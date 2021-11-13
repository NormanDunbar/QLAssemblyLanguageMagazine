;--------------------------------------------------------------
; Test Harness
;--------------------------------------------------------------
; A quick and dirty test of the cBuffers_asm code. It will:
;
; 1. Request a buffer of 5 bytes, but will get one of 8.
; 2. Write ABCDEFG to it, filling it up.
; 3. Test if it is full, D0 = 0 means it is.
; 4. Read back all the data, ABCDEFG, emptying the buffer.
; 5. Test if it is empty, D0 = 0 if so.
; 6. Free the buffer.
;
; The code here was simply traced through QMON2 to be sure that
; everything was working. It was. Error checking is few and far
; between due to the use of QMON2. 
;
; Feel free to use this as a starter if you ever need to use
; circular buffers (FIFO) in your code.
;--------------------------------------------------------------
start
        moveq #5,d0             ; Will round up to 8
        bsr allocateBuffer      ; Create buffer

        moveq #'A',d1           ; First byte
addLoop
        bsr addByte             ; Add 1 byte
        bne.s addEnd            ; Buffer full?
        addq #1,d1              ; No, next byte
        bra.s addLoop           ; And again

addEnd
        bsr isFull              ; D0 = 0 then full

getLoop
        bsr getByte             ; Get 1 byte
        bne.s getEnd            ; Buffer empty?
        bra.s getLoop           ; No, next byte

getEnd
        bsr isEmpty             ; D0 = 0 then empty


        bsr freeBuffer          ; Delete buffer

        clr.l d0                ; For SuperBASIC
        rts

        ; Pull in the cBuffer_asm code.
        in "ram1_cBuffers_asm"
