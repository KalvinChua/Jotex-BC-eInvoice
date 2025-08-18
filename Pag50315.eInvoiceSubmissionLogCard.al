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
                    // Use context-safe refresh method
                    if not SubmissionStatusCU.RefreshSubmissionLogStatusSafe(Rec) then begin
                        // If direct method fails due to context restrictions, try alternative approach
                        SubmissionStatusCU.RefreshSubmissionLogStatusAlternative(Rec);
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
}