# MyInvois LHDN e-Invoice System - Complete Documentation

## Table of Contents
1. [Project Overview](#project-overview)
2. [System Architecture](#system-architecture)
3. [Core Components](#core-components)
4. [LHDN Compliance](#lhdn-compliance)
5. [Setup and Configuration](#setup-and-configuration)
6. [Usage Guide](#usage-guide)
7. [Technical Implementation](#technical-implementation)
8. [Troubleshooting](#troubleshooting)
9. [API Reference](#api-reference)
10. [Development Guidelines](#development-guidelines)

## Project Overview

### Purpose
This Business Central extension provides comprehensive e-Invoice functionality for LHDN (Lembaga Hasil Dalam Negeri) MyInvois compliance in Malaysia. The system generates UBL 2.1 compliant JSON invoices, digitally signs them via Azure Functions, and submits them to the LHDN MyInvois API.

### Key Features
- **UBL 2.1 Compliance**: Generates structured JSON invoices following UBL 2.1 standards
- **Digital Signing**: Azure Function integration for JOTEX P12 certificate signing
- **LHDN Integration**: Direct submission to MyInvois API with full error handling
- **Multi-Document Support**: Invoices, Credit Notes, Debit Notes, and Self-billed documents
- **Audit Trail**: Complete logging and status tracking for compliance
- **Batch Processing**: Export multiple invoices for bulk processing
- **TIN Validation**: Real-time taxpayer identification number validation

### Supported Document Types
Based on [LHDN Official Specification](https://sdk.myinvois.hasil.gov.my/codes/e-invoice-types/):

| Code | Description             | Supported |
|------|------------------------|-----------|
| 01   | Invoice                | ✅         |
| 02   | Credit Note            | ✅         |
| 03   | Debit Note             | ✅         |
| 04   | Refund Note            | ✅         |
| 11   | Self-billed Invoice    | ✅         |
| 12   | Self-billed Credit Note| ✅         |
| 13   | Self-billed Debit Note | ✅         |
| 14   | Self-billed Refund Note| ✅         |

## System Architecture

### Integration Flow
```text
Business Central → Azure Function → LHDN MyInvois API
     ↓                ↓                  ↓
1. Generate UBL    2. Digital         3. Official
   JSON Invoice       Signing            Submission
```

### Component Overview
1. **JSON Generation Engine**: Creates UBL 2.1 compliant JSON structures
2. **Azure Function Client**: Handles secure communication with signing service
3. **LHDN API Integration**: Direct submission to MyInvois platform
4. **Status Management**: Tracks document lifecycle and compliance status
5. **Field Population**: Automatic mapping of Business Central data to e-Invoice fields

## Core Components

### Tables

#### Master Data Tables
- **Tab50300.eInvoiceSetup**: System configuration and API settings
- **Tab50302.eInvoiceTypes**: Document type definitions
- **Tab50303.CurrencyCodes**: Supported currency mappings
- **Tab50304.MSICCodes**: Malaysian Standard Industrial Classification codes
- **Tab50305.StateCodes**: Malaysian state code mappings
- **Tab50306.CountryCodes**: ISO country code definitions
- **Tab50307.PaymentModes**: Payment method classifications
- **Tab50308.eInvoiceClassification**: Product/service classifications
- **Tab50309.eInvoiceTaxTypes**: Tax category definitions
- **Tab50310.eInvoiceUOM**: Unit of measure mappings
- **Tab50311.eInvoiceVersion**: UBL version specifications

#### Operational Tables
- **Tab50301.eInvoiceTINLog**: TIN validation history and results
- **Tab50312.eInvoiceSubmissionLog**: Complete audit trail of submissions

#### Table Extensions
- **Tab-Ext50300.eInvoiceCustomerExt**: Customer e-Invoice fields
- **Tab-Ext50301.eInvSalesInvHeaderExt**: Sales Invoice e-Invoice fields
- **Tab-Ext50302.eInvItemExt**: Item e-Invoice classifications
- **Tab-Ext50303.eInvCompanyInfoExt**: Company e-Invoice settings
- **Tab-Ext50304.eInvoiceVendorExt**: Vendor e-Invoice fields
- **Tab-Ext50305.eInvSalesHeader**: Sales Header e-Invoice fields
- **Tab-Ext50306.SalesInvLineExt**: Sales Invoice Line e-Invoice fields
- **Tab-Ext50307.eInvSalesLineExt**: Sales Line e-Invoice fields
- **Tab-Ext50308.eInvSalesCreditMemoLinesExt**: Credit Memo Line fields
- **Tab-Ext50309.eInvSalesCrHeaderExt**: Credit Memo Header fields
- **Tab-Ext50310.eInvSalesReturnHeaderExt**: Return Order Header fields
- **Tab-Ext50311.eInvSalesReturnLineExt**: Return Order Line fields
- **Tab-Ext50312.eInvSalesLineArc**: Sales Line Archive fields
- **Tab-Ext50313.eInvSalesHeaderArch**: Sales Header Archive fields

### Codeunits

#### Core Processing
- **Cod50302.eInvoiceJSONGenerator**: Main JSON generation and LHDN submission engine
- **Cod50311.eInvoiceUBLDocumentBuilder**: UBL document structure builder
- **Cod50310.eInvoiceAzureFunctionClient**: Azure Function integration client

#### Validation and Utilities
- **Cod50300.eInvoiceHelper**: Common helper functions and utilities
- **Cod50301.eInvoiceTINValidator**: TIN validation and verification
- **Cod50307.eInvoiceCountryCodeMgt**: Country code management
- **Cod50308.eInvoiceStateCodeMgt**: State code management
- **Cod50312.eInvoiceSubmissionStatus**: Status tracking and management

#### Event Subscribers
- **Cod50305.eInvSalesInvPostingSub**: Sales Invoice posting automation
- **Cod50306.eInvFieldPopulation**: Automatic field population
- **Cod50309.eInvFieldPopulationHandler**: Field population event handling
- **Cod50313.eInvSalesOrderPostingSub**: Sales Order posting automation

#### Maintenance and Upgrades
- **Cod50320.eInvoiceCancellationHelper**: Document cancellation handling
- **Cod50321.eInvoiceDataUpgrade**: Data migration and upgrades
- **Cod50322.eInvoicePostingDatePopulator**: Posting date management
- **Cod50323.eInvoiceCustomerBulkUpdate**: Bulk customer data updates
- **Cod50324.eInvoiceCustomerNameUpgrade**: Customer name standardization

### Pages

#### Setup and Configuration
- **Pag50300.eInvoiceSetupCard**: Main system configuration
- **Pag50304.eInvoiceTypes**: Document type management
- **Pag50305.eInvoiceCurrencyCodes**: Currency code setup
- **Pag50306.MSICCodeList**: MSIC code management
- **Pag50307.StateCodeList**: State code configuration
- **Pag50308.CountryCodeList**: Country code setup
- **Pag50309.PaymentModeList**: Payment mode configuration
- **Pag50310.einvoiceClassification**: Classification management
- **Pag50311.eInvoiceTaxTypes**: Tax type configuration
- **Pag50312.eInvoiceUOM**: Unit of measure setup
- **Pag50313.eInvoiceVersion**: Version management
- **Pag50317.CustomCancellationReason**: Cancellation reason setup

#### Operational Pages
- **Pag50301.TINValidationLog**: TIN validation history
- **Pag50302.TINLogFactBox**: TIN validation factbox
- **Pag50315.eInvoiceSubmissionLogCard**: Submission details
- **Pag50316.eInvoiceSubmissionLog**: Submission history list

#### Page Extensions
- **Customer and Vendor Extensions**: e-Invoice field additions to customer and vendor cards
- **Sales Document Extensions**: e-Invoice functionality on all sales documents
- **Posted Document Extensions**: e-Invoice actions on posted documents
- **List Page Extensions**: Bulk operations and status indicators

### Reports
- **Rep50300.ExportPostedSalesBatcheInv**: Batch invoice export
- **Rep50301.ExportCreditMemoBatcheInv**: Batch credit memo export

## LHDN Compliance

### UBL 2.1 Standard Implementation
The system generates JSON documents that comply with UBL 2.1 (Universal Business Language) standards as required by LHDN:

#### Document Structure
```json
{
  "_D": "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2",
  "_A": "urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2", 
  "_B": "urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2",
  "Invoice": [
    {
      "ID": "INV001",
      "IssueDate": "2024-01-15",
      "InvoiceTypeCode": "01",
      "DocumentCurrencyCode": "MYR",
      // ... complete UBL structure
    }
  ]
}
```

#### Credit Note Structure
```json
{
  "_D": "urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2",
  "_A": "urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2",
  "_B": "urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2", 
  "CreditNote": [
    {
      "ID": "CN001",
      "IssueDate": "2024-01-15",
      "InvoiceTypeCode": "02",
      "BillingReference": [
        {
          "InvoiceDocumentReference": [
            {
              "ID": "INV001",
              "IssueDate": "2024-01-10"
            }
          ]
        }
      ],
      // ... complete credit note structure
    }
  ]
}
```

### Digital Signature Process
1. **Unsigned JSON Generation**: Business Central creates UBL-compliant JSON
2. **Azure Function Signing**: JOTEX P12 certificate applied via 7-step process
3. **LHDN Submission**: Signed document submitted to MyInvois API
4. **Status Tracking**: Real-time status updates and error handling

### Mandatory Fields Compliance
The system ensures all LHDN-required fields are populated:

#### Supplier Information
- Company TIN number
- Company registration details
- Address with state and country codes
- Business registration number

#### Customer Information  
- Customer TIN validation
- ID type (NRIC, BRN, PASSPORT, ARMY)
- Complete address information
- State and country code compliance

#### Document Details
- Proper document type codes
- Sequential numbering
- Correct date and time formats
- Currency and exchange rate information

#### Line Item Requirements
- Product/service classification codes
- Tax type and rate specifications
- Unit of measure codes
- Complete pricing breakdown

## Setup and Configuration

### Initial Setup Steps

#### 1. eInvoice Setup Configuration
Navigate to **eInvoice Setup Card** and configure:

```al
// Required Settings
- Azure Function URL: Your signing service endpoint
- Environment: PREPROD or PRODUCTION
- LHDN API URLs for both environments
- Access tokens and authentication details
```

#### 2. Company Information
Ensure company information includes:
- **TIN Number**: Malaysian tax identification number
- **Business Registration Number**: SSM registration
- **Complete Address**: Including state and country codes
- **Bank Account Information**: For payment details

#### 3. Customer Setup
For each customer requiring e-Invoice:
- **Enable "Requires e-Invoice"** flag
- **TIN Number**: Customer's tax identification
- **ID Type**: NRIC, BRN, PASSPORT, or ARMY
- **State and Country Codes**: Use Malaysian standards
- **Address Completion**: All mandatory address fields

#### 4. Item Classification
Configure items with:
- **e-Invoice Classification**: Product/service category
- **Tax Type**: Appropriate tax classification  
- **UOM Code**: Unit of measure for LHDN compliance

#### 5. Master Data Setup
Configure supporting tables:
- **State Codes**: Malaysian state mappings
- **Country Codes**: ISO Alpha-3 codes
- **Currency Codes**: Supported currencies
- **Payment Modes**: Payment method classifications
- **MSIC Codes**: Industry classification codes

### Environment Configuration

#### PREPROD Environment
```al
Environment: PREPROD
LHDN API URL: https://preprod-api.myinvois.hasil.gov.my
Azure Function: Your development signing service
```

#### PRODUCTION Environment  
```al
Environment: PRODUCTION
LHDN API URL: https://api.myinvois.hasil.gov.my
Azure Function: Your production signing service
```

## Usage Guide

### Invoice Processing

#### Automatic Processing
1. **Create Sales Invoice** with customer flagged for e-Invoice
2. **Post Invoice** - system automatically:
   - Copies e-Invoice fields to posted document
   - Generates UBL JSON
   - Sends to Azure Function for signing
   - Submits to LHDN API
   - Updates status fields

#### Manual Processing
1. Navigate to **Posted Sales Invoice**
2. Click **"Sign & Submit to LHDN"** action
3. System processes and displays results
4. Check **eInvoice Validation Status** field

### Credit Memo Processing

#### Standard Process
1. **Create Credit Memo** linked to original invoice
2. **Set "Applies-to Doc. No."** for proper billing reference
3. **Post Credit Memo**
4. **Sign & Submit** via posted document actions

#### Key Requirements
- Credit memos should reference original invoices when possible
- Document type automatically set to "02" (Credit Note)
- Enhanced billing reference structure includes original invoice details

### Batch Processing

#### Export Multiple Invoices
1. Run **"LHDN e-Invoice Export"** report
2. Set filters for date range and customers
3. System generates batch export file
4. Process through external systems if needed

#### Bulk Status Updates
Use bulk update codeunits for:
- Customer name standardization
- TIN validation updates
- Field population across multiple records

### Status Monitoring

#### Submission Status Tracking
Monitor document status through:
- **eInvoice Validation Status** field on documents
- **eInvoice Submission Log** for detailed history
- **TIN Validation Log** for customer validation results

#### Error Resolution
Common status values:
- **"Submitted"**: Successfully processed by LHDN
- **"Submission Failed"**: Requires investigation
- **"Pending"**: Awaiting processing
- **"Cancelled"**: Document cancelled in LHDN

## Technical Implementation

### JSON Generation Process

#### Core Generation Flow
```al
procedure GenerateEInvoiceJson(SalesInvoiceHeader: Record "Sales Invoice Header"; IncludeSignature: Boolean) JsonText: Text
var
    JsonObject: JsonObject;
begin
    // 1. Build UBL structure with namespaces
    JsonObject := BuildEInvoiceJson(SalesInvoiceHeader, IncludeSignature);
    
    // 2. Convert to text
    JsonObject.WriteTo(JsonText);
    
    // 3. Validate output
    if JsonText = '' then
        Error('JSON generation failed');
end;
```

#### UBL Structure Building
```al
local procedure BuildEInvoiceJson(SalesInvoiceHeader: Record "Sales Invoice Header"; IncludeSignature: Boolean) JsonObject: JsonObject
begin
    // UBL 2.1 namespace declarations (CRITICAL for LHDN)
    JsonObject.Add('_D', 'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2');
    JsonObject.Add('_A', 'urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2');
    JsonObject.Add('_B', 'urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2');
    
    // Build invoice object and wrap in array
    InvoiceObject := CreateInvoiceObject(SalesInvoiceHeader, IncludeSignature);
    InvoiceArray.Add(InvoiceObject);
    JsonObject.Add('Invoice', InvoiceArray);
end;
```

### Azure Function Integration

#### Request Payload Structure
```al
local procedure BuildAzureFunctionPayload(JsonText: Text; CorrelationId: Text): Text
var
    RequestPayload: JsonObject;
begin
    RequestPayload.Add('correlationId', CorrelationId);
    RequestPayload.Add('environment', Format(Setup.Environment));
    RequestPayload.Add('invoiceType', InvoiceTypeCode);
    RequestPayload.Add('documentType', DocumentTypeCode);
    RequestPayload.Add('unsignedJson', JsonText);
    RequestPayload.Add('timestamp', Format(CurrentDateTime, 0, '<Year4>-<Month,2>-<Day,2>T<Hours24,2>:<Minutes,2>:<Seconds,2>Z'));
    RequestPayload.Add('requestId', CreateGuid());
    
    RequestPayload.WriteTo(RequestText);
    exit(RequestText);
end;
```

#### Response Processing
```al
local procedure ProcessAzureFunctionResponse(ResponseText: Text; var LhdnPayload: Text): Boolean
var
    AzureResponse: JsonObject;
    JsonToken: JsonToken;
begin
    // Parse response
    if not AzureResponse.ReadFrom(ResponseText) then
        exit(false);
        
    // Check success status
    if not AzureResponse.Get('success', JsonToken) or not JsonToken.AsValue().AsBoolean() then
        exit(false);
        
    // Extract LHDN payload
    if AzureResponse.Get('lhdnPayload', JsonToken) then begin
        LhdnPayload := SafeJsonValueToText(JsonToken);
        exit(true);
    end;
    
    exit(false);
end;
```

### LHDN API Integration

#### Submission Process
```al
procedure SubmitToLhdnApi(LhdnPayload: JsonObject; SalesInvoiceHeader: Record "Sales Invoice Header"; var LhdnResponse: Text): Boolean
var
    HttpClient: HttpClient;
    HttpRequestMessage: HttpRequestMessage;
    HttpResponseMessage: HttpResponseMessage;
begin
    // Configure request
    SetupLhdnApiRequest(HttpRequestMessage, LhdnPayload);
    
    // Send to LHDN
    if HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then begin
        HttpResponseMessage.Content.ReadAs(LhdnResponse);
        
        // Process response
        if HttpResponseMessage.IsSuccessStatusCode then begin
            ProcessSuccessfulSubmission(LhdnResponse, SalesInvoiceHeader);
            exit(true);
        end else begin
            ProcessFailedSubmission(LhdnResponse, SalesInvoiceHeader);
            exit(false);
        end;
    end;
    
    exit(false);
end;
```

#### Error Handling
```al
local procedure ParseAndDisplayLhdnError(ErrorResponse: Text; DocumentNo: Code[20])
var
    ErrorObject: JsonObject;
    ErrorArray: JsonArray;
    JsonToken: JsonToken;
begin
    if ErrorObject.ReadFrom(ErrorResponse) then begin
        if ErrorObject.Get('error', JsonToken) then begin
            // Extract error details
            ProcessErrorDetails(JsonToken.AsObject());
            
            // Log for troubleshooting
            LogSubmissionError(DocumentNo, ErrorResponse);
            
            // Display user-friendly message
            DisplayFormattedError(ErrorResponse);
        end;
    end;
end;
```

### Field Population and Validation

#### Automatic Field Population
```al
[EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnAfterValidateEvent', 'Sell-to Customer No.', false, false)]
local procedure PopulateEInvoiceFields(var Rec: Record "Sales Header")
var
    Customer: Record Customer;
begin
    if Customer.Get(Rec."Sell-to Customer No.") and Customer."Requires e-Invoice" then begin
        // Set document type based on document
        case Rec."Document Type" of
            Rec."Document Type"::Invoice,
            Rec."Document Type"::Order:
                Rec."eInvoice Document Type" := '01';
            Rec."Document Type"::"Credit Memo",
            Rec."Document Type"::"Return Order":
                Rec."eInvoice Document Type" := '02';
        end;
        
        // Set currency code
        if Rec."Currency Code" = '' then
            Rec."eInvoice Currency Code" := 'MYR'
        else
            Rec."eInvoice Currency Code" := Rec."Currency Code";
            
        // Set version
        if Rec."eInvoice Version Code" = '' then
            Rec."eInvoice Version Code" := '1.1';
    end;
end;
```

#### TIN Validation Process
```al
procedure ValidateCustomerTIN(CustomerNo: Code[20]): Boolean
var
    Customer: Record Customer;
    TINValidationLog: Record "eInvoice TIN Log";
    HttpClient: HttpClient;
    ValidationResult: Boolean;
begin
    if not Customer.Get(CustomerNo) then
        exit(false);
        
    // Call LHDN TIN validation API
    ValidationResult := CallLhdnTinValidationApi(Customer."e-Invoice TIN No.");
    
    // Log result
    TINValidationLog.Init();
    TINValidationLog."Customer No." := CustomerNo;
    TINValidationLog."TIN No." := Customer."e-Invoice TIN No.";
    TINValidationLog."Validation Date" := Today;
    TINValidationLog."Validation Time" := Time;
    TINValidationLog."Validation Result" := ValidationResult;
    TINValidationLog.Insert();
    
    // Update customer status
    Customer."Validation Status" := Customer."Validation Status"::Validated;
    Customer."Last TIN Validation" := CurrentDateTime;
    Customer.Modify();
    
    exit(ValidationResult);
end;
```

## Troubleshooting

### Common Issues and Solutions

#### 1. "Invalid structured submission" Error
**Cause**: Missing UBL namespace declarations or incorrect JSON structure
**Solution**: 
- Verify UBL namespace declarations are present
- Check document type codes match LHDN specification
- Validate JSON structure against UBL 2.1 standards

#### 2. "Credit memo must have Applies-to Doc. No." Error  
**Cause**: Overly strict validation (now fixed)
**Solution**: 
- Update to latest version where billing reference is optional
- Populate "Applies-to Doc. No." for better traceability when possible

#### 3. Azure Function Communication Failures
**Cause**: Network connectivity or authentication issues
**Solution**:
- Verify Azure Function URL in setup
- Check network connectivity and firewall rules
- Validate authentication tokens and certificates

#### 4. TIN Validation Failures
**Cause**: Invalid TIN numbers or LHDN API issues
**Solution**:
- Verify TIN format (12 digits for companies, varies for individuals)
- Check LHDN TIN validation service availability
- Review TIN Validation Log for detailed error messages

#### 5. Missing Required Fields
**Cause**: Incomplete master data setup
**Solution**:
- Run field validation procedures
- Complete customer and company information
- Configure all required master data tables

### Debug Tools and Procedures

#### Debug Invoice Generation
```al
// Call from developer console or debug page
DebugInvoicePayload('INVOICE_NO');
```

#### Debug Credit Memo Generation  
```al
// Call from developer console or debug page
DebugCreditMemoPayload('CREDIT_MEMO_NO');
```

#### Get Available Documents for Testing
```al
// Get list of available invoices
GetAvailableInvoicesForDebugging();

// Get list of available credit memos  
GetAvailableCreditMemosForDebugging();
```

#### Azure Function Response Analysis
```al
// Test Azure Function connectivity
TestAzureFunctionConnectivity('INVOICE_NO');

// Download response files for analysis
DownloadAzureFunctionResponse('INVOICE_NO');
```

### Log Analysis

#### Submission Log Fields
- **Document No.**: Reference to original document
- **Submission Date/Time**: When submission occurred
- **Status**: Current processing status
- **LHDN Response**: Complete API response
- **Error Details**: Detailed error information
- **Correlation ID**: Unique tracking identifier

#### TIN Validation Log Fields  
- **Customer No.**: Business Central customer reference
- **TIN No.**: Taxpayer identification number
- **Validation Date/Time**: When validation occurred
- **Validation Result**: Success/failure status
- **LHDN Response**: API response details

### Performance Optimization

#### Caching Strategy
```al
// Company information caching
var
    CompanyInfoCache: Record "Company Information";
    SetupCache: Record "eInvoiceSetup";
    LastCacheRefresh: DateTime;
    CacheValidityDuration: Duration;

local procedure GetCachedCompanyInfo(): Record "Company Information"
begin
    if (LastCacheRefresh = 0DT) or (CurrentDateTime - LastCacheRefresh > CacheValidityDuration) then
        RefreshCache();
    exit(CompanyInfoCache);
end;
```

#### Batch Processing Optimization
- Process multiple documents in single API calls when possible
- Use background job queue for large batches
- Implement retry logic with exponential backoff

## API Reference

### Main Procedures

#### Invoice Processing
```al
// Generate and submit invoice
procedure GetSignedInvoiceAndSubmitToLHDN(SalesInvoiceHeader: Record "Sales Invoice Header"; var LhdnResponse: Text): Boolean

// Generate JSON only
procedure GenerateEInvoiceJson(SalesInvoiceHeader: Record "Sales Invoice Header"; IncludeSignature: Boolean) JsonText: Text

// Submit existing payload
procedure SubmitToLhdnApi(LhdnPayload: JsonObject; SalesInvoiceHeader: Record "Sales Invoice Header"; var LhdnResponse: Text): Boolean
```

#### Credit Memo Processing
```al
// Generate and submit credit memo
procedure GetSignedCreditMemoAndSubmitToLHDN(SalesCrMemoHeader: Record "Sales Cr.Memo Header"; var LhdnResponse: Text): Boolean

// Generate credit memo JSON
procedure GenerateCreditMemoEInvoiceJson(SalesCrMemoHeader: Record "Sales Cr.Memo Header"; IncludeSignature: Boolean) JsonText: Text

// Submit credit memo to LHDN
procedure SubmitCreditMemoToLhdnApi(LhdnPayload: JsonObject; SalesCrMemoHeader: Record "Sales Cr.Memo Header"; var LhdnResponse: Text): Boolean
```

#### Validation and Utilities
```al
// TIN validation
procedure ValidateCustomerTIN(CustomerNo: Code[20]): Boolean

// Field validation
procedure ValidateEInvoiceCompleteness(DocumentType: Option; DocumentNo: Code[20]): Boolean

// Status updates
procedure UpdateInvoiceValidationStatus(InvoiceNo: Code[20]; NewStatus: Text): Boolean
procedure UpdateCreditMemoValidationStatus(CreditMemoNo: Code[20]; NewStatus: Text): Boolean
```

#### Debug and Testing
```al
// Debug procedures
procedure DebugInvoicePayload(InvoiceNo: Code[20])
procedure DebugCreditMemoPayload(CreditMemoNo: Code[20])
procedure TestAzureFunctionConnectivity(DocumentNo: Code[20])

// Information procedures
procedure GetAvailableInvoicesForDebugging(): Text
procedure GetAvailableCreditMemosForDebugging(): Text
```

### Event Subscribers

#### Automatic Processing
```al
// Sales invoice posting
[EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnAfterPostSalesDoc', '', false, false)]
local procedure CopyEInvoiceHeaderFieldsAndAutoSubmit(...)

// Field population
[EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnAfterValidateEvent', 'Sell-to Customer No.', false, false)]
local procedure PopulateEInvoiceFields(...)
```

### Error Codes and Messages

#### Common Error Patterns
```al
// Structure validation errors
'Invalid structured submission' -> Check UBL namespaces and JSON structure

// Authentication errors  
'Unauthorized' -> Verify API tokens and certificates

// Validation errors
'Missing required field' -> Complete mandatory data fields

// TIN validation errors
'Invalid TIN format' -> Verify TIN number format and length
```

## Development Guidelines

### Code Standards

#### Naming Conventions
- **Tables**: Tab50xxx.eInvoice[Purpose]
- **Table Extensions**: Tab-Ext50xxx.eInv[TableName]Ext  
- **Codeunits**: Cod50xxx.eInvoice[Purpose]
- **Pages**: Pag50xxx.eInvoice[Purpose]
- **Page Extensions**: Pag-Ext50xxx.eInv[PageName]Ext
- **Reports**: Rep50xxx.[Purpose]eInv

#### Field Naming
- **Prefix**: "eInvoice" for all custom fields
- **Examples**: "eInvoice Document Type", "eInvoice Currency Code"
- **Consistency**: Use same field names across all table extensions

#### Procedure Structure
```al
/// <summary>
/// Clear description of procedure purpose
/// </summary>
/// <param name="ParameterName">Parameter description</param>
/// <returns>Return value description</returns>
procedure ProcedureName(Parameter: DataType) ReturnType: DataType
var
    LocalVariable: DataType;
begin
    // Implementation with proper error handling
    if not ValidateInput(Parameter) then
        Error('Input validation failed');
        
    // Main logic
    ProcessData(Parameter);
    
    // Return result
    exit(Result);
end;
```

### Testing Procedures

#### Unit Testing
```al
// Test invoice generation
TestInvoiceGeneration();

// Test credit memo generation  
TestCreditMemoGeneration();

// Test Azure Function integration
TestAzureFunctionIntegration();

// Test LHDN API submission
TestLhdnApiSubmission();
```

#### Integration Testing
- Test complete end-to-end flow
- Verify PREPROD environment before PRODUCTION
- Test error scenarios and recovery
- Validate audit trail completeness

### Deployment Guidelines

#### Pre-deployment Checklist
1. **Configuration Validation**
   - Verify all setup tables populated
   - Test Azure Function connectivity
   - Validate LHDN API access

2. **Data Migration**
   - Run data upgrade procedures
   - Validate existing document compatibility
   - Test customer and vendor data

3. **User Training**
   - Document new procedures
   - Train users on e-Invoice requirements
   - Provide troubleshooting guides

#### Post-deployment Monitoring
- Monitor submission success rates
- Track error patterns and resolution
- Validate performance metrics
- Ensure compliance audit trail

### Maintenance Procedures

#### Regular Maintenance
```al
// Monthly TIN validation refresh
RefreshCustomerTINValidation();

// Quarterly setup validation
ValidateSystemConfiguration();

// Annual compliance review
ReviewLhdnComplianceStatus();
```

#### Data Cleanup
```al
// Archive old submission logs
ArchiveSubmissionLogs(CutoffDate);

// Clean up temporary files
CleanupTempFiles();

// Optimize performance
OptimizeSystemPerformance();
```

## Version History

### Current Version: 1.0.0.38
- ✅ Complete UBL 2.1 compliance implementation
- ✅ Full LHDN document type support (01-04, 11-14)
- ✅ Enhanced credit memo processing with proper billing references
- ✅ Azure Function integration with JOTEX P12 signing
- ✅ Comprehensive error handling and logging
- ✅ Automatic field population and validation
- ✅ TIN validation integration
- ✅ Batch processing capabilities
- ✅ Complete audit trail implementation

### Key Improvements in Latest Version
1. **Fixed Credit Memo Structure**: Added missing UBL namespaces and enhanced billing references
2. **LHDN Compliance**: Full alignment with official e-Invoice type specifications
3. **Error Handling**: Comprehensive error parsing and user-friendly messages
4. **Performance**: Optimized JSON generation and API communication
5. **Debugging**: Enhanced debug tools and troubleshooting procedures

## Support and Contact

### Technical Support
- **Primary Developer**: KMAX Development Team
- **Version**: 1.0.0.38
- **Extension ID**: KMAXDev by KMAX

### LHDN Resources
- **Official Documentation**: [MyInvois SDK](https://sdk.myinvois.hasil.gov.my/)
- **API Specification**: [MyInvois API](https://sdk.myinvois.hasil.gov.my/api/)
- **Support Portal**: [LHDN MyInvois Support](https://myinvois.hasil.gov.my/)

### Emergency Procedures
1. **Production Issues**: Immediately switch to manual processing
2. **API Outages**: Monitor LHDN status pages and retry when service restored
3. **Certificate Issues**: Contact Azure Function administrator
4. **Data Corruption**: Restore from backup and reprocess affected documents

---

**Document Version**: 1.0  
**Last Updated**: January 2025  
**Next Review**: March 2025

This documentation covers the complete MyInvois LHDN e-Invoice system implementation. For additional technical details or specific implementation questions, refer to the inline code documentation or contact the development team.

