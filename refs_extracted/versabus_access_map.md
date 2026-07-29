# VersaBus access map: what the SBC firmware reads and writes

Every off-board access the FPS-3000 SBC firmware makes, with address,
direction, width, values and the code that performs it.

Three sources, cross-checked against each other:

1. **Static.** Every memory-reference instruction in `fps3k_clean.asm`
   whose operand resolves into VersaBus space, tagged with its PC and
   enclosing function. Covers code that never runs.
2. **Dynamic.** The emulator's bus logger (`-bus`) over a full boot to
   the RMS68K idle loop plus a host S-record transfer. Records what
   executes, with observed values.
3. **RAM dump.** `-dump-ram` after boot, used to resolve interrupt
   vector numbers to their installed handlers.

Where the static and dynamic views disagree, the disagreement is
recorded. It marks code the boot never reaches.

---

## Summary

The SBC drives three off-board windows. Every data access to them is a
16-bit word. No byte-wide or long-wide data access appears anywhere in
`$FF0000-$FF025F`. The one non-word off-board access in the firmware is
a 32-bit read of the mailbox at `$70001C`.

| Window | Range | What it is |
|---|---|---|
| AP I/F | `$FF0000-$FF00FF` | host interface: command register + four 32-byte channel windows |
| XLTR control | `$FF0200-$FF021B` | mode/select/data/status/IRQ-mask register file |
| XLTR interrupt | `$FF0230-$FF025F` | three MC68153-style BIMs, described below |
| Mailbox | `$70001C` | 32-bit read, host-attention flag |

On-board peripherals (`$F70001-$F7001A` PTM, SIO and board status, and
`$01FFF0` VMOD control) sit outside VersaBus space and are excluded
here. See `M68KVM02_memory_map.md`.

---

## 1. Three BIMs at `$FF0230-$FF025F`

The card list names this card "V-BUS XLTR 3 BIMS" (612-4803-400-G). The
block at `$FF0230` holds three Bus Interface Modules, each with four
interrupt channels:

```
   CR0 = base+$0   CR1 = base+$2   CR2 = base+$4   CR3 = base+$6
   VR0 = base+$8   VR1 = base+$A   VR2 = base+$C   VR3 = base+$E
```

BIM0 sits at `$FF0230`, BIM1 at `$FF0240`, BIM2 at `$FF0250`. Control
register `n` pairs with vector register `n` eight bytes higher.

`RTOSKernelInit` (F0A164-F0A1CA) zeroes six of the twelve control
registers (`$FF0232`, `$234`, `$236`, `$242`, `$254`, `$256`), then loads
ten vector registers with the interrupt vector numbers `$41` through
`$4A`. It never touches `$FF0240` or `$FF0248`. Each task later enables
its own channel by writing `$5F` to its control register, with BIM0 ch0
the exception at `$5E`.
Resolving each vector number against the post-boot vector table gives:

| BIM | ch | CR | value | VR | vec | vector addr | installed handler | owner |
|---|---|---|---|---|---|---|---|---|
| 0 | 0 | `$FF0230` | `$5E` | `$FF0238` | `$41` | `$104` | `F04930` | — |
| 0 | 1 | `$FF0232` | `$00` | `$FF023A` | `$42` | `$108` | `F00896` generic | disabled |
| 0 | 2 | `$FF0234` | `$00` | `$FF023C` | `$43` | `$10C` | `F00896` generic | disabled |
| 0 | 3 | `$FF0236` | `$00` | `$FF023E` | `$44` | `$110` | `F00896` generic | disabled |
| 1 | 0 | `$FF0240` | never written | `$FF0248` | — | — | — | unused |
| 1 | 1 | `$FF0242` | `$00` | `$FF024A` | `$49` | `$124` | `F0A27A` panic | disabled |
| 1 | 2 | `$FF0244` | `$5F` | `$FF024C` | `$45` | `$114` | `F07EE6` | **TCBXP1I** |
| 1 | 3 | `$FF0246` | `$5F` | `$FF024E` | `$46` | `$118` | `F074E6` | **TCBXP2I/3I** |
| 2 | 0 | `$FF0250` | `$5F` | `$FF0258` | `$47` | `$11C` | `F06AE6` | **TCBXP3I/2I** |
| 2 | 1 | `$FF0252` | `$5F` | `$FF025A` | `$48` | `$120` | `F060CE` | **TCBXP4I** |
| 2 | 2 | `$FF0254` | `$5F` | `$FF025C` | `$4A` | `$128` | `F05DD6` | **TCBIO1I** |
| 2 | 3 | `$FF0256` | `$00` | `$FF025E` | — | — | — | disabled |

Every channel with an enabled control register has a distinct handler.
Every channel that holds `$00` and has a vector loaded points at the
generic handler or the panic catch-all. The two channels with no vector
loaded (BIM1 ch0 and BIM2 ch3) sit outside that pattern. The
correspondence across the ten loaded registers is the evidence for the
identification.

