# FPS-3000 Architecture

This document captures the canonical architecture of the FPS-3000 array
processor, with primary sources cited. All claims here trace back to:

- **Hockney & Jesshope** (1988), *Parallel Computers 2*, §2.5 "The FPS
  AP-120B and Derivatives", pp.205–244 — `FPS3000_fps.pdf`
- **Curington & Tracy** (1984), "Performance Estimation Methods for XP32
  MAXL", FUSE conference paper —
  `FPS5000_Curington_-_Performance_Estimation_Methods_for_XP32_MAXL_1984.pdf`
- The disassembled CP firmware (this repo's `fps3k_custom.asm`)
- Card photographs:
  https://github.com/Nakazoto/FloatingPointSystems/tree/main/FPS%203000/Cards

## 1. The FPS family

Floating Point Systems Inc. (Beaverton OR, founded 1970) built attached
floating-point processors for minicomputers. The lineage:

```
1976  AP-120B          first product, 12 Mflop/s, 38-bit FP, ~28 boards
                       horizontal microcode (64-bit microword), 167ns clock
1978  FPS-100          AP-120B compressed onto 10 boards, 250ns clock
1981  FPS-164          64-bit, designed 1979 with Schottky-TTL MSI
                       (~2000 chips, 7 boards, 760W per Charlesworth 1986)
1983  XP-32 (FPS-5000) IEEE 754 32-bit, single-board AC, 6 MHz
                       Am29116 EU sequencer + Weitek FP chips + Am2168 SRAMs
1985  FPS-164/MAX      matrix accelerator boards: Weitek WTL 1264/1265
                       + ADI ADSP-3210/3220, ADSP-1401 program sequencer
1986  FPS-264          ECL FPS-164, 38 Mflop/s
```

**Sequencer-chip identification differs by generation.** The original
FPS-164 (1979/1981) and FPS-264 (1986) both predate or sidestep the
Am29116 — they use Schottky-TTL MSI control logic. The FPS-164/MAX
boards use ADSP-1401 as program sequencer. Only the FPS-3000 EXEC
card (1983) carries an Am29116 in this family. See
`fps164_chip_identification.md` for the full chain and references.

The **FPS-3000** is an FPS-5000-class entry-level system: a single
**Control Processor** (the M68KVM02 SBC running this ROM) plus 1–4
**XP-32 arithmetic coprocessors**, all on a VersaBUS backplane sharing a
**System Common Memory (SCM)**.

**The specific FPS-3000 we have** (Lovett's, system model
`FPS 3000` / system P/N `833-2003-004` REV B, S/N `FAS 20282`,
120VAC 1ph 15A 50/60Hz per the back-panel data plate
`refs/FPS-3000/fps-3000-sn.jpg`; chassis index-plate photo
`refs/FPS-3000/fps-3000.jpg`, model `821-9008-011`) is a **14-slot
chassis populated as a 2-AC configuration**: AP I/F + FMT + VBUS XLTR
+ VBUS SBC (slots 11-14), 2 × XP-32 AC each as ARITH+EXEC pair
(slots 7-10), MEM CTL (slot 6), and 5 × MEMORY (slots 1-5). The SBC
firmware exposes 4 channels (`TCBXP1I..XP4I`) for the family's
larger variants; only AC1 and AC2 are populated in this hardware.

Card-level P/Ns confirmed for Lovett's chassis (slot → card → FPS
engineering P/N, where read):
| Slot | Card | P/N | Note |
|---:|---|---|---|
| 11 | AP I/F | `612-4448-401-F` | host-bus variant unidentified |
| 10/8 | XP-32 EXEC | `612-4805-002` | Am29116 + EU PROM |
| 9/7 | XP-32 ARITH | `612-4806-002` | FP pipes |
| 4 | MEMORY | `612-4456-461` | per cardcage-photo label |
| 5 | MEMORY | `612-4498-401-A` | per index-plate |

**Status (2026-05)**: Lovett has the chassis-side AP I/F (slot 11)
but the **host-side AP I/F card and its cable are missing**. So
the chassis can boot and run its self-tests but cannot
communicate with any host computer until the host-side card is
sourced or substituted. See `ap_if_card.md` for the three
realistic paths forward.

## 2. System block diagram (the layout webp)

