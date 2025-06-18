tableextension 50302 eInvSalesInvoiceQRMedia extends "Sales Invoice Header"
{
    fields
    {
        field(50103; "eInvoice QR Image"; Media)
        {
            Caption = 'e-Invoice QR Image';
            DataClassification = CustomerContent;
        }
    }
}
