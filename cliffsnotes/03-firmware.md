# 03 — Firmware (the SBC ROM)

## Memory map

| Range | Use |
|---|---|
| `0x000000–0x00FFFF` | RAM lower 64 KB — kernel data, vectors, SYSPAR, TCBs, ASQs |
| `0x010000–0x01FFFF` | RAM upper 64 KB — **XP-32 microcode staging buffer** (= one WCS bank exactly) |
| `0x01FFD0` | supervisor stack |
| `0x01FFF0–0x01FFF1` | VERSAmodule control register |
| `0xF00000–0xF0FFFF` | ROM (this firmware) |
| `0xF70001–0xF7000F` | MC6840 PTM (odd bytes, `movep`) |
| `0xF70010–0xF70017` | NEC µPD7201 dual UART (unused by factory ROM; co-opted by our in-ROM monitor at `F0A826` for serial console + S-record loader) |
| `0xF70018–0xF7001A` | Board status/control register (PAL-decoded) |
| `0xFF0000–0xFF00FF` | **AP I/F** command/data interface (host-visible) |
| `0xFF0200–0xFF025F` | **VersaBUS XLTR** control register block (SBC-private) |

The 64 KB staging buffer at `0x10000–0x1FFFF` exactly equals one bank
of the 4K × 128-bit AU WCS — so each S-record session loads one bank.

## RTOS

**RMS68K** — Motorola's Real-time Multitasking Software for MC68000,
generic kernel (same as `~/src/claude/versados/rms68k_disasm.SA`).
The kernel ends at ROM offset `0xF04487`. The FPS-3000-specific
application code+data is `0xF04488–0xF0FFFF` (~37 KB).

- **Syscalls**: TRAP #1 with directive in param block; TRAP #0 with
  directive in `D0` (37 internal directives).
- **Markers** (4-byte ASCII): `!TCB`, `!CCB`, `!ASQ`, `!TST`, `!DLY`,
  `!VCT`, `!GST`, `!UST`, `!IOV`, `!IDV`, `!PAT`, `!UDR`.
- **Boot**: TDTI (Table-Driven Task Initiator) scans
  `TCBDefinitionTable @ 0xF0A57E` and creates each `!TCB` entry.

## Tasks created at boot

| Task | Role |
|---|---|
| `TCBRDHC` | Master / dispatch — drives panel command interface and SLC microcode receiver |
| `TCBIO1I` (ASQ "HIO1") | Host link via AP I/F — implements EXPUT/EXGET data movement |
| `TCBXP1I` (ASQ "AXP1"/"HXP1") | XP-32 channel 1 controller |
| `TCBXP2I` | XP-32 channel 2 controller |
| `TCBXP3I` | XP-32 channel 3 controller |
| `TCBXP4I` | XP-32 channel 4 controller |

ASQ name pattern: `A`+name = AC-side queue, `H`+name = host-side queue.

## Key entry points

| Address | Name | Purpose |
|---|---|---|
| `F046F0` | `TCBRDHC_Entry` | Master/dispatch task entry |
| `F04730` | `TCBRDHC_MainLoop` | Main dispatch loop |
| `F046E0` | `ChannelConfigOffsetTable` | 4 longwords (XLTR config offsets) |
| `F051A2` | `SRecordDataHandler` | Validates `0x10000 ≤ addr ≤ 0x1FFFF` |
| `F05256` | `SRecordFinalize` | End-of-record handler |
| `F05688` | `PanelIOConfigure_25A` | Panel-command-sender (called with 21 distinct codes) |
| `F056BA` | `PanelSendAndWait` | Panel-command kernel |
| `F05BA4` | `PanelStatusDispatchTable` | 42-entry × 4-byte dispatch (4 handler classes: POLL/D1_SEND/BLK_XFR/D2_FIN + RTS noop) — fully reverse-engineered, see `refs_extracted/panel_status_dispatch_table.md` |
| `F05C4C` | `PanelErrorMaskTable` | Error-mask table (data) |
| `F05D36` | `TCBIO1I_Entry` | Host I/O channel task |
| `F05F4A` | `TCBXP4I_Entry` | XP-32 channel 4 task |

## Disassembly state

- **`fps3k_clean.asm`** — ~22,000 lines, the readable annotated form
- **`fps3k_custom_annotated.asm`** — same disasm with MC annotations
- **`fps3k_custom.asm`** — the raw generated disassembly
- **`disasm.py`** — recursive-descent + iterative-convergence disassembler

Coverage: 6,485 instructions, ~48% byte-coverage as code. The
remainder is data tables, padding, and some misdecoded data.

## Where to read more

- [`architecture.md`](../architecture.md) — RMS68K marker inventory §10, 4-letter context tags §11
- [`xltr_protocol.md`](../notes/xltr_protocol.md)
- [`host_to_sbc_communication.md`](../notes/host_to_sbc_communication.md)
- [`mc_results.md`](../notes/mc_results.md), [`mc_fps3k_pass2_summary.md`](../notes/mc_fps3k_pass2_summary.md)
