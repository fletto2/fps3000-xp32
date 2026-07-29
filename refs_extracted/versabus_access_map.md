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
| 0 | 0 | `$FF0230` | `$5E` | `$FF0238` | `$41` | `$104` | `F04930` | **TCBRDHC** |
| 0 | 1 | `$FF0232` | `$00` | `$FF023A` | `$42` | `$108` | `F00896` generic | disabled |
| 0 | 2 | `$FF0234` | `$00` | `$FF023C` | `$43` | `$10C` | `F00896` generic | disabled |
| 0 | 3 | `$FF0236` | `$00` | `$FF023E` | `$44` | `$110` | `F00896` generic | disabled |
| 1 | 0 | `$FF0240` | never written | `$FF0248` | — | — | — | unused |
| 1 | 1 | `$FF0242` | `$00` | `$FF024A` | `$49` | `$124` | `F0A27A` panic | disabled |
| 1 | 2 | `$FF0244` | `$5F` | `$FF024C` | `$45` | `$114` | `F07EE6` | **TCBXP1I** |
| 1 | 3 | `$FF0246` | `$5F` | `$FF024E` | `$46` | `$118` | `F074E6` | **TCBXP2I** |
| 2 | 0 | `$FF0250` | `$5F` | `$FF0258` | `$47` | `$11C` | `F06AE6` | **TCBXP3I** |
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
`$FF0256`/`$FF025E`).

### Reading the channel owners off the handlers

Every vector target starts with a register-save prologue, so all six are
interrupt handlers. The four XP handlers open with the identical
instruction (`move.l a5,-(a7)`), marking them as four instances of one
code pattern.

Locating each handler inside the disassembly's function map identifies
the owners, including two the earlier version of this document left
ambiguous:

| task instance | CR write | CR addr | vec | ISR | ISR - CR | gap to previous |
|---|---|---|---|---|---|---|
| TCBXP1I | `F07E12` | `$FF0244` | `$45` | `F07EE6` | +`$D4` | — |
| TCBXP2I | `F07412` | `$FF0246` | `$46` | `F074E6` | +`$D4` | `$A00` |
| TCBXP3I | `F06A12` | `$FF0250` | `$47` | `F06AE6` | +`$D4` | `$A00` |
| TCBXP4I | `F06018` | `$FF0252` | `$48` | `F060CE` | +`$B6` | `$9FA` |

Four instances of one task body, `$A00` apart, three of them with the ISR
at a fixed `+$D4` from the control-register write. As the task address
descends, both the control-register address and the vector number ascend.
TCBXP1I (highest) and TCBXP4I (lowest) are already labelled in the
disassembly, so the two instances between them are channels 2 and 3 in
that order. Three orderings agree and the endpoints are pinned.

Vector `$41` lands at `F04930`, inside **TCBRDHC**, the master dispatch
task that drives the panel command interface and the SLC microcode
receiver. Its prologue saves every register (`movem.l d0-d7/a0-a7`),
heavier than the XP handlers. So BIM0 ch0 serves TCBRDHC at level 6,
while the four XP data channels and the host link run at level 7. Data
movement outranks the dispatcher.

Vector `$49` (BIM1 ch1) points at the panic catch-all and its channel is
disabled, which marks it as a spare. `RTOSKernelInit` writes it after
`$47` and `$48`, so the firmware assigns vector numbers by purpose rather
than by register address.

### What the vectors do not settle

The handler addresses fix which task owns which channel. They say nothing
about the IACKIN/IACKOUT daisy chain, which decides who wins when two
channels request the same level in the same cycle. Five channels share
level 7 across BIM1 (two) and BIM2 (three), so the question is live.

The firmware numbers vectors in task order, `$45` through `$48` for XP
channels 1 to 4, crossing from BIM1 to BIM2 between `$46` and `$47`. A
designer who wired the chain to match that order would put BIM1 ahead of
BIM2. That is a reading of intent, not evidence, and the emulator's
scan order stays a placeholder until someone buzzes pins 6 and 7.

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
external response) without giving their positions in the pages rendered
so far.

