# MyInvois LHDN e-Invoice System - Installation & Setup Guide

## Overview

This guide provides comprehensive instructions for installing, configuring, and deploying the MyInvois LHDN e-Invoice extension for Microsoft Dynamics 365 Business Central. The installation process involves multiple components and requires coordination between different teams.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Pre-Installation Checklist](#pre-installation-checklist)
3. [Extension Installation](#extension-installation)
4. [Azure Function Setup](#azure-function-setup)
5. [LHDN Integration Setup](#lhdn-integration-setup)
6. [System Configuration](#system-configuration)
7. [Master Data Setup](#master-data-setup)
8. [Testing and Validation](#testing-and-validation)
9. [Go-Live Preparation](#go-live-preparation)
10. [Post-Installation Support](#post-installation-support)

---

## Prerequisites

### System Requirements

#### Business Central Environment
- **Version**: Microsoft Dynamics 365 Business Central 2022 Wave 2 or later
- **License**: Valid Business Central license with development capabilities
- **Permissions**: System Administrator access for installation and configuration
- **Database**: SQL Server or Azure SQL Database

#### Hardware Requirements
- **Memory**: Minimum 8GB RAM (16GB recommended)
- **Storage**: 10GB free space for extension and logs
- **Network**: Stable internet connection for LHDN API communication

#### Software Prerequisites
- **Development Tools**: Visual Studio Code with AL Language extension
- **Azure Tools**: Azure CLI, Azure PowerShell (for Azure Function deployment)
- **SSL Certificate**: Valid SSL certificate for Azure Function HTTPS endpoints
- **Digital Signature**: JOTEX P12 certificate for document signing

### Required Accounts and Access

#### LHDN MyInvois Portal
- **LHDN Account**: Registered business account with MyInvois
- **API Access**: Approved API access with client credentials
- **Production Access**: Separate credentials for PREPROD and PRODUCTION environments

#### Azure Subscription
- **Azure Account**: Valid Azure subscription with sufficient credits
- **Resource Group**: Dedicated resource group for e-Invoice components
- **App Service Plan**: Basic or higher tier for Azure Functions

#### Business Central Access
- **Administrator Access**: Full system administrator permissions
- **Development License**: For deploying and testing extensions
- **Sandbox Environment**: For testing before production deployment

---

## Pre-Installation Checklist

### Environment Preparation

#### ✅ Development Environment
- [ ] Business Central sandbox environment available
- [ ] Development license activated
- [ ] Visual Studio Code with AL extension installed
- [ ] Git repository set up for version control

#### ✅ Azure Environment
- [ ] Azure subscription active and accessible
- [ ] Resource group created for e-Invoice components
- [ ] Azure Function App service plan provisioned
- [ ] Storage account configured for Function App

#### ✅ LHDN Preparation
- [ ] LHDN MyInvois account registered and verified
- [ ] API access requested and approved
- [ ] PREPROD environment credentials obtained
- [ ] PRODUCTION environment access planned

#### ✅ Security and Certificates
- [ ] Digital signature certificate (P12) obtained
- [ ] Certificate password securely stored
- [ ] SSL certificate for Azure Function procured
- [ ] Secure key management solution identified

#### ✅ Team Coordination
- [ ] IT infrastructure team aligned
- [ ] Business users identified for testing
- [ ] Support team briefed on new system
- [ ] Change management process initiated

### Risk Assessment

#### Potential Risks
1. **API Rate Limiting**: LHDN API has rate limits that could affect bulk processing
2. **Certificate Expiry**: Digital certificates expire and need renewal
3. **Network Connectivity**: Internet connectivity issues could disrupt submissions
4. **Data Volume**: Large transaction volumes may require performance optimization

#### Mitigation Strategies
- Implement retry logic with exponential backoff
- Set up certificate expiry monitoring and alerts
- Configure redundant network connections
- Plan for horizontal scaling of Azure Functions

---

## Extension Installation

### Method 1: Manual Installation via Extension Management

#### Step 1: Prepare Extension Package
```powershell
# Create extension package
# This would typically be done during development
Publish-NAVApp -ServerInstance $ServerInstance -Path ".\MyInvoisLHDN.app" -SkipVerification
```

#### Step 2: Install via Business Central Web Client
1. **Access Extension Management**
   - Open Business Central web client
   - Navigate to **Extension Management** (search for "Extensions")
   - Click **Manage** → **Upload Extension**

2. **Upload Extension File**
   - Select the `.app` file
   - Click **Upload**
   - Wait for validation to complete

3. **Install Extension**
   - Review permissions and dependencies
   - Click **Install**
   - Wait for installation to complete

4. **Verify Installation**
   - Check **Installed Extensions** list
   - Verify version number
   - Test basic functionality

### Method 2: PowerShell Installation

#### Automated Installation Script
```powershell
# PowerShell installation script
param(
    [Parameter(Mandatory=$true)]
    [string]$ServerInstance,
    [Parameter(Mandatory=$true)]
    [string]$ExtensionPath,
    [Parameter(Mandatory=$false)]
    [string]$Tenant = "default"
)

# Import required modules
Import-Module "C:\Program Files\Microsoft Dynamics 365 Business Central\*\Service\NavAdminTool.ps1"

# Install extension
try {
    Write-Host "Installing MyInvois LHDN e-Invoice extension..."
    Publish-NAVApp -ServerInstance $ServerInstance -Path $ExtensionPath -SkipVerification
    Install-NAVApp -ServerInstance $ServerInstance -Name "MyInvoisLHDN" -Tenant $Tenant

    Write-Host "Extension installed successfully!"
} catch {
    Write-Error "Installation failed: $_"
    exit 1
}
```

#### Batch Installation for Multiple Environments
```powershell
# Install across multiple environments
$environments = @("Sandbox", "Test", "Production")
$extensionPath = ".\MyInvoisLHDN.app"

foreach ($env in $environments) {
    Write-Host "Installing on $env environment..."
    # Installation logic here
}
```

### Method 3: Azure DevOps Pipeline

#### CI/CD Pipeline Configuration
```yaml
# azure-pipelines.yml
trigger:
  branches:
    include:
    - main

stages:
- stage: Build
  jobs:
  - job: BuildExtension
    steps:
    - task: PowerShell@2
      inputs:
        targetType: 'inline'
        script: |
          # Build extension
          # Compile AL code
          # Create .app package

- stage: Test
  jobs:
  - job: TestExtension
    steps:
    - task: PowerShell@2
      inputs:
        targetType: 'inline'
        script: |
          # Run automated tests
          # Validate extension package

- stage: Deploy
  jobs:
  - deployment: DeployToSandbox
    environment: 'Sandbox'
    strategy:
      runOnce:
        deploy:
          steps:
          - task: PowerShell@2
            inputs:
              targetType: 'inline'
              script: |
                # Deploy to sandbox
                # Run smoke tests
```

---

## Azure Function Setup

### Azure Function Architecture

The Azure Function serves as the secure bridge between Business Central and LHDN, handling digital signing and API communication.

#### Required Components
- **Function App**: Hosts the signing service
- **Storage Solutions**: For function logs and temporary files
- **Certificate Management**: For secure certificate storage and access
- **Monitoring Tools**: For logging and performance tracking

### Step-by-Step Azure Setup

#### 1. Create Resource Group
```azurecli
# Create dedicated resource group
az group create --name "rg-myinvois-prod" --location "Southeast Asia"
```

#### 2. Create Storage Account
```azurecli
# Create storage account for Function App
az storage account create \
  --name "stmyinvoisprod" \
  --resource-group "rg-myinvois-prod" \
  --location "Southeast Asia" \
  --sku "Standard_LRS" \
  --kind "StorageV2"
```

#### 3. Create Function App
```azurecli
# Create Function App
az functionapp create \
  --name "func-myinvois-prod" \
  --resource-group "rg-myinvois-prod" \
  --storage-account "stmyinvoisprod" \
  --consumption-plan-location "Southeast Asia" \
  --runtime "dotnet" \
  --runtime-version "6.0" \
  --functions-version "4" \
  --os-type "Windows"
```

#### 4. Configure Application Settings
```azurecli
# Set environment variables
az functionapp config appsettings set \
  --name "func-myinvois-prod" \
  --resource-group "rg-myinvois-prod" \
  --settings \
    "ENVIRONMENT=PRODUCTION" \
    "LHDN_API_URL=https://api.myinvois.hasil.gov.my" \
    "CERTIFICATE_PASSWORD=your-secure-password" \
    "LOG_LEVEL=Information"
```

#### 5. Configure Digital Certificate
```bash
# Configure certificate access for Azure Function
# Certificate should be securely stored and accessible to the function
# Implementation details based on: https://github.com/acutraaq/eInvAzureSign
# Follow your organization's certificate management procedures
```

### Azure Function Code Deployment

#### Function Structure
```
MyInvoisAzureFunction/
├── host.json
├── local.settings.json
├── SignDocument/
│   ├── function.json
│   └── run.csx
└── ValidateDocument/
    ├── function.json
    └── run.csx
```

#### Sample Function Implementation
```csharp
// run.csx - Document Signing Function
#r "Newtonsoft.Json"

using System.Net;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Primitives;
using Newtonsoft.Json;

public static async Task<IActionResult> Run(HttpRequest req, ILogger log)
{
    log.LogInformation("Document signing request received");

    // Parse request
    string requestBody = await new StreamReader(req.Body).ReadToEndAsync();
    dynamic data = JsonConvert.DeserializeObject(requestBody);

    // Validate input
    if (data?.unsignedJson == null || data?.invoiceType == null) {
        return new BadRequestObjectResult("Missing required parameters");
    }

    try {
        // Sign document
        var signedDocument = await SignDocumentWithCertificate(data.unsignedJson.ToString());

        // Prepare LHDN payload
        var lhdnPayload = PrepareLhdnPayload(signedDocument, data.invoiceType.ToString());

        // Return response
        return new OkObjectResult(new {
            success = true,
            signedJson = signedDocument,
            lhdnPayload = lhdnPayload,
            message = "Document signed successfully"
        });
    } catch (Exception ex) {
        log.LogError($"Signing failed: {ex.Message}");
        return new ObjectResult(new {
            success = false,
            message = $"Signing failed: {ex.Message}"
        }) { StatusCode = 500 };
    }
}
```

### Security Configuration

#### Network Security
```azurecli
# Configure VNet integration
az functionapp vnet-integration add \
  --name "func-myinvois-prod" \
  --resource-group "rg-myinvois-prod" \
  --vnet "vnet-myinvois-prod" \
  --subnet "snet-functions"
```

#### Access Restrictions
```azurecli
# Restrict access to specific IP ranges
az functionapp config access-restriction add \
  --name "func-myinvois-prod" \
  --resource-group "rg-myinvois-prod" \
  --rule-name "AllowBusinessCentral" \
  --action Allow \
  --ip-address "YOUR_BC_IP_RANGE" \
  --priority 100
```

---

## LHDN Integration Setup

### LHDN Portal Registration

#### Step 1: Register for MyInvois
1. **Visit LHDN Portal**
   - Go to https://myinvois.hasil.gov.my/
   - Click **"Register"** for new account

2. **Company Registration**
   - Enter company TIN and registration details
   - Upload required documents
   - Verify email and phone number

3. **API Access Request**
   - Navigate to **Developer Portal**
   - Request API access
   - Select required scopes (submit, retrieve, cancel)
   - Submit business justification

#### Step 2: Obtain API Credentials
```json
// Sample API credentials structure
{
  "client_id": "your-client-id",
  "client_secret": "your-client-secret",
  "api_key": "your-api-key",
  "environment": "PREPROD"
}
```

### Environment Configuration

#### PREPROD Environment Setup
```json
// PREPROD configuration
{
  "base_url": "https://preprod-api.myinvois.hasil.gov.my",
  "auth_url": "https://preprod-api.myinvois.hasil.gov.my/connect/token",
  "submit_endpoint": "/api/v1.0/documentsubmissions",
  "get_endpoint": "/api/v1.0/documents/{documentId}",
  "timeout": 30000
}
```

#### PRODUCTION Environment Setup
```json
// PRODUCTION configuration
{
  "base_url": "https://api.myinvois.hasil.gov.my",
  "auth_url": "https://api.myinvois.hasil.gov.my/connect/token",
  "submit_endpoint": "/api/v1.0/documentsubmissions",
  "get_endpoint": "/api/v1.0/documents/{documentId}",
  "timeout": 30000
}
```

### API Testing

#### Test API Connectivity
```bash
# Test LHDN API connectivity
curl -X GET "https://preprod-api.myinvois.hasil.gov.my/api/v1.0/ping" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json"
```

#### Validate API Credentials
```bash
# Test authentication
curl -X POST "https://preprod-api.myinvois.hasil.gov.my/connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=YOUR_CLIENT_ID&client_secret=YOUR_CLIENT_SECRET"
```

---

## System Configuration

### Business Central Configuration

#### 1. Access eInvoice Setup
1. **Open Business Central**
2. **Search for "eInvoice Setup Card"**
3. **Configure General Settings**

#### 2. General Configuration
```al
// Required settings in eInvoice Setup
General Tab:
- Environment: PREPROD (for testing) or PRODUCTION (for live)
- Azure Function URL: https://func-myinvois-prod.azurewebsites.net
- Default Version: 1.1
- Enable Logging: Yes
- Batch Size: 50 (documents per batch)

API Configuration Tab:
- LHDN API URL: https://api.myinvois.hasil.gov.my
- Client ID: your-lhdn-client-id
- Client Secret: your-lhdn-client-secret
- Timeout: 30 seconds
- Retry Count: 3
```

#### 3. Advanced Settings
```al
// Advanced configuration options
Processing Tab:
- Auto-submit on Post: Yes
- Suppress Dialogs: No (for production)
- Validation Level: Strict
- Error Handling: Log and Continue

Security Tab:
- Certificate Validation: Required
- IP Whitelisting: Enabled
- Audit Logging: Comprehensive
- Data Encryption: AES-256
```

### Permission Setup

#### User Permissions
```al
// Permission set for e-Invoice users
Permission Set: "EINVOICE-USER"
Permissions:
- Table "eInvoice Setup" - R
- Table "eInvoice Submission Log" - R
- Codeunit "eInvoice JSON Generator" - X
- Page "Posted Sales Invoice" - Actions: "Sign & Submit to LHDN"
- Page "eInvoice Submission Log" - R
```

#### Administrator Permissions
```al
// Permission set for administrators
Permission Set: "EINVOICE-ADMIN"
Permissions:
- Table "eInvoice Setup" - RIMD
- Table "eInvoice TIN Log" - RIMD
- Codeunit "eInvoice JSON Generator" - X
- Codeunit "eInvoice Data Upgrade" - X
- All e-Invoice pages - Full access
```

---

## Master Data Setup

### Company Information Setup

#### Required Company Fields
1. **Open Company Information Card**
2. **Fill e-Invoice Fields**:
   - TIN Number: Company tax identification
   - Business Registration Number: SSM registration
   - Complete Address: With state and country codes
   - Bank Account Information: For payment details
   - Contact Information: Email and phone

#### Address Validation
```al
// Address validation checklist
- Address Line 1: Required, max 100 characters
- City: Required, valid Malaysian city
- State Code: Required, valid Malaysian state code (01-16)
- Post Code: Required, valid Malaysian postcode
- Country Code: Must be "MYS" for Malaysia
```

### Customer Setup

#### Bulk Customer Setup
```al
// Codeunit for bulk customer e-Invoice setup
procedure SetupCustomersForEInvoice()
var
    Customer: Record Customer;
    ProgressDialog: Dialog;
    Counter: Integer;
begin
    ProgressDialog.Open('Setting up customer #1###### of #2######');

    Customer.SetRange("Requires e-Invoice", false);
    if Customer.FindSet() then begin
        repeat
            Counter += 1;
            ProgressDialog.Update(1, Counter);
            ProgressDialog.Update(2, Customer.Count);

            // Setup e-Invoice fields
            SetupCustomerEInvoiceFields(Customer);

        until Customer.Next() = 0;
    end;

    ProgressDialog.Close();
    Message('Customer setup completed for %1 customers', Counter);
end;
```

#### Customer Validation
```al
// Validate customer e-Invoice readiness
procedure ValidateCustomerEInvoiceReadiness(CustomerNo: Code[20]): Boolean
var
    Customer: Record Customer;
    ErrorMessage: Text;
begin
    if not Customer.Get(CustomerNo) then
        exit(false);

    // Check TIN
    if Customer."e-Invoice TIN No." = '' then begin
        ErrorMessage := 'TIN number is required';
        exit(false);
    end;

    // Validate address
    if not ValidateCustomerAddress(Customer) then begin
        ErrorMessage := 'Complete address is required';
        exit(false);
    end;

    // Check ID type
    if Customer."e-Invoice ID Type" = '' then begin
        ErrorMessage := 'ID type is required';
        exit(false);
    end;

    exit(true);
end;
```

### Item Classification Setup

#### MSIC Code Setup
```al
// Setup Malaysian Standard Industrial Classification codes
procedure ImportMSICCodes()
var
    MSICCodes: Record "MSIC Codes";
    TempBlob: Codeunit "Temp Blob";
    FileManagement: Codeunit "File Management";
    XmlDocument: XmlDocument;
begin
    // Import MSIC codes from XML file
    // This would typically be done via data migration
    UploadIntoStream('', '', '', FileName, TempBlob.CreateInStream());

    // Parse and import codes
    // Implementation details...
end;
```

#### Item Classification Process
1. **Review Item List**
2. **Assign PTC Codes** (Product Tax Category)
3. **Assign CLASS Codes** (Classification)
4. **Set Tax Types**
5. **Configure UOM Codes**

---

## Testing and Validation

### Test Environment Setup

#### Create Test Data
```al
// Create comprehensive test data
procedure CreateTestScenario()
var
    Customer: Record Customer;
    Item: Record Item;
    SalesHeader: Record "Sales Header";
    SalesLine: Record "Sales Line";
begin
    // Create test customer
    CreateTestCustomer(Customer);

    // Create test items
    CreateTestItems();

    // Create test documents
    CreateTestSalesInvoice(SalesHeader, SalesLine, Customer."No.");

    Message('Test scenario created successfully');
end;
```

#### Test Scenarios
1. **Basic Invoice Submission**
2. **Credit Note Processing**
3. **Bulk Document Processing**
4. **Error Handling and Recovery**
5. **Certificate Renewal Process**

### Validation Procedures

#### Pre-Production Checklist
- [ ] All test scenarios pass
- [ ] Performance benchmarks met
- [ ] Error handling validated
- [ ] Security audit completed
- [ ] User acceptance testing passed

#### Automated Testing
```al
// Automated test runner
[Test]
procedure RunFullEInvoiceTestSuite()
begin
    // Unit tests
    TestJsonGeneration();
    TestAzureFunctionIntegration();
    TestLhdnApiCommunication();

    // Integration tests
    TestEndToEndInvoiceProcessing();
    TestBulkProcessing();

    // Performance tests
    TestConcurrentProcessing();
    TestLargeVolumeProcessing();

    // Security tests
    TestCertificateValidation();
    TestAccessControl();
end;
```

### Performance Testing

#### Load Testing Setup
```powershell
# Load testing with PowerShell
$testCases = 1..100
$parallelJobs = 10

$testCases | ForEach-Object -Parallel {
    # Submit test invoice
    # Measure response time
    # Validate results
} -ThrottleLimit $parallelJobs
```

#### Performance Benchmarks
- **Single Document**: < 5 seconds
- **Batch Processing**: < 30 seconds for 50 documents
- **API Response Time**: < 2 seconds average
- **Concurrent Users**: Support 20+ simultaneous users

---

## Go-Live Preparation

### Production Readiness Checklist

#### ✅ System Readiness
- [ ] All configurations validated
- [ ] Test environment fully tested
- [ ] Performance benchmarks achieved
- [ ] Security audit passed
- [ ] Backup procedures documented

#### ✅ Data Readiness
- [ ] All customers configured for e-Invoice
- [ ] Item classifications complete
- [ ] Master data validated
- [ ] Historical data migration tested

#### ✅ Team Readiness
- [ ] Users trained on new processes
- [ ] Support team briefed
- [ ] Documentation distributed
- [ ] Communication plan ready

#### ✅ Infrastructure Readiness
- [ ] Production Azure Function deployed
- [ ] LHDN PRODUCTION credentials configured
- [ ] Network connectivity verified
- [ ] Monitoring and alerting configured

### Go-Live Execution Plan

#### Phase 1: Soft Launch (Week 1)
- Deploy to production environment
- Process low-volume test transactions
- Monitor system performance
- Train additional users

#### Phase 2: Gradual Rollout (Week 2)
- Increase transaction volume gradually
- Process real customer invoices
- Monitor error rates and performance
- Fine-tune configurations

#### Phase 3: Full Production (Week 3+)
- Full production go-live
- Monitor system health continuously
- Handle support requests
- Optimize performance as needed

### Rollback Plan

#### Emergency Rollback Procedures
1. **Stop Processing**: Disable auto-submission
2. **Switch Environment**: Point to backup system if available
3. **Manual Processing**: Process critical documents manually
4. **Data Recovery**: Restore from backup if needed
5. **Communication**: Notify stakeholders of rollback

#### Rollback Checklist
- [ ] Identify rollback trigger conditions
- [ ] Document rollback procedures
- [ ] Test rollback process
- [ ] Assign rollback responsibilities
- [ ] Prepare communication templates

---

## Post-Installation Support

### Monitoring and Maintenance

#### Key Metrics to Monitor
- **Submission Success Rate**: Target > 98%
- **Average Processing Time**: Track trends
- **Error Rate by Type**: Monitor and address
- **System Availability**: 99.9% uptime target

#### Regular Maintenance Tasks
- **Daily**: Check submission logs and error rates
- **Weekly**: Review system performance and capacity
- **Monthly**: Update certificates and security patches
- **Quarterly**: Full system health assessment

### Support Procedures

#### Tier 1 Support (Help Desk)
- Basic user questions and guidance
- Password resets and access issues
- Simple configuration changes
- Log analysis and basic troubleshooting

#### Tier 2 Support (Technical Team)
- Complex technical issues
- System configuration changes
- Integration troubleshooting
- Performance optimization

#### Tier 3 Support (Development Team)
- Code fixes and patches
- System upgrades and enhancements
- Root cause analysis
- Architecture changes

### Training and Documentation

#### User Training Materials
- **Quick Start Guide**: 30-minute overview
- **Detailed User Guide**: Comprehensive reference
- **Video Tutorials**: Step-by-step process videos
- **FAQ Document**: Common questions and answers

#### Administrator Training
- **System Administration Guide**: Configuration and maintenance
- **Troubleshooting Guide**: Problem resolution procedures
- **API Documentation**: Integration and customization
- **Best Practices Guide**: Optimization and performance

### Continuous Improvement

#### Feedback Collection
- Regular user surveys
- Support ticket analysis
- Performance monitoring
- Feature request tracking

#### System Enhancement
- Quarterly feature releases
- Performance optimization
- Security updates
- Compliance updates

---

## Emergency Contacts

### Technical Support
- **Primary Support**: IT Help Desk - support@company.com
- **Escalation**: System Administrator - admin@company.com
- **Development Team**: dev-team@company.com

### External Support
- **LHDN Support**: https://myinvois.hasil.gov.my/support
- **Microsoft Support**: Business Central support portal
- **Azure Support**: Azure portal support

### After-Hours Support
- **Emergency Hotline**: +60-XXX-XXXXXXX
- **On-Call Engineer**: Available 24/7 for critical issues

---

**Installation Guide Version**: 1.0
**Last Updated**: January 2025
**Next Review**: March 2025

*This installation guide provides comprehensive instructions for deploying the MyInvois LHDN e-Invoice system. Ensure all prerequisites are met before beginning installation. Contact your system administrator if you need assistance.*