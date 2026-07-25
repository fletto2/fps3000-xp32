# FPS-3000 SBC Monitor / Debugger / Host Interface

A small, self-contained M68K monitor that fits in the **21.9 KB of
free ROM** at `F0A826` (just past the panic catch-all table).
Communicates over the on-board NEC µPD7201 SIO Channel A — which the
factory firmware never touches, so we have it all to ourselves.

## Quick start

```sh
cd monitor
vasmm68k_mot -m68000 -Fbin -o monitor.bin monitor.s -L monitor.lst
python3 patch_rom.py ../FPS3K_U11_U12_JOIN.bin monitor.bin \
                     FPS3K_with_monitor.bin --reset --panic
cd ../emulator
./fps3k_sbc -rom ../monitor/FPS3K_with_monitor.bin
```

For a non-interactive demo:

```sh
echo -e "i\nL\nS208010000DEADBEEFBE\nS804000000FB\nm 010000 8\n" \
  | ./fps3k_sbc -rom ../monitor/FPS3K_with_monitor.bin -cycles 50000000
```

## Example session

```
==================================
 FPS-3000 SBC Monitor / Debugger
 Lives in 21.9 KB free ROM @F0A826
 Talks via SIO chA (F70011/F70015)
==================================
entered at PC=$00000000  SR=$2700
fps3k> i
RAM:      128 KB (000000-01FFFF)
ROM:      64 KB (F00000-F0FFFF)
WCS buf:  010000-01FFFF (fully loadable via L)
mon work: 00F800-00FEFF + stack top 00FF00
AP I/F:   FF0000-FF00FF
XLTR:     FF0200-FF025F
SIO chA:  F70011 data / F70015 ctrl (odd bytes)
PTM:      F70001-F7000F (odd bytes)
board status F70019 = $1F
VMOD ctrl   1FFF0  = $0000
monitor_end        = $00F0B444
grp0/nest/txfail   = $FF/00/00
fps3k> L
send S-records, S8/S9 ends:
S208010000CAFEBABEB6
S208010008DEADBEEFB6
S804000000FB
..

loaded $00000002 records, $00000008
fps3k> m 010000 20
00010000: CA FE BA BE 00 00 00 00 DE AD BE EF 00 00 00 00 |................|
00010010: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 |................|
fps3k> r
D0=00000000  D1=00000000  D2=00000000  D3=00000000
...
PC=$00000000  SR=$2700
fps3k>
```

## What it provides

- A **command-line monitor** over SIO Channel A
- **Memory display** with ASCII view (`m`, `d`)
- **Memory write** for RAM patching (`w`)
- **Register display** for post-panic diagnostics (`r`)
- **S-record loader** as a makeshift host interface (`L`)
- **Resume or start execution** (`g`) — resumes a panic, or starts code
  at an address from cold entry
- **Breakpoints** (`b`) — up to 8, via TRAP #14
- **Single step** (`t`) — via the SR trace bit
- **Help / banner / chassis info** commands

## Files

| File             | What it is                                             |
|------------------|---------------------------------------------------------|
| `monitor.s`      | M68K assembly source (vasm Motorola syntax)            |
| `monitor.bin`    | Assembled blob (4,042 bytes)                            |
| `monitor.lst`    | Symbol map / listing produced by vasm                  |
| `patch_rom.py`   | Patches the FPS-3000 ROM with monitor.bin + entry vec  |
| `FPS3K_with_monitor.bin` | Patched ROM (cold-boot + panic-vector hooked)  |
| `FPS3K_panic_only.bin`   | Patched ROM (only panic-vector hooked)         |

## Build

```sh
cd monitor
vasmm68k_mot -m68000 -Fbin -o monitor.bin monitor.s -L monitor.lst
python3 patch_rom.py ../FPS3K_U11_U12_JOIN.bin monitor.bin \
                     FPS3K_with_monitor.bin --reset --panic
```

Patches applied:

