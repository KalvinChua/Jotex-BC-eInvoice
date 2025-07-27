page 50300 eInvoiceSetupCard
{
    PageType = Card;
    SourceTable = eInvoiceSetup;
    Caption = 'e-Invoice Setup';
    UsageCategory = Administration;
    ApplicationArea = All;

    layout
    {
        area(content)
        {

            group("API Configuration")
            {
                field("Client ID"; Rec."Client ID")
                {
                    ApplicationArea = All;
                }
                field("Client Secret"; Rec."Client Secret")
                {
                    ApplicationArea = All;
                }
                field("Environment"; Rec.Environment)
                {
                    ApplicationArea = All;
                }
                field("eInvoice Version"; Rec."eInvoice Version")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the e-Invoice version to use for submission to LHDN (e.g. 1.0 or 1.1).';
                }
                // New field for Azure Function URL
                field("Azure Function URL"; Rec."Azure Function URL")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Azure Function endpoint for e-Invoice signing and submission.';
                }
            }

            group("Token Info")
            {
                field("Last Token"; Rec."Last Token")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Token Timestamp"; Rec."Token Timestamp")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
            }
        }
    }


    actions
    {
        area(processing)
        {
            action(TestConnection)
            {
                Caption = 'Test Connection';
                ApplicationArea = All;
                Image = Action;

                trigger OnAction()
                var
                    Token: Text;
                    MyInvoisHelper: Codeunit eInvoiceHelper;
                    TokenLength: Integer;
                begin
                    Token := MyInvoisHelper.GetAccessTokenFromSetup(Rec);
                    TokenLength := StrLen(Token);

                    Message('Token Generation Test Results:\n\n' +
                        'Token Length: %1 characters\n' +
                        'Token Preview: %2...\n' +
                        'Token Format: %3\n\n' +
                        'Note: If token is valid, it should be a JWT token starting with "eyJ"',
                        TokenLength,
                        CopyStr(Token, 1, 50),
                        Token.StartsWith('eyJ') ? 'Valid JWT format' : 'Invalid format - should start with eyJ');
                end;
            }

            action(TestLhdnApiConnection)
            {
                Caption = 'Test LHDN API Connection';
                ApplicationArea = All;
                Image = TestReport;
                ToolTip = 'Test the actual LHDN API connection using the current token';

                trigger OnAction()
                var
                    eInvoiceJsonCodeunit: Codeunit "eInvoice 1.0 Invoice JSON";
                    DocumentTypesResponse: Text;
                begin
                    // Test by calling the document types API - this will verify the token works
                    if eInvoiceJsonCodeunit.GetLhdnDocumentTypes(DocumentTypesResponse) then begin
                        Message('LHDN API Connection Test SUCCESSFUL!\n\n' +
                            'Token is valid and API is accessible.\n\n' +
                            'Response preview: %1', CopyStr(DocumentTypesResponse, 1, 200));
                    end else begin
                        Message('LHDN API Connection Test FAILED!\n\n' +
                            'The token may be invalid or expired.\n\n' +
                            'Please check:\n' +
                            '1. Client ID and Client Secret are correct\n' +
                            '2. Environment setting is correct\n' +
                            '3. LHDN API service is available');
                    end;
                end;
            }

            action(GetDocumentTypes)
            {
                Caption = 'Get LHDN Document Types';
                ApplicationArea = All;
                Image = Document;
                ToolTip = 'Retrieve all available document types from LHDN MyInvois API';

                trigger OnAction()
                var
                    eInvoiceJsonCodeunit: Codeunit "eInvoice 1.0 Invoice JSON";
                    DocumentTypesResponse: Text;
                begin
                    if eInvoiceJsonCodeunit.GetLhdnDocumentTypes(DocumentTypesResponse) then begin
                        // Success message is already shown in the procedure
                    end;
                    // Error handling is done in the procedure
                end;
            }

            action(GetNotifications)
            {
                Caption = 'Get LHDN Notifications';
                ApplicationArea = All;
                Image = Email;
                ToolTip = 'Retrieve notifications from LHDN MyInvois system';

                trigger OnAction()
                var
                    eInvoiceJsonCodeunit: Codeunit "eInvoice 1.0 Invoice JSON";
                    NotificationsResponse: Text;
                    DateFrom: Date;
                    DateTo: Date;
                begin
                    // Get notifications for the last 7 days
                    DateFrom := CalcDate('-7D', Today);
                    DateTo := Today;

                    if eInvoiceJsonCodeunit.GetLhdnNotifications(NotificationsResponse, DateFrom, DateTo, 0, 1, 50) then begin
                        // Success message is already shown in the procedure
                    end;
                    // Error handling is done in the procedure
                end;
            }

            action(TestPayloadFormat)
            {
                Caption = 'Test Payload Format';
                ApplicationArea = All;
                Image = TestReport;
                ToolTip = 'Generate and view the payload format that will be sent to Azure Function for debugging';

                trigger OnAction()
                var
                    eInvoiceGenerator: Codeunit "eInvoice 1.0 Invoice JSON";
                    SalesInvoiceHeader: Record "Sales Invoice Header";
                    JsonText: Text;
                    PayloadObject: JsonObject;
                    PayloadText: Text;
                    TempBlob: Codeunit "Temp Blob";
                    OutStream: OutStream;
                    InStream: InStream;
                    FileName: Text;
                    Setup: Record "eInvoiceSetup";
                    EnvironmentText: Text;
                begin
                    // Get the latest posted sales invoice for testing
                    SalesInvoiceHeader.Reset();
                    if SalesInvoiceHeader.FindLast() then begin
                        // Generate the unsigned eInvoice JSON
                        JsonText := eInvoiceGenerator.GenerateEInvoiceJson(SalesInvoiceHeader, false);

                        if JsonText = '' then
                            Error('Failed to generate eInvoice JSON for testing');

                        // Get environment setting from setup
                        if Setup.Get('SETUP') then begin
                            case Setup.Environment of
                                Setup.Environment::Preprod:
                                    EnvironmentText := 'PREPROD';
                                Setup.Environment::Production:
                                    EnvironmentText := 'PRODUCTION';
                                else
                                    EnvironmentText := 'PREPROD';
                            end;
                        end else
                            EnvironmentText := 'PREPROD';

                        // Create the same payload structure that will be sent to Azure Function
                        PayloadObject.Add('unsignedJson', JsonText);
                        PayloadObject.Add('invoiceType', '01');
                        PayloadObject.Add('environment', EnvironmentText);
                        PayloadObject.Add('timestamp', Format(CurrentDateTime, 0, '<Year4>-<Month,2>-<Day,2>T<Hours24,2>:<Minutes,2>:<Seconds,2>Z'));
                        PayloadObject.Add('requestId', CreateGuid());
                        PayloadObject.WriteTo(PayloadText);

                        if PayloadText <> '' then begin
                            // Validate the payload structure
                            if not (PayloadText.StartsWith('{') and PayloadText.EndsWith('}')) then
                                Error('Generated payload is not valid JSON');

                            // Show first 500 characters in a message
                            Message('Azure Function Payload Preview (first 500 chars):\n\n%1\n\n[Full payload will be downloaded as file]',
                                CopyStr(PayloadText, 1, 500));

                            // Download full payload for inspection
                            FileName := StrSubstNo('Azure_Function_Payload_%1_%2.json',
                                SalesInvoiceHeader."No.",
                                Format(CurrentDateTime, 0, '<Year4><Month,2><Day,2><Hours24,2><Minutes,2><Seconds,2>'));

                            TempBlob.CreateOutStream(OutStream);
                            OutStream.WriteText(PayloadText);
                            TempBlob.CreateInStream(InStream);
                            DownloadFromStream(InStream, 'Download Azure Function Payload', '', 'JSON files (*.json)|*.json', FileName);
                        end else
                            Error('Failed to generate payload for testing');
                    end else
                        Error('No posted sales invoices found for testing');
                end;
            }

            action(DebugAzureFunction)
            {
                Caption = 'Debug Azure Function';
                ApplicationArea = All;
                Image = TestFile;
                ToolTip = 'Test Azure Function connectivity and get detailed diagnostics';

                trigger OnAction()
                var
                    eInvoiceGenerator: Codeunit "eInvoice 1.0 Invoice JSON";
                    DiagnosticResult: Text;
                begin
                    if Rec."Azure Function URL" = '' then begin
                        Error('Azure Function URL is not configured. Please configure it first.');
                    end;

                    DiagnosticResult := eInvoiceGenerator.TestAzureFunctionConnectivity(Rec."Azure Function URL");
                    Message(DiagnosticResult);
                end;
            }
        }
    }

    trigger OnOpenPage()
    var
        Setup: Record eInvoiceSetup;
    begin
        if not Setup.Get('SETUP') then begin
            Setup.Init();
            Setup."Primary Key" := 'SETUP';
            Setup.Insert();
        end;
        // Ensure the page is showing the SETUP record
        Rec.Get('SETUP');
    end;
}
