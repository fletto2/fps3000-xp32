# Doc-audit triage — wheat vs chaff

The Council-of-Clankers audit in `mc_doc_audit.md` produced ~120 KB of
critique across 4 doc clusters × 2 LLMs. **Many findings are real and
actionable. Several are hallucinations.** This file separates the two.

## Methodology

For each high-priority finding I cross-checked the audit's claims
against the actual source text — both our docs and the cited primary
references (Hockney chapter PDF, refs/FPS-164/, refs/FPS-3000/).

LLM auditors confidently cite page numbers and quotes that don't
exist in the cited PDFs. Treat every audit citation as a claim that
must be verified, not as evidence.

## Verified-genuine findings (act on these)

### G1. Memory-map collision: AP I/F vs XLTR addresses (DS A-2.3)

**Real.** `CLAUDE.md`'s memory-map row says
`0xFF0000–0xFF025F | AP I/F + VersaBUS XLTR command/data interface` —
combining both ranges. Other sections correctly distinguish
`0xFF0000+` (AP I/F, host-visible) from `0xFF0200+` (XLTR, SBC-private).
The combined range is misleading.

**Fix:** split the row into two — `0xFF0000–0xFF00FF AP I/F` and
`0xFF0200–0xFF025F XLTR`.

### G2. Cable signal count: 150 vs 169 inconsistency (GLM A-INT.CONT)

**Real.** `cable_protocol_inferred.md` line 17 says ~150 logical signals,
line 180 has the table sum **`TOTAL ~169`**, and lines 192/205 reuse
"150" elsewhere. These are inconsistent without reconciliation.

**Fix:** reconcile the count. The table sum (169) is the authoritative
count; the "150" headline figure is approximate. Make this explicit.

### G3. Bomem DA3 may have used FPS-3000, not just FPS-100 (DS A-4.4)

**Real.** Our docs assume the FPS-3000 is unrelated to Lovett's Bomem
DA3 (separate later acquisition). But:
- the timeline (FPS-3000 c.1983, DA3 1981–2000) overlaps
- the FPS-3000 was acquired alongside the DA3 system
- LOABOM.CMD references `loahpvp` (Bomem's name for the FPS-100, the
  ancestor) but the actual chassis at Lovett's site is an FPS-3000

**Action:** check Lovett's chain-of-custody; the FPS-3000 may
genuinely be the DA3's array processor (a later upgrade replacing
the FPS-100).

### G4. Am29116 is a microprocessor, not a microprogram sequencer (term.)

**Real (terminology).** Our docs call the Am29116 the "EU sequencer".
That's loose — the Am29116 is a 16-bit microprocessor with its own
instruction set and on-chip PC; it is *not* a microprogram sequencer
in the bit-slice sense (the way Am2910 is). It plays the role of
"EU controller" by running its own program from the 80-bit PROM.

**Fix:** rename "EU sequencer" → "EU controller" or "EU instruction
processor" throughout, to avoid implying an Am2910-style architecture.

### G5. EU control store: PROM vs SRAM — **RESOLVED 2026-05-09**

**EU is WRITABLE** per Hockney's primary text. Direct quote from
`refs/FPS-5000/FPS3000_fps.pdf`:

> "...reside in a writable control store, which contains 2K 80-bit
> microcode instructions."

The original audit's hallucinated p.241 quote was rejected, but the
underlying fact is correct: BOTH EU and AU control stores are
writable. The "EU = fixed mask PROM" model in our docs was wrong.

See `correction_eu_writable.md` for full implications. The new
follow-up question: where in the SBC ROM is the EU upload path?
(separate from the AU upload at `0x10000-0x1FFFF` staging).

Status: this triage item is closed; a new task supersedes it.

### G6. UNIV FMT card role in microcode upload underexamined (DS A-4.1)

**Real.** Our microcode-upload-path block diagram routes
`SBC → XLTR → UNIV FMT → XP-32 bus`, but we never explain what
UNIV FMT *does*. It sits in the data path but its function is opaque.

**Action:** investigate; possibilities include format conversion
(VersaBUS 16-bit ↔ XP32-bus 32-bit), bit-width adaptation for the
128-bit WCS write port, or arbitration between channels.

