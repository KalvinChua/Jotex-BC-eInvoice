page 50316 "e-Invoice Submission Log"
{
    PageType = List;
    SourceTable = "eInvoice Submission Log";
    Caption = 'e-Invoice Submission Log';
    UsageCategory = Lists;
    ApplicationArea = All;
    CardPageId = "e-Invoice Submission Log Card";
    Editable = false; // Make list page read-only to prevent data corruption

    layout
    {
        area(content)
        {
            repeater(GroupName)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the unique entry number for this log entry.';
                }
                field("Invoice No."; Rec."Invoice No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the invoice number that was submitted.';
                }
                field("Customer Name"; Rec."Customer Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the customer name for this invoice submission.';
                }
                field("Submission UID"; Rec."Submission UID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the LHDN submission UID returned after submission.';
                }
                field("Document UUID"; Rec."Document UUID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the document UUID assigned by LHDN MyInvois.';
                }
                field("Status"; Rec.Status)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the submission status (Submitted, Accepted, Rejected, etc.).';
                }
                field("Submission Date"; Rec."Submission Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the invoice was submitted to LHDN.';
                }
                field("Response Date"; Rec."Response Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the response was received from LHDN.';
                }
                field("Environment"; Rec.Environment)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the environment (Preprod/Production) where the submission was made.';
                }
                field("Error Message"; Rec."Error Message")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies any error message received from LHDN.';
                    Visible = false;
                }
            }
        }
    }

    actions
    {
        area(processing)
        {
            action(RefreshStatus)
            {
                ApplicationArea = All;
                Caption = 'Refresh Status';
                Image = Refresh;
                ToolTip = 'Refresh the status of the selected submission from LHDN using direct API call';

                trigger OnAction()
                var
                    HttpClient: HttpClient;
                    HttpRequestMessage: HttpRequestMessage;
                    HttpResponseMessage: HttpResponseMessage;
                    RequestHeaders: HttpHeaders;
                    AccessToken: Text;
                    eInvoiceSetup: Record "eInvoiceSetup";
                    eInvoiceHelper: Codeunit eInvoiceHelper;
                    ApiUrl: Text;
                    ResponseText: Text;
                    LhdnStatus: Text;
                begin
                    // Validate selection
                    if Rec."Submission UID" = '' then begin
                        Message('Please select a record with a Submission UID to refresh.');
                        exit;
                    end;

                    // Get setup for environment determination
                    if not eInvoiceSetup.Get('SETUP') then begin
                        Message('eInvoice Setup not found');
                        exit;
                    end;

                    // Get access token using the helper method
                    eInvoiceHelper.InitializeHelper();
                    AccessToken := eInvoiceHelper.GetAccessTokenFromSetup(eInvoiceSetup);
                    if AccessToken = '' then begin
                        Message('Failed to get access token');
                        exit;
                    end;

                    // Build API URL
                    if eInvoiceSetup.Environment = eInvoiceSetup.Environment::Preprod then
                        ApiUrl := StrSubstNo('https://preprod-api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions/%1', Rec."Submission UID")
                    else
                        ApiUrl := StrSubstNo('https://api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions/%1', Rec."Submission UID");

                    // Setup request
                    HttpRequestMessage.Method := 'GET';
                    HttpRequestMessage.SetRequestUri(ApiUrl);

                    // Set headers
                    HttpRequestMessage.GetHeaders(RequestHeaders);
                    RequestHeaders.Clear();
                    RequestHeaders.Add('Accept', 'application/json');
                    RequestHeaders.Add('Accept-Language', 'en');
                    RequestHeaders.Add('Authorization', 'Bearer ' + AccessToken);

                    // Send request
                    if HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then begin
                        HttpResponseMessage.Content.ReadAs(ResponseText);

                        if HttpResponseMessage.IsSuccessStatusCode then begin
                            // Extract status from response and update record
                            LhdnStatus := ExtractStatusFromApiResponse(ResponseText);

                            Rec.Status := LhdnStatus;
                            Rec."Response Date" := CurrentDateTime;
                            Rec."Last Updated" := CurrentDateTime;
                            Rec."Error Message" := 'Status updated via direct API call: ' + LhdnStatus;
                            Rec.Modify();

                            Message('Status refreshed successfully using direct API!\\\\' +
                                   'Submission UID: %1\\' +
                                   'New Status: %2\\' +
                                   'Updated: %3',
                                   Rec."Submission UID",
                                   LhdnStatus,
                                   Format(CurrentDateTime, 0, '<Day,2>/<Month,2>/<Year4> <Hours24,2>:<Minutes,2>'));
                        end else begin
                            // Update error message
                            Rec."Error Message" := CopyStr('Direct API call failed: Status ' + Format(HttpResponseMessage.HttpStatusCode) + ' - ' + ResponseText, 1, MaxStrLen(Rec."Error Message"));
                            Rec."Last Updated" := CurrentDateTime;
                            Rec.Modify();

                            Message('Direct API Call FAILED\\\\' +
                                   'Submission UID: %1\\' +
                                   'Status Code: %2\\' +
                                   'Error Response:\\%3',
                                   Rec."Submission UID",
                                   HttpResponseMessage.HttpStatusCode,
                                   ResponseText);
                        end;
                    end else begin
                        // Update error message
                        Rec."Error Message" := CopyStr('HTTP request failed: ' + GetLastErrorText(), 1, MaxStrLen(Rec."Error Message"));
                        Rec."Last Updated" := CurrentDateTime;
                        Rec.Modify();

                        Message('Failed to send HTTP request to LHDN API\\\\' +
                               'URL: %1\\' +
                               'Last Error: %2',
                               ApiUrl, GetLastErrorText());
                    end;

                    CurrPage.Update(false);
                end;
            }
            action(RefreshAllStatuses)
            {
                ApplicationArea = All;
                Caption = 'Refresh All Statuses';
                Image = RefreshLines;
                ToolTip = 'Refresh the status for all submissions with UIDs using direct LHDN API calls';

                trigger OnAction()
                var
                    SubmissionLog: Record "eInvoice Submission Log";
                    HttpClient: HttpClient;
                    HttpRequestMessage: HttpRequestMessage;
                    HttpResponseMessage: HttpResponseMessage;
                    RequestHeaders: HttpHeaders;
                    AccessToken: Text;
                    eInvoiceSetup: Record "eInvoiceSetup";
                    eInvoiceHelper: Codeunit eInvoiceHelper;
                    ApiUrl: Text;
                    ResponseText: Text;
                    LhdnStatus: Text;
                    UpdatedCount: Integer;
                    FailedCount: Integer;
                    TotalCount: Integer;
                    ProgressDialog: Dialog;
                begin
                    if not Confirm('This will refresh the status for ALL submissions with UIDs using direct API calls.\\\\' +
                                 'This may take several minutes depending on the number of entries.\\\\' +
                                 'Continue?') then
                        exit;

                    // Get setup for environment determination
                    if not eInvoiceSetup.Get('SETUP') then begin
                        Message('eInvoice Setup not found');
                        exit;
                    end;

                    // Get access token using the helper method
                    eInvoiceHelper.InitializeHelper();
                    AccessToken := eInvoiceHelper.GetAccessTokenFromSetup(eInvoiceSetup);
                    if AccessToken = '' then begin
                        Message('Failed to get access token');
                        exit;
                    end;

                    // Count total records
                    SubmissionLog.SetFilter("Submission UID", '<>%1', '');
                    TotalCount := SubmissionLog.Count();

                    if TotalCount = 0 then begin
                        Message('No submissions with UIDs found to refresh.');
                        exit;
                    end;

                    ProgressDialog.Open('Refreshing submission statuses...\\' +
                                       'Progress: #1### of #2### \\' +
                                       'Current: #3################## \\' +
                                       'Updated: #4### Failed: #5###');

                    ProgressDialog.Update(2, TotalCount);

                    // Process each record
                    if SubmissionLog.FindSet() then
                        repeat
                            ProgressDialog.Update(1, SubmissionLog."Entry No.");
                            ProgressDialog.Update(3, SubmissionLog."Submission UID");
                            ProgressDialog.Update(4, UpdatedCount);
                            ProgressDialog.Update(5, FailedCount);

                            // Build API URL
                            if eInvoiceSetup.Environment = eInvoiceSetup.Environment::Preprod then
                                ApiUrl := StrSubstNo('https://preprod-api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions/%1', SubmissionLog."Submission UID")
                            else
                                ApiUrl := StrSubstNo('https://api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions/%1', SubmissionLog."Submission UID");

                            // Setup request
                            Clear(HttpRequestMessage);
                            Clear(HttpResponseMessage);
                            HttpRequestMessage.Method := 'GET';
                            HttpRequestMessage.SetRequestUri(ApiUrl);

                            // Set headers
                            HttpRequestMessage.GetHeaders(RequestHeaders);
                            RequestHeaders.Clear();
                            RequestHeaders.Add('Accept', 'application/json');
                            RequestHeaders.Add('Accept-Language', 'en');
                            RequestHeaders.Add('Authorization', 'Bearer ' + AccessToken);

                            // Send request
                            if HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then begin
                                HttpResponseMessage.Content.ReadAs(ResponseText);

                                if HttpResponseMessage.IsSuccessStatusCode then begin
                                    // Extract status from response and update record
                                    LhdnStatus := ExtractStatusFromApiResponse(ResponseText);

                                    SubmissionLog.Status := LhdnStatus;
                                    SubmissionLog."Response Date" := CurrentDateTime;
                                    SubmissionLog."Last Updated" := CurrentDateTime;
                                    SubmissionLog."Error Message" := 'Bulk status update via direct API: ' + LhdnStatus;
                                    SubmissionLog.Modify();
                                    UpdatedCount += 1;
                                end else begin
                                    // Update error message
                                    SubmissionLog."Error Message" := CopyStr('Bulk API failed: Status ' + Format(HttpResponseMessage.HttpStatusCode), 1, MaxStrLen(SubmissionLog."Error Message"));
                                    SubmissionLog."Last Updated" := CurrentDateTime;
                                    SubmissionLog.Modify();
                                    FailedCount += 1;
                                end;
                            end else begin
                                // Update error message
                                SubmissionLog."Error Message" := CopyStr('Bulk HTTP request failed', 1, MaxStrLen(SubmissionLog."Error Message"));
                                SubmissionLog."Last Updated" := CurrentDateTime;
                                SubmissionLog.Modify();
                                FailedCount += 1;
                            end;

                            // Brief delay to respect rate limits
                            Sleep(100);

                        until SubmissionLog.Next() = 0;

                    ProgressDialog.Close();

                    Message('Bulk status refresh completed!\\\\' +
                           'Total processed: %1\\' +
                           'Successfully updated: %2\\' +
                           'Failed: %3',
                           TotalCount,
                           UpdatedCount,
                           FailedCount);

                    CurrPage.Update(false);
                end;
            }

            action(ExportToExcel)
            {
                ApplicationArea = All;
                Caption = 'Export to Excel';
                Image = ExportFile;
                ToolTip = 'Export the submission log to Excel for analysis';

                trigger OnAction()
                var
                    TempBlob: Codeunit "Temp Blob";
                    OutStream: OutStream;
                    InStream: InStream;
                    FileName: Text;
                    CsvContent: Text;
                begin
                    // Generate CSV content
                    CsvContent := 'Entry No.,Invoice No.,Customer Name,Submission UID,Document UUID,Status,Submission Date,Response Date,Environment,Error Message' + '\\';

                    if Rec.FindSet() then begin
                        repeat
                            CsvContent += StrSubstNo('%1,%2,%3,%4,%5,%6,%7,%8,%9,%10' + '\\',
                                Rec."Entry No.",
                                Rec."Invoice No.",
                                Rec."Customer Name",
                                Rec."Submission UID",
                                Rec."Document UUID",
                                Rec.Status,
                                Format(Rec."Submission Date"),
                                Format(Rec."Response Date"),
                                Rec.Environment,
                                Rec."Error Message");
                        until Rec.Next() = 0;
                    end;

                    // Create and download file
                    FileName := StrSubstNo('eInvoice_Submission_Log_%1.csv',
                        Format(CurrentDateTime, 0, '<Year4><Month,2><Day,2><Hours24,2><Minutes,2><Seconds,2>'));

                    TempBlob.CreateOutStream(OutStream);
                    OutStream.WriteText(CsvContent);
                    TempBlob.CreateInStream(InStream);
                    DownloadFromStream(InStream, 'Download Submission Log', '', 'CSV files (*.csv)|*.csv', FileName);
                end;
            }

            action(ClearOldEntries)
            {
                ApplicationArea = All;
                Caption = 'Clear Old Entries';
                Image = Delete;
                ToolTip = 'Clear log entries older than 30 days';

                trigger OnAction()
                var
                    DeleteDate: Date;
                    DeletedCount: Integer;
                begin
                    if Confirm('This will delete all log entries older than 30 days.' + '\\' + '\\' + 'Proceed?') then begin
                        DeleteDate := CalcDate('-30D', Today);
                        DeletedCount := 0;

                        Rec.SetRange("Submission Date", 0DT, CreateDateTime(DeleteDate, 235959T));
                        if Rec.FindSet() then begin
                            repeat
                                Rec.Delete();
                                DeletedCount += 1;
                            until Rec.Next() = 0;
                        end;

                        Message('Cleared %1 old log entries.', DeletedCount);
                    end;
                end;
            }
        }
    }

    /// <summary>
    /// Extract status from LHDN API response for display purposes
    /// </summary>
    /// <param name="ResponseText">JSON response from LHDN API</param>
    /// <returns>The formatted status value</returns>
    local procedure ExtractStatusFromApiResponse(ResponseText: Text): Text
    var
        JsonObject: JsonObject;
        JsonToken: JsonToken;
        OverallStatus: Text;
    begin
        // Parse the JSON response
        if not JsonObject.ReadFrom(ResponseText) then
            exit('Unknown - JSON Parse Failed');

        // Extract the overallStatus field
        if not JsonObject.Get('overallStatus', JsonToken) then
            exit('Unknown - No Status Field');

        OverallStatus := JsonToken.AsValue().AsText();

        // Convert LHDN status values to proper case for display
        case OverallStatus.ToLower() of
            'valid':
                exit('Valid');
            'invalid':
                exit('Invalid');
            'in progress':
                exit('In Progress');
            'partially valid':
                exit('Partially Valid');
            else
                exit(OverallStatus); // Use as-is if unknown
        end;
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
    /// Create a background job for status refresh to avoid context restrictions
    /// </summary>
    local procedure CreateBackgroundJobForStatusRefresh()
    var
        JobQueueEntry: Record "Job Queue Entry";
        JobQueueLogEntry: Record "Job Queue Log Entry";
        LogEntryNo: Integer;
    begin
        // Create job queue entry
        JobQueueEntry.Init();
        JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
        JobQueueEntry."Object ID to Run" := 50312;
        JobQueueEntry."Job Queue Category Code" := 'EINVOICE';
        JobQueueEntry."Description" := 'eInvoice Status Refresh';
        JobQueueEntry."Parameter String" := '';
        JobQueueEntry."User ID" := UserId;
        JobQueueEntry."Earliest Start Date/Time" := CurrentDateTime;
        JobQueueEntry.Status := JobQueueEntry.Status::Ready;
        JobQueueEntry."Maximum No. of Attempts to Run" := 1;
        JobQueueEntry.Insert(true);

        // Log the job creation
        if JobQueueLogEntry.FindLast() then
            LogEntryNo := JobQueueLogEntry."Entry No." + 1
        else
            LogEntryNo := 1;

        JobQueueLogEntry.Init();
        JobQueueLogEntry."Entry No." := LogEntryNo;
        JobQueueLogEntry."Status" := JobQueueLogEntry.Status::Success;
        JobQueueLogEntry."Start Date/Time" := CurrentDateTime;
        JobQueueLogEntry."End Date/Time" := CurrentDateTime;
        JobQueueLogEntry."Object Type to Run" := JobQueueLogEntry."Object Type to Run"::Codeunit;
        JobQueueLogEntry."Object ID to Run" := 50312;
        JobQueueLogEntry."Job Queue Category Code" := 'EINVOICE';
        JobQueueLogEntry."Description" := 'eInvoice Status Refresh - Job Created';
        JobQueueLogEntry.Insert();
    end;
}