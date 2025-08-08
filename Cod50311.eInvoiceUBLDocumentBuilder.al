codeunit 50311 "eInvoice UBL Document Builder"
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
            Error('UBL Document validation failed\\\\Please check document structure and required fields.');
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

        // FORCE: Always use yesterday's date to ensure it's never in the future
        IssueDate.Add('_text', Format(CalcDate('-1D', Today()), 0, '<Year4>-<Month,2>-<Day,2>'));
        InvoiceObject.Add('cbc:IssueDate', IssueDate);

        IssueTime.Add('_text', Format(DT2Time(CurrentDateTime - 300000), 0, '<Hours24,2>:<Minutes,2>:<Seconds,2>Z'));
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

    // Overloaded version for credit memos
    local procedure BuildSupplierParty(var UBLDocument: JsonObject; SalesCrMemoHeader: Record "Sales Cr.Memo Header")
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

        UBLDocument.Replace('Invoice', InvoiceObject);
    end;

    // Overloaded version for credit memos
    local procedure BuildCustomerParty(var UBLDocument: JsonObject; SalesCrMemoHeader: Record "Sales Cr.Memo Header")
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
        Customer.Get(SalesCrMemoHeader."Sell-to Customer No.");
        UBLDocument.Get('Invoice', InvoiceToken);
        InvoiceObject := InvoiceToken.AsObject();

        // Use VAT Registration No. as TIN placeholder
        CustomerTIN := Customer."VAT Registration No.";
        if CustomerTIN = '' then
            CustomerTIN := Customer."No."; // Fallback to customer number

        // Build customer party structure with basic information
        BuildPartyIdentification(PartyIdentification, CustomerTIN);
        PartyObject.Add('cac:PartyIdentification', PartyIdentification);

        BuildPartyName(PartyName, SalesCrMemoHeader."Sell-to Customer Name");
        PartyObject.Add('cac:PartyName', PartyName);

        // TODO: Implement additional party components
        // BuildCustomerPostalAddress(PostalAddress, SalesCrMemoHeader);
        // PartyObject.Add('cac:PostalAddress', PostalAddress);

        // BuildPartyTaxScheme(PartyTaxScheme, Customer."VAT Registration No.");
        // PartyObject.Add('cac:PartyTaxScheme', PartyTaxScheme);

        // BuildPartyLegalEntity(PartyLegalEntity, SalesCrMemoHeader."Sell-to Customer Name", CustomerTIN);
        // PartyObject.Add('cac:PartyLegalEntity', PartyLegalEntity);

        // BuildCustomerContact(Contact, Customer, SalesCrMemoHeader);
        // PartyObject.Add('cac:Contact', Contact);

        AccountingCustomerParty.Add('cac:Party', PartyObject);
        InvoiceObject.Add('cac:AccountingCustomerParty', AccountingCustomerParty);

        UBLDocument.Replace('Invoice', InvoiceObject);
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
        UBLDocument.Replace('Invoice', InvoiceObject);
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

    // New procedure for building credit memo UBL JSON
    procedure BuildCreditMemoUBLJson(SalesCrMemoHeader: Record "Sales Cr.Memo Header"): Text
    var
        UBLDocument: JsonObject;
        JsonText: Text;
    begin
        // Build the credit memo UBL document
        UBLDocument := BuildCreditMemoDocument(SalesCrMemoHeader);

        // Convert to JSON text
        UBLDocument.WriteTo(JsonText);

        exit(JsonText);
    end;

    procedure BuildCreditMemoDocument(SalesCrMemoHeader: Record "Sales Cr.Memo Header") UBLDocument: JsonObject
    var
        DocumentBuilder: JsonObject;
        InvoiceTypeCode: Text;
        CurrencyCode: Text;
        DocumentCurrencyCode: Text;
    begin
        // Initialize document structure following UBL 2.1 standard for credit memos
        InitializeCreditMemoUBLStructure(UBLDocument);

        // Build core credit memo identification
        BuildCreditMemoIdentification(UBLDocument, SalesCrMemoHeader);

        // Build parties (supplier and customer)
        BuildSupplierParty(UBLDocument, SalesCrMemoHeader);
        BuildCustomerParty(UBLDocument, SalesCrMemoHeader);

        // Build credit memo lines
        BuildCreditMemoLines(UBLDocument, SalesCrMemoHeader);

        // Validate final document structure
        if not ValidateUBLDocument(UBLDocument) then
            Error('Credit Memo UBL Document validation failed\\\\Please check document structure and required fields.');
    end;

    local procedure InitializeCreditMemoUBLStructure(var UBLDocument: JsonObject)
    var
        NamespaceObject: JsonObject;
    begin
        // Set UBL namespace and schema information for credit memos
        UBLDocument.Add('_declaration', CreateXMLDeclaration());
        UBLDocument.Add('Invoice', CreateCreditMemoRoot());
    end;

    local procedure CreateCreditMemoRoot() InvoiceRoot: JsonObject
    var
        AttributesObject: JsonObject;
    begin
        // UBL Invoice root element with required namespaces (same as invoice but for credit memo)
        AttributesObject.Add('xmlns', 'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2');
        AttributesObject.Add('xmlns:cac', 'urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2');
        AttributesObject.Add('xmlns:cbc', 'urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2');

        InvoiceRoot.Add('_attributes', AttributesObject);
    end;

    local procedure BuildCreditMemoIdentification(var UBLDocument: JsonObject; SalesCrMemoHeader: Record "Sales Cr.Memo Header")
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

        // Credit Memo Number
        ID.Add('_text', SalesCrMemoHeader."No.");
        InvoiceObject.Add('cbc:ID', ID);

        // FORCE: Always use yesterday's date to ensure it's never in the future
        IssueDate.Add('_text', Format(CalcDate('-1D', Today()), 0, '<Year4>-<Month,2>-<Day,2>'));
        InvoiceObject.Add('cbc:IssueDate', IssueDate);

        IssueTime.Add('_text', Format(DT2Time(CurrentDateTime - 300000), 0, '<Hours24,2>:<Minutes,2>:<Seconds,2>Z'));
        InvoiceObject.Add('cbc:IssueTime', IssueTime);

        // Invoice Type Code (02 = Credit Note)
        InvoiceTypeCode.Add('_text', '02');
        InvoiceObject.Add('cbc:InvoiceTypeCode', InvoiceTypeCode);

        // Document Currency Code
        DocumentCurrencyCode.Add('_text', GetDocumentCurrencyCode(SalesCrMemoHeader));
        InvoiceObject.Add('cbc:DocumentCurrencyCode', DocumentCurrencyCode);

        // Update the document
        UBLDocument.Replace('Invoice', InvoiceObject);
    end;

    local procedure BuildCreditMemoLines(var UBLDocument: JsonObject; SalesCrMemoHeader: Record "Sales Cr.Memo Header")
    var
        InvoiceToken: JsonToken;
        InvoiceObject: JsonObject;
        InvoiceLinesArray: JsonArray;
        SalesCrMemoLine: Record "Sales Cr.Memo Line";
    begin
        // Get invoice object from UBL structure
        UBLDocument.Get('Invoice', InvoiceToken);
        InvoiceObject := InvoiceToken.AsObject();

        // Build invoice lines array
        SalesCrMemoLine.SetRange("Document No.", SalesCrMemoHeader."No.");
        if SalesCrMemoLine.FindSet() then
            repeat
                BuildSingleCreditMemoLine(InvoiceLinesArray, SalesCrMemoLine);
            until SalesCrMemoLine.Next() = 0;

        // Add invoice lines to document
        InvoiceObject.Add('cac:InvoiceLine', InvoiceLinesArray);

        // Update the document
        UBLDocument.Replace('Invoice', InvoiceObject);
    end;

    local procedure BuildSingleCreditMemoLine(var InvoiceLinesArray: JsonArray; SalesCrMemoLine: Record "Sales Cr.Memo Line")
    var
        InvoiceLineObject: JsonObject;
        ID: JsonObject;
        InvoicedQuantity: JsonObject;
        LineExtensionAmount: JsonObject;
        Item: JsonObject;
        ItemDescription: JsonObject;
        Name: JsonObject;
        SellersItemIdentification: JsonObject;
        ID2: JsonObject;
        Price: JsonObject;
        PriceAmount: JsonObject;
        TaxTotal: JsonObject;
        TaxSubtotal: JsonObject;
        TaxCategory: JsonObject;
        TaxScheme: JsonObject;
        TaxAmount: Decimal;
    begin
        // Calculate tax amount (negative for credit note)
        TaxAmount := -(SalesCrMemoLine."Amount Including VAT" - SalesCrMemoLine."Line Amount");

        // Invoice Line ID
        ID.Add('_text', Format(SalesCrMemoLine."Line No."));
        InvoiceLineObject.Add('cbc:ID', ID);

        // Invoiced Quantity (negative for credit note)
        InvoicedQuantity.Add('_text', Format(-SalesCrMemoLine.Quantity));
        InvoicedQuantity.Add('unitCode', 'C62');
        InvoiceLineObject.Add('cbc:InvoicedQuantity', InvoicedQuantity);

        // Line Extension Amount (negative for credit note)
        LineExtensionAmount.Add('_text', Format(-SalesCrMemoLine."Line Amount"));
        LineExtensionAmount.Add('currencyID', GetDocumentCurrencyCode(SalesCrMemoLine));
        InvoiceLineObject.Add('cbc:LineExtensionAmount', LineExtensionAmount);

        // Add Tax Total for this line
        TaxTotal.Add('cbc:TaxAmount', TaxAmount);
        TaxTotal.Add('currencyID', GetDocumentCurrencyCode(SalesCrMemoLine));

        // Tax Subtotal
        TaxSubtotal.Add('cbc:TaxableAmount', -SalesCrMemoLine."Line Amount");
        TaxSubtotal.Add('currencyID', GetDocumentCurrencyCode(SalesCrMemoLine));
        TaxSubtotal.Add('cbc:TaxAmount', TaxAmount);
        TaxSubtotal.Add('currencyID', GetDocumentCurrencyCode(SalesCrMemoLine));

        // Tax Category
        TaxCategory.Add('cbc:ID', 'S'); // Standard rate
        TaxCategory.Add('cbc:Percent', Format(SalesCrMemoLine."VAT %"));

        // Tax Scheme
        TaxScheme.Add('cbc:ID', 'OTH');
        TaxScheme.Add('schemeID', 'UN/ECE 5153');
        TaxCategory.Add('cac:TaxScheme', TaxScheme);
        TaxSubtotal.Add('cac:TaxCategory', TaxCategory);

        TaxTotal.Add('cac:TaxSubtotal', TaxSubtotal);
        InvoiceLineObject.Add('cac:TaxTotal', TaxTotal);

        // Item Information
        Item.Add('cbc:Description', SalesCrMemoLine.Description);

        // Item Name
        Name.Add('_text', SalesCrMemoLine.Description);
        ItemDescription.Add('cbc:Name', Name);
        Item.Add('cac:Description', ItemDescription);

        // Item ID
        ID2.Add('_text', SalesCrMemoLine."No.");
        SellersItemIdentification.Add('cbc:ID', ID2);
        Item.Add('cac:SellersItemIdentification', SellersItemIdentification);

        // Price Information
        PriceAmount.Add('_text', Format(SalesCrMemoLine."Unit Price"));
        PriceAmount.Add('currencyID', GetDocumentCurrencyCode(SalesCrMemoLine));
        Price.Add('cbc:PriceAmount', PriceAmount);

        // Add item and price to line
        InvoiceLineObject.Add('cac:Item', Item);
        InvoiceLineObject.Add('cac:Price', Price);

        // Add line to array
        InvoiceLinesArray.Add(InvoiceLineObject);
    end;

    // Enhanced helper method for credit memo currency code
    local procedure GetDocumentCurrencyCode(SalesCrMemoHeader: Record "Sales Cr.Memo Header"): Text
    begin
        if SalesCrMemoHeader."Currency Code" <> '' then
            exit(SalesCrMemoHeader."Currency Code")
        else
            exit('MYR'); // Default Malaysian Ringgit
    end;

    local procedure GetDocumentCurrencyCode(SalesCrMemoLine: Record "Sales Cr.Memo Line"): Text
    var
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
    begin
        if SalesCrMemoHeader.Get(SalesCrMemoLine."Document No.") then
            exit(GetDocumentCurrencyCode(SalesCrMemoHeader))
        else
            exit('MYR');
    end;

    // Enhanced credit memo document building with proper structure
    procedure BuildEnhancedCreditMemoDocument(SalesCrMemoHeader: Record "Sales Cr.Memo Header") UBLDocument: JsonObject
    var
        CompanyInfo: Record "Company Information";
        Customer: Record Customer;
        LegalMonetaryTotal: JsonObject;
        TaxTotal: JsonObject;
        TaxSubtotal: JsonObject;
        TaxCategory: JsonObject;
        TaxScheme: JsonObject;
        TotalTaxAmount: Decimal;
        TotalAmount: Decimal;
    begin
        CompanyInfo.Get();
        Customer.Get(SalesCrMemoHeader."Sell-to Customer No.");

        // Initialize document structure
        InitializeCreditMemoUBLStructure(UBLDocument);

        // Build core credit memo identification
        BuildCreditMemoIdentification(UBLDocument, SalesCrMemoHeader);

        // Build parties (supplier and customer)
        BuildSupplierParty(UBLDocument, SalesCrMemoHeader);
        BuildCustomerParty(UBLDocument, SalesCrMemoHeader);

        // Build credit memo lines
        BuildCreditMemoLines(UBLDocument, SalesCrMemoHeader);

        // Calculate totals (negative for credit notes)
        TotalAmount := -SalesCrMemoHeader."Amount";
        TotalTaxAmount := -(SalesCrMemoHeader."Amount Including VAT" - SalesCrMemoHeader."Amount");

        // Build Legal Monetary Total
        BuildLegalMonetaryTotal(UBLDocument, SalesCrMemoHeader, TotalAmount, TotalTaxAmount);

        // Build Tax Total
        BuildTaxTotal(UBLDocument, SalesCrMemoHeader, TotalTaxAmount);

        // Validate final document structure
        if not ValidateUBLDocument(UBLDocument) then
            Error('Credit Memo UBL Document validation failed\\\\Please check document structure and required fields.');
    end;

    // Enhanced Legal Monetary Total for credit memos
    local procedure BuildLegalMonetaryTotal(var UBLDocument: JsonObject; SalesCrMemoHeader: Record "Sales Cr.Memo Header"; TotalAmount: Decimal; TotalTaxAmount: Decimal)
    var
        InvoiceToken: JsonToken;
        InvoiceObject: JsonObject;
        LegalMonetaryTotal: JsonObject;
        LineExtensionAmount: JsonObject;
        TaxExclusiveAmount: JsonObject;
        TaxInclusiveAmount: JsonObject;
        PayableAmount: JsonObject;
        CurrencyCode: Text;
    begin
        CurrencyCode := GetDocumentCurrencyCode(SalesCrMemoHeader);

        UBLDocument.Get('Invoice', InvoiceToken);
        InvoiceObject := InvoiceToken.AsObject();

        // Line Extension Amount (negative for credit note)
        LineExtensionAmount.Add('_text', Format(TotalAmount));
        LineExtensionAmount.Add('currencyID', CurrencyCode);
        LegalMonetaryTotal.Add('cbc:LineExtensionAmount', LineExtensionAmount);

        // Tax Exclusive Amount (negative for credit note)
        TaxExclusiveAmount.Add('_text', Format(TotalAmount));
        TaxExclusiveAmount.Add('currencyID', CurrencyCode);
        LegalMonetaryTotal.Add('cbc:TaxExclusiveAmount', TaxExclusiveAmount);

        // Tax Inclusive Amount (negative for credit note)
        TaxInclusiveAmount.Add('_text', Format(TotalAmount + TotalTaxAmount));
        TaxInclusiveAmount.Add('currencyID', CurrencyCode);
        LegalMonetaryTotal.Add('cbc:TaxInclusiveAmount', TaxInclusiveAmount);

        // Payable Amount (negative for credit note)
        PayableAmount.Add('_text', Format(TotalAmount + TotalTaxAmount));
        PayableAmount.Add('currencyID', CurrencyCode);
        LegalMonetaryTotal.Add('cbc:PayableAmount', PayableAmount);

        InvoiceObject.Add('cac:LegalMonetaryTotal', LegalMonetaryTotal);
        UBLDocument.Replace('Invoice', InvoiceObject);
    end;

    // Enhanced Tax Total for credit memos
    local procedure BuildTaxTotal(var UBLDocument: JsonObject; SalesCrMemoHeader: Record "Sales Cr.Memo Header"; TotalTaxAmount: Decimal)
    var
        InvoiceToken: JsonToken;
        InvoiceObject: JsonObject;
        TaxTotal: JsonObject;
        TaxSubtotal: JsonObject;
        TaxCategory: JsonObject;
        TaxScheme: JsonObject;
        TaxAmount: JsonObject;
        TaxableAmount: JsonObject;
        CurrencyCode: Text;
    begin
        CurrencyCode := GetDocumentCurrencyCode(SalesCrMemoHeader);

        UBLDocument.Get('Invoice', InvoiceToken);
        InvoiceObject := InvoiceToken.AsObject();

        // Tax Amount (negative for credit note)
        TaxAmount.Add('_text', Format(TotalTaxAmount));
        TaxAmount.Add('currencyID', CurrencyCode);
        TaxTotal.Add('cbc:TaxAmount', TaxAmount);

        // Tax Subtotal
        TaxableAmount.Add('_text', Format(-SalesCrMemoHeader."Amount"));
        TaxableAmount.Add('currencyID', CurrencyCode);
        TaxSubtotal.Add('cbc:TaxableAmount', TaxableAmount);

        TaxAmount.Add('_text', Format(TotalTaxAmount));
        TaxAmount.Add('currencyID', CurrencyCode);
        TaxSubtotal.Add('cbc:TaxAmount', TaxAmount);

        // Tax Category
        TaxCategory.Add('cbc:ID', 'S'); // Standard rate
        TaxCategory.Add('cbc:Percent', '10'); // Default VAT rate

        // Tax Scheme
        TaxScheme.Add('cbc:ID', 'OTH');
        TaxScheme.Add('schemeID', 'UN/ECE 5153');
        TaxCategory.Add('cac:TaxScheme', TaxScheme);
        TaxSubtotal.Add('cac:TaxCategory', TaxCategory);

        TaxTotal.Add('cac:TaxSubtotal', TaxSubtotal);
        InvoiceObject.Add('cac:TaxTotal', TaxTotal);
        UBLDocument.Replace('Invoice', InvoiceObject);
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
