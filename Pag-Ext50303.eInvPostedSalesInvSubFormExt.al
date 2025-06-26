pageextension 50303 eInvPostedSalesInvSubFormExt extends "Posted Sales Invoice Subform"
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
            field("e-Invoice UOM"; Rec."e-Invoice UOM")
            {
                ApplicationArea = All;
                Visible = true;
                ToolTip = 'UOM for Item based on LHDN requirement.';
            }
        }
    }
}
