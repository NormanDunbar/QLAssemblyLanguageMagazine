gridSize    equ 9               ; Grid is 9 by 9 usually
linefeed    equ 10              ; Linefeed character code
escKey      equ 3               ; Bit to test for ESC key
IOB.SBYT    equ 5               ; Print a byte trap code
IOW.SCUR    equ $10             ; Set cursor trap code
IOW.SINK    equ $29             ; Set ink colour
OPW.CON     equ $c6             ; Open CON channel
UT.WTEXT    equ $d0             ; Print string vector
SMS.FRJB    equ $05             ; Force remove a job
IOB.FLIN    equ $02             ; Get a line of text
IOW.CLRA    equ $20             ; CLS whole screen
IOW.CLRB    equ $22             ; CLS bottom of screen
IOW.CLRL    equ $23             ; CLS bottom of screen
IOA.OPEN    equ $01             ; Open a file
IOA.CLOS    equ $02             ; Close a file
IOB.FBYT    equ $01             ; Read one byte
SMS.HDOP    equ $11             ; Scan keyboard trap code

TIMEOUT     equ -1              ; Infinite timeout
ME          equ -1              ; Current job
BUFFERSIZE  equ 40              ; Input buffer length

WHITE       equ 7               ; White colour
GREEN       equ 4               ; Green colour
RED         equ 2               ; Red colour
BLACK       equ 0               ; Black colour

BORDCOLOUR  equ RED             ; Border colour
BORDWIDTH   equ 1               ; Border width
PAPER       equ GREEN           ; Paper colour
INK         equ BLACK           ; Text colour

CON_W       equ 160             ; Console width
CON_H       equ 180             ;    "    height
CON_X       equ 50              ;    "    X position
CON_Y       equ 50              ;    "    Y position


;--------------------------------------------------------------
; Job's require a header. This is basically boilerplate, except
; for the job name's length and the name of the job. This will
; need to be EXEC/EXEC_W/EX or EW'd to execute it.
;--------------------------------------------------------------

;    section code                ; Uncomment for QMC assembler
    data 4000                   ; Dataspace

Start
    bra.s mainCode              ; Skip over job header
    dc.l 0                      ; 4 bytes, can be any value
    dc.w $4afb                  ; Job flag, must be $4afb

jobName
    dc.w jobNameEnd-*-2         ; Length of job name
    dc.b 'Sudoku Solver'        ; Bytes of job name
jobNameEnd equ *

    ds.w 0                      ; Ensure address alignment


;--------------------------------------------------------------
; Main code starts here.
;--------------------------------------------------------------
; Initialise the board by converting numbers to ASCII, then 
; print it. They try to solve the board!
;--------------------------------------------------------------
mainCode
    bsr openScreen              ; Open a CON_ channel
    lea jobName,a1              ; Pointer to jobname text
    bsr printString             ; Print job name
    bsr menu                    ; Load, quit, demo menu
    lea board,a3                ; Start of the board
    bsr printBoard              ; Print initial board
    bsr solveBoard              ; Attempt to solve the board
    bne.s mcFailed              ; Unsolvable board

mcSucceeded
    lea messSuccess,a1          ; Succeeded
    bra.s mcPrint

mcFailed
    lea messFailed,a1           ; Failed to solve board

mcPrint
    bsr printString             ; Print message

mcWaitForENTER
    lea messEnter,a1            ; Press ENTER message
    bsr printString             ; Print it
    bsr waitForInput            ; Wait for the ENTER key

;--------------------------------------------------------------
; The job is complete, remove it from the system. No errors are
; returned to S*BASIC even with EXEC_W/EW.
;--------------------------------------------------------------
die
    move.l #0,d3                ; No errors
    moveq #SMS.FRJB,d0          ; Force Remove a job
    moveq #me,d1                ; Kill this job
    trap #1                     ; Kill this job


