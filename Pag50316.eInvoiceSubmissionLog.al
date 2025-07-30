page 50316 "e-Invoice Submission Log"
{
    PageType = List;
    SourceTable = "eInvoice Submission Log";
    Caption = 'e-Invoice Submission Log';
    UsageCategory = Lists;
    ApplicationArea = All;
    CardPageId = "e-Invoice Submission Log Card";

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
            action(DiagnoseEmptyLog)
            {
                ApplicationArea = All;
                Caption = 'Diagnose Empty Log';
                Image = Troubleshoot;
                ToolTip = 'Diagnose why the submission log appears empty';

                trigger OnAction()
                var
                    SubmissionLog: Record "eInvoice Submission Log";
                    CompanyInfo: Record "Company Information";
                    RecordCount: Integer;
                    DiagnosticInfo: Text;
                begin
                    // Check if we're in the correct company
                    if CompanyInfo.Get() then
                        DiagnosticInfo := StrSubstNo('Company: %1', CompanyInfo.Name)
                    else
                        DiagnosticInfo := 'Company: Not found';

                    // Count total records
                    if SubmissionLog.FindSet() then begin
                        repeat
                            RecordCount += 1;
                        until SubmissionLog.Next() = 0;
                    end;

                    DiagnosticInfo += StrSubstNo('\nTotal Log Records: %1', RecordCount);

                    // Check for recent entries
                    SubmissionLog.SetRange("Submission Date", CreateDateTime(CalcDate('-7D', Today), 000000T), CurrentDateTime);
                    if SubmissionLog.FindSet() then begin
                        DiagnosticInfo += StrSubstNo('\nRecords in last 7 days: %1', SubmissionLog.Count);

                        // Show sample entries
                        DiagnosticInfo += '\n\nRecent entries:';
                        repeat
                            DiagnosticInfo += StrSubstNo('\n- Entry %1: Invoice %2, Status %3, Date %4',
                                SubmissionLog."Entry No.",
                                SubmissionLog."Invoice No.",
                                SubmissionLog.Status,
                                Format(SubmissionLog."Submission Date"));
                        until (SubmissionLog.Next() = 0) or (SubmissionLog.Count > 5);
                    end else begin
                        DiagnosticInfo += '\nNo records in last 7 days';
                    end;

                    // Check permissions
                    DiagnosticInfo += StrSubstNo('\n\nUser ID: %1', UserId);
                    DiagnosticInfo += StrSubstNo('\nCurrent DateTime: %1', Format(CurrentDateTime));

                    Message('Diagnostic Information:\n%1', DiagnosticInfo);
                end;
            }

            action(CreateTestEntry)
            {
                ApplicationArea = All;
                Caption = 'Create Test Entry';
                Image = Create;
                ToolTip = 'Create a test entry in the submission log for testing purposes';

                trigger OnAction()
                var
                    SubmissionLog: Record "eInvoice Submission Log";
                    eInvoiceSetup: Record "eInvoiceSetup";
                begin
                    if Confirm('This will create a test entry in the submission log. Continue?') then begin
                        // Create test log entry
                        SubmissionLog.Init();
                        SubmissionLog."Entry No." := 0; // Auto-increment
                        SubmissionLog."Invoice No." := 'TEST-INV-001';
                        SubmissionLog."Submission UID" := CleanQuotesFromText('TEST-SUB-UID-' + Format(CurrentDateTime, 0, '<Year4><Month,2><Day,2><Hours24,2><Minutes,2><Seconds,2>'));
                        SubmissionLog."Document UUID" := CleanQuotesFromText('TEST-DOC-UUID-' + Format(CurrentDateTime, 0, '<Year4><Month,2><Day,2><Hours24,2><Minutes,2><Seconds,2>'));
                        SubmissionLog.Status := 'Test Status';
                        SubmissionLog."Submission Date" := CurrentDateTime;
                        SubmissionLog."Response Date" := CurrentDateTime;
                        SubmissionLog."Last Updated" := CurrentDateTime;
                        SubmissionLog."User ID" := UserId;
                        SubmissionLog."Company Name" := CompanyName;
                        SubmissionLog."Error Message" := '';

                        // Set environment based on setup
                        if eInvoiceSetup.Get('SETUP') then
                            SubmissionLog.Environment := eInvoiceSetup.Environment
                        else
                            SubmissionLog.Environment := SubmissionLog.Environment::Preprod;

                        // Insert the log entry
                        if SubmissionLog.Insert() then begin
                            Message('Test entry created successfully!\nEntry No.: %1\nInvoice No.: %2',
                                SubmissionLog."Entry No.", SubmissionLog."Invoice No.");
                        end else begin
                            Message('Failed to create test entry.\nError: %1', GetLastErrorText());
                        end;
                    end;
                end;
            }

            action(TestSubmissionAccess)
            {
                ApplicationArea = All;
                Caption = 'Test Submission Access';
                Image = Troubleshoot;
                ToolTip = 'Test submission status access and permissions';

                trigger OnAction()
                var
                    SubmissionStatusCU: Codeunit "eInvoice Submission Status";
                    TestResults: Text;
                begin
                    TestResults := SubmissionStatusCU.TestSubmissionStatusAccess();
                    Message('Submission Status Access Test:\n\n%1', TestResults);
                end;
            }

            action(TestSimpleAccess)
            {
                ApplicationArea = All;
                Caption = 'Test Simple Access';
                Image = Troubleshoot;
                ToolTip = 'Test basic access without HTTP operations';

                trigger OnAction()
                var
                    SubmissionStatusCU: Codeunit "eInvoice Submission Status";
                    TestResults: Text;
                    ApiSuccess: Boolean;
                begin
                    ApiSuccess := SubmissionStatusCU.TestSubmissionStatusSimple('TEST-UID', TestResults);
                    Message('Simple Access Test:\n\n%1\n\nAPI Success: %2', TestResults, Format(ApiSuccess));
                end;
            }

            action(TestContextSafeAccess)
            {
                ApplicationArea = All;
                Caption = 'Test Context-Safe Access';
                Image = Troubleshoot;
                ToolTip = 'Test access with context-aware error handling';

                trigger OnAction()
                var
                    SubmissionStatusCU: Codeunit "eInvoice Submission Status";
                    SubmissionDetails: Text;
                    ApiSuccess: Boolean;
                    ConfirmMsg: Text;
                begin
                    ConfirmMsg := 'This will test LHDN API access with enhanced context awareness.' + '\\' + '\\' +
                                 'The test includes:\n' +
                                 '• Context restriction detection\n' +
                                 '• Network connectivity validation\n' +
                                 '• Detailed error reporting\n' +
                                 '• Retry logic for transient failures\n\n' +
                                 'Proceed with test?';

                    if not Confirm(ConfirmMsg) then
                        exit;

                    ApiSuccess := SubmissionStatusCU.CheckSubmissionStatus('TEST-CONTEXT-UID', SubmissionDetails);

                    if ApiSuccess then begin
                        Message('Context-Safe Access Test: SUCCESS\n\n%1', SubmissionDetails);
                    end else begin
                        Message('Context-Safe Access Test: FAILED\n\n%1', SubmissionDetails);
                    end;
                end;
            }

            action(RefreshStatus)
            {
                ApplicationArea = All;
                Caption = 'Refresh Status';
                Image = Refresh;
                ToolTip = 'Refresh the status of selected submissions using the LHDN Get Submission API';

                trigger OnAction()
                var
                    SubmissionStatusCU: Codeunit "eInvoice Submission Status";
                    SubmissionDetails: Text;
                    ApiSuccess: Boolean;
                    UpdatedCount: Integer;
                    ConfirmMsg: Text;
                    ErrorMessage: Text;
                    FirstError: Text;
                begin
                    ConfirmMsg := 'This will refresh the status of all selected submissions using the LHDN Get Submission API.' + '\\' + '\\' +
                                 'Note: LHDN recommends 3-5 second intervals between requests to avoid system throttling.' + '\\' + '\\' +
                                 'Proceed?';

                    if not Confirm(ConfirmMsg) then
                        exit;

                    // Try to refresh statuses directly
                    if Rec.FindSet() then begin
                        repeat
                            if Rec."Submission UID" <> '' then begin
                                ApiSuccess := SubmissionStatusCU.CheckSubmissionStatus(Rec."Submission UID", SubmissionDetails);

                                if ApiSuccess then begin
                                    // Update the log entry with current status
                                    Rec."Status" := ExtractStatusFromResponse(SubmissionDetails);
                                    Rec."Response Date" := CurrentDateTime;
                                    Rec."Last Updated" := CurrentDateTime;
                                    Rec.Modify();
                                    UpdatedCount += 1;
                                end else begin
                                    // Log the error but continue processing
                                    Rec."Error Message" := CopyStr(SubmissionDetails, 1, 250);
                                    Rec."Last Updated" := CurrentDateTime;
                                    Rec.Modify();

                                    // Capture first error for context restriction detection
                                    if FirstError = '' then
                                        FirstError := SubmissionDetails;
                                end;
                            end;
                        until Rec.Next() = 0;

                        if UpdatedCount > 0 then
                            Message('Status refresh completed.' + '\\' + 'Updated %1 submissions.', UpdatedCount)
                        else if FirstError.Contains('cannot be performed in this context') then begin
                            Message('Context Restriction Detected\n\n' +
                                    'HTTP operations are not allowed in the current context.\n\n' +
                                    'Alternative Solutions:\n' +
                                    '1. Use "Manual Status Update" to set status manually\n' +
                                    '2. Try running from a different page or action\n' +
                                    '3. Contact your system administrator\n' +
                                    '4. Use "Export to Excel" to get current data\n\n' +
                                    'Session Details:\n' +
                                    '• User ID: %1\n' +
                                    '• Company: %2\n' +
                                    '• Current Time: %3',
                                    UserId, CompanyName, Format(CurrentDateTime));
                        end else
                            Message('No submissions were updated. Check error messages for details.');
                    end else
                        Message('No log entries found to refresh.');
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
                    CsvContent := 'Entry No.,Invoice No.,Submission UID,Document UUID,Status,Submission Date,Response Date,Environment,Error Message' + '\\';

                    if Rec.FindSet() then begin
                        repeat
                            CsvContent += StrSubstNo('%1,%2,%3,%4,%5,%6,%7,%8,%9' + '\\',
                                Rec."Entry No.",
                                Rec."Invoice No.",
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

            action(ManualStatusUpdate)
            {
                ApplicationArea = All;
                Caption = 'Manual Status Update';
                Image = Edit;
                ToolTip = 'Manually update status when HTTP operations are blocked';

                trigger OnAction()
                var
                    StatusOptions: Text;
                    SelectedStatus: Integer;
                    StatusText: Text;
                    UpdatedCount: Integer;
                begin
                    StatusOptions := 'valid,invalid,in progress,partially valid,Unknown';
                    SelectedStatus := StrMenu(StatusOptions, 1, 'Select Status to Apply');

                    if SelectedStatus = 0 then
                        exit;

                    // Convert selection to status text (using official LHDN API values)
                    case SelectedStatus of
                        1:
                            StatusText := 'valid';
                        2:
                            StatusText := 'invalid';
                        3:
                            StatusText := 'in progress';
                        4:
                            StatusText := 'partially valid';
                        5:
                            StatusText := 'Unknown';
                        else
                            StatusText := 'Unknown';
                    end;

                    UpdatedCount := 0;

                    if Rec.FindSet() then begin
                        repeat
                            if Rec."Submission UID" <> '' then begin
                                Rec."Status" := StatusText;
                                Rec."Response Date" := CurrentDateTime;
                                Rec."Last Updated" := CurrentDateTime;
                                Rec."Error Message" := 'Manually updated - HTTP operations blocked';
                                Rec.Modify();
                                UpdatedCount += 1;
                            end;
                        until Rec.Next() = 0;

                        Message('Manual status update completed.' + '\\' + 'Updated %1 submissions with status: %2', UpdatedCount, StatusText);
                    end else
                        Message('No log entries found to update.');
                end;
            }
        }
    }

    local procedure ExtractStatusFromResponse(ResponseText: Text): Text
    var
        Status: Text;
        JsonObject: JsonObject;
        JsonToken: JsonToken;
    begin
        // Try to parse JSON response first for more accurate status extraction
        if JsonObject.ReadFrom(ResponseText) then begin
            if JsonObject.Get('overallStatus', JsonToken) then begin
                Status := JsonToken.AsValue().AsText();
                // Return the official LHDN API status value directly
                exit(Status);
            end;
        end;

        // Fallback to text parsing if JSON parsing fails
        if ResponseText.Contains('Overall Status: valid') then
            Status := 'valid'
        else if ResponseText.Contains('Overall Status: invalid') then
            Status := 'invalid'
        else if ResponseText.Contains('Overall Status: in progress') then
            Status := 'in progress'
        else if ResponseText.Contains('Overall Status: partially valid') then
            Status := 'partially valid'
        else
            Status := 'Unknown';

        exit(Status);
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
        JobQueueEntry."Object ID to Run" := Codeunit::"eInvoice Submission Status";
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
        JobQueueLogEntry."Object ID to Run" := Codeunit::"eInvoice Submission Status";
        JobQueueLogEntry."Job Queue Category Code" := 'EINVOICE';
        JobQueueLogEntry."Description" := 'eInvoice Status Refresh - Job Created';
        JobQueueLogEntry.Insert();
    end;


}