# 06 — Validation: what's known, unknown, and how we'd check

## Three layers of certainty

```
ROM evidence          ─── HIGH confidence ──── (we have the bytes)
Family inheritance    ─── MEDIUM confidence ── (FPS-100/164 docs apply)
LLM-inferred details  ─── LOW confidence ────── (need bench check)
```

## What's locked

- **64 KB SBC ROM contents** byte-for-byte identical across every
  copy in circulation
- **MC68000 disassembly** with ~80% functional understanding
- **Panel command codes** decode unambiguously as Am29116 SUBRC
  instructions (verified against datasheet)
- **VersaBUS register addresses** and protocol flow (poll ready/done
  bits, 0x8004/0x8005 opcodes)
- **Memory map** (with G1 fix: AP I/F vs XLTR ranges separated)
- **Boot task list** via TDTI scan of `TCBDefinitionTable`
- **`ChannelConfigOffsetTable @ F046E0`** (4 longwords of XLTR config
  offsets) — found by MC pass 2, now in `fps3k_clean.asm`

## What's plausible-but-unverified

- **128-bit XP-32 AU microinstruction layout**, first 103 bits
  HIGH confidence by inheritance (`mc_xp32_microcode_inference.md`)
- **EU = fixed PROM, AU = writable WCS** — chip identification not
  yet definitive (audit G5)
- **Cable pin correspondence** to 4448 netlist — strong hypothesis,
  not yet bench-probed
- **Bomem DA3 chain-of-custody** for the FPS-3000 (audit G3)
- **Hockney's "WTL-1032/1033"** likely refer to production parts
  WTL-1232/1233 (bitsavers has only the latter)

## What's genuinely unknown

1. **EU PROM contents** — 2K × 80 bits = 20 KB of EU microcode never
   read. The biggest single piece of missing evidence.
2. **Panel-code semantic role** — are codes literal Am29116
   instructions, dispatch indices, or hybrid? Three interpretations
   compatible with the ROM evidence.
3. **Last 25 bits of the AU layout** — DMA (12), EU coordination (10),
   Special-Op/IO (3). No precedent in AP-120B/FPS-164.
4. **UNIV FMT card role** — sits in the microcode-upload data path
   between XLTR and XP32-bus, function not analyzed (audit G6).
5. **AP I/F variant suffix** — `-011..-017` vs `-401..-403`
   convention not verified against FPS Board Revision List
   (audit G7).
6. **Whether the FPS-3000 was the Bomem DA3's array processor** —
   timeline overlaps, no chain-of-custody confirmation (audit G3).

## How to check what's plausible-but-unverified

| Check | Method | Cost |
|---|---|---|
| Layout first 103 bits | Disassemble FPS-100 `.APO` files via `SIM100.FTN` SPLIT, cross-check against `.APS` source | Software only |
| Layout last 25 bits | Bus trace on a running FPS-3000 during XPMLIB call | Lab time |
| EU PROM contents | Desolder + read with bipolar-PROM programmer | Risk to chassis |
| Cable pin correspondence | Multimeter probe with chassis powered | Hours |
| EU vs AU storage | Re-inspect EXEC card photo, identify chip part numbers | Software only |
| Bomem chain-of-custody | Ask Lovett | Email |
| AP I/F variant | Read FPS Board Revision List PDF | Hours |

## Validation paths without an EU PROM dump

The stress test (`mc_xp32_layout_stress.md`) explored what could be
validated even if the EU PROM is never read. Result: most of the
work is unblocked by the FPS-100 archive — see
[07-resources.md](07-resources.md).

The PROM dump is *helpful* but not *essential* for layout validation
if XPMLIB binary kernels can be obtained or bus traces taken.

## Where to read more

- Audit + triage: [`mc_doc_audit.md`](../mc_doc_audit.md), [`mc_doc_audit_triage.md`](../mc_doc_audit_triage.md)
- Stress test: [`mc_xp32_layout_stress.md`](../mc_xp32_layout_stress.md)
- XPMLIB search: [`xpmlib_search_results.md`](../xpmlib_search_results.md)
- Project plan: [`project_plan.md`](../project_plan.md)
