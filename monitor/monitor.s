; ----------------------------------------------------------------
; FPS-3000 SBC Monitor / Debugger / Host Interface
; Lives in the 21.9 KB of free ROM at $F0A826 onwards.
;
; Communicates over the on-board NEC µPD7201 SIO Channel A
; ($F70011 data, $F70015 control), which the FPS firmware never
; initialises or uses — so we have it all to ourselves.
;
; Triggered by jumping to monitor_entry (typically by patching
; one or more vectors).
; ----------------------------------------------------------------

; µPD7201 register addresses, per Motorola's VERSAdos source for this
; board — verdos06/SDLCPRI/NEC7201.EQ, in rms68k_source.SA:
;
;     NEC7201 EQU $F70011      <- ODD base: the chip is on D0-D7 / LDS
;     ch A data    = base+0 = $F70011
;     ch B data    = base+2 = $F70013
;     ch A control = base+4 = $F70015
;     ch B control = base+6 = $F70017
;
; Registers are grouped by FUNCTION (both data, then both control), not
; interleaved per channel.  Earlier versions of this file used $F70010
; and $F70012, which is wrong twice over: even addresses assert UDS only
; and this chip never answers them (-> no DTACK -> BERR), and the odd
; byte of that second slot, $F70013, is channel B's DATA register, not
; channel A's control.  Corroborated by verdos06/_root/NEC7201.EQ
; (CREG/SREG = 0, DREG = -4) and by the ROM's own MC6840 access at odd
; $F70001/$F70003 in PTMInit (F09176).
SIO_A_DATA      equ     $F70011
SIO_A_CTRL      equ     $F70015
SIO_B_DATA      equ     $F70013
SIO_B_CTRL      equ     $F70017

; Z80-SIO/i8274 RR0 status bits
RR0_RX_AVAIL    equ     0
ESC             equ     $1B             ; abort character for L (see getchar)
RR0_TX_EMPTY    equ     2

; Monitor RAM workspace.
;
; This used to live at $1F000, which was wrong in two ways at once:
;
;   * $1F000 is INSIDE the AU WCS staging buffer ($10000-$1FFFF), so
;     loading a full 64 KB bank — the whole point of the L command —
;     would overwrite the monitor's own saved registers, line buffer and
;     stack partway through the transfer.
;   * The factory firmware also writes live data there.  A RAM dump after
;     booting the stock ROM to the scheduler idle loop shows 40 nonzero
;     bytes in $1F000-$1F09F, so entering via the panic vector clobbered
;     firmware state and quietly compromised `g`.
;
; Measured alternative: dumping RAM after a full stock boot shows
; $01200-$0FFFF — 60,928 bytes — completely untouched by the firmware.
; The workspace and the cold-path stack both now live there, which puts
; them below the staging buffer AND out of the firmware's way, fixing
; both problems at once.
;
; Caveat on the evidence: "untouched after booting to idle" is not proof
; that RMS68K never allocates there under load — it is a measurement of
; this chassis reaching its idle loop, not a guarantee.  It is strictly
; better than the old placement, which was measurably in use.
MON_BASE        equ     $0F800
MON_REGS        equ     MON_BASE        ; saved D0..D7 then A0..A6 (15*4=60 bytes)
MON_SPC         equ     MON_BASE+$3C    ; saved PC (long) — at MON_REGS + 60
MON_SSR         equ     MON_BASE+$40    ; saved SR (word)
MON_CMDSP       equ     MON_BASE+$44    ; sp as it stands at the top of cmd_loop
                                        ;   (long).  The abort anchor: getchar
                                        ;   can be three frames deep inside L
                                        ;   (cmd_load_srec -> read_hex_byte ->
                                        ;   read_hex_nibble -> getchar), so an
                                        ;   abort cannot rts out.  It must NOT
                                        ;   simply `lea MON_STACK,sp` either:
                                        ;   monitor_common deliberately runs on
                                        ;   the stack it was entered with, and
                                        ;   the firmware's exception frame is
                                        ;   still beneath it -- that frame is
                                        ;   what `g` resumes through.  Anchoring
                                        ;   on cmd_loop's own sp unwinds exactly
                                        ;   as far as the prompt and no further.
MON_MAGIC       equ     MON_BASE+$4C    ; long.  "MON1" once ws_init has run.
                                        ;   The panic image never runs cold_init,
                                        ;   so on real hardware every workspace
                                        ;   field starts as never-written DRAM --
                                        ;   random, not the zeroes the emulator
                                        ;   shows.  This is the one-shot flag that
                                        ;   says "the workspace is real".  Chosen
                                        ;   as ASCII so it is recognisable in a RAM
                                        ;   dump; a random long matching it is 1 in
                                        ;   4 billion.
MON_MAGIC_V     equ     $4D4F4E31       ; 'MON1'
MON_ABORT       equ     MON_BASE+$48    ; nonzero: ESC seen in getchar aborts to
                                        ;   cmd_loop.  Set only for the duration
                                        ;   of L, so ESC stays an ordinary
                                        ;   (ignored) character at the prompt.
MON_LINEBUF     equ     MON_BASE+$50    ; cmd line buffer (64 B)
MON_LASTADDR    equ     MON_BASE+$90    ; last 'm' addr (long)
MON_GRP0        equ     MON_BASE+$94    ; frame kind: 0 = short (4-word,
                                        ;   resumable), 1 = group-0 (7-word
                                        ;   bus/addr error), $FF = no frame
                                        ;   at all (cold entry)
MON_NEST        equ     MON_BASE+$95    ; re-entry guard: 0 = not inside a
                                        ;   fault report, 1 = reporting,
                                        ;   2 = died re-entering (sticky)
MON_FADDR       equ     MON_BASE+$98    ; group-0 ACCESS ADDRESS (long).
                                        ;   The 68000 pushes the address that
                                        ;   faulted at (sp)+2; discarding it
                                        ;   leaves "bus error at PC X" with no
                                        ;   way to say WHAT X touched, which is
                                        ;   the one number bring-up needs.
MON_SSW         equ     MON_BASE+$9C    ; group-0 special status word: bit 4 =
                                        ;   R/W (1 = read), bit 3 = I/N, bits
                                        ;   2-0 = function code (5 = supervisor
                                        ;   data, 6 = supervisor program)
MON_TXFAIL      equ     MON_BASE+$96    ; nonzero once a putchar has timed
                                        ;   out — survives for a RAM dump

; Cold-entry supervisor stack top, growing down toward the workspace end
; at MON_BASE+$97.  ~1.7 KB of stack, all inside the free region.  The
; panic path deliberately leaves SP alone — it needs the firmware's
; exception frame where the firmware left it.
MON_STACK       equ     $0FF00

; Region srec_check refuses to load over: workspace + cold-entry stack.
MON_LO          equ     MON_BASE
MON_HI          equ     MON_STACK

; Breakpoint table: 8 slots of {addr.l, saved original word}.  A slot
; with addr = 0 is free.
MON_BPN         equ     8
MON_BPT         equ     MON_BASE+$A0    ; 8 * 6 bytes = 48, ends +$CF
MON_BP_SZ       equ     6

; Tier 4 tap state and capture ring.  All of it sits inside
; MON_LO..MON_HI, so srec_check already refuses to load over it, and
; cold_init pre-writes every byte for the same DRAM-parity reason it
; pre-writes MON_REGS.
MON_TAPMSK      equ     MON_BASE+$D0    ; armed channels, bit n = ch n+1
MON_TAPTGT      equ     MON_BASE+$F0    ; chain target scratch -- FOUR longs, one
                                        ;   per channel ($F0-$FF, the gap below
                                        ;   MON_RING).  One shared slot was a
                                        ;   cross-channel race: see tap_body.
; Saved TRACE vector, or 0 = nothing saved.  Long-aligned, and it fits the
; $D1-$D7 gap (MON_TAPMSK is a BYTE), so the workspace does not grow -- the
; same trick MON_TAPTGT used to claim $F0-$FF.
;
; Zero is a safe sentinel because vector 9 is never zero on either image:
; the kernel's static vector table at $F00114 puts $F00AEE there (measured
; from the ROM), and cold_init fills all 256 vectors on the reset image.
MON_TRCSAV      equ     MON_BASE+$D4    ; saved vector 9, 0 = none saved
MON_TAPSAV      equ     MON_BASE+$D8    ; 4 saved vectors, $D8..$E7
MON_RINGHD      equ     MON_BASE+$E8    ; ring head index (word)
MON_RINGN       equ     MON_BASE+$EA    ; entries captured, saturating
MON_RINGOV      equ     MON_BASE+$EC    ; wrap count
MON_RING        equ     MON_BASE+$100   ; 64 * 10 bytes = $280, ending at
                                        ;   $0FB7F -- which leaves 896 bytes
                                        ;   of cold-entry stack below $0FF00
MON_RING_N      equ     64
MON_RING_SZ     equ     10

; TRAP #14 opcode, used as the breakpoint trap.  Vector 46 at $B8.
BP_OPCODE       equ     $4E4E
BP_VECTOR       equ     $B8
TRACE_VECTOR    equ     $24             ; vector 9 — T-bit trace
SR_TRACE_BIT    equ     15              ; T bit in SR

; putchar TX-ready spin limit.  The btst loop is ~20 cycles, so this is
; roughly 20M cycles / ~2.5 s at 8 MHz — comfortably longer than one
; character time even at the slowest strappable rate (50 baud = 200 ms),
; while still being bounded.  An unbounded spin here is why a dead SIO
; produced total silence on the first hardware attempt: the monitor hung
; before emitting a single byte, so there was nothing to diagnose.
TX_SPIN_LIMIT   equ     $100000

                org     $F0A826

;================================================================
; Cold entry — used when monitor is patched in as the reset PC.
; SP isn't loaded by the FPS reset path, so we install it ourselves
; before doing anything that pushes (like bsr).
;================================================================
monitor_cold:
                ori.w   #$2700,sr               ; supervisor, IPL=7
                movea.l #MON_STACK,sp           ; supervisor stack (below
                                                ;   the WCS staging buffer)
                bsr.w   cold_init               ; vectors + workspace
                bra.w   monitor_common

; monitor_entry MUST stay at $F0A840: patch_rom.py hardcodes
; MON_ENTRY = 0xA840, and README.md / CLAUDE.md both document that
; address.  Pinning it here means edits to monitor_cold above cannot
; silently shift it and send the panic-vector patch into the middle of
; an instruction.  vasm errors out if monitor_cold ever overflows.
                org     $F0A840

;================================================================
; Exception entry — called as JMP target from patched vectors.
;
; If entered via an exception, the supervisor stack contains the
; standard 7-word frame (or 4-word for IRQ).  We save D0-D7/A0-A6
; into MON_REGS, then read the saved PC and SR from the stack.
;================================================================
monitor_entry:
                ; The workspace check has to come before EVERYTHING, including
                ; the re-entry guard -- because the re-entry guard reads
                ; MON_NEST, and on the panic image nothing has ever written it.
                ; cold_init runs only on the --reset path; the panic image jumps
                ; straight here from the firmware's catch-all, and $0F800-$0FEFF
                ; is DRAM the firmware never touches, so on real hardware every
                ; byte of it powers up RANDOM.  A garbage MON_NEST sends this
                ; entry to mon_dead and STOPs the CPU with no banner and no
                ; prompt -- a board that looks dead, ~255 times out of 256.
                ; The emulator cannot show it: ram[] is zero-filled, and zero is
                ; a valid initial state for nearly every field here.
                ;
                ; Ordering is safe: a genuine re-entry means the monitor has
                ; already run, so the magic is set and ws_init is skipped -- the
                ; guard still sees the MON_NEST=1 that the first pass wrote.
                cmpi.l  #MON_MAGIC_V,MON_MAGIC
                beq.b   .ws_ok
                bsr.w   ws_init                 ; preserves d0/d1/a0
.ws_ok:
                ; Re-entry guard, before clobbering anything: if we are already
                ; reporting a fault, the fault is coming from the monitor's own
                ; I/O path and reporting it again just recurses, pushing a frame
                ; per pass until the stack eats the workspace.  Bail to mon_dead
                ; and keep the FIRST fault's PC/SR intact for post-mortem.
                tst.b   MON_NEST
                bne.w   mon_dead
                move.b  #1,MON_NEST

                movem.l d0-d7/a0-a6,MON_REGS
                move.b  #0,MON_GRP0             ; short frame: SR, then PC
                move.l  #0,MON_FADDR            ; no access address in a short
                move.w  #0,MON_SSW              ;   frame -- do not leave stale
                move.w  (sp),MON_SSR
                move.l  2(sp),MON_SPC
                bra.w   monitor_common

;================================================================
; grp0_entry — vectors 2 (bus error) and 3 (address error) ONLY.
;
; The 68000 pushes a 7-word group-0 frame, which is NOT laid out like
; the 4-word frame every other exception uses:
;
;   (sp)+0  special status word
;   (sp)+2  access address (long)
;   (sp)+6  instruction register
;   (sp)+8  status register      <- SR lives here, not at (sp)
;   (sp)+10 program counter      <- PC lives here, not at 2(sp)
;
; Reading it as a short frame reports the SSW as "SR" and half the
; fault address as "PC", which is worse than useless during bring-up.
; Group-0 faults are also not resumable on a 68000, so flag the frame
; and let cmd_go refuse rather than RTE into the weeds.
;================================================================
grp0_entry:
                ; Same first-write problem as monitor_entry, and the same
                ; ordering argument -- see the comment there.  A bus error is
                ; the LIKELIEST first entry on the panic image (that is what the
                ; catch-all is for), so this path is the one that would present
                ; as a dead board.
                cmpi.l  #MON_MAGIC_V,MON_MAGIC
                beq.b   .ws_ok
                bsr.w   ws_init
.ws_ok:
                tst.b   MON_NEST
                bne.w   mon_dead
                move.b  #1,MON_NEST

                movem.l d0-d7/a0-a6,MON_REGS
                move.b  #1,MON_GRP0             ; group-0: not resumable
                move.w  (sp),MON_SSW            ; special status word
                move.l  2(sp),MON_FADDR         ; THE ACCESS ADDRESS
                move.w  8(sp),MON_SSR
                move.l  10(sp),MON_SPC
                bra.w   monitor_common

;================================================================
; mon_dead — nested fault.  Touch NO I/O (the I/O is what is broken)
; and do not let the stack creep: re-anchor SP every pass, mark RAM so
; a later RAM dump shows how we got here, and stop the CPU.  STOP with
; IPL 7 still admits a level-7 NMI, so loop back and re-stop instead of
; falling through into whatever follows.
;================================================================
mon_dead:
                movea.l #MON_STACK,sp           ; re-anchor: no creep
                move.b  #2,MON_NEST             ; sticky post-mortem marker
                stop    #$2700
                bra.b   mon_dead

monitor_common:
                ; cold_init runs on the COLD path only, so on the panic path
                ; MON_ABORT would be whatever the firmware left in DRAM -- and
                ; every getchar reads it.  Clear it here, which both entries
                ; reach, rather than relying on cmd_loop happening to write
                ; MON_CMDSP before the first character arrives.
                move.b  #0,MON_ABORT
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
                ; A group-0 frame carries the address that actually faulted.
                ; Report it here: "bus error at PC X" without it says nothing
                ; about WHAT the access touched, and on this board the answer
                ; is usually a device that did not answer.
                cmpi.b  #1,MON_GRP0
                bne.b   .no_faddr
                lea     faddr_msg(pc),a0
                bsr.w   puts
                move.l  MON_FADDR,d0
                bsr.w   puthex_long
                lea     ssw_msg(pc),a0
                bsr.w   puts
                move.w  MON_SSW,d0
                bsr.w   puthex_word
.no_faddr:
                bsr.w   put_crlf

