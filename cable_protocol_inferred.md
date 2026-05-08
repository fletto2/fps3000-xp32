# FPS-3000 host-cable protocol — derived from sources

The cable runs between the **host-side AP I/F card** (e.g.
`612-4012-003` Q-bus or `612-4013-001` UNIBUS) and the
**chassis-side AP I/F card** (`612-4448-401-F`).

> **Update (2026-05-09)**: this protocol is no longer purely
> *inferred* — `4448_APIF_netlist.txt` in
> [github.com/fletto2/ap120dg](https://github.com/fletto2/ap120dg)
> documents the actual J22 + J23 cable connectors with every
> signal named for the AP-120B-era 4448 AP I/F card. Lovett's
> FPS-3000-era `612-4448-401-F` is the next-generation revision
> in the same card family — pinout almost certainly identical
> or trivially mappable.
>
> The earlier "inference" estimate of ~50 logical signals was
> off by ~3× — the actual cable carries ~150 logical signals
> across two connectors. Substantial implications for the
> substitute-card design (FPGA required, not MCU).

## Source: `4448_APIF_netlist.txt`

The 4448 chassis-side AP I/F card has two cable connectors:

| Connector | Pin count | Position |
|---|---|---|
| **J22** | A1-A100 | left side of card |
| **J23** | B1-B99 (B100 not listed) | right side |
| **Total** | **~199 pins per card** | |

Pin numbering convention (per netlist preamble): `1 = leftmost
component side, 100 = rightmost solder side; odd = component
side, even = solder side`.

## Logical signal classes

From the 4448 netlist's signal names, the cable carries these
distinct functional classes:

### Power and ground (~16 conductors)

`+5V`, `GND` distributed through the cable. The connectors have
+5V/GND at A1-A4 and similar pins, plus alternation through the
length. Standard noise-immunity practice for ribbon cables.

### Three independent 16-bit data buses (48 lines)

The 4448 separates data paths by purpose, **not** multiplexing
them like a typical bus:

| Bus | Pins | Use |
|---|---|---|
| **HD00..HD15** | A74-A80, B24-B36, B40-B64 | Host-buffer data path (host ↔ HSR / register file) |
| **DMA00..DMA15** | A62-A68, B10-B16, B39-B85 | DMA path (parallel to HD; for bus-master DMA cycles) |
| **HST00..HST15** | A61-A69, B9-B15, B47-B95 | Host strobe/status (associated with HD path) |

The **separate parallel buses** are why the cable is wide: the
4448 architecture lets DMA proceed concurrently with host
register pokes, with each path having its own data lanes and
control. Modern designs would multiplex these onto fewer wires
with arbitration overhead; the 4448 era spent the pins instead.

### Auxiliary data routing (~24 lines)

| Bus | Pins | Use |
|---|---|---|
| **PNL08..PNL15** | A11-A29 | Panel data (front-panel switch register?) |
| **DA08..DA15** | A12-A30 | Data-pad-A side |
| **SP+DP08..SP+DP15** | A19-A34 | S-pad + Data-pad combined routing |

These connect to the AP-side data-pad register file via the
cable — the host can examine/deposit DPX/DPY contents directly
through these wires (per FN.EXAM and FN.DEP semantics in
`nova_fps.c`).

### Register-select address (6 bits)

`REGSEL00..REGSEL05` (B54-B65, scattered) — **6 bits = 64
register slots**. Matches the SBC ROM's observation that the
AP I/F register file occupies 0xFF0000-0xFF00FF (= 256 bytes /
4 bytes per dword = 64 32-bit slots, or = 128 16-bit registers
addressed in pairs).

### I/O bus extension (~16 lines)

`IO24..IO39` (A47-A90, B68-B84) — looks like a wider extension
of the ~6-bit register select for higher-bandwidth I/O paths.
In a 16-bit address space the IOxx lines may carry the full
host address for DMA bus-mastering.

### Data-pad multiplex select (16 lines)

`DPMBS12..DPMBS27` (A51-A91, B67-B77) — selects which data-pad
register routes onto the SP+DP bus. Equivalent to the 4-bit
register file index inside DPX/DPY.

### Bus arbitration / DMA control (~6 lines)

| Signal | Pin | Use |
|---|---|---|
| `APDMAACT` / `APDMAACTR` | B7-B8 | AP DMA active (and strobed) |
| `HDMAACT` / `HDMAACTR` | B19-B21 | Host DMA active (and strobed) |
| `DMASTB` / `DMASTBR` | B22-B23 | DMA strobe |
| `HADRCLK` | B13 | Host address clock |

These coordinate **which side is bus master** (host or AP) and
the timing of address/data transitions during DMA cycles.

### Interrupts (7 lines)

| Signal | Pin | Use |
|---|---|---|
| `INTR*` | A39 | General interrupt |
| `INTFN` | A40 | FN-register interrupt |
| `INTPIN` / `INTPOUT` | A44, A92 | Interrupt-priority chain pins |
| `HALTINT*` / `CHALTINT*` | B34-B35 | AP-halt interrupt + clear |
| `CTL5INT*` / `CCT5INT*` | B50-B51 | CTL5 (programmed-I/O) interrupt + clear |
| `INT06*` / `INT07*` | B76-B78 | Two more interrupt sources |

These are the **3 documented event flags** (`RUNEVF=22`,
`DMAEVF=23`, `CB5EVF=24`) plus additional inputs for DMA-active
status and panel-busy indication.

### Handshake / acknowledge (~6 lines)

| Signal | Pin | Use |
|---|---|---|
| `READY*` | A5 | Generic ready |
| `IORDY*` | A10 | I/O ready (DTACK-equivalent) |
| `IOACK*` | A46 | I/O acknowledge |
| `CTLACK` / `CTLACKR` | B5-B6 | Control acknowledge |
| `DACK` / `DACKR` | A75-A77 | DMA acknowledge |
| `DAVAL` / `DAVALR` | A71-A73 | Data valid |

Multiple parallel handshake lines reflect the 4448's
multi-channel nature — each register access, DMA cycle, and
control pulse has its own ack path.

### Clocks (7 lines)

`IOCLK`, `B0CLK`, `B1CLK`, `B2CLK`, `B3CLK`, `NUF2CLK`,
`CTLCLK` — clocks distributed through the cable for
synchronisation with the AP's own internal clock domains.

### Reset and miscellany

`HRSET` (host reset), `SYRST*` (system reset) — separate-purpose
reset lines.

`MDCA1`, `B0CLK`, `MDWRT*`, `IN100`, `OUT*`, `BXA2HD`,
`BXB2HD`, `SAPX`, `SAPXR`, `SHSTX`, `SHSTXR`, `SPLFMT*` — additional
control / mux-select / format-select lines.

`OVFL*`, `UNFL*` — floating-point overflow / underflow status.

`RUN*`, `RUNIND`, `DMAIND` — AP run/DMA indicator lines.

## Total signal count

Adding it up:

| Class | Count |
|---|---|
| Power / ground | ~16 |
| HD data | 16 |
| DMA data | 16 |
| HST strobe/status | 16 |
| PNL data | 8 |
| DA data | 8 |
| SP+DP data | 8 |
| Register select (REGSEL) | 6 |
| I/O extension (IOxx) | 16 |
| DP-Mux select (DPMBS) | 16 |
| Arbitration / DMA control | 6 |
| Interrupts | 7 |
| Handshake / ack | 6 |
| Clocks | 7 |
| Reset | 2 |
| Misc control + status | ~15 |
| **TOTAL** | **~169** |

Of which **~150 are logical signals** (excluding power/ground).
The 199-pin total leaves a small margin for un-listed
signals + cable-side noise-immunity grounds.

## Implications for the substitute card

### MCU options are not viable

A single Pi Pico 2 has 30 GPIOs. Two in tandem give 60. Even
the highest-pin MCU options (Teensy 4.1 with 55, RP2350B with
48) are **far short of the 150 logical signals needed**.

Port-expander solutions (74HC595/165 shift registers) introduce
~10-100 µs latency per access — fine for a few low-priority
signals, but **prohibitive for 100+ lines that need cycle-accurate
timing for bus arbitration and DMA**.

### FPGA is required

The substitute card needs an FPGA with 150+ user I/O. Options:

| Board | I/O | Cost | Notes |
|---|---|---|---|
| **ULX3S 25F** | 108 | $155 | LFE5U-25F-6BG381C; 108 user I/O via 4 PMOD slots + GPIO + dedicated lines. *Tight* for 150 signals. |
| **ULX3S 85F** | 108 | $235 | Same I/O count as 25F (limited by board breakout, not chip). Bigger fabric only. |
| **OrangeCrab 85F** | ~100 | $129 | Compact form factor; might be tight on I/O |
| **ECP5-5G-EVN** | ~150 | $99 | LFE5UM5G-85F-8BG756I; 150+ user I/O including high-speed serdes |
| **Custom ECP5 PCB** | 150+ | $200+ design + fab | Form-factor-correct quad Q-bus card with ECP5 LFE5U-85F-6BG381C (130-160 user I/O) |

**Recommendation: ECP5-5G-EVN dev board** ($99) for development,
followed by a custom Q-bus quad card with the same chip family
once the design is validated.

### Reference design exists

`fletto2/ap120dg`'s `adapter.md` traces the **280B Nova/Eclipse
I/O Adapter** schematic in detail (726 lines). That's the
host-side counterpart for DG Nova hosts — exactly the pattern
we need to adapt for Q-bus. Different host-bus signals, but
the same architectural decomposition: bus interface →
qualification gates → register file mux → cable transceivers.

The host-side card's job is:
1. Decode host-bus cycles into "register N read/write" events
2. Forward to the chassis-side card via the cable's REGSEL +
   data + handshake lines
3. On DMA, become bus master on the host's bus and shuttle data
   between host RAM and the chassis via the DMA bus
4. Translate chassis-side interrupt sources into host-bus
   interrupts at the correct priority level

This whole structure naturally fits an FPGA — interface
decoders, state machines, mux logic, all classic FPGA work.

## Mapping the cable into a working substitute

Phase 1 (cable-side validation only, no Q-bus integration yet):

1. **FPGA mirrors the 4448 chassis-side card's exact pin
   semantics** — every signal in `4448_APIF_netlist.txt` either
   gets driven from the FPGA or read by the FPGA.
2. **A modern PC** controls the FPGA over USB-C — register
   pokes, status reads, IRQ event observation. Phase 1 testing
   uses just the cable interface.
3. **Validation**: power up FPS-3000 chassis with the FPGA
   substitute attached, observe the SBC's panel-init sequence
   (`0x276..0x27D`) — every poke should be visible across the
   cable, every status read should return data.

Phase 2 (Q-bus integration on the same FPGA):

1. Same FPGA, additional logic block decoding Q-bus cycles
2. PDP-11/73 sees the substitute card as a Q-bus device
3. End-to-end validation: /73 issues `XPSEL/XPRUN/XPWAIT` via
   the substitute → cable → SBC → XP-32

## Validation against Lovett's specific card

Two physical-world checks remain (both ~1h bench tasks):

1. **Connector count**: does Lovett's `612-4448-401-F` have
   exactly J22 + J23 (= 199 pins) like the AP-120B-era 4448?
   Visual inspection of the card.
2. **Pin-name correspondence**: probe a few known signal pins
   (e.g., A1 = +5V, A100 = +5V, B53 = HST10) with a multimeter
   while the chassis is powered and the SBC is running. Confirm
   the netlist's signal names match the FPS-3000-era card.

These are *validation*, not *discovery* — the netlist gives us
strong priors for the answer. Total bench time: hours, not
days.

## What stays open

The netlist tells us **what the cable carries**, not **what
each signal does over time** at the protocol level. We still
need to characterize:

- Bus-cycle timing: setup/hold relationships between REGSEL,
  HD/DMA/HST, IOACK / DACK / IORDY
- DMA arbitration sequence: which signals go in what order when
  the AP becomes bus master
- Interrupt-acknowledge protocol: how `INTPIN`/`INTPOUT` chain
  works for priority arbitration

These can be reverse-engineered from `nova_fps.c` (which models
the host-side I/O state machine in detail) plus the SBC ROM's
poke patterns. **No new bench captures needed for protocol
characterization — only for validating that the FPS-3000-era
card matches the AP-120B-era netlist.**
