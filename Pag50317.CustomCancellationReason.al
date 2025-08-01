page 50317 "Custom Cancellation Reason"
{
    Caption = 'Enter Custom Cancellation Reason';
    PageType = StandardDialog;
    SourceTable = Integer;
    SourceTableTemporary = true;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'Cancellation Details';

                field(ReasonText; CancellationReason)
                {
                    ApplicationArea = All;
                    Caption = 'Cancellation Reason';
                    ToolTip = 'Enter the specific reason for cancelling this e-Invoice. This will be sent to LHDN and recorded in the submission log.';
                    MultiLine = true;

                    trigger OnValidate()
                    begin
                        // Ensure reason is not empty and within limits
                        if StrLen(CancellationReason) = 0 then
                            Error('Cancellation reason cannot be empty.');

                        if StrLen(CancellationReason) > 500 then
                            Error('Cancellation reason cannot exceed 500 characters. Current length: %1', StrLen(CancellationReason));
                    end;
                }

                field(CharacterCount; StrLen(CancellationReason))
                {
                    ApplicationArea = All;
                    Caption = 'Character Count';
                    Editable = false;
                    ToolTip = 'Current character count (maximum 500 allowed)';
                }
            }

            group(Instructions)
            {
                Caption = 'Guidelines';

                field(InstructionText; 'Please provide a clear and specific reason for cancellation. This information will be:\- Sent to LHDN MyInvois system\- Recorded in your submission log\- Used for audit and compliance purposes')
                {
                    ApplicationArea = All;
                    Caption = 'Instructions';
                    Editable = false;
                    MultiLine = true;
                    ShowCaption = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(OK)
            {
                ApplicationArea = All;
                Caption = 'OK';
                Image = Confirm;
                InFooterBar = true;

                trigger OnAction()
                begin
                    if StrLen(CancellationReason) = 0 then
                        Error('Please enter a cancellation reason before proceeding.');

                    CurrPage.Close();
                end;
            }

            action(Cancel)
            {
                ApplicationArea = All;
                Caption = 'Cancel';
                Image = Cancel;
                InFooterBar = true;

                trigger OnAction()
                begin
                    CancellationReason := '';
                    CurrPage.Close();
                end;
            }
        }
    }

    var
        CancellationReason: Text[500];

    /// <summary>
    /// Get the cancellation reason entered by the user
    /// </summary>
    /// <returns>The cancellation reason text</returns>
    procedure GetCancellationReason(): Text[500]
    begin
        exit(CancellationReason);
    end;

    /// <summary>
    /// Set a default cancellation reason
    /// </summary>
    /// <param name="DefaultReason">Default reason to display</param>
    procedure SetDefaultReason(DefaultReason: Text[500])
    begin
        CancellationReason := DefaultReason;
    end;
}
