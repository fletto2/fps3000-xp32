# Substitute host-side AP I/F card — hardware plan

A **modern hardware substitute** for the missing host-side AP I/F
card (`612-4012-003 Q22 BUS ADPTR FPS3000/5000` for Q-bus, or its
UNIBUS sibling `612-4013-001`). Implements the cable protocol
documented in `cable_protocol_inferred.md`.

This is the **D1 task** in `project_plan.md` — desk-work that
unblocks Objective A (PDP-11/73 ↔ FPS-3000 connection).

## Scope: two phases

The substitute board can be built incrementally:

**Phase 1 — modern host PC ↔ FPS-3000.** A USB-attached board
drives the chassis-side cable interface. A Python tool on the PC
issues commands. Lets us bring up the chassis, validate the SBC
firmware, develop XP-32 microcode — without yet involving a
PDP-11 host. **First-milestone target.**

**Phase 2 — PDP-11/73 ↔ FPS-3000.** Adds Q-bus electricals so the
/73 sees the substitute board as a Q-bus peripheral. The chassis
side is the same as Phase 1. Effectively wraps the Phase-1
hardware with a Q-bus front-end.

Phase 1 alone is enough to develop microcode. Phase 2 is needed
for "running real Bomem-style host software on a PDP-11", which
is **out of scope per the refocused project objectives** but
worth doing eventually as a hardware demonstration.

## Three design options (Phase 1)

| Option | Parts cost | Pin count | Sync complexity | Effort |
|---|---|---|---|---|
| Single Pico 2 + port expanders | $25 | 30 GPIO + 8-bit latches | none | ~80h |
| **Dual Pico 2 in tandem** | **$45** | **60 GPIO** | **moderate** | **~90h** |
| Teensy 4.1 | $60 | 55 GPIO | none | ~80h |
| RP2350B custom board | $150 + PCB | 48 GPIO | none | ~100h |
| Lattice ECP5 / Cyclone IV FPGA | $150-300 | 100+ I/O | low | ~150h |

**Recommended: dual Pico 2 in tandem** — best parts-on-hand /
GPIO-headroom / cost balance. The Pico's PIO is genuinely
purpose-built for this kind of synchronous register-bus driving.

## The dual-Pico tandem topology

Two Pico 2s split the cable signals along functional lines:

```
                            FPS-3000 chassis
                            slot 11: AP I/F card
                            (612-4448-401-F)
                                    │
                                    │ ~50-pin cable
                            ┌───────┴────────┐
                            │ Custom adapter │  ← matches the
                            │   connector    │     (TBD-physical-pinout)
                            └───────┬────────┘     connector on the
                                    │              chassis-side card
                                    │
         3.3V ↔ 5V level-shift via 74LVCH16245s × 3
                                    │
            ┌───────────────────────┴─────────────────────────┐
            │                                                 │
   ┌────────┴───────────┐                          ┌──────────┴──────────┐
   │  Pico A             │                          │  Pico B             │
   │  "Register Pico"    │                          │  "Bus-Master Pico"  │
   │                     │                          │                     │
   │  16 data            │                          │  22 host-bus addr   │
   │  9 register addr    │                          │   (Phase 2 unused)  │
   │  R/W + strobe       │                          │  4 bus arb signals  │
   │  DTACK              │                          │  3 IRQ-source lines │
   │  USB CDC ↔ host PC  │                          │  1 host→AP IRQ      │
   │                     │                          │  1 reset            │
   │  GPIO used: 30      │                          │  GPIO used: 31*     │
   │                     │                          │   (*one IRQ via I²C │
   │                     │                          │    or pri-encoded)  │
   └─────────┬───────────┘                          └──────────┬──────────┘
             │                                                 │
             └────── PIO-IRQ sync line (1 GPIO) ───────────────┘
             └────── SPI master/slave (4 GPIO) ────────────────┘
             └────── shared 5V power, common ground ───────────┘
```

### Pin assignment per Pico

**Pico A — "Register Pico"** (the cleaner half):

