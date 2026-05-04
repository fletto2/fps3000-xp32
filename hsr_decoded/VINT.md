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
  0000  040000 000000 000000 000060  SPMOV R0,R0; SETMA
  0001  030310 000000 000000 000000  SPSUB R3,R2
  0002  020100 000000 000000 000060  SPADD R1,R0; SETMA
  0003  040420 024000 000000 000000  SPMOV R4,R4; FIXT A2=MD
  0004  000001 100624 000000 000000  FADD A1=NC,A2=NC; BEQ 24
  0005  020101 151000 000000 000060  SPADD R1,R0; FADD A1=ZERO,A2=FA; SETMA
  0006  001220 024000 000000 000000  DEC R4; FIXT A2=MD
  0007  020311 100656 000000 000160  SPADD R3,R2; FADD A1=NC,A2=NC; BNE 16; WMD<FA; SETMA
  0010  000000 000340 000000 000000  RETURN 0
```