- `--reset` — overwrites the reset PC (`F00004`) so the SBC boots
  *directly* into the monitor instead of running normal init. SP is
  set to `$1FFD0` by the cold-entry path.
- `--panic` — overwrites the panic catch-all at `F0A27A` with
  `JMP $F0A840` (= `monitor_entry`). Whenever the firmware would
  panic into `bra .` at `F0A57E`, it now drops into the monitor with
  registers saved.

Use `--reset` for standalone monitor (good for SIO testing). Use
`--panic` only for production-firmware-with-debug-fallback.

## Run (in the emulator)

```sh
cd ../emulator
./fps3k_sbc -rom ../monitor/FPS3K_with_monitor.bin
```

The monitor's stdout/stdin go through `upd7201.c`'s console hooks —
TX appears on the terminal stdout, RX comes from stdin (raw mode
recommended for interactive use).

## Commands

| Command            | Action                                                 |
|--------------------|--------------------------------------------------------|
| `h` or `?`         | Show command list                                      |
| `r`                | Display saved registers (D0-D7, A0-A6, PC, SR)         |
| `m AAAA [NN]`      | Hex/ASCII dump NN bytes (hex, default 16) at AAAA      |
| `d AAAA [NN]`      | Same as `m`                                            |
| `w AAAA BB BB ...` | Write hex bytes to AAAA                                |
| `g [AAAA]`         | Resume from a saved frame, or — from cold entry —      |
|                    | **start** execution at AAAA by synthesizing a frame    |
| `b [ADDR]`         | Set a breakpoint (TRAP #14). Bare `b` lists slots;     |
|                    | `b -ADDR` clears one, `b -` clears all. 8 slots        |
| `t`                | Single step one instruction (SR trace bit)             |
| `L`                | Receive Motorola S-records over SIO (S0/S1/S2/S3,     |
|                    | terminator S7/S8/S9)                                   |
| `i`                | Memory map plus **live** board status (`F70019`),      |
|                    | VMOD ctrl image (`1FFF0`), `monitor_end`, and the     |
|                    | grp0/nest/txfail diagnostic bytes                     |
| `!`                | Reprint banner                                         |

`m` advances the display address each call, so `m AAAA` followed by
plain `m` gives the next 16 bytes.

## S-record loader (the host-link path)

`L` reads bytes from the SIO directly (not via the line buffer), so
records can be streamed at line rate — typical workflow:

```
fps3k> L
send S-records, S8/S9 ends:
S208010000DEADBEEFBE
S804000000FB

loaded $00000001 records, $00000004
fps3k> m 010000 4
00010000: DE AD BE EF                                     |....|
```

Supported record types:

- **S0** — header, ignored
- **S1** — 16-bit address payload
- **S2** — 24-bit address payload
- **S3** — 32-bit address payload
- **S7/S8/S9** — terminator (any of these ends the load)

The loader writes bytes directly to the address contained in each
record — including the **AU WCS staging buffer at `$10000-$1FFFF`**.
This is the same path the factory firmware uses internally; the
monitor just bypasses the chassis-side dispatch (which we haven't
fully reverse-engineered yet) and goes straight to RAM.

### Refused ranges, and a layout collision to be aware of

`srec_check` rejects any record whose write range touches:

- `$000000-$0003FF` — the exception vector table
- `$00F800-$00FEFF` — `MON_*` workspace, breakpoint table, and the
  cold-entry supervisor stack
- anything at or above `$020000` — ROM and peripherals. A stray S2/S3
  record pointed there is not harmlessly ignored: a write to `$F70011`
  would **transmit a byte over the SIO**, and writes to the XLTR or AP
  I/F blocks would poke the chassis. Deliberate peripheral pokes are
  what `w` is for.
- any record whose *end* runs past `$01FFFF`

Each record's **checksum is verified** (sum of count + address + data
bytes, plus the checksum byte, must be `$FF`). A bad record is reported
as `!checksum error @$ADDR`. Note the data is written before the
checksum can be computed, so a failing record may have been partially
applied — re-send it.