cmd_loop:
                ; We reached the prompt, so the I/O path works: re-arm the
                ; guard so a later fault is reportable too.
                move.b  #0,MON_NEST
                move.l  sp,MON_CMDSP            ; re-taken every pass, so the
                                                ;   abort anchor cannot go stale
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
                cmpi.b  #'b',d0
                beq.w   cmd_bp
                cmpi.b  #'t',d0
                beq.w   cmd_trace
                cmpi.b  #'x',d0
                beq.w   cmd_apif
                cmpi.b  #'y',d0
                beq.w   cmd_xltr
                cmpi.b  #'c',d0
                beq.w   cmd_ac
                cmpi.b  #'s',d0
                beq.w   cmd_tap
                cmpi.b  #'e',d0
                beq.w   cmd_bulk
                cmpi.b  #'p',d0
                beq.w   cmd_page
                cmpi.b  #'q',d0
                beq.w   cmd_ready
                cmpi.b  #'z',d0
                beq.w   cmd_sum
                cmpi.b  #'f',d0
                beq.w   cmd_fill

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
                ; d7 = access width: 1 byte (default), 2 word, 4 long.
                ; The byte form is kept because the MC6840 PTM and the SIO
                ; are odd-byte-only on D0-D7 and must be reached with
                ; move.b; the wide forms exist because the AP I/F and XLTR
                ; are 16-bit-only blocks that move.b cannot drive at all.
                moveq   #1,d7
                addq.l  #1,a6
                move.b  (a6),d0
                cmpi.b  #'w',d0
                beq.b   .w16
                cmpi.b  #'l',d0
                beq.b   .w32
                bra.b   .havew
.w16:
                moveq   #2,d7
                addq.l  #1,a6
                bra.b   .havew
.w32:
                moveq   #4,d7
                addq.l  #1,a6
.havew:
                bsr.w   skip_ws
                move.b  (a6),d0
                beq.b   .use_last
                bsr.w   parse_hex
                tst.b   d1
                beq.w   cmd_err
                bsr.w   odd_check
                tst.b   d1
                beq.w   cmd_loop
                move.l  d0,MON_LASTADDR
.use_last:
                bsr.w   skip_ws
                moveq   #16,d2                  ; default: 16 bytes
                cmpi.b  #2,d7
                bne.b   .d1
                moveq   #8,d2                   ;          8 words
.d1:
                cmpi.b  #4,d7
                bne.b   .d2
                moveq   #4,d2                   ;          4 longs
.d2:
                move.b  (a6),d0
                beq.b   .cap
                bsr.w   parse_hex
                tst.b   d1
                beq.w   cmd_err
                move.l  d0,d2
.cap:
                ; one line's worth per line, one screen's worth per command
                moveq   #64,d3                  ; words
                cmpi.b  #2,d7
                beq.b   .havecap
                moveq   #32,d3                  ; longs
                cmpi.b  #4,d7
                beq.b   .havecap
                moveq   #127,d3
                addq.l  #1,d3                   ; 128 bytes
.havecap:
                cmp.l   d3,d2
                bls.b   .do                     ; UNSIGNED.  Third site of one
                                                ;   bug (also cmd_bulk, cmd_page):
                                                ;   a signed `ble` reads
                                                ;   $FFFFFFFF as -1 and skips the
                                                ;   clamp, and `m 1000 FFFFFFFF`
                                                ;   then prints 268M lines at
                                                ;   9600 baud -- unrecoverable
                                                ;   without a reset.
                move.l  d3,d2
.do:
                move.l  MON_LASTADDR,a4
                cmpi.b  #1,d7
                bne.b   .wide
                bsr.w   hexdump
                add.l   d2,MON_LASTADDR
                bra.w   cmd_loop
.wide:
                bsr.w   xdump
                move.l  d2,d0
                mulu.w  d7,d0
                add.l   d0,MON_LASTADDR
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
                moveq   #1,d7                   ; width, as cmd_mem
                addq.l  #1,a6
                move.b  (a6),d0
                cmpi.b  #'w',d0
                beq.b   .w16
                cmpi.b  #'l',d0
                beq.b   .w32
                bra.b   .havew
.w16:
                moveq   #2,d7
                addq.l  #1,a6
                bra.b   .havew
.w32:
                moveq   #4,d7
                addq.l  #1,a6
.havew:
                bsr.w   skip_ws
                bsr.w   parse_hex
                tst.b   d1
                beq.w   cmd_err
                bsr.w   odd_check
                tst.b   d1
                beq.w   cmd_loop
                move.l  d0,a4
.wloop:
                bsr.w   skip_ws
                move.b  (a6),d0
                beq.b   .done
                bsr.w   parse_hex
                tst.b   d1
                beq.w   cmd_err
                cmpi.b  #1,d7
                bne.b   .p2
                move.b  d0,(a4)+
                bra.b   .wloop
.p2:
                cmpi.b  #2,d7
                bne.b   .p4
                move.w  d0,(a4)+
                bra.b   .wloop
.p4:
                move.l  d0,(a4)+
                bra.b   .wloop
.done:
                lea     ok_msg(pc),a0
                bsr.w   puts
                bra.w   cmd_loop

;----------------------------------------------------------------
; Go — restore registers and RTE.  No address arg = use saved PC.
; "g XXXXXX" replaces the saved PC before resuming.
;----------------------------------------------------------------
; Only a short (4-word) frame can be *resumed*.  A group-0 frame is not
; restartable on a 68000, and cold entry has no frame at all — but with
; an explicit address, cold entry can still start code by synthesizing a
; frame and RTE'ing into it.  That is what makes the standalone monitor
; able to run and then debug something, rather than only look at memory.
cmd_go:
                ; Put the trace vector back first.  `t` displaces a LIVE
                ; kernel handler ($F00AEE) where `b` displaces nobody --
                ; see cmd_trace.  Doing it here rather than at .resume
                ; covers .fresh too, since both paths end in RTE, and d0
                ; is free at this point because nothing is parsed yet.
                move.l  MON_TRCSAV,d0
                beq.b   .notrc
                move.l  d0,TRACE_VECTOR
                clr.l   MON_TRCSAV              ; so a second `g` cannot
                                                ;   re-poke a stale value
.notrc:
                addq.l  #1,a6
                bsr.w   skip_ws
                move.b  (a6),d0
                beq.b   .noaddr
                bsr.w   parse_hex
                tst.b   d1
                beq.w   cmd_err
                ; An explicit address is a START, not a resume, so any
                ; frame we cannot resume ($FF cold entry OR 1 group-0) is
                ; handled by synthesizing one.  Refusing the group-0 case
                ; here meant that after a single bus error NO further code
                ; could be started until a power cycle -- the worst failure
                ; mode for a bring-up tool, since every later probe then
                ; reports a fault that is about the monitor, not the board.
                tst.b   MON_GRP0
                bne.w   .fresh                  ; no resumable frame + address
                move.l  d0,MON_SPC
                bra.b   .resume
.noaddr:
                tst.b   MON_GRP0                ; no address: need a real frame
                bne.w   .no_frame
                ; falls through to .resume -- an explicit `bra.b .resume` here
                ; assembles to a NOP (vasm warning 2058) and reads as control
                ; flow that does not exist.
.resume:
                lea     resume_msg(pc),a0
                bsr.w   puts
                move.l  MON_SPC,d0
                bsr.w   puthex_long
                bsr.w   put_crlf
                ; rebuild stack frame and RTE
                bclr.b  #SR_TRACE_BIT-8,MON_SSR ; stop tracing on a plain g
                move.l  MON_SPC,2(sp)
                move.w  MON_SSR,(sp)
                movem.l MON_REGS,d0-d7/a0-a6
                rte
.fresh:
                ; Two ways in, and they differ on the stack.  MON_GRP0 = $FF is
                ; cold entry: no frame exists.  MON_GRP0 = 1 means a 7-word
                ; group-0 frame IS sitting at (sp) -- grp0_entry saves the
                ; registers to MON_REGS, not the stack, so the frame is the
                ; whole 14 bytes -- and we are about to abandon it.  Pop it, or
                ; every bus-error-then-`g ADDR` cycle leaks 14 bytes: about 60
                ; of those and the cold-entry stack reaches the tap ring at
                ; $0FB7F, which CORRUPTS CAPTURES rather than crashing, so it
                ; would present as bad data and be blamed on the tap.
                ; Nothing is lost -- MON_SPC, MON_SSR, MON_FADDR and MON_SSW
                ; already hold everything the frame carried.  MON_GRP0 -> $FF
                ; afterwards so a second `g` cannot pop a frame that has gone.
                cmpi.b  #1,MON_GRP0
                bne.b   .nopop
                lea     14(sp),sp
                move.b  #$FF,MON_GRP0
.nopop:
                ; Build a frame.  RTE pops SR then PC, so push PC first and SR
                ; on top.  IPL stays 7 and the T bit stays clear; every vector
                ; already points at the monitor, so a fault in the target lands
                ; back here.
                move.l  d0,MON_SPC
                lea     resume_msg(pc),a0
                bsr.w   puts
                move.l  MON_SPC,d0
                bsr.w   puthex_long
                bsr.w   put_crlf
                move.w  #$2700,MON_SSR
                move.l  MON_SPC,-(sp)           ; PC
                move.w  MON_SSR,-(sp)           ; SR
                movem.l MON_REGS,d0-d7/a0-a6
                rte
.no_frame:
                lea     nogo_msg(pc),a0
                bsr.w   puts
                bra.w   cmd_loop

;================================================================
; Breakpoints:  b            list slots
;               b ADDR       set a breakpoint
;               b -ADDR      clear one
;               b -          clear all
;
; A breakpoint replaces the word at ADDR with TRAP #14 ($4E4E) and keeps
; the original in the slot table.  Vector 46 ($B8) is pointed at
; monitor_entry when the first breakpoint is armed — cold_init already
; filled every vector, but on the --panic path the firmware owns the
; table, so arming has to install it explicitly.  That is the only write
; this command makes outside the target word and the slot table.
;
; TRAP pushes the 4-word frame, so MON_SPC/MON_SSR read correctly and
; MON_GRP0 stays 0, which keeps `g` usable.  Note the pushed PC points
; *after* the trap word: `g` therefore resumes past the breakpoint, and
; the original instruction is NOT re-executed.  Clear the breakpoint and
; `g ADDR` if you need to run it.
;================================================================
cmd_bp:
                addq.l  #1,a6
                bsr.w   skip_ws
                move.b  (a6),d0
                beq.w   bp_list                 ; bare "b" -> list
                cmpi.b  #'-',d0
                beq.b   .clear
                bsr.w   parse_hex
                tst.b   d1
                beq.w   cmd_err
                bsr.w   bp_set
                bra.w   cmd_loop
.clear:
                addq.l  #1,a6                   ; skip '-'
                bsr.w   skip_ws
                move.b  (a6),d0
                beq.b   .clr_all
                bsr.w   parse_hex
                tst.b   d1
                beq.w   cmd_err
                bsr.w   bp_clr_one
                bra.w   cmd_loop
.clr_all:
                bsr.w   bp_clr_all
                lea     ok_msg(pc),a0
                bsr.w   puts
                bra.w   cmd_loop

; ---- bp_set: arm a breakpoint at d0 ----
bp_set:
                movem.l d0-d3/a0-a1,-(sp)
                move.l  d0,d3                   ; target address
                beq.w   .odd                    ; 0 is not a target
                btst.l  #0,d3
                bne.w   .odd                    ; must be word-aligned
                ; Target must be on-board RAM.  A breakpoint writes $4E4E to
                ; the address: in ROM that is silently lost, but in
                ; peripheral space it would poke the AP I/F or XLTR, and
                ; $F70011 would transmit a byte over the SIO.
                ; Use the audited bounds routine rather than a second copy of
                ; the rule.  The two cmpi.l that used to be here covered the
                ; vector table and the top of RAM but NOT the monitor's own
                ; workspace, so `b F900` patched $4E4E into the TAP RING and
                ; `b FE00` into the monitor's own STACK -- where the next deep
                ; call overwrites the trap word, and clearing the breakpoint
                ; afterwards writes the saved word back over live stack.
                ; srec_check reads d3 as the start and d2 as the byte count,
                ; preserves d0/d3, and clobbers d1 only; d1 and d2 are both
                ; free here because the scan below sets them afterwards.
                moveq   #2,d2                   ; a breakpoint writes one word
                bsr.w   srec_check
                tst.b   d1
                beq.w   .odd
                ; find a free slot, and reject a duplicate
                lea     MON_BPT,a0
                moveq   #MON_BPN-1,d1
                suba.l  a1,a1                   ; a1 = first free slot, or 0
.scan:
                move.l  (a0),d2
                beq.b   .isfree
                cmp.l   d3,d2
                beq.w   .dup
                bra.b   .next
.isfree:
                move.l  a1,d2
                bne.b   .next                   ; already have a free slot
                move.l  a0,a1
.next:
                lea     MON_BP_SZ(a0),a0
                dbra    d1,.scan
                move.l  a1,d2
                beq.w   .full
                ; point the TRAP #14 vector at the monitor, then patch
                move.l  #monitor_entry,BP_VECTOR
                move.l  d3,a0
                move.w  (a0),4(a1)              ; save original word
                move.w  #BP_OPCODE,(a0)
                move.l  d3,(a1)                 ; mark slot in use
                lea     bp_set_msg(pc),a0
                bsr.w   puts
                move.l  d3,d0
                bsr.w   puthex_long
                bsr.w   put_crlf
                bra.b   .out
.dup:
                lea     bp_dup_msg(pc),a0
                bsr.w   puts
                bra.b   .out
.full:
                lea     bp_full_msg(pc),a0
                bsr.w   puts
                bra.b   .out
.odd:
                lea     bp_odd_msg(pc),a0
                bsr.w   puts
.out:
                movem.l (sp)+,d0-d3/a0-a1
                rts

; ---- bp_clr_one: disarm the breakpoint at d0, restoring its word ----
bp_clr_one:
                movem.l d0-d2/a0-a1,-(sp)
                move.l  d0,d2
                beq.w   .nf                     ; 0 never matches a slot
                lea     MON_BPT,a0
                moveq   #MON_BPN-1,d1
.scan:
                move.l  (a0),d0
                cmp.l   d2,d0
                bne.b   .next
                move.l  d0,a1
                move.w  4(a0),(a1)              ; put the original back
                move.l  #0,(a0)                 ; free the slot
                lea     ok_msg(pc),a0
                bsr.w   puts
                bra.b   .out
.next:
                lea     MON_BP_SZ(a0),a0
                dbra    d1,.scan
.nf:
                lea     bp_none_msg(pc),a0
                bsr.w   puts
.out:
                movem.l (sp)+,d0-d2/a0-a1
                rts

; ---- bp_clr_all: disarm every armed slot ----
bp_clr_all:
                movem.l d0-d1/a0-a1,-(sp)
                lea     MON_BPT,a0
                moveq   #MON_BPN-1,d1
.scan:
                move.l  (a0),d0
                beq.b   .next
                move.l  d0,a1
                move.w  4(a0),(a1)
                move.l  #0,(a0)
.next:
                lea     MON_BP_SZ(a0),a0
                dbra    d1,.scan
                movem.l (sp)+,d0-d1/a0-a1
                rts

; ---- bp_list: show armed slots ----
bp_list:
                lea     bp_list_msg(pc),a0
                bsr.w   puts
                lea     MON_BPT,a4
                moveq   #MON_BPN-1,d3
                moveq   #0,d5                   ; count
.scan:
                move.l  (a4),d0
                beq.b   .next
                addq.l  #1,d5
                move.b  #' ',d0
                bsr.w   putchar
                bsr.w   putchar
                move.l  (a4),d0
                bsr.w   puthex_long
                lea     bp_was_msg(pc),a0
                bsr.w   puts
                move.w  4(a4),d0
                bsr.w   puthex_word
                bsr.w   put_crlf
