# XDAREA — AP-120B microcode

- Library: **BABLIB**
- Args (NSPADS): **2**
- Entry uPC: **000** (octal)
- Microcode size: **3** instructions (24 bytes)

## Host-side PDP-11 stub

```

        .GLOBL XDAREA,APEX
XDAREA: MOV (%5)+,%0
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
CODE:        3.
```

## AP-120B microcode disassembly

```
;   uPC | w1     w2     w3     w4    | symbolic
;  ----+-------+------+------+------+----------
  0000  040003 107000 006000 000000  SPMOV SPS=0,SPD=0; FANOT.B<DB,TM>
  0001  001677 144000 041004 000000  SP_OP1 SPSF=16,SPD=17; FANOT.B<FA,FA>; DP[WX,XR=0/YR=0,XW=4/YW=0,BS=1]
  0002  040104 000340 003400 000360  SPMOV SPS=1,SPD=1; JFN 0; DP[XR=4/YR=0,XW=0/YW=0,BS=3]; MEM[WMD|RMD,LDMA|INCMA]
```
