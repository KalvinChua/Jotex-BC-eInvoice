pageextension 50321 "Posted Sales Invoices Ext" extends "Posted Sales Invoices"
{
    actions
    {
        addlast(processing)
        {
            action(ExportToExcel)
            {
                Caption = 'Export to Excel';
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Image = ExportToExcel;
                ToolTip = 'Export selected sales invoices to Excel';

                trigger OnAction()
                begin
                    ExportPostedSalesInvoices(Rec);
                end;
            }
        }
    }

    local procedure ExportPostedSalesInvoices(var SalesInvoiceHeader: Record "Sales Invoice Header")
    var
        TempExcelBuffer: Record "Excel Buffer" temporary;
        SalesInvoiceLine: Record "Sales Invoice Line";
        Window: Dialog;
        Counter: Integer;
        TotalCount: Integer;
        ExcelFileName: Text;
        ProgressLbl: Label 'Exporting invoices #1###### of #2######';
    begin
        // Set filters and count records
        SalesInvoiceHeader.CopyFilters(Rec);
        TotalCount := SalesInvoiceHeader.Count();

        // Initialize progress window
        Window.Open(ProgressLbl);
        Window.Update(1, 0);
        Window.Update(2, TotalCount);

        // Prepare Excel file name with timestamp
        ExcelFileName := 'SalesInvoices_' + Format(Today, 0, '<Year4><Month,2><Day,2>') + '_' +
                         Format(Time, 0, '<Hours24,2><Filler Character,0><Minutes,2><Seconds,2>') + '.xlsx';

        // Initialize Excel buffer
        TempExcelBuffer.Reset();
        TempExcelBuffer.DeleteAll();

        // Process records
        if SalesInvoiceHeader.FindSet() then
            repeat
                Counter += 1;
                if Counter mod 50 = 0 then begin
                    Window.Update(1, Counter);
                    Commit();
                end;

                // Add invoice header section
                AddInvoiceSectionToExcel(TempExcelBuffer, SalesInvoiceHeader);

                // Add invoice lines
                SalesInvoiceLine.SetRange("Document No.", SalesInvoiceHeader."No.");
                if SalesInvoiceLine.FindSet() then
                    repeat
                        AddInvoiceLineToExcel(TempExcelBuffer, SalesInvoiceLine);
                    until SalesInvoiceLine.Next() = 0;

                // Add separator between invoices
                TempExcelBuffer.NewRow();
                TempExcelBuffer.NewRow();
            until SalesInvoiceHeader.Next() = 0;

        Window.Close();

        // Generate and open Excel file
        GenerateExcelFile(TempExcelBuffer, ExcelFileName);
    end;

    local procedure AddInvoiceSectionToExcel(var TempExcelBuffer: Record "Excel Buffer"; SalesInvoiceHeader: Record "Sales Invoice Header")
    begin
        // Invoice header
        TempExcelBuffer.NewRow();
        TempExcelBuffer.AddColumn('Invoice No.:', false, '', true, false, false, '', TempExcelBuffer."Cell Type"::Text);
        TempExcelBuffer.AddColumn(SalesInvoiceHeader."No.", false, '', false, false, false, '', TempExcelBuffer."Cell Type"::Text);

        TempExcelBuffer.NewRow();
        TempExcelBuffer.AddColumn('Posting Date:', false, '', true, false, false, '', TempExcelBuffer."Cell Type"::Text);
        TempExcelBuffer.AddColumn(SalesInvoiceHeader."Posting Date", false, '', false, false, false, '', TempExcelBuffer."Cell Type"::Date);

        TempExcelBuffer.NewRow();
        TempExcelBuffer.AddColumn('Customer:', false, '', true, false, false, '', TempExcelBuffer."Cell Type"::Text);
        TempExcelBuffer.AddColumn(SalesInvoiceHeader."Sell-to Customer No." + ' - ' + SalesInvoiceHeader."Sell-to Customer Name",
                                false, '', false, false, false, '', TempExcelBuffer."Cell Type"::Text);

        TempExcelBuffer.NewRow();
        TempExcelBuffer.AddColumn('Amount:', false, '', true, false, false, '', TempExcelBuffer."Cell Type"::Text);
        TempExcelBuffer.AddColumn(SalesInvoiceHeader.Amount, false, '', false, false, false, '', TempExcelBuffer."Cell Type"::Number);

        // Line items header
        TempExcelBuffer.NewRow();
        TempExcelBuffer.NewRow();
        TempExcelBuffer.AddColumn('LINE ITEMS', false, '', true, false, false, '', TempExcelBuffer."Cell Type"::Text);

        TempExcelBuffer.NewRow();
        AddExcelHeader(TempExcelBuffer, 'Line No.');
        AddExcelHeader(TempExcelBuffer, 'Type');
        AddExcelHeader(TempExcelBuffer, 'No.');
        AddExcelHeader(TempExcelBuffer, 'Description');
        AddExcelHeader(TempExcelBuffer, 'Quantity');
        AddExcelHeader(TempExcelBuffer, 'Unit Price');
        AddExcelHeader(TempExcelBuffer, 'Line Amount');
    end;

    local procedure AddExcelHeader(var TempExcelBuffer: Record "Excel Buffer"; HeaderText: Text)
    begin
        TempExcelBuffer.AddColumn(
            HeaderText, false, '', true, false, false,
            '', TempExcelBuffer."Cell Type"::Text);
    end;

    local procedure AddInvoiceLineToExcel(var TempExcelBuffer: Record "Excel Buffer"; SalesInvoiceLine: Record "Sales Invoice Line")
    begin
        TempExcelBuffer.NewRow();
        TempExcelBuffer.AddColumn(SalesInvoiceLine."Line No.", false, '', false, false, false, '', TempExcelBuffer."Cell Type"::Text);
        TempExcelBuffer.AddColumn(Format(SalesInvoiceLine.Type), false, '', false, false, false, '', TempExcelBuffer."Cell Type"::Text);
        TempExcelBuffer.AddColumn(SalesInvoiceLine."No.", false, '', false, false, false, '', TempExcelBuffer."Cell Type"::Text);
        TempExcelBuffer.AddColumn(SalesInvoiceLine.Description, false, '', false, false, false, '', TempExcelBuffer."Cell Type"::Text);
        TempExcelBuffer.AddColumn(SalesInvoiceLine.Quantity, false, '', false, false, false, '', TempExcelBuffer."Cell Type"::Number);
        TempExcelBuffer.AddColumn(SalesInvoiceLine."Unit Price", false, '', false, false, false, '', TempExcelBuffer."Cell Type"::Number);
        TempExcelBuffer.AddColumn(SalesInvoiceLine."Line Amount", false, '', false, false, false, '', TempExcelBuffer."Cell Type"::Number);
    end;

    local procedure GenerateExcelFile(var TempExcelBuffer: Record "Excel Buffer"; FileName: Text)
    begin
        TempExcelBuffer.CreateNewBook('Sales Invoices');
        TempExcelBuffer.WriteSheet('Sales Invoices', CompanyName, UserId);
        TempExcelBuffer.CloseBook();
        TempExcelBuffer.SetFriendlyFilename(FileName);
        TempExcelBuffer.OpenExcel();
    end;
}