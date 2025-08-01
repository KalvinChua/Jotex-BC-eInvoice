codeunit 50305 "eInv Posting Subscribers"
{
    Permissions = tabledata "Sales Invoice Header" = M,
                  tabledata "eInvoice Submission Log" = M;

    // Event to copy header fields after posting is complete AND auto-submit to LHDN
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnAfterPostSalesDoc', '', false, false)]
    local procedure CopyEInvoiceHeaderFieldsAndAutoSubmit(
        var SalesHeader: Record "Sales Header";
        var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line";
        SalesShptHdrNo: Code[20];
        RetRcpHdrNo: Code[20];
        SalesInvHdrNo: Code[20];
        SalesCrMemoHdrNo: Code[20])
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        Customer: Record Customer;
        eInvoiceJSONGenerator: Codeunit "eInvoice JSON Generator";
        TelemetryDimensions: Dictionary of [Text, Text];
        CompanyInfo: Record "Company Information";
        LhdnResponse: Text;
        CustomerRequiresEInvoice: Boolean;
    begin
        // Only process for JOTEX SDN BHD
        if not CompanyInfo.Get() or (CompanyInfo.Name <> 'JOTEX SDN BHD') then
            exit;

        // Only process invoices (skip credit memos and other documents)
        if SalesInvHdrNo = '' then
            exit;

        // Find the posted invoice and update fields
        if SalesInvoiceHeader.Get(SalesInvHdrNo) then begin
            SalesInvoiceHeader."eInvoice Document Type" := SalesHeader."eInvoice Document Type";
            SalesInvoiceHeader."eInvoice Payment Mode" := SalesHeader."eInvoice Payment Mode";
            SalesInvoiceHeader."eInvoice Currency Code" := SalesHeader."eInvoice Currency Code";
            SalesInvoiceHeader."eInvoice Version Code" := SalesHeader."eInvoice Version Code";

            // Force the modification and commit immediately
            if not SalesInvoiceHeader.Modify(true) then begin
                TelemetryDimensions.Add('DocumentNo', SalesInvHdrNo);
                Session.LogMessage('0000EIV', 'Failed to update e-Invoice fields for posted invoice',
                    Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                    TelemetryDimensions);
            end;

            Commit();

            // Check if customer requires e-Invoice for auto-submission
            CustomerRequiresEInvoice := Customer.Get(SalesInvoiceHeader."Sell-to Customer No.") and Customer."Requires e-Invoice";

            // Auto-submit to LHDN if customer requires e-Invoice
            if CustomerRequiresEInvoice then begin
                // Wait a moment to ensure all data is committed
                Sleep(2000);

                // Attempt automatic submission to LHDN
                Message('Starting automatic e-Invoice submission for invoice %1...', SalesInvHdrNo);

                if eInvoiceJSONGenerator.GetSignedInvoiceAndSubmitToLHDN(SalesInvoiceHeader, LhdnResponse) then begin
                    // Success - log the successful submission
                    Clear(TelemetryDimensions);
                    TelemetryDimensions.Add('InvoiceNo', SalesInvHdrNo);
                    TelemetryDimensions.Add('CustomerNo', SalesInvoiceHeader."Sell-to Customer No.");
                    Session.LogMessage('0000EIV01', 'Automatic e-Invoice submission successful',
                        Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                        TelemetryDimensions);

                    Message('Invoice %1 has been successfully posted and submitted to LHDN e-Invoice system.', SalesInvHdrNo);
                end else begin
                    // Failure - log the error but don't stop the posting process
                    Clear(TelemetryDimensions);
                    TelemetryDimensions.Add('InvoiceNo', SalesInvHdrNo);
                    TelemetryDimensions.Add('Error', CopyStr(LhdnResponse, 1, 250));
                    Session.LogMessage('0000EIV02', 'Automatic e-Invoice submission failed',
                        Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                        TelemetryDimensions);

                    Message('Invoice %1 has been posted successfully.' +
                            'However, automatic e-Invoice submission failed: %2' +
                            'You can manually submit it from the Posted Sales Invoice page.',
                            SalesInvHdrNo, CopyStr(LhdnResponse, 1, 200));
                end;
            end else begin
                // Customer doesn't require e-Invoice - just show normal posting message
                Message('Invoice %1 has been posted successfully. Customer does not require automatic e-Invoice submission.', SalesInvHdrNo);
            end;
        end;
    end;

    // Event to copy line fields during line insertion
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnBeforeSalesInvLineInsert', '', false, false)]
    local procedure CopyEInvoiceLineFields(
        var SalesInvLine: Record "Sales Invoice Line";
        SalesLine: Record "Sales Line";
        SalesInvHeader: Record "Sales Invoice Header";
        CommitIsSuppressed: Boolean)
    var
        CompanyInfo: Record "Company Information";
    begin
        // Only process for JOTEX SDN BHD
        if not CompanyInfo.Get() or (CompanyInfo.Name <> 'JOTEX SDN BHD') then
            exit;

        // Only copy fields for item and resource lines
        if SalesLine.Type in [SalesLine.Type::Item, SalesLine.Type::Resource] then begin
            SalesInvLine."e-Invoice Classification" := SalesLine."e-Invoice Classification";
            SalesInvLine."e-Invoice UOM" := SalesLine."e-Invoice UOM";
            SalesInvLine."e-Invoice Tax Type" := SalesLine."e-Invoice Tax Type";
        end;
    end;

    // Event to verify fields before posting
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnBeforePostSalesDoc', '', false, false)]
    local procedure VerifyEInvoiceFieldsBeforePosting(
        var SalesHeader: Record "Sales Header";
        var HideProgressWindow: Boolean;
        var IsHandled: Boolean)
    var
        Customer: Record Customer;
        SalesLine: Record "Sales Line";
        MissingFieldsErr: Label 'Missing e-Invoice fields for %1:\%2', Comment = '%1=Document No.,%2=Missing fields';
        MissingFields: Text;
        CompanyInfo: Record "Company Information";
    begin
        // Only process for JOTEX SDN BHD
        if not CompanyInfo.Get() or (CompanyInfo.Name <> 'JOTEX SDN BHD') then
            exit;

        if IsHandled then
            exit;

        // Check customer requirements
        if Customer.Get(SalesHeader."Sell-to Customer No.") and Customer."Requires e-Invoice" then begin
            if SalesHeader."eInvoice Document Type" = '' then
                MissingFields := MissingFields + '\- Document Type';

            if SalesHeader."eInvoice Currency Code" = '' then
                MissingFields := MissingFields + '\- Currency Code';
        end;

        // Check lines
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetFilter(Type, '<>%1', SalesLine.Type::" ");
        if SalesLine.FindSet() then
            repeat
                if SalesLine."e-Invoice Classification" = '' then
                    MissingFields := MissingFields + '\- Line ' + Format(SalesLine."Line No.") + ' Classification';

                if SalesLine."e-Invoice UOM" = '' then
                    MissingFields := MissingFields + '\- Line ' + Format(SalesLine."Line No.") + ' UOM';

                if SalesLine."e-Invoice Tax Type" = '' then
                    MissingFields := MissingFields + '\- Line ' + Format(SalesLine."Line No.") + ' Tax Type';
            until SalesLine.Next() = 0;

        if MissingFields <> '' then
            Error(MissingFieldsErr, SalesHeader."No.", MissingFields);
    end;

    // Procedure to cancel a submitted e-Invoice document in LHDN
    procedure CancelEInvoiceDocument(SalesInvoiceHeader: Record "Sales Invoice Header"; CancellationReason: Text) Success: Boolean
    var
        HttpClient: HttpClient;
        HttpRequestMessage: HttpRequestMessage;
        HttpResponseMessage: HttpResponseMessage;
        RequestContent: HttpContent;
        RequestHeaders: HttpHeaders;
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
    begin
        Success := false;

        // Only process for JOTEX SDN BHD
        if not CompanyInfo.Get() or (CompanyInfo.Name <> 'JOTEX SDN BHD') then
            exit;

        // Get setup for environment determination
        if not eInvoiceSetup.Get('SETUP') then begin
            Message('eInvoice Setup not found');
            exit;
        end;

        // Find the submission log for this invoice to get Document UUID and Submission UID
        eInvoiceSubmissionLog.SetRange("Invoice No.", SalesInvoiceHeader."No.");
        eInvoiceSubmissionLog.SetRange(Status, 'Valid');
        if not eInvoiceSubmissionLog.FindLast() then begin
            Message('No valid e-Invoice submission found for invoice %1. Only valid/accepted invoices can be cancelled.', SalesInvoiceHeader."No.");
            exit;
        end;

        DocumentUUID := eInvoiceSubmissionLog."Document UUID";
        SubmissionUID := eInvoiceSubmissionLog."Submission UID";

        if (DocumentUUID = '') or (SubmissionUID = '') then begin
            Message('Document UUID or Submission UID is missing for invoice %1. Cannot proceed with cancellation.', SalesInvoiceHeader."No.");
            exit;
        end;

        // Get access token using the helper method
        eInvoiceHelper.InitializeHelper();
        AccessToken := eInvoiceHelper.GetAccessTokenFromSetup(eInvoiceSetup);
        if AccessToken = '' then begin
            Message('Failed to get access token for cancellation');
            exit;
        end;

        // Build API URL for cancellation
        if eInvoiceSetup.Environment = eInvoiceSetup.Environment::Preprod then
            ApiUrl := StrSubstNo('https://preprod-api.myinvois.hasil.gov.my/api/v1.0/documents/state/%1/state', DocumentUUID)
        else
            ApiUrl := StrSubstNo('https://api.myinvois.hasil.gov.my/api/v1.0/documents/state/%1/state', DocumentUUID);

        // Build request payload for cancellation according to LHDN API spec
        JsonObj.Add('status', 'cancelled');
        JsonObj.Add('reason', CancellationReason);
        JsonObj.WriteTo(RequestText);

        // Set up HTTP request
        RequestContent.WriteFrom(RequestText);
        RequestContent.GetHeaders(RequestHeaders);
        RequestHeaders.Clear();
        RequestHeaders.Add('Content-Type', 'application/json');
        RequestHeaders.Add('Authorization', 'Bearer ' + AccessToken);

        HttpRequestMessage.Method := 'PUT';
        HttpRequestMessage.SetRequestUri(ApiUrl);
        HttpRequestMessage.Content := RequestContent;

        // Set timeout
        HttpClient.Timeout(30000); // 30 seconds

        // Send cancellation request
        if HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then begin
            HttpResponseMessage.Content.ReadAs(ResponseText);

            if HttpResponseMessage.IsSuccessStatusCode then begin
                // Parse response to check cancellation status
                if JsonResponse.ReadFrom(ResponseText) then begin
                    // Update submission log with cancellation status using try function for context safety
                    if TryUpdateCancellationStatus(eInvoiceSubmissionLog, CancellationReason) then begin
                        // Log successful cancellation
                        TelemetryDimensions.Add('InvoiceNo', SalesInvoiceHeader."No.");
                        TelemetryDimensions.Add('DocumentUUID', DocumentUUID);
                        TelemetryDimensions.Add('Reason', CancellationReason);
                        Session.LogMessage('0000EIV03', 'e-Invoice document cancellation successful',
                            Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                            TelemetryDimensions);

                        Message('e-Invoice for invoice %1 has been successfully cancelled in LHDN system.\Reason: %2',
                                SalesInvoiceHeader."No.", CancellationReason);
                        Success := true;
                    end else begin
                        // Log database update failure
                        TelemetryDimensions.Add('InvoiceNo', SalesInvoiceHeader."No.");
                        TelemetryDimensions.Add('Error', 'Failed to update submission log after successful LHDN cancellation');
                        Session.LogMessage('0000EIV05', 'e-Invoice cancellation succeeded but log update failed',
                            Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                            TelemetryDimensions);

                        Message('e-Invoice for invoice %1 has been cancelled in LHDN system, but failed to update local log.\Please refresh the submission log manually.',
                                SalesInvoiceHeader."No.");
                        Success := true; // Still considered successful since LHDN accepted the cancellation
                    end;
                end;
            end else begin
                // Log cancellation failure
                TelemetryDimensions.Add('InvoiceNo', SalesInvoiceHeader."No.");
                TelemetryDimensions.Add('DocumentUUID', DocumentUUID);
                TelemetryDimensions.Add('StatusCode', Format(HttpResponseMessage.HttpStatusCode));
                TelemetryDimensions.Add('Error', CopyStr(ResponseText, 1, 250));
                Session.LogMessage('0000EIV04', 'e-Invoice document cancellation failed',
                    Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                    TelemetryDimensions);

                Message('Failed to cancel e-Invoice for invoice %1.\Error: %2',
                        SalesInvoiceHeader."No.", CopyStr(ResponseText, 1, 200));
            end;
        end else begin
            Message('Failed to communicate with LHDN API for cancellation of invoice %1', SalesInvoiceHeader."No.");
        end;
    end;

    /// <summary>
    /// Try to update cancellation status in submission log with proper error handling
    /// </summary>
    [TryFunction]
    local procedure TryUpdateCancellationStatus(var eInvoiceSubmissionLog: Record "eInvoice Submission Log"; CancellationReason: Text)
    begin
        eInvoiceSubmissionLog.Status := 'Cancelled';
        eInvoiceSubmissionLog."Cancellation Reason" := CopyStr(CancellationReason, 1, MaxStrLen(eInvoiceSubmissionLog."Cancellation Reason"));
        eInvoiceSubmissionLog."Cancellation Date" := CurrentDateTime;
        eInvoiceSubmissionLog.Modify(true);
    end;

    /// <summary>
    /// Alternative cancellation method with transaction isolation
    /// </summary>
    procedure CancelEInvoiceDocumentWithIsolation(SalesInvoiceHeader: Record "Sales Invoice Header"; CancellationReason: Text): Boolean
    var
        eInvoiceSubmissionLog: Record "eInvoice Submission Log";
    begin
        // Find the submission log first
        eInvoiceSubmissionLog.SetRange("Invoice No.", SalesInvoiceHeader."No.");
        eInvoiceSubmissionLog.SetRange(Status, 'Valid');
        if not eInvoiceSubmissionLog.FindLast() then
            exit(false);

        // Start isolated transaction for database update
        if TryPerformCancellationWithTransaction(SalesInvoiceHeader, CancellationReason, eInvoiceSubmissionLog) then
            exit(true)
        else
            exit(false);
    end;

    [TryFunction]
    local procedure TryPerformCancellationWithTransaction(SalesInvoiceHeader: Record "Sales Invoice Header"; CancellationReason: Text; var eInvoiceSubmissionLog: Record "eInvoice Submission Log")
    begin
        // Perform the actual cancellation in an isolated transaction
        if CancelEInvoiceDocument(SalesInvoiceHeader, CancellationReason) then begin
            Commit(); // Commit any pending changes
        end else
            Error('Cancellation API call failed');
    end;
}