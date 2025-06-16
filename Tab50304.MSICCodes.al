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

        field(4; "MSIC Category Reference"; Code[5])
        {
            Caption = 'Category Reference (e.g. A)';
            DataClassification = SystemMetadata;
        }

        field(5; "Section Code"; Code[1])
        {
            Caption = 'Section Code (A-Z)';
            DataClassification = SystemMetadata;
        }

        field(6; "Section Description"; Text[250])
        {
            Caption = 'Section Description';
            DataClassification = SystemMetadata;
        }

        field(7; "Is Header"; Boolean)
        {
            Caption = 'Is Header';
            DataClassification = SystemMetadata;
        }

        field(8; "Indentation Level"; Integer)
        {
            Caption = 'Indentation Level';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; ID)
        {
            Clustered = true;
        }

        key(CodeKey; Code)
        {
            Clustered = false;
        }
    }
}
