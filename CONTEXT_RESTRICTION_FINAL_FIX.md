# eInvoice Context Restriction Solution

## Problem Summary

**Error:** "The requested operation cannot be performed in this context"
- **Location:** `Cod50312.eInvoiceSubmissionStatus.al` line 57
- **Trigger:** `Pag50316.eInvoiceSubmissionLog.al` RefreshStatus action
- **Root Cause:** HTTP operations are restricted in certain Business Central contexts

## Solution Overview

The solution implements a multi-layered approach to handle context restrictions gracefully:

### 1. Enhanced RefreshStatus Action

The `RefreshStatus` action now includes:

- **Pre-flight Context Test:** Tests HTTP access before attempting API calls
- **Context-Aware Alternatives:** Offers different options when restrictions are detected
- **Fallback Methods:** Uses local data analysis when HTTP operations fail
- **Background Job Option:** Creates background jobs for processing

### 2. New Alternative Actions

#### RefreshStatusLocal Action
- **Purpose:** Status refresh using only local data analysis
- **Benefits:** No HTTP calls, works in all contexts
- **Usage:** When context restrictions prevent API calls

#### TestContextAccess Action
- **Purpose:** Diagnose context access issues and setup configuration
- **Benefits:** Helps troubleshoot permission and context problems
- **Usage:** Before attempting status refresh operations

#### BackgroundStatusRefresh Action
- **Purpose:** Process status updates in background jobs
- **Benefits:** Avoids context restrictions by running in background
- **Usage:** When immediate processing is not required

### 3. Enhanced Error Handling

The codeunit now includes:

- **Context Detection:** Automatically detects context restrictions
- **Graceful Degradation:** Falls back to local analysis when needed
- **User-Friendly Messages:** Clear explanations of issues and solutions
- **Multiple Recovery Options:** Background jobs, local analysis, context testing

## Implementation Details

### Modified Files

1. **Pag50316.eInvoiceSubmissionLog.al**
   - Enhanced `RefreshStatus` action with context testing
   - Added `RefreshStatusLocal` action for local-only analysis
   - Added `TestContextAccess` action for diagnostics

2. **Cod50312.eInvoiceSubmissionStatus.al**
   - Enhanced error handling in `CheckSubmissionStatus`
   - Improved `TrySendHttpRequest` with context awareness
   - Added comprehensive testing methods

### Key Changes

#### 1. Context Testing
```al
// First, test if HTTP operations are allowed in this context
TestResult := SubmissionStatusCU.TestSubmissionStatusAccess();

if TestResult.Contains('✗ Access token not available') or
   TestResult.Contains('Context restrictions') then begin
    // Offer alternatives when restrictions detected
end;
```

#### 2. Alternative Processing
```al
// Use the alternative method first to avoid context restrictions
if SubmissionStatusCU.CheckSubmissionStatusAlternative(Rec."Submission UID", SubmissionDetails) then begin
    // Update with local data analysis
    Rec."Status" := 'Local Analysis';
    // ... update fields
end else begin
    // Try direct API call as fallback
    ApiSuccess := SubmissionStatusCU.CheckSubmissionStatus(Rec."Submission UID", SubmissionDetails);
end;
```

#### 3. Background Job Creation
```al
// Create background job for processing
CreateBackgroundJobForStatusRefresh();
Message('Background job created for status refresh.');
```

## Usage Instructions

### For Users

1. **Normal Operation:** Use "Refresh Status" - it will automatically detect context restrictions
2. **Context Restrictions:** When prompted, choose "Use Background Job (Recommended)" or "Refresh Status (Local Analysis)"
3. **Local Analysis:** Use "Refresh Status (Local Analysis)" for immediate results without API calls
4. **Background Processing:** Use "Background Status Refresh" for processing in background jobs
5. **Troubleshooting:** Use "Test Context Access" to diagnose setup and permission issues

### For Administrators

1. **Monitor Job Queue:** Check for background jobs in Job Queue
2. **Review Logs:** Monitor eInvoice Submission Log for status updates
3. **Permissions:** Ensure users have appropriate permissions for HTTP operations

## Error Resolution

### Common Scenarios

1. **Context Restriction Detected**
   - **Solution:** Use "Refresh Status (Local Analysis)" or "Background Status Refresh"
   - **Prevention:** Run from appropriate context (page actions, not background)

2. **Access Token Not Available**
   - **Solution:** Check eInvoice Setup configuration
   - **Prevention:** Verify Client ID and Client Secret in setup

3. **Network Connectivity Issues**
   - **Solution:** Check internet connectivity and firewall settings
   - **Prevention:** Ensure LHDN API endpoints are accessible

### Troubleshooting Steps

1. **Run Context Test:** Use "Test Context Access" action to check setup and permissions
2. **Check Setup:** Verify eInvoice Setup configuration
3. **Try Local Analysis:** Use "Refresh Status (Local Analysis)"
4. **Use Background Processing:** Use "Background Status Refresh" for background job processing
5. **Check Permissions:** Verify user has HTTP operation permissions

## Benefits

1. **Reliability:** Works in all contexts, not just unrestricted ones
2. **User Experience:** Clear options and helpful error messages
3. **Flexibility:** Multiple approaches for different scenarios
4. **Diagnostics:** Built-in testing and troubleshooting tools
5. **Compliance:** Respects LHDN API rate limits and recommendations

## Technical Notes

- **Rate Limiting:** Respects LHDN's 300 RPM limit
- **Error Handling:** Comprehensive error capture and reporting
- **Logging:** Detailed logging for troubleshooting
- **Performance:** Optimized for minimal impact on system performance
- **Security:** Proper authentication and authorization handling

## API Reference

- **LHDN Get Submission API:** https://sdk.myinvois.hasil.gov.my/einvoicingapi/06-get-submission/
- **Rate Limits:** 300 RPM per Client ID
- **Recommended Intervals:** 3-5 seconds between requests

## Support Information

When requesting support, provide:
- Error message details
- Context where error occurred
- Results from "Test Context Access" action
- Background job status (if applicable)
- User permissions and setup configuration 