# 08 — Methodology

How the inferences in this project were produced.

## Council-of-Clankers (CoC)

A pattern reused across most of the inference work. Two LLMs
(DeepSeek-chat + GLM-4.5-air) consulted independently via OpenAI-
compatible APIs, then cross-critiqued, then synthesized. Per
`~/src/claude/libs/MONTECARLO.md`.

Three modes:

- **Cooperative** — both answer independently; accept when both
  YES (default for disassembly annotation)
- **Adversarial** — A answers; B sees A's answer and challenges; A
  defends or revises (used for the disasm pass on disagreed samples)
- **3-stage stress** — adversarial / cooperative / paranoid postures
  with and without specific resource assumptions

Why two LLMs: independent failure modes. DeepSeek tends to invent
plausible-sounding citations; GLM tends to over-generalize. The
intersection is signal; the difference is the audit target.

## Validation: every LLM citation gets cross-checked

Critical lesson from the doc audit (`mc_doc_audit_triage.md`):
**LLM auditors fabricate citations confidently.** DeepSeek invented
a "Hockney p.240: XP-32 uses Am2910A + Am2901/Am2903" quote that
doesn't exist in the actual PDF. GLM made similar invented citations.

Workflow consequence: every audit/inference finding gets
cross-checked against the actual source text via `pdftotext` /
`grep` before being acted on. Of 14 high-priority audit findings,
**9 were genuine and 5 were fabricated** (G1–G9 vs H1–H5).

## Monte Carlo annotation pipeline

`mc_fps3k.py` samples disasm lines, presents each in a 21-line
context window, asks both LLMs for purpose, and accepts when:

- one model gives a specific answer with ≥1 domain keyword **OR**
- both agree (BOTH = highest signal)

Sampling is biased 70%/30% toward the XP-32 communication kernel
range (`F046xx-F058xx`).

Pass 1 (15 rounds, 644 annotations) — `mc_results.md`
Pass 2 (5 rounds, 250 annotations, 99.6% YES, 77.2% BOTH) —
`mc_fps3k_pass2_summary.md`. Updated context block included recent
inferences (panel-code SUBRC decode, consensus 128-bit layout, audit
fixes) — sharpened model agreement.

## Inference-from-evolution

Where direct evidence is missing, we infer XP-32 properties by
**bracketing**: whatever the documented AP-120B (FPS-7319) and FPS-164
(Touzeau 1984 fig 2 + APSIM64) microinstructions encode, the XP-32
must encode at minimum (per APAL compatibility). Differences trace
to documented FPS-3000-specific hardware: 2 adders + 1 multiplier,
DMA controller, IEEE-754 32-bit, EU/AU split with Am29116.

This is the basis for the consensus 128-bit layout. First 103 bits
(SPAD through Memory) are well-bracketed; last 25 bits (DMA, EU
coord, Special) are speculative.

## Adversarial stress tests

Once a consensus is reached, we attack it from three postures:

- **Adversarial** — find every plausible flaw or contradiction
- **Cooperative** — extend with concrete sub-field encodings
- **Paranoid** — what's *subtly* wrong that wouldn't show up in
  inspection but would show up the first time microcode was uploaded?

Each posture run twice — with and without a key resource
assumption (e.g. "EU PROM eventually readable" vs "never readable").
The diff reveals which findings are robust vs assumption-dependent.

## Documenting hallucinations

When an LLM finding turns out to be fabricated, we record the
hallucination explicitly (e.g. H1–H5 in
`mc_doc_audit_triage.md`). This protects against re-running the
inference and getting the same wrong answer treated as new evidence.

## Where to read more

- Council methodology: `~/src/claude/libs/MONTECARLO.md`
- Audit + triage: [`mc_doc_audit.md`](../notes/mc_doc_audit.md), [`mc_doc_audit_triage.md`](../notes/mc_doc_audit_triage.md)
- Past inference rounds: [`mc_xp32_debate_log.md`](../notes/mc_xp32_debate_log.md), [`mc_panel_code_inference.md`](../notes/mc_panel_code_inference.md)
