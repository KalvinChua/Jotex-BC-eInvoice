codeunit 50321 "eInvoice Data Upgrade"
{
    Subtype = Upgrade;

    trigger OnUpgradePerCompany()
    begin
        PopulatePostingDatesForExistingEntries();
    end;

    /// <summary>
    /// Populates posting dates for existing submission log entries that don't have posting dates
    /// </summary>
    local procedure PopulatePostingDatesForExistingEntries()
    var
        SubmissionLog: Record "eInvoice Submission Log";
        SalesInvoiceHeader: Record "Sales Invoice Header";
        UpdatedCount: Integer;
    begin
        UpdatedCount := 0;

        // Find all submission log entries that don't have posting dates
        SubmissionLog.SetRange("Posting Date", 0D);
        if SubmissionLog.FindSet() then begin
            repeat
                // Try to find the corresponding posted sales invoice
                if SalesInvoiceHeader.Get(SubmissionLog."Invoice No.") then begin
                    SubmissionLog."Posting Date" := SalesInvoiceHeader."Posting Date";
                    if SubmissionLog.Modify() then
                        UpdatedCount += 1;
                end;
            until SubmissionLog.Next() = 0;
        end;

        // Log the upgrade results
        if UpdatedCount > 0 then
            Session.LogMessage('0000EIV04', StrSubstNo('eInvoice Data Upgrade: Updated posting dates for %1 submission log entries', UpdatedCount),
                Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, '', '');
    end;
}
