codeunit 50326 "eInvoice Submission Log Update"
{
    Subtype = Normal;
    Permissions = tabledata "eInvoice Submission Log" = M;

    /// <summary>
    /// Updates Customer No. field for all existing submission log entries
    /// that have empty Customer No. but have an Invoice No.
    /// </summary>
    procedure UpdateCustomerNoInSubmissionLog()
    var
        SubmissionLog: Record "eInvoice Submission Log";
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        UpdatedCount: Integer;
        TotalCount: Integer;
        NotFoundCount: Integer;
    begin
        UpdatedCount := 0;
        TotalCount := 0;
        NotFoundCount := 0;

        // Find all submission log entries with empty Customer No.
        SubmissionLog.SetRange("Customer No.", '');
        if SubmissionLog.FindSet(true) then begin
            repeat
                TotalCount += 1;

                // Try to find the invoice first
                if SalesInvoiceHeader.Get(SubmissionLog."Invoice No.") then begin
                    SubmissionLog."Customer No." := SalesInvoiceHeader."Sell-to Customer No.";
                    if SubmissionLog.Modify(true) then
                        UpdatedCount += 1;
                end
                // If not a sales invoice, try credit memo
                else if SalesCrMemoHeader.Get(SubmissionLog."Invoice No.") then begin
                    SubmissionLog."Customer No." := SalesCrMemoHeader."Sell-to Customer No.";
                    if SubmissionLog.Modify(true) then
                        UpdatedCount += 1;
                end else begin
                    NotFoundCount += 1;
                    Session.LogMessage('0000EIV10', StrSubstNo('eInvoice Submission Log Update: Could not find invoice or credit memo %1 for submission log entry %2',
                        SubmissionLog."Invoice No.", SubmissionLog."Entry No."),
                        Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, '', '');
                end;
            until SubmissionLog.Next() = 0;
        end;

        // Show results to user
        if TotalCount = 0 then begin
            Message('No submission log entries found with empty Customer No.');
        end else begin
            Message('Submission Log Customer No. update completed!\\\\' +
                   'Total entries with empty Customer No.: %1\\' +
                   'Successfully updated: %2\\' +
                   'Invoice/Credit Memo not found: %3',
                   TotalCount, UpdatedCount, NotFoundCount);

            Session.LogMessage('0000EIV09', StrSubstNo('eInvoice Submission Log Update: Updated Customer No. for %1 out of %2 submission log entries. %3 entries had no corresponding invoice.',
                UpdatedCount, TotalCount, NotFoundCount),
                Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, '', '');
        end;
    end;

    /// <summary>
    /// Shows current status of Customer No. population in submission log
    /// </summary>
    procedure ShowSubmissionLogCustomerNoStatus()
    var
        SubmissionLog: Record "eInvoice Submission Log";
        TotalEntries: Integer;
        WithCustomerNo: Integer;
        WithoutCustomerNo: Integer;
    begin
        TotalEntries := SubmissionLog.Count();

        SubmissionLog.SetFilter("Customer No.", '<>%1', '');
        WithCustomerNo := SubmissionLog.Count();

        WithoutCustomerNo := TotalEntries - WithCustomerNo;

        Message('Submission Log Customer No. Status:\\\\' +
               'Total entries: %1\\' +
               'Entries with Customer No.: %2\\' +
               'Entries without Customer No.: %3',
               TotalEntries, WithCustomerNo, WithoutCustomerNo);
    end;

    /// <summary>
    /// Diagnostic procedure to check a specific submission log entry
    /// </summary>
    procedure DiagnoseSubmissionLogEntry(EntryNo: Integer)
    var
        SubmissionLog: Record "eInvoice Submission Log";
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        DiagMsg: Text;
    begin
        if not SubmissionLog.Get(EntryNo) then begin
            Message('Submission log entry %1 not found.', EntryNo);
            exit;
        end;

        DiagMsg := StrSubstNo('Submission Log Entry %1:\\', EntryNo);
        DiagMsg += StrSubstNo('Invoice No.: %1\\', SubmissionLog."Invoice No.");
        DiagMsg += StrSubstNo('Customer No.: %1\\', SubmissionLog."Customer No.");
        DiagMsg += StrSubstNo('Customer Name: %1\\\\', SubmissionLog."Customer Name");

        if SalesInvoiceHeader.Get(SubmissionLog."Invoice No.") then begin
            DiagMsg += StrSubstNo('✓ Sales Invoice found: %1\\', SalesInvoiceHeader."No.");
            DiagMsg += StrSubstNo('  Sell-to Customer No.: %1\\', SalesInvoiceHeader."Sell-to Customer No.");
            DiagMsg += StrSubstNo('  Sell-to Customer Name: %1\\', SalesInvoiceHeader."Sell-to Customer Name");
        end else if SalesCrMemoHeader.Get(SubmissionLog."Invoice No.") then begin
            DiagMsg += StrSubstNo('✓ Credit Memo found: %1\\', SalesCrMemoHeader."No.");
            DiagMsg += StrSubstNo('  Sell-to Customer No.: %1\\', SalesCrMemoHeader."Sell-to Customer No.");
            DiagMsg += StrSubstNo('  Sell-to Customer Name: %1\\', SalesCrMemoHeader."Sell-to Customer Name");
        end else begin
            DiagMsg += '✗ No Sales Invoice or Credit Memo found with this number';
        end;

        Message(DiagMsg);
    end;
}
