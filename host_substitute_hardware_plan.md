# Substitute host-side AP I/F card — hardware plan

A **modern hardware substitute** for the missing host-side AP I/F
card (P/N `612-4012-003 Q22 BUS ADPTR FPS3000/5000`). The
substitute card plugs into the **PDP-11/73's Q-bus** on one side
and the **FPS-3000 chassis cable** on the other, presenting itself
to the /73 as a Q-bus peripheral and to the FPS-3000 as the
expected host-side AP I/F.

Implements the cable protocol documented in
`cable_protocol_inferred.md`. This is the **D1 task** in
`project_plan.md` — desk-work that unblocks Objective A
(PDP-11/73 ↔ FPS-3000 connection).

```
   PDP-11/73                        FPS-3000 chassis
   ┌──────────┐  Q-bus     ┌──────────────────────┐    cable    ┌────────┐
   │  J-11    │◄──────────►│ Substitute AP I/F    │◄───────────►│ slot 11│
   │          │  ~34       │   (this card)        │   ~50       │ AP I/F │
   │          │  signals   │                      │   signals   │chassis │
   └──────────┘            └──────────────────────┘             └────────┘
                              │
                              │ (optional, dev only)
                              ▼
                           USB-C to dev workstation
                           (firmware updates, debug)
```

## Two interfaces to handle

### Q-bus side (PDP-11/73)

22-bit Q-bus signals, all 5V TTL:
- **BDAL[15:0]** — address/data, time-multiplexed (16 lines)
- **BDAL[21:16]** — extended address (6 lines, only address phase)
- **BSYNC** — bus cycle start
- **BDIN** — read strobe (CPU → device)
- **BDOUT** — write strobe (device → CPU... wait, names confusing)
- **BWTBT** — write/byte indicator
- **BRPLY** — device acknowledge
- **BIRQ4..BIRQ7** — interrupt request lines (1-4 lines, depends on level)
- **BIAKI / BIAKO** — interrupt acknowledge daisy chain
- **BDMR** — DMA request (substitute card asserting bus mastery)
- **BDMGI / BDMGO** — DMA grant daisy chain
- **BSACK** — DMA grant acknowledge
- **BREF** — refresh
- **BINIT** — bus reset

**Total: ~34 logical signal lines** plus power, ground, spares.

The card needs to be both a **Q-bus slave** (receiving CPU
register pokes and reading them back) and a **Q-bus master**
(performing DMA into /73 RAM during AP-initiated transfers).

### FPS cable side (to chassis)

Per `cable_protocol_inferred.md`: ~50 logical signals — register
pokes (9 addr + 16 data + R/W + DTACK), bus-master pass-through
for DMA, 3 AP→host irq + 1 host→AP irq, reset.

## Two-Pico tandem fits, just barely

Total cable-side + Q-bus-side: ~84 logical signals. Standard Pi
Pico 2 has 30 accessible GPIO. **Two Picos = 60 GPIO**, ~24
short of the worst case. Bridged via small amount of expansion
glue:

```
                          Pi Pico 2 — "Pico Q" (Q-bus side)
                          ┌──────────────────────────────┐
   PDP-11/73       ┌──────┤  GP00..GP15: BDAL[15:0]       │
   Q-bus           │      │  GP16..GP21: BDAL[21:16]      │   (level-
                   │      │  GP22..GP29: 8 control lines  │   shifted
   ────────────────┤      │              (BSYNC, BDIN,    │   3.3V↔5V
   ─────────34─────┤      │               BDOUT, BWTBT,   │   via 74LVCH
                   │      │               BRPLY, BIRQ,    │    245s)
                   │      │               BIAK, BBSY)     │
                   │      │  + 1 × 74HC595 latch for      │
                   │      │    BDMR/BDMG/BSACK/BREF/BINIT │
                   │      │    (5 signals via shift reg)  │
                   │      │  GP25: SPI to Pico F          │
                   │      └───────────────┬───────────────┘
                   │                      │
                   │              SPI + PIO-IRQ sync
                   │                      │
                   │      ┌───────────────┴───────────────┐
                   │      │  Pi Pico 2 — "Pico F" (FPS    │
                   │      │  cable side)                  │
                   │      │  GP00..GP15: 16 data lines    │
                   │      │  GP16..GP24: 9 addr lines     │   (level-
                   │      │  GP25..GP28: R/W,strobe,DTACK,│   shifted
                   │      │              host→AP IRQ      │    via 2nd
                   │      │  GP29: SPI to Pico Q          │    set of
                   │      │  + 1 × 74HC165 shift-in for   │    74LVCH245s)
                   │      │    3 AP→host IRQs + 1 reset   │
                   │      │    + 4 bus-arb lines (Phase 2)│
   ─────────50─────┤◄─────┤    (8 signals via shift reg)  │
                   │      └───────────────────────────────┘
                   │
                   FPS cable to chassis-side AP I/F card
                   (612-4448-401-F in chassis slot 11)
```

### GPIO budget (revised)

