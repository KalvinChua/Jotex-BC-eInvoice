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
                        Error('Failed to complete signing and submission process.\nResponse: %1', LhdnResponse);
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
                    RetryCount: Integer;
                    MaxRetries: Integer;
                begin
                    // Step 1: Generate unsigned eInvoice JSON with validation
                    InvoiceId := Rec."No.";
                    JsonText := eInvoiceGenerator.GenerateEInvoiceJson(Rec, false);

                    // Step 2: Basic JSON validation
                    if JsonText = '' then
                        Error('Generated JSON is empty and cannot be sent to Azure Function.\n\nPlease check invoice data completeness and try again.');

                    if not (JsonText.StartsWith('{') and JsonText.EndsWith('}')) then
                        Error('Generated JSON format is invalid and cannot be sent to Azure Function.\n\nPlease check invoice data completeness and try again.');

                    // Step 3: Get Azure Function URL from setup with validation
                    if not Setup.Get('SETUP') then begin
                        Setup.Init();
                        Setup."Primary Key" := 'SETUP';
                        Setup.Insert();
                    end;
                    AzureFunctionUrl := Setup."Azure Function URL";
                    if AzureFunctionUrl = '' then
                        Error('Azure Function URL is not configured.\n\nPlease configure the Azure Function URL in e-Invoice Setup and try again.');

                    // Step 4: Send to Azure Function using background session with retry logic
                    MaxRetries := 3;
                    RetryCount := 0;
                    repeat
                        RetryCount += 1;
                        ClearLastError();

                        if not TryPostToAzureFunctionInBackground(JsonText, AzureFunctionUrl, SignedJsonText) then begin
                            if RetryCount >= MaxRetries then
                                Error('Failed to communicate with Azure Function after %1 attempts.\n\nLast error: %2\n\nPlease check:\n• Network connectivity\n• Azure Function availability\n• Azure Function URL configuration', MaxRetries, GetLastErrorText());

                            // Wait before retry (progressive delay: 1s, 2s, 3s)
                            Sleep(1000 * RetryCount);
                        end else
                            break; // Success, exit retry loop

                    until RetryCount >= MaxRetries;

                    // Step 5: Basic response validation
                    if SignedJsonText = '' then
                        Error('Azure Function returned empty response.\n\nPlease check Function App logs and try again.');

                    if not (SignedJsonText.StartsWith('{') and SignedJsonText.EndsWith('}')) then
                        Error('Azure Function returned invalid JSON response.\n\nPlease check Function App logs and try again.');

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

            action(TestAzureFunctionConnectivity)
            {
                ApplicationArea = All;
                Caption = 'Test Azure Function';
                Image = TestFile;
                ToolTip = 'Test Azure Function connectivity and diagnose issues';

                trigger OnAction()
                var
                    Client: HttpClient;
                    Response: HttpResponseMessage;
                    Setup: Record "eInvoiceSetup";
                    AzureFunctionUrl: Text;
                    ResponseText: Text;
                    RequestContent: HttpContent;
                    Headers: HttpHeaders;
                    TestPayload: JsonObject;
                    TestPayloadText: Text;
                    TestStartTime: DateTime;
                    TestEndTime: DateTime;
                    ResponseTime: Duration;
                begin
                    TestStartTime := CurrentDateTime;

                    // Get Azure Function URL from setup with validation
                    if not Setup.Get('SETUP') then begin
                        Message('Test Failed: eInvoice Setup Record Not Found\n\n' +
                                'Resolution Steps:\n' +
                                '1. Navigate to e-Invoice Setup\n' +
                                '2. Create or verify setup configuration\n' +
                                '3. Save the configuration\n' +
                                '4. Retry the connectivity test');
                        exit;
                    end;

                    AzureFunctionUrl := Setup."Azure Function URL";
                    if AzureFunctionUrl = '' then begin
                        Message('Test Failed: Azure Function URL Not Configured\n\n' +
                                'Resolution Steps:\n' +
                                '1. Navigate to e-Invoice Setup\n' +
                                '2. Configure the Azure Function URL\n' +
                                '3. Save the configuration\n' +
                                '4. Retry the connectivity test');
                        exit;
                    end;

                    Message('Testing Azure Function Connectivity...\n\n' +
                            'Target: %1\n' +
                            'Test started: %2\n' +
                            'Please wait...', AzureFunctionUrl, Format(TestStartTime, 0, '<Hours24,2>:<Minutes,2>:<Seconds,2>'));

                    // Create enhanced test payload (following myinvois-client pattern)
                    TestPayload.Add('test', 'connectivity');
                    TestPayload.Add('timestamp', Format(CurrentDateTime, 0, '<Year4>-<Month,2>-<Day,2>T<Hours24,2>:<Minutes,2>:<Seconds,2>Z'));
                    TestPayload.Add('source', 'BusinessCentral-ConnectivityTest');
                    TestPayload.Add('environment', Format(Setup.Environment));
                    TestPayload.Add('version', '1.0');
                    TestPayload.WriteTo(TestPayloadText);

                    // Setup request with enhanced headers
                    RequestContent.WriteFrom(TestPayloadText);
                    RequestContent.GetHeaders(Headers);
                    Headers.Clear();
                    Headers.Add('Content-Type', 'application/json');
                    Headers.Add('User-Agent', 'BusinessCentral-eInvoice/1.0-Test');
                    Headers.Add('X-Test-Type', 'Connectivity');

                    // Perform connectivity test with comprehensive diagnostics
                    if Client.Post(AzureFunctionUrl, RequestContent, Response) then begin
                        TestEndTime := CurrentDateTime;
                        ResponseTime := TestEndTime - TestStartTime;
                        Response.Content().ReadAs(ResponseText);

                        if Response.IsSuccessStatusCode() then begin
                            Message('Azure Function Connectivity Test PASSED\n\n' +
                                    'Endpoint: %1\n' +
                                    'Status Code: %2 %3\n' +
                                    'Response Time: %4 ms\n' +
                                    'Response Size: %5 characters\n' +
                                    'Test Completed: %6\n' +
                                    'Environment: %7\n\n' +
                                    'Status: Azure Function is healthy and responsive\n' +
                                    'Ready for e-Invoice signing operations\n\n' +
                                    'Response Preview:\n%8',
                                    AzureFunctionUrl, Response.HttpStatusCode(), Response.ReasonPhrase(),
                                    ResponseTime, StrLen(ResponseText),
                                    Format(TestEndTime, 0, '<Hours24,2>:<Minutes,2>:<Seconds,2>'),
                                    Format(Setup.Environment),
                                    CopyStr(ResponseText, 1, 150) + '...');
                        end else begin
                            Message('Azure Function Connectivity Test - Warning\n\n' +
                                    'Endpoint: %1\n' +
                                    'Status Code: %2 %3\n' +
                                    'Response Time: %4 ms\n' +
                                    'Test Completed: %5\n' +
                                    'Environment: %6\n\n' +
                                    'Function is reachable but returned non-success status\n\n' +
                                    'Potential Issues:\n' +
                                    '• Function may require authentication\n' +
                                    '• Test payload format may be incorrect\n' +
                                    '• Function may be in unhealthy state\n' +
                                    '• Resource constraints or dependencies\n' +
                                    '• Cold start delays or timeout issues\n\n' +
                                    'Response Details:\n%7',
                                    AzureFunctionUrl, Response.HttpStatusCode(), Response.ReasonPhrase(),
                                    ResponseTime, Format(TestEndTime, 0, '<Hours24,2>:<Minutes,2>:<Seconds,2>'),
                                    Format(Setup.Environment), ResponseText);
                        end;
                    end else begin
                        TestEndTime := CurrentDateTime;
                        Error('Azure Function Connectivity Test FAILED\n\n' +
                              'Endpoint: %1\n' +
                              'Test Duration: %2 ms\n' +
                              'Test Completed: %3\n' +
                              'Environment: %4\n\n' +
                              'Connection could not be established\n\n' +
                              'Comprehensive Troubleshooting Steps:\n' +
                              '1. Verify Function URL format and accessibility\n' +
                              '2. Check network connectivity and DNS resolution\n' +
                              '3. Ensure Azure Function App is running\n' +
                              '4. Verify firewall and security group settings\n' +
                              '5. Check Function App deployment status\n' +
                              '6. Review Azure Function App logs in Application Insights\n' +
                              '7. Validate Function App resource allocation\n' +
                              '8. Check Function App authentication settings\n' +
                              '9. Verify SSL/TLS certificate validity\n' +
                              '10. Test with direct HTTP client (Postman/curl)\n\n' +
                              'Common Connection Issues:\n' +
                              '• Incorrect Function URL or endpoint path\n' +
                              '• Network firewall blocking outbound requests\n' +
                              '• Function App stopped, deallocated, or scaling down\n' +
                              '• DNS resolution problems or proxy issues\n' +
                              '• SSL/TLS certificate validation failures\n' +
                              '• Timeout due to cold start delays (>5 minutes)\n' +
                              '• Function App plan limitations or quotas\n' +
                              '• CORS policy restrictions (if browser-based)\n\n' +
                              'Session Information for Support:\n' +
                              '• Test Timestamp: %3\n' +
                              '• Environment: %4\n' +
                              '• User-Agent: BusinessCentral-eInvoice/1.0-Test',
                              AzureFunctionUrl, TestEndTime - TestStartTime,
                              Format(TestEndTime, 0, '<Hours24,2>:<Minutes,2>:<Seconds,2>'),
                              Format(Setup.Environment));
                    end;
                end;
            }
        }
    }

    [TryFunction]
    local procedure TryPostToAzureFunctionInBackground(JsonText: Text; AzureFunctionUrl: Text; var SignedJsonText: Text)
    var
        eInvoiceGenerator: Codeunit "eInvoice 1.0 Invoice JSON";
    begin
        eInvoiceGenerator.PostJsonToAzureFunction(JsonText, AzureFunctionUrl, SignedJsonText);
    end;

    [TryFunction]
    local procedure TryPostToAzureFunction(var eInvoiceGenerator: Codeunit "eInvoice 1.0 Invoice JSON"; JsonText: Text; AzureFunctionUrl: Text; var SignedJsonText: Text)
    begin
        eInvoiceGenerator.PostJsonToAzureFunction(JsonText, AzureFunctionUrl, SignedJsonText);
    end;
}
