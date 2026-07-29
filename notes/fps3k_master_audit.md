# Master Verification Audit

Comprehensive Council-of-Clankers verification of every load-bearing claim across the FPS-3000 / FPS-100 reverse-engineering project. 7 clusters × cooperative + adversarial × 2 LLMs + synthesis pass.

---

## Final synthesized claims (DeepSeek)

# Verified Claims — FPS-3000 / FPS-100 reverse-engineering project

## Tier 1: HIGH-confidence claims (verified against primary source)

- **FPS-164 does NOT use Am29116 (designed 1979 with MSI TTL)** [Charlesworth & Gustafson (1986) IEEE Micro paper, Table 1: "designed in 1979 with medium-scale integration (10 to 100 gates per chip), required nearly 2000 chips." Am29116 first sampled 1980, volume shipments 1981-82 — too late for 1979 design freeze. HIGH confidence.]

- **64 KB staging buffer = 1 bank of 4K × 128-bit AU WCS** [Simple arithmetic: 4096 × 128 bits = 4096 × 16 bytes = 65,536 bytes = exactly 64 KB. SBC ROM maps upper DRAM region 0x10000–0x1FFFF as 64 KB staging buffer. HIGH confidence.]

- **Panel codes 0x258-0x27D decode as syntactically valid Am29116 TOR1 SUBRC instructions per AMD datasheet** [Explicitly cites AMD March 1986 bipolar datasheet and March 1988 CMOS datasheet. Correct 5-field instruction format verified against datasheets. Document self-corrects earlier wrong analysis. HIGH confidence — but semantic interpretation (executed as instructions vs. dispatch indices) remains unresolved.]

- **DAPEX.MAC is the primary user-mode QIO-to-AP dispatcher in the FPS-100 stack** [Comprehensive 8-tier inventory with 32 files referencing APEX, documented call chain: user FORTRAN → HSR stub → JSR APEX → DAPEX.MAC → QIO$ → APDRV → hardware. 217 HSR stubs across 7 files. HIGH confidence.]

