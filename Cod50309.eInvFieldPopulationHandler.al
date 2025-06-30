codeunit 50309 "eInv Field Population Handler"
{
    procedure CopyFieldsFromItemToSalesLines(SalesHeader: Record "Sales Header")
    var
        SalesLine: Record "Sales Line";
        Item: Record Item;
        ModifiedHeader: Boolean;
    begin
        // === Set Header Fields if Blank ===
        if SalesHeader."eInvoice Document Type" = '' then begin
            case SalesHeader."Document Type" of
                SalesHeader."Document Type"::Invoice,
                SalesHeader."Document Type"::Order:
                    SalesHeader."eInvoice Document Type" := '01'; // Standard Invoice
                SalesHeader."Document Type"::"Credit Memo":
                    SalesHeader."eInvoice Document Type" := '02'; // Credit Note
                SalesHeader."Document Type"::"Return Order":
                    SalesHeader."eInvoice Document Type" := '02'; // Return Order (Credit)
            end;
            ModifiedHeader := true;
        end;

        if SalesHeader."eInvoice Version Code" = '' then begin
            SalesHeader."eInvoice Version Code" := '1.1'; // Replace with your default version if needed
            ModifiedHeader := true;
        end;

        if ModifiedHeader then
            SalesHeader.Modify();

        // === Update Sales Lines from Item ===
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");

        if SalesLine.FindSet() then
            repeat
                if SalesLine.Type = SalesLine.Type::Item then
                    if Item.Get(SalesLine."No.") then begin
                        SalesLine."e-Invoice Tax Type" := Item."e-Invoice Tax Type";
                        SalesLine."e-Invoice Classification" := Item."e-Invoice Classification";
                        SalesLine."e-Invoice UOM" := Item."e-Invoice UOM";
                        SalesLine.Modify();
                    end;
            until SalesLine.Next() = 0;
    end;
}
