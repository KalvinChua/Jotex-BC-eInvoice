table 50311 "eInvoice Version"
{
    Caption = 'eInvoice Version';
    DataClassification = ToBeClassified;

    fields
    {
        field(1; Code; Code[10])
        {
            Caption = 'Version';
            DataClassification = CustomerContent;
        }

        field(2; Description; Text[100])
        {
            Caption = 'Description';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; Code) { Clustered = true; }
    }
}
