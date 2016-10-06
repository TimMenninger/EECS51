;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                                        ;
;                                     MAIN CONSTANTS                                     ;
;             Contains Constants for Both the Motor and Controller Main Loops            ;
;                                      Tim Menninger                                     ;
;                                                                                        ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;
; Description:		Contains constants for the motor and controller target board main
;					loops.
;
; Revision History:
;		12/11/14	Tim Menninger	Created
;

; Error constants
NO_ERROR		EQU	0				;event code indicating no errors
FTL_ERR_CODE	EQU	00001001B		;event code for fatal errors
PARSE_ERROR		EQU	00001000B		;event code for parsing error
UNKNOWN_ERROR	EQU	0				;event code for unknown error
MAX_ERROR_CODE	EQU	9				;error codes count from 1.  if we have an error code
									;	greater than this, we don't know what it is

; Event constants
CHECK_BUTTON	EQU	10000000B		;mask to check if event code is button press
IS_BUTTON		EQU	10000000B		;after masking, button press should be IS_BUTTON
BUTTONEC_MASK	EQU	11110000B		;masks unused bits of event code

; Command constants
SPEED_UP_VAL	EQU	2048			;amount to speed up by when speed up command found
SLOW_DWN_VAL	EQU	-2048			;amount to slow down by when speed up command found