tableextension 50310 eInvSalesReturnHeaderExt extends "Return Receipt Header"
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
        field(50303; "eInvoice Version Code"; Code[20])
        {
            Caption = 'e-Invoice Version Code';
            TableRelation = "eInvoice Version".Code;
            DataClassification = ToBeClassified;
            InitValue = '1.1';  // Default value
        }
    }
    trigger OnInsert()
    begin
        if "eInvoice Version Code" = '' then
            "eInvoice Version Code" := '1.1';
    end;
}
