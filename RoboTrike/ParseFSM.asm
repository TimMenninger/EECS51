        NAME  ParserFSM

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                 PARSEFSM.ASM                               ;
;                   Driver for Parsing Serial Command Strings                ;
;								  Tim Menninger								 ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;
; This file contains the main functions for parsing ASCII characters as part
; of a larger string containing a command.  The functions included are:
;	GetSerToken 	- takes an ASCII character and returns the token type and value
;	ParseSerialChar - takes a character and determines how to interpret it in the scope
;					  of robot commands
;   InitParser 		- (FSM routine) initializes parsing variables
;	doNOP 			- (FSM routine) does nothing, is merely a table filler
;	NoErr 			- (FSM routine) clears the error flag variable
;	ParseErr 		- (FSM routine) sets the error flag variable
;	FireLaser 		- (FSM routine) fires the laser
;	CeaseLaserFire  - (FSM routine) turns laser off
;	SetSign 	   	- (FSM routine) stores sign of argued number in shared variable
;	NewSpeed 	   	- (FSM routine) sets absolute linear speed for robotrike
;	AddSpeed 	   	- (FSM routine) sets relative linear speed for robotrike
;	UpdAngle 	   	- (FSM routine) sets absolute direction for robotrike motion
;	NewAngle 	   	- (FSM routine) sets absolute direction for robotrike motion
;	RelTurrAngle   	- (FSM routine) sets relative turret angle
;	NewTurrAngle   	- (FSM routine) sets absolute turret angle
;	NewElev 	   	- (FSM routine) sets absolute turret elevation
;	AddElev 	   	- (FSM routine) sets relative turret elevation
;	UpdSetting     	- (FSM routine) deciphers digits with knowledge of previous digits
;
; Revision History:
;    02/26/03  Glen George              initial revision
;    02/24/05  Glen George              simplified some code in ParseFP
;                                       updated comments
;	 12/05/14  Tim Menninger			Altered significantly to parse serial characters
;	 12/12/14  Tim Menninger			Changed UpdAngle to set absolute angle instead
;										of relative angle.
;


; local include files
$INCLUDE(Parse.inc)
$INCLUDE(Boolean.inc)




CGROUP  GROUP   CODE
DGROUP	GROUP	DATA


CODE	SEGMENT PUBLIC 'CODE'


        ASSUME  CS:CGROUP,	DS:DGROUP


; external action routines used

		EXTRN	SetMotorSpeed:NEAR		;sets motor speed and angle
		EXTRN	GetMotorSpeed:NEAR		;gets current motor speed (linear speed)
		EXTRN	SetLaser:NEAR			;turns laser on and off
		EXTRN	SetTurretAngle:NEAR		;sets angle of turret
		EXTRN	GetTurretAngle:NEAR		;returns current angle of turret
		EXTRN	SetRelTurretAngle:NEAR	;sets angle of turret relative to current angle
		EXTRN	SetTurretElevation:NEAR	;sets elevation of turret
		EXTRN	GetTurretElevation:NEAR	;returns current elevation of turret



;
; GetSerToken
;
; Description:      	This procedure returns the token class and token value for
;                   	the passed character.  The character is truncated to
;                   	7-bits.
;
; Operation:        	Looks up the passed character in two tables, one for token
;                   	types or classes, the other for token values.  It first looks
;						for token type, stores that in the high byte of AX, then looks for
;						token value and keeps that in the low byte.
;
; Arguments:        	AL - character to look up.
;
; Return Value:     	AL - token value for the character.
;
;                   	AH - token type or class for the character.
;
; Local Variables:  	BX - table pointer, points at lookup tables.
;
; Shared Variables: 	None.
;
; Global Variables: 	None.
;
; Input:            	None.
;
; Output:           	None.
;
; Error Handling:   	None.
;
; Algorithms:       	Table lookup.
;
; Data Structures:  	Two tables, one containing token values and the other
;                   	containing token types.
; 
;Limitations:           None.
; 
;Known Bugs:            None.
; 
;Special Notes:         None.
; 	

GetSerToken	PROC    NEAR

	PUSH BX								;store register

InitGetSerToken:						;setup for lookups
	AND  AL, TOKEN_MASK					;strip unused bits (high bit)
	MOV  AH, AL							;and preserve value in AH

TokenTypeLookup:                        ;get the token type
    MOV  BX, OFFSET(TokenTypeTable)  	;BX points at table
	XLAT CS:TokenTypeTable				;have token type in AL
	XCHG AH, AL							;token type in AH, character in AL

TokenValueLookup:						;get the token value
    MOV  BX, OFFSET(TokenValueTable) 	;BX points at table
	XLAT CS:TokenValueTable				;have token value in AL

EndGetToken:                     		;done looking up type and value
	POP  BX								;restore register
    RET


GetSerToken	ENDP




; ParseSerialChar
;
; Description:      This procedure parses a passed ASCII character that is assumed
;                   to be part of a command.  The valid characters depends on the current
;					state of the machine, but in general,
;						S#  sets absolute speed.  The # can start with a '+' sign or with
;							digits, but a '-' will cause an error.  The # must fit in 15
;							bits.
;						V#  sets relative speed.  The # can start with a digit, implying
;							add to the current speed, or a sign implying to add ('+') or
;							subtract ('-') from the current speed.
;						D#	sets the direction.  If the # starts with a digit, an absolute
;							direction is set.  If it starts with a sign, it either adds
;							('+') to the current angle or subtracts ('-') from it.
;						T#	rotates the turret.  If the # starts with a digit, an absolute
;							angle is rotated to.  If it starts with a sign, it either adds
;							('+') or subtracts ('-') to the current turret angle.
;						E#	changes the turret elevation.  If the # starts with a digit,
;							the elevation changes to an absolute angle.  If it starts with
;							a sign, it either adds ('+') or subtracts ('-') to the current
;							turret elevation angle.
;						F	fires the laser.
;						O	turns the laser off.
;					This function handles the character according to the current state and
;					what command it is trying to execute.
;
; Operation:        Uses a state machine to translate the command.  It uses the character,
;					current state and a transition table to determine what the next state
;					should be and what function(s) should be called.  It then calls
;					those functions, changes the state accordingly and moves on to check
;					if an error occurred during the process.  It returns whether or not
;					an error has occurred.
;
; Arguments:        AL - character to parse
;
; Return Value:     AX - TRUE if error was encountered in parsing, FALSE otherwise
;
; Local Variables:  BX - pointer to state transition table
;
; Shared Variables: curr_state (WRITE) - current state of the machine
;
;					ser_error (READ) - boolean TRUE if error reached, FALSE otherwise
;
; Global Variables: None.
;
; Input:            None.
;
; Output:           None.
;
; Error Handling:   If the passed string does not hold a valid character, then an
;					error flag (shared variable) is set and returned.  In this case,
;                   the FSM moves to the error state until the end-command character
;                   is detected.
;
; Algorithms:       State Machine.
;
; Data Structures:  None.
;
; Known Bugs:		None.
;
; Special Notes:	None.
;



ParseSerialChar		PROC    NEAR
            		PUBLIC  ParseSerialChar
	
	PUSH BX								;store registers
	PUSH CX
	PUSH DX

