pageextension 50316 eInvSalesReturnOrdHeader extends "Sales Return Order"
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
                    Editable = true;
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
            action("Populate e-Invoice Fields")
            {
                ApplicationArea = All;
                Caption = 'Populate e-Invoice Fields';
                Image = Process;
                Visible = IsJotexCompany;

                trigger OnAction()
                var
                    EInvHandler: Codeunit "eInv Field Population Handler";
                begin
                    if not IsJotexCompany then
                        exit;
                    EInvHandler.CopyFieldsFromItemToSalesLines(Rec);
                end;
            }
            action(GenerateReturnJSON)
            {
                ApplicationArea = All;
                Caption = 'Generate e-Invoice JSON';
                Image = ExportFile;
                ToolTip = 'Generate e-Invoice JSON for Sales Return Order (as Credit Note)';
                Visible = IsJotexCompany;

                trigger OnAction()
                var
                    eInvoiceGenerator: Codeunit "eInvoice JSON Generator";
                    TempBlob: Codeunit "Temp Blob";
                    FileName: Text;
                    JsonText: Text;
                    OutStream: OutStream;
                    InStream: InStream;
                    SalesHeader: Record "Sales Header";
                    SalesCrMemoHeader: Record "Sales Cr.Memo Header";
                begin
                    // Convert return order to a temporary credit memo JSON using the standard credit memo generator
                    // by referencing the posted credit memo when available
                    if SalesCrMemoHeader.Get(Rec."Last Posting No.") then begin
                        JsonText := eInvoiceGenerator.GenerateCreditMemoEInvoiceJson(SalesCrMemoHeader, false);
                    end else begin
                        Error('No posted Credit Memo exists for this Return Order. Post the return first.');
                    end;

                    FileName := StrSubstNo('eInvoice_Return_%1_%2.json', Rec."No.",
                        Format(CurrentDateTime, 0, '<Year4><Month,2><Day,2><Hours24,2><Minutes,2><Seconds,2>'));
                    TempBlob.CreateOutStream(OutStream);
                    OutStream.WriteText(JsonText);
                    TempBlob.CreateInStream(InStream);
                    DownloadFromStream(InStream, 'Download e-Invoice JSON', '', 'JSON files (*.json)|*.json', FileName);
                end;
            }
            action(SignAndSubmitReturn)
            {
                ApplicationArea = All;
                Caption = 'Sign & Submit to LHDN';
                Image = ElectronicDoc;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Submission occurs automatically during posting. This action is disabled on Return Orders.';
                Visible = false;
                Enabled = false;

                trigger OnAction()
                var
                    eInvoiceGenerator: Codeunit "eInvoice JSON Generator";
                    LhdnResponse: Text;
                    SalesCrMemoHeader: Record "Sales Cr.Memo Header";
                    Success: Boolean;
                begin
                    if Rec."Last Posting No." = '' then
                        Error('This return order has not been posted yet. Post it to create a Credit Memo, then submit.');

                    if not SalesCrMemoHeader.Get(Rec."Last Posting No.") then
                        Error('Posted Credit Memo %1 not found.', Rec."Last Posting No.");

                    // Suppress popups from the generator for this flow
                    eInvoiceGenerator.SetSuppressUserDialogs(true);
                    Success := eInvoiceGenerator.GetSignedCreditMemoAndSubmitToLHDN(SalesCrMemoHeader, LhdnResponse);
                    if not Success then
                        Error('Submission failed: %1', LhdnResponse);
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
}