codeunit 50322 "eInvoice Post Date Populator"
{
    Subtype = Normal;

    /// <summary>
    /// Populates posting dates for existing submission log entries that don't have posting dates
    /// This can be run manually to update existing data
    /// </summary>
    procedure PopulatePostingDatesForExistingEntries()
    var
        SubmissionLog: Record "eInvoice Submission Log";
        SalesInvoiceHeader: Record "Sales Invoice Header";
        UpdatedCount: Integer;
        TotalCount: Integer;
        NotFoundCount: Integer;
    begin
        UpdatedCount := 0;
        TotalCount := 0;
        NotFoundCount := 0;

        // Find all submission log entries that don't have posting dates
        SubmissionLog.SetRange("Posting Date", 0D);
        if SubmissionLog.FindSet() then begin
            repeat
                TotalCount += 1;
                // Try to find the corresponding posted sales invoice
                if SalesInvoiceHeader.Get(SubmissionLog."Invoice No.") then begin
                    SubmissionLog."Posting Date" := SalesInvoiceHeader."Posting Date";
                    if SubmissionLog.Modify() then
                        UpdatedCount += 1;
                end else begin
                    NotFoundCount += 1;
                    // Log for debugging
                    Session.LogMessage('0000EIV06', StrSubstNo('eInvoice Post Date Populator: Sales Invoice %1 not found for submission log entry %2',
                        SubmissionLog."Invoice No.", SubmissionLog."Entry No."),
                        Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, '', '');
                end;
            until SubmissionLog.Next() = 0;
        end;

        // Show results to user
        if TotalCount = 0 then begin
            Message('No submission log entries found without posting dates.');
        end else if UpdatedCount > 0 then begin
            Message('Successfully updated posting dates for %1 out of %2 submission log entries.\%3 entries had no corresponding sales invoice.',
                UpdatedCount, TotalCount, NotFoundCount);
            Session.LogMessage('0000EIV05', StrSubstNo('eInvoice Post Date Populator: Updated posting dates for %1 out of %2 submission log entries. %3 entries had no corresponding sales invoice.',
                UpdatedCount, TotalCount, NotFoundCount),
                Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, '', '');
        end else begin
            Message('No posting dates were updated. Found %1 entries without posting dates, but none had corresponding sales invoices.', TotalCount);
        end;
    end;

    /// <summary>
    /// Debug procedure to show current state of submission log entries
    /// </summary>
    procedure ShowSubmissionLogStatus()
    var
        SubmissionLog: Record "eInvoice Submission Log";
        TotalEntries: Integer;
        EntriesWithoutPostingDate: Integer;
        EntriesWithPostingDate: Integer;
    begin
        TotalEntries := SubmissionLog.Count();

        SubmissionLog.SetRange("Posting Date", 0D);
        EntriesWithoutPostingDate := SubmissionLog.Count();

        EntriesWithPostingDate := TotalEntries - EntriesWithoutPostingDate;

        Message('Submission Log Status:\%1 Total entries\%2 Entries with posting date\%3 Entries without posting date',
            TotalEntries, EntriesWithPostingDate, EntriesWithoutPostingDate);
    end;
}
