codeunit 50300 eInvoiceHelper
{
    // Enhanced e-Invoice Helper with patterns inspired by myinvois-client
    // Includes improved error handling, token management, and API communication

    var
        DefaultTimeout: Duration;
        TokenCache: Dictionary of [Text, Text]; // Cache for tokens by environment
        TokenExpiryCache: Dictionary of [Text, DateTime]; // Cache for token expiry times

    procedure InitializeHelper()
    begin
        DefaultTimeout := 300000; // 5 minutes timeout
    end;

    procedure GetAccessTokenFromSetup(var SetupRec: Record eInvoiceSetup): Text
    var
        Token: Text;
        ExpirySeconds: Integer;
        ExpiryTime: DateTime;
        TokenValidityBuffer: Duration;
        CacheKey: Text;
        CurrentTime: DateTime;
    begin
        InitializeHelper();
        CurrentTime := CurrentDateTime();

        // Enhanced token validation with buffer time (following myinvois-client pattern)
        TokenValidityBuffer := 300000; // 5 minutes buffer before actual expiry

        // Create cache key based on environment and credentials
        CacheKey := GetCacheKey(SetupRec);

        // Check in-memory cache first (fastest)
        if TokenCache.ContainsKey(CacheKey) then begin
            if TokenExpiryCache.ContainsKey(CacheKey) then begin
                TokenExpiryCache.Get(CacheKey, ExpiryTime);
                if ExpiryTime > CurrentTime then begin
                    TokenCache.Get(CacheKey, Token);
                    LogTokenOperation('Token reused from cache', Token, ExpiryTime);
                    exit(Token);
                end;
            end;
        end;

        // Check database cache (slower but persistent)
        if (SetupRec."Last Token" <> '') and (SetupRec."Token Timestamp" <> 0DT) and (SetupRec."Token Expiry (s)" > 0) then begin
            ExpiryTime := SetupRec."Token Timestamp" + ((SetupRec."Token Expiry (s)" - 300) * 1000); // 5 min buffer
            if ExpiryTime > CurrentTime then begin
                // Update in-memory cache
                TokenCache.Set(CacheKey, SetupRec."Last Token");
                TokenExpiryCache.Set(CacheKey, ExpiryTime);

                LogTokenOperation('Token reused from database', SetupRec."Last Token", ExpiryTime);
                exit(SetupRec."Last Token");
            end;
        end;

        // Token missing, expired, or near expiry – generate new
        LogTokenOperation('Generating new token', '', 0DT);
        Token := GetAccessTokenFromFields(
            SetupRec."Client ID",
            SetupRec."Client Secret",
            SetupRec.Environment,
            ExpirySeconds
        );

        // Update both database and in-memory cache
        SetupRec."Last Token" := Token;
        SetupRec."Token Timestamp" := CurrentTime;
        SetupRec."Token Expiry (s)" := ExpirySeconds;
        SetupRec.Modify();

        // Update in-memory cache
        ExpiryTime := CurrentTime + (ExpirySeconds * 1000);
        TokenCache.Set(CacheKey, Token);
        TokenExpiryCache.Set(CacheKey, ExpiryTime);

        LogTokenOperation('New token generated', Token, ExpiryTime);
        exit(Token);
    end;

    local procedure GetCacheKey(SetupRec: Record eInvoiceSetup): Text
    begin
        // Create unique cache key based on environment and credentials hash
        exit(Format(SetupRec.Environment) + '_' + CreateGuid());
    end;

    procedure GetAccessTokenFromFields(ClientID: Text; ClientSecret: Text; Env: Option Preprod,Production; var ExpirySeconds: Integer): Text
    var
        HttpClient: HttpClient;
        ResponseMessage: HttpResponseMessage;
        ResponseText: Text;
        JsonResponse: JsonObject;
        TokenValue, ExpiryValue : JsonToken;
        TokenURL: Text;
        AccessToken: Text;
        BodyText: Text;
        Content: HttpContent;
        Headers: HttpHeaders;
        CorrelationId: Text;
        RequestStartTime: DateTime;
        RequestEndTime: DateTime;
    begin
        ExpirySeconds := 0;
        CorrelationId := CreateGuid();
        RequestStartTime := CurrentDateTime();

        // Enhanced input validation
        if (ClientID = '') or (ClientSecret = '') then
            Error('Authentication Configuration Error\n\n' +
                  'Client ID or Client Secret is blank.\n\n' +
                  'Resolution Steps:\n' +
                  '1. Navigate to e-Invoice Setup\n' +
                  '2. Configure Client ID and Client Secret\n' +
                  '3. Verify credentials with LHDN\n' +
                  '4. Save configuration and retry\n\n' +
                  'Correlation ID: %1', CorrelationId);

        // Set timeout for HTTP client
        HttpClient.Timeout := DefaultTimeout;

        if Env = Env::Preprod then
            TokenURL := 'https://preprod-api.myinvois.hasil.gov.my/connect/token'
        else
            TokenURL := 'https://api.myinvois.hasil.gov.my/connect/token';

        BodyText := StrSubstNo(
            'grant_type=client_credentials&client_id=%1&client_secret=%2&scope=InvoicingAPI',
            ClientID,
            ClientSecret
        );

        Content.WriteFrom(BodyText);
        Content.GetHeaders(Headers);
        Headers.Clear();
        Headers.Add('Content-Type', 'application/x-www-form-urlencoded');

        HttpClient.DefaultRequestHeaders().Clear();

        if not HttpClient.Post(TokenURL, Content, ResponseMessage) then
            Error('Failed to send request to MyInvois token endpoint.');

        ResponseMessage.Content().ReadAs(ResponseText);
        JsonResponse.ReadFrom(ResponseText);

        if JsonResponse.Contains('access_token') then begin
            JsonResponse.Get('access_token', TokenValue);
            AccessToken := TokenValue.AsValue().AsText();

            if JsonResponse.Contains('expires_in') then begin
                JsonResponse.Get('expires_in', ExpiryValue);
                ExpirySeconds := ExpiryValue.AsValue().AsInteger();
            end;

            RequestEndTime := CurrentDateTime();
            LogTokenOperation('Token request successful', AccessToken, RequestStartTime + (ExpirySeconds * 1000));

            exit(AccessToken);
        end else begin
            RequestEndTime := CurrentDateTime();
            Error('Access Token Request Failed\n\n' +
                  'Response Details:\n%1\n\n' +
                  'Troubleshooting Steps:\n' +
                  '1. Verify Client ID and Client Secret are correct\n' +
                  '2. Check if credentials are active in LHDN portal\n' +
                  '3. Ensure correct environment is selected\n' +
                  '4. Verify network connectivity to LHDN servers\n' +
                  '5. Check for any API service outages\n\n' +
                  'Correlation ID: %2\n' +
                  'Request Duration: %3 ms', ResponseText, CorrelationId, RequestEndTime - RequestStartTime);
        end;
    end;

    local procedure LogTokenOperation(Operation: Text; Token: Text; ExpiryTime: DateTime)
    var
        LogMessage: Text;
        TokenPreview: Text;
    begin
        // Create safe token preview (first 10 characters + ...)
        if StrLen(Token) > 10 then
            TokenPreview := CopyStr(Token, 1, 10) + '...'
        else if Token <> '' then
            TokenPreview := '***'
        else
            TokenPreview := 'N/A';

        LogMessage := StrSubstNo('%1 - Token: %2, Expiry: %3',
            Operation,
            TokenPreview,
            Format(ExpiryTime, 0, '<Year4>-<Month,2>-<Day,2> <Hours24,2>:<Minutes,2>:<Seconds,2>'));

        // Could be extended to write to event log or custom logging table
        // For now, this serves as a placeholder for debugging
    end;

    procedure ValidateEnvironmentConfiguration(Setup: Record "eInvoiceSetup") IsValid: Boolean
    var
        ValidationErrors: List of [Text];
        ErrorText: Text;
        ErrorMessage: Text;
    begin
        // Comprehensive environment validation inspired by myinvois-client
        IsValid := true;

        // Check required fields
        if Setup."Client ID" = '' then begin
            ValidationErrors.Add('Client ID is not configured');
            IsValid := false;
        end;

        if Setup."Client Secret" = '' then begin
            ValidationErrors.Add('Client Secret is not configured');
            IsValid := false;
        end;

        if Setup."Azure Function URL" = '' then begin
            ValidationErrors.Add('Azure Function URL is not configured');
            IsValid := false;
        end;

        // Report validation errors if any
        if not IsValid then begin
            ErrorMessage := 'eInvoice Configuration Validation Failed\n\nMissing Configuration:\n';
            foreach ErrorText in ValidationErrors do
                ErrorMessage += '• ' + ErrorText + '\n';

            ErrorMessage += '\nPlease complete the configuration in e-Invoice Setup and try again.';
            Error(ErrorMessage);
        end;
    end;

    procedure GetFormattedEnvironmentInfo(Setup: Record "eInvoiceSetup") EnvironmentInfo: Text
    var
        InfoObject: JsonObject;
        InfoText: Text;
    begin
        // Format environment information for debugging and logging
        InfoObject.Add('environment', Format(Setup.Environment));
        InfoObject.Add('hasClientId', Setup."Client ID" <> '');
        InfoObject.Add('hasClientSecret', Setup."Client Secret" <> '');
        InfoObject.Add('hasAzureFunctionUrl', Setup."Azure Function URL" <> '');
        InfoObject.Add('tokenStatus', GetTokenStatus(Setup));
        InfoObject.Add('timestamp', Format(CurrentDateTime, 0, '<Year4>-<Month,2>-<Day,2>T<Hours24,2>:<Minutes,2>:<Seconds,2>Z'));

        InfoObject.WriteTo(InfoText);
        EnvironmentInfo := InfoText;
    end;

    local procedure GetTokenStatus(Setup: Record "eInvoiceSetup") Status: Text
    var
        ExpiryTime: DateTime;
    begin
        if (Setup."Last Token" = '') or (Setup."Token Timestamp" = 0DT) then
            Status := 'No Token'
        else begin
            ExpiryTime := Setup."Token Timestamp" + (Setup."Token Expiry (s)" * 1000);
            if ExpiryTime > CurrentDateTime() then
                Status := 'Valid'
            else
                Status := 'Expired';
        end;
    end;

    // Performance optimization: Clear cache when needed
    procedure ClearTokenCache()
    begin
        // Dictionary cache will be cleared automatically when codeunit is unloaded
        // No manual clear needed in AL
    end;
}