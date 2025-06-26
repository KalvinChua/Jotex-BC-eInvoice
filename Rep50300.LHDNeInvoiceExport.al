report 50300 "LHDN e-Invoice Export"
{
    UsageCategory = Administration;
    ApplicationArea = All;
    ProcessingOnly = true;
    Caption = 'Export e-Invoices for LHDN';
    DefaultLayout = RDLC;

    dataset
    {
        dataitem(SalesInvHeader; "Sales Invoice Header")
        {
            RequestFilterFields = "No.", "Posting Date", "Sell-to Customer No.";
            DataItemTableView = SORTING("Posting Date");

            dataitem(SalesInvLine; "Sales Invoice Line")
            {
                DataItemLink = "Document No." = field("No.");
                DataItemTableView = SORTING("Document No.", "Line No.") WHERE(Type = FILTER(Item | "G/L Account" | Resource));

                trigger OnAfterGetRecord()
                begin
                    // Calculate line-level tax amounts (only for taxable lines)
                    if "Line Amount" <> 0 then begin
                        if "VAT Calculation Type" <> "VAT Calculation Type"::"Full VAT" then
                            TotalTaxAmount += "Amount Including VAT" - Amount;

                        // Calculate total discount amount
                        TotalDiscountAmount += "Inv. Discount Amount" + "Line Discount Amount";
                    end;
                end;
            }

            trigger OnAfterGetRecord()
            var
                CompanyInfo: Record "Company Information";
                Customer: Record Customer;
                PaymentTerms: Record "Payment Terms";
                PaymentMethod: Record "Payment Method";
                CountryRegion: Record "Country/Region";
                GLSetup: Record "General Ledger Setup";
                CustBankAccount: Record "Customer Bank Account";
                CompanyBankAccount: Record "Bank Account";
                SalesInvLineLocal: Record "Sales Invoice Line"; // For totals
            begin
                RowNo += 1;
                TotalTaxAmount := 0;
                TotalDiscountAmount := 0;

                // Get related records
                if not CompanyInfo.Get() then
                    Error('Company Information must be set up for e-Invoice export');

                if not Customer.Get("Sell-to Customer No.") then
                    Error('Customer %1 not found', "Sell-to Customer No.");

                if not PaymentTerms.Get("Payment Terms Code") then
                    PaymentTerms.Init();

                if not PaymentMethod.Get("Payment Method Code") then
                    PaymentMethod.Init();

                if not CountryRegion.Get(CompanyInfo."Country/Region Code") then
                    CountryRegion.Init();

                GLSetup.Get();

                if not CompanyBankAccount.Get(CompanyInfo."Bank Account No.") then
                    CompanyBankAccount.Init();

                CustBankAccount.SetRange("Customer No.", "Sell-to Customer No.");
                if not CustBankAccount.FindFirst() then
                    CustBankAccount.Init();

                // 🔁 Manual line total calculation loop
                SalesInvLineLocal.SetRange("Document No.", "No.");
                SalesInvLineLocal.SetFilter(Type, '<>%1', SalesInvLineLocal.Type::" ");
                if SalesInvLineLocal.FindSet() then
                    repeat
                        if SalesInvLineLocal."Line Amount" <> 0 then begin
                            if SalesInvLineLocal."VAT Calculation Type" <> SalesInvLineLocal."VAT Calculation Type"::"Full VAT" then
                                TotalTaxAmount += SalesInvLineLocal."Amount Including VAT" - SalesInvLineLocal.Amount;

                            TotalDiscountAmount += SalesInvLineLocal."Inv. Discount Amount" + SalesInvLineLocal."Line Discount Amount";
                        end;
                    until SalesInvLineLocal.Next() = 0;

                // Format date/time in ISO 8601 with Malaysia timezone
                InvDateTime := Format("Posting Date", 0, '<Year4>-<Month,2>-<Day,2>') + 'T' +
                              Format(Time, 0, '<Hours24,2>:<Minutes,2>:<Seconds,2>') + '+08:00';

                // Basic invoice information
                AddExcelColumn(RowNo, 1, "No."); // eInvoiceNumber
                AddExcelColumn(RowNo, 2, SalesInvHeader."eInvoice Document Type"); // eInvoiceTypeCode
                AddExcelColumn(RowNo, 3, '1.0'); // eInvoiceVersion
                AddExcelColumn(RowNo, 4, InvDateTime); // IssuanceDateTime
                AddExcelColumn(RowNo, 5, GLSetup."LCY Code"); // CurrencyCode (use LCY if blank)
                AddExcelColumn(RowNo, 6, "Currency Factor"); // CurrencyExchangeRate (actual rate)

                // Supplier information (Company Information)
                AddExcelColumn(RowNo, 7, CompanyInfo."e-Invoice TIN No."); // Supplier.TIN
                AddExcelColumn(RowNo, 8, CompanyInfo.Name); // Supplier.Name
                AddExcelColumn(RowNo, 9, CompanyInfo."ID Type"); // Supplier.IDType (default to Registration)
                AddExcelColumn(RowNo, 10, CompanyInfo."ID No."); // Supplier.IDNo
                AddExcelColumn(RowNo, 11, CompanyInfo."VAT Registration No."); // Supplier.SST.No
                AddExcelColumn(RowNo, 12, CompanyInfo."TTX No."); // Supplier.TTX.No
                AddExcelColumn(RowNo, 13, CompanyInfo."e-Invoice Email"); // Supplier.Email
                AddExcelColumn(RowNo, 14, CompanyInfo."MSIC Code"); // Supplier.MSIC.Code
                AddExcelColumn(RowNo, 15, CompanyInfo."Business Activity Description"); // Supplier.BusinessActivityDescription
                AddExcelColumn(RowNo, 16, CompanyInfo.Address); // Supplier.Address.AddressLine0
                AddExcelColumn(RowNo, 17, CompanyInfo."Address 2"); // Supplier.Address.AddressLine1
                AddExcelColumn(RowNo, 18, ''); // Supplier.Address.AddressLine2
                AddExcelColumn(RowNo, 19, CompanyInfo."Post Code"); // Supplier.Address.PostalZone
                AddExcelColumn(RowNo, 20, CompanyInfo.City); // Supplier.Address.CityName
                AddExcelColumn(RowNo, 21, CompanyInfo."e-Invoice State Code"); // Supplier.Address.State
                AddExcelColumn(RowNo, 22, CompanyInfo."e-Invoice Country Code"); // Supplier.Address.CountryCode
                AddExcelColumn(RowNo, 23, CompanyInfo."Phone No."); // Supplier.ContactNumber

                // Buyer information (Customer)
                AddExcelColumn(RowNo, 24, Customer."e-Invoice TIN No."); // Buyer.TIN
                AddExcelColumn(RowNo, 25, Customer.Name); // Buyer.Name
                AddExcelColumn(RowNo, 26, Customer."e-Invoice ID Type"); // Buyer.IDType
                AddExcelColumn(RowNo, 27, Customer."e-Invoice SST No."); // Buyer.IDNo
                AddExcelColumn(RowNo, 28, Customer."VAT Registration No."); // Buyer.SST.No
                AddExcelColumn(RowNo, 29, Customer."E-Mail"); // Buyer.Email
                AddExcelColumn(RowNo, 30, Customer.Address); // Buyer.Address.AddressLine0
                AddExcelColumn(RowNo, 31, Customer."Address 2"); // Buyer.Address.AddressLine1
                AddExcelColumn(RowNo, 32, ''); // Buyer.Address.AddressLine2
                AddExcelColumn(RowNo, 33, Customer."Post Code"); // Buyer.Address.PostalZone
                AddExcelColumn(RowNo, 34, Customer.City); // Buyer.Address.CityName
                AddExcelColumn(RowNo, 35, Customer."e-Invoice State Code"); // Buyer.Address.State
                AddExcelColumn(RowNo, 36, Customer."e-Invoice Country Code"); // Buyer.Address.CountryCode
                AddExcelColumn(RowNo, 37, Customer."Phone No."); // Buyer.ContactNumber

                // Totals (with proper rounding)
                AddExcelColumn(RowNo, 38, Round(Amount, 0.01)); // TotalExcludingTax
                AddExcelColumn(RowNo, 39, Round("Amount Including VAT", 0.01)); // TotalIncludingTax
                AddExcelColumn(RowNo, 40, Round("Amount Including VAT", 0.01)); // TotalPayableAmount
                AddExcelColumn(RowNo, 41, Round(Amount, 0.01)); // TotalNetAmount
                AddExcelColumn(RowNo, 42, Round(TotalDiscountAmount, 0.01)); // TotalDiscountValue
                AddExcelColumn(RowNo, 43, 0); // TotalChargeAmount
                AddExcelColumn(RowNo, 44, Round("Amount Including VAT" - Amount - TotalTaxAmount, 0.01)); // TotalRoundingAmount
                AddExcelColumn(RowNo, 45, Round(TotalTaxAmount, 0.01)); // TotalTaxAmount

                // Billing
                AddExcelColumn(RowNo, 46, ''); // FrequencyBilling
                AddExcelColumn(RowNo, 47, Format("Posting Date", 0, '<Year4>-<Month,2>-<Day,2>')); // BillingPeriod.StartDate
                AddExcelColumn(RowNo, 48, Format("Posting Date", 0, '<Year4>-<Month,2>-<Day,2>')); // BillingPeriod.EndDate

                // Payment
                AddExcelColumn(RowNo, 49, PaymentMethod.Code); // PaymentMode
                AddExcelColumn(RowNo, 50, CompanyBankAccount."Bank Account No."); // SupplierBankAccountNumber
                AddExcelColumn(RowNo, 51, PaymentTerms.Code); // PaymentTerms

                // Prepayment
                AddExcelColumn(RowNo, 52, ''); // PrePaymentAmount
                AddExcelColumn(RowNo, 53, ''); // PrePaymentDate
                AddExcelColumn(RowNo, 54, ''); // PrePaymentTime
                AddExcelColumn(RowNo, 55, ''); // PrePaymentReferenceNumber


                // Reference & Shipping
                AddExcelColumn(RowNo, 56, "External Document No."); // BillReferenceNumber
                AddExcelColumn(RowNo, 57, "Ship-to Name"); // ShippingRecipientName
                AddExcelColumn(RowNo, 58, ''); // ShippingRecipientAddress.Address.AddressLine0
                AddExcelColumn(RowNo, 59, "Ship-to Address"); // ShippingRecipientAddress.Address.AddressLine1
                AddExcelColumn(RowNo, 60, "Ship-to Address 2"); // ShippingRecipientAddress.Address.AddressLine2
                AddExcelColumn(RowNo, 61, "Ship-to Post Code"); // ShippingRecipientAddress.Address.PostalZone
                AddExcelColumn(RowNo, 62, "Ship-to City"); // ShippingRecipientAddress.Address.CityName
                AddExcelColumn(RowNo, 63, "Ship-to County"); // ShippingRecipientAddress.Address.State
                AddExcelColumn(RowNo, 64, "Ship-to Country/Region Code"); // ShippingRecipientAddress.Address.CountryCode
                AddExcelColumn(RowNo, 65, Customer."e-Invoice TIN No."); // ShippingRecipientTIN
                AddExcelColumn(RowNo, 66, ''); // ShippingRecipientRegistrationNumber.Type
                AddExcelColumn(RowNo, 67, Customer."VAT Registration No."); // ShippingRecipientRegistrationNumber.Number

                // Additional
                AddExcelColumn(RowNo, 68, "Transaction Specification"); // Incoterms
                AddExcelColumn(RowNo, 69, ''); // FreeTradeAgreement
                AddExcelColumn(RowNo, 70, ''); // AuthorisationNumberCertifiedExporter
                AddExcelColumn(RowNo, 71, ''); // ReferenceNumberCustomsFormNo2
                AddExcelColumn(RowNo, 72, ''); // DetailsOtherCharges.eInvoiceNumber
                AddExcelColumn(RowNo, 73, 0); // DetailsOtherCharges.Amount
                AddExcelColumn(RowNo, 74, "Payment Reference"); // DetailsOtherCharges.Description
            end;

            trigger OnPreDataItem()
            begin
                if GetFilters = '' then
                    Error('Please specify filters for the report');

                // Initialize Excel headers
                RowNo := 1;
                ExcelBuffer.DeleteAll();
                InitializeExcelHeaders();
            end;
        }
    }

    requestpage
    {
        layout
        {
            area(Content)
            {
                group(Options)
                {
                    field(IncludeAllFields; IncludeAllFields)
                    {
                        ApplicationArea = All;
                        Caption = 'Include All Fields';
                        ToolTip = 'Include all fields even if empty';
                    }
                    field(FileName; FileName)
                    {
                        ApplicationArea = All;
                        Caption = 'File Name';
                        ToolTip = 'Specify the name for the export file';
                    }
                }
            }
        }

        var
            IncludeAllFields: Boolean;
            FileName: Text;
    }

    var
        ExcelBuffer: Record "Excel Buffer" temporary;
        RowNo: Integer;
        InvDateTime: Text;
        TotalTaxAmount: Decimal;
        TotalDiscountAmount: Decimal;
        FileName: Text; // ✅ For download name
        IncludeAllFields: Boolean; // ✅ From requestpage

    local procedure InitializeExcelHeaders()
    var
        ColumnNo: Integer;
    begin
        ColumnNo := 1;

        // Add all columns from the LHDN Bulk Upload "Documents" sheet
        AddHeaderColumn(ColumnNo, 'eInvoiceNumber');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'eInvoiceTypeCode');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'eInvoiceVersion');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'IssuanceDateTime');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'CurrencyCode');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'CurrencyExchangeRate');
        ColumnNo += 1;

        // Supplier columns
        AddHeaderColumn(ColumnNo, 'Supplier.TIN');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'Supplier.Name');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'Supplier.IDType');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'Supplier.IDNo');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'Supplier.SST.No');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'Supplier.TTX.No');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'Supplier.Email');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'Supplier.MSIC.Code');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'Supplier.BusinessActivityDescription');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'Supplier.Address.AddressLine0');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'Supplier.Address.AddressLine1');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'Supplier.Address.AddressLine2');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'Supplier.Address.PostalZone');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'Supplier.Address.CityName');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'Supplier.Address.State');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'Supplier.Address.CountryCode');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'Supplier.ContactNumber');
        ColumnNo += 1;

        // Buyer columns
        AddHeaderColumn(ColumnNo, 'Buyer.TIN');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'Buyer.Name');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'Buyer.IDType');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'Buyer.IDNo');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'Buyer.SST.No');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'Buyer.Email');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'Buyer.Address.AddressLine0');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'Buyer.Address.AddressLine1');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'Buyer.Address.AddressLine2');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'Buyer.Address.PostalZone');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'Buyer.Address.CityName');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'Buyer.Address.State');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'Buyer.Address.CountryCode');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'Buyer.ContactNumber');
        ColumnNo += 1;

        // Totals
        AddHeaderColumn(ColumnNo, 'TotalExcludingTax');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'TotalIncludingTax');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'TotalPayableAmount');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'TotalNetAmount');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'TotalDiscountValue');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'TotalChargeAmount');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'TotalRoundingAmount');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'TotalTaxAmount');
        ColumnNo += 1;

        // Billing
        AddHeaderColumn(ColumnNo, 'FrequencyBilling');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'BillingPeriod.StartDate');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'BillingPeriod.EndDate');
        ColumnNo += 1;

        // Payment
        AddHeaderColumn(ColumnNo, 'PaymentMode');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'SupplierBankAccountNumber');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'PaymentTerms');
        ColumnNo += 1;

        // Prepayment
        AddHeaderColumn(ColumnNo, 'PrePaymentAmount');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'PrePaymentDate');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'PrePaymentTime');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'PrePaymentReferenceNumber');
        ColumnNo += 1;

        // Reference & Shipping
        AddHeaderColumn(ColumnNo, 'BillReferenceNumber');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'ShippingRecipientName');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'ShippingRecipientAddress.Address.AddressLine0');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'ShippingRecipientAddress.Address.AddressLine1');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'ShippingRecipientAddress.Address.AddressLine2');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'ShippingRecipientAddress.Address.PostalZone');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'ShippingRecipientAddress.Address.CityName');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'ShippingRecipientAddress.Address.State');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'ShippingRecipientAddress.Address.CountryCode');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'ShippingRecipientTIN');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'ShippingRecipientRegistrationNumber.Type');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'ShippingRecipientRegistrationNumber.Number');
        ColumnNo += 1;

        // Additional
        AddHeaderColumn(ColumnNo, 'Incoterms');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'FreeTradeAgreement');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'AuthorisationNumberCertifiedExporter');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'ReferenceNumberCustomsFormNo2');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'DetailsOtherCharges.eInvoiceNumber');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'DetailsOtherCharges.Amount');
        ColumnNo += 1;
        AddHeaderColumn(ColumnNo, 'DetailsOtherCharges.Description');
        ColumnNo += 1;
    end;

    local procedure AddHeaderColumn(ColumnNo: Integer; ColumnName: Text)
    begin
        ExcelBuffer.Init();
        ExcelBuffer.Validate("Row No.", RowNo);
        ExcelBuffer.Validate("Column No.", ColumnNo);
        ExcelBuffer.Validate("Cell Value as Text", ColumnName);
        ExcelBuffer.Insert();
    end;

    local procedure AddExcelColumn(Row: Integer; Column: Integer; Value: Variant)
    var
        CellValue: Text;
    begin
        if (not IncludeAllFields) and (Format(Value) = '') then
            exit;

        CellValue := Format(Value, 0, 9);

        ExcelBuffer.Init();
        ExcelBuffer.Validate("Row No.", Row);
        ExcelBuffer.Validate("Column No.", Column);

        if Value.IsDecimal() or Value.IsInteger() then
            ExcelBuffer.Validate("Cell Value as Text", Value)
        else
            ExcelBuffer.Validate("Cell Value as Text", CellValue);

        ExcelBuffer.Insert();
    end;

    trigger OnPostReport()
    begin
        if ExcelBuffer.IsEmpty() then
            Error('No data to export.');

        if FileName = '' then
            FileName := 'LHDN_eInvoice_Export_' + Format(Today, 0, '<Year4><Month,2><Day,2>') + '.xlsx';

        ExcelBuffer.CreateNewBook('LHDN e-Invoice');
        ExcelBuffer.WriteSheet('Documents', CompanyName, UserId);
        ExcelBuffer.CloseBook();
        ExcelBuffer.SetFriendlyFilename(FileName);
        ExcelBuffer.OpenExcel();
    end;

    trigger OnPreReport()
    begin
        // Initialize global variables
        TotalTaxAmount := 0;
        TotalDiscountAmount := 0;
    end;
}