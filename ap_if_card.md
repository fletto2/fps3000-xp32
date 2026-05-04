# The AP I/F card — host-to-FPS-3000 bridge

Everything we've established about the **Application Processor
Interface** card (slot 11 in the chassis), consolidated from the SBC
ROM disassembly + FPS published references + chassis photos +
analysis of the FPS-100 ancestor's host-side driver.

## What it is

A **dual-ported VersaBUS card** that bridges between:
- **Host computer's native bus** (UNIBUS / Q-bus / VAX BI / IBM
  mainframe channel — host-bus-specific) on one side
- **VersaBUS** (the FPS-3000 chassis backplane, MC68000-style 16-bit)
  on the other

The card carries dual-ported register file + DMA engine +
bidirectional interrupt logic. From either bus, it looks like a
local I/O device.

Position in the chassis (per Lovett's index-plate photo,
`refs/FPS-3000/fps-3000.jpg`):

| Slot | Card | Part-prefix |
|---:|---|---|
| 14 | VBUS SBC | 80B |
| 13 | VBUS XLTR | 803 |
| 12 | FMT (Univ. Format) | 804 |
| **11** | **AP I/F** | **4xx** *(host variant; full digits not legible in photo)* |
| 10/9 | XP-32 EXEC + ARITH (AC1) | 805/806 |
| 8/7 | XP-32 EXEC + ARITH (AC2) | 805/806 |
| 6 | MEM CTL | — |
| 5–1 | MEMORY ×5 | 498/456 |

## Physical connection to the host

```
   ┌──────── HOST CHASSIS ────────┐         ┌───── FPS-3000 ─────┐
   │                              │         │   chassis          │
   │  ┌────────────────────────┐  │         │   ┌─────────────┐  │
   │  │ Host-bus side of AP I/F│◄─┼─cable──►│◄──┤ VersaBUS    │  │
   │  │ (lives in host's       │  │         │   │ side of     │  │
   │  │  backplane, fits one   │  │         │   │ AP I/F      │  │
   │  │  host slot)            │  │         │   │ (slot 11)   │  │
   │  └────────────────────────┘  │         │   └─────────────┘  │
   │                              │         │                    │
   └──────────────────────────────┘         └────────────────────┘
```

The AP I/F is **physically two pieces of hardware** connected by a
cable:

1. **Host-side card** — plugs into a slot in the host's bus
   (UNIBUS hex slot for PDP-11/44, etc.). Has the host-side
   transceivers and the cable connector.
2. **Cable** — multi-conductor twisted-pair (typically 40-pin flat
   for UNIBUS / 50-pin for Q-bus / heavier bus-and-tag for IBM
   channel). Length-limited per the host bus's spec
   (e.g., 50 ft max for UNIBUS; less for Q-bus).
3. **VersaBUS-side card** — sits in slot 11 of the FPS-3000
   chassis, presents the SBC with the dual-ported register file at
   VersaBUS address `0xFF0000+`.

Both pieces are functionally one logical card; they share state via
the cable. Some FPS implementations integrate them differently
(e.g., the IBM channel adapter is much fatter than UNIBUS because
of channel-protocol complexity), but the role is the same.

> **Note**: none of the chassis photos in `refs/FPS-3000/` show the
> rear panel where the cable would attach to Lovett's specific unit.
> The general arrangement above is documented in Hockney p.241 and
> the FPS-5000 brochure (1984).

## The card is host-bus-specific (different P/N per host)

Confirmed by Hockney & Jesshope §2.5 + FPS-5000 brochure (1984)
which lists support for **PDP-11 (UNIBUS), VAX (UNIBUS or BI-bus),
IBM 4300/3033/308x channel**. Each is a different physical AP I/F
variant — different host-side transceivers, different cable, different
part number — but **all share the same VersaBUS-side register
layout and protocol**.

So from an engineering perspective:

| Host | AP I/F variant | What FPS shipped |
|---|---|---|
| PDP-11/40, /44, /70, /84 | UNIBUS AP I/F | Standard option |
| PDP-11/23, /73, /83 | Q-bus AP I/F | (existence inferred from family practice; we have no doc) |
| VAX 11/750, 11/780 | UNIBUS or VAX BI | Standard option |
| IBM 4300, 3033, 308x | Channel adapter | Standard option |
| CDC Cyber | PPU adapter | (FPS-100 era; FPS-3000 era unclear) |

