# Substitute host-side AP I/F card — hardware plan

A modern hardware substitute for the missing host-side AP I/F
card. Plugs into the **PDP-11/73's Q-bus** on one side and the
**FPS-3000 chassis cable** on the other.

> **Plan rev 2 (2026-05-09)**: original plan called for a dual
> Pi Pico 2 tandem. **That plan is dead.** The
> `4448_APIF_netlist.txt` in `fletto2/ap120dg` shows the cable
> carries ~150 logical signals across J22+J23 (~200 pins
> total) — far too many for any MCU. Plan now centers on a
> Lattice ECP5 FPGA dev board.

## Why FPGA is required

| Hardware | Available I/O | vs 150 needed |
|---|---|---|
| Pi Pico 2 (RP2350) | 30 GPIO | far short |
| Pi Pico 2 ×2 | 60 GPIO | far short |
| Teensy 4.1 (iMXRT1062) | 55 GPIO | far short |
| RP2350B custom | 48 GPIO | far short |
| **ECP5-5G-EVN dev board** | **~150** | ✓ |
| ULX3S 25F | ~108 | tight, would need expanders |
| ULX3S 85F | ~108 | same |
| Lattice MachXO3 dev kits | 100-200 | ✓ |

Plus the FPGA's structural advantages:
- **Cycle-accurate Q-bus timing** (BRPLY in <1 clock = trivial)
- **DMA bus-master state machine** is natural FPGA work
- **Multiple parallel data paths** (HD / DMA / HST buses) all
  drive simultaneously without firmware juggling
- **Register-select decode** (REGSEL00-05 → 64 registers) is a
  6-input mux in 0 ns
- **Open-source toolchain** (Yosys + nextpnr-ecp5 + Project
  Trellis) is excellent for ECP5

## Recommended board: ECP5-5G-EVN

Lattice **ECP5UM5G-85F** evaluation board, ~$99:
- LFE5UM5G-85F-8BG756I FPGA — 85K LUTs, 670 KB RAM
- **150+ user I/O** broken out across 4 expansion headers
- USB-JTAG + USB-UART + USB-FTDI for programming and host comms
- 100 MHz oscillator, on-board PLLs to 400+ MHz
- 5V/3.3V/2.5V/1.8V power — drives 5V TTL via level translators

Alternatives ranked:

| Board | $ | I/O | Why not first choice |
|---|---|---|---|
| **ECP5-5G-EVN** | $99 | 150+ | **Best fit** |
| Lattice MachXO3LF-9400-EVN | $89 | 100+ | Smaller fabric, less margin for Q-bus state machine |
| ULX3S 85F | $235 | 108 | Tight on I/O; would need port expanders |
| Custom ECP5 PCB | $200+ | 150+ | Form-factor-correct quad Q-bus card; fab after validation |

## System architecture (FPGA-centric)

```
   PDP-11/73 ────── Q-bus ─────────┐
                  ~34 signals       │
                                    │
                            ┌───────▼──────────────────────────────────┐
                            │  ECP5-5G-EVN with custom HDL design      │
                            │                                          │
                            │  ┌─────────────────────────────┐         │
                            │  │ Q-bus interface block       │         │
                            │  │  - BSYNC/BDIN/BDOUT decode  │         │
                            │  │  - BDAL[21:0] mux          │         │
                            │  │  - Bus-master state machine│         │
                            │  │  - IRQ priority encoder    │         │
                            │  └────────────┬────────────────┘         │
                            │               │                          │
                            │  ┌────────────▼──────────────┐           │
                            │  │ Bridge logic / register file│         │
                            │  │  - 64 × 16-bit registers   │         │
                            │  │  - DMA address/count latches│         │
                            │  │  - IRQ event collation     │         │
                            │  └────────────┬──────────────┘          │
                            │               │                          │
                            │  ┌────────────▼──────────────┐           │
                            │  │ Cable interface block       │         │
                            │  │  - REGSEL00-05 driver       │         │
                            │  │  - HD/DMA/HST data lanes    │         │
                            │  │  - Handshake state machines │         │
                            │  │  - IRQ source aggregation   │         │
                            │  └────────────┬──────────────┘          │
                            │               │                          │
                            │  ~150 signals through 5V level shifters  │
                            │  (5-6 × 74LVCH16245 16-bit translators)  │
                            └───────────────┬──────────────────────────┘
                                            │
                                ~200 pins ──┴──── J22 + J23 cable to
                                                  FPS-3000 slot 11
                                                  (612-4448-401-F)
```

