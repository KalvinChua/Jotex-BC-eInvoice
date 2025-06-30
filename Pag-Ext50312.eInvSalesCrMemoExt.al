pageextension 50312 eInvSalesCrMemoExt extends "Sales Credit Memo"
{
    layout
    {
        addafter("Credit Memo Details")
        {
            group("e-Invoice")
            {
                Caption = 'e-Invoice Details';
                field("eInvoice Document Type"; Rec."eInvoice Document Type")
                {
                    ApplicationArea = Suite;
                    ToolTip = 'Specifies the e-Invoice document type as required by tax authorities';
                    Importance = Promoted;
                    Editable = false;

                    trigger OnValidate()
                    begin
                        ValidateEInvoiceDocumentType();
                        CurrPage.SaveRecord();
                    end;
                }
                field("eInvoice Payment Mode"; Rec."eInvoice Payment Mode")
                {
                    ApplicationArea = Suite;
                    ToolTip = 'Specifies the payment mode for e-Invoice purposes';
                    Importance = Additional;
                }
                field("eInvoice Currency Code"; Rec."eInvoice Currency Code")
                {
                    ApplicationArea = Suite;
                    ToolTip = 'Specifies the currency code for e-Invoice reporting';
                    Importance = Additional;
                }
                field("eInvoice Version Code"; Rec."eInvoice Version Code")
                {
                    ApplicationArea = Suite;
                    ToolTip = 'Specifies version code for e-Invoice reporting';
                    Importance = Additional;
                }
            }
        }
    }

    actions
    {
        addfirst(Processing)
        {
            action(ValidateEInvoice)
            {
                Caption = 'Validate e-Invoice';
                ApplicationArea = Suite;
                Image = CheckList;  // Changed from CheckRules to CheckList
                ToolTip = 'Verify all required e-Invoice fields are populated correctly';

                trigger OnAction()
                begin
                    ValidateEInvoiceCompleteness();
                end;
            }
        }
    }

    local procedure ValidateEInvoiceDocumentType()
    var
        Customer: Record Customer;
    begin
        if not Customer.Get(Rec."Sell-to Customer No.") then
            exit;

        if (Rec."eInvoice Document Type" = '') and Customer."Requires e-Invoice" then
            Error('e-Invoice Document Type must be specified for this customer.');
    end;

    local procedure ValidateEInvoiceCompleteness()
    var
        Customer: Record Customer;
        SalesLine: Record "Sales Line";
        MissingFieldsErr: Label 'Missing e-Invoice fields:%1', Comment = '%1 = list of missing fields';
        MissingFields: Text;
    begin
        // Check customer requirements
        if Customer.Get(Rec."Sell-to Customer No.") and Customer."Requires e-Invoice" then begin
            if Rec."eInvoice Document Type" = '' then
                MissingFields := MissingFields + '\- Document Type';

            if Rec."eInvoice Currency Code" = '' then
                MissingFields := MissingFields + '\- Currency Code';
        end;

        // Check lines
        SalesLine.SetRange("Document Type", Rec."Document Type");
        SalesLine.SetRange("Document No.", Rec."No.");
        SalesLine.SetFilter(Type, '<>%1', SalesLine.Type::" ");
        if SalesLine.FindSet() then
            repeat
                if SalesLine."e-Invoice Classification" = '' then
                    MissingFields := MissingFields + '\- Line ' + Format(SalesLine."Line No.") + ' Classification';

                if SalesLine."e-Invoice UOM" = '' then
                    MissingFields := MissingFields + '\- Line ' + Format(SalesLine."Line No.") + ' UOM';
            until SalesLine.Next() = 0;

        if MissingFields <> '' then
            Error(MissingFieldsErr, MissingFields)
        else
            Message('All required e-Invoice fields are properly populated.');
    end;
}