;--------------------------------------------------------------
; Print the board. 
;--------------------------------------------------------------
; We print a vertical separator every 3 bytes but not at the
; start or end of a row.
; We print a linefeed every 9 bytes, if we print a linefeed we
; check to see if there's a horozontal separator needed. This 
; will occur if the current index is 26 or 53.
; Expects A3 to point at the board.
; Preserves everything except D0.
;--------------------------------------------------------------
printBoard
    movem.l d1/d6/a3,-(a7)      ; Save important registers
    bsr at                      ; Cursor to 2,0
    moveq #0,d6                 ; Which byte next?

pbLoop
    move.b (a3)+,d1             ; Grab a byte
    bne.s pbNotZero             ; It's not a zero
    move.b #' '-'0',d1          ; Print a space instead

pbNotZero
    addi.b #'0',d1              ; ASCII digit    
    bsr printByte               ; Print the byte in D1

pbTryLinefeed
    move.l d6,d1                ; Copy of current byte index
    divu #9,d1                  ; Divide for linefeed
    swap d1                     ; Get remainder
    cmpi.w #8,d1                ; Remainder 8 = linefeed
    bne.s pbTryVseparator       ; No linefeed required

pbLinefeed
    move.b #linefeed,d1
    bsr printByte               ; Print the linefeed
    
pbTryHSeparator
    cmpi.w #26,d6               ; Horozontal separator needed?
    beq.s pbHSeparator          ; Yes
    cmpi.w #53,d6               ; Horozontal separator needed?
    bne.s pbLoopEnd             ; No

pbHSeparator
    lea hSeparator,a1           ; Separator string
    bsr printString             ; Print it
    bra.s pbLoopEnd             ; No vertical separator needed

pbTryVSeparator 
    move.l d6,d1                ; Another copy of index
    divu #3,d1                  ; Divide for vertical separator
    swap d1                     ; Get remainder
    cmpi.w #2,d1                ; Remainder 2 = '|' required
    bne.s pbLoopEnd             ; No vertical separator needed

pbVSeparator
    move.b #'|',d1              ; Vertical separator needed
    bsr printByte               ; Print it

pbLoopEnd
    addq.w #1,d6                ; Next index
    cmpi.w #81,d6               ; Are we done yet?
    bne.s pbLoop                ; No, keep going

pbDone
    movem.l (a7)+,d1/d6/a3      ; Restore board
    rts

;--------------------------------------------------------------
; Attempt to solve the board.
;--------------------------------------------------------------
; Basically, brute force and recurse the solution! Test if a
; cell is zero, if so, try each  umber from 1 to 9 to see if it
; could be placed there legally. If so, do so! Then recurse and
; keep going. If not, restore the zero and try the next number.
;
; We need to keep the row, column and number as 'local'
; variables. Interesting thing to do in assembly.
;
; Expects A3 to be the board pointer, and never changes it.
; Uses D5, D6 and D7 as row, column and the number being tried.
; D4 is the offset into the board for the cell being tried.
; Returns Z set if the board was solved, unset if not.
;--------------------------------------------------------------
solveBoard
    bsr scanForESC              ; Z clear = ESC pressed
    beq.s sbNoESC               ; Not pressed
    rts                         ; ESC

sbNoESC
    movem.l d4-d7,-(a7)         ; Save working registers
    moveq #0,d4                 ; Offset into board data
    moveq #0,d5                 ; Row number
  
sbRowLoop
    moveq #0,d6                 ; Column number

sbColLoop
    tst.b (a3,d4.l)             ; Is this cell zero?
    bne.s sbNextColumn          ; No, skip this column      
    moveq #1,d7                 ; Otherwise, try 1 - 9 in cell

sbNumberLoop
    bsr.s inRow                 ; Is D7 in row D5?
    beq.s sbNextNumber          ; Yes, skip
    bsr.s inColumn              ; Is D7 in column D6?
    beq.s sbNextNumber          ; Yes, skip
    bsr.s inRow                 ; Is D7 in box D5/D6?
    beq.s sbNextNumber          ; Yes, skip

sbValid
    move.b d7,(a3,d4.l)         ; Put the number in the cell
    bsr printBoard              ; Update the board
    bsr.s solveBoard            ; Try to solve this new board
    beq.s sbSolved              ; Board is solved, hooray!
    clr.b (a3,d4.l)             ; Else, reset cell to zero

