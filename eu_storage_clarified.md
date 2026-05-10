# EU storage: definitively PROM, not SRAM (correction of correction)

User asked: "I still don't understand how the proms would fill up
20KB of microcode" and "if microcode is in PROMs, why have RAMs at
all?"

The first question is answerable. The second question forced a
re-examination of my earlier claim that "EU is writable per Hockney"
— turns out that claim was wrong, based on a `pdftotext` misread.

## Hockney's actual text (verified with `pdftotext -raw`)

```
Microcode programs for the e u reside in e u p r o m , which contains
2K 80-bit microcode instructions.
Similarly, microcode programs for the a u reside in a writable control
store (wcs) of 4K 128-bit microcode instructions, arranged in four banks.
```

The italicized abbreviations get stripped by default `pdftotext`,
turning "the EU reside in EU PROM" into garble that I misread as
"EU reside in writable control store". The "Similarly, ... writable"
in the next sentence was a CONTRAST (AU is writable, unlike EU),
not a parallel.

**Verified architecture per Hockney**:
- **EU** = **EU PROM** (fixed, mask-programmed at factory) — 2K × 80-bit
- **AU** = **writable WCS** — 4K × 128-bit × 4 banks

## Answer to "20 KB in PROM is too much"

It's actually feasible. 1983-era bipolar PROMs:

| Chip | Per chip | Chips for 2K × 80 (20 KB) |
|---|---:|---:|
| 2K × 4-bit | 1 KB | 20 chips |
| 2K × 8-bit | 2 KB | **10 chips** |
| 4K × 4-bit | 2 KB | 10 (half-used) – 20 (full) |
| 4K × 8-bit | 4 KB | 5 (half-used) – 10 (full) |

10 chips of 2K × 8-bit, paralleled to give 80-bit width × 2K depth
= exactly 20 KB EU PROM. Reasonable count for an early-80s control
board.

## Answer to "why have RAMs if EU is in PROM"

**The RAMs on the EXEC card are not for the EU. They're for the AU.**

The architecture:
- EU sequencer (Am29116) runs from its FIXED bipolar PROMs (factory-
  set, 2K × 80-bit) — these implement the AP supervisor / dispatch
  / control logic
- AU FP pipelines (on the ARITH card) execute microcode FROM the
  WRITABLE SRAM array on the EXEC card — these are the user's math
  kernels (XPMLIB: ZVMUL, ZRFFT, etc.)

```
EXEC card                              ARITH card
─────────────                          ──────────
Am29116 ←── reads from ─── EU PROM     WTL-1232/1233 ←── reads from ─── AU WCS
                          (fixed,                                       (writable
                          factory)                                      SRAM)
                                          ↑
                                          │ AU microinstructions cross
                                          │ the inter-card connector
                                          │
[SRAM array = AU WCS] ────────────────────┘
[PALs = decode logic]
[74F = glue]
```

The EXEC card holds both stores because the EU is the executive that
issues AU microinstructions. By keeping the AU WCS close to the EU
sequencer, microinstruction-fetch latency is minimized.

## What this corrects in the project

| Doc | Earlier claim | Corrected |
|---|---|---|
| `correction_eu_writable.md` | "EU is writable per Hockney" | **Wrong** — pdftotext misread. Doc retracted. |
| `eu_upload_trace_v3.md` H1 | "EU might bootstrap from EXEC bipolar PROMs into writable WCS" | **Simpler**: EU IS the bipolar PROMs. No bootstrap needed. The PROMs ARE the runtime store. |
| `VERIFIED_CLAIMS.md` R2 | Retracts "EU = fixed mask PROM" | **R2 is itself retracted**. The original project doc was correct: EU = fixed PROM. |
| `mc_doc_audit_triage.md` G5 | Marked "RESOLVED via Hockney: writable" | **Resolution wrong**. Re-resolve as "EU = fixed PROM per Hockney `-raw` extraction". |
| `cliffsnotes/05-microcode.md` | "writable WCS per Hockney" | Restore to "fixed PROM per Hockney" |

## Methodological lesson (added to the project's running list)

**`pdftotext` strips italicized inline abbreviations**, especially
when they're 2-3 letter sequences like `eu`, `au`, `wcs`. Always use
`pdftotext -raw` (preserves character order) when reading PDFs that
make heavy use of italicized acronyms in technical descriptions.

The audit-itself-can-hallucinate lesson now also includes: **my own
direct primary-source verification can be wrong if the extraction
tool is mangling the source.** Tool failure mode matters as much as
LLM hallucination.

## What this means for the project

The EU PROM dump remains the path forward to recover EU contents —
just unambiguously now: those bipolar PROMs ARE the EU contents,
factory-mask-programmed, fixed. Read them with a universal PROM
programmer and the EU runtime is recovered.

The 21 documented panel codes (plus 0x27E-0x282 from Dispatcher B,
plus 0x29E-0x29F from RTOSKernelInit) are dispatch indices into the
EU PROM's handler table. Once the PROM is dumped, those 28+ codes
can be mapped to specific handler routines.

The SBC ROM has no EU upload path because the EU has no upload
mechanism — its contents are factory-fixed. The SBC just dispatches
to it.

## Revised hypothesis ranking (4th revision)

| # | Hypothesis | Confidence |
|---|---|---|
| H1 | **EU contents are the bipolar PROMs themselves (fixed, mask-programmed at factory)** | **HIGH** (Hockney directly says "EU PROM") |
| H2-H5 | All previously-considered alternatives | LOW (no longer needed; H1 directly explains everything) |

The whole "where does EU upload happen" question dissolves: there
is no EU upload, because EU contents are not loaded — they're built
into the PROMs at manufacture.

User's intuition was correct: the SBC ROM having no EU upload path
isn't a mystery to solve, it's a confirmation that the EU is not
host-loaded. The "writable WCS for EU" reading was based on a
tool-extraction error.