Motorola's own VERSAdos drivers fill part of that gap. `MPCCDRV.SA` and
`P050DRV.SA` (`~/src/claude/versados/SR07/U9993/`) drive a BIM on
another board and confirm the layout from a second, independent source:

```
BIM_CTL0 EQU $FF10C1     BIM_CTL1 EQU $FF10C3     BIM_CTL3 EQU $FF10C7
BIM_VEC3 EQU $FF10CF     IRE      EQU 4           BIM_SET  EQU $3B
```

Control registers two bytes apart on odd addresses, `BIM_CTL3` and
`BIM_VEC3` exactly eight bytes apart, and `IRE EQU 4` labelled "Interrupt
request enable bit". That is the layout this document derives from the
FPS firmware, arrived at on different hardware by the vendor.

`BIM_SET = $3B` also locates IRAC. Motorola writes `$3B` when programming
the BIM and writes it **again inside the interrupt handler**, under the
comment "Clear the interrupt at the BIM #1". That re-arm is what IRAC=1
requires: the chip clears IRE during IACK, so software must set it again
before the source can interrupt a second time. Comparing the two
firmwares:

| | value | level | bit 3 | IRE (4) | bit 5 | bit 6 | F (7) |
|---|---|---|---|---|---|---|---|
| Motorola `BIM_SET` | `$3B` | 3 | 1 | 1 | **1** | 0 | 0 |
| FPS-3000 | `$5F` | 7 | 1 | 1 | **0** | 1 | 0 |

Bits 5 and 6 are the only ones that differ in role. Motorola sets bit 5
and re-arms every interrupt; the FPS firmware clears bit 5 and writes
`$FF0254` once, at task start, never again. That points at **bit 5 =
IRAC**, with bit 6 the remaining candidate for FAC.

The practical consequence: the FPS-3000 runs its BIM channels with
auto-clear off, so a channel stays armed after acknowledgement and the
emulator is right not to clear IRE on IACK.

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

## The panel-status handshake — fires, but does not complete

The mechanism CLAUDE.md long recorded as "one good IRQ-handler
implementation away from end-to-end S-record loading" is identified and
the handler now runs in the emulator. It does **not** complete a host
transfer, and an earlier version of this section claiming otherwise was
wrong — see "What the response does not do" below.

Sequence, all read off the disassembly:

| Step | Actor | Action |
|---|---|---|
| 1 | SBC | clear `MODE0` bit 10 (`bclr #$a,d1` at F05E7A) |
| 2 | SBC | write the command code to `CHANNEL_SELECT` |
| 3 | SBC | park in `bra .` |
| 4 | chassis | 5-bit code into `MODE0` bits 0-4, set bit 11, assert a BIM channel |
| 5 | handler | read code, clear bit 11, set bit 10, dispatch, rewrite the saved PC |

There are **two tiers of spin**, which is why two interrupt levels exist:

| Spin | Enclosing | Context | Woken by |
|---|---|---|---|
| `F04530` | task__init_misc | task, IPL 0 | BIM0 ch0, level 6 |
| `F056B8` | PanelIOConfigure_25A | task, IPL 0 | BIM0 ch0, level 6 |
| `F05E86` | TCBIO1I | **ISR, IPL 7** | that channel, level 7 |
| `F068D8` | TCBXP4I | **ISR, IPL 7** | that channel, level 7 |
| `F072F0`, `F07CF0` | TCBXP2I/3I | **ISR, IPL 7** | that channel, level 7 |
| `F086F0` | TCBXP1I | **ISR, IPL 7** | that channel, level 7 |

The five ISR spins sit on the same `$A00` stride as the task bodies, one
per channel. A trace confirms the ISR never returns before parking:
`F05E4C` (ISRExit) and `F05E50` (the `trap #1` return-from-interrupt)
execute zero times, and a sweep of the whole ROM finds only seven writes
to `SR`, all of them in MainInit/HardwareInit/RTOSKernelInit. No task or
handler ever changes the interrupt mask. So an ISR-context spin sits at
IPL 7 and only a fresh level-7 edge reaches it, which is exactly what
makes level 7 (edge-triggered on a 68000) the right choice for the
per-channel channels and level 6 sufficient for the task-context ones.

