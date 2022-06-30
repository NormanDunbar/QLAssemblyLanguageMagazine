;=============================================================
; NDBM Hash Function.
;
; This is loosely based on the SDBM hash but is not as good as
; the SDBM function requires 64 bit variables and the QL only
; has 32 bits available. Shame.
;
; The hash is calculated as:
;
;    hash(i) = hash(i-1) + (str(i) * str(i))
;
; Register Usage:
;
; Entry:
;
; A1.L = pointer to SMS format string.
;
;
; Exit:
; 
; A1.L preserved.
; D0.L = error code (ERR.OVFL) or zero if no overflow.
; All other registers are preserved.
;=============================================================
err.ovfl    equ $ee             ; Overflow error code

ndbm
    movem.l d2-d3/a1,-(a7)      ; Preserve working registers
    moveq #0,d1                 ; Current hash value
    move.l d1,d3                ; A "zero" register
    move.w (a1)+,d2             ; String size, can be zero!
    bra.s ndbmEndLoop           ; Skip loop

ndbmLoop
    move.l d3,d0                ; Clear D0 again
    move.b (a1)+,d0             ; Get current character
    mulu d0,d0                  ; Multiply by itself
    add.l d0,d1                 ; Update hash
    bvs.s ndbmError             ; Oops, overflow!
    
ndbmEndLoop
    dbra d2,ndbmLoop            ; Go around again
    move.l d3,d0                ; No errors
    bra.s ndbmExit              ; Finished
    
ndbmError
    moveq #err.ovfl,d0          ; Overflow error

ndbmExit
    movem.l (a7)+,d2-d3/a1      ; Restore working registers
    rts
