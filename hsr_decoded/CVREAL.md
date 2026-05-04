# CVREAL — AP-120B microcode

- Library: **BAALIB**
- Args (NSPADS): **5**
- Entry uPC: **000** (octal)
- Microcode size: **9** instructions (72 bytes)

## Host-side PDP-11 stub

```

        .GLOBL CVREAL,APEX
CVREAL: MOV (%5)+,%0
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
  0000  030100 000000 000000 000000  SPSUB R1,R0
  0001  030310 000000 000000 000000  SPSUB R3,R2
  0002  001110 000000 000000 000000  INC R2
  0003  040420 000000 000000 000000  SPMOV R4,R4
  0004  020100 000624 000000 000060  SPADD R1,R0; BEQ 24; SETMA
  0005  000000 000000 000000 000000  (zero word)
  0006  020310 000000 000000 000360  SPADD R3,R2; WMD<DB; SETMA
  0007  001220 000115 005000 000340  DEC R4; BR 15; DP[DB=MD]; WMD<DB; DECMA
  0010  000000 000340 000000 000000  RETURN 0
```
