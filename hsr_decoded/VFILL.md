# VFILL — AP-120B microcode

- Library: **BAALIB**
- Args (NSPADS): **4**
- Entry uPC: **000** (octal)
- Microcode size: **6** instructions (48 bytes)

## Host-side PDP-11 stub

```

        .GLOBL VFILL ,APEX
VFILL : MOV (%5)+,%0
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
CODE:        6.
```

## AP-120B microcode disassembly

```
;   uPC | w1     w2     w3     w4    | symbolic
;  ----+-------+------+------+------+----------
  0000  040000 000000 000000 000060  SPMOV SPS=0,SPD=0; MEM[LDMA|INCMA]
  0001  040314 000000 000000 000000  SPMOV SPS=3,SPD=3
  0002  030204 000623 000000 000000  SPSUB SPS=2,SPD=1; JGE 23
  0003  001214 000000 000000 000000  SP_OP1 SPSF=12,SPD=3
  0004  020204 000657 005000 000360  SPADD SPS=2,SPD=1; JGT 17; MEM[WMD|RMD,LDMA|INCMA]
  0005  000000 000340 000000 000000  JFN 0
```
