page 50303 "eInvoice QR FactBox"
{
    PageType = CardPart;
    SourceTable = "Sales Invoice Header";
    ApplicationArea = All;
    Caption = 'e-Invoice QR Code';
    Editable = false;

    layout
    {
        area(content)
        {
            group(QR)
            {
                field("MyInvois QR Image"; Rec."eInvoice QR Image")
                {
                    ApplicationArea = All;
                    ShowCaption = false;
                }
            }
        }
    }
}
