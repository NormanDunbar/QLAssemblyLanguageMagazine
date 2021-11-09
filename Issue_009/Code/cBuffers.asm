;==============================================================
; Circular Buffers for the Sinclair QL
;==============================================================
;
; A circular buffer is an area of RAM consiting of a 6 byte
; header and a data area which is sized by the programmer and
; must be a power of two in size. The maximum power of two that
; fits a word is 32768. The data area of the buffer cannot be
; bigger than this size.

; The 6 byte header is used to hold the buffer's size, the head
; offset where the most recent byte of data was written to, the 
; tail offset where the most recent data byte was read back
; from.
;
; All the code expects buffer addresses to be passed in the A3
; register and the base address of the buffer's header is the
; address required, not the data area address:
;
; A3 -> cbSize      (word)     Power of 2 from 2 to 32768 only
;       cbHead      (word)     Offset to next byte to write
;       cbTail      (word)     Offset to next byte to read
;       Data bytes  (byte ...) Data bytes.
;
;==============================================================
; Copyright (C) Norman Dunbar 2021.
;
; MIT Licence applies. Feel free to use and abuse as you wish.
;==============================================================



;--------------------------------------------------------------
; Equates
;--------------------------------------------------------------
cbSize equ -6       ; How big is my buffer's data area?
cbHead equ -4       ; Where is my head? Last byte inserted.
cbTail equ -2       ; Where is my tail? Last byte removed.

MT_ALCHP equ $18    ; Allocate common heap
MT_RECHP equ $19    ; Release common heap



;--------------------------------------------------------------
; Allocate Buffer
;--------------------------------------------------------------
; Allocates memory for a new circular buffer. The size passed
; must be a power of 2 and cannot be larger than a word. This
; limits a buffer to a maximum size of 32,768 bytes. 1 of which
; will be unusable.
; 
; ENTRY:
;
; D0.W = Size of buffer. Power of two, 32768 maximum.
;
; EXIT:
;
; D0.L = Error code. (From MT_ALCHP)
;      = 0 if the buffer was created.
;      <>0 if the buffer failed to create.
;
; A3.L = Buffer address. (A3 -> cbSize in the buffer.)
;
; All other registers are preserved.
;--------------------------------------------------------------
allocateBuffer
        movem.l d1-d3/a0-a2,-(a7) ; Save working registers
		bsr.s checkSize         ; Returns D0.L as a power of 2
        move.l d0,d1            ; D1.L = space required
        addq.l #6,d1            ; Adjust for header space
        moveq #MT_ALCHP,d0      ; Allocate common heap
        moveq #-1,d2            ; Current job is owner
        trap #1
        tst.l d0                ; Do we allocate some heap?
        bne.s abExit            ; No       

        move.l a0,a3            ; Buffer address in A3.L
        subq.w #6,d1            ; Size of buffer data area
        move.w d1,(a3)          ; Set cbSize 
        clr.l 2(a3)             ; Set cbHead = cbTail = 0           

abExit
        movem.l (a7)+,d1-d3/a0-a2 ; Restore working registers
        rts


;--------------------------------------------------------------
; Check Size
;--------------------------------------------------------------
; Check the requested buffer size in D0 and round it up to the
; next largest power of two if not already a power. If less 
; than 8 bytes, make it 8. If more than 32768, then make it 
; 32768.
; 
; ENTRY:
;
; D0.W = Size of buffer.
;
; EXIT:
;
; D0.L = Potentially adjusted buffer size.
;
; All other registers are preserved.
;--------------------------------------------------------------
; Algorithm:
;
; Value = Value - 1
; REPEAT LOOP
;   Temp = Value & (Value - 1)
;   If Temp = 0, return min(max(2*Value, 8), 32768)
;   Value = Temp
; END LOOP
;
; D1.L = Value
; D0.L = Temp
;--------------------------------------------------------------
checkSize
        move.l d1,-(a7)     ; Save the worker
        moveq #0,d1
        move.w d0,d1        ; D1.L = Value

        subq.l #1,d1        ; In case Value is a power already

