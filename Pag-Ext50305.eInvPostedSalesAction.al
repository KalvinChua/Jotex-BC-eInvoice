pageextension 50305 eInvPostedSalesAction extends "Posted Sales Invoice"
{
    actions
    {
        addlast(Processing)
        {
            action(SubmitToMyInvois)
            {
                Caption = 'Submit e-Invoice';
                ApplicationArea = All;
                Image = SendTo;

                trigger OnAction()
                var
                    Submitter: Codeunit "eInvoice Submitter";
                    Msg: Text;
                begin
                    Msg := Submitter.SubmitToMyInvois(Rec);
                    Message(Msg);
                end;
            }
        }
    }
}
