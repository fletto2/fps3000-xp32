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
MON_LINEBUF     equ     MON_BASE+$50    ; cmd line buffer (64 B)
MON_LASTADDR    equ     MON_BASE+$90    ; last 'm' addr (long)
MON_GRP0        equ     MON_BASE+$94    ; frame kind: 0 = short (4-word,
                                        ;   resumable), 1 = group-0 (7-word
                                        ;   bus/addr error), $FF = no frame
                                        ;   at all (cold entry)
MON_NEST        equ     MON_BASE+$95    ; re-entry guard: 0 = not inside a
                                        ;   fault report, 1 = reporting,
                                        ;   2 = died re-entering (sticky)
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
                ; Re-entry guard FIRST, before clobbering anything: if we
                ; are already reporting a fault, the fault is coming from
                ; the monitor's own I/O path and reporting it again just
                ; recurses, pushing a frame per pass until the stack eats
                ; the workspace.  Bail to mon_dead and keep the FIRST
                ; fault's PC/SR intact for post-mortem.
                tst.b   MON_NEST
                bne.w   mon_dead
                move.b  #1,MON_NEST

                movem.l d0-d7/a0-a6,MON_REGS
                move.b  #0,MON_GRP0             ; short frame: SR, then PC
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
                tst.b   MON_NEST
                bne.w   mon_dead
                move.b  #1,MON_NEST

                movem.l d0-d7/a0-a6,MON_REGS
                move.b  #1,MON_GRP0             ; group-0: not resumable
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
                ; We reached the prompt, so the I/O path works: re-arm the
                ; guard so a later fault is reportable too.
                move.b  #0,MON_NEST
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
; Only a short (4-word) frame can be *resumed*.  A group-0 frame is not
; restartable on a 68000, and cold entry has no frame at all — but with
; an explicit address, cold entry can still start code by synthesizing a
; frame and RTE'ing into it.  That is what makes the standalone monitor
; able to run and then debug something, rather than only look at memory.
cmd_go:
                addq.l  #1,a6
                bsr.w   skip_ws
                move.b  (a6),d0
                beq.b   .noaddr
                bsr.w   parse_hex
                tst.b   d1
                beq.w   cmd_err
                cmpi.b  #$FF,MON_GRP0
                beq.w   .fresh                  ; cold entry + address
                tst.b   MON_GRP0
                bne.w   .no_frame               ; group-0: not resumable
                move.l  d0,MON_SPC
                bra.b   .resume
.noaddr:
                tst.b   MON_GRP0                ; no address: need a real frame
                bne.w   .no_frame
                bra.b   .resume
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
                ; Cold entry: no frame exists, so build one.  RTE pops SR
                ; then PC, so push PC first and SR on top.  IPL stays 7 and
                ; the T bit stays clear; every vector already points at the
                ; monitor, so a fault in the target lands back here.
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
                cmpi.l  #$400,d3
                bcs.w   .odd                    ; vector table
                cmpi.l  #$20000,d3
                bcc.w   .odd                    ; not on-board RAM
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
; stays set in the restored SR, so `t` repeats naturally; `g` clears it
; on the way out so a resume does not keep tracing.
;================================================================
cmd_trace:
                tst.b   MON_GRP0
                bne.w   trace_noframe
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
                bsr.w   put_crlf
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
                bsr.w   putchar                 ; echo
                move.b  d0,(a0)+
                dbra    d2,.rloop
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
                ; clear the breakpoint slot table (addr 0 = free)
                lea     MON_BPT,a0
                moveq   #MON_BPN-1,d1
.bpclr:
                move.l  #0,(a0)
                move.w  #0,4(a0)
                lea     MON_BP_SZ(a0),a0
                dbra    d1,.bpclr
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
                dc.b    " Lives in 21.9 KB free ROM @F0A826",13,10
                dc.b    " Talks via SIO chA (F70011/F70015)",13,10
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
                dc.b    "  g [AAAA]       resume, or start at AAAA",13,10
                dc.b    "  L              load Motorola S-records over SIO",13,10
                dc.b    "  b [ADDR|-ADDR|-]  set/clear/list breakpoints",13,10
                dc.b    "  t              single step (trace one insn)",13,10
                dc.b    "  i              live board status + diagnostics",13,10
                dc.b    "  !              show banner",13,10
                dc.b    "  h, ?           this help",13,10,0

ok_msg:         dc.b    "ok",13,10,0
hex_err:        dc.b    "?hex",13,10,0
bp_set_msg:     dc.b    "bp set @$",0
bp_dup_msg:     dc.b    "?already set",13,10,0
bp_full_msg:    dc.b    "?bp table full",13,10,0
bp_odd_msg:     dc.b    "?bad addr (need even, nonzero, on-board RAM)",13,10,0
bp_none_msg:    dc.b    "?no such bp",13,10,0
bp_list_msg:    dc.b    "breakpoints:",13,10,0
bp_empty_msg:   dc.b    "  (none)",13,10,0
bp_was_msg:     dc.b    "  orig=$",0
trace_msg:      dc.b    "step from $",0
nogo_msg:       dc.b    "?no resumable frame (cold entry, or bus/address"
                dc.b    " error)",13,10,0
resume_msg:     dc.b    "resume @$",0
load_msg:       dc.b    "send S-records, S8/S9 ends:",13,10,0
load_done_msg:  dc.b    13,10,"loaded $",0
load_bytes_msg: dc.b    " records, $",0

info_msg:
                dc.b    "RAM:      128 KB (000000-01FFFF)",13,10
                dc.b    "ROM:      64 KB (F00000-F0FFFF)",13,10
                dc.b    "WCS buf:  010000-01FFFF (fully loadable via L)",13,10
                dc.b    "mon work: 00F800-00FEFF + stack top 00FF00",13,10
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

                even
monitor_end:
