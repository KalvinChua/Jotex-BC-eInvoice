# LHDN MyInvois API Compliance Implementation

## Overview
This document outlines the implementation of LHDN MyInvois API standards compliance in the e-Invoice Status Refresh functionality, based on the latest LHDN SDK documentation.

## LHDN Standards Implemented

### 1. Standard Header Parameters
**Reference**: https://sdk.myinvois.hasil.gov.my/standard-header-parameters/

#### Request Headers (Implemented)
- `Accept`: `application/json` - Defines content types client can accept
- `Accept-Language`: `en` - Preferred language for response (English)
- `Content-Type`: `application/json; charset=utf-8` - Message type definition
- `Authorization`: `Bearer <Token>` - Access token for authenticated calls
- `User-Agent`: `BusinessCentral-eInvoice/2.0` - Client identification
- `X-Correlation-ID`: `<GUID>` - Unique tracking identifier
- `X-Request-Source`: `BusinessCentral-StatusCheck` - Request source identification

#### Response Headers (Monitored)
- `correlationId` - Tracking identifier returned by LHDN
- `X-Rate-Limit-Limit` - Total request count limit
- `X-Rate-Limit-Remaining` - Remaining allowed requests
- `X-Rate-Limit-Reset` - Time when count resets

### 2. Standard Error Response Structure
**Reference**: https://sdk.myinvois.hasil.gov.my/standard-error-response/

#### Error Object Structure (Implemented)
```json
{
  "error": {
    "propertyName": "string",
    "propertyPath": "string", 
    "errorCode": "string",
    "error": "string",
    "errorMS": "string",
    "target": "string",
    "innerError": []
  }
}
```

#### Standard HTTP Status Codes (Handled)
- `400` - BadRequest/BadArgument
- `401` - Unauthorized (token issues)
- `403` - Forbidden (access denied)
- `404` - NotFound (submission not found)
- `429` - TooManyRequests (rate limiting)
- `500` - InternalServerError
- `503` - ServiceUnavailable

## Implementation Details

### Enhanced Error Parsing
- **Function**: `ParseErrorResponse`
- **Features**:
  - Parses LHDN standard error structure
  - Extracts `errorCode`, `error`, `errorMS` fields
  - Handles `propertyName`, `propertyPath`, `target` information
  - Processes `innerError` arrays for multiple validation errors
  - Provides bilingual error messages (English/Malay)
  - Includes LHDN documentation references

### Enhanced HTTP Request Handling
- **Function**: `TrySendHttpRequest`
- **Features**:
  - Implements LHDN standard headers
  - Handles rate limiting (HTTP 429) with proper retry logic
  - Provides correlation ID tracking for support issues
  - Context-aware error handling for Business Central restrictions
  - Comprehensive error messaging with LHDN references

### Status Refresh Functionality
- **Function**: `RefreshSubmissionLogStatusSafe`
- **Features**:
  - Context-safe operation with graceful fallbacks
  - Real-time status updates from LHDN API
  - Proper error handling and user guidance
  - Environment-aware URL construction (Preprod/Production)

## API Compliance Checklist

### Request Standards ✅
- [x] Standard headers implemented
- [x] Proper authorization with Bearer token
- [x] Correlation ID for request tracking
- [x] Accept/Content-Type headers set correctly
- [x] User-Agent identification included

### Response Handling ✅
- [x] Standard error structure parsing
- [x] HTTP status code handling
- [x] Rate limiting detection and handling
- [x] Correlation ID extraction for support
- [x] Bilingual error message support

### Business Logic ✅
- [x] Context-safe HTTP operations
- [x] Automatic retry with exponential backoff
- [x] Environment-aware endpoint selection
- [x] User-friendly error messages
- [x] Background processing fallback

## Error Handling Scenarios

### 1. Context Restrictions
- **Trigger**: HTTP operations blocked in UI context
- **Handling**: Graceful fallback with user guidance
- **User Experience**: Clear instructions for alternative actions

### 2. Rate Limiting (HTTP 429)
- **Trigger**: LHDN API rate limits exceeded
- **Handling**: Automatic retry with proper delays
- **User Experience**: Informative messages about rate limits

### 3. Network Issues
- **Trigger**: Connection timeouts or network errors
- **Handling**: Retry logic with increasing delays
- **User Experience**: Clear troubleshooting guidance

### 4. Authentication Issues (HTTP 401)
- **Trigger**: Invalid or expired access tokens
- **Handling**: Clear error messaging
- **User Experience**: Guidance on token refresh

### 5. Submission Not Found (HTTP 404)
- **Trigger**: Invalid submission UID
- **Handling**: Detailed error analysis
- **User Experience**: Suggestions for resolution

## Best Practices Implemented

### 1. Rate Limiting Compliance
- 300 RPM limit respected with 200ms delays
- Automatic handling of HTTP 429 responses
- Exponential backoff for retry attempts

### 2. Error Tracking
- Correlation ID generation and tracking
- Comprehensive error logging
- LHDN documentation references

### 3. User Experience
- Context-aware operation modes
- Clear, actionable error messages
- Progressive fallback options

### 4. Environment Management
- Automatic Preprod/Production detection
- Environment-specific URL construction
- Setup validation and error handling

## Integration Points

### Business Central Integration
- Seamless integration with existing e-Invoice setup
- Compatible with current table structures
- Background job support for context restrictions

### LHDN API Integration
- Full compliance with latest SDK standards
- Proper authentication and authorization
- Standard request/response handling

## Future Enhancements

### Potential Improvements
1. **Enhanced Rate Limiting**: Implement adaptive delays based on response headers
2. **Caching**: Add intelligent caching for frequently accessed submissions
3. **Bulk Operations**: Optimize batch status updates with pagination
4. **Monitoring**: Add detailed API call metrics and monitoring

### LHDN Updates Compatibility
- Implementation is designed to be forward-compatible
- Easy to update for new LHDN API versions
- Modular error handling for new error codes

## References

- [LHDN Standard Header Parameters](https://sdk.myinvois.hasil.gov.my/standard-header-parameters/)
- [LHDN Standard Error Response](https://sdk.myinvois.hasil.gov.my/standard-error-response/)
- [LHDN Get Submission API](https://sdk.myinvois.hasil.gov.my/einvoicingapi/06-get-submission/)
- [LHDN SDK Documentation](https://sdk.myinvois.hasil.gov.my/)

## Support and Troubleshooting

For issues related to LHDN API integration:
1. Check correlation ID in error messages
2. Verify environment settings (Preprod vs Production)
3. Ensure proper access token configuration
4. Reference LHDN documentation for specific error codes
5. Contact LHDN support with correlation ID for API issues

---
*Document Last Updated: August 1, 2025*
*Implementation Version: 1.0.0.32*
