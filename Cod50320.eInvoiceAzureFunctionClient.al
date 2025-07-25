codeunit 50320 "eInvoice Azure Function Client"
{
    // Enhanced Azure Function Client with patterns inspired by myinvois-client
    // Provides structured approach to Azure Function communication
    // Includes comprehensive error handling and diagnostics

    var
        Client: HttpClient;
        DefaultTimeout: Duration;

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

        // Send request with comprehensive error handling
        if not Client.Post(Setup."Azure Function URL", RequestContent, Response) then
            Error('❌ Failed to connect to Azure Function\n\n' +
                  'Correlation ID: %1\n' +
                  'Endpoint: %2\n\n' +
                  'This indicates a network connectivity issue.', CorrelationId, Setup."Azure Function URL");

        Response.Content().ReadAs(ResponseText);

        if not Response.IsSuccessStatusCode() then
            HandleAzureFunctionError(Response, ResponseText, CorrelationId, Setup."Azure Function URL");

        // Validate and return signed JSON
        if not ValidateSignedResponse(ResponseText) then
            Error('❌ Azure Function returned invalid signed document\n\n' +
                  'Correlation ID: %1\n' +
                  'Please check Function App logs for details.', CorrelationId);

        SignedJson := ResponseText;
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
                Error('❌ Azure Function - Bad Request (400)\n\n' +
                      '📋 Error Details:\n%1\n\n' +
                      '🔧 Common Causes:\n' +
                      '• Invalid JSON payload structure\n' +
                      '• Missing required fields in request\n' +
                      '• Malformed UBL document structure\n' +
                      '• Invalid certificate configuration\n\n' +
                      '🆔 Correlation ID: %2\n' +
                      '🎯 Endpoint: %3', ErrorDetails, CorrelationId, FunctionUrl);

            401:
                Error('❌ Azure Function - Unauthorized (401)\n\n' +
                      '🔧 Authentication Issues:\n' +
                      '• Function requires authentication\n' +
                      '• Invalid or expired authentication token\n' +
                      '• Missing authentication headers\n\n' +
                      '🆔 Correlation ID: %1\n' +
                      '🎯 Endpoint: %2', CorrelationId, FunctionUrl);

            404:
                Error('❌ Azure Function - Not Found (404)\n\n' +
                      '🔧 Endpoint Issues:\n' +
                      '• Function URL is incorrect\n' +
                      '• Function has been deleted or moved\n' +
                      '• Function name or route is wrong\n\n' +
                      '🆔 Correlation ID: %1\n' +
                      '🎯 Endpoint: %2', CorrelationId, FunctionUrl);

            500:
                Error('❌ Azure Function - Internal Server Error (500)\n\n' +
                      '📋 Error Details:\n%1\n\n' +
                      '🔧 Server-Side Issues:\n' +
                      '• Function code exceptions or bugs\n' +
                      '• Digital signature certificate problems\n' +
                      '• External service dependencies unavailable\n' +
                      '• Resource constraints (memory/CPU)\n' +
                      '• Configuration errors in Function App\n\n' +
                      '💡 Next Steps:\n' +
                      '• Check Application Insights logs\n' +
                      '• Verify certificate availability\n' +
                      '• Review Function App configuration\n' +
                      '• Check resource utilization\n\n' +
                      '🆔 Correlation ID: %2\n' +
                      '🎯 Endpoint: %3', ErrorDetails, CorrelationId, FunctionUrl);

            502, 503, 504:
                Error('❌ Azure Function - Service Unavailable (%1)\n\n' +
                      '🔧 Infrastructure Issues:\n' +
                      '• Function App is scaling or restarting\n' +
                      '• Load balancer or gateway problems\n' +
                      '• Temporary service outage\n' +
                      '• Cold start timeout issues\n\n' +
                      '💡 Recommended Actions:\n' +
                      '• Wait a few minutes and retry\n' +
                      '• Check Azure Status page\n' +
                      '• Verify Function App scaling settings\n\n' +
                      '🆔 Correlation ID: %2\n' +
                      '🎯 Endpoint: %3', StatusCode, CorrelationId, FunctionUrl);

            else
                Error('❌ Azure Function - Unexpected Error (%1 %2)\n\n' +
                      '📋 Response Details:\n%3\n\n' +
                      '🆔 Correlation ID: %4\n' +
                      '🎯 Endpoint: %5\n\n' +
                      '💡 Please contact support with the correlation ID.',
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

    procedure TestConnectivity(Setup: Record "eInvoiceSetup") TestResult: Boolean
    var
        TestPayload: JsonObject;
        TestText: Text;
        Response: HttpResponseMessage;
        RequestContent: HttpContent;
        Headers: HttpHeaders;
        CorrelationId: Text;
    begin
        CorrelationId := CreateGuid();

        // Prepare test payload
        TestPayload.Add('test', true);
        TestPayload.Add('correlationId', CorrelationId);
        TestPayload.Add('timestamp', Format(CurrentDateTime, 0, '<Year4>-<Month,2>-<Day,2>T<Hours24,2>:<Minutes,2>:<Seconds,2>Z'));
        TestPayload.Add('source', 'BusinessCentral-ConnectivityTest');
        TestPayload.WriteTo(TestText);

        RequestContent.WriteFrom(TestText);
        RequestContent.GetHeaders(Headers);
        Headers.Clear();
        Headers.Add('Content-Type', 'application/json');
        Headers.Add('User-Agent', 'BusinessCentral-eInvoice/1.0-Test');
        Headers.Add('X-Correlation-ID', CorrelationId);

        TestResult := Client.Post(Setup."Azure Function URL", RequestContent, Response) and Response.IsSuccessStatusCode();
    end;
}
