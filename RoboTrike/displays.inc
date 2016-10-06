;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                                        ;
;                                        DISPLAYS                                        ;
;                           Contains Constants for the Displays                          ;
;                                      Tim Menninger                                     ;
;                                                                                        ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;
; Description:		Contains constants for the display and the display mux
;
; Revision History:
;		11/07/14	Tim Menninger	Created
;		12/11/14	Tim Menninger	added header
;

; General constants
NUM_LEDS		EQU		8			;number of LEDs we can display at once
MAX_CHARS		EQU		20			;maximum length of string to write to LEDs
LEDDisplay		EQU		0			;address of first LED display port (assuming they are at
									;	consecutive addresses)
LEDOff          EQU     0           ;writing 0 to LED port turns off LED
LEDInnerSeg		EQU		8			;port written to for inner segments
AllSegs			EQU		0FFFFH		;lights up all segments of an LED display
SegBuffSize     EQU     2           ;size of elements in segment buffer
SCRL_WAIT       EQU     1000        ;number of milliseconds before start scrolling
START_SCROLL    EQU     0           ;how we know we have finished counting
SCROLLING_TM    EQU     125         ;number of milliseconds between each scroll