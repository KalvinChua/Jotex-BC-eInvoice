page 50302 "TIN Log FactBox"
{
    PageType = ListPart;
    SourceTable = "eInvoice TIN Log";
    ApplicationArea = All;
    Caption = 'e-Invoice TIN Validation History';
    Editable = false;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Response Time"; Rec."Response Time") { }
                field("TIN"; Rec.TIN) { }
                field("TIN Status"; Rec."TIN Status") { }
                field("TIN Name (API)"; Rec."TIN Name (API)") { }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        // Optional formatting or logic
    end;
}
