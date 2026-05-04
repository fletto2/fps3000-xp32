# FPS-100 / AP-120B microcode corpus — quantitative analysis

Stats taken across all 217 routines / 21,066 microinstructions in
`*HSR.MAC`, decoded with `hsr_disassembler.py` (decoder cross-checked
against FPS-7319 Programmer's Reference Manual Part 2, official field
tables).

**Decoder coverage: 98.9%** (20,840 / 21,066 instructions produce a
fully-named symbolic form with no `?` markers).

## What does AP-120B microcode actually do?

### S-Pad operation distribution

| `SOPF` value | Mnemonic | Count | % |
|---|---|---:|---:|
| 0 | SOP1 (single-op) | 9,873 | **47.4%** |
| 4 | MOV | 4,413 | 21.2% |
| 2 | ADD | 3,292 | 15.8% |
| 1 | B (bit-reverse class) | 1,887 | 9.1% |
| 3 | SUB | 1,195 | 5.7% |
| 5 | AND | 101 | 0.5% |
| 6 | OR | 84 | 0.4% |
| 7 | EQV | 2 | 0.0% |

Almost half of all microinstructions invoke the S-Pad single-op
group. Within that group:

| `SOP1` | Mnemonic | Count | % of SOP1 |
|---|---|---:|---:|
| 0 | NOP | 5,528 | 56.0% |
| 16 | **LDSPI** (load S-Pad immediate) | 1,598 | 16.2% |
| 12 | **DEC** | 1,134 | 11.5% |
| 11 | **INC** | 857 | 8.7% |
| 10 | CLR | 260 | 2.6% |
| 15 | LDSPE | 112 | 1.1% |
| 13 | COM | 107 | 1.1% |
| 14 | LDSPNL | 104 | 1.1% |

(LDSPNL = "load S-Pad no-load" — sets up address register without
copying value.) The dominance of `LDSPI`/`INC`/`DEC` matches the
expected pattern: address-register setup + iteration counter
stepping in tight loops.

### Adder usage

| `FADDF` | Mnemonic | Count | % |
|---|---|---:|---:|
| 0 | FADD1 (single-op selector) | 13,346 | 64.0% |
| 3 | **FADD** | 4,346 | 20.8% |
| 2 | **FSUB** | 1,300 | 6.2% |
| 7 | I/O field group | 901 | 4.3% |
| 1 | FSUSR (subtract-reverse) | 772 | 3.7% |
| 5 | FAND | 160 | 0.8% |
| 6 | FOR | 20 | 0.1% |
| 4 | FEQV | 2 | 0.0% |

The adder is the busiest FP unit (idle as a "single-op" filler in
64% of instructions but actively adding/subtracting in 31%).

### Multiplier usage

`FMF` (multiplier fire) bit set in **5,267 / 21,066 instructions =
25.0%** — exactly one multiply per four cycles on average. With the
3-stage multiplier pipeline depth, that's near the architectural
maximum throughput.

### Branch usage

| `CONDF` | Mnemonic | Count | % |
|---|---|---:|---:|
| 0 | (no branch) | 15,803 | **75.8%** |
| 2 | BR (unconditional) | 1,180 | 5.7% |
| 7 | RETURN | 861 | 4.1% |
| 1 | IF | 854 | 4.1% |
| 14 | BEQ | 551 | 2.6% |
| 15 | BNE | 459 | 2.2% |
| 17 | BGT | 359 | 1.7% |
| 16 | BGE | 217 | 1.0% |

So 76% of instructions are straight-line (typical of horizontal
microcode that scheduled compactly). The remaining 24% are:
~6% unconditional branches, ~4% returns, ~4% IF (single-instruction
predicate), ~10% conditional branches.

### Memory addressing usage

`MAF` (memory address function):
- 66.6% no-op
- 19.9% **SETMA** (load main-memory address from SPFN)
- 10.7% **INCMA** (auto-increment)
-  2.8% DECMA

`DPBSF` (data-pad bus select):
- 69.3% ZERO (idle)
-  9.5% MD (memory data — pipeline staging)
-  7.6% **VALUE** (16-bit immediate from bits 48-63)
-  5.8% DPX
-  2.9% SPFN, DPY each
-  2.0% TM (table memory — sin/cos for FFT)

### Bit-reverse flag (`B` / `DF`)

Set in **121 / 21,066 = 0.6%** of all instructions. As expected —
this is the bit-reverse-mode flag for FFT addressing, used only in
the FFT family of routines.

## Most-common microinstruction patterns

The 20 most-common full symbolic forms across the corpus:

| Count | Pattern |
|---:|---|
| 452 | `RETURN 0` |
| 318 | `FMUL TM,MD` (multiplier inner loop) |
| 275 | `FADD A1=NC,A2=NC` (adder pipe push, no new operands) |
| 219 | (all zeros, padding) |
| 121 | `INCMA` (bare memory-address increment) |
| 118 | `SPMOV R0,R0; SETMA` (NOP-class instruction, setup memory addr) |
|  73 | `LDREG.LDTMA; FMUL FM,FA; RETURN 0; DP[DPX2,...,XW=5]; #010001` (return-with-pipeline-fold) |
|  70 | `SPMOV R2,R2; SETMA` |
|  67 | `BGT 22` |
|  67 | `IF 1; DP[DPY1,DB=VALUE]; #000000` |
|  67 | `RETURN 0; WMD<FA; INCMA` (return with pipelined memory write) |

