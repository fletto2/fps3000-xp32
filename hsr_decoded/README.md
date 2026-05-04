# FPS-100 / AP-120B host service routine + microcode corpus

This directory contains the disassembled, documented form of every
routine in the FPS-100 RSX-11M v3.2 software distribution's
**Host Service Routines** (HSR) source files — `*HSR.MAC` in
`fps100_archive/fps100sw/`. **217 routines** across **7 libraries**,
totalling **21,066 AP-120B microinstructions** in 64-bit horizontal
format.

This is the production microcode that ran on every FPS-100 (and
its AP-120B sibling) shipped in the late 1970s. It's the canonical
example of the family's microcode style — far more code than the
single recovered FFT/IFFT identity-test microcode we had before.

## Provenance

The source `*HSR.MAC` files came from Al Kossow's bitsavers FLX-tape
recovery of the FPS-100 distribution
(`bitsavers.org/bits/FloatingPointSystems/FPS100/fps100sw.zip`).
Each MACRO-11 file packs, per math-library routine:

1. A small PDP-11 host-side stub (~12 lines of MACRO-11) that
   collects the user's args and calls `JSR PC, APEX`.
2. A `PARAM` block listing pointers to (CODE, START, SLIST, NSPADS).
3. The AP-120B microcode binary as inline `.WORD` lines — 4 octal
   16-bit numbers per 64-bit microinstruction.

The decoder uses the SPLIT field map documented in `CLAUDE.md`
(corresponds to `SUBROUTINE SPLIT` in `SIM100.FTN`, FPS's own
AP-120B simulator). 24 named fields per microinstruction — see
`hsr_disassembler.py` for the bit assignments.

## Library taxonomy

| Library | Routines | Microinstructions | Domain |
|---|---|---|---|
| `AMLLIB` | 23 | 3,789 | Applied Math (eigensolvers, banded systems, Householder reductions) |
| `BAALIB` | 88 | 2,511 | Basic Arithmetic Batch A — vector add/sub/mul/divide, complex arithmetic |
| `BABLIB` | 60 | 2,003 | Basic Arithmetic Batch B — max/min, logical, scaling, conversion |
| `DGNLIB` | 7 | 1,847 | Diagnostics |
| `IPRLIB` | 11 | 968 | Inner-product / 2-D operators (gradient, laplacian, FFT2D, …) |
| `SIGLIB` | 27 | ~9,948 | Signal processing (FFT family, windowing, spectra, transforms) |
| `UTLLIB` | 1 | 1 | Utilities (`APNOP` — single-instruction no-op) |

`SIGLIB` is the largest body (it includes the FFT machinery), and
`AMLLIB`'s `EIGRS` (582 µinstructions) is the largest single routine
— a real-symmetric eigensolver implementing tridiagonal-reduction +
QL with implicit shifts (per the source comment, based on EISPACK).

The BAA/BAB naming inheritance is preserved into XPMLIB on the
FPS-3000/5000 (Z-prefixed: `ZVMUL`, `ZCVMA`, etc.) and into APMATH64
on the FPS-164 (D-prefixed). Same routine taxonomy, different float
formats — see `fps_library_uniformity.md`.

## Per-routine file format

Each `<routine>.md` contains:

- **Library** + arg count (NSPADS) + entry uPC offset + microcode
  size (instructions and bytes)
- **Host-side PDP-11 stub** — verbatim from the `.MAC` source
- **AP-120B microcode disassembly** — one line per microinstruction:

  ```
  ;   uPC | w1     w2     w3     w4    | symbolic
  ;  ----+-------+------+------+------+----------
    0000  001620 000000 002000 000001  LDSPI R4; DP[DB=VALUE]; #000001
    0001  040000 000000 016000 020060  SPMOV R0,R0; DP[DPY1,DB=SPFN,YW=1]; SETMA
    0002  030404 000000 000000 000000  SPSUB R4,R1
  ```

The symbolic column shows non-empty field groups separated by `;`.
Empty groups are omitted. SPAD/Adder/Multiplier/DataPad/Memory/Branch
form the natural grouping (see `xp32_opcode_clues.md` for the
inheritance to FPS-3000/5000 XP-32 and FPS-164).

## Status of the decoder

This v1 decoder produces correct **field extraction** for every
microinstruction (verified against the SPLIT routine in SIM100.FTN
on the recovered FFT identity-test microcode, where the resulting
mnemonics matched the hand-annotated source listing).

The **value tables** for sub-fields are partial — known mnemonics
are emitted by name (`SPADD`/`SPMOV`/`FAA+B`/`JFN`/`INCMA`/...);
unknown values display the raw octal. Specifically:
- `SOPF` (S-Pad operation): 7 values named, 1 reserved as "single-op"
- `FADDF` (FALU function): all 8 values named
- `CONDF` (branch condition): all 16 values named
- `MAF` / `MIF` / `DPXF` / `DPYF`: known values named
- All register-index / immediate fields: emitted as octal numbers

Filling in the remaining mnemonic tables is mechanical follow-on work:
read the AP-120B Programmer's Reference Manual (FPS-7319, in `refs/AP-120B/`)
appendix tables, or run the routines through the SIM100 simulator
and trace what each numeric encoding does.

## Connection to the FPS-3000 / XP-32 work

These 217 routines are the **AP-120B / FPS-100 layer** of the FPS
math-software stack. They map onto the family's later evolution as:

| FPS-100 (this corpus) | FPS-3000/5000 (XPMLIB) | FPS-164 (APMATH64) |
|---|---|---|
| `VMUL`, `CVMUL`, `VMA`, `CVMA`, `RFFT`, … | `ZVMUL`, `ZCVMUL`, `ZVMA`, `ZRFFT`, … | `DVMUL`, `DVMA`, `DRFFT`, … |
| 38-bit FPS proprietary float | 32-bit IEEE-754 | 64-bit IEEE-754 |
| 64-bit µinst | 128-bit µinst | 64-bit µinst |

The Bomem DA3 ⇄ FPS-100 (HPVP) integration in Lovett's setup uses
*this* corpus directly; the missing Bomem floppies (BOM1–BOM13)
should add Bomem-specific FFT / interferogram / apodization kernels
that follow exactly the same `*HSR.MAC` packaging convention.

## How it ties to the protocol writeup

`host_to_fps100_protocol.md` documents the host-side wire protocol
(6 UNIBUS registers, 3 event flags, RUNDMA-driven kernel upload).
This directory documents the *content* that gets uploaded — the
actual microcode that the AP-120B executes after the host pokes
`CTRL.HDMAST`.

Together: the protocol + the corpus = a fully-documented FPS-100.

## Tooling

- `hsr_disassembler.py` (parent dir) — extractor + decoder. Single
  Python script, ~250 lines. Run with `--src <dir>` and `--out <dir>`.
- The decoder follows `CLAUDE.md`'s SPLIT bit-field table; aligned
  with `ucode_transcribed.py`'s data file (the recovered FFT
  identity-test microcode), which uses the same 4×16-bit packing.
