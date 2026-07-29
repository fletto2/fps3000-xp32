# The XP-32 ARITH card is AMD's published FFT architecture, part for part

Matching the card parts survey against AMD's *Am29500 Family Handbook*
(1986, §4.1, "Optimum Cost/Performance Radix-2 FFT" reference design)
gives a role for every significant part on the XP32 ARITH card — and
several direct consequences for the 128-bit microword layout.

Source: `refs/datasheets/AMD_Am29500_Family_Handbook_1986.pdf`, and
`refs_extracted/card_parts_inventory.md` card 06.

---

## The match

| AMD reference-design role | Handbook | FPS-3000 ARITH part | Qty |
|---|---|---|---|
| **FFT address sequencer** | §4.1.3 | **AM29540DC** (ceramic, gold lid) | 1 |
| **data-memory address pipeline register** | line 1422 | **L29C520PC-R** (Logic Devices' Am29520) | ≥6 |
| **coefficient-PROM address pipeline register** | line 1423 | **AM29821DC** | many |
| data memory | §4.1.3 | **AM2168-45PCB** 4K×4 SRAM | many |
| coefficient PROMs | §4.1.3 | **29F52 SDC** PROM banks | many |
| address generation for filters / matrix multiply | line 1748 | **AM29116DCB** (on the EXEC card) | 1–2 |

The handbook states the two roles explicitly:

> The Am29520 is the address pipeline register for the data memory. The
> Am29821 is the address pipeline register for the coefficient PROMs for
> the FFT and filter algorithms.

and

> The Am29540 and the Am29116 generate addresses for DSP algorithms. The
> Am29540 is an FFT address generator.

`L29C520PC-R` had no identified role in the survey; it is Logic Devices'
CMOS Am29520, which is what closes the match.

**This is inference, but strong inference.** FPS could have arrived at the
same parts independently — they were the obvious choices for the job in
1983 — but a six-part correspondence including the pipeline-register
split between data and coefficient addressing is not coincidence. The
reasonable reading is that FPS built the ARITH card from AMD's reference
architecture.

---

## What this settles about the FFT question

Until now the FFT-engine reading of the XP-32 rested entirely on
software-side evidence: XPMLIB's `ZRFFT`, the AP-120B FFT identity-test
microcode recovered earlier, and the Curington papers' emphasis on signal
processing. A dedicated FFT address sequencer plus a coefficient-PROM
addressing path is **hardware built for FFTs specifically**. Nobody fits
an Am29540 to a general-purpose array processor.

---

## Consequences for the 128-bit microword

`notes/mc_xp32_microcode_inference.md` marks two fields low-confidence:
"DMA (12 bits, sub-fields unknown)" and "EU coordination (10 bits,
sub-fields unknown)". The handbook describes what the microcode has to
carry for this architecture, and it is much less than address
generation:

1. **FFT type is a few bits.** "The microcode indicates to the address
   sequencer the FFT type (radix 4/2; in-place, non-in-place; DIT/DIF)."
   That is 1 bit of radix, 1 of in-place, 1 of decimation — call it 3.
2. **Transform length is 4 bits, latched once.** "Four bits from the
   Instruction Register indicate the transform length to the sequencer.
   The transform length is latched into the part at the start of the
   process." It comes from an instruction register, **not** from the
   microword, and only at process start.
3. **Addresses are not in the microword at all.** "That's all that is
   required for initialization. The sequencer now produces data and
   coefficient address in the required order for the entire transform."
   So during an FFT the microcode carries no address fields — the
   hardware walks the butterfly.
4. **The Am29520 needs about 4 bits.** "Four bits of microcode control"
   the source/destination pipeline levels.
5. **The Am29821 is driven by write-enable lines from the microword**,
   not by an address field.

### The overlay, which is the useful part

> Since the board runs just one process at a time, the Am29540 and the
> Am29116 are never used simultaneously. **Therefore the microcode bits
> for the two parts are overlayed.**

If FPS followed the reference design here too, then a field in the
128-bit word is **dual-purpose**: Am29540 FFT-sequencer control during
transforms, Am29116 control otherwise. That would explain a real
difficulty in the layout work — a field that decodes sensibly under one
reading and as noise under another is exactly what an overlaid field
looks like, and no amount of consistency-checking against a single
interpretation will resolve it.

It also means the "EU coordination" group and part of the "DMA" group in
the consensus layout may not be separate fields at all, but one shared
region with a mode bit selecting the interpretation. Worth testing
against any real XPMLIB kernel that turns up: an FFT kernel and a
non-FFT kernel should use the same bits for visibly different purposes.

---

## Caveats

- The reference design is a **16-bit** DSP board (two Am29501 ALU slices
  per 16-bit channel). The XP-32 is 32-bit IEEE-754 with Weitek
  multipliers, so the datapath differs; the **addressing** subsystem is
  what matches.
- The survey counts one Am29540. A four-bank WCS machine might use more;
  one is what was read.
- Everything above about the microword is inference from AMD's design
  applied to FPS's hardware. It predicts what to look for; it does not
  establish the FPS encoding.

---

## AMD publishes the reference design's 128-bit microword — and it is bit-mapped

§4.1 states the design's microprogram control unit outright:

> The microword width is **128 bits**. The code can be up to **2K** deep.
> High-speed (35 ns) registered PROMs are used to store the code. The
> sequencer is the Am2910A. Two Am2922s allow the sequencer to test up to
> 16 different conditions.

