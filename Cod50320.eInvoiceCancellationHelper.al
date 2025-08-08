codeunit 50320 "eInvoice Cancellation Helper"
{
    TableNo = "eInvoice Submission Log";

    trigger OnRun()
    begin
        UpdateCancellationStatus(Rec);
    end;

    /// <summary>
    /// Update cancellation status in submission log - designed to run in isolated context
    /// </summary>
    procedure UpdateCancellationStatus(var eInvoiceSubmissionLog: Record "eInvoice Submission Log")
    var
        TelemetryDimensions: Dictionary of [Text, Text];
        CompanyInfo: Record "Company Information";
    begin
        // Only process for JOTEX SDN BHD
        if not CompanyInfo.Get() or (CompanyInfo.Name <> 'JOTEX SDN BHD') then
            exit;

        if eInvoiceSubmissionLog."Invoice No." = '' then
            exit;

        // Update the status
        eInvoiceSubmissionLog.Status := 'Cancelled';
        eInvoiceSubmissionLog."Cancellation Date" := CurrentDateTime;

        if eInvoiceSubmissionLog.Modify(true) then begin
            TelemetryDimensions.Add('InvoiceNo', eInvoiceSubmissionLog."Invoice No.");
            Session.LogMessage('0000EIV07', 'Cancellation status updated in submission log',
                Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                TelemetryDimensions);
        end;
    end;

    /// <summary>
    /// Update cancellation status by invoice number - safe method for external calls
    /// </summary>
    procedure UpdateCancellationStatusByInvoice(InvoiceNo: Code[20]; CancellationReason: Text): Boolean
    var
        eInvoiceSubmissionLog: Record "eInvoice Submission Log";
        CompanyInfo: Record "Company Information";
        TelemetryDimensions: Dictionary of [Text, Text];
        RecordCount: Integer;
    begin
        // Only process for JOTEX SDN BHD
        if not CompanyInfo.Get() or (CompanyInfo.Name <> 'JOTEX SDN BHD') then begin
            TelemetryDimensions.Add('InvoiceNo', InvoiceNo);
            TelemetryDimensions.Add('Error', 'Company validation failed or not JOTEX SDN BHD');
            Session.LogMessage('0000EIV08', 'Cancellation update failed - company validation',
                Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                TelemetryDimensions);
            exit(false);
        end;

        // Find all submission logs for this invoice first
        eInvoiceSubmissionLog.SetRange("Invoice No.", InvoiceNo);
        RecordCount := eInvoiceSubmissionLog.Count();

        if RecordCount = 0 then begin
            TelemetryDimensions.Add('InvoiceNo', InvoiceNo);
            TelemetryDimensions.Add('Error', 'No submission log records found');
            Session.LogMessage('0000EIV08', 'Cancellation update failed - no records found',
                Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                TelemetryDimensions);
            exit(false);
        end;

        // Now filter for Valid status
        eInvoiceSubmissionLog.SetRange(Status, 'Valid');
        if not eInvoiceSubmissionLog.FindLast() then begin
            // Log available statuses for debugging
            eInvoiceSubmissionLog.SetRange(Status);  // Remove status filter
            if eInvoiceSubmissionLog.FindSet() then begin
                TelemetryDimensions.Add('InvoiceNo', InvoiceNo);
                TelemetryDimensions.Add('TotalRecords', Format(RecordCount));
                TelemetryDimensions.Add('Error', 'No Valid status records found');
                Session.LogMessage('0000EIV08', 'Cancellation update failed - no Valid status records',
                    Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                    TelemetryDimensions);
            end;
            exit(false);
        end;

        // Update the status
        eInvoiceSubmissionLog.Status := 'Cancelled';
        eInvoiceSubmissionLog."Cancellation Reason" := CopyStr(CancellationReason, 1, MaxStrLen(eInvoiceSubmissionLog."Cancellation Reason"));
        eInvoiceSubmissionLog."Cancellation Date" := CurrentDateTime;

        if eInvoiceSubmissionLog.Modify(true) then begin
            TelemetryDimensions.Add('InvoiceNo', InvoiceNo);
            TelemetryDimensions.Add('OriginalUUID', eInvoiceSubmissionLog."Document UUID");
            Session.LogMessage('0000EIV07', 'Cancellation status updated successfully in submission log',
                Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                TelemetryDimensions);
            exit(true);
        end else begin
            TelemetryDimensions.Add('InvoiceNo', InvoiceNo);
            TelemetryDimensions.Add('Error', 'Modify operation failed');
            Session.LogMessage('0000EIV08', 'Cancellation update failed - modify failed',
                Verbosity::Warning, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
                TelemetryDimensions);
            exit(false);
        end;
    end;



    /// <summary>
    /// Updates Customer Name for existing e-invoice submission log entries that have empty customer names.
    /// This procedure can be called manually to populate customer names for historical records.
    /// </summary>
    procedure UpdateExistingCustomerNames()
    var
        SubmissionLog: Record "eInvoice Submission Log";
        Customer: Record Customer;
        SalesInvoiceHeader: Record "Sales Invoice Header";
        CustomerName: Text;
        UpdatedCount: Integer;
    begin
        UpdatedCount := 0;

        // Find all submission log entries with empty customer names
        SubmissionLog.SetRange("Customer Name", '');
        if SubmissionLog.FindSet() then begin
            repeat
                CustomerName := '';

                // Try to get customer name from the invoice
                if SalesInvoiceHeader.Get(SubmissionLog."Invoice No.") then begin
                    if Customer.Get(SalesInvoiceHeader."Sell-to Customer No.") then
                        CustomerName := Customer.Name;
                end;

                // Update the record if we found a customer name
                if CustomerName <> '' then begin
                    SubmissionLog."Customer Name" := CustomerName;
                    SubmissionLog.Modify();
                    UpdatedCount += 1;
                end;
            until SubmissionLog.Next() = 0;
        end;

        // Show results to user
        if UpdatedCount > 0 then
            Message('Successfully updated Customer Name for %1 existing submission log entries.', UpdatedCount)
        else
            Message('No submission log entries with empty Customer Name were found.');
    end;
}
