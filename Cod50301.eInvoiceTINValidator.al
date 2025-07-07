codeunit 50301 "eInvoice TIN Validator"
{
    procedure ValidateTIN(var CustomerRec: Record Customer): Text
    var
        MyInvoisSetup: Record "eInvoiceSetup";
        TokenHelper: Codeunit "eInvoiceHelper";
        HttpClient: HttpClient;
        Response: HttpResponseMessage;
        Token: Text;
        URL: Text;
        TIN: Text;
        IDType: Text;
        IDValue: Text;
    begin
        // Get field values
        TIN := CustomerRec."e-Invoice TIN No.";
        IDType := Format(CustomerRec."e-Invoice ID Type");
        IDValue := CustomerRec."e-Invoice ID No.";

        // Validate inputs
        if TIN = '' then
            Error('Customer does not have a TIN No.');
        if IDType = '' then
            Error('Customer does not have an e-Invoice ID Type.');
        if IDValue = '' then
            Error('Customer does not have an e-Invoice ID No.');
        if not MyInvoisSetup.Get('API SETUP') then
            Error('eInvois API Setup not found.');

        // Get token
        Token := TokenHelper.GetAccessTokenFromSetup(MyInvoisSetup);

        // Build URL
        if MyInvoisSetup.Environment = MyInvoisSetup.Environment::Preprod then
            URL := StrSubstNo(
                'https://preprod-api.myinvois.hasil.gov.my/api/v1.0/taxpayer/validate/%1?idType=%2&idValue=%3',
                TIN, IDType, IDValue)
        else
            URL := StrSubstNo(
                'https://api.myinvois.hasil.gov.my/api/v1.0/taxpayer/validate/%1?idType=%2&idValue=%3',
                TIN, IDType, IDValue);

        // Make HTTP call
        HttpClient.DefaultRequestHeaders().Clear();
        HttpClient.DefaultRequestHeaders().Add('Authorization', 'Bearer ' + Token);
        HttpClient.Get(URL, Response);

        // Handle response purely based on status code (no body parsing)
        case Response.HttpStatusCode() of
            200:
                begin
                    CustomerRec."Validation Status" := CustomerRec."Validation Status"::"Valid";
                    CustomerRec."Last TIN Validation" := CurrentDateTime();
                    CustomerRec.Modify();
                    exit(StrSubstNo('TIN: %1\nStatus: Valid', TIN));
                end;

            400:
                begin
                    CustomerRec."Validation Status" := CustomerRec."Validation Status"::"Invalid Input";
                    CustomerRec."Last TIN Validation" := CurrentDateTime();
                    CustomerRec.Modify();
                    Error('TIN validation failed: Bad input format (400).\nPlease check the TIN, ID Type, or ID No.');
                end;

            404:
                begin
                    CustomerRec."Validation Status" := CustomerRec."Validation Status"::"Not Found";
                    CustomerRec."Last TIN Validation" := CurrentDateTime();
                    CustomerRec.Modify();
                    exit(StrSubstNo('TIN: %1\nNo taxpayer found for this TIN and ID combination.', TIN));
                end;

            else begin
                CustomerRec."Validation Status" := CustomerRec."Validation Status"::"API Error";
                CustomerRec."Last TIN Validation" := CurrentDateTime();
                CustomerRec.Modify();
                Error('TIN validation failed (status %1).', Response.HttpStatusCode());
            end;
        end;
    end;
}
