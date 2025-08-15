table 50301 "eInvoice TIN Log"
{
    Caption = 'MyInvois TIN Log';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            DataClassification = SystemMetadata;
            AutoIncrement = true;
        }

        field(2; "Customer No."; Code[20]) { DataClassification = CustomerContent; }
        field(3; "Customer Name"; Text[100]) { DataClassification = CustomerContent; }
        field(4; "TIN"; Code[20]) { DataClassification = CustomerContent; }
        field(5; "TIN Status"; Text[30]) { DataClassification = CustomerContent; }
        field(6; "TIN Name (API)"; Text[100]) { DataClassification = CustomerContent; }
        field(7; "Response Time"; DateTime) { DataClassification = SystemMetadata; }
        field(8; "ID Type"; Text[10]) { DataClassification = CustomerContent; }
        field(9; "ID Value"; Text[150]) { DataClassification = CustomerContent; }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
    }
}
