# FPS-100 / AP-120B math library — decoded production microcode

11,469 microinstructions across ~313 routines, decoded from the
bitsavers FPS-100 RSX-11M v3.2 distribution (Al Kossow's tape
recovery, Jan 1980).

To my knowledge this is the **largest publicly recovered corpus of
FPS production microcode**, ~51× larger than the AP-120B FFT
identity-test microcode previously recovered (227 instructions,
also in this repo as `ap120b_ffttest_ucode.bin`).

## What's here

| File | Library | Routines | Microinstructions |
|---|---|---:|---:|
| `BAALIB.dis` | Basic Algorithms A | 88 | 1847 |
| `BABLIB.dis` | Basic Algorithms B | 60 | 2273 |
| `SIGLIB.dis` | Signal Processing | 32 | 2129 |
| `AMLLIB.dis` | Applied Math | 33 | 1925 |
| `IPRLIB.dis` | Image Processing | 13 | 1486 |
| `UTLLIB.dis` | Utility | 39 | 1022 |
| `APFLIB.dis` | APF (auxiliary) | 34 | 456 |
| `DGNLIB.dis` | Diagnostics | 11 | 282 |
| `VADD.dis` | Vector Add (standalone) | 3 | 49 |
| `SYMLIB.dis` | Symbol library | 0 | 0 (no code, just symbols) |
| **Total** | | **~313** | **11,469** |

Each `.dis` file is an APAL-style disassembly listing with:

- Octal address (4 digits)
- 8-byte hex representation of the microinstruction
- Field decode showing the nonzero of 24 fields per microinstruction

## Sample output

```
; ============================================================
; ROUTINE: VADD (14 microinstructions)
; ============================================================
  0000: 03 bc 00 00 04 00 00 6a
        ; SPSF=14 SPDF=15 DPBSF=2 MIF=1 MAF=2 DPAF=2 TMAF=2
  0001: 12 0c 00 00 00 00 00 00
        ; SOPF=1 SPSF=8 SPDF=3
  ...
  0010: 20 c8 c4 00 1b 40 80 30
        ; SOPF=2 SPSF=3 SPDF=2 FADDF=1 A1F=4 A2F=2 DPYF=1
        ;   DPBSF=5 XRF=5 YWF=4 MAF=3
  ...
```

## How it was produced

`../apo_decode.py` reads each `.APO` file (the textual ASM100 object-
file format), locates `***CODE` block headers, and consumes exactly
`RECCNT` records per CODE block. Each record is one line of 4 octal
16-bit words = 8 bytes = one AP-120B microinstruction.

Each microinstruction is then decoded via the canonical SIM100
SPLIT routine (`SIM100.FTN` line 3863), which decomposes the 8 bytes
into 24 named fields per the AP-120B microarchitecture. Field
meanings come from the FPS-7319 Programmer's Reference Manual.

| FV# | Name | Bits | Function |
|---|---|---|---|
| 1 | DF | 1 | DPX bit-reverse flag |
| 2 | SOPF | 3 | S-Pad operation |
| 3 | SHF | 2 | shift |
| 4 | SPSF | 4 | S-Pad source register index |
| 5 | SPDF | 4 | S-Pad dest register index |
| 6 | FADDF | 3 | FALU function |
| 7 | A1F | 3 | FALU input-1 source |
| 8 | A2F | 3 | FALU input-2 source |
| 9 | CONDF | 4 | branch condition |
| 10 | DISPF | 5 | branch displacement / immediate |
| 11 | DPXF | 2 | DPX function |
| 12 | DPYF | 2 | DPY function |
| 13 | DPBSF | 3 | DP-Bus select |
| 14 | XRF | 3 | DPX read addr |
| 15 | YRF | 3 | DPY read addr |
| 16 | XWF | 3 | DPX write addr |
| 17 | YWF | 3 | DPY write addr |
| 18 | FMF | 1 | FMUL fire |
| 19 | M1F | 2 | FMUL input-1 source |
| 20 | M2F | 2 | FMUL input-2 source |
| 21 | MIF | 2 | memory input |
| 22 | MAF | 2 | memory address function (MAF=1 = INCMA) |
| 23 | DPAF | 2 | DP address |
| 24 | TMAF | 2 | TM address |

