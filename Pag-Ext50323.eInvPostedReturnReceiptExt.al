pageextension 50323 eInvPostedReturnReceiptExt extends "Posted Return Receipt"
{
    actions
    {
        addlast(Processing)
        {
            action(SignAndSubmitToLHDN)
            {
                ApplicationArea = All;
                Caption = 'Sign & Submit to LHDN';
                Image = ElectronicDoc;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Sign the linked posted Credit Memo for this Return Receipt and submit to LHDN.';

                trigger OnAction()
                var
                    SalesCrMemoHeader: Record "Sales Cr.Memo Header";
                    eInvoiceGenerator: Codeunit "eInvoice JSON Generator";
                    LhdnResponse: Text;
                    Success: Boolean;
                begin
                    if not FindLinkedCreditMemo(SalesCrMemoHeader) then
                        Error('No linked Posted Sales Credit Memo could be found for Return Receipt %1.', Rec."No.");

                    // Suppress popups from the generator for this flow
                    eInvoiceGenerator.SetSuppressUserDialogs(true);
                    Success := eInvoiceGenerator.GetSignedCreditMemoAndSubmitToLHDN(SalesCrMemoHeader, LhdnResponse);
                    if not Success then
                        Error('Submission failed: %1', LhdnResponse);
                end;
            }

            action(GenerateEInvoiceJSON)
            {
                ApplicationArea = All;
                Caption = 'Generate e-Invoice JSON';
                Image = ExportFile;
                ToolTip = 'Generate e-Invoice JSON using the linked posted Credit Memo for this Return Receipt.';

                trigger OnAction()
                var
                    SalesCrMemoHeader: Record "Sales Cr.Memo Header";
                    eInvoiceGenerator: Codeunit "eInvoice JSON Generator";
                    TempBlob: Codeunit "Temp Blob";
                    JsonText: Text;
                    OutStream: OutStream;
                    InStream: InStream;
                    FileName: Text;
                begin
                    if not FindLinkedCreditMemo(SalesCrMemoHeader) then
                        Error('No linked Posted Sales Credit Memo could be found for Return Receipt %1.', Rec."No.");

                    JsonText := eInvoiceGenerator.GenerateCreditMemoEInvoiceJson(SalesCrMemoHeader, false);
                    FileName := StrSubstNo('eInvoice_ReturnReceipt_%1_%2.json', Rec."No.",
                        Format(CurrentDateTime, 0, '<Year4><Month,2><Day,2><Hours24,2><Minutes,2><Seconds,2>'));

                    TempBlob.CreateOutStream(OutStream);
                    OutStream.WriteText(JsonText);
                    TempBlob.CreateInStream(InStream);
                    DownloadFromStream(InStream, 'Download e-Invoice JSON', '', 'JSON files (*.json)|*.json', FileName);
                end;
            }
        }
    }

    local procedure FindLinkedCreditMemo(var SalesCrMemoHeader: Record "Sales Cr.Memo Header"): Boolean
    begin
        // Try by Return Order No. from the receipt
        SalesCrMemoHeader.Reset();
        SalesCrMemoHeader.SetRange("Return Order No.", Rec."Return Order No.");
        if SalesCrMemoHeader.FindLast() then
            exit(true);

        exit(false);
    end;
}


