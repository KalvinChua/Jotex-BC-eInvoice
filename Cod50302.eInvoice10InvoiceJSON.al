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

        // Build the invoice object with mandatory fields only
        InvoiceObject := CreateInvoiceObject(SalesInvoiceHeader);
        InvoiceArray.Add(InvoiceObject);
        JsonObject.Add('Invoice', InvoiceArray);
    end;

    local procedure CreateInvoiceObject(SalesInvoiceHeader: Record "Sales Invoice Header") InvoiceObject: JsonObject
    var
        Customer: Record Customer;
        CompanyInformation: Record "Company Information";
        SalesInvoiceLine: Record "Sales Invoice Line";
        LineArray: JsonArray;
    begin
        // Mandatory basic invoice information
        AddSimpleField(InvoiceObject, 'ID', SalesInvoiceHeader."No.");
        AddSimpleField(InvoiceObject, 'IssueDate', Format(SalesInvoiceHeader."Posting Date", 0, '<Year4>-<Month,2>-<Day,2>'));

        // Mandatory invoice type code (01 for regular invoice)
        AddCodeField(InvoiceObject, 'InvoiceTypeCode', '01', '1.0');

        // Mandatory currency information
        if SalesInvoiceHeader."Currency Code" = '' then
            AddSimpleField(InvoiceObject, 'DocumentCurrencyCode', 'MYR')
        else
            AddSimpleField(InvoiceObject, 'DocumentCurrencyCode', SalesInvoiceHeader."Currency Code");

        // Mandatory supplier information
        CompanyInformation.Get();
        AddAccountingSupplierParty(InvoiceObject, CompanyInformation);

        // Mandatory customer information
        Customer.Get(SalesInvoiceHeader."Bill-to Customer No.");
        AddAccountingCustomerParty(InvoiceObject, Customer);

        // Mandatory tax totals
        AddTaxTotals(InvoiceObject, SalesInvoiceHeader);

        // Mandatory monetary totals
        AddLegalMonetaryTotal(InvoiceObject, SalesInvoiceHeader);

        // Mandatory invoice lines
        SalesInvoiceLine.SetRange("Document No.", SalesInvoiceHeader."No.");
        if SalesInvoiceLine.FindSet() then
            repeat
                AddInvoiceLine(LineArray, SalesInvoiceLine, SalesInvoiceHeader."Currency Code");
            until SalesInvoiceLine.Next() = 0;

        InvoiceObject.Add('InvoiceLine', LineArray);
    end;

    local procedure AddAccountingSupplierParty(var InvoiceObject: JsonObject; CompanyInformation: Record "Company Information")
    var
        SupplierPartyArray: JsonArray;
        SupplierPartyObject: JsonObject;
        PartyObject: JsonObject;
        PartyIdentificationArray: JsonArray;
        PostalAddressObject: JsonObject;
        PartyLegalEntityObject: JsonObject;
    begin
        Clear(SupplierPartyArray);
        Clear(SupplierPartyObject);

        // Mandatory Party information
        Clear(PartyObject);

        // Mandatory Party Identification (at least one)
        Clear(PartyIdentificationArray);
        AddPartyIdentification(PartyIdentificationArray, CompanyInformation."e-Invoice TIN No.", 'TIN');
        PartyObject.Add('PartyIdentification', PartyIdentificationArray);

        // Mandatory Postal Address
        Clear(PostalAddressObject);
        AddSimpleField(PostalAddressObject, 'CityName', CompanyInformation.City);
        AddSimpleField(PostalAddressObject, 'PostalZone', CompanyInformation."Post Code");
        AddAddressLines(PostalAddressObject, CompanyInformation.Address, CompanyInformation."Address 2", '');
        AddCountry(PostalAddressObject, CompanyInformation."Country/Region Code");
        PartyObject.Add('PostalAddress', PostalAddressObject);

        // Mandatory Party Legal Entity
        Clear(PartyLegalEntityObject);
        AddSimpleField(PartyLegalEntityObject, 'RegistrationName', CompanyInformation.Name);
        PartyObject.Add('PartyLegalEntity', PartyLegalEntityObject);

        SupplierPartyObject.Add('Party', PartyObject);
        SupplierPartyArray.Add(SupplierPartyObject);
        InvoiceObject.Add('AccountingSupplierParty', SupplierPartyArray);
    end;

    local procedure AddAccountingCustomerParty(var InvoiceObject: JsonObject; Customer: Record Customer)
    var
        CustomerPartyArray: JsonArray;
        CustomerPartyObject: JsonObject;
        PartyObject: JsonObject;
        PartyIdentificationArray: JsonArray;
        PostalAddressObject: JsonObject;
        PartyLegalEntityObject: JsonObject;
    begin
        Clear(CustomerPartyArray);
        Clear(CustomerPartyObject);

        // Mandatory Party information
        Clear(PartyObject);

        // Mandatory Party Identification (at least one)
        Clear(PartyIdentificationArray);
        AddPartyIdentification(PartyIdentificationArray, Customer."e-Invoice TIN No.", 'TIN');
        PartyObject.Add('PartyIdentification', PartyIdentificationArray);

        // Mandatory Postal Address
        Clear(PostalAddressObject);
        AddSimpleField(PostalAddressObject, 'CityName', Customer.City);
        AddSimpleField(PostalAddressObject, 'PostalZone', Customer."Post Code");
        AddAddressLines(PostalAddressObject, Customer.Address, Customer."Address 2", '');
        AddCountry(PostalAddressObject, Customer."Country/Region Code");
        PartyObject.Add('PostalAddress', PostalAddressObject);

        // Mandatory Party Legal Entity
        Clear(PartyLegalEntityObject);
        AddSimpleField(PartyLegalEntityObject, 'RegistrationName', Customer.Name);
        PartyObject.Add('PartyLegalEntity', PartyLegalEntityObject);

        CustomerPartyObject.Add('Party', PartyObject);
        CustomerPartyArray.Add(CustomerPartyObject);
        InvoiceObject.Add('AccountingCustomerParty', CustomerPartyArray);
    end;

    local procedure AddTaxTotals(var InvoiceObject: JsonObject; SalesInvoiceHeader: Record "Sales Invoice Header")
    var
        TaxTotalArray: JsonArray;
        TaxTotalObject: JsonObject;
        TaxSubtotalArray: JsonArray;
        TaxSubtotalObject: JsonObject;
        TaxCategoryObject: JsonObject;
    begin
        Clear(TaxTotalArray);
        Clear(TaxTotalObject);

        // Mandatory Tax Amount
        AddAmountField(TaxTotalObject, 'TaxAmount', SalesInvoiceHeader."Amount Including VAT" - SalesInvoiceHeader.Amount, SalesInvoiceHeader."Currency Code");

        // Mandatory Tax Subtotal
        Clear(TaxSubtotalObject);
        AddAmountField(TaxSubtotalObject, 'TaxableAmount', SalesInvoiceHeader.Amount, SalesInvoiceHeader."Currency Code");
        AddAmountField(TaxSubtotalObject, 'TaxAmount', SalesInvoiceHeader."Amount Including VAT" - SalesInvoiceHeader.Amount, SalesInvoiceHeader."Currency Code");

        // Mandatory Tax Category
        Clear(TaxCategoryObject);
        AddSimpleField(TaxCategoryObject, 'ID', 'S'); // Standard rate (adjust based on your VAT setup)
        AddTaxScheme(TaxCategoryObject);
        TaxSubtotalObject.Add('TaxCategory', TaxCategoryObject);

        TaxSubtotalArray.Add(TaxSubtotalObject);
        TaxTotalObject.Add('TaxSubtotal', TaxSubtotalArray);

        TaxTotalArray.Add(TaxTotalObject);
        InvoiceObject.Add('TaxTotal', TaxTotalArray);
    end;

    local procedure AddLegalMonetaryTotal(var InvoiceObject: JsonObject; SalesInvoiceHeader: Record "Sales Invoice Header")
    var
        MonetaryTotalArray: JsonArray;
        MonetaryTotalObject: JsonObject;
    begin
        Clear(MonetaryTotalArray);
        Clear(MonetaryTotalObject);

        // Mandatory fields
        AddAmountField(MonetaryTotalObject, 'TaxExclusiveAmount', SalesInvoiceHeader.Amount, SalesInvoiceHeader."Currency Code");
        AddAmountField(MonetaryTotalObject, 'TaxInclusiveAmount', SalesInvoiceHeader."Amount Including VAT", SalesInvoiceHeader."Currency Code");
        AddAmountField(MonetaryTotalObject, 'PayableAmount', SalesInvoiceHeader."Amount Including VAT", SalesInvoiceHeader."Currency Code");

        MonetaryTotalArray.Add(MonetaryTotalObject);
        InvoiceObject.Add('LegalMonetaryTotal', MonetaryTotalArray);
    end;

    local procedure AddInvoiceLine(var LineArray: JsonArray; SalesInvoiceLine: Record "Sales Invoice Line"; CurrencyCode: Code[10])
    var
        LineObject: JsonObject;
        TaxTotalObject: JsonObject;
        ItemObject: JsonObject;
        PriceObject: JsonObject;
    begin
        Clear(LineObject);

        // Mandatory line information
        AddSimpleField(LineObject, 'ID', Format(SalesInvoiceLine."Line No."));
        AddQuantityField(LineObject, 'InvoicedQuantity', SalesInvoiceLine.Quantity, SalesInvoiceLine."e-Invoice UOM");
        AddAmountField(LineObject, 'LineExtensionAmount', SalesInvoiceLine."Line Amount", CurrencyCode);

        // Mandatory tax total for line
        AddLineTaxTotal(TaxTotalObject, SalesInvoiceLine, CurrencyCode);
        LineObject.Add('TaxTotal', TaxTotalObject);

        // Mandatory item information
        AddItemInformation(ItemObject, SalesInvoiceLine);
        LineObject.Add('Item', ItemObject);

        // Mandatory price information
        AddPriceInformation(PriceObject, SalesInvoiceLine, CurrencyCode);
        LineObject.Add('Price', PriceObject);

        LineArray.Add(LineObject);
    end;

    // Helper methods for specific field types
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

    local procedure AddCodeField(var ParentObject: JsonObject; FieldName: Text; FieldValue: Text; ListVersion: Text)
    var
        ValueArray: JsonArray;
        ValueObject: JsonObject;
    begin
        Clear(ValueArray);
        Clear(ValueObject);

        ValueObject.Add('_', FieldValue);
        if ListVersion <> '' then
            ValueObject.Add('listVersionID', ListVersion);
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
        PartyIDObject: JsonObject;
        IDArray: JsonArray;
    begin
        Clear(PartyIDObject);
        Clear(IDArray);

        AddSimpleField(PartyIDObject, 'ID', ID, 'schemeID', SchemeID);
        PartyIdentificationArray.Add(PartyIDObject);
    end;

    local procedure AddAddressLines(var PostalAddressObject: JsonObject; Address1: Text; Address2: Text; Address3: Text)
    var
        AddressLineArray: JsonArray;
        LineObject1: JsonObject;
    begin
        Clear(AddressLineArray);

        if Address1 <> '' then begin
            Clear(LineObject1);
            AddSimpleField(LineObject1, 'Line', Address1);
            AddressLineArray.Add(LineObject1);
        end;

        PostalAddressObject.Add('AddressLine', AddressLineArray);
    end;

    local procedure AddCountry(var PostalAddressObject: JsonObject; CountryCode: Code[10])
    var
        CountryArray: JsonArray;
        CountryObject: JsonObject;
    begin
        Clear(CountryArray);
        Clear(CountryObject);

        AddSimpleField(CountryObject, 'IdentificationCode', CountryCode, 'listID', 'ISO3166-1', 'listAgencyID', '6');
        CountryArray.Add(CountryObject);
        PostalAddressObject.Add('Country', CountryArray);
    end;

    local procedure AddTaxScheme(var TaxCategoryObject: JsonObject)
    var
        TaxSchemeArray: JsonArray;
        TaxSchemeObject: JsonObject;
    begin
        Clear(TaxSchemeArray);
        Clear(TaxSchemeObject);

        AddSimpleField(TaxSchemeObject, 'ID', 'OTH', 'schemeID', 'UN/ECE 5153', 'schemeAgencyID', '6');
        TaxSchemeArray.Add(TaxSchemeObject);
        TaxCategoryObject.Add('TaxScheme', TaxSchemeArray);
    end;

    local procedure AddLineTaxTotal(var TaxTotalObject: JsonObject; SalesInvoiceLine: Record "Sales Invoice Line"; CurrencyCode: Code[10])
    var
        TaxSubtotalArray: JsonArray;
        TaxSubtotalObject: JsonObject;
        TaxCategoryObject: JsonObject;
    begin
        Clear(TaxSubtotalArray);
        Clear(TaxSubtotalObject);

        AddAmountField(TaxTotalObject, 'TaxAmount', SalesInvoiceLine."Amount Including VAT" - SalesInvoiceLine.Amount, CurrencyCode);

        // Tax subtotal
        AddAmountField(TaxSubtotalObject, 'TaxableAmount', SalesInvoiceLine.Amount, CurrencyCode);
        AddAmountField(TaxSubtotalObject, 'TaxAmount', SalesInvoiceLine."Amount Including VAT" - SalesInvoiceLine.Amount, CurrencyCode);
        AddSimpleField(TaxSubtotalObject, 'Percent', Format(SalesInvoiceLine."VAT %"));

        // Tax category
        Clear(TaxCategoryObject);
        AddSimpleField(TaxCategoryObject, 'ID', 'S'); // Standard rate (adjust based on your VAT setup)
        AddTaxScheme(TaxCategoryObject);
        TaxSubtotalObject.Add('TaxCategory', TaxCategoryObject);

        TaxSubtotalArray.Add(TaxSubtotalObject);
        TaxTotalObject.Add('TaxSubtotal', TaxSubtotalArray);
    end;

    local procedure AddItemInformation(var ItemObject: JsonObject; SalesInvoiceLine: Record "Sales Invoice Line")
    begin
        // Mandatory description
        AddSimpleField(ItemObject, 'Description', SalesInvoiceLine.Description);
    end;

    local procedure AddPriceInformation(var PriceObject: JsonObject; SalesInvoiceLine: Record "Sales Invoice Line"; CurrencyCode: Code[10])
    begin
        // Mandatory price amount
        AddAmountField(PriceObject, 'PriceAmount', SalesInvoiceLine."Unit Price", CurrencyCode);
    end;

    local procedure GetUnitCode(UOM: Text): Text
    begin
        // Map Business Central UOM to standard codes
        case UOM of
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
            else
                exit('C62');
        end;
    end;

    local procedure AddSimpleField(var ParentObject: JsonObject; FieldName: Text; FieldValue: Text; AttributeName1: Text; AttributeValue1: Text)
    var
        ValueArray: JsonArray;
        ValueObject: JsonObject;
    begin
        Clear(ValueArray);
        Clear(ValueObject);

        ValueObject.Add('_', FieldValue);
        if AttributeName1 <> '' then
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
        if AttributeName1 <> '' then
            ValueObject.Add(AttributeName1, AttributeValue1);
        if AttributeName2 <> '' then
            ValueObject.Add(AttributeName2, AttributeValue2);

        ValueArray.Add(ValueObject);
        ParentObject.Add(FieldName, ValueArray);
    end;
}