The **VersaBUS-facing side stays identical across all variants** —
which is why the SBC firmware (this ROM) is host-bus-agnostic. The
SBC sees the same `0xFF0000+` register layout regardless of which
host is on the other end of the cable.

The host-side software (driver + APEX runtime) **does** vary per
host, because each host's OS has its own device-driver framework
and its own bus-poking conventions. We have full source for the
**FPS-100 era** RSX-11M driver (`DRIVER.MAC`, see
`host_to_fps100_protocol.md`), but the **FPS-5000-era successor
driver is not in our archive** — Curington 1984 calls it a "software
migration path", explicitly *not* byte-compatible with FPS-100.

## Functional layout (both sides see the same)

The AP I/F's register file is mapped into both buses. From the SBC
ROM's accesses we know the **VersaBUS-side address is `0xFF0000+`**,
with these registers used:

| Offset | SBC use observed | Likely host-side role |
|---:|---|---|
| `0x00` | command/status word; SBC writes `0x8004`/`0x8005` triggers, reads bits 13-14 for done/error | host writes commands; polls done/error |
| `0x0E` | per-channel command-arg register | host writes channel arg |
| `0x14` | data low | bidirectional 16-bit data |
| `0x16` | command code (`0x258..0x27D` panel codes) | host writes panel cmd code |
| `0x18` | trigger / status | host arms transactions |
| `0x1A` | IRQ mask | host configures interrupts |
| `0x48/0x4E` | per-AC1 data A/B | per-channel I/O |
| `0x68/0x6E` | per-AC2 data A/B | |
| `0x88/0x8E` | per-AC3 data A/B (slot empty in 2-AC config) | |
| `0xA8/0xAE` | per-AC4 data A/B (slot empty in 2-AC config) | |
| `0x244/0x246` | AC1/AC2 config | |
| `0x250/0x252` | AC3/AC4 config | |

**The host pokes its side at a SYSGEN-configurable host-bus address**
(typical for FPS gear: UNIBUS `0o176000` for the historical
default). The AP I/F card's host-bus dispatch maps host-side reads
and writes onto the same internal register file, so the SBC sees
the host's pokes immediately.

The XLTR's separate registers at `0xFF0200+` are **not visible to
the host** — those are the SBC's private control plane for the
XP-32 cards, behind a different translator card (slot 13).

## Three channels of bidirectional traffic

Each channel uses different register pokes + interrupt patterns.
The chassis front panel (`refs/FPS-3000/fps-3000-fp.jpg`) confirms
all three with dedicated indicator LEDs:

| Front-panel LED | Channel | What it indicates |
|---|---|---|
| **direct memory transfer** | DMA | Bulk data via VersaBUS DMA in progress |
| **host interrupt enabled** | CTL5 / APIRT | Programmed-I/O channel armed |
| **AP busy** | RUN | Some AC is running microcode |
| coprocessor 1 busy | AC1-specific | XP-32 #1 currently executing |
| coprocessor 2 busy | AC2-specific | XP-32 #2 currently executing |

Two distinct "busy" lights confirms the **2-AC chassis configuration**
that the slot-map photo also shows.

The detailed protocol for each channel is documented in
`host_to_fps100_full_protocol.md` (FPS-100 generation, fully
documented from MACRO-11 source) and `host_to_sbc_communication.md`
(FPS-3000-side observations from the SBC ROM).

## The SBC's tasks that handle host traffic

In the SBC ROM (this firmware), two RMS68K tasks split host duties:

| Task | Address | Role |
|---|---|---|
| `TCBRDHC` | `F046F0–F051A2` | Master/dispatch task. Wakes on AP I/F interrupts, decodes incoming host commands, dispatches to subordinate tasks. Owns the S-record parser for microcode upload. |
| `TCBIO1I` | `F05D00–F05F00` | Host I/O channel task (ASQ name `HIO1`). Implements the **EXPUT** and **EXGET** primitives (host RAM ↔ FPS-3000 SCM bulk transfer). Uses RMS68K TRAP #1 syscalls heavily. |

