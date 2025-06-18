pageextension 50301 eInvCustomerCardExtFactBox extends "Customer Card"
{
    layout
    {
        addlast(FactBoxes)
        {
            part(TINValidationLog; "TIN Log FactBox")
            {
                SubPageLink = "Customer No." = FIELD("No.");
                ApplicationArea = All;
            }
        }
    }
}
