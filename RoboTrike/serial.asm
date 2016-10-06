    NAME    SERIAL
    
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                                        ;
;                                        SERIAL.ASM                                      ;
;                          Contains code for serial communication                        ;
;                                       Tim Menninger                                    ;
;                                                                                        ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Description:      This code handles all of the processes for serial communication.  This
;                   includes writing characters to the serial port, reading data from the
;                   serial port and handling it and initializing the serial port.
;
; Contents:			SerialPutChar - takes a character and enqueues it in the serial channel
;                   queue
;
;					SerialInit - initializes constants and variables for use with serial
;                   communication
;
;                   SerialEventHandler - called when serial interrupts occur.  this handles
;                   interrupts from serial errors, data ready, send data and modem interrupts
;
; Input:            Serial port - this code reads from the serial port and responds to the
;                   data accordingly
;
; Output:           Serial port - part of this code deals with writing serial data to the
;                   serial port
;
; User Interface:   None.
;
; Error Handling:   None.
;
; Algorithms:       None.
;
; Data Structures:  queues - used as a buffer for serial channel outputs
;
; Revision History:
;	 11/29/14       Tim Menninger	created
;
    
    
$INCLUDE(serial.inc)        ;includes constants and addresses for serial communication
$INCLUDE(queues.inc)        ;includes the queue struct
$INCLUDE(boolean.inc)       ;includes boolean constants
$INCLUDE(intrpts.inc)      ;includes INT2 interrupt information

    
CGROUP  GROUP   CODE
DGROUP	GROUP	DATA


CODE	SEGMENT PUBLIC 'CODE'


        ASSUME  CS:CGROUP, DS:DGROUP
        
        EXTRN   QueueFull:NEAR      ;checks if queue is full
        EXTRN   EnqueueEvent:NEAR   ;enqueues event code
        EXTRN   QueueInit:NEAR      ;initializes queue
        EXTRN   Dequeue:NEAR        ;dequeues from queue
        EXTRN   Enqueue:NEAR        ;enqueues to queue
        EXTRN   QueueEmpty:NEAR     ;checks if queue is empty
        
;
;SerialPutChar
;
;Description:		Takes a character as an argument and enqueues it in the serial channel
;                   buffer, assuming there is room in the queue that makes the buffer.
;                   If there is no room, the carry flag is set, otherwise, the carry flag
;                   is reset.  It then sets a bit that causes an automatic interrupt in
;                   order to "kickstart" the system.
;
;Operation:			This first loads the serial channel queue/buffer that we are working
;                   with.  Then, it checks whether or not it is full.  If the queue is
;                   full, then the carry flag is set and the character is not enqueued
;                   (because the queue is full!).  The function returns.  If the queue is
;                   not full, then the carry flag is reset and the character is enqueued
;                   into the serial channel queue/buffer.  After enqueuing, the function
;                   checks whether or not the system needs to be "kickstarted".  If not,
;                   it returns.  If it does, then it sets a bit that will, when interrupts
;                   are enabled, force an interrupt.  It does this by turning off the
;                   THRE interrupt enable bit in IER, then setting the THRE interrupt bit
;                   in LSR, then reenabling the THRE interrupts.  It then records this
;                   was done by writing our shared variable for needing a kickstart false.
;                   The value of the carry flag is returned.
;
;Arguments:			AL - character to be enqueued
;
;Return Values:		CF - set if the queue is/was full and the character was not enqueued
;                        reset if the queue was not full and the character was enqueued
;
;Global Variables:	None.
;
;Shared Variables:	serial_channel (WRITE) - queue buffer for serial characters
;
;Local Variables:	CF - set if queue full and enqueue fails, reset if enqueue successful
;
;Registers Changed:	Flags - carry flag is a return value
;
;Inputs:			Serial port - reads from LSR so as to only change desired bit
;
;Outputs:			Serial port - writes to IER and LSR
;
;Error Handling:	None.
;
;Algorithms:		None.
;
;Data Structures:	queue - used as buffer for serial data output
;
;Limitations:		None.
;
;Known Bugs:		None.
;
;Special Notes:		None.    
        
SerialPutChar   PROC    NEAR
                PUBLIC  SerialPutChar
                
    PUSHA                   ;store registers        
                            
