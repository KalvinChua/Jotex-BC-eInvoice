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
                field("Client ID"; Rec."Client ID")
                {
                    ApplicationArea = All;
                }
                field("Client Secret"; Rec."Client Secret")
                {
                    ApplicationArea = All;
                }
                field("Environment"; Rec.Environment)
                {
                    ApplicationArea = All;
                }
                field("eInvoice Version"; Rec."eInvoice Version")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the e-Invoice version to use for submission to LHDN (e.g. 1.0 or 1.1).';
                }
                // New field for Azure Function URL
                field("Azure Function URL"; Rec."Azure Function URL")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Azure Function endpoint for e-Invoice signing and submission.';
                }
            }

            group("Token Info")
            {
                field("Last Token"; Rec."Last Token")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Token Timestamp"; Rec."Token Timestamp")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
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

            action(GetDocumentTypes)
            {
                Caption = 'Get LHDN Document Types';
                ApplicationArea = All;
                Image = Document;
                ToolTip = 'Retrieve all available document types from LHDN MyInvois API';

                trigger OnAction()
                var
                    eInvoiceJsonCodeunit: Codeunit "eInvoice 1.0 Invoice JSON";
                    DocumentTypesResponse: Text;
                begin
                    if eInvoiceJsonCodeunit.GetLhdnDocumentTypes(DocumentTypesResponse) then begin
                        // Success message is already shown in the procedure
                    end;
                    // Error handling is done in the procedure
                end;
            }

            action(GetNotifications)
            {
                Caption = 'Get LHDN Notifications';
                ApplicationArea = All;
                Image = Email;
                ToolTip = 'Retrieve notifications from LHDN MyInvois system';

                trigger OnAction()
                var
                    eInvoiceJsonCodeunit: Codeunit "eInvoice 1.0 Invoice JSON";
                    NotificationsResponse: Text;
                    DateFrom: Date;
                    DateTo: Date;
                begin
                    // Get notifications for the last 7 days
                    DateFrom := CalcDate('-7D', Today);
                    DateTo := Today;

                    if eInvoiceJsonCodeunit.GetLhdnNotifications(NotificationsResponse, DateFrom, DateTo, 0, 1, 50) then begin
                        // Success message is already shown in the procedure
                    end;
                    // Error handling is done in the procedure
                end;
            }
        }
    }

    trigger OnOpenPage()
    var
        Setup: Record eInvoiceSetup;
    begin
        if not Setup.Get('SETUP') then begin
            Setup.Init();
            Setup."Primary Key" := 'SETUP';
            Setup.Insert();
        end;
        // Ensure the page is showing the SETUP record
        Rec.Get('SETUP');
    end;
}
