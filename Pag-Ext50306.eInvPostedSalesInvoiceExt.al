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
                }
                field("eInvoice UUID"; Rec."eInvoice UUID")
                {
                    ApplicationArea = All;
                    Caption = 'e-Invoice UUID';
                    ToolTip = 'Stores the document UUID assigned by LHDN MyInvois.';
                    Visible = IsJotexCompany;
                }
                field("eInvoice Validation Status"; Rec."eInvoice Validation Status")
                {
                    ApplicationArea = All;
                    Caption = 'e-Invoice Validation Status';
                    ToolTip = 'Shows the validation status returned by LHDN (Submitted/Submission Failed for initial submission, or valid/invalid/in progress/partially valid for processing status).';
                    Visible = IsJotexCompany;
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
                    ConfirmMsg: Text;
                    SuccessMsg: Text;
                begin
                    ConfirmMsg := StrSubstNo('This will:' + '\\' + '1. Generate unsigned eInvoice JSON' + '\\' + '2. Send to Azure Function for digital signing' + '\\' + '3. Submit signed invoice directly to LHDN MyInvois API' + '\\' + '\\' + 'Proceed with invoice %1?', Rec."No.");
                    if not Confirm(ConfirmMsg) then
                        exit;

                    Success := eInvoiceGenerator.GetSignedInvoiceAndSubmitToLHDN(Rec, LhdnResponse);

                    if Success then begin
                        SuccessMsg := StrSubstNo('Invoice %1 successfully signed and submitted to LHDN!' + '\\' + '\\' + 'LHDN Response:' + '\\' + '%2', Rec."No.", FormatLhdnResponse(LhdnResponse));
                        Message(SuccessMsg);
                    end else begin
                        Message(StrSubstNo('Failed to complete signing and submission process.' + '\\' + 'Response: %1', LhdnResponse));
                    end;
                end;
            }

            action(CheckSubmissionStatus)
            {
                ApplicationArea = All;
                Caption = 'Check LHDN Submission Status';
                Image = Refresh;
                ToolTip = 'Check the current status of the LHDN submission using the Get Submission API';
                Visible = IsJotexCompany;

                trigger OnAction()
                var
                    SubmissionStatusCU: Codeunit "eInvoice Submission Status";
                    SubmissionDetails: Text;
                    ApiSuccess: Boolean;
                    ConfirmMsg: Text;
                begin
                    if Rec."eInvoice Submission UID" = '' then begin
                        Message('No submission UID found for this invoice.' + '\\' + 'Please submit the invoice to LHDN first.');
                        exit;
                    end;

                    ConfirmMsg := StrSubstNo('This will check the current status of submission %1 using the LHDN Get Submission API.' + '\\' + '\\' + 'Note: LHDN recommends 3-5 second intervals between requests.' + '\\' + '\\' + 'Proceed?', Rec."eInvoice Submission UID");
                    if not Confirm(ConfirmMsg) then
                        exit;

                    ApiSuccess := SubmissionStatusCU.CheckSubmissionStatus(Rec."eInvoice Submission UID", SubmissionDetails);

                    if ApiSuccess then begin
                        Message(StrSubstNo('Submission Status for %1:' + '\\' + '\\' + '%2', Rec."eInvoice Submission UID", SubmissionDetails));
                    end else begin
                        Message(StrSubstNo('Failed to get submission status.' + '\\' + '\\' + 'Error: %1' + '\\' + '\\' + 'This may be due to rate limiting or network issues. Please try again in a few seconds.', SubmissionDetails));
                    end;
                end;
            }

            action(CheckStatusWithPolling)
            {
                ApplicationArea = All;
                Caption = 'Check Status with Auto-Polling';
                Image = Refresh;
                ToolTip = 'Check submission status with automatic polling (recommended for monitoring processing)';
                Visible = IsJotexCompany;

                trigger OnAction()
                var
                    SubmissionStatusCU: Codeunit "eInvoice Submission Status";
                    SubmissionDetails: Text;
                    ApiSuccess: Boolean;
                    ConfirmMsg: Text;
                begin
                    if Rec."eInvoice Submission UID" = '' then begin
                        Message('No submission UID found for this invoice.' + '\\' + 'Please submit the invoice to LHDN first.');
                        exit;
                    end;

                    ConfirmMsg := StrSubstNo('This will check the status of submission %1 with automatic polling.' + '\\' + '\\' +
                                           'The system will make up to 5 attempts with 4-second intervals (total 20 seconds).' + '\\' + '\\' +
                                           'This is recommended for monitoring documents that are still being processed.' + '\\' + '\\' +
                                           'Proceed?', Rec."eInvoice Submission UID");
                    if not Confirm(ConfirmMsg) then
                        exit;

                    ApiSuccess := SubmissionStatusCU.GetSubmissionStatusWithAutoPolling(Rec."eInvoice Submission UID", SubmissionDetails);

                    if ApiSuccess then begin
                        Message(StrSubstNo('Submission Status (with polling) for %1:' + '\\' + '\\' + '%2', Rec."eInvoice Submission UID", SubmissionDetails));
                    end else begin
                        Message(StrSubstNo('Failed to get submission status after polling attempts.' + '\\' + '\\' + 'Error: %1' + '\\' + '\\' + 'The submission may still be processing. Please try again later.', SubmissionDetails));
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
}