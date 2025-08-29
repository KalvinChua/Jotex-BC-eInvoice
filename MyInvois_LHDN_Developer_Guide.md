## MyInvois LHDN e-Invoice System — Developer Guide (Concise)

### Purpose
Compact reference for developers integrating Malaysia LHDN MyInvois with Business Central in this extension. Covers setup, object map, core flows, interfaces, rules, and troubleshooting.

### Capabilities
- Digital signing via Azure Function, then submission to LHDN MyInvois
- Documents: Invoice (01), Credit Note (02), Debit Note (03), Refund Note (04), plus self-billed variants
- UBL 2.1 JSON generation (v1.1 profile)
- Status tracking and audit logging
- Page actions to Sign & Submit, generate JSON, and check status

## Object Map (key only)
- Codeunit `eInvoice JSON Generator` (50302)
  - JSON build, Azure Function call, LHDN submission
  - Public:
    - `GetSignedInvoiceAndSubmitToLHDN(Sales Invoice Header; var Text) : Boolean`
    - `GetSignedCreditMemoAndSubmitToLHDN(Sales Cr.Memo Header; var Text) : Boolean`
    - `GenerateEInvoiceJson(Sales Invoice Header; IncludeSignature: Boolean) : Text`
    - `GenerateCreditMemoEInvoiceJson(Sales Cr.Memo Header; IncludeSignature: Boolean) : Text`
    - `SetSuppressUserDialogs(Boolean)`
  - Notable locals:
    - `AddAmountField(var JsonObject; FieldName: Text; Amount: Decimal; Currency: Text)` — allows negative `LineExtensionAmount` at line level; still blocks negative `TaxAmount` and `PayableAmount`.
- Codeunit `eInvoiceAzureFunctionClient` (50310) — outbound HTTP (if used separately)
- Codeunit `eInvoiceSubmissionStatus` (50312) — status + logs
- Pages (extensions)
  - Posted Sales Invoice: action `Sign & Submit to LHDN`
  - Posted Sales Cr. Memo: action `Sign & Submit to LHDN`
  - Posted Return Receipt: action `Sign & Submit to LHDN` (uses linked Posted Credit Memo)

## Setup (minimal path)
1. Open `eInvoice Setup Card` (`Pag50300`)
2. Configure:
   - Azure Function URL (signing service)
   - Environment: PREPROD or PRODUCTION
   - LHDN API base URLs/tokens per environment
3. Master data:
   - Company TIN/BRN, address, bank info
   - Customer e-Invoice flags, TIN/ID type, address codes
   - Item classification (PTC + CLASS), tax type, UOM; currency/state/country codes

## End‑to‑End Flow
1. User clicks `Sign & Submit to LHDN` on a posted document
2. Extension generates UBL 2.1 JSON (unsigned)
3. JSON is sent to Azure Function for digital signing
4. Function returns `signedJson` and `lhdnPayload`
5. Extension submits `lhdnPayload` to LHDN API
6. Response is logged in `eInvoice Submission Log`; page shows status/notifications

## Azure Function Interface
- Request (core fields)
```json
{
  "unsignedJson": "...",
  "invoiceType": "01|02|03|04",
  "environment": "PREPROD|PRODUCTION",
  "timestamp": "YYYY-MM-DDThh:mm:ssZ",
  "correlationId": "GUID",
  "requestId": "GUID"
}
```
- Response (expected)
```json
{
  "success": true,
  "signedJson": "...",
  "lhdnPayload": { "documents": [ /* per LHDN spec */ ] },
  "message": "optional"
}
```

