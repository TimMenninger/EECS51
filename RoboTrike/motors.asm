    NAME MOTORS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                                        ;
;                                       MOTORS.ASM                                       ;
;                            Functions to Set Motors and Laser                           ;
;                                      Tim Menninger                                     ;
;                                                                                        ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Description:      This code has the code to initialize motors and set them.  It sets
;					the direction of the trike, linear speed and fires/ceases firing the
;					laser.
;
; Contents:			MotorInit - initializes motors to have no speed and laser off
;					SetMotorSpeed - sets an absolute motor speed and direction
;					GetMotorSpeed - returns the current motor speed
;					GetDirection - returns the current direction of motion
;					SetLaser - turns the laser on or off depending on argument
;					GetLaser - returns the status of the laser
;					SetPWM - counts interrupts and turns motors on for a calculated
;						proportion of time (pulse width modulation)
;
; Input:            None.
;
; Output:           The ports relating to the keypads and displays are written
;					values so we can access them.
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
;    11/11/92  Glen George      initial revision (originally ISRDEMO.ASM)
;	 11/07/14  Tim Menninger	adapted to supplement RoboTrike processes
;	 12/11/14  Tim Menninger	added header, changed MotorInit to call SetMotorSpeed
;								and SetLaser instead of manually writing to 8255 chip
;



CGROUP  GROUP   CODE
DGROUP	GROUP	DATA


CODE	SEGMENT PUBLIC 'CODE'


        ASSUME  CS:CGROUP, DS:DGROUP
        
        EXTRN   Sin_Table:WORD          ;table of sin values
        EXTRN   Cos_Table:WORD          ;table of cos values
        
        
$INCLUDE(motors.inc)			;includes constants used in this program

;
; MotorInit
;
; Description:       This procedure initializes variables related to the
;					 motors, preparing the for the event handler to correctly
;					 handle events.
;
; Operation:         This function sets shared variables to their initial values
;					 one at a time.  Then, it sets the wheel speed array to have
;                    all zeroes.
;
; Arguments:         None.
;
; Return Value:      None.
;
; Local Variables:   BX - iterator for the wheel array
;
; Shared Variables:  PWM_counter (WRITE) - counts how many interrupts so we know when
;                    to turn on and off the motors
;
;                    laser_status (WRITE) - TRUE if the laser is on FALSE otherwise
;
;                    total_speed (WRITE) - current speed of the trike
;   
;                    trike_angle (WRITE) - angle of motion of the trike
;
; Global Variables:  None.
;
; Input:             None.
;
; Output:            motors - this turns on/off the wheel motors
;                    laser - turns on/off the laser
;
; Error Handling:    None.
;
; Algorithms:        None.
;
; Data Structures:   None.
;
; Registers Changed: None
;
        

MotorInit       PROC        NEAR
                PUBLIC      MotorInit

    PUSH AX                     ;store registers
    PUSH DX
    PUSH BX
    
ResetMotorVals:
    MOV  DX, CONTROL_ADDRESS    ;want to load control value into control address
    MOV  AX, CONTROL_VALUE      ;   OUT requires AX and DX
    OUT  DX, AX                 ;set up 8255 chip for writing to motors
    
    MOV  PWM_counter, INIT_ITER ;initialize PWM_counter
    MOV  laser_status, LASER_OFF;turn the laser off
    MOV  total_speed, NO_SPEED  ;stop motion
    MOV  trike_angle, ANGLE_ZERO;reset the angle
    
    MOV  BX, INIT_ITER          ;will be our counter, initialize it
    
ResetMotors:    
    MOV  AX, NO_SPEED			;want to stop motion
    MOV  BX, ANGLE_ZERO			;want direction to be zero
    CALL SetMotorSpeed			;set motors to be zero speed and straight forward
    
    MOV  AX, LASER_OFF			;want to turn laser off
    CALL SetLaser				;call SetLaser to turn the laser off
    
    POP  BX                     ;recall registers used
    POP  DX
    POP  AX
    RET

MotorInit       ENDP


;
; GetMotorSpeed
;
; Description:       This procedure returns the current speed of the trike.
;
; Operation:         This function reads the shared variable for speed and returns
;                    it in AX.
;
; Arguments:         None.
;
; Return Value:      AX - current speed of the trike
;
; Local Variables:   None.
;
; Shared Variables:  total_speed (READ) - the current speed of the trike
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
; Registers Changed: AX - the return value
;


