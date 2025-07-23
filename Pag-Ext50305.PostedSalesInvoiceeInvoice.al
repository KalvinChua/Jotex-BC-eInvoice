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
                    Client: HttpClient;
                    RequestContent: HttpContent;
                    Response: HttpResponseMessage;
                    AzureFunctionUrl: Text;
                    Headers: HttpHeaders;
                    Setup: Record "eInvoiceSetup";
                    IsValidJson: Boolean;
                    TestJson: JsonObject;
                    ResponseText: Text;
                begin
                    // 1. Generate unsigned JSON
                    JsonText := eInvoiceGenerator.GenerateEInvoiceJson(Rec, false);

                    // 2. Validate JSON (basic check)
                    // Try to parse as JsonObject to check validity
                    if not TestJson.ReadFrom(JsonText) then
                        Error('Generated JSON is invalid and cannot be sent to Azure Function.');

                    // 3. Get Azure Function URL from setup
                    if not Setup.Get() then
                        Error('e-Invoice Setup record not found.');
                    AzureFunctionUrl := Setup."Azure Function URL";
                    if AzureFunctionUrl = '' then
                        Error('Azure Function URL is not configured. Please set it in e-Invoice Setup.');

                    // 4. Prepare HTTP POST
                    RequestContent.WriteFrom(JsonText);
                    RequestContent.GetHeaders(Headers);
                    Headers.Clear();
                    Headers.Add('Content-Type', 'application/json');

                    // 5. Send POST request with error handling
                    if not Client.Post(AzureFunctionUrl, RequestContent, Response) then
                        Error('Failed to connect to Azure Function at %1', AzureFunctionUrl);

                    if Response.IsSuccessStatusCode() then begin
                        Response.Content().ReadAs(SignedJsonText);
                        Message('Azure Function call succeeded.');

                        // 6. Download the signed JSON
                        FileName := StrSubstNo('eInvoice_Signed_%1_%2.json',
                            Rec."No.",
                            Format(CurrentDateTime, 0, '<Year4><Month,2><Day,2><Hours24,2><Minutes,2><Seconds,2>'));

                        TempBlob.CreateOutStream(OutStream);
                        OutStream.WriteText(SignedJsonText);
                        TempBlob.CreateInStream(InStream);
                        DownloadFromStream(InStream, 'Download Signed e-Invoice', '', 'JSON files (*.json)|*.json', FileName);
                    end else begin
                        Response.Content().ReadAs(ResponseText);
                        Error('Azure Function error: %1 %2\nResponse: %3', Response.HttpStatusCode(), Response.ReasonPhrase(), ResponseText);
                    end;
                end;
            }
        }
    }
}
