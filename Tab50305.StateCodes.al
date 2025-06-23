table 50305 "State Codes"
{
    Caption = 'State Codes';
    DataClassification = CustomerContent;
    LookupPageId = "State Code List";

    fields
    {
        field(1; Code; Code[20])
        {
            Caption = 'Code';
        }

        field(2; State; Text[100])
        {
            Caption = 'State';
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
