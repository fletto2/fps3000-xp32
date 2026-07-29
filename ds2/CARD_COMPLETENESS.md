# FPS-3000 Chassis — Per-Card Emulator Completeness

Assesses what the emulator models for each physical card in the
14-slot VersaBUS chassis, relative to the firmware's expectations.

---

## Slot 14: VBUS SBC (M68KVM02-3)

**What the emulator models:**
- MC68000 @ 8 MHz (Musashi core, full instruction set)
- 128 KB RAM at $000000-$01FFFF
- 64 KB ROM at $F00000-$F0FFFF
- Reset overlay (ROM aliased at $000000 for initial vector fetches)
- MC6840 PTM at $F70001-$F7000F (odd-byte MOVEP)
- NEC µPD7201 SIO at $F70010-$F70017 (odd bytes only, function-grouped)
- Board status register at $F70018-$F7001A
- VERSAmodule control register at $01FFF0
- Exception vector table in RAM (256 vectors, full table)
- Bus error (BERR) for unmapped/denied addresses

**What's simplified/missing:**
- No DRAM byte parity (strap-selectable; firmware doesn't read uninitialized RAM)
- No board strap model (baud rate, parity enable, bus timeout, ROM size)
- No DRAM refresh model
- No bus arbitration (CPU always owns the bus)
- PTM prescaler simplified (÷8 only; datasheet has ÷1, ÷8, ÷64, ÷1024)
- PTM no external clock/gate inputs
- No 68000 supervisor/user mode distinction in bus access
- No address error detection (odd-word access → BERR on real 68000)

**Completeness: ~75%** — adequate for firmware execution. Parity is the
main deviation; testable by any code reading never-written DRAM, but the
stock firmware never does.

---

## Slot 13: VBUS XLTR (612-4803-400-G)

**What the emulator models:**
- 48-word raw backing store at $FF0200-$FF025F (round-trips on write/read)
- MODE0: bits 0-4 (response code), bit 10 (ack), bit 11 (valid)
- MODE1: bit 12 (Path B command gate), bit 14 (unconfirmed control), bit 15 (engage/busy)
- MODE2: cleared during channel setup
- CHANNEL_SELECT: write-through + scripted readback
- COUNTER: operational value 0x04; 0x01/0xFF diagnostic
- DATA_LO/DATA_HI: write-through; DATA_HI bit 5 as BERR gate
- STATUS_IRQ: arm via 0x400 write, bit 15 auto-set on completion
- IRQ_MASK: write-through
- Three MC68153-style BIMs, each with 4 interrupts:
  - CRn per channel (level 0-2, IRE bit 4)
  - VRn per channel (vector number on IACK)
  - IACK daisy chain (priority order placeholder)
  - IRQ line assertion/deassertion

**What's missing:**
- No actual bus-bridge state machine (XLTR translates VersaBUS ↔ XP-32 bus)
- No transaction queuing (the real XLTR can queue commands)
- DATA_HI = 0 causes word-writes at $400000 to be ignored (phase 0x1900
  confirms this) — this is modeled but the *mechanism* (XLTR shadow register)
  is unclear
- BIM daisy-chain ordering between chips is a placeholder (scans BIM2 first)
- The 8-byte gap at $FF0248-$FF024F between per-channel config registers
  is unmodeled — could be additional per-channel registers
- The 256-byte gap at $FF0100-$FF01FF between APIF and XLTR blocks is
  unmodeled

**Completeness: ~40%** — register-level access works (self-tests pass) but
the bus-bridge function (what the XLTR actually *does*) is unstubbed. The
register semantics are reverse-engineered, not from a datasheet.

---

## Slot 12: UNIV FMT (612-4804-003-E)

**What the emulator models: Nothing.**

The FMT card sits between XLTR and XP-32 bus. Its documented role is
"32 BIT IEEE FPS3000" format conversion. Possible functions (none
modeled):
- 16-bit VersaBUS ↔ 32-bit XP-32 bus width adapter
- IEEE-754 format validation/conversion
- DEC F-floating ↔ IEEE-754 (for PDP-11 host)
- WCS write-port fan-out (splitting data across multiple WCS SRAMs)
- Arbitration between multiple XLTR channels

The firmware writes MODE0/MODE1/MODE2/COUNTER — some of these fields
may configure the FMT card, not the XLTR. Without a schematic, the
boundary between XLTR registers and FMT registers is unknown.

**Completeness: 0%** — black box. All data passing through it is
unmodeled. This is the most significant single-card gap because it
sits in the critical path: every byte the SBC sends to the XP-32
goes through the FMT.

---

## Slot 11: AP I/F (612-4448-401-F)

**What the emulator models:**
- Command/status register at $FF0000 (bit 14=ready, bit 13=error)
- CMD_ARG_LO at $FF000E (panel command staging)
- CMD_ARG_HI at $FF0010 (argument high word)
- 4 × 32-byte channel windows at $FF0040/$0060/$0080/$00A0:
  - +$04 write port
  - +$08 data HIGH
  - +$0A data LOW
  - +$0E command/trigger
- $FF0004 bit 0 as port-ready flag (polled before bulk transfer)
- $FF0008 as bidirectional bulk data port (polled loop at F04AE2)
- AP I/F BERR when XLTR DMA is in progress (phase 0x1A00)
- $FF004A (CH1 status word at Data_A+2) — host-injected

**What's missing:**
- **Host-side counterpart registers** (HMA, WC, CTRL, FN, LITES, RSTAP
  per FPS-100). The AP I/F is dual-ported: the SBC sees one side, the host
  sees another. The emulator injects directly into SBC-side registers
  without modeling the host-side translation.
- **Host-side bus model** — no PDP-11 UNIBUS/QBUS or VAX BI bus.
- **Dual-port SRAM contention model** — 8 × Am29705 16×4 dual-port SRAMs
  (32 bits wide); simultaneous access behavior unknown.
- **Channel data port semantics** — $FF004A (status at Data_A+2) is
  host-injected as 0x4F but the real meaning of bits in the status
  word is unknown.
- **$FF0008 operating modes** — the port has THREE documented modes in
  the firmware (inbound bulk at F04AE2, outbound bulk, and S-record ASCII
  at F04B22) but the register-level mechanism for mode selection is
  unknown (likely MODE1/MODE2 configuration).
- **256-byte gap at $FF0100-$FF01FF** — between APIF and XLTR blocks.
  Could be undocumented AP I/F registers.

**Completeness: ~25%** — SBC-side register access modeled but the
card's actual function (host↔SBC gateway) has no counterpart side.
This is the second most significant gap after FMT.

---

## Slots 10 + 9: XP-32 AC1 (EXEC 612-4805-002-R + ARITH 612-4806-002-F)

**What the emulator models: Nothing.**

These cards contain:
- **EXEC:** 2 × Am29116DCB 16-bit bipolar microprocessors + fixed
  80-bit × 2K EU PROM + decode PALs + probably the AU WCS SRAM
  array (Am2168/CY7C168 4K×4 SRAMs, 45 ns).
- **ARITH:** 1 multiplier + 2 adder floating-point pipelines (IEEE-754
  32-bit) + likely Weitek WTL-1032/1033 or WTL-1232/1233 parts +
  bipolar PROM decode fan-out.

Panel commands target these cards but produce no effects. The emulator
has no:
- Am29116 instruction execution
- EU PROM contents (need physical dump)
- AU WCS (4K × 128-bit × 4 banks)
- FP pipeline stages (multiplier, 2 adders)
- Data-pad registers (DPX, DPY)
- S-pad registers
- Table memory (TM)
- Main data memory (MD)
- Program source memory (PS)
- Memory controller interface (MEM CTL)
- DMA engines (XPDMAR, XTMDMA)

**Completeness: 0%** — the entire AC is a black box to the emulator.

---

## Slots 8 + 7: XP-32 AC2

Identical hardware to AC1. Same completeness analysis: **0%**.

---

## Slot 6: MEM CTL (612-4498-401-A)

**What the emulator models: Nothing.**

System Common Memory controller. Manages access to the SCM (System
Common Memory) shared between AC1 and AC2. The MEM CTL arbitrates
requests from two ACs to a shared memory bus.

The emulator does not model:
- SCM memory (4 cards of MAIN DATA; only 1 populated = 1 MW)
- SCM bus arbitration
- MEM CTL register interface (if any)
- LMD (Local Memory Data) path
- DMA between SCM ↔ LMD (XPDMAR)

**Completeness: 0%** — black box.

---

## Slots 5-1: MAIN DATA (612-4456-403-C, one of 4 populated)

**What the emulator models: Nothing.**

1 megaword × 32-bit SCM terminator card. The emulator has no shared
memory model at all.

**Completeness: 0%** — black box.

---

## Host-Side Cards (not in chassis, unknown)

The AP I/F's counterpart card in the host chassis. The host could be a
PDP-11 (UNIBUS/QBUS), VAX (BI bus), or IBM system. The counterpart card
translates host bus cycles into the AP I/F register set. All host-side
state in the emulator is injected through `host_sim`, which has no bus
model at all.

**Completeness: 0%** — unmodeled, unknown card.

---

## 0x700000 Mailbox

**What the emulator models:**
- $70001C: 32-bit read, host status word (bit 29 = host-needs-attention)
- $700020: 32-bit write, SBC reply word

**What's missing:**
- Which physical card the mailbox lives on is unknown (XLTR? MEM CTL? AP I/F?)
- Only 8 bytes of mailbox documented; firmware uses only these two words
- No write acknowledgement
- No contention model (multiple bus masters writing simultaneously)

**Completeness: ~50%** — the two words the firmware uses are modeled.

---

## Summary

| Card | Slot | Emulated? | Completeness | Gap severity |
|---|---|---|---|---|
| VBUS SBC | 14 | Yes | ~75% | Minor (parity, straps) |
| VBUS XLTR | 13 | Register-level | ~40% | Major (no bus-bridge function) |
| UNIV FMT | 12 | No | 0% | **Critical** (in data path) |
| AP I/F | 11 | SBC-side only | ~25% | **Critical** (no host side) |
| XP-32 EXEC (AC1) | 10 | No | 0% | **Critical** (target of all panel commands) |
| XP-32 ARITH (AC1) | 9 | No | 0% | **Critical** (no pipeline model) |
| XP-32 EXEC (AC2) | 8 | No | 0% | Major (second AC) |
| XP-32 ARITH (AC2) | 7 | No | 0% | Major (second AC) |
| MEM CTL | 6 | No | 0% | Major (SCM arbitration) |
| MAIN DATA | 5-1 | No | 0% | Minor (only used via DMA) |
| 0x700000 Mailbox | — | Partial | ~50% | Minor (adequate for firmware) |
