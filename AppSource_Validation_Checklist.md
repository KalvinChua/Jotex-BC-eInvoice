# AppSource Validation Checklist for MyInvois LHDN e-Invoice Extension

## ✅ COMPLETED REQUIREMENTS

### 1. Development Environment
- [x] Extension developed in Visual Studio Code with AL Language extension
- [x] AL project structure properly organized

### 2. App.json Configuration
- [x] All mandatory properties included (name, publisher, version)
- [x] Dependencies properly specified
- [x] ID ranges registered (50300-50399)
- [x] Application manifest property specified (26.0.0.0)
- [x] Privacy statement, EULA, help, URL, and logo URLs provided
- [x] Supported countries specified (MY - Malaysia)
- [x] Application Insights connection string placeholder added

### 3. Permission Sets
- [x] Permission set created (50300 "eInvoice Full Access")
- [x] All setup and usage abilities included
- [x] No SUPER permissions required for setup and usage
- [x] Complete table, page, codeunit, and report permissions

### 4. Data Classification
- [x] All table fields have DataClassification property set
- [x] No fields use "ToBeClassified" value
- [x] Appropriate classifications used (CustomerContent, SystemMetadata)

### 5. Translation Files
- [x] Translation file created (en-US/MyInvoisLHDN.g.xlf)
- [x] All major objects included in translations

## 🔧 STILL NEEDS ATTENTION

### 1. Digital Signing
- [ ] .app file must be digitally signed before submission
- [ ] Use proper code signing certificate

### 2. Testing Requirements
- [ ] Test publish/sync/install/uninstall/reinstall in BC environment
- [ ] Thorough testing in Business Central environment
- [ ] Automated testing with AL Test Toolkit (recommended)

### 3. Upgrade Code
- [ ] Ensure upgrade codeunits handle version-to-version upgrades
- [ ] Test upgrade scenarios

### 4. Web Services
- [ ] Verify no UI generation in web service exposed codeunits
- [ ] Test web service functionality

### 5. Application Areas
- [ ] Verify all controls have appropriate application areas set
- [ ] Test control visibility in different application areas

## 📋 VALIDATION STEPS TO RUN

### Self-Validation Command
```powershell
$validationResults = Run-AlValidation `
    -validateCurrent `
    -apps @("path/to/your/app.app") `
    -countries @("MY") `
    -affixes @("KMAX") `
    -supportedCountries @("MY")
```

### Pre-Submission Checklist
1. **Compile Extension**: Ensure no compilation errors
2. **Test Installation**: Install in clean BC environment
3. **Test Functionality**: Verify all e-invoice features work
4. **Test Uninstall**: Ensure clean removal
5. **Test Reinstall**: Verify reinstallation works
6. **Check Dependencies**: Ensure all dependencies resolve
7. **Verify Permissions**: Test with non-SUPER user

## 🚨 CRITICAL VALIDATION POINTS

### Technical Validation
- Extension compiles successfully
- All dependencies resolve correctly
- No runtime package issues
- Proper signature validation
- Affix registration verification

### Business Logic Validation
- e-Invoice submission works correctly
- TIN validation functions properly
- QR code generation works
- All document types supported
- Error handling implemented

### Integration Validation
- MyInvois API integration works
- Azure Function communication works
- Business Central posting integration works
- Data synchronization works

## 📚 RESOURCES

- [Microsoft Technical Validation Checklist](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-checklist-submission)
- [AL Test Toolkit Documentation](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-testing-extension)
- [AppSource Submission Guide](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-checklist-submission)

## 🎯 NEXT STEPS

1. **Complete Testing**: Run full test suite in BC environment
2. **Digital Signing**: Sign the .app file
3. **Self-Validation**: Run Run-AlValidation command
4. **Documentation**: Prepare submission documentation
5. **Submit**: Submit to AppSource validation

## 📝 NOTES

- This extension targets Business Central 26.0.0.0 and above
- Malaysia (MY) is the primary target market
- All e-invoice functionality is specific to MyInvois LHDN requirements
- Extension follows Business Central best practices and coding standards
