       NAME  MTRTIMER0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                                        ;
;                                        MTRTIMER0                                       ;
;                     Initializes Timer0 for Motor Side Target Board                     ;
;                                      Tim Menninger                                     ;
;                                                                                        ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Description:      This has the code to initialize timer 0 and installs the
;					handler.
;
; Contents:			Timer0EventHandler - event handler for timer interrupt.  It
;								calls a function that scans/debounces buttons
;					InitTimer0 - initializes timer 0
;					InstallTimer0Handler - installs the event handler for timer 0
;
; Input:            Keypad - interrupt handler handles keypresses
;
; Output:           None.
;
; User Interface:   User presses keys.  This function handles those keypresses
;
; Error Handling:   None.
;
; Algorithms:       None.
;
; Data Structures:  None.
;
; Revision History:
;    11/11/92  Glen George      initial revision (originally ISRDEMO.ASM)
;	 11/07/14  Tim Menninger	adapted to supplement displays.asm
;	 11/22/14  Tim Menninger	adapted to supplement motors.asm, no longer
;								compatible with displays.asm.  also updated
;								comments
;


; local include files
;$INCLUDE(motors.inc)
$INCLUDE(mtrtmr0.inc)			;constants and addresses for timer0




CGROUP	GROUP	CODE


CODE	SEGMENT PUBLIC 'CODE'

        ASSUME  CS:CGROUP
		
		EXTRN	SetPWM:NEAR		;event handler for buttonpush



		

; Timer0EventHandler
;
; Description:       This procedure is the event handler for the timer
;                    interrupt.  It calls a function that will check
;					 for buttons pressed, debounces them and then repsonds
;					 accordingly to the button pressed.
;
; Operation:         This function works by calling a function that scans
;					 one row per interrupt for a button pressed.  When a
;					 button is pressed, it will enqueue that button press
;					 for another function to respond to accordingly.  After
;					 that, it sends the EOI message marking the end of the
;					 interrupt.
;
; Arguments:         None.
;
; Return Value:      None.
;
; Local Variables:   AX - Timer EOI value.
;                    DX - interrupt controller port.
;
; Shared Variables:  None.
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
; Stack Depth:       3 words
;
; Revision History:	 01/27/03	Glen George		Created
;					 11/14/14	Tim Menninger	Adapted to supplement RoboTrike
;												processes

Timer0EventHandler       PROC    NEAR
                         PUBLIC  Timer0EventHandler

		PUSH AX
		PUSH DX
		
		CALL SetPWM
		
EndTimer0EventHandler:			;done taking care of the timer

        MOV  DX, INTCtrlrEOI	;send the EOI to the interrupt controller
        MOV  AX, TimerEOI
        OUT  DX, AL

        POP  DX					;restore the registers
        POP  AX

        IRET					;and return (Event Handlers end with IRET not RET)

Timer0EventHandler       ENDP







; InitTimer0
;
; Description:       Initialize the 80188 Timer.  The timers are initialized
;                    to generate interrupts every INTERUPTS_PER_MS milliseconds.
;                    The interrupt controller is also initialized to allow the
;                    timer interrupts.
;
; Operation:         The appropriate values are written to the timer control
;                    registers in the PCB.  Also, the timer count registers
;                    are reset to zero.  Finally, the interrupt controller is
;                    setup to accept timer interrupts and any pending
;                    interrupts are cleared by sending a TimerEOI to the
;                    interrupt controller.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  None.
; Global Variables:  None.
;
; Input:             None.
; Output:            None.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   None.
;
; Registers Changed: AX, DX

InitTimer0      PROC    NEAR
				PUBLIC	InitTimer0
                                
        MOV     DX, Tmr0Count		;initialize the count register to 0
        XOR     AX, AX
        OUT     DX, AL

        MOV     DX, Tmr0MaxCntA 	;setup max count
        MOV     AX, TIMER0_COUNTS  	;want to interrupt for PWM
        OUT     DX, AL

        MOV     DX, Tmr0Ctrl    	;setup the control register, interrupts on
        MOV     AX, Tmr0CtrlVal
        OUT     DX, AL

                                	;initialize interrupt controller for timers
        MOV     DX, INTCtrlrCtrl	;setup the interrupt control registero
        MOV     AX, INTCtrlrCVal
        OUT     DX, AL

        MOV     DX, INTCtrlrEOI 	;send a timer EOI (to clear out controller)
        MOV     AX, TimerEOI
        OUT     DX, AL


        RET                    	 	;done so return


InitTimer0      ENDP




; InstallTimer0Handler
;
; Description:       Install the event handler for the timer interrupt.
;
; Operation:         Writes the address of the timer event handler to the
;                    appropriate interrupt vector.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  None.
; Global Variables:  None.
;
; Input:             None.
; Output:            None.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   None.
;
; Registers Changed: flags, AX, ES

InstallTimer0Handler  PROC		NEAR
					  PUBLIC	InstallTimer0Handler


        XOR     AX, AX          ;clear ES (interrupt vectors are in segment 0)
        MOV     ES, AX
                                ;store the vector
        MOV     ES: WORD PTR (4 * Tmr0Vec), OFFSET(Timer0EventHandler)
        MOV     ES: WORD PTR (4 * Tmr0Vec + 2), SEG(Timer0EventHandler)

        RET                     ;all done, return


InstallTimer0Handler  ENDP

CODE	ENDS


        END