# How to make the XP-32 work — consolidated programming model

Everything we have, in one place, that bears on actually driving an
XP-32 arithmetic coprocessor: hardware spec, programming model,
microinstruction format, command protocol, math-library API, and
identified gaps.

Sources (in confidence order, highest first):

1. **Direct ROM reverse engineering** in this project — the SBC
   firmware that talks to XP-32 ACs. Highest confidence because
   it's executable code we've traced.
2. **Curington & Tracy 1984**, *Performance Estimation Methods for
   XP32 MAXL* (in `refs/FPS-5000/`). Highest-confidence published
   document about XP-32 software semantics.
3. **Hockney & Jesshope 1988** §2.5.10 + figure 2.53
   (in `fps.pdf`). Confirmed architectural facts; brief paraphrased
   summaries appear below.
4. **AP-120B / FPS-100 docs** in `refs/AP-120B/` — the ancestor of
   XP-32. Field layouts that did not survive into XP-32 are dropped;
   field layouts that did survive (S-Pad, Data-Pad, FALU, FMUL,
   memory) are documented as having been *inherited*.
5. **Nakazoto / Usagi photos** in `refs/FPS-3000/` — chip
   identification on the actual board.
6. **Consensus / inferred** material (multi-LLM cross-check). Stress-
   tested but unverified against silicon.

### Confidence markers used in this doc

After the calibration pass (May 2026), claims are tagged:

- **[V]** — verified by a primary source (datasheet, Hockney
  diagram, ROM reverse engineering, photo evidence)
- **[I]** — inferred: a short logical step from verified facts. Could
  be wrong but the reasoning is in the doc
- **[S]** — speculation: a guess we should not rely on without
  further evidence
- **[?]** — open question / unknown

Where a whole section's content shares one confidence level, the
marker appears in the heading. Where the level varies within a
section, individual claims are tagged.

## 1. System block diagram (what's in the chassis) [V]

Slot layout from the chassis index-plate photo
`refs/FPS-3000/fps-3000.jpg`. Bus widths from Hockney p. 241 + the
M68KVM02 manual.


```
┌────────────────────────────────────────────────────────────────┐
│ FPS-3000 chassis (Motorola VERSAbus, 14 slots)                 │
│                                                                │
│  Slot 14:  SBC      M68KVM02 — 68000 @ 8 MHz, this ROM         │
│            ⇅ VERSAbus                                          │
│  Slot 13:  XLTR     SBC↔XP32-bus translator                    │
│            ⇅                                                   │
│  Slot 12:  FMT      Universal Format card                      │
│            ⇅                                                   │
│  Slot 11:  AP I/F   host computer interface  ── cable ──→ Host │
│            ⇅                                                   │
│  Slot 10:  XP-32 EXEC (AC1)  ┐                                 │
│  Slot 9:   XP-32 ARITH (AC1) ┘   one AC = EXEC + ARITH card    │
│  Slot 8:   XP-32 EXEC (AC2)  ┐                                 │
│  Slot 7:   XP-32 ARITH (AC2) ┘                                 │
│            ⇅ XP-32 bus                                         │
│  Slot 6:   MEM CTL  controls 5-bank SCM                        │
│  Slots 1-5 MEMORY   SCM banks                                  │
└────────────────────────────────────────────────────────────────┘
```

**Two buses:** 16-bit VERSAbus (SBC ↔ everything on the CP side) and
the wider 32-bit XP-32 bus (XLTR ↔ XP-32 ACs ↔ SCM). The XLTR
bridges between them.

**Data path for arithmetic:** host → AP I/F (slot 11) → SCM (slots
1-5) → AC's LMD via XPDMAR → AU pipelines → back to LMD → back to
SCM → back through AP I/F → host. The SBC mediates SCM↔AC transfers
via panel commands through the XLTR.

**Data path for microcode upload:** host S-records → SBC staging
buffer (`$10000-$1FFFF`) → XLTR-mediated DMA → AU WCS bank N (4K×
128-bit). One S-record session = one bank.

## 2. The XP-32 internally (per Hockney figure 2.53) [V] / [I]

Memory sizes, bank counts, EU/AU split, and pipeline counts are
**[V]** from Hockney figure 2.53 + p. 241 text. The "AU data paths
(256-bit?)" annotation in the diagram below is **[S]** — Hockney
shows multiple data paths but doesn't specify their width.

