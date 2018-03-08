;--------------------------------------------------------------------
; LANGTON'S ANT - 68020 Edition
;
; A small routine to demonstrate how emergent behaviour can, ahem,
; emerge from simple rules.
;
; See Wikipedia: htps://en.wikipedia.org/wiki/Langton's_ant
;
; The ant lives in a world which is a certain size wide and deep and
; the ends wrap around. It starts off in the middle, and walks in a
; downward direction - it makes no difference though, the behaviour
; will still emerge.
;
; If the ant lands on a cell which is white, it must turn it black,
; turn right, and walk on to the next cell in that new direction.
;
; If the cell was black, the ant must turn it white, turn left, and
; walk on to the next cell in the new direction.
;
; That is all the rules. Run the program and see what happens!
;--------------------------------------------------------------------
; Norman Dunbar
; 17 February 2018.
;
; This source code is open source. Use it as you see fit and if you
; improve it, tell everyone and let them have the new source!
;--------------------------------------------------------------------


;--------------------------------------------------------------------
; The sizes must be a power of two. We need this later when we limit
; them to anything between 0 and the size minus 1. If they are not a
; power of two, it doesn't work the way I've done things later!
;--------------------------------------------------------------------
size_x
           equ     512                 ; Pixels across (width)
size_y
           equ     256                 ; Pixels down (height)

;--------------------------------------------------------------------
; Color names, better than guessing the colour values. The ESC key is
; defined here, or its bit number in D1 after an IPC call.
;--------------------------------------------------------------------
black
           equ     0                   ; Black cell colour
red
           equ     2                   ; It's a red ant!
white
           equ     7                   ; White cell colour
green
           equ     4                   ; The world colour
esc
           equ     3                   ; Bit number for ESC
;--------------------------------------------------------------------
; Standard Job start.
;--------------------------------------------------------------------
start
           bra.s   Langton
           dc.l    0
           dc.w    $4afb

name
           dc.w    nameEnd-name-2
           dc.b    "Langton's Ant"
nameEnd
           equ     *

;--------------------------------------------------------------------
; BLOCK command parameter block.
;--------------------------------------------------------------------
Block
           dc.w    1,1
xPos
           dc.w    Size_x/2,Size_y/2

;--------------------------------------------------------------------
; Check ESC key pressed IPC command string.
;--------------------------------------------------------------------
ipc_command
           dc.b    9,1,0,0,0,0,1,2

;--------------------------------------------------------------------
; Screen channel name and window definition block.
;--------------------------------------------------------------------
scr_def
           dc.w    4
           dc.b    'scr_'

winDef
           dc.w    size_x
           dc.w    size_y
           dc.w    (512-size_x)/2
           dc.w    (256-size_y)/2

;--------------------------------------------------------------------
; Subroutines to do a trap, test D0 and die horribly if there was
; an error.
;--------------------------------------------------------------------
doTrap1
           trap    #1
           bra.s   testD0

doTrap2
           trap    #2
           bra.s   testD0

doTrap3
           trap    #3

testD0
           tst.l   d0
           bne.s   suicide
           rts

suicide
           move.l  d0,d3
           moveq   #mt_frjob,d0
           moveq   #-1,d1
           trap    #1


;--------------------------------------------------------------------
; The main starting place. Open a scr_ channel. The channel ID will
; stay protected in A0.L throughout the rest of the code.
;--------------------------------------------------------------------
Langton
           lea     scr_def,a0          ; Screen channel
           moveq   #io_open,d0
           moveq   #-1,d1
           moveq   #0,d3
           bsr.s   doTrap2

;--------------------------------------------------------------------
; The screen channel is open, make the window the requested size.
;--------------------------------------------------------------------
Window
           moveq   #sd_wdef,d0         ; Window definition
           moveq   #0,d1
           moveq   #0,d2
           moveq   #-1,d3
           lea     winDef,a1
           bsr.s   doTrap3

;--------------------------------------------------------------------
; Set the paper to green.
;--------------------------------------------------------------------
Paper
           moveq   #sd_setpa,d0        ; Set paper to green
           moveq   #green,d1
           bsr.s   doTrap3

;--------------------------------------------------------------------
; And clear the entire screen.
;--------------------------------------------------------------------
Cls
           moveq   #sd_clear,d0        ; Cls
           bsr.s   doTrap3