```
                       ┌────────────────────┐
                       │   VersaBUS SBC     │  ← 68K Control Processor
                       │   (this ROM)       │     M68KVM02 board
                       └─────────┬──────────┘
              ┌──────────────────┴─────────────┐
              │      VersaBUS (16-bit)         │
              └─────┬───────────────────┬──────┘
                    │                   │
        ┌───────────▼────────┐    ┌─────▼──────┐
        │  VersaBUS XLTR     │    │   AP I/F   │ ──► Host computer
        │ (16↔32-bit bridge) │    │            │     (PDP-11/VAX/IBM)
        └───────────┬────────┘    └────────────┘
                    │
        ┌───────────▼────────┐
        │     UNIV FMT       │   ← format converter
        │ (int↔IEEE-754, etc)│     for legacy/host interop
        └───────────┬────────┘
                    │
              ┌─────┴───────────────────────────┐
              │  XP32 BUS (32-bit IEEE-754)     │
              └────┬────────────┬───────────┬───┘
                   │            │           │
            ┌──────▼─────┐  ┌───▼────┐  ┌───▼─────┐
            │ XP32 ARITH │  │MEM CTRL│  │MAIN DATA│
            │  (Weitek + │  │        │  │  (SCM)  │
            │   AMD glue)│  │        │  │         │
            └─────┬──────┘  └────────┘  └─────────┘
                  │ × 4 parallel paths
            ┌─────┴──────┐
            │ XP32 EXEC  │  ← writable control store + Am2900 sequencer
            │ (microcode │
            │  runs here)│
            └────────────┘
```

8 cards = 8 diagram blocks, one-to-one. This is essentially the AP-120B
(Figure 2.39 in Hockney/Jesshope) re-partitioned across a VersaBUS
backplane, with the 68K SBC replacing the AP-120B's S-pad integer ALU
and host-interface logic.

## 3. XP-32 internals (from Hockney p.240, Figure 2.53)

The XP-32 in the FPS-3000 is **two VersaBUS cards** (per Usagi's
slot card and the Nakazoto photos): an EXEC card (612-4805-002) and an
ARITH card (612-4806-002). The cards are described in Hockney's
*Parallel Computers 2* §2.5 as a single integrated unit, but on the
FPS-3000 the integer/sequencer side and the floating-point side live
on separate VersaBUS cards that talk over the chassis backplane.

```
                                    To CP and SCM (system common memory)
                                              ▲
                                              │
  ┌────────────┐  ┌────────────┐  ┌─────────────────────────────────┐
  │    TCM     │  │    LMD     │  │  Executive Unit (EU) — EXEC card│
  │ 4K × 32    │  │ 16K × 32   │  │   AMD Am29116DCB sequencer      │
  │ RAM        │  │ RAM        │  │   (16-bit bipolar µP)           │
  │ 2 banks    │  │ 2 banks    │  │   + Am2168 SRAM array (program) │
  │ (table     │  │ (local main│  │   + PALs (decode logic)         │
  │  coef mem) │  │  data)     │  │                                 │
  └─────┬──────┘  └─────┬──────┘  └────────────┬────────────────────┘
        │               │                      │
        ▼               ▼                      ▼
      ┌─┴──┐          ┌─┴──┐            ┌──────────────────────────┐
      │ ×  │ ◄── Logic-Devices         │  Arithmetic Unit (AU)    │
      │ M  │     L29C520 16×16          │  — ARITH card            │
      └─┬──┘     CMOS MAC × 4+          │  Large CPGA chip         │
        │                                │  (likely Weitek WTL-     │
      ┌─┴──┐ ◄── (large CPGA, part#     │   1064/1065 family,       │
      │ +  │      under metal lid —     │   32-bit IEEE FP)        │
      │ A  │      probably Weitek FP)   │  + Am2168 SRAM (control  │
      └────┘                            │     store / regs)        │
                                        │  + bipolar PROMs (FP fan-│
                                        │     out lookup tables)   │
                                        │  + PALs                  │
                                        └──────────────────────────┘
```

### Memory hierarchy (per XP-32 channel)