```
                ┌─────────────────────────────────────────────┐
                │                XP-32 (one AC)               │
                │                                             │
   To CP/SCM ───┼──► EU (Executive Unit) ◄── EU PROM 2K×80    │
                │    │ Am29116 sequencer + integer/addr unit  │
                │    │   16-bit ALU, 32 × 16-bit registers    │
                │    ▼                                        │
                │    AU control unit                          │
                │    │                                        │
                │    │  ┌──────────────┐    ┌──────────────┐  │
                │    └──┤ TCM 4K × 32  │    │ LMD 16K × 32 │  │
                │       │ (constants)  │    │  (data)      │  │
                │       │ 2 banks      │    │  2 banks     │  │
                │       └───────┬──────┘    └───────┬──────┘  │
                │               │                   │         │
                │               ▼                   ▼         │
                │       ┌─────────────────────────────────┐   │
                │       │      AU data paths (256-bit?)   │   │
                │       └────┬────────────┬──────────────┘    │
                │            ▼            ▼                   │
                │       ┌─────────┐ ┌─────────┐ ┌─────────┐   │
                │       │WTL-1032 │ │WTL-1033 │ │WTL-1033 │   │
                │       │5-stage  │ │5-stage  │ │5-stage  │   │
                │       │MUL pipe │ │ADD pipe │ │ADD pipe │   │
                │       └─────────┘ └─────────┘ └─────────┘   │
                │             ▲                               │
                │             │                               │
                │       ┌─────┴──────┐                        │
                │       │ AU WCS     │                        │
                │       │ 4K × 128b  │                        │
                │       │ 4 banks    │                        │
                │       │ WRITABLE   │                        │
                │       └────────────┘                        │
                └─────────────────────────────────────────────┘
```

**Numbers:**

| Block | Size | Word width | Banks | Notes |
|---|---|---|---|---|
| EU PROM | 2K | 80-bit | 1 | mask-programmed, factory |
| EU integer/addr regs | 32 | 16-bit | — | Am29116-controlled |
| AU WCS | 4K | 128-bit | 4 | writable, host-uploaded |
| LMD | 16K | 32-bit | 2 (odd/even) | local main data |
| TCM | 4K | 32-bit | 2 | table coefficients (twiddles etc.) |

**Total WCS size**: 4096 × 128 × 4 = 2,097,152 bits = 256 KB.
The SBC's 64 KB staging buffer holds **exactly one bank**.

**Chip BOM:**

| Component | Part | Function | Source |
|---|---|---|---|
| EU sequencer | AMD Am29116 (or Am29C116 CMOS variant) | 16-bit bipolar µP, the EU brain | [I] Nakazoto photo ID |
| FP multiplier | WEITEK WTL-1032 (64-pin DIP or 68-pin LCC) | IEEE 754 32-bit single | [V] Hockney + datasheet |
| FP adder × 2 | WEITEK WTL-1033 (64-pin DIP or 68-pin LCC) | IEEE 754 32-bit single | [V] Hockney + datasheet |
| Logic glue | AMD Am29500-series VLSI | bipolar | [V] Hockney p. 240 |
| WCS SRAM | INMOS IMS-1040 [V] *or* Am2168 / CY7C168 [I] | 4K×4 static, ≤45 ns | [V] Hockney; Nakazoto photo varies |
| EU PROM | bipolar PROMs DIP-20, hand-labeled FPS PE-0071-xxx | factory-programmed | [I] Nakazoto photo ID |
| Decode PALs | DIP-24 custom-marked "29F52 SDC F" | combinational logic | [I] Nakazoto photo ID |
| TTL glue | 74F-series | | [I] Nakazoto photo ID |

**Pipeline-stage count discrepancy:** Hockney p. 240 describes the
XP-32 as having "a five-stage floating-point multiplier pipeline
and two five-stage floating-point adder pipelines." [V]. The
WTL-1032/1033 datasheet, however, documents 3 internal pipeline
registers per chip. Reconciliation [I]: the "5-stage" is the
**system-level** pipe (3 stages inside the chip + 2 stages of
external register staging — input-mux capture and output capture),
not the chip's internal depth. Either statement alone, used
without the other, is misleading.

## 3. Floating-point format — IEEE 754 single (datasheet-confirmed)

**Settled by primary source.** The WEITEK WTL-1032/1033 datasheet
(in `refs/Weitek/WeitekDatasheet.pdf`) has an explicit "Data
Formats" diagram on page 7 showing the stored format used by both
the multiplier and ALU chips:

| Field | Bits | Width |
|---|---|---|
| Sign | 31 | 1 |
| Exponent (biased) | 23-30 | 8 |
| Significand (stored) | 0-22 | 23 |
| Hidden bit (implicit) | — | 1 |

That's IEEE 754 single precision exactly: 32 bits stored, 24-bit
effective mantissa, range ~10⁻³⁸ to ~10⁺³⁸, ≈7 decimal digits of
precision.

**Hockney p. 240 has a typo**: the sentence "a more precise mantissa
equivalent to 33 bits" should read "23 bits" (the explicit
significand-field width). With that correction, his text becomes
internally consistent — the XP-32 has *less* precision than the
AP-120B's 28-bit-mantissa 38-bit format, traded for IEEE
compliance and dynamic-range standardization.

**Earlier draft note.** A previous version of this doc claimed
"extended precision via WEITEK mode" based on Hockney's incorrect
33-bit figure. The datasheet rules that out — the chip carries
exactly one stored format, plain IEEE 754 single. The naming "XP-32"
matches the 32-bit IEEE word size used internally on the LMD/TCM
buses, but the underlying choice was driven by which Weitek part
FPS sourced, not by FPS picking the bit width independently.

The chip *does* offer behavior modes that affect arithmetic:

- **Pipeline mode (PIPE)**: 3 internal pipeline registers, ~200 ns
  per stage, useful for streaming vector ops
- **Flowthrough mode (FLOW)**: pipeline registers bypassed, single
  result in ~600 ns per chip
