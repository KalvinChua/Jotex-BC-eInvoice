codeunit 50324 "eInvoice Customer Name Upgrade"
{
    Subtype = Upgrade;

    trigger OnUpgradePerCompany()
    begin
        UpdateCustomerNamesInSubmissionLog();
    end;

    local procedure UpdateCustomerNamesInSubmissionLog()
    var
        SubmissionLog: Record "eInvoice Submission Log";
        Customer: Record Customer;
        SalesInvoiceHeader: Record "Sales Invoice Header";
        CustomerName: Text;
        UpdatedCount: Integer;
    begin
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

        // Log the upgrade results
        if UpdatedCount > 0 then
            LogUpgradeResults(UpdatedCount);
    end;

    local procedure LogUpgradeResults(UpdatedCount: Integer)
    var
        SubmissionLog: Record "eInvoice Submission Log";
    begin
        // Create a log entry for the upgrade
        SubmissionLog.Init();
        SubmissionLog."Entry No." := 0; // Auto-increment
        SubmissionLog."Invoice No." := '';
        SubmissionLog."Customer Name" := 'System';
        SubmissionLog."Submission UID" := '';
        SubmissionLog."Document UUID" := '';
        SubmissionLog.Status := 'System';
        SubmissionLog."Submission Date" := CurrentDateTime;
        SubmissionLog."Response Date" := CurrentDateTime;
        SubmissionLog."Last Updated" := CurrentDateTime;
        SubmissionLog."User ID" := UserId;
        SubmissionLog."Company Name" := CompanyName;
        SubmissionLog."Error Message" := StrSubstNo('Data upgrade completed: Updated Customer Name for %1 existing submission log entries', UpdatedCount);
        SubmissionLog."Posting Date" := Today;

        if SubmissionLog.Insert() then begin
            // Successfully logged upgrade results
        end;
    end;
}
