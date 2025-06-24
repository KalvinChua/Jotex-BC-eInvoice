tableextension 50304 eInvSalesInvoiceHeader extends "Sales Invoice Header"
{
    fields
    {
        field(50300; "eInvoice Document Type"; Code[2])
        {
            Caption = 'e-Invoice Document Type';
            TableRelation = eInvoiceTypes.Code;
            DataClassification = ToBeClassified;
        }
    }
}
