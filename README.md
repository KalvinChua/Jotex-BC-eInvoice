# Jotex Business Central e-Invoice Extension

## Overview
This extension provides a complete integration between **Microsoft Dynamics 365 Business Central** and the **Lembaga Hasil Dalam Negeri (LHDN) MyInvois System** for Malaysia. It handles the end-to-end process of generating UBL 2.1 compliant e-Invoices, digitally signing them using X.509 certificates (via Azure Functions), and submitting them to the official LHDN API.

> **Target Version**: Business Central 22.0+ (SaaS/On-Prem)  
> **Region**: Malaysia (MY)

## Key Features
- **Compliance**: Fully compliant with LHDN MyInvois Guidelines (Model 2.1).
- **Document Support**: 
  - Standard Invoices (01)
  - Credit Notes (02)
  - Debit Notes (03)
  - Self-billed Invoices (11, 12, 13, 14)
- **Digital Signing**: Secure, offloaded signing using Azure Functions to handle P12 certificates.
- **Automation**: Automatic status tracking, background batch processing, and extensive logging.
- **TIN Validation**: Integrated validation of Tax Identification Numbers with LHDN.

## Documentation Map

| Document | Audience | Description |
|----------|----------|-------------|
| **[Handover Documentation](HANDOVER.md)** | **Developers** | **Start Here**. Architecture, design decisions, and critical technical context. |
| [Documentation Overview](MyInvois_LHDN_Documentation_Overview.md) | All | Complete index of all available documentation. |
| [User Guide](MyInvois_LHDN_User_Guide.md) | End Users | How to issue, view, and cancel e-Invoices. |
| [Developer Guide](MyInvois_LHDN_Developer_Guide.md) | Developers | API references, code samples, and extensibility points. |
| [Installation Guide](MyInvois_LHDN_Installation_Guide.md) | Admins | Setup instructions for BC and Azure resources. |
| [Troubleshooting Guide](MyInvois_LHDN_Troubleshooting_Guide.md) | Support | Error codes, common issues, and debugging steps. |

## Quick Start
1. **Install the Extension**: Deploy the `.app` file to your environment.
2. **Setup**:
   - Go to **eInvoice Setup**.
   - Enter your **Azure Function URL** (for signing).
   - Configure **LHDN API Credentials** (Client ID/Secret) for PreProd/Production.
   - Set up **Company Information** (TIN, MSIC, etc.).
3. **Validate**: 
   - Open a **Customer Card**, ensure TIN is valid using the "Validate TIN" action.
4. **Transact**:
   - Post a **Sales Invoice**.
   - Click **"Sign & Submit to LHDN"** on the Posted Sales Invoice page.

## Dependencies
- **SalesPurchaseReport** (Publisher: Evopoint Izzat). Ensure this dependency is installed (min version 1.0.0.199).

## Architecture
The solution uses a **Sidecar Architecture**:
1. **Business Central**: Generates UBL JSON (unsigned).
2. **Azure Function**: Receives JSON + Cert, signs it (XAdES), returns signed JSON.
3. **Business Central**: Submits signed JSON to LHDN API and tracks status.

See [System Documentation](MyInvois_LHDN_eInvoice_System_Documentation.md) for deeper architectural details.
