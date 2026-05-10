; ----------------------------------------------------------------
; FPS-3000 SBC Monitor / Debugger / Host Interface
; Lives in the 22.4 KB of free ROM at $F0A825 onwards.
;
; Communicates over the on-board NEC µPD7201 SIO Channel A
; ($F70010 data, $F70012 control), which the FPS firmware never
; initialises or uses — so we have it all to ourselves.
;
; Triggered by jumping to monitor_entry (typically by patching
; one or more vectors).
; ----------------------------------------------------------------

SIO_A_DATA      equ     $F70010
SIO_A_CTRL      equ     $F70012

; Z80-SIO/i8274 RR0 status bits
RR0_RX_AVAIL    equ     0
RR0_TX_EMPTY    equ     2

; Monitor RAM workspace (using high-RAM area below VMOD_CTRL @ $1FFF0)
MON_REGS        equ     $1F000          ; saved D0..D7 then A0..A6 (15*4=60 bytes)
MON_SPC         equ     $1F03C          ; saved PC (long) — at MON_REGS + 60
MON_SSR         equ     $1F040          ; saved SR (word)
MON_LINEBUF     equ     $1F050          ; cmd line buffer (64 B)
MON_LASTADDR    equ     $1F090          ; last 'm' addr (long)

                org     $F0A826

;================================================================
; Cold entry — used when monitor is patched in as the reset PC.
; SP isn't loaded by the FPS reset path, so we install it ourselves
; before doing anything that pushes (like bsr).
;================================================================
monitor_cold:
                ori.w   #$2700,sr               ; supervisor, IPL=7
                lea     $1FFD0,sp               ; supervisor stack
                clr.l   MON_SPC
                move.w  #$2700,MON_SSR
                bra.b   monitor_common

;================================================================
; Exception entry — called as JMP target from patched vectors.
;
; If entered via an exception, the supervisor stack contains the
; standard 7-word frame (or 4-word for IRQ).  We save D0-D7/A0-A6
; into MON_REGS, then read the saved PC and SR from the stack.
;================================================================
monitor_entry:
                movem.l d0-d7/a0-a6,MON_REGS
                ; Top of stack: short frame = SR, PC.l ; long frame extra
                ; We don't know which — peek at SR's vector field
                move.w  (sp),MON_SSR            ; saved SR is at top
                move.l  2(sp),MON_SPC           ; saved PC follows
monitor_common:

                bsr.w   sio_init
                bsr.w   put_crlf
                bsr.w   put_crlf
                lea     banner_msg(pc),a0
                bsr.w   puts
                lea     entry_msg(pc),a0
                bsr.w   puts
                move.l  MON_SPC,d0
                bsr.w   puthex_long
                lea     sr_msg(pc),a0
                bsr.w   puts
                move.w  MON_SSR,d0
                bsr.w   puthex_word
                bsr.w   put_crlf

cmd_loop:
                lea     prompt_msg(pc),a0
                bsr.w   puts
                bsr.w   read_line               ; reads into MON_LINEBUF, term=0
                lea     MON_LINEBUF,a6          ; a6 = parse pointer
                bsr.w   skip_ws
                move.b  (a6),d0
                beq.b   cmd_loop                ; empty line

                cmpi.b  #'?',d0
                beq.w   cmd_help
                cmpi.b  #'h',d0
                beq.w   cmd_help
                cmpi.b  #'r',d0
                beq.w   cmd_regs
                cmpi.b  #'m',d0
                beq.w   cmd_mem
                cmpi.b  #'d',d0
                beq.w   cmd_dump
                cmpi.b  #'w',d0
                beq.w   cmd_write
                cmpi.b  #'g',d0
                beq.w   cmd_go
                cmpi.b  #'L',d0
                beq.w   cmd_load_srec
                cmpi.b  #'i',d0
                beq.w   cmd_info
                cmpi.b  #'!',d0
                beq.w   cmd_about

                lea     unknown_msg(pc),a0
                bsr.w   puts
                bra.w   cmd_loop

;----------------------------------------------------------------
; Help — print command list
;----------------------------------------------------------------
cmd_help:
                lea     help_msg(pc),a0
                bsr.w   puts
                bra.w   cmd_loop

;----------------------------------------------------------------
; About / Banner
;----------------------------------------------------------------
cmd_about:
                lea     banner_msg(pc),a0
                bsr.w   puts
                bra.w   cmd_loop

