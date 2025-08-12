tableextension 50305 eInvSalesHeader extends "Sales Header"
{
    fields
    {
        field(50306; "eInvoice Document Type"; Code[20])
        {
            Caption = 'e-Invoice Document Type';
            TableRelation = eInvoiceTypes.Code;
            DataClassification = ToBeClassified;
        }
        field(50301; "eInvoice Payment Mode"; Code[20])
        {
            Caption = 'e-Invoice Payment Mode';
            TableRelation = "Payment Modes".Code;
            DataClassification = ToBeClassified;
        }
        field(50302; "eInvoice Currency Code"; Code[20])
        {
            Caption = 'e-Invoice Currency Code';
            TableRelation = "Currency Codes".Code;
            DataClassification = ToBeClassified;
        }
        field(50303; "eInvoice Version Code"; Code[20])
        {
            Caption = 'e-Invoice Version Code';
            TableRelation = "eInvoice Version".Code;
            DataClassification = ToBeClassified;
            InitValue = '1.1';  // Default value
        }
    }
    trigger OnInsert()
    begin
        if "eInvoice Version Code" = '' then
            "eInvoice Version Code" := '1.1';

        // Set e-Invoice Document Type based on Sales Document Type (override anything copied in)
        case "Document Type" of
            "Document Type"::Invoice:
                "eInvoice Document Type" := '01';
            "Document Type"::"Credit Memo":
                "eInvoice Document Type" := '02';
        end;
    end;

    trigger OnModify()
    begin
        // Ensure correct type after copy/correction routines transfer fields from source docs
        if "Document Type" = "Document Type"::"Credit Memo" then begin
            if "eInvoice Document Type" <> '02' then
                "eInvoice Document Type" := '02';
        end else
            if "Document Type" = "Document Type"::Invoice then begin
                if "eInvoice Document Type" <> '01' then
                    "eInvoice Document Type" := '01';
            end;
    end;

    // Note: additional enforcement can be done via subscribers if needed
}