GetMotorSpeed   PROC        NEAR
                PUBLIC      GetMotorSpeed
                
MovMotorSpeed:
    MOV  AX, total_speed        ;want to return total speed in AX
    RET
    
GetMotorSpeed   ENDP

;
; GetMotorDirection
;
; Description:       This procedure returns the current direction of the trike.
;
; Operation:         This function reads the shared variable for direction and returns
;                    it in AX.
;
; Arguments:         None.
;
; Return Value:      AX - current angle of motion of the trike
;
; Local Variables:   None.
;
; Shared Variables:  trike_angle (READ) - the current angle of motion of the trike
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
; Registers Changed: AX - the return value
;


GetMotorDirection   PROC    NEAR
                    PUBLIC  GetMotorDirection

MovMotorDirection:
    MOV  AX, trike_angle        ;want to return angle in AX
    RET
    
GetMotorDirection   ENDP


;
; GetLaser
;
; Description:       This procedure returns whether the laser is on or off.
;
; Operation:         This function reads the shared variable for the condition
;                    (on or off) of the laser and returns a Boolean value in AX
;                    corresponding to on (TRUE) or off (FALSE).
;
; Arguments:         None.
;
; Return Value:      AX - Boolean for laser status (on = TRUE off = FALSE)
;
; Local Variables:   None.
;
; Shared Variables:  laser_status (READ) - TRUE if the laser is set FALSE otherwise
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
; Registers Changed: AX - the return value
;


GetLaser        PROC        NEAR
                PUBLIC      GetLaser

MovLaser:
    MOV  AX, laser_status       ;want to return laser status in AX
    RET
    
GetLaser    ENDP


;
; SetLaser
;
; Description:       This procedure sets or resets the laser depending on the
;                    argument in AX.  Zero resets the laser and nonzero sets it.
;
; Operation:         This function takes as input a number that is either 0 or
;                    nonzero in AX.  It will write the value in AX to the shared
;                    variable for laser status for the event handler to read and
;                    set/reset motors accordingly.  It then returns.
;
; Arguments:         AX - 0 if the laser should be turned off and nonzero if the
;                    laser should be turned on.
;
; Return Value:      None.
;
; Local Variables:   None.
;
; Shared Variables:  laser_status (WRITE) - the current speed of the trike
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


SetLaser        PROC        NEAR
                PUBLIC      SetLaser

SetTheLaser:
    MOV  laser_status, AX       ;want to change laser status to input (in AX)
    RET
  
SetLaser    ENDP

;
; SetMotorSpeed
;
; Description:       This procedure takes as its argument a speed and an angle.
;                    It takes the angle and puts it into a reasonable range
;                    (0 to 359 degrees) and then calculates the speed each wheel
;                    needs in order to move the specified speed in the specified
;                    direction.  It then writes the speeds and directions of the
;                    wheels into buffers that are read in another function that
;                    is called as a result of a timer interrupt.  If the speed
;                    argument is 65535, the speed does not change and if the 
;                    angle argument is -32768 then the angle does not change from
;                    what it previously was (as stored in shared variables).
;
; Operation:         This function first checks what the speed argument was.  If
;                    it was 65535, then it does nothing to the shared variable
;                    for speed.  Otherwise, it changes the speed variable to match
;                    the argument.  Then, it checks the angle argument.  If it is
;                    -32768, then it does nothing to the shared variable for angle
;                    and otherwise continues to mod the argument with 360 (degrees
;                    in a circle), mapping the argument to a degree between 0 and
;                    360.  It then writes this value to the shared variable for
;                    angle.
;
;                    Now that the speed and angle variables are set, the function
;                    proceeds to calculate the contribution from each wheel.  It
;                    enters a loop that iterates through the wheels.  For each
;                    wheel, it multiplies the x force of the wheel (which is
;                    stored in a table in the code segment) by the cosine of the
;                    angle (also stored in a table in the code segment), then
;                    multiplies that by the total speed.  To do this, we use
;                    fixed point notation, with the sine and cosine values in
;                    Q0.15, as well as the force, and the speed in Q0.15.  The
;                    same process is followed with y force and sine.  The two
;                    values obtained are then added together and scaled down to
;                    be in range of the PWM resolution.  To scale them down, we
;                    essentially truncate as many bits as necessary leaving a
;                    number within range of the resolution.  Now that we have a
;                    speed (which is signed), we store the bits corresponding to
;                    the speed into one buffer and the bit corresponding to
;                    direction into another buffer.  These two are then used
;                    by the PWM (called from a timer event handler) to set the
;                    speed and direction of the motors.
;
; Arguments:         AX - new speed, or number indicating not to change the speed
;                    BX - new angle, or number indicating not to change the angle
;
; Return Values:     None.
;
; Local Variables:   AX - iterator for the wheel in consideration
;                       - also used for x-speed of wheel in consideration
;                    DX - speed of wheel
;                    BP + LOOP_IT_OFFSET - iterator for updating wheel arrays
;
; Shared Variables:  total_speed (WRITE) - current speed of the trike
;   
;                    trike_angle (WRITE) - angle of motion of the trike
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
; Registers Changed: None
;