;----------------------------------------------------------------
; Show registers
;   format:
;     D0=12345678  D1=12345678  D2=12345678  D3=12345678
;     D4=12345678  D5=12345678  D6=12345678  D7=12345678
;     A0=12345678  A1=12345678  A2=12345678  A3=12345678
;     A4=12345678  A5=12345678  A6=12345678
;     PC=12345678  SR=1234
;----------------------------------------------------------------
cmd_regs:
                moveq   #0,d2                   ; reg index 0..14
.loop:
                moveq   #0,d3
                move.b  d2,d3
                cmpi.b  #8,d3
                blt.b   .is_d
                move.b  #'A',d0
                subi.b  #8,d3
                bra.b   .show
.is_d:
                move.b  #'D',d0
.show:
                bsr.w   putchar
                move.b  d3,d0
                addi.b  #'0',d0
                bsr.w   putchar
                move.b  #'=',d0
                bsr.w   putchar
                ; load reg from MON_REGS[d2*4]
                move.w  d2,d0
                lsl.w   #2,d0
                lea     MON_REGS,a0
                move.l  (a0,d0.w),d0
                bsr.w   puthex_long
                move.b  #' ',d0
                bsr.w   putchar
                bsr.w   putchar
                addq.b  #1,d2
                ; new line every 4 regs
                move.b  d2,d0
                andi.b  #3,d0
                bne.b   .nonl
                bsr.w   put_crlf
.nonl:
                cmpi.b  #15,d2
                blt.b   .loop
                bsr.w   put_crlf
                lea     pcmsg(pc),a0
                bsr.w   puts
                move.l  MON_SPC,d0
                bsr.w   puthex_long
                lea     srmsg(pc),a0
                bsr.w   puts
                move.w  MON_SSR,d0
                bsr.w   puthex_word
                bsr.w   put_crlf
                bra.w   cmd_loop

;----------------------------------------------------------------
; Memory display (default 16 bytes from last addr or parsed addr)
;   m            -> dump 16 bytes from MON_LASTADDR
;   m XXXXXX     -> set MON_LASTADDR, dump 16 bytes
;   m XXXXXX YY  -> dump YY bytes (hex count)
;----------------------------------------------------------------
cmd_mem:
                addq.l  #1,a6
                bsr.w   skip_ws
                move.b  (a6),d0
                beq.b   .use_last
                bsr.w   parse_hex
                tst.b   d1
                beq.w   cmd_err
                move.l  d0,MON_LASTADDR
.use_last:
                bsr.w   skip_ws
                moveq   #16,d2                  ; default count
                move.b  (a6),d0
                beq.b   .do
                bsr.w   parse_hex
                tst.b   d1
                beq.w   cmd_err
                move.l  d0,d2
                cmpi.l  #128,d2
                ble.b   .do
                moveq   #-128,d2
                neg.l   d2
.do:
                move.l  MON_LASTADDR,a4
                bsr.w   hexdump
                ; advance LASTADDR by count
                add.l   d2,MON_LASTADDR
                bra.w   cmd_loop

cmd_err:
                lea     hex_err(pc),a0
                bsr.w   puts
                bra.w   cmd_loop

;----------------------------------------------------------------
; Dump aliases mem command
;----------------------------------------------------------------
cmd_dump:
                bra.w   cmd_mem

;----------------------------------------------------------------
; Memory write:  w XXXXXX BB BB BB ...
;----------------------------------------------------------------
cmd_write:
                addq.l  #1,a6
                bsr.w   skip_ws
                bsr.w   parse_hex
                tst.b   d1
                beq.w   cmd_err
                move.l  d0,a4
.wloop:
                bsr.w   skip_ws
                move.b  (a6),d0
                beq.b   .done
                bsr.w   parse_hex
                tst.b   d1
                beq.w   cmd_err
                move.b  d0,(a4)+
                bra.b   .wloop
.done:
                lea     ok_msg(pc),a0
                bsr.w   puts
                bra.w   cmd_loop

;----------------------------------------------------------------
; Go — restore registers and RTE.  No address arg = use saved PC.
; "g XXXXXX" replaces the saved PC before resuming.
;----------------------------------------------------------------
cmd_go:
                addq.l  #1,a6
                bsr.w   skip_ws
                move.b  (a6),d0
                beq.b   .resume
                bsr.w   parse_hex
                tst.b   d1
                beq.w   cmd_err
                move.l  d0,MON_SPC
.resume:
                lea     resume_msg(pc),a0
                bsr.w   puts
                move.l  MON_SPC,d0
                bsr.w   puthex_long
                bsr.w   put_crlf
                ; rebuild stack frame and RTE
                move.l  MON_SPC,2(sp)
                move.w  MON_SSR,(sp)
                movem.l MON_REGS,d0-d7/a0-a6
                rte

