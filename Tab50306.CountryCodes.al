table 50306 "Country Codes"
{
    Caption = 'Country Codes';
    DataClassification = CustomerContent;
    LookupPageId = "Country Code List";

    fields
    {
        field(1; Code; Code[20])
        {
            Caption = 'Code';
        }

        field(2; Country; Text[100])
        {
            Caption = 'Country';
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
