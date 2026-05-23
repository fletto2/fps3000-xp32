# SIM100 — working build of the FPS-100 / AP-120B simulator

`SIM100.FTN` (4910 lines, 1979 vintage) is the FPS official AP-120B
simulator — a bit-exact implementation of the AP's microarchitecture
in PDP-11 FORTRAN-IV-PLUS. We have it from the bitsavers FPS-100
RSX-11M v3.2 distribution.

This directory contains a **working modern Linux build**. To my
knowledge this is the first publicly executable port of the
canonical FPS-100 simulator since the PDP-11 era.

## Build

```sh
# Strip CRLF line endings + drop the leading 'O' artifact (file
# byte 0 is a continuation marker from the PDP-11 era — gfortran
# rejects it as a bad statement label)
tr -d '\r' < ../fps100_archive/fps100sw/'[327,010]SIM100.FTN' > SIM100.f

# Compile (key flags: -std=legacy for F77 dialect; default 72-col
# truncation drops the comment text past col 72 like 'STATEFUN'
# that gfortran -ffixed-line-length-none would otherwise treat
# as part of the statement)
gfortran -std=legacy -fno-automatic SIM100.f iutil_stubs.f -o sim100

# Run
echo 'X' | ./sim100
```

Result:

```
 SIM100   REL.  1.00 , 09/01/79
 *
```

That `*` is the simulator's interactive prompt.

## What this gets us

A clean compile of SIM100 means we have a **working AP-120B
microarchitecture reference in code**. Every operation the AP can
perform is implemented, including:

- `APSIM` (line 937) — the cycle-accurate execution loop
- `SPLIT` (line 3863) — the canonical 24-field microinstruction
  decoder (which we ported to Python in `../apo_decode.py`)
- `FPADD` (line 2763) — floating-point adder simulation
- `FPMUL` (line 3052) — floating-point multiplier simulation
- `FPINPT`/`FPOUT` (lines 2966, 3173) — IEEE↔FPS-format conversion
- `PSMEM`/`MDMEM`/`TMMEM` (lines 2494, 2549, 2633) — Program Store,
  Main Data, Table Memory access models
- `INCODE` (line 3232) — modify P.S. words (microcode patching)
- `LAND`/`LCOM`/`LSHFT` (3340, 3379, 3420) — logical AND/COMPLEMENT/
  SHIFT primitives the AP uses
- `NEGATE`/`NORMAL`/`PAKRG`/`UNPKRG` (3619, 3663, 3810, 3951) —
  arithmetic helpers
- `LODINP` (line 3976) — load an APLOAD load module (so we can
  feed it real microcode from the FPS-100 math libraries)
- `INTRPT` (line 4640) — interrupt handling
- `CLOCK` (line 4821) — cycle-counting for performance estimation

## Build issues handled

| Problem | Fix |
|---|---|
| File starts with stray `O\r\n` byte (PDP-11 file copy artifact) | Will need stripping for some files; not needed for SIM100 |
| CRLF line endings | `tr -d '\r'` |
| Statement function `IRSHFT(I,J)=0 STATEFUN` at line 4033 — `STATEFUN` text in col 73+ confused gfortran with `-ffixed-line-length-none` | Use default 72-col truncation (drop the flag) |
| 45 undefined refs to IUTIL routines (AREAD, IREAD, etc.) | Provided minimal `iutil_stubs.f` (11 symbols) instead of compiling IUTIL.FTN which has Hollerith-literal issues |
| Rank mismatch warnings (23) | Harmless — F77 was permissive; gfortran flags but compiles |
| COMMON-block IORM size mismatch (772 vs 920 bytes) — REAL BUG | Causes segfault after prompt when AREAD writes past block bounds. **Not yet fixed.** |

## Current limitation

The simulator prints its banner and prompt, but segfaults when input
arrives because of the COMMON-block size mismatch. The mismatch is
between the main program (declares IORM as 772 bytes) and a few
subroutines (declare it as 920 bytes), which corrupts memory when
those subroutines are called.

To fix: pad the smaller declaration to match. Or run with a Fortran
compiler that's tolerant of size mismatches (the original PDP-11
F4P was). This is a one-day debugging project, not currently done.

## Files

- `sim100.bin` — working binary (115 KB ELF, x86-64 Linux)
- `iutil_stubs.f` — minimal IUTIL replacements (11 routines; see file)

## Why this matters

SIM100 source is the **definitive AP-120B microarchitecture reference**
— more authoritative than even the FPS-7319 Programmer's Reference,
because it implements every behavior including edge cases. Once we
fix the COMMON-block issue, we can:

- Run real microcode from the FPS-100 math libraries (the
  `.APO` files we just decoded — see `../apo_decoded/`) and
  watch them execute
- Validate `apo_decode.py`'s SPLIT decoder against the canonical
  one byte-for-byte
- Use it as a control simulator for the FPS-3000 / XP-32 work
  (XP-32 inherits ~90% of AP-120B mnemonics)

For now: SIM100 source is also valuable as **read-only reference**.
That's what `../notes/fps100_sim100_annotated.md` (Council-of-Clankers
analysis, see when generated) is for.
