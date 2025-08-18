pageextension 50304 eInvCustomerCardExt extends "Customer Card"
{
    layout
    {
        addafter(Invoicing)
        {
            group("e-Invoice")
            {
                field("e-Invoice TIN No."; Rec."e-Invoice TIN No.")
                {
                    ApplicationArea = All;
                    Editable = true;
                    Visible = true;
                }

                field("e-Invoice ID Type"; Rec."e-Invoice ID Type")
                {
                    ApplicationArea = All;
                    Editable = true;
                    Visible = true;
                }
                field("e-Invoice ID No."; Rec."e-Invoice ID No.")
                {
                    ApplicationArea = All;
                    Editable = true;
                    Visible = true;
                }

                field("e-Invoice SST No."; Rec."e-Invoice SST No.")
                {
                    ApplicationArea = All;
                    Editable = true;
                    Visible = true;
                }

                field("e-Invoice State Code"; Rec."e-Invoice State Code")
                {
                    ApplicationArea = All;
                    Editable = true;
                    Visible = true;
                }

                field("e-Invoice Country Code"; Rec."e-Invoice Country Code")
                {
                    ApplicationArea = All;
                    Editable = true;
                    Visible = true;
                }

                field("Validation Status"; Rec."Validation Status")
                {
                    ApplicationArea = All;
                    Editable = false;
                    Visible = true;
                }
                field("Requires e-Invoice"; Rec."Requires e-Invoice")
                {
                    ApplicationArea = Suite;
                    ToolTip = 'Specifies if this customer requires e-Invoice submission';
                }
            }
        }

        addfirst(factboxes)
        {
            part("TIN Validation History"; "TIN Log FactBox")
            {
                ApplicationArea = All;
                Caption = 'TIN Validation History';
                SubPageLink = "Customer No." = field("No.");
            }
        }
    }

    actions
    {
        addlast(Navigation)
        {
            action(ValidateTIN)
            {
                Caption = 'Validate TIN No.';
                Image = Check;
                ApplicationArea = All;

                trigger OnAction()
                var
                    Validator: Codeunit "eInvoice TIN Validator";
                    Msg: Text;
                begin
                    Msg := Validator.ValidateTIN(Rec);
                    Message(Msg);
                end;
            }
        }
    }
}
