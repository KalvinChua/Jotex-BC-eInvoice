pageextension 50319 eInvSalesReturnOrdArch extends "Sales Return Order Archive"
{
    layout
    {
        addafter("Invoice Details")
        {
            group("e-Invoice")
            {
                Caption = 'e-Invoice Details';
                Visible = IsJotexCompany;
                field("eInvoice Document Type"; Rec."eInvoice Document Type")
                {
                    ApplicationArea = Suite;
                    ToolTip = 'Specifies the e-Invoice document type as required by tax authorities';
                    Importance = Promoted;
                    Editable = false;
                    Visible = IsJotexCompany;

                    trigger OnValidate()
                    begin
                        if not IsJotexCompany then
                            exit;
                        ValidateEInvoiceDocumentType();
                        CurrPage.SaveRecord();
                    end;
                }
                field("eInvoice Payment Mode"; Rec."eInvoice Payment Mode")
                {
                    ApplicationArea = Suite;
                    ToolTip = 'Specifies the payment mode for e-Invoice purposes';
                    Importance = Additional;
                    Visible = IsJotexCompany;
                }
                field("eInvoice Currency Code"; Rec."eInvoice Currency Code")
                {
                    ApplicationArea = Suite;
                    ToolTip = 'Specifies the currency code for e-Invoice reporting';
                    Importance = Additional;
                    Visible = IsJotexCompany;
                }
                field("eInvoice Version Code"; Rec."eInvoice Version Code")
                {
                    ApplicationArea = Suite;
                    ToolTip = 'Specifies version code for e-Invoice reporting';
                    Importance = Additional;
                    Visible = IsJotexCompany;
                }
            }
        }
    }

    actions
    {
        addfirst(Processing)
        {
            action(ValidateEInvoice)
            {
                Caption = 'Validate e-Invoice';
                ApplicationArea = Suite;
                Image = CheckList;
                ToolTip = 'Verify all required e-Invoice fields are populated correctly';
                Visible = IsJotexCompany;

                trigger OnAction()
                begin
                    if not IsJotexCompany then
                        exit;
                    ValidateEInvoiceCompleteness();
                end;
            }
            action(SignAndSubmitToLHDN)
            {
                ApplicationArea = All;
                Caption = 'Sign & Submit to LHDN';
                Image = ElectronicDoc;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Submission occurs during posting. This action is disabled on archived Return Orders.';
                Visible = IsJotexCompany;
                Enabled = false;

                trigger OnAction()
                var
                    SalesCrMemoHeader: Record "Sales Cr.Memo Header";
                    eInvoiceGenerator: Codeunit "eInvoice JSON Generator";
                    LhdnResponse: Text;
                    Success: Boolean;
                begin
                    Error('Submission is handled during posting.');
                end;
            }
            action(GenerateEInvoiceJSON)
            {
                ApplicationArea = All;
                Caption = 'Generate e-Invoice JSON';
                Image = ExportFile;
                ToolTip = 'Generate e-Invoice JSON using the linked posted Credit Memo for this archived Return Order.';
                Visible = IsJotexCompany;

                trigger OnAction()
                var
                    SalesCrMemoHeader: Record "Sales Cr.Memo Header";
                    eInvoiceGenerator: Codeunit "eInvoice JSON Generator";
                    TempBlob: Codeunit "Temp Blob";
                    JsonText: Text;
                    OutStream: OutStream;
                    InStream: InStream;
                    FileName: Text;
                begin
                    if not FindLinkedCreditMemo(SalesCrMemoHeader) then
                        Error('No linked Posted Sales Credit Memo could be found for Return Order %1.', Rec."No.");

                    JsonText := eInvoiceGenerator.GenerateCreditMemoEInvoiceJson(SalesCrMemoHeader, false);
                    FileName := StrSubstNo('eInvoice_ReturnOrderArch_%1_%2.json', Rec."No.",
                        Format(CurrentDateTime, 0, '<Year4><Month,2><Day,2><Hours24,2><Minutes,2><Seconds,2>'));

                    TempBlob.CreateOutStream(OutStream);
                    OutStream.WriteText(JsonText);
                    TempBlob.CreateInStream(InStream);
                    DownloadFromStream(InStream, 'Download e-Invoice JSON', '', 'JSON files (*.json)|*.json', FileName);
                end;
            }
        }
    }

    var
        IsJotexCompany: Boolean;

    trigger OnOpenPage()
    var
        CompanyInfo: Record "Company Information";
    begin
        IsJotexCompany := CompanyInfo.Get() and (CompanyInfo.Name = 'JOTEX SDN BHD');
    end;

    local procedure ValidateEInvoiceDocumentType()
    var
        Customer: Record Customer;
    begin
        if not Customer.Get(Rec."Sell-to Customer No.") then
            exit;

        if (Rec."eInvoice Document Type" = '') and Customer."Requires e-Invoice" then
            Error('e-Invoice Document Type must be specified for this customer.');
    end;

    local procedure ValidateEInvoiceCompleteness()
    var
        Customer: Record Customer;
        SalesLine: Record "Sales Line";
        MissingFieldsErr: Label 'Missing e-Invoice fields:%1', Comment = '%1 = list of missing fields';
        MissingFields: Text;
    begin
        // Check customer requirements
        if Customer.Get(Rec."Sell-to Customer No.") and Customer."Requires e-Invoice" then begin
            if Rec."eInvoice Document Type" = '' then
                MissingFields := MissingFields + '\- Document Type';

            if Rec."eInvoice Currency Code" = '' then
                MissingFields := MissingFields + '\- Currency Code';
        end;

        // Check lines
        SalesLine.SetRange("Document Type", Rec."Document Type");
        SalesLine.SetRange("Document No.", Rec."No.");
        SalesLine.SetFilter(Type, '<>%1', SalesLine.Type::" ");
        if SalesLine.FindSet() then
            repeat
                if SalesLine."e-Invoice Classification" = '' then
                    MissingFields := MissingFields + '\- Line ' + Format(SalesLine."Line No.") + ' Classification';

                if SalesLine."e-Invoice UOM" = '' then
                    MissingFields := MissingFields + '\- Line ' + Format(SalesLine."Line No.") + ' UOM';
            until SalesLine.Next() = 0;

        if MissingFields <> '' then
            Error(MissingFieldsErr, MissingFields)
        else
            Message('All required e-Invoice fields are properly populated.');
    end;

    local procedure FindLinkedCreditMemo(var SalesCrMemoHeader: Record "Sales Cr.Memo Header"): Boolean
    begin
        SalesCrMemoHeader.Reset();
        SalesCrMemoHeader.SetRange("Return Order No.", Rec."No.");
        if SalesCrMemoHeader.FindLast() then
            exit(true);

        exit(false);
    end;
}