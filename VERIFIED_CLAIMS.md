# Verified Claims — FPS-3000 / FPS-100 reverse-engineering project

**This is the project's careful claims-of-record document.** It
distinguishes claims by evidence tier, applies retractions caught
in the master audit (`fps3k_master_audit.md`), and corrects mistakes
the auditor LLMs themselves introduced (cross-checked against
primary sources directly).

Last full audit: 2026-05-09 (Council-of-Clankers master audit + my
primary-source spot-checks).

---

## Tier 1 — Verified against primary source (HIGH confidence)

### Hardware

**FPS-3000 EXEC card has an Am29116DCB.** Visible in Nakazoto's
photo `refs/FPS-3000/cards/05_XP32_EXEC.JPG`. Package matches
(64-pin DIP). I have viewed the photo directly via Read tool earlier
in the project; the chip marking is "AMD Am29116DCB" on board
612-4805-002.

**FPS-164 was designed in 1979 with Schottky-TTL MSI; does NOT use
Am29116.** Charlesworth & Gustafson 1986 IEEE Micro paper, Table 1:
"designed in 1979 with medium-scale integration (10 to 100 gates per
chip), required nearly 2000 chips." Am29116 first sampled 1980,
volume 1981 — too late.

**FPS-164/MAX (1985) uses ADSP-1401 as program sequencer.** Same
Charlesworth paper Table 2.

### Memory map

**SBC RAM upper 64 KB at `0x10000-0x1FFFF` is the XP-32 microcode
staging buffer.** SBC ROM disassembly shows S-record handler
validates `0x10000 ≤ addr ≤ 0x1FFFF`. Size = `4096 × 128 bits`
exactly = 1 bank of the AU WCS.

**AP I/F register block at `0xFF0000–0xFF00FF` is distinct from
XLTR register block at `0xFF0200–0xFF025F`.** SBC ROM disassembly
shows different access patterns and different functional roles.
NOTE: The 256-byte gap at `0xFF0100-0xFF01FF` is unaccounted for —
audit caught this; treat as open question.

### Microcode

**The 21 panel command codes `0x258..0x27D` decode as syntactically
valid Am29116 TOR1 SUBRC instructions.** Verified against AMD's
March 1986 bipolar Am29116 datasheet AND March 1988 CMOS Am29C116
datasheet (`refs/AMD/29116_dataSheet_Mar86.pdf`,
`refs/AMD/29C116_dataSheet_Mar88.pdf`).
Group A (`0x258..0x25F`, SRC/Dest=TORIA): `ACC ← I − RAM[R24..R31] − ¬c`
Group B (`0x260..0x27D`, SRC/Dest=TODRA): `ACC ← RAM[N] − D − ¬c`
**Semantic role** (instruction vs dispatch index vs hybrid) **remains open.**

**EU and AU control stores are BOTH writable per Hockney.** Direct
quote from `refs/FPS-5000/FPS3000_fps.pdf`:
> "...reside in a writable control store, which contains 2K 80-bit
> microcode instructions. Similarly, microcode programs for the [AU]
> reside in a writable control store (WCS) of 4K 128-bit microcode
> instructions, arranged in four banks."
**This contradicts the long-running "EU = fixed mask PROM" assumption
in CLAUDE.md, architecture.md, and earlier cliffsnotes.** See
`correction_eu_writable.md` for full implications. Audit triage
G5 marked this open; Hockney resolves it: BOTH writable.

### FPS-100 archive

**The `.APO` and `.B` files are text-format ASM100 object files
with `***CODE`-block markers; each CODE record is one line of 4
octal 16-bit words = 8 bytes = one AP-120B microinstruction.**
Verified by:
- Direct file inspection of `[327,010]VADD.APO`, `BAALIB.APO`,
  `KERNEL.B`
- LED100.FTN's LOAD subroutine (line 3031) confirms record format
- `apo_decode.py` correctly parses all files; routine counts match
  the matching `.APS` source file headers exactly (BAA: 88, BAB: 60)

**Combined microinstruction count is 13,440 across 382 routines.**
Math libraries: 11,469 (313 routines). AP-side supervisor (.B):
1,971 (69 routines). Reproducible via `python3 apo_decode.py`.

