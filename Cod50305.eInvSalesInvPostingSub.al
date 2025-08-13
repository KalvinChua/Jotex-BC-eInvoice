codeunit 50305 "eInv Posting Subscribers"
{
    Permissions = tabledata "Sales Invoice Header" = RIMD,
                  tabledata "Sales Cr.Memo Header" = RIMD,
                  tabledata "eInvoice Submission Log" = RIMD,
                  tabledata "Company Information" = R;

    // Event to copy header fields after posting is complete AND auto-submit to LHDN
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnAfterPostSalesDoc', '', false, false)]
    local procedure CopyEInvoiceHeaderFieldsAndAutoSubmit(
        var SalesHeader: Record "Sales Header";
        var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line";
        SalesShptHdrNo: Code[20];
        RetRcpHdrNo: Code[20];
        SalesInvHdrNo: Code[20];
        SalesCrMemoHdrNo: Code[20])
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        Customer: Record Customer;
        eInvoiceJSONGenerator: Codeunit 50302;
        TelemetryDimensions: Dictionary of [Text, Text];
        CompanyInfo: Record "Company Information";
        LhdnResponse: Text;
        CustomerRequiresEInvoice: Boolean;
    begin
        // Only process for JOTEX SDN BHD
        if not CompanyInfo.Get() or (CompanyInfo.Name <> 'JOTEX SDN BHD') then
            exit;

        // Skip Sales Orders - they are handled by dedicated codeunit
        if SalesHeader."Document Type" = SalesHeader."Document Type"::Order then
            exit;

        // Process Invoices
        if SalesInvHdrNo <> '' then
            ProcessPostedInvoice(SalesHeader, SalesInvHdrNo, CustomerRequiresEInvoice, LhdnResponse);

        // Process Credit Memos
        if SalesCrMemoHdrNo <> '' then
            ProcessPostedCreditMemo(SalesHeader, SalesCrMemoHdrNo);
    end;

    local procedure NotifyAutoSubmission(DocumentKind: Text; DocNo: Code[20]; Success: Boolean; RawResponse: Text)
    var
        Notif: Notification;
        Msg: Text;
        Inline: Text;
    begin
        if Success then begin
            Inline := FormatInlineSummary(RawResponse);
            Msg := StrSubstNo('LHDN submission successful for %1 %2. %3', DocumentKind, DocNo, Inline);
        end else begin
            Msg := StrSubstNo('LHDN submission failed for %1 %2. Response: %3', DocumentKind, DocNo, CopyStr(RawResponse, 1, 250));
        end;

        Notif.Scope := NotificationScope::LocalScope;
        Notif.Message(Msg);
        Notif.Send();
    end;

    local procedure FormatInlineSummary(RawResponse: Text): Text
    var
        ResponseJson: JsonObject;
        JsonToken: JsonToken;
        AcceptedArray: JsonArray;
        DocumentJson: JsonObject;
        SubmissionUid: Text;
        AcceptedCount: Integer;
        CodeNumber: Text;
        Uuid: Text;
        Summary: Text;
    begin
        if not ResponseJson.ReadFrom(RawResponse) then
            exit(StrSubstNo('Raw Response: %1', CopyStr(RawResponse, 1, 200)));

        if ResponseJson.Get('submissionUid', JsonToken) then
            SubmissionUid := CopyStr(Format(JsonToken.AsValue()), 1, 100);

        if ResponseJson.Get('acceptedDocuments', JsonToken) and JsonToken.IsArray() then begin
            AcceptedArray := JsonToken.AsArray();
            AcceptedCount := AcceptedArray.Count();
            if AcceptedCount > 0 then begin
                AcceptedArray.Get(0, JsonToken);
                if JsonToken.IsObject() then begin
                    DocumentJson := JsonToken.AsObject();
                    if DocumentJson.Get('invoiceCodeNumber', JsonToken) then
                        CodeNumber := CopyStr(Format(JsonToken.AsValue()), 1, 50);
                    if DocumentJson.Get('uuid', JsonToken) then
                        Uuid := CopyStr(Format(JsonToken.AsValue()), 1, 100);
                end;
            end;
        end;

        Summary := StrSubstNo('Submission ID: %1 | Accepted Documents: %2', SubmissionUid, Format(AcceptedCount));
        if CodeNumber <> '' then
            Summary += StrSubstNo(' | Document: %1', CodeNumber);
        if Uuid <> '' then
            Summary += StrSubstNo(' | UUID: %1', Uuid);

        exit(Summary);
    end;

    local procedure ProcessPostedInvoice(SalesHeader: Record "Sales Header"; SalesInvHdrNo: Code[20]; var CustomerRequiresEInvoice: Boolean; var LhdnResponse: Text)
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        Customer: Record Customer;
        eInvoiceJSONGenerator: Codeunit 50302;
        TelemetryDimensions: Dictionary of [Text, Text];
    begin
        // Find the posted invoice and update fields
        if SalesInvoiceHeader.Get(SalesInvHdrNo) then begin
            SalesInvoiceHeader."eInvoice Document Type" := SalesHeader."eInvoice Document Type";
            SalesInvoiceHeader."eInvoice Payment Mode" := SalesHeader."eInvoice Payment Mode";
            SalesInvoiceHeader."eInvoice Currency Code" := SalesHeader."eInvoice Currency Code";
            SalesInvoiceHeader."eInvoice Version Code" := SalesHeader."eInvoice Version Code";

            // Force the modification without commit (commit will be handled by the posting process)
            if not SalesInvoiceHeader.Modify(true) then begin
                TelemetryDimensions.Add('DocumentNo', SalesInvHdrNo);
                Session.LogMessage('0000EIV', 'Failed to update e-Invoice fields for posted invoice',
                    Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                    TelemetryDimensions);
            end;

            // Check if customer requires e-Invoice for auto-submission
            CustomerRequiresEInvoice := Customer.Get(SalesInvoiceHeader."Sell-to Customer No.") and Customer."Requires e-Invoice";

            // Auto-submit to LHDN if customer requires e-Invoice
            if CustomerRequiresEInvoice then begin
                // Wait a moment to ensure all data is committed
                Sleep(2000);

                // Suppress modal popups from generator and use a non-blocking notification
                eInvoiceJSONGenerator.SetSuppressUserDialogs(true);
                if eInvoiceJSONGenerator.GetSignedInvoiceAndSubmitToLHDN(SalesInvoiceHeader, LhdnResponse) then begin
                    // Success - log the successful submission
                    Clear(TelemetryDimensions);
                    TelemetryDimensions.Add('InvoiceNo', SalesInvHdrNo);
                    TelemetryDimensions.Add('CustomerNo', SalesInvoiceHeader."Sell-to Customer No.");
                    Session.LogMessage('0000EIV01', 'Automatic e-Invoice submission successful',
                        Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                        TelemetryDimensions);

                    NotifyAutoSubmission('Invoice', SalesInvHdrNo, true, LhdnResponse);
                end else begin
                    // Failure - log the error but don't stop the posting process
                    Clear(TelemetryDimensions);
                    TelemetryDimensions.Add('InvoiceNo', SalesInvHdrNo);
                    TelemetryDimensions.Add('Error', CopyStr(LhdnResponse, 1, 250));
                    Session.LogMessage('0000EIV02', 'Automatic e-Invoice submission failed',
                        Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                        TelemetryDimensions);

                    NotifyAutoSubmission('Invoice', SalesInvHdrNo, false, LhdnResponse);
                end;
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Copy Document Mgt.", 'OnBeforeCopySalesHeaderFromPostedInvoice', '', false, false)]
    local procedure PreventQrUrlCopy(var ToSalesHeader: Record "Sales Header")
    begin
        // Clear any potential URL text mapped into our Code[20] fields during copy
        if StrLen(ToSalesHeader."eInvoice Payment Mode") > MaxStrLen(ToSalesHeader."eInvoice Payment Mode") then
            Clear(ToSalesHeader."eInvoice Payment Mode");
        if StrLen(ToSalesHeader."eInvoice Currency Code") > MaxStrLen(ToSalesHeader."eInvoice Currency Code") then
            Clear(ToSalesHeader."eInvoice Currency Code");
        if StrLen(ToSalesHeader."eInvoice Version Code") > MaxStrLen(ToSalesHeader."eInvoice Version Code") then
            ToSalesHeader."eInvoice Version Code" := '1.1';
    end;

    local procedure ProcessPostedCreditMemo(SalesHeader: Record "Sales Header"; SalesCrMemoHdrNo: Code[20])
    var
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        Customer: Record Customer;
        eInvoiceJSONGenerator: Codeunit 50302;
        TelemetryDimensions: Dictionary of [Text, Text];
        CustomerRequiresEInvoice: Boolean;
        LhdnResponse: Text;
    begin
        // Find the posted credit memo and update fields
        if SalesCrMemoHeader.Get(SalesCrMemoHdrNo) then begin
            SalesCrMemoHeader."eInvoice Document Type" := SalesHeader."eInvoice Document Type";
            SalesCrMemoHeader."eInvoice Payment Mode" := SalesHeader."eInvoice Payment Mode";
            SalesCrMemoHeader."eInvoice Currency Code" := SalesHeader."eInvoice Currency Code";
            SalesCrMemoHeader."eInvoice Version Code" := SalesHeader."eInvoice Version Code";

            // Force the modification without commit (commit will be handled by the posting process)
            if not SalesCrMemoHeader.Modify(true) then begin
                TelemetryDimensions.Add('DocumentNo', SalesCrMemoHdrNo);
                Session.LogMessage('0000EIV06', 'Failed to update e-Invoice fields for posted credit memo',
                    Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                    TelemetryDimensions);
            end else begin
                // Log successful update
                Clear(TelemetryDimensions);
                TelemetryDimensions.Add('CreditMemoNo', SalesCrMemoHdrNo);
                TelemetryDimensions.Add('CustomerNo', SalesCrMemoHeader."Sell-to Customer No.");
                Session.LogMessage('0000EIV07', 'Successfully updated e-Invoice fields for posted credit memo',
                    Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                    TelemetryDimensions);
            end;

            // ENHANCED: Check if customer requires e-Invoice for auto-submission (same as invoices)
            CustomerRequiresEInvoice := Customer.Get(SalesCrMemoHeader."Sell-to Customer No.") and Customer."Requires e-Invoice";

            // Auto-submit to LHDN if customer requires e-Invoice
            if CustomerRequiresEInvoice then begin
                // Wait a moment to ensure all data is committed
                Sleep(2000);

                // Suppress modal popups from generator and use a non-blocking notification
                eInvoiceJSONGenerator.SetSuppressUserDialogs(true);
                if eInvoiceJSONGenerator.GetSignedCreditMemoAndSubmitToLHDN(SalesCrMemoHeader, LhdnResponse) then begin
                    // Success - log the successful submission
                    Clear(TelemetryDimensions);
                    TelemetryDimensions.Add('CreditMemoNo', SalesCrMemoHdrNo);
                    TelemetryDimensions.Add('CustomerNo', SalesCrMemoHeader."Sell-to Customer No.");
                    Session.LogMessage('0000EIV08', 'Automatic e-Invoice credit memo submission successful',
                        Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                        TelemetryDimensions);

                    NotifyAutoSubmission('Credit Memo', SalesCrMemoHdrNo, true, LhdnResponse);
                end else begin
                    // Failure - log the error but don't stop the posting process
                    Clear(TelemetryDimensions);
                    TelemetryDimensions.Add('CreditMemoNo', SalesCrMemoHdrNo);
                    TelemetryDimensions.Add('Error', CopyStr(LhdnResponse, 1, 250));
                    Session.LogMessage('0000EIV09', 'Automatic e-Invoice credit memo submission failed',
                        Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                        TelemetryDimensions);

                    NotifyAutoSubmission('Credit Memo', SalesCrMemoHdrNo, false, LhdnResponse);
                end;
            end;
        end;
    end;

    // Event to copy line fields during line insertion
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnBeforeSalesInvLineInsert', '', false, false)]
    local procedure CopyEInvoiceLineFields(
        var SalesInvLine: Record "Sales Invoice Line";
        SalesLine: Record "Sales Line";
        SalesInvHeader: Record "Sales Invoice Header";
        CommitIsSuppressed: Boolean)
    var
        CompanyInfo: Record "Company Information";
    begin
        // Only process for JOTEX SDN BHD
        if not CompanyInfo.Get() or (CompanyInfo.Name <> 'JOTEX SDN BHD') then
            exit;

        // Only copy fields for item and resource lines
        if SalesLine.Type in [SalesLine.Type::Item, SalesLine.Type::Resource] then begin
            SalesInvLine."e-Invoice Classification" := SalesLine."e-Invoice Classification";
            SalesInvLine."e-Invoice UOM" := SalesLine."e-Invoice UOM";
            SalesInvLine."e-Invoice Tax Type" := SalesLine."e-Invoice Tax Type";
        end;
    end;

    // Event to copy credit memo line fields during line insertion
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnBeforeSalesCrMemoLineInsert', '', false, false)]
    local procedure CopyEInvoiceCreditMemoLineFields(
        var SalesCrMemoLine: Record "Sales Cr.Memo Line";
        SalesLine: Record "Sales Line";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        CommitIsSuppressed: Boolean)
    var
        CompanyInfo: Record "Company Information";
        TelemetryDimensions: Dictionary of [Text, Text];
    begin
        // Only process for JOTEX SDN BHD
        if not CompanyInfo.Get() or (CompanyInfo.Name <> 'JOTEX SDN BHD') then
            exit;

        // Copy e-Invoice fields for ALL line types to ensure nothing is lost
        SalesCrMemoLine."e-Invoice Classification" := SalesLine."e-Invoice Classification";
        SalesCrMemoLine."e-Invoice UOM" := SalesLine."e-Invoice UOM";
        SalesCrMemoLine."e-Invoice Tax Type" := SalesLine."e-Invoice Tax Type";

        // Log the copying process for debugging
        Clear(TelemetryDimensions);
        TelemetryDimensions.Add('CreditMemoNo', SalesCrMemoHeader."No.");
        TelemetryDimensions.Add('LineNo', Format(SalesCrMemoLine."Line No."));
        TelemetryDimensions.Add('Description', CopyStr(SalesCrMemoLine.Description, 1, 50));
        TelemetryDimensions.Add('Type', Format(SalesCrMemoLine.Type));
        TelemetryDimensions.Add('Quantity', Format(SalesCrMemoLine.Quantity));
        TelemetryDimensions.Add('UnitPrice', Format(SalesCrMemoLine."Unit Price"));
        TelemetryDimensions.Add('Classification', SalesCrMemoLine."e-Invoice Classification");
        TelemetryDimensions.Add('UOM', SalesCrMemoLine."e-Invoice UOM");
        TelemetryDimensions.Add('TaxType', SalesCrMemoLine."e-Invoice Tax Type");
        Session.LogMessage('0000EIV03', 'Credit memo line copying completed',
            Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
            TelemetryDimensions);
    end;

    // Event to ensure credit memo line fields are properly copied after insertion
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnAfterSalesCrMemoLineInsert', '', false, false)]
    local procedure OnAfterSalesCrMemoLineInsert(var SalesCrMemoLine: Record "Sales Cr.Memo Line"; SalesLine: Record "Sales Line"; SalesCrMemoHeader: Record "Sales Cr.Memo Header")
    var
        CompanyInfo: Record "Company Information";
        TelemetryDimensions: Dictionary of [Text, Text];
        Modified: Boolean;
    begin
        // Only process for JOTEX SDN BHD
        if not CompanyInfo.Get() or (CompanyInfo.Name <> 'JOTEX SDN BHD') then
            exit;

        Modified := false;

        // Ensure all e-Invoice fields are copied for ALL line types
        if SalesCrMemoLine."e-Invoice Classification" <> SalesLine."e-Invoice Classification" then begin
            SalesCrMemoLine."e-Invoice Classification" := SalesLine."e-Invoice Classification";
            Modified := true;
        end;
        if SalesCrMemoLine."e-Invoice UOM" <> SalesLine."e-Invoice UOM" then begin
            SalesCrMemoLine."e-Invoice UOM" := SalesLine."e-Invoice UOM";
            Modified := true;
        end;
        if SalesCrMemoLine."e-Invoice Tax Type" <> SalesLine."e-Invoice Tax Type" then begin
            SalesCrMemoLine."e-Invoice Tax Type" := SalesLine."e-Invoice Tax Type";
            Modified := true;
        end;

        // Save the changes if any were made
        if Modified then begin
            if not SalesCrMemoLine.Modify(true) then begin
                Clear(TelemetryDimensions);
                TelemetryDimensions.Add('CreditMemoNo', SalesCrMemoHeader."No.");
                TelemetryDimensions.Add('LineNo', Format(SalesCrMemoLine."Line No."));
                TelemetryDimensions.Add('Error', 'Failed to modify credit memo line');
                Session.LogMessage('0000EIV04', 'Failed to modify credit memo line after insertion',
                    Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                    TelemetryDimensions);
            end;
        end;

        // Log the copying process for debugging
        Clear(TelemetryDimensions);
        TelemetryDimensions.Add('CreditMemoNo', SalesCrMemoHeader."No.");
        TelemetryDimensions.Add('LineNo', Format(SalesCrMemoLine."Line No."));
        TelemetryDimensions.Add('Description', CopyStr(SalesCrMemoLine.Description, 1, 50));
        TelemetryDimensions.Add('Type', Format(SalesCrMemoLine.Type));
        TelemetryDimensions.Add('Quantity', Format(SalesCrMemoLine.Quantity));
        TelemetryDimensions.Add('UnitPrice', Format(SalesCrMemoLine."Unit Price"));
        TelemetryDimensions.Add('Classification', SalesCrMemoLine."e-Invoice Classification");
        TelemetryDimensions.Add('UOM', SalesCrMemoLine."e-Invoice UOM");
        TelemetryDimensions.Add('TaxType', SalesCrMemoLine."e-Invoice Tax Type");
        TelemetryDimensions.Add('Modified', Format(Modified));
        Session.LogMessage('0000EIV05', 'Credit memo line post-insertion processing completed',
            Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
            TelemetryDimensions);
    end;

    // Event to verify fields before posting
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnBeforePostSalesDoc', '', false, false)]
    local procedure VerifyEInvoiceFieldsBeforePosting(
        var SalesHeader: Record "Sales Header";
        var HideProgressWindow: Boolean;
        var IsHandled: Boolean)
    var
        Customer: Record Customer;
        SalesLine: Record "Sales Line";
        MissingFieldsErr: Label 'Missing e-Invoice fields for %1:\%2', Comment = '%1=Document No.,%2=Missing fields';
        MissingFields: Text;
        CompanyInfo: Record "Company Information";
    begin
        // Only process for JOTEX SDN BHD
        if not CompanyInfo.Get() or (CompanyInfo.Name <> 'JOTEX SDN BHD') then
            exit;

        // Skip Sales Orders - they are handled by dedicated codeunit
        if SalesHeader."Document Type" = SalesHeader."Document Type"::Order then
            exit;

        if IsHandled then
            exit;

        // Check customer requirements
        if Customer.Get(SalesHeader."Sell-to Customer No.") and Customer."Requires e-Invoice" then begin
            if SalesHeader."eInvoice Document Type" = '' then
                MissingFields := MissingFields + '\- Document Type';

            if SalesHeader."eInvoice Currency Code" = '' then
                MissingFields := MissingFields + '\- Currency Code';
        end;

        // Check lines for invoices and credit memos
        if SalesHeader."Document Type" in [SalesHeader."Document Type"::Invoice, SalesHeader."Document Type"::"Credit Memo"] then begin
            SalesLine.SetRange("Document Type", SalesHeader."Document Type");
            SalesLine.SetRange("Document No.", SalesHeader."No.");
            SalesLine.SetFilter(Type, '<>%1', SalesLine.Type::" ");
            if SalesLine.FindSet() then
                repeat
                    if SalesLine."e-Invoice Classification" = '' then
                        MissingFields := MissingFields + '\- Line ' + Format(SalesLine."Line No.") + ' Classification';

                    if SalesLine."e-Invoice UOM" = '' then
                        MissingFields := MissingFields + '\- Line ' + Format(SalesLine."Line No.") + ' UOM';

                    if SalesLine."e-Invoice Tax Type" = '' then
                        MissingFields := MissingFields + '\- Line ' + Format(SalesLine."Line No.") + ' Tax Type';
                until SalesLine.Next() = 0;
        end;

        if MissingFields <> '' then
            Error(MissingFieldsErr, SalesHeader."No.", MissingFields);
    end;

    // Note: Credit memo processing is now handled in the OnAfterPostSalesDoc event subscriber
    // This ensures proper field copying and avoids conflicts during the posting process

    // Test procedure to debug credit memo posting issues
    procedure TestCreditMemoLineCopying(SalesCrMemoHeaderNo: Code[20])
    var
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        SalesCrMemoLine: Record "Sales Cr.Memo Line";
        SalesLine: Record "Sales Line";
        SalesHeader: Record "Sales Header";
        CompanyInfo: Record "Company Information";
        TelemetryDimensions: Dictionary of [Text, Text];
        LineCount: Integer;
        MissingFieldsCount: Integer;
    begin
        // Only process for JOTEX SDN BHD
        if not CompanyInfo.Get() or (CompanyInfo.Name <> 'JOTEX SDN BHD') then
            exit;

        if not SalesCrMemoHeader.Get(SalesCrMemoHeaderNo) then
            exit;

        // Find the original sales header
        if not SalesHeader.Get(SalesHeader."Document Type"::"Credit Memo", SalesCrMemoHeader."Pre-Assigned No.") then
            exit;

        LineCount := 0;
        MissingFieldsCount := 0;

        // Check posted credit memo lines
        SalesCrMemoLine.SetRange("Document No.", SalesCrMemoHeaderNo);
        if SalesCrMemoLine.FindSet() then
            repeat
                LineCount += 1;

                // Check if e-Invoice fields are missing
                if SalesCrMemoLine."e-Invoice Classification" = '' then
                    MissingFieldsCount += 1;
                if SalesCrMemoLine."e-Invoice UOM" = '' then
                    MissingFieldsCount += 1;
                if SalesCrMemoLine."e-Invoice Tax Type" = '' then
                    MissingFieldsCount += 1;

                // Log each line for debugging
                Clear(TelemetryDimensions);
                TelemetryDimensions.Add('CreditMemoNo', SalesCrMemoHeaderNo);
                TelemetryDimensions.Add('LineNo', Format(SalesCrMemoLine."Line No."));
                TelemetryDimensions.Add('Type', Format(SalesCrMemoLine.Type));
                TelemetryDimensions.Add('Description', CopyStr(SalesCrMemoLine.Description, 1, 50));
                TelemetryDimensions.Add('Classification', SalesCrMemoLine."e-Invoice Classification");
                TelemetryDimensions.Add('UOM', SalesCrMemoLine."e-Invoice UOM");
                TelemetryDimensions.Add('TaxType', SalesCrMemoLine."e-Invoice Tax Type");
                Session.LogMessage('0000EIV08', 'Credit memo line debug info',
                    Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                    TelemetryDimensions);
            until SalesCrMemoLine.Next() = 0;

        // Log summary
        Clear(TelemetryDimensions);
        TelemetryDimensions.Add('CreditMemoNo', SalesCrMemoHeaderNo);
        TelemetryDimensions.Add('TotalLines', Format(LineCount));
        TelemetryDimensions.Add('MissingFields', Format(MissingFieldsCount));
        TelemetryDimensions.Add('HeaderClassification', SalesCrMemoHeader."eInvoice Document Type");
        Session.LogMessage('0000EIV09', 'Credit memo posting debug summary',
            Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
            TelemetryDimensions);

        if MissingFieldsCount > 0 then
            Message('Credit Memo %1 has %2 lines with %3 missing e-Invoice fields. Check the Event Log for details.',
                SalesCrMemoHeaderNo, LineCount, MissingFieldsCount)
        else
            Message('Credit Memo %1 has %2 lines with all e-Invoice fields properly populated.',
                SalesCrMemoHeaderNo, LineCount);
    end;

    // Procedure to cancel a submitted e-Invoice document in LHDN (API call only)
    // Following exact same pattern as successful LHDN API implementations (GetLhdnDocumentTypes, SubmitToLhdnApi)
    procedure CancelEInvoiceDocument(SalesInvoiceHeader: Record "Sales Invoice Header"; CancellationReason: Text) Success: Boolean
    var
        HttpClient: HttpClient;
        HttpRequestMessage: HttpRequestMessage;
        HttpResponseMessage: HttpResponseMessage;
        RequestHeaders: HttpHeaders;
        ContentHeaders: HttpHeaders;
        eInvoiceSetup: Record "eInvoiceSetup";
        eInvoiceHelper: Codeunit eInvoiceHelper;
        AccessToken: Text;
        ApiUrl: Text;
        RequestText: Text;
        ResponseText: Text;
        JsonObj: JsonObject;
        JsonResponse: JsonObject;
        JsonToken: JsonToken;
        TelemetryDimensions: Dictionary of [Text, Text];
        CompanyInfo: Record "Company Information";
        DocumentUUID: Text;
        SubmissionUID: Text;
        eInvoiceSubmissionLog: Record "eInvoice Submission Log";
        CorrelationId: Text;
    begin
        Success := false;

        // Only process for JOTEX SDN BHD
        if not CompanyInfo.Get() or (CompanyInfo.Name <> 'JOTEX SDN BHD') then
            exit;

        // Get setup for environment determination
        if not eInvoiceSetup.Get('SETUP') then begin
            Message('eInvoice Setup not found');
            exit;
        end;

        // Find the submission log for this invoice to get Document UUID and Submission UID
        eInvoiceSubmissionLog.SetRange("Invoice No.", SalesInvoiceHeader."No.");
        eInvoiceSubmissionLog.SetRange(Status, 'Valid');
        if not eInvoiceSubmissionLog.FindLast() then begin
            Message('No valid e-Invoice submission found for invoice %1. Only valid/accepted invoices can be cancelled.', SalesInvoiceHeader."No.");
            exit;
        end;

        DocumentUUID := eInvoiceSubmissionLog."Document UUID";
        SubmissionUID := eInvoiceSubmissionLog."Submission UID";

        if (DocumentUUID = '') or (SubmissionUID = '') then begin
            Message('Document UUID or Submission UID is missing for invoice %1. Cannot proceed with cancellation.', SalesInvoiceHeader."No.");
            exit;
        end;

        // Get access token using the helper method (same as all other LHDN API calls)
        eInvoiceHelper.InitializeHelper();
        AccessToken := eInvoiceHelper.GetAccessTokenFromSetup(eInvoiceSetup);
        if AccessToken = '' then begin
            Message('Failed to get access token for cancellation');
            exit;
        end;

        // Build API URL for cancellation (same environment pattern as SubmitToLhdnApi)
        if eInvoiceSetup.Environment = eInvoiceSetup.Environment::Preprod then
            ApiUrl := StrSubstNo('https://preprod-api.myinvois.hasil.gov.my/api/v1.0/documents/state/%1/state', DocumentUUID)
        else
            ApiUrl := StrSubstNo('https://api.myinvois.hasil.gov.my/api/v1.0/documents/state/%1/state', DocumentUUID);

        // Generate correlation ID for tracking (same as status check implementations)
        CorrelationId := CreateGuid();

        // Build request payload for cancellation according to LHDN API spec
        JsonObj.Add('status', 'cancelled');
        JsonObj.Add('reason', CancellationReason);
        JsonObj.WriteTo(RequestText);

        // Setup LHDN API request with EXACT same headers as successful implementations
        HttpRequestMessage.Method := 'PUT';
        HttpRequestMessage.SetRequestUri(ApiUrl);
        HttpRequestMessage.Content.WriteFrom(RequestText);

        // Set standard LHDN API headers as per documentation (exact pattern from SubmitToLhdnApi)
        HttpRequestMessage.Content.GetHeaders(ContentHeaders);
        ContentHeaders.Clear();
        ContentHeaders.Add('Content-Type', 'application/json');

        HttpRequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Clear();
        RequestHeaders.Add('Accept', 'application/json');
        RequestHeaders.Add('Accept-Language', 'en');
        RequestHeaders.Add('Authorization', 'Bearer ' + AccessToken);
        RequestHeaders.Add('User-Agent', 'BusinessCentral-eInvoice/2.0');
        RequestHeaders.Add('X-Correlation-ID', CorrelationId);
        RequestHeaders.Add('X-Request-Source', 'BusinessCentral-Cancellation');

        // Apply rate limiting (same as status check)
        eInvoiceHelper.ApplyRateLimiting(ApiUrl);

        // Send cancellation request using exact same pattern as successful implementations
        if HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then begin
            HttpResponseMessage.Content.ReadAs(ResponseText);

            if HttpResponseMessage.IsSuccessStatusCode then begin
                // Parse response to check cancellation status
                if JsonResponse.ReadFrom(ResponseText) then begin
                    // Log successful cancellation (no database update here)
                    TelemetryDimensions.Add('InvoiceNo', SalesInvoiceHeader."No.");
                    TelemetryDimensions.Add('DocumentUUID', DocumentUUID);
                    TelemetryDimensions.Add('Reason', CancellationReason);
                    TelemetryDimensions.Add('CorrelationId', CorrelationId);
                    Session.LogMessage('0000EIV03', 'e-Invoice document cancellation successful in LHDN',
                        Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                        TelemetryDimensions);

                    Message('e-Invoice for invoice %1 has been successfully cancelled in LHDN system.\Reason: %2\Correlation ID: %3\Note: Submission log will be updated automatically.',
                            SalesInvoiceHeader."No.", CancellationReason, CorrelationId);
                    Success := true;

                    // Try to update database using helper codeunit
                    if TryUpdateWithHelper(SalesInvoiceHeader."No.", CancellationReason) then begin
                        // Log successful database update
                        TelemetryDimensions.Add('DatabaseUpdate', 'Success');
                        Session.LogMessage('0000EIV06', 'Cancellation log updated successfully',
                            Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                            TelemetryDimensions);
                    end else begin
                        // Log database update failure but don't fail the operation
                        TelemetryDimensions.Add('DatabaseUpdate', 'Failed');
                        TelemetryDimensions.Add('LastError', GetLastErrorText());
                        Session.LogMessage('0000EIV06', 'Cancellation successful but log update failed: ' + GetLastErrorText(),
                            Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                            TelemetryDimensions);

                        Message('LHDN cancellation succeeded but failed to update local status.\Error: %1\Please use "Mark as Cancelled" action if needed.\Correlation ID: %2',
                            GetLastErrorText(), CorrelationId);
                    end;
                end;
            end else begin
                // Enhanced error handling following LHDN pattern
                TelemetryDimensions.Add('InvoiceNo', SalesInvoiceHeader."No.");
                TelemetryDimensions.Add('DocumentUUID', DocumentUUID);
                TelemetryDimensions.Add('StatusCode', Format(HttpResponseMessage.HttpStatusCode));
                TelemetryDimensions.Add('Error', CopyStr(ResponseText, 1, 250));
                TelemetryDimensions.Add('CorrelationId', CorrelationId);
                Session.LogMessage('0000EIV04', 'e-Invoice document cancellation failed',
                    Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                    TelemetryDimensions);

                // Check for rate limiting (same pattern as status check)
                if HttpResponseMessage.HttpStatusCode() = 429 then begin
                    Message('LHDN API Rate Limit Exceeded\\\Cancellation request for invoice %1 was rate limited.\Please wait a few minutes and try again.\Correlation ID: %2',
                            SalesInvoiceHeader."No.", CorrelationId);
                end else begin
                    Message('Failed to cancel e-Invoice for invoice %1.\Status Code: %2\Error: %3\Correlation ID: %4',
                            SalesInvoiceHeader."No.", HttpResponseMessage.HttpStatusCode(), CopyStr(ResponseText, 1, 200), CorrelationId);
                end;
            end;
        end else begin
            // Enhanced connection error handling
            TelemetryDimensions.Add('InvoiceNo', SalesInvoiceHeader."No.");
            TelemetryDimensions.Add('DocumentUUID', DocumentUUID);
            TelemetryDimensions.Add('CorrelationId', CorrelationId);
            TelemetryDimensions.Add('Error', GetLastErrorText());
            Session.LogMessage('0000EIV05', 'e-Invoice cancellation HTTP request failed',
                Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                TelemetryDimensions);

            Message('Failed to communicate with LHDN API for cancellation of invoice %1\Error: %2\Correlation ID: %3',
                    SalesInvoiceHeader."No.", GetLastErrorText(), CorrelationId);
        end;
    end;

    /// <summary>
    /// Schedule a background task to update cancellation status in submission log
    /// </summary>
    local procedure ScheduleCancellationLogUpdate(InvoiceNo: Code[20]; CancellationReason: Text)
    var
        ScheduledTask: Record "Scheduled Task";
        TaskId: Guid;
        TelemetryDimensions: Dictionary of [Text, Text];
    begin
        // Use a simple approach - create a message for manual refresh
        TelemetryDimensions.Add('InvoiceNo', InvoiceNo);
        TelemetryDimensions.Add('Action', 'Cancellation log update scheduled');
        Session.LogMessage('0000EIV06', 'Cancellation successful - log update pending',
            Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
            TelemetryDimensions);

        // Since task scheduler might also have context restrictions, 
        // we'll inform user to manually refresh the submission log
        Message('LHDN cancellation completed successfully.\Please refresh the submission log page to see the updated status.');
    end;

    /// <summary>
    /// Try to update cancellation status using helper codeunit
    /// </summary>
    [TryFunction]
    local procedure TryUpdateWithHelper(InvoiceNo: Code[20]; CancellationReason: Text)
    var
        CancellationHelper: Codeunit "eInvoice Cancellation Helper";
        UpdateSuccess: Boolean;
    begin
        // Clear any previous errors
        ClearLastError();

        UpdateSuccess := CancellationHelper.UpdateCancellationStatusByInvoice(InvoiceNo, CancellationReason);
        if not UpdateSuccess then
            Error('Helper codeunit returned false - check permissions and data integrity for invoice %1', InvoiceNo);
    end;

    /// <summary>
    /// Try to update cancellation status in submission log with proper error handling
    /// </summary>
    [TryFunction]
    local procedure TryUpdateCancellationStatus(var eInvoiceSubmissionLog: Record "eInvoice Submission Log"; CancellationReason: Text)
    begin
        eInvoiceSubmissionLog.Status := 'Cancelled';
        eInvoiceSubmissionLog."Cancellation Reason" := CopyStr(CancellationReason, 1, MaxStrLen(eInvoiceSubmissionLog."Cancellation Reason"));
        eInvoiceSubmissionLog."Cancellation Date" := CurrentDateTime;
        eInvoiceSubmissionLog.Modify(true);
    end;

    /// <summary>
    /// Alternative cancellation method with transaction isolation
    /// </summary>
    procedure CancelEInvoiceDocumentWithIsolation(SalesInvoiceHeader: Record "Sales Invoice Header"; CancellationReason: Text): Boolean
    var
        eInvoiceSubmissionLog: Record "eInvoice Submission Log";
    begin
        // Find the submission log first
        eInvoiceSubmissionLog.SetRange("Invoice No.", SalesInvoiceHeader."No.");
        eInvoiceSubmissionLog.SetRange(Status, 'Valid');
        if not eInvoiceSubmissionLog.FindLast() then
            exit(false);

        // Start isolated transaction for database update
        if TryPerformCancellationWithTransaction(SalesInvoiceHeader, CancellationReason, eInvoiceSubmissionLog) then
            exit(true)
        else
            exit(false);
    end;

    [TryFunction]
    local procedure TryPerformCancellationWithTransaction(SalesInvoiceHeader: Record "Sales Invoice Header"; CancellationReason: Text; var eInvoiceSubmissionLog: Record "eInvoice Submission Log")
    begin
        // Perform the actual cancellation in an isolated transaction
        if CancelEInvoiceDocument(SalesInvoiceHeader, CancellationReason) then begin
            // Commit will be handled by the calling procedure if needed
        end else
            Error('Cancellation API call failed');
    end;
}