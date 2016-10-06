        NAME    Buttons

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                                        ;
;                                         BUTTONS                                        ;
;                                    Buttonpush Handler                                  ;
;                                      Tim Menninger                                     ;
;                                                                                        ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


; 
;Description:		This has the code that handles button presses on the target board by
;					scanning through each row and determining whether a button in that
;					row is pressed or not.  If it is, it debounces the button before 
;					declaring it pressed.
;
;Contents:			ButtonInit 	  - initializes variables to their no-buttons-pushed state
;					ButtonHandler - scans for button presses and debounces when a button
;									is found to have been pressed
;
;Input:				Keypad - this program initializes the keypad and is called by the
;							 event handler to scan for buttonpushes, debounce buttons and
;							 respond to button pushes.
;
;Output:			None.
;
;Error Handling:	None.
;
;Data Structures:	None.
;
;Revision History:	11/14/14	Tim Menninger	Created
;                   12/11/14    Tim Menninger   Changed button event codes to range from
;                                               1 to [number of buttons]
;


		
$INCLUDE(buttons.inc)					;this file contains constants related to button
										;	presses and related processes


CGROUP  GROUP   CODE
DGROUP	GROUP	DATA


CODE	SEGMENT PUBLIC 'CODE'


        ASSUME  CS:CGROUP, DS:DGROUP
        
        EXTRN EnqueueEvent : NEAR		;enqueues the value of a pushed key stored in AX
		
        
        
;
; ButtonInit
;
; Description:       This procedure initializes variables related to the
;					 keypad, preparing the for the event handler to correctly
;					 handle events.
;
; Operation:         This function sets shared variables to their initial values
;					 one at a time.
;
; Arguments:         None.
;
; Return Value:      None.
;
; Local Variables:   None.
;
; Shared Variables:  curr_row (WRITE) - keeps track of the row that is currently being
;								scanned for button pushes
;					 debounce_cntr (WRITE) - counts how long the button has been pressed
;
; Global Variables:  None.
;
; Input:             None.
;
; Output:            None.
;
; Error Handling:    None.
;
; Algorithms:        None.
;
; Data Structures:   None.
;
; Registers Changed: None
;
; Revision History:	 01/27/03	Glen George		Created
;					 11/14/14	Tim Menninger	Adapted to supplement RoboTrike
;												processes
;					 12/11/14	Tim Menninger	changed button labels, added documentation
;

ButtonInit      PROC        NEAR
                PUBLIC      ButtonInit

InitButtonVars:							;reset variables if no buttons are pushed
	MOV  curr_row, FIRST_ROW			;obviously starting at first row
	MOV  debounce_cntr, DEBOUNCE_TIME	;reset our debounce counter (it counts down)
	RET

ButtonInit		ENDP


;
; ButtonHandler
;
; Description:       This procedure checks if a button is being pressed.
;					 If there is, it checks to make sure it is still pressed.
;					 If the button is no longer pressed, or there was no
;					 button pressed to begin with, it scans one row for a
;					 pressed button.
;
; Operation:         This function checks the current row for a pressed
;					 button.  If it finds that there is no button pressed,
;					 It scans the next row for a pressed button.  If there
;					 is a button pressed, it checks if it is the same one
;					 that was pressed during the previouis interrupt.  If
;					 it is the same, it debounces that button.  If it is
;					 different, it updates the most recent pushed button
;					 and returns.
;
;					 When it scans the next row for a button, it checks if
;					 the value of that row is the default value corresponding
;					 to no buttons pushed.  If it is, it increments current
;					 row and returns.  If it comes back with a button-push
;					 value, then it sets the last button to that value and
;					 returns without incrementing curr_row because the next
;					 time we will check to see if the button is still pushed.
;
;					 When it debounces a button, it starts from a certain
;					 debounce time and counts down.  If at any time the button
;					 stops being pushed (presumably due to bouncing), it stops
;					 counting and will restart when it is pushed again.  When
;					 the counter reaches 0, the button has been down for the
;					 desired amount of time and the program then considers it
;					 to be fully pressed, at which point the function processes
;					 the button push by calling EnqueueEvent.  The debounce
;					 counter decrements once per function call.
;
;					 When it calls EnqueueEvent, it calls it with the argument
;					 in AX.  Thus the value enqueued is going to have the event code
;                    in the high bit of AL, the button number in the lower seven bits
;                    of AL, and AH cleared.
;
;					 After the first time an event is enqueued, it enters an
;					 auto repeat mode, where the counter for debouncing is 
;					 set to a time that corresponds to how frequently the
;					 event should be enqueued until the button is no longer
;					 pressed.
;
; Arguments:         None.
;
; Return Value:      None.
;
; Local Variables:   AX - the value corresponding to the pushed button
;
; Shared Variables:  curr_row - the row that the scanner is currently scanning
;					 last_button - the last button that was pushed
;					 
;
; Global Variables:  None.
;
; Input:             Keypad - timer interrupt searches for keypresses and
;					 responds accordingly
;
; Output:            None.
;
; Error Handling:    None.
;
; Algorithms:        None.
;
; Data Structures:   None.
;
; Registers Changed: None
;
; Limitations:		 If multiple buttons are pressed from two or more different rows, only
;					 button presses from the row closest to the top will be recognized.
;
; Revision History:	 01/27/03	Glen George		Created
;					 11/14/14	Tim Menninger	Adapted to supplement RoboTrike
;												processes

