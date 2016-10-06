        NAME  TRIKEUI

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                                        ;
;                                         TRIKEUI                                        ;
;                                 RoboTrike User Interface                               ;
;								       Tim Menninger								     ;
;                                                                                        ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;
; Description:		This contains code for the user interface.  It contains functions
;					called when an event (possibly an error) occurs and action is
;					required.
;
; Contents:			DecipherContEvent - This takes as input an event code, determines
;						whether it is an error or not, then handles it accordingly
;					
; Input:            None direct, but is called when event occurs, which could be a
;					character from the serial port or a buttonpress on the target board.
;
; Output:           None direct, but this calls functions that write updates to the 
;					display and sends commands over the serial port.
;
; User Interface:   When a button is pressed, it is enqueued.  When that event is
;					dequeued, DecipherContEvent is called to decide what to do about
;					the button press.  Similarly, if information comes from the serial
;					port, it is enqueued, dequeued, then deciphered.
;
; Error Handling:   None.
;
; Algorithms:       None.
;
; Data Structures:  None.
;
; Revision History:
;	 12/11/14       Tim Menninger	created
;



; local include files
$INCLUDE(maincons.inc)					;constants for the main loops and helper procs
$INCLUDE(ASCII.inc)						;various ASCII letter representations




CGROUP  GROUP   CODE
DGROUP	GROUP	DATA


CODE	SEGMENT PUBLIC 'CODE'


        ASSUME  CS:CGROUP,	DS:DGROUP


; external action routines used

		EXTRN	Dec2String:NEAR		;converts a number to a string of decimal characters
		EXTRN	SerialPutChar:NEAR	;enqueues a character to be sent over serial to motors
		EXTRN	Display:NEAR		;takes a string and displays it



;
;NewSpeed
;
;Description:			This procedure takes the value in the change setting variable,
;						scales it to 16 bits and changes the speed to that value.
; 
;Operation:             This first gets from a shared variable the value of the new speed,
;						which fits in 15 bits.  SetMotorSpeed expects a 16 bit input, so
;						it scales the new speed accordingly.  It then calls SetMotorSpeed
;						with that new speed argument and an angle argument that indicates
;						not to change direction of the trike.  This only happens if there
;                       are no errors.  Then, also if there are no errors, InitParser is
;                       called to reset all of the variables, as NewSpeed is only called
;                       at the end of a command.
; 
;Arguments:				None.
; 
;Return Values:         None.
; 
;Global Variables:      None.
; 
;Shared Variables:      setting_chg (READ) - keeps track of what we are changing value by
;
;                       ser_error (WRITE) - TRUE if error encountered, FALSE otherwise
;
;                       have_argument (READ) - TRUE if we have argument, FALSE otherwise
; 
;Local Variables:       None.
; 
;Inputs:                None.
; 
;Outputs:               None.
;
;Registers Changed:		None.
; 
;Error Handling:        If this function is called without an argument (i.e. we got the
;                       character for this particular command, but no value to change to),
;                       the error flag is set.
;
;                       If the value read from the setting change variable is not within
;                       the range accepted by the function to be called, the error flag is set.
; 
;Algorithms:            None.
; 
;Data Structures:       None.
; 
;Limitations:           None.
; 
;Known Bugs:            None.
; 
;Special Notes:         None.
; 	


DecipherContEvent	PROC    NEAR
                    PUBLIC  DecipherContEvent
                    
    PUSHA                           ;store registers

    CMP  AH, NO_ERROR               ;see if there is an error
    JE   NoContError                ;if not, continue
    JNE  ContError                  ;if so, handle error
    
NoContError:
    MOV  BL, AL                     ;want to evaluate event without changing code
    AND  BL, CHECK_BUTTON           ;want to mask and check if it is a button press
    CMP  BL, IS_BUTTON              ;check if it is a button
    JNE  HaveChar                   ;not a button, must be a serial character
    
    AND  AL, BUTTONEC_MASK          ;mask out the button event code and unused bits
    MOV  BL, AL                     ;use button code as index
    XOR  BH, BH                     ;mask high byte so it doesn't interfere with indexing
    
    LEA  SI, CS:ButtonCmdTable[BX]  ;will use this buffer for many buttons
    JMP  SendCmdsLoop				;have command, now send it to motors
    
SendCmdsLoop:
	CMP  [SI], ASCIInull			;see if we are at end of command string
	JE   DoneContEH					;if we are, return from procedure
	
	MOV  AL, [SI]					;put character into AL to send over serial
	CALL SerialPutChar				;enqueue character to send to motor board
	INC  SI							;want to look at next character
	JMP  SendCmdsLoop				;send next character
    
ContError:
	CMP  AH, MAX_ERROR_CODE			;make sure we will be inside table
	JA   UnkError					;if not on table, error unknown
    
UnkError:							;unknown error
	MOV  AH, UNKNOWN_ERROR			;change AH to index for unknown error
	JMP  DisplayError
	
