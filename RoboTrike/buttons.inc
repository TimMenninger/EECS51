;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                                        ;
;                                         BUTTONS                                        ;
;                    Contains Constants Related to Buttons and Debouncing                ;
;                                      Tim Menninger                                     ;
;                                                                                        ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;
; Description:		Contains constants keypresses and debouncing of those keypresses.
;
; Revision History:
;		11/14/14	Tim Menninger	Created
;		12/11/14	Tim Menninger	Added documentation
;

;Constants related to button presses

BUTTON_DEFAULT		EQU		0FH		;value at ports if button is not pushed
DEBOUNCE_TIME		EQU		30		;number of milliseconds before button considered pushed
SLOW_RATE			EQU		1000	;number of milliseconds between event enqueues for first
									;	(FAST_REPEAT_TIME) milliseconds
BUTTON_EVENT_CODE	EQU		80H		;code corresponding to button push
NUM_ROWS			EQU		4		;number of rows of buttons
NUM_COLS            EQU     4       ;number of columns of buttons
FIRST_ROW			EQU		0		;starting at the 0th row
BUTTON_PORT			EQU		80H		;port of first row of buttons
KEY_EVENT			EQU		0		;high bit of enqueue value
IMPORTANT_BITS		EQU		0FH		;only the last four bits of the value at the key port are
									;	important.  we will AND with this to slice off top
									;	four bits