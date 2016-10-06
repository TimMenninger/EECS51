        NAME  MOTORBOARD

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                                        ;
;                                       MOTORBOARD                                       ;
;                      Function to Decipher Motor Target Board Events                    ;
;							       	   Tim Menninger								     ;
;                                                                                        ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;
; Description:		This contains code for handling events on the motor side target board.
;					This includes parsing characters coming in from the serial port and
;					updating the controller side target board with errors and/or requested
;					information.
;
; Contents:			DecipherMotorEvent - This takes as input an event code, determines
;						whether it is an error or not, then handles it accordingly
;					
; Input:            None direct, but is called when a character is detected from the
;					serial port.
;
; Output:           None direct, but this calls functions that write to the motors and
;					send data over the serial port.
;
; User Interface:   When a button is pressed on the controller side, it triggers a series
;					of events ultimately sending characters over the serial port.  This
;					function uses those characters to control the motors.
;
; Error Handling:   None.
;
; Algorithms:       None.
;
; Data Structures:  None.
;
; Revision History:
;    12/11/14	Tim Menninger	Created
;



CGROUP  GROUP   CODE
DGROUP	GROUP	DATA


CODE	SEGMENT PUBLIC 'CODE'


        ASSUME  CS:CGROUP,	DS:DGROUP


$INCLUDE(maincons.inc)					;constants for the main loops and helper procs


; external action routines used

		EXTRN	ParseSerialChar:NEAR	;interprets serial character given previous ones
		EXTRN	SerialPutChar:NEAR		;enqueues a character to be sent over serial





;
;DecipherMotorEvent
;
;Description:			This procedure takes an event code and decides whether it is an
;						error or an event.  In either case, it handles it accordingly,
;						either by parsing the event or sending to the controller board
;						the error code.
; 
;Operation:             This is called when there is an event dequeued from the queue
;						of events.  If the event dequeued is an error, then AH will
;						contain a non-zero value corresponding to an error code.  In
;						this case, it enqueues the error code to be sent via serial to the
;						controller to display.  If it is an event, then it assumes that
;						the event is a character and it thus calls a serial character
;						parser to handle it.
; 
;Arguments:				AH - error code
;						AL - event code
; 
;Return Values:         None.
; 
;Global Variables:      None.
; 
;Shared Variables:      None.
; 
;Local Variables:       None.
; 
;Inputs:                None.
; 
;Outputs:               None.
;
;Registers Changed:		None.
; 
;Error Handling:        If the event is an error, it sends it to the controller to handle.
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


DecipherMotorEvent	PROC    NEAR
                    PUBLIC  DecipherMotorEvent

    PUSHA
                    
    CMP  WORD PTR AH, NO_ERROR		;check to see if we have an error
    JE   NoMotorError				;if not, parse character
    JNE  MotorError					;if so, send it to controller
    
NoMotorError:
	CALL ParseSerialChar            ;since we have a character, parse it
	CMP  WORD PTR AH, NO_ERROR		;see if we got an error when parsing
    JE   DecipheredMotEv            ;done parse, can now return
    MOV  AH, PARSE_ERROR			;want to report parsing error

MotorError:
	MOV  AL, AH						;put error code into AL to send over serial
    CALL SerialPutChar				;send the error code to controller side to handle
    JMP  DecipheredMotEv
    
DecipheredMotEv:
    POPA
    RET
                
DecipherMotorEvent	ENDP


CODE	ENDS


DATA    SEGMENT PUBLIC  'DATA'

	

DATA    ENDS



        END