table 50303 "Currency Codes"
{
    Caption = 'Currency Codes';
    DataClassification = CustomerContent;

    fields
    {
        field(1; Code; Code[20])
        {
            Caption = 'Code';
        }

        field(2; Currency; Text[100])
        {
            Caption = 'Currency';
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
