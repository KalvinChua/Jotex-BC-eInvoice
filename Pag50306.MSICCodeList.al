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
                    StyleExpr = HeaderStyle;
                }

                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    Editable = true;
                    StyleExpr = HeaderStyle;
                }

                field("Indented Description"; GetIndentedDescription())
                {
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = HeaderStyle;
                }

                field("MSIC Category Reference"; Rec."MSIC Category Reference")
                {
                    ApplicationArea = All;
                }

                field("Section Code"; Rec."Section Code")
                {
                    ApplicationArea = All;
                }

                field("Section Description"; Rec."Section Description")
                {
                    ApplicationArea = All;
                }

                field("Is Header"; Rec."Is Header")
                {
                    ApplicationArea = All;
                }

                field("Indentation Level"; Rec."Indentation Level")
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        if Rec."Is Header" then
            HeaderStyle := 'Strong'
        else
            HeaderStyle := 'Standard';
    end;

    var
        HeaderStyle: Text;

    local procedure GetIndentedDescription(): Text
    var
        IndentText: Text;
        i: Integer;
    begin
        for i := 1 to Rec."Indentation Level" do
            IndentText += '   '; // 3 spaces per level
        exit(IndentText + Rec.Description);
    end;
}
