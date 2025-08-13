## MyInvois LHDN e-Invoice System — Developer Guide (Concise)

### Purpose
Compact reference for developers integrating Malaysia LHDN MyInvois with Business Central in this extension. Covers setup, object map, core flows, interfaces, rules, and troubleshooting.

### Capabilities
- Digital signing via Azure Function, then submission to LHDN MyInvois
- Documents: Invoice (01), Credit Note (02), Debit Note (03), Refund Note (04), plus self-billed variants
- UBL 2.1 JSON generation (v1.1 profile)
- Status tracking and audit logging
- Page actions to Sign & Submit, generate JSON, and check status

## Object Map (key only)
- Codeunit `eInvoice JSON Generator` (50302)
  - JSON build, Azure Function call, LHDN submission
  - Public:
    - `GetSignedInvoiceAndSubmitToLHDN(Sales Invoice Header; var Text) : Boolean`
    - `GetSignedCreditMemoAndSubmitToLHDN(Sales Cr.Memo Header; var Text) : Boolean`
    - `GenerateEInvoiceJson(Sales Invoice Header; IncludeSignature: Boolean) : Text`
    - `GenerateCreditMemoEInvoiceJson(Sales Cr.Memo Header; IncludeSignature: Boolean) : Text`
    - `SetSuppressUserDialogs(Boolean)`
  - Notable locals:
    - `AddAmountField(var JsonObject; FieldName: Text; Amount: Decimal; Currency: Text)` — allows negative `LineExtensionAmount` at line level; still blocks negative `TaxAmount` and `PayableAmount`.
- Codeunit `eInvoiceAzureFunctionClient` (50310) — outbound HTTP (if used separately)
- Codeunit `eInvoiceSubmissionStatus` (50312) — status + logs
- Pages (extensions)
  - Posted Sales Invoice: action `Sign & Submit to LHDN`
  - Posted Sales Cr. Memo: action `Sign & Submit to LHDN`
  - Posted Return Receipt: action `Sign & Submit to LHDN` (uses linked Posted Credit Memo)

## Setup (minimal path)
1. Open `eInvoice Setup Card` (`Pag50300`)
2. Configure:
   - Azure Function URL (signing service)
   - Environment: PREPROD or PRODUCTION
   - LHDN API base URLs/tokens per environment
3. Master data:
   - Company TIN/BRN, address, bank info
   - Customer e-Invoice flags, TIN/ID type, address codes
   - Item classification (PTC + CLASS), tax type, UOM; currency/state/country codes

## End‑to‑End Flow
1. User clicks `Sign & Submit to LHDN` on a posted document
2. Extension generates UBL 2.1 JSON (unsigned)
3. JSON is sent to Azure Function for digital signing
4. Function returns `signedJson` and `lhdnPayload`
5. Extension submits `lhdnPayload` to LHDN API
6. Response is logged in `eInvoice Submission Log`; page shows status/notifications

## Azure Function Interface
- Request (core fields)
```json
{
  "unsignedJson": "...",
  "invoiceType": "01|02|03|04",
  "environment": "PREPROD|PRODUCTION",
  "timestamp": "YYYY-MM-DDThh:mm:ssZ",
  "correlationId": "GUID",
  "requestId": "GUID"
}
```
- Response (expected)
```json
{
  "success": true,
  "signedJson": "...",
  "lhdnPayload": { "documents": [ /* per LHDN spec */ ] },
  "message": "optional"
}
```

## LHDN API (references)
- See official SDK: [Start](https://sdk.myinvois.hasil.gov.my/start/), [Standard Headers](https://sdk.myinvois.hasil.gov.my/standard-header-parameters/), [Errors](https://sdk.myinvois.hasil.gov.my/standard-error-response/)
- Submission and retrieval:
  - [Submit Documents](https://sdk.myinvois.hasil.gov.my/einvoicingapi/02-submit-documents/)
  - [Get Submission](https://sdk.myinvois.hasil.gov.my/einvoicingapi/06-get-submission/)
  - [Get Document](https://sdk.myinvois.hasil.gov.my/einvoicingapi/07-get-document/)
  - [Get Document Details](https://sdk.myinvois.hasil.gov.my/einvoicingapi/08-get-document-details/)
  - [Cancel](https://sdk.myinvois.hasil.gov.my/einvoicingapi/03-cancel-document/), [Reject](https://sdk.myinvois.hasil.gov.my/einvoicingapi/04-reject-document/)

## Data Rules and Validations (high‑signal)
- UBL 2.1 v1.1 profile for Malaysia.
- Line classifications: require PTC and CLASS codes.
- Negative amounts:
  - Line level: `LineExtensionAmount` may be negative (discount/adjustment lines).
  - Totals: `TaxAmount` and `PayableAmount` must not be negative.
- Credit Notes (02) should be used for document‑level negatives or returns.
- Currency, state, country, tax type, UOM must be valid per local code lists.

## Troubleshooting (quick)
- "Invalid structured submission": verify UBL namespaces and schema; check version (1.1) and arrays/objects shape.
- "Amount field LineExtensionAmount cannot be negative": fixed in generator; ensure you’re on current build. If still hit, confirm your call path uses `AddAmountField` after update.
- Azure Function communication: check URL, network/firewall, and function auth; capture response and correlation ID.
- Credit memo linkage: when raised from Return Receipt, ensure the linked Posted Credit Memo exists.

## Operational Tips
- Use posted document actions for single submissions; use batch reports for bulk export.
- Check `eInvoice Submission Log` for full payloads/responses and correlation IDs.
- For UI flows where popups are undesired, call `SetSuppressUserDialogs(true)` before submission.

## Change Highlights (current)
- Allow negative `LineExtensionAmount` at line level; still block negative `TaxAmount` and `PayableAmount`.
- Posted Return Receipt action submits based on its linked Posted Credit Memo.

## References
- SDK samples and specs: [Document Types](https://sdk.myinvois.hasil.gov.my/codes/e-invoice-types/), [Invoice v1.1](https://sdk.myinvois.hasil.gov.my/documents/invoice-v1-1/), [Credit v1.1](https://sdk.myinvois.hasil.gov.my/documents/credit-v1-1/), [Debit v1.1](https://sdk.myinvois.hasil.gov.my/documents/debit-v1-1/)
 