Each task programs its own control register and owns the ISR named by
the vector register eight bytes above it. `TCBIO1I` writes `$5F` to
`$FF0254` at F05DB8, and its ISR sits on vector `$4A` from `$FF025C`.

### What follows from this

`$FF025C` supplies the host-link interrupt vector. `$4A` is 74, and
74 x 4 is `$128`, which holds `F05DD6`, the TCBIO1I ISR. `host_sim`
gates on that same vector, reached from a different direction.

The BIM supplies the vector during the IACK cycle, so the host
interrupt is vectored. Documents describing it as "level 5 autovectored
through vector `$128`" record the effect and miss the mechanism.

The registers earlier docs call `XLTR_CH{1..4}_CONFIG` are BIM control
registers, and `$5F` is a control value. A fifth control register at
`$FF0254` belongs to TCBIO1I and appears in no earlier doc.

Two channels are wired but unused (`$FF0240`/`$FF0248` and
`$FF0256`/`$FF025E`). BIM0 has one enabled channel whose vector `$41`
reaches `F04930`, a handler we have not identified.

### Confirmation from the MC68153 datasheet

`refs/MC68153L.pdf` carries no text layer, so I read it by rendering
the pages. Three passages close the identification:

- "The MC68153 can be used with many system buses, however, it is
  primarily intended for VMEbus, VERSAbus and MC68000 applications."
- "All eight BIM registers can be accessed from the system bus ... the
  internal registers are selected by A1, A2, and A3." Eight registers
  on A1-A3 gives 2-byte spacing, matching the layout above.
- "Each input is regulated by Bit 4 (IRE) ... (CR0 controls INT0, CR1
  controls INT1, etc.) The asserted IRQX output is selected by the
  value programmed in Bits 0, 1, and 2 of the control register (L0, L1,
  and L2). This 3-bit field determines the interrupt request level ...
  If the interrupt request level is set to zero, the interrupt is
  disabled because there is no corresponding IRQ output."

That decodes the observed values:

| CR value | bits 2-0 (level) | bit 4 (IRE) | meaning |
|---|---|---|---|
| `$5F` | `111` = 7 | 1 | enabled, requests IRQ level 7 |
| `$5E` | `110` = 6 | 1 | enabled, requests IRQ level 6 |
| `$00` | `000` = 0 | 0 | disabled, no IRQ output exists at level 0 |

Level zero meaning disabled explains the pattern above: a channel left
at `$00` cannot raise an interrupt at all, so whatever its vector
register points at never runs.

### The interrupt level, and an emulator bug

The host link (TCBIO1I, `CR = $FF0254 = $5F`) requests IRQ level 7.
All five task channels hold `$5F`, so they share level 7 and separate
by vector, the case the datasheet covers: "Two or more interrupt
sources can be programmed to the same request level", resolved by the
IACKIN*/IACKOUT* daisy chain. BIM0 ch0 sits alone at level 6.

Our emulator raised level 5 and returned a hard-coded `0x4A` from
`m68k_irq_callback`. Both values were wrong. The emulator now reads the
level from the channel's control register and the vector from its
vector register during IACK, following the datasheet's Figure 6, where
the interrupter "places vector byte on data bus" and the handler "reads
vector".

The post-boot autovector table shows the same thing from another angle:

| autovector | address | handler |
|---|---|---|
| L1, L2, L3 | `$064`-`$06C` | `F00896` generic |
| **L4** | `$070` | `F00EC8`, the one real autovector handler (PTM tick) |
| **L5** | `$074` | `F00896` generic |
| L6 | `$078` | `F00896` generic |
| L7 | `$07C` | `00000000`, never installed |

An autovectored level-5 host interrupt would land on `F00896`. The only
route to `F05DD6` runs through vector `$4A`, which the BIM supplies.
Level 7 never uses its autovector, which is why `$07C` stays zero. An
autovectored level-7 interrupt would fetch vector 31 from `$07C` and jump
to address zero. That is separate from the 68000 spurious-interrupt
vector (24, at `$060`), which applies when BERR is asserted during IACK.

### Reset state

The datasheet gives the power-on state: "The control registers are reset
to all zeroes and the Vector Registers are set to a value of `$0F`. This
vector value is the uninitialized vector for the MC68000." A BIM the
firmware never programs therefore answers IACK with `$0F`, vector 15,
which the 68000 reserves as uninitialised.

Known control-register bits: 0-2 are the level, 4 is IRE, and 7 is the
Flag ("Flag (F) is located in bit position 7"). The datasheet names IRAC
(interrupt auto-clear), FAC (flag auto-clear) and X/IN (internal versus
external response) without giving their positions in the pages read so
far, so bits 3, 5 and 6 of the `$5F` the firmware writes stay unnamed.

### Remaining caveat