Modelling this needed one further fix: the BIM must **release the IRQ
line during IACK**, as the datasheet's Figure 10 shows. Without that the
level never drops, no new edge forms, and a later response on the same
channel is swallowed.

### The response must outrank the waiting handler

The handler at `F04930` runs only when the response arrives at a level
**above** the IPL mask of the code that is spinning. That is a hard
68000 rule (a level-*n* request is blocked at mask *n*; only level 7 is
exempt, and then only on an edge), and it decides the whole mechanism:

| Host-link ISR level | `F04930` executions | Spin iterations | Outcome |
|---|---|---|---|
| 7 (as the firmware sets it, `CR=$5F`) | **0** | 76,314 | spins forever |
| 5 | 1 | 1 | escapes, advances one command |
| 2 | 1 | 1 | escapes, advances one command |

The firmware writes `CR=$5E` (level 6) to BIM0 ch0 and `CR=$5F`
(level 7) to the channel BIMs, so on the real board a BIM0 ch0 response
can *never* preempt a channel ISR. The level-5 row above is an
experiment (`FPS3K_HOSTLVL`), not hardware truth. Either the per-channel
spins are answered on their own level-7 channel by a fresh edge, or the
board's IRQ-pin wiring differs from the CR level — Check 2 in the trace
worksheet. This is the open question, and it is now a specific one.

### Two dispatchers, selected by bit 7

`F04930` reads `MODE0`, clears bit 11, stores the word to `$E86`, sets
bit 10 and writes it back. It then does `btst #7, $E87` — **bit 7 of the
response byte picks which dispatcher runs**:

| Bit 7 | Path | Index | Table |
|---|---|---|---|
| 0 | `F04A6E` | `(code & $F) << 2` | 16 entries at **`F05102`** |
| 1 | `F0495C` | `code & $1F`, range-checked 0..`$14` | the `F05BA4` family |

The `F05102` table is new here and was not in any earlier note. All 16
slots are `4EFA xxxx` (`jmp d16(pc)`), targets:

| Code | Target | Code | Target | Code | Target | Code | Target |
|---|---|---|---|---|---|---|---|
| `$0` | F04A84 | `$4` | F04E3A | `$8` | F04F52 | `$C` | F0502C |
| `$1` | F04CF2 | `$5` | F04EE4 | `$9` | F04FA0 | `$D` | F05092 |
| `$2` | F04D20 | `$6` | F04F30 | `$A` | F04FBA | `$E` | F050CA |
| `$3` | F04D4E | `$7` | F04F3A | `$B` | F05002 | `$F` | F050F8 |

Two entries are confirmed by execution trace, not just by decoding the
displacement: code `$00` runs `F05102 → F04A84`, code `$0B` runs
`F0512E → F05002`. Because only the low nibble indexes this table,
`$04`/`$14` alias and `$00`/`$10` alias — which is exactly the aliasing
seen in the sweep below, and is the reason that sweep's results split the
way they do.

### The host payload rides in the mailbox, not the data ports

Following the negative result above — `$FF0048` never read — to its
conclusion changes the host-link model.

`$FF0048` has exactly one absolute reference in the ROM, at F07E2C, and
it is inside **TCBXP1I**, which *writes* the port group: `$FF0048 <- 0`,
`$FF004A <- $1B`, `$FF004E <- $8000`. The channel-1 data ports are that
task's output, not the host's inbox.

TCBIO1I instead works the mailbox pair. It reads `$70001C`, and at F05E2C
takes that same word, `swap`s it and masks `#3` — **bits 16-17 are a
class field** which must read `1`. The gate is `$10AA`, read at F05E12,
with `d2 == 2` selecting the reply path. Drive both and the path runs:

| `$10AA` | mailbox bits 16-17 | F05E40 (reply write) | `$700020` |
|---|---|---|---|
| 2 | 1 | 46,511 | **`$00010002`** |
| 2 | 0 | 0 | — |
| 2 | 2 | 0 | — |

