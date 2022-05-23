err.ipar equ -15                ; Bad parameter error
qa.resri equ $11a               ; Allocate maths stack space
sv_arthp equ $58                ; Storage for maths stack top


;    section code                ; Uncomment for QMAC

;--------------------------------------------------------------
; All we have to do here is link the new functions into S*BASIC
; errors, if any, will be returned to S*BASIC on exit.
;--------------------------------------------------------------
start
    lea define,a1
    move.w bp_init,a2
    jsr (a2)
    rts

    ds.w 0
    
;--------------------------------------------------------------
; Definition block for two functions, FN_0 and FN_1. The names
; just reflect how many parameters the function takes. There
; are no procedures defined.
;--------------------------------------------------------------
define
    dc.w 0                      ; No procedures
    dc.w 0                      ; End of procedures

    dc.w 2                      ; Two functions
    
    dc.w fn0-*                  ; Offset to fn_0
    dc.b 4,'FN_0'               ; Size of, and function name.

    dc.w fn1-*                  ; Offset to fn_1
    dc.b 4,'FN_1'               ; Size of, and function name.
           
    dc.w 0                      ; End of functions
   
;--------------------------------------------------------------
; FN_0 takes no parameters and returns zero as an integer word
; of two bytes.
;-------------------------------------------------------------- 
fn0
    trap #15                    ; Jump into QMON2
    moveq #0,d7                 ; Result in D7
    moveq #2,d6                 ; How much space do I need?
    bra.s fnResult              ; Just return a result

;--------------------------------------------------------------
; FN_1 takes one integer word parameter and returns it +1 as an
; integer word of two bytes. No validation here before fetching
; the parameter(s), but we do check for fetching only one.
;--------------------------------------------------------------
fn1
    trap #15                    ; Jump into QMON2
    move.w ca_gtint,a2          ; Fetch word integers only
    jsr (a2)                    ; Do it
    tst.l d0                    ; Ok?
    beq.s fn1Check              ; Yes, carry on
    rts                         ; No, bale out

fn1Check
    cmpi.w #1,d3                ; How many? We need 1
    beq.s fn1Got1               ; Yes, carry on
    moveq #err.ipar,d0          ; Bad parameter
    rts                         ; Error out

fn1Got1
    move.w 0(a6,a1.l),d7        ; Fetch the parameter 
    addq.w #1,d7                ; Increment for return    
    moveq #0,d6                 ; No space required

;--------------------------------------------------------------
; This code returns the function results. For FN_0 it has to
; allocate two bytes but for FN_1, there's already space as we
; used two bytes for the parameter. The result is in D7 and D6
; holds the space we need to allocate on the stack for the 
; result.
;--------------------------------------------------------------
fnResult
    tst.w d6                    ; Do I need space allocated?
    beq.s rtnFn1                ; No, use existing space
    move.l sv_arthp(a6),a1      ; Yes, get the stack pointer
    move.w d6,d1                ; Space needed for result
    move.w qa.resri,a2          ; Allocation vector
    jsr (a2)                    ; Allocate - will not error out
    move.l sv_arthp(a6),a1      ; Possible new maths stack
    subq.l #2,a1                ; Make room for result
    
rtnFn1
    move.w d7,0(a6,a1.l)        ; Stack the result
    moveq #3,d4                 ; Signal word integer result
    move.l a1,sv_arthp(a6)      ; Save top of stack
    moveq #0,d0                 ; No errors
    rts                         ; Back to S*BASIC

;    end                         ; Uncomment for QMC assembler

