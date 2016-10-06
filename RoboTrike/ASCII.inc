;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                                        ;
;                                          ASCII                                         ;
;                                 Contains ASCII Constants                               ;
;                                      Tim Menninger                                     ;
;                                                                                        ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;
; Description:		General conversions for numbers/characters to ASCII representations.
;
; Revision History:
;		10/27/14	Tim Menninger	Created
;		12/11/14	Tim Menninger	took away constants for type-able characters and added
;									constants for <RETURN>
;

ASCIInull		EQU	0				;NULL ASCII character
CARRIAGE_RETURN	EQU	13				;carriage return ASCII character, used for end of cmd