## LHDN API (references)
- See official SDK: [Start](https://sdk.myinvois.hasil.gov.my/start/), [Standard Headers](https://sdk.myinvois.hasil.gov.my/standard-header-parameters/), [Errors](https://sdk.myinvois.hasil.gov.my/standard-error-response/)
- Submission and retrieval:
  - [Submit Documents](https://sdk.myinvois.hasil.gov.my/einvoicingapi/02-submit-documents/)
  - [Get Submission](https://sdk.myinvois.hasil.gov.my/einvoicingapi/06-get-submission/)
  - [Get Document](https://sdk.myinvois.hasil.gov.my/einvoicingapi/07-get-document/)
  - [Get Document Details](https://sdk.myinvois.hasil.gov.my/einvoicingapi/08-get-document-details/)
  - [Cancel](https://sdk.myinvois.hasil.gov.my/einvoicingapi/03-cancel-document/), [Reject](https://sdk.myinvois.hasil.gov.my/einvoicingapi/04-reject-document/)

## Data Rules and Validations (high‑signal)
- UBL 2.1 v1.1 profile for Malaysia.
- Line classifications: require PTC and CLASS codes.
- Negative amounts:
  - Line level: `LineExtensionAmount` may be negative (discount/adjustment lines).
  - Totals: `TaxAmount` and `PayableAmount` must not be negative.
- Credit Notes (02) should be used for document‑level negatives or returns.
- Currency, state, country, tax type, UOM must be valid per local code lists.

## Troubleshooting (quick)
- "Invalid structured submission": verify UBL namespaces and schema; check version (1.1) and arrays/objects shape.
- "Amount field LineExtensionAmount cannot be negative": fixed in generator; ensure you’re on current build. If still hit, confirm your call path uses `AddAmountField` after update.
- Azure Function communication: check URL, network/firewall, and function auth; capture response and correlation ID.
- Credit memo linkage: when raised from Return Receipt, ensure the linked Posted Credit Memo exists.

## Operational Tips
- Use posted document actions for single submissions; use batch reports for bulk export.
- Check `eInvoice Submission Log` for full payloads/responses and correlation IDs.
- For UI flows where popups are undesired, call `SetSuppressUserDialogs(true)` before submission.

## Change Highlights (current)
- Allow negative `LineExtensionAmount` at line level; still block negative `TaxAmount` and `PayableAmount`.
- Posted Return Receipt action submits based on its linked Posted Credit Memo.

### Practical Implementation Examples

#### Complete Invoice Processing Example
```al
// Example: Process invoice with full error handling
procedure ProcessInvoiceWithFullErrorHandling(InvoiceNo: Code[20])
var
    SalesInvoiceHeader: Record "Sales Invoice Header";
    LhdnResponse: Text;
    Success: Boolean;
    ErrorMessage: Text;
begin
    // 1. Get the invoice
    if not SalesInvoiceHeader.Get(InvoiceNo) then
        Error('Invoice %1 not found', InvoiceNo);

    // 2. Validate prerequisites
    if not ValidateInvoiceForSubmission(SalesInvoiceHeader, ErrorMessage) then
        Error('Validation failed: %1', ErrorMessage);

    // 3. Process with error handling
    ClearLastError();
    if not Codeunit.Run(Codeunit::"eInvoice JSON Generator", SalesInvoiceHeader) then begin
        ErrorMessage := GetLastErrorText();
        LogSubmissionError(InvoiceNo, ErrorMessage);
        Error('Processing failed: %1', ErrorMessage);
    end;

    // 4. Submit to LHDN
    Success := SubmitInvoiceToLhdn(SalesInvoiceHeader, LhdnResponse);

    // 5. Update status and log
    UpdateInvoiceStatus(InvoiceNo, Success, LhdnResponse);
    LogSubmissionResult(InvoiceNo, Success, LhdnResponse);
end;
```

#### Custom Field Population Example
```al
// Example: Custom field population for specific business rules
[EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnAfterValidateEvent', 'Sell-to Customer No.', false, false)]
local procedure PopulateCustomEInvoiceFields(var Rec: Record "Sales Header")
var
    Customer: Record Customer;
    SalesLine: Record "Sales Line";
    TotalAmount: Decimal;
begin
    if not Customer.Get(Rec."Sell-to Customer No.") then
        exit;

    if not Customer."Requires e-Invoice" then
        exit;

    // Set document type based on customer type
    case Customer."Customer Type" of
        Customer."Customer Type"::Government:
            Rec."eInvoice Document Type" := '11'; // Self-billed
        Customer."Customer Type"::B2B:
            Rec."eInvoice Document Type" := '01'; // Standard invoice
        else
            Rec."eInvoice Document Type" := '01';
    end;

    // Calculate and set currency
    if Rec."Currency Code" = '' then
        Rec."eInvoice Currency Code" := 'MYR'
    else
        Rec."eInvoice Currency Code" := Rec."Currency Code";

    // Set version
    Rec."eInvoice Version Code" := '1.1';

    // Custom business logic: Set payment terms based on amount
    SalesLine.SetRange("Document Type", Rec."Document Type");
    SalesLine.SetRange("Document No.", Rec."No.");
    if SalesLine.FindSet() then begin
        repeat
            TotalAmount += SalesLine."Line Amount";
        until SalesLine.Next() = 0;

        // Set payment mode based on invoice amount
        if TotalAmount > 50000 then
            Rec."eInvoice Payment Mode" := '02' // Bank transfer for large amounts
        else
            Rec."eInvoice Payment Mode" := '01'; // Cash/cheque for smaller amounts
    end;
end;
```

#### Batch Processing Implementation
```al
// Example: Batch processing multiple invoices
procedure ProcessInvoiceBatch(var InvoiceNos: List of [Code[20]])
var
    SalesInvoiceHeader: Record "Sales Invoice Header";
    SuccessCount: Integer;
    FailCount: Integer;
    ProgressDialog: Dialog;
    i: Integer;
begin
    ProgressDialog.Open('Processing invoice #1###### of #2######\' +
                       'Success: #3######  Failed: #4######');

    for i := 1 to InvoiceNos.Count() do begin
        ProgressDialog.Update(1, i);
        ProgressDialog.Update(2, InvoiceNos.Count());
        ProgressDialog.Update(3, SuccessCount);
        ProgressDialog.Update(4, FailCount);

        if SalesInvoiceHeader.Get(InvoiceNos.Get(i)) then begin
            if ProcessSingleInvoice(SalesInvoiceHeader) then
                SuccessCount += 1
            else
                FailCount += 1;
        end else begin
            LogError(StrSubstNo('Invoice %1 not found', InvoiceNos.Get(i)));
            FailCount += 1;
        end;

        // Small delay to prevent overwhelming the system
        Sleep(100);
    end;

    ProgressDialog.Close();

    Message('Batch processing completed.\Success: %1\Failed: %2',
            SuccessCount, FailCount);
end;
```

### Advanced Integration Patterns

#### Custom API Integration
```al
// Example: Custom LHDN API integration for specific requirements
procedure CustomLhdnApiCall(Endpoint: Text; Payload: Text; var Response: Text): Boolean
var
    HttpClient: HttpClient;
    HttpRequestMessage: HttpRequestMessage;
    HttpResponseMessage: HttpResponseMessage;
    Setup: Record "eInvoiceSetup";
    Headers: HttpHeaders;
    Content: HttpContent;
begin
    Setup.Get();

    // Build request
    HttpRequestMessage.Method('POST');
    HttpRequestMessage.SetRequestUri(Setup."LHDN API URL" + Endpoint);

    // Set headers
    HttpRequestMessage.GetHeaders(Headers);
    Headers.Add('Authorization', 'Bearer ' + Setup."API Token");
    Headers.Add('Content-Type', 'application/json');
    Headers.Add('X-Correlation-ID', CreateGuid());

    // Set content
    Content.WriteFrom(Payload);
    HttpRequestMessage.Content(Content);

    // Send request with timeout
    HttpClient.Timeout(30000); // 30 seconds

    if HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then begin
        HttpResponseMessage.Content.ReadAs(Response);

        if HttpResponseMessage.IsSuccessStatusCode then begin
            LogApiCall(Endpoint, Payload, Response, true);
            exit(true);
        end else begin
            LogApiCall(Endpoint, Payload, Response, false);
            exit(false);
        end;
    end;

    exit(false);
end;
```

#### Error Recovery and Retry Logic
```al
// Example: Intelligent retry logic with exponential backoff
procedure SubmitWithRetry(DocumentNo: Code[20]; Payload: Text; MaxRetries: Integer): Boolean
var
    RetryCount: Integer;
    Success: Boolean;
    DelayMs: Integer;
    Response: Text;
begin
    RetryCount := 0;
    DelayMs := 1000; // Start with 1 second

    repeat
        Success := SubmitToLhdnApi(Payload, Response);

        if Success then begin
            LogSuccess(DocumentNo, Response, RetryCount);
            exit(true);
        end;

        RetryCount += 1;

        if RetryCount <= MaxRetries then begin
            LogRetryAttempt(DocumentNo, RetryCount, GetLastErrorText());

            // Exponential backoff with jitter
            Sleep(DelayMs + Random(500));
            DelayMs := DelayMs * 2; // Double the delay
        end;

    until (RetryCount > MaxRetries) or Success;

    LogFinalFailure(DocumentNo, MaxRetries, GetLastErrorText());
    exit(false);
end;
```

### Testing and Validation

#### Reference Implementation

**Important**: For actual implementation details and working code examples, refer to the GitHub repository:
**Repository**: https://github.com/acutraaq/eInvAzureSign

This repository contains the production-ready Azure Function code for document signing and LHDN integration.

#### Unit Test Example
```al
// Example: Unit test for JSON generation
[Test]
procedure TestInvoiceJsonGeneration()
var
    SalesInvoiceHeader: Record "Sales Invoice Header";
    JsonGenerator: Codeunit "eInvoice JSON Generator";
    JsonText: Text;
    JsonObject: JsonObject;
begin
    // Setup test data
    LibrarySales.CreateSalesInvoice(SalesInvoiceHeader);
    SetupEInvoiceFields(SalesInvoiceHeader);

    // Execute
    JsonText := JsonGenerator.GenerateEInvoiceJson(SalesInvoiceHeader, false);

    // Verify
    Assert.AreNotEqual('', JsonText, 'JSON should not be empty');

    // Parse and validate structure
    Assert.IsTrue(JsonObject.ReadFrom(JsonText), 'Should be valid JSON');

    // Check required UBL structure
    VerifyUblStructure(JsonObject);

    // Check invoice-specific fields
    VerifyInvoiceFields(JsonObject, SalesInvoiceHeader);
end;
```

#### Integration Test Example
```al
// Example: Integration test for end-to-end flow
[Test]
procedure TestEndToEndInvoiceProcessing()
var
    SalesInvoiceHeader: Record "Sales Invoice Header";
    JsonGenerator: Codeunit "eInvoice JSON Generator";
    AzureClient: Codeunit "eInvoiceAzureFunctionClient";
    SubmissionStatus: Codeunit "eInvoiceSubmissionStatus";
    JsonText: Text;
    SignedJson: Text;
    LhdnPayload: Text;
    Success: Boolean;
begin
    // Setup
    InitializeTestEnvironment();
    CreateTestInvoice(SalesInvoiceHeader);

    // Test JSON generation
    JsonText := JsonGenerator.GenerateEInvoiceJson(SalesInvoiceHeader, false);
    Assert.AreNotEqual('', JsonText, 'JSON generation failed');

    // Test Azure Function signing (mocked in test environment)
    Success := AzureClient.SignDocument(JsonText, SignedJson, LhdnPayload);
    Assert.IsTrue(Success, 'Azure Function signing failed');

    // Test LHDN submission (mocked in test environment)
    Success := SubmitToLhdnApi(LhdnPayload, SalesInvoiceHeader, '');
    Assert.IsTrue(Success, 'LHDN submission failed');

    // Verify status update
    Assert.AreEqual('Submitted', SalesInvoiceHeader."eInvoice Validation Status",
                   'Status should be updated to Submitted');
end;
```

### Performance Optimization

#### Caching Implementation
```al
// Example: Implement caching for frequently accessed data
codeunit 50326 "eInvoice Cache Manager"
{
    var
        CompanyInfoCache: Record "Company Information";
        SetupCache: Record "eInvoiceSetup";
        StateCodesCache: Record "State Codes";
        LastCacheRefresh: DateTime;
        CacheValidityMinutes: Integer;

    procedure GetCachedCompanyInfo(): Record "Company Information"
    begin
        if NeedsRefresh() then
            RefreshCache();

        exit(CompanyInfoCache);
    end;

    procedure GetCachedSetup(): Record "eInvoiceSetup"
    begin
        if NeedsRefresh() then
            RefreshCache();

        exit(SetupCache);
    end;

    local procedure NeedsRefresh(): Boolean
    begin
        exit((LastCacheRefresh = 0DT) or
             (CurrentDateTime - LastCacheRefresh > CacheValidityMinutes * 60000));
    end;

    local procedure RefreshCache()
    var
        CompanyInfo: Record "Company Information";
        Setup: Record "eInvoiceSetup";
    begin
        if CompanyInfo.Get() then
            CompanyInfoCache := CompanyInfo;

        if Setup.Get() then
            SetupCache := Setup;

        // Cache state codes if needed
        // StateCodesCache.SetRange(...);

        LastCacheRefresh := CurrentDateTime;
    end;
}
```

#### Background Processing
```al
// Example: Background job queue implementation
procedure ScheduleInvoiceProcessing(DocumentNo: Code[20])
var
    JobQueueEntry: Record "Job Queue Entry";
begin
    JobQueueEntry.Init();
    JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
    JobQueueEntry."Object ID to Run" := Codeunit::"eInvoice Background Processor";
    JobQueueEntry."Parameter String" := DocumentNo;
    JobQueueEntry."Maximum No. of Attempts to Run" := 3;
    JobQueueEntry."Rerun Delay (sec.)" := 300; // 5 minutes
    JobQueueEntry.Description := StrSubstNo('Process e-Invoice for %1', DocumentNo);
    JobQueueEntry."Job Queue Category Code" := 'EINVOICE';
    JobQueueEntry.Status := JobQueueEntry.Status::Ready;
    JobQueueEntry.Insert(true);
end;
```

### Security Best Practices

#### Secure Configuration Storage
```al
// Example: Secure handling of sensitive configuration
procedure GetSecureApiToken(): Text
var
    Setup: Record "eInvoiceSetup";
    IsolatedStorage: Codeunit "Isolated Storage";
    TokenKey: Text;
begin
    Setup.Get();
    TokenKey := 'LHDN_API_TOKEN_' + Format(Setup.Environment);

    // Retrieve from isolated storage instead of plain text field
    if IsolatedStorage.Get(TokenKey, TokenKey) then
        exit(TokenKey);

    Error('API token not configured. Please set up the token in isolated storage.');
end;
```

#### Input Validation and Sanitization
```al
// Example: Comprehensive input validation
procedure ValidateEInvoiceData(var SalesInvoiceHeader: Record "Sales Invoice Header"): Boolean
var
    Customer: Record Customer;
    ErrorMessage: Text;
begin
    // Validate customer
    if not Customer.Get(SalesInvoiceHeader."Sell-to Customer No.") then begin
        ErrorMessage := 'Customer not found';
        exit(false);
    end;

    // Validate TIN
    if Customer."e-Invoice TIN No." = '' then begin
        ErrorMessage := 'Customer TIN is required';
        exit(false);
    end;

    // Validate TIN format
    if not ValidateTINFormat(Customer."e-Invoice TIN No.") then begin
        ErrorMessage := 'Invalid TIN format';
        exit(false);
    end;

    // Validate address completeness
    if not ValidateAddressCompleteness(Customer) then begin
        ErrorMessage := 'Customer address is incomplete';
        exit(false);
    end;

    // Validate document amounts
    if not ValidateDocumentAmounts(SalesInvoiceHeader) then begin
        ErrorMessage := 'Invalid document amounts';
        exit(false);
    end;

    exit(true);
end;
```

### Monitoring and Alerting

#### Health Check Implementation
```al
// Example: System health monitoring
procedure PerformSystemHealthCheck(): Text
var
    Setup: Record "eInvoiceSetup";
    HttpClient: HttpClient;
    HttpResponseMessage: HttpResponseMessage;
    HealthStatus: Text;
begin
    HealthStatus := 'System Health Check Results:\';

    // Check setup configuration
    if not Setup.Get() then
        HealthStatus += '\❌ eInvoice Setup not configured'
    else
        HealthStatus += '\✅ eInvoice Setup configured';

    // Check Azure Function connectivity
    if TestAzureFunctionConnectivity() then
        HealthStatus += '\✅ Azure Function accessible'
    else
        HealthStatus += '\❌ Azure Function not accessible';

    // Check LHDN API connectivity
    if TestLhdnApiConnectivity() then
        HealthStatus += '\✅ LHDN API accessible'
    else
        HealthStatus += '\❌ LHDN API not accessible';

    // Check certificate validity
    if TestCertificateValidity() then
        HealthStatus += '\✅ Digital certificate valid'
    else
        HealthStatus += '\❌ Digital certificate expired or invalid';

    exit(HealthStatus);
end;
```

#### Alert System
```al
// Example: Alert system for critical issues
procedure SendAlertIfNeeded(AlertType: Option; Details: Text)
var
    Setup: Record "eInvoiceSetup";
    Email: Codeunit Email;
    EmailMessage: Codeunit "Email Message";
begin
    Setup.Get();

    if not Setup."Enable Alerts" then
        exit;

    case AlertType of
        AlertType::SubmissionFailure:
            begin
                EmailMessage.Create(Setup."Alert Email Recipients",
                                  'e-Invoice Submission Failure Alert',
                                  StrSubstNo('Critical: e-Invoice submission failed.\Details: %1', Details));
            end;
        AlertType::CertificateExpiry:
            begin
                EmailMessage.Create(Setup."Alert Email Recipients",
                                  'Digital Certificate Expiry Alert',
                                  StrSubstNo('Warning: Digital certificate expires soon.\Details: %1', Details));
            end;
        AlertType::ApiConnectivity:
            begin
                EmailMessage.Create(Setup."Alert Email Recipients",
                                  'LHDN API Connectivity Alert',
                                  StrSubstNo('Warning: LHDN API connectivity issues.\Details: %1', Details));
            end;
    end;

    Email.Send(EmailMessage);
end;
```

## References

### External Resources
- [LHDN MyInvois Official Documentation](https://sdk.myinvois.hasil.gov.my/)
- [UBL 2.1 Specification](https://docs.oasis-open.org/ubl/UBL-2.1.html)
- [Microsoft Dynamics 365 Business Central Documentation](https://docs.microsoft.com/en-us/dynamics365/business-central/)

### Internal Resources
- System Documentation: `MyInvois_LHDN_eInvoice_System_Documentation.md`
- User Guide: `MyInvois_LHDN_User_Guide.md`
- API Reference: Inline code documentation

---

**Developer Guide Version**: 2.0
**Last Updated**: January 2025
**Next Review**: March 2025

*This developer guide provides comprehensive technical information for implementing and maintaining the MyInvois LHDN e-Invoice system. For end-user instructions, refer to the User Guide.*
## References
- SDK samples and specs: [Document Types](https://sdk.myinvois.hasil.gov.my/codes/e-invoice-types/), [Invoice v1.1](https://sdk.myinvois.hasil.gov.my/documents/invoice-v1-1/), [Credit v1.1](https://sdk.myinvois.hasil.gov.my/documents/credit-v1-1/), [Debit v1.1](https://sdk.myinvois.hasil.gov.my/documents/debit-v1-1/)
 

