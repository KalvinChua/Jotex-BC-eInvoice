pageextension 50303 eInvPostedSalesQRFactboxExt extends "Posted Sales Invoice"
{
    layout
    {
        addlast(FactBoxes)
        {
            part(MyInvoisQRFactBox; "eInvoice QR FactBox")
            {
                ApplicationArea = All;
                SubPageLink = "No." = FIELD("No.");
            }
        }
    }
}
