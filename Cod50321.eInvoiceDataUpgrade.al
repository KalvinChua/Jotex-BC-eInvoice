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

    /// <summary>
    /// Populate eInvoiceTypes table with standard LHDN document type codes
    /// </summary>
    procedure PopulateEInvoiceTypes()
    var
        EInvoiceTypes: Record eInvoiceTypes;
    begin
        // Clear existing data first
        if EInvoiceTypes.FindSet() then
            EInvoiceTypes.DeleteAll();

        // Insert standard LHDN document types
        InsertEInvoiceType('01', 'Standard Invoice');
        InsertEInvoiceType('02', 'Credit Note');
        InsertEInvoiceType('03', 'Debit Note');
        InsertEInvoiceType('04', 'Return Order');
        InsertEInvoiceType('05', 'Refund Note');
        InsertEInvoiceType('06', 'Self-Billed Invoice');
        InsertEInvoiceType('07', 'Self-Billed Credit Note');
        InsertEInvoiceType('08', 'Self-Billed Debit Note');
        InsertEInvoiceType('09', 'Consolidated Invoice');
        InsertEInvoiceType('10', 'Consolidated Credit Note');

        Message('eInvoice Types populated successfully with %1 document types.', EInvoiceTypes.Count());
    end;

    /// <summary>
    /// Insert a single eInvoice type record
    /// </summary>
    /// <param name="Code">Document type code</param>
    /// <param name="Description">Document type description</param>
    local procedure InsertEInvoiceType(Code: Code[20]; Description: Text[100])
    var
        EInvoiceTypes: Record eInvoiceTypes;
    begin
        EInvoiceTypes.Init();
        EInvoiceTypes.Code := Code;
        EInvoiceTypes.Description := Description;
        EInvoiceTypes.Insert();
    end;
}
