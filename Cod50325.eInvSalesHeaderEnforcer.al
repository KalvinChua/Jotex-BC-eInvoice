codeunit 50325 "eInv Sales Header Enforcer"
{
    Subtype = Normal;

    local procedure EnsureCorrectEInvDocType(var SalesHeader: Record "Sales Header"): Boolean
    var
        originalValue: Code[20];
        newValue: Code[20];
    begin
        originalValue := SalesHeader."eInvoice Document Type";

        case SalesHeader."Document Type" of
            SalesHeader."Document Type"::Invoice:
                newValue := '01';
            SalesHeader."Document Type"::"Credit Memo":
                newValue := '02';
            else
                exit(false);
        end;

        if SalesHeader."eInvoice Document Type" <> newValue then begin
            SalesHeader."eInvoice Document Type" := newValue;
            exit(true);
        end;

        exit(false);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnAfterValidateEvent', 'Document Type', false, false)]
    local procedure SalesHeader_OnAfterValidate_DocumentType(var Rec: Record "Sales Header"; var xRec: Record "Sales Header"; CurrFieldNo: Integer)
    begin
        if EnsureCorrectEInvDocType(Rec) then
            Rec.Modify(false);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnAfterInsertEvent', '', false, false)]
    local procedure SalesHeader_OnAfterInsert(var Rec: Record "Sales Header"; RunTrigger: Boolean)
    begin
        if EnsureCorrectEInvDocType(Rec) then
            Rec.Modify(false);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnAfterModifyEvent', '', false, false)]
    local procedure SalesHeader_OnAfterModify(var Rec: Record "Sales Header"; var xRec: Record "Sales Header"; RunTrigger: Boolean)
    begin
        if EnsureCorrectEInvDocType(Rec) then
            Rec.Modify(false);
    end;
}


