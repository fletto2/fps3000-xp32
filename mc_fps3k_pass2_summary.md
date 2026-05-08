# MC pass 2 — disassembly annotation with updated context

Re-ran `mc_fps3k.py cooperative` after baking the recent inference and
audit findings into the hardware-context block:

- panel codes decode as Am29116 TOR1 SUBRC instructions (Groups A/B)
- consensus 128-bit XP-32 AU layout
- stress-test caveats (EU_ADDR width, missing pipeline-stall, etc.)
- audit triage corrections (memory-map split AP I/F vs XLTR, EU
  control-store uncertainty)
- absence of any public XPMLIB binary; FPS-100 archive as substitute

## Run statistics

| Round | Seed | Samples | YES% | BOTH% | Time |
|---|---|---|---|---|---|
| R1 | 42 | 50 | 100.0 | 60.0 | 450s |
| R2 | 99 | 49 | 98.0 | 80.0 | 377s |
| R3 | 777 | 50 | 100.0 | 80.0 | 507s |
| R4 | 2026 | 50 | 100.0 | 72.0 | 396s |
| R5 | 31337 | 50 | 100.0 | 94.0 | 221s |
| **Total** | — | **249** | **99.6** | **77.2** | **32 min** |

249 of 250 samples accepted; 192/249 (77%) had BOTH-LLM agreement —
the highest BOTH-rate of any FPS-3000 MC pass to date. Updated context
sharpened model agreement.

Output: `mc_fps3k_pass2_annotations.txt` (28.5 KB, 250 annotation
lines).

## New structural findings

### Per-channel dispatch table at `F046E0`

Multiple samples independently identified a dispatch table at
`F046E0` indexed by channel number. Used by:
- `f04ce8` (PanelSendAndWait callsite) — adds channel index to
  table base + `0xFF0000`
- `f0540c` (`adda.l d3, a3` in S-record finalize) — selects
  per-channel handler

This is a **new label candidate**: `ChannelDispatchTable` at
`F046E0`. Not in `fps3k_clean.asm`'s current label set.

### Per-channel-controller RAM globals (named through context)

Recurring globals that the LLMs interpret consistently:

| Address | Purpose |
|---|---|
| `$E58.l` | microcode-staging address pointer (already known as `g__srec_addr`) |
| `$E60.l` | channel count / index |
| `$E68` | command argument |
| `$E74.l` | command-argument echo (mirrored to `0xFF000E`) |
| `$E86.l` | current channel state / mode bits |
| `$E87` | global status byte (bit 7 = error flag) |
| `$1054.l` | max staging-buffer size limit (validated against length in S-record handler) |
| `$10A1` | per-block completion-flag bit table |

### Address-range coverage

- 70% of sampling biased to `F046xx-F058xx` (XP-32 comms kernel)
- 30% sampled across the full ROM
- 239 unique addresses across all 5 rounds

The XP-32-comms range got dense coverage with high BOTH agreement,
producing a tight semantic map of the panel-command path. Many
labels in `f04600-f048ff` are absent from the current annotated
disassembly and could be added via a `build_clean_disasm.py` rerun.

### Validation of recent inferences

Round 1 sample at `f04784` independently produced:

> "calls `PanelIOConfigure_25A` with d0=0x278, which is a panel
> command that decodes as an Am29116 SUBRC instruction (Group B,
> TODRA class)"

The model used the recent panel-code inference correctly without
prompting — confirming that the updated context block is being
applied during reasoning.

### What's still UNKNOWN

- No annotation distinguished between Interpretations 1/2/3 of
  the panel codes (dispatch index / MMIO trigger / hybrid). The
  ROM evidence is consistent with all three; disambiguation still
  requires the EU PROM read OR direct bus traces.
- The "EU control store: PROM vs SRAM" question (audit G5) was not
  resolved by ROM evidence — the ROM only ever uploads to one bank
  (the 64KB AU staging buffer). The EU is opaque from the ROM side.

## Recommended next steps

1. Add `ChannelDispatchTable` at `F046E0` and the named globals
   above to `build_clean_disasm.py`'s symbol table.
2. Skim the 250 annotations for any that genuinely contradict
   existing labels in `fps3k_clean.asm`. If found, file as audit
   followups.
3. Consider an adversarial-mode pass (`MODE=adversarial`) on the
   subset where BOTH disagreed (~57 samples) — those are where
   one model saw something the other missed.