- **IEEE vs FAST**: in FAST mode (multiplier only) denormalized
  operands are replaced by zero — same data format, faster behavior
- **Rounding**: RN (nearest, even on tie), RZ (toward 0), RP (+∞),
  RM (-∞)
- **Infinity**: Affine (sign preserved) or Projective (sign ignored)

These are control-input choices made at runtime by the EU; they
don't change the stored format. **Which mode the XP-32 actually
uses in normal operation is not currently known** — confirming it
would require either an EU PROM dump (to see the LMODE word the
EU asserts at init), an XPMLIB binary (to see what AU microcode
asserts on the chip's FUNCTION inputs), or an FPS XP-32 hardware
reference manual (not in our corpus). Pipeline mode is a plausible
guess given the measured triad throughput of 12 Mflop/s/AC fits
under the per-chip PIPE ceiling of 5 Mflop/s × 3 chips = 15 Mflop/s
and exceeds the FLOW ceiling of 1.1 Mflop/s × 3 = 3.3 Mflop/s, but
the dyad measurement of 4 Mflop/s doesn't distinguish.

The CP side (M68000 in our chassis) and the host see data as 32-bit
IEEE single words. Conversion to host-native formats (e.g.
PDP-11 F-float, IBM hex-float, VAX F-float, IEEE double) would be
handled by host-side or CP-side library routines (named like
`ZD2S`/`ZS2D` by FPS convention), not by the XP-32 itself.

## 4. EU programming model (80-bit microcode in EU PROM)

The Executive Unit runs from a fixed 2K×80-bit PROM that's set at
the factory [V — Hockney p. 241]. **We cannot change EU
microcode**; only AU WCS is writable [V]. So for "making the
XP-32 work" the EU is a fixed sequencer driven by control signals
encoded in the AU microinstruction [I].

EU sequencer:

- **Am29116** identified visually from Nakazoto's photos of the
  EXEC card [I]. Hockney does not name a specific sequencer chip.
- 16-bit data path [V — Am29116 datasheet]
- Instruction count per AMD datasheet (Mar 1986 bipolar /
  Mar 1988 CMOS Am29C116) — same ISA both variants [V]
- Status outputs: carry, overflow, sign, zero, parity, link, etc.
  [V — Am29116 datasheet]
- Single-bus 16-bit datapath with status logic for testing /
  branching [V — datasheet]
- 32 × 16-bit register file [V] — datasheet documents this as
  on-die with expansion possible via external RAM. Whether the
  XP-32 EXEC card uses the on-die file or extends it externally is
  [?] — depends on board-level design we haven't traced.

**80-bit EU PROM word layout** — entirely [S] / [?]. We have **no
bit map**. The breakdown below is a guess from Am29116-based
horizontal-microcode conventions in other 1980s designs:

- Bits 0-15: Am29116 instruction word (16-bit native) [S]
- Bits 16-79: 64 bits of side controls — chip-enables, RAM
  strobes, shift/rotate selects, branch-target overlay, mux selects
  for the AC1/AC2/M1/M2 inputs of the AU pipelines [S]

Each EU PROM word is one cycle of the Am29116-driven control pipe.
Address space = 11 bits (2K) [V — 2K = 2^11].
Branches presumably use the Am29116's native conditional-branch
mechanism plus, possibly, a small address-mux PROM (one of the
hand-labeled DIP-20 PROMs on the EXEC card may be this) [S].

**Practical implication for us**: we don't program the EU. We
program the AU. The AU microinstruction is presumed to carry bits
that "dispatch to EU subroutine X" or "wait for EU done" [S — no
direct evidence], corresponding to the EU_ADDR field in our
consensus AU layout (bits 116-125). The 8-bit-vs-11-bit puzzle
under "Open layout objections" §5 below is still open [?].

## 5. AU programming model (128-bit horizontal microcode in WCS) [I]

**This is the part we'd actually write code for.** AU
microinstruction = 128 bits [V — Hockney p. 241], one per clock
(6 MHz → 167 ns) [V — Hockney p. 239], drives all AU pipelines +
memory operations in parallel [I — "horizontal microcode" pattern
from AP-120B; explicit verification for XP-32 not in our corpus].

### Consensus AU bit-field layout (128 bits)

From `mc_xp32_microcode_inference.md`, cross-validated:

| Bits | Group | Width | Confidence | Inherited from AP-120B? |
|---:|---|---:|---|---|
| 1-23 | SPAD (S-pad ops, branches, monadic SPEC) | 23 | **HIGH** | yes — FPS-164 widened |
| 24-35 | Adder #1 (FADD, IFADD, A1_1, A1_2) | 12 | **HIGH** | yes |
| 36-47 | Adder #2 (symmetric mirror) | 12 | medium | NEW (no AP-120B precedent) |
| 48-56 | Branch (COND, DISP) | 9 | **HIGH** | yes |
| 57-85 | Data Pad (DPX/DPY mode, DPBS, XR/YR/XW/YW, XE/YE) | 29 | medium | yes — widened |
| 86-94 | Multiplier (FM, M1, M2, FM1, FM0) | 9 | **HIGH** | yes |
| 95-103 | Memory (MI, MA, DPA, TMA, MEMX) | 9 | **HIGH** | yes |
| 104-115 | DMA group (4-bit op + 4-bit src + 4-bit dst) | 12 | low | NEW |
| 116-125 | EU coordination (8-bit EU addr + 2 ctrl) | 10 | low | NEW |
| 126-128 | SPEC + I/O flags | 3 | medium | partial |

First 103 bits inherit cleanly from documented AP-120B → FPS-164
evolution. Last 25 bits are XP-32-specific (and the most speculative).

### Open layout objections (stress-tested)

1. **EU_ADDR is 8 bits** but EU PROM is 2K = 11-bit-addressed.
   Either the field is widened, or it's a dispatch-class index
   (the EU has its own internal sub-PROM that maps 8-bit class IDs
   to 11-bit PROM addresses).
2. **No pipeline-stall / wait / hold bit** in our layout, even
   though the FPS-164 has one. Either it's implicit (the EU asserts
   wait externally when needed) or hidden in the "SPEC + I/O flags"
   3-bit tail.