sbNextNumber
    addq.b #1,d7                ; Try next number
    cmpi.b #gridSize+1,d7       ; Unless we are done
    bne.s sbNumberLoop          ; Still going, loop again

sbUnsolved
    moveq #1,D0                 ; No numbers fit here
    bra.s sbReturn              ; Bale out, failure

sbNextColumn
    addq.b #1,d4                ; Next cell offset
    addq.b #1,d6                ; Next column number
    cmpi.b #gridSize,d6         ; Done yet?
    bne.s sbColLoop             ; Loop over columns

sbNextRow
    addq.b #1,d5                ; Next row number
    cmpi.b #gridSize,d5         ; Done yet?
    bne.s sbRowLoop             ; Loop over rows
;                               ; Drop in to sbSolved.

sbSolved
    moveq #0,d0                 ; We solved the board

sbReturn
    movem.l (a7)+,d4-d7         ; Restore callers values
    rts                         ; Done this recurse anyway!


;--------------------------------------------------------------
; Is number already in a row?
;--------------------------------------------------------------
; Given an row number in D5.W, and a number in D7.B, is the 
; number in D7 already in the row?
;
; Expects A3 = board, D5 = row, D7 = a number.
; Returns Z set if the number is already there.
; Preserves all registers except D0.
;--------------------------------------------------------------
inRow
    movem.l d5/a3,-(a7)         ; Preserve board
    move.w d5,d0                ; Copy row number
    lsl.w #3,d5                 ; Multiply by 8
    add.w d0,d5                 ; D0.W = Row * 9
    adda.l d5,a3                ; A3 = First cell in row
    moveq #gridSize-1,d0        ; 9 cells to check

irCheckCell
    cmp.b (a3)+,d7              ; Number in cell already?
    dbeq d0,irCheckCell         ; Keep going

;--------------------------------------------------------------
; If found, D0.W = ??? and Z is set.
; If not found, D0.W = -1 and Z is clear
;--------------------------------------------------------------
irDone
    movem.l (a7)+,d5/a3          ; Restore board
    rts

;--------------------------------------------------------------
; Is number already in a column?
;--------------------------------------------------------------
; Given an column number in D6.W, and a number in D7.B, is the 
; number in D7 already in the column?
;
; Expects A3 = board, D6 = column, D7 = a number.
; Returns Z set if the number is already there.
; Preserves all registers except D0.
;--------------------------------------------------------------
inColumn
    movem.l d6/a3,-(a7)         ; Preserve board
    adda.w d6,a3                ; Row 0, column D6.W
    moveq #8,d0                 ; 9 cells to check

icCheckCell
    cmp.b (a3),d7               ; Number in cell already?
    beq.s icDone                ; Yes, skip rest of loop
    adda.l #gridSize,a3         ; Same cell, next row
    dbeq d0,icCheckCell         ; Keep going

;--------------------------------------------------------------
; If found, D0.W = ??? and Z is set.
; If not found, D0.W = -1 and Z is clear
;--------------------------------------------------------------
icDone
    movem.l (a7)+,d6/a3          ; Restore board
    rts

;--------------------------------------------------------------
; Is number already in a box?
;--------------------------------------------------------------
; Given a row in D5.W, a column in D6.W and a number in D7, is
; the number in D7 already in the 3 by 3 box that D5/D6 is in?
;
; Expects A3 = board, D5 = row, D6 = column, D7 = a number.
; Returns Z set if the number is already there.
; Preserves all registers except D0.
;--------------------------------------------------------------
inBox
    movem.l d5-d6/a3,-(a7)
    moveq #0,d0                 ; Needs to be long
    move.w d5,d0                ; D0.L = row number
    divu #3,d0                  ; Row / 3
    swap d0                     ; Remainder
    sub.w d0,d5                 ; Row - row % 3 = box top row

    move.w d5,d0
    lsl.w #3,d0
    add.w d5,d0
    adda.l d0,a3                ; A3 = row offset of box top

    move.w d6,d0                ; D0.L = column number
    divu #3,d0                  ; Column / 3
    swap d0                     ; Remainder
    sub.w d0,d6                 ; Box top column

    add d6,a3                   ; A3 = column offset of box top

    moveq #2,d6                 ; 3 rows to check
    