.next:
                lea     MON_BP_SZ(a4),a4
                dbra    d3,.scan
                tst.l   d5
                bne.w   cmd_loop
                lea     bp_empty_msg(pc),a0
                bsr.w   puts
                bra.w   cmd_loop

;================================================================
; Single step:  t
;
; Sets the T bit in the saved SR and resumes.  The 68000 then takes a
; trace exception after one instruction, which lands back in the monitor
; (vector 9 at $24).  Needs a resumable frame, same as `g`.  The T bit
; stays set in the restored SR, so `t` repeats naturally.
;
; Stepping has TWO halves and `g` puts both back: the T bit in the saved
; SR, and the vector itself.  Contrast `b`, which installs monitor_entry
; into TRAP #14 permanently and is right to -- the two differ on whether
; the vector belongs to anyone, measured from the kernel's own static
; vector table at $F00114 ({1-byte vector, 3-byte handler} records):
;
;     vector $09 TRACE   -> $F00AEE   entry 11 of the CPU-exception bsr
;                                     ladder at $F00AD8.  LIVE.
;     vector $2E TRAP#14 -> ABSENT from that table.  Nobody's.
;
; So `t` displaces a real kernel handler and must give it back.  Nothing
; today notices -- RMS68K's per-task single-stepping is latent, since
; nothing sets TCB+$148 bit 31 -- but leaving it installed breaks the
; save/restore discipline every other stateful command here follows, and
; the whole point of the panic image is to sit alongside a running RTOS.
;================================================================
cmd_trace:
                tst.b   MON_GRP0
                bne.w   trace_noframe
                ; Save the ORIGINAL vector ONCE.  A second `t` must not
                ; save monitor_entry over it: that is precisely the bug
                ; `s` twice had, where re-arming made the taps save
                ; themselves and `s-` then restored the taps.
                tst.l   MON_TRCSAV
                bne.b   .haveold
                move.l  TRACE_VECTOR,MON_TRCSAV
.haveold:
                move.l  #monitor_entry,TRACE_VECTOR
                bset.b  #SR_TRACE_BIT-8,MON_SSR ; high byte of the saved SR
                lea     trace_msg(pc),a0
                bsr.w   puts
                move.l  MON_SPC,d0
                bsr.w   puthex_long
                bsr.w   put_crlf
                move.l  MON_SPC,2(sp)
                move.w  MON_SSR,(sp)
                movem.l MON_REGS,d0-d7/a0-a6
                rte
trace_noframe:
                lea     nogo_msg(pc),a0
                bsr.w   puts
                bra.w   cmd_loop

;----------------------------------------------------------------
; Info — chassis state, ROM version, free RAM, etc.
;----------------------------------------------------------------
cmd_info:
                lea     info_msg(pc),a0
                bsr.w   puts

                ; Live board status.  Byte read at ODD $F70019 — the board
                ; status/control register is an 8-bit device on D0-D7, and
                ; the ROM bit-tests this same odd byte (F08728 etc).
                lea     bstat_msg(pc),a0
                bsr.w   puts
                move.b  $F70019,d0
                bsr.w   puthex_byte
                bsr.w   put_crlf

                ; VERSAmodule control register image at $1FFF0.  Per the
                ; manual this is "control register image only — register
                ; not directly accessible", so read-back is mediated by
                ; external logic and may not reflect what was written.
                lea     vmod_msg(pc),a0
                bsr.w   puts
                move.w  $1FFF0,d0
                bsr.w   puthex_word
                bsr.w   put_crlf

                ; Where this build actually ends, rather than a hardcoded
                ; number that goes stale every time the monitor grows.
                lea     mend_msg(pc),a0
                bsr.w   puts
                move.l  #monitor_end,d0
                bsr.w   puthex_long
                bsr.w   put_crlf

                ; Fault / link state: frame kind, nest guard, TX-timeout
                ; flag.  MON_NEST = 2 means a previous run died while
                ; reporting a fault; MON_TXFAIL = 1 means putchar gave up
                ; waiting for the SIO at some point.
                lea     fault_msg(pc),a0
                bsr.w   puts
                move.b  MON_GRP0,d0
                bsr.w   puthex_byte
                move.b  #'/',d0
                bsr.w   putchar
                move.b  MON_NEST,d0
                bsr.w   puthex_byte
                move.b  #'/',d0
                bsr.w   putchar
                move.b  MON_TXFAIL,d0
                bsr.w   puthex_byte
                lea     faddr_msg(pc),a0
                bsr.w   puts
                move.l  MON_FADDR,d0
                bsr.w   puthex_long
                lea     ssw_msg(pc),a0
                bsr.w   puts
                move.w  MON_SSW,d0
                bsr.w   puthex_word
                bsr.w   put_crlf
                bra.w   cmd_loop

;----------------------------------------------------------------
; Load S-record over the SIO (channel A).
; Each line consumed and validated; bytes go to addresses inside.
; Terminator: S8 / S9 record.
;----------------------------------------------------------------
cmd_load_srec:
                move.b  #1,MON_ABORT            ; ESC now aborts (see getchar)
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
                ; read_hex_byte only writes d0's low byte, so the upper 24
                ; bits are stale.  Zero-extend explicitly, and keep the
                ; count word-sized below: a payload count >= $80 is legal
                ; in an S1 record, and a signed byte test would read it as
                ; negative and silently truncate the record to no data.
                moveq   #0,d2
                move.b  d0,d2                   ; payload count (incl addr+cksum)
                ; d7 accumulates the record checksum: sum of the count byte,
                ; the address bytes and the data bytes.  A valid record has
                ; (sum + cksum) & $FF == $FF.  Without this a corrupted line
                ; loads silently and reports success, which over a serial
                ; link at an unverified baud rate is exactly the failure we
                ; would not notice.
                moveq   #0,d7
                add.b   d0,d7
                clr.l   d3
                cmpi.b  #'3',d6
                beq.b   .a32
                cmpi.b  #'2',d6
                beq.b   .a24
                bra.b   .a16
.a32:
                bsr.w   read_hex_byte
                add.b   d0,d7
                lsl.l   #8,d3
                or.b    d0,d3
                subq.w  #1,d2
.a24:
                bsr.w   read_hex_byte
                add.b   d0,d7
                lsl.l   #8,d3
                or.b    d0,d3
                subq.w  #1,d2
.a16:
                bsr.w   read_hex_byte
                add.b   d0,d7
                lsl.l   #8,d3
                or.b    d0,d3
                bsr.w   read_hex_byte
                add.b   d0,d7
                lsl.l   #8,d3
                or.b    d0,d3
                subq.w  #2,d2
                subq.w  #1,d2                   ; -1 for checksum
                move.l  d3,a4                   ; dest pointer
                bsr.w   srec_check              ; d1 = 0 -> would self-destruct
                tst.b   d1
                beq.w   .badaddr
.dloop:
                tst.w   d2
                ble.b   .endrec
                bsr.w   read_hex_byte
                add.b   d0,d7
                move.b  d0,(a4)+
                addq.l  #1,d5
                subq.w  #1,d2
                bra.b   .dloop
.endrec:
                bsr.w   read_hex_byte           ; the record's checksum byte
                add.b   d0,d7
                cmpi.b  #$FF,d7
                bne.b   .badsum
                addq.l  #1,d4
                move.b  #'.',d0
                bsr.w   putchar
                bra.w   .eat_eol
.badsum:
                ; The data was already written by the time we can check, so
                ; say which record failed and let the operator re-send it.
                lea     srec_sum_msg(pc),a0
                bsr.w   puts
                move.l  d3,d0
                bsr.w   puthex_long
                bsr.w   put_crlf
                bra.w   .scan_S
.badaddr:
                ; Skip this record.  No need to consume its hex: .scan_S
                ; resyncs on the next 'S', and hex digits are 0-9A-F so
                ; none of the skipped payload can be mistaken for a
                ; record start.
                lea     srec_bad_msg(pc),a0
                bsr.w   puts
                move.l  d3,d0
                bsr.w   puthex_long
                bsr.w   put_crlf
                bra.w   .scan_S
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
                move.b  #0,MON_ABORT            ; the only normal exit; the
                                                ;   bad-record paths loop back
                                                ;   to .scan_S and stay armed
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
                tst.l   d2                      ; as xdump: a zero count would
                beq.w   .ret                    ;   otherwise print one row of
                                                ;   .w, not .b: hexdump's body
                                                ;   is ~140 bytes, past the
                                                ;   +/-127 a short branch
                                                ;   reaches.  xdump's own guard
                                                ;   is .b only because xdump is
                                                ;   short.
                                                ;   pure padding.  Same contract
                                                ;   as xdump, deliberately --
                                                ;   these two are the shared
                                                ;   dump primitives and every
                                                ;   caller should be able to
                                                ;   reason about them alike.
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
                bcc.b   .full                   ; UNSIGNED -- the FIFTH instance,
                                                ;   and the first inside a shared
                                                ;   primitive rather than a
                                                ;   command.  d6 is a caller's
                                                ;   item count: with `bge`, any
                                                ;   count >= $80000000 reads as
                                                ;   negative, fails the test and
                                                ;   sets d4 = d6 -- a .hex loop
                                                ;   of 4 billion puthex calls,
                                                ;   with no ESC escape (MON_ABORT
                                                ;   is armed only inside L).
                                                ;
                                                ;   Every caller today clamps
                                                ;   unsigned, so this was not
                                                ;   reachable.  It is fixed HERE
                                                ;   because a routine whose
                                                ;   safety depends on all its
                                                ;   callers remembering is one
                                                ;   command away from a hang,
                                                ;   and this file grows commands.
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
                bne.w   .line                   ; not bgt: d4 = min(16,d6) taken
                                                ;   UNSIGNED above, so d6 can
                                                ;   never go negative and "not
                                                ;   zero" IS the loop condition.
                                                ;   Signedness cannot enter --
                                                ;   which is the point, since
                                                ;   `bgt` here was the second
                                                ;   half of the same bug.
.ret:
                rts

; ---- read_line: read line from SIO into MON_LINEBUF, term=0 ----
read_line:
                lea     MON_LINEBUF,a0
                moveq   #60,d2                  ; 61 chars + NUL, 2 spare
                                        ;   in the 64 B before MON_LASTADDR
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
                ; Drop the remaining control characters rather than storing and
                ; ECHOING them.  The echo is the real harm: a bare ESC sent
                ; back can put the operator's terminal into a state they then
                ; have to unpick, and now that ESC is meaningful during L it is
                ; a key people will actually press.  This does NOT fully tidy
                ; an arrow key -- ESC '[' 'A' loses only the ESC, and the
                ; printable '[A' still reaches the buffer and draws a '?'.
                ; Swallowing those too would need a small escape-sequence state
                ; machine, and a monitor that silently eats visible characters
                ; is worse to use than one that shows you the junk it got.  TAB survives because skip_ws
                ; accepts it as whitespace.  bcs, not blt -- a byte >= $80 is
                ; negative under a signed test, and line noise would be
                ; silently swallowed instead of showing up as junk the
                ; operator can see.
                cmpi.b  #9,d0                   ; TAB
                beq.b   .store
                cmpi.b  #' ',d0
                bcs.b   .rloop                  ; other controls: ignore
.store:
                bsr.w   putchar                 ; echo
                move.b  d0,(a0)+
                dbra    d2,.rloop
                ; Buffer full and no terminator yet.  This USED to fall
                ; straight into .end, which silently executed whatever
                ; fitted -- and truncation lands mid-TOKEN, so
                ;   ww 3000 <22 words>
                ; became a valid but WRONG write of the words that fitted,
                ; with the last one short a nibble.  The tail then stayed
                ; in the SIO and arrived as the NEXT command, so one long
                ; paste produced a wrong write followed by a cascade of
                ; junk commands.  Planting a stub with ww and running it
                ; with g is the monitor's own documented technique, and
                ; those lines are exactly the ones that exceed 61 bytes.
                ;
                ; Peek first: if the next character IS the terminator the
                ; line exactly fills the buffer and is perfectly valid --
                ; rejecting it would be an off-by-one that refuses a legal
                ; command.
                bsr.w   getchar
                cmpi.b  #13,d0
                beq.b   .end
                cmpi.b  #10,d0
                beq.b   .end
                bra.b   .full                   ; block lives past .bs, so
                                                ;   .bs keeps its ORIGINAL
                                                ;   distance to .rloop --
                                                ;   inserting here instead
                                                ;   pushed that bra.b out of
                                                ;   short-branch range
.end:
                move.b  #0,(a0)                 ; not clr: CLR reads first
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
.full:
                ; Drain to the terminator WITHOUT echoing.  Echoing would
                ; double the time per character on a link with no flow
                ; control, and the characters being dropped are the ones
                ; that would then be missed -- including the CR, which
                ; would leave the drain running on into the next command.
                bsr.w   getchar
                cmpi.b  #13,d0
                beq.b   .toolong
                cmpi.b  #10,d0
                bne.b   .full
.toolong:
                lea     MON_LINEBUF,a0
                move.b  #0,(a0)                 ; hand back an EMPTY line:
                                                ;   cmd_loop re-prompts on it
                bsr.w   put_crlf
                lea     toolong_msg(pc),a0
                bsr.w   puts
                rts

; ---- skip_ws: skip whitespace at (a6) ----
;      CLOBBERS d0, and ADVANCES a6 past the whitespace -- again the operation
;      itself, so it cannot be saved either.  Swept at all 24 call sites: every
;      one is followed by parse_hex, which RETURNS in d0, so nothing observes
;      the clobber.  That is the reason it has never bitten, not a reason it
;      cannot: a future caller reading d0 straight after would.
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
;                 advances a6 past digits.
;      CLOBBERS d0 and d1 ONLY.  It uses d2 as the digit and d3 as the
;      digit count, and saves both -- 10 bytes to remove a whole class of
;      aliasing bug.  The recorded cmd_page/xdump defect was exactly this
;      shape (a value held in d4 across a call that used d4), and it
;      reported a restore that had not happened, which is worse than no
;      restore because it is believed.
parse_hex:
                movem.l d2-d3,-(sp)
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
                bra.b   .ret
.err:
                clr.b   d1
.ret:
                movem.l (sp)+,d2-d3             ; d0/d1 carry the result out
                rts

;================================================================
; srec_check — is it safe to write d2 bytes starting at d3?
;   returns d1 = 1 safe, 0 = refuse.  Preserves d0/d2/d3.
;
; A load is refused unless its whole range lies in on-board RAM and
; clear of the two regions the monitor itself needs:
;
;   $000000-$0003FF  the exception vector table
;   $00F800-$00FEFF  MON_* workspace, breakpoint table, and the
;                    cold-entry supervisor stack below $0FF00
;
; Anything at or above $20000 is refused outright.  That range is ROM
; and peripherals, and a stray S2/S3 record pointed there would not
; merely be ignored: a write to $F70011 would transmit a byte over the
; SIO, and writes to the XLTR or AP I/F blocks would poke the chassis.
; Deliberate peripheral pokes are what the `w` command is for.
;
; The workspace used to live at $1F000, inside the WCS staging buffer,
; which forced the top 4 KB of the buffer to be refused.  It now sits at
; $0F800, below the buffer, so $10000-$1FFFF is loadable end to end.
;================================================================
srec_check:
                movem.l d0/d3,-(sp)
                moveq   #0,d1
                cmpi.l  #$400,d3
                bcs.b   .out                    ; below vector-table top
                cmpi.l  #$20000,d3
                bcc.b   .out                    ; beyond on-board RAM
                move.l  d3,d0
                add.l   d2,d0
                subq.l  #1,d0                   ; last byte to be written
                cmpi.l  #$20000,d0
                bcc.b   .out                    ; would run off the end of RAM
                cmpi.l  #MON_HI,d3
                bcc.b   .ok                     ; starts above our region
                cmpi.l  #MON_LO,d0
                bcc.b   .out                    ; reaches workspace/stack