`$00010002` is the mailbox word with bit 1 set, which is exactly what
`bset #1,d1` at F05E3C produces. This is also the first configuration in
which the ISR *returns*: `F05E4C` (ISRExit) and the `trap #1` at F05E50
had executed zero times in every earlier run.

`$10AA` is not written by any path this emulator reaches. A write
watchpoint over a full boot catches 8 writes to `$10AA-$10AD`, **all
zeros**, from two bulk-clear routines (F0A1D2, F0A33C).

**That is weaker than "the chassis must supply it", which an earlier
revision of this file claimed.** F053E2 writes `#$2` into a word array at
`$10A0` indexed by `(d4 - 1) * 2`, and index 6 lands on `$10AA` —
`#$2` being exactly the value TCBIO1I dispatches on. So the ROM *does*
contain code that writes a nonzero value there; it simply never runs in
any configuration tested, because nothing reaches its enclosing function.
`d4` is range-checked `1 <= d4 <= $105E`, so whether index 6 is even
legal depends on `$105E`.

A chassis-side VersaBus master remains a plausible source, but it is now
one of two candidates rather than the only one, and the honest statement
is that the value's origin is **unresolved**.

Reproduce with `FPS3K_DMA10AA=2 FPS3K_MBOX=00010000 FPS3K_HOSTLVL=5`.

### The bulk data-in port is `$FF0008`

The mailbox path above is handshake only — it moves no payload. The
actual host-to-SBC bulk transfer is a polled loop in TCBRDHC at F04AE2,
and it reads a different port entirely:

```
F04AD6  lea    $8(a5),a0        ; a5 = $FF0000, so a0 = $FF0008
F04ADA  movea.l $E58,a1         ; g__srec_addr = destination in SBC RAM
F04AE2  move.w #$400,$218(a5)   ; arm  XLTR_STATUS_IRQ
F04AE8  move.w $218(a5),d7      ; poll XLTR_STATUS_IRQ
F04AEC  btst   #$f,d7           ;   until bit 15
F04AF0  beq    F04AE8
F04AF2  move.w #0,$218(a5)      ; clear
F04AF8  move.w (a0),(a1)+       ; *** read $FF0008 -> RAM, auto-increment
F04AFC  cmp.l  $E64,d0          ; g__panel_expected = word count
F04B02  ble    F04AE2
```

One 16-bit word per arm/poll/clear cycle, no interrupts anywhere. The
destination `$E58` is the same pointer `SRecordDataHandler` constrains to
`$10000-$1FFFF`, so this is the microcode staging path.

**The gate is a CHANNEL_SELECT readback of `$28`.** F04A84 reads
`$FF0204` back and stores it to `$E5C`; F04AC8 compares `$E5C` against
`$28` and only then enters the loop. The chassis signals "bulk transfer
pending" by presenting that value — it is not something the SBC wrote.

That is a falsifiable prediction, and it holds. Forcing the readback
(`FPS3K_CHSEL_RD=28 FPS3K_RESP=0x00`) produces
`[APIF] RD 2-byte FF0008` — the first read of that port in any run of
this emulator. The loop then exits after one word because `$E64` is
still zero, which is the next thing a chassis model has to supply.

Two neighbouring registers in the same window follow the per-channel
layout: `$FF0004` bit 0 is polled as a ready flag (F04B22, F05A22), and
`$FF0008` is the data-in port. So `$FF0000-$FF001F` is a channel window
of the same shape as the four at `$FF0040 + $20*N`.

### The response codes are a chassis-to-SBC command language

Codes `$1` and `$2` load 32-bit parameters a half-word at a time, taking
the value from the **CHANNEL_SELECT readback** and using **bit 6 of the
code** to pick which half:

