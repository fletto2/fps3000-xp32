# 09 — Current status

## Where we are

The reverse-engineering work has reached a steady state where most
of what's *derivable* from the SBC ROM + family documentation is
extracted. Further progress requires either:

- **physical access to the hardware** (bus traces, EU PROM dump,
  cable continuity probe), or
- **discovery of missing artifacts** (XPMLIB binary, AP I/F card,
  Bomem application disks)

## Solved

### Session of 2026-07-31 — SBC-side analysis closed at every level examined

**Completeness results** (each from two or more independent methods):
- **Control flow closed**: 25 computed dispatches, 22 static jump-table runs (3 structures),
  2 `bsr` fan-in tables — all identified, none unaccounted.
- **Device reach closed**: base-address census + pointer-global census + provenance-tracked
  window sweeps + runtime access log all agree. **Exactly three cached device pointers**
  (`$0C3A` display, `$0C4E` PTM, `$0E48` VMOD). The SIO base is **never formed**, which is a
  positive property of the instruction stream, not an absence of observations.
- **AP I/F settled**: 5 populated windows x exactly 4 registers each; windows 1, 6, 7 have
  **zero references by any addressing form**.
- **Byte accounting**: 7 contiguous regions tiling 65,536 exactly; every region read end to end.
- **Subroutines**: FPS layer 110/110 identified; kernel 41/69 named from the directive tables,
  remaining 28 each bounded by their calling directive.

**Mechanisms found this session**: the remote register-access interface (chassis can read/write
every CPU register incl. USP), a **stack canary** (`$4245`='BE', 7 pushes / 1 check / kernel-fatal
on mismatch), **runtime code generation** (the kernel builds `jsr` thunks in 3 places), a real
**time-of-day clock** with lock-free sub-tick interpolation, a **privilege model** (7 gated
directives), **per-task single-step** (trace-enabled dispatch + T-clearing handler), and a
**second unmapped-space test** covering `$20000`-`$EFFFFF` that runs before the documented
watchdog.

**Corrections made**: `$26C` is the timeout code and `$26A` an error code (were inverted);
`$271` reports `$2B` SGSEM not `$29` ATSEM; `$259`-`$260` are validation failures not per-channel
ops; `PanelErrorMaskTable` is indexed by channel not opcode; the 96-byte "stack leak" retracted;
BIM registers are 21 of 24 named not 23; board-status counts were inflated by overlapping scans.

**Verification**: `tools/verify_findings.py` at ~1,560 checks. Two harness defects fixed —
**193 checks were sitting below `sys.exit()` and never ran**, and five checks asserted vacuously
true conditions. Both classes now guarded.

## Solved

- 64 KB SBC ROM disassembled and annotated (~22K lines, ~80%
  understood)
- VersaBUS/XLTR protocol reconstructed
- 21 panel commands decoded as Am29116 SUBRC instructions
- Consensus 128-bit XP-32 AU microinstruction layout (first 103
  bits HIGH/MEDIUM confidence)
- AP-120B microinstruction format verified end-to-end via the
  recovered FFT identity-test microcode
- Bomem-customized RSX-11M+ V5.1.1 disks extracted (4.6 MB OS files,
  but missing application disks)
- Full FPS-100 archive accessible (11.5K AP-120B microinstructions
  + matching APAL source)
- **PanelStatusDispatchTable reverse-engineered** (42-entry, 4
  handler classes — see `refs_extracted/panel_status_dispatch_table.md`)
