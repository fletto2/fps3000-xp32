# DAWRIT — AP-120B microcode

- Library: **BABLIB**
- Args (NSPADS): **2**
- Entry uPC: **000** (octal)
- Microcode size: **2** instructions (16 bytes)

## Host-side PDP-11 stub

```

        .GLOBL DAWRIT,APEX
DAWRIT: MOV (%5)+,%0
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
NSPADS:      2.
SLIST:  .BLKW      2.
START:       0.
CODE:        2.
```

## AP-120B microcode disassembly

```
;   uPC | w1     w2     w3     w4    | symbolic
;  ----+-------+------+------+------+----------
  0000  040003 107000 006000 000000  SPMOV SPS=0,SPD=0; FANOT.B<DB,TM>
  0001  040107 140340 006000 000000  SPMOV SPS=1,SPD=1; FANOT.B<FA,DB>; JFN 0
```
