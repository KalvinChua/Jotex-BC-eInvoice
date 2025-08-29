# MyInvois LHDN e-Invoice System - API Integration Guide

## Overview

This guide provides comprehensive examples and procedures for integrating with the MyInvois LHDN e-Invoice system APIs, including LHDN MyInvois API, Azure Functions, and Business Central APIs. It includes practical code examples, testing procedures, and best practices for API integration.

---

## Table of Contents

1. [LHDN API Integration](#lhdn-api-integration)
2. [Azure Function Integration](#azure-function-integration)
3. [Business Central API Integration](#business-central-api-integration)
4. [Testing Procedures](#testing-procedures)
5. [Error Handling](#error-handling)
6. [Security Best Practices](#security-best-practices)
7. [Performance Optimization](#performance-optimization)
8. [Monitoring and Logging](#monitoring-and-logging)

---

## LHDN API Integration

### API Authentication

#### OAuth 2.0 Client Credentials Flow
```bash
# Obtain access token from LHDN
curl -X POST "https://preprod-api.myinvois.hasil.gov.my/connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=YOUR_CLIENT_ID" \
  -d "client_secret=YOUR_CLIENT_SECRET" \
  -d "scope=InvoicingAPI"
```

#### AL Implementation
```al
// LHDN API authentication in AL
procedure GetLhdnAccessToken(): Text
var
    HttpClient: HttpClient;
    HttpRequestMessage: HttpRequestMessage;
    HttpResponseMessage: HttpResponseMessage;
    Setup: Record "eInvoiceSetup";
    RequestBody: Text;
    ResponseBody: Text;
    JsonObject: JsonObject;
    AccessToken: Text;
begin
    Setup.Get();

    // Prepare request
    RequestBody := 'grant_type=client_credentials&';
    RequestBody += 'client_id=' + Setup."Client ID" + '&';
    RequestBody += 'client_secret=' + Setup."Client Secret" + '&';
    RequestBody += 'scope=InvoicingAPI';

    HttpRequestMessage.SetRequestUri(Setup."LHDN API URL" + '/connect/token');
    HttpRequestMessage.Method('POST');
    HttpRequestMessage.Content.WriteFrom(RequestBody);
    HttpRequestMessage.GetHeaders().Add('Content-Type', 'application/x-www-form-urlencoded');

    // Send request
    if HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then begin
        HttpResponseMessage.Content.ReadAs(ResponseBody);

        if HttpResponseMessage.IsSuccessStatusCode then begin
            // Parse response
            if JsonObject.ReadFrom(ResponseBody) then begin
                JsonObject.Get('access_token', AccessToken);
                exit(AccessToken);
            end;
        end else begin
            Error('LHDN authentication failed: %1', ResponseBody);
        end;
    end;

    exit('');
end;
```

### Document Submission

#### Submit Invoice to LHDN
```bash
# Submit invoice using LHDN API
curl -X POST "https://preprod-api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "language": "en",
    "documents": [
      {
        "format": "JSON",
        "documentHash": "YOUR_DOCUMENT_HASH",
        "codeNumber": "YOUR_CODE_NUMBER",
        "document": "YOUR_UBL_JSON_DOCUMENT"
      }
    ]
  }'
```

#### AL Implementation
```al
// Submit document to LHDN API
procedure SubmitDocumentToLhdn(DocumentJson: Text; DocumentHash: Text; CodeNumber: Text): Text
var
    HttpClient: HttpClient;
    HttpRequestMessage: HttpRequestMessage;
    HttpResponseMessage: HttpResponseMessage;
    Setup: Record "eInvoiceSetup";
    RequestBody: Text;
    ResponseBody: Text;
    AccessToken: Text;
    JsonObject: JsonObject;
    DocumentsArray: JsonArray;
    DocumentObject: JsonObject;
begin
    Setup.Get();
    AccessToken := GetLhdnAccessToken();

    // Build request payload
    JsonObject.Add('language', 'en');

    // Add document to array
    DocumentObject.Add('format', 'JSON');
    DocumentObject.Add('documentHash', DocumentHash);
    DocumentObject.Add('codeNumber', CodeNumber);
    DocumentObject.Add('document', DocumentJson);
    DocumentsArray.Add(DocumentObject);

    JsonObject.Add('documents', DocumentsArray);
    JsonObject.WriteTo(RequestBody);

    // Prepare HTTP request
    HttpRequestMessage.SetRequestUri(Setup."LHDN API URL" + '/api/v1.0/documentsubmissions');
    HttpRequestMessage.Method('POST');
    HttpRequestMessage.Content.WriteFrom(RequestBody);

    // Set headers
    HttpRequestMessage.GetHeaders().Add('Authorization', 'Bearer ' + AccessToken);
    HttpRequestMessage.GetHeaders().Add('Content-Type', 'application/json');

    // Send request
    if HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then begin
        HttpResponseMessage.Content.ReadAs(ResponseBody);

        if HttpResponseMessage.IsSuccessStatusCode then begin
            exit(ResponseBody);
        end else begin
            Error('LHDN submission failed: %1', ResponseBody);
        end;
    end;

    exit('');
end;
```

### Document Retrieval

#### Get Submission Status
```bash
# Get submission status
curl -X GET "https://preprod-api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions/YOUR_SUBMISSION_ID" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json"
```

#### Get Document Details
```bash
# Get document details
curl -X GET "https://preprod-api.myinvois.hasil.gov.my/api/v1.0/documents/YOUR_DOCUMENT_ID" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json"
```

#### AL Implementation
```al
// Get document status from LHDN
procedure GetDocumentStatus(DocumentId: Text): Text
var
    HttpClient: HttpClient;
    HttpRequestMessage: HttpRequestMessage;
    HttpResponseMessage: HttpResponseMessage;
    Setup: Record "eInvoiceSetup";
    ResponseBody: Text;
    AccessToken: Text;
begin
    Setup.Get();
    AccessToken := GetLhdnAccessToken();

    // Prepare request
    HttpRequestMessage.SetRequestUri(Setup."LHDN API URL" + '/api/v1.0/documents/' + DocumentId);
    HttpRequestMessage.Method('GET');

    // Set headers
    HttpRequestMessage.GetHeaders().Add('Authorization', 'Bearer ' + AccessToken);
    HttpRequestMessage.GetHeaders().Add('Content-Type', 'application/json');

    // Send request
    if HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then begin
        HttpResponseMessage.Content.ReadAs(ResponseBody);

        if HttpResponseMessage.IsSuccessStatusCode then begin
            exit(ResponseBody);
        end else begin
            Error('Failed to get document status: %1', ResponseBody);
        end;
    end;

    exit('');
end;
```

### TIN Validation

#### Validate Taxpayer Identification Number
```bash
# Validate TIN with LHDN
curl -X GET "https://preprod-api.myinvois.hasil.gov.my/api/v1.0/taxpayer/validation/YOUR_TIN" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json"
```

#### AL Implementation
```al
// Validate TIN with LHDN API
procedure ValidateTinWithLhdn(TinNumber: Text): Boolean
var
    HttpClient: HttpClient;
    HttpRequestMessage: HttpRequestMessage;
    HttpResponseMessage: HttpResponseMessage;
    Setup: Record "eInvoiceSetup";
    ResponseBody: Text;
    AccessToken: Text;
    JsonObject: JsonObject;
    IsValid: Boolean;
begin
    Setup.Get();
    AccessToken := GetLhdnAccessToken();

    // Prepare request
    HttpRequestMessage.SetRequestUri(Setup."LHDN API URL" + '/api/v1.0/taxpayer/validation/' + TinNumber);
    HttpRequestMessage.Method('GET');

    // Set headers
    HttpRequestMessage.GetHeaders().Add('Authorization', 'Bearer ' + AccessToken);
    HttpRequestMessage.GetHeaders().Add('Content-Type', 'application/json');

    // Send request
    if HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then begin
        HttpResponseMessage.Content.ReadAs(ResponseBody);

        if HttpResponseMessage.IsSuccessStatusCode then begin
            // Parse response
            if JsonObject.ReadFrom(ResponseBody) then begin
                JsonObject.Get('isValid', IsValid);
                exit(IsValid);
            end;
        end;
    end;

    exit(false);
end;
```

---

## Azure Function Integration

### Function Configuration

#### host.json Configuration
```json
{
  "version": "2.0",
  "logging": {
    "applicationInsights": {
      "samplingSettings": {
        "isEnabled": true,
        "excludedTypes": "Request"
      }
    }
  },
  "extensionBundle": {
    "id": "Microsoft.Azure.Functions.ExtensionBundle",
    "version": "[3.*, 4.0.0)"
  },
  "extensions": {
    "http": {
      "routePrefix": "api",
      "maxOutstandingRequests": 200,
      "maxConcurrentRequests": 100,
      "dynamicThrottlesEnabled": true
    }
  }
}
```

#### local.settings.json for Development
```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "dotnet",
    "ENVIRONMENT": "PREPROD",
    "LHDN_API_URL": "https://preprod-api.myinvois.hasil.gov.my",
    "CERTIFICATE_PASSWORD": "your-certificate-password",
    "LOG_LEVEL": "Information"
  }
}
```

### Azure Function Code Examples

#### Reference Implementation

**Note**: The following examples are based on the reference implementation available at:
**GitHub Repository**: https://github.com/acutraaq/eInvAzureSign

This repository contains the actual Azure Function code used for document signing in the MyInvois LHDN e-Invoice system. Please refer to this repository for the most up-to-date implementation details.

#### Document Signing Function (Based on Reference Implementation)
```csharp
// Based on: https://github.com/acutraaq/eInvAzureSign
using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using System.Security.Cryptography.X509Certificates;
using System.Security.Cryptography.Pkcs;
using System.Security.Cryptography;

public static class SignDocumentFunction
{
    [FunctionName("SignDocument")]
    public static async Task<IActionResult> Run(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = null)] HttpRequest req,
        ILogger log)
    {
        log.LogInformation("Document signing request received");

        try
        {
            // Parse request
            string requestBody = await new StreamReader(req.Body).ReadToEndAsync();
            dynamic data = JsonConvert.DeserializeObject(requestBody);

            // Validate input
            if (data?.unsignedJson == null || data?.invoiceType == null)
            {
                return new BadRequestObjectResult("Missing required parameters");
            }

            // Sign document using reference implementation
            var signedDocument = await SignDocumentWithCertificate(data.unsignedJson.ToString());

            // Prepare LHDN payload
            var lhdnPayload = PrepareLhdnPayload(signedDocument, data.invoiceType.ToString());

            // Return response
            return new OkObjectResult(new
            {
                success = true,
                signedJson = signedDocument,
                lhdnPayload = lhdnPayload,
                message = "Document signed successfully"
            });
        }
        catch (Exception ex)
        {
            log.LogError($"Signing failed: {ex.Message}");
            return new ObjectResult(new
            {
                success = false,
                message = $"Signing failed: {ex.Message}"
            })
            { StatusCode = 500 };
        }
    }

    private static async Task<string> SignDocumentWithCertificate(string unsignedJson)
    {
        // Implementation based on: https://github.com/acutraaq/eInvAzureSign
        // Load certificate from Key Vault or local store
        var certificate = LoadCertificate();

        // Create content to sign
        var content = new ContentInfo(Encoding.UTF8.GetBytes(unsignedJson));

        // Create signed CMS
        var signedCms = new SignedCms(content, true);
        var cmsSigner = new CmsSigner(certificate);

        // Sign the content
        signedCms.ComputeSignature(cmsSigner);

        // Encode to Base64
        return Convert.ToBase64String(signedCms.Encode());
    }

    private static X509Certificate2 LoadCertificate()
    {
        // Refer to: https://github.com/acutraaq/eInvAzureSign
        // Load certificate from Key Vault or environment
        var certPassword = Environment.GetEnvironmentVariable("CERTIFICATE_PASSWORD");
        var certData = Convert.FromBase64String(Environment.GetEnvironmentVariable("CERTIFICATE_DATA"));

        return new X509Certificate2(certData, certPassword);
    }

    private static object PrepareLhdnPayload(string signedJson, string invoiceType)
    {
        return new
        {
            language = "en",
            documents = new[]
            {
                new
                {
                    format = "JSON",
                    documentHash = ComputeSha256Hash(signedJson),
                    codeNumber = GenerateCodeNumber(),
                    document = signedJson
                }
            }
        };
    }

    private static string ComputeSha256Hash(string input)
    {
        using (var sha256 = SHA256.Create())
        {
            var bytes = Encoding.UTF8.GetBytes(input);
            var hash = sha256.ComputeHash(bytes);
            return Convert.ToBase64String(hash);
        }
    }

    private static string GenerateCodeNumber()
    {
        return DateTime.UtcNow.ToString("yyyyMMddHHmmssfff");
    }
}
```

#### Health Check Function
```csharp
using System;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;

public static class HealthCheckFunction
{
    [FunctionName("HealthCheck")]
    public static IActionResult Run(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "health")] HttpRequest req,
        ILogger log)
    {
        log.LogInformation("Health check request received");

        return new OkObjectResult(new
        {
            status = "healthy",
            timestamp = DateTime.UtcNow,
            version = "1.0.0",
            environment = Environment.GetEnvironmentVariable("ENVIRONMENT")
        });
    }
}
```

### Azure Function Deployment

#### Deploy via Azure CLI
```bash
# Create resource group
az group create --name "rg-myinvois-prod" --location "southeastasia"

# Create storage account
az storage account create \
  --name "stmyinvoisprod" \
  --resource-group "rg-myinvois-prod" \
  --location "southeastasia" \
  --sku "Standard_LRS"

# Create function app
az functionapp create \
  --name "func-myinvois-prod" \
  --resource-group "rg-myinvois-prod" \
  --storage-account "stmyinvoisprod" \
  --consumption-plan-location "southeastasia" \
  --runtime "dotnet" \
  --runtime-version "6.0" \
  --functions-version "4"

# Configure app settings
az functionapp config appsettings set \
  --name "func-myinvois-prod" \
  --resource-group "rg-myinvois-prod" \
  --settings \
    "ENVIRONMENT=PRODUCTION" \
    "LHDN_API_URL=https://api.myinvois.hasil.gov.my" \
    "LOG_LEVEL=Information"

# Deploy function code
az functionapp deployment source config \
  --name "func-myinvois-prod" \
  --resource-group "rg-myinvois-prod" \
  --repo-url "https://github.com/your-org/myinvois-functions" \
  --branch "main" \
  --manual-integration
```

#### Deploy via Visual Studio Code
```json
// .vscode/settings.json
{
  "azureFunctions.deploySubpath": ".",
  "azureFunctions.projectLanguage": "C#",
  "azureFunctions.projectRuntime": "~4",
  "azureFunctions.templateFilter": "Verified"
}
```

---

## Business Central API Integration

### REST API Integration

#### Call Business Central APIs from External Systems
```bash
# Get sales invoices
curl -X GET "https://api.businesscentral.dynamics.com/v2.0/your-tenant/production/api/v2.0/companies({company-id})/salesInvoices" \
  -H "Authorization: Bearer YOUR_BC_ACCESS_TOKEN" \
  -H "Content-Type: application/json"
```

#### Create Sales Invoice via API
```bash
# Create sales invoice
curl -X POST "https://api.businesscentral.dynamics.com/v2.0/your-tenant/production/api/v2.0/companies({company-id})/salesInvoices" \
  -H "Authorization: Bearer YOUR_BC_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "customerNumber": "CUST001",
    "postingDate": "2024-01-15",
    "dueDate": "2024-02-14",
    "salesInvoiceLines": [
      {
        "lineType": "Item",
        "lineObjectNumber": "ITEM001",
        "quantity": 10,
        "unitPrice": 100.00
      }
    ]
  }'
```

### Custom API Endpoints

#### Create Custom API for e-Invoice Operations
```al
// Custom API page for e-Invoice operations
page 50100 "eInvoice API"
{
    PageType = API;
    APIPublisher = 'YourPublisher';
    APIGroup = 'eInvoice';
    APIVersion = 'v1.0';
    EntityName = 'eInvoice';
    EntitySetName = 'eInvoices';
    SourceTable = "Sales Invoice Header";
    DelayedInsert = true;

    layout
    {
        area(content)
        {
            field(id; Rec."No.")
            {
                ApplicationArea = All;
                Caption = 'id';
            }
            field(customerNumber; Rec."Sell-to Customer No.")
            {
                ApplicationArea = All;
                Caption = 'customerNumber';
            }
            field(invoiceDate; Rec."Posting Date")
            {
                ApplicationArea = All;
                Caption = 'invoiceDate';
            }
            field(totalAmount; Rec."Amount Including VAT")
            {
                ApplicationArea = All;
                Caption = 'totalAmount';
            }
            field(eInvoiceStatus; Rec."eInvoice Validation Status")
            {
                ApplicationArea = All;
                Caption = 'eInvoiceStatus';
            }
        }
    }

    actions
    {
        area(processing)
        {
            action(SubmitToLHDN)
            {
                ApplicationArea = All;
                Caption = 'Submit to LHDN';

                trigger OnAction()
                var
                    eInvoiceGenerator: Codeunit "eInvoice JSON Generator";
                    LhdnResponse: Text;
                begin
                    if eInvoiceGenerator.GetSignedInvoiceAndSubmitToLHDN(Rec, LhdnResponse) then
                        Message('Invoice submitted successfully')
                    else
                        Error('Submission failed: %1', LhdnResponse);
                end;
            }
        }
    }
}
```

### Web Service Integration

#### SOAP Web Service for Legacy Systems
```al
// SOAP web service for e-Invoice operations
codeunit 50101 "eInvoice SOAP Service"
{
    trigger OnRun()
    begin
    end;

    [ServiceEnabled]
    procedure SubmitInvoiceSOAP(InvoiceNo: Text): Text
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        eInvoiceGenerator: Codeunit "eInvoice JSON Generator";
        LhdnResponse: Text;
    begin
        if SalesInvoiceHeader.Get(InvoiceNo) then begin
            if eInvoiceGenerator.GetSignedInvoiceAndSubmitToLHDN(SalesInvoiceHeader, LhdnResponse) then
                exit('SUCCESS: Invoice submitted to LHDN')
            else
                exit('ERROR: ' + LhdnResponse);
        end else
            exit('ERROR: Invoice not found');
    end;

    [ServiceEnabled]
    procedure GetInvoiceStatusSOAP(InvoiceNo: Text): Text
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
    begin
        if SalesInvoiceHeader.Get(InvoiceNo) then
            exit(SalesInvoiceHeader."eInvoice Validation Status")
        else
            exit('ERROR: Invoice not found');
    end;
}
```

---

## Testing Procedures

### Unit Testing

#### Test LHDN API Integration
```al
[Test]
procedure TestLhdnApiAuthentication()
var
    eInvoiceSetup: Record "eInvoiceSetup";
    AccessToken: Text;
begin
    // Setup test data
    InitializeTestEnvironment();

    // Test authentication
    AccessToken := GetLhdnAccessToken();

    // Assert
    Assert.AreNotEqual('', AccessToken, 'Access token should not be empty');
    Assert.IsTrue(StrLen(AccessToken) > 100, 'Access token should be substantial length');
end;

[Test]
procedure TestDocumentSubmission()
var
    SalesInvoiceHeader: Record "Sales Invoice Header";
    eInvoiceGenerator: Codeunit "eInvoice JSON Generator";
    JsonText: Text;
    SubmissionResult: Boolean;
begin
    // Setup test invoice
    LibrarySales.CreateSalesInvoice(SalesInvoiceHeader);
    SetupEInvoiceFields(SalesInvoiceHeader);

    // Generate JSON
    JsonText := eInvoiceGenerator.GenerateEInvoiceJson(SalesInvoiceHeader, false);
    Assert.AreNotEqual('', JsonText, 'JSON should not be empty');

    // Test submission (mocked in test environment)
    SubmissionResult := SubmitDocumentToLhdn(JsonText, 'TEST123', 'CODE001');
    Assert.IsTrue(SubmissionResult, 'Document submission should succeed');
end;
```

### Integration Testing

#### End-to-End Test Scenario
```al
[Test]
procedure TestEndToEndInvoiceProcessing()
var
    SalesInvoiceHeader: Record "Sales Invoice Header";
    Customer: Record Customer;
    eInvoiceGenerator: Codeunit "eInvoice JSON Generator";
    JsonText: Text;
    SignedJson: Text;
    LhdnPayload: Text;
    SubmissionResult: Text;
begin
    // 1. Setup test customer
    LibrarySales.CreateCustomer(Customer);
    SetupEInvoiceCustomer(Customer);

    // 2. Create and post sales invoice
    LibrarySales.CreateSalesInvoice(SalesInvoiceHeader);
    SalesInvoiceHeader."Sell-to Customer No." := Customer."No.";
    SalesInvoiceHeader.Modify();
    LibrarySales.PostSalesDocument(SalesInvoiceHeader, true, true);

    // 3. Generate e-Invoice JSON
    JsonText := eInvoiceGenerator.GenerateEInvoiceJson(SalesInvoiceHeader, false);
    Assert.AreNotEqual('', JsonText, 'JSON generation should succeed');

    // 4. Test Azure Function signing (mocked)
    SignedJson := MockAzureFunctionSigning(JsonText);
    Assert.AreNotEqual('', SignedJson, 'Signing should succeed');

    // 5. Test LHDN submission (mocked)
    SubmissionResult := MockLhdnSubmission(SignedJson);
    Assert.AreNotEqual('', SubmissionResult, 'Submission should succeed');

    // 6. Verify status update
    SalesInvoiceHeader.Get(SalesInvoiceHeader."No.");
    Assert.AreEqual('Submitted', SalesInvoiceHeader."eInvoice Validation Status",
                   'Status should be updated to Submitted');
end;
```

### Load Testing

#### Performance Load Test
```al
[Test]
procedure TestBulkInvoiceProcessing()
var
    SalesInvoiceHeader: Record "Sales Invoice Header";
    eInvoiceGenerator: Codeunit "eInvoice JSON Generator";
    StartTime: DateTime;
    EndTime: DateTime;
    ProcessingTime: Duration;
    i: Integer;
    BatchSize: Integer;
begin
    BatchSize := 50; // Test with 50 invoices
    StartTime := CurrentDateTime;

    for i := 1 to BatchSize do begin
        // Create and process invoice
        LibrarySales.CreateSalesInvoice(SalesInvoiceHeader);
        SetupEInvoiceFields(SalesInvoiceHeader);

        // Generate and submit
        ProcessInvoiceForTesting(SalesInvoiceHeader);
    end;

    EndTime := CurrentDateTime;
    ProcessingTime := EndTime - StartTime;

    // Assert performance requirements
    Assert.IsTrue(ProcessingTime < 300000, // 5 minutes
                 'Bulk processing should complete within 5 minutes');

    // Average processing time per invoice
    Assert.IsTrue(ProcessingTime / BatchSize < 10000, // 10 seconds
                 'Average processing time should be less than 10 seconds per invoice');
end;
```

### API Testing Tools

#### Postman Collection for LHDN API Testing
```json
{
  "info": {
    "name": "MyInvois LHDN API Collection",
    "description": "Complete API collection for testing LHDN MyInvois integration"
  },
  "item": [
    {
      "name": "Authentication",
      "item": [
        {
          "name": "Get Access Token",
          "request": {
            "method": "POST",
            "header": [
              {
                "key": "Content-Type",
                "value": "application/x-www-form-urlencoded"
              }
            ],
            "body": {
              "mode": "urlencoded",
              "urlencoded": [
                {
                  "key": "grant_type",
                  "value": "client_credentials"
                },
                {
                  "key": "client_id",
                  "value": "{{client_id}}"
                },
                {
                  "key": "client_secret",
                  "value": "{{client_secret}}"
                },
                {
                  "key": "scope",
                  "value": "InvoicingAPI"
                }
              ]
            },
            "url": {
              "raw": "{{lhdn_base_url}}/connect/token",
              "host": ["{{lhdn_base_url}}"],
              "path": ["connect", "token"]
            }
          }
        }
      ]
    },
    {
      "name": "Document Operations",
      "item": [
        {
          "name": "Submit Document",
          "request": {
            "method": "POST",
            "header": [
              {
                "key": "Authorization",
                "value": "Bearer {{access_token}}"
              },
              {
                "key": "Content-Type",
                "value": "application/json"
              }
            ],
            "body": {
              "mode": "raw",
              "raw": "{\n  \"language\": \"en\",\n  \"documents\": [\n    {\n      \"format\": \"JSON\",\n      \"documentHash\": \"{{document_hash}}\",\n      \"codeNumber\": \"{{code_number}}\",\n      \"document\": \"{{ubl_json_document}}\"\n    }\n  ]\n}"
            },
            "url": {
              "raw": "{{lhdn_base_url}}/api/v1.0/documentsubmissions",
              "host": ["{{lhdn_base_url}}"],
              "path": ["api", "v1.0", "documentsubmissions"]
            }
          }
        }
      ]
    }
  ],
  "variable": [
    {
      "key": "lhdn_base_url",
      "value": "https://preprod-api.myinvois.hasil.gov.my"
    },
    {
      "key": "client_id",
      "value": "your-client-id"
    },
    {
      "key": "client_secret",
      "value": "your-client-secret"
    }
  ]
}
```

---

## Error Handling

### Comprehensive Error Handling Strategy

#### Error Classification
```al
// Error classification and handling
procedure ClassifyAndHandleError(ErrorMessage: Text; ErrorCode: Text): Text
var
    ErrorCategory: Text;
    RecommendedAction: Text;
begin
    case true of
        ErrorMessage.Contains('Invalid TIN'):
            begin
                ErrorCategory := 'DATA_VALIDATION';
                RecommendedAction := 'Verify customer TIN and ID type';
            end;
        ErrorMessage.Contains('Authentication failed'):
            begin
                ErrorCategory := 'AUTHENTICATION';
                RecommendedAction := 'Check API credentials and token validity';
            end;
        ErrorMessage.Contains('timeout'):
            begin
                ErrorCategory := 'CONNECTIVITY';
                RecommendedAction := 'Retry submission and check network connectivity';
            end;
        ErrorMessage.Contains('Invalid structured submission'):
            begin
                ErrorCategory := 'FORMAT_ERROR';
                RecommendedAction := 'Validate UBL JSON structure and namespaces';
            end;
        else
            begin
                ErrorCategory := 'UNKNOWN';
                RecommendedAction := 'Contact system administrator for investigation';
            end;
    end;

    exit(StrSubstNo('Category: %1\nAction: %2', ErrorCategory, RecommendedAction));
end;
```

### Retry Logic Implementation

#### Exponential Backoff Retry
```al
// Implement intelligent retry logic
procedure SubmitWithIntelligentRetry(DocumentNo: Code[20]; Payload: Text; MaxRetries: Integer): Boolean
var
    RetryCount: Integer;
    Success: Boolean;
    DelayMs: Integer;
    BaseDelay: Integer;
    MaxDelay: Integer;
    Response: Text;
    ErrorCategory: Text;
begin
    RetryCount := 0;
    BaseDelay := 1000; // 1 second
    MaxDelay := 30000; // 30 seconds

    repeat
        Success := SubmitToLhdnApi(Payload, Response);

        if Success then begin
            LogSuccess(DocumentNo, Response, RetryCount);
            exit(true);
        end;

        // Classify error for retry decision
        ErrorCategory := GetErrorCategory(Response);

        // Only retry on transient errors
        if not IsRetryableError(ErrorCategory) then begin
            LogPermanentFailure(DocumentNo, Response);
            exit(false);
        end;

        RetryCount += 1;

        if RetryCount <= MaxRetries then begin
            // Calculate delay with exponential backoff and jitter
            DelayMs := CalculateDelayWithJitter(BaseDelay, RetryCount, MaxDelay);

            LogRetryAttempt(DocumentNo, RetryCount, DelayMs, Response);
            Sleep(DelayMs);
        end;

    until (RetryCount > MaxRetries) or Success;

    LogFinalFailure(DocumentNo, MaxRetries, Response);
    exit(false);
end;

local procedure CalculateDelayWithJitter(BaseDelay: Integer; RetryCount: Integer; MaxDelay: Integer): Integer
var
    Delay: Integer;
    Jitter: Integer;
begin
    // Exponential backoff: BaseDelay * 2^(RetryCount-1)
    Delay := BaseDelay * Power(2, RetryCount - 1);

    // Cap at maximum delay
    if Delay > MaxDelay then
        Delay := MaxDelay;

    // Add jitter (±25%)
    Jitter := Random(Delay / 2) - (Delay / 4);
    Delay := Delay + Jitter;

    exit(Delay);
end;

local procedure IsRetryableError(ErrorCategory: Text): Boolean
begin
    case ErrorCategory of
        'CONNECTIVITY', 'TIMEOUT', 'SERVER_ERROR':
            exit(true);
        'AUTHENTICATION', 'VALIDATION', 'CLIENT_ERROR':
            exit(false);
        else
            exit(false);
    end;
end;
```

### Error Recovery Procedures

#### Automatic Error Recovery
```al
// Automatic error recovery system
procedure ExecuteErrorRecovery(DocumentNo: Code[20]; ErrorDetails: Text): Boolean
var
    RecoveryAction: Text;
    RecoveryResult: Boolean;
begin
    // Determine recovery action based on error
    RecoveryAction := DetermineRecoveryAction(ErrorDetails);

    case RecoveryAction of
        'RETRY_SUBMISSION':
            RecoveryResult := RetryDocumentSubmission(DocumentNo);
        'REFRESH_TOKEN':
            RecoveryResult := RefreshApiTokenAndRetry(DocumentNo);
        'VALIDATE_DATA':
            RecoveryResult := ValidateAndCorrectData(DocumentNo);
        'ESCALATE':
            RecoveryResult := EscalateToAdministrator(DocumentNo, ErrorDetails);
        else
            RecoveryResult := false;
    end;

    // Log recovery attempt
    LogRecoveryAttempt(DocumentNo, RecoveryAction, RecoveryResult);

    exit(RecoveryResult);
end;
```

---

## Security Best Practices

### API Security

#### Secure Credential Management
```al
// Secure API credential storage and retrieval
procedure GetSecureApiCredentials(): Text
var
    IsolatedStorage: Codeunit "Isolated Storage";
    Credentials: Text;
    CredentialKey: Text;
begin
    CredentialKey := 'LHDN_API_CREDENTIALS_' + Format(CompanyName);

    // Retrieve from isolated storage
    if IsolatedStorage.Get(CredentialKey, Credentials) then begin
        // Decrypt if necessary
        Credentials := DecryptCredentials(Credentials);
        exit(Credentials);
    end else
        Error('API credentials not configured. Please contact administrator.');
end;

procedure StoreSecureApiCredentials(ClientId: Text; ClientSecret: Text)
var
    IsolatedStorage: Codeunit "Isolated Storage";
    Credentials: Text;
    EncryptedCredentials: Text;
    CredentialKey: Text;
begin
    // Combine and encrypt credentials
    Credentials := ClientId + '|' + ClientSecret;
    EncryptedCredentials := EncryptCredentials(Credentials);

    CredentialKey := 'LHDN_API_CREDENTIALS_' + Format(CompanyName);

    // Store in isolated storage
    IsolatedStorage.Set(CredentialKey, EncryptedCredentials);
end;
```

#### Request Signing and Validation
```al
// Implement request signing for additional security
procedure SignApiRequest(RequestBody: Text; Timestamp: DateTime): Text
var
    Signature: Text;
    SecretKey: Text;
    StringToSign: Text;
begin
    SecretKey := GetApiSecretKey();
    StringToSign := RequestBody + Format(Timestamp, 0, '<Year4><Month,2><Day,2><Hours24><Minutes,2><Seconds,2>');

    // Create HMAC-SHA256 signature
    Signature := CalculateHMAC256(StringToSign, SecretKey);

    exit(Signature);
end;

procedure ValidateRequestSignature(RequestBody: Text; Timestamp: DateTime; ProvidedSignature: Text): Boolean
var
    ExpectedSignature: Text;
begin
    ExpectedSignature := SignApiRequest(RequestBody, Timestamp);

    // Verify signature with timing attack protection
    exit(VerifySignatureSecurely(ExpectedSignature, ProvidedSignature));
end;
```

### Data Protection

#### Data Encryption at Rest
```al
// Encrypt sensitive data before storage
procedure EncryptSensitiveData(PlainText: Text): Text
var
    CryptographyManagement: Codeunit "Cryptography Management";
    EncryptedText: Text;
begin
    // Use platform encryption
    EncryptedText := CryptographyManagement.Encrypt(PlainText);
    exit(EncryptedText);
end;

procedure DecryptSensitiveData(EncryptedText: Text): Text
var
    CryptographyManagement: Codeunit "Cryptography Management";
    PlainText: Text;
begin
    // Use platform decryption
    PlainText := CryptographyManagement.Decrypt(EncryptedText);
    exit(PlainText);
end;
```

#### Data Masking for Logs
```al
// Mask sensitive data in logs
procedure MaskSensitiveData(LogMessage: Text): Text
var
    MaskedMessage: Text;
    Regex: Codeunit Regex;
begin
    // Mask TIN numbers
    MaskedMessage := Regex.Replace(LogMessage, '\b\d{12}\b', '***TIN***');

    // Mask API keys
    MaskedMessage := Regex.Replace(MaskedMessage, 'Bearer\s+[A-Za-z0-9+/=]{20,}', 'Bearer ***API_KEY***');

    // Mask certificate passwords
    MaskedMessage := Regex.Replace(MaskedMessage, 'CERTIFICATE_PASSWORD\s*[:=]\s*\S+', 'CERTIFICATE_PASSWORD: ***MASKED***');

    exit(MaskedMessage);
end;
```

---

## Performance Optimization

### API Call Optimization

#### Connection Pooling
```al
// Implement connection pooling for API calls
codeunit 50102 "API Connection Pool Manager"
{
    var
        HttpClientPool: Dictionary of [Text, HttpClient];
        PoolSize: Integer;
        MaxPoolSize: Integer;

    procedure GetHttpClient(Endpoint: Text): HttpClient
    var
        ClientKey: Text;
        HttpClient: HttpClient;
    begin
        ClientKey := GetClientKey(Endpoint);

        if HttpClientPool.ContainsKey(ClientKey) then begin
            HttpClient := HttpClientPool.Get(ClientKey);
        end else begin
            HttpClient := CreateNewHttpClient(Endpoint);

            if PoolSize < MaxPoolSize then begin
                HttpClientPool.Add(ClientKey, HttpClient);
                PoolSize += 1;
            end;
        end;

        exit(HttpClient);
    end;

    local procedure CreateNewHttpClient(Endpoint: Text): HttpClient
    var
        NewHttpClient: HttpClient;
    begin
        // Configure client settings
        NewHttpClient.Timeout(30000); // 30 seconds
        // Add default headers if needed

        exit(NewHttpClient);
    end;

    local procedure GetClientKey(Endpoint: Text): Text
    begin
        // Group connections by domain
        if Endpoint.Contains('myinvois.hasil.gov.my') then
            exit('LHDN_API')
        else if Endpoint.Contains('azurewebsites.net') then
            exit('AZURE_FUNCTION')
        else
            exit('OTHER');
    end;
}
```

#### Batch Processing Optimization
```al
// Optimize batch processing for multiple documents
procedure ProcessDocumentBatch(var DocumentNos: List of [Code[20]]; BatchSize: Integer): Text
var
    ProcessingReport: Text;
    BatchCount: Integer;
    TotalProcessed: Integer;
    StartTime: DateTime;
    EndTime: DateTime;
    i: Integer;
    j: Integer;
begin
    StartTime := CurrentDateTime;
    BatchCount := Round(DocumentNos.Count() / BatchSize, 1, '>');

    for i := 1 to BatchCount do begin
        // Process batch
        for j := ((i - 1) * BatchSize) + 1 to Min(i * BatchSize, DocumentNos.Count()) do begin
            ProcessSingleDocument(DocumentNos.Get(j));
            TotalProcessed += 1;
        end;

        // Small delay between batches to prevent overwhelming APIs
        if i < BatchCount then
            Sleep(1000); // 1 second
    end;

    EndTime := CurrentDateTime;

    ProcessingReport := StrSubstNo(
        'Batch processing completed:\nTotal: %1\nBatches: %2\nTime: %3 seconds\nAvg per document: %4 ms',
        TotalProcessed,
        BatchCount,
        Round((EndTime - StartTime) / 1000, 0.01),
        Round((EndTime - StartTime) / TotalProcessed, 0.01)
    );

    exit(ProcessingReport);
end;
```

### Caching Strategies

#### Multi-Level Caching Implementation
```al
// Implement multi-level caching for performance
codeunit 50103 "MultiLevel Cache Manager"
{
    var
        MemoryCache: Dictionary of [Text, Text];
        DatabaseCache: Record "Cache Entry";
        RedisCache: Codeunit "Redis Cache Manager";
        CacheExpiry: Dictionary of [Text, DateTime];

    procedure GetCachedValue(Key: Text): Text
    var
        CachedValue: Text;
        ExpiryTime: DateTime;
    begin
        // Check memory cache first (fastest)
        if MemoryCache.ContainsKey(Key) then begin
            if not IsExpired(Key) then begin
                exit(MemoryCache.Get(Key));
            end else begin
                MemoryCache.Remove(Key);
                CacheExpiry.Remove(Key);
            end;
        end;

        // Check database cache
        if GetDatabaseCacheValue(Key, CachedValue) then
            exit(CachedValue);

        // Check Redis/external cache
        if RedisCache.GetValue(Key, CachedValue) then begin
            // Store in memory for faster future access
            SetMemoryCache(Key, CachedValue, 300000); // 5 minutes
            exit(CachedValue);
        end;

        exit('');
    end;

    procedure SetCachedValue(Key: Text; Value: Text; ExpiryMs: Integer)
    begin
        // Store in all levels
        SetMemoryCache(Key, Value, ExpiryMs);
        SetDatabaseCache(Key, Value, ExpiryMs);
        RedisCache.SetValue(Key, Value, ExpiryMs);
    end;

    local procedure SetMemoryCache(Key: Text; Value: Text; ExpiryMs: Integer)
    begin
        MemoryCache.Set(Key, Value);
        CacheExpiry.Set(Key, CurrentDateTime + ExpiryMs);
    end;

    local procedure IsExpired(Key: Text): Boolean
    var
        ExpiryTime: DateTime;
    begin
        if CacheExpiry.ContainsKey(Key) then begin
            CacheExpiry.Get(Key, ExpiryTime);
            exit(CurrentDateTime > ExpiryTime);
        end;
        exit(true);
    end;
}
```

---

## Monitoring and Logging

### Comprehensive Logging Strategy

#### Structured Logging Implementation
```al
// Implement structured logging for better analysis
procedure LogStructuredEvent(EventType: Text; EventData: Dictionary of [Text, Text])
var
    LogEntry: Record "Structured Log Entry";
    EventDataJson: Text;
    JsonObject: JsonObject;
    Key: Text;
begin
    // Create JSON from dictionary
    foreach Key in EventData.Keys() do
        JsonObject.Add(Key, EventData.Get(Key));

    JsonObject.WriteTo(EventDataJson);

    // Create log entry
    LogEntry.Init();
    LogEntry."Entry No." := 0; // Auto-increment
    LogEntry."Timestamp" := CurrentDateTime;
    LogEntry."Event Type" := EventType;
    LogEntry."Event Data" := EventDataJson;
    LogEntry."User ID" := UserId;
    LogEntry."Session ID" := SessionId;
    LogEntry.Insert();

    // Also log to external system if configured
    LogToExternalSystem(EventType, EventDataJson);
end;
```

#### Monitoring Dashboard Data Collection
```al
// Collect data for monitoring dashboard
procedure CollectMonitoringMetrics(): Text
var
    MetricsJson: Text;
    JsonObject: JsonObject;
    CurrentTime: DateTime;
begin
    CurrentTime := CurrentDateTime;

    // System health metrics
    JsonObject.Add('timestamp', Format(CurrentTime, 0, '<Year4>-<Month,2>-<Day,2>T<Hours24>:<Minutes,2>:<Seconds,2>Z'));
    JsonObject.Add('system_status', GetSystemHealthStatus());
    JsonObject.Add('active_sessions', GetActiveSessionCount());
    JsonObject.Add('memory_usage', GetMemoryUsagePercentage());
    JsonObject.Add('cpu_usage', GetCpuUsagePercentage());

    // e-Invoice specific metrics
    JsonObject.Add('pending_submissions', GetPendingSubmissionCount());
    JsonObject.Add('today_submissions', GetTodaysSubmissionCount());
    JsonObject.Add('success_rate', GetSubmissionSuccessRate());
    JsonObject.Add('average_processing_time', GetAverageProcessingTime());

    // API metrics
    JsonObject.Add('lhdn_api_calls', GetLhdnApiCallCount());
    JsonObject.Add('azure_function_calls', GetAzureFunctionCallCount());
    JsonObject.Add('api_error_rate', GetApiErrorRate());

    JsonObject.WriteTo(MetricsJson);
    exit(MetricsJson);
end;
```

### Alert System

#### Intelligent Alert Configuration
```al
// Configure intelligent alerting system
procedure ConfigureIntelligentAlerts()
begin
    // Performance alerts
    SetupPerformanceAlert('Average processing time > 60 seconds', 'WARNING');
    SetupPerformanceAlert('Average processing time > 120 seconds', 'CRITICAL');

    // Success rate alerts
    SetupSuccessRateAlert('Success rate < 95%', 'WARNING');
    SetupSuccessRateAlert('Success rate < 90%', 'CRITICAL');

    // System resource alerts
    SetupResourceAlert('Memory usage > 90%', 'CRITICAL');
    SetupResourceAlert('CPU usage > 80%', 'WARNING');

    // API connectivity alerts
    SetupConnectivityAlert('LHDN API unavailable > 5 minutes', 'CRITICAL');
    SetupConnectivityAlert('Azure Function unavailable > 10 minutes', 'CRITICAL');

    // Certificate alerts
    SetupCertificateAlert('Certificate expires < 30 days', 'WARNING');
    SetupCertificateAlert('Certificate expires < 7 days', 'CRITICAL');
end;
```

#### Automated Alert Response
```al
// Implement automated alert response
procedure ProcessAlert(AlertId: Text; AlertType: Text; Severity: Text; Details: Text)
var
    ResponseAction: Text;
    ResponseResult: Boolean;
begin
    // Log alert
    LogAlert(AlertId, AlertType, Severity, Details);

    // Determine response based on alert type and severity
    ResponseAction := DetermineAlertResponse(AlertType, Severity);

    // Execute automated response
    case ResponseAction of
        'SCALE_UP':
            ResponseResult := ExecuteScaleUp();
        'RESTART_SERVICES':
            ResponseResult := ExecuteServiceRestart();
        'FAILOVER':
            ResponseResult := ExecuteFailover();
        'NOTIFY_ADMIN':
            ResponseResult := NotifyAdministrator(AlertType, Details);
        else
            ResponseResult := false;
    end;

    // Log response
    LogAlertResponse(AlertId, ResponseAction, ResponseResult);

    // Escalate if automated response failed
    if not ResponseResult and (Severity = 'CRITICAL') then
        EscalateAlert(AlertId, AlertType, Details);
end;
```

---

**API Integration Guide Version**: 1.0
**Last Updated**: January 2025
**Next Review**: March 2025

*This API integration guide provides comprehensive examples and procedures for integrating with the MyInvois LHDN e-Invoice system. Use the testing procedures to validate your integrations before going live.*