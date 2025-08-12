codeunit 50320 "eInvoice Cancellation Helper"
{
    TableNo = "eInvoice Submission Log";
    Permissions = tabledata "Sales Invoice Header" = M,
                  tabledata "Sales Cr.Memo Header" = M,
                  tabledata "eInvoice Submission Log" = M;

    trigger OnRun()
    begin
        UpdateCancellationStatus(Rec);
    end;

    /// <summary>
    /// Update cancellation status in submission log - designed to run in isolated context
    /// </summary>
    procedure UpdateCancellationStatus(var eInvoiceSubmissionLog: Record "eInvoice Submission Log")
    var
        TelemetryDimensions: Dictionary of [Text, Text];
        CompanyInfo: Record "Company Information";
    begin
        // Only process for JOTEX SDN BHD
        if not CompanyInfo.Get() or (CompanyInfo.Name <> 'JOTEX SDN BHD') then
            exit;

        if eInvoiceSubmissionLog."Invoice No." = '' then
            exit;

        // Update the status
        eInvoiceSubmissionLog.Status := 'Cancelled';
        eInvoiceSubmissionLog."Cancellation Date" := CurrentDateTime;

        if eInvoiceSubmissionLog.Modify(true) then begin
            TelemetryDimensions.Add('InvoiceNo', eInvoiceSubmissionLog."Invoice No.");
            Session.LogMessage('0000EIV07', 'Cancellation status updated in submission log',
                Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                TelemetryDimensions);
        end;
    end;

    /// <summary>
    /// Update cancellation status by invoice number - safe method for external calls
    /// </summary>
    procedure UpdateCancellationStatusByInvoice(InvoiceNo: Code[20]; CancellationReason: Text): Boolean
    var
        eInvoiceSubmissionLog: Record "eInvoice Submission Log";
        CompanyInfo: Record "Company Information";
        TelemetryDimensions: Dictionary of [Text, Text];
        RecordCount: Integer;
    begin
        // Only process for JOTEX SDN BHD
        if not CompanyInfo.Get() or (CompanyInfo.Name <> 'JOTEX SDN BHD') then begin
            TelemetryDimensions.Add('InvoiceNo', InvoiceNo);
            TelemetryDimensions.Add('Error', 'Company validation failed or not JOTEX SDN BHD');
            Session.LogMessage('0000EIV08', 'Cancellation update failed - company validation',
                Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                TelemetryDimensions);
            exit(false);
        end;

        // Find all submission logs for this invoice first
        eInvoiceSubmissionLog.SetRange("Invoice No.", InvoiceNo);
        RecordCount := eInvoiceSubmissionLog.Count();

        if RecordCount = 0 then begin
            TelemetryDimensions.Add('InvoiceNo', InvoiceNo);
            TelemetryDimensions.Add('Error', 'No submission log records found');
            Session.LogMessage('0000EIV08', 'Cancellation update failed - no records found',
                Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                TelemetryDimensions);
            exit(false);
        end;

        // Now filter for Valid status
        eInvoiceSubmissionLog.SetRange(Status, 'Valid');
        if not eInvoiceSubmissionLog.FindLast() then begin
            // Log available statuses for debugging
            eInvoiceSubmissionLog.SetRange(Status);  // Remove status filter
            if eInvoiceSubmissionLog.FindSet() then begin
                TelemetryDimensions.Add('InvoiceNo', InvoiceNo);
                TelemetryDimensions.Add('TotalRecords', Format(RecordCount));
                TelemetryDimensions.Add('Error', 'No Valid status records found');
                Session.LogMessage('0000EIV08', 'Cancellation update failed - no Valid status records',
                    Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                    TelemetryDimensions);
            end;
            exit(false);
        end;

        // Update the status
        eInvoiceSubmissionLog.Status := 'Cancelled';
        eInvoiceSubmissionLog."Cancellation Reason" := CopyStr(CancellationReason, 1, MaxStrLen(eInvoiceSubmissionLog."Cancellation Reason"));
        eInvoiceSubmissionLog."Cancellation Date" := CurrentDateTime;

        if eInvoiceSubmissionLog.Modify(true) then begin
            TelemetryDimensions.Add('InvoiceNo', InvoiceNo);
            TelemetryDimensions.Add('OriginalUUID', eInvoiceSubmissionLog."Document UUID");
            Session.LogMessage('0000EIV07', 'Cancellation status updated successfully in submission log',
                Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                TelemetryDimensions);
            exit(true);
        end else begin
            TelemetryDimensions.Add('InvoiceNo', InvoiceNo);
            TelemetryDimensions.Add('Error', 'Modify operation failed');
            Session.LogMessage('0000EIV08', 'Cancellation update failed - modify failed',
                Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                TelemetryDimensions);
            exit(false);
        end;
    end;



    /// <summary>
    /// Updates Customer Name for existing e-invoice submission log entries that have empty customer names.
    /// Enhanced to support both invoices and credit memos.
    /// </summary>
    procedure UpdateExistingCustomerNames()
    var
        SubmissionLog: Record "eInvoice Submission Log";
        Customer: Record Customer;
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        CustomerName: Text;
        UpdatedCount: Integer;
    begin
        UpdatedCount := 0;

        // Find all submission log entries with empty customer names
        SubmissionLog.SetRange("Customer Name", '');
        if SubmissionLog.FindSet() then begin
            repeat
                CustomerName := '';

                // ENHANCED: Check document type to determine which table to lookup
                case SubmissionLog."Document Type" of
                    '01': // Invoice
                        begin
                            if SalesInvoiceHeader.Get(SubmissionLog."Invoice No.") then begin
                                if Customer.Get(SalesInvoiceHeader."Sell-to Customer No.") then
                                    CustomerName := Customer.Name;
                            end;
                        end;
                    '02': // Credit Memo
                        begin
                            if SalesCrMemoHeader.Get(SubmissionLog."Invoice No.") then begin
                                if Customer.Get(SalesCrMemoHeader."Sell-to Customer No.") then
                                    CustomerName := Customer.Name;
                            end;
                        end;
                    else
                        // Fallback: Try invoice first, then credit memo
                        begin
                        if SalesInvoiceHeader.Get(SubmissionLog."Invoice No.") then begin
                            if Customer.Get(SalesInvoiceHeader."Sell-to Customer No.") then
                                CustomerName := Customer.Name;
                        end else if SalesCrMemoHeader.Get(SubmissionLog."Invoice No.") then begin
                            if Customer.Get(SalesCrMemoHeader."Sell-to Customer No.") then
                                CustomerName := Customer.Name;
                        end;
                    end;
                end;

                // Update the record if we found a customer name
                if CustomerName <> '' then begin
                    SubmissionLog."Customer Name" := CustomerName;
                    SubmissionLog.Modify();
                    UpdatedCount += 1;
                end;
            until SubmissionLog.Next() = 0;
        end;

        // Show results to user
        if UpdatedCount > 0 then
            Message('Successfully updated Customer Name for %1 existing submission log entries.', UpdatedCount)
        else
            Message('No submission log entries with empty Customer Name were found.');
    end;

    /// <summary>
    /// Enhanced cancellation procedure that supports both invoices and credit memos with LHDN API integration
    /// </summary>
    procedure CancelDocument(DocumentNo: Code[20]; CancellationReason: Text): Boolean
    var
        eInvoiceSubmissionLog: Record "eInvoice Submission Log";
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        eInvPostingSubscribers: Codeunit "eInv Posting Subscribers";
        DocumentType: Text;
        IsInvoice: Boolean;
        IsCreditMemo: Boolean;
        Success: Boolean;
    begin
        // Determine document type by checking which table contains the document
        IsInvoice := SalesInvoiceHeader.Get(DocumentNo);
        IsCreditMemo := SalesCrMemoHeader.Get(DocumentNo);

        if IsInvoice then begin
            DocumentType := '01';
            // For invoices, use the existing proven LHDN API cancellation method
            Success := eInvPostingSubscribers.CancelEInvoiceDocument(SalesInvoiceHeader, CancellationReason);
        end else if IsCreditMemo then begin
            DocumentType := '02';
            // For credit memos, use the new LHDN API cancellation method
            Success := CancelCreditMemoInLHDN(SalesCrMemoHeader, CancellationReason);
        end else begin
            Message('Document %1 not found in either Sales Invoice or Sales Credit Memo tables.', DocumentNo);
            exit(false);
        end;

        if Success then begin
            // Update local status after successful LHDN cancellation
            if IsInvoice then begin
                SalesInvoiceHeader."eInvoice Validation Status" := 'Cancelled';
                SalesInvoiceHeader.Modify();
                Message('Successfully cancelled Invoice %1 in LHDN system', DocumentNo);
            end else if IsCreditMemo then begin
                SalesCrMemoHeader."eInvoice Validation Status" := 'Cancelled';
                SalesCrMemoHeader.Modify();
                Message('Successfully cancelled Credit Memo %1 in LHDN system', DocumentNo);
            end;
            exit(true);
        end else begin
            if IsInvoice then
                Message('Failed to cancel Invoice %1 in LHDN system. Please check the submission log for details.', DocumentNo)
            else
                Message('Failed to cancel Credit Memo %1 in LHDN system. Please check the submission log for details.', DocumentNo);
            exit(false);
        end;
    end;

    /// <summary>
    /// Alternative cancellation method with transaction isolation - mirrors posted sales invoice pattern
    /// </summary>
    procedure CancelDocumentWithIsolation(DocumentNo: Code[20]; CancellationReason: Text): Boolean
    var
        eInvoiceSubmissionLog: Record "eInvoice Submission Log";
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        DocumentType: Text;
        IsInvoice: Boolean;
        IsCreditMemo: Boolean;
    begin
        // Determine document type by checking which table contains the document
        IsInvoice := SalesInvoiceHeader.Get(DocumentNo);
        IsCreditMemo := SalesCrMemoHeader.Get(DocumentNo);

        if IsInvoice then
            DocumentType := '01'
        else if IsCreditMemo then
            DocumentType := '02'
        else
            exit(false);

        // Find the submission log first
        eInvoiceSubmissionLog.SetRange("Invoice No.", DocumentNo);
        eInvoiceSubmissionLog.SetRange("Document Type", DocumentType);
        eInvoiceSubmissionLog.SetRange(Status, 'Valid');

        if not eInvoiceSubmissionLog.FindLast() then
            exit(false);

        // Try to perform cancellation with transaction isolation
        exit(TryPerformCancellationWithTransaction(DocumentNo, CancellationReason, eInvoiceSubmissionLog));
    end;

    /// <summary>
    /// Cancel credit memo in LHDN system via API - mirrors the invoice cancellation logic
    /// </summary>
    local procedure CancelCreditMemoInLHDN(SalesCrMemoHeader: Record "Sales Cr.Memo Header"; CancellationReason: Text): Boolean
    var
        HttpClient: HttpClient;
        HttpRequestMessage: HttpRequestMessage;
        HttpResponseMessage: HttpResponseMessage;
        RequestHeaders: HttpHeaders;
        ContentHeaders: HttpHeaders;
        eInvoiceSetup: Record "eInvoiceSetup";
        eInvoiceHelper: Codeunit eInvoiceHelper;
        AccessToken: Text;
        ApiUrl: Text;
        RequestText: Text;
        ResponseText: Text;
        JsonObj: JsonObject;
        JsonResponse: JsonObject;
        JsonToken: JsonToken;
        TelemetryDimensions: Dictionary of [Text, Text];
        CompanyInfo: Record "Company Information";
        DocumentUUID: Text;
        SubmissionUID: Text;
        eInvoiceSubmissionLog: Record "eInvoice Submission Log";
        CorrelationId: Text;
    begin
        // Only process for JOTEX SDN BHD
        if not CompanyInfo.Get() or (CompanyInfo.Name <> 'JOTEX SDN BHD') then
            exit(false);

        // Get setup for environment determination
        if not eInvoiceSetup.Get('SETUP') then begin
            Message('eInvoice Setup not found');
            exit(false);
        end;

        // Find the submission log for this credit memo to get Document UUID and Submission UID
        eInvoiceSubmissionLog.SetRange("Invoice No.", SalesCrMemoHeader."No.");
        eInvoiceSubmissionLog.SetRange("Document Type", '02'); // Credit Memo
        eInvoiceSubmissionLog.SetRange(Status, 'Valid');
        if not eInvoiceSubmissionLog.FindLast() then begin
            Message('No valid e-Invoice submission found for credit memo %1. Only valid/accepted credit memos can be cancelled.', SalesCrMemoHeader."No.");
            exit(false);
        end;

        DocumentUUID := eInvoiceSubmissionLog."Document UUID";
        SubmissionUID := eInvoiceSubmissionLog."Submission UID";

        if (DocumentUUID = '') or (SubmissionUID = '') then begin
            Message('Document UUID or Submission UID is missing for credit memo %1. Cannot proceed with cancellation.', SalesCrMemoHeader."No.");
            exit(false);
        end;

        // Get access token using the helper method (same as all other LHDN API calls)
        eInvoiceHelper.InitializeHelper();
        AccessToken := eInvoiceHelper.GetAccessTokenFromSetup(eInvoiceSetup);
        if AccessToken = '' then begin
            Message('Failed to get access token for credit memo cancellation');
            exit(false);
        end;

        // Build API URL for cancellation (same environment pattern as invoice cancellation)
        if eInvoiceSetup.Environment = eInvoiceSetup.Environment::Preprod then
            ApiUrl := StrSubstNo('https://preprod-api.myinvois.hasil.gov.my/api/v1.0/documents/state/%1/state', DocumentUUID)
        else
            ApiUrl := StrSubstNo('https://api.myinvois.hasil.gov.my/api/v1.0/documents/state/%1/state', DocumentUUID);

        // Generate correlation ID for tracking
        CorrelationId := CreateGuid();

        // Build request payload for cancellation according to LHDN API spec
        JsonObj.Add('status', 'cancelled');
        JsonObj.Add('reason', CancellationReason);
        JsonObj.WriteTo(RequestText);

        // Setup LHDN API request with exact same headers as invoice cancellation
        HttpRequestMessage.Method('PUT');
        HttpRequestMessage.SetRequestUri(ApiUrl);
        HttpRequestMessage.Content().WriteFrom(RequestText);

        // Set standard LHDN API headers
        HttpRequestMessage.Content().GetHeaders(ContentHeaders);
        ContentHeaders.Clear();
        ContentHeaders.Add('Content-Type', 'application/json');

        HttpRequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Clear();
        RequestHeaders.Add('Accept', 'application/json');
        RequestHeaders.Add('Accept-Language', 'en');
        RequestHeaders.Add('Authorization', 'Bearer ' + AccessToken);
        RequestHeaders.Add('User-Agent', 'BusinessCentral-eInvoice/2.0');
        RequestHeaders.Add('X-Correlation-ID', CorrelationId);
        RequestHeaders.Add('X-Request-Source', 'BusinessCentral-CreditMemo-Cancellation');

        // Apply rate limiting
        eInvoiceHelper.ApplyRateLimiting(ApiUrl);

        // Send cancellation request to LHDN
        if HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then begin
            HttpResponseMessage.Content().ReadAs(ResponseText);

            if HttpResponseMessage.IsSuccessStatusCode then begin
                // Parse response and update submission log
                if JsonResponse.ReadFrom(ResponseText) then begin
                    // Update submission log with cancellation details
                    eInvoiceSubmissionLog.Status := 'Cancelled';
                    eInvoiceSubmissionLog."Cancellation Reason" := CopyStr(CancellationReason, 1, MaxStrLen(eInvoiceSubmissionLog."Cancellation Reason"));
                    eInvoiceSubmissionLog."Cancellation Date" := CurrentDateTime;
                    eInvoiceSubmissionLog."Last Updated" := CurrentDateTime;
                    eInvoiceSubmissionLog."Error Message" := 'Successfully cancelled in LHDN system';
                    eInvoiceSubmissionLog.Modify(true);

                    // Log successful cancellation
                    TelemetryDimensions.Add('CreditMemoNo', SalesCrMemoHeader."No.");
                    TelemetryDimensions.Add('DocumentUUID', DocumentUUID);
                    Session.LogMessage('0000EIV08', 'Credit memo successfully cancelled in LHDN',
                        Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                        TelemetryDimensions);

                    exit(true);
                end;
            end else begin
                // Log the error response
                TelemetryDimensions.Add('CreditMemoNo', SalesCrMemoHeader."No.");
                TelemetryDimensions.Add('StatusCode', Format(HttpResponseMessage.HttpStatusCode));
                TelemetryDimensions.Add('Response', CopyStr(ResponseText, 1, 250));
                Session.LogMessage('0000EIV09', 'Credit memo cancellation failed in LHDN',
                    Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                    TelemetryDimensions);

                Message('LHDN API returned error for credit memo cancellation: %1', ResponseText);
            end;
        end else begin
            Message('Failed to connect to LHDN API for credit memo cancellation');
        end;

        exit(false);
    end;

    [TryFunction]
    local procedure TryPerformCancellationWithTransaction(DocumentNo: Code[20]; CancellationReason: Text; var eInvoiceSubmissionLog: Record "eInvoice Submission Log")
    begin
        // Perform the actual cancellation in an isolated transaction
        if CancelDocument(DocumentNo, CancellationReason) then begin
            // Commit will be handled by the calling procedure if needed
        end else
            Error('Cancellation failed');
    end;
}
