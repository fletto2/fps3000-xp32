# VSQ — AP-120B microcode

- Library: **BAALIB**
- Args (NSPADS): **5**
- Entry uPC: **000** (octal)
- Microcode size: **9** instructions (72 bytes)

## Host-side PDP-11 stub

```

        .GLOBL VSQ   ,APEX
VSQ   : MOV (%5)+,%0
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
NSPADS:      5.
SLIST:  .BLKW      5.
START:       0.
CODE:        9.
```

## AP-120B microcode disassembly

```
;   uPC | w1     w2     w3     w4    | symbolic
;  ----+-------+------+------+------+----------
  0000  040000 000000 000000 000060  SPMOV R0,R0; SETMA
  0001  030310 000000 000000 000000  SPSUB R3,R2
  0002  020100 000000 000000 000060  SPADD R1,R0; SETMA
  0003  040420 000000 045004 000000  SPMOV R4,R4; DP[DPX1,DB=MD,XW=4]
  0004  000000 000624 000400 012400  FMUL DPX,DPX; BEQ 24; DP[DB=ZERO,XR=4]
  0005  020100 000000 045004 017460  SPADD R1,R0; FMUL TM,MD; DP[DPX1,DB=MD,XW=4]; SETMA
  0006  001220 000000 000400 012400  DEC R4; FMUL DPX,DPX; DP[DB=ZERO,XR=4]
  0007  020310 000656 000000 000260  SPADD R3,R2; BNE 16; WMD<FM; SETMA
  0010  000000 000340 000000 000000  RETURN 0
```
