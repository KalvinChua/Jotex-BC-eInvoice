page 50304 "e-Invoice Types"
{
    ApplicationArea = All;
    Caption = 'e-Invoice Types';
    PageType = List;
    SourceTable = eInvoiceTypes;
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

    actions
    {
        area(processing)
        {
            action(PopulateStandardTypes)
            {
                ApplicationArea = All;
                Caption = 'Populate Standard Types';
                Image = Refresh;
                ToolTip = 'Populate the table with standard LHDN document type codes and descriptions';

                trigger OnAction()
                var
                    DataUpgrade: Codeunit "eInvoice Data Upgrade";
                begin
                    if Confirm('This will replace all existing e-Invoice types with standard LHDN document types. Continue?') then begin
                        DataUpgrade.PopulateEInvoiceTypes();
                        CurrPage.Update(false);
                    end;
                end;
            }
        }
    }
}