**`DAPEX.MAC` is the sole `QIO$`-to-AP chokepoint in the FPS-100
host stack.** 32-file 8-tier inventory (`fps100_callers_inventory.md`)
confirms: only `DAPEX.MAC` issues `QIO$` with `LUN` assigned to AP.
217 HSR stubs across 7 files all funnel through `JSR APEX`.

**SIM100.FTN compiles cleanly with `gfortran -std=legacy -fno-automatic`
(no `-ffixed-line-length-none`).** 217 KB .o file produced. Linked
with minimal IUTIL stubs into `sim100_build/sim100.bin` (115 KB
ELF), runs to interactive `*` prompt; segfaults thereafter due to
documented COMMON-block IORM size mismatch (772 vs 920 bytes — real
F77→gfortran porting bug).

---

## Tier 2 — Strong inference (MEDIUM-HIGH confidence)

### XP-32 layout

**The proposed 128-bit XP-32 microinstruction layout's FIELD NAMES
inherit from AP-120B/FPS-164.** SPAD/Adder/Branch/Data Pad/Multiplier/
Memory groups, plus the field names within each group, appear in
Touzeau 1984 fig 2 and FPS-7319 references.

**However, FIELD WIDTHS do NOT cleanly inherit.** Audit caught this:

| Group | FPS-164 width | Consensus XP-32 width | Inheritance? |
|---|---:|---:|---|
| SPAD | 12 | 23 | name only, width nearly 2× |
| Adder | 9 | 12 (×2 = 24) | name only, doubled for two adders |
| Data Pad | 19 | 29 | name only, widened |
| Multiplier | 5 | 9 | name only, widened |
| Memory | 9 | 9 | exact match |
| Branch | 9 | 9 | exact match |

**Earlier wording "first 103 bits inherit cleanly from documented
AP-120B → FPS-164 evolution" was misleading and is RETRACTED.**
Corrected language: "field names and group ordering inherit; widths
are XP-32-specific re-allocations."

### FPS-100 → FPS-3000 architecture

**The FPS-3000 SBC plays the role FPS-100's AP-side `KERNEL.S`
played in Super-100 mode.** Both implement priority-based ready-queue
task dispatch. The novelty in FPS-3000 is moving this from AP-side
to host-side (the SBC). Strong-inference based on:
- RMS68K task structure mirrors KERNEL.S/EXTASK pattern
- The FPS-3000 likely has no AP120-mode equivalent — SBC always arbitrates

### Panel commands as RPC dispatch

