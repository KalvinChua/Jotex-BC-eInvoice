# Enhanced Azure Function Integration with Direct LHDN Submission

## Overview

This implementation provides a complete workflow where Business Central:
1. **Generates** unsigned eInvoice JSON
2. **Sends** to Azure Function for digital signing only
3. **Receives** signed payload from Azure Function
4. **Submits** directly to LHDN MyInvois API from Business Central

## Architecture Benefits

### 🎯 **Azure Function Focus**
- **Single Responsibility**: Azure Function only handles digital signing
- **Simplified Logic**: No complex LHDN API integration in Azure
- **Cost Effective**: Reduced Azure Function execution time and complexity

### 🔐 **Business Central Control**
- **Direct LHDN Integration**: Full control over LHDN API submission
- **Token Management**: Business Central manages LHDN authentication tokens
- **Error Handling**: Comprehensive error handling and retry logic
- **Environment Management**: Automatic PREPROD/PROD environment switching

## Implementation Details

### 📦 **Enhanced Payload Structure (to Azure Function)**

```json
{
  "unsignedJson": "<original_einvoice_json>",
  "invoiceType": "01",
  "environment": "PREPROD", // or "PROD"
  "submissionId": "<unique_guid>",
  "metadata": {
    "correlationId": "<unique_guid>",
    "timestamp": "2024-01-15T10:30:45Z",
    "source": "BusinessCentral",
    "version": "BC26.0",
    "user": {
      "sessionId": "<session_guid>",
      "userId": "user@company.com",
      "companyName": "Company Name",
      "tenantId": "<tenant_guid>"
    },
    "environment": {
      "environmentType": "Production",
      "region": "Malaysia",
      "applicationVersion": "BC26.0"
    }
  }
}
```

### 📥 **Expected Azure Function Response**

```json
{
  "success": true,
  "lhdnPayload": {
    "documents": [
      {
        "format": "JSON",
        "document": "<signed_invoice_json>",
        "documentHash": "<calculated_hash>",
        "codeNumber": "<invoice_number>"
      }
    ]
  },
  "metadata": {
    "signedAt": "2024-01-15T10:30:45Z",
    "correlationId": "<same_as_request>"
  }
}
```

## Code Implementation

### 🔧 **New Methods Added**

#### 1. **GetSignedInvoiceAndSubmitToLHDN()**
Complete workflow method that:
- Generates unsigned JSON
- Calls Azure Function for signing
- Submits to LHDN API
- Returns success/failure with response

#### 2. **SubmitToLhdnApi()**
Direct LHDN API submission:
- Handles PREPROD/PROD environment switching
- Manages OAuth2 token authentication
- Comprehensive error handling

#### 3. **GetLhdnAccessToken()**
LHDN authentication management:
- Environment-aware token URLs
- Automatic token refresh and storage
- Error handling for authentication failures

#### 4. **BuildAzureFunctionPayload()**
Enhanced payload builder:
- Environment detection from setup
- Rich metadata for tracking
- User and system context

### 🎛️ **Page Action Integration**

New action on Posted Sales Invoice page:
```al
action(SignAndSubmitToLHDN)
{
    ApplicationArea = All;
    Caption = 'Sign & Submit to LHDN';
    Image = ElectronicDoc;
    Promoted = true;
    PromotedCategory = Process;
    PromotedIsBig = true;
    ToolTip = 'Sign the invoice via Azure Function and submit directly to LHDN MyInvois API';
}
```

## Setup Requirements

### 1. **eInvoice Setup Configuration**

| Field | Purpose | Example |
|-------|---------|---------|
| **Azure Function URL** | Your signing function endpoint | `https://your-func.azurewebsites.net/api/eInvSigning` |
| **Client ID** | LHDN API client ID | `b7c599b3-b78a-4994-aaaa-1e0be7c5d1d9` |
| **Client Secret** | LHDN API client secret | `2aa7bbc5-42ab-464d-b905-37b4b799f7b8` |
| **Environment** | PREPROD or Production | `Preprod` |

### 2. **Azure Function Requirements**

Your Azure Function should:
- Accept the enhanced payload structure
- Return `success: true` with `lhdnPayload` object
- Handle error cases with `success: false` and `error` message

## Usage Examples

### 📋 **From Business Central**

```al
var
    eInvoiceGenerator: Codeunit "eInvoice JSON Generator";
    LhdnResponse: Text;
    Success: Boolean;
begin
    // Complete workflow - signing + submission
    Success := eInvoiceGenerator.GetSignedInvoiceAndSubmitToLHDN(SalesInvoiceHeader, LhdnResponse);
    
    if Success then
        Message('Invoice successfully submitted to LHDN: %1', LhdnResponse)
    else
        Error('Submission failed: %1', LhdnResponse);
end;
```

### 🔄 **Workflow Steps**

1. **User clicks "Sign & Submit to LHDN"**
2. **System generates unsigned JSON** from Sales Invoice
3. **Payload sent to Azure Function** with metadata
4. **Azure Function signs document** and returns LHDN payload
5. **Business Central gets LHDN token** (cached if valid)
6. **Direct submission to LHDN API** with signed payload
7. **Success/error message** displayed to user

## Environment Handling

### 🌍 **Automatic Environment Detection**

```al
// Environment URLs automatically selected based on setup
if eInvoiceSetup.Environment = eInvoiceSetup.Environment::Preprod then begin
    TokenUrl := 'https://preprod-api.myinvois.hasil.gov.my/connect/token';
    LhdnApiUrl := 'https://preprod-api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions';
end else begin
    TokenUrl := 'https://api.myinvois.hasil.gov.my/connect/token';
    LhdnApiUrl := 'https://api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions';
end;
```

## Error Handling

### 🚨 **Comprehensive Error Management**

1. **Azure Function Errors**:
   - Connection failures
   - Signing failures
   - Invalid responses

2. **LHDN API Errors**:
   - Authentication failures
   - Validation errors
   - Rate limiting

3. **Configuration Errors**:
   - Missing setup values
   - Invalid URLs
   - Token expiration

### 📊 **Error Messages**

- **Setup Issues**: `"eInvoice Setup not found. Please configure the Azure Function URL."`
- **Azure Function**: `"Azure Function signing failed: [specific error]"`
- **LHDN API**: `"LHDN API error 400: [validation details]"`
- **Authentication**: `"Failed to obtain LHDN access token"`

## Benefits Summary

### ✅ **Advantages of This Approach**

1. **🎯 Simplified Azure Function**: Focus only on signing, not LHDN integration
2. **🔐 Better Security**: LHDN credentials stay in Business Central
3. **💰 Cost Effective**: Reduced Azure Function execution time
4. **🔄 Better Control**: Full control over LHDN submission process
5. **📊 Enhanced Monitoring**: Rich metadata and correlation IDs
6. **🌍 Environment Aware**: Automatic PREPROD/PROD switching
7. **⚡ Improved Performance**: Direct API calls without intermediary
8. **🛡️ Robust Error Handling**: Comprehensive error management

This enhanced integration provides a production-ready, secure, and efficient solution for LHDN MyInvois digital signing and submission directly from Business Central.
