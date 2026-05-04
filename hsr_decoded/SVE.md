# SVE — AP-120B microcode

- Library: **BAALIB**
- Args (NSPADS): **4**
- Entry uPC: **000** (octal)
- Microcode size: **7** instructions (56 bytes)

## Host-side PDP-11 stub

```

        .GLOBL SVE   ,APEX
SVE   : MOV (%5)+,%0
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
CODE:        7.
```

## AP-120B microcode disassembly

```
;   uPC | w1     w2     w3     w4    | symbolic
;  ----+-------+------+------+------+----------
  0000  040000 000000 000000 000060  SPMOV SPS=0,SPD=0; MEM[LDMA|INCMA]
  0001  040314 000000 000000 000000  SPMOV SPS=3,SPD=3
  0002  020101 155623 000000 000060  SPADD SPS=1,SPD=0; FAB-A<FM,FM>; JGE 23; MEM[LDMA|INCMA]
  0003  001215 100000 045004 000000  SP_OP1 SPSF=12,SPD=3; FAB-A<DB,DB>; DP[WX,XR=0/YR=0,XW=4/YW=0,BS=5]
  0004  020101 121657 000400 000060  SPADD SPS=1,SPD=0; FAB-A<DPY,DPX>; JGT 17; DP[XR=4/YR=0,XW=0/YW=0,BS=0]; MEM[LDMA|INCMA]
  0005  000001 100000 000000 000000  FAB-A<DB,DB>
  0006  040210 000340 000000 000160  SPMOV SPS=2,SPD=2; JFN 0; MEM[WMD,LDMA|INCMA]
```
