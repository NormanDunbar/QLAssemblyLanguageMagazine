;------------------------------------------------------------
; This is effectively randomise(date). The code is exactly as
; per the SuperBASIC function. I stole the code from
; sbsext/ext/rnd.asm.
;
; Enter with D1.L = 0 to randomise(date) or with D1.L = some
; specified value to randomise(D1).
;
; Preserves all registers.
;------------------------------------------------------------
randomise
    movem.l d0-d2/a0,-(a7)      ; Save workers
    tst.l   d1                  ; D1 passed with a value?
    bne.s   randomise_d1        ; Yes, skip date bit
    moveq   #mt_rclck,d0        ; Read clock
    trap    #1                  ; No errors, no need to
;                               ; call doTrap1.

randomise_d1
    move.l  d1,d2               ; Copy HHHH LLLL
    swap    d1                  ; LLLL HHHH
    add.l   d2,d1               ; LLLL = HHHH
    move.l  d1,myRandSeed(a6)   ; Save random seed
    movem.l (a7)+,d0-d2/a0      ; restore workers
    rts


;------------------------------------------------------------
; This is effectively RND(1 TO 6). The code does exactly as
; per the SBasic RND function. I stole the code!
;
; D1 = Bottom of range = 1.
; D2 = Top of range + 1 = 7.
;
; Returns D1.W as RND(1 to 6) and obviously trashes D1.
;------------------------------------------------------------
rnd
    movem.l d0/d2/d4,-(a7)      ; Save workers
    move.l  myRandSeed(a6),d0   ; Get seed value
    move.w  d0,d4               ; Copy low word LLLL
    swap    d0                  ; LLLL HHHH
    mulu    #$c12d,d0           ; HHHH * 49453
    mulu    #$712d,d4           ; LLLL * 28973
    swap    d0                  ; HHHH LLLL
    clr.w   d0                  ; HHHH 0000 (Divide by 65536)
    add.l   d0,d4               ; I have no idea!!!
    addq.l  #1,d4               ; New seed
    move.l  d4,myRandSeed(a6)   ; Save seed

rndOneToSix
    moveq   #1,d1               ; Bottom of range
    moveq   #6+1,d2             ; Top of range + 1
    sub.w   d1,d2               ; Size of range

    swap    d4                  ; LLLL HHHH of seed
    mulu    d2,d4               ; D4.HHHH * top
    swap    d4                  ; Take top word
    add.w   d4,d1               ; Add range bottom
;                               ; D1 = RND(1 to 6)
    movem.l (a7)+,d0/d2/d4      ; Restore workers.
    rts
