# Sales Order e-Invoice Implementation

## Overview

This implementation extends the e-Invoice functionality to Sales Orders, allowing automatic submission to LHDN when users post Sales Orders with the "Ship and Invoice" option.

## Implementation Details

### New Codeunit: `Cod50313.eInvSalesOrderPostingSub.al`

This codeunit handles e-Invoice submission specifically for Sales Orders and includes:

1. **Event Subscriber for Posting**: `OnAfterPostSalesDoc`
   - Triggers when a Sales Order is posted
   - Only processes Sales Orders (excludes other document types)
   - Only processes when an invoice is created (Ship and Invoice or Invoice only)
   - Copies e-Invoice fields from Sales Order to Posted Invoice
   - Automatically submits to LHDN if customer requires e-Invoice

2. **Event Subscriber for Validation**: `OnBeforePostSalesDoc`
   - Validates required e-Invoice fields before posting
   - Ensures all mandatory fields are populated for customers requiring e-Invoice
   - Prevents posting if required fields are missing

3. **Event Subscriber for Line Fields**: `OnBeforeSalesInvLineInsert`
   - Copies e-Invoice line fields from Sales Order lines to Posted Invoice lines
   - Handles Classification, UOM, and Tax Type fields

### Modified Existing Codeunits

1. **`Cod50305.eInvSalesInvPostingSub.al`**
   - Updated to exclude Sales Orders from processing
   - Added check: `if SalesHeader."Document Type" = SalesHeader."Document Type"::Order then exit;`
   - Prevents conflicts with the new Sales Order dedicated codeunit

2. **`Cod50306.eInvFieldPopulation.al`**
   - Updated to exclude Sales Orders from field copying
   - Added same check to prevent conflicts

## User Experience

### Sales Order Posting Process

1. **User creates Sales Order** with e-Invoice fields populated
2. **User clicks "Post"** on the Sales Order
3. **System shows posting dialog** with options:
   - Ship
   - Invoice  
   - Ship and Invoice
4. **User selects "Ship and Invoice"**
5. **System validates e-Invoice fields** before posting
6. **If validation passes**, Sales Order is posted and invoice is created
7. **System automatically submits invoice to LHDN** if customer requires e-Invoice
8. **User receives confirmation message** about successful posting and LHDN submission

### Validation Rules

The system validates the following fields for customers requiring e-Invoice:

**Header Fields:**
- e-Invoice Document Type
- e-Invoice Currency Code

**Line Fields:**
- e-Invoice Classification
- e-Invoice UOM
- e-Invoice Tax Type

### Error Handling

- **Missing Fields**: System prevents posting and shows detailed error message listing missing fields
- **LHDN Submission Failure**: System posts the document but shows warning about failed LHDN submission
- **Manual Submission**: Users can manually submit failed invoices from Posted Sales Invoice page

## Technical Architecture

### Event Flow

```
Sales Order Post → OnBeforePostSalesDoc → Validation → OnAfterPostSalesDoc → LHDN Submission
```

### Data Flow

```
Sales Order Header → Posted Invoice Header (e-Invoice fields copied)
Sales Order Lines → Posted Invoice Lines (e-Invoice fields copied)
Posted Invoice → LHDN API (automatic submission)
```

### Company Restriction

All functionality is restricted to company "JOTEX SDN BHD" only.

## Integration Points

1. **Sales-Post Codeunit**: Main posting logic
2. **eInvoice JSON Generator**: LHDN API submission
3. **Customer Table**: e-Invoice requirement check
4. **Company Information**: Company restriction check

## Benefits

1. **Seamless Integration**: Works with existing Sales Order posting workflow
2. **Automatic Submission**: No manual intervention required for LHDN submission
3. **Validation**: Prevents posting with incomplete e-Invoice data
4. **Error Handling**: Graceful handling of LHDN API failures
5. **Audit Trail**: Complete logging of all operations

## Testing Scenarios

1. **Valid Sales Order**: All fields populated, successful posting and LHDN submission
2. **Missing Fields**: Validation prevents posting, shows error message
3. **Customer without e-Invoice**: Normal posting, no LHDN submission
4. **LHDN API Failure**: Successful posting, warning about failed submission
5. **Different Posting Options**: Only "Ship and Invoice" triggers e-Invoice submission 