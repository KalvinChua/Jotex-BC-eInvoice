tableextension 50313 eInvSalesHeaderArch extends "Sales Header Archive"
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
        field(50304; "eInvoice Submission UID"; Text[100])
        {
            Caption = 'e-Invoice Submission UID';
            DataClassification = ToBeClassified;
        }
        field(50305; "eInvoice UUID"; Text[100])
        {
            Caption = 'e-Invoice UUID';
            DataClassification = ToBeClassified;
        }
        field(50306; "eInvoice Validation Status"; Text[50])
        {
            Caption = 'e-Invoice Validation Status';
            DataClassification = ToBeClassified;
        }
    }
    trigger OnInsert()
    begin
        if "eInvoice Version Code" = '' then
            "eInvoice Version Code" := '1.1';
    end;
}
