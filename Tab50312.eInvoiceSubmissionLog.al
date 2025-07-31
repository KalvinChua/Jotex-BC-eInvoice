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
}