# `.APO` files are NOT raw binary microcode — obstacle for option 1

> **Status: SOLVED.** This document is historical. The .APO format
> was successfully reverse-engineered (`fps100_apo_format_spec.md`)
> and a working Python decoder (`apo_decode.py`) was built. All 9
> .APO math-library files plus 34 .B AP-side supervisor files have
> been decoded — see `apo_decoded/` and `apo_decoded/B_files/`. SIM100
> compiles cleanly with proper flags (see `sim100_build/`). Kept for
> historical record of the obstacle and how it was resolved.


Started option 1 (deep-mine the FPS-100 archive — disassemble all 9
`.APO` library files via SIM100's SPLIT decoder) and hit an
unexpected obstacle: **`.APO` files are not raw 8-byte-per-instruction
binary microcode**. They are **ASCII text in ASM100's intermediate
object-file format**, with column-formatted decimal numbers and
`***LSB` / `***TITLE` / `***PB` directives.

Example from `[327,010]VADD.APO`:

```
     6      ***LSB
     3      ***TITLE
VADD
    12      7      ***PB
     2     1     2
     1      2
     1      7
     1     1     0
     2     1     2
     1      4
...
```

This is the format `LED100` (the AP-120B link editor) consumes to
produce the actual binary load module that gets uploaded to the
AP-120B/FPS-100 program memory.

## Earlier (now-corrected) project assumption

`CLAUDE.md` claimed "9 binary `.APO` math-library files totalling
**11,469 AP-120B microinstructions** with matching APAL `.APS`
source." This bytes-divided-by-8 calculation assumed binary; the
files are text. The actual microinstruction count requires running
the .APO files through the linker first.

## Paths forward

### Option A — compile and run LED100 + SIM100 as black boxes

`gfortran --std=legacy` partially compiles SIM100.FTN but trips on
statement-function syntax (`IRSHFT(I,J)=0` at line 4033 — a
single-line function definition no longer accepted).

LED100.FTN fails at line 1 with what looks like a CRLF/encoding
issue, plus uses unformatted `READ(LUNX)(BUFFER(I),I=1,LENX)` which
gfortran doesn't accept directly.

Both tools were originally compiled with PDP-11 FORTRAN-IV-PLUS or
F4P, which differs from F77/F90 standard. To run them on a modern
Linux box would require:

- Patching the statement-functions and unformatted-READ syntax to
  modern equivalents, OR
- Running them in a real PDP-11 SIMH simulator (we have SimH built
  at `/tmp/simh/BIN/pdp11`) with a stock RSX-11M v3.2 image —
  approximately the original deployment environment

**Cost**: SimH path is most authentic but requires an RSX-11M v3.2
distribution disk (we have v5.1.1 from Bomem, not v3.2). Patching
SIM100/LED100 for gfortran is a few hours of careful work.

### Option B — reverse-engineer the .APO format from LED100 source

LED100.FTN's `LOAD` subroutine (line 3031) and supporting helpers
parse the .APO format. ~500 lines of FORTRAN-77 to read carefully.
Output: a Python parser that converts .APO → 8-byte microinstructions.
Then SIM100's SPLIT decoder is straightforward to port.

**Cost**: a day or two of careful reading.

### Option C — start from already-recovered binary microcode

`ap120b_ffttest_ucode.bin` (1816 bytes, 227 instructions) is already
recovered from the AP120B FFT test PDF and is in canonical 8-byte
binary form. SPLIT decoder can run on it today. Smaller corpus
(227 vs ~11,469 from libraries; 1971 from AP-side; 13,440 total) but immediately usable.

### Option D — recover LM-format binaries (load modules)

After LED100 produces a load module, the binary is in LM (load
module) format — but we don't have LM files in the recovered
distribution either. Customer site would have created LMs locally
from the .APO objects.

## Recommendation

Pursue **Option B** — reverse-engineer the .APO format from LED100
source. Output: a Python `.APO` reader + SPLIT decoder that produces
APAL-style disassembly. Cross-validate against the matching `.APS`
source files (which we DO have, and which are human-readable APAL
assembly with comments).

This delivers the original goal — full ground-truth AP-120B microcode
corpus — without needing to compile/run the original toolchain.

## What's been done so far

- `fps100_dapex_annotated.md` — complete Council-of-Clankers
  annotation of `DAPEX.MAC` (the host-side dispatcher library).
  100 KB. The single chokepoint between user code and APDRV
  reverse-engineered to reference quality.
- This obstacle doc captures the .APO-format finding.

## What's pending

- Reverse-engineer .APO format from LED100 source
- Build Python disassembler that produces APAL-style output
- Cross-validate against `.APS` source for each library (.APS files
  ARE plain APAL assembly with comments and documented headers)
- Produce final `.apo_decoded/` directory with all 9 libraries
  decoded as APAL
