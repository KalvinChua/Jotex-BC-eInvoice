# MyInvois LHDN e-Invoice System Implementation Proposal

**Date:** August 29, 2025

**From:**  
[Your Company Name]  
[Your Company Address]  
[City, State, Postcode]  

**To:**  
[Client Company Name]  
[Client Address]  
[City, State, Postcode]  

**Subject:** MyInvois LHDN e-Invoice System Implementation

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Overview](#overview)
3. [Current Environment](#current-environment)
4. [Objective](#objective)
5. [Requirements](#requirements)
6. [Company Overview](#company-overview)
7. [Proposed Solutions](#proposed-solutions)
8. [Proposed Technologies](#proposed-technologies)
9. [Proposed Architecture](#proposed-architecture)
10. [Our Approach](#our-approach)
11. [Project Plan and Estimation](#project-plan-and-estimation)
12. [Estimated Project Timeline](#estimated-project-timeline)
13. [Scope of Work](#scope-of-work)
14. [Out Of Scope](#out-of-scope)
15. [Assumptions](#assumptions)
16. [Post Support](#post-support)
17. [Financial Plan](#financial-plan)
18. [Invoicing and Payment Terms](#invoicing-and-payment-terms)
19. [Standard Terms & Conditions](#standard-terms-conditions)
20. [Support and Maintenance](#support-and-maintenance)

---

## Executive Summary

### Overview

The document is to propose [Client Company Name] (hereafter refer as "CLIENT") to engage [Your Company Name] (hereafter refer as "VENDOR") to develop and implement a comprehensive MyInvois LHDN e-Invoice system for Microsoft Dynamics 365 Business Central. The solution will enable CLIENT to comply with Malaysian LHDN (Lembaga Hasil Dalam Negeri) e-Invoice requirements and streamline their invoicing processes through digital transformation.

### Current Environment

CLIENT currently manages their invoicing processes manually or through traditional systems, which leads to several operational inefficiencies:

- **Manual Invoice Processing** – Invoices are created and managed manually, leading to delays, errors, and increased administrative overhead.
- **Lack of Digital Compliance** – Current processes may not fully comply with LHDN MyInvois e-Invoice requirements, risking non-compliance penalties.
- **Limited Integration** – Invoice data may not be properly integrated with financial systems, leading to data silos and reconciliation challenges.
- **No Real-time Tracking** – Lack of visibility into invoice status, submission results, and compliance metrics.

To overcome these issues, CLIENT seeks to implement a comprehensive e-Invoice solution that integrates seamlessly with Microsoft Dynamics 365 Business Central, ensures full LHDN compliance, and provides real-time visibility into the entire invoicing lifecycle.

### Objective

To develop and deliver the MyInvois LHDN e-Invoice System for Microsoft Dynamics 365 Business Central, enabling CLIENT to:

- Achieve full compliance with LHDN MyInvois e-Invoice requirements for digital invoicing in Malaysia.
- Streamline invoice processing from creation to LHDN submission through automated workflows.
- Enable real-time tracking and monitoring of invoice status, validation results, and compliance metrics.
- Integrate seamlessly with existing Business Central processes and data structures.
- Provide comprehensive audit trails and reporting capabilities for regulatory compliance.
- Support both B2B and B2G transactions with appropriate document types and validation rules.
- Ensure secure digital signing and submission of invoices to LHDN API endpoints.
- Empower users with intuitive interfaces for invoice management and status monitoring.

### Requirements

As VENDOR understanding, CLIENT is looking for solutions which could address:

- Full UBL 2.1 compliance for generating structured JSON invoices as required by LHDN.
- Digital signing integration using JOTEX P12 certificates through Azure Functions.
- Direct API integration with LHDN MyInvois for invoice submission and status tracking.
- Seamless integration with Microsoft Dynamics 365 Business Central sales processes.
- Real-time TIN validation for customers to ensure data accuracy.
- Support for all LHDN document types (01-Invoice, 02-Credit Note, 03-Debit Note, 04-Refund Note, 11-14 Self-billed variants).
- Automated field population and validation based on Business Central data.
- Comprehensive error handling and retry mechanisms for failed submissions.
- Complete audit logging and compliance reporting capabilities.
- Role-based access control ensuring appropriate security and data visibility.
- Real-time dashboards and notifications for invoice status monitoring.
- Bulk processing capabilities for high-volume invoice scenarios.
- Mobile-responsive user interfaces for cross-device accessibility.
- Multi-language support (English/Malay) for diverse user groups.

---

## Company Overview

[Your Company Name] is a leading provider of Microsoft technology solutions, specializing in digital transformation and enterprise application development. With extensive experience in Microsoft Dynamics 365 Business Central and Azure cloud services, we deliver innovative solutions that drive business efficiency and compliance.

### Our core competencies include:

- **Enterprise Application Development** – Custom development using Microsoft technologies including Business Central, Azure, and Power Platform.
- **Digital Transformation** – Streamlining business processes through automation and cloud adoption.
- **Compliance Solutions** – Implementing regulatory compliance systems for various industries.
- **Cloud Integration** – Seamless integration with Microsoft Azure services and APIs.
- **Data Analytics** – Providing insights through reporting and dashboard solutions.
- **Quality Assurance** – Comprehensive testing and validation procedures.

We have successfully delivered numerous Business Central implementations and integrations, with particular expertise in Malaysian market requirements and LHDN compliance solutions.

---

## Proposed Solutions

### Overview

VENDOR is proposing CLIENT to implement the MyInvois LHDN e-Invoice System using Microsoft Dynamics 365 Business Central extension with Azure cloud services integration. The solution leverages:

- **Business Central Extension** – Core e-Invoice processing and UI integration.
- **Azure Functions** – Secure digital signing service for invoice authentication.
- **LHDN API Integration** – Direct submission to MyInvois platform.
- **Secure Storage Solutions** – Document and log storage with encryption.
- **Certificate Management** – Secure JOTEX P12 certificate handling and lifecycle management.

The proposed solution will transform CLIENT's invoicing processes from manual to fully automated digital compliance, ensuring regulatory adherence while improving operational efficiency.

### MyInvois LHDN e-Invoice System

The proposed solution will leverage Microsoft Dynamics 365 Business Central extension with Azure cloud services to digitize and automate the e-Invoice process.

#### Workflow Overview:

1. Users create sales invoices in Business Central with standard processes.
2. The e-Invoice extension automatically validates customer TIN and populates required fields.
3. System generates UBL 2.1 compliant JSON structure with all mandatory fields.
4. Document is digitally signed using JOTEX P12 certificate through Azure Functions.
5. Signed document and LHDN-ready payload are returned to Business Central.
6. Business Central submits the signed document to LHDN MyInvois API.
7. System tracks submission status and provides real-time updates.
8. Comprehensive audit logging captures all actions and system responses.
9. Users can monitor invoice status through integrated dashboards and receive notifications.

The solution supports all LHDN document types and ensures complete compliance with current regulations.

#### Key Features:

- Automatic UBL 2.1 JSON generation with proper namespace declarations.
- Real-time TIN validation with LHDN API integration.
- Digital signing using Azure Functions and certificate management.
- Multi-level error handling with intelligent retry mechanisms.
- Comprehensive audit trails and compliance reporting.
- Role-based security and access control.
- Real-time dashboards and status monitoring.
- Bulk processing capabilities for high-volume scenarios.
- Mobile-responsive user interfaces.
- Multi-language support (English/Malay).

---

## Proposed Technologies

### Microsoft Dynamics 365 Business Central

Business Central serves as the core platform for invoice creation and management, providing a robust foundation for e-Invoice processing.

#### Core Capabilities:
- **Version**: Microsoft Dynamics 365 Business Central 2022 Wave 2 or later
- **AL Language Development**: Custom extension development using AL (Application Language) for e-Invoice functionality
- **Table Extensions**: Enhanced data models for customers, items, and sales documents with e-Invoice fields
- **Page Extensions**: Integrated user interfaces for e-Invoice management and real-time monitoring
- **Codeunits**: Business logic implementation for JSON generation, validation, and API orchestration
- **Reports**: Advanced reporting capabilities for bulk processing and compliance documentation
- **Workflow Integration**: Seamless integration with existing sales, purchase, and financial processes

#### Key Benefits:
- **Unified Platform**: Single system for ERP and e-Invoice compliance
- **Real-time Processing**: Immediate validation and status updates
- **Scalability**: Handles high-volume invoice processing efficiently
- **Customization**: Flexible extension model for specific business requirements
- **Security**: Built-in role-based security and audit trails

### Microsoft Azure Cloud Services

Azure provides enterprise-grade cloud infrastructure and services for secure, scalable e-Invoice processing.

#### Core Services:

##### Azure Functions v4
- **Runtime**: .NET 6.0 Isolated Process Model
- **Reference Implementation**: https://github.com/acutraaq/eInvAzureSign
- **Trigger Types**: HTTP triggers for API endpoints, Timer triggers for scheduled tasks
- **Scaling**: Consumption plan with automatic scaling (1-200 instances)
- **Security**: Integrated with Azure Active Directory and secure certificate management
- **Monitoring**: Application Insights integration for performance tracking
- **Certificate Management**: Secure JOTEX P12 certificate handling
- **Benefits**: Serverless architecture reduces operational overhead, automatic scaling for peak loads
- **Production Ready**: Based on proven implementation with JOTEX certificate integration

##### Certificate Management
- **JOTEX P12 Certificates**: File-based certificate storage and management
- **Environment-Specific Loading**: PREPROD and PRODUCTION certificate handling
- **Serial Number Extraction**: Decimal format extraction for LHDN compliance
- **Access Control**: Secure certificate access with proper authentication
- **Compliance**: Malaysian Digital Signature Standard (DSS) compliance
- **Benefits**: Production-ready implementation, no Key Vault dependency

##### Azure Monitor and Application Insights
- **Metrics Collection**: Real-time performance and health metrics
- **Log Analytics**: Centralized logging and query capabilities
- **Alerting**: Intelligent alerting based on metrics and logs
- **Dashboards**: Custom dashboards for system monitoring
- **Integration**: Native integration with Azure Functions
- **Benefits**: Proactive monitoring, rapid issue detection and resolution

### Digital Security Technologies

Security technologies ensure compliance with Malaysian regulations and protect sensitive financial data.

#### Digital Signature Infrastructure:
- **JOTEX P12 Certificates**: Malaysian Digital Signature Standard (DSS) compliant
- **Certificate Loading**: Environment-specific file-based certificate management
- **XAdES Implementation**: Official LHDN 7-step signing process
- **Signature Algorithm**: RSA 2048-bit with SHA-256 hashing
- **Serial Number Handling**: Decimal format extraction for LHDN compliance
- **Compliance**: Meets Malaysian Communications and Multimedia Commission (MCMC) requirements

#### Data Protection:
- **Encryption at Rest**: AES-256 encryption for all stored data
- **Encryption in Transit**: TLS 1.3 for all network communications
- **Data Masking**: Sensitive data masking in logs and user interfaces
- **Tokenization**: PCI DSS compliant tokenization for payment data

#### Authentication and Authorization:
- **OAuth 2.0**: Industry-standard authorization framework
- **JWT Tokens**: JSON Web Tokens for secure API authentication
- **API Keys**: Secure API key management with rotation policies
- **Certificate-based Authentication**: Mutual TLS for high-security scenarios

#### Security Monitoring:
- **Application Insights**: Real-time performance and security monitoring
- **Certificate Validation**: Automated certificate expiry monitoring
- **Request Validation**: Input validation and sanitization
- **Error Logging**: Comprehensive security event logging
- **Correlation Tracking**: Request correlation for security analysis

### LHDN MyInvois API Integration

Direct integration with the official LHDN MyInvois platform ensures regulatory compliance and seamless document submission.

#### API Endpoints and Capabilities:

##### Document Submission API
- **Endpoint**: `POST /api/v1.0/documentsubmissions`
- **Authentication**: OAuth 2.0 Bearer tokens
- **Payload Format**: JSON with UBL 2.1 structure
- **Rate Limits**: 100 requests per minute, 10,000 per hour
- **Response Format**: JSON with submission ID and status
- **Error Handling**: Detailed error codes and messages

##### Document Status Retrieval API
- **Endpoint**: `GET /api/v1.0/documents/{documentId}`
- **Authentication**: OAuth 2.0 Bearer tokens
- **Response Format**: JSON with detailed status information
- **Real-time Updates**: Status polling every 30 seconds
- **Historical Data**: 90-day status history retention

##### TIN Validation API
- **Endpoint**: `GET /api/v1.0/taxpayer/validation/{tin}`
- **Authentication**: OAuth 2.0 Bearer tokens
- **Response Format**: JSON with validation status and taxpayer details
- **Caching**: 24-hour validation result caching
- **Error Handling**: Invalid TIN format detection

##### Bulk Submission API
- **Endpoint**: `POST /api/v1.0/documentsubmissions/batch`
- **Batch Size**: Maximum 50 documents per batch
- **Processing**: Asynchronous processing with status callbacks
- **Error Handling**: Individual document error reporting
- **Benefits**: Efficient bulk processing for high-volume scenarios

#### API Integration Features:
- **Automatic Retries**: Intelligent retry logic with exponential backoff
- **Circuit Breaker**: Automatic failover for API unavailability
- **Request Throttling**: Respectful rate limiting to prevent API rejection
- **Response Caching**: Intelligent caching to reduce API calls
- **Error Classification**: Automated error categorization and handling

### Azure Function Implementation (eInvAzureSign) – Technical Reference

This is the production signing service used by Business Central. It is implemented in the eInvAzureSign repository and is referenced here to align proposal claims with the working codebase.

- Runtime and hosting
  - .NET 8.0 Isolated Azure Functions (Application Insights enabled)
  - Dependency Injection configured in [Program.cs](external/eInvAzureSign/Program.cs:11)

- Endpoints
  - General signing: [eInvSigning.Run()](external/eInvAzureSign/eInvSigning.cs:45) → POST /api/eInvSigning
  - Business Central optimized: [eInvSigning.ProcessBusinessCentralRequest()](external/eInvAzureSign/eInvSigning.cs:814) → POST /api/BusinessCentralSigning
  - Health: [eInvSigning.HealthCheck()](external/eInvAzureSign/eInvSigning.cs:431) → GET /api/health
  - Connectivity test: [eInvSigning.ConnectivityTest()](external/eInvAzureSign/eInvSigning.cs:379) → GET/POST /api/connectivity-test
  - Signature validation: [eInvSigning.ValidateSignature()](external/eInvAzureSign/eInvSigning.cs:450) → POST /api/validate

- LHDN 7‑step signing pipeline (XAdES)
  - Orchestrated by [HardcodedDigitalSignatureService.GenerateOfficialLhdnSignature()](external/eInvAzureSign/Services/HardcodedDigitalSignatureService.cs:312)
  - Transform/remove UBLExtensions/Signature: [TransformDocument()](external/eInvAzureSign/Services/HardcodedDigitalSignatureService.cs:394)
  - RSA‑SHA256 using provider pattern: [SignDocumentUsingCertProviderMethod()](external/eInvAzureSign/Services/HardcodedDigitalSignatureService.cs:149)
  - Build signed properties: [CreateLhdnSignedProperties()](external/eInvAzureSign/Services/HardcodedDigitalSignatureService.cs:440)
  - Final UBL with UBLExtensions + Signature: [CreateLhdnCompliantSignedDocument()](external/eInvAzureSign/Services/HardcodedDigitalSignatureService.cs:520)

- Certificate management (file‑based; no Key Vault required)
  - Environment‑specific loading: [LoadCertificateForEnvironment()](external/eInvAzureSign/Services/HardcodedDigitalSignatureService.cs:41)
    - PREPROD: JOTEX_SDN._BHD..p12
    - PROD: CERT_19448802.p12
  - Serial number (decimal) extraction for LHDN: [GetCertificateSerialNumberAsDecimal()](external/eInvAzureSign/Services/HardcodedDigitalSignatureService.cs:130)

- Business Central interoperability
  - Clean placeholder and normalize UBL numbers: [BusinessCentralService.CleanBusinessCentralJson()](external/eInvAzureSign/Services/BusinessCentralService.cs:23), [NormalizeDataTypes()](external/eInvAzureSign/Services/BusinessCentralService.cs:103)
  - Embed XAdES into BC UBL: [EmbedSignatureIntoBusinessCentralJson()](external/eInvAzureSign/Services/BusinessCentralService.cs:56)
  - Async webhook callback back to BC (signed payload/status): [BusinessCentralHttpService.SendSignedInvoiceCallbackAsync()](external/eInvAzureSign/Services/BusinessCentralHttpService.cs:36)

- Returned artifacts to Business Central
  - Signed JSON with UBLExtensions and Signature
  - LHDN “documents” payload (base64 document + SHA‑256 hash + codeNumber) created by [CreateLhdnSubmissionDocument()](external/eInvAzureSign/eInvSigning.cs:714)

- Data quality and safeguards
  - Normalize IssueDate/IssueTime to current UTC to avoid CF321: [NormalizeInvoiceDateTimeToUtc()](external/eInvAzureSign/eInvSigning.cs:1003)
  - Environment heuristics for safety/logging: [DetectEnvironmentFromJson()](external/eInvAzureSign/eInvSigning.cs:1090)
  - Request validation: [ValidateRequest()](external/eInvAzureSign/eInvSigning.cs:505)
  - Correlation IDs and processing time metrics in BC flow: [ProcessBusinessCentralRequest()](external/eInvAzureSign/eInvSigning.cs:814)

- Monitoring
  - Application Insights telemetry configured in [Program.cs](external/eInvAzureSign/Program.cs:11)

### Technology Integration Architecture

#### System Integration Points:
1. **Business Central ↔ Azure Functions**: Secure document signing and payload preparation
2. **Business Central ↔ LHDN API**: Direct API communication with authentication
3. **Azure Functions ↔ Business Central**: Signed document and status callbacks
4. **Application Insights ↔ All Components**: Centralized monitoring and logging
5. **Certificate Management**: File-based certificate handling and validation

#### Data Flow Architecture:
1. **Invoice Creation**: Business Central captures invoice data
2. **Validation**: Real-time TIN and data validation
3. **JSON Generation**: UBL 2.1 compliant JSON creation
4. **Digital Signing**: Azure Functions applies JOTEX signature and returns signed document
5. **Payload Preparation**: LHDN-ready payload created with base64 document and hash
6. **API Submission**: Business Central submits signed document to LHDN MyInvois
7. **Status Tracking**: Real-time status monitoring and updates
8. **Audit Logging**: Comprehensive audit trail maintenance

#### Performance Characteristics:
- **Response Time**: < 5 seconds for standard invoice processing
- **Throughput**: 100+ invoices per minute during peak hours
- **Availability**: 99.9% uptime with automated failover
- **Scalability**: Auto-scaling from 1 to 200 concurrent instances
- **Data Retention**: 7-year audit trail retention for compliance

This comprehensive technology stack ensures a robust, secure, and scalable e-Invoice solution that meets Malaysian regulatory requirements while providing excellent performance and user experience.

---

## Proposed Architecture

The architecture follows a secure, scalable cloud-native design:

### Business Central Extension Layer:
- Custom AL extension with core business logic
- UI integration for user interaction
- Data validation and transformation
- API orchestration and error handling

### Azure Integration Layer:
- Azure Functions for digital signing and payload preparation
- File-based certificate management for secure authentication
- Application Insights for monitoring and logging

### LHDN Integration Layer:
- Secure API communication
- Request/response handling
- Error parsing and retry logic
- Status monitoring and updates

### Security Layer:
- Certificate-based authentication
- Data encryption throughout
- Role-based access control
- Audit logging and monitoring

The architecture ensures:
- High availability and scalability
- Secure data processing and storage
- Compliance with Malaysian regulations
- Seamless integration with existing systems
- Real-time monitoring and alerting

---

## Our Approach

We approach all our projects following the Microsoft Solutions Framework (MSF) methodology, which consists of 5 phases:

### 1. Envisioning Phase
– Project initiation, stakeholder alignment, and scope definition.

### 2. Planning Phase
– Technical design, architecture planning, and detailed project planning.

### 3. Developing Phase
– Solution development, testing, and quality assurance.

### 4. Stabilizing Phase
– System integration testing, user acceptance testing, and final validation.

### 5. Deploying Phase
– Production deployment, data migration, and go-live support.

### Project Phases

| Activities/Deliverables | Milestones |
|------------------------|------------|
| Envisioning: Team and stakeholder alignment, risk and environment assessment, requirement gathering sessions, define scope, features, and success criteria, prepare initial project plan | Vision/Scope Approved (5 man-days) |
| Planning: Environment and license review, conceptual design of user interface and data models, define access matrix and security roles, draft functional specification, identify test plan and use cases | Functional Specification Conceptual Design (12 man-days) |
| Developing: Configure Power Platform environments, develop core modules in Power Apps, implement SharePoint backend for data storage and evidence handling, perform System Integration Testing (SIT), identify pilot users for testing and feedback | Development (60 man-days) |
| Stabilizing: Prepare and deploy staging environment, conduct User Acceptance Testing (UAT) with pilot users, apply fixes and improvements from UAT feedback | Test Lab Testing (10 man-days) |
| Deploying: Finalize staging deployment, performance tuning, validate readiness for production rollout | Pilot and staging (8 man-days) |

---

## Project Plan and Estimation

Below are estimated project plan and timeline.

| Phase | Deliverables | Milestone |
|-------|-------------|-----------|
| **Envisioning** | • Team and stakeholder alignment<br>• Risk and environment assessment<br>• Requirement gathering sessions<br>• Define scope, features, and success criteria<br>• Prepare initial project plan | Vision Scope (5 man-days) |
| **Planning** | • Environment and license review<br>• Conceptual design of user interface and data models<br>• Define access matrix and security roles<br>• Draft functional specification<br>• Identify test plan and use cases | Functional Specification Conceptual Design (12 man-days) |
| **Development** | • Configure Power Platform environments<br>• Develop core modules in Power Apps<br>• Implement SharePoint backend for data storage and evidence handling<br>• Perform System Integration Testing (SIT)<br>• Identify pilot users for testing and feedback | Development (60 man-days) |
| **Testing (SIT/UAT)** | • Set up test/staging environment<br>• Perform System Integration Testing (SIT)<br>• Conduct User Acceptance Testing (UAT) with pilot users<br>• Apply fixes and improvements from UAT feedback | Test Lab Testing (10 man-days) |
| **Stabilizing** | • Finalize staging deployment<br>• Performance tuning<br>• Validate readiness for production rollout | Pilot and staging (8 man-days) |
| **Deploying** | • Deploy solution to production environment<br>• Final security and permission configuration<br>• Monitor go-live performance and verify critical workflows | Implementation & Deployment (8 man-days) |
| **Project Closure** | • Conduct final project review and feedback session<br>• Prepare and hand over all documentation<br>• Conduct knowledge transfer and admin training<br>• Obtain final sign-off from KPJ stakeholders | Project Closure (5 man-days) |

---

## Estimated Project Timeline

Below the estimate timeline for the project, assuming no holidays in between. The actual timeline will be subject to the actual start date and factor in Malaysian public holidays.

| Task Description | Duration | Month 1 | Month 2 | Month 3 | Month 4 | Month 5 |
|------------------|----------|---------|---------|---------|---------|---------|
| Envisioning | 5 | W1-W1 | | | | |
| Planning | 12 | W2-W4 | W1 | | | |
| Development | 60 | W1-W4 | W2-W4 | W1-W4 | W1-W2 | |
| Testing | 10 | | | W1-W2 | W3-W4 | |
| Stabilizing | 8 | | | W3-W4 | W1 | |
| Deployment | 8 | | | | W2 | W1 |
| Project Sign-Off | 5 | | | | | W2 |

**Note:** Some tasks will run concurrently and CLIENT user cooperation is required to ensure timeline is met. If there are delays due to CLIENT user availability, project timeline may be affected.

---

## Scope of Work

The proposed solutions involve development, implementation, and deployment of the MyInvois LHDN e-Invoice System for Microsoft Dynamics 365 Business Central.

### In Scope:
- Perform environment study and gap analysis
- Understand CLIENT's business and compliance requirements
- Confirming Scope and Functional Specification
- Preparing Functional Specification & Requirement Documentation
- **Milestone: Envisioning Phase Sign-Off**

- Design Business Central extension architecture
- Develop AL extension with core e-Invoice functionality
- Implement Azure Functions for digital signing
- Configure LHDN API integration and authentication
- Design user interfaces and reporting dashboards
- **Milestone: Design Approved**

- Develop Business Central extension components
- Implement table extensions and page customizations
- Develop codeunits for JSON generation and API integration
- Create Azure Functions for secure document signing
- Implement error handling and retry mechanisms
- **Milestone: Development Complete**

- Configure test environments and test data
- Perform unit testing and integration testing
- Conduct user acceptance testing with CLIENT team
- Execute performance and security testing
- Validate LHDN compliance and documentation
- **Milestone: Testing Complete**

- Configure production environment
- Execute data migration and validation
- Deploy solution to production
- Conduct user training and knowledge transfer
- Provide go-live support and monitoring
- **Milestone: Deployment Complete**

- Prepare comprehensive documentation
- Conduct project closure and handover
- Provide post-implementation support
- Establish ongoing maintenance procedures
- **Milestone: Project Closure**

---

## Out Of Scope

- Third-party system integrations not specified in requirements
- Custom reporting beyond standard e-Invoice reports
- Mobile app development (web-responsive design only)
- Offline functionality and local data synchronization
- Advanced analytics and business intelligence features
- Multi-company deployment (single company scope)
- Legacy system data migration (Business Central data only)
- Hardware procurement and infrastructure setup
- Network security configuration and firewall management
- Backup and disaster recovery system implementation

---

## Assumptions

The following assumptions are made in this proposal:

- The project timeline is based on best-case estimates and actual effort may vary based on complexity discovered during implementation.
- CLIENT will provide timely access to required systems, data, and stakeholders for requirement gathering and testing.
- Business Central environment is properly licensed and configured with necessary permissions.
- CLIENT will provide LHDN PREPROD credentials and certificates for testing and development.
- Azure subscription and resources will be provided by CLIENT or procured as part of the project.
- Digital certificates (JOTEX P12) will be procured by CLIENT and provided to VENDOR.
- Test data and scenarios will be provided by CLIENT for comprehensive testing.
- CLIENT's IT team will collaborate closely during development, testing, and deployment phases.
- Network connectivity and security policies allow required Azure and LHDN API communications.
- CLIENT will perform regular backups of Business Central data throughout the project.

---

## Post Support

VENDOR will provide 30 days post-implementation support after go-live for the developed solution. This includes:

- Daily monitoring and health checks
- Issue resolution and troubleshooting
- User guidance and training
- Performance optimization recommendations
- Knowledge transfer sessions
- Emergency support during business hours

---

## Financial Plan

### Invoicing and Payment Terms

Invoicing for Professional Services for development and implementation shall be done based on the following:

- **30%** upon confirmation or receiving PO
- **50%** upon UAT completion and sign-off
- **20%** upon successful go-live and project completion

Invoicing for Microsoft Azure Services shall be done based on the following:

- **100%** upon confirmation or receiving PO (prepaid consumption)

---

## Standard Terms & Conditions

CLIENT agrees to pay VENDOR based on the agreed contractual sum plus all travel and other expenses incurred in association with the project work.

VENDOR cannot confirm the availability of the above resources until CLIENT agrees and signs acceptance of this proposal. At least two (2) weeks are needed for VENDOR to mobilize its resources for the project.

Should there be additional time needed by VENDOR for the project (i.e., more time needed due to changes in project scope), VENDOR shall highlight to CLIENT.

This proposal expires on **December 31, 2025**, unless otherwise agreed to by both parties.

---

## Support and Maintenance – Microsoft Business Central/Managed Security Service

### Overview

VENDOR will provide comprehensive support and maintenance services for the implemented MyInvois LHDN e-Invoice System, ensuring optimal performance, security, and compliance.

### Standard Business Hours

For the purpose of the following section of this proposal, the standard business hours shall be defined as below:

**Monday to Friday (9:00am to 6:00pm) Malaysia time**, excluding weekends and national public holidays gazetted in Malaysia.

Extended support shall be defined as any other support time other than the standard business hours.

### Support Location

For the purposes of the following sections of this proposal, the supported location shall be defined as below:

**[CLIENT Office Address]**

Should CLIENT decide to shift the location of support, CLIENT must provide VENDOR with 30 days prior notice of the new location to be supported.

### Supported Products

For the purposes of the following sections of this proposal, the supported products shall be defined as below:

- Microsoft Dynamics 365 Business Central
- MyInvois LHDN e-Invoice Extension
- Microsoft Azure Services (Functions, Monitoring)
- LHDN MyInvois API Integration

### Helpdesk Support

The proposed support structure shall be as shown below:

| Name | Level |
|------|-------|
| CLIENT | First |
| VENDOR | Second |

Based on the structure above, each support case shall be approached as below:

1. CLIENT shall dedicate IT personnel or administrator (IT team) for any point of contact.
2. CLIENT IT team shall evaluate and diagnose the issue at hand.
3. CLIENT IT team shall attempt preliminary troubleshooting exercise to resolve the issue at hand.
4. Should the issue remain unresolved, it shall be escalated to VENDOR for further support assistance.
5. VENDOR shall perform further diagnosis of the issue at hand and attempt to resolve the issue together with CLIENT IT team.

VENDOR Helpdesk shall provide the following services to CLIENT:

- Management of incident submission via email or portal
- Diagnostic and resolution of submitted issues
- Management of CLIENT request for on-site support
- Escalation of unresolved issues
- Management of monthly support case reports

The services provided by VENDOR Helpdesk Unit are available only during the standard business hours as defined above.

CLIENT shall provide up to two (2) dedicated contacts for managing and coordinating support requests with VENDOR.

### Email Support

Email support shall be used by CLIENT as one of the mediums of communication with VENDOR for incident submission and resolution.

Email support shall be responded within **4 hours** upon receiving such request.

**Support Email Address:** support@[yourcompany].com

### Telephone Support

Telephone support shall be used by CLIENT as one of the mediums of communication with VENDOR for incident submission and resolution.

Telephone support shall be responded within **4 hours** upon receiving such request.

**Support Telephone Number:** [Your Support Number]

### On-Site Support

CLIENT nominated contacts may request on-site support incidents in respect of the supported products in the supported location.

Every on-site support is equal to **two (2) man-days**.

On-site support shall be used for troubleshooting and maintenance support purposes in the production environment only.

### Preventive Maintenance

VENDOR recommends executing preventive maintenance at least quarterly from the project sign-off date.

Tasks to be performed during preventive maintenance:

- Review system performance and optimization opportunities
- Update Azure Functions and dependencies
- Validate LHDN API integration and certificates
- Review security configurations and access controls
- Update documentation and procedures
- Perform database maintenance and cleanup
- Review monitoring and alerting configurations

### Development

CLIENT may engage VENDOR for additional development and enhancements using available support man-days.

Development services include:

- Business Central extension enhancements
- Azure Functions modifications
- API integration updates
- UI/UX improvements
- Reporting enhancements
- Performance optimizations

VENDOR will submit scope of work with required man-days to CLIENT for approval before proceeding with any development work.

### Annual Support & Maintenance Service – Level Agreement (SLA)

The Severity Level for each escalated incident is defined based on the following support level agreement:

| Severity Level | Definition | Initial Response Time | Final Resolution |
|---------------|------------|----------------------|------------------|
| **1 (Critical)** | System down, no e-Invoice processing possible | 2 hours | 24 hours |
| **2 (High)** | Major functionality impaired, limited processing | 4 hours | 48 hours |
| **3 (Medium)** | Minor functionality issues, workaround available | 8 hours | 5 business days |
| **4 (Low)** | Cosmetic issues, informational requests | 24 hours | 10 business days |

### Period of Service

This Support Maintenance shall be effective upon the issuance of the Purchase Order from CLIENT for a period of **12 months**.

### Service Responsibility

VENDOR will provide remote and/or on-site services under the following conditions:

- Existing MyInvois LHDN e-Invoice System implemented by VENDOR
- Solutions deployed by VENDOR
- No third-party integrations beyond VENDOR's scope
- Travel location within reasonable distance

### Service Limitation

VENDOR shall NOT be liable for the following circumstances:

- Loss of data due to CLIENT's negligence or inadequate backup procedures
- Issues caused by CLIENT modifications to the system
- Problems resulting from unsupported software versions
- Connectivity issues due to CLIENT's network configuration
- Certificate expiry due to CLIENT's failure to renew

Under all circumstances, CLIENT should perform regular backups of Business Central data.

Users' applications other than those specified in this proposal are not included in our support.

---

**THE END**

*This proposal is valid until December 31, 2025, unless otherwise agreed by both parties.*