| Code | bit 6 | Action |
|---|---|---|
| `$01` | 0 | `clr.w $E58` (addr high), `$E5A <- CHANNEL_SELECT` (addr low) |
| `$41` | 1 | `$E58 <- CHANNEL_SELECT` (addr high) |
| `$02` | 0 | `clr.w $E64` (count high), `$E66 <- CHANNEL_SELECT` (count low) |
| `$42` | 1 | `$E64 <- CHANNEL_SELECT` (count high) |
| `$00` | — | read CHANNEL_SELECT; if `$28`, run the transfer |

So `$E58`/`$E5A` is the 32-bit destination and `$E64`/`$E66` the 32-bit
word count, and the chassis programs both by pushing (code, argument)
pairs. That makes the whole thing a small command language, not a status
report.

### `$105E` is the installed-AC count, and it gates the dormant channels

CLAUDE.md has long recorded that this chassis runs a 2-AC configuration
and that "AC3 and AC4 task slots are dormant". `$105E` is the mechanism.

Each XP task compares it against **its own channel number** and skips its
channel initialisation if the count is lower:

| Site | Compare | Task |
|---|---|---|
| F07DF6 | `cmpi.w #$1,$105E` | TCBXP1I |
| F073F6 | `cmpi.w #$2,$105E` | TCBXP2I |
| F069F6 | `cmpi.w #$3,$105E` | TCBXP3I |
| F05FF6 | `cmpi.w #$4,$105E` | TCBXP4I |

A fifth independent confirmation of the task-to-channel mapping, and this
one is decisive about what the value means. Driving it confirms the
behaviour end to end — counting writes to each channel's write port:

| `$105E` | ch1 `$FF0044` | ch2 `$FF0064` | ch3 `$FF0084` | ch4 `$FF00A4` |
|---|---|---|---|---|
| `0` | 0 | 0 | 0 | 0 |
| `2` | 1 | 1 | 0 | 0 |
| `4` | 1 | 1 | 1 | 1 |

`$105E = 2` is exactly this machine's population. So the firmware is not
hard-wired for a 2-AC chassis: it is generic over 1-4 ACs and the chassis
tells it how many are present. That is why the ROM exposes four channels
while only two do anything here.

### `$105E` is supplied from outside the ROM



`$105E` is compared in six places (F04838, F04C94, F04E46, F04EEE,
F04F0A, F0538A) and **written nowhere**. It reads `$0000` after boot, and
it bounds every channel loop: F0538A range-checks a channel number as
`1 <= d4 <= $105E`, so at zero those loops never execute. It is the same
class of value as `$10AA` — something the chassis tells the SBC.

The channel number's meaning is pinned by F053B6, which loads
`$48585030` and adds `d4` to the low byte. `$48585030` is ASCII
**`"HXP0"`**, so this builds the `HXP1`..`HXP<n>` host-side ASQ names that
CLAUDE.md lists. That is a fourth independent confirmation that these
indices are XP channel numbers, and the first that ties them to the ASQ
naming convention.

A related array sits at `$10A0`, word-per-channel, written by F053E2 at
index `(d4 - 1) * 2`.

### `$1062` records the channel number, per task

Each XP task writes its own channel number to `$1062`:

| Site | Value | Task |
|---|---|---|
| F07E66 | 1 | TCBXP1I |
| F07466 | 2 | TCBXP2I |
| F06A66 | 3 | TCBXP3I |
| F06018 | 4 | TCBXP4I |

A third independent confirmation of the task-to-channel ordering, after
the ISR/vector arithmetic and the F046E0 table. `$1064` is a separate
shared word that all four tasks `and`/`or` bits into (F0683A, F07252,
F07C52, F08652), so it is a per-channel bitmask rather than a per-channel
slot.

### Two indexed blocks the chassis can read and write

Codes `$A` and `$C` operate on `$E7A`, a slot index range-checked
0..`$C` (13 slots) and auto-incremented under `$E87` bit 4 — so the
chassis can set that bit and walk a whole block with repeated codes.

| Code | Block | Entry size | Access |
|---|---|---|---|
| `$A` | `$1064` | 2 bytes | read only |
| `$C` | `$101E` | 4 bytes (high at `$101E+4N`, low at `$1020+4N`) | read and write, half selected by bit 6 |

