page 50309 "Payment Mode List"
{
    ApplicationArea = All;
    Caption = 'e-Invoice Payment Modes';
    PageType = List;
    SourceTable = "Payment Modes";
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