SetMotorSpeed   PROC        NEAR
                PUBLIC      SetMotorSpeed
                
    PUSHA
                
ChangeSpeed:
    CMP  AX, NO_SPD_CHNG    ;check if input indicates not to change the speed
    JE   ChangeAngle        ;only want to change speed if not equal to NO_SPD_CHNG
    MOV  total_speed, AX    ;if not, change total speed to match argument
    ;JMP ChangeAngle
   
ChangeAngle:
    CMP  BX, NO_ANGL_CHNG   ;check if argument indicates not to change angle
    JE   WheelLoopSetup     ;only change angle if not equal to NO_ANGL_CHNG
    MOV  AX, BX             ;want angle in AX
    MOV  CX, DEGREES_IN_CIRC;want to mod by degrees in circle
    CWD                     ;prepare for division
    IDIV CX                 ;divide by degrees in circle so we can use remainder (mod)
    
    ADD  DX, DEGREES_IN_CIRC;remainder negative if negative, this will make it pos.
    MOV  AX, DX             ;now want to divide using remainder, which must be in AX
    MOV  DX, DX_DIVIDE_PREP ;prepare to divide
    DIV  CX                 ;if it was already positive, this will put it back in range
    MOV  trike_angle, DX    ;remainder is now a valid degree
    ;JMP WheelLoopSetup

WheelLoopSetup:
    MOV   AX, INIT_ITER     ;initialize our iterator, AX
    ;JMP  UpdateWheelArray

CheckIter:
    CMP   AX, NUM_WHEELS    ;see if we have iterated through all wheels
    JB    UpdateWheelArray  ;if not, continue updating array
    JMP   MotorSpeedSet     ;if so, were done iterating
    