;----------------------------------------------------------------
; Info — chassis state, ROM version, free RAM, etc.
;----------------------------------------------------------------
cmd_info:
                lea     info_msg(pc),a0
                bsr.w   puts
                bra.w   cmd_loop

;----------------------------------------------------------------
; Load S-record over the SIO (channel A).
; Each line consumed and validated; bytes go to addresses inside.
; Terminator: S8 / S9 record.
;----------------------------------------------------------------
cmd_load_srec:
                lea     load_msg(pc),a0
                bsr.w   puts
                clr.l   d4                      ; record count
                clr.l   d5                      ; byte count
.scan_S:
                bsr.w   getchar
                cmpi.b  #'S',d0
                bne.b   .scan_S                  ; skip until 'S'
                bsr.w   getchar                  ; record type
                cmpi.b  #'8',d0
                beq.w   .terminator
                cmpi.b  #'9',d0
                beq.w   .terminator
                cmpi.b  #'7',d0
                beq.w   .terminator
                cmpi.b  #'0',d0
                beq.w   .eat_eol                ; header — skip
                cmpi.b  #'1',d0
                blt.w   .scan_S
                cmpi.b  #'3',d0
                bgt.w   .scan_S
                ; data record S1 / S2 / S3
                move.b  d0,d6                   ; save type
                bsr.w   read_hex_byte
                move.l  d0,d2                   ; payload count (incl addr+cksum)
                clr.l   d3
                cmpi.b  #'3',d6
                beq.b   .a32
                cmpi.b  #'2',d6
                beq.b   .a24
                bra.b   .a16
.a32:
                bsr.w   read_hex_byte
                lsl.l   #8,d3
                or.b    d0,d3
                subq.b  #1,d2
.a24:
                bsr.w   read_hex_byte
                lsl.l   #8,d3
                or.b    d0,d3
                subq.b  #1,d2
.a16:
                bsr.w   read_hex_byte
                lsl.l   #8,d3
                or.b    d0,d3
                bsr.w   read_hex_byte
                lsl.l   #8,d3
                or.b    d0,d3
                subq.b  #2,d2
                subq.b  #1,d2                   ; -1 for checksum
                move.l  d3,a4                   ; dest pointer
.dloop:
                tst.b   d2
                ble.b   .endrec
                bsr.w   read_hex_byte
                move.b  d0,(a4)+
                addq.l  #1,d5
                subq.b  #1,d2
                bra.b   .dloop
.endrec:
                bsr.w   read_hex_byte           ; consume cksum byte
                addq.l  #1,d4
                move.b  #'.',d0
                bsr.w   putchar
                bra.w   .eat_eol
.eat_eol:
                bsr.w   getchar
                cmpi.b  #13,d0
                beq.w   .scan_S
                cmpi.b  #10,d0
                beq.w   .scan_S
                bra.b   .eat_eol
.terminator:
                ; finish the terminator's line
.t_eol:
                bsr.w   getchar
                cmpi.b  #13,d0
                beq.b   .t_done
                cmpi.b  #10,d0
                beq.b   .t_done
                bra.b   .t_eol
.t_done:
                bsr.w   put_crlf
                lea     load_done_msg(pc),a0
                bsr.w   puts
                move.l  d4,d0
                bsr.w   puthex_long
                lea     load_bytes_msg(pc),a0
                bsr.w   puts
                move.l  d5,d0
                bsr.w   puthex_long
                bsr.w   put_crlf
                bra.w   cmd_loop

;================================================================
; Helpers
;================================================================

; ---- hexdump d2 bytes starting at a4 ----
hexdump:
                move.l  d2,d6                   ; bytes remaining
.line:
                ; Print address
                move.l  a4,d0
                bsr.w   puthex_long
                move.b  #':',d0
                bsr.w   putchar
                move.b  #' ',d0
                bsr.w   putchar
                ; row count = min(16, d6)
                moveq   #16,d4
                cmp.l   d4,d6
                bge.b   .full
                move.l  d6,d4
.full:
                move.l  a4,a5                   ; row start
                ; print d4 hex bytes
                move.l  d4,d3
                tst.l   d3
                beq.b   .pad
.hex:
                move.b  (a4)+,d0
                bsr.w   puthex_byte
                move.b  #' ',d0
                bsr.w   putchar
                subq.l  #1,d3
                bne.b   .hex
