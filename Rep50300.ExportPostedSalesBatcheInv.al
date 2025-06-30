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

                InvDateTime := Format("Posting Date") + '  ' + Format(Time);

                // Basic invoice information
                AddExcelColumn(RowNo, 1, "No.");
                AddExcelColumn(RowNo, 2, "eInvoice Document Type");
                AddExcelColumn(RowNo, 3, "eInvoice Version Code");
                AddExcelColumn(RowNo, 4, InvDateTime);
                AddExcelColumn(RowNo, 5, "Currency Code");
                AddExcelColumn(RowNo, 6, "Currency Factor");

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
                AddExcelColumn(RowNo, 27, Customer."e-Invoice SST No.");
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
                AddExcelColumn(RowNo, 38, Round(TotalExcludingTax, 0.01));
                AddExcelColumn(RowNo, 39, Round(TotalIncludingTax, 0.01));
                AddExcelColumn(RowNo, 40, Round(TotalIncludingTax, 0.01));
                AddExcelColumn(RowNo, 41, '');
                AddExcelColumn(RowNo, 42, Round(TotalDiscountAmount, 0.01));
                AddExcelColumn(RowNo, 43, '');
                AddExcelColumn(RowNo, 44, '');
                AddExcelColumn(RowNo, 45, Round(TotalTaxAmount, 0.01));

                // Billing
                AddExcelColumn(RowNo, 46, '');
                AddExcelColumn(RowNo, 47, '');
                AddExcelColumn(RowNo, 48, '');

                // Payment
                AddExcelColumn(RowNo, 49, '');
                AddExcelColumn(RowNo, 50, '');
                AddExcelColumn(RowNo, 51, '');

                // Prepayment
                AddExcelColumn(RowNo, 52, '');
                AddExcelColumn(RowNo, 53, '');
                AddExcelColumn(RowNo, 54, '');
                AddExcelColumn(RowNo, 55, '');

                // Reference & Shipping
                AddExcelColumn(RowNo, 56, '');
                AddExcelColumn(RowNo, 57, '');
                AddExcelColumn(RowNo, 58, '');
                AddExcelColumn(RowNo, 59, '');
                AddExcelColumn(RowNo, 60, '');
                AddExcelColumn(RowNo, 61, '');
                AddExcelColumn(RowNo, 62, '');
                AddExcelColumn(RowNo, 63, '');
                AddExcelColumn(RowNo, 64, '');
                AddExcelColumn(RowNo, 65, '');
                AddExcelColumn(RowNo, 66, '');
                AddExcelColumn(RowNo, 67, '');

                // Additional
                AddExcelColumn(RowNo, 68, '');
                AddExcelColumn(RowNo, 69, '');
                AddExcelColumn(RowNo, 70, '');
                AddExcelColumn(RowNo, 71, '');
                AddExcelColumn(RowNo, 72, '');
                AddExcelColumn(RowNo, 73, '');
                AddExcelColumn(RowNo, 74, '');
            end;

            trigger OnPreDataItem()
            begin
                if GetFilters = '' then
                    Error('Please specify filters for the report');

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
                TaxAmount: Decimal;
                PerUnitAmount: Decimal;
            begin
                if not ExcelBuffer.Get(RowNo, 1) then
                    CurrReport.Skip();

                LineRowNo += 1;
                ClassificationRowNo += 1;
                TaxRowNo += 1;

                if Type = Type::Item then
                    if not Item.Get("No.") then
                        Clear(Item);

                if not VATPostingSetup.Get("VAT Bus. Posting Group", "VAT Prod. Posting Group") then
                    VATPostingSetup.Init();

                // DocumentLineItems sheet
                AddLineExcelColumn(LineRowNo, 1, SalesInvHeader."No.");
                AddLineExcelColumn(LineRowNo, 2, "Line No.");
                AddLineExcelColumn(LineRowNo, 3, "e-Invoice Classification");
                AddLineExcelColumn(LineRowNo, 4, Description);
                AddLineExcelColumn(LineRowNo, 5, "Unit Price");
                AddLineExcelColumn(LineRowNo, 6, Quantity);
                AddLineExcelColumn(LineRowNo, 7, "e-Invoice UOM");
                AddLineExcelColumn(LineRowNo, 8, "Line Amount");
                AddLineExcelColumn(LineRowNo, 9, "Amount Including VAT" - Amount);
                AddLineExcelColumn(LineRowNo, 10, GetLineAmountExclVAT());
                AddLineExcelColumn(LineRowNo, 11, '');
                AddLineExcelColumn(LineRowNo, 12, '');

                // LineItemsAddClassification sheet
                AddClassificationExcelColumn(ClassificationRowNo, 1, SalesInvHeader."No.");
                AddClassificationExcelColumn(ClassificationRowNo, 2, "Line No.");
                AddClassificationExcelColumn(ClassificationRowNo, 3, "e-Invoice Classification");

                // LineItemTaxes sheet
                if "VAT %" <> 0 then begin
                    TaxAmount := "Amount Including VAT" - Amount;
                    PerUnitAmount := (Quantity <> 0) ? TaxAmount / Quantity : 0;

                    AddTaxExcelColumn(TaxRowNo, 1, SalesInvHeader."No.");
                    AddTaxExcelColumn(TaxRowNo, 2, "Line No.");
                    AddTaxExcelColumn(TaxRowNo, 3, 'SST');
                    AddTaxExcelColumn(TaxRowNo, 4, "VAT %");
                    AddTaxExcelColumn(TaxRowNo, 5, TaxAmount);
                    AddTaxExcelColumn(TaxRowNo, 6, PerUnitAmount);
                    AddTaxExcelColumn(TaxRowNo, 7, "Unit of Measure Code");
                    AddTaxExcelColumn(TaxRowNo, 8, 0);
                    AddTaxExcelColumn(TaxRowNo, 9, '');
                    AddTaxExcelColumn(TaxRowNo, 10, Amount);
                end;
            end;

            trigger OnPreDataItem()
            begin
                LineRowNo := 1;
                ClassificationRowNo := 1;
                TaxRowNo := 1;
                InitializeLineExcelHeaders();
                InitializeClassificationExcelHeaders();
                InitializeTaxExcelHeaders();
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
        LineRowNo: Integer;
        ClassificationRowNo: Integer;
        TaxRowNo: Integer;
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
        ExcelBuffer.Validate("Column No.", ColumnNo + 100);
        ExcelBuffer.Validate("Cell Value as Text", ColumnName);
        ExcelBuffer.Insert();
    end;

    local procedure AddClassificationHeaderColumn(ColumnNo: Integer; ColumnName: Text)
    begin
        ExcelBuffer.Init();
        ExcelBuffer.Validate("Row No.", ClassificationRowNo);
        ExcelBuffer.Validate("Column No.", ColumnNo + 200);
        ExcelBuffer.Validate("Cell Value as Text", ColumnName);
        ExcelBuffer.Insert();
    end;

    local procedure AddTaxHeaderColumn(ColumnNo: Integer; ColumnName: Text)
    begin
        ExcelBuffer.Init();
        ExcelBuffer.Validate("Row No.", TaxRowNo);
        ExcelBuffer.Validate("Column No.", ColumnNo + 300);
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

        if Column in [2, 10, 19, 21, 27, 33, 35, 49] then
            ExcelBuffer.Validate("Cell Type", ExcelBuffer."Cell Type"::Text);

        ExcelBuffer.Validate("Cell Value as Text", Format(Value, 0, 9));
        ExcelBuffer.Insert();
    end;

    local procedure AddLineExcelColumn(Row: Integer; Column: Integer; Value: Variant)
    begin
        if (not IncludeAllFields) and (Format(Value) = '') then
            exit;

        if ExcelBuffer.Get(Row, Column + 100) then
            ExcelBuffer.Delete();

        ExcelBuffer.Init();
        ExcelBuffer.Validate("Row No.", Row);
        ExcelBuffer.Validate("Column No.", Column + 100);

        if Column in [1, 2, 3, 7, 11, 12] then
            ExcelBuffer.Validate("Cell Type", ExcelBuffer."Cell Type"::Text);

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

        if ExcelBuffer.Get(Row, Column + 200) then
            ExcelBuffer.Delete();

        ExcelBuffer.Init();
        ExcelBuffer.Validate("Row No.", Row);
        ExcelBuffer.Validate("Column No.", Column + 200);
        ExcelBuffer.Validate("Cell Type", ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.Validate("Cell Value as Text", Format(Value, 0, 9));

        if not ExcelBuffer.Insert() then
            ExcelBuffer.Modify();
    end;

    local procedure AddTaxExcelColumn(Row: Integer; Column: Integer; Value: Variant)
    begin
        if (not IncludeAllFields) and (Format(Value) = '') then
            exit;

        if ExcelBuffer.Get(Row, Column + 300) then
            ExcelBuffer.Delete();

        ExcelBuffer.Init();
        ExcelBuffer.Validate("Row No.", Row);
        ExcelBuffer.Validate("Column No.", Column + 300);

        if Column in [4, 5, 6, 8, 10] then
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
        LineRowCounter: Integer;
        ClassificationRowCounter: Integer;
        TaxRowCounter: Integer;
        TaxAmount: Decimal;
        PerUnitAmount: Decimal;
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
            ExcelBuffer.DeleteAll();
            LineRowCounter := 1;
            InitializeLineExcelHeaders();

            TempSalesInvHeader.CopyFilters(SalesInvHeader);
            if TempSalesInvHeader.FindSet() then
                repeat
                    TempSalesInvLine.Reset();
                    TempSalesInvLine.SetRange("Document No.", TempSalesInvHeader."No.");
                    if TempSalesInvLine.FindSet() then
                        repeat
                            LineRowCounter += 1;

                            AddLineExcelColumn(LineRowCounter, 1, TempSalesInvHeader."No.");
                            AddLineExcelColumn(LineRowCounter, 2, TempSalesInvLine."Line No.");
                            AddLineExcelColumn(LineRowCounter, 3, TempSalesInvLine."e-Invoice Classification");
                            AddLineExcelColumn(LineRowCounter, 4, TempSalesInvLine.Description);
                            AddLineExcelColumn(LineRowCounter, 5, TempSalesInvLine."Unit Price");
                            AddLineExcelColumn(LineRowCounter, 6, TempSalesInvLine.Quantity);
                            AddLineExcelColumn(LineRowCounter, 7, TempSalesInvLine."e-Invoice UOM");
                            AddLineExcelColumn(LineRowCounter, 8, TempSalesInvLine."Line Amount");
                            AddLineExcelColumn(LineRowCounter, 9, TempSalesInvLine."Amount Including VAT" - TempSalesInvLine.Amount);
                            AddLineExcelColumn(LineRowNo, 10, GetLineAmountExclVAT(SalesInvLine));
                            AddLineExcelColumn(LineRowCounter, 11, '');
                            AddLineExcelColumn(LineRowCounter, 12, '');
                        until TempSalesInvLine.Next() = 0;
                until TempSalesInvHeader.Next() = 0;

            ExcelBuffer.WriteSheet('DocumentLineItems', CompanyName, UserId);
        end;

        // Process third sheet (LineItemsAddClassification) if we have line items
        if ClassificationRowNo > 1 then begin
            ExcelBuffer.DeleteAll();
            ClassificationRowCounter := 1;
            InitializeClassificationExcelHeaders();

            TempSalesInvHeader.CopyFilters(SalesInvHeader);
            if TempSalesInvHeader.FindSet() then
                repeat
                    TempSalesInvLine.Reset();
                    TempSalesInvLine.SetRange("Document No.", TempSalesInvHeader."No.");
                    if TempSalesInvLine.FindSet() then
                        repeat
                            ClassificationRowCounter += 1;

                            AddClassificationExcelColumn(ClassificationRowCounter, 1, TempSalesInvHeader."No.");
                            AddClassificationExcelColumn(ClassificationRowCounter, 2, TempSalesInvLine."Line No.");
                            AddClassificationExcelColumn(ClassificationRowCounter, 3, TempSalesInvLine."e-Invoice Classification");
                        until TempSalesInvLine.Next() = 0;
                until TempSalesInvHeader.Next() = 0;

            ExcelBuffer.WriteSheet('LineItemsAddClassification', CompanyName, UserId);
        end;

        // Process fourth sheet (LineItemTaxes) if we have line items
        if TaxRowNo > 1 then begin
            ExcelBuffer.DeleteAll();
            TaxRowCounter := 1;
            InitializeTaxExcelHeaders();

            TempSalesInvHeader.CopyFilters(SalesInvHeader);
            if TempSalesInvHeader.FindSet() then
                repeat
                    TempSalesInvLine.Reset();
                    TempSalesInvLine.SetRange("Document No.", TempSalesInvHeader."No.");
                    TempSalesInvLine.SetFilter("VAT %", '<>%1', 0);
                    if TempSalesInvLine.FindSet() then
                        repeat
                            TaxRowCounter += 1;

                            TaxAmount := TempSalesInvLine."Amount Including VAT" - TempSalesInvLine.Amount;
                            PerUnitAmount := (TempSalesInvLine.Quantity <> 0) ? TaxAmount / TempSalesInvLine.Quantity : 0;

                            AddTaxExcelColumn(TaxRowCounter, 1, TempSalesInvHeader."No.");
                            AddTaxExcelColumn(TaxRowCounter, 2, TempSalesInvLine."Line No.");
                            AddTaxExcelColumn(TaxRowCounter, 3, 'SST');
                            AddTaxExcelColumn(TaxRowCounter, 4, TempSalesInvLine."VAT %");
                            AddTaxExcelColumn(TaxRowCounter, 5, TaxAmount);
                            AddTaxExcelColumn(TaxRowCounter, 6, PerUnitAmount);
                            AddTaxExcelColumn(TaxRowCounter, 7, TempSalesInvLine."Unit of Measure Code");
                            AddTaxExcelColumn(TaxRowCounter, 8, 0);
                            AddTaxExcelColumn(TaxRowCounter, 9, '');
                            AddTaxExcelColumn(TaxRowCounter, 10, TempSalesInvLine.Amount);
                        until TempSalesInvLine.Next() = 0;
                until TempSalesInvHeader.Next() = 0;

            ExcelBuffer.WriteSheet('LineItemTaxes', CompanyName, UserId);
        end;

        ExcelBuffer.CloseBook();
        ExcelBuffer.SetFriendlyFilename(FileName);
        ExcelBuffer.OpenExcel();
    end;

    trigger OnPreReport()
    begin
        TotalTaxAmount := 0;
        TotalDiscountAmount := 0;
        TotalExcludingTax := 0;
        TotalIncludingTax := 0;
        LineRowNo := 1;
        ClassificationRowNo := 1;
        TaxRowNo := 1;
    end;

    local procedure GetLineAmountExclVAT(SalesInvLine: Record "Sales Invoice Line"): Decimal
    begin
        // Simply return the Amount field from the passed record
        exit(SalesInvLine.Amount);
    end;
}