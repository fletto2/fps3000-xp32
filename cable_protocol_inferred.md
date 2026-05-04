# FPS-3000 host-cable protocol — inferred from available sources

The cable runs between the **host-side AP I/F card** (e.g.
`612-4012-003` Q-bus or `612-4013-001` UNIBUS) and the
**chassis-side AP I/F card** (`612-4448-401-F`). We can pin its
protocol down without LA captures by triangulating four sources:

1. **FPS-100 ancestor**: the `IOP-UNI` UNIBUS interface (Curington
   1983 IOP-16 paper confirms it as a 1-board UNIBUS interface
   "with cable"). The FPS-100's host-side driver source
   (`DRIVER.MAC` in `fps100_archive/`) shows how UNIBUS bus
   cycles reach the AP-120B's internal memory — by direct
   bus-master operation, with the IOP-UNI card just extending
   the UNIBUS through the cable.
2. **Same-chassis catalog**: `612-4012-003` (Q-bus), `612-4013-001`
   (UNIBUS), `612-4850-000` (LSI-11) all pair with the *same*
   chassis-side `612-4448-401-F`. So **the cable protocol is
   host-bus-agnostic** — each host-side card adapts its
   bus-specific signals to a common cable abstraction.
3. **SBC's view of the chassis-side AP I/F**: the firmware accesses
   a register file at VersaBUS `0xFF0000+`. We have the full
   accessed-register table from MC-derived disassembly.
4. **The XP-32 panel-command protocol** (in `xp32_eu_command_protocol.md`)
   tells us about the SBC↔XLTR side; the AP I/F sits in front of
   that on the host side and therefore must support equivalent
   primitives.

The triangulation rules out the "extend UNIBUS literally over
cable" model that the FPS-100 used. The FPS-3000 cable must be
**abstracted** because the same cable plugs into both the Q-bus
and UNIBUS host-side cards, and Q-bus signaling is electrically
incompatible with UNIBUS.

## What the cable must carry

Five signal classes, derivable from the operations the SBC
firmware performs:

### 1. Register-poke (host → chassis)

The host writes to AP I/F registers at offsets visible to it
(maps to chassis-side `0xFF0000+`). The cable conveys:
- **9-bit address** (selects one of 256 × 16-bit registers in the
  AP I/F register file, covering `0xFF0000..0xFF01FE`)
- **16-bit data** (write data going to the chassis-side card)
- **Write strobe** (~1 µs assertion timing per host-bus cycle)
- **Acknowledge / DTACK** (chassis side responds to confirm)

### 2. Register-read (chassis → host) — same as (1) but data flows the other direction

The chassis-side card drives the data lines back to the host on
read cycles. So the data lines are bidirectional with direction
controlled by the read/write line.

### 3. Bus-master DMA (chassis becomes bus master on host's bus)

This is the critical one. From `DRIVER.MAC RUNDMA`:

```mac
MOV     R0,LITES(R3)            ; high 2 bits of host phys addr
MOV     U.BUF+2(R5),HMA(R3)     ; low 16 bits
BIS     #HDMAGO,CTRL(R3)        ; ★ AP becomes bus master, fires DMA
```

The AP becomes bus master — meaning **the chassis-side AP I/F
card requests bus mastership of the HOST'S bus, through the
cable, then issues memory-read/write cycles to the host's RAM**.

For this the cable must carry:
- **Bus-request / bus-grant arbitration** (1-2 lines each direction)
- **Full host-physical address** — 18 bits for UNIBUS / 22 bits
  for Q-bus (the chassis-side card needs to drive the host's
  full address space)
- **Bus master signaling** — direction, master/slave swap

The host-side card uses these signals to actually drive the
host's bus. So the cable carries an abstracted master/slave
arbitration that the host-side card translates to its specific
bus's mastership protocol (UNIBUS NPR/NPG vs Q-bus DMR/DMG vs
LSI-11 etc.).

### 4. Interrupt propagation (chassis → host)

Three RSX event flags are sourced from chassis-side hardware
events:
- `DMAEVF=23` — DMA complete (CTRL.IHWC bit, after CTRL.HDMAST clears)
- `RUNEVF=22` — AP halted itself (CTRL.IHALT bit)
- `CB5EVF=24` — CTL5 programmed I/O word ready (CTRL.IHCB5 bit)

So the cable carries **at least 1 interrupt line** (probably 1
line + 3-bit identification of the irq source, or 3 separate
lines). The host-side card translates these into the host's
native interrupt-vector mechanism (UNIBUS BR4/5/6/7 + BG-grant
chain, Q-bus IRQ4-7, etc.).

### 5. Host → AP interrupt (CTRL bit 14 = APIRT)

The reverse direction. From `DAPEX.MAC SENDER`:

```mac
BIS     #APIRT,R3                ; raise CTRL bit 14
MOV     R3,CTRL(R2)              ; → AP receives interrupt
```

So the cable also carries **a single line, host → chassis**, that
asserts an "interrupt the AP" signal. This is just one bit, no
data, no acknowledgment beyond the AP eventually responding via
SWR.

### 6. Reset

Cold-start mechanism. `RSTAP/ABRT` register (offset `0o116`) is
the AP-side reset trigger. From the host's side, asserting it
likely flows through the cable as **one reset line** to the
chassis-side card. May or may not be a separate cable conductor
vs. multiplexed through the register-write path.