DisplayError:
	MOV  BL, AH						;put error code into index-able register
	XOR  BH, BH						;and clear high byte, BX now offset
    LEA  SI, CS:ErrorDispTable[BX]	;load error string into SI to display
    
    PUSH CS							;want to use ES in display, string currently in CS
    POP  ES
    
    CALL Display					;display the error string
    JMP  DoneContEH					;done with controller event
    
HaveChar:
    MOV  AH, AL						;data from serial means error, should be in AH
    JMP  ContError					;display error accordingly
    
DoneContEH:
    POPA
    RET
                
DecipherContEvent	ENDP


    
    
;
; ErrorDispTable
;
; Description:  This has the strings to be displayed when an error occurs.  It is indexed
;				by error code.
;

ErrorDispTable      LABEL   BYTE
                    PUBLIC  ErrorDispTable
                    
;   DB      String                          			;Corresponding error

	DB		'UnKnown Error', ASCIInull					;unknown error
	DB		'OvErrun Error', ASCIInull					;overrun error
	DB		'ParItY Error', ASCIInull					;parity error
	DB		'OvErrun And ParItY ErrorS', ASCIInull		;overrun and parity errors
	DB		'FrAMInG Error', ASCIInull					;framing error
	DB		'OvErrun And FrAMInG ErrorS', ASCIInull		;overrun and framing errors
	DB		'ParItY And FrAMIng ErrorS', ASCIInull		;parity and framing errors
	DB		'ALL PoSSIbLE SErIAl ErrorS', ASCIInull		;overrun, parity and framing errs
	DB		'PArSInG Error', ASCIInull					;error when parsing command
	DB		'FATAL ERROR', ASCIInull					;fatal error (event queue full)
	

;
; CmdDispTable
;
; Description:	This has the strings to be displayed when a button is pressed.  It is
;				indexed by the button number.
;

CmdDispTable		LABEL	BYTE
					PUBLIC	CmdDispTable
					
;	DB		Displayed Command				;Button

	DB						   ASCIInull	;N/A
	DB		'FIRE',			   ASCIInull	;1					
	DB		'CEASE FIRE',	   ASCIInull	;2
	DB						   ASCIInull	;3
	DB		'SPEED UP',		   ASCIInull	;4
	DB		'GO -45 DEGREES',  ASCIInull	;5
	DB		'GO STRAIGHT',	   ASCIInull	;6
	DB		'GO 45 DEGREES',   ASCIInull	;7
	DB		'SLOW DOWN',	   ASCIInull	;8
	DB		'GO LEFT',		   ASCIInull	;9
	DB		'STOP',			   ASCIInull	;10
	DB		'GO RIGHT',		   ASCIInull	;11
	DB						   ASCIInull	;12
	DB		'GO -135 DEGREES', ASCIInull	;13
	DB		'GO BACKWARDS',    ASCIInull	;14
	DB		'GO 135 DEGREES',  ASCIInull	;15
	DB		'RESET MOTION',	   ASCIInull	;16



;
; ButtonCmdTable
;
; Description:	This has the strings to send over serial in response to a button being
;				pressed.  It is indexed by button pressed.
;
; Notes:		Buttons are counted from 1 on the top left and upwards first to the right
;				then down until the bottom right button, so the x-th button in the y-th
;				row would be button (y * num_cols) + x where num_cols is the number of
;				columns of buttons.
;

ButtonCmdTable		LABEL	BYTE
					PUBLIC	ButtonCmdTable
					
;	DB		Command String								;instruction			button

	DB								   ASCIInull		;no instruction			N/A
	DB		'F',      CARRIAGE_RETURN, ASCIInull		;fire laser				1
	DB		'O',      CARRIAGE_RETURN, ASCIInull		;turn laser off			2
	DB								   ASCIInull		;no instruction			3
	DB		'V+2048', CARRIAGE_RETURN, ASCIInull		;speed up by 2048		4
	DB		'D-45',   CARRIAGE_RETURN, ASCIInull		;go -45 degrees			5
	DB		'D+0',    CARRIAGE_RETURN, ASCIInull		;straight				6
	DB		'D+45',   CARRIAGE_RETURN, ASCIInull		;go 45 degrees			7
	DB		'V-2048', CARRIAGE_RETURN, ASCIInull		;slow down by 2048		8
	DB		'D-90',   CARRIAGE_RETURN, ASCIInull		;go -90 degrees			9
	DB		'S0',     CARRIAGE_RETURN, ASCIInull		;stop motion			10
	DB		'D+90',   CARRIAGE_RETURN, ASCIInull		;go 90 degrees			11
	DB								   ASCIInull		;no instruction			12
	DB		'D-135',  CARRIAGE_RETURN, ASCIInull		;go -135 degrees		13
	DB		'D180',   CARRIAGE_RETURN, ASCIInull		;go backwards			14
	DB		'D+135',  CARRIAGE_RETURN, ASCIInull		;go 135 degrees			15
														;reset motion			16
	DB		'O', CARRIAGE_RETURN,'S0', CARRIAGE_RETURN,	'D+0', CARRIAGE_RETURN, ASCIInull


CODE	ENDS



        END