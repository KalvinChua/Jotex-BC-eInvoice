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
                begin
                    Token := MyInvoisHelper.GetAccessTokenFromSetup(Rec);
                    Message('Access token retrieved: %1', CopyStr(Token, 1, 50) + '...');
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

            action(TestAzureFunctionBasic)
            {
                Caption = 'Test Azure Function (Basic)';
                ApplicationArea = All;
                Image = TestFile;
                ToolTip = 'Simple GET connectivity test to Azure Function';

                trigger OnAction()
                var
                    HttpClient: HttpClient;
                    HttpResponseMessage: HttpResponseMessage;
                    ResponseText: Text;
                    AzureFunctionUrl: Text;
                begin
                    if Rec."Azure Function URL" = '' then begin
                        Error('Azure Function URL is not configured. Please configure it first.');
                    end;

                    AzureFunctionUrl := Rec."Azure Function URL";
                    Message('Testing basic connectivity to: %1', AzureFunctionUrl);

                    // Simple GET request without authentication
                    if HttpClient.Get(AzureFunctionUrl, HttpResponseMessage) then begin
                        if HttpResponseMessage.IsSuccessStatusCode then begin
                            HttpResponseMessage.Content.ReadAs(ResponseText);
                            Message('Basic Test PASSED - Azure Function connectivity successful! Response: %1',
                                CopyStr(ResponseText, 1, 200));
                        end else begin
                            HttpResponseMessage.Content.ReadAs(ResponseText);
                            Message('Basic Test WARNING - Azure Function returned error code: %1 %2. Response: %3. This may be normal if the function requires specific endpoints or authentication.',
                                HttpResponseMessage.HttpStatusCode, HttpResponseMessage.ReasonPhrase, CopyStr(ResponseText, 1, 200));
                        end;
                    end else begin
                        Error('Basic Test FAILED - Failed to connect to Azure Function. Please check: Function URL is correct, Function is deployed and running, Network connectivity');
                    end;
                end;
            }

            action(TestAzureFunctionAdvanced)
            {
                Caption = 'Test Azure Function (Advanced)';
                ApplicationArea = All;
                Image = TestReport;
                ToolTip = 'Comprehensive POST test with headers and detailed diagnostics';

                trigger OnAction()
                var
                    HttpClient: HttpClient;
                    HttpRequestMessage: HttpRequestMessage;
                    HttpResponseMessage: HttpResponseMessage;
                    HttpContent: HttpContent;
                    HttpHeaders: HttpHeaders;
                    ResponseText: Text;
                    RequestText: Text;
                    AzureFunctionUrl: Text;
                    ErrorText: Text;
                    TestStartTime: DateTime;
                    TestEndTime: DateTime;
                    TestDuration: Duration;
                begin
                    if Rec."Azure Function URL" = '' then begin
                        Error('Azure Function URL is not configured. Please configure it first.');
                    end;

                    AzureFunctionUrl := Rec."Azure Function URL";
                    TestStartTime := CurrentDateTime;

                    Message('ADVANCED TEST STARTING - Target: %1, Test Type: POST with JSON payload, Test Started: %2. Please wait...',
                        AzureFunctionUrl, Format(TestStartTime, 0, '<Hours24,2>:<Minutes,2>:<Seconds,2>'));

                    // Prepare comprehensive test request body
                    RequestText := StrSubstNo('{"test": "connectivity", "source": "BusinessCentral-Advanced", "timestamp": "%1", "environment": "%2", "version": "1.1"}',
                        Format(CurrentDateTime, 0, '<Year4>-<Month,2>-<Day,2>T<Hours24,2>:<Minutes,2>:<Seconds,2>Z'),
                        Format(Rec.Environment));

                    HttpContent.WriteFrom(RequestText);

                    // Set comprehensive headers
                    HttpContent.GetHeaders(HttpHeaders);
                    HttpHeaders.Clear();
                    HttpHeaders.Add('Content-Type', 'application/json');
                    HttpHeaders.Add('User-Agent', 'BusinessCentral-eInvoice/1.1-AdvancedTest');
                    HttpHeaders.Add('Accept', 'application/json');
                    HttpHeaders.Add('X-Test-Type', 'Advanced-Connectivity');
                    HttpHeaders.Add('X-BC-Environment', Format(Rec.Environment));

                    // Create and configure request
                    HttpRequestMessage.Method := 'POST';
                    HttpRequestMessage.SetRequestUri(AzureFunctionUrl);
                    HttpRequestMessage.Content := HttpContent;

                    // Set timeout to 60 seconds for thorough testing
                    HttpClient.Timeout(60000);

                    // Send request with detailed logging
                    if HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then begin
                        TestEndTime := CurrentDateTime;
                        TestDuration := TestEndTime - TestStartTime;

                        Message('HTTP REQUEST SENT SUCCESSFULLY - Response Status: %1 %2, Response Time: %3 ms, Test Completed: %4',
                            HttpResponseMessage.HttpStatusCode, HttpResponseMessage.ReasonPhrase,
                            TestDuration, Format(TestEndTime, 0, '<Hours24,2>:<Minutes,2>:<Seconds,2>'));

                        if HttpResponseMessage.IsSuccessStatusCode then begin
                            HttpResponseMessage.Content.ReadAs(ResponseText);
                            Message('ADVANCED TEST PASSED - Azure Function is fully operational! Status: %1 %2, Response Time: %3 ms, Response Size: %4 chars, Environment: %5. Response Preview: %6',
                                HttpResponseMessage.HttpStatusCode, HttpResponseMessage.ReasonPhrase,
                                TestDuration, StrLen(ResponseText), Format(Rec.Environment),
                                CopyStr(ResponseText, 1, 300));
                        end else begin
                            HttpResponseMessage.Content.ReadAs(ResponseText);
                            Message('ADVANCED TEST WARNING - Function is reachable but returned error status. Status: %1 %2, Response Time: %3 ms, Environment: %4. Error Response: %5. Possible Issues: Function may require authentication, Specific endpoint path needed, Test payload format incorrect, Function configuration issues',
                                HttpResponseMessage.HttpStatusCode, HttpResponseMessage.ReasonPhrase,
                                TestDuration, Format(Rec.Environment), CopyStr(ResponseText, 1, 300));
                        end;
                    end else begin
                        TestEndTime := CurrentDateTime;
                        Error('ADVANCED TEST FAILED - Failed to send HTTP request to Azure Function. Test Duration: %1 ms. Troubleshooting Steps: 1. Verify Function URL format, 2. Check Function deployment status, 3. Validate network connectivity, 4. Review firewall/proxy settings, 5. Confirm Function App is running, 6. Check SSL/TLS certificates. Contact support with these details: Test Time: %2, Environment: %3, Function URL: %4',
                            TestEndTime - TestStartTime, Format(TestEndTime, 0, '<Hours24,2>:<Minutes,2>:<Seconds,2>'),
                            Format(Rec.Environment), AzureFunctionUrl);
                    end;
                end;
            }

            action(TestAzureFunctionHealth)
            {
                Caption = 'Test Health Endpoint';
                ApplicationArea = All;
                Image = TestDatabase;
                ToolTip = 'Test Azure Function health endpoint if available';

                trigger OnAction()
                var
                    HttpClient: HttpClient;
                    HttpResponseMessage: HttpResponseMessage;
                    ResponseText: Text;
                    HealthUrl: Text;
                begin
                    if Rec."Azure Function URL" = '' then begin
                        Error('Azure Function URL is not configured. Please configure it first.');
                    end;

                    // Try common health endpoint patterns
                    HealthUrl := Rec."Azure Function URL";
                    if not HealthUrl.EndsWith('/') then
                        HealthUrl += '/';
                    HealthUrl += 'health';

                    Message('HEALTH CHECK STARTING - Testing health endpoint: %1. Please wait...', HealthUrl);

                    if HttpClient.Get(HealthUrl, HttpResponseMessage) then begin
                        if HttpResponseMessage.IsSuccessStatusCode then begin
                            HttpResponseMessage.Content.ReadAs(ResponseText);
                            Message('HEALTH CHECK PASSED - Azure Function health endpoint is responding! Status: %1 %2. Health Response: %3',
                                HttpResponseMessage.HttpStatusCode, HttpResponseMessage.ReasonPhrase, CopyStr(ResponseText, 1, 300));
                        end else begin
                            HttpResponseMessage.Content.ReadAs(ResponseText);
                            Message('HEALTH CHECK WARNING - Health endpoint returned: %1 %2. Response: %3. Note: Not all Azure Functions implement health endpoints.',
                                HttpResponseMessage.HttpStatusCode, HttpResponseMessage.ReasonPhrase, CopyStr(ResponseText, 1, 200));
                        end;
                    end else begin
                        Message('HEALTH CHECK FAILED - Health endpoint not accessible. This is normal if: Function does not implement health endpoint, Different endpoint path is used, Authentication is required. Try the Basic or Advanced tests instead.');
                    end;
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
