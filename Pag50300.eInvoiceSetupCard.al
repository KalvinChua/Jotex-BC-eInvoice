page 50300 eInvoiceSetupCard
{
    PageType = Card;
    SourceTable = eInvoiceSetup;
    Caption = 'e-Invoice Setup';
    UsageCategory = Administration;
    ApplicationArea = All;

    layout
    {
        area(content)
        {
            group("API Configuration")
            {
                field("Client ID"; Rec."Client ID") { ApplicationArea = All; }
                field("Client Secret"; Rec."Client Secret") { ApplicationArea = All; }
                field("Environment"; Rec.Environment) { ApplicationArea = All; }
            }

            group("Token Info")
            {
                field("Last Token"; Rec."Last Token") { ApplicationArea = All; Editable = false; }
                field("Token Timestamp"; Rec."Token Timestamp") { ApplicationArea = All; Editable = false; }
            }
        }
    }


    actions
    {
        area(processing)
        {
            action(TestConnection)
            {
                Caption = 'Test Connection';
                ApplicationArea = All;
                Image = Action;

                trigger OnAction()
                var
                    Token: Text;
                    MyInvoisHelper: Codeunit eInvoiceHelper;
                begin
                    Token := MyInvoisHelper.GetAccessTokenFromSetup(Rec);
                    Message('Access token retrieved: %1', CopyStr(Token, 1, 50) + '...');
                end;
            }
            action(OpenCompanyInfo)
            {
                Caption = 'Open Company Info';
                ApplicationArea = All;
                Image = View;

                trigger OnAction()
                var
                    CompanyInfoRec: Record "e-Invoice Company Info";
                begin
                    if Rec."Company Info Code" = '' then
                        Error('No Company Info Code is set.');

                    if CompanyInfoRec.Get(Rec."Company Info Code") then
                        PAGE.Run(PAGE::"e-Invoice Company Info Card", CompanyInfoRec)
                    else
                        Error('The selected Company Info record was not found.');
                end;
            }

        }
    }

    trigger OnOpenPage()
    var
        Setup: Record eInvoiceSetup;
    begin
        if not Setup.Get('API SETUP') then begin
            Setup.Init();
            Setup."Primary Key" := 'API SETUP';
            Setup.Insert();
        end;
    end;
}