| Memory | Size | Role | Storage |
|---|---|---|---|
| EU control store | 2K × 80 bit | Am29116 sequencer program | **bipolar PROM** — fixed mask, on EXEC card |
| AU control store (WCS) | 4K × 128 bit, 4 banks | FP-pipeline microcode | **Am2168 SRAM** — writable, host-uploaded |
| TCM | 4 K × 32 bit, 2 banks | Table/coefficient memory (sin/cos for FFT) | RAM |
| LMD | 16 K × 32 bit, 2 banks | Local Main Data (operand workspace) | RAM |
| SCM | 0.25–1 M × 32 bit | System Common Memory (off-card, shared) | RAM |

Confirmed against Hockney & Jesshope figure 2.53 (XP-32 internal
architecture). The earlier draft of this file claimed the EU was
also SRAM and that no fixed PROM existed — that was wrong; the
FPS-3000 EXEC card *does* carry the EU PROM (separate from the
white-labelled PALs that handle decode logic). The white-label
chips were misidentified as PROMs in an even earlier pass; both
mistakes are now fixed.

The SBC's microcode upload path is therefore **AU-only**: the
64 KB staging buffer at `0x10000–0x1FFFF` exactly equals one
4K × 128-bit AU WCS bank. The EU is already alive at power-on
(running its mask PROM) — without that, the panel-command
interface that the SBC drives wouldn't have anything to talk to.

### Microcode word widths

The "128-bit microinstruction" and "80-bit EU instruction" sizes from
Hockney are the canonical FPS-5000 family numbers and are most likely
still right for the FPS-3000 — but the *storage* of those words is
SRAM here, not PROM. Combined microinstruction bits (estimated):

| Functional unit | Bits |
|---|---|
| Am29116 sequencer instruction | 16 |
| Memory addressing (TCM/LMD/SCM) | 16 |
| Register file selects (DPX/DPY) | ~16 |
| FP pipeline control (multiplier + adder) | ~32 |
| Branch / condition / sequencer | ~16 |
| Bus/IRQ control | ~16 |
| Spare / parity | ~16 |
| **Total per microword** | **~128** |

This is true horizontal microcode — one microinstruction per clock,
controlling every functional unit at once. With 6 MHz clock × 12 useful
operations per microword the peak rate works out to the published
~12 Mflop/s per XP-32 (6 Mflop/s per pipeline × 2 pipelines).

### Critical numbers for the upload path

```
1 WCS bank = 4096 microinstructions × 128 bits
           = 4096 × 16 bytes
           = 65,536 bytes
           = exactly 64 KB
```

The CP SBC's upper DRAM region `0x10000–0x1FFFF` is **64 KB** — sized
exactly to hold one WCS bank. The S-record uploader streams microcode
into that buffer, then the panel-I/O command processor DMAs it across
the XLTR into one of the four AU control-store banks.

## 4. Floating-point chips

Hockney's text says **WTL-1032 multiplier** + **WTL-1033 adder**. Those
exact part numbers are not on bitsavers — only the **WTL-1232/1233**
pair appears in the public datasheet archive (July 1986).

Most likely these are the same chips. Either:
- "1032/1033" are the engineering-sample / first-revision part numbers
  (1983–84) renamed to "1232/1233" for general release (1986); or
- Hockney wrote them down slightly wrong from his FPS contact.