DoNextToken:							;get next input for state machine
    PUSH AX                             ;store argued character
	CALL GetSerToken					;and get the token type and value
	MOV  DH, AH							;and save them in DH and CH
	MOV  CH, AL

ComputeTransition:						;figure out what transition to do
	MOV  AX, NUM_TOKEN_TYPES			;find row in the table
	MOV  CL, curr_state					;get current_state to find row
	MUL  CL								;AX is start of row for current state
	ADD  AL, DH							;get the actual transition

	IMUL BX, AX, SIZE TRANSITION_ENTRY  ;now convert to table offset

DoActions:								;do the actions (don't affect regs)
    POP  DX                             ;recall argued character
	MOV  AL, CH							;get token value back for actions
	CALL CS:StateTable[BX].ACTION1		;do the actions
    
CheckError:
    CMP  ser_error, NO_ERROR            ;check if there is an error
    JNE  GoToErrorState                 ;if so, want to change to error state

DoTransition:							;now go to next state
	MOV  CL, CS:StateTable[BX].NEXTSTATE;get next state from table
    MOV  curr_state, CL                 ;load into shared variable for current state
    JMP  EndSerParse                    ;want to skip error state
    
GoToErrorState:
    MOV  curr_state, ST_ERROR           ;error, go to error state

EndSerParse:							;done parsing, return with value
	MOV  AX, ser_error					;want to return error status
	POP  DX								;restore registers
	POP  CX
	POP  BX
    RET

ParseSerialChar		ENDP

;
;InitParser
;
;Description:			This function initializes all of the variables related to the
;						serial parsing program and associated finite state machine.  It
;						resets the error variable, sets the state to the start state and
;						initializes the variable for changed setting to zero.
; 
;Operation:             This puts values into each of the shared variables one by one.
; 
;Arguments:				None.
; 
;Return Values:         None.
; 
;Global Variables:      None.
; 
;Shared Variables:      curr_state (WRITE) - keeps track of which state in the FSM we are
;						currently in
;
;						ser_error (WRITE) - TRUE if a serial error has been encountered
;						FALSE otherwise
;
;						setting_chg (WRITE) - keeps track of the value we are changing
;						something by/to
;
;						update_sign (WRITE) - tells us if our setting_chg should be
;						positive or negative
;
;                       have_argument (WRITE) - TRUE if we have argument, FALSE otherwise
; 
;Local Variables:       None.
; 
;Inputs:                None.
; 
;Outputs:               None.
;
;Registers Changed:		None.
; 
;Error Handling:        None.
; 
;Algorithms:            None.
; 
;Data Structures:       None.
; 
;Limitations:           None.
; 
;Known Bugs:            None.
; 
;Special Notes:         None.
; 	

InitParser		PROC	NEAR
				PUBLIC	InitParser
	
	MOV  curr_state, ST_INITIAL		;go to start state
	MOV  ser_error, FALSE			;shouldn't be an error yet (obviously)
	MOV  setting_chg, INIT_SETCHG	;not changing anything yet
	MOV  update_sign, INIT_SIGN		;have no sign, don't want this interfering elsewhere
    MOV  have_argument, FALSE       ;we do not have a numerical argument
    
    RET
	
InitParser		ENDP


;
;doNOP
;
;Description:			This does nothing.  It is merely a filler for the transition
;						table.
; 
;Operation:             This does NOP then returns.
; 
;Arguments:				None.
; 
;Return Values:         None.
; 
;Global Variables:      None.
; 
;Shared Variables:      None.
; 
;Local Variables:       None.
; 
;Inputs:                None.
; 
;Outputs:               None.
;
;Registers Changed:		None.
; 
;Error Handling:        None.
; 
;Algorithms:            None.
; 
;Data Structures:       None.
; 
;Limitations:           None.
; 
;Known Bugs:            None.
; 
;Special Notes:         None.
; 	

doNOP			PROC	NEAR
				PUBLIC	doNOP
				
	RET
	
doNOP			ENDP



;
;NoErr
;
;Description:			This is called if there was no error and thus sets the error
;						flag to false to indicate no errors.
; 
;Operation:             This writes FALSE to the error flag shared variable.
; 
;Arguments:				None.
; 
;Return Values:         None.
; 
;Global Variables:      None.
; 
;Shared Variables:      ser_error (WRITE) - TRUE if error encountered, FALSE otherwise
; 
;Local Variables:       None.
; 
;Inputs:                None.
; 
;Outputs:               None.
;
;Registers Changed:		None.
; 
;Error Handling:        None.
; 
;Algorithms:            None.
; 
;Data Structures:       None.
; 
;Limitations:           None.
; 
;Known Bugs:            None.
; 
;Special Notes:         None.
; 	

NoErr			PROC	NEAR
				PUBLIC	NoErr
			
	MOV  ser_error, NO_ERROR		;document that there has been no error
	RET
	
NoErr			ENDP



;
;ParseErr
;
;Description:			This is called if an error is encountered in parsing.  It sets a
;						shared variable error flag to indicate an error occurred.  The
;                       flag is set to the value of the ASCII character that caused the
;                       error but with the high bit set (since ASCII characters fit in
;                       7 bits)
; 
;Operation:             This sets the high bit of the 7-bit ASCII character, then sets
;                       the error variable to hold that value (so we know what character
;                       caused the failure).
; 
;Arguments:				DX - character that caused error
; 
;Return Values:         None.
; 
;Global Variables:      None.
; 
;Shared Variables:      ser_error (WRITE) - TRUE if an error occurs, FALSE otherwise
; 
;Local Variables:       None.
; 
;Inputs:                None.
; 
;Outputs:               None.
;
;Registers Changed:		None.
; 
;Error Handling:        None.
; 
;Algorithms:            None.
; 
;Data Structures:       None.
; 
;Limitations:           None.
; 
;Known Bugs:            None.
; 
;Special Notes:         None.
; 	

ParseErr		PROC	NEAR
				PUBLIC	ParseErr
	
    MOV  DH, curr_state             ;put current state in high byte of serial error
	MOV	 ser_error, DX          	;store ASCII character that caused error
	RET
	
ParseErr		ENDP



;
;FireLaser
;
;Description:			This function fires the laser.
; 
;Operation:             SetLaser takes a boolean argument, so it calls SetLaser with a
;						TRUE argument to turn the laser on.  Then, it calls ParserInit
;                       to reset all of the variables (as this is only called at the
;                       end of a command).
; 
;Arguments:				None.
; 
;Return Values:         None.
; 
;Global Variables:      None.
; 
;Shared Variables:      None.
; 
;Local Variables:       None.
; 
;Inputs:                None.
; 
;Outputs:               None.
;
;Registers Changed:		None.
; 
;Error Handling:        None.
; 
;Algorithms:            None.
; 
;Data Structures:       None.
; 
;Limitations:           None.
; 
;Known Bugs:            None.
; 
;Special Notes:         None.
; 	

FireLaser		PROC	NEAR
				PUBLIC	FireLaser
				
	PUSH AX							;store register
			
	MOV  AX, TRUE					;want to set laser with TRUE value
	CALL SetLaser					;set the laser (uses value in AX)
    
    CALL InitParser                 ;done command, reset variables
	
	POP  AX							;restore register
	RET
	
FireLaser		ENDP



;
;CeaseLaserFire
;
;Description:			This function turns the laser off.
; 
;Operation:             SetLaser requires a boolean input.  This function calls SetLaser
;						with a FALSE argument in order to turn the laser off.  Then,
;                       InitParser is called to reset all of the variables, as this
;                       procedure is only called at the end of a command.
; 
;Arguments:				None.
; 
;Return Values:         None.
; 
;Global Variables:      None.
; 
;Shared Variables:      None.
; 
;Local Variables:       None.
; 
;Inputs:                None.
; 
;Outputs:               None.
;
;Registers Changed:		None.
; 
;Error Handling:        None.
; 
;Algorithms:            None.
; 
;Data Structures:       None.
; 
;Limitations:           None.
; 
;Known Bugs:            None.
; 
;Special Notes:         None.
; 	

CeaseLaserFire	PROC	NEAR
				PUBLIC	CeaseLaserFire
				
	PUSH AX							;store register
				
	MOV  AX, FALSE					;want to clear laser with FALSE value
	CALL SetLaser					;unset the laser (uses value in AX)
    
    CALL InitParser                 ;done command, reset variables
	
	POP  AX							;restore register
	RET

CeaseLaserFire	ENDP



;
;SetSign
;
;Description:			This records whether our command argument is positive or negative.
; 
;Operation:             This writes to the shared variable containing the sign of the
;						command the token value of either '+' or '-' (whichever resulted
;						in the calling of this procedure).
; 
;Arguments:				None.
; 
;Return Values:         None.
; 
;Global Variables:      None.
; 
;Shared Variables:      update_sign (WRITE) - remember if argument is positive or negative
; 
;Local Variables:       None.
; 
;Inputs:                None.
; 
;Outputs:               None.
;
;Registers Changed:		None.
; 
;Error Handling:        None.
; 
;Algorithms:            None.
; 
;Data Structures:       None.
; 
;Limitations:           None.
; 
;Known Bugs:            None.
; 
;Special Notes:         None.
; 	

SetSign			PROC	NEAR
				PUBLIC	SetSign
				
	MOV  update_sign, AL		;want update_sign to reflect argued token value
	RET
	
SetSign			ENDP



;
;NewSpeed
;
;Description:			This procedure takes the value in the change setting variable,
;						scales it to 16 bits and changes the speed to that value.
; 
;Operation:             This first gets from a shared variable the value of the new speed,
;						which fits in 15 bits.  SetMotorSpeed expects a 16 bit input, so
;						it scales the new speed accordingly.  It then calls SetMotorSpeed
;						with that new speed argument and an angle argument that indicates
;						not to change direction of the trike.  This only happens if there
;                       are no errors.  Then, also if there are no errors, InitParser is
;                       called to reset all of the variables, as NewSpeed is only called
;                       at the end of a command.
; 
;Arguments:				None.
; 
;Return Values:         None.
; 
;Global Variables:      None.
; 
;Shared Variables:      setting_chg (READ) - keeps track of what we are changing value by
;
;                       ser_error (WRITE) - TRUE if error encountered, FALSE otherwise
;
;                       have_argument (READ) - TRUE if we have argument, FALSE otherwise
; 
;Local Variables:       None.
; 
;Inputs:                None.
; 
;Outputs:               None.
;
;Registers Changed:		None.
; 
;Error Handling:        If this function is called without an argument (i.e. we got the
;                       character for this particular command, but no value to change to),
;                       the error flag is set.
;
;                       If the value read from the setting change variable is not within
;                       the range accepted by the function to be called, the error flag is set.
; 
;Algorithms:            None.
; 
;Data Structures:       None.
; 
;Limitations:           None.
; 
;Known Bugs:            None.
; 
;Special Notes:         None.
; 	

NewSpeed		PROC	NEAR
				PUBLIC	NewSpeed
				
	PUSH AX							;store registers
	PUSH BX
    
    CMP  have_argument, TRUE        ;check to see if we have an argument for motor
    JNE  NoNewSpdArg                ;if not, we can't write to motors
	
SetNewSpd:
	MOV  AX, setting_chg			;want to change speed to what is in setting_chg
	MOV  BX, SAME_DIRECT			;don't want to change direction of motion
    
    CMP  AX, MAX_SPEED              ;check to make sure new speed is in range
    JA   NewSpdError                ;if too large, set error
    CMP  AX, MIN_SPEED
    JB   NewSpdError                ;if too small, set error
    
    MOV  ser_error, FALSE           ;in range, clear error flag
	CALL SetMotorSpeed				;update motor speed without changing direction
    
    CALL InitParser                 ;done command, reset variables
    JMP  DoneNewSpd                 ;don't set error flag
    
NoNewSpdArg:
    MOV  ser_error, NO_ARGUMENT     ;did not have argument
    JMP  DoneNewSpd
    
NewSpdError:
    MOV  ser_error, OUT_OF_RANGE    ;argument out of range
    
DoneNewSpd:	
	POP  BX							;restore registers
	POP  AX
	RET
	
NewSpeed		ENDP



;
;AddSpeed
;
;Description:			This function takes the value in the shared variable for setting
;						change and adds that value to the current speed of the robot.
;						Note that the value could be negative, so adding effectively
;						subtracts from the current speed.
; 
;Operation:             This function first gets the current motor speed, so we know what
;						to add to.  It then adds to the current motor speed (now in a
;						register) the value by which we are changing it.  It then checks
;                       to make sure the new speed is within the range of valid speeds
;                       for the motors.  If its not, it sets an error flag.  Then it calls
;						SetMotorSpeed with this new speed and the angle value that
;						indicates not to change direction of motion, assuming no error.
;                       Then, it calls a function to reset all variables, as AddSpeed
;                       is only called at the end of a command.
; 
;Arguments:				None.
; 
;Return Values:         None.
; 
;Global Variables:      None.
; 
;Shared Variables:      setting_chg (READ) - value which we change setting to/by
;
;                       ser_error (WRITE) - TRUE if error encountered, FALSE otherwise
;
;                       have_argument (READ) - TRUE if we have argument, FALSE otherwise
; 
;Local Variables:       None.
; 
;Inputs:                None.
; 
;Outputs:               None.
;
;Registers Changed:		None.
; 
;Error Handling:        If this function is called without an argument (i.e. we got the
;                       character for this particular command, but no value to change to),
;                       the error flag is set.
; 
;Algorithms:            None.
; 
;Data Structures:       None.
; 
;Limitations:           None.
; 
;Known Bugs:            None.
; 
;Special Notes:         None.
; 	

AddSpeed		PROC	NEAR
				PUBLIC	AddSpeed
				
	PUSH AX							;store registers
	PUSH BX
    
    CMP  have_argument, TRUE        ;check to see if we have an argument for motor
    JNE  NoAddSpdArg                ;if not, we can't write to motors
    
	CALL GetMotorSpeed				;changing relative speed, need old speed
    CMP  update_sign, INIT_SIGN     ;we check overflow if subtracting and carry if adding
    JE   AddInSpd
    JNE  SubInSpd

AddInSpd:
	ADD  AX, setting_chg			;want speed we are adding to it
    JC   AddSpdCF                   ;if carry flag, use max speed
    CMP  AX, MAX_SPEED              ;make sure we don't set it too high
    JA   AddSpdCF                   ;want to write max speed if we overflowed
    JMP  SendAddedSpd               ;if not, continue
    
SubInSpd:
    ADD  AX, setting_chg            ;want to add negative (subtract) speed
    JC   SendAddedSpd
    JS   AddSpdOF                   ;if overflow flag, use min speed
    JMP  SendAddedSpd
    
NoAddSpdArg:
    MOV  ser_error, NO_ARGUMENT     ;did not have argument
    JMP  EndAddSpd                  
    
AddSpdCF:
    MOV  AX, MAX_SPEED              ;overflow when adding, use max speed
    JMP  SendAddedSpd               ;then continue
    
AddSpdOF:
    MOV  AX, MIN_SPEED              ;underflow when subtracting, use min speed
    JMP  SendAddedSpd               ;then continue
    
SendAddedSpd:
	MOV  BX, SAME_DIRECT			;don't want to change direction of motion
    
    MOV  ser_error, FALSE           ;in range, clear error flag
	CALL SetMotorSpeed				;set motor speed without changing direction
    
    CALL InitParser                 ;done command, reset variables
    JMP  EndAddSpd                  ;don't set error

EndAddSpd:
	POP  BX							;restore registers
	POP  AX
	RET
	
AddSpeed		ENDP



;
;UpdAngle
;
;Description:			This procedure changes the direction of motion to the value
;						stored in the shared setting change variable, then sets that new
;						angle.
; 
;Operation:             This function first checks to make sure it was called with a
;						valid 16-bit signed argument.  Then, it takes that argument and
;						sets the absolute angle of motion to the input angle by calling
;						the set motor speed function.
; 
;Arguments:				None.
; 
;Return Values:         None.
; 
;Global Variables:      None.
; 
;Shared Variables:      setting_chg (READ) - value by which we want to change setting
;
;                       ser_error (WRITE) - TRUE if error encountered, FALSE otherwise
;
;                       have_argument (READ) - TRUE if we have an argument, FALSE otherwise
; 
;Local Variables:       None.
; 
;Inputs:                None.
; 
;Outputs:               None.
;
;Registers Changed:		None.
; 
;Error Handling:        If this function is called without an argument (i.e. we got the
;                       character for this particular command, but no value to change to),
;                       the error flag is set.
; 
;Algorithms:            None.
; 
;Data Structures:       None.
; 
;Limitations:           None.
; 
;Known Bugs:            None.
; 
;Special Notes:         None.
; 	

UpdAngle		PROC	NEAR
				PUBLIC	UpdAngle
				
	PUSH AX							;store registers
	PUSH BX
    
    CMP  have_argument, TRUE        ;check to see if we have an argument for motor
    JNE  NoNewAngleArg              ;if not, we can't write to motors
    
SetNewAngle:
	MOV  AX, SAME_SPEED				;don't want to change speed with this process
	MOV  BX, setting_chg			;load angle we are changing to
	CALL SetMotorSpeed				;want to set absolute angle
	JMP  EndUpdAngle

NoNewAngleArg:
	MOV  ser_error, NO_ARGUMENT     ;no argument given
    JMP  EndUpdAngle
    
EndUpdAngle:
	POP  BX							;restore registers
	POP  AX
	RET

UpdAngle		ENDP



;
;RelTurrAngle
;
;Description:			This procedure changes the turret angle by the value (positive or
;						negative) stored in the shared variable for setting change.
; 
;Operation:             This loads the value by which we are changing the turret angle
;						and then calls SetRelTurretAngle with that as its argument.  If
;                       there is an error, then it will set the error flag and return
;                       before calling SetRelTurretAngle.  If there is no error, then
;                       after changing the turret angle, the initializer is called to
;                       reset all of the variables, as RelTurrAngle is only called
;                       at the end of a command.
; 
;Arguments:				None.
; 
;Return Values:         None.
; 
;Global Variables:      None.
; 
;Shared Variables:      setting_chg (READ) - value by which we are changing setting
;
;                       have_argument (READ) - TRUE if we have an argument, FALSE otherwise
;
;                       ser_error (WRITE) - TRUE if an error encountered, FALSE otherwise
; 
;Local Variables:       None.
; 
;Inputs:                None.
; 
;Outputs:               None.
;
;Registers Changed:		None.
; 
;Error Handling:        If no numeric argument was given to this command, then an error
;                       flag is set.
; 
;Algorithms:            None.
; 
;Data Structures:       None.
; 
;Limitations:           None.
; 
;Known Bugs:            None.
; 
;Special Notes:         None.
; 	

RelTurrAngle	PROC	NEAR
				PUBLIC	RelTurrAngle
				
	PUSH AX							;store register
    
    CMP  have_argument, TRUE        ;check to see if we have an argument for motor
    JNE  RelTurrError               ;if not, we can't write to motors
	
DoRelTurrAngle:
	MOV  AX, setting_chg			;load into AX how much we want to change angle
	CALL SetRelTurretAngle			;changes turret angle by what is in AX
    
    CALL InitParser                 ;done command, reset variables
    JMP  DoneRelTurrAngle
    
RelTurrError:
    MOV  ser_error, NO_ARGUMENT     ;no argument given
    
DoneRelTurrAngle:	
	POP  AX							;restore register
	RET
	
RelTurrAngle	ENDP



;
;NewTurrAngle
;
;Description:			This function takes the value in the setting change shared variable
;						and rotates the turret to that absolute angle.
; 
;Operation:             This function loads the value in the setting change shared variable
;						then calls SetTurretAngle with that as its argument.  If there is
;                       an error, then the function returns before changing the angle.
;                       If there is no error, then after changing the angle, the initializer
;                       is called to reset all of the variables, as NewTurrAngle is only
;                       called at the end of a serial command.
; 
;Arguments:				None.
; 
;Return Values:         None.
; 
;Global Variables:      None.
; 
;Shared Variables:      setting_chg - value to which we are changing a setting
;
;                       ser_error (WRITE) - TRUE if error encountered, FALSE otherwise
;
;                       have_argument (READ) - TRUE if we have an argument, FALSE otherwise
; 
;Local Variables:       None.
; 
;Inputs:                None.
; 
;Outputs:               None.
;
;Registers Changed:		None.
; 
;Error Handling:        If this function is called without an argument (i.e. we got the
;                       character for this particular command, but no value to change to),
;                       the error flag is set.
; 
;Algorithms:            None.
; 
;Data Structures:       None.
; 
;Limitations:           None.
; 
;Known Bugs:            None.
; 
;Special Notes:         None.
; 	

NewTurrAngle	PROC	NEAR
				PUBLIC	NewTurrAngle
				
	PUSH AX							;store register
    
    CMP  have_argument, TRUE        ;check to see if we have an argument for motor
    JNE  NewTurrError               ;if not, we can't write to motors
	
DoNewTurretAngle:
	MOV  AX, setting_chg			;load into AX what new angle should be
	CALL SetTurretAngle				;set the turret angle to new angle
    
    CALL InitParser                 ;done command, reset variables
    JMP  DoneNewTurrAngle
	
NewTurrError:
    MOV  ser_error, NO_ARGUMENT     ;no argument given
    
DoneNewTurrAngle:
	POP  AX							;restore register
	RET
	
NewTurrAngle	ENDP



;
;NewElev
;
;Description:			This procedure changes the elevation of the turret to the value
;						in the shared variable for setting change.
; 
;Operation:             This first loads the value in setting_chg, which is the definite
;						value to which we are changing elevation.  It then uses that as
;						argument to call SetTurretElevation.  If there are any errors,
;                       then before changing the elevation the function returns.  If not,
;                       then after changing the elevation, the initializer is called to
;                       reset all of the variables, as NewElev is only called at the end of
;                       a serial command.
; 
;Arguments:				None.
; 
;Return Values:         None.
; 
;Global Variables:      None.
; 
;Shared Variables:      setting_chg (READ) - value to which we are changing setting
;
;                       ser_error (WRITE) - TRUE if error encountered, FALSE otherwise
;
;                       have_argument (READ) - TRUE if we have an argument, FALSE otherwise
; 
;Local Variables:       None.
; 
;Inputs:                None.
; 
;Outputs:               None.
;
;Registers Changed:		None.
; 
;Error Handling:        If this function is called without an argument (i.e. we got the
;                       character for this particular command, but no value to change to),
;                       the error flag is set.
;
;                       If the value read from the setting change variable is not within
;                       the range accepted by the function to be called, the error flag is set.
; 
;Algorithms:            None.
; 
;Data Structures:       None.
; 
;Limitations:           None.
; 
;Known Bugs:            None.
; 
;Special Notes:         None.
; 	

NewElev			PROC	NEAR
				PUBLIC	NewElev
				
	PUSH AX							;store register
    
    CMP  have_argument, TRUE        ;check to see if we have an argument for motor
    JNE  NoNewElevArg               ;if not, we can't write to motors
	
GetNewElev:
	MOV  AX, setting_chg			;load into AX what new elevation should be
    
    CMP  AX, MAX_ELEV               ;check to make sure new elevation is in valid range
    JG   NewElevError               ;if too high, set error
    CMP  AX, MIN_ELEV
    JL   NewElevError               ;if too low, set error
    
    MOV  ser_error, FALSE           ;in range, clear error
	CALL SetTurretElevation			;set new turret elevation
    
    CALL InitParser                 ;done command, reset variables
    JMP  DoneNewElev
    
NoNewElevArg:
    MOV  ser_error, NO_ARGUMENT     ;no argument given
    
NewElevError:
    MOV  ser_error, OUT_OF_RANGE    ;argument out of range
	
DoneNewElev:
	POP  AX							;restore register
	RET
	
NewElev			ENDP



;
;AddElev
;
;Description:			This takes the value in the setting change shared variable and
;						changes the turret elevation by that value.
; 
;Operation:             This first gets the current turret elevation.  Then, it adds to
;						that the value in setting change, yielding the new absolute
;						angle.  It uses this new angle as argument to set the turret
;						elevation.  If there are any errors, then the function returns
;                       before changing elevation.  If no errors, then after changing
;                       elevation, the initializer is called to reset all of the variables,
;                       as AddElev is only called at the end of a serial command.
; 
;Arguments:				None.
; 
;Return Values:         None.
; 
;Global Variables:      None.
; 
;Shared Variables:      setting_chg (READ) - value by which we are changing a setting
;
;                       ser_error (WRITE) - TRUE if error encountered, FALSE otherwise
;
;                       have_argument (READ) - TRUE if we have an argument, FALSE otherwise
; 
;Local Variables:       None.
; 
;Inputs:                None.
; 
;Outputs:               None.
;
;Registers Changed:		None.
; 
;Error Handling:        If this function is called without an argument (i.e. we got the
;                       character for this particular command, but no value to change to),
;                       the error flag is set.
;
;                       If the value read from the setting change variable is not within
;                       the range accepted by the function to be called, the error flag is set.
; 
;Algorithms:            None.
; 
;Data Structures:       None.
; 
;Limitations:           None.
; 
;Known Bugs:            None.
; 
;Special Notes:         None.
; 	

AddElev			PROC	NEAR
				PUBLIC	AddElev
				
	PUSH AX							;store register
    
    CMP  have_argument, TRUE        ;check to see if we have an argument for motor
    JNE  NoAddElevArg               ;if not, we can't write to motors
	
AddInElev:
	CALL GetTurretElevation			;need to know what we are adding elevation to
	ADD  AX, setting_chg			;add to angle what we want to change elevation by
    
    CMP  AX, MAX_ELEV               ;check to make sure new elevation is in valid range
    JG   AddElevError               ;if too high, set error
    CMP  AX, MIN_ELEV
    JL   AddElevError               ;if too low, set error
    
    MOV  ser_error, FALSE           ;in range, clear error
	CALL SetTurretElevation			;change turret elevation accordingly
    
    CALL InitParser                 ;done command, reset variables
    JMP  EndAddElev
    
NoAddElevArg:
    MOV  ser_error, NO_ARGUMENT     ;no argument given
    
AddElevError:
    MOV  ser_error, OUT_OF_RANGE    ;argument out of range
    
EndAddElev:
	POP  AX							;restore register
	RET
	
AddElev			ENDP



;
;UpdSetting
;
;Description:			This procedure is what is called when we read a digit from the
;						serial port (assuming a digit is expected).  It takes that digit
;						and updates setting_chg so that the current digits are one order
;						higher and the new digit is the one's digit.  It then returns
;						with the setting_chg shared variable updated.
; 
;Operation:             This loads the shared variable for setting change, which contains
;						the previous digit instructions (if none, it is in its initial
;						state).  Because the serial arguments are in decimal, it multiplies
;						this value by ten in order to have each digit one greater in 
;						order.  Then it adds the argued digit to the new higher-order
;						setting change (which is in a register at this point) and 
;						rewrites the setting change shared variable with this new value.
; 
;Arguments:				AL - digit to be added to setting update shared variable
; 
;Return Values:         None.
; 
;Global Variables:      None.
; 
;Shared Variables:      setting_chg (WRITE) - value which a setting is changed by or to
;
;                       ser_error (WRITE) - TRUE if error encountered, FALSE otherwise
;
;                       have_argument (WRITE) - TRUE if we have an argument, FALSE otherwise
; 
;Local Variables:       None.
; 
;Inputs:                None.
; 
;Outputs:               None.
;
;Registers Changed:		None.
; 
;Error Handling:        If when multiplying the previous setting or adding the new digit, an overflow
;                       occurs, an error flag is set which will eventually move the machine into
;                       its error state.
; 
;Algorithms:            None.
; 
;Data Structures:       None.
; 
;Limitations:           None.
; 
;Known Bugs:            None.
; 
;Special Notes:         None.
; 	
	
UpdSetting		PROC	NEAR
				PUBLIC	UpdSetting
				
	PUSHA
	
PrepSettingVar:
	MOV  BX, setting_chg			;updating setting_chg with new digit
    XCHG AX, BX                     ;want to remember argument and want to multiply setting_chg
	MOV	 CX, DEC_SHL				;new digit is one's, want to shift everything left (in decimal)
	IMUL CX							;multiply to shift left
    JC   SettingError               ;don't want to have setting changer more than 16 bits
	
AddSerChar:
	XCHG AX, BX						;AL now has value to add, BX has modified setting_chg
    XOR  AH, AH                     ;don't want high byte interfering
	IMUL update_sign				;either keep same or make negative
    JO   SettingError               ;overflow, need to set error
    
	ADD  AX, BX						;one's digit free, add in passed character
    JO   SettingError               ;overflow, need to set error
    
	MOV  setting_chg, AX			;write new value
    MOV  have_argument, TRUE        ;now have an argument
    JMP  DoneUpdSetting             ;don't want to set error
    
SettingError:
    MOV  ser_error, SETTING_OF      ;set error for overflow
	
DoneUpdSetting:
	POPA
	RET
	
UpdSetting		ENDP



; StateTable
;
; Description:      This is the state transition table for the state machine.
;                   Each entry consists of the next state and actions for that
;                   transition.  The rows are associated with the current
;                   state and the columns with the input type.
;
; Author:           Glen George
; Last Modified:    Feb. 26, 2003


TRANSITION_ENTRY        STRUC           ;structure used to define table
    NEXTSTATE   DB      ?               ;the next state for the transition
    ACTION1     DW      ?               ;first action for the transition
TRANSITION_ENTRY      ENDS



;
; TRANSITION macro
;
; Description:		This macro has a next state entry and a PROC label, which is the
;					action to do for the given transition.
;

%*DEFINE(TRANSITION(nxtst, act1))  (
    TRANSITION_ENTRY< %nxtst, OFFSET(%act1) >
)


StateTable	LABEL	TRANSITION_ENTRY

	;Current State = ST_INITIAL             Input Token Type
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_DIGIT
	%TRANSITION(ST_CHSPEED, NoErr)			;TOKEN_ABSSPD       (S)
	%TRANSITION(ST_UPDSPEED, NoErr)			;TOKEN_RELSPD       (V)
	%TRANSITION(ST_FIRE, NoErr)  		    ;TOKEN_FIRE         (F)
	%TRANSITION(ST_CEASEFIRE, NoErr)        ;TOKEN_CEASEFIRE    (O)
	%TRANSITION(ST_CHANGLE, NoErr)			;TOKEN_ANGLE        (D)
	%TRANSITION(ST_ROTTURR, NoErr)			;TOKEN_ROTTURR      (T)
	%TRANSITION(ST_TURRELEV, NoErr)			;TOKEN_TURRELEV     (E)
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_PLUS  
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_MINUS 
	%TRANSITION(ST_INITIAL, InitParser)		;TOKEN_EOC
    %TRANSITION(ST_INITIAL, doNOP)          ;TOKEN_NOP
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_OTHER
	
	;Current State = ST_CHSPEED				Input Token Type
	%TRANSITION(ST_GETNEWSPD, UpdSetting)	;TOKEN_DIGIT
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ABSSPD
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_RELSPD
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_FIRE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_CEASEFIRE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ANGLE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ROTTURR
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_TURRELEV
	%TRANSITION(ST_GETNEWSPD, SetSign)    	;TOKEN_PLUS
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_MINUS
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_EOC
    %TRANSITION(ST_CHSPEED, doNOP)          ;TOKEN_NOP
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_OTHER
	
	;Current State = ST_GETNEWSPD           Input Token Type
	%TRANSITION(ST_GETNEWSPD, UpdSetting)	;TOKEN_DIGIT
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ABSSPD
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_RELSPD
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_FIRE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_CEASEFIRE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ANGLE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ROTTURR
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_TURRELEV
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_PLUS
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_MINUS
	%TRANSITION(ST_INITIAL, NewSpeed)	    ;TOKEN_EOC
    %TRANSITION(ST_GETNEWSPD, doNOP)        ;TOKEN_NOP
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_OTHER
	
	;Current State = ST_UPDSPEED			Input Token Type
	%TRANSITION(ST_UPDSPD, UpdSetting)		;TOKEN_DIGIT
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ABSSPD
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_RELSPD
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_FIRE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_CEASEFIRE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ANGLE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ROTTURR
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_TURRELEV
	%TRANSITION(ST_UPDSPD, SetSign)  		;TOKEN_PLUS
	%TRANSITION(ST_UPDSPD, SetSign)  		;TOKEN_MINUS
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_EOC
    %TRANSITION(ST_UPDSPEED, doNOP)         ;TOKEN_NOP
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_OTHER
	
	;Current State = ST_UPDSPD				Input Token Type
	%TRANSITION(ST_UPDSPD, UpdSetting)		;TOKEN_DIGIT
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ABSSPD
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_RELSPD
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_FIRE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_CEASEFIRE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ANGLE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ROTTURR
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_TURRELEV
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_PLUS
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_MINUS
	%TRANSITION(ST_INITIAL, AddSpeed)	    ;TOKEN_EOC
    %TRANSITION(ST_UPDSPD, doNOP)           ;TOKEN_NOP
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_OTHER
	
	;Current State = ST_CHANGLE				Input Token Type
	%TRANSITION(ST_UPDANGLE, UpdSetting)	;TOKEN_DIGIT
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ABSSPD
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_RELSPD
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_FIRE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_CEASEFIRE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ANGLE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ROTTURR
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_TURRELEV
	%TRANSITION(ST_UPDANGLE, SetSign)	    ;TOKEN_PLUS
	%TRANSITION(ST_UPDANGLE, SetSign)	    ;TOKEN_MINUS
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_EOC
    %TRANSITION(ST_CHANGLE, doNOP)          ;TOKEN_NOP
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_OTHER
	
	;Current State = ST_UPDANGLE			Input Token Type
	%TRANSITION(ST_UPDANGLE, UpdSetting)	;TOKEN_DIGIT
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ABSSPD
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_RELSPD
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_FIRE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_CEASEFIRE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ANGLE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ROTTURR
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_TURRELEV
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_PLUS
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_MINUS
	%TRANSITION(ST_INITIAL, UpdAngle)	    ;TOKEN_EOC
    %TRANSITION(ST_UPDANGLE, doNOP)         ;TOKEN_NOP
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_OTHER
	
	;Current State = ST_ROTTURR				Input Token Type
	%TRANSITION(ST_SETTURR, UpdSetting)	    ;TOKEN_DIGIT
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ABSSPD
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_RELSPD
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_FIRE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_CEASEFIRE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ANGLE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ROTTURR
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_TURRELEV
	%TRANSITION(ST_UPDTURR, SetSign)	    ;TOKEN_PLUS
	%TRANSITION(ST_UPDTURR, SetSign)	    ;TOKEN_MINUS
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_EOC
    %TRANSITION(ST_ROTTURR, doNOP)          ;TOKEN_NOP
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_OTHER
	
	;Current State = ST_UPDTURR				Input Token Type
	%TRANSITION(ST_UPDTURR, UpdSetting)	    ;TOKEN_DIGIT
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ABSSPD
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_RELSPD
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_FIRE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_CEASEFIRE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ANGLE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ROTTURR
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_TURRELEV
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_PLUS
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_MINUS
	%TRANSITION(ST_INITIAL, RelTurrAngle)   ;TOKEN_EOC
    %TRANSITION(ST_UPDTURR, doNOP)          ;TOKEN_NOP
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_OTHER
	
	;Current State = ST_SETTURR				Input Token Type
	%TRANSITION(ST_SETTURR, UpdSetting)	    ;TOKEN_DIGIT
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ABSSPD
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_RELSPD
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_FIRE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_CEASEFIRE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ANGLE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ROTTURR
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_TURRELEV
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_PLUS
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_MINUS
	%TRANSITION(ST_INITIAL, NewTurrAngle)   ;TOKEN_EOC
    %TRANSITION(ST_SETTURR, doNOP)          ;TOKEN_NOP
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_OTHER
	
	;Current State = ST_TURRELEV			Input Token Type
	%TRANSITION(ST_SETELEV, UpdSetting)		;TOKEN_DIGIT
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ABSSPD
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_RELSPD
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_FIRE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_CEASEFIRE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ANGLE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ROTTURR
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_TURRELEV
	%TRANSITION(ST_UPDELEV, SetSign)	    ;TOKEN_PLUS
	%TRANSITION(ST_UPDELEV, SetSign)	    ;TOKEN_MINUS
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_EOC
    %TRANSITION(ST_TURRELEV, doNOP)         ;TOKEN_NOP
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_OTHER
	
	;Current State = ST_SETELEV				Input Token Type
	%TRANSITION(ST_SETELEV, UpdSetting)	    ;TOKEN_DIGIT
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ABSSPD
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_RELSPD
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_FIRE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_CEASEFIRE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ANGLE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ROTTURR
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_TURRELEV
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_PLUS
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_MINUS
	%TRANSITION(ST_INITIAL, NewElev)	    ;TOKEN_EOC
    %TRANSITION(ST_SETELEV, doNOP)          ;TOKEN_NOP
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_OTHER
	
	;Current State = ST_UPDELEV				Input Token Type
	%TRANSITION(ST_UPDELEV, UpdSetting)	    ;TOKEN_DIGIT
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ABSSPD
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_RELSPD
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_FIRE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_CEASEFIRE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ANGLE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ROTTURR
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_TURRELEV
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_PLUS
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_MINUS
	%TRANSITION(ST_INITIAL, AddElev)	    ;TOKEN_EOC
    %TRANSITION(ST_UPDELEV, doNOP)          ;TOKEN_NOP
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_OTHER
	
	;Current State = ST_ERROR				Input Token Type
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_DIGIT
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ABSSPD
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_RELSPD
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_FIRE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_CEASEFIRE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ANGLE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ROTTURR
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_TURRELEV
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_PLUS
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_MINUS
	%TRANSITION(ST_INITIAL, InitParser)		;TOKEN_EOC
    %TRANSITION(ST_ERROR, doNOP)            ;TOKEN_NOP
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_OTHER
    
	;Current State = ST_FIRE 				Input Token Type
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_DIGIT
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ABSSPD
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_RELSPD
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_FIRE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_CEASEFIRE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ANGLE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ROTTURR
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_TURRELEV
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_PLUS
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_MINUS
	%TRANSITION(ST_INITIAL, FireLaser)      ;TOKEN_EOC
    %TRANSITION(ST_FIRE, doNOP)             ;TOKEN_NOP
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_OTHER
    
	;Current State = CEASEFIRE  			Input Token Type
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_DIGIT
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ABSSPD
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_RELSPD
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_FIRE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_CEASEFIRE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ANGLE
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_ROTTURR
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_TURRELEV
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_PLUS
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_MINUS
	%TRANSITION(ST_INITIAL, CeaseLaserFire) ;TOKEN_EOC
    %TRANSITION(ST_CEASEFIRE, doNOP)        ;TOKEN_NOP
	%TRANSITION(ST_ERROR, ParseErr)			;TOKEN_OTHER





; Token Tables
;
; Description:      This creates the tables of token types and token values.
;                   Each entry corresponds to the token type and the token
;                   value for a character.  Macros are used to actually build
;                   two separate tables - TokenTypeTable for token types and
;                   TokenValueTable for token values.
;
; Author:           Glen George
;
; Revisions:    	Tim Menninger - changed tokens and values for parsing serial chars


%*DEFINE(TABLE)  (
        %TABENT(TOKEN_OTHER, 0)			;<null>
        %TABENT(TOKEN_OTHER, 1)			;SOH
        %TABENT(TOKEN_OTHER, 2)			;STX
        %TABENT(TOKEN_OTHER, 3)			;ETX
        %TABENT(TOKEN_OTHER, 4)			;EOT
        %TABENT(TOKEN_OTHER, 5)			;ENQ
        %TABENT(TOKEN_OTHER, 6)			;ACK
        %TABENT(TOKEN_OTHER, 7)			;BEL
        %TABENT(TOKEN_OTHER, 8)			;backspace
        %TABENT(TOKEN_NOP, 9)			;TAB................(ignore character)
        %TABENT(TOKEN_NOP, 10)		    ;new line...........(ignore character)
        %TABENT(TOKEN_OTHER, 11)		;vertical tab
        %TABENT(TOKEN_OTHER, 12)		;form feed
        %TABENT(TOKEN_EOC, 13)			;carriage return....(end of command)
        %TABENT(TOKEN_OTHER, 14)		;SO
        %TABENT(TOKEN_OTHER, 15)		;SI
        %TABENT(TOKEN_OTHER, 16)		;DLE
        %TABENT(TOKEN_OTHER, 17)		;DC1
        %TABENT(TOKEN_OTHER, 18)		;DC2
        %TABENT(TOKEN_OTHER, 19)		;DC3
        %TABENT(TOKEN_OTHER, 20)		;DC4
        %TABENT(TOKEN_OTHER, 21)		;NAK
        %TABENT(TOKEN_OTHER, 22)		;SYN
        %TABENT(TOKEN_OTHER, 23)		;ETB
        %TABENT(TOKEN_OTHER, 24)		;CAN
        %TABENT(TOKEN_OTHER, 25)		;EM
        %TABENT(TOKEN_OTHER, 26)		;SUB
        %TABENT(TOKEN_OTHER, 27)		;escape
        %TABENT(TOKEN_OTHER, 28)		;FS
        %TABENT(TOKEN_OTHER, 29)		;GS
        %TABENT(TOKEN_OTHER, 30)		;AS
        %TABENT(TOKEN_OTHER, 31)		;US
        %TABENT(TOKEN_NOP, ' ')		    ;space..............(ignore character)
        %TABENT(TOKEN_OTHER, '!')		;!
        %TABENT(TOKEN_OTHER, '"')		;"
        %TABENT(TOKEN_OTHER, '#')		;#
        %TABENT(TOKEN_OTHER, '$')		;$
        %TABENT(TOKEN_OTHER, 37)		;percent
        %TABENT(TOKEN_OTHER, '&')		;&
        %TABENT(TOKEN_OTHER, 39)		;'
        %TABENT(TOKEN_OTHER, 40)		;open paren
        %TABENT(TOKEN_OTHER, 41)		;close paren
        %TABENT(TOKEN_OTHER, '*')		;*
        %TABENT(TOKEN_PLUS, +1)			;+..................(positive sign)
        %TABENT(TOKEN_OTHER, 44)		;,
        %TABENT(TOKEN_MINUS, -1)		;-..................(negative sign)
        %TABENT(TOKEN_OTHER, '.')		;.
        %TABENT(TOKEN_OTHER, '/')		;/
        %TABENT(TOKEN_DIGIT, 0)			;0..................(digit)
        %TABENT(TOKEN_DIGIT, 1)			;1..................(digit)
        %TABENT(TOKEN_DIGIT, 2)			;2..................(digit)
        %TABENT(TOKEN_DIGIT, 3)			;3..................(digit)
        %TABENT(TOKEN_DIGIT, 4)			;4..................(digit)
        %TABENT(TOKEN_DIGIT, 5)			;5..................(digit)
        %TABENT(TOKEN_DIGIT, 6)			;6..................(digit)
        %TABENT(TOKEN_DIGIT, 7)			;7..................(digit)
        %TABENT(TOKEN_DIGIT, 8)			;8..................(digit)
        %TABENT(TOKEN_DIGIT, 9)			;9..................(digit)
        %TABENT(TOKEN_OTHER, ':')		;:
        %TABENT(TOKEN_OTHER, ';')		;;
        %TABENT(TOKEN_OTHER, '<')		;<
        %TABENT(TOKEN_OTHER, '=')		;=
        %TABENT(TOKEN_OTHER, '>')		;>
        %TABENT(TOKEN_OTHER, '?')		;?
        %TABENT(TOKEN_OTHER, '@')		;@
        %TABENT(TOKEN_OTHER, 'A')		;A
        %TABENT(TOKEN_OTHER, 'B')		;B
        %TABENT(TOKEN_OTHER, 'C')		;C
        %TABENT(TOKEN_ANGLE, 'D')		;D..................(set direction)
        %TABENT(TOKEN_TURRELEV, 'E')	;E..................(set turret elevation)
        %TABENT(TOKEN_FIRE, 'F')		;F..................(turn laser on)
        %TABENT(TOKEN_OTHER, 'G')		;G
        %TABENT(TOKEN_OTHER, 'H')		;H
        %TABENT(TOKEN_OTHER, 'I')		;I
        %TABENT(TOKEN_OTHER, 'J')		;J
        %TABENT(TOKEN_OTHER, 'K')		;K
        %TABENT(TOKEN_OTHER, 'L')		;L
        %TABENT(TOKEN_OTHER, 'M')		;M
        %TABENT(TOKEN_OTHER, 'N')		;N
        %TABENT(TOKEN_CEASEFIRE, 'O')	;O..................(turn laser off)
        %TABENT(TOKEN_OTHER, 'P')		;P
        %TABENT(TOKEN_OTHER, 'Q')		;Q
        %TABENT(TOKEN_OTHER, 'R')		;R
        %TABENT(TOKEN_ABSSPD, 'S')		;S..................(set absolute speed)
        %TABENT(TOKEN_ROTTURR, 'T')		;T..................(rotate turret)
        %TABENT(TOKEN_OTHER, 'U')		;U
        %TABENT(TOKEN_RELSPD, 'V')		;V..................(set relative speed)
        %TABENT(TOKEN_OTHER, 'W')		;W
        %TABENT(TOKEN_OTHER, 'X')		;X
        %TABENT(TOKEN_OTHER, 'Y')		;Y
        %TABENT(TOKEN_OTHER, 'Z')		;Z
        %TABENT(TOKEN_OTHER, '[')		;[
        %TABENT(TOKEN_OTHER, '\')		;\
        %TABENT(TOKEN_OTHER, ']')		;]
        %TABENT(TOKEN_OTHER, '^')		;^
        %TABENT(TOKEN_OTHER, '_')		;_
        %TABENT(TOKEN_OTHER, '`')		;`
        %TABENT(TOKEN_OTHER, 'a')		;a
        %TABENT(TOKEN_OTHER, 'b')		;b
        %TABENT(TOKEN_OTHER, 'c')		;c
        %TABENT(TOKEN_ANGLE, 'd')		;d..................(set direction)
        %TABENT(TOKEN_TURRELEV, 'e')	;e..................(set turret elevation)
        %TABENT(TOKEN_FIRE, 'f')		;f..................(turn laser on)
        %TABENT(TOKEN_OTHER, 'g')		;g
        %TABENT(TOKEN_OTHER, 'h')		;h
        %TABENT(TOKEN_OTHER, 'i')		;i
        %TABENT(TOKEN_OTHER, 'j')		;j
        %TABENT(TOKEN_OTHER, 'k')		;k
        %TABENT(TOKEN_OTHER, 'l')		;l
        %TABENT(TOKEN_OTHER, 'm')		;m
        %TABENT(TOKEN_OTHER, 'n')		;n
        %TABENT(TOKEN_CEASEFIRE, 'o')	;o..................(turn laser off)
        %TABENT(TOKEN_OTHER, 'p')		;p
        %TABENT(TOKEN_OTHER, 'q')		;q
        %TABENT(TOKEN_OTHER, 'r')		;r
        %TABENT(TOKEN_ABSSPD, 's')		;s..................(set absolute speed)
        %TABENT(TOKEN_ROTTURR, 't')		;t..................(rotate turret)
        %TABENT(TOKEN_OTHER, 'u')		;u
        %TABENT(TOKEN_RELSPD, 'v')		;v..................(set relative speed)
        %TABENT(TOKEN_OTHER, 'w')		;w
        %TABENT(TOKEN_OTHER, 'x')		;x
        %TABENT(TOKEN_OTHER, 'y')		;y
        %TABENT(TOKEN_OTHER, 'z')		;z
        %TABENT(TOKEN_OTHER, '{')		;{
        %TABENT(TOKEN_OTHER, '|')		;|
        %TABENT(TOKEN_OTHER, '}')		;}
        %TABENT(TOKEN_OTHER, '~')		;~
        %TABENT(TOKEN_OTHER, 127)		;rubout
)	


; token type table - uses first byte of macro table entry
%*DEFINE(TABENT(tokentype, tokenvalue))  (
        DB      %tokentype
)

TokenTypeTable	LABEL   BYTE
        %TABLE


; token value table - uses second byte of macro table entry
%*DEFINE(TABENT(tokentype, tokenvalue))  (
        DB      %tokenvalue
)

TokenValueTable	LABEL       BYTE
        %TABLE


CODE	ENDS


DATA    SEGMENT PUBLIC  'DATA'

	ser_error		DW		?       ;TRUE if error has occurred, FALSE otherwise
	setting_chg		DW		?       ;value by/to which we are changing a setting
	update_sign		DB		?       ;keeps track of sign of setting (pos or neg)
	curr_state		DB		?       ;current state in finite state machine
    have_argument   DB      ?       ;set if we have argument, false otherwise

DATA    ENDS



        END