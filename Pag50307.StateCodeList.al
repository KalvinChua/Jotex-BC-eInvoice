page 50307 "State Code List"
{
    ApplicationArea = All;
    Caption = 'e-Invoice State Codes';
    PageType = List;
    SourceTable = "State Codes";
    UsageCategory = Lists;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field(Code; Rec.Code) { ApplicationArea = All; }
                field(State; Rec.State) { ApplicationArea = All; }
            }
        }
    }
}
