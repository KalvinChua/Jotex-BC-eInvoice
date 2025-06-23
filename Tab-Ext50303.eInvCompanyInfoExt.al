tableextension 50303 eInvCompanyInfoExt extends "Company Information"
{
    fields
    {
        field(50300; "ID Type"; Option) // Supplier.IDType
        {
            Caption = 'ID Type';
            OptionMembers = NRIC,BRN,PASSPORT,ARMY;
            DataClassification = CustomerContent;
            Editable = true;
        }

        field(50301; "ID No."; Text[30]) // Supplier.IDNo
        {
            Caption = 'ID No.';
            DataClassification = CustomerContent;
            Editable = true;
        }
        field(50302; "TTX No."; Text[30]) // Supplier.TTX.No (conditional)
        {
            Caption = 'TTX No.';
            DataClassification = CustomerContent;
            Editable = true;
        }

        field(50303; "e-Invoice Email"; Text[80]) // Supplier.Email (optional)
        {
            Caption = 'Email';
            DataClassification = CustomerContent;
            Editable = true;
        }

        field(50304; "MSIC Code"; Code[5])
        {
            Caption = 'MSIC Code';
            TableRelation = "MSIC Codes".Code;
            DataClassification = CustomerContent;

            trigger OnValidate()
            var
                MSIC: Record "MSIC Codes";
            begin
                MSIC.SetRange(Code, "MSIC Code");
                if MSIC.FindFirst() then
                    "Business Activity Description" := MSIC.Description;
            end;
        }

        field(50305; "Business Activity Description"; Text[250]) // Supplier.BusinessActivityDescription
        {
            Caption = 'Business Activity Description';
            Editable = false;
            DataClassification = CustomerContent;
        }
        field(50306; "e-Invoice State Code"; Code[5]) // State
        {
            Caption = 'State Code';
            TableRelation = "State Codes";
            DataClassification = CustomerContent;
            Editable = true;
            trigger OnValidate()
            var
                StateRec: Record "State Codes";
            begin
                if StateRec.Get("e-Invoice State Code") then
                    "State Name" := StateRec.State;
            end;
        }

        field(50307; "e-Invoice Country Code"; Code[5]) // CountryCode
        {
            Caption = 'Country Code';
            TableRelation = "Country Codes".Code;
            DataClassification = CustomerContent;
            Editable = true;

            trigger OnValidate()
            var
                Country: Record "Country Codes";
            begin
                Country.SetRange(Code, "e-Invoice Country Code");
                if Country.FindFirst() then
                    "Country Name" := Country.Country;
            end;
        }
        field(50308; "State Name"; Text[100])
        {
            Caption = 'State Name';
            Editable = false;
            DataClassification = CustomerContent;
        }

        field(50309; "Country Name"; Text[100])
        {
            Caption = 'Country Name';
            Editable = false;
            DataClassification = CustomerContent;
        }
    }
}
