# Hockney & Jesshope §2.5 — Technical Summary

> R.W. Hockney & C.R. Jesshope, *Parallel Computers 2: Architecture,
> Programming and Algorithms*, Adam Hilger / IOP Publishing, 1988,
> chapter 2.5 "The FPS AP-120B and Derivatives", pp. 206-244.
>
> **This is not a transcription** — the chapter is in copyright. What
> follows is a technical synthesis of the engineering content
> (specifications, architectural facts, performance numbers, API
> conventions) in our own words, with short verbatim quotes attributed
> where wording matters. For the full prose, read the original; for
> the engineering facts you need to model the hardware, this should
> suffice.

## What the chapter covers

The whole chapter is one section (§2.5) split into subsections:

- §2.5.1 — AP-120B history and physical form
- §2.5.2 — AP-120B architecture
- §2.5.3 — Implementation technology
- §2.5.4 — Instruction-set encoding
- §2.5.5 — Software stack (APEX, APAL, APLOAD, APSIM, APDBUG, VFC, AP FORTRAN)
- §2.5.6 — Performance modelling
- §2.5.7 — FPS-164 / FPS-264 (renamed M140/M30 and M60)
- §2.5.8 — FPS-164/MAX matrix accelerator (renamed M145)
- §2.5.9 — IBM /CAP loosely-coupled multiprocessor at Kingston / Cornell
- §2.5.10 — **FPS-5000 series — the family our FPS-3000 belongs to**

For our project the most directly relevant subsection is §2.5.10
(plus the XP-32 figure 2.53). §2.5.1-§2.5.6 supply ancestor context
that explains why the XP-32 design choices were made.

## 2.5.1-2.5.6 — AP-120B in brief

- Founded 1970 by C N Winningstad, Beaverton OR. ~4400 AP-120Bs
  shipped by 1985.
- AP-120B introduced 1976. Co-designers: George O'Leary and Alan
  Charlesworth. 12 Mflop/s peak (38-bit FP).
- AP-190L = mainframe-attach variant for IBM 370 etc.
- FPS-100 (1978) = cheaper, lower-power-Schottky-TTL repackaging of
  the same architecture; 4 MHz clock, 10 boards (vs 20 for AP-120B).
- Cabinet: 29 inches of EIA 19-inch rack space, ~160 lb, ~1.3 kW,
  air-cooled. Plugs into a 13-amp domestic socket.
- 28 etched-circuit boards, 10×15 inch, six-layer (3 signal + 3
  power planes for ±5/+12 V).
- Synchronous 167 ns clock period (6 MHz). Important property: the
  whole machine's state is reproducible clock-by-clock — no
  asynchronous timing uncertainties.

### Memory map (AP-120B, §2.5.2)

- **Program memory** — up to 4K × 64-bit, 50 ns cycle, Schottky bipolar
- **S-pad** — 16 × 16-bit registers (addresses, indices, loop counts)
- **Memory address registers** — MA, TMA, DPA, each 16-bit
- **Table memory** — up to 64K × 38-bit, 167 ns cycle, RAM or ROM
- **Data Pad X** — 32 × 38-bit
- **Data Pad Y** — 32 × 38-bit
- **Main data memory** — up to 1 Mword × 38-bit (plus 3 parity bits).
  8K or 32K modules, organised as even/odd bank pairs.
  - "Standard" 500 ns chip cycle → 333 ns interleaved
  - "Fast" 333 ns chip cycle → 167 ns interleaved

### Pipelines (§2.5.2)

- **Floating-point adder**: 2-stage, 333 ns latency. Stage 1 aligns
  fractions and adds; stage 2 normalises and rounds. Inputs A1, A2.
- **Floating-point multiplier**: 3-stage, 500 ns latency. Stages:
  start product of fractions / complete product / add exponents +
  normalise + round. Inputs M1, M2.
- Maximum result rate: 6 Mflop/s per pipeline, 12 Mflop/s combined.

### Floating-point format

- **38 bits**: 10-bit radix-2 exponent + 28-bit two's-complement
  mantissa. Range ~10^±153, precision ~8 decimal digits.

