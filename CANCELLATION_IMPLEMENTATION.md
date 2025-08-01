# e-Invoice Cancellation Implementation

## Overview
This document describes the implementation of e-Invoice cancellation functionality according to the LHDN MyInvois API specification. The cancellation feature allows users to cancel submitted and valid e-Invoices through the Business Central interface.

## Implementation Components

### 1. Database Changes
**File**: `Tab50312.eInvoiceSubmissionLog.al`
- Added `Cancellation Reason` field (Text[500]) to store the reason for cancellation
- Added `Cancellation Date` field (DateTime) to track when the cancellation occurred
- These fields are automatically populated when a cancellation is successful

### 2. Core Cancellation Logic
**File**: `Cod50305.eInvSalesInvPostingSub.al`
- Added `CancelEInvoiceDocument` procedure that implements the LHDN cancellation API
- Follows the API specification: `PUT /api/v1.0/documents/{uuid}/cancel`
- Validates that only valid/accepted invoices can be cancelled
- Updates submission log with cancellation details
- Provides comprehensive error handling and telemetry logging

### 3. User Interface
**File**: `Pag-Ext50306.eInvPostedSalesInvoiceExt.al`
- Added "Cancel e-Invoice" action in the Posted Sales Invoice page
- Provides user-friendly cancellation reason selection
- Includes confirmation dialog to prevent accidental cancellations
- Shows appropriate messages for different cancellation scenarios

### 4. Submission Log Updates
**Files**: 
- `Pag50315.eInvoiceSubmissionLogCard.al` - Added cancellation information group
- `Pag50316.eInvoiceSubmissionLog.al` - Added cancellation fields to list view

## API Integration Details

### Cancellation Request
- **Method**: PUT
- **URL**: `https://{environment}-api.myinvois.hasil.gov.my/api/v1.0/documents/state/{UUID}/state`
- **Headers**: 
  - `Content-Type: application/json`
  - `Authorization: Bearer {access_token}`
- **Payload**: 
  ```json
  {
    "status": "cancelled",
    "reason": "cancellation reason"
  }
  ```

### Prerequisites for Cancellation
1. Invoice must be previously submitted to LHDN
2. Invoice status must be "Valid" (accepted by LHDN)
3. Document UUID must be available in submission log
4. Valid access token required for API authentication

### Cancellation Reasons Available
1. Wrong buyer information
2. Incorrect invoice details
3. Duplicate invoice submission
4. Technical error during submission
5. Cancellation requested by buyer
6. Other business reason - Contact support for details

## Usage Instructions

### For Users
1. Navigate to Posted Sales Invoice page
2. Select an invoice that has been submitted to LHDN
3. Click "Cancel e-Invoice" action
4. Confirm the cancellation when prompted
5. Select an appropriate cancellation reason
6. The system will attempt to cancel the invoice via LHDN API
7. Success/failure message will be displayed
8. View cancellation details in submission log

### For Administrators
- Monitor cancellation telemetry via logs with event IDs:
  - `0000EIV03`: Successful cancellation
  - `0000EIV04`: Failed cancellation
- Review submission logs for cancellation tracking
- Cancellation is irreversible once processed by LHDN

## Error Handling

### Validation Checks
- Only JOTEX SDN BHD company can cancel invoices
- Invoice must have valid submission log entry
- Document UUID and Submission UID must be present
- Invoice status must be "Valid" (not already cancelled or rejected)

### API Error Scenarios
- Network connectivity issues
- Invalid access token
- Document not found in LHDN system
- Document already cancelled
- LHDN service unavailable

### User Feedback
- Clear error messages for different failure scenarios
- Success confirmation with cancellation details
- Updated submission log reflecting cancellation status

## Security Considerations
- Cancellation requires same authentication as submission
- Only valid/accepted invoices can be cancelled
- Cancellation action is logged for audit trail
- Confirmation dialog prevents accidental cancellations

## Testing Recommendations
1. Test cancellation with valid submitted invoice
2. Verify error handling for already cancelled invoices
3. Test with invalid document UUIDs
4. Verify submission log updates correctly
5. Test access token renewal scenarios
6. Validate different cancellation reasons

## Future Enhancements
- Batch cancellation functionality
- Cancellation approval workflow
- Enhanced reporting for cancelled invoices
- Integration with credit memo posting for business process alignment

## Technical Notes
- Cancellation updates the submission log status to "Cancelled"
- Original submission data is preserved for audit purposes
- API timeout set to 30 seconds
- Comprehensive telemetry logging for monitoring
- Thread-safe implementation with proper error handling
