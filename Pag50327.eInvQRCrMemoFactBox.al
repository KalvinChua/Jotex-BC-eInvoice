page 50327 "eInvoice QR CM FactBox"
{
    PageType = CardPart;
    SourceTable = "Sales Cr.Memo Header";
    ApplicationArea = All;
    Caption = 'e-Invoice QR';

    layout
    {
        area(content)
        {
            field("eInvoice QR Image"; Rec."eInvoice QR Image")
            {
                ApplicationArea = All;
                ShowCaption = false;
                ToolTip = 'Displays the e-Invoice QR image when available.';
            }
        }
    }
}


