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
