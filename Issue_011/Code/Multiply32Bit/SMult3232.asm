;--------------------------------------------------------------
; Code for signed multiply of two 32 bit numbers in D0 and D1.
; Does some jiggery pokery (!) before calling unsigned "mult32"
; and on return, adjusts things to undo the jiggery pokery!
;
; Negative * Negative = Positive.
; Positive * Positive = Positive.
; Negative * Positive = Negative.
;--------------------------------------------------------------

smult32
    move.w d6,-(a7)             ; Save flag register
    moveq #1,d6                 ; Assume both have same sign

;--------------------------------------------------------------
; Test D0 for negativity. If negative set a flag in D6 and 
; make D0 positive.
;--------------------------------------------------------------
sm32TestD0
    tst.l d0                    ; Check for negative
    bpl.s sm32TestD1            ; Skip if positive
    neg.b d6                    ; D6 is negative if D0 is too
    neg.l d0                    ; Make D0 positive

;--------------------------------------------------------------
; Test D1 for negativity. If negative set a flag in D6 and 
; make D0 positive.
;--------------------------------------------------------------
sm32TestD1
    tst.l d1                    ; Check for negative
    bpl.s sm32DoMult            ; Skip if positive
    neg.b d6                    ; D6 now holds sign of result
    neg.l d1                    ; Make D1 positive

;--------------------------------------------------------------
; We now have two positive values in D0 and D1. Do unsigned 
; multiplication then adjust the sign according to D6. If D6 is 
; 0 or 2 we are done (Both positive or both negative) but if it
; is 1 then we need to make the result negative.
;--------------------------------------------------------------
sm32DoMult
    bsr.s mult32                ; Do unsigned multiplication
    tst.b d6                    ; Test flag byte
    bpl.s sm32Exit              ; Result is positive, all done

;--------------------------------------------------------------
; To negate a 64 bit value, NEG the low word and NEGX the high
; word.
;--------------------------------------------------------------
sm32Adjust
    neg.l d2                    ; Negate the low word
    negx.l d3                   ; And then the high word

sm32Exit
    move.w (a7)+,d6             ; Restore flag register
    rts                         ; All done

;--------------------------------------------------------------
; Code to multiply a 32 bit value in D0.L by another in D1.L. 
; The result will be returned as a 64 bit value in D3:D2 with
; D3 being the higher 32 bits. UNSIGNED.
;
; D0 and D1 are returned unchanged, unless overflow occurs, in
; which case, they are undefined.
;
; D3 and D2 hold the result.
;
; All other registers are preserved.
;--------------------------------------------------------------
; D0.L * D1.L = D3:D2 (D3.L holds high part)
;
; (D0lo * D1lo) +               ; Step 1 in D2
; (D0lo * D1hi << 16) +         ; Step 2 in D4/D5
; (D0hi * D1lo << 16) +         ; Step 3 in D4/D5
; (D0hi * D1hi << 32)           ; Step 4 in D3
;--------------------------------------------------------------
mult32
    movem.l d4-d5,-(a7)         ; Save Working registers
    moveq #0,d3                 ; Assume result will be zero
    move.l d3,d2

mult32TestD0D1
    tst.l d0                    ; Is D0 zero?
    beq.s m32Exit               ; Product must be zero, done
    tst.l d1                    ; Is D1 zero?
    beq.s m32Exit               ; Product must be zero, done

;--------------------------------------------------------------
; Step 1: (D0 low * D1 low), save the result in D2.
;--------------------------------------------------------------
m32Step_1
    move.w  d0,d2               ; D2 = D0 low
    mulu.w  d1,d2               ; D2 = (D0 low * D1 low)

;--------------------------------------------------------------
; We also need D0 low in D4.
;--------------------------------------------------------------
    move.w d0,d4                ; D4 = copy of D0 low

;--------------------------------------------------------------
; Step 4: (D0 high * D1 high), save result in D3.
;--------------------------------------------------------------
m32Step_4
    swap    d0                  ; D0 = LLLLHHHH     
    swap    d1                  ; D1 = LLLLHHHH
    move.w  d0,d3               ; D3 = D0 high
    mulu.w  d1,d3               ; D3 = (D0 high * D1 high)

;--------------------------------------------------------------
; Steps 2 and 3 are pretty much identical. We multiply one low
; word with the other high word, giving a 32 bit product. We
; need to shift that 16 bits leftwards though -- we only have 
; 32 bits in our registers, what to do? Use another register.
;
; If we start with HHHHHLLLL in a register, we can "shift" it
; 16 bits left and use a pair of registers, D5:D4, and end up
; with 0000HHHH LLLL0000 in D5:D4. This is a 16 bit shift.
; We then add the low 32 bits , D4, to D2 and add, with extend,
; D5 to D3. Then we do it again for the other low and high word
; values we have yet to calculate.
;
; At this point, our registers look like:
;
; D0 = First value, swapped = LLLLHHHH
; D1 = Second value, swapped = LLLLHHHH
; D2 = (D0lo * D1lo)
; D3 = (D0hi * D1hi)
; D4 = First value, from D0, ????LLLL (low word only)
; D5 = ????????
;--------------------------------------------------------------

;--------------------------------------------------------------
; Step 2: (D0 low * D1 high << 16), save result in D5:D4 as
; 0000HHHH LLLL0000.
;--------------------------------------------------------------
m32Step_2
    mulu.w  d1,d4               ; D4 = (D0 low * D1 high)
    swap    d4                  ; D4 = LLLLHHHH
    moveq   #0,d5               ; D5 = 00000000
    move.w  d4,d5               ; D5 = (D0lo * D1hi) 0000HHHH 
    clr.w   d4                  ; D5:D4 = 0000HHHH LLLL0000

;--------------------------------------------------------------
; Add (D0 low * D1 high << 16) in D5:D4 to the partial result
; currently in D3:D2.
;--------------------------------------------------------------
m32Step_2add 
    add.l   d4,d2
    addx.l  d5,d3               ; D3:D2 = Steps 1, 2 and 4 now

;--------------------------------------------------------------
; Step 3: (D0 high * D1 low << 16), save result in D5:D4 as
; 0000HHHH LLLL0000.
;--------------------------------------------------------------
m32Step_3
    swap    d1                  ; D1 = HHHHLLLL again
    move.w  d0,d4               ; D4 = D0 high word, ????HHHH
    mulu.w  d1,d4               ; D4 = (D0hi * D1lo) HHHHLLLL
    swap    d4                  ; D4 = LLLLHHHH
    moveq   #0,d5               ; D5 = 00000000
    move.w  d4,d5               ; D5 = (D0hi * D1lo) 0000HHHH 
    clr.w   d4                  ; D5:D4 = 0000HHHH LLLL0000

;--------------------------------------------------------------
; Add (D0 high * D1 low << 16) in D5:D4 to the partial result
; currently in D3:D2.
;--------------------------------------------------------------
m32Step_3add 
    add.l   d4,d2
    addx.l  d5,d3               ; We have a result!

;--------------------------------------------------------------
; D3:D2 now holds the 64 bit product of D0.L * D1.L.
;--------------------------------------------------------------
m32Done
    swap d0                     ; D0 finally back to HHHHLLLL

m32Exit
    movem.l (a7)+,d4-d5         ; Restore working registers
    rts

