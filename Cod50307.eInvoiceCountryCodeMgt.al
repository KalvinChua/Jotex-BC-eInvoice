codeunit 50307 "e-Invoice Country Code Mgt"
{
    [EventSubscriber(ObjectType::Table, Database::Customer, 'OnAfterValidateEvent', 'Country/Region Code', false, false)]
    local procedure UpdateEInvoiceCountryCodeOnCountryChange(var Rec: Record Customer; var xRec: Record Customer)
    var
        CompanyInfo: Record "Company Information";
    begin
        // Only process for JOTEX SDN BHD
        if not CompanyInfo.Get() or (CompanyInfo.Name <> 'JOTEX SDN BHD') then
            exit;

        if Rec."Country/Region Code" = 'MY' then
            Rec."e-Invoice Country Code" := 'MYS';
    end;

    [EventSubscriber(ObjectType::Page, Page::"Customer Card", 'OnAfterGetCurrRecordEvent', '', false, false)]
    local procedure UpdateEInvoiceCountryCodeOnPageOpen(var Rec: Record Customer)
    var
        CompanyInfo: Record "Company Information";
    begin
        // Only process for JOTEX SDN BHD
        if not CompanyInfo.Get() or (CompanyInfo.Name <> 'JOTEX SDN BHD') then
            exit;

        if (Rec."e-Invoice Country Code" = '') and (Rec."Country/Region Code" = 'MY') then
            Rec."e-Invoice Country Code" := 'MYS';
    end;
}