| Pico | Direct GPIO | Via shift-reg expander | Total |
|---|---|---|---|
| Pico Q (Q-bus side) | 30 / 30 | 5 (BDMR, BDMG, BSACK, BREF, BINIT) | 35 ✓ |
| Pico F (cable side) | 30 / 30 | 8 (3 IRQ in + reset + 4 Phase-2 arb) | 38 ✓ |

**Each Pico exactly fills its 30 GPIO + needs one $0.30 shift
register to handle the lower-priority signals**. Workable.

## Sync between Pico Q and Pico F

The two cards share state at three places:

1. **Register-poke pass-through** (slowest, simplest): /73 writes
   to a Q-bus register on the substitute card → Pico Q decodes
   the write → SPI to Pico F → Pico F drives the corresponding
   FPS cable poke → DTACK back. Round trip ~10 µs at SPI
   60 MHz. Q-bus needs response in ~150 ns; we need to assert
   BRPLY *first* (before forwarding to Pico F) and **buffer the
   data** in Pico Q for write-pokes — the cable poke completes
   asynchronously.

2. **Read-back pokes** are trickier — /73 read needs data from
   the cable side. Two options:
   - **Cache-and-prefetch**: Pico F polls cable register file
     on a timer, keeps a shadow copy in shared SRAM (via SPI).
     /73 reads from the cache. ~1 ms staleness, fine for
     status polling.
   - **Block-and-fetch**: Pico Q stalls Q-bus by holding off
     BRPLY until SPI round-trip completes. Q-bus has a
     Bus-Timeout of ~10 µs, our SPI round-trip is comfortably
     under that. Cleaner semantically but stalls the /73 CPU.

3. **DMA bus-master** (Phase 2 / advanced): when the chassis
   wants to write to /73 RAM, the cable signals "AP wants bus
   mastership", Pico F notifies Pico Q via PIO IRQ sync line,
   Pico Q requests Q-bus mastery (BDMR), gets BDMG, then drives
   /73 RAM addresses on BDAL[21:0] and shuttles data through
   the cable. This needs cycle-accurate sync between the two
   Picos, hence the dedicated PIO IRQ line.

## Power and form factor

A Q-bus card lives in a **1× height (8.9 × 5.2 inch) slot** in
the /73 chassis backplane. The substitute card should fit a
quad-height (Q-Q) Q-bus slot:

- Custom PCB with 2 × Pico 2 SMD-soldered or socketed
- 6-7 × 74LVCH16245 level shifters (3 per side bus + a couple
  for control lines)
- 2 × 74HC595/165 shift register expanders
- Q-bus edge connector (40 fingers ÷ side, top + bottom = 80
  contacts on a quad card)
