# LHDN API Status Values

## Official LHDN MyInvois API Status Values

According to the LHDN MyInvois API documentation, the following are the official status values for batch processing:

### Primary Status Values

1. **`valid`** - Document passed all validations
   - The document has been successfully validated by LHDN
   - All required fields and business rules are satisfied
   - Document is ready for further processing

2. **`invalid`** - Document failed validations
   - The document has failed one or more validations
   - Contains errors that need to be corrected
   - Cannot proceed until issues are resolved

3. **`in progress`** - Document is being processed
   - The document is currently being processed by LHDN systems
   - Status will change to `valid` or `invalid` when processing completes
   - May take several minutes to hours depending on system load

4. **`partially valid`** - Some documents valid, others not
   - For batch submissions with multiple documents
   - Some documents in the batch are valid, others have issues
   - Requires review of individual document statuses

### Status Flow

```
Submission → in progress → valid/invalid/partially valid
```

### Implementation Notes

- **Case Sensitivity**: Status values are lowercase as per LHDN API specification
- **Spacing**: "in progress" uses a space (not "inprogress")
- **Consistency**: All status values match exactly with LHDN API responses
- **Fallback**: Unknown statuses are marked as "Unknown"

### API Response Format

```json
{
  "submissionUid": "string",
  "overallStatus": "valid|invalid|in progress|partially valid",
  "documentCount": 1,
  "dateTimeReceived": "2024-01-01T00:00:00Z",
  "documentSummary": [
    {
      "uuid": "string",
      "internalId": "string",
      "status": "valid|invalid|in progress"
    }
  ]
}
```

### Business Rules

1. **Status Persistence**: Once a document reaches `valid` or `invalid`, it typically doesn't change
2. **Processing Time**: `in progress` status can last from minutes to hours
3. **Batch Handling**: `partially valid` only applies to multi-document submissions
4. **Error Handling**: `invalid` status includes specific error details in the response

### User Interface Considerations

- **Display**: Status values are shown exactly as received from LHDN API
- **Filtering**: Users can filter by any of the four status values
- **Sorting**: Status values are sorted alphabetically in dropdowns
- **Color Coding**: Consider visual indicators for different statuses

### Error Scenarios

1. **Network Issues**: Returns "Unknown" status
2. **API Errors**: Returns "Unknown" status with error details
3. **Timeout**: Returns "Unknown" status with timeout message
4. **Invalid Response**: Returns "Unknown" status with parsing error

### Best Practices

1. **Polling**: Check status every 3-5 seconds for `in progress` documents
2. **Retry Logic**: Implement exponential backoff for failed requests
3. **User Feedback**: Provide clear explanations for each status
4. **Audit Trail**: Log all status changes with timestamps
5. **Error Handling**: Gracefully handle unknown or unexpected statuses

### Integration Guidelines

- **API Version**: Use latest LHDN API version for status values
- **Rate Limiting**: Respect 300 RPM limit for status checks
- **Authentication**: Ensure valid access tokens for status requests
- **Logging**: Log all status check attempts and responses
- **Monitoring**: Monitor for status check failures and timeouts 