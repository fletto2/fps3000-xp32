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
- Full FPS-100 archive accessible (62K AP-120B microinstructions
  + matching APAL source)

## Open issues (from doc audit + stress test)

| ID | Issue | Action |
|---|---|---|
| G1 | Memory-map row split AP I/F vs XLTR | ✓ Done (fixed in CLAUDE.md, 03-firmware.md) |
| G2 | Cable count 150 vs 169 reconciled | ✓ Done (cable_protocol_inferred.md) |
| G3 | Bomem DA3 chain-of-custody for FPS-3000 | Open — ask Lovett |
| G4 | "Am29116 sequencer" terminology | ✓ Documented as "controller" in fps164_chip_identification.md |
| G5 | EU control store: PROM vs SRAM | Open — photo re-inspection |
| G6 | UNIV FMT card role | Open — investigation |
| G7 | AP I/F variant suffix convention | Open — read Board Revision List |
| G8 | VersaBUS bandwidth analysis | Open — low priority |
| G9 | Cable doc "validation" overclaim | ✓ Done (softened to "high-confidence-hypothesis verification") |
| stress-1 | EU_ADDR width: 8 vs 11 bits needed | Open — design refinement |
| stress-2 | Missing pipeline-stall bit | Open — design refinement |
| stress-3 | DF flag: 1-bit vs 2-bit | Open — design refinement |
| stress-4 | Multiplier ordering hazard | Open — design refinement |

## Next-step paths

### Path A — connect FPS-3000 to PDP-11/73

**Bottleneck**: missing host-side AP I/F card. Substitute requires
FPGA with ≥150 user I/O. Plan in
[`host_substitute_hardware_plan.md`](../host_substitute_hardware_plan.md).

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
   the FPS-100 archive's 62K AP-120B microinstructions

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

- Project plan: [`project_plan.md`](../project_plan.md)
- Audit triage: [`mc_doc_audit_triage.md`](../mc_doc_audit_triage.md)
- Hardware substitute plan: [`host_substitute_hardware_plan.md`](../host_substitute_hardware_plan.md)