;--------------------------------------------------------------------
; The cells bitmap defines the ant's world. A bit is clear for white
; or set for black. Initially, all cells are white. It makes no
; difference - try setting the cells to FF (all black) and you'll see
; the same results.
;--------------------------------------------------------------------
clearCells
           lea     cells,a3            ; The ant's world lives here
           move.l  a3,a2               ; Use A2 for the loop
           moveq   #0,d0               ; Byte counter
           move.w  winDef(pc),d0       ; Get width in pixels
           lsr.w   #3,d0               ; Calculate width in bytes
           mulu    winDef+2(pc),d0     ; * height in bytes or pixels
           bra.s   clearNext

clearLoop
           clr.b   (a2)+               ; Clear one byte

clearNext
           dbra    d0,clearLoop        ; And the rest


;--------------------------------------------------------------------
; Initialise A2 to point at the block command parameters. We need it
; in A1 actually, but A1 gets corrupted so we save it in A2. We also
; load up the initial position of the ant into D2. The top word of D2
; is the Across coordinate, the low word is the Down coordinate. D5
; is set to zero, for DOWN, which is the direction the ant is facing.
; Try changing it, see what happens.
; A5 is set to the IPC command string, which we need in A` later. So
; as A3 is preserved through an IPC call, we can EXG these two.
;--------------------------------------------------------------------
           lea     Block,a2            ; Needed in A1 later
           move.l  xpos(pc),d2         ; Hi = Across, Lo = Down
           moveq   #0,d5               ; Direction ant is walking
           lea     ipc_command,a5      ; Read KEYROW 1 for ESC key

;--------------------------------------------------------------------
; And here we start the main loop. We adjust the ant coordinates to
; fall into range. This is why we used a power of two as the sizes as
; it makes it easier to keep the coordinates in range 0 to size - 1.
;--------------------------------------------------------------------
; REGISTERS USED BEYOND THIS POINT
;
; D0 = Trap codes.
; D1 = Ant or Cell colour, red, white or black.
; D2 = Hi word = Across, Lo word = Down coordinates.
; D3 = Timeout for traps. -1 always.
; D4 = Holds the bitmap offset for the current cell.
; D5 = Direction indicator. 0=Down, 1=Left, 2=Up, 3=Right.
; D6 = Unused.
; D7 = Copy of Direction, used in walking to next cell.
;
; A0 = Channel Id
; A1 = Used for trap calls.
; A2 = Pointer to BLOCK command in job code. (Used in A1.)
; A3 = Pointer to Cells bitmap.
; A4 = Unused.
; A5 = Pointer to IPC command to read KEYROW 1 for ESC key.
; A6 = Reserved for QDOS/SMSQ
; A7 = Stack Pointer.
;
; Cells Bitmap.
;
; The cells array of bytes measures size_y * (size_x / 8) bytes
; and holds 1 bit for every cell in the screen (512 * 256 default)
; with a zero bit meaning a white cell and a 1 bit being black.
;--------------------------------------------------------------------
antWalk
           andi.w  #size_y-1,d2        ; Make down 0 to size_y-1
           swap    d2
           andi.w  #size_x-1,d2        ; Make across 0 to size_x-1
           swap    d2
           move.l  d2,4(a2)            ; Update block coordinates

;--------------------------------------------------------------------
; We have saved the adjusted coordinates in the BLOCK command's 
; parameters, plot the current ant position with a red pixel. Good
; luck seeing that, it moves pretty quickly!
;--------------------------------------------------------------------
plotAnt
           moveq   #sd_fill,d0         ; Block command
           moveq   #red,d1             ; It's a red ant of course!
           move.l  a2,a1               ; Block parameter block
           bsr     doTrap3             ; Won't return on error

;--------------------------------------------------------------------
; We need to get the current cell at this point. We want the number 
; of the bit in the cells bitmap, corresponding to the across and
; down coordinates, in D4. 
;
; At this point we have:
;
; A3 = the cells bitmap start address.
; D2 = Across | Down coordinates.
;--------------------------------------------------------------------

;--------------------------------------------------------------------
; Calculate the bit field number for the current cell.
;--------------------------------------------------------------------
bitNumber
           move.w  #size_x,d4          ; Width
           mulu    d2,d4               ; Width * Down
           swap    d2                  ; Across in low word
           add.w   d2,d4               ; Across + (Down * Width)
           swap    d2                  ; REstore coordinates
           bftst   (A3){D4:1}          ; Test the bit

;--------------------------------------------------------------------
; Rule 1: If the cell is white, turn it black, right turn, walk on.
;--------------------------------------------------------------------
ruleOne
           bne.s   ruleTwo
           bfset   (A3){D4:1}          ; Turn it black in the bitmap
           moveq   #black,d1           ; Colour for BLOCK command
           subq.b  #1,d5               ; Direction - 1 = right
           bra.s   doDirection         ; Prepare to walk on

;--------------------------------------------------------------------
; Rule 2: If the cell is black, turn it white, left turn, walk on.
;--------------------------------------------------------------------
ruleTwo
           bfclr   (A3){D4:1}          ; Turn it white in the bitmap
           moveq   #white,d1           ; Colour for BLOCK command
           addq.b  #1,d5               ; Direction + 1 = left

;--------------------------------------------------------------------
; We have adjusted the direction. Make sure we restrict it to 0 - 3.
;--------------------------------------------------------------------
doDirection
           andi.b  #3,d5               ; Restrict to 0 to 3
           move.b  d5,d7               ; Copy new direction

;--------------------------------------------------------------------
; Ready to walk on in the new direction. 
;
; The directions are:
;
;         UP
;          2
; LEFT 3       1 RIGHT
;          0
;         DOWN
;
; So, if direction is up (2) then turn right = 1 and turn left = 3
;
; Plus 1 = turn left
; Minus 1 = turn right.
;
; If direction = down  = 0 then Down   + 1
; If direction = right = 1 then Across + 1
; If direction = up    = 2 then Down   - 1
; If direction = left  = 3 then Across - 1
;--------------------------------------------------------------------

;--------------------------------------------------------------------
; Check the direction for Down, if not then skip, otherwise adjust
; the Down coordinate by +1.
;--------------------------------------------------------------------
doWalk
           bne.s   tryRight

doDown
           addq.w  #1,d2               ; Down + 1
           bra.s   doPlot

;--------------------------------------------------------------------
; Check if the new direction is Right. If so, adjust the Across 
; coordinate by +1.
;--------------------------------------------------------------------
tryRight
           subq.b  #1,d7
           bne.s   tryUp

doRight
           swap    d2                  ; Down | Across
           addq.w  #1,d2               ; Across + 1
           swap    d2                  ; Across | Down
           bra.s   doPlot

;--------------------------------------------------------------------
; Check if the new direction is Up. If so, adjust the Down coordinate
; by -1.
;--------------------------------------------------------------------
tryUp
           subq.b  #1,d7
           bne.s   doLeft              ; Must be left

doUp
           subq.w  #1,d2               ; Down - 1
           bra.s   doPlot

;--------------------------------------------------------------------
; The new direction must be Left. Adjust the Across coordinate by -1.
;--------------------------------------------------------------------
doLeft
           swap    d2                  ; Down | Across
           subq.w  #1,d2               ; Across - 1
           swap    d2                  ; Across | Down

;--------------------------------------------------------------------
; We can overwrite the red ant at the current coordinates with either
; a black or a white cell. When we get here, D1 holds the correct
; colour.
;--------------------------------------------------------------------
doPlot
           moveq   #sd_fill,d0         ; Block command
           move.l  a2,a1               ; Block parameter block
           bsr     doTrap3             ; Won't return on error

;--------------------------------------------------------------------
; We have overwritten the current coordinate, update the BLOCK 
; parameters with the new coordinates - this is effectively a single
; step in the new direction.
;--------------------------------------------------------------------
nowMove
           move.l  d2,4(a2)            ; Update coordinates

;--------------------------------------------------------------------
; Read the keyboard and check on the ESC key. If pressed, we are done 
; here. If not pressed, go around again after suspending for a few
; frames.
;--------------------------------------------------------------------
hadEnough
           move.w  d5,-(a7)            ; Direction gets corrupted
           exg     a3,a5               ; We need the IPC command in A3
           moveq   #mt_ipcom,d0        ; IPC command coming up
           bsr     doTrap1             ; Dies on error
           move.w  (a7)+,d5            ; Restore direction
           exg     a3,a5               ; Cells address in A3 again
           btst    #esc,d1             ; ESC pressed?
           beq     hangAbout           ; No, go around
           moveq   #0,d0               ; Yes, show no errors
           bra     suicide             ; Kill myself

;--------------------------------------------------------------------
; Delay processing for a few frames. Without this, the job has pretty
; much finished by the time you get to see the screen!
;--------------------------------------------------------------------
hangAbout
           ;bra    antWalk

           moveq   #3,d0               ; Outer loop counter
d0Loop
           moveq   #-1,d1              ; Inner loop counter
d1Loop
           nop
           nop
           dbra    d1,d1Loop
           dbra    d0,d0Loop

           bra     antWalk             ; Go around

;--------------------------------------------------------------------
; This is the ant's world. It is a bitmap representing the cells that
; the ant walks over. Each bit defines the colour of a cell. Zero is
; white and 1 is black.
;--------------------------------------------------------------------
cells
           ds.b    size_y*(size_x/8)
