tableextension 50307 eInvSalesLineExt extends "Sales Line"
{
    fields
    {
        field(50300; "e-Invoice Classification"; Code[20])
        {
            Caption = 'e-Invoice Classification';
            DataClassification = ToBeClassified;
            TableRelation = eInvoiceClassification.Code;
        }
        field(50301; "e-Invoice UOM"; Code[20])
        {
            Caption = 'e-Invoice UOM';
            DataClassification = ToBeClassified;
            TableRelation = eInvoiceUOM.Code;
        }
    }
}
