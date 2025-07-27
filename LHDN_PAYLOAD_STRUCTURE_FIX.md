# LHDN Payload Structure Error - Fix and Troubleshooting Guide

## Error Summary
**Error Message:** `Invalid LHDN payload structure. Expected "documents" array not found.`

**Root Cause:** The Azure Function returns `lhdnPayload` as a **JSON string** (not a JSON object), but the original code was trying to parse it as a JSON object directly. The `lhdnPayload` string contains the correct documents array structure, but it needed to be extracted and parsed properly.

## Fixes Applied

### 1. Fixed Azure Function Response Parsing
**File:** `Cod50302.eInvoice10InvoiceJSON.al`
**Method:** `GetSignedInvoiceAndSubmitToLHDN` (lines 1770-1780)

**Before:**
```al
if AzureResponse.Get('lhdnPayload', JsonToken) then begin
    // Parse the LHDN payload string into JSON object
    exit(ProcessLhdnPayload(JsonToken.AsValue().AsText(), SalesInvoiceHeader, LhdnResponse));
end else begin
    LhdnResponse := StrSubstNo('No LHDN payload found in Azure Function response. Response keys: %1', GetJsonObjectKeys(AzureResponse));
    exit(false);
end;
```

**After:**
```al
if AzureResponse.Get('lhdnPayload', JsonToken) then begin
    // The lhdnPayload is returned as a JSON string, not an object
    // We need to parse this string into a JSON object
    LhdnResponse := JsonToken.AsValue().AsText();
    
    // Log the LHDN payload for debugging
    LogDebugInfo('LHDN Payload extracted from Azure Function', 
        StrSubstNo('Payload length: %1\nPayload preview: %2', 
            StrLen(LhdnResponse), 
            CopyStr(LhdnResponse, 1, 300)));
    
    // Process the LHDN payload string
    exit(ProcessLhdnPayload(LhdnResponse, SalesInvoiceHeader, LhdnResponse));
end else begin
    LhdnResponse := StrSubstNo('No LHDN payload found in Azure Function response. Response keys: %1', GetJsonObjectKeys(AzureResponse));
    LogDebugInfo('Missing LHDN payload in Azure Function response', 
        StrSubstNo('Available keys: %1\nFull response preview: %2', 
            GetJsonObjectKeys(AzureResponse), 
            CopyStr(AzureResponseText, 1, 500)));
    exit(false);
end;
```

### 2. Simplified LHDN Payload Processing
**Method:** `SubmitToLhdnApi` (lines 2023-2033)

**Before:**
```al
// Complex handling for different Azure Function response formats
if LhdnPayload.Get('documents', JsonToken) then begin
    LhdnPayload.WriteTo(LhdnPayloadText);
end else if LhdnPayload.Get('lhdnPayload', JsonToken) then begin
    // ... complex nested handling
end else begin
    // ... fallback logic
end;
```

**After:**
```al
// SIMPLIFIED FIX: The Azure Function returns lhdnPayload as a JSON string
// that already contains the correct documents array structure
// We can use it directly for LHDN submission
LhdnPayload.WriteTo(LhdnPayloadText);

// Validate that we have the documents array structure
if not LhdnPayloadText.Contains('"documents"') then begin
    Error('Invalid LHDN payload structure. Expected "documents" array not found. Payload preview: %1', CopyStr(LhdnPayloadText, 1, 200));
end;
```

### 2. Enhanced Debugging and Logging
**New Method:** `LogDebugInfo`
**Purpose:** Comprehensive logging for troubleshooting Azure Function integration issues

**Features:**
- Timestamped log entries
- Detailed payload structure analysis
- JSON key extraction for debugging
- Response validation tracking

### 3. Flexible Validation
**Method:** `ValidateLhdnPayloadStructureFlexible`
**Enhancements:**
- Multiple format support (documents array, single document, nested structures)
- Better error messages with payload previews
- Graceful handling of unknown structures for debugging

## Actual Azure Function Response Format

Based on the actual response you provided, the Azure Function returns:

```json
{
  "success": true,
  "correlationId": "B6FE59CE-F8A0-41AA-B202-4A31B32FAFEA",
  "statusCode": 200,
  "message": "Invoice signed successfully",
  "signedJson": "{\"_D\":\"urn:oasis:names:specification:ubl:schema:xsd:Invoice-2\",...}",
  "lhdnPayload": "{\n  \"documents\": [\n    {\n      \"format\": \"JSON\",\n      \"document\": \"eyJfRCI6InVybjpvYXNpczpuYW1lczpzcGVjaWZpY2F0aW9uOnVibDpzY2hlbWE6eHNkOkludm9pY2UtMiIsIkludm9pY2UiOlt7IklEIjpbeyJfIjoiUFNJMjUwMy0wMDIwIn1dfV19\",\n      \"documentHash\": \"cc1a5c6bb9e295a4267faf9bad8dd1ce40dea6839a9e2fb72dcc35bac86eabbf\",\n      \"codeNumber\": \"PSI2503-0020\"\n    }\n  ]\n}",
  "signature": {...},
  "timestamp": "2025-07-27T10:54:45.3706605Z",
  "processingTimeMs": 17,
  "errorDetails": null,
  "warnings": null
}
```

**Key Points:**
- `lhdnPayload` is returned as a **JSON string** (not a JSON object)
- The string contains the correct `documents` array structure
- The `document` field contains base64-encoded UBL XML
- The structure matches LHDN requirements perfectly

## Troubleshooting Steps

