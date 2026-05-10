# FPS-3000 SBC Emulator

Stand-alone M68000 emulator for the FPS-3000 SBC (M68KVM02-3
VERSAmodule monoboard), with detailed VersaBUS access logging and
CPU PC tracing. Runs the actual SBC firmware ROM through reset,
MainInit, HardwareInit, and the boot-time hardware diagnostics.

## Components

- **CPU core**: Musashi MC68000 emulator (linked from
  `~/src/claude/pvs2/emulator/musashi`)
- **MC6840 PTM** (`mc6840.c`): 3-timer programmable timer module,
  datasheet-aligned register layout. Timers tick on every CPU
  cycle by default; CR bits 0/1 control prescaler/halt; bit 6
  enables IRQ.
- **NEC µPD7201 SIO** (`upd7201.c`): dual-channel SIO (functionally
  equivalent to Z80-SIO/i8274). Channel A wired to stdin/stdout
  for console behavior. WR0..WR7 / RR0..RR2 register set with
  pointer-based access pattern.
- **VersaBUS device stubs** (`versabus.c`):
  - AP I/F at `0xFF0000-0xFF00FF` (auto-completing opcodes 0x8004/
    0x8005 so panel-cmd send/wait loops terminate)
  - XLTR at `0xFF0200-0xFF025F` (auto-arming status_irq when 0x400
    written to FF0218)
  - 0x700000 mailbox (8 bytes — status word 0x70001C, reply word
    0x700020)
  - VERSAmodule Status Register at 0xF70018-0xF7001A (M68KVM02 board
    feature, default value sets bit 4 = ready, bit 5 = no error)
  - VERSAmodule control register at 0x01FFF0
- **Reset overlay**: ROM aliased at 0x000000 for the first 8 byte-
  fetches (initial SP + initial PC), then disabled (RAM thereafter).
- **Detailed bus access log**: every device read/write tagged with
  device class + symbolic register name + decoded panel command
  code where applicable.

## Build

```sh
make
```

Requires `~/src/claude/pvs2/emulator/musashi` (symlinked at
`./musashi`). If you don't have pvs2 checked out, copy a Musashi
tree there.

## Run

```sh
./fps3k_sbc -rom ../FPS3K_U11_U12_JOIN.bin -cycles 500000 \
            -bus bus.log -trace trace.log
```

Options:

- `-rom <file>`: FPS-3000 SBC firmware (mandatory)
- `-trace <file>`: CPU PC trace (one hex addr per line)
- `-bus <file>`: VersaBUS access log (default: stderr)
- `-cycles <n>`: stop after n cycles (default: forever)
- `-breakpc <addr>`: halt when PC hits this address
- `-dump-ram <file>`: dump SBC RAM (128 KB) on exit
- `-v`: verbose

## Current status

The emulator runs through reset and most of MainInit successfully:

- ResetEntry at `F09C00` ✓
- MainInit at `F08700` ✓
- VERSAmodule control register write `0x50` to `0x01FFF0` ✓
- Board status poll passes (bit 4 set, bit 5 clear) ✓
- HardwareInit subroutine entered ✓
- ~188 unique PCs visited, ~38K instructions executed before
  current bug

The simulation currently hits `BusAddressErrorHandler` (F08902)
during HardwareInit's continuous polling of VMOD_CTRL — likely
because the stubbed read returns inconsistent data. Iterating.

## Sample bus log

```
[VMOD_CTRL   ] WR 2-byte 01FFF0 = 00000050
[BOARD_STATUS] RD 1-byte F70019 = 00000010
[VMOD_CTRL   ] RD 1-byte 01FFF1 = 00000050
[XLTR        ] WR 2-byte FF0202 = 00002000  ; XLTR_MODE1
[XLTR        ] WR 2-byte FF0204 = 00000100  ; XLTR_CHANNEL_SELECT
...
```

## Architecture

```
+------------------+        +-------------------+
| fps3k_sbc.c      |        | versabus.c        |
| - Musashi hooks  | calls  | - AP I/F stubs    |
| - bus_read/write | -----> | - XLTR stubs      |
| - reset overlay  |        | - mailbox stubs   |
| - trace          |        | - PTM (mc6840.c)  |
+------------------+        | - SIO (upd7201.c) |
                            +-------------------+
```

The VersaBUS dispatch is one function (`versabus_read`/`_write`)
that delegates to per-device handlers based on address range. Every
access is logged with device class, size, value, and symbolic name.

## Progress log

### Run 1 — initial smoke test (50K cycles)
PC reached F08728 (board status poll), bit-4 polling stuck because
my BOARD_STATUS stub returned 0. Fixed by initializing bit 4 to 1.

### Run 2 — board status fix (200K cycles)
188 unique PCs visited, 13K instructions. Got past board-ready poll
into HardwareInit. Started iterating CHANNEL_SELECT 0x100..0x107.

### Run 3 — endurance (5M cycles)
378K instructions. CHANNEL_SELECT now scans 0x100..0x168 (group 1
channel test), then 0x200..0x201 (group 2). Still inside
HardwareInit's CSR-loopback test phase. PollBoardStatus is being
called many times per channel.

### Run 4 — extended (10M cycles)
756K instructions. Still in HardwareInit. PC oscillates between
PollBoardStatus body (F0891C-F08956) and the CSR-loopback driver
(F08AC2-F08C9C).

### Stuck where, why
HardwareInit's CSR-loopback test exercises every possible channel
selector value. The test increments d6 (the channel selector) by
one each iteration, calls PollBoardStatus to verify the chassis
responds, then writes the next CHANNEL_SELECT value. With my stubs
returning consistent "ready, no error" status, the test loops
through values without finding a failure but also without
identifying a "real" channel.

### What would unstick it
The actual chassis would have only specific channels populated
(in Lovett's 2-AC config: channels 1 and 2 are populated, 3 and 4
are not). HardwareInit probably terminates the scan when it finds
a non-responsive channel. To progress, the BOARD_STATUS stub needs
to alternate between bit-4-set (responsive) and bit-4-clear or
bit-5-set (not responsive / error) based on which CHANNEL_SELECT
value was last written. That requires the BOARD_STATUS stub to
read from XLTR.channel_select state.

### Iteration target
Add channel-aware response logic to the BOARD_STATUS stub: only
return "ready, no error" for CHANNEL_SELECT values matching the
populated 2-AC config (ch 1 = 0x100..0x104, ch 2 = 0x200..0x204,
others not populated → return error or no-ready).
