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
  0000  040000 000000 000000 000060  SPMOV R0,R0; SETMA
  0001  040314 000000 000000 000000  SPMOV R3,R3
  0002  020101 155623 000000 000060  SPADD R1,R0; FADD A1=ZERO,A2=ZERO; BEQ 23; SETMA
  0003  001215 100000 045004 000000  DEC R3; FADD A1=NC,A2=NC; DP[DPX1,DB=MD,XW=4]
  0004  020101 121657 000400 000060  SPADD R1,R0; FADD A1=DPX,A2=FA; BNE 17; DP[DB=ZERO,XR=4]; SETMA
  0005  000001 100000 000000 000000  FADD A1=NC,A2=NC
  0006  040210 000340 000000 000160  SPMOV R2,R2; RETURN 0; WMD<FA; SETMA
```
