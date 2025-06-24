pageextension 50306 eInvPostedSalesInvoiceExt extends "Posted Sales Invoice"
{
    layout
    {
        addafter("Currency Code")
        {
            field("eInvoice Document Type"; Rec."eInvoice Document Type")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the MyInvois document type code (e.g., 01 = Invoice, 02 = Credit Note, etc.)';
            }
        }
    }
}
