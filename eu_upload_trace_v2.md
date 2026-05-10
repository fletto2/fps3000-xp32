# EU upload path — corrected trace (v2)

> **SUPERSEDED by `eu_upload_trace_v3.md`** — v2 promoted H2 to leading
> hypothesis based on finding the 0x700000 region. v3 confirms via
> exhaustive sweep that 0x700000 is just an 8-byte mailbox (not a
> data buffer), so H2 is downgraded back to LOW. H1 (EU boots from
> EXEC PROMs) returns as the leading hypothesis.


**v1 finding was incomplete.** Previous trace concluded "EU upload
is NOT in the SBC ROM" based on examining `SRecordDataHandler` /
`SRecordFinalize` / `MainInit` / `HardwareInit` / `Phase2Init` /
the 21 panel codes via `PanelIOConfigure_25A`.

The user pushed back: "the SBC must be able to shuttle EU data
somehow." That pushback was correct. There's a **second dispatch
path** I missed entirely.

## Second panel-command dispatcher

There are TWO panel-command-sender routines in the SBC ROM, not one:

### Dispatcher A — `PanelIOConfigure_25A` at F05688 (the one v1 traced)

Used by TCBRDHC for the AU upload path. Sends via `0xFF0000`
opcodes (`0x8004` REQUEST-XFER / `0x8005` CONTINUE-XFER) and polls
status at `0xFF0218`. Handles panel codes `0x258..0x27D` (the
"21 codes" we documented).

### Dispatcher B — `loc_F05E56` at F05E56 (v1 missed)

Used by TCBIO1I (the host I/O channel task). Different protocol:

```asm
loc_F05E56:
  f05e56:  move.w  d0, $e6e.l        ; save command in g__last_panel_arg
  f05e5c:  movea.l #$ff0000, a0
  f05e62:  move.w  d0, $e(a0)        ; → XLTR_CMD_ARG (0xFF000E)
  f05e66:  move.w  $202(a0), d1      ; read XLTR_MODE1
  f05e6a:  bclr.b  #$e, d1           ; clear bit 14
  f05e6e:  bset.b  #$c, d1           ; set bit 12 (enable)
  f05e72:  move.w  d1, $202(a0)      ; → XLTR_MODE1
  f05e76:  move.w  $200(a0), d1      ; read XLTR_MODE0
  f05e7a:  bclr.b  #$a, d1           ; clear bit 10
  f05e7e:  move.w  d1, $200(a0)      ; → XLTR_MODE0
  f05e82:  move.w  d0, $204(a0)      ; → XLTR_CHANNEL_SELECT
```

This routes the command via `XLTR_CMD_ARG` (`0xFF000E`) +
`XLTR_CHANNEL_SELECT` (`0xFF0204`) — completely different from
Dispatcher A's `0xFF0000` opcode protocol.

## The 0x700000 memory region (also missed in v1)

`TCBIO1I_ASQHandler` accesses a previously-undocumented memory
range:

```asm
TCBIO1I_ASQHandler:
  f05dda:  movea.l #$ff0000, a5     ; XLTR base
  f05de0:  movea.l #$700000, a4     ; ← NEW: 0x700000 base
  f05de6:  move.w  $210(a5), d7     ; save XLTR_MODE2
  f05dea:  move.w  #$f, $210(a5)    ; set MODE2 = 0xF
  f05df0:  move.l  $1c(a4), d1      ; read 0x70001C — host status
  f05df4:  btst.b  #$1d, d1         ; test bit 29
  f05df8:  beq.b   loc_F05E12       ; if clear, skip
  f05dfa:  move.l  #$281, d0        ; otherwise send panel cmd 0x281
  f05e0c:  jsr     loc_F05E56.l     ; via Dispatcher B
loc_F05E12:
  f05e12:  move.l  $10aa.l, d2      ; check SBC RAM flag
  f05e18:  bne.b   loc_F05E22       ; if nonzero, continue
  f05e1a:  move.l  #$282, d0        ; otherwise send 0x282
  f05e20:  bra.b   loc_F05E00       ; (also via F05E56)
loc_F05E22:
  f05e22:  cmpi.l  #$2, d2
  f05e28:  bne.w   loc_F05E44
  f05e2c:  move.l  d1, d2
  f05e2e:  swap    d2
  f05e30:  andi.l  #$3, d2
  f05e36:  cmpi.b  #$1, d2
  f05e3a:  bne.b   loc_F05E44
  f05e3c:  bset.b  #$1, d1
  f05e40:  move.l  d1, $20(a4)      ; write to 0x700020
```

So the SBC reads from `0x70001C`, modifies bits, and writes to
`0x700020`. This is a **shared memory window** between the host
(via the AP I/F card) and the SBC. Most likely the AP I/F card
provides a memory-mapped DMA region that both the host and SBC
can access; the host writes data + sets flag bits, SBC monitors
and dispatches.

## Updated panel-command alphabet

Counted from full disasm sweep, not just `PanelIOConfigure_25A`
calls:

| Range | Codes seen | Source |
|---|---|---|
| 0x258-0x27D | 21 codes (the documented set) | TCBRDHC, panel commands sent via Dispatcher A |
| **0x27E-0x282** | **5 codes** (NEW) | TCBIO1I, sent via Dispatcher B |
| **0x29E-0x29F** | **2 codes** (NEW) | RTOSKernelInit / TCBDefinitionTable context |

Total: at least **28 distinct panel codes** — not 21 as previously
documented. This is a significant revision to the panel-command
inventory.

## What the v1 trace got wrong

The v1 trace asked "where does EU microcode get uploaded?" and
looked for paths analogous to the AU's S-record-driven mechanism.
That assumed the EU upload path would look like the AU one (S-records,
staging buffer, panel command at the end).

The reality (very plausibly) is that **EU upload uses an entirely
different mechanism**:
- Host writes EU code into the `0x700000` shared memory window
  (mapped by the AP I/F card)
- Host sets a flag bit at `0x70001C`
- SBC's TCBIO1I task notices the flag, sends Dispatcher-B panel
  command (one of `0x27E..0x282`)
- AP-side EU runtime reads from a designated location and loads
  WCS

This **fits the SBC ROM evidence** (TCBIO1I exists, `0x700000`
region is monitored, Dispatcher-B exists), Hockney's text (EU is
writable), and the absence of obvious EU-upload code in the
TCBRDHC path.

It also matches the FPS-100 model where `EXPUT`/`EXGET` (TCBIO1I's
documented function per CLAUDE.md) is the data-transfer path
between host and AP — distinct from program-loading on the
AP-120B side.

## Hypothesis update

The three hypotheses from v1, re-ranked:

| # | Hypothesis | v1 confidence | v2 confidence |
|---|---|---|---|
| H1 | EU bootstraps from bipolar PROMs at power-on | MEDIUM-HIGH | MEDIUM |
| **H2** | **Host loads EU via shared memory window (0x700000), SBC notifies AP via TCBIO1I + Dispatcher B** | LOW | **MEDIUM-HIGH** |
| H3 | EU loads from SCM | LOW | LOW |

**H2 is now the strongest candidate.** Direct evidence:
- The 0x700000 memory region exists and is monitored by SBC
- TCBIO1I implements EXPUT/EXGET (general data movement)
- Dispatcher-B sends commands `0x281`/`0x282` etc. that look like
  data-transfer-control opcodes
- Hockney's "EU is writable" fits with host upload via DMA-window

H1 (boot ROM) is still possible — could be **complementary** to H2
(boot ROM gets EU minimally functional, then host does runtime
re-loads via H2 path).

## What still needs investigation

- **What's mapped at 0x700000+?** Is it the AP I/F card's host-
  visible memory window? Is it shared between SBC and host? What
  size? Need to look at all accesses to 0x700000-0x7FFFFF and
  also any board-status registers that select between memory
  windows.
- **What do panel codes 0x27E..0x282 mean?** Like the 21 codes,
  these decode somewhere on the AP side; need either an EU dump
  or a bus trace to identify per-code semantics.
- **Are 0x29E/0x29F also sent through Dispatcher B**, or via a
  third path? Their context (`RTOSKernelInit` / `TCBDefinitionTable`)
  is at boot; could be early-init commands.
- **Is the 0x700000 window read-only from SBC side?** TCBIO1I
  reads `$1c(a4)` and writes `$20(a4)`. So at least these two
  offsets are read/write from SBC.

## Net retraction of v1 conclusion

**v1 said**: "The EU upload path is NOT in the SBC ROM."

**v2 says**: The EU upload path is **likely in TCBIO1I + the
`0x700000` shared memory region + Dispatcher B (loc_F05E56)**.
The SBC ROM does shuttle EU data, just not via the S-record/
TCBRDHC path that handles AU.

The user's pushback was correct.

## Confidence

**HIGH** that the second dispatch path (loc_F05E56 + 0x700000
region) exists and is used by TCBIO1I — primary-source disasm
evidence is unambiguous.

**MEDIUM-HIGH** that this is the EU upload path — fits all
evidence but not yet confirmed (would need bus trace or detailed
analysis of what host writes to 0x700000+ during EU bring-up).

**HIGH** that the panel-code inventory is at least 28 codes, not
21 — direct count from disasm.

## Action items added by v2

- Update `panel_codes_am29116_decoded.md` with codes 0x27E-0x282,
  0x29E-0x29F + their dispatcher paths
- Update memory map in CLAUDE.md / cliffsnotes/03-firmware.md to
  include the 0x700000 region
- Investigate all 0x700000-0x7FFFFF accesses (more might be lurking)
- Investigate F05E56 dispatcher's full panel-command alphabet
  (we've seen 0x281, 0x282, 0x27D, 0x27E, 0x27F, 0x280 — the
  whole 0x27D-0x282 range goes through it)
- Update `VERIFIED_CLAIMS.md` Tier 4 with the v1 retraction