### G7. AP I/F card "-011" vs "-401" variant interpretation (GLM A-1)

**Plausible.** GLM claims the `-011..-017` suffixes on the host-side
AP I/F card encode "which AP family the card serves" (RDCP/FPS100/
AP120B), and `-401..-403` encode XP32 chassis-side variants.

**Action:** check the FPS Board Revision List PDF directly for the
suffix convention before adopting either reading.

### G8. VersaBUS timing constraints not analyzed (GLM A-MISSED)

**Real.** Our docs talk about VersaBUS as a 16-bit MC68000-style bus
but never analyze whether its bandwidth could become a bottleneck
between the SBC and the XP-32 ACs (especially during S-record
upload). Worth at least estimating.

### G9. Confidence-miscalibration on cable correspondence (DS A-5.1, GLM A-5)

**Real.** `cable_protocol_inferred.md` rates pin-correspondence as
"validation, not discovery". That overclaims — we have a netlist for
a *related* card (4448), not the actual host-side AP I/F. The
correspondence is a *strong prior*, not a confirmation.

**Fix:** soften the language; rate as "high-confidence hypothesis
pending physical verification".

## Hallucinated / misread audit findings (ignore these)

### H1. DS A-1.1: "Hockney p.240 says XP-32 uses Am2910A + Am2901/Am2903"

**Fabricated citation.** I searched the actual Hockney PDF
(`refs/FPS-5000/FPS3000_fps.pdf`) for "29116", "2901", "2910",
"sequencer", "bit-slice", "AMD", "Am" — *no matches*. The chip
identification DS attributes to Hockney is not in Hockney.

The Nakazoto chip photos clearly show an **Am29116** on the EXEC
card. The "real EU sequencer is hiding under a heatsink" speculation
is unsupported.

### H2. GLM A-1: "WTL-1232/1233 is on bitsavers and Hockney's 1032/1033 is wrong"

**Misread.** Our `architecture.md` already states this — the audit
found it as a "wrong claim" because it didn't read the surrounding
text correctly. Our doc says: Hockney *the book* uses 1032/1033,
which are not on bitsavers; the actual Weitek production parts on
bitsavers are 1232/1233. We resolve this correctly already.

### H3. DS C-1.1: "Am29116 cannot autonomously decode 16-bit commands; needs Am2910/Am2911"

**Architecturally wrong.** The Am29116 is a complete 16-bit
microprocessor with its own program counter. It does not require an
external sequencer. The audit's confidence on this claim is
misplaced; the Am29116 datasheet itself contradicts it.

### H4. DS A-1.2 cited quote: "Hockney p.241: 'The EU's control store is writable...'"

**Fabricated.** Hockney's PDF does not contain that quote. The
underlying question (is the EU CS writable?) is genuinely open per
G5, but the audit's "evidence" is invented.

### H5. GLM A-INT.CONT: "CLAUDE.md describes EU PROM as fixed while implying SRAM storage"

**Misread.** GLM is parsing the same sentence two ways. Our docs
consistently say EU = fixed PROM; SRAM refers to the AU WCS only.
There is no internal contradiction here.

## Net audit yield

- 9 verified genuine issues to fix or investigate (G1–G9)
- 5 spurious findings to discard (H1–H5)
- ~120 KB of LLM critique total

The audit was worth running. **But every individual finding had to
be cross-checked against the actual source text** — the LLMs invent
plausible-sounding citations to support their critiques. The
audit's value is in *surfacing questions to investigate*, not in
delivering authoritative corrections.

## Top fix-list (in order)

1. Fix the memory-map row (G1) — easy, factual.
2. Reconcile 150 vs 169 cable count (G2) — easy, factual.
3. Soften "validation" → "strong-prior hypothesis" in cable doc (G9).
4. Rename "Am29116 sequencer" → "Am29116 controller" globally (G4).
5. Investigate Bomem chain-of-custody for FPS-3000 (G3) — ask Lovett.
6. Re-examine EXEC card photos for EU control-store chip ID (G5).
7. Document UNIV FMT card role (G6) — open question.
8. Verify AP I/F variant suffix convention (G7).
9. Estimate VersaBUS bandwidth (G8).
