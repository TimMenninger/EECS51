    NAME CONTROLLERMAIN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                                        ;
;                                     CONTROLLERMAIN                                     ;
;                        Main Loop for Controller Side Target Board                      ;
;                                      Tim Menninger                                     ;
;                                                                                        ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Description:      This program is the main loop for the controller side of the roboTrike
;                   system.
;
; Input:            None.
;
; Output:           None.
;
; User Interface:   This enqueues event codes when buttons are pressed and sends the
;					corresponding motor command over serial to turn on/off motors.  It
;					displays updates when prompted and if an error occurs, it displays it.
;
; Error Handling:   If this function tries to enqueue an event and the event queue is
;					full, the system resets.
;
; Algorithms:       None.
;
; Data Structures:  None.
;
; Known Bugs:       None.
;
; Limitations:      None.


CGROUP  GROUP   CODE
DGROUP  GROUP   DATA, STACK



CODE    SEGMENT PUBLIC 'CODE'


        ASSUME  CS:CGROUP, DS:DGROUP
	
	
; external action routines used

		EXTRN	DisplayInit:NEAR		;clears display and initializes variables
		EXTRN	ButtonInit:NEAR			;initializes buttons and associated variables
		EXTRN	SerialInit:NEAR			;initializes serial constants
		EXTRN	DequeueEvent:NEAR		;dequeues an event from the event queue
		EXTRN	DecipherContEvent:NEAR	;decides what to do about dequeued event
		EXTRN	GetErrorStatus:NEAR		;tells us if there has been a fatal error
        EXTRN   InitEventQueue:NEAR     ;initializes event queue
	
	
$INCLUDE(maincons.inc)					;constants for the main loops and helper procs
$INCLUDE(serial.inc)                    ;contains serial comm constants for initialization


START:  

MAIN:

        MOV     AX, STACK               ;initialize the stack pointer
        MOV     SS, AX                
        MOV     SP, OFFSET(TopOfStack)  

        MOV     AX, DATA                ;initialize the data segment
        MOV     DS, AX
        
        CALL    DisplayInit				;initialize displays
        CALL    ButtonInit				;initialize button constants
        
        MOV     AX, INIT_PARITY         ;parity is an argument to SerialInit
        MOV     BX, INIT_DIVISOR        ;divisor is an argument to SerialInit
        CALL    SerialInit				;initialize serial constants
        
        CALL	InitEventQueue			;initialize event queue
        
		STI                             ;turn on interrupts
        
    Forever:
    	CALL	GetErrorStatus			;get status of fatal error
    	CMP		AX, FTL_ERR_CODE		;check if the returned value means fatal error
    	JE		FoundFatalError			;if so, we need to restart system
    	
        CALL    DequeueEvent			;if no fatal error, continue dequeueing
        CALL    DecipherContEvent		;after dequeueing, decide what to do
		JMP     Forever					;repeat
		
	FoundFatalError:
		JMP		START

CODE    ENDS


DATA    SEGMENT PUBLIC  'DATA'

DATA    ENDS


;the stack

STACK   SEGMENT STACK  'STACK'

                DB      80 DUP ('Stack ')       ;240 words

TopOfStack      LABEL   WORD

STACK   ENDS



        END     START