pageextension 50306 eInvPostedSalesInvoiceExt extends "Posted Sales Invoice"
{
    layout
    {
        addafter("Invoice Details")
        {
            group("e-Invoice")
            {
                Visible = IsJotexCompany;
                field("eInvoice Document Type"; Rec."eInvoice Document Type")
                {
                    ApplicationArea = Suite;
                    ToolTip = 'Specifies the e-Invoice document type code';
                    Visible = IsJotexCompany;

                    trigger OnValidate()
                    var
                        Customer: Record Customer;
                        CustomerEInvoiceExt: Record "Customer";
                    begin
                        if not IsJotexCompany then
                            exit;

                        if Customer.Get(Rec."Sell-to Customer No.") then begin
                            // Safe way to check for the field
                            if CustomerEInvoiceExt.Get(Customer."No.") then
                                if (Rec."eInvoice Document Type" = '') and CustomerEInvoiceExt."Requires e-Invoice" then
                                    Error('e-Invoice Document Type must be specified for this customer.');
                        end;
                    end;
                }
                field("eInvoice Payment Mode"; Rec."eInvoice Payment Mode")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Payment Mode';
                    Visible = IsJotexCompany;
                }
                field("eInvoice Currency Code"; Rec."eInvoice Currency Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Currency Code';
                    Visible = IsJotexCompany;
                }
                field("eInvoice Version Code"; Rec."eInvoice Version Code")
                {
                    ApplicationArea = Suite;
                    ToolTip = 'Specifies version code for e-Invoice reporting';
                    Visible = IsJotexCompany;
                }
                field("eInvoice Submission UID"; Rec."eInvoice Submission UID")
                {
                    ApplicationArea = All;
                    Caption = 'e-Invoice Submission UID';
                    ToolTip = 'Stores the LHDN submission ID returned after successful submission.';
                    Visible = IsJotexCompany;
                    Editable = false; // Read-only - populated by LHDN API response
                }
                field("eInvoice UUID"; Rec."eInvoice UUID")
                {
                    ApplicationArea = All;
                    Caption = 'e-Invoice UUID';
                    ToolTip = 'Stores the document UUID assigned by LHDN MyInvois.';
                    Visible = IsJotexCompany;
                    Editable = false; // Read-only - populated by LHDN API response
                }
                field("eInvoice Validation Status"; Rec."eInvoice Validation Status")
                {
                    ApplicationArea = All;
                    Caption = 'e-Invoice Validation Status';
                    ToolTip = 'Shows the validation status returned by LHDN (Submitted/Submission Failed for initial submission, or valid/invalid/in progress/partially valid for processing status). This field is automatically updated when checking status via LHDN API.';
                    Visible = IsJotexCompany;
                    Editable = false; // Read-only - only updated from LHDN API
                }
            }
        }


    }

    actions
    {
        addlast(Processing)
        {
            action(GenerateEInvoiceJSON)
            {
                ApplicationArea = All;
                Caption = 'Generate e-Invoice JSON';
                Image = ExportFile;
                ToolTip = 'Generate e-Invoice in JSON format';
                Visible = IsJotexCompany;

                trigger OnAction()
                var
                    eInvoiceGenerator: Codeunit "eInvoice JSON Generator";
                    TempBlob: Codeunit "Temp Blob";
                    FileName: Text;
                    JsonText: Text;
                    OutStream: OutStream;
                    InStream: InStream;
                begin
                    JsonText := eInvoiceGenerator.GenerateEInvoiceJson(Rec, false);

                    // Create download file
                    FileName := StrSubstNo('eInvoice_%1_%2.json',
                        Rec."No.",
                        Format(CurrentDateTime, 0, '<Year4><Month,2><Day,2><Hours24,2><Minutes,2><Seconds,2>'));

                    // Create the file content
                    TempBlob.CreateOutStream(OutStream);
                    OutStream.WriteText(JsonText);

                    // Prepare for download
                    TempBlob.CreateInStream(InStream);
                    DownloadFromStream(InStream, 'Download e-Invoice', '', 'JSON files (*.json)|*.json', FileName);
                end;
            }

            action(SignAndSubmitToLHDN)
            {
                ApplicationArea = All;
                Caption = 'Sign & Submit to LHDN';
                Image = ElectronicDoc;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Sign the invoice via Azure Function and submit directly to LHDN MyInvois API';
                Visible = IsJotexCompany;

                trigger OnAction()
                var
                    eInvoiceGenerator: Codeunit "eInvoice JSON Generator";
                    LhdnResponse: Text;
                    Success: Boolean;
                    SuccessMsg: Text;
                begin
                    // Direct submission without confirmation
                    Success := eInvoiceGenerator.GetSignedInvoiceAndSubmitToLHDN(Rec, LhdnResponse);

                    if Success then begin
                        SuccessMsg := StrSubstNo('Invoice %1 successfully signed and submitted to LHDN!' + '\\' + '\\' + 'LHDN Response:' + '\\' + '%2', Rec."No.", FormatLhdnResponse(LhdnResponse));
                        Message(SuccessMsg);
                    end else begin
                        Message(StrSubstNo('Failed to complete signing and submission process.' + '\\' + 'Response: %1', LhdnResponse));
                    end;
                end;
            }

            action(CheckStatusDirect)
            {
                ApplicationArea = All;
                Caption = 'Check Status (Direct API)';
                Image = Refresh;
                ToolTip = 'Test direct API call to LHDN submission status (same method as Get Document Types)';
                Visible = IsJotexCompany;

                trigger OnAction()
                var
                    HttpClient: HttpClient;
                    HttpRequestMessage: HttpRequestMessage;
                    HttpResponseMessage: HttpResponseMessage;
                    RequestHeaders: HttpHeaders;
                    AccessToken: Text;
                    eInvoiceSetup: Record "eInvoiceSetup";
                    eInvoiceHelper: Codeunit eInvoiceHelper;
                    ApiUrl: Text;
                    ResponseText: Text;
                begin
                    if Rec."eInvoice Submission UID" = '' then begin
                        Message('No submission UID found for this invoice.' + '\\' + 'Please submit the invoice to LHDN first.');
                        exit;
                    end;

                    // Get setup for environment determination
                    if not eInvoiceSetup.Get('SETUP') then begin
                        Message('eInvoice Setup not found');
                        exit;
                    end;

                    // Get access token using the helper method
                    eInvoiceHelper.InitializeHelper();
                    AccessToken := eInvoiceHelper.GetAccessTokenFromSetup(eInvoiceSetup);
                    if AccessToken = '' then begin
                        Message('Failed to get access token');
                        exit;
                    end;

                    // Build API URL same as in the codeunit
                    if eInvoiceSetup.Environment = eInvoiceSetup.Environment::Preprod then
                        ApiUrl := StrSubstNo('https://preprod-api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions/%1', Rec."eInvoice Submission UID")
                    else
                        ApiUrl := StrSubstNo('https://api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions/%1', Rec."eInvoice Submission UID");

                    // Setup request (same as Document Types API)
                    HttpRequestMessage.Method := 'GET';
                    HttpRequestMessage.SetRequestUri(ApiUrl);

                    // Set headers (same as Document Types API)
                    HttpRequestMessage.GetHeaders(RequestHeaders);
                    RequestHeaders.Clear();
                    RequestHeaders.Add('Accept', 'application/json');
                    RequestHeaders.Add('Accept-Language', 'en');
                    RequestHeaders.Add('Authorization', 'Bearer ' + AccessToken);

                    // Send request (same method as Document Types API)
                    if HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then begin
                        HttpResponseMessage.Content.ReadAs(ResponseText);

                        if HttpResponseMessage.IsSuccessStatusCode then begin
                            // Parse the JSON response to extract the status
                            if UpdateInvoiceStatusFromResponse(ResponseText) then begin
                                // Try to update the posted invoice field using the codeunit with proper permissions
                                TryUpdateStatusViaCodeunit(ExtractStatusFromApiResponse(ResponseText));

                                Message('Status updated successfully from LHDN.');
                            end else begin
                                Message('Status check completed, but unable to parse response.');
                            end;
                        end else begin
                            Message('Failed to retrieve status from LHDN API (Status Code: %1)',
                                   HttpResponseMessage.HttpStatusCode);
                        end;
                    end else begin
                        Message('Failed to connect to LHDN API.');
                    end;
                end;
            }

            action(ViewSubmissionLog)
            {
                ApplicationArea = All;
                Caption = 'View Submission Log';
                Image = Log;
                ToolTip = 'View submission log entries for this invoice (alternative status tracking)';
                Visible = IsJotexCompany;

                trigger OnAction()
                var
                    SubmissionLog: Record "eInvoice Submission Log";
                    SubmissionLogPage: Page "e-Invoice Submission Log";
                begin
                    // Filter to show only entries for this invoice
                    SubmissionLog.SetRange("Invoice No.", Rec."No.");
                    if Rec."eInvoice Submission UID" <> '' then
                        SubmissionLog.SetRange("Submission UID", Rec."eInvoice Submission UID");

                    SubmissionLogPage.SetTableView(SubmissionLog);
                    SubmissionLogPage.RunModal();
                end;
            }

            action(CancelEInvoice)
            {
                ApplicationArea = All;
                Caption = 'Cancel e-Invoice';
                Image = Cancel;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Cancel this e-Invoice in the LHDN MyInvois system';
                Visible = IsJotexCompany;

                trigger OnAction()
                var
                    eInvPostingSubscribers: Codeunit "eInv Posting Subscribers";
                    CancellationReason: Text;
                    SubmissionLog: Record "eInvoice Submission Log";
                    ConfirmMsg: Label 'Are you sure you want to cancel e-Invoice %1 in the LHDN system?\This action cannot be undone.';
                    ReasonPrompt: Label 'Please enter the reason for cancellation:';
                begin
                    // Verify that the invoice has been submitted and is valid
                    SubmissionLog.SetRange("Invoice No.", Rec."No.");
                    SubmissionLog.SetRange(Status, 'Valid');
                    if not SubmissionLog.FindLast() then begin
                        Message('This invoice has not been submitted to LHDN or is not in a valid state.\Only valid/accepted e-Invoices can be cancelled.');
                        exit;
                    end;

                    // Check if already cancelled
                    if SubmissionLog.Status = 'Cancelled' then begin
                        Message('This e-Invoice has already been cancelled.\Reason: %1\Cancelled on: %2',
                                SubmissionLog."Cancellation Reason",
                                Format(SubmissionLog."Cancellation Date"));
                        exit;
                    end;

                    // Confirm cancellation
                    if not Confirm(ConfirmMsg, false, Rec."No.") then
                        exit;

                    // Get cancellation reason
                    CancellationReason := SelectCancellationReason();
                    if CancellationReason = '' then
                        exit;

                    // Proceed with cancellation
                    ClearLastError();
                    if eInvPostingSubscribers.CancelEInvoiceDocument(Rec, CancellationReason) then begin
                        // Refresh the page to show updated status
                        CurrPage.Update(false);
                    end else begin
                        // Try alternative method with transaction isolation
                        ClearLastError();
                        if eInvPostingSubscribers.CancelEInvoiceDocumentWithIsolation(Rec, CancellationReason) then begin
                            Message('Cancellation completed using alternative method. Please refresh the submission log.');
                            CurrPage.Update(false);
                        end else begin
                            // Show any error that occurred
                            if GetLastErrorText() <> '' then
                                Message('Cancellation failed with error:\%1', GetLastErrorText())
                            else
                                Message('Cancellation operation failed. Please check the submission log for details.');
                        end;
                    end;
                end;
            }
        }
    }

    var
        IsJotexCompany: Boolean;

    trigger OnOpenPage()
    var
        CompanyInfo: Record "Company Information";
    begin
        IsJotexCompany := CompanyInfo.Get() and (CompanyInfo.Name = 'JOTEX SDN BHD');
    end;

    /// <summary>
    /// Formats LHDN response JSON into a clean, readable format
    /// </summary>
    /// <param name="RawResponse">Raw JSON response from LHDN</param>
    /// <returns>Formatted response text</returns>
    local procedure FormatLhdnResponse(RawResponse: Text): Text
    var
        ResponseJson: JsonObject;
        JsonToken: JsonToken;
        AcceptedArray: JsonArray;
        RejectedArray: JsonArray;
        SubmissionUid: Text;
        AcceptedCount: Integer;
        RejectedCount: Integer;
        i: Integer;
        DocumentJson: JsonObject;
        Uuid: Text;
        InvoiceCodeNumber: Text;
        FormattedResponse: Text;
    begin
        // Try to parse the JSON response
        if not ResponseJson.ReadFrom(RawResponse) then begin
            // If parsing fails, return a simplified version of the raw response
            exit('Raw Response: ' + CopyStr(RawResponse, 1, 200) + '...');
        end;

        // Extract submission UID
        if ResponseJson.Get('submissionUid', JsonToken) then
            SubmissionUid := CleanQuotesFromText(SafeJsonValueToText(JsonToken));

        // Extract accepted documents
        if ResponseJson.Get('acceptedDocuments', JsonToken) and JsonToken.IsArray() then begin
            AcceptedArray := JsonToken.AsArray();
            AcceptedCount := AcceptedArray.Count();

            if AcceptedCount > 0 then begin
                FormattedResponse := 'Submission ID: ' + SubmissionUid + '\\' +
                                   'Accepted Documents: ' + Format(AcceptedCount) + '\\';

                for i := 0 to AcceptedCount - 1 do begin
                    AcceptedArray.Get(i, JsonToken);
                    if JsonToken.IsObject() then begin
                        DocumentJson := JsonToken.AsObject();

                        if DocumentJson.Get('uuid', JsonToken) then
                            Uuid := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                        if DocumentJson.Get('invoiceCodeNumber', JsonToken) then
                            InvoiceCodeNumber := CleanQuotesFromText(SafeJsonValueToText(JsonToken));

                        FormattedResponse += StrSubstNo('• Invoice: %1\\    UUID: %2', InvoiceCodeNumber, Uuid);
                        if i < AcceptedCount - 1 then
                            FormattedResponse += '\\';
                    end;
                end;
            end;
        end;

        // Extract rejected documents
        if ResponseJson.Get('rejectedDocuments', JsonToken) and JsonToken.IsArray() then begin
            RejectedArray := JsonToken.AsArray();
            RejectedCount := RejectedArray.Count();

            if RejectedCount > 0 then begin
                if FormattedResponse <> '' then
                    FormattedResponse += '\\';
                FormattedResponse += 'Rejected Documents: ' + Format(RejectedCount);
            end;
        end;

        // If no structured data found, return simplified raw response
        if FormattedResponse = '' then begin
            FormattedResponse := 'Raw Response: ' + CopyStr(RawResponse, 1, 200) + '...';
        end;

        exit(FormattedResponse);
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
    /// Extract status from LHDN API response for display purposes
    /// </summary>
    /// <param name="ResponseText">JSON response from LHDN API</param>
    /// <returns>The formatted status value</returns>
    local procedure ExtractStatusFromApiResponse(ResponseText: Text): Text
    var
        JsonObject: JsonObject;
        JsonToken: JsonToken;
        OverallStatus: Text;
    begin
        // Parse the JSON response
        if not JsonObject.ReadFrom(ResponseText) then
            exit('Unknown - JSON Parse Failed');

        // Extract the overallStatus field
        if not JsonObject.Get('overallStatus', JsonToken) then
            exit('Unknown - No Status Field');

        OverallStatus := JsonToken.AsValue().AsText();

        // Convert LHDN status values to proper case for display
        case OverallStatus.ToLower() of
            'valid':
                exit('Valid');
            'invalid':
                exit('Invalid');
            'in progress':
                exit('In Progress');
            'partially valid':
                exit('Partially Valid');
            else
                exit(OverallStatus); // Use as-is if unknown
        end;
    end;

    /// <summary>
    /// Parse JSON response and update the invoice validation status field
    /// Uses TryFunction approach to handle permission restrictions gracefully
    /// </summary>
    /// <param name="ResponseText">JSON response from LHDN API</param>
    /// <returns>True if status was successfully updated or permission denied</returns>
    local procedure UpdateInvoiceStatusFromResponse(ResponseText: Text): Boolean
    var
        JsonObject: JsonObject;
        JsonToken: JsonToken;
        OverallStatus: Text;
        LhdnStatus: Text;
        UpdateSuccess: Boolean;
    begin
        // Parse the JSON response
        if not JsonObject.ReadFrom(ResponseText) then
            exit(false);

        // Extract the overallStatus field
        if not JsonObject.Get('overallStatus', JsonToken) then
            exit(false);

        OverallStatus := JsonToken.AsValue().AsText();

        // Convert LHDN status values to proper case for display
        case OverallStatus.ToLower() of
            'valid':
                LhdnStatus := 'Valid';
            'invalid':
                LhdnStatus := 'Invalid';
            'in progress':
                LhdnStatus := 'In Progress';
            'partially valid':
                LhdnStatus := 'Partially Valid';
            else
                LhdnStatus := OverallStatus; // Use as-is if unknown
        end;

        // Try to update the invoice validation status field with permission handling
        UpdateSuccess := TryUpdateInvoiceStatus(LhdnStatus);

        // Always try to update the submission log (which we should have permissions for)
        UpdateSubmissionLogStatus(LhdnStatus);

        if UpdateSuccess then begin
            // Refresh the page to show the updated status
            CurrPage.Update(false);
        end;

        // Return true even if update failed due to permissions - the status check itself was successful
        exit(true);
    end;

    /// <summary>
    /// Update the submission log with the latest status from LHDN
    /// This provides an alternative storage when we can't modify the posted invoice
    /// </summary>
    /// <param name="NewStatus">The new status retrieved from LHDN</param>
    local procedure UpdateSubmissionLogStatus(NewStatus: Text)
    var
        SubmissionLog: Record "eInvoice Submission Log";
        Customer: Record Customer;
        CustomerName: Text[100];
    begin
        // Get customer name from the invoice
        CustomerName := '';
        if Customer.Get(Rec."Sell-to Customer No.") then
            CustomerName := Customer.Name;

        // Try to find existing log entry for this invoice and submission UID
        SubmissionLog.SetRange("Invoice No.", Rec."No.");
        SubmissionLog.SetRange("Submission UID", Rec."eInvoice Submission UID");

        if SubmissionLog.FindLast() then begin
            // Update existing log entry
            SubmissionLog.Status := NewStatus;
            SubmissionLog."Last Updated" := CurrentDateTime;
            SubmissionLog."Customer Name" := CustomerName;
            SubmissionLog."Error Message" := StrSubstNo('Status updated via API check: %1', NewStatus);
            if SubmissionLog.Modify() then begin
                // Successfully updated log
            end;
        end else begin
            // Create new log entry if none exists
            SubmissionLog.Init();
            SubmissionLog."Invoice No." := Rec."No.";
            SubmissionLog."Submission UID" := Rec."eInvoice Submission UID";
            SubmissionLog."Document UUID" := Rec."eInvoice UUID";
            SubmissionLog.Status := NewStatus;
            SubmissionLog."Customer Name" := CustomerName;
            SubmissionLog."Submission Date" := CurrentDateTime;
            SubmissionLog."Last Updated" := CurrentDateTime;
            SubmissionLog."Error Message" := StrSubstNo('Status retrieved via API check: %1', NewStatus);
            if SubmissionLog.Insert() then begin
                // Successfully created log entry
            end;
        end;
    end;

    /// <summary>
    /// Try to update invoice status using the JSON Generator codeunit which has modify permissions
    /// This bypasses the permission restrictions on the page extension
    /// </summary>
    /// <param name="NewStatus">The new status to set</param>
    local procedure TryUpdateStatusViaCodeunit(NewStatus: Text)
    var
        eInvoiceGenerator: Codeunit "eInvoice JSON Generator";
    begin
        // Use the JSON Generator codeunit which has tabledata "Sales Invoice Header" = M permission
        if eInvoiceGenerator.UpdateInvoiceValidationStatus(Rec."No.", NewStatus) then begin
            // Refresh the current record to show updated status
            Rec.Get(Rec."No.");
            CurrPage.Update(false);
        end;
    end;

    /// <summary>
    /// Try to update invoice status with proper error handling for permission restrictions
    /// </summary>
    /// <param name="NewStatus">The new status to set</param>
    /// <returns>True if successfully updated, false if permission denied</returns>
    [TryFunction]
    local procedure TryUpdateInvoiceStatus(NewStatus: Text)
    begin
        // Attempt to update the status field
        Rec."eInvoice Validation Status" := NewStatus;

        // Try to save the changes - will fail gracefully if no modify permissions
        Rec.Modify();
    end;

    /// <summary>
    /// Try to call LHDN API with proper error handling for context restrictions
    /// </summary>
    [TryFunction]
    local procedure TryCallLhdnApi(var SubmissionStatusCU: Codeunit "eInvoice Submission Status"; SubmissionUID: Text; var SubmissionDetails: Text)
    begin
        SubmissionStatusCU.CheckSubmissionStatus(SubmissionUID, SubmissionDetails);
    end;

    /// <summary>
    /// Shows a dialog to select cancellation reason
    /// </summary>
    /// <returns>Selected cancellation reason or empty string if cancelled</returns>
    local procedure SelectCancellationReason(): Text
    var
        ReasonOptions: Dialog;
        Selection: Integer;
        CustomReason: Text;
        ReasonText: Text;
    begin
        ReasonText := '';

        // Show options dialog
        Selection := Dialog.StrMenu('Wrong buyer,Wrong invoice details,Duplicate invoice,Technical error,Buyer cancellation request,Other business reason', 1, 'Select cancellation reason:');

        case Selection of
            1:
                ReasonText := 'Wrong buyer information';
            2:
                ReasonText := 'Incorrect invoice details';
            3:
                ReasonText := 'Duplicate invoice submission';
            4:
                ReasonText := 'Technical error during submission';
            5:
                ReasonText := 'Cancellation requested by buyer';
            6:
                begin
                    // For custom reason, we'll use a predefined text since we can't easily prompt for input
                    ReasonText := 'Other business reason - Contact support for details';
                end;
            else
                ReasonText := '';
        end;

        exit(ReasonText);
    end;
}