## Build phases (revised)

### Phase 1A — Cable-side bring-up (FPGA only, no Q-bus)

Goal: validate the FPGA's cable interface against the FPS-3000
chassis. No Q-bus logic in this phase; modern PC controls the
FPGA over USB-UART.

- ECP5-5G-EVN dev board on bench
- 5-6 × 74LVCH16245 level shifters on a daughter board
- Custom mating connector for J22+J23 (TBD per visual inspection
  of Lovett's `612-4448-401-F`)
- Ribbon cable (likely 100-conductor + 100-conductor pair, or
  single 200-pin assembly)
- HDL: cable interface + register file + USB-UART command
  interpreter
- Modern PC tool: Python, sends register-poke / register-read /
  IRQ-wait / DMA-test commands over USB-UART

**Validation milestones**:
1. Power on, FPGA loads bitstream, USB enumerates
2. Cable connected to chassis, chassis off — continuity test
3. Chassis powered, observe SBC's panel-init pokes (`0x276..0x27D`)
   from the FPGA's perspective
4. FPGA mirrors a successful poke ↔ read round-trip
5. FPGA writes a `0x26C` PCMD_RELEASE — observe SBC's TCBRDHC
   process it
6. FPGA receives an interrupt from chassis (DMA-complete or
   AP-halt event)

### Phase 1B — Q-bus integration

Same FPGA, additional HDL block decoding Q-bus cycles. Custom
PCB at this phase to fit a /73 quad slot.

- Custom 4-slot Q-bus PCB with same ECP5UM5G-85F + level
  shifters + edge connector
- HDL: Q-bus interface block (BSYNC/BDIN/BDOUT/BRPLY/BIRQ
  decode + bus-master state machine for DMA)
- /73-side software: small RSX-11M+ driver mimicking the
  FPS-3000-era driver behaviour. Pattern from `dapex_dg.asm`
  in the upstream repo (DG Nova driver for FPS-100; analogous
  shape for Q-bus).

**Validation milestones**:
1. Card seated in /73 backplane; /73 boots normally
2. /73 issues register read at SYSGEN-configured I/O address —
   correct DTACK + data
3. /73 issues register write — change visible on chassis
4. Chassis-side IRQ → /73 sees corresponding Q-bus IRQ at
   expected vector
5. End-to-end: from RSX-11M+ on /73, send a panel command that
   selects an XP-32 channel; observe SBC's TCBRDHC dispatch

## HDL design effort

| Block | LoC (Verilog estimate) | Hours |
|---|---|---|
| Cable interface (register file + REGSEL + 3-bus driver + handshakes) | ~800 | 30 |
| IRQ aggregation + event-flag encoding | ~200 | 8 |
| DMA bus-master FSM (chassis side) | ~400 | 15 |
| USB-UART command interpreter (Phase 1A) | ~300 | 10 |
| Q-bus interface (Phase 1B) | ~600 | 20 |
| Q-bus DMA-master FSM | ~400 | 15 |
| Testbench / cocotb sims | ~1000 | 30 |
| **Total HDL** | **~3700** | **~130** |

Plus PCB design (Phase 1B custom card): ~30h. Plus host-PC
Python tooling: ~15h. Plus integration / debug: ~30h.

**Phase 1A total: ~75h** (HDL cable + UART + PC tool +
validation, dev board only)
**Phase 1B incremental: ~80h** (Q-bus HDL + PCB + driver
software + integration)
**Phase 1A + Phase 1B total: ~155h**

This is *roughly the same* as the previous dual-Pico estimate
(~110h), trading firmware complexity for HDL volume. The
single-FPGA path is **more deterministic** (no inter-chip sync
issues, no port expanders, no timing margin scares) — net
better outcome for the same effort.

## Parts cost

### Phase 1A

| Part | Qty | Cost | Notes |
|---|---|---|---|
| ECP5-5G-EVN dev board | 1 | $99 | Mouser / Digikey / Lattice |
| 74LVCH16245 16-bit level shifter (3.3V↔5V) | 6 | $18 | for the ~96 highest-speed signals |
| 74HC595 / 74HC165 for low-speed misc lines | 2 | $1 | for status LEDs etc. |
| Custom mating connector for J22/J23 | 2 | $20 | TBD per Lovett's bench inspection |
| 200-conductor ribbon cable / pair of 100-conductor | 1 | $20 | ~3 ft |
| Daughter board (perfboard or simple PCB) for level shifters | 1 | $15 | OSHPark or hand-built |
| Hookup wire, breakouts, headers | — | $10 | |
| **Phase 1A total** | | **~$185** | |

### Phase 1B incremental

| Part | Qty | Cost |
|---|---|---|
| Custom Q-bus PCB (quad height, 4-slot) | 1 | $40-80 |
| ECP5UM5G-85F-8BG381C IC | 1 | $50 (or move from dev board) |
| FPGA support (config Flash, decoupling, regs) | bag | $20 |
| Q-bus edge connector | 1 | $30 (proper Q-bus socket, hard to find) |
| Power regulation (5V→3.3V/2.5V/1.2V) | bag | $10 |
| **Phase 1B total** | | **~$150-200** |

**Combined Phase 1A + 1B: ~$335-385**.

This is more expensive than the original ~$90 dual-Pico plan,
but **delivers a working Q-bus device with cycle-accurate
timing and headroom for full 1.6 MW/s DMA**, which the dual
Pico approach probably could not achieve.

## Open-source HDL references

- **CHDickman's `qbus_ide`** — Q-bus IDE adapter using ECP5-class
  FPGA. Open-source Verilog. Q-bus interface implementation
  + DMA bus-master logic. Adapt this for our register-bridge
  use case.
- **Joerg Hoppe's UniBone-Q (QBone)** — UNIBUS / Q-bus
  bridge using BeagleBone Black PRU. Different architecture
  (PRU instead of FPGA) but reference for the bus-cycle
  characterisation.
- **fletto2/ap120dg `adapter.md`** — schematic trace of the
  280B Nova adapter. Same architectural pattern as our Q-bus
  adapter; different host bus.

## Validation against Lovett's hardware (the only physical
work needed)