csLoop
        move.l d1,d0        ; Temp = Value
        subq.l #1,d0        ; Temp = (Value - 1)
        and.l d1,d0         ; Temp = Value & (Value - 1)
        beq.s csRange       ; If Temp = Zero = no more set bits
        move.l d0,d1        ; Value = Temp
        bne.s csLoop        ; Keep going

csRange
        lsl.l #1,d1         ; Value = Value * 2
        move.l d1,d0        ; To return the new value

csMin
        cmpi.l #8,d0        ; Minimum is 8
        bhi.s csMax         ; Bigger than 8
        moveq #8,d0         ; Result is 8
        bra.s csExit        ; Done

csMax
        cmpi.l #$8000,d0    ; Maximum is 32768
        ble.s csExit        ; Equal/Smaller than 32768
        move.l #$8000,d0    ; Result is 32768

csExit
        move.l (a7)+,d1     ; Restore worker
        rts





;--------------------------------------------------------------
; Free Buffer
;--------------------------------------------------------------
; deallocates memory for a circular buffer. 
; 
; ENTRY:
;
; A3.L = Buffer address. (A3 -> cbSize in the buffer.)
;
; EXIT:
;
; A3.L = Corrupted.
;
; All other registers are preserved.
;--------------------------------------------------------------
freeBuffer
        movem.l d0-d3/a0-a2,-(a7) ; Save working registers
        move.l a3,a0            ; Buffer address
        moveq #MT_RECHP,d0      ; Release common heap
        trap #1

fbExit
        movem.l (a7)+,d0-d3/a0-a2 ; Restore working registers
        rts


;--------------------------------------------------------------
; Add Byte
;--------------------------------------------------------------
; Adds one byte to a circular buffer.
; 
; ENTRY:
;
; D1.B = Byte to be added.
; A3.L = Buffer to add to. (A3 -> cbSize in the buffer.)
;
; EXIT:
;
; D0.L = Error code.
;      = 0 if the byte was added to the buffer.
;      = 1 if the buffer is full, so D1 was not added.
;
; All other registers are preserved.
;--------------------------------------------------------------
addByte
        movem.w d1/d4-d5/a3,-(a7) ; Save working registers

abIsFull
        bsr.s isFull            ; Preserves all registers
        beq.s abFullUp          ; Yes, bale out        

        move.w (a3)+,d5         ; Size of buffer
        subq.w #1,d5            ; We need one less than size
        move.w (a3)+,d4         ; Where is the head?
        addq.l #2,a3            ; Skip over the tail, not used
        addq.w #1,d4            ; New head pointer
        and.w d5,d4             ; Wrap around if necessary
        move.b d1,(a3,d4.w)     ; Store new byte
        move.w d4,cbHead(a3)    ; New head saved
        moveq #0,d0             ; One byte added
        bra.s abExit            ; Done, no errors.

abFullUp
        moveq #1,d0             ; Buffer full, can't add D1

abExit
        movem.w (a7)+,d1/d4-d5/a3 ; Restore working registers
        rts


;--------------------------------------------------------------
; Get Byte
;--------------------------------------------------------------
; Gets one byte from a circular buffer.
; 
; ENTRY:
;
; A3.L = Buffer to get from. (A3 = cbSize in the buffer.)
;
; EXIT:
;
; D0.L = Error code.
;      = 0 if the byte was retrieved from the buffer.
;      = 1 if the buffer is empty.
;
; D1.B = The retrieved byte, if the buffer was not empty.
;      = Preserved if the buffer was empty.
;
; All other registers are preserved.
;--------------------------------------------------------------
getByte
        movem.w d4-d6/a3,-(a7)  ; Save working registers

gbIsEmpty
        bsr.s isEmpty           ; Is the buffer empty?
        beq.s gbEmpty           ; Yes, bale out

        move.w (a3)+,d5         ; Size of buffer
        subq.w #1,d5            ; We need one less than size
        addq.l #2,a3            ; Skip over the head
        move.w (a3)+,d6         ; Get the tail?
        addq.w #1,d6            ; New tail pointer
        and.w d5,d6             ; Wrap around if necessary
        move.b (a3,d6.w),d1     ; Fetch byte
        move.w d6,cbTail(a3)    ; New tail saved
        moveq #0,d0             ; One byte retrieved
        bra.s gbExit            ; Done, no errors

