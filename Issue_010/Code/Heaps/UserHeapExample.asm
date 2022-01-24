sms.achp  equ $18
sms.rehp  equ $0d

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
    moveq #sms.rehp,d0          ; Trap code
    suba.l a6,a0                ; We need A0 to be A6 relative
    lea myHeap,a1               ; Pointer to heap header
    move.l 0,(a1)               ; Indicate this is a new heap
    suba.l a6,a1                ; This needs to be relative A6
    trap #1                     ; That should do it (No errors)
    bra.s useHeap			   ; Go and use the heap space

myHeap
	ds.l 1                      ; Pointer to free space

sms.alhp  equ $0c

; Allocate space in the user heap.
useHeap
    moveq #sms.alhp,d0          ; Trap code
    move.l #200,d1              ; I need 200 bytes of user heap
    lea myHeap,a0               ; MyHeap = Free space pointer
    suba.l a6,a0                ; Relative to A6        
    trap #1                     ; Allocate 200 bytes
    tst.l d0                    ; Did it work?
    bra.s doStuff               ; Go and use the allocation

; Handle out of user heap memory errors here
    rts                         ; Back to SuperBasic
        
; Now we have allocated some user heap, use it somehow
doStuff 
    adda.l a6,a0                ; Absolute the address

freeUser  
    moveq #sms.rehp,d0          ; Trap code
    move.l #200,d1              ; Size is 200 bytes
    suba.l a6,a0                ; A0 has to be relative a6
    lea myHeap,a1               ; Pointer to top of heap
    suba.l a6,a1                ; Which has also to be relative A6
    trap #1                     ; Deallocate the 200 byte area
    rts                         ; Back to SuperBasic

