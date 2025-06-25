tableextension 50306 SalesInvLineExt extends "Sales Invoice Line"
{
    fields
    {
        field(50300; "e-Invoice Classification"; Code[20])
        {
            Caption = 'e-Invoice Classification';
            TableRelation = "eInvoiceClassification".Code;
            DataClassification = ToBeClassified;
        }
    }
}
