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
                    JsonText := eInvoiceGenerator.GenerateEInvoiceJson(Rec);

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
        }
    }
}