Two short bench tasks remaining:

1. **Photograph J22 and J23 connectors** on Lovett's
   `612-4448-401-F`. Confirm 100+99 pin headers; note connector
   type/manufacturer for sourcing the mating side. ~30 min.

2. **Spot-check 5 known pins** (e.g., A1 = +5V, A3 = GND,
   B53 = HST10, B72 = LDFN*, B75 = DPMBS25*) with a multimeter
   while chassis is powered. Confirms `4448_APIF_netlist.txt`
   matches the FPS-3000-era card. ~30 min.

If those check out — and they almost certainly will — the
substitute-card design proceeds **using the netlist as the
authoritative reference** for cable signal assignments. No LA
captures needed.

## Why this represents progress despite plan changes

The earlier plan (dual Pi Pico 2 + ~$90 parts) was based on
underestimating the cable signal count by 3×. The
`4448_APIF_netlist.txt` netlist resolves that question
definitively, *and* gives us a reference design pattern from
the 280B Nova adapter for the host-bus side. So the larger
substitute-card budget ($335 vs $90) buys:

1. **Right-sized hardware** that actually has enough I/O for
   the cable
2. **Deterministic Q-bus timing** that won't have silent
   reliability issues with vintage backplane noise
3. **Reusable HDL design** that can transition from dev board
   to custom Q-bus card without rewriting

Net: same goal, scaled appropriately to the actual problem.
