# ds2/ Document Errata

Errors found during cross-reference review against source files
(`versabus.c`, `fps3k_sbc.c`, `fps3k.asm`, `CLAUDE.md`).

Date: 2026-07-29

---

## Remaining Issues (not fixed — informational)

### I1. FPS3K_BSTAT19_CLR — documented but never implemented

### I1. FPS3K_BSTAT19_CLR — documented but never implemented

Mentioned in versabus.c line 940 comment as a preferred alternative to
FPS3K_BSTAT19, but never actually implemented with a `getenv()` call.
Documented in ENVVAR_HOOKS.md as "unused" — this is accurate but worth
noting for completeness.

### I2. FUNCTION_COVERAGE.md — "ROMChecksum_etc" at F098EE

The name "ROMChecksum_etc" for F098EE is inherited from
`ds/FIRMWARE_GAPS.md`. The companion routine F08DF8 was correctly
renamed to `BoardStatusPoll_3F11` after the 2026-07-26 label
correction, but F098EE's name was not similarly reviewed. The
disassembly labels it as `loc_F098EC`/`loc_F098E0` — no symbolic
name is assigned. Whether F098EE actually computes a ROM checksum
or is another misnamed routine is unknown; the label should be
treated as suspect.

### I3. RAM_SYMBOLS.md — $1080 per-channel pointer table

Identified by MC pass as a "per-channel data-pointer table" but never
decoded. The exact shape (number of entries, stride, what each entry
points to) is unknown. If decoded, it would reveal how the four XP
tasks locate their per-channel state windows at $1060 + (ch-1)*$20.

### I4. PANEL_COMMANDS.md — TODRA group size

The Am29116 decode says Group B (TODRA, $260-$27D) = 30 codes. But
`0x27D - 0x260 + 1 = 30`. However, $27E+ are not SUBRC at all.
The subgroups break at $27D (TODRA end) and $27E-$282 (TCBIO1I
codes, non-SUBRC), so the range is correctly stated.

### I5. All documents — self-test phase count ambiguity

Various documents mention "~15 self-test phases" (0x700-0x1A00) but
the exact count and ordering is approximate. The phase numbering comes
from CHANNEL_SELECT values written before each test; the numbering
might skip values or have additional phases beyond 0x1A00. The
CLAIM.md says phases exist at 0x700, 0x800, 0x900, 0x1000, 0x1100,
0x1200, 0x1300, 0x1400, 0x1600, 0x1700, 0x1800, 0x1900, 0x1A00
(13 phases). "~15" should be "13 confirmed."

---

## Documents Verified — No Errors Found

- **GAP_ANALYSIS.md**: cross-referenced all 27 gap items against source;
  all claims supported by evidence in versabus.c, fps3k_sbc.c,
  fps3k.asm, or CLAUDE.md.

- **FUNCTION_COVERAGE.md**: address ranges verified against
  FIRMWARE_GAPS.md and CLAUDE.md function inventory. Coverage
  percentages match emulator execution data (19% overall, 8% TCBRDHC,
  30% TCBIO1I, 4-6% XP tasks).

- **PANEL_COMMANDS.md**: all 29 named codes verified against
  versabus.c:118-151 panel-code switch. SUBRC decode verified
  against AMD Am29116 datasheet (documented in CLAUDE.md).

- **RAM_SYMBOLS.md**: all 26 variable addresses verified against
  `fps3k.asm` absolute reference scan output. No spurious entries.
