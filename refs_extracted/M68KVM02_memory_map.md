# M68KVM02-3 VERSAmodule Monoboard Memory Map

Extracted from Motorola M68KVM02-3 VERSAbus User's Manual
(`refs/versabus2.pdf`, Figure 2 page 2-55).

## Memory map

```
Address range          Width      Use
─────────────────────  ──────────  ─────────────────────────────────────
FF0001 - FFFFFF        2 bytes     VERSAbus Short I/O Address space
FF0000 - FEFFFE                    (16-bit)
─────────────────────────────────  off-board peripherals (e.g. AP I/F)
F82001 - FEFFFF                    VERSAbus
F82000 - FEFFFE
─────────────────────────────────
F80001 - F81FFF        16-bit       I/O Channel — small, single-function
F80000 - F81FFE                    non-VERSAbus boards
─────────────────────────────────
F7FFFF - F80000                    VERSAbus
F7FFFE - F7001B                    (illegal F7001A-F7001B)
─────────────────────────────────
F70019                              VERSAmodule Status Register
F70018                              (low byte = control, high byte = status)
─────────────────────────────────
F70017                              Serial Port channel B
F70010 - F70016                     Serial Ports (NEC µPD7201)
                                    F70010 = chA data
                                    F70012 = chA control/status
                                    F70014 = chB data
                                    F70016 = chB control/status
─────────────────────────────────
F70011 (image)                      Illegal — not used
F7000F                              PTM register 8 (high byte)
F7000E                              PTM register 8 (low byte) (?)
F70001 - F7000F                     MC6840 PTM (odd-byte access only via MOVEP)
                                    8 PTM registers: F70001, F70003, ...,
                                    F7000F at odd-byte boundaries
F70000                              (illegal)
─────────────────────────────────
F6FFFF - F70000                    VERSAbus (long I/O)
F10001 - F6FFFE                    
F10000 - F6FFFE                    
─────────────────────────────────
F0FFFE                              ROM (top)
F0FFFF                             
F00009                              ROM
F00008
F00007                              ROM — initial PC LSB (used during reset)
F00006                              ROM — initial PC LSB
F00005                              ROM — initial PC MSB
F00004                              ROM — initial PC MSB
F00003                              ROM — initial reset SP LSB
F00002                              ROM — initial reset SP LSB
F00001                              ROM — initial SP MSB
F00000                              ROM — initial SP MSB
                                    Two 28-pin sockets, 2K/4K/8K/16K/32K
                                    devices each, total ROM = 64 KB.
                                    Jumper-selected access timing 0..500ns.
─────────────────────────────────
EFFFFE - 020000                     VERSAbus
EFFFFF - 020001
─────────────────────────────────
01FFFF                              Top of RAM
01FFFE
01FFF1                              VERSAmodule Control Register (low byte)
01FFF0                              VERSAmodule Control Register (high byte)
                                    NOTE: Control Register IMAGE only —
                                    register not directly accessible.
                                    Reads return chassis-mediated image.
─────────────────────────────────
01FFEF - 000001                     128 KB Dynamic RAM (0x000000-0x01FFEF)
000000                              RAM byte 0 (also serves M68000 reset
                                    vector reads at $0-$7 via address-decode
                                    overlay during reset)
─────────────────────────────────
```

## Key facts

- **Total directly addressable**: 16,777,216 bytes (24-bit address bus)
- **MPU**: MC68000 @ 8 MHz (32 MHz crystal)
- **RAM**: 128 KB dynamic, with byte parity (jumper option)
- **ROM/PROM/EPROM**: 64 KB max in two 28-pin sockets
- **Reset behavior**: M68000 reads SP from `$00000000` and PC from
  `$00000004`. The M68KVM02's address-decode logic redirects these
  reads to ROM at `F00000-F00007` so the initial vectors come from
  ROM.

## Critical details for emulation

### VERSAmodule Control Register at `0x01FFF0`

> "Control Register image only. Register not directly accessible."

This means writes to `0x01FFF0` go through the VERSAbus interrupter
logic — they don't store directly. Reads return whatever the chassis-
side state machine wants to expose, NOT necessarily what was last
written.

This is critical for emulation: a `bclr.b #$6, $1FFF1` followed by
`btst.l #$6, $1FFF1` may NOT see the bit cleared, because the
control register's read-back is mediated by external logic.

### VERSAmodule Status Register at `0xF70018-0xF7001A`

Three bytes (24 bits + 1 byte at F7001A which the figure marks as
the high byte of the status register). F7001B is illegal.

The status register reports:
- RAM size (jumper-strapped)
- User-defined status bits
- On-board interrupt select
- Bus interrupt select
- Possibly: VERSAbus AC Fail line state

### Serial ports at `0xF70011-0xF70017` (ODD bytes only)

**Corrected 2026-07-25.** An earlier version of this file listed four
*word* slots at `F70010/12/14/16` and labelled them A-data / A-ctrl /
B-data / B-ctrl. Both halves of that were wrong, and the monitor was
written from it — see the post-mortem in `monitor/README.md`.

Authoritative source: Motorola's own VERSAdos chip description for this
board, `verdos06/SDLCPRI/NEC7201.EQ`
(`~/src/claude/versados/extracted/verdos06/SDLCPRI/NEC7201.EQ`, also
concatenated into `rms68k_source.SA`):

