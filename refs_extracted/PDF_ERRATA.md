# Bench PDFs — status and history

| PDF | status |
|---|---|
| `versabus_address_map.pdf` | **REBUILT 2026-07-29 — current** |
| `versabus_trace_worksheet.pdf` | **REBUILT 2026-07-29 — current** |

**Both PDFs are now current.** This file is kept as a record of what was
wrong in the 2026-07 editions and why, because the same mistakes are easy
to reintroduce — every one of them came from trusting our own emulator or
from documenting a boot-path sample as if it were the whole behaviour.

Generator scripts are `*.py`, which `.gitignore` excludes, so neither PDF
can be rebuilt from the repo alone; both rebuilds were produced from
scripts kept outside it. That is the same repo rule CLAUDE.md flags for
`disasm.py` and the generated `.asm` files.

The prose in `versabus_access_map.md` is current, and
`selftest_reference.md` is the detailed companion to the worksheet's
Check 0.

## Worksheet rebuilt again, 2026-07-29 (second pass)

The Check 0 beacon table now carries **measured** data rather than inferred
labels, and two new rows that did not exist before:

- **sub-test counts per phase**, so a stuck low byte is interpretable — `$0605`
  means phase 6 died at step 5 of 8
- the complete phase list: **30 phases, `$01`-`$09`, `$10`-`$1A`, `$20`-`$29`**
  (BCD numbering with `$1A` the one exception)
- **`$18`/`$19`/`$1A` identified** as XLTR mode-page, data and status/IRQ
  register tests — they had no labels at all before
- **`$20`-`$23` and `$24`-`$27` identified as two passes of the same RAM test**,
  over `$000400-$01F000` and `$010000-$01F000`. Reaching `$24xx` but hanging in
  `$25xx-$27xx` means good low RAM and bad WCS staging RAM
- a warning that **phase `$29` is 99.4% of the run** (32,768 of 32,967 beacon
  writes) so a beacon parked in `$29xx` is normal, not a hang

**New Check 7c** states the two predictions this session's decoding produced
that a bus trace can falsify outright:

1. `$10AA` must be written by a non-CPU master — the only code that writes that
   array indexes `$10A0` by `(channel-1)*2` and validates against `$105E`,
   which counts nonzero ports among exactly four, so reaching `$10AA` needs
   channel 6 and is barred.
2. A panel command issued from a channel ISR cannot complete — the issuer ends
   in `bra .`, is released only by the BIM0 ch0 responder at **level 6**, and
   every channel ISR runs at **level 7** without ever lowering SR.

Both are cheap to test and each settles an open question either way.

## What the rebuilt worksheet adds

- **Check 0, the phase beacon** — read the machine's own self-test
  progress off `$FF0204` with no debugger, with a beacon-to-suspect table
  covering `$0100`-`$2903`
- **Check 7b, bus mastership** — which card drives `BR*`/`BGACK*`, where
  the DMA address counter lives, and what writes `$10AA`/`$105E` given
  that the firmware never does
- Check 1 now says plainly that the parts survey did **not** find the
  three BIMs, so it is a real question rather than a formality
- Check 8 states the Am29116 count dispute (survey 1, owner 2) as the
  thing to settle before any PROM comes off

---
---|---|
| `versabus_address_map.pdf` | **REBUILT 2026-07-29 — current, use it** |
| `versabus_trace_worksheet.pdf` | **STALE — corrections below override it** |

The address map has been regenerated and now carries the corrected
channel-window roles, the three `$FF0008` modes, the chassis-to-SBC
command table, the S-record offset rule, the bus-mastership finding and
the self-test phase beacon. Everything in the numbered sections below is
already fixed in it; they remain here because they still apply to the
**trace worksheet**, which has not been rebuilt.

Generator scripts are `*.py`, which `.gitignore` excludes, so neither PDF
can be regenerated from the repo alone — the rebuilt address map was
produced from a script kept outside it. That is the same repo rule
CLAUDE.md flags for `disasm.py` and the generated `.asm` files, and it
applies here too.

The prose in `versabus_access_map.md` is current.

---

## 1. The per-channel window labels are wrong (worksheet; fixed in the address map)

Both carry a table reading:

```
  +$04   W   write port
  +$08   R   read A: this read consumes a host byte      <-- WRONG
  +$0A   R   status; host presents $4F                   <-- WRONG
  +$0E   R   read B                                      <-- WRONG
```

Corrected:

| Offset | Actual role |
|---|---|
| +`$04` | write port (unchanged) |
| +`$08` | **32-bit data register, HIGH half** |
| +`$0A` | **32-bit data register, LOW half** |
| +`$0E` | **command / trigger register** (`$8000` fires it) |

`BLK_XFR` (F05B0E) reads `+$08` and `+$0A` every iteration and deposits
them at one address or at consecutive addresses — the signature of a
32-bit value. TCBXP1I writes `$0000001B` across the pair as two halves at
F07EC6, then writes `$8000` to `+$0E`. Eight Am29705 16×4 two-port RAMs
on the AP I/F give exactly a 32-bit-wide register.

## 2. "This read consumes a host byte" is wrong — and self-contradictory

`$FF0048` is **never read anywhere in the ROM**. The address-map PDF says
so itself further down the same page ("`$FF0048` is never read"), so the
document contradicts itself. The only absolute reference to `$FF0048` in
the firmware is at F07E2C, in TCBXP1I, and it is a **write**.

Nothing consumes a host byte by reading. The chassis is a **bus master**
and DMAs into SBC RAM; the SBC is a slave. That is also why `$10AA` and
`$105E` are read but never written by CPU code.

## 3. `$4F` is our own invention, not a hardware value

Both PDFs describe `+$0A` as "status; host presents `$4F`", and the
worksheet asks as an open question "What generates the `$4F` status
value?"

**Do not spend bench time on it.** `$4F` occurs in the ROM exactly five
times, always as `move.w #$4f,(a3)` where `a3` is a **BIM control
register** — the IRE-cleared form of `$5F` that `PanelSendAndWait` writes
to suppress a channel's interrupt during a transfer. It has no connection
to `$FF004A`. The value entered our documentation from
`emulator/host_sim.c`, and the docs then cited the emulator as evidence.

## 4. Board-status bits will never be in a datasheet

Motorola's Table 1 (M68KVM02-3 p. 2-59) gives the board status/control
registers as 28 bits: 12 status inputs and 16 control outputs. **Six of
the twelve status inputs are "User-Defined."** Every bit this project has
reverse-engineered — `$F70019` bits 1-5 — is in that user-defined set,
i.e. FPS's own wiring. Any worksheet step that suggests looking them up
is a dead end; they can only be inferred from firmware behaviour or
traced on the board.

## 5. Things the PDFs get right and are worth keeping

- the `$FF0000-$FF00FF` / `$FF0200-$FF025F` / `$70001C` window split
- the BIM control-register bit decode (0-2 level, 4 IRE, 5 IRAC, 7 Flag)
  and the channel-to-vector table
- the A4/A5/A6 decode note about separating BIM1 from the XLTR file
- the "look for three 40-pin DIPs" MC68153 step — still open, and the
  parts survey did **not** find them, so it is a genuine bench question

## What a rebuild should add

- the phase beacon: every self-test writes `phase<<8 | subtest` to
  `$FF0204`, so scoping that register during reset identifies the failing
  test with no debugger (`selftest_reference.md` has the lookup table)
- `$FF0008` as the bulk data port, bidirectional, with three modes
- S-record addresses are **offsets**: the firmware computes
  `$10 + addr + $10000`
