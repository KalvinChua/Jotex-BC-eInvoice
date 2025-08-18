codeunit 50323 "eInvoice Customer Bulk Update"
{
    Subtype = Normal;

    /// <summary>
    /// Updates all customers to require e-Invoice
    /// This can be run manually to set the default for all customers
    /// </summary>
    procedure SetAllCustomersRequireEInvoice()
    var
        Customer: Record Customer;
        UpdatedCount: Integer;
        TotalCount: Integer;
        AlreadySetCount: Integer;
    begin
        UpdatedCount := 0;
        TotalCount := 0;
        AlreadySetCount := 0;

        if Customer.FindSet() then begin
            repeat
                TotalCount += 1;

                if not Customer."Requires e-Invoice" then begin
                    Customer."Requires e-Invoice" := true;
                    if Customer.Modify() then
                        UpdatedCount += 1;
                end else begin
                    AlreadySetCount += 1;
                end;
            until Customer.Next() = 0;
        end;

        // Show results to user
        if TotalCount = 0 then begin
            Message('No customers found.');
        end else begin
            Message('Customer e-Invoice requirement update completed!\\\\' +
                   'Total customers: %1\\' +
                   'Updated to require e-Invoice: %2\\' +
                   'Already required e-Invoice: %3',
                   TotalCount, UpdatedCount, AlreadySetCount);

            Session.LogMessage('0000EIV07', StrSubstNo('eInvoice Customer Bulk Update: Updated %1 out of %2 customers to require e-Invoice. %3 already required e-Invoice.',
                UpdatedCount, TotalCount, AlreadySetCount),
                Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, '', '');
        end;
    end;

    /// <summary>
    /// Shows current status of customer e-Invoice requirements
    /// </summary>
    procedure ShowCustomerEInvoiceStatus()
    var
        Customer: Record Customer;
        TotalCustomers: Integer;
        RequireEInvoice: Integer;
        DontRequireEInvoice: Integer;
    begin
        TotalCustomers := Customer.Count();

        Customer.SetRange("Requires e-Invoice", true);
        RequireEInvoice := Customer.Count();

        DontRequireEInvoice := TotalCustomers - RequireEInvoice;

        Message('Customer e-Invoice Status:\\\\' +
               'Total customers: %1\\' +
               'Require e-Invoice: %2\\' +
               'Don''t require e-Invoice: %3',
               TotalCustomers, RequireEInvoice, DontRequireEInvoice);
    end;

}
