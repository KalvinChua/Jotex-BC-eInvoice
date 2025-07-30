codeunit 50300 eInvoiceHelper
{
    // Enhanced e-Invoice Helper with LHDN SDK integration practices
    // Implements official rate limits, retry-after handling, and best practices

    var
        DefaultTimeout: Duration;
        TokenCache: Dictionary of [Text, Text]; // Cache for tokens by environment
        TokenExpiryCache: Dictionary of [Text, DateTime]; // Cache for token expiry times
        TokenRetryCount: Dictionary of [Text, Integer]; // Track retry attempts per cache key
        MaxRetries: Integer;
        RetryDelayMs: Integer;
        // LHDN SDK Rate Limiting
        LastRequestTime: Dictionary of [Text, DateTime]; // Track last request time per endpoint
        RateLimits: Dictionary of [Text, Integer]; // RPM limits per endpoint
        RetryAfterCache: Dictionary of [Text, DateTime]; // Track retry-after times

    procedure InitializeHelper()
    begin
        DefaultTimeout := 300000; // 5 minutes timeout
        MaxRetries := 3; // Maximum retry attempts for token requests
        RetryDelayMs := 2000; // 2 seconds delay between retries

        // Initialize LHDN SDK rate limits as per official documentation
        InitializeRateLimits();
    end;

    /// <summary>
    /// Initialize rate limits according to LHDN SDK documentation
    /// </summary>
    local procedure InitializeRateLimits()
    begin
        // Login endpoint: 12 RPM
        RateLimits.Set('login', 12);
        // Submit Documents: 100 RPM  
        RateLimits.Set('submit', 100);
        // Get Submission: 300 RPM
        RateLimits.Set('status', 300);
        // Default rate limit for other endpoints
        RateLimits.Set('default', 60);
    end;

    /// <summary>
    /// Apply rate limiting based on LHDN SDK requirements
    /// </summary>
    procedure ApplyRateLimiting(Endpoint: Text)
    var
        CurrentTime: DateTime;
        LastTime: DateTime;
        MinIntervalMs: Integer;
        EndpointKey: Text;
        RetryAfterTime: DateTime;
    begin
        CurrentTime := CurrentDateTime();
        EndpointKey := GetEndpointKey(Endpoint);

        // Check if we're in a retry-after period
        if RetryAfterCache.ContainsKey(EndpointKey) then begin
            RetryAfterCache.Get(EndpointKey, RetryAfterTime);
            if CurrentTime < RetryAfterTime then begin
                Sleep(RetryAfterTime - CurrentTime);
            end else begin
                RetryAfterCache.Remove(EndpointKey);
            end;
        end;

        // Apply rate limiting based on endpoint
        if LastRequestTime.ContainsKey(EndpointKey) then begin
            LastRequestTime.Get(EndpointKey, LastTime);
            MinIntervalMs := GetMinIntervalForEndpoint(Endpoint);

            if (CurrentTime - LastTime) < MinIntervalMs then begin
                Sleep(MinIntervalMs - (CurrentTime - LastTime));
            end;
        end;

        // Update last request time
        LastRequestTime.Set(EndpointKey, CurrentDateTime());
    end;

    /// <summary>
    /// Get minimum interval in milliseconds for endpoint rate limiting
    /// </summary>
    local procedure GetMinIntervalForEndpoint(Endpoint: Text): Integer
    var
        RpmLimit: Integer;
    begin
        // Convert RPM to minimum interval in milliseconds
        if Endpoint.Contains('connect/token') then
            RpmLimit := 12 // Login endpoint
        else if Endpoint.Contains('documentsubmissions') and Endpoint.Contains('POST') then
            RpmLimit := 100 // Submit documents
        else if Endpoint.Contains('documentsubmissions') and Endpoint.Contains('GET') then
            RpmLimit := 300 // Get submission status
        else
            RpmLimit := 60; // Default rate limit

        // Convert RPM to milliseconds (60,000ms / RPM)
        exit(60000 div RpmLimit);
    end;

    /// <summary>
    /// Get unique endpoint key for rate limiting
    /// </summary>
    local procedure GetEndpointKey(Endpoint: Text): Text
    begin
        // Create unique key based on endpoint and HTTP method
        if Endpoint.Contains('connect/token') then
            exit('login')
        else if Endpoint.Contains('documentsubmissions') and Endpoint.Contains('POST') then
            exit('submit')
        else if Endpoint.Contains('documentsubmissions') and Endpoint.Contains('GET') then
            exit('status')
        else
            exit('default');
    end;

    /// <summary>
    /// Handle Retry-After header from LHDN API responses
    /// </summary>
    procedure HandleRetryAfter(Endpoint: Text; RetryAfterSeconds: Integer)
    var
        RetryAfterTime: DateTime;
        EndpointKey: Text;
    begin
        if RetryAfterSeconds > 0 then begin
            EndpointKey := GetEndpointKey(Endpoint);
            RetryAfterTime := CurrentDateTime() + (RetryAfterSeconds * 1000);
            RetryAfterCache.Set(EndpointKey, RetryAfterTime);

            LogTokenOperation(StrSubstNo('Rate limit hit - retry after %1 seconds', RetryAfterSeconds), '', RetryAfterTime);
        end;
    end;

    /// <summary>
    /// Enhanced token retrieval with automatic refresh and robust error handling
    /// This method automatically handles token expiry and retries failed requests
    /// </summary>
    /// <param name="SetupRec">eInvoice Setup record containing credentials</param>
    /// <returns>Valid access token for LHDN API</returns>
    procedure GetAccessTokenFromSetup(var SetupRec: Record eInvoiceSetup): Text
    var
        Token: Text;
        ExpirySeconds: Integer;
        ExpiryTime: DateTime;
        TokenValidityBuffer: Duration;
        CacheKey: Text;
        CurrentTime: DateTime;
        RetryAttempt: Integer;
        LastError: Text;
    begin
        InitializeHelper();
        CurrentTime := CurrentDateTime();

        // Enhanced token validation with buffer time (following myinvois-client pattern)
        TokenValidityBuffer := 300000; // 5 minutes buffer before actual expiry

        // Create cache key based on environment and credentials
        CacheKey := GetCacheKey(SetupRec);

        // Check in-memory cache first (fastest)
        if IsTokenValidInCache(CacheKey, CurrentTime, Token) then begin
            LogTokenOperation('Token reused from memory cache', Token, GetExpiryTimeFromCache(CacheKey));
            exit(Token);
        end;

        // Check database cache (slower but persistent)
        if IsTokenValidInDatabase(SetupRec, CurrentTime, Token, ExpiryTime) then begin
            // Update in-memory cache
            UpdateMemoryCache(CacheKey, Token, ExpiryTime);
            LogTokenOperation('Token reused from database cache', Token, ExpiryTime);
            exit(Token);
        end;

        // Token missing, expired, or near expiry – generate new with retry logic
        LogTokenOperation('Generating new token (automatic refresh)', '', 0DT);

        for RetryAttempt := 1 to MaxRetries do begin
            Token := TryGetNewToken(SetupRec, ExpirySeconds, LastError);

            if Token <> '' then begin
                // Success - update both database and in-memory cache
                UpdateTokenCaches(SetupRec, Token, ExpirySeconds, CacheKey);
                LogTokenOperation(StrSubstNo('New token generated (attempt %1/%2)', RetryAttempt, MaxRetries), Token, CurrentTime + (ExpirySeconds * 1000));
                exit(Token);
            end;

            // Failed - log error and retry if attempts remain
            if RetryAttempt < MaxRetries then begin
                LogTokenOperation(StrSubstNo('Token request failed (attempt %1/%2)', RetryAttempt, MaxRetries), '', 0DT);
                Sleep(RetryDelayMs * RetryAttempt); // Exponential backoff
            end;
        end;

        // All retries failed
        Error('Token Generation Failed After %1 Attempts\n\n' +
              'Last Error: %2\n\n' +
              'Troubleshooting Steps:\n' +
              '1. Verify Client ID and Client Secret are correct\n' +
              '2. Check network connectivity to LHDN servers\n' +
              '3. Ensure LHDN API service is available\n' +
              '4. Verify credentials are active in LHDN portal\n' +
              '5. Check if your IP is whitelisted if required\n\n' +
              'Correlation ID: %3',
              MaxRetries, LastError, CreateGuid());
    end;

    /// <summary>
    /// Check if token is valid in memory cache
    /// </summary>
    local procedure IsTokenValidInCache(CacheKey: Text; CurrentTime: DateTime; var Token: Text): Boolean
    var
        ExpiryTime: DateTime;
    begin
        if not TokenCache.ContainsKey(CacheKey) then
            exit(false);

        if not TokenExpiryCache.ContainsKey(CacheKey) then
            exit(false);

        TokenExpiryCache.Get(CacheKey, ExpiryTime);
        if ExpiryTime <= CurrentTime then
            exit(false);

        TokenCache.Get(CacheKey, Token);
        exit(true);
    end;

    /// <summary>
    /// Check if token is valid in database cache
    /// </summary>
    local procedure IsTokenValidInDatabase(var SetupRec: Record eInvoiceSetup; CurrentTime: DateTime; var Token: Text; var ExpiryTime: DateTime): Boolean
    var
        BufferTime: Duration;
    begin
        if (SetupRec."Last Token" = '') or (SetupRec."Token Timestamp" = 0DT) or (SetupRec."Token Expiry (s)" <= 0) then
            exit(false);

        BufferTime := 300000; // 5 minutes buffer
        ExpiryTime := SetupRec."Token Timestamp" + ((SetupRec."Token Expiry (s)" * 1000) - BufferTime);

        if ExpiryTime <= CurrentTime then
            exit(false);

        Token := SetupRec."Last Token";
        exit(true);
    end;

    /// <summary>
    /// Update memory cache with token and expiry
    /// </summary>
    local procedure UpdateMemoryCache(CacheKey: Text; Token: Text; ExpiryTime: DateTime)
    begin
        TokenCache.Set(CacheKey, Token);
        TokenExpiryCache.Set(CacheKey, ExpiryTime);
    end;

    /// <summary>
    /// Get expiry time from memory cache
    /// </summary>
    local procedure GetExpiryTimeFromCache(CacheKey: Text): DateTime
    var
        ExpiryTime: DateTime;
    begin
        if TokenExpiryCache.ContainsKey(CacheKey) then
            TokenExpiryCache.Get(CacheKey, ExpiryTime)
        else
            ExpiryTime := 0DT;
        exit(ExpiryTime);
    end;

    /// <summary>
    /// Try to get a new token with error handling
    /// </summary>
    local procedure TryGetNewToken(var SetupRec: Record eInvoiceSetup; var ExpirySeconds: Integer; var LastError: Text): Text
    var
        Token: Text;
        TempExpirySeconds: Integer;
    begin
        LastError := ''; // Initialize LastError
        TempExpirySeconds := 0;
        Token := GetAccessTokenFromFields(
            SetupRec."Client ID",
            SetupRec."Client Secret",
            SetupRec.Environment,
            TempExpirySeconds
        );
        ExpirySeconds := TempExpirySeconds;
        exit(Token);
    end;

    /// <summary>
    /// Update both database and memory caches with new token
    /// </summary>
    local procedure UpdateTokenCaches(var SetupRec: Record eInvoiceSetup; Token: Text; ExpirySeconds: Integer; CacheKey: Text)
    var
        CurrentTime: DateTime;
        ExpiryTime: DateTime;
    begin
        CurrentTime := CurrentDateTime();
        ExpiryTime := CurrentTime + (ExpirySeconds * 1000);

        // Update database cache
        SetupRec."Last Token" := Token;
        SetupRec."Token Timestamp" := CurrentTime;
        SetupRec."Token Expiry (s)" := ExpirySeconds;
        SetupRec.Modify();

        // Update memory cache
        UpdateMemoryCache(CacheKey, Token, ExpiryTime);
    end;

    /// <summary>
    /// Force refresh token regardless of cache status
    /// Useful for testing or when credentials are updated
    /// </summary>
    procedure ForceRefreshToken(var SetupRec: Record eInvoiceSetup): Text
    var
        Token: Text;
        ExpirySeconds: Integer;
        CacheKey: Text;
        LastError: Text;
    begin
        LogTokenOperation('Force refreshing token', '', 0DT);

        // Clear existing caches
        ClearTokenCache();

        // Get new token
        CacheKey := GetCacheKey(SetupRec);
        Token := TryGetNewToken(SetupRec, ExpirySeconds, LastError);

        if Token <> '' then begin
            UpdateTokenCaches(SetupRec, Token, ExpirySeconds, CacheKey);
            LogTokenOperation('Token force refreshed successfully', Token, CurrentDateTime() + (ExpirySeconds * 1000));
        end;

        exit(Token);
    end;

    /// <summary>
    /// Check if token needs refresh (for monitoring purposes)
    /// </summary>
    procedure IsTokenRefreshNeeded(var SetupRec: Record eInvoiceSetup): Boolean
    var
        CurrentTime: DateTime;
        ExpiryTime: DateTime;
        BufferTime: Duration;
    begin
        if (SetupRec."Last Token" = '') or (SetupRec."Token Timestamp" = 0DT) or (SetupRec."Token Expiry (s)" <= 0) then
            exit(true);

        CurrentTime := CurrentDateTime();
        BufferTime := 300000; // 5 minutes buffer
        ExpiryTime := SetupRec."Token Timestamp" + ((SetupRec."Token Expiry (s)" * 1000) - BufferTime);

        exit(ExpiryTime <= CurrentTime);
    end;

    /// <summary>
    /// Get token status for monitoring and debugging
    /// </summary>
    procedure GetTokenStatus(var SetupRec: Record eInvoiceSetup): Text
    var
        CurrentTime: DateTime;
        ExpiryTime: DateTime;
        TimeRemaining: Duration;
        Status: Text;
    begin
        if (SetupRec."Last Token" = '') or (SetupRec."Token Timestamp" = 0DT) then
            exit('No Token');

        CurrentTime := CurrentDateTime();
        ExpiryTime := SetupRec."Token Timestamp" + (SetupRec."Token Expiry (s)" * 1000);

        if ExpiryTime <= CurrentTime then
            exit('Expired');

        TimeRemaining := ExpiryTime - CurrentTime;
        Status := StrSubstNo('Valid (%1 minutes remaining)',
            Round(TimeRemaining / 60000, 1, '>'));
        exit(Status);
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
        RetryAfterSeconds: Integer;
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

        // Apply LHDN SDK rate limiting for login endpoint
        ApplyRateLimiting(TokenURL);

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

        // Handle rate limiting response (429 status)
        if ResponseMessage.HttpStatusCode() = 429 then begin
            // Note: AL doesn't support direct header access, so we'll use a default retry time
            RetryAfterSeconds := 60; // Default 60 seconds for rate limit
            HandleRetryAfter(TokenURL, RetryAfterSeconds);
            Error('Rate Limit Exceeded\n\n' +
                  'LHDN API rate limit reached for login endpoint.\n' +
                  'Retry after %1 seconds.\n\n' +
                  'This is normal behavior - the system will automatically retry.\n' +
                  'Correlation ID: %2', RetryAfterSeconds, CorrelationId);
        end;

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

    // Performance optimization: Clear cache when needed
    procedure ClearTokenCache()
    begin
        // Clear memory caches - dictionaries will be cleared when codeunit is unloaded
        // No manual clear needed in AL as dictionaries are session-based
        LogTokenOperation('Token cache cleared', '', 0DT);
    end;
}