CheckQueue:
	LEA  SI, serial_channel	;want to perform queue routine on serial channel queue
    CALL QueueFull          ;only want to enqueue char if the queue is full
    JZ   SetCarryFlag       ;if it is full, set the carry flag and move on
    CALL Enqueue            ;if not, enqueue the character into serial channel queue
    JMP  KickStart          ;and coerce our lazy computer to do an interrupt
                            
SetCarryFlag:
    STC                     ;queue was full, set carry flag
    JMP  Kicked				;no need to kickstart here
    
KickStart:
    MOV  DX, SERIAL_IER     ;need to alter interrupt enable register to force interrupt
    MOV  AL, SET_KICKSTART  ;make sure THRE interrupt bit starts as off
    OUT  DX, AL             ;output with THRE interrupt off
    
    OR   AL, RESTORE_IER    ;then turn THRE interrupt bit back on
    OUT  DX, AL             ;output with THRE interrupt on, thereby causing interrupt
    
    MOV  need_kick, FALSE	;no longer need kickstart (obviously)
    CLC                     ;only kickstarting if successful, so clear CF
    
Kicked:
    POPA                    ;recall registers
    RET
    
SerialPutChar   ENDP



;
;SerialInit
;
;Description:		This function initializes all the variables and constants related to
;                   the serial port.  This includes the LCR, writing to it the parity,
;                   stop bits and DLAB value.  It also sets the divisor latch according
;                   to the baud divisor value, it initializes the queue used as a serial
;                   channel buffer and initializes our boolean variable for necessity of
;                   a "kickstart".
;
;Operation:			This function takes as argument an 8-bit number corresponding to the
;                   parity bits.  It then ORs in the rest of the initial values, including
;                   initial DLAB value, serial word length and number of stop bits.  It
;                   then writes this value to the LCR on the serial port.  Then, it takes
;                   the argued baud divisor (16 bits) and writes the low byte to the DLL
;                   register (DLAB was set from the initial LCR value).  Next, DLAB is
;                   cleared in the LCR so the high byte of the divisor can be written to
;                   the DLM register.  After the registers are initialized, the queues
;                   are initialized to have byte-sized elements and maximum element number
;                   is defined.  Finally, the boolean value for kickstart necessity is
;                   set to TRUE to show that we need a kickstart.
;
;Arguments:			AL - 8-bit number for parity        --x-----    stick parity
;                                                       ---x----    even parity select
;                                                       ----x---    parity enable
;                   
;                   BX - 16-bit number for baud divisor
;
;Return Values:		None.
;
;Global Variables:	None.
;
;Shared Variables:	serial_channel (WRITE) - queue/buffer for serial characters,
;					initialized in EXTRN function call to QueueInit
;
;Local Variables:	None.
;
;Registers Changed:	None.
;
;Inputs:			Serial port - LCR value read so we can write to DLAB without changing
;						other bits
;
;Outputs:			Serial port - LCR initalized with parity, word size and stop bits
;                                 DLAB bit changed within LCR
;                                 DLL gets low byte of divisor
;                                 DLM gets high byte of divisor
;
;Error Handling:	None.
;
;Algorithms:		None.
;
;Data Structures:	queue - used as buffer for serial data output
;
;Limitations:		None.
;
;Known Bugs:		None.
;
;Special Notes:		None. 

;AX has parity BX has baud rate divisor
SerialInit      PROC    NEAR
                PUBLIC  SerialInit
         
    PUSHA                   ;store registers
    
DisableInterrupts:
    MOV  DX, SERIAL_IER     ;load address of IER to disable interrupts
    MOV  AL, DISABLE_INT    ;want to disable interrupts
    OUT  DX, AL             ;write no interrupt constant to IER
         
InitializeLCR:
    MOV  DX, SERIAL_LCR     ;get address of line control register (LCR)
    OR   AL, INIT_LCR       ;AL has initial parity bits as input.  OR with other
                            ;   initial values to get total initial LCR value
    OUT  DX, AL             ;write initial value of LCR to LCR
                
SetDivisorLatch:
    MOV  DX, SERIAL_DLL     ;get address of low byte of baud divisor latch (DLL)
    MOV  AL, BL             ;BX contains baud divisor argument, need low byte
    OUT  DX, AL             ;write low byte of baud divisor to DLL
    
    MOV  DX, SERIAL_DLM     ;get address of high byte of baud divisor latch (DLM)
    MOV  AL, BH             ;put high byte of baud divisor into AL for OUT instruction
    OUT  DX, AL             ;write high byte of divisor to DLM
    
    MOV  DX, SERIAL_LCR     ;get address LCR so we can clear divisor latch access bit (DLAB)
    IN   AL, DX             ;store current LCR so we can remember other non-DLAB bit values
    AND  AL, CLEAR_DLAB     ;clear the DLAB bit
    OUT  DX, AL             ;write new LCR value to LCR
                
InitializeQueue:
    MOV  AX, SERIAL_QLEN    ;QueueInit needs length of queue in AX
    MOV  BX, BYTE_QUEUE     ;have elements in serial channel buffer be bytes
    LEA  SI, serial_channel	;QueueInit expects queue memory location in SI
    CALL QueueInit          ;inititalize queues
    
InitializeKickstart:
	MOV  need_kick, TRUE    ;want to kickstart first chance we get
    
InitializeInterrupts:
    MOV  DX, SERIAL_IER     ;load address of interrupt enable register
    MOV  AX, RESTORE_IER    ;get value of all interrupts enabled
    OUT  DX, AX             ;write to enable interrupts
    
EndSerialInit:
    POPA                    ;restore registers
    RET
    
SerialInit      ENDP
    
    
;
;SerialEventHandler
;
;Description:		This function is called when there is an interrupt as a result of
;                   serial communication.  When called, it assesses why the interrupt
;                   occurred then responds accordingly.  It could respond by sending
;                   serial data, simply reading to reset the modem interrupt, handling
;                   an error or receiving data and handling that accordingly.
;
;Operation:			This function starts by reading the byte at the interrupt identity
;                   register, which will reveal why the event handler was called.  It
;                   masks out all of the identity bits to single out the interrupt pending
;                   bit, then compares with the interrupt pending value to see if there
;                   are pending interrupts remaining.  If not, it ends the process.
;
;                   If there are pending interrupts, then it takes the value read from IIR
;                   (copied into another register), and shifts out the interrupt pending
;                   bit.  The resultant value is then the offset for a jump table.  We then
;                   jump to the label corresponding to the interrupt identity.
;
;                   SendSerialData:
;                   If the IIR indicates to send serial data, it jumps to SendSerialData.
;                   Here, the value in the LCR is read, so we don't overwrite what was
;                   there, and we set the DLAB bit and write back to LCR.  This allows us
;                   to write to the THR.  Therefore, we dequeue from the serial channel
;                   queue/buffer and write that byte to THR.  It then jumps to the beginning
;                   of the function to check if there are other interrupts pending.
;
;                   SerialModem:
;                   If IIR has a modem interrupt, this is executed.  It merely reads from
;                   the MSR to clear the interrupt and then jumps to the beginning of the
;                   function to check if there are other interrupts pending.
;
;                   SerialError:
;                   This label is jumped to if IIR indicates there is an error.  In this
;                   case, the error code is stored in LSR, so we first read the byte from
;                   the LSR.  Because LSR is not exclusively errors, we mask out the bits
;                   not corresponding to errors.  Then, we check if this corresponds to
;                   no errors.  If so, we go back to the beginning to check for other
;                   pending interrupts.  If there is an error, then we find the event code
;                   that correctly responds to that error and enqueue that to our event
;                   queue before jumping to the beginning of SerialError to check for other
;                   errors.
;
;                   ReceiveSerialData:
;                   This label is jumped to when there is data to be read/received.  It
;                   first reads from LCR, clears the DLAB bit then writes back to the LCR.
;                   This allows us to read from the RBR.  We then read from the RBR and
;                   translate that value into the appropriate event code.  Now that we have
;                   the event code for the serial data, we enqueue the event code in our
;                   event queue.  Then we jump to the beginning of the function to see
;                   if there are more pending interrupts.
;
;                   If there are no more pending interrupts, then we restore the registers
;                   and return from the interrupt code.
;
;Arguments:			None.
;
;Return Values:		None.
;
;Global Variables:	None.
;
;Shared Variables:	serial_channel (WRITE) - queue/buffer for characters to be sent to the serial port
;
;Local Variables:	None.
;
;Registers Changed:	None.
;
;Inputs:			Serial port - reads from the IIR and responds accordingly
;                                 reads from LCR to set/clear DLAB bit without changing other bits
;                                 reads from LSR to determine what errors (if any)
;                                 reads from the MSR to clear modem interrupt
;
;Outputs:			Serial port - writes to the LCR to set/clear DLAB bit
;                                 writes to the THR serial data from serial channel queue/buffer
;
;Error Handling:	None.
;
;Algorithms:		None.
;
;Data Structures:	queue - used as buffer for serial data output
;
;Limitations:		None.
;
;Known Bugs:		None.
;
;Special Notes:		None. 
    
    
SerialEventHandler    PROC    NEAR
                      PUBLIC  SerialEventHandler
                
    PUSHA                   ;store registers
                
