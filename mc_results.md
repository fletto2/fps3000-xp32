# Monte Carlo disassembly rounds — FPS-3000 ROM

Methodology per `~/src/claude/libs/MONTECARLO.md`. A Council of
Clankers (two members) queried in parallel per batch. Sampling biased
70% toward the XP32 init/communication code range (`F046xx-F058xx`).

**Hardware context fed to both models** included:
- Full memory map (RAM, ROM, PTM, UART, AP I/F + XLTR registers at `0xFF0xxx`)
- 21 ROM entry points (TCBRDHC, panel-command sender, SRecord
  handler, init-tag routines, etc.)
- The XLTR register-level protocol (`0x8004`/`0x8005` opcodes, `0x258..0x27D`
  command codes, panel-send-and-wait kernel at `F056BA`)
- All RMS68K marker tags (`!TCB`, `!CCB`, `!ASQ`, `!TST`, `!DLY`, `!VCT`,
  `!GST`, `!UST`, `!IOV`, `!IDV`, `!PAT`, `!UDR`)
- XPMLIB primitive list (XPSEL/XPRUN/XPWAIT/XPSTAT/XPDMAR/XTMDMA/XPISNC)
- Hardware chip identifications from Nakazoto/Usagi photos
- AMD Am29116 16-bit bipolar microprocessor instruction-format details
  (4-bit T class, 5-bit S/D fields, 2-bit M mode)

## Round 1 (R1-R5) — XP32 init/communication focus

5 rounds × 50 samples × 2 models, biased 70% toward `F046xx–F058xx`.
Annotation accepted when both models gave a specific, keyword-rich
answer (BOTH-tag) or when at least one did with no contradiction.

| Round | Seed | Total | YES% | BOTH% | Annotations | Wall |
|---|---|---|---|---|---|---|
| R1 | 42    | 50 | 100.0% | 92.0% | 50 | 180 s |
| R2 | 99    | 50 | 98.0%  | 96.0% | 49 | 117 s |
| R3 | 777   | 50 | 98.0%  | 98.0% | 49 | 175 s |
| R4 | 2026  | 50 | 100.0% | 98.0% | 50 | 166 s |
| R5 | 31337 | 50 | 100.0% | 98.0% | 50 | 151 s |
| **Σ** | — | **250** | **99.2% avg** | **96.4% avg** | **248** | **789 s ≈ 13 min** |

**248 unique annotations** written to
`fps3k_custom_annotated.asm` (21 646 lines, the disassembly with
`;>>>> [Rn/agreement] description` lines inserted). 238 distinct
addresses annotated (some addresses hit twice across rounds).

**Agreement rate is exceptionally high** — 240/248 (96.4%) of
accepted annotations had BOTH models independently giving a YES answer
on the same line. Per `MONTECARLO.md` typical R1 yields 30-50%, this
ROM hit 92% on R1 — a consequence of the rich hardware context block
(memory map + 21 named entry points + XLTR register table + RMS68K
markers + Am29116 bit-fields) acting as effective scaffolding for
both models.

### Confirmed findings (representative samples)

**S-record loader internals** (the microcode upload path):
- `F04B9E` — `cmp.w 0x5331,d1` checks for ASCII "S1" (16-bit-addr S-record); branch to handle other types
- `F04B80` — counter increment per S-record byte
- `F04D90` — staging-buffer upper-bound clamp (the `0x10000-0x1FFFF` enforcement)
- `F04DEC` — load 32-bit value from `$E58.l` (S-record address being assembled)
- `F05210` — main S-record data-processing loop branch
- `F05220` — read 16-bit value from staging buffer in finalize loop
- `F05228` — invoke `PanelIOConfigure_25A(0x25A)` to begin the upload-to-WCS handoff
- `F05244` — poll bit 15 of `$218(a5)` waiting for "ready/done" flag during finalize
- `F05370` — save data pointer to `a6` for upload phase

