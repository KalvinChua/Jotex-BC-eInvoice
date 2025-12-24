codeunit 50312 "eInvoice Submission Status"
{
    Permissions = tabledata "eInvoiceSetup" = R,
                  tabledata "eInvoice Submission Log" = RIMD,
                  tabledata "Sales Invoice Header" = RIMD,
                  tabledata "Sales Cr.Memo Header" = RIMD,
                  tabledata "Company Information" = R,
                  tabledata "Job Queue Entry" = RIMD,
                  tabledata "Job Queue Log Entry" = RIMD;

    var
        eInvoiceHelper: Codeunit eInvoiceHelper;

    local procedure IsJotexCompany(): Boolean
    var
        CompanyInfo: Record "Company Information";
    begin
        exit(CompanyInfo.Get() and (CompanyInfo.Name = 'JOTEX SDN BHD'));
    end;


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
    procedure CheckSubmissionStatus(SubmissionUid: Text; var SubmissionDetails: Text; var DocumentType: Text): Boolean
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
        if not IsJotexCompany() then begin
            SubmissionDetails := 'Operation not permitted. This e-Invoice feature is enabled only for JOTEX SDN BHD.';
            exit(false);
        end;
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
        if ParseSubmissionResponse(ResponseText, SubmissionDetails, OverallStatus, DocumentCount, DateTimeReceived, DocumentType) then begin
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
    /// Parse validation errors from LHDN Get Submission API response
    /// Extracts error details from documentSummary for documents with Invalid/Rejected status
    /// Returns error object as JSON text for storage via ParseAndStoreErrorResponse
    /// </summary>
    /// <param name="ResponseText">Raw JSON response from LHDN Get Submission API</param>
    /// <param name="DocumentUuid">UUID of the document to find errors for</param>
    /// <param name="ErrorJsonText">Output: Error object as JSON text</param>
    /// <param name="HttpStatusCode">Output: HTTP status code (400 for validation errors)</param>
    /// <returns>True if errors were found and parsed successfully</returns>
    procedure ParseSubmissionResponseForErrors(ResponseText: Text; DocumentUuid: Text; var ErrorJsonText: Text; var HttpStatusCode: Integer): Boolean
    var
        JsonObject: JsonObject;
        JsonToken: JsonToken;
        DocumentSummaryArray: JsonArray;
        DocumentObject: JsonObject;
        ErrorObject: JsonObject;
        UuidValue: Text;
        StatusValue: Text;
        i: Integer;
    begin
        ErrorJsonText := '';
        HttpStatusCode := 0;

        // Parse the response JSON
        if not JsonObject.ReadFrom(ResponseText) then
            exit(false);

        // Get documentSummary array
        if not JsonObject.Get('documentSummary', JsonToken) then
            exit(false);

        if not JsonToken.IsArray() then
            exit(false);

        DocumentSummaryArray := JsonToken.AsArray();

        // Find the document matching the UUID
        for i := 0 to DocumentSummaryArray.Count() - 1 do begin
            DocumentSummaryArray.Get(i, JsonToken);
            if JsonToken.IsObject() then begin
                DocumentObject := JsonToken.AsObject();

                // Get UUID
                if DocumentObject.Get('uuid', JsonToken) then
                    UuidValue := CleanQuotesFromText(SafeJsonValueToText(JsonToken));

                // Check if this is the document we're looking for
                if UuidValue = DocumentUuid then begin
                    // Get status
                    if DocumentObject.Get('status', JsonToken) then
                        StatusValue := CleanQuotesFromText(SafeJsonValueToText(JsonToken));

                    // Check if status is Invalid or Rejected
                    if (StatusValue = 'Invalid') or (StatusValue = 'Rejected') then begin
                        // Get error object
                        if DocumentObject.Get('error', JsonToken) and JsonToken.IsObject() then begin
                            ErrorObject := JsonToken.AsObject();
                            // Convert error object to JSON text
                            ErrorObject.WriteTo(ErrorJsonText);
                            // Set HTTP status code to 400 (Bad Request) for validation errors
                            HttpStatusCode := 400;
                            exit(true);
                        end;
                    end;

                    // Document found but no errors or status is not Invalid/Rejected
                    exit(false);
                end;
            end;
        end;

        // Document UUID not found in response
        exit(false);
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
        DocumentType: Text;
    begin
        if not IsJotexCompany() then begin
            SubmissionDetails := 'Operation not permitted. This e-Invoice feature is enabled only for JOTEX SDN BHD.';
            exit(false);
        end;
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
                                     ResponseText, OverallStatus, DocumentCount, DateTimeReceived, PageDetails, DocumentType);

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
                                             ResponseText, OverallStatus, DocumentCount, DateTimeReceived, PageDetails, DocumentType);

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
    local procedure GetSubmissionPage(SubmissionUid: Text; PageNo: Integer; PageSize: Integer; var eInvoiceSetup: Record "eInvoiceSetup"; AccessToken: Text; CorrelationId: Text; var ResponseText: Text; var OverallStatus: Text; var DocumentCount: Integer; var DateTimeReceived: Text; var PageDetails: Text; var DocumentType: Text): Boolean
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
        if not ParseSubmissionResponse(ResponseText, PageDetails, OverallStatus, DocumentCount, DateTimeReceived, DocumentType) then begin
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
    local procedure ParseSubmissionResponse(ResponseText: Text; var SubmissionDetails: Text; var OverallStatus: Text; var DocumentCount: Integer; var DateTimeReceived: Text; var DocumentType: Text): Boolean
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
        DocumentType := '';

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

            // Extract document type from the first document if available
            if DocumentSummaryCount > 0 then begin
                DocumentSummaryArray.Get(0, JsonToken);
                if JsonToken.IsObject() then begin
                    DocumentJson := JsonToken.AsObject();
                    if DocumentJson.Get('typeName', JsonToken) then
                        DocumentType := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                end;
            end;
        end;

        exit(true);
    end;

    /// <summary>
    /// Build validation link using env base URL, UUID and Long ID per SDK guidance
    /// Docs: https://sdk.myinvois.hasil.gov.my/einvoicingapi/07-get-document/
    /// </summary>
    local procedure BuildValidationLink(DocumentUuid: Text; LongId: Text; Environment: Option Preprod,Production): Text
    var
        BaseUrl: Text;
    begin
        if (DocumentUuid = '') or (LongId = '') then
            exit('');

        if Environment = Environment::Preprod then
            BaseUrl := 'https://preprod.myinvois.hasil.gov.my'
        else
            BaseUrl := 'https://myinvois.hasil.gov.my';

        exit(StrSubstNo('%1/%2/share/%3', BaseUrl, DocumentUuid, LongId));
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
        if not IsJotexCompany() then begin
            DocumentDetails := 'Operation not permitted. This e-Invoice feature is enabled only for JOTEX SDN BHD.';
            exit(false);
        end;
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
    /// 
    /// ENHANCED DOCUMENT-LEVEL STATUS DETECTION:
    /// When DocumentUuid is provided, checks individual document status first,
    /// then falls back to submission-level status if no match found.
    /// </summary>
    local procedure ExtractStatusFromResponse(ResponseText: Text): Text
    var
        Status: Text;
        JsonObject: JsonObject;
        JsonToken: JsonToken;
        DocumentSummaryArray: JsonArray;
        DocumentJson: JsonObject;
        DocumentUuid: Text;
        DocumentStatus: Text;
        i: Integer;
    begin
        Status := 'Unknown';

        // Try to parse JSON response first for more accurate status extraction
        if JsonObject.ReadFrom(ResponseText) then begin
            // NEW: Check document-level status first (more specific than submission-level)
            if JsonObject.Get('documentSummary', JsonToken) and JsonToken.IsArray() then begin
                DocumentSummaryArray := JsonToken.AsArray();

                // If there's only one document in the submission, use its status directly
                if DocumentSummaryArray.Count() = 1 then begin
                    DocumentSummaryArray.Get(0, JsonToken);
                    if JsonToken.IsObject() then begin
                        DocumentJson := JsonToken.AsObject();
                        if DocumentJson.Get('status', JsonToken) then begin
                            DocumentStatus := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                            // Convert to proper capitalization
                            case DocumentStatus of
                                'valid':
                                    Status := 'Valid';
                                'invalid':
                                    Status := 'Invalid';
                                'cancelled':
                                    Status := 'Cancelled';
                                'in progress':
                                    Status := 'In Progress';
                                else
                                    Status := DocumentStatus; // Keep as-is for unknown statuses
                            end;
                            exit(Status); // Return document-level status
                        end;
                    end;
                end else if DocumentSummaryArray.Count() > 1 then begin
                    // Multiple documents - check if any are cancelled
                    for i := 0 to DocumentSummaryArray.Count() - 1 do begin
                        DocumentSummaryArray.Get(i, JsonToken);
                        if JsonToken.IsObject() then begin
                            DocumentJson := JsonToken.AsObject();
                            if DocumentJson.Get('status', JsonToken) then begin
                                DocumentStatus := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                                if DocumentStatus = 'cancelled' then begin
                                    Status := 'Partially Valid'; // At least one cancelled
                                    exit(Status);
                                end;
                            end;
                        end;
                    end;
                end;
            end;

            // Fallback to submission-level status if no document-level status found
            if JsonObject.Get('overallStatus', JsonToken) then begin
                Status := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
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
    /// Extract status for a specific document within a submission using UUID matching
    /// This overloaded version prioritizes the status of the document with matching UUID
    /// </summary>
    local procedure ExtractStatusFromResponse(ResponseText: Text; DocumentUuidToMatch: Text): Text
    var
        Status: Text;
        JsonObject: JsonObject;
        JsonToken: JsonToken;
        DocumentSummaryArray: JsonArray;
        DocumentJson: JsonObject;
        DocumentUuid: Text;
        DocumentStatus: Text;
        i: Integer;
        FoundMatch: Boolean;
        TotalDocuments: Integer;
        DebugInfo: Text;
    begin
        Status := 'Unknown';
        FoundMatch := false;
        DebugInfo := '';

        // Only proceed if we have a UUID to match
        if DocumentUuidToMatch = '' then
            exit(ExtractStatusFromResponse(ResponseText)); // Fall back to regular function

        // Try to parse JSON response and find matching document
        if JsonObject.ReadFrom(ResponseText) then begin
            if JsonObject.Get('documentSummary', JsonToken) and JsonToken.IsArray() then begin
                DocumentSummaryArray := JsonToken.AsArray();
                TotalDocuments := DocumentSummaryArray.Count();
                DebugInfo := StrSubstNo('Searching %1 documents for UUID: %2. ', TotalDocuments, DocumentUuidToMatch);

                // Search for document with matching UUID
                for i := 0 to DocumentSummaryArray.Count() - 1 do begin
                    DocumentSummaryArray.Get(i, JsonToken);
                    if JsonToken.IsObject() then begin
                        DocumentJson := JsonToken.AsObject();

                        // Check if this document's UUID matches
                        if DocumentJson.Get('uuid', JsonToken) then begin
                            DocumentUuid := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                            DebugInfo += StrSubstNo('Doc[%1]: %2. ', i + 1, CopyStr(DocumentUuid, 1, 10));

                            if DocumentUuid = DocumentUuidToMatch then begin
                                FoundMatch := true;
                                // Found matching document - get its status
                                if DocumentJson.Get('status', JsonToken) then begin
                                    DocumentStatus := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                                    DebugInfo += StrSubstNo('MATCH FOUND! Status: %1', DocumentStatus);
                                    // Convert to proper capitalization
                                    case DocumentStatus of
                                        'valid':
                                            Status := 'Valid';
                                        'invalid':
                                            Status := 'Invalid';
                                        'cancelled':
                                            Status := 'Cancelled';
                                        'in progress':
                                            Status := 'In Progress';
                                        else
                                            Status := DocumentStatus; // Keep as-is for unknown statuses
                                    end;
                                    exit(Status); // Return document-specific status
                                end else begin
                                    DebugInfo += 'MATCH FOUND but no status field!';
                                end;
                            end;
                        end else begin
                            DebugInfo += StrSubstNo('Doc[%1]: No UUID. ', i + 1);
                        end;
                    end;
                end;

                if not FoundMatch then begin
                    DebugInfo += 'NO MATCH FOUND - using submission status';
                end;
            end else begin
                DebugInfo := 'No documentSummary array found in response';
            end;
        end else begin
            DebugInfo := 'Failed to parse JSON response';
        end;

        // Log debug info (you can remove this later)
        // For now, we'll add it to a global debug log or display it somewhere

        // If document not found or no match, fall back to regular extraction
        exit(ExtractStatusFromResponse(ResponseText));
    end;    /// <summary>
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
        DocumentType: Text;
    begin
        if not IsJotexCompany() then
            exit;
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
                ApiSuccess := CheckSubmissionStatus(SubmissionLog."Submission UID", SubmissionDetails, DocumentType);

                if ApiSuccess then begin
                    // Update the log entry with current status from LHDN using Document UUID for precise matching
                    if SubmissionLog."Document UUID" <> '' then
                        SubmissionLog.Status := ExtractDocumentStatusFromJson(SubmissionDetails, SubmissionLog."Document UUID")
                    else
                        SubmissionLog.Status := ExtractDocumentStatusFromJson(SubmissionDetails);
                    SubmissionLog."Response Date" := CurrentDateTime;
                    SubmissionLog."Last Updated" := CurrentDateTime;
                    SubmissionLog."Error Message" := CopyStr(StrSubstNo('Background refresh: %1. Method: %2',
                                                                       SubmissionLog.Status,
                                                                       SubmissionLog."Document UUID" <> '' ? 'Document-level UUID matching' : 'Document-level status'),
                                                             1, MaxStrLen(SubmissionLog."Error Message"));
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
        // Variables for DATE_RANGE parameter parsing
        FromText: Text;
        ToText: Text;
        SecondPipe: Integer;
        FromDate: Date;
        ToDate: Date;
    begin
        if not IsJotexCompany() then
            exit;
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
                            // Extract status using Document UUID for precise matching when available
                            if SubmissionLogRec."Document UUID" <> '' then
                                LhdnStatus := ExtractDocumentStatusFromJson(SubmissionDetails, SubmissionLogRec."Document UUID")
                            else
                                LhdnStatus := ExtractDocumentStatusFromJson(SubmissionDetails);

                            SubmissionLogRec.Status := LhdnStatus;
                            SubmissionLogRec."Response Date" := CurrentDateTime;
                            SubmissionLogRec."Last Updated" := CurrentDateTime;
                            SubmissionLogRec."Error Message" := StrSubstNo('Background refresh completed at %1',
                                                                          Format(CurrentDateTime, 0, '<Day,2>/<Month,2>/<Year4> <Hours24,2>:<Minutes,2>'));
                            SubmissionLogRec.Modify();

                            // Synchronize the Posted Sales Invoice status
                            SynchronizePostedSalesInvoiceStatus(SubmissionLogRec."Invoice No.", LhdnStatus);
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
            end else if ParameterString.StartsWith('DATE_RANGE|') then begin
                // Date range background refresh
                PipePos := ParameterString.IndexOf('|');
                if PipePos > 0 then begin
                    FromText := CopyStr(ParameterString, PipePos + 1);
                    SecondPipe := FromText.IndexOf('|');
                    if SecondPipe > 0 then begin
                        ToText := CopyStr(FromText, SecondPipe + 1);
                        FromText := CopyStr(FromText, 1, SecondPipe - 1);
                        if Evaluate(FromDate, FromText) and Evaluate(ToDate, ToText) then
                            ProcessDateRangeForBackground(FromDate, ToDate);
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
        DocumentType: Text;
        // Variables for DATE_RANGE parameter parsing
        FromText2: Text;
        ToText2: Text;
        SecondPipe2: Integer;
        FromDate2: Date;
        ToDate2: Date;
        // Variables for error parsing
        ErrorJsonText: Text;
        HttpStatusCode: Integer;
        CorrelationId: Text;
    begin
        if not IsJotexCompany() then
            exit;
        // Find the current job queue entry to get parameters
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"eInvoice Submission Status");
        JobQueueEntry.SetRange(Status, JobQueueEntry.Status::"In Process");
        if JobQueueEntry.FindFirst() then begin
            ParameterString := JobQueueEntry."Parameter String";

            // Check parameter to determine the type of refresh
            if ParameterString.StartsWith('REFRESH_SINGLE|') then begin
                // Single submission refresh
                PipePos := ParameterString.IndexOf('|');
                if PipePos > 0 then begin
                    SubmissionUID := CopyStr(ParameterString, PipePos + 1);

                    // Find and refresh the specific submission
                    SubmissionLogRec.SetRange("Submission UID", SubmissionUID);
                    if SubmissionLogRec.FindFirst() then begin
                        // Direct API call - this runs in background context where HTTP is allowed
                        if CheckSubmissionStatus(SubmissionUID, SubmissionDetails, DocumentType) then begin
                            // Extract status using Document UUID for precise matching
                            if SubmissionLogRec."Document UUID" <> '' then
                                LhdnStatus := ExtractDocumentStatusFromJson(SubmissionDetails, SubmissionLogRec."Document UUID")
                            else
                                LhdnStatus := ExtractDocumentStatusFromJson(SubmissionDetails);

                            SubmissionLogRec.Status := LhdnStatus;
                            SubmissionLogRec."Response Date" := CurrentDateTime;
                            SubmissionLogRec."Last Updated" := CurrentDateTime;

                            // Parse and store validation errors if status is Invalid or Rejected
                            if (LhdnStatus = 'Invalid') or (LhdnStatus = 'Rejected') then begin
                                if SubmissionLogRec."Document UUID" <> '' then begin
                                    CorrelationId := CreateGuid();
                                    if ParseSubmissionResponseForErrors(SubmissionDetails, SubmissionLogRec."Document UUID", ErrorJsonText, HttpStatusCode) then begin
                                        // Store the error details using the same method as initial submission
                                        ParseAndStoreErrorResponse(SubmissionLogRec, ErrorJsonText, HttpStatusCode, CorrelationId);
                                    end else begin
                                        // If no errors found in response, set generic message
                                        SubmissionLogRec."Error Message" := 'Background refresh: Invalid - No detailed error information available';
                                    end;
                                end else begin
                                    // No Document UUID to match errors
                                    SubmissionLogRec."Error Message" := 'Background refresh: Invalid - Document UUID missing';
                                end;
                            end else begin
                                // For Valid, Accepted, or other statuses, set generic success message
                                SubmissionLogRec."Error Message" := StrSubstNo('Background refresh completed at %1',
                                                                              Format(CurrentDateTime, 0, '<Day,2>/<Month,2>/<Year4> <Hours24,2>:<Minutes,2>'));
                            end;

                            SubmissionLogRec.Modify();

                            // Synchronize the Posted Sales Invoice status
                            SynchronizePostedSalesInvoiceStatus(SubmissionLogRec."Invoice No.", LhdnStatus);
                        end else begin
                            // Log the error from background job
                            SubmissionLogRec."Error Message" := CopyStr(StrSubstNo('Background refresh failed: %1', SubmissionDetails),
                                                                      1, MaxStrLen(SubmissionLogRec."Error Message"));
                            SubmissionLogRec."Last Updated" := CurrentDateTime;
                            SubmissionLogRec.Modify();
                        end;
                    end;
                end;
            end else if ParameterString = 'BULK_REFRESH_ALL' then begin
                // Bulk refresh for all submissions - called from enhanced page action
                RefreshSubmissionStatusesBackground(); // Use the dedicated background procedure
            end else if ParameterString.StartsWith('DATE_RANGE|') then begin
                // Date range background refresh
                PipePos := ParameterString.IndexOf('|');
                if PipePos > 0 then begin
                    FromText2 := CopyStr(ParameterString, PipePos + 1);
                    SecondPipe2 := FromText2.IndexOf('|');
                    if SecondPipe2 > 0 then begin
                        ToText2 := CopyStr(FromText2, SecondPipe2 + 1);
                        FromText2 := CopyStr(FromText2, 1, SecondPipe2 - 1);
                        if Evaluate(FromDate2, FromText2) and Evaluate(ToDate2, ToText2) then
                            ProcessDateRangeForBackground(FromDate2, ToDate2);
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
    /// Process a date range for background status refresh
    /// Filters submission logs by Submission Date and refreshes their status
    /// </summary>
    local procedure ProcessDateRangeForBackground(FromDate: Date; ToDate: Date)
    var
        SubmissionLog: Record "eInvoice Submission Log";
        SubmissionDetails: Text;
        LhdnStatus: Text;
        DocumentType: Text;
        FromDT: DateTime;
        ToDT: DateTime;
        TrimmedUid: Text;
        ErrorJsonText: Text;
        HttpStatusCode: Integer;
        CorrelationId: Text;
    begin
        if (FromDate = 0D) or (ToDate = 0D) then
            exit;

        // Build inclusive DateTime range
        FromDT := CreateDateTime(FromDate, 000000T);
        ToDT := CreateDateTime(ToDate, 235959T);

        SubmissionLog.SetFilter("Submission UID", '<>%1', '');
        SubmissionLog.SetRange("Submission Date", FromDT, ToDT);

        if SubmissionLog.FindSet() then begin
            repeat
                // Normalize and validate Submission UID before calling API
                TrimmedUid := CleanQuotesFromText(SubmissionLog."Submission UID");
                TrimmedUid := DelChr(TrimmedUid, '<>', ' '); // trim leading/trailing spaces

                if not ValidateSubmissionUid(TrimmedUid) then begin
                    SubmissionLog."Error Message" := CopyStr(
                        StrSubstNo('Skipped: Invalid Submission UID format "%1" (trimmed from "%2").', TrimmedUid, SubmissionLog."Submission UID"),
                        1, MaxStrLen(SubmissionLog."Error Message"));
                    SubmissionLog."Last Updated" := CurrentDateTime;
                    SubmissionLog.Modify();
                    Sleep(100);
                    continue;
                end;

                if CheckSubmissionStatus(TrimmedUid, SubmissionDetails, DocumentType) then begin
                    if SubmissionLog."Document UUID" <> '' then
                        LhdnStatus := ExtractDocumentStatusFromJson(SubmissionDetails, SubmissionLog."Document UUID")
                    else
                        LhdnStatus := ExtractDocumentStatusFromJson(SubmissionDetails);

                    SubmissionLog.Status := LhdnStatus;
                    SubmissionLog."Response Date" := CurrentDateTime;
                    SubmissionLog."Last Updated" := CurrentDateTime;
                    if DocumentType <> '' then
                        SubmissionLog."Document Type" := DocumentType;

                    // Parse and store validation errors if status is Invalid or Rejected
                    if (LhdnStatus = 'Invalid') or (LhdnStatus = 'Rejected') then begin
                        if SubmissionLog."Document UUID" <> '' then begin
                            CorrelationId := CreateGuid();
                            if ParseSubmissionResponseForErrors(SubmissionDetails, SubmissionLog."Document UUID", ErrorJsonText, HttpStatusCode) then begin
                                // Store the error details using the same method as initial submission
                                ParseAndStoreErrorResponse(SubmissionLog, ErrorJsonText, HttpStatusCode, CorrelationId);
                            end;
                        end;
                    end;

                    SubmissionLog.Modify();

                    // Keep sales invoice header in sync
                    SynchronizePostedSalesInvoiceStatus(SubmissionLog."Invoice No.", LhdnStatus);
                end else begin
                    // Enhance 404 guidance when refreshing by date range
                    if SubmissionDetails.Contains('HTTP Error 404') then
                        SubmissionDetails += '\\Hint: 404 usually means the Submission UID was not found in the selected environment.\' +
                                             'Verify that your e-Invoice Setup Environment matches where this UID was created (Preprod vs Production).';

                    SubmissionLog."Error Message" := CopyStr(SubmissionDetails, 1, MaxStrLen(SubmissionLog."Error Message"));
                    SubmissionLog."Last Updated" := CurrentDateTime;
                    SubmissionLog.Modify();
                end;

                // Respect API rate limit
                Sleep(300);
            until SubmissionLog.Next() = 0;
        end;
    end;

    /// <summary>
    /// Try direct API call specifically for background job context
    /// Uses additional error handling for strict HTTP policy environments
    /// </summary>
    [TryFunction]
    local procedure TryDirectApiCallForBackground(SubmissionUid: Text; var SubmissionDetails: Text)
    var
        DocumentType: Text;
    begin
        // Initialize helper with minimal overhead
        eInvoiceHelper.InitializeHelper();

        // Attempt the status check with try-catch
        // If this fails even in job queue, it indicates very strict HTTP restrictions
        CheckSubmissionStatus(SubmissionUid, SubmissionDetails, DocumentType);
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
        DocumentType: Text;
    begin
        // Process a limited number of entries to avoid timeout
        SubmissionLog.SetFilter("Submission UID", '<>%1', '');
        SubmissionLog.SetRange(Status, 'Submitted'); // Only try submitted status

        if SubmissionLog.FindSet() then begin
            repeat
                ProcessedCount += 1;
                // Try to refresh this one entry
                CheckSubmissionStatus(SubmissionLog."Submission UID", SubmissionDetails, DocumentType);

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
        if not IsJotexCompany() then begin
            Message('Operation not permitted. This e-Invoice feature is enabled only for JOTEX SDN BHD.');
            exit(false);
        end;
        // Validate input
        if SubmissionLogRec."Submission UID" = '' then begin
            Message('No Submission UID found for this entry.');
            exit(false);
        end;

        // Try direct approach first (may fail due to context restrictions)
        if TryDirectApiCallForBackground(SubmissionLogRec."Submission UID", SubmissionDetails) then begin
            // Success - extract status and update using Document UUID for precise matching
            if SubmissionLogRec."Document UUID" <> '' then
                LhdnStatus := ExtractDocumentStatusFromJson(SubmissionDetails, SubmissionLogRec."Document UUID")
            else
                LhdnStatus := ExtractDocumentStatusFromJson(SubmissionDetails);

            // Update record
            SubmissionLogRec.Status := LhdnStatus;
            SubmissionLogRec."Response Date" := CurrentDateTime;
            SubmissionLogRec."Last Updated" := CurrentDateTime;
            SubmissionLogRec."Error Message" := CopyStr(StrSubstNo('Successfully refreshed from LHDN API. Method: %1',
                                                                  SubmissionLogRec."Document UUID" <> '' ? 'Document-level UUID matching' : 'Document-level status'),
                                                       1, MaxStrLen(SubmissionLogRec."Error Message"));
            SubmissionLogRec.Modify();

            // Status refreshed successfully - no message needed as requested by user
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
        DocumentType: Text;
        ErrorJsonText: Text;
        HttpStatusCode: Integer;
        CorrelationId: Text;
    begin
        if not IsJotexCompany() then begin
            Message('Operation not permitted. This e-Invoice feature is enabled only for JOTEX SDN BHD.');
            exit(false);
        end;
        // Validate that we have a submission UID
        if SubmissionLogRec."Submission UID" = '' then begin
            Message('No Submission UID found for this entry. Cannot refresh status.');
            exit(false);
        end;

        // Check status using LHDN API
        eInvoiceHelper.InitializeHelper();
        ApiSuccess := CheckSubmissionStatus(SubmissionLogRec."Submission UID", SubmissionDetails, DocumentType);

        if ApiSuccess then begin
            // Extract the proper status from LHDN response using Document UUID for precise matching
            if SubmissionLogRec."Document UUID" <> '' then
                LhdnStatus := ExtractDocumentStatusFromJson(SubmissionDetails, SubmissionLogRec."Document UUID")
            else
                LhdnStatus := ExtractDocumentStatusFromJson(SubmissionDetails);

            // Update the log entry with the current LHDN status
            SubmissionLogRec.Status := LhdnStatus;
            SubmissionLogRec."Response Date" := CurrentDateTime;
            SubmissionLogRec."Last Updated" := CurrentDateTime;
            if DocumentType <> '' then
                SubmissionLogRec."Document Type" := DocumentType;

            // Parse and store validation errors if status is Invalid or Rejected
            if (LhdnStatus = 'Invalid') or (LhdnStatus = 'Rejected') then begin
                if SubmissionLogRec."Document UUID" <> '' then begin
                    CorrelationId := CreateGuid();
                    if ParseSubmissionResponseForErrors(SubmissionDetails, SubmissionLogRec."Document UUID", ErrorJsonText, HttpStatusCode) then begin
                        // Store the error details using the same method as initial submission
                        // This will populate the Error Message field with validation error details
                        ParseAndStoreErrorResponse(SubmissionLogRec, ErrorJsonText, HttpStatusCode, CorrelationId);
                    end else begin
                        // If no errors found in response, set generic message
                        SubmissionLogRec."Error Message" := CopyStr('Status: Invalid - No detailed error information available from LHDN API', 1, MaxStrLen(SubmissionLogRec."Error Message"));
                    end;
                end else begin
                    // No Document UUID to match errors
                    SubmissionLogRec."Error Message" := CopyStr('Status: Invalid - Document UUID missing, cannot retrieve error details', 1, MaxStrLen(SubmissionLogRec."Error Message"));
                end;
            end else begin
                // For Valid, Accepted, or other statuses, set generic success message
                SubmissionLogRec."Error Message" := CopyStr(SubmissionDetails, 1, MaxStrLen(SubmissionLogRec."Error Message"));
            end;

            if SubmissionLogRec.Modify() then begin
                // Status refreshed successfully - no message needed as requested by user
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
        DocumentType: Text;
        ProgressDialog: Dialog;
        ErrorJsonText: Text;
        HttpStatusCode: Integer;
        CorrelationId: Text;
    begin
        if not IsJotexCompany() then begin
            Message('Operation not permitted. This e-Invoice feature is enabled only for JOTEX SDN BHD.');
            exit(0);
        end;
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
                ApiSuccess := CheckSubmissionStatus(SubmissionLog."Submission UID", SubmissionDetails, DocumentType);

                if ApiSuccess then begin
                    // Extract status using Document UUID for precise matching
                    if SubmissionLog."Document UUID" <> '' then
                        LhdnStatus := ExtractDocumentStatusFromJson(SubmissionDetails, SubmissionLog."Document UUID")
                    else
                        LhdnStatus := ExtractDocumentStatusFromJson(SubmissionDetails);

                    SubmissionLog.Status := LhdnStatus;
                    SubmissionLog."Response Date" := CurrentDateTime;
                    SubmissionLog."Last Updated" := CurrentDateTime;
                    if DocumentType <> '' then
                        SubmissionLog."Document Type" := DocumentType;

                    // Parse and store validation errors if status is Invalid or Rejected
                    if (LhdnStatus = 'Invalid') or (LhdnStatus = 'Rejected') then begin
                        if SubmissionLog."Document UUID" <> '' then begin
                            CorrelationId := CreateGuid();
                            if ParseSubmissionResponseForErrors(SubmissionDetails, SubmissionLog."Document UUID", ErrorJsonText, HttpStatusCode) then begin
                                // Store the error details using the same method as initial submission
                                ParseAndStoreErrorResponse(SubmissionLog, ErrorJsonText, HttpStatusCode, CorrelationId);
                            end else begin
                                // If no errors found in response, set generic message
                                SubmissionLog."Error Message" := CopyStr('Bulk refresh: Invalid - No detailed error information available', 1, MaxStrLen(SubmissionLog."Error Message"));
                            end;
                        end else begin
                            // No Document UUID to match errors
                            SubmissionLog."Error Message" := CopyStr('Bulk refresh: Invalid - Document UUID missing', 1, MaxStrLen(SubmissionLog."Error Message"));
                        end;
                    end else begin
                        // For Valid, Accepted, or other statuses, set generic success message
                        SubmissionLog."Error Message" := CopyStr(StrSubstNo('Bulk refresh: %1. Method: %2',
                                                                           LhdnStatus,
                                                                           SubmissionLog."Document UUID" <> '' ? 'Document-level UUID matching' : 'Document-level status'),
                                                                 1, MaxStrLen(SubmissionLog."Error Message"));
                    end;

                    if SubmissionLog.Modify() then begin
                        UpdatedCount += 1;
                        // Synchronize the Posted Sales Invoice status
                        SynchronizePostedSalesInvoiceStatus(SubmissionLog."Invoice No.", LhdnStatus);
                    end;
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
    /// Enhanced to use the same direct HttpClient approach as Posted Sales Invoice
    /// </summary>
    procedure RefreshSubmissionLogStatusSafe(var SubmissionLogRec: Record "eInvoice Submission Log"): Boolean
    var
        ContextRestricted: Boolean;
    begin
        if not IsJotexCompany() then begin
            Message('Operation not permitted. This e-Invoice feature is enabled only for JOTEX SDN BHD.');
            exit(false);
        end;

        // Try the direct method first with context restriction detection
        if TryRefreshSubmissionLogStatusInternal(SubmissionLogRec, true, ContextRestricted) then
            exit(true);

        // If context restricted, use alternative method
        if ContextRestricted then begin
            RefreshSubmissionLogStatusAlternative(SubmissionLogRec);
            exit(false);
        end;

        exit(false);
    end;

    /// <summary>
    /// Internal method for refreshing submission log status with optional message display
    /// </summary>
    local procedure RefreshSubmissionLogStatusSafeInternal(var SubmissionLogRec: Record "eInvoice Submission Log"; ShowMessages: Boolean): Boolean
    var
        HttpClient: HttpClient;
        HttpRequestMessage: HttpRequestMessage;
        HttpResponseMessage: HttpResponseMessage;
        RequestHeaders: HttpHeaders;
        AccessToken: Text;
        eInvoiceSetup: Record "eInvoiceSetup";
        ApiUrl: Text;
        ResponseText: Text;
        LhdnStatus: Text;
        CorrelationId: Text;
        SanitizedUid: Text;
        ErrorDetails: Text;
        HttpStatusCode: Integer;
    begin
        // Validate that we have a submission UID
        if SubmissionLogRec."Submission UID" = '' then begin
            if ShowMessages then
                Message('No Submission UID found for this entry. Cannot refresh status.');
            exit(false);
        end;

        // Get setup for environment determination
        if not eInvoiceSetup.Get('SETUP') then begin
            if ShowMessages then
                Message('eInvoice Setup not found');
            exit(false);
        end;

        // Get access token using the helper method (same as Posted Sales Invoice)
        eInvoiceHelper.InitializeHelper();
        AccessToken := eInvoiceHelper.GetAccessTokenFromSetup(eInvoiceSetup);
        if AccessToken = '' then begin
            if ShowMessages then
                Message('Failed to get access token');
            exit(false);
        end;

        // Sanitize and validate Submission UID
        SanitizedUid := CleanQuotesFromText(SubmissionLogRec."Submission UID");
        SanitizedUid := DelChr(SanitizedUid, '<>', ' ');
        if not ValidateSubmissionUid(SanitizedUid) then begin
            SubmissionLogRec."Error Message" := CopyStr(StrSubstNo('Invalid Submission UID: "%1" (original: "%2").', SanitizedUid, SubmissionLogRec."Submission UID"),
                                                        1, MaxStrLen(SubmissionLogRec."Error Message"));
            SubmissionLogRec."Last Updated" := CurrentDateTime;
            SubmissionLogRec.Modify();
            if ShowMessages then
                Message('Invalid Submission UID for this entry.');
            exit(false);
        end;

        // Build API URL same as other endpoints
        if eInvoiceSetup.Environment = eInvoiceSetup.Environment::Preprod then
            ApiUrl := StrSubstNo('https://preprod-api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions/%1', SanitizedUid)
        else
            ApiUrl := StrSubstNo('https://api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions/%1', SanitizedUid);

        // Setup request with standard headers per LHDN guidance
        CorrelationId := CreateGuid();
        HttpRequestMessage.Method('GET');
        HttpRequestMessage.SetRequestUri(ApiUrl);

        // Set headers
        HttpRequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Clear();
        RequestHeaders.Add('Accept', 'application/json');
        RequestHeaders.Add('Accept-Language', 'en');
        RequestHeaders.Add('Authorization', 'Bearer ' + AccessToken);
        RequestHeaders.Add('Content-Type', 'application/json; charset=utf-8');
        RequestHeaders.Add('User-Agent', 'BusinessCentral-eInvoice/2.0');
        RequestHeaders.Add('X-Correlation-ID', CorrelationId);
        RequestHeaders.Add('X-Request-Source', 'BusinessCentral-SubmissionLog');

        // Send request (same method as Posted Sales Invoice extension)
        // Wrap in try-catch to handle context restrictions gracefully
        if TryHttpClientSend(HttpClient, HttpRequestMessage, HttpResponseMessage) then begin
            HttpResponseMessage.Content().ReadAs(ResponseText);

            if HttpResponseMessage.IsSuccessStatusCode() then begin
                // Extract status using Document UUID for precise matching (same logic as Posted Sales Invoice)
                if SubmissionLogRec."Document UUID" <> '' then
                    LhdnStatus := ExtractDocumentStatusFromJson(ResponseText, SubmissionLogRec."Document UUID")
                else
                    LhdnStatus := ExtractDocumentStatusFromJson(ResponseText);

                // Update the log entry with the current LHDN status
                SubmissionLogRec.Status := LhdnStatus;
                SubmissionLogRec."Response Date" := CurrentDateTime;
                SubmissionLogRec."Last Updated" := CurrentDateTime;

                // Handle error details based on status
                if (LhdnStatus = 'Valid') or (LhdnStatus = 'Accepted') then begin
                    // Clear error fields for valid documents
                    SubmissionLogRec."Error Message" := '';
                    SubmissionLogRec."Error Code" := '';
                    SubmissionLogRec."Error English" := '';
                    SubmissionLogRec."Error Malay" := '';
                    SubmissionLogRec."Error Property Name" := '';
                    SubmissionLogRec."Error Property Path" := '';
                    SubmissionLogRec."Error Target" := '';
                    Clear(SubmissionLogRec."Inner Errors");
                    SubmissionLogRec."HTTP Status Code" := 0;
                end else if (LhdnStatus = 'Invalid') or (LhdnStatus = 'Rejected') then begin
                    // Parse and store validation errors from API response
                    if SubmissionLogRec."Document UUID" <> '' then begin
                        if ParseSubmissionResponseForErrors(ResponseText, SubmissionLogRec."Document UUID", ErrorDetails, HttpStatusCode) then begin
                            // Store the error details using the same method as initial submission
                            ParseAndStoreErrorResponse(SubmissionLogRec, ErrorDetails, HttpStatusCode, CorrelationId);
                        end;
                    end;
                end;
                // For other statuses (Submitted, In Progress), preserve existing error details

                if SubmissionLogRec.Modify() then begin
                    // Synchronize the Posted Sales Invoice status
                    SynchronizePostedSalesInvoiceStatus(SubmissionLogRec."Invoice No.", LhdnStatus);

                    // Status refreshed successfully - no message needed as requested by user
                    exit(true);
                end else begin
                    if ShowMessages then
                        Message('Failed to update the log entry. Please try again.');
                    exit(false);
                end;
            end else begin
                // Parse error response for better details when possible
                if ParseErrorResponse(ResponseText, ErrorDetails) then
                    ; // ErrorDetails populated
                if ErrorDetails = '' then
                    ErrorDetails := StrSubstNo('HTTP Error %1: %2', HttpResponseMessage.HttpStatusCode(), ResponseText);

                // For 404, provide environment hint
                if HttpResponseMessage.HttpStatusCode() = 404 then
                    ErrorDetails += StrSubstNo('\\Hint: 404 usually means the Submission UID was not found in the selected environment.\' +
                                               'Verify that the UID %1 exists in %2.', SanitizedUid, Format(eInvoiceSetup.Environment));

                if ShowMessages then
                    Message('Failed to retrieve status from LHDN API (Status Code: %1). Check the Error Message field for details.',
                           HttpResponseMessage.HttpStatusCode());

                SubmissionLogRec."Error Message" := CopyStr(ErrorDetails,
                                                            1, MaxStrLen(SubmissionLogRec."Error Message"));
                SubmissionLogRec."Last Updated" := CurrentDateTime;
                SubmissionLogRec.Modify();
                exit(false);
            end;
        end else begin
            // Failed to connect to LHDN API - check if it's due to context restrictions
            if GetLastErrorText().Contains('cannot be performed in this context') then begin
                if ShowMessages then
                    Message('Context Restriction - HTTP operations not allowed in this context.\\\\' +
                           'The system cannot perform HTTP operations in this UI context.\\\\' +
                           'Use the alternative refresh method or schedule a background job.');

                SubmissionLogRec."Error Message" := CopyStr('Context restriction: HTTP operations not allowed in this UI context.',
                                                           1, MaxStrLen(SubmissionLogRec."Error Message"));
                SubmissionLogRec."Last Updated" := CurrentDateTime;
                SubmissionLogRec.Modify();
                exit(false);
            end else begin
                // Other HTTP failures
                if ShowMessages then
                    Message('Failed to connect to LHDN API via direct HttpClient call.\\\\' +
                           'Error: %1\\\\' +
                           'This may be due to:\\' +
                           '- Network connectivity issues\\' +
                           '- LHDN API temporary unavailability',
                           GetLastErrorText());

                SubmissionLogRec."Error Message" := CopyStr(StrSubstNo('Direct API call failed: %1', GetLastErrorText()),
                                                           1, MaxStrLen(SubmissionLogRec."Error Message"));
                SubmissionLogRec."Last Updated" := CurrentDateTime;
                SubmissionLogRec.Modify();
                exit(false);
            end;
        end;
    end;

    /// <summary>
    /// Try to refresh submission log status with context restriction detection
    /// Returns true if successful, false if failed (with ContextRestricted flag set if due to context)
    /// </summary>
    [TryFunction]
    local procedure TryRefreshSubmissionLogStatusInternal(var SubmissionLogRec: Record "eInvoice Submission Log"; ShowMessages: Boolean; var ContextRestricted: Boolean)
    begin
        ContextRestricted := false;

        // Try to perform the HTTP operation
        if not RefreshSubmissionLogStatusSafeInternal(SubmissionLogRec, ShowMessages) then begin
            // Check if the failure was due to context restrictions
            if GetLastErrorText().Contains('cannot be performed in this context') or
               GetLastErrorText().Contains('Context restriction') then begin
                ContextRestricted := true;
            end;
        end;
    end;

    /// <summary>
    /// Safe HTTP client send with context restriction detection
    /// Returns true if successful, false if failed due to context restrictions
    /// </summary>
    [TryFunction]
    local procedure TryHttpClientSend(var HttpClient: HttpClient; var HttpRequestMessage: HttpRequestMessage; var HttpResponseMessage: HttpResponseMessage)
    begin
        HttpClient.Send(HttpRequestMessage, HttpResponseMessage);
    end;

    /// <summary>
    /// Alternative refresh method that can be called from different contexts
    /// This method attempts to refresh the status using a different approach
    /// </summary>
    procedure RefreshSubmissionLogStatusFromDifferentContext(var SubmissionLogRec: Record "eInvoice Submission Log"): Boolean
    var
        BackgroundJobCreated: Boolean;
    begin
        if not IsJotexCompany() then begin
            Message('Operation not permitted. This e-Invoice feature is enabled only for JOTEX SDN BHD.');
            exit(false);
        end;

        // Try to create a background job for this submission
        BackgroundJobCreated := CreateBackgroundStatusRefreshJob(SubmissionLogRec."Submission UID");

        if BackgroundJobCreated then begin
            Message('Background job created successfully for submission %1. The status will be refreshed automatically within the next few minutes.',
                    SubmissionLogRec."Submission UID");
            exit(true);
        end else begin
            Message('Failed to create background job. Please try again or contact system administrator.');
            exit(false);
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
                                  'Use tools like Postman or browser to test manually.\\\\' +
                                  'Would you like to schedule a background job to refresh this status?',
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

        // Offer to create a background job
        if Confirm('Would you like to schedule a background job to refresh this status?') then begin
            if CreateBackgroundStatusRefreshJob(SubmissionLogRec."Submission UID") then begin
                Message('Background job scheduled successfully. The status will be refreshed automatically within the next few minutes.');
            end else begin
                Message('Failed to schedule background job. Please contact system administrator.');
            end;
        end;

        Message(StatusMessage);
    end;

    /// <summary>
    /// Protected HTTP API call with try-catch for context restrictions
    /// Returns true if successful, false if context restrictions prevent HTTP operations
    /// </summary>
    [TryFunction]
    local procedure TryRefreshStatusFromAPI(SubmissionUid: Text; var SubmissionDetails: Text)
    var
        DocumentType: Text;
    begin
        // Initialize helper and attempt API call
        eInvoiceHelper.InitializeHelper();

        // The TryFunction attribute ensures any errors (including context restrictions) 
        // are caught and the function returns false gracefully
        CheckSubmissionStatus(SubmissionUid, SubmissionDetails, DocumentType);
    end;

    /// <summary>
    /// Context-safe refresh for all submission log entries
    /// Uses direct HttpClient approach (same as single refresh) to avoid context restrictions
    /// </summary>
    procedure RefreshAllSubmissionLogStatusesSafe(): Boolean
    var
        SubmissionLog: Record "eInvoice Submission Log";
        UpdatedCount: Integer;
        ProcessedCount: Integer;
        ErrorCount: Integer;
        ProgressDialog: Dialog;
        ContextRestricted: Boolean;
        FirstError: Text;
    begin
        if not IsJotexCompany() then begin
            Message('Operation not permitted. This e-Invoice feature is enabled only for JOTEX SDN BHD.');
            exit(false);
        end;
        UpdatedCount := 0;
        ProcessedCount := 0;
        ErrorCount := 0;
        ContextRestricted := false;
        FirstError := '';

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

                // Use the EXACT same method as single refresh for each record
                // This ensures each HTTP call is identical to the working single refresh
                // Use internal method without messages to avoid dialog bombardment
                if RefreshSubmissionLogStatusSafeInternal(SubmissionLog, false) then begin
                    UpdatedCount += 1;
                end else begin
                    // Check if this failed due to context restrictions
                    FirstError := GetLastErrorText();
                    if FirstError.Contains('Context restrictions') or
                       FirstError.Contains('HTTP operations') or
                       FirstError.Contains('not allowed') or
                       FirstError.Contains('context') then begin
                        ContextRestricted := true;
                        ErrorCount += 1;
                        break; // Exit the loop on first context restriction
                    end else begin
                        ErrorCount += 1;
                    end;
                end;

                // Add delay to respect LHDN rate limiting
                Sleep(300);

            until SubmissionLog.Next() = 0;
        end;

        ProgressDialog.Close();

        // Show completion message
        if ContextRestricted then begin
            Message('Bulk refresh stopped due to context restrictions!\\\\' +
                   'Processed: %1 entries\\' +
                   'Updated: %2 entries\\' +
                   'Errors: %3 entries\\\\' +
                   'Error: %4\\\\' +
                   'Context restrictions prevent HTTP operations in this UI context.\\' +
                   'Consider using individual refresh or background job for bulk operations.',
                   ProcessedCount, UpdatedCount, ErrorCount, FirstError);
            exit(false);
        end else begin
            Message('Status refresh completed!\\\\' +
                   'Processed: %1 entries\\' +
                   'Updated: %2 entries\\' +
                   'Errors: %3 entries\\\\' +
                   'Check the Error Message field for any failed updates.',
                   ProcessedCount, UpdatedCount, ErrorCount);
            exit(true);
        end;
    end;

    /// <summary>
    /// Extract document-level status from LHDN API JSON response
    /// Prioritizes individual document status over submission-level overallStatus
    /// </summary>
    local procedure ExtractDocumentStatusFromJson(ResponseText: Text): Text
    var
        JsonObject: JsonObject;
        JsonToken: JsonToken;
        DocumentSummaryArray: JsonArray;
        DocumentJson: JsonObject;
        OverallStatus: Text;
        DocumentStatus: Text;
    begin
        // Parse JSON response
        if not JsonObject.ReadFrom(ResponseText) then
            exit('Unknown');

        // Check for document-level status first (more accurate)
        if JsonObject.Get('documentSummary', JsonToken) and JsonToken.IsArray() then begin
            DocumentSummaryArray := JsonToken.AsArray();

            // For single document submissions, use the document status directly
            if DocumentSummaryArray.Count() = 1 then begin
                DocumentSummaryArray.Get(0, JsonToken);
                if JsonToken.IsObject() then begin
                    DocumentJson := JsonToken.AsObject();
                    if DocumentJson.Get('status', JsonToken) then begin
                        DocumentStatus := JsonToken.AsValue().AsText();
                        exit(FormatLhdnStatus(DocumentStatus));
                    end;
                end;
            end;
        end;

        // Fallback to submission-level overallStatus
        if JsonObject.Get('overallStatus', JsonToken) then begin
            OverallStatus := JsonToken.AsValue().AsText();
            exit(FormatLhdnStatus(OverallStatus));
        end;

        exit('Unknown');
    end;

    /// <summary>
    /// Extract document-level status using UUID matching for precise document identification
    /// </summary>
    local procedure ExtractDocumentStatusFromJson(ResponseText: Text; DocumentUuidToMatch: Text): Text
    var
        JsonObject: JsonObject;
        JsonToken: JsonToken;
        DocumentSummaryArray: JsonArray;
        DocumentJson: JsonObject;
        DocumentUuid: Text;
        DocumentStatus: Text;
        i: Integer;
    begin
        // If no UUID provided, use regular extraction
        if DocumentUuidToMatch = '' then
            exit(ExtractDocumentStatusFromJson(ResponseText));

        // Parse JSON response
        if not JsonObject.ReadFrom(ResponseText) then
            exit('Unknown');

        // Search for matching document UUID in documentSummary array
        if JsonObject.Get('documentSummary', JsonToken) and JsonToken.IsArray() then begin
            DocumentSummaryArray := JsonToken.AsArray();

            for i := 0 to DocumentSummaryArray.Count() - 1 do begin
                DocumentSummaryArray.Get(i, JsonToken);
                if JsonToken.IsObject() then begin
                    DocumentJson := JsonToken.AsObject();

                    // Check if this document matches our UUID
                    if DocumentJson.Get('uuid', JsonToken) then begin
                        DocumentUuid := JsonToken.AsValue().AsText();

                        if DocumentUuid = DocumentUuidToMatch then begin
                            // Found matching document - get its individual status
                            if DocumentJson.Get('status', JsonToken) then begin
                                DocumentStatus := JsonToken.AsValue().AsText();
                                exit(FormatLhdnStatus(DocumentStatus));
                            end;
                        end;
                    end;
                end;
            end;
        end;

        // If UUID not found, fallback to regular extraction
        exit(ExtractDocumentStatusFromJson(ResponseText));
    end;

    /// <summary>
    /// Format LHDN status values to consistent display format
    /// </summary>
    local procedure FormatLhdnStatus(StatusValue: Text): Text
    begin
        case LowerCase(StatusValue) of
            'valid':
                exit('Valid');
            'invalid':
                exit('Invalid');
            'cancelled':
                exit('Cancelled');
            'in progress':
                exit('In Progress');
            'partially valid':
                exit('Partially Valid');
            'rejected':
                exit('Rejected');
            'submitted':
                exit('Submitted');
            else
                exit(StatusValue); // Return as-is for unknown values
        end;
    end;

    /// <summary>
    /// Synchronize the Posted Sales Invoice status with the submission log status
    /// This ensures both entities have consistent status information
    /// </summary>
    /// <param name="InvoiceNo">The invoice number to update</param>
    /// <param name="NewStatus">The new status from LHDN</param>
    local procedure SynchronizePostedSalesInvoiceStatus(InvoiceNo: Code[20]; NewStatus: Text)
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        eInvoiceGenerator: Codeunit "eInvoice JSON Generator";
    begin
        // Only proceed if we have a valid invoice number
        if InvoiceNo = '' then
            exit;

        // Try to get the posted sales invoice
        if SalesInvoiceHeader.Get(InvoiceNo) then begin
            // Use the existing UpdateInvoiceValidationStatus procedure from the JSON Generator codeunit
            // This ensures consistent status formatting and proper permissions
            if not eInvoiceGenerator.UpdateInvoiceValidationStatus(InvoiceNo, NewStatus) then begin
                // Log the failure but don't stop the process
                Session.LogMessage('0000EIV03', StrSubstNo('Failed to synchronize Posted Sales Invoice status for invoice %1 with status %2',
                    InvoiceNo, NewStatus),
                    Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, '', '');
            end;
        end;
    end;

    /// <summary>
    /// Update existing submission log entries with empty Document Type fields
    /// This procedure can be called to populate Document Type for existing records
    /// </summary>
    procedure UpdateExistingDocumentTypes(): Integer
    var
        SubmissionLog: Record "eInvoice Submission Log";
        SalesInvoiceHeader: Record "Sales Invoice Header";
        UpdatedCount: Integer;
    begin
        if not IsJotexCompany() then begin
            Message('Operation not permitted. This e-Invoice feature is enabled only for JOTEX SDN BHD.');
            exit(0);
        end;
        UpdatedCount := 0;

        // Find all submission log entries with empty Document Type
        SubmissionLog.SetFilter("Document Type", '');
        SubmissionLog.SetFilter("Invoice No.", '<>%1', '');

        if SubmissionLog.FindSet() then begin
            repeat
                // Try to get document type from the corresponding Sales Invoice Header
                if SalesInvoiceHeader.Get(SubmissionLog."Invoice No.") then begin
                    if SalesInvoiceHeader."eInvoice Document Type" <> '' then begin
                        SubmissionLog."Document Type" := SalesInvoiceHeader."eInvoice Document Type";
                        SubmissionLog."Last Updated" := CurrentDateTime;
                        if SubmissionLog.Modify() then
                            UpdatedCount += 1;
                    end;
                end;
            until SubmissionLog.Next() = 0;
        end;

        if UpdatedCount > 0 then
            Message('Updated Document Type for %1 existing submission log entries.', UpdatedCount)
        else
            Message('No submission log entries found with empty Document Type fields.');

        exit(UpdatedCount);
    end;

    /// <summary>
    /// Get entries that can be deleted (no Submission UID OR no Document UUID, including literal 'null' values)
    /// </summary>
    /// <param name="SubmissionLog">Filtered record set of deletable entries</param>
    /// <param name="DeleteEntries">Whether to actually delete the entries</param>
    /// <returns>Number of entries that can be deleted</returns>
    procedure GetDeletableEntries(var SubmissionLog: Record "eInvoice Submission Log"; DeleteEntries: Boolean): Integer
    var
        TempSubmissionLog: Record "eInvoice Submission Log" temporary;
        DeletedCount: Integer;
    begin
        // Reset the record to clear any existing filters

        // Set filter to show entries without Submission UID OR without Document UUID (including literal 'null')
        SubmissionLog.SetFilter("Submission UID", '%1|%2', '', 'null');
        SubmissionLog.SetFilter("Document UUID", '%1|%2', '', 'null');

        if DeleteEntries then begin
            DeletedCount := 0;
            if SubmissionLog.FindSet() then
                repeat
                    if SubmissionLog.Delete() then
                        DeletedCount += 1;
                until SubmissionLog.Next() = 0;
            exit(DeletedCount);
        end else begin
            exit(SubmissionLog.Count());
        end;
    end;

    /// <summary>
    /// Clean up old submission log entries that meet deletion criteria (including literal 'null' values)
    /// </summary>
    /// <param name="OlderThanDays">Delete entries older than specified days</param>
    /// <param name="DeleteEntries">Whether to actually delete the entries</param>
    /// <returns>Number of entries that can be deleted</returns>
    procedure CleanupOldDeletableEntries(OlderThanDays: Integer; DeleteEntries: Boolean): Integer
    var
        SubmissionLog: Record "eInvoice Submission Log";
        CutoffDate: DateTime;
        DeletableCount: Integer;
        CanDelete: Boolean;
    begin
        CutoffDate := CreateDateTime(CalcDate(StrSubstNo('-%1D', OlderThanDays), Today), 0T);

        // Find all old entries and check deletion criteria
        SubmissionLog.SetFilter("Submission Date", '<%1', CutoffDate);

        DeletableCount := 0;

        if SubmissionLog.FindSet() then
            repeat
                CanDelete := false;

                // Check if entry can be deleted based on various criteria
                if (SubmissionLog."Submission UID" = '') or (SubmissionLog."Submission UID" = 'null') then
                    CanDelete := true
                else if (SubmissionLog."Document UUID" = '') or (SubmissionLog."Document UUID" = 'null') then
                    CanDelete := true
                else if (SubmissionLog.Status = 'Invalid') or (SubmissionLog.Status = 'Submitted') then
                    CanDelete := true;

                if CanDelete then begin
                    DeletableCount += 1;
                    if DeleteEntries then
                        SubmissionLog.Delete(true);
                end;
            until SubmissionLog.Next() = 0;

        exit(DeletableCount);
    end;

    /// <summary>
    /// Check if the current context allows HTTP operations
    /// Returns true if HTTP operations are allowed, false if restricted
    /// </summary>
    procedure IsHttpContextAllowed(): Boolean
    var
        TestHttpClient: HttpClient;
        TestHttpRequestMessage: HttpRequestMessage;
        TestHttpResponseMessage: HttpResponseMessage;
        TestUrl: Text;
    begin
        // Try a simple HTTP operation to test context
        TestUrl := 'https://httpbin.org/get';
        TestHttpRequestMessage.Method('GET');
        TestHttpRequestMessage.SetRequestUri(TestUrl);

        exit(TryHttpClientSend(TestHttpClient, TestHttpRequestMessage, TestHttpResponseMessage));
    end;

    /// <summary>
    /// Parse MyInvois standard error response and store details in submission log
    /// According to https://sdk.myinvois.hasil.gov.my/standard-error-response/
    /// </summary>
    procedure ParseAndStoreErrorResponse(var SubmissionLog: Record "eInvoice Submission Log"; ResponseText: Text; HttpStatusCode: Integer; CorrelationId: Text)
    var
        JsonObject: JsonObject;
        ErrorObject: JsonObject;
        JsonToken: JsonToken;
        InnerErrorArray: JsonArray;
        InnerErrorsOutStream: OutStream;
        InnerErrorsText: Text;
        i: Integer;
        InnerErrorObject: JsonObject;
        ErrorSummary: Text;
    begin
        // Store HTTP status code and correlation ID
        SubmissionLog."HTTP Status Code" := HttpStatusCode;
        SubmissionLog."Correlation ID" := CopyStr(CorrelationId, 1, 100);

        // Try to parse JSON response
        if not JsonObject.ReadFrom(ResponseText) then begin
            SubmissionLog."Error Message" := CopyStr('Failed to parse error response: ' + ResponseText, 1, 2048);
            SubmissionLog.Modify(true);
            exit;
        end;

        // Parse main error object according to LHDN standard structure
        if JsonObject.Get('error', JsonToken) and JsonToken.IsObject() then begin
            ErrorObject := JsonToken.AsObject();

            // Extract errorCode
            if ErrorObject.Get('errorCode', JsonToken) then
                SubmissionLog."Error Code" := CopyStr(CleanQuotesFromText(SafeJsonValueToText(JsonToken)), 1, 50);

            // Extract propertyName
            if ErrorObject.Get('propertyName', JsonToken) then
                SubmissionLog."Error Property Name" := CopyStr(CleanQuotesFromText(SafeJsonValueToText(JsonToken)), 1, 250);

            // Extract propertyPath
            if ErrorObject.Get('propertyPath', JsonToken) then
                SubmissionLog."Error Property Path" := CopyStr(CleanQuotesFromText(SafeJsonValueToText(JsonToken)), 1, 250);

            // Extract error (English message)
            if ErrorObject.Get('error', JsonToken) then
                SubmissionLog."Error English" := CopyStr(CleanQuotesFromText(SafeJsonValueToText(JsonToken)), 1, 2048);

            // Extract errorMS (Malay message)
            if ErrorObject.Get('errorMS', JsonToken) then
                SubmissionLog."Error Malay" := CopyStr(CleanQuotesFromText(SafeJsonValueToText(JsonToken)), 1, 2048);

            // Extract target
            if ErrorObject.Get('target', JsonToken) then
                SubmissionLog."Error Target" := CopyStr(CleanQuotesFromText(SafeJsonValueToText(JsonToken)), 1, 250);

            // Handle inner errors
            if ErrorObject.Get('innerError', JsonToken) and JsonToken.IsArray() then begin
                InnerErrorArray := JsonToken.AsArray();

                // Store inner errors as JSON in blob field
                Clear(SubmissionLog."Inner Errors");
                SubmissionLog."Inner Errors".CreateOutStream(InnerErrorsOutStream);
                InnerErrorArray.WriteTo(InnerErrorsText);
                InnerErrorsOutStream.WriteText(InnerErrorsText);
            end;

            // Build summary error message for display
            ErrorSummary := '';
            if SubmissionLog."Error Code" <> '' then
                ErrorSummary += SubmissionLog."Error Code" + ': ';
            if SubmissionLog."Error English" <> '' then
                ErrorSummary += SubmissionLog."Error English"
            else if SubmissionLog."Error Malay" <> '' then
                ErrorSummary += SubmissionLog."Error Malay";

            if ErrorSummary <> '' then
                SubmissionLog."Error Message" := CopyStr(ErrorSummary, 1, 2048);
        end else begin
            // No standard error object found, store raw response
            SubmissionLog."Error Message" := CopyStr('Non-standard error response: ' + ResponseText, 1, 2048);
        end;

        SubmissionLog.Modify(true);
    end;

    /// <summary>
    /// Get formatted error details for display (with inner errors) - Simple version
    /// </summary>
    procedure GetFormattedErrorDetails(var SubmissionLog: Record "eInvoice Submission Log"): Text
    var
        InnerErrorsInStream: InStream;
        InnerErrorsText: Text;
        InnerErrorArray: JsonArray;
        JsonToken: JsonToken;
        InnerErrorObject: JsonObject;
        FormattedDetails: Text;
        i: Integer;
        InnerErrorCode: Text;
        InnerError: Text;
        InnerErrorMS: Text;
    begin
        FormattedDetails := '';

        // Status
        FormattedDetails := 'Status: ' + Format(SubmissionLog.Status) + '\\\\';

        // Main error
        if SubmissionLog."Error Code" <> '' then
            FormattedDetails += 'Error Code: ' + SubmissionLog."Error Code" + '\\';

        if SubmissionLog."Error English" <> '' then
            FormattedDetails += 'Error: ' + SubmissionLog."Error English" + '\\';

        if SubmissionLog."Error Malay" <> '' then
            FormattedDetails += 'Error MS: ' + SubmissionLog."Error Malay" + '\\';

        // Inner errors
        if SubmissionLog."Inner Errors".HasValue then begin
            SubmissionLog."Inner Errors".CreateInStream(InnerErrorsInStream);
            InnerErrorsInStream.ReadText(InnerErrorsText);

            if InnerErrorArray.ReadFrom(InnerErrorsText) then begin
                if InnerErrorArray.Count() > 0 then begin
                    FormattedDetails += '\\Inner Errors:\\';

                    for i := 0 to InnerErrorArray.Count() - 1 do begin
                        InnerErrorArray.Get(i, JsonToken);
                        if JsonToken.IsObject() then begin
                            InnerErrorObject := JsonToken.AsObject();
                            InnerErrorCode := '';
                            InnerError := '';
                            InnerErrorMS := '';

                            if InnerErrorObject.Get('errorCode', JsonToken) then
                                InnerErrorCode := CleanQuotesFromText(SafeJsonValueToText(JsonToken));

                            if InnerErrorObject.Get('error', JsonToken) then
                                InnerError := CleanQuotesFromText(SafeJsonValueToText(JsonToken));

                            if InnerErrorObject.Get('errorMS', JsonToken) then
                                InnerErrorMS := CleanQuotesFromText(SafeJsonValueToText(JsonToken));

                            FormattedDetails += StrSubstNo('  %1) ', i + 1);
                            if InnerErrorCode <> '' then
                                FormattedDetails += 'Code: ' + InnerErrorCode + ' - ';
                            FormattedDetails += InnerError + '\\';
                            if InnerErrorMS <> '' then
                                FormattedDetails += '     MS: ' + InnerErrorMS + '\\';
                        end;
                    end;
                end;
            end;
        end;

        // If no structured error found, show raw message
        if (SubmissionLog."Error Code" = '') and (SubmissionLog."Error English" = '') then begin
            if SubmissionLog."Error Message" <> '' then
                FormattedDetails := SubmissionLog."Error Message"
            else
                FormattedDetails := 'No error details available for this submission.';
        end;

        exit(FormattedDetails);
    end;

    /// <summary>
    /// Translate error codes to user-friendly explanations
    /// </summary>
    local procedure GetUserFriendlyErrorExplanation(ErrorCode: Text): Text
    begin
        case ErrorCode of
            'Error03', 'DS302':
                exit('This invoice has already been submitted to LHDN. You cannot submit the same invoice twice.');
            'Error01':
                exit('Some required information is missing or incorrect in the invoice.');
            'Error02':
                exit('The invoice format does not meet LHDN requirements.');
            'IV001':
                exit('The invoice number or date is invalid.');
            'IV002':
                exit('Customer details (TIN/ID) are invalid or missing.');
            'IV003':
                exit('The invoice total amount does not match the line items.');
            'IV004':
                exit('Tax calculation is incorrect.');
            'Auth01', 'Auth02':
                exit('Authentication failed. Your LHDN credentials may be invalid.');
            else
                exit('');
        end;
    end;

    /// <summary>
    /// Convert technical field paths to user-friendly names
    /// </summary>
    local procedure GetUserFriendlyFieldName(PropertyPath: Text): Text
    begin
        if PropertyPath.Contains('TIN') or PropertyPath.Contains('tin') then
            exit('Tax Identification Number (TIN)');
        if PropertyPath.Contains('Invoice') and PropertyPath.Contains('Number') then
            exit('Invoice Number');
        if PropertyPath.Contains('Date') then
            exit('Invoice Date');
        if PropertyPath.Contains('Customer') then
            exit('Customer Information');
        if PropertyPath.Contains('Amount') or PropertyPath.Contains('Total') then
            exit('Invoice Amount/Total');
        if PropertyPath.Contains('Tax') then
            exit('Tax Information');
        if PropertyPath.Contains('Item') or PropertyPath.Contains('Line') then
            exit('Invoice Line Items');

        // Return original if no match found
        exit(PropertyPath);
    end;

    /// <summary>
    /// Provide user-friendly action steps based on error
    /// </summary>
    local procedure GetUserFriendlyActionSteps(ErrorCode: Text; ErrorMessage: Text): Text
    var
        ActionSteps: Text;
    begin
        ActionSteps := '';

        case ErrorCode of
            'Error03', 'DS302':
                begin
                    ActionSteps += '1. This invoice was already submitted successfully\\';
                    ActionSteps += '2. Check the e-Invoice Submission Log for the original submission\\';
                    ActionSteps += '3. If you need to make changes, cancel the original and resubmit\\';
                end;
            'Error01':
                begin
                    ActionSteps += '1. Review all invoice fields for missing or incorrect data\\';
                    ActionSteps += '2. Verify customer TIN and registration details\\';
                    ActionSteps += '3. Check that all required fields are filled in\\';
                end;
            'Error02':
                begin
                    ActionSteps += '1. Ensure the invoice format meets LHDN requirements\\';
                    ActionSteps += '2. Contact IT support to review the invoice structure\\';
                end;
            'Auth01', 'Auth02':
                begin
                    ActionSteps += '1. Check your LHDN API credentials in e-Invoice Setup\\';
                    ActionSteps += '2. Verify that your credentials are active in LHDN portal\\';
                    ActionSteps += '3. Contact your system administrator\\';
                end;
            else begin
                ActionSteps += '1. Review the error message details above\\';
                ActionSteps += '2. Correct any identified issues in the invoice\\';
                ActionSteps += '3. Try submitting again\\';
                ActionSteps += '4. Contact IT support if the problem continues\\';
            end;
        end;

        exit(ActionSteps);
    end;

}