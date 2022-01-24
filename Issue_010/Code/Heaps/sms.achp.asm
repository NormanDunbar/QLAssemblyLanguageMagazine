sms.achp    equ $18
sms.rchp    equ $19

start
    moveq #sms.achp,d0
    moveq #10,d1
    moveq #-1,d2
    moveq #0,d3
    trap #1
    tst.l d0
    beq.s alloc
    rts

alloc
    move.l a0,a5
    moveq #sms.achp,d0
    moveq #10,d1
    moveq #-1,d2
    moveq #0,d3
    trap #1
    tst.l d0
    beq.s dealloc
    rts

dealloc
    moveq #sms.rchp,d0
    trap #1
    move.l a5,a0
    moveq #sms.rchp,d0
    trap #1
    rts

