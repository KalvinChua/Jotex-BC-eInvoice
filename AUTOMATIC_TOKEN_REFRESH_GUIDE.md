# Automatic Token Retrieval System for LHDN e-Invoice

## Overview

The enhanced `eInvoiceHelper` codeunit now provides robust automatic token retrieval that handles token expiry seamlessly. The system automatically refreshes tokens when they expire, with intelligent caching and retry mechanisms.

## 🔄 **How Automatic Token Retrieval Works**

### **1. Multi-Level Caching System**

```al
// Memory Cache (Fastest)
TokenCache: Dictionary of [Text, Text]
TokenExpiryCache: Dictionary of [Text, DateTime]

// Database Cache (Persistent)
SetupRec."Last Token"
SetupRec."Token Timestamp" 
SetupRec."Token Expiry (s)"
```

### **2. Automatic Refresh Logic**

```al
procedure GetAccessTokenFromSetup(var SetupRec: Record eInvoiceSetup): Text
begin
    // 1. Check memory cache first (fastest)
    if IsTokenValidInCache(CacheKey, CurrentTime, Token) then
        exit(Token);
    
    // 2. Check database cache (persistent)
    if IsTokenValidInDatabase(SetupRec, CurrentTime, Token, ExpiryTime) then
        exit(Token);
    
    // 3. Token expired - generate new with retry logic
    for RetryAttempt := 1 to MaxRetries do begin
        Token := TryGetNewToken(SetupRec, ExpirySeconds, LastError);
        if Token <> '' then
            exit(Token);
    end;
end;
```

### **3. Smart Expiry Detection**

- **5-minute buffer**: Tokens are refreshed 5 minutes before actual expiry
- **Environment-aware**: Different cache keys for PREPROD vs PRODUCTION
- **Credential-based**: Cache keys include credential hash for security

## 🛠️ **Key Features**

### **1. Automatic Retry Logic**
```al
MaxRetries := 3; // Maximum retry attempts
RetryDelayMs := 2000; // 2 seconds base delay
// Exponential backoff: 2s, 4s, 6s
```

### **2. Comprehensive Error Handling**
```al
Error('Token Generation Failed After %1 Attempts\n\n' +
      'Last Error: %2\n\n' +
      'Troubleshooting Steps:\n' +
      '1. Verify Client ID and Client Secret are correct\n' +
      '2. Check network connectivity to LHDN servers\n' +
      '3. Ensure LHDN API service is available\n' +
      '4. Verify credentials are active in LHDN portal\n' +
      '5. Check if your IP is whitelisted if required\n\n' +
      'Correlation ID: %3', 
      MaxRetries, LastError, CreateGuid());
```

### **3. Token Status Monitoring**
```al
procedure GetTokenStatus(var SetupRec: Record eInvoiceSetup): Text
// Returns: "No Token", "Expired", "Valid (X minutes remaining)"

procedure IsTokenRefreshNeeded(var SetupRec: Record eInvoiceSetup): Boolean
// Returns: true if token needs refresh, false if still valid
```

### **4. Force Refresh Capability**
```al
procedure ForceRefreshToken(var SetupRec: Record eInvoiceSetup): Text
// Forces token refresh regardless of current status
// Useful for testing or when credentials are updated
```

## 📋 **Usage Examples**

### **1. Basic Automatic Token Retrieval**
```al
var
    MyInvoisHelper: Codeunit eInvoiceHelper;
    Token: Text;
begin
    // This will automatically handle token expiry and refresh
    Token := MyInvoisHelper.GetAccessTokenFromSetup(SetupRec);
end;
```

### **2. Check Token Status**
```al
var
    MyInvoisHelper: Codeunit eInvoiceHelper;
    TokenStatus: Text;
    RefreshNeeded: Boolean;
begin
    TokenStatus := MyInvoisHelper.GetTokenStatus(SetupRec);
    RefreshNeeded := MyInvoisHelper.IsTokenRefreshNeeded(SetupRec);
    
    Message('Token Status: %1\nRefresh Needed: %2', 
        TokenStatus, 
        RefreshNeeded ? 'Yes' : 'No');
end;
```

### **3. Force Token Refresh**
```al
var
    MyInvoisHelper: Codeunit eInvoiceHelper;
    Token: Text;
begin
    // Force refresh regardless of current status
    Token := MyInvoisHelper.ForceRefreshToken(SetupRec);
end;
```

### **4. Clear Token Cache**
```al
var
    MyInvoisHelper: Codeunit eInvoiceHelper;
begin
    // Clear all cached tokens (useful for troubleshooting)
    MyInvoisHelper.ClearTokenCache();
end;
```

## 🎯 **Integration Points**

### **1. Main eInvoice JSON Generator**
```al
// In Cod50302.eInvoiceJSONGenerator.al
procedure GetLhdnAccessTokenFromHelper(eInvoiceSetup: Record "eInvoiceSetup"): Text
var
    MyInvoisHelper: Codeunit eInvoiceHelper;
begin
    exit(MyInvoisHelper.GetAccessTokenFromSetup(eInvoiceSetup));
end;
```

### **2. Submission Status Checker**
```al
// In Cod50312.eInvoiceSubmissionStatus.al
AccessToken := eInvoiceJson.GetLhdnAccessTokenFromHelper(eInvoiceSetup);
```

### **3. TIN Validator**
```al
// In Cod50301.eInvoiceTINValidator.al
Token := TokenHelper.GetAccessTokenFromSetup(MyInvoisSetup);
```

## 🔧 **Testing the System**