| GPIO range | Function |
|---|---|
| GP0..GP15 | 16-bit data bus (bidirectional, level-shifted to 5V) |
| GP16..GP24 | 9-bit register address |
| GP25 | R/W strobe |
| GP26 | DTACK (input from chassis) |
| GP27 | PIO-IRQ sync line (to/from Pico B) |
| GP28 | SPI clock to Pico B |
| GP29 | SPI MOSI to Pico B |
| **Total** | **30 GPIO** ✓ |

**Pico B — "Bus-Master Pico"** (Phase 1 uses just IRQ + sync):

| GPIO range | Function (Phase 1 only) |
|---|---|
| GP0..GP2 | 3 IRQ-source lines from chassis |
| GP3 | Host→AP IRQ (CTRL bit 14 APIRT) |
| GP4 | Reset |
| GP5 | PIO-IRQ sync line (to/from Pico A) |
| GP6..GP9 | SPI slave from Pico A (CLK, MOSI, MISO, CS) |
| GP10..GP31 | **Phase 2: 22-bit host-bus DMA address** (unused in Phase 1) |
| **Total** | **10 GPIO used in Phase 1; 31 in Phase 2** |

### Inter-Pico coordination

Two mechanisms working together:

1. **SPI (Pico A → Pico B)** — command-level coordination.
   Pico A is master, Pico B is slave. Operations like "raise
   IRQ to host" or "monitor irq line N" sent as SPI packets.
   Plenty fast at 60+ MHz; ~1 µs round-trip.

2. **PIO-IRQ sync line** — cycle-accurate bus-cycle sync.
   When a register cycle on the cable needs both Picos to
   change pin state simultaneously (rare in Phase 1, but
   essential in Phase 2 for DMA bus-master operations), one
   Pico raises a hardware sync line and the other's PIO state
   machine triggers off it. ~20 ns skew.

**Phase 1 only needs SPI**. PIO sync is reserved for Phase 2's
DMA path.

## Level shifting

Pico 2 GPIOs are 3.3 V; the cable carries 5 V TTL signals.

- **3 × 74LVCH16245** (16-bit bidirectional level translators
  with direction control) cover the 16 data + 9 addr + assorted
  control lines.
- Direction lines driven by the Pico's R/W output.
- ~$3 each, jellybean part.

## Connector to the chassis-side cable

The `612-4448-401-F` card has **a specific FPS-proprietary
cable connector**. We don't yet know its exact type/pinout —
this is the only remaining bench task for Phase 1 (and it's
short: hours, not days).

Once the connector is identified:
- **If it's standard 50-pin or 60-pin IDC** (common in FPS gear
  per the FPS-100 IOP-UNI ancestor): off-the-shelf ribbon cable
  + IDC connectors, $10.
- **If it's a custom multi-pin proprietary connector**: probe
  the chip-level layout on the card and use individual female
  jumper wires to a custom adapter PCB. Slightly less elegant
  but cheap.

The 1984 FPS pricing list shows the cable as `422-0015-001
Co-Processor Interconnect Cable` — $100 in 1984 dollars,
suggesting a moderately complex cable assembly but not exotic.

## USB host PC interface

Pico A's USB-C presents as a **CDC virtual serial port** to a
modern PC. A Python script on the PC sends frame-formatted
commands like:

```
WRITE_REG addr=0xE  data=0x26C    ; PCMD_RELEASE
READ_REG  addr=0x18                ; status / trigger
WAIT_IRQ  src=DMA  timeout=1000    ; wait for DMA complete
DMA_READ  host_phys=...            ; staged DMA op
```

The Pico A firmware decodes these and either:
- Issues the corresponding cable transaction directly (for
  register pokes), or
- Coordinates with Pico B via SPI (for DMA / IRQ-related ops)

USB CDC at 12 Mbps gives ~1 MB/s sustained — plenty for
register-poke development. Bulk DMA validation in Phase 2 may
benefit from USB 2.0 high-speed (Pico W variant or external USB
PHY) or moving to Ethernet (Teensy or ESP32 add-on).

## Firmware structure (Pico A)