.pad:
                ; pad to 16 hex slots
                moveq   #16,d5
                sub.l   d4,d5
                tst.l   d5
                beq.b   .ascii
.padl:
                move.b  #' ',d0
                bsr.w   putchar
                bsr.w   putchar
                bsr.w   putchar
                subq.l  #1,d5
                bne.b   .padl
.ascii:
                move.b  #'|',d0
                bsr.w   putchar
                move.l  d4,d3
                tst.l   d3
                beq.b   .ascii_end
.ascii_l:
                move.b  (a5)+,d0
                cmpi.b  #' ',d0
                blt.b   .dot
                cmpi.b  #126,d0
                bgt.b   .dot
                bra.b   .pchar
.dot:
                move.b  #'.',d0
.pchar:
                bsr.w   putchar
                subq.l  #1,d3
                bne.b   .ascii_l
.ascii_end:
                move.b  #'|',d0
                bsr.w   putchar
                bsr.w   put_crlf
                sub.l   d4,d6
                bgt.w   .line
                rts

; ---- read_line: read line from SIO into MON_LINEBUF, term=0 ----
read_line:
                lea     MON_LINEBUF,a0
                moveq   #62,d2                  ; max len
.rloop:
                bsr.w   getchar
                cmpi.b  #13,d0                  ; CR
                beq.b   .end
                cmpi.b  #10,d0                  ; LF
                beq.b   .end
                cmpi.b  #8,d0                   ; BS
                beq.b   .bs
                cmpi.b  #127,d0                 ; DEL
                beq.b   .bs
                bsr.w   putchar                 ; echo
                move.b  d0,(a0)+
                dbra    d2,.rloop
.end:
                clr.b   (a0)
                bsr.w   put_crlf
                rts
.bs:
                cmpa.l  #MON_LINEBUF,a0
                beq.b   .rloop                  ; empty - ignore
                subq.l  #1,a0
                addq.l  #1,d2
                move.b  #8,d0
                bsr.w   putchar
                move.b  #' ',d0
                bsr.w   putchar
                move.b  #8,d0
                bsr.w   putchar
                bra.b   .rloop

; ---- skip_ws: skip whitespace at (a6) ----
skip_ws:
.lp:            move.b  (a6),d0
                cmpi.b  #' ',d0
                beq.b   .adv
                cmpi.b  #9,d0                   ; tab
                beq.b   .adv
                rts
.adv:           addq.l  #1,a6
                bra.b   .lp

; ---- parse_hex: parse hex number at (a6) into d0; d1=1 ok, 0 err ----
;                 advances a6 past digits
parse_hex:
                clr.l   d0
                clr.b   d1                      ; success flag
                clr.b   d3                      ; digit count
.lp:
                move.b  (a6),d2
                cmpi.b  #'0',d2
                blt.b   .end
                cmpi.b  #'9',d2
                ble.b   .dig
                cmpi.b  #'A',d2
                blt.b   .end
                cmpi.b  #'F',d2
                ble.b   .upper
                cmpi.b  #'a',d2
                blt.b   .end
                cmpi.b  #'f',d2
                bgt.b   .end
                subi.b  #'a'-10,d2
                bra.b   .acc
.upper:
                subi.b  #'A'-10,d2
                bra.b   .acc
.dig:
                subi.b  #'0',d2
.acc:
                lsl.l   #4,d0
                andi.b  #$0F,d2
                or.b    d2,d0
                addq.l  #1,a6
                addq.b  #1,d3
                bra.b   .lp
.end:
                tst.b   d3
                beq.b   .err
                moveq   #1,d1
                rts
.err:
                clr.b   d1
                rts

; ---- read_hex_byte: read 2 hex chars from SIO, return byte in d0 ----
read_hex_byte:
                move.l  d2,-(sp)                ; preserve d2 (caller may use it)
                bsr.w   read_hex_nibble
                lsl.b   #4,d0
                move.b  d0,d2
                bsr.w   read_hex_nibble
                or.b    d2,d0
                move.l  (sp)+,d2
                rts

read_hex_nibble:
                bsr.w   getchar
                cmpi.b  #'9',d0
                bgt.b   .alpha
                subi.b  #'0',d0
                rts
.alpha:
                cmpi.b  #'F',d0
                bgt.b   .lower
                subi.b  #'A'-10,d0
                rts
.lower:
                subi.b  #'a'-10,d0
                rts