Refused records are reported and skipped, and the load continues (the
scanner resyncs on the next `S`; hex digits can't be mistaken for a
record start). Straddling records are caught too — a record starting at
`$1EFFE` with 4 data bytes is refused because its tail reaches `$1F001`.

**The whole staging buffer is now loadable.** Earlier versions kept the
workspace at `$1F000`, i.e. *inside* the WCS staging buffer, so a full
64 KB bank load — the documented use case — would have destroyed the
monitor partway through and the top 4 KB had to be refused. The
workspace now lives at `$0F800`, below the buffer, so `$10000-$1FFFF`
is writable end to end. Verified by loading records at `$1FFE0` and
`$1FFF0` (the very top) with no refusals.

## Debugging a target: worked example

Cold-entry monitor, no firmware running. Write a short program, break in
it, inspect, and step:

```
fps3k> w 002000 30 3C 12 34 32 3C AB CD 4E 71 4E 71 60 FE
ok
fps3k> b 002008
bp set @$00002008
fps3k> g 002000
resume @$00002000

entered at PC=$0000200A  SR=$2708      <- breakpoint hit
fps3k> r
D0=00001234  D1=0000ABCD  D2=00000000  D3=00000000
...
fps3k> t
step from $0000200A
entered at PC=$0000200C  SR=$A708      <- one instruction later, T set
```

Note `PC=$200A`, one word *past* the `$2008` breakpoint: TRAP pushes the
address after the trap word, so `g` resumes past it and the original
instruction is **not** re-executed. Clear the breakpoint and `g ADDR` if
you need to run that instruction.

`b` arms vector 46 (`$B8`) and `t` arms vector 9 (`$24`) at the moment
they are first used. On the cold path `cold_init` has already filled
every vector, but on the `--panic` path the firmware owns the table, so
arming writes them explicitly — those two longwords are the only writes
these commands make outside the target word and the slot table.

## Connecting a USB-serial adapter to real hardware

To use the monitor on a real FPS-3000 chassis (not just the
emulator), you need to wire a USB-to-serial adapter into the SBC
card's **P2 connector** (the 120-pin edge connector, not the 140-pin
VERSAbus connector). Channel A of the µPD7201 SIO is exposed on P2
at RS-232C levels (±7 V mark/space, Type C in the M68KVM02 manual)
— compatible with any standard FTDI / CH340 / PL2303 / CP2102
USB-serial dongle.

### Connector

The P2 socket on the M68KVM02 board is a Stanford Applied Eng'g
**CPH7000-120ST** edge connector (per the manual). It's not a DB-9
or DB-25 — it's a custom-pitch backplane edge connector. So you
won't plug a serial cable in directly. You have three options:

1. **Card on an extender** — pull the SBC out, insert it into a
   VERSAbus extender card if you have one, then probe / solder onto
   P2 pin pads at the back of the card.
2. **Solder on the card** — if you don't mind modifying the SBC,
   solder fly-leads to the four pins listed below directly on the
   board side of the connector.
3. **Backplane breakout** — if the chassis has unused J2 signals
   exposed on a service connector somewhere, probe there instead.
   (FPS-3000 chassis-specific; check the chassis schematic.)

### Minimum wiring (3-wire null-modem-style)

For the monitor's needs (no flow control, full-duplex, 9600 8-N-1),
just three connections suffice. Add CTS/RTS only if you turn on
hardware flow control — the firmware doesn't.

| P2 pin | Direction | Signal     | USB-serial side                |
|-------:|-----------|------------|--------------------------------|
| **73** | SBC OUT   | **TXD1**   | RX of the USB-serial adapter   |
| **75** | SBC IN    | **RXD1**   | TX of the USB-serial adapter   |
| **1-6** | —        | **GND**    | GND of the USB-serial adapter  |