The pattern at #7 above is fascinating — 73 occurrences of an
identical 5-field combined instruction across the corpus. That's
the **canonical "tight inner-loop body fold" idiom**: simultaneous
register load (`LDTMA`), multiply-fire (`FMUL FM,FA`), conditional
return (`RETURN 0`), data-pad write (`XW=5`), and immediate. One
horizontal microinstruction doing the work of 5 RISC-style
instructions. This is what 64-bit horizontal microcode is *for*.

## Per-library size distribution

| Library | Routines | Total μinsts | Avg per routine |
|---|---:|---:|---:|
| `AMLLIB` | 23 | 3,789 | 164 |
| `BAALIB` | 88 | 2,511 | 28 |
| `BABLIB` | 60 | 3,255 | 54 |
| `DGNLIB` | 7 | 562 | 80 |
| **`IPRLIB`** | 11 | **3,388** | **308** |
| **`SIGLIB`** | 27 | **7,560** | **280** |
| `UTLLIB` | 1 | 1 | 1 |

`IPRLIB` (2-D operators incl. FFT2D) and `SIGLIB` (signal
processing incl. 1-D FFT family) have the largest per-routine
average. `BAALIB` has many small vector ops. `EIGRS` (eigensolver,
582 μinsts) is the largest single AML routine.

### Top 10 longest routines

| μinsts | Library | Routine |
|---:|---|---|
| **1,336** | SIGLIB | `CPSTRM` (complex power spectrum?) |
| **1,326** | SIGLIB | `UNWRAP` (phase unwrap) |
|   718 | SIGLIB | `ENVEL` (envelope detector) |
|   709 | IPRLIB | `ERFFT2` (FFT2 of real input) |
|   632 | IPRLIB | `RFFT2D` (2-D real FFT) |
|   582 | AMLLIB | `EIGRS` (eigensystem real symmetric) |
|   579 | SIGLIB | `HLBRT` (Hilbert transform) |
|   561 | SIGLIB | `CCORF` (complex cross-correlation forward) |
|   535 | SIGLIB | `ACORF` (auto-correlation forward) |
|   442 | AMLLIB | `FGEN` |

`CPSTRM` and `UNWRAP` at >1300 μinsts each are the largest single
microcode kernels in the FPS-100 distribution — both signal-
processing pipelines that include FFT + post-processing.

## How to read these stats

In modern terms, AP-120B microcode is **VLIW-ish horizontal**, with
each 64-bit instruction independently controlling **8 functional
unit groups in parallel**: S-Pad arithmetic (integer/address), Adder
(FP), Multiplier (FP), Branch, Data-Pad (X/Y register-file
read/write), DP-bus muxer, Memory-input mux, Memory/DP/TM address
update.

The statistics show that:
1. The compiler/programmer is good at packing — 47% of instructions
   *only* do an S-Pad op (the rest of the unit groups idle), but
   when work is being done, multiple groups fire together
   (the 73-occurrence "5-group fold" idiom is proof).
2. The adder is busier than the multiplier (31% vs 25%), reflecting
   that FP add is shorter pipe (2-stage) and easier to schedule.
3. Data-pad bus-select is "ZERO" 69% of the time — most instructions
   don't drive that path; it's reserved for explicit data-flow
   between functional units (multiplier output → adder input, etc).
4. SETMA fires 20% of the time — heavy memory traffic, as expected
   for FP scientific kernels operating on streaming vectors.

## Connection to the FPS-3000 / XP-32 inference

The XP-32 microcode is 128-bit (vs AP-120B's 64-bit) and adds a
second adder. We can now estimate **what the extra 64 bits hold**
based on what AP-120B actually USES:

- The FADD/A1/A2 group costs ~10 bits in AP-120B and would need to
  duplicate to ~10 bits for the second adder = +10 bits
- The DMA-controller field group (Curington 1986) needs ~5–10 bits
  — corresponds to a class of "I/O instructions" we can see in the
  AP-120B at FADDF=7 (4.3% of corpus, ~900 instructions). The XP-32
  promotes this from a sub-mode to a dedicated field group.
- Data-pad addressing widening (FPS-164 already added 6 XE/YE
  extension bits) suggests another +6 bits for XP-32
- IEEE-754 32-bit immediates (vs FPS proprietary 38-bit) likely
  preserve the 16-bit VALUE field but add separate exponent/mantissa
  loaders → +8 bits

That sums to **~30–40 bits of extra width going to identifiable
features**, leaving 24–34 bits for second-multiplier control,
multi-AC sync, EU↔AU coordination — consistent with the prior
"plausible filler" estimate in `xp32_opcode_clues.md` but now
backed by what AP-120B actually does in 21K real instructions.

## Caveats

1. The decoder treats SPEC sub-dispatch (SOP=0, SOP1=1, SPS=SPEC
   class) only at the class level — the within-class sub-op (e.g.
   STEST.BFLT vs STEST.BIFN) is recognized as the class but not
   the specific instruction. Filling that in is mechanical given
   the manual tables on E-3.
2. The I/O group (FADDF=7, ~900 instructions) is decoded by class
   (LDREG/RDREG/INOUT/CONTROL) but again sub-ops are class-named
   not full mnemonics. Same caveat.
3. Some opcode-modifier interactions (SH applied to single-op,
   double-precision FP modes) are recognized as fields but not
   composed into the canonical APAL syntax. They appear in the
   raw octal column for cross-reference.

These three could plausibly take the decoder from 98.9% to 99.9%
coverage with a couple of hours of additional manual table copy
from the AP-120B reference.
