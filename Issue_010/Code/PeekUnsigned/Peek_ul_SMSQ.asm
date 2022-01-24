;==============================================================
; PEEK_UL(address) returns the unsigned long word at address.
; The value has to be returned as a float as we can't return a
; long value. Sigh.
;==============================================================

;--------------------------------------------------------------
; Equates for SMSQ/E.
;--------------------------------------------------------------
sb_arthp equ $58                ; Where is top of maths stack
sb.inipr equ $110               ; Add procs/fns to S*BASIC
sb.gtlin equ $118               ; Fetch long int parameters
qa.resri equ $11a               ; Reserve maths stack space
qa.op    equ $11c               ; Do one maths stack operation

qa.flong equ $09                ; Convert long to float (SMSQ)
qa.add   equ $0a                ; Add TOS to NOS on maths stack

err.ipar equ -15                ; Bad parameter error code

exp231   equ $0820              ; 2^31 exponent
exp215   equ $0810              ; 2^15 exponent
mantBoth equ $40000000          ; 2^31 & 2^15 mantissa

peek_w   equ exp215             ; Flag for peek_uw
peek_l   equ exp231             ; Flag for peek_ul

;--------------------------------------------------------------
; Call here to link in the new function(s). 
;--------------------------------------------------------------
start
    lea define,a1               ; Proc/FN definition list
    move.w sb.inipr,a2          ; Ready to add to S*BASIC
    jsr (a2)                    ; Do it
    rts                         ; Take errors back to S*BASIC

;--------------------------------------------------------------
; S*BASIC definition block for new function(s).
;--------------------------------------------------------------
define
    dc.w 0                      ; No procedures
    dc.w 0                      ; End of procedure list

    dc.w 2                      ; 2 Functions
        dc.w peek_ul-*          ; Offset to function
        dc.b 7,'PEEK_UL'        ; The function name

        dc.w peek_uw-*          ; Offset to function
        dc.b 7,'PEEK_UW'        ; The function name
    dc.w 0                      ; End of functions


;--------------------------------------------------------------
;                                              PEEK_UW(address)
;
; There should be a single parameter, the address. Test before
; fetching.
;--------------------------------------------------------------
peek_uw
    move.w #peek_w,d4           ; Flag for peek_uw
    bra.s peekBoth              ; Off we go then!

;--------------------------------------------------------------
;                                              PEEK_UL(address)
;
; There should be a single parameter, the address. Test before
; fetching.
;--------------------------------------------------------------
peek_ul
    move.w #peek_l,d4           ; Flag for peek_ul

peekBoth
    move.l a5,d0                ; First parameter
    sub.l a3,d0                 ; Last parameter
    cmpi.l #8,d0                ; 8 bytes per parameter
    beq.s pulGetParam           ; We have one parameter to get

pulBadParam
    moveq #err.ipar,d0          ; That didn't go well then!
    rts                         ; Back to S*BASIC

;--------------------------------------------------------------
; Fetch one single long integer parameter. Bale out if errors
; detected in the fetch.
;--------------------------------------------------------------
pulGetParam
    movea.w sb.gtlin,a2         ; We want a long integer
    jsr (a2)                    ; Go fetch
    beq.s pulTestOne            ; No problems detected
    rts                         ; Back to S*BASIC with error

;--------------------------------------------------------------
; Check after the fetch, that we did actually get 1 parameter.
; It's unlikely, but probably bad if not.
;--------------------------------------------------------------
pulTestOne
    cmpi.w #1,d3                ; Make sure we got one only
    bne.s pulBadParam           ; Weirdness has happened!

;--------------------------------------------------------------
; We fetched one parameter, the address, get it into a2 and
; fetch the long word at that address into D7.L.
;--------------------------------------------------------------
pulGotParam
    move.l (a6,a1.l),a2         ; Get the address into a2.
    move.l (a2),d7              ; Peek the address

;--------------------------------------------------------------
; We have a long in D7, if we need a word then clear the lower
; word then swap words to get the high word as the result.
;--------------------------------------------------------------
pulWord    
    cmpi.w #peek_w,d4           ; Are we looking for a word?
    bne.s pulGotPeek            ; No, continue
    clr.w d7                    ; We don't need the bottom word
    swap d7                     ; Correct word for peek_uw

;--------------------------------------------------------------
; Common point for both variants of peek_ul/peek_uw.
;--------------------------------------------------------------
pulGotPeek equ *                ; It's just a label for both

;=========================================================
; Only use code on QDOS machines. SMSQ is easier!
;=========================================================

;--------------------------------------------------------------
; Float D7 into D4.W (exponent) and D5.L (Mantissa) ready to
; return to S*BASIC. This version is for QDOS machines. 
;
; First, make space for a float result on the stack. We only
; need an extra 2 bytes as we have four there already.
;--------------------------------------------------------------
;pulMakeSpace
;    moveq #2,d1                 ; 2 extra bytes required
;    bsr.s pulGetSpace           ; Reserve space, sets A1 to TOS

