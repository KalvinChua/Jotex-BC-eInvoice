tableextension 50301 eInvSalesInvoiceExt extends "Sales Invoice Header"
{
    fields
    {
        field(50100; "eInvoice UUID"; Text[100])
        {
            Caption = 'e-Invoice UUID';
        }
        field(50101; "eInvoice QR URL"; Text[250])
        {
            Caption = 'e-Invoice QR URL';
        }
        field(50102; "eInvoice PDF URL"; Text[250])
        {
            Caption = 'e-Invoice PDF URL';
        }
        field(50104; "eInvoice Submission UID"; Text[100])
        {
            Caption = 'e-Invoice Submission UID';
        }
    }
}
