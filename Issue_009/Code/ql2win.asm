;--------------------------------------------------------------
; QL2WIN:
;
; This filter converts QL or Linux line endings to Windows
; format.
;
; EX ql2win_bin, input_file, output_file_or_channel
;--------------------------------------------------------------
; 21/02/2021 NDunbar Created for QDOSMSQ Assembly Mailing List
;--------------------------------------------------------------
; (c) Norman Dunbar, 2021. Permission granted for unlimited use
; or abuse, without attribution being required. Just enjoy!
;--------------------------------------------------------------

;--------------------------------------------------------------
; How many channels do I want?
;--------------------------------------------------------------
numchans    equ     2         ; How many channels required?

;--------------------------------------------------------------
; Stack stuff.
;--------------------------------------------------------------
sourceId    equ     $02       ; Offset(A7) to input file id
destId      equ     $06       ; Offset(A7) to output file id

;--------------------------------------------------------------
; Other Variables
;--------------------------------------------------------------
err_bp      equ     -15
err_eof     equ     -10
me          equ     -1
timeout     equ     -1
lf          equ     $0a
cr          equ     $0d

;==============================================================
; Here begins the code.
;--------------------------------------------------------------
; Stack on entry:
;
; $06(a7) = Output file channel id.
; $02(a7) = Source file channel id.
; $00(a7) = How many channels? Should be $02.
;==============================================================
start
    bra.s   checkStack
    dc.l    $00
    dc.w    $4afb
name
    dc.w    name_end-name-2
    dc.b    'QL2WIN'
name_end    equ       *

version
    dc.w    vers_end-version-2
    dc.b    'Version 1.00'
vers_end    equ       *


;--------------------------------------------------------------
; Check the stack on entry. We only require NUMCHAN channels.
; Anything other than NUMCHANS will result in a BAD PARAMETER
; error on exit from EW (but not from EX).
;--------------------------------------------------------------
checkStack
    cmpi.w  #numchans,(a7)    ; Two channels is a must
    beq.s   ql2win            ; Ok, skip error bit

bad_parameter
    moveq   #err_bp,d0        ; Guess!
    bra     errorExit         ; Die horribly

;--------------------------------------------------------------
; Initialise a couple of registers that will keep their values
; all through the rest of the code. These are:
;
; D3 holds the read and write timeout value, -1.
; D4 holds the buffer size for reading into, buffSize.
; A3 holds the buffer for reading and writing.
; A4 holds the source channel id.
; A5 holds the destination channel id.
;--------------------------------------------------------------
ql2win
    moveq   #timeout,d3       ; Timeout
    moveq   #buffSize,d4      ; Storage for buffer size for D2
    lea     buffer,a3         ; Start of (write) buffer
    move.l  sourceID(a7),a4   ; Source channel id
    move.l  destId(a7),a5     ; Destination channel id

;--------------------------------------------------------------
; The main loop starts here. Read a single byte, check for EOF.
;
; D0 = 2 (io_fline)         Error code
; D1.W                      Bytes read into buffer
; D2.W = Buffer Size        Preserved
; D3.W = timeout.           Preserved
; A0.L = Channel ID.        Preserved
; A1.L = Start of buffer.   Updated buffer (A1 + D2.W)
;--------------------------------------------------------------
readLoop
    moveq   #io_fline,d0      ; Fetch lines ending with LF
    move.w  d4,d2             ; Buffer size
    movea.l a4,a0             ; Channel to read
    movea.l a3,a1             ; Read buffer start
    trap    #3                ; Read a line from input file
    tst.l   d0                ; OK?
    beq.s   gotLine           ; Yes
    cmpi.l  #ERR_EOF,d0       ; All done yet?
    beq     allDone           ; Yes.
    bra     errorExit         ; Oops!

;--------------------------------------------------------------
; At this point, we have a string and a clean read with no
; errors. Check if we have read an entire line before we try to
; convert this to Windows format.
;
; D1.W = bytes read into buffer, inc LF.
; A1.L = one past where the LF should be.
; If -1(a1) == lf we have a whole string.
; Else write out what we have and read more of the same string.
;--------------------------------------------------------------
gotLine
    move.w  d1,d2             ; Bytes read, required for write
    cmpi.b  #lf,-1(a1)        ; Did we read the whole line?
    bne.s  putLine            ; No, write out what we got

;--------------------------------------------------------------
; We have read at least the end of a line and have the LF at
; the correct place in the buffer. If the character before it
; is a CR ignore it and write out, otherwise insert a CR before
; the LF and write it all out.
;--------------------------------------------------------------
    cmpi.b  #cr,-2(a1)        ; Already Windows format?
    beq.s   putLine           ; Yes, ignore CR and write out
    move.b  #cr,-1(a1)        ; Insert CR
    move.b  #lf,(a1)          ; Needs LF also
    addq.w  #1,d2             ; Update count for the CR

;--------------------------------------------------------------
; Write out the contents of the buffer.
;
; D0 = 7 (io_sstrg)         Error code
; D1.W                      Bytes written to channel
; D2.W = Buffer Size        Preserved
; D3.W = timeout.           Preserved
; A0.L = Channel ID.        Preserved
; A1.L = Start of buffer.   Updated buffer (A1 + D2.W)
;--------------------------------------------------------------
putLine
    moveq   #io_sstrg,d0      ; Send strings
    movea.l  a5,a0            ; Dest channel id
    movea.l  a3,a1            ; Write buffer
    trap    #3                ; Do it
    tst.l   d0                ; OK?
    beq.s   readLoop          ; Yes, keep going
    bra.s   errorExit         ; No.

;--------------------------------------------------------------
; No errors, exit quietly back to SuperBASIC.
;--------------------------------------------------------------
allDone
    moveq   #0,d0

;--------------------------------------------------------------
; We have hit an error so we copy the code to D3 then exit via
; a forced removal of this job. EXEC_W/EW will display the
; error in SuperBASIC, but EXEC/EX will not.
;--------------------------------------------------------------
errorExit
    move.l  d0,d3             ; Error code we want to return

;--------------------------------------------------------------
; Kill myself when an error was detected, or at EOF.
;--------------------------------------------------------------
suicide
    moveq   #mt_frjob,d0      ; This job will die soon
    moveq   #me,d1
    trap    #1

;--------------------------------------------------------------
; Read/write buffer. The buffer is 2 bytes longer than we need
; as there needs to be room to insert the required CRLF in
; place of the LF.
;--------------------------------------------------------------
buffSize    equ     64*2        ; Buffer Size
buffer      ds.b    buffSize+2  ; Buffer