> **Corrected 2026-07-25.** An earlier revision of this table had 73 and
> 75 swapped, contradicting the 8-wire table further down and
> `CLAUDE.md`. The authority is `refs_extracted/versabus_pinout.md`
> (extracted from the Motorola P2/J2 pin map): **73 = TXD1**,
> **75 = RXD1**. If you wired from the old table, TX and RX are reversed
> and you will see nothing — swap them before suspecting anything else.

(The original M68KVM02 docs label TXD1 as "transmit data — output"
and RXD1 as "receive data — input" relative to the SBC. So **SBC
TXD1 → adapter RX** and **adapter TX → SBC RXD1**, classic
null-modem.)

Some USB-serial adapters expect DTR/DSR/DCD asserted before they'll
talk. Workarounds:

- Wire SBC's **DTR1 (pin 87)** → adapter's **DSR/DCD** if needed
- Or just tie the adapter's DSR/DCD to its own DTR (loopback) —
  most modern dongles don't care
- Adapter's **RTS** can be left unconnected (the SBC doesn't read CTS
  unless you change WR3/WR5)

### Full 8-wire serial (with flow control)

If you want hardware flow control, wire all the modem-control
lines:

| P2 pin | Signal | Direction | USB-serial side |
|-------:|--------|-----------|-----------------|
|     73 | TXD1   | SBC out   | RX              |
|     75 | RXD1   | SBC in    | TX              |
|     77 | RTS1   | SBC out   | CTS             |
|     79 | CTS1   | SBC in    | RTS             |
|     81 | DSR1   | SBC in    | DTR             |
|     85 | DCD1   | SBC in    | (tie to DTR)    |
|     87 | DTR1   | SBC out   | DSR             |
|  1...6 | GND    | —         | GND             |

You'll also need to reprogram the monitor's WR3/WR5 to enable
flow control (currently `$C1` and `$EA`, no flow control). Or
just leave it 3-wire — the monitor is light enough that 9600
baud has no overrun risk.

### Settings on the host side

Use any terminal program (`screen`, `minicom`, `picocom`, `tio`,
PuTTY, …) configured for:

- Baud rate **9600** (the monitor programmes WR4 = `$44` for x16
  clock, which together with the on-board baud generator gives
  9600 — adjust if your board's BRG is jumpered for a different
  ratio)
- **8 data bits, no parity, 1 stop bit** (8-N-1)
- **No flow control** (3-wire) or **RTS/CTS** if you wired them
- Local-echo OFF (the monitor echoes received chars back)
- LF-after-CR / CR-after-LF translation as you prefer (the monitor
  always emits CR+LF)

Linux example:
```sh
picocom -b 9600 -f n /dev/ttyUSB0
# or
screen /dev/ttyUSB0 9600 8N1
# or
tio -b 9600 /dev/ttyUSB0
```

### Sanity-checking the link

Power up the chassis with the patched ROM in place. With `--reset`
patch, the cold-entry path runs immediately and you should see the
banner within a second:

```
==================================
 FPS-3000 SBC Monitor / Debugger
 Lives in 21.9 KB free ROM @F0A826
 Talks via SIO chA (F70011/F70015)
==================================
entered at PC=$00000000  SR=$2700
fps3k>
```

If you see garbage characters, your terminal's baud rate is wrong
or the M68KVM02's baud generator is jumpered to something other
than 9600 (consult the board strap settings).

If you see nothing at all:

- Probe TXD1 (P2 pin 73) with a scope — should show RS-232-level
  bursts when the SBC tries to print the banner
- Verify the panic-only patch isn't fooling you (use `--reset` for
  guaranteed entry on power-up)
- Check GND continuity between adapter and chassis frame
- Verify chip is present (the M68KVM02 ships with the µPD7201
  socketed; some early boards left it depopulated)

### Loading microcode this way

Once the link works, send Motorola S-records via your terminal
program to load microcode into the staging buffer:

```sh
picocom -b 9600 /dev/ttyUSB0
# at the prompt:
fps3k> L
# then C-a C-s in picocom to send a file:
> some_microcode.s19
```

