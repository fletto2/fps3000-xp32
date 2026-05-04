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

- **167 ns clock**, identical to AP-120B (Curington 1984)
- **MAXL compiles to APAL** (explicit statement, Curington 1984:
  *"the speed of MAXL code interpreted by the processor, where MAXL
  is compiled to APAL rather than interpreted"*)
- **128-bit horizontal microinstructions** (Hockney & Jesshope §2.5)
- **4K × 128-bit WCS, 4 banks** per AC card (matches what the
  FPS-3000 ROM uploads to)
- **IEEE-754 32-bit float** (vs AP-120B's 38-bit proprietary)
- **MIMD with 1–4 AC channels** (XP1I..XP4I in this firmware)

## The strong inference

Combining these:

> **The XP32 microinstruction is the AP-120B/FPS-164 microinstruction
> doubled in width, with the lower 64 bits keeping (or extending)
> APAL's field layout, and the upper 64 bits providing additional
> functional-unit control — most likely a second parallel issue slot
> or further extensions to the S-Pad / Data-Pad / immediate fields.**

Evidence for this specific shape:

1. **Curington's "MAXL compiles to APAL"** is the load-bearing
   statement. APAL is the AP-120B/FPS-100 assembly language. If MAXL
   targets APAL, then APAL is the human-readable layer for the XP32
   too — and APAL field names are fixed by the AP-120B Vol 2
   reference manual. The XP32 must therefore ACCEPT the same field
   names. The only degrees of freedom are: which fields are extended,
   and what's added in the new bits.
2. **FPS-164's evolution pattern is purely additive.** No field
   shrinks; no field is repurposed; only widths grow and new fields
   slot in. The XP32 is contemporary with the FPS-164 (both early-
   to-mid 1980s) and was designed at the same company; the same
   philosophy almost certainly applies.
3. **Byte-shoveling firmware.** The FPS-3000 ROM uploads opaque bytes
   without decoding instructions. So the upload mechanism doesn't
   constrain or reveal the microinstruction format; it just confirms
   the WCS is 128-bit wide × 4K deep.

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