## Usage

```sh
# Summary of any .APO file
python3 ../apo_decode.py path/to/file.APO --summary

# List routines + sizes
python3 ../apo_decode.py path/to/file.APO --list

# Full decode of a single routine
python3 ../apo_decode.py path/to/file.APO --routine VADD

# Full decode of everything (already done — see *.dis files)
python3 ../apo_decode.py path/to/file.APO
```

## How `.APO` format was reverse-engineered

`.APO` files are text, not binary. They are the intermediate object-
file format produced by `ASM100` (the AP-120B assembler) and consumed
by `LED100` (the link editor). Format spec was derived from
`LED100.FTN`'s `LOAD` subroutine (line 3031) via Council-of-Clankers
analysis (DeepSeek + GLM-4.5-air, cooperative + adversarial passes).
Spec captured in `../fps100_apo_format_spec.md`.

Each block has the form:

```
<tokens> ***BLOCKNAME
<payload lines>
```

Block types observed:

| Marker | Purpose | Payload |
|---|---|---|
| `***LSB` | Library Start Block | none |
| `***TITLE` | Routine title | 1 line: name |
| `***PB` / `***FPB` | Program / File-Parameter Block | RECCNT records |
| `***AENTRY` | Alternate Entry | N records |
| `***ENTRY` | Entry point | N records |
| `***CODE` | Microinstruction code block | RECCNT records (4 octal words each) |
| `***EXT` | External symbol | N records |
| `***END` | Routine end | 1 line: name |
| `***DBDB` `***DBIB` `***PARAM` `***INDEX` `***TASK` `***ISR` | Various data / task / ISR / index blocks | varies |

The decoder uses `***CODE` markers as anchors and treats other block
types as opaque (counted but not consumed in detail). This is robust
to format variations across libraries.

## Counts: history of corrections

The microinstruction-count claim has gone through three revisions:

| Source | Count | Correctness |
|---|---:|---|
| Earlier `CLAUDE.md` | 62,130 | Wrong — that was raw `bytes/8` of the text-format `.APO` files, treating them as raw binary microcode |
| First fixed parser | 6,581 | Drift undercount — parser lost sync after first routine in large files |
| **Current parser** | **11,469** | Correct — verified by routine counts matching `.APS` source files exactly |

## Why this matters for the FPS-3000 project

The FPS-3000 inherits its 128-bit microinstruction format from the
AP-120B's 64-bit (24-field) format via the FPS-100 → FPS-164 → XP-32
evolution chain (see `../mc_xp32_microcode_inference.md`). Having
11,469 real production AP-120B microinstructions with field-decoded
output:

- Validates the consensus 128-bit XP-32 layout's first 103 bits
  (which inherit directly from the AP-120B/FPS-164 evolution)
- Provides ground truth for any AP-120B simulator (e.g. `SIM100.FTN`
  ported to modern Fortran)
- Gives a corpus large enough to derive AP-120B coding idioms
  empirically (which fields tend to be 0/nonzero together, common
  field-value combinations, branch-target patterns)

The matching `.APS` source files (in
`../fps100_archive/fps100sw/[327,010]*SRC.APS`) provide human-
readable APAL assembly with author comments and revision history,
which can be cross-referenced with this decoded binary corpus.

## Reproducibility

```sh
cd /path/to/this/repo
for lib in BAALIB BABLIB AMLLIB IPRLIB SIGLIB UTLLIB DGNLIB APFLIB VADD; do
  python3 apo_decode.py "fps100_archive/fps100sw/[327,010]${lib}.APO" \
    > "apo_decoded/${lib}.dis"
done
```

Decoder source: `../apo_decode.py` (~180 lines of self-contained
Python; no dependencies beyond the standard library).
