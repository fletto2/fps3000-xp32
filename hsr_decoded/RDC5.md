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
  0000  000003 107000 002000 000002  LDREG.LDDA; DP[DB=VALUE]; #000002
  0001  000003 144000 041004 000000  INOUT.IN; DP[DPX1,DB=INBS,XW=4]
  0002  001674 000000 003400 000000  LDSPI R17; DP[DB=DPX,XR=4]
  0003  001670 000000 002000 002000  LDSPI R16; DP[DB=VALUE]; #002000
  0004  051674 000000 000000 000000  SPAND R16,R17
  0005  000000 000622 000000 000000  BEQ 22
  0006  001674 000000 002000 000001  LDSPI R17; DP[DB=VALUE]; #000001
  0007  041774 000000 046004 000000  SPMOV R17,R17; DP[DPX1,DB=SPFN,XW=4]
  0010  040000 000340 003400 000360  SPMOV R0,R0; RETURN 0; DP[DB=DPX,XR=4]; WMD<DB; SETMA
```
