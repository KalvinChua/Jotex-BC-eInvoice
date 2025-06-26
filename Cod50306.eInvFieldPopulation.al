codeunit 50306 "eInv Field Population"
{
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
    local procedure CopyToPostedInvoiceLine(
        var SalesInvLine: Record "Sales Invoice Line";
        SalesLine: Record "Sales Line";
        SalesInvHeader: Record "Sales Invoice Header";
        CommitIsSuppressed: Boolean)
    begin
        SalesInvLine."e-Invoice Tax Type" := SalesLine."e-Invoice Tax Type";
        SalesInvLine."e-Invoice Classification" := SalesLine."e-Invoice Classification";
        SalesInvLine."e-Invoice UOM" := SalesLine."e-Invoice UOM";
    end;
}
