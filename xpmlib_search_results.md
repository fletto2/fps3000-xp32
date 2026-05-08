# XPMLIB / FPS-3000 software search — findings

The stress test of the consensus XP-32 layout suggested a real XPMLIB
binary kernel could substitute for an EU PROM dump as a layout-
validation artifact. This document records the result of searching for
one.

## What was searched

- bitsavers.org `pdf/floatingPointSystems/` and `bits/FloatingPointSystems/`
- Nakazoto's GitHub repo (`Nakazoto/FloatingPointSystems`)
- VCFed FPS-100 thread (`forum.vcfed.org/threads/floating-point-systems-fps-100-found.1254035`)
- Hackaday Usagi/FPS appeal article + comments
- Internet Archive (`archive.org`) — fps-related collections
- General web search for "XPMLIB", "MAXL", "FPS-5000", "XP-32",
  "FPS-3000" + "software" / "tape" / "microcode" combinations
- The local FPS-100 software archive at `fps100_archive/` (already in
  this workspace from bitsavers' tape recovery)

## What does NOT exist publicly

- **No `XPMLIB` binary.** The string is essentially absent from the
  indexed web; only references are in Curington 1984 ("Performance
  Estimation Methods for XP32 MAXL") which describes its primitives
  but does not distribute the library.
- **No FPS-3000 software distribution** of any kind on bitsavers,
  archive.org, or community archives. The only FPS-3000 in
  Nakazoto's `KnownSurviving.txt` is Lovett's; nothing beyond
  hardware photos.
- **No FPS-5000 software** anywhere. bitsavers has 3 Curington PDFs
  + one ad. That is everything public.
- **No surviving FPS-164 software** either, despite the FPS-164
  having had real customers.

## What DOES exist (and is useful for the project)

### bitsavers FPS-100 software archive — already in this workspace

`fps100_archive/fps100sw/[327,010]*` (extracted from
`fps100sw.zip`, recovered from a damaged tape by Al Kossow). 183
files. Critical contents:

**9 binary math-library files (`.APO`)** — production AP-120B
microcode kernels:

| File | Bytes | Microinstructions | Purpose |
|---|---:|---:|---|
| `BAALIB.APO` | 102,102 | 12,762 | Basic math library, part 1 |
| `BABLIB.APO` | 102,258 | 12,782 | Basic math library, part 2 |
| `SIGLIB.APO` | 86,122 | 10,765 | Signal-processing library |
| `AMLLIB.APO` | 69,528 | 8,691 | Applied-math library |
| `IPRLIB.APO` | 52,238 | 6,529 | Integer pre-processor library |
| `UTLLIB.APO` | 39,950 | 4,993 | Utility library |
| `APFLIB.APO` | 23,812 | 2,976 | APF library |
| `DGNLIB.APO` | 10,972 | 1,371 | Diagnostic library |
| `SYMLIB.APO` | 7,598 | 949 | Symbol library |
| `VADD.APO` | 2,498 | 312 | Vector-add (standalone) |
| **Total** | **497,078** | **62,130** | |

That's **62,130 AP-120B microinstructions of real production kernels**
with documented header conventions (`$LIB` directive, revision
history comments, conditional-assembly switches).

**9 matching APAL source files (`*SRC.APS`)** with comments,
revision history, conditional-assembly directives — full ground
truth for cross-validating any decoder.

**The toolchain itself** as FORTRAN-77 source:
- `ASM100.FTN` — assembler
- `LED100.FTN` — link editor
- `SIM100.FTN` — simulator (containing the canonical 24-field
  `SPLIT(CB,FV)` microinstruction-decode subroutine)
- `DBG100.FTN` — debugger
- `ART100.FTN` — array runner
- `KERNEL.{B,S}`, `IOQUE.{B,S}`, `HSVC.{B,S}` — host-side OS pieces
- `INSTAL.TXT` — 162 KB installation manual

## What this gives us (without an XPMLIB binary)

The FPS-100 archive is *not* XPMLIB — but it is the closest analog:
real production-quality binary microcode from the same FPS family,
with matching source code and documented format. It enables:

1. **Cross-check the 24-field AP-120B layout end-to-end.** Decode
   each `.APO` using `SIM100.FTN`'s `SPLIT` routine, compare the
   decode against the `.APS` source — that proves we read the AP-120B
   format correctly. We had the recovered FFT identity-test microcode
   already, but 62K microinstructions with source ≫ 227 microinstructions
   without.

2. **Bracket the XP-32 layout from below.** The AP-120B → FPS-164 →
   XP-32 layout-evolution arc that the consensus 128-bit layout
   inherits is now grounded in a much larger sample. Any XP-32
   microinstruction must (per APAL compatibility) carry every field
   exercised by these 62K AP-120B kernels.

3. **Run real workloads in the AP-120B simulator.** SIM100 + the
   `BAALIB` kernels gives a working "FFT/multiply/etc. on simulated
   AP-120B" that can be used as a control for any FPS-3000 simulator
   we eventually build.

4. **Test the panel-command upload path on the FPS-3000.** If the
   FPS-3000's WCS-write port is wired such that 64-bit AP-120B
   microcode would also fit (highly unlikely — it's a 128-bit port),
   we could try uploading these. More realistically, we use them as
   a known-good source for synthesizing test microinstructions in
   whatever the XP-32 actually accepts.

## Realistic paths to an actual XPMLIB binary

In rough decreasing probability:

1. **Myron White** — posted on Hackaday on 2025-07-10: "I have
   schematics for an AP120B, and I was the lead HW designer for the
   FPS-100. How can I contact Usagi?" If he has personal archives of
   FPS-100 era software, he may also know where FPS-3000/5000
   software went. Usagi could/should be the contact.

2. **FPS-5000/3000 customer sites c.1984-90.** Curington's papers
   imply LANL, NCAR, USGS, oil/gas seismic outfits. Any of these may
   have decommissioned tapes in storage.

3. **Cully (Massachusetts)** — has a powered-up FPS-100 per
   Nakazoto's `KnownSurviving.txt`. He may have software too.

4. **Cray archives.** FPS was acquired by Cray in 1991; FPS source
   code may have ended up at Cray, then SGI (1996), then HPE.
   Probably lost, but worth asking the Computer History Museum.

5. **FPS-164 software.** Same MAXL-family compiler but for the
   later 64-bit machine. Even less likely to surface since no
   FPS-164 hardware is on the surviving-systems list.

## Recommendation

Stop searching for XPMLIB. **Pivot to fully exploiting the FPS-100
archive** — disassemble all 9 .APO files via SIM100's SPLIT routine,
cross-validate against the .APS sources, and use that as the AP-120B
ground-truth corpus. The AP-120B → XP-32 layout evolution chain
becomes the validation framework for the consensus 128-bit layout,
*without* needing an XPMLIB binary or an EU PROM dump.

If Lovett ever does succeed at reading the EU PROM, all of this
becomes a stronger validation set for the layout. Either way, the
work is unblocked.
