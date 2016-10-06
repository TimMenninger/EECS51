        NAME  EVENTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                                        ;
;                                           EVENTS                                       ;
;                                  Functions for Event Queue                             ;
;							       	     Tim Menninger								     ;
;                                                                                        ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;
; Description:		This contains the processes for event queues.  It is different from
;					regular queue routines in that it checks for a critical error, as a
;					full event queue is more crucial than a regular full queue.
;
; Contents:			DequeueEvent - dequeues an event from the serial event queue, blocks
;						(by calling Dequeue) if the queue is empty
;					EnqueueEvent - enqueues an event to the serial event queue, if the
;						queue is full, it sets a fatal error flag and returns (does not
;						block)
;					FatalError - sets the fatal error flag
;					NoFatalError - resets the fatal error flag
;					GetErrorStatus - returns the fatal error flag status
;
; Input:            None.
;
; Output:           None.
;
; User Interface:   None.
;
; Error Handling:   If the event queue is full, it sets a fatal error flag.
;
; Algorithms:       None.
;
; Data Structures:  Queues - used to store events
;
; Revision History:
;	 12/11/14  Tim Menninger	created
;




CGROUP  GROUP   CODE
DGROUP	GROUP	DATA


CODE	SEGMENT PUBLIC 'CODE'


        ASSUME  CS:CGROUP,	DS:DGROUP
        
        
; local include files       
$INCLUDE(maincons.inc)					;constants for the main loops and helper procs
$INCLUDE(queues.inc)                    ;includes queue struct
$INCLUDE(boolean.inc)                   ;contains boolean constants


; external action routines used
		
		EXTRN	Dequeue:NEAR			;dequeues from a queue in SI
		EXTRN	Enqueue:NEAR			;enqueues into a queue in SI
		EXTRN	QueueFull:NEAR			;checks if a queue is full
		EXTRN	QueueInit:NEAR			;initializes queue


;
; InitEventQueue
;
; Description:       This creates and initializes the event queue.
;
; Operation:         This creates the event queue and then sets the maximum size and size
;					 of elements.
;
; Arguments:         None.
;
; Return Value:      None.
;
; Local Variables:   None.
;
; Shared Variables:  fatal_error (WRITE) - initializes fatal error to false
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
; Registers Changed: None.
;

InitEventQueue		PROC	NEAR
					PUBLIC	InitEventQueue
					
	PUSH SI							;store registers
	PUSH AX
	PUSH BX
	
	LEA  SI, serial_events			;want to initialize serial event queue
	MOV  AL, EVENT_QUEUE_SZ			;event queue size argument to QueueInit
	MOV  BL, TRUE					;want items to be words
	CALL QueueInit					;initialize queue
	
	POP  BX							;restore registers
	POP  AX
	POP  SI
	RET
					

;
; DequeueEvent
;
; Description:       This procedure dequeues an event from the event queue.
;
; Operation:         This function loads the effective address of the event queue and then
;					 dequeues from it.  It returns the value dequeued.  Because of the
;					 design of the Dequeue function, this will block if the queue is
;					 empty.
;
; Arguments:         None.
;
; Return Value:      AX - value dequeued
;
; Local Variables:   None.
;
; Shared Variables:  serial_events (WRITE) - value is dequeued from this queue
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
; Data Structures:   Queue - dequeues from event queue
;
; Registers Changed: None.
;

DequeueEvent		PROC	NEAR
					PUBLIC	DequeueEvent
				
	LEA  SI, serial_events			;want to dequeue from serial event queue
	CALL Dequeue					;dequeue from serial event queue
	RET
	
DequeueEvent		ENDP



;
; EnqueueEvent
;
; Description:       This procedure enqueues an event into the event queue.
;
; Operation:         This function loads the effective address of the event queue and then
;					 checks to see if it is full.  If it is, then it does not enqueue
;					 the value.  Instead, it sets a flag and returns.  If the queue is
;					 not full, it enqueues the value then returns.
;
; Arguments:         AX - value to be enqueued
;
; Return Value:      None.
;
; Local Variables:   None.
;
; Shared Variables:  serial_events (WRITE) - value is enqueued into this queue
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
; Data Structures:   Queue - enqueues into event queue
;
; Registers Changed: AX - return value
;


EnqueueEvent	    PROC    NEAR
                    PUBLIC  EnqueueEvent

    LEA  SI, serial_events              ;load serial event queue
    CALL QueueFull                      ;check if our queue is full
    JZ   SetFatalError                  ;if the queue is full, we have a fatal error
    JNZ  ProcedeEnqueue                 ;otherwise, go ahead and enqueue
    
SetFatalError:
	CALL FatalError						;record that fatal error reached
    JMP  DoneEnqEvent
   
ProcedeEnqueue:
	CALL NoFatalError					;keep track that there was no error
    CALL Enqueue                        ;enqueue the event
    JMP  DoneEnqEvent                   ;can now return
    
DoneEnqEvent:
    RET
                
EnqueueEvent		ENDP


;
; FatalError
;
; Description:       This procedure sets the fatal error flag.
;
; Operation:         This function sets the fatal error flag.
;
; Arguments:         None.
;
; Return Value:      None.
;
; Local Variables:   None.
;
; Shared Variables:  fatal_error (WRITE) - this sets the fatal error flag
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
; Registers Changed: None.
;

FatalError			PROC	NEAR
					PUBLIC	FatalError
					
	MOV  fatal_error, FTL_ERR_CODE		;set the fatal_error flag
	RET
	
FatalError			ENDP


;
; NoFatalError
;
; Description:       This procedure clears the fatal error flag.
;
; Operation:         This function clears the fatal error flag.
;
; Arguments:         None.
;
; Return Value:      None.
;
; Local Variables:   None.
;
; Shared Variables:  fatal_error (WRITE) - this clears the fatal error flag
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
; Registers Changed: None.
;

NoFatalError		PROC	NEAR
					PUBLIC	NoFatalError
					
	MOV  fatal_error, FALSE				;clear the fatal_error flag
	RET
	
NoFatalError		ENDP


;
; GetErrorStatus
;
; Description:       This procedure returns the value of the fatal error flag.
;
; Operation:         This procedure returns the value of the fatal error flag.
;
; Arguments:         None.
;
; Return Value:      AX - value of the fatal error flag
;
; Local Variables:   None.
;
; Shared Variables:  fatal_error (READ) - this returns the value in fatal_error
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
; Registers Changed: None.
;

GetErrorStatus		PROC	NEAR
					PUBLIC	GetErrorStatus
					
	MOV  AX, fatal_error				;return the fatal_error flag
	RET
	
GetErrorStatus		ENDP



CODE	ENDS


DATA    SEGMENT PUBLIC  'DATA'

	fatal_error		DW		?			;flag for whether fatal error has occurred
	serial_events	QUEUE	<>			;queue for events

DATA    ENDS



        END