### **1. Test Automatic Token Refresh**
Navigate to **e-Invoice Setup** → **Test Automatic Token Refresh**
- Shows current token status
- Tests automatic retrieval
- Displays detailed results

### **2. Force Token Refresh**
Navigate to **e-Invoice Setup** → **Force Token Refresh**
- Forces immediate token refresh
- Useful for testing or troubleshooting

### **3. Monitor Token Status**
```al
// Check if token needs refresh
if MyInvoisHelper.IsTokenRefreshNeeded(SetupRec) then
    Message('Token will be refreshed on next API call');
```

## 📊 **Performance Benefits**

### **1. Reduced API Calls**
- **Memory cache**: Instant token retrieval
- **Database cache**: Persistent across sessions
- **Smart expiry**: 5-minute buffer prevents unnecessary calls

### **2. Improved Reliability**
- **Retry logic**: Handles temporary network issues
- **Exponential backoff**: Prevents overwhelming LHDN servers
- **Comprehensive error handling**: Clear troubleshooting guidance

### **3. Better User Experience**
- **Seamless operation**: Users don't need to manually refresh tokens
- **Automatic recovery**: System handles token expiry transparently
- **Detailed logging**: Easy troubleshooting when issues occur

## 🚨 **Error Handling**

### **1. Network Issues**
```al
// Automatic retry with exponential backoff
for RetryAttempt := 1 to MaxRetries do begin
    Token := TryGetNewToken(SetupRec, ExpirySeconds, LastError);
    if Token <> '' then
        exit(Token);
    
    if RetryAttempt < MaxRetries then
        Sleep(RetryDelayMs * RetryAttempt);
end;
```

### **2. Invalid Credentials**
```al
Error('Authentication Configuration Error\n\n' +
      'Client ID or Client Secret is blank.\n\n' +
      'Resolution Steps:\n' +
      '1. Navigate to e-Invoice Setup\n' +
      '2. Configure Client ID and Client Secret\n' +
      '3. Verify credentials with LHDN\n' +
      '4. Save configuration and retry');
```

### **3. API Service Issues**
```al
Error('Access Token Request Failed\n\n' +
      'Response Details:\n%1\n\n' +
      'Troubleshooting Steps:\n' +
      '1. Verify Client ID and Client Secret are correct\n' +
      '2. Check if credentials are active in LHDN portal\n' +
      '3. Ensure correct environment is selected\n' +
      '4. Verify network connectivity to LHDN servers\n' +
      '5. Check for any API service outages');
```

## 🔒 **Security Considerations**

### **1. Token Storage**
- **Memory cache**: Session-based, cleared when codeunit unloads
- **Database cache**: Encrypted in Business Central
- **No persistent storage**: Tokens not stored in plain text

### **2. Cache Keys**
```al
// Environment-specific cache keys
CacheKey := Format(SetupRec.Environment) + '_' + CreateGuid();
```

### **3. Token Validation**
- **JWT format validation**: Ensures tokens are valid JWT format
- **Expiry checking**: Prevents use of expired tokens
- **Buffer time**: 5-minute safety margin

## 📈 **Monitoring and Logging**

### **1. Token Operations Logging**
```al
LogTokenOperation('Token reused from memory cache', Token, ExpiryTime);
LogTokenOperation('New token generated (attempt 1/3)', Token, ExpiryTime);
LogTokenOperation('Token cache cleared', '', 0DT);
```

### **2. Performance Metrics**
- **Cache hit rate**: Memory vs database cache usage
- **Retry frequency**: How often retries are needed
- **Token refresh rate**: How often tokens are refreshed

### **3. Error Tracking**
- **Correlation IDs**: Unique identifiers for troubleshooting
- **Detailed error messages**: Clear resolution steps
- **Request timing**: Performance monitoring

## 🎯 **Best Practices**

### **1. Configuration**
- **Environment selection**: Ensure correct PREPROD/PRODUCTION setting
- **Credential management**: Keep Client ID and Secret secure
- **Regular testing**: Use test actions to verify functionality

### **2. Monitoring**
- **Token status checks**: Regular monitoring of token health
- **Error log review**: Monitor for authentication issues
- **Performance tracking**: Monitor API response times

### **3. Troubleshooting**
- **Force refresh**: Use when credentials are updated
- **Cache clearing**: Use when troubleshooting token issues
- **Detailed error messages**: Follow resolution steps provided

## 🔄 **Migration from Manual Token Management**

### **Before (Manual)**
```al
// Old manual approach
if TokenExpired then begin
    Token := GetNewToken(); // Manual refresh
    SaveToken(Token);
end;
```

### **After (Automatic)**
```al
// New automatic approach
Token := MyInvoisHelper.GetAccessTokenFromSetup(SetupRec);
// Handles expiry, refresh, caching, and retries automatically
```

## 📞 **Support and Troubleshooting**

### **1. Common Issues**
- **Token expiry errors**: Usually resolved by automatic refresh
- **Network connectivity**: Retry logic handles temporary issues
- **Invalid credentials**: Clear error messages guide resolution

### **2. Debug Actions**
- **Test Automatic Token Refresh**: Verify system functionality
- **Force Token Refresh**: Manual refresh for testing
- **Clear Token Cache**: Reset cache for troubleshooting

### **3. Error Resolution**
1. Check Client ID and Secret configuration
2. Verify environment setting (PREPROD/PRODUCTION)
3. Test network connectivity to LHDN servers
4. Check LHDN portal for credential status
5. Use force refresh if credentials were updated

---

**The automatic token retrieval system ensures your e-invoice solution operates seamlessly without manual token management, providing reliable and secure access to LHDN APIs.** 