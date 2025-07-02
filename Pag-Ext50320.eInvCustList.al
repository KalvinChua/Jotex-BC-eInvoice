pageextension 50320 eInvCustList extends "Customer List"
{
    layout
    {
        addafter(Contact)
        {
            field("e-Invoice TIN No."; Rec."e-Invoice TIN No.")
            {
                ApplicationArea = All;
                Caption = 'e-Invoice TIN No.';
                Editable = true;
                Visible = true;
            }
            field("e-Invoice SST No."; Rec."e-Invoice SST No.")
            {
                ApplicationArea = All;
                Caption = 'e-Invoice SST No.';
                Editable = true;
                Visible = true;
            }
            field("e-Invoice Country Code"; Rec."e-Invoice Country Code")
            {
                ApplicationArea = All;
                Caption = 'e-Invoice Country Code';
                Editable = true;
                Visible = true;
            }
            field("e-Invoice State Code"; Rec."e-Invoice State Code")
            {
                ApplicationArea = All;
                Caption = 'e-Invoice State Code';
                Editable = true;
                Visible = true;
            }
            field("e-Invoice ID Type"; Rec."e-Invoice ID Type")
            {
                ApplicationArea = All;
                Caption = 'e-Invoice ID Type.';
                Editable = true;
                Visible = true;
            }
            field("e-Invoice ID No."; Rec."e-Invoice ID No.")
            {
                ApplicationArea = All;
                Caption = 'e-Invoice ID No.';
                Editable = true;
                Visible = true;
            }
        }
    }

    actions
    {
        addfirst(Processing)
        {
            action(PopulateEInvoiceStateCodes)
            {
                ApplicationArea = All;
                Caption = 'Populate State Codes';
                Image = Change;
                ToolTip = 'Populate e-Invoice State Codes based on County values';

                trigger OnAction()
                var
                    Customer: Record Customer;
                    UpdatedCount: Integer;
                begin
                    if Confirm('Do you want to populate e-Invoice State Codes for all customers based on their County?', false) then begin
                        Customer.SetRange("e-Invoice State Code", '');
                        if Customer.FindSet() then
                            repeat
                                if Customer.County <> '' then begin
                                    Customer."e-Invoice State Code" := GetStateCode(Customer.County);
                                    Customer.Modify();
                                    UpdatedCount += 1;
                                end;
                            until Customer.Next() = 0;

                        Message('%1 customer(s) had their e-Invoice State Code populated.', UpdatedCount);
                    end;
                end;
            }

            action(PopulateEInvoiceCountryCodes)
            {
                ApplicationArea = All;
                Caption = 'Populate Country Codes';
                Image = CountryRegion;
                ToolTip = 'Populate e-Invoice Country Codes (MY->MYS, SG->SGP)';

                trigger OnAction()
                var
                    Customer: Record Customer;
                    UpdatedCount: Integer;
                begin
                    if Confirm('Do you want to populate e-Invoice Country Codes for all customers?', false) then begin
                        Customer.SetRange("e-Invoice Country Code", '');
                        if Customer.FindSet() then
                            repeat
                                case Customer."Country/Region Code" of
                                    'MY':
                                        begin
                                            Customer."e-Invoice Country Code" := 'MYS';
                                            Customer.Modify();
                                            UpdatedCount += 1;
                                        end;
                                    'SG':
                                        begin
                                            Customer."e-Invoice Country Code" := 'SGP';
                                            Customer.Modify();
                                            UpdatedCount += 1;
                                        end;
                                end;
                            until Customer.Next() = 0;

                        Message('%1 customer(s) had their e-Invoice Country Code populated.', UpdatedCount);
                    end;
                end;
            }
        }
    }

    local procedure GetStateCode(CountyText: Text): Code[2]
    begin
        case UpperCase(CountyText) of
            'JOHOR':
                exit('01');
            'KEDAH':
                exit('02');
            'KELANTAN':
                exit('03');
            'MELAKA', 'MALACCA':
                exit('04');
            'NEGERI SEMBILAN', 'N.SEMBILAN':
                exit('05');
            'PAHANG':
                exit('06');
            'PULAU PINANG', 'PENANG':
                exit('07');
            'PERAK':
                exit('08');
            'PERLIS':
                exit('09');
            'SELANGOR':
                exit('10');
            'TERENGGANU':
                exit('11');
            'SABAH':
                exit('12');
            'SARAWAK':
                exit('13');
            'WILAYAH PERSEKUTUAN KUALA LUMPUR', 'KUALA LUMPUR', 'WP KUALA LUMPUR':
                exit('14');
            'WILAYAH PERSEKUTUAN LABUAN', 'LABUAN', 'WP LABUAN':
                exit('15');
            'WILAYAH PERSEKUTUAN PUTRAJAYA', 'PUTRAJAYA', 'WP PUTRAJAYA':
                exit('16');
            else
                exit('17'); // Not Applicable
        end;
    end;
}