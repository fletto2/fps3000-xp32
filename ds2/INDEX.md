# ds2/ — FPS-3000 Gap Analysis Documents

Analysis date: 2026-07-29. Written to characterize what the VersaBUS
card disassembly and emulator are missing, and what remains to be done.

## Documents

| File | Description |
|---|---|
| `GAP_ANALYSIS.md` | **Master analysis** — 27 gaps across disassembly, emulator, and cross-cutting concerns. Severity-assessed with actionable next steps. |
| `ENVVAR_HOOKS.md` | Complete inventory of 24 `FPS3K_*` environment variable hooks in the emulator. Each one papers over a hardware gap — chassis DMA, interrupt routing, panel response codes, register injection. |
| `FUNCTION_COVERAGE.md` | Per-function coverage table. 19% of FPS application code executes. TCBRDHC: 8%, TCBIO1I: 30%, XP tasks: 4-6%. Shows what each function needs to advance. |
| `CARD_COMPLETENESS.md` | Per-card emulator model assessment. SBC ~75%, XLTR ~40%, AP I/F ~25%. UNIV FMT, XP-32 AC1/AC2, MEM CTL, MAIN DATA: all 0%. |
| `RAM_SYMBOLS.md` | Complete global variable table for $0000-$10FF. 26 named globals with observed values, access sites, and verified/unverified status. |
| `PANEL_COMMANDS.md` | Three cross-referenced views: functional map (29 named codes), Am29116 SUBRC decode (38 codes, 2 groups), and PanelStatusDispatchTable (42 response codes → 4 handlers). The command→response mapping is the central unknown. |
| `REGISTER_ACCESS.md` | Every VersaBUS-address register the firmware accesses, by code site, with observed/static-only status. Complete for dynamic accesses; static-only catalog deferred to versabus_access_map.md. |
| `AM29116_EMULATION.md` | **How to emulate the Am29116** — architecture, 80-bit EU PROM, panel command SUBRC decode, emulator integration plan (3 phases), data-flow diagram, and development priorities. |
| `ADVERSARIAL_REVIEW.md` | **Systematic challenge of every document** — 3 factual errors found and fixed (A.1: $10AA attribution), 5 overconfident claims identified (B.1-B.5), 3 missing counter-arguments (C.1-C.3), 3 inconsistencies (D.1-D.3), and 2 circular reasoning issues (E.1-E.2). |
| `ROADMAP.md` | Prioritized plan for closing gaps. Tier 1 (can do now) → Tier 2 (needs hardware) → Tier 3 (full system model). |
| `ERRATA.md` | Errors found and fixed during cross-reference review. 4 fixes applied; 5 remaining informational issues documented. |

## Quick Summary of Gaps

### Critical (3 items)
1. **No chassis DMA model** — $10AA never set, host-byte path dead
2. **TCBIO1I host path deadlocks** — level-6 responder can't preempt level-7 ISR
3. **Panel command → response mapping unknown** — chassis is a black box

### High (6 items)
4. No XP-32 AC model (no microcode execution, no pipeline)
5. Only 19% of firmware executes
6. Mode-state machine in TCBRDHC uncharacterized
7. $10AA delivery mechanism unknown (chassis bus-master write, unobserved)
8. No UNIV FMT card model (in critical data path)
9. No AP I/F counterpart card model (no host side)

### Medium (8 items)
10. Self-test phase inventory incomplete
11. MC6840 PTM simplified (prescaler, external inputs)
12. No DRAM parity model
13. TCBDefinitionTable not extracted field-by-field
14. Per-channel code divergence in XP2I/XP3I shared body unknown
15. No VersaBUS arbitration model
16. No board-strap model (baud rate, parity, etc.)
17. Emulator bug: -host-srec hidden from usage()

### Low (4 items)
18. 256-byte gap at $FF0100-$FF01FF unaccounted
19. Init step gap at 0x27C
20. XLTR register byte-access behavior unmodeled
21. RAM global variable map incomplete for computed-offset accesses

## Key Unknowns Unresolvable Without Hardware Access

- BIM daisy-chain ordering (Check 3 in trace worksheet)
- Host IRQ-pin wiring level (Check 2)
- $10AA bus-master write timing and trigger condition
- EU PROM contents (80-bit × 2K Am29116 instruction stream)
- AU WCS microinstruction format (128-bit, 4K × 4 banks)
- UNIV FMT card schematic (format conversion path)
- AP I/F counterpart card identity and register layout
