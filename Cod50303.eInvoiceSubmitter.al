codeunit 50303 "eInvoice Submitter"
{
    procedure SubmitToMyInvois(SalesInvHeader: Record "Sales Invoice Header"): Text
    var
        JsonBuilder: Codeunit "eInvois Json Builder";
        MyInvoisHelper: Codeunit "eInvoiceHelper";
        MyInvoisSetup: Record eInvoiceSetup;
        Token: Text;
        Json: JsonObject;
        JsonText: Text;
        HttpClient: HttpClient;
        RequestContent: HttpContent;
        Headers: HttpHeaders;
        Response: HttpResponseMessage;
        ResponseText: Text;
        ResponseJson: JsonObject;
        ValueToken: JsonToken;
        ApiURL: Text;

        // ✅ For QR image download
        QRUrl: Text;
        QRResponse: HttpResponseMessage;
        QRStream: InStream;
    begin
        if not MyInvoisSetup.Get('API SETUP') then
            Error('API Setup not found.');

        // ✅ Get Access Token
        Token := MyInvoisHelper.GetAccessTokenFromSetup(MyInvoisSetup);

        // ✅ Build Invoice JSON
        Json := JsonBuilder.BuildInvoiceJson(SalesInvHeader);

        // ✅ Serialize JSON to Text
        Json.WriteTo(JsonText);

        // ✅ Prepare HTTP content
        RequestContent.WriteFrom(JsonText);
        RequestContent.GetHeaders(Headers);
        Headers.Clear();
        Headers.Add('Content-Type', 'application/json');

        HttpClient.DefaultRequestHeaders().Clear();
        HttpClient.DefaultRequestHeaders().Add('Authorization', 'Bearer ' + Token);

        // ✅ Determine API URL
        if MyInvoisSetup.Environment = MyInvoisSetup.Environment::Preprod then
            ApiURL := 'https://preprod-api.myinvois.hasil.gov.my/api/v1.0/invoices'
        else
            ApiURL := 'https://api.myinvois.hasil.gov.my/api/v1.0/invoices';

        // ✅ POST to MyInvois
        if not HttpClient.Post(ApiURL, RequestContent, Response) then
            Error('Failed to submit invoice to MyInvois.');

        Response.Content().ReadAs(ResponseText);
        Message('Response:\n%1', ResponseText);

        // ✅ Parse response and update header
        ResponseJson.ReadFrom(ResponseText);

        if ResponseJson.Contains('uuid') then begin
            ResponseJson.Get('uuid', ValueToken);
            SalesInvHeader."eInvoice UUID" := ValueToken.AsValue().AsText();
        end;

        if ResponseJson.Contains('qrCodeUrl') then begin
            ResponseJson.Get('qrCodeUrl', ValueToken);
            QRUrl := ValueToken.AsValue().AsText();
            SalesInvHeader."eInvoice QR URL" := QRUrl;

            if QRUrl <> '' then begin
                HttpClient.Get(QRUrl, QRResponse);
                QRResponse.Content().ReadAs(QRStream);
                SalesInvHeader."eInvoice QR Image".ImportStream(QRStream, 'QRCode.png');
            end;
        end;

        if ResponseJson.Contains('pdfUrl') then begin
            ResponseJson.Get('pdfUrl', ValueToken);
            SalesInvHeader."eInvoice PDF URL" := ValueToken.AsValue().AsText();
        end;

        SalesInvHeader.Modify();

        exit(StrSubstNo(
            'Submitted successfully.\nUUID: %1\nQR: %2\nPDF: %3',
            SalesInvHeader."eInvoice UUID",
            SalesInvHeader."eInvoice QR URL",
            SalesInvHeader."eInvoice PDF URL"
        ));
    end;
}
