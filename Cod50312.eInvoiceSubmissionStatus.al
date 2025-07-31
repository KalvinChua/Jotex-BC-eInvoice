codeunit 50312 "eInvoice Submission Status"
{
    Permissions = tabledata "eInvoiceSetup" = R,
                  tabledata "eInvoice Submission Log" = RIMD,
                  tabledata "Company Information" = R;

    var
        eInvoiceHelper: Codeunit eInvoiceHelper;

    /// <summary>
    /// Check submission status using LHDN Get Submission API
    /// API: GET /api/v1.0/documentsubmissions/{{submissionUid}}?pageNo={{pageNo}}&amp;pageSize={{pageSize}}
    /// Rate Limit: 300 RPM per Client ID
    /// Enhanced with context restriction handling
    /// </summary>
    procedure CheckSubmissionStatus(SubmissionUid: Text; var SubmissionDetails: Text): Boolean
    var
        HttpClient: HttpClient;
        HttpResponseMessage: HttpResponseMessage;
        RequestMessage: HttpRequestMessage;
        AccessToken: Text;
        eInvoiceSetup: Record "eInvoiceSetup";
        Url: Text;
        Headers: HttpHeaders;
        RetryAfterSeconds: Integer;
        CorrelationId: Text;
        ResponseText: Text;
        JsonObject: JsonObject;
        JsonToken: JsonToken;
        OverallStatus: Text;
        DocumentCount: Integer;
        DateTimeReceived: Text;
        ContextRestrictionDetected: Boolean;
    begin
        SubmissionDetails := '';
        CorrelationId := CreateGuid();
        ContextRestrictionDetected := false;

        // Validate input parameters
        if SubmissionUid = '' then begin
            SubmissionDetails := 'Error: Submission UID is required.';
            exit(false);
        end;

        if not eInvoiceSetup.Get('SETUP') then begin
            SubmissionDetails := 'Error: eInvoice Setup not found.';
            exit(false);
        end;

        // Get access token using the public helper
        AccessToken := eInvoiceHelper.GetAccessTokenFromSetup(eInvoiceSetup);
        if AccessToken = '' then begin
            SubmissionDetails := 'Error: Failed to obtain access token.\\\\This may be due to:\\- Invalid Client ID or Client Secret\\- Network connectivity issues\\- LHDN API service unavailable\\- Credentials not active in LHDN portal\\- Context restrictions preventing HTTP operations';
            exit(false);
        end;

        // Build URL according to LHDN API specification
        // GET /api/v1.0/documentsubmissions/{submissionUid}
        // pageNo and pageSize are optional parameters
        if eInvoiceSetup.Environment = eInvoiceSetup.Environment::Preprod then
            Url := StrSubstNo('https://preprod-api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions/%1', SubmissionUid)
        else
            Url := StrSubstNo('https://api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions/%1', SubmissionUid);

        // Apply LHDN SDK rate limiting for status endpoint (300 RPM as per API docs)
        eInvoiceHelper.ApplyRateLimiting(Url);

        RequestMessage.Method('GET');
        RequestMessage.SetRequestUri(Url);

        RequestMessage.GetHeaders(Headers);
        Headers.Add('Authorization', StrSubstNo('Bearer %1', AccessToken));
        Headers.Add('Content-Type', 'application/json; charset=utf-8');
        Headers.Add('Accept', 'application/json');
        Headers.Add('Accept-Language', 'en');
        Headers.Add('User-Agent', 'BusinessCentral-eInvoice/2.0');
        Headers.Add('X-Correlation-ID', CorrelationId);
        Headers.Add('X-Request-Source', 'BusinessCentral-StatusCheck');

        // Enhanced error handling with context awareness
        if not TrySendHttpRequest(HttpClient, RequestMessage, HttpResponseMessage, CorrelationId, SubmissionDetails) then begin
            // Check if it's a context restriction
            if SubmissionDetails.Contains('Context Restriction Error') then begin
                ContextRestrictionDetected := true;
                SubmissionDetails := StrSubstNo('Context Restriction Detected\\\\' +
                                              'HTTP operations are not allowed in the current context.\\\\' +
                                              'Alternative Solutions:\\' +
                                              '1. Use "Manual Status Update" to set status manually\\' +
                                              '2. Try running from a different page or action\\' +
                                              '3. Use "Export to Excel" to get current data\\' +
                                              '4. Contact your system administrator\\\\' +
                                              'Session Details:\\' +
                                              '• User ID: %1\\' +
                                              '• Company: %2\\' +
                                              '• Current Time: %3\\' +
                                              '• Correlation ID: %4\\\\' +
                                              'LHDN API Reference: https://sdk.myinvois.hasil.gov.my/einvoicingapi/06-get-submission/',
                                              UserId, CompanyName, Format(CurrentDateTime), CorrelationId);
            end;
            exit(false);
        end;

        // Handle rate limiting response (429 status)
        if HttpResponseMessage.HttpStatusCode() = 429 then begin
            RetryAfterSeconds := 60; // Default retry time for rate limit
            eInvoiceHelper.HandleRetryAfter(Url, RetryAfterSeconds);
            SubmissionDetails := StrSubstNo('Rate Limit Exceeded\\\\' +
                                          'LHDN Get Submission API rate limit reached (300 RPM).\\' +
                                          'Retry after %1 seconds.\\\\' +
                                          'Correlation ID: %2\\\\' +
                                          'API Reference: https://sdk.myinvois.hasil.gov.my/einvoicingapi/06-get-submission/', RetryAfterSeconds, CorrelationId);
            exit(false);
        end;

        // Handle other HTTP errors
        if not HttpResponseMessage.IsSuccessStatusCode() then begin
            // Read error response for better error details
            HttpResponseMessage.Content().ReadAs(ResponseText);

            // Try to parse error response for more specific error messages
            if ParseErrorResponse(ResponseText, SubmissionDetails) then begin
                // Error response was parsed successfully
                exit(false);
            end else begin
                // Fallback to generic error message
                SubmissionDetails := StrSubstNo('HTTP Error %1\\\\' +
                                              'Failed to retrieve submission status.\\' +
                                              'Correlation ID: %2\\\\' +
                                              'This may be due to:\\' +
                                              '• Invalid submission UID\\' +
                                              '• Authentication issues\\' +
                                              '• LHDN API service problems\\\\' +
                                              'API Reference: https://sdk.myinvois.hasil.gov.my/einvoicingapi/06-get-submission/',
                                              HttpResponseMessage.HttpStatusCode(), CorrelationId);
                exit(false);
            end;
        end;

        // Read response content
        HttpResponseMessage.Content().ReadAs(ResponseText);

        // Parse JSON response according to LHDN API specification
        if ParseSubmissionResponse(ResponseText, SubmissionDetails, OverallStatus, DocumentCount, DateTimeReceived) then begin
            // Format the response for better readability with official API structure
            SubmissionDetails := StrSubstNo('LHDN Get Submission API Response\\' +
                                          '================================\\\\' +
                                          'Submission UID: %1\\' +
                                          'Overall Status: %2\\' +
                                          'Document Count: %3\\' +
                                          'Date Time Received: %4\\\\' +
                                          'Status Meanings:\\' +
                                          '• Valid: Document passed all validations\\' +
                                          '• Invalid: Document failed validations\\' +
                                          '• In Progress: Document is being processed\\' +
                                          '• Partially Valid: Some documents valid, others not\\\\' +
                                          'Document Details:\\%5\\\\' +
                                          'API Reference: https://sdk.myinvois.hasil.gov.my/einvoicingapi/06-get-submission/',
                                          SubmissionUid,
                                          OverallStatus,
                                          DocumentCount,
                                          DateTimeReceived,
                                          SubmissionDetails);
            exit(true);
        end else begin
            // If parsing fails, return raw response
            SubmissionDetails := StrSubstNo('Raw Response (Parsing Failed):\\%1', ResponseText);
            exit(true);
        end;
    end;

    /// <summary>
    /// Enhanced submission status check with polling strategy as per LHDN SDK
    /// LHDN recommends 3-5 second intervals between requests to avoid system throttling
    /// </summary>
    procedure CheckSubmissionStatusWithPolling(SubmissionUid: Text; var SubmissionDetails: Text; MaxPollingAttempts: Integer): Boolean
    var
        PollingAttempt: Integer;
        PollingDelayMs: Integer;
        IsSuccess: Boolean;
    begin
        PollingDelayMs := 4000; // 4 seconds between polling attempts (within 3-5 second recommendation as per API docs)

        for PollingAttempt := 1 to MaxPollingAttempts do begin
            IsSuccess := CheckSubmissionStatus(SubmissionUid, SubmissionDetails);

            if IsSuccess then
                exit(true);

            // If not the last attempt, wait before next poll
            if PollingAttempt < MaxPollingAttempts then begin
                Sleep(PollingDelayMs);
                PollingDelayMs := PollingDelayMs * 2; // Exponential backoff
            end;
        end;

        // All polling attempts failed
        SubmissionDetails := StrSubstNo('Polling failed after %1 attempts.\\\\Last Error: %2',
                                       MaxPollingAttempts, SubmissionDetails);
        exit(false);
    end;

    /// <summary>
    /// Parse LHDN error response according to their API specification
    /// Based on actual LHDN API error responses
    /// </summary>
    local procedure ParseErrorResponse(ResponseText: Text; var ErrorDetails: Text): Boolean
    var
        JsonObject: JsonObject;
        JsonToken: JsonToken;
        ErrorObject: JsonObject;
        DetailsArray: JsonArray;
        DetailObject: JsonObject;
        ErrorCode: Text;
        ErrorMessage: Text;
        Target: Text;
        DetailMessage: Text;
    begin
        if not JsonObject.ReadFrom(ResponseText) then
            exit(false);

        // Extract error object
        if not JsonObject.Get('error', JsonToken) then
            exit(false);

        if not JsonToken.IsObject() then
            exit(false);

        ErrorObject := JsonToken.AsObject();

        // Extract error code
        if ErrorObject.Get('code', JsonToken) then
            ErrorCode := CleanQuotesFromText(SafeJsonValueToText(JsonToken));

        // Extract error message
        if ErrorObject.Get('message', JsonToken) then
            ErrorMessage := CleanQuotesFromText(SafeJsonValueToText(JsonToken));

        // Extract target
        if ErrorObject.Get('target', JsonToken) then
            Target := CleanQuotesFromText(SafeJsonValueToText(JsonToken));

        // Extract details array
        if ErrorObject.Get('details', JsonToken) and JsonToken.IsArray() then begin
            DetailsArray := JsonToken.AsArray();
            if DetailsArray.Count() > 0 then begin
                DetailsArray.Get(0, JsonToken);
                if JsonToken.IsObject() then begin
                    DetailObject := JsonToken.AsObject();
                    if DetailObject.Get('message', JsonToken) then
                        DetailMessage := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                end;
            end;
        end;

        // Format error details
        ErrorDetails := StrSubstNo('LHDN API Error\\\\' +
                                  'Error Code: %1\\' +
                                  'Target: %2\\' +
                                  'Message: %3\\\\' +
                                  'Details: %4\\\\' +
                                  'This typically means:\\' +
                                  '• The submission UUID is incorrect or not found\\' +
                                  '• The submission may have been deleted\\' +
                                  '• The submission was made in a different environment\\\\' +
                                  'API Reference: https://sdk.myinvois.hasil.gov.my/einvoicingapi/06-get-submission/',
                                  ErrorCode, Target, ErrorMessage, DetailMessage);

        exit(true);
    end;

    /// <summary>
    /// Parse LHDN submission response according to their API specification
    /// Based on: https://sdk.myinvois.hasil.gov.my/einvoicingapi/06-get-submission/
    /// </summary>
    local procedure ParseSubmissionResponse(ResponseText: Text; var SubmissionDetails: Text; var OverallStatus: Text; var DocumentCount: Integer; var DateTimeReceived: Text): Boolean
    var
        JsonObject: JsonObject;
        JsonToken: JsonToken;
        DocumentSummaryArray: JsonArray;
        SubmissionUid: Text;
        DocumentSummaryCount: Integer;
        i: Integer;
        DocumentJson: JsonObject;
        Uuid: Text;
        InternalId: Text;
        Status: Text;
        IssuerName: Text;
        ReceiverName: Text;
        TotalAmount: Text;
        DocumentDetails: Text;
    begin
        OverallStatus := '';
        DocumentCount := 0;
        DateTimeReceived := '';
        SubmissionUid := '';

        if not JsonObject.ReadFrom(ResponseText) then
            exit(false);

        // Extract submissionUid (official API field)
        if JsonObject.Get('submissionUid', JsonToken) then
            SubmissionUid := CleanQuotesFromText(SafeJsonValueToText(JsonToken));

        // Extract overallStatus (official API values: in progress, valid, partially valid, invalid)
        if JsonObject.Get('overallStatus', JsonToken) then
            OverallStatus := CleanQuotesFromText(SafeJsonValueToText(JsonToken));

        // Extract documentCount (official API field)
        if JsonObject.Get('documentCount', JsonToken) then
            DocumentCount := JsonToken.AsValue().AsInteger();

        // Extract dateTimeReceived (official API field)
        if JsonObject.Get('dateTimeReceived', JsonToken) then
            DateTimeReceived := CleanQuotesFromText(SafeJsonValueToText(JsonToken));

        // Extract documentSummary array (official API structure)
        if JsonObject.Get('documentSummary', JsonToken) and JsonToken.IsArray() then begin
            DocumentSummaryArray := JsonToken.AsArray();
            DocumentSummaryCount := DocumentSummaryArray.Count();

            // Build document details for display
            DocumentDetails := '';
            for i := 0 to DocumentSummaryCount - 1 do begin
                DocumentSummaryArray.Get(i, JsonToken);
                if JsonToken.IsObject() then begin
                    DocumentJson := JsonToken.AsObject();

                    // Extract document details according to actual API response
                    Uuid := 'N/A';
                    InternalId := 'N/A';
                    Status := 'N/A';
                    IssuerName := 'N/A';
                    ReceiverName := 'N/A';
                    TotalAmount := 'N/A';

                    if DocumentJson.Get('uuid', JsonToken) then
                        Uuid := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                    if DocumentJson.Get('internalId', JsonToken) then
                        InternalId := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                    if DocumentJson.Get('status', JsonToken) then
                        Status := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                    if DocumentJson.Get('issuerName', JsonToken) then
                        IssuerName := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                    if DocumentJson.Get('receiverName', JsonToken) then
                        ReceiverName := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                    if DocumentJson.Get('totalPayableAmount', JsonToken) then
                        TotalAmount := Format(JsonToken.AsValue().AsDecimal());

                    if DocumentDetails <> '' then
                        DocumentDetails += '\\';
                    DocumentDetails += StrSubstNo('  • Document: %1 (UUID: %2, Status: %3)\\    Issuer: %4\\    Receiver: %5\\    Amount: %6',
                                                InternalId, Uuid, Status, IssuerName, ReceiverName, TotalAmount);
                end;
            end;

            // Update submission details with document information
            if DocumentDetails <> '' then begin
                SubmissionDetails := StrSubstNo('Document Details:\\%1', DocumentDetails);
            end;
        end;

        exit(true);
    end;

    /// <summary>
    /// Get submission UID from LHDN API
    /// Simplified method to get just the submission UID from the API
    /// </summary>


    /// <summary>
    /// Get submission status with automatic polling (recommended approach)
    /// Uses LHDN's recommended 3-5 second intervals
    /// </summary>
    procedure GetSubmissionStatusWithAutoPolling(SubmissionUid: Text; var SubmissionDetails: Text): Boolean
    begin
        // Use 5 attempts with 4-second intervals (total 20 seconds)
        exit(CheckSubmissionStatusWithPolling(SubmissionUid, SubmissionDetails, 5));
    end;

    /// <summary>
    /// Get submission UID from LHDN API response
    /// Simplified method to extract just the submission UID from the API response
    /// </summary>


    /// <summary>
    /// Alternative status check method that doesn't require HTTP operations
    /// Useful when context restrictions prevent HTTP calls
    /// </summary>
    procedure CheckSubmissionStatusAlternative(SubmissionUid: Text; var SubmissionDetails: Text): Boolean
    var
        SubmissionLog: Record "eInvoice Submission Log";
        LogEntry: Record "eInvoice Submission Log";
        StatusCount: Integer;
        ValidCount: Integer;
        InvalidCount: Integer;
        InProgressCount: Integer;
        PartiallyValidCount: Integer;
        UnknownCount: Integer;
    begin
        SubmissionDetails := '';

        // Validate input parameters
        if SubmissionUid = '' then begin
            SubmissionDetails := 'Error: Submission UID is required.';
            exit(false);
        end;

        // Try to find existing log entries for this submission UID
        SubmissionLog.SetRange("Submission UID", SubmissionUid);
        if not SubmissionLog.FindSet() then begin
            SubmissionDetails := StrSubstNo('No log entries found for submission UID: %1\\\\' +
                                          'This may mean:\\' +
                                          '• The submission was not logged\\' +
                                          '• The submission UID is incorrect\\' +
                                          '• The submission was made in a different company\\\\' +
                                          'Alternative Solutions:\\' +
                                          '1. Check the submission UID is correct\\' +
                                          '2. Use "Create Test Entry" to add a test record\\' +
                                          '3. Export current data to Excel for analysis',
                                          SubmissionUid);
            exit(false);
        end;

        // Analyze existing log entries
        repeat
            StatusCount += 1;
            case SubmissionLog.Status of
                'Valid':
                    ValidCount += 1;
                'Invalid':
                    InvalidCount += 1;
                'In Progress':
                    InProgressCount += 1;
                'Partially Valid':
                    PartiallyValidCount += 1;
                else
                    UnknownCount += 1;
            end;
        until SubmissionLog.Next() = 0;

        // Generate status summary
        SubmissionDetails := StrSubstNo('Submission Status Analysis (Local Data)\\' +
                                      '=====================================\\\\' +
                                      'Submission UID: %1\\' +
                                      'Total Log Entries: %2\\\\' +
                                      'Status Breakdown:\\' +
                                      '• Valid: %3\\' +
                                      '• Invalid: %4\\' +
                                      '• In Progress: %5\\' +
                                      '• Partially Valid: %6\\' +
                                      '• Unknown: %7\\\\' +
                                      'Note: This is based on local log data.\\' +
                                      'For real-time status, try:\\' +
                                      '1. Running from a different context\\' +
                                      '2. Using "Refresh Status (Local Analysis)"\\' +
                                      '3. Contacting system administrator\\\\' +
                                      'LHDN API Reference: https://sdk.myinvois.hasil.gov.my/einvoicingapi/06-get-submission/',
                                      SubmissionUid,
                                      StatusCount,
                                      ValidCount,
                                      InvalidCount,
                                      InProgressCount,
                                      PartiallyValidCount,
                                      UnknownCount);

        exit(true);
    end;

    /// <summary>
    /// Test submission status access without making HTTP calls
    /// Useful for diagnosing context restrictions
    /// </summary>
    procedure TestSubmissionStatusAccess(): Text
    var
        eInvoiceSetup: Record "eInvoiceSetup";
        TestResults: Text;
        AccessToken: Text;
    begin
        TestResults := 'Submission Status Access Test\\' +
                      '===========================\\' +
                      '\\';

        // Test 1: Check if setup exists
        if eInvoiceSetup.Get('SETUP') then begin
            TestResults += 'eInvoice Setup found\\';
            TestResults += StrSubstNo('  Environment: %1\\', eInvoiceSetup.Environment);
        end else begin
            TestResults += 'eInvoice Setup not found\\';
            TestResults += '  Please configure eInvoice Setup first\\';
        end;

        // Test 2: Check access token (without HTTP call)
        if eInvoiceSetup.Get('SETUP') then begin
            AccessToken := eInvoiceHelper.GetAccessTokenFromSetup(eInvoiceSetup);
            if AccessToken <> '' then begin
                TestResults += 'Access token available\\';
            end else begin
                TestResults += 'Access token not available\\';
                TestResults += '  This may be due to context restrictions\\';
            end;
        end;

        // Test 3: Check permissions
        TestResults += StrSubstNo('\\User Information:\\');
        TestResults += StrSubstNo('• User ID: %1\\', UserId);
        TestResults += StrSubstNo('• Company: %2\\', CompanyName);
        TestResults += StrSubstNo('• Current Time: %3\\', Format(CurrentDateTime, 0, '<Day,2>/<Month,2>/<Year4> <Hours24,2>:<Minutes,2> <AM/PM>'));

        // Test 4: Context information
        TestResults += '\\Context Analysis:\\';
        TestResults += '• HTTP operations may be restricted in current context\\';
        TestResults += '• Try running from a different page or action\\';
        TestResults += '• Use "Refresh Status (Local Analysis)" as alternative\\';

        TestResults += '\\Recommendations:\\';
        TestResults += '1. Try running from the main e-Invoice Submission Log page\\';
        TestResults += '2. Use "Export to Excel" to get current data\\';
        TestResults += '3. Contact system administrator for HTTP permissions\\';
        TestResults += '4. Check LHDN API documentation for troubleshooting\\';

        TestResults += '\\API Reference: https://sdk.myinvois.hasil.gov.my/einvoicingapi/06-get-submission/';

        exit(TestResults);
    end;



    /// <summary>
    /// Enhanced HTTP request sending with context awareness and retry logic
    /// </summary>
    local procedure TrySendHttpRequest(var HttpClient: HttpClient; var RequestMessage: HttpRequestMessage; var HttpResponseMessage: HttpResponseMessage; CorrelationId: Text; var SubmissionDetails: Text): Boolean
    var
        RetryAttempt: Integer;
        MaxRetries: Integer;
        RetryDelayMs: Integer;
        IsSuccess: Boolean;
        ErrorMessage: Text;
    begin
        MaxRetries := 3;
        RetryDelayMs := 2000; // 2 seconds between retries

        for RetryAttempt := 1 to MaxRetries do begin
            // Try to send the HTTP request
            IsSuccess := HttpClient.Send(RequestMessage, HttpResponseMessage);

            if IsSuccess then
                exit(true);

            // If failed, determine the error type and handle accordingly
            ErrorMessage := GetLastErrorText();

            // Check if it's a context restriction error
            if ErrorMessage.Contains('cannot be performed in this context') or
               ErrorMessage.Contains('context') then begin
                SubmissionDetails := StrSubstNo('Context Restriction Error\\\\' +
                                              'HTTP operations are not allowed in the current context.\\' +
                                              'This typically happens when:\\' +
                                              '• Running in background operations\\' +
                                              '• Operating in restricted UI contexts\\' +
                                              '• User lacks HTTP operation permissions\\\\' +
                                              'Correlation ID: %1\\' +
                                              'Attempt: %2 of %3\\\\' +
                                              'Recommendations:\\' +
                                              '1. Try running from a different context (e.g., from a page action)\\' +
                                              '2. Check user permissions for HTTP operations\\' +
                                              '3. Contact system administrator\\' +
                                              '4. Use the "Test Context Access" action for basic connectivity testing',
                                              CorrelationId, RetryAttempt, MaxRetries);
                exit(false);
            end;

            // Check if it's a network connectivity issue
            if ErrorMessage.Contains('network') or
               ErrorMessage.Contains('connection') or
               ErrorMessage.Contains('timeout') then begin
                if RetryAttempt < MaxRetries then begin
                    Sleep(RetryDelayMs);
                    continue;
                end else begin
                    SubmissionDetails := StrSubstNo('Network Connectivity Error\\\\' +
                                                  'Failed to connect to LHDN API after %1 attempts.\\' +
                                                  'Correlation ID: %2\\\\' +
                                                  'This may be due to:\\' +
                                                  '• Network connectivity issues\\' +
                                                  '• Firewall restrictions\\' +
                                                  '• LHDN API service unavailable\\\\' +
                                                  'Troubleshooting:\\' +
                                                  '1. Check internet connectivity\\' +
                                                  '2. Verify firewall allows outbound HTTPS\\' +
                                                  '3. Ensure LHDN API endpoints are accessible\\' +
                                                  '4. Try again in a few seconds',
                                                  MaxRetries, CorrelationId);
                    exit(false);
                end;
            end;

            // Generic error handling
            if RetryAttempt < MaxRetries then begin
                Sleep(RetryDelayMs);
                continue;
            end else begin
                SubmissionDetails := StrSubstNo('HTTP Request Failed\\\\' +
                                              'Failed to send HTTP request after %1 attempts.\\' +
                                              'Correlation ID: %2\\' +
                                              'Error: %3\\\\' +
                                              'Troubleshooting:\\' +
                                              '1. Check network connectivity\\' +
                                              '2. Verify firewall settings\\' +
                                              '3. Ensure LHDN API is accessible\\' +
                                              '4. Try again later',
                                              MaxRetries, CorrelationId, ErrorMessage);
                exit(false);
            end;
        end;

        exit(false);
    end;

    /// <summary>
    /// Removes surrounding quotes from text values
    /// </summary>
    /// <param name="InputText">Text that may contain surrounding quotes</param>
    /// <returns>Text with quotes removed</returns>
    local procedure CleanQuotesFromText(InputText: Text): Text
    var
        CleanText: Text;
    begin
        if InputText = '' then
            exit('');

        CleanText := InputText;

        // Remove leading quote if present
        if StrPos(CleanText, '"') = 1 then
            CleanText := CopyStr(CleanText, 2);

        // Remove trailing quote if present
        if StrLen(CleanText) > 0 then
            if CopyStr(CleanText, StrLen(CleanText), 1) = '"' then
                CleanText := CopyStr(CleanText, 1, StrLen(CleanText) - 1);

        exit(CleanText);
    end;

    /// <summary>
    /// Safely converts JSON token to text
    /// </summary>
    /// <param name="JsonToken">JSON token to convert</param>
    /// <returns>Text representation of the JSON value</returns>
    local procedure SafeJsonValueToText(JsonToken: JsonToken): Text
    begin
        if JsonToken.IsValue() then begin
            exit(Format(JsonToken.AsValue()));
        end else if JsonToken.IsObject() then begin
            exit('JSON Object');
        end else if JsonToken.IsArray() then begin
            exit('JSON Array');
        end else begin
            exit('Unknown');
        end;
    end;

    /// <summary>
    /// Background job procedure to refresh submission statuses
    /// This procedure is designed to be called from TaskScheduler to avoid context restrictions
    /// </summary>
    procedure RefreshSubmissionStatusesBackground()
    var
        SubmissionLog: Record "eInvoice Submission Log";
        SubmissionDetails: Text;
        ApiSuccess: Boolean;
        UpdatedCount: Integer;
        ProcessedCount: Integer;
    begin
        UpdatedCount := 0;
        ProcessedCount := 0;

        // Process all log entries that have submission UIDs
        if SubmissionLog.FindSet() then begin
            repeat
                if SubmissionLog."Submission UID" <> '' then begin
                    ProcessedCount += 1;

                    // Use the polling approach for better reliability
                    ApiSuccess := GetSubmissionStatusWithAutoPolling(SubmissionLog."Submission UID", SubmissionDetails);

                    if ApiSuccess then begin
                        // Update the log entry with current status
                        SubmissionLog."Status" := ExtractStatusFromResponse(SubmissionDetails);
                        SubmissionLog."Response Date" := CurrentDateTime;
                        SubmissionLog."Last Updated" := CurrentDateTime;
                        SubmissionLog.Modify();
                        UpdatedCount += 1;
                    end else begin
                        // Log the error but continue processing
                        SubmissionLog."Error Message" := CopyStr(SubmissionDetails, 1, 250);
                        SubmissionLog."Last Updated" := CurrentDateTime;
                        SubmissionLog.Modify();
                    end;

                    // Add delay between requests to respect rate limits
                    if ProcessedCount < SubmissionLog.Count() then
                        Sleep(4000); // 4 second delay between requests
                end;
            until SubmissionLog.Next() = 0;
        end;

        // Log the completion
        LogBackgroundJobCompletion(UpdatedCount, ProcessedCount);
    end;

    /// <summary>
    /// Handle background job processing for status refresh
    /// This procedure is called by the Job Queue to process status refresh in the background
    /// </summary>
    procedure ProcessBackgroundStatusRefresh()
    var
        SubmissionLog: Record "eInvoice Submission Log";
        SubmissionDetails: Text;
        ApiSuccess: Boolean;
        UpdatedCount: Integer;
        ProcessedCount: Integer;
        ErrorCount: Integer;
        BackgroundLog: Record "eInvoice Submission Log";
    begin
        UpdatedCount := 0;
        ProcessedCount := 0;
        ErrorCount := 0;

        // Find all log entries with submission UIDs that need status refresh
        SubmissionLog.SetRange("Submission UID", '');
        SubmissionLog.SetFilter("Submission UID", '<>%1', '');

        if SubmissionLog.FindSet() then begin
            repeat
                ProcessedCount += 1;

                // Check status using LHDN API
                ApiSuccess := CheckSubmissionStatus(SubmissionLog."Submission UID", SubmissionDetails);

                if ApiSuccess then begin
                    // Update the log entry with current status
                    SubmissionLog."Status" := ExtractStatusFromResponse(SubmissionDetails);
                    SubmissionLog."Response Date" := CurrentDateTime;
                    SubmissionLog."Last Updated" := CurrentDateTime;
                    SubmissionLog."Error Message" := '';

                    if SubmissionLog.Modify() then
                        UpdatedCount += 1;
                end else begin
                    // Log the error
                    SubmissionLog."Error Message" := CopyStr(SubmissionDetails, 1, 250);
                    SubmissionLog."Last Updated" := CurrentDateTime;
                    SubmissionLog.Modify();
                    ErrorCount += 1;
                end;

                // Add delay between requests to respect LHDN rate limiting
                Sleep(4000); // 4 seconds between requests

            until SubmissionLog.Next() = 0;
        end;

        // Create a log entry to record the background job completion
        BackgroundLog.Init();
        BackgroundLog."Entry No." := 0; // Auto-increment
        BackgroundLog."Invoice No." := 'BACKGROUND-JOB';
        BackgroundLog."Customer Name" := 'System';
        BackgroundLog."Submission UID" := 'BACKGROUND-' + Format(CurrentDateTime, 0, '<Year4><Month,2><Day,2><Hours24,2><Minutes,2><Seconds,2>');
        BackgroundLog."Document UUID" := '';
        BackgroundLog.Status := 'Completed';
        BackgroundLog."Submission Date" := CurrentDateTime;
        BackgroundLog."Response Date" := CurrentDateTime;
        BackgroundLog."Last Updated" := CurrentDateTime;
        BackgroundLog."User ID" := UserId;
        BackgroundLog."Company Name" := CompanyName;
        BackgroundLog."Error Message" := StrSubstNo('Background job completed. Processed: %1, Updated: %2, Errors: %3',
                                                   ProcessedCount, UpdatedCount, ErrorCount);
        BackgroundLog.Environment := BackgroundLog.Environment::Preprod;
        BackgroundLog.Insert();
    end;

    /// <summary>
    /// Extract status from response text with proper capitalization
    /// </summary>
    local procedure ExtractStatusFromResponse(ResponseText: Text): Text
    var
        Status: Text;
        JsonObject: JsonObject;
        JsonToken: JsonToken;
    begin
        // Try to parse JSON response first for more accurate status extraction
        if JsonObject.ReadFrom(ResponseText) then begin
            if JsonObject.Get('overallStatus', JsonToken) then begin
                Status := JsonToken.AsValue().AsText();
                // Convert to proper capitalization for display
                case Status of
                    'valid':
                        exit('Valid');
                    'invalid':
                        exit('Invalid');
                    'in progress':
                        exit('In Progress');
                    'partially valid':
                        exit('Partially Valid');
                    else
                        exit(Status);
                end;
            end;
        end;

        // Fallback to text parsing if JSON parsing fails
        if ResponseText.Contains('Overall Status: valid') then
            Status := 'Valid'
        else if ResponseText.Contains('Overall Status: invalid') then
            Status := 'Invalid'
        else if ResponseText.Contains('Overall Status: in progress') then
            Status := 'In Progress'
        else if ResponseText.Contains('Overall Status: partially valid') then
            Status := 'Partially Valid'
        else
            Status := 'Unknown';

        exit(Status);
    end;

    /// <summary>
    /// Log background job completion for monitoring
    /// </summary>
    local procedure LogBackgroundJobCompletion(UpdatedCount: Integer; ProcessedCount: Integer)
    var
        JobQueueLogEntry: Record "Job Queue Log Entry";
        LogEntryNo: Integer;
    begin
        if JobQueueLogEntry.FindLast() then
            LogEntryNo := JobQueueLogEntry."Entry No." + 1
        else
            LogEntryNo := 1;

        JobQueueLogEntry.Init();
        JobQueueLogEntry."Entry No." := LogEntryNo;
        JobQueueLogEntry."Status" := JobQueueLogEntry.Status::Success;
        JobQueueLogEntry."Start Date/Time" := CurrentDateTime;
        JobQueueLogEntry."End Date/Time" := CurrentDateTime;
        JobQueueLogEntry."Object Type to Run" := JobQueueLogEntry."Object Type to Run"::Codeunit;
        JobQueueLogEntry."Object ID to Run" := Codeunit::"eInvoice Submission Status";
        JobQueueLogEntry."Job Queue Category Code" := 'EINVOICE';
        JobQueueLogEntry."Description" := StrSubstNo('eInvoice Status Refresh - Updated: %1, Processed: %2', UpdatedCount, ProcessedCount);
        JobQueueLogEntry.Insert();
    end;

    /// <summary>
    /// Job queue entry point for status refresh
    /// This procedure is called by the job queue system
    /// </summary>
    procedure RefreshStatusesFromJobQueue()
    begin
        RefreshSubmissionStatusesBackground();
    end;


}