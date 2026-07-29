# Adversarial Review of ds2/ Documents

Systematic challenge of every factual assertion, cross-referenced against
primary sources. Date: 2026-07-29.

---

## A. FACTUAL ERRORS FOUND (and fixed)

### A.1 $10AA incorrectly attributed to TCBRDHC (3 files affected)

**Error:** `GAP_ANALYSIS.md:146`, `FUNCTION_COVERAGE.md:81`, and
`REGISTER_ACCESS.md:273` all said TCBRDHC reads/dispatches on `$10AA`.

**Reality:** `$10AA` is read ONLY by TCBIO1I's ISR at F05E12 (`move.l
$10aa.l, d2`). TCBRDHC dispatches on `$E86` (the latched MODE0 panel
response code at F04752: `cmpi.w #$8, d0` with d0 from `$E86`).

**Evidence:** `fps3k.asm` line 2965 (`f05e12: 24 39 00 00 10 aa`) is inside
TCBIO1I's region (F05D00-F05EFF, per TDTI table). CLAUDE.md:718 confirms:
"`$10AA` is the gate, read at F05E12 and dispatched on."

**Fix:** All three files corrected. `$10AA` in TCBRDHC context replaced
with `$E86` (panel response dispatch).

---

## B. OVERCONFIDENT CLAIMS — insufficient evidence

### B.1 AM29116_EMULATION.md: 64-bit side-channel sub-field breakdown

**Claim:** The 64-bit side-channel is broken into 7 groups with specific
bit counts (AU WCS addr 12b, pipeline controls 16b, S-Pad 8b, Data Pad
10b, memory 8b, DMA 4b, EU coord 6b = 64 bits total).

**Challenge:** Every bit count is speculative. No primary source
(Hockney, datasheets, schematics) specifies ANY of these assignments.
The CLAUDE.md consensus layout's sub-field breakdown (giving DMA
12 bits at 104-115 and EU coordination 10 bits at 116-125) was
explicitly RETRACTED (R3, R4 in VERIFIED_CLAIMS.md) as "LLM-generated
speculation." My breakdown adds NEW sub-fields not in the retracted
layout.

**Additionally,** the review confuses the EU PROM's 64-bit side-channel
(on the EXEC card, controlling high-level sequencing) with the AU
microinstruction's 128-bit fields (on the ARITH card, controlling
FP pipelines cycle-by-cycle). These are separate memories with
different bit assignments. Placing "S-Pad controls" in the EU PROM
side-channel implies the Am29116 directly controls S-Pad register
indices — which might be true but is unverified and conflicts with
the 128-bit AU microinstruction also having S-Pad fields.

**Severity:** Low. The document correctly warns "The sub-field breakdown
above is speculative. No primary source confirms the bit assignments."

**Recommendation:** Replace the specific bit counts with "unknown allocation"
and note the EU-PROM-vs-AU-microinstruction distinction.

### B.2 AM29116_EMULATION.md: "Am29116 instruction is 16 bits"

**Claim:** "Bits 0-15: Am29116 instruction word (16-bit native)" in the
80-bit EU PROM.

**Challenge:** This is an inference. Hockney says "80-bit microcode
instructions" — he does not specify which bits are Am29116 instructions.
The Am29116 ISA is known (16-bit instruction format), and the 80-bit PROM
could contain a 16-bit Am29116 field, but:
- The 80 bits might use a CUSTOM microcode format (not Am29116 instructions
  at all), with the Am29116 receiving a decoded/translated signal
- The Am29116 instruction might occupy bits other than 0-15
- The two Am29116 chips might share the 80-bit word differently (each
  getting a 16-bit instruction from a different field)

CLAUDE.md:921 says "16-bit Am29116 instr + 64-bit side-control" — this is
presented as a consensus, not as Hockney's words. The Hockney primary
source just says "80-bit microcode instructions."

**Severity:** Medium. The 16+64 split is the project consensus and is
plausible, but the document should state it as inference, not fact.

**Recommendation:** Change "Bits 0-15: Am29116 instruction word" to
"Inferred: bits 0-15 likely contain the Am29116 instruction."

