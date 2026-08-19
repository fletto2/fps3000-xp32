# FPS-3000 SBC monitor

A serial monitor and debugger that lives in the unused tail of the FPS-3000
SBC ROM. It gives a terminal access to SBC memory, the chassis registers the
AP I/F and the XLTR present, and the XP-32 channel windows, without needing a
host on the far end of the AP I/F link.

**To use it, read `MONITOR_MANUAL.pdf`.** This file covers only building and
installing it.

## Files

| File | What it is |
|---|---|
| `MONITOR_MANUAL.pdf` | the user's guide: commands, wiring, what each command touches |
| `MONITOR_MANUAL.md` | pandoc source for the above |
| `monitor.s` | M68K assembly source, vasm Motorola syntax |
| `monitor.bin` | assembled blob, 10,842 bytes |
| `monitor.lst` | vasm listing and symbol map |
| `patch_rom.py` | inserts `monitor.bin` into the ROM image and hooks the entry vectors |
| `split_rom.py` | splits a 64 KB image into the two EPROM halves |
| `FPS3K_with_monitor.bin` | patched image, reset vector and panic vector both hooked |
| `FPS3K_panic_only.bin` | patched image, panic vector only |
| `*_U11_lo.bin`, `*_U12_hi.bin` | the same two images split for burning |

The four `.bin` images are checked in, so burning an EPROM needs none of what
follows.

## Build

```sh
vasmm68k_mot -m68000 -Fbin -o monitor.bin monitor.s -L monitor.lst
python3 patch_rom.py ../FPS3K_U11_U12_JOIN.bin monitor.bin \
                     FPS3K_with_monitor.bin --reset --panic
python3 patch_rom.py ../FPS3K_U11_U12_JOIN.bin monitor.bin \
                     FPS3K_panic_only.bin --panic
python3 split_rom.py FPS3K_with_monitor.bin
python3 split_rom.py FPS3K_panic_only.bin
```

The build currently produces no warnings and must stay that way.

Do not pipe the assembler's output through `tail`. It hides the error line, and
vasm leaves the previous `monitor.bin` in place when it fails, so the next step
packages a stale binary and reports success. Check for the word `error`, and
check the output file's timestamp.

`monitor_entry` is pinned to `F0A840` by an `org` in the source, because
`patch_rom.py` hardcodes that address. Moving it means changing both.

## The two patches

`--reset` overwrites the reset PC at `F00004` so the SBC boots directly into
the monitor. The firmware never runs.

`--panic` overwrites the firmware's exception catch-all at `F0A27A` with a jump
to `monitor_entry`. The firmware boots normally, and anything that would have
panicked into `bra .` lands in the monitor instead with the registers saved.

Both patches are independent and can be applied together.

## The ROM checksum is not optional

Self-test phase `$0300` exclusive-ORs all 32,768 words of the ROM and requires
zero. On failure it retries forever, so a bad checksum means the machine never
boots and never says why, beyond leaving `$0300` in the CHANNEL_SELECT
register. Every monitor image built before 29 July 2026 broke it.

`patch_rom.py` recomputes the trailing word at `F0FFFE`. If you modify an image
by any other means, fix the checksum yourself. Verify from the host:

```sh
python3 -c "
import struct
d = open('FPS3K_with_monitor.bin','rb').read()
x = 0
for (w,) in struct.iter_unpack('>H', d): x ^= w
print(hex(x))"
```

or from the running monitor with `z F00000 10000`. Both report zero.

## EPROM split

The board takes two 27256-class devices, one per byte lane. `split_rom.py`
writes `_U11_lo.bin` and `_U12_hi.bin`. U12 holds even addresses, which on a
68000 is the high byte of each word; U11 holds odd addresses, the low byte.
The convention was verified against the original dumps.

## Space

The firmware ends at `F0A825`. The monitor occupies `F0A826` to `F0D27F`, and
`F0D280` to `F0FFFD` is still zero: 11,646 bytes, with the checksum in the last
word. Nothing the firmware needs is moved or overwritten.

## SIO setup

Channel A, 9600 8-N-1, no interrupts, receive and transmit enabled. See
`sio_init` in the source.

| Register | Value | Meaning |
|---|---|---|
| WR0 | `$18` | command 3, channel reset |
| WR4 | `$44` | x16 clock, 1 stop bit, no parity |
| WR3 | `$C1` | 8 receive bits per character, receiver enable |
| WR5 | `$EA` | 8 transmit bits per character, transmitter enable, DTR and RTS asserted |

The chip is at odd addresses only, `F70011` for channel A data and `F70015` for
channel A control, and its two channels are grouped by function rather than
interleaved. An early version of this monitor used `F70010` and `F70012` and
was silent on hardware for both reasons at once.

## Before blaming the software

Three things produce exactly the same silence as a dead board: the RS-232
drivers may be unpowered, since the chassis supplies no plus or minus 12 volts;
jumpers J25 and J26 must be fitted to connect the serial signals to P2; and TX
and RX may be swapped. Chapter 1 of the manual has the wiring table.

## Tests

`tools/verify_findings.py` reads `monitor.s` directly and pins a number of its
properties, including several bug fixes that are only visible in the source.
Do not modify `monitor.s` while a suite run is in flight.