```
main.c (Pico A — Register Pico)
├── usb_cdc.c           — host PC packet protocol
├── cable_master.c      — issues cable transactions
│   ├── pio_register_poke  ; PIO program: 9-addr + 16-data
│   │                       ; + strobe, sample DTACK
│   └── pio_register_read   ; mirror of above for reads
├── spi_to_picob.c      — coordination with Pico B
└── timing_constants.h  — strobe widths, setup/hold times
```

**Firmware structure (Pico B)**:

```
main.c (Pico B — Bus-Master Pico)
├── spi_from_picoa.c    — slave to Pico A
├── irq_monitor.c       — watches the 3 IRQ source lines from
│                          chassis, reports source via SPI
├── irq_inject.c        — drives the host→AP IRQ line on demand
└── reset.c             — drives the reset line on demand
```

Firmware lives in C with embedded PIO assembly for the
register-poke timing path. Total LoC estimate: ~2000 across both
Picos.

## Validation steps after build

1. **Power-up + blink test** — confirm both Picos boot, USB
   enumerates, SPI handshake succeeds.
2. **Cable connector continuity test** — multimeter every wire
   end-to-end with chassis off, no surprises.
3. **Chassis powered, no commands** — observe what the SBC
   pokes onto the AP I/F register file at boot. (The SBC's
   panel-init sequence at `0x276..0x27D` writes to specific
   register offsets; if Pico A captures those writes correctly,
   the cable is physically working.)
4. **First register read** — Pico A reads back what the SBC
   wrote. If values match, full register-poke path works.
5. **First write** — Pico A writes a recognised value (e.g.,
   the panel-command for "release/no-op", `0x26C`). Confirm
   the SBC's `TCBRDHC` task processes it (visible via SBC's
   front-panel LEDs or further reads).
6. **First IRQ propagation** — set up a chassis-side condition
   that raises `DMAEVF`-equivalent and confirm Pico B sees it.

Each step is a short bench session (~1-2 hours including
debug). Total bring-up time once hardware is built: ~2-3 days
of focused work.

## Cost summary

| Part | Source | Cost |
|---|---|---|
| 2 × Raspberry Pi Pico 2 | Adafruit / Pimoroni / Mouser | $10 |
| 3 × 74LVCH16245 16-bit level shifter | Mouser / Digikey | $9 |
| 50-pin IDC ribbon + connectors | Mouser / eBay | $10 |
| Mating connector for chassis card | TBD per pinout | $5-15 |
| Perfboard / custom PCB | Mouser / OSHPark | $5-20 |
| Hookup wire / DuPont jumpers | bench supply | $5 |
| **Total parts** | | **~$50** |

vs. ~$60 for Teensy 4.1 alternative. Tandem-Pico is the
**cheapest path that uses commodity parts on the bench**.

## What this unblocks

Once Phase 1 is built and validated:

- **Objective A.2** (substitute host-side card) is achieved.
- **Objective B** can proceed: microcode authored for the XP-32
  AU can be uploaded via the Pico-to-cable bridge, run on the
  chassis, and the result observed in MD memory by reading it
  back through the same bridge.
- **The SBC firmware can be exercised** with arbitrary command
  sequences from a modern PC, accelerating the discovery of
  edge cases and undocumented behaviours.

The Phase 1 substitute is **the gateway to all downstream
microcode work** — without it, no kernel can be uploaded to the
XP-32 because the S-record path enters via the AP I/F that's
currently disconnected.

## Next concrete actions

1. **Order parts** — 2 Pico 2s, 3 × 74LVCH16245, IDC connectors,
   ribbon cable. Total ~$30; lead time ~1 week.
2. **Identify the chassis-side cable connector** on Lovett's
   `612-4448-401-F`. Photo + DMM continuity → connector type +
   pinout. ~2 hours bench work.
3. **Write the host-PC Python tool** — packet protocol over USB
   CDC, mirror of the SBC's command vocabulary. ~10 hours desk
   work; can start before parts arrive.
4. **Write the Pico A PIO program** for register-poke timing.
   ~8 hours; can start before parts arrive.

Steps 1-4 are independent; can run in parallel once Lovett
provides the connector identification.
