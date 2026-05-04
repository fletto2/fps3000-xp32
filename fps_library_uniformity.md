# FPS math-library uniformity across the family

**Short answer:** Yes — the **Fortran-callable interface** is uniform
across AP-120B → FPS-100 → FPS-3000/5000 → FPS-164. The underlying
microcode and float format change every generation, but a host program
that calls `CVMUL(...)` on an FPS-100 will call essentially the same
routine, with the same argument pattern, on an FPS-5000.

## Calling convention

The canonical "FPS calling convention" is:

```
CALL <op>(vec1, stride1, vec2, stride2, ..., resultvec, stride, length)
```

Confirmed verbatim in the recovered FPS-100 `BAASRC.APS` source:

```
"****** CVADD = COMPLEX VECTOR ADD /FAST/ = REL 3.0, NOV 78 *****
"FORTRAN: CALL CVADD(A,I,B,J,C,K,N)
"APAL:    JSR CVADD
```

This is the same shape Hockney/Curington use for XPMLIB on FPS-5000
(`ZVMUL(A,1,B,1,C,1,N)`) and APMATH64 uses on FPS-164.

## Naming convention

Operation names break into **prefix** (float-format / data-type) +
**tail** (operation). The tail is shared across the family; only the
prefix changes:

| Prefix | Meaning | Where |
|---|---|---|
| (none) / `V` | scalar / vector, native float (38-bit FPS) | AP-120B, FPS-100 |
| `C` | complex (paired native float) | AP-120B, FPS-100 |
| `Z` | IEEE-754 32-bit | XPMLIB on FPS-3000 / FPS-5000 |
| `ZC` | IEEE-754 32-bit complex | XPMLIB |
| `D` | IEEE-754 64-bit | FPS-164 / APMATH64 |
| `T` / `TS` / `TR` | banded / tridiagonal solvers | shared across |

So `VMUL` (FPS-100) and `ZVMUL` (FPS-5000) and `DVMUL` (FPS-164) are
the **same operation, different float format**.

Examples of cross-generation tail-stability:

| Tail | FPS-100 (AP-120B) | FPS-5000 (XPMLIB) | FPS-164 (APMATH64) |
|---|---|---|---|
| `VADD` | `VADD`, `CVADD` | `ZVADD`, `ZCVADD` | `DVADD` |
| `VMUL` | `VMUL`, `CVMUL` | `ZVMUL`, `ZCVMUL` | `DVMUL` |
| `VMA` (mul-add) | `VMA`, `CVMA` | `ZVMA`, `ZCVMA` | `DVMA` |
| `VCLR` | `VCLR` | `ZVCLR` | `DVCLR` |
| `RFFT` | (in `FFT100.FTN`) | `ZRFFT` | `DRFFT` |
| `VMAGS` (mag²) | `CVMAGS` | `ZCVMGS` | `DCVMGS` |
| `VFLT` (int→fp) | `VFLT` | `ZVFLT` | `DVFLT` |

## Library packaging is also uniform

FPS-100 ships:

| Library | Contents |
|---|---|
| `BAALIB` | Basic Arithmetic — Batch A: vector add/sub/mul, complex ops, magnitudes |
| `BABLIB` | Basic Arithmetic — Batch B: max/min, logical ops, scaling, conversion |
| `IPRLIB` | Inner products / matrix products |
| `SIGLIB` | Signal processing (FFT family lives here) |
| `UTLLIB` | Utilities |
| `SYMLIB` | Symbolic / equation-solver primitives |
| `AMLLIB` | Applied math (eigensolvers, banded systems, etc.) |
| `DGNLIB` | Diagnostics |
| `APFLIB` | AP Fortran runtime |

XPMLIB on FPS-5000 reuses the same library breakdown with `Z`-prefixed
names. APMATH64 on FPS-164 collapses BAALIB+BABLIB into `MATH64`,
keeps `SIGLIB` etc. — same partitioning, mostly the same names.

## What this means for the FPS-3000 reverse-engineering effort

1. **The host-side software interface is already documented.** When
   we recover an XPMLIB kernel from disk or from a microcode dump,
   we already know what it should compute — the AP-120B `BAALIB`
   sources (we have these, in `fps100_archive/fps100sw/`) describe
   the algorithm a routine like `CVADD` implements.

2. **The MAXL programmer's view of the FPS-3000 is interchangeable
   with the FPS-100's APAL view.** Same Fortran calls, same argument
   conventions, same kernel-naming taxonomy. The difference is *what
   you can ask for*: ZVMUL is faster than VMUL because XP-32 has
   IEEE-754 hardware that FPS-100 does not.

3. **APMATH64 documentation (FPS-164, we have refs/FPS-164/) is
   directly relevant** even though FPS-164 is the *next* generation:
   the calling convention is identical, the operation taxonomy is
   identical, and APMATH64 Vol 2-4 lists each kernel's algorithm. So
   for any operation in the family, **at least one of the published
   FPS docs describes what it does** — even if no doc describes the
   FPS-3000 implementation specifically.

4. **The microcode is *not* uniform.** APAL (AP-120B) is 64-bit
   horizontal; XPMLIB (XP-32) is 128-bit horizontal; APMATH64 (FPS-164)
   is also 64-bit but with a different field layout. Recovering one
   doesn't directly let us read another. But the *scheduling logic*
   (e.g., how many cycles a multiply-add takes, where pipeline bubbles
   appear) carries family DNA — Hockney p.226 ff. is illuminating.

## Bottom line

When we eventually pull an XPMLIB kernel off a working FPS-3000 (or
extract one from the missing Bomem `BOM*` floppies, or from another
source), we won't be reverse-engineering it from scratch. We'll be
matching it against a documented Fortran-callable interface that's
been stable for 8+ years across the family, with full source for the
FPS-100 ancestor sitting in `fps100_archive/fps100sw/`.