### Instruction encoding (§2.5.4) — 64 bits, 7 groups

Bit layout per Hockney figure 2.42:

```
Bits  0-13  S-pad group:    B, SOP, SH, SPS, SPD  (or SOP1/SPEC)
Bits 14-22  Adder group:    FADD, A1, A2          (or FADD1/I/O)
Bits 23-31  Branch group:   COND, DISP
Bits 32-50  Data-pad group: DPX, DPY, DPBS, XR, YR, XW, YW
Bits 51-55  Multiplier:     FM, M1, M2
Bits 56-63  Memory:         MI, MA, DPA, TMA
```

Hockney calls this **horizontal microcode** — one instruction
controls all 10 functional units per clock. This is why the FPS
"instruction" looks more like a microcode word than a CPU op.

S-pad operation codes (SOP, 3-bit):
- 0 → SPEC group (monadic, conditional, branch)
- 2 → ADD, 3 → SUB, 4 → MOV, 5 → AND, 6 → OR (NOR per source), 7 → EQUIV / XOR

(Maps exactly onto our recovered AP-120B microcode field layout in
`ucode_transcribed.py`.)

### Software stack (§2.5.5)

- **APEX** — executive on host, manages PS memory + program transfer
- **APAL** — assembler for AP-120B code
- **APLOAD** — links APAL object modules
- **APSIM / APDBUG** — host-side simulator + debugger
- **VFC** — vector function chainer (concatenates math-lib calls)
- **AP FORTRAN** — host-side compiler that targets AP code
- **SIGLIB** — signal processing routines
- **IMP** — image processing routines (2D FFT, convolution, filters)
- **AMLIB** — advanced maths (function generation, Runge-Kutta,
  sparse, eigenvalues)

### Performance formulas (§2.5.6)

For vector operations, Hockney expresses everything in his
(r∞, n_½) framework (asymptotic Mflop/s, half-performance length):

| Operation | Routine | r∞ (Mflop/s) | n_½ |
|---|---|---|---|
| Vector move | VMOV | 1.5 (3.0 fast) | 1 |
| Vector add | VADD | 1 (2 fast) | 1 |
| Vector mul | VMUL | 1 (2 fast) | 2 |
| Vector div | VDIV | 0.55 | 3 |
| Vector exp | VEXP | 0.2 | 0.3 |
| Dot product | DOTPR | 3 (6 fast) | 2 |

Only ~10% of the 12 Mflop/s peak is reachable on simple ops because
memory bandwidth = 36 Mword/s required vs 2-6 Mword/s available.
Programs with high computational intensity (≥4 flop/ref) reach much
higher fractions.

## 2.5.7 — FPS-164 (renamed M140/M30)

