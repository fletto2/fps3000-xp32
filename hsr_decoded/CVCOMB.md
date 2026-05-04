# CVCOMB — AP-120B microcode

- Library: **BAALIB**
- Args (NSPADS): **7**
- Entry uPC: **000** (octal)
- Microcode size: **10** instructions (80 bytes)

## Host-side PDP-11 stub

```

        .GLOBL CVCOMB,APEX
CVCOMB: MOV (%5)+,%0
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
NSPADS:      7.
SLIST:  .BLKW      7.
START:       0.
CODE:       10.
```

## AP-120B microcode disassembly

```
;   uPC | w1     w2     w3     w4    | symbolic
;  ----+-------+------+------+------+----------
  0000  030100 000000 000000 000000  SPSUB R1,R0
  0001  030310 000000 000000 000000  SPSUB R3,R2
  0002  030520 000000 000000 000000  SPSUB R5,R4
  0003  040630 000000 000000 000000  SPMOV R6,R6
  0004  020100 000625 000000 000060  SPADD R1,R0; BEQ 25; SETMA
  0005  020310 000000 000000 000060  SPADD R3,R2; SETMA
  0006  000000 000000 000000 000000  (zero word)
  0007  020520 000000 005000 000360  SPADD R5,R4; DP[DB=MD]; WMD<DB; SETMA
  0010  001230 000114 005000 000320  DEC R6; BR 14; DP[DB=MD]; WMD<DB; INCMA
  0011  000000 000340 000000 000000  RETURN 0
```
