page 50308 "Country Code List"
{
    ApplicationArea = All;
    Caption = 'e-Invoice Country Codes';
    PageType = List;
    SourceTable = "Country Codes";
    UsageCategory = Lists;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field(Code; Rec.Code)
                {
                    ApplicationArea = All;
                }
                field(Country; Rec.Country)
                {
                    ApplicationArea = All;
                }
            }
        }
    }
}