## Putting it together — cable conductor count

For full functional coverage:

| Signal class | Conductors |
|---|---|
| Address (host-bus-superset = 22 bit for Q-bus mastery) | 22 |
| Data (16-bit) | 16 |
| Read/Write + strobe + ack | 3-4 |
| Bus arbitration (request, grant, master, ack) | 4 |
| Interrupt host→AP | 1 |
| Interrupt AP→host (3 sources, encoded as 3 lines OR 1 line + 2-bit cause) | 3 |
| Reset (could be in-band) | 0-1 |
| **Logical signal lines total** | **~50** |
| Ground / power-return alternation | ~16-24 |
| Power for transceiver (5V supply if not on host-side) | 1-2 |
| **Conductor count total** | **~70-80** |

This is consistent with **a heavy ribbon cable or a 50-pin × 2
hex-cable bundle** — the format FPS used for `Co-Processor
Interconnect Cable` (P/N `422-0015-001`, $100 in 1984).

## Comparison to FPS-100 IOP-UNI cable

The FPS-100's cable was simpler — UNIBUS-only host, so the cable
literally extended UNIBUS:
- 18 address (UNIBUS A0-A17)
- 16 data
- ~10 control + arb + irq
- Ground / power
- Total: ~50 conductors, common UNIBUS bus extension format

The FPS-3000 cable is **bus-extension generalised** — the
abstraction layer adds a small amount of overhead (different
arbitration semantics, irq-cause encoding) but is structurally
the same kind of thing. The host-side card per bus-type does the
specific translation.

## Protocol timing (from SBC firmware behavior)

The SBC firmware uses a 1000-iteration timeout loop on most AP
I/F transactions (`#$3E8 = 1000` decimal — see `PanelSendAndWait`
at `F056BA`). At an 8 MHz 68000 with ~125 ns per instruction and
~5-10 instructions per loop iteration, that's roughly **5-10 ms
total wait per transaction**. So the cable + chassis-side
roundtrip can be slow (probably bus-master cycle ~750 ns, but
acknowledgments may be hand-shaken across multiple cycles).

The handshake bit FN[14] (SWR-data-valid) is checked in tight
loops that idle waiting for the AP to consume the previous SWR
write — so cable bandwidth on programmed I/O is **< 200 kword/s**.
DMA mode is much faster, Curington 1986 reports ~1.6 MW/s for
AP-120B DMA, similar order for FPS-3000.

## What's left undetermined by inference alone

Three things that **only LA captures (or finding the cable
itself + visual ribbon-cable conductor count) can pin down**:

1. **Exact pinout assignment** on the cable connector — which
   wire is "address bit 0" vs "data bit 0" etc. The functional
   signal set is determined; the physical mapping is not.
2. **Whether the cable uses single-ended or differential signaling**.
   For the cable lengths involved (typically 2-4 m chassis-to-host),
   single-ended TTL is plausible but differential (e.g. 26LS31/32)
   would be more reliable. FPS may have used either.
3. **Frame format on multiplexed lines** — if the cable saves
   pins by multiplexing address/data on the same wires (with a
   strobe to distinguish), the exact framing of bits across
   cycles. Most likely the design is *not* multiplexed (FPS
   used parallel ribbon cables in this era), but worth checking.

## Implications for building a substitute host-side board

Given the inference, a substitute host-side card needs to:

1. **Source/sink ~50 logical signal lines** matching the cable
   protocol. FPGA approach: tens of GPIO pins, all bidirectional
   with controlled directionality. Lattice ECP5, Cyclone IV, or
   Spartan-6 dev boards all suffice (plenty of I/O).
2. **Bus-master emulation on the host bus side** — for DMA mode.
   The board must request bus mastership of the host's Q-bus,
   drive addresses, and signal completion. This is where Q-bus
   transceiver chips (or modern equivalents like 74LVCH16245A)
   matter. Standard Q-bus dev kits (e.g., the recent open-source
   Q-bus interface boards from CHDickman et al.) provide good
   reference.
3. **Implement irq translation** in the FPGA — chassis-side irq
   lines come in, FPGA generates Q-bus IRQ4/5/6/7 with the right
   timing.
4. **Handle the simple host→AP irq** — one cable line, asserted
   on a register write to the right address.

## What to do without the cable

If Lovett never gets the original cable, **build it**. The
conductor count is ~50-80 depending on the design choice; flat
ribbon cable + IDC connectors is cheap. The connector pinout
*does* need LA captures (or visual examination of the
chassis-side card's connector pads) to pin down which physical
pin carries which logical signal. But the functional protocol is
already understood.

## Net take

**The cable protocol is structurally a bus-extender carrying
register pokes + bus-mastership + interrupts.** Number of
conductors ~50-80. Bandwidth ~200 KW/s programmed-I/O, ~1.6 MW/s
DMA. Designed to abstract over the host's specific bus
electricals (Q-bus / UNIBUS / LSI-11) so the same cable works
with multiple host-side cards.

This is enough to **start designing the substitute host-side
FPGA**. The remaining LA-capture work shifts from "figure out
what the protocol is" (already done by inference) to "pin down
the physical signal-to-pin mapping" — a much narrower question.
