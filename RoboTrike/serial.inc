;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                                        ;
;                                       SERIAL.INC                                       ;
;                       Contains constants for serial communication                      ;
;                                      Tim Menninger                                     ;
;                                                                                        ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;This file contains constants and addresses relevant for serial communication
;Revision History:
;       11/28/14    Tim Menninger   Created

;Serial Accessible Registers
SERIAL_BASE     EQU 100H            ;address of base serial register
SERIAL_RBR      EQU SERIAL_BASE     ;address of Receiver Buffer Register
SERIAL_THR      EQU SERIAL_BASE     ;address of Transmitter Holding Register
SERIAL_IER      EQU SERIAL_BASE + 1 ;address of Interrupt Enable Register
SERIAL_IIR      EQU SERIAL_BASE + 2 ;address of Interrupt Ident. Register
SERIAL_LCR      EQU SERIAL_BASE + 3 ;address of Line Control Register
SERIAL_LSR      EQU SERIAL_BASE + 5 ;address of Line Status Register
SERIAL_MSR      EQU SERIAL_BASE + 6 ;address of Modem Status Register
SERIAL_DLL      EQU SERIAL_BASE     ;address of Divisor Latch (LSB)
SERIAL_DLM      EQU SERIAL_BASE + 1 ;address of Latch (MSB)

;LCR Constants
CLEAR_DLAB      EQU 01111111B       ;0-------B  clears divisor latch access bit

INIT_PARITY     EQU 00000000B       ;--0-----B  stick parity bit
                                    ;---0----B  even parity select bit
                                    ;----0---B  parity enable bit
INIT_DIVISOR    EQU 60              ;divisor = (clock frequency) / 2 / (baud rate) / 16
                                    ;        = 18.432 MHz / 2 / 9600 / 16
                                    ;        = 60
                                    
INIT_LCR        EQU 10000111B       ;1-------B  sets divisor latch access bit
                                    ;-0------B  break control bit
                                    ;--xxx---B  argument to init function
                                    ;-----1--B  set for 2 stop bits, reset for 1
                                    ;------11B  8-bit serial character words
                                    
;Interrupt Constants
RESTORE_IER     EQU 00000111B       ;OR-ed to clear create interrupt bit
SET_KICKSTART   EQU 00000101B       ;AND-ed to set create interrupt bit
NO_INTERRUPTS   EQU 00000001B       ;corresponds to no interrupts
NO_ERRORS       EQU 0               ;corresponds to no errors
NONERROR_MASK   EQU 00001110B       ;masks bits that don't correspond to errors
GENERATE_INT    EQU 00100000B       ;--1-----   automatic interrupt, other bits are read only
DISABLE_INT     EQU 0               ;value of IER when interrupts are disabled

;EnqueueEvent Constants
DENOTE_ERROR    EQU 11101110B       ;high byte of error event code (EE)
DENOTE_EVENT    EQU 00001110B       ;high byte of valid event code (0E)

;Queue Constants
SERIAL_QLEN     EQU 254             ;max number of elements in serial channel buf
BYTE_QUEUE      EQU 0               ;indicates that queue elements are words
