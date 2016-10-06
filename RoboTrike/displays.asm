        NAME    Displays

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                                        ;
;                                         DISPLAYS                                       ;
;                                   Conversion Functions                                 ;
;                                         EE/CS 51                                       ;
;                                                                                        ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


; 
; Description:		This contains the code for displaying strings and muxxing the display.
;
; Contents:			DisplayInit - clears the display and the segment buffer
;					Display - takes a string and puts the segments for each character
;						into a buffer for the muxxer to display
;					DisplayMux - iterates through a segment buffer to display the 
;						characters represented in it
;
; Input:            None.
;
; Output:           Display - the muxxer outputs to the display to display strings
;
; User Interface:   The display shows strings either gotten from serial or in response to
;					user input.
;
; Error Handling:   None.
;
; Algorithms:       None.
;
; Data Structures:  None.
;
;
; Revision History:
;	 11/07/14  Tim Menninger	created program
;    12/04/14  Tim Menninger    added code for scrolling
;	 12/11/14  Tim Menninger	added header
;



CGROUP  GROUP   CODE
DGROUP	GROUP	DATA


CODE	SEGMENT PUBLIC 'CODE'


        ASSUME  CS:CGROUP,	DS:DGROUP


		EXTRN	Dec2String:NEAR			;Dec2String takes numbers and converts to decimal
										;	ASCII strings.
		EXTRN	Hex2String:NEAR			;Hex2String takes numbers and converts to hex
										;	ASCII strings.
		EXTRN	ASCIISegTable:BYTE		;table containing segment patterns for ASCII
											

$INCLUDE(displays.inc)
$INCLUDE(ASCII.inc)
										

;
;DisplayInit
;
;Description:			This function will set all of the entries in the buffer to zero,
;						thereby telling the muxxing function not to display anything
;						(because 0 corresponds to no segments lit).
; 
;Operation:             This works by first loading our seg_buffer into DI.  Then it will
;						iterate through all of the indices in seg_buffer.  The number of
;						indices is equal to the size of MAX_CHARS, which is the maximum
;						number of characters allowed in a string to be displayed.  We then
;						multiply this by our SegBuffSize, which is 2 if each index is two
;						bytes and 1 if it is one byte.  Then it will iterate through using
;						a counter until the counter is equal to the number of indices, and
;						on each iteration, the seg_buffer will be set to 0 at the current
;						index.
; 
;Arguments:				None.
; 
;Return Values:         None.
; 
;Global Variables:      None.
; 
;Shared Variables:      seg_buffer (WRITE) - an array containing the segment patterns to display
;						for each respective character
;
;						Digit (WRITE) - a number that is used to keep track of which display we
;						are currently considering, initialized to zero by this function
;
;                       scrl_delay (WRITE) - the amount of time to wait before scrolling
; 
;Local Variables:       DI - initialized to 0, keeps track of what display to turn off
;						next
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


DisplayInit     PROC        NEAR
                PUBLIC      DisplayInit
				
	PUSHA					;store registers
				
PrepDisplayInit:			
    MOV  scrl_delay, SCRL_WAIT;make scroll delay amount of time before beginning scrolling
	MOV  Digit, 0			;digit is our iterator to know what LEDs we've written to
	;JMP PrepBufferClear	
	
PrepBufferClear:			
	MOV  AX, MAX_CHARS		;AX will be boundary for DI
	MOV  BX, SegBuffSize	;get size of (in bytes) each element in array
	MUL  BX					;multiply character offset by element size adjustment
	MOV  DI, 0				;initialize a counter for array

ClearBuffer:				
	CMP  DI, AX				;see if we have indexed through all characters
	JAE  DoneDispInit		;if so, we are done initialization
	MOV  seg_buffer[DI], ASCIInull;if not, want to clear next buffer element
	INC  DI					;then increment so we clear next digit
	JMP  ClearBuffer		;repeat everything
	
DoneDispInit:				;now want to clear buffer array
	POPA					;restore registers
	RET						