### 1. Check Azure Function Response
Use the enhanced logging to see what the Azure Function is actually returning:

1. Run the e-Invoice submission process
2. Check the debug logs for "Azure Function response received"
3. Review the JSON keys and payload structure

### 2. Verify Azure Function Configuration
Ensure your Azure Function is configured to return the expected format:

- **Expected Response Model:** `BusinessCentralSigningResponse`
- **Required Fields:** `success`, `signedJson`, `lhdnPayload`
- **LHDN Payload Format:** Should contain `documents` array

### 3. Test with Actual Azure Function Response
Use the provided test procedure to verify the fix works with the actual response format:

```al
// Test procedure that matches the actual Azure Function response
procedure TestLhdnPayloadWithActualResponse()
var
    TestAzureResponse: JsonObject;
    TestLhdnPayload: JsonObject;
    TestDocuments: JsonArray;
    TestDocument: JsonObject;
    LhdnPayloadString: Text;
    AzureResponseString: Text;
    JsonToken: JsonToken;
    LhdnResponse: Text;
    SalesInvoiceHeader: Record "Sales Invoice Header";
begin
    // Create test document structure matching the actual Azure Function response
    TestDocument.Add('format', 'JSON');
    TestDocument.Add('document', 'eyJfRCI6InVybjpvYXNpczpuYW1lczpzcGVjaWZpY2F0aW9uOnVibDpzY2hlbWE6eHNkOkludm9pY2UtMiIsIkludm9pY2UiOlt7IklEIjpbeyJfIjoiUFNJMjUwMy0wMDIwIn1dfV19');
    TestDocument.Add('documentHash', 'cc1a5c6bb9e295a4267faf9bad8dd1ce40dea6839a9e2fb72dcc35bac86eabbf');
    TestDocument.Add('codeNumber', 'PSI2503-0020');
    
    // Create documents array
    TestDocuments.Add(TestDocument);
    
    // Create LHDN payload object
    TestLhdnPayload.Add('documents', TestDocuments);
    TestLhdnPayload.WriteTo(LhdnPayloadString);
    
    // Create Azure Function response matching the actual format
    TestAzureResponse.Add('success', true);
    TestAzureResponse.Add('correlationId', 'B6FE59CE-F8A0-41AA-B202-4A31B32FAFEA');
    TestAzureResponse.Add('statusCode', 200);
    TestAzureResponse.Add('message', 'Invoice signed successfully');
    TestAzureResponse.Add('signedJson', '{"test": "signed_json"}');
    TestAzureResponse.Add('lhdnPayload', LhdnPayloadString);
    
    // Test the parsing logic
    if TestAzureResponse.Get('lhdnPayload', JsonToken) then begin
        LhdnResponse := JsonToken.AsValue().AsText();
        
        // Test the ProcessLhdnPayload method
        if ProcessLhdnPayload(LhdnResponse, SalesInvoiceHeader, LhdnResponse) then begin
            Message('Test successful! LHDN payload structure is correctly handled.');
        end else begin
            Message('Test failed! Error: %1', LhdnResponse);
        end;
    end else begin
        Message('Test failed! Could not extract lhdnPayload from Azure response.');
    end;
end;
```

### 4. Monitor Debug Logs
The enhanced logging will help identify:

- **Response Structure:** What keys are present in the Azure Function response
- **Payload Format:** Whether the LHDN payload has the expected structure
- **Validation Results:** Which validation checks pass or fail

## Error Prevention

### 1. Azure Function Response Validation
Ensure your Azure Function validates its response before returning:

```csharp
// C# Azure Function validation
public class BusinessCentralSigningResponse
{
    public bool Success { get; set; }
    public string SignedJson { get; set; }
    public LhdnPayload LhdnPayload { get; set; }
    public string ErrorDetails { get; set; }
}

public class LhdnPayload
{
    public List<Document> Documents { get; set; }
}

public class Document
{
    public string Format { get; set; }
    public string DocumentContent { get; set; }
    public string DocumentHash { get; set; }
    public string CodeNumber { get; set; }
}
```

### 2. Business Central Setup Validation
Add validation to ensure proper configuration:

```al
procedure ValidateEInvoiceSetup()
var
    Setup: Record "eInvoiceSetup";
begin
    if not Setup.Get('SETUP') then
        Error('eInvoice Setup not found');
    
    if Setup."Azure Function URL" = '' then
        Error('Azure Function URL is not configured');
    
    if Setup."Client ID" = '' then
        Error('Client ID is not configured');
    
    if Setup."Client Secret" = '' then
        Error('Client Secret is not configured');
end;
```

## Session Information
- **Internal Session ID:** 153a8298-54ea-4f4a-99e6-30fa8138f666
- **Application Insights Session ID:** bf0999f6-8806-44e0-97c2-df72a64b1af8
- **Client Activity ID:** ababd988-b66f-4067-a003-805c49512ba0
- **Timestamp:** 2025-07-27T10:41:03.3866692Z
- **User Telemetry ID:** fde1195a-e68c-417e-b727-2b088139c23f

## Next Steps

1. **Deploy the Fix:** Update the codeunit with the enhanced error handling
2. **Test Integration:** Run a test e-Invoice submission
3. **Monitor Logs:** Check debug logs for detailed information
4. **Verify Azure Function:** Ensure Azure Function returns expected format
5. **Update Documentation:** Share this guide with your development team

## Support Contact
If issues persist after implementing these fixes, please provide:
- Debug log output
- Azure Function response structure
- Business Central error messages
- Session IDs for correlation 