The **handoff from interrupt to task** is via RMS68K's ASQ
(Application Status Queue) marker `!ASQ`. When the AP I/F raises a
VersaBUS interrupt, the SBC's interrupt vector lands in a small
trampoline that pushes a message onto `TCBRDHC`'s ASQ; `TCBRDHC`
wakes, reads the AP I/F register set, and dispatches.

## What changes vs. what stays the same per host

```
                         HOST              FPS-3000 (constant across hosts)
                         ────              ─────────────────────────────
                         driver software   SBC ROM (this firmware)
                         host-bus regs     VersaBUS regs (0xFF0000+)
                         host's bus        VersaBUS
                         host-side card    AP I/F VersaBUS-side card
                         cable             (passes through)
                         ▲ varies          ▼ same
```

So if you swap from PDP-11/44 to PDP-11/73 to VAX:
- **Host computer** changes
- **Host-side AP I/F card** changes (different P/N per bus)
- **Cable** may change (UNIBUS cable ≠ Q-bus cable)
- **Host driver software** changes (different OS, different bus
  conventions)
- **Everything inside the FPS-3000 chassis stays the same**, including
  the VersaBUS-side AP I/F card. The SBC ROM is unaware of the
  host-bus type.

## PDP-11/73-specific options

The PDP-11/73 is a Q-bus machine; the FPS-100 was UNIBUS-only; the
FPS-3000-era Q-bus AP I/F variant (if it existed) we have no
documentation for. So in practice:

1. **Keep an existing UNIBUS AP I/F card** in the FPS-3000 (slot 11)
   and put a **Q-bus↔UNIBUS bridge** between the /73 and the AP I/F
   card. Examples: DEC `BCV1B` UNIBUS adapter, Able `Q-Map`. The
   host driver continues using UNIBUS-style register pokes; the
   bridge translates physically.

2. **Find/build a Q-bus AP I/F variant.** If FPS made one, look
   for FPS part number `612-44xx-yyy` with Q-bus connectors. If
   not, custom-build a Q-bus interface card that presents the same
   VersaBUS register set behind a Q-bus front-end.

3. **Use a different host model** entirely. Lovett's actual machine
   is PDP-11/44 (UNIBUS) per the Hackaday article; the /73 was
   not the original Bomem host either.

For most retrocomputing purposes, **option 1** is the path of least
resistance — UNIBUS↔Q-bus bridges were common 1980s commercial
products and several survive in working order.

## The AP I/F card's exact part number

**Confirmed (2026-05): the AP I/F card in Lovett's chassis is
`612-4448-401`, revision F.**

Reading: FPS engineering numbering is `612-NNNN-VVV` followed by
a revision letter:
- `612` — VersaBUS-family card series prefix
- `4448` — card-type code (this is "AP I/F")
- `401` — variant code (host-bus type or feature option)
- `F` — revision letter (sixth revision; A is first)

### What we can deduce from neighbours in Lovett's chassis

| Slot | Function | P/N (full or partial) |
|---:|---|---|
| 14 | VBUS SBC | (slot label "80B" → ~612-44**80**B-... or 612-44xx, suffix B not yet read) |
| 13 | VBUS XLTR | (slot label "803" → 612-44**80**3-401 or similar) |
| 12 | FMT | (slot label "804" → 612-44**80**4-401 or similar) |
| **11** | **AP I/F** | **`612-4448-401-F`** ← this confirmed |
| 10 | XP-32 EXEC #1 | `612-4805-002` (visible in Nakazoto photos) |
| 9  | XP-32 ARITH #1 | `612-4806-002` (visible in Nakazoto photos) |
| 8  | XP-32 EXEC #2 | `612-4805-002` |
| 7  | XP-32 ARITH #2 | `612-4806-002` |
| 6  | MEM CTL | (not yet read) |
| 5  | MEMORY | `612-4498-401-A` (per index-plate photo) |
| 4  | MEMORY | `612-4456-461` (per cardcage-photo label) |
| 3-1 | MEMORY ×3 | (presumably same as 4 or 5) |

