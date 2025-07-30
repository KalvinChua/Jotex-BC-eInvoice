page 50316 "e-Invoice Submission Log"
{
    PageType = List;
    SourceTable = "eInvoice Submission Log";
    Caption = 'e-Invoice Submission Log';
    UsageCategory = Lists;
    ApplicationArea = All;
    CardPageId = "e-Invoice Submission Log Card";

    layout
    {
        area(content)
        {
            repeater(GroupName)
            {
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
                field("Status"; Rec.Status)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the submission status (Submitted, Accepted, Rejected, etc.).';
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
                field("Environment"; Rec.Environment)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the environment (Preprod/Production) where the submission was made.';
                }
                field("Error Message"; Rec."Error Message")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies any error message received from LHDN.';
                    Visible = false;
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
                ToolTip = 'Refresh the status of selected submissions using the LHDN Get Submission API';

                trigger OnAction()
                var
                    eInvoiceGenerator: Codeunit "eInvoice JSON Generator";
                    SubmissionDetails: Text;
                    ApiSuccess: Boolean;
                    UpdatedCount: Integer;
                begin
                    if Rec.FindSet() then begin
                        repeat
                            if Rec."Submission UID" <> '' then begin
                                ApiSuccess := eInvoiceGenerator.GetSubmissionStatus(Rec."Submission UID", SubmissionDetails);

                                if ApiSuccess then begin
                                    // Update the log entry with current status
                                    Rec."Status" := ExtractStatusFromResponse(SubmissionDetails);
                                    Rec."Response Date" := CurrentDateTime;
                                    Rec."Last Updated" := CurrentDateTime;
                                    Rec.Modify();
                                    UpdatedCount += 1;
                                end;
                            end;
                        until Rec.Next() = 0;

                        Message('Status refresh completed.' + '\\' + 'Updated %1 submissions.', UpdatedCount);
                    end else
                        Message('No log entries found to refresh.');
                end;
            }

            action(ExportToExcel)
            {
                ApplicationArea = All;
                Caption = 'Export to Excel';
                Image = ExportFile;
                ToolTip = 'Export the submission log to Excel for analysis';

                trigger OnAction()
                var
                    TempBlob: Codeunit "Temp Blob";
                    OutStream: OutStream;
                    InStream: InStream;
                    FileName: Text;
                    CsvContent: Text;
                begin
                    // Generate CSV content
                    CsvContent := 'Entry No.,Invoice No.,Submission UID,Document UUID,Status,Submission Date,Response Date,Environment,Error Message' + '\\';

                    if Rec.FindSet() then begin
                        repeat
                            CsvContent += StrSubstNo('%1,%2,%3,%4,%5,%6,%7,%8,%9' + '\\',
                                Rec."Entry No.",
                                Rec."Invoice No.",
                                Rec."Submission UID",
                                Rec."Document UUID",
                                Rec.Status,
                                Format(Rec."Submission Date"),
                                Format(Rec."Response Date"),
                                Rec.Environment,
                                Rec."Error Message");
                        until Rec.Next() = 0;
                    end;

                    // Create and download file
                    FileName := StrSubstNo('eInvoice_Submission_Log_%1.csv',
                        Format(CurrentDateTime, 0, '<Year4><Month,2><Day,2><Hours24,2><Minutes,2><Seconds,2>'));

                    TempBlob.CreateOutStream(OutStream);
                    OutStream.WriteText(CsvContent);
                    TempBlob.CreateInStream(InStream);
                    DownloadFromStream(InStream, 'Download Submission Log', '', 'CSV files (*.csv)|*.csv', FileName);
                end;
            }

            action(ClearOldEntries)
            {
                ApplicationArea = All;
                Caption = 'Clear Old Entries';
                Image = Delete;
                ToolTip = 'Clear log entries older than 30 days';

                trigger OnAction()
                var
                    DeleteDate: Date;
                    DeletedCount: Integer;
                begin
                    if Confirm('This will delete all log entries older than 30 days.' + '\\' + '\\' + 'Proceed?') then begin
                        DeleteDate := CalcDate('-30D', Today);
                        DeletedCount := 0;

                        Rec.SetRange("Submission Date", 0DT, CreateDateTime(DeleteDate, 235959T));
                        if Rec.FindSet() then begin
                            repeat
                                Rec.Delete();
                                DeletedCount += 1;
                            until Rec.Next() = 0;
                        end;

                        Message('Cleared %1 old log entries.', DeletedCount);
                    end;
                end;
            }
        }
    }

    local procedure ExtractStatusFromResponse(ResponseText: Text): Text
    var
        Status: Text;
    begin
        // Extract status from the response text
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
}