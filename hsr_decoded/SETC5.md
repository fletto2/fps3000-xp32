# SETC5 — AP-120B microcode

- Library: **BABLIB**
- Args (NSPADS): **0**
- Entry uPC: **000** (octal)
- Microcode size: **1** instructions (8 bytes)

## Host-side PDP-11 stub

```

        .GLOBL SETC5 ,APEX
SETC5 : MOV (%5)+,%0
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
NSPADS:      0.
SLIST:  .BLKW      0.
START:       0.
CODE:        1.
```

## AP-120B microcode disassembly

```
;   uPC | w1     w2     w3     w4    | symbolic
;  ----+-------+------+------+------+----------
  0000  000003 172340 000000 000000  FANOT.B<TM,DPY>; JFN 0
```
