codeunit 50321 "eInvoice UBL Document Builder"
{
    // Enhanced UBL Document Builder inspired by myinvois-client patterns
    // Provides structured approach to UBL document construction
    // Includes validation and helper methods for common UBL elements

    procedure BuildInvoiceDocument(SalesInvoiceHeader: Record "Sales Invoice Header") UBLDocument: JsonObject
    var
        DocumentBuilder: JsonObject;
        InvoiceTypeCode: Text;
        CurrencyCode: Text;
        DocumentCurrencyCode: Text;
    begin
        // Initialize document structure following UBL 2.1 standard
        InitializeUBLStructure(UBLDocument);

        // Build core invoice identification
        BuildInvoiceIdentification(UBLDocument, SalesInvoiceHeader);

        // Build parties (supplier and customer)
        BuildSupplierParty(UBLDocument, SalesInvoiceHeader);
        BuildCustomerParty(UBLDocument, SalesInvoiceHeader);

        // TODO: Implement additional document components
        // BuildDocumentReferences(UBLDocument, SalesInvoiceHeader);
        // BuildDeliveryInformation(UBLDocument, SalesInvoiceHeader);

        // TODO: Implement payment information
        // BuildPaymentMeans(UBLDocument, SalesInvoiceHeader);
        // BuildPaymentTerms(UBLDocument, SalesInvoiceHeader);

        // TODO: Implement tax information
        // BuildTaxTotal(UBLDocument, SalesInvoiceHeader);

        // TODO: Implement monetary totals
        // BuildLegalMonetaryTotal(UBLDocument, SalesInvoiceHeader);

        // Build invoice lines
        BuildInvoiceLines(UBLDocument, SalesInvoiceHeader);

        // Validate final document structure
        if not ValidateUBLDocument(UBLDocument) then
            Error('UBL Document validation failed\n\nPlease check document structure and required fields.');
    end;

    local procedure InitializeUBLStructure(var UBLDocument: JsonObject)
    var
        NamespaceObject: JsonObject;
    begin
        // Set UBL namespace and schema information (following myinvois standards)
        UBLDocument.Add('_declaration', CreateXMLDeclaration());
        UBLDocument.Add('Invoice', CreateInvoiceRoot());
    end;

    local procedure CreateXMLDeclaration() Declaration: JsonObject
    begin
        Declaration.Add('_attributes', CreateXMLAttributes());
    end;

    local procedure CreateXMLAttributes() Attributes: JsonObject
    begin
        Attributes.Add('version', '1.0');
        Attributes.Add('encoding', 'UTF-8');
    end;

    local procedure CreateInvoiceRoot() InvoiceRoot: JsonObject
    var
        AttributesObject: JsonObject;
    begin
        // UBL Invoice root element with required namespaces
        AttributesObject.Add('xmlns', 'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2');
        AttributesObject.Add('xmlns:cac', 'urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2');
        AttributesObject.Add('xmlns:cbc', 'urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2');

        InvoiceRoot.Add('_attributes', AttributesObject);
    end;

    local procedure BuildInvoiceIdentification(var UBLDocument: JsonObject; SalesInvoiceHeader: Record "Sales Invoice Header")
    var
        InvoiceToken: JsonToken;
        InvoiceObject: JsonObject;
        UBLVersionID: JsonObject;
        CustomizationID: JsonObject;
        ProfileID: JsonObject;
        ID: JsonObject;
        IssueDate: JsonObject;
        IssueTime: JsonObject;
        InvoiceTypeCode: JsonObject;
        DocumentCurrencyCode: JsonObject;
    begin
        // Get invoice object from UBL structure
        UBLDocument.Get('Invoice', InvoiceToken);
        InvoiceObject := InvoiceToken.AsObject();

        // UBL Version (required by myinvois)
        UBLVersionID.Add('_text', '2.1');
        InvoiceObject.Add('cbc:UBLVersionID', UBLVersionID);

        // Customization ID (Malaysia e-Invoice specific)
        CustomizationID.Add('_text', 'MY:1.0');
        InvoiceObject.Add('cbc:CustomizationID', CustomizationID);

        // Profile ID (Malaysia e-Invoice profile)
        ProfileID.Add('_text', 'reporting:1.0');
        InvoiceObject.Add('cbc:ProfileID', ProfileID);

        // Invoice Number
        ID.Add('_text', SalesInvoiceHeader."No.");
        InvoiceObject.Add('cbc:ID', ID);

        // Issue Date
        IssueDate.Add('_text', Format(SalesInvoiceHeader."Document Date", 0, '<Year4>-<Month,2>-<Day,2>'));
        InvoiceObject.Add('cbc:IssueDate', IssueDate);

        // Issue Time (current time or posting time)
        IssueTime.Add('_text', Format(Time, 0, '<Hours24,2>:<Minutes,2>:<Seconds,2>Z'));
        InvoiceObject.Add('cbc:IssueTime', IssueTime);

        // Invoice Type Code (01 = Invoice, 02 = Debit Note, 03 = Credit Note)
        InvoiceTypeCode.Add('_text', GetInvoiceTypeCode(SalesInvoiceHeader));
        InvoiceObject.Add('cbc:InvoiceTypeCode', InvoiceTypeCode);

        // Document Currency Code
        DocumentCurrencyCode.Add('_text', GetDocumentCurrencyCode(SalesInvoiceHeader));
        InvoiceObject.Add('cbc:DocumentCurrencyCode', DocumentCurrencyCode);

        // Update the document
        UBLDocument.Replace('Invoice', InvoiceObject);
    end;

    local procedure BuildSupplierParty(var UBLDocument: JsonObject; SalesInvoiceHeader: Record "Sales Invoice Header")
    var
        InvoiceToken: JsonToken;
        InvoiceObject: JsonObject;
        AccountingSupplierParty: JsonObject;
        PartyObject: JsonObject;
        PartyIdentification: JsonObject;
        PartyName: JsonObject;
        PostalAddress: JsonObject;
        PartyTaxScheme: JsonObject;
        PartyLegalEntity: JsonObject;
        Contact: JsonObject;
        CompanyInfo: Record "Company Information";
    begin
        CompanyInfo.Get();
        UBLDocument.Get('Invoice', InvoiceToken);
        InvoiceObject := InvoiceToken.AsObject();

        // Build supplier party structure with basic information
        BuildPartyIdentification(PartyIdentification, CompanyInfo."Registration No.");
        PartyObject.Add('cac:PartyIdentification', PartyIdentification);

        BuildPartyName(PartyName, CompanyInfo.Name);
        PartyObject.Add('cac:PartyName', PartyName);

        // TODO: Implement additional party components
        // BuildSupplierPostalAddress(PostalAddress, CompanyInfo);
        // PartyObject.Add('cac:PostalAddress', PostalAddress);

        // BuildPartyTaxScheme(PartyTaxScheme, CompanyInfo."VAT Registration No.");
        // PartyObject.Add('cac:PartyTaxScheme', PartyTaxScheme);

        // BuildPartyLegalEntity(PartyLegalEntity, CompanyInfo.Name, CompanyInfo."Registration No.");
        // PartyObject.Add('cac:PartyLegalEntity', PartyLegalEntity);

        // BuildSupplierContact(Contact, CompanyInfo);
        // PartyObject.Add('cac:Contact', Contact);

        AccountingSupplierParty.Add('cac:Party', PartyObject);
        InvoiceObject.Add('cac:AccountingSupplierParty', AccountingSupplierParty);

        UBLDocument.Replace('Invoice', InvoiceToken);
    end;

    local procedure BuildCustomerParty(var UBLDocument: JsonObject; SalesInvoiceHeader: Record "Sales Invoice Header")
    var
        InvoiceToken: JsonToken;
        InvoiceObject: JsonObject;
        AccountingCustomerParty: JsonObject;
        PartyObject: JsonObject;
        PartyIdentification: JsonObject;
        PartyName: JsonObject;
        PostalAddress: JsonObject;
        PartyTaxScheme: JsonObject;
        PartyLegalEntity: JsonObject;
        Contact: JsonObject;
        Customer: Record Customer;
        CustomerTIN: Text;
    begin
        Customer.Get(SalesInvoiceHeader."Sell-to Customer No.");
        UBLDocument.Get('Invoice', InvoiceToken);
        InvoiceObject := InvoiceToken.AsObject();

        // Use VAT Registration No. as TIN placeholder
        CustomerTIN := Customer."VAT Registration No.";
        if CustomerTIN = '' then
            CustomerTIN := Customer."No."; // Fallback to customer number

        // Build customer party structure with basic information
        BuildPartyIdentification(PartyIdentification, CustomerTIN);
        PartyObject.Add('cac:PartyIdentification', PartyIdentification);

        BuildPartyName(PartyName, SalesInvoiceHeader."Sell-to Customer Name");
        PartyObject.Add('cac:PartyName', PartyName);

        // TODO: Implement additional party components
        // BuildCustomerPostalAddress(PostalAddress, SalesInvoiceHeader);
        // PartyObject.Add('cac:PostalAddress', PostalAddress);

        // BuildPartyTaxScheme(PartyTaxScheme, Customer."VAT Registration No.");
        // PartyObject.Add('cac:PartyTaxScheme', PartyTaxScheme);

        // BuildPartyLegalEntity(PartyLegalEntity, SalesInvoiceHeader."Sell-to Customer Name", CustomerTIN);
        // PartyObject.Add('cac:PartyLegalEntity', PartyLegalEntity);

        // BuildCustomerContact(Contact, Customer, SalesInvoiceHeader);
        // PartyObject.Add('cac:Contact', Contact);

        AccountingCustomerParty.Add('cac:Party', PartyObject);
        InvoiceObject.Add('cac:AccountingCustomerParty', AccountingCustomerParty);

        UBLDocument.Replace('Invoice', InvoiceToken);
    end;

    local procedure BuildInvoiceLines(var UBLDocument: JsonObject; SalesInvoiceHeader: Record "Sales Invoice Header")
    var
        InvoiceToken: JsonToken;
        InvoiceObject: JsonObject;
        InvoiceLinesArray: JsonArray;
        SalesInvoiceLine: Record "Sales Invoice Line";
    begin
        UBLDocument.Get('Invoice', InvoiceToken);
        InvoiceObject := InvoiceToken.AsObject();

        SalesInvoiceLine.SetRange("Document No.", SalesInvoiceHeader."No.");
        SalesInvoiceLine.SetFilter(Type, '<>%1', SalesInvoiceLine.Type::" ");
        SalesInvoiceLine.SetFilter(Quantity, '<>0');

        if SalesInvoiceLine.FindSet() then
            repeat
                BuildSingleInvoiceLine(InvoiceLinesArray, SalesInvoiceLine);
            until SalesInvoiceLine.Next() = 0;

        InvoiceObject.Add('cac:InvoiceLine', InvoiceLinesArray);
        UBLDocument.Replace('Invoice', InvoiceToken);
    end;

    local procedure BuildSingleInvoiceLine(var InvoiceLinesArray: JsonArray; SalesInvoiceLine: Record "Sales Invoice Line")
    var
        InvoiceLineObject: JsonObject;
        ID: JsonObject;
        InvoicedQuantity: JsonObject;
        LineExtensionAmount: JsonObject;
        TaxTotal: JsonObject;
        Item: JsonObject;
        Price: JsonObject;
        ClassifiedTaxCategory: JsonObject;
    begin
        // Line ID
        ID.Add('_text', Format(SalesInvoiceLine."Line No."));
        InvoiceLineObject.Add('cbc:ID', ID);

        // TODO: Implement line detail builders
        // BuildInvoicedQuantity(InvoicedQuantity, SalesInvoiceLine);
        // InvoiceLineObject.Add('cbc:InvoicedQuantity', InvoicedQuantity);

        // BuildLineExtensionAmount(LineExtensionAmount, SalesInvoiceLine);
        // InvoiceLineObject.Add('cbc:LineExtensionAmount', LineExtensionAmount);

        // BuildLineTaxTotal(TaxTotal, SalesInvoiceLine);
        // InvoiceLineObject.Add('cac:TaxTotal', TaxTotal);

        // BuildItemInformation(Item, SalesInvoiceLine);
        // InvoiceLineObject.Add('cac:Item', Item);

        // BuildPriceInformation(Price, SalesInvoiceLine);
        // InvoiceLineObject.Add('cac:Price', Price);

        InvoiceLinesArray.Add(InvoiceLineObject);
    end;

    // Helper methods for building specific UBL components
    local procedure BuildPartyIdentification(var PartyIdentification: JsonObject; IdentificationNumber: Text)
    var
        ID: JsonObject;
        IdentificationArray: JsonArray;
        IdentificationObject: JsonObject;
    begin
        ID.Add('_text', IdentificationNumber);
        ID.Add('_attributes', CreateSchemeAttributes('TIN'));
        IdentificationObject.Add('cbc:ID', ID);
        IdentificationArray.Add(IdentificationObject);
        PartyIdentification := IdentificationObject;
    end;

    local procedure BuildPartyName(var PartyName: JsonObject; Name: Text)
    var
        NameElement: JsonObject;
        NameArray: JsonArray;
    begin
        NameElement.Add('_text', Name);
        PartyName.Add('cbc:Name', NameElement);
    end;

    local procedure CreateSchemeAttributes(SchemeID: Text) Attributes: JsonObject
    begin
        Attributes.Add('schemeID', SchemeID);
    end;

    local procedure GetInvoiceTypeCode(SalesInvoiceHeader: Record "Sales Invoice Header") TypeCode: Text
    begin
        // Standard invoice type codes for myinvois
        TypeCode := '01'; // Standard Invoice

        // Could be extended based on document type or custom fields
        // 02 = Debit Note, 03 = Credit Note, etc.
    end;

    local procedure GetDocumentCurrencyCode(SalesInvoiceHeader: Record "Sales Invoice Header") CurrencyCode: Text
    begin
        if SalesInvoiceHeader."Currency Code" <> '' then
            CurrencyCode := SalesInvoiceHeader."Currency Code"
        else
            CurrencyCode := 'MYR'; // Default Malaysian Ringgit
    end;

    local procedure ValidateUBLDocument(UBLDocument: JsonObject) IsValid: Boolean
    var
        InvoiceObject: JsonToken;
        RequiredElements: List of [Text];
        ElementName: Text;
    begin
        // Basic validation of required UBL elements
        if not UBLDocument.Get('Invoice', InvoiceObject) then
            exit(false);

        // Check for required elements
        RequiredElements.Add('cbc:ID');
        RequiredElements.Add('cbc:IssueDate');
        RequiredElements.Add('cbc:InvoiceTypeCode');
        RequiredElements.Add('cbc:DocumentCurrencyCode');
        RequiredElements.Add('cac:AccountingSupplierParty');
        RequiredElements.Add('cac:AccountingCustomerParty');

        foreach ElementName in RequiredElements do
            if not InvoiceObject.AsObject().Contains(ElementName) then
                exit(false);

        IsValid := true;
    end;

    // Additional helper methods would be implemented here for:
    // - BuildSupplierPostalAddress
    // - BuildCustomerPostalAddress
    // - BuildPartyTaxScheme
    // - BuildPartyLegalEntity
    // - BuildSupplierContact
    // - BuildCustomerContact
    // - BuildDocumentReferences
    // - BuildDeliveryInformation
    // - BuildPaymentMeans
    // - BuildPaymentTerms
    // - BuildTaxTotal
    // - BuildLegalMonetaryTotal
    // - BuildInvoicedQuantity
    // - BuildLineExtensionAmount
    // - BuildLineTaxTotal
    // - BuildItemInformation
    // - BuildPriceInformation
}
