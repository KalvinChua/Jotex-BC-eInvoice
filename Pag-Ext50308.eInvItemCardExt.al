pageextension 50308 eInvItemCardExt extends "Item Card"
{
    layout
    {
        addafter("Default Deferral Template Code")
        {
            field("e-Invoice Tax Type"; Rec."e-Invoice Tax Type")
            {
                ApplicationArea = All;
                Caption = 'e-Invoice Tax Type';
                Editable = true;
                Importance = Additional;
            }
            field("e-Invoice Classification"; Rec."e-Invoice Classification")
            {
                ApplicationArea = All;
                Caption = 'e-Invoice Classification';
                Editable = true;
                Importance = Additional;
            }
        }
    }
}
