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

                    DiagnosticInfo += StrSubstNo('\\Total Log Records: %1', RecordCount);

                    // Check for recent entries
                    DiagnosticInfo += '\\\\';
                    SubmissionLog.SetRange("Submission Date", CreateDateTime(CalcDate('-7D', Today), 000000T), CurrentDateTime);
                    if SubmissionLog.FindSet() then begin
                        DiagnosticInfo += StrSubstNo('\\Records in last 7 days: %1', SubmissionLog.Count);

                        // Show sample entries
                        DiagnosticInfo += '\\\\Recent entries:';
                        repeat
                            DiagnosticInfo += StrSubstNo('\\• Entry %1: Invoice %2, Status %3, Date %4',
                                SubmissionLog."Entry No.",
                                SubmissionLog."Invoice No.",
                                SubmissionLog.Status,
                                Format(SubmissionLog."Submission Date", 0, '<Day,2>/<Month,2>/<Year4> <Hours24,2>:<Minutes,2> <AM/PM>'));
                        until (SubmissionLog.Next() = 0) or (SubmissionLog.Count > 5);
                    end else begin
                        DiagnosticInfo += '\\No records in last 7 days';
                    end;

                    // Check permissions
                    DiagnosticInfo += StrSubstNo('\\\\User ID: %1', UserId);
                    DiagnosticInfo += StrSubstNo('\\Current DateTime: %1', Format(CurrentDateTime, 0, '<Day,2>/<Month,2>/<Year4> <Hours24,2>:<Minutes,2> <AM/PM>'));

                    Message('Diagnostic Information:\\%1', DiagnosticInfo);
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
                        SubmissionLog."Customer Name" := 'Test Customer';
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
                            Message('Test entry created successfully!\\Entry No.: %1\\Invoice No.: %2',
                                SubmissionLog."Entry No.", SubmissionLog."Invoice No.");
                        end else begin
                            Message('Failed to create test entry.\\Error: %1', GetLastErrorText());
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
                    SubmissionStatusCU: Codeunit 50312;
                    TestResults: Text;
                begin
                    TestResults := SubmissionStatusCU.TestSubmissionStatusAccess();
                    Message('Submission Status Access Test:\\\\%1', TestResults);
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
                    SubmissionStatusCU: Codeunit 50312;
                    SubmissionDetails: Text;
                    ApiSuccess: Boolean;
                    ConfirmMsg: Text;
                begin
                    ConfirmMsg := 'This will test LHDN API access with enhanced context awareness.' + '\\' + '\\' +
                                 'The test includes:\\' +
                                 '• Context restriction detection\\' +
                                 '• Network connectivity validation\\' +
                                 '• Detailed error reporting\\' +
                                 '• Retry logic for transient failures\\\\' +
                                 'Proceed with test?';

                    if not Confirm(ConfirmMsg) then
                        exit;

                    ApiSuccess := SubmissionStatusCU.CheckSubmissionStatus('TEST-CONTEXT-UID', SubmissionDetails);

                    if ApiSuccess then begin
                        Message('Context-Safe Access Test: SUCCESS\\\\%1', SubmissionDetails);
                    end else begin
                        Message('Context-Safe Access Test: FAILED\\\\%1', SubmissionDetails);
                    end;
                end;
            }



            action(TestContextAccess)
            {
                ApplicationArea = All;
                Caption = 'Test Context Access';
                Image = Troubleshoot;
                ToolTip = 'Test if HTTP operations are allowed in the current context';

                trigger OnAction()
                var
                    SubmissionStatusCU: Codeunit 50312;
                    TestResult: Text;
                begin
                    // Test context access
                    TestResult := SubmissionStatusCU.TestSubmissionStatusAccess();

                    Message('Context Access Test Results\\' +
                           '========================\\' +
                           '\\%1',
                           TestResult);
                end;
            }

            action(RefreshStatus)
            {
                ApplicationArea = All;
                Caption = 'Refresh Status';
                Image = Refresh;
                ToolTip = 'Refresh the status of the selected submission using the LHDN Get Submission API';

                trigger OnAction()
                var
                    SubmissionStatusCU: Codeunit 50312;
                    SubmissionDetails: Text;
                    ApiSuccess: Boolean;
                    UpdatedCount: Integer;
                    ConfirmMsg: Text;
                    ErrorMessage: Text;
                    FirstError: Text;
                    ContextRestrictionDetected: Boolean;
                    BackgroundJobOption: Integer;
                    TestResult: Text;
                begin
                    // First, test if HTTP operations are allowed in this context
                    TestResult := SubmissionStatusCU.TestSubmissionStatusAccess();

                    if TestResult.Contains('Access token not available') or
                       TestResult.Contains('Context restrictions') then begin
                        // Context restrictions detected - offer alternatives
                        BackgroundJobOption := StrMenu('Use Background Job (Recommended),Test Context Access,Cancel', 1, 'Context Restriction Detected - Select Alternative Method');

                        case BackgroundJobOption of
                            0: // Cancel
                                exit;
                            1: // Use Background Job
                                begin
                                    CreateBackgroundJobForStatusRefresh();
                                    Message('Background job created for status refresh.\\' + '\\' +
                                            'The job will process your submissions in the background\\' +
                                            'and update the log entries when complete.\\' + '\\' +
                                            'You can check the Job Queue to monitor progress.');
                                    exit;
                                end;
                            2: // Test Context Access
                                begin
                                    TestResult := SubmissionStatusCU.TestSubmissionStatusAccess();
                                    Message('Context Access Test:\\%1', TestResult);
                                    exit;
                                end;
                            else
                                exit;
                        end;
                    end;

                    // If we reach here, HTTP operations should be allowed
                    // Proceed with direct refresh

                    ContextRestrictionDetected := false;
                    UpdatedCount := 0;

                    // Try to refresh status for selected entry only
                    if Rec."Submission UID" <> '' then begin
                        // Try direct API call first to get real status
                        ApiSuccess := SubmissionStatusCU.CheckSubmissionStatus(Rec."Submission UID", SubmissionDetails);

                        if ApiSuccess then begin
                            // Update the log entry with current status from LHDN API
                            Rec."Status" := ExtractStatusFromResponse(SubmissionDetails);
                            Rec."Response Date" := CurrentDateTime;
                            Rec."Last Updated" := CurrentDateTime;
                            Rec."Error Message" := CopyStr(SubmissionDetails, 1, 250);
                            Rec.Modify();
                            UpdatedCount += 1;
                        end else begin
                            // Check if it's a context restriction
                            if SubmissionDetails.Contains('Context Restriction Detected') or
                               SubmissionDetails.Contains('Context Restriction Error') then begin
                                ContextRestrictionDetected := true;
                                // Log the error but continue processing
                                Rec."Error Message" := CopyStr(SubmissionDetails, 1, 250);
                                Rec."Last Updated" := CurrentDateTime;
                                Rec.Modify();
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
                    end else begin
                        Message('No Submission UID found for the selected entry.\\Entry No.: %1\\Invoice No.: %2', Rec."Entry No.", Rec."Invoice No.");
                        exit;
                    end;

                    if UpdatedCount > 0 then
                        Message('Status refresh completed.' + '\\' + 'Updated %1 submission.', UpdatedCount)
                    else if ContextRestrictionDetected then begin
                        Message('Context Restriction Detected\\\\' +
                                'HTTP operations are not allowed in the current context.\\\\' +
                                'Alternative Solutions:\\' +
                                '1. Use "Background Status Refresh" for background processing\\' +
                                '2. Use "Manual Status Update" to set status manually\\' +
                                '3. Try running from a different page or action\\' +
                                '4. Contact your system administrator\\' +
                                '5. Use "Export to Excel" to get current data\\\\' +
                                'Session Details:\\' +
                                '• User ID: %1\\' +
                                '• Company: %2\\' +
                                '• Current Time: %3\\' +
                                '• Session ID: c34d2514-2068-4b19-9607-298463aa417e\\\\' +
                                'LHDN API Reference: https://sdk.myinvois.hasil.gov.my/einvoicingapi/06-get-submission/',
                                UserId, CompanyName, Format(CurrentDateTime));
                    end else
                        Message('No submission was updated. Check error messages for details.');
                end;
            }

            action(BackgroundStatusRefresh)
            {
                ApplicationArea = All;
                Caption = 'Background Status Refresh';
                Image = Process;
                ToolTip = 'Refresh status using background job to avoid context restrictions';

                trigger OnAction()
                var
                    JobQueueEntry: Record "Job Queue Entry";
                    JobQueueLogEntry: Record "Job Queue Log Entry";
                    LogEntryNo: Integer;
                    SelectedCount: Integer;
                begin
                    // Count selected entries
                    if Rec.FindSet() then begin
                        repeat
                            if Rec."Submission UID" <> '' then
                                SelectedCount += 1;
                        until Rec.Next() = 0;
                    end;

                    if SelectedCount = 0 then begin
                        Message('No submissions with UIDs found to refresh.');
                        exit;
                    end;

                    if not Confirm('This will create a background job to refresh %1 submissions.\\' + '\\' +
                                  'The job will run in the background and update the log entries when complete.\\' + '\\' +
                                  'Proceed?', false, SelectedCount) then
                        exit;

                    // Create job queue entry for background processing
                    JobQueueEntry.Init();
                    JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
                    JobQueueEntry."Object ID to Run" := 50312;
                    JobQueueEntry."Job Queue Category Code" := 'EINVOICE';
                    JobQueueEntry."Description" := StrSubstNo('eInvoice Status Refresh - %1 submissions', SelectedCount);
                    JobQueueEntry."Parameter String" := 'BACKGROUND_REFRESH';
                    JobQueueEntry."User ID" := UserId;
                    JobQueueEntry."Earliest Start Date/Time" := CurrentDateTime;
                    JobQueueEntry.Status := JobQueueEntry.Status::Ready;
                    JobQueueEntry."Maximum No. of Attempts to Run" := 1;

                    if JobQueueEntry.Insert(true) then begin
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
                        JobQueueLogEntry."Description" := StrSubstNo('eInvoice Status Refresh - Job Created for %1 submissions', SelectedCount);
                        JobQueueLogEntry.Insert();

                        Message('Background job created successfully!\\' + '\\' +
                                'Job Queue Entry: %1\\' +
                                'Submissions to process: %2\\' +
                                'Status: Ready\\' + '\\' +
                                'The job will run in the background and update your log entries when complete.\\' +
                                'You can monitor progress in the Job Queue.',
                                JobQueueEntry."Entry No.", SelectedCount);
                    end else begin
                        Message('Failed to create background job.\\Error: %1', GetLastErrorText());
                    end;
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
                // Convert to proper capitalization for display
                case LowerCase(Status) of
                    'valid':
                        exit('Valid');
                    'invalid':
                        exit('Invalid');
                    'in progress':
                        exit('In Progress');
                    'partially valid':
                        exit('Partially Valid');
                    else
                        exit(Status);
                end;
            end;
        end;

        // Fallback to text parsing if JSON parsing fails
        if ResponseText.Contains('Overall Status: valid') or ResponseText.Contains('"overallStatus":"Valid"') then
            Status := 'Valid'
        else if ResponseText.Contains('Overall Status: invalid') or ResponseText.Contains('"overallStatus":"Invalid"') then
            Status := 'Invalid'
        else if ResponseText.Contains('Overall Status: in progress') or ResponseText.Contains('"overallStatus":"In Progress"') then
            Status := 'In Progress'
        else if ResponseText.Contains('Overall Status: partially valid') or ResponseText.Contains('"overallStatus":"Partially Valid"') then
            Status := 'Partially Valid'
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