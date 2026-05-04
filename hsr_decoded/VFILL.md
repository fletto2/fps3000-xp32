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
  0000  040000 000000 000000 000060  SPMOV R0,R0; SETMA
  0001  040314 000000 000000 000000  SPMOV R3,R3
  0002  030204 000623 000000 000000  SPSUB R2,R1; BEQ 23
  0003  001214 000000 000000 000000  DEC R3
  0004  020204 000657 005000 000360  SPADD R2,R1; BNE 17; DP[DB=MD]; WMD<DB; SETMA
  0005  000000 000340 000000 000000  RETURN 0
```