UpdateWheelArray:    
    MOV   BP, SP            ;stored a variable on stack, want a constant reference point
    PUSH  AX                ;will change, want to remember iteration
    
    LEA   DI, Cos_Table     ;want to look up cosine of angle
    MOV   CX, trike_angle   ;need the angle we are going to look up
    SHL   CX, 1             ;must account for table of words
    ADD   DI, CX            ;add angle to offset of table
    MOV   CX, CS:[DI]       ;load cosine of angle into reg
    
    LEA   SI, X_Forces      ;now want to look up x force for wheel
    MOV   DX, SS:[BP + LOOP_IT_OFFSET];recall iterator
    SHL   DX, 1             ;must account for table of words
    ADD   SI, DX            ;add iterator to offset of table
    MOV   AX, CS:[SI]       ;load force of current wheel into reg
    
    MOV   BX, AX            ;want to multiply without changing, so we need AX
    MOV   AX, total_speed   ;we are multiplying trike speed by force and cosine of angle
    SHR   AX, SPD_DWN_SCALE ;we want to scale down the speed to leave room for sign bit
    IMUL  BX                ;multiply speed by wheel x force
    MOV   AX, DX            ;truncate to DX
    IMUL  CX                ;multiply speed/force by cosine angle
    PUSH  DX                ;remember this value for later
    
    LEA   DI, Sin_Table     ;want to look up cosine of angle
    MOV   CX, trike_angle   ;need the angle we are going to look up
    SHL   CX, 1             ;must account for table of words
    ADD   DI, CX            ;add angle to offset of table
    MOV   CX, CS:[DI]       ;load cosine of angle into reg
    
    LEA   SI, Y_Forces      ;now want to look up x force for wheel
    MOV   DX, SS:[BP + LOOP_IT_OFFSET];recall iterator
    SHL   DX, 1             ;must account for table of words
    ADD   SI, DX            ;add iterator to offset of table
    MOV   AX, CS:[SI]       ;load force of current wheel into reg
    
    MOV   BX, AX            ;want to multiply without changing, so we need AX
    MOV   AX, total_speed   ;we are multiplying trike speed by force and cosine of angle
    SHR   AX, SPD_DWN_SCALE ;we want to scale down the speed to leave room for sign bit
    IMUL  BX                ;multiply speed by wheel x force
    MOV   AX, DX            ;truncate to DX
    IMUL  CX                ;multiply speed/force by cosine angle
    
    POP   AX                ;recall x value
    ADD   DX, AX            ;add x and y values
    SAL   DX, 2
    
    MOV   DL, DH            ;duplicate wheel speed so we can perform different operations
    AND   DH, SPEED_BITS    ;want speed and direction separate
    AND   DL, DIRECTION_BIT ;remember only the direction bit
    SHR   DL, DIRECTION_BIT_OFFSET;move the direction bit to the lowest bit
    MOV   CL, DH            ;want to move speed into different register
    XOR   CH, CH            ;clear high byte of CX
    XOR   DH, DH            ;now CX has speed and DX has direction
    
    POP   AX                ;recall iterator
    
    MOV   BX, AX            ;indexing arrays disallows AX
    SHL   BX, 1             ;shift to account for our table having words
    MOV   wheel_speeds[BX], CX;load speed into buffer
    MOV   wheel_dirs[BX], DX;load direction into buffer
   
    INC   AX                ;increment our iterator that we just popped
    CMP   DX, REVERSE       ;check if we just put in a speed that is backwards
    JE    AlterSpeed        ;if we did, we must alter the speed
    JMP   CheckIter         ;and repeat

AlterSpeed:                 ;must account for negative value when speed negative
    MOV   DX, PWM_RES       ;want to subtract speed (in CX) from maximum speed
    SUB   DX, CX
    MOV   wheel_speeds[BX], DX;overwrite the new speed
    JMP   CheckIter         ;go back to beginning of loop
    
MotorSpeedSet:              ;motor speed set, can return
    POPA
    RET
    
SetMotorSpeed   ENDP


;
; SetPWM
;
; Description:       This procedure is called by the timer event handler to write
;                    speed values to the wheels.  It takes the speeds from one
;                    buffer and the directions from another and writes them to
;                    Port B in order to change the PWM of that motor.  It also
;                    reads the laser status and turns on/off the laser.
;
; Operation:         This function starts by setting what will be output to
;                    a default value where all of the motors are off as well
;                    as the laser.  It then increments the PWM counter.  If
;                    the counter reaches the max count, then it resets it to
;                    start counting from the beginning.
;
;                    The function then enters a loop where it iterates through
;                    the wheels and the buffers associated with their speed and
;                    directions.  Because the speed is between 0 and the
;                    resolution, we compare the counter to the speed and turn
;                    the motor on if the counter is less than the speed value
;                    and off if it is greater than or equal to it.  This
;                    guarantees that the motors' duty cycles are appropriate to
;                    their speed.  It does this by OR-ing a motor-set constant.
;                    Then, if the motor is supposed to be running in reverse,
;                    it sets the lowest bit accordingly.  It then repeats until
;                    all of the motors have been recorded.  Finally, it checks
;                    the status of the laser, and if it should be on, it ORs in
;                    a bit that sets the laser.  It is then sent to the port
;                    corresponding to the motors.
;
; Arguments:         None.
;
; Return Value:      None.
;
; Local Variables:   AX - the value that will be sent to the motor port
;                    BX - an iterator for the wheels
;
; Shared Variables:  PWM_counter (WRITE) - counts how many interrupts so we know when
;                    to turn on and off the motors
;
;                    laser_status (READ) - TRUE if the laser is on FALSE otherwise
;
;                    total_speed (READ) - current speed of the trike
;   
;                    trike_angle (READ) - angle of motion of the trike
;
; Global Variables:  None.
;
; Input:             None.
;
; Output:            motors - this turns on/off the wheel motors
;                    laser - this turns on/off the laser
;
; Error Handling:    None.
;
; Algorithms:        None.
;
; Data Structures:   None.
;
; Registers Changed: None
;

