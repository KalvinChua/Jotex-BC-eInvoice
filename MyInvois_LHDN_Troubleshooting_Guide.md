# MyInvois LHDN e-Invoice System - Troubleshooting Guide

## Overview

This comprehensive troubleshooting guide helps you identify, diagnose, and resolve common issues with the MyInvois LHDN e-Invoice system. Whether you're a user, administrator, or developer, this guide provides systematic approaches to problem resolution.

---

## Table of Contents

1. [Quick Issue Resolution](#quick-issue-resolution)
2. [System Health Checks](#system-health-checks)
3. [Submission Issues](#submission-issues)
4. [Configuration Problems](#configuration-problems)
5. [Performance Issues](#performance-issues)
6. [Security and Certificate Issues](#security-and-certificate-issues)
7. [Data and Validation Issues](#data-and-validation-issues)
8. [Integration Issues](#integration-issues)
9. [Monitoring and Alerting](#monitoring-and-alerting)
10. [Advanced Diagnostics](#advanced-diagnostics)

---

## Quick Issue Resolution

### Issue Symptom Quick Reference

| Symptom | Possible Cause | Quick Fix | Reference |
|---------|----------------|-----------|-----------|
| "Sign & Submit" button missing | Permissions or setup | Check user permissions | [Section 3.1](#submission-issues) |
| Submission fails immediately | Configuration error | Verify setup card | [Section 4.1](#configuration-problems) |
| "Invalid TIN" error | Customer data issue | Validate TIN format | [Section 7.2](#data-and-validation-issues) |
| Slow performance | System overload | Check system resources | [Section 5.1](#performance-issues) |
| Certificate errors | Expired or invalid cert | Renew certificate | [Section 6.1](#security-and-certificate-issues) |

### Emergency Response Checklist

#### For Critical Production Issues
1. **Assess Impact**: Determine affected users and business processes
2. **Stop Processing**: Disable auto-submission if needed
3. **Gather Information**: Collect error logs and system state
4. **Escalate if Needed**: Contact appropriate support tier
5. **Implement Workaround**: Use manual processing if available
6. **Document Resolution**: Record solution for future reference

---

## System Health Checks

### Automated Health Check

#### Run System Health Assessment
```al
// Execute comprehensive system health check
procedure RunSystemHealthCheck(): Text
var
    HealthStatus: Text;
    Setup: Record "eInvoiceSetup";
    HttpClient: HttpClient;
    HttpResponseMessage: HttpResponseMessage;
begin
    HealthStatus := '=== MyInvois LHDN System Health Check ===\' +
                   'Timestamp: ' + Format(CurrentDateTime) + '\\';

    // Check 1: Extension Installation
    HealthStatus += CheckExtensionInstallation() + '\\';

    // Check 2: Configuration Completeness
    HealthStatus += CheckConfigurationCompleteness() + '\\';

    // Check 3: Azure Function Connectivity
    HealthStatus += CheckAzureFunctionConnectivity() + '\\';

    // Check 4: LHDN API Connectivity
    HealthStatus += CheckLhdnApiConnectivity() + '\\';

    // Check 5: Certificate Validity
    HealthStatus += CheckCertificateValidity() + '\\';

    // Check 6: Database Performance
    HealthStatus += CheckDatabasePerformance() + '\\';

    // Check 7: Recent Error Analysis
    HealthStatus += AnalyzeRecentErrors() + '\\';

    exit(HealthStatus);
end;
```

#### Health Check Components

##### 1. Extension Installation Check
```al
local procedure CheckExtensionInstallation(): Text
var
    NAVApp: Record "NAV App";
begin
    NAVApp.SetRange(Name, 'MyInvoisLHDN');
    if NAVApp.FindFirst() then
        exit('✅ Extension installed: Version ' + NAVApp."Version")
    else
        exit('❌ Extension not found - reinstall required');
end;
```

##### 2. Configuration Completeness Check
```al
local procedure CheckConfigurationCompleteness(): Text
var
    Setup: Record "eInvoiceSetup";
    MissingFields: List of [Text];
begin
    if not Setup.Get() then
        exit('❌ eInvoice Setup not configured');

    // Check required fields
    if Setup."Azure Function URL" = '' then
        MissingFields.Add('Azure Function URL');

    if Setup."LHDN API URL" = '' then
        MissingFields.Add('LHDN API URL');

    if Setup."Client ID" = '' then
        MissingFields.Add('Client ID');

    if MissingFields.Count > 0 then
        exit('❌ Missing configuration: ' + MissingFields.Get(1))
    else
        exit('✅ Configuration complete');
end;
```

##### 3. Connectivity Tests
```al
local procedure CheckAzureFunctionConnectivity(): Text
var
    HttpClient: HttpClient;
    HttpResponseMessage: HttpResponseMessage;
    Setup: Record "eInvoiceSetup";
begin
    Setup.Get();

    HttpClient.Get(Setup."Azure Function URL" + '/api/health', HttpResponseMessage);

    if HttpResponseMessage.IsSuccessStatusCode then
        exit('✅ Azure Function accessible')
    else
        exit('❌ Azure Function not accessible: ' + Format(HttpResponseMessage.HttpStatusCode));
end;
```

### Manual Health Check Procedures

#### Daily Health Check Routine
1. **Check System Status Dashboard**
2. **Review Recent Submissions** (last 24 hours)
3. **Monitor Error Logs** for new patterns
4. **Verify Certificate Expiry** dates
5. **Test Sample Submission** if possible

#### Weekly Health Check Routine
1. **Performance Metrics Review**
2. **Storage and Resource Usage**
3. **Backup Verification**
4. **Security Scan Results**
5. **User Feedback Analysis**

---

## Submission Issues

### Issue: "Sign & Submit" Action Not Available

#### Symptoms
- Button missing from posted document actions
- Action appears grayed out
- Error: "Action not available for this document"

#### Root Causes
1. **Document Type Not Supported**
2. **Customer Not e-Invoice Enabled**
3. **Missing Required Fields**
4. **User Permissions Insufficient**
5. **Document Already Submitted**

#### Diagnostic Steps
```al
// Debug document submission eligibility
procedure DebugDocumentEligibility(DocumentNo: Code[20]): Text
var
    SalesInvoiceHeader: Record "Sales Invoice Header";
    Customer: Record Customer;
    DebugInfo: Text;
begin
    if not SalesInvoiceHeader.Get(DocumentNo) then
        exit('Document not found');

    DebugInfo := 'Document: ' + DocumentNo + '\\';

    // Check customer
    if Customer.Get(SalesInvoiceHeader."Sell-to Customer No.") then begin
        DebugInfo += 'Customer: ' + Customer.Name + '\\';
        DebugInfo += 'e-Invoice Enabled: ' + Format(Customer."Requires e-Invoice") + '\\';
        DebugInfo += 'TIN: ' + Customer."e-Invoice TIN No." + '\\';
    end;

    // Check document status
    DebugInfo += 'Status: ' + SalesInvoiceHeader."eInvoice Validation Status" + '\\';

    // Check required fields
    DebugInfo += 'Document Type: ' + SalesInvoiceHeader."eInvoice Document Type" + '\\';
    DebugInfo += 'Currency: ' + SalesInvoiceHeader."eInvoice Currency Code" + '\\';

    exit(DebugInfo);
end;
```

#### Resolution Steps
1. **Verify Customer Setup**
   - Open customer card
   - Check "Requires e-Invoice" flag
   - Validate TIN and address information

2. **Check Document Status**
   - Review "eInvoice Validation Status"
   - Check submission history if previously submitted

3. **Validate User Permissions**
   - Confirm user has e-Invoice permissions
   - Check role assignments

4. **Complete Missing Fields**
   - Ensure all required e-Invoice fields are populated
   - Run field validation procedure

### Issue: Submission Fails with "Invalid Structured Submission"

#### Symptoms
- Submission rejected by LHDN
- Error: "Invalid structured submission"
- JSON validation errors

#### Root Causes
1. **Missing UBL Namespaces**
2. **Incorrect Document Structure**
3. **Invalid Field Values**
4. **Schema Version Mismatch**

#### Diagnostic Steps
```al
// Validate UBL JSON structure
procedure ValidateUblJsonStructure(JsonText: Text): Text
var
    JsonObject: JsonObject;
    ValidationErrors: List of [Text];
begin
    if not JsonObject.ReadFrom(JsonText) then begin
        ValidationErrors.Add('Invalid JSON format');
        exit(GetValidationSummary(ValidationErrors));
    end;

    // Check UBL namespaces
    if not ValidateUblNamespaces(JsonObject) then
        ValidationErrors.Add('Missing or invalid UBL namespaces');

    // Check document structure
    if not ValidateDocumentStructure(JsonObject) then
        ValidationErrors.Add('Invalid document structure');

    // Check required fields
    if not ValidateRequiredFields(JsonObject) then
        ValidationErrors.Add('Missing required fields');

    exit(GetValidationSummary(ValidationErrors));
end;
```

#### Resolution Steps
1. **Verify UBL Namespaces**
   ```json
   // Required namespaces in JSON
   {
     "_D": "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2",
     "_A": "urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2",
     "_B": "urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2"
   }
   ```

2. **Check Document Type Codes**
   - Invoice: "01"
   - Credit Note: "02"
   - Debit Note: "03"
   - Refund Note: "04"

3. **Validate Field Formats**
   - Dates: ISO 8601 format (YYYY-MM-DD)
   - Amounts: Decimal with 2 places
   - TIN: 12 digits for companies

4. **Update to Latest Version**
   - Ensure using UBL 2.1 v1.1
   - Check for extension updates

### Issue: Azure Function Communication Failure

#### Symptoms
- Timeout errors
- Connection refused
- HTTP 500 errors from Azure Function

#### Root Causes
1. **Network Connectivity Issues**
2. **Azure Function Down**
3. **Authentication Problems**
4. **Certificate Issues**

#### Diagnostic Steps
```al
// Test Azure Function connectivity
procedure TestAzureFunctionConnection(): Text
var
    HttpClient: HttpClient;
    HttpRequestMessage: HttpRequestMessage;
    HttpResponseMessage: HttpResponseMessage;
    Setup: Record "eInvoiceSetup";
    TestPayload: Text;
begin
    Setup.Get();

    // Create test request
    TestPayload := '{"test": "connection"}';

    HttpRequestMessage.SetRequestUri(Setup."Azure Function URL" + '/api/test');
    HttpRequestMessage.Method('POST');
    HttpRequestMessage.Content.WriteFrom(TestPayload);

    // Add headers
    HttpRequestMessage.GetHeaders().Add('Content-Type', 'application/json');

    // Send request
    if HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then begin
        if HttpResponseMessage.IsSuccessStatusCode then
            exit('✅ Azure Function responding')
        else
            exit('❌ Azure Function error: ' + Format(HttpResponseMessage.HttpStatusCode));
    end else
        exit('❌ Connection failed');
end;
```

#### Resolution Steps
1. **Check Azure Function Status**
   - Access Azure Portal
   - Check Function App status
   - Review Application Insights

2. **Verify Network Connectivity**
   - Test from Business Central server
   - Check firewall rules
   - Verify DNS resolution

3. **Validate Authentication**
   - Check API keys
   - Verify certificate validity
   - Review Azure Function logs

4. **Scale Azure Function**
   - Increase instance count
   - Check resource usage
   - Review performance metrics

---

## Configuration Problems

### Issue: Extension Not Properly Configured

#### Symptoms
- Setup card shows errors
- Fields not populating automatically
- Integration not working

#### Configuration Validation Script
```al
// Comprehensive configuration validator
procedure ValidateSystemConfiguration(): Text
var
    Setup: Record "eInvoiceSetup";
    ValidationResults: Text;
    ErrorCount: Integer;
begin
    ValidationResults := 'Configuration Validation Results:\\';

    if not Setup.Get() then begin
        ValidationResults += '❌ eInvoice Setup record not found\\';
        exit(ValidationResults);
    end;

    // Validate Azure Function URL
    if Setup."Azure Function URL" = '' then begin
        ValidationResults += '❌ Azure Function URL not configured\\';
        ErrorCount += 1;
    end else
        ValidationResults += '✅ Azure Function URL configured\\';

    // Validate LHDN API settings
    if Setup."LHDN API URL" = '' then begin
        ValidationResults += '❌ LHDN API URL not configured\\';
        ErrorCount += 1;
    end else
        ValidationResults += '✅ LHDN API URL configured\\';

    // Validate environment settings
    if Setup.Environment = Setup.Environment::" " then begin
        ValidationResults += '❌ Environment not selected\\';
        ErrorCount += 1;
    end else
        ValidationResults += '✅ Environment configured: ' + Format(Setup.Environment) + '\\';

    // Validate API credentials
    if Setup."Client ID" = '' then begin
        ValidationResults += '❌ Client ID not configured\\';
        ErrorCount += 1;
    end else
        ValidationResults += '✅ Client ID configured\\';

    ValidationResults += '\\Total Errors: ' + Format(ErrorCount);

    exit(ValidationResults);
end;
```

### Issue: Master Data Incomplete

#### Symptoms
- State codes missing
- Country codes not configured
- MSIC codes incomplete

#### Master Data Validation
```al
// Validate master data completeness
procedure ValidateMasterData(): Text
var
    StateCodes: Record "State Codes";
    CountryCodes: Record "Country Codes";
    MSICCodes: Record "MSIC Codes";
    ValidationResults: Text;
begin
    ValidationResults := 'Master Data Validation:\\';

    // Check state codes
    if StateCodes.IsEmpty then
        ValidationResults += '❌ No state codes configured\\'
    else
        ValidationResults += '✅ State codes: ' + Format(StateCodes.Count) + ' records\\';

    // Check country codes
    if CountryCodes.IsEmpty then
        ValidationResults += '❌ No country codes configured\\'
    else
        ValidationResults += '✅ Country codes: ' + Format(CountryCodes.Count) + ' records\\';

    // Check MSIC codes
    if MSICCodes.IsEmpty then
        ValidationResults += '❌ No MSIC codes configured\\'
    else
        ValidationResults += '✅ MSIC codes: ' + Format(MSICCodes.Count) + ' records\\';

    exit(ValidationResults);
end;
```

---

## Performance Issues

### Issue: Slow Document Processing

#### Symptoms
- Long processing times
- System responsiveness issues
- Timeout errors

#### Performance Analysis
```al
// Performance monitoring procedure
procedure AnalyzeSystemPerformance(): Text
var
    StartTime: DateTime;
    EndTime: DateTime;
    ProcessingTime: Duration;
    PerformanceReport: Text;
begin
    StartTime := CurrentDateTime;
    PerformanceReport := 'Performance Analysis Report\\';
    PerformanceReport += 'Start Time: ' + Format(StartTime) + '\\';

    // Test JSON generation performance
    EndTime := CurrentDateTime;
    ProcessingTime := EndTime - StartTime;
    PerformanceReport += 'JSON Generation: ' + Format(ProcessingTime) + '\\';

    // Test Azure Function performance
    StartTime := CurrentDateTime;
    // ... Azure Function call ...
    EndTime := CurrentDateTime;
    ProcessingTime := EndTime - StartTime;
    PerformanceReport += 'Azure Function: ' + Format(ProcessingTime) + '\\';

    // Test LHDN API performance
    StartTime := CurrentDateTime;
    // ... LHDN API call ...
    EndTime := CurrentDateTime;
    ProcessingTime := EndTime - StartTime;
    PerformanceReport += 'LHDN API: ' + Format(ProcessingTime) + '\\';

    exit(PerformanceReport);
end;
```

#### Performance Optimization Steps
1. **Database Optimization**
   - Update statistics
   - Rebuild indexes
   - Check for blocking queries

2. **Azure Function Scaling**
   - Increase instance count
   - Configure auto-scaling
   - Optimize function code

3. **Caching Implementation**
   - Cache frequently used data
   - Implement connection pooling
   - Use CDN for static resources

4. **Batch Processing**
   - Process multiple documents together
   - Implement queuing mechanism
   - Use background processing

### Issue: High Memory Usage

#### Symptoms
- System running out of memory
- Performance degradation
- Application crashes

#### Memory Analysis
```al
// Memory usage monitoring
procedure MonitorMemoryUsage(): Text
var
    Session: Record "Active Session";
    MemoryReport: Text;
    TotalMemory: Integer;
begin
    MemoryReport := 'Memory Usage Report:\\';

    Session.SetRange("Client Type", Session."Client Type"::"Web Client");
    if Session.FindSet() then begin
        repeat
            MemoryReport += 'Session ' + Format(Session."Session ID") + ': ' +
                           Format(Session."Memory Usage") + ' KB\\';
            TotalMemory += Session."Memory Usage";
        until Session.Next() = 0;
    end;

    MemoryReport += '\\Total Memory Usage: ' + Format(TotalMemory) + ' KB\\';

    // Check for memory thresholds
    if TotalMemory > 1000000 then // 1GB
        MemoryReport += '⚠️ High memory usage detected\\';

    exit(MemoryReport);
end;
```

---

## Security and Certificate Issues

### Issue: Certificate Expired or Invalid

#### Symptoms
- Signing failures
- Authentication errors
- "Certificate not valid" messages

#### Certificate Validation
```al
// Certificate health check
procedure ValidateCertificateHealth(): Text
var
    CertificateReport: Text;
    CertificateExpiry: Date;
    DaysUntilExpiry: Integer;
begin
    CertificateReport := 'Certificate Validation Report:\\';

    // Check certificate expiry
    CertificateExpiry := GetCertificateExpiryDate();
    DaysUntilExpiry := CertificateExpiry - Today;

    if DaysUntilExpiry < 0 then
        CertificateReport += '❌ Certificate expired ' + Format(Abs(DaysUntilExpiry)) + ' days ago\\'
    else if DaysUntilExpiry < 30 then
        CertificateReport += '⚠️ Certificate expires in ' + Format(DaysUntilExpiry) + ' days\\'
    else
        CertificateReport += '✅ Certificate valid for ' + Format(DaysUntilExpiry) + ' days\\';

    // Check certificate format
    if not ValidateCertificateFormat() then
        CertificateReport += '❌ Invalid certificate format\\'
    else
        CertificateReport += '✅ Certificate format valid\\';

    exit(CertificateReport);
end;
```

#### Certificate Renewal Process
1. **Request New Certificate**
   - Contact certificate authority
   - Provide required documentation
   - Generate new certificate request

2. **Update Azure Function**
   - Upload new certificate to Key Vault
   - Update certificate references
   - Test signing functionality

3. **Update Business Central**
   - Update certificate password if changed
   - Test end-to-end process
   - Validate with LHDN

### Issue: Authentication Failures

#### Symptoms
- API authentication errors
- Access denied messages
- Token validation failures

#### Authentication Troubleshooting
```al
// Test authentication flow
procedure TestAuthenticationFlow(): Text
var
    HttpClient: HttpClient;
    HttpRequestMessage: HttpRequestMessage;
    HttpResponseMessage: HttpResponseMessage;
    AuthResult: Text;
begin
    AuthResult := 'Authentication Test Results:\\';

    // Test LHDN token generation
    if TestLhdnTokenGeneration() then
        AuthResult += '✅ LHDN token generation successful\\'
    else
        AuthResult += '❌ LHDN token generation failed\\';

    // Test Azure Function authentication
    if TestAzureFunctionAuth() then
        AuthResult += '✅ Azure Function authentication successful\\'
    else
        AuthResult += '❌ Azure Function authentication failed\\';

    // Test API permissions
    if TestApiPermissions() then
        AuthResult += '✅ API permissions valid\\'
    else
        AuthResult += '❌ API permissions invalid\\';

    exit(AuthResult);
end;
```

---

## Data and Validation Issues

### Issue: TIN Validation Failures

#### Symptoms
- TIN validation errors
- Customer TIN rejected
- "Invalid TIN format" messages

#### TIN Validation Troubleshooting
```al
// Comprehensive TIN validation
procedure ValidateTINComprehensive(TIN: Text): Text
var
    ValidationResult: Text;
    IsValidFormat: Boolean;
    IsValidChecksum: Boolean;
    LhdnValidation: Boolean;
begin
    ValidationResult := 'TIN Validation Results for: ' + TIN + '\\';

    // Check format
    IsValidFormat := ValidateTINFormat(TIN);
    if IsValidFormat then
        ValidationResult += '✅ Format validation passed\\'
    else
        ValidationResult += '❌ Invalid TIN format\\';

    // Check checksum
    IsValidChecksum := ValidateTINChecksum(TIN);
    if IsValidChecksum then
        ValidationResult += '✅ Checksum validation passed\\'
    else
        ValidationResult += '❌ Invalid TIN checksum\\';

    // Check with LHDN
    LhdnValidation := ValidateTINWithLhdn(TIN);
    if LhdnValidation then
        ValidationResult += '✅ LHDN validation passed\\'
    else
        ValidationResult += '❌ LHDN validation failed\\';

    exit(ValidationResult);
end;
```

#### Common TIN Issues
1. **Format Errors**
   - Wrong number of digits
   - Invalid characters
   - Leading zeros missing

2. **Checksum Errors**
   - Calculation mistakes
   - Data entry errors
   - System calculation bugs

3. **LHDN Validation Errors**
   - TIN not registered
   - TIN expired
   - Business type mismatch

### Issue: Address Validation Problems

#### Symptoms
- Address validation failures
- State code errors
- Country code issues

#### Address Validation
```al
// Address validation procedure
procedure ValidateCustomerAddress(CustomerNo: Code[20]): Text
var
    Customer: Record Customer;
    ValidationResult: Text;
begin
    if not Customer.Get(CustomerNo) then
        exit('Customer not found');

    ValidationResult := 'Address Validation for ' + Customer.Name + ':\\';

    // Check address completeness
    if Customer.Address = '' then
        ValidationResult += '❌ Address line 1 missing\\'
    else
        ValidationResult += '✅ Address line 1 present\\';

    if Customer.City = '' then
        ValidationResult += '❌ City missing\\'
    else
        ValidationResult += '✅ City present\\';

    // Check state code
    if Customer."State Code" = '' then
        ValidationResult += '❌ State code missing\\'
    else if not ValidateStateCode(Customer."State Code") then
        ValidationResult += '❌ Invalid state code\\'
    else
        ValidationResult += '✅ State code valid\\';

    // Check country code
    if Customer."Country/Region Code" <> 'MY' then
        ValidationResult += '❌ Country must be Malaysia (MY)\\'
    else
        ValidationResult += '✅ Country code valid\\';

    exit(ValidationResult);
end;
```

---

## Integration Issues

### Issue: LHDN API Connectivity Problems

#### Symptoms
- API timeout errors
- Connection refused
- HTTP error responses

#### API Connectivity Testing
```al
// Test LHDN API connectivity
procedure TestLhdnApiConnectivity(): Text
var
    HttpClient: HttpClient;
    HttpRequestMessage: HttpRequestMessage;
    HttpResponseMessage: HttpResponseMessage;
    Setup: Record "eInvoiceSetup";
    ConnectivityResult: Text;
begin
    Setup.Get();
    ConnectivityResult := 'LHDN API Connectivity Test:\\';

    // Test basic connectivity
    HttpRequestMessage.SetRequestUri(Setup."LHDN API URL" + '/health');
    HttpRequestMessage.Method('GET');

    if HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then begin
        if HttpResponseMessage.IsSuccessStatusCode then
            ConnectivityResult += '✅ Basic connectivity successful\\'
        else
            ConnectivityResult += '❌ API returned error: ' + Format(HttpResponseMessage.HttpStatusCode) + '\\';
    end else
        ConnectivityResult += '❌ Connection failed\\';

    // Test authentication
    if TestLhdnAuthentication() then
        ConnectivityResult += '✅ Authentication successful\\'
    else
        ConnectivityResult += '❌ Authentication failed\\';

    // Test document submission endpoint
    if TestSubmissionEndpoint() then
        ConnectivityResult += '✅ Submission endpoint accessible\\'
    else
        ConnectivityResult += '❌ Submission endpoint not accessible\\';

    exit(ConnectivityResult);
end;
```

### Issue: Azure Function Integration Problems

#### Symptoms
- Function invocation failures
- Payload format errors
- Response parsing issues

#### Azure Function Diagnostics
```al
// Azure Function integration test
procedure TestAzureFunctionIntegration(): Text
var
    IntegrationResult: Text;
    TestPayload: Text;
    Response: Text;
begin
    IntegrationResult := 'Azure Function Integration Test:\\';

    // Create test payload
    TestPayload := CreateTestPayload();

    // Test function invocation
    if InvokeAzureFunction(TestPayload, Response) then begin
        IntegrationResult += '✅ Function invocation successful\\';

        // Validate response
        if ValidateFunctionResponse(Response) then
            IntegrationResult += '✅ Response format valid\\'
        else
            IntegrationResult += '❌ Invalid response format\\';
    end else
        IntegrationResult += '❌ Function invocation failed\\';

    exit(IntegrationResult);
end;
```

---

## Monitoring and Alerting

### Setting Up System Monitoring

#### Key Metrics to Monitor
1. **Submission Success Rate**
2. **Average Processing Time**
3. **Error Rate by Category**
4. **System Resource Usage**
5. **Certificate Expiry Dates**

#### Alert Configuration
```al
// Configure monitoring alerts
procedure SetupMonitoringAlerts()
begin
    // Alert on submission failures
    SetupSubmissionFailureAlert();

    // Alert on performance degradation
    SetupPerformanceAlert();

    // Alert on certificate expiry
    SetupCertificateExpiryAlert();

    // Alert on system resource issues
    SetupResourceAlert();
end;
```

### Log Analysis Procedures

#### Analyzing Submission Logs
```al
// Analyze submission patterns
procedure AnalyzeSubmissionLogs(DateFrom: Date; DateTo: Date): Text
var
    SubmissionLog: Record "eInvoice Submission Log";
    AnalysisReport: Text;
    TotalSubmissions: Integer;
    SuccessfulSubmissions: Integer;
    FailedSubmissions: Integer;
begin
    AnalysisReport := 'Submission Log Analysis (' + Format(DateFrom) + ' to ' + Format(DateTo) + '):\\';

    SubmissionLog.SetRange("Submission Date", DateFrom, DateTo);

    if SubmissionLog.FindSet() then begin
        repeat
            TotalSubmissions += 1;
            if SubmissionLog.Status = 'Submitted' then
                SuccessfulSubmissions += 1
            else
                FailedSubmissions += 1;
        until SubmissionLog.Next() = 0;
    end;

    AnalysisReport += 'Total Submissions: ' + Format(TotalSubmissions) + '\\';
    AnalysisReport += 'Successful: ' + Format(SuccessfulSubmissions) + '\\';
    AnalysisReport += 'Failed: ' + Format(FailedSubmissions) + '\\';

    if TotalSubmissions > 0 then
        AnalysisReport += 'Success Rate: ' + Format((SuccessfulSubmissions / TotalSubmissions) * 100, 0, 2) + '%\\';

    exit(AnalysisReport);
end;
```

---

## Advanced Diagnostics

### Debug Tools and Procedures

#### Enable Debug Logging
```al
// Enable comprehensive debug logging
procedure EnableDebugLogging()
var
    Setup: Record "eInvoiceSetup";
begin
    Setup.Get();
    Setup."Enable Debug Logging" := true;
    Setup."Log Level" := 'Debug';
    Setup."Log Retention Days" := 30;
    Setup.Modify();

    Message('Debug logging enabled. Check logs at: C:\\Logs\\eInvoice\\');
end;
```

#### System Dump Collection
```al
// Collect system diagnostic information
procedure CollectSystemDump(): Text
var
    SystemInfo: Text;
    SessionInfo: Record "Active Session";
    CompanyInfo: Record "Company Information";
begin
    SystemInfo := '=== System Diagnostic Dump ===\\';
    SystemInfo += 'Timestamp: ' + Format(CurrentDateTime) + '\\';

    // Company information
    if CompanyInfo.Get() then begin
        SystemInfo += 'Company: ' + CompanyInfo.Name + '\\';
        SystemInfo += 'Business Central Version: ' + CompanyInfo."Business Central Version" + '\\';
    end;

    // Session information
    SessionInfo.SetRange("Client Type", SessionInfo."Client Type"::"Web Client");
    SystemInfo += 'Active Sessions: ' + Format(SessionInfo.Count) + '\\';

    // Extension information
    SystemInfo += GetExtensionInfo() + '\\';

    // Configuration summary
    SystemInfo += GetConfigurationSummary() + '\\';

    exit(SystemInfo);
end;
```

### Performance Profiling

#### Code Performance Analysis
```al
// Profile code execution performance
procedure ProfileCodeExecution(ProcedureName: Text; Iterations: Integer): Text
var
    StartTime: DateTime;
    EndTime: DateTime;
    TotalTime: Duration;
    AverageTime: Duration;
    PerformanceReport: Text;
    i: Integer;
begin
    PerformanceReport := 'Performance Profile for ' + ProcedureName + ':\\';

    for i := 1 to Iterations do begin
        StartTime := CurrentDateTime;

        // Execute the procedure to profile
        case ProcedureName of
            'GenerateEInvoiceJson':
                ProfileGenerateJson();
            'SubmitToLhdn':
                ProfileSubmitToLhdn();
            // Add other procedures as needed
        end;

        EndTime := CurrentDateTime;
        TotalTime += EndTime - StartTime;
    end;

    AverageTime := TotalTime / Iterations;

    PerformanceReport += 'Iterations: ' + Format(Iterations) + '\\';
    PerformanceReport += 'Total Time: ' + Format(TotalTime) + '\\';
    PerformanceReport += 'Average Time: ' + Format(AverageTime) + '\\';

    exit(PerformanceReport);
end;
```

### Database Analysis

#### Query Performance Analysis
```sql
-- Identify slow queries
SELECT
    query_text,
    execution_count,
    total_worker_time / execution_count AS avg_worker_time,
    total_elapsed_time / execution_count AS avg_elapsed_time
FROM sys.dm_exec_query_stats
CROSS APPLY sys.dm_exec_sql_text(sql_handle)
WHERE query_text LIKE '%eInvoice%'
ORDER BY avg_worker_time DESC;
```

#### Index Optimization
```sql
-- Check for missing indexes
SELECT
    TableName = OBJECT_NAME(s.object_id),
    IndexName = i.name,
    ColumnName = c.name,
    s.user_seeks,
    s.user_scans,
    s.user_lookups
FROM sys.dm_db_index_usage_stats s
INNER JOIN sys.indexes i ON s.object_id = i.object_id AND s.index_id = i.index_id
INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE s.database_id = DB_ID()
AND OBJECT_NAME(s.object_id) LIKE '%eInvoice%'
ORDER BY s.user_seeks + s.user_scans + s.user_lookups DESC;
```

---

## Emergency Procedures

### Critical System Failure Response

#### Immediate Actions
1. **Assess Situation**: Determine scope and impact
2. **Stop Processing**: Disable e-Invoice processing
3. **Activate Backup**: Switch to manual processing
4. **Notify Stakeholders**: Alert management and users
5. **Escalate**: Contact emergency support

#### Recovery Steps
1. **Diagnose Root Cause**: Use diagnostic tools
2. **Implement Fix**: Apply appropriate solution
3. **Test Recovery**: Validate fix in test environment
4. **Gradual Rollout**: Resume processing gradually
5. **Monitor Closely**: Watch for recurrence

### Data Recovery Procedures

#### Log Recovery
```al
// Recover from log files
procedure RecoverFromLogs(DateToRecover: Date): Text
var
    SubmissionLog: Record "eInvoice Submission Log";
    RecoveryReport: Text;
    RecoveredCount: Integer;
begin
    RecoveryReport := 'Data Recovery Report for ' + Format(DateToRecover) + ':\\';

    SubmissionLog.SetRange("Submission Date", DateToRecover);
    if SubmissionLog.FindSet() then begin
        repeat
            // Attempt to recover submission
            if RecoverSubmission(SubmissionLog) then
                RecoveredCount += 1;
        until SubmissionLog.Next() = 0;
    end;

    RecoveryReport += 'Records processed: ' + Format(SubmissionLog.Count) + '\\';
    RecoveryReport += 'Records recovered: ' + Format(RecoveredCount) + '\\';

    exit(RecoveryReport);
end;
```

---

## Support Resources

### Internal Support
- **Help Desk**: Primary contact for user issues
- **System Administrators**: Configuration and setup issues
- **Development Team**: Code and integration issues

### External Support
- **LHDN Support**: API and compliance issues
- **Microsoft Support**: Business Central platform issues
- **Azure Support**: Cloud infrastructure issues

### Documentation Resources
- **User Guide**: `MyInvois_LHDN_User_Guide.md`
- **Developer Guide**: `MyInvois_LHDN_Developer_Guide.md`
- **Installation Guide**: `MyInvois_LHDN_Installation_Guide.md`
- **System Documentation**: `MyInvois_LHDN_eInvoice_System_Documentation.md`

---

**Troubleshooting Guide Version**: 1.0
**Last Updated**: January 2025
**Next Review**: March 2025

*This troubleshooting guide is designed to help resolve common issues efficiently. For persistent problems, contact your system administrator or IT support team.*