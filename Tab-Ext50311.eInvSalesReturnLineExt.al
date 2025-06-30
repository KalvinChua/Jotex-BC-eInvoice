tableextension 50311 eInvSalesReturnLineExt extends "Return Receipt Line"
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
        field(50302; "e-Invoice Tax Type"; Code[20])
        {
            Caption = 'e-Invoice Tax Type';
            DataClassification = ToBeClassified;
            TableRelation = "e-Invoice Tax Types".Code;
        }
    }
}
