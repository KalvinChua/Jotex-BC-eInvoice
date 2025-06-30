codeunit 50305 "eInv Posting Subscribers"
{
    Permissions = tabledata "Sales Invoice Header" = M;

    // Event to copy header fields after posting is complete
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnAfterPostSalesDoc', '', false, false)]
    local procedure CopyEInvoiceHeaderFields(
        var SalesHeader: Record "Sales Header";
        var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line";
        SalesShptHdrNo: Code[20];
        RetRcpHdrNo: Code[20];
        SalesInvHdrNo: Code[20];
        SalesCrMemoHdrNo: Code[20])
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        TelemetryDimensions: Dictionary of [Text, Text];
    begin
        // Only process invoices (skip credit memos and other documents)
        if SalesInvHdrNo = '' then
            exit;

        // Find the posted invoice and update fields
        if SalesInvoiceHeader.Get(SalesInvHdrNo) then begin
            SalesInvoiceHeader."eInvoice Document Type" := SalesHeader."eInvoice Document Type";
            SalesInvoiceHeader."eInvoice Payment Mode" := SalesHeader."eInvoice Payment Mode";
            SalesInvoiceHeader."eInvoice Currency Code" := SalesHeader."eInvoice Currency Code";
            SalesInvoiceHeader."eInvoice Version Code" := SalesHeader."eInvoice Version Code";

            // Force the modification and commit immediately
            if not SalesInvoiceHeader.Modify(true) then begin
                TelemetryDimensions.Add('DocumentNo', SalesInvHdrNo);
                Session.LogMessage('0000EIV', 'Failed to update e-Invoice fields for posted invoice',
                    Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                    TelemetryDimensions);
            end;

            Commit();
        end;
    end;

    // Event to copy line fields during line insertion
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnBeforeSalesInvLineInsert', '', false, false)]
    local procedure CopyEInvoiceLineFields(
        var SalesInvLine: Record "Sales Invoice Line";
        SalesLine: Record "Sales Line";
        SalesInvHeader: Record "Sales Invoice Header";
        CommitIsSuppressed: Boolean)
    begin
        // Only copy fields for item and resource lines
        if SalesLine.Type in [SalesLine.Type::Item, SalesLine.Type::Resource] then begin
            SalesInvLine."e-Invoice Classification" := SalesLine."e-Invoice Classification";
            SalesInvLine."e-Invoice UOM" := SalesLine."e-Invoice UOM";
            SalesInvLine."e-Invoice Tax Type" := SalesLine."e-Invoice Tax Type";
        end;
    end;

    // Event to verify fields before posting
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnBeforePostSalesDoc', '', false, false)]
    local procedure VerifyEInvoiceFieldsBeforePosting(
        var SalesHeader: Record "Sales Header";
        var HideProgressWindow: Boolean;
        var IsHandled: Boolean)
    var
        Customer: Record Customer;
        SalesLine: Record "Sales Line";
        MissingFieldsErr: Label 'Missing e-Invoice fields for %1:\%2', Comment = '%1=Document No.,%2=Missing fields';
        MissingFields: Text;
    begin
        if IsHandled then
            exit;

        // Check customer requirements
        if Customer.Get(SalesHeader."Sell-to Customer No.") and Customer."Requires e-Invoice" then begin
            if SalesHeader."eInvoice Document Type" = '' then
                MissingFields := MissingFields + '\- Document Type';

            if SalesHeader."eInvoice Currency Code" = '' then
                MissingFields := MissingFields + '\- Currency Code';
        end;

        // Check lines
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetFilter(Type, '<>%1', SalesLine.Type::" ");
        if SalesLine.FindSet() then
            repeat
                if SalesLine."e-Invoice Classification" = '' then
                    MissingFields := MissingFields + '\- Line ' + Format(SalesLine."Line No.") + ' Classification';

                if SalesLine."e-Invoice UOM" = '' then
                    MissingFields := MissingFields + '\- Line ' + Format(SalesLine."Line No.") + ' UOM';

                if SalesLine."e-Invoice Tax Type" = '' then
                    MissingFields := MissingFields + '\- Line ' + Format(SalesLine."Line No.") + ' Tax Type';
            until SalesLine.Next() = 0;

        if MissingFields <> '' then
            Error(MissingFieldsErr, SalesHeader."No.", MissingFields);
    end;
}