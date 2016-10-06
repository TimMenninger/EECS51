;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                                        ;
;                                        CONVERTS                                        ;
;                       Constants Used in Dec2String and Hex2String                      ;
;                                      Tim Menninger                                     ;
;                                                                                        ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;
; Description:		Contains constants for Dec2String process in converts.asm
;
; Revision History:
;		11/01/14	Tim Menninger	Created
;		12/11/14	Tim Menninger	Added documentation
;

;constants used in converts.asm

PWR10	EQU	10000		;We use 10^4 for this because it is a
						;5 digit number max