ibRowLoop
    moveq #2,d5                 ; 3 columns to check

ibColLoop
    cmp.b (a3)+,d7              ; Is cell = number?
    beq.s ibDone                ; Yes, bale out
    dbra d5,ibColLoop           ; Try again

    adda.l #6,a3                ; Offset to next row in box
    dbra d6,ibRowLoop           ; Try next column   
    
ibDone   
    movem.l (a7)+,d5-d6/a3
    rts

;--------------------------------------------------------------
; Print D1.
;--------------------------------------------------------------
; Prints the byte in D1.
;
; D1 = byte
; A0 = Channel
;
; All registers preserved except D0, D1. Z set if no errors.
;--------------------------------------------------------------
printByte
    movem.l d3/a1,-(a7)
    moveq #IOB.SBYT,d0
    moveq #timeout,d3
    trap #3
    movem.l (a7)+,d3/a1
    tst.l d0
    rts


;--------------------------------------------------------------
; At - sets the cursor position to 2,0
;--------------------------------------------------------------
; Expects channel id in A0.
; Preserves all registers except D0. Z flag set if no errors.
;--------------------------------------------------------------
at
    movem.l d1-d3/a1,-(a7)
    moveq #IOW.SCUR,d0
    clr.w d1
    moveq #2,d2
    moveq #timeout,d3
    trap #3
    movem.l (a7)+,d1-d3/a1
    tst.l d0
    rts


;--------------------------------------------------------------
; Print String pointed to by A1.
;--------------------------------------------------------------
; Expects A0 to be the channel id and A1 to point at the QDOS
; format string to be printed.
; Preserves all registers except D0. Z set if no errors.
;--------------------------------------------------------------
printString
    movem.l d1-d3/a1,-(a7)
    move.w UT.WTEXT,a2          ; Print a string of bytes
    jsr (a2)                    ; Print it
    movem.l (a7)+,d1-d3/a1      ; Z unaffected
    rts

;--------------------------------------------------------------
; Open a CON_ channel.
;--------------------------------------------------------------
; This returns A0 as the channel ID.
; We don't care about the other registers at this point!
;--------------------------------------------------------------
conDefine
    dc.b BORDCOLOUR             ; Border colour
    dc.b BORDWIDTH              ; And width
    dc.b PAPER                  ; Paper/strip colour
    dc.b INK                    ; Ink colour
    dc.w CON_W                  ; Width
    dc.w CON_H                  ; Height
    dc.w CON_X                  ; X pos
    dc.w CON_Y                  ; Y pos

openScreen
    lea conDefine,a1            ; Parameters
    move.w OPW.CON,a2           ; Con_ channel required
    jsr (a2)                    ; Open Console & set colours
    rts


;--------------------------------------------------------------
; Menu - offer the user some simple choices.
;--------------------------------------------------------------
; The choices are:
;
; ENTER: run the demo.
; L: Load a file and solve it.
; Q: Quit.
;
; Expects A0 to contain the console channel ID.
; Doesn't really care about registers as we are at the start of
; the program and nothing, except A0, is important.
;--------------------------------------------------------------
menu
    bsr.s at                    ; At 2,0
    bsr.s clsScrBottom          ; Clear screen bottom
    lea messMenu,a1             ; Menu options
    bsr.s printString           ; Display menu
    bsr waitForInput            ; Get option
    move.b 2(a1),d2             ; Grab the first character
    bset #5,d2                  ; Lowercase it

mnuDemo
    cmpi.w #1,d1                ; ENTER?
    beq.s mnuEnd                ; Yes, run demo

mnuQuit
    cmpi.b #'q',d2              ; Quit?
    beq die                     ; Bye bye

mnuLoad
    cmpi.b #'l',d2              ; Load?
    bne.s menu                  ; Invalid option
    bsr loadGame                ; Load a Sudoku to solve
    beq.s mnuEnd                ; Load was ok
    lea messBadLoad,a1          ; Load failed
    bsr.s printString           ; Tell the user
    
