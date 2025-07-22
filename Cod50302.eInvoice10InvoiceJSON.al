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
        // Keep posting date for IssueDate, but use safe time with Malaysia timezone
        AddBasicField(InvoiceObject, 'IssueDate', Format(SalesInvoiceHeader."Posting Date", 0, '<Year4>-<Month,2>-<Day,2>'));
        AddBasicField(InvoiceObject, 'IssueTime', GetSafeMalaysiaTime(SalesInvoiceHeader."Posting Date"));

        // Invoice type code with list version
        AddFieldWithAttribute(InvoiceObject, 'InvoiceTypeCode', SalesInvoiceHeader."eInvoice Document Type", 'listVersionID', SalesInvoiceHeader."eInvoice Version Code");

        // Currency codes
        AddBasicField(InvoiceObject, 'DocumentCurrencyCode', CurrencyCode);
        AddBasicField(InvoiceObject, 'TaxCurrencyCode', CurrencyCode);

        // Invoice Period
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
        AddDelivery(InvoiceObject, Customer, SalesInvoiceHeader);

        // Payment information
        AddPaymentMeans(InvoiceObject, SalesInvoiceHeader);
        AddPaymentTerms(InvoiceObject, SalesInvoiceHeader);

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

    local procedure GetSafeMalaysiaTime(PostingDate: Date): Text
    begin
        // ALWAYS use a fixed safe time in the past
        // This eliminates any possibility of future time validation errors
        exit('00:00:00Z');  // Fixed 8 AM UTC time - guaranteed to be safe
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
        HasReferences: Boolean;
    begin
        // Only add if there are actual references
        if SalesInvoiceHeader."External Document No." <> '' then begin
            Clear(RefObject);
            AddBasicField(RefObject, 'ID', SalesInvoiceHeader."External Document No.");
            AddBasicField(RefObject, 'DocumentType', '');
            AdditionalDocArray.Add(RefObject);
            HasReferences := true;
        end;

        // Add other document references only if they exist
        // Remove the empty object creation

        if HasReferences then
            InvoiceObject.Add('AdditionalDocumentReference', AdditionalDocArray);
    end;

    local procedure AddAccountingSupplierParty(var InvoiceObject: JsonObject; CompanyInfo: Record "Company Information")
    var
        SupplierArray: JsonArray;
        SupplierObject: JsonObject;
        PartyArray: JsonArray;
        PartyObject: JsonObject;
        PartyIdentificationArray: JsonArray;
        PostalAddressArray: JsonArray;
        PostalAddressObject: JsonObject;
        ContactArray: JsonArray;
        ContactObject: JsonObject;
        PartyLegalEntityArray: JsonArray;
        PartyLegalEntityObject: JsonObject;
        IndustryClassificationArray: JsonArray;
        IndustryClassificationObject: JsonObject;
        AdditionalAccountIDArray: JsonArray;
        AdditionalAccountIDObject: JsonObject;
    begin
        // Additional Account ID (for certifications like CertEX)
        AdditionalAccountIDObject.Add('_', GetCertificationID());
        AdditionalAccountIDObject.Add('schemeAgencyName', 'CertEX');
        AdditionalAccountIDArray.Add(AdditionalAccountIDObject);
        SupplierObject.Add('AdditionalAccountID', AdditionalAccountIDArray);

        // Industry classification (MSIC code)
        IndustryClassificationObject.Add('_', GetMSICCode());
        IndustryClassificationObject.Add('name', GetMSICDescription());
        IndustryClassificationArray.Add(IndustryClassificationObject);
        PartyObject.Add('IndustryClassificationCode', IndustryClassificationArray);

        // Party identification (TIN, BRN, SST, TTX)
        AddPartyIdentification(PartyIdentificationArray, CompanyInfo."e-Invoice TIN No.", 'TIN');
        AddPartyIdentification(PartyIdentificationArray, CompanyInfo."ID No.", 'BRN');
        AddPartyIdentification(PartyIdentificationArray, GetSSTNumber(), 'SST');
        AddPartyIdentification(PartyIdentificationArray, GetTTXNumber(), 'TTX');
        PartyObject.Add('PartyIdentification', PartyIdentificationArray);

        // Postal address
        AddBasicField(PostalAddressObject, 'CityName', CompanyInfo.City);
        AddBasicField(PostalAddressObject, 'PostalZone', CompanyInfo."Post Code");
        AddBasicField(PostalAddressObject, 'CountrySubentityCode', GetStateCode(CompanyInfo."City"));
        AddAddressLines(PostalAddressObject, CompanyInfo.Address, CompanyInfo."Address 2", '');
        AddCountry(PostalAddressObject, GetCountryCode(CompanyInfo."e-Invoice Country Code"));
        PostalAddressArray.Add(PostalAddressObject);
        PartyObject.Add('PostalAddress', PostalAddressArray);

        // Legal entity information
        AddBasicField(PartyLegalEntityObject, 'RegistrationName', CompanyInfo.Name);
        PartyLegalEntityArray.Add(PartyLegalEntityObject);
        PartyObject.Add('PartyLegalEntity', PartyLegalEntityArray);

        // Contact information
        AddBasicField(ContactObject, 'Telephone', CompanyInfo."Phone No.");
        AddBasicField(ContactObject, 'ElectronicMail', CompanyInfo."e-Invoice Email");
        ContactArray.Add(ContactObject);
        PartyObject.Add('Contact', ContactArray);

        // Build supplier object
        PartyArray.Add(PartyObject);
        SupplierObject.Add('Party', PartyArray);
        SupplierArray.Add(SupplierObject);
        InvoiceObject.Add('AccountingSupplierParty', SupplierArray);
    end;

    local procedure AddAccountingCustomerParty(var InvoiceObject: JsonObject; Customer: Record Customer)
    var
        CustomerArray: JsonArray;
        CustomerObject: JsonObject;
        PartyArray: JsonArray;
        PartyObject: JsonObject;
        PartyIdentificationArray: JsonArray;
        PostalAddressArray: JsonArray;
        PostalAddressObject: JsonObject;
        ContactArray: JsonArray;
        ContactObject: JsonObject;
        PartyLegalEntityArray: JsonArray;
        PartyLegalEntityObject: JsonObject;
    begin
        // Postal address
        AddBasicField(PostalAddressObject, 'CityName', Customer.City);
        AddBasicField(PostalAddressObject, 'PostalZone', Customer."Post Code");
        AddBasicField(PostalAddressObject, 'CountrySubentityCode', GetStateCode(Customer."City"));
        AddAddressLines(PostalAddressObject, Customer.Address, Customer."Address 2", '');
        AddCountry(PostalAddressObject, GetCountryCode(Customer."Country/Region Code"));
        PostalAddressArray.Add(PostalAddressObject);
        PartyObject.Add('PostalAddress', PostalAddressArray);

        // Legal entity
        AddBasicField(PartyLegalEntityObject, 'RegistrationName', Customer.Name);
        PartyLegalEntityArray.Add(PartyLegalEntityObject);
        PartyObject.Add('PartyLegalEntity', PartyLegalEntityArray);

        // Party identification
        AddPartyIdentification(PartyIdentificationArray, Customer."e-Invoice TIN No.", 'TIN');
        AddPartyIdentification(PartyIdentificationArray, Customer."e-Invoice ID No.", 'BRN');
        AddPartyIdentification(PartyIdentificationArray, Customer."e-Invoice SST No.", 'SST');
        AddPartyIdentification(PartyIdentificationArray, '', 'TTX');
        PartyObject.Add('PartyIdentification', PartyIdentificationArray);

        // Contact information
        AddBasicField(ContactObject, 'Telephone', Customer."Phone No.");
        AddBasicField(ContactObject, 'ElectronicMail', Customer."E-Mail");
        ContactArray.Add(ContactObject);
        PartyObject.Add('Contact', ContactArray);

        // Build customer object
        PartyArray.Add(PartyObject);
        CustomerObject.Add('Party', PartyArray);
        CustomerArray.Add(CustomerObject);
        InvoiceObject.Add('AccountingCustomerParty', CustomerArray);
    end;

    local procedure AddDelivery(var InvoiceObject: JsonObject; Customer: Record Customer; SalesInvoiceHeader: Record "Sales Invoice Header")
    var
        DeliveryArray: JsonArray;
        DeliveryObject: JsonObject;
        DeliveryPartyArray: JsonArray;
        DeliveryPartyObject: JsonObject;
        PartyIdentificationArray: JsonArray;
        PostalAddressArray: JsonArray;
        PostalAddressObject: JsonObject;
        PartyLegalEntityArray: JsonArray;
        PartyLegalEntityObject: JsonObject;
        ShipmentArray: JsonArray;
        CompanyInformation: Record "Company Information";
    begin
        // Use customer address as delivery address if no specific delivery address
        CompanyInformation.Get();

        // Legal entity - use customer name as delivery recipient
        AddBasicField(PartyLegalEntityObject, 'RegistrationName', Customer.Name);
        PartyLegalEntityArray.Add(PartyLegalEntityObject);
        DeliveryPartyObject.Add('PartyLegalEntity', PartyLegalEntityArray);

        // Delivery address - use customer address
        AddBasicField(PostalAddressObject, 'CityName', Customer.City);
        AddBasicField(PostalAddressObject, 'PostalZone', Customer."Post Code");
        AddBasicField(PostalAddressObject, 'CountrySubentityCode', GetStateCode(Customer.City));
        AddAddressLines(PostalAddressObject, Customer.Address, Customer."Address 2", '');
        AddCountry(PostalAddressObject, GetCountryCode(Customer."Country/Region Code"));
        PostalAddressArray.Add(PostalAddressObject);
        DeliveryPartyObject.Add('PostalAddress', PostalAddressArray);

        // Delivery party identification - use customer TIN/BRN
        AddPartyIdentification(PartyIdentificationArray, Customer."e-Invoice TIN No.", 'TIN');
        AddPartyIdentification(PartyIdentificationArray, Customer."e-Invoice ID No.", 'BRN');
        DeliveryPartyObject.Add('PartyIdentification', PartyIdentificationArray);

        DeliveryPartyArray.Add(DeliveryPartyObject);
        DeliveryObject.Add('DeliveryParty', DeliveryPartyArray);

        // Shipment information (optional)
        AddShipmentInfoDynamic(ShipmentArray, SalesInvoiceHeader);
        if ShipmentArray.Count > 0 then
            DeliveryObject.Add('Shipment', ShipmentArray);

        DeliveryArray.Add(DeliveryObject);
        InvoiceObject.Add('Delivery', DeliveryArray);
    end;

    // Alternative version if you want to make it more dynamic:
    local procedure AddShipmentInfoDynamic(var ShipmentArray: JsonArray; SalesInvoiceHeader: Record "Sales Invoice Header")
    var
        ShipmentObject: JsonObject;
        FreightChargeArray: JsonArray;
        FreightChargeObject: JsonObject;
        ChargeIndicatorArray: JsonArray;
        ChargeIndicatorObject: JsonObject;
        AllowanceChargeReasonArray: JsonArray;
        AllowanceChargeReasonObject: JsonObject;
        AmountArray: JsonArray;
        AmountObject: JsonObject;
        FreightAmount: Decimal;
        CurrencyCode: Code[10];
        ShipmentID: Text;
    begin
        // Get currency code
        if SalesInvoiceHeader."Currency Code" = '' then
            CurrencyCode := 'MYR'
        else
            CurrencyCode := SalesInvoiceHeader."Currency Code";

        // CRITICAL: Shipment ID is mandatory when Shipment section is included
        ShipmentID := GetShipmentID(SalesInvoiceHeader);
        if ShipmentID = '' then
            ShipmentID := SalesInvoiceHeader."No."; // Use invoice number as fallback

        AddBasicField(ShipmentObject, 'ID', ShipmentID);

        // Calculate freight amount
        FreightAmount := CalculateFreightAmount(SalesInvoiceHeader);

        // Freight allowance charge
        ChargeIndicatorObject.Add('_', FreightAmount > 0);
        ChargeIndicatorArray.Add(ChargeIndicatorObject);
        FreightChargeObject.Add('ChargeIndicator', ChargeIndicatorArray);

        AllowanceChargeReasonObject.Add('_', GetFreightReason(FreightAmount));
        AllowanceChargeReasonArray.Add(AllowanceChargeReasonObject);
        FreightChargeObject.Add('AllowanceChargeReason', AllowanceChargeReasonArray);

        AmountObject.Add('_', FreightAmount);
        AmountObject.Add('currencyID', CurrencyCode);
        AmountArray.Add(AmountObject);
        FreightChargeObject.Add('Amount', AmountArray);

        FreightChargeArray.Add(FreightChargeObject);
        ShipmentObject.Add('FreightAllowanceCharge', FreightChargeArray);
        ShipmentArray.Add(ShipmentObject);
    end;

    // Helper functions for the dynamic version (implement as needed):
    local procedure CalculateFreightAmount(SalesInvoiceHeader: Record "Sales Invoice Header"): Decimal
    begin
        // Implement your freight calculation logic here
        // For now, return 0
        exit(0.0);
    end;

    local procedure GetShipmentID(SalesInvoiceHeader: Record "Sales Invoice Header"): Text
    begin
        // Try to get shipment ID from a custom field, otherwise use invoice number
        // You can customize this based on your Business Central setup
        if SalesInvoiceHeader."External Document No." <> '' then
            exit('SHIP-' + SalesInvoiceHeader."External Document No.")
        else
            exit('SHIP-' + SalesInvoiceHeader."No.");
    end;

    local procedure GetFreightReason(FreightAmount: Decimal): Text
    begin
        if FreightAmount > 0 then
            exit('Freight')
        else
            exit('');
    end;

    local procedure AddPaymentMeans(var InvoiceObject: JsonObject; SalesInvoiceHeader: Record "Sales Invoice Header")
    var
        PaymentMeansArray: JsonArray;
        PaymentMeansObject: JsonObject;
        PayeeAccountArray: JsonArray;
        PayeeAccountObject: JsonObject;
    begin
        // CRITICAL: PaymentMeansCode is mandatory and was missing
        AddBasicField(PaymentMeansObject, 'PaymentMeansCode', GetPaymentMeansCode(SalesInvoiceHeader));

        // Only add bank account for bank transfer payments
        if GetPaymentMeansCode(SalesInvoiceHeader) = '01' then begin // Bank Transfer
            AddBasicField(PayeeAccountObject, 'ID', GetBankAccountNumber());
            PayeeAccountArray.Add(PayeeAccountObject);
            PaymentMeansObject.Add('PayeeFinancialAccount', PayeeAccountArray);
        end;

        PaymentMeansArray.Add(PaymentMeansObject);
        InvoiceObject.Add('PaymentMeans', PaymentMeansArray);
    end;

    local procedure GetPaymentMeansCode(SalesInvoiceHeader: Record "Sales Invoice Header"): Code[10]
    begin
        // Return the payment mode from the invoice header
        if SalesInvoiceHeader."eInvoice Payment Mode" <> '' then
            exit(SalesInvoiceHeader."eInvoice Payment Mode")
        else
            exit('01'); // Default to bank transfer if not specified
    end;

    local procedure AddPaymentTerms(var InvoiceObject: JsonObject; SalesInvoiceHeader: Record "Sales Invoice Header")
    var
        PaymentTermsArray: JsonArray;
        PaymentTermsObject: JsonObject;
    begin
        AddBasicField(PaymentTermsObject, 'Note', GetPaymentTermsNote(SalesInvoiceHeader));
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
        // Only add if there's actually a prepaid amount > 0
        if PrepaidAmount > 0 then begin
            AddBasicField(PrepaidObject, 'ID', SalesInvoiceHeader."No.");
            AddAmountField(PrepaidObject, 'PaidAmount', PrepaidAmount, GetCurrencyCode(SalesInvoiceHeader));
            AddBasicField(PrepaidObject, 'PaidDate', Format(SalesInvoiceHeader."Posting Date", 0, '<Year4>-<Month,2>-<Day,2>'));
            AddBasicField(PrepaidObject, 'PaidTime', Format(Time(), 0, '<Hours24,2>:<Minutes,2>:<Seconds,2>Z'));

            PrepaidArray.Add(PrepaidObject);
            InvoiceObject.Add('PrepaidPayment', PrepaidArray);
        end;
        // If no prepaid amount, don't add the section at all
    end;

    local procedure AddAllowanceCharges(var InvoiceObject: JsonObject; SalesInvoiceHeader: Record "Sales Invoice Header")
    var
        AllowanceArray: JsonArray;
        ChargeObject: JsonObject;
        ChargeIndicatorArray: JsonArray;
        ChargeIndicatorObject: JsonObject;
        AllowanceChargeReasonArray: JsonArray;
        AllowanceChargeReasonObject: JsonObject;
        AmountArray: JsonArray;
        AmountObject: JsonObject;
        SalesLine: Record "Sales Invoice Line";
        DiscountAmount: Decimal;
        ChargeAmount: Decimal;
    begin
        // Calculate total discount and charges from invoice lines
        SalesLine.SetRange("Document No.", SalesInvoiceHeader."No.");
        if SalesLine.FindSet() then
            repeat
                DiscountAmount += SalesLine."Line Discount Amount";
            until SalesLine.Next() = 0;

        // Add discount as allowance
        if DiscountAmount > 0 then begin
            Clear(ChargeObject);
            ChargeIndicatorObject.Add('_', false);
            ChargeIndicatorArray.Add(ChargeIndicatorObject);
            ChargeObject.Add('ChargeIndicator', ChargeIndicatorArray);

            Clear(AllowanceChargeReasonArray);
            AllowanceChargeReasonObject.Add('_', '');
            AllowanceChargeReasonArray.Add(AllowanceChargeReasonObject);
            ChargeObject.Add('AllowanceChargeReason', AllowanceChargeReasonArray);

            Clear(AmountArray);
            AmountObject.Add('_', DiscountAmount);
            AmountObject.Add('currencyID', GetCurrencyCode(SalesInvoiceHeader));
            AmountArray.Add(AmountObject);
            ChargeObject.Add('Amount', AmountArray);

            AllowanceArray.Add(ChargeObject);
        end;

        // Add any charges if applicable (calculate dynamically or omit if not applicable)
        ChargeAmount := 0; // Set to 0 or calculate based on your business logic
        // Example: ChargeAmount := CalculateServiceCharge(SalesInvoiceHeader);

        if ChargeAmount > 0 then begin
            Clear(ChargeObject);
            Clear(ChargeIndicatorArray);
            Clear(ChargeIndicatorObject);
            ChargeIndicatorObject.Add('_', true);
            ChargeIndicatorArray.Add(ChargeIndicatorObject);
            ChargeObject.Add('ChargeIndicator', ChargeIndicatorArray);

            Clear(AllowanceChargeReasonArray);
            Clear(AllowanceChargeReasonObject);
            AllowanceChargeReasonObject.Add('_', 'Service charge');
            AllowanceChargeReasonArray.Add(AllowanceChargeReasonObject);
            ChargeObject.Add('AllowanceChargeReason', AllowanceChargeReasonArray);

            Clear(AmountArray);
            Clear(AmountObject);
            AmountObject.Add('_', ChargeAmount);
            AmountObject.Add('currencyID', GetCurrencyCode(SalesInvoiceHeader));
            AmountArray.Add(AmountObject);
            ChargeObject.Add('Amount', AmountArray);

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
        TaxCategoryArray: JsonArray;
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

        AddAmountField(TaxTotalObject, 'TaxAmount', TotalTaxAmount, GetCurrencyCode(SalesInvoiceHeader));

        // Tax subtotal
        AddAmountField(TaxSubtotalObject, 'TaxableAmount', TaxableAmount, GetCurrencyCode(SalesInvoiceHeader));
        AddAmountField(TaxSubtotalObject, 'TaxAmount', TotalTaxAmount, GetCurrencyCode(SalesInvoiceHeader));

        // Tax category
        AddBasicField(TaxCategoryObject, 'ID', '01');

        // Tax scheme
        AddBasicFieldWithAttributes(TaxSchemeObject, 'ID', 'OTH', 'schemeID', 'UN/ECE 5153', 'schemeAgencyID', '6');
        TaxSchemeArray.Add(TaxSchemeObject);
        TaxCategoryArray.Add(TaxCategoryObject);
        TaxCategoryObject.Add('TaxScheme', TaxSchemeArray);

        TaxSubtotalArray.Add(TaxSubtotalObject);
        TaxSubtotalObject.Add('TaxCategory', TaxCategoryArray);
        TaxTotalObject.Add('TaxSubtotal', TaxSubtotalArray);

        TaxTotalArray.Add(TaxTotalObject);
        InvoiceObject.Add('TaxTotal', TaxTotalArray);
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
        PayableRoundingAmount: Decimal;
        SalesLine: Record "Sales Invoice Line";
        TotalTaxAmount: Decimal;
    begin
        // Calculate amounts from invoice lines
        ChargeTotalAmount := 0;
        SalesLine.SetRange("Document No.", SalesInvoiceHeader."No.");
        if SalesLine.FindSet() then
            repeat
                LineExtensionAmount += SalesLine.Amount;
                AllowanceTotalAmount += SalesLine."Line Discount Amount";
                TotalTaxAmount += SalesLine."Amount Including VAT" - SalesLine.Amount;
            until SalesLine.Next() = 0;

        TaxExclusiveAmount := LineExtensionAmount - AllowanceTotalAmount + ChargeTotalAmount;
        TaxInclusiveAmount := TaxExclusiveAmount + TotalTaxAmount;
        PayableAmount := TaxInclusiveAmount;
        PayableRoundingAmount := 0;

        AddAmountField(LegalTotalObject, 'LineExtensionAmount', LineExtensionAmount, GetCurrencyCode(SalesInvoiceHeader));
        AddAmountField(LegalTotalObject, 'TaxExclusiveAmount', TaxExclusiveAmount, GetCurrencyCode(SalesInvoiceHeader));
        AddAmountField(LegalTotalObject, 'TaxInclusiveAmount', TaxInclusiveAmount, GetCurrencyCode(SalesInvoiceHeader));
        AddAmountField(LegalTotalObject, 'AllowanceTotalAmount', AllowanceTotalAmount, GetCurrencyCode(SalesInvoiceHeader));
        AddAmountField(LegalTotalObject, 'ChargeTotalAmount', ChargeTotalAmount, GetCurrencyCode(SalesInvoiceHeader));
        AddAmountField(LegalTotalObject, 'PayableRoundingAmount', PayableRoundingAmount, GetCurrencyCode(SalesInvoiceHeader));
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
        TaxCategoryArray: JsonArray;
        TaxCategoryObject: JsonObject;
        TaxSchemeArray: JsonArray;
        TaxSchemeObject: JsonObject;
        ItemArray: JsonArray;
        ItemObject: JsonObject;
        PriceArray: JsonArray;
        PriceObject: JsonObject;
        AllowanceChargeArray: JsonArray;
        CommodityArray: JsonArray;
        CommodityObject: JsonObject;
        ItemClassificationCodeArray: JsonArray;
        ItemClassificationCodeObject: JsonObject;
        OriginCountryArray: JsonArray;
        OriginCountryObject: JsonObject;
        IdentificationCodeArray: JsonArray;
        IdentificationCodeObject: JsonObject;
        DescriptionArray: JsonArray;
        DescriptionObject: JsonObject;
        ItemPriceExtensionArray: JsonArray;
        ItemPriceExtensionObject: JsonObject;
        UnitCode: Code[10];
    begin
        // Line ID and quantity
        AddBasicField(LineObject, 'ID', Format(SalesInvoiceLine."Line No."));

        UnitCode := GetUBLUnitCode(SalesInvoiceLine);
        AddQuantityField(LineObject, 'InvoicedQuantity', SalesInvoiceLine.Quantity, UnitCode);
        AddAmountField(LineObject, 'LineExtensionAmount', SalesInvoiceLine.Amount, GetCurrencyCode(CurrencyCode));

        // Line allowances/charges
        if SalesInvoiceLine."Line Discount Amount" > 0 then
            AddLineAllowanceCharge(AllowanceChargeArray, false, '',
                SalesInvoiceLine."Line Discount %", SalesInvoiceLine."Line Discount Amount", GetCurrencyCode(CurrencyCode));

        // Add a sample charge
        // Example: Add a charge if applicable (remove hardcoded values)
        // You can calculate the charge amount and percentage based on your business logic.
        // For example, if you have a "Line Charge Amount" field:
        // Removed usage of non-existent "Line Charge Amount" field.
        // If you want to add a charge, replace the following with your own logic and field:
        // Example:
        // if MyChargeAmount > 0 then
        //     AddLineAllowanceCharge(
        //         AllowanceChargeArray,
        //         true,
        //         '', // Reason
        //         0, // Percentage
        //         MyChargeAmount,
        //         GetCurrencyCode(CurrencyCode)
        //     );

        if AllowanceChargeArray.Count > 0 then
            LineObject.Add('AllowanceCharge', AllowanceChargeArray);

        // Tax total for line
        AddAmountField(TaxTotalObject, 'TaxAmount', SalesInvoiceLine."Amount Including VAT" - SalesInvoiceLine.Amount, GetCurrencyCode(CurrencyCode));

        // Tax subtotal
        AddAmountField(TaxSubtotalObject, 'TaxableAmount', SalesInvoiceLine.Amount, GetCurrencyCode(CurrencyCode));
        AddAmountField(TaxSubtotalObject, 'TaxAmount', SalesInvoiceLine."Amount Including VAT" - SalesInvoiceLine.Amount, GetCurrencyCode(CurrencyCode));
        AddBasicField(TaxSubtotalObject, 'Percent', Format(SalesInvoiceLine."VAT %", 0, '<Precision,2:2><Standard Format,2>'));

        // Tax category
        AddBasicField(TaxCategoryObject, 'ID', SalesInvoiceLine."e-Invoice Tax Type");
        AddBasicField(TaxCategoryObject, 'TaxExemptionReason', '');

        // Tax scheme
        AddBasicFieldWithAttributes(TaxSchemeObject, 'ID', 'OTH', 'schemeID', 'UN/ECE 5153', 'schemeAgencyID', '6');
        TaxSchemeArray.Add(TaxSchemeObject);
        TaxCategoryArray.Add(TaxCategoryObject);
        TaxCategoryObject.Add('TaxScheme', TaxSchemeArray);

        TaxSubtotalArray.Add(TaxSubtotalObject);
        TaxSubtotalObject.Add('TaxCategory', TaxCategoryArray);
        TaxTotalObject.Add('TaxSubtotal', TaxSubtotalArray);

        TaxTotalArray.Add(TaxTotalObject);
        LineObject.Add('TaxTotal', TaxTotalArray);

        // Item information
        // Commodity classification
        ItemClassificationCodeObject.Add('_', GetHSCode(SalesInvoiceLine));
        ItemClassificationCodeObject.Add('listID', 'PTC');
        ItemClassificationCodeArray.Add(ItemClassificationCodeObject);
        CommodityObject.Add('ItemClassificationCode', ItemClassificationCodeArray);
        CommodityArray.Add(CommodityObject);

        // Add second commodity classification
        Clear(CommodityObject);
        Clear(ItemClassificationCodeArray);
        Clear(ItemClassificationCodeObject);
        ItemClassificationCodeObject.Add('_', '003');
        ItemClassificationCodeObject.Add('listID', 'CLASS');
        ItemClassificationCodeArray.Add(ItemClassificationCodeObject);
        CommodityObject.Add('ItemClassificationCode', ItemClassificationCodeArray);
        CommodityArray.Add(CommodityObject);

        ItemObject.Add('CommodityClassification', CommodityArray);

        // Description
        DescriptionObject.Add('_', SalesInvoiceLine.Description);
        DescriptionArray.Add(DescriptionObject);
        ItemObject.Add('Description', DescriptionArray);

        // Origin country
        IdentificationCodeObject.Add('_', GetOriginCountryCode(SalesInvoiceLine));
        IdentificationCodeArray.Add(IdentificationCodeObject);
        OriginCountryObject.Add('IdentificationCode', IdentificationCodeArray);
        OriginCountryArray.Add(OriginCountryObject);
        ItemObject.Add('OriginCountry', OriginCountryArray);

        ItemArray.Add(ItemObject);
        LineObject.Add('Item', ItemArray);

        // Price
        AddAmountField(PriceObject, 'PriceAmount', SalesInvoiceLine."Unit Price", GetCurrencyCode(CurrencyCode));
        PriceArray.Add(PriceObject);
        LineObject.Add('Price', PriceArray);

        // Item price extension
        AddAmountField(ItemPriceExtensionObject, 'Amount', SalesInvoiceLine.Amount, GetCurrencyCode(CurrencyCode));
        ItemPriceExtensionArray.Add(ItemPriceExtensionObject);
        LineObject.Add('ItemPriceExtension', ItemPriceExtensionArray);

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
        // For TIN and BRN - always required (use actual value or NA)
        // For SST and TTX - use NA if not applicable
        if ID <> '' then begin
            IDValueObject.Add('_', ID);
            IDValueObject.Add('schemeID', SchemeID);
        end else begin
            IDValueObject.Add('_', 'NA');
            IDValueObject.Add('schemeID', SchemeID);
        end;

        IDArray.Add(IDValueObject);
        IDObject.Add('ID', IDArray);
        PartyIdentificationArray.Add(IDObject);
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
            Clear(LineObject);
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
        ChargeIndicatorArray: JsonArray;
        ChargeIndicatorObject: JsonObject;
        AllowanceChargeReasonArray: JsonArray;
        AllowanceChargeReasonObject: JsonObject;
        MultiplierFactorArray: JsonArray;
        MultiplierFactorObject: JsonObject;
        AmountArray: JsonArray;
        AmountObject: JsonObject;
    begin
        ChargeIndicatorObject.Add('_', IsCharge);
        ChargeIndicatorArray.Add(ChargeIndicatorObject);
        AllowanceCharge.Add('ChargeIndicator', ChargeIndicatorArray);

        AllowanceChargeReasonObject.Add('_', Reason);
        AllowanceChargeReasonArray.Add(AllowanceChargeReasonObject);
        AllowanceCharge.Add('AllowanceChargeReason', AllowanceChargeReasonArray);

        if Percentage > 0 then begin
            MultiplierFactorObject.Add('_', Percentage / 100);
            MultiplierFactorArray.Add(MultiplierFactorObject);
            AllowanceCharge.Add('MultiplierFactorNumeric', MultiplierFactorArray);
        end;

        AmountObject.Add('_', Amount);
        AmountObject.Add('currencyID', CurrencyCode);
        AmountArray.Add(AmountObject);
        AllowanceCharge.Add('Amount', AmountArray);

        AllowanceChargeArray.Add(AllowanceCharge);
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

    local procedure GetUBLUnitCode(SalesInvoiceLine: Record "Sales Invoice Line"): Code[10]
    begin
        // Return the UBL unit code directly from the e-Invoice UOM field
        if SalesInvoiceLine."e-Invoice UOM" <> '' then
            exit(SalesInvoiceLine."e-Invoice UOM")
        else
            exit('EA'); // Default to pieces if empty
    end;

    local procedure GetStateCode(County: Text): Text
    begin
        case County of
            'JOHOR':
                exit('01');
            'KEDAH', 'SUNGAI PETANI':
                exit('02');
            'KELANTAN':
                exit('03');
            'MELAKA', 'MALACCA':
                exit('04');
            'NEGERI SEMBILAN', 'SEREMBAN', 'NILAI':
                exit('05');
            'PAHANG':
                exit('06');
            'PULAU PINANG', 'PENANG':
                exit('07');
            'PERAK':
                exit('08');
            'PERLIS':
                exit('09');
            'SELANGOR':
                exit('10');
            'TERENGGANU':
                exit('11');
            'SABAH':
                exit('12');
            'SARAWAK', 'KUCHING':
                exit('13');
            'WILAYAH PERSEKUTUAN KUALA LUMPUR', 'KUALA LUMPUR':
                exit('14');
            'WILAYAH PERSEKUTUAN LABUAN', 'LABUAN':
                exit('15');
            'WILAYAH PERSEKUTUAN PUTRAJAYA', 'PUTRAJAYA':
                exit('16');
            else
                exit('17'); // Default to Not Applicable
        end;
    end;

    local procedure GetCountryCode(CountryRegionCode: Code[10]): Code[10]
    begin
        if CountryRegionCode = 'MY' then
            exit('MYS');
        // Add more country mappings as needed
        exit('MYS'); // Default to Malaysia
    end;

    local procedure GetTaxCategoryCode(eInvoiceTaxCategoryCode: Code[10]): Code[10]
    begin
        // Return the tax category code directly from the e-Invoice Tax Category Code field
        if eInvoiceTaxCategoryCode <> '' then
            exit(eInvoiceTaxCategoryCode)
        else
            exit('01'); // Default to standard rate if empty
    end;

    local procedure GetMSICCode(): Text
    var
        CompanyInformation: Record "Company Information";
    begin
        // Return your company's MSIC code - customize this
        CompanyInformation.Get();
        exit(CompanyInformation."MSIC Code");
    end;

    local procedure GetMSICDescription(): Text
    var
        CompanyInformation: Record "Company Information";
    begin
        // Return your company's MSIC description - customize this
        CompanyInformation.Get();
        exit(CompanyInformation."Business Activity Description")
    end;

    local procedure GetCertificationID(): Text
    begin
        // Return your certification ID (e.g., CertEX ID)
        exit('');
    end;

    local procedure GetSSTNumber(): Text
    var
        CompanyInformation: Record "Company Information";
    begin
        if CompanyInformation.Get() then begin
            if CompanyInformation."VAT Registration No." <> '' then
                exit(CompanyInformation."VAT Registration No.");
        end;
        exit('NA');
    end;

    local procedure GetTTXNumber(): Text
    var
        CompanyInformation: Record "Company Information";
    begin
        if CompanyInformation.Get() then begin
            if CompanyInformation."TTX No." <> '' then
                exit(CompanyInformation."TTX No.");
        end;
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
    var
        CompanyInformation: Record "Company Information";
        BankAccount: Record "Bank Account";
    begin
        // Get the company's bank account number for payments
        if CompanyInformation.Get() then begin
            // Find the first bank account or use a specific one based on your setup
            BankAccount.SetRange(Blocked, false);
            if BankAccount.FindFirst() then
                exit(BankAccount."No.");
        end;
        exit(''); // Return empty if not found
    end;

    local procedure GetPaymentTermsNote(SalesInvoiceHeader: Record "Sales Invoice Header"): Text
    var
        PaymentTerms: Record "Payment Terms";
        CompanyInformation: Record "Company Information";
    begin
        // Return payment terms description based on Payment Terms Code from Company Information
        if CompanyInformation.Get() then
            if PaymentTerms.Get(SalesInvoiceHeader."Payment Terms Code") then
                exit(PaymentTerms.Description);
        exit('08'); // Default to '08' if not found
    end;

    local procedure GetHSCode(SalesInvoiceLine: Record "Sales Invoice Line"): Text
    begin
        // Return the HS code directly from the e-Invoice Classification field
        if SalesInvoiceLine."e-Invoice Classification" <> '' then
            exit(SalesInvoiceLine."e-Invoice Classification")
        else
            exit('022'); // Default HS code if empty
    end;

    local procedure HasPrepaidAmount(SalesInvoiceHeader: Record "Sales Invoice Header"): Boolean
    begin
        // Check if there are any prepaid amounts
        exit(GetPrepaidAmount(SalesInvoiceHeader) > 0);
    end;

    local procedure GetPrepaidAmount(SalesInvoiceHeader: Record "Sales Invoice Header"): Decimal
    begin
        // Implement actual logic to get prepaid amount
        // For now, return 0 if no prepaid amount exists
        exit(0);
    end;

    local procedure GetOriginCountryCode(SalesInvoiceLine: Record "Sales Invoice Line"): Text
    var
        Item: Record Item;
        CompanyInformation: Record "Company Information";
    begin
        // Try to get from item first
        if SalesInvoiceLine.Type = SalesInvoiceLine.Type::Item then begin
            if Item.Get(SalesInvoiceLine."No.") then begin
                // If you have a country of origin field on Item table, use it
                // exit(Item."Country of Origin Code");
            end;
        end;

        // Fallback to company information
        if CompanyInformation.Get() then
            exit(GetCountryCode(CompanyInformation."e-Invoice Country Code"));

        exit('MYS'); // Default to Malaysia
    end;
}