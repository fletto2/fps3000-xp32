# Card parts inventory vs. the ROM findings — cross-check

The per-card parts survey (`card_parts_inventory.md`,
`card_versabus_interface.md`) is the first *physical* evidence this
project has had. Everything else here was derived from the ROM image, the
card list, and owner statements. This page checks one against the other.

**Read the survey's own caveat first.** It states it is "a *representative*
survey, not an exhaustive per-reference-designator BOM — 1–2 crops per
card were read". So an absence in it is weak evidence; a presence is
strong. The conflicts below are weighted accordingly.

---

## Confirmations

| Finding | Source | Physical evidence |
|---|---|---|
| 128 KB SBC RAM | ROM memory map | ~16 × **MSK4164AP-15** (64K×1) in two banks = 1 Mbit = **128 KB** ✓ |
| DRAM parity, BERR on failure | M68KVM02 manual; "Known divergences" in CLAUDE.md | **≥2 × MC74F280N** 9-bit parity generators — one per bank ✓ |
| Am29116 is the EU controller | Hockney; owner | **AM29116DCB** present on XP32 EXEC ✓ |
| AU WCS is writable SRAM | inferred from the S-record upload path | **AM2168-45PCB** (4K×4 SRAM) arrays on both EXEC and ARITH ✓ |
| EU microcode in fixed PROM | Hockney's "2K × 80-bit PROM" | **29F52 SDC** PROM banks on EXEC ✓ |
| XLTR is the bus-facing card | ROM drives `$FF0200-$FF025F` | **AM2927DCB** quad 3-state bus transceivers ×8+, **AM29823DC** bus registers ×4 — a dedicated backplane interface ✓ |

The parity generators are the nicest confirmation: CLAUDE.md's "Known
divergences" list warns that real DRAM powers up with invalid parity and
that `clr` on untouched memory is a BERR risk. Two F280s on the board is
what that warning predicts.

---

## Conflicts

### 1. The AP I/F shows no Am29705 — RESOLVED, survey coverage gap

CLAUDE.md states the AP I/F "carries eight **Am29705** 16-word × 4-bit
dual-port SRAMs = 32 bits wide, which is the basis for believing the
original host was a 32-bit machine such as a VAX".

The survey reads card 04 (AP I/F, `412-4448-401`) as **all Schottky TTL,
no LSI**, listing only `74S175/S02/S74/S51/S20/S00/S04/S169A/S10/S64/
S153/S374/S30`, `74LS377`, `74LS240`, `74LS00`, plus several unpopulated
**SPARE** positions. No Am29705 appears.

**RESOLVED in favour of the parts being present.** The Am29705 claim did
not come from the photographs at all — it comes from the machine's owner
describing the board in front of them, reporting eight of them along the
right-hand side of the AP I/F. The survey read one or two crops per card
and evidently did not cover that region; its own caveat anticipates
exactly this. Direct observation beats a partial crop, so the parts are
there and the survey's silence is a coverage gap.

Two things worth separating out now that the provenance is clear.

**The part identification checks out.** AMD's Am2900 databook describes
the Am29704/Am29705 as "16-word by 4-bit, two-port RAM's", the Am29705
being the three-state version. Eight of them give a **16-word × 32-bit
two-port RAM** — a textbook inter-processor mailbox. Its canonical
application in the databook is register-file expansion for Am2903
bit-slice systems, but a two-port RAM is a two-port RAM.

**The VAX is explicitly a guess, and should be recorded as one.** The
owner's own words make the 32-bit inference and the VAX identification
two separate claims: eight 4-bit-wide dual-port RAMs really do give a
32-bit path, but which 32-bit machine sat on the other end is
acknowledged guesswork, with a DG Eagle or any other mid-80s 32-bit mini
equally possible. CLAUDE.md carries "such as a VAX" without that hedge.

### And it converges with the ROM finding

The owner reads the array as holding very little at a time — on the order
of one word outbound to the host and one word inbound from it.

That is **exactly the shape the firmware shows**. The host↔SBC payload
does not move through the AP I/F channel data ports; it rides in the
**mailbox pair at `$70001C` (host→SBC) and `$700020` (SBC→host)** — one
word each way — as established in `versabus_access_map.md`. Two
independent routes, one from reading the board and one from reading the
firmware, arrive at a one-word-each-way mailbox.

The reasonable synthesis is that the Am29705 array **is** the physical
implementation of that mailbox pair. Not proven — nothing here traces
`$70001C` to those chips — but the width, the port count, the direction
split and the depth all agree, and no other candidate on the card does.

### 2. No MC68153 found anywhere, but the ROM drives three BIMs

The card list names the XLTR "**V-BUS XLTR 3 BIMS**", the ROM programs
three four-channel interrupt blocks at `$FF0230`/`$FF0240`/`$FF0250`, and
the register layout matches the MC68153 datasheet exactly (CR0-3 at
+0/+2/+4/+6, VR0-3 at +8/+A/+C/+E). The BIM model is one of the
better-evidenced parts of this project.

`card_versabus_interface.md` says of the SBC: "Expected but not located:
MC68153 Bus Interrupter". The XLTR listing has only AM2927 transceivers
and AM29823 registers.

