    NAME MOTORSMAIN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                                        ;
;                                        MOTORSMAIN                                      ;
;                                  Homework #8 Main Loop                                 ;
;                                      Tim Menninger                                     ;
;                                                                                        ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Description:      This program is the main loop for the motor side of the roboTrike
;                   system.
;
; Input:            None.
;
; Output:           None.
;
; User Interface:   None.
;
; Error Handling:   None.
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

$INCLUDE(serial.inc)					;serial constants
$INCLUDE(maincons.inc)					;constants for the main loops and helper procs


CODE    SEGMENT PUBLIC 'CODE'


        ASSUME  CS:CGROUP, DS:DGROUP
	
	
; external action routines used

		EXTRN	DisplayInit:NEAR		;clears display and initializes variables
		EXTRN	MotorInit:NEAR			;initializes motors and lasers off
		EXTRN	SerialInit:NEAR			;initializes serial constants
		EXTRN	InitParser:NEAR			;initializes constants for serial char parser
		EXTRN	DequeueEvent:NEAR		;dequeues an event from the event queue
		EXTRN	DecipherMotorEvent:NEAR	;decides what to do with dequeued event
		EXTRN	GetErrorStatus:NEAR		;tells us if there has been a fatal error
        EXTRN   InitEventQueue:NEAR     ;initializes event queue
        EXTRN   SerialPutChar:NEAR      ;enqueues serial character to be sent over serial


START:  

MAIN:

        MOV     AX, STACK               ;initialize the stack pointer
        MOV     SS, AX                
        MOV     SP, OFFSET(TopOfStack)  

        MOV     AX, DATA                ;initialize the data segment
        MOV     DS, AX
        
        CALL    DisplayInit             ;initialize display
        CALL    MotorInit               ;initialize motors
        
        MOV     AX, INIT_PARITY         ;parity is an argument to SerialInit
        MOV     BX, INIT_DIVISOR        ;divisor is an argument to SerialInit
        CALL    SerialInit              ;initialize serial constants
        CALL    InitParser              ;initialize parser
        
        CALL	InitEventQueue			;initialize event queue
		
		STI                             ;turn on interrupts
		
	Forever:
		CALL	GetErrorStatus			;put status of fatal error in AX
		CMP		AX, FTL_ERR_CODE		;error or no error? check
		JE		FoundFatalError			;now there is an error, handle it
		CALL	DequeueEvent			;if no error, carry on and get next event
		CALL	DecipherMotorEvent		;start to decipher the event and handle it
	
		JMP		Forever					;repeat
		
	FoundFatalError:
		CALL	SerialPutChar			;tell controller side we have fatal error
		JMP		START					;then restart
        

CODE    ENDS




;the data segment

DATA    SEGMENT PUBLIC  'DATA'

DATA    ENDS




;the stack

STACK   SEGMENT STACK  'STACK'

                DB      80 DUP ('Stack ')       ;240 words

TopOfStack      LABEL   WORD

STACK   ENDS



        END     START