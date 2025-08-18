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
            field("Validation Status"; Rec."Validation Status")
            {
                ApplicationArea = All;
                Caption = 'TIN Validation Status';
                Editable = false;
                Visible = true;
                ToolTip = 'Shows the current TIN validation status for this customer';
            }
            field("Last TIN Validation"; Rec."Last TIN Validation")
            {
                ApplicationArea = All;
                Caption = 'Last TIN Validation';
                Editable = false;
                Visible = true;
                ToolTip = 'Shows when the TIN was last validated';
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
                    if Confirm('Do you want to populate e-Invoice State Codes for all customers based on their County?') then begin
                        Customer.SetRange("e-Invoice State Code", '');
                        if Customer.FindSet() then
                            repeat
                                if Customer.County <> '' then begin
                                    Customer."e-Invoice State Code" := GetStateCode(Customer.County);
                                    Customer.Modify();
                                    UpdatedCount += 1;
                                end;
                            until Customer.Next() = 0;

                        Message(StrSubstNo('%1 customer(s) had their e-Invoice State Code populated.', UpdatedCount));
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
                    if Confirm('Do you want to populate e-Invoice Country Codes for all customers?') then begin
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

                        Message(StrSubstNo('%1 customer(s) had their e-Invoice Country Code populated.', UpdatedCount));
                    end;
                end;
            }

            action(SetAllCustomersRequireEInvoice)
            {
                ApplicationArea = All;
                Caption = 'Set All Require e-Invoice';
                Image = Check;
                ToolTip = 'Set all customers to require e-Invoice submission';

                trigger OnAction()
                var
                    CustomerBulkUpdate: Codeunit "eInvoice Customer Bulk Update";
                begin
                    if Confirm('Do you want to set ALL customers to require e-Invoice? This will enable automatic submission for all customers.') then begin
                        CustomerBulkUpdate.SetAllCustomersRequireEInvoice();
                    end;
                end;
            }

            action(ShowCustomerEInvoiceStatus)
            {
                ApplicationArea = All;
                Caption = 'Show e-Invoice Status';
                Image = Statistics;
                ToolTip = 'Show current status of customer e-Invoice requirements';

                trigger OnAction()
                var
                    CustomerBulkUpdate: Codeunit "eInvoice Customer Bulk Update";
                begin
                    CustomerBulkUpdate.ShowCustomerEInvoiceStatus();
                end;
            }

            action(ResetAllCustomersEInvoiceRequirement)
            {
                ApplicationArea = All;
                Caption = 'Reset All e-Invoice Requirements';
                Image = Cancel;
                ToolTip = 'Reset all customers to NOT require e-Invoice (revert changes)';

                trigger OnAction()
                var
                    CustomerBulkUpdate: Codeunit "eInvoice Customer Bulk Update";
                begin
                    if Confirm('Do you want to reset ALL customers to NOT require e-Invoice? This will disable automatic submission for all customers.') then begin
                        CustomerBulkUpdate.ResetAllCustomersEInvoiceRequirement();
                    end;
                end;
            }

            action(ValidateTIN)
            {
                ApplicationArea = All;
                Caption = 'Validate TIN No.';
                Image = Check;
                ToolTip = 'Validate the selected customer''s TIN using MyInvois API';

                trigger OnAction()
                var
                    Validator: Codeunit "eInvoice TIN Validator";
                    Msg: Text;
                begin
                    if Rec."e-Invoice TIN No." = '' then
                        Error('Please select a customer with a TIN No. to validate.');

                    Msg := Validator.ValidateTIN(Rec);
                    Message(Msg);
                    CurrPage.Update(false);
                end;
            }

            action(ValidateMultipleTINs)
            {
                ApplicationArea = All;
                Caption = 'Validate Multiple TINs';
                Image = CheckList;
                ToolTip = 'Validate TIN for all customers that have TIN numbers but haven''t been validated recently';

                trigger OnAction()
                var
                    Customer: Record Customer;
                    Validator: Codeunit "eInvoice TIN Validator";
                    ValidatedCount: Integer;
                    ErrorCount: Integer;
                    ProgressDialog: Dialog;
                    TotalCount: Integer;
                    CurrentCount: Integer;
                begin
                    if not Confirm('Do you want to validate TIN numbers for all customers that have TIN but haven''t been validated in the last 180 days?') then
                        exit;

                    Customer.Reset();
                    Customer.SetFilter("e-Invoice TIN No.", '<>%1', '');
                    Customer.SetFilter("e-Invoice ID Type", '<>%1', 0);
                    Customer.SetFilter("e-Invoice ID No.", '<>%1', '');
                    TotalCount := Customer.Count();

                    if TotalCount = 0 then begin
                        Message('No customers found with complete TIN information.');
                        exit;
                    end;

                    ProgressDialog.Open('Validating TIN #1####### of #2####### customers...\Current: #3#########');

                    if Customer.FindSet() then
                        repeat
                            CurrentCount += 1;
                            ProgressDialog.Update(1, CurrentCount);
                            ProgressDialog.Update(2, TotalCount);
                            ProgressDialog.Update(3, Customer."No." + ' - ' + Customer.Name);

                            if ShouldValidateTIN(Customer) then begin
                                if TryValidateTIN(Customer, Validator) then
                                    ValidatedCount += 1
                                else
                                    ErrorCount += 1;
                            end;
                        until Customer.Next() = 0;

                    ProgressDialog.Close();
                    Message('TIN validation completed.\Validated: %1\Errors: %2\Total processed: %3', ValidatedCount, ErrorCount, CurrentCount);
                    CurrPage.Update(false);
                end;
            }
        }
    }

    local procedure ShouldValidateTIN(var Customer: Record Customer): Boolean
    var
        CutoffDate: Date;
    begin
        // Skip if missing required fields
        if (Customer."e-Invoice TIN No." = '') or
           (Customer."e-Invoice ID Type" = 0) or
           (Customer."e-Invoice ID No." = '') then
            exit(false);

        // Validate if never validated or last validation was more than 180 days ago
        CutoffDate := CalcDate('<-180D>', Today);
        exit((Customer."Last TIN Validation" = 0DT) or (DT2Date(Customer."Last TIN Validation") < CutoffDate));
    end;

    local procedure TryValidateTIN(var Customer: Record Customer; var Validator: Codeunit "eInvoice TIN Validator"): Boolean
    var
        Msg: Text;
    begin
        if not Customer.Get(Customer."No.") then
            exit(false);

        Commit();
        if not Codeunit.Run(Codeunit::"eInvoice TIN Validator", Customer) then
            exit(false);

        exit(true);
    end;

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