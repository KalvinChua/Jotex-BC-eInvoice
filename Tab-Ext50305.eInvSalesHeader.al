tableextension 50305 eInvSalesHeader extends "Sales Header"
{
    fields
    {
        field(50300; "eInvoice Document Type"; Code[2])
        {
            Caption = 'e-Invoice Document Type';
            TableRelation = eInvoiceTypes.Code;
            DataClassification = ToBeClassified;
        }
        field(50301; "eInvoice Payment Mode"; Code[2])
        {
            Caption = 'e-Invoice Payment Mode';
            TableRelation = "Payment Modes".Code;
            DataClassification = ToBeClassified;
        }
    }
}