Thirteen slots, not four, so `$E7A` is not an XP channel number despite
what some annotations in the disassembly say.

### A ROM table independently confirms the channel-to-BIM mapping

The channel ownership table in section 1 was built by reading CR write
sites and doing vector arithmetic. There is a literal table in the ROM
that says the same thing, reached from a different direction entirely.

F04CC8 indexes a longword table at **F046E0** by `($E60 - 1) * 4`,
dereferences it, and adds `$FF0000`. Dumping it:

| index | value | resolves to | channel |
|---|---|---|---|
| 0 | `$00000244` | `$FF0244` | TCBXP1I |
| 1 | `$00000246` | `$FF0246` | TCBXP2I |
| 2 | `$00000250` | `$FF0250` | TCBXP3I |
| 3 | `$00000252` | `$FF0252` | TCBXP4I |

Index 4 reads `$700141F9`, which is `moveq #1,d0` — the table is exactly
four entries and code follows it. So `$E60` is an **XP channel number
1-4**, and the ROM itself maps channel to BIM control register in exactly
the order section 1 derives. Two independent derivations agreeing is
worth more than either alone, and this one needs no inference at all.

The surrounding code also places the other two parameters. F04CAC builds
`a0` from an index scaled by `$20` — the channel-window stride — plus
`$E`, so `a1 = a0 - 6` lands on the channel's data port. It then loads
`d3 = $E68` and `d4 = $E60` and calls `PanelSendAndWait`. So the third
32-bit parameter that code `$9` loads is **a data value handed to the
panel send/wait engine**, alongside the channel number.

`$E7A`, the operand of codes `$A` and `$C`, is a separate **slot index**
range-checked 0..`$C` and auto-incremented under `$E87` bit 4. It indexes
tables at `$1064` and `$1020` — 13 slots, not 4, so it is not the XP
channel number.

### Code `$3` is the chassis-memory access primitive

The `$3` handler at F04D4E is a **paged 32-bit read/write of chassis
memory**, and it is where the SBC's address translation lives:

```
d1 = $E58                    ; the 32-bit address parameter
d1 >>= 20                    ; top 12 bits
MODE2 ($FF0210) = d1         ; <- page / bank register
d1 = $E58 & $FFFFF           ; low 20 bits
d1 <<= 2                     ; longword-scaled
a1 = d1;  access (a1 + $400000)
```

Bits 5 and 6 of the code pick the operation, and `$E70`/`$E72` are a
32-bit data register the same way `$E58`/`$E5A` are an address register:

| Code | bit 6 | bit 5 | Action |
|---|---|---|---|
| `$43` | 1 | 0 | `$E70 <- CHANNEL_SELECT` (data high) |
| `$03` | 0 | 0 | `$E72 <- CHANNEL_SELECT` (data low), then **write** `$E70` to chassis |
| `$63` | 1 | 1 | **read** chassis into `$E70` |
| `$23` | 0 | 1 | `$E74 <- $E72` (return the low half) |

A round trip confirms all of it. Driving
`01:0000,41:0000,43:DEAD,03:BEEF,63:0000` writes `$DEADBEEF` to chassis
address 0 and reads it back: the RAM dump shows **`$E70 = DEADBEEF`**.

The page register is confirmed separately by varying only the address:

| `$E58` | MODE2 written | read-back |
|---|---|---|
| `$00300000` | `3` | `12345678` |
| `$00500000` | `5` | `12345678` |

So `$FF0210` — which earlier docs list only as "Mode Register 2, cleared
during channel setup" — is the **chassis page/bank select**, carrying
address bits 20-31. The `<<2` says the address parameter counts
**longwords**, not bytes, which fits a 32-bit machine whose SCM is
addressed in words of its own width.

This is the primitive behind EXPUT/EXGET and XPDMAR/XTMDMA: one address
register, one data register, a page select, and a read/write bit. Which
memory a page maps to (SCM, WCS write port, TCM) is not settled here —
but the fact that the API distinguishes XPDMAR (SCM<->LMD) from XTMDMA
(SCM<->TCM) while the ROM has only this one primitive suggests the page
field is what picks between them.

