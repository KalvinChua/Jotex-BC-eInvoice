report 50300 "LHDN e-Invoice Export"
{
    UsageCategory = Administration;
    ApplicationArea = All;
    ProcessingOnly = true;
    Caption = 'Export Batch e-Invoices for Posted Sales Invoice';
    DefaultLayout = RDLC;

    dataset
    {
        dataitem(SalesInvHeader; "Sales Invoice Header")
        {
            RequestFilterFields = "No.", "Posting Date", "Sell-to Customer No.";
            DataItemTableView = SORTING("Posting Date");

            trigger OnAfterGetRecord()
            var
                CompanyInfo: Record "Company Information";
                Customer: Record Customer;
                PaymentTerms: Record "Payment Terms";
                PaymentModes: Record "Payment Modes";
                CountryRegion: Record "Country/Region";
                GLSetup: Record "General Ledger Setup";
                CustBankAccount: Record "Customer Bank Account";
                CompanyBankAccount: Record "Bank Account";
                SalesInvLineLocal: Record "Sales Invoice Line";
            begin
                RowNo += 1;
                TotalTaxAmount := 0;
                TotalDiscountAmount := 0;
                TotalExcludingTax := 0;
                TotalIncludingTax := 0;

                // Get related records
                if not CompanyInfo.Get() then
                    Error('Company Information must be set up for e-Invoice export');

                if not Customer.Get("Sell-to Customer No.") then
                    Error('Customer %1 not found', "Sell-to Customer No.");

                if not PaymentTerms.Get("Payment Terms Code") then
                    PaymentTerms.Init();

                if not PaymentModes.Get("eInvoice Payment Mode") then
                    PaymentModes.Init();

                if not CountryRegion.Get(CompanyInfo."Country/Region Code") then
                    CountryRegion.Init();

                GLSetup.Get();

                if not CompanyBankAccount.Get(CompanyInfo."Bank Account No.") then
                    CompanyBankAccount.Init();

                CustBankAccount.SetRange("Customer No.", "Sell-to Customer No.");
                if not CustBankAccount.FindFirst() then
                    CustBankAccount.Init();

                // Calculate totals from invoice lines
                SalesInvLineLocal.SetRange("Document No.", "No.");
                SalesInvLineLocal.SetFilter(Type, '<>%1', SalesInvLineLocal.Type::" ");
                if SalesInvLineLocal.FindSet() then
                    repeat
                        if SalesInvLineLocal."Line Amount" <> 0 then begin
                            TotalExcludingTax += SalesInvLineLocal.Amount;
                            TotalIncludingTax += SalesInvLineLocal."Amount Including VAT";

                            if SalesInvLineLocal."VAT Calculation Type" <> SalesInvLineLocal."VAT Calculation Type"::"Full VAT" then
                                TotalTaxAmount += SalesInvLineLocal."Amount Including VAT" - SalesInvLineLocal.Amount;

                            TotalDiscountAmount += SalesInvLineLocal."Inv. Discount Amount" + SalesInvLineLocal."Line Discount Amount";
                        end;
                    until SalesInvLineLocal.Next() = 0;

                // Format date/time in ISO 8601 with Malaysia timezone
                InvDateTime := Format("Posting Date") + '  ' + Format(Time);

                // Basic invoice information
                AddExcelColumn(RowNo, 1, "No."); // eInvoiceNumber
                AddExcelColumn(RowNo, 2, "eInvoice Document Type"); // eInvoiceTypeCode
                AddExcelColumn(RowNo, 3, "eInvoice Version Code"); // eInvoiceVersion
                AddExcelColumn(RowNo, 4, InvDateTime); // IssuanceDateTime
                AddExcelColumn(RowNo, 5, "Currency Code"); // CurrencyCode
                AddExcelColumn(RowNo, 6, "Currency Factor"); // CurrencyExchangeRate

                // Supplier information
                AddExcelColumn(RowNo, 7, CompanyInfo."e-Invoice TIN No.");
                AddExcelColumn(RowNo, 8, CompanyInfo.Name);
                AddExcelColumn(RowNo, 9, Format(CompanyInfo."ID Type"));
                AddExcelColumn(RowNo, 10, CompanyInfo."ID No.");
                AddExcelColumn(RowNo, 11, CompanyInfo."VAT Registration No.");
                AddExcelColumn(RowNo, 12, CompanyInfo."TTX No.");
                AddExcelColumn(RowNo, 13, CompanyInfo."e-Invoice Email");
                AddExcelColumn(RowNo, 14, CompanyInfo."MSIC Code");
                AddExcelColumn(RowNo, 15, CompanyInfo."Business Activity Description");
                AddExcelColumn(RowNo, 16, CompanyInfo.Address);
                AddExcelColumn(RowNo, 17, CompanyInfo."Address 2");
                AddExcelColumn(RowNo, 18, '');
                AddExcelColumn(RowNo, 19, CompanyInfo."Post Code");
                AddExcelColumn(RowNo, 20, CompanyInfo.City);
                AddExcelColumn(RowNo, 21, CompanyInfo."e-Invoice State Code");
                AddExcelColumn(RowNo, 22, CompanyInfo."e-Invoice Country Code");
                AddExcelColumn(RowNo, 23, CompanyInfo."Phone No.");

                // Buyer information
                AddExcelColumn(RowNo, 24, Customer."e-Invoice TIN No.");
                AddExcelColumn(RowNo, 25, Customer.Name);
                AddExcelColumn(RowNo, 26, Format(Customer."e-Invoice ID Type"));
                AddExcelColumn(RowNo, 27, Customer."e-Invoice ID No.");
                AddExcelColumn(RowNo, 28, Customer."VAT Registration No.");
                AddExcelColumn(RowNo, 29, Customer."E-Mail");
                AddExcelColumn(RowNo, 30, Customer.Address);
                AddExcelColumn(RowNo, 31, Customer."Address 2");
                AddExcelColumn(RowNo, 32, '');
                AddExcelColumn(RowNo, 33, Customer."Post Code");
                AddExcelColumn(RowNo, 34, Customer.City);
                AddExcelColumn(RowNo, 35, Customer."e-Invoice State Code");
                AddExcelColumn(RowNo, 36, Customer."e-Invoice Country Code");
                AddExcelColumn(RowNo, 37, Customer."Phone No.");

                // Totals
                AddExcelColumn(RowNo, 38, Round(TotalExcludingTax, 0.01)); // TotalExcludingTax
                AddExcelColumn(RowNo, 39, Round(TotalIncludingTax, 0.01)); // TotalIncludingTax
                AddExcelColumn(RowNo, 40, Round(TotalIncludingTax, 0.01)); // TotalPayableAmount
                AddExcelColumn(RowNo, 41, ''); // TotalNetAmount
                AddExcelColumn(RowNo, 42, Round(TotalDiscountAmount, 0.01)); // TotalDiscountValue
                AddExcelColumn(RowNo, 43, ''); // TotalChargeAmount
                AddExcelColumn(RowNo, 44, ''); // TotalRoundingAmount
                AddExcelColumn(RowNo, 45, Round(TotalTaxAmount, 0.01)); // TotalTaxAmount

                // Billing
                AddExcelColumn(RowNo, 46, ''); // FrequencyBilling
                AddExcelColumn(RowNo, 47, ''); // BillingPeriod.StartDate
                AddExcelColumn(RowNo, 48, ''); // BillingPeriod.EndDate

                // Payment
                AddExcelColumn(RowNo, 49, ''); // PaymentMode
                AddExcelColumn(RowNo, 50, ''); // SupplierBankAccountNumber
                AddExcelColumn(RowNo, 51, ''); // PaymentTerms

                // Prepayment
                AddExcelColumn(RowNo, 52, ''); // PrePaymentAmount
                AddExcelColumn(RowNo, 53, ''); // PrePaymentDate
                AddExcelColumn(RowNo, 54, ''); // PrePaymentTime
                AddExcelColumn(RowNo, 55, ''); // PrePaymentReferenceNumber

                // Reference & Shipping
                AddExcelColumn(RowNo, 56, ''); // BillReferenceNumber
                AddExcelColumn(RowNo, 57, ''); // ShippingRecipientName
                AddExcelColumn(RowNo, 58, ''); // ShippingRecipientAddress.Address.AddressLine0
                AddExcelColumn(RowNo, 59, ''); // ShippingRecipientAddress.Address.AddressLine1
                AddExcelColumn(RowNo, 60, ''); // ShippingRecipientAddress.Address.AddressLine2
                AddExcelColumn(RowNo, 61, ''); // ShippingRecipientAddress.Address.PostalZone
                AddExcelColumn(RowNo, 62, ''); // ShippingRecipientAddress.Address.CityName
                AddExcelColumn(RowNo, 63, ''); // ShippingRecipientAddress.Address.State
                AddExcelColumn(RowNo, 64, ''); // ShippingRecipientAddress.Address.CountryCode
                AddExcelColumn(RowNo, 65, ''); // ShippingRecipientTIN
                AddExcelColumn(RowNo, 66, ''); // ShippingRecipientRegistrationNumber.Type
                AddExcelColumn(RowNo, 67, ''); // ShippingRecipientRegistrationNumber.Number

                // Additional
                AddExcelColumn(RowNo, 68, ''); // Incoterms
                AddExcelColumn(RowNo, 69, ''); // FreeTradeAgreement
                AddExcelColumn(RowNo, 70, ''); // AuthorisationNumberCertifiedExporter
                AddExcelColumn(RowNo, 71, ''); // ReferenceNumberCustomsFormNo2
                AddExcelColumn(RowNo, 72, ''); // DetailsOtherCharges.eInvoiceNumber
                AddExcelColumn(RowNo, 73, ''); // DetailsOtherCharges.Amount
                AddExcelColumn(RowNo, 74, ''); // DetailsOtherCharges.Description
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

        dataitem(SalesInvLine; "Sales Invoice Line")
        {
            DataItemLink = "Document No." = field("No.");
            DataItemLinkReference = SalesInvHeader;
            DataItemTableView = SORTING("Document No.", "Line No.") WHERE(Type = FILTER(<> " "));

            trigger OnAfterGetRecord()
            var
                Item: Record Item;
                VATPostingSetup: Record "VAT Posting Setup";
                CountryRegion: Record "Country/Region";
            begin
                // Skip lines with zero values for UnitPrice, Quantity, and UnitOfMeasurement
                if ("Unit Price" = 0) and (Quantity = 0) and ("e-Invoice UOM" = '') then
                    CurrReport.Skip();

                // Only process lines for invoices that were included in the first sheet
                if not ExcelBuffer.Get(RowNo, 1) then
                    CurrReport.Skip();

                LineRowNo += 1;
                ClassificationRowNo += 1;

                // Get related item information if available
                if Type = Type::Item then
                    if not Item.Get("No.") then
                        Clear(Item);

                // Get VAT information
                if not VATPostingSetup.Get("VAT Bus. Posting Group", "VAT Prod. Posting Group") then
                    VATPostingSetup.Init();

                // Add line details to the DocumentLineItems sheet
                AddLineExcelColumn(LineRowNo, 1, SalesInvHeader."No."); // eInvoiceNumber
                AddLineExcelColumn(LineRowNo, 2, "Line No."); // ID
                AddLineExcelColumn(LineRowNo, 3, "e-Invoice Classification"); // Classification
                AddLineExcelColumn(LineRowNo, 4, Description); // DescriptionProductService
                AddLineExcelColumn(LineRowNo, 5, "Unit Price"); // UnitPrice
                AddLineExcelColumn(LineRowNo, 6, Quantity); // Quantity
                AddLineExcelColumn(LineRowNo, 7, "e-Invoice UOM"); // UnitOfMeasurement
                AddLineExcelColumn(LineRowNo, 8, "Line Amount"); // Subtotal
                AddLineExcelColumn(LineRowNo, 9, "Amount Including VAT" - Amount); // TotalTaxAmount
                AddLineExcelColumn(LineRowNo, 10, GetLineAmountExclVAT()); // TotalExcludingTax
                AddLineExcelColumn(LineRowNo, 11, ''); // ProductTariffCode
                AddLineExcelColumn(LineRowNo, 12, ''); // CountryofOrigin

                // Add line details to the LineItemsAddClassification sheet
                AddClassificationExcelColumn(ClassificationRowNo, 1, SalesInvHeader."No."); // eInvoiceNumber
                AddClassificationExcelColumn(ClassificationRowNo, 2, "Line No."); // LineItem.ID
                AddClassificationExcelColumn(ClassificationRowNo, 3, "e-Invoice Classification"); // ClassificationCode
            end;

            trigger OnPreDataItem()
            begin
                LineRowNo := 1; // Reset counter for each invoice
                ClassificationRowNo := 1; // Reset counter for each invoice
                InitializeLineExcelHeaders();
                InitializeClassificationExcelHeaders();
            end;
        }

        dataitem(SalesInvLineTax; "Sales Invoice Line")
        {
            DataItemLink = "Document No." = field("No.");
            DataItemLinkReference = SalesInvHeader;
            DataItemTableView = SORTING("Document No.", "Line No.") WHERE(Type = FILTER(<> " "));

            trigger OnAfterGetRecord()
            var
                VATPostingSetup: Record "VAT Posting Setup";
            begin
                // Only process lines for invoices that were included in the main sheet
                if not ExcelBuffer.Get(RowNo, 1) then
                    CurrReport.Skip();

                TaxRowNo += 1;

                // Get VAT information
                if VATPostingSetup.Get("VAT Bus. Posting Group", "VAT Prod. Posting Group") then begin
                    // Add tax details to the LineItemTaxes sheet
                    AddTaxExcelColumn(TaxRowNo, 1, SalesInvHeader."No."); // eInvoiceNumber
                    AddTaxExcelColumn(TaxRowNo, 2, "Line No."); // LineItem.ID
                    AddTaxExcelColumn(TaxRowNo, 3, VATPostingSetup."VAT Identifier"); // TaxType
                    AddTaxExcelColumn(TaxRowNo, 4, "VAT %"); // TaxRate
                    AddTaxExcelColumn(TaxRowNo, 5, "Amount Including VAT" - Amount); // TaxAmount
                    AddTaxExcelColumn(TaxRowNo, 6, ''); // PerUnitAmount
                    AddTaxExcelColumn(TaxRowNo, 7, ''); // BaseUnitMeasure
                    AddTaxExcelColumn(TaxRowNo, 8, ''); // AmountTaxExempted
                    AddTaxExcelColumn(TaxRowNo, 9, ''); // DetailsTaxExemption
                    AddTaxExcelColumn(TaxRowNo, 10, ''); // TaxableAmount
                end;
            end;

            trigger OnPreDataItem()
            begin
                TaxRowNo := 1; // Reset counter for each invoice
                InitializeTaxExcelHeaders();
            end;
        }

        dataitem(SalesInvDocTax; "Sales Invoice Line")
        {
            DataItemLink = "Document No." = field("No.");
            DataItemLinkReference = SalesInvHeader;
            DataItemTableView = SORTING("Document No.", "Line No.") WHERE(Type = FILTER(<> " "));

            trigger OnAfterGetRecord()
            var
                VATPostingSetup: Record "VAT Posting Setup";
            begin
                // Only process lines for invoices that were included in the main sheet
                if not ExcelBuffer.Get(RowNo, 1) then
                    CurrReport.Skip();

                DocTaxRowNo += 1;

                // Get VAT information
                if VATPostingSetup.Get("VAT Bus. Posting Group", "VAT Prod. Posting Group") then begin
                    // Add doc tax details to the DocumentTotalTax sheet
                    AddDocTaxExcelColumn(DocTaxRowNo, 1, SalesInvHeader."No."); // eInvoiceNumber
                    AddDocTaxExcelColumn(DocTaxRowNo, 2, SalesInvDocTax."e-Invoice Tax Type"); // TaxType
                    AddDocTaxExcelColumn(DocTaxRowNo, 3, ''); // TotalTaxableAmount
                    AddDocTaxExcelColumn(DocTaxRowNo, 4, "Amount Including VAT" - Amount); // TotalTaxAmount
                    AddDocTaxExcelColumn(DocTaxRowNo, 5, ''); // AmountTaxExempted
                    AddDocTaxExcelColumn(DocTaxRowNo, 6, ''); // DetailsTaxExemption
                end;
            end;

            trigger OnPreDataItem()
            begin
                DocTaxRowNo := 1; // Reset counter for each invoice
                InitializeDocTaxExcelHeaders();
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
        VATPostingSetup: Record "VAT Posting Setup";
        RowNo: Integer;
        LineRowNo: Integer;
        ClassificationRowNo: Integer;
        TaxRowNo: Integer;
        DocTaxRowNo: Integer;
        InvDateTime: Text;
        TotalTaxAmount: Decimal;
        TotalDiscountAmount: Decimal;
        TotalExcludingTax: Decimal;
        TotalIncludingTax: Decimal;
        FileName: Text;
        IncludeAllFields: Boolean;

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

    local procedure InitializeLineExcelHeaders()
    var
        ColumnNo: Integer;
    begin
        ColumnNo := 1;

        // Add all columns for the DocumentLineItems sheet
        AddLineHeaderColumn(ColumnNo, 'eInvoiceNumber');
        ColumnNo += 1;
        AddLineHeaderColumn(ColumnNo, 'ID');
        ColumnNo += 1;
        AddLineHeaderColumn(ColumnNo, 'Classification');
        ColumnNo += 1;
        AddLineHeaderColumn(ColumnNo, 'DescriptionProductService');
        ColumnNo += 1;
        AddLineHeaderColumn(ColumnNo, 'UnitPrice');
        ColumnNo += 1;
        AddLineHeaderColumn(ColumnNo, 'Quantity');
        ColumnNo += 1;
        AddLineHeaderColumn(ColumnNo, 'UnitOfMeasurement');
        ColumnNo += 1;
        AddLineHeaderColumn(ColumnNo, 'Subtotal');
        ColumnNo += 1;
        AddLineHeaderColumn(ColumnNo, 'TotalTaxAmount');
        ColumnNo += 1;
        AddLineHeaderColumn(ColumnNo, 'TotalExcludingTax');
        ColumnNo += 1;
        AddLineHeaderColumn(ColumnNo, 'ProductTariffCode');
        ColumnNo += 1;
        AddLineHeaderColumn(ColumnNo, 'CountryofOrigin');
        ColumnNo += 1;
    end;

    local procedure InitializeClassificationExcelHeaders()
    var
        ColumnNo: Integer;
    begin
        ColumnNo := 1;

        // Add columns for the LineItemsAddClassification sheet
        AddClassificationHeaderColumn(ColumnNo, 'eInvoiceNumber');
        ColumnNo += 1;
        AddClassificationHeaderColumn(ColumnNo, 'LineItem.ID');
        ColumnNo += 1;
        AddClassificationHeaderColumn(ColumnNo, 'ClassificationCode');
        ColumnNo += 1;
    end;

    local procedure InitializeTaxExcelHeaders()
    var
        ColumnNo: Integer;
    begin
        ColumnNo := 1;

        // Add columns for the LineItemTaxes sheet
        AddTaxHeaderColumn(ColumnNo, 'eInvoiceNumber');
        ColumnNo += 1;
        AddTaxHeaderColumn(ColumnNo, 'LineItem.ID');
        ColumnNo += 1;
        AddTaxHeaderColumn(ColumnNo, 'TaxType');
        ColumnNo += 1;
        AddTaxHeaderColumn(ColumnNo, 'TaxRate');
        ColumnNo += 1;
        AddTaxHeaderColumn(ColumnNo, 'TaxAmount');
        ColumnNo += 1;
        AddTaxHeaderColumn(ColumnNo, 'PerUnitAmount');
        ColumnNo += 1;
        AddTaxHeaderColumn(ColumnNo, 'BaseUnitMeasure');
        ColumnNo += 1;
        AddTaxHeaderColumn(ColumnNo, 'AmountTaxExempted');
        ColumnNo += 1;
        AddTaxHeaderColumn(ColumnNo, 'DetailsTaxExemption');
        ColumnNo += 1;
        AddTaxHeaderColumn(ColumnNo, 'TaxableAmount');
        ColumnNo += 1;
    end;

    local procedure InitializeDocTaxExcelHeaders()
    var
        ColumnNo: Integer;
    begin
        ColumnNo := 1;

        // Add columns for the LineItemTaxes sheet
        AddDocTaxHeaderColumn(ColumnNo, 'eInvoiceNumber');
        ColumnNo += 1;
        AddDocTaxHeaderColumn(ColumnNo, 'TaxType');
        ColumnNo += 1;
        AddDocTaxHeaderColumn(ColumnNo, 'TotalTaxableAmount');
        ColumnNo += 1;
        AddDocTaxHeaderColumn(ColumnNo, 'TotalTaxAmount');
        ColumnNo += 1;
        AddDocTaxHeaderColumn(ColumnNo, 'AmountTaxExempted');
        ColumnNo += 1;
        AddDocTaxHeaderColumn(ColumnNo, 'DetailsTaxExemption');
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

    local procedure AddLineHeaderColumn(ColumnNo: Integer; ColumnName: Text)
    begin
        ExcelBuffer.Init();
        ExcelBuffer.Validate("Row No.", LineRowNo);
        ExcelBuffer.Validate("Column No.", ColumnNo + 100); // Use column numbers >100 for the second sheet
        ExcelBuffer.Validate("Cell Value as Text", ColumnName);
        ExcelBuffer.Insert();
    end;

    local procedure AddClassificationHeaderColumn(ColumnNo: Integer; ColumnName: Text)
    begin
        ExcelBuffer.Init();
        ExcelBuffer.Validate("Row No.", ClassificationRowNo);
        ExcelBuffer.Validate("Column No.", ColumnNo + 200); // Use column numbers >200 for the third sheet
        ExcelBuffer.Validate("Cell Value as Text", ColumnName);
        ExcelBuffer.Insert();
    end;

    local procedure AddTaxHeaderColumn(ColumnNo: Integer; ColumnName: Text)
    begin
        ExcelBuffer.Init();
        ExcelBuffer.Validate("Row No.", TaxRowNo);
        ExcelBuffer.Validate("Column No.", ColumnNo + 300); // Use column numbers >300 for the fourth sheet
        ExcelBuffer.Validate("Cell Value as Text", ColumnName);
        ExcelBuffer.Insert();
    end;

    local procedure AddDocTaxHeaderColumn(ColumnNo: Integer; ColumnName: Text)
    begin
        ExcelBuffer.Init();
        ExcelBuffer.Validate("Row No.", DocTaxRowNo);
        ExcelBuffer.Validate("Column No.", ColumnNo + 400); // Use column numbers >400 for the fifth sheet
        ExcelBuffer.Validate("Cell Value as Text", ColumnName);
        ExcelBuffer.Insert();
    end;

    local procedure AddExcelColumn(Row: Integer; Column: Integer; Value: Variant)
    begin
        if (not IncludeAllFields) and (Format(Value) = '') then
            exit;

        ExcelBuffer.Init();
        ExcelBuffer.Validate("Row No.", Row);
        ExcelBuffer.Validate("Column No.", Column);

        // Force text format for ID, code, and numeric fields that should be treated as text
        if Column in [2, 10, 19, 21, 27, 33, 35, 36, 49] then
            ExcelBuffer.Validate("Cell Type", ExcelBuffer."Cell Type"::Text);

        ExcelBuffer.Validate("Cell Value as Text", Format(Value, 0, 9));
        ExcelBuffer.Insert();
    end;

    local procedure AddLineExcelColumn(Row: Integer; Column: Integer; Value: Variant)
    begin
        if (not IncludeAllFields) and (Format(Value) = '') then
            exit;

        // Clear any existing entry first
        if ExcelBuffer.Get(Row, Column + 100) then
            ExcelBuffer.Delete();

        ExcelBuffer.Init();
        ExcelBuffer.Validate("Row No.", Row);
        ExcelBuffer.Validate("Column No.", Column + 100); // Use column numbers >100 for the second sheet

        // Force text format for code fields
        if Column in [1, 2, 3, 7, 11, 12] then
            ExcelBuffer.Validate("Cell Type", ExcelBuffer."Cell Type"::Text);

        // Format numeric values with 2 decimal places
        if Column in [5, 8, 9, 10] then
            ExcelBuffer.Validate("Cell Value as Text", Format(Value, 0, '<Precision,2><Standard Format,2>'))
        else
            ExcelBuffer.Validate("Cell Value as Text", Format(Value, 0, 9));

        if not ExcelBuffer.Insert() then
            ExcelBuffer.Modify();
    end;

    local procedure AddClassificationExcelColumn(Row: Integer; Column: Integer; Value: Variant)
    begin
        if (not IncludeAllFields) and (Format(Value) = '') then
            exit;

        // Clear any existing entry first
        if ExcelBuffer.Get(Row, Column + 200) then
            ExcelBuffer.Delete();

        ExcelBuffer.Init();
        ExcelBuffer.Validate("Row No.", Row);
        ExcelBuffer.Validate("Column No.", Column + 200); // Use column numbers >200 for the third sheet
        ExcelBuffer.Validate("Cell Type", ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.Validate("Cell Value as Text", Format(Value, 0, 9));

        if not ExcelBuffer.Insert() then
            ExcelBuffer.Modify();
    end;

    local procedure AddTaxExcelColumn(Row: Integer; Column: Integer; Value: Variant)
    begin
        if (not IncludeAllFields) and (Format(Value) = '') then
            exit;

        // Clear any existing entry first
        if ExcelBuffer.Get(Row, Column + 300) then
            ExcelBuffer.Delete();

        ExcelBuffer.Init();
        ExcelBuffer.Validate("Row No.", Row);
        ExcelBuffer.Validate("Column No.", Column + 300); // Use column numbers >300 for the fourth sheet

        // Force text format for code fields
        if Column in [1, 2, 3, 7, 9] then
            ExcelBuffer.Validate("Cell Type", ExcelBuffer."Cell Type"::Text);

        // Format numeric values with 2 decimal places
        if Column in [4, 5, 6, 8, 10] then
            ExcelBuffer.Validate("Cell Value as Text", Format(Value, 0, '<Precision,2><Standard Format,2>'))
        else
            ExcelBuffer.Validate("Cell Value as Text", Format(Value, 0, 9));

        if not ExcelBuffer.Insert() then
            ExcelBuffer.Modify();
    end;

    local procedure AddDocTaxExcelColumn(Row: Integer; Column: Integer; Value: Variant)
    begin
        if (not IncludeAllFields) and (Format(Value) = '') then
            exit;

        // Clear any existing entry first
        if ExcelBuffer.Get(Row, Column + 400) then
            ExcelBuffer.Delete();

        ExcelBuffer.Init();
        ExcelBuffer.Validate("Row No.", Row);
        ExcelBuffer.Validate("Column No.", Column + 400); // Use column numbers >400 for the fourth sheet

        // Force text format for code fields
        if Column in [1, 2] then
            ExcelBuffer.Validate("Cell Type", ExcelBuffer."Cell Type"::Text);

        // Format numeric values with 2 decimal places
        if Column in [3, 4, 5] then
            ExcelBuffer.Validate("Cell Value as Text", Format(Value, 0, '<Precision,2><Standard Format,2>'))
        else
            ExcelBuffer.Validate("Cell Value as Text", Format(Value, 0, 9));

        if not ExcelBuffer.Insert() then
            ExcelBuffer.Modify();
    end;

    trigger OnPostReport()
    var
        TempSalesInvHeader: Record "Sales Invoice Header";
        TempSalesInvLine: Record "Sales Invoice Line";
        TempSalesInvLineTax: Record "Sales Invoice Line";
        TempSalesDocLineTax: Record "Sales Invoice Line";
        LineRowCounter: Integer;
        ClassificationRowCounter: Integer;
        TaxRowCounter: Integer;
        DocTaxRowCounter: Integer;
    begin
        if ExcelBuffer.IsEmpty() then
            Error('No data to export.');

        if FileName = '' then
            FileName := 'LHDN_Posted_Sales_Invoice_Batch_' + Format(Today, 0, '<Year4><Month,2><Day,2>') + '.xlsx';

        // Create new workbook
        ExcelBuffer.CreateNewBook('LHDN Export');

        // Write first sheet (Documents)
        ExcelBuffer.WriteSheet('Documents', CompanyName, UserId);

        // Process second sheet (DocumentLineItems) if we have line items
        if LineRowNo > 1 then begin
            // Clear buffer for second sheet
            ExcelBuffer.DeleteAll();

            // Reinitialize line headers
            LineRowCounter := 1;
            InitializeLineExcelHeaders();

            // Process all filtered invoice headers
            TempSalesInvHeader.CopyFilters(SalesInvHeader);
            if TempSalesInvHeader.FindSet() then
                repeat
                    // Process lines for each invoice
                    TempSalesInvLine.Reset();
                    TempSalesInvLine.SetRange("Document No.", TempSalesInvHeader."No.");
                    if TempSalesInvLine.FindSet() then
                        repeat
                            LineRowCounter += 1;

                            // Add line details to the DocumentLineItems sheet
                            AddLineExcelColumn(LineRowCounter, 1, TempSalesInvHeader."No."); // eInvoiceNumber
                            AddLineExcelColumn(LineRowCounter, 2, TempSalesInvLine."Line No."); // ID
                            AddLineExcelColumn(LineRowCounter, 3, TempSalesInvLine."e-Invoice Classification"); // Classification
                            AddLineExcelColumn(LineRowCounter, 4, TempSalesInvLine.Description); // DescriptionProductService
                            AddLineExcelColumn(LineRowCounter, 5, TempSalesInvLine."Unit Price"); // UnitPrice
                            AddLineExcelColumn(LineRowCounter, 6, TempSalesInvLine.Quantity); // Quantity
                            AddLineExcelColumn(LineRowCounter, 7, TempSalesInvLine."e-Invoice UOM"); // UnitOfMeasurement
                            AddLineExcelColumn(LineRowCounter, 8, TempSalesInvLine."Line Amount"); // Subtotal
                            AddLineExcelColumn(LineRowCounter, 9, TempSalesInvLine."Amount Including VAT" - TempSalesInvLine.Amount); // TotalTaxAmount
                            AddLineExcelColumn(LineRowCounter, 10, TempSalesInvLine.GetLineAmountExclVAT()); // TotalExcludingTax
                            AddLineExcelColumn(LineRowCounter, 11, ''); // ProductTariffCode
                            AddLineExcelColumn(LineRowCounter, 12, ''); // CountryofOrigin
                        until TempSalesInvLine.Next() = 0;
                until TempSalesInvHeader.Next() = 0;

            // Write second sheet
            ExcelBuffer.WriteSheet('DocumentLineItems', CompanyName, UserId);
        end;

        // Process third sheet (LineItemsAddClassification) if we have line items
        if ClassificationRowNo > 1 then begin
            // Clear buffer for third sheet
            ExcelBuffer.DeleteAll();

            // Reinitialize classification headers
            ClassificationRowCounter := 1;
            InitializeClassificationExcelHeaders();

            // Process all filtered invoice headers
            TempSalesInvHeader.CopyFilters(SalesInvHeader);
            if TempSalesInvHeader.FindSet() then
                repeat
                    // Process lines for each invoice
                    TempSalesInvLine.Reset();
                    TempSalesInvLine.SetRange("Document No.", TempSalesInvHeader."No.");
                    if TempSalesInvLine.FindSet() then
                        repeat
                            ClassificationRowCounter += 1;

                            // Add line details to the LineItemsAddClassification sheet
                            AddClassificationExcelColumn(ClassificationRowCounter, 1, TempSalesInvHeader."No."); // eInvoiceNumber
                            AddClassificationExcelColumn(ClassificationRowCounter, 2, TempSalesInvLine."Line No."); // LineItem.ID
                            AddClassificationExcelColumn(ClassificationRowCounter, 3, TempSalesInvLine."e-Invoice Classification"); // ClassificationCode
                        until TempSalesInvLine.Next() = 0;
                until TempSalesInvHeader.Next() = 0;

            // Write third sheet
            ExcelBuffer.WriteSheet('LineItemsAddClassification', CompanyName, UserId);
        end;

        // Process fourth sheet (LineItemTaxes) if we have line items
        if TaxRowNo > 1 then begin
            // Clear buffer for fourth sheet
            ExcelBuffer.DeleteAll();

            // Reinitialize tax headers
            TaxRowCounter := 1;
            InitializeTaxExcelHeaders();

            // Process all filtered invoice headers
            TempSalesInvHeader.CopyFilters(SalesInvHeader);
            if TempSalesInvHeader.FindSet() then
                repeat
                    // Process lines for each invoice
                    TempSalesInvLineTax.Reset();
                    TempSalesInvLineTax.SetRange("Document No.", TempSalesInvHeader."No.");
                    if TempSalesInvLineTax.FindSet() then
                        repeat
                            TaxRowCounter += 1;

                            // Get VAT information
                            if VATPostingSetup.Get(TempSalesInvLineTax."VAT Bus. Posting Group", TempSalesInvLineTax."VAT Prod. Posting Group") then begin
                                // Add tax details to the LineItemTaxes sheet
                                AddTaxExcelColumn(TaxRowCounter, 1, TempSalesInvHeader."No."); // eInvoiceNumber
                                AddTaxExcelColumn(TaxRowCounter, 2, TempSalesInvLineTax."Line No."); // LineItem.ID
                                AddTaxExcelColumn(TaxRowCounter, 3, TempSalesInvLineTax."e-Invoice Tax Type"); // TaxType
                                AddTaxExcelColumn(TaxRowCounter, 4, TempSalesInvLineTax."VAT %"); // TaxRate
                                AddTaxExcelColumn(TaxRowCounter, 5, TempSalesInvLineTax."Amount Including VAT" - TempSalesInvLineTax.Amount); // TaxAmount
                                AddTaxExcelColumn(TaxRowCounter, 6, ''); // PerUnitAmount
                                AddTaxExcelColumn(TaxRowCounter, 7, ''); // BaseUnitMeasure
                                AddTaxExcelColumn(TaxRowCounter, 8, ''); // AmountTaxExempted
                                AddTaxExcelColumn(TaxRowCounter, 9, ''); // DetailsTaxExemption
                                AddTaxExcelColumn(TaxRowCounter, 10, ''); // TaxableAmount
                            end;
                        until TempSalesInvLineTax.Next() = 0;
                until TempSalesInvHeader.Next() = 0;

            // Write fourth sheet
            ExcelBuffer.WriteSheet('LineItemTaxes', CompanyName, UserId);
        end;

        // Process fifth sheet (DocumentTotalTax) if we have line items
        if DocTaxRowNo > 1 then begin
            // Clear buffer for fifth sheet
            ExcelBuffer.DeleteAll();

            // Reinitialize tax headers
            DocTaxRowCounter := 1;
            InitializeDocTaxExcelHeaders();

            // Process all filtered invoice headers
            TempSalesInvHeader.CopyFilters(SalesInvHeader);
            if TempSalesInvHeader.FindSet() then
                repeat
                    // Process lines for each invoice
                    TempSalesDocLineTax.Reset();
                    TempSalesDocLineTax.SetRange("Document No.", TempSalesInvHeader."No.");
                    if TempSalesDocLineTax.FindSet() then
                        repeat
                            DocTaxRowCounter += 1;

                            // Get VAT information
                            if VATPostingSetup.Get(TempSalesInvLineTax."VAT Bus. Posting Group", TempSalesDocLineTax."VAT Prod. Posting Group") then begin
                                // Add tax details to the LineItemTaxes sheet
                                AddDocTaxExcelColumn(DocTaxRowCounter, 1, TempSalesInvHeader."No."); // eInvoiceNumber
                                AddDocTaxExcelColumn(DocTaxRowCounter, 2, TempSalesDocLineTax."e-Invoice Tax Type"); // TaxType
                                AddDocTaxExcelColumn(DocTaxRowCounter, 3, ''); // TotalTaxableAmount
                                AddDocTaxExcelColumn(DocTaxRowCounter, 4, TempSalesDocLineTax."Amount Including VAT" - TempSalesDocLineTax.Amount); // TotalTaxAmount
                                AddDocTaxExcelColumn(DocTaxRowCounter, 5, ''); // AmountTaxExempted
                                AddDocTaxExcelColumn(DocTaxRowCounter, 6, ''); // DetailsTaxExempted
                            end;
                        until TempSalesDocLineTax.Next() = 0;
                until TempSalesInvHeader.Next() = 0;

            // Write fifth sheet
            ExcelBuffer.WriteSheet('DocumentTotalTax', CompanyName, UserId);
        end;

        ExcelBuffer.CloseBook();
        ExcelBuffer.SetFriendlyFilename(FileName);
        ExcelBuffer.OpenExcel();
    end;

    trigger OnPreReport()
    begin
        // Initialize global variables
        TotalTaxAmount := 0;
        TotalDiscountAmount := 0;
        TotalExcludingTax := 0;
        TotalIncludingTax := 0;
        LineRowNo := 1;
        ClassificationRowNo := 1;
        TaxRowNo := 1;
        DocTaxRowNo := 1;
    end;
}