The 1232/1233 datasheet on bitsavers
(http://bitsavers.org/components/weitek/dataSheets/WTL-1232_1233_Floating_Point_Multiplier_and_ALU_Jul86.pdf)
describes:

- **WTL-1232**: 32-bit IEEE-754 single-precision FP multiplier, single
  chip, pipelined. Drop-in for AP-120B's three-board multiplier.
- **WTL-1233**: matching 32-bit IEEE-754 FP ALU (add/subtract + format
  conversion + comparisons + AND/OR/XOR on the float bits).

The XP-32 uses one WTL-1232 multiplier and **two** WTL-1233 adders (per
Hockney p.240: "*The multiplier is now reduced to a single chip … namely
the 32-bit WEITEK WTL-1032. Similarly the floating-point adders each use
the WEITEK WTL-1033 floating-point ALU chip.*"). The XP-32 has two FP
add pipelines and one multiply pipeline, and Hockney measures the
adder pipelines as 5-stage and the multiplier pipeline as 5-stage.

## 5. AMD 29500-series

The "AMD bit-slice / microcode sequencers" in the XP-32 EXEC are the
**29500 series** — AMD's late-VLSI building blocks for microprogrammed
machines:

| Part | Function |
|---|---|
| Am29501 | 8-bit byte-slice multiport register file |
| Am29509 | 16-bit barrel shifter |
| Am29510 / Am29511 | floating-point support (formatter, normalizer) |
| Am29516 / Am29517 | 16×16 hardware multipliers |
| Am2910A | microprogram sequencer (carried over from earlier family) |

These sit between the WCS read port and the data-path control lines,
expanding 128-bit microwords into the dozens of clock-precise control
signals that drive the WTL-1232/1233 chips, address calculation, and
register-file routing.

## 6. Programming model — MAXL / XPMLIB / CPFORTRAN

(per Curington/Tracy 1984)

The FPS-5000 is programmed in three layers:

### Layer 1 — host program (any language, calls library)

Runs on the host (PDP-11/VAX/IBM). Calls "host interface routines" that
talk to the CP via the AP I/F. Documented set (Hockney p.241):

```
CPOPEN   open a CPFORTRAN program file on the host
CPLOAD   load it from host to CP
CPRUN    start CP program running
EXPUT    start host→FPS-5000 data transfer
EXGET    start FPS-5000→host data transfer
APWAIT   wait for transfer + CP program done
APWD     wait for data transfer only
APWR     wait for CP program only
```

### Layer 2 — CPFORTRAN (runs on the CP / 68K SBC)

A FORTRAN-77 subset that the CP executes. Its main job is sequencing
XP-32 operations: selecting an AC, dispatching XPMLIB calls, waiting,
moving data between SCM and LMD/TCM. Synchronization primitives
(running on the CP):

```
XPSEL    select an XP-32 for subsequent XP-control calls
XPRUN    start the selected XP-32 running its loaded program
XPWAIT   wait for selected XP-32 to finish
XPSTAT   obtain status of an XP-32
```

Data-transfer primitives (run on the XP-32 itself, scheduled by CP):

```
XPDMAR   SCM ↔ LMD DMA  (~2 Mop/s)
XTMDMA   SCM ↔ TCM DMA
XPISNC   wait for transfer (or arithmetic) to finish
```

### Layer 3 — MAXL programs (run on XP-32, from WCS microcode)

A FORTRAN-syntax language compiled to **XPMLIB calls**. Each XPMLIB
"function" is a pre-written microcode kernel that lives in the AU WCS;
the MAXL "compiler" essentially emits a sequence of *invoke kernel K
with arguments A,B,C,N* commands.

Documented XPMLIB routines (from Curington 1984 Table 1 + Hockney
p.242–243):

| Routine | Operation | Cycles startup | Cycles/point | r∞ Mflop/s |
|---|---|---|---|---|
| ZVCLR | vector clear | 20 | 0.5 | – |
| ZVMUL | vector multiply A·B → C | 19 | 1.5 | 4.0 |
| ZVDIV | vector divide | – | – | 0.5 |
| ZRFFT | real FFT (N=512) | 90 | 7.5 | – |
| ZSCLRF | scale FFT | 19 | 3.0 | – |
| ZCVMGS | convert/magnitude | 20 | 1.5 | – |
| ZVASM | vector add scalar mul: A·s + B | – | – | 11 |
| ZVSASM | one-vector triad: (A+b)·d | – | – | 12 |
| ZVASM | (B(J)) = s·B(J) + C(J) | – | – | 11 |
| ZVAM | all-vector triad: (A+B)·D | – | – | 6 |

A typical MAXL source looks like (Curington Fig 2):

```fortran
       SUBROUTINE SPECTR( INAD, NBLOCKS, OUTAD )
C$APMATH ZVCLR,ZVMUL,ZRFFT,ZSCLRF,ZCVMGS
       PARAMETER ( FROMXP=1, TOXP=2, NFFT=512, NINPUT=128 )
       INTEGER BUFFER, J, WORK, WINDOW
       DATA BUFFER,WINDOW,WORK / 0, 8192, 12288 /
C
       DO 600 J=1,NBLOCKS
         CALL XPDMAR( TOXP, BUFFER, 1, INAD, 1, FLOAT, NINPUT )
         CALL XPISNC
         CALL ZVCLR ( WORK, 1, NFFT )
         CALL ZVMUL ( BUFFER, WINDOW, WORK, NINPUT )
         CALL ZRFFT ( WORK, NFFT, 1 )
         CALL ZSCLRF( WORK, NFFT, 3, 1 )
         CALL ZCVMGS( WORK, BUFFER, NOUTPT )
         CALL XPISNC
         CALL XPDMAR( FROMXP, BUFFER, 1, OUTAD, 1, FLOAT, NOUTPT )
         CALL XPISNC
         INAD  = INAD  + NINPUT
         OUTAD = OUTAD + NOUTPT
600    CONTINUE
       RETURN
       END
```

The `C$APMATH` directive lists which XPMLIB kernels the program
needs — those become the WCS bank contents that get loaded.

## 7. Microcode upload path (full picture)

```
                    HOST COMPUTER
                  (PDP-11 / VAX / IBM)
                          │
                          │ (1) S-records over AP I/F
                          │     S0 header
                          │     S1/S2/S3 data records (16/24/32-bit addr)
                          │     S8/S9 end records
                          ▼
                  ┌───────────────────┐
                  │  VersaBUS SBC     │
                  │  (this ROM)       │
                  ├───────────────────┤
                  │ TCBRDHC main loop │  [F046F0]
                  │   ↓               │
                  │ panel-cmd dispatch│
                  │   ↓               │
                  │ SLC parser  [F04B68]
                  │   ↓               │
                  │ SRecordDataHandler│  [F051A2]
                  │   ↓ writes        │
                  │ SBC RAM           │
                  │ 0x10000–0x1FFFF   │  ← 64 KB staging buffer
                  │   = 1 WCS bank    │
                  └─────────┬─────────┘
                            │ (2) host issues panel command sequence:
                            │     XPSEL (select-channel)
                            │     XPDMAR with TOXP direction, count=4096*16,
                            │     FLOAT type, src=staging buffer, dest=WCS
                            ▼
                  ┌───────────────────┐
                  │ PanelIOCommand    │  [F05688]
                  │  - writes 0xFF0204│  channel select
                  │  - 0xFF0214 data  │
                  │  - 0xFF0218=0x400 │  arm DMA
                  │  - poll 0xFF0218  │  bit 15 = ready
                  └─────────┬─────────┘
                            │
                            ▼
                ┌─────────────────────┐
                │   VersaBUS XLTR     │
                │   (16↔32 bridge)    │
                └─────────┬───────────┘
                          │
                          ▼
                ┌─────────────────────┐
                │     UNIV FMT        │  (transparent for opaque
                │                     │   microcode words)
                └─────────┬───────────┘
                          │
                          ▼
                ┌─────────────────────┐
                │  XP32 BUS  →  WCS   │  one of 4 banks now loaded
                │            write port│
                └─────────────────────┘
                          │
                          ▼
                  XP-32 EXEC ready to execute
                  AU pipeline microcode for whatever
                  XPMLIB kernels were just uploaded
```

After load, the host (or CPFORTRAN program) issues XPRUN to start the
EXEC fetching from WCS at the kernel entry point, then XPWAIT/XPISNC
until done.

## 8. What's *not* in this ROM

These all live elsewhere (uploaded at runtime, on the XP-32 card itself,
or on the host):

- ❌ **AU control-store microcode** — the actual ZVMUL/ZRFFT/etc.
  kernels. Uploaded fresh per workload. Stored in 128-bit-wide SRAM
  (Am2168 array) — 4K × 128 × 4 banks of writable WCS.
- ✓ **EU control-store microcode** — the Am29116 sequencer's program
  *is* on the board, in a fixed bipolar PROM array (per Hockney
  fig. 2.53: 2K × 80-bit). Already alive at power-on; the SBC ROM
  never uploads it. The white-labelled chips earlier mistaken for
  this PROM are PALs.
- ❌ **Any IEEE-754 arithmetic in software** — done by WTL-1232/1233
  hardware under microcode control. The 68K never adds/multiplies floats.
- ❌ **MAXL compiler** — runs on the host development system; emits the
  WCS image + CPFORTRAN program.
- ❌ **CPFORTRAN runtime** — likely loaded into SBC RAM via CPLOAD; not
  resident in this ROM. (The ROM is a generic CP firmware that only knows
  the panel/XLTR primitive set; CPFORTRAN sits above that.)
- ❌ **XP32-side addressing logic** — encapsulated in the XLTR's
  per-channel state, never named directly by SBC code.

## 9. Reinterpreting the prior versabus project's labels

The prior project at `~/src/claude/versabus/fps3k_combined.asm` is
correct in its function-level structure but consistently mislabels the
peripherals. Translation table when reading that file:

| Prior label (wrong) | Actual meaning |
|---|---|
| "fire panel I/O" | AP I/F + VersaBUS XLTR command interface |
| "fire detection loop" | XP-32 channel |
| "expansion channel" | XP-32 channel (XP-prefix is literal) |
| "loop microcode" | AU WCS microcode (128-bit horizontal) |
| "host code upload" | microcode bank staging |
| "panel command processor" | XLTR command primitives (XPSEL/XPDMAR/etc.) |
| "TCBRDHC" = Read/Drive Channel | Master / dispatch task on CP |
| "TCBIO1I" = I/O Channel 1 | AP I/F host link |
| "TCBXPnI" = Expansion Channel n | XP-32 controller for AC channel n |
| Per-channel "data registers" at 0xFF00xx | Per-channel XLTR data ports |

## 10. RMS68K kernel data-structure tags

ROM contains a set of 4-byte ASCII signatures (`!XXX`) used by RMS68K
and by FPS-specific kernel additions to mark in-RAM data structures.
The init routines for these are at `0xF09E80–0xF0A04E`; each one
allocates RAM via `TRAP #0` directive 4, zeroes it, writes its tag at
offset 0, then fills size/count fields.

| Tag    | Init routine              | Purpose |
|--------|---------------------------|---------|
| `!TCB` | (multiple TCBs in TCBDef) | Task Control Block — RMS68K canonical |
| `!CCB` | `0xF03EF0`                | Channel Control Block — RMS68K canonical |
| `!ASQ` | (multiple sites)          | Application Status Queue — RMS68K canonical |
| `!TST` | `0xF0298C`                | Task Status / Test record — RMS68K canonical |
| `!DLY` | `0xF02D9A`                | Delay record — RMS68K canonical |
| `!VCT` | `0xF09C9C`                | Vector / config table (FPS-specific?) |
| `!GST` | `Init_GST_StoreTag` (`F09E88`) | Global System Table |
| `!UST` | `Init_UST_StoreTag` (`F09ECE`) | User System Table |
| `!IOV` | `Init_IOV_StoreTag` (`F09F52`) | I/O Vector |
| `!IDV` | `Init_IDV_StoreTag` (`F09F80`) | Interrupt Descriptor Vector |
| `!PAT` | `Init_PAT_StoreTag` (`F09FB2`) | Pattern table |
| `!UDR` | `Init_UDR_StoreTag` (`F0A000`) | User Driver record |

Each init routine follows the same template (clearest at GST):

```
movea.l <config_ptr>, A0     ; pointer to config descriptor in ROM
trap   #0  ; D0=4            ; RMS68K MEMALLOC syscall
move.l  A0, <global>          ; save allocated block ptr
bsr     MemoryClear           ; zero the block
move.l  #'!XXX', (A0)         ; write magic tag at +0
move.w  #1,    8(A0)          ; version/flags
move.w  D2,   $A(A0)          ; size in bytes
divu.w  #N,   D2              ; entries = size / record_width
move.w  D2,   $C(A0)          ; entry count
lea     $14(A0), A2           ; first record after 0x14-byte header
move.l  A2,   $10(A0)         ; pointer to record array
```

The record-width divisor differs per table (`$12` for GST, `$16` for
UST, etc.) — that's the per-table record size in bytes.

## 11. Context strings in TCBs and dispatch tables

In addition to the `!XXX` tags above, the ROM uses 4-letter ASCII
identifiers as fixed fields inside TCB and configuration records:

| String | Use |
|--------|-----|
| `EXEC` | Executive identifier |
| `USER` | User-context identifier (per-task user state) |
| `STCK` | Stack-context identifier |
| `UPGM` | User Program identifier |
| `PROG` | TCB terminator (marks end of a TCB record) |
| `RDHC` | Master/dispatch task name (`TCBRDHC`) |
| `IO1I` | Host I/O channel task name (`TCBIO1I`) |
| `XP1I`..`XP4I` | XP-32 channel 1-4 task names (`TCBXP1I..TCBXP4I`) |
| `AS0f`..`AS3f` | Application-Specific function tables |