DisplayInit		ENDP
        
        
;
;Display
;
;Description:          	This function takes as argument a string and converts each
;						character to a segment pattern that the mux will use to display
;						the string on the LEDs.  These segment patterns are stored in
;						a buffer.
; 
;Operation:             This function operates by iterating through the string (in ES).
;						Because this uses 14-segment display, each byte in our string
;						buffer corresponds to a word in our segment buffer.  This function
;						therefore operates by taking a character from the string buffer.
;						then it will look at a table that contains information on what
;						the corresponding segment pattern is for any given character.
;						Because the table is set up such that the 0th element is ASCII 0
;						and the i-th element is ASCII i, we simply add the ASCII value
;						to the table offset.  This table is assumed to be stored in the
;						code segment.  Then, this segment pattern is loaded into the
;						segment buffer from which the muxxing function can read and write
;						to the display.  When the end of the string is reached (if there
;						are fewer characters than LEDs), denoted by the ASCII null 
;						character, then the rest of the segment buffer is filled with
;						zeroes to notify the muxxing function not to light them up.
;                       At the end, it resets the shared variable for scroll delay to
;                       the initial delay (the delay changes so that the first bit
;                       shows long enough before effectively erasing the first letter
;                       as a result of scrolling).
; 
;Arguments:             ES:SI - location in memory where the string to be displayed is
; 
;Return Values:         None.
; 
;Global Variables:      None.
; 
;Shared Variables:      seg_buffer (WRITE) - the segment patterns for each character 
;						correspond to a byte in the seg_buffer array
;
;                       scrl_delay (WRITE) - amount of time before scrolling starts/continues
; 
;Local Variables:       CX - initialized to 0, keeps track of how many characters have
;						been iterated through and make sure we don't exceed our MAX_CHARS
;
;						DI - initialized to 0, keeps track of where in segment buffer we
;						are.  this must be incremented by 2 if we use 14-segment displays
;						(which we are)
; 
;Inputs:                None.
; 
;Outputs:               Display - writes the string to 7 or 14-segment displays
;
;Registers Changed:		None.
; 
;Error Handling:        None.
; 
;Algorithms:            None.
; 
;Data Structures:       Array - our segment patterns are in arrays
; 
;Limitations:           There are some characters that have no 14-segment analogs.  They
;						will be left blank.
; 
;Known Bugs:            None.
; 
;Special Notes:         None.
;


Display         PROC        NEAR
                PUBLIC      Display
                
