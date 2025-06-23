table 50304 "MSIC Codes"
{
    Caption = 'MSIC Codes';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "ID"; Integer)
        {
            Caption = 'ID';
            AutoIncrement = true;
            DataClassification = SystemMetadata;
        }

        field(2; "Code"; Code[5])
        {
            Caption = 'MSIC Code';
            DataClassification = SystemMetadata;
        }

        field(3; "Description"; Text[250])
        {
            Caption = 'Activity Description';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; Code)
        {
            Clustered = true;
        }

        key(IDKey; ID)
        {
            Clustered = false;
        }
    }
}
