pageextension 50307 eInvSalesInvoiceExt extends "Sales Invoice"
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
            field("eInvoice Payment Mode"; Rec."eInvoice Payment Mode")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the Payment Mode';
            }
        }
    }
}
