# 05 — Microcode

## The two control stores

| Unit | Storage | Width | Size | How filled |
|---|---|---|---|---|
| **Executive Unit** (Am29116-class controller) | **fixed bipolar PROM** ("EU PROM" per Hockney) | 80-bit | 2K words ≈ 20 KB | factory mask-programmed |
| **Arithmetic Unit** (FP pipelines) | writable WCS | 128-bit | 4K × 4 banks ≈ 256 KB | uploaded by SBC from host |

The 80-bit EU width = 16 bits Am29116 instruction + 64 bits side-
channel control fan-out to the rest of the EXEC card.

The SBC ROM **uploads AU microcode** via the 64 KB staging buffer at
`0x10000–0x1FFFF` (= exactly one 4K × 128-bit AU bank). It does
NOT upload EU microcode — the EU is fixed factory-set PROM per
Hockney's direct text (`pdftotext -raw refs/FPS-5000/FPS3000_fps.pdf`):

> "Microcode programs for the EU reside in EU PROM, which contains
> 2K 80-bit microcode instructions. Similarly, microcode programs
> for the AU reside in a writable control store (WCS)..."

The "Similarly, ... writable" CONTRASTS AU's writability with the
EU's fixed PROM. An earlier draft of this doc misread Hockney as
saying both are writable; that misread was caused by `pdftotext`
default mode dropping italicized inline abbreviations. See
`../eu_storage_clarified.md`.

## Consensus 128-bit AU layout (inferred)

Synthesized from the AP-120B → FPS-164 → XP-32 evolution chain via
two-LLM Council-of-Clankers (`mc_xp32_microcode_inference.md`), then
adversarially stress-tested (`mc_xp32_layout_stress.md`):

| Bits | Group | Width | Confidence |
|---|---|---|---|
| 1–23 | SPAD (DF, SOP, SOP1, SH, SPS, SPSX, SPD, SPDX, SPDX1) | 23 | **HIGH** |
| 24–35 | Adder #1 (FADD, IFADD, A1_1, A1_2) | 12 | **HIGH** |
| 36–47 | Adder #2 (symmetric mirror — UNVERIFIED) | 12 | medium |
| 48–56 | Branch (COND + DISP) | 9 | **HIGH** |
| 57–85 | Data Pad (DPX/DPY/DPBS + 4-bit XR/YR/XW/YW + XE/YE) | 29 | medium |
| 86–94 | Multiplier (FM, M1, M2, FM1, FM0) | 9 | **HIGH** |
| 95–103 | Memory (MI, MA, DPA, TMA, MEMX) | 9 | **HIGH** |
| 104–115 | DMA (4-op + 4-src + 4-dst) | 12 | low |
| 116–125 | EU coordination (8-bit EU PROM addr + 2-bit ctrl) | 10 | low |
| 126–128 | Special-Op + I/O-Op flags | 3 | medium |

First 103 bits (~80%): **field NAMES and group ordering** inherit
from documented AP-120B → FPS-164 evolution. **Field WIDTHS do NOT
inherit** — they are XP-32-specific re-allocations. The earlier
phrasing "first 103 bits inherit cleanly" was misleading and is
retracted (see `../VERIFIED_CLAIMS.md` §R1). Last 25 bits (DMA, EU
coord, Special) are pure speculation with no FPS-164 precedent.

## Adversarial objections to the layout (open)

From the stress test (`mc_xp32_layout_stress.md`):

1. **`EU_ADDR` is 8 bits** but the EU PROM is 2K = 11-bit address
   space. Either widen, or reinterpret as a dispatch-class index.
2. **No pipeline-stall / wait / hold bit.** FPS-164 and AP-120B
   have explicit synchronization controls; absence here is suspicious.
3. **`DF` flag may be 2 bits**, encoding a "parcel class" rather
   than a binary primary/secondary toggle.
4. **Adder #2 symmetry unverified** — FPS-3000 may have asymmetric
   adders (one FP + one integer/address).
5. **Multiplier control too late**? Bits 86–94 sit *after* the
   Data Pad (57–85). FPS pipeline convention puts multiplier control
   earlier so the multiply pipeline starts one cycle ahead.

## Panel commands (Am29116 instruction layer)

The 21 panel codes the SBC sends to the EU all decode as Am29116
TOR1 SUBRC instructions. See [04-protocols.md](04-protocols.md) for
the table and [`panel_codes_am29116_decoded.md`](../panel_codes_am29116_decoded.md)
for the verification.

Three interpretations remain live. Disambiguation requires either
an EU PROM dump or a live bus trace.

## What carries over from AP-120B

~90% of the instruction *mnemonics*: `MOV`, `ADD`, `FADD`, `FMUL`,
`DPX(reg)<MD`, `INCMA`, `JSR`. What changes:

- every field's bit position (XP-32 widens AP-120B's 64 bits to 128)
- the float pipeline width (38-bit FPS proprietary → IEEE-754 32-bit)
- the math library encoding (XPMLIB ≠ AP-120B math libraries)

The FPS-3000 SBC ROM is **microcode-format-agnostic** — it shovels
opaque bytes from RSX/host into the WCS. The wiring is the
incompatibility, not the firmware.

## Where to read more

- Inference: [`mc_xp32_microcode_inference.md`](../mc_xp32_microcode_inference.md)
- Stress test: [`mc_xp32_layout_stress.md`](../mc_xp32_layout_stress.md)
- AP-120B field-by-field: [`ap120b_ffttest_ucode.md`](../ap120b_ffttest_ucode.md)
- Older companion: [`xp32_microcode_format_inferred.md`](../xp32_microcode_format_inferred.md), [`xp32_opcode_clues.md`](../xp32_opcode_clues.md)
- Inference write-up: [`inferring_xp32_microcode.md`](../inferring_xp32_microcode.md)
