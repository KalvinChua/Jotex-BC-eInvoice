pageextension 50314 eInvPostedSalesCrMemoExt extends "Posted Sales Credit Memo"
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
                    ToolTip = 'Specifies the LHDN Submission UID';
                    Visible = IsJotexCompany;
                    Editable = false;
                }
                field("eInvoice UUID"; Rec."eInvoice UUID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the LHDN Document UUID';
                    Visible = IsJotexCompany;
                    Editable = false;
                }
                field("eInvoice Validation Status"; Rec."eInvoice Validation Status")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the e-Invoice validation status from LHDN';
                    Visible = IsJotexCompany;
                    Editable = false;
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
                ToolTip = 'Generate e-Invoice in JSON format for credit memo';
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
                    JsonText := eInvoiceGenerator.GenerateCreditMemoEInvoiceJson(Rec, false);

                    // Create download file
                    FileName := StrSubstNo('eInvoice_CreditMemo_%1_%2.json',
                        Rec."No.",
                        Format(CurrentDateTime, 0, '<Year4><Month,2><Day,2><Hours24,2><Minutes,2><Seconds,2>'));

                    // Create the file content
                    TempBlob.CreateOutStream(OutStream);
                    OutStream.WriteText(JsonText);

                    // Prepare for download
                    TempBlob.CreateInStream(InStream);
                    DownloadFromStream(InStream, 'Download e-Invoice Credit Memo', '', 'JSON files (*.json)|*.json', FileName);
                end;
            }

            action(SignAndSubmitToLHDN)
            {
                ApplicationArea = All;
                Caption = 'Sign & Submit to LHDN';
                Image = ElectronicDoc;
                ToolTip = 'Sign and submit credit memo to LHDN MyInvois';
                Visible = IsJotexCompany;

                trigger OnAction()
                var
                    eInvoiceGenerator: Codeunit "eInvoice JSON Generator";
                    LhdnResponse: Text;
                    Success: Boolean;
                    SuccessMsg: Text;
                begin
                    // Direct submission without confirmation - matching sales invoice pattern
                    Success := eInvoiceGenerator.GetSignedCreditMemoAndSubmitToLHDN(Rec, LhdnResponse);

                    if Success then begin
                        SuccessMsg := StrSubstNo('Credit Memo %1 successfully signed and submitted to LHDN!\' +
                            'LHDN Response:\' +
                            '%2', Rec."No.", FormatLhdnResponse(LhdnResponse));
                        Message(SuccessMsg);
                    end else begin
                        Message(StrSubstNo('Failed to complete signing and submission process.\' +
                            'Response: %1', LhdnResponse));
                    end;
                end;
            }

            action(CancelEInvoice)
            {
                ApplicationArea = All;
                Caption = 'Cancel e-Invoice';
                Image = Cancel;
                ToolTip = 'Cancel this e-Invoice submission in LHDN system';
                Visible = IsJotexCompany and (Rec."eInvoice Validation Status" = 'Valid');

                trigger OnAction()
                var
                    eInvoiceCancellationHelper: Codeunit "eInvoice Cancellation Helper";
                    CancellationReason: Text;
                begin
                    if not IsJotexCompany then
                        exit;

                    if Rec."eInvoice Validation Status" <> 'Valid' then begin
                        Message('Can only cancel e-Invoices with Valid status. Current status: %1', Rec."eInvoice Validation Status");
                        exit;
                    end;

                    CancellationReason := '';
                    if not (StrMenu('User Error,Duplicate Entry,Wrong Amount,Other', 1, 'Select cancellation reason:') > 0) then
                        exit;

                    case StrMenu('User Error,Duplicate Entry,Wrong Amount,Other', 1, 'Select cancellation reason:') of
                        1:
                            CancellationReason := 'User Error';
                        2:
                            CancellationReason := 'Duplicate Entry';
                        3:
                            CancellationReason := 'Wrong Amount';
                        4:
                            CancellationReason := 'Other';
                        else
                            exit;
                    end;

                    if eInvoiceCancellationHelper.CancelDocument(Rec."No.", CancellationReason) then
                        CurrPage.Update();
                end;
            }

            action(RefreshStatus)
            {
                ApplicationArea = All;
                Caption = 'Refresh Status';
                Image = Refresh;
                ToolTip = 'Refresh the e-Invoice status from LHDN system';
                Visible = IsJotexCompany and (Rec."eInvoice UUID" <> '');

                trigger OnAction()
                var
                    eInvoiceSubmissionStatus: Codeunit "eInvoice Submission Status";
                    eInvoiceSubmissionLog: Record "eInvoice Submission Log";
                    StatusRefreshed: Boolean;
                begin
                    if not IsJotexCompany then
                        exit;

                    if Rec."eInvoice UUID" = '' then begin
                        Message('No e-Invoice UUID found. Cannot refresh status.');
                        exit;
                    end;

                    // Find the submission log entry for this credit memo
                    eInvoiceSubmissionLog.SetRange("Invoice No.", Rec."No.");
                    eInvoiceSubmissionLog.SetRange("Document Type", '02'); // Credit Memo

                    // DEBUG: Check what entries exist for this credit memo
                    if not eInvoiceSubmissionLog.FindSet() then begin
                        Message('No submission log entries found for Credit Memo %1.\Please check if the credit memo was submitted to LHDN.', Rec."No.");
                        exit;
                    end;

                    // Look for any valid entry (not just 'Valid' status)
                    eInvoiceSubmissionLog.SetRange(Status); // Clear status filter
                    if not eInvoiceSubmissionLog.FindLast() then begin
                        Message('No submission log entry found for Credit Memo %1', Rec."No.");
                        exit;
                    end;

                    // Check if the entry has a valid status for refresh
                    if eInvoiceSubmissionLog.Status in ['Valid', 'Pending', 'Processing'] then begin
                        // Can refresh these statuses
                    end else begin
                        Message('Cannot refresh status for Credit Memo %1.\Current status: %2\Only Valid, Pending, or Processing entries can be refreshed.',
                            Rec."No.", eInvoiceSubmissionLog.Status);
                        exit;
                    end;

                    StatusRefreshed := eInvoiceSubmissionStatus.RefreshSubmissionLogStatus(eInvoiceSubmissionLog);

                    if StatusRefreshed then begin
                        // Update the credit memo header with the refreshed status
                        if eInvoiceSubmissionLog.Status = 'Valid' then
                            Rec."eInvoice Validation Status" := 'Valid'
                        else if eInvoiceSubmissionLog.Status = 'Cancelled' then
                            Rec."eInvoice Validation Status" := 'Cancelled'
                        else
                            Rec."eInvoice Validation Status" := eInvoiceSubmissionLog.Status;

                        Rec.Modify();
                        CurrPage.Update();
                        Message('Status refreshed successfully for Credit Memo %1. Current status: %2', Rec."No.", Rec."eInvoice Validation Status");
                    end else begin
                        Message('Failed to refresh status for Credit Memo %1. Please check the submission log for details.', Rec."No.");
                    end;
                end;
            }

            action(ShowSubmissionLogEntries)
            {
                ApplicationArea = All;
                Caption = 'Show Submission Log Entries';
                Image = List;
                ToolTip = 'Show all submission log entries for this credit memo for debugging';
                Visible = IsJotexCompany;

                trigger OnAction()
                var
                    eInvoiceSubmissionLog: Record "eInvoice Submission Log";
                    LogInfo: Text;
                    EntryCount: Integer;
                begin
                    if not IsJotexCompany then
                        exit;

                    LogInfo := StrSubstNo('Submission Log Entries for Credit Memo: %1\\\', Rec."No.");
                    EntryCount := 0;

                    // Find all submission log entries for this credit memo
                    eInvoiceSubmissionLog.SetRange("Invoice No.", Rec."No.");
                    if eInvoiceSubmissionLog.FindSet() then begin
                        repeat
                            EntryCount += 1;
                            LogInfo += StrSubstNo('Entry %1:\- Document Type: %2\- Status: %3\- Submission UID: %4\- Document UUID: %5\- Customer Name: %6\- Submission Date: %7\\',
                                EntryCount,
                                eInvoiceSubmissionLog."Document Type",
                                eInvoiceSubmissionLog.Status,
                                eInvoiceSubmissionLog."Submission UID",
                                eInvoiceSubmissionLog."Document UUID",
                                eInvoiceSubmissionLog."Customer Name",
                                Format(eInvoiceSubmissionLog."Submission Date"));
                        until eInvoiceSubmissionLog.Next() = 0;
                    end else begin
                        LogInfo += 'No submission log entries found for this credit memo.\';
                    end;

                    if EntryCount = 0 then
                        LogInfo += '\This credit memo may not have been submitted to LHDN yet.'
                    else
                        LogInfo += StrSubstNo('\Total entries found: %1', EntryCount);

                    Message(LogInfo);
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
                FormattedResponse := StrSubstNo('Submission ID: %1\' +
                                   'Accepted Documents: %2\', SubmissionUid, Format(AcceptedCount));

                for i := 0 to AcceptedCount - 1 do begin
                    AcceptedArray.Get(i, JsonToken);
                    if JsonToken.IsObject() then begin
                        DocumentJson := JsonToken.AsObject();

                        if DocumentJson.Get('uuid', JsonToken) then
                            Uuid := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
                        if DocumentJson.Get('invoiceCodeNumber', JsonToken) then
                            InvoiceCodeNumber := CleanQuotesFromText(SafeJsonValueToText(JsonToken));

                        FormattedResponse += StrSubstNo('- Credit Memo: %1\    UUID: %2', InvoiceCodeNumber, Uuid);
                        if i < AcceptedCount - 1 then
                            FormattedResponse += '\';
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
                    FormattedResponse += '\';
                FormattedResponse += StrSubstNo('Rejected Documents: %1', Format(RejectedCount));
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
}