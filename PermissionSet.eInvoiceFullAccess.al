permissionset 50300 "eInvoice Full Access"
{
    Assignable = true;
    Caption = 'e-Invoice Full Access';

    // ======================================================================================================
    // MINIMAL PERMISSIONS TO FIX THE IMMEDIATE ERROR
    // ======================================================================================================

    // Core Business Central tables - CRITICAL for e-Invoice
    Permissions = tabledata "Sales Invoice Header" = RIMD,
                  tabledata "Sales Invoice Line" = RIMD,
                  tabledata Customer = RIMD,
                  tabledata Vendor = RIMD,
                  tabledata Item = RIMD,
                  tabledata "Company Information" = RIMD;
}
