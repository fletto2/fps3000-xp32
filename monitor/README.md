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
