tableextension 50300 eInvoiceCustomerExt extends Customer
{
    fields
    {
        field(50300; "Last Validated TIN Name"; Text[100])
        {
            Caption = 'TIN Registered Name';
        }
        field(50301; "Last TIN Validation"; DateTime)
        {
            Caption = 'Last TIN Validation';
        }
        field(50302; "e-Invoice SST No."; Text[150])
        {
            Caption = 'e-Invoice SST No.';
        }
        field(50303; "e-Invoice State Code"; Code[20]) // Match the key size in table 50305
        {
            Caption = 'e-Invoice State Code';
            ToolTip = 'Mandatory for e-Invoice submission. Use MyInvois State Code.';
            TableRelation = "State Codes".Code;
        }

        field(50304; "e-Invoice Country Code"; Code[20]) // Match the key size in table 50306
        {
            Caption = 'e-Invoice Country Code';
            ToolTip = 'Mandatory for e-Invoice submission. Use ISO Alpha-3 code (e.g., MYS).';
            TableRelation = "Country Codes".Code;
        }

        field(50305; "e-Invoice ID Type"; Option)
        {
            Caption = 'e-Invoice ID Type';
            OptionMembers = NRIC,BRN,PASSPORT,ARMY;
            ToolTip = 'ID Type required for e-Invoice: NRIC, BRN, PASSPORT, or ARMY.';
        }
        field(50306; "e-Invoice TIN No."; Text[150])
        {
            Caption = 'e-Invoice TIN No.';
        }
        field(50307; "Requires e-Invoice"; Boolean)
        {
            Caption = 'Requires e-Invoice';
            DataClassification = CustomerContent;
        }
    }
}
