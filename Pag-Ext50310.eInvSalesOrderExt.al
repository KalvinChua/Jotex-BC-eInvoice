pageextension 50310 eInvSalesOrderExt extends "Sales Order Subform"
{
    layout
    {
        addafter("Description")
        {
            field("e-Invoice Classification"; Rec."e-Invoice Classification")
            {
                ApplicationArea = All;
                Visible = IsJotexCompany;
                ToolTip = 'Classification for Item based on LHDN requirement.';
            }
            field("e-Invoice Tax Type"; Rec."e-Invoice Tax Type")
            {
                ApplicationArea = All;
                Visible = IsJotexCompany;
                ToolTip = 'Tax Type for Item based on LHDN requirement.';
            }
            field("e-Invoice UOM"; Rec."e-Invoice UOM")
            {
                ApplicationArea = All;
                Visible = IsJotexCompany;
                ToolTip = 'UOM for Item based on LHDN requirement.';
            }
        }
    }

    var
        IsJotexCompany: Boolean;

    trigger OnOpenPage()
    var
        CompanyInfo: Record "Company Information";
    begin
        IsJotexCompany := CompanyInfo.Get() and (CompanyInfo.Name = 'JOTEX SDN BHD');
    end;
}
