page 50305 eInvoiceCurrencyCodes
{
    ApplicationArea = All;
    Caption = 'e-Invoice Currency Codes';
    PageType = List;
    SourceTable = "Currency Codes";
    UsageCategory = Lists;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field(Code; Rec.Code) { ApplicationArea = All; }
                field(Currency; Rec.Currency) { ApplicationArea = All; }
            }
        }
    }
}
