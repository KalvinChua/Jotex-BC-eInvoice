codeunit 50302 "eInvoice 1.0 Invoice JSON"
{
    procedure GenerateEInvoiceJson(SalesInvoiceHeader: Record "Sales Invoice Header") JsonText: Text
    var
        JsonObject: JsonObject;
    begin
        JsonObject := BuildEInvoiceJson(SalesInvoiceHeader);
        JsonObject.WriteTo(JsonText);
    end;

    local procedure BuildEInvoiceJson(SalesInvoiceHeader: Record "Sales Invoice Header") JsonObject: JsonObject
    var
        InvoiceArray: JsonArray;
        InvoiceObject: JsonObject;
    begin
        // UBL 2.1 namespace declarations
        JsonObject.Add('_D', 'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2');
        JsonObject.Add('_A', 'urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2');
        JsonObject.Add('_B', 'urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2');

        // Build the invoice object
        InvoiceObject := CreateInvoiceObject(SalesInvoiceHeader);
        InvoiceArray.Add(InvoiceObject);
        JsonObject.Add('Invoice', InvoiceArray);
    end;

    local procedure CreateInvoiceObject(SalesInvoiceHeader: Record "Sales Invoice Header") InvoiceObject: JsonObject
    var
        Customer: Record Customer;
        CompanyInformation: Record "Company Information";
        CurrencyCode: Code[10];
    begin
        // Get currency code
        if SalesInvoiceHeader."Currency Code" = '' then
            CurrencyCode := 'MYR'
        else
            CurrencyCode := SalesInvoiceHeader."Currency Code";

        // Core invoice fields
        AddBasicField(InvoiceObject, 'ID', SalesInvoiceHeader."No.");
        AddBasicField(InvoiceObject, 'IssueDate', Format(SalesInvoiceHeader."Posting Date", 0, '<Year4>-<Month,2>-<Day,2>'));
        AddBasicField(InvoiceObject, 'IssueTime', Format(Time(), 0, '<Hours24,2>:<Minutes,2>:<Seconds,2>Z'));

        // Invoice type code with list version
        AddFieldWithAttribute(InvoiceObject, 'InvoiceTypeCode', '01', 'listVersionID', '1.1');

        // Currency codes
        AddBasicField(InvoiceObject, 'DocumentCurrencyCode', CurrencyCode);
        AddBasicField(InvoiceObject, 'TaxCurrencyCode', CurrencyCode);

        // Invoice period
        AddInvoicePeriod(InvoiceObject, SalesInvoiceHeader);

        // Billing reference (if applicable)
        AddBillingReference(InvoiceObject, SalesInvoiceHeader);

        // Additional document references
        AddAdditionalDocumentReferences(InvoiceObject, SalesInvoiceHeader);

        // Party information
        CompanyInformation.Get();
        AddAccountingSupplierParty(InvoiceObject, CompanyInformation);

        Customer.Get(SalesInvoiceHeader."Bill-to Customer No.");
        AddAccountingCustomerParty(InvoiceObject, Customer);

        // Delivery and shipment
        AddDelivery(InvoiceObject, Customer);

        // Payment information
        AddPaymentMeans(InvoiceObject);
        AddPaymentTerms(InvoiceObject);

        // Optional sections
        if HasPrepaidAmount(SalesInvoiceHeader) then
            AddPrepaidPayment(InvoiceObject, SalesInvoiceHeader);

        // Allowances and charges
        AddAllowanceCharges(InvoiceObject, SalesInvoiceHeader);

        // Tax calculations
        AddTaxTotals(InvoiceObject, SalesInvoiceHeader);

        // Monetary totals
        AddLegalMonetaryTotal(InvoiceObject, SalesInvoiceHeader);

        // Invoice lines
        AddInvoiceLines(InvoiceObject, SalesInvoiceHeader);
    end;

    local procedure AddInvoicePeriod(var InvoiceObject: JsonObject; SalesInvoiceHeader: Record "Sales Invoice Header")
    var
        PeriodArray: JsonArray;
        PeriodObject: JsonObject;
        StartDate: Date;
        EndDate: Date;
    begin
        // Calculate period based on posting date
        EndDate := SalesInvoiceHeader."Posting Date";
        StartDate := CalcDate('<-1M+1D>', EndDate); // Start of the month

        AddBasicField(PeriodObject, 'StartDate', Format(StartDate, 0, '<Year4>-<Month,2>-<Day,2>'));
        AddBasicField(PeriodObject, 'EndDate', Format(EndDate, 0, '<Year4>-<Month,2>-<Day,2>'));
        AddBasicField(PeriodObject, 'Description', 'Monthly');

        PeriodArray.Add(PeriodObject);
        InvoiceObject.Add('InvoicePeriod', PeriodArray);
    end;

    local procedure AddBillingReference(var InvoiceObject: JsonObject; SalesInvoiceHeader: Record "Sales Invoice Header")
    var
        BillingRefArray: JsonArray;
        BillingRefObject: JsonObject;
        AdditionalDocRefArray: JsonArray;
        DocRefObject: JsonObject;
    begin
        // Only add if there's a reference document
        if SalesInvoiceHeader."External Document No." <> '' then begin
            AddBasicField(DocRefObject, 'ID', SalesInvoiceHeader."External Document No.");
            AdditionalDocRefArray.Add(DocRefObject);
            BillingRefObject.Add('AdditionalDocumentReference', AdditionalDocRefArray);
            BillingRefArray.Add(BillingRefObject);
            InvoiceObject.Add('BillingReference', BillingRefArray);
        end;
    end;

    local procedure AddAdditionalDocumentReferences(var InvoiceObject: JsonObject; SalesInvoiceHeader: Record "Sales Invoice Header")
    var
        AdditionalDocArray: JsonArray;
        RefObject: JsonObject;
    begin
        // Add any additional document references based on your business requirements
        // This is optional - only add if you have additional references

        // Example: Customs forms, permits, etc.
        // Clear(RefObject);
        // AddBasicField(RefObject, 'ID', 'CustomsForm123');
        // AddBasicField(RefObject, 'DocumentType', 'CustomsImportForm');
        // AdditionalDocArray.Add(RefObject);

        if AdditionalDocArray.Count > 0 then
            InvoiceObject.Add('AdditionalDocumentReference', AdditionalDocArray);
    end;

    local procedure AddAccountingSupplierParty(var InvoiceObject: JsonObject; CompanyInfo: Record "Company Information")
    var
        SupplierArray: JsonArray;
        SupplierObject: JsonObject;
        PartyObject: JsonObject;
        PartyIdentificationArray: JsonArray;
        PostalAddressObject: JsonObject;
        ContactObject: JsonObject;
        PartyLegalEntityArray: JsonArray;
        PartyLegalEntityObject: JsonObject;
        IndustryClassificationObject: JsonObject;
    begin
        // Industry classification (MSIC code)
        AddBasicFieldWithAttribute(IndustryClassificationObject, '_', GetMSICCode(), 'name', GetMSICDescription());

        // Party identification (TIN, BRN, SST, TTX)
        AddPartyIdentification(PartyIdentificationArray, CompanyInfo."VAT Registration No.", 'TIN');
        AddPartyIdentification(PartyIdentificationArray, CompanyInfo."Registration No.", 'BRN');
        AddPartyIdentification(PartyIdentificationArray, GetSSTNumber(), 'SST');
        AddPartyIdentification(PartyIdentificationArray, GetTTXNumber(), 'TTX');

        // Legal entity information
        AddBasicField(PartyLegalEntityObject, 'RegistrationName', CompanyInfo.Name);
        PartyLegalEntityArray.Add(PartyLegalEntityObject);

        // Postal address
        AddBasicField(PostalAddressObject, 'CityName', CompanyInfo.City);
        AddBasicField(PostalAddressObject, 'PostalZone', CompanyInfo."Post Code");
        AddBasicField(PostalAddressObject, 'CountrySubentityCode', GetStateCode(CompanyInfo.County));
        AddAddressLines(PostalAddressObject, CompanyInfo.Address, CompanyInfo."Address 2", '');
        AddCountry(PostalAddressObject, GetCountryCode(CompanyInfo."Country/Region Code"));

        // Contact information
        AddBasicField(ContactObject, 'Telephone', CompanyInfo."Phone No.");
        AddBasicField(ContactObject, 'ElectronicMail', CompanyInfo."E-Mail");

        // Build party object
        PartyObject.Add('IndustryClassificationCode', IndustryClassificationObject);
        PartyObject.Add('PartyIdentification', PartyIdentificationArray);
        PartyObject.Add('PartyLegalEntity', PartyLegalEntityArray);
        PartyObject.Add('PostalAddress', PostalAddressObject);
        PartyObject.Add('Contact', ContactObject);

        // Optional: Additional account ID (for certifications)
        // AddAdditionalAccountID(SupplierObject);

        SupplierObject.Add('Party', PartyObject);
        SupplierArray.Add(SupplierObject);
        InvoiceObject.Add('AccountingSupplierParty', SupplierArray);
    end;

    local procedure AddAccountingCustomerParty(var InvoiceObject: JsonObject; Customer: Record Customer)
    var
        CustomerArray: JsonArray;
        CustomerObject: JsonObject;
        PartyObject: JsonObject;
        PartyIdentificationArray: JsonArray;
        PostalAddressObject: JsonObject;
        ContactObject: JsonObject;
        PartyLegalEntityArray: JsonArray;
        PartyLegalEntityObject: JsonObject;
    begin
        // Party identification
        AddPartyIdentification(PartyIdentificationArray, Customer."VAT Registration No.", 'TIN');
        AddPartyIdentification(PartyIdentificationArray, Customer."Registration Number", 'BRN');
        AddPartyIdentification(PartyIdentificationArray, GetCustomerSSTNumber(Customer), 'SST');
        AddPartyIdentification(PartyIdentificationArray, GetCustomerTTXNumber(Customer), 'TTX');

        // Legal entity
        AddBasicField(PartyLegalEntityObject, 'RegistrationName', Customer.Name);
        PartyLegalEntityArray.Add(PartyLegalEntityObject);

        // Postal address
        AddBasicField(PostalAddressObject, 'CityName', Customer.City);
        AddBasicField(PostalAddressObject, 'PostalZone', Customer."Post Code");
        AddBasicField(PostalAddressObject, 'CountrySubentityCode', GetStateCode(Customer.County));
        AddAddressLines(PostalAddressObject, Customer.Address, Customer."Address 2", '');
        AddCountry(PostalAddressObject, GetCountryCode(Customer."Country/Region Code"));

        // Contact information
        AddBasicField(ContactObject, 'Telephone', Customer."Phone No.");
        AddBasicField(ContactObject, 'ElectronicMail', Customer."E-Mail");

        // Build party object
        PartyObject.Add('PartyIdentification', PartyIdentificationArray);
        PartyObject.Add('PartyLegalEntity', PartyLegalEntityArray);
        PartyObject.Add('PostalAddress', PostalAddressObject);
        PartyObject.Add('Contact', ContactObject);

        CustomerObject.Add('Party', PartyObject);
        CustomerArray.Add(CustomerObject);
        InvoiceObject.Add('AccountingCustomerParty', CustomerArray);
    end;

    local procedure AddDelivery(var InvoiceObject: JsonObject; Customer: Record Customer)
    var
        DeliveryArray: JsonArray;
        DeliveryObject: JsonObject;
        DeliveryPartyObject: JsonObject;
        PartyIdentificationArray: JsonArray;
        PostalAddressObject: JsonObject;
        PartyLegalEntityObject: JsonObject;
        PartyLegalEntityArray: JsonArray;
        ShipmentArray: JsonArray;
        ShipmentObject: JsonObject;
    begin
        // Delivery party identification
        AddPartyIdentification(PartyIdentificationArray, Customer."VAT Registration No.", 'TIN');
        AddPartyIdentification(PartyIdentificationArray, Customer."Registration Number", 'BRN');

        // Legal entity
        AddBasicField(PartyLegalEntityObject, 'RegistrationName', Customer.Name);
        PartyLegalEntityArray.Add(PartyLegalEntityObject);

        // Delivery address (use ship-to if available, otherwise bill-to)
        AddBasicField(PostalAddressObject, 'CityName', Customer.City);
        AddBasicField(PostalAddressObject, 'PostalZone', Customer."Post Code");
        AddBasicField(PostalAddressObject, 'CountrySubentityCode', GetStateCode(Customer.County));
        AddAddressLines(PostalAddressObject, Customer.Address, Customer."Address 2", '');
        AddCountry(PostalAddressObject, GetCountryCode(Customer."Country/Region Code"));

        DeliveryPartyObject.Add('PartyIdentification', PartyIdentificationArray);
        DeliveryPartyObject.Add('PartyLegalEntity', PartyLegalEntityArray);
        DeliveryPartyObject.Add('PostalAddress', PostalAddressObject);

        // Optional: Shipment information
        AddShipmentInfo(ShipmentArray);
        if ShipmentArray.Count > 0 then
            DeliveryObject.Add('Shipment', ShipmentArray);

        DeliveryObject.Add('DeliveryParty', DeliveryPartyObject);
        DeliveryArray.Add(DeliveryObject);
        InvoiceObject.Add('Delivery', DeliveryArray);
    end;

    local procedure AddShipmentInfo(var ShipmentArray: JsonArray)
    var
        ShipmentObject: JsonObject;
        FreightChargeArray: JsonArray;
        FreightChargeObject: JsonObject;
        ChargeIndicatorArray: JsonArray;
        ChargeIndicatorObject: JsonObject;
    begin
        // Only add shipment if there are freight charges
        // This is optional based on your business needs

        // Example freight charge
        // AddBasicField(ShipmentObject, 'ID', 'SHIP001');
        // 
        // ChargeIndicatorObject.Add('_', true);
        // ChargeIndicatorArray.Add(ChargeIndicatorObject);
        // FreightChargeObject.Add('ChargeIndicator', ChargeIndicatorArray);
        // AddBasicField(FreightChargeObject, 'AllowanceChargeReason', 'Shipping Fee');
        // AddAmountField(FreightChargeObject, 'Amount', 50.00, 'MYR');
        // 
        // FreightChargeArray.Add(FreightChargeObject);
        // ShipmentObject.Add('FreightAllowanceCharge', FreightChargeArray);
        // ShipmentArray.Add(ShipmentObject);
    end;

    local procedure AddPaymentMeans(var InvoiceObject: JsonObject)
    var
        PaymentMeansArray: JsonArray;
        PaymentMeansObject: JsonObject;
        PayeeAccountObject: JsonObject;
        PayeeAccountArray: JsonArray;
    begin
        // Payment means code (03 = Cash, 01 = Bank Transfer, etc.)
        AddBasicField(PaymentMeansObject, 'PaymentMeansCode', '01'); // Bank transfer

        // Payee financial account (optional)
        AddBasicField(PayeeAccountObject, 'ID', GetBankAccountNumber());
        PayeeAccountArray.Add(PayeeAccountObject);
        PaymentMeansObject.Add('PayeeFinancialAccount', PayeeAccountArray);

        PaymentMeansArray.Add(PaymentMeansObject);
        InvoiceObject.Add('PaymentMeans', PaymentMeansArray);
    end;

    local procedure AddPaymentTerms(var InvoiceObject: JsonObject)
    var
        PaymentTermsArray: JsonArray;
        PaymentTermsObject: JsonObject;
    begin
        AddBasicField(PaymentTermsObject, 'Note', GetPaymentTermsNote());
        PaymentTermsArray.Add(PaymentTermsObject);
        InvoiceObject.Add('PaymentTerms', PaymentTermsArray);
    end;

    local procedure AddPrepaidPayment(var InvoiceObject: JsonObject; SalesInvoiceHeader: Record "Sales Invoice Header")
    var
        PrepaidArray: JsonArray;
        PrepaidObject: JsonObject;
        PrepaidAmount: Decimal;
    begin
        PrepaidAmount := GetPrepaidAmount(SalesInvoiceHeader);
        if PrepaidAmount > 0 then begin
            AddBasicField(PrepaidObject, 'ID', SalesInvoiceHeader."No." + '-PREPAID');
            AddAmountField(PrepaidObject, 'PaidAmount', PrepaidAmount, GetCurrencyCode(SalesInvoiceHeader));
            AddBasicField(PrepaidObject, 'PaidDate', Format(SalesInvoiceHeader."Posting Date", 0, '<Year4>-<Month,2>-<Day,2>'));
            AddBasicField(PrepaidObject, 'PaidTime', Format(Time(), 0, '<Hours24,2>:<Minutes,2>:<Seconds,2>Z'));

            PrepaidArray.Add(PrepaidObject);
            InvoiceObject.Add('PrepaidPayment', PrepaidArray);
        end;
    end;

    local procedure AddAllowanceCharges(var InvoiceObject: JsonObject; SalesInvoiceHeader: Record "Sales Invoice Header")
    var
        AllowanceArray: JsonArray;
        ChargeObject: JsonObject;
        SalesLine: Record "Sales Invoice Line";
        DiscountAmount: Decimal;
        ChargeAmount: Decimal;
    begin
        // Calculate total discount and charges from invoice lines
        SalesLine.SetRange("Document No.", SalesInvoiceHeader."No.");
        if SalesLine.FindSet() then
            repeat
                DiscountAmount += SalesLine."Line Discount Amount";
            // Add any additional charges if applicable
            until SalesLine.Next() = 0;

        // Add discount as allowance
        if DiscountAmount > 0 then begin
            Clear(ChargeObject);
            AddBasicField(ChargeObject, 'ChargeIndicator', 'false');
            AddBasicField(ChargeObject, 'AllowanceChargeReason', 'Discount');
            AddAmountField(ChargeObject, 'Amount', DiscountAmount, GetCurrencyCode(SalesInvoiceHeader));
            AllowanceArray.Add(ChargeObject);
        end;

        // Add any charges if applicable
        if ChargeAmount > 0 then begin
            Clear(ChargeObject);
            AddBasicField(ChargeObject, 'ChargeIndicator', 'true');
            AddBasicField(ChargeObject, 'AllowanceChargeReason', 'Service Charge');
            AddAmountField(ChargeObject, 'Amount', ChargeAmount, GetCurrencyCode(SalesInvoiceHeader));
            AllowanceArray.Add(ChargeObject);
        end;

        if AllowanceArray.Count > 0 then
            InvoiceObject.Add('AllowanceCharge', AllowanceArray);
    end;

    local procedure AddTaxTotals(var InvoiceObject: JsonObject; SalesInvoiceHeader: Record "Sales Invoice Header")
    var
        TaxTotalArray: JsonArray;
        TaxTotalObject: JsonObject;
        TaxSubtotalArray: JsonArray;
        TaxSubtotalObject: JsonObject;
        TaxCategoryObject: JsonObject;
        TaxSchemeArray: JsonArray;
        TaxSchemeObject: JsonObject;
        TotalTaxAmount: Decimal;
        TaxableAmount: Decimal;
        SalesLine: Record "Sales Invoice Line";
    begin
        // Calculate tax amounts from invoice lines
        SalesLine.SetRange("Document No.", SalesInvoiceHeader."No.");
        SalesLine.SetFilter("VAT %", '>0');
        if SalesLine.FindSet() then
            repeat
                TotalTaxAmount += SalesLine."Amount Including VAT" - SalesLine.Amount;
                TaxableAmount += SalesLine.Amount;
            until SalesLine.Next() = 0;

        if TotalTaxAmount > 0 then begin
            AddAmountField(TaxTotalObject, 'TaxAmount', TotalTaxAmount, GetCurrencyCode(SalesInvoiceHeader));

            // Tax subtotal
            AddAmountField(TaxSubtotalObject, 'TaxableAmount', TaxableAmount, GetCurrencyCode(SalesInvoiceHeader));
            AddAmountField(TaxSubtotalObject, 'TaxAmount', TotalTaxAmount, GetCurrencyCode(SalesInvoiceHeader));

            // Tax category
            AddBasicField(TaxCategoryObject, 'ID', GetTaxCategoryCode(SalesLine."VAT %"));

            // Tax scheme
            AddBasicFieldWithAttributes(TaxSchemeObject, 'ID', 'OTH', 'schemeID', 'UN/ECE 5153', 'schemeAgencyID', '6');
            TaxSchemeArray.Add(TaxSchemeObject);
            TaxCategoryObject.Add('TaxScheme', TaxSchemeArray);

            TaxSubtotalObject.Add('TaxCategory', TaxCategoryObject);
            TaxSubtotalArray.Add(TaxSubtotalObject);
            TaxTotalObject.Add('TaxSubtotal', TaxSubtotalArray);

            TaxTotalArray.Add(TaxTotalObject);
            InvoiceObject.Add('TaxTotal', TaxTotalArray);
        end;
    end;

    local procedure AddLegalMonetaryTotal(var InvoiceObject: JsonObject; SalesInvoiceHeader: Record "Sales Invoice Header")
    var
        LegalTotalArray: JsonArray;
        LegalTotalObject: JsonObject;
        LineExtensionAmount: Decimal;
        TaxExclusiveAmount: Decimal;
        TaxInclusiveAmount: Decimal;
        AllowanceTotalAmount: Decimal;
        ChargeTotalAmount: Decimal;
        PayableAmount: Decimal;
        SalesLine: Record "Sales Invoice Line";
    begin
        // Calculate amounts from invoice lines
        SalesLine.SetRange("Document No.", SalesInvoiceHeader."No.");
        if SalesLine.FindSet() then
            repeat
                LineExtensionAmount += SalesLine.Amount;
                AllowanceTotalAmount += SalesLine."Line Discount Amount";
            until SalesLine.Next() = 0;

        TaxExclusiveAmount := LineExtensionAmount - AllowanceTotalAmount + ChargeTotalAmount;
        TaxInclusiveAmount := SalesInvoiceHeader."Amount Including VAT";
        PayableAmount := TaxInclusiveAmount;

        AddAmountField(LegalTotalObject, 'LineExtensionAmount', LineExtensionAmount, GetCurrencyCode(SalesInvoiceHeader));
        AddAmountField(LegalTotalObject, 'TaxExclusiveAmount', TaxExclusiveAmount, GetCurrencyCode(SalesInvoiceHeader));
        AddAmountField(LegalTotalObject, 'TaxInclusiveAmount', TaxInclusiveAmount, GetCurrencyCode(SalesInvoiceHeader));

        if AllowanceTotalAmount > 0 then
            AddAmountField(LegalTotalObject, 'AllowanceTotalAmount', AllowanceTotalAmount, GetCurrencyCode(SalesInvoiceHeader));

        if ChargeTotalAmount > 0 then
            AddAmountField(LegalTotalObject, 'ChargeTotalAmount', ChargeTotalAmount, GetCurrencyCode(SalesInvoiceHeader));

        AddAmountField(LegalTotalObject, 'PayableAmount', PayableAmount, GetCurrencyCode(SalesInvoiceHeader));

        LegalTotalArray.Add(LegalTotalObject);
        InvoiceObject.Add('LegalMonetaryTotal', LegalTotalArray);
    end;

    local procedure AddInvoiceLines(var InvoiceObject: JsonObject; SalesInvoiceHeader: Record "Sales Invoice Header")
    var
        LineArray: JsonArray;
        SalesInvoiceLine: Record "Sales Invoice Line";
    begin
        SalesInvoiceLine.SetRange("Document No.", SalesInvoiceHeader."No.");
        SalesInvoiceLine.SetFilter(Type, '<>%1', SalesInvoiceLine.Type::" ");
        if SalesInvoiceLine.FindSet() then
            repeat
                AddInvoiceLine(LineArray, SalesInvoiceLine, SalesInvoiceHeader."Currency Code");
            until SalesInvoiceLine.Next() = 0;
        InvoiceObject.Add('InvoiceLine', LineArray);
    end;

    local procedure AddInvoiceLine(var LineArray: JsonArray; SalesInvoiceLine: Record "Sales Invoice Line"; CurrencyCode: Code[10])
    var
        LineObject: JsonObject;
        TaxTotalArray: JsonArray;
        TaxTotalObject: JsonObject;
        TaxSubtotalArray: JsonArray;
        TaxSubtotalObject: JsonObject;
        TaxCategoryObject: JsonObject;
        TaxSchemeArray: JsonArray;
        TaxSchemeObject: JsonObject;
        ItemArray: JsonArray;
        ItemObject: JsonObject;
        PriceArray: JsonArray;
        PriceObject: JsonObject;
        AllowanceChargeArray: JsonArray;
        CommodityArray: JsonArray;
        OriginCountryArray: JsonArray;
        OriginCountryObject: JsonObject;
        UnitCode: Code[10];
    begin
        // Line ID and quantity
        AddBasicField(LineObject, 'ID', Format(SalesInvoiceLine."Line No."));

        UnitCode := GetUBLUnitCode(SalesInvoiceLine."Unit of Measure Code");
        AddQuantityField(LineObject, 'InvoicedQuantity', SalesInvoiceLine.Quantity, UnitCode);
        AddAmountField(LineObject, 'LineExtensionAmount', SalesInvoiceLine.Amount, GetCurrencyCode(CurrencyCode));

        // Line allowances/charges
        if SalesInvoiceLine."Line Discount Amount" > 0 then
            AddLineAllowanceCharge(AllowanceChargeArray, false, 'Discount',
                SalesInvoiceLine."Line Discount %", SalesInvoiceLine."Line Discount Amount", GetCurrencyCode(CurrencyCode));

        if AllowanceChargeArray.Count > 0 then
            LineObject.Add('AllowanceCharge', AllowanceChargeArray);

        // Tax total for line
        if SalesInvoiceLine."VAT %" > 0 then begin
            AddAmountField(TaxTotalObject, 'TaxAmount', SalesInvoiceLine."Amount Including VAT" - SalesInvoiceLine.Amount, GetCurrencyCode(CurrencyCode));

            // Tax subtotal
            AddAmountField(TaxSubtotalObject, 'TaxableAmount', SalesInvoiceLine.Amount, GetCurrencyCode(CurrencyCode));
            AddAmountField(TaxSubtotalObject, 'TaxAmount', SalesInvoiceLine."Amount Including VAT" - SalesInvoiceLine.Amount, GetCurrencyCode(CurrencyCode));
            AddBasicField(TaxSubtotalObject, 'Percent', Format(SalesInvoiceLine."VAT %", 0, '<Precision,2:2><Standard Format,2>'));

            // Tax category
            AddBasicField(TaxCategoryObject, 'ID', GetTaxCategoryCode(SalesInvoiceLine."VAT %"));

            // Tax scheme
            AddBasicFieldWithAttributes(TaxSchemeObject, 'ID', 'OTH', 'schemeID', 'UN/ECE 5153', 'schemeAgencyID', '6');
            TaxSchemeArray.Add(TaxSchemeObject);
            TaxCategoryObject.Add('TaxScheme', TaxSchemeArray);

            TaxSubtotalObject.Add('TaxCategory', TaxCategoryObject);
            TaxSubtotalArray.Add(TaxSubtotalObject);
            TaxTotalObject.Add('TaxSubtotal', TaxSubtotalArray);

            TaxTotalArray.Add(TaxTotalObject);
            LineObject.Add('TaxTotal', TaxTotalArray);
        end;

        // Item information
        AddBasicField(ItemObject, 'Description', SalesInvoiceLine.Description);

        // Commodity classification (optional)
        AddCommodityClassification(CommodityArray, GetHSCode(SalesInvoiceLine), 'PTC');
        if CommodityArray.Count > 0 then
            ItemObject.Add('CommodityClassification', CommodityArray);

        // Origin country (optional)
        AddBasicField(OriginCountryObject, 'IdentificationCode', 'MYS');
        OriginCountryArray.Add(OriginCountryObject);
        ItemObject.Add('OriginCountry', OriginCountryArray);

        ItemArray.Add(ItemObject);
        LineObject.Add('Item', ItemArray);

        // Price
        AddAmountField(PriceObject, 'PriceAmount', SalesInvoiceLine."Unit Price", GetCurrencyCode(CurrencyCode));
        PriceArray.Add(PriceObject);
        LineObject.Add('Price', PriceArray);

        LineArray.Add(LineObject);
    end;

    // Helper procedures for UBL 2.1 JSON structure
    local procedure AddBasicField(var ParentObject: JsonObject; FieldName: Text; FieldValue: Text)
    var
        ValueArray: JsonArray;
        ValueObject: JsonObject;
    begin
        if FieldValue <> '' then begin
            ValueObject.Add('_', FieldValue);
            ValueArray.Add(ValueObject);
            ParentObject.Add(FieldName, ValueArray);
        end;
    end;

    local procedure AddFieldWithAttribute(var ParentObject: JsonObject; FieldName: Text; FieldValue: Text; AttributeName: Text; AttributeValue: Text)
    var
        ValueArray: JsonArray;
        ValueObject: JsonObject;
    begin
        if FieldValue <> '' then begin
            ValueObject.Add('_', FieldValue);
            ValueObject.Add(AttributeName, AttributeValue);
            ValueArray.Add(ValueObject);
            ParentObject.Add(FieldName, ValueArray);
        end;
    end;

    local procedure AddBasicFieldWithAttribute(var ParentObject: JsonObject; FieldName: Text; FieldValue: Text; AttributeName: Text; AttributeValue: Text)
    begin
        AddFieldWithAttribute(ParentObject, FieldName, FieldValue, AttributeName, AttributeValue);
    end;

    local procedure AddBasicFieldWithAttributes(var ParentObject: JsonObject; FieldName: Text; FieldValue: Text; Attr1Name: Text; Attr1Value: Text; Attr2Name: Text; Attr2Value: Text)
    var
        ValueArray: JsonArray;
        ValueObject: JsonObject;
    begin
        if FieldValue <> '' then begin
            ValueObject.Add('_', FieldValue);
            ValueObject.Add(Attr1Name, Attr1Value);
            ValueObject.Add(Attr2Name, Attr2Value);
            ValueArray.Add(ValueObject);
            ParentObject.Add(FieldName, ValueArray);
        end;
    end;

    local procedure AddAmountField(var ParentObject: JsonObject; FieldName: Text; Amount: Decimal; CurrencyCode: Text)
    var
        ValueArray: JsonArray;
        ValueObject: JsonObject;
    begin
        ValueObject.Add('_', Amount);
        ValueObject.Add('currencyID', CurrencyCode);
        ValueArray.Add(ValueObject);
        ParentObject.Add(FieldName, ValueArray);
    end;

    local procedure AddQuantityField(var ParentObject: JsonObject; FieldName: Text; Quantity: Decimal; UnitCode: Text)
    var
        ValueArray: JsonArray;
        ValueObject: JsonObject;
    begin
        ValueObject.Add('_', Quantity);
        ValueObject.Add('unitCode', UnitCode);
        ValueArray.Add(ValueObject);
        ParentObject.Add(FieldName, ValueArray);
    end;

    local procedure AddPartyIdentification(var PartyIdentificationArray: JsonArray; ID: Text; SchemeID: Text)
    var
        IDObject: JsonObject;
        IDArray: JsonArray;
        IDValueObject: JsonObject;
    begin
        if ID <> '' then begin
            IDValueObject.Add('_', ID);
            IDValueObject.Add('schemeID', SchemeID);
            IDArray.Add(IDValueObject);
            IDObject.Add('ID', IDArray);
            PartyIdentificationArray.Add(IDObject);
        end;
    end;

    local procedure AddAddressLines(var PostalAddressObject: JsonObject; Address1: Text; Address2: Text; Address3: Text)
    var
        AddressLineArray: JsonArray;
        LineObject: JsonObject;
        LineArray: JsonArray;
        LineValueObject: JsonObject;
    begin
        if Address1 <> '' then begin
            Clear(LineArray);
            Clear(LineValueObject);
            LineValueObject.Add('_', Address1);
            LineArray.Add(LineValueObject);
            LineObject.Add('Line', LineArray);
            AddressLineArray.Add(LineObject);
        end;

        if Address2 <> '' then begin
            Clear(LineObject);
            Clear(LineArray);
            Clear(LineValueObject);
            LineValueObject.Add('_', Address2);
            LineArray.Add(LineValueObject);
            LineObject.Add('Line', LineArray);
            AddressLineArray.Add(LineObject);
        end;

        if Address3 <> '' then begin
            Clear(LineObject);
            Clear(LineArray);
            Clear(LineValueObject);
            LineValueObject.Add('_', Address3);
            LineArray.Add(LineValueObject);
            LineObject.Add('Line', LineArray);
            AddressLineArray.Add(LineObject);
        end;

        if AddressLineArray.Count > 0 then
            PostalAddressObject.Add('AddressLine', AddressLineArray);
    end;

    local procedure AddCountry(var PostalAddressObject: JsonObject; CountryCode: Code[10])
    var
        CountryArray: JsonArray;
        CountryObject: JsonObject;
        IdentificationCodeArray: JsonArray;
        IdentificationCodeObject: JsonObject;
    begin
        IdentificationCodeObject.Add('_', CountryCode);
        IdentificationCodeObject.Add('listID', 'ISO3166-1');
        IdentificationCodeObject.Add('listAgencyID', '6');
        IdentificationCodeArray.Add(IdentificationCodeObject);
        CountryObject.Add('IdentificationCode', IdentificationCodeArray);
        CountryArray.Add(CountryObject);
        PostalAddressObject.Add('Country', CountryArray);
    end;

    local procedure AddLineAllowanceCharge(var AllowanceChargeArray: JsonArray; IsCharge: Boolean; Reason: Text; Percentage: Decimal; Amount: Decimal; CurrencyCode: Text)
    var
        AllowanceCharge: JsonObject;
    begin
        AddBasicField(AllowanceCharge, 'ChargeIndicator', Format(IsCharge));
        AddBasicField(AllowanceCharge, 'AllowanceChargeReason', Reason);
        if Percentage > 0 then
            AddBasicField(AllowanceCharge, 'MultiplierFactorNumeric', Format(Percentage / 100, 0, '<Precision,2:2><Standard Format,2>'));
        AddAmountField(AllowanceCharge, 'Amount', Amount, CurrencyCode);
        AllowanceChargeArray.Add(AllowanceCharge);
    end;

    local procedure AddCommodityClassification(var CommodityArray: JsonArray; Code: Text; ListID: Text)
    var
        ClassificationObject: JsonObject;
    begin
        if Code <> '' then begin
            AddFieldWithAttribute(ClassificationObject, 'ItemClassificationCode', Code, 'listID', ListID);
            CommodityArray.Add(ClassificationObject);
        end;
    end;

    // Business logic helper functions (customize these based on your setup)
    local procedure GetCurrencyCode(SalesInvoiceHeader: Record "Sales Invoice Header"): Code[10]
    begin
        if SalesInvoiceHeader."Currency Code" = '' then
            exit('MYR')
        else
            exit(SalesInvoiceHeader."Currency Code");
    end;

    local procedure GetCurrencyCode(CurrencyCode: Code[10]): Code[10]
    begin
        if CurrencyCode = '' then
            exit('MYR')
        else
            exit(CurrencyCode);
    end;

    local procedure GetUBLUnitCode(UOM: Code[10]): Code[10]
    begin
        case UpperCase(UOM) of
            'PCS', 'PC', 'PIECE':
                exit('C62');
            'BOX':
                exit('BX');
            'KG', 'KILOGRAM':
                exit('KGM');
            'L', 'LITER', 'LITRE':
                exit('LTR');
            'M', 'METER', 'METRE':
                exit('MTR');
            'SET':
                exit('SET');
            'PKT', 'PACKET':
                exit('PK');
            'HOUR', 'HR':
                exit('HUR');
            else
                exit('C62'); // Default to pieces
        end;
    end;

    local procedure GetStateCode(County: Text): Text
    begin
        case County of
            'Johor':
                exit('01');
            'Kedah':
                exit('02');
            'Kelantan':
                exit('03');
            'Melaka', 'Malacca':
                exit('04');
            'Negeri Sembilan':
                exit('05');
            'Pahang':
                exit('06');
            'Pulau Pinang', 'Penang':
                exit('07');
            'Perak':
                exit('08');
            'Perlis':
                exit('09');
            'Selangor':
                exit('10');
            'Terengganu':
                exit('11');
            'Sabah':
                exit('12');
            'Sarawak':
                exit('13');
            'Wilayah Persekutuan Kuala Lumpur', 'Kuala Lumpur':
                exit('14');
            'Wilayah Persekutuan Labuan', 'Labuan':
                exit('15');
            'Wilayah Persekutuan Putrajaya', 'Putrajaya':
                exit('16');
            else
                exit('14'); // Default to KL
        end;
    end;

    local procedure GetCountryCode(CountryRegionCode: Code[10]): Code[10]
    begin
        if CountryRegionCode = 'MY' then
            exit('MYS');
        // Add more country mappings as needed
        exit('MYS'); // Default to Malaysia
    end;

    local procedure GetTaxCategoryCode(VATPercent: Decimal): Code[10]
    begin
        case VATPercent of
            0:
                exit('E'); // Exempt
            6:
                exit('01'); // Standard rate
            else
                exit('01'); // Default to standard
        end;
    end;

    local procedure GetMSICCode(): Text
    begin
        // Return your company's MSIC code - customize this
        exit('46510');
    end;

    local procedure GetMSICDescription(): Text
    begin
        // Return your company's MSIC description - customize this
        exit('Wholesale of computer hardware, software and peripherals');
    end;

    local procedure GetSSTNumber(): Text
    begin
        // Return SST registration number if applicable
        exit('NA');
    end;

    local procedure GetTTXNumber(): Text
    begin
        // Return Tourism Tax registration number if applicable
        exit('NA');
    end;

    local procedure GetCustomerSSTNumber(Customer: Record Customer): Text
    begin
        // Return customer's SST number if available
        exit('NA');
    end;

    local procedure GetCustomerTTXNumber(Customer: Record Customer): Text
    begin
        // Return customer's TTX number if available
        exit('NA');
    end;

    local procedure GetBankAccountNumber(): Text
    begin
        // Return your bank account number for payments
        exit('1234567890123');
    end;

    local procedure GetPaymentTermsNote(): Text
    begin
        // Return payment terms description
        exit('Payment due within 30 days');
    end;

    local procedure GetHSCode(SalesInvoiceLine: Record "Sales Invoice Line"): Text
    begin
        // Return HS code for the item - customize based on your item setup
        exit('9800.00.0010');
    end;

    local procedure HasPrepaidAmount(SalesInvoiceHeader: Record "Sales Invoice Header"): Boolean
    begin
        // Check if there are any prepaid amounts
        exit(false);
    end;

    local procedure GetPrepaidAmount(SalesInvoiceHeader: Record "Sales Invoice Header"): Decimal
    begin
        // Return prepaid amount if any
        exit(0);
    end;
}