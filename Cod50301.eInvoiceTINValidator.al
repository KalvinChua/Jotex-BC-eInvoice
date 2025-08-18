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
        TinLog: Record "eInvoice TIN Log";
        CachedMsg: Text;
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

        // Reuse cached result if validated recently (180 days)
        if TryGetCachedTinStatus(CustomerRec, TIN, IDType, IDValue, CachedMsg) then
            exit(CachedMsg);

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
        HttpClient.DefaultRequestHeaders().Add('Accept', 'application/json');
        HttpClient.DefaultRequestHeaders().Add('User-Agent', 'BC-eInvoice/1.0');
        HttpClient.Get(URL, Response);

        // Handle response purely based on status code (no body parsing)
        case Response.HttpStatusCode() of
            200:
                begin
                    CustomerRec."Validation Status" := CustomerRec."Validation Status"::"Valid";
                    CustomerRec."Last TIN Validation" := CurrentDateTime();
                    CustomerRec.Modify();
                    InsertTinLog(CustomerRec, TIN, 'Valid', IDType, IDValue);
                    exit(StrSubstNo('TIN: %1' + '\' + 'Status: Valid', TIN));
                end;

            400:
                begin
                    CustomerRec."Validation Status" := CustomerRec."Validation Status"::"Invalid Input";
                    CustomerRec."Last TIN Validation" := CurrentDateTime();
                    CustomerRec.Modify();
                    InsertTinLog(CustomerRec, TIN, 'Invalid Input', IDType, IDValue);
                    Error('TIN validation failed: Bad input format (400).' + '\' + 'Please check the TIN, ID Type, or ID No.');
                end;

            404:
                begin
                    CustomerRec."Validation Status" := CustomerRec."Validation Status"::"Not Found";
                    CustomerRec."Last TIN Validation" := CurrentDateTime();
                    CustomerRec.Modify();
                    InsertTinLog(CustomerRec, TIN, 'Not Found', IDType, IDValue);
                    exit(StrSubstNo('TIN: %1' + '\' + 'No taxpayer found for this TIN and ID combination.', TIN));
                end;

            else begin
                CustomerRec."Validation Status" := CustomerRec."Validation Status"::"API Error";
                CustomerRec."Last TIN Validation" := CurrentDateTime();
                CustomerRec.Modify();
                InsertTinLog(CustomerRec, TIN, 'API Error', IDType, IDValue);
                Error('TIN validation failed (status %1).', Response.HttpStatusCode());
            end;
        end;
    end;

    local procedure TryGetCachedTinStatus(var CustomerRec: Record Customer; Tin: Text; IdType: Text; IdValue: Text; var MessageText: Text): Boolean
    var
        Log: Record "eInvoice TIN Log";
        CutoffDate: Date;
        StatusText: Text;
    begin
        CutoffDate := CalcDate('<-180D>', Today);
        Log.Reset();
        Log.SetRange("Customer No.", CustomerRec."No.");
        Log.SetRange("TIN", CopyStr(Tin, 1, 20));
        Log.SetRange("ID Type", IdType);
        Log.SetRange("ID Value", IdValue);
        if Log.FindLast() then begin
            if DT2Date(Log."Response Time") >= CutoffDate then begin
                StatusText := Log."TIN Status";
                case StatusText of
                    'Valid':
                        begin
                            CustomerRec."Validation Status" := CustomerRec."Validation Status"::"Valid";
                            CustomerRec."Last TIN Validation" := CurrentDateTime();
                            CustomerRec.Modify();
                            MessageText := StrSubstNo('TIN: %1' + '\' + 'Status: Valid (cached)', Tin);
                            exit(true);
                        end;
                    'Not Found':
                        begin
                            CustomerRec."Validation Status" := CustomerRec."Validation Status"::"Not Found";
                            CustomerRec."Last TIN Validation" := CurrentDateTime();
                            CustomerRec.Modify();
                            MessageText := StrSubstNo('TIN: %1' + '\' + 'No taxpayer found (cached).', Tin);
                            exit(true);
                        end;
                end;
            end;
        end;
        exit(false);
    end;

    local procedure InsertTinLog(var CustomerRec: Record Customer; Tin: Text; StatusText: Text; IdType: Text; IdValue: Text)
    var
        Log: Record "eInvoice TIN Log";
    begin
        Log.Init();
        Log.Validate("Customer No.", CustomerRec."No.");
        Log.Validate("Customer Name", CustomerRec.Name);
        Log.Validate("TIN", CopyStr(Tin, 1, 20));
        Log.Validate("TIN Status", StatusText);
        Log.Validate("Response Time", CurrentDateTime());
        Log.Validate("ID Type", IdType);
        Log.Validate("ID Value", CopyStr(IdValue, 1, 150));
        Log.Insert(true);
    end;
}
