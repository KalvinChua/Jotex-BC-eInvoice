/// <summary>
/// Business Central e-Invoice JSON Generator and Azure Function Integration
/// 
/// PURPOSE:
/// Generate LHDN-compliant UBL 2.1 JSON invoices and process through Azure Function for digital signing
/// 
/// INTEGRATION FLOW:
/// 1. Business Central generates unsigned e-Invoice JSON (UBL 2.1 format)
/// 2. Posts JSON to Azure Function with proper payload structure
/// 3. Azure Function digitally signs using JOTEX P12 certificate (7-step process)
/// 4. Returns signed JSON and LHDN-ready payload to Business Central
/// 5. Business Central submits to LHDN MyInvois API
/// 6. Processes LHDN response and updates invoice status
/// 
/// AZURE FUNCTION INTEGRATION:
/// - Endpoint: Configurable in eInvoice Setup
/// - Payload: {"unsignedJson": "...", "invoiceType": "01", "environment": "PREPROD/PRODUCTION", "timestamp": "...", "requestId": "..."}
/// - Response: {"success": true, "signedJson": "...", "lhdnPayload": {"documents": [...]}}
/// - Error Handling: Comprehensive validation and retry logic
/// 
/// LHDN COMPLIANCE:
/// - UBL 2.1 JSON structure as per LHDN specification
/// - Digital signature using JOTEX certificate infrastructure
/// - Proper TIN validation and environment-specific endpoints
/// - Complete audit trail for compliance requirements
/// 
/// CUSTOMIZATION POINTS:
/// - Business logic helper procedures for company-specific mappings
/// - Field population based on your Business Central setup
/// - Error handling and logging preferences
/// 
/// Author: Business Central e-Invoice Integration Team
/// Version: 2.0 - Enhanced with Azure Function integration and comprehensive error handling
/// Last Updated: July 2025
/// </summary>
codeunit 50302 "eInvoice 1.0 Invoice JSON"
{
    // ======================================================================================================
    // MAIN AZURE FUNCTION INTEGRATION PROCEDURES
    // ======================================================================================================

    /// <summary>
    /// Sends unsigned e-Invoice JSON to Azure Function for digital signing using JOTEX certificate
    /// This is a simplified version - main logic moved to TryPostToAzureFunction for better error handling
    /// </summary>
    /// <param name="JsonText">Unsigned e-Invoice JSON in UBL 2.1 format</param>
    /// <param name="AzureFunctionUrl">Azure Function endpoint URL for signing service</param>
    /// <param name="ResponseText">Response from Azure Function containing signed JSON and LHDN payload</param>
    procedure PostJsonToAzureFunction(JsonText: Text; AzureFunctionUrl: Text; var ResponseText: Text)
    begin
        // This procedure is kept for backward compatibility
        // All logic moved to TryPostToAzureFunction to prevent recursive calls
        if not TryPostToAzureFunction(JsonText, AzureFunctionUrl, ResponseText) then
            Error('Failed to communicate with Azure Function. Please check the configuration and try again.');
    end;

    // ======================================================================================================
    // MAIN E-INVOICE JSON GENERATION PROCEDURES
    // ======================================================================================================

    /// <summary>
    /// Generates LHDN-compliant UBL 2.1 JSON for Sales Invoice
    /// </summary>
    /// <param name="SalesInvoiceHeader">Sales Invoice record to convert</param>
    /// <param name="IncludeSignature">Whether to include digital signature placeholder</param>
    /// <returns>Complete UBL 2.1 JSON string</returns>
    procedure GenerateEInvoiceJson(SalesInvoiceHeader: Record "Sales Invoice Header"; IncludeSignature: Boolean) JsonText: Text
    var
        JsonObject: JsonObject;
        StartTime: DateTime;
    begin
        StartTime := CurrentDateTime;

        // Validate input
        if SalesInvoiceHeader."No." = '' then
            Error('Sales Invoice Header cannot be empty');

        JsonObject := BuildEInvoiceJson(SalesInvoiceHeader, IncludeSignature);
        JsonObject.WriteTo(JsonText);

        // Validate output
        if JsonText = '' then
            Error('Failed to generate JSON for invoice %1', SalesInvoiceHeader."No.");

        // Log completion
        // Message('eInvoice JSON generated for %1 in %2 ms', 
        //     SalesInvoiceHeader."No.", 
        //     CurrentDateTime - StartTime);
    end;

    local procedure BuildEInvoiceJson(SalesInvoiceHeader: Record "Sales Invoice Header"; IncludeSignature: Boolean) JsonObject: JsonObject
    var
        InvoiceArray: JsonArray;
        InvoiceObject: JsonObject;
    begin
        // UBL 2.1 namespace declarations
        JsonObject.Add('_D', 'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2');
        JsonObject.Add('_A', 'urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2');
        JsonObject.Add('_B', 'urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2');

        // Build the invoice object
        InvoiceObject := CreateInvoiceObject(SalesInvoiceHeader, IncludeSignature);
        InvoiceArray.Add(InvoiceObject);
        JsonObject.Add('Invoice', InvoiceArray);
    end;

    local procedure CreateInvoiceObject(SalesInvoiceHeader: Record "Sales Invoice Header"; IncludeSignature: Boolean) InvoiceObject: JsonObject
    var
        Customer: Record Customer;
        CompanyInformation: Record "Company Information";
        CurrencyCode: Code[10];
        NowUTC: DateTime;
    begin
        // Validate mandatory fields
        if SalesInvoiceHeader."No." = '' then
            Error('Invoice number is required');
        if SalesInvoiceHeader."Bill-to Customer No." = '' then
            Error('Bill-to Customer No. is required for invoice %1', SalesInvoiceHeader."No.");
        if SalesInvoiceHeader."Posting Date" = 0D then
            Error('Posting Date is required for invoice %1', SalesInvoiceHeader."No.");

        // Get currency code
        if SalesInvoiceHeader."Currency Code" = '' then
            CurrencyCode := 'MYR'
        else
            CurrencyCode := SalesInvoiceHeader."Currency Code";

        // Core invoice fields
        AddBasicField(InvoiceObject, 'ID', SalesInvoiceHeader."No.");
        // LHDN: IssueDate = Posting Date, IssueTime = current UTC time (buffered)
        NowUTC := CurrentDateTime - 60000; // Subtract 60,000 ms = 1 minute
        AddBasicField(InvoiceObject, 'IssueDate', Format(SalesInvoiceHeader."Posting Date", 0, '<Year4>-<Month,2>-<Day,2>'));
        AddBasicField(InvoiceObject, 'IssueTime', Format(DT2Time(NowUTC), 0, '<Hours24,2>:<Minutes,2>:<Seconds,2>Z'));

        // Invoice type code with list version
        if SalesInvoiceHeader."eInvoice Version Code" <> '' then
            AddFieldWithAttribute(InvoiceObject, 'InvoiceTypeCode', SalesInvoiceHeader."eInvoice Document Type", 'listVersionID', SalesInvoiceHeader."eInvoice Version Code")
        else
            AddFieldWithAttribute(InvoiceObject, 'InvoiceTypeCode', SalesInvoiceHeader."eInvoice Document Type", 'listVersionID', '1.0'); // Default to version 1.0

        // Currency codes
        AddBasicField(InvoiceObject, 'DocumentCurrencyCode', CurrencyCode);
        AddBasicField(InvoiceObject, 'TaxCurrencyCode', CurrencyCode);

        // MANDATORY: Currency exchange rate for non-MYR currencies
        if CurrencyCode <> 'MYR' then
            AddTaxExchangeRate(InvoiceObject, SalesInvoiceHeader, CurrencyCode);

        // Invoice Period
        AddInvoicePeriod(InvoiceObject, SalesInvoiceHeader);

        // Billing reference (if applicable)
        AddBillingReference(InvoiceObject, SalesInvoiceHeader);

        // Additional document references
        AddAdditionalDocumentReferences(InvoiceObject, SalesInvoiceHeader);

        // Party information
        if not CompanyInformation.Get() then
            Error('Company Information not found');
        AddAccountingSupplierParty(InvoiceObject, CompanyInformation);

        if not Customer.Get(SalesInvoiceHeader."Bill-to Customer No.") then
            Error('Customer %1 not found', SalesInvoiceHeader."Bill-to Customer No.");
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

        // Digital signature (only required for version 1.1 and if requested)
        if (SalesInvoiceHeader."eInvoice Version Code" = '1.1') and IncludeSignature then
            AddDigitalSignature(InvoiceObject, SalesInvoiceHeader);
    end;

    local procedure GetSafeMalaysiaTime(PostingDate: Date): Text
    var
        CurrentTime: Time;
        TimeText: Text;
    begin
        // CRITICAL COMPLIANCE: LHDN requires CURRENT time, not fixed time
        // Per documentation: "Time of issuance of the e-Invoice *Note that the time must be the current time"
        CurrentTime := Time();
        TimeText := Format(CurrentTime, 0, '<Hours24,2>:<Minutes,2>:<Seconds,2>Z');
        exit(TimeText);
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
            AddBasicField(RefObject, 'DocumentType', 'PurchaseOrder');
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
        // Additional Account ID (for certifications like CertEX) - only if available
        if GetCertificationID() <> '' then begin
            AdditionalAccountIDObject.Add('_', GetCertificationID());
            AdditionalAccountIDObject.Add('schemeAgencyName', 'CertEX');
            AdditionalAccountIDArray.Add(AdditionalAccountIDObject);
            SupplierObject.Add('AdditionalAccountID', AdditionalAccountIDArray);
        end;

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

        // MANDATORY: Contact information per LHDN spec
        if CompanyInfo."Phone No." = '' then
            Error('Company phone number is mandatory for eInvoice compliance');
        AddBasicField(ContactObject, 'Telephone', CompanyInfo."Phone No.");

        if CompanyInfo."e-Invoice Email" = '' then
            Error('Company email is mandatory for eInvoice compliance');
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

        // MANDATORY: Contact information per LHDN spec
        if Customer."Phone No." = '' then
            Error('Customer phone number is mandatory for eInvoice compliance. Customer: %1', Customer."No.");
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
        AddAmountField(LineObject, 'LineExtensionAmount', SalesInvoiceLine.Amount, GetCurrencyCodeFromText(CurrencyCode));

        // Line allowances/charges
        if SalesInvoiceLine."Line Discount Amount" > 0 then
            AddLineAllowanceCharge(AllowanceChargeArray, false, '',
                SalesInvoiceLine."Line Discount %", SalesInvoiceLine."Line Discount Amount", GetCurrencyCodeFromText(CurrencyCode));

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
        AddAmountField(TaxTotalObject, 'TaxAmount', SalesInvoiceLine."Amount Including VAT" - SalesInvoiceLine.Amount, GetCurrencyCodeFromText(CurrencyCode));

        // Tax subtotal
        AddAmountField(TaxSubtotalObject, 'TaxableAmount', SalesInvoiceLine.Amount, GetCurrencyCodeFromText(CurrencyCode));
        AddAmountField(TaxSubtotalObject, 'TaxAmount', SalesInvoiceLine."Amount Including VAT" - SalesInvoiceLine.Amount, GetCurrencyCodeFromText(CurrencyCode));
        AddNumericField(TaxSubtotalObject, 'Percent', SalesInvoiceLine."VAT %");

        // Tax category
        AddBasicField(TaxCategoryObject, 'ID', SalesInvoiceLine."e-Invoice Tax Type");

        // Add TaxExemptionReason only for exempt tax types
        if SalesInvoiceLine."e-Invoice Tax Type" in ['E', 'Z'] then
            AddBasicField(TaxCategoryObject, 'TaxExemptionReason', GetTaxExemptionReason(SalesInvoiceLine."e-Invoice Tax Type"));

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
        // MANDATORY: Product Tariff Code (PTC) - FIRST classification
        ItemClassificationCodeObject.Add('_', GetHSCode(SalesInvoiceLine));
        ItemClassificationCodeObject.Add('listID', 'PTC');
        ItemClassificationCodeArray.Add(ItemClassificationCodeObject);
        CommodityObject.Add('ItemClassificationCode', ItemClassificationCodeArray);
        CommodityArray.Add(CommodityObject);

        // MANDATORY: Classification Code (CLASS) - SECOND classification  
        Clear(CommodityObject);
        Clear(ItemClassificationCodeArray);
        Clear(ItemClassificationCodeObject);
        ItemClassificationCodeObject.Add('_', GetClassificationCode(SalesInvoiceLine));
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
        AddAmountField(PriceObject, 'PriceAmount', SalesInvoiceLine."Unit Price", GetCurrencyCodeFromText(CurrencyCode));
        PriceArray.Add(PriceObject);
        LineObject.Add('Price', PriceArray);

        // Item price extension
        AddAmountField(ItemPriceExtensionObject, 'Amount', SalesInvoiceLine.Amount, GetCurrencyCodeFromText(CurrencyCode));
        ItemPriceExtensionArray.Add(ItemPriceExtensionObject);
        LineObject.Add('ItemPriceExtension', ItemPriceExtensionArray);

        LineArray.Add(LineObject);
    end;

    local procedure AddDigitalSignature(var InvoiceObject: JsonObject; SalesInvoiceHeader: Record "Sales Invoice Header")
    var
        UBLExtensionsArray: JsonArray;
        UBLExtensionsObject: JsonObject;
        UBLExtensionArray: JsonArray;
        UBLExtensionObject: JsonObject;
        ExtensionURIArray: JsonArray;
        ExtensionURIObject: JsonObject;
        ExtensionContentArray: JsonArray;
        ExtensionContentObject: JsonObject;
        UBLDocumentSignaturesArray: JsonArray;
        UBLDocumentSignaturesObject: JsonObject;
        SignatureInformationArray: JsonArray;
        SignatureInformationObject: JsonObject;
        SignatureArray: JsonArray;
        SignatureObject: JsonObject;
    begin
        // MANDATORY for version 1.1: UBLExtensions with proper signature structure
        ExtensionURIObject.Add('_', 'urn:oasis:names:specification:ubl:dsig:enveloped:xades');
        ExtensionURIArray.Add(ExtensionURIObject);
        UBLExtensionObject.Add('ExtensionURI', ExtensionURIArray);

        // Build proper UBLDocumentSignatures structure
        AddBasicField(SignatureInformationObject, 'ID', 'urn:oasis:names:specification:ubl:signature:1');
        AddBasicField(SignatureInformationObject, 'ReferencedSignatureID', 'urn:oasis:names:specification:ubl:signature:Invoice');

        // Add placeholder signature structure - implement actual cryptographic signing
        AddBasicField(SignatureInformationObject, 'Signature', 'PLACEHOLDER_SIGNATURE_CONTENT');

        SignatureInformationArray.Add(SignatureInformationObject);
        UBLDocumentSignaturesObject.Add('SignatureInformation', SignatureInformationArray);
        UBLDocumentSignaturesArray.Add(UBLDocumentSignaturesObject);
        ExtensionContentObject.Add('UBLDocumentSignatures', UBLDocumentSignaturesArray);

        ExtensionContentArray.Add(ExtensionContentObject);
        UBLExtensionObject.Add('ExtensionContent', ExtensionContentArray);

        UBLExtensionArray.Add(UBLExtensionObject);
        UBLExtensionsObject.Add('UBLExtension', UBLExtensionArray);
        UBLExtensionsArray.Add(UBLExtensionsObject);
        InvoiceObject.Add('UBLExtensions', UBLExtensionsArray);

        // Simple Signature section as per LHDN sample
        AddBasicField(SignatureObject, 'ID', 'urn:oasis:names:specification:ubl:signature:Invoice');
        AddBasicField(SignatureObject, 'SignatureMethod', 'urn:oasis:names:specification:ubl:dsig:enveloped:xades');

        SignatureArray.Add(SignatureObject);
        InvoiceObject.Add('Signature', SignatureArray);
    end;

    local procedure AddTaxExchangeRate(var InvoiceObject: JsonObject; SalesInvoiceHeader: Record "Sales Invoice Header"; SourceCurrencyCode: Code[10])
    var
        TaxExchangeRateArray: JsonArray;
        TaxExchangeRateObject: JsonObject;
        CurrencyExchangeRate: Record "Currency Exchange Rate";
        ExchangeRate: Decimal;
    begin
        // MANDATORY for non-MYR currencies per LHDN specification
        // Get exchange rate from Business Central
        ExchangeRate := 1.0; // Default

        if CurrencyExchangeRate.Get(SourceCurrencyCode, Today()) then
            ExchangeRate := CurrencyExchangeRate."Exchange Rate Amount"
        else if CurrencyExchangeRate.Get(SourceCurrencyCode, SalesInvoiceHeader."Posting Date") then
            ExchangeRate := CurrencyExchangeRate."Exchange Rate Amount";

        AddBasicField(TaxExchangeRateObject, 'SourceCurrencyCode', SourceCurrencyCode);
        AddBasicField(TaxExchangeRateObject, 'TargetCurrencyCode', 'MYR');
        AddNumericField(TaxExchangeRateObject, 'CalculationRate', ExchangeRate);
        AddBasicField(TaxExchangeRateObject, 'Date', Format(Today(), 0, '<Year4>-<Month,2>-<Day,2>'));

        TaxExchangeRateArray.Add(TaxExchangeRateObject);
        InvoiceObject.Add('TaxExchangeRate', TaxExchangeRateArray);
    end;

    // ======================================================================================================
    // UBL 2.1 JSON STRUCTURE HELPER PROCEDURES
    // These procedures ensure proper LHDN-compliant JSON structure formatting
    // ======================================================================================================

    /// <summary>
    /// Adds a basic field with text value in UBL 2.1 array format
    /// </summary>
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

    /// <summary>
    /// Adds a field with one attribute in UBL 2.1 format
    /// </summary>
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

    /// <summary>
    /// Wrapper for AddFieldWithAttribute - maintains backward compatibility
    /// </summary>
    local procedure AddBasicFieldWithAttribute(var ParentObject: JsonObject; FieldName: Text; FieldValue: Text; AttributeName: Text; AttributeValue: Text)
    begin
        AddFieldWithAttribute(ParentObject, FieldName, FieldValue, AttributeName, AttributeValue);
    end;

    /// <summary>
    /// Adds a field with two attributes in UBL 2.1 format
    /// </summary>
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

    /// <summary>
    /// Adds amount field with currency code attribute - includes validation for negative amounts
    /// </summary>
    local procedure AddAmountField(var ParentObject: JsonObject; FieldName: Text; Amount: Decimal; CurrencyCode: Text)
    var
        ValueArray: JsonArray;
        ValueObject: JsonObject;
    begin
        // Validate amount is not negative for invoice amounts
        if (FieldName in ['LineExtensionAmount', 'TaxAmount', 'PayableAmount']) and (Amount < 0) then
            Error('Amount field %1 cannot be negative: %2', FieldName, Amount);

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

    local procedure AddNumericField(var ParentObject: JsonObject; FieldName: Text; NumericValue: Decimal)
    var
        ValueArray: JsonArray;
        ValueObject: JsonObject;
    begin
        // For numeric fields that LHDN expects as numbers, not strings
        ValueObject.Add('_', NumericValue);
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

    local procedure GetCurrencyCodeFromText(CurrencyCode: Code[10]): Code[10]
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
    var
        UpperCounty: Text;
    begin
        UpperCounty := UpperCase(County);
        case UpperCounty of
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
        case UpperCase(CountryRegionCode) of
            'MY', 'MYS', 'MALAYSIA':
                exit('MYS');
            'SG', 'SGP', 'SINGAPORE':
                exit('SGP');
            'TH', 'THA', 'THAILAND':
                exit('THA');
            'ID', 'IDN', 'INDONESIA':
                exit('IDN');
            'PH', 'PHL', 'PHILIPPINES':
                exit('PHL');
            'VN', 'VNM', 'VIETNAM':
                exit('VNM');
            'US', 'USA', 'UNITED STATES':
                exit('USA');
            'GB', 'GBR', 'UNITED KINGDOM':
                exit('GBR');
            'CN', 'CHN', 'CHINA':
                exit('CHN');
            'JP', 'JPN', 'JAPAN':
                exit('JPN');
            'AU', 'AUS', 'AUSTRALIA':
                exit('AUS');
            else
                exit('MYS'); // Default to Malaysia
        end;
    end;

    // ======================================================================================================
    // BUSINESS LOGIC HELPER PROCEDURES
    // Configure these based on your company setup and Business Central field mappings
    // ======================================================================================================

    /// <summary>
    /// Gets tax category code with fallback to standard rate
    /// </summary>
    local procedure GetTaxCategoryCode(eInvoiceTaxCategoryCode: Code[10]): Code[10]
    begin
        if eInvoiceTaxCategoryCode <> '' then
            exit(eInvoiceTaxCategoryCode)
        else
            exit('01'); // Default to standard rate if empty
    end;

    /// <summary>
    /// Gets company MSIC code from Company Information or returns default
    /// </summary>
    local procedure GetMSICCode(): Text
    var
        CompanyInformation: Record "Company Information";
    begin
        // Return your company's MSIC code - customize this based on your field mappings
        if CompanyInformation.Get() then begin
            if CompanyInformation."MSIC Code" <> '' then
                exit(CompanyInformation."MSIC Code");
        end;
        exit('46510'); // Default MSIC code for wholesale computer hardware
    end;

    /// <summary>
    /// Gets company MSIC description from Company Information or returns default
    /// </summary>
    local procedure GetMSICDescription(): Text
    var
        CompanyInformation: Record "Company Information";
    begin
        // Return your company's MSIC description - customize this
        if CompanyInformation.Get() then begin
            if CompanyInformation."Business Activity Description" <> '' then
                exit(CompanyInformation."Business Activity Description");
        end;
        exit('Wholesale of computer hardware, software and peripherals'); // Default description
    end;

    /// <summary>
    /// Gets certification ID (e.g., CertEX ID) - customize based on your requirements
    /// </summary>
    local procedure GetCertificationID(): Text
    begin
        // Return your certification ID - add custom field to Company Information if needed
        exit(''); // Return empty if no certification required
    end;

    /// <summary>
    /// Gets company SST registration number or returns 'NA'
    /// </summary>
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
        if Customer."e-Invoice SST No." <> '' then
            exit(Customer."e-Invoice SST No.")
        else
            exit('NA');
    end;

    local procedure GetCustomerTTXNumber(Customer: Record Customer): Text
    begin
        // Return customer's TTX number if available
        // Add field to Customer table extension if needed
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
        exit('1234567890123'); // Default bank account if not found
    end;

    local procedure GetPaymentTermsNote(SalesInvoiceHeader: Record "Sales Invoice Header"): Text
    var
        PaymentTerms: Record "Payment Terms";
        PaymentModeCode: Code[10];
    begin
        // Return payment terms description based on Payment Mode, not Payment Terms Code
        PaymentModeCode := GetPaymentMeansCode(SalesInvoiceHeader);

        case PaymentModeCode of
            '01':
                exit('Bank Transfer');
            '02':
                exit('Cheque');
            '03':
                exit('Payment method is cash');
            '04':
                exit('Credit Card');
            '05':
                exit('Debit Card');
            '06':
                exit('e-Wallet/Digital Wallet');
            else begin
                // Fallback to Payment Terms if available
                if PaymentTerms.Get(SalesInvoiceHeader."Payment Terms Code") then begin
                    if PaymentTerms.Description <> '' then
                        exit(PaymentTerms.Description)
                    else
                        exit('Payment due ' + Format(PaymentTerms."Due Date Calculation"));
                end;
                exit('Others');
            end;
        end;
    end;

    local procedure GetHSCode(SalesInvoiceLine: Record "Sales Invoice Line"): Text
    begin
        // Return the HS code directly from the e-Invoice Classification field
        if SalesInvoiceLine."e-Invoice Classification" <> '' then
            exit(SalesInvoiceLine."e-Invoice Classification")
        else
            exit('022'); // Default HS code if empty
    end;

    local procedure GetClassificationCode(SalesInvoiceLine: Record "Sales Invoice Line"): Text
    begin
        // MANDATORY: Return classification code as per LHDN requirement
        // This should be configured in your item setup or use default
        // Common codes: 001=Goods, 002=Services, 003=Mixed
        if SalesInvoiceLine.Type = SalesInvoiceLine.Type::Item then
            exit('001') // Goods
        else
            exit('002'); // Services
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

    local procedure GetTaxExemptionReason(TaxType: Code[10]): Text
    begin
        // Return appropriate tax exemption reason based on tax type
        case TaxType of
            'E':
                exit('Exempt New Means of Transport');
            'Z':
                exit('Zero-rated supply');
            else
                exit('');
        end;
    end;

    /// <summary>
    /// Complete integration workflow: Generate → Sign → Submit to LHDN
    /// Handles the full process from unsigned JSON to LHDN submission with proper error handling
    /// </summary>
    /// <param name="SalesInvoiceHeader">Sales Invoice record to process</param>
    /// <param name="LhdnResponse">Final response from LHDN MyInvois API</param>
    /// <returns>True if entire process successful, False if any step fails</returns>
    procedure GetSignedInvoiceAndSubmitToLHDN(SalesInvoiceHeader: Record "Sales Invoice Header"; var LhdnResponse: Text): Boolean
    var
        UnsignedJsonText: Text;
        AzureResponseText: Text;
        AzureResponse: JsonObject;
        JsonToken: JsonToken;
        eInvoiceSetup: Record "eInvoiceSetup";
        AzureFunctionUrl: Text;
    begin
        // Step 1: Generate unsigned eInvoice JSON
        UnsignedJsonText := GenerateEInvoiceJson(SalesInvoiceHeader, false);

        // Step 2: Get Azure Function URL from setup
        if not eInvoiceSetup.Get('SETUP') then
            Error('eInvoice Setup not found. Please configure the Azure Function URL.');

        AzureFunctionUrl := eInvoiceSetup."Azure Function URL";
        if AzureFunctionUrl = '' then
            Error('Azure Function URL is not configured in eInvoice Setup.');

        // Step 3: Get signed invoice from Azure Function with improved error handling
        if not TryPostToAzureFunction(UnsignedJsonText, AzureFunctionUrl, AzureResponseText) then
            Error('Failed to communicate with Azure Function. Please check connectivity and try again.');

        // Step 4: Parse Azure Function response with detailed validation
        if not AzureResponse.ReadFrom(AzureResponseText) then
            Error('Invalid JSON response from Azure Function: %1', CopyStr(AzureResponseText, 1, 500));

        // Check for success status
        if not AzureResponse.Get('success', JsonToken) or not JsonToken.AsValue().AsBoolean() then begin
            if AzureResponse.Get('error', JsonToken) then
                Error('Azure Function signing failed: %1', JsonToken.AsValue().AsText())
            else if AzureResponse.Get('message', JsonToken) then
                Error('Azure Function error: %1', JsonToken.AsValue().AsText())
            else
                Error('Azure Function signing failed with unknown error. Response: %1', CopyStr(AzureResponseText, 1, 200));
        end;

        // Step 5: Process and store signed JSON (important for audit trail)
        if AzureResponse.Get('signedJson', JsonToken) then begin
            // Store the signed JSON for records/audit purposes
            StoreSignedInvoiceJson(SalesInvoiceHeader, JsonToken.AsValue().AsText());
        end;

        // Step 6: Extract LHDN payload and submit to LHDN API
        // Expected Azure Function response format:
        // {
        //   "success": true,
        //   "signedJson": "...",
        //   "lhdnPayload": { "documents": [...] }
        // }
        if AzureResponse.Get('lhdnPayload', JsonToken) then begin
            // Validate the LHDN payload structure before submission
            if ValidateLhdnPayloadStructure(JsonToken.AsValue().AsText()) then
                exit(SubmitToLhdnApi(JsonToken.AsObject(), SalesInvoiceHeader, LhdnResponse))
            else
                Error('Invalid LHDN payload structure received from Azure Function');
        end else
            Error('No LHDN payload found in Azure Function response. Response keys: %1', GetJsonObjectKeys(AzureResponse));
    end;

    /// <summary>
    /// Safer HTTP call wrapper with proper error handling and retry logic
    /// Prevents recursive calls and memory issues by implementing controlled retry mechanism
    /// </summary>
    /// <param name="JsonText">JSON payload to send</param>
    /// <param name="AzureFunctionUrl">Azure Function endpoint URL</param>
    /// <param name="ResponseText">Response from Azure Function</param>
    /// <returns>True if successful, False if failed after all retries</returns>
    local procedure TryPostToAzureFunction(JsonText: Text; AzureFunctionUrl: Text; var ResponseText: Text): Boolean
    var
        HttpClient: HttpClient;
        RequestContent: HttpContent;
        Response: HttpResponseMessage;
        Headers: HttpHeaders;
        PayloadObject: JsonObject;
        PayloadText: Text;
        Setup: Record "eInvoiceSetup";
        EnvironmentText: Text;
        AttemptCount: Integer;
        MaxAttempts: Integer;
        LastError: Text;
        CallSuccessful: Boolean;
    begin
        // Initialize variables
        ResponseText := '';
        CallSuccessful := false;
        MaxAttempts := 3;
        LastError := '';

        // Get environment setting from setup
        if Setup.Get('SETUP') then begin
            case Setup.Environment of
                Setup.Environment::Preprod:
                    EnvironmentText := 'PREPROD';
                Setup.Environment::Production:
                    EnvironmentText := 'PRODUCTION';
                else
                    EnvironmentText := 'PREPROD';
            end;
        end else
            EnvironmentText := 'PREPROD';

        // Validate inputs before attempting
        if JsonText = '' then begin
            LastError := 'Cannot send empty JSON to Azure Function';
            exit(false);
        end;

        if AzureFunctionUrl = '' then begin
            LastError := 'Azure Function URL is not configured';
            exit(false);
        end;

        // Create proper JSON payload structure
        PayloadObject.Add('unsignedJson', JsonText);
        PayloadObject.Add('invoiceType', '01');
        PayloadObject.Add('environment', EnvironmentText);
        PayloadObject.Add('timestamp', Format(CurrentDateTime, 0, '<Year4>-<Month,2>-<Day,2>T<Hours24,2>:<Minutes,2>:<Seconds,2>Z'));
        PayloadObject.Add('requestId', CreateGuid());
        PayloadObject.WriteTo(PayloadText);

        // Attempt HTTP call with retry logic
        for AttemptCount := 1 to MaxAttempts do begin
            Clear(HttpClient);
            Clear(RequestContent);
            Clear(Response);
            Clear(Headers);

            // Set up request content
            RequestContent.WriteFrom(PayloadText);
            RequestContent.GetHeaders(Headers);
            Headers.Clear();
            Headers.Add('Content-Type', 'application/json');

            // Make HTTP request
            if HttpClient.Post(AzureFunctionUrl, RequestContent, Response) then begin
                if Response.IsSuccessStatusCode then begin
                    Response.Content.ReadAs(ResponseText);
                    if ResponseText <> '' then begin
                        CallSuccessful := true;
                        exit(true); // Success - exit immediately
                    end else begin
                        LastError := StrSubstNo('Empty response received from Azure Function (Attempt %1/%2)', AttemptCount, MaxAttempts);
                    end;
                end else begin
                    Response.Content.ReadAs(ResponseText);
                    LastError := StrSubstNo('HTTP %1: %2 (Attempt %3/%4)', Response.HttpStatusCode, Response.ReasonPhrase, AttemptCount, MaxAttempts);
                end;
            end else begin
                LastError := StrSubstNo('Failed to send HTTP request to Azure Function (Attempt %1/%2)', AttemptCount, MaxAttempts);
            end;

            // Add delay between retries (except for last attempt)
            if (AttemptCount < MaxAttempts) and (not CallSuccessful) then
                Sleep(2000); // Wait 2 seconds before retry
        end;

        // If we get here, all attempts failed
        Error('Failed to communicate with Azure Function after %1 attempts.\n\nLast error: %2\n\nPlease check:\n• Network connectivity\n• Azure Function availability\n• Azure Function URL configuration', MaxAttempts, LastError);
    end;

    // ======================================================================================================
    // LHDN MyInvois API INTEGRATION PROCEDURES
    // ======================================================================================================

    /// <summary>
    /// Submits digitally signed invoice to LHDN MyInvois API for official processing
    /// Handles proper payload structure validation and comprehensive error reporting
    /// </summary>
    /// <param name="LhdnPayload">Signed JSON payload from Azure Function</param>
    /// <param name="SalesInvoiceHeader">Invoice record for context and updates</param>
    /// <param name="LhdnResponse">Response from LHDN API</param>
    /// <returns>True if submission successful, False otherwise</returns>
    procedure SubmitToLhdnApi(LhdnPayload: JsonObject; SalesInvoiceHeader: Record "Sales Invoice Header"; var LhdnResponse: Text): Boolean
    var
        HttpClient: HttpClient;
        HttpRequestMessage: HttpRequestMessage;
        HttpResponseMessage: HttpResponseMessage;
        ContentHeaders: HttpHeaders;
        RequestHeaders: HttpHeaders;
        LhdnPayloadText: Text;
        AccessToken: Text;
        eInvoiceSetup: Record "eInvoiceSetup";
        LhdnApiUrl: Text;
        TempBlob: Codeunit "Temp Blob";
        OutStream: OutStream;
        InStream: InStream;
        FileName: Text;
        ActualLhdnPayload: JsonObject;
        JsonToken: JsonToken;
    begin
        // Get setup for environment determination
        if not eInvoiceSetup.Get('SETUP') then
            Error('eInvoice Setup not found');

        // CRITICAL FIX: The LhdnPayload from Azure Function contains the full structure,
        // but LHDN API only wants the inner content. Extract the correct structure.
        if LhdnPayload.Get('documents', JsonToken) then begin
            // LhdnPayload already contains "documents" array - this is the correct format
            LhdnPayload.WriteTo(LhdnPayloadText);
        end else begin
            // If no "documents" key found, assume LhdnPayload IS the documents array structure
            // and we need to verify it has the right format
            if not LhdnPayload.Contains('documents') then
                Error('Invalid LHDN payload structure. Expected "documents" array not found.');
            LhdnPayload.WriteTo(LhdnPayloadText);
        end;

        // Validate the payload structure matches LHDN requirements
        if not ValidateLhdnPayloadStructure(LhdnPayloadText) then
            Error('LHDN payload does not match required structure for document submissions');

        // DEBUG: Save the LHDN payload to see what we're submitting
        FileName := StrSubstNo('DEBUG_LHDN_Payload_%1.json', Format(CurrentDateTime, 0, '<Year4><Month,2><Day,2>_<Hours24,2><Minutes,2><Seconds,2>'));
        TempBlob.CreateOutStream(OutStream);
        OutStream.WriteText(LhdnPayloadText);
        TempBlob.CreateInStream(InStream);
        DownloadFromStream(InStream, 'Debug LHDN Payload', '', 'JSON files (*.json)|*.json', FileName);

        // Get LHDN access token
        if not GetLhdnAccessToken(AccessToken) then
            Error('Failed to obtain LHDN access token');

        // Determine LHDN API URL based on environment
        if eInvoiceSetup.Environment = eInvoiceSetup.Environment::Preprod then
            LhdnApiUrl := 'https://preprod-api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions'
        else
            LhdnApiUrl := 'https://api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions';

        // Show debug info with payload structure validation
        Message('Submitting to LHDN URL: %1\nPayload size: %2 characters\nPayload structure validated: %3\nFirst 1000 chars: %4',
            LhdnApiUrl, StrLen(LhdnPayloadText), ValidateLhdnPayloadStructure(LhdnPayloadText), CopyStr(LhdnPayloadText, 1, 1000));

        // Setup LHDN API request with standard headers
        HttpRequestMessage.Method := 'POST';
        HttpRequestMessage.SetRequestUri(LhdnApiUrl);
        HttpRequestMessage.Content.WriteFrom(LhdnPayloadText);

        // Set standard LHDN API headers as per documentation
        HttpRequestMessage.Content.GetHeaders(ContentHeaders);
        ContentHeaders.Clear();
        ContentHeaders.Add('Content-Type', 'application/json');

        HttpRequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Clear();
        RequestHeaders.Add('Accept', 'application/json');
        RequestHeaders.Add('Accept-Language', 'en');
        RequestHeaders.Add('Authorization', 'Bearer ' + AccessToken);

        // Submit to LHDN
        if HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then begin
            HttpResponseMessage.Content.ReadAs(LhdnResponse);

            if HttpResponseMessage.IsSuccessStatusCode then begin
                // Parse and display structured LHDN response with headers
                ParseAndDisplayLhdnResponse(LhdnResponse, HttpResponseMessage.HttpStatusCode, SalesInvoiceHeader, HttpResponseMessage);
                exit(true);
            end else begin
                // Parse and display structured LHDN error response with headers
                ParseAndDisplayLhdnError(LhdnResponse, HttpResponseMessage.HttpStatusCode, HttpResponseMessage.ReasonPhrase, HttpResponseMessage);
            end;
        end else begin
            Error('Failed to send HTTP request to LHDN API at %1', LhdnApiUrl);
        end;

        exit(false);
    end;

    local procedure ParseAndDisplayLhdnResponse(LhdnResponse: Text; StatusCode: Integer; var SalesInvoiceHeader: Record "Sales Invoice Header"; HttpResponseMessage: HttpResponseMessage)
    var
        ResponseJson: JsonObject;
        JsonToken: JsonToken;
        AcceptedArray: JsonArray;
        RejectedArray: JsonArray;
        SubmissionUid: Text;
        AcceptedCount: Integer;
        RejectedCount: Integer;
        DocumentInfo: Text;
        i: Integer;
        DocumentJson: JsonObject;
        Uuid: Text;
        InvoiceCodeNumber: Text;
        CorrelationId: Text;
        RateLimitInfo: Text;
        ResponseHeaders: HttpHeaders;
        HeaderValues: List of [Text];
    begin
        // Extract LHDN response headers - using Content headers as proxy for response headers
        HttpResponseMessage.Content.GetHeaders(ResponseHeaders);

        // Note: In AL, direct access to response headers may be limited
        // The correlation ID and rate limit headers would typically be in the response
        // but we'll focus on the content parsing for now

        CorrelationId := 'N/A'; // Will be populated from JSON response if available
        RateLimitInfo := 'See LHDN response for rate limiting info';
        // Try to parse the JSON response
        if not ResponseJson.ReadFrom(LhdnResponse) then begin
            Message('LHDN Submission successful!\nStatus: %1\nRaw Response: %2', StatusCode, LhdnResponse);
            exit;
        end;

        // Extract submission UID
        if ResponseJson.Get('submissionUid', JsonToken) then
            SubmissionUid := JsonToken.AsValue().AsText()
        else
            SubmissionUid := 'N/A';

        // Process accepted documents
        AcceptedCount := 0;
        DocumentInfo := '';
        if ResponseJson.Get('acceptedDocuments', JsonToken) then begin
            AcceptedArray := JsonToken.AsArray();
            AcceptedCount := AcceptedArray.Count;

            for i := 0 to AcceptedArray.Count - 1 do begin
                AcceptedArray.Get(i, JsonToken);
                DocumentJson := JsonToken.AsObject();

                // Extract UUID
                if DocumentJson.Get('uuid', JsonToken) then
                    Uuid := JsonToken.AsValue().AsText()
                else
                    Uuid := 'N/A';

                // Extract Invoice Code Number
                if DocumentJson.Get('invoiceCodeNumber', JsonToken) then
                    InvoiceCodeNumber := JsonToken.AsValue().AsText()
                else
                    InvoiceCodeNumber := 'N/A';

                if DocumentInfo <> '' then
                    DocumentInfo += '\n';
                DocumentInfo += StrSubstNo('  • Invoice: %1 (UUID: %2)', InvoiceCodeNumber, Uuid);
            end;
        end;

        // Process rejected documents
        RejectedCount := 0;
        if ResponseJson.Get('rejectedDocuments', JsonToken) then begin
            RejectedArray := JsonToken.AsArray();
            RejectedCount := RejectedArray.Count;

            // If there are rejected documents, add their details to DocumentInfo
            if RejectedCount > 0 then begin
                if DocumentInfo <> '' then
                    DocumentInfo += '\n\nRejected Documents:\n';

                for i := 0 to RejectedArray.Count - 1 do begin
                    RejectedArray.Get(i, JsonToken);
                    DocumentJson := JsonToken.AsObject();

                    // Extract rejection details (structure may vary)
                    Uuid := 'N/A';
                    InvoiceCodeNumber := 'N/A';
                    if DocumentJson.Get('uuid', JsonToken) then
                        Uuid := JsonToken.AsValue().AsText();
                    if DocumentJson.Get('invoiceCodeNumber', JsonToken) then
                        InvoiceCodeNumber := JsonToken.AsValue().AsText();

                    DocumentInfo += StrSubstNo('  • Invoice: %1 (UUID: %2)', InvoiceCodeNumber, Uuid);

                    // Add error details if available
                    if DocumentJson.Get('error', JsonToken) then
                        DocumentInfo += ' - Error: ' + JsonToken.AsValue().AsText();
                    if DocumentJson.Get('errorCode', JsonToken) then
                        DocumentInfo += ' (Code: ' + JsonToken.AsValue().AsText() + ')';

                    if i < RejectedArray.Count - 1 then
                        DocumentInfo += '\n';
                end;
            end;
        end;

        // Display comprehensive success message
        if (AcceptedCount > 0) and (RejectedCount = 0) then begin
            // All documents accepted
            Message('LHDN Submission Successful!\n\n' +
                'Submission ID: %1\n' +
                'Status Code: %2\n' +
                '%3\n' +
                '%4\n\n' +
                'Accepted Documents: %5\n%6\n\n' +
                'All documents have been successfully submitted to LHDN MyInvois.',
                SubmissionUid, StatusCode,
                CorrelationId <> 'N/A' ? StrSubstNo('Correlation ID: %1', CorrelationId) : '',
                RateLimitInfo <> '' ? StrSubstNo('Rate Limits: %1', RateLimitInfo) : '',
                AcceptedCount, DocumentInfo);
        end else if (AcceptedCount > 0) and (RejectedCount > 0) then begin
            // Mixed results - some accepted, some rejected
            Message('LHDN Submission Partially Successful\n\n' +
                'Submission ID: %1\n' +
                'Status Code: %2\n' +
                '%3\n' +
                '%4\n\n' +
                'Accepted Documents: %5\n' +
                'Rejected Documents: %6\n\n' +
                'Details:\n%7\n\n' +
                'Please review and resubmit the rejected documents.',
                SubmissionUid, StatusCode,
                CorrelationId <> 'N/A' ? StrSubstNo('Correlation ID: %1', CorrelationId) : '',
                RateLimitInfo <> '' ? StrSubstNo('Rate Limits: %1', RateLimitInfo) : '',
                AcceptedCount, RejectedCount, DocumentInfo);
        end else begin
            // All documents rejected or no documents processed
            Message('LHDN Submission Failed\n\n' +
                'Submission ID: %1\n' +
                'Status Code: %2\n' +
                '%3\n' +
                '%4\n\n' +
                'Accepted Documents: %5\n' +
                'Rejected Documents: %6\n\n' +
                'Details:\n%7\n\n' +
                'Please review the errors and resubmit.\n\n' +
                'Full Response: %8',
                SubmissionUid, StatusCode,
                CorrelationId <> 'N/A' ? StrSubstNo('Correlation ID: %1', CorrelationId) : '',
                RateLimitInfo <> '' ? StrSubstNo('Rate Limits: %1', RateLimitInfo) : '',
                AcceptedCount, RejectedCount, DocumentInfo, LhdnResponse);
        end;

        // Update Sales Invoice Header with LHDN response data
        UpdateSalesInvoiceWithLhdnResponse(SalesInvoiceHeader, SubmissionUid, AcceptedArray, AcceptedCount);
    end;

    local procedure UpdateSalesInvoiceWithLhdnResponse(var SalesInvoiceHeader: Record "Sales Invoice Header"; SubmissionUid: Text; AcceptedArray: JsonArray; AcceptedCount: Integer)
    var
        JsonToken: JsonToken;
        DocumentJson: JsonObject;
        Uuid: Text;
        InvoiceCodeNumber: Text;
    begin
        // Update the submission UID
        if SubmissionUid <> '' then begin
            SalesInvoiceHeader."eInvoice Submission UID" := CopyStr(SubmissionUid, 1, MaxStrLen(SalesInvoiceHeader."eInvoice Submission UID"));
        end;

        // Update UUID from the first accepted document (if any)
        if AcceptedCount > 0 then begin
            AcceptedArray.Get(0, JsonToken);
            DocumentJson := JsonToken.AsObject();

            if DocumentJson.Get('uuid', JsonToken) then begin
                Uuid := JsonToken.AsValue().AsText();
                SalesInvoiceHeader."eInvoice UUID" := CopyStr(Uuid, 1, MaxStrLen(SalesInvoiceHeader."eInvoice UUID"));
            end;

            // Optional: Update invoice code number if different from the original
            if DocumentJson.Get('invoiceCodeNumber', JsonToken) then begin
                InvoiceCodeNumber := JsonToken.AsValue().AsText();
                // You can add a field for this if needed, or validate it matches the original
            end;
        end;

        // Save the changes
        if SalesInvoiceHeader.Modify() then begin
            // Successfully updated
        end else begin
            Message('Warning: Could not save LHDN response data to invoice record.');
        end;
    end;

    local procedure ParseAndDisplayLhdnError(ErrorResponse: Text; StatusCode: Integer; ReasonPhrase: Text; HttpResponseMessage: HttpResponseMessage)
    var
        ErrorJson: JsonObject;
        JsonToken: JsonToken;
        ErrorObject: JsonObject;
        InnerErrorArray: JsonArray;
        ErrorMessage: Text;
        ErrorDetails: Text;
        PropertyName: Text;
        PropertyPath: Text;
        ErrorCode: Text;
        ErrorMS: Text;
        Target: Text;
        CorrelationId: Text;
        RateLimitInfo: Text;
        i: Integer;
        InnerErrorObject: JsonObject;
    begin
        ErrorDetails := '';

        // Extract correlation ID from response (if available in content headers or JSON)
        CorrelationId := 'N/A';
        RateLimitInfo := 'Check LHDN response for rate limiting details';

        // Try to parse the JSON error response
        if ErrorJson.ReadFrom(ErrorResponse) then begin
            // Extract main error object
            if ErrorJson.Get('error', JsonToken) and JsonToken.IsObject() then begin
                ErrorObject := JsonToken.AsObject();

                // Extract error details
                if ErrorObject.Get('error', JsonToken) then
                    ErrorMessage := JsonToken.AsValue().AsText();
                if ErrorObject.Get('errorMS', JsonToken) then
                    ErrorMS := JsonToken.AsValue().AsText();
                if ErrorObject.Get('errorCode', JsonToken) then
                    ErrorCode := JsonToken.AsValue().AsText();
                if ErrorObject.Get('propertyName', JsonToken) then
                    PropertyName := JsonToken.AsValue().AsText();
                if ErrorObject.Get('propertyPath', JsonToken) then
                    PropertyPath := JsonToken.AsValue().AsText();
                if ErrorObject.Get('target', JsonToken) then
                    Target := JsonToken.AsValue().AsText();

                // Build error details
                ErrorDetails := 'Error Details:\n';
                if ErrorCode <> '' then
                    ErrorDetails += StrSubstNo('• Error Code: %1\n', ErrorCode);
                if ErrorMessage <> '' then
                    ErrorDetails += StrSubstNo('• Error (EN): %1\n', ErrorMessage);
                if ErrorMS <> '' then
                    ErrorDetails += StrSubstNo('• Error (MS): %1\n', ErrorMS);
                if PropertyName <> '' then
                    ErrorDetails += StrSubstNo('• Property: %1\n', PropertyName);
                if PropertyPath <> '' then
                    ErrorDetails += StrSubstNo('• Path: %1\n', PropertyPath);
                if Target <> '' then
                    ErrorDetails += StrSubstNo('• Target: %1\n', Target);

                // Process inner errors if present
                if ErrorObject.Get('innerError', JsonToken) and JsonToken.IsArray() then begin
                    InnerErrorArray := JsonToken.AsArray();
                    if InnerErrorArray.Count > 0 then begin
                        ErrorDetails += '\n🔍 Additional Errors:\n';
                        for i := 0 to InnerErrorArray.Count - 1 do begin
                            InnerErrorArray.Get(i, JsonToken);
                            if JsonToken.IsObject() then begin
                                InnerErrorObject := JsonToken.AsObject();
                                ErrorDetails += StrSubstNo('  %1. ', i + 1);

                                if InnerErrorObject.Get('errorCode', JsonToken) then
                                    ErrorDetails += StrSubstNo('[%1] ', JsonToken.AsValue().AsText());
                                if InnerErrorObject.Get('error', JsonToken) then
                                    ErrorDetails += JsonToken.AsValue().AsText();
                                if InnerErrorObject.Get('propertyPath', JsonToken) then
                                    ErrorDetails += StrSubstNo(' (Path: %1)', JsonToken.AsValue().AsText());

                                if i < InnerErrorArray.Count - 1 then
                                    ErrorDetails += '\n';
                            end;
                        end;
                    end;
                end;
            end;

            // Extract correlation ID if available
            if ErrorJson.Get('correlationId', JsonToken) then
                CorrelationId := JsonToken.AsValue().AsText();

        end else begin
            // Fallback if JSON parsing fails
            ErrorDetails := StrSubstNo('Raw error response:\n%1', ErrorResponse);
        end;

        // Log error for troubleshooting
        LogLhdnError(ErrorCode, ErrorMessage, PropertyPath, ErrorResponse, StatusCode);

        // Display comprehensive error message
        Error('LHDN API Submission Failed\n\n' +
            'HTTP Status: %1 (%2)\n\n' +
            '%3\n\n' +
            'Resolution Steps:\n' +
            '%4\n\n' +
            '%5\n' +
            '%6\n\n' +
            'Full Response:\n%7',
            StatusCode, ReasonPhrase, ErrorDetails,
            GetResolutionSteps(ErrorCode),
            CorrelationId <> 'N/A' ? StrSubstNo('Correlation ID: %1', CorrelationId) : '',
            RateLimitInfo <> '' ? StrSubstNo('Rate Limits: %1', RateLimitInfo) : '',
            ErrorResponse);
    end;

    local procedure LogLhdnError(ErrorCode: Text; ErrorMessage: Text; PropertyPath: Text; FullResponse: Text; StatusCode: Integer)
    var
        TempBlob: Codeunit "Temp Blob";
        OutStream: OutStream;
        InStream: InStream;
        FileName: Text;
        LogContent: Text;
    begin
        // Create detailed error log for troubleshooting
        LogContent := StrSubstNo('LHDN API Error Log\n' +
            'Timestamp: %1\n' +
            'User: %2\n' +
            'Company: %3\n' +
            'Status Code: %4\n' +
            'Error Code: %5\n' +
            'Error Message: %6\n' +
            'Property Path: %7\n' +
            'Session ID: %8\n\n' +
            'Full Response:\n%9',
            Format(CurrentDateTime, 0, '<Year4>-<Month,2>-<Day,2> <Hours24,2>:<Minutes,2>:<Seconds,2>'),
            UserId, CompanyName, StatusCode, ErrorCode, ErrorMessage, PropertyPath,
            Format(SessionId), FullResponse);

        // Save error log as downloadable file
        FileName := StrSubstNo('LHDN_Error_%1_%2.log',
            Format(CurrentDateTime, 0, '<Year4><Month,2><Day,2>_<Hours24,2><Minutes,2><Seconds,2>'),
            ErrorCode);

        TempBlob.CreateOutStream(OutStream);
        OutStream.WriteText(LogContent);
        TempBlob.CreateInStream(InStream);
        DownloadFromStream(InStream, 'LHDN Error Log', '', 'Log files (*.log)|*.log', FileName);
    end;

    local procedure GetResolutionSteps(ErrorCode: Text): Text
    begin
        // Return specific resolution steps based on common LHDN error codes and FAQ guidance
        case UpperCase(ErrorCode) of
            'ERROR03':
                exit('1. Check for duplicate submissions within 2-hour window\n' +
                     '2. Verify document UUID is unique\n' +
                     '3. Wait a few minutes before resubmitting\n' +
                     '4. Check: Invoice Type, Issue Date/Time, Internal ID, Supplier TIN, Buyer TIN');
            'DS302':
                exit('1. Document already submitted with this UUID\n' +
                     '2. Use a different invoice number or UUID\n' +
                     '3. Check if document was previously accepted\n' +
                     '4. Review duplicate validation criteria (FAQ: 5 fields checked)');
            'VALIDATION_ERROR', 'INVALID_FORMAT', 'INVALID_STRUCTURE':
                exit('1. Review invoice data format against UBL 2.1 structure\n' +
                     '2. Check required fields are populated correctly\n' +
                     '3. Verify data types and formats (numbers, dates, text limits)\n' +
                     '4. Ensure sequence of elements is correct\n' +
                     '5. Check sample formats: sdk.myinvois.hasil.gov.my/sample/');
            'UNAUTHORIZED', 'AUTH_FAILED', '401':
                exit('1. Generate new access token (expires after 60 minutes)\n' +
                     '2. Check LHDN credentials in setup\n' +
                     '3. Verify environment (Preprod vs Production credentials)\n' +
                     '4. Ensure Client ID/Secret are environment-specific\n' +
                     '5. Contact LHDN for API access issues');
            '403', 'FORBIDDEN':
                exit('1. Verify correct Client ID and Client Secret for environment\n' +
                     '2. Production credentials cannot be used in Sandbox\n' +
                     '3. Register ERP system in correct environment portal\n' +
                     '4. Check TIN matching requirements');
            '400', 'BAD_REQUEST':
                exit('1. Check TIN number format is correct\n' +
                     '2. Verify input parameters match argument structure\n' +
                     '3. Review date formats (UTC standard required)\n' +
                     '4. Check for special character escaping in JSON');
            '429', 'TOO_MANY_REQUESTS':
                exit('1. Wait before retrying (check X-Rate-Limit headers)\n' +
                     '2. Implement rate limiting in your application\n' +
                     '3. Submit documents in batches to avoid limits\n' +
                     '4. Token endpoint: max 12 requests per minute');
            'SCHEMA_VALIDATION':
                exit('1. Check UBL 2.1 JSON structure compliance\n' +
                     '2. Verify all mandatory fields are present\n' +
                     '3. Check field data types and formats\n' +
                     '4. Review property paths in error details\n' +
                     '5. Validate against document type schema');
            'TIN_MISMATCH', 'TIN_NOT_MATCHING':
                exit('1. Taxpayer: Issuer TIN must match Client ID TIN\n' +
                     '2. Intermediary: Issuer TIN must match represented taxpayer\n' +
                     '3. Sole proprietors: Ensure "Business Owner" role in MyTax\n' +
                     '4. Individual TIN: Use "IG" prefix (not "OG" or "SG")\n' +
                     '5. Non-Individual TIN: Remove leading zeros, ensure ends with "0"');
            'DATE_TOO_OLD':
                exit('1. Issue date must be within 72 hours before submission\n' +
                     '2. Check "propertyPath" for specific date field\n' +
                     '3. Adjust document issuance date/time\n' +
                     '4. Ensure date is not in the future');
            'FUTURE_DATE':
                exit('1. Ensure issuance date/time is not in the future\n' +
                     '2. Use UTC format for all date/time values\n' +
                     '3. Check timezone conversion is correct\n' +
                     '4. Format: YYYY-MM-DDTHH:MM:SSZ');
            'FILE_SIZE_EXCEEDED':
                exit('1. Document size must not exceed 300KB\n' +
                     '2. Use minification to remove whitespace/comments\n' +
                     '3. Optimize JSON structure\n' +
                     '4. Consider reducing line item details if necessary');
            else
                exit('1. Review the error details above\n' +
                     '2. Check LHDN FAQ: sdk.myinvois.hasil.gov.my/faq/\n' +
                     '3. Validate against sample formats and documentation\n' +
                     '4. Test in Sandbox environment first\n' +
                     '5. Contact LHDN support with correlation ID if error persists');
        end;
    end;

    local procedure GetLhdnAccessToken(var AccessToken: Text): Boolean
    var
        HttpClient: HttpClient;
        HttpRequestMessage: HttpRequestMessage;
        HttpResponseMessage: HttpResponseMessage;
        ContentHeaders: HttpHeaders;
        RequestHeaders: HttpHeaders;
        TokenRequestBody: Text;
        TokenResponse: Text;
        JsonResponse: JsonObject;
        JsonToken: JsonToken;
        eInvoiceSetup: Record "eInvoiceSetup";
        TokenUrl: Text;
    begin
        // Get setup
        if not eInvoiceSetup.Get('SETUP') then
            Error('eInvoice Setup not found');

        if (eInvoiceSetup."Client ID" = '') or (eInvoiceSetup."Client Secret" = '') then
            Error('LHDN Client ID and Client Secret must be configured in eInvoice Setup');

        // Prepare OAuth2 token request
        TokenRequestBody := StrSubstNo('grant_type=client_credentials&client_id=%1&client_secret=%2&scope=InvoicingAPI',
            eInvoiceSetup."Client ID", eInvoiceSetup."Client Secret");

        // Determine token URL based on environment
        if eInvoiceSetup.Environment = eInvoiceSetup.Environment::Preprod then
            TokenUrl := 'https://preprod-api.myinvois.hasil.gov.my/connect/token'
        else
            TokenUrl := 'https://api.myinvois.hasil.gov.my/connect/token';

        // Setup OAuth2 token request with standard headers
        HttpRequestMessage.Method := 'POST';
        HttpRequestMessage.SetRequestUri(TokenUrl);
        HttpRequestMessage.Content.WriteFrom(TokenRequestBody);

        // Set standard LHDN API headers as per documentation
        HttpRequestMessage.Content.GetHeaders(ContentHeaders);
        ContentHeaders.Clear();
        ContentHeaders.Add('Content-Type', 'application/x-www-form-urlencoded');

        // Note: Authorization header not required for token endpoint per OAuth2 spec
        // Accept headers added for consistency with LHDN standards
        HttpRequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Clear();
        RequestHeaders.Add('Accept', 'application/json');
        RequestHeaders.Add('Accept-Language', 'en');

        if HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then begin
            if HttpResponseMessage.IsSuccessStatusCode then begin
                HttpResponseMessage.Content.ReadAs(TokenResponse);

                if JsonResponse.ReadFrom(TokenResponse) then begin
                    if JsonResponse.Get('access_token', JsonToken) then begin
                        AccessToken := JsonToken.AsValue().AsText();

                        // Update setup with new token and expiry
                        eInvoiceSetup."Last Token" := AccessToken;
                        eInvoiceSetup."Token Timestamp" := CurrentDateTime;
                        if JsonResponse.Get('expires_in', JsonToken) then
                            eInvoiceSetup."Token Expiry (s)" := JsonToken.AsValue().AsInteger();
                        eInvoiceSetup.Modify();

                        exit(true);
                    end;
                end;
            end else begin
                HttpResponseMessage.Content.ReadAs(TokenResponse);
                ParseAndDisplayLhdnError(TokenResponse, HttpResponseMessage.HttpStatusCode, 'Token Request Failed', HttpResponseMessage);
            end;
        end;

        exit(false);
    end;

    /// <summary>
    /// Retrieves available document types from LHDN MyInvois API
    /// Useful for validation and configuration purposes
    /// </summary>
    /// <param name="DocumentTypesResponse">JSON response containing available document types</param>
    /// <returns>True if successful, False otherwise</returns>
    procedure GetLhdnDocumentTypes(var DocumentTypesResponse: Text): Boolean
    var
        HttpClient: HttpClient;
        HttpRequestMessage: HttpRequestMessage;
        HttpResponseMessage: HttpResponseMessage;
        RequestHeaders: HttpHeaders;
        AccessToken: Text;
        eInvoiceSetup: Record "eInvoiceSetup";
        DocumentTypesUrl: Text;
    begin
        // Get setup for environment determination
        if not eInvoiceSetup.Get('SETUP') then
            Error('eInvoice Setup not found');

        // Get LHDN access token
        if not GetLhdnAccessToken(AccessToken) then
            Error('Failed to obtain LHDN access token for document types request');

        // Determine LHDN Document Types API URL based on environment
        if eInvoiceSetup.Environment = eInvoiceSetup.Environment::Preprod then
            DocumentTypesUrl := 'https://preprod-api.myinvois.hasil.gov.my/api/v1.0/documenttypes'
        else
            DocumentTypesUrl := 'https://api.myinvois.hasil.gov.my/api/v1.0/documenttypes';

        // Setup LHDN API request with standard headers
        HttpRequestMessage.Method := 'GET';
        HttpRequestMessage.SetRequestUri(DocumentTypesUrl);

        // Set standard LHDN API headers as per documentation
        HttpRequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Clear();
        RequestHeaders.Add('Accept', 'application/json');
        RequestHeaders.Add('Accept-Language', 'en');
        RequestHeaders.Add('Authorization', 'Bearer ' + AccessToken);

        // Submit to LHDN
        if HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then begin
            HttpResponseMessage.Content.ReadAs(DocumentTypesResponse);

            if HttpResponseMessage.IsSuccessStatusCode then begin
                // Successfully retrieved document types
                Message('LHDN Document Types Retrieved Successfully!\n\n' +
                    'Status Code: %1\n' +
                    'Document Types Data:\n%2',
                    HttpResponseMessage.HttpStatusCode, DocumentTypesResponse);
                exit(true);
            end else begin
                // Parse and display structured LHDN error response
                ParseAndDisplayLhdnError(DocumentTypesResponse, HttpResponseMessage.HttpStatusCode, HttpResponseMessage.ReasonPhrase, HttpResponseMessage);
            end;
        end else begin
            Error('Failed to send HTTP request to LHDN Document Types API at %1', DocumentTypesUrl);
        end;

        exit(false);
    end;

    /// <summary>
    /// Retrieves LHDN notifications for the taxpayer within specified date range
    /// Supports filtering by notification type and pagination
    /// </summary>
    /// <param name="NotificationsResponse">JSON response containing notifications</param>
    /// <param name="DateFrom">Start date for notification search</param>
    /// <param name="DateTo">End date for notification search</param>
    /// <param name="NotificationType">Filter by notification type (0 for all)</param>
    /// <param name="PageNo">Page number for pagination (0 for default)</param>
    /// <param name="PageSize">Number of items per page (0 for default)</param>
    /// <returns>True if successful, False otherwise</returns>
    procedure GetLhdnNotifications(var NotificationsResponse: Text; DateFrom: Date; DateTo: Date; NotificationType: Integer; PageNo: Integer; PageSize: Integer): Boolean
    var
        HttpClient: HttpClient;
        HttpRequestMessage: HttpRequestMessage;
        HttpResponseMessage: HttpResponseMessage;
        RequestHeaders: HttpHeaders;
        AccessToken: Text;
        eInvoiceSetup: Record "eInvoiceSetup";
        NotificationsUrl: Text;
        QueryParams: Text;
    begin
        // Get setup for environment determination
        if not eInvoiceSetup.Get('SETUP') then
            Error('eInvoice Setup not found');

        // Get LHDN access token
        if not GetLhdnAccessToken(AccessToken) then
            Error('Failed to obtain LHDN access token for notifications request');

        // Determine LHDN Notifications API URL based on environment
        if eInvoiceSetup.Environment = eInvoiceSetup.Environment::Preprod then
            NotificationsUrl := 'https://preprod-api.myinvois.hasil.gov.my/api/v1.0/notifications/taxpayer'
        else
            NotificationsUrl := 'https://api.myinvois.hasil.gov.my/api/v1.0/notifications/taxpayer';

        // Build query parameters
        QueryParams := '';
        if DateFrom <> 0D then
            QueryParams += StrSubstNo('dateFrom=%1', Format(DateFrom, 0, '<Year4>-<Month,2>-<Day,2>') + 'T00:00:00Z');

        if DateTo <> 0D then begin
            if QueryParams <> '' then QueryParams += '&';
            QueryParams += StrSubstNo('dateTo=%1', Format(DateTo, 0, '<Year4>-<Month,2>-<Day,2>') + 'T23:59:59Z');
        end;

        if NotificationType > 0 then begin
            if QueryParams <> '' then QueryParams += '&';
            QueryParams += StrSubstNo('type=%1', NotificationType);
        end;

        if PageNo > 0 then begin
            if QueryParams <> '' then QueryParams += '&';
            QueryParams += StrSubstNo('pageNo=%1', PageNo);
        end;

        if PageSize > 0 then begin
            if QueryParams <> '' then QueryParams += '&';
            QueryParams += StrSubstNo('pageSize=%1', PageSize);
        end;

        // Add language parameter
        if QueryParams <> '' then QueryParams += '&';
        QueryParams += 'language=en';

        // Complete URL with query parameters
        if QueryParams <> '' then
            NotificationsUrl += '?' + QueryParams;

        // Setup LHDN API request with standard headers
        HttpRequestMessage.Method := 'GET';
        HttpRequestMessage.SetRequestUri(NotificationsUrl);

        // Set standard LHDN API headers as per documentation
        HttpRequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Clear();
        RequestHeaders.Add('Accept', 'application/json');
        RequestHeaders.Add('Accept-Language', 'en');
        RequestHeaders.Add('Authorization', 'Bearer ' + AccessToken);

        // Submit to LHDN
        if HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then begin
            HttpResponseMessage.Content.ReadAs(NotificationsResponse);

            if HttpResponseMessage.IsSuccessStatusCode then begin
                // Successfully retrieved notifications
                ParseAndDisplayLhdnNotifications(NotificationsResponse, HttpResponseMessage.HttpStatusCode);
                exit(true);
            end else begin
                // Parse and display structured LHDN error response
                ParseAndDisplayLhdnError(NotificationsResponse, HttpResponseMessage.HttpStatusCode, HttpResponseMessage.ReasonPhrase, HttpResponseMessage);
            end;
        end else begin
            Error('Failed to send HTTP request to LHDN Notifications API at %1', NotificationsUrl);
        end;

        exit(false);
    end;

    local procedure ParseAndDisplayLhdnNotifications(NotificationsResponse: Text; StatusCode: Integer)
    var
        ResponseJson: JsonObject;
        JsonToken: JsonToken;
        ResultArray: JsonArray;
        MetadataObject: JsonObject;
        NotificationObject: JsonObject;
        NotificationsInfo: Text;
        i: Integer;
        NotificationId: Text;
        Subject: Text;
        TypeName: Text;
        ReceivedDateTime: Text;
        Status: Text;
        HasNext: Boolean;
    begin
        // Try to parse the JSON response
        if not ResponseJson.ReadFrom(NotificationsResponse) then begin
            Message('LHDN Notifications retrieved successfully!\nStatus: %1\nRaw Response: %2', StatusCode, NotificationsResponse);
            exit;
        end;

        // Extract notifications array
        NotificationsInfo := '';
        if ResponseJson.Get('result', JsonToken) then begin
            ResultArray := JsonToken.AsArray();

            for i := 0 to ResultArray.Count - 1 do begin
                ResultArray.Get(i, JsonToken);
                NotificationObject := JsonToken.AsObject();

                // Extract notification details
                NotificationId := 'N/A';
                Subject := 'N/A';
                TypeName := 'N/A';
                ReceivedDateTime := 'N/A';
                Status := 'N/A';

                if NotificationObject.Get('notificationId', JsonToken) then
                    NotificationId := JsonToken.AsValue().AsText();
                if NotificationObject.Get('notificationSubject', JsonToken) then
                    Subject := JsonToken.AsValue().AsText();
                if NotificationObject.Get('typeName', JsonToken) then
                    TypeName := JsonToken.AsValue().AsText();
                if NotificationObject.Get('receivedDateTime', JsonToken) then
                    ReceivedDateTime := JsonToken.AsValue().AsText();
                if NotificationObject.Get('status', JsonToken) then
                    Status := JsonToken.AsValue().AsText();

                if NotificationsInfo <> '' then
                    NotificationsInfo += '\n';
                NotificationsInfo += StrSubstNo('  %1. [%2] %3\n      Type: %4 | Status: %5 | Received: %6',
                    i + 1, NotificationId, Subject, TypeName, Status, ReceivedDateTime);
            end;

            // Check for pagination
            HasNext := false;
            if ResponseJson.Get('metadata', JsonToken) then begin
                MetadataObject := JsonToken.AsObject();
                if MetadataObject.Get('hasNext', JsonToken) then
                    HasNext := JsonToken.AsValue().AsBoolean();
            end;

            // Display notifications
            Message('LHDN Notifications Retrieved Successfully!\n\n' +
                'Status Code: %1\n' +
                'Total Notifications: %2\n' +
                '%3\n\n' +
                'Notifications:\n%4\n\n' +
                '%5',
                StatusCode, ResultArray.Count,
                HasNext ? 'More pages available' : 'All notifications retrieved',
                NotificationsInfo,
                'Full Response available for integration purposes');
        end else begin
            Message('LHDN Notifications Retrieved!\n\nStatus: %1\nNo notifications found or unexpected response format.\n\nRaw Response: %2',
                StatusCode, NotificationsResponse);
        end;
    end;

    // ======================================================================================================
    // LHDN PAYLOAD VALIDATION PROCEDURES
    // ======================================================================================================

    /// <summary>
    /// Validates that the LHDN payload structure matches required format for document submission
    /// Ensures proper "documents" array structure with required fields
    /// </summary>
    /// <param name="PayloadText">JSON payload to validate</param>
    /// <returns>True if structure is valid for LHDN submission</returns>
    local procedure ValidateLhdnPayloadStructure(PayloadText: Text): Boolean
    var
        PayloadObject: JsonObject;
        JsonToken: JsonToken;
        DocumentsArray: JsonArray;
        DocumentObject: JsonObject;
        i: Integer;
    begin
        // Parse the payload
        if not PayloadObject.ReadFrom(PayloadText) then
            exit(false);

        // Check for "documents" array
        if not PayloadObject.Get('documents', JsonToken) then
            exit(false);

        if not JsonToken.IsArray() then
            exit(false);

        DocumentsArray := JsonToken.AsArray();
        if DocumentsArray.Count() = 0 then
            exit(false);

        // Validate each document in the array
        for i := 0 to DocumentsArray.Count() - 1 do begin
            DocumentsArray.Get(i, JsonToken);
            if not JsonToken.IsObject() then
                exit(false);

            DocumentObject := JsonToken.AsObject();

            // Check required fields
            if not DocumentObject.Contains('format') then
                exit(false);
            if not DocumentObject.Contains('document') then
                exit(false);
            if not DocumentObject.Contains('documentHash') then
                exit(false);
            if not DocumentObject.Contains('codeNumber') then
                exit(false);
        end;

        exit(true);
    end;

    // ======================================================================================================
    // UTILITY AND HELPER PROCEDURES
    // ======================================================================================================

    /// <summary>
    /// Creates a new GUID for correlation tracking
    /// </summary>
    /// <returns>Formatted GUID string</returns>
    local procedure CreateGuid(): Text
    var
        GuidVar: Guid;
    begin
        GuidVar := CreateGuid();
        exit(Format(GuidVar, 0, 4));
    end;

    /// <summary>
    /// Validates JSON text format without parsing the full structure
    /// </summary>
    /// <param name="JsonText">JSON text to validate</param>
    /// <returns>True if valid JSON format</returns>
    local procedure TestJsonValidity(JsonText: Text): Boolean
    var
        JsonObject: JsonObject;
    begin
        exit(JsonObject.ReadFrom(JsonText));
    end;

    /// <summary>
    /// Stores signed invoice JSON for audit trail and compliance requirements
    /// Can be extended to save to custom tables for permanent record keeping
    /// </summary>
    /// <param name="SalesInvoiceHeader">Invoice record for reference</param>
    /// <param name="SignedJsonText">Digitally signed JSON from Azure Function</param>
    local procedure StoreSignedInvoiceJson(SalesInvoiceHeader: Record "Sales Invoice Header"; SignedJsonText: Text)
    var
        TempBlob: Codeunit "Temp Blob";
        OutStream: OutStream;
        InStream: InStream;
        FileName: Text;
    begin
        // Store signed JSON for audit trail and records
        // You can extend this to store in a custom table if needed

        FileName := StrSubstNo('SignedInvoice_%1_%2.json',
            SalesInvoiceHeader."No.",
            Format(CurrentDateTime, 0, '<Year4><Month,2><Day,2><Hours24,2><Minutes,2><Seconds,2>'));

        TempBlob.CreateOutStream(OutStream);
        OutStream.WriteText(SignedJsonText);
        TempBlob.CreateInStream(InStream);

        // Optional: Download the signed JSON for verification
        // DownloadFromStream(InStream, 'Signed eInvoice JSON', '', 'JSON files (*.json)|*.json', FileName);

        // TODO: Store in a custom table for permanent record keeping
        // Example: 
        // SignedInvoiceLog."Invoice No." := SalesInvoiceHeader."No.";
        // SignedInvoiceLog.SetSignedJSONText(SignedJsonText);
        // SignedInvoiceLog.Insert();
    end;

    /// <summary>
    /// Gets all property keys from a JSON object for debugging purposes
    /// Useful for troubleshooting Azure Function response structure issues
    /// </summary>
    /// <param name="JsonObj">JSON object to analyze</param>
    /// <returns>Comma-separated list of all keys</returns>
    local procedure GetJsonObjectKeys(JsonObj: JsonObject): Text
    var
        KeysList: Text;
        Keys: List of [Text];
        i: Integer;
        CurrentKey: Text;
    begin
        Keys := JsonObj.Keys();
        for i := 1 to Keys.Count() do begin
            CurrentKey := Keys.Get(i);
            if KeysList <> '' then
                KeysList += ', ';
            KeysList += CurrentKey;
        end;
        exit(KeysList);
    end;
}