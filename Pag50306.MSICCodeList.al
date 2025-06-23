page 50306 "MSIC Code List"
{
    ApplicationArea = All;
    Caption = 'e-Invoice MSIC Code';
    PageType = List;
    SourceTable = "MSIC Codes";
    UsageCategory = Lists;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field(Code; Rec.Code)
                {
                    ApplicationArea = All;
                    Editable = true;
                    Visible = true;
                }

                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    Editable = true;
                    Visible = true;
                }


            }

        }
    }
}