; ---- SIO init for 9600 8N1, RX+TX enabled, no IRQs ----
sio_init:
                ; Channel reset
                move.b  #$18,SIO_A_CTRL         ; WR0: cmd 3 = chan reset
                nop
                nop
                nop
                nop
                ; WR4: x16 clk, 1 stop, no parity
                move.b  #$04,SIO_A_CTRL         ; WR0: ptr to WR4
                move.b  #$44,SIO_A_CTRL
                ; WR3: 8 bits/RX char, RX enable
                move.b  #$03,SIO_A_CTRL         ; WR0: ptr to WR3
                move.b  #$C1,SIO_A_CTRL
                ; WR5: 8 bits/TX char, TX enable, DTR, RTS
                move.b  #$05,SIO_A_CTRL         ; WR0: ptr to WR5
                move.b  #$EA,SIO_A_CTRL
                rts

; ---- putchar: send byte in d0 over SIO chA ----
putchar:
                btst.b  #RR0_TX_EMPTY,SIO_A_CTRL
                beq.b   putchar
                move.b  d0,SIO_A_DATA
                rts

; ---- getchar: receive byte from SIO chA into d0 ----
getchar:
                btst.b  #RR0_RX_AVAIL,SIO_A_CTRL
                beq.b   getchar
                move.b  SIO_A_DATA,d0
                rts

; ---- puts: print null-terminated string at (a0) ----
puts:
                move.b  (a0)+,d0
                beq.b   .end
                bsr.w   putchar
                bra.b   puts
.end:
                rts

put_crlf:
                move.b  #13,d0
                bsr.w   putchar
                move.b  #10,d0
                bra.w   putchar

puthex_nibble:
                andi.b  #$0F,d0
                cmpi.b  #10,d0
                blt.b   .num
                addi.b  #'A'-10,d0
                bra.w   putchar
.num:
                addi.b  #'0',d0
                bra.w   putchar

puthex_byte:
                move.l  d0,-(sp)
                lsr.b   #4,d0
                bsr.w   puthex_nibble
                move.l  (sp)+,d0
                bra.w   puthex_nibble

puthex_word:
                rol.w   #8,d0
                bsr.w   puthex_byte
                rol.w   #8,d0
                bra.w   puthex_byte

puthex_long:
                swap    d0
                bsr.w   puthex_word
                swap    d0
                bra.w   puthex_word

;================================================================
; Strings
;================================================================
banner_msg:
                dc.b    13,10
                dc.b    "==================================",13,10
                dc.b    " FPS-3000 SBC Monitor / Debugger",13,10
                dc.b    " Lives in 22.4 KB free ROM @F0A825",13,10
                dc.b    " Talks via SIO chA (F70010/F70012)",13,10
                dc.b    "==================================",13,10,0

entry_msg:      dc.b    "entered at PC=$",0
sr_msg:         dc.b    "  SR=$",0

prompt_msg:     dc.b    "fps3k> ",0
unknown_msg:    dc.b    "?  Type 'h' for help.",13,10,0

help_msg:
                dc.b    "Commands:",13,10
                dc.b    "  r              show registers",13,10
                dc.b    "  m AAAA [NN]    dump NN bytes (default 16) at AAAA",13,10
                dc.b    "  d AAAA [NN]    same as m",13,10
                dc.b    "  w AAAA BB BB.. write bytes to AAAA",13,10
                dc.b    "  g [AAAA]       resume execution (optionally at AAAA)",13,10
                dc.b    "  L              load Motorola S-records over SIO",13,10
                dc.b    "  i              chassis info",13,10
                dc.b    "  !              show banner",13,10
                dc.b    "  h, ?           this help",13,10,0

ok_msg:         dc.b    "ok",13,10,0
hex_err:        dc.b    "?hex",13,10,0
resume_msg:     dc.b    "resume @$",0
load_msg:       dc.b    "send S-records, S8/S9 ends:",13,10,0
load_done_msg:  dc.b    13,10,"loaded $",0
load_bytes_msg: dc.b    " records, $",0

info_msg:
                dc.b    "Free ROM: 22489 bytes (F0A825-F0FFFF)",13,10
                dc.b    "RAM:      128 KB (000000-01FFFF)",13,10
                dc.b    "ROM:      64 KB (F00000-F0FFFF)",13,10
                dc.b    "AP I/F:   FF0000-FF00FF",13,10
                dc.b    "XLTR:     FF0200-FF025F",13,10
                dc.b    "Mailbox:  700000-70003F",13,10,0

pcmsg:          dc.b    "PC=$",0
srmsg:          dc.b    "  SR=$",0

                even
monitor_end:
