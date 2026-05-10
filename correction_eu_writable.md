# Correction: EU control store is WRITABLE, not fixed PROM

Audit-triage item G5 (in `mc_doc_audit_triage.md`) marked the
"EU control store: PROM vs SRAM" question as open. The answer was
in Hockney's PDF the whole time.

## Primary-source finding

Direct quote from `refs/FPS-5000/FPS3000_fps.pdf` (Hockney & Jesshope,
*Parallel Computers 2*, §2.5):

> "...reside in a writable control store, which contains 2K 80-bit
> microcode instructions.
> Similarly, microcode programs for the [arithmetic coprocessor]
> reside in a writable control store (WCS) of 4K 128-bit microcode
> instructions, arranged in four banks."

So **BOTH** the EU and the AU have writable control stores per
Hockney. The "EU = fixed mask PROM" model in our docs was wrong.

## What needs correcting

| Doc | Wrong claim | Corrected |
|---|---|---|
| `CLAUDE.md` | "Executive Unit (Am29116-class controller) \| fixed PROM \| 80-bit \| 2K words \| mask-programmed at the factory" | EU control store is **writable** per Hockney; size and width correct |
| `architecture.md` | "EU control store \| 2K × 80 bit \| Am29116 sequencer program \| bipolar PROM — fixed mask, on EXEC card" | Same correction |
| `cliffsnotes/02-hardware.md` | "Bipolar PROMs — likely the EU's fixed program store (Hockney's '2K × 80')" | EU is writable; the bipolar PROMs may be a boot loader, OR may be the WCS itself with one-time-programmable behavior |
| `cliffsnotes/05-microcode.md` | "Executive Unit ... fixed PROM (likely)" + "The SBC ROM only uploads AU microcode, not EU" | EU is writable per Hockney; SBC may also upload EU code (we just haven't traced that path yet) |
| `mc_doc_audit_triage.md` G5 | "Open question. Photo re-inspection needed" | RESOLVED via Hockney; both writable |

## What this changes for the project

Significant implications:

### 1. Microcode upload path may be more complex than assumed

The 64 KB SBC RAM staging buffer at `0x10000-0x1FFFF` exactly matches
**one bank of the 4K × 128-bit AU WCS** (= 64 KB). We assumed this
meant the SBC only uploads AU microcode.

But if the EU is also writable (2K × 80 bit = 20 KB), then the SBC
must have a path to upload EU microcode too — possibly via the same
staging buffer at a different size, or via a separate panel command,
or via the host taking over the upload directly.

**New question to investigate**: where in the SBC ROM is the EU
microcode upload path? Or is it strictly host-driven, bypassing the SBC?

### 2. The 21 panel codes may include EU-load-bank commands

Some of the 21 panel commands (0x258-0x27D) might be EU-microcode-
upload triggers, not just AP runtime control. A close read of the
PanelStatusDispatchTable (F05BA4, 20 entries) plus the panel-code
sites might reveal one or two that look like "load EU bank" rather
than "run AP routine".

### 3. EU PROM contents are not "fixed at factory"

The "EU PROM" terminology was incorrect — there are no factory-fixed
ROM contents to read. Lovett would need to dump the WRITABLE control
store after boot (when it's been loaded), not before.

This changes the EU-PROM-read difficulty:
- Before: desolder bipolar PROM + read with universal programmer
- Now: tap into the WCS while the AP is powered up + read via JTAG
  / signal probing, OR boot the system + dump RAM contents

### 4. The "Am29116 + bipolar PROMs" interpretation needs revision

The bipolar PROMs visible on the EXEC card (Nakazoto photos) might
NOT be the EU control store. They could be:
- A small boot ROM that initializes the Am29116 enough to receive
  EU microcode via the host upload path
- Decode logic / address maps
- Microcode for a control unit smaller than the full EU
- Something else entirely

The Am2168/CY7C168 SRAMs visible on the same card are then the most
likely **actual EU WCS** (writable, ~2K words at 80 bits would
require multiple SRAM chips). Photo re-inspection with this hypothesis
would be more productive.

### 5. The audit triage needs updating

`mc_doc_audit_triage.md` G5 should move from "Open — needs photo
re-inspection" to "RESOLVED via Hockney primary source". The status
docs in cliffsnotes should reflect this.

## Confidence

This is a **primary-source-verified correction** — Hockney's PDF text
is unambiguous on the writability point. There's no LLM hallucination
risk because I've verified the exact quote via `pdftotext` of the
local PDF copy.

The downstream implications (whether the SBC uploads EU microcode,
how the EU is initialized at boot, what the bipolar PROMs actually
do) require additional investigation. But the basic claim — both
control stores are writable — is settled.

## Action items

1. ✓ Document the correction (this file)
2. Update `CLAUDE.md`, `architecture.md`, cliffsnotes 02 + 05
3. Update `mc_doc_audit_triage.md` G5 to RESOLVED
4. Update `xp32_microcode_format_inferred.md` and other docs that
   reference "fixed PROM" or "mask-programmed"
5. Investigate the SBC ROM for EU upload path (separate from AU
   upload at `0x10000-0x1FFFF` staging)
6. Re-examine Nakazoto's EXEC card photo with the new hypothesis
   (SRAMs = EU WCS, bipolar PROMs = boot ROM or decode logic)
