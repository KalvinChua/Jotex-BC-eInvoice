permissionset 50300 eInvoiceFullAccess
{
    Caption = 'e-Invoice Full Access';
    Assignable = true;

    Permissions =
        tabledata eInvoiceSetup = RIMD,
        tabledata "eInvoice TIN Log" = RIMD,
        tabledata eInvoiceTypes = RIMD,
        tabledata eInvoiceUOM = RIMD,
        tabledata "eInvoice Version" = RIMD,
        tabledata "Currency Codes" = RIMD,
        tabledata "MSIC Codes" = RIMD,
        tabledata "State Codes" = RIMD,
        tabledata "Country Codes" = RIMD,
        tabledata "Payment Modes" = RIMD,
        tabledata "e-Invoice Tax Types" = RIMD,
        tabledata eInvoiceClassification = RIMD;
}
