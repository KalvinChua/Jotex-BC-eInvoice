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
                ToolTip = 'Refresh the status of the selected submission from LHDN using direct API call';

                trigger OnAction()
                var
                    SubmissionStatusCU: Codeunit "eInvoice Submission Status";
                begin
                    // Validate selection
                    if Rec."Submission UID" = '' then begin
                        Message('Please select a record with a Submission UID to refresh.');
                        exit;
                    end;

                    // Use the same context-safe refresh method as the submission log card
                    // This ensures consistent document-level status extraction
                    if not SubmissionStatusCU.RefreshSubmissionLogStatusSafe(Rec) then begin
                        // If direct method fails due to context restrictions, offer alternatives
                        if Confirm('Context restrictions detected. Create background job for this entry?') then begin
                            // Create background job for this specific entry
                            if SubmissionStatusCU.CreateBackgroundStatusRefreshJob(Rec."Submission UID") then begin
                                Message('Background job created. Check "Background Jobs" for progress.');
                            end else begin
                                Message('Failed to create background job.');
                            end;
                        end else begin
                            // Show alternative options
                            SubmissionStatusCU.RefreshSubmissionLogStatusAlternative(Rec);
                        end;
                    end;

                    CurrPage.Update(false);
                end;
            }
            action(RefreshAllStatuses)
            {
                ApplicationArea = All;
                Caption = 'Refresh All Statuses';
                Image = RefreshLines;
                ToolTip = 'Refresh the status for all submissions with UIDs using direct LHDN API calls with document-level status detection';

                trigger OnAction()
                var
                    SubmissionStatusCU: Codeunit "eInvoice Submission Status";
                    SubmissionLog: Record "eInvoice Submission Log";
                    UpdatedCount: Integer;
                    TotalEntries: Integer;
                    JobQueueEntry: Record "Job Queue Entry";
                begin
                    // Count total entries first
                    SubmissionLog.SetFilter("Submission UID", '<>%1', '');
                    TotalEntries := SubmissionLog.Count();

                    if TotalEntries = 0 then begin
                        Message('No submission entries found with Submission UIDs to refresh.');
                        exit;
                    end;

                    if not Confirm(StrSubstNo('Refresh status for all %1 submissions?', TotalEntries)) then
                        exit;

                    // Use the context-safe bulk refresh method from the submission status codeunit
                    // This ensures consistent document-level status extraction for all entries
                    if SubmissionStatusCU.RefreshAllSubmissionLogStatusesSafe() then begin
                        Message('Bulk refresh completed successfully.');
                    end else begin
                        // Context restrictions detected - automatically create background job
                        Message('Context restrictions detected. Creating background job for bulk refresh...');
                        if CreateBulkRefreshJob() then begin
                            Message('Background job created successfully!\\\\' +
                                   'Expected duration: 5-15 minutes\\\\' +
                                   'You can check progress using the "Check Background Jobs" action.');
                        end else begin
                            Message('Failed to create background job. Please try individual refresh instead.');
                        end;
                    end;

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
                    CsvContent := 'Entry No.,Invoice No.,Customer Name,Submission UID,Document UUID,Status,Submission Date,Response Date,Posting Date,Environment,Error Message' + '\\';

                    if Rec.FindSet() then begin
                        repeat
                            CsvContent += StrSubstNo('%1,%2,%3,%4,%5,%6,%7,%8,%9,%10,%11' + '\\',
                                Rec."Entry No.",
                                Rec."Invoice No.",
                                Rec."Customer Name",
                                Rec."Submission UID",
                                Rec."Document UUID",
                                Rec.Status,
                                Format(Rec."Submission Date"),
                                Format(Rec."Response Date"),
                                Format(Rec."Posting Date"),
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

            action(CheckBackgroundJobs)
            {
                ApplicationArea = All;
                Caption = 'Check Background Jobs';
                Image = JobListSetup;
                ToolTip = 'Check the status of background refresh jobs';

                trigger OnAction()
                var
                    JobQueueEntry: Record "Job Queue Entry";
                    JobStatus: Text;
                    ActiveJobs: Integer;
                    CompletedJobs: Integer;
                    ErrorJobs: Integer;
                begin
                    ActiveJobs := 0;
                    CompletedJobs := 0;
                    ErrorJobs := 0;

                    // Count eInvoice related jobs
                    JobQueueEntry.SetRange("Object ID to Run", Codeunit::"eInvoice Submission Status");
                    if JobQueueEntry.FindSet() then begin
                        repeat
                            case JobQueueEntry.Status of
                                JobQueueEntry.Status::Ready,
                                JobQueueEntry.Status::"In Process":
                                    ActiveJobs += 1;
                                JobQueueEntry.Status::Finished:
                                    CompletedJobs += 1;
                                JobQueueEntry.Status::Error:
                                    ErrorJobs += 1;
                            end;
                        until JobQueueEntry.Next() = 0;
                    end;

                    JobStatus := StrSubstNo('Background Jobs: Active: %1, Completed: %2, Errors: %3',
                                          ActiveJobs, CompletedJobs, ErrorJobs);

                    Message(JobStatus);
                end;
            }

            action(PopulatePostingDates)
            {
                ApplicationArea = All;
                Caption = 'Populate Posting Dates';
                Image = UpdateDescription;
                ToolTip = 'Populate posting dates for existing submission log entries that don''t have posting dates';

                trigger OnAction()
                var
                    PostingDatePopulator: Codeunit "eInvoice Post Date Populator";
                begin
                    if Confirm('This will populate posting dates for existing submission log entries that don''t have posting dates. Continue?') then begin
                        PostingDatePopulator.PopulatePostingDatesForExistingEntries();
                        CurrPage.Update(false);
                    end;
                end;
            }

            action(ShowSubmissionLogStatus)
            {
                ApplicationArea = All;
                Caption = 'Show Log Status';
                Image = Statistics;
                ToolTip = 'Show current status of submission log entries';

                trigger OnAction()
                var
                    PostingDatePopulator: Codeunit "eInvoice Post Date Populator";
                begin
                    PostingDatePopulator.ShowSubmissionLogStatus();
                end;
            }

            action(UpdateDocumentTypes)
            {
                ApplicationArea = All;
                Caption = 'Update Document Types';
                Image = UpdateDescription;
                ToolTip = 'Update document types for existing submission log entries that have empty document types';

                trigger OnAction()
                var
                    SubmissionStatusCU: Codeunit "eInvoice Submission Status";
                    UpdatedCount: Integer;
                begin
                    if Confirm('This will update document types for existing submission log entries that have empty document types. Continue?') then begin
                        UpdatedCount := SubmissionStatusCU.UpdateExistingDocumentTypes();
                        CurrPage.Update(false);
                    end;
                end;
            }

            action(UpdateCustomerNames)
            {
                ApplicationArea = All;
                Caption = 'Update Customer Names';
                Image = UpdateDescription;
                ToolTip = 'Update customer names for existing submission log entries that have empty customer names';

                trigger OnAction()
                var
                    CustomerNameUpgrade: Codeunit "eInvoice Customer Name Upgrade";
                    SubmissionLog: Record "eInvoice Submission Log";
                    Customer: Record Customer;
                    SalesInvoiceHeader: Record "Sales Invoice Header";
                    CustomerName: Text;
                    UpdatedCount: Integer;
                begin
                    if Confirm('This will update customer names for existing submission log entries that have empty customer names. Continue?') then begin
                        UpdatedCount := 0;

                        // Find all submission log entries with empty customer names
                        SubmissionLog.SetRange("Customer Name", '');
                        if SubmissionLog.FindSet() then begin
                            repeat
                                CustomerName := '';

                                // Try to get customer name from the invoice
                                if SalesInvoiceHeader.Get(SubmissionLog."Invoice No.") then begin
                                    if Customer.Get(SalesInvoiceHeader."Sell-to Customer No.") then
                                        CustomerName := Customer.Name;
                                end;

                                // Update the record if we found a customer name
                                if CustomerName <> '' then begin
                                    SubmissionLog."Customer Name" := CustomerName;
                                    SubmissionLog.Modify();
                                    UpdatedCount += 1;
                                end;
                            until SubmissionLog.Next() = 0;
                        end;

                        // Show results to user
                        if UpdatedCount > 0 then
                            Message('Successfully updated Customer Name for %1 existing submission log entries.', UpdatedCount)
                        else
                            Message('No submission log entries with empty Customer Name were found.');

                        CurrPage.Update(false);
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
}