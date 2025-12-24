# Developer Handover Documentation

## Jotex Business Central e-Invoice Extension

> **Last Updated**: December 2025  
> **Project Status**: Production (Active)  
> **Compliance**: LHDN MyInvois Malaysia e-Invoice Mandate

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Project Takeover Checklist & 30-Day Onboarding Plan](#2-project-takeover-checklist--30-day-onboarding-plan)
3. [Development Environment Setup](#3-development-environment-setup)
4. [Architecture Deep Dive](#4-architecture-deep-dive)
5. [Critical Components Reference](#5-critical-components-reference)
6. [Operational Workflows](#6-operational-workflows)
7. [Testing & Quality Assurance](#7-testing--quality-assurance)
8. [Deployment Procedures](#8-deployment-procedures)
9. [Troubleshooting Guide](#9-troubleshooting-guide)
10. [Maintenance & Support](#10-maintenance--support)

---

## 1. Executive Summary

### 1.1 Project Purpose

This extension enables **Microsoft Dynamics 365 Business Central** to comply with Malaysia's **LHDN (Lembaga Hasil Dalam Negeri) MyInvois** e-invoicing mandate. It handles the complete lifecycle of e-Invoice generation, digital signing, submission, and status tracking.

**Key Capabilities:**

- Automated e-Invoice generation from posted sales documents
- Digital signature application using company certificates
- Real-time submission to LHDN MyInvois platform
- QR code generation for invoice validation
- Comprehensive audit trail and error logging
- Support for invoices, credit notes, and debit notes

### 1.2 Project Timeline

```text
2024 Q1: Project Initiation
├─ Jan 2024: Requirements gathering and LHDN API analysis
├─ Feb 2024: Architecture design and proof of concept
└─ Mar 2024: Development environment setup

2024 Q2: Core Development
├─ Apr 2024: JSON generator and UBL 2.1 implementation
├─ May 2024: Azure Function development for digital signing
└─ Jun 2024: LHDN API integration and testing

2024 Q3: Testing & Refinement
├─ Jul 2024: User acceptance testing (UAT)
├─ Aug 2024: Bug fixes and performance optimization
└─ Sep 2024: PreProd environment testing

2024 Q4: Production Deployment
├─ Oct 2024: Production deployment and monitoring
├─ Nov 2024: User training and support
└─ Dec 2024: Stabilization and enhancements

2025: Ongoing Maintenance
└─ Current Status: Production (Active) - Version 1.0.0.71
```

### 1.3 Stakeholder Map

```text
┌─────────────────────────────────────────────────────────────┐
│                    LHDN (Regulatory Body)                    │
│              Mandates e-Invoice compliance                   │
└────────────────────────┬────────────────────────────────────┘
                         │ Compliance Requirements
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   Jotex Management                           │
│          Business Owner & Decision Maker                     │
└────────┬────────────────────────────────┬───────────────────┘
         │                                │
         ▼                                ▼
┌────────────────────┐          ┌────────────────────────────┐
│  Finance Team      │          │  IT Department             │
│  (Primary Users)   │          │  (System Administrators)   │
│                    │          │                            │
│  • Post invoices   │          │  • Maintain system         │
│  • Submit to LHDN  │          │  • Monitor performance     │
│  • Handle errors   │          │  • Deploy updates          │
└────────────────────┘          └────────────────────────────┘
         │                                │
         └────────────┬───────────────────┘
                      ▼
         ┌────────────────────────┐
         │   Development Team     │
         │   (You - New Developer)│
         │                        │
         │   • Maintain codebase  │
         │   • Fix bugs           │
         │   • Add features       │
         │   • Provide support    │
         └────────────────────────┘
```

### 1.4 Business Impact

#### Compliance & Legal

- **Regulatory Requirement**: Mandatory for all Malaysian businesses (effective Aug 2024)
- **Penalty for Non-Compliance**: Fines up to RM 20,000 or imprisonment
- **Audit Trail**: All submissions logged for LHDN audit purposes
- **Data Retention**: 7 years as per LHDN requirements

#### Operational Metrics

- **Daily Volume**: ~50-200 invoices/day (varies by business cycle)
- **Peak Volume**: Up to 500 invoices/day (month-end closing)
- **Processing Time**: Average 3-5 seconds per invoice
- **Success Rate**: Target >98% (current: ~96-97%)
- **System Availability**: 99.5% uptime required

#### User Impact

- **Primary Users**: 5-10 finance team members
- **User Training**: 2-hour initial training + ongoing support
- **Daily Usage**: Multiple submissions throughout business hours
- **Critical Window**: Month-end (25th-5th) - highest volume

#### Financial Impact

- **Cost Savings**: Eliminates manual e-Invoice portal entry
- **Time Savings**: ~5 minutes per invoice (automated vs manual)
- **Efficiency Gain**: ~80% reduction in invoice processing time
- **ROI**: Positive within 6 months of deployment

### 1.5 Technical Stack

- **Platform**: Business Central 26.0+ (AL Language)
- **Runtime**: AL Runtime 15.0
- **Cloud Services**: Azure Functions (Document Signing)
- **External APIs**: LHDN MyInvois API v1.0
- **Standards**: UBL 2.1 (Universal Business Language)
- **Authentication**: OAuth 2.0 (Client Credentials Flow)
- **Signing**: XAdES (XML Advanced Electronic Signatures)
- **Certificate**: P12/PFX format (annual renewal required)

### 1.6 Critical Dates & Deadlines

> [!CAUTION]
> **Certificate Expiry**: The digital signing certificate expires annually. Missing renewal will block ALL invoice submissions.

| Event | Date | Action Required | Lead Time |
| ----- | ---- | --------------- | --------- |
| Certificate Renewal | Annually (check eInvoice Setup) | Request new certificate from CA | 60 days before expiry |
| LHDN API Credentials Rotation | Every 6 months | Update Client ID/Secret in setup | 14 days before expiry |
| Quarterly Security Review | Every 3 months | Audit access logs and credentials | 1 week |
| BC Platform Upgrade | As per Microsoft schedule | Test extension compatibility | 30 days before upgrade |
| Extension Version Update | As needed | Deploy to sandbox, test, then production | 7 days for testing |

### 1.7 Current System Status

**Production Environment:**

- **Version**: 1.0.0.71 (as of Dec 2024)
- **Environment**: PRODUCTION
- **LHDN API**: <https://api.myinvois.hasil.gov.my>
- **Azure Function**: [URL in eInvoice Setup]
- **Health Status**: ✅ Operational

**Known Issues:**

- Occasional QR code generation delays (LHDN API latency)
- Retry logic handles transient Azure Function timeouts
- Performance optimization ongoing for batch submissions

**Recent Changes (Last 3 Months):**

- Credit note reference handling updated (Dec 2023)
- Improved error messaging for user clarity
- Enhanced logging for better diagnostics
- Performance improvements for large invoices

---

## 2. Project Takeover Checklist & 30-Day Onboarding Plan

> [!NOTE]
> This section provides a structured 30-day onboarding plan. Adjust the timeline based on your experience level and availability. The plan assumes full-time dedication; part-time developers should extend timelines proportionally.

### 2.1 Week 1: Environment Setup & Orientation

**Objective**: Gain access to all systems, set up development environment, and understand project context.

#### Day 1: Access Verification & Initial Setup

**Morning (9:00 AM - 12:00 PM)**:

- [ ] **Source Code Access**

  ```bash
  # Clone the repository
  git clone https://github.com/KalvinChua/Jotex-BC-eInvoice.git
  cd Jotex-BC-eInvoice
  
  # Verify repository structure
  ls -la
  # Expected: See .al files, app.json, HANDOVER.md, etc.
  ```
  
- [ ] **Verify GitHub Access**
  - Can you see the repository?
  - Can you create a branch?
  - Can you push commits?

**Afternoon (1:00 PM - 5:00 PM)**:

- [ ] **Environment Access Verification**
  - [ ] Business Central Sandbox: Login at `https://businesscentral.dynamics.com`
  - [ ] Azure Portal: Access Resource Group `rg-myinvois-*`
  - [ ] Document all URLs and credentials in your secure password manager

- [ ] **Initial Documentation Review**
  - [ ] Read this HANDOVER.md (sections 1-3)
  - [ ] Skim `README.md`
  - [ ] Review `app.json` to understand extension metadata

**End of Day Checkpoint**:

```text
✓ Can access GitHub repository
✓ Can login to BC Sandbox
✓ Can access Azure Portal
✓ Have read executive summary and understand project purpose
```

---

#### Day 2: Development Environment Setup

**Morning (9:00 AM - 12:00 PM)**:

- [ ] **Install Required Software**

  ```powershell
  # Verify installations
  code --version          # VS Code 1.85.0+
  git --version           # Git 2.40.0+
  docker --version        # Docker 24.0.0+ (if using containers)
  az --version            # Azure CLI 2.50.0+
  ```

- [ ] **Install VS Code Extensions**
  - [ ] AL Language Extension (v13.0+)
  - [ ] GitLens (optional but recommended)
  - [ ] Markdown All in One (for documentation)

**Afternoon (1:00 PM - 5:00 PM)**:

- [ ] **Configure VS Code for BC Development**
  - [ ] Create `.vscode/launch.json` (see Section 3.2 for template)
  - [ ] Configure `.vscode/settings.json`
  - [ ] Download symbols: Press F1 → "AL: Download Symbols"
  
- [ ] **First Build Attempt**

  ```powershell
  # In VS Code, press Ctrl+Shift+B or F5
  # Expected: Extension builds successfully to .app file
  ```

**End of Day Checkpoint**:

```text
✓ All required software installed
✓ VS Code configured for AL development
✓ Symbols downloaded successfully
✓ Extension builds without errors
```

**Troubleshooting**: If build fails, see Section 3.3 "Common Setup Issues"

---

#### Day 3: First Successful Deployment

**Morning (9:00 AM - 12:00 PM)**:

- [ ] **Deploy to Sandbox**
  - [ ] Press F5 in VS Code
  - [ ] Wait for deployment to complete
  - [ ] BC should open in browser automatically
  
- [ ] **Verify Deployment**
  - [ ] Search for "eInvoice Setup Card" in BC
  - [ ] Can you open the page?
  - [ ] Do you see configuration fields?

**Afternoon (1:00 PM - 5:00 PM)**:

- [ ] **Explore the Extension in BC**
  - [ ] Navigate to Posted Sales Invoices
  - [ ] Look for "Sign & Submit to LHDN" action
  - [ ] Open eInvoice Submission Log
  - [ ] Familiarize yourself with the UI

- [ ] **Review Extension Metadata**
  - [ ] Open `app.json`
  - [ ] Note current version: 1.0.0.71
  - [ ] Understand ID ranges: 50300-50399
  - [ ] Review dependencies

**End of Day Checkpoint**:

```text
✓ Successfully deployed extension to sandbox
✓ Can navigate to eInvoice Setup Card
✓ Can see eInvoice actions on Posted Sales Invoices
✓ Understand extension structure and versioning
```

---

#### Day 4: Documentation Deep Dive

**Morning (9:00 AM - 12:00 PM)**:

- [ ] **Read Core Documentation**
  - [ ] Complete HANDOVER.md (all sections)
  - [ ] Read `MyInvois_LHDN_eInvoice_System_Documentation.md`
  - [ ] Take notes on unclear areas

**Afternoon (1:00 PM - 5:00 PM)**:

- [ ] **Read Technical Documentation**
  - [ ] `MyInvois_LHDN_Developer_Guide.md`
  - [ ] `MyInvois_LHDN_API_Integration_Guide.md`
  - [ ] `MyInvois_LHDN_Troubleshooting_Guide.md`

- [ ] **Create Personal Notes**
  - [ ] List questions for knowledge transfer session
  - [ ] Document unclear concepts
  - [ ] Identify areas needing clarification

**End of Day Checkpoint**:

```text
✓ Read all handover documentation
✓ Understand high-level architecture
✓ Have list of questions for previous developer
✓ Know where to find specific information
```

---

#### Day 5: Knowledge Transfer Session

**Morning (9:00 AM - 12:00 PM)**:

- [ ] **Session 1: Architecture Walkthrough** (2 hours)
  - [ ] Data flow: BC → Azure → LHDN
  - [ ] Key codeunits and responsibilities
  - [ ] Configuration in eInvoice Setup
  - [ ] Live demo of invoice submission

**Afternoon (1:00 PM - 5:00 PM)**:

- [ ] **Session 2: Common Issues & Resolutions** (1.5 hours)
  - [ ] "Invalid Structured Submission" debugging
  - [ ] Certificate renewal process
  - [ ] Token expiry handling
  - [ ] Real examples from production

- [ ] **Review Session Notes**
  - [ ] Organize notes from knowledge transfer
  - [ ] Update personal documentation
  - [ ] Clarify any remaining questions

**End of Week 1 Checkpoint**:

```text
✓ Development environment fully operational
✓ Can build and deploy extension
✓ Understand project architecture
✓ Have completed knowledge transfer sessions
✓ Ready to start hands-on exercises
```

---

### 2.2 Week 2: Hands-On Learning & Practical Exercises

**Objective**: Gain practical experience with the system through guided exercises.

#### Day 6-7: Exercise 1 - Generate and Submit Test Invoice

##### Day 6: Setup Test Data

##### Morning (9:00 AM - 12:00 PM)

- [ ] **Create Test Customer**

  ```text
  1. In BC Sandbox, go to Customers
  2. Create new customer:
     - No.: CUST-TEST-001
     - Name: Test Customer Sdn Bhd
     - TIN: C12345678901234 (test TIN)
     - Address: 123 Test Street
     - City: Kuala Lumpur
     - Post Code: 50000
     - Country/Region Code: MY
  3. Enable e-Invoice:
     - Requires e-Invoice: Yes
     - eInv Customer Name: Test Customer Sdn Bhd
     - eInv TIN: C12345678901234
  ```

- [ ] **Create Test Item**

  ```text
  1. Go to Items
  2. Create new item:
     - No.: ITEM-TEST-001
     - Description: Test Product
     - Unit Price: 100.00
     - Gen. Prod. Posting Group: RETAIL
     - VAT Prod. Posting Group: STANDARD
  ```

**Afternoon (1:00 PM - 5:00 PM)**:

- [ ] **Configure eInvoice Setup for PreProd**

  ```text
  1. Search "eInvoice Setup Card"
  2. Verify/Update:
     - Environment: PREPROD
     - Azure Function URL: [Get from previous developer]
     - Client ID: [PreProd credentials]
     - Client Secret: [PreProd credentials]
     - LHDN API URL: https://preprod-api.myinvois.hasil.gov.my
  ```

- [ ] **Verify Company Information**

  ```text
  1. Go to Company Information
  2. Ensure all eInvoice fields are populated:
     - eInv TIN
     - eInv Registration Name
     - eInv Address, City, Post Code
     - eInv MSIC Code
  ```

##### Day 7: Create and Submit Invoice

##### Morning (Day 7)

- [ ] **Create Sales Invoice**

  ```text
  1. Go to Sales Invoices
  2. Create new invoice:
     - Customer: CUST-TEST-001
     - Add line: ITEM-TEST-001, Quantity: 1
  3. Verify e-Invoice fields auto-populated
  4. Post the invoice
  ```

- [ ] **Submit to LHDN PreProd**

  ```text
  1. Go to Posted Sales Invoices
  2. Find your invoice
  3. Click "Sign & Submit to LHDN"
  4. Wait for confirmation message
  5. Expected: "Successfully submitted to LHDN"
  ```

**Afternoon (1:00 PM - 5:00 PM)**:

- [ ] **Verify Submission**

  ```text
  1. Check invoice fields:
     - eInvoice Validation Status: "Submitted"
     - eInvoice Submission UID: [populated]
     - eInvoice UUID: [populated]
  2. Open eInvoice Submission Log
  3. Find your submission entry
  4. Verify status: "Submitted"
  5. Check for QR code (may take a few minutes)
  ```

- [ ] **Document Your Experience**
  - [ ] What worked smoothly?
  - [ ] What was confusing?
  - [ ] How long did the process take?
  - [ ] Any errors encountered?

**Exercise 1 Completion Checkpoint**:

```text
✓ Created test customer with valid e-Invoice data
✓ Created test item
✓ Configured eInvoice Setup for PreProd
✓ Successfully posted sales invoice
✓ Successfully submitted invoice to LHDN
✓ Verified submission in log
✓ Understand end-to-end invoice flow
```

---

#### Day 8-9: Exercise 2 - Debug a Failed Submission

##### Day 8: Create Intentional Errors

##### Morning (Day 8)

- [ ] **Scenario 1: Missing TIN**

  ```text
  1. Create new customer: CUST-TEST-002
  2. DO NOT populate eInv TIN field
  3. Create and post sales invoice
  4. Attempt to submit
  5. Expected: Error message about missing TIN
  ```

- [ ] **Analyze the Error**
  - [ ] What was the exact error message?
  - [ ] Where did the validation occur? (Before or after API call?)
  - [ ] How user-friendly is the error message?

**Afternoon (1:00 PM - 5:00 PM)**:

- [ ] **Scenario 2: Invalid Azure Function URL**

  ```text
  1. Go to eInvoice Setup
  2. Modify Azure Function URL (add "xxx" to end)
  3. Create invoice for CUST-TEST-001
  4. Attempt to submit
  5. Expected: Azure Function connectivity error
  ```

- [ ] **Debug Using Submission Log**

  ```text
  1. Open eInvoice Submission Log
  2. Find the failed submission
  3. Read the error message
  4. Note the correlation ID
  5. Understand what information is logged
  ```

##### Day 9: Deep Debugging

##### Morning (Day 9)

- [ ] **Use Debugging Tools**

  ```text
  1. Open Cod50302.eInvoiceJSONGenerator.al in VS Code
  2. Set breakpoint in GetSignedInvoiceAndSubmitToLHDN
  3. Attach debugger (F5)
  4. Submit an invoice
  5. Step through the code
  6. Observe variable values
  ```

- [ ] **Understand Error Flow**
  - [ ] Where does error handling occur?
  - [ ] How are errors logged?
  - [ ] How are errors displayed to users?

**Afternoon (1:00 PM - 5:00 PM)**:

- [ ] **Fix the Errors**

  ```text
  1. Restore correct Azure Function URL
  2. Add TIN to CUST-TEST-002
  3. Resubmit failed invoices
  4. Verify successful submission
  ```

- [ ] **Download JSON for Analysis**

  ```text
  1. Use DownloadAzureFunctionPayloadForDebugging procedure
  2. Download generated JSON
  3. Review structure
  4. Validate against UBL 2.1 schema
  ```

**Exercise 2 Completion Checkpoint**:

```text
✓ Intentionally created validation errors
✓ Analyzed error messages and logging
✓ Used debugger to step through code
✓ Understand error handling flow
✓ Can use submission log for diagnostics
✓ Can download and analyze JSON payloads
```

---

#### Day 10: Exercise 3 - Deploy a Minor Change

**Morning (9:00 AM - 12:00 PM)**:

- [ ] **Make a Cosmetic Change**

  ```al
  // In Pag-Ext50306.eInvPostedSalesInvoiceExt.al
  // Find the "Sign & Submit to LHDN" action
  // Change the caption to "Sign & Submit to LHDN (Test)"
  
  action(SignAndSubmit)
  {
      Caption = 'Sign & Submit to LHDN (Test)';
      // ... rest of action
  }
  ```

- [ ] **Update Version Number**

  ```json
  // In app.json
  "version": "1.0.0.72"  // Increment from 1.0.0.71
  ```

**Afternoon (1:00 PM - 5:00 PM)**:

- [ ] **Build and Deploy**

  ```text
  1. Save all files
  2. Press Ctrl+Shift+B to build
  3. Verify .app file created: KMAX_KMAXDev_1.0.0.72.app
  4. Press F5 to deploy to sandbox
  5. Wait for deployment to complete
  ```

- [ ] **Verify the Change**

  ```text
  1. Go to Posted Sales Invoices in BC
  2. Check if action caption changed
  3. Test that functionality still works
  4. Submit a test invoice to verify no regression
  ```

- [ ] **Rollback the Change**

  ```text
  1. Revert caption to original
  2. Revert version to 1.0.0.71
  3. Rebuild and redeploy
  4. Verify rollback successful
  ```

**Exercise 3 Completion Checkpoint**:

```text
✓ Made code modification
✓ Updated version number
✓ Built extension successfully
✓ Deployed to sandbox
✓ Verified change in UI
✓ Tested functionality
✓ Rolled back changes
✓ Understand deployment workflow
```

**End of Week 2 Checkpoint**:

```text
✓ Completed all three hands-on exercises
✓ Can create and submit invoices
✓ Can debug failed submissions
✓ Can deploy changes to sandbox
✓ Comfortable with development workflow
```

---

### 2.3 Week 3: Deep Dive into Codebase

**Objective**: Understand the codebase architecture and key components in detail.

#### Day 11-12: Code Walkthrough - JSON Generator

##### Day 11: Understanding the Main Flow

- [ ] **Study Cod50302.eInvoiceJSONGenerator.al**

  ```text
  1. Open the file (327KB, ~7,000 lines)
  2. Review file outline (Ctrl+Shift+O in VS Code)
  3. Identify main procedures:
     - GetSignedInvoiceAndSubmitToLHDN
     - GenerateEInvoiceJson
     - TryPostToAzureFunctionDirect
     - SubmitToLhdnApi
  ```

- [ ] **Trace Invoice Submission Flow**

  ```text
  1. Start at GetSignedInvoiceAndSubmitToLHDN
  2. Follow the call chain
  3. Document each step in your notes
  4. Understand data transformations
  ```

- [ ] **Understand UBL 2.1 Structure**
  - [ ] Read about UBL 2.1 standard
  - [ ] Review JSON structure in generated files
  - [ ] Understand namespace conventions (_D,_A, _B)

##### Day 12: Deep Dive into Helper Procedures

- [ ] **Study JSON Building Procedures**

  ```text
  - BuildEInvoiceJson()
  - AddAccountingSupplierParty()
  - AddAccountingCustomerParty()
  - AddInvoiceLines()
  - AddTaxTotal()
  ```

- [ ] **Understand Error Handling**
  - [ ] How are errors caught?
  - [ ] How are they logged?
  - [ ] How are they reported to users?

- [ ] **Review Retry Logic**
  - [ ] Where is retry implemented?
  - [ ] How many retries?
  - [ ] What is the backoff strategy?

---

#### Day 13-14: Azure Function Integration

##### Day 13: Understanding Azure Function

- [ ] **Review Azure Function Code** (if accessible)
  - [ ] Request access to eInvAzureSign repository
  - [ ] Review SignDocument function
  - [ ] Understand certificate loading
  - [ ] Understand XAdES signing process

- [ ] **Study BC-Azure Communication**

  ```al
  // In Cod50302
  - TryPostToAzureFunctionDirect()
  - How is HTTP request constructed?
  - What is sent in payload?
  - What is expected in response?
  ```

##### Day 14: Testing Azure Integration

- [ ] **Test Azure Function Directly**

  ```bash
  # Use Postman or curl
  curl -X POST [Azure Function URL] \
    -H "Content-Type: application/json" \
    -d @test-payload.json
  ```

- [ ] **Understand Response Handling**
  - [ ] What does successful response look like?
  - [ ] What error responses are possible?
  - [ ] How does BC handle each response type?

---

#### Day 15: LHDN API Integration

- [ ] **Study LHDN API Documentation**
  - [ ] Review `MyInvois_LHDN_API_Integration_Guide.md`
  - [ ] Understand authentication (OAuth 2.0)
  - [ ] Review API endpoints used

- [ ] **Trace LHDN Submission Flow**

  ```al
  // In Cod50302
  - SubmitToLhdnApi()
  - GetLhdnAccessToken()
  - ParseAndDisplayLhdnResponse()
  ```

- [ ] **Understand Token Management**
  - [ ] Where is token cached?
  - [ ] How is expiry handled?
  - [ ] What happens on token refresh?

**End of Week 3 Checkpoint**:

```text
✓ Understand Cod50302 structure and flow
✓ Can trace invoice submission end-to-end
✓ Understand UBL 2.1 JSON generation
✓ Understand Azure Function integration
✓ Understand LHDN API integration
✓ Comfortable reading and navigating codebase
```

---

### 2.4 Week 4: Production Readiness & Certification

**Objective**: Prepare for production support and validate knowledge.

#### Day 16-18: Production Monitoring

##### Day 16: Log Analysis

- [ ] **Access Production Submission Log** (read-only)

  ```text
  1. Login to BC Production
  2. Open eInvoice Submission Log
  3. Review last 100 submissions
  4. Identify patterns:
     - Success rate
     - Common errors
     - Peak submission times
  ```

- [ ] **Analyze Failed Submissions**
  - [ ] What are the most common failure reasons?
  - [ ] Are there patterns (time of day, specific customers)?
  - [ ] How were they resolved?

##### Day 17: Azure Monitoring

- [ ] **Review Azure Function Metrics**

  ```text
  1. Login to Azure Portal
  2. Navigate to Function App
  3. Review metrics:
     - Request count
     - Response time
     - Error rate
  4. Review Application Insights logs
  ```

##### Day 18: Support Ticket Review

- [ ] **Review Historical Support Tickets**
  - [ ] Read last 10 support tickets
  - [ ] Understand common user issues
  - [ ] Review resolution approaches

---

#### Day 19-20: Support Simulation

##### Day 19: Scenario-Based Troubleshooting

- [ ] **Scenario 1: User reports "Invoice won't submit"**

  ```text
  Your approach:
  1. Ask for invoice number
  2. Check submission log
  3. Verify customer data
  4. Check Azure Function health
  5. Test submission in sandbox
  6. Provide resolution
  ```

- [ ] **Scenario 2: "QR code not showing"**

  ```text
  Your approach:
  1. Check if submission succeeded
  2. Verify Submission UID and UUID populated
  3. Manually trigger QR generation
  4. Check LHDN API response
  5. Explain timing to user
  ```

##### Day 20: Emergency Response Drill

- [ ] **Scenario: Azure Function is down**

  ```text
  Your response plan:
  1. Verify Azure Function status
  2. Check Azure Portal for alerts
  3. Restart function if needed
  4. Test with sample invoice
  5. Communicate with users
  6. Document incident
  ```

---

#### Day 21-25: Independent Feature Implementation

- [ ] **Choose a Small Enhancement**

  ```text
  Examples:
  - Add a new field to submission log
  - Improve error message clarity
  - Add validation for a specific scenario
  - Create a utility report
  ```

- [ ] **Implement the Feature**

  ```text
  Day 21: Design and plan
  Day 22-23: Implement
  Day 24: Test in sandbox
  Day 25: Code review with previous developer
  ```

---

#### Day 26-30: Knowledge Validation & Certification

##### Day 26-27: Self-Assessment

- [ ] **Technical Quiz** (create your own or request from previous developer)
  - [ ] Architecture questions
  - [ ] Code comprehension questions
  - [ ] Troubleshooting scenarios

##### Day 28-29: Documentation Update

- [ ] **Update Handover Documentation**
  - [ ] Add any missing information you discovered
  - [ ] Clarify confusing sections
  - [ ] Add your own tips and tricks

##### Day 30: Final Review & Sign-Off

- [ ] **Final Knowledge Transfer Session**
  - [ ] Review any remaining questions
  - [ ] Discuss edge cases
  - [ ] Review escalation procedures

- [ ] **Certification Checklist**

  ```text
  ✓ Can independently submit invoices
  ✓ Can debug common issues
  ✓ Can deploy changes safely
  ✓ Can monitor production
  ✓ Can handle support tickets
  ✓ Know when to escalate
  ✓ Understand all critical components
  ✓ Have access to all necessary systems
  ```

**End of 30-Day Onboarding**:

```text
✓ Fully onboarded and production-ready
✓ Can independently maintain the system
✓ Confident in troubleshooting and support
✓ Ready to take over from previous developer
```

---

## 3. Development Environment Setup

### 3.1 Prerequisites - Detailed Installation Guide

#### Required Software with Version Verification

##### 1. Visual Studio Code

```powershell
# Download and install from: https://code.visualstudio.com/
# After installation, verify:
code --version
# Expected output: 1.85.0 or higher
```

##### Installation Steps

1. Download VS Code installer for Windows
2. Run installer with default settings
3. Check "Add to PATH" during installation
4. Launch VS Code to verify

##### 2. AL Language Extension

```text
1. Open VS Code
2. Press Ctrl+Shift+X (Extensions)
3. Search for "AL Language"
4. Install "AL Language extension for Microsoft Dynamics 365 Business Central"
5. Verify version: v13.0 or higher
```

##### 3. Git for Windows

```powershell
# Download from: https://git-scm.com/download/win
# After installation, verify:
git --version
# Expected output: git version 2.40.0 or higher
```

##### Configuration

```bash
# Set your identity
git config --global user.name "Your Name"
git config --global user.email "your.email@company.com"

# Verify configuration
git config --list
```

##### 4. Docker Desktop (Optional - for local BC containers)

```powershell
# Download from: https://www.docker.com/products/docker-desktop
# After installation, verify:
docker --version
# Expected output: Docker version 24.0.0 or higher

docker ps
# Should show empty list (no errors)
```

> [!NOTE]
> Docker is only needed if you want to run Business Central in local containers. For cloud-based development, you can skip this.

##### 5. Azure CLI

```powershell
# Download from: https://aka.ms/installazurecliwindows
# After installation, verify:
az --version
# Expected output: azure-cli 2.50.0 or higher

# Login to Azure
az login
# This will open browser for authentication
```

##### 6. Postman (or similar API testing tool)

```text
# Download from: https://www.postman.com/downloads/
# Alternative: Use VS Code REST Client extension
```

#### Verification Checklist

After installing all prerequisites, verify:

```powershell
# Run this verification script
Write-Host "=== Environment Verification ==="
Write-Host "VS Code: " -NoNewline; code --version | Select-Object -First 1
Write-Host "Git: " -NoNewline; git --version
Write-Host "Docker: " -NoNewline; docker --version
Write-Host "Azure CLI: " -NoNewline; az version --query '"azure-cli"' -o tsv
Write-Host "=== Verification Complete ==="
```

##### Expected Output

```text
=== Environment Verification ===
VS Code: 1.85.0
Git: git version 2.40.1.windows.1
Docker: Docker version 24.0.5, build ced0996
Azure CLI: 2.53.0
=== Verification Complete ===
```

### 3.2 Local Development Setup

#### Step 1: Clone Repository

```bash
git clone https://github.com/your-org/Jotex-BC-eInvoice.git
cd Jotex-BC-eInvoice
```

#### Step 2: Configure VS Code

Create `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "al",
      "request": "launch",
      "name": "BC Sandbox",
      "server": "https://businesscentral.dynamics.com",
      "serverInstance": "BC220",
      "tenant": "your-tenant-id",
      "authentication": "AAD",
      "startupObjectId": 50300,
      "startupObjectType": "Page",
      "breakOnError": true,
      "launchBrowser": true
    }
  ]
}
```

#### Step 3: Download Symbols

```powershell
# In VS Code, press F1 and run:
AL: Download Symbols
```

#### Step 4: Build Extension

```powershell
# Press Ctrl+Shift+B or F5 to build and deploy
```

### 3.3 Common Setup Issues & Solutions

#### Issue 1: Symbol Download Fails

##### Symptoms: Symbol Download

- "Failed to download symbols" error
- AL extension shows errors on all standard BC objects

##### Possible Causes & Solutions

###### Cause 1: Network/Firewall Issues

```powershell
# Test connectivity to BC service
Test-NetConnection -ComputerName businesscentral.dynamics.com -Port 443

# If fails, check:
# 1. Corporate firewall settings
# 2. Proxy configuration
# 3. VPN connection
```

###### Cause 2: Authentication Issues

```text
Solution:
1. In VS Code, press F1
2. Run "AL: Clear Credentials Cache"
3. Try downloading symbols again
4. Re-authenticate when prompted
```

###### Cause 3: Incorrect launch.json Configuration

```json
// Verify these fields in launch.json:
{
  "server": "https://businesscentral.dynamics.com",  // Correct URL
  "serverInstance": "BC220",  // Match your BC version
  "tenant": "your-actual-tenant-id",  // Not placeholder!
  "authentication": "AAD"  // For cloud BC
}
```

---

#### Issue 2: Build Fails with Dependency Errors

##### Symptoms: Build Failures

- "Could not find dependency" errors
- Missing .alpackages folder

##### Solution: Fix Dependencies

```powershell
# 1. Ensure .alpackages folder exists
New-Item -ItemType Directory -Force -Path ".alpackages"

# 2. Download symbols again
# In VS Code: F1 → "AL: Download Symbols"

# 3. Check app.json dependencies
# Verify dependency versions match your BC environment
```

##### Verify Dependencies

```json
// In app.json, check:
"dependencies": [
  {
    "id": "e41c95d1-d093-45cf-a32e-7e3c52721a20",
    "name": "SalesPurchaseReport",
    "publisher": "Evopoint Izzat",
    "version": "1.0.0.200"  // Must be available in your environment
  }
]
```

---

#### Issue 3: Deployment Fails

##### Symptoms: Deployment Failures

- Extension builds but deployment fails
- "Could not publish extension" error

##### Solution 1: Check Permissions

```text
1. Verify you have permission to publish extensions
2. In BC, check your user role includes:
   - D365 EXTENSION MGT
   - SUPER (for sandbox)
```

##### Solution 2: Uninstall Previous Version

```text
1. In BC, search "Extension Management"
2. Find "KMAXDev" extension
3. Uninstall if already installed
4. Try deployment again
```

##### Solution 3: Check Version Conflict

```json
// In app.json, ensure version is incremented
"version": "1.0.0.72"  // Higher than currently installed version
```

---

#### Issue 4: Debugger Won't Attach

##### Symptoms: Debugger Issues

- Breakpoints not hit
- Debugger shows "Disconnected"

##### Solution: Fix Debugger Configuration

```json
// In launch.json, ensure:
{
  "breakOnError": true,
  "breakOnRecordWrite": false,  // Can cause issues if true
  "enableSqlInformationDebugger": true,
  "enableLongRunningSqlStatements": true
}
```

##### Alternative: Use Snapshot Debugging

```text
1. In BC, enable snapshot debugging
2. In VS Code: F1 → "AL: Enable Snapshot Debugging"
3. Set breakpoints and trigger code
```

### 3.4 Environment Configuration Templates

#### Complete launch.json Template

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "BC Sandbox (Cloud)",
      "type": "al",
      "request": "launch",
      "server": "https://businesscentral.dynamics.com",
      "serverInstance": "BC220",
      "tenant": "your-tenant-id",
      "authentication": "AAD",
      "startupObjectId": 50300,
      "startupObjectType": "Page",
      "breakOnError": true,
      "launchBrowser": true,
      "enableLongRunningSqlStatements": true,
      "enableSqlInformationDebugger": true,
      "schemaUpdateMode": "Synchronize"
    },
    {
      "name": "BC Production (Read-Only)",
      "type": "al",
      "request": "attach",
      "server": "https://businesscentral.dynamics.com",
      "serverInstance": "BC220-PROD",
      "tenant": "your-prod-tenant-id",
      "authentication": "AAD",
      "breakOnError": false,
      "breakOnNext": "None"
    }
  ]
}
```

#### Recommended settings.json

```json
{
  "al.enableCodeAnalysis": true,
  "al.codeAnalyzers": [
    "${CodeCop}",
    "${UICop}",
    "${PerTenantExtensionCop}"
  ],
  "al.enableCodeActions": true,
  "al.incrementalBuild": true,
  "editor.formatOnSave": true,
  "files.autoSave": "afterDelay",
  "files.autoSaveDelay": 1000,
  "[al]": {
    "editor.defaultFormatter": "ms-dynamics-smb.al",
    "editor.formatOnSave": true
  },
  "git.autofetch": true,
  "git.confirmSync": false
}
```

#### .gitignore for BC Projects

```gitignore
# AL-specific
.alpackages/
.alcache/
.vscode/.alcache/
*.app

# Build output
.output/
.artifacts/

# VS Code
.vscode/settings.json
.vscode/launch.json

# OS
.DS_Store
Thumbs.db

# Logs
*.log

# Temporary files
*.tmp
*.bak
```

### 3.5 First Build Validation Checklist

After completing environment setup, verify everything works:

#### Pre-Build Checklist

```text
[ ] Repository cloned successfully
[ ] All prerequisites installed and verified
[ ] launch.json configured with correct tenant ID
[ ] settings.json created with recommended settings
[ ] .gitignore file present
[ ] Symbols downloaded (check .alpackages folder has files)
[ ] No red squiggly lines in AL files (IntelliSense working)
```

#### Build Checklist

```text
[ ] Press Ctrl+Shift+B (Build)
[ ] Build completes without errors
[ ] .app file created in project root
[ ] App file size is reasonable (~280KB for this project)
[ ] No warnings about missing dependencies
```

#### Deployment Checklist

```text
[ ] Press F5 (Deploy and Debug)
[ ] Extension publishes successfully
[ ] Extension synchronizes successfully
[ ] Extension installs successfully
[ ] Browser opens to BC
[ ] Can navigate to eInvoice Setup Card
[ ] Can see eInvoice actions on Posted Sales Invoices
```

#### Post-Deployment Verification

```powershell
# In BC, verify extension is installed:
# 1. Search "Extension Management"
# 2. Find "KMAXDev" extension
# 3. Status should be "Installed"
# 4. Version should match app.json
```

**Verification Script**:

```text
1. Open Posted Sales Invoices in BC
2. Look for these custom actions:
   - "Sign & Submit to LHDN"
   - "View Submission Log"
   - "Download JSON"
3. If visible, extension is working correctly
```

**Troubleshooting Failed Verification**:

```text
If actions not visible:
1. Check Extension Management - is extension installed?
2. Check user permissions - do you have eInvoice Full Access?
3. Refresh browser (Ctrl+F5)
4. Check browser console for JavaScript errors
```

### 3.3 Azure Function Local Development

#### Setup Azure Functions Core Tools

```bash
# Install Azure Functions Core Tools
npm install -g azure-functions-core-tools@4

# Navigate to Azure Function project
cd ../eInvAzureSign  # Separate repository

# Install dependencies
dotnet restore

# Run locally
func start
```

#### Test Local Azure Function

```bash
# Test the signing endpoint
curl -X POST http://localhost:7071/api/SignDocument \
  -H "Content-Type: application/json" \
  -d '{
    "unsignedJson": "...",
    "invoiceType": "01",
    "environment": "PREPROD"
  }'
```

### 3.4 Database Access (Optional)

For deep debugging, you may need direct database access:

```sql
-- Connect to BC database (on-prem only)
-- Query submission log
SELECT TOP 100 
    [Invoice No_],
    [Status],
    [Submission Date],
    [Error Message]
FROM [eInvoice Submission Log]
ORDER BY [Submission Date] DESC;
```

---

## 4. Architecture Deep Dive

### 4.1 System Architecture Diagram

```plaintext
┌─────────────────────────────────────────────────────────────────┐
│                     Business Central                             │
│                                                                  │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────────┐  │
│  │ Sales Invoice│─────▶│ eInvoice JSON│─────▶│ Azure Function│  │
│  │   Posting    │      │  Generator   │      │    Client     │  │
│  └──────────────┘      └──────────────┘      └───────┬────────┘  │
│                                                       │           │
└───────────────────────────────────────────────────────┼───────────┘
                                                        │
                                                        ▼
                                            ┌───────────────────┐
                                            │  Azure Function   │
                                            │  (Document Sign)  │
                                            └─────────┬─────────┘
                                                      │
                                                      ▼
                                            ┌───────────────────┐
                                            │   LHDN MyInvois   │
                                            │       API         │
                                            └───────────────────┘
```

### 4.2 Data Flow Sequence

#### 4.2.1 Invoice Submission Flow

```text
1. User Action
   └─▶ User posts Sales Invoice OR clicks "Sign & Submit to LHDN"

2. Field Population (Automatic)
   └─▶ Cod50306.eInvFieldPopulation
       ├─▶ Copies e-Invoice fields from Sales Header to Posted Invoice
       └─▶ Validates mandatory fields (TIN, Address, etc.)

3. JSON Generation
   └─▶ Cod50302.GenerateEInvoiceJson()
       ├─▶ Builds UBL 2.1 JSON structure
       ├─▶ Adds supplier party (Company Info)
       ├─▶ Adds customer party (Customer record)
       ├─▶ Adds invoice lines with tax details
       └─▶ Returns unsigned JSON string

4. Azure Function Signing
   └─▶ Cod50302.TryPostToAzureFunctionDirect()
       ├─▶ HTTP POST to Azure Function URL
       ├─▶ Payload: { unsignedJson, invoiceType, environment }
       ├─▶ Azure Function loads P12 certificate
       ├─▶ Signs JSON using XAdES
       └─▶ Returns: { success, signedJson, lhdnPayload }

5. LHDN Submission
   └─▶ Cod50302.SubmitToLhdnApi()
       ├─▶ Extracts lhdnPayload from Azure response
       ├─▶ Gets LHDN access token (OAuth 2.0)
       ├─▶ HTTP POST to LHDN API /documentsubmissions
       └─▶ Receives: { submissionUid, acceptedDocuments, rejectedDocuments }

6. Status Update
   └─▶ Cod50302.UpdateSalesInvoiceWithLhdnResponse()
       ├─▶ Updates "eInvoice Validation Status" field
       ├─▶ Stores Submission UID and Document UUID
       └─▶ Logs to eInvoice Submission Log table

7. QR Code Generation (Background)
   └─▶ Cod50302.TryFetchAndStoreValidationLink()
       ├─▶ Fetches longId from LHDN (retry logic)
       ├─▶ Builds validation URL
       └─▶ Generates and stores QR code image
```

### 4.3 Why This Architecture?

#### Design Decision: Sidecar Pattern

**Problem**: Business Central cannot perform complex cryptographic operations (P12 certificate signing with XAdES).

**Solution**: Offload signing to Azure Function.

**Benefits**:

- **Separation of Concerns**: BC handles business logic, Azure handles crypto
- **Security**: Certificate never leaves Azure (stored in Key Vault)
- **Scalability**: Azure Functions auto-scale under load
- **Maintainability**: Crypto logic isolated from BC codebase

**Trade-offs**:

- **Network Dependency**: Requires reliable internet connection
- **Latency**: Additional HTTP round-trip (~500ms-2s)
- **Complexity**: Two deployment targets (BC + Azure)

---

## 5. Critical Components Reference

### 5.1 Core Codeunits

#### Cod50302: eInvoice JSON Generator

**Location**: `Cod50302.eInvoiceJSONGenerator.al`  
**Lines of Code**: ~7,000  
**Responsibility**: The "brain" of the system

**Key Procedures**:

```al
// Main entry point for invoice submission
procedure GetSignedInvoiceAndSubmitToLHDN(
    SalesInvoiceHeader: Record "Sales Invoice Header"; 
    var LhdnResponse: Text
): Boolean

// Generates unsigned UBL 2.1 JSON
procedure GenerateEInvoiceJson(
    SalesInvoiceHeader: Record "Sales Invoice Header"; 
    IncludeSignature: Boolean
): Text

// Credit memo variant
procedure GetSignedCreditMemoAndSubmitToLHDN(
    SalesCrMemoHeader: Record "Sales Cr.Memo Header"; 
    var LhdnResponse: Text
): Boolean
```

**Critical Internal Procedures**:

- `BuildEInvoiceJson()`: Constructs UBL structure
- `AddAccountingSupplierParty()`: Company information
- `AddAccountingCustomerParty()`: Customer information
- `AddInvoiceLines()`: Line items with tax
- `TryPostToAzureFunctionDirect()`: Azure communication
- `SubmitToLhdnApi()`: LHDN API submission
- `ParseAndDisplayLhdnResponse()`: Response handling

**Error Handling**:

- Validates all mandatory fields before generation
- Retry logic for Azure Function (3 attempts with exponential backoff)
- Detailed error logging to Submission Log

#### Cod50310: eInvoiceAzureFunctionClient

**Location**: `Cod50310.eInvoiceAzureFunctionClient.al`  
**Responsibility**: HTTP client for Azure Function

**Note**: Most Azure communication is now in `Cod50302` for better cohesion. This codeunit may be deprecated in future versions.

#### Cod50312: eInvoiceSubmissionStatus

**Location**: `Cod50312.eInvoiceSubmissionStatus.al`  
**Responsibility**: Status tracking and retrieval

**Key Procedures**:

- `GetSubmissionStatus()`: Polls LHDN for submission status
- `GetDocumentDetails()`: Retrieves document metadata
- `UpdateStatusFromLhdn()`: Syncs status from LHDN

### 5.2 Tables

#### Tab50300: eInvoiceSetup

**Purpose**: System configuration (singleton table)

**Critical Fields**:

```al
field(1; "Primary Key"; Code[10]) { }
field(10; "Azure Function URL"; Text[250]) { }
field(20; "Environment"; Enum "eInvoice Environment") { }  // PREPROD | PRODUCTION
field(30; "Client ID"; Text[100]) { }
field(40; "Client Secret"; Text[100]) { }  // ⚠️ Security: Should use Isolated Storage
field(50; "LHDN API URL"; Text[250]) { }
field(60; "Last Token"; Text[2048]) { }
field(70; "Token Timestamp"; DateTime) { }
field(80; "Token Expiry (s)"; Integer) { }
```

**Access**: Search "eInvoice Setup Card" in BC

#### Tab50312: eInvoice Submission Log

**Purpose**: Audit trail of all submissions

**Critical Fields**:

```al
field(1; "Entry No."; Integer) { AutoIncrement = true; }
field(10; "Invoice No."; Code[20]) { }
field(20; "Submission Date"; DateTime) { }
field(30; "Status"; Text[50]) { }  // Submitted | Failed | Pending
field(40; "Submission UID"; Text[100]) { }  // LHDN reference
field(50; "Document UUID"; Text[100]) { }  // LHDN document ID
field(60; "Error Message"; Text[2048]) { }
field(70; "Correlation ID"; Text[50]) { }  // For tracing
field(80; "Environment"; Enum "eInvoice Environment") { }
```

**Usage**: Primary debugging tool. Always check this first when investigating issues.

### 5.3 Page Extensions

#### Pag-Ext50306: eInvPostedSalesInvoiceExt

**Extends**: Posted Sales Invoice (Page 132)

**Added Actions**:

- **"Sign & Submit to LHDN"**: Main submission action
- **"View Submission Log"**: Opens related log entries
- **"Download JSON"**: Debug action to download generated JSON
- **"Validate TIN"**: Validates customer TIN with LHDN

**Added Fields**:

- eInvoice Validation Status
- eInvoice Submission UID
- eInvoice UUID
- eInv QR URL

---

## 6. Operational Workflows

### 6.1 Normal Invoice Processing

#### User Workflow

```text
1. Create Sales Invoice
   └─▶ Ensure customer has "Requires e-Invoice" = Yes

2. Post Invoice
   └─▶ System auto-populates e-Invoice fields
   └─▶ (Optional) Auto-submit if configured

3. Manual Submission (if not auto)
   └─▶ Open Posted Sales Invoice
   └─▶ Click "Sign & Submit to LHDN"
   └─▶ Wait for confirmation message

4. Verify Submission
   └─▶ Check "eInvoice Validation Status" = "Submitted"
   └─▶ Note the Submission UID
```

#### System Workflow (Behind the Scenes)

```text
1. Posting Trigger
   └─▶ Codeunit 80 "Sales-Post" (standard BC)
   └─▶ Event: OnAfterPostSalesDoc
   └─▶ Subscriber: Cod50305.CopyEInvoiceHeaderFieldsAndAutoSubmit()

2. Field Copy
   └─▶ Copies all e-Invoice fields from Sales Header to Posted Invoice
   └─▶ Validates mandatory fields

3. Auto-Submit (if enabled)
   └─▶ Calls Cod50302.GetSignedInvoiceAndSubmitToLHDN()
   └─▶ Entire flow executes automatically

4. Status Update
   └─▶ Posted Invoice updated with status
   └─▶ User sees confirmation or error message
```

### 6.2 Credit Memo Processing

**Important**: Credit memos follow similar flow but use different UBL structure.

#### Key Differences

- Document Type Code: `02` (Credit Note)
- Requires `BillingReference` to original invoice (if available)
- Amounts are positive in LHDN submission (system handles conversion)

#### Workflow

```text
1. Create Credit Memo
   └─▶ Link to original invoice via "Applies-to Doc. No." (recommended)

2. Post Credit Memo
   └─▶ System generates Credit Note JSON

3. Submit
   └─▶ Click "Sign & Submit to LHDN" on Posted Credit Memo
   └─▶ System uses Cod50302.GetSignedCreditMemoAndSubmitToLHDN()
```

### 6.3 Batch Processing

For processing multiple documents:

```al
// Example: Batch submit all pending invoices
procedure BatchSubmitPendingInvoices()
var
    SalesInvoiceHeader: Record "Sales Invoice Header";
    eInvoiceGenerator: Codeunit "eInvoice JSON Generator";
    LhdnResponse: Text;
    SuccessCount: Integer;
    FailCount: Integer;
begin
    SalesInvoiceHeader.SetRange("eInvoice Validation Status", '');
    SalesInvoiceHeader.SetFilter("Sell-to Customer No.", '<>''''');
    
    if SalesInvoiceHeader.FindSet() then
        repeat
            if eInvoiceGenerator.GetSignedInvoiceAndSubmitToLHDN(SalesInvoiceHeader, LhdnResponse) then
                SuccessCount += 1
            else
                FailCount += 1;
            
            Commit();  // Commit after each to prevent rollback
            Sleep(500);  // Rate limiting
        until SalesInvoiceHeader.Next() = 0;
    
    Message('Batch complete. Success: %1, Failed: %2', SuccessCount, FailCount);
end;
```

---

## 7. Testing & Quality Assurance

### 7.1 Test Environments

#### PreProd Environment

- **LHDN URL**: `https://preprod-api.myinvois.hasil.gov.my`
- **Purpose**: All development and testing
- **Data**: Use test customers and items
- **Credentials**: Separate Client ID/Secret from production

#### Production Environment

- **LHDN URL**: `https://api.myinvois.hasil.gov.my`
- **Purpose**: Live business transactions
- **Access**: Restricted, requires approval
- **Monitoring**: Enhanced logging and alerting

### 7.2 Test Scenarios

#### Scenario 1: Standard Invoice

```text
Given: Customer with valid TIN and complete address
When: Post sales invoice with 1 item line
Then: 
  - JSON generated successfully
  - Azure Function signs document
  - LHDN accepts submission
  - Status = "Submitted"
  - Submission UID populated
```

#### Scenario 2: Credit Note with Reference

```text
Given: Posted invoice already submitted to LHDN
When: Create credit memo with "Applies-to Doc. No." = invoice number
Then:
  - Credit Note JSON includes BillingReference
  - LHDN links credit note to original invoice
```

#### Scenario 3: Invalid Customer Data

```text
Given: Customer with missing TIN
When: Attempt to submit invoice
Then:
  - Validation error before submission
  - Clear error message to user
  - No API call made
```

#### Scenario 4: Network Failure

```text
Given: Azure Function is unreachable
When: Attempt to submit invoice
Then:
  - Retry logic executes (3 attempts)
  - User sees timeout error
  - Submission log shows "Failed" with error details
```

### 7.3 Automated Testing

#### Unit Tests (if implemented)

```al
[Test]
procedure TestJsonGeneration()
var
    SalesInvoiceHeader: Record "Sales Invoice Header";
    JsonText: Text;
begin
    // Arrange
    CreateTestInvoice(SalesInvoiceHeader);
    
    // Act
    JsonText := GenerateEInvoiceJson(SalesInvoiceHeader, false);
    
    // Assert
    Assert.AreNotEqual('', JsonText, 'JSON should not be empty');
    Assert.IsTrue(JsonText.Contains('"Invoice"'), 'Should contain Invoice element');
end;
```

### 7.4 Manual Testing Checklist

Before each release:

- [ ] Test standard invoice submission (PreProd)
- [ ] Test credit memo submission (PreProd)
- [ ] Test with missing mandatory fields (should fail gracefully)
- [ ] Test Azure Function connectivity
- [ ] Test LHDN API connectivity
- [ ] Verify submission log entries
- [ ] Test QR code generation
- [ ] Test batch processing (10 invoices)
- [ ] Verify error messages are user-friendly

---

## 8. Deployment Procedures

### 8.1 Extension Deployment to Business Central

#### Step 1: Build Extension

```powershell
# In VS Code
# Press F5 or Ctrl+Shift+B
# Or use command line:
alc.exe /project:"c:\path\to\project" /packagecachepath:"c:\path\to\.alpackages"
```

#### Step 2: Publish to Sandbox

```powershell
# Using BC Admin Center or PowerShell
Publish-NAVApp -ServerInstance BC220 -Path ".\KMAXDev.app" -SkipVerification
Install-NAVApp -ServerInstance BC220 -Name "KMAXDev" -Version "1.0.0.62"
```

#### Step 3: Test in Sandbox

- Run through test scenarios
- Verify no regressions
- Check submission log

#### Step 4: Deploy to Production

```powershell
# Schedule during maintenance window
# Backup current version first
Publish-NAVApp -ServerInstance BC220-PROD -Path ".\KMAXDev.app"
Sync-NAVApp -ServerInstance BC220-PROD -Name "KMAXDev" -Version "1.0.0.62"
Install-NAVApp -ServerInstance BC220-PROD -Name "KMAXDev" -Version "1.0.0.62"
```

### 8.2 Azure Function Deployment

#### Step 1: Build Function

```bash
cd eInvAzureSign
dotnet build --configuration Release
```

#### Step 2: Deploy to Azure

```bash
# Using Azure CLI
az functionapp deployment source config-zip \
  --resource-group rg-myinvois-prod \
  --name func-myinvois-prod \
  --src ./publish.zip
```

#### Step 3: Verify Deployment

```bash
# Test health endpoint
curl https://func-myinvois-prod.azurewebsites.net/api/health

# Test signing endpoint (with valid payload)
curl -X POST https://func-myinvois-prod.azurewebsites.net/api/SignDocument \
  -H "Content-Type: application/json" \
  -d @test-payload.json
```

### 8.3 Rollback Procedures

#### BC Extension Rollback

```powershell
# Uninstall current version
Uninstall-NAVApp -ServerInstance BC220-PROD -Name "KMAXDev" -Version "1.0.0.62"

# Reinstall previous version
Install-NAVApp -ServerInstance BC220-PROD -Name "KMAXDev" -Version "1.0.0.61"
```

#### Azure Function Rollback

```bash
# Swap deployment slots
az functionapp deployment slot swap \
  --resource-group rg-myinvois-prod \
  --name func-myinvois-prod \
  --slot staging \
  --target-slot production
```

---

## 9. Troubleshooting Guide

### 9.1 Common Issues

#### Issue 1: "Invalid Structured Submission"

**Symptom**: LHDN rejects submission with this error

**Root Cause**: JSON structure doesn't match UBL 2.1 schema

**Debug Steps**:

1. Run `DownloadAzureFunctionPayloadForDebugging()` in Cod50302
2. Download the generated JSON files
3. Validate against LHDN validator: <https://sdk.myinvois.hasil.gov.my/>
4. Check for:
   - Missing mandatory fields
   - Incorrect namespace declarations
   - Invalid field formats (dates, amounts)

**Common Fixes**:

- Ensure UBL namespaces are correct: `_D`, `_A`, `_B`
- Verify all amounts have `currencyID` attribute
- Check date format: `YYYY-MM-DD`
- Validate array structures (must be arrays, not objects)

#### Issue 2: Azure Function Timeout

**Symptom**: "Failed to communicate with Azure Function"

**Debug Steps**:

1. Check Azure Function URL in eInvoice Setup
2. Test connectivity: `TestAzureFunctionConnectivity()` in Cod50302
3. Check Azure Function logs in Azure Portal
4. Verify certificate is loaded correctly

**Common Fixes**:

- Update Azure Function URL if redeployed
- Check firewall rules (BC must reach Azure)
- Verify function key is correct
- Restart Azure Function if hung

#### Issue 3: LHDN 401 Unauthorized

**Symptom**: "LHDN authentication failed"

**Debug Steps**:

1. Check Client ID and Client Secret in eInvoice Setup
2. Verify environment (PREPROD vs PRODUCTION)
3. Test token generation manually
4. Check token expiry

**Common Fixes**:

- Refresh credentials from LHDN portal
- Ensure correct environment selected
- Clear cached token (delete "Last Token" field value)
- Verify API access is still active in LHDN portal

#### Issue 4: Missing QR Code

**Symptom**: QR code not generated after successful submission

**Root Cause**: Background process to fetch `longId` failed

**Debug Steps**:

1. Check if Submission UID and UUID are populated
2. Manually call `TryFetchAndStoreValidationLink()`
3. Check LHDN API response for `longId` field

**Fix**:

- Wait 5-10 minutes (LHDN may delay populating longId)
- Manually retry QR generation
- Verify network connectivity to LHDN

### 9.2 Debugging Tools

#### Tool 1: Submission Log Analysis

```al
// Find failed submissions
SubmissionLog.SetRange(Status, 'Submission Failed');
SubmissionLog.SetRange("Submission Date", Today - 7, Today);
if SubmissionLog.FindSet() then
    repeat
        // Analyze error patterns
        Message('Invoice: %1, Error: %2', 
            SubmissionLog."Invoice No.", 
            SubmissionLog."Error Message");
    until SubmissionLog.Next() = 0;
```

#### Tool 2: JSON Download for Debugging

```al
// In Cod50302
procedure DebugInvoicePayload(InvoiceNo: Code[20])
var
    SalesInvoiceHeader: Record "Sales Invoice Header";
    JsonText: Text;
    TempBlob: Codeunit "Temp Blob";
    OutStream: OutStream;
    InStream: InStream;
begin
    SalesInvoiceHeader.Get(InvoiceNo);
    JsonText := GenerateEInvoiceJson(SalesInvoiceHeader, false);
    
    TempBlob.CreateOutStream(OutStream);
    OutStream.WriteText(JsonText);
    TempBlob.CreateInStream(InStream);
    
    DownloadFromStream(InStream, 'Download JSON', '', 'JSON Files (*.json)|*.json', 
        'Invoice_' + InvoiceNo + '.json');
end;
```

#### Tool 3: Azure Function Response Inspection

Check `Cod50302` for these debug procedures:

- `DownloadAzureFunctionPayloadForDebugging()`
- `TestAzureFunctionConnectivity()`
- `GetAvailableInvoicesForDebugging()`

### 9.3 Escalation Procedures

#### Level 1: User Support

- Check submission log
- Verify customer data completeness
- Retry submission

#### Level 2: Developer Support

- Debug JSON generation
- Check Azure Function logs
- Analyze LHDN API responses

#### Level 3: External Support

- Contact LHDN support (for API issues)
- Contact Microsoft (for BC platform issues)
- Contact Azure support (for Azure Function issues)

---

## 10. Maintenance & Support

### 10.1 Regular Maintenance Tasks

#### Weekly

- [ ] Review submission log for errors
- [ ] Check Azure Function health
- [ ] Monitor LHDN API rate limits

#### Monthly

- [ ] Review and archive old submission logs (>6 months)
- [ ] Check certificate expiry dates
- [ ] Update LHDN API credentials if rotated
- [ ] Review Azure Function costs

#### Quarterly

- [ ] Security audit (check for exposed secrets)
- [ ] Performance review (submission times)
- [ ] User feedback review
- [ ] Update documentation

### 10.2 Certificate Renewal

**CRITICAL**: Digital certificate expires annually

#### Renewal Process

1. **60 days before expiry**: Request new certificate from JOTEX
2. **30 days before expiry**: Upload new certificate to Azure Key Vault
3. **Update Azure Function**: Point to new certificate
4. **Test in PreProd**: Verify signing works with new certificate
5. **Deploy to Production**: Update production Azure Function
6. **Verify**: Test production submission

#### Certificate Storage

- **Current Location**: Azure Key Vault (recommended) or Azure Function App Settings
- **Backup**: Store encrypted copy in secure location
- **Access**: Restricted to admins only

### 10.3 Monitoring & Alerts

#### Key Metrics to Monitor

- **Submission Success Rate**: Should be >98%
- **Average Processing Time**: Should be <5 seconds
- **Azure Function Availability**: Should be >99.9%
- **LHDN API Response Time**: Should be <2 seconds

#### Alerting Setup (Recommended)

```text
Alert 1: Submission Failure Rate >5% (1 hour window)
  └─▶ Notify: Development team
  └─▶ Action: Investigate immediately

Alert 2: Azure Function Errors >10 (1 hour window)
  └─▶ Notify: DevOps team
  └─▶ Action: Check Azure Function health

Alert 3: Certificate Expiry <30 days
  └─▶ Notify: Admin team
  └─▶ Action: Initiate renewal process
```

### 10.4 Support Contacts

#### Internal Contacts

- **Previous Developer**: [Name] - [Email]
- **BC Administrator**: [Name] - [Email]
- **Azure Administrator**: [Name] - [Email]

#### External Contacts

- **LHDN Support**: <https://myinvois.hasil.gov.my/support>
- **Microsoft BC Support**: [Support contract details]
- **Azure Support**: [Support contract details]

### 10.5 Knowledge Base

#### Documentation Locations

- **This Handover Doc**: `HANDOVER.md`
- **System Documentation**: `MyInvois_LHDN_eInvoice_System_Documentation.md`
- **Developer Guide**: `MyInvois_LHDN_Developer_Guide.md`
- **API Integration Guide**: `MyInvois_LHDN_API_Integration_Guide.md`
- **Troubleshooting Guide**: `MyInvois_LHDN_Troubleshooting_Guide.md`

#### External Resources

- **LHDN SDK**: <https://sdk.myinvois.hasil.gov.my/>
- **Azure Function Reference**: <https://github.com/KalvinChua/Jotex-eInvoice-Azure>
- **UBL 2.1 Specification**: <https://docs.oasis-open.org/ubl/UBL-2.1.html>

---

## Appendix A: Quick Reference

### Key File Locations

```text
Jotex-BC-eInvoice/
├── Cod50302.eInvoiceJSONGenerator.al    # Main logic
├── Cod50310.eInvoiceAzureFunctionClient.al
├── Cod50312.eInvoiceSubmissionStatus.al
├── Tab50300.eInvoiceSetup.al             # Configuration
├── Tab50312.eInvoiceSubmissionLog.al     # Audit log
├── Pag-Ext50306.eInvPostedSalesInvoiceExt.al
└── app.json                              # Extension metadata
```

### Key Procedures

```al
// Submit invoice
Cod50302.GetSignedInvoiceAndSubmitToLHDN(SalesInvoiceHeader, LhdnResponse)

// Generate JSON only
Cod50302.GenerateEInvoiceJson(SalesInvoiceHeader, false)

// Test connectivity
Cod50302.TestAzureFunctionConnectivity(AzureFunctionUrl)

// Debug payload
Cod50302.DownloadAzureFunctionPayloadForDebugging(DocType, DocNo, Setup)
```

### Configuration Locations

- **eInvoice Setup**: Search "eInvoice Setup Card" in BC
- **Azure Function URL**: eInvoice Setup → Azure Function URL field
- **LHDN Credentials**: eInvoice Setup → Client ID / Client Secret fields
- **Environment Switch**: eInvoice Setup → Environment field (PREPROD | PRODUCTION)

---

## Appendix B: Glossary

- **LHDN**: Lembaga Hasil Dalam Negeri (Inland Revenue Board of Malaysia)
- **MyInvois**: LHDN's e-Invoice platform
- **UBL**: Universal Business Language (XML/JSON standard for invoices)
- **TIN**: Tax Identification Number
- **XAdES**: XML Advanced Electronic Signatures
- **P12**: PKCS#12 certificate format
- **Submission UID**: LHDN's unique identifier for a submission batch
- **Document UUID**: LHDN's unique identifier for a specific document
- **longId**: LHDN's long-form document identifier (used for QR codes)

---

### End of Handover Documentation

> **Next Steps**: Complete the [Project Takeover Checklist & 30-Day Onboarding Plan](#2-project-takeover-checklist--30-day-onboarding-plan) and schedule knowledge transfer sessions with the previous developer.
