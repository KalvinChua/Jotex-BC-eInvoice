page 50318 "eInv Date Range Picker"
{
    PageType = StandardDialog;
    ApplicationArea = All;
    Caption = 'Select Date Range';

    layout
    {
        area(content)
        {
            group(General)
            {
                field(FromDate; FromDate)
                {
                    ApplicationArea = All;
                    Caption = 'From Date';
                }
                field(ToDate; ToDate)
                {
                    ApplicationArea = All;
                    Caption = 'To Date';
                }
            }
        }
    }

    var
        FromDate: Date;
        ToDate: Date;

    procedure SetInitialDates(NewFromDate: Date; NewToDate: Date)
    begin
        FromDate := NewFromDate;
        ToDate := NewToDate;
    end;

    procedure GetDates(var OutFromDate: Date; var OutToDate: Date)
    begin
        OutFromDate := FromDate;
        OutToDate := ToDate;
    end;
}


