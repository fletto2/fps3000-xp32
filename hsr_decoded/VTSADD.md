# VTSADD — AP-120B microcode

- Library: **BAALIB**
- Args (NSPADS): **6**
- Entry uPC: **000** (octal)
- Microcode size: **9** instructions (72 bytes)

## Host-side PDP-11 stub

```

        .GLOBL VTSADD,APEX
VTSADD: MOV (%5)+,%0
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
NSPADS:      6.
SLIST:  .BLKW      6.
START:       0.
CODE:        9.
```

## AP-120B microcode disassembly

```
;   uPC | w1     w2     w3     w4    | symbolic
;  ----+-------+------+------+------+----------
  0000  040000 000000 000000 000060  SPMOV R0,R0; SETMA
  0001  040524 000000 000000 000000  SPMOV R5,R5
  0002  040210 000626 000000 000003  SPMOV R2,R2; BEQ 26; SETTMA
  0003  020100 000000 000000 000060  SPADD R1,R0; SETMA
  0004  030415 144000 000000 000000  SPSUB R4,R3; FADD A1=TM,A2=MD
  0005  020100 000000 000000 000060  SPADD R1,R0; SETMA
  0006  001225 144000 000000 000000  DEC R5; FADD A1=TM,A2=MD
  0007  020414 000656 000000 000160  SPADD R4,R3; BNE 16; WMD<FA; SETMA
  0010  000000 000340 000000 000000  RETURN 0
```