SerialInterrupts:
    MOV  DX, SERIAL_IIR     ;get address of interrupt identity register (IIR)
    IN   AL, DX             ;read value of IIR, which contains interrupt identities
    
    XOR  AH, AH             ;clear high byte so we can use as an index
    MOV  DI, AX             ;otherwise, want to call appropriate function
    AND  AL, NO_INTERRUPTS  ;mask out all bits not corresponding to pending interrupts
    CMP  AL, NO_INTERRUPTS  ;check if there are no interrupts
    JE   DoneSerialInts     ;if not, end process
    
    LEA  SI, serial_channel ;will be working with serial channel in queue routines
    
    JMP  CS:SerialFunctions[DI];jump to function corresponding to interrupt identity
    
SerialModem:                ;executed when modem interrupt occurs
    MOV  DX, SERIAL_MSR     ;get address of modem status register (MSR)
    IN   AL, DX             ;read MSR to clear interrupt
    
    JMP  DoneSerialInts  
    
SendSerialData:             ;executed when there is data to send    
    CALL QueueEmpty         ;check if the queue is empty
    JZ   DoneSerialInts     ;if so, don't dequeue value. carry on
    
    CALL Dequeue            ;otherwise, dequeue value into AL
    MOV  DX, SERIAL_THR     ;get transmitter holding register (THR)
    OUT  DX, AL             ;send new THR value
    
    MOV  need_kick, TRUE    ;just dequeued, want to kickstart to handle that
    JMP  DoneSerialInts  
    
ReceiveSerialData:          ;executed when there is data to be read
    MOV  DX, SERIAL_LCR     ;get address of LCR to clear DLAB
    IN   AL, DX             ;read LCR value so we remember other bit values
    AND  AL, CLEAR_DLAB     ;clear DLAB bit on LCR value
    OUT  DX, AL             ;rewrite LCR
    
    MOV  DX, SERIAL_RBR     ;get address of receiver buffer register (RBR)
    IN   AL, DX             ;read from RBR

    XOR  AH, AH             ;want high byte, which has error code, to be 0
    
    CALL EnqueueEvent       ;enqueue the event
    
    JMP  DoneSerialInts  
    
SerialError:                ;executed when error occurs
    MOV  DX, SERIAL_LSR     ;get address of LSR to check for errors
    IN   AL, DX             ;read value at LSR
    AND  AL, NONERROR_MASK  ;mask bits that don't correspond to an error
    
    CMP  AL, NO_ERRORS      ;check if masked LSR value has an error
    JE   DoneSerialInts     ;if not, done checking, check for more interrupts
    
    MOV  AH, AL             ;want error code in high byte (0 if no error)
    
    CALL EnqueueEvent       ;now that we have event, enqueue it
    JMP  SerialError        ;repeat loop until no more errors
    
DoneSerialInts:
    MOV     DX, INTCtrlrEOI  ;EOI control register address
    MOV     AX, INT2EOI		 ;INT2 end of interrupt value
    OUT     DX, AL			 ;write end of interrupt
    
    POPA                     ;restore registers
    IRET
    
SerialEventHandler    ENDP


;Table containing labels to jump to, indexed by interrupt identity
SerialFunctions LABEL   WORD
                PUBLIC  SerialFunctions
                             
;   DW      Function Name               ;Description/notes
    DW      OFFSET(SerialModem)         ;handles serial modem interrupt
    DW      OFFSET(SendSerialData)      ;sends data from queue to serial port
    DW      OFFSET(ReceiveSerialData)   ;enqueues event for incoming data
    DW      OFFSET(SerialError)         ;handles serial errors
                
CODE    ENDS


;the data segment

DATA    SEGMENT PUBLIC  'DATA'

	serial_channel	QUEUE 	<>			;queue buffer for serial events
	need_kick		DB		?			;keeps track of whether kickstart is required

DATA    ENDS


    END