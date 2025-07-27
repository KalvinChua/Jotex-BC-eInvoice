codeunit 50309 "eInv Field Population Handler"
{
    var
        CompanyInfoCache: Record "Company Information"; // Cache for company info
        LastCacheRefresh: DateTime; // Track when cache was last refreshed
        CacheValidityDuration: Duration; // How long cache is valid

    procedure CopyFieldsFromItemToSalesLines(SalesHeader: Record "Sales Header")
    var
        SalesLine: Record "Sales Line";
        Item: Record Item;
        ModifiedHeader: Boolean;
        CompanyInfo: Record "Company Information";
        ModifiedLines: List of [Integer]; // Track modified line numbers
    begin
        // Only process for JOTEX SDN BHD
        if not IsEInvoiceEnabled() then
            exit;

        // === Set Header Fields if Blank ===
        ModifiedHeader := SetDefaultHeaderFields(SalesHeader);

        if ModifiedHeader then
            SalesHeader.Modify();

        // === Update Sales Lines from Item ===
        UpdateSalesLinesFromItems(SalesHeader, ModifiedLines);

        // Log performance metrics
        LogFieldPopulationMetrics(SalesHeader."No.", ModifiedLines.Count);
    end;

    local procedure IsEInvoiceEnabled(): Boolean
    begin
        // Cache company info to avoid repeated database calls
        if CompanyInfoCache.Name = '' then begin
            if not CompanyInfoCache.Get() then
                exit(false);
        end;

        exit(CompanyInfoCache.Name = 'JOTEX SDN BHD');
    end;

    local procedure SetDefaultHeaderFields(var SalesHeader: Record "Sales Header"): Boolean
    var
        Modified: Boolean;
    begin
        // Set document type if blank
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
            Modified := true;
        end;

        // Set version if blank
        if SalesHeader."eInvoice Version Code" = '' then begin
            SalesHeader."eInvoice Version Code" := '1.1'; // Replace with your default version if needed
            Modified := true;
        end;

        exit(Modified);
    end;

    local procedure UpdateSalesLinesFromItems(SalesHeader: Record "Sales Header"; var ModifiedLines: List of [Integer])
    var
        SalesLine: Record "Sales Line";
        Item: Record Item;
        LineNo: Integer;
    begin
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");

        if SalesLine.FindSet() then
            repeat
                if SalesLine.Type = SalesLine.Type::Item then begin
                    if Item.Get(SalesLine."No.") then begin
                        // Only modify if fields are actually different
                        if (SalesLine."e-Invoice Tax Type" <> Item."e-Invoice Tax Type") or
                           (SalesLine."e-Invoice Classification" <> Item."e-Invoice Classification") or
                           (SalesLine."e-Invoice UOM" <> Item."e-Invoice UOM") then begin

                            SalesLine."e-Invoice Tax Type" := Item."e-Invoice Tax Type";
                            SalesLine."e-Invoice Classification" := Item."e-Invoice Classification";
                            SalesLine."e-Invoice UOM" := Item."e-Invoice UOM";
                            SalesLine.Modify();

                            ModifiedLines.Add(SalesLine."Line No.");
                        end;
                    end;
                end;
            until SalesLine.Next() = 0;
    end;

    local procedure LogFieldPopulationMetrics(DocumentNo: Code[20]; ModifiedLineCount: Integer)
    var
        TelemetryDimensions: Dictionary of [Text, Text];
    begin
        // Log performance metrics for monitoring
        TelemetryDimensions.Add('DocumentNo', DocumentNo);
        TelemetryDimensions.Add('ModifiedLines', Format(ModifiedLineCount));

        Session.LogMessage('0000EIV', StrSubstNo('Field population completed for document %1. Modified %2 lines.',
            DocumentNo, ModifiedLineCount),
            Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
            TelemetryDimensions);
    end;
}