S-records to `$10000-$1FFFF` populate the AU WCS staging buffer.
From there the firmware's normal upload path (panel command
sequence to XP-32) takes the bytes the rest of the way to the
microcode store.

## SIO programming

Channel A configured for **9600 8-N-1, no IRQs, RX+TX enabled**:

| Register | Value | Meaning                                          |
|----------|-------|--------------------------------------------------|
| WR0      | $18   | command 3 = channel reset                        |
| WR4      | $44   | x16 clock, 1 stop bit, no parity                 |
| WR3      | $C1   | 8 RX bits/char, RX enable                        |
| WR5      | $EA   | 8 TX bits/char, TX enable, DTR + RTS asserted    |

(See `monitor.s:sio_init`.)

## Memory layout

```
$F0A826  monitor_cold       ; entry from reset PC
$F0A840  monitor_entry      ; entry from panic / exception
$F0A874  grp0_entry         ; entry for vectors 2/3 (7-word frame)
$F0A8AA  mon_dead           ; nested-fault trap (no I/O, STOP)
$F0A8BE  monitor_common     ; merge point — banner + cmd loop
$F0A8..  command implementations
$F0AC..  helpers (puts, putchar, getchar, hex print, parse, ...)
$F0AE..  SIO init + string table
$F0B7F0  monitor_end        ; ~4,042 bytes total (18.4 KB ROM left)
```

Workspace in high RAM (above the staging buffer, below VMOD_CTRL):

```
$0F800   MON_REGS    saved D0-D7/A0-A6 (60 bytes)
$0F83C   MON_SPC     saved PC (long)
$0F840   MON_SSR     saved SR (word)
$0F850   MON_LINEBUF cmd line buffer (64 bytes, NUL-term)
$0F890   MON_LASTADDR  last `m` address
$0F894   MON_GRP0    frame kind: 0=short, 1=group-0, $FF=none
$0F895   MON_NEST    re-entry guard: 0=idle, 1=reporting, 2=died
$0F896   MON_TXFAIL  set once putchar has timed out waiting for TX
$0F8A0   MON_BPT     8 breakpoint slots, 6 bytes each {addr.l, orig.w}
$0FF00   supervisor stack top (cold entry only; the panic path keeps
         the firmware's SP so the exception frame stays where it is)

Everything is inside `$01200-$0FFFF`, which a RAM dump after a full
stock-firmware boot shows to be **completely untouched** (60,928 bytes).
That puts the workspace below the WCS staging buffer *and* out of the
firmware's way — see the header comment in `monitor.s` for why the old
`$1F000` placement was wrong on both counts.
```

## Post-mortem: why the first real-hardware attempt halted

The first burn onto David's SBC came up with the **FAIL and HALTED LEDs
lit and no serial output**. Cause, found by deduction (no hardware
access) and reproduced in the emulator:

1. `SIO_A_DATA`/`SIO_A_CTRL` were `$F70010`/`$F70012`. The µPD7201 sits
   on D0–D7 at **odd** addresses, and its registers are grouped by
   function, so channel A control is `$F70015`. The old `$F70012` was
   wrong on both counts — its odd byte, `$F70013`, is channel *B's* data
   register. Even-address byte accesses assert `UDS` only, nothing
   answers, and the bus timeout raises BERR. See
   `refs_extracted/M68KVM02_memory_map.md` for the sourcing.
2. With `--reset`, `MainInit` never runs, so **nothing fills the
   exception vector table**. The 68000 has no VBR; the table lives in
   DRAM at `$000000` and is garbage at power-on (only the first 8 bytes
   of ROM are mapped to address 0, for the first four bus cycles, to
   supply reset SSP/PC). The stock firmware installs `$8`/`$C` as its
   2nd and 3rd instructions precisely because of this.

BERR + garbage vector = double bus fault = `HALT`. FAIL was simply never
cleared by anything, so it carried no information.