128 bits is the XP-32 AU microword width exactly, and 2K is the EU PROM
depth Hockney gives. That is not proof of a shared design, but it is a
second independent convergence on top of the six-part hardware match.

Better still, **Appendix 2 (`DSP.DEF`) is reproduced in full** — the
AMDASM meta-assembler definition file, opening with `WORD 128` and
followed by a bit-numbered map. The OCR is imperfect but the structure is
unambiguous:

| Bits | Group | Contents |
|---|---|---|
| 127–96 | **Real ALU** | shift, ALU function, `R0p`/`Rsp` selects, A/B port selects, `RMIO3-0`, `RDIO2-0`, `RWE` |
| 95–64 | **Imaginary ALU** | the same fields mirrored (`IALU`, `IA…`, `IB…`, `IMIO`, `IDIO`, `IWE`) |
| 63–32 | **Multiplier + Address Generator** | `RND`, multiplier port selects, then `AG19…AG0` — twenty address-generator bits |
| 31–0 | **Program Sequence** | `INTR`, `CKSEL`, `CCSEL3-0`, `BR11…BR0` branch address, `IOI3-0` |

Four 32-bit quarters, one per major resource.

### The overlay is explicit, and it carries an Am29116 instruction

Immediately after the main map the file has a section headed
**`ADDRESS GENERATOR OVERLAY`**, redefining the same bit positions as
`DITIF`, `4I2`, `PSD`, `S3-0` … and **`I15…I00`** — a full **16-bit
Am29116 instruction field** occupying the bits that otherwise carry
Am29540 FFT control.

This is the prose claim ("the microcode bits for the two parts are
overlayed") realised in the actual assembler definitions, and it is
directly relevant: the XP-32's EU also has an Am29116 whose 16-bit
instruction has to come from somewhere, and CLAUDE.md's reading of
Hockney's 80-bit EU word is "16-bit Am29116 instruction + 64 bits of side
control".

---

## This resolves an open objection in the layout stress test

`notes/mc_xp32_layout_stress.md` lists as an unresolved adversarial
objection:

> Adder #2 symmetry unverified — the FPS-3000 may have asymmetric adders
> (one FP + one integer/address).

The consensus layout allots bits 24–35 to "Adder #1" and 36–47 to
"Adder #2 (symmetric mirror — UNVERIFIED)". AMD's design answers the
architectural question: its two ALUs are the **real and imaginary halves
of complex arithmetic**, byte-for-byte symmetric in the microword because
complex data demands it.

The FPS-3000 AC is described as "1 mul + 2 add" — the same shape. For a
machine built around FFTs, two *symmetric* adders is the expected design,
not two differently-purposed ones. The objection does not disappear —
FPS could still have made them asymmetric — but the "one FP + one
integer/address" alternative now has to explain why an FFT engine would
forgo a complex-arithmetic datapath its own parts list is organised
around.

**What does not carry over:** AMD's ALUs are Am29501 16-bit fixed-point
slices; the XP-32 is 32-bit IEEE-754 with Weitek parts. The field
*contents* will differ. What transfers is the organising principle — two
symmetric arithmetic channels, a multiplier, a sequencer, and an
address-generator region overlaid with an Am29116 instruction.

---

## The appendix also carries worked FFT microcode — preserved

Appendix 2 does not stop at definitions. It includes **working microcode**
for the reference design: forward FFT, inverse FFT, the two butterfly
loops (`BTF.LOOP`, `IBTF.LUP`) and matrix multiply (`MXMULT`).

Extracted verbatim to
**`refs_extracted/amd_dsp_reference_microcode.txt`** (1,609 lines, 367
labels) with the OCR damage catalogued in its header.

Each microinstruction is a lead line plus `&` continuation lines, one per
resource group. A single butterfly step reads:

```
ADG.HOLD  CF.HOLD, DIT, RADIX.2, NORM.ORD, ADR1, ADP.LOA, ADP.A2
&  WR.CMPX
&  R.SUBS A1,A3, , A2.EQ.AU, , B1.HOLD, B2.HOLD, , M.EQ.B1, D.EQ.A2
&  I.ADD  B2,MSP, A1.HOLD, , A3.HOLD, B1.HOLD, B2.EQ.AU, B3.EQ.MP, MIO.IN, D.EQ.A2
&  MSPROD MP.ROUND, MP.FRAC, MY.IN, MXY.2C, MX.COS, BUFEN
&  MISC
&  CJP IF.LOW, FFT.ITC, IT1.LOOP
```

Seven groups in one 128-bit word: address generator, memory write, real
ALU, imaginary ALU, multiplier, misc, sequencer. The real and imaginary
lines carry the **same operand structure with different operations**
(`R.SUBS` against `I.ADD`) — the complex butterfly `A ± BW` expressed as
two symmetric ALU channels driven in parallel.

**Why keep it.** This project has never had an example of the kind of
code the XP-32 AU WCS holds. The recovered AP-120B microcode is the
64-bit ancestor with a different field structure; a real XPMLIB kernel
has never surfaced. This is a 128-bit horizontal microword for an
architecture built from the same parts, doing the workload the XP-32 was
built for, with the field layout published alongside. For questions of
the form "how would a butterfly be scheduled across these units" or
"which resources share a microinstruction", it is the best available
evidence.

It is not XP-32 microcode and must not be read as such — different ALU
width, different float format, different vendor. Its value is structural.