### All 16 opcodes of the F05102 dispatcher

The response byte splits into fields rather than being a flat code:

```
   bit 7    selects the dispatcher (0 = this table, 1 = the 0..$14 path)
   bits 6-5 modifiers — half-select for the 32-bit loaders, mode elsewhere
   bits 3-0 the opcode, indexing F05102
```

| Code | Target | What it does |
|---|---|---|
| `$0` | F04A84 | read CHANNEL_SELECT; `$28` runs the bulk transfer, else validate 0..`$10` into `$E5C`/`$E5E` |
| `$1` | F04CF2 | load destination-address half (bit 6 selects) into `$E58`/`$E5A` |
| `$2` | F04D20 | load word-count half (bit 6 selects) into `$E64`/`$E66` |
| `$3` | F04D4E | MODE2 / WCS page setup; `$E87` bits 5-6 pick a 20-bit address shifted by 14 or by 2 |
| `$4` | F04E3A | validate `$E60` against `$105E`; overflow issues panel cmd `$25C` |
| `$5` | F04EE4 | validate CHANNEL_SELECT as a channel number against `$105E` |
| `$6` | F04F30 | `a1 <- $E58`, join the shared tail at F04EA0 |
| `$7` | F04F3A | **clear IRE (bit 4) of BIM0 CR0** — disable the dispatcher's own interrupt |
| `$8` | F04F52 | test MODE1 bit 14 with CHANNEL_SELECT == 0 |
| `$9` | F04FA0 | load a **third** 32-bit parameter half into `$E68`/`$E6A` |
| `$A` | F04FBA | range-check `$E7A` against 0..`$C` |
| `$B` | F05002 | compute `$10010`, store under `$E87` bit 6 |
| `$C` | F0502C | index a table by `$E7A << 2` |
| `$D` | F05092 | validate CHANNEL_SELECT 0..`$F` |
| `$E` | F050CA | if CHANNEL_SELECT == 0, clear MODE1 bit 7 |
| `$F` | F050F8 | **return from interrupt** — `movem.l (a7)+,d0-d7/a0-a7`, `ccr`, `trap #1` |

Six are confirmed by execution, not just by reading: `$0` (drives the
8-word transfer), `$1` and `$2` (address and count), `$B` (traced to
F05002), `$7` (BIM0 CR0 observed going `$5E` -> `$4E`, exactly bit 4),
and `$F` (F050F8 then the `trap #1`, once each).

So the language has three 32-bit parameter registers (`$E58` address,
`$E64` count, `$E68` unknown), a set of validators, an interrupt-disable,
and an explicit terminator. `$F` being the return explains the shape of
every other handler: they all end in `bra ChannelConfigDispatch` and only
`$F` unwinds the frame.

### End-to-end: the staging path driven through the firmware

Scripting that sequence runs the ROM's reason for existing:

```
FPS3K_SEQ="01:0000,41:0001,02:0008,42:0000,00:0028"
    $01 + $0000  -> destination low  = $0000, high cleared
    $41 + $0001  -> destination high = $0001   (= $00010000)
    $02 + $0008  -> count low  = 8
    $42 + $0000  -> count high = 0             (= 8 words)
    $00 + $0028  -> run
```

All five codes are delivered and dispatched (`F04CF2` twice, `F04D20`
twice, `F04A84` once), the loop at F04AF8 executes **exactly 8 times**,
and the bus log shows **8 reads of `$FF0008`**. With the port handing
back an incrementing pattern, a RAM dump gives:

```
$10000: 1000 1001 1002 1003 1004 1005 1006 1007 0000 0000 ...
```

Eight words at the programmed address, nothing past the programmed
count. Destination decode, count decode and transfer loop all confirmed
together — the microcode staging path works through the firmware's own
mechanism, with no monitor bypass.

