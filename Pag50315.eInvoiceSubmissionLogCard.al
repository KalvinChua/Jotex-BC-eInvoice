page 50315 "e-Invoice Submission Log Card"
{
    PageType = Card;
    SourceTable = "eInvoice Submission Log";
    Caption = 'e-Invoice Submission Log Entry';
    UsageCategory = None;
    ApplicationArea = All;
    Editable = false; // Read-only - system-generated log entries should not be edited by users
    InsertAllowed = false; // Prevent inserts from UI
    ModifyAllowed = false; // Prevent modifications from UI
    DeleteAllowed = false; // Use controlled delete actions instead

    layout
    {
        area(content)
        {
            group(General)
            {
                Caption = 'General';
                field("Entry No."; Rec."Entry No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the unique entry number for this log entry.';
                    Editable = false; // System-generated auto-increment field
                }
                field("Invoice No."; Rec."Invoice No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the invoice number that was submitted.';
                    Editable = false; // System-populated from invoice - should not be modified
                }
                field("Customer Name"; Rec."Customer Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the customer name for this invoice submission.';
                    Editable = false; // System-populated from invoice - should not be modified
                }
                field("Status"; Rec.Status)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the submission status (Submitted, Accepted, Rejected, etc.).';
                    Editable = false; // System-controlled status - should not be manually modified
                }
                field("Environment"; Rec.Environment)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the environment (Preprod/Production) where the submission was made.';
                    Editable = false; // Set during submission - should not be modified
                }
            }

            group(Submission)
            {
                Caption = 'Submission Details';
                field("Submission UID"; Rec."Submission UID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the LHDN submission UID returned after submission.';
                    Editable = false; // LHDN-generated identifier - should not be modified
                }
                field("Document UUID"; Rec."Document UUID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the document UUID assigned by LHDN MyInvois.';
                    Editable = false; // LHDN-generated identifier - should not be modified
                }
                field("Long ID"; Rec."Long ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Long temporary ID returned by LHDN for valid documents.';
                    Editable = false; // LHDN-generated identifier - should not be modified
                }
                field("Validation Link"; Rec."Validation Link")
                {
                    ApplicationArea = All;
                    ToolTip = 'Public validation URL constructed as {envbaseurl}/uuid-of-document/share/longid.';
                    ExtendedDatatype = URL;
                    Editable = false; // System-generated URL - should not be modified
                }
                field("Document Type Description"; Rec."Document Type Description")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the document type description (e.g., Standard Invoice, Credit Note, etc.).';
                    Editable = false; // Calculated field - should not be modified
                }
                field("Submission Date"; Rec."Submission Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the invoice was submitted to LHDN.';
                    Editable = false; // System-generated timestamp - should not be modified
                }
                field("Response Date"; Rec."Response Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the response was received from LHDN.';
                    Editable = false; // System-generated timestamp - should not be modified
                }
                field("Last Updated"; Rec."Last Updated")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when this log entry was last updated.';
                    Editable = false; // System-generated timestamp - should not be modified
                }
                field("Posting Date"; Rec."Posting Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the posting date of the posted sales invoice.';
                    Editable = false; // System-generated date - should not be modified
                }
            }

            group(User)
            {
                Caption = 'User Information';
                field("User ID"; Rec."User ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the user who made the submission.';
                    Editable = false; // System-generated user tracking - should not be modified
                }
                field("Company Name"; Rec."Company Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the company name.';
                    Editable = false; // System-generated company info - should not be modified
                }
            }

            group(Error)
            {
                Caption = 'Error Information';
                Visible = Rec."Error Message" <> '';
                field("Error Message"; Rec."Error Message")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies any error message received from LHDN.';
                    MultiLine = true;
                    Editable = false; // System-generated error message - should not be modified
                }
                field("Response Details"; Rec."Response Details")
                {
                    ApplicationArea = All;
                    ToolTip = 'Full response details from LHDN API.';
                    Editable = false; // System-generated response - should not be modified
                }
            }

            group(Cancellation)
            {
                Caption = 'Cancellation Information';
                Visible = Rec.Status = 'Cancelled';
                field("Cancellation Reason"; Rec."Cancellation Reason")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the reason for cancellation.';
                    MultiLine = true;
                    Editable = false; // System-generated cancellation reason - should not be modified
                }
                field("Cancellation Date"; Rec."Cancellation Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the document was cancelled in LHDN.';
                    Editable = false; // System-generated timestamp - should not be modified
                }
            }
        }
    }

    actions
    {
        area(processing)
        {
            action(RefreshStatus)
            {
                ApplicationArea = All;
                Caption = 'Refresh Status';
                Image = Refresh;
                ToolTip = 'Refresh the status of this submission using the LHDN Get Submission API';
                Visible = IsJotexCompany;

                trigger OnAction()
                var
                    SubmissionStatusCU: Codeunit "eInvoice Submission Status";
                begin
                    // Use direct API refresh method like the submission log page
                    if Rec."Submission UID" = '' then begin
                        Message('No Submission UID found for this entry. Cannot refresh status.');
                        exit;
                    end;

                    if DirectRefreshSingle(Rec) then begin
                        PopulateValidationLink(Rec);
                        Message('Status refreshed successfully from LHDN API.');
                        CurrPage.Update(false);
                    end else begin
                        Message('Direct API refresh failed for Submission UID %1. Check the Error Message field for details.', Rec."Submission UID");
                    end;
                end;
            }

            action(ViewInvoice)
            {
                ApplicationArea = All;
                Caption = 'View Invoice';
                Image = Document;
                ToolTip = 'Open the related posted sales invoice';

                trigger OnAction()
                var
                    PostedSalesInvoice: Page "Posted Sales Invoice";
                    SalesInvoiceHeader: Record "Sales Invoice Header";
                begin
                    if SalesInvoiceHeader.Get(Rec."Invoice No.") then begin
                        PostedSalesInvoice.SetRecord(SalesInvoiceHeader);
                        PostedSalesInvoice.Run();
                    end else
                        Message('Invoice %1 not found.', Rec."Invoice No.");
                end;
            }

            action(DownloadResponse)
            {
                ApplicationArea = All;
                Caption = 'Download Response Details';
                Image = ExportFile;
                ToolTip = 'Download the full response details as a text file';

                trigger OnAction()
                var
                    TempBlob: Codeunit "Temp Blob";
                    OutStream: OutStream;
                    InStream: InStream;
                    FileName: Text;
                    ResponseText: Text;
                begin
                    // Extract response details from blob
                    if Rec."Response Details".HasValue() then begin
                        Rec.CalcFields("Response Details");
                        Rec."Response Details".CreateInStream(InStream);
                        InStream.ReadText(ResponseText);

                        FileName := StrSubstNo('Response_Details_%1_%2.txt',
                            Rec."Invoice No.",
                            Format(CurrentDateTime, 0, '<Year4><Month,2><Day,2><Hours24,2><Minutes,2><Seconds,2>'));

                        TempBlob.CreateOutStream(OutStream);
                        OutStream.WriteText(ResponseText);
                        TempBlob.CreateInStream(InStream);
                        DownloadFromStream(InStream, 'Download Response Details', '', 'Text files (*.txt)|*.txt', FileName);
                    end else
                        Message('No response details available for this entry.');
                end;
            }

            action(MarkAsCancelled)
            {
                ApplicationArea = All;
                Caption = 'Mark as Cancelled';
                Image = Cancel;
                ToolTip = 'Manually mark this submission as cancelled (use when LHDN cancellation succeeded but local update failed)';
                Visible = (Rec.Status = 'Valid') and IsJotexCompany;

                trigger OnAction()
                var
                    CancellationHelper: Codeunit "eInvoice Cancellation Helper";
                    CancellationReason: Text;
                    ConfirmMsg: Label 'Are you sure you want to mark submission %1 as cancelled?\This should only be used when LHDN cancellation succeeded but the local log was not updated.';
                begin
                    if not Confirm(ConfirmMsg, false, Rec."Entry No.") then
                        exit;

                    // Allow user to choose between default reason or custom reason
                    CancellationReason := SelectManualCancellationReason();
                    if CancellationReason = '' then
                        exit; // User cancelled

                    if CancellationHelper.UpdateCancellationStatusByInvoice(Rec."Invoice No.", CancellationReason) then begin
                        Message('Submission log has been updated to cancelled status with reason: %1', CancellationReason);
                        CurrPage.Update(false);
                    end else begin
                        Message('Failed to update cancellation status. Please contact system administrator.');
                    end;
                end;
            }

            action(DeleteEntry)
            {
                ApplicationArea = All;
                Caption = 'Delete Entry';
                Image = Delete;
                ToolTip = 'Delete this entry (allowed if Submission UID is empty/null OR Document UUID is empty/null, including literal "null" values).';
                Visible = true;

                trigger OnAction()
                var
                    SubmissionLog: Record "eInvoice Submission Log";
                begin
                    // Check if both fields have actual values (not empty AND not literal 'null')
                    if (Rec."Submission UID" <> '') and (Rec."Submission UID" <> 'null') and
                       (Rec."Document UUID" <> '') and (Rec."Document UUID" <> 'null') then begin
                        Error('Cannot delete e-invoice submission log entry. Only entries without Submission UID OR without Document UUID (including literal "null" values) can be deleted.\Submission UID: %1\Document UUID: %2',
                              Rec."Submission UID", Rec."Document UUID");
                    end;

                    if Confirm(StrSubstNo('Are you sure you want to delete entry %1 for invoice %2?\This entry has no Submission UID or no Document UUID (including literal "null" values).', Rec."Entry No.", Rec."Invoice No.")) then begin
                        SubmissionLog := Rec;
                        if SubmissionLog.Delete() then begin
                            Message('Entry %1 has been deleted successfully.', SubmissionLog."Entry No.");
                            CurrPage.Close();
                        end else
                            Error('Failed to delete entry %1.', SubmissionLog."Entry No.");
                    end;
                end;
            }
        }
    }

    local procedure ExtractStatusFromResponse(ResponseText: Text): Text
    var
        Status: Text;
        JsonObject: JsonObject;
        JsonToken: JsonToken;
    begin
        // Try to parse JSON response first for more accurate status extraction
        if JsonObject.ReadFrom(ResponseText) then begin
            if JsonObject.Get('overallStatus', JsonToken) then begin
                Status := JsonToken.AsValue().AsText();
                // Convert API status to display format
                case Status of
                    'valid':
                        exit('Valid');
                    'invalid':
                        exit('Invalid');
                    'in progress':
                        exit('In Progress');
                    'partially valid':
                        exit('Partially Valid');
                    else
                        exit(Status);
                end;
            end;
        end;

        // Fallback to text parsing if JSON parsing fails
        if ResponseText.Contains('Overall Status: valid') then
            Status := 'Valid'
        else if ResponseText.Contains('Overall Status: invalid') then
            Status := 'Invalid'
        else if ResponseText.Contains('Overall Status: in progress') then
            Status := 'In Progress'
        else if ResponseText.Contains('Overall Status: partially valid') then
            Status := 'Partially Valid'
        else
            Status := 'Unknown';

        exit(Status);
    end;

    /// <summary>
    /// Select cancellation reason for manual marking
    /// </summary>
    /// <returns>Selected cancellation reason or empty string if cancelled</returns>
    local procedure SelectManualCancellationReason(): Text
    var
        Selection: Integer;
        CustomReason: Text[500];
        ReasonText: Text;
    begin
        ReasonText := '';

        // Show options for manual cancellation reasons
        Selection := Dialog.StrMenu('Default - LHDN cancellation completed successfully,System sync issue - LHDN already cancelled,Data correction - Manual administrative action,Enter custom reason', 1, 'Select reason for manual cancellation:');

        case Selection of
            1:
                ReasonText := 'Manually marked as cancelled - LHDN cancellation completed successfully';
            2:
                ReasonText := 'System synchronization issue - LHDN status already cancelled';
            3:
                ReasonText := 'Data correction - Manual administrative cancellation';
            4:
                begin
                    // Get custom reason input from user
                    CustomReason := GetCustomCancellationReason();
                    if CustomReason <> '' then
                        ReasonText := 'Manual cancellation - ' + CustomReason
                    else
                        ReasonText := ''; // User cancelled
                end;
            else
                ReasonText := '';
        end;

        exit(ReasonText);
    end;

    /// <summary>
    /// Get custom cancellation reason from user input
    /// </summary>
    /// <returns>Custom reason text or empty string if cancelled</returns>
    local procedure GetCustomCancellationReason(): Text[500]
    var
        CustomReasonPage: Page "Custom Cancellation Reason";
        CustomReason: Text[500];
    begin
        // Open the custom reason input page
        if CustomReasonPage.RunModal() = Action::OK then begin
            CustomReason := CustomReasonPage.GetCancellationReason();

            // Validate the reason is not empty
            if CustomReason <> '' then
                exit(CustomReason);
        end;

        // Return empty string if cancelled or no reason provided
        exit('');
    end;

    var
        IsJotexCompany: Boolean;

    trigger OnOpenPage()
    var
        CompanyInfo: Record "Company Information";
    begin
        IsJotexCompany := CompanyInfo.Get() and (CompanyInfo.Name = 'JOTEX SDN BHD');
    end;

    /// <summary>
    /// Direct refresh using the same approach as Posted Sales Invoice page
    /// </summary>
    local procedure DirectRefreshSingle(var Entry: Record "eInvoice Submission Log"): Boolean
    var
        HttpClient: HttpClient;
        HttpRequestMessage: HttpRequestMessage;
        HttpResponseMessage: HttpResponseMessage;
        RequestHeaders: HttpHeaders;
        eInvoiceSetup: Record "eInvoiceSetup";
        eInvoiceHelper: Codeunit eInvoiceHelper;
        AccessToken: Text;
        ApiUrl: Text;
        ResponseText: Text;
        LhdnStatus: Text;
        OutStream: OutStream;
    begin
        if Entry."Submission UID" = '' then
            exit(false);

        if not eInvoiceSetup.Get('SETUP') then
            exit(false);

        eInvoiceHelper.InitializeHelper();
        AccessToken := eInvoiceHelper.GetAccessTokenFromSetup(eInvoiceSetup);
        if AccessToken = '' then
            exit(false);

        if eInvoiceSetup.Environment = eInvoiceSetup.Environment::Preprod then
            ApiUrl := StrSubstNo('https://preprod-api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions/%1', Entry."Submission UID")
        else
            ApiUrl := StrSubstNo('https://api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions/%1', Entry."Submission UID");

        HttpRequestMessage.Method('GET');
        HttpRequestMessage.SetRequestUri(ApiUrl);
        HttpRequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Clear();
        RequestHeaders.Add('Accept', 'application/json');
        RequestHeaders.Add('Accept-Language', 'en');
        RequestHeaders.Add('Authorization', 'Bearer ' + AccessToken);

        if HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then begin
            HttpResponseMessage.Content().ReadAs(ResponseText);
            if HttpResponseMessage.IsSuccessStatusCode() then begin
                // Parse status like posted pages
                LhdnStatus := ExtractStatusFromApiResponse(ResponseText, Entry."Document UUID");
                Entry.Status := LhdnStatus;
                Entry."Response Date" := CurrentDateTime;
                Entry."Last Updated" := CurrentDateTime;
                Entry."Error Message" := CopyStr('Status refreshed from LHDN via direct API (Submission Log Entry).', 1, MaxStrLen(Entry."Error Message"));

                // Store the full response details
                Entry."Response Details".CreateOutStream(OutStream);
                OutStream.WriteText(ResponseText);

                // Populate UUID if missing
                if Entry."Document UUID" = '' then
                    Entry."Document UUID" := CopyStr(ExtractUuidFromApiResponse(ResponseText), 1, MaxStrLen(Entry."Document UUID"));

                // Extract Long ID when available (Valid/Cancelled docs)
                Entry."Long ID" := CopyStr(ExtractLongIdFromApiResponse(ResponseText, Entry."Document UUID"), 1, MaxStrLen(Entry."Long ID"));

                if Entry.Modify() then begin
                    exit(true);
                end else begin
                    Entry."Error Message" := CopyStr('Failed to update log entry after successful API response.', 1, MaxStrLen(Entry."Error Message"));
                    exit(false);
                end;
            end else begin
                // Handle HTTP errors
                Entry."Error Message" := CopyStr(StrSubstNo('HTTP Error %1: %2', HttpResponseMessage.HttpStatusCode(), ResponseText), 1, MaxStrLen(Entry."Error Message"));
                Entry."Last Updated" := CurrentDateTime;
                Entry.Modify();
                exit(false);
            end;
        end else begin
            // Handle connection failures
            Entry."Error Message" := CopyStr(StrSubstNo('Connection failed: %1', GetLastErrorText()), 1, MaxStrLen(Entry."Error Message"));
            Entry."Last Updated" := CurrentDateTime;
            Entry.Modify();
            exit(false);
        end;
    end;

    local procedure PopulateValidationLink(var Entry: Record "eInvoice Submission Log")
    var
        Setup: Record "eInvoiceSetup";
        ValidationUrl: Text;
    begin
        if not Setup.Get('SETUP') then
            exit;

        // Ensure Long ID is populated from last response when possible
        if Entry."Long ID" = '' then
            exit;

        if Setup.Environment = Setup.Environment::Preprod then
            ValidationUrl := StrSubstNo('%1/%2/share/%3', 'https://preprod.myinvois.hasil.gov.my', Entry."Document UUID", Entry."Long ID")
        else
            ValidationUrl := StrSubstNo('%1/%2/share/%3', 'https://myinvois.hasil.gov.my', Entry."Document UUID", Entry."Long ID");

        Entry."Validation Link" := CopyStr(ValidationUrl, 1, MaxStrLen(Entry."Validation Link"));
        Entry.Modify();

        // Also update Posted Sales Invoice with QR URL when available
        UpdatePostedInvoiceQrUrl(Entry."Invoice No.", ValidationUrl);
    end;

    local procedure UpdatePostedInvoiceQrUrl(InvoiceNo: Code[20]; Url: Text)
    var
        eInvoiceGenerator: Codeunit "eInvoice JSON Generator";
    begin
        if (InvoiceNo = '') or (Url = '') then
            exit;

        // Use codeunit with tabledata permissions to avoid page permission issues
        if eInvoiceGenerator.UpdateInvoiceQrUrl(InvoiceNo, Url) then begin
            // Automatically generate QR image after updating the URL
            AutoGenerateInvoiceQrImage(InvoiceNo, Url);
        end;
    end;

    local procedure ExtractLongIdFromApiResponse(ResponseText: Text; DocumentUuid: Text): Text
    var
        JsonObject: JsonObject;
        JsonToken: JsonToken;
        DocumentSummary: JsonArray;
        Doc: JsonObject;
        PickedUuid: Text;
        LongId: Text;
        i: Integer;
    begin
        if not JsonObject.ReadFrom(ResponseText) then
            exit('');

        if JsonObject.Get('documentSummary', JsonToken) and JsonToken.IsArray() then begin
            DocumentSummary := JsonToken.AsArray();
            for i := 0 to DocumentSummary.Count() - 1 do begin
                DocumentSummary.Get(i, JsonToken);
                if JsonToken.IsObject() then begin
                    Doc := JsonToken.AsObject();
                    PickedUuid := '';
                    if Doc.Get('uuid', JsonToken) then
                        PickedUuid := JsonToken.AsValue().AsText();
                    if (DocumentUuid = '') or (PickedUuid = DocumentUuid) then begin
                        if Doc.Get('longId', JsonToken) then
                            exit(JsonToken.AsValue().AsText());
                    end;
                end;
            end;
        end;
        exit('');
    end;

    local procedure ExtractUuidFromApiResponse(ResponseText: Text): Text
    var
        JsonObject: JsonObject;
        JsonToken: JsonToken;
        DocumentSummary: JsonArray;
        Doc: JsonObject;
    begin
        if not JsonObject.ReadFrom(ResponseText) then
            exit('');

        if JsonObject.Get('documentSummary', JsonToken) and JsonToken.IsArray() then begin
            DocumentSummary := JsonToken.AsArray();
            if DocumentSummary.Count() > 0 then begin
                DocumentSummary.Get(0, JsonToken);
                if JsonToken.IsObject() then begin
                    Doc := JsonToken.AsObject();
                    if Doc.Get('uuid', JsonToken) then
                        exit(JsonToken.AsValue().AsText());
                end;
            end;
        end;
        exit('');
    end;

    local procedure ExtractStatusFromApiResponse(ResponseText: Text; DocumentUuid: Text): Text
    var
        JsonObject: JsonObject;
        JsonToken: JsonToken;
        DocumentSummaryArray: JsonArray;
        DocumentJson: JsonObject;
        OverallStatus: Text;
        DocumentStatus: Text;
        PickedUuid: Text;
        i: Integer;
    begin
        if not JsonObject.ReadFrom(ResponseText) then
            exit('Unknown');

        if JsonObject.Get('documentSummary', JsonToken) and JsonToken.IsArray() then begin
            DocumentSummaryArray := JsonToken.AsArray();
            for i := 0 to DocumentSummaryArray.Count() - 1 do begin
                DocumentSummaryArray.Get(i, JsonToken);
                if JsonToken.IsObject() then begin
                    DocumentJson := JsonToken.AsObject();
                    if DocumentJson.Get('uuid', JsonToken) then
                        PickedUuid := JsonToken.AsValue().AsText();
                    if (DocumentUuid <> '') and (PickedUuid = DocumentUuid) then
                        if DocumentJson.Get('status', JsonToken) then begin
                            DocumentStatus := JsonToken.AsValue().AsText();
                            exit(NormalizeStatus(DocumentStatus));
                        end;
                end;
            end;
        end;

        if JsonObject.Get('overallStatus', JsonToken) then
            OverallStatus := JsonToken.AsValue().AsText();
        exit(NormalizeStatus(OverallStatus));
    end;

    local procedure NormalizeStatus(StatusValue: Text): Text
    begin
        case LowerCase(StatusValue) of
            'valid':
                exit('Valid');
            'invalid':
                exit('Invalid');
            'in progress':
                exit('In Progress');
            'partially valid':
                exit('Partially Valid');
            'cancelled':
                exit('Cancelled');
            'rejected':
                exit('Rejected');
            else
                exit(StatusValue);
        end;
    end;

    /// <summary>
    /// Automatically generates QR image for the invoice using the validation URL
    /// This is called after the QR URL is updated during status refresh
    /// </summary>
    /// <param name="InvoiceNo">The invoice number to generate QR for</param>
    /// <param name="ValidationUrl">The validation URL to convert to QR</param>
    local procedure AutoGenerateInvoiceQrImage(InvoiceNo: Code[20]; ValidationUrl: Text)
    var
        HttpClient: HttpClient;
        Response: HttpResponseMessage;
        QrServiceUrl: Text;
        InS: InStream;
        eInvoiceGenerator: Codeunit "eInvoice JSON Generator";
        Success: Boolean;
    begin
        if (InvoiceNo = '') or (ValidationUrl = '') then
            exit;

        // Use a QR generation service to render the QR image from the validation URL
        QrServiceUrl := StrSubstNo('https://quickchart.io/qr?text=%1&size=220', ValidationUrl);

        if not HttpClient.Get(QrServiceUrl, Response) then begin
            // Silently fail - this is an automatic process
            exit;
        end;

        if not Response.IsSuccessStatusCode() then begin
            // Silently fail - this is an automatic process
            exit;
        end;

        Response.Content().ReadAs(InS);

        // Generate and store the QR image
        Success := eInvoiceGenerator.UpdateInvoiceQrImage(InvoiceNo, InS, 'eInvoiceQR.png');

        if Success then begin
            // Successfully generated QR image
            // Note: We don't update the page here as this is called from a background process
        end;
    end;
}