gbEmpty
        moveq #1,d0             ; Buffer empty, can't retrieve

gbExit
        movem.w (a7)+,d4-d6/a3  ; Restore working registers
        rts


;--------------------------------------------------------------
; Is Full?
;--------------------------------------------------------------
; Checks if the buffer passed in A3 is full. A buffer is full 
; when (Head + 1) == Tail.
; 
; ENTRY:
;
; A3.L = Buffer to get from. (A3 -> cbSize in the buffer.)
;
; EXIT:
;
; D0.L = Error code.
;      = 0 if the buffer is full. Z set.
;      = 1 if the buffer is not full. Z clear.
;
; All other registers are preserved.
;--------------------------------------------------------------
isFull
        movem.l d4-d5/a3,-(a7)  ; Save the workers
        move.w (a3)+,d4         ; Get the buffer size
        subq.w #1,d4            ; Minus 1 for MOD
        move.w (a3)+,d5         ; Get the head offset
        addq.w #1,d5            ; Next head offset
        and.w d4,d5             ; MOD buffer size
        cmp.w (a3),d5           ; Same as tail?
        beq.s ifFull            ; Buffer is full
        moveq #1,d0             ; Not full
        bra.s ifExit            ; Bale out

ifFull        
        moveq #0,d0             ; Buffer is full

ifExit
        movem.l (a7)+,d4-d5/a3  ; Restore the workers
        rts


;--------------------------------------------------------------
; Is Empty?
;--------------------------------------------------------------
; Checks if the buffer passed in A3 is empty. A buffer is empty 
; when Head == Tail.
; 
; ENTRY:
;
; A3.L = Buffer to get from. (A3 = cbSize in the buffer.)
;
; EXIT:
;
; D0.L = Error code.
;      = 0 if the buffer is empty. Z set.
;      = 1 if the buffer is not empty. Z clear.
;
; All other registers are preserved.
;--------------------------------------------------------------
isEmpty
        cmp.w -cbHead(a3),-cbTail(a3)    ; Head = Tail? 
        beq.s ieEmpty                    ; Yes
        moveq #1,d0                      ; Not empty
        rts

ieEmpty
        moveq #0,d0                      ; No
        rts


;--------------------------------------------------------------
; Get Used
;--------------------------------------------------------------
; Returns the space used in a buffer. This is (size + head -
; tail) MOD size.
; 
; ENTRY:
;
; A3.L = Buffer to get from. (A3 = cbSize in the buffer.)
;
; EXIT:
;
; D0.L = Used space.
;      = 0 if the buffer is empty. Z set.
;      <> 0 = used space. Z clear.
;
; All other registers are preserved.
;--------------------------------------------------------------
getUsed
        movem.l d5/a3,-(a7)     ; Save the workers

guIsEmpty
        bsr.s isEmpty           ; Is buffer empty?
        beq.s guExit            ; Yes, D0 = 0, bale out

        move.w (a3)+,d0         ; Buffer size
        move.w d0,d5            ; Buffer size again
        subq.w #1,d5            ; For MOD
        add.w (a3)+,d0          ; Add on head
        sub.w (a3),d0           ; Minus tail
        andw.l d5,d0            ; MOD size

guExit
        movem.l (a7)+,d5/a3     ; Restore the workers
        rts


;--------------------------------------------------------------
; Get Free
;--------------------------------------------------------------
; Returns the space free in a buffer. This is size - 1 - used.
; 
; ENTRY:
;
; A3.L = Buffer to get from. (A3 = cbSize in the buffer.)
;
; EXIT:
;
; D0.L = Space used in the buffer. 
;      Z set if buffer is full.
;
; All other registers are preserved.
;--------------------------------------------------------------
getFree
        move.l a3,-(a7)         ; Save the worker

gfIsEmpty
        bsr.s getUsed           ; D0.W = used space
        neg.w d0                ; negative used size
        add.w (a3),d0           ; Add buffer size
        subq.w #1,d0            ; Minus the unusable byte

gfExit
        move.l (a7)+,a3         ; Restore the worker
        rts