So the FPS-3000 VersaBUS card-type codes cluster like this:
- `4408..449x` — system memory cards
- `4428` — likely FMT (middle of cardcage-photo PN)
- `4448` — AP I/F (confirmed)
- `4805/4806` — XP-32 EXEC/ARITH

The "44xx" codes are SBC-family / system cards; "48xx" codes are
XP-32-family cards. AP I/F at `4448` slots cleanly into the
SBC-family numbering.

### What `612-4448-401` tells us about the host-bus variant

**Nothing definitive** without an FPS catalog. The `-401` variant
suffix likely encodes the host-bus type (UNIBUS vs Q-bus vs VAX
BI vs IBM channel), but we don't have a P/N→variant mapping. Best
inference: since FPS's most-shipped FPS-3000 host pairing was
**PDP-11 UNIBUS** (per Hockney), the `-401` suffix on a card
shipped with what appears to be a stock 833-2003-004 chassis is
**most likely the UNIBUS variant**. Hypothesis only — needs
catalog confirmation.

If FPS used `-401`/`-402`/`-403` for sequential host-bus options
(plausible naming pattern), the variants might be:
- `-401` — UNIBUS (best guess)
- `-402` — Q-bus
- `-403` — VAX BI
- `-404` — IBM channel

But this is pure speculation. The actual mapping requires either
a surviving FPS catalog page, or an FPS engineer / customer who
remembers.

### Catalog confirmation (FPS Board Revision List, Dec 1989)

`refs/FPS_Board_Revision_List_198912.pdf` (12 MB, 26 pages) was on
bitsavers all along — pulling it apart reveals the *complete*
`612-4448-xxx` family:

| P/N | CR REV | Description (verbatim) |
|---|---|---|
| `612-4448-000..005` | various | "MULTI WIRE B" (deprecated; "USE -003 1-WAY" etc.) |
| `612-4448-011` | 02 | **448 APIF RDCP** |
| `612-4448-012` | 03 | **448 APIF FPS100** |
| `612-4448-013` | 06 | **448 APIF AP120B** |
| `612-4448-014` | B | 448 APIF FPS100 (newer rev) |
| `612-4448-015` | A | 448 APIF AP120 |
| `612-4448-017` | E | 448 APIF RDCP120 |
| `612-4448-301` | K | UNIV APIF |
| `612-4448-303` | T | UNIV APIF |
| `612-4448-304` | M | **UNIV APIF FPS5100** |
| `612-4448-305..307` | various | UNIV APIF (various) |
| `612-4448-400` | 12 | UNIV APIF |
| **`612-4448-401`** | **F** | **APIF** ← Lovett's exact card |
| `612-4448-402` | B | AP I/F **MP32** |
| `612-4448-403` | A | AP I/F **MP32** |

So the family splits chronologically:
- **`-011`..`-017`**: per-host-AP variants (each labeled with the
  AP it talks to — RDCP / FPS100 / AP120B / AP120 / RDCP120)
- **`-301`..`-307`**: "UNIV APIF" (universal — newer generation)
- **`-401`..`-403`**: just "APIF" / "AP I/F MP32" (newest; "MP32"
  is FPS internal shorthand — almost certainly **Multi-Processor
  32-bit** = the FPS-3000/5000 multi-XP-32 family)

Lovett's `-401-F` is the **base APIF** (no host-AP-name suffix
in the description), which is the chassis-side card for the
multi-XP-32 family. The matching host-side card is **NOT** in the
`612-4448-` family — it's a separate part number.

### The matching HOST-SIDE card — found

Same catalog, lines 159-163:

```
1   612-4013-000    10  10  10   000     UNIBUS ADAPTOR 3000/5000
2   612-4013-001    D   D   D    001     UNIBUS ADPTR FPS3000/5000   ← UNIBUS
2   612-4013-002    03  03  03   001     UNIBUS ADAPTER
1   612-4013-003    02  02  02   002     UNIBUS ADAPTER
2   612-4014-000    A   A   A    000     UNIBUS TERMINATOR 5000
```

