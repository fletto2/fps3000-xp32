# VINT — AP-120B microcode

- Library: **BAALIB**
- Args (NSPADS): **5**
- Entry uPC: **000** (octal)
- Microcode size: **9** instructions (72 bytes)

## Host-side PDP-11 stub

```

        .GLOBL VINT  ,APEX
VINT  : MOV (%5)+,%0
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
  0000  040000 000000 000000 000060  SPMOV SPS=0,SPD=0; MEM[LDMA|INCMA]
  0001  030310 000000 000000 000000  SPSUB SPS=3,SPD=2
  0002  020100 000000 000000 000060  SPADD SPS=1,SPD=0; MEM[LDMA|INCMA]
  0003  040420 024000 000000 000000  SPMOV SPS=4,SPD=4
  0004  000001 100624 000000 000000  FAB-A<DB,DB>; JGE 24
  0005  020101 151000 000000 000060  SPADD SPS=1,SPD=0; FAB-A<FM,DPX>; MEM[LDMA|INCMA]
  0006  001220 024000 000000 000000  SP_OP1 SPSF=12,SPD=4
  0007  020311 100656 000000 000160  SPADD SPS=3,SPD=2; FAB-A<DB,DB>; JGT 16; MEM[WMD,LDMA|INCMA]
  0010  000000 000340 000000 000000  JFN 0
```
