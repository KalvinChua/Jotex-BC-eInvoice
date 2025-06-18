page 50311 "e-Invoice Tax Types"
{
    ApplicationArea = All;
    Caption = 'e-Invoice Tax Types';
    PageType = List;
    SourceTable = "e-Invoice Tax Types";
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
