page 50304 "e-Invoice Types"
{
    ApplicationArea = All;
    Caption = 'e-Invoice Types';
    PageType = List;
    SourceTable = eInvoiceTypes;
    UsageCategory = Lists;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field(Code; Rec.Code) { ApplicationArea = All; }
                field(Description; Rec.Description) { ApplicationArea = All; }
            }
        }
    }
}
