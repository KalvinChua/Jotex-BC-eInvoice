tableextension 50302 eInvItemExt extends Item
{
    fields
    {
        field(50300; "e-Invoice Tax Type"; Code[20])
        {
            Caption = 'e-Invoice Tax';
            ToolTip = 'Mandatory for e-Invoice submission. Use e-Invoice Tax Type.';
            TableRelation = "e-Invoice Tax Types".Code;
        }
        field(50301; "e-Invoice Classification"; Code[20])
        {
            Caption = 'e-Invoice Classification';
            ToolTip = 'Mandatory for e-Invoice submission. Use e-Invoice Classification.';
            TableRelation = "eInvoiceClassification".Code;
        }
        field(50302; "e-Invoice UOM"; Code[20])
        {
            Caption = 'e-Invoice UOM';
            ToolTip = 'Mandatory for e-Invoice submission. Use e-Invoice Unit of Measure.';
            TableRelation = "eInvoiceUOM".Code;
        }
    }
}
