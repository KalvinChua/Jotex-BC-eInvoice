codeunit 50310 "eInvoice Azure Function Client"
{
    // Enhanced Azure Function Client with patterns inspired by myinvois-client
    // Provides structured approach to Azure Function communication
    // Includes comprehensive error handling and diagnostics

    var
        Client: HttpClient;
        DefaultTimeout: Duration;
        LastRequestTime: Dictionary of [Text, DateTime]; // Track request timing for rate limiting

    procedure InitializeClient()
    begin
        // Initialize HTTP client with optimal settings
        DefaultTimeout := 300000; // 5 minutes timeout (following myinvois-client pattern)
        Client.Timeout := DefaultTimeout;
    end;

    procedure SignDocument(UnsignedJson: Text; Setup: Record "eInvoiceSetup") SignedJson: Text
    var
        RequestPayload: JsonObject;
        RequestText: Text;
        Response: HttpResponseMessage;
        RequestContent: HttpContent;
        Headers: HttpHeaders;
        ResponseText: Text;
        CorrelationId: Text;
        PooledClient: HttpClient;
    begin
        // Generate correlation ID for tracking (following myinvois-client pattern)
        CorrelationId := CreateGuid();

        // Prepare structured request payload
        if not PrepareSigningRequest(UnsignedJson, Setup, RequestPayload, CorrelationId) then
            Error('Failed to prepare signing request payload');

        RequestPayload.WriteTo(RequestText);

        // Setup HTTP request with enhanced headers
        RequestContent.WriteFrom(RequestText);
        RequestContent.GetHeaders(Headers);
        Headers.Clear();
        Headers.Add('Content-Type', 'application/json');
        Headers.Add('User-Agent', 'BusinessCentral-eInvoice/1.0');
        Headers.Add('X-Correlation-ID', CorrelationId);
        Headers.Add('X-Request-Source', 'BusinessCentral');

        // Apply rate limiting
        ApplyRateLimiting(Setup."Azure Function URL");

        // Send request with comprehensive error handling
        if not Client.Post(Setup."Azure Function URL", RequestContent, Response) then
            Error('Failed to connect to Azure Function\\\\' +
                  'Correlation ID: %1\\' +
                  'Endpoint: %2\\\\' +
                  'This indicates a network connectivity issue.', CorrelationId, Setup."Azure Function URL");

        Response.Content().ReadAs(ResponseText);

        if not Response.IsSuccessStatusCode() then
            HandleAzureFunctionError(Response, ResponseText, CorrelationId, Setup."Azure Function URL");

        // Validate and return signed JSON
        if not ValidateSignedResponse(ResponseText) then
            Error('Azure Function returned invalid signed document\\\\' +
                  'Correlation ID: %1\\' +
                  'Please check Function App logs for details.', CorrelationId);

        SignedJson := ResponseText;
    end;



    local procedure ApplyRateLimiting(FunctionUrl: Text)
    var
        LastTime: DateTime;
        CurrentTime: DateTime;
        MinInterval: Duration;
    begin
        CurrentTime := CurrentDateTime();
        MinInterval := 1000; // 1 second minimum between requests

        if LastRequestTime.ContainsKey(FunctionUrl) then begin
            LastRequestTime.Get(FunctionUrl, LastTime);
            if (CurrentTime - LastTime) < MinInterval then begin
                // Wait for rate limiting
                Sleep(1000);
            end;
        end;

        // Update last request time
        LastRequestTime.Set(FunctionUrl, CurrentTime);
    end;

    local procedure PrepareSigningRequest(UnsignedJson: Text; Setup: Record "eInvoiceSetup"; var RequestPayload: JsonObject; CorrelationId: Text) Success: Boolean
    var
        TestJson: JsonObject;
    begin
        // Validate input JSON structure
        if not TestJson.ReadFrom(UnsignedJson) then
            exit(false);

        // Build structured request following myinvois-client patterns
        RequestPayload.Add('unsignedJson', UnsignedJson);
        RequestPayload.Add('correlationId', CorrelationId);
        RequestPayload.Add('timestamp', Format(CurrentDateTime, 0, '<Year4>-<Month,2>-<Day,2>T<Hours24,2>:<Minutes,2>:<Seconds,2>Z'));
        RequestPayload.Add('environment', Format(Setup.Environment));
        RequestPayload.Add('source', 'BusinessCentral');
        RequestPayload.Add('version', '1.0');

        // Add metadata for better tracking
        RequestPayload.Add('payloadSize', StrLen(UnsignedJson));
        RequestPayload.Add('clientInfo', GetClientInfo());

        Success := true;
    end;

    local procedure ValidateSignedResponse(SignedJson: Text) IsValid: Boolean
    var
        ResponseObject: JsonObject;
        SignedDocumentToken: JsonToken;
    begin
        // Validate response structure
        if not ResponseObject.ReadFrom(SignedJson) then
            exit(false);

        // Check for required signed document field
        if not ResponseObject.Get('signedDocument', SignedDocumentToken) then
            exit(false);

        // Additional validation could be added here
        IsValid := true;
    end;

    local procedure HandleAzureFunctionError(Response: HttpResponseMessage; ResponseText: Text; CorrelationId: Text; FunctionUrl: Text)
    var
        StatusCode: Integer;
        ReasonPhrase: Text;
        ErrorDetails: Text;
    begin
        StatusCode := Response.HttpStatusCode();
        ReasonPhrase := Response.ReasonPhrase();

        // Parse error details from response if available
        ErrorDetails := ExtractErrorDetails(ResponseText);

        // Comprehensive error reporting based on status code
        case StatusCode of
            400:
                Error('Azure Function - Bad Request (400)\\\\' +
                      'Error Details:\\%1\\\\' +
                      'Common Causes:\\' +
                      '- Invalid JSON payload structure\\' +
                      '- Missing required fields in request\\' +
                      '- Malformed UBL document structure\\' +
                      '- Invalid certificate configuration\\\\' +
                      'Correlation ID: %2\\' +
                      'Endpoint: %3', ErrorDetails, CorrelationId, FunctionUrl);

            401:
                Error('Azure Function - Unauthorized (401)\\\\' +
                      'Authentication Issues:\\' +
                      '- Function requires authentication\\' +
                      '- Invalid or expired authentication token\\' +
                      '- Missing authentication headers\\\\' +
                      'Correlation ID: %1\\' +
                      'Endpoint: %2', CorrelationId, FunctionUrl);

            404:
                Error('Azure Function - Not Found (404)\\\\' +
                      'Endpoint Issues:\\' +
                      '- Function URL is incorrect\\' +
                      '- Function has been deleted or moved\\' +
                      '- Function name or route is wrong\\\\' +
                      'Correlation ID: %1\\' +
                      'Endpoint: %2', CorrelationId, FunctionUrl);

            429:
                Error('Azure Function - Too Many Requests (429)\\\\' +
                      'Rate Limiting:\\' +
                      '- Function is rate limited\\' +
                      '- Too many concurrent requests\\' +
                      '- Wait before retrying\\\\' +
                      'Correlation ID: %1\\' +
                      'Endpoint: %2', CorrelationId, FunctionUrl);

            500:
                Error('Azure Function - Internal Server Error (500)\\\\' +
                      'Error Details:\\%1\\\\' +
                      'Server-Side Issues:\\' +
                      '- Function code exceptions or bugs\\' +
                      '- Digital signature certificate problems\\' +
                      '- External service dependencies unavailable\\' +
                      '- Resource constraints (memory/CPU)\\' +
                      '- Configuration errors in Function App\\\\' +
                      'Next Steps:\\' +
                      '- Check Application Insights logs\\' +
                      '- Verify certificate availability\\' +
                      '- Review Function App configuration\\' +
                      '- Check resource utilization\\\\' +
                      'Correlation ID: %2\\' +
                      'Endpoint: %3', ErrorDetails, CorrelationId, FunctionUrl);

            502, 503, 504:
                Error('Azure Function - Service Unavailable (%1)\\\\' +
                      'Infrastructure Issues:\\' +
                      '- Function App is scaling or restarting\\' +
                      '- Load balancer or gateway problems\\' +
                      '- Temporary service outage\\' +
                      '- Cold start timeout issues\\\\' +
                      'Recommended Actions:\\' +
                      '- Wait a few minutes and retry\\' +
                      '- Check Azure Status page\\' +
                      '- Verify Function App scaling settings\\\\' +
                      'Correlation ID: %2\\' +
                      'Endpoint: %3', StatusCode, CorrelationId, FunctionUrl);

            else
                Error('Azure Function - Unexpected Error (%1 %2)\\\\' +
                      'Response Details:\\%3\\\\' +
                      'Correlation ID: %4\\' +
                      'Endpoint: %5\\\\' +
                      'Please contact support with the correlation ID.',
                      StatusCode, ReasonPhrase, ResponseText, CorrelationId, FunctionUrl);
        end;
    end;

    local procedure ExtractErrorDetails(ResponseText: Text) ErrorDetails: Text
    var
        ResponseObject: JsonObject;
        ErrorToken: JsonToken;
        MessageToken: JsonToken;
    begin
        // Try to extract structured error information
        if ResponseObject.ReadFrom(ResponseText) then begin
            if ResponseObject.Get('error', ErrorToken) then begin
                if ErrorToken.AsObject().Get('message', MessageToken) then
                    ErrorDetails := MessageToken.AsValue().AsText()
                else
                    ErrorDetails := 'Structured error information available in response';
            end else if ResponseObject.Get('message', MessageToken) then
                    ErrorDetails := MessageToken.AsValue().AsText()
            else
                ErrorDetails := ResponseText;
        end else
            ErrorDetails := ResponseText;

        // Truncate if too long
        if StrLen(ErrorDetails) > 500 then
            ErrorDetails := CopyStr(ErrorDetails, 1, 500) + '... (truncated)';
    end;

    local procedure GetClientInfo() ClientInfo: Text
    var
        ClientObject: JsonObject;
        ClientText: Text;
    begin
        // Build client information object
        ClientObject.Add('platform', 'Microsoft Dynamics 365 Business Central');
        ClientObject.Add('version', '1.0');
        ClientObject.Add('timestamp', Format(CurrentDateTime, 0, '<Year4>-<Month,2>-<Day,2>T<Hours24,2>:<Minutes,2>:<Seconds,2>Z'));
        ClientObject.WriteTo(ClientText);
        ClientInfo := ClientText;
    end;



    // Performance optimization: Clear rate limiting cache when needed
    procedure ClearRateLimitingCache()
    begin
        // Clear rate limiting cache to free resources
        // Dictionary cache will be cleared automatically when codeunit is unloaded
    end;
}