Both are fixed. `cold_init` now fills all 256 vectors before touching
any I/O, vectors 2 and 3 get a group-0-aware stub, and a re-entry guard
stops a fault in the monitor's own I/O path from recursing forever.

### Diagnosing a dead board from RAM

If it dies again, `MON_NEST = 2` at `$1F095` means "faulted while
reporting a fault" — and `MON_GRP0`/`MON_SPC`/`MON_SSR` still hold the
**first** fault's kind, PC and SR, because the guard checks before
overwriting them. `mon_dead` touches no I/O and re-anchors SP each pass,
so RAM stays intact for a post-mortem dump.

## Baud rate: strapped in hardware, not programmable

Worth knowing before chasing a silent link. The VM02's rate is set by
**straps**, one of sixteen: 50, 75, 110, 134.5, 150, 300, 600, 1200,
1800, 2000, 2400, 3600, 4800, 7200, 9600, 19200. A separate jumper
selects the on-board baud-rate generator **versus an external clock** —
if that is set to external with no clock present, the 7201 never raises
Tx-buffer-empty and `putchar` spins silently forever.

Motorola's own driver confirms there is no software control:
`MPSCDRV.SA` defines `VM03_BRCR EQU $F80071` as "the baud rate control
register on VM03" with no VM02 equivalent, and its changelog reads
"10/9/84 Added baud rate support for VM03". The only software lever on a
VM02 is WR4's clock divisor — the driver's `CLOCK_64` flag notes that
x64 "effectively divides the baud rate by 4".

So WR4 = `$44` (x16) runs at **exactly whatever the strap says**, and
x64 would give strapped/4. "9600" in this document is therefore an
assumption about strap position, not a fact. If output is garbage, walk
the terminal through the sixteen rates.

## Limitations / TODO

- **Resume from cold entry** doesn't make sense (no exception frame),
  and a 68000 group-0 frame is not restartable. `g` now detects both via
  `MON_GRP0` and refuses with `?no resumable frame` instead of RTE'ing
  into the weeds.
- **`getchar` still spins unboundedly** — deliberately. Waiting
  indefinitely for a human at a prompt is correct, and a timeout there
  would just spin the prompt. `putchar` *is* bounded now
  (`TX_SPIN_LIMIT`, ~2.5 s at 8 MHz, longer than one character time even
  at 50 baud): it drops the character and sets `MON_TXFAIL` rather than
  hanging before any output exists. That distinguishes "TX never became
  ready" — wrong clock jumper, dead chip — from "nobody typed".
- **`t` needs trace emulation** if you are testing in the emulator.
  Musashi ships with `M68K_EMULATE_TRACE` set to `M68K_OPT_OFF`, which
  makes the trace exception silently never fire; it is now switched
  `M68K_OPT_ON` in `emulator/musashi/m68kconf.h`. Real hardware was never
  affected.
- **No breakpoint set/clear, no single-step, no disassembler** (below).
- **No board-fail LED beacon.** Clearing Board Fail Status would give a
  liveness signal that needs no serial link, but the bit position in the
  board control register is not sourced yet — the `RED_LED`/`WRT_LED`
  bits in the VERSAdos sources belong to the MVME400, not the VM02. Not
  guessing at a hardware write.
- **No breakpoint set/clear** — would need to write
  `0x4E4E` (TRAP #14) into target instruction and chain the trap
  vector to `monitor_entry`. ~50 lines of asm to add.
- **No single-step** — would need to set the SR Trace bit (T1) on
  resume and install the Trace vector ($24) to `monitor_entry`.
- **No disassembler** — beyond scope for 2 KB. Use `m AAAA` and
  decode by eye, or run an external disassembler against the
  RAM dump.
- **Receive overrun** on the SIO — at 9600 baud and emulator's
  1-byte-per-versabus-tick rate, the monitor's L command can keep
  up. On real hardware the chip's 4-byte FIFO handles bursts.
