# Formatting Inconsistencies Report

## Overview
After reviewing the entire codebase, I found several formatting inconsistencies that should be standardized for better code quality and maintainability.

## Issues Found and Fixed

### ✅ **1. UUID Formatting Inconsistency - FIXED**

**Location:** `Pag-Ext50306.eInvPostedSalesInvoiceExt.al`
**Issue:** UUID was displayed in parentheses `(UUID: ...)` instead of on separate line
**Fix Applied:** Changed to `\\    UUID: ...` format

**Before:**
```al
FormattedResponse += StrSubstNo('• Invoice: %1 (UUID: %2)', InvoiceCodeNumber, Uuid);
```

**After:**
```al
FormattedResponse += StrSubstNo('• Invoice: %1\\    UUID: %2', InvoiceCodeNumber, Uuid);
```

### ✅ **2. Quote Cleanup Inconsistency - FIXED**

**Location:** `Cod50302.eInvoiceJSONGenerator.al`
**Issue:** Quotes not being cleaned from JSON values in success messages
**Fix Applied:** Added `CleanQuotesFromText()` to all JSON value extractions

**Before:**
```al
Uuid := SafeJsonValueToText(JsonToken);
InvoiceCodeNumber := SafeJsonValueToText(JsonToken);
```

**After:**
```al
Uuid := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
InvoiceCodeNumber := CleanQuotesFromText(SafeJsonValueToText(JsonToken));
```

## Remaining Formatting Patterns

### **Message String Concatenation Patterns**

The codebase uses several different patterns for message formatting:

#### **Pattern 1: Simple Concatenation**
```al
Message('Status refresh completed.' + '\\' + 'Updated %1 submissions.', UpdatedCount);
```

#### **Pattern 2: StrSubstNo with Multiple Line Breaks**
```al
MessageText := StrSubstNo('Token Status Test Results:' + '\\' + '\\' +
    'Current Status: %1' + '\\' +
    'Refresh Needed: %2' + '\\' + '\\' +
    'Testing automatic token retrieval...',
    TokenStatus,
    RefreshNeeded ? 'Yes' : 'No');
```

#### **Pattern 3: Complex Multi-line Messages**
```al
ConfirmMsg := StrSubstNo('This will:' + '\\' + '1. Generate unsigned eInvoice JSON' + '\\' + '2. Send to Azure Function for digital signing' + '\\' + '3. Submit signed invoice directly to LHDN MyInvois API' + '\\' + '\\' + 'Proceed with invoice %1?', Rec."No.");
```

## Recommendations for Standardization

### **1. Message Formatting Standards**

#### **A. Simple Messages (1-2 lines)**
Use Pattern 1:
```al
Message('Operation completed successfully.' + '\\' + 'Result: %1', Result);
```

#### **B. Multi-line Messages (3+ lines)**
Use Pattern 2:
```al
MessageText := StrSubstNo('Operation Results:' + '\\' + '\\' +
    'Status: %1' + '\\' +
    'Details: %2' + '\\' + '\\' +
    'Summary: %3',
    Status, Details, Summary);
```

#### **C. Confirmation Messages**
Use Pattern 3 but with consistent spacing:
```al
ConfirmMsg := StrSubstNo('This will:' + '\\' + 
    '1. Step one' + '\\' + 
    '2. Step two' + '\\' + 
    '3. Step three' + '\\' + '\\' + 
    'Proceed?');
```

### **2. Line Break Standards**

#### **A. Single Line Break**
Use: `'\\'`

#### **B. Double Line Break (Section Separator)**
Use: `'\\' + '\\'`

#### **C. Triple Line Break (Major Section Separator)**
Use: `'\\' + '\\' + '\\'`

### **3. Indentation Standards**

#### **A. Bullet Points**
Use: `'  • '` (2 spaces + bullet)

#### **B. Sub-items**
Use: `'    '` (4 spaces)

#### **C. Nested Items**
Use: `'      '` (6 spaces)

## Files Requiring Standardization

### **High Priority**
1. **`Pag50300.eInvoiceSetupCard.al`** - Multiple message formatting patterns
2. **`Cod50302.eInvoiceJSONGenerator.al`** - Complex error messages
3. **`Pag50316.eInvoiceSubmissionLog.al`** - Diagnostic messages

### **Medium Priority**
1. **`Pag-Ext50306.eInvPostedSalesInvoiceExt.al`** - Success/error messages
2. **`Pag50315.eInvoiceSubmissionLogCard.al`** - Status messages
3. **`Cod50312.eInvoiceSubmissionStatus.al`** - API response messages

### **Low Priority**
1. **`Pag-Ext50320.eInvCustList.al`** - Simple status messages
2. **`Pag-Ext50307.eInvSalesInvoiceExt.al`** - Validation messages

## Specific Issues to Address

### **1. Excessive Line Breaks**
Some messages have too many consecutive line breaks:
```al
// Current (excessive)
MessageText := StrSubstNo('Results:' + '\\' + '\\' + '\\' + '\\' + '\\' + 'Status: %1', Status);

// Recommended
MessageText := StrSubstNo('Results:' + '\\' + '\\' + 'Status: %1', Status);
```

### **2. Inconsistent Bullet Point Formatting**
Some use different bullet styles:
```al
// Current (inconsistent)
'• Item: %1'
'  - Item: %1'
'    * Item: %1'

// Recommended (consistent)
'  • Item: %1'
```

### **3. Mixed Indentation**
Some messages mix different indentation levels:
```al
// Current (mixed)
'• Main Item' + '\\' +
'    Sub-item' + '\\' +
'  • Another Item'

// Recommended (consistent)
'  • Main Item' + '\\' +
'      Sub-item' + '\\' +
'  • Another Item'
```

## Implementation Plan

### **Phase 1: High Priority Files**
1. Standardize message formatting in `Pag50300.eInvoiceSetupCard.al`
2. Clean up excessive line breaks in `Cod50302.eInvoiceJSONGenerator.al`
3. Standardize diagnostic messages in `Pag50316.eInvoiceSubmissionLog.al`

### **Phase 2: Medium Priority Files**
1. Standardize success/error messages in page extensions
2. Clean up API response formatting
3. Standardize confirmation messages

### **Phase 3: Low Priority Files**
1. Review and standardize remaining message formatting
2. Create documentation for formatting standards
3. Add code review guidelines

## Benefits of Standardization

1. **Consistency**: All messages follow the same formatting patterns
2. **Readability**: Easier to read and understand messages
3. **Maintainability**: Easier to modify and update messages
4. **Professional Appearance**: Consistent user experience
5. **Code Quality**: Better structured and organized code

## Conclusion

The main formatting inconsistencies have been fixed (UUID display and quote cleanup). The remaining issues are primarily about standardizing message formatting patterns across the codebase. Implementing the recommended standards will significantly improve code quality and user experience. 