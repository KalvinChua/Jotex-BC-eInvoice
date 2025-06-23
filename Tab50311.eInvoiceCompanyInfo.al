table 50311 "e-Invoice Company Info"
{
    Caption = 'e-Invoice Company Info';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[20])
        {
            Caption = 'Primary Key';
            DataClassification = SystemMetadata;
        }

        field(2; "TIN No."; Text[20]) // Supplier.TIN
        {
            Caption = 'TIN No.';
            DataClassification = CustomerContent;
            Editable = true;
        }

        field(3; "Company Name"; Text[100]) // Supplier.Name
        {
            Caption = 'Company Name';
            DataClassification = CustomerContent;
            Editable = true;
        }

        field(4; "ID Type"; Option) // Supplier.IDType
        {
            Caption = 'ID Type';
            OptionMembers = NRIC,BRN,PASSPORT,ARMY;
            DataClassification = CustomerContent;
            Editable = true;
        }

        field(5; "ID No."; Text[30]) // Supplier.IDNo
        {
            Caption = 'ID No.';
            DataClassification = CustomerContent;
            Editable = true;
        }

        field(6; "SST No."; Text[30]) // Supplier.SST.No (conditional)
        {
            Caption = 'SST No.';
            DataClassification = CustomerContent;
            Editable = true;
        }

        field(7; "TTX No."; Text[30]) // Supplier.TTX.No (conditional)
        {
            Caption = 'TTX No.';
            DataClassification = CustomerContent;
            Editable = true;
        }

        field(8; "Email"; Text[80]) // Supplier.Email (optional)
        {
            Caption = 'Email';
            DataClassification = CustomerContent;
            Editable = true;
        }

        field(9; "MSIC Code"; Code[5])
        {
            Caption = 'MSIC Code';
            TableRelation = "MSIC Codes".Code;
            DataClassification = CustomerContent;

            trigger OnValidate()
            var
                MSIC: Record "MSIC Codes";
            begin
                // Use SETRANGE instead of Get since 'Code' is not the primary key
                MSIC.SetRange(Code, "MSIC Code");
                if MSIC.FindFirst() then
                    "Business Activity Description" := MSIC.Description;
            end;
        }

        field(10; "Business Activity Description"; Text[250]) // Supplier.BusinessActivityDescription
        {
            Caption = 'Business Activity Description';
            Editable = false;
            DataClassification = CustomerContent;
        }

        field(11; "Address Line 0"; Text[100]) // AddressLine0 (required)
        {
            Caption = 'Address Line 0';
            DataClassification = CustomerContent;
            Editable = true;
        }

        field(12; "Address Line 1"; Text[100]) // AddressLine1 (optional)
        {
            Caption = 'Address Line 1';
            DataClassification = CustomerContent;
            Editable = true;
        }

        field(13; "Address Line 2"; Text[100]) // AddressLine2 (optional)
        {
            Caption = 'Address Line 2';
            DataClassification = CustomerContent;
            Editable = true;
        }

        field(14; "Postal Code"; Code[10]) // PostalZone (optional)
        {
            Caption = 'Postal Code';
            DataClassification = CustomerContent;
            Editable = true;
        }

        field(15; "City Name"; Text[100]) // CityName
        {
            Caption = 'City Name';
            DataClassification = CustomerContent;
            Editable = true;
        }

        field(16; "State Code"; Code[5]) // State
        {
            Caption = 'State Code';
            TableRelation = "State Codes";
            DataClassification = CustomerContent;
            Editable = true;
            trigger OnValidate()
            var
                StateRec: Record "State Codes";
            begin
                if StateRec.Get("State Code") then
                    "State Name" := StateRec.State;
            end;
        }

        field(17; "Country Code"; Code[5]) // CountryCode
        {
            Caption = 'Country Code';
            TableRelation = "Country Codes".Code;
            DataClassification = CustomerContent;
            Editable = true;

            trigger OnValidate()
            var
                CountryRec: Record "Country Codes";
            begin
                if CountryRec.Get("Country Code") then
                    "Country Name" := CountryRec.Country;
            end;
        }


        field(18; "Contact No."; Text[20]) // ContactNumber
        {
            Caption = 'Contact No.';
            DataClassification = CustomerContent;
            Editable = true;
        }

        field(19; "Last Modified"; DateTime)
        {
            Caption = 'Last Modified';
            Editable = false;
            DataClassification = SystemMetadata;
        }

        field(20; "State Name"; Text[100])
        {
            Caption = 'State Name';
            Editable = false;
            DataClassification = CustomerContent;
        }

        field(21; "Country Name"; Text[100])
        {
            Caption = 'Country Name';
            Editable = false;
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    trigger OnModify()
    begin
        Rec."Last Modified" := CurrentDateTime();
    end;
}
