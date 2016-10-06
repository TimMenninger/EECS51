;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                                        ;
;                                         PARSE.INC                                      ;
;                           Driver for Parsing Serial Characters                         ;
;                                       Tim Menninger                                    ;
;                                                                                        ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;
; Description:	This file contains the state definitions and token types for parsing
;				serial chars for setting motors.  It also contains error codes and general
;				constants.
;
; Revision History:
;    12/05/14  Tim Menninger	initial revision



; State definitions

ST_INITIAL		EQU	0		;initial state
ST_CHSPEED		EQU	1		;change absolute speed, wait for digit or sign
ST_GETNEWSPD	EQU	2		;have sign, process chars to get new speed/set new speed
ST_UPDSPEED		EQU 3		;change relative speed, wait for sign
ST_UPDSPD		EQU	4		;have sign, process chars to get speed change/set new speed
ST_CHANGLE		EQU	5		;change direction, wait for sign
ST_UPDANGLE		EQU	6		;have sign, process chars to add or subtract to current angle
ST_ROTTURR		EQU	7		;rotate turret, wait for sign
ST_UPDTURR		EQU 8		;have sign, add or subtract to current turret position/set it
ST_SETTURR		EQU	9		;no sign, set absolute turret rotation/set it
ST_TURRELEV		EQU	10		;want to change turret elevation, wait for sign
ST_SETELEV		EQU	11		;no sign, set absolute turret elevation
ST_UPDELEV		EQU	12		;have sign, set relative turret elevation
ST_ERROR		EQU	13		;error encountered, do nothing until valid command comes
ST_FIRE         EQU 14      ;fire laser
ST_CEASEFIRE    EQU 15      ;turn laser off


; Token Type Definitions

TOKEN_DIGIT		EQU	0		;token is a digit: 0 to 9
TOKEN_ABSSPD	EQU	1		;token is 'S', command to change absolute speed
TOKEN_RELSPD	EQU 2		;token is 'V', command to change relative speed
TOKEN_FIRE		EQU 3		;token is 'F', command to fire laser
TOKEN_CEASEFIRE	EQU	4		;token is 'O', command to turn laser off
TOKEN_ANGLE		EQU	5		;token is 'D', command to change direction
TOKEN_ROTTURR	EQU	6		;token is 'T', command to rotate turret
TOKEN_TURRELEV	EQU	7		;token is 'E', command to change turret elevation
TOKEN_PLUS		EQU	8		;token is '+', sign for numeric argument to commands
TOKEN_MINUS		EQU 9		;token is '-', sign for numeric argument to commands
TOKEN_EOC		EQU 10		;token is <Return>, delimits commands
TOKEN_NOP		EQU	11		;token is <Tab>, <space>, <new line>, ignore them
TOKEN_OTHER		EQU	12		;anything else, raise error


; Error Type Definitions
NO_ERROR        EQU 0       	;no errors
INVALID_CHAR    EQU 10000000B	;sets high bit of ASCII char for invalid character error
NO_ARGUMENT     EQU 2       	;command attempted with no numeric argument
OUT_OF_RANGE    EQU 3       	;argument is not in valid range
SETTING_OF      EQU 4       	;overflow when updating setting variable
SET_REL_OF      EQU 5       	;overflow when updating motor setting


; Other Constants

NUM_TOKEN_TYPES	EQU	13			;number of token types
TOKEN_MASK		EQU	01111111B	;mask high bit of token
NO_ADDING		EQU	0			;initial value for setting change variable
SAME_SPEED		EQU	65535		;indicates not to change speed
SAME_DIRECT		EQU	-32768		;indicates not to change direction
INIT_SETCHG		EQU	0			;want to start with 0 as initial setting change
INIT_SIGN		EQU	1			;want default sign to be positive
DEC_SHL     	EQU 10          ;multiplier to effectively shift left once in decimal
MAX_ELEV    	EQU 60          ;maximum turret elevation
MIN_ELEV    	EQU -60         ;minimum turret elevation
MAX_ANGLE   	EQU 32767       ;maximum direction angle
MIN_ANGLE   	EQU -32767      ;minimum direction angle
MAX_SPEED   	EQU 65534       ;maximum robotrike speed
MIN_SPEED   	EQU 0           ;minimum robotrike speed