PrepForDisp:				;set up constants, etc
	PUSHA					;store registers
	
    MOV  scroll_offset, 0   ;original offset should be 0 (because we haven't scrolled yet)
	LEA  DI, seg_buffer		;want to write character segment patterns to a buffer
	MOV  DI, 0				;offset for seg_buffer, also counter to limit string length
	MOV  CX, 0				;counter so we know where in array we are
	;JMP GetSegValue		

GetSegValue:				;takes ASCII characters and turns them into values which
							;	correspond to which segments to light up
	MOV  AL, ES:[SI]		;AL temporary to change value
	CMP  AL, ASCIInull		;if null, the string has ended
	JE   FillRest			;if we got to end of string, make the rest of the string null
	
	MOV  AH, 0				;don't want high bits interfering
	SHL  AX, 1				;ASCIISegTable contains words, so index every two
	LEA  BX, ASCIISegTable	;seg pattern is a word, so we cannot use XLAT
	ADD  BX, AX				;had offset, now BX points to desired table value
	;JMP WriteSegValue		
	
WriteSegValue:
	MOV  AX, CS:[BX]		;extract segment pattern for particular character
	MOV  BX, AX				;duplicate it
	MOV  seg_buffer[DI], BX	;need to load seg patterns into our buffer one byte at
	
	ADD  DI, SegBuffSize	;seg_buffer has words, must increment by 2 if words
	INC  SI					;increment pointer in our string
	INC  CX					;increment counter

	CMP  CX, MAX_CHARS		;we don't want to run off into memory, so this will truncate
							;	the string to MAX_CHARS length
	JE   DoneDisplay		;if reached max chars, leave the loop
	JMP  GetSegValue		;otherwise, convert next character
	
FillRest:
	CMP  CX, MAX_CHARS		;only want to fill in as many characters as we ahve
	JAE  DoneDisplay		;if done, we're done
	MOV  seg_buffer[DI], ASCIInull;fill buffer with nothing
	ADD  DI, SegBuffSize	;want to increment DI by size of elements
	INC  CX					;increment counter so we know when we've done all characters
	JMP  FillRest			;repeat until we've done all characters

DoneDisplay:				;finished writing char segments to buffer. fill rest with spaces
    MOV  scrl_delay, SCRL_WAIT;changed string, want to reset scroll delay for muxxer
	POPA					;restore registers
	RET						

Display			ENDP


;
;DisplayNum
;
;Description:           This function takes a signed integer as input and converts it
;						to a string, then displays it.  The string it is converted to
;						is 6 characters: its sign, then 5 digits (leading zeroes if n
;						is less than 10,000).  It displays from the left.
; 
;Operation:             This function takes a signed 16-bit number, assumed to be
;						passed in AX.  It is to take this number and display it in
;						decimal.  It loads a string buffer into SI then calls Dec2String
;						which will save the string in SI.  Then, we store DS into ES
;						because Display expects the string to be in ES.  We call Display
;						which stores this number in another buffer to be sent to the
;						muxxing function.  Finally, we pop all our registers so that 
;						nothing is lost.
; 
;Arguments:             AX - 16-bit signed value to turn into a string of digits
; 
;Return Values:         None.
; 
;Global Variables:      None.
; 
;Shared Variables:      str_buffer (READ) - the buffer where we store the decimal string
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
;Data Structures:       array - used to store the string
; 
;Limitations:           This can only display numbers up to and including 16-bit signed
;						integers and does not recognize any number greater than or equal
;						to 100,000 (although it would require minimally 17 bits anyway).
; 
;Known Bugs:            None.
; 
;Special Notes:         None.
;


DisplayNum      PROC        NEAR
                PUBLIC      DisplayNum

DecNumDisp:					;want to write number to display in decimal
	PUSHA					;store registers
	LEA  SI, str_buffer		;SI could be pointing somewhere we don't want changed
	CALL Dec2String			;takes number and puts ASCII characters in buffer pointed
							;	to by SI
	MOV  AX, DS				;want to store DS into ES because that is where Display
	MOV  ES, AX				;	expects string to be
	CALL Display			;takes string in buffer pointed to by SI (in ES)

DoneDispNum:
	POPA					;restore registers
	RET
                
DisplayNum		ENDP



;
;DisplayHex
;
;Description:           This function takes an unsigned 16-bit integer and outputs it
;						in hexadecimal to the display.  It will display exactly four
;						characters 0-9, A-F.  It will start the display from the left.
;						It is assumed that the argued number is in AX.
; 
; 
;Operation:             This function takes an unsigned 16-bit number, assumed to be
;						passed in AX.  It is to take this number and display it in
;						decimal.  It loads a string buffer into SI then calls HexString
;						which will save the string in SI.  Then, we store DS into ES
;						because Display expects the string to be in ES.  We call Display
;						which stores this number in another buffer to be sent to the
;						muxxing function.  Finally, we pop all our registers so that 
;						nothing is lost.
; 
;Arguments:             AX - 16-bit unsigned value to be displayed in hex
; 
;Return Values:         None.
; 
;Global Variables:      None.
; 
;Shared Variables:      str_buffer (READ) - the buffer where we store the decimal string
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
;Data Structures:       array - used to store the string
; 
;Limitations:           This can only display numbers up to and including 16-bit signed
;						integers and does not recognize any number greater than or equal
;						to 100,000 (although it would require minimally 17 bits anyway).
; 
;Known Bugs:            None.
; 
;Special Notes:         None.
;
        
DisplayHex      PROC        NEAR
                PUBLIC      DisplayHex

HexNumDisp:					;will take number and display it in hex
	PUSHA					;store registers
	LEA  SI, str_buffer		;SI could be pointing somewhere we don't want changed
	CALL Hex2String			;takes number in AX and converts it to ASCII string in SI
	MOV  AX, DS				;Display expects string to be in ES
	MOV  ES, AX				;
	CALL Display			;will take ASCII string at SI and display it on LEDs

DoneDispHex:
	POPA					;restore registers
	RET

DisplayHex		ENDP


; DisplayMux
;
; Description:       This procedure is the muxxing procedure when the timer
;                    interrupts.  It outputs the next segment pattern to the
;                    LED display.  After going through all the segment
;                    patterns for a digit it goes on to the next digit.  After
;                    doing all the digits it starts over again.
;
; Operation:         This begins by initializing CX as the digit we are currently
;					 considering.  We then add to it the offset of the first port
;					 that contains a display.  Next, we load into DI the digit we
;					 are considering multiplied by 2 if we are using 14-segments,
;					 which we are, because the segment buffer uses words.  This now
;					 has our offset of our segment buffer and we can write to the
;					 displays.  Because the inner segments are accessed through a
;					 different port, we first write the high byte of the segment
;					 buffer to that port, then write the low byte of it to the port
;					 corresponding to the digit to be displayed.  Now, the digit
;					 should be lit with the desired character, so we can increment
;					 digit for the next time this function is called.  If we
;					 increment digit to one beyond the number of LED displays we
;					 have, we rewrite it to be 0 so we start over with the display.
;
; Arguments:         None.
;
; Return Value:      None.
;
; Local Variables:   AX - temporarily used
;					 BX - temporarily used
;					 CX - pointer to LED port
;                    DX - points to port being written to in OUT instruction
;					 DI - index for our segment buffer
;
; Shared Variables:  seg_buffer (WRITE) - buffer containing segment patterns for display
;
;					 Digit (WRITE) - which LED (counted from 0 being leftmost) we are lighting
;
;                    scrl_delay (WRITE) - amount of time to wait before scrolling
;
; Global Variables:  None.
;
; Input:             None.
;
; Output:            A segment to the display.
;
; Error Handling:    None.
;
; Algorithms:        None.
;
; Data Structures:   array - used to store our segment buffer
;
; Registers Changed: None
;


DisplayMux		PROC    NEAR
				PUBLIC	DisplayMux

        PUSHA

PrepMux:
		MOV		AX, Digit				;offset for seg_buffer, which we read from
        ADD     AX, scroll_offset       ;then add in offset due to scrolling
		MOV		BX, SegBuffSize			;want to adjust for size of array elements
		MUL		BX						;multiply by size (in bytes)
		MOV		DI, AX					;put index into register we can use for indexing
        DEC     scrl_delay              ;want to count until we have finished scrolling
        CMP     scrl_delay, START_SCROLL;see if we have waited until we want to begin scrolling
        JE      ScrollDisplay           ;if so, update buffer so we scroll
        JNE     DisplayUpdate           ;otherwise, maintain display
        
ScrollDisplay:
        MOV     scrl_delay, SCROLLING_TM;started scrolling, want it to look "continuous"
        MOV     AX, NUM_LEDS            ;first non-displayed element is after all LEDs
        MOV     BX, SegBuffSize         ;want to multiply each index by number of bytes of each element
        MUL     BX                      ;now have offset to first non-displayed element
        ADD     AX, DI                  ;want to get index of first non-displayed element
        XCHG    AX, BX                  ;need to index buffer with BX
        CMP     seg_buffer[BX], ASCIInull;check if there are non-displayed characters
        JE      DisplayUpdate           ;if no more characters, keep displaying
        INC     scroll_offset           ;otherwise, start looking one to the right

DisplayUpdate:                          ;update the display
		MOV		BX, seg_buffer[DI]		;get segment pattern
		
		MOV		AL, BH					;OUT requires value in AL, inner segs use high byte
		MOV		DX, LEDInnerSeg			;want to write bits for inner segments first
		OUT		DX, AL					;write segments to display
		
		MOV		AL, BL					;low bits correspond to specific LED
		MOV		DX, Digit				;get offset of current display digit
		ADD		DX, LEDDisplay			;offset for first display
		OUT		DX, AL					;can now write bits for outer segments
		
		INC		Digit					;done writing to current digit, increment it
		
		;JMP	NextDigit				;prepare to mux next digit

NextDigit:                              ;do the next digit
        CMP     Digit, NUM_LEDS	        ;have we done all the displays?
		JB		EndMuxxing				;if not, we're done
        ;JGE	DigitWrap				;if we did, wrap around
        
DigitWrap:                              ;if so, wrap the digit number back to 0
        MOV     Digit, 0				;go back to beginning
		;JMP	EndMuxxing				;done

EndMuxxing: 
		POPA
        RET                             ;and return (Event Handlers end with IRET not RET)


DisplayMux		ENDP
        
        
CODE    ENDS


;the data segment

DATA    SEGMENT PUBLIC  'DATA'

	Digit		DW		?	        	;current digit we are considering
    scrl_delay  DW      ?               ;amount of time before scrolling
    scroll_offset DW    ?               ;amount we have scrolled by
	
	seg_buffer	DW		(MAX_CHARS)		DUP	(?)	;will be buffer for segment patterns
	str_buffer	DB		(MAX_CHARS + 1) DUP (?)	;buffer for string when calling Dec2String
												;	and Hex2String.  +1 for NULL char

DATA    ENDS



        END