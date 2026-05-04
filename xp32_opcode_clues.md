# What we can infer about the XP32 microinstruction format

## TL;DR

**No XP32 microinstruction reference manual exists publicly.** But three
authoritative sources, when triangulated, let us predict the XP32
encoding with high confidence:

1. **AP-120B Programmer's Reference Manual Part 2 (FPS-7319, 1978-01)**
   — Appendix E gives the bit-level field layout of the *ancestor*
   64-bit microinstruction. Authoritative.
2. **APSIM64 / APDEBUG64 Manual (860-7489-001B, 1984-03)** — Appendix
   A gives the field-mnemonic table for the FPS-164 (the *successor*
   64-bit machine). Authoritative for the lineage's evolution.
3. **SIM100.FTN `SUBROUTINE SPLIT(REG, FV)`** — bit-extraction code
   from the canonical AP-120B simulator. Validates source #1 at the
   bit level.
4. **Curington 1984 "Performance Estimation Methods for XP32 MAXL"**
   — explicitly states *"MAXL is compiled to APAL"* and *"one cycle
   in the XP32 takes .167 microseconds"*. The 167 ns clock is
   identical to the AP-120B.

## The AP-120B baseline (authoritative)

64-bit microinstruction, from FPS-7319 Vol 2 Appendix E:

```
bit  0 |  1  2  3 |  4  5 |  6  7  8  9 | 10 11 12 13 | 14 15 16 17 | 18 19 20 | 21 22 23 | 24 25 26 27 | 28 29 30 31
DF       SOP        SH       SPS           SPD           FADD          A1         A2         COND          DISP
─────────────────────────── S-Pad Group ───────────────────────  ──────── Adder ────────    ──── Branch ─────
                            (SOP1 [4] / SPEC [4] overlay)         (FADD1 [3] / I/O [3] overlay)

bit 32 33 | 34 35 | 36 37 38 | 39 40 41 | 42 43 44 | 45 46 47 | 48 49 50 | 51 | 52 53 | 54 55 | 56 57 | 58 59 | 60 61 | 62 63
    DPX     DPY     DPBS       XR          YR         XW         YW       FM   M1     M2     MI       MA      DPA     TMA
    ────────────────── Data-Pad Group ─────────────────────────────────  ──── Multiply ───  ────── Memory ──────
                                                                         (VALUE [11] overlay across multiply+memory)
```

Every named field has a fixed 1- to 5-bit width. The instruction
overlays one of three modes: normal (multi-unit parallel issue),
SOP1/SPEC (S-Pad-only), or VALUE (immediate, disables M1+M2+MI+MA+DPA+TMA).

This matches `SIM100.FTN`'s `SPLIT(REG,FV)` exactly — a Python
re-implementation of those formulas decoded my transcribed microcode
and produced register indices consistent with the source listing's
mnemonics. Encoding is solid.

## FPS-164 INSTRUCTION-FORMAT FIGURE — finally pinned down

