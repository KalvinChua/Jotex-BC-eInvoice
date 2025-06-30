codeunit 50308 "e-Invoice State Code Mgt"
{
    [EventSubscriber(ObjectType::Table, Database::Customer, 'OnAfterValidateEvent', 'County', false, false)]
    local procedure UpdateEInvoiceStateCodeOnCountyChange(var Rec: Record Customer; var xRec: Record Customer)
    begin
        UpdateEInvoiceStateCode(Rec);
    end;

    [EventSubscriber(ObjectType::Page, Page::"Customer Card", 'OnAfterGetCurrRecordEvent', '', false, false)]
    local procedure UpdateEInvoiceStateCodeOnPageOpen(var Rec: Record Customer)
    begin
        UpdateEInvoiceStateCode(Rec);
    end;

    local procedure UpdateEInvoiceStateCode(var Customer: Record Customer)
    begin
        if Customer.County = '' then begin
            Customer."e-Invoice State Code" := '';
            exit;
        end;

        case UpperCase(Customer.County) of
            'JOHOR':
                Customer."e-Invoice State Code" := '01';
            'KEDAH':
                Customer."e-Invoice State Code" := '02';
            'KELANTAN':
                Customer."e-Invoice State Code" := '03';
            'MELAKA', 'MALACCA':
                Customer."e-Invoice State Code" := '04';
            'NEGERI SEMBILAN':
                Customer."e-Invoice State Code" := '05';
            'PAHANG':
                Customer."e-Invoice State Code" := '06';
            'PULAU PINANG', 'PENANG':
                Customer."e-Invoice State Code" := '07';
            'PERAK':
                Customer."e-Invoice State Code" := '08';
            'PERLIS':
                Customer."e-Invoice State Code" := '09';
            'SELANGOR':
                Customer."e-Invoice State Code" := '10';
            'TERENGGANU':
                Customer."e-Invoice State Code" := '11';
            'SABAH':
                Customer."e-Invoice State Code" := '12';
            'SARAWAK':
                Customer."e-Invoice State Code" := '13';
            'WILAYAH PERSEKUTUAN KUALA LUMPUR', 'KUALA LUMPUR', 'WP KUALA LUMPUR':
                Customer."e-Invoice State Code" := '14';
            'WILAYAH PERSEKUTUAN LABUAN', 'LABUAN', 'WP LABUAN':
                Customer."e-Invoice State Code" := '15';
            'WILAYAH PERSEKUTUAN PUTRAJAYA', 'PUTRAJAYA', 'WP PUTRAJAYA':
                Customer."e-Invoice State Code" := '16';
            else
                Customer."e-Invoice State Code" := '17'; // Not Applicable
        end;
    end;
}