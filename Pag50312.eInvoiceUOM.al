page 50312 "e-Invoice UOM"
{
    ApplicationArea = All;
    Caption = 'e-Invoice UOM';
    PageType = List;
    SourceTable = eInvoiceUOM;
    UsageCategory = Lists;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field(Code; Rec.Code) { ApplicationArea = All; }
                field(Name; Rec.Name) { ApplicationArea = All; }
            }
        }
    }
}