Larger machine introduced 1981. 5.5 ft tall, 2.5×7 ft footprint
(vs the AP-120B's 29-inch rack-space).

Architectural upgrades vs AP-120B (Hockney's list verbatim, slightly
re-formatted):

(a) 64-bit FP arithmetic instead of 38-bit
(b) 32-bit integer arithmetic instead of 16-bit
(c) 24-bit addressing → 16 Mword (was 16-bit / 64 Kword)
(d) 64-bit X/Y data pad registers (was 32-bit)
(e) 64 × 32-bit S-pad address registers (was 16 × 16-bit)
(f) 1024 × 64-bit instruction cache replaces program memory
(g) 256 × 32-bit subroutine return stack (was none)
(h) Main memory expandable from 0.25 to 7.25 Mword with memory
    protection (MDBASE / MDLIMIT registers)
(i) Table memory now 32 Kword RAM
(j) A real-time clock and a CPU timer (notably lacking on AP-120B)

Actual clock 182 ns (slightly slower than the AP-120B's 167 ns
nominal), giving 11 Mflop/s peak. Single-pipeline performance on
Livermore loops and LINPACK: 1-5 Mflop/s typical.

## 2.5.8 — FPS-164/MAX

Matrix Algebra eXtension, announced 1984 (Charlesworth & Gustafson
1986). Adds up to 15 MAX boards to a standard FPS-164. Each MAX
board has two pipelined Weitek FP units (8-stage multiplier + 8-stage
adder), broadcasts one operand from FPS-164 main memory to all 31
multipliers in parallel.

- Each board = 2 CPUs × (mult + adder) + local vector registers
  (4 × 2048 × 64-bit, broken into 4 vector registers of 2K each in
  v1; the spec allows 4K×4)
- Theoretical peak with 15 boards: **341 Mflop/s** (31 CPUs × 11 Mflop/s)
- Memory-mapped into the top 1 Mword of the FPS-164's 16 Mword
  address space (figure 2.49)

The instructions a MAX board executes (table 2.10):

| Operation | FORTRAN form | Mflop/s, 1 board | Mflop/s, 15 boards |
|---|---|---|---|
| Dot product | `S = S + A(I)*B(J(I))` | 22 | 341 |
| Complex dot product | `S = S + A(I)*B(I)` | 22 | 341 |
| VSMA | `A(J(I)) = S*B(J(I)) + C(I)` | 11 | 167 |
| VMSA | `A(J(I)) = B(J(I))*C(I) + S` | 11 | 167 |
| Vector mult | `A(J(I)) = B(I)*C(J(I))` | 5.5 | 83 |
| Vector add | `A(J(I)) = B(I) + C(J(I))` | 5.5 | 83 |

## 2.5.9 — IBM /CAP

Ten FPS-164s linked via channels (later FPSBUS, 22 MB/s) to two
IBM 4381 / 4341 hosts at Kingston laboratory (1985) and Rome.
Aggregate peak 110 Mflop/s (or 550 Mflop/s with 2 MAX boards each,
3.4 Gflop/s fully loaded). Performance dominated by communication
bandwidth — Hockney derives equations 2.23a/2.23b for channels vs
FPSBUS timing, intersect at p=9.78 (his figure 2.51).

## 2.5.10 — **FPS-5000 series (this is our chassis class)**

Announced 1983. MIMD multiprocessor based on the AP-120B
architecture. Hockney's overall figure 2.52:

```
                  Host (e.g. VAX)
                        │
                        ▼
                  CP   ── 0.25-1 Mword SCM ──┐  6 Mword/s
              (AP-120B 167 ns                │
              or FPS-100 250 ns)             │
              8 / 12 Mflop/s                 │
                        │                    │
                        ▼                    │
              ┌─────────┼─────────┬──────────┤
              ▼         ▼         ▼          ▼
              AC        AC        AC         IOP × n
              XP-32     XP-32     XP-32
              18 Mflop/s each
```

Up to **three XP-32 ACs** plus IOPs share a bus to a System Common
Memory (SCM, 0.25-1 Mword, 6 Mword/s bandwidth). The CP serves as
the host link AND can do useful arithmetic on its own.

Peak performance of largest announced (1983) config = FPS-100 CP +
3 XP-32 ACs = 8 + 3×18 = **62 Mflop/s theoretical**.

### XP-32 internal architecture (figure 2.53) — definitive

> "The architecture of the XP-32 coprocessor (figure 2.53) is similar
> in general concept to that of the AP-120B but differs in detail.
> A five-stage floating-point multiplier pipeline and **two** five-stage
> floating-point adder pipelines are connected by multiple data paths
> to a *local main data* (LMD) and a *table coefficient memory* (TCM).
> The LMD stores 16K 32-bit words arranged in two banks, and the TCM
> has 4K 32-bit words also arranged in two banks."  (p. 241)

> "Overall control of the XP-32 is exercised by the *executive unit*
> (EU) which can operate simultaneously with the *arithmetic unit*
> (AU), thereby providing for the parallel execution of I/O and
> address calculation with floating-point arithmetic. The EU performs
> all communication of programs and data between the AC and the CP
> and SCM. The AU performs arithmetic only on data in the local
> TCM and LMD memories."  (p. 241)

> "Microcode programs for the EU reside in *EU PROM*, which contains
> 2K 80-bit microinstructions. Similarly, microcode programs for the
> AU reside in a *writable control store* (WCS) of 4K 128-bit
> microinstructions, arranged in four banks."  (p. 241)

**Block-diagram fact sheet (figure 2.53):**

| Block | Spec | Notes |
|---|---|---|
| EU PROM | 2K × 80-bit | factory mask, not writable |
| EU | 24-bit ALU, 16 registers | program sequencer |
| Integer/Address unit | 16-bit, 32 registers | independent of FP |
| AU Control | drives multiplier + 2 adders | |
| AU WCS | 4K × 128-bit, 4 banks | **writable** — uploaded from host |
| LMD | 16K × 32-bit, 2 banks | local data memory |
| TCM | 4K × 32-bit, 2 banks | table memory (constants, twiddles) |
| Multiplier | 5-stage pipe, Weitek **WTL-1032** | IEEE 754 single |
| Adders | two × 5-stage pipe, Weitek **WTL-1033** | IEEE 754 single |
| Logic | AMD Am29500-series VLSI | bipolar |
| RAM | INMOS IMS-1040 static | |
| Clock | 6 MHz | 167 ns period |

The XP-32 dropped FPS's proprietary 38-bit format and adopted the
IEEE 754 32-bit single-precision standard. Hockney's p. 240
description has a typo: "a more precise mantissa equivalent to **33
bits**" should read **23 bits** (the explicit significand-field
width). With that correction the paragraph becomes internally
consistent — XP-32 mantissa precision is *less* than the AP-120B's
28-bit, traded for IEEE compliance and dynamic-range
standardisation. Confirmed by the WEITEK WTL-1032/1033 datasheet
in `refs/Weitek/WeitekDatasheet.pdf` page 7, which explicitly
diagrams the format as 1 sign + 8 exponent + 23 significand =
plain IEEE single. See `xp32_programming_model.md` §3 for the full
data-format discussion.