### B.3 AM29116_EMULATION.md: "dual-port (1 read + 1 write per cycle)"

**Claim:** The Am29116's 32-entry register file is described as
"dual-port (1 read + 1 write per cycle)."

**Challenge:** The Am29116 datasheet (referenced in CLAUDE.md as
`refs/AMD/29116_dataSheet_Mar86.pdf`) is not available for me to check
directly. The "dual-port" characterization is an assumption based on
typical bipolar microprocessor architecture of the era. The chip
certainly has a register file (CLAUDE.md line 248: "32 × 16-bit
register file") but whether it's dual-port is unverified from local
sources.

**Severity:** Trivial. Doesn't affect emulator design at the level
described.

### B.4 PANEL_COMMANDS.md: "TODRA range = 30 codes"

**Claim:** "30 codes in this range (0x260-0x27D = 30 codes, 0x27E+
outside SUBRC)."

**Challenge:** 0x260 through 0x27D inclusive = 0x27D - 0x260 + 1 = 30.
But the panel commands use only a SUBSET of these: per the emulator's
switch statement, 0x269, 0x26A, 0x26B, 0x26C, 0x26E, 0x271, 0x276,
0x277, 0x278, 0x279, 0x27A, 0x27B, 0x27D (plus 0x260, 0x26D, 0x270
and several others). Many TODRA codes between 0x260-0x27D are NOT used
as panel commands — they produce no effect in the `chassis_panel_cmd_name`
dispatch. The TODRA GROUP has 30 codes; the panel command SET is smaller.

**Severity:** Trivial. The statement is mathematically correct but the
document should distinguish "TODRA instruction group size" from "panel
command count."

### B.5 CARD_COMPLETENESS.md: "$FF0008 has THREE documented modes"

**Claim:** The AP I/F bulk data port at $FF0008 "has THREE documented
modes in the firmware (inbound bulk at F04AE2, outbound bulk, and
S-record ASCII at F04B22)."

**Challenge:** "Inbound bulk" (F04AE2) and "S-record ASCII" (F04B22) are
confirmed code sites. "Outbound bulk" is listed in CLAUDE.md as "selected
by $E87 bit 5." But RAM_SYMBOLS.md documents $E87 bit 5 as "32-bit
argument mode" — a different function. The outbound bulk mode IS
mentioned in the disassembly at F04C50 (per REGISTER_ACCESS.md), so the
mode exists, but whether $E87 bit 5 actually selects port direction vs.
argument width is unresolved.

**Severity:** Low. Three modes are confirmed by code sites. The selector
ambiguity is documented elsewhere.

---

## C. MISSING COUNTER-EVIDENCE

### C.1 The panel command path DOES NOT go through the Am29116

**What ds2/ documents assert:** Panel commands are Am29116 SUBRC
instructions; the EU's Am29116 processes them.

**Missing counter-argument:** The SBC writes panel commands to
`APIF_CMD_ARG_LO` ($FF000E), an AP I/F register. The AP I/F card is a
dual-port interface between the SBC (VersaBUS side) and the host
(host-bus side). The panel command path is:

```
SBC → APIF_CMD_ARG_LO ($FF000E) → AP I/F card → ??? → Am29116
```

What happens between the AP I/F card and the Am29116 is unknown.
Possibilities:
- The command is forwarded verbatim to the Am29116's instruction input
- The command is translated/decoded by intermediate logic (XLTR, FMT, PALs)
- The command triggers a fixed-function sequence in the chassis that does
  NOT route through the Am29116 at all

The fact that the codes decode as valid Am29116 SUBRC is suggestive but
not proof of direct Am29116 reception. The chassis could decode the
command via PALs and send a different signal to the Am29116.

**Documents affected:** AM29116_EMULATION.md (data-flow diagram implies
direct SBC→Am29116 command routing), PANEL_COMMANDS.md (Am29116 decode
section treats codes as Am29116-received).

**Recommendation:** Add explicit note that the Am29116 input path is
unverified.

### C.2 The "level-7 deadlock" may not exist on real hardware

**What ds2/ documents assert:** TCBIO1I's ISR at level 7 spins in
`bra .` forever because the level-6 panel responder can never preempt it.