.ok:
                moveq   #1,d1
.out:
                movem.l (sp)+,d0/d3
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

;================================================================
; cold_init — called from monitor_cold ONLY (never from monitor_entry).
;
; The MC68000 has no VBR: the exception vector table is hard-wired at
; $000000-$0003FF, which on this board is plain DRAM.  The reset SSP/PC
; are the only vectors that come from ROM — the M68KVM02 maps just the
; first 8 bytes of ROM to address 0 for the first four bus cycles after
; a total system reset, then address 0 is DRAM like any other.  So at
; power-on every vector except reset is whatever the DRAM happens to
; hold, i.e. garbage.
;
; The stock firmware handles this on its 2nd and 3rd instructions —
; MainInit at F08700 does `lea $1ffd0,a7` then immediately installs
; $8 and $C (F08706 / F0870E) before touching any I/O.  But when
; patch_rom.py --reset points the reset PC at monitor_cold, MainInit
; never executes, so nothing fills the table and the monitor inherits
; garbage.  Any bus or address error then fetches a junk handler
; address, faults again, and the 68000 asserts HALT (double bus fault)
; with no diagnostic at all.  That is what a bad SIO address did on
; real hardware: FAIL + HALTED, silently.
;
; Point every vector at monitor_entry so the next fault reports itself
; instead of killing the CPU.  Writing all 1 KB also leaves valid DRAM
; parity across the table, which matters if the board's parity strap is
; enabled (a read of never-written DRAM can raise BERR).
;
; This deliberately does NOT run on the panic path: with --panic only,
; the firmware booted normally and its live vectors are already in
; place, and `g` needs them intact to resume.
;================================================================
cold_init:
                suba.l  a0,a0                   ; a0 = $000000
                move.l  #monitor_entry,d0
                move.w  #255,d1                 ; 256 vectors, dbra -> 256 passes
.vfill:
                move.l  d0,(a0)+
                dbra    d1,.vfill

                ; Vectors 2 and 3 push the 7-word group-0 frame, which
                ; monitor_entry would misread — give them their own stub.
                move.l  #grp0_entry,$8          ; bus error
                move.l  #grp0_entry,$C          ; address error

                ; Pre-write the whole workspace.  Two reasons: it leaves
                ; valid DRAM parity on every byte the monitor later reads
                ; back (MON_NEST and MON_LASTADDR are both read before
                ; being written otherwise), and it puts the guard in a
                ; known state.  move.l/move.b, never clr: a real MC68000
                ; READS the destination before writing it on CLR, so clr
                ; on never-written DRAM is a parity-BERR risk.  (Musashi
                ; models CLR as a pure write, so the emulator never shows
                ; this — see m68k_in.c, M68KMAKE_OP(clr, 32, ., .).)
                ; MON_REGS itself must be written too, not just the
                ; scalars below it: cmd_regs READS all 60 bytes, and on a
                ; cold boot nothing has written them yet.  On a board with
                ; the DRAM parity strap enabled, reading never-written
                ; memory raises BERR, so `r` before any fault would have
                ; been a parity trap rather than a register dump.  The
                ; emulator cannot show this — its RAM is zero-filled and
                ; it models no parity.
                bra.w   ws_init                 ; ...which is the rest of this
                                                ;   routine, factored out so the
                                                ;   panic path can reach it too

;================================================================
; ws_init — initialise the WORKSPACE ONLY, never the vector table.
;
; Split out of cold_init because the two entries need different amounts
; of it.  The --reset image owns the machine and fills all 256 vectors;
; the PANIC image must not touch a single one -- the RTOS is running and
; its vectors are live -- but it needs every workspace field defined just
; as badly, because $0F800-$0FEFF is DRAM the firmware never writes.
;
; Called from monitor_entry/grp0_entry BEFORE the registers are saved to
; MON_REGS, so it must preserve everything it touches or `r` would show
; the monitor's own working values instead of the faulting task's.
;
; MON_MAGIC is written LAST, deliberately: a fault partway through this
; routine leaves it unset, so the next entry re-runs the whole thing
; rather than trusting a half-built workspace.
;================================================================
ws_init:
                movem.l d0-d1/a0,-(sp)
                lea     MON_REGS,a0
                moveq   #14,d1                  ; 15 longs, dbra -> 15 passes
.rclr:
                move.l  #0,(a0)+
                dbra    d1,.rclr

                move.l  #0,MON_SPC
                move.w  #$2700,MON_SSR
                move.l  #0,MON_LASTADDR
                move.b  #$FF,MON_GRP0           ; cold entry: no frame
                move.b  #0,MON_NEST             ; first fault is reportable
                move.b  #0,MON_TXFAIL
                move.l  #0,MON_FADDR            ; no fault yet: a stale address
                move.w  #0,MON_SSW              ;   would read as a live one
                move.b  #0,MON_ABORT            ; read by EVERY getchar, so it
                move.l  #0,MON_CMDSP            ;   must start defined
                move.l  #0,MON_TRCSAV           ; 0 = no trace vector saved.
                                                ;   On the PANIC image nothing
                                                ;   else writes this, so an
                                                ;   uninitialised DRAM word
                                                ;   would read as a saved
                                                ;   vector and `g` would poke
                                                ;   garbage into $24.
                ; clear the breakpoint slot table (addr 0 = free)
                lea     MON_BPT,a0
                moveq   #MON_BPN-1,d1
.bpclr:
                move.l  #0,(a0)
                move.w  #0,4(a0)
                lea     MON_BP_SZ(a0),a0
                dbra    d1,.bpclr
                ; Tier 4 tap state and capture ring.  MON_TAPMSK is read
                ; before it is written otherwise, so it must start defined
                ; for the same reason MON_NEST does.
                move.b  #0,MON_TAPMSK
                lea     MON_TAPTGT,a0           ; four longs now, one per channel
                move.l  #0,(a0)+
                move.l  #0,(a0)+
                move.l  #0,(a0)+
                move.l  #0,(a0)+
                lea     MON_TAPSAV,a0
                moveq   #3,d1
.tapclr:
                move.l  #0,(a0)+
                dbra    d1,.tapclr
                move.w  #0,MON_RINGHD
                move.w  #0,MON_RINGN
                move.w  #0,MON_RINGOV
                lea     MON_RING,a0
                move.w  #(MON_RING_N*MON_RING_SZ)/4-1,d1
.ringclr:
                move.l  #0,(a0)+
                dbra    d1,.ringclr
                move.l  #MON_MAGIC_V,MON_MAGIC  ; LAST -- see the header
                movem.l (sp)+,d0-d1/a0
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

; ---- putchar: send byte in d0 over SIO chA.  Bounded: drops the
;      character and sets MON_TXFAIL rather than hanging forever, so a
;      dead or mis-strapped SIO still lets the monitor make progress and
;      leaves evidence in RAM.  Preserves d0 and d1.
putchar:
                move.l  d1,-(sp)
                ; Belt-and-braces: point the register pointer at RR0 before
                ; polling status.  On a Z80-SIO-family part the pointer
                ; auto-resets to 0 after each access, so this should be
                ; unnecessary -- but $00 to WR0 is the null command
                ; (pointer := 0, no side effect), it costs two instructions,
                ; and if the auto-reset does NOT behave as assumed the poll
                ; would otherwise read WR5 forever and never transmit.  One
                ; attempt per hardware trip: take the insurance.
                move.b  #0,SIO_A_CTRL
                move.l  #TX_SPIN_LIMIT,d1
.wait:
                btst.b  #RR0_TX_EMPTY,SIO_A_CTRL
                bne.b   .ready
                subq.l  #1,d1
                bne.b   .wait
                ; Timed out.  move.b, not an increment: a read-modify-write
                ; on never-written DRAM is a parity-BERR risk on real
                ; hardware, and this path runs when things are already bad.
                move.b  #1,MON_TXFAIL
                move.l  (sp)+,d1
                rts
.ready:
                move.b  d0,SIO_A_DATA
                move.l  (sp)+,d1
                rts

; ---- getchar: receive byte from SIO chA into d0 ----
;      Deliberately unbounded: waiting indefinitely for a human to type
;      is correct behaviour for a monitor prompt, and a timeout here
;      would just spin the prompt.  The dangerous spin was putchar,
;      which blocks *before* any output exists; that one is bounded
;      above.  If a board goes quiet, MON_TXFAIL distinguishes "TX
;      never became ready" from "nobody typed anything".
getchar:
                move.b  #0,SIO_A_CTRL           ; point at RR0 (see putchar)
.poll:
                btst.b  #RR0_RX_AVAIL,SIO_A_CTRL
                beq.b   .poll
                move.b  SIO_A_DATA,d0
                ; The one escape from a blocking read.  Without it, `L` cannot
                ; be abandoned: mistype the command, or have the sender die
                ; mid-transfer, and the monitor waits forever -- recoverable
                ; only by a power cycle, which on this machine means re-running
                ; the whole boot and losing every breakpoint and tap capture.
                ; ESC is safe as the escape because a valid S-record stream
                ; contains only 'S', hex digits, CR and LF; $1B can never
                ; appear in one.  Costs one tst/beq per character, and
                ; MON_ABORT is zero everywhere except inside L, so ESC stays
                ; an ordinary character at the prompt.
                tst.b   MON_ABORT
                beq.b   .ret
                cmpi.b  #ESC,d0
                beq.w   srec_abort
.ret:
                rts

; ---- srec_abort: unwind an in-flight L back to the prompt ----
srec_abort:
                move.b  #0,MON_ABORT            ; disarm FIRST -- puts below
                                                ;   does not read, but a later
                                                ;   getchar must not re-abort
                movea.l MON_CMDSP,sp            ; three frames deep, so unwind
                                                ;   rather than rts
                lea     abort_msg(pc),a0
                bsr.w   puts
                bra.w   cmd_loop

; ---- puts: print null-terminated string at (a0) ----
;      CLOBBERS d0 AND a0.  a0 is left one PAST the terminator, because that
;      is how the string is walked -- unlike parse_hex, puts cannot save its
;      registers, since advancing a0 IS the operation.  So this contract is
;      documented rather than enforced, and a caller needing either across the
;      call must reload it.  Swept at all 82 call sites: none relies on one.
;      (Two false-positive classes had to be removed before that negative meant
;      anything -- a walker that did not stop at `bra` fell through into puts
;      itself, and `movem.l MON_REGS,d0-d7/a0-a6` WRITES a0 despite naming it.)
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
; TIER 1 — 16- and 32-bit peek/poke
;
; Every one of the 65 device addresses this project's
; reaching-definitions census resolves in the AP I/F and XLTR blocks
; is reached by a WORD access, and the AP I/F block is touched by
; plain `move` only (bar three `cmpi` on $FF0000).  The byte commands
; therefore cannot drive a single chassis register: `m`/`w` use
; move.b, and these are 16-bit-only blocks.
;
; The byte forms are KEPT rather than replaced.  The MC6840 PTM hangs
; off D0-D7 at ODD addresses ($F70001-$F7000F) and MUST be reached
; with move.b; so does the SIO.  Two access widths for two
; differently-wired classes of device.
;
;   mw AAAA [NN]   dump NN words (default 8, cap 64)
;   ml AAAA [NN]   dump NN longs (default 4, cap 32)
;   ww AAAA WWWW.. write words
;   wl AAAA LLLLLLLL.. write longs
;
; Odd addresses are REFUSED rather than attempted.  A word or long
; access at an odd address is an address error on a real 68000, and
; the emulator models it too since M68K_EMULATE_ADDRESS_ERROR was
; switched on — before that it silently completed them, which is how
; a move.w to the odd-byte MC6840 once ran clean in rehearsal.
; grp0_entry would catch the fault and now even reports the address,
; but a refusal names the operator's mistake instead of producing a
; fault report that reads like a dead device.
;================================================================

; ---- xdump: dump d2 items of width d7 (2 or 4) starting at a4 ----
; CONSUMES d2 = item count, d7 = width (2 or 4), a4 = address.
; CLOBBERS  d0, d3, d4, d6, and advances a4.  d3/d4/d6 are the reason
; cmd_page holds its saved MODE2 on the stack rather than in a register:
; a caller that keeps a value in any of the three across this call gets
; garbage back and, if it then prints it, reports a restore that did not
; happen.  Do not add a register to the clobber list without re-auditing
; the four call sites.
xdump:
                tst.l   d2                      ; a zero count would run the
                beq.b   .ret                    ;   item loop 4 billion times
                move.l  d2,d6                   ; items remaining
.line:
                move.l  a4,d0
                bsr.w   puthex_long
                move.b  #':',d0
                bsr.w   putchar
                moveq   #8,d4                   ; 8 words per line
                cmpi.b  #4,d7
                bne.b   .cnt
                moveq   #4,d4                   ; or 4 longs
.cnt:
                cmp.l   d4,d6
                bcc.b   .full                   ; UNSIGNED, as hexdump -- see the
                                                ;   note there.  Same bug, same
                                                ;   shape, in the other shared
                                                ;   dump primitive.
                move.l  d6,d4
.full:
                move.l  d4,d3
.item:
                move.b  #' ',d0
                bsr.w   putchar
                cmpi.b  #4,d7
                beq.b   .l32
                move.w  (a4)+,d0
                bsr.w   puthex_word
                bra.b   .nx
.l32:
                move.l  (a4)+,d0
                bsr.w   puthex_long
.nx:
                subq.l  #1,d3
                bne.b   .item
                bsr.w   put_crlf
                sub.l   d4,d6
                bne.w   .line                   ; not bgt -- see hexdump
.ret:
                rts

; ---- odd_check: d0 = address, d7 = width.  Prints and returns Z=0
;      (via d1=0) if the access would be an address error. ----
odd_check:
                cmpi.b  #1,d7
                beq.b   .ok
                btst    #0,d0
                beq.b   .ok
                lea     odd_msg(pc),a0
                bsr.w   puts
                clr.b   d1
                rts
.ok:
                moveq   #1,d1
                rts

;================================================================
; TIER 2 — device register maps
;
;   x   AP I/F  ($FF0000 bulk window + four channel windows)
;   y   XLTR    ($FF0200 control block + three MC68153 BIMs)
;
; Both walk a ROM table of addresses this project has POSITIVELY
; established, rather than sweeping the block.  Sweeping would touch
; addresses never shown to answer, and an unanswered address on this
; board is a bus error that aborts the dump — so a sweep would be
; both less informative and less safe than a table.
;
; $FF0008 is DELIBERATELY ABSENT from the AP I/F table.  It is the
; bulk data FIFO and READS POP IT: the S-record error paths spin
; `while ($FF0000 > 0) read (a0)` precisely to DRAIN a rejected
; record, and the stream read has no post-increment.  Dumping it as
; part of a register map would silently consume host data.  Use `e`.
;
; $FF0010 is absent because it does not exist: it is a register the
; emulator invented (APIF_CMD_ARG_HI), never accessed statically or
; at runtime.  Window 1 ($FF0020-$FF003F) is absent because the
; firmware's own (ch+1)<<5 arithmetic skips it by construction.
;
; The three BIM registers the firmware never individually programs —
; $FF0240 (BIM1 CR0), $FF0248 (BIM1 VR0) and $FF025E (BIM2 VR3) —
; ARE in the table.  They are written by self-test phase $1600's
; address-indexed walk, so they exist; only the firmware's per-channel
; programming skips them, and a map should show what the hardware has.
;================================================================

