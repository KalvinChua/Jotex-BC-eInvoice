pageextension 50305 "Posted Sales Invoice eInvoice" extends "Posted Sales Invoice"
{
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

                trigger OnAction()
                var
                    eInvoiceGenerator: Codeunit "eInvoice 1.0 Invoice JSON";
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

                trigger OnAction()
                var
                    eInvoiceGenerator: Codeunit "eInvoice 1.0 Invoice JSON";
                    LhdnResponse: Text;
                    Success: Boolean;
                    ConfirmMsg: Text;
                    SuccessMsg: Text;
                begin
                    // Confirm with user
                    ConfirmMsg := StrSubstNo('This will:\n1. Generate unsigned eInvoice JSON\n2. Send to Azure Function for digital signing\n3. Submit signed invoice directly to LHDN MyInvois API\n\nProceed with invoice %1?', Rec."No.");
                    if not Confirm(ConfirmMsg) then
                        exit;

                    // Execute the complete workflow
                    Success := eInvoiceGenerator.GetSignedInvoiceAndSubmitToLHDN(Rec, LhdnResponse);

                    if Success then begin
                        SuccessMsg := StrSubstNo('Invoice %1 successfully signed and submitted to LHDN!\n\nLHDN Response:\n%2', Rec."No.", LhdnResponse);
                        Message(SuccessMsg);
                    end else begin
                        Message('Failed to complete signing and submission process.\nResponse: %1', LhdnResponse);
                    end;
                end;
            }

            action(PostToAzureFunctionAndDownloadSigned)
            {
                ApplicationArea = All;
                Caption = 'Get Signed e-Invoice (Azure)';
                Image = Cloud;
                ToolTip = 'Send unsigned e-Invoice JSON to Azure Function for digital signing and download the signed JSON.';

                trigger OnAction()
                var
                    eInvoiceGenerator: Codeunit "eInvoice 1.0 Invoice JSON";
                    TempBlob: Codeunit "Temp Blob";
                    FileName: Text;
                    JsonText: Text;
                    SignedJsonText: Text;
                    OutStream: OutStream;
                    InStream: InStream;
                    AzureFunctionUrl: Text;
                    Setup: Record "eInvoiceSetup";
                    InvoiceId: Text;
                begin
                    // Step 1: Generate unsigned eInvoice JSON with validation
                    InvoiceId := Rec."No.";

                    // Test JSON generation step by step
                    Message('Starting JSON generation for invoice %1...', InvoiceId);

                    JsonText := eInvoiceGenerator.GenerateEInvoiceJson(Rec, false);

                    Message('JSON generation completed. Length: %1 characters', StrLen(JsonText));

                    // Step 2: Basic JSON validation
                    if JsonText = '' then begin
                        Message('Generated JSON is empty and cannot be sent to Azure Function.\n\nPlease check invoice data completeness and try again.');
                        exit;
                    end;

                    if not (JsonText.StartsWith('{') and JsonText.EndsWith('}')) then begin
                        Message('Generated JSON format is invalid and cannot be sent to Azure Function.\n\nPlease check invoice data completeness and try again.');
                        exit;
                    end;

                    // Step 3: Get Azure Function URL from setup with validation
                    if not Setup.Get('SETUP') then begin
                        Setup.Init();
                        Setup."Primary Key" := 'SETUP';
                        Setup.Insert();
                    end;
                    AzureFunctionUrl := Setup."Azure Function URL";
                    if AzureFunctionUrl = '' then begin
                        Message('Azure Function URL is not configured.\n\nPlease configure the Azure Function URL in e-Invoice Setup and try again.');
                        exit;
                    end;

                    // Step 4: Send to Azure Function using session-safe method
                    Message('Sending JSON to Azure Function at: %1', AzureFunctionUrl);

                    // Use the new direct HTTP method with proper implementation
                    if not eInvoiceGenerator.TryPostToAzureFunctionDirect(JsonText, AzureFunctionUrl, SignedJsonText) then begin
                        Message('Failed to communicate with Azure Function.\n\nError: %1\n\nPlease check:\n• Network connectivity\n• Azure Function availability\n• Azure Function URL configuration\n• Try refreshing the page and attempting again', SignedJsonText);
                        exit;
                    end;

                    Message('Azure Function call completed successfully');

                    // Step 5: Basic response validation
                    if SignedJsonText = '' then begin
                        Message('Azure Function returned empty response.\n\nPlease check Function App logs and try again.');
                        exit;
                    end;

                    if not (SignedJsonText.StartsWith('{') and SignedJsonText.EndsWith('}')) then begin
                        Message('Azure Function returned invalid JSON response.\n\nPlease check Function App logs and try again.');
                        exit;
                    end;

                    // Step 6: Download the signed JSON
                    FileName := StrSubstNo('eInvoice_Signed_%1_%2.json',
                        Rec."No.",
                        Format(CurrentDateTime, 0, '<Year4><Month,2><Day,2><Hours24,2><Minutes,2><Seconds,2>'));

                    TempBlob.CreateOutStream(OutStream);
                    OutStream.WriteText(SignedJsonText);
                    TempBlob.CreateInStream(InStream);
                    DownloadFromStream(InStream, 'Download Signed e-Invoice', '', 'JSON files (*.json)|*.json', FileName);

                    Message('eInvoice %1 successfully signed and downloaded as %2', InvoiceId, FileName);
                end;
            }
        }
    }






}