The register layout rests on the firmware's own writes and on the
CR-to-VR pairing holding across five enabled channels. Naming the part
an MC68153 rests on the card description and on the datasheet fit. Read
"MC68153-style" as "a four-channel BIM with this layout" until someone
reads the part numbers off the board. `versabus_trace_worksheet.pdf`
covers that check.

---

## 2. AP I/F at `$FF0000-$FF00FF`

Four channel windows on a 32-byte stride, base `$FF0040 + $20·N`:

| Offset | Dir | ch1 | ch2 | ch3 | ch4 | Notes |
|---|---|---|---|---|---|---|
| +`$04` | **W** | `$FF0044` | `$FF0064` | `$FF0084` | `$FF00A4` | write port |
| +`$08` | **R** | `$FF0048` | `$FF0068` | `$FF0088` | `$FF00A8` | read port A, the byte-consume read |
| +`$0A` | **R** | `$FF004A` | `$FF006A` | `$FF008A` | `$FF00AA` | status, where the host presents `$4F` |
| +`$0E` | **R** | `$FF004E` | `$FF006E` | `$FF008E` | `$FF00AE` | read port B |

`$FF000E` holds the command and argument register. The firmware writes
it from eight sites and never reads it. It carries the only AP I/F
write a boot performs, value `$281` (`PCMD_HOST_REQUEST`).

A full boot reads the `+$0E` port of each channel twice, inside
`RTOSKernelInit`, and touches nothing else in this window. The `+$08`
and `+$0A` ports appear only in `TCBXP*I` code that a plain boot never
reaches. The SBC never reads `$FF0048`, so a queued host byte is never
consumed, which is the stall CLAUDE.md describes.

`build_clean_disasm.py` labels `$FF0048` and its siblings
`XLTR_CH1_DATA_A`. Those registers belong to the AP I/F. The XLTR
starts at `$FF0200`. The label survives from an early guess.

---

## 3. XLTR control file at `$FF0200-$FF021B`

Word accesses throughout. Static counts are read and write instruction
sites; the observed column reports one boot.

| Addr | Name | R | W | Observed | Values seen |
|---|---|---|---|---|---|
| `$FF0200` | MODE0 | 20 | 20 | R1/W1 | `0` |
| `$FF0202` | MODE1 | 37 | 32 | R2/W6 | `8020 8000 8021 9021` |
| `$FF0204` | CHANNEL_SELECT | 26 | 80 | R0/W1 | `281` |
| `$FF020C` | COUNTER | 1 | 9 | — | never executed |
| `$FF0210` | MODE2 | 3 | 15 | R1/W5 | `F 0` |
| `$FF0214` | DATA_LO | 0 | 1 | — | never executed |
| `$FF0216` | DATA_HI | 3 | 20 | R0/W2 | `C0` |
| `$FF0218` | STATUS_IRQ | 22 | 44 | — | never executed |
| `$FF021A` | IRQ_MASK | 51 | 51 | — | never executed |

`CHANNEL_SELECT` takes more writes than any other register in the map,
from 80 sites, and the firmware reads it from 26 more. Every panel
operation sets it first.

---

## 4. Mailbox `$70001C`

The one 32-bit off-board access in the firmware. Read-only, from two
sites (`RTOSKernelInit` and `TCBIO1I_ASQHandler`), observed three
times. Bit 29 carries the host-attention flag; observed values are
`00000000` and `20000000`.

---

## 5. Chassis memory `$400000`, `$403FFC`, `$404000`

Only `lea` and `movea` reference these, inside the self-test region.
They compute addresses rather than transfer data, and a plain boot
never reaches them. Listed for completeness. Treat the window as
unconfirmed.

---

## Code a plain boot never executes

`XLTR_COUNTER`, `XLTR_DATA_LO`, `XLTR_STATUS_IRQ`, `XLTR_IRQ_MASK` and
every channel `+$04`, `+$08` and `+$0A` port carry real code with no
coverage. They make up the panel-command path
(`PanelSendAndWait_andDispatch`) and the per-channel data paths, the
parts that wait for the chassis to answer. Emulator work aimed at
completing the host handshake should target this set, since it is the
code the current chassis model never provokes.

---

## Corrections this analysis implies

1. `XLTR_CH{1..4}_CONFIG` are BIM control registers, and a fifth exists
   at `$FF0254` for TCBIO1I. The "config init value `$5F`" is a BIM
   control value carrying level 7 and IRE.
2. The host-link interrupt arrives vectored through the BIM at level 7.
   Earlier docs record level 5, autovectored.
3. The `$FF0048` family carry an `XLTR_` prefix and belong to the AP I/F.
4. Each AP I/F channel window holds one write port and three read ports
   on a `$20` stride. Earlier docs list only "Data A" and "Data B".
5. All VersaBus data traffic runs 16 bits wide. Any model that issues
   byte or long accesses to `$FF____` models something the firmware
   never does.