```
3   612-4012-000    08  08  08   000     Q22 BUS ADAPTOR 300/5000
1   612-4012-001    A   06  06   001     Q22 BUS ADAPTOR 3000/5000
1   612-4012-002    01  01  01   001     Q22 BUS ADAPTOR FPS3000/5000
* 1 612-4012-003    04  04  04   002     Q22 BUS ADPTR FPS3000/5000  ← Q-bus (current)
```

Plus an alternate at line 1643:
```
3   612-4850-000    B   B   B    000     850 LSI-11 ADAPTOR HEX FPS3000
```

So the matching host-side cards for Lovett's `612-4448-401-F`
chassis-side AP I/F are, **definitively, by host bus**:

| Host bus | Host-side card | Description |
|---|---|---|
| **UNIBUS** (PDP-11/44, /70, /84; VAX 11/780) | **`612-4013-001` rev D** | UNIBUS ADPTR FPS3000/5000 |
| **Q-bus** (PDP-11/23, **/73**, /83) | **`612-4012-003` rev 04** | Q22 BUS ADPTR FPS3000/5000 |
| **LSI-11** (alternative Q-bus form factor) | **`612-4850-000` rev B** | 850 LSI-11 ADAPTOR HEX FPS3000 |

UNIBUS systems also need `612-4014-000` UNIBUS TERMINATOR 5000 as
a companion termination card (typical for high-speed bus
extensions over cable).

**For Lovett's PDP-11/73 specifically**: the part to find is
**`612-4012-003`** — Q22 BUS ADPTR FPS3000/5000, revision 04.
This was a current-revision FPS catalog item as of Dec 1989 (the
"*" mark indicates active inventory). It's the matching pair for
his `612-4448-401-F`.

### The cable

From the FPS pricing list (Mar 1984,
`refs/FPS_Pricing_198403.pdf`):

```
422-0015-001  Co-Processor Interconnect Cable  $100
```

Single P/N — likely the only flavour, but only listed in the
1984 (FPS-100-era) pricing; the FPS-3000-era cable may be a
different P/N we haven't identified.

### Pricing context (1984 dollars)

The 1984 pricing list is for the FPS-100/AP-120B-era 38-bit
parts; FPS-3000-specific cards aren't in it. But the 1984
prices for analogous earlier-generation host adapters are
informative on order-of-magnitude:

```
612-0106-000  Q Bus Adapter             $3,504  (38-bit Q-bus adapter)
612-4226-024  Formatter, VAX PDP        $3,614
612-4227-035  Formatter, PDP            $3,344
612-4239-004  Adaptor, HARRIS           $6,814
```

So a host-side adapter card in 1984 was a **$3-7K** part.
Adjusted to 2026 dollars, that's roughly $9-21K — explains why
these don't surface often in surplus channels.

## ⚠ Lovett's hardware status — host-side card is missing

**As of 2026-05, Lovett has only the chassis-side hardware** —
the FPS-3000 chassis with VersaBUS-side AP I/F card in slot 11
is present, but the **host-side AP I/F card is not in his
inventory**. This is a significant constraint: without the
host-side card (and its cable), the chassis cannot communicate
with any host computer at all, regardless of host model. The SBC
boots and runs its self-tests, but every command path that ends
at `0xFF0000+` register reads will see no host-side activity.

This means:
- No CPLOAD / CPRUN can be issued from a host
- No microcode can be uploaded to the XP-32 banks via the normal
  S-record path (which ingests S-records from the host through
  the AP I/F)
- The XP-32 cards' AU WCS will stay empty, so the XP-32s can't
  do useful FP work even though their EU PROMs run at power-on

### Three realistic paths forward