**Missing counter-argument:** The real hardware might not route the
host interrupt at level 7. The $5F written to $FF0254 encodes level 7,
but the board's IRQ-pin wiring might deliver it at a different level.
If the board straps or PAL logic routes the host interrupt at level 5
or 6, the deadlock doesn't occur. Additionally, the chassis might
respond to PCMD_HOST_REQUEST (0x281) via a mechanism that does NOT
require the level-6 BIM0 ch0 path — e.g., a direct bus cycle that
modifies the saved PC without an interrupt.

**Documents affected:** GAP_ANALYSIS.md:2.3, FUNCTION_COVERAGE.md,
REGISTER_ACCESS.md (multiple entries marked "level-6 blocked").

**Recommendation:** The deadlock is confirmed in the EMULATOR (F04930
executes zero times vs 18,135 spin iterations). Note this may not
represent real hardware.

### C.3 Emulator self-test pass does NOT validate the hardware model

**What ds2/ documents assert:** The emulator passes the self-test suite
(820 diagnostic-region PCs executed, 296 XLTR accesses, etc.).

**Missing counter-argument:** Passing tests by providing the expected
values doesn't prove the model is correct. Several model choices make
the tests pass but are unverified:

1. Bit 5 of F70019 tracks checkpoint-count ≥ 2 — modeled because a
   direct VMOD mirror was proven wrong (it would skip the test suite
   permanently at F08732). But the REAL mechanism could be different
   (e.g., an external timer, a chassis interlock, a jumper setting).
2. The MC6840 single internal reset (CR1 bit 0 holding all timers) —
   implemented because without it T2 and T3 free-run and re-assert IRQ.
   But the REAL MC6840 might behave differently with specific prescaler
   settings that prevent free-running.
3. MODE1 bit 12 gate for panel responses — prevents model corruption
   during register walks. This is the right hardware behavior but the
   specific bit (12) is an inference; the gate could be a different bit.

The model makes the self-tests pass, but model correctness ≠ test pass.

