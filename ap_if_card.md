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

## Reading the AP I/F's actual part number

Lovett's chassis has the AP I/F's full part number on the card
itself but the index-plate photo only shows the prefix `4` (the
last 2-3 digits are illegible due to glare). Reading the full
number from the card directly would tell us:
- The host-bus variant (UNIBUS vs Q-bus vs other)
- The card revision
- Whether it matches an FPS published part-number table

FPS engineering numbering is `612-NNNN-RRR` where:
- `NNNN` = card type + host-variant code
- `RRR` = revision

So a UNIBUS AP I/F might be `612-4456-461` (matching the partial
"4 4 5 6" pattern visible on the slot label) and a Q-bus variant
would be a different `NNNN`.

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
