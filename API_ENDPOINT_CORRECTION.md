# API Endpoint Correction for e-Invoice Cancellation

## Issue Identified
The cancellation implementation was using an incorrect API endpoint pattern based on initial assumptions.

## Incorrect Implementation
```
PUT /api/v1.0/documents/{uuid}/cancel
Payload: {"reason": "cancellation reason"}
```

## Correct LHDN API Specification  
According to the official LHDN MyInvois API documentation:

```
PUT /api/v1.0/documents/state/{UUID}/state
```

### Request Payload
```json
{
  "status": "cancelled",
  "reason": "cancellation reason"
}
```

### Parameters
- **status** (String, Mandatory): Must be "cancelled" to cancel previously issued document
- **reason** (String, Mandatory): Reason for cancelling the document (limited to 300 characters)

## Code Changes Made

### Updated API URL Pattern
**Before:**
```al
ApiUrl := StrSubstNo('https://preprod-api.myinvois.hasil.gov.my/api/v1.0/documents/%1/cancel', DocumentUUID)
```

**After:**
```al
ApiUrl := StrSubstNo('https://preprod-api.myinvois.hasil.gov.my/api/v1.0/documents/state/%1/state', DocumentUUID)
```

### Updated Request Payload
**Before:**
```al
JsonObj.Add('reason', CancellationReason);
```

**After:**
```al
JsonObj.Add('status', 'cancelled');
JsonObj.Add('reason', CancellationReason);
```

## Impact
- **Compliance**: Now follows the official LHDN MyInvois API specification exactly
- **Functionality**: Cancellation requests will now use the correct endpoint
- **Reliability**: Improved success rate for cancellation operations
- **Future-proof**: Aligned with official API documentation

## Testing Recommendations
1. Test cancellation with a valid submitted e-Invoice
2. Verify the API accepts the new payload structure
3. Check that LHDN properly processes the cancellation status
4. Validate submission log updates reflect the cancellation

## Files Updated
- `Cod50305.eInvSalesInvPostingSub.al` - Updated cancellation procedure
- `CANCELLATION_IMPLEMENTATION.md` - Updated API documentation

## Technical Notes
- The HTTP method remains PUT
- Authentication headers remain unchanged
- Response handling logic remains the same
- Error handling and telemetry logging unchanged