3. **DF (parcel class)** may be 2-bit not 1-bit — affects how the
   "primary vs secondary" classification works for dual-issue.
4. **Multiplier control timing** — to keep a 5-stage pipe fed,
   the multiplier inputs need to be valid one cycle BEFORE the
   advance, suggesting M1/M2/FM should appear earlier in the
   word than bits 86-94. Open.

### AP-120B field semantics (inherited, applicable to XP-32 SPAD/FADD/FMUL/DPX/DPY/MA/TMA groups)

From the SIM100.FTN simulator's `SPLIT(CB,FV)` decode (canonical):

| Group | Subfield | Function |
|---|---|---|
| S-pad | SOP | 0=monadic-via-SPSF, 2=ADD, 3=SUB, 4=MOV, 5=AND, 6=NOR, 7=XOR |
| S-pad | SH | shift result: 0=none, 1=L1, 2=R2, 3=R1 |
| S-pad | SPS, SPD | source / destination S-pad index (4-bit each) |
| Adder | FADD | dyadic op: FADD, FSUB, AND, OR, EQUIV |
| Adder | FADD1 | monadic when FADD=0: sign-magnitude convert, 2's-comp convert, abs |
| Adder | A1, A2 | source mux (FA, FM, DPX, DPY, TM, MD, Zero) |
| Branch | COND | 0=always; flag, FA result, SPFN compare, arithmetic-error |
| Branch | DISP | +DISP-16 = -16..+15 relative jump |
| Data Pad | DPX | load X from DPBS, FA or FM |
| Data Pad | DPY | load Y from DPBS, FA or FM |
| Data Pad | DPBS | DP-bus select: DPX, DPY, MD, SPFN or TM |
| Data Pad | XR, YR | read addr: DPA + XR - 4 |
| Data Pad | XW, YW | write addr: DPA + XW - 4 |
| Multiplier | FM | fire (or no-op) |
| Multiplier | M1, M2 | source mux (FM, DPX, DPY, TM, MD, Zero) |
| Memory | MI | memory input mux (FA, FM, DPBS) |
| Memory | MA | INC/DEC memory address, or set from SPFN |
| Memory | DPA | DPA register: INC/DEC or set |
| Memory | TMA | TMA register: INC/DEC or set |

For XP-32, these fields are wider (32-bit registers vs 16-bit;
double-precision precision changes to single-precision IEEE 754;
two adders instead of one — adders #1 and #2 share the same field
template), but the semantic core is identical.

## 6. Memory addressing (XP-32 side)

### LMD (16K × 32-bit, 2 banks)

- Sizes [V — Hockney p. 241].
- Addressing register is the **MA** register [I — by AP-120B
  inheritance, not explicitly named in Hockney for XP-32].