One modelling note: after the SBC acknowledges a response the emulator
queues the next step itself rather than waiting for another
CHANNEL_SELECT write. Driven the other way only the first code is ever
delivered, because the address-setter path returns to
`ChannelConfigDispatch` without re-issuing a panel command. A real
chassis pushing its own stream is the natural reading, but the
alternative — that some further SBC action re-arms it — is not excluded.

### What the response does not do

Sweeping every response value in `$00`-`$14` and `$80`-`$94` (both
dispatchers, 42 runs) gives two firm negative results:

- **`$FF0048` is never read.** Not once, on any code. The host byte is
  therefore not consumed through the panel-status path, and whatever
  frees the host to send its next byte is some other mechanism.
- **`F0572C` — the `PanelStatusDispatch` site — is never reached.** So
  the 42-slot `F05BA4` table below, although correctly decoded, is *not*
  what `F04930` dispatches through. It belongs to a different caller.

An earlier revision of this file stated that the SBC "reads `$FF0048`
for the first time, consuming a host byte". That was an artefact: the
apparent read was an **instruction fetch** from `PC=$FF0048`, after a
re-entrant interrupt storm walked the stack down through the vector
table and overwrote vector `$128` with `$00FF0000`. Logging the PC of
each access (`FPS3K_PCLOG`) is what exposed it; register-access logs
alone cannot distinguish a data read from an opcode fetch.

## The dispatch table is executable code

`PanelStatusDispatchTable` at `F05BA4` is not a table of addresses. It is
42 four-byte slots that `jmp (a4,d0.w)` lands in and executes, each
holding either `4E75 4E71` (`rts; nop`) or `4EFA xxxx` (`jmp d16(pc)`).
Decoding the displacements gives every reachable code:

| Code | Handler | Code | Handler |
|---|---|---|---|
| `$00` | no-op | `$0A` | POLL (`F05A12`) |
| `$01` | POLL | `$0B`, `$0C` | no-op |
| `$02`-`$07` | D1_SEND (`F058B2`) | `$0D`-`$10` | D1_SEND |
| `$08`, `$09` | BLK_XFR (`F05B0E`) | `$11`-`$13` | no-op |
| | | `$14` | D2_FIN (`F05738`) |

Counts within the range check are POLL 9, D1_SEND 10, BLK_XFR 9, D2_FIN 1
and **13 no-ops**. Earlier notes give 12/10/11 and omit the no-ops. The
range check stops at `$14`, so 21 of the 42 slots are unreachable by this
path.

## Measured behaviour per code

The codes can be driven directly (`FPS3K_INJECT=<code>` fires one
response on BIM0 ch0). **Treat the table below as unverified**: it was
measured before the interrupt-storm bug above was found, so some of its
writes may be storm artefacts rather than per-code behaviour. It needs
re-running against the corrected model. Writes observed after injection:

| Code | Predicted | Registers written |
|---|---|---|
| `$00` | no-op | `FF0200`, `FF020C` |
| `$01`, `$02`, `$0A`, `$0B`, `$0D`, `$11` | mixed | `FF0200`, `FF0204`, `FF0230` |
| `$08` | BLK_XFR | `FF000E`, `FF0200`, `FF0202`, `FF0204` |
| `$14` | D2_FIN | `FF000E`, `FF0200`, `FF0202`, `FF0204` |

Only `$08` and `$14` write `FF000E`, the command register: those are the
codes that issue a further panel command. The no-op slots return into
their caller, which then runs its own `FF0200`/`FF0204`/`FF0230`
sequence, so a `rts` slot does not mean nothing happens.

The code is **inert on the host byte path**: sweeping all 21 values there
produced identical behaviour every time. Only the task-context dispatch
at `F04930` reads it. Two mechanisms share `MODE0`, which is why the
level split exists.

## Open lead: the 92-word window sweep

After consuming a host byte the SBC reads 92 consecutive words from
`$FF0048` to `$FF00FE`, straight through the channel boundaries to the
end of the AP I/F window. That does not fit a byte-at-a-time port and
may indicate the window is a buffer the SBC drains, which would fit the
eight Am29705 dual-port SRAMs on the card. Not yet explained.

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