**Documents affected:** CARD_COMPLETENESS.md (XLTR "register-level
access works"), all documents citing the self-test as validation.

---

## D. INCONSISTENCIES ACROSS DOCUMENTS

### D.1 $E87 bit 5: "32-bit argument mode" vs "port direction select"

| Document | Interpretation |
|---|---|
| RAM_SYMBOLS.md | bit 5 = "32-bit argument mode" |
| REGISTER_ACCESS.md | Outbound bulk "Selected by $E87 bit 5" |
| GAP_ANALYSIS.md | Not listed |

These could be the same thing (32-bit mode selects outbound direction).
Or they could be unrelated bits with different functions at different
code sites. The inconsistency arises because both documents reference
the same bit but describe different functions. Resolution requires
tracing the actual branch instruction that tests bit 5.

### D.2 Self-test phase count: "~15" vs "13 confirmed"

| Document | Count |
|---|---|
| GAP_ANALYSIS.md | "~15 phases known" |
| FUNCTION_COVERAGE.md | "16+ self-test phases" |
| ERRATA.md: I5 | "13 confirmed" |

The 13 confirmed phases (0x700, 0x800, 0x900, 0x1000, 0x1100, 0x1200,
0x1300, 0x1400, 0x1600, 0x1700, 0x1800, 0x1900, 0x1A00) come from the
CHANNEL_SELECT values written during MainInit. But there may be
additional phases outside this range (using different chsel values)
or phases that don't write CHANNEL_SELECT at all. "~15" and "16+"
are both approximations. Standardize on "13 confirmed phases."

### D.3 $FF004A: "status word" vs "data LOW"

| Document | Name |
|---|---|
| REGISTER_ACCESS.md | CH1 status word (host-injected) |
| RAM_SYMBOLS.md | ISR snapshot of $FF004A (channel status) |

These are different views of the same register. TCBXP1I writes $1B to
$FF004A as a "data LOW" value. TCBIO1I reads $FF004A as a "status word"
set by the host (0x4F). Same register, different semantics depending on
which task owns the channel window. The inconsistency is in the naming,
not the fact — but it's worth reconciling.

---

## E. CIRCULAR REASONING

### E.1 "Verified against CLAUDE.md"

Several ds2/ documents cite CLAUDE.md as evidence ("per CLAUDE.md,"
"CLAUDE.md confirms"). But CLAUDE.md is itself a secondary summary
document — not a primary source. Citing it as evidence for hardware
claims creates circular trust:

```
ds2/ document → claims X → cites CLAUDE.md as evidence
CLAUDE.md → claims X → cites emulator code as evidence
emulator code → implements X → because CLAUDE.md says so
```

The primary sources are Hockney, AMD datasheets, board photos, and
the SBC ROM disassembly. Where ds2/ documents cite CLAUDE.md, they
should instead cite the underlying primary source.

**Affected:** Assertions about EU PROM size (should cite Hockney p.241),
Am29116 presence (should cite Nakazoto photo), panel code decode (should
cite AMD datasheet), etc.

### E.2 "19% coverage" number cited without verification

The 19% figure comes from CLAUDE.md's "coverage reality check
(2026-07-29)." My documents cite it extensively but never verify it
independently. The methodology (counting executed PCs per region,
dividing by region size) is described but the raw data is not available.

**Recommendation:** Add caveat that the 19% figure is from CLAUDE.md's
internal measurement, not independently verified.

---

## F. MISSING TOPICS

### F.1 No discussion of the FMT card's bus-width conversion

The UNIV FMT card converts between 16-bit VersaBUS and 32-bit XP-32
bus. This width adaptation is critical for the WCS upload path: SBC
writes 16-bit words, the XLTR forwards them, the FMT converts to
32-bit, and the WCS write port stores 128 bits at once. How the FMT
packs 16-bit words into 32-bit and then into 128-bit is not analyzed.

### F.2 No discussion of the Am29540 FPC (Floating Point Chip)

The ARITH card may contain AMD Am29540 chips (mentioned in
`card_parts_vs_rom_crosscheck.md` as "Am29540 and Am29116 microcode
bits") in addition to Weitek parts. The Am29540 is a 32-bit FPU with a
different pipeline structure. If present, it complicates the AU pipeline
model.

### F.3 No discussion of the 68000's CLR read-modify-write hazard

The emulator models `CLR` as a pure write. A real 68000 reads the
destination first. Code using `CLR` on uninitialized DRAM could raise
BERR due to parity. The monitor consciously uses `move.l #0` instead.
Not discussed in any ds2/ document.

### F.4 No discussion of the VersaBUS byte-lane convention

The M68KVM02 uses odd-byte addressing for on-board peripherals
(F70001, F70011, etc.). The emulator correctly models this. But the
VersaBUS side ($FF0000+) uses 16-bit word accesses exclusively. What
happens on a byte access to a VersaBUS register is not modeled, and
this convention is not documented.

---

## G. SUMMARY — Required Fixes

| # | Severity | Description | Documents affected |
|---|---|---|---|
| A.1 | **HIGH** | $10AA attributed to TCBRDHC, actually TCBIO1I | GAP_ANALYSIS.md, FUNCTION_COVERAGE.md, REGISTER_ACCESS.md |
| B.1 | Low | Side-channel sub-field bit counts are speculative | AM29116_EMULATION.md |
| B.2 | Medium | 16-bit Am29116 field is inference, not fact | AM29116_EMULATION.md |
| C.1 | Medium | Panel cmd path through Am29116 is unverified | AM29116_EMULATION.md, PANEL_COMMANDS.md |
| C.2 | Medium | Level-7 deadlock may be emulator-only | GAP_ANALYSIS.md, FUNCTION_COVERAGE.md |
| D.1 | Low | $E87 bit 5 has two inconsistent interpretations | RAM_SYMBOLS.md, REGISTER_ACCESS.md |
| D.2 | Low | Self-test phase count inconsistent (13-16+) | Multiple |
| E.1 | Medium | Circular citation of CLAUDE.md as evidence | Multiple |
| E.2 | Low | 19% figure from CLAUDE.md, not independently verified | Multiple |
| F.1-F.4 | Low | Missing topics (FMT width conv, Am29540, CLR hazard, byte-lane) | None explicitly |
