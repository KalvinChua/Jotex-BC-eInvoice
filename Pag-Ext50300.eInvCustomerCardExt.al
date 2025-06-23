pageextension 50304 eInvCustomerCardExt extends "Customer Card"
{
    layout
    {
        addlast(Content)
        {
            group("e-Invoice Info")
            {
                Caption = 'e-Invoice Info';

                field("eInvoice TIN No."; Rec."eInvoice TIN No.")
                {
                    ApplicationArea = All;
                    Editable = true;
                }

                field("eInvoice ID Type"; Rec."eInvoice ID Type")
                {
                    ApplicationArea = All;
                    Editable = true;
                }

                field("eInvoice SST No."; Rec."eInvoice SST No.")
                {
                    ApplicationArea = All;
                    Editable = true;
                }

                field("eInvoice State Code"; Rec."eInvoice State Code")
                {
                    ApplicationArea = All;
                    Editable = true;
                }

                field("eInvoice Country Code"; Rec."eInvoice Country Code")
                {
                    ApplicationArea = All;
                    Editable = true;
                }

                field("Last Validated TIN Name"; Rec."Last Validated TIN Name")
                {
                    ApplicationArea = All;
                    Editable = false;
                }

                field("Last TIN Validation"; Rec."Last TIN Validation")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
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
