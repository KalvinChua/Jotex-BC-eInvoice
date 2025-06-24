pageextension 50306 eInvPostedSalesInvoiceExt extends "Posted Sales Invoice"
{
    layout
    {
        addafter("Currency Code")
        {
            field("eInvoice Document Type"; Rec."eInvoice Document Type")
            {
                ApplicationArea = Suite; // Best practice: Use 'Suite' for core financial areas
                ToolTip = 'Specifies the MyInvois document type code (e.g., 01 = Invoice, 02 = Credit Note, etc.)';
                Editable = false; // Since this is a posted document, field should be read-only
                Importance = Additional; // Makes the field less prominent (optional)
            }
        }
    }
}