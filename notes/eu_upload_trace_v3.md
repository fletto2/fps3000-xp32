# EU upload path — corrected trace v3 (after exhaustive 0x700000 sweep)

## v2's mistake

v2 promoted Hypothesis 2 (host loads EU via 0x700000 + TCBIO1I +
Dispatcher B) to MEDIUM-HIGH after finding the 0x700000 region and
the second dispatcher. **Exhaustive analysis of all 0x700000 accesses
shows that region is NOT a data buffer — it's an 8-byte handshake
area.** Two longword offsets, three accesses total in the entire SBC
ROM.

## Complete inventory of 0x700000-region accesses

Comprehensive byte-pattern search of the ROM binary for `00 70 00 xx`
plus all forms of the disassembly (immediate, absolute, register-
relative). After eliminating one false positive (the byte sequence
`4CEC 0070 0012` is `MOVEM.L 0x12(a4), d4-d6` — `0070` is a
register list, not a high address word), the result is:

| ROM addr | Instruction | Access |
|---|---|---|
| F05DE0 | `movea.l #$700000, a4` | a4 = base ptr (used in TCBIO1I_ASQHandler only) |
| F05DF0 | `move.l $1c(a4), d1` | **read 0x70001C** (longword) |
| F05E40 | `move.l d1, $20(a4)` | **write 0x700020** (longword) |
| F0A1E6 | `move.l $70001c.l, d1` | **read 0x70001C** (longword) — duplicate via absolute addressing |

**Two distinct offsets accessed: `0x70001C` (read) and `0x700020`
(write). 8 bytes of memory-mapped I/O total.**

This is a handshake/flag region, not a data buffer. Cannot carry EU
microcode (which is 20 KB).

## The actual function of 0x700000+

Reading the access pattern in TCBIO1I_ASQHandler:

```asm
TCBIO1I_ASQHandler:
  movea.l #$ff0000, a5
  movea.l #$700000, a4
  move.w  $210(a5), d7        ; save XLTR_MODE2
  move.w  #$f, $210(a5)       ; set MODE2 = 0xF (probably arms IRQ)

  move.l  $1c(a4), d1         ; ← READ status word from 0x70001C
  btst.b  #$1d, d1            ; test bit 29
  beq.b   skip_281
    move.l #$281, d0
    bset.b #$0, $202(a5)      ; XLTR_MODE1 |= bit 0
    jsr    F05E56              ; send panel cmd 0x281
skip_281:

  move.l  $10aa.l, d2         ; check g__some_flag in SBC RAM
  bne.b   not_zero
    move.l #$282, d0
    [...send 0x282...]
  not_zero:

  cmpi.l  #$2, d2
  bne.b   skip_22
    [bit manipulation: swap d2; isolate bits; if value is 1...]
    bset.b  #$1, d1
    move.l  d1, $20(a4)       ; ← WRITE config back to 0x700020
  skip_22:
```

So the 0x700000 region exposes:
- **`0x70001C`** — a 32-bit status/event word the host writes; SBC
  reads to detect host-initiated events. Bit 29 is one specific
  event signal.
- **`0x700020`** — a 32-bit response/config word the SBC writes; the
  host reads to receive SBC's reply.

The protocol is a low-bandwidth event/request handshake, not a bulk
data path.

## What 0x700000 most likely IS

This 8-byte device is almost certainly part of the **AP I/F card's
mailbox protocol** — a small set of registers that the AP I/F card
makes visible to both the SBC (via VersaBUS at 0x700000+) and the
host (via the I/F cable on the host side). Either side writes a
flag, the other side polls and responds.

This matches typical attached-coprocessor designs of the era —
control plane separate from data plane:
- Control plane: 0x700000+ for events/handshakes
- Data plane: separate (cable, SCM, channel data ports)

## Where this leaves the EU upload question

Three hypotheses, re-ranked AGAIN (this is the third revision):

| # | Hypothesis | v1 | v2 | **v3** |
|---|---|---|---|---|
| H1 | EU bootstraps from EXEC card bipolar PROMs at chassis power-on | MEDIUM-HIGH | MEDIUM | **MEDIUM-HIGH** (back to top) |
| H2 | Host writes EU via 0x700000 → SBC dispatches via TCBIO1I | LOW | MEDIUM-HIGH | **LOW** (region is too small) |
| H3 | EU loads from SCM via per-channel data ports | LOW | LOW | LOW |
| H4 (NEW) | EU loads from SCM via the AU upload mechanism (just at a different staging address that the SBC's range check happens to allow) | — | — | LOW |
| H5 (NEW) | The AP I/F card has a **separate** data channel besides 0x700000 — high-bandwidth, possibly direct-mapped, that bypasses the SBC entirely. Host writes EU code into that channel; SBC just sees handshakes via 0x700000+ | — | — | **MEDIUM** |

H1 is the leading candidate again. H5 is plausible — the AP I/F
card may expose more than one window to the SBC bus, and we just
haven't seen the larger one in this ROM (because the SBC doesn't
need to access that data, only signal it).

## What I want to investigate next

1. **Are there OTHER memory-mapped device ranges in the SBC ROM that
   I haven't catalogued?** Specifically look for:
   - 0x100000-0xEFFFFF (anything outside RAM/ROM/peripherals)
   - 0x600000-0x6FFFFF or 0x800000-0xFEFFFF
   - References to the host-side AP I/F card's address space

2. **Does the FPS-100 archive or any FPS literature describe a
   "mailbox" or "handshake" region** for the FPS-3000-class machines?
   Curington's papers might mention it.

3. **What's at 0x700000+ on the AP I/F card itself?** If we ever
   recover an AP I/F card schematic or PAL equations, that would
   show what registers/buffers the card exposes to the SBC vs the
   host.

## Confidence revision

**HIGH** that the 0x700000 region is exactly 8 bytes of mailbox/
handshake (`0x70001C` + `0x700020`), based on exhaustive disasm
analysis.

**HIGH** that the 0x700000 region is NOT a data buffer for EU
upload (too small).

**MEDIUM-HIGH** that Hypothesis 1 (EU boots from EXEC card bipolar
PROMs) is the leading explanation for how EU contents get there —
fits Hockney's "writable" terminology + the SBC ROM's lack of EU
upload code + chassis-power-on observable behavior.

**MEDIUM** that Hypothesis 5 (AP I/F card has a separate data
window not visible in the SBC ROM) is also possible. Would require
schematic-level evidence of the AP I/F card.

## v2 retraction

v2 said: "EU upload likely happens via the 0x700000 region."

v3 says: "0x700000 is too small for EU upload. EU upload almost
certainly happens via something else — most likely a power-on
boot-ROM-to-WCS copy on the EXEC card itself (Hypothesis 1)."

Net: the SBC ROM probably DOES NOT shuttle EU data. The user's
pushback ("the SBC must shuttle the EU data somehow") was a good
prompt to look harder, and the looking found a previously-missed
mailbox region — but the region turns out to be too small for
the EU's purpose.

The corrected answer to "does the SBC shuttle EU data?" is:
**Probably not.** The mailbox at 0x700000 is for control-plane
handshakes, not bulk data. The EU is most likely loaded from the
EXEC card's own bipolar PROMs at power-on, with no SBC involvement.
The SBC's role is limited to sending dispatch commands once the EU
is already running its supervisor.

This means the EU contents recovery path is unchanged from v1's
recommendation: read the bipolar PROMs on the EXEC card with a
universal PROM programmer.
