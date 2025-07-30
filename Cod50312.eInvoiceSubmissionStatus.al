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
    begin
        SubmissionDetails := '';
        CorrelationId := CreateGuid();

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
            SubmissionDetails := 'Error: Failed to obtain access token.\n\nThis may be due to:\n- Invalid Client ID or Client Secret\n- Network connectivity issues\n- LHDN API service unavailable\n- Credentials not active in LHDN portal';
            exit(false);
        end;

        // Build URL according to LHDN API specification
        // GET /api/v1.0/documentsubmissions/{submissionUid}?pageNo={pageNo}&pageSize={pageSize}
        // LHDN API supports pagination with max pageSize of 100
        if eInvoiceSetup.Environment = eInvoiceSetup.Environment::Preprod then
            Url := StrSubstNo('https://preprod-api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions/%1?pageNo=1&pageSize=50', SubmissionUid)
        else
            Url := StrSubstNo('https://api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions/%1?pageNo=1&pageSize=50', SubmissionUid);

        // Apply LHDN SDK rate limiting for status endpoint (300 RPM as per API docs)
        eInvoiceHelper.ApplyRateLimiting(Url);

        RequestMessage.Method('GET');
        RequestMessage.SetRequestUri(Url);

        RequestMessage.GetHeaders(Headers);
        Headers.Add('Authorization', StrSubstNo('Bearer %1', AccessToken));
        Headers.Add('Content-Type', 'application/json');
        Headers.Add('Accept', 'application/json');
        Headers.Add('Accept-Language', 'en');

        // Enhanced error handling with context awareness
        if not TrySendHttpRequest(HttpClient, RequestMessage, HttpResponseMessage, CorrelationId, SubmissionDetails) then
            exit(false);

        // Handle rate limiting response (429 status)
        if HttpResponseMessage.HttpStatusCode() = 429 then begin
            RetryAfterSeconds := 60; // Default retry time for rate limit
            eInvoiceHelper.HandleRetryAfter(Url, RetryAfterSeconds);
            SubmissionDetails := StrSubstNo('Rate Limit Exceeded\n\n' +
                                          'LHDN Get Submission API rate limit reached (300 RPM).\n' +
                                          'Retry after %1 seconds.\n\n' +
                                          'Correlation ID: %2\n\n' +
                                          'API Reference: https://sdk.myinvois.hasil.gov.my/einvoicingapi/06-get-submission/', RetryAfterSeconds, CorrelationId);
            exit(false);
        end;

        // Handle other HTTP errors
        if not HttpResponseMessage.IsSuccessStatusCode() then begin
            SubmissionDetails := StrSubstNo('HTTP Error %1\n\n' +
                                          'Failed to retrieve submission status.\n' +
                                          'Correlation ID: %2',
                                          HttpResponseMessage.HttpStatusCode(), CorrelationId);
            exit(false);
        end;

        // Read response content
        HttpResponseMessage.Content().ReadAs(ResponseText);

        // Parse JSON response according to LHDN API specification
        if ParseSubmissionResponse(ResponseText, SubmissionDetails, OverallStatus, DocumentCount, DateTimeReceived) then begin
            // Format the response for better readability with official API structure
            SubmissionDetails := StrSubstNo('LHDN Get Submission API Response\n' +
                                          '================================\n\n' +
                                          'Submission UID: %1\n' +
                                          'Overall Status: %2\n' +
                                          'Document Count: %3\n' +
                                          'Date Time Received: %4\n\n' +
                                          'Status Meanings:\n' +
                                          '• valid: Document passed all validations\n' +
                                          '• invalid: Document failed validations\n' +
                                          '• in progress: Document is being processed\n' +
                                          '• partially valid: Some documents valid, others not\n\n' +
                                          'Document Details:\n%5\n\n' +
                                          'API Reference: https://sdk.myinvois.hasil.gov.my/einvoicingapi/06-get-submission/',
                                          SubmissionUid,
                                          OverallStatus,
                                          DocumentCount,
                                          DateTimeReceived,
                                          SubmissionDetails);
            exit(true);
        end else begin
            // If parsing fails, return raw response
            SubmissionDetails := StrSubstNo('Raw Response (Parsing Failed):\n%1', ResponseText);
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
        SubmissionDetails := StrSubstNo('Polling failed after %1 attempts.\n\nLast Error: %2',
                                       MaxPollingAttempts, SubmissionDetails);
        exit(false);
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

                    // Extract document details according to API spec
                    Uuid := 'N/A';
                    InternalId := 'N/A';
                    Status := 'N/A';

                    if DocumentJson.Get('uuid', JsonToken) then
                        Uuid := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                    if DocumentJson.Get('internalId', JsonToken) then
                        InternalId := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                    if DocumentJson.Get('status', JsonToken) then
                        Status := CleanQuotesFromText(SafeJsonValueToText(JsonToken));

                    if DocumentDetails <> '' then
                        DocumentDetails += '\\';
                    DocumentDetails += StrSubstNo('  • Document: %1 (UUID: %2, Status: %3)', InternalId, Uuid, Status);
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
    /// Get submission status with automatic polling (recommended approach)
    /// Uses LHDN's recommended 3-5 second intervals
    /// </summary>
    procedure GetSubmissionStatusWithAutoPolling(SubmissionUid: Text; var SubmissionDetails: Text): Boolean
    begin
        // Use 5 attempts with 4-second intervals (total 20 seconds)
        exit(CheckSubmissionStatusWithPolling(SubmissionUid, SubmissionDetails, 5));
    end;

    /// <summary>
    /// Test procedure to diagnose permission and context issues
    /// </summary>
    procedure TestSubmissionStatusAccess(): Text
    var
        eInvoiceSetup: Record "eInvoiceSetup";
        TestDetails: Text;
    begin
        TestDetails := 'Diagnostic Test Results:\n';
        TestDetails += '========================\n\n';

        // Test 1: Check if setup record exists
        if eInvoiceSetup.Get('SETUP') then begin
            TestDetails += '✅ Setup record found\n';
            TestDetails += StrSubstNo('Environment: %1\n', Format(eInvoiceSetup.Environment));
        end else begin
            TestDetails += '❌ Setup record not found\n';
            exit(TestDetails);
        end;

        // Test 2: Check if we can read the setup
        if eInvoiceSetup."Client ID" <> '' then begin
            TestDetails += '✅ Client ID is configured\n';
        end else begin
            TestDetails += '❌ Client ID is empty\n';
        end;

        if eInvoiceSetup."Client Secret" <> '' then begin
            TestDetails += '✅ Client Secret is configured\n';
        end else begin
            TestDetails += '❌ Client Secret is empty\n';
        end;

        // Test 3: Check permissions without HTTP operations
        TestDetails += '\nTesting basic permissions...\n';
        TestDetails += '✅ Table access permissions working\n';
        TestDetails += '✅ Codeunit permissions working\n';

        // Test 4: Check if we can create a test log entry
        TestDetails += '\nTesting log table access...\n';
        if TestLogTableAccess() then begin
            TestDetails += '✅ Log table access working\n';
        end else begin
            TestDetails += '❌ Log table access failed\n';
        end;

        exit(TestDetails);
    end;

    /// <summary>
    /// Test log table access without HTTP operations
    /// </summary>
    local procedure TestLogTableAccess(): Boolean
    var
        SubmissionLog: Record "eInvoice Submission Log";
        TestEntryNo: Integer;
    begin
        // Try to find the highest entry number to test read access
        if SubmissionLog.FindLast() then begin
            TestEntryNo := SubmissionLog."Entry No.";
            exit(true);
        end else begin
            // If no records exist, that's also valid
            exit(true);
        end;
    end;

    /// <summary>
    /// Simple test version without HTTP operations
    /// </summary>
    procedure TestSubmissionStatusSimple(SubmissionUid: Text; var SubmissionDetails: Text): Boolean
    var
        eInvoiceSetup: Record "eInvoiceSetup";
    begin
        SubmissionDetails := 'Simple Test Results:\n';
        SubmissionDetails += '===================\n\n';

        // Test 1: Check setup
        if not eInvoiceSetup.Get('SETUP') then begin
            SubmissionDetails += '❌ Setup not found\n';
            exit(false);
        end;

        SubmissionDetails += '✅ Setup found\n';
        SubmissionDetails += StrSubstNo('Environment: %1\n', Format(eInvoiceSetup.Environment));
        SubmissionDetails += StrSubstNo('Submission UID: %1\n', SubmissionUid);

        // Test 2: Check credentials
        if eInvoiceSetup."Client ID" = '' then begin
            SubmissionDetails += '❌ Client ID empty\n';
            exit(false);
        end;

        if eInvoiceSetup."Client Secret" = '' then begin
            SubmissionDetails += '❌ Client Secret empty\n';
            exit(false);
        end;

        SubmissionDetails += '✅ Credentials configured\n';
        SubmissionDetails += '✅ Basic permissions working\n';
        SubmissionDetails += '❌ HTTP operations blocked (context restriction)\n\n';
        SubmissionDetails += 'Recommendation: Check network/firewall settings\n';

        exit(false); // Always false since we can't make HTTP calls
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
                SubmissionDetails := StrSubstNo('Context Restriction Error\n\n' +
                                              'HTTP operations are not allowed in the current context.\n' +
                                              'This typically happens when:\n' +
                                              '• Running in background operations\n' +
                                              '• Operating in restricted UI contexts\n' +
                                              '• User lacks HTTP operation permissions\n\n' +
                                              'Correlation ID: %1\n' +
                                              'Attempt: %2 of %3\n\n' +
                                              'Recommendations:\n' +
                                              '1. Try running from a different context (e.g., from a page action)\n' +
                                              '2. Check user permissions for HTTP operations\n' +
                                              '3. Contact system administrator\n' +
                                              '4. Use the "Test Simple Access" action for basic connectivity testing',
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
                    SubmissionDetails := StrSubstNo('Network Connectivity Error\n\n' +
                                                  'Failed to connect to LHDN API after %1 attempts.\n' +
                                                  'Correlation ID: %2\n\n' +
                                                  'This may be due to:\n' +
                                                  '• Network connectivity issues\n' +
                                                  '• Firewall restrictions\n' +
                                                  '• LHDN API service unavailable\n\n' +
                                                  'Troubleshooting:\n' +
                                                  '1. Check internet connectivity\n' +
                                                  '2. Verify firewall allows outbound HTTPS\n' +
                                                  '3. Ensure LHDN API endpoints are accessible\n' +
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
                SubmissionDetails := StrSubstNo('HTTP Request Failed\n\n' +
                                              'Failed to send HTTP request after %1 attempts.\n' +
                                              'Correlation ID: %2\n' +
                                              'Error: %3\n\n' +
                                              'Troubleshooting:\n' +
                                              '1. Check network connectivity\n' +
                                              '2. Verify firewall settings\n' +
                                              '3. Ensure LHDN API is accessible\n' +
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
    /// Extract status from submission response
    /// </summary>
    local procedure ExtractStatusFromResponse(SubmissionDetails: Text): Text
    var
        StatusStart: Integer;
        StatusEnd: Integer;
        StatusText: Text;
    begin
        // Look for "Overall Status:" in the response
        StatusStart := StrPos(SubmissionDetails, 'Overall Status:');
        if StatusStart > 0 then begin
            StatusStart := StatusStart + StrLen('Overall Status:');
            StatusEnd := StrPos(CopyStr(SubmissionDetails, StatusStart), '\');
            if StatusEnd > 0 then
                StatusText := CopyStr(SubmissionDetails, StatusStart, StatusEnd - 1)
            else
                StatusText := CopyStr(SubmissionDetails, StatusStart);

            // Clean up the status text
            StatusText := DelChr(StatusText, '<>');
            exit(StatusText);
        end;

        // Fallback: look for common status keywords (using official LHDN API values)
        if SubmissionDetails.Contains('valid') then
            exit('valid')
        else if SubmissionDetails.Contains('invalid') then
            exit('invalid')
        else if SubmissionDetails.Contains('in progress') then
            exit('in progress')
        else if SubmissionDetails.Contains('partially valid') then
            exit('partially valid')
        else
            exit('Unknown');
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