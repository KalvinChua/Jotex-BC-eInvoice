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
                    ToolTip = 'Shows the validation status returned by LHDN (Accepted/Rejected).';
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
                        SuccessMsg := StrSubstNo('Invoice %1 successfully signed and submitted to LHDN!' + '\\' + '\\' + 'LHDN Response:' + '\\' + '%2', Rec."No.", LhdnResponse);
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
}