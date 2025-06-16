page 50310 "e-invoice Classification"
{
    ApplicationArea = All;
    Caption = 'e-invoice Classification';
    PageType = List;
    SourceTable = eInvoiceClassification;
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