;--------------------------------------------------------------
; Now the maths stack is ready to accept a 6 byte float now. We
; can convert D7.L to a float with the exponent in D5 and the 
; mantissa in D6. Code stolen from DJ_TOOLKIT and I have no 
; idea how it works now -- it's been far too long!
;--------------------------------------------------------------
;pulFloatD7QDOS
;    move.l d7,d6                ; Mantissa
;    beq.s pulNormalised         ; We are done if D7.L = zero
;    move.w #$081f,d5            ; Starting exponent value
;    add.l d7,d7                 ; Already normalised?
;    bvs.s pulNormalised         ; Yes
;    subq.w #1,d5                ; No, halve the exponent
;    move.l d7,d6                ; Mantissa * 2
;    moveq #$10,d0               ; Start with a 16 bit shift

;pulNormalise
;    move.l d6,d7	            ; Copy the mantissa
;    asl.l d0,d7                 ; Multiply by 2^D0
;    bvs.s pulTooBig             ; Oops, too big now
;    sub.w d0,d5                 ; Adjust exponent for the shift
;    move.l d7,d6                ; Getting more normalised now

;pulTooBig
;    asr.w #1,d0                 ; Halve the shift size
;    bne.s pulNormalise          ; Do 8, 4, 2, 1 shifts

;pulNormalised
;	move.w d5,(a6,a1.l)         ; Stack exponent
;	move.l d6,2(a6,a1.l)        ; Stack mantissa

;=========================================================
; End of QDOS specific code.
;=========================================================

;=========================================================
; Don't use this on QDOS machines. Only for SMSQ/E.
;=========================================================

;--------------------------------------------------------------
; Float D7 onto the maths stack. This version is for SMSQ 
; machines only and won't work on QDOS.
;
; As we obtained the address parameter as a long, we have space 
; for a long on the maths stack already. A1 is still valid as a
; maths stack pointer.
;--------------------------------------------------------------
pulFloatD7SMSQ
    move.l d7,(a6,a1.l)         ; Stack D7.L
    move.l #qa.flong,d0         ; Float a long operation code
    bsr.s pulDoMathsOp          ; Do it
    beq.s pulTestNegative       ; All was well
    rts                         ; Take errors back to S*BASIC    

;=========================================================
; End of SMSQ/E specific code.
;=========================================================

;--------------------------------------------------------------
; Is the float negative? Bit 31 of the mantissa tells us so. If
; it is, we need to add 2^32 to the value before returning to
; S*BASIC.
;--------------------------------------------------------------
pulTestNegative
    btst #7,2(a6,a1.l)          ; Mantissa bit 31
    beq.s pulValuePositive      ; It's positive, skip

;--------------------------------------------------------------
; The value is negative, make it positive by adding 2^31 for
; peek_ul, or 2^15 for peek_uw, to the float on the maths 
; stack. 
; 
; 2^15 = $0810 $40000000 in binary.
; 2^31 = $0820 $40000000 in binary.
;
; And usefully, D4 holds the correct exponent!
;--------------------------------------------------------------
pulValueNegative
    moveq #6,d1                 ; Need space for a float
    bsr.s pulGetSpace           ; Reserve space, sets A1
    move.w d4,(a6,a1.l)         ; Stack 2^D4 exponent
    move.l #mantBoth,2(a6,a1.l) ; Stack common mantissa
    move.l #qa.add,d0           ; Add TOS to NOS operation code
    bsr.s pulDoMathsOp          ; Do it
    beq.s pulValuePositive      ; All was well
    rts                         ; Take errors back to S*BASIC      

;--------------------------------------------------------------
; We have a positive value on top of the maths stack, return it
; to S*BASIC. At this point SB.ARTHP is correctly set to point
; at TOS.
;--------------------------------------------------------------
pulValuePositive
    moveq #2,d4                 ; Return is floating point
    moveq #0,d0                 ; No errors
    rts                         ; Done

;--------------------------------------------------------------
; Reserve D1.L bytes of maths stack space.
;
; ENTRY:
; D1.L bytes required
; A1.L points to TOP of maths stack - relative A6
;
; EXIT:
;
; TRASHES:
; D2, D3, A1, A2. Rest preserved.
;--------------------------------------------------------------
pulGetSpace
    move.l d1,-(a7)             ; Save space required
    move.l a1,sb_arthp(a6)      ; Store current TOS
    move.w qa.resri,a2          ; Allocate maths stack space
    jsr (a2)                    ; Do it - never errors
    move.l sb_arthp(a6),a1      ; Fetch possible new A1 value
    move.l (a7)+,d1             ; Retrieve space requested
    sub.l d1,a1                 ; Adjust space as required
    move.l a1,sb_arthp(a6)      ; And store new TOS
    rts

;--------------------------------------------------------------
; Execute a single maths stack operation and update QA.ARTHP.
;
; ENTRY:
; D0.W Operation code to execute
; A1.L points to TOP of maths stack - relative A6
;
; EXIT:
; D0.L Error code or zero
; A1.L Updated to new TOS
;
; TRASHES:
; None.
;--------------------------------------------------------------
pulDoMathsOp
    move.w qa.op,a2             ; Do 1 maths operation
    jsr (a2)                    ; Do the conversion
    beq.s pulFixup              ; No errors, adjust SB_ARTHP
    rts                         ; Errors go back to caller

pulFixup
    move.l a1,sb_arthp(a6)      ; Save new TOS pointer
    moveq #0,d0                 ; No errors
    rts
