pageextension 50322 eInvSalesCrMemoFix extends "Sales Credit Memo"
{
    trigger OnOpenPage()
    begin
        // Force correct e-Invoice type for Credit Memo documents when page opens
        if Rec."Document Type" = Rec."Document Type"::"Credit Memo" then begin
            if Rec."eInvoice Document Type" <> '02' then begin
                Rec."eInvoice Document Type" := '02';
                Rec.Modify(true);
            end;
        end;
    end;
}


