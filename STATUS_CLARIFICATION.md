# LHDN MyInvois Status Clarification

## Overview

The LHDN MyInvois system uses **two different types of statuses** that serve different purposes in the e-invoice lifecycle. This document clarifies the distinction between these status types.

## Status Types

### 1. Submission Status (Initial Submission Response)

**When:** Set during the initial submission of an invoice to LHDN MyInvois API

**Purpose:** Indicates whether LHDN successfully received and accepted the submission for processing

**Possible Values:**
- `'Submitted'` - LHDN successfully received the submission and accepted it for processing
- `'Submission Failed'` - LHDN rejected the submission due to validation errors or API issues

**Where Set:**
- `SalesInvoiceHeader."eInvoice Validation Status"` field
- `eInvoice Submission Log.Status` field (during initial submission)

**API Endpoint:** POST /api/v1.0/documentsubmissions

### 2. Batch Processing Status (Get Submission API Response)

**When:** Retrieved when checking the status of a previously submitted invoice

**Purpose:** Indicates the current processing status of the submitted documents

**Possible Values:**
- `'valid'` - Document has been validated and is valid
- `'invalid'` - Document has validation errors
- `'in progress'` - Document is still being processed
- `'partially valid'` - Some documents in batch are valid, others have issues

**Where Retrieved:** LHDN Get Submission API response (`overallStatus` field)

**API Endpoint:** GET /api/v1.0/documentsubmissions/{submissionUid}

## Status Flow

```
1. Initial Submission
   ↓
   POST /api/v1.0/documentsubmissions
   ↓
   Response: "Submitted" (if accepted) or "Submission Failed" (if rejected)
   ↓
   Status stored in: SalesInvoiceHeader."eInvoice Validation Status"
   ↓
2. Status Check (Later)
   ↓
   GET /api/v1.0/documentsubmissions/{submissionUid}
   ↓
   Response: "valid", "invalid", "in progress", or "partially valid"
   ↓
   Status stored in: eInvoice Submission Log.Status (updated)
```

## Why You See "Accepted" vs Expected LHDN Statuses

### The Issue
You were seeing "Accepted" status because:

1. **Initial Submission** → LHDN returns "Accepted" (meaning submission was received successfully)
2. **Status Check** → You expected to see LHDN batch processing statuses (`valid`, `invalid`, etc.)

### The Solution
The system now properly distinguishes between:

- **Submission Status**: `'Submitted'` (initial acceptance) vs `'Submission Failed'` (initial rejection)
- **Processing Status**: `'valid'`, `'invalid'`, `'in progress'`, `'partially valid'` (batch processing results)

## Implementation Changes

### Updated Status Values

**Before:**
- Initial submission success: `'Accepted'`
- Initial submission failure: `'Rejected'`

**After:**
- Initial submission success: `'Submitted'`
- Initial submission failure: `'Submission Failed'`

### Code Changes Made

1. **`Cod50302.eInvoiceJSONGenerator.al`**:
   - Line 2344: Changed `'Accepted'` to `'Submitted'`
   - Line 2157: Changed `'Rejected'` to `'Submission Failed'`
   - Added comments explaining the distinction

2. **Status Checking**:
   - `Cod50312.eInvoiceSubmissionStatus.al` and `Pag50316.eInvoiceSubmissionLog.al` already correctly handle LHDN batch processing statuses
   - Manual status updates use official LHDN values

## Best Practices

### For Users
1. **Initial Submission**: Look for "Submitted" status to confirm LHDN received your invoice
2. **Status Monitoring**: Use "Refresh Status" to get current processing status (`valid`, `invalid`, etc.)
3. **Manual Updates**: Use "Manual Status Update" when API calls are blocked

### For Developers
1. **Submission Status**: Use for immediate feedback on submission success/failure
2. **Processing Status**: Use for monitoring long-term processing results
3. **Status Updates**: Always use official LHDN API values for processing statuses

## Troubleshooting

### Common Questions

**Q: Why do I see "Submitted" instead of "Accepted"?**
A: "Submitted" indicates LHDN accepted your submission for processing. "Accepted" was confusing because it suggested final approval.

**Q: When should I check the processing status?**
A: Wait 3-5 seconds after submission, then use "Refresh Status" to get the current processing status.

**Q: What does "in progress" mean?**
A: LHDN is still processing your documents. Check again later for final status.

**Q: What's the difference between "Submitted" and "valid"?**
A: "Submitted" = LHDN received your invoice. "Valid" = LHDN processed and approved your invoice.

## API Documentation Reference

- **Submission API**: POST /api/v1.0/documentsubmissions
- **Status API**: GET /api/v1.0/documentsubmissions/{submissionUid}
- **Rate Limit**: 300 RPM per Client ID
- **Recommended Interval**: 3-5 seconds between status checks 