# CVFILL — AP-120B microcode

- Library: **BAALIB**
- Args (NSPADS): **4**
- Entry uPC: **000** (octal)
- Microcode size: **8** instructions (64 bytes)

## Host-side PDP-11 stub

```

        .GLOBL CVFILL,APEX
CVFILL: MOV (%5)+,%0
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
NSPADS:      4.
SLIST:  .BLKW      4.
START:       0.
CODE:        8.
```

## AP-120B microcode disassembly

```
;   uPC | w1     w2     w3     w4    | symbolic
;  ----+-------+------+------+------+----------
  0000  040000 000000 000000 000060  SPMOV SPS=0,SPD=0; MEM[LDMA|INCMA]
  0001  030204 000000 000000 000000  SPSUB SPS=2,SPD=1
  0002  040314 000000 000000 000020  SPMOV SPS=3,SPD=3; MEM[INCMA]
  0003  000000 000624 045004 000000  JGE 24; DP[WX,XR=0/YR=0,XW=4/YW=0,BS=5]
  0004  020204 000000 003400 000360  SPADD SPS=2,SPD=1; DP[XR=4/YR=0,XW=0/YW=0,BS=3]; MEM[WMD|RMD,LDMA|INCMA]
  0005  001214 000000 005000 000320  SP_OP1 SPSF=12,SPD=3; MEM[WMD|RMD,INCMA]
  0006  000000 000656 000000 000000  JGT 16
  0007  000000 000340 000000 000000  JFN 0
```
