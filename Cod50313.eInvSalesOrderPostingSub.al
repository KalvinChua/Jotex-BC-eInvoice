codeunit 50313 "eInv Sales Order Posting Sub"
{
    Permissions = tabledata "Sales Invoice Header" = M,
                  tabledata "Sales Cr.Memo Header" = M,
                  tabledata "eInvoice Submission Log" = M;

    // Event to handle e-Invoice submission for Sales Orders when posted with "Ship and Invoice"
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnAfterPostSalesDoc', '', false, false)]
    local procedure HandleSalesOrderEInvoiceSubmission(
        var SalesHeader: Record "Sales Header";
        var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line";
        SalesShptHdrNo: Code[20];
        RetRcpHdrNo: Code[20];
        SalesInvHdrNo: Code[20];
        SalesCrMemoHdrNo: Code[20])
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        Customer: Record Customer;
        eInvoiceJSONGenerator: Codeunit 50302;
        TelemetryDimensions: Dictionary of [Text, Text];
        CompanyInfo: Record "Company Information";
        LhdnResponse: Text;
        CustomerRequiresEInvoice: Boolean;
        PostingAction: Option Ship,Invoice,"Ship and Invoice";
    begin
        // Only process for JOTEX SDN BHD
        if not CompanyInfo.Get() or (CompanyInfo.Name <> 'JOTEX SDN BHD') then
            exit;

        // Only process Sales Orders that were posted with "Ship and Invoice"
        if SalesHeader."Document Type" <> SalesHeader."Document Type"::Order then
            exit;

        // Only process if an invoice was created (Ship and Invoice or Invoice only)
        if SalesInvHdrNo = '' then
            exit;

        // Find the posted invoice and update fields
        if SalesInvoiceHeader.Get(SalesInvHdrNo) then begin
            // Copy e-Invoice fields from Sales Order to Posted Invoice
            SalesInvoiceHeader."eInvoice Document Type" := SalesHeader."eInvoice Document Type";
            SalesInvoiceHeader."eInvoice Payment Mode" := SalesHeader."eInvoice Payment Mode";
            SalesInvoiceHeader."eInvoice Currency Code" := SalesHeader."eInvoice Currency Code";
            SalesInvoiceHeader."eInvoice Version Code" := SalesHeader."eInvoice Version Code";

            // Force the modification and commit immediately
            if not SalesInvoiceHeader.Modify(true) then begin
                TelemetryDimensions.Add('DocumentNo', SalesInvHdrNo);
                Session.LogMessage('0000EIV', 'Failed to update e-Invoice fields for posted invoice from Sales Order',
                    Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                    TelemetryDimensions);
            end;

            Commit();

            // Check if customer requires e-Invoice for auto-submission
            CustomerRequiresEInvoice := Customer.Get(SalesInvoiceHeader."Sell-to Customer No.") and Customer."Requires e-Invoice";

            // Auto-submit to LHDN if customer requires e-Invoice
            if CustomerRequiresEInvoice then begin
                // Wait a moment to ensure all data is committed
                Sleep(2000);

                if eInvoiceJSONGenerator.GetSignedInvoiceAndSubmitToLHDN(SalesInvoiceHeader, LhdnResponse) then begin
                    // Success - log the successful submission
                    Clear(TelemetryDimensions);
                    TelemetryDimensions.Add('SalesOrderNo', SalesHeader."No.");
                    TelemetryDimensions.Add('InvoiceNo', SalesInvHdrNo);
                    TelemetryDimensions.Add('CustomerNo', SalesInvoiceHeader."Sell-to Customer No.");
                    Session.LogMessage('0000EIV01', 'Automatic e-Invoice submission successful for Sales Order',
                        Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                        TelemetryDimensions);
                end else begin
                    // Failure - log the error but don't stop the posting process
                    Clear(TelemetryDimensions);
                    TelemetryDimensions.Add('SalesOrderNo', SalesHeader."No.");
                    TelemetryDimensions.Add('InvoiceNo', SalesInvHdrNo);
                    TelemetryDimensions.Add('Error', CopyStr(LhdnResponse, 1, 250));
                    Session.LogMessage('0000EIV02', 'Automatic e-Invoice submission failed for Sales Order',
                        Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                        TelemetryDimensions);
                end;
            end;
        end;
    end;

    // Event to verify e-Invoice fields before posting Sales Order
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnBeforePostSalesDoc', '', false, false)]
    local procedure VerifySalesOrderEInvoiceFieldsBeforePosting(
        var SalesHeader: Record "Sales Header";
        var HideProgressWindow: Boolean;
        var IsHandled: Boolean)
    var
        Customer: Record Customer;
        SalesLine: Record "Sales Line";
        MissingFieldsErr: Label 'Missing e-Invoice fields for Sales Order %1:\%2', Comment = '%1=Document No.,%2=Missing fields';
        MissingFields: Text;
        CompanyInfo: Record "Company Information";
    begin
        // Only process for JOTEX SDN BHD
        if not CompanyInfo.Get() or (CompanyInfo.Name <> 'JOTEX SDN BHD') then
            exit;

        // Only process Sales Orders
        if SalesHeader."Document Type" <> SalesHeader."Document Type"::Order then
            exit;

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

    // Event to copy line fields during line insertion for Sales Orders
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnBeforeSalesInvLineInsert', '', false, false)]
    local procedure CopySalesOrderEInvoiceLineFields(
        var SalesInvLine: Record "Sales Invoice Line";
        SalesLine: Record "Sales Line";
        SalesInvHeader: Record "Sales Invoice Header";
        CommitIsSuppressed: Boolean)
    var
        CompanyInfo: Record "Company Information";
    begin
        // Only process for JOTEX SDN BHD
        if not CompanyInfo.Get() or (CompanyInfo.Name <> 'JOTEX SDN BHD') then
            exit;

        // Only copy fields for item and resource lines
        if SalesLine.Type in [SalesLine.Type::Item, SalesLine.Type::Resource] then begin
            SalesInvLine."e-Invoice Classification" := SalesLine."e-Invoice Classification";
            SalesInvLine."e-Invoice UOM" := SalesLine."e-Invoice UOM";
            SalesInvLine."e-Invoice Tax Type" := SalesLine."e-Invoice Tax Type";
        end;
    end;
}