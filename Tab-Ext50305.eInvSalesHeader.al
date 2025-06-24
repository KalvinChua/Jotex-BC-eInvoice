tableextension 50305 eInvSalesHeader extends "Sales Header"
{
    fields
    {
        field(50300; "eInvoice Document Type"; Code[20])
        {
            Caption = 'e-Invoice Document Type';
            TableRelation = eInvoiceTypes.Code;
            DataClassification = ToBeClassified;
        }
        field(50301; "eInvoice Payment Mode"; Code[20])
        {
            Caption = 'e-Invoice Payment Mode';
            TableRelation = "Payment Modes".Code;
            DataClassification = ToBeClassified;
        }
        field(50302; "eInvoice Currency Code"; Code[20])
        {
            Caption = 'e-Invoice Currency Code';
            TableRelation = "Currency Codes".Code;
            DataClassification = ToBeClassified;
        }
    }
}
