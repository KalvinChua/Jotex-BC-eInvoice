# MyInvois LHDN e-Invoice System - User Guide

## Welcome to MyInvois e-Invoice System

This guide will help you understand and use the MyInvois LHDN e-Invoice system in Microsoft Dynamics 365 Business Central. Whether you're new to e-Invoicing or need a refresher, this guide provides step-by-step instructions for all common tasks.

---

## Table of Contents

1. [Quick Start Guide](#quick-start-guide)
2. [Understanding e-Invoices](#understanding-e-invoices)
3. [System Setup](#system-setup)
4. [Daily Operations](#daily-operations)
5. [Customer Management](#customer-management)
6. [Document Processing](#document-processing)
7. [Monitoring and Reporting](#monitoring-and-reporting)
8. [Troubleshooting](#troubleshooting)
9. [Best Practices](#best-practices)
10. [Support and Resources](#support-and-resources)

---

## Quick Start Guide

### For New Users (5 minutes setup)

1. **Check Your Access**
   - Ensure you have access to Business Central
   - Verify you have the necessary permissions for e-Invoice operations

2. **Verify System Setup**
   - Ask your administrator to confirm the system is configured
   - Check that your company information is complete

3. **Test with a Sample Invoice**
   - Create a test sales invoice
   - Post it and try the "Sign & Submit to LHDN" action

4. **Monitor the Results**
   - Check the e-Invoice status on your posted document
   - Review the submission log for any issues

### Key Terms You Need to Know

- **LHDN**: Lembaga Hasil Dalam Negeri (Inland Revenue Board of Malaysia)
- **MyInvois**: Malaysia's official e-Invoice platform
- **TIN**: Tax Identification Number
- **UBL**: Universal Business Language (standard format for e-Invoices)
- **PREPROD/PRODUCTION**: Test and live environments

---

## Understanding e-Invoices

### What is an e-Invoice?

An e-Invoice is a digital invoice that complies with Malaysian tax regulations. Instead of paper invoices, e-Invoices are:

- Submitted electronically to LHDN
- Digitally signed for authenticity
- Automatically validated
- Stored securely in the government's system

### Why Use e-Invoices?

- **Legal Requirement**: Mandatory for B2B transactions above RM30,000
- **Faster Processing**: Instant submission and validation
- **Cost Savings**: No paper, printing, or mailing costs
- **Better Compliance**: Automatic tax reporting and audit trail
- **Real-time Status**: Track invoice status instantly

### Document Types Supported

| Type | Code | Description | When to Use |
|------|------|-------------|-------------|
| Invoice | 01 | Standard sales invoice | Regular sales transactions |
| Credit Note | 02 | Credit memo for returns/refunds | Customer returns or price adjustments |
| Debit Note | 03 | Additional charges | Extra charges after original invoice |
| Refund Note | 04 | Refund documentation | Official refund processing |
| Self-billed Invoice | 11 | Customer creates invoice | When customer manages their own billing |

---

## System Setup

### Initial Configuration Checklist

Before using the system, ensure these are completed:

#### ✅ Company Information Setup

- [ ] TIN (Tax Identification Number)
- [ ] Business Registration Number
- [ ] Complete company address with state code
- [ ] Bank account information
- [ ] Contact details

#### ✅ System Configuration

- [ ] Azure Function URL configured
- [ ] Environment set (PREPROD for testing, PRODUCTION for live)
- [ ] LHDN API credentials
- [ ] Digital signature certificate

#### ✅ Master Data Setup

- [ ] State codes configured
- [ ] Country codes configured
- [ ] Currency codes set up
- [ ] Payment modes defined
- [ ] MSIC codes configured

### How to Access e-Invoice Setup

1. **From Business Central Home Page**
   - Search for "eInvoice Setup Card"
   - Or navigate: Departments → Administration → Application Setup → eInvoice Setup

2. **Key Settings to Configure**

   ```text
   General Tab:
   - Environment: Choose PREPROD or PRODUCTION
   - Azure Function URL: Your signing service endpoint
   - Default Version: 1.1 (UBL 2.1)

   API Configuration Tab:
   - LHDN API URL: https://api.myinvois.hasil.gov.my (Production)
   - Authentication Token: Your LHDN API token
   - Timeout Settings: Default 30 seconds
   ```

---

## Daily Operations

### Creating e-Invoice Ready Documents

#### Step 1: Create Sales Invoice/Order

1. Go to **Sales & Marketing → Sales → Sales Orders** or **Sales Invoices**
2. Create new document
3. Select customer (must be e-Invoice enabled)
4. Add lines with proper item classifications

#### Step 2: Verify e-Invoice Fields

Before posting, check these fields are populated:

- **eInvoice Document Type**: Automatically set based on document type
- **eInvoice Currency Code**: MYR or customer's currency
- **eInvoice Version**: 1.1
- **Customer TIN**: Must be validated

#### Step 3: Post and Submit

1. Click **Post** or **Post and Send**
2. After posting, go to the posted document
3. Click **Sign & Submit to LHDN**
4. Monitor the status

### Processing Different Document Types

#### Standard Invoice (Type 01)

```al
// Automatic process
1. Create sales invoice
2. Post invoice
3. System auto-generates UBL JSON
4. Digital signing via Azure Function
5. Submit to LHDN
6. Status: "Submitted" or "Accepted"
```

#### Credit Note (Type 02)

```al
// For returns or adjustments
1. Create credit memo
2. Link to original invoice (Applies-to Doc. No.)
3. Post credit memo
4. Sign & Submit to LHDN
5. Reference original invoice in billing reference
```

#### Self-Billed Invoice (Type 11)

```al
// When customer manages billing
1. Customer creates and sends invoice data
2. You receive and validate the information
3. Create invoice in Business Central
4. Process as self-billed document (Type 11)
5. Submit to LHDN
```

---

## Customer Management

### Setting Up Customers for e-Invoicing

#### Enable e-Invoice for Customer

1. Open **Customer Card**
2. Go to **e-Invoice FastTab**
3. Check **"Requires e-Invoice"**
4. Fill required fields:

#### Required Information

- **TIN Number**: Customer's tax ID (12 digits for companies)
- **ID Type**: NRIC, BRN, PASSPORT, or ARMY
- **Address**: Complete with state and country codes
- **State Code**: Malaysian state (e.g., "14" for Kuala Lumpur)
- **Country Code**: "MYS" for Malaysia

#### TIN Validation Process

1. Enter customer's TIN
2. Click **"Validate TIN"** action
3. System calls LHDN validation API
4. Check **TIN Validation Log** for results
5. Status shows: Valid, Invalid, or Pending

### Customer Setup Checklist

- [ ] Customer marked as "Requires e-Invoice"
- [ ] TIN number entered and validated
- [ ] Complete address with state/country codes
- [ ] ID type specified
- [ ] Contact information current
- [ ] Tax classification set

---

## Document Processing

### Invoice Processing Workflow

#### 1. Document Creation

```text
Sales Order/Invoice → Add Lines → Verify Fields → Post Document
```

#### 2. e-Invoice Generation

```text
Posted Document → Generate UBL JSON → Digital Sign → Submit to LHDN
```

#### 3. Status Monitoring

```text
Submission → Processing → Accepted/Rejected → Status Update
```

### Batch Processing

#### Export Multiple Documents

1. Go to **Reports → eInvoice Reports → Export Posted Sales Batch eInv**
2. Set filters:
   - Date range
   - Customer filters
   - Status filters
3. Run report
4. System generates batch file
5. Process through external tools if needed

#### Bulk Status Updates

Use these functions for bulk operations:

- **Bulk TIN Validation**: Validate multiple customers
- **Bulk Field Updates**: Update e-Invoice fields across documents
- **Bulk Submissions**: Submit multiple documents at once

### Error Handling

#### Common Submission Errors

| Error Message | Cause | Solution |
|---------------|-------|----------|
| "Invalid TIN" | Wrong TIN format | Verify TIN with customer |
| "Missing Address" | Incomplete address | Complete customer address |
| "Invalid State Code" | Wrong state mapping | Check state code setup |
| "Signature Failed" | Certificate issue | Contact IT for certificate |
| "API Timeout" | Network/LHDN issue | Retry submission later |

#### Recovery Steps

1. **Check Error Details**: Review submission log
2. **Verify Data**: Ensure all required fields complete
3. **Retry Submission**: Use "Sign & Submit" again
4. **Contact Support**: If persistent issues

---

## Monitoring and Reporting

### Status Tracking

#### Document Status Values

- **"Not Submitted"**: Document created but not sent
- **"Pending"**: Submitted, awaiting LHDN processing
- **"Submitted"**: Successfully received by LHDN
- **"Accepted"**: Approved and valid
- **"Rejected"**: Failed validation, check error details
- **"Cancelled"**: Document cancelled in LHDN

#### How to Check Status

1. Open posted document
2. Look at **"eInvoice Validation Status"** field
3. Click **"View Submission Log"** for details
4. Check **"eInvoice Submission Log"** page for history

### Reporting and Analytics

#### Available Reports

1. **e-Invoice Submission Report**
   - Date range submissions
   - Success/failure rates
   - Document type breakdown

2. **TIN Validation Report**
   - Customer validation status
   - Failed validations
   - Validation history

3. **Compliance Report**
   - Missing e-Invoice setups
   - Incomplete customer data
   - System health check

#### Key Metrics to Monitor

- **Submission Success Rate**: Target > 95%
- **Average Processing Time**: Should be < 5 minutes
- **Error Rate by Type**: Track and reduce common errors
- **Customer Compliance**: % of customers e-Invoice ready

---

## Troubleshooting

### Quick Problem Solver

#### Issue: "Sign & Submit" button not visible

#### Possible Causes

- Customer not marked for e-Invoice
- Missing required fields
- User permissions issue

#### Solutions

1. Check customer "Requires e-Invoice" flag
2. Verify all mandatory fields are filled
3. Confirm user has e-Invoice permissions

#### Issue: Submission fails with "Invalid Structure"

#### Possible Causes

- Missing UBL namespaces
- Incorrect document type
- Invalid JSON format

#### Solutions

1. Check system version is current
2. Verify document type codes
3. Review submission log for details

#### Issue: Azure Function connection failed

#### Possible Causes

- Wrong Azure Function URL
- Network connectivity issues
- Authentication problems

#### Solutions

1. Verify Azure Function URL in setup
2. Check network connectivity
3. Validate authentication tokens

### Getting Help

#### Self-Service Resources

1. **Check Submission Logs**: Detailed error information
2. **Review TIN Validation Logs**: Customer TIN issues
3. **Test Environment**: Use PREPROD for testing
4. **User Documentation**: This guide and developer docs

#### When to Contact Support

- System configuration issues
- Certificate/signature problems
- LHDN API connectivity issues
- Permission and access problems

---

## Best Practices

### Document Management

- **Always link credit memos** to original invoices when possible
- **Use correct document types** (01, 02, 03, 04, 11-14)
- **Complete all fields** before posting
- **Validate customer TIN** before creating documents

### System Maintenance

- **Regular backups** of Business Central data
- **Monitor submission logs** daily
- **Update customer information** when it changes
- **Test in PREPROD** before production changes

### Performance Optimization

- **Batch process** multiple documents together
- **Use background processing** for large volumes
- **Monitor API timeouts** and adjust accordingly
- **Cache frequently used data** (company info, setup)

### Compliance and Audit

- **Maintain complete audit trail** of all submissions
- **Regular compliance reviews** with LHDN requirements
- **Document all processes** and procedures
- **Train users** on e-Invoice requirements

---

## Support and Resources

### Internal Support

- **System Administrator**: For configuration issues
- **IT Support**: For technical problems
- **Business Central Support**: For platform issues

### External Resources

- **LHDN MyInvois Portal**: <https://myinvois.hasil.gov.my/>
- **LHDN SDK Documentation**: <https://sdk.myinvois.hasil.gov.my/>
- **Microsoft Learn**: Business Central e-Invoice documentation

### Emergency Contacts

- **LHDN Support Hotline**: Contact for urgent LHDN issues
- **Certificate Authority**: For digital signature problems
- **Azure Support**: For Azure Function issues

### Training Resources

- **This User Guide**: Complete reference manual
- **Developer Guide**: Technical implementation details
- **LHDN Training Materials**: Official government training
- **Video Tutorials**: Step-by-step process videos

---

## Quick Reference

### Keyboard Shortcuts

- **Ctrl+F**: Search for customers/documents
- **F5**: Refresh page
- **Ctrl+Enter**: Save and close
- **Alt+F2**: Open page inspection

### Important Field Names

- **"eInvoice Validation Status"**: Current submission status
- **"eInvoice Document Type"**: LHDN document type code
- **"eInvoice Currency Code"**: Transaction currency
- **"Requires e-Invoice"**: Customer e-Invoice flag

### Status Indicators

- 🟢 **Green**: Successfully submitted
- 🟡 **Yellow**: Pending processing
- 🔴 **Red**: Failed or rejected
- ⚪ **White**: Not submitted

---

**Document Version**: 1.0
**Last Updated**: January 2025
**Next Review**: March 2025

*This user guide is designed to help you effectively use the MyInvois LHDN e-Invoice system. For technical details, refer to the Developer Guide. If you need assistance, contact your system administrator or IT support team.*