- **.APO format is text-based with ***CODE markers and 4 octal words per microinstruction** [Derived from LED100.FTN's LOAD subroutine (line 3031). Sample output shows octal addresses and 8-byte hex representations consistent with 4 × 16-bit PDP-11 words = 8 bytes. HIGH confidence.]

- **24-field SPLIT recipe structure is canonical for AP-120B microinstruction format** [Field names (FV# 1-24) match known AP-120B architecture: S-Pad operations, FALU functions, DPX/DPY data pad operations. Total bit count sums to 64 bits, matching 8-byte microinstruction width. HIGH confidence — but exact bit positions within 64-bit word not specified.]

- **HPVP is NOT the FPS-3000 (per project owner)** [Documented assertion. MEDIUM confidence — see Tier 2 for reasoning.]

## Tier 2: STRONG-INFERENCE claims (well-supported by analogy/inheritance)

- **FPS-3000 EXEC card carries an Am29116DCB** [Nakazoto photo (refs/FPS-3000/cards/05_XP32_EXEC.JPG) shows 64-pin DIP labeled "AMD Am29116DCB" on board 612-4805-002. Photo path exists but has not been independently verified by examining the actual image. Am29116 is 64-pin DIP, correct package. MEDIUM confidence — downgraded from HIGH because photo analysis not independently confirmed.]

- **FPS-3000 EU control store is fixed PROM (not writable SRAM)** [Hockney fig. 2.53 explicitly shows "2K × 80 bit" EU control store labeled as PROM. SBC ROM never uploads EU microcode — only AU WCS. Panel-command interface must be alive at power-on. Am29116 standard architecture executes from its own PROM. MEDIUM confidence — contradictory evidence within cluster (cliffsnotes/02-hardware.md calls it open question G5).]

- **AP I/F at 0xFF0000-FF00FF and XLTR at 0xFF0200-FF025F are separate register blocks** [Firmware traces show distinct addresses: AP I/F block at 0xFF0000 (command/status), 0xFF000E (command-arg), 0xFF0048/4E, 0xFF0068/6E, 0xFF0088/8E, 0xFF00A8/AE (per-channel data). XLTR block at 0xFF0200 (Mode 0), 0xFF0202 (Mode 1), 0xFF0204 (Channel Select), 0xFF0214 (Data Lo), 0xFF0216 (Data Hi). MEDIUM confidence — no schematic confirms physical separation; 256-byte gap at 0xFF0100–0xFF01FF unaccounted for.]

- **Microinstruction field names and group ordering inherit from AP-120B/FPS-164** [Field names (SOP, SH, SPS, SPD, FADD, COND, DISP, etc.) and group ordering (SPAD→Adder→Branch→Data Pad→Multiplier→Memory) documented in FPS-164 literature (Touzeau, Curington). MEDIUM confidence — bit positions and widths are NOT inherited; they are re-mapped with significantly different widths (SPAD: 23 vs 12, Adder: 12 vs 9, Data Pad: 29 vs 19, Multiplier: 9 vs 5).]

- **HPVP is NOT the FPS-3000 (per project owner)** [Claim asserted in documentation but "project owner" not named, authority not established, statement not captured in any auditable primary source. MEDIUM confidence — plausible but unverifiable from available evidence.]

## Tier 3: PLAUSIBLE-SPECULATION (consistent but not directly evidenced)

- **WTL-1232/1233 are the FPS-3000 Weitek parts** [Hockney p.240 names "WTL-1032 multiplier" and "WTL-1033 adder." Bitsavers has WTL-1232/1233 datasheets (July 1986) that are functionally identical: 32-bit IEEE-754 single-precision FP multiplier/ALU. No primary source connects 1032/1033 to 1232/1233. WTL-1232/1233 datasheet dated 3 years after FPS-3000 introduction (1983). LOW confidence — pure speculation with no direct evidence.]

- **0x8004/0x8005 semantics as "command-with-flag" (high bit = strobe)** [Firmware writes 0x8004 to 0xFF0000 at F056CA (command initiation), 0x8005 at F05742 (32-bit data follow-up). SBC polls bit 14 (complete) and bit 13 (error). "High bit = strobe" interpretation is entirely invented — no source document makes this claim. LOW confidence — actual hardware semantics completely unknown.]

- **EU_ADDR width of 8 bits is wrong (PROM is 2K = 11 bits needed)** [EU described as "2K × 80-bit" (2048 words), requiring 11 address bits, but consensus layout allocates only 8 bits (116-123). However, 2K claim is explicitly marked as "not yet definitive." Possible indirection, paging, or sequencer-provided address bits. LOW confidence — premise (2K PROM) not verified.]

- **DF (Data Format) flag is 1-bit (not 2-bit)** [AP-120B and FPS-164 both use 1-bit DF selecting between primary/secondary parcels. 2-bit proposal would imply 4 parcel classes with no architectural rationale. LOW confidence for 2-bit alternative — no evidence provided.]

- **ChannelConfigOffsetTable at F046E0 contains 4 longwords 0x244, 0x246, 0x250, 0x252** [Hypothesized from firmware analysis but no disassembly evidence shown. Addresses not contiguous (gap at 0x248-0x24F). LOW confidence — unverified hypothesis with no supporting instruction bytes.]

- **HPVP = FPS-100 with Bomem rebranding** [Consistent with all available evidence: no APDRV in base RSX install (but missing loahpvp.cmd could install it), HPVP optional in LOABOM.CMD flow, Bomem RSX disks have zero AP references. MEDIUM confidence — consistent but evidence is sparse; near-empty tautology.]

## Tier 4: RETRACTED-OR-WRONG (claims to remove from project)

- **"Post-G1 fix" for AP I/F / XLTR separation** — **RETRACTED**. This phrase appears nowhere in any source document. It is an LLM hallucination fabricated by the GLM peer audit. The GLM peer correctly identified this as unsupported but then accepted the claim at HIGH confidence anyway — a serious methodological error.

- **"First 103 bits inherit cleanly from FPS-164"** — **RETRACTED**. The field widths differ significantly from FPS-164 (SPAD: 23 vs 12, Adder: 12 vs 9, Data Pad: 29 vs 19, Multiplier: 9 vs 5). This is not "clean inheritance" — it's a complete re-layout with wider fields. The document's HIGH confidence on these fields is unjustified. Field names inherit; bit positions and widths do NOT.

- **"Identical to FPS-164" for SPAD, Adder #1, Branch, Data Pad, Multiplier, Memory** — **RETRACTED**. Every field except Memory has a different width than FPS-164. The document contradicts itself by claiming both "identical" and "23 bits" for SPAD when FPS-164 has 12 bits.

- **Detailed DMA sub-fields (4-bit opcode, 3-bit source/destination, etc.)** — **RETRACTED**. No evidence supports these specific allocations. They are LLM-generated plausible-sounding details appearing in both DeepSeek and GLM proposals with different specific values — a classic LLM hallucination pattern.

- **Detailed EU coordination sub-fields (8-bit address, 2-bit control, 1-bit sync)** — **RETRACTED**. No evidence supports these specific allocations. The 8-bit address is mathematically inconsistent with the claimed 2K PROM.

- **"Multiplier control too late for pipeline lead"** — **RETRACTED**. The FPS-164 places multiplier AFTER Data Pad (bits 50-54 vs 31-49), matching the consensus layout. The objection is based on AP-120B convention, not FPS-164 convention. The adversarial objection is factually wrong about FPS-164 ordering.

- **"DF may be 2 bits"** — **RETRACTED as unsupported speculation**. No evidence or architectural rationale provided. FPS-164 uses 1-bit DF. The 2-bit proposal would imply 4 parcel classes with no proposed meaning for additional states.

- **"May 2026" investigation date in fps164_chip_identification.md** — **RETRACTED as suspicious/fabricated**. "May 2026" is a future date relative to document creation context. This is either a typo (2025 → 2026) or a fabricated timestamp. Undermines document credibility.

- **"Hockney PDF contains zero hits for 2910, 2901, 29116, sequencer, bit-slice"** — **RETRACTED as unverifiable**. PDF may be scanned with poor OCR. Search terms may not match actual text. This is an unverifiable negative claim — a classic LLM hallucination pattern.

- **"No FPS-164 units survive"** — **RETRACTED as overstatement**. Corrected to "no FPS-164 units in Nakazoto public inventory." Computer History Museum has at least one FPS-164 per document's own statement.

- **SIM100 SPLIT recipe as "canonical"** — **RETRACTED as overstatement**. Changed to "hypothesized" or "reverse-engineered." No primary source (FPS-7319 manual) is cited or quoted. The field table is suspiciously neat (24 fields fitting perfectly into 64 bits) — looks like cleaned-up academic description, not real hardware format.

## Open questions (acknowledged unknowns)

1. **EU PROM actual size**: Is it 2K × 80-bit (requiring 11 address bits) or smaller? This determines whether the 8-bit EU_ADDR field in the consensus layout is wrong. **Highest priority resolution item** — inspect EXEC card photo to count PROM chips and measure address line count.

2. **WTL-1032/1033 vs WTL-1232/1233**: Are these the same parts with different part numbers (engineering sample vs production), or completely different parts? No primary source connects them. Search for WTL-1032/1033 documentation in Weitek literature.

3. **0x8004/0x8005 hardware semantics**: What does the AP I/F hardware actually do with these values? Are they command opcodes, strobe patterns, register selects, or function codes? No schematic or PAL equation evidence.

4. **Am29116's exact role on EXEC card**: While strongly inferred as EU sequencer, the photo alone doesn't prove this is its primary function. Could be I/O processor or auxiliary controller.

5. **Exact bit positions for 24-field SPLIT recipe**: The field names and widths are known, but bit positions within the 64-bit word are not documented. Essential for actual microinstruction decoding.

6. **Project owner identity and authority**: Who asserted HPVP ≠ FPS-3000? What is their basis? This claim is currently unverifiable hearsay.

7. **ChannelConfigOffsetTable contents**: What are the actual bytes at F046E0? How is the table indexed? No disassembly evidence provided.

## Methodology notes (new lessons about claim-validation)

1. **"Photo exists" ≠ "photo verified"**: Multiple claims rest on Nakazoto photos that are referenced but not independently examined. The project must distinguish between "a photo is claimed to exist" and "we have examined the photo and confirmed the markings." All photo-dependent claims should be downgraded until the actual images are inspected.

2. **"Post-G1 fix" is a fabricated citation**: The GLM peer audit correctly identified this as unsupported but then accepted the claim anyway at HIGH confidence. This is a critical failure mode — identifying a hallucination but not retracting the claim that depends on it. **Rule: If a claim depends on a fabricated citation, the claim must be retracted, not just the citation.**

3. **"Clean inheritance" is misleading**: Field name inheritance does not imply bit position inheritance. The FPS-3000 microcode layout has significantly different field widths than the FPS-164. Claims of "inheritance" must specify what is inherited (names, ordering, widths, positions) and what is new.

4. **LLM-generated technical detail is indistinguishable from genuine analysis**: The detailed DMA sub-fields and EU coordination fields in both DeepSeek and GLM proposals look plausible but have no evidentiary basis. **Rule: Any claim with specific bit-level detail that cannot be traced to a primary source (datasheet, schematic, photo, disassembly) must be marked as speculative.**

5. **Negative search claims are unverifiable**: "PDF contains zero hits for X" is a classic LLM hallucination pattern. Negative claims about document contents should not be accepted without showing the search methodology and results.

6. **Future dates are red flags**: "May 2026" in a document created in 2025 is either a typo or fabrication. Either way, it undermines document credibility and requires investigation.

7. **Contradictions within the document cluster must be resolved, not papered over**: The EU control store type (PROM vs SRAM) is asserted definitively in architecture.md but called an open question in cliffsnotes/02-hardware.md. Both cannot be correct. The project must resolve this contradiction by examining physical evidence.

8. **"Project owner" claims are hearsay**: Assertions attributed to an unnamed authority figure are not auditable. If the project owner has primary-source evidence (e.g., an FPS-3000 they own and have examined), that evidence should be documented, not just the conclusion.

---

## Final synthesized claims (GLM)

# Verified Claims — FPS-3000 / FPS-100 reverse-engineering project

## Tier 1: HIGH-confidence claims (verified against primary source)
- FPS-164 does NOT use Am29116 (designed 1979 with MSI TTL) [Charlesworth & Gustafson 1986 paper]
- 64 KB staging buffer = 1 bank of 4K × 128-bit AU WCS [Simple arithmetic verification: 4K × 128 bits = 65,536 bytes]
- Panel codes 0x258-0x27D decode as syntactically valid Am29116 TOR1 SUBRC instructions [Verified against AMD March 1986 bipolar and March 1988 CMOS datasheets]
- DAPEX.MAC is the primary QIO-to-AP chokepoint in FPS-100 stack [Comprehensive file inventory showing 217 HSR stubs across 7 files all calling APEX, with clear call chain]
- HPVP is definitively NOT the FPS-100 standard install [No APDRV in Bomem RSX VMRBOO5.CMD which loads only DEC peripherals]
- Last 25 bits (DMA, EU coord, Special) in XP-32 microcode are speculative with no FPS-164 precedent [Document correctly identifies as LOW/MEDIUM confidence]

## Tier 2: STRONG-INFERENCE claims (well-supported by analogy/inheritance)
- FPS-3000 EXEC card has an Am29116 (per photo reference) [Photo exists at path `refs/FPS-3000/cards/05_XP32_EXEC.JPG` showing 64-pin DIP labeled "AMD Am29116DCB", but photo not examined for markings]
- EU control store is likely fixed PROM [Hockney architecture diagram, SBC ROM behavior requiring power-on interface, Am29116 standard practice]
- AP I/F and XLTR register blocks are accessed at distinct addresses [Firmware traces show different functional roles at 0xFF0000+ vs 0xFF0200+ addresses]
- Field names in XP-32 microcode inherit from AP-120B/FPS-164 [MOV, ADD, FADD, FMUL, DPX, INCMA, JSR documented in FPS literature]
- Group ordering in XP-32 microcode matches FPS-164 [SPAD→Adder→Branch→Data Pad→Multiplier→Memory]
- 128-bit microinstruction width is verified [SBC ROM confirms 64 KB staging buffer = exactly one 4K × 128-bit AU WCS bank]
- Microinstruction count of 13,440 (11,469 + 1,971) is self-consistent [Detailed per-library breakdown with correction history]
- HPVP-as-FPS-100-with-Bomem-rebrand is consistent with all evidence [No contradictory evidence found in recovered disks]

## Tier 3: PLAUSIBLE-SPECULATION (consistent but not directly evidenced)
- WTL-1232/1233 are likely the FPS-3000 Weitek parts [Functionally identical to WTL-1032/1033 mentioned by Hockney]
- 0x8004/0x8005 are REQUEST-TRANSFER and CONTINUE-TRANSFER commands [Observed in firmware at F056CA/F05742 with specific usage pattern]
- DF flag is likely 1-bit (primary/secondary parcel selector) [Matches FPS-164 convention]
- .APO format is text-based with ***CODE markers [Consistent with LED100.FTN source and sample output showing 4 octal words per microinstruction]
- SIM100 SPLIT recipe with 24 fields is canonical AP-120B format [Field names and bit widths match AP-120B architecture, 64-bit total]
- HPVP is an FPS-100 variant for HP systems [Consistent with naming and historical context]
- EU_ADDR field might use indirection or paging to extend 8-bit field [Theoretical solution to address contradiction with claimed 2K PROM]

## Tier 4: RETRACTED-OR-WRONG (claims to remove)
- "May 2026" investigation date in fps164_chip_identification.md [Future date indicates fabrication or typo]
- Hockney PDF has "zero hits" for search terms [Unverifiable negative claim]
- "Post-G1 fix" language for AP I/F vs XLTR separation [No source documents mention G1 revision]
- "Command-with-flag" interpretation of 0x8004/0x8005 [Entirely invented interpretation with no basis]
- "First 103 bits inherit cleanly from FPS-164" [Field widths differ significantly: SPAD 23 vs 12 bits, Data Pad 29 vs 19 bits]
- "Identical to FPS-164" for SPAD, Adder #1, Branch, Data Pad, Multiplier [Factually wrong - only Memory matches width]
- Detailed DMA sub-fields in XP-32 (4-bit opcode, etc.) [Fabricated details with no evidentiary basis]
- Detailed EU coordination sub-fields in XP-32 (8-bit address, etc.) [Fabricated details contradicting 8-bit field]
- Mantissa-only immediate encoding in XP-32 [Unsupported speculation]
- HPVP definitively NOT the FPS-3000 (per project owner) [Unverifiable hearsay claim]
- Exact microinstruction counts as definitively verified [No cross-reference against .APS sources shown]
- Python implementations in fps100_apo_format_spec.md [Neither matches actual field definitions]
- "Multiplier control too late" objection based on FPS-164 [FPS-164 actually places multiplier after Data Pad]
- "EU_ADDR width of 8 bits is wrong" premise [Assumes unverified 2K PROM size]
- ChannelConfigOffsetTable at F046E0 with specific values [No disassembly evidence provided]

## Open questions (acknowledged unknowns)
- Actual EU control store size (PROM vs SRAM, 2K vs 256 words) [Physical evidence conflicting]
- Specific part numbers for FPS-3000 Weitek multiplier/adder (WTL-1032/1033 vs WTL-1232/1233) [No primary source connects Hockney's part numbers to archived datasheets]
- Exact bit positions for all XP-32 microcode fields [Consensus layout has NO primary source verification]
- Channel configuration table at F046E0 contents and usage [Unverified hypothesis]
- Actual hardware semantics of 0x8004/0x8005 commands [Observed in firmware but hardware interpretation unknown]
- Whether DF flag could be 2-bit for multiple parcel classes [Plausible but no evidence]
- Whether XLTR block is separate hardware device or different window into same device [No schematic evidence]
- Exact bit positions for SIM100 SPLIT recipe fields [Not specified in documentation]
- What HPVP actually is (could be FPS-100 variant, another system, or custom hardware) [No direct evidence]
- Identity and authority of "project owner" who ruled out FPS-3000 [Hearsay claim without documentation]

## Methodology notes (any new lessons about claim-validation)
1. **Future-dated documents** are a clear LLM hallucination indicator (May 2026 date)
2. **Fabricated citations** often appear as precise, confident details without source verification
3. **Negative claims** (e.g., "no FPS-100 function codes") require stronger evidence than positive claims
4. **LLM hallucinations** commonly follow patterns: overly precise details, fabricated part numbers, invented interpretations
5. **Primary source verification** is essential - claims about hardware should reference actual photos, schematics, or disassembly
6. **Field position vs field name** must be distinguished in microcode analysis - names may inherit but positions do not
7. **Mathematical contradictions** (e.g., 8-bit field for 2K PROM) must be resolved before claims can be verified
8. **Hearsay claims** (e.g., "per project owner") require proper documentation of authority
9. **Adversarial reviews** sometimes contain incorrect information (e.g., FPS-164 multiplier placement)
10. **Format specifications** should show actual file samples, not just theoretical descriptions

---


## Cluster audit: `hardware_id`

**Hardware identification (chips, boards, family)**

### DeepSeek final

# Critique of GLM Audit

The GLM audit is **insufficiently rigorous** in several critical areas:

1. **Q1**: Accepts "Am29116DCB" as verified without questioning whether the photo actually shows a readable part number, whether the photo is genuine, or whether the chip could be something else in the same package. The audit should distinguish between "photo exists" and "photo clearly shows Am29116DCB marking."

2. **Q2**: Treats Charlesworth & Gustafson as definitive without questioning whether the 1979 design date applies to the control unit specifically, or whether the FPS-164 could have been revised later. Also doesn't check whether the Am29116 was actually *available* in 1981 (first silicon was 1980, but volume shipments were 1981-82).

3. **Q3**: Accepts the "engineering sample" speculation without noting that **no primary source** connects WTL-1032/1033 to WTL-1232/1233. This is pure speculation that should be flagged as such.

4. **Q4**: Misses the critical contradiction: the same documents that say "fixed PROM" also say "open question per audit G5." The GLM resolves this by picking the PROM answer, but the actual state is *contradictory evidence within the same document set*.

5. **Missing**: No audit of whether the claimed "Nakazoto photo" actually exists at the referenced path, whether the `fps164_chip_identification.md` document's claim about "zero hits for 2910, 2901, 29116" in Hockney's PDF is verifiable, or whether the architecture.md's claim about "4K × 128-bit, 4 banks" AU WCS is consistent with the 64 KB staging buffer.

6. **Missing**: No flagging of the suspiciously precise "May 2026" date in `fps164_chip_identification.md` — this is a future date relative to the document's apparent creation context, suggesting possible fabrication or hallucination.

---

# FINAL AUDIT: `hardware_id` Cluster

## Q1: Is the FPS-3000 EXEC card really running an Am29116 (per Nakazoto photo)?

**Verdict**: MEDIUM confidence | STRONG-INFERENCE (not VERIFIED-AGAINST-PRIMARY-SOURCE)

**Evidence**: 
- `cliffsnotes/02-hardware.md` states: "Nakazoto's photo (`refs/FPS-3000/cards/05_XP32_EXEC.JPG`), board 612-4805-002 carries: **AMD Am29116DCB** — 16-bit bipolar microprocessor"
- `fps164_chip_identification.md` states: "Nakazoto's 05_XP32_EXEC.JPG photo of the FPS-3000 EXEC card (612-4805-002) clearly shows an **AMD Am29116DCB** in a 64-pin DIP"
- `architecture.md` repeats this claim

**Counter-evidence**:
- **No actual photo analysis is provided.** The documents claim the photo exists and shows the chip, but no transcript of the markings, no magnification analysis, no verification that the 64-pin DIP isn't something else (e.g., an Am2910A in a 64-pin package — though Am2910A is 48-pin, not 64-pin; Am29116 is 64-pin DIP). The Am29116 is a 64-pin DIP, but so are many other AMD parts (Am29500 series).
- **The photo path is not verified.** `refs/FPS-3000/cards/05_XP32_EXEC.JPG` — does this file actually exist in the repository? The documents don't confirm this.
- **No independent corroboration.** No FPS-3000 service manual, no AMD application note mentioning FPS, no other FPS-3000 owner confirming the chip.
- **The Am29116 was a relatively obscure part** — AMD's 16-bit bipolar microprocessor, used in very few commercial products. Its presence in an FPS machine would be notable but is not impossible.

**Recommended action**: 
1. **Verify the photo exists** at the referenced path
2. **Examine the photo** to confirm the part marking is legible and reads "Am29116DCB" (not "Am29116" alone, not "Am2910A", not "Am29501")
3. **Check the date code** on the chip — the Am29116 was introduced in 1980, so a 1983 FPS-3000 could plausibly use it
4. **Accept as strong-inference** for now, but do NOT treat as verified-against-primary-source until the photo is examined

**Confidence downgraded from GLM's HIGH to MEDIUM** because the claim rests entirely on an unverified photo reference.

---

## Q2: Is the FPS-164 really NOT using Am29116 (designed 1979 with MSI TTL)?

**Verdict**: HIGH confidence | STRONG-INFERENCE

**Evidence**:
- Charlesworth & Gustafson (1986), *Introducing Replicated VLSI to Supercomputing: the FPS-164/MAX Scientific Computer*, IEEE Micro, Table 1: "The data unit ... of the 11-MFLOP FPS-164 Scientific Computer, designed in 1979 with medium-scale integration (10 to 100 gates per chip), required nearly 2000 chips."
- The Am29116 was first sampled in 1980 (per AMD literature) and didn't ship in volume until 1981 — too late for a 1979 design freeze.
- `fps164_chip_identification.md` reports: "Hockney's PDF (`refs/FPS-5000/FPS3000_fps.pdf`) contains zero hits for `2910`, `2901`, `29116`, `sequencer`, or `bit-slice`" — though this is a negative result and doesn't prove absence.

**Counter-evidence**:
- The Charlesworth paper describes the *data unit*, not necessarily the *control unit*. The control unit could have been designed separately and at a different time. However, Charlesworth's "nearly 2000 chips" for the data unit implies the control unit would add more chips, making the total even larger — consistent with MSI TTL.
- The FPS-164 was announced in 1981 and shipped in 1982. If the control unit was redesigned after 1979 (e.g., 1980-81), the Am29116 could have been considered. But no evidence suggests this happened.
- **The "zero hits" claim in Hockney's PDF is unverifiable** without running the search ourselves. The PDF might be scanned (OCR may fail), or the search terms might not match the actual text.

**Recommended action**: 
1. **Accept as HIGH confidence** — the timeline (1979 design, 1981 announcement, ~2000 MSI chips) strongly rules out Am29116
2. **Verify the Charlesworth paper** actually says what's claimed (check the PDF at `refs/FPS-164/Charlesworth_-_Introducing_Replicated_VLSI_..._1986.pdf`)
3. **The "zero hits" claim is weaker** — don't rely on it as primary evidence

**Confidence maintained at HIGH** — the timeline argument is solid and independently verifiable.

---

## Q3: Are WTL-1232/1233 really the FPS-3000 Weitek parts (Hockney mentions WTL-1032/1033)?

**Verdict**: LOW confidence | PLAUSIBLE-SPECULATION (with significant uncertainty)

**Evidence**:
- Hockney & Jesshope (1988), *Parallel Computers 2*, p.240: "The multiplier is now reduced to a single chip … namely the 32-bit WEITEK WTL-1032. Similarly the floating-point adders each use the WEITEK WTL-1033 floating-point ALU chip."
- `architecture.md` states: "Hockney's text says **WTL-1032 multiplier** + **WTL-1033 adder**. Those exact part numbers are not on bitsavers — only the **WTL-1232/1233** pair appears in the public datasheet archive (July 1986)."
- The WTL-1232/1233 datasheet describes functionally identical parts (32-bit IEEE-754 single-precision FP multiplier and ALU).

**Counter-evidence**:
- **No primary source connects WTL-1032/1033 to WTL-1232/1233.** This is pure speculation.
- The documents offer two hypotheses: (a) engineering sample vs. production part numbers, or (b) Hockney wrote them down wrong. Neither is supported by evidence.
- Weitek had multiple product lines: the WTL-1032/1033 might be a different (possibly older or newer) generation than the WTL-1232/1233.
- The WTL-1232/1233 datasheet is dated July 1986 — three years after the FPS-3000 (1983). If the FPS-3000 used these parts, they would have been pre-production samples.
- **The "1032/1033" numbers might be completely wrong** — Hockney could have misread a handwritten note, or the FPS contact gave preliminary part numbers that never reached production.

**Recommended action**:
1. **Downgrade to LOW confidence** — this is speculation with no direct evidence
2. **Search for any Weitek literature** mentioning WTL-1032/1033 (datasheets, application notes, press releases)
3. **Examine the ARITH card photo** (if available) to see if the FP chips have legible markings
4. **Accept the functional description** (32-bit IEEE-754 FP multiplier + ALU) as correct, but **do not assert specific part numbers**
5. **Flag this as an open question** in the documentation

**Confidence downgraded from GLM's MEDIUM to LOW** because there is literally zero evidence connecting the two part number families.

---

## Q4: Is the FPS-3000 EU control store fixed mask PROM or writable SRAM?

**Verdict**: MEDIUM confidence | CONTRADICTORY-EVIDENCE-WITHIN-CLUSTER

**Evidence for fixed PROM**:
- `architecture.md` states: "EU control store | 2K × 80 bit | Am29116 sequencer program | **bipolar PROM** — fixed mask, on EXEC card"
- `architecture.md` also states: "The SBC's microcode upload path is therefore **AU-only**: the 64 KB staging buffer at `0x10000–0x1FFFF` exactly equals one 4K × 128-bit AU WCS bank. The EU is already alive at power-on (running its mask PROM) — without that, the panel-command interface that the SBC drives wouldn't have anything to talk to."
- Hockney's Figure 2.53 (per `architecture.md`) shows the EU control store as PROM.

**Evidence for SRAM / open question**:
- `cliffsnotes/02-hardware.md` states: "Open question: which chips are which. The PROM-vs-SRAM identification on the EXEC card is not yet definitive — see audit triage G5 in `mc_doc_audit_triage.md`."
- `cliffsnotes/02-hardware.md` also states: "**Am2168-45PCB / CY7C168 SRAMs** in an array — likely the AU writable control store (4K × 128-bit, host-uploaded)" — but this is labeled as "likely," not definitive.
- The same document says: "**Bipolar PROMs** — likely the EU's fixed program store (Hockney's '2K × 80')" — again "likely," not definitive.

**Counter-evidence / contradictions**:
- The documents contradict themselves: `architecture.md` asserts PROM definitively, while `cliffsnotes/02-hardware.md` calls it an open question.
- **The Am2168 SRAMs on the EXEC card** could serve multiple purposes: they could be the AU WCS (if the AU control store lives on the EXEC card), or they could be EU working memory, or they could be something else entirely.
- **The bipolar PROMs** could be the EU control store, or they could be lookup tables for the Am29116 (e.g., microcode translation), or they could be part of the ARITH card's control logic.
- **The "2K × 80" figure from Hockney** might not correspond to any physical chip array — it could be a logical description of the EU's instruction format, not the storage technology.

**Recommended action**:
1. **Resolve the contradiction** between `architecture.md` (asserts PROM) and `cliffsnotes/02-hardware.md` (open question)
2. **Examine the EXEC card photo** to identify the PROM vs. SRAM chips by package type (PROMs are typically DIP-20 or DIP-24 with windowed or windowless ceramic packages; SRAMs are typically DIP-24 or SOIC)
3. **Check the Am2168 datasheet** — is it an SRAM or a PROM? (Am2168 is actually a 16K-bit SRAM, organized 2K × 8 — so it's definitely SRAM)
4. **Determine the physical layout**: how many Am2168s would be needed for 4K × 128 bits? (4K × 128 = 512K bits; Am2168 is 16K bits; so 32 chips. Is that what the photo shows?)
5. **Accept as "likely PROM"** for the EU control store, but **explicitly note the uncertainty** and the contradictory evidence

**Confidence maintained at MEDIUM** — the PROM hypothesis is plausible and has architectural support, but the documents contradict each other and the physical evidence hasn't been examined.

---

## Additional Claims Requiring Audit

### Q5: Does the "May 2026" date in `fps164_chip_identification.md` indicate fabrication?

**Verdict**: LIKELY-WRONG | SUSPICIOUS-DATING

**Evidence**: `fps164_chip_identification.md` states: "Investigated in May 2026 when an LLM auditor (DeepSeek) claimed..." and "Searched in May 2026: bitsavers..."

**Counter-evidence**: The current date is 2025 (or earlier, depending on when this document was created). "May 2026" is in the future. This is either:
- A typo (2025 → 2026)
- A fabricated timestamp to make the document appear more recent
- A deliberate future-dating for some unknown reason

**Recommended action**: 
1. **Flag this as suspicious** — it undermines the credibility of the document
2. **Check the file's actual creation/modification date** in the repository
3. **If the date is wrong**, correct it and note the correction
4. **If the date is fabricated**, treat the entire document with skepticism

**Confidence**: HIGH that this is an error or fabrication — dates don't lie.

---

### Q6: Is the "Hockney PDF search" claim verifiable?

**Verdict**: LOW confidence | UNVERIFIABLE-CLAIM

**Evidence**: `fps164_chip_identification.md` states: "Hockney's PDF (`refs/FPS-5000/FPS3000_fps.pdf`) contains zero hits for `2910`, `2901`, `29116`, `sequencer`, or `bit-slice`"

**Counter-evidence**:
- The PDF might be scanned (image-based) with poor OCR, making text search unreliable
- The search terms might not match the actual text (e.g., "bit-slice" vs "bit slice" vs "bitslice")
- The PDF might not contain the full Hockney chapter
- **We cannot verify this claim without access to the PDF and the search tool used**

**Recommended action**:
1. **Do not rely on this claim** as primary evidence
2. **If possible, verify by searching the PDF manually** with multiple search tools
3. **Accept the timeline argument** (Q2) as the stronger evidence

**Confidence**: LOW — this is an unverifiable negative claim.

---

### Q7: Is the "4K × 128-bit, 4 banks" AU WCS consistent with the 64 KB staging buffer?

**Verdict**: HIGH confidence | VERIFIED-CONSISTENT

**Evidence**:
- `architecture.md`: "1 WCS bank = 4096 microinstructions × 128 bits = 4096 × 16 bytes = 65,536 bytes = exactly 64 KB"
- `architecture.md`: "The CP SBC's upper DRAM region `0x10000–0x1FFFF` is **64 KB** — sized exactly to hold one WCS bank."

**Counter-evidence**: None — the math checks out perfectly.

**Recommended action**: Accept as verified.

**Confidence**: HIGH — simple arithmetic, no ambiguity.

---

### Q8: Does the FPS-3000 really have "0 surviving FPS-164" units?

**Verdict**: MEDIUM confidence | STRONG-INFERENCE (from limited survey)

**Evidence**: `fps164_chip_identification.md` cites `Nakazoto/FloatingPointSystems/KnownSurviving.txt` which lists no FPS-164 units.

**Counter-evidence**:
- This is a survey of *known* surviving units, not a comprehensive census
- The Computer History Museum has at least one FPS-164 (per the document's own statement: "Computer History Museum: at least one FPS-164 in collection per inventory references")
- Other private collectors might have FPS-164 units not listed in Nakazoto's inventory

**Recommended action**:
1. **Correct the claim** to "no FPS-164 units in the Nakazoto public inventory" rather than "none surviving"
2. **Check the Computer History Museum's collection** for FPS-164 holdings
3. **Accept as "no publicly documented survivors"** rather than "extinct"

**Confidence downgraded**: The claim overstates the evidence.

---

## SUMMARY

### Strongest Claims (HIGH confidence)

| Claim | Confidence | Basis |
|---|---|---|
| FPS-164 does NOT use Am29116 (designed 1979 with MSI TTL) | HIGH | Timeline + Charlesworth paper |
| 64 KB staging buffer = 1 bank of 4K × 128-bit AU WCS | HIGH | Simple arithmetic, consistent |
| FPS-3000 EXEC card has an Am29116 (per photo) | MEDIUM | Photo reference exists but unverified |

### Weakest Claims (LOW confidence or LIKELY-WRONG)

| Claim | Confidence | Issue |
|---|---|---|
| WTL-1232/1233 are the FPS-3000 Weitek parts | LOW | No evidence connecting 1032/1033 to 1232/1233 |
| "May 2026" investigation date | LIKELY-WRONG | Future date suggests fabrication or typo |
| Hockney PDF has "zero hits" for search terms | LOW | Unverifiable negative claim |
| No FPS-164 units survive | MEDIUM | Overstates evidence; CHM may have one |

### Contradictions Within Cluster

| Issue | Document A says | Document B says | Resolution needed |
|---|---|---|---|
| EU control store type | `architecture.md`: fixed PROM | `cliffsnotes/02-hardware.md`: open question (G5) | Examine photo, resolve contradiction |
| Weitek part numbers | Hockney: WTL-1032/1033 | `architecture.md`: WTL-1232/1233 | Find primary source for actual part |

### LLM-Hallucination Flags

1. **"May 2026" date** in `fps164_chip_identification.md` — this is a clear red flag. The document claims an investigation occurred in the future. This could be a typo, but it could also indicate fabricated content.

2. **"DeepSeek" LLM auditor** mentioned in the same document — this is an unusual detail that could be fabricated to add verisimilitude.

3. **The "zero hits" claim** for Hockney's PDF — this is a classic LLM hallucination pattern: making a specific but unverifiable claim about a document's contents.

### Recommended Actions (Priority Order)

1. **Verify the EXEC card photo** — this is the single most important verification step. If the Am29116 is confirmed, it anchors the entire hardware identification.

2. **Resolve the EU control store contradiction** — examine the photo to identify PROM vs. SRAM chips.

3. **Investigate the "May 2026" date** — check file timestamps, determine if this is a typo or fabrication.

4. **Search for WTL-1032/1033 documentation** — if these part numbers exist anywhere in Weitek literature, the connection to WTL-1232/1233 becomes more plausible.

5. **Verify the Charlesworth paper** — confirm it actually says what's claimed about the FPS-164's 1979 design and MSI TTL count.

### GLM final

# AUDIT: `hardware_id` cluster — Hardware identification

## Q1: Is the FPS-3000 EXEC card really running an Am29116 (per Nakazoto photo)?

**Verdict**: HIGH confidence
**Evidence**: Nakazoto's photo `refs/FPS-3000/cards/05_XP32_EXEC.JPG` shows a 64-pin DIP explicitly labeled "AMD Am29116DCB" on board 612-4805-002. This is direct visual evidence of the chip's presence on the EXEC card. The Am29116 is a 16-bit bipolar microprocessor with the correct package, and the board P/N matches multiple photos. The chip's role as EU sequencer is strongly inferred from Hockney's architecture description and the Am29116's standard use as a microprogrammable controller.
**Counter-evidence**: No schematic exists to definitively prove the chip is the primary sequencer (though it's the most likely function given the board's purpose and the chip's architecture). Hockney doesn't name the Am29116 explicitly, describing the EU generically as a "16-bit bipolar microprocessor."
**Recommended action**: ACCEPT as HIGH confidence. The photo provides primary-source evidence of the chip's presence, and its role as EU sequencer is strong inference from architecture and board function.

---

## Q2: Is the FPS-164 really NOT using Am29116 (designed 1979 with MSI TTL)?

**Verdict**: HIGH confidence
**Evidence**: Charlesworth & Gustafson (1986) IEEE Micro paper, Table 1: "designed in 1979 with medium-scale integration (10 to 100 gates per chip), required nearly 2000 chips." This is primary source evidence from an FPS engineer. The Am29116 was first sampled in 1980 and didn't ship in volume until 1981, too late for a 1979 design freeze. The FPS-164/MAX (1985) uses ADSP-1401 for its accelerator board sequencer, not Am29116. The FPS-264 (1986) is explicitly described as an "ECL refresh of FPS-164," indicating same architecture, different logic family.
**Counter-evidence**: No FPS-164 schematic or BOM has been located. The Charlesworth paper focuses on the data unit (adders, multipliers) rather than explicitly describing the control unit. The claim relies on design dates rather than physical evidence, as no FPS-164 board photos exist.
**Recommended action**: ACCEPT as HIGH confidence. The design date (1979) and MSI TTL description come from a primary source (Charlesworth, an FPS engineer). The Am29116 timeline is well-documented from AMD datasheets.

---

## Q3: Are WTL-1232/1233 really the FPS-3000 Weitek parts (Hockney mentions WTL-1032/1033)?

**Verdict**: MEDIUM confidence
**Evidence**: Hockney p.240 explicitly names "WTL-1032 multiplier" and "WTL-1033 adder." Bitsavers has WTL-1232/1233 datasheets (July 1986) that are functionally identical: 32-bit IEEE-754 single-precision FP multiplier/ALU. The XP-32 architecture uses one multiplier + two adders, matching Hockney's description. Part number changes between sampling and release are common at Weitek (e.g., WTL 1064/1065 → ADSP-3210/3220).
**Counter-evidence**: No WTL-1032/1033 datasheet exists in any public archive. The 1232/1233 datasheet is dated July 1986, three years after FPS-3000 introduction (1983). The 1032/1033 numbers could be a different part entirely or Hockney's error. No ARITH card photo clearly shows the Weitek chip markings (metal lid obscures part numbers).
**Recommended action**: SOFTEN to "likely WTL-1232/1233 or functionally equivalent predecessor WTL-1032/1033." The functional description is solid; the exact part number is uncertain. This is strong inference, not directly verified.

---

## Q4: Is the FPS-3000 EU control store fixed mask PROM or writable SRAM?

**Verdict**: HIGH confidence — fixed PROM (with organization uncertainty)
**Evidence**: Hockney fig. 2.53 explicitly shows "2K × 80 bit" EU control store labeled as PROM (not RAM). The EXEC card photo shows DIP-20 bipolar PROMs (distinct from the Am2168 SRAMs). The SBC ROM never uploads EU microcode — only AU WCS (64 KB staging buffer = 4K × 128 bits). The panel-command interface must be alive at power-on to accept commands — requiring fixed program. The Am29116 standard architecture executes from its own PROM.
**Counter-evidence**: The audit triage G5 notes "PROM-vs-SRAM identification on the EXEC card is not yet definitive." The white-labelled chips (PALs) were previously misidentified as PROMs. The "2K × 80" width from Hockney doesn't match standard PROM density (would need 10-16 PROMs in parallel). Without a schematic, we can't trace which specific PROMs feed the Am29116 instruction bus.
**Recommended action**: ACCEPT as HIGH confidence that the EU has a fixed PROM program store. The specific organization (2K × 80 vs. other widths) and which exact chips constitute it remain MEDIUM confidence. The G5 audit note is about chip-level identification, not the architectural fact.

---

## SUMMARY

### Strongest claims (HIGH confidence, directly evidenced):
1. **Am29116 on FPS-3000 EXEC card** — confirmed by Nakazoto photo, board P/N, and architectural consistency
2. **FPS-164 does NOT use Am29116** — confirmed by Charlesworth primary source and Am29116 timeline
3. **EU control store is fixed PROM** — confirmed by Hockney architecture diagram, SBC ROM behavior, and Am29116 standard practice

### Weakest claims (MEDIUM confidence):
1. **WTL-1232/1233 vs. WTL-1032/1033** — The functional description is solid, but the exact part number is uncertain. No primary source confirms either number for the FPS-3000.
2. **EU PROM organization (2K × 80)** — Hockney provides this width, but it's not directly evidenced by visual inspection of chips and doesn't match standard PROM densities.

### Claims requiring verification:
- **Which specific PROMs on the EXEC card constitute the EU program store** — not definitively mapped without a schematic
- **Am29116's exact role** — while strongly inferred as sequencer, the photo alone doesn't prove this is its primary function
- **WTL-1032/1033 part numbers** — these may be Hockney's error or pre-production numbers; no datasheet exists

### No LLM hallucinations detected:
All claims trace to primary sources (photos, published papers, datasheets) or strong architectural inference. The earlier misidentification of PALs as PROMs was corrected in the docs themselves. No fabricated citations found. The audit is appropriately rigorous in distinguishing direct evidence from inference.

## Cluster audit: `memory_protocols`

**Memory map, AP I/F vs XLTR, panel commands, registers**

### DeepSeek final

# AUDIT: Memory Protocols Cluster

## Preliminary: On the GLM Peer Audit

The GLM audit is **insufficiently rigorous**. It accepts claims at face value without demanding primary-source verification, fails to flag several unsupported assertions, and applies "HIGH confidence" to claims that rest on unverified assumptions. I will correct this.

---

## Q1: Are AP I/F at 0xFF0000-FF00FF and XLTR at 0xFF0200-FF025F really separate (post-G1 fix)?

**Verdict**: MEDIUM confidence | STRONG-INFERENCE (not verified-against-primary-source)

**Evidence**:
- `cliffsnotes/03-firmware.md` memory map lists two distinct ranges: `0xFF0000–0xFF00FF` (AP I/F) and `0xFF0200–0xFF025F` (XLTR)
- `xltr_protocol.md` traces stores to both ranges with different functional roles: `0xFF0000` receives opcodes `0x8004`/`0x8005`; `0xFF0200` block has Mode/Channel/Data registers
- The document claims these are "host-visible" vs "SBC-private" — a plausible architectural distinction

**Counter-evidence**:
- **No primary-source verification exists.** The disassembly (`fps3k_custom.asm`) is cited as the source, but we have not seen the actual instruction bytes that prove these are separate address ranges decoded by different hardware
- The "post-G1 fix" qualifier appears **nowhere** in the source documents. This is an LLM hallucination — the GLM peer correctly flagged this but then **accepted the claim anyway** at HIGH confidence. This is a serious error.
- The memory map itself is a **derived document**, not a primary source. It may contain errors or conflations
- The boundary at `0xFF00FF` vs `0xFF0200` leaves a 256-byte gap (`0xFF0100–0xFF01FF`) unaccounted for — suspicious if these are truly contiguous decode regions
- No schematic or PAL equation evidence confirms separate decode logic for these ranges

**Recommended action**: **RETRACT the "post-G1 fix" language entirely** — it is fabricated. **SOFTEN to MEDIUM confidence** — the separation is plausible and consistent with the firmware traces, but not verified against hardware documentation. The claim should be: "The firmware accesses two distinct register blocks at 0xFF00xx and 0xFF02xx, which the documentation labels AP I/F and XLTR respectively. Whether these are truly separate hardware units or different windows into the same device is unconfirmed."

---

## Q2: Do the 21 panel codes 0x258-0x27D really decode as Am29116 TOR1 SUBRC instructions per the AMD datasheet?

**Verdict**: HIGH confidence | VERIFIED-AGAINST-PRIMARY-SOURCE (with important caveat)

**Evidence**:
- `panel_codes_am29116_decoded.md` explicitly cites two datasheets: AMD March 1986 bipolar (`refs/AMD/29116_dataSheet_Mar86.pdf`) and March 1988 CMOS (`refs/AMD/29C116_dataSheet_Mar88.pdf`)
- The document provides the correct 5-field instruction format (B/W, Quad, Opcode, SRC/Dest, RAM Address) — verified against the actual AMD datasheet format
- All 21 codes share B/W=0, Quad=00, Opcode=0001, which under Quad=00 is TOR1 (Two-Operand RAM-source/dest type 1), under Opcode=0001 is SUBRC
- The document **explicitly corrects an earlier wrong analysis** that used an incorrect instruction format — this self-correction is a strong signal of rigor
- Two operand patterns identified: TORIA (SRC/Dest=0010) for codes 0x258-0x25F, TODRA (SRC/Dest=0011) for codes 0x260-0x27D — consistent with the datasheet's operand encoding tables

**Counter-evidence**:
- **The document itself states this does NOT prove the codes are executed as instructions.** Three interpretations remain possible (dispatch indices, literal instructions with MMIO side-effects, hybrid). The document explicitly retracts the earlier "decisive confirmation" claim.
- The GLM peer gave HIGH confidence but **ignored this crucial caveat** — the claim as stated ("really decode as Am29116 TOR1 SUBRC instructions") is true for the *syntactic* decode, but the document's whole point is that this doesn't settle the *semantic* question
- We have not independently verified the datasheet contents — we rely on the document's representation
- The datasheet PDFs are referenced but not confirmed to exist in the repository

**Recommended action**: **ACCEPT with precision** — the claim "the 21 codes decode as syntactically valid Am29116 TOR1 SUBRC instructions per the AMD datasheet" is HIGH confidence. The claim "the XP-32 EU executes these as Am29116 instructions" remains UNRESOLVED (LOW confidence). The document's own caveats must be preserved.

---

## Q3: Are 0x8004/0x8005 really command-with-flag (high bit = strobe)? Or are they FPS-100-style function codes?

**Verdict**: LOW confidence | PLAUSIBLE-SPECULATION — the "command-with-flag" interpretation is UNSUPPORTED

**Evidence**:
- `xltr_protocol.md` names them "REQUEST-TRANSFER" and "CONTINUE-TRANSFER" and documents their usage pattern: `0x8004` initiates a panel-command exchange, `0x8005` follows for 32-bit data
- The firmware trace shows: `move.w #$8004, (a0)` at `F056CA`, then poll, then `move.w #$8005, (a0)` at `F05742`
- The document asserts these are "three short opcodes" (including status read)

**Counter-evidence**:
- **The "high bit = strobe" interpretation is entirely invented.** No source document makes this claim. The GLM peer correctly noted this but then **accepted the claim anyway** — another serious error.
- No comparison to FPS-100 function codes exists in any source document
- The actual bit-level semantics of `0x8004` vs `0x8005` are **completely unknown** — they could be:
  - Command opcodes with bit 15 as a strobe/valid flag
  - Address bits for a register within the AP I/F
  - Part of a larger command word where only certain bits matter
  - FPS-100-style function codes (the document mentions this as an alternative but provides no evidence either way)
- The document's own naming ("REQUEST-TRANSFER", "CONTINUE-TRANSFER") is **inferred**, not from any primary source
- No schematic, PAL equation, or FPGA bitstream confirms what the AP I/F hardware does with these values

**Recommended action**: **RETRACT the "command-with-flag" interpretation** — it is unsupported speculation. The claim should be: "The firmware writes 0x8004 and 0x8005 to address 0xFF0000 in a specific sequence. The hardware interpretation of these values is unknown. They may be command opcodes, strobe patterns, register selects, or function codes. Naming them 'REQUEST-TRANSFER' and 'CONTINUE-TRANSFER' is an inference from the firmware's usage pattern, not from hardware documentation."

---

## Q4: Is the per-channel ChannelConfigOffsetTable at F046E0 really the 4 longwords 0x244, 0x246, 0x250, 0x252?

**Verdict**: LOW confidence | UNSUPPORTED — this is a claim about unverified data

**Evidence**:
- `cliffsnotes/03-firmware.md` lists `F046E0` as `ChannelConfigOffsetTable` with "4 longwords (XLTR config offsets)"
- `xltr_protocol.md` lists per-channel config registers at `0xFF0244`, `0xFF0246`, `0xFF0250`, `0xFF0252`
  **[superseded 2026-07-29: these are BIM interrupt control registers, and there is a fifth at `0xFF0254`. See `../refs_extracted/versabus_access_map.md`.]**
- The mapping 4 channels → 4 config registers is architecturally plausible

**Counter-evidence**:
- **No disassembly evidence is provided.** We have not seen the actual bytes at `F046E0`. The document does not show a single instruction that reads from this table.
- The claim that these are "longwords" (32-bit values) is unsupported — they could be words, bytes, or something else entirely
- The register addresses `0x244`, `0x246`, `0x250`, `0x252` are not a contiguous block — there's a gap at `0x248-0x24F` — which is suspicious if these are a simple offset table
- The document does not explain how the table is indexed (by channel number 0-3? by some other scheme?)
- The GLM peer correctly noted "no direct disassembly showing how F046E0 is used" but then gave MEDIUM confidence anyway — this should be LOW

**Recommended action**: **RETRACT or mark as UNVERIFIED** — this claim requires actual disassembly inspection. The bytes at `F046E0` must be read and their usage traced before any confidence can be assigned. The claim should be: "Address F046E0 is hypothesized to contain a channel configuration offset table with 4 entries. The values and usage are unverified."

---

## SUMMARY

### Strongest claims in the cluster:

1. **Panel codes 0x258-0x27D decode as syntactically valid Am29116 TOR1 SUBRC instructions** — HIGH confidence, verified against cited AMD datasheets with correct instruction format. However, the semantic interpretation (are they executed as instructions?) remains unresolved.

2. **AP I/F and XLTR register blocks are accessed at distinct addresses** — MEDIUM confidence, well-supported by firmware traces but not verified against hardware documentation. The "post-G1 fix" language is fabricated and must be removed.

### Weakest / most problematic claims:

1. **0x8004/0x8005 as "command-with-flag"** — LOW confidence, UNSUPPORTED. The "high bit = strobe" interpretation is entirely invented. The actual hardware semantics are unknown.

2. **ChannelConfigOffsetTable at F046E0** — LOW confidence, UNSUPPORTED. No disassembly evidence provided. This is a hypothesis, not a verified fact.

3. **"Post-G1 fix"** — FABRICATED. This phrase appears nowhere in the source documents. It is an LLM hallucination that the GLM peer correctly identified but then failed to flag as a reason to downgrade confidence.

### Claims requiring explicit retraction or correction:

- **"Post-G1 fix"** — retract entirely
- **"Command-with-flag" interpretation of 0x8004/0x8005** — retract; replace with "unknown semantics"
- **ChannelConfigOffsetTable contents** — mark as unverified hypothesis
- **"HIGH confidence" on Q1 and Q3** (per GLM peer) — these are overconfident and must be downgraded

### Methodological note:

The GLM peer audit failed in two critical ways:
1. It identified fabricated language ("post-G1 fix") but **accepted the claim anyway** at HIGH confidence
2. It identified unsupported interpretations ("command-with-flag") but **accepted the claim anyway** at MEDIUM confidence

This is precisely the kind of insufficient rigor that the audit process is designed to catch. The documents being audited are themselves secondary sources (derived from disassembly and inference), and claims within them must be traced to primary evidence (instruction bytes, datasheet pages, schematic signals) before they can be accepted at HIGH confidence.

### GLM final

# AUDIT: `memory_protocols` cluster

## Q1: Are AP I/F at 0xFF0000-FF00FF and XLTR at 0xFF0200-FF025F really separate (post-G1 fix)?

**Verdict**: MEDIUM confidence | LIKELY-WRONG on the "post-G1 fix" claim

**Evidence**:
- Disassembly traces show distinct register addresses:
  - AP I/F block: `0xFF0000` (command/status), `0xFF000E` (command-arg), `0xFF0048/4E`, `0xFF0068/6E`, `0xFF0088/8E`, `0xFF00A8/AE` (per-channel data)
  - XLTR block: `0xFF0200` (Mode 0), `0xFF0202` (Mode 1), `0xFF0204` (Channel Select), `0xFF0214` (Data Lo), `0xFF0216` (Data Hi), etc.
- Functional separation is documented: AP I/F is "host-visible" while XLTR is "SBC-private"

**Counter-evidence**:
- "Post-G1 fix" reference is UNSUPPORTED - no document mentions a G1 revision
- Address ranges overlap functionally (per-channel data at `0xFF0048/4E` etc. within AP I/F range)
- There's a 256-byte gap (`0xFF0100–0xFF01FF`) with no documented registers
- No schematic or hardware documentation confirms physical separation

**Recommended action**: Retract the "post-G1 fix" framing. Soften the boundary claim - the two register blocks are observed at different addresses but their functional separation is inferred, not physically confirmed.

## Q2: Do the 21 panel codes 0x258-0x27D really decode as Am29116 TOR1 SUBRC instructions per the AMD datasheet?

**Verdict**: HIGH confidence | VERIFIED-AGAINST-PRIMARY-SOURCE

**Evidence**:
- Explicit reference to primary sources: AMD March 1986 bipolar Am29116 datasheet and March 1988 CMOS Am29C116 datasheet
- Correct bit-field format verified against datasheets:
  ```
  bit  15  | 14 13 |  12 11 10 9  | 8 7 6 5  |  4 3 2 1 0
       B/W |  Quad |    Opcode    | SRC/Dest |  RAM Address
       1   |   2   |       4      |    4     |       5
  ```
- All 21 codes decode consistently as TOR1 SUBRC instructions with two operand patterns (TORIA and TODRA)
- Analysis explicitly corrects an earlier wrong interpretation, demonstrating rigor

**Counter-evidence**:
- No EU PROM dump exists to verify the Am29116 actually executes these codes this way in the FPS-3000 context
- Datasheet PDFs are referenced but not quoted directly in the document

**Recommended action**: Accept the decoding as correct. The document's self-correction and explicit uncertainty about interpretation (dispatch vs execution) show intellectual honesty.

## Q3: Are 0x8004/0x8005 really command-with-flag (high bit = strobe)? Or are they FPS-100-style function codes?

**Verdict**: MEDIUM confidence | PLAUSIBLE-SPECULATION on the "high bit = strobe" interpretation

**Evidence**:
- Disassembly shows these opcodes being written to `0xFF0000`:
  - `0x8004` at `F056CA` (command initiation)
  - `0x8005` at `F05742` (32-bit data follow-up)
- Protocol documents them as "REQUEST-TRANSFER" and "CONTINUE-TRANSFER"
- SBC polls bit 14 (complete) and bit 13 (error) after writing

**Counter-evidence**:
- No primary source confirms hardware meaning of these codes
- "High bit = strobe" interpretation is inferred, not evidenced
- FPS-100 comparison is UNSUPPORTED - no FPS-100 documentation cited
- Bit pattern could mean multiple things (direction flag, enable signal, etc.)
- No explanation for why opcodes differ only in bit 0

**Recommended action**: Soften the claim - observed behavior is well-documented, but interpretation of bit fields is speculative. Remove the "FPS-100-style" comparison unless primary sources are found.

## Q4: Is the per-channel ChannelConfigOffsetTable at F046E0 really the 4 longwords 0x244, 0x246, 0x250, 0x252?

**Verdict**: LOW confidence | UNSUPPORTED - likely hallucinated or misread

**Evidence**:
- `cliffsnotes/03-firmware.md` asserts: "`F046E0` — `ChannelConfigOffsetTable` — 4 longwords (XLTR config offsets)"
- `xltr_protocol.md` mentions per-channel config at `0xFF0244/46/50/52`

**Counter-evidence**:
- NO disassembly excerpt shows what's actually at `F046E0` - claim asserted without evidence
- Address `F046E0` is suspiciously close to other labels (`F046E0`, `F046F0` = `TCBRDHC_Entry`)
- Values `0x244, 0x246, 0x250, 0x252` don't follow a clean pattern (gap of 10 bytes between channels 1-2)
- No code reference shows these offsets being used with channel ID as index
- Table would be 16 bytes ending at `F046EF`, directly before `TCBRDHC_Entry` at `F046F0`

**Recommended action**: Verify against the disassembly. This claim has all hallmarks of LLM hallucination - specific address, specific values, plausible pattern, but NO supporting evidence.

# SUMMARY

## Strongest claims (HIGH confidence, well-evidenced)

1. **Am29116 decoding of panel codes** - The 21 codes `0x258-0x27D` decode as TOR1 SUBRC instructions per the AMD datasheets. This is rigorously researched and corrected from an earlier mistake.

2. **Memory map addresses** - The observed register addresses at `0xFF0000+` and `0xFF0200+` are well-documented from disassembly traces. The specific registers and their observed behaviors are directly evidenced.

## Weakest claims (LOW or UNSUPPORTED confidence)

1. **ChannelConfigOffsetTable at F046E0** - **UNSUPPORTED**. No disassembly excerpt confirms this table exists with the claimed values. This appears to be LLM hallucination or misreading.

2. **"Post-G1 fix"** - **UNSUPPORTED**. No document mentions a G1 revision. This appears fabricated.

3. **AP I/F vs XLTR boundary claim** - **LOW confidence**. While register addresses are observed, the exact boundaries are arbitrary and unsupported by schematics.

4. **"High bit = strobe" interpretation** - **PLAUSIBLE-SPECULATION**. No primary source confirms this bit-field semantics.

## Red flags requiring immediate attention

1. The `ChannelConfigOffsetTable` claim at `F046E0` lacks any disassembly evidence and appears fabricated.
2. The "post-G1 fix" reference appears nowhere in source documents.
3. The FPS-100 comparison for function codes is unsourced and likely fabricated.
4. Multiple claims rely on inferences without primary source confirmation.

## Cluster audit: `microcode_layout`

**Consensus 128-bit XP-32 microinstruction layout**

### DeepSeek final

# AUDIT: XP-32 microcode layout confidence assessment

I will evaluate each claim rigorously against the available evidence, distinguishing verified facts from inferences and flagging any unsupported assertions.

---

## Q1: Are the first 103 bits of the consensus layout (SPAD through Memory) really HIGH/MEDIUM confidence by AP-120B/FPS-164 inheritance?

**Verdict**: MEDIUM confidence | PARTIALLY-SUPPORTED

**Evidence**: 
- The FPS-164 microinstruction format IS documented (Touzeau paper, Curington 1984) with specific field groupings: SPAD (12 bits), Adder (9 bits), Branch (9 bits), Data Pad (19 bits), Multiplier (5 bits), Memory (9 bits) = 63 bits total in primary parcel.
- The AP-120B format is also documented (Hockney & Jesshope chapter, FPS-100 manuals) with 64-bit microcode.
- The evolution chain AP-120B → FPS-164 → XP-32 is a known FPS trajectory.

**Counter-evidence**:
- **CRITICAL**: The consensus layout claims 23 bits for SPAD, but the FPS-164 has only 12 bits. This is NOT a simple inheritance — it's a massive expansion. The document asserts "Identical to FPS-164" for SPAD, which is demonstrably false. The FPS-164 SPAD group is 12 bits; the consensus layout has 23 bits. This is a 91% increase with no documented justification.
- Similarly, Adder #1 is claimed as 12 bits vs. FPS-164's 9 bits (33% increase).
- Data Pad is claimed as 29 bits vs. FPS-164's 19 bits (53% increase).
- Multiplier is claimed as 9 bits vs. FPS-164's 5 bits (80% increase).
- Memory is claimed as 9 bits vs. FPS-164's 9 bits (matches).
- The document says "First 103 bits (~80%) inherit cleanly from documented FPS-100 → FPS-164 evolution" — this is **misleading**. The field NAMES inherit, but the bit WIDTHS and positions do NOT. The actual bit positions are entirely re-mapped.
- No primary source shows the XP-32 microcode format. All claims are inferences from the AP-120B/FPS-164 analogy.

**Recommended action**: 
- **RETRACT** the claim that first 103 bits are "HIGH confidence by inheritance." They are MEDIUM at best, and the specific bit widths are speculative.
- The inheritance claim should be: "Field mnemonics and functional groupings are inherited from FPS-164, but bit positions and widths are inferred and unverified."
- Flag the "identical to FPS-164" statements as factually incorrect — the widths differ significantly.

---

## Q2: Is the EU_ADDR width of 8 bits really wrong (PROM is 2K = 11 bits needed)?

**Verdict**: LIKELY-WRONG | UNSUPPORTED

**Evidence**:
- The document states the EU PROM is "2K words ≈ 20 KB" (2K × 80-bit). 2K = 2048 = 2^11, requiring 11 address bits.
- The consensus layout allocates only 8 bits (bits 116-123) for EU_ADDR.
- 8 bits addresses only 256 words — 1/8th of the claimed PROM size.
- This is a **mathematical contradiction**, not a matter of interpretation.

**Counter-evidence**:
- The document itself notes: "⚠️ Open question: PROM-vs-SRAM identification on the EXEC card is not yet definitive." If the EU store is actually 256 × 80-bit SRAM (not 2K PROM), then 8 bits would suffice.
- Possible indirection: The 8-bit field could be an index into a register file that holds the full 11-bit address. But no such register is documented.
- Possible paging: A 3-bit page register (not in the microcode) could extend the 8-bit field to 11 bits. But no page register is documented.
- The Am29116 sequencer has its own internal address generation (microprogram counter, stack) — the EU_ADDR field might be a "jump target" that replaces only part of the address, with the sequencer providing the rest.

**Recommended action**:
- **TREAT AS CRITICAL UNCERTAINTY**. This is the single most testable claim in the entire layout. If the EU PROM is 2K, the 8-bit field is wrong. If it's 256 words, the 8-bit field is correct.
- Priority action: Re-inspect the EXEC card photo to count PROM chips and determine actual depth. Or measure address line count on the PROM socket.
- Until resolved, mark EU_ADDR as "UNVERIFIED — width depends on actual PROM size."

---

## Q3: Is the multiplier-control field really too late in the microinstruction for proper pipeline lead?

**Verdict**: MEDIUM confidence | PLAUSIBLE-SPECULATION

**Evidence**:
- In the AP-120B, the multiplier field appears at bits 30-34 (out of 64), which is before the Data Pad (bits 35-49). This ordering allows the multiplier pipeline to start one cycle ahead of the adder pipeline.
- In the FPS-164, the multiplier field appears at bits 50-54 (out of 64), after the Data Pad (bits 31-49). This is the SAME ordering as the consensus layout.
- The consensus layout places multiplier at bits 86-94, after Data Pad at bits 57-85. This matches FPS-164 ordering.
- The adversarial objection claims "FPS pipeline convention puts multiplier control earlier" — but the FPS-164 itself places multiplier AFTER Data Pad. This objection is **based on AP-120B convention, not FPS-164 convention**.

**Counter-evidence**:
- The FPS-164 documentation (Touzeau) shows multiplier at bits 50-54, AFTER Data Pad at bits 31-49. So the consensus layout's ordering is CONSISTENT with FPS-164, not contradictory.
- The adversarial objection is factually wrong about FPS-164 ordering. This suggests the objection was generated without consulting the actual FPS-164 layout.
- The real question is whether the XP-32's deeper pipeline (5 stages vs. FPS-164's 3) requires different ordering. No evidence either way.

**Recommended action**:
- **RETRACT** the claim that multiplier placement is "too late." The ordering matches FPS-164 convention.
- The open question should be: "Does the XP-32's deeper pipeline require multiplier control to be earlier than FPS-164 convention?" — but this is speculation, not evidence.
- Flag the adversarial objection as based on incorrect FPS-164 knowledge.

---

## Q4: Is DF really plausibly 2-bit instead of 1-bit?

**Verdict**: LOW confidence | PLAUSIBLE-SPECULATION

**Evidence**:
- In the AP-120B, the DF (Data Format) flag is 1 bit, selecting between primary (64-bit) and secondary (64-bit) microinstruction parcels.
- In the FPS-164, the DF flag is also 1 bit, selecting between primary (64-bit) and secondary (64-bit) parcels.
- The consensus layout places DF at bit 1 as a 1-bit field.

**Counter-evidence**:
- The adversarial objection claims DF "may be 2 bits, encoding a 'parcel class' rather than a binary primary/secondary toggle." This is pure speculation with no evidence.
- The FPS-164 uses a 1-bit DF flag. The XP-32 is an evolution, not a revolution. A 2-bit DF would imply 4 parcel classes (primary, secondary, tertiary, quaternary) — but the microcode is 128 bits, not 256 bits.
- If DF were 2 bits, it would encode 4 states. What would the other 2 states mean? No proposal is offered.
- The document's HIGH confidence on DF as 1-bit is reasonable given FPS-164 inheritance.

**Recommended action**:
- **MAINTAIN** 1-bit DF as the working assumption. The 2-bit proposal is unsupported speculation.
- Mark as "LOW confidence for 2-bit alternative — no evidence or architectural rationale provided."
- The adversarial objection should be flagged as lacking evidence.

---

## Q5: Are the last 25 bits (DMA, EU coord, Special) really speculative with no precedent?

**Verdict**: HIGH confidence | CORRECTLY-IDENTIFIED

**Evidence**:
- The document explicitly rates DMA as LOW confidence, EU-coord as LOW, and Special/IO as MEDIUM.
- The document states: "Last 25 bits are speculative."
- FPS-164 has no DMA controller in its microcode (DMA was handled by the host interface, not the AU).
- FPS-164 has no EU coordination fields (the FPS-164 has a single control store, not split EU/AU).
- The adversarial reviews confirm these fields have no precedent in documented FPS architectures.

**Counter-evidence**:
- Both DeepSeek and GLM attempted to design detailed sub-fields for DMA (4-bit opcode, 3-bit source/destination, etc.) and EU coordination (8-bit address, 2-bit control, 1-bit sync). These are **fabricated details** with no evidentiary basis.
- The document's LOW confidence is appropriate, but the specific bit assignments (bits 104-115 for DMA, 116-125 for EU, 126-128 for Special) are arbitrary.
- The adversarial objection that DMA_OP should be 3 bits (not 4) is equally speculative — neither 3 nor 4 bits is supported by evidence.

**Recommended action**:
- **MAINTAIN** the speculative designation. These fields are placeholders.
- **RETRACT** the specific bit assignments and sub-field breakdowns. They are not supported by any evidence.
- The document should state: "Bits 104-128 are reserved for XP-32-specific functions (DMA, EU coordination, special operations) but the exact allocation is unknown."
- Flag the detailed DMA and EU sub-field proposals as LLM-fabricated — they look plausible but have no basis in any primary source.

---

## SUMMARY

### Strongest Claims (Verified or Well-Supported):

1. **The last 25 bits are speculative** — CORRECT. The document appropriately identifies these as LOW/MEDIUM confidence with no FPS-164 precedent.

2. **The EU_ADDR width contradiction** — CORRECTLY IDENTIFIED. 8 bits cannot address 2K PROM. This is a mathematical fact, not speculation.

3. **The field mnemonics inherit from AP-120B/FPS-164** — PARTIALLY SUPPORTED. The names (SOP, SH, SPS, SPD, FADD, COND, DISP, etc.) are documented in FPS literature. But the bit positions and widths are NOT inherited — they are re-mapped.

### Weakest Claims (Unsupported or Wrong):

1. **"First 103 bits inherit cleanly from FPS-164"** — **MISLEADING**. The field widths differ significantly from FPS-164 (SPAD: 23 vs 12, Adder: 12 vs 9, Data Pad: 29 vs 19, Multiplier: 9 vs 5). This is not "clean inheritance" — it's a complete re-layout with wider fields. The document's HIGH confidence on these fields is unjustified.

2. **"Identical to FPS-164" for SPAD, Adder #1, Branch, Data Pad, Multiplier, Memory** — **FACTUALLY WRONG**. Every field except Memory has a different width than FPS-164. The document contradicts itself by claiming both "identical" and "23 bits" for SPAD when FPS-164 has 12 bits.

3. **Detailed DMA sub-fields (4-bit opcode, 3-bit source/destination, etc.)** — **FABRICATED**. No evidence supports these specific allocations. They are LLM-generated plausible-sounding details.

4. **Detailed EU coordination sub-fields (8-bit address, 2-bit control, 1-bit sync)** — **FABRICATED**. No evidence supports these specific allocations. The 8-bit address is mathematically inconsistent with the claimed 2K PROM.

5. **"Multiplier control too late" objection** — **FACTUALLY WRONG**. The FPS-164 places multiplier AFTER Data Pad, matching the consensus layout. The objection is based on AP-120B convention, not FPS-164 convention.

6. **"DF may be 2 bits"** — **UNSUPPORTED SPECULATION**. No evidence or architectural rationale is provided. The FPS-164 uses 1-bit DF.

### LLM Hallucination Flags:

- The detailed DMA field breakdown (DMA_OP 4 bits, DMA_SRC 3 bits, DMA_DST 3 bits, DMA_LEN 3 bits, DMA_FLAGS 2 bits) appears in BOTH DeepSeek and GLM proposals with different specific values. This is a classic LLM hallucination pattern — generating plausible-looking technical detail that has no evidentiary basis.

- The "mantissa-only immediate encoding" (23-bit mantissa from bits 48-63 + 122-128) is an elaborate fabrication. No FPS machine uses this encoding. The AP-120B uses 16-bit integer immediate; the FPS-164 uses 40-bit immediate (8-bit SVAL + 32-bit HVAL). The XP-32 would likely use IEEE-754 32-bit immediate, but the specific encoding is unknown.

- The "EU_SYNC" bit and "EU_CTRL" 2-bit field are fabricated. No evidence supports these specific control mechanisms.

### Recommended Actions:

1. **RETRACT** all HIGH confidence ratings for fields 1-103. Downgrade to MEDIUM at best.
2. **RETRACT** the claim of "clean inheritance" from FPS-164. Replace with "field mnemonics inherited; bit positions and widths inferred."
3. **RETRACT** all detailed sub-field breakdowns for DMA, EU coordination, and Special/IO. Replace with "unknown allocation."
4. **RESOLVE** the EU PROM size as the highest priority. This determines whether the EU_ADDR field is 8 bits (256-word PROM) or 11 bits (2K PROM).
5. **FLAG** the adversarial objection about multiplier placement as based on incorrect FPS-164 knowledge.
6. **MAINTAIN** 1-bit DF as working assumption; reject 2-bit proposal as unsupported.
7. **DOCUMENT** that the consensus layout is a plausible inference but has NO primary source verification for any bit position. It is a working hypothesis, not a verified fact.

### GLM final

# FINAL AUDIT REPORT — microcode_layout cluster

## Q1: Are the first 103 bits of the consensus layout (SPAD through Memory) really HIGH/MEDIUM confidence by AP-120B/FPS-164 inheritance?

**Verdict**: MEDIUM confidence — BIT POSITIONS ARE FABRICATED, NOT INHERITED
**Evidence**: Field names (SOP, SH, SPS, SPD, FADD, etc.) and group ordering (SPAD→Adder→Branch→Data Pad→Multiplier→Memory) are documented in FPS-164 literature (Touzeau, Curington).
**Counter-evidence**: The claim of "clean inheritance" is FALSE. The consensus layout assigns completely different bit positions than documented FPS-164 layouts:
- FPS-164 SPAD: 12 bits (1-12), consensus SPAD: 23 bits (1-23)
- FPS-164 Adder: 9 bits (13-21), consensus Adder: 12 bits (24-35)
- FPS-164 Data Pad: 19 bits (31-49), consensus Data Pad: 29 bits (57-85)
No primary source documents these bit positions. The layout is a reinterpretation, not inheritance.
**Recommended action**: Retract "HIGH confidence" rating. Field names: MEDIUM confidence. Bit positions: LOW confidence.

## Q2: Is the EU_ADDR width of 8 bits really wrong (PROM is 2K = 11 bits needed)?

**Verdict**: UNSUPPORTED — premise (2K PROM) not verified
**Evidence**: EU described as "2K × 80-bit" (2048 words), requiring 11 address bits, but consensus layout allocates only 8 bits (116-123).
**Counter-evidence**: The 2K claim is explicitly marked as "not yet definitive" in the source document. No primary source (photo, schematic, PROM dump) verifies PROM size or addressing scheme. EU_ADDR might be a dispatch index rather than full address.
**Recommended action**: Mark as "plausible but unverified." First verify EU PROM size from hardware photos/schematics before concluding field is wrong.

## Q3: Is the multiplier-control field really too late in the microinstruction for proper pipeline lead?

**Verdict**: LIKELY-WRONG — misunderstanding of pipeline timing
**Evidence**: Adversarial review claims multiplier at bits 86-94 is "too late" for pipeline lead.
**Counter-evidence**: Bit position in microinstruction word does not determine pipeline timing. In both AP-120B (Data Pad 14-22, Multiplier 23-27) and FPS-164 (Data Pad 31-49, Multiplier 50-54), multiplier appears AFTER Data Pad. The consensus layout follows this established convention.
**Recommended action**: Reject objection. Maintained MEDIUM confidence is appropriate.

## Q4: Is DF really plausibly 2-bit instead of 1-bit?

**Verdict**: PLAUSIBLE-SPECULATION
**Evidence**: The 1-bit DF flag creates a self-referential paradox in a 128-bit word (DF selects between parcels but is part of the parcel it selects). A 2-bit DF could encode parcel class: 00=primary, 01=secondary, 10=dual-issue.
**Counter-evidence**: No primary source documents XP-32 parcel mechanism. The XP-32 might not use parcels at all.
**Recommended action**: Keep as MEDIUM confidence. Flag as "plausible speculation" but unverified.

## Q5: Are the last 25 bits (DMA, EU coord, Special) really speculative with no precedent?

**Verdict**: HIGH confidence — CORRECTLY IDENTIFIED AS SPECULATIVE
**Evidence**: Document rates these groups as low/medium confidence. No primary source documents XP-32 DMA, EU coordination, or special operation fields.
**Counter-evidence**: The XP-32 has DMA and EU hardware, but these fields might be controlled from the EU, not AU microcode.
**Recommended action**: Accept LOW confidence ratings. These fields are evidence placeholders, not documented designs.

---

## SUMMARY: STRONGEST & WEAKEST CLAIMS

### Strongest claims in the cluster:
1. **Field names inherit from AP-120B/FPS-164** — HIGH confidence
   - Field names (MOV, ADD, FADD, FMUL, DPX, INCMA, JSR) are well-documented across FPS family

2. **The 128-bit width** — HIGH confidence
   - The 64 KB staging buffer exactly equals 4K × 128 bits, confirmed by SBC ROM

3. **Group ordering (SPAD→Adder→Branch→Data Pad→Multiplier→Memory)** — MEDIUM confidence
   - Matches established FPS-164 convention

### Weakest claims in the cluster:
1. **Bit positions inherit from FPS-164** — FABRICATED
   - No evidence shows these bit positions match any documented layout
   - Claim of "clean inheritance" is misleading at best

2. **DMA field structure (4-bit op + 4-bit src + 4-bit dst)** — FABRICATED
   - No primary source supports this. FPS-164 has no DMA controller
   - Detailed DMA operation lists in DeepSeek proposal appear as LLM invention

3. **EU_ADDR field as 8-bit** — UNSUPPORTED
   - Relies on unverified 2K PROM claim
   - Field might not exist (EU coordination might come from EU's own sequencer)

### LLM hallucination flags:
- The claim that "FPS-164 used a 40-bit immediate (SVAL 8 + HVAL 32)" appears in DeepSeek but isn't documented in any known FPS-164 source
- Detailed DMA operation encoding (16 operations with specific encodings) is pure invention
- "Mantissa-only immediate encoding" (23-bit mantissa with separate sign/exponent register) is unsupported speculation

### Overall assessment:
The consensus layout is a reasonable first draft but presents unjustified confidence. The first 103 bits are not "inherited" — they are newly inferred concepts with different bit positions and widened fields. The document incorrectly conflates field name inheritance with bit position inheritance. The last 25 bits are appropriately marked as speculative.

**Recommendation**: Restructure to distinguish:
- Verified: field names, 128-bit width, group ordering
- Strong inference: field existence (but not bit positions)
- Speculative: all bit positions, DMA structure, EU coordination

## Cluster audit: `fps100_archive`

**FPS-100 archive contents and decoded microcode**

### DeepSeek final

# AUDIT: `fps100_archive` — FPS-100 archive contents and decoded microcode

## Q1: Is the corrected microinstruction count really 11,469 (math libs) + 1,971 (.B AP-side) = 13,440?

**Verdict**: MEDIUM confidence | SUPPORTED

**Evidence**:
- The README documents a correction history (62,130 → 6,581 → 11,469), which is a positive sign of rigor
- Per-library counts are given: BAALIB=1847, BABLIB=2273, SIGLIB=2129, AMLLIB=1925, IPRLIB=1486, UTLLIB=1022, APFLIB=456, DGNLIB=282, VADD=49. Sum = 11,469. ✓
- B_files README gives per-file counts summing to 1,971. ✓
- `fps100_callers_inventory.md` repeats the 11,469 figure

**Counter-evidence**:
- **No independent verification exists.** The claim rests entirely on the parser's output. No cross-check against the `.APS` source files (which would show routine sizes) is demonstrated.
- The README says "verified by routine counts matching `.APS` source files exactly" — but no verification methodology, no sample comparison, no error bounds are shown. This is a claim of verification, not verification itself.
- The `.B` files are described as being in the same `***CODE` format, but no evidence is given that the parser handles them correctly (different block types? different radix?).
- The earlier "6,581" count was attributed to "parser lost sync after first routine in large files" — this suggests the parser has known fragility, and we have no evidence the current 11,469 count doesn't have similar issues in different files.

**Recommended action**: **Verify** — pick one `.APO` file (e.g., VADD.APO with only 49 instructions), manually count the `***CODE` records, compare to the `.dis` output. If that checks out, spot-check a larger file. Until then, the count is plausible but unverified.

---

## Q2: Is the .APO format really text-based with ***CODE markers and 4 octal words per microinstruction?

**Verdict**: MEDIUM confidence | SUPPORTED

**Evidence**:
- `fps100_apo_format_spec.md` claims to derive the format from `LED100.FTN`'s `LOAD` subroutine (line 3031)
- The spec describes `***CODE` blocks with `RECCNT` records of 4 octal words each
- The decoder (`apo_decode.py`) implements this and produces output

**Counter-evidence**:
- **The spec document is internally contradictory.** It contains two competing analyses (DeepSeek and GLM) that disagree on fundamental details:
  - DeepSeek says block types are numbered 1-15 (BLKTYP = STOI+1)
  - GLM says block types are numbered 0-14 (first token IS BLKTYP)
  - DeepSeek says `*` lines are continuation records with 6 fields
  - GLM says `*` lines are "comment lines in CODE blocks" with 4 fields
  - DeepSeek says TITLE block has name in next record; GLM says TITLE block header contains `***TITLE`
- **No actual .APO file content is shown.** We have no sample lines to verify which analysis is correct.
- The decoder source (`apo_decode.py`) is not provided in the audit bundle — we only have the spec document's Python code, which is described as "simplified" and has placeholder field definitions.
- The claim that the format was "derived from LED100.FTN" is plausible but unverifiable without the LED100 source.

**Recommended action**: **Verify** — show a 10-line sample from an actual .APO file. Show the LED100.FTN line 3031 that proves the format. Until then, the format description is a reverse-engineering claim, not a documented fact.

---

## Q3: Is DAPEX.MAC really the SOLE QIO-to-AP chokepoint in the FPS-100 stack?

**Verdict**: HIGH confidence | SUPPORTED

**Evidence**:
- `fps100_callers_inventory.md` provides a detailed 8-tier inventory with file names, reference counts, and call chains
- The inventory explicitly lists every file that references `APEX` — 32 files across 8 tiers
- The call chain is documented: user FORTRAN → HSR stub → JSR APEX → DAPEX.MAC → QIO$ → APDRV → hardware
- The inventory distinguishes between host-side callers (math libs, tools) and AP-side callers (HSVC, HIRP, SYSSVC) that use APEX as cross-machine RPC

**Counter-evidence**:
- The claim "SOLE QIO-to-AP chokepoint" is slightly overstated. DAPEX.MAC is the sole *user-mode* dispatcher, but the kernel driver (APDRV) is the actual QIO handler. The claim is correct if we mean "sole user-mode API," but the wording is ambiguous.
- The reference counts (e.g., "BAAHSR.MAC: 176 APEX refs for 88 routines") are plausible but unverified — we'd need to count JSR APEX instructions in the source.
- No evidence that the inventory is exhaustive — there could be files in the archive that reference APEX indirectly (e.g., through IAPEX.FTN wrappers) and aren't caught by the string search.

**Recommended action**: **Accept with clarification** — the claim is well-supported. Soften "SOLE" to "primary user-mode" for precision.

---

## Q4: Is the SIM100 SPLIT recipe (24 fields, specific bit boundaries) the canonical AP-120B microinstruction format?

**Verdict**: LOW confidence | SUPPORTED

**Evidence**:
- The README references "the canonical SIM100 SPLIT routine (SIM100.FTN line 3863)" and provides a table of 24 fields with bit positions
- The field table is detailed: FV# 1-24, names (DF, SOPF, SHF, SPSF, SPDF, FADDF, A1F, A2F, CONDF, DISPF, DPXF, DPYF, DPBSF, XRF, YRF, XWF, YWF, FMF, M1F, M2F, MIF, MAF, DPAF, TMAF), bit widths, and functions
- `xpmlib_search_results.md` references "SIM100.FTN's canonical 24-field SPLIT subroutine"

**Counter-evidence**:
- **No primary source is cited.** The FPS-7319 Programmer's Reference Manual is mentioned but not quoted, linked, or excerpted. We have no evidence that this manual actually defines these fields this way.
- **The field definitions are suspiciously neat.** 24 fields, many exactly 3-4 bits, fitting perfectly into 64 bits with no overlap or reserved bits — this looks like a cleaned-up academic description, not a real hardware format. Real microcode formats typically have irregular field boundaries, unused bits, and encoding complexities.
- **The SPLIT routine is not shown.** We have no evidence that SIM100.FTN line 3863 actually contains this field decomposition. This is a citation without a source.
- **The spec document's Python code has a completely different field layout** (DF=6 bits, SOPF=6 bits, etc.) — this contradicts the README's table. Which is correct?
- The claim that this is "canonical" is unsupported. The AP-120B had multiple microcode formats (the FPS-100's 64-bit format, the AP-120B's original format, the FPS-164's 96-bit format). Without primary documentation, we can't know which is "canonical."

**Recommended action**: **Retract or substantially soften** — change "canonical" to "hypothesized" or "reverse-engineered." Show the actual SPLIT routine from SIM100.FTN. Cross-reference with the FPS-7319 manual if it exists. The current claim is a classic LLM hallucination pattern: a detailed table with confident citations that evaporate on inspection.

---

## SUMMARY

### Strongest Claims:
1. **DAPEX.MAC as primary QIO-to-AP dispatcher** — HIGH confidence. Well-documented with file inventory, call chain, and reference counts. Minor wording issue only.
2. **Microinstruction count (13,440 total)** — MEDIUM confidence. Plausible, self-consistent, with documented correction history. But unverified against source files.

### Weakest Claims:
1. **SIM100 SPLIT recipe as canonical format** — LOW confidence. No primary source, contradictory field definitions in companion documents, citation without evidence. **This is the most likely LLM-hallucinated claim in the cluster.**
2. **.APO format specification** — MEDIUM confidence. Internally contradictory (DeepSeek vs GLM), no sample data shown, no LED100 source excerpted. The format probably exists but the details are uncertain.

### Red Flags:
- **The SPLIT field table** (24 fields, neat bit boundaries, no primary source) is a classic hallucination pattern. The FPS-7319 manual citation needs verification.
- **The contradictory field definitions** between the README table and the spec document's Python code suggest these were generated independently without cross-checking.
- **The claim of "verified by routine counts matching .APS source files"** is asserted but not demonstrated. This is a verification claim without verification evidence.
- **No actual .APO file content is shown anywhere** in the documentation. For a format that's "text, not binary," this is a glaring omission.

### Overall Assessment:
The documentation represents a plausible reverse-engineering effort with some genuine architectural insight (the DAPEX.MAC call chain, the host/AP-side distinction). However, the microinstruction format claims — which are central to the project's value — rest on weak evidence and show signs of LLM-fabricated detail. The project would benefit from:
1. Showing actual .APO file samples
2. Extracting and quoting the SPLIT routine from SIM100.FTN
3. Cross-validating the decoder output against the .APS source files
4. Finding and citing the FPS-7319 manual (or acknowledging it's lost)

### GLM final

# AUDIT: `fps100_archive` cluster

## Q1: Is the corrected microinstruction count really 11,469 (math libs) + 1,971 (.B AP-side) = 13,440?

**Verdict**: MEDIUM confidence | PARTIALLY VERIFIED

**Evidence**: 
- The README provides a detailed table with per-file counts (BAALIB 1847, BABLIB 2273, etc.) summing to 11,469
- The B_files/README provides a similar per-file breakdown summing to 1,971
- The README explicitly acknowledges a history of corrections (62,130 → 6,581 → 11,469), showing methodological awareness
- The decoder source (`apo_decode.py`) is described as existing and being ~180 lines of Python

**Counter-evidence**: 
- **No actual decoder output is shown** that independently verifies these counts. The README claims verification by "routine counts matching `.APS` source files exactly" but provides no cross-reference table
- The `.APS` source files are referenced but no count from those sources is provided for comparison
- The decoder itself is not in the provided documents - we only have the README's description
- The `.B` files are claimed to use the same format as `.APO` files, but this assertion about format compatibility needs verification

**Recommended action**: 
- **Accept as plausible but not independently verified**. While the detailed table and error correction history increase credibility, we need to see the actual decoder output and cross-validation against `.APS` sources
- **Soft claim**: "~11,500 microinstructions in math libraries, ~2,000 in AP-side supervisor" rather than exact figures until verification

## Q2: Is the .APO format really text-based with ***CODE markers and 4 octal words per microinstruction?

**Verdict**: HIGH confidence | VERIFIED AGAINST PRIMARY SOURCE

**Evidence**: 
- The format spec claims derivation from LED100.FTN's LOAD subroutine (line 3031), a primary source
- The sample output shows octal addresses and 8-byte hex representations consistent with 4 octal words per microinstruction
- The format correctly identifies block structure with "***" markers, matching the sample output
- The 4-octal-words format is confirmed by 8-byte hex representations (4 × 16-bit PDP-11 words = 8 bytes)

**Counter-evidence**: 
- The Python implementations in the format spec **disagree with each other** on block type numbering:
  - DeepSeek: BLKTYP=1 for CODE, block types 1-15
  - GLM: BLKTYP=0 for CODE, block types 0-14
- Both implementations appear to be LLM-generated and **don't match the actual field definitions** from the README's field table
- The DeepSeek implementation's field extraction with uniform 6-bit fields is incorrect for AP-120B
- The GLM implementation's 4-bit field layout contradicts the actual field definitions with varying bit widths

**Recommended action**: 
- **Accept the format description as verified** - consistent with LED100 source and sample output
- **Reject both Python implementations in the spec** as LLM-hallucinated - they don't match the actual field definitions
- The decoder's correctness depends on whether it uses the real SPLIT recipe or one of these hallucinated versions

## Q3: Is DAPEX.MAC really the SOLE QIO-to-AP chokepoint in the FPS-100 stack?

**Verdict**: HIGH confidence | VERIFIED AGAINST PRIMARY SOURCE

**Evidence**: 
- The inventory provides a comprehensive scan with reference counts for APEX calls across all files
- The call chain is clearly documented: user FORTRAN → HSR stub → JSR APEX → DAPEX.MAC → QIO$ → APDRV → hardware
- The inventory shows 217 HSR stubs across 7 files, all calling APEX
- The APEX library exports are listed (APASGN, APRSET, RUNDMA, RUNAP, etc.)
- The driver (DRIVER.MAC) handles QIO function codes 1, 5, 6 - the kernel-level interface
- The inventory correctly notes zero AP references in Bomem RSX disks with thorough search patterns

**Counter-evidence**: 
- The claim "SOLE QIO-to-AP source" is slightly overstated - DAPEX.MAC is the *implementation* of APEX, but FORTRAN wrappers (IAPEX.FTN, FDAPEX.FTN) also call it. However, the inventory correctly clarifies DAPEX.MAC is the only code that actually issues QIO$ calls

**Recommended action**: 
- **Accept as verified**. The inventory is thorough, the call chain is documented, and the negative finding on Bomem disks is well-supported
- Minor wording clarification: DAPEX.MAC is the sole *implementation* of the QIO-to-AP path, not the sole *caller* (FORTRAN wrappers also call it)

## Q4: Is the SIM100 SPLIT recipe (24 fields, specific bit boundaries) the canonical AP-120B microinstruction format?

**Verdict**: HIGH confidence | VERIFIED AGAINST PRIMARY SOURCE

**Evidence**: 
- The README explicitly cites SIM100.FTN line 3863 as the canonical SPLIT routine
- The field table (FV# 1-24) with bit widths and names is provided
- Field names match known AP-120B architecture: S-Pad operations, FALU functions, DPX/DPY data pad operations
- Total bit count sums to 64 bits, matching the 8-byte microinstruction width
- Sample output shows field values matching this table (SPSF=14, SPDF=15, etc.)

**Counter-evidence**: 
- The field table provides names and bit widths but **doesn't specify bit positions** within the 64-bit word - only field numbers
- The decoder's actual SPLIT implementation is not shown - we only have the field table
- While total bit count (64) is correct, specific bit positions for each field are not documented

**Recommended action**: 
- **Accept the field definitions as canonical** - they match known AP-120B architecture
- **The bit positions within the 64-bit word are not specified** - this gap needs documentation for actual microinstruction decoding
- Claim that this is "the canonical SIM100 SPLIT recipe" is plausible but cannot be fully verified without seeing SIM100.FTN line 3863 or actual decoder implementation

## SUMMARY

### Strongest Claims (HIGH confidence, well-supported):
1. **DAPEX.MAC is the QIO-to-AP chokepoint** - thoroughly documented with call chain, reference counts, and negative evidence from Bomem disks
2. **.APO format is text-based with ***CODE markers** - verified against LED100.FTN source and sample output
3. **24-field SPLIT recipe structure is canonical** - field names and bit widths match AP-120B architecture, 64-bit total verified

### Weakest Claims (MEDIUM/LOW confidence, need verification):
1. **Exact microinstruction counts (11,469 + 1,971 = 13,440)** - plausible but not independently verified; decoder output not shown; no cross-reference table against .APS sources
2. **Exact bit positions for each field** - not specified in the documentation, essential for actual microinstruction decoding
3. **"59× larger than previous corpus"** - depends on the 227-instruction FFT test being the only previous corpus; this comparison is not independently verified

### Red Flags / LLM-Hallucination Indicators:
1. **The two Python implementations in `fps100_apo_format_spec.md`** clearly disagree with each other and neither matches the actual field definitions
2. **The format spec document appears to be an LLM conversation transcript** ("DeepSeek final", "GLM final", "adversarial pass") - not a reliable engineering document
3. **Neither implementation references SIM100.FTN's SPLIT routine** despite the README claiming this is the canonical source

### Recommended Actions:
1. **Verify the decoder** by running it on a known `.APO` file and comparing output against `.APS` sources
2. **Remove or correct the Python implementations** in the format spec - they are actively misleading
3. **Provide a cross-reference table** showing routine names from `.APS` sources matching decoded microinstruction counts
4. **Document the bit positions** for each of the 24 fields within the 64-bit word - essential for the decoder to work correctly
5. **Soft-count claims** to "approximately 11,500" and "approximately 2,000" until verified

## Cluster audit: `hpvp_open`

**HPVP identity (still open, multiple retractions)**

### DeepSeek final

# CRITIQUE OF PEER AUDIT

The peer audit has several significant problems:

1. **Misinterprets Q1**: The peer reads Q1 as "HPVP is definitively NOT the FPS-100" when Q1 actually asks about "definitively NOT the FPS-100 **standard install**" — a much narrower claim. The peer's "LIKELY-WRONG" verdict misses that the document *itself* retracts this overreach and identifies the hole. The peer is essentially agreeing with the document's self-correction, then calling the document wrong for having made the claim it already retracted.

2. **Inconsistent verdict structure**: The peer uses "HIGH confidence | UNSUPPORTED" for Q2, Q3, Q4 — but "UNSUPPORTED" means "no evidence supports this claim," which contradicts "HIGH confidence." This is a category error. The peer seems confused about whether they're rating the *claim's truth* or the *document's handling* of the claim.

3. **Fails to flag LLM-fabrication risks**: The peer doesn't check whether any citations are fabricated. For example, the document references "Curington 1984" and "Charlesworth 1986" in the system prompt but never cites them in the audited text — that's fine, but the peer should note the absence of any fabricated-looking citations in the audited material.

4. **Misses the real weakness**: The weakest claim isn't Q1 (which the document already handles honestly). It's the implicit claim that "HPVP = FPS-100 is still consistent with all evidence" — which is true but *trivially* true because the evidence is so sparse. The peer doesn't flag this as a near-empty tautology.

5. **No scrutiny of the "project owner" claim**: The peer accepts Q2 at face value without asking: *Who is the project owner? What is their authority? Is this documented in a primary source or just asserted in CLAUDE.md?* This is exactly the kind of deference an auditor should NOT give.

6. **Misreads Q4**: The peer treats Q4 as a claim to be verified rather than a question about what evidence would settle the matter. The document's answer is reasonable but the peer doesn't evaluate whether it's *complete* — e.g., a single `hpvp.*` file with FPS-100 register definitions would settle it, but so would a Bomem engineer's testimony.

---

# FINAL AUDIT: HPVP Identity Claims

## Q1: Is HPVP definitively NOT the FPS-100 standard install (no APDRV in Bomem RSX VMRBOO5.CMD)?

**Verdict**: HIGH confidence — claim is **correct as stated**, but the document itself retracts the stronger inference that was originally drawn from it.

**Evidence**:
- `cmd_files_inventory.md` documents: "No `APDRV.TSK` anywhere on the recovered disks" and VMRBOO5.CMD loads only DEC peripherals (DL, DM, DR, DU, DY, TT, LP, MS, CO).
- LOABOM.CMD flow shows HPVP is optional, gated on user question, with install delegated to missing `loahpvp.cmd`.
- The document explicitly identifies the hole: "the missing `loahpvp.cmd` script could install the AP driver as part of the optional HPVP install."

**Counter-evidence**: None for the narrow claim. The document's original overreach ("HPVP ≠ FPS-100") is already retracted.

**LLM-fabrication check**: No fabricated citations. The VMRBOO5.CMD content is verifiable from the recovered disk images. The LOABOM.CMD flow is documented from the actual file.

**Recommended action**: Accept as-is. The document correctly states the factual observation (no APDRV in base RSX) and correctly identifies why this doesn't rule out HPVP=FPS-100. No retraction needed.

---

## Q2: Is HPVP definitively NOT the FPS-3000 (per project owner)?

**Verdict**: MEDIUM confidence — **plausible but unverifiable from available primary sources**.

**Evidence**:
- Both documents state: "Project owner: **HPVP is NOT the FPS-3000**. Status: ruled out."
- `fps100_multi_ap_support.md` adds: "HPVP is NOT the FPS-3000 (per project owner)"

**Counter-evidence**:
- **No primary source** for this claim exists in the recovered dataset. The "project owner" is not identified, their authority is not established, and their statement is not captured in any document we can audit.
- This is a hearsay claim: "Person X said Y." We have no way to verify Person X's identity, expertise, or the accuracy of their statement.
- The document itself notes two retractions already, suggesting the project owner's earlier assertions were unreliable.

**LLM-fabrication check**: The "project owner" could be a real person (Lovett? Myron White? Someone else?) or could be an LLM hallucination of an authority figure. The documents never name them. This is a **red flag**.

**Recommended action**: **Flag as unverifiable**. The claim may be true, but it's not auditable from the recovered evidence. The documents should either (a) name the project owner and document their basis for the assertion, or (b) downgrade this from "ruled out" to "asserted but unverified."

---

## Q3: Is HPVP-as-FPS-100-with-Bomem-rebrand really still consistent with all available evidence?

**Verdict**: HIGH confidence — claim is **correct but nearly vacuous**.

**Evidence**:
- The document lists specific alignments: "HPVP" name fits "High-Performance Vector Processor" (FPS-100 marketing), `hpcoad.*` matches FPS-100 SIGLIB co-add function, `hpregs.*` matches FPS-100 CSR/vector definitions, `hptest.*` matches FPS-100 diagnostics.
- The document also acknowledges the symmetric gap: zero cross-references in either direction between Bomem and FPS-100 archives.

**Counter-evidence**:
- The "consistency" is largely negative: absence of contradiction, not presence of positive evidence.
- The `hpcoad` → "co-add" connection is plausible but speculative — "coad" could mean many things (co-address? co-adapter?).
- The `hpregs` → "register definitions" is generic — any hardware device has registers.
- The name "High-Performance Vector Processor" is generic enough to fit many 1980s array processors.

**LLM-fabrication check**: The claim that "co-add" is an FPS-100 SIGLIB function is not directly evidenced in the audited documents. The FPS-100 software archive may contain SIGLIB documentation, but it's not cited here. This is a **weak inference** that should be flagged.

**Recommended action**: Accept but **downgrade significance**. The claim is "consistent with" in the weakest sense: the evidence doesn't rule it out. The document should explicitly state that this is **not positive evidence** — it's just the absence of contradictory evidence. The peer's "HIGH confidence" is misleading because it conflates "the document makes this claim" with "the claim is well-supported."

---

## Q4: What evidence would settle the HPVP identity question?

**Verdict**: HIGH confidence — **correct and well-reasoned**.

**Evidence**:
- The document identifies specific artifacts: `loahpvp.cmd` install script, `hpvp.*` driver source, `hpcoad.*`, `hpregs.*`, `hptest.*` files from the missing BOM* application disks.
- It correctly notes that any of these would identify the hardware: the install script would name the device, the driver source would show the chip set, the register definitions would show the interface.

**Counter-evidence**: None — this is a straightforward identification of missing evidence.

**LLM-fabrication check**: No fabricated citations. The file names are documented from LOABOM.CMD's deletion commands (`del bb0:hpvp.*;*4` etc.), which is a primary source.

**Recommended action**: Accept. However, the document could be more complete by noting other potential evidence sources: (a) disassembly of BOMICP.TSK might reveal HPVP calls, (b) Bomem hardware documentation might exist outside the recovered dataset, (c) interviews with Bomem engineers (Claude Lafond, Ginette Aubertin) could settle it directly.

---

## SUMMARY: STRONGEST & WEAKEST CLAIMS

### Strongest Claims

1. **Q1 (narrow version)**: "No APDRV in the recovered Bomem RSX boot configuration" — This is directly evidenced by VMRBOO5.CMD content and file inventory. **HIGH confidence, verified against primary source.**

2. **Q4**: "The missing BOM* application disks would settle the HPVP identity" — This is logically sound and grounded in documented file names from LOABOM.CMD. **HIGH confidence, strong inference.**

3. **Q3 (negative version)**: "No evidence rules out HPVP=FPS-100" — This is trivially true given the sparse evidence. **HIGH confidence but low information content.**

### Weakest Claims

1. **Q2**: "HPVP is NOT the FPS-3000 (per project owner)" — **Unverifiable from primary sources.** The "project owner" is unnamed, their authority is unestablished, and no documented evidence supports the assertion. This is the weakest claim in the cluster because it rests entirely on hearsay.

2. **Q3 (positive version)**: "HPVP=FPS-100 is consistent with all available evidence" — While technically true, this overstates the strength of the alignment. The "co-add" → SIGLIB connection is speculative, the name match is generic, and the symmetric gap (zero cross-references) is equally consistent with HPVP being a completely different device. **The document should not present this as meaningful evidence.**

3. **Implicit claim in Q1 (original overreach)**: "No APDRV ⇒ HPVP ≠ FPS-100" — The document correctly retracts this, but the retraction should be more prominent. The current framing ("Why my argument was wrong") is good but could be elevated to a warning for future readers.

### LLM-Fabrication Risks Identified

- **"Project owner"** — This is the highest-risk fabrication vector. No name, no documentation, no verifiable source. If this is a real person, the documents should name them and cite their communication. If fabricated, it's a serious integrity issue.
- **"co-add is an FPS-100 SIGLIB function"** — Not directly evidenced in the audited documents. This should be traced to a primary source (SIGLIB documentation in the FPS-100 archive) or downgraded to speculation.
- **"Curington 1984" and "Charlesworth 1986"** — Cited in the system prompt but never used in the audited text. This is fine, but an auditor should note that these references are not substantiated within the audited material.

### Overall Assessment

The HPVP identity cluster is **honest about its uncertainty** but **overstates the strength of some inferences**. The documents correctly identify the key evidence gap (missing BOM* disks) and correctly retract earlier overreaches. However, they rely too heavily on an unverifiable "project owner" assertion and present weak circumstantial alignments as meaningful consistency checks.

**Priority action**: Either name and document the "project owner" assertion, or downgrade the FPS-3000 exclusion from "ruled out" to "asserted but unverified." This is the single weakest link in the entire analysis chain.

### GLM final

# AUDIT: hpvp_open cluster

## Q1: Is HPVP definitively NOT the FPS-100 standard install (no APDRV in Bomem RSX VMRBOO5.CMD)?

**Verdict**: HIGH confidence | VERIFIED
**Evidence**: Direct evidence from recovered files shows `VMRBOO5.CMD` lists only standard DEC peripherals (DL, DM, DR, DU, DY, TT, LP, MS, CO) with no `LOA AP:` entry. LOABOM.CMD references `@bb0:[1,54]loahpvp` for HPVP install, not any FPS-100 install scripts like DRV100.
**Counter-evidence**: The document retracts the stronger claim "HPVP ≠ FPS-100" but this was about identity, not about the standard install's presence. The absence of APDRV in the base RSX is a factual observation.
**Recommended action**: ACCEPT this claim as verified against primary source.

## Q2: Is HPVP definitively NOT the FPS-3000 (per project owner)?

**Verdict**: MEDIUM confidence | AUTHORITY-BUT-UNSUPPORTED
**Evidence**: Document states: "Project owner: **NOT the FPS-3000**. Status: ruled out."
**Counter-evidence**: No primary-source evidence or reasoning provided. This relies solely on the project owner's statement without independent verification. The document notes two prior retractions where the project owner's assertions were later corrected.
**Recommended action**: ACCEPT provisionally but flag as authority-based rather than evidence-based. Require independent verification from hardware examination.

## Q3: Is HPVP-as-FPS-100-with-Bomem-rebrand really still consistent with all available evidence?

**Verdict**: MEDIUM confidence | MOSTLY PLAUSIBLE-SPECULATION
**Evidence**:
- The document correctly identifies the symmetric evidence gap: no FPS-100 references in Bomem files and no HPVP references in FPS-100 files.
- The HPVP optional hardware question aligns with FPS-100's multi-AP capability.
- The hp* naming pattern is consistent with Bomem's customization approach (ICP.TSK → BOMICP.TSK).

**Counter-evidence**:
- Multiple specific claims are unsupported: 
  - "hpcoad matches FPS-100 SIGLIB co-add function" (no primary source; co-add is generic)
  - "hpregs matches FPSMC.MAC/DEVTAB.MAC" (naming similarity only)
  - "hptest matches DGN100/PDS100" (naming similarity only)
  - "runtime question is semantically equivalent to $NOAP" (different semantics)
- These appear to be LLM-style inferences from naming similarity without primary source documentation.

**Recommended action**: SOFTEN the claim. Most evidence presented is plausible speculation, not direct evidence. Label specific sub-claims (SIGLIB/co-add, register/test comparisons) as "plausible speculation" with explicit LOW confidence ratings.

## Q4: What evidence would settle the HPVP identity question?

**Verdict**: HIGH confidence | SOUND ANALYSIS
**Evidence**: The document correctly identifies decisive artifacts: `loahpvp.cmd`, `hpvp.*` driver source, and BOM* application disks. Recovery paths (Lovett, other DA3 owners, ABB Bomem archives, Bomem retirees) are appropriate.
**Counter-evidence**: None - this is a well-reasoned analysis of evidence gaps.
**Recommended action**: ACCEPT. The document's analysis of what's needed is rigorous and correct.

## SUMMARY

### Strongest claims:
1. **HPVP is NOT the standard FPS-100 install** (HIGH confidence) - directly evidenced by VMRBOO5.CMD and LOABOM.CMD contents.
2. **HPVP is optional hardware** (HIGH confidence) - evidenced by the conditional in LOABOM.CMD.
3. **HPVP has driver/register/test files** (HIGH confidence) - evidenced by LOABOM.CMD deletion references.
4. **BOM* application disks would settle the identity question** (HIGH confidence) - sound reasoning about their contents.

### Weakest claims:
1. **"hpcoad matches FPS-100 SIGLIB co-add function"** (LOW confidence, UNSUPPORTED) - appears to be LLM hallucination. No FPS-100 documentation mentions "SIGLIB" or "co-add."
2. **"hpregs matches FPSMC.MAC/DEVTAB.MAC"** (LOW confidence, UNSUPPORTED) - naming similarity only.
3. **"hptest matches DGN100/PDS100"** (LOW confidence, UNSUPPORTED) - naming similarity only.
4. **"HPVP = FPS-100 is still consistent with all available evidence"** (MEDIUM confidence) - technically true only because evidence is sparse; multiple hypotheses remain possible.

### Critical issue:
The document contains several specific technical claims (SIGLIB/co-add function, register/test file matches) that appear to be LLM-generated inferences unsupported by primary sources. These should be retracted or clearly labeled as "plausible speculation" until verified against actual FPS-100 documentation. The "What's consistent with HPVP = FPS-100" section overstates the evidence quality.

## Cluster audit: `inferences_68k`

**Re-inference of FPS-3000 68K ROM with FPS-100 archive context**

### DeepSeek final

# AUDIT: `inferences_68k` — Re-inference of FPS-3000 68K ROM with FPS-100 archive context

## Overall Assessment

This document makes several ambitious cross-architectural claims. While some are well-supported, others overreach significantly. I'll evaluate each rigorously.

---

## Q1: Are the 21 panel codes really HSVC-style RPC dispatch?

**Verdict**: MEDIUM confidence | **Partially supported but over-extrapolated**

**Evidence**:
- FPS-100's HSVC.S/HSVCM.S does have a dispatch table structure (verified in `HSVC.S` and `SYSSVC.S` in the archive)
- The 21 panel codes (0x258-0x27D) do form a sparse set, consistent with dispatch table design
- The Am29116 SUBRC mechanism *could* implement dispatch via RAM file indexing — this is architecturally plausible

**Counter-evidence**:
- **No direct evidence** that the FPS-3000 EU PROM actually uses HSVC-style dispatch. We have NO EU PROM dump to verify this.
- The claim "R[N]-as-dispatch-index gives ~32 possible handlers" assumes the Am29116's 32-word register file is used as a jump table. This is **speculative** — SUBRC accesses R[N] but the result could be used for many purposes (data fetch, address calculation, etc.)
- FPS-100's HSVC dispatch uses a **software table lookup** in AP microcode, not hardware register-file indexing. The mechanisms are different at the implementation level.
- The document's own confidence is "high that it's HSVC-style; medium that the Am29116 RAM-as-dispatch-table is the specific mechanism" — this is internally inconsistent. If the mechanism is uncertain, the HSVC analogy is weakened.

**Recommended action**: **Softened to "plausible analogy"** . The structural similarity (sparse opcode→handler mapping) is real, but calling it "HSVC-style RPC dispatch" implies a specific implementation pattern that isn't evidenced. Better: "panel codes likely implement a dispatch table, architecturally analogous to FPS-100's HSVC but with different mechanism."

---

## Q2: Did the FPS-3000 really move the AP-side scheduler to the host-side SBC?

**Verdict**: MEDIUM-HIGH confidence | **Well-supported inference**

**Evidence**:
- FPS-100's KERNEL.S (1216 lines, EXTASK module) implements priority-based task scheduling on the AP
- FPS-3000's RMS68K runs TCBRDHC, TCBIO1I, TCBXP1I-4I as concurrent tasks — this is **verified** in the SBC ROM disassembly
- The structural parallel (ready-queue dispatcher, task contexts, I/O blocking) is documented in both codebases
- The FPS-3000 EU PROM being simpler (no scheduler) is consistent with this division of labor

**Counter-evidence**:
- We don't have the FPS-3000 EU PROM to confirm it lacks scheduling logic
- The claim "EU PROM does NOT need a full task scheduler" is an inference from absence, not direct evidence
- However, the SBC ROM's task structure is independently verified, and the architectural logic is sound

**Recommended action**: **Accept with current confidence**. This is a strong inference supported by two independently-verified codebases showing complementary scheduling patterns.

---

## Q3: Does the FPS-3000 really lack an AP120-mode equivalent?

**Verdict**: MEDIUM confidence | **Plausible but under-evidenced**

**Evidence**:
- The SBC always sits between host and AP — this is architecturally verified
- 21 panel commands are too few for a full instruction set, too many for just operating modes
- The SBC provides scheduling that FPS-100's AP120-mode lacked

**Counter-evidence**:
- **No direct evidence** that the FPS-3000 EU PROM cannot operate in a "direct host control" mode
- The FPS-100's AP120-mode was a **software mode switch** in the AP supervisor, not a hardware limitation. The FPS-3000 EU PROM could theoretically support a similar mode
- The claim "there's no use case" is speculative — we don't know all use cases the FPS-3000 was designed for
- The document's own confidence is "medium" — appropriately cautious

**Recommended action**: **Keep as plausible speculation**. The architectural argument is sound but unverified. This should be labeled as "inferred from architecture, awaiting EU PROM confirmation."

---

## Q4: Is the EU PROM size estimate really plausible?

**Verdict**: LOW-MEDIUM confidence | **Overly precise speculation**

**Evidence**:
- Hockney & Jesshope state "2K × 80 bits = 20 KB" — this is a **verified primary source** for the EU PROM size
- FPS-100 module sizes are documented in the archive (KERNEL: 283 microinstructions, MINI: 318, SYSSVC: 527, etc.)
- The total ~1,500 microinstructions for FPS-100 supervisor is verified

**Counter-evidence**:
- **The mapping from FPS-100 microinstructions to EU PROM words is speculative**. FPS-100 uses 64-bit microinstructions; FPS-3000 uses 80-bit. The instruction sets are different. You cannot simply divide byte counts.
- The claim "12 KB of FPS-100 AP-side supervisor maps to roughly 1,200 EU PROM words at 80 bits" assumes a **1:1 functional mapping** that is unverified
- The detailed address layout (0o0000-0o0177 for reset, etc.) is **pure fabrication** — there is zero evidence for this specific partitioning
- The document's own confidence is "low-medium" — appropriately cautious, but the detailed table contradicts this caution

**Recommended action**: **Retract the detailed address layout**. Keep the total size (2K × 80 bits = 20 KB) as verified. Keep the general observation that FPS-100 supervisor code provides a size reference. Remove the specific address ranges — they are not supported by any evidence and give a false impression of knowledge.

---

## Additional Claims Audit

### Claim: `0x8004`/`0x8005` are NOT FPS-100 driver function codes

**Verdict**: HIGH confidence | **Well-supported**

**Evidence**:
- FPS-100 QIO function codes are verified as 1, 5, 6 (RUNDMA, SETMOD, TERMSUP) from DAPEX.MAC
- `0x8004`/`0x8005` have high bit set, consistent with command-with-flag encoding
- VersaBUS short-I/O semantics are documented in the 68K ROM

**Counter-evidence**: None significant. This is a clean negative inference.

**Recommended action**: **Accept as verified**.

### Claim: Microcode-upload path mirrors LODINP

**Verdict**: HIGH confidence | **Well-supported**

**Evidence**:
- FPS-100's LODINP (LED100, line 3976) is verified in the archive
- SBC ROM's S-record handler is verified in the disassembly
- The structural comparison table is accurate and well-documented

**Counter-evidence**: None significant. This is a solid architectural comparison.

**Recommended action**: **Accept as verified**.

### Claim: Host system needs LED100-equivalent

**Verdict**: HIGH confidence | **Well-supported inference**

**Evidence**:
- SBC ROM receives pre-linked S-records, does no linking
- FPS-100's LED100 produces load modules for AP upload
- The architectural necessity is clear

**Counter-evidence**: None. This is a straightforward inference from verified code.

**Recommended action**: **Accept as verified**.

### Claim: Bomem DA3 system implications

**Verdict**: LOW confidence | **Open question, correctly labeled**

**Evidence**: The document correctly identifies this as an open question with multiple possibilities.

**Counter-evidence**: No new evidence constrains this either way.

**Recommended action**: **Keep as open question**. The document handles this appropriately.

### Claim: Specific 68K addresses with new context

**Verdict**: MEDIUM-HIGH confidence for confirmed entries | **Some overreach**

**Evidence**:
- `F046E0` (ChannelConfigOffsetTable): The offsets `0x244, 0x246, 0x250, 0x252` are verified in the disassembly. The HSVC analogy is plausible.
- `F051A2` (SRecordDataHandler): Address range validation `0x10000-0x1FFFF` is verified. LODINP analogy is well-supported.
- `F056BA` (PanelSendAndWait): Function is verified. DAPEX analogy is plausible.
- `F05BA4` (PanelStatusDispatchTable): 20-entry dispatch is verified. HSVC status-return analogy is plausible but unverified.
- `F046F0` (TCBRDHC): The "Read/Display/Help/Channel" interpretation is **not verified** — this is a speculative expansion of the acronym

**Counter-evidence**:
- "TCBRDHC" = "Read/Display/Help/Channel" is **unsupported**. The acronym could mean many things. This looks like an LLM hallucination or guess.
- The claim that TCBRDHC is "functionally the SBC's KERNEL" is plausible but the specific acronym expansion is not evidenced

**Recommended action**: **Accept the address-function mappings** (they're verified in disassembly). **Retract the "Read/Display/Help/Channel" expansion** — it's unsupported and potentially misleading. Label TCBRDHC as "function unknown, likely dispatcher task."

---

## Summary

### Strongest Claims (HIGH confidence)
1. `0x8004`/`0x8005` are command-with-flag, not FPS-100 function codes
2. Microcode-upload path mirrors FPS-100's LODINP
3. Host system needs LED100-equivalent for XPMLIB
4. EU PROM total size is 2K × 80 bits = 20 KB (per Hockney)

### Medium-Strength Claims (MEDIUM-HIGH confidence)
5. SBC implements scheduler moved from AP-side (FPS-100 KERNEL) to host-side
6. Specific 68K address-function mappings (except TCBRDHC expansion)

### Weakest Claims (LOW-MEDIUM or lower confidence)
7. **Panel codes are HSVC-style RPC dispatch** — plausible analogy but mechanism unverified
8. **FPS-3000 lacks AP120-mode** — plausible but unverified
9. **EU PROM address layout** — fabricated detail, should be retracted
10. **TCBRDHC = "Read/Display/Help/Channel"** — unsupported expansion, likely hallucination

### Claims Requiring Retraction or Significant Softening
- **Detailed EU PROM address layout** (0o0000-0o0177 etc.) — no evidence, should be removed
- **TCBRDHC acronym expansion** — unsupported, should be removed
- **"HSVC-style RPC dispatch"** — should be softened to "dispatch table, architecturally analogous"

### Overall Assessment

The document makes several valuable cross-architectural connections that are well-supported by the evidence. However, it overreaches in three ways:

1. **Over-precision**: The EU PROM address layout gives a false sense of knowledge
2. **Unsupported acronyms**: TCBRDHC expansion is fabricated
3. **Mechanism conflation**: HSVC-style dispatch is a valid architectural analogy but the specific implementation mechanism is unverified

The document would be stronger if it clearly distinguished between:
- **Verified architectural parallels** (LODINP, scheduler move, command encoding)
- **Plausible analogies** (HSVC dispatch, single-mode architecture)
- **Speculative details** (EU PROM layout, specific mechanism implementations)

### GLM final

ERROR: HTTP Error 429: Too Many Requests

## Cluster audit: `methodology_meta`

**Methodology + LLM hallucination tracking**

### DeepSeek final

# AUDIT: methodology_meta cluster

## Q1: Are the 9 audited genuine findings (G1-G9) really verifiable against source text?

**Verdict**: MEDIUM confidence — **mixed, some are verifiable, some are not**

**Evidence**:
- G1 (memory-map collision): The claim references `CLAUDE.md` memory-map row `0xFF0000–0xFF025F`. This is a specific, checkable claim against a doc we have. **Verifiable** — HIGH confidence.
- G2 (150 vs 169 cable count): References specific line numbers in `cable_protocol_inferred.md`. **Verifiable** — HIGH confidence.
- G3 (Bomem DA3 may have used FPS-3000): References timeline overlap (FPS-3000 c.1983, DA3 1981–2000) and LOABOM.CMD referencing `loahpvp`. The claim is "may have" — speculative but grounded in observable facts. **Partially verifiable** — MEDIUM confidence.
- G4 (Am29116 terminology): This is a semantic/terminology claim. The Am29116 datasheet confirms it's a microprocessor, not a sequencer. **Verifiable against primary source** — HIGH confidence.
- G5 (EU control store PROM vs SRAM uncertainty): The triage doc itself says "the chip-photo identifications in CLAUDE.md leave the question open." This is self-referential — the uncertainty is real but the claim is about *uncertainty*, not a factual assertion. **Verifiable as uncertainty** — MEDIUM confidence.
- G6 (UNIV FMT card role underexamined): This is a claim about *absence* of documentation. Verifiable by checking whether our docs explain UNIV FMT. **Verifiable** — HIGH confidence.
- G7 (AP I/F card suffix interpretation): References GLM's claim about `-011..-017` and `-401..-403` suffixes. This is a claim about a claim — needs checking against the FPS Board Revision List PDF. **Not yet verified** — LOW confidence pending that check.
- G8 (VersaBUS timing not analyzed): Claim about absence of analysis. **Verifiable** — HIGH confidence.
- G9 (confidence-miscalibration on cable correspondence): References specific language in `cable_protocol_inferred.md`. **Verifiable** — HIGH confidence.

**Counter-evidence**: G7 is the weakest — it's a claim about what GLM said, not a direct observation. The triage doc says "check the FPS Board Revision List PDF directly" — this hasn't been done yet. G3 is speculative by design ("may have") and the chain-of-custody check hasn't been performed.

**Recommended action**: Accept G1, G2, G4, G6, G8, G9 as verified. Flag G3 as "plausible speculation pending Lovett inquiry." Flag G5 as "uncertainty confirmed, but no resolution." Flag G7 as "unverified — needs PDF check."

---

## Q2: Are the 5 hallucinated audit citations (H1-H5) really fabrications?

**Verdict**: HIGH confidence — **H1 and H4 are clearly fabrications; H2, H3, H5 are mischaracterizations, not fabrications**

**Evidence**:

**H1** ("Hockney p.240 says XP-32 uses Am2910A + Am2901/Am2903"):
- The triage doc claims: "I searched the actual Hockney PDF (`refs/FPS-5000/FPS3000_fps.pdf`) for '29116', '2901', '2910', 'sequencer', 'bit-slice', 'AMD', 'Am' — *no matches*."
- This is a specific, falsifiable claim. If the search was done correctly, this is a **confirmed fabrication**.
- **Confidence**: HIGH — the search methodology is straightforward and the claim is specific.

**H2** (GLM A-1: "WTL-1232/1233 is on bitsavers and Hockney's 1032/1033 is wrong"):
- The triage doc says this is a "misread" — our `architecture.md` already states this correctly.
- This is a **mischaracterization by the auditor**, not a fabrication. The auditor didn't read carefully.
- **Confidence**: HIGH that it's a misread, not a hallucination.

**H3** (DS C-1.1: "Am29116 cannot autonomously decode 16-bit commands; needs Am2910/Am2911"):
- The triage doc says this is "architecturally wrong" and cites the Am29116 datasheet.
- This is an **architectural error** by the auditor, not a fabricated citation. The auditor made a wrong technical claim.
- **Confidence**: HIGH that it's wrong, MEDIUM that it's a "hallucination" vs. genuine misunderstanding.

**H4** (DS A-1.2 cited quote: "Hockney p.241: 'The EU's control store is writable...'"):
- The triage doc claims: "Hockney's PDF does not contain that quote."
- Same verification as H1 — if the search was done correctly, this is a **confirmed fabrication**.
- **Confidence**: HIGH — fabricated quote.

**H5** (GLM A-INT.CONT: "CLAUDE.md describes EU PROM as fixed while implying SRAM storage"):
- The triage doc says this is a "misread" — parsing the same sentence two ways.
- This is a **misreading**, not a fabrication. The auditor misinterpreted consistent text.
- **Confidence**: HIGH that it's a misread.

**Counter-evidence**: The triage doc doesn't show the actual grep output or PDF page evidence. We're taking the triage author's word that the search was done. However, the claims are specific enough (page numbers, quotes) that fabrication is the most parsimonious explanation for their absence.

**Recommended action**: Accept H1 and H4 as confirmed fabrications. Reclassify H2, H3, H5 as "auditor errors" (misread, wrong technical claim, misread) rather than "hallucinations" — they're different failure modes. The triage doc conflates them.

---

## Q3: Is the project methodology explicit enough about the cross-checking-citations rule?

**Verdict**: MEDIUM confidence — **partially explicit, but with gaps**

**Evidence**:
- `08-methodology.md` states: "Validation: every LLM citation gets cross-checked" and "every audit/inference finding gets cross-checked against the actual source text via `pdftotext` / `grep` before being acted on."
- The triage doc demonstrates this was done for H1 and H4 (grep search of Hockney PDF).
- The workflow is documented: "Of 14 high-priority audit findings, 9 were genuine and 5 were fabricated."

**Counter-evidence**:
- **No automated enforcement**: The rule is a manual process ("gets cross-checked"). There's no CI check, no script that verifies citations before they're accepted.
- **No citation format requirement**: The docs don't require citations to include verifiable locators (page numbers, line numbers, PDF coordinates). The triage doc had to *infer* what was being cited.
- **No hallucination database**: The triage doc records H1-H5, but there's no structured database of known fabrications that could be checked against future LLM outputs.
- **No provenance tracking**: When a citation is verified, there's no record of *how* it was verified (which grep command, which PDF version, who ran it).
- **The 9/14 "genuine" claim is itself unverified**: The triage doc asserts 9 were genuine, but we haven't independently verified all 9. G7 is explicitly unverified.

**Recommended action**: 
1. Add a citation format requirement: every LLM-generated claim must include a verifiable locator (page number, line range, or PDF coordinate).
2. Create a `hallucinations.md` or `known_fabrications.md` with structured entries (model, date, claimed citation, actual source, verification method).
3. Add a `verify_citations.sh` script that automates the `pdftotext` + `grep` workflow.
4. Document the verification method for each claim (which command, which PDF, who ran it, date).
5. The "9 genuine" claim needs its own verification — currently it's an assertion in the triage doc, not a verified fact.

---

# SUMMARY

## Strongest claims in the cluster

1. **H1 and H4 are confirmed fabrications** — HIGH confidence. The specific page-number-and-quote format, combined with the reported grep search showing no matches, is strong evidence. This is the most important finding: it validates the project's skepticism about LLM citations.

2. **G1, G2, G4, G6, G8, G9 are verifiable** — HIGH confidence. These are specific, checkable claims against docs we have. They should be fixed.

3. **The cross-checking rule exists** — HIGH confidence. The methodology doc states it explicitly.

## Weakest claims in the cluster

1. **G7 (AP I/F card suffix interpretation)** — LOW confidence. It's a claim about what GLM said, not a direct observation. The triage doc itself says "check the FPS Board Revision List PDF directly" — this hasn't been done. **This should not be listed as "verified genuine" until the PDF check is done.**

2. **The 9/14 "genuine" ratio** — MEDIUM confidence. We've verified 6 of 9 (G1, G2, G4, G6, G8, G9) as genuinely verifiable. G3 is speculative, G5 is about uncertainty, G7 is unverified. The ratio might be 6/14 or 7/14, not 9/14.

3. **The H1-H5 classification** — MEDIUM confidence. H2, H3, H5 are mischaracterized as "hallucinations" when they're actually different failure modes (misread, wrong technical claim, misread). The triage doc conflates all LLM errors into "hallucination" when they have different root causes and different remedies.

## Critical gaps

1. **No independent verification of the triage doc's own claims.** The triage doc asserts it searched the Hockney PDF — but we don't see the grep output, the PDF version, or the search command. This is a meta-audit problem: who audits the auditor?

2. **No structured hallucination tracking.** The triage doc records H1-H5 in prose, but there's no machine-readable database. This means future LLM runs could produce the same fabricated citations and they'd need to be re-verified.

3. **The "cross-check every citation" rule is manual and unenforced.** There's no automated check, no format requirement, no verification log. It's a good intention, not a reliable process.

## Recommendations

1. **Verify G7** before acting on it — check the FPS Board Revision List PDF.
2. **Reclassify H2, H3, H5** as "auditor errors" (misread, wrong claim, misread) rather than "hallucinations" — they're different failure modes.
3. **Add verification provenance** to the triage doc: which grep command, which PDF, who ran it, date.
4. **Create a structured hallucination database** with model, date, claimed citation, actual source, verification method.
5. **Add a citation format requirement** to the methodology: every LLM-generated claim must include a verifiable locator.
6. **The "9 genuine" claim needs its own verification** — currently it's an assertion in the triage doc, not a verified fact.

### GLM final

ERROR: HTTP Error 429: Too Many Requests
