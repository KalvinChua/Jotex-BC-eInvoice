page 50313 "e-Invoice Company Info Card"
{
    ApplicationArea = All;
    Caption = 'e-Invoice Company Info';
    PageType = Card;
    SourceTable = "e-Invoice Company Info";
    UsageCategory = Administration;
    Editable = true;


    layout
    {
        area(Content)
        {
            group("General Info")
            {
                Caption = 'General Info';
                field("TIN No."; Rec."TIN No.")
                {
                    Editable = true;
                }
                field("Company Name"; Rec."Company Name")
                {
                    Editable = true;
                }
                field("ID Type"; Rec."ID Type")
                {
                    Editable = true;
                }
                field("ID No."; Rec."ID No.")
                {
                    Editable = true;
                }
                field("SST No."; Rec."SST No.")
                {
                    Editable = true;
                }
                field("TTX No."; Rec."TTX No.")
                {
                    Editable = true;
                }
                field("Email"; Rec."Email")
                {
                    Editable = true;
                }
                field("Contact No."; Rec."Contact No.")
                {
                    Editable = true;
                }
            }

            group("Business Activity")
            {
                Caption = 'Business Activity';
                field("MSIC Code"; Rec."MSIC Code")
                {
                    Editable = true;
                }
                field("Business Activity Description"; Rec."Business Activity Description")
                {

                }
            }

            group("Address")
            {
                Caption = 'Address';
                field("Address Line 0"; Rec."Address Line 0")
                {
                    Editable = true;
                }
                field("Address Line 1"; Rec."Address Line 1")
                {
                    Editable = true;
                }
                field("Address Line 2"; Rec."Address Line 2")
                {
                    Editable = true;
                }
                field("Postal Code"; Rec."Postal Code")
                {
                    Editable = true;
                }
                field("City Name"; Rec."City Name")
                {
                    Editable = true;
                }
                field("State Code"; Rec."State Code")
                {
                    Editable = true;
                }
                field("State Name"; Rec."State Name")
                {
                    Editable = true;
                }
                field("Country Code"; Rec."Country Code")
                {
                    Editable = true;
                }
                field("Country Name"; Rec."Country Name")
                {
                    Editable = false;
                }
            }

            group("System")
            {
                Caption = 'System';
                field("Last Modified"; Rec."Last Modified") { }
            }
        }
    }
}