**(1) Find an original host-side AP I/F card.** The only sure-fire
way to get an end-to-end working FPS-3000 in the original
configuration. Used parts from this era surface periodically in:
- VCFed.org forums (Lovett's existing thread is the natural place)
- eBay vintage-computing listings (the broader sweep we did showed
  no FPS Inc. host-interface cards currently listed, but they do
  appear sporadically)
- University equipment surplus from sites that ran FPS-3000s in
  the 80s
- Estate sales / liquidations of former FPS engineers
The most likely variant to surface is **UNIBUS** (most-shipped) —
not Q-bus.

**(2) Build a substitute host-side interface** with modern hardware
(FPGA / microcontroller) that:
- Speaks the **cable protocol** between host-side and chassis-side
  AP I/F cards on one side
- Speaks something **modern** (USB, Ethernet, SPI to a Pi) on the
  other side

This is more achievable than it sounds *if* the cable protocol
turns out to be a simple register-bus extender (16 data lines +
address/control + ground), which is the typical late-1970s pattern
for cards split across two chassis. Reverse-engineering the cable
protocol requires:
- Tracing connector pinout on the chassis-side card with a
  multimeter and the schematics (visible chip-level on the card)
- Logic-analyzer captures during SBC boot (the SBC pokes the
  register file even with no host attached, e.g., during init
  and when reading the IRQ-mask register at startup)
- Cross-reference against the FPS-100's known UNIBUS interface
  (the FPS-3000 AP I/F evolved from it; field assignments likely
  preserved even if widened)

A simpler version of this approach: build a UNIBUS-master FPGA
board that *acts as* a UNIBUS PDP-11 host, drives the cable to
the chassis-side AP I/F card from the UNIBUS side. Then run
UNIBUS-style register pokes from a modern host through it.
This works if the host-side card is just a bus-extender (most
likely case for UNIBUS variant).

**(3) Bypass the AP I/F entirely** and drive the SBC's VersaBUS
directly via slot 14 or via SBC RAM via on-chassis injection.
This is the most invasive option but doesn't need any
host-side card at all. Concretely:
- Plug a custom VersaBUS card into a free slot, present it to the
  SBC as a substitute "host I/O" device
- Modify the SBC ROM (or attach a different boot ROM) to read
  microcode from the substitute device instead of the AP I/F
- Or even more invasive: replace the SBC entirely with a modern
  68K-emulator board that speaks VersaBUS but has its own
  Ethernet for host connection

Option 3 is the "make it work without any FPS host hardware"
approach — useful if the goal is just to drive the XP-32s
through their paces, less useful if the goal is to recreate
the original Bomem DA3 + FPS-100 + PDP-11 user experience.

### What's still useful even without a host

Even with no host attached, Lovett can:

- **Verify the SBC boots** — the ROM runs through its self-tests
  (PTM init, RAM checksum, ROM checksum, hardware probe — see
  `architecture.md` for the full init sequence) and will report
  pass/fail via the front-panel LEDs. This validates the SBC
  card, the VersaBUS backplane, and basic chassis power.
- **Probe the XP-32 EU PROMs** with a logic analyzer — the EU's
  Am29116 sequencer fetches its first instruction from PROM at
  power-on. Watching the EU's clock + address bus would reveal
  the PROM contents instruction-by-instruction. (And/or the PROM
  chips can be read out of-circuit with a vintage PROM
  programmer.)
- **Verify the XLTR responds** to SBC pokes — an in-circuit
  probe at `0xFF0200+` while the SBC runs its panel-init sequence
  (issuing `0x276..0x27D` boot codes) would show the XLTR's
  acknowledgement pattern, validating that side of the chassis
  is alive.
- **Read the AP I/F card's part number** off the chassis-side
  card directly. This identifies the host-bus variant FPS
  shipped, and tells future searchers exactly which P/N to look
  for in (1) above.

This isn't "running real software", but it's enough to validate
that 80% of the chassis is healthy and to characterize what's
needed for path (1) or (2).

## Cross-references to other docs

- `host_to_fps100_protocol.md` — FPS-100-generation protocol
  (UNIBUS only; complete from MACRO-11 source)
- `host_to_fps100_full_protocol.md` — full 3-tier analysis with
  APEX runtime + driver + libraries
- `host_to_sbc_communication.md` — FPS-3000-side observations
  (what the SBC sees of the AP I/F)
- `xltr_protocol.md` — the *other* translator (VersaBUS↔XP32-BUS)
  in slot 13, separate from AP I/F
- `architecture.md` §1, §2 — chassis-level system architecture
