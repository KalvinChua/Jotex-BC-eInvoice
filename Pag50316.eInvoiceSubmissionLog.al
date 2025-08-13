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
                field("Document Type Description"; Rec."Document Type Description")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the document type description (e.g., Standard Invoice, Credit Note, etc.).';
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
                field("Posting Date"; Rec."Posting Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the posting date of the posted sales invoice.';
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
                field("Cancellation Reason"; Rec."Cancellation Reason")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the reason for cancellation if the document was cancelled.';
                    Visible = Rec.Status = 'Cancelled';
                }
                field("Cancellation Date"; Rec."Cancellation Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the document was cancelled in LHDN.';
                    Visible = Rec.Status = 'Cancelled';
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
                ToolTip = 'Refresh status for the current record or all selected records.';

                trigger OnAction()
                var
                    SubmissionStatusCU: Codeunit "eInvoice Submission Status";
                    SelectedSubmissionLog: Record "eInvoice Submission Log";
                    SelectedCount: Integer;
                    UpdatedCount: Integer;
                    FailedCount: Integer;
                begin
                    // If multiple entries are selected, process them in bulk
                    CurrPage.SetSelectionFilter(SelectedSubmissionLog);
                    SelectedCount := SelectedSubmissionLog.Count();

                    if SelectedCount > 1 then begin
                        // Process only those with Submission UID
                        SelectedSubmissionLog.SetFilter("Submission UID", '<>%1', '');
                        if SelectedSubmissionLog.Count() = 0 then begin
                            Message('None of the selected entries have Submission UIDs. Cannot refresh status.');
                            exit;
                        end;

                        if not Confirm(StrSubstNo('Refresh status for %1 selected submissions?', SelectedSubmissionLog.Count())) then
                            exit;

                        UpdatedCount := 0;
                        FailedCount := 0;
                        if SelectedSubmissionLog.FindSet() then
                            repeat
                                if DirectRefreshSingle(SelectedSubmissionLog) then
                                    UpdatedCount += 1
                                else
                                    FailedCount += 1;
                            until SelectedSubmissionLog.Next() = 0;

                        if FailedCount > 0 then
                            Message('%1 updated. %2 failed (direct API).', UpdatedCount, FailedCount);
                    end else begin
                        // Single record flow
                        if Rec."Submission UID" = '' then begin
                            Message('Please select a record with a Submission UID to refresh.');
                            exit;
                        end;

                        if not DirectRefreshSingle(Rec) then
                            Message('Direct API refresh failed for Submission UID %1.', Rec."Submission UID");
                    end;

                    CurrPage.Update(false);
                end;
            }
            action(RefreshSelectedStatuses)
            {
                ApplicationArea = All;
                Caption = 'Refresh Selected Statuses';
                Image = RefreshRegister;
                ToolTip = 'Refresh the status for selected submissions (use "Refresh Status" instead).';
                Visible = false;
                Enabled = false;

                trigger OnAction()
                var
                    SubmissionStatusCU: Codeunit "eInvoice Submission Status";
                    SelectedSubmissionLog: Record "eInvoice Submission Log";
                    UpdatedCount: Integer;
                    FailedCount: Integer;
                    SelectedCount: Integer;
                    ProcessedCount: Integer;
                begin
                    // Get selected records
                    CurrPage.SetSelectionFilter(SelectedSubmissionLog);
                    SelectedCount := SelectedSubmissionLog.Count();

                    if SelectedCount = 0 then begin
                        Message('Please select one or more submission entries to refresh.');
                        exit;
                    end;

                    // Count how many have Submission UIDs
                    SelectedSubmissionLog.SetFilter("Submission UID", '<>%1', '');
                    ProcessedCount := SelectedSubmissionLog.Count();

                    if ProcessedCount = 0 then begin
                        Message('None of the selected entries have Submission UIDs. Cannot refresh status.');
                        exit;
                    end;

                    if not Confirm(StrSubstNo('Refresh status for %1 selected submissions (out of %2 selected)?', ProcessedCount, SelectedCount)) then
                        exit;

                    UpdatedCount := 0;
                    FailedCount := 0;

                    // Process each selected record
                    if SelectedSubmissionLog.FindSet() then begin
                        repeat
                            if SubmissionStatusCU.RefreshSubmissionLogStatusSafe(SelectedSubmissionLog) then
                                UpdatedCount += 1
                            else
                                FailedCount += 1;
                        until SelectedSubmissionLog.Next() = 0;
                    end;

                    // Handle failures with background job option (no success message)
                    if FailedCount > 0 then begin
                        if Confirm(StrSubstNo('Refreshed %1 submissions successfully, %2 failed due to context restrictions.\Create background jobs for the failed entries?', UpdatedCount, FailedCount)) then begin
                            CreateSelectedBackgroundJobs(SelectedSubmissionLog);
                        end;
                    end;

                    CurrPage.Update(false);
                end;
            }

            action(RefreshByDateRange)
            {
                ApplicationArea = All;
                Caption = 'Refresh by Date Range';
                Image = RefreshLines;
                ToolTip = 'Refresh the status for submissions within a specified date range using direct LHDN API calls';

                trigger OnAction()
                var
                    SubmissionStatusCU: Codeunit "eInvoice Submission Status";
                    SubmissionLog: Record "eInvoice Submission Log";
                    UpdatedCount: Integer;
                    FailedCount: Integer;
                    TotalEntries: Integer;
                    FromDate: Date;
                    ToDate: Date;
                    DateRangeText: Text;
                begin
                    // Let user pick exact dates via dialog, fallback to helper if cancelled
                    if not OpenDateRangeDialog(FromDate, ToDate) then
                        if not GetDateRangeFromUser(FromDate, ToDate) then
                            exit;

                    // Validate date range
                    if FromDate > ToDate then begin
                        Message('From Date cannot be later than To Date.');
                        exit;
                    end;

                    // Count entries in the date range
                    SubmissionLog.SetFilter("Submission UID", '<>%1', '');
                    SubmissionLog.SetRange("Submission Date", CreateDateTime(FromDate, 0T), CreateDateTime(ToDate, 235959T));
                    TotalEntries := SubmissionLog.Count();

                    if TotalEntries = 0 then begin
                        Message('No submission entries found with Submission UIDs in the date range %1 to %2.', Format(FromDate, 0, '<Day,2>/<Month,2>/<Year4>'), Format(ToDate, 0, '<Day,2>/<Month,2>/<Year4>'));
                        exit;
                    end;

                    DateRangeText := StrSubstNo('%1 to %2', Format(FromDate, 0, '<Day,2>/<Month,2>/<Year4>'), Format(ToDate, 0, '<Day,2>/<Month,2>/<Year4>'));
                    // Confirm (extra prompt for large batches)
                    if not Confirm(StrSubstNo('Refresh status for %1 submissions (%2)?', TotalEntries, DateRangeText)) then
                        exit;
                    if (TotalEntries > 200) and not Confirm('This is a large batch and may take some time. Continue?') then
                        exit;

                    // Directly process entries in the date range (no background jobs)
                    UpdatedCount := 0;
                    FailedCount := 0;

                    SubmissionLog.SetFilter("Submission UID", '<>%1', '');
                    SubmissionLog.SetRange("Submission Date", CreateDateTime(FromDate, 0T), CreateDateTime(ToDate, 235959T));

                    if SubmissionLog.FindSet() then begin
                        repeat
                            if DirectRefreshSingle(SubmissionLog) then
                                UpdatedCount += 1
                            else
                                FailedCount += 1;
                            // Light rate-limit buffer
                            Sleep(300);
                        until SubmissionLog.Next() = 0;
                    end;

                    Message('Direct refresh completed for date range %1 to %2. Updated: %3, Failed: %4.',
                            Format(FromDate, 0, '<Day,2>/<Month,2>/<Year4>'),
                            Format(ToDate, 0, '<Day,2>/<Month,2>/<Year4>'),
                            UpdatedCount, FailedCount);

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
                    ExcelBuf: Record "Excel Buffer" temporary;
                    FileName: Text;
                begin
                    // Header row
                    ExcelBuf.Reset();
                    ExcelBuf.DeleteAll();
                    ExcelBuf.NewRow();
                    ExcelBuf.AddColumn('Entry No.', false, '', true, false, false, '', ExcelBuf."Cell Type"::Number);
                    ExcelBuf.AddColumn('Invoice No.', false, '', true, false, false, '', ExcelBuf."Cell Type"::Text);
                    ExcelBuf.AddColumn('Customer Name', false, '', true, false, false, '', ExcelBuf."Cell Type"::Text);
                    ExcelBuf.AddColumn('Submission UID', false, '', true, false, false, '', ExcelBuf."Cell Type"::Text);
                    ExcelBuf.AddColumn('Document UUID', false, '', true, false, false, '', ExcelBuf."Cell Type"::Text);
                    ExcelBuf.AddColumn('Status', false, '', true, false, false, '', ExcelBuf."Cell Type"::Text);
                    ExcelBuf.AddColumn('Submission Date', false, '', true, false, false, '', ExcelBuf."Cell Type"::Date);
                    ExcelBuf.AddColumn('Response Date', false, '', true, false, false, '', ExcelBuf."Cell Type"::Date);
                    ExcelBuf.AddColumn('Posting Date', false, '', true, false, false, '', ExcelBuf."Cell Type"::Date);
                    ExcelBuf.AddColumn('Environment', false, '', true, false, false, '', ExcelBuf."Cell Type"::Text);
                    ExcelBuf.AddColumn('Error Message', false, '', true, false, false, '', ExcelBuf."Cell Type"::Text);

                    // Data rows
                    if Rec.FindSet() then begin
                        repeat
                            ExcelBuf.NewRow();
                            ExcelBuf.AddColumn(Rec."Entry No.", false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
                            ExcelBuf.AddColumn(Rec."Invoice No.", false, '', false, false, false, '', ExcelBuf."Cell Type"::Text);
                            ExcelBuf.AddColumn(Rec."Customer Name", false, '', false, false, false, '', ExcelBuf."Cell Type"::Text);
                            ExcelBuf.AddColumn(Rec."Submission UID", false, '', false, false, false, '', ExcelBuf."Cell Type"::Text);
                            ExcelBuf.AddColumn(Rec."Document UUID", false, '', false, false, false, '', ExcelBuf."Cell Type"::Text);
                            ExcelBuf.AddColumn(Rec.Status, false, '', false, false, false, '', ExcelBuf."Cell Type"::Text);
                            ExcelBuf.AddColumn(DT2Date(Rec."Submission Date"), false, '', false, false, false, '', ExcelBuf."Cell Type"::Date);
                            ExcelBuf.AddColumn(DT2Date(Rec."Response Date"), false, '', false, false, false, '', ExcelBuf."Cell Type"::Date);
                            ExcelBuf.AddColumn(Rec."Posting Date", false, '', false, false, false, '', ExcelBuf."Cell Type"::Date);
                            ExcelBuf.AddColumn(Format(Rec.Environment), false, '', false, false, false, '', ExcelBuf."Cell Type"::Text);
                            ExcelBuf.AddColumn(CopyStr(Rec."Error Message", 1, 250), false, '', false, false, false, '', ExcelBuf."Cell Type"::Text);
                        until Rec.Next() = 0;
                    end;

                    // Build workbook and open
                    FileName := StrSubstNo('eInvoice_Submission_Log_%1.xlsx',
                        Format(CurrentDateTime, 0, '<Year4><Month,2><Day,2><Hours24,2><Minutes,2><Seconds,2>'));
                    ExcelBuf.CreateNewBook('e-Invoice Submission Log');
                    ExcelBuf.WriteSheet('Submission Log', CompanyName, UserId);
                    ExcelBuf.CloseBook();
                    ExcelBuf.SetFriendlyFilename(FileName);
                    ExcelBuf.OpenExcel();
                end;
            }


            action(OpenPostedInvoice)
            {
                ApplicationArea = All;
                Caption = 'Open Posted Invoice';
                Image = Navigate;
                ToolTip = 'Open the related posted sales invoice.';

                trigger OnAction()
                var
                    SIH: Record "Sales Invoice Header";
                begin
                    if SIH.Get(Rec."Invoice No.") then
                        Page.Run(Page::"Posted Sales Invoice", SIH);
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
                    if Confirm('Delete entries older than 30 days?') then begin
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

    /// <summary>
    /// Create a background job for bulk status refresh
    /// </summary>
    local procedure CreateBulkRefreshJob(): Boolean
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        // Create job queue entry for bulk refresh
        JobQueueEntry.Init();
        JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
        JobQueueEntry."Object ID to Run" := Codeunit::"eInvoice Submission Status";
        JobQueueEntry."Job Queue Category Code" := 'EINVOICE';
        JobQueueEntry.Description := 'eInvoice Bulk Status Refresh - All Submissions';
        JobQueueEntry."Parameter String" := 'BULK_REFRESH_ALL'; // Indicates bulk refresh operation
        JobQueueEntry."User ID" := UserId;
        JobQueueEntry."Earliest Start Date/Time" := CurrentDateTime + 5000; // Start in 5 seconds
        JobQueueEntry.Status := JobQueueEntry.Status::Ready;
        JobQueueEntry."Maximum No. of Attempts to Run" := 3;
        JobQueueEntry."Rerun Delay (sec.)" := 30;

        exit(JobQueueEntry.Insert(true));
    end;

    /// <summary>
    /// Create background jobs for selected entries that failed direct refresh
    /// </summary>
    local procedure CreateSelectedBackgroundJobs(var SelectedSubmissionLog: Record "eInvoice Submission Log")
    var
        JobQueueEntry: Record "Job Queue Entry";
        SubmissionStatusCU: Codeunit "eInvoice Submission Status";
        JobsCreated: Integer;
        JobsFailed: Integer;
    begin
        JobsCreated := 0;
        JobsFailed := 0;

        // Create individual background jobs for each selected entry
        if SelectedSubmissionLog.FindSet() then begin
            repeat
                if SelectedSubmissionLog."Submission UID" <> '' then begin
                    if SubmissionStatusCU.CreateBackgroundStatusRefreshJob(SelectedSubmissionLog."Submission UID") then
                        JobsCreated += 1
                    else
                        JobsFailed += 1;
                end;
            until SelectedSubmissionLog.Next() = 0;
        end;

        // Only show message if there were failures creating jobs
        if JobsFailed > 0 then
            Message('Created %1 background jobs successfully, %2 failed.\Check "Background Jobs" for progress.', JobsCreated, JobsFailed);
    end;

    /// <summary>
    /// Get date range from user input with validation
    /// </summary>
    local procedure GetDateRangeFromUser(var FromDate: Date; var ToDate: Date): Boolean
    begin
        // Initialize with empty dates - user will select via date picker
        FromDate := 0D;
        ToDate := 0D;

        // Show date picker options directly
        if not GetDateRangeSimple(FromDate, ToDate) then
            exit(false);

        // Validate the date range
        if FromDate > ToDate then begin
            Message(StrSubstNo('From Date %1 cannot be later than To Date %2.', Format(FromDate, 0, '<Day,2>/<Month,2>/<Year4>'), Format(ToDate, 0, '<Day,2>/<Month,2>/<Year4>')));
            exit(false);
        end;

        // Don't allow future dates for ToDate (but allow for FromDate for planning purposes)
        if ToDate > Today then begin
            Message(StrSubstNo('To Date %1 cannot be in the future. Current date is %2.', Format(ToDate, 0, '<Day,2>/<Month,2>/<Year4>'), Format(Today, 0, '<Day,2>/<Month,2>/<Year4>')));
            exit(false);
        end;

        // Don't allow very old dates (more than 1 year) - but allow future dates for planning
        if (FromDate < CalcDate('-1Y', Today)) and (FromDate < Today) then begin
            if not Confirm(StrSubstNo('From Date %1 is more than 1 year ago. This may include many entries. Continue?', Format(FromDate, 0, '<Day,2>/<Month,2>/<Year4>'))) then
                exit(false);
        end;

        exit(true);
    end;

    local procedure OpenDateRangeDialog(var FromDate: Date; var ToDate: Date): Boolean
    var
        DateDlg: Page "eInv Date Range Picker";
        F: Date;
        T: Date;
    begin
        // Initialize with sensible defaults (last 7 days)
        F := CalcDate('-7D', Today);
        T := Today;
        DateDlg.SetInitialDates(F, T);
        if DateDlg.RunModal() = Action::OK then begin
            DateDlg.GetDates(FromDate, ToDate);
            exit(true);
        end;
        exit(false);
    end;

    /// <summary>
    /// Simple date range selection using predefined options
    /// </summary>
    local procedure GetDateRangeSimple(var FromDate: Date; var ToDate: Date): Boolean
    var
        Selection: Integer;
    begin
        Selection := StrMenu('Today,Single Date,Last 7 days,Last 30 days,Last 90 days,This month,Last month,This year,Custom dates', 3, 'Select date range for refresh:');

        case Selection of
            0:
                exit(false); // User cancelled
            1:
                begin // Today
                    FromDate := Today;
                    ToDate := Today;
                end;
            2:
                begin // Single Date
                    if not GetSingleDateFromUser(FromDate) then
                        exit(false);
                    ToDate := FromDate;
                end;
            3:
                begin // Last 7 days
                    FromDate := CalcDate('-7D', Today);
                    ToDate := Today;
                end;
            4:
                begin // Last 30 days
                    FromDate := CalcDate('-30D', Today);
                    ToDate := Today;
                end;
            5:
                begin // Last 90 days
                    FromDate := CalcDate('-90D', Today);
                    ToDate := Today;
                end;
            6:
                begin // This month
                    FromDate := CalcDate('-CM', Today);
                    ToDate := Today;
                end;
            7:
                begin // Last month
                    FromDate := CalcDate('-1M-CM', Today);
                    ToDate := CalcDate('-1M+CM', Today);
                end;
            8:
                begin // This year
                    FromDate := CalcDate('-CY', Today);
                    ToDate := Today;
                end;
            9:
                begin // Custom dates - use date picker
                    if not GetCustomDateRangeWithPicker(FromDate, ToDate) then
                        exit(false);
                end;
        end;

        exit(true);
    end;

    /// <summary>
    /// Get a single date from user input using a simple date picker approach
    /// </summary>
    local procedure GetSingleDateFromUser(var SelectedDate: Date): Boolean
    var
        DateSelection: Integer;
        SelectedDateText: Text;
        ParsedDate: Date;
    begin
        // Show a simple date picker with common options
        DateSelection := StrMenu('Today,Yesterday,Last Week,Last Month,Last Year,Other', 1, 'Select a date:');

        case DateSelection of
            0:
                exit(false); // User cancelled
            1:
                SelectedDate := Today; // Today
            2:
                SelectedDate := CalcDate('-1D', Today); // Yesterday
            3:
                SelectedDate := CalcDate('-7D', Today); // Last Week
            4:
                SelectedDate := CalcDate('-1M', Today); // Last Month
            5:
                SelectedDate := CalcDate('-1Y', Today); // Last Year
            6:
                begin // Other - use a simple date input approach
                    SelectedDateText := Format(Today, 0, '<Day,2>/<Month,2>/<Year4>');

                    // For now, use a simple confirmation approach since we can't easily get user input
                    if not Confirm(StrSubstNo('Use %1 as the selected date?\Click No to cancel.', Format(Today, 0, '<Day,2>/<Month,2>/<Year4>'))) then
                        exit(false);

                    SelectedDate := Today;
                end;
        end;

        // Validate the selected date
        if SelectedDate > Today then begin
            Message('Selected date cannot be in the future.');
            exit(false);
        end;

        if SelectedDate < CalcDate('-1Y', Today) then begin
            if not Confirm('Selected date is more than 1 year ago. This may include many entries. Continue?') then
                exit(false);
        end;

        exit(true);
    end;

    /// <summary>
    /// Get custom date range using enhanced date picker options
    /// </summary>
    local procedure GetCustomDateRangeWithPicker(var FromDate: Date; var ToDate: Date): Boolean
    var
        DateRangeSelection: Integer;
        TempFromDate: Date;
        TempToDate: Date;
    begin
        // Show enhanced custom date range options
        DateRangeSelection := StrMenu('Last 7 days,Last 14 days,Last 30 days,Last 60 days,Last 90 days,Last 6 months,Last year,This week,This month,This quarter,This year,Other', 3, 'Select custom date range:');

        case DateRangeSelection of
            0:
                exit(false); // User cancelled
            1:
                begin // Last 7 days
                    FromDate := CalcDate('-7D', Today);
                    ToDate := Today;
                end;
            2:
                begin // Last 14 days
                    FromDate := CalcDate('-14D', Today);
                    ToDate := Today;
                end;
            3:
                begin // Last 30 days
                    FromDate := CalcDate('-30D', Today);
                    ToDate := Today;
                end;
            4:
                begin // Last 60 days
                    FromDate := CalcDate('-60D', Today);
                    ToDate := Today;
                end;
            5:
                begin // Last 90 days
                    FromDate := CalcDate('-90D', Today);
                    ToDate := Today;
                end;
            6:
                begin // Last 6 months
                    FromDate := CalcDate('-6M', Today);
                    ToDate := Today;
                end;
            7:
                begin // Last year
                    FromDate := CalcDate('-1Y', Today);
                    ToDate := Today;
                end;
            8:
                begin // This week
                    FromDate := CalcDate('-CW', Today);
                    ToDate := Today;
                end;
            9:
                begin // This month
                    FromDate := CalcDate('-CM', Today);
                    ToDate := Today;
                end;
            10:
                begin // This quarter
                    FromDate := CalcDate('-CQ', Today);
                    ToDate := Today;
                end;
            11:
                begin // This year
                    FromDate := CalcDate('-CY', Today);
                    ToDate := Today;
                end;
            12:
                begin // Other - use current page filters
                    if Rec.GetFilter("Submission Date") <> '' then begin
                        if Confirm('Use the current Submission Date filter as the date range?') then begin
                            exit(true); // Keep current FromDate and ToDate
                        end;
                    end;

                    // Fallback to simple date input
                    Message('For specific custom dates, please:\1. Use the filter on "Submission Date" column\2. Set your desired date range filter\3. Then run "Refresh by Date Range" again and select "Custom dates"');
                    exit(false);
                end;
        end;

        exit(true);
    end;



    /// <summary>
    /// Create background job for date range refresh
    /// </summary>
    local procedure CreateDateRangeBackgroundJob(FromDate: Date; ToDate: Date): Boolean
    var
        JobQueueEntry: Record "Job Queue Entry";
        ParameterString: Text;
    begin
        // Create parameter string with date range
        ParameterString := StrSubstNo('DATE_RANGE|%1|%2', Format(FromDate), Format(ToDate));

        // Create job queue entry for date range refresh
        JobQueueEntry.Init();
        JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
        JobQueueEntry."Object ID to Run" := Codeunit::"eInvoice Submission Status";
        JobQueueEntry."Job Queue Category Code" := 'EINVOICE';
        JobQueueEntry.Description := StrSubstNo('eInvoice Status Refresh - Date Range %1 to %2', FromDate, ToDate);
        JobQueueEntry."Parameter String" := ParameterString;
        JobQueueEntry."User ID" := UserId;
        JobQueueEntry."Earliest Start Date/Time" := CurrentDateTime + 5000; // Start in 5 seconds
        JobQueueEntry.Status := JobQueueEntry.Status::Ready;
        JobQueueEntry."Maximum No. of Attempts to Run" := 3;
        JobQueueEntry."Rerun Delay (sec.)" := 30;

        if JobQueueEntry.Insert(true) then begin
            exit(true);
        end else begin
            Message('Failed to create background job for date range refresh.');
            exit(false);
        end;
    end;

    local procedure SendDateRangeSummaryNotification(FromDate: Date; ToDate: Date; TotalEntries: Integer; UpdatedCount: Integer; FailedCount: Integer)
    var
        Notif: Notification;
        Msg: Text;
    begin
        Msg := StrSubstNo('Date range %1 to %2 | Total: %3 | Updated: %4 | Failed: %5',
            Format(FromDate, 0, '<Day,2>/<Month,2>/<Year4>'),
            Format(ToDate, 0, '<Day,2>/<Month,2>/<Year4>'),
            TotalEntries,
            UpdatedCount,
            FailedCount);

        Notif.Scope := NotificationScope::LocalScope;
        Notif.Message(Msg);
        Notif.Send();
    end;

    /// <summary>
    /// Direct refresh using the same approach as Posted Sales Invoice page
    /// </summary>
    local procedure DirectRefreshSingle(var Entry: Record "eInvoice Submission Log"): Boolean
    var
        HttpClient: HttpClient;
        HttpRequestMessage: HttpRequestMessage;
        HttpResponseMessage: HttpResponseMessage;
        RequestHeaders: HttpHeaders;
        eInvoiceSetup: Record "eInvoiceSetup";
        eInvoiceHelper: Codeunit eInvoiceHelper;
        AccessToken: Text;
        ApiUrl: Text;
        ResponseText: Text;
        StatusText: Text;
        LhdnStatus: Text;
    begin
        if Entry."Submission UID" = '' then
            exit(false);

        if not eInvoiceSetup.Get('SETUP') then
            exit(false);

        eInvoiceHelper.InitializeHelper();
        AccessToken := eInvoiceHelper.GetAccessTokenFromSetup(eInvoiceSetup);
        if AccessToken = '' then
            exit(false);

        if eInvoiceSetup.Environment = eInvoiceSetup.Environment::Preprod then
            ApiUrl := StrSubstNo('https://preprod-api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions/%1', Entry."Submission UID")
        else
            ApiUrl := StrSubstNo('https://api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions/%1', Entry."Submission UID");

        HttpRequestMessage.Method := 'GET';
        HttpRequestMessage.SetRequestUri(ApiUrl);
        HttpRequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Clear();
        RequestHeaders.Add('Accept', 'application/json');
        RequestHeaders.Add('Accept-Language', 'en');
        RequestHeaders.Add('Authorization', 'Bearer ' + AccessToken);

        if HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then begin
            HttpResponseMessage.Content.ReadAs(ResponseText);
            if HttpResponseMessage.IsSuccessStatusCode then begin
                // Parse status like posted pages
                LhdnStatus := ExtractStatusFromApiResponse(ResponseText, Entry."Document UUID");
                Entry.Status := LhdnStatus;
                Entry."Response Date" := CurrentDateTime;
                Entry."Last Updated" := CurrentDateTime;
                Entry."Error Message" := CopyStr('Status refreshed from LHDN via direct API (Submission Log).', 1, MaxStrLen(Entry."Error Message"));
                Entry.Modify();
                exit(true);
            end;
        end;
        exit(false);
    end;

    local procedure ExtractStatusFromApiResponse(ResponseText: Text; DocumentUuid: Text): Text
    var
        JsonObject: JsonObject;
        JsonToken: JsonToken;
        DocumentSummaryArray: JsonArray;
        DocumentJson: JsonObject;
        OverallStatus: Text;
        DocumentStatus: Text;
        PickedUuid: Text;
        i: Integer;
    begin
        if not JsonObject.ReadFrom(ResponseText) then
            exit('Unknown');

        if JsonObject.Get('documentSummary', JsonToken) and JsonToken.IsArray() then begin
            DocumentSummaryArray := JsonToken.AsArray();
            for i := 0 to DocumentSummaryArray.Count() - 1 do begin
                DocumentSummaryArray.Get(i, JsonToken);
                if JsonToken.IsObject() then begin
                    DocumentJson := JsonToken.AsObject();
                    if DocumentJson.Get('uuid', JsonToken) then
                        PickedUuid := JsonToken.AsValue().AsText();
                    if (DocumentUuid <> '') and (PickedUuid = DocumentUuid) then
                        if DocumentJson.Get('status', JsonToken) then begin
                            DocumentStatus := JsonToken.AsValue().AsText();
                            exit(NormalizeStatus(DocumentStatus));
                        end;
                end;
            end;
        end;

        if JsonObject.Get('overallStatus', JsonToken) then
            OverallStatus := JsonToken.AsValue().AsText();
        exit(NormalizeStatus(OverallStatus));
    end;

    local procedure NormalizeStatus(StatusValue: Text): Text
    begin
        case LowerCase(StatusValue) of
            'valid':
                exit('Valid');
            'invalid':
                exit('Invalid');
            'in progress':
                exit('In Progress');
            'partially valid':
                exit('Partially Valid');
            'cancelled':
                exit('Cancelled');
            'rejected':
                exit('Rejected');
            else
                exit(StatusValue);
        end;
    end;
}