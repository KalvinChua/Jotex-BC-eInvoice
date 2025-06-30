codeunit 50306 "eInv Field Population"
{
    Permissions = tabledata "Sales Invoice Header" = M;

    [EventSubscriber(ObjectType::Table, Database::"Sales Line", 'OnAfterValidateEvent', 'Type', false, false)]
    local procedure CopyFromItemOnTypeChange(var Rec: Record "Sales Line"; var xRec: Record "Sales Line"; CurrFieldNo: Integer)
    begin
        if Rec.Type <> Rec.Type::Item then
            exit;

        CopyEInvoiceFieldsFromItem(Rec);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Line", 'OnAfterValidateEvent', 'No.', false, false)]
    local procedure CopyFromItemOnItemNoChange(var Rec: Record "Sales Line"; var xRec: Record "Sales Line"; CurrFieldNo: Integer)
    begin
        if Rec.Type <> Rec.Type::Item then
            exit;

        CopyEInvoiceFieldsFromItem(Rec);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnAfterInsertEvent', '', false, false)]
    local procedure SetDefaultEInvoiceValuesOnInsert(var Rec: Record "Sales Header"; RunTrigger: Boolean)
    begin
        if Rec.IsTemporary then
            exit;

        // Set default document type for invoices
        if Rec."Document Type" = Rec."Document Type"::Invoice then
            Rec."eInvoice Document Type" := '01'; // Standard invoice code
        if Rec."Document Type" = Rec."Document Type"::Order then
            Rec."eInvoice Document Type" := '01'; // Standard invoice code
        if Rec."Document Type" = Rec."Document Type"::"Credit Memo" then
            Rec."eInvoice Document Type" := '02'; // Credit Note code
        if Rec."Document Type" = Rec."Document Type"::"Return Order" then
            Rec."eInvoice Document Type" := '04'; // Credit Note code
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnAfterValidateEvent', 'Sell-to Customer No.', false, false)]
    local procedure SetDefaultEInvoiceValuesOnCustomerChange(var Rec: Record "Sales Header"; var xRec: Record "Sales Header"; CurrFieldNo: Integer)
    begin
        // For invoices, always use '01' unless already set
        if (Rec."Document Type" = Rec."Document Type"::Invoice) and
           (Rec."eInvoice Document Type" = '')
        then
            Rec."eInvoice Document Type" := '01';
        if (Rec."Document Type" = Rec."Document Type"::Order) and
           (Rec."eInvoice Document Type" = '')
        then
            Rec."eInvoice Document Type" := '01';
        if (Rec."Document Type" = Rec."Document Type"::"Credit Memo") and
           (Rec."eInvoice Document Type" = '')
        then
            Rec."eInvoice Document Type" := '02';
        if (Rec."Document Type" = Rec."Document Type"::"Return Order") and
           (Rec."eInvoice Document Type" = '')
        then
            Rec."eInvoice Document Type" := '02';
    end;

    local procedure CopyEInvoiceFieldsFromItem(var SalesLine: Record "Sales Line")
    var
        Item: Record Item;
    begin
        if not Item.Get(SalesLine."No.") then
            exit;

        SalesLine."e-Invoice Tax Type" := Item."e-Invoice Tax Type";
        SalesLine."e-Invoice Classification" := Item."e-Invoice Classification";
        SalesLine."e-Invoice UOM" := Item."e-Invoice UOM";
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnBeforeSalesInvLineInsert', '', false, false)]
    local procedure CopyLineFieldsToPostedInvoice(
        var SalesInvLine: Record "Sales Invoice Line";
        SalesLine: Record "Sales Line";
        SalesInvHeader: Record "Sales Invoice Header";
        CommitIsSuppressed: Boolean)
    begin
        SalesInvLine."e-Invoice Tax Type" := SalesLine."e-Invoice Tax Type";
        SalesInvLine."e-Invoice Classification" := SalesLine."e-Invoice Classification";
        SalesInvLine."e-Invoice UOM" := SalesLine."e-Invoice UOM";
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnAfterPostSalesDoc', '', false, false)]
    local procedure CopyHeaderFieldsToPostedInvoice(
        var SalesHeader: Record "Sales Header";
        var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line";
        SalesShptHdrNo: Code[20];
        RetRcpHdrNo: Code[20];
        SalesInvHdrNo: Code[20];
        SalesCrMemoHdrNo: Code[20])
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
    begin
        // Only process invoices (skip credit memos)
        if SalesInvHdrNo = '' then
            exit;

        if SalesInvoiceHeader.Get(SalesInvHdrNo) then begin
            SalesInvoiceHeader."eInvoice Document Type" := SalesHeader."eInvoice Document Type";
            SalesInvoiceHeader."eInvoice Payment Mode" := SalesHeader."eInvoice Payment Mode";
            SalesInvoiceHeader."eInvoice Currency Code" := SalesHeader."eInvoice Currency Code";
            SalesInvoiceHeader."eInvoice Version Code" := SalesHeader."eInvoice Version Code";
            SalesInvoiceHeader.Modify(true);
        end;
    end;
}