### SCM access protocol (page 241)

> "There is no direct connection between the arithmetic coprocessors.
> The coprocessors can only take data from and return results to the
> SCM, so that any communication between the ACs is by shared data
> in the SCM."

So AC↔AC communication is always SCM-mediated. The arbiter limits
any individual AC to half the SCM bandwidth (4-6 Mword/s) so that
two ACs can run concurrently; with three ACs, contention rises.

DMA priority scheme: ACs can DMA to SCM by "taking turns with the
CP" for available memory cycles.

### FPS-5000 software API — CPFORTRAN (page 241-242)

CPFORTRAN is a subset of FORTRAN 77. The full primitive set, per
Hockney's bullet list:

**(i) Host interface routines** (run on host):

| Routine | Purpose |
|---|---|
| CPOPEN | Open a CPFORTRAN program file |
| CPLOAD | Load a CPFORTRAN program file from host to CP |
| CPRUN | Start CPFORTRAN program running on CP |
| EXPUT | Start data transfer from host to FPS-5000 |
| EXGET | Start data transfer from FPS-5000 to host |
| APWAIT | Wait for data transfer and CP program to stop |
| APWD | Wait for data transfer to stop |
| APWR | Wait for CP program to stop |

**(ii) Synchronisation of ACs by the CP** (run on CP):

| Routine | Purpose |
|---|---|
| XPSEL | Select the XP-32 for subsequent XPWAIT |
| XPRUN | Start program running in selected XP-32 |
| XPWAIT | Wait for selected XP-32 to finish |
| XPSTAT | Obtain status of XP-32 |

**(iii) Data transfer to and from SCM** (run on XP-32):

| Routine | Purpose |
|---|---|
| XPDMAR | Transfer data between SCM and LMD |
| XTMDMA | Transfer data between SCM and TCM |
| XPISNC | Wait for transfer (or arithmetic) to finish |

XPDMAR/XTMDMA both run at r∞ = 2 Mop/s per Hockney.

**(iv) Arithmetic within the XP-32** — the XPMLIB primitives that
live as microcode in the AU WCS:

| Routine | What it does | r∞ (Mflop/s) | n_½ |
|---|---|---|---|
| ZVMUL(IA,IB,IC,N) | element-wise A*B → C | 4 | 33 |
| ZVDIV(IA,IB,IC,N) | element-wise A/B → C | 0.5 | 9 |
| ZVSASM(IA,IB,IC,ID,IC,N) | one-vector triad: C = (A+b)*d | 12 | 56 |
| ZVASM(IA,IB,ID,IC,N) | CDC 205-type two-vector triad: C = (A+B)*d | 8 | 37 |
| ZVAM(IA,IB,ID,IC,N) | all-vector triad: C = (A+B)*D | 6 | 28 |

### FPS-5320A benchmark measurements (Table 2.11)

> "The FPS-5320A computer which was used for the measurements
> comprises a control processor and either one or two XP-32 arithmetic
> coprocessors."  (p. 243)

This is the same chassis family as our FPS-3000.

| Operation | CP only | 1 XP-32 | 2 XP-32 | CP + 2 XP-32 |
|---|---:|---:|---:|---:|
| Dyad `Aᵢ = Bᵢ * Cᵢ` (VMUL/ZVMUL) | 1.5 Mflop/s | 4.0 | 8.0 | 9.2 |
| Triad `Aᵢ = (Bᵢ+s)*c` (VSASM/ZVSASM) | 3.9 | 12.0 | 24.0 | 27.7 |

n_½ values from same table:

| Operation | 1 XP-32 | 2 XP-32 | CP + 2 XP-32 |
|---|---:|---:|---:|
| Dyad | 470 | 1320 | 1545 |
| Triad | 1490 | 4200 | 4820 |

(The high n_½ values indicate substantial pipeline + synchronisation
startup; vectors need to be ~5000 elements to hit half-performance
on a 2-AC triad.)

### Performance constraint analysis (Table 2.12)

For ZVSASM with data flowing from SCM through LMD:

| Case | r̂∞ (Mflop/s) | f_½ |
|---|---:|---:|
| Sequential I/O | 12.5 | 4.2 |
| Overlapped I/O | 12.6 | 2.2 |

Overlapping XPDMAR with arithmetic halves the f_½ — i.e. doubles
the program's tolerance for low computational intensity.

## What this confirms about the FPS-3000 / our project

1. **WCS bank = 64 KB = SBC staging buffer** — Hockney's "4K × 128-bit"
   matches the SBC RAM region at `$10000-$1FFFF`. One S-record session
   = one bank.

2. **XPMLIB primitives in our SBC firmware** — XPSEL, XPRUN, XPWAIT,
   XPDMAR, XTMDMA, XPISNC, ZVMUL etc. all appear as documented panel
   commands / function entries.

3. **Two-stage data path** — host → SCM → AC (LMD/TCM/WCS). Our
   chassis-side `chassis_irq` / `XLTR_STATUS_IRQ` mechanism mediates
   the second stage.

4. **Performance ceiling** ~28 Mflop/s for our chassis (CP + 2 ACs
   on triads). Useful as a sanity bound when we get end-to-end
   execution working.

5. **The CP role being M68000 + RMS68K instead of AP-120B / FPS-100
   is a later-model adaptation** — the XP-32 ACs and the SCM bus
   protocol are unchanged from Hockney's description. The chassis
   interface our SBC implements is identical; only the CP CPU was
   modernised.

6. **The Weitek + AMD + INMOS chips on the EXEC/ARITH cards** match
   what Nakazoto / Usagi photographed exactly:
   - Am29116 ↔ Am29500 family (Hockney's "AMD 29500-series")
   - Am2168 / CY7C168 SRAMs ↔ IMS-1040 (both 4K × 4 static)

## Citation

R.W. Hockney, C.R. Jesshope. *Parallel Computers 2: Architecture,
Programming and Algorithms.* Adam Hilger (IOP Publishing), Bristol
& Philadelphia, 1988. Chapter 2.5 "The FPS AP-120B and Derivatives",
pp. 206-244. ISBN 0-85274-811-6 (paperback). Local copy:
`fps.pdf` in this workspace.
