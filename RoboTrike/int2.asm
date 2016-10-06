	NAME INT2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                                        ;
;                                        INT2.ASM                                        ;
;                            Initializes INT2 Interrupt Vector                           ;
;                                      Tim Menninger                                     ;
;                                                                                        ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;
; Description:      This code initializes and installs the INT2 interrupt handler.
;
; Contents:			InstallINT2Handler - installs the INT2 event handler
;					INT2Init - initializes the INT2 interrupt vector
;
; Input:            None.
;
; Output:           Interrupt control register
;
; User Interface:   None.
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


CGROUP	GROUP	CODE


CODE	SEGMENT PUBLIC 'CODE'

        ASSUME  CS:CGROUP
        
        EXTRN   SerialEventHandler :NEAR


$INCLUDE(intrpts.inc)        ;contains addresses and constants for interrupt vectors


; InstallINT2Handler
;
; Description:       This installs the INT2 event handler.
;
; Operation:         This works by clearing ES and then storing the INT2 interrupt
;                    vector for serial events.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  None.
; Global Variables:  None.
;
; Input:             None.
; Output:            IVT. 
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   None.
;
; Registers Changed: flags, AX, ES
; Stack Depth:       0 words
;
; Known Bugs:		 None
; Limitations:		 None
; Special Notes:	 None




InstallINT2Handler  PROC    NEAR
                    PUBLIC  InstallINT2Handler

        XOR     AX, AX          ;clear ES (interrupt vectors are in segment 0)
        MOV     ES, AX
                                ;store the vector
        MOV     ES: WORD PTR (4 * INT2_VEC), OFFSET(SerialEventHandler)
        MOV     ES: WORD PTR (4 * INT2_VEC + 2), SEG(SerialEventHandler)


        RET                     ;all done, return


InstallINT2Handler  ENDP        
       
       
; INT2Init
;
; Description:       This function initializes the INT2 interrupt vector.
;
; Operation:         This first sets up the interrupt control register with
;                    predefined constants and then sends an INT2 EOI to
;                    clear out the controller.
;
; Arguments:         None.
;
; Return Value:      None.
;
; Local Variables:   None.
;
; Shared Variables:  None.
;
; Global Variables:  None.
;
; Input:             None.
;
; Output:            PCB.
;
; Error Handling:    None.
;
; Algorithms:        None.
;
; Data Structures:   None.
;
; Registers Changed: AX, DX
;
; Stack Depth:       0 words
;
; Known Bugs:		 None
;
; Limitations:		 None
;
; Special Notes:	 None
;
; Revision History:  



INT2Init	       PROC    NEAR
				   PUBLIC  INT2Init
                                
                                    
        MOV     DX, INT2Cntrl	 ;setup the INT2 interrupt control register
        MOV     AX, INT2CtrlrCVal;set up priority
        OUT     DX, AL			 ;write priority to INT2 control register
        
        MOV		DX, INT_MASK_REG ;address of interrupt mask register
        MOV		AX, UNMASK2      ;value that masks all interrupts except INT2
        OUT		DX, AX			 ;do the deed and send it out

        MOV     DX, INTCtrlrEOI  ;EOI control register address
        MOV     AX, INT2EOI		 ;INT2 end of interrupt value
        OUT     DX, AL			 ;write end of interrupt


        RET                     ;done so return


INT2Init       ENDP

CODE	ENDS

	END