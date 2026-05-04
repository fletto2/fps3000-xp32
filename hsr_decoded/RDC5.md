# RDC5 — AP-120B microcode

- Library: **BABLIB**
- Args (NSPADS): **1**
- Entry uPC: **000** (octal)
- Microcode size: **9** instructions (72 bytes)

## Host-side PDP-11 stub

```

        .GLOBL RDC5  ,APEX
RDC5  : MOV (%5)+,%0
        BEQ NONE
        MOV #SLIST,%1
LOOP:   MOV @(%5)+,(%1)+
        DEC %0
        BNE LOOP
NONE:   MOV #PARAM,%5
        JSR %7,APEX
        RTS %7
PARAM:  4
        CODE
        START
        SLIST
        NSPADS
NSPADS:      1.
SLIST:  .BLKW      1.
START:       0.
CODE:        9.
```

## AP-120B microcode disassembly

```
;   uPC | w1     w2     w3     w4    | symbolic
;  ----+-------+------+------+------+----------
  0000  000003 107000 002000 000002  FANOT.B<DB,TM>; MEM[TMA=2]
  0001  000003 144000 041004 000000  FANOT.B<FA,FA>; DP[WX,XR=0/YR=0,XW=4/YW=0,BS=1]
  0002  001674 000000 003400 000000  SP_OP1 SPSF=16,SPD=17; DP[XR=4/YR=0,XW=0/YW=0,BS=3]
  0003  001670 000000 002000 002000  SP_OP1 SPSF=16,SPD=16
  0004  051674 000000 000000 000000  SPAND SPS=16,SPD=17
  0005  000000 000622 000000 000000  JGE 22
  0006  001674 000000 002000 000001  SP_OP1 SPSF=16,SPD=17; MEM[TMA=1]
  0007  041774 000000 046004 000000  SPMOV SPS=17,SPD=17; DP[WX,XR=0/YR=0,XW=4/YW=0,BS=6]
  0010  040000 000340 003400 000360  SPMOV SPS=0,SPD=0; JFN 0; DP[XR=4/YR=0,XW=0/YW=0,BS=3]; MEM[WMD|RMD,LDMA|INCMA]
```
