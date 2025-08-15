permissionset 50300 "eInvoice Full Access"
{
    Assignable = true;
    Caption = 'e-Invoice Full Access';

    // ======================================================================================================
    // COMPLETE PERMISSIONS FOR ALL eINVOICE TABLES AND OBJECTS
    // ======================================================================================================

    Permissions =
        // Custom e-Invoice tables
        table "eInvoiceSetup" = X,
        table "eInvoice TIN Log" = X,
        table "eInvoiceTypes" = X,
        table "Currency Codes" = X,
        table "MSIC Codes" = X,
        table "State Codes" = X,
        table "Country Codes" = X,
        table "Payment Modes" = X,
        table "eInvoiceClassification" = X,
        table "e-Invoice Tax Types" = X,
        table "eInvoiceUOM" = X,
        table "eInvoice Version" = X,
        table "eInvoice Submission Log" = X,

        // Table data permissions
        tabledata "eInvoiceSetup" = RIMD,
        tabledata "eInvoice TIN Log" = RIMD,
        tabledata "eInvoiceTypes" = RIMD,
        tabledata "Currency Codes" = RIMD,
        tabledata "MSIC Codes" = RIMD,
        tabledata "State Codes" = RIMD,
        tabledata "Country Codes" = RIMD,
        tabledata "Payment Modes" = RIMD,
        tabledata "eInvoiceClassification" = RIMD,
        tabledata "e-Invoice Tax Types" = RIMD,
        tabledata "eInvoiceUOM" = RIMD,
        tabledata "eInvoice Version" = RIMD,
        tabledata "eInvoice Submission Log" = RIMD,

        // Core Business Central tables - CRITICAL for e-Invoice
        tabledata "Sales Invoice Header" = RIMD,
        tabledata "Sales Invoice Line" = RIMD,
        tabledata "Sales Cr.Memo Header" = RIMD,
        tabledata "Sales Cr.Memo Line" = RIMD,
        tabledata Customer = RIMD,
        tabledata Vendor = RIMD,
        tabledata Item = RIMD,
        tabledata "Company Information" = RIMD,
        tabledata "Job Queue Entry" = RIMD,
        tabledata "Job Queue Log Entry" = RIMD,
        tabledata "Scheduled Task" = RIMD,

        // Additional required permissions for complete functionality
        tabledata "Sales Header" = RIMD,
        tabledata "Sales Line" = RIMD,
        tabledata "Sales Header Archive" = RIMD,
        tabledata "Sales Line Archive" = RIMD,

        // Pages
        page eInvoiceSetupCard = X,
        page "TIN Validation Log" = X,
        page "TIN Log FactBox" = X,
        page "e-Invoice Types" = X,
        page eInvoiceCurrencyCodes = X,
        page "MSIC Code List" = X,
        page "State Code List" = X,
        page "Country Code List" = X,
        page "Payment Mode List" = X,
        page "e-invoice Classification" = X,
        page "e-Invoice Tax Types" = X,
        page "e-Invoice UOM" = X,
        page "e-Invoice Version" = X,
        page "e-Invoice Submission Log Card" = X,
        page "e-Invoice Submission Log" = X,
        page "Custom Cancellation Reason" = X,
        page "eInv Date Range Picker" = X,
        page "eInvoice QR FactBox" = X,
        page "eInvoice QR CM FactBox" = X,

        // Codeunits
        codeunit eInvoiceHelper = X,
        codeunit "eInvoice TIN Validator" = X,
        codeunit "eInvoice JSON Generator" = X,
        codeunit "eInv Posting Subscribers" = X,
        codeunit "eInv Field Population" = X,
        codeunit "e-Invoice Country Code Mgt" = X,
        codeunit "e-Invoice State Code Mgt" = X,
        codeunit "eInv Field Population Handler" = X,
        codeunit "eInvoice Azure Function Client" = X,
        codeunit "eInvoice UBL Document Builder" = X,
        codeunit "eInvoice Submission Status" = X,
        codeunit "eInvoice Cancellation Helper" = X,
        codeunit "eInv Sales Order Posting Sub" = X,
        codeunit "eInvoice QR Manager" = X,
        codeunit "eInvoice Data Upgrade" = X,
        codeunit "eInvoice Post Date Populator" = X,
        codeunit "eInvoice Customer Bulk Update" = X,
        codeunit "eInvoice Customer Name Upgrade" = X,
        codeunit "eInv Sales Header Enforcer" = X,

        // Reports
        report "LHDN e-Invoice Export" = X,
        report "Export Credit Memo Batch eInv" = X;
}
