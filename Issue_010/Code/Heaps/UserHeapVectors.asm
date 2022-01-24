sms.achp  equ $18
mem.rehp  equ $DA

; First, allocate a 64Kb common heap area:
start   
    moveq #sms.achp,d0          ; Trap code
    move.l #65536,d1            ; 64Kb required
    moveq #-1,d2                ; This job will be the owner
    trap #1                     ; Allocate the space
    tst.l d0                    ; Did it work?
    beq.s heapOk                ; Yes

; Handle out of memory errors here.
    rts                         ; Back to SuperBasic
        
; We have a common heap, convert it to a user heap :
heapOk
	move.w mem.rehp,a2          ; Vector 
    lea myHeap,a1               ; Pointer to pointer to free space
    move.l #65536,d1            ; We have 64 Kb to play with
    jsr (a2)                    ; Convert to a user heap
    tst.l d0                    ; Did it work
    beq.s useHeap               ; Yes
    rts                         ; No

myHeap
	ds.l 1                      ; Pointer to free space

mem.alhp  equ $D8

; Allocate space in the user heap.
useHeap
    move.l #200+8,d1            ; I need 200 bytes of user heap
    lea myHeap,a0               ; MyHeap = Free space pointer
    move.w mem.alhp,a2          ; Vector
    jsr (a2)                    ; Get some user heap
    tst.l d0                    ; Did it work?
    bra.s doStuff               ; Yes
    rts                         ; No
        
; Now we have allocated some user heap, use it somehow
doStuff 
   move.l #$12345678,8(a0)      ; Avoid writing the header bytes
;   ...

; Now deallocate the user heap space.
freeUser  
    lea myHeap,a1               ; Pointer to pointer to free space
	move.w mem.rehp,a2          ; Vector 
    move.l (a0),d1              ; Block length to free up
    jsr (a2)                    ; Free the space
    rts                         ; Back to SuperBASIC
