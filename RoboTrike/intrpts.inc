;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                                        ;
;                                      IRQVECTS.INC                                      ;
;                       Contains constants for setting up IRQ vectors                    ;
;                                      Tim Menninger                                     ;
;                                                                                        ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;This file contains constants and addresses for interrupt vectors
;Revision History:
;       11/07/14    Tim Menninger   Created/Adapted from Glen George
;       11/29/14    Tim Menninger   Added header and INT2 constants/addresses

; General Constants
VECTOR_SIZE		EQU		4					;size of each vector in bytes
NUM_VECTORS		EQU		256					;number of vectors in vector table
INT2_VECTOR     EQU     14              	;INT2 interrupt vector
INT2_VEC        EQU     14                  ;vector for INT2 in vector table

FIRST_RESERVED_VEC	EQU	1	                ;reserve vectors 1-3
LAST_RESERVED_VEC	EQU	3
NUM_IRQ_VECTORS     EQU 256             	;number of interrupt vectors


; Addresses
PCB_BASE        EQU     0FF00H              ;base address of peripheral control block
INTCtrlrEOI     EQU     PCB_BASE + 22H     	;address of interrupt controller EOI register
INT_MASK_REG	EQU		PCB_BASE + 28H  	;address of interrupt mask register
INTCtrlrCtrl    EQU     PCB_BASE + 32H    	;address of interrupt controller for timer
INT2Cntrl       EQU     PCB_BASE + 3CH     	;address of INT2 control register 



INT2CtrlrCVal   EQU     00013H          	;set priority for INT2 enable
                                        	;00000000000-----  reserved
                                        	;-----------1----  select level triggering
                                        	;------------0---  enable INT2 interrupts
                                        	;-------------011  INT2 priority
NonSpecEOI      EQU     08000H          	;Non-specific EOI command
INT2EOI         EQU     0000EH          	;INT2 EOI command
UNMASK2			EQU	    0000000010111101B	;00000000------0-	reserved
											;--------1-------	mask INT3
											;---------0------	unmask INT2
											;----------1-----	mask INT1
											;-----------1----	mask INT0
											;------------1---	mask DMA1
											;-------------1--	mask DMA0
											;---------------1	mask timer