mnuEnd
    bsr.s at                    ; At 2,0 again
    bsr.s clsScrBottom          ; CLS
    rts                         ; Finished


;--------------------------------------------------------------
; CLS Bottom- Clear the screen below the cursor and the cursor
; line.
;--------------------------------------------------------------
; Expects A0 to be the channel ID.
; Preserves A0 and D3, corrupts D0,D1,A1.
;--------------------------------------------------------------
clsScrBottom
    moveq #IOW.CLRL,d0          ; CLS cursor line
    bsr.s clsDoClear            ; Do it
    moveq #IOW.CLRB,d0          ; CLS window bottom

clsDoClear
    moveq #timeout,d3           ; Infinite timeout
    trap #3                     ; Do it
    rts                         ; Ignore errors

;--------------------------------------------------------------
; Load a puzle to solve.
;--------------------------------------------------------------
; Loads a file containing ASCII data for a game. Converts all
; digits into binary values in the board area, converts all 
; other characters into zeros, for spaces. User can use any 
; character they like to imply a blank in the grid.
;
; Expects A0 to contain the console channel for messages etc.
; Preserves everything except D0 which will be zero if load ok,
; else non-zero. Z is set on a successful load.
;--------------------------------------------------------------
loadGame
    bsr at                      ; At 2,0
    bsr.s clsScrBottom          ; Clear cursorline and bottom
    lea messLoad,a1             ; Filename prompt
    bsr printString             ; Prompt user
    bsr.s waitForInput          ; Get a filename
    cmpi.w #1,d1                ; ENTER only?
    beq.s loadGame              ; Yes, try again

lgOpenFile
    moveq #IOA.OPEN,d0          ; Open file
    moveq #me,d1                ; This job owns it
    moveq #1,d3                 ; Must exist, OPEN_IN
    move.l a0,a4                ; Save console id
    move.l a1,a0                ; Pointer to filename
    trap #2                     ; Open file
    tst.l d0                    ; Ok?
    beq.s lgReadFile            ; Yes, read the file.
    move.l a4,a0                ; Get the console ID
    lea messOops,a1             ; File open error
    bsr printString             ; Print it
    bra.s loadGame              ; No, try again

lgReadFile
    moveq #timeout,d3           ; Guess!
    lea board,a3                ; Where the board is
    moveq #81-1,d4              ; 81 bytes to load

lgReadLoop
    moveq #IOB.FBYT,d0          ; Fetch one byte
    trap #3                     ; Do it
    tst.l d0                    ; Ok?
    bne die                     ; No, Give up, bale out
    cmpi.b #linefeed,d1         ; Linefeeds are ignored
    beq.s lgReadLoop            ; Read again, count untouched

lgDigits
    cmpi.b #'0',d1              ; Digit?
    bcs.s lgNonDigit            ; No, treat as space
    cmpi.b #'9',d1              ; Digit?
    bhi.s lgNonDigit            ; Still no, treat as space
    subi.b #'0',d1              ; Convert from ASCII
    bra.s lgStoreByte           ; Store in board

lgNonDigit
    moveq #0,d1                 ; Non digits are zeros

lgStoreByte
    move.b d1,(a3)+             ; Save in board
    dbra d4,lgReadLoop          ; Do the rest

lgCloseFile
    moveq #IOA.CLOS,d0          ; Close file
    trap #2                     ; Do it, no errors in SMSQ/E
    moveq #0,d0                 ; No errors - QDOS either
    move.l a4,a0                ; Restore console ID
    rts


;--------------------------------------------------------------
; Get input from the console.
;--------------------------------------------------------------
; Gets user input from the console. The buffer is big enough for
; a filename.
;
; Expects A0 to be the channel id.
; Returns A1 at the start of the buffer.
; Doesn't care about registers, we are done!
;--------------------------------------------------------------
waitForInput
    moveq #IOB.FLIN,d0          ; Fetch input with Linefeed
    move.w #BUFFERSIZE,d2       ; How big is my buffer?
    lea inputBuffer,a1          ; Input buffer space
    move.l a1,a4                ; Save buffer
    addq.l #2,a1                ; Skip where the length word is
    trap #3                     ; Fetch input D1.W = size
    tst.l d0                    ; Any errors?
    bne.s waitForInput          ; Yes, just try again
    move.w d1,(a4)              ; Save the string length
    subq.w #1,(a4)              ; Lose the linefeed
    move.l a4,a1                ; Buffer start
    rts