**The 21 panel codes are likely HSVC-style RPC dispatch entries**
(analogous to FPS-100's HSVC.S → SYSSVC.S pattern), not standalone
opaque opcodes. Strong-inference based on:
- HSVC dispatch tables in FPS-100 are exactly this kind of structure
  (sparse opcode → handler entries)
- 21 codes split into 2 operand-pattern groups matches the
  HSVC-table layout
- Three live interpretations (literal Am29116 instruction / dispatch
  index / hybrid) are all consistent with HSVC-style routing

**Confirmation requires** EU PROM dump or live bus trace.

---

## Tier 3 — Plausible speculation (LOW-MEDIUM confidence)

These claims are consistent with available evidence but lack direct
support; would need primary verification to promote.

- **WTL-1232/1233 are the FPS-3000 Weitek parts.** Hockney names
  "WTL-1032/1033"; bitsavers has WTL-1232/1233 datasheets functionally
  identical. No primary source connects them.
- **`0x8004`/`0x8005` semantics**: observed in firmware as
  REQUEST-TRANSFER and CONTINUE-TRANSFER opcodes at the AP I/F
  command register. Earlier "command-with-flag (high bit = strobe)"
  interpretation was speculative and is RETRACTED — what the AP I/F
  hardware actually does with these values is unknown without a
  schematic or bus trace.
- **HPVP = FPS-100 with Bomem rebranding.** Consistent with all
  available evidence: optional in LOABOM, uses HP-prefixed file
  set, no APDRV in base RSX install. **NOT proven.**
- **`ChannelConfigOffsetTable` at `F046E0` contains 4 longwords
  `0x244, 0x246, 0x250, 0x252`.** Identified by MC pass as the
  per-channel XLTR config offsets. Audit notes the addresses
  are not contiguous (gap at `0x248-0x24F`) — should be
  re-verified by examining raw disassembly bytes.
- **EU PROM size is 2K × 80-bit per Hockney.** Plausible based on
  Hockney's text; not yet confirmed by chip-count on the EXEC photo.

---

## Tier 4 — RETRACTED or wrong (real removals)

These claims appeared in earlier project docs and are removed.

| # | Retracted claim | Reason |
|---|---|---|
| R1 | "First 103 bits inherit cleanly from FPS-164" | Audit-verified: field widths differ significantly (SPAD 12→23, Adder 9→12, Data Pad 19→29, Multiplier 5→9). Names + ordering inherit; widths don't. |
| R2 | "EU control store is fixed mask PROM" | Hockney explicitly says writable. Long-running mistake corrected. |
| R3 | Detailed DMA sub-fields (specific 4-bit op + 4-bit src + 4-bit dst) | Pure LLM speculation — both DS and GLM proposed slightly different specifics, classic hallucination pattern |
| R4 | Detailed EU coordination sub-fields (8-bit addr + 2-bit ctrl) | Same — speculative + mathematically inconsistent with claimed 2K PROM |
| R5 | "Multiplier control too late for pipeline lead" objection | Wrong about FPS-164 — FPS-164 also places multiplier AFTER Data Pad. The objection assumed AP-120B convention. |
| R6 | "DF may be 2 bits encoding parcel class" | Unsupported speculation; FPS-164 uses 1-bit DF |
| R7 | HPVP = FPS-100 (Bomem marketing name) | Original assertion was unsourced; remains as Tier-3 speculation |
| R8 | HPVP = FPS-3000 | Project owner correction |
| R9 | "62,130 AP-120B microinstructions" | Was bytes/8 of text-format files; corrected to 11,469 (math) + 1,971 (.B) = 13,440 |
| R10 | LLM-fabricated Hockney p.240/241 quotes (Am2910A + Am2901/2903; "EU's writable control store" attributed to p.241) | Hockney text doesn't include the cited content at those locations; the **claim** that EU is writable IS correct, but cite Hockney generally not specific page |

### Auditor LLM hallucinations to NOT apply

The master audit itself (`fps3k_master_audit.md`) contained several
auditor errors that I have NOT applied to the project:

| Auditor claim | Why I rejected |
|---|---|
| "May 2026" date is fabricated/typo | Current date IS 2026-05-09 per system clock; audit was wrong about this being a future date |
| Hockney "zero hits for 2910/2901/29116" claim is unverifiable | I directly ran `pdftotext` on the local PDF and confirmed zero hits — the claim is verifiable, just not by the LLM at audit time |
| EU control store is "fixed PROM" with MEDIUM confidence | Both DS and GLM converged on this wrong reading. Direct primary-source check (Hockney text) says writable. |
| "Field names inherit but widths don't" framed as catastrophic | Real point worth addressing (R1) but not as severe as audit framing — much of the field-by-field semantics still carry over |

---

## Open questions (acknowledged unknowns)

1. **EU control-store storage type** on the FPS-3000 EXEC card —
   Hockney says writable but the specific chips on the card (bipolar
   PROMs vs Am2168 SRAMs) need photo re-examination given the
   updated reading.
2. **EU microcode upload path** in the SBC ROM — if EU is writable,
   how is it loaded? Currently we trace only AU upload via the 64KB
   staging buffer.
3. **Per-panel-code semantics** — which of the 21 panel codes maps
   to which AP-side handler? Three interpretations remain open;
   disambiguation requires EU contents.
4. **HPVP identity** — still unproven. Most plausible candidates:
   FPS-100 with Bomem rebrand, or some other vector-processor
   product.
5. **`0x8004`/`0x8005` actual hardware semantics** — what does the
   AP I/F do with these values? Need a schematic or bus trace.
6. **256-byte gap at `0xFF0100-0xFF01FF`** in the AP I/F register
   range — unaccounted for in current memory map.
7. **WTL-1032/1033 vs WTL-1232/1233** — same parts or different?
8. **Last 25 bits (DMA / EU coord / Special-Op) of consensus XP-32
   layout** — purely speculative; need primary source.
9. **Bit positions for the 24-field SPLIT recipe** — the field
   names and widths come from SIM100 source, but the specific bit
   recipes may need cross-checking against FPS-7319 directly.

---

## Methodology lessons (refined)

These are the rules the project should now operate under:

1. **Photo claims must reference actual photo inspection.** "A photo
   exists" ≠ "we have examined the photo and confirmed the markings."
   Photo-dependent claims default to MEDIUM confidence until the image
   is opened.

2. **LLM-fabricated citations must be retracted along with the claim
   they support.** If an audit catches a hallucinated citation, the
   claim depending on it doesn't survive — even if the claim "sounds
   right." DS and GLM both fell into this trap during the audit
   (accepting "post-G1 fix" as fact while flagging the citation).

3. **Auditor LLMs hallucinate too.** The master audit itself contained
   incorrect claims (EU=fixed-PROM despite Hockney's actual text;
   "May 2026 is a future date"). Always cross-check audit findings
   against primary source — same standard as the original claims.

4. **"Inheritance" must specify what's inherited.** Field names,
   group ordering, bit-width, bit-position — these are different
   things. Saying "X inherits from Y" without specifying which
   aspects creates false confidence.

5. **Mathematical contradictions are red flags.** A claim that
   asserts both "2K PROM" and "8-bit address field" is internally
   inconsistent and can't be both right.

6. **Negative claims about document contents need methodology.**
   "PDF X contains zero hits for Y" is verifiable IF the search
   methodology is shown. Without that, it's a hallucination pattern.

7. **Primary-source verification is the gold standard.** Even when
   an LLM consensus says X, if I can directly inspect the source
   document and find Y, Y wins. The Hockney EU=writable finding
   is a clean example.

8. **Speculation must be marked.** Tier-3 claims shouldn't accidentally
   become Tier-1 through repeated citation. Each consensus document
   should ride along its evidence tier.

---

## What this audit pushed UP

The audit and primary-source verification PROMOTED several claims
to higher tiers:

- **EU control store is writable** moved from "open question (G5)"
  to Tier-1 (Hockney primary source)
- **Panel codes are HSVC-style RPC dispatch** strengthened from
  "speculation" to Tier-2 strong inference (FPS-100 archive
  parallel is robust)
- **The 11,469 + 1,971 = 13,440 microinstruction count** moved from
  "current best" to Tier-1 (reproducible via `apo_decode.py`)
- **DAPEX is the QIO chokepoint** moved from "inferred from grep"
  to Tier-1 (8-tier inventory across 32 files)

## What this audit pushed DOWN

- **"First 103 bits inherit cleanly"** moved from "high confidence"
  to Tier-4 retraction — field WIDTHS don't inherit
- **DMA + EU-coord detailed sub-fields** moved from "low confidence"
  to Tier-4 retraction — pure speculation
- **EU = fixed PROM** moved from "long-standing assumption" to
  Tier-4 retraction (Hockney contradicts)
- **"Multiplier control too late"** moved from "open adversarial
  objection" to Tier-4 retraction (FPS-164 places it the same way)

## Status of project plan after this audit

| Goal | Status before audit | Status after audit |
|---|---|---|
| Connect FPS-3000 to PDP-11/73 | active line | active line |
| Devise XP-32 microcode | blocked on EU PROM | partially unblocked: EU is writable, so we need to find the upload path in the SBC ROM (new task) |
| Recover BOM* application disks | open lead | still open |
| Recover XPMLIB binary | open lead | still open |
| Validate 128-bit layout | needed primary source | constraints sharpened (R1, R3, R4, R5, R6 retractions) |

The biggest practical change: **the EU is writable**, which means
recovering the EU contents at runtime is theoretically much easier
than the long-assumed PROM-desolder approach. Memory dump while AP
is powered would suffice.
