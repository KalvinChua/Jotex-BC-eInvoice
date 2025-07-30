codeunit 50312 "eInvoice Submission Status"
{
    var
        LastRequestTime: DateTime;

    procedure CheckSubmissionStatus(SubmissionUid: Text; var SubmissionDetails: Text): Boolean
    var
        HttpClient: HttpClient;
        HttpResponseMessage: HttpResponseMessage;
        RequestMessage: HttpRequestMessage;
        AccessToken: Text;
        eInvoiceSetup: Record "eInvoiceSetup";
        Url: Text;
        Headers: HttpHeaders;
        eInvoiceJson: Codeunit "eInvoice JSON Generator";
        TimeSinceLastRequest: Duration;
    begin
        SubmissionDetails := '';

        // Rate limiting: Ensure 3-5 second interval between requests as per LHDN documentation
        if LastRequestTime <> 0DT then begin
            TimeSinceLastRequest := CurrentDateTime - LastRequestTime;
            if TimeSinceLastRequest < 3000 then begin // 3 seconds minimum
                Sleep(3000 - TimeSinceLastRequest);
            end;
        end;

        if not eInvoiceSetup.Get('SETUP') then begin
            SubmissionDetails := 'Error: eInvoice Setup not found.';
            exit(false);
        end;

        // Get access token using the public helper
        AccessToken := eInvoiceJson.GetLhdnAccessTokenFromHelper(eInvoiceSetup);
        if AccessToken = '' then begin
            SubmissionDetails := 'Error: Failed to obtain access token.';
            exit(false);
        end;

        // Build URL according to LHDN API specification
        // GET /api/v1.0/documentsubmissions/{submissionUid}?pageNo={pageNo}&pageSize={pageSize}
        if eInvoiceSetup.Environment = eInvoiceSetup.Environment::Preprod then
            Url := StrSubstNo('https://preprod-api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions/%1?pageNo=1&pageSize=100', SubmissionUid)
        else
            Url := StrSubstNo('https://api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions/%1?pageNo=1&pageSize=100', SubmissionUid);

        RequestMessage.Method('GET');
        RequestMessage.SetRequestUri(Url);

        RequestMessage.GetHeaders(Headers);
        Headers.Add('Authorization', StrSubstNo('Bearer %1', AccessToken));
        Headers.Add('Content-Type', 'application/json');
        Headers.Add('Accept', 'application/json');
        Headers.Add('Accept-Language', 'en');

        if not HttpClient.Send(RequestMessage, HttpResponseMessage) then begin
            SubmissionDetails := 'Error: Failed to send HTTP request.';
            exit(false);
        end;

        // Update last request time for rate limiting
        LastRequestTime := CurrentDateTime;

        HttpResponseMessage.Content().ReadAs(SubmissionDetails);

        exit(HttpResponseMessage.IsSuccessStatusCode());
    end;
}