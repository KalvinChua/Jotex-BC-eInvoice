pageextension 50304 eInvCustomerCardExt extends "Customer Card"
{
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
