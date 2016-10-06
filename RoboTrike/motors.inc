;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                                        ;
;                                         MOTORS                                         ;
;				          Constants for Setting Motors and Laser				         ;
;				                      Tim Menninger                                      ;
;                                                                                        ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;
; Description:		This file contains constants required for manipulating motors and the
;					laser.
;
; Revision History:
;		11/23/14	Tim Menninger	Created
;

NO_SPEED        EQU 0       ;Speed when trike shouldn't move
MAX_SPEED       EQU 32767   ;maximum speed (signed 16 bit integer)
ANGLE_ZERO      EQU 0       ;Angle when it should be zero
NO_SPD_CHNG     EQU 65535   ;if input to speed-changing function, the speed will
                            ;   not change
NO_ANGL_CHNG    EQU -32768  ;if input to angle_changing function, the angle will
                            ;   not change
DX_DIVIDE_PREP  EQU 0       ;value DX should have to divide properly
DEGREES_IN_CIRC EQU 360     ;number of degrees in a circle
INIT_ITER       EQU 0       ;initial value of an iterator
NUM_WHEELS      EQU 3       ;number of wheels on robotrike
DONE_DEC        EQU 0       ;used as bound when iterator is decremented
SET_WHEEL       EQU 10B     ;bit value corresponding to wheel motor on
ALL_MOTORS_OFF  EQU 0       ;value when all motors are off
SET_LASER       EQU 10000000B;value corresponding to laser on
LASER_OFF       EQU 0       ;value corresponding to laser being off
PWM_RES         EQU 128     ;number of times PWM signal is updated each cycle
SPEED_BITS      EQU 01111111B ;bits of the velocity that correspond to speed
DIRECTION_BIT   EQU 10000000B ;bit of the velocity that corresponds to wheel
                              ; direction
SPD_DWN_SCALE   EQU 1
WRD_TAB_OFFSET  EQU 1       ;to account for incrementing in tables when using words
DIRECTION_BIT_OFFSET  EQU 7 ;how far from first bit the direction bit is
LOOP_IT_OFFSET  EQU -2      ;offset from BP in stack for loop iterator
REVERSE         EQU 1       ;value of direction when the wheel direction is reverse
                              
MOTOR_PORT		EQU 181H    ;location of port B of 8255 chip, used for motors
CONTROL_VALUE   EQU 10000000B ;written to control register to initialize motors
CONTROL_ADDRESS EQU 183H    ;control address of 8255 chip 