```
NEC7201  EQU  $F70011              <- ODD base
NECWRDA / NECRDDA = base+0 = $F70011   ch A data
NECWRDB / NECRDDB = base+2 = $F70013   ch B data
NECWR0A / NECRD0A = base+4 = $F70015   ch A control/status
NECWR0B / NECRD0B = base+6 = $F70017   ch B control/status
```

| Byte address | Register |
|---|---|
| `F70011` | channel A data |
| `F70013` | channel B data |
| `F70015` | channel A control / status |
| `F70017` | channel B control / status |

Two things to keep straight:

1. **Odd addresses only.** The chip sits on D0–D7 and answers `LDS`, so
   a byte access to an even address in this block asserts `UDS` only,
   nothing responds, and the board's bus timeout raises BERR. Same
   convention as the MC6840 below (the ROM drives it at odd `F70001` /
   `F70003`) and as the board status register (the ROM bit-tests odd
   `F70019`). The MVME101 map in the Motorola handbook states the rule
   outright: "On-board I/O Registers (Only odd addresses used)."
2. **Grouped by function, not by channel** — both data registers, then
   both control registers. Corroborated by the second copy of the file,
   `verdos06/_root/NEC7201.EQ`, which gives the layout relatively as
   `CREG/SREG = 0`, `DREG = -4` (data sits four below control).

Implemented via NEC µPD7201 Multiprotocol Serial Communications
Controller (Z80-SIO/i8274 register-compatible), driven under VERSAdos
by **MPSCDRV** (per `verdos03/_root/BOARDS.NW`: "VM02 — 1 7201 —
VERSAdos driver: MPSCDRV").

#### Baud rate is strap-selected, not programmable

The datasheet lists sixteen strap-selectable rates — 50, 75, 110,
134.5, 150, 300, 600, 1200, 1800, 2000, 2400, 3600, 4800, 7200, 9600,
19200 — plus external clock to 600 kbps, with a jumper choosing between
the on-board baud-rate generator and an external clock.

`MPSCDRV.SA` (`~/src/claude/versados/SR07/U9993/MPSCDRV.SA`) confirms
there is **no software baud control on the VM02**: it defines
`VM03_BRCR EQU $F80071  Address of the baud rate control register on
VM03` and nothing equivalent for VM02, and its changelog notes
"10/9/84 Added baud rate support for VM03". The only software lever on
a VM02 is the 7201's WR4 clock divisor — per the driver's `CLOCK_64`
flag, "if it is nonzero (true), then we're using the x64 clock, which
effectively divides the baud rate by 4."

So WR4 = x16 runs at exactly the strapped rate, and x64 gives
strapped/4. Nothing else is reachable in software.

Note for anyone reading the same disks: the `Baud Rate Jmprs`,
`RED_LED` and `WRT_LED` PIA bits that appear near this material belong
to **`MVME400.EQ`**, a different board. `MPSCDRV.SA` marks its
`PIA_ASAV` field "Used only for MVME 400 boards". Do not attribute them
to the VM02.

### PTM at `0xF70001-0xF7000F`

MC6840 Programmable Timer Module. Three 16-bit cascadable timers.
Access via MOVEP at odd-byte boundaries (PTM is on the upper
8 bits of the 16-bit data bus).

### Reset behavior

M68000 reset sequence:
1. CPU reads SP from `$00000000-$00000003` (4 bytes)
2. CPU reads PC from `$00000004-$00000007` (4 bytes)
3. CPU jumps to PC

The M68KVM02 board overlays ROM at `$00000000-$00000007` for the
duration of the reset-vector fetches. After that, `$00000000+` is
normal RAM and `$F00000+` is the only ROM-visible region.

Our SBC ROM `FPS3K_U11_U12_JOIN.bin` (64 KB) populates exactly
the F00000-F0FFFF range. ResetEntry per the disassembly is at
`F09C00`, so the initial PC at `F00004-F00007` reads `0x00 0xF0
0x9C 0x00`.

## Implications for the FPS-3000 SBC emulator

Confirms our memory layout:

- ROM at `F00000-F0FFFF` ✓
- 128 KB RAM at `0x000000-0x01FFFF` ✓
- VMOD_CTRL at `0x01FFF0-0x01FFF1` (image-only, chassis-mediated) ✓
- PTM at `0xF70001-0xF7000F` (odd byte) ✓
- Serial Ports at `0xF70010-0xF70017` ✓
- VERSAmodule Status Register at `0xF70018-0xF7001A` ✓
  (note: F7001B is **illegal** — should bus-error)
- VERSAbus Short I/O at `0xFF0000-0xFFFFFF` (where AP I/F lives) ✓

Two corrections to apply to the current emulator:

1. **F7001B should be illegal** — bus error on access. Currently
   stubbed as part of board-status range.
2. **VERSAbus long I/O at `0xF10000-0xF6FFFF`** is currently
   unmapped (warns/returns 0xFF). Should be stubbed as VERSAbus
   per the manual (chassis-side accesses; we don't know what's
   there but reads should produce something rational).

## Source

Motorola M68KVM02-3 VERSAmodule Monoboard Microcomputer User's
Manual, included in `refs/versabus2.pdf` (FPS-3000 archive copy).
