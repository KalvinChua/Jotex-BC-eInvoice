# Customer Name Upgrade Solution for Previous e-Invoice Submissions

## Problem
The "Customer Name" field in the "e-Invoice Submission Log" was not populated for submissions created before the fix was implemented in the `eInvoice JSON Generator` codeunit.

## Solution Overview
Two approaches have been implemented to address this issue:

### 1. Automatic Data Upgrade (Recommended)
A new data upgrade codeunit (`Cod50324.eInvoiceCustomerNameUpgrade.al`) has been created that will automatically run during the next app upgrade to populate customer names for existing records.

**Features:**
- Automatically runs during app upgrade
- Finds all submission log entries with empty "Customer Name"
- Retrieves customer names from the corresponding posted sales invoices
- Updates the records with the correct customer names
- Logs the upgrade results in the submission log

### 2. Manual Update Procedure
A manual procedure has been added to `Cod50320.eInvoiceCancellationHelper.al` that can be called to update existing records.

**Usage:**
```al
// Call this procedure from the AL Development Environment or via code
UpdateExistingCustomerNames();
```

## Implementation Details

### Data Upgrade Codeunit (Cod50324)
```al
codeunit 50324 "eInvoice Customer Name Upgrade"
{
    Subtype = Upgrade;
    
    trigger OnUpgradePerCompany()
    begin
        UpdateCustomerNamesInSubmissionLog();
    end;
    
    // ... implementation details
}
```

### Manual Update Procedure
```al
procedure UpdateExistingCustomerNames()
var
    SubmissionLog: Record "eInvoice Submission Log";
    Customer: Record Customer;
    SalesInvoiceHeader: Record "Sales Invoice Header";
    CustomerName: Text;
    UpdatedCount: Integer;
begin
    // ... implementation details
end;
```

## How It Works

1. **Find Empty Customer Names**: The procedure searches for all submission log entries where "Customer Name" is empty.

2. **Retrieve Customer Information**: For each entry, it:
   - Gets the posted sales invoice using the "Invoice No."
   - Retrieves the customer record using the "Sell-to Customer No."
   - Extracts the customer name

3. **Update Records**: If a customer name is found, it updates the submission log entry.

4. **Log Results**: The upgrade process creates a system log entry showing how many records were updated.

## Benefits

- **Automatic**: No manual intervention required for future deployments
- **Safe**: Only updates records with empty customer names
- **Traceable**: Creates log entries to track the upgrade process
- **Reversible**: Can be run multiple times safely
- **Comprehensive**: Covers all existing records that need updating

## Deployment

1. **For New Installations**: The data upgrade will run automatically during the first installation.

2. **For Existing Installations**: The data upgrade will run when the app is upgraded to the next version.

3. **For Immediate Updates**: Use the manual procedure `UpdateExistingCustomerNames()` if immediate updates are needed.

## Verification

After the upgrade runs, you can verify the results by:
1. Opening the "e-Invoice Submission Log" page
2. Checking that the "Customer Name" column is populated for all entries
3. Looking for a system log entry with the message "Data upgrade completed: Updated Customer Name for X existing submission log entries"

## Notes

- The upgrade only affects records with empty "Customer Name" fields
- Records that already have customer names will not be modified
- The process is safe to run multiple times
- System log entries are created with "Customer Name" set to 'System' to distinguish them from regular invoice submissions