- **WEITEK WTL-1032/1033 datasheet acquired** — FP format settled
  as plain IEEE 754 32-bit single precision (Hockney's "33-bit
  mantissa" is a typo for "23-bit")
- **Stand-alone M68000 emulator** that boots the ROM cleanly
  through MainInit's 16+ self-test phases, Phase2Init,
  RTOSKernelInit, and TDTI task creation — all 6 expected RTOS
  tasks instantiated. Settles in the scheduler idle loop. See
  `emulator/`
- **In-ROM monitor / debugger / host interface** in 22.4 KB of free
  ROM (`F0A826`+), talks over the on-board SIO Channel A. Includes
  S-record loader, memory dump/write, register display. Lets us
  bypass the chassis-side panel-cmd dispatch and load microcode
  directly into the staging buffer. See `monitor/`

## Open issues (from doc audit + stress test)

| ID | Issue | Action |
|---|---|---|
| G1 | Memory-map row split AP I/F vs XLTR | ✓ Done (fixed in CLAUDE.md, 03-firmware.md) |
| G2 | Cable count 150 vs 169 reconciled | ✓ Done (cable_protocol_inferred.md) |
| G3 | Bomem DA3 chain-of-custody for FPS-3000 | Open — ask Lovett |
| G4 | "Am29116 sequencer" terminology | ✓ **Applied 2026-07-25** across CLAUDE.md + cliffsnotes: the chip is the "EU controller", not a microprogram sequencer. Remaining "sequencer" uses are contrastive (Am2910 / ADSP-1401, which genuinely are) |
| G5 | EU control store: PROM vs SRAM | **Mostly closed** — Hockney p. 241 text + WEITEK datasheet confirm EU=PROM, AU=WCS. Chip-to-role mapping on the physical card still needs photo re-inspection. |
| G6 | UNIV FMT card role | **Narrowed 2026-07-31 by inference** — the SCM march test requires exact read-back of `$00000000`/`$FFFFFFFF`/`$55555555`/`$AAAAAAAA` through the `$400000` window, and the machine boots on iron, so **UNIV FMT is bit-transparent to the SBC**. Any format conversion happens on AC-initiated traffic, which the SBC's diagnostics never observe. Testable: write a pattern via the SBC, read it with an AC |
| G7 | AP I/F variant suffix convention | Open — read Board Revision List |
| G8 | VersaBUS bandwidth analysis | Open — low priority |
| G9 | Cable doc "validation" overclaim | ✓ Done (softened to "high-confidence-hypothesis verification") |
| **New 2026-07-25** | `0x26E` panel code is named `CH1_TCB_FAIL` but appears at F05F92 in code attributed to TCBXP4I; `0x26F`/`0x270` unnamed. Either the channel label or the function attribution is wrong — channel numbers in the `0x26E-0x271` block are unreliable. Also a gap at `0x27C` where `INIT_STEP7` would sit. |
| stress-1 | EU_ADDR width: 8 vs 11 bits needed | Open — design refinement |
| stress-2 | Missing pipeline-stall bit | Open — design refinement |
| stress-3 | DF flag: 1-bit vs 2-bit | Open — design refinement |
| stress-4 | Multiplier ordering hazard | Open — design refinement |

## Next-step paths

### Path A — connect FPS-3000 to PDP-11/73

**Bottleneck**: missing host-side AP I/F card. Substitute requires
FPGA with ≥150 user I/O. Plan in
[`host_substitute_hardware_plan.md`](../notes/host_substitute_hardware_plan.md).

Subtasks:

1. Bench-probe the cable to verify 4448 netlist correspondence (G9)
2. Build FPGA gateware emulating the host-side AP I/F protocol
3. Q-bus interface to the /73

### Path B — devise XP-32 microcode

**Bottleneck**: EU PROM never read. Three sub-paths:

1. **Read the EU PROM** — most informative but most invasive
2. **Live bus trace** during a known XPMLIB call (requires
   booting the FPS-3000 with a host that can issue XPMLIB calls)
3. **Inference-only** — refine the consensus layout further from
   the FPS-100 archive's 11.5K AP-120B microinstructions

Path A unblocks Path B.2 (need a working host first).

### Path C — recover an XPMLIB binary

Long shots, in roughly decreasing probability:

1. **Myron White** (FPS-100 lead designer, posted on Hackaday
   2025-07) — may know where FPS-3000 software went
2. **FPS-5000 customer sites** (LANL, NCAR, USGS, seismic firms)
3. **Cully's powered-up FPS-100** in Massachusetts — may have
   software too
4. **CHM Cray archives** (FPS → Cray 1991 → SGI 1996 → HPE)

## Project meta

- Lessons committed to writing: methodology in [08](08-methodology.md),
  hallucination tracking in `mc_doc_audit_triage.md`
- All inferences cross-checked against primary source text before
  committing
- Council-of-Clankers consistently produces useful work *and*
  consistently fabricates citations — both have to be expected and
  managed

## Where to read more

- Project plan: [`project_plan.md`](../notes/project_plan.md)
- Audit triage: [`mc_doc_audit_triage.md`](../notes/mc_doc_audit_triage.md)
- Hardware substitute plan: [`host_substitute_hardware_plan.md`](../notes/host_substitute_hardware_plan.md)

## Session of 2026-07-31 (second block) — the kernel's own subsystems

The previous session closed the *device* side. This one closed most of what was still open
on the **RTOS** side, which matters because a model of this machine has to run the RTOS
before any chassis behaviour is observable.

**Mechanisms newly specified**

- **P and V** (`$F006E8`/`$F00788`) — the blocking primitive everything else reduces to.
  Semaphore = `{bit 15 TAS lock, bits 14-0 signed count}` + a waiter list linked through
  `TCB+$20`. Blocking sets state bit 13, releases the lock, installs the scheduler's stack
  and jumps to `$F0050C` without returning.
- **`$2A`/`$2B` put the object at `!UST` entry + `$10`** — from the `lea` the handler
  actually executes. This **corrects** an earlier inference of `+8` made from the layout,
  and it self-confirms: a word plus a longword at `$10` ends exactly on `USTMENT = $16`.
- **The task context area**: `TCB+$74` is the 60-byte `movem` save area, `TCB+$26` the
  priority byte. `TCB+$77` turns out **not to be a field** — it is the low byte of the
  saved `d0`, which is where the old priority was stashed.
- **The timebase, end to end from one ROM constant.** `$F0A530 = 10` (milliseconds) is
  shifted and multiplied into the MC6840 latch `$27C7`, and separately stored at `$0C56`
  for the software clock. It simultaneously confirms the dual-8-bit PTM mode, the latch
  value, the 10.0000 ms tick, the 100-tick 1 Hz divider and the ms-of-day arithmetic.
- **A real time-of-day clock**: `$0C3E` = days, `$0C42` = ms-of-day, rolling over at
  86,400,000; `$49` sets it (accumulating the adjustment so intervals survive a change),
  `$4A` reads it. **The day rollover rebases every deadline** in the two timer lists at
  `$0C2C`.
- ~~A 1 Hz display heartbeat~~ — **RETRACTED later the same day.** The `$0C5C` divider and
  its display writes live in the **spurious-interrupt** handler, which the FPS layer
  overrides, so they never execute. The display is a **boot-only** channel. I had inferred
  "tick" from the divider value of 100 against the 10 ms tick without checking what invoked
  the handler.
- **The server registry** (`$0C9A`/`$0CAA`) and the `SERVER`/`DSERVE`/`DERQST`/`AKRQST`
  family; **`$23` = QEVNT** and **`$36` = AKRQST** decoded from their bodies.
- **Two calling conventions that defeat static analysis**: the trace logger takes an
  **inline parameter word** after the `bsr` (11 sites, not the 9 recorded), and
  `$F0175C` returns into a **two-slot return vector** — 31 of 31 callers reserve exactly
  4 bytes.

**Corrections made**

- The AP I/F **base window and channel windows have different register maps**; the summary
  sentence generalised window 0 to all five.
- `!UST` semaphore field is `+$10`, not `+8`.
- The trace-hook census is 11, not 9 (two gate on `$0C35`, not `$0C34`).
- `$0C40` and `$0C41` are **not globals** — the first is the low word of `$0C3E`, the
  second a misaligned decode at an address no listing treats as a boundary.
- `$F05666` is a parameter-block update, not a return-address patch; **nothing in RDHC
  patches a stacked return address**.

**Verification state**

The harness went from 1,557 to ~1,650 live checks. Three defects of the *same family* as
the previously-recorded orphaned checks were found and fixed: five more vacuous
assertions, a **use-before-definition** inside the emulator block that aborted three
consecutive runs, and — the reason that one survived — **both structural self-audits were
running at the end of the file**, where they cannot catch a crash 5,700 lines above. Both
now run first.

Worth stating plainly: the AP I/F window failures only appeared **because** the orphaned
checks were rescued. That assertion had been written from a wrong summary and had never
once executed. Rescued checks that immediately fail are the expected outcome, not a
regression.

### Continued, same day — the boot table and the device closure

- **The TDTI record is decoded field by field**, resolving the two constants that had been
  listed as unexplained. `+$18` bit 4 is what places each task on the ready list; the
  segment count is computed from four slots rather than stored, which independently
  reproduces `!TST`'s `TSTNSEGS=4, TSTCSEGS=2`.
- **The MC6840 is fully specified** — reset held across programming, CR2 toggled three
  times because CR1 and CR3 share address 0, T1 loaded with `$0100`, T2 touched only by the
  self-test, T3's counter read live by the sub-tick clock.
- **The device map is closed against cached-pointer indirection.** Exactly three globals
  hold device addresses. The PTM is reached three different ways, and a sweep keyed on its
  literal address sees only the self-test — the third confidently-wrong negative of this
  kind in the project, after `$FF0204` and the `$FF0048` read.
- **The post-mortem snapshot is reachable after all** (22 `bsr` callers of `$F00186`), and
  `$0848` holds the USP rather than `a1`. Both had been recorded the other way.

### Continued — device maps completed, and a tooling defect that mattered

**A lookahead cap in every base-register sweep.** All the provenance sweeps — mine and the
harness's — walked forward from a `lea`/`movea` with a 300–500 instruction cap. A base
register can stay live far longer: `a6` holds the AP I/F base from `$F08752` to `$F09B24`,
~5,000 bytes. Uncapped, the `$FF0000` sweep finds **431 access sites instead of 328** and
one extra register (`$FF0214`). **No structural conclusion changed** — the AP I/F window map
and the three never-referenced BIM registers survive — but the caps are now raised
everywhere, so a truncated sweep fails loudly instead of passing quietly. This is the fourth
distinct false-negative mechanism in base-register analysis here.

**Device maps now complete:**

- **SBC↔SCM** is one self-test routine: page 0, `$400000`-`$403FFF`, complementary pattern
  pairs, each element read back and complemented, then the whole set repeated **backwards**.
  ~65,000 window accesses, matching the bus-log figure from the opposite direction.
- **MODE2** is only ever *set* to `$0` or `$F`; any other value on the bus is a restore.
  Two pages need backing.
- **The board status register is never written** — 16 read sites, 16 `btst` sites, zero
  writes by any path — and **`$F7001A` is never referenced at all**, though the block is
  documented as 28 bits.
- **A new constraint**: the SCM test aborts if `$F70019` bits 4 **and** 5 are both set. The
  emulator satisfies it, but for an unrelated reason.

**Two counting corrections.** The VMOD control pair carries **52** bit operations, not 28 —
ten of them use a *computed* bit number that no literal census can see. And the XLTR mode
registers are modified **register-side** (`move.w` → `bclr.b #$e,d1` → `move.w`), where bit
numbers are **mod 32**, not mod 8. A memory-side sweep finds none of them. Across the image
the split is 742 register-target versus 666 memory-target bit instructions, with 198 memory
sites carrying a literal bit number above 7 — so neither convention is the default.

### The harness guards now have tested positive controls

Three structural self-audits protect the regression harness from defects that **inflate the
pass count instead of failing**: orphaned `check()` calls below `sys.exit()`, use-before-
definition inside the emulator block, and vacuous checks (literal `True`, constant-vs-
constant).

**Every one of those guards has been wrong at least once**, all discovered in this session:

- the orphaned-check guard initially matched its own source text;
- the use-before-definition guard **lost its `sys.exit()` in an edit**, so it printed
  `FATAL` and carried on — then, once restored, over-reported six false positives because
  it did not treat `import ... as` aliases, nested tuple unpacking or function parameters
  as bindings;
- the vacuous-check audit existed only as a one-off script, and two more vacuous checks
  were introduced afterwards.

`tools/test_guards.py` now asserts each guard is **both** quiet on the real file **and**
fires on a synthetic instance of the defect it exists to catch. A guard nobody tests is
worth nothing; a fatal guard that over-reports is worse than none, because it blocks work.


### 2026-07-31 — the three-BIM anomaly is resolved

`$FF0218` bit 4 was read as "a third BIM is fitted", and forcing it derailed the boot. Both halves
were wrong. **BIM2 (`$FF0250`-`$FF025F`) is programmed unconditionally** — init writes vectors
`$47`/`$48`/`$4A` at `$F0A1B2`/`$F0A1B8`/`$F0A1C4`, and XP3I, XP4I and TCBIO1I write their control
registers at `$F06A12`/`$F06018`/`$F05DB8` — with no reference to bit 4 anywhere near them. Three
of the six live interrupt channels are on BIM2, so the machine has three BIMs whatever bit 4 says.

Bit 4 only sizes phase `$1600`'s register **walk** (16 or 24). The derailment is a separate,
now-explained fact: `$F095A2` requires `($FF0218 & $610) == $400` *after* `$FF0218 <- $400`, so
**bit 4 must read zero once armed**, and the model re-asserts it on every read. Fix and prediction
in `refs_extracted/chassis_model_spec.md`.