Three readings, in rough order of likelihood:

1. **Survey coverage.** Three DIP-24 parts on a card read from one or two
   crops is exactly what a representative pass misses.
2. **The function is discrete.** "3 BIMS" could name a function built
   from the TTL on the card rather than three MC68153 packages. The ROM
   cannot tell the difference — it only sees the register layout.
3. **Different package/marking.** A second-source or custom-marked part.

The ROM evidence for *three four-channel interrupt blocks with MC68153
register semantics* stands either way; what is open is which packages
implement them.

### 3. XP32 EXEC: survey reads one Am29116, the owner says two

CLAUDE.md records, from the machine's owner (2026-07-29): "There are
**TWO** of these on the one EXEC card". The survey lists
`AM29116DCB … Qty 1`.

This matters because CLAUDE.md hangs an open question on the pair —
whether the 80-bit EU word carries two 16-bit instruction fields, or one
plus a cascade link — and that question only exists if there are two.

The owner has the physical board and the survey admits partial coverage,
so the owner's count should be preferred; but the discrepancy is worth
resolving before any EU-PROM dump is interpreted, since it decides
whether a dump holds one instruction stream or two.

### 4. SBC clock: `MC68000L10` with 32 MHz and 20 MHz crystals

CLAUDE.md and the emulator both assume **8 MHz**. The part is an
**MC68000L10** (10 MHz rated) and the board carries **32.000 MHz** and
**20.000 MHz** crystals. 20 MHz ÷ 2 = 10 MHz is the obvious CPU clock;
32 MHz ÷ 4 = 8 MHz is also available.

Nothing in this project depends on absolute timing — the emulator counts
cycles, and no result here is wall-clock sensitive — with **one
exception**: the DRAM retention delay in phase `$2500`ish loads
`d5 = $493E0` (300,000 iterations), and how long that represents depends
on the clock. At 8 MHz it is ~0.4 s; at 10 MHz, ~0.3 s.

---

## New identifications the ROM work did not have

### `AM29540DC` on XP32 ARITH — an FFT address generator

The survey identifies an **AM29540** (ceramic, gold lid) on the ARITH
card. That part is AMD's **FFT address sequencer** — it generates the
butterfly addressing patterns for radix-2/4 FFTs in hardware.

This is direct physical support for the FFT-engine reading of the XP-32
that until now rested entirely on the software side: XPMLIB's `ZRFFT`,
the AP-120B FFT microcode recovered earlier, and the Curington papers'
emphasis on signal processing. A dedicated FFT address generator is not
general-purpose hardware — it is put on a board because FFTs are the
workload.

It also sharpens what the AU microcode has to encode — and following it
into AMD's own handbook turned out to identify the whole card. The ARITH
board matches AMD's published radix-2 FFT reference architecture part for
part, including the split between data-address and coefficient-address
pipeline registers, which also identifies the previously unexplained
`L29C520PC-R` as Logic Devices' Am29520. Written up in
`notes/xp32_arith_is_amd_reference_fft.md`, with the consequences for the
128-bit microword — the most useful of which is that AMD **overlays** the
Am29540 and Am29116 microcode bits, since the two are never active at
once.

### MAIN DATA is 256K×1 DRAM

**MSM4256P-15** (OKI, 256K×1) in a full-board array. The card list calls
it "MAIN DATA 1 MEG 32 BIT TERM". 32 × 256K×1 = 256K words × 32 bits =
**1 MB = 256 Kword**.

CLAUDE.md describes the memory cards as "~1 megaword each". That reads
the "1 MEG" in the part description as megawords; the part count says
megabytes. One populated card is **256 Kwords of 32-bit data**, and the
four-card full configuration would be 1 Mword / 4 MB.

### Two EPROM pairs on the SBC

The survey lists `51AW1940X14 U80` and `51AW4039B02 U81`, **both labelled
"VM02 1.0"** — Motorola's own VM02 firmware — *and* separately "AMD EPROM
(© 1983 AMD, ceramic window) ×2".

Our ROM image is `FPS3K_U11_U12_JOIN.bin`, i.e. from sockets **U11/U12**.
So the SBC appears to carry **two** firmware pairs: Motorola's VM02
monitor at U80/U81 and the FPS firmware at U11/U12. That is consistent
with what the image contains — a stock RMS68K kernel (bytes identical to
Motorola's, ending at `$F04487`) followed by FPS application code.

If the U80/U81 VM02 firmware is a stock Motorola product, its contents
may be documented or dumped elsewhere, which would give an independent
reference for the RMS68K portion. The survey flags the same route.

---

## What to do with this

Ordered by how much they would change:

1. **Resolve the Am29705 question** (conflict 1). It underpins the
   32-bit-host/VAX inference in CLAUDE.md. A single native-resolution
   crop of the AP I/F card would settle it.
2. **Confirm the Am29116 count** (conflict 3). Decides whether an EU PROM
   dump is one instruction stream or two.
3. **Locate the BIMs** (conflict 2). The ROM model does not depend on it,
   but a bring-up attempt would.
4. **Check the CPU clock strap** (conflict 4). Only affects the delay-loop
   timing interpretation.