- FPS cable connector on the back edge (matches whatever
  Lovett's chassis-side card uses — TBD per `B1` bench task)
- USB-C breakout to one Pico for dev/debug
- Power: take 5 V off Q-bus, generate 3.3 V on-card with a
  buck regulator

Approximate PCB cost via OSHPark or JLCPCB: **$15-30** for a
quad Q-bus card. PCB design effort: **~30 hours** (KiCad,
mostly-mechanical layout; the schematic is straightforward).

## Alternative: skip the /73 for now, use modern PC

The user's clarification says the host **is** the /73, so the
runtime path goes Q-bus → substitute card → FPS cable. **But for
bring-up + Objective B microcode work**, the /73 isn't strictly
required — a modern PC over USB-C to one of the Picos can issue
the same command sequences.

Two phases possible:

**Phase 1A — modern-PC dev mode** (build first):
- Pico F populated, Pico Q omitted (or Pico Q populated but Q-bus
  side disabled)
- Modern PC ↔ Pico F via USB-C ↔ FPS cable to chassis
- All XP-32 microcode work happens here; lets us validate the
  cable + microcode path before committing to a PCB

**Phase 1B — full Q-bus integration** (build after 1A validates):
- Pico Q added on top of working Pico F
- Substitute card plugs into the /73's Q-bus
- Same FPS-cable-side firmware, new Q-bus-side firmware

This is **lower risk** — Phase 1A on a perfboard validates the
cable interface in days; Phase 1B then adds the Q-bus front-end
on a proper PCB once Phase 1A confirms everything works.

## Three design options compared

| Option | Phase 1A cost | Full Phase 1B cost | Pin headroom | Effort |
|---|---|---|---|---|
| Single Pico 2 + heavy expanders | $25 / $50 | $80 | tight, lots of glue | ~120h |
| **Dual Pico 2 tandem** | **$30 / $50** | **$80** | **tight, light glue** | **~110h** |
| Teensy 4.1 + expanders | $35 / $60 | $90 | comfortable | ~90h |
| RP2350B custom board | $50 / $100 | $150 | very comfortable | ~120h |
| Lattice ECP5 FPGA | $80 / $150 | $200+ | abundant | ~160h |

**Recommendation unchanged: dual Pico 2 tandem**, but now the
"host PC" in Phase 1A is just a dev workstation talking to Pico F
over USB-C, **and Phase 1B adds Pico Q for actual /73 Q-bus
integration**.

## Phase 1A — the parts list (build first)

| Part | Qty | Cost | Notes |
|---|---|---|---|
| Raspberry Pi Pico 2 (1 of the two for now) | 1 | $5 | Pico F |
| 74LVCH16245 16-bit level shifter | 3 | $9 | for FPS cable's 50 lines |
| 74HC165 shift-input | 1 | $0.50 | for IRQ-source + reset reads |
| 50-pin IDC ribbon + connectors | 1 | $10 | matches FPS chassis cable |
| Mating connector for `612-4448-401-F` | 1 | $5-15 | TBD per B1 bench task |
| Perfboard / breakout proto PCB | 1 | $5 | bring-up only |
| **Phase 1A subtotal** | | **~$35-45** | |

## Phase 1B — adds Q-bus front-end

| Part | Qty | Cost | Notes |
|---|---|---|---|
| Second Pico 2 | 1 | $5 | Pico Q |
| 74LVCH16245 (Q-bus side) | 3 | $9 | for BDAL + control |
| 74HC595 shift-output | 1 | $0.50 | for low-priority Q-bus signals |
| Q-bus edge-connector PCB | 1 | $20-30 | quad-height, OSHPark or JLCPCB |
| 5 V → 3.3 V buck regulator (e.g., MP1584) | 1 | $1 | from Q-bus 5 V |
| Decoupling caps, resistors, LEDs | bag | $5 | |
| **Phase 1B incremental** | | **~$40-55** | |

**Total Phase 1A + 1B: ~$90**.

## Validation step sequence

### Phase 1A (cable side only)

1. Power up Pico F + level shifters; USB enumerates on dev workstation.
2. Connect cable to chassis-side `612-4448-401-F`; chassis off.
3. Continuity test every line in the cable.
4. Power chassis on; observe SBC's panel-init sequence
   (`0x276..0x27D`) on the cable via Pico F's PIO sniffer.
5. Pico F mirrors the SBC's writes — confirms the chassis-side
   card is responding correctly to the cable.
6. Pico F issues a register read (e.g., read AP I/F status at
   offset `0x18`) — confirms cable-side decode + DTACK works.
7. Pico F issues a register write (e.g., panel command `0x26C`
   PCMD_RELEASE) — confirms write path + the SBC's `TCBRDHC`
   processes it.

### Phase 1B (add Q-bus integration)

1. Substitute card builds out on quad PCB; Pico Q + Pico F both
   populated; Q-bus edge connector wired.
2. Card inserted into /73 backplane in a free slot.
3. /73 boots, DCL/MCR running. Console: `MCR>SET /UIC=[1,1]` etc.
4. From /73, issue a register read at the substitute card's
   SYSGEN-configured I/O address (`0o176000` default for FPS).
   Confirm BRPLY + correct data.
5. From /73, issue a register write — confirm the FPS chassis
   reflects the change (visible via Pico F sniffer or via
   chassis SBC behaviour).
6. Trigger an interrupt on the FPS cable side; confirm the /73
   receives the corresponding Q-bus IRQ at the right vector.
7. End-to-end sanity: from /73, send a panel-command that
   selects an XP-32 channel; observe the chassis-side SBC's
   `TCBRDHC` task wake and dispatch.

## What this unblocks

Phase 1A alone is **enough to develop XP-32 microcode**:
- Modern-PC tool issues the SBC's command vocabulary via USB
- The substitute card forwards to the FPS-3000 chassis via cable
- XP-32 µkernels uploaded via the SBC's S-record path
- AU runs uploaded code; results read back via the same path

Phase 1B converts this from a development setup to a **real
PDP-11/73 ↔ FPS-3000 system** — same microcode runs unchanged,
now driven by an RSX-11M-flavoured driver on the /73 making
QIO/IO.WLB calls (analogous to the FPS-100 `DRIVER.MAC` we have
as ancestor reference). Writing that /73-side driver is a
separate ~50-hour software task, not blocked by the substitute
hardware.

## Next concrete actions

1. **Order Phase 1A parts** (Pico 2, level shifters, ribbon
   cable, shift register, perfboard) — **~$45, 1-week lead time**
2. **B1 bench task: identify chassis-side cable connector** on
   Lovett's `612-4448-401-F` — visual + DMM. **~2h.**
3. **Write Pico F PIO program** for register-poke timing on the
   FPS cable side. **~8h, can start before parts arrive.**
4. **Write dev-workstation Python tool** (USB CDC packet protocol
   mirroring the SBC command vocabulary). **~10h, can start now.**
5. After Phase 1A validates: **Phase 1B PCB design + fab** for
   the Q-bus integration. **~30h design + 1-2 weeks fab.**

Phase 1A is buildable on perfboard for first validation. Phase
1B requires a proper PCB because Q-bus electricals demand
controlled-impedance traces and the card must mechanically fit
the /73's quad slot.