- "16-bit address register" gives 64K-word reach [I — Hockney
  figure 2.53 shows EU integer/address unit as "16-bit, 32
  registers"]. Only 16K is populated.
- Even/odd bank organisation: consecutive references to
  *different* banks can occur on successive cycles. Same bank
  costs extra cycles [I — by AP-120B pattern, Hockney p. 212;
  not explicitly stated for XP-32].
- DMA-fillable from SCM via XPDMAR [V — Hockney p. 242].

### TCM (4K × 32-bit, 2 banks)

- Sizes [V — Hockney p. 241].
- Addressing register **TMA** [I — by AP-120B inheritance].
- 2-bank organisation [V — Hockney p. 241 says LMD and TCM "each
  arranged in two banks"].
- DMA-fillable from SCM via XTMDMA [V — Hockney p. 242].

### WCS (4K × 128-bit, 4 banks)

- Sizes [V — Hockney p. 241].
- Microinstruction store. Addressed by the EU's program counter [I
  — by AP-120B inheritance, not explicit in Hockney for XP-32].
- Bank semantics [?]: Hockney doesn't say what the 4 banks are
  used for. Plausible candidates: one bank per math-primitive
  family, one bank per "load module" from a CPFORTRAN program, or
  one bank per active concurrent kernel. Resolving requires either
  XPMLIB documentation or an actual binary kernel.
- **Writable from CP via the panel-command DMA path** [V — implied
  by Hockney's "writable control store" terminology + the ROM's
  staging-buffer mechanism].

### EU PROM (2K × 80-bit, 1 bank)

- Sizes [V — Hockney p. 241].
- Factory-programmed; cannot be modified at runtime [V — Hockney
  uses "EU PROM" specifically, distinguishing from "WCS"
  (writable)].
- Holds the EU sequencer's instruction stream + side-control words
  [I — see §4].

## 7. CP↔AC command protocol (panel commands)

The two send paths and the dispatch table below are **[V]** — they
come from direct disassembly of the SBC ROM in this project. The
**names** I give individual panel commands are mostly **[S]** —
educated guesses from call-site context, not from FPS
documentation.

The SBC (CP role) directs XP-32 ACs via the **XLTR** (slot 13). It
writes panel-command codes to `$FF000E` (XLTR_CMD_ARG) and triggers
via `$FF0204` (XLTR_CHANNEL_SELECT) or `$FF0000` (AP I/F
CMD_STATUS with opcode 0x8004).

### Two send paths [V] (full detail in `panel_command_protocol.md`)

**Path A — polling-based** (used for sync setup ops):
- Write cmd to `$FF000E`
- Write 0x8004 to `$FF0000` (REQUEST-TRANSFER)
- Poll `$FF0000` bit 14 (ready) up to 1000 reads
- On ready, check bit 13 (error); send 0x269 or 0x26C

**Path B — XLTR-driven, IRQ-completed** (used for streaming ops):
- Write cmd to `$FF000E`
- Modify XLTR_MODE1 (clear bit 14, set bit 12); MODE0 bit 10 clear
- Write cmd to `$FF0204` (XLTR_CHANNEL_SELECT)
- Execute `bra .` waiting for chassis IRQ
- IRQ handler reads response code, sets `d0`, modifies saved PC to
  the dispatch site `F0572C`, RTEs
- Dispatch via `PanelStatusDispatchTable` at `F05BA4`

### Panel command set (16-bit codes, written to `$FF000E`)

The **codes** are [V] from disassembly; the **symbols** are [S] —
my labelling based on call-site context. FPS may have used
completely different names.

| Code | My label (speculative) | Observed context |
|---|---|---|
| 0x258-0x25F | PCMD_CH*_op_a [S] | Used in channel init/setup sequences |
| 0x260 | PCMD_CH4_CONFIG? [S] | Used once in init |
| 0x269 | PCMD_ERROR_ABORT [I] | Sent on cmd_status bit-13 (error) path |
| 0x26A-0x26B | unknown [?] | Used in recovery paths |
| 0x26C | PCMD_RELEASE [I] | Sent on cmd_status no-error path; cleanup |
| 0x276-0x27B | PCMD_INIT_STEP1-6 [S] | TCBRDHC startup, in order |
| 0x27D | PCMD_INIT_FINAL [S] | TCBRDHC startup completion |
| 0x281 | PCMD_GET_HOST_BYTE [I] | Sent during host-byte path; chassis returns a byte |
| 0x282 | PCMD_GET_HOST_BYTE_RESYNC [S] | Sent after 0x281 in a loop; sema not isolated |

These codes also decode as valid Am29116 SUBRC instructions (per
`panel_codes_am29116_decoded.md`) [V]. Three live hypotheses
about whether the chassis treats them as opcodes the EU executes
or as opaque dispatch indices, see that doc.

### PanelStatusDispatchTable response classes [V] (full detail in `panel_status_dispatch_table.md`)

42-entry × 4-byte JMP table at `F05BA4-F05C4B`, indexed by
`d0 << 2`. `d0` is a 6-bit response code (range fits 0-41) [I —
indexing arithmetic]. Only 4 distinct handlers exist + a no-op
(RTS):

| Class | Handler | Action |
|---|---|---|
| **POLL** | F05A12 | Poll `$FF0004 b0` → arm `$FF0218=0x400` → wait `b15` |
| **D1_SEND** | F058B2 | Push d1 long to `(a1)`/`(a1+2)`, opcode 0x8004 |
| **BLK_XFR** | F05B0E | Copy `(a1)→(a2)`, `a2+=4`, opcode 0x8004 |
| **D2_FIN** | F05738 | Push d2, opcode 0x8005, then 0x26C. **Only finalize code = 0x14.** |
| **RTS** | F05BA4 | No-op fall-through |

The "streaming-DMA state machine" interpretation [I] is a *reading*
of the table structure: chassis feeds CP a stream of response codes;
CP reacts (send header, pull data, sync, finalize). The chassis
side that generates the codes is still [?].

## 8. SCM ↔ AC data movement (XPDMAR / XTMDMA / XPISNC)

API spec and bandwidth figures from Hockney p. 241-242 [V].
Implementation details below — the specific XLTR-register-write
sequence — are [V] from ROM disassembly.

```
XPDMAR(IS, IL, N) — transfer N words between SCM and LMD
                    [V — Hockney p. 242]
                    r∞ = 2 Mop/s [V]
XTMDMA(IS, IT, N) — same but for TCM [V]
XPISNC()         — block until current transfer (or arithmetic)
                    completes [V]
```

These are CP-side calls [V]. The CP issues an XLTR sequence to
execute each [V — from ROM disassembly]: select XP-32 channel via
XPSEL [V — Hockney lists XPSEL but the panel-cmd implementation is
ROM-traced], program XLTR_DATA registers with SCM start address +
count [V], kick off via XLTR_STATUS_IRQ = 0x400 [V], wait via the
IRQ-driven `bra .` exit described in Path B above [V].

SCM bandwidth, per Hockney p. 241 [V]:

- Total SCM bus: 6 Mword/s (24 MB/s) for 32-bit words, or
  4 Mword/s (16 MB/s) on slower-organised banks
- Hockney explicitly: "the memory is organised such that any
  individual XP-32 coprocessor may only use half this bandwidth,
  thereby allowing two ACs on an FPS-5000 system before the memory
  bus restricts its performance"
- So **per-AC max ≈ 3 Mword/s** when bandwidth is divided in half
  by design — earlier drafts of this doc said "4-6 Mword/s per AC"
  which was wrong (mixed up "total" with "per-AC"; corrected here)
- Two ACs may run concurrently before the bus saturates [V]
- Three ACs contend for bandwidth [I — arithmetic from above]

## 9. XPMLIB primitives (the math kernels)

These run on the AU as microcode in the WCS [V], called from
CPFORTRAN running on the CP [V — Hockney p. 241-242]. The CP
"loads the appropriate WCS bank, sets up LMD/TCM, then calls
XPRUN to start the AU executing the kernel" [I — concept stated by
Hockney; specific mechanism (which bank, what bank-select cmd) is
[?]].

