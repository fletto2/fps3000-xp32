# EU upload path in the SBC ROM — trace result

> **SUPERSEDED by `eu_upload_trace_v2.md`** — v1 missed the second
> dispatch path (loc_F05E56) and the 0x700000 shared memory region
> used by TCBIO1I. The EU upload path IS in the SBC ROM, just not
> via the S-record/TCBRDHC route that v1 examined.


**The EU upload path is NOT in the SBC ROM.** The SBC ROM exclusively
handles AU microcode staging. EU initialization must happen via a
mechanism outside the SBC's purview.

## Methodology

Searched the SBC ROM disassembly (`fps3k_clean.asm`, ~22K lines) for:

1. Any non-AU-staging-related buffer base addresses
2. Loops sized to match the EU (2K × 80 = 20 KB or 2048 words)
3. Writes to XLTR registers other than the well-known AU upload pattern
4. Boot-time init sequences that could carry EU bootstrap

## What the SBC ROM actually does for microcode

Single upload pipeline traced end-to-end:

```
Host ──S-records──► AP I/F (0xFF0000)
                          │
                          ▼ TCBRDHC dispatches based on record type
                    ┌──────────────────────────────────┐
                    │ SRecordDataHandler (F051A2)      │
                    │   - Polls XLTR_STATUS_IRQ b15    │
                    │   - Reads 16-bit words from (a0) │
                    │   - Validates 0x10000 ≤ addr ≤   │
                    │     0x1FFFF (the AU staging      │
                    │     buffer range)                │
                    │   - Stores byte-by-byte to       │
                    │     (a1)+ in SBC RAM             │
                    └──────┬───────────────────────────┘
                           │
                           ▼ End of record (S5/S7/S8/S9)
                    ┌──────────────────────────────────┐
                    │ SRecordFinalize (F05256)         │
                    │   - Pad/finalize the record      │
                    │   - For S3/4/5: prepare DMA      │
                    │   - For end records: enter       │
                    │     poll-and-write loop at       │
                    │     loc_F0529E                   │
                    │   - Issues PCMD_CH4_CONFIG       │
                    │     (0x260) to trigger transfer  │
                    └──────────────────────────────────┘
```

Address validation at `F051FE`:

```asm
F051FE: cmpa.l  #$10000, a1
F05204: blt.b   loc_F05212    ; below staging range → error
F05206: cmpa.l  #$1FFFF, a1
F0520C: bgt.b   loc_F05212    ; above staging range → error
F0520E: move.b  d2, (a1)+     ; otherwise: store in staging buffer
```

The validation is **strictly `0x10000 ≤ addr ≤ 0x1FFFF`** — the
64 KB SBC RAM staging buffer that exactly equals one bank of the
AU's 4K × 128-bit WCS. Anything outside this range goes to error
recovery (`loc_F05212` → `PanelIOConfigure_25A.l` with
`PCMD_CH1_ACK`).

## What's NOT in the SBC ROM

After exhaustive disasm search:

- **No second buffer base address** sized for the EU (would be
  20 KB for 2K × 80-bit). All large-buffer references are 0x10000.
- **No loop counter matching EU sizes** (2048, 0x800, 0x7d0).
  The constants `#$800` that appear are `g__ctx_save` task-context
  storage, unrelated to microcode.
- **No alternate XLTR register bank** addressed for EU upload.
  All XLTR data writes go to `0xFF0214/0216/0218` (AU path) or
  `0xFF0048/4E/68/6E/88/8E/A8/AE` (per-channel data ports).
- **No INIT_STEP panel command** is an upload trigger. Codes
  `0x276..0x27D` are dispatched ONLY after `trap #1` (RMS68K TCB
  lookup) returns failure (`beq.b skip` follows the trap). They're
  TCB-failure recovery, not initialization-load triggers.
- **MainInit's d6-incrementing chain** runs hardware diagnostics
  (RAMAddressingTest, ROMChecksumTest, MemBusProbe, IOChannelDiagnostic,
  PanelBusDiagnostic) but no microcode upload.
- **HardwareInit** does channel-select cycling and board-status
  polling, no microcode upload.
- **Phase2Init** does RTOS kernel init (Init_GST/UST/IOV/IDV/PAT/UDR
  table-builds), no microcode upload.

## Where the EU upload must actually happen

Three remaining hypotheses, in order of plausibility:

### Hypothesis 1: EU bootstraps from the bipolar PROMs on the EXEC card

The Nakazoto photo of the EXEC card shows bipolar PROMs in DIP-20
packages. Even though Hockney says the EU is "writable", the
bipolar PROMs may serve as a **boot ROM** that gets copied into
the writable WCS at chassis power-on by a small hardware-driven
sequencer (independent of any host code).

This would mean:
- EU microcode is effectively factory-fixed (frozen at the bipolar
  PROM contents)
- "Writable" means the host CAN overwrite it after boot, but in
  normal operation never does
- The 21 panel commands implement a static dispatch table whose
  contents come from those bipolar PROMs

This matches the SBC ROM behavior: panel commands work as soon as
the SBC starts sending them, with no apparent prior load step.

### Hypothesis 2: Host loads EU directly via the AP I/F card

The host-side AP I/F card (currently missing — being substituted
with FPGA per `host_substitute_hardware_plan.md`) might have a
direct path to the EU bus that bypasses the SBC entirely.

This would mean:
- Host runs an EU-load procedure as part of FPS-3000 cold-start,
  before any SBC interaction
- The SBC ROM never sees EU code, only AU code
- Consistent with host running its own LED100-equivalent that
  produces both EU and AU load modules

This matches the FPS-100 model where APDRV's `RUNDMA` function code
loads any AP memory from host RAM. Could be one panel-bypass mode
in the FPS-3000 too.

### Hypothesis 3: EU is loaded from SCM (System Common Memory)

SCM is shared between the AU and the SBC; maybe also the EU. EU
might initialize from a designated SCM region populated by the host
through one of the four channel data ports.

Less likely because:
- SCM access requires the SBC to have configured channels first
- That requires the EU to already be running (chicken-and-egg)
- The SBC ROM's TCBXP*I tasks all assume EU is alive

## Implication for the project

This finding **changes the substitute-hardware design** for the
host-side AP I/F card:

- Originally we'd assumed the substitute card just needed to handle
  the host↔SBC protocol; the SBC handles all AP-side complexity.
- If EU loading actually goes through the AP I/F card directly
  (Hypothesis 2), the substitute needs to handle EU upload too.
- If EU loads from PROM at power-on (Hypothesis 1), the substitute
  doesn't need to worry about EU at all — but we'd need to read
  those bipolar PROMs on the EXEC card to know what's in them.

## Concrete next-step suggestion

Examine the Nakazoto EXEC card photo for the bipolar PROMs more
carefully. Specifically:

- Count the chips
- Read part numbers if visible
- Estimate organization (e.g. eight 256-byte DIP-20s = 2K bytes;
  if 80-bit-wide PROM, that's 200-word × 80-bit = ten DIP-20 chips
  in parallel)

If the PROM count + organization matches "2K × 80-bit", Hypothesis 1
is confirmed: EU is **boot-loaded from PROM** to writable WCS at
power-on, and the WCS contents we need are exactly the PROM
contents.

This makes EU PROM dump still the path forward — just with the
caveat that what we're dumping is a boot ROM, not the runtime
WCS contents (which are a copy of the boot ROM unless the host
overwrites them).

## Trace verdict

| Question | Answer |
|---|---|
| Does the SBC ROM upload EU microcode? | **No.** Confirmed by exhaustive disasm search. |
| Where does EU code come from? | Most likely from bipolar PROMs on the EXEC card, copied into writable WCS at boot. |
| Does this contradict Hockney's "writable WCS"? | **No.** "Writable" is a property of the storage; doesn't preclude factory-loaded contents that nobody overwrites in normal operation. |
| Should we still try to dump the EU? | **Yes.** The bipolar PROMs ARE the EU contents (almost certainly). Read those, get the EU. |
| Does this affect the FPGA AP-I/F substitute design? | **Slightly.** Substitute doesn't need to handle EU upload (assuming Hypothesis 1 is correct), but should pass through any EU-load traffic the host might emit (in case Hypothesis 2 is correct in some configurations). |

## Confidence

**HIGH** that the SBC ROM does not upload EU microcode (exhaustive
disasm trace).

**MEDIUM-HIGH** that EU bootstraps from EXEC-card bipolar PROMs
into writable WCS at power-on (Hypothesis 1) — best fit with both
Hockney's text and the SBC ROM behavior.

**LOW** that host-direct upload (Hypothesis 2) is the answer — would
require additional protocol machinery we don't see evidence for.

**LOW** that SCM-based loading (Hypothesis 3) is the answer —
chicken-and-egg problem.
