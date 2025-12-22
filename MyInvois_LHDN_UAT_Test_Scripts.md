# MyInvois LHDN e-Invoice System - UAT Test Scripts

## Overview

This comprehensive User Acceptance Testing (UAT) script validates all functionality of the MyInvois LHDN e-Invoice system. The UAT process ensures the system meets business requirements and is ready for production deployment.

---

## Table of Contents

1. [UAT Preparation](#uat-preparation)
2. [Test Environment Setup](#test-environment-setup)
3. [System Configuration Testing](#system-configuration-testing)
4. [Customer Management Testing](#customer-management-testing)
5. [Invoice Processing Testing](#invoice-processing-testing)
6. [Credit Memo Testing](#credit-memo-testing)
7. [Bulk Operations Testing](#bulk-operations-testing)
8. [Error Handling Testing](#error-handling-testing)
9. [Integration Testing](#integration-testing)
10. [Performance Testing](#performance-testing)
11. [Security Testing](#security-testing)
12. [Compliance Validation](#compliance-validation)
13. [UAT Sign-Off](#uat-sign-off)

---

## UAT Preparation

### Prerequisites Checklist

#### ✅ Test Environment
- [ ] Business Central test environment available
- [ ] MyInvois LHDN extension installed and configured
- [ ] Azure Function deployed and accessible
- [ ] LHDN PREPROD environment access configured
- [ ] Test data prepared (customers, items, historical transactions)

#### ✅ Test Users and Permissions
- [ ] UAT test users created with appropriate permissions
- [ ] Business users identified for testing
- [ ] System administrator access for configuration testing
- [ ] Developer access for technical validation

#### ✅ Test Data Requirements
- [ ] Sample customers with valid TINs
- [ ] Test items with proper classifications
- [ ] Historical sales data for testing
- [ ] Various customer types (B2B, B2G, etc.)
- [ ] Different document scenarios (invoices, credit memos, returns)

#### ✅ Testing Tools and Resources
- [ ] Test script document distributed to testers
- [ ] Defect tracking system established
- [ ] Test data backup created
- [ ] Communication channels for issues/questions

### UAT Schedule

#### Phase 1: System Setup (Days 1-2)
- Environment validation
- Configuration testing
- Master data setup

#### Phase 2: Core Functionality (Days 3-7)
- Customer management
- Invoice processing
- Credit memo processing
- Bulk operations

#### Phase 3: Integration & Error Handling (Days 8-10)
- API integration testing
- Error scenarios
- Recovery procedures

#### Phase 4: Performance & Security (Days 11-12)
- Load testing
- Security validation
- Compliance checking

#### Phase 5: User Acceptance (Days 13-14)
- Business user testing
- Process validation
- Final sign-off

---

## Test Environment Setup

### Environment Validation Script

#### Test Case: ENV-001 - Environment Accessibility
**Objective**: Verify test environment is properly configured and accessible

**Preconditions**:
- Test environment URL provided
- User credentials available

**Test Steps**:
1. Open Business Central test environment
2. Login with test user credentials
3. Verify system loads successfully
4. Check for any system messages or alerts
5. Navigate to key areas: Sales, Customers, Items

**Expected Results**:
- ✅ System loads within 30 seconds
- ✅ All menus and pages accessible
- ✅ No error messages displayed
- ✅ e-Invoice related pages visible

**Pass/Fail Criteria**:
- **PASS**: All steps completed successfully
- **FAIL**: Any step fails or errors encountered

#### Test Case: ENV-002 - Extension Installation Verification
**Objective**: Confirm MyInvois LHDN extension is properly installed

**Preconditions**:
- Access to Extension Management

**Test Steps**:
1. Navigate to Extension Management
2. Search for "MyInvois LHDN" extension
3. Verify extension status is "Installed"
4. Check extension version matches requirements
5. Verify no installation errors

**Expected Results**:
- ✅ Extension shows as "Installed"
- ✅ Version is 1.0.0.52 or higher
- ✅ No installation errors
- ✅ All extension objects accessible

---

## System Configuration Testing

### Configuration Validation Script

#### Test Case: CONF-001 - eInvoice Setup Configuration
**Objective**: Validate system configuration is complete and correct

**Preconditions**:
- Access to eInvoice Setup Card
- Configuration parameters documented

**Test Steps**:
1. Open eInvoice Setup Card
2. Verify Environment setting (should be PREPROD for UAT)
3. Check Azure Function URL is configured
4. Validate LHDN API URL is set
5. Confirm Client ID and Client Secret are entered
6. Test Azure Function connectivity
7. Test LHDN API connectivity

**Expected Results**:
- ✅ All required fields populated
- ✅ Environment set to PREPROD
- ✅ Azure Function responds to test calls
- ✅ LHDN API authentication successful
- ✅ No configuration errors

**Test Data**:
```text
Environment: PREPROD
Azure Function URL: https://func-myinvois-test.azurewebsites.net
LHDN API URL: https://preprod-api.myinvois.hasil.gov.my
Client ID: [test-client-id]
Client Secret: [test-client-secret]
```

#### Test Case: CONF-002 - Master Data Setup
**Objective**: Verify all master data tables are properly configured

**Preconditions**:
- Access to master data pages
- Master data requirements documented

**Test Steps**:
1. Open State Codes list - verify 16 Malaysian states present
2. Open Country Codes list - verify Malaysia (MYS) configured
3. Open Currency Codes list - verify MYR and other required currencies
4. Open MSIC Codes list - verify industry classifications loaded
5. Open Payment Modes list - verify payment methods configured
6. Open Tax Types list - verify tax classifications set up
7. Open UOM list - verify units of measure configured

**Expected Results**:
- ✅ All master data tables populated
- ✅ No missing or invalid entries
- ✅ Data matches LHDN specifications
- ✅ Codes are unique and properly formatted

#### Test Case: CONF-003 - Company Information Setup
**Objective**: Validate company information for e-Invoicing

**Preconditions**:
- Access to Company Information page
- Company details available

**Test Steps**:
1. Open Company Information page
2. Verify TIN number is entered (12 digits)
3. Check Business Registration Number
4. Validate complete address with state and country codes
5. Confirm bank account information
6. Check contact details
7. Verify all mandatory fields completed

**Expected Results**:
- ✅ TIN format is valid (12 digits)
- ✅ All address fields completed
- ✅ State and country codes valid
- ✅ Contact information current

---

## Customer Management Testing

### Customer Setup Script

#### Test Case: CUST-001 - Customer Creation with e-Invoice Fields
**Objective**: Create a new customer with complete e-Invoice information

**Preconditions**:
- Customer master data available
- TIN validation service accessible

**Test Steps**:
1. Create new customer card
2. Enter basic customer information (name, address)
3. Navigate to e-Invoice FastTab
4. Check "Requires e-Invoice" flag
5. Enter TIN number (12 digits for companies)
6. Select ID Type (NRIC/BRN/PASSPORT/ARMY)
7. Enter complete address with state/country codes
8. Click "Validate TIN" button
9. Verify validation result
10. Save customer record

**Expected Results**:
- ✅ Customer created successfully
- ✅ TIN validation passes
- ✅ All e-Invoice fields populated
- ✅ No validation errors

**Test Data**:
```text
Customer Name: ABC Manufacturing Sdn Bhd
TIN: 123456789012
ID Type: BRN
Address: No. 123, Jalan Teknologi, 47301 Petaling Jaya, Selangor
State Code: 10 (Selangor)
Country Code: MYS
```

#### Test Case: CUST-002 - Customer TIN Validation
**Objective**: Test TIN validation functionality

**Preconditions**:
- Customer with TIN created
- LHDN TIN validation service accessible

**Test Steps**:
1. Open existing customer
2. Navigate to e-Invoice FastTab
3. Click "Validate TIN" button
4. Wait for validation process
5. Check validation result
6. Verify TIN Validation Log entry created
7. Confirm validation status updated

**Expected Results**:
- ✅ TIN validation completes within 30 seconds
- ✅ Validation result displayed (Valid/Invalid)
- ✅ Log entry created with details
- ✅ Customer status updated appropriately

#### Test Case: CUST-003 - Bulk Customer Update
**Objective**: Test bulk customer data updates

**Preconditions**:
- Multiple customers requiring updates
- Bulk update functionality available

**Test Steps**:
1. Identify customers needing updates
2. Run bulk update procedure
3. Monitor update progress
4. Verify customers updated correctly
5. Check for any errors or failures
6. Validate updated data

**Expected Results**:
- ✅ All selected customers updated
- ✅ No data corruption
- ✅ Process completes within reasonable time
- ✅ Update log shows success/failure details

---

## Invoice Processing Testing

### Standard Invoice Processing Script

#### Test Case: INV-001 - Create and Process Standard Invoice
**Objective**: Complete end-to-end invoice processing workflow

**Preconditions**:
- Test customer set up for e-Invoicing
- Test items with proper classifications
- Azure Function and LHDN API accessible

**Test Steps**:
1. Create new sales invoice
2. Select e-Invoice enabled customer
3. Add invoice lines with proper items
4. Verify e-Invoice fields auto-populated
5. Post the invoice
6. Wait for automatic e-Invoice processing
7. Check e-Invoice validation status
8. Verify submission log entry
9. Confirm LHDN submission successful

**Expected Results**:
- ✅ Invoice created and posted successfully
- ✅ e-Invoice fields populated correctly
- ✅ Automatic processing triggered
- ✅ Status shows "Submitted" or "Accepted"
- ✅ Submission log shows successful submission
- ✅ LHDN confirmation received

**Test Data**:
```text
Customer: ABC Manufacturing Sdn Bhd
Items: 5 different items with classifications
Invoice Total: RM 5,000
Expected Document Type: 01 (Invoice)
```

#### Test Case: INV-002 - Manual e-Invoice Submission
**Objective**: Test manual submission when automatic processing fails

**Preconditions**:
- Posted invoice without e-Invoice submission
- Manual submission access

**Test Steps**:
1. Open posted sales invoice
2. Verify e-Invoice status is "Not Submitted"
3. Click "Sign & Submit to LHDN" action
4. Monitor submission progress
5. Check for any error messages
6. Verify status updates to "Submitted"
7. Confirm submission log updated

**Expected Results**:
- ✅ Manual submission action available
- ✅ Submission completes successfully
- ✅ Status updates correctly
- ✅ No error messages
- ✅ Submission log shows manual submission

#### Test Case: INV-003 - Invoice with Multiple Line Items
**Objective**: Test invoice processing with complex line items

**Preconditions**:
- Customer set up for e-Invoicing
- Multiple items with different classifications

**Test Steps**:
1. Create invoice with 10+ line items
2. Include different tax types
3. Add discount lines
4. Include negative quantity adjustments
5. Post invoice
6. Verify e-Invoice processing
7. Check line item details in submission
8. Confirm LHDN acceptance

**Expected Results**:
- ✅ All line items processed correctly
- ✅ Tax calculations accurate
- ✅ Discount lines handled properly
- ✅ Negative amounts processed (where allowed)
- ✅ LHDN accepts complex invoice structure

---

## Credit Memo Testing

### Credit Memo Processing Script

#### Test Case: CM-001 - Create and Process Credit Memo
**Objective**: Test credit memo creation and e-Invoice processing

**Preconditions**:
- Original invoice already submitted to LHDN
- Credit memo required for testing

**Test Steps**:
1. Create credit memo linked to original invoice
2. Set "Applies-to Doc. No." to original invoice
3. Add credit memo lines
4. Verify e-Invoice fields (Document Type should be 02)
5. Post credit memo
6. Monitor automatic e-Invoice processing
7. Check submission status
8. Verify billing reference to original invoice

**Expected Results**:
- ✅ Credit memo created and posted
- ✅ Document type set to 02 (Credit Note)
- ✅ Billing reference includes original invoice details
- ✅ LHDN submission successful
- ✅ Status shows "Submitted"

**Test Data**:
```text
Original Invoice: INV-001 (RM 5,000)
Credit Amount: RM 1,000
Reason: Price adjustment
Applies-to Doc: INV-001
```

#### Test Case: CM-002 - Credit Memo Without Original Reference
**Objective**: Test credit memo processing without linking to original invoice

**Preconditions**:
- Customer set up for e-Invoicing
- Credit memo scenario without original invoice reference

**Test Steps**:
1. Create credit memo without "Applies-to Doc. No."
2. Add credit memo lines
3. Post credit memo
4. Verify e-Invoice processing
5. Check if system handles missing reference
6. Confirm LHDN submission

**Expected Results**:
- ✅ Credit memo processes successfully
- ✅ System handles missing reference appropriately
- ✅ LHDN accepts credit memo
- ✅ Proper audit trail maintained

---

## Bulk Operations Testing

### Batch Processing Script

#### Test Case: BULK-001 - Bulk Invoice Export
**Objective**: Test bulk export functionality for multiple invoices

**Preconditions**:
- Multiple posted invoices ready for export
- Bulk export report available

**Test Steps**:
1. Run "LHDN e-Invoice Export" report
2. Set date range and filters
3. Select multiple invoices
4. Execute export
5. Verify export file generated
6. Check file format and content
7. Validate data accuracy

**Expected Results**:
- ✅ Report runs successfully
- ✅ Export file generated in correct format
- ✅ All selected invoices included
- ✅ Data accuracy maintained
- ✅ File ready for external processing

#### Test Case: BULK-002 - Bulk Status Updates
**Objective**: Test bulk status update functionality

**Preconditions**:
- Multiple documents with various statuses
- Bulk update functionality available

**Test Steps**:
1. Select multiple documents for status update
2. Run bulk status update procedure
3. Monitor update progress
4. Verify status changes applied
5. Check for any update failures
6. Validate update log

**Expected Results**:
- ✅ Bulk update completes successfully
- ✅ All selected documents updated
- ✅ Status changes applied correctly
- ✅ No data corruption
- ✅ Update log shows complete details

---

## Error Handling Testing

### Error Scenario Script

#### Test Case: ERR-001 - Invalid Customer TIN
**Objective**: Test system behavior with invalid TIN

**Preconditions**:
- Customer with invalid TIN
- Error handling procedures documented

**Test Steps**:
1. Create invoice for customer with invalid TIN
2. Attempt to post invoice
3. Verify system prevents posting or handles gracefully
4. Check error message displayed
5. Correct TIN and retry
6. Verify successful processing

**Expected Results**:
- ✅ System detects invalid TIN
- ✅ Clear error message provided
- ✅ Process can be corrected and retried
- ✅ Successful processing after correction

#### Test Case: ERR-002 - Azure Function Unavailable
**Objective**: Test system behavior when Azure Function is down

**Preconditions**:
- Ability to simulate Azure Function unavailability
- Error handling for connectivity issues

**Test Steps**:
1. Create and post invoice
2. Simulate Azure Function unavailability
3. Monitor system response
4. Check error handling and retry logic
5. Restore Azure Function
6. Verify automatic recovery or manual retry

**Expected Results**:
- ✅ System detects connectivity issue
- ✅ Appropriate error message displayed
- ✅ Retry logic implemented
- ✅ Recovery successful when service restored

#### Test Case: ERR-003 - LHDN API Rejection
**Objective**: Test handling of LHDN API document rejection

**Preconditions**:
- Document that will be rejected by LHDN
- Error handling for API rejections

**Test Steps**:
1. Create document that will be rejected
2. Submit to LHDN
3. Monitor rejection response
4. Verify error details captured
5. Check error handling procedure
6. Correct issue and resubmit

**Expected Results**:
- ✅ Rejection handled gracefully
- ✅ Detailed error information provided
- ✅ Error logged appropriately
- ✅ Resubmission possible after correction

---

## Integration Testing

### API Integration Script

#### Test Case: INT-001 - LHDN API Authentication
**Objective**: Validate LHDN API authentication flow

**Preconditions**:
- LHDN API credentials configured
- API endpoints accessible

**Test Steps**:
1. Trigger API authentication
2. Verify token generation
3. Test token validity
4. Check token refresh mechanism
5. Validate error handling for auth failures

**Expected Results**:
- ✅ Authentication successful
- ✅ Valid access token generated
- ✅ Token refresh works
- ✅ Auth failures handled properly

#### Test Case: INT-002 - Document Submission Flow
**Objective**: Test complete document submission to LHDN

**Preconditions**:
- Complete document ready for submission
- All validations passed

**Test Steps**:
1. Generate UBL JSON document
2. Sign document via Azure Function
3. Submit to LHDN API
4. Monitor submission status
5. Verify LHDN response
6. Check status updates in Business Central

**Expected Results**:
- ✅ JSON generation successful
- ✅ Digital signing completes
- ✅ LHDN submission successful
- ✅ Status tracking works
- ✅ Business Central updated

#### Test Case: INT-003 - Status Retrieval
**Objective**: Test document status retrieval from LHDN

**Preconditions**:
- Document submitted to LHDN
- Status retrieval functionality

**Test Steps**:
1. Query document status from LHDN
2. Verify status response
3. Check status update in Business Central
4. Test status polling mechanism
5. Validate status history

**Expected Results**:
- ✅ Status retrieval successful
- ✅ Status accurately reflected
- ✅ Business Central updated
- ✅ Status history maintained

---

## Performance Testing

### Load Testing Script

#### Test Case: PERF-001 - High Volume Invoice Processing
**Objective**: Test system performance under load

**Preconditions**:
- Sufficient test data
- Performance monitoring tools

**Test Steps**:
1. Create 100 test invoices
2. Process invoices simultaneously
3. Monitor processing time
4. Check system resource usage
5. Verify all invoices processed successfully
6. Analyze performance metrics

**Expected Results**:
- ✅ All invoices processed within 30 minutes
- ✅ Average processing time < 30 seconds per invoice
- ✅ System resources remain stable
- ✅ No processing failures

#### Test Case: PERF-002 - Concurrent User Testing
**Objective**: Test system with multiple concurrent users

**Preconditions**:
- Multiple test user accounts
- Concurrent access scenario

**Test Steps**:
1. Have 10 users create invoices simultaneously
2. Monitor system performance
3. Check for conflicts or locking issues
4. Verify all transactions complete successfully
5. Analyze response times

**Expected Results**:
- ✅ All users can work simultaneously
- ✅ No transaction conflicts
- ✅ Response times remain acceptable
- ✅ System stability maintained

---

## Security Testing

### Security Validation Script

#### Test Case: SEC-001 - User Access Control
**Objective**: Validate user permissions and access controls

**Preconditions**:
- Different user roles configured
- Permission sets assigned

**Test Steps**:
1. Test user access with different permission levels
2. Verify users can only access authorized functions
3. Check audit logging for access attempts
4. Test permission changes
5. Validate role-based access

**Expected Results**:
- ✅ Users have appropriate access levels
- ✅ Unauthorized access prevented
- ✅ Access attempts logged
- ✅ Permission changes work correctly

#### Test Case: SEC-002 - Data Encryption
**Objective**: Validate data encryption and protection

**Preconditions**:
- Sensitive data handling configured
- Encryption mechanisms in place

**Test Steps**:
1. Check data encryption at rest
2. Verify data transmission encryption
3. Test credential storage security
4. Validate certificate handling
5. Check for data leakage prevention

**Expected Results**:
- ✅ Sensitive data encrypted
- ✅ Secure data transmission
- ✅ Credentials securely stored
- ✅ No data leakage detected

---

## Compliance Validation

### Compliance Testing Script

#### Test Case: COMP-001 - UBL Structure Validation
**Objective**: Validate generated UBL documents meet LHDN specifications

**Preconditions**:
- Sample documents generated
- UBL validation tools

**Test Steps**:
1. Generate sample UBL documents
2. Validate against UBL 2.1 schema
3. Check LHDN-specific requirements
4. Verify namespace declarations
5. Validate field formats and values

**Expected Results**:
- ✅ Documents pass UBL validation
- ✅ LHDN requirements met
- ✅ Proper namespace declarations
- ✅ All mandatory fields present

#### Test Case: COMP-002 - Audit Trail Validation
**Objective**: Verify complete audit trail for compliance

**Preconditions**:
- Document processing completed
- Audit logging enabled

**Test Steps**:
1. Review submission logs
2. Check audit trail completeness
3. Verify log integrity
4. Test log retention
5. Validate audit reporting

**Expected Results**:
- ✅ Complete audit trail maintained
- ✅ All actions logged
- ✅ Log integrity preserved
- ✅ Retention policies met

---

## UAT Sign-Off

### Sign-Off Process

#### UAT Completion Checklist
- [ ] All test cases executed
- [ ] No critical defects remaining
- [ ] Business requirements validated
- [ ] Performance criteria met
- [ ] Security requirements satisfied
- [ ] Compliance validation complete
- [ ] User training completed
- [ ] Documentation reviewed

#### Sign-Off Documentation
**UAT Sign-Off Form**

```text
Project: MyInvois LHDN e-Invoice System Implementation
Date: ____________________

Business Owner: ____________________
IT Representative: ____________________
QA Lead: ____________________

Test Results Summary:
- Total Test Cases: _____
- Passed: _____
- Failed: _____
- Deferred: _____

Critical Issues: _____
- Resolved: _____ Pending: _____

Performance Validation:
- Average Processing Time: _____ seconds
- Success Rate: _____%
- System Availability: _____%

Compliance Validation:
- UBL Compliance: ☐ Pass ☐ Fail
- LHDN Requirements: ☐ Pass ☐ Fail
- Audit Trail: ☐ Pass ☐ Fail

Business Acceptance:
- Functional Requirements: ☐ Met ☐ Not Met
- Performance Requirements: ☐ Met ☐ Not Met
- User Experience: ☐ Acceptable ☐ Needs Improvement

Sign-Off:
Business Owner Signature: ____________________ Date: _____
IT Representative Signature: ____________________ Date: _____
QA Lead Signature: ____________________ Date: _____

Comments:
________________________________________________________________________
________________________________________________________________________
________________________________________________________________________
```

### Post-UAT Activities

#### Production Preparation
1. **Configuration Migration**: Move configurations to production
2. **Data Migration**: Migrate master data to production
3. **User Training**: Complete end-user training
4. **Documentation**: Finalize production documentation
5. **Go-Live Plan**: Execute production deployment plan

#### Support Readiness
1. **Support Team Training**: Train support teams on system
2. **Knowledge Base**: Populate support knowledge base
3. **Monitoring Setup**: Configure production monitoring
4. **Escalation Procedures**: Establish support escalation paths

---

## Test Case Summary

### Test Execution Summary Table

| Test Category | Test Cases | Estimated Time | Priority |
|---------------|------------|----------------|----------|
| Environment Setup | 2 | 2 hours | High |
| System Configuration | 3 | 4 hours | High |
| Customer Management | 3 | 6 hours | High |
| Invoice Processing | 3 | 8 hours | High |
| Credit Memo Testing | 2 | 4 hours | Medium |
| Bulk Operations | 2 | 3 hours | Medium |
| Error Handling | 3 | 5 hours | High |
| Integration Testing | 3 | 6 hours | High |
| Performance Testing | 2 | 4 hours | Medium |
| Security Testing | 2 | 3 hours | High |
| Compliance Validation | 2 | 4 hours | High |
| **Total** | **27** | **49 hours** | |

### Test Case Execution Tracking

#### Daily Test Execution Log
```text
Date: ________
Tester: ________
Test Cases Executed: ________
- Passed: ________
- Failed: ________
- Blocked: ________

Issues Identified:
1. ________
2. ________
3. ________

Blockers:
1. ________
2. ________

Next Steps:
1. ________
2. ________
```

#### Defect Tracking Template
```text
Defect ID: UAT-___
Title: ________
Description: ________
Severity: Critical/High/Medium/Low
Test Case: ________
Steps to Reproduce:
1. ________
2. ________
3. ________
Expected Result: ________
Actual Result: ________
Environment: ________
Assigned To: ________
Status: Open/In Progress/Resolved/Closed
Resolution: ________
```

---

**UAT Test Scripts Version**: 1.0
**Last Updated**: January 2025
**Estimated Execution Time**: 49 hours across 14 days

*These UAT test scripts provide comprehensive validation of the MyInvois LHDN e-Invoice system. Execute all test cases systematically and document results for production readiness assessment.*