inputBuffer ds.b BUFFERSIZE+2   ; Input buffer
    ds.w 0                      ; Alignment


;--------------------------------------------------------------
; Scan for ESC
;--------------------------------------------------------------
; Scans the keyboard for the ESC key being pressed. If so, it
; will abort this run.
; Preserves everything. Returns Z unset if ESC
; pressed.
;--------------------------------------------------------------
scanForESC
    movem.l d0-d1/d5/d7/a3,-(a7) ; Save corrupted registers
    moveq #SMS.HDOP,d0          ; Do hardware op
    lea ipcCommand,a3           ; Command to execute
    trap #1                     ; Scan keyboard, no errors
    btst #escKey,d1             ; ESC bit will be 0 now
    movem.l (a7)+,d0-d1/d5/d7/a3 ; Restore corrupted registers
    rts


;--------------------------------------------------------------
; The Sudoku board.
;--------------------------------------------------------------
; The board is 81 bytes of numbers between 0 and 9 inclusive to
; match the Sudoku game board. Zeros represent a blank space.
;--------------------------------------------------------------
board
    dc.b 9,0,0,5,3,1,0,0,0      ; Index  0 to  8
    dc.b 0,0,0,0,4,9,3,8,0      ; Index  9 to 17
    dc.b 0,0,1,8,0,7,4,0,0      ; Index 18 to 26, H-Sep here
    dc.b 7,0,4,2,0,0,0,0,6      ; Index 27 to 35
    dc.b 0,0,3,0,9,0,0,0,7      ; Index 36 to 44
    dc.b 0,6,9,0,0,3,0,0,0      ; Index 45 to 53, H-Sep here
    dc.b 0,0,7,0,0,0,0,0,0      ; Index 54 to 62
    dc.b 0,9,2,0,0,0,0,7,0      ; Index 63 to 71
    dc.b 5,1,0,0,0,4,0,0,8      ; Index 72 to 80

    ds.w 0


;--------------------------------------------------------------
; Horozontal Separator.
;--------------------------------------------------------------
; This is only printed after a linefeed and when the current 
; index into the board is either 26 or 53.
;--------------------------------------------------------------
hSeparator
    dc.w hSepEnd-*-2
    dc.b '---+---+---',linefeed
hSepEnd equ *
    ds.w 0


;--------------------------------------------------------------
; Messages displayed during 'game'.
;--------------------------------------------------------------
messMenu
    dc.w mMenuEnd-*-2
    dc.b 'ENTER: Load demo',linefeed
    dc.b 'L: Load game',linefeed
    dc.b 'Q: Quit.',linefeed,linefeed
    dc.b 'Please choose:'   
mMenuEnd equ *
    ds.w 0


messBadLoad
    dc.w mBadLoadEnd-*-2
    dc.b 'Failed to load puzzle.'
mBadLoadEnd equ *
    ds.w 0


messSuccess
    dc.w mSucEnd-*-2
    dc.b linefeed,'Solved.',linefeed,linefeed
mSucEnd equ *
    ds.w 0


messFailed
    dc.w mFailEnd-*-2
    dc.b linefeed,'Unsolvable!!',linefeed
mFailEnd equ *
    ds.w 0


messLoad
    dc.w mLoadEnd-*-2
    dc.b 'File name',linefeed
mLoadEnd


messEnter
    dc.w mEnterEnd-*-2
    dc.b 'Press ENTER to quit:'
mEnterEnd equ *
    ds.w 0


messOops
    dc.w messOopsEnd-*-2
    dc.b 'Oops. File open failed.'
messOopsEnd equ *
    ds.w 0


;--------------------------------------------------------------
; Check ESC key pressed IPC command string.
;--------------------------------------------------------------
ipcCommand
           dc.b    9,1,0,0,0,0,1,2


;    end                         ; Uncomment for QMC assembler