ButtonHandler	PROC		NEAR
				PUBLIC		ButtonHandler

	PUSHA
	
ButtonHandlerInit:
	MOV  DX, BUTTON_PORT
	ADD  DX, curr_row					;after this, we have port for specific row
	IN   AL, DX
	AND  AL, IMPORTANT_BITS				;only want to consider certain bits
	CMP  AL, BUTTON_DEFAULT				;only want to scan if last_button is the default state
	JE   RowScan
	JNE  RecheckButton

RecheckButton:						
	CMP  AL, last_button				;check that the button is still being pushed
	JE   DebounceButton					
	JNE  DiffButtonPushed
	
RowScan:
	IN   AL, DX
	AND  AL, IMPORTANT_BITS				;only want to consider certain bits
	
	CMP  AL, BUTTON_DEFAULT				;compare it to the default (unpressed) value
	JNE  DiffButtonPushed
	INC  curr_row
	CMP  curr_row, NUM_ROWS				;check if we have checked all of the rows
	JAE  WrapRowCount					;if equal (or above) no buttons are pushed so stop
	JMP  ReturnFromBH
	
WrapRowCount:
	MOV  curr_row, FIRST_ROW			;reset our current row counter
	JMP  ReturnFromBH				

DiffButtonPushed:
	CALL ButtonInit						;resets all of the counters and variables
	MOV  last_button, AL				;remember that this particular button is pushed
	JMP  ReturnFromBH
	
DebounceButton:
	DEC  debounce_cntr
	CMP  debounce_cntr, 0				;see if we have exceeded debouncing time
	JA   ReturnFromBH
	JE   ButtonDebounced
	
ButtonDebounced:
    XOR  AH, AH                         ;clear high byte so it doesn't interfere with index
    LEA  DI, ColumnTab                  ;want to access table
    ADD  DI, AX                         ;add in button code offset
    MOV  BL, CS:[DI]                    ;put column number in AL
    MOV  CX, curr_row                   ;get current row (range 0 to NUM_ROWS - 1)
    MOV  AX, NUM_COLS                   ;want to multiply row and number of columns
    MUL  CL                             ;multiply row by columns to get row offset in AL
    ADD  AL, BL                         ;add column offset to row offset, now have key num
    
    OR   AL, BUTTON_EVENT_CODE          ;make this distinct so we know it is a button event
    
	MOV  debounce_cntr, SLOW_RATE
	CALL EnqueueEvent					;enqueues the event associated with pushed button
	JMP  ReturnFromBH

ReturnFromBH:
	POPA
	RET
	
ButtonHandler	ENDP


;
; ColumnTab
;
; Description:  This table takes a button code ranging from 0 to 15 and returns which
;               column the button pressed is in.  It only accepts instances where
;               only one button is being pressed.
;
; Author:       Tim Menninger
; Last Changed: 12/11/14
;

ColumnTab       LABEL   BYTE
                PUBLIC  ColumnTab
                
;   DB      column          ;key value
    DB      0               ;0000H
    DB      0               ;0001H
    DB      0               ;0010H
    DB      0               ;0011H
    DB      0               ;0100H
    DB      0               ;0101H
    DB      0               ;0110H
    DB      4               ;0111H
    DB      0               ;1000H
    DB      0               ;1001H
    DB      0               ;1010H
    DB      3               ;1011H
    DB      0               ;1100H
    DB      2               ;1101H
    DB      1               ;1110H
    DB      0               ;1111H

CODE	ENDS



DATA    SEGMENT PUBLIC  'DATA'

	curr_row		DW		?			;row that is currently being scanned
	last_button		DB		?			;last button to have been pressed, if any
	debounce_cntr   DW      ?			;counter for debouncing, counts down

DATA    ENDS


	END