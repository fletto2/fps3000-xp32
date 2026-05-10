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

### Serial ports at `0xF70010-0xF70017`

Four word slots:
- `F70010` = channel A data
- `F70012` = channel A control/status
- `F70014` = channel B data
- `F70016` = channel B control/status

Implemented via NEC µPD7201 Multiprotocol Serial Communications
Controller (Z80-SIO/i8274 register-compatible). Internal clock
rates strappable from 50 bps to 19.2 kbps; external clock rates
to 600 kbps.

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
