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
                field("eInvoice Version"; Rec."eInvoice Version")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the e-Invoice version to use for submission to LHDN (e.g. 1.0 or 1.1).';
                }

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
