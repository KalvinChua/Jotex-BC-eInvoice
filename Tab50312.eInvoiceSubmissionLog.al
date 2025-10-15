table 50312 "eInvoice Submission Log"
{
    DataClassification = CustomerContent;
    Caption = 'e-Invoice Submission Log';

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            DataClassification = CustomerContent;
            AutoIncrement = true;
        }
        field(2; "Invoice No."; Code[20])
        {
            Caption = 'Invoice No.';
            DataClassification = CustomerContent;
            TableRelation = "Sales Invoice Header"."No.";
        }
        field(3; "Submission UID"; Text[100])
        {
            Caption = 'Submission UID';
            DataClassification = CustomerContent;
        }
        field(4; "Document UUID"; Text[100])
        {
            Caption = 'Document UUID';
            DataClassification = CustomerContent;
        }
        field(5; "Status"; Text[50])
        {
            Caption = 'Status';
            DataClassification = CustomerContent;
        }
        field(6; "Submission Date"; DateTime)
        {
            Caption = 'Submission Date';
            DataClassification = CustomerContent;
        }
        field(7; "Response Date"; DateTime)
        {
            Caption = 'Response Date';
            DataClassification = CustomerContent;
        }
        field(8; "Environment"; Option)
        {
            Caption = 'Environment';
            DataClassification = CustomerContent;
            OptionMembers = Preprod,Production;
        }
        field(9; "Error Message"; Text[2048])
        {
            Caption = 'Error Message';
            DataClassification = CustomerContent;
        }
        field(10; "Last Updated"; DateTime)
        {
            Caption = 'Last Updated';
            DataClassification = CustomerContent;
        }
        field(11; "Response Details"; Blob)
        {
            Caption = 'Response Details';
            DataClassification = CustomerContent;
        }
        field(12; "User ID"; Code[50])
        {
            Caption = 'User ID';
            DataClassification = CustomerContent;
        }
        field(13; "Company Name"; Text[100])
        {
            Caption = 'Company Name';
            DataClassification = CustomerContent;
        }
        field(14; "Customer Name"; Text[100])
        {
            Caption = 'Customer Name';
            DataClassification = CustomerContent;
        }
        field(15; "Cancellation Reason"; Text[500])
        {
            Caption = 'Cancellation Reason';
            DataClassification = CustomerContent;
        }
        field(16; "Cancellation Date"; DateTime)
        {
            Caption = 'Cancellation Date';
            DataClassification = CustomerContent;
        }
        field(17; "Posting Date"; Date)
        {
            Caption = 'Posting Date';
            DataClassification = CustomerContent;
        }
        field(18; "Document Type"; Code[20])
        {
            Caption = 'Document Type';
            DataClassification = CustomerContent;
            TableRelation = eInvoiceTypes.Code;
        }
        field(19; "Document Type Description"; Text[100])
        {
            Caption = 'Document Type Description';
            FieldClass = FlowField;
            CalcFormula = Lookup(eInvoiceTypes.Description WHERE(Code = FIELD("Document Type")));
        }

        field(21; "Request Payload"; Blob)
        {
            Caption = 'Request Payload';
            DataClassification = CustomerContent;
        }
        field(22; "Response Payload"; Blob)
        {
            Caption = 'Response Payload';
            DataClassification = CustomerContent;
        }
        field(23; "Raw Payload Stored"; Boolean)
        {
            Caption = 'Raw Payload Stored';
            DataClassification = CustomerContent;
        }
        field(24; "Response Preview"; Text[250])
        {
            Caption = 'Response Preview';
            DataClassification = CustomerContent;
        }
        field(25; "Long ID"; Text[200])
        {
            Caption = 'Long ID';
            DataClassification = CustomerContent;
        }
        field(26; "Validation Link"; Text[250])
        {
            Caption = 'Validation Link';
            DataClassification = CustomerContent;
        }
        field(27; "Amount"; Decimal)
        {
            Caption = 'Amount';
            DataClassification = CustomerContent;
            AutoFormatType = 1;
        }
        field(28; "Amount Including VAT"; Decimal)
        {
            Caption = 'Amount Including VAT';
            DataClassification = CustomerContent;
            AutoFormatType = 1;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(InvoiceNo; "Invoice No.")
        {
        }
        key(SubmissionUID; "Submission UID")
        {
        }
        key(Status; Status)
        {
        }
        key(SubmissionDate; "Submission Date")
        {
        }
    }

    trigger OnDelete()
    var
        CanDelete: Boolean;
    begin
        CanDelete := false;

        // Allow deletion if Submission UID is empty or 'null'
        if ("Submission UID" = '') or ("Submission UID" = 'null') then
            CanDelete := true
        // Allow deletion if Document UUID is empty or 'null'
        else if ("Document UUID" = '') or ("Document UUID" = 'null') then
            CanDelete := true
        // Allow deletion if Status is Invalid or Submitted
        else if (Status = 'Invalid') or (Status = 'Submitted') then
            CanDelete := true;

        if not CanDelete then
            Error('Cannot delete e-invoice submission log entry. Only entries without Submission UID, without Document UUID, or with Invalid/Submitted status can be deleted.\Submission UID: %1\Document UUID: %2\Status: %3',
                  "Submission UID", "Document UUID", Status);
    end;
}