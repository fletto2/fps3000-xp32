# FPS-164 chip identification — does it use the Am29116?

**No.** Investigated in May 2026 when an LLM auditor (DeepSeek) claimed
the XP-32 must use Am2910A + Am2901/Am2903 instead of Am29116, citing
"Hockney p.240". The citation turned out to be hallucinated — Hockney's
PDF (`refs/FPS-5000/FPS3000_fps.pdf`) contains zero hits for `2910`,
`2901`, `29116`, `sequencer`, or `bit-slice`. But the underlying
question — whether the Am29116 actually appears in this FPS family —
deserved answering, and the answer for the FPS-164 is conclusive.

## Original FPS-164 (1981)

Per Charlesworth & Gustafson, *Introducing Replicated VLSI to
Supercomputing: the FPS-164/MAX Scientific Computer*, IEEE Micro 1986,
Table 1 (`refs/FPS-164/Charlesworth_-_Introducing_Replicated_VLSI_..._1986.pdf`):

> "The data unit (adder, multiplier, registers, and interconnect
> buses) of the 11-MFLOP FPS-164 Scientific Computer, designed in
> 1979 with medium-scale integration (10 to 100 gates per chip),
> required nearly 2000 chips. It occupied seven large (16- × 22-inch)
> printed circuit boards and dissipated 760 watts of power."

The Am29116 was first sampled in 1980 and didn't ship in volume until
1981 — too late for the FPS-164's original 1979 control-unit design,
which used Schottky-TTL MSI parts.

## FPS-164/MAX (1985)

The MAX matrix-accelerator boards added Weitek and Analog Devices
VLSI parts:

| Function | Part |
|---|---|
| Floating-point multiplier | WTL 1264 / ADSP-3210 |
| Floating-point ALU | WTL 1265 / ADSP-3220 |
| Register reservation unit | WTL 2068 |
| **Program sequencer** | **ADSP-1401** |
| Integer ALU | Two ADSP-1201s + WTL 2067 |

The MAX program sequencer is **ADSP-1401** (Analog Devices), not
Am29116. The original FPS-164 control unit was retained when MAX
boards were added, so the host-side sequencer is still TTL MSI.

## FPS-3000 by contrast

Nakazoto's 05_XP32_EXEC.JPG photo of the FPS-3000 EXEC card
(612-4805-002) clearly shows an **AMD Am29116DCB** in a 64-pin DIP.
This is a per-card chip choice that diverges from the FPS-164's
sequencer family. The FPS-3000 (1983) is in a different design
generation — late enough that the Am29116 was a sensible choice
for a single-chip 16-bit microprogrammed controller.

So the family chip-identification chain is:

| System | Year | EU/sequencer chip |
|---|---|---|
| AP-120B | 1976 | Schottky-TTL MSI (no single sequencer chip) |
| FPS-100 | 1977 | Schottky-TTL MSI (cheaper variant of AP-120B) |
| FPS-164 | 1981 | Schottky-TTL MSI (designed 1979) |
| FPS-164/MAX | 1985 | ADSP-1401 (MAX boards only; control unit unchanged) |
| **FPS-3000** | **1983** | **Am29116** (per Nakazoto photo) |
| FPS-264 | 1985 | ECL refresh of FPS-164 — same MSI architecture, ECL parts |

## Are there FPS-164 board photos online?

**Not in any organized public archive.** Searched in May 2026:

- bitsavers `pdf/floatingPointSystems/FPS-164/`: PDFs only
- Nakazoto `FPS 164/` directory on GitHub: PDFs only
- Charlesworth IEEE Micro paper: line drawings only, no photos
- Computer History Museum: at least one FPS-164 in collection per
  inventory references, but no online photo gallery found

`Nakazoto/FloatingPointSystems/KnownSurviving.txt` does not list any
surviving FPS-164 — only Lovett's FPS-3000, two LSSM AP-120Bs, two
FPS-100s, an AP-180V (China), an FPS-5100 (Europe), and two unloved
AP-120Bs. The FPS-164 may be effectively extinct in the wild.

## Implication for the XP-32 microcode-layout inference

The "AP-120B → FPS-164 → XP-32 layout-evolution" chain that grounds
our consensus 128-bit XP-32 layout (`mc_xp32_microcode_inference.md`)
is **not constrained by chip-level continuity**. The FPS-164 used
discrete TTL MSI control logic; the XP-32 EU is an Am29116 running
its own program. The XP-32 must additionally accommodate the
Am29116's 16-bit instruction encoding inside the 128-bit AU
microinstruction — structural information the FPS-164 layout doesn't
carry. We should weight this evidence into any future refinement of
the layout.

The 80-bit fixed PROM that Hockney associates with the EU is, on
the FPS-3000, the Am29116's instruction stream + side-channel control
fields. The width matches an Am29116 16-bit instruction (16 bits)
plus 64 bits of fan-out control to the rest of the EXEC card.
