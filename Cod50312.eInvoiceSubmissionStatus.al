codeunit 50312 "eInvoice Submission Status"
{
    Permissions = tabledata "eInvoiceSetup" = R,
                  tabledata "eInvoice Submission Log" = RIMD,
                  tabledata "Sales Invoice Header" = M,
                  tabledata "Company Information" = R;

    var
        eInvoiceHelper: Codeunit eInvoiceHelper;

    /// <summary>
    /// OnRun trigger - handles background job execution for status refresh
    /// Called by Job Queue when background refresh is needed
    /// </summary>
    trigger OnRun()
    begin
        // Handle background status refresh from job queue with enhanced error handling
        ProcessBackgroundStatusRefreshSafe();
    end;

    /// <summary>
    /// Check submission status using LHDN Get Submission API
    /// API: GET /api/v1.0/documentsubmissions/{submissionUid}?pageNo={pageNo}&amp;pageSize={pageSize}
    /// Rate Limit: 300 RPM per Client ID
    /// Enhanced with context restriction handling and proper pagination
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

        // Validate submission UID format
        if not ValidateSubmissionUid(SubmissionUid) then begin
            SubmissionDetails := StrSubstNo('Error: Invalid Submission UID format: %1\\\\' +
                                          'Submission UID should be:\\' +
                                          '- 10-50 characters long\\' +
                                          '- Contain only letters, numbers, hyphens, and underscores\\' +
                                          '- Not be empty\\\\' +
                                          'Example: HJSD135P2S7D8IU or ABC-123_XYZ',
                                          SubmissionUid);
            exit(false);
        end;

        if not eInvoiceSetup.Get('SETUP') then begin
            SubmissionDetails := 'Error: eInvoice Setup not found.';
            exit(false);
        end;

        // Get access token using the public helper
        eInvoiceHelper.InitializeHelper();
        AccessToken := eInvoiceHelper.GetAccessTokenFromSetup(eInvoiceSetup);
        if AccessToken = '' then begin
            SubmissionDetails := 'Error: Failed to obtain access token.\\\\This may be due to:\\- Invalid Client ID or Client Secret\\- Network connectivity issues\\- LHDN API service unavailable\\- Credentials not active in LHDN portal\\- Context restrictions preventing HTTP operations';
            exit(false);
        end;

        // Build URL according to LHDN API specification
        // GET /api/v1.0/documentsubmissions/{submissionUid}
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

        // Use direct HttpClient.Send() method (same as working Document Types API)
        if HttpClient.Send(RequestMessage, HttpResponseMessage) then begin
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
                                                  '- Invalid submission UID\\' +
                                                  '- Authentication issues\\' +
                                                  '- LHDN API service problems\\\\' +
                                                  'API Reference: https://sdk.myinvois.hasil.gov.my/einvoicingapi/06-get-submission/',
                                                  HttpResponseMessage.HttpStatusCode(), CorrelationId);
                    exit(false);
                end;
            end;
        end else begin
            // Handle HTTP send failure with context-aware error detection
            SubmissionDetails := StrSubstNo('HTTP Request Failed\\\\' +
                                          'Failed to send HTTP request to LHDN API.\\' +
                                          'Correlation ID: %1\\' +
                                          'Error: %2\\\\' +
                                          'This may indicate:\\' +
                                          '- Network connectivity issues\\' +
                                          '- HTTP context restrictions\\' +
                                          '- Authentication/authorization issues\\' +
                                          '- LHDN service temporarily unavailable\\\\' +
                                          'LHDN References:\\' +
                                          '- Error Codes: https://sdk.myinvois.hasil.gov.my/standard-error-response/\\' +
                                          '- Headers: https://sdk.myinvois.hasil.gov.my/standard-header-parameters/\\' +
                                          '- API Docs: https://sdk.myinvois.hasil.gov.my/api/',
                                          CorrelationId, GetLastErrorText());
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
                                              '- Invalid submission UID\\' +
                                              '- Authentication issues\\' +
                                              '- LHDN API service problems\\\\' +
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
                                          '- in progress: Documents are being processed\\' +
                                          '- valid: All documents passed validations\\' +
                                          '- invalid: All documents failed validations\\' +
                                          '- partially valid: Some documents valid, others invalid\\\\' +
                                          'Document Summary:\\%5\\\\' +
                                          'Note: For large submissions with many documents, \\' +
                                          'use "Get Complete Submission" for paginated results.\\\\' +
                                          'API Reference: https://sdk.myinvois.hasil.gov.my/einvoicingapi/06-get-submission/',
                                          SubmissionUid,
                                          OverallStatus,
                                          DocumentCount,
                                          DateTimeReceived,
                                          SubmissionDetails);
            exit(true);
        end else begin
            // If parsing fails, return raw response with better formatting
            SubmissionDetails := StrSubstNo('Raw API Response (Parsing Failed):\\\\' +
                                          'Correlation ID: %1\\' +
                                          'Response Text: %2\\\\' +
                                          'This may indicate:\\' +
                                          '- API response format has changed\\' +
                                          '- Network connectivity issues\\' +
                                          '- Invalid JSON response\\\\' +
                                          'Please check LHDN API documentation for updates.',
                                          CorrelationId, ResponseText);
            exit(true);
        end;
    end;

    /// <summary>
    /// Get complete submission details with pagination support
    /// Retrieves all pages of document summary for large submissions
    /// Uses LHDN recommended 3-5 second intervals between requests
    /// </summary>
    procedure GetCompleteSubmissionStatus(SubmissionUid: Text; var SubmissionDetails: Text): Boolean
    var
        HttpClient: HttpClient;
        HttpResponseMessage: HttpResponseMessage;
        RequestMessage: HttpRequestMessage;
        AccessToken: Text;
        eInvoiceSetup: Record "eInvoiceSetup";
        Url: Text;
        Headers: HttpHeaders;
        CorrelationId: Text;
        ResponseText: Text;
        JsonObject: JsonObject;
        JsonToken: JsonToken;
        OverallStatus: Text;
        DocumentCount: Integer;
        DateTimeReceived: Text;
        PageNo: Integer;
        PageSize: Integer;
        TotalPages: Integer;
        AllDocumentDetails: Text;
        PageDetails: Text;
        CurrentPageDocCount: Integer;
        RetrievedDocCount: Integer;
        IsSuccess: Boolean;
    begin
        SubmissionDetails := '';
        CorrelationId := CreateGuid();
        PageNo := 1;
        PageSize := 100; // Maximum page size per API documentation
        TotalPages := 1;
        AllDocumentDetails := '';
        RetrievedDocCount := 0;

        // Validate input parameters
        if SubmissionUid = '' then begin
            SubmissionDetails := 'Error: Submission UID is required.';
            exit(false);
        end;

        if not eInvoiceSetup.Get('SETUP') then begin
            SubmissionDetails := 'Error: eInvoice Setup not found.';
            exit(false);
        end;

        // Get access token
        eInvoiceHelper.InitializeHelper();
        AccessToken := eInvoiceHelper.GetAccessTokenFromSetup(eInvoiceSetup);
        if AccessToken = '' then begin
            SubmissionDetails := 'Error: Failed to obtain access token.';
            exit(false);
        end;

        // Get first page to determine total document count
        IsSuccess := GetSubmissionPage(SubmissionUid, PageNo, PageSize, eInvoiceSetup, AccessToken, CorrelationId,
                                     ResponseText, OverallStatus, DocumentCount, DateTimeReceived, PageDetails);

        if not IsSuccess then begin
            SubmissionDetails := PageDetails;
            exit(false);
        end;

        AllDocumentDetails := PageDetails;
        CurrentPageDocCount := GetDocumentCountFromPage(ResponseText);
        RetrievedDocCount := CurrentPageDocCount;

        // Calculate total pages needed
        if DocumentCount > PageSize then begin
            TotalPages := (DocumentCount + PageSize - 1) div PageSize;

            // Retrieve remaining pages with proper rate limiting
            for PageNo := 2 to TotalPages do begin
                // Apply 4-second delay between requests (within LHDN 3-5 second recommendation)
                Sleep(4000);

                IsSuccess := GetSubmissionPage(SubmissionUid, PageNo, PageSize, eInvoiceSetup, AccessToken, CorrelationId,
                                             ResponseText, OverallStatus, DocumentCount, DateTimeReceived, PageDetails);

                if IsSuccess then begin
                    if AllDocumentDetails <> '' then
                        AllDocumentDetails += '\\\\';
                    AllDocumentDetails += StrSubstNo('Page %1:\\%2', PageNo, PageDetails);
                    CurrentPageDocCount := GetDocumentCountFromPage(ResponseText);
                    RetrievedDocCount += CurrentPageDocCount;
                end else begin
                    // Log error but continue with partial results
                    AllDocumentDetails += StrSubstNo('\\\\Page %1 Error: %2', PageNo, PageDetails);
                end;

                // Stop if we've retrieved all documents
                if RetrievedDocCount >= DocumentCount then
                    break;
            end;
        end;

        // Format complete response
        SubmissionDetails := StrSubstNo('LHDN Complete Submission Details\\' +
                                      '==============================\\\\' +
                                      'Submission UID: %1\\' +
                                      'Overall Status: %2\\' +
                                      'Total Documents: %3\\' +
                                      'Retrieved Documents: %4\\' +
                                      'Total Pages: %5\\' +
                                      'Date Time Received: %6\\\\' +
                                      'Status Values:\\' +
                                      '- in progress: Documents being processed\\' +
                                      '- valid: All documents passed validations\\' +
                                      '- invalid: All documents failed validations\\' +
                                      '- partially valid: Mixed document statuses\\\\' +
                                      'Complete Document Summary:\\%7\\\\' +
                                      'Rate Limiting: 4-second intervals used between page requests\\' +
                                      'API Reference: https://sdk.myinvois.hasil.gov.my/einvoicingapi/06-get-submission/',
                                      SubmissionUid,
                                      OverallStatus,
                                      DocumentCount,
                                      RetrievedDocCount,
                                      TotalPages,
                                      DateTimeReceived,
                                      AllDocumentDetails);

        exit(true);
    end;

    /// <summary>
    /// Helper procedure to get a specific page of submission data
    /// </summary>
    local procedure GetSubmissionPage(SubmissionUid: Text; PageNo: Integer; PageSize: Integer; var eInvoiceSetup: Record "eInvoiceSetup"; AccessToken: Text; CorrelationId: Text; var ResponseText: Text; var OverallStatus: Text; var DocumentCount: Integer; var DateTimeReceived: Text; var PageDetails: Text): Boolean
    var
        HttpClient: HttpClient;
        HttpResponseMessage: HttpResponseMessage;
        RequestMessage: HttpRequestMessage;
        Url: Text;
        Headers: HttpHeaders;
    begin
        // Build paginated URL
        if eInvoiceSetup.Environment = eInvoiceSetup.Environment::Preprod then
            Url := StrSubstNo('https://preprod-api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions/%1?pageNo=%2&pageSize=%3', SubmissionUid, PageNo, PageSize)
        else
            Url := StrSubstNo('https://api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions/%1?pageNo=%2&pageSize=%3', SubmissionUid, PageNo, PageSize);

        // Apply rate limiting
        eInvoiceHelper.ApplyRateLimiting(Url);

        // Prepare request
        RequestMessage.Method('GET');
        RequestMessage.SetRequestUri(Url);
        RequestMessage.GetHeaders(Headers);
        Headers.Add('Authorization', StrSubstNo('Bearer %1', AccessToken));
        Headers.Add('Content-Type', 'application/json; charset=utf-8');
        Headers.Add('Accept', 'application/json');
        Headers.Add('Accept-Language', 'en');
        Headers.Add('User-Agent', 'BusinessCentral-eInvoice/2.0');
        Headers.Add('X-Correlation-ID', CorrelationId);
        Headers.Add('X-Request-Source', 'BusinessCentral-CompleteStatusCheck');

        // Send request using direct HttpClient.Send() method (same as working implementation)
        if not HttpClient.Send(RequestMessage, HttpResponseMessage) then begin
            PageDetails := StrSubstNo('HTTP Request Failed for page %1\\\\' +
                                    'Correlation ID: %2\\' +
                                    'Error: %3', PageNo, CorrelationId, GetLastErrorText());
            exit(false);
        end;

        // Handle response
        if not HttpResponseMessage.IsSuccessStatusCode() then begin
            PageDetails := StrSubstNo('HTTP Error %1 for page %2', HttpResponseMessage.HttpStatusCode(), PageNo);
            exit(false);
        end;

        // Read and parse response
        HttpResponseMessage.Content().ReadAs(ResponseText);
        if not ParseSubmissionResponse(ResponseText, PageDetails, OverallStatus, DocumentCount, DateTimeReceived) then begin
            PageDetails := StrSubstNo('Failed to parse response for page %1', PageNo);
            exit(false);
        end;

        exit(true);
    end;

    /// <summary>
    /// Helper to count documents in a page response
    /// </summary>
    local procedure GetDocumentCountFromPage(ResponseText: Text): Integer
    var
        JsonObject: JsonObject;
        JsonToken: JsonToken;
        DocumentSummaryArray: JsonArray;
    begin
        if not JsonObject.ReadFrom(ResponseText) then
            exit(0);

        if JsonObject.Get('documentSummary', JsonToken) and JsonToken.IsArray() then begin
            DocumentSummaryArray := JsonToken.AsArray();
            exit(DocumentSummaryArray.Count());
        end;

        exit(0);
    end;

    /// <summary>
    /// Parse LHDN error response according to their API specification
    /// Based on: https://sdk.myinvois.hasil.gov.my/standard-error-response/
    /// Handles the standardized error structure with propertyName, propertyPath, errorCode, etc.
    /// </summary>
    local procedure ParseErrorResponse(ResponseText: Text; var ErrorDetails: Text): Boolean
    var
        JsonObject: JsonObject;
        ErrorObject: JsonObject;
        JsonToken: JsonToken;
        InnerErrorArray: JsonArray;
        InnerErrorObject: JsonObject;
        DetailMessage: Text;
        ErrorCode: Text;
        ErrorMessage: Text;
        ErrorMessageMS: Text;
        PropertyName: Text;
        PropertyPath: Text;
        Target: Text;
        i: Integer;
    begin
        if not JsonObject.ReadFrom(ResponseText) then begin
            ErrorDetails := StrSubstNo('Failed to parse JSON error response: %1', ResponseText);
            exit(false);
        end;

        // Parse main error object according to LHDN standard structure
        if JsonObject.Get('error', JsonToken) and JsonToken.IsObject() then begin
            ErrorObject := JsonToken.AsObject();

            // Extract standard LHDN error fields
            if ErrorObject.Get('errorCode', JsonToken) then
                ErrorCode := CleanQuotesFromText(SafeJsonValueToText(JsonToken));

            if ErrorObject.Get('error', JsonToken) then
                ErrorMessage := CleanQuotesFromText(SafeJsonValueToText(JsonToken));

            if ErrorObject.Get('errorMS', JsonToken) then
                ErrorMessageMS := CleanQuotesFromText(SafeJsonValueToText(JsonToken));

            if ErrorObject.Get('propertyName', JsonToken) then
                PropertyName := CleanQuotesFromText(SafeJsonValueToText(JsonToken));

            if ErrorObject.Get('propertyPath', JsonToken) then
                PropertyPath := CleanQuotesFromText(SafeJsonValueToText(JsonToken));

            if ErrorObject.Get('target', JsonToken) then
                Target := CleanQuotesFromText(SafeJsonValueToText(JsonToken));

            // Build detailed error message according to LHDN standards
            DetailMessage := 'LHDN API Error\\';

            if ErrorCode <> '' then
                DetailMessage += StrSubstNo('Error Code: %1\\', ErrorCode);

            if ErrorMessage <> '' then
                DetailMessage += StrSubstNo('Error: %1\\', ErrorMessage);

            if ErrorMessageMS <> '' then
                DetailMessage += StrSubstNo('Error (Malay): %1\\', ErrorMessageMS);

            if PropertyName <> '' then
                DetailMessage += StrSubstNo('Property: %1\\', PropertyName);

            if PropertyPath <> '' then
                DetailMessage += StrSubstNo('Path: %1\\', PropertyPath);

            if Target <> '' then
                DetailMessage += StrSubstNo('Target: %1\\', Target);

            // Handle inner errors (multiple validation errors)
            if ErrorObject.Get('innerError', JsonToken) and JsonToken.IsArray() then begin
                InnerErrorArray := JsonToken.AsArray();
                DetailMessage += '\\Inner Errors:\\';

                for i := 0 to InnerErrorArray.Count() - 1 do begin
                    InnerErrorArray.Get(i, JsonToken);
                    if JsonToken.IsObject() then begin
                        InnerErrorObject := JsonToken.AsObject();

                        // Extract inner error details
                        if InnerErrorObject.Get('errorCode', JsonToken) then
                            DetailMessage += StrSubstNo('  - Code: %1', CleanQuotesFromText(SafeJsonValueToText(JsonToken)));

                        if InnerErrorObject.Get('error', JsonToken) then
                            DetailMessage += StrSubstNo(' | %1\\', CleanQuotesFromText(SafeJsonValueToText(JsonToken)));
                    end;
                end;
            end;

            DetailMessage += '\\API Reference: https://sdk.myinvois.hasil.gov.my/standard-error-response/';
            ErrorDetails := DetailMessage;
            exit(true);
        end;

        // Fallback for legacy error format
        if JsonObject.Get('code', JsonToken) or JsonObject.Get('message', JsonToken) then begin
            if JsonObject.Get('code', JsonToken) then
                ErrorCode := CleanQuotesFromText(SafeJsonValueToText(JsonToken));

            if JsonObject.Get('message', JsonToken) then
                ErrorMessage := CleanQuotesFromText(SafeJsonValueToText(JsonToken));

            if JsonObject.Get('target', JsonToken) then
                Target := CleanQuotesFromText(SafeJsonValueToText(JsonToken));

            ErrorDetails := StrSubstNo('API Error\\\\' +
                                      'Code: %1\\' +
                                      'Message: %2\\' +
                                      'Target: %3\\\\' +
                                      'Common causes:\\' +
                                      '- Submission UID not found or invalid\\' +
                                      '- Wrong environment (Preprod vs Production)\\' +
                                      '- Authentication or authorization issues\\\\' +
                                      'API Reference: https://sdk.myinvois.hasil.gov.my/standard-error-response/',
                                      ErrorCode, ErrorMessage, Target);
            exit(true);
        end;

        // Last resort - return the raw response
        ErrorDetails := StrSubstNo('Unknown error format: %1', ResponseText);
        exit(false);
    end;

    /// <summary>
    /// Parse LHDN submission response according to their API specification
    /// Based on: https://sdk.myinvois.hasil.gov.my/einvoicingapi/06-get-submission/
    /// Response includes: submissionUid, documentCount, dateTimeReceived, overallStatus, documentSummary[]
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
        IssuerTin: Text;
        IssuerName: Text;
        ReceiverId: Text;
        ReceiverName: Text;
        TypeName: Text;
        TypeVersionName: Text;
        DateTimeIssued: Text;
        DateTimeValidated: Text;
        TotalPayableAmount: Text;
        DocumentDetails: Text;
        LongId: Text;
        DocumentStatusReason: Text;
        CancelDateTime: Text;
        RejectRequestDateTime: Text;
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

            // Build document details for display according to API spec
            DocumentDetails := '';
            for i := 0 to DocumentSummaryCount - 1 do begin
                DocumentSummaryArray.Get(i, JsonToken);
                if JsonToken.IsObject() then begin
                    DocumentJson := JsonToken.AsObject();

                    // Extract document details according to LHDN API response structure
                    Uuid := 'N/A';
                    InternalId := 'N/A';
                    Status := 'N/A';
                    IssuerTin := 'N/A';
                    IssuerName := 'N/A';
                    ReceiverId := 'N/A';
                    ReceiverName := 'N/A';
                    TypeName := 'N/A';
                    TypeVersionName := 'N/A';
                    DateTimeIssued := 'N/A';
                    DateTimeValidated := 'N/A';
                    TotalPayableAmount := 'N/A';
                    LongId := 'N/A';
                    DocumentStatusReason := '';
                    CancelDateTime := '';
                    RejectRequestDateTime := '';

                    // Parse all available fields from LHDN API specification
                    if DocumentJson.Get('uuid', JsonToken) then
                        Uuid := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                    if DocumentJson.Get('internalId', JsonToken) then
                        InternalId := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                    if DocumentJson.Get('status', JsonToken) then
                        Status := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                    if DocumentJson.Get('issuerTin', JsonToken) then
                        IssuerTin := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                    if DocumentJson.Get('issuerName', JsonToken) then
                        IssuerName := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                    if DocumentJson.Get('receiverId', JsonToken) then
                        ReceiverId := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                    if DocumentJson.Get('receiverName', JsonToken) then
                        ReceiverName := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                    if DocumentJson.Get('typeName', JsonToken) then
                        TypeName := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                    if DocumentJson.Get('typeVersionName', JsonToken) then
                        TypeVersionName := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                    if DocumentJson.Get('dateTimeIssued', JsonToken) then
                        DateTimeIssued := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                    if DocumentJson.Get('dateTimeValidated', JsonToken) then
                        DateTimeValidated := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                    if DocumentJson.Get('totalPayableAmount', JsonToken) then
                        TotalPayableAmount := Format(JsonToken.AsValue().AsDecimal());
                    if DocumentJson.Get('longId', JsonToken) then
                        LongId := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                    if DocumentJson.Get('documentStatusReason', JsonToken) then
                        DocumentStatusReason := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                    if DocumentJson.Get('cancelDateTime', JsonToken) then
                        CancelDateTime := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                    if DocumentJson.Get('rejectRequestDateTime', JsonToken) then
                        RejectRequestDateTime := CleanQuotesFromText(SafeJsonValueToText(JsonToken));

                    if DocumentDetails <> '' then
                        DocumentDetails += '\\\\';

                    // Format document details according to LHDN API structure
                    DocumentDetails += StrSubstNo('Document %1: %2\\', i + 1, InternalId);
                    DocumentDetails += StrSubstNo('  - UUID: %1\\', Uuid);
                    DocumentDetails += StrSubstNo('  - Status: %1\\', Status);
                    DocumentDetails += StrSubstNo('  - Type: %1 v%2\\', TypeName, TypeVersionName);
                    DocumentDetails += StrSubstNo('  - Issuer: %1 (TIN: %2)\\', IssuerName, IssuerTin);
                    DocumentDetails += StrSubstNo('  - Receiver: %1 (ID: %2)\\', ReceiverName, ReceiverId);
                    DocumentDetails += StrSubstNo('  - Amount: MYR %1\\', TotalPayableAmount);
                    DocumentDetails += StrSubstNo('  - Issued: %1\\', DateTimeIssued);
                    if DateTimeValidated <> 'N/A' then
                        DocumentDetails += StrSubstNo('  - Validated: %1\\', DateTimeValidated);
                    if LongId <> 'N/A' then
                        DocumentDetails += StrSubstNo('  - Long ID: %1\\', LongId);
                    if DocumentStatusReason <> '' then
                        DocumentDetails += StrSubstNo('  - Status Reason: %1\\', DocumentStatusReason);
                    if CancelDateTime <> '' then
                        DocumentDetails += StrSubstNo('  - Cancelled: %1\\', CancelDateTime);
                    if RejectRequestDateTime <> '' then
                        DocumentDetails += StrSubstNo('  - Reject Requested: %1\\', RejectRequestDateTime);
                end;
            end;

            // Update submission details with document information
            if DocumentDetails <> '' then begin
                SubmissionDetails := StrSubstNo('Document Summary:\\%1', DocumentDetails);
            end;
        end;

        exit(true);
    end;

    /// <summary>
    /// Get submission UID from LHDN API
    /// Simplified method to get just the submission UID from the API
    /// </summary>


    /// <summary>
    /// Check status of a specific document within a submission by internal ID
    /// Searches through paginated results to find the document
    /// </summary>
    procedure CheckDocumentStatusInSubmission(SubmissionUid: Text; DocumentInternalId: Text; var DocumentDetails: Text): Boolean
    var
        HttpClient: HttpClient;
        HttpResponseMessage: HttpResponseMessage;
        RequestMessage: HttpRequestMessage;
        AccessToken: Text;
        eInvoiceSetup: Record "eInvoiceSetup";
        Url: Text;
        Headers: HttpHeaders;
        CorrelationId: Text;
        ResponseText: Text;
        JsonObject: JsonObject;
        JsonToken: JsonToken;
        DocumentSummaryArray: JsonArray;
        DocumentJson: JsonObject;
        PageNo: Integer;
        PageSize: Integer;
        DocumentCount: Integer;
        TotalPages: Integer;
        i: Integer;
        FoundDocument: Boolean;
        CurrentInternalId: Text;
        DocumentUuid: Text;
        DocumentStatus: Text;
        IssuerName: Text;
        ReceiverName: Text;
        TypeName: Text;
        TotalAmount: Text;
        DateTimeIssued: Text;
        DateTimeValidated: Text;
        DocumentStatusReason: Text;
    begin
        DocumentDetails := '';
        CorrelationId := CreateGuid();
        PageNo := 1;
        PageSize := 100; // Maximum page size
        FoundDocument := false;

        // Validate input parameters
        if (SubmissionUid = '') or (DocumentInternalId = '') then begin
            DocumentDetails := 'Error: Both Submission UID and Document Internal ID are required.';
            exit(false);
        end;

        if not eInvoiceSetup.Get('SETUP') then begin
            DocumentDetails := 'Error: eInvoice Setup not found.';
            exit(false);
        end;

        // Get access token
        eInvoiceHelper.InitializeHelper();
        AccessToken := eInvoiceHelper.GetAccessTokenFromSetup(eInvoiceSetup);
        if AccessToken = '' then begin
            DocumentDetails := 'Error: Failed to obtain access token.';
            exit(false);
        end;

        // Search through pages until document is found
        repeat
            // Build URL for current page
            if eInvoiceSetup.Environment = eInvoiceSetup.Environment::Preprod then
                Url := StrSubstNo('https://preprod-api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions/%1?pageNo=%2&pageSize=%3', SubmissionUid, PageNo, PageSize)
            else
                Url := StrSubstNo('https://api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions/%1?pageNo=%2&pageSize=%3', SubmissionUid, PageNo, PageSize);

            // Apply rate limiting
            eInvoiceHelper.ApplyRateLimiting(Url);

            // Prepare and send request
            RequestMessage.Method('GET');
            RequestMessage.SetRequestUri(Url);
            RequestMessage.GetHeaders(Headers);
            Headers.Add('Authorization', StrSubstNo('Bearer %1', AccessToken));
            Headers.Add('Content-Type', 'application/json; charset=utf-8');
            Headers.Add('Accept', 'application/json');
            Headers.Add('Accept-Language', 'en');
            Headers.Add('User-Agent', 'BusinessCentral-eInvoice/2.0');
            Headers.Add('X-Correlation-ID', CorrelationId);
            Headers.Add('X-Request-Source', 'BusinessCentral-DocumentSearch');

            // Send request using direct HttpClient.Send() method (same as working implementation)
            if not HttpClient.Send(RequestMessage, HttpResponseMessage) then begin
                DocumentDetails := StrSubstNo('HTTP Request Failed while searching for document\\\\' +
                                            'Correlation ID: %1\\' +
                                            'Error: %2', CorrelationId, GetLastErrorText());
                exit(false);
            end;

            if not HttpResponseMessage.IsSuccessStatusCode() then begin
                DocumentDetails := StrSubstNo('HTTP Error %1 while searching for document', HttpResponseMessage.HttpStatusCode());
                exit(false);
            end;

            // Parse response
            HttpResponseMessage.Content().ReadAs(ResponseText);
            if not JsonObject.ReadFrom(ResponseText) then begin
                DocumentDetails := 'Failed to parse API response';
                exit(false);
            end;

            // Get document count for pagination calculation (only on first page)
            if PageNo = 1 then begin
                if JsonObject.Get('documentCount', JsonToken) then begin
                    DocumentCount := JsonToken.AsValue().AsInteger();
                    TotalPages := (DocumentCount + PageSize - 1) div PageSize;
                end;
            end;

            // Search documents in current page
            if JsonObject.Get('documentSummary', JsonToken) and JsonToken.IsArray() then begin
                DocumentSummaryArray := JsonToken.AsArray();

                for i := 0 to DocumentSummaryArray.Count() - 1 do begin
                    DocumentSummaryArray.Get(i, JsonToken);
                    if JsonToken.IsObject() then begin
                        DocumentJson := JsonToken.AsObject();

                        // Check if this is the document we're looking for
                        if DocumentJson.Get('internalId', JsonToken) then begin
                            CurrentInternalId := CleanQuotesFromText(SafeJsonValueToText(JsonToken));

                            if CurrentInternalId = DocumentInternalId then begin
                                FoundDocument := true;

                                // Extract all document details
                                if DocumentJson.Get('uuid', JsonToken) then
                                    DocumentUuid := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                                if DocumentJson.Get('status', JsonToken) then
                                    DocumentStatus := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                                if DocumentJson.Get('issuerName', JsonToken) then
                                    IssuerName := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                                if DocumentJson.Get('receiverName', JsonToken) then
                                    ReceiverName := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                                if DocumentJson.Get('typeName', JsonToken) then
                                    TypeName := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                                if DocumentJson.Get('totalPayableAmount', JsonToken) then
                                    TotalAmount := Format(JsonToken.AsValue().AsDecimal());
                                if DocumentJson.Get('dateTimeIssued', JsonToken) then
                                    DateTimeIssued := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                                if DocumentJson.Get('dateTimeValidated', JsonToken) then
                                    DateTimeValidated := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                                if DocumentJson.Get('documentStatusReason', JsonToken) then
                                    DocumentStatusReason := CleanQuotesFromText(SafeJsonValueToText(JsonToken));

                                // Format document details
                                DocumentDetails := StrSubstNo('Document Found in Submission\\' +
                                                            '========================\\\\' +
                                                            'Submission UID: %1\\' +
                                                            'Internal ID: %2\\' +
                                                            'UUID: %3\\' +
                                                            'Status: %4\\' +
                                                            'Type: %5\\' +
                                                            'Issuer: %6\\' +
                                                            'Receiver: %7\\' +
                                                            'Amount: MYR %8\\' +
                                                            'Date Issued: %9\\' +
                                                            'Date Validated: %10\\' +
                                                            'Status Reason: %11\\\\' +
                                                            'Found on page %12 of %13\\\\' +
                                                            'API Reference: https://sdk.myinvois.hasil.gov.my/einvoicingapi/06-get-submission/',
                                                            SubmissionUid,
                                                            CurrentInternalId,
                                                            DocumentUuid,
                                                            DocumentStatus,
                                                            TypeName,
                                                            IssuerName,
                                                            ReceiverName,
                                                            TotalAmount,
                                                            DateTimeIssued,
                                                            DateTimeValidated,
                                                            DocumentStatusReason,
                                                            PageNo,
                                                            TotalPages);

                                exit(true);
                            end;
                        end;
                    end;
                end;
            end;

            // Move to next page if document not found
            PageNo += 1;

            // Add delay between page requests
            if PageNo <= TotalPages then
                Sleep(4000);

        until FoundDocument or (PageNo > TotalPages);

        // Document not found
        if not FoundDocument then begin
            DocumentDetails := StrSubstNo('Document Not Found\\\\' +
                                        'Submission UID: %1\\' +
                                        'Document Internal ID: %2\\' +
                                        'Searched Pages: %3\\' +
                                        'Total Documents in Submission: %4\\\\' +
                                        'This may mean:\\' +
                                        '- The document internal ID is incorrect\\' +
                                        '- The document was not part of this submission\\' +
                                        '- The document was processed in a different batch\\\\' +
                                        'Try checking the complete submission details first.',
                                        SubmissionUid,
                                        DocumentInternalId,
                                        PageNo - 1,
                                        DocumentCount);
        end;

        exit(FoundDocument);
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
                                          '- The submission was not logged\\' +
                                          '- The submission UID is incorrect\\' +
                                          '- The submission was made in a different company\\\\' +
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
                                      '- Valid: %3\\' +
                                      '- Invalid: %4\\' +
                                      '- In Progress: %5\\' +
                                      '- Partially Valid: %6\\' +
                                      '- Unknown: %7\\\\' +
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
            eInvoiceHelper.InitializeHelper();
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
        TestResults += StrSubstNo('- User ID: %1\\', UserId);
        TestResults += StrSubstNo('- Company: %2\\', CompanyName);
        TestResults += StrSubstNo('- Current Time: %3\\', Format(CurrentDateTime, 0, '<Day,2>/<Month,2>/<Year4> <Hours24,2>:<Minutes,2> <AM/PM>'));

        // Test 4: Context information
        TestResults += '\\Context Analysis:\\';
        TestResults += '- HTTP operations may be restricted in current context\\';
        TestResults += '- Try running from a different page or action\\';
        TestResults += '- Use "Refresh Status (Local Analysis)" as alternative\\';

        TestResults += '\\Recommendations:\\';
        TestResults += '1. Try running from the main e-Invoice Submission Log page\\';
        TestResults += '2. Use "Export to Excel" to get current data\\';
        TestResults += '3. Contact system administrator for HTTP permissions\\';
        TestResults += '4. Check LHDN API documentation for troubleshooting\\';

        TestResults += '\\API Reference: https://sdk.myinvois.hasil.gov.my/einvoicingapi/06-get-submission/';

        exit(TestResults);
    end;



    /// <summary>
    /// Validate submission UID format according to LHDN standards
    /// </summary>
    local procedure ValidateSubmissionUid(SubmissionUid: Text): Boolean
    var
        ValidChars: Text;
        i: Integer;
        CurrentChar: Text;
    begin
        // Basic validation - should not be empty and should have reasonable length
        if SubmissionUid = '' then
            exit(false);

        if StrLen(SubmissionUid) < 10 then
            exit(false);

        if StrLen(SubmissionUid) > 50 then
            exit(false);

        // Check for valid characters (alphanumeric and some special chars)
        ValidChars := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_';

        for i := 1 to StrLen(SubmissionUid) do begin
            CurrentChar := UpperCase(CopyStr(SubmissionUid, i, 1));
            if StrPos(ValidChars, CurrentChar) = 0 then
                exit(false);
        end;

        exit(true);
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
    /// Extract status from response text with proper capitalization
    /// 
    /// STATUS FLOW EXPLANATION:
    /// 1. Initially when documents are submitted > Status = "Submitted"
    /// 2. LHDN processes the submission > Status changes to one of:
    ///    - "Valid": All documents passed validation
    ///    - "Invalid": All documents failed validation  
    ///    - "In Progress": Documents still being processed
    ///    - "Partially Valid": Some documents valid, others invalid
    /// 
    /// This procedure maps LHDN API response values to user-friendly display values
    /// API Note: Get Submission Status API returns info for ONE submission UID 
    /// (which can contain multiple documents), not per individual document
    /// </summary>
    local procedure ExtractStatusFromResponse(ResponseText: Text): Text
    var
        Status: Text;
        JsonObject: JsonObject;
        JsonToken: JsonToken;
    begin
        Status := 'Unknown';

        // Try to parse JSON response first for more accurate status extraction
        if JsonObject.ReadFrom(ResponseText) then begin
            if JsonObject.Get('overallStatus', JsonToken) then begin
                Status := JsonToken.AsValue().AsText();
                // Convert LHDN status to proper capitalization for display
                case Status of
                    'valid':
                        Status := 'Valid';
                    'invalid':
                        Status := 'Invalid';
                    'in progress':
                        Status := 'In Progress';
                    'partially valid':
                        Status := 'Partially Valid';
                    else
                        Status := 'Unknown';
                end;
                exit(Status);
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
    /// Log background job completion for tracking purposes
    /// </summary>
    local procedure LogBackgroundJobCompletion(UpdatedCount: Integer; ProcessedCount: Integer)
    var
        BackgroundLog: Record "eInvoice Submission Log";
        JobQueueLogEntry: Record "Job Queue Log Entry";
        LogEntryNo: Integer;
    begin
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
        BackgroundLog."Error Message" := StrSubstNo('Background job completed. Processed: %1, Updated: %2',
                                                   ProcessedCount, UpdatedCount);
        BackgroundLog.Insert();

        // Also log to Job Queue Log Entry for system tracking
        if JobQueueLogEntry.FindLast() then
            LogEntryNo := JobQueueLogEntry."Entry No." + 1
        else
            LogEntryNo := 1;

        JobQueueLogEntry.Init();
        JobQueueLogEntry."Entry No." := LogEntryNo;
        JobQueueLogEntry.Status := JobQueueLogEntry.Status::Success;
        JobQueueLogEntry."Start Date/Time" := CurrentDateTime;
        JobQueueLogEntry."End Date/Time" := CurrentDateTime;
        JobQueueLogEntry."Object Type to Run" := JobQueueLogEntry."Object Type to Run"::Codeunit;
        JobQueueLogEntry."Object ID to Run" := Codeunit::"eInvoice Submission Status";
        JobQueueLogEntry."Job Queue Category Code" := 'EINVOICE';
        JobQueueLogEntry."Description" := StrSubstNo('eInvoice Status Refresh - Updated: %1, Processed: %2', UpdatedCount, ProcessedCount);
        JobQueueLogEntry.Insert();
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

        // Process entries that need status updates
        // Priority: Submitted, In Progress, Partially Valid, Unknown statuses
        // Skip: Valid and Invalid (final statuses that won't change)
        SubmissionLog.SetFilter("Submission UID", '<>%1', '');
        SubmissionLog.SetFilter(Status, '%1|%2|%3|%4|%5', 'Submitted', 'In Progress', 'Partially Valid', 'Unknown', '');

        if SubmissionLog.FindSet() then begin
            repeat
                ProcessedCount += 1;

                // Use the direct status check method
                ApiSuccess := CheckSubmissionStatus(SubmissionLog."Submission UID", SubmissionDetails);

                if ApiSuccess then begin
                    // Update the log entry with current status from LHDN
                    SubmissionLog.Status := ExtractStatusFromResponse(SubmissionDetails);
                    SubmissionLog."Response Date" := CurrentDateTime;
                    SubmissionLog."Last Updated" := CurrentDateTime;
                    SubmissionLog."Error Message" := '';
                    SubmissionLog.Modify();
                    UpdatedCount += 1;
                end else begin
                    // Log the error but continue processing
                    SubmissionLog."Error Message" := CopyStr(SubmissionDetails, 1, MaxStrLen(SubmissionLog."Error Message"));
                    SubmissionLog."Last Updated" := CurrentDateTime;
                    SubmissionLog.Modify();
                end;

                // Add delay between requests to respect rate limits
                Sleep(4000); // 4 second delay between requests

            until SubmissionLog.Next() = 0;
        end;

        // Log the completion
        LogBackgroundJobCompletion(UpdatedCount, ProcessedCount);
    end;

    /// <summary>
    /// Handle background job processing for status refresh with enhanced error handling
    /// This procedure is called by the Job Queue to process status refresh in the background
    /// If HTTP restrictions apply even in job queue context, it will log the issue and provide guidance
    /// </summary>
    procedure ProcessBackgroundStatusRefreshSafe()
    var
        JobQueueEntry: Record "Job Queue Entry";
        SubmissionLogRec: Record "eInvoice Submission Log";
        ParameterString: Text;
        SubmissionUID: Text;
        SubmissionDetails: Text;
        LhdnStatus: Text;
        PipePos: Integer;
        ErrorLogEntry: Record "eInvoice Submission Log";
    begin
        // Find the current job queue entry to get parameters
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"eInvoice Submission Status");
        JobQueueEntry.SetRange(Status, JobQueueEntry.Status::"In Process");
        if JobQueueEntry.FindFirst() then begin
            ParameterString := JobQueueEntry."Parameter String";

            // Check if this is a single submission refresh
            if ParameterString.StartsWith('REFRESH_SINGLE|') then begin
                PipePos := ParameterString.IndexOf('|');
                if PipePos > 0 then begin
                    SubmissionUID := CopyStr(ParameterString, PipePos + 1);

                    // Find and refresh the specific submission
                    SubmissionLogRec.SetRange("Submission UID", SubmissionUID);
                    if SubmissionLogRec.FindFirst() then begin
                        // Try the API call with enhanced error handling
                        if TryDirectApiCallForBackground(SubmissionUID, SubmissionDetails) then begin
                            LhdnStatus := ExtractStatusFromResponse(SubmissionDetails);

                            SubmissionLogRec.Status := LhdnStatus;
                            SubmissionLogRec."Response Date" := CurrentDateTime;
                            SubmissionLogRec."Last Updated" := CurrentDateTime;
                            SubmissionLogRec."Error Message" := StrSubstNo('Background refresh completed at %1',
                                                                          Format(CurrentDateTime, 0, '<Day,2>/<Month,2>/<Year4> <Hours24,2>:<Minutes,2>'));
                            SubmissionLogRec.Modify();
                        end else begin
                            // Even background job context has restrictions - log this issue
                            SubmissionLogRec."Error Message" := CopyStr(StrSubstNo('Background refresh failed due to HTTP context restrictions. Environment may have strict HTTP policies. Last attempted: %1',
                                                                      Format(CurrentDateTime, 0, '<Day,2>/<Month,2>/<Year4> <Hours24,2>:<Minutes,2>')),
                                                                      1, MaxStrLen(SubmissionLogRec."Error Message"));
                            SubmissionLogRec."Last Updated" := CurrentDateTime;
                            SubmissionLogRec.Modify();

                            // Create an error log entry to track this issue
                            CreateContextRestrictionErrorLog(SubmissionUID, 'Job Queue context also restricted');
                        end;
                    end;
                end;
            end else begin
                // Bulk refresh attempt
                if not TryBulkRefreshForBackground() then begin
                    // Create error log for bulk refresh failure
                    CreateContextRestrictionErrorLog('BULK_REFRESH', 'Bulk refresh failed in job queue context');
                end;
            end;
        end else begin
            // No job queue entry found - this shouldn't happen but handle gracefully
            CreateContextRestrictionErrorLog('NO_JOB_ENTRY', 'No job queue entry found during background processing');
        end;
    end;

    /// <summary>
    /// Job queue entry point for status refresh
    /// This procedure is called by the job queue system
    /// Handles both background refresh and single submission refresh
    /// </summary>
    procedure RefreshStatusesFromJobQueue()
    var
        JobQueueEntry: Record "Job Queue Entry";
        SubmissionLogRec: Record "eInvoice Submission Log";
        ParameterString: Text;
        SubmissionUID: Text;
        SubmissionDetails: Text;
        LhdnStatus: Text;
        PipePos: Integer;
    begin
        // Find the current job queue entry to get parameters
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"eInvoice Submission Status");
        JobQueueEntry.SetRange(Status, JobQueueEntry.Status::"In Process");
        if JobQueueEntry.FindFirst() then begin
            ParameterString := JobQueueEntry."Parameter String";

            // Check if this is a single submission refresh
            if ParameterString.StartsWith('REFRESH_SINGLE|') then begin
                PipePos := ParameterString.IndexOf('|');
                if PipePos > 0 then begin
                    SubmissionUID := CopyStr(ParameterString, PipePos + 1);

                    // Find and refresh the specific submission
                    SubmissionLogRec.SetRange("Submission UID", SubmissionUID);
                    if SubmissionLogRec.FindFirst() then begin
                        // Direct API call - this runs in background context where HTTP is allowed
                        if CheckSubmissionStatus(SubmissionUID, SubmissionDetails) then begin
                            LhdnStatus := ExtractStatusFromResponse(SubmissionDetails);

                            SubmissionLogRec.Status := LhdnStatus;
                            SubmissionLogRec."Response Date" := CurrentDateTime;
                            SubmissionLogRec."Last Updated" := CurrentDateTime;
                            SubmissionLogRec."Error Message" := StrSubstNo('Background refresh completed at %1',
                                                                          Format(CurrentDateTime, 0, '<Day,2>/<Month,2>/<Year4> <Hours24,2>:<Minutes,2>'));
                            SubmissionLogRec.Modify();
                        end else begin
                            // Log the error from background job
                            SubmissionLogRec."Error Message" := CopyStr(StrSubstNo('Background refresh failed: %1', SubmissionDetails),
                                                                      1, MaxStrLen(SubmissionLogRec."Error Message"));
                            SubmissionLogRec."Last Updated" := CurrentDateTime;
                            SubmissionLogRec.Modify();
                        end;
                    end;
                end;
            end else begin
                // Default bulk refresh for all submitted entries
                RefreshAllSubmissionLogStatusesSafe();
            end;
        end else begin
            // Fallback to bulk refresh if no job queue entry found
            RefreshAllSubmissionLogStatusesSafe();
        end;
    end;

    /// <summary>
    /// Try direct API call specifically for background job context
    /// Uses additional error handling for strict HTTP policy environments
    /// </summary>
    [TryFunction]
    local procedure TryDirectApiCallForBackground(SubmissionUid: Text; var SubmissionDetails: Text)
    begin
        // Initialize helper with minimal overhead
        eInvoiceHelper.InitializeHelper();

        // Attempt the status check with try-catch
        // If this fails even in job queue, it indicates very strict HTTP restrictions
        CheckSubmissionStatus(SubmissionUid, SubmissionDetails);
    end;

    /// <summary>
    /// Try bulk refresh in background context
    /// </summary>
    [TryFunction]
    local procedure TryBulkRefreshForBackground()
    var
        SubmissionLog: Record "eInvoice Submission Log";
        SubmissionDetails: Text;
        ProcessedCount: Integer;
    begin
        // Process a limited number of entries to avoid timeout
        SubmissionLog.SetFilter("Submission UID", '<>%1', '');
        SubmissionLog.SetRange(Status, 'Submitted'); // Only try submitted status

        if SubmissionLog.FindSet() then begin
            repeat
                ProcessedCount += 1;
                // Try to refresh this one entry
                CheckSubmissionStatus(SubmissionLog."Submission UID", SubmissionDetails);

                // Limit to 5 entries to avoid job timeout
                if ProcessedCount >= 5 then
                    break;

            until SubmissionLog.Next() = 0;
        end;
    end;

    /// <summary>
    /// Create a special error log entry to track context restriction issues
    /// This helps identify when the Business Central environment has very strict HTTP policies
    /// </summary>
    local procedure CreateContextRestrictionErrorLog(SubmissionUID: Text; ErrorDetails: Text)
    var
        ErrorLogEntry: Record "eInvoice Submission Log";
    begin
        ErrorLogEntry.Init();
        ErrorLogEntry."Entry No." := 0; // Auto-increment
        ErrorLogEntry."Invoice No." := 'CONTEXT-ERROR';
        ErrorLogEntry."Customer Name" := 'System Error';
        ErrorLogEntry."Submission UID" := SubmissionUID;
        ErrorLogEntry."Document UUID" := '';
        ErrorLogEntry.Status := 'Context Restricted';
        ErrorLogEntry."Submission Date" := CurrentDateTime;
        ErrorLogEntry."Response Date" := CurrentDateTime;
        ErrorLogEntry."Last Updated" := CurrentDateTime;
        ErrorLogEntry."User ID" := UserId;
        ErrorLogEntry."Company Name" := CompanyName;
        ErrorLogEntry."Error Message" := CopyStr(StrSubstNo('HTTP Context Restriction Error: %1. ' +
                                                           'Environment has strict HTTP policies that prevent API calls even in job queue context. ' +
                                                           'Manual status verification required via LHDN portal. ' +
                                                           'Contact system administrator for HTTP policy review.',
                                                           ErrorDetails),
                                                 1, MaxStrLen(ErrorLogEntry."Error Message"));
        if ErrorLogEntry.Insert(true) then; // Use try-insert to avoid any secondary errors
    end;    /// <summary>
            /// Simple direct status refresh for testing - bypasses complex error handling
            /// Now with context-aware handling for HTTP restrictions
            /// </summary>
    procedure SimpleDirectStatusRefresh(var SubmissionLogRec: Record "eInvoice Submission Log"): Boolean
    var
        SubmissionDetails: Text;
        LhdnStatus: Text;
    begin
        // Validate input
        if SubmissionLogRec."Submission UID" = '' then begin
            Message('No Submission UID found for this entry.');
            exit(false);
        end;

        // Try direct approach first (may fail due to context restrictions)
        if TryDirectApiCallForBackground(SubmissionLogRec."Submission UID", SubmissionDetails) then begin
            // Success - extract status and update
            LhdnStatus := ExtractStatusFromResponse(SubmissionDetails);

            // Update record
            SubmissionLogRec.Status := LhdnStatus;
            SubmissionLogRec."Response Date" := CurrentDateTime;
            SubmissionLogRec."Last Updated" := CurrentDateTime;
            SubmissionLogRec."Error Message" := 'Successfully refreshed from LHDN API';
            SubmissionLogRec.Modify();

            Message('Status refreshed successfully!\\\\' +
                   'New Status: %1\\' +
                   'Submission UID: %2\\' +
                   'Updated: %3',
                   LhdnStatus,
                   SubmissionLogRec."Submission UID",
                   Format(CurrentDateTime, 0, '<Day,2>/<Month,2>/<Year4> <Hours24,2>:<Minutes,2>'));
            exit(true);
        end else begin
            // Direct call failed - likely due to context restrictions
            // Create a background job for the refresh
            if CreateBackgroundStatusRefreshJob(SubmissionLogRec."Submission UID") then begin
                SubmissionLogRec."Error Message" := 'Background refresh scheduled due to context restrictions';
                SubmissionLogRec."Last Updated" := CurrentDateTime;
                SubmissionLogRec.Modify();

                Message('Context restrictions detected!\\\\' +
                       'Submission UID: %1\\\\' +
                       'A background job has been created to refresh the status.\\' +
                       'The status will be updated automatically within a few minutes.\\' +
                       'Check the Job Queue or refresh this page later to see the updated status.\\\\' +
                       'NOTE: If the background job also fails with context restrictions,\\' +
                       'use "Manual Status Check Guide" for alternative options.',
                       SubmissionLogRec."Submission UID");
                exit(true);
            end else begin
                // Can't create background job either - provide comprehensive manual options
                SubmissionLogRec."Error Message" := CopyStr('Context restrictions prevent automatic refresh. Please use manual verification methods.', 1, MaxStrLen(SubmissionLogRec."Error Message"));
                SubmissionLogRec."Last Updated" := CurrentDateTime;
                SubmissionLogRec.Modify();

                Message('Strict HTTP Context Restrictions Detected\\\\' +
                       'Submission UID: %1\\\\' +
                       'Your Business Central environment has very strict HTTP policies\\' +
                       'that prevent API calls in all contexts (UI and background jobs).\\\\' +
                       'IMMEDIATE SOLUTIONS:\\' +
                       '1. Click "Manual Status Check Guide" for detailed instructions\\' +
                       '2. Check LHDN MyInvois portal directly\\' +
                       '3. Use external API testing tools\\' +
                       '4. Contact system administrator for HTTP policy review\\\\' +
                       'This is an environment configuration issue, not an application error.',
                       SubmissionLogRec."Submission UID");
                exit(false);
            end;
        end;
    end;    /// <summary>
            /// Refresh status for a specific submission log entry
            /// Updates the Status field with the latest LHDN status
            /// </summary>
    procedure RefreshSubmissionLogStatus(var SubmissionLogRec: Record "eInvoice Submission Log"): Boolean
    var
        SubmissionDetails: Text;
        ApiSuccess: Boolean;
        LhdnStatus: Text;
    begin
        // Validate that we have a submission UID
        if SubmissionLogRec."Submission UID" = '' then begin
            Message('No Submission UID found for this entry. Cannot refresh status.');
            exit(false);
        end;

        // Check status using LHDN API
        eInvoiceHelper.InitializeHelper();
        ApiSuccess := CheckSubmissionStatus(SubmissionLogRec."Submission UID", SubmissionDetails);

        if ApiSuccess then begin
            // Extract the proper status from LHDN response
            LhdnStatus := ExtractStatusFromResponse(SubmissionDetails);

            // Update the log entry with the current LHDN status
            SubmissionLogRec.Status := LhdnStatus;
            SubmissionLogRec."Response Date" := CurrentDateTime;
            SubmissionLogRec."Last Updated" := CurrentDateTime;
            SubmissionLogRec."Error Message" := CopyStr(SubmissionDetails, 1, MaxStrLen(SubmissionLogRec."Error Message"));

            if SubmissionLogRec.Modify() then begin
                Message('Status refreshed successfully!\\' +
                       'New Status: %1\\' +
                       'Updated: %2',
                       LhdnStatus,
                       Format(CurrentDateTime, 0, '<Day,2>/<Month,2>/<Year4> <Hours24,2>:<Minutes,2>'));
                exit(true);
            end else begin
                Message('Failed to update the log entry. Please try again.');
                exit(false);
            end;
        end else begin
            // Update error message even if API call failed
            SubmissionLogRec."Error Message" := CopyStr(SubmissionDetails, 1, MaxStrLen(SubmissionLogRec."Error Message"));
            SubmissionLogRec."Last Updated" := CurrentDateTime;
            SubmissionLogRec.Modify();

            Message('Failed to refresh status from LHDN.\\' +
                   'Error: %1\\\\' +
                   'The error has been logged for reference.',
                   SubmissionDetails);
            exit(false);
        end;
    end;

    /// <summary>
    /// Refresh status for multiple submission log entries
    /// Updates Status field for all entries with Submission UIDs
    /// </summary>
    procedure RefreshAllSubmissionLogStatuses(): Integer
    var
        SubmissionLog: Record "eInvoice Submission Log";
        SubmissionDetails: Text;
        ApiSuccess: Boolean;
        UpdatedCount: Integer;
        ProcessedCount: Integer;
        ErrorCount: Integer;
        LhdnStatus: Text;
        ProgressDialog: Dialog;
    begin
        UpdatedCount := 0;
        ProcessedCount := 0;
        ErrorCount := 0;

        // Set up progress dialog
        ProgressDialog.Open('Refreshing submission statuses...\\' +
                           'Processed: #1######\\' +
                           'Updated: #2######\\' +
                           'Errors: #3######');

        // Find all entries with submission UIDs
        SubmissionLog.SetFilter("Submission UID", '<>%1', '');

        if SubmissionLog.FindSet() then begin
            repeat
                ProcessedCount += 1;
                ProgressDialog.Update(1, ProcessedCount);
                ProgressDialog.Update(2, UpdatedCount);
                ProgressDialog.Update(3, ErrorCount);

                // Refresh status using LHDN API
                eInvoiceHelper.InitializeHelper();
                ApiSuccess := CheckSubmissionStatus(SubmissionLog."Submission UID", SubmissionDetails);

                if ApiSuccess then begin
                    // Extract and update status
                    LhdnStatus := ExtractStatusFromResponse(SubmissionDetails);
                    SubmissionLog.Status := LhdnStatus;
                    SubmissionLog."Response Date" := CurrentDateTime;
                    SubmissionLog."Last Updated" := CurrentDateTime;
                    SubmissionLog."Error Message" := '';

                    if SubmissionLog.Modify() then
                        UpdatedCount += 1;
                end else begin
                    // Log the error
                    SubmissionLog."Error Message" := CopyStr(SubmissionDetails, 1, MaxStrLen(SubmissionLog."Error Message"));
                    SubmissionLog."Last Updated" := CurrentDateTime;
                    SubmissionLog.Modify();
                    ErrorCount += 1;
                end;

                // Add delay to respect LHDN rate limiting (300 RPM = 5 RPS = 200ms minimum)
                Sleep(300); // 300ms delay between requests for safe rate limiting

            until SubmissionLog.Next() = 0;
        end;

        ProgressDialog.Close();

        Message('Status refresh completed!\\\\' +
               'Processed: %1 entries\\' +
               'Updated: %2 entries\\' +
               'Errors: %3 entries\\\\' +
               'Check the Error Message field for any failed updates.',
               ProcessedCount, UpdatedCount, ErrorCount);

        exit(UpdatedCount);
    end;

    /// <summary>
    /// Context-safe refresh for a specific submission log entry
    /// Uses direct API call when possible, background job when restricted
    /// </summary>
    procedure RefreshSubmissionLogStatusSafe(var SubmissionLogRec: Record "eInvoice Submission Log"): Boolean
    var
        SubmissionDetails: Text;
        LhdnStatus: Text;
        ApiSuccess: Boolean;
    begin
        // Validate that we have a submission UID
        if SubmissionLogRec."Submission UID" = '' then begin
            Message('No Submission UID found for this entry. Cannot refresh status.');
            exit(false);
        end;

        // Try direct API call with proper initialization
        eInvoiceHelper.InitializeHelper();

        // Use CheckSubmissionStatus directly instead of TryRefreshStatusFromAPI
        ApiSuccess := CheckSubmissionStatus(SubmissionLogRec."Submission UID", SubmissionDetails);

        if ApiSuccess then begin
            // Extract and update status
            LhdnStatus := ExtractStatusFromResponse(SubmissionDetails);

            // Update the log entry with the current LHDN status
            SubmissionLogRec.Status := LhdnStatus;
            SubmissionLogRec."Response Date" := CurrentDateTime;
            SubmissionLogRec."Last Updated" := CurrentDateTime;
            SubmissionLogRec."Error Message" := '';

            if SubmissionLogRec.Modify() then begin
                Message('Status refreshed successfully!\\' +
                       'New Status: %1\\' +
                       'Updated: %2',
                       LhdnStatus,
                       Format(CurrentDateTime, 0, '<Day,2>/<Month,2>/<Year4> <Hours24,2>:<Minutes,2>'));
                exit(true);
            end else begin
                Message('Failed to update the log entry. Please try again.');
                exit(false);
            end;
        end else begin
            // Check if it's a context restriction
            if SubmissionDetails.Contains('context') or GetLastErrorText().Contains('context') then begin
                // Create background job for actual API call
                if CreateBackgroundStatusRefreshJob(SubmissionLogRec."Submission UID") then begin
                    Message('HTTP operations restricted in current context.\\\\' +
                           'Background job created to refresh status.\\' +
                           'The status will be updated automatically.\\\\' +
                           'Please check again in a few moments or refresh the page.');
                    exit(true);
                end else begin
                    Message('HTTP operations restricted in current context.\\\\' +
                           'To refresh this status, try one of these options:\\\\' +
                           '1. Use "Background Status Refresh" action from the page\\' +
                           '2. Run the refresh from Job Queue Entries\\' +
                           '3. Wait for scheduled automatic refresh\\\\' +
                           'Submission UID: %1\\' +
                           'Current Status: %2',
                           SubmissionLogRec."Submission UID",
                           SubmissionLogRec.Status);
                    exit(false);
                end;
            end else begin
                // Other type of error - log it and inform user
                SubmissionLogRec."Error Message" := CopyStr(SubmissionDetails, 1, MaxStrLen(SubmissionLogRec."Error Message"));
                SubmissionLogRec."Last Updated" := CurrentDateTime;
                SubmissionLogRec.Modify();

                Message('Failed to refresh status from LHDN.\\\\' +
                       'Error: %1\\\\' +
                       'Please check:\\' +
                       '- Network connectivity\\' +
                       '- LHDN API availability\\' +
                       '- Submission UID validity\\\\' +
                       'The error has been logged for reference.',
                       SubmissionDetails);
                exit(false);
            end;
        end;
    end;

    /// <summary>
    /// Creates a background job to refresh status when HTTP context is restricted
    /// </summary>
    procedure CreateBackgroundStatusRefreshJob(SubmissionUid: Text): Boolean
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        // Create job queue entry for background status refresh
        JobQueueEntry.Init();
        JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
        JobQueueEntry."Object ID to Run" := Codeunit::"eInvoice Submission Status";
        JobQueueEntry."Job Queue Category Code" := 'EINVOICE';
        JobQueueEntry.Description := StrSubstNo('eInvoice Status Refresh - %1', SubmissionUid);
        JobQueueEntry."Parameter String" := StrSubstNo('REFRESH_SINGLE|%1', SubmissionUid);
        JobQueueEntry."User ID" := UserId;
        JobQueueEntry."Earliest Start Date/Time" := CurrentDateTime + 5000; // Start in 5 seconds
        JobQueueEntry.Status := JobQueueEntry.Status::Ready;
        JobQueueEntry."Maximum No. of Attempts to Run" := 3;
        JobQueueEntry."Rerun Delay (sec.)" := 30;

        exit(JobQueueEntry.Insert(true));
    end;    /// <summary>
            /// Alternative refresh method when HTTP operations are restricted
            /// Provides analysis based on local data and guidance for manual refresh
            /// </summary>
    procedure RefreshSubmissionLogStatusAlternative(var SubmissionLogRec: Record "eInvoice Submission Log")
    var
        StatusMessage: Text;
        LastUpdateInfo: Text;
        eInvoiceSetup: Record "eInvoiceSetup";
        ApiUrl: Text;
        EnvironmentInfo: Text;
    begin
        // Get the correct API URL based on environment setup
        if eInvoiceSetup.Get('SETUP') then begin
            if eInvoiceSetup.Environment = eInvoiceSetup.Environment::Preprod then begin
                ApiUrl := StrSubstNo('https://preprod-api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions/%1', SubmissionLogRec."Submission UID");
                EnvironmentInfo := 'Environment: Preprod (Testing)';
            end else begin
                ApiUrl := StrSubstNo('https://api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions/%1', SubmissionLogRec."Submission UID");
                EnvironmentInfo := 'Environment: Production (Live)';
            end;
        end else begin
            // Default to preprod if setup not found
            ApiUrl := StrSubstNo('https://preprod-api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions/%1', SubmissionLogRec."Submission UID");
            EnvironmentInfo := 'Environment: Preprod (Default - Setup not found)';
        end;

        // Prepare informative message about context restrictions
        LastUpdateInfo := '';
        if SubmissionLogRec."Last Updated" <> 0DT then
            LastUpdateInfo := StrSubstNo('Last Updated: %1\\',
                                        Format(SubmissionLogRec."Last Updated", 0, '<Day,2>/<Month,2>/<Year4> <Hours24,2>:<Minutes,2>'));

        StatusMessage := StrSubstNo('Context Restriction - HTTP Operations Not Allowed\\\\' +
                                  'Submission UID: %1\\' +
                                  'Current Status: %2\\' +
                                  '%3\\' +
                                  '%4\\\\' +
                                  'The system cannot perform HTTP operations in this context.\\\\' +
                                  'Alternative Options:\\' +
                                  '1. Use "Export to Excel" to get current data\\' +
                                  '2. Try refreshing from a different page\\' +
                                  '3. Schedule a background job for automatic refresh\\' +
                                  '4. Contact system administrator\\\\' +
                                  'Manual API Testing:\\' +
                                  'URL: %5\\' +
                                  'Use tools like Postman or browser to test manually.',
                                  SubmissionLogRec."Submission UID",
                                  SubmissionLogRec.Status,
                                  LastUpdateInfo,
                                  EnvironmentInfo,
                                  ApiUrl);

        // Update the error message field with context information
        SubmissionLogRec."Error Message" := CopyStr('Context restriction: HTTP operations not allowed in this UI context. Use alternative refresh methods.',
                                                   1, MaxStrLen(SubmissionLogRec."Error Message"));
        SubmissionLogRec."Last Updated" := CurrentDateTime;
        SubmissionLogRec.Modify();

        Message(StatusMessage);
    end;

    /// <summary>
    /// Protected HTTP API call with try-catch for context restrictions
    /// Returns true if successful, false if context restrictions prevent HTTP operations
    /// </summary>
    [TryFunction]
    local procedure TryRefreshStatusFromAPI(SubmissionUid: Text; var SubmissionDetails: Text)
    begin
        // Initialize helper and attempt API call
        eInvoiceHelper.InitializeHelper();

        // The TryFunction attribute ensures any errors (including context restrictions) 
        // are caught and the function returns false gracefully
        CheckSubmissionStatus(SubmissionUid, SubmissionDetails);
    end;

    /// <summary>
    /// Context-safe refresh for all submission log entries
    /// Uses try-catch approach to handle context restrictions gracefully
    /// </summary>
    procedure RefreshAllSubmissionLogStatusesSafe(): Boolean
    var
        SubmissionLog: Record "eInvoice Submission Log";
        SubmissionDetails: Text;
        UpdatedCount: Integer;
        ProcessedCount: Integer;
        ErrorCount: Integer;
        LhdnStatus: Text;
        ProgressDialog: Dialog;
        ContextRestricted: Boolean;
    begin
        UpdatedCount := 0;
        ProcessedCount := 0;
        ErrorCount := 0;
        ContextRestricted := false;

        // Set up progress dialog
        ProgressDialog.Open('Refreshing submission statuses...\\' +
                           'Processed: #1######\\' +
                           'Updated: #2######\\' +
                           'Errors: #3######');

        // Find all entries with submission UIDs
        SubmissionLog.SetFilter("Submission UID", '<>%1', '');

        if SubmissionLog.FindSet() then begin
            repeat
                ProcessedCount += 1;
                ProgressDialog.Update(1, ProcessedCount);
                ProgressDialog.Update(2, UpdatedCount);
                ProgressDialog.Update(3, ErrorCount);

                // Try context-safe API call
                if TryRefreshStatusFromAPI(SubmissionLog."Submission UID", SubmissionDetails) then begin
                    // Extract and update status
                    LhdnStatus := ExtractStatusFromResponse(SubmissionDetails);
                    SubmissionLog.Status := LhdnStatus;
                    SubmissionLog."Response Date" := CurrentDateTime;
                    SubmissionLog."Last Updated" := CurrentDateTime;
                    SubmissionLog."Error Message" := '';

                    if SubmissionLog.Modify() then
                        UpdatedCount += 1;
                end else begin
                    // Check if this is due to context restrictions
                    if GetLastErrorText().Contains('context') then begin
                        ContextRestricted := true;
                        break; // Exit the loop if context restricted
                    end else begin
                        // Log other types of errors
                        SubmissionLog."Error Message" := CopyStr(GetLastErrorText(), 1, MaxStrLen(SubmissionLog."Error Message"));
                        SubmissionLog."Last Updated" := CurrentDateTime;
                        SubmissionLog.Modify();
                        ErrorCount += 1;
                    end;
                    ClearLastError();
                end;

                // Add delay to respect LHDN rate limiting
                Sleep(300);

            until SubmissionLog.Next() = 0;
        end;

        ProgressDialog.Close();

        if ContextRestricted then begin
            // Context restrictions detected - return false to trigger alternative handling
            exit(false);
        end else begin
            // Show completion message
            Message('Status refresh completed!\\\\' +
                   'Processed: %1 entries\\' +
                   'Updated: %2 entries\\' +
                   'Errors: %3 entries\\\\' +
                   'Check the Error Message field for any failed updates.',
                   ProcessedCount, UpdatedCount, ErrorCount);
            exit(true);
        end;
    end;

}