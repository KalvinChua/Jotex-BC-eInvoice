pageextension 50301 "e-Invoice Company Info" extends "Company Information"
{
    layout
    {
        addafter(General)
        {
            group("e-Invoice")
            {
                field("e-Invoice TIN No."; Rec."e-Invoice TIN No.")
                {
                    ApplicationArea = All;
                    Visible = true;
                    Caption = 'e-Invoice TIN No.';
                }
                field("TTX No."; Rec."TTX No.")
                {
                    ApplicationArea = All;
                    Visible = true;
                    Caption = 'e-Invoice TTX No.';
                }
                field("ID Type"; Rec."ID Type")
                {
                    ApplicationArea = All;
                    Visible = true;
                    Caption = 'e-Invoice ID Type';
                }
                field("ID No."; Rec."ID No.")
                {
                    ApplicationArea = All;
                    Visible = true;
                    Caption = 'e-Invoice ID No.';
                }
                field("e-Invoice Email"; Rec."e-Invoice Email")
                {
                    ApplicationArea = All;
                    Visible = true;
                    Caption = 'e-Invoice Email';
                }
                field("MSIC Code"; Rec."MSIC Code")
                {
                    ApplicationArea = All;
                    Visible = true;
                }
                field("Business Activity Description"; Rec."Business Activity Description")
                {
                    ApplicationArea = All;
                    Visible = true;
                    Editable = false;
                }
                field("e-Invoice State Code"; Rec."e-Invoice State Code")
                {
                    ApplicationArea = All;
                    Visible = true;
                    Caption = 'e-Invoice State Code';
                }
                field("State Name"; Rec."State Name")
                {
                    ApplicationArea = All;
                    Visible = true;
                    Editable = false;
                    Caption = 'e-Invoice State Name';
                }
                field("e-Invoice Country Code"; Rec."e-Invoice Country Code")
                {
                    ApplicationArea = All;
                    Visible = true;
                    Caption = 'e-Invoice Country Code';
                }
                field("Country Name"; Rec."Country Name")
                {
                    ApplicationArea = All;
                    Visible = true;
                    Editable = false;
                    Caption = 'e-Invoice Country Name';
                }
            }
        }
    }
}
