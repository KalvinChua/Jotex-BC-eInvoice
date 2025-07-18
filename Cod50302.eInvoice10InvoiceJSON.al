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
        // Initialize the root structure with UBL namespaces
        JsonObject.Add('_D', 'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2');
        JsonObject.Add('_A', 'urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2');
        JsonObject.Add('_B', 'urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2');

        // Build the invoice object with all required fields
        InvoiceObject := CreateInvoiceObject(SalesInvoiceHeader);
        InvoiceArray.Add(InvoiceObject);
        JsonObject.Add('Invoice', InvoiceArray);
    end;

    local procedure CreateInvoiceObject(SalesInvoiceHeader: Record "Sales Invoice Header") InvoiceObject: JsonObject
    var
        Customer: Record Customer;
        CompanyInformation: Record "Company Information";
    begin
        // Basic invoice information
        AddSimpleField(InvoiceObject, 'ID', SalesInvoiceHeader."No.");
        AddSimpleField(InvoiceObject, 'IssueDate', Format(SalesInvoiceHeader."Posting Date", 0, '<Year4>-<Month,2>-<Day,2>'));
        AddSimpleField(InvoiceObject, 'IssueTime', Format(Time(), 0, '<Hours24,2>:<Minutes,2>:<Seconds,2>Z'));

        // Invoice type code (01 for regular invoice)
        AddSimpleField(InvoiceObject, 'InvoiceTypeCode', '01', 'listVersionID', '1.0');

        // Currency information
        if SalesInvoiceHeader."Currency Code" = '' then begin
            AddSimpleField(InvoiceObject, 'DocumentCurrencyCode', 'MYR');
            AddSimpleField(InvoiceObject, 'TaxCurrencyCode', 'MYR');
        end else begin
            AddSimpleField(InvoiceObject, 'DocumentCurrencyCode', SalesInvoiceHeader."Currency Code");
            AddSimpleField(InvoiceObject, 'TaxCurrencyCode', SalesInvoiceHeader."Currency Code");
        end;

        // Invoice period
        AddInvoicePeriod(InvoiceObject, SalesInvoiceHeader);

        // Billing reference
        AddBillingReference(InvoiceObject, SalesInvoiceHeader);

        // Additional document references
        AddAdditionalDocumentReferences(InvoiceObject, SalesInvoiceHeader);

        // Supplier information
        CompanyInformation.Get();
        AddAccountingSupplierParty(InvoiceObject, CompanyInformation);

        // Customer information
        Customer.Get(SalesInvoiceHeader."Bill-to Customer No.");
        AddAccountingCustomerParty(InvoiceObject, Customer);

        // Delivery information
        AddDelivery(InvoiceObject, Customer);

        // Shipment information
        AddShipment(InvoiceObject);

        // Payment means
        AddPaymentMeans(InvoiceObject);

        // Payment terms
        AddPaymentTerms(InvoiceObject);

        // Prepaid payment
        AddPrepaidPayment(InvoiceObject);

        // Allowance/charges
        AddAllowanceCharges(InvoiceObject, SalesInvoiceHeader);

        // Tax totals
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
    begin
        AddSimpleField(PeriodObject, 'StartDate', Format(SalesInvoiceHeader."Posting Date" - 30, 0, '<Year4>-<Month,2>-<Day,2>'));
        AddSimpleField(PeriodObject, 'EndDate', Format(SalesInvoiceHeader."Posting Date", 0, '<Year4>-<Month,2>-<Day,2>'));
        AddSimpleField(PeriodObject, 'Description', 'Monthly');
        PeriodArray.Add(PeriodObject);
        InvoiceObject.Add('InvoicePeriod', PeriodArray);
    end;

    local procedure AddBillingReference(var InvoiceObject: JsonObject; SalesInvoiceHeader: Record "Sales Invoice Header")
    var
        BillingRefArray: JsonArray;
        BillingRefObject: JsonObject;
        DocRefArray: JsonArray;
        DocRefObject: JsonObject;
    begin
        AddSimpleField(DocRefObject, 'ID', 'E12345678912');
        DocRefArray.Add(DocRefObject);
        BillingRefObject.Add('AdditionalDocumentReference', DocRefArray);
        BillingRefArray.Add(BillingRefObject);
        InvoiceObject.Add('BillingReference', BillingRefArray);
    end;

    local procedure AddAdditionalDocumentReferences(var InvoiceObject: JsonObject; SalesInvoiceHeader: Record "Sales Invoice Header")
    var
        AdditionalDocArray: JsonArray;
        RefObject: JsonObject;
    begin
        Clear(RefObject);
        AddSimpleField(RefObject, 'ID', 'E12345678912');
        AddSimpleField(RefObject, 'DocumentType', 'CustomsImportForm');
        AdditionalDocArray.Add(RefObject);

        Clear(RefObject);
        AddSimpleField(RefObject, 'ID', 'sa313321312');
        AddSimpleField(RefObject, 'DocumentType', '213312dddddd');
        AddSimpleField(RefObject, 'DocumentDescription', 'asddasdwqfd ddq');
        AdditionalDocArray.Add(RefObject);

        Clear(RefObject);
        AddSimpleField(RefObject, 'ID', 'E12345678912');
        AddSimpleField(RefObject, 'DocumentType', 'K2');
        AdditionalDocArray.Add(RefObject);

        Clear(RefObject);
        AddSimpleField(RefObject, 'ID', 'CIF');
        AdditionalDocArray.Add(RefObject);

        InvoiceObject.Add('AdditionalDocumentReference', AdditionalDocArray);
    end;

    local procedure AddAccountingSupplierParty(var InvoiceObject: JsonObject; CompanyInfo: Record "Company Information")
    var
        SupplierArray: JsonArray;
        SupplierObject: JsonObject;
        PartyObject: JsonObject;
        PostalAddress: JsonObject;
        ContactObject: JsonObject;
        PartyLegalEntity: JsonObject;
        IndustryClassificationObject: JsonObject;
        PartyIdentificationArray: JsonArray;
        PartyLegalEntityArray: JsonArray;
        CountryArray: JsonArray;
        AdditionalAccountIDArray: JsonArray;
        AdditionalAccountIDObject: JsonObject;
    begin
        AddPartyIdentification(PartyIdentificationArray, 'C5865134090', 'TIN');
        AddPartyIdentification(PartyIdentificationArray, '199201007100', 'BRN');
        AddPartyIdentification(PartyIdentificationArray, 'NA', 'SST');
        AddPartyIdentification(PartyIdentificationArray, 'NA', 'TTX');

        AddSimpleField(IndustryClassificationObject, '_', '13921');
        AddSimpleField(IndustryClassificationObject, 'name', 'Manufacture of made-up articles of any textile materials, including of knitted or crocheted fabrics');

        AddSimpleField(PartyLegalEntity, 'RegistrationName', CompanyInfo.Name);
        PartyLegalEntityArray.Add(PartyLegalEntity);

        AddSimpleField(PostalAddress, 'CityName', 'Seremban');
        AddSimpleField(PostalAddress, 'PostalZone', '70200');
        AddSimpleField(PostalAddress, 'CountrySubentityCode', '10');
        AddAddressLines(PostalAddress, '4962 OAKLAND INDUSTRIAL PARK', 'JALAN HARUAN 7', '');
        AddCountry(PostalAddress, 'MYS');

        AddSimpleField(ContactObject, 'Telephone', '+6067671188');
        AddSimpleField(ContactObject, 'ElectronicMail', 'finance@jotexfabrics.com');

        PartyObject.Add('IndustryClassificationCode', IndustryClassificationObject);
        PartyObject.Add('PartyIdentification', PartyIdentificationArray);
        PartyObject.Add('PartyLegalEntity', PartyLegalEntityArray);
        PartyObject.Add('PostalAddress', PostalAddress);
        PartyObject.Add('Contact', ContactObject);

        AdditionalAccountIDObject.Add('_', 'CPT-CCN-W-211111-KL-000002');
        AdditionalAccountIDObject.Add('schemeAgencyName', 'CertEX');
        AdditionalAccountIDArray.Add(AdditionalAccountIDObject);

        SupplierObject.Add('AdditionalAccountID', AdditionalAccountIDArray);
        SupplierObject.Add('Party', PartyObject);

        SupplierArray.Add(SupplierObject);
        InvoiceObject.Add('AccountingSupplierParty', SupplierArray);
    end;


    local procedure AddAccountingCustomerParty(var InvoiceObject: JsonObject; Customer: Record Customer)
    var
        CustomerArray: JsonArray;
        CustomerObject, PartyObject, PostalAddress, ContactObject, PartyLegalEntity : JsonObject;
        PartyIdentificationArray, PartyLegalEntityArray : JsonArray;
    begin
        AddPartyIdentification(PartyIdentificationArray, 'C58490029050', 'TIN');
        AddPartyIdentification(PartyIdentificationArray, '202401002338', 'BRN');
        AddPartyIdentification(PartyIdentificationArray, 'NA', 'SST');
        AddPartyIdentification(PartyIdentificationArray, 'NA', 'TTX');

        AddSimpleField(PartyLegalEntity, 'RegistrationName', 'YWR CURTAINS SDN BHD');
        PartyLegalEntityArray.Add(PartyLegalEntity);

        AddSimpleField(PostalAddress, 'CityName', 'Kuala Lumpur');
        AddSimpleField(PostalAddress, 'PostalZone', '50480');
        AddSimpleField(PostalAddress, 'CountrySubentityCode', '10');
        AddAddressLines(PostalAddress, 'STORE ROOM - TAMAN CUEPACS, NO. 8-A', 'JALAN PERMATA BIRU, TAMAN CHERAS PERMATA', '');
        AddCountry(PostalAddress, 'MYS');

        AddSimpleField(ContactObject, 'Telephone', '+60137605191');
        AddSimpleField(ContactObject, 'ElectronicMail', 'enquiry.ywrcurtainssb@gmail.com');

        PartyObject.Add('PartyLegalEntity', PartyLegalEntityArray);
        PartyObject.Add('PostalAddress', PostalAddress);
        PartyObject.Add('PartyIdentification', PartyIdentificationArray);
        PartyObject.Add('Contact', ContactObject);

        CustomerObject.Add('Party', PartyObject);
        CustomerArray.Add(CustomerObject);
        InvoiceObject.Add('AccountingCustomerParty', CustomerArray);
    end;

    local procedure AddDelivery(var InvoiceObject: JsonObject; Customer: Record Customer)
    var
        DeliveryArray: JsonArray;
        DeliveryObject, DeliveryPartyObject, PostalAddressObject, PartyLegalEntityObject : JsonObject;
        PartyIdentificationArray: JsonArray;
    begin
        AddPartyIdentification(PartyIdentificationArray, 'Recipient''s TIN', 'TIN');
        AddPartyIdentification(PartyIdentificationArray, 'Recipient''s BRN', 'BRN');

        AddSimpleField(PartyLegalEntityObject, 'RegistrationName', 'Recipient''s Name');

        AddSimpleField(PostalAddressObject, 'CityName', 'Kuala Lumpur');
        AddSimpleField(PostalAddressObject, 'PostalZone', '50480');
        AddSimpleField(PostalAddressObject, 'CountrySubentityCode', '10');
        AddAddressLines(PostalAddressObject, 'Lot 66', 'Bangunan Merdeka', 'Persiaran Jaya');
        AddCountry(PostalAddressObject, 'MYS');

        DeliveryPartyObject.Add('PartyLegalEntity', PartyLegalEntityObject);
        DeliveryPartyObject.Add('PostalAddress', PostalAddressObject);
        DeliveryPartyObject.Add('PartyIdentification', PartyIdentificationArray);

        DeliveryObject.Add('DeliveryParty', DeliveryPartyObject);
        DeliveryArray.Add(DeliveryObject);
        InvoiceObject.Add('Delivery', DeliveryArray);
    end;

    local procedure AddShipment(var InvoiceObject: JsonObject)
    var
        ShipmentArray: JsonArray;
        ShipmentObject: JsonObject;
        FreightChargeObject: JsonObject;
        FreightChargeArray: JsonArray;
        ChargeIndicatorArray: JsonArray;
        ChargeIndicatorObject: JsonObject;
    begin
        AddSimpleField(ShipmentObject, 'ID', '1234');

        // Add ChargeIndicator as a Boolean true wrapped in JsonObject and JsonArray
        ChargeIndicatorObject.Add('_', true);
        ChargeIndicatorArray.Add(ChargeIndicatorObject);
        FreightChargeObject.Add('ChargeIndicator', ChargeIndicatorArray);

        AddSimpleField(FreightChargeObject, 'AllowanceChargeReason', 'Service charge');
        AddAmountField(FreightChargeObject, 'Amount', 100, 'MYR');

        FreightChargeArray.Add(FreightChargeObject);
        ShipmentObject.Add('FreightAllowanceCharge', FreightChargeArray);

        ShipmentArray.Add(ShipmentObject);
        InvoiceObject.Add('Shipment', ShipmentArray);
    end;


    local procedure AddPaymentMeans(var InvoiceObject: JsonObject)
    var
        PaymentMeansArray: JsonArray;
        PaymentMeansObject, PayeeAccountObject : JsonObject;
    begin
        AddSimpleField(PaymentMeansObject, 'PaymentMeansCode', '03'); // Cash
        AddSimpleField(PayeeAccountObject, 'ID', '1234567890123');
        PaymentMeansObject.Add('PayeeFinancialAccount', PayeeAccountObject);

        PaymentMeansArray.Add(PaymentMeansObject);
        InvoiceObject.Add('PaymentMeans', PaymentMeansArray);
    end;

    local procedure AddPaymentTerms(var InvoiceObject: JsonObject)
    var
        PaymentTermsArray: JsonArray;
        PaymentTermsObject: JsonObject;
    begin
        AddSimpleField(PaymentTermsObject, 'Note', 'Payment method is cash');
        PaymentTermsArray.Add(PaymentTermsObject);
        InvoiceObject.Add('PaymentTerms', PaymentTermsArray);
    end;

    local procedure AddPrepaidPayment(var InvoiceObject: JsonObject)
    var
        PrepaidArray: JsonArray;
        PrepaidObject: JsonObject;
    begin
        AddSimpleField(PrepaidObject, 'ID', 'E12345678912');
        AddAmountField(PrepaidObject, 'PaidAmount', 1, 'MYR');
        AddSimpleField(PrepaidObject, 'PaidDate', Format(Today, 0, '<Year4>-<Month,2>-<Day,2>'));
        AddSimpleField(PrepaidObject, 'PaidTime', Format(Time(), 0, '<Hours24,2>:<Minutes,2>:<Seconds,2>Z'));

        PrepaidArray.Add(PrepaidObject);
        InvoiceObject.Add('PrepaidPayment', PrepaidArray);
    end;

    local procedure AddAllowanceCharges(var InvoiceObject: JsonObject; SalesInvoiceHeader: Record "Sales Invoice Header")
    var
        AllowanceArray: JsonArray;
        ChargeObject: JsonObject;
    begin
        Clear(ChargeObject);
        AddSimpleField(ChargeObject, 'ChargeIndicator', 'false');
        AddSimpleField(ChargeObject, 'AllowanceChargeReason', 'Sample Description');
        AddAmountField(ChargeObject, 'Amount', 100, 'MYR');
        AllowanceArray.Add(ChargeObject);

        Clear(ChargeObject);
        AddSimpleField(ChargeObject, 'ChargeIndicator', 'true');
        AddSimpleField(ChargeObject, 'AllowanceChargeReason', 'Service charge');
        AddAmountField(ChargeObject, 'Amount', 100, 'MYR');
        AllowanceArray.Add(ChargeObject);

        InvoiceObject.Add('AllowanceCharge', AllowanceArray);
    end;

    local procedure AddTaxTotals(var InvoiceObject: JsonObject; SalesInvoiceHeader: Record "Sales Invoice Header")
    var
        TaxTotalArray: JsonArray;
        TaxTotalObject: JsonObject;
        TaxSubtotalArray: JsonArray;
        TaxSubtotalObject: JsonObject;
        TaxCategoryObject: JsonObject;
    begin
        AddAmountField(TaxTotalObject, 'TaxAmount', 87.63, 'MYR');

        AddAmountField(TaxSubtotalObject, 'TaxableAmount', 87.63, 'MYR');
        AddAmountField(TaxSubtotalObject, 'TaxAmount', 87.63, 'MYR');

        AddSimpleField(TaxCategoryObject, 'ID', '01');
        AddTaxScheme(TaxCategoryObject);

        TaxSubtotalObject.Add('TaxCategory', TaxCategoryObject);
        TaxSubtotalArray.Add(TaxSubtotalObject);
        TaxTotalObject.Add('TaxSubtotal', TaxSubtotalArray);

        TaxTotalArray.Add(TaxTotalObject);
        InvoiceObject.Add('TaxTotal', TaxTotalArray);
    end;

    local procedure AddLegalMonetaryTotal(var InvoiceObject: JsonObject; SalesInvoiceHeader: Record "Sales Invoice Header")
    var
        LegalTotalArray: JsonArray;
        LegalTotalObject: JsonObject;
    begin
        AddAmountField(LegalTotalObject, 'LineExtensionAmount', 1436.5, 'MYR');
        AddAmountField(LegalTotalObject, 'TaxExclusiveAmount', 1436.5, 'MYR');
        AddAmountField(LegalTotalObject, 'TaxInclusiveAmount', 1436.5, 'MYR');
        AddAmountField(LegalTotalObject, 'AllowanceTotalAmount', 1436.5, 'MYR');
        AddAmountField(LegalTotalObject, 'ChargeTotalAmount', 1436.5, 'MYR');
        AddAmountField(LegalTotalObject, 'PayableRoundingAmount', 0.3, 'MYR');
        AddAmountField(LegalTotalObject, 'PayableAmount', 1436.5, 'MYR');

        LegalTotalArray.Add(LegalTotalObject);
        InvoiceObject.Add('LegalMonetaryTotal', LegalTotalArray);
    end;

    local procedure AddInvoiceLines(var InvoiceObject: JsonObject; SalesInvoiceHeader: Record "Sales Invoice Header")
    var
        LineArray: JsonArray;
        SalesInvoiceLine: Record "Sales Invoice Line";
    begin
        SalesInvoiceLine.SetRange("Document No.", SalesInvoiceHeader."No.");
        if SalesInvoiceLine.FindSet() then
            repeat
                AddInvoiceLine(LineArray, SalesInvoiceLine, SalesInvoiceHeader."Currency Code");
            until SalesInvoiceLine.Next() = 0;
        InvoiceObject.Add('InvoiceLine', LineArray);
    end;

    local procedure AddInvoiceLine(var LineArray: JsonArray; SalesInvoiceLine: Record "Sales Invoice Line"; CurrencyCode: Code[10])
    var
        LineObject, TaxTotalObject, ItemObject, PriceObject, PriceExtensionObject : JsonObject;
        CommodityArray, AllowanceChargeArray : JsonArray;
        Item: Record Item;
    begin
        AddSimpleField(LineObject, 'ID', '1234');
        AddQuantityField(LineObject, 'InvoicedQuantity', 1, 'C62');
        AddAmountField(LineObject, 'LineExtensionAmount', 1436.5, 'MYR');

        Clear(AllowanceChargeArray);
        AddLineAllowanceCharge(AllowanceChargeArray, false, 'Sample Description', 0.15, 100, 'MYR');
        AddLineAllowanceCharge(AllowanceChargeArray, true, 'Sample Description', 0.10, 100, 'MYR');
        LineObject.Add('AllowanceCharge', AllowanceChargeArray);

        AddLineTaxTotal(TaxTotalObject, SalesInvoiceLine, 'MYR');
        LineObject.Add('TaxTotal', TaxTotalObject);

        Clear(CommodityArray);
        AddCommodityClassification(CommodityArray, '9800.00.0010', 'PTC');
        AddCommodityClassification(CommodityArray, '003', 'CLASS');

        AddSimpleField(ItemObject, 'Description', 'Laptop Peripherals');
        AddOriginCountry(ItemObject, 'MYS');
        ItemObject.Add('CommodityClassification', CommodityArray);

        LineObject.Add('Item', ItemObject);

        AddAmountField(PriceObject, 'PriceAmount', 17, 'MYR');
        LineObject.Add('Price', PriceObject);

        AddAmountField(PriceExtensionObject, 'Amount', 100, 'MYR');
        LineObject.Add('ItemPriceExtension', PriceExtensionObject);

        LineArray.Add(LineObject);
    end;

    local procedure AddLineTaxTotal(var TaxTotalObject: JsonObject; SalesInvoiceLine: Record "Sales Invoice Line"; CurrencyCode: Code[10])
    var
        TaxSubtotalArray: JsonArray;
        TaxSubtotalObject: JsonObject;
        TaxCategoryObject: JsonObject;
    begin
        AddAmountField(TaxTotalObject, 'TaxAmount', 1460.5, 'MYR');

        AddAmountField(TaxSubtotalObject, 'TaxableAmount', 1460.5, 'MYR');
        AddAmountField(TaxSubtotalObject, 'TaxAmount', 1460.5, 'MYR');
        AddSimpleField(TaxSubtotalObject, 'Percent', '6');

        AddSimpleField(TaxCategoryObject, 'ID', 'E');
        AddSimpleField(TaxCategoryObject, 'TaxExemptionReason', 'Exempt New Means of Transport');
        AddTaxScheme(TaxCategoryObject);

        TaxSubtotalObject.Add('TaxCategory', TaxCategoryObject);
        TaxSubtotalArray.Add(TaxSubtotalObject);
        TaxTotalObject.Add('TaxSubtotal', TaxSubtotalArray);
    end;

    local procedure AddTaxScheme(var TaxCategoryObject: JsonObject)
    var
        TaxSchemeArray: JsonArray;
        TaxSchemeObject: JsonObject;
    begin
        AddSimpleField(TaxSchemeObject, 'ID', 'OTH', 'schemeID', 'UN/ECE 5153', 'schemeAgencyID', '6');
        TaxSchemeArray.Add(TaxSchemeObject);
        TaxCategoryObject.Add('TaxScheme', TaxSchemeArray);
    end;

    local procedure AddOriginCountry(var ItemObject: JsonObject; CountryCode: Code[10])
    var
        OriginArray: JsonArray;
        OriginObject: JsonObject;
    begin
        AddSimpleField(OriginObject, 'IdentificationCode', CountryCode);
        OriginArray.Add(OriginObject);
        ItemObject.Add('OriginCountry', OriginArray);
    end;

    local procedure AddCommodityClassification(var CommodityArray: JsonArray; Code: Text; ListID: Text)
    var
        ClassificationObject: JsonObject;
    begin
        AddSimpleField(ClassificationObject, 'ItemClassificationCode', Code, 'listID', ListID);
        CommodityArray.Add(ClassificationObject);
    end;

    local procedure GetUnitCode(UOM: Text): Text
    begin
        case UpperCase(UOM) of
            'PCS':
                exit('C62');
            'BOX':
                exit('BX');
            'KG':
                exit('KGM');
            'L':
                exit('LTR');
            'M':
                exit('MTR');
            'SET':
                exit('SET');
            'PKT':
                exit('PK');
            else
                exit('C62');
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
            'Melaka':
                exit('04');
            'Negeri Sembilan':
                exit('05');
            'Pahang':
                exit('06');
            'Pulau Pinang':
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
            'Wilayah Persekutuan Kuala Lumpur':
                exit('14');
            'Wilayah Persekutuan Labuan':
                exit('15');
            'Wilayah Persekutuan Putrajaya':
                exit('16');
            else
                exit('17');
        end;
    end;

    local procedure AddSimpleField(var ParentObject: JsonObject; FieldName: Text; FieldValue: Text)
    var
        ValueArray: JsonArray;
        ValueObject: JsonObject;
    begin
        Clear(ValueArray);
        Clear(ValueObject);
        ValueObject.Add('_', FieldValue);
        ValueArray.Add(ValueObject);
        ParentObject.Add(FieldName, ValueArray);
    end;

    local procedure AddSimpleField(var ParentObject: JsonObject; FieldName: Text; FieldValue: Text; AttributeName1: Text; AttributeValue1: Text)
    var
        ValueArray: JsonArray;
        ValueObject: JsonObject;
    begin
        Clear(ValueArray);
        Clear(ValueObject);
        ValueObject.Add('_', FieldValue);
        ValueObject.Add(AttributeName1, AttributeValue1);
        ValueArray.Add(ValueObject);
        ParentObject.Add(FieldName, ValueArray);
    end;

    local procedure AddSimpleField(var ParentObject: JsonObject; FieldName: Text; FieldValue: Text; AttributeName1: Text; AttributeValue1: Text; AttributeName2: Text; AttributeValue2: Text)
    var
        ValueArray: JsonArray;
        ValueObject: JsonObject;
    begin
        Clear(ValueArray);
        Clear(ValueObject);
        ValueObject.Add('_', FieldValue);
        ValueObject.Add(AttributeName1, AttributeValue1);
        ValueObject.Add(AttributeName2, AttributeValue2);
        ValueArray.Add(ValueObject);
        ParentObject.Add(FieldName, ValueArray);
    end;

    local procedure AddAmountField(var ParentObject: JsonObject; FieldName: Text; Amount: Decimal; CurrencyCode: Text)
    var
        ValueArray: JsonArray;
        ValueObject: JsonObject;
    begin
        Clear(ValueArray);
        Clear(ValueObject);
        ValueObject.Add('_', Amount);
        if CurrencyCode = '' then
            ValueObject.Add('currencyID', 'MYR')
        else
            ValueObject.Add('currencyID', CurrencyCode);
        ValueArray.Add(ValueObject);
        ParentObject.Add(FieldName, ValueArray);
    end;

    local procedure AddQuantityField(var ParentObject: JsonObject; FieldName: Text; Quantity: Decimal; UOM: Text)
    var
        ValueArray: JsonArray;
        ValueObject: JsonObject;
    begin
        Clear(ValueArray);
        Clear(ValueObject);
        ValueObject.Add('_', Quantity);
        ValueObject.Add('unitCode', GetUnitCode(UOM));
        ValueArray.Add(ValueObject);
        ParentObject.Add(FieldName, ValueArray);
    end;

    local procedure AddPartyIdentification(var PartyIdentificationArray: JsonArray; ID: Text; SchemeID: Text)
    var
        IDObject: JsonObject;
    begin
        if ID = '' then
            exit;
        AddSimpleField(IDObject, 'ID', ID, 'schemeID', SchemeID);
        PartyIdentificationArray.Add(IDObject);
    end;

    local procedure AddAddressLines(var PostalAddressObject: JsonObject; Address1: Text; Address2: Text; Address3: Text)
    var
        AddressLineArray: JsonArray;
        LineObject1, LineObject2, LineObject3 : JsonObject;
    begin
        Clear(AddressLineArray);

        if Address1 <> '' then begin
            Clear(LineObject1);
            AddSimpleField(LineObject1, 'Line', Address1);
            AddressLineArray.Add(LineObject1);
        end;

        if Address2 <> '' then begin
            Clear(LineObject2);
            AddSimpleField(LineObject2, 'Line', Address2);
            AddressLineArray.Add(LineObject2);
        end;

        if Address3 <> '' then begin
            Clear(LineObject3);
            AddSimpleField(LineObject3, 'Line', Address3);
            AddressLineArray.Add(LineObject3);
        end;

        PostalAddressObject.Add('AddressLine', AddressLineArray);
    end;

    local procedure AddCountry(var PostalAddressObject: JsonObject; CountryCode: Code[10])
    var
        CountryArray: JsonArray;
        CountryObject: JsonObject;
    begin
        AddSimpleField(CountryObject, 'IdentificationCode', CountryCode, 'listID', 'ISO3166-1', 'listAgencyID', '6');
        CountryArray.Add(CountryObject);
        PostalAddressObject.Add('Country', CountryArray);
    end;

    local procedure AddLineAllowanceCharge(var AllowanceChargeArray: JsonArray; IsCharge: Boolean; Reason: Text; Factor: Decimal; Amount: Decimal; CurrencyCode: Text)
    var
        AllowanceCharge: JsonObject;
    begin
        AddSimpleField(AllowanceCharge, 'ChargeIndicator', Format(IsCharge));
        AddSimpleField(AllowanceCharge, 'AllowanceChargeReason', Reason);
        AddSimpleField(AllowanceCharge, 'MultiplierFactorNumeric', Format(Factor, 0, '<Precision,2:2><Standard Format,2>'));
        AddAmountField(AllowanceCharge, 'Amount', Amount, CurrencyCode);
        AllowanceChargeArray.Add(AllowanceCharge);
    end;
}