table 50310 eInvoiceUOM
{
    Caption = 'eInvoiceUOM';
    DataClassification = ToBeClassified;

    fields
    {
        field(1; Code; Code[20])
        {
            Caption = 'Code';
        }

        field(2; Name; Text[250])
        {
            Caption = 'Name';
        }
    }

    keys
    {
        key(PK; Code)
        {
            Clustered = true;
        }
    }
}