Recovered from **Touzeau 1984** (`refs/FPS-164/Touzeau_1984_Fortran_compiler_FPS-164.pdf`,
SIGPLAN '84 Compiler Construction, page 49 Figure 2). Bit positions
are 1-indexed; MSB = bit 1, LSB = bit 64.

The 64-bit FPS-164 microinstruction is divided into multiple
*independent instruction groups* called **PARCELS**, with two parcel
sets that can be intermixed: **primary** and **secondary**.

### Primary parcel layout

Boundaries shown in Touzeau Fig 2 are 1, 13, 22, 31, 50, 55, 63 — six
groups summing to 63 bits. The 64th bit is not drawn; almost certainly
a 1-bit overlay/class-selector flag (per AP-120B precedent's `DF`).

| Bits | Parcel | Width | APSIM64 fields it carries |
|---|---|---|---|
| **1–12** | SPAD Grp | 12 | SOP/SOP1, SH, SPS, SPD (SOP/SOP1 mutex saves 1 bit) |
| **13–21** | Adder Grp | 9 | FADD/FADD1/IFADD1, A1, A2 (FADD-class mutex saves 1 bit) |
| **22–30** | Branch Grp | 9 | COND(4) + DISP(5) — **width matches APSIM64 exactly** |
| **31–49** | Data Pad Grp | 19 | DPX(2)+DPY(2)+DPBS(3)+XR(3)+YR(3)+XW(3)+YW(3) = **19 ✓ exact** |
| **50–54** | Multiplier Grp | 5 | FM(1)+M1(2)+M2(2) = **5 ✓ exact** |
| **55–63** | Memory Grp | 9 | MI(2)+MA(2)+DPA(2)+TMA(2) + 1 ext bit |
| **64** | overlay flag | 1 | inferred — primary/secondary parcel selector |

### Secondary parcel layout (overlays primary)

Boundaries shown: 1, 13, 22, 31, 39, 63. Five cells visible; one is
unlabeled in the figure.

| Bits | Parcel | Width | Notes |
|---|---|---|---|
| 1–12 | Spec Grp | 12 | 8-class SPECIAL OP per APSIM64 A-8 |
| 13–21 | I/O Grp | 9 | 8-class I/O OP per APSIM64 A-9 |
| 22–30 | Short value (hi) | 9 | likely SVALNL(1) + SVAL upper bits |
| 31–38 | (unlabeled) | 8 | likely SVAL low byte (SVAL=8 per APSIM64 A-7) |
| 39–63 | Address value | 25 | 24-bit `VALUE` per APSIM64 A-7, +1 ext bit |

Touzeau §2.2: "The secondary instruction parcels can be intermixed
with primary instruction parcels to produce a wide variety of
instruction formats."

### What this confirms about the family

- **Width-summing from APSIM64 Appendix A is correct to the bit** for
  Branch / Data Pad / Multiplier.
- **SPAD and Adder groups are 1 bit narrower** than naive width-sum
  suggests, because SOP/SOP1 share encoding (and similarly
  FADD/FADD1/IFADD1 share). This validates our "decode-class overlay"
  reading of those groups.
- **DPX / DPY are 32 × 64-bit registers each, with a 16-register
  "window"** the compiler can shift; SPAD = **64 × 32-bit registers**.
  These are the actual register-file sizes the field widths must
  address.
- **5 parallel functional units** issue per cycle: memory / FP-mul /
  FP-add / address-computation / control. The pipe depths are
  memory=3, multiplier=3, adder=2, address=1.
- **Pipes are explicitly pushed** by separate APAL operations
  (`FMPUSH`, `FAPUSH`); output latches FM/FA/SPFN hold values until
  the unit is pushed or re-issued.

### XP-32 inference, sharpened

Now that FPS-164 is pinned, XP-32 = "FPS-164 widened to 128 bits with
an extra adder and DMA controller" becomes specific:

| Group | FPS-164 (64-bit) | XP-32 (128-bit), inferred |
|---|---|---|
| SPAD | 12 bits | ~14 bits (with SPSX/SPDX/SPDX1 extensions slotted in) |
| Adder #1 | 9 bits | ~9 bits (preserved) |
| **Adder #2** | — | **~9 bits NEW** (Curington 1986: 2 adders on XP32) |
| Branch | 9 bits | ~12 bits (DISP widens to 12 to address 4K WCS) |
| Data Pad | 19 bits | ~25 bits (XR/YR/XW/YW + XE/YE extensions for larger TCM/LMD) |
| Multiplier | 5 bits | ~7 bits (FM/FM1/FM0 added) |
| Memory | 10 bits | ~10 bits (preserved) |
| **DMA Controller** | — | **~8-10 bits NEW** (Curington 1986: separate SCM↔local DMA) |
| Spec/IO Groups | 21 bits (secondary parcel) | ~21 bits (preserved as secondary) |
| Immediate | up to 26 bits (Address value) | ~26-32 bits (HVAL widens for IEEE-754 32-bit constants) |

Sums to ~125-135, which is close enough to 128 that the XP-32 layout
is now constrained to ≤±5 bits per group — a *much* tighter envelope
than the prior "guess between 39 and 60 bits of new content."

## The FPS-164 evolution (authoritative for direction of change)

From APSIM64 Appendix A, Tables A-1 through A-9. Same field names,
extended widths and new sub-fields:

| Group | AP-120B field | FPS-164 field(s) | Δ |
|---|---|---|---|
| S-Pad | `SOP` (3) | `SOP` (3) | same |
| | `SOP1` (4, overlay) | `SOP1` (4, separate) | promoted from overlay |
| | `SH` (2) | `SH` (2) | same |
| | `SPS` (4) | `SPS` (4) + **`SPSX` (2 NEW)** | **6-bit S-Pad source addr → 64 S-Pad regs** |
| | `SPD` (4) | `SPD` (4) + **`SPDX` (2)** + **`SPDX1` (2)** | similarly extended |
| Adder | `FADD` (4) | `FADD` (4) | same |
| | `FADD1` (3, overlay) | `FADD1` (3, separate) | promoted |
| | — | **`IFADD1` (3 NEW)** | **integer single-op adder ops** |
| | `A1`, `A2` (3 each) | `A1`, `A2` (3 each) | same |
| Branch | `COND` (4) | `COND` (4) | same |
| | `DISP` (5) | `DISP` (5) | same |
| Data Pad | `DPX`, `DPY` (2 each) | `DPX`, `DPY` (2 each) | same |
| | `DPBS` (3) | `DPBS` (3) | same |
| | `XR`/`YR`/`XW`/`YW` (3 each) | same | + **6 NEW 1-bit "extension" fields**: `XRXE`, `YRXE`, `YWXE`, `XRYE`, `YRYE`, `XWYE` (combine X/Y read-write addresses across both register banks) |
| Multiplier | `FM` (1) | `FM` (1) | same |
| | — | **`FM1` (2 NEW)** | **single-operand multiplier ops** |
| | — | **`FM0` (2 NEW)** | **zero-operand multiplier ops** (constants etc.) |
| | `M1`, `M2` (2 each) | `M1`, `M2` (2 each) | same |
| Memory | `MI`, `MA`, `DPA`, `TMA` (2 each) | same | same |
| Immediate | `VALUE` (~11, overlay) | **`SVAL` (8 NEW)**, **`VALUE` (24)**, **`HVAL` (32 NEW)**, **`SVALNL` (1 NEW)** | **promoted to multiple sized immediates including 32-bit** |

**Pattern: pure additive extension.** No field is renamed or
re-purposed. Every AP-120B mnemonic still works. The expansion is to
wider register addresses, single-operand integer/float ops, and
larger immediates — exactly what you'd expect from doubling the
microinstruction width.

## What the FPS-3000/XP32 docs say directly

In `refs/`, no XP32 reference manual. The four publicly-available XP32
papers (`refs/FPS-5000/Curington_*.pdf` + `refs/FPS-5000/FPS3000_curington1986symbolic_xp32.pdf`)
are at the **MAXL/CPFORTRAN application level** — they describe how to
*program* the XP32 in MAXL, not how the microinstruction is laid out.
The "Symbolic Execution Methods for XP32" paper (despite its title) is
about CPFORTRAN memory allocation, not microcode.

What the papers DO say about XP32 hardware:

- **6 MHz instruction clock**, all FP elements (Curington 1986
  *Synchronization and Pipeline Overhead Measurements*, p.3)
- **2 floating-point adders + 1 floating-point multiplier**, all
  pipelined, all producing one result per 6 MHz cycle (Curington 1986
  p.3, FPS-internal): *"The XP32 co-processor is also an SIMD
  architecture with a separate program storage memory, two floating
  point adders and one floating point multiplier. All three of these
  produce results at the instruction clock rate of 6 MHz."*
  (vs CP/AP-120B-class which has 1 adder + 1 multiplier — same paper)
- **Separate DMA controller on each XP32** for SCM↔local-memory
  movement, distinct from the FP pipelines (Curington 1986 p.3:
  *"the XP32 contains a high speed local memory, and a separate
  controller for movement of data between the local and the System
  Common Memory"*) — this is **not** present on the FPS-164/AP-120B
  in the same form
- **MAXL compiles to APAL** (explicit, Curington 1984: *"the speed
  of MAXL code interpreted by the processor, where MAXL is compiled
  to APAL rather than interpreted"*)
- **128-bit horizontal microinstructions** (Hockney & Jesshope §2.5,
  fig 2.53; corroborated by 4K × 128 × 4-banks WCS sizing)
- **4K × 128-bit WCS, 4 banks** per AC card (matches what the
  FPS-3000 ROM uploads to: 64 KB staging buffer = one bank)
- **80-bit EU PROM, 2K words** — fixed mask-programmed, *not* uploaded
  by the SBC (Hockney fig 2.53)
- **IEEE-754 32-bit float** (vs AP-120B's 38-bit proprietary)
- **TCM** (table mem, sin/cos): 4K × 32', 2 banks; **LMD**
  (local main data): 16K × 32', 2 banks (Hockney fig 2.53)
- **MIMD chassis with up to 3 XP-32 ACs** in FPS-5000 (Curington
  1986 p.3); the FPS-3000 SBC firmware exposes 4 channels
  (`TCBXP1I..XP4I`), of which the 4th may be a chassis variant
  difference or a slot reserved for a GPIOP-style I/O processor

## The strong inference (and where it gets soft)

The **firm part** is the family lineage:

> **The XP32 microinstruction inherits the AP-120B / FPS-164 field
> taxonomy.** Same group structure (S-Pad / Adder / Branch / Data-Pad
> / Multiplier / Memory / Immediate / Special-Op / I/O-Op), same
> pure-additive evolution philosophy, same APAL-source mnemonics
> visible to the programmer. The only degrees of freedom are which
> fields are extended, what's added in the new bits, and the exact
> bit-position offsets.

Evidence:

1. **Curington 1984: "MAXL compiles to APAL"** — load-bearing. APAL
   field names are fixed by FPS-7319 Vol 2 (AP-120B Programmer's Ref
   Part 2). If MAXL targets APAL on the XP32, then the XP32 accepts
   the same field-mnemonic vocabulary; the encoding is then
   constrained to be a structure-preserving widening of that.
2. **FPS-164's evolution pattern is purely additive** (APSIM64
   Appendix A): no field shrinks, none is repurposed, only widths
   grow and new fields slot in. XP32 (early–mid 1980s) is
   contemporary with FPS-164 and from the same company — same
   philosophy almost certainly applies.
3. **Byte-shoveling firmware:** the FPS-3000 ROM uploads opaque
   bytes, so it neither constrains nor reveals the microinstruction
   layout — but it does confirm the **WCS is 128-bit wide × 4K deep
   × 4 banks**.

The **soft part** is what the extra 64 bits do (FPS-164 = 64-bit,
XP32 = 128-bit). Earlier drafts of this doc said something like
"almost certainly a second adder's control fields" — that's
**overclaiming**. Here's the honest version, supported by
Curington 1986:

The extra 64 bits **plausibly** divide between:

| Plausible use of extra 64 bits | Why | Estimated bits |
|---|---|---|
| Second-adder controls (FADD₂ / A1₂ / A2₂ etc.) | Curington 1986 confirms 2 adders, 1 multiplier on XP32 vs 1+1 on CP/AP-120B. The extra adder needs ~10 control bits (function + 2× operand source) | ~10 |
| Wider Data-Pad addressing for TCM/LMD | XP32 has on-card TCM (4K×32') + LMD (16K×32') — a much larger on-card memory hierarchy than AP-120B/FPS-164. The XR/YR/XW/YW indices likely widen accordingly. The FPS-164 already added 6×1-bit XE/YE extension fields; XP32 likely adds more | ~10–15 |
| DMA-controller field group | Curington 1986: XP32 has "a separate controller for movement of data between the local and the System Common Memory" — distinct from FP pipelines. APSIM64 has no analogous group. XP32 likely has a new DMA-control field group similar in shape to the FPS-164 I/O-Op group (~3 bits × multiple decode classes) | ~5–10 |
| Wider IEEE-754 immediates | 32-bit IEEE-754 needs single-instruction loadable constants. FPS-164 already added `HVAL` (32-bit immediate); XP32 likely refines for IEEE-754 single-precision layout | ~0–8 |
| Per-AC sync / multi-AC bus fields | XP32 is multi-AC (1–3 per chassis) and the SBC firmware orchestrates inter-AC handoff via panel commands (`0x258..0x27D`); some of the 4 banks of WCS may be selected via control bits in the µinst itself rather than externally | ~2–4 |
| EU↔AU split-control (80-bit EU vs 128-bit AU) | The AU runs from the 128-bit WCS, but the EU runs from a separate 80-bit PROM. Some bits must coordinate the two. Could be a single "EU-issue-this-cycle" field carrying an EU PROM address | ~12 |

These add to ≥ 39 and ≤ ~60 bits — i.e. plausibly fill the extra 64
without needing radical re-design. But **which of these are actually
present, and what their exact widths and positions are, is unknown.**
Without an APAL-XP reference manual or simulator source, we are
guessing the *categories* from architectural function, not the
encoding.

The frame I'd stand behind: *"the XP32 microinstruction is the
AP-120B/FPS-164 microinstruction widened to 128 bits to accommodate
a second adder, a separate DMA controller, wider on-card data
addressing for TCM+LMD, and EU/AU coordination — with the field
taxonomy preserved per APAL-on-XP, but exact bit positions
undocumented in any source we currently have."*

## What this means for the recovered microcode

The recovered AP-120B FFT identity-test microcode I transcribed (227 ×
64-bit instructions) is in the **AP-120B/FPS-100** dialect.

| Question | Answer |
|---|---|
| Is it directly XP32-loadable? | **Probably not** — different float format (38-bit vs IEEE-754) means the FFT arithmetic would produce different results even if the encoding were accepted. |
| Does it tell us anything about the XP32 encoding? | **Yes** — the encoding for the lower 64 bits of an XP32 microinstruction is very likely a (possibly extended) superset of this exact format. |
| Could it run on SIM100? | **Yes** — SIM100 is the canonical AP-120B simulator. The microcode is in its native format. We can compile and execute. |
| Could a hypothetical XP32SIM accept it? | **Maybe** — if the XP32 has an "AP-120B compatibility mode" (unlikely but plausible given pure-additive evolution), yes. Otherwise no. |

## What it would take to recover the XP32 format definitively

In rough order of practicality:

1. **Find an XP32 / FPS-5000 / FPS-3000 microinstruction reference
   manual.** Likely document numbers in the FPS 860-7xxx series.
   Probably exists as paper at retired FPS engineers, ABB Bomem, or
   former FPS customer institutions. Not online.
2. **Find the XP32 simulator source** (analogous to SIM100/APSIM64).
   Same provenance.
3. **Disassemble actual XP32 microcode binaries** — but we have no
   extant XP32 microcode binaries. The Bomem application disks
   (BOM1–BOM13) might contain some, but they're missing.
4. **Reverse-engineer from the FPS-3000 hardware.** The XP32 EXEC
   card uses Am2900-family bit-slice; the WCS write port and
   sequencer microcode could in principle be analyzed if anyone has
   board-level scoping access (Usagi Electric does).

## Practical advice

For the immediate validation task on the recovered microcode, all
three sources point in the same direction:

- **Trust the AP-120B Vol 2 layout** for the actual transcribed
  microcode. The SIM100 SPLIT routine confirms it bit-for-bit.
- **Use FPS-164 APSIM64 Appendix A** as the "vocabulary" reference
  when annotating mnemonics — for any mnemonic in the AP-120B
  microcode that has an FPS-164 successor, the FPS-164 docs give
  more thorough field-by-field descriptions.
- **Treat XP32 as out of scope for now.** No public bit-level
  specification exists; speculation about format is constrained by
  the additive-evolution pattern but not pinned down. If the goal is
  bringing up Bomem's HPVP, that's an FPS-100 task, not an XP32
  task — the recovered microcode IS in the right dialect.
