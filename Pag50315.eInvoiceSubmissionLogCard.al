page 50315 "e-Invoice Submission Log Card"
{
    PageType = Card;
    SourceTable = "eInvoice Submission Log";
    Caption = 'e-Invoice Submission Log Entry';
    UsageCategory = None;
    ApplicationArea = All;
    Editable = false; // Make entire page read-only to prevent data corruption

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
                }
                field("Invoice No."; Rec."Invoice No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the invoice number that was submitted.';
                }
                field("Customer Name"; Rec."Customer Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the customer name for this invoice submission.';
                }
                field("Status"; Rec.Status)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the submission status (Submitted, Accepted, Rejected, etc.).';
                }
                field("Environment"; Rec.Environment)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the environment (Preprod/Production) where the submission was made.';
                }
            }

            group(Submission)
            {
                Caption = 'Submission Details';
                field("Submission UID"; Rec."Submission UID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the LHDN submission UID returned after submission.';
                }
                field("Document UUID"; Rec."Document UUID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the document UUID assigned by LHDN MyInvois.';
                }
                field("Document Type"; Rec."Document Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the document type from the LHDN API response (e.g., Invoice, Credit Note, etc.).';
                }
                field("Submission Date"; Rec."Submission Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the invoice was submitted to LHDN.';
                }
                field("Response Date"; Rec."Response Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the response was received from LHDN.';
                }
                field("Last Updated"; Rec."Last Updated")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when this log entry was last updated.';
                }
                field("Posting Date"; Rec."Posting Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the posting date of the posted sales invoice.';
                }
            }

            group(User)
            {
                Caption = 'User Information';
                field("User ID"; Rec."User ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the user who made the submission.';
                }
                field("Company Name"; Rec."Company Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the company name.';
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
                }
                field("Cancellation Date"; Rec."Cancellation Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the document was cancelled in LHDN.';
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