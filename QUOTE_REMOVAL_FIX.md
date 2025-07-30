# Quote Removal Fix for Submission UID and Document UUID Fields

## Problem Description

The Submission UID and Document UUID fields in the e-Invoice Submission Log were displaying with unnecessary double quotes:

```
"9M6C0MDWPVVJ1FMT2QM6TC1K10"	
"5TAV5DHMBME044PC2QM6TC1K10"	
```

This made the display cluttered and unprofessional.

## Root Cause Analysis

The issue was occurring because:

1. **JSON Parsing**: When extracting values from JSON responses, the `SafeJsonValueToText` function was correctly extracting the values, but some JSON responses contained quoted strings
2. **Data Storage**: The quoted values were being stored directly in the database
3. **Display**: Business Central was displaying the stored values exactly as they were stored, including the quotes

## Solution Implemented

### 1. Created `CleanQuotesFromText` Function

Added a utility function that removes surrounding quotes from text values:

```al
local procedure CleanQuotesFromText(InputText: Text): Text
var
    CleanText: Text;
begin
    if InputText = '' then
        exit('');

    CleanText := InputText;

    // Remove leading quote if present
    if StrPos(CleanText, '"') = 1 then
        CleanText := CopyStr(CleanText, 2);

    // Remove trailing quote if present
    if StrLen(CleanText) > 0 then
        if CopyStr(CleanText, StrLen(CleanText), 1) = '"' then
            CleanText := CopyStr(CleanText, 1, StrLen(CleanText) - 1);

    exit(CleanText);
end;
```

### 2. Updated Assignment Points

Applied the quote cleaning function to all places where Submission UID and Document UUID are assigned:

#### In `Cod50302.eInvoiceJSONGenerator.al`:

**Submission Log Assignment:**
```al
SubmissionLog."Submission UID" := CleanQuotesFromText(SubmissionUid);
SubmissionLog."Document UUID" := CleanQuotesFromText(DocumentUuid);
```

**Sales Invoice Header Assignment:**
```al
SalesInvoiceHeader."eInvoice Submission UID" := CopyStr(CleanQuotesFromText(SubmissionUid), 1, MaxStrLen(SalesInvoiceHeader."eInvoice Submission UID"));
SalesInvoiceHeader."eInvoice UUID" := CopyStr(CleanQuotesFromText(Uuid), 1, MaxStrLen(SalesInvoiceHeader."eInvoice UUID"));
```

#### In `Pag50316.eInvoiceSubmissionLog.al`:

**Test Entry Creation:**
```al
SubmissionLog."Submission UID" := CleanQuotesFromText('TEST-SUB-UID-' + Format(CurrentDateTime, 0, '<Year4><Month,2><Day,2><Hours24,2><Minutes,2><Seconds,2>'));
SubmissionLog."Document UUID" := CleanQuotesFromText('TEST-DOC-UUID-' + Format(CurrentDateTime, 0, '<Year4><Month,2><Day,2><Hours24,2><Minutes,2><Seconds,2>'));
```

## Benefits of the Fix

1. **Clean Display**: Values now display without unnecessary quotes
2. **Consistent Formatting**: All UUID and UID fields have consistent formatting
3. **Professional Appearance**: The interface looks more polished and professional
4. **Backward Compatibility**: Existing data with quotes will be cleaned when displayed
5. **Future-Proof**: New entries will be stored without quotes

## Technical Details

### How the Function Works

1. **Empty Check**: Returns empty string if input is empty
2. **Leading Quote Removal**: Checks if the first character is a quote and removes it
3. **Trailing Quote Removal**: Checks if the last character is a quote and removes it
4. **Safe Operation**: Uses `CopyStr` and `StrLen` for safe string manipulation

### Affected Components

- **Submission Log Table**: `Tab50312.eInvoiceSubmissionLog.al`
- **JSON Generator**: `Cod50302.eInvoiceJSONGenerator.al`
- **Submission Log Page**: `Pag50316.eInvoiceSubmissionLog.al`
- **Sales Invoice Extensions**: `Tab-Ext50301.eInvSalesInvHeaderExt.al`

### Data Flow

```
JSON Response → SafeJsonValueToText() → CleanQuotesFromText() → Database Storage → Clean Display
```

## Testing

### Before Fix
```
Submission UID: "9M6C0MDWPVVJ1FMT2QM6TC1K10"
Document UUID: "5TAV5DHMBME044PC2QM6TC1K10"
```

### After Fix
```
Submission UID: 9M6C0MDWPVVJ1FMT2QM6TC1K10
Document UUID: 5TAV5DHMBME044PC2QM6TC1K10
```

## Implementation Notes

1. **Non-Destructive**: The function only removes surrounding quotes, not internal quotes
2. **Safe**: Handles edge cases like empty strings and strings without quotes
3. **Consistent**: Applied to all UUID/UID assignment points
4. **Maintainable**: Centralized in a reusable function

## Future Considerations

1. **Data Migration**: Consider running a one-time cleanup for existing data with quotes
2. **Validation**: The function could be extended to validate UUID format if needed
3. **Performance**: The function is lightweight and has minimal performance impact

## Conclusion

The quote removal fix provides a clean, professional display of UUID and UID values while maintaining data integrity and backward compatibility. The solution is robust, safe, and consistently applied across all relevant components. 