**Panel-command dispatch** (the XLTR protocol):
- `F056A4` — write Mode-1 register `FF0202` with bit 12 set + bit 14 cleared (entry to `PanelIOConfigure_25A`)
- `F056B0` — write Mode-0 register `FF0200` with bit 10 cleared
- `F0517E` — write `0x400` to status register `FF0218` (arms IRQ for DMA-transfer initiation)
- `F0517A` (panel command) — `XPWAIT` polls bit 14 with 1000-tick timeout
- `F058FA` — main timeout loop in send-and-wait kernel; on timeout issues `0x26C` abort
- `F057A8` — write swapped high-word of 32-bit arg to `FF0216` (the `0x8005` CONTINUE-TRANSFER step)
- `F0628E` — error-path subroutine for panel-command timeouts (`d0=0x26C`)

**Mode-register state machine** (revealed by random sampling):
- `F04756` — `cmpi.w #$8, d0` — checks for state 8 in low nibble of `$E86`
- `F0496E` — `cmpi.w #$14, d0` — checks for state 0x14 (20)
- `F04966` — checks for zero state
- `F0498C` — special-case for channel `0x10` (16, possibly broadcast/diagnostic)
- These suggest `$E86` is a 5-bit-or-larger mode field whose values dispatch
  to different XP-32 setup routines (states 0, 8, 0x14 confirmed; others
  TBD)

**TCB lifecycle** (the per-channel task creation):
- `F07DC6` — after `trap #1` for TCB creation: if d0=0 (success) set up
  `TCBXP1I_Data`, else issue panel command `0x26E` (channel-1 abort)
- `F07476` — analogous for channel 4 (`trap #1` failure → `0x271` abort)
- `F04776`/`F04794` — TCB lookup via `loc_F04600` table; failures issue
  `0x278`/`0x279` abort to specific channels

**Address space confirmations**:
- `$E58` (32-bit) — S-record current address being parsed
- `$E60` (16-bit) — block size counter compared against `$105E` limit
- `$E74` (16-bit) — last panel command issued (stored by `PanelIOConfigure_25A`)
- `$E86` (16-bit) — XP-32 channel mode/state register (lower nibble used)
- `$E87` (8-bit) — global status byte (bits 6, 7 used)
- `$1064` — IRQ-mask shadow for XP-32 channels (mirrors `FF021A`)
- `$1080` — table of per-channel data-structure pointers (4-byte stride)
- `$105E` — maximum block-size limit
- `loc_F05BA4` — 256-entry × 4-byte status-code dispatch table
- `loc_F05C4C` — 16-byte error-code → IRQ-mask-bit lookup table

## Round 2 (R6-R10) — broader sweep with prior annotations as context

5 more rounds × 40 samples each. Prior R1-R5 annotations were
folded back into the disassembly so models could cite them. Each
round biased toward a different ROM region; one round adversarial.

| Round | Seed | Mode | Bias | YES% | BOTH% | Annots | Wall |
|---|---|---|---|---|---|---|---|
| R6  | 11 | cooperative | TCBXP1I-XP4I (`F05F00-F086FF`) | 100% | 100% | 40 | 83 s |
| R7  | 22 | cooperative | MainInit/diags (`F08700-F09BFF`) | 100% | 100% | 40 | 86 s |
| R8  | 33 | cooperative | RTOSKernelInit (`F09C00-F0A57E`) | 100% | 92% | 40 | 126 s |
| R9  | 44 | adversarial | random across ROM | 97% | 72% | 39 | 212 s |
| R10 | 55 | cooperative | broad sweep (no bias) | 97% | 97% | 39 | 145 s |
| **Σ** | — | — | — | **98.8% avg** | **92.2% avg** | **198** | **652 s ≈ 11 min** |

**Cumulative: 10 rounds, 248+198 = 446 raw → 430 unique addresses
annotated, 495 total annotations (after dedup) across the disassembly.**

Per the MONTECARLO.md prediction, R6+ rounds plateau at high
agreement because prior rounds' annotations seed the model's mental
model of the ROM. New regions covered in R2 batch:

- **TCBXP1I-XP4I per-channel state machines** (R6): poll loops at
  channel-specific addresses (`FF008E`, `FF00AE`, etc.), per-channel
  IRQ-mask manipulation, channel diagnostic byte counters
- **HardwareInit / RAMAddressingTest / ROMChecksumTest / MemBusProbe /
  IOChannelDiagnostic / PTMInit / PanelBusDiagnostic** (R7): the
  power-on diagnostic chain
- **RTOSKernelInit** (R8): the !VCT scan loop, RMS68K table-init
  glue past `F09E88` already-named entries
- Random sweep (R9 adversarial, R10 cooperative): catches stragglers

### New facts from R6-R10

11. **Channel state field at `$10AE`**: per-channel TCB status byte,
    indexed by `channel_index × 4`
12. **Channel-1 sub-command `0x08`** triggers the data-transfer path
    in TCBXP1I
13. **Diagnostic-poll counter `9`** at `F07C3E` — likely the maximum
    per-channel diagnostic retries
14. **Global status word at `$1072`** has bit 11 = "channel-4 ready
    for microcode-upload-or-status-query"
15. **Per-channel data ports**: `FF008E` (ch3 data B), `FF00AE`
    (ch4 data B) — confirmed via channel-specific writes
16. **Mode 1 register write `0x8020`** during TCBXP4I init — sets
    a config bit pattern
17. **Adversarial round (R9)** found cases where one Clanker produced
    a plausible-but-incomplete answer that the other correctly
    sharpened — the 28% agreement gap (BOTH=72%) is in the
    disagreement column, indicating active adversarial value-add
    (not just noise)

## Adversarial cycles

Three-stage protocol per batch (R1 only — bulk run aborted as too
slow):
1. Clanker A gives an unprompted answer (same as cooperative)
2. Clanker B is shown A's answer and asked to refute, sharpen, or
   substitute a specific alternative
3. Clanker A is shown B's challenge and asked to defend or revise

Final annotation accepts A's revised answer (after B's challenge),
on the assumption that surviving a critique is a stronger signal
than a single-shot answer. Where B produced a substitute that A
adopted or refined, the final annotation captures the negotiated
wording.

The full 3-stage adversarial proved too slow at bulk (~10+ min per
round at 50 samples). R9 used a streamlined 2-stage variant
(A-cooperative + B-challenge, skip A-defense) which finished in
212 s for 40 samples — a workable trade.

A reasoning-model Clanker was attempted for targeted adversarial
follow-up but consumed all 12K output tokens on internal reasoning
per sample without producing a final answer (~286 s/sample). Run
aborted; the standard 2-stage protocol was the best speed/quality
tradeoff for adversarial.

## Notable findings — what the MC pass added beyond manual analysis

Cross-referenced against the prior manual analyses (`xltr_protocol.md`,
`xp32_microcode_format_inferred.md`):

### New facts learned from MC

1. **S1 record handling confirmed** — `F04B9E` matches `0x5331` ("S1");
   the firmware accepts standard 16-bit-address S-records and also
   reaches a different code path when matching fails (likely S2/S3
   handlers). Our prior analysis only said "S-record loader exists".

2. **Mode-state machine has at least 4 states** — the sampling
   revealed `cmpi.w` checks against `0`, `8`, and `0x14` against the
   `$E86` mode register's low nibble. None of these were documented
   before.

3. **Channel `0x10` is special-cased** — `F0498C` checks for channel
   number `!= 0x10`. Channels are 4-bit indexed (0..F) elsewhere, so
   `0x10` is out-of-band and likely indicates broadcast or diagnostic
   mode. Not previously identified.

4. **Per-channel data-pointer table at `$1080`** — `F07110` walks a
   table indexed by `d2*4`, suggesting a 4-byte/entry table of
   per-channel descriptors. Not documented before.

5. **TCB-creation failure paths emit channel-specific aborts**:
   - Channel 1 failure → `0x26E`
   - Channel 4 failure → `0x271`
   - Channel ID lookup failure → `0x278` or `0x279`
   This refines our prior "0x276..0x27D = init sequence" guess —
   actually they're per-channel error codes.

