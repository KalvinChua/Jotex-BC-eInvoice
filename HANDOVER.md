# Developer Handover Documentation

## Jotex Business Central e-Invoice Extension

> **Last Updated**: December 2025  
> **Project Status**: Production (Active)  
> **Compliance**: LHDN MyInvois Malaysia e-Invoice Mandate

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Project Takeover Checklist](#2-project-takeover-checklist)
3. [Development Environment Setup](#3-development-environment-setup)
4. [Architecture Deep Dive](#4-architecture-deep-dive)
5. [Critical Components Reference](#5-critical-components-reference)
6. [Operational Workflows](#6-operational-workflows)
7. [Testing & Quality Assurance](#7-testing--quality-assurance)
8. [Deployment Procedures](#8-deployment-procedures)
9. [Troubleshooting Guide](#9-troubleshooting-guide)
10. [Maintenance & Support](#10-maintenance--support)

---

## 1. Executive Summary

### 1.1 Project Purpose

This extension enables **Microsoft Dynamics 365 Business Central** to comply with Malaysia's **LHDN (Lembaga Hasil Dalam Negeri) MyInvois** e-invoicing mandate. It handles the complete lifecycle of e-Invoice generation, digital signing, submission, and status tracking.

### 1.2 Business Impact

- **Compliance**: Legal requirement for Malaysian businesses
- **Volume**: Processes all sales invoices and credit memos
- **Criticality**: HIGH - Failure blocks invoice issuance
- **Users**: Finance team, sales operations

### 1.3 Technical Stack

- **Platform**: Business Central 22.0+ (AL Language)
- **Cloud Services**: Azure Functions (Document Signing)
- **External APIs**: LHDN MyInvois API
- **Standards**: UBL 2.1 (Universal Business Language)

---

## 2. Project Takeover Checklist

### 2.1 Access & Credentials (Week 1)

Complete these tasks in your first week:

- [ ] **Source Code Access**
  - Clone repository: `git clone <repo-url>`
  - Verify you can build the project locally
  - Ensure you have access to the GitHub organization and required repositories

- [ ] **Environment Access**
  - Business Central Sandbox environment credentials
  - Business Central Production environment (read-only initially)
  - Azure Portal access (Resource Group: `rg-myinvois-*`)

- [ ] **API Credentials**
  - LHDN MyInvois PreProd credentials (Client ID/Secret)
  - LHDN MyInvois Production credentials (Client ID/Secret)
  - Azure Function URL and access keys

- [ ] **Documentation Review**
  - Read this handover document completely
  - Review `MyInvois_LHDN_eInvoice_System_Documentation.md`
  - Skim `MyInvois_LHDN_Developer_Guide.md`

### 2.2 Knowledge Transfer Sessions (Week 1-2)

Schedule these sessions with the previous developer:

1. **Session 1: Architecture Walkthrough** (2 hours)
   - Data flow from BC → Azure → LHDN
   - Key codeunits and their responsibilities
   - Configuration in `eInvoice Setup`

2. **Session 2: Common Issues & Resolutions** (1.5 hours)
   - "Invalid Structured Submission" debugging
   - Certificate renewal process
   - Token expiry handling

3. **Session 3: Deployment Process** (1 hour)
   - Extension deployment to BC environments
   - Azure Function deployment
   - Rollback procedures

4. **Session 4: Support Scenarios** (1 hour)
   - How to investigate user-reported issues
   - Using `eInvoice Submission Log` for diagnostics
   - Escalation procedures

### 2.3 Hands-On Tasks (Week 2-3)

Complete these practical exercises:

- [ ] **Exercise 1**: Generate Test Invoice
  - Create a test customer with e-Invoice enabled
  - Post a sales invoice
  - Submit to LHDN PreProd
  - Verify in submission log

- [ ] **Exercise 2**: Debug a Failed Submission
  - Intentionally create an invalid invoice (missing TIN)
  - Attempt submission
  - Use debugging tools to identify the issue
  - Fix and resubmit

- [ ] **Exercise 3**: Deploy a Minor Change
  - Make a cosmetic change (e.g., modify a label)
  - Build the extension
  - Deploy to sandbox
  - Verify the change

- [ ] **Exercise 4**: Review Production Logs
  - Access `eInvoice Submission Log` in production
  - Identify the last 10 submissions
  - Check for any failed submissions
  - Understand the error patterns

---

## 3. Development Environment Setup

### 3.1 Prerequisites

Install the following tools:

```powershell
# Required Software
- Visual Studio Code (latest)
- AL Language Extension for VS Code
- Git for Windows
- Docker Desktop (for BC container development)
- Azure CLI (for Azure Function management)
- Postman or similar (for API testing)
```

### 3.2 Local Development Setup

#### Step 1: Clone Repository

```bash
git clone https://github.com/your-org/Jotex-BC-eInvoice.git
cd Jotex-BC-eInvoice
```

#### Step 2: Configure VS Code

Create `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "al",
      "request": "launch",
      "name": "BC Sandbox",
      "server": "https://businesscentral.dynamics.com",
      "serverInstance": "BC220",
      "tenant": "your-tenant-id",
      "authentication": "AAD",
      "startupObjectId": 50300,
      "startupObjectType": "Page",
      "breakOnError": true,
      "launchBrowser": true
    }
  ]
}
```

#### Step 3: Download Symbols

```powershell
# In VS Code, press F1 and run:
AL: Download Symbols
```

#### Step 4: Build Extension

```powershell
# Press Ctrl+Shift+B or F5 to build and deploy
```

### 3.3 Azure Function Local Development

#### Setup Azure Functions Core Tools

```bash
# Install Azure Functions Core Tools
npm install -g azure-functions-core-tools@4

# Navigate to Azure Function project
cd ../eInvAzureSign  # Separate repository

# Install dependencies
dotnet restore

# Run locally
func start
```

#### Test Local Azure Function

```bash
# Test the signing endpoint
curl -X POST http://localhost:7071/api/SignDocument \
  -H "Content-Type: application/json" \
  -d '{
    "unsignedJson": "...",
    "invoiceType": "01",
    "environment": "PREPROD"
  }'
```

### 3.4 Database Access (Optional)

For deep debugging, you may need direct database access:

```sql
-- Connect to BC database (on-prem only)
-- Query submission log
SELECT TOP 100 
    [Invoice No_],
    [Status],
    [Submission Date],
    [Error Message]
FROM [eInvoice Submission Log]
ORDER BY [Submission Date] DESC;
```

---

## 4. Architecture Deep Dive

### 4.1 System Architecture Diagram

```plaintext
┌─────────────────────────────────────────────────────────────────┐
│                     Business Central                             │
│                                                                  │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────────┐  │
│  │ Sales Invoice│─────▶│ eInvoice JSON│─────▶│ Azure Function│  │
│  │   Posting    │      │  Generator   │      │    Client     │  │
│  └──────────────┘      └──────────────┘      └───────┬────────┘  │
│                                                       │           │
└───────────────────────────────────────────────────────┼───────────┘
                                                        │
                                                        ▼
                                            ┌───────────────────┐
                                            │  Azure Function   │
                                            │  (Document Sign)  │
                                            └─────────┬─────────┘
                                                      │
                                                      ▼
                                            ┌───────────────────┐
                                            │   LHDN MyInvois   │
                                            │       API         │
                                            └───────────────────┘
```

### 4.2 Data Flow Sequence

#### 4.2.1 Invoice Submission Flow

```text
1. User Action
   └─▶ User posts Sales Invoice OR clicks "Sign & Submit to LHDN"

2. Field Population (Automatic)
   └─▶ Cod50306.eInvFieldPopulation
       ├─▶ Copies e-Invoice fields from Sales Header to Posted Invoice
       └─▶ Validates mandatory fields (TIN, Address, etc.)

3. JSON Generation
   └─▶ Cod50302.GenerateEInvoiceJson()
       ├─▶ Builds UBL 2.1 JSON structure
       ├─▶ Adds supplier party (Company Info)
       ├─▶ Adds customer party (Customer record)
       ├─▶ Adds invoice lines with tax details
       └─▶ Returns unsigned JSON string

4. Azure Function Signing
   └─▶ Cod50302.TryPostToAzureFunctionDirect()
       ├─▶ HTTP POST to Azure Function URL
       ├─▶ Payload: { unsignedJson, invoiceType, environment }
       ├─▶ Azure Function loads P12 certificate
       ├─▶ Signs JSON using XAdES
       └─▶ Returns: { success, signedJson, lhdnPayload }

5. LHDN Submission
   └─▶ Cod50302.SubmitToLhdnApi()
       ├─▶ Extracts lhdnPayload from Azure response
       ├─▶ Gets LHDN access token (OAuth 2.0)
       ├─▶ HTTP POST to LHDN API /documentsubmissions
       └─▶ Receives: { submissionUid, acceptedDocuments, rejectedDocuments }

6. Status Update
   └─▶ Cod50302.UpdateSalesInvoiceWithLhdnResponse()
       ├─▶ Updates "eInvoice Validation Status" field
       ├─▶ Stores Submission UID and Document UUID
       └─▶ Logs to eInvoice Submission Log table

7. QR Code Generation (Background)
   └─▶ Cod50302.TryFetchAndStoreValidationLink()
       ├─▶ Fetches longId from LHDN (retry logic)
       ├─▶ Builds validation URL
       └─▶ Generates and stores QR code image
```

### 4.3 Why This Architecture?

#### Design Decision: Sidecar Pattern

**Problem**: Business Central cannot perform complex cryptographic operations (P12 certificate signing with XAdES).

**Solution**: Offload signing to Azure Function.

**Benefits**:

- **Separation of Concerns**: BC handles business logic, Azure handles crypto
- **Security**: Certificate never leaves Azure (stored in Key Vault)
- **Scalability**: Azure Functions auto-scale under load
- **Maintainability**: Crypto logic isolated from BC codebase

**Trade-offs**:

- **Network Dependency**: Requires reliable internet connection
- **Latency**: Additional HTTP round-trip (~500ms-2s)
- **Complexity**: Two deployment targets (BC + Azure)

---

## 5. Critical Components Reference

### 5.1 Core Codeunits

#### Cod50302: eInvoice JSON Generator

**Location**: `Cod50302.eInvoiceJSONGenerator.al`  
**Lines of Code**: ~7,000  
**Responsibility**: The "brain" of the system

**Key Procedures**:

```al
// Main entry point for invoice submission
procedure GetSignedInvoiceAndSubmitToLHDN(
    SalesInvoiceHeader: Record "Sales Invoice Header"; 
    var LhdnResponse: Text
): Boolean

// Generates unsigned UBL 2.1 JSON
procedure GenerateEInvoiceJson(
    SalesInvoiceHeader: Record "Sales Invoice Header"; 
    IncludeSignature: Boolean
): Text

// Credit memo variant
procedure GetSignedCreditMemoAndSubmitToLHDN(
    SalesCrMemoHeader: Record "Sales Cr.Memo Header"; 
    var LhdnResponse: Text
): Boolean
```

**Critical Internal Procedures**:

- `BuildEInvoiceJson()`: Constructs UBL structure
- `AddAccountingSupplierParty()`: Company information
- `AddAccountingCustomerParty()`: Customer information
- `AddInvoiceLines()`: Line items with tax
- `TryPostToAzureFunctionDirect()`: Azure communication
- `SubmitToLhdnApi()`: LHDN API submission
- `ParseAndDisplayLhdnResponse()`: Response handling

**Error Handling**:

- Validates all mandatory fields before generation
- Retry logic for Azure Function (3 attempts with exponential backoff)
- Detailed error logging to Submission Log

#### Cod50310: eInvoiceAzureFunctionClient

**Location**: `Cod50310.eInvoiceAzureFunctionClient.al`  
**Responsibility**: HTTP client for Azure Function

**Note**: Most Azure communication is now in `Cod50302` for better cohesion. This codeunit may be deprecated in future versions.

#### Cod50312: eInvoiceSubmissionStatus

**Location**: `Cod50312.eInvoiceSubmissionStatus.al`  
**Responsibility**: Status tracking and retrieval

**Key Procedures**:

- `GetSubmissionStatus()`: Polls LHDN for submission status
- `GetDocumentDetails()`: Retrieves document metadata
- `UpdateStatusFromLhdn()`: Syncs status from LHDN

### 5.2 Tables

#### Tab50300: eInvoiceSetup

**Purpose**: System configuration (singleton table)

**Critical Fields**:

```al
field(1; "Primary Key"; Code[10]) { }
field(10; "Azure Function URL"; Text[250]) { }
field(20; "Environment"; Enum "eInvoice Environment") { }  // PREPROD | PRODUCTION
field(30; "Client ID"; Text[100]) { }
field(40; "Client Secret"; Text[100]) { }  // ⚠️ Security: Should use Isolated Storage
field(50; "LHDN API URL"; Text[250]) { }
field(60; "Last Token"; Text[2048]) { }
field(70; "Token Timestamp"; DateTime) { }
field(80; "Token Expiry (s)"; Integer) { }
```

**Access**: Search "eInvoice Setup Card" in BC

#### Tab50312: eInvoice Submission Log

**Purpose**: Audit trail of all submissions

**Critical Fields**:

```al
field(1; "Entry No."; Integer) { AutoIncrement = true; }
field(10; "Invoice No."; Code[20]) { }
field(20; "Submission Date"; DateTime) { }
field(30; "Status"; Text[50]) { }  // Submitted | Failed | Pending
field(40; "Submission UID"; Text[100]) { }  // LHDN reference
field(50; "Document UUID"; Text[100]) { }  // LHDN document ID
field(60; "Error Message"; Text[2048]) { }
field(70; "Correlation ID"; Text[50]) { }  // For tracing
field(80; "Environment"; Enum "eInvoice Environment") { }
```

**Usage**: Primary debugging tool. Always check this first when investigating issues.

### 5.3 Page Extensions

#### Pag-Ext50306: eInvPostedSalesInvoiceExt

**Extends**: Posted Sales Invoice (Page 132)

**Added Actions**:

- **"Sign & Submit to LHDN"**: Main submission action
- **"View Submission Log"**: Opens related log entries
- **"Download JSON"**: Debug action to download generated JSON
- **"Validate TIN"**: Validates customer TIN with LHDN

**Added Fields**:

- eInvoice Validation Status
- eInvoice Submission UID
- eInvoice UUID
- eInv QR URL

---

## 6. Operational Workflows

### 6.1 Normal Invoice Processing

#### User Workflow

```text
1. Create Sales Invoice
   └─▶ Ensure customer has "Requires e-Invoice" = Yes

2. Post Invoice
   └─▶ System auto-populates e-Invoice fields
   └─▶ (Optional) Auto-submit if configured

3. Manual Submission (if not auto)
   └─▶ Open Posted Sales Invoice
   └─▶ Click "Sign & Submit to LHDN"
   └─▶ Wait for confirmation message

4. Verify Submission
   └─▶ Check "eInvoice Validation Status" = "Submitted"
   └─▶ Note the Submission UID
```

#### System Workflow (Behind the Scenes)

```text
1. Posting Trigger
   └─▶ Codeunit 80 "Sales-Post" (standard BC)
   └─▶ Event: OnAfterPostSalesDoc
   └─▶ Subscriber: Cod50305.CopyEInvoiceHeaderFieldsAndAutoSubmit()

2. Field Copy
   └─▶ Copies all e-Invoice fields from Sales Header to Posted Invoice
   └─▶ Validates mandatory fields

3. Auto-Submit (if enabled)
   └─▶ Calls Cod50302.GetSignedInvoiceAndSubmitToLHDN()
   └─▶ Entire flow executes automatically

4. Status Update
   └─▶ Posted Invoice updated with status
   └─▶ User sees confirmation or error message
```

### 6.2 Credit Memo Processing

**Important**: Credit memos follow similar flow but use different UBL structure.

#### Key Differences

- Document Type Code: `02` (Credit Note)
- Requires `BillingReference` to original invoice (if available)
- Amounts are positive in LHDN submission (system handles conversion)

#### Workflow

```text
1. Create Credit Memo
   └─▶ Link to original invoice via "Applies-to Doc. No." (recommended)

2. Post Credit Memo
   └─▶ System generates Credit Note JSON

3. Submit
   └─▶ Click "Sign & Submit to LHDN" on Posted Credit Memo
   └─▶ System uses Cod50302.GetSignedCreditMemoAndSubmitToLHDN()
```

### 6.3 Batch Processing

For processing multiple documents:

```al
// Example: Batch submit all pending invoices
procedure BatchSubmitPendingInvoices()
var
    SalesInvoiceHeader: Record "Sales Invoice Header";
    eInvoiceGenerator: Codeunit "eInvoice JSON Generator";
    LhdnResponse: Text;
    SuccessCount: Integer;
    FailCount: Integer;
begin
    SalesInvoiceHeader.SetRange("eInvoice Validation Status", '');
    SalesInvoiceHeader.SetFilter("Sell-to Customer No.", '<>''''');
    
    if SalesInvoiceHeader.FindSet() then
        repeat
            if eInvoiceGenerator.GetSignedInvoiceAndSubmitToLHDN(SalesInvoiceHeader, LhdnResponse) then
                SuccessCount += 1
            else
                FailCount += 1;
            
            Commit();  // Commit after each to prevent rollback
            Sleep(500);  // Rate limiting
        until SalesInvoiceHeader.Next() = 0;
    
    Message('Batch complete. Success: %1, Failed: %2', SuccessCount, FailCount);
end;
```

---

## 7. Testing & Quality Assurance

### 7.1 Test Environments

#### PreProd Environment

- **LHDN URL**: `https://preprod-api.myinvois.hasil.gov.my`
- **Purpose**: All development and testing
- **Data**: Use test customers and items
- **Credentials**: Separate Client ID/Secret from production

#### Production Environment

- **LHDN URL**: `https://api.myinvois.hasil.gov.my`
- **Purpose**: Live business transactions
- **Access**: Restricted, requires approval
- **Monitoring**: Enhanced logging and alerting

### 7.2 Test Scenarios

#### Scenario 1: Standard Invoice

```text
Given: Customer with valid TIN and complete address
When: Post sales invoice with 1 item line
Then: 
  - JSON generated successfully
  - Azure Function signs document
  - LHDN accepts submission
  - Status = "Submitted"
  - Submission UID populated
```

#### Scenario 2: Credit Note with Reference

```text
Given: Posted invoice already submitted to LHDN
When: Create credit memo with "Applies-to Doc. No." = invoice number
Then:
  - Credit Note JSON includes BillingReference
  - LHDN links credit note to original invoice
```

#### Scenario 3: Invalid Customer Data

```text
Given: Customer with missing TIN
When: Attempt to submit invoice
Then:
  - Validation error before submission
  - Clear error message to user
  - No API call made
```

#### Scenario 4: Network Failure

```text
Given: Azure Function is unreachable
When: Attempt to submit invoice
Then:
  - Retry logic executes (3 attempts)
  - User sees timeout error
  - Submission log shows "Failed" with error details
```

### 7.3 Automated Testing

#### Unit Tests (if implemented)

```al
[Test]
procedure TestJsonGeneration()
var
    SalesInvoiceHeader: Record "Sales Invoice Header";
    JsonText: Text;
begin
    // Arrange
    CreateTestInvoice(SalesInvoiceHeader);
    
    // Act
    JsonText := GenerateEInvoiceJson(SalesInvoiceHeader, false);
    
    // Assert
    Assert.AreNotEqual('', JsonText, 'JSON should not be empty');
    Assert.IsTrue(JsonText.Contains('"Invoice"'), 'Should contain Invoice element');
end;
```

### 7.4 Manual Testing Checklist

Before each release:

- [ ] Test standard invoice submission (PreProd)
- [ ] Test credit memo submission (PreProd)
- [ ] Test with missing mandatory fields (should fail gracefully)
- [ ] Test Azure Function connectivity
- [ ] Test LHDN API connectivity
- [ ] Verify submission log entries
- [ ] Test QR code generation
- [ ] Test batch processing (10 invoices)
- [ ] Verify error messages are user-friendly

---

## 8. Deployment Procedures

### 8.1 Extension Deployment to Business Central

#### Step 1: Build Extension

```powershell
# In VS Code
# Press F5 or Ctrl+Shift+B
# Or use command line:
alc.exe /project:"c:\path\to\project" /packagecachepath:"c:\path\to\.alpackages"
```

#### Step 2: Publish to Sandbox

```powershell
# Using BC Admin Center or PowerShell
Publish-NAVApp -ServerInstance BC220 -Path ".\KMAXDev.app" -SkipVerification
Install-NAVApp -ServerInstance BC220 -Name "KMAXDev" -Version "1.0.0.62"
```

#### Step 3: Test in Sandbox

- Run through test scenarios
- Verify no regressions
- Check submission log

#### Step 4: Deploy to Production

```powershell
# Schedule during maintenance window
# Backup current version first
Publish-NAVApp -ServerInstance BC220-PROD -Path ".\KMAXDev.app"
Sync-NAVApp -ServerInstance BC220-PROD -Name "KMAXDev" -Version "1.0.0.62"
Install-NAVApp -ServerInstance BC220-PROD -Name "KMAXDev" -Version "1.0.0.62"
```

### 8.2 Azure Function Deployment

#### Step 1: Build Function

```bash
cd eInvAzureSign
dotnet build --configuration Release
```

#### Step 2: Deploy to Azure

```bash
# Using Azure CLI
az functionapp deployment source config-zip \
  --resource-group rg-myinvois-prod \
  --name func-myinvois-prod \
  --src ./publish.zip
```

#### Step 3: Verify Deployment

```bash
# Test health endpoint
curl https://func-myinvois-prod.azurewebsites.net/api/health

# Test signing endpoint (with valid payload)
curl -X POST https://func-myinvois-prod.azurewebsites.net/api/SignDocument \
  -H "Content-Type: application/json" \
  -d @test-payload.json
```

### 8.3 Rollback Procedures

#### BC Extension Rollback

```powershell
# Uninstall current version
Uninstall-NAVApp -ServerInstance BC220-PROD -Name "KMAXDev" -Version "1.0.0.62"

# Reinstall previous version
Install-NAVApp -ServerInstance BC220-PROD -Name "KMAXDev" -Version "1.0.0.61"
```

#### Azure Function Rollback

```bash
# Swap deployment slots
az functionapp deployment slot swap \
  --resource-group rg-myinvois-prod \
  --name func-myinvois-prod \
  --slot staging \
  --target-slot production
```

---

## 9. Troubleshooting Guide

### 9.1 Common Issues

#### Issue 1: "Invalid Structured Submission"

**Symptom**: LHDN rejects submission with this error

**Root Cause**: JSON structure doesn't match UBL 2.1 schema

**Debug Steps**:

1. Run `DownloadAzureFunctionPayloadForDebugging()` in Cod50302
2. Download the generated JSON files
3. Validate against LHDN validator: <https://sdk.myinvois.hasil.gov.my/>
4. Check for:
   - Missing mandatory fields
   - Incorrect namespace declarations
   - Invalid field formats (dates, amounts)

**Common Fixes**:

- Ensure UBL namespaces are correct: `_D`, `_A`, `_B`
- Verify all amounts have `currencyID` attribute
- Check date format: `YYYY-MM-DD`
- Validate array structures (must be arrays, not objects)

#### Issue 2: Azure Function Timeout

**Symptom**: "Failed to communicate with Azure Function"

**Debug Steps**:

1. Check Azure Function URL in eInvoice Setup
2. Test connectivity: `TestAzureFunctionConnectivity()` in Cod50302
3. Check Azure Function logs in Azure Portal
4. Verify certificate is loaded correctly

**Common Fixes**:

- Update Azure Function URL if redeployed
- Check firewall rules (BC must reach Azure)
- Verify function key is correct
- Restart Azure Function if hung

#### Issue 3: LHDN 401 Unauthorized

**Symptom**: "LHDN authentication failed"

**Debug Steps**:

1. Check Client ID and Client Secret in eInvoice Setup
2. Verify environment (PREPROD vs PRODUCTION)
3. Test token generation manually
4. Check token expiry

**Common Fixes**:

- Refresh credentials from LHDN portal
- Ensure correct environment selected
- Clear cached token (delete "Last Token" field value)
- Verify API access is still active in LHDN portal

#### Issue 4: Missing QR Code

**Symptom**: QR code not generated after successful submission

**Root Cause**: Background process to fetch `longId` failed

**Debug Steps**:

1. Check if Submission UID and UUID are populated
2. Manually call `TryFetchAndStoreValidationLink()`
3. Check LHDN API response for `longId` field

**Fix**:

- Wait 5-10 minutes (LHDN may delay populating longId)
- Manually retry QR generation
- Verify network connectivity to LHDN

### 9.2 Debugging Tools

#### Tool 1: Submission Log Analysis

```al
// Find failed submissions
SubmissionLog.SetRange(Status, 'Submission Failed');
SubmissionLog.SetRange("Submission Date", Today - 7, Today);
if SubmissionLog.FindSet() then
    repeat
        // Analyze error patterns
        Message('Invoice: %1, Error: %2', 
            SubmissionLog."Invoice No.", 
            SubmissionLog."Error Message");
    until SubmissionLog.Next() = 0;
```

#### Tool 2: JSON Download for Debugging

```al
// In Cod50302
procedure DebugInvoicePayload(InvoiceNo: Code[20])
var
    SalesInvoiceHeader: Record "Sales Invoice Header";
    JsonText: Text;
    TempBlob: Codeunit "Temp Blob";
    OutStream: OutStream;
    InStream: InStream;
begin
    SalesInvoiceHeader.Get(InvoiceNo);
    JsonText := GenerateEInvoiceJson(SalesInvoiceHeader, false);
    
    TempBlob.CreateOutStream(OutStream);
    OutStream.WriteText(JsonText);
    TempBlob.CreateInStream(InStream);
    
    DownloadFromStream(InStream, 'Download JSON', '', 'JSON Files (*.json)|*.json', 
        'Invoice_' + InvoiceNo + '.json');
end;
```

#### Tool 3: Azure Function Response Inspection

Check `Cod50302` for these debug procedures:

- `DownloadAzureFunctionPayloadForDebugging()`
- `TestAzureFunctionConnectivity()`
- `GetAvailableInvoicesForDebugging()`

### 9.3 Escalation Procedures

#### Level 1: User Support

- Check submission log
- Verify customer data completeness
- Retry submission

#### Level 2: Developer Support

- Debug JSON generation
- Check Azure Function logs
- Analyze LHDN API responses

#### Level 3: External Support

- Contact LHDN support (for API issues)
- Contact Microsoft (for BC platform issues)
- Contact Azure support (for Azure Function issues)

---

## 10. Maintenance & Support

### 10.1 Regular Maintenance Tasks

#### Weekly

- [ ] Review submission log for errors
- [ ] Check Azure Function health
- [ ] Monitor LHDN API rate limits

#### Monthly

- [ ] Review and archive old submission logs (>6 months)
- [ ] Check certificate expiry dates
- [ ] Update LHDN API credentials if rotated
- [ ] Review Azure Function costs

#### Quarterly

- [ ] Security audit (check for exposed secrets)
- [ ] Performance review (submission times)
- [ ] User feedback review
- [ ] Update documentation

### 10.2 Certificate Renewal

**CRITICAL**: Digital certificate expires annually

#### Renewal Process

1. **60 days before expiry**: Request new certificate from JOTEX
2. **30 days before expiry**: Upload new certificate to Azure Key Vault
3. **Update Azure Function**: Point to new certificate
4. **Test in PreProd**: Verify signing works with new certificate
5. **Deploy to Production**: Update production Azure Function
6. **Verify**: Test production submission

#### Certificate Storage

- **Current Location**: Azure Key Vault (recommended) or Azure Function App Settings
- **Backup**: Store encrypted copy in secure location
- **Access**: Restricted to admins only

### 10.3 Monitoring & Alerts

#### Key Metrics to Monitor

- **Submission Success Rate**: Should be >98%
- **Average Processing Time**: Should be <5 seconds
- **Azure Function Availability**: Should be >99.9%
- **LHDN API Response Time**: Should be <2 seconds

#### Alerting Setup (Recommended)

```text
Alert 1: Submission Failure Rate >5% (1 hour window)
  └─▶ Notify: Development team
  └─▶ Action: Investigate immediately

Alert 2: Azure Function Errors >10 (1 hour window)
  └─▶ Notify: DevOps team
  └─▶ Action: Check Azure Function health

Alert 3: Certificate Expiry <30 days
  └─▶ Notify: Admin team
  └─▶ Action: Initiate renewal process
```

### 10.4 Support Contacts

#### Internal Contacts

- **Previous Developer**: [Name] - [Email]
- **BC Administrator**: [Name] - [Email]
- **Azure Administrator**: [Name] - [Email]

#### External Contacts

- **LHDN Support**: <https://myinvois.hasil.gov.my/support>
- **Microsoft BC Support**: [Support contract details]
- **Azure Support**: [Support contract details]

### 10.5 Knowledge Base

#### Documentation Locations

- **This Handover Doc**: `HANDOVER.md`
- **System Documentation**: `MyInvois_LHDN_eInvoice_System_Documentation.md`
- **Developer Guide**: `MyInvois_LHDN_Developer_Guide.md`
- **API Integration Guide**: `MyInvois_LHDN_API_Integration_Guide.md`
- **Troubleshooting Guide**: `MyInvois_LHDN_Troubleshooting_Guide.md`

#### External Resources

- **LHDN SDK**: <https://sdk.myinvois.hasil.gov.my/>
- **Azure Function Reference**: <https://github.com/KalvinChua/Jotex-eInvoice-Azure>
- **UBL 2.1 Specification**: <https://docs.oasis-open.org/ubl/UBL-2.1.html>

---

## Appendix A: Quick Reference

### Key File Locations

```text
Jotex-BC-eInvoice/
├── Cod50302.eInvoiceJSONGenerator.al    # Main logic
├── Cod50310.eInvoiceAzureFunctionClient.al
├── Cod50312.eInvoiceSubmissionStatus.al
├── Tab50300.eInvoiceSetup.al             # Configuration
├── Tab50312.eInvoiceSubmissionLog.al     # Audit log
├── Pag-Ext50306.eInvPostedSalesInvoiceExt.al
└── app.json                              # Extension metadata
```

### Key Procedures

```al
// Submit invoice
Cod50302.GetSignedInvoiceAndSubmitToLHDN(SalesInvoiceHeader, LhdnResponse)

// Generate JSON only
Cod50302.GenerateEInvoiceJson(SalesInvoiceHeader, false)

// Test connectivity
Cod50302.TestAzureFunctionConnectivity(AzureFunctionUrl)

// Debug payload
Cod50302.DownloadAzureFunctionPayloadForDebugging(DocType, DocNo, Setup)
```

### Configuration Locations

- **eInvoice Setup**: Search "eInvoice Setup Card" in BC
- **Azure Function URL**: eInvoice Setup → Azure Function URL field
- **LHDN Credentials**: eInvoice Setup → Client ID / Client Secret fields
- **Environment Switch**: eInvoice Setup → Environment field (PREPROD | PRODUCTION)

---

## Appendix B: Glossary

- **LHDN**: Lembaga Hasil Dalam Negeri (Inland Revenue Board of Malaysia)
- **MyInvois**: LHDN's e-Invoice platform
- **UBL**: Universal Business Language (XML/JSON standard for invoices)
- **TIN**: Tax Identification Number
- **XAdES**: XML Advanced Electronic Signatures
- **P12**: PKCS#12 certificate format
- **Submission UID**: LHDN's unique identifier for a submission batch
- **Document UUID**: LHDN's unique identifier for a specific document
- **longId**: LHDN's long-form document identifier (used for QR codes)

---

### End of Handover Documentation

> **Next Steps**: Complete the [Project Takeover Checklist](#2-project-takeover-checklist) and schedule knowledge transfer sessions with the previous developer.