Naming convention: **Z** prefix = XP-32 family (vs **V** for
AP-120B) [I — pattern from Hockney's tables].

The table below is **[V]** from Hockney p. 242-243:

| Routine | Function | Approx r∞ | n_½ |
|---|---|---:|---:|
| ZVMUL(IA,IB,IC,N) | element-wise C = A*B | 4 Mflop/s | 33 |
| ZVDIV(IA,IB,IC,N) | element-wise C = A/B | 0.5 | 9 |
| ZVSASM(IA,IB,IC,ID,N) | one-vector triad: C = (A+b)*d | 12 | 56 |
| ZVASM(IA,IB,ID,IC,N) | CDC-205-type triad: C = (A+B)*d | 8 | 37 |
| ZVAM(IA,IB,ID,IC,N) | all-vector triad: C = (A+B)*D | 6 | 28 |

Other names that *might* exist in XPMLIB by analogy to the
AP-120B math-library naming convention (V-prefix routines like
VFFT, VCLR, VSCLR all exist per FPS-7352 *AP-120B Math Library
Routines*). Whether the Z-prefixed equivalents below are in
XPMLIB is **[S]** — pattern-matching, not direct evidence:

- ZRFFT — real FFT (analog of VFFT)
- ZSCLRF — scalar fill (analog of VSCLR)
- ZCVMGS — conditional vector merge by sign (analog of VCVMGS)
- ZVCLR — vector clear (analog of VCLR)

A previous version of this doc presented these as established
XPMLIB names. They are speculative and should not be cited as
such without further verification.

## 10. Startup sequence (boot → ready-to-run)

The CP-side steps are [V] from ROM reverse engineering. The
chassis-side and AC-side reactions are [I] from architectural
context — what the SBC *should* be doing to make XPMLIB work, not
what it has been observed to do (since end-to-end execution
hasn't been achieved yet).

1. **CP power-on / RTOSKernelInit** [V from ROM]:
   - SBC inits its own RAM, PTM, XLTR registers, channel configs
     (writes 0x5F to all 4 channel configs)
   - TDTI scans TCBDefinitionTable, creates 6 RTOS tasks (RDHC,
     IO1I, XP1I, XP2I, XP3I, XP4I)

2. **TCBRDHC init** (master / dispatch task) [V from ROM]:
   - Sends panel commands `0x276` through `0x27D` via
     `PanelIOConfigure_25A`
   - Each step does XLTR setup, ends in `bra .` waiting for
     chassis IRQ
   - **Intended** result [I]: chassis state machine in "ready to
     receive host commands"

3. **Host sends S-records** for each WCS bank to load [I — by
   architectural design, not yet end-to-end verified]:
   - SLC S-record parser at `F04B68` accepts host bytes
   - Bytes go to `$10000-$1FFFF` (one bank worth, 64 KB)
   - When complete, host should issue a panel cmd to transfer
     staging buffer into selected AU WCS bank. **Which panel cmd
     this is, and how the chassis selects the destination bank,
     is [?]**

4. **Host calls CPLOAD** to load the CPFORTRAN program text into
   CP's program memory [V — Hockney; specifics of CP-memory layout
   are [I]].

5. **Host calls CPRUN** to start CP execution [V — Hockney].
   CPFORTRAN program then issues XPSEL/XPRUN to fire the AU [V —
   Hockney lists these primitives].

6. **Host periodically calls APWAIT / EXGET** to harvest results
   [V — Hockney].

## 10. Startup sequence (boot → ready-to-run)

Compiled from ROM reverse engineering + Hockney + FPS-100 driver:

1. **CP power-on / RTOSKernelInit**:
   - SBC inits its own RAM, PTM, XLTR registers, channel configs
     (writes 0x5F to all 4 channel configs)
   - TDTI scans TCBDefinitionTable, creates 6 RTOS tasks (RDHC,
     IO1I, XP1I, XP2I, XP3I, XP4I)

2. **TCBRDHC init** (master / dispatch task):
   - Sends panel commands `0x276` (PCMD_INIT_STEP1) through
     `0x27D` (PCMD_INIT_FINAL) via `PanelIOConfigure_25A`
   - Each step does some XLTR setup, ends in `bra .` waiting for
     chassis IRQ
   - Result: chassis state machine in "ready to receive host
     commands"

3. **Host sends S-records** for each WCS bank to load:
   - SLC S-record parser at `F04B68`
   - Bytes go to `$10000-$1FFFF` (one bank worth)
   - When complete, host issues panel cmd to transfer staging
     buffer into selected AU WCS bank

4. **Host calls CPLOAD** to load the CPFORTRAN program text into
   CP's program memory (separate from microcode)

5. **Host calls CPRUN** to start CP execution. CPFORTRAN program
   issues `XPSEL` + `XPRUN` to fire the AU on the loaded microcode.

6. **Host periodically calls** `APWAIT` / `EXGET` to harvest results
   back into host RAM.

## 11. Sample CPFORTRAN flow [I]

The individual API calls are [V] from Hockney + Curington. The
*specific argument values and ordering* shown below are
illustrative reconstruction — they show how the primitives would
fit together, not a verbatim XPMLIB example. The actual CPFORTRAN
syntax (argument types, optional vs mandatory, etc.) may differ.

```fortran
CALL CPLOAD('mymath.cpo')       ! load CP-side program
CALL CPRUN                       ! start CP-side
CALL EXPUT(IA, 4096, A)          ! host → FPS-5000 SCM at IA
CALL EXPUT(IB, 4096, B)
CALL APWD                        ! wait for both transfers
! On the CP, the loaded program now does:
!   XPSEL(1)
!   XPDMAR(IA, ILMD_A, 4096)    -- SCM→LMD
!   XPDMAR(IB, ILMD_B, 4096)
!   XPISNC                       -- wait for DMAs
!   XPRUN(ZVMUL_addr_in_WCS)    -- fire AU on ZVMUL kernel
!   XPWAIT(1)                    -- wait for AU done
!   XPDMAR(ILMD_C, IC, 4096)    -- LMD→SCM
! Back on host:
CALL EXGET(IC, 4096, C)          ! SCM → host
CALL APWR                        ! wait
```

The XP-32 ↔ host doesn't go direct [V — Hockney p. 241 explicit] —
everything is CP-mediated.

## 12. Performance ceiling (Hockney Table 2.11, FPS-5320A measured) [V]

| Operation | CP only | 1 AC | 2 AC | CP + 2 AC |
|---|---:|---:|---:|---:|
| Dyad `C=A*B` (ZVMUL) | 1.5 | 4 | 8 | 9.2 Mflop/s |
| Triad `C=(A+b)*c` (ZVSASM) | 3.9 | 12 | 24 | 27.7 Mflop/s |

n_½ for triad on 2 AC = 4200 elements [V — Hockney Table 2.11].
Below n=4200 you don't get half the asymptotic rate.

Memory-bandwidth interpretation [I]:

- 6 Mword/s total SCM bandwidth [V — Hockney p. 241]
- An AC's arithmetic saturates its memory bandwidth at computational
  intensity f ≥ ~4 flop/ref [I — arithmetic from peak rates vs
  bandwidth, following Hockney's general methodology in §1.3.6;
  not stated explicitly for XP-32]
- Below that, memory bandwidth caps the effective rate

## 13. What we don't know yet (open questions)

These are the things still in the way of actually running AU code:

### A. Exact AU microinstruction bit-field mapping

Inferred consensus is medium-confidence for the 25 XP-32-specific
bits (DMA, EU coord, SPEC tail). Need at least one of:

- An XPMLIB binary kernel (`.cpo` / `.xpo`) file — would let us
  reverse-engineer field-by-field by comparing source ZVMUL
  semantics to the bit pattern
- An XPMLIB source listing in APAL-equivalent assembler
- An FPS XP-32 microcode reference manual

**Closest we have**: the recovered AP-120B FFT microcode in
`ucode_transcribed.py` (227 instructions, full bit map known). The
AP-120B is the ancestor; 90% of XP-32 fields are present in the
AP-120B, just widened. So if we found *any* XP-32 kernel binary
we could anchor the layout to known semantics.

### B. EU PROM contents

We have **zero data** about EU PROM contents. Can't run AU code
without knowing what the EU does for each command. Either:

- Dump the EU PROM chips on a physical EXEC card (Lovett's chassis)
- Find FPS documentation for the EU instruction stream
- Reverse-engineer behaviour by observing the bus

### C. Chassis state machine for the AU control path

The `PanelStatusDispatchTable` reverse engineering tells us what
the SBC does after receiving each response code, but **not what the
chassis does to choose response codes**. The IRQ handler that
writes `d0` and `$10AA` and modifies the saved PC out of `bra .`
remains unidentified.

### D. Whether the AP-120B-shaped fields are byte-aligned in the
  same way in 128-bit XP-32 microinstructions

The AP-120B's 64-bit word maps fields starting from bit 63 (DF/SOP)
down. The XP-32's 128-bit word might do the same (high-bits-first)
or might reverse, or might pad on either end. The "lsb-first" vs
"msb-first" choice doesn't change semantics but means the
recovered AP-120B microcode binary can't be re-used as XP-32 prefix
bits without verifying.

### E. Floating-point conversion semantics

How does the XP-32 handle data coming from the host as IEEE 754
double (64-bit) or 32-bit-int? Are there explicit ZD2S / ZI2S type
conversion microcode kernels? If so, where in the WCS do they live?

## 14. Concrete path to "running our first XP-32 code"

This is a *plan*, not a verified procedure. Each step assumes the
prior step succeeded; if a prior step uncovers facts that contradict
later steps, the plan should be revised.

In dependency order:

1. **Acquire an XPMLIB binary** — try Bitsavers, eBay 9-track
   tapes, David Lovett's chassis if its EU PROMs and WCS contents
   can be read. Without this, AU programming stays [S].

2. **Dump EU PROM** from one of the EXEC cards in the chassis.
   ~2K × 80-bit = ~20 KB total. The chip count and width split
   on the physical card is [?] — likely 5-10 bipolar PROMs ganged
   into a wide word per Nakazoto's photo, but exact organisation
   isn't determined.

3. **Resolve the panel-command-completion IRQ** — close the
   chassis state machine. Either:
   - Find the missing IRQ handler that writes `d0` + `$10AA` in
     the ROM (further disassembly work)
   - Or implement the chassis side ourselves in the emulator's
     `versabus.c` so end-to-end Path B works without identifying
     a real handler

4. **Write a minimal AU kernel by hand** — say, a vector copy
   (no arithmetic). Hand-assemble using the consensus 128-bit
   layout. Upload via monitor's `L` command into RAM staging,
   then via SBC panel commands into WCS bank 0.

   Caveat: this step depends on the consensus layout being
   approximately right. Wrong-layout kernels will produce
   wrong-looking results without obvious diagnostics. Some way
   to instrument the AU (e.g. observing LMD via the monitor
   after each command) would help.

5. **Run it on emulator first**. The emulator doesn't model the
   XP-32 at all yet — we'd need to add at minimum a stub that
   accepts WCS uploads and reports back something sensible on
   read. This is a substantial new emulator subsystem, not free.

6. **Run it on Lovett's actual chassis** (the moment of truth).
   Burn the monitor ROM. Use the monitor's `L` command to upload
   the WCS kernel. Issue panel commands manually via the
   monitor's `w` command to fire the AU. Observe LMD with `m`.

## 15. References / pointers

In-project documents (some inferences, some verified facts;
follow individual files for confidence breakdown):

- `panel_command_protocol.md` — Path A / Path B panel-cmd protocols
- `panel_status_dispatch_table.md` — F05BA4 dispatch table
- `versabus_pinout.md` — P1 / P2 connector pin maps
- `serial_ports.md` — SIO docs (firmware-unused; monitor uses it)
- `M68KVM02_memory_map.md` — SBC memory map
- `hockney_chapter_summary.md` — Hockney §2.5 paraphrase
- `../notes/mc_xp32_microcode_inference.md` — 128-bit AU layout consensus
- `../notes/mc_xp32_layout_stress.md` — adversarial stress test
- `../notes/panel_codes_am29116_decoded.md` — panel codes as Am29116 SUBRC
- `../notes/fps164_chip_identification.md` — sequencer-chip family ID
- `../ucode_transcribed.py` — AP-120B microcode source-of-truth
- `../monitor/README.md` — in-ROM monitor + wiring guide

External sources we have in `refs/`:

- Hockney & Jesshope, *Parallel Computers 2*, §2.5 (1988) —
  `fps.pdf`
- WEITEK WTL-1032 / WTL-1033 datasheet —
  `refs/Weitek/WeitekDatasheet.pdf`
- AMD Am29116 datasheets — `refs/AMD/29116_dataSheet_Mar86.pdf`,
  `refs/AMD/29C116_dataSheet_Mar88.pdf`
- Curington & Tracy 1984, *Performance Estimation Methods for
  XP32 MAXL* — `refs/FPS-5000/`
- Curington 1986, *Symbolic Execution Methods for XP32* —
  `refs/FPS-5000/`
- Curington 1983 power-spectrum-analysis paper — `refs/FPS-5000/`
- Curington 1986 synchronisation / pipeline-overhead paper —
  `refs/FPS-5000/`
- AP-120B / FPS-164 docs in `refs/AP-120B/`, `refs/FPS-164/`

External sources we **do not** have but would help:

- An FPS XP-32 hardware reference manual (existence unknown,
  no public copy located)
- INMOS IMS-1040 datasheet (would confirm SRAM identification
  Hockney attributes)
- An XPMLIB binary / source listing
- An EU PROM dump from any FPS-3000 / FPS-5000 chassis
- The Curington & Tracy 1984 paper specifically may answer many of
  the [?] questions in this doc — worth reading carefully (haven't
  worked through it in detail yet)
