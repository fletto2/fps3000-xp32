# FPS-3000 SBC Monitor / Debugger / Host Interface

A small, self-contained M68K monitor that fits in the **22.4 KB of
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
echo -e "i\nL\nS208010000DEADBEEFEC\nS804000000FB\nm 010000 8\n" \
  | ./fps3k_sbc -rom ../monitor/FPS3K_with_monitor.bin -cycles 50000000
```

## Example session

```
==================================
 FPS-3000 SBC Monitor / Debugger
 Lives in 22.4 KB free ROM @F0A825
 Talks via SIO chA (F70010/F70012)
==================================
entered at PC=$00000000  SR=$2700
fps3k> i
Free ROM: 22489 bytes (F0A825-F0FFFF)
RAM:      128 KB (000000-01FFFF)
ROM:      64 KB (F00000-F0FFFF)
AP I/F:   FF0000-FF00FF
XLTR:     FF0200-FF025F
Mailbox:  700000-70003F
fps3k> L
send S-records, S8/S9 ends:
S208010000CAFEBABEEC
S208010008DEADBEEFD8
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
- **Resume execution** to continue from where the panic happened (`g`)
- **Help / banner / chassis info** commands

## Files

| File             | What it is                                             |
|------------------|---------------------------------------------------------|
| `monitor.s`      | M68K assembly source (vasm Motorola syntax)            |
| `monitor.bin`    | Assembled blob (2,340 bytes)                            |
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
| `g [AAAA]`         | Restore regs and RTE — optionally jump to AAAA first   |
| `L`                | Receive Motorola S-records over SIO (S0/S1/S2/S3,     |
|                    | terminator S7/S8/S9)                                   |
| `i`                | Print chassis-info dump (memory map, ROM/RAM sizes)    |
| `!`                | Reprint banner                                         |

`m` advances the display address each call, so `m AAAA` followed by
plain `m` gives the next 16 bytes.

## S-record loader (the host-link path)

`L` reads bytes from the SIO directly (not via the line buffer), so
records can be streamed at line rate — typical workflow:

```
fps3k> L
send S-records, S8/S9 ends:
S208010000DEADBEEFEC
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
| **75** | SBC OUT   | **TXD1**   | RX of the USB-serial adapter   |
| **73** | SBC IN    | **RXD1**   | TX of the USB-serial adapter   |
| **1-6** | —        | **GND**    | GND of the USB-serial adapter  |

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
 Lives in 22.4 KB free ROM @F0A825
 Talks via SIO chA (F70010/F70012)
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
$F0A856  monitor_common     ; merge point — banner + cmd loop
$F0A8..  command implementations
$F0AC..  helpers (puts, putchar, getchar, hex print, parse, ...)
$F0AE..  SIO init + string table
$F0B188  monitor_end        ; ~2,340 bytes total
```

Workspace in high RAM (above the staging buffer, below VMOD_CTRL):

```
$1F000   MON_REGS    saved D0-D7/A0-A6 (60 bytes)
$1F03C   MON_SPC     saved PC (long)
$1F040   MON_SSR     saved SR (word)
$1F050   MON_LINEBUF cmd line buffer (64 bytes, NUL-term)
$1F090   MON_LASTADDR  last `m` address
$1FFD0   supervisor stack top (cold-entry sets SP here)
```

## Limitations / TODO

- **Resume from cold entry** doesn't make sense (no exception frame).
  `g` only works correctly when entered via the panic vector.
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
