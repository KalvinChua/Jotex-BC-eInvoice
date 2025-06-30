pageextension 50302 eInvSalesInvPageExt extends "Sales Invoice Subform"
{
    layout
    {
        addafter("Description")
        {
            field("e-Invoice Classification"; Rec."e-Invoice Classification")
            {
                ApplicationArea = All;
                Visible = true;
                ToolTip = 'Classification for Item based on LHDN requirement.';
            }
            field("e-Invoice Tax Type"; Rec."e-Invoice Tax Type")
            {
                ApplicationArea = All;
                Visible = true;
                ToolTip = 'Tax Type for Item based on LHDN requirement.';
            }
            field("e-Invoice UOM"; Rec."e-Invoice UOM")
            {
                ApplicationArea = All;
                Visible = true;
                ToolTip = 'UOM for Item based on LHDN requirement.';
            }
        }
    }
}
