# Can we infer XP-32 microcode from FPS-100 and FPS-164?

> **Erratum (2026-05-09)**: an earlier conversation pass decoded the
> SBC's 21 panel-command codes (`0x258..0x27D`) as a clean
> "MOV R4 → R[D], mode M" pattern in the Am29116 ISA, claiming this
> "decisively proved" interpretation B (panel codes are literal
> Am29116 instructions). **That analysis used an incorrect instruction
> format.** Re-decoding against the actual Am29116 / Am29C116
> datasheets shows the codes are `TOR1 SUBRC` two-operand subtract
> instructions, not MOVs. The conclusion that interpretation B is
> "decisively correct" is retracted; interpretations A, B, and a
> hybrid all remain plausible. See `panel_codes_am29116_decoded.md`
> for the corrected analysis. The PROM read remains the only way to
> settle the question definitively.

The honest answer is **structurally yes, bit-for-bit no** — and
that distinction matters a lot for what we can actually do
without reading the EU PROM off Lovett's hardware.

## What we have to work with

| Source | What it gives us | Gap to XP-32 |
|---|---|---|
| **AP-120B / FPS-100** (1976/1978) | Definitive 64-bit microinstruction layout (FPS-7319 + SIM100 SPLIT). 21,066 instructions of recovered production microcode in `hsr_decoded/`. Working emulator + assembler + linker | 64-bit vs 128-bit. 38-bit FP vs 32-bit IEEE. 1 adder + 1 multiplier vs 2+1. No DMA controller. |
| **FPS-164** (1981) | 64-bit microinstruction layout from Touzeau 1984 fig 2 (primary + secondary parcel structure, exact bit positions of group boundaries). APSIM64 manual Appendix A field tables. | 64-bit vs 128-bit. 64-bit IEEE-754 FP vs 32-bit. 1 adder + 1 multiplier vs 2+1. No on-card DMA controller (FPS-164's I/O is different). |
| **XP-32** target | 128-bit µinst per Hockney fig 2.53. 2 adders + 1 multiplier + DMA controller + on-card TCM/LMD. 32-bit IEEE-754. | What we don't know: exact bit-position layout, sub-field encodings, second-adder mux options, DMA-controller field encoding. |

## What we *can* infer (high confidence)

### 1. The set of fields almost certainly present

Inheritance from AP-120B → FPS-164 was **purely additive** —
APSIM64 confirms every AP-120B field name carries through with
same widths or wider, plus new fields slotted in. XP-32 is
contemporary with FPS-164 (early-to-mid 1980s), same engineering
team, same APAL-on-XP language statement (Curington 1984: "MAXL
is compiled to APAL"). So XP-32 must support **at minimum** all
AP-120B + FPS-164 fields:

| Group | Fields (FPS-164 widths) |
|---|---|
| S-Pad | SOP/SOP1, SH, SPS+SPSX, SPD+SPDX/SPDX1 |
| Adder #1 | FADD/FADD1/IFADD1, A1, A2 |
| Branch | COND, DISP |
| Data Pad | DPX, DPY, DPBS, XR/YR/XW/YW + XE/YE extensions |
| Multiplier | FM/FM1/FM0, M1, M2 |
| Memory | MI, MA, DPA, TMA |
| Special-Op | SPEC (8 sub-classes × 4 bits) |
| I/O-Op | I/O class (8 sub-classes × 3 bits) |
| Immediate | SVAL(8) / VALUE(24) / HVAL(32) / SVALNL(1) |

That's **~70 distinct fields**, summing to ~75-80 bits worth of
field-content (with overlay-style sharing).

### 2. The new fields XP-32 *must* add

Curington 1986 explicitly documents three architectural
features that AP-120B and FPS-164 do not have:

- **Second floating-point adder** ("two adders, one multiplier")
- **Separate DMA controller** ("the XP32 contains a high speed
  local memory, and a separate controller for movement of data
  between the local and the System Common Memory")
- **On-card memory hierarchy**: TCM (4K × 32', 2 banks) + LMD
  (16K × 32', 2 banks) — Hockney fig 2.53

Each of these requires control fields:
- **Adder #2 group**: ~9 bits (FADD₂ + A1₂ + A2₂, mirror of
  Adder #1) — though potentially asymmetric (Adder #2 might not
  be able to source from all the same places)
- **DMA group**: ~10-12 bits — control codes for SCM↔LMD/TCM
  transfers, similar in shape to the FPS-164's I/O-Op group
  (8 sub-classes × 3 bits = 24 bit-encoded operations) but
  dedicated to DMA
- **TCM/LMD addressing**: extra bits on existing XR/YR/XW/YW
  fields (FPS-164 already added 6 × 1-bit XE/YE extensions for
  this; XP-32's bigger LMD probably needs more)

### 3. The 128-bit budget allocation

Combining the above:

| Component | Bits |
|---|---|
| AP-120B/FPS-164 baseline (carrying through) | ~65 |
| Adder #2 controls | ~10 |
| DMA controller group | ~10 |
| Wider TCM/LMD addressing extensions | ~6 |
| IEEE-754 32-bit immediate variant | ~5 |
| EU↔AU coordination bits (sequencer state, etc.) | ~10 |
| Reserved / parity / unknown | ~22 |
| **Total** | **~128** |

That's a plausible allocation. The "reserved/unknown" 22 bits
are real headroom — XP-32 hardware might use them for things
we can't predict from the family lineage.

### 4. The instruction-level semantics

Where AP-120B has a `MOV R0, R1; FADD; XR=4; INCMA` instruction,
XP-32 must accept *something equivalent* — same fields, same
mnemonics, same per-cycle parallelism. The byte layout differs
but the *meaning* of a programmer-visible instruction is
preserved. This is the load-bearing claim from Curington 1984's
"MAXL is compiled to APAL" remark.

## What we *cannot* infer (without reading EU PROM)

### 1. Exact bit positions

The 128-bit budget could be laid out many ways:
- Adder #2 could be packed adjacent to Adder #1, or in a
  separate region
- DMA group could be in the upper or lower half
- Reserved bits could be anywhere
- Field-overlay decisions (when does S-Pad single-op overlay
  data-pad fields, etc.) are engineering choices

We can sketch a **candidate** layout that obeys all the known
constraints, but the actual hardware engineers picked one
specific layout out of many possibilities. **Without the
manual or schematics, we don't know which.**

### 2. Sub-field encodings

AP-120B has `MA=1 → INCMA, MA=2 → DECMA, MA=3 → SETMA`. XP-32
might use the same numeric assignments — or it might shuffle
them. The mnemonic vocabulary is preserved; the binary
encoding within each field is not guaranteed.

### 3. Asymmetry / second-adder limits

XP-32's two adders may not be functionally identical:
- Adder #1 might be the "primary" with full mux options
- Adder #2 might be restricted (e.g., can only source from FA₁
  output, can't read MD directly)
- Or they could be fully symmetric

This is an **engineering choice** that affects which
microinstruction patterns are valid. A microcode kernel
authored for symmetric adders might not run correctly if
Adder #2 has restrictions.

### 4. DMA controller field encoding

We have NO public reference for the XP-32 DMA controller's
microcode-level interface. The Curington 1986 paper says it
exists as "a separate controller" but doesn't document its
field encoding. We can predict **the SHAPE** (probably ~3-bit
class + ~3-bit sub-op + ~6-bit address/count, similar to
FPS-164's I/O-Op group) but not the actual values.

### 5. EU↔AU coordination

XP-32 has the unique split: 80-bit EU running from fixed PROM,
128-bit AU running from writable WCS. Some bits in the AU
microinstruction must coordinate with the EU's PROM sequencer.
This wasn't an issue for AP-120B/FPS-164 because they had a
single unified microcode. **We have zero direct evidence of
how the coordination works.**

## What this means for the project

### Path 1 — Build "candidate" microcode and try it

We can author XP-32 microcode by analogy:
1. Take an AP-120B kernel from `hsr_decoded/` (e.g., `VMUL`)
2. Encode it using a *guessed* XP-32 layout that respects the
   inferred field budget
3. Upload via the SBC's S-record path
4. See what happens

**Failure modes** (very likely):
- Hardware halts immediately (illegal opcode trap)
- Hardware runs but produces wrong results
- Hardware runs and *looks* right but corrupts state silently

Each failure mode gives us *something* — illegal-opcode trap
narrows the encoding hypothesis; wrong results tell us about
sub-field semantics. But it's slow, blind, and risks
hardware damage if a bad encoding triggers an unsafe state.

**Estimate**: 50-200 hours of trial-and-error per kernel,
probably converging to a working encoding for *one* simple
kernel like a single-FMUL test. Inefficient.

### Path 2 — Read the EU PROM (the right path)

The XP-32 EU is a Am29116 sequencer running from fixed mask
PROM (2K × 80-bit per Hockney). The PROM is on Lovett's EXEC
card. **It can be read** with a vintage PROM programmer +
adapter for whichever bipolar PROM type FPS used.

Once the EU PROM is dumped:
1. Disassemble the Am29116 instruction stream (datasheet is
   public; ~30h of Python work for a disassembler)
2. The EU's instructions include direct writes/reads to AU
   control registers — observing those tells us **the AU
   microinstruction layout** by looking at how the EU
   *uses* it
3. Pattern-match against AP-120B/FPS-164 inheritance to
   identify which fields are which
4. Synthesize a candidate XP-32 layout that's *grounded* in
   what the EU actually does

**Estimate**: 100-150 hours of well-defined work. Output is a
**working AU microinstruction layout** that hardware will
actually accept.

### Path 3 — Hybrid (recommended)

Use the upstream `nova_fps.c` AP-120B emulator + Python `sim100`
+ `asm2lm.py` assembler as the **AP-120B baseline tooling**.
Extend them step by step:

1. Add a 128-bit XP-32 instruction class to the assembler that
   encodes the inferred layout (with placeholder bit positions)
2. Run hand-authored XP-32 kernels against an *XP-32-extended
   simulator* (a fork of `sim100.py`'s APSIM that handles
   2 adders + DMA group + IEEE-754 32-bit FP)
3. Use this simulator to validate the *behavior* of candidate
   microcode without committing to specific bit positions
4. Once the EU PROM read happens (Path 2), fold in the actual
   bit positions and re-run to confirm

This is the **best path forward** — it lets desk-work proceed
without bench input, then refines once Lovett does the PROM
read. Failure is graceful (simulator results vs. real hardware
divergence is a clear signal of remaining unknowns).

**Estimate**: ~80h to extend the existing tooling for XP-32
simulation. Plus ~150h for the eventual Path 2 work to
validate against hardware. Total ~230h vs Path 1's 50-200h
trial-and-error, but with much higher confidence in correctness.

## The bottom line

**Inferring the structure is straightforward; inferring the
encoding is not.** Specifically:

| Question | Inferable from FPS-100 + FPS-164? |
|---|---|
| What fields exist? | ✓ (yes, with high confidence) |
| What groups they're in? | ✓ |
| What sub-classes each field has? | ⚠ (mostly yes for inherited fields, no for new XP-32 fields like DMA group) |
| Their bit positions in the 128-bit word? | ✗ (no — engineering choice, not constrained by lineage) |
| Sub-field numeric encodings? | ⚠ (probably preserved for inherited fields, but no guarantee) |
| Asymmetries (e.g., Adder #2 restrictions)? | ✗ (no — engineering choice) |
| DMA controller's exact field codes? | ✗ (no — entirely new on XP-32) |
| EU↔AU coordination protocol? | ✗ (no — XP-32-unique architecture) |

So: **we can write XP-32 microcode that is *structurally
plausible* without any new information**, and we can extend
the existing AP-120B simulator to *behaviorally validate* it.
But **we cannot author microcode that is guaranteed to execute
correctly on real XP-32 hardware** without either:

- Reading the EU PROM to recover the actual AU layout, OR
- Finding the APAL-XP / MAXL reference manual (no public
  copy known to exist), OR
- Lots of trial-and-error with real hardware

The realistic plan: **start the inference work now (Path 3
hybrid), so when the EU PROM read happens, the toolchain is
ready and validation is fast**. The PROM read is the gating
physical-world step — everything else can run in parallel.

## Cross-reference

- AP-120B / FPS-164 evolution analysis: `xp32_opcode_clues.md`
- 217 working AP-120B kernels: `hsr_decoded/`
- AP-120B emulator + assembler: `github.com/fletto2/ap120dg`
  + `github.com/roy20100/python-sim100`
- EU PROM read task: project_plan.md tasks B2, B3
