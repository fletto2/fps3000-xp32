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
  0000  040000 000000 000000 000060  SPMOV R0,R0; SETMA
  0001  030204 000000 000000 000000  SPSUB R2,R1
  0002  040314 000000 000000 000020  SPMOV R3,R3; INCMA
  0003  000000 000624 045004 000000  BEQ 24; DP[DPX1,DB=MD,XW=4]
  0004  020204 000000 003400 000360  SPADD R2,R1; DP[DB=DPX,XR=4]; WMD<DB; SETMA
  0005  001214 000000 005000 000320  DEC R3; DP[DB=MD]; WMD<DB; INCMA
  0006  000000 000656 000000 000000  BNE 16
  0007  000000 000340 000000 000000  RETURN 0
```
