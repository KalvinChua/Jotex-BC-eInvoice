pageextension 50302 eInvPostedSalesPDFExt extends "Posted Sales Invoice"
{
    actions
    {
        addlast(Processing)
        {
            action(VieweInvoicePDF)
            {
                Caption = 'View PDF (e-Invoice)';
                ApplicationArea = All;
                Image = Document;

                trigger OnAction()
                begin
                    if Rec."eInvoice PDF URL" = '' then
                        Error('No e-Invoice PDF URL available for this invoice.');

                    HYPERLINK(Rec."eInvoice PDF URL");
                end;
            }
        }
    }
}
