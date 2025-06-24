page 50313 "e-Invoice Version"
{
    ApplicationArea = All;
    Caption = 'e-Invoice Version';
    PageType = List;
    SourceTable = "eInvoice Version";
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