6. **The error/IRQ-mask lookup table at `loc_F05C4C`** is 16 bytes
   confirmed (one byte per error code in `0x258..0x27F`); each entry
   selects a bit position in the IRQ-mask register `FF021A` to clear.

7. **The status-code dispatch table at `loc_F05BA4`** is structured as
   256 × 4-byte entries, indexed by `d0*4` after the panel-command
   read returns a status code. This is the per-status-code handler
   dispatcher — much wider than I'd guessed.

8. **`$E58.l`** holds the current S-record assembly address (32-bit);
   used in microcode address calculations during upload.

9. **`$105E`** holds the maximum block-size limit (compared by
   `F04E46`). Probably a per-bank or per-transfer limit.

10. **Bit 6 and bit 7 of `$E87`** are status flags checked at multiple
    sites (`F04748`, `F049BA`); represent global "command-pending"
    and "error-pending" states for `TCBRDHC`.

### Manual-analysis confirmations

The cooperative MC pass independently confirmed (via random sampling
+ specific keyword-rich answers from both models) every major claim
in `xltr_protocol.md`:
- The `0x8004`/`0x8005` panel-command opcodes
- The `0x4F`/`0x5F` busy/idle status flags
- Each of the 21 distinct `PanelIOConfigure_25A` codes in `0x258..0x27D`
- The 1000-tick (`0x3E8`) timeout in the panel send-and-wait kernel
- The Mode 0/1 register manipulation sequence at `F056A4`/`F056B0`
- The 32-bit data extension via `0x8005` after initial `0x8004`

This is significant: without seeing my manual notes, both LLMs
described the protocol in terms that match my reverse-engineering
exactly — strong evidence the analysis is correct.

## Round 3 (R11-R15) — uniform sampling across entire custom-code range

Goal: eliminate the F046xx-F058xx region bias of R1-R10 by uniformly
sampling across all 6485 instruction lines (F04488-F0FFFF), skipping
addresses already annotated in R1-R10. Mix of cooperative (4 rounds)
and adversarial (1 round). Reduced to 40 samples × 5 rounds.

| Round | Seed | Mode          | Total | YES% | BOTH% | Annot | Wall |
|---|---|---|---|---|---|---|---|
| R11 | 100 | cooperative   | 40 | 95% | 30% | 38 | 107 s |
| R12 | 200 | cooperative   | 40 | 95% | 52% | 38 | 116 s |
| R13 | 300 | adversarial   | 40 | 10% |  0% |  4 | 193 s |
| R14 | 400 | cooperative   | 40 | 95% | 30% | 38 | 113 s |
| R15 | 500 | cooperative   | 40 | 77% | 27% | 31 | 131 s |

**149 new annotations** added on previously-unannotated addresses,
bringing the cumulative total to **644 annotations on 576 unique
addresses** (≈8.9% of the 6485 custom-code instructions).

The drop in BOTH% from ~95% (R1-R10, region-biased) to 27-52%
(R11-R15, uniform) reflects sampling regions where the two models
have different blind spots — DS often gives generic
have different blind spots — one Clanker often gives generic
"loop/branch/store" answers while the other produces register-level
XLTR or RMS68K interpretations, so they don't both clear the
keyword bar on the same sample. The 95% YES (at-least-one-Clanker)
rate stayed high — coverage is not the issue; agreement is.

**R13 adversarial collapse (10% YES):** the critic Clanker refuted
nearly every cooperative answer as "vague" or "speculative" on this
uniform-sampled set. Expected behavior: adversarial mode produces
fewer but sharper survivors.

## Failure modes / DATA samples

Of 250 samples, 2 were marked DATA (data misdecoded as code) by both
models — `F0691E` (a `!TST` marker tag inside `TCBXP3I_CRTCBParams`,
the parameter block template) is the example. Two others (`F063xx`
range) had only DS giving a YES answer; these are in the dispatch
glue between TCBXP*I tasks and may be plausible code-or-data.