SetPWM              PROC    NEAR
                    PUBLIC  SetPWM
                    
    PUSHA
              
PrepPWMCounters:
    MOV  BX, NUM_WHEELS     ;writing for each wheel and in reverse order
    MOV  AX, ALL_MOTORS_OFF ;want to initialize DX, as it will be our output
    INC  PWM_counter        ;increment our counter that takes care of PWM
    CMP  PWM_counter, PWM_RES;see if increment must be wrapped
    JB   WriteMotorBits     ;if not, begin writing corresponding bits
    ;JAE WrapPWMCntr
    
WrapPWMCntr:
    MOV  PWM_counter, INIT_ITER;reset counter before continuing
    ;JMP WriteMotorBits
    
WriteMotorBits:
    CMP  BX, DONE_DEC       ;see if we have written for all wheels
    JE   CheckLaser         ;if we have, move on to check laser
    DEC  BX                 ;otherwise, decrement counter and do next wheel
    MOV  DI, BX             ;load into DI because we must index by twice the iterator
    SHL  DI, 1               ;must account for table of words
    MOV  CX, wheel_speeds[DI];read the wheel speed of current wheel
    CMP  PWM_counter, CX    ;only want motor on if it is less than speed (max speed
                            ;   and max counter are equivalent, so this gives duty cycle)
    JAE  KeepMotorOff       ;if it is greater, keep the motor off
    JB   TurnMotorOn        ;otherwise, write bits to turn it on

KeepMotorOff:
    SHL  AX, 1              ;want to make room to write next bit
    JMP  WriteMotorBits     ;go to start of loop
    
TurnMotorOn:
    SHL  AX, 1              ;make room to write next bit
    OR   AX, SET_WHEEL      ;set bit to turn wheel on
    OR   AX, wheel_dirs[DI] ;account for motor direction
    JMP  WriteMotorBits     ;go to start of loop

CheckLaser:
    CMP  laser_status, LASER_OFF;check if laser is on or off
    JE   WriteToMotors      ;if off, do nothing to the laser and continue
    OR   AX, SET_LASER      ;want to turn laser on
    ;JMP WriteToMotors
    
WriteToMotors:
    MOV  DX, MOTOR_PORT     ;need motor port in DX so we can execute OUT instruction
    OUT  DX, AL             ;write motor values to port for motors
    
    POPA
    RET

SetPWM  ENDP



;x components of the forces for each wheel.  values are in Q0.15 form
X_Forces        LABEL   WORD
                PUBLIC  X_Forces
     
;       DW  X force             ;wheel, decimal value

        DW  0111111111111111B   ;front, 1
        DW  1100000000000000B   ;right, -1/2
        DW  1100000000000000B   ;left,  -1/2

        
;y components of the forces for each wheel.  values are in Q0.15 form        
Y_Forces        LABEL   WORD
                PUBLIC  Y_Forces
                
;       DW  Y force             ;wheel, decimal value

        DW  0                   ;front, 0        
        DW  1001000100100111B   ;right, -sqrt(3)/2
        DW  0110111011011001B   ;left,  sqrt(3)/2
        
        
CODE    ENDS




DATA    SEGMENT PUBLIC  'DATA'

	laser_status    DW	?					;0 if laser is off, nonzero otherwise
    total_speed     DW  ?                   ;speed the robot is moving
    trike_angle     DW  ?                   ;angle the robot is moving
    PWM_counter     DW  ?                   ;counts interrupts so we can PWM
	
	wheel_speeds	DW	(NUM_WHEELS)	DUP	(?)	;contains speed of each wheel
	wheel_dirs	    DW	(NUM_WHEELS)    DUP (?)	;contains direction (0 = forward
                                                ;   1 = backward) of each wheel

DATA    ENDS

    END