; ---- devdump: walk the 12-byte table at a3 ----
;      entry = { addr.l, 7-char name, NUL }.  addr 0 terminates.
devdump:
                move.l  (a3),d0
                beq.b   .end
                bsr.w   puthex_long
                move.b  #' ',d0
                bsr.w   putchar
                lea     4(a3),a0
                bsr.w   puts
                move.b  #'=',d0
                bsr.w   putchar
                move.l  (a3),a0
                move.w  (a0),d0
                bsr.w   puthex_word
                bsr.w   put_crlf
                lea     12(a3),a3
                bra.b   devdump
.end:
                rts

cmd_apif:
                lea     apif_hdr(pc),a0
                bsr.w   puts
                lea     apif_tab(pc),a3
                bsr.w   devdump
                lea     fifo_msg(pc),a0
                bsr.w   puts
                bra.w   cmd_loop

cmd_xltr:
                lea     xltr_hdr(pc),a0
                bsr.w   puts
                lea     xltr_tab(pc),a3
                bsr.w   devdump
                bra.w   cmd_loop

;================================================================
; TIER 3 — an AC channel transaction, by hand
;
;   c CH OP [DD]   CH = 1..4, OP = 16-bit AC operation code, DD = the
;                  optional CONTINUE-phase longword ($8005)
;   ca CH OP       the fire-and-forget acknowledge ($8000), no poll
;
; Reproduces the firmware's own channel transaction primitive at
; $F07F12, which exists in five byte-identical copies (one per XP
; task plus RDHC's, at stride $2858):
;
;   mask the channel's BIM control register to $4F  (IRE cleared)
;   +$08 <- $0000          data high
;   +$0A <- operation code data low
;   +$0E <- $8004          REQUEST-TRANSFER
;   poll +$0E bit 14 = DONE, bit 13 = ERROR, 1000 iterations
;   on error  -> panel $269    on timeout -> panel $26C
;
; The channel window is $FF0000 + ((CH+1) << 5) — the firmware's own
; arithmetic at $F04CAA, which is why window 1 is skipped: (1+1)*32
; starts at $40.  BIM control registers come from the four-longword
; table at $F046E0: $244 $246 $250 $252, indexed by (CH-1)*4.  Note
; that is NOT a uniform stride.
;
; TEARDOWN IS UNCONDITIONAL.  The firmware's teardown clears the
; channel's bit in $FF021A and restores the BIM CR to $5F, and this
; project establishes that a chassis which raises a channel error and
; then ignores the resulting $269 leaves that bit SET and the BIM
; masked at $4F PERMANENTLY — the channel never re-enables and the
; machine degrades one channel at a time in a way that looks like a
; firmware bug.  This command therefore saves BOTH the BIM CR and the
; whole $FF021A word on entry and restores them on every exit path,
; including timeout and error.  Save-and-restore rather than the
; firmware's one-way clear: a probe should leave the machine as it
; found it, and $FF021A is clear-only in the firmware (50 sites, all
; bclr, zero bset) so emulating that here would be a one-shot.
;
; LATCH DISCRIMINATOR.  A model that merely acknowledges looks
; identical to a live AC unless you test for it: the emulator's
; chassis stub never examines the operation code (ch_lo is written
; and never read), so every opcode returns the same status, in ZERO
; polls, with the data pair echoing what was written.  This command
; reports that triple explicitly instead of printing "DONE" and
; letting the operator conclude an AC answered.
;================================================================
cmd_ac:
                addq.l  #1,a6
                ; a2 = form: 0 plain request, 1 request+continue, 2 acknowledge.
                ; a3 = the continue-phase longword.  Both survive parse_hex
                ; (which touches only a6 and d0-d3) and every output routine
                ; (a0/d0/d1), so no workspace word is needed.
                moveq   #0,d0
                move.l  d0,a2
                move.l  d0,a3
                cmpi.b  #'a',(a6)
                bne.b   .noack
                addq.l  #1,a6
                moveq   #2,d0
                move.l  d0,a2                   ; `ca` -- the acknowledge form
.noack:
                bsr.w   skip_ws
                bsr.w   parse_hex
                tst.b   d1
                beq.w   cmd_err
                move.l  d0,d5                   ; d5 = channel
                moveq   #1,d1
                cmp.l   d1,d5
                blt.w   .badch
                moveq   #4,d1
                cmp.l   d1,d5
                bgt.w   .badch
                bsr.w   skip_ws
                bsr.w   parse_hex
                tst.b   d1
                beq.w   cmd_err
                move.w  d0,d6                   ; d6 = opcode

                ; Optional third argument: the CONTINUE-phase longword.
                ; APPENDED, never inserted -- the same discipline as `p`'s
                ; third argument, where putting it second would silently
                ; re-read an existing two-argument command as something else.
                ; `c CH OP` therefore behaves exactly as before.
                move.l  a2,d0
                bne.b   .noc                    ; the acknowledge form takes none
                bsr.w   skip_ws
                bsr.w   parse_hex
                tst.b   d1
                beq.b   .noc
                move.l  d0,a3
                moveq   #1,d0
                move.l  d0,a2
.noc:
                bsr.w   ch_window               ; a4 = window, a5 = BIM CR
                move.w  (a5),d3                 ; save BIM CR
                move.w  $FF021A,d4              ; save IRQ mask word

                move.w  #$4F,(a5)               ; mask this channel

                move.l  a2,d0
                cmpi.l  #2,d0
                beq.w   .ack

                move.w  #0,8(a4)                ; +$08 data high
                move.w  d6,$A(a4)               ; +$0A operation code
                move.w  #$8004,$E(a4)           ; +$0E REQUEST-TRANSFER
                bsr.w   ac_poll                 ; d2 = poll count

                ; --- the latch discriminator ---
                tst.l   d2
                bne.b   .cont_chk               ; it took at least one poll
                move.w  $A(a4),d0
                cmp.w   d6,d0
                bne.b   .cont_chk               ; data low is not our opcode
                lea     ac_latch_msg(pc),a0
                bsr.w   puts
.cont_chk:
                ; --- the CONTINUE phase, $8005 ---
                ; The firmware's primitive is TWO phases, not one: $F07F12
                ; opens with $8004 and $F07F90 then writes d2 across the data
                ; pair and issues $8005 CONTINUE-TRANSFER, polling identically
                ; and reporting panel $26B on error.  A normal channel request
                ; is in fact two back-to-back transactions -- op $10 to open,
                ; then op $0E carrying a longword -- so a command that can only
                ; issue $8004 cannot reproduce one.
                ;
                ; Gated on phase 1 having actually completed: continuing a
                ; transfer that never started would write the pair and issue a
                ; verb into a channel that is not listening.
                move.l  a2,d0
                cmpi.l  #1,d0
                bne.b   .tear
                move.w  $E(a4),d0
                btst    #14,d0                  ; DONE from phase 1?
                beq.b   .tear
                lea     ac_cont_msg(pc),a0
                bsr.w   puts
                move.l  a3,d0
                swap    d0
                move.w  d0,8(a4)                ; +$08 = high half
                move.l  a3,d0
                move.w  d0,$A(a4)               ; +$0A = low half
                move.w  #$8005,$E(a4)           ; CONTINUE-TRANSFER
                bsr.w   ac_poll
                bra.b   .tear

.ack:
                ; --- the acknowledge, $8000 ---
                ; The firmware's sub-mode acknowledge is $F07ECA and its two
                ; siblings: +$08 <- 0, +$0A <- $1B, +$0E <- $8000.  It is
                ; FIRE-AND-FORGET -- all three sites bra.w away immediately,
                ; with no poll and no status read -- because it is the SBC
                ; answering the AC, not asking it.  A chassis owes no response,
                ; so polling here would time out on correct hardware and
                ; report a fault that is not one.  Hence no poll.
                move.w  #0,8(a4)
                move.w  d6,$A(a4)               ; the opcode ($1B in the firmware)
                move.w  #$8000,$E(a4)
                lea     ac_ack_msg(pc),a0
                bsr.w   puts
                ; One status read for the operator's benefit, which the
                ; firmware does NOT do on this path.  Safe because +$0E has no
                ; pop semantics -- the channel ISR and the `x` map both read it
                ; freely; it is $FF0008, the bulk port, whose reads pop.
                move.w  $E(a4),d0
                bsr.w   puthex_word
                lea     ac_data_msg(pc),a0
                bsr.w   puts
                move.w  8(a4),d0
                bsr.w   puthex_word
                move.b  #':',d0
                bsr.w   putchar
                move.w  $A(a4),d0
                bsr.w   puthex_word
                bsr.w   put_crlf
.tear:
                ; $FF021A is deliberately NOT written back.  This command never
                ; modifies it -- it is read at entry and was previously written
                ; back here, a blind word store of a value nothing had changed.
                ;
                ; That store is not merely redundant, it is the one operation no
                ; other code in the machine performs.  The firmware treats
                ; $FF021A as CLEAR-ONLY: 50 read-modify-write sites, every one a
                ; bclr, ZERO bset, and a single literal write ($FFF, in self-test
                ; phase $1600).  So a word write-back can only ever SET bits that
                ; the firmware had deliberately cleared.
                ;
                ; And there is a window for exactly that.  OUR channel's bit
                ; cannot change while we hold its BIM masked at $4F -- but the
                ; other three channels' BIMs are live at level 7, so their ISRs
                ; may legitimately bclr their own bits between our read at entry
                ; and this point.  Writing the whole word back RESURRECTS them,
                ; and the recorded consequence of a stuck $FF021A bit is a
                ; channel that never re-enables: the machine degrades one channel
                ; at a time in a way that looks like a firmware bug.
                ;
                ; The saved word is reported instead, which is the useful half:
                ; the operator can see the mask state that was in force around
                ; the transaction.
                move.w  d3,(a5)                 ; restore BIM CR -- this one WAS
                                                ;   modified, to $4F, and must go
                                                ;   back or the channel stays
                                                ;   masked for good
                lea     ac_tear_msg(pc),a0
                bsr.w   puts
                move.w  d4,d0
                bsr.w   puthex_word
                bsr.w   put_crlf
                bra.w   cmd_loop
.badch:
                lea     ac_ch_msg(pc),a0
                bsr.w   puts
                bra.w   cmd_loop

; ---- ac_poll: poll +$0E for DONE/ERROR, then report the phase ----
;      in : a4 = channel window
;      out: d2 = poll count.  Clobbers d0/d7.
;
;      FACTORED rather than copied.  Both phases of an AC transaction poll
;      identically -- 1000 iterations on bit 14 DONE with bit 13 ERROR, the
;      firmware's own budget -- and this monitor's recorded failure mode is
;      that a rule which grows a second copy diverges: three separate clamp
;      bugs came from exactly that, and srec_check is shared by L, f and b
;      for the same reason.
ac_poll:
                clr.l   d2                      ; poll count
                move.l  #1000,d7
.poll:
                move.w  $E(a4),d0
                btst    #14,d0                  ; DONE
                bne.b   .done
                btst    #13,d0                  ; ERROR
                bne.b   .err
                addq.l  #1,d2
                subq.l  #1,d7
                bne.b   .poll
                lea     ac_to_msg(pc),a0
                bsr.w   puts
                bra.b   .report
.err:
                lea     ac_err_msg(pc),a0
                bsr.w   puts
                bra.b   .report
.done:
                lea     ac_ok_msg(pc),a0
                bsr.w   puts
.report:
                move.w  $E(a4),d0
                bsr.w   puthex_word
                lea     ac_poll_msg(pc),a0
                bsr.w   puts
                move.l  d2,d0
                bsr.w   puthex_long
                lea     ac_data_msg(pc),a0
                bsr.w   puts
                move.w  8(a4),d0
                bsr.w   puthex_word
                move.b  #':',d0
                bsr.w   putchar
                move.w  $A(a4),d0
                bsr.w   puthex_word
                bsr.w   put_crlf
                rts

; ---- ch_window: d5 = channel 1..4 -> a4 = window base, a5 = BIM CR ----
;      window = $FF0000 + ((ch+1) << 5)      [firmware's own $F04CAA]
;      BIM CR = ac_bimcr[(ch-1)]             [firmware's table $F046E0]
ch_window:
                move.l  d5,d0
                addq.l  #1,d0
                lsl.l   #5,d0
                addi.l  #$FF0000,d0
                move.l  d0,a4
                move.l  d5,d0
                subq.l  #1,d0
                lsl.l   #2,d0
                lea     ac_bimcr(pc),a0
                move.l  0(a0,d0.l),a5
                rts

;================================================================
; TIER 4 — resident ISR taps on the four channel BIM vectors
;
;   s     arm taps on channels 1-4
;   s-    disarm, restoring the original vectors
;   sl    list the capture ring
;   sc    clear the ring
;   s+    start PTM timer 3 free-running (--reset image only; the RTOS
;         programs T3 itself, so this is refused when it owns the tick)
;
; This is the tier that argues for ROM residency: everything else the
; probe does can be a transient stub poked into RAM and jumped to, but
; an interrupt handler must still be there when the interrupt arrives.
;
; Vectors $45-$48 are the four XP channel BIMs — $FF0244/$46/$50/$52
; programmed to $5F (level 7, IRE set), with handlers $F07EE6,
; $F074E6, $F06AE6 and $F060CE.  Vector n lives at n*4, so the four
; addresses are $114 $118 $11C $120.
;
; The tap CHAINS: it latches +$0E, +$08 and +$0A into a ring and then
; transfers to the original handler, so on an image where the RTOS is
; running the firmware still services its own channel.  The one
; exception is cold_init's filler — it points all 256 vectors at
; monitor_entry, so a tap that chained there would drop into the
; prompt on every interrupt.  When the saved vector IS monitor_entry
; there is nobody else to service it and the tap simply RTEs.
;
; The three registers latched are exactly the three the firmware's own
; channel ISR latches, into $1066+(ch-1)*6 as {status, data-hi,
; data-lo} — and the task then consumes the data pair as ONE longword
; (move.l $1068,d1 at $F07E20), which is the direct proof that +$08
; and +$0A are halves of a single 32-bit register.
;
; TIMESTAMP: PTM timer THREE ($F7000D MSB, $F7000F LSB), read
; MSB-then-LSB because reading the MSB latches the LSB.  T3 rather
; than T1 for two reasons: it is the counter the firmware's own
; sub-tick clock reads (TRAP #0 $1C at $F00F96), so tap and RTOS agree
; on what time is; and on the PANIC image the RTOS has already
; programmed it, so timestamps work with NO PTM write from us at all.
;
; (The `s+` sub-command and the .startt1 label keep their historical
; names.  They program T3.)
;
; What each image gives you:
;
;   panic   T3 already free-running, latch $27C7, DUAL 8-BIT mode
;           (CR3 = $C6, bit 2).  Timestamps need nothing.  But the
;           halves are INDEPENDENT counters -- the LSB reloads from
;           199, not from 255 -- so a concatenated MSB:LSB read is a
;           usable ORDERING marker and NOT a linear count.  Do not
;           subtract two of them and call the result a duration.
;   --reset no RTOS, so T3 is unprogrammed and reads a constant until
;           `s+`.  There it IS 16-bit continuous, and differences are
;           linear at 1.25 us per count.
;
; `s+` is refused unless the tick vector shows the RTOS is absent --
; see .startt1.  An earlier version of this comment warned instead
; that `s+` leaves CR2's select bit set so "the firmware's next CR3
; write would land on CR1".  That warning was void: the firmware's
; own init ($F0A2DE) leaves the select bit at 1 too, and it sets the
; bit explicitly before touching either register rather than assuming.
; The real hazard is the one now enforced -- `s+` stops the tick.
;================================================================
cmd_tap:
                addq.l  #1,a6
                move.b  (a6),d0
                cmpi.b  #'-',d0
                beq.w   .disarm
                cmpi.b  #'l',d0
                beq.w   .list
                cmpi.b  #'c',d0
                beq.w   .clear
                cmpi.b  #'+',d0
                beq.w   .startt1

                ; ---- arm ----
                ; Refuse a SECOND arm.  The disarm below guards on
                ; MON_TAPMSK and this did not, so `s` twice re-ran the save
                ; loop against vectors that already held tap1..tap4 -- the
                ; taps saved THEMSELVES into MON_TAPSAV.  Measured: after
                ; the second `s`, MON_TAPSAV read 00F0B8B8 00F0B8C0
                ; 00F0B8C8 00F0B8D0, and `s-` then "restored" those over
                ; the vectors, leaving the taps permanently installed while
                ; reporting success.
                ;
                ; On the panic image it is worse than untidy: the saved
                ; vector is a real firmware ISR there, so tap_body's
                ; `cmpi.l #monitor_entry,d1` no longer matches, and the
                ; chain jumps to MON_TAPSAV[ch] -- which is now the tap
                ; itself.  It re-captures, re-chains, and never reaches an
                ; rte, so the BIM is never acknowledged: typing `s` twice
                ; HANGS THE BOARD inside the ISR.  Stack-neutral per pass
                ; (movem push, movem pop, push 4, rts pops 4), so it does
                ; not even overflow into something noticeable -- it just
                ; stops.
                tst.b   MON_TAPMSK
                bne.w   .rearm
                lea     tap_vec(pc),a0          ; tap entry points
                lea     MON_TAPSAV,a1
                moveq   #0,d2                   ; channel index 0..3
.aloop:
                move.l  d2,d0
                lsl.l   #2,d0
                lea     $114,a2
                adda.l  d0,a2                   ; a2 = vector address
                move.l  (a2),(a1)               ; save original
                move.l  0(a0,d0.l),(a2)         ; install tap
                addq.l  #4,a1
                addq.l  #1,d2
                cmpi.l  #4,d2
                blt.b   .aloop
                move.b  #$0F,MON_TAPMSK
                lea     tap_on_msg(pc),a0
                bsr.w   puts
                bra.w   cmd_loop

.disarm:
                tst.b   MON_TAPMSK
                beq.w   .notarmed
                lea     MON_TAPSAV,a1
                moveq   #0,d2
.dloop:
                move.l  d2,d0
                lsl.l   #2,d0
                lea     $114,a2
                adda.l  d0,a2
                move.l  (a1),(a2)               ; restore original
                addq.l  #4,a1
                addq.l  #1,d2
                cmpi.l  #4,d2
                blt.b   .dloop
                move.b  #0,MON_TAPMSK
                lea     tap_off_msg(pc),a0
                bsr.w   puts
                bra.w   cmd_loop

.notarmed:
                lea     tap_noarm_msg(pc),a0
                bsr.w   puts
                bra.w   cmd_loop

.rearm:
                lea     tap_rearm_msg(pc),a0
                bsr.w   puts
                bra.w   cmd_loop

.clear:
                move.w  #0,MON_RINGHD
                move.w  #0,MON_RINGN
                move.w  #0,MON_RINGOV
                lea     ok_msg(pc),a0
                bsr.w   puts
                bra.w   cmd_loop

.startt1:
                ; REFUSE if the RTOS owns the tick.  Every step below is
                ; destructive to it: CR1 bit 0 asserts the CHIP-WIDE
                ; internal reset (all three timers, not just T3), CR3=$02
                ; replaces dual-8-bit with 16-bit continuous AND clears
                ; bit 6 so T3 stops interrupting, and the $FFFF latch
                ; replaces the firmware's $27C7 -- (39+1)*(199+1) = 8000
                ; E cycles = exactly 10.0000 ms.  Run on the panic image
                ; this does not corrupt a timestamp, it stops the RTOS
                ; system tick.
                ;
                ; The test is the tick's own vector.  $1C is the level-4
                ; autovector the tick uses, at $1C*4 = $70, and the
                ; kernel's static table at $F00114 puts $F00EC8 there.
                ; cold_init fills all 256 with monitor_entry, so on the
                ; --reset image it reads monitor_entry and s+ proceeds.
                cmpi.l  #monitor_entry,$70
                bne.w   .tickowned
                ; Free-run T3 for timestamps, in the firmware's own order
                ; ($F0A294-$F0A2E4): assert the internal reset, load the
                ; latch, configure, release.  A model that ignores that
                ; ordering loads a latch into a running timer.
                move.b  #$01,$F70003            ; CR2 bit0=1 -> +$1 is CR1
                move.b  #$01,$F70001            ; CR1 bit0=1 -> INTERNAL
                                                ;   RESET: holds ALL THREE
                                                ;   timers, not just T1
                move.b  #$00,$F70003            ; CR2 bit0=0 -> +$1 is CR3
                move.b  #$02,$F70001            ; CR3: 16-bit, continuous,
                                                ;   internal E clock, IRQ
                                                ;   DISABLED (bit 6 = 0)
                move.b  #$FF,$F7000D            ; T3 latch MSB
                move.b  #$FF,$F7000F            ; T3 latch LSB -> 65536
                                                ;   counts = 82 ms wrap at
                                                ;   1.25 us resolution
                move.b  #$01,$F70003            ; select CR1 again
                move.b  #$00,$F70001            ; release the reset: the
                                                ;   timers start HERE
                lea     tap_t1_msg(pc),a0
                bsr.w   puts
                bra.w   cmd_loop
.tickowned:
                lea     tap_tick_msg(pc),a0
                bsr.w   puts
                bra.w   cmd_loop

.list:
                lea     tap_hdr_msg(pc),a0
                bsr.w   puts
                move.w  MON_RINGN,d6
                tst.w   d6
                beq.w   .empty
                cmpi.w  #MON_RING_N,d6
                ble.b   .have
                move.w  #MON_RING_N,d6
.have:
                ; oldest first: start at (head - n) mod N
                move.w  MON_RINGHD,d5
                sub.w   d6,d5
                bge.b   .lloop
                addi.w  #MON_RING_N,d5
.lloop:
                move.w  d5,d0
                andi.l  #$FFFF,d0
                mulu.w  #MON_RING_SZ,d0
                lea     MON_RING,a4
                adda.l  d0,a4
                move.b  8(a4),d0                ; channel
                bsr.w   puthex_byte
                move.b  #' ',d0
                bsr.w   putchar
                move.w  (a4),d0                 ; timestamp
                bsr.w   puthex_word
                move.b  #' ',d0
                bsr.w   putchar
                move.w  2(a4),d0                ; status
                bsr.w   puthex_word
                move.b  #' ',d0
                bsr.w   putchar
                move.w  4(a4),d0                ; data hi
                bsr.w   puthex_word
                move.b  #':',d0
                bsr.w   putchar
                move.w  6(a4),d0                ; data lo
                bsr.w   puthex_word
                bsr.w   put_crlf
                addq.w  #1,d5
                cmpi.w  #MON_RING_N,d5
                blt.b   .nowr
                move.w  #0,d5
.nowr:
                subq.w  #1,d6
                bne.b   .lloop
                lea     tap_ov_msg(pc),a0
                bsr.w   puts
                move.w  MON_RINGOV,d0
                bsr.w   puthex_word
                bsr.w   put_crlf
                bra.w   cmd_loop
.empty:
                lea     tap_empty_msg(pc),a0
                bsr.w   puts
                bra.w   cmd_loop

; ---- the four tap entry points ----
tap1:           movem.l d0-d2/a0-a1,-(sp)
                moveq   #1,d2
                bra.b   tap_body
tap2:           movem.l d0-d2/a0-a1,-(sp)
                moveq   #2,d2
                bra.b   tap_body
tap3:           movem.l d0-d2/a0-a1,-(sp)
                moveq   #3,d2
                bra.b   tap_body
tap4:           movem.l d0-d2/a0-a1,-(sp)
                moveq   #4,d2

tap_body:
                ; channel window = $FF0000 + ((ch+1) << 5)
                move.l  d2,d0
                addq.l  #1,d0
                lsl.l   #5,d0
                addi.l  #$FF0000,d0
                move.l  d0,a0

                ; ring slot
                move.w  MON_RINGHD,d0
                andi.l  #$FFFF,d0
                mulu.w  #MON_RING_SZ,d0
                lea     MON_RING,a1
                adda.l  d0,a1

                ; Timestamp: PTM TIMER 3, read MSB then LSB because reading
                ; the MSB latches the LSB.  T3 rather than T1 because on
                ; the panic image the RTOS has ALREADY programmed it --
                ; latch $27C7 = (4*10-1)<<8 | (800/4-1), dual 8-bit, giving
                ; a 10.0000 ms tick at E = 800 kHz -- so the tap needs no
                ; PTM writes at all in the configuration that matters, and
                ; it reads the very counter the firmware's own sub-tick
                ; clock reads (TRAP #0 $1C at $F00F96).  On the --reset
                ; image T3 is unprogrammed and this column reads a
                ; constant, which is self-evidently not a timestamp; `s+`
                ; starts it there.
                ;
                ; DUAL 8-BIT is not 16-bit: the halves count
                ; independently and the LSB reloads from 199, not 255.
                ; So on the panic image this concatenation ORDERS events
                ; and does not MEASURE them -- subtracting two of these
                ; over-counts by 256/200 per MSB step.  Linear only on
                ; the --reset image after `s+` (16-bit continuous).
                move.b  $F7000D,d1
                lsl.w   #8,d1
                move.b  $F7000F,d1
                move.w  d1,(a1)+
                move.w  $E(a0),(a1)+            ; status
                move.w  8(a0),(a1)+             ; data high
                move.w  $A(a0),(a1)+            ; data low
                move.b  d2,(a1)+                ; channel
                move.b  #0,(a1)+

                ; advance head, count, overruns
                move.w  MON_RINGHD,d0
                addq.w  #1,d0
                cmpi.w  #MON_RING_N,d0
                blt.b   .nowrap
                move.w  #0,d0
                move.w  MON_RINGOV,d1
                addq.w  #1,d1
                move.w  d1,MON_RINGOV
.nowrap:
                move.w  d0,MON_RINGHD
                move.w  MON_RINGN,d1
                cmpi.w  #MON_RING_N,d1
                bge.b   .nosat
                addq.w  #1,d1
                move.w  d1,MON_RINGN
.nosat:
                ; chain to the original handler, or RTE if the saved
                ; vector is cold_init's filler and there is nobody else
                move.l  d2,d0
                subq.l  #1,d0
                lsl.l   #2,d0
                lea     MON_TAPSAV,a0
                move.l  0(a0,d0.l),d1
                cmpi.l  #monitor_entry,d1
                beq.b   .own
                lea     MON_TAPTGT,a0
                move.l  d1,0(a0,d0.l)           ; this channel's OWN slot
                ; rts pops the target we push below and jumps to it, leaving the
                ; exception frame beneath it untouched for the original handler's
                ; own rte.  The target has to survive the movem that restores
                ; d0-d2/a0-a1 -- every one of which the chained handler expects
                ; to see as it was at interrupt time -- so it cannot stay in a
                ; register, and after the restore there is no register left to
                ; index with either.  Hence four fixed slots and a dispatch on
                ; the channel while d2 is still live.
                ;
                ; It used to be ONE slot, justified as "all four channel BIMs are
                ; level 7 and a 68000 masks the level it is already servicing, so
                ; two channel taps cannot nest".  That is wrong, and this file
                ; says so twelve hundred lines up: mon_dead's comment notes that
                ; "STOP with IPL 7 still admits a level-7 NMI".  Level 7 is
                ; non-maskable on a 68000 -- it is transition-sensitive, not
                ; level-sensitive against the mask -- so a second BIM asserting
                ; while the first is being serviced IS taken.  The window was the
                ; three instructions below: channel 2 would overwrite the slot and
                ; channel 1 would then chain into channel 2's ISR, which reads the
                ; wrong window and leaves channel 1 unacknowledged.  Narrow (~4 us
                ; at 8 MHz) and real.  Per-channel slots close it for distinct
                ; channels; a channel re-interrupting inside its own three
                ; instructions is all that remains, and the BIM's IRE is cleared
                ; during service.
                cmpi.b  #2,d2
                beq.b   .ch2
                cmpi.b  #3,d2
                beq.b   .ch3
                cmpi.b  #4,d2
                beq.b   .ch4
                movem.l (sp)+,d0-d2/a0-a1
                move.l  MON_TAPTGT,-(sp)
                rts
.ch2:
                movem.l (sp)+,d0-d2/a0-a1
                move.l  MON_TAPTGT+4,-(sp)
                rts
.ch3:
                movem.l (sp)+,d0-d2/a0-a1
                move.l  MON_TAPTGT+8,-(sp)
                rts
.ch4:
                movem.l (sp)+,d0-d2/a0-a1
                move.l  MON_TAPTGT+12,-(sp)
                rts
.own:
                movem.l (sp)+,d0-d2/a0-a1
                rte

;================================================================
; TIER 5 — the bulk path, the chassis window and the ready flag
;
;   e [NN]      drain NN words from the bulk data port
;   p PP [NN [OO]]     read NN longs at page PP, byte offset OO
;   pw PP OO VV [VV..] write longs at page PP, byte offset OO
;   q           bounded poll of $FF0004 bit 0
;
; --- e ---
; Reproduces TCBRDHC's polled bulk loop at $F04AE2: arm
; XLTR_STATUS_IRQ ($FF0218) with $400 — bit 10, the arm — poll bit 15
; for done, clear, then `move.w (a0),(a1)+` with a0 = $FF0008.  The
; firmware writes XLTR_COUNTER ($FF020C) = 4 when the bulk port is the
; source, which is the concrete role of that register.
;
; It reads $FF0000 BEFORE and AFTER the drain, because that is the one
; SBC-visible test of whether the word count is a hardware down-counter.
; The firmware only ever COMPARES that register — three cmpi, never a
; move — and never writes it, while its value decreases as the FIFO is
; popped; and the AP I/F photograph carries six 74S169 synchronous
; UP/DOWN counters against three up-only parts.  Firmware evidence and
; silicon agree and neither was derived from the other.  If the count
; does not fall, either the port is not being popped or the counter is
; not loaded — and this prints both readings so the operator can tell.
;
; --- p ---
; MODE2 ($FF0210) is the page register for the $400000 window:
; page = addr >> 20, offset = (addr & $FFFFF) << 2, so one page is 1M
; longwords and the field is 12 bits — 4096 pages, not the 4 bits the
; observed $0/$F suggest.  MODE2 is saved and restored, because the
; firmware itself saves and restores it in all four of its disciplines
; and RTOS init forces it to zero; leaving it changed would put a later
; operation on the wrong page with no path to correction.
;
; --- q ---
; All eleven $FF0004 sites in the firmware are byte-identical UNBOUNDED
; spins: move.w, btst #0, beq back, with no counter and no exit but
; success.  That makes it the hardest obligation on the board — a model
; that never raises it produces no diagnostic at all — so the one thing
; a probe must not do is reproduce the unbounded spin.  This one counts.
;================================================================
cmd_bulk:
                addq.l  #1,a6
                bsr.w   skip_ws
                moveq   #8,d5                   ; default words
                move.b  (a6),d0
                beq.b   .havecnt
                bsr.w   parse_hex
                tst.b   d1
                beq.w   cmd_err
                move.l  d0,d5
                ; Two ways a typo used to run the .drain loop 2^32 times,
                ; popping the $FF0008 FIFO and writing 8 GB through a 640-byte
                ; ring.  xdump's own guard is downstream and cannot help --
                ; .drain runs first.
                tst.l   d5
                beq.w   cmd_err                 ; `e 0`: subq/bne wraps to -1
                cmpi.l  #64,d5
                bls.b   .havecnt                ; UNSIGNED -- `ble` let every
                                                ;   value >= $80000000 through
                                                ;   the clamp as "negative"
                moveq   #64,d5
.havecnt:
                lea     bulk_arm_msg(pc),a0
                bsr.w   puts
                move.w  #$400,$FF0218           ; arm
                move.l  #$20000,d7
.wait:
                move.w  $FF0218,d0
                btst    #15,d0
                bne.b   .ready
                subq.l  #1,d7
                bne.b   .wait
                lea     bulk_to_msg(pc),a0
                bsr.w   puts
                move.w  #0,$FF0218
                bra.w   cmd_loop
.ready:
                move.w  #0,$FF0218              ; clear the arm
                ; $FF020C is READABLE and was the one device this monitor
                ; changed without putting back -- cmd_ac restores the BIM CR
                ; and $FF021A, cmd_page restores MODE2, cmd_tap restores the
                ; vectors, and this did not.  4 is the operational value at
                ; all seven firmware sites, so the write is usually a no-op;
                ; $01 and $FF are the boot-diagnostic values, and silently
                ; overwriting one of those is how a probe changes the state
                ; it was brought in to observe.  On the STACK, not a
                ; register: xdump below clobbers d3/d4/d6.
                move.w  $FF020C,-(sp)
                move.w  #4,$FF020C              ; counter/config, bulk source
                move.w  $FF0000,d6              ; count BEFORE
                lea     bulk_pre_msg(pc),a0
                bsr.w   puts
                move.w  d6,d0
                bsr.w   puthex_word
                bsr.w   put_crlf

                ; Borrowing the tap ring as scratch destroys whatever the tap
                ; captured, so invalidate its bookkeeping FIRST -- otherwise a
                ; later `sl` prints bulk words as if they were channel
                ; interrupts, with fabricated timestamps and channel numbers.
                ; Arming the tap and then running `e` to see whether the drain
                ; raises an interrupt is a sensible experiment; silently
                ; mislabelling the result is not.  A capture that reports the
                ; wrong value is worse than none, because it is believed.
                move.w  #0,MON_RINGHD
                move.w  #0,MON_RINGN
                move.w  #0,MON_RINGOV
                lea     MON_RING,a4             ; land the words in the ring
                move.l  d5,d3
.drain:
                move.w  $FF0008,(a4)+
                subq.l  #1,d3
                bne.b   .drain

                move.w  $FF0000,d4              ; count AFTER
                lea     bulk_post_msg(pc),a0
                bsr.w   puts
                move.w  d4,d0
                bsr.w   puthex_word
                bsr.w   put_crlf
                ; UNSIGNED, and this is the FOURTH instance of the same bug
                ; -- the clamp twenty lines up already carries the comment
                ; "UNSIGNED -- `ble` let every value >= $80000000 through",
                ; and this comparison in the SAME routine was missed.
                ;
                ; d6 is the count BEFORE and d4 the count AFTER, both read
                ; from $FF0000, which the record establishes as a HARDWARE
                ; DOWN-COUNTER loaded off-card by the host -- six 74S169
                ; up/down parts against three up-only, and the CPU never
                ; writes it.  A microcode bank is $8000 words, so counts
                ; above $7FFF are ordinary rather than exotic.
                ;
                ; With bge, a count falling $8000 -> $7FFF (a decrement of
                ; exactly one) reads as +32767 >= -32768 and reports "count
                ; did NOT fall"; a count RISING $7FFF -> $8000 reports that
                ; it fell.  Both inversions land on the one operation this
                ; command exists for: draining a bulk microcode load.
                cmp.w   d6,d4
                bcc.b   .nodec
                lea     bulk_dec_msg(pc),a0
                bra.b   .say
.nodec:
                lea     bulk_flat_msg(pc),a0
.say:
                bsr.w   puts
                lea     MON_RING,a4
                move.l  d5,d2
                moveq   #2,d7
                bsr.w   xdump
                move.w  (sp)+,$FF020C           ; put the counter/config back
                                                ;   (pushed at .ready; the
                                                ;   timeout path exits before
                                                ;   the push, so both exits
                                                ;   leave the stack balanced)
                bra.w   cmd_loop

cmd_page:
                addq.l  #1,a6
                cmpi.b  #'w',(a6)
                beq.w   .write
                bsr.w   skip_ws
                bsr.w   parse_hex
                tst.b   d1
                beq.w   cmd_err
                andi.l  #$FFF,d0                ; 12-bit page field
                move.w  d0,d5
                bsr.w   skip_ws
                moveq   #4,d6                   ; default longs
                move.b  (a6),d0
                beq.b   .havecnt
                bsr.w   parse_hex
                tst.b   d1
                beq.w   cmd_err
                move.l  d0,d6
                cmpi.l  #32,d6
                bls.b   .havecnt                ; UNSIGNED, as cmd_bulk: a
                                                ;   signed `ble` passed every
                                                ;   value >= $80000000 through
                                                ;   unclamped, and xdump would
                                                ;   then walk 2^32 longs off
                                                ;   the $400000 window.  Zero
                                                ;   is safe -- xdump guards it.
                moveq   #32,d6
.havecnt:
                ; Optional THIRD argument: a byte offset within the window.
                ; Appended rather than inserted so `p PP NN` keeps meaning
                ; what it always did -- inserting the offset second would
                ; silently re-read `p 0 4` as "page 0, offset 4".
                ;
                ; Without it the pair is asymmetric: pw writes at any
                ; offset and p could only read offset 0, so verifying a
                ; non-zero-offset write meant `ww FF0210 nnnn` + `ml` --
                ; the two-step that leaves MODE2 selected, which is exactly
                ; what pw exists to avoid.  A write command whose result
                ; can only be checked unsafely is not much of a win.
                moveq   #0,d4                   ; default offset
                bsr.w   skip_ws
                tst.b   (a6)
                beq.b   .haveoff
                bsr.w   parse_hex
                tst.b   d1
                beq.w   cmd_err
                andi.l  #$3FFFFC,d0             ; long-aligned, in-window.
                                                ;   $3FFFFC because ONE PAGE
                                                ;   IS 4 MB: the effective
                                                ;   longword index is
                                                ;   (MODE2 << 20) | (off >> 2),
                                                ;   so off >> 2 spans 20 bits.
                                                ;   Do NOT shrink this to
                                                ;   $FFFFC -- the emulator
                                                ;   models only the first 1 MB
                                                ;   (CHASSIS_MEM_SIZE, flagged
                                                ;   "not derived" in its own
                                                ;   source), so offsets
                                                ;   >= $100000 bus-error THERE
                                                ;   and are valid on iron.
                                                ;   The fault is reported with
                                                ;   its address, which is the
                                                ;   diagnostic working.
                ;
                ; A 20-bit offset makes the HOST MAILBOX reachable, which
                ; is worth stating because it is not obvious: $70001C is
                ; inside this window at page $F, offset $70001C-$400000 =
                ; $30001C.  So
                ;
                ;     p F 2 30001C
                ;
                ; reads the mailbox pair the firmware's TCBIO1I ISR uses
                ; ($70001C request, $700020 reply), and the ISR reaches it
                ; the same way -- it saves MODE2, writes $F, touches the
                ; pair, restores.  The mailbox is only valid at page $F.
                ;
                ; READING is harmless.  WRITING it with `pw` on the panic
                ; image is not: bit 29 is the host's "needs attention"
                ; flag and the class field at bits 16-17 selects the ISR's
                ; arm, so a poke can hand TCBIO1I a request no host made.
                ; The emulator's 1 MB window bus-errors at this offset;
                ; hardware does not.
                move.l  d0,d4
.haveoff:
                ; Save MODE2 on the STACK, not in a register: xdump uses
                ; d3/d4/d6 for its own line arithmetic, and holding the
                ; saved page in d4 across the call restored garbage --
                ; which read as "MODE2 restored to $0004" on a page that
                ; had been $0000.  A restore that reports the wrong value
                ; is worse than none, because it is believed.
                move.w  $FF0210,-(sp)           ; save MODE2
                move.w  d5,$FF0210
                lea     $400000,a4
                adda.l  d4,a4                   ; d4 is free again after xdump,
                                                ;   which is where the restore
                                                ;   below reloads it
                move.l  d6,d2
                moveq   #4,d7
                bsr.w   xdump
                move.w  (sp)+,d4
                move.w  d4,$FF0210              ; restore MODE2
                lea     page_rest_msg(pc),a0
                bsr.w   puts
                move.w  d4,d0
                bsr.w   puthex_word
                bsr.w   put_crlf
                bra.w   cmd_loop

.write:
                ; pw PAGE OFF VAL [VAL...] -- write consecutive LONGS into
                ; the paged chassis window, saving and restoring MODE2.
                ;
                ; This exists because the two-step workaround is a footgun.
                ; `ww FF0210 000F` + `wl 400080 ...` already works, and
                ; leaves MODE2 SET -- and MODE2's post-boot value is defined
                ; and is ZERO, forced by RTOS init at $F0A1FE and again by
                ; self-test phase $1600.  Nothing after init ever changes
                ; the resting page: op $3, RDHC's command path and TCBIO1I
                ; all save and restore it.  So a stale MODE2 sends RDHC's
                ; next command fetch to the wrong page with no path to
                ; correction, and the failure surfaces later as a bad
                ; command record rather than as a wrong-page fault.  Making
                ; the safe form the easy form is the whole point.
                ;
                ; The SBC genuinely writes SCM this way: op $3's write arm
                ; assembles a 32-bit word from $FF0204 in two halves, pages
                ; via $FF0210, and stores with move.l $e70,(a1,d1.l) --
                ; measured at 219 stores into the window in a driven boot.
                ;
                ; LIMITATION, shared with the read path above: if the window
                ; bus-errors mid-write, grp0_entry takes over and the
                ; stack-saved MODE2 is lost with the frame, so the page is
                ; left selected.  The fault address is reported, so the
                ; condition is visible; `p 0` afterwards re-selects page 0.
                addq.l  #1,a6                   ; past the 'w'
                bsr.w   skip_ws
                bsr.w   parse_hex
                tst.b   d1
                beq.w   cmd_err
                andi.l  #$FFF,d0                ; 12-bit page field, as `p`
                move.w  d0,d5
                bsr.w   skip_ws
                bsr.w   parse_hex
                tst.b   d1
                beq.w   cmd_err
                andi.l  #$3FFFFC,d0             ; long-aligned, inside the
                                                ;   4 MB window.  Masking
                                                ;   rather than rejecting
                                                ;   matches `p`'s treatment
                                                ;   of the page field, and an
                                                ;   odd offset would address-
                                                ;   error on the move.l.
                move.l  d0,d4
                bsr.w   skip_ws
                tst.b   (a6)                    ; at least one value
                beq.w   cmd_err
                move.w  $FF0210,-(sp)           ; save MODE2 -- on the STACK,
                                                ;   for the reason the read
                                                ;   path documents above
                move.w  d5,$FF0210
                lea     $400000,a4
                adda.l  d4,a4
                moveq   #0,d6                   ; longs written
.wloop:
                bsr.w   skip_ws
                tst.b   (a6)
                beq.b   .wdone
                bsr.w   parse_hex
                tst.b   d1
                beq.b   .wdone                  ; trailing junk ends the list
                                                ;   rather than aborting a
                                                ;   half-done write
                move.l  d0,(a4)+
                addq.l  #1,d6
                bra.b   .wloop
.wdone:
                move.w  (sp)+,d5
                move.w  d5,$FF0210              ; restore MODE2
                move.l  d6,d0
                bsr.w   puthex_byte
                lea     pagew_msg(pc),a0
                bsr.w   puts
                move.w  d5,d0
                bsr.w   puthex_word
                bsr.w   put_crlf
                bra.w   cmd_loop

cmd_ready:
                lea     rdy_msg(pc),a0
                bsr.w   puts
                clr.l   d2
                move.l  #$20000,d7
.poll:
                move.w  $FF0004,d0
                btst    #0,d0
                bne.b   .set
                addq.l  #1,d2
                subq.l  #1,d7
                bne.b   .poll
                lea     rdy_no_msg(pc),a0
                bra.b   .say
.set:
                lea     rdy_yes_msg(pc),a0
.say:
                bsr.w   puts
                move.l  d2,d0
                bsr.w   puthex_long
                lea     rdy_val_msg(pc),a0
                bsr.w   puts
                move.w  $FF0004,d0
                bsr.w   puthex_word
                bsr.w   put_crlf
                bra.w   cmd_loop

;================================================================
; TIER 6 — region arithmetic
;
;   z AAAA NNNN         XOR and additive sum of a region, as words
;   f AAAA NNNN VVVV    fill a region with a word
;
; Both exist because the link is 9600 baud.  Verifying 64 KB of ROM by
; dumping it is ~512 round trips and about six minutes; `z F00000 10000`
; is one round trip, and reproduces self-test phase $300 exactly — that
; phase XORs every word of the ROM and requires zero, retrying forever
; on a mismatch, which is why patch_rom.py recomputes the trailing word.
;
; XOR catches bit errors.  It cannot see ORDERING, so the additive sum
; runs in the same pass: two accumulators, one traversal.
;================================================================
cmd_sum:
                addq.l  #1,a6
                bsr.w   skip_ws
                bsr.w   parse_hex
                tst.b   d1
                beq.w   cmd_err
                move.l  d0,d4                   ; start
                moveq   #2,d7                   ; word access, for odd_check
                bsr.w   odd_check
                tst.b   d1
                beq.w   cmd_loop
                bsr.w   skip_ws
                bsr.w   parse_hex
                tst.b   d1
                beq.w   cmd_err
                ; UNSIGNED bound, as everywhere else in this monitor: the
                ; whole 68000 address space is $1000000 bytes, a few
                ; seconds at 8 MHz.  A signed compare here would be the
                ; fourth instance of the bug fixed at cmd_mem/cmd_page/
                ; cmd_bulk.
                cmpi.l  #$1000000,d0
                bls.b   .havelen
                move.l  #$1000000,d0
.havelen:
                lsr.l   #1,d0                   ; bytes -> words
                beq.w   cmd_err                 ; a zero count would wrap
                move.l  d0,d3
                move.l  d4,a4
                clr.l   d5                      ; XOR accumulator
                clr.l   d6                      ; additive sum
.lp:
                move.w  (a4)+,d0
                eor.w   d0,d5
                andi.l  #$FFFF,d0
                add.l   d0,d6
                subq.l  #1,d3
                bne.b   .lp
                lea     sum_x_msg(pc),a0        ; puts/puthex clobber d0 only,
                bsr.w   puts                    ;   so d5 and d6 survive
                move.w  d5,d0
                bsr.w   puthex_word
                lea     sum_a_msg(pc),a0
                bsr.w   puts
                move.l  d6,d0
                bsr.w   puthex_long
                bsr.w   put_crlf
                bra.w   cmd_loop

;----------------------------------------------------------------
; f AAAA NNNN VVVV — fill words
;
; Bounds-checked through srec_check, the same audited checker the S-record
; loader uses: it refuses the vector table, anything at or above $20000,
; and anything reaching this monitor's own workspace or stack.  Filling
; over MON_BASE would destroy the stack the fill is running on.
;
; Deliberate pokes at devices and ROM space are what `w` is for; a fill
; is a RAM operation and is guarded like one.
;----------------------------------------------------------------
cmd_fill:
                addq.l  #1,a6
                bsr.w   skip_ws
                bsr.w   parse_hex
                tst.b   d1
                beq.w   cmd_err
                move.l  d0,d4                   ; start
                moveq   #2,d7
                bsr.w   odd_check
                tst.b   d1
                beq.w   cmd_loop
                bsr.w   skip_ws
                bsr.w   parse_hex
                tst.b   d1
                beq.w   cmd_err
                move.l  d0,d2                   ; byte count, for srec_check
                move.l  d4,d3                   ; start,      for srec_check
                bsr.w   srec_check              ; clobbers d1 only
                tst.b   d1
                beq.w   .refuse
                move.l  d2,d0
                lsr.l   #1,d0                   ; bytes -> words
                beq.w   cmd_err
                move.l  d0,d3
                bsr.w   skip_ws
                bsr.w   parse_hex
                tst.b   d1
                beq.w   cmd_err
                move.w  d0,d5                   ; fill value
                move.l  d4,a4
.lp:
                move.w  d5,(a4)+
                subq.l  #1,d3
                bne.b   .lp
                lea     fill_ok_msg(pc),a0
                bsr.w   puts
                bra.w   cmd_loop
.refuse:
                lea     fill_no_msg(pc),a0
                bsr.w   puts
                bra.w   cmd_loop

;================================================================
; Tables
;================================================================

; BIM control registers, one per XP channel.  From the firmware's own
; four-longword table at $F046E0 — note the stride is NOT uniform.
ac_bimcr:
                dc.l    $FF0244                 ; ch1  vector $45
                dc.l    $FF0246                 ; ch2  vector $46
                dc.l    $FF0250                 ; ch3  vector $47
                dc.l    $FF0252                 ; ch4  vector $48

tap_vec:
                dc.l    tap1
                dc.l    tap2
                dc.l    tap3
                dc.l    tap4

; ---- AP I/F: the bulk window plus four channel windows ----
apif_tab:
                dc.l    $FF0000
                dc.b    "WCNT   ",0
                dc.l    $FF0004
                dc.b    "READY  ",0
                dc.l    $FF000E
                dc.b    "CMD/ST ",0
                dc.l    $FF0044
                dc.b    "C1 WR  ",0
                dc.l    $FF0048
                dc.b    "C1 DHI ",0
                dc.l    $FF004A
                dc.b    "C1 DLO ",0
                dc.l    $FF004E
                dc.b    "C1 CMD ",0
                dc.l    $FF0064
                dc.b    "C2 WR  ",0
                dc.l    $FF0068
                dc.b    "C2 DHI ",0
                dc.l    $FF006A
                dc.b    "C2 DLO ",0
                dc.l    $FF006E
                dc.b    "C2 CMD ",0
                dc.l    $FF0084
                dc.b    "C3 WR  ",0
                dc.l    $FF0088
                dc.b    "C3 DHI ",0
                dc.l    $FF008A
                dc.b    "C3 DLO ",0
                dc.l    $FF008E
                dc.b    "C3 CMD ",0
                dc.l    $FF00A4
                dc.b    "C4 WR  ",0
                dc.l    $FF00A8
                dc.b    "C4 DHI ",0
                dc.l    $FF00AA
                dc.b    "C4 DLO ",0
                dc.l    $FF00AE
                dc.b    "C4 CMD ",0
                dc.l    0

; ---- XLTR: control block plus three MC68153 BIMs ----
xltr_tab:
                dc.l    $FF0200
                dc.b    "MODE0  ",0
                dc.l    $FF0202
                dc.b    "MODE1  ",0
                dc.l    $FF0204
                dc.b    "CHSEL  ",0
                dc.l    $FF020C
                dc.b    "COUNTER",0
                dc.l    $FF0210
                dc.b    "MODE2  ",0
                dc.l    $FF0212
                dc.b    "M2+2   ",0
                dc.l    $FF0214
                dc.b    "DATA   ",0
                dc.l    $FF0216
                dc.b    "CTLBITS",0
                dc.l    $FF0218
                dc.b    "STATUS ",0
                dc.l    $FF021A
                dc.b    "IRQMASK",0
                dc.l    $FF0230
                dc.b    "B0 CR0 ",0
                dc.l    $FF0232
                dc.b    "B0 CR1 ",0
                dc.l    $FF0234
                dc.b    "B0 CR2 ",0
                dc.l    $FF0236
                dc.b    "B0 CR3 ",0
                dc.l    $FF0238
                dc.b    "B0 VR0 ",0
                dc.l    $FF023A
                dc.b    "B0 VR1 ",0
                dc.l    $FF023C
                dc.b    "B0 VR2 ",0
                dc.l    $FF023E
                dc.b    "B0 VR3 ",0
                dc.l    $FF0240
                dc.b    "B1 CR0 ",0
                dc.l    $FF0242
                dc.b    "B1 CR1 ",0
                dc.l    $FF0244
                dc.b    "B1 CR2 ",0
                dc.l    $FF0246
                dc.b    "B1 CR3 ",0
                dc.l    $FF0248
                dc.b    "B1 VR0 ",0
                dc.l    $FF024A
                dc.b    "B1 VR1 ",0
                dc.l    $FF024C
                dc.b    "B1 VR2 ",0
                dc.l    $FF024E
                dc.b    "B1 VR3 ",0
                dc.l    $FF0250
                dc.b    "B2 CR0 ",0
                dc.l    $FF0252
                dc.b    "B2 CR1 ",0
                dc.l    $FF0254
                dc.b    "B2 CR2 ",0
                dc.l    $FF0256
                dc.b    "B2 CR3 ",0
                dc.l    $FF0258
                dc.b    "B2 VR0 ",0
                dc.l    $FF025A
                dc.b    "B2 VR1 ",0
                dc.l    $FF025C
                dc.b    "B2 VR2 ",0
                dc.l    $FF025E
                dc.b    "B2 VR3 ",0
                dc.l    0


;================================================================
; Strings
;================================================================
banner_msg:
                dc.b    13,10
                dc.b    "==================================",13,10
                dc.b    " FPS-3000 SBC Monitor / Debugger",13,10
                dc.b    " Lives in 21.9 KB free ROM @F0A826",13,10
                dc.b    " Talks via SIO chA (F70011/F70015)",13,10
                dc.b    "==================================",13,10,0

entry_msg:      dc.b    "entered at PC=$",0
sr_msg:         dc.b    "  SR=$",0
faddr_msg:      dc.b    "  FAULT@$",0
ssw_msg:        dc.b    "  SSW=$",0

prompt_msg:     dc.b    "fps3k> ",0
toolong_msg:    dc.b    "?line too long (max 61) -- NOTHING was executed.",13,10
                dc.b    "   split it: ww takes an address, so ww A .. then ww A+n ..",13,10,0
unknown_msg:    dc.b    "?  Type 'h' for help.",13,10,0

help_msg:
                dc.b    "Commands:",13,10
                dc.b    "  r              show registers",13,10
                dc.b    "  m AAAA [NN]    dump NN bytes (default 16) at AAAA",13,10
                dc.b    "  d AAAA [NN]    same as m",13,10
                dc.b    "  w AAAA BB BB.. write bytes to AAAA",13,10
                dc.b    "  g [AAAA]       resume, or start at AAAA",13,10
                dc.b    "  L              load S-records over SIO (ESC aborts)",13,10
                dc.b    "  b [ADDR|-ADDR|-]  set/clear/list breakpoints",13,10
                dc.b    "  t              single step (trace one insn)",13,10
                dc.b    "  i              live board status + diagnostics",13,10
                dc.b    "  mw/ml A [NN]   dump NN words / longs at A",13,10
                dc.b    "  ww/wl A VV..   write words / longs to A",13,10
                dc.b    "  x              AP I/F register map (skips the FIFO)",13,10
                dc.b    "  y              XLTR register map + 3 BIMs",13,10
                dc.b    "  c CH OP [DD]   AC transaction; DD adds $8005 continue",13,10
                dc.b    "  ca CH OP       AC acknowledge $8000 (no poll)",13,10
                dc.b    "  s [-|l|c|+]    channel ISR taps: arm/off/list/clr/T3",13,10
                dc.b    "  e [NN]         drain NN words from the bulk port",13,10
                dc.b    "  p PP [NN [OO]] read chassis window page PP",13,10
                dc.b    "  pw PP OO VV..  write longs at page PP offset OO",13,10
                dc.b    "  q              bounded poll of FF0004 bit 0",13,10
                dc.b    "  z AAAA NNNN    XOR + sum of a region, as words",13,10
                dc.b    "  f AAAA NNNN VV fill RAM with word VV",13,10
                dc.b    "  !              show banner",13,10
                dc.b    "  h, ?           this help",13,10,0

ok_msg:         dc.b    "ok",13,10,0
hex_err:        dc.b    "?hex",13,10,0
bp_set_msg:     dc.b    "bp set @$",0
bp_dup_msg:     dc.b    "?already set",13,10,0
bp_full_msg:    dc.b    "?bp table full",13,10,0
bp_odd_msg:     dc.b    "?bad addr (need even, nonzero, on-board RAM,",13,10
                dc.b    "   and clear of the monitor at 0F800-0FEFF)",13,10,0
bp_none_msg:    dc.b    "?no such bp",13,10,0
bp_list_msg:    dc.b    "breakpoints:",13,10,0
bp_empty_msg:   dc.b    "  (none)",13,10,0
bp_was_msg:     dc.b    "  orig=$",0
trace_msg:      dc.b    "step from $",0
nogo_msg:       dc.b    "?no resumable frame (cold entry, or bus/address"
                dc.b    " error)",13,10,0
resume_msg:     dc.b    "resume @$",0
load_msg:       dc.b    "send S-records, S8/S9 ends, ESC aborts:",13,10,0
abort_msg:      dc.b    13,10,"?aborted",13,10,0
load_done_msg:  dc.b    13,10,"loaded $",0
load_bytes_msg: dc.b    " records, $",0

info_msg:
                dc.b    "RAM:      128 KB (000000-01FFFF)",13,10
                dc.b    "ROM:      64 KB (F00000-F0FFFF)",13,10
                dc.b    "WCS buf:  010000-01FFFF (fully loadable via L)",13,10
                dc.b    "mon work: 00F800-00F8FF vars/bp, 00F900-00FB7F"
                dc.b    " tap ring",13,10
                dc.b    "          stack top 00FF00 (896 B below the ring)"
                dc.b    13,10
                dc.b    "AP I/F:   FF0000-FF00FF",13,10
                dc.b    "XLTR:     FF0200-FF025F",13,10
                dc.b    "SIO chA:  F70011 data / F70015 ctrl (odd bytes)",13,10
                dc.b    "PTM:      F70001-F7000F (odd bytes)",13,10,0

bstat_msg:      dc.b    "board status F70019 = $",0
vmod_msg:       dc.b    "VMOD ctrl   1FFF0  = $",0
mend_msg:       dc.b    "monitor_end        = $",0
fault_msg:      dc.b    "grp0/nest/txfail   = $",0
srec_bad_msg:   dc.b    "!refused (not RAM, or hits monitor space) @$",0
srec_sum_msg:   dc.b    "!checksum error @$",0

pcmsg:          dc.b    "PC=$",0
srmsg:          dc.b    "  SR=$",0

; ---- tier 1-5 strings ----
odd_msg:        dc.b    "?odd address (word/long access would be an "
                dc.b    "ADDRESS ERROR)",13,10,0

; ---- tier 6 strings ----
sum_x_msg:      dc.b    "XOR=$",0
sum_a_msg:      dc.b    "  SUM=$",0
fill_ok_msg:    dc.b    "filled",13,10,0
fill_no_msg:    dc.b    "?refused: fill is a RAM operation and would hit the "
                dc.b    "vector table, non-RAM, or monitor space",13,10
                dc.b    "  (use w for deliberate device/ROM pokes)",13,10,0

apif_hdr:       dc.b    "AP I/F -- bulk window + 4 channel windows",13,10
                dc.b    "  (window N base = FF0000 + ((N+1)<<5), so"
                dc.b    " FF0020 is skipped by construction)",13,10,0
fifo_msg:       dc.b    "FF0008 NOT read: bulk data FIFO, reads POP it."
                dc.b    "  Use 'e'.",13,10
                dc.b    "FF0010 absent: never accessed, statically or at"
                dc.b    " runtime.",13,10,0
xltr_hdr:       dc.b    "XLTR -- control block + 3 MC68153 BIMs",13,10,0

ac_ok_msg:      dc.b    "DONE   status=$",0
ac_err_msg:     dc.b    "ERROR  status=$",0
ac_to_msg:      dc.b    "TIMEOUT (1000 polls, as the firmware) status=$",0
ac_poll_msg:    dc.b    "  polls=$",0
ac_data_msg:    dc.b    "  data=$",0
ac_ch_msg:      dc.b    "?channel must be 1-4",13,10,0
ac_latch_msg:   dc.b    "  ** LATCH ECHOING, not an AC responding:"
                dc.b    " zero polls and",13,10
                dc.b    "     +$0A read back the opcode we wrote."
                dc.b    "  Vary OP and compare.",13,10,0
ac_cont_msg:    dc.b    "  CONTINUE ($8005): ",0
ac_ack_msg:     dc.b    "  ACK ($8000, fire-and-forget, no poll)  status=$",0
ac_tear_msg:    dc.b    "  BIM CR restored; FF021A left alone, was $",0

tap_on_msg:     dc.b    "taps armed on vectors 45-48 ($114-$120),"
                dc.b    " chaining to the originals",13,10,0
tap_off_msg:    dc.b    "taps disarmed, original vectors restored",13,10,0
tap_noarm_msg:  dc.b    "?not armed",13,10,0
tap_rearm_msg:  dc.b    "?already armed -- s- first.  Arming twice would save",13,10
                dc.b    "   the taps over the originals and hang the ISR.",13,10,0
tap_t1_msg:     dc.b    "PTM T3 free-running: 16-bit, internal E clock,"
                dc.b    " IRQ off, latch FFFF.",13,10
                dc.b    "  NOT NEEDED with the RTOS running -- it programs"
                dc.b    " T3 itself.",13,10
                dc.b    "  WARNING: CR1 bit 0 is a CHIP-WIDE internal reset,"
                dc.b    " so this",13,10
                dc.b    "  restarts T1 and T2 as well and REPLACES the"
                dc.b    " 10 ms RTOS tick.",13,10
                dc.b    "  --reset image only.",13,10,0
tap_tick_msg:   dc.b    "?refused: the RTOS owns the tick (vector $1C at"
                dc.b    " $70 is not",13,10
                dc.b    "  monitor_entry).  s+ would assert the chip-wide"
                dc.b    " PTM reset and",13,10
                dc.b    "  stop T3 interrupting -- T3 IS the 10 ms system"
                dc.b    " tick.  T3 is",13,10
                dc.b    "  already free-running here, so timestamps work"
                dc.b    " without s+.",13,10,0
tap_hdr_msg:    dc.b    "CH TSTMP STAT DHI :DLO",13,10,0
tap_empty_msg:  dc.b    "  (ring empty)",13,10,0
tap_ov_msg:     dc.b    "wraps=$",0

bulk_arm_msg:   dc.b    "arming FF0218 <- $400, polling bit 15...",13,10,0
bulk_to_msg:    dc.b    "?timeout: FF0218 bit 15 never set",13,10,0
bulk_pre_msg:   dc.b    "FF0000 before drain = $",0
bulk_post_msg:  dc.b    "FF0000 after  drain = $",0
bulk_dec_msg:   dc.b    "  -> COUNT FELL: FF0000 behaves as a hardware"
                dc.b    " down-counter",13,10,0
bulk_flat_msg:  dc.b    "  -> count did NOT fall: port not popping, or"
                dc.b    " counter not loaded",13,10,0

page_rest_msg:  dc.b    "MODE2 restored to $",0
pagew_msg:      dc.b    " longs written, MODE2 restored to $",0

rdy_msg:        dc.b    "polling FF0004 bit 0 (BOUNDED -- the firmware's"
                dc.b    " own 11 sites are not)",13,10,0
rdy_yes_msg:    dc.b    "  bit 0 SET after $",0
rdy_no_msg:     dc.b    "  bit 0 still clear after $",0
rdy_val_msg:    dc.b    " polls, FF0004=$",0

                even
monitor_end:
