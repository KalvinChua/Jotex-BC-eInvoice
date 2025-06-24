tableextension 50301 eInvSalesInvoiceExt extends "Sales Invoice Header"
{
    fields
    {
        field(50300; "eInvoice UUID"; Text[100])
        {
            Caption = 'e-Invoice UUID';
        }
        field(50301; "eInvoice QR URL"; Text[250])
        {
            Caption = 'e-Invoice QR URL';
        }
        field(50302; "eInvoice PDF URL"; Text[250])
        {
            Caption = 'e-Invoice PDF URL';
        }
        field(50304; "eInvoice Submission UID"; Text[100])
        {
            Caption = 'e-Invoice Submission UID';
        }
        field(50305; "eInvoice QR Image"; Media)
        {
            Caption = 'e-Invoice QR Image';
            DataClassification = CustomerContent;
        }
        field(50306; "eInvoice Document Type"; Code[2])
        {
            Caption = 'e-Invoice Document Type';
            TableRelation = eInvoiceTypes.Code;
            DataClassification = ToBeClassified;
        }
    }
}
