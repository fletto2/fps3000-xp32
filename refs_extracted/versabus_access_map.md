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

### Driving the S-record front end — what it takes, and where it stops

Reaching `SRecordDataHandler` through the firmware's own path (rather
than the monitor's `L` bypass) needs four things, each found by running
into it:

1. **`$FF0004` bit 0 must read set.** F04B22 spins on it before every
   transfer — 9.2 million iterations in the run that lacked it. It is the
   port-ready flag, and `versabus.c` now returns it when an S-record
   source is configured.
2. **The chassis must initiate.** TCBRDHC parks at **F04736** waiting to
   be told what to do, so nothing ever writes CHANNEL_SELECT and nothing
   arms a response. The scripted chassis has to start itself once BIM0
   ch0 is enabled; it cannot wait to be prompted.
3. **The stream must be 4-character aligned and free of newlines.** The
   parser reads **two words per iteration, two ASCII characters per
   word**, and does not re-synchronise on a record boundary. A 17-byte
   `S0` header with a trailing newline misaligns everything that follows,
   which is what an early attempt did.
4. **The word count `$E64` must be programmed first**, via response codes
   `$2`/`$42`. With it zero the parser reads the header, matches `"S0"`
   and exits immediately at F04C42.

With all four, the path runs: `F04B8A` matches, `F04BBC` matches `"S2"`,
and **`SRecordDataHandler` at F051A2 executes** — 35 distinct
instructions of it, reading the record body directly from `$FF0008`
through its own arm/poll/clear loop at F051A8-F051BE.

Reproduce with:

```
FPS3K_SREC=<file> FPS3K_SEQ="02:000E,42:0000,00:0000"
```

### Inside `SRecordDataHandler`, decoded

Instrumenting the range check (`FPS3K_REGLOG=F051FE`) gives the register
roles directly:

| Register | Role |
|---|---|
| `d5` | **address-width shift**, set by the caller per record type: `$08` for S1, `$10` for S2, `$18` for S3 — i.e. `(address_bytes - 1) * 8` |
| `d4` | **record byte count**, taken from the record's own count field at F04B88 and decremented once per byte consumed |
| `d2` | the current converted byte |
| `a1` | the destination pointer, **initialised to `$10`** at F051A2 |

The store and its guard:

```
F051FE  cmpa.l #$10000,a1
F05204  blt  F05212            ; below the staging buffer -> reject
F05206  cmpa.l #$1FFFF,a1
F0520C  bgt  F05212            ; above it -> reject
F0520E  move.b d2,(a1)+        ; the store
F05210  bra  SRecordParseLoop
```

This is where the `$10000-$1FFFF` constraint CLAUDE.md attributes to the
handler actually lives — a byte-at-a-time store with a two-sided bounds
check, silently rejecting anything outside.

### `$FF0000` signals end-of-stream

**Two exits, and an earlier note here had them backwards.** `F05254` is
the **success** exit — reached when `d4` counts down to 1, the last byte
is read, and the handler `rts`. In the verified two-record load it
executes exactly twice, once per record. `F05224`, previously described
as "the `PCMD_CH1_ACK` that ends a successful record", is the **reject**
exit and executes zero times on a clean load.

**The firmware does not validate S-record checksums.** At `F05250` the
final byte — the record's checksum — is read into `d2`, and what follows
is `addq.l #1,d0` then `rts`. It is never compared against anything.

That matters for anyone generating microcode: a corrupt record will be
stored, not rejected. The in-ROM monitor's `L` command *does* validate
checksums, so the two paths differ in safety, and the safer one is ours
rather than FPS's.

The reject path is more interesting than a simple error exit:

```
F05212  a1 = $FF0000
F05218  cmpi.w #$0,$0(a1)      ; read APIF_CMD_STATUS
F0521E  ble  F05224            ; <= 0 -> done, issue PCMD_CH1_ACK
F05220  d0 = (a0)              ; else drain a word from $FF0008
F05222  bra  F05218
```

So after a rejected record the firmware **drains the port until
`$FF0000` reads zero or negative**. That makes `$FF0000` an
end-of-stream indicator as well as the command/status register: the
chassis says "nothing more" by clearing it, or by raising bit 15.

Our model returns `$4000` there permanently, so the drain never
terminates — which is what the run actually did.

### The outbound half, verified

The other direction works exactly as the static decode predicts. Driving
it alone:

```
FPS3K_SEQ="01:0010,41:0001,02:0008,42:0000,20:0000"
```

- `$01`/`$41` set the source address: `$E58 = $00010010`
- `$02`/`$42` set the word count: `$E64 = $00000008`
- `$20` is opcode `0` with **bit 5 set** — the outbound selector

Result: F04C62 executes **8 times** and the bus log records **8 writes to
`$FF0008`**. Programmed address and count are both confirmed in the RAM
dump.

So the complete microcode chain is now exercised in both directions:

```
  host ASCII S-records --> $FF0008 --> SRecordDataHandler --> $10010+
  $10010+ --> $FF0008 --> XLTR --> UNIV FMT --> XP-32 WCS
```

**One limitation, and it is the harness.** Chaining a load and a push in
a single scripted run does not work: the parameter-loading responses
interleave with the long S-record parse and land wrong (`$E58` came out
`$00010001` and `$E64` zero). Each half verifies cleanly on its own.

The obvious fix — re-arm only when TCBRDHC is back at its idle wait,
rather than on acknowledgement — **was tried and made things worse**, so
it is recorded here as a dead end rather than a suggestion. Gating on
`PC == F04736` stopped the inbound path running at all and left `$E58` at
`$00080010` with a count of `$1C`. `F04736` is reached transiently
between commands, not only when the task is genuinely idle, so it is not
the completion signal it looks like. The change was reverted.

The `$FF000E` panel-command write was tried too, on the reasoning that
F05224 issues `PCMD_CH1_ACK` that way after a successful record. **It
also failed**, and worse: it broke the isolated cases as well. The SBC
writes `$FF000E` when it *starts* a command as well as when it finishes
one, so the flag fired immediately and the next response still landed
mid-command.

Two attempts, one cause: **there is no CPU-side event meaning "the SBC
has finished"** — and the bus-mastership section above explains why. The
SBC is a slave here. It is not driving the transfer, so its instruction
stream cannot report the transfer's completion. Both attempts were
interrogating the reactive party.

### The fix: let the chassis keep its own schedule

Once the SBC is understood as reactive, the sequencer becomes simple. The
chassis issues a command, waits long enough for the SBC to deal with it,
and issues the next — no inference, no completion signal.
`FPS3K_SEQGAP` sets the spacing in cycles (default 20 M).

**With that, the whole chain runs in one session:**

```
FPS3K_SEQGAP=40000000 FPS3K_SREC=<file> \
FPS3K_SEQ="02:001C,42:0000,00:0000,01:0010,41:0001,02:0008,42:0000,20:0000"
```

| stage | result |
|---|---|
| inbound stores (F0520E) | **16** |
| staging at `$10010` | `DEADBEEFCAFEBABE0102030405060708` |
| parameters reloaded | `$E58 = $00010010`, `$E64 = $00000008` |
| outbound moves (F04C62) | **8** |
| words written to `$FF0008` | `DEAD BEEF CAFE BABE 0102 0304 0506 0708` |

The bytes that entered as ASCII S-record text leave as binary words on
the bus, in order, with nothing lost. **That is the complete microcode
upload path — host to WCS — exercised through the firmware's own
mechanisms in a single run.**

### The record address is an OFFSET — the firmware adds `$10000` itself

The address accumulation loop settles it:

```
F051A2  a1 = $10                 ; initial value
F051BE  d2 = (a0)                ; one byte, as two ASCII chars
F051C4  convert
F051CE  lsl.l d5,d2              ; shift into position
F051D0  adda.l d2,a1             ; accumulate
F051D4  d5 -= 8
F051DA  bge F051A8               ; more address bytes
F051DC  adda.l #$10000,a1        ; <-- add the staging-buffer base
```

So the destination is

```
    a1 = $10 + <record address> + $10000
```

An S2 record carrying address `$010000` therefore lands at
`$10 + $010000 + $10000 = $020010`, which is out of bounds and silently
rejected — exactly the `$00020010` the instrumented run reported.

**CLAUDE.md says "SRecordDataHandler enforces `0x10000 <= addr <=
0x1FFFF`". That is the check on the *computed* address, not on the
address written in the record.** The record address must be an offset
from zero. The usable range is:

| | |
|---|---|
| record address | `$0000` - `$FFEF` |
| lands at | `$10010` - `$1FFFF` |

The first 16 bytes of the staging buffer are unreachable through this
path because of the `$10` initial value.

### Verified end to end

Records built that way load correctly through the firmware's own front
end, with no monitor involvement:

```
S20C000000DEADBEEFCAFEBABE7B S20C0000080102030405060708C7
FPS3K_SREC=<file> FPS3K_SEQ="02:001C,42:0000,00:0000"

-> F0520E executes 16 times
-> $10010: DEADBEEFCAFEBABE0102030405060708
```

Two records, sixteen bytes, contiguous and correct at the computed
destination. **This is the complete microcode staging path exercised
through the firmware's S-record receiver** — host ASCII into `$FF0008`,
parsed in place, stored to the WCS staging buffer — as opposed to the
monitor's `L` command, which bypasses all of it.

Anyone generating microcode for this machine needs to emit S-records
addressed from **zero**, not from `$10000`.

### `$FF0008` has three modes, and one of them is ASCII S-records

The third branch out of the opcode test — `$E5C == 0` with `$E87` bit 5
**clear** — leads to F04B22, and it is the S-record receiver:

```
F04B22  poll $FF0004 bit 0            ; port ready
F04B2C  COUNTER <- 4
F04B4E  STATUS_IRQ <- $400            ; arm
F04B54  poll STATUS_IRQ bit 15, clear
F04B64  d1 = (a0)                     ; word 1 from $FF0008
F04B68  arm / poll / clear again
F04B7E  d2 = (a0)                     ; word 2
F04B82  jsr F05150                    ; hex conversion
F04B8A  cmpi.w #$5330,d1              ; "S0"
F04B9A  cmpi.w #$5331,d1              ; "S1" -> d5=8, jsr SRecordDataHandler
```

`$5330` is ASCII **`"S0"`** and `$5331` is **`"S1"`**. So the S-records
arrive through the same `$FF0008` port as **two ASCII characters per
16-bit word**, one word per arm/poll/clear cycle on `XLTR_STATUS_IRQ`.

CLAUDE.md describes the upload as "S-records over the AP I/F", which is
right but leaves the mechanism open. The concrete answer:

| `$E5C` | bit 5 | Mode at `$FF0008` |
|---|---|---|
| `$00` | 0 | **ASCII S-record text**, 2 chars per word, parsed in place |
| `$28` | — | **binary inbound**, word -> `$10000+` |
| `$00` | 1 | **binary outbound**, `$10000+` -> port |

One port, three modes, all three gated by the identical
`STATUS_IRQ <- $400` / poll bit 15 / `STATUS_IRQ <- 0` handshake. The
mode is selected entirely by the latched opcode and one response bit.

That also explains why the firmware carries an S-record parser at all
when it has a perfectly good binary bulk path: the two are alternative
front ends to the same staging buffer, and the ASCII form is what a host
sends when it is shipping a *file*, while the binary form is what the
chassis uses once a transfer is already set up.

### `$FF0008` is bidirectional, and response-byte bit 5 picks the direction

The inbound loop at F04AE2 is only half the mechanism. F04C50 is its
mirror:

```
F04C50  a0 = $FF0008          ; the same port
        a1 = $E58             ; the same staging pointer
F04C62  move.w (a1)+,(a0)     ; RAM -> port  (F04AF8 does port -> RAM)
        cmp d0, $E64          ; the same count
        ble F04C62
```

Same port, same address parameter, same count parameter, opposite
direction. `$FF0008` is a bidirectional bulk data port.

**The selector is bit 5 of the response byte.** After the opcode latch
`$E5C` is tested, F04B16 does `btst #5,$E87` and F04B1E branches to the
outbound loop when it is set:

| `$E5C` | `$E87` bit 5 | Path |
|---|---|---|
| `$28` | — | **inbound** bulk, F04AE2: `$FF0008` -> `$10000+` |
| `$00` | 1 | **outbound** bulk, F04C50: `$10000+` -> `$FF0008` |
| `$00` | 0 | F04B22, the polled non-bulk path |

This completes the microcode upload route. Host content reaches the
staging buffer by S-record or by inbound bulk, and leaves for the WCS
through the **outbound** direction of the same port:

```
host -> [S-record parser | inbound $FF0008] -> $10000-$1FFFF
     -> outbound $FF0008 -> XLTR -> UNIV FMT -> XP32 WCS
```

Note bit 5 is a direction modifier in the code `$3` chassis-memory
primitive too, but with the **opposite sense** — there bit 5 set selects
a *read* of chassis memory into `$E70`, here it selects a *write* out of
SBC RAM. The bit means "direction" in both, but the polarity is
per-command and should not be generalised.

### Where the WCS bank select must live — still open

The AU store is 4K x 128 bits x **four banks** per AC, and the staging
buffer holds exactly one bank. Neither transfer loop touches a bank
register: both use only `$E58` (address) and `$E64` (count), and the
destination within the chassis is not expressed in either.

### Resolved: there is no SBC-side bank select

The earlier guess here was that `$E68`/`$E6A`, the third 32-bit
parameter, carried the bank "by elimination". **That is wrong and is
retracted.** `$E68` has exactly two references in the ROM: response code
`$9` writes it at F04FA0, and F04CDC reads it into `d3` for
`PanelSendAndWait`, where the dispatch handlers push it to the channel
status port (`move.w d3,$2(a1)` at F05886, F059D0, F062C6). It is a data
value for the panel engine, not an address.

More decisively, the outbound bulk loop references **only** `$FF0000`,
`$FF0008`, `$E58`, `$E64` and the constant 1. There is no destination
register of any kind in it.

So the SBC streams words at `$FF0008` **with no notion of where they
land**. That is exactly what the bus-mastership finding predicts: the SBC
is a slave conduit, and the chassis — which is the master — decides the
destination. There is no WCS bank select in the SBC's command set because
the SBC does not address the WCS.

**Practical consequence.** A revival attempt cannot choose the target bank
from the SBC side, and no amount of further ROM analysis will find a way
to. Bank selection has to come from whatever configures the XLTR or the
UNIV FMT before the transfer starts — the host-side command, or a panel
command whose effect is inside the chassis rather than in SBC RAM. The
monitor's `L` command has the same limitation: it fills the staging
buffer, but what happens to those bytes afterwards is not the SBC's
decision.

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

### The four XP tasks are three template copies and one original

Diffing the task bodies pairwise, **each at its own stride**:

| comparison | stride | bytes differing | share |
|---|---|---|---|
| XP1I vs XP2I | `$A00` | 76 / 2528 | 3.0% |
| XP2I vs XP3I | `$A00` | 77 / 2528 | 3.0% |
| XP3I vs XP4I | **`$A18`** | 493 / 2528 | 19.5% |

All four are near-copies of one template. XP4I is the most divergent but
is still 80% identical to XP3I.

**An earlier revision of this table reported TCBXP4I as "2303 / 2554,
90.2% — not a copy at all". That was an alignment artefact and is
retracted.** XP4I sits **`$18` bytes off the `$A00` grid** — XP3I to XP4I
is `$A18`, while XP1I to XP2I to XP3I are exactly `$A00`. Comparing at a
fixed `$A00` stride misaligns every byte after the first shift and
reports 81.5% difference for what is really 19.5%.

The `$18` shift is also why XP4I's ISR sits at `+$B6` from its CR write
instead of `+$D4`, and it is confirmed independently: each task calls its
own copy of a helper — F060FA, F06B12, F07512, F07F12 — and those are
spaced `$A18`, `$A00`, `$A00`, exactly matching.

Two conclusions elsewhere in this document inherit the correction. The
replication measurement counts only **exact** repeats, so XP4I's shifted
near-copies are invisible to it and **28.6% is a lower bound**. And the
advice to skip XP2I/XP3I as redundant applies to XP4I too — it is a
copy with a shift, not a separate routine.

The substituted constants are exactly what the channel identity requires:

| Offset | Meaning | ch1 | ch2 | ch3 | ch4 |
|---|---|---|---|---|---|
| +`$005` | BIM CR low byte | `$44` | `$46` | `$50` | `$52` |
| +`$00D` | channel number | `$01` | `$02` | `$03` | `$04` |
| +`$019` | data port B low | `$4E` | `$6E` | `$8E` | `$AE` |
| +`$01F` | data port A low | `$48` | `$68` | `$88` | `$A8` |
| +`$013` | RAM slot | `$68` | `$6E` | `$74` | `$7A` |
| +`$041` | RAM slot | `$66` | `$6C` | `$72` | `$78` |

The BIM row reproduces the F046E0 table exactly, and the data-port rows
reproduce the `$20` channel stride. This is a sixth independent
confirmation of the mapping.

## The channel `+$08`/`+$0A` pair is one 32-bit register

This document and CLAUDE.md both label the per-channel window as
"Read A `+$08`" and "Status `+$0A`". `BLK_XFR` (F05B0E) says otherwise:

```
a5 = $FF0008
if a2 == a5:  poll $FF0004 bit 0        ; destination is the bulk port
loop:
   d6 = (a1)        ; channel +$08
   (a2) = d6
   if (swapped) d0 == 0:
        d6 = $2(a1) ; channel +$0A
        (a2) = d6           ;  -> same address: packed into a FIFO port
   else:
        d6 = $2(a1)
        $2(a2) = d6         ;  -> next word: strided into memory
```

It reads **both** words every iteration and deposits them either at one
address or at consecutive addresses. That is what moving a 32-bit value
looks like: `+$08` is the high half, `+$0A` the low half. `+$0A` is not a
status register.

TCBXP1I corroborates it from the write side. F07EC6 writes `(a1) <- 0`
then `$2(a1) <- $1B`, which is the 32-bit constant `$0000001B` written
high-half-then-low-half — the same convention `BLK_XFR` reads back.

A 32-bit channel register also fits the hardware: the AP I/F carries
eight **Am29705** 16-word x 4-bit dual-port SRAMs, which is 32 bits wide.

The high word of the opcode selects the destination style — packed for a
port, strided for memory — which is the only use found for the upper half
of the opcode word.

## `+$0E` is a command register, not "Read B"

The same three task copies that write the 32-bit pair go on to write
`$8000` to the channel's `+$0E`:

| Task | `+$08`/`+$0A` | `+$0E` |
|---|---|---|
| TCBXP1I F07EC6 | `$FF0048`/`$FF004A` <- `$0000001B` | `$FF004E` <- `$8000` |
| TCBXP2I F074C6 | `$FF0068`/`$FF006A` <- `$0000001B` | `$FF006E` <- `$8000` |
| TCBXP3I F06AC6 | `$FF0088`/`$FF008A` <- `$0000001B` | `$FF008E` <- `$8000` |

Load a 32-bit value, then write a bit-15-set word to `+$0E`. That is a
**command/trigger register**, and `$8000` is the trigger. `+$0E` is also
read once per channel during init (F0A204-F0A21C), so it is read/write.

Both this file and CLAUDE.md label the per-channel window as
`Write +$04 / Read A +$08 / Status +$0A / Read B +$0E`. Three of those
four labels are wrong. The evidence supports:

| Offset | Corrected role |
|---|---|
| +`$04` | write port (tasks write `0` here at init, F07E00) |
| +`$08` | 32-bit data register, **high half** |
| +`$0A` | 32-bit data register, **low half** |
| +`$0E` | **command/trigger** — `$8000` fires it; also readable |

## Why no datasheet defines the board-status bits: six of them are user-defined

Motorola's own **Table 1 — VM02 Specifications** (M68KVM02-3, page 2-59
of the datasheet, now at `refs/datasheets/M68KVM02.pdf`) settles a
question this project has worked around for a long time:

```
Board Status/Control Registers
  Size            28 bits
  Status Inputs   System Controller
  12 Bits         VERSAbus Available
                  VERSAbus Interrupt Serviced
                  System Failure
                  VERSAbus Test
                  User-Defined (6)          <-- six of the twelve
  Control Outputs VERSAbus Interrupt
  16 Bits         VERSAbus Interrupt Acknowledge Mask
                  System Controller VERSAbus Transfer Request
                  VERSAbus Block Transfer Request
                  Board Fail Status
                  Interrupt Mask
                  VERSAbus Available Mask
                  System Fail Interrupt Mask
                  Write Protect
                  I/O Channel Interrupt Mask
                  VERSAbus Resource Management (4)
```

12 status + 16 control = the stated 28 bits. `$F70018/$F70019` carries
the status inputs; `$1FFF0/$1FFF1` carries the control outputs.

**Half the status register is left to the integrator.** Motorola defines
five signals and hands FPS six bits to wire to whatever the chassis
needs. That is exactly where the bits this project has been reverse-
engineering must live: `$F70019` bits 1, 2, 3, 4 and 5 — the ones driving
the self-test gate, the chassis-ready handshake and the block selector —
are FPS-specific, not Motorola-specific.

Three consequences:

1. **No datasheet will ever define them.** Searching for Motorola
   documentation of these bits was never going to succeed, and the
   inference-from-firmware approach was not a workaround but the only
   available method.
2. **The relationships are allowed to look arbitrary.** `$F70019` bit 3
   tracking the inverse of `$1FFF1` bit 6 is a wire FPS chose. There is
   no general rule to recover, only this machine's wiring.
3. **The count fits.** Five bits are in active use in the firmware
   (1, 2, 3, 4, 5) against six user-defined inputs available — a
   comfortable match, and it suggests one spare.

The same table also confirms a modelling detail taken on faith. The
memory map footnote reads "**Control Register image only. Register not
directly accessible**", so `$1FFF0` is a RAM-backed image whose reads
return the last value written rather than any hardware state. That is
what `versabus.c` implements, and phase `$0600`'s eight-pattern
round-trip test only passes because of it.

## The ROM image carries an XOR checksum; the kernel region does not touch the chassis

Two checks on regions this project had written off.

### The "free" ROM is not entirely free

`F0A826-F0FFFF` is 22,490 bytes, and **22,488 of them are `$00`**. The
exception is the final word at `$F0FFFE`: **`$C12D`**, which is the XOR of
every preceding 16-bit word. The stock image therefore XORs to **zero** —
an image-integrity word.

Nothing in the firmware verifies it, so the standing claim that there is
no ROM checksum *in the boot path* still holds. But the image is
checksummed for someone — an EPROM programmer, a factory tool, the VM02
monitor — and **every monitor image this project produced before
2026-07-29 left it broken**, including the one burned for the first
hardware attempt. `monitor/patch_rom.py` now recomputes it;
`tools/verify_findings.py` asserts the stock image still XORs to zero.

### The kernel region really is stock — a scan said otherwise and was wrong

A 32-bit scan of `F00000-F04487` for chassis addresses returned five
hits, suggesting FPS had patched the RMS68K kernel. **All five are false
positives** — the scan was reading instruction operand pairs as address
constants:

| site | bytes | actual instruction |
|---|---|---|
| F03DC8 | `0C2A 00FF 0008` | `cmpi.b #$FF,$8(a2)` |
| F03F50 | `0C29 00FF 0018` | `cmpi.b #$FF,$18(a1)` |
| F02802 | `48EE 00FF 0100` | `movem.l <$00FF>,$100(a6)` |
| F028A0 | `4CEC 0070 0012` | `movem.l $12(a4),<$0070>` |

Searching instead for genuine address loads — `movea.l #imm,aN` (`2x7C`)
and `lea imm.l,aN` (`4xF9`) — finds **zero** chassis references in the
kernel region. The kernel is unmodified, and all chassis access lives in
the FPS application code above `$F04488`, as previously assumed.

Worth keeping as a method note: scanning a byte range for 32-bit
constants at every even offset will manufacture hits out of any
instruction whose operands happen to align. Decode before believing.

## Regression harness for the findings in this document

`tools/verify_findings.py` asserts **21 of the claims made here**, in the
ROM image and at runtime. Run it from the repo root after any change to
`disasm.py`, the emulator, or the ROM:

```
python3 tools/verify_findings.py     ->  21/21 passed
```

Static checks: the ROM's MD5; that the panel-command issuer has exactly
seven byte-identical copies at the documented addresses; that the 42-slot
dispatch table has five; that F05102 is sixteen `4EFA` entries; that
`SRecordDataHandler` seeds `a1 = $10` and adds `$10000`; that one
S-record parser takes S8 and the other S7; that the XP task stride is
`$A00` with XP4I aligning at `$A18`; and the TDTI entry names.

Runtime checks: that a boot installs all six task ISR vectors; that the
self-tests execute and hit **zero** error flags; that an S-record load
produces exactly 16 stores with the right bytes at `$10010`; and that it
exits via `F05254` (success) rather than `F05224` (reject).

**The harness is itself tested.** A check suite that has never failed
proves nothing, so `verify_findings.py` takes an optional ROM path.
Mutating two bytes — one inside panel-issuer copy 4 at `F068A8`, one in
`SRecordDataHandler`'s `$10000` addend at `F051DC` — takes it from 21/21
to **12/21**, with the issuer count dropping 7 to 6 and every runtime
check failing:

```
python3 tools/verify_findings.py mutant.bin
  FAIL  panel issuer: exactly 7 byte-identical copies
        F04500 F05688 F05E56 F072C0 F07CC0 F086C0     <- F068A8 missing
  12/21 passed
```

Nine checks still pass on that ROM, which is correct: each targets a
specific claim, and those nine are untouched by these mutations.

**Why this exists.** Several findings in this document were wrong for
days before anything caught them — a `ROMChecksumTest` label that
outlived its correction by three days, an XP4I "90% divergent" reading
that was an alignment artefact, an `F05224` success/reject swap. Each was
a claim nothing tested. The harness will not catch a wrong
*interpretation*, but it will catch the case where a change makes a
recorded fact stop being true, which is the failure mode that has cost
the most time here.

## Validation record: the self-test suite as a chassis-model test harness

With the four chassis-stub fixes in place the firmware's own diagnostics
run end to end, and they are a far better check on the chassis model than
anything hand-written. Measured over a full boot:

**Every subtest passes on the first attempt.** The suite signals failure
by loading the marker `$F0F0F0F0` into `d7`; there are **65 such sites**
in the ROM and **none of them execute**. No test retries, and no test
falls into an error path silently. That is a stronger statement than the
run merely completing, and it is the claim the emulator could not make
before.

**Bus errors are deliberate and counted.** `F098E0` — the handler phase
`$1700` installs at vector `$8` before it starts (F09606 saves the old
one, F0960A installs its own) — executes exactly **3** times. The
firmware is testing that the chassis *denies* out-of-range access, so
those three BERRs are the expected result, not a fault. A model that let
those accesses succeed would fail the test.

**The phase beacon walks cleanly.** Every test writes its phase number to
CHANNEL_SELECT as `phase<<8 | subtest`, giving an externally visible
progress trace. The observed walk is monotonic with no repeats:
`$0100`-`$0168` (105 subtests), `$0200`-`$0205`, `$0300`, `$0400`,
`$0500`, `$0600`-`$0605`, and so on through `$1A00`, then `$2000`.

That beacon is worth noting as a **hardware bring-up aid in its own
right**: on a real board, watching `$FF0204` during reset tells you
exactly which self-test the firmware is executing and which subtest it
died on, with no debugger and no serial port. The value that sticks is
the last one written.

`PollBoardStatus` takes its `bra F088F4` abort exactly once, at the end,
which is the normal exit from the final block rather than a fault.

### What this does and does not establish

It establishes that the chassis model now satisfies every behavioural
check the firmware knows how to make — several hundred assertions about
timer behaviour, VMOD/board-status bit relationships, XLTR register
round-tripping, chassis-window addressing and access denial.

It does not establish that the model matches the real FPS-3000. The
firmware only tests what its authors chose to test, and a wrong model
that happens to satisfy every test is still wrong. But it is a much
narrower gap than before, and it is the firmware's own definition of a
working chassis.

## Bus mastership: the SBC is the slave, and that explains the dead ends

Motorola's Table 1 lists among the **16 control outputs** at
`$1FFF0`/`$1FFF1`: *System Controller VERSAbus Transfer Request*,
*VERSAbus Block Transfer Request*, and *VERSAbus Resource Management (4)*
— and among the 12 status inputs, *VERSAbus Available*. Bus arbitration
lives in the same register pair this document has been decoding.

**The firmware never uses the upper half of it.** Every write to
`$1FFF0` puts `$00` in the high byte:

| write | `$1FFF0` | `$1FFF1` |
|---|---|---|
| `move.w #$0050` | `$00` | `$50` |
| `move.w #$00D0` | `$00` | `$D0` |
| `move.w #$0000` | `$00` | `$00` |
| the eight `F08E2E` pattern longs | `$00` in all eight | varies |

There is no bit operation on `$1FFF0` anywhere, and no byte write to it.
Every bit the firmware manipulates individually — 3, 5, 6, 7 — is in
`$1FFF1`.

So of Motorola's sixteen control outputs, this firmware drives at most
the low eight, and **never asserts a VERSAbus transfer request**. The SBC
does not take bus mastership for these transfers.

### What follows

The chassis is the master. That is consistent with, and explains, three
things established separately:

1. **`$10AA` and `$105E` are read but never written** by any executed
   code. If the chassis DMAs into SBC RAM as a bus master, that is
   exactly what the CPU's view looks like.
2. **No MMIO read ever consumes a host byte.** There is nothing for the
   CPU to consume — the data arrives in RAM by DMA.
3. **There is no CPU-observable "command complete" event**, which
   defeated two attempts at a smarter scripted chassis (`F04736`, then
   the `$FF000E` write). Of course there is not: the CPU is not driving
   the transfer. The chassis knows when it is finished because it is the
   one doing it. Both attempts were trying to infer completion from the
   reactive party.

The control flow is **chassis-driven with the SBC reactive**, not a
peer-to-peer handshake. A scripted chassis should therefore drive its own
schedule and treat the SBC's responses as acknowledgements, rather than
waiting for the SBC to signal readiness for the next step.

### Emulator divergence

`fps3k_sbc.c` models no bus arbitration at all — the CPU always owns the
bus and never stalls. Real hardware would hold the 68000 off (`BGACK`)
during chassis DMA cycles. Nothing measured here depends on that, since
no result is timing-sensitive, but it belongs on the "Known divergences"
list: any experiment that depends on *when* the CPU sees a DMA'd value
land will be wrong in the emulator, because in the model the value simply
appears between one instruction and the next.

## What a clean emulator boot actually proves

CLAUDE.md describes the emulator as booting "cleanly all the way through
MainInit's 16+ self-test phases, Phase2Init, RTOSKernelInit, and TDTI
task creation". The first clause is **false**, and the consequences run
through several other claims.

Measured over a plain boot to the RMS68K idle loop (6,975,885
instructions, final PC `F00FE6`):

| Device | Bus accesses |
|---|---|
| PTM | 81,100 |
| XLTR | **27** |
| BIM | 22 |
| VMOD_CTRL | 4 |
| AP I/F | **4** |
| BOARD_STATUS | **2** |

Of the 27 XLTR accesses, 22 are `RTOSKernelInit` stamping BIM vectors and
control registers. `$FF020C`, `$FF0214`, `$FF0218` and `$FF021A` are
touched **zero** times. The region `F08D00-F09BFF` — the whole diagnostic
suite — executes **zero instructions**.

### The gate

`F08732` is `btst.b #5,$F70019`, and `F0873A` branches past the entire
self-test sequence when that bit is **set**. Our chassis model returns
`$35` for that byte, and `$35` has bit 5 set. The tests are skipped by
construction.

### Why the gate was closed — a model bug, found by inference

The sequence around the gate is a **chassis handshake**:

```
F08720  $1FFF0 <- $0050        ; VMOD: $1FFF1 = $50, bits 4 and 6 set
F08728  wait until bit 4 of $F70019 is SET     ; chassis says ready
F08732  btst bit 5 of $F70019
F0873A  if SET -> skip the entire diagnostic suite
F0873E  $1FFF0 <- 0
F0874E  HardwareInit, then the tests
```

The SBC raises two VMOD lines, waits for the chassis to acknowledge on
bit 4, then samples bit 5 for the answer.

The emulator modelled **bit 5 of `$F70019` as tracking bit 6 of
`$1FFF1`**. That cannot be right. `$50` sets bit 6, so a direct mirror
makes bit 5 read back set every time, and the firmware always skips its
own diagnostics — leaving 3.8 KB of test code permanently dead. No ROM is
built that way.

**Bit 7 fits both uses of the signal.** The pre-test write `$50` has
bit 7 clear, so the tests run; the post-test write `$D0` at F087AA has
bit 7 set, and F088EE reads bit 5 to decide whether to advance to
Phase2Init. One signal, two samplings, consistent in both directions.

Changing the rule to bit 7 takes the diagnostic region from **0 to 109
distinct PCs executed**, and six tests now run that never ran before:

| MainInit call | Routine | Runs |
|---|---|---|
| F0874E | HardwareInit | yes |
| F0876A | F08C4A | yes |
| F08772 | F08D1A | yes |
| F0877A | RAMAddressingTest | yes |
| F08782 | F08DF8 (`BoardStatusPoll_3F11`) | yes |
| F08786 | PTMInit | yes |
| F0878E | F08E2E | entered, does not return |
| F08796 onward | F08F1C, F08F70, F0905A, F09518+ | not reached |

The next wall is inside F08E2E. Hook: `FPS3K_BSTAT19_B5` forces the bit
either way for experiments.

### `$10AA` cannot be written by this ROM after all — a retraction retracted

CLAUDE.md currently says:

> But "the value cannot come from this ROM", as an earlier revision of this
> file put it, is **wrong and retracted**. F053E2 writes `#$2` into a word
> array at `$10A0` indexed by `(d4-1)*2`, and index 6 lands exactly on
> `$10AA` — with `#$2` being precisely the value TCBIO1I dispatches on.

**The arithmetic is wrong, so the retraction is wrong, and the original claim
stands.** Decoding the host-command-1 handler exactly:

```
$F05384  cmpi.w  #1,d4              ; channel
$F05388  blt     -> error
$F0538A  cmp.w   $105E,d4
$F05390  ble     -> proceed         ; so 1 <= ch <= $105E
...
$F053CC  move.l  d4,d0
$F053CE  subq.l  #1,d0
$F053D0  lsl.l   #2,d0              ; (ch-1)*4
$F053DA  move.l  a2,$1080(a1)       ; longword array, stride 4
$F053DE  lsr.l   #1,d0              ; (ch-1)*2
$F053E2  move.w  #$2,$10A0(a1)      ; word array, stride 2
```

The `$10A0` array is indexed by `(ch-1)*2`, so:

| ch | address |
|---|---|
| 1 | `$10A0` |
| 2 | `$10A2` |
| 3 | `$10A4` |
| 4 | `$10A6` |
| 5 | `$10A8` |
| **6** | **`$10AA`** |

Reaching `$10AA` requires **channel 6**. "Index 6 lands exactly on `$10AA`" is
an off-by-two-entries slip: index 6 is `$10A6`, which is channel 4. `$10AA` is
index 10.

And channel 6 cannot pass the guard. `$105E` is the count of nonzero command
ports among **exactly four** probed at `$F0A202`, so `$105E ≤ 4` and
`cmp.w $105E,d4 / ble` rejects anything above 4. The handler can write
`$10A0`, `$10A2`, `$10A4` and `$10A6` and nothing else.

So the position returns to where it was two revisions ago, with a firmer
reason than it had then:

- `$F053E2` **cannot** write `$10AA` — not "does not in tested configurations",
  but is arithmetically barred by its own bounds check.
- A write watchpoint over a full boot catches only zeros at `$10AA-$10AD`,
  from the two bulk-clear routines at `$F0A1D2` and `$F0A33C`.
- Nothing else in the ROM references `$10AA` at all except TCBIO1I's read.

**Therefore a nonzero `$10AA` must come from off-board**, which puts the
chassis-as-bus-master reading back as the only candidate rather than one of
two. That matters for bring-up: it is a hard prediction that a bus trace can
check.

*This is the second time this session that a documented correction has turned
out to need correcting — the other being the `$FF0048` claim, where the
original was right in substance and my re-verification of it was wrong in
method. Both were caught by doing the arithmetic or the decode rather than
trusting a summary.*

### No panel command is issued during a clean boot

A whole boot writes `$FF000E` **exactly once**, and the value is `$AAAA` — a
self-test RAM pattern, not a panel code. **None of the 41 panel codes is ever
issued in normal operation**, and no directive-failure path (`$26D`-`$271`,
`$27E`-`$280`) executes.

So the entire panel-command apparatus — eight replicated issuer copies, 41
codes, the exception table, the `bra .` spins — is **dormant by design in a
healthy machine**. It is an error-and-command path, entered only when the
chassis asks for something or when something goes wrong.

That explains part of the 19% execution coverage recorded below, and it is
reassuring rather than alarming: a board that issues *any* panel command during
a quiet boot is telling you something. It also means the panel port doubles as
a fault beacon with a very low false-positive rate — Check 0b's exception codes
sit on a channel that is otherwise silent.

### RTOS directives `$29` and `$2A` are ASQ name-lookup and post

`$F05652`, the routine RDHC's command 1 calls with `'HXP1'`-`'HXP4'` in `d1`, uses
two of the five directives this document lists as *"RDHC's alone"* and records as
unmatched to any published Motorola name:

```
$F05652  move.l  a0,-(a7)
$F05654  move.w  #$2,-(a7)        \
$F05658  move.l  #$0,-(a7)         > a 10-byte parameter block on the stack
$F0565E  move.l  d1,-(a7)         /   {name, longword 0, word 2}
$F05660  movea.l a7,a0
$F05662  moveq   #$29,d0
$F05664  trap    #1               ; LOOK UP the queue by name -> handle in a0
$F05666  move.l  a0,$4(a7)        ; store the handle into the block
$F0566A  movea.l a7,a0
$F0566C  moveq   #$2A,d0
$F0566E  trap    #1               ; POST to it
$F05670  lea     $a(a7),a7        ; discard the block
```

**`$29` resolves an ASQ name to a handle, returned in `a0`; `$2A` posts to that
handle.** Two of the fourteen unidentified directives now have meanings, and they
are the pair that makes RDHC a dispatcher.

And the parameter block is **`{4-byte name, longword, word}` — exactly the 10-byte
ASQ descriptor layout found at the base of every task's block at `TCB+$138`**. The
in-RAM descriptor and the directive's argument block are the same structure, which
is why the descriptors are 10 bytes and why `!ASQ` never needed a tag: the kernel
addresses them by name through `$29`, not by scanning for a marker.

### The S2/S3 address handler, and a third copy of the offset rule

`$F055FC` selects address width from `d4` and rejects anything else:

```
$F055FC  cmpi.w  #$2,d4 / beq -> d5 = $0000     ; one address word
$F05608  cmpi.w  #$3,d4 / beq -> d5 = $0010     ; two address words
$F05614  move.w  #$260,d0 / jsr PanelIOConfigure / rts   ; neither -> reject
$F05620  a1 = 0
$F05626  read word, shift left by d5, accumulate into a1, d5 -= $10, repeat
$F05640  adda.l  #$10000,a1                     ; the staging base
$F05646  move.l  a1,$0E7E                       ; store the resolved address
```

So `d5` is the same shift-count mechanism as the S1 handler, and this is a **third
implementation of the `+$10000` staging offset** — after `$F051A2` and `$F055A2`.
Unlike the other two it does not store data; it resolves an address into `$E7E` for
a later transfer, and it is the site that rejects an unsupported record type with
panel `$260`.

*Three independent implementations of the same offset arithmetic, in three code
paths written for three record classes, is about as strong as static evidence for
that rule gets without hardware.*

### The last six helpers — the self-test is now documented end to end (42/42)

| routine | calls | what it is |
|---|---|---|
| `$F08970` | 4 | **byte-pattern generator** — `not/rol/not/rol` on `(a5)`, OR the counter at `$4(a5)`, increment it |
| `$F08958` | 1 | calls the generator four times, storing via `move.b d0,(a5)+` — a **4-byte pattern** |
| `$F089EE` | 3 | **error-gated longword access test** — see below; "chassis handshake probe" was wrong |
| `$F090EA` | 2 | **PTM configuration** — `movep.w #$fff` into all three timer latches, then `CR2 <- 0`, `CR1 <- $C2` |
| `$F094AE` | 3 | interrupt-level request — `andi.w #$fff8,(a5)`, `bset #7`, `ori.w #$1,(a5)` |
| `$F09A7E` | 1 | **DRAM retention/refresh test** — see below; "final sub-test prologue" was near-contentless |

Two of these close open questions.

**`$F08970` explains `$1FFF4`.** The generator reads a byte, applies `not.b / rol.b #1 /
not.b / rol.b #1`, ORs in a counter held at `$4(a5)` and increments it. With `a5 = $1FFF0`
that counter is **`$1FFF4`** — the location flagged earlier as "read and incremented, unlike
its write-only neighbours". It is the pattern generator's sequence counter: **ordinary RAM,
exactly as its treatment by the address-line walker implied.** The one address whose
behaviour did not fit the register hypothesis turns out to have a mundane and complete
explanation, which is the outcome that should have been expected once the walker evidence
came in.

**`$F094AE` independently corroborates the interrupt-level field.** Its first instruction is
`andi.w #$fff8,(a5)` — masking off exactly **bits 0-2** of the word at `$1FFF0` — followed by
`ori.w #$1,(a5)` to request level 1. That is the canonical "clear the level, then set one"
idiom, and it was reached from a different stage (`$1400`) than the walk that established the
field (`$1300`). *Two stages, written independently, agree that bits 0-2 are a 3-bit level
field* — which is a stronger form of confirmation than the exhaustive 1..7 walk alone,
because it shows the rest of the firmware treating the field the same way.

**Self-test documentation is now complete**: all **42** subroutines called from
`$F08700-$F09C00` are accounted for, against **3** when this thread began. Every stage of
every sequence has a decoded purpose, and each is tied to the board or device it exercises —
which was the request that started this work.

### Auditing the harness: a stale check that outlived the defect it described

Fixing three brittle checks prompted an audit of the rest, and it found a worse one.

**A check asserting a defect that had been fixed.** `check('the emulator does NOT model
dual-8-bit, so its tick is 27% slow', ...)` was still present and still **passing**, hours
after the dual-8-bit fix. It passed because its condition — that `counter[t] = p->latch[t]`
appears in `mc6840.c` — remains true: the fix kept the 16-bit reload as the *else* branch.
**The condition held while the name had become false.**

That is the second time this session a check outlived its claim; the first asserted the
retracted `$0E74` mailbox reading and likewise passed. Both are more dangerous than a failing
check, because a green suite reads as confirmation of every name in it.

**The audit also classified the 20 source-string assertions**, which fall into two kinds that a
reader cannot distinguish from a failure message:

| kind | examples | what a failure means |
|---|---|---|
| **code structure** | `#define APIF_END 0xFF0100`, `((addr - 0xFF0040) >> 5) + 1`, `panel_resp_code = sc;` | the model changed; a documented claim may no longer hold |
| **comment presence** | `"does NOT reliably isolate the reply"`, `"Gate on boot completion"` | a recorded **caveat was deleted** — worth knowing, not a regression |

Both are legitimate; conflating them is not. The harness now says so in a header note, so a
future failure is read correctly rather than investigated as a machine change.

**And the removed kind.** Three checks asserted that two strings appeared within *N characters*
of each other in a source file. Those tested the file's formatting: any comment inserted between
them — and this session added many — breaks them without anything about the emulator changing.
*A proxy that correlates with the property you want is fine until you edit the thing the proxy
measures.*

The pattern across all of this is the session's recurring one, one level up: **the harness is
itself a detector, and detectors need the same scrutiny as the findings they guard.** Nothing
here changed what is known about the machine; it changed how much a passing suite is worth.

### TRAP #0 decoded: a 35-entry jump table, and user-mode calls are silently ignored

The TRAP #0 handler at `$F001AC` (vector 32) decodes completely in a dozen instructions, and
gives two results.

```
$F001AC:  move.w (a7),-(a7)          ; duplicate the stacked SR
$F001AE:  andi.b #$7f,(a7)           ; mask the system byte, clearing T
$F001B2:  addq.l #2,a7
$F001B4:  bne    $F001B8
$F001B6:  rte                        ; <-- masked byte ZERO: return immediately
$F001B8:  lsl.l  #2,d0               ; d0 * 4 -- the index
$F001BA:  bmi    $F00182             ; negative -> error
$F001BE:  addi.l #$f001d6,d0         ; + TABLE BASE
$F001C4:  cmpi.l #$f00262,d0         ; vs TABLE END
$F001CA:  bge    $F00182             ; out of range -> error
$F001CE:  exg    d0,a0
$F001D0:  move.l (a0),-(a7)          ; push the handler address
$F001D2:  exg    d0,a0
$F001D4:  rts                        ; "return" into it -- the dispatch
```

**1. There are 35 directives, not 37.** The table runs `$F001D6`-`$F00262` = `$8C` bytes = **35
longword entries**, and the range check `cmpi.l #$F00262 / bge` admits exactly `d0 < 35`. This
project records *"TRAP #0 with directive in D0 (37 internal directives)"* — a number presumably
taken from Motorola's documentation for some RMS68K revision. **This build has 35.** Entry 0 is
`$F00182`, the same address the error paths branch to, so directive 0 is invalid and the usable
range is 1..34.

**2. TRAP #0 from user mode is silently ignored.** The handler masks the stacked SR's system byte
with `$7F` — clearing the trace bit — and **`rte`s immediately if the result is zero**. A zero
system byte means S=0 and IPL=0: user mode, no interrupt mask. So a user task issuing TRAP #0
gets no error, no directive, and no indication — just a return.

*That is the mechanism behind an observation this project made from counting.* The record notes
TRAP #0 *"has 12 sites, all in the kernel, RTOS-init or pre-task code and **never in a task**"*,
which was a statistical fact about where the instruction appears. **The handler enforces it**: a
task could issue TRAP #0 and it would do nothing. The executive interface is supervisor-only by
construction, and TRAP #1 — with its 71 sites all inside task regions — is the user interface.

The dispatch idiom is worth noting too: `move.l (a0),-(a7)` then `rts`, using the return-stack as
an indirect jump. That is a 68000 pattern with no `jmp (a0)` involved, and a disassembler
following control flow linearly will lose the thread at the `rts` — which is one reason the
kernel region resists automatic analysis and has stayed 26% of the image with no per-routine
documentation.

### ARITH card: three FP units confirmed, but the packages are UNMARKED

The AU card yields a clear architectural picture and one firm negative.

**Three large square packages**, gold-lidded **leadless chip carriers in sockets**, at board
positions around N/P (two) and U/V (one). **Three is exactly Hockney's "1 multiplier + 2
adders"** for the XP-32 arithmetic unit, so the count corroborates the documented architecture
independently.

**But they cannot be identified from the photograph.** Zooming to native resolution shows a
**blank gold lid** — no part number, no manufacturer mark, only a **date code `8541`** (week 41,
1985) on the package edge. The marking, if any, is on a face the photograph does not see.

That matters because this project carries a specific hypothesis: the HPVP uses "Am29116 +
Weitek WTL 1032/1033", and CLAUDE.md notes *"the same pairing Hockney attributes to the XP-32"*.
A 68-pin LCC is the WTL 1032/1033 package, and the date code fits — **but a blank lid is not
evidence for a part number.** The identification stays open, and confirming it needs the board
or a photograph from a different angle. *Recording this as a negative rather than a
near-confirmation is the point: "consistent with" is how a hypothesis survives without being
tested.*

**What the card does establish:**

| part | significance |
|---|---|
| **`AM29540DC`** | AMD's **programmable FFT address sequencer** — a purpose-built FFT part, which fits XPMLIB's `ZRFFT` routines exactly |
| **`AM2910ADC`** | a **second** microprogram sequencer — the AU is separately microprogrammed from the EU |
| **`AM2168-45PCB`** array | the large SRAM bank — the AU's writable control store and data pads |
| `CY7C168-45PC` | further SRAM |
| **four ribbon connectors** | along the top edge — the XP32 bus links |
| `29F52 SDC` PALs, `L29C520PC-R` PLDs | decode logic, as on the EXEC card |

**The `AM29540` is the most informative of these.** It is not general-purpose logic — it is a
dedicated FFT address generator, and its presence says the AU was designed with FFT as a
first-class workload rather than as library code layered on generic hardware. That is consistent
with the FPS product line, where FFT timings were the headline benchmark.

**And the second Am2910 matters for the emulation model.** With one on the EXEC card and one
here, the EU and AU each have their own microprogram sequencer — so they are two independently
sequenced engines that synchronise, not one engine driving the other. Any future model of the
XP-32 needs two control stores and two sequencers, not a master-slave pair.

### The EU store looks like ONE 80-bit word: ~10 PROMs in the `225-0600` series

Reading the second white-label column at full resolution finds **approximately ten**
white-labelled DIPs in a **`225-0600-0NN`** series — a different series from the five
`225-0071-00N` parts in the centre column — with the **AMD arrow logo** visible on several,
which makes them bipolar PROMs rather than the `29F52` PALs.

**Ten PROMs is an exact fit for the documented word width:**

| if the PROMs are | devices needed for 80 bits |
|---|---|
| 4 bits wide | 20 |
| **8 bits wide** | **10** |

Hockney gives the EU program store as **2K x 80**. Ten 8-bit devices give exactly 80 bits, and
the Am2910 found on the same card is the sequencer that addresses them.

**That bears directly on the question this project could not settle.** The record asks whether
the two Am29116s "divide the 80-bit word: two 16-bit instruction fields, or one field plus a
cascade link, or independent sequencing", and notes it *"has to be settled before an EU PROM
dump can be assembled, because it decides whether a dump holds one instruction stream or two."*

**A single 80-bit store addressed by a single Am2910 is one instruction stream**, with the word
divided between the two processors — not two independent streams. Two streams would need two
sequencers or a partitioned store, and the card shows one sequencer and one PROM bank of the
right width. *So a dump would hold one stream, and the assembly order is the PROM order.*

**RECOUNTED AND CONFIRMED: exactly ten.** Cropping the column tightly and splitting it in two
gives an unambiguous tally — **seven** complete devices in the upper half, **one** straddling the
split, and **two** below the interrupting `74F245N`. Ten. At that magnification the package is
also legible: **24-pin DIPs carrying the AMD arrow logo**, the form factor of AMD's 2K x 8
bipolar PROMs. So `10 x 8 = 80` is a **counted** fit, not an estimated one, and the `74F245N`
mid-column is an output buffer — where one would expect it. The five `225-0071-00N` parts remain
a separate group whose function is unidentified.

*The caveat that remains is the right one to be left with:* the individual handwritten labels are
still illegible, so the **order** of the devices within the word is unknown. A dump can be
assembled in board order and the bit-lane assignment corrected afterwards — a tractable problem,
where a wrong device count would not have been.

*This is as far as photographs can take the EU.* The next step is a physical dump, and the
finding that matters for planning one is that it should be read as **ten 8-bit devices forming a
single 80-bit word**, in board order, rather than as two independent streams.

### RETRACTION: there IS an Am2910 microprogram sequencer on the EXEC card

Reading the left column of the EXEC card at full resolution finds **`AM2910ADC 8506GM`** —
AMD's 12-bit **microprogram address sequencer**, the canonical bit-slice control part — at board
position V/W, directly below the PAL bank.

**That retracts a caution this project has carried as settled.** The record reads:

> *"Note the terminology: this is a fixed-instruction-set 16-bit processor, **not** a
> microprogram sequencer in the Am2910 / ADSP-1401 bit-slice sense. Calling it a 'sequencer'
> implies a next-address generator driving a wide microword, which is the wrong mental model
> for how the EU is controlled."*

The first half is right and stands: an **Am29116 is not a sequencer**, and earlier revisions
calling it one were wrong. **The second half does not follow, and is false.** A next-address
generator driving a wide microword is not the wrong model — it is what the card contains. The
EU is an ordinary microprogrammed bit-slice engine:

| element | part | role |
|---|---|---|
| **sequencer** | **`AM2910ADC`** | generates the next microcode address |
| **control store** | the `225-0071-00N` PROMs | the 80-bit microword |
| **datapath** | **2 x `AM29116DCB`** | the 16-bit processors the microword drives |

*The error is instructive.* Correcting a wrong label ("the Am29116 is a sequencer") produced an
over-correction ("therefore the sequencer model is wrong"), and the over-correction was stated
more confidently than the original mistake. **This is the same shape as the `ROMChecksumTest`
case**, where renaming a misnamed routine led to concluding no such test existed anywhere — and
one did, 200 bytes away. Twice now, fixing a name has discarded a true belief attached to it.

**Also counted on this strip:** exactly **nine `29F52 SDC 8617 SINGAPORE`** PALs in the left
column — the first hard count of that group — alongside a second column of white-labelled parts
whose visible suffixes (`-024`, `-027`) do **not** match the `225-0071-00N` PROM series, so they
are a third distinct group. Plus `74F245`, `MC74F244NDS`, `P8287-B`, a red **Grayhill DIP
switch**, and `74F86`.

*What this does for the EU PROM question:* it makes the count more tractable, not less. With an
Am2910 sequencing them, the PROMs form one addressed store, and the two Am29116s are fed from
it — so the "one instruction stream or two" question becomes "how wide is the word the Am2910
addresses", which a full PROM count answers directly.

### EXEC card survey: the EU PROM count is partial, and that limitation is the finding

CLAUDE.md carries a TBD directly on the EU: *"Bipolar PROMs on the EXEC card — these are the
fixed EU program store (Hockney's 2K x 80). Concrete chip count and width split TBD"*, and notes
that the split *"has to be settled before an EU PROM dump can be assembled, because it decides
whether a dump holds one instruction stream or two."*

**What the photograph establishes:**

| part | where | note |
|---|---|---|
| **`AM29116DCB 8443EPT`** | centre-right | the EU controller, in ceramic — one visible in this band |
| **`AM2168-45PCB`** | large array, centre-left | 4K x 4 SRAM — **the AU writable control store** |
| **`29F52 SDC 8617 SINGAPORE`** | many, left side | the **PALs** this project identifies, in quantity |
| **`225-0071-00N`** white-labelled | one column, **exactly 5** | the EU PROMs, `-002` through `-007` seen |
| `L29C520PC-R` x2, `AM2984IDC`, `AM29823DC-8` | scattered | PLD and AMD support logic |
| `DL14CB300`, `STTLDFMM-145` | centre | **delay lines** — 300 and 145 ns |
| `SN74S381N` | centre | a 4-bit ALU, on the EXEC card |

**What it does not establish, and why that matters.** I read **one column of five PROMs**. The
overview strip shows **further columns of white-labelled parts** at the far left and at roughly
one-eighth across, which may be more PROMs or may be more PALs — the two are visually identical
at this resolution, both being white-labelled DIPs, and CLAUDE.md already records one occasion
when *"the white-labelled chips earlier mistaken for EU PROMs are PALs"*.

So the count remains open, and the arithmetic is why it matters:

| if the PROMs are | 80 bits needs | five would be |
|---|---|---|
| 8 bits wide | **10** devices | half the word — implying a second bank |
| 4 bits wide | **20** devices | a quarter |

**A second bank of five would be the interesting answer**, because the EXEC card carries *two*
Am29116s and 2 x 40 bits is the natural split for two independent instruction streams — which is
precisely the question a PROM dump has to answer before it can be assembled. *I am not claiming
that; I am recording that the observation which would settle it is one careful count away, and
that distinguishing PROMs from PALs by eye at this resolution is exactly the error this project
has made before.*

The remaining work is mechanical: tile the left third of `05_XP32_EXEC.JPG` at full resolution
and read every white label. That is a better use of the photographs than anything else currently
outstanding, because it converts a hardware TBD into a number.

### UNIV FMT carries ALUs and shifters — it is a FORMAT converter, not a width converter

The UNIV FMT card's role is recorded as unestablished: *"Whether it also does 16-to-32-bit width
conversion, WCS write-port fan-out, or DEC F-floating to IEEE-754 for a DEC host is still
unestablished."* One tile of `03_UNIV_FMT.JPG` narrows it sharply.

| part | count seen | function |
|---|---|---|
| **`74S181N`** | **2** | **4-bit ALU / function generator** |
| **`74F350`** | 4+ | **4-bit shifter** |
| `MC74F153N` | 6+ | 4-to-1 multiplexer |
| `74F257`, `74F157` | 3+ | 2-to-1 multiplexers |
| `SN74S251N` | 1 | 8-to-1 multiplexer |
| `SN74LS240/244` | many | buffers |
| FPS PROMs `225-1000-013/-014` | 2 | white-labelled control store |

**The ALUs are the discriminator.** Width conversion needs multiplexers and latches; WCS
fan-out needs buffers. **Neither needs arithmetic.** A card carrying two 4-bit ALUs *and* an
array of 4-bit shifters is doing something that requires adding and shifting — which for a card
named "UNIV FMT 32 BIT IEEE" means **floating-point format conversion**:

- **shifters** → mantissa alignment and normalisation
- **ALUs** → **exponent arithmetic**, i.e. bias adjustment
- **multiplexers** → field extraction and reassembly

That is the entire recipe for converting between two float formats, and it is not the recipe for
anything else on the candidate list.

**It also fits the specific hypothesis.** DEC F-floating and IEEE-754 single differ in exponent
bias (128 vs 127) and in mantissa/hidden-bit convention — a bias add and a one-bit shift, which
is exactly what an ALU plus a shifter provides. The card's own FPS description names IEEE as one
side; a DEC host would supply the other.

**Stated with its limits.** This identifies the *class* of operation from the parts, not the
specific conversion. Two 4-bit ALUs give 8 bits of arithmetic width — enough for an 8-bit IEEE
exponent, which is suggestive but not proof. Confirming the format pair needs the schematic or a
data trace across the card, neither of which exists. What can be said is that **"width
conversion" and "fan-out" are now the weakest of the three candidates, and the arithmetic
hardware is the reason.**

*This complements rather than contradicts the `$1900` finding.* That phase demonstrated a
**16-to-32-bit width mux** with `$FF0214` as the low-half latch — but noted explicitly that the
SBC sees only the XLTR's registers and "whether the mux sits on the XLTR or further down the
path is not observable from here". The width mux and the format converter can both exist; the
photograph says the FMT card is doing arithmetic, which the width mux does not require.

### The vector-table overrun was a TWO-BIM artefact — correcting the count removed it

Verifying the three-BIM change turned up a behavioural difference worth more than the change
itself. The harness carries a check that the `$281` deadlock configuration "overruns the stack
into the vector table". Measured both ways, post-boot vector writes over 300 M cycles:

| BIM count | post-boot vector writes |
|---|---|
| **2** (the old default) | **730** — the overrun |
| **3** (the card's actual complement) | **1** |

**The interrupt storm was caused by our own misconfiguration.** Telling a three-BIM card that it
has two produces a re-entrant interrupt condition that walks the stack through the exception
vector table; modelling the hardware correctly removes it entirely.

*That matters beyond tidiness, because this project already has a retracted finding whose root
cause was that storm.* The record reads:

> *A **retracted** earlier claim: that the handshake was "closed" and `$FF0048` read. That
> reading came from an interrupt-storm artefact — a re-entrant ISR walked the stack through the
> vector table, overwrote vector `$128` with `$00FF0000`, and the resulting instruction fetch
> from `$FF0048` was misread as a data access.*

So a wrong conclusion was drawn from a storm, the storm was correctly identified as an artefact,
and the artefact has now been traced to its cause: **the emulator was modelling two BIMs where
three are fitted.** The retraction was right; what it could not say was *why* the machine was
behaving pathologically.

**The check is now split into both halves** — the storm under `FPS3K_BIMS=2`, and its absence
under the correct default — so the phenomenon stays documented while the default asserts the
healthy behaviour. Keeping only the second would lose a real finding about what a wrong BIM
count does.

*A general point this makes concrete:* a modelling error does not always show up as a wrong
value. Here it showed up as **an entire pathological behaviour** that looked like a property of
the firmware, was investigated as one, and produced a published claim that had to be withdrawn.
**Misconfiguration is a source of phantom findings, not merely of missing ones.**

### THE MONITOR WORKED ON REAL HARDWARE (2026-07-30)

The owner reports the monitor running on the machine. That closes the project's principal open
question and resolves all three "open hardware unknowns" at once — none of which needed the
scope measurement that was planned for them:

| unknown | resolved by the machine running |
|---|---|
| is the µPD7201 populated and clocked? | **yes** — it could not have talked otherwise |
| which of sixteen baud straps is set? | **the one burned for** |
| is RXC/TXC on the on-board BRG? | **yes** — no external clock was supplied |

**The SBC photograph corroborates the hardware side**: `MC1488P` x3 (RS-232 line **drivers**)
and `MC1489AP` x2 (**receivers**) are physically fitted, with jumper blocks `J21`-`J24` shunted
and two DIP-switch banks `J25`/`J26` set — the strap configuration the baud rate comes from.

**What the success validates, retroactively.** Each of these was a *diagnosed defect with a
mechanism*, not a guess, and the first burn failed on them:

- the SIO decode being **odd-byte and function-grouped** — `$F70011`/`$F70015`, where the first
  attempt used `$F70010`/`$F70012` and `$F70013` is channel **B** data;
- `cold_init` filling **all 256 exception vectors** before any I/O, since on a 68000 the table
  is DRAM and garbage at power-on — BERR plus a junk vector is a double fault and a halt;
- the group-0 frame stub, the `MON_NEST` re-entry guard, and `g` refusing non-resumable frames;
- `patch_rom.py` **recomputing the ROM checksum word**.

*That last item is worth dwelling on.* It was added as prudence — the stock image XORs to zero
and every monitor image before 2026-07-29 broke that. This session found the reason it is
**necessary**: self-test phase `$300` at `$F08D1A` XOR-accumulates the entire ROM and **retries
forever** on mismatch, so an image that boots the stock path with a broken checksum never
starts, silently. The claim recorded for three days — *"patching the ROM cannot fail a
self-test, because no such test exists"* — was wrong, and the hardware would have demonstrated
it.

**What this does not tell us**, and worth stating rather than assuming: which image was burned
(`--reset` bypasses the checksum path; `panic_only` does not), and therefore whether the
checksum fix was load-bearing on this particular attempt or merely correct. The distinction
matters for anyone reproducing it.

### The emulator now models three BIMs — and bit 4 is a ONE-SHOT, not a strap

Acting on the photograph, `$FF0218` bit 4 now reads set by default. The first attempt —
modelling it as a **static** presence strap — **broke the boot**, and the failure was
diagnostic rather than annoying.

**Phase `$1600` requires bit 4 in *both* states.** It reads the register at entry and tests bit
4 to choose a 16- or 24-register BIM walk; then it writes `$400` and requires the register to
read back `$400` under mask **`$0610`** — bits 4, 9, 10 — i.e. **bit 4 clear**. A permanently-set
bit 4 fails that readback, and the stage retries forever: measured `$F09574` executing
**3,055,728** times and the `$F095E8` fail path **127,321**.

So bit 4 is a **one-shot presence flag**: set at reset, **cleared by the `$400` arm write**. The
firmware's own two uses of the same bit, four instructions apart, pin the semantics exactly —
and a static strap is ruled out by the machine refusing to boot with one.

**Modelled that way, everything works:**

| | before | after |
|---|---|---|
| self-test `$1A00` / sequence C | 1 / 1 | **1 / 1** |
| RTOS idle loop | 538,560 | **538,560** |
| BIM registers touched | 16 of 24 | **24 of 24** |
| **`$FF025E`** (BIM2 VR3) | **never** | **touched** |
| **default RAM digest** | `f72fb0a5…` | **`f72fb0a5…` — unchanged** |

**Zero bytes of post-boot RAM differ.** The BIM walk writes device registers, not memory, and
the self-test's outcome is identical either way — so this is a correctness improvement with no
golden-master churn, and no digest update to justify.

That retires the last piece of the `$FF025E` puzzle. It was never an asymmetry in the firmware,
nor a quirk of the card: **the walk stopped one BIM short because the model said two BIMs were
fitted, and three are.** `FPS3K_BIMS=2` restores the old behaviour for comparison.

*The sequence here is worth noting:* firmware analysis produced a binary question it could not
answer (`$D0` or `$D8`?); a photograph answered it; implementing the answer failed; and the
failure specified the mechanism more precisely than either source alone. **The wrong
implementation was more informative than the right guess would have been.**

### SETTLED: three MC68153P BIMs are physically fitted — the emulator models two

The fifth XLTR tile finds them, unambiguously: **three `MC68153P` chips** (Motorola, date code
8626A), stacked vertically in board positions F/G, H/J and K/L, with a resistor pack `R25` and
**jumper blocks `E2` and `E3`** immediately beside them.

**That closes a question this project raised from the firmware side and could not answer.**
Phase `$1600` reads `$FF0218` bit 4 and walks either 16 or 24 BIM registers accordingly:

| bit 4 | walk | machine |
|---|---|---|
| clear | `$FF0230`-`$FF024E`, 16 registers | **2 BIMs** — what the emulator presents |
| **set** | `$FF0230`-`$FF025E`, 24 registers | **3 BIMs** — **what the card actually has** |

**The hardware is a three-BIM card and the model presents a two-BIM one.** That is now a
demonstrated misconfiguration rather than "a defensible choice that should be stated": the card
list says "V-BUS XLTR 3 BIMS", the photograph shows three, and the firmware has a code path for
exactly that case which never executes.

**Concrete consequences:**

- The emulator should set **`$FF0218` bit 4**. Phase `$1600` would then walk all 24 registers.
- **`$FF025E` would stop being anomalous.** This project records "23 of the 24 are used; only
  `$FF025E` (BIM2 VR3) is never touched" — an asymmetry that had no explanation until the bit-4
  finding, and now has none left at all: it is untouched *because we configure a two-BIM
  chassis*, and on the real card it is the third BIM's last vector register.
- Any experiment relying on BIM2 is currently running against absent hardware.

**And the jumper blocks are suggestive.** `E2` shows four jumper positions (`1-2`, `3-4`, `5-6`,
`7-8`) directly beside the third BIM, with one position appearing bridged. A strap next to the
third interrupter is exactly where a "third BIM present" configuration bit would come from — and
`$FF0218` bit 4 is read, not written, by the firmware. *That is a hypothesis the photograph
suggests rather than proves*; tracing the strap needs the board, not a picture of it.

Also on this tile: white-labelled FPS PROMs `225-0069-001` and `225-0070`, and more green-wire
rework.

### `MC26S10` on the XLTR: physical evidence for the arbitration the emulator omits

A fourth XLTR tile finds parts that bear directly on a documented emulator gap:

| part | function |
|---|---|
| **`MC26S10P`** x2 | Motorola **quad open-collector bus transceiver with arbitration** — the classic VERSAbus/Multibus daisy-chained request/grant part |
| `AM25LS2521PC` | 8-bit comparator — address match, the usual bus-interface decode |
| `74S240`, `74LS244`, `7417` | buffers |

**The `MC26S10` matters.** This project's known-divergences table opens with:

> *"No VERSAbus arbitration; the CPU always owns the bus — the chassis is a **bus master**, it
> DMAs into SBC RAM and holds the 68000 off during those cycles."*

That was inferred from firmware behaviour and from the `$10AA` puzzle. **The photograph shows
the hardware that does it**: open-collector arbitration transceivers are used for exactly one
thing — resolving which of several masters owns the bus — and there are at least two of them on
the translator card, adjacent to an 8-bit address comparator.

So the divergence is not a modelling shortcut around something hypothetical. **The arbitration
logic is physically present, identifiable, and on the card that mediates between the SBC's
VERSAbus and the chassis.** Anything that depends on *when* a DMA'd value lands remains wrong in
the model, and now there is a part number attached to why.

*Still not found: the MC68153 BIMs.* Four of twelve tiles examined. What has turned up instead —
bus transceivers, arbitration transceivers, comparators, registers, buffers, a delay line — is a
coherent picture of a **bus translator**: the card's job is moving cycles between two buses and
arbitrating for them. The interrupter half is presumably there (23 of its 24 registers are
written by the firmware, which is not something one does to absent hardware) but has not been
photographed yet.

### XLTR card photograph: part number confirmed, BIM count NOT yet settled

Tiling `02_VBUS_XLTR.JPG` and examining three of twelve tiles establishes some things and
leaves the interesting question open.

**Confirmed:**

| finding | |
|---|---|
| **`PN 612-4803-400 REV G`** | matches the card list exactly, **including the revision** |
| `AM2927DCB` x4+ | AMD quad three-state bus transceivers, at the `PB` VERSAbus edge |
| `AM29823DC` x2+ | 9-bit registers |
| **`PE-21199 100NS`** | an FPS-labelled **100 ns delay line** — a timing element |
| `AMP 53137-5` | connector component |
| a ribbon-cable header | the XLTR carries one too, not only the AP I/F |
| **extensive green-wire rework** | far more than the AP I/F card, across the whole board |

The part-number match is worth having on its own: the card list came from the machine's owner,
and the photograph independently confirms both the number and revision G.

**Not settled: how many BIMs are physically fitted.** The card is described as "V-BUS XLTR **3
BIMS**", and the firmware analysis raised a real question about this — `$FF0218` bit 4 selects a
walk over **16 or 24 BIM registers**, i.e. two or three MC68153s, and our chassis model reads
that bit clear, presenting a two-BIM machine. A photograph could settle which is physically
present.

**I have not found them.** Three tiles examined, no MC68153 visible. The parts seen so far are
bus transceivers, buffers and registers — consistent with the XLTR's translator role but not
the interrupter half. Nine tiles remain, and the BIMs are 20-pin DIPs that could be anywhere on
a board this dense.

*Recording the negative deliberately.* It would be easy to leave this out and mention only the
confirmations, but the BIM count is the question worth answering here and a partial search that
found nothing is a real result about where not to look. The remaining tiles are cheap; this is
an unfinished search, not a failed one.

### The differential host link is on the AP I/F card: MC3487 drivers, MC3486 receivers

The SIO is genuinely untouched by the firmware — but that is not the only serial-class interface
on the machine. Examining the AP I/F card photograph (`refs/FPS-3000/cards/04_APIF.JPG`,
6000x4000, tiled 4x3 to stay under the vision cap) finds the differential hardware:

| part | function |
|---|---|
| **MC3487P** | Motorola **quad differential line DRIVER** (RS-422/423) — the AM26LS31 equivalent |
| **MC3486P** | Motorola **quad differential line RECEIVER** (RS-422) — the AM26LS32 equivalent |

**At least two of each**, and their placement is the confirming detail: they sit immediately
above the **`PA`** and **`PB`** edge connectors — one driver/receiver pair per connector — with
termination resistor packs (`R8`, `R9`, `R29`, `R30`-`R35`) alongside. That is exactly the
layout of a differential interface terminated at the board edge.

**This is the host link.** The card description already records that the AP I/F "drives two
large ribbon cables that went to a counterpart card in the host chassis"; `PA` and `PB` are
those two connectors, and the signalling across them is **RS-422 differential**, not
single-ended TTL. That answers how a 32-bit-wide interface ran reliably over metres of ribbon
to another chassis — differential pairs at RS-422 rates, which single-ended TTL could not do.

Other parts identified on the same card, none previously recorded:

- **`AM29705DCB`** — the 16x4 dual-port SRAM the card's 32-bit width is built from (this
  project documents eight of them; one is directly visible)
- **`P8287-B`** — an octal bus transceiver
- white-labelled **FPS PROMs** with hand-written part numbers (`225-0057-001`, `225-0041-002`,
  `225-0041-003`, `225-0041-004`)
- a **hand-wired green-wire modification** near a 74S02 — a factory or field rework
- part number **`612-4448-401`**, matching the card list

**Why the firmware cannot show any of this.** Every device the ROM touches is now mapped, and
there is no unaccounted block — so the differential layer is *below* the AP I/F register
interface, not beside it. The SBC writes `$FF0008`/`$FF000E` and the card converts that to
differential signalling on `PA`/`PB` without the firmware knowing. **The two host paths are
therefore not comparable**: the SIO is a serial port the firmware never uses, while the AP I/F
*is* the host link and its differential nature is invisible from the bus side.

*This is the class of finding the ROM structurally cannot produce* — the same class as the
EU↔AU interface, UNIV FMT and MEM CTL internals. Photographs are the only source, and in this
case they were decisive.

### VERIFIED: the firmware never touches the SIO — checked three ways, including the near-miss

"The FPS firmware never initialises or accesses the µPD7201" is load-bearing: the monitor
co-opts that chip, and the whole serial-host plan rests on it being free. After a session in
which several "never accessed" claims collapsed, it deserved re-checking rather than
inheriting.

**Three independent checks, all negative:**

| check | result |
|---|---|
| `tools/refs.py` on all eight SIO registers (`$F70010`-`$F70017`) | **0 references** |
| absolute-long operands into that range, whole ROM incl. kernel | **0** |
| **displacements off a base holding the PTM address** | **0 reach it** |

The third is the one that mattered, and it was a genuine near-miss. **The PTM base is
`$F70001`, so `$10(a0)` would land on `$F70011` — the SIO channel-A data register.** A single
displacement past the PTM's own registers crosses into the serial chip. Tracking which
displacements are actually used while a base holds the PTM address:

```
+$02 -> $F70003     +$04 -> $F70005     +$08 -> $F70009     +$0C -> $F7000D
```

**The highest address reached from the PTM base is `$F7000D`** — the T3 MSB register, the last
register of the PTM. The firmware stops exactly at the device boundary and never steps past it.
That is a much stronger statement than "no absolute references exist", because it rules out the
one form that could plausibly have hidden an access.

*Worth being clear about what the SIO is and is not here.* The board has **two** host paths and
they are not alternatives to each other:

| path | used by |
|---|---|
| **AP I/F** `$FF0000` + the XLTR/chassis protocol | **the firmware** — S-records, `EXPUT`/`EXGET`, the whole documented host link |
| **µPD7201 SIO** `$F70011`-`$F70017` | **nothing in this ROM** — which is exactly why the monitor can have it |

So the firmware's host communication is entirely through the AP I/F; the serial port is
physically present, wired to P2 pins 73/75, and completely unused by the shipped firmware. Both
facts now rest on measurement rather than on an earlier reading.

*(Separately, the `FPS3K_CHSEL_RD`/`FPS3K_SEQ` conflict warning is also slightly overstated but
substantially right: with both set, CHANNEL_SELECT reads returned the scripted value 723,796
times and the `CHSEL_RD` value **4** times — before the sequence takes its first code. Unlike
the `FPS3K_RESP` case, `seq_cur` is never reset, so once the sequence starts `CHSEL_RD` is
permanently unreachable.)*

### A warning that overstated its case: `FPS3K_RESP` is NOT ignored when `FPS3K_SEQ` is set

Running the write-once experiment surfaced this warning:

```
[WARN] FPS3K_RESP and FPS3K_SEQ both set: FPS3K_SEQ wins, FPS3K_RESP is IGNORED
```

**It is false.** Logging every write to `XLTR_MODE0` with both variables set shows the model
delivering codes from *both* sources:

| value at MODE0 | source |
|---|---|
| `$0001`, `$0426` | the scripted sequence (`01`, `26` with the valid bit) |
| **`$0094`, `$0494`** | **`FPS3K_RESP=0x94`**, the latter with the valid bit |

The sequence wins only **while it has entries**; once exhausted, `FPS3K_RESP` is what continues
to be delivered. That is a meaningful difference, because a long-running experiment spends most
of its time in the exhausted state.

**This cost real analysis time.** Several entries above attribute the bit-7 dispatches to
`FPS3K_RESP=0x94`, and on seeing this warning I began doubting those conclusions — they were
correct, and the warning was wrong. *A diagnostic that overstates a conflict is as misleading as
one that reports the wrong decision*, which is a lesson this codebase already learned once: the
comment beside the CHANNEL_SELECT arming log records exactly that defect, where "arm=yes" was
printed for 32,967 beacon writes that armed nothing.

**Corrected**, in both places it appears — the inline warning in `versabus.c` and the conflict
table in `fps3k_sbc.c`, which now carries a per-pair qualifier. *The other three pairs in that
table are left exactly as written*: `FPS3K_CHSEL_RD`/`FPS3K_SEQ`,
`FPS3K_RESP`/`FPS3K_INJECT`, `FPS3K_MBOX`/`FPS3K_APIF_LEGACY` have **not** been measured, and
weakening an unverified warning would be the same error in the opposite direction. Default RAM
digest unchanged (`f72fb0a5…`).

### `FPS3K_POKEONCE`: a write-once release — RDHC escapes, then halts on the *next* command

The read-override experiment established the mechanism and the wrong tool. `FPS3K_POKEONCE`
is the right one: same syntax as `FPS3K_POKE`, but it performs a **real RAM write, once**, when
the boot-complete gate first opens, and then leaves the memory alone so the kernel's own
save/restore keeps working. Default-off; the default RAM digest is byte-identical with it
present.

| | read-override (`FPS3K_POKE`) | **write-once (`FPS3K_POKEONCE`)** |
|---|---|---|
| escapes the spin | 3 | **1** |
| RTOS idle loop | **8** (collapsed) | **2,416** (healthy) |
| trace lines | — | 9,680,659 |
| self-test | — | completes |

**The write-once release works and does not damage the machine.** RDHC leaves `$F056B8`, runs
`$F056BA` and `$F056BE` — and then the spin count goes back up to 183,093.

**That is exactly what the one-way-issuer finding predicts.** `PanelIOConfigure_25A` halts on
*every* call, so releasing RDHC from one spin merely lets it proceed to its next panel command,
which parks it again. A single release cannot free the task; only a release *per issuer call*
can, which is presumably what a real chassis provides by answering each command.

So the two experiments together give a complete account:

- the resume address is **TCB+`$FC`**, measured holding `$F056B8` while parked;
- writing a different value **does** release the task — mechanism confirmed twice;
- forcing the field permanently destroys the scheduler, so the hook must write once;
- and one write is not enough, because the halt is per-command, not once per task.

**A process note.** The first attempt at this experiment reported all-zero counts and looked
like a total failure of the new hook. The cause was my own command: `2>&1 >/dev/null | head -3`
closed the pipe early and killed the emulator by `SIGPIPE` before it flushed the trace. The hook
had fired correctly all along. *An empty result file and a broken feature are indistinguishable
until you check that the run finished* — and the check that separated them was simply counting
the trace lines, which were zero rather than merely uninteresting.

### The intervention works — RDHC leaves the spin — but a read-override is the wrong tool

Forcing RDHC's saved PC with the existing hook,
`FPS3K_POKE="1F3FC=00F0,1F3FE=56BA"` (the two words of `$00F056BA`, the instruction after the
spin):

| PC | driven run | with the override |
|---|---|---|
| `$F056B8` — the spin | **182,124** | **20** |
| `$F056BA` — after it | 0 | **3** |
| `$F056BE` — further in | 0 | **3** |
| `$F00FCC` — RTOS idle | ~3,661 | **8** |

**RDHC leaves the spin.** Three escapes, and execution continues into the routine following it —
a 9,000-fold reduction in spin iterations. That confirms the whole chain end to end: `+$FC` is
the resume address, and changing it releases a task parked at `bra .`.

**But the machine collapses.** The RTOS idle loop runs 8 times against ~3,661 normally, so
almost nothing else executes. The reason is in the hook's nature: `FPS3K_POKE` overrides
**every read** of those addresses, permanently. The kernel therefore cannot save a *new* PC for
RDHC — every context switch reads back `$F056BA` regardless of where the task actually got to —
so RDHC is repeatedly restarted at the same instruction and the scheduler's bookkeeping is
destroyed.

*So the experiment is positive on the mechanism and negative on the method.* What a real
release does is a **one-time write** at the moment the chassis responds; what this hook does is
pin the field forever. Those differ in exactly the way that matters. **A hook that forces a
value is not a model of an event that sets one.**

That is a useful distinction for the emulator generally: `FPS3K_POKE`, `FPS3K_CHSEL_RD` and
`FPS3K_MBOX` all force reads to a constant, and this file already records one case where that
"returns a constant, which no real mailbox does" invalidated a conclusion. The same limitation
applies here, and it now has a measured demonstration rather than a caveat.

**What is established:** the escape target is `$1F300 + $FC`, writing `$F056BA` there does
release RDHC, and a usable experiment needs a *write-once* facility the emulator does not
currently have. That is a smaller and better-specified gap than "something must rewrite the
saved PC", which is where this thread started.

### CONFIRMED: TCB+`$FC` holds the spin address — and the escape is now a single write

The `+$FC` = saved-PC identification is confirmed by the strongest available test: the field
holds exactly the address the task was independently measured spinning at.

| configuration | RDHC's TCB+`$FC` |
|---|---|
| clean boot | **`$F04740`** — its main-loop `btst #7`, parked in the directive-`$13` wait |
| driven (`FPS3K_RESP=0x94 FPS3K_XPIRQ=6`) | **`$F056B8`** — **the spin** |

The other tasks read sensibly in both: XP1I `$F07E1C`, XP4I `$F06022`, IO1I `$F05DC2`, each
inside its own region. **A task parked at `bra .` has that `bra .` saved in its TCB**, which is
what a correctly-working context save looks like — the kernel is not failing to save RDHC's
position, it is saving it faithfully.

**Two things this settles.**

*The clean-boot resting place is `$F04740`.* This project documents RDHC as entering its wait
and not leaving; the TCB now shows exactly where it sits, and it is the `btst #7` immediately
after the wait — consistent with the measured `$F0473C` x1 / `$F04740` x1 from the very first
profile, and independent of it.

*The escape is a single memory write.* Releasing RDHC means putting a different value in
**`$1F300 + $FC`**. That is a concrete, testable intervention where previously there was only
"something must rewrite the saved PC" — and `FPS3K_POKE`, which this emulator already has and
which is gated on boot completion, can perform it without any code change.

The natural value is **`$F056BA`**, the instruction after the spin — which is the start of the
routine this project labels `PanelSendAndWait` (`move.w #$4f,(a3)` …). *That labelling now
looks like it was reaching for something real*: the code after the spin is a continuation, and
a task released from `$F056B8` would run it. Whether the hardware ever produces that release is
still unknown, but the shape of what the release does is no longer a mystery.

*This closes the thread properly.* It began with "why does only one reply ship", ran through six
superseded explanations, and ends with a measured field, a measured value, and an intervention
that can be executed with an existing hook. **The chain was long because each explanation was
testable only by the experiment that displaced it; it terminated because the last step asked
what the machine had recorded rather than what it was doing.**

### The TCB layout derived empirically — and `+$FC` is the saved PC, which IS written

Rather than trust a header from the wrong revision, diffing the six live TCBs gives a
build-specific layout. **Only 13 of 128 longwords differ across the six**, and every one is
interpretable:

| offset | example values | reading |
|---|---|---|
| `+$004`, `+$00C` | `$0001EB00`, `$0001ED00` | **list links** — other TCB addresses |
| `+$010` | `"XP1I"`, `"RDHC"`, `"IO1I"` | **task name** |
| `+$028` | `$A0010000` / `$A0810000` | attributes — only RDHC differs |
| `+$038` | `$1EA60`, `$1EC60` | per-task structure pointer |
| **`+$06C`** | `$F046F0`, `$F05D36` | **entry point** (confirms this project's value) |
| **`+$0FC`** | **`$F04740`**, `$F05DC2` | **a second code address** — see below |
| `+$120` | `$F04600`, `$F05D00` | **TDTI region base** |
| `+$138`, `+$13C` | `$1DD00` / `$1DE16` | semaphore/stack block and its end |

**`+$0FC` is the saved PC, and it is written by the kernel.** For RDHC it holds **`$F04740`** —
which is not its entry point (`$F046F0`, at `+$6C`) but its **main-loop `btst #7` instruction**,
the documented "RDHC leaves the wait" PC. That is a *current* position, not a starting one.

Searching the ROM for displacement `$00FC` finds **seven references, all in the kernel**:

```
writes: $F00610  $F0292E  $F02B1C  $F036A0
reads:  $F02AF0  $F02B04  $F03638
```

`$F02B1C` (`move.l d6,$fc(a5)`) sits beside the scheduler at `$F02C6C`, which is exactly where
a context save belongs.

**This corrects a claim from two entries ago.** I wrote that "nothing in the firmware ever reads
or writes a task's saved PC", based on finding no references to displacement `$D8` — the vendor
header's `TCBPC`. **That offset is not the PC in this build.** The real field is `+$FC`, and it
is written four times and read three times. The search was sound; it was pointed at the wrong
address, because I took the offset from the header I had just shown to be mismatched.

*What survives and what does not.* The **empirical** conclusion — RDHC never escapes, 182,124
spin iterations, three eliminated candidates — is untouched. The **argument** that no mechanism
could rewrite a task's PC is withdrawn: the mechanism plainly exists, since that is how any
preemptive kernel resumes a task. What remains true is that nothing was observed to write an
*altered* PC for a spinning task; a task parked at `bra .` has `$F056B8` saved and restored
faithfully, which is a save/restore working correctly rather than an escape.

**Two rounds, two corrections, one cause.** Both came from carrying a vendor offset past the
point where the vendor layout was shown not to apply. Having flagged the header as mismatched,
I then used one of its offsets in the very next search. *A source you have just discredited does
not become reliable again for the next question.*

### CAUTION: the vendor `TCB.EQ` does NOT match this build — the field naming is tentative

The previous entry named `+$2C`, `+$58` and `+$5E` from `SR10/U9995/TCB.EQ`, calibrated on
`TCBNAME` landing at `+$10`. **One matching field was not enough calibration.** Checking live
TCBs in post-boot RAM:

| offset | vendor field | XP1I | XP2I | XP3I |
|---|---|---|---|---|
| `+$10` | `TCBNAME` | `XP1I` | `XP2I` | `XP3I` | ✓ matches |
| **`+$5A`** | **`TCBENTRY`** — initial entry point | **0** | **0** | **0** | ✗ empty |
| **`+$6C`** | *(inside `TCBXREGS`)* | **`$F07D4A`** | **`$F0734A`** | **`$F0694A`** | the real entry points |
| `+$D8` | `TCBPC` | 0 | 0 | 0 | |

**The entry points are at `+$6C`, where the vendor header says saved registers live, and
`TCBENTRY` at `+$5A` is zero.** This project's empirically-derived `+$6C` is right; the vendor
offset is not. So the SR10 header describes a **related but different TCB layout** — a
different RMS68K revision than this firmware was built against.

**Consequences, stated plainly:**

- The names `TCBSTATE` (`+$2C`), `TCBISRS` (`+$58`), `TCBUSER` (`+$5E`) are **tentative**, not
  authoritative. They come from a header that is demonstrably wrong about `+$5A` for this
  build. They remain plausible — the scheduler's use of `+$2C` as a flag word fits "task
  state" well — but "named from the vendor source" overstated it and is withdrawn.
- The `$FC` boundary and the "FPS extension space" reading inherit the same doubt. The
  *observation* that `+$100`, `+$138` and `+$160` sit past 252 bytes is arithmetic and stands;
  the *interpretation* that 252 is where the vendor structure ends does not, if the layout
  differs.
- **The `TCBPC` search is unaffected in what it measured** — there are no `d16(An)` references
  with displacement `$D8` anywhere in the ROM — but it no longer supports "nothing writes a
  task's saved PC", because `$D8` may not be the PC in this build.

*What went wrong, precisely.* I calibrated on one known value, it matched, and I proceeded. A
second known value was available the whole time — this project documents the entry point at
`+$6C` — and it contradicts the header. **One agreeing control is consistent with a correct
map and equally consistent with a coincidence; two are what distinguish them.** The same
mistake in a different medium as the address scans: a check that can only confirm.

The conclusion that RDHC has no in-ROM escape still rests on the three eliminated candidates
and the 182,124-iteration measurement, which are independent of any of this.

### TCB fields named from the vendor source — and where the FPS extension begins

`SR10/U9995/TCB.EQ` declares the TCB as 51 sequential `DS` fields rather than numeric equates,
so offsets have to be accumulated. Doing that lands `TCBNAME` at **`+$10`**, which is exactly
the offset this project already documents for the task name — so the accumulation is validated
against a known value before anything is read off it.

The offsets the scheduler touches then resolve authoritatively:

| offset | vendor name | vendor comment |
|---|---|---|
| `+$2C` | **`TCBSTATE`** | current task state |
| `+$58` | **`TCBISRS`** | **error code — save for wakeup** |
| `+$5E` | **`TCBUSER`** | number associated with task |

That makes the scheduler's opening read plainly: clear a bit in **`TCBSTATE`**, clear the saved
**error code** and the pointer that carries it, move **`TCBUSER`** out to `+$102`, stamp `$813`
at `+$100`, and clear `TCBUSER`. All state hygiene on a task being rescheduled — and it
confirms from the other side that nothing here touches a PC.

**The vendor TCB is `$FC` = 252 bytes, and that boundary explains several documented offsets:**

| offset | | |
|---|---|---|
| `+$10`, `+$2C`, `+$58`, `+$5E`, `+$6C` | inside | vendor fields |
| **`+$100`, `+$102`** | **beyond** | the scheduler's write targets |
| **`+$138`** | **beyond** | the semaphore block this project documents |
| **`+$160`** | **beyond** | `!TST`, likewise documented |

TCBs are allocated on a **`$200` stride**, so **`$FC`-`$1FF` is FPS extension space** — 260
bytes appended past the vendor structure. The semaphore descriptors at `+$138` and the `!TST`
tag at `+$160` were both found empirically and recorded without reference to a boundary; they
sit in that extension, as do `+$100`/`+$102`. *One boundary explains all four.*

That also answers a question the `$200` stride raised but never settled: the TCBs are not
`$200` bytes because the allocator rounds to pages — 252 would round to `$100`. They are `$200`
because **the FPS layer appends its own fields**, and the extension is over half the block.

*Method note:* the offsets came from computing a running total over a vendor header, which is
error-prone in exactly the way this session has been catalogueing. The guard was checking the
computation against `TCBNAME` at `+$10` — a value derived independently, long before, by
inspecting live TCBs in RAM. **A parser of someone else's header needs a known answer to
calibrate against just as much as a scanner of someone else's binary does.**

### The scheduler touches TCB state, not PCs — so no in-ROM escape from `bra .`

`$F02C6C`, the routine the ISR exit hands a TCB to, opens by manipulating task state:

```
$F02C6C:  move    sr,-(a7)
$F02C6E:  bset.b  #$7,$0c5b.w          ; a global flag
$F02C74:  bclr.b  #$e,$2c(a0)          ; TCB+$2C -- flags (bit $E mod 8 = bit 6)
$F02C7C:  move.l  $58(a0),d0           ; TCB+$58
$F02C84:  clr.l   $4(a1)  ;  clr.l $58(a0)
$F02C8C:  move.w  $5e(a0),$102(a0)     ; TCB+$5E -> TCB+$102
$F02C94:  move.w  #$813,$100(a0)       ; TCB+$100 <- $813
$F02C9A:  clr.w   $5e(a0)
```

**New TCB field offsets**, which this project's TCB map does not record (it has name `+$10`,
entry `+$6C`, semaphore block `+$138`, `!TST` `+$160`):

| offset | use |
|---|---|
| `+$2C` | flags — bit 6 cleared on this path |
| `+$58` | a pointer, cleared along with `$4` of what it points to |
| `+$5E` | a word moved to `+$102` then cleared |
| `+$100` | set to **`$813`** |
| `+$102` | receives `+$5E` |

**And no PC arithmetic anywhere in it.** The routine adjusts flags, clears a pointer pair, and
moves a word between two TCB fields. Nothing resembling a saved program counter is written.

That eliminates the third and last in-ROM candidate. Collecting the eliminations:

| candidate | verdict |
|---|---|
| panel-status responder `$F04930` | **no** — runs 966x during the spin; no stacked-PC write exists in RDHC |
| kernel ISR-exit path | **no** — its only PC arithmetic is a fixed −6 on the ISR's *own* return |
| scheduler `$F02C6C` | **no** — manipulates TCB state fields, not PCs |

**So within this ROM there is no mechanism that rewrites a spinning task's program counter**,
and the `bra .` at `$F056B8` is terminal. Combined with the earlier finding that
`PanelIOConfigure_25A` is linear and returns on no path, the conclusion is that **the eight
panel-command issuer copies are halt points** — reaching one ends that task.

*Stated with its limits.* I have read the scheduler's first 26 bytes, not all of it, and the
kernel region is 17.5 KB of generic RMS68K. A PC-manipulating path deeper in the scheduler
would overturn this. What makes the conclusion worth stating anyway is that it agrees with the
measurement — 182,124 spin iterations against 966 responder entries and a working scheduler —
so any such path is at minimum not exercised here. **The firmware-side search is done; if an
escape exists it is in hardware behaviour this emulator does not model.**

### The ISR exit is a RESCHEDULING POINT — the full kernel path decoded

Following the sentinel branch to its end gives the complete ISR-exit mechanism:

```
$F002AA:  bne     $F002C2           ; no match -> error
$F002AC:  movea.l -$c(a5),a6        ; matched: a6 = the record's TCB pointer
$F002B0:  lea     (a6),a0
$F002B2:  bsr     $F02C6C           ; hand the TCB to the scheduler
$F002B6:  movem.l (a7)+,d0-d7/a0-a6
$F002BA:  lea     $4(a7),a7
$F002BE:  rte                       ; return to whatever was selected
$F002C2:  bsr     $F00186           ; no match -> error path
```

**Both `!IDV` offsets land exactly on the documented fields**, which is a strong independent
check on the record layout since `a5` has already been advanced `$E` past the match:

| code | resolves to | field |
|---|---|---|
| `cmpa.l $a(a5),a4` | `+$A` (pre-advance) | **ISR exit** — what the lookup matches |
| `movea.l -$c(a5),a6` | `a5-$E+$2` = `+$2` | **TCB** — what the lookup yields |

So the sequence is: match the exiting ISR by its exit address, take that record's **TCB**, and
pass it to `$F02C6C` before returning via `rte`.

**That makes the ISR exit a rescheduling point.** The `rte` cannot simply resume the ISR — the
PC was rewound six bytes to the `move.w #$c,ccr`, so resuming it would re-issue the same trap
forever. It only makes sense if `$F02C6C` **switches the stacked context to another task**,
which is what a scheduler called with a TCB does. The rewind then serves a second purpose: if
this ISR is ever resumed later, it re-issues its exit rather than falling through into whatever
follows.

That completes a central RTOS mechanism which this project had only named:

| step | |
|---|---|
| 1 | ISR finishes with `move.w #$c,ccr` / `trap #1` |
| 2 | kernel detects the **Z\|N sentinel** and rewinds the PC by 6 |
| 3 | walks **`!IDV`** (stride 14) matching the exit address at `+$A` |
| 4 | takes that record's **TCB** at `+$2` |
| 5 | calls **`$F02C6C`** with it — the scheduler |
| 6 | `rte` into the selected task |

**And it confirms why RDHC cannot escape its spin.** Step 6 returns to whatever the scheduler
selects; if that is RDHC, RDHC resumes at `$F056B8` and spins again. Nothing in this path
inspects or alters a *spinning* task's PC — the only PC arithmetic is the fixed −6 applied to
the ISR's own return address. The escape, if there is one, is not in the ISR-exit path either.

### The sentinel path walks `!IDV` with a 14-byte stride — and rewinds the PC by 6

Following the sentinel branch decodes cleanly and confirms `!IDV`'s record layout from the
code that consumes it.

```
$F00280:  addq.l  #4,a7             ; discard the SR copy and the SR -> (a7) is the PC
$F00282:  subq.l  #6,(a7)           ; REWIND the return PC by 6
$F00284:  movem.l d0-d7/a0-a6,-(a7)
$F00288:  movea.l $0c6e.l,a5        ; the !IDV directory slot
$F0028E:  movea.l $4(a5),a6         ; the table END pointer
$F00292:  lea     $8(a5),a5         ; first record, past the tag and bounds
$F00296:  movea.l $3c(a7),a4        ; the value to match
$F0029A:  cmpa.l  $a(a5),a4         ; compare against field +$A
$F0029E:  adda.l  #$e,a5            ; STRIDE 14
$F002A4:  beq     $F002AA
$F002A6:  cmpa.l  a5,a6  ;  bcc $F0029A    ; loop while inside the table
```

**`$0C6E` holds `$1F800`, whose first longword is `!IDV` — verified in post-boot RAM.** So this
is the interrupt-descriptor table, and the walk settles its geometry:

| | |
|---|---|
| stride | **`$E` = 14 bytes**, straight from `adda.l #$e,a5` |
| record | `{vector, TCB, ISR entry, ISR exit}` = 2 + 4 + 4 + 4 = **14** ✓ |
| six records | 6 x 14 = **84 bytes** |
| match field | **`+$A`** — the fourth field, the **ISR exit** address |
| bounds | header at `+$0`/`+$4`; records start at `+$8`; end pointer `$1F8FF` |

The documented record shape was inferred from the structure's contents; here the kernel's own
traversal confirms it, and adds which field the lookup keys on. **The ISR-exit handler
identifies which ISR is exiting by matching the return address against each record's ISR-exit
field.** That is why six tasks can share one exit convention: the sentinel says "this is an ISR
exit", and `!IDV` says *whose*.

**And the PC rewind is real, just not an escape.** `subq.l #6,(a7)` moves the return address
back **6 bytes** — exactly the length of `move.w #$c,ccr` (4) plus `trap #1` (2). So the kernel
rewinds the task to re-execute its own ISR-exit sequence. *This is the "rewriting the saved PC"
mechanism this project attributed to the panel-status responder* — it exists, it is in the
kernel, and it rewinds rather than advances. It cannot release a `bra .` spin; it makes the exit
stub re-runnable.

So the RDHC question stands where the last entry left it, but one candidate is now eliminated
rather than merely unlocated: **the kernel's PC manipulation is not the escape.** It moves the
PC backwards by a fixed 6 and depends on nothing external.

### CONFIRMED IN THE KERNEL: the TRAP #1 handler tests for the Z|N sentinel

The sentinel reading was inferred from `$0C` being an arithmetically impossible flag pair. The
kernel's own TRAP #1 handler confirms it outright.

Vector 33 (`$84`) reads `$F00262` in post-boot RAM, and that handler opens:

```
$F00262:  3F17            move.w  (a7),-(a7)        ; duplicate the stacked SR
$F00264:  022F 000C 0001  andi.b  #$0C,$1(a7)       ; MASK the CCR with $0C
$F0026A:  0217 007F       andi.b  #$7F,(a7)
$F0026E:  6708            beq     $F00278           ; -> normal directive path
$F00270:  0C2F 000C 0001  cmpi.b  #$0C,$1(a7)       ; COMPARE against $0C
$F00276:  6708            beq     $F00280           ; -> the sentinel path
$F00278:  548F            addq.l  #2,a7             ; normal
$F00280:  588F            addq.l  #4,a7             ; sentinel
```

**The kernel masks the stacked CCR with `$0C` and tests for `$0C` — that is, it tests that
both Z and N are set**, and branches to a different path when they are. The impossible flag
pair is not merely a plausible marker; it is the exact thing the handler looks for, and the two
arms discard different amounts of stack (`addq #2` versus `addq #4`), so they expect different
frame shapes.

That closes the question completely:

| | |
|---|---|
| **normal TRAP #1** | directive in `d0`, CCR arbitrary → `$F00278` |
| **ISR exit** | CCR = Z\|N, `d0` belongs to the interrupted task → `$F00280` |

*The prediction and its confirmation came from different places*, which is what makes it worth
recording. The reasoning was: `d0` is unavailable at an ISR exit, so the CCR must carry the
signal; `$0C` sets Z and N together; no arithmetic produces that; therefore it is a deliberate
marker rather than a value. The confirmation is six instructions of kernel code — in the region
this project excludes from `fps3k.asm` as "stock Motorola" — doing precisely that test.

**And it vindicates looking in the kernel at all.** The previous entry ended with "whatever
releases it comes from outside the ROM — the RTOS kernel or the hardware — and that is where to
look next". The kernel was the right half of that disjunction, and the 27% of the image this
project treats as generic turned out to contain the answer. *Stock code is still this machine's
code*, and the boundary drawn around it is a convenience, not a statement about where findings
live.

### The ISR-exit CCR value is a SENTINEL, not a directive number

I wrote earlier that the six ISR exit stubs "pass the directive in the CCR". Two checks say
that framing was wrong, and the truth is neater.

**Directive 12 does not fit.** `$0C` looked up in the RMS68K reference (`SR10/U9995/TR1.EQ`) is
**`GTTASKNM` — "GET TASK NAME"**, which has no plausible role at an interrupt exit. And the
reference contains **no CCR-based convention at all**: searching its equates for interrupt
exit/return directives, or for any mention of the condition-code register, returns nothing.

**The value is an impossible flag combination.** `move.w #$000C,CCR` sets:

| bit | flag |
|---|---|
| 2 | **Z** — zero |
| 3 | **N** — negative |

**Z and N together cannot arise from arithmetic.** No comparison, no `tst`, no ALU result
makes a value both zero and negative. It is a state the hardware never produces on its own,
which makes it exactly what one would choose as an **unambiguous marker**: the kernel can test
for it and know it was set deliberately rather than left over from a computation.

So the corrected reading: the ISR exit is a `trap #1` whose CCR carries a **sentinel**. Whether
the kernel decodes it as an index or simply recognises the pattern is not determinable from
this ROM — the handling is in the RMS68K kernel region, and the reference source does not
document it.

**What survives from the earlier entry is the mechanism, not the label.** The important part
was always that `d0` cannot carry anything at an ISR exit — `movem.l (a7)+,d0-d7/a0-a7`
restores the interrupted task's registers immediately before — so the CCR is the only channel
left, and `trap` stacks the SR where the kernel can read it. That reasoning holds. Calling the
payload "the directive" was an assumption imported from the normal TRAP #1 convention, and the
lookup contradicts it.

*This is the second time this session that a value has been read as an index into a known table
when it was actually a flag pattern* — the first being the panel codes `$25D`-`$260`, taken as
per-channel indices and found to be rejects. **A number that happens to fall inside a known
numbering is not thereby a member of it.**

### The panel-command issuer is ONE-WAY: it never returns, on any path

`$F05688` is 48 bytes and **completely linear — no branches, no conditions:**

```
$F05688:  move.w d0,$e6e.l       ; stash the code at the shared global
$F0568E:  movea.l #$ff0000,a0
$F05694:  move.w d0,$e(a0)       ; write the code to $FF000E
$F05698:  move.w $202(a0),d1     ; MODE1
$F0569C:  bclr.b #$e,d1          ; clear bit 14
$F056A0:  bset.b #$c,d1          ; set bit 12
$F056A4:  move.w d1,$202(a0)
$F056A8:  move.w $200(a0),d1     ; MODE0
$F056AC:  bclr.b #$a,d1          ; clear bit 10
$F056B0:  move.w d1,$200(a0)
$F056B4:  move.w d0,$204(a0)     ; issue on CHANNEL_SELECT
$F056B8:  bra.b  $F056B8         ; SPIN -- unreachable to exit
```

**Every call to this routine halts the calling task.** There is no return, no conditional
skip, and the eight copies are byte-identical over exactly these 48 bytes. It is called with
ordinary completion codes as well as error codes — `$26C` RELEASE on a normal finish, `$25D`
on a range reject, `$26A` on a timeout — so this is not an error-only path.

**Two of this project's readings need adjusting.**

The routine is named `PanelSendAndWait` and described as issuing a command and waiting for a
response. **The code contains no wait** — a `bra .` is not a poll, has no exit condition, and
tests nothing. "Send and halt" is what it does.

And the escape is documented as *"the panel-status responder `$F04930` rewriting the saved
PC"*. **No code in RDHC writes to a stacked return address.** Every `a7`-relative access in the
region is a register save/restore (`$F04930`, `$F050F8`), a MODE2 push/pop (`$F04D4E`/`$F04E22`,
`$F05312`), or an on-stack parameter block (`$F05652`-`$F05674`). The ISR exits via `trap #1`
with directive `$0C` in the CCR, so any resumption decision belongs to the RTOS — and
empirically the responder runs **966 times during the spin without releasing it**.

**What this does not settle** is how the machine is supposed to work on real hardware. A task
that halts on every panel command cannot be the normal path, so either the RTOS's directive-`$0C`
handling resumes the task elsewhere (plausible, and it is kernel code outside `fps3k.asm`), or
the spin is genuinely terminal and the eight copies mark unrecoverable states. *I can rule out
the documented explanation without being able to supply the correct one*, and saying so is more
useful than replacing one unsupported mechanism with another.

The practical consequence for the emulator is unchanged and now better founded: **RDHC halts on
its first panel command**, and nothing in the firmware will release it. Whatever releases it must
come from outside the ROM — the RTOS kernel or the hardware — and that is where to look next.

### The dynamic profile of the whole machine: one live spin, four idle tasks

Applying the profiling lesson to every task at once gives the machine's actual behaviour in a
single table, and it is worth having in this form.

| region | executions | hottest PC |
|---|---|---|
| **RDHC** | 201,534 | **`$F056B8` x182,124 (90%) — `bra .`** |
| IO1I | **126** | `$F05F7A` x6 |
| XP4I | **81** | `$F0697A` x6 |
| XP3I | **81** | `$F0737A` x6 |
| XP2I | **81** | `$F07D7A` x6 |
| XP1I | **59** | `$F08700` x1 |
| RTOS + kernel | 417,447 | `$F00552` x7,251 (1%) |

**Four of the five service tasks execute fewer than 130 instructions in a 300 M-cycle run.**
They are not blocked in a spin — they are barely entered at all, which is consistent with their
being gated behind conditions this configuration never satisfies.

**And the spin census is decisive.** The ROM contains **nine** `bra .` sites — the eight
panel-command issuer copies this file documents plus `$F001AA` in the kernel:

```
$F001AA  x0      $F04530  x0      $F056B8  x182,124  <-- the only live one
$F05E86  x0      $F068D8  x0      $F072F0  x0
$F07CF0  x0      $F086F0  x0      $F0A5AE  x0
```

**Exactly one executes.** Every other issuer copy, including TCBIO1I's `$F05E86` — the deadlock
this file describes in detail — is **never reached** in this configuration. So of the two
"self-programmed deadlocks" documented for this machine, only RDHC's is live; TCBIO1I's is real
in the code and dormant in practice, because TCBIO1I executes 126 instructions and never gets
there.

*That reframes the emulator's remaining work usefully.* The picture is not "several tasks stuck
in spins needing several chassis responses". It is **one task stuck in one spin**, four tasks
that never start, and a kernel scheduling around them. Releasing `$F056B8` — by making the
panel-status responder rewrite the spinning PC — is a single change that would let RDHC run, and
RDHC is the task that drives everything else.

*Method note, and the lesson of this whole thread:* nine rounds of hypotheses about protocol
mechanics were resolved by one profile of where the program counter goes. **Instruction counts
per PC are the cheapest measurement available on an emulator and should be the first one taken,
not the last.** I reached for it only after six explanations had failed.

### ANSWERED: RDHC spends 90% of the run in a `bra .` spin at `$F056B8`

Measuring where RDHC actually executes settles the question the previous entry left open, and
it is not subtle:

| PC | executions | share |
|---|---|---|
| **`$F056B8`** | **182,124** | **90% of all RDHC execution** |
| `$F04930`-`$F04958` | 966 each | the panel-status ISR |
| `$F050F8`/`$F050FC` | 966 each | the ISR exit and its wake |
| everything else in RDHC | — | 117 distinct PCs, 201,534 total |

`$F056B8` is `60 fe` — **`bra.b` to itself**. It is the tail of `PanelIOConfigure_25A`:

```
$F056A0:  bset.b #$c,d1          ; set MODE1 bit 12
$F056A4:  move.w d1,$202(a0)
$F056A8:  move.w $200(a0),d1     ; read MODE0
$F056AC:  bclr.b #$a,d1          ; clear bit 10 -- release the acknowledge
$F056B0:  move.w d1,$200(a0)
$F056B4:  move.w d0,$204(a0)     ; issue the command on CHANNEL_SELECT
$F056B8:  bra.b  $F056B8         ; SPIN, waiting for the chassis
```

**So RDHC is not waiting for work — it is stuck having asked for some.** It wakes, dispatches,
the handler issues a panel command through this routine, and the routine parks forever. That is
why the directive-`$13` wait is entered only twice: RDHC never gets back to it.

**And the ISR fires 966 times *during* that spin without releasing it.** This file documents the
escape mechanism — *"the only escape is the panel-status responder `$F04930` rewriting the saved
PC"* — and the measurement shows the responder running while the spin continues. So the ISR is
entered and does not rewrite the PC out of `$F056B8`.

**That is the single concrete thing blocking RDHC**, stated in a form a model can act on: the
chassis must respond to a panel command in a way that causes `$F04930` to rewrite the spinning
return address. Everything else in this thread — delivery timing, push versus pull, the two
acknowledges, wake rates — was downstream of a task that never leaves its first command.

*The same self-programmed deadlock is already documented for TCBIO1I* (`$F05E86`), and this file
notes RDHC as "the same, one level further out". That was inferred; this measures it, names the
spin, and quantifies it at 182,124 iterations against 966 ISR entries — a responder running
188 times per spin without effect.

### The wake fires 966 times; RDHC's wait is entered TWICE

Following the narrowed question — what wakes RDHC and how often — measures out sharply, and
rules out the answer I expected:

| PC | count | |
|---|---|---|
| `$F04930` | 966 | panel-status ISR entry |
| `$F0495C` | 964 | bit-7=1 dispatcher |
| `$F04A6E` | **2** | bit-7=0 dispatcher (the 16 chassis ops) |
| `$F050F8` | 966 | ISR exit stub |
| **`$F050FC`** | **966** | **the `trap #1` that wakes RDHC** |
| `$F0473C` | **2** | RDHC **enters** its wait |
| `$F04740` | **2** | RDHC **leaves** its wait |

**The wake directive is issued 966 times and RDHC's wait is entered twice.** So the wake
mechanism is not the bottleneck — it fires constantly, and 964 of those calls had nothing to
wake because RDHC was not waiting.

That relocates the question again. RDHC is not looping wait → wake → process → wait; it enters
the wait exactly twice in a 300 M-cycle run. **Where RDHC spends the rest of the run is now the
open question**, and it is a question about RDHC's control flow rather than about the chassis
interface at all.

*One further asymmetry worth recording:* the ISR dispatches to the **bit-7=1** route 964 times
and to the **bit-7=0** route (the sixteen chassis operations) only **twice**. Since a scripted
sequence leaves `panel_resp_code` at its last entry once exhausted, and my last entry was `$94`
— bit 7 set — the model re-delivers that code indefinitely. So the 964 are an artefact of the
sequence running dry, not a property of the machine. **A test harness that repeats its final
input forever will make that input look overwhelmingly common**, and the ratio here is 482:1.

This closes the thread that began with "why does only one reply ship". The chain of
explanations went: model drops replies → firmware replies per-op → replies are a separate
bit-7 command → delivery is pull-based → delivery is fine, acknowledge is two things → the
acknowledge fires constantly and RDHC simply is not there to receive it. **Each step was
supported by the evidence available when it was made, and each was superseded by evidence the
next experiment produced.** The useful output is not any one of those statements but the
measurement above, which is stable regardless of what explains it.

### There are TWO acknowledges, and the reply is gated by RDHC's wake rate

The failed push experiment said the obstacle was in the arm/acknowledge state machine. It is,
and the reason is that **"acknowledge" names two different things** which I had been treating as
one.

The panel-status ISR at `$F04930` acknowledges **every** command, immediately, before it
dispatches anything:

```
$F0493A:  move.w $200(a0),d0        ; read MODE0
$F0493E:  bclr.b #$b,d0             ; clear bit 11
$F04942:  move.w d0,$e86.l          ; LATCH the command
$F04948:  bset.b #$a,d0             ; SET bit 10 -- ACKNOWLEDGE
$F0494C:  move.w d0,$200(a0)        ; write it back
$F04950:  btst.b #$7,$e87.l         ; then dispatch on bit 7
```

That is the bit-10 set the model waits on to release the next scripted code — and it fires on
**every** command (1,464 times in these runs), which is why delivery works and why pacing never
mattered.

RDHC's `$F048C8` is a **second, different** acknowledge: it *clears* bit 10 and ships `$0E74`.
It is reached only when RDHC wakes from its directive-`$13` wait **and** finds bit 7 set.

| | site | when | effect |
|---|---|---|---|
| **ISR acknowledge** | `$F04948` | every command | sets bit 10; releases the next code |
| **RDHC acknowledge+reply** | `$F048C8` | RDHC wakes *and* bit 7 set | clears bit 10; ships the result |

**So the reply rate is gated by RDHC's wake rate, not by delivery at all.** RDHC woke twice in
the two-op run and only one wake carried bit 7 — hence one reply. Pushing codes faster could
never help, exactly as measured, because the codes were never the constraint.

*This is where three rounds of reasoning about delivery timing should have started.* The
distinction was visible in the disassembly the whole time — one site does `bset #$a`, the other
`bclr #$a`, four hundred bytes apart — and I read both as "the acknowledge" because they touch
the same bit. **Two operations on one bit are not the same operation**, and the direction was
the tell.

What remains genuinely open is narrower than before: **what wakes RDHC, and how often it can be
made to.** Its waker is its own ISR exit stub `$F050FC` via RTOS directive `$13`, which this
file already documents. That is a tractable question and a different one from anything I have
been asking.

### Push delivery implemented, tested, and REVERTED — the specification was incomplete

Having derived a specification for push-based delivery from the code, I implemented it:
`FPS3K_SEQPUSH=<cycles>` arming the next scripted code on a timer regardless of SBC panel
activity, additive and default-off. The default RAM digest was byte-identical with it present,
so the baseline was safe.

**It does not work, at any interval.**

| `FPS3K_SEQPUSH` | op `$1` | op `$26` | acknowledge |
|---|---|---|---|
| 8,000,000 | **0** | **0** | **0** |
| 60,000,000 | 1 | 1 | 1 |
| 150,000,000 | 1 | 1 | 1 |

At 8M cycles it **breaks dispatch entirely** — the machine boots, the self-test completes, the
RTOS idle loop runs 3,661 times and the panel ISR fires 1,464 times, but **no op handler ever
runs**. Pushing faster than the SBC can process leaves codes overwritten before dispatch. At
60M and 150M it changes nothing: the same one operation each and the same single acknowledge as
without the hook.

**So the specification was necessary but not sufficient.** Push-arming the next code is not
enough to produce a second acknowledge cycle; something else in the arm/dispatch interaction
gates it, and I have not characterised that. The previous entry's confident *"what a fix
requires is now clear and small"* was wrong — it was clear, and it was small, and it was not a
fix.

**Reverted.** `versabus.c` is back to its committed state and the digest re-verified
(`f72fb0a5…`). A non-functional environment variable is worse than none: it would sit in the
emulator looking like a capability, and the next person to set it and see nothing happen could
not tell whether their scenario or the hook was at fault. **The honest artifact of a failed fix
is the knowledge, not the code.**

What the attempt did establish, which the earlier reasoning had not:

- pushing codes faster than the SBC consumes them **destroys dispatch** rather than
  accelerating it — the arm slot is single and gets overwritten;
- the acknowledge count is insensitive to delivery timing across a 20x range, so whatever
  limits it to one is **not a pacing problem** at all;
- and therefore the remaining obstacle is in the arm/acknowledge state machine, not in when
  codes arrive — which is a different place to look than where I had been looking.

### Why the two-phase conversation cannot be driven: delivery is pull-based

Reading the delivery path rather than guessing at it settles why the collect never lands after
an operation — and the answer is not the one I assumed.

**Bit 7 survives delivery.** `MODE0_RESP_MASK` is `0xFF` (its own comment reads *"bit 7 selects
the dispatcher; bits 0-4 are the code"*), and `versabus.c:1586` assigns the sequence code whole
into `panel_resp_code`, which line 1589 ORs into MODE0's low byte. So a `94` entry in
`FPS3K_SEQ` **would** arrive as a bit-7 collect. My earlier guess that SEQ entries cannot carry
bit 7 was wrong.

**The obstacle is when codes are handed over, not what they contain.** Dropping `FPS3K_RESP`
and driving the same three-entry sequence alone gives no operation at all — op `$26` never runs,
and the only event is one `$0000` reply. So `FPS3K_RESP` supplies the wake that starts the
conversation, and the sequence supplies what follows.

That matches the limitation this file already records — *"a code is handed over only when the
SBC issues another panel command, and it stops after a handful"* — and now explains it:
**delivery is pull-based.** The next code is released when the SBC writes a panel command. An
operation that exits via `ChannelConfigDispatch` writes none, so nothing pulls the following
code, and the sequence stalls with its remaining entries undelivered.

**So the two-phase transaction is structurally undriveable with the current hooks**, and for a
specific reason: the *operate* phase is exactly the phase that issues no panel command, so it
can never pull its own *collect*. The documented "one operation per run" guidance is a
consequence of this, not a separate quirk.

What a fix requires is now clear and small: **a push-based delivery mode** that releases the
next code after a cycle delay regardless of SBC panel activity. `FPS3K_SEQGAP` sets a spacing
but is consulted only inside the same pull path (`panel_resp_tick`, on the acknowledge), so it
paces handovers rather than causing them.

*I am still not implementing it*, for the reasons given in the previous entry — but the
requirement is now derived from the delivery code rather than inferred from failed experiments,
which is the difference between a guess at a fix and a specification for one.

### The two-phase prediction is UNTESTED, not confirmed — and the missing hook is now named

The two-phase model predicts: run op `$26` (which reads `$105E` = 2), then issue a bit-7
collect, and the reply should be `$0002`. Attempting it with
`FPS3K_SEQ="01:105E,26:0000,94:0000"` gives:

| access-log line | event |
|---|---|
| 16,416,872 | reply shipped — **`$0000`** |
| 16,428,354 | op `$26` reads `$105E` = **2** |
| 16,428,356 | op `$26` stores **2** into `$0E74` |

**The collect fired ~11,500 accesses *before* the operation.** The acknowledge path executed
exactly once across the whole run, and the third sequence entry produced no second collect.

So the prediction is **untested rather than confirmed**. What is established:

- op `$26` reads the right value and stores it in the result register (confirmed twice now);
- a collect ships whatever `$0E74` holds *at that instant*, and here it held zero;
- `FPS3K_RESP` fires **once, at a time the model chooses**, not on demand.

**The missing capability is now precisely named**, which is more useful than the earlier
"half-duplex" framing: the model needs **a way to issue a bit-7 collect at a chosen point after
an operation**. `FPS3K_SEQ` entries are delivered as operations and do not appear to carry bit 7
into RDHC's dispatch; `FPS3K_RESP` carries bit 7 but fires on its own schedule. Neither can
express "do this op, then collect its result", which is the shape of every real chassis
transaction.

*I am not implementing that hook here.* I do not have a confident reading of the SEQ delivery
path, this session has already made several model changes, and a speculative edit to command
delivery risks the 550-check baseline for a capability nothing yet consumes. **The gap is
small, precisely bounded, and better left as a stated requirement than a guessed
implementation.**

*On the epistemics:* it would have been easy to report this as a confirmation — op `$26` did
store `2`, and `2` is the predicted value. The reply that actually went out was `$0000`, and the
ordering shows why. **A prediction is confirmed by the mechanism producing the value, not by the
value existing somewhere in the machine at some point in the run.**

### The reply is a SEPARATE COMMAND: bit 7 collects, bit 7 clear operates

The previous entry said one reply per run was firmware structure and predicted that **spacing
the commands would give each an acknowledge cycle**. That prediction was tested and **failed** —
`FPS3K_SEQGAP=20000000` produced exactly the same single reply. Following the failure gives the
real mechanism, which is better than the guess.

The trace shows RDHC wakes **twice** (`$F04740` x2) but the finish dispatch `$F048B4` runs
**once**. So the limit is not wakes and not spacing. RDHC's loop is:

```
moveq #$13,d0  /  trap #1        ; wait
btst  #$7,$e87  /  bne <arm>     ; bit 7 of the command byte
```

**Bit 7 selects whether the command is an operation or a collection.** My sequence sent `$01`
and `$26` — both bit-7 clear — so both went to the bit-7=0 dispatcher (`$F04A6E`), ran their
handlers, stored results in `$0E74`, and exited via `ChannelConfigDispatch` **without ever
reaching the reply path**. The single acknowledge+reply came from `FPS3K_RESP=0x94`, whose
**bit 7 is set**, arriving through the other route entirely.

So the protocol is **two-phase**:

| phase | command | effect |
|---|---|---|
| **operate** | bit 7 **clear** — the 16 ops `$0`-`$F` | handler runs, result stored in `$0E74`, exits silently |
| **collect** | bit 7 **set** | acknowledge (clear MODE0 bit 10) and ship `$0E74` to CHANNEL_SELECT |

That explains every observation cleanly: ops never reply because replying is not what ops do;
one reply per run because one bit-7 command was issued; spacing irrelevant because the ops were
never routed to the reply path at all. It also explains why the shipped value was `$0000` — the
`$94` collect arrived *before* op `$26` stored its `2`, and a collect ships whatever `$0E74`
holds at that instant.

**And it means the earlier "half-duplex" framing was too harsh on the model.** The emulated
chassis does have a way to collect results — `FPS3K_RESP` with bit 7 set — and it works. What is
missing is only that nothing *consumes* the value once shipped, which is a smaller gap than "the
return path is not wired". *A driving sequence that interleaves ops with bit-7 collects would
exercise the full conversation today*, with no model changes.

*On the failed prediction:* it was worth making precisely because it was cheap and falsifiable.
The claim "acknowledge is per-command-cycle" fit every observation I had, and only a test that
could contradict it revealed that acknowledge is per-*collect-command*. **An explanation
consistent with all current evidence is not thereby correct** — it has to forbid something, and
then that something has to be checked.

### RESOLVED: the reply is shipped by the acknowledge path, not by op handlers

I left "which ops ship a reply?" as an open question needing a per-op census. Doing it answers
something better: **no op handler ships a reply at all.**

Only three sites branch into the reply region, and none of them is an op handler:

| target | reached from |
|---|---|
| `$F04910` | `$F04902 bne` |
| `$F0491E` | `$F0490E bra` |
| **`$F04924`** | **`$F048D6 bra`** |

And `$F048D6` is the tail of an acknowledge sequence:

```
$F048C8:  move.w $e86.l,d1       ; the latched command
$F048CE:  bclr.b #$a,d1          ; clear bit 10 -- ACKNOWLEDGE
$F048D2:  move.w d1,$200(a5)     ; write it back to MODE0
$F048D6:  bra    loc_F04924      ; -> ship $0E74 to CHANNEL_SELECT
```

**So acknowledging and replying are the same act.** The op handlers store their result into
`$0E74` and exit via `ChannelConfigDispatch`; a separate path clears the MODE0 acknowledge bit
and ships whatever `$0E74` holds at that moment. The reply is not attached to an operation —
it is attached to the **command-arm cycle**.

That resolves the open question the right way round: **"one reply per run" is firmware
structure, not a model limitation.** In a two-op sequence both handlers ran and both stored
their results, but only one acknowledge cycle occurred, so only one value was shipped — and the
one shipped was whatever `$0E74` held when that cycle ran. Nothing was dropped by the emulator.

*A consequence worth stating for anyone driving the machine:* the value a chassis receives is
`$0E74` **at acknowledge time**, not the result of the command it just issued. Issuing two ops
before an acknowledge means the second overwrites the first's result and only one comes back.
A chassis that wants a specific op's answer must let the acknowledge cycle complete between
commands — which is exactly the `FPS3K_SEQGAP` spacing the model already implements for a
different reason.

The neighbouring code at `$F048D8` is the documented bit-7 command arm, testing the latched
command's low five bits for `$14` (command waiting → `jsr $F052F8`) and `$13` (→ RTOS directive
`$12`, RESUME). So this region is the whole command lifecycle in one place: **arm, dispatch,
acknowledge, reply.**

### One reply per run, and a counting trap in the access log

Chasing why a two-op sequence ships only one reply produced a smaller result than expected and
a measurement caution that nearly cost another wrong claim.

**The counting trap first.** `grep -c " F04924$"` on an access log returns **5** for every run,
which looks like five executions. It is one instruction's **bus cycles**:

```
R 2 F04924 00003B79 F04924     ; opcode fetch
R 4 F04926 00000E74 F04924     ; operand fetch
R 2 000E74 00000010 F04924     ; the read of the result word
R 2 F0492A 00000204 F04924     ; operand fetch
W 2 FF0204 00000010 F04924     ; the write
```

The PC trace for the same run reports **1**. So `FPS3K_ACCESSLOG` counts *bus accesses* and
`-trace` counts *executions*, and a `grep -c` on the former is not an execution count. Every
"x5" in this session's access-log work meant "one execution of a 5-cycle instruction". *This
is the same shape as the earlier errors — a measure read as answering a question it does not
answer — caught this time before it reached a conclusion.*

**The finding, correctly counted.** In a two-op sequence (`01:105E,26:0000`), the PC trace
shows both handlers execute once each (`$F04CF2` op `$1`, `$F04EB8` op `$6`-read) and
`$F04924` executes **once**. In single-op runs `$F04924` also executes once. So the reply path
fires **once per run**, not once per command — which is why op `$6`'s correctly-read `2` sat in
`$0E74` unshipped while the first command's `$0000` went out.

**What this does and does not establish.** It confirms the observation and rules out the
simplest alternative explanation — that the second op never ran. It does **not** establish
where the limit lives. The model's sequence advance waits on the SBC setting MODE0 bit 10 and
that mechanism plainly works, since both commands were delivered and both handlers ran. So the
one-reply limit is somewhere between the second handler completing and the reply path being
re-entered, and I have not isolated it. *Stated as an open question rather than attributed to
the model, because the firmware may simply not reply to every op* — most op handlers end in
`bra ChannelConfigDispatch` (the ISR exit stub, 3,960 executions in that run) rather than
routing through `$F04924`, and which ops ship a reply is not something I have determined.

That distinction matters for anyone driving the machine: **"the chassis got no answer" may mean
the model dropped it, or may mean that operation does not answer.** Separating those needs a
per-op census of which handlers reach `$F04924`, which is a clean piece of work and not one I
have done.

### The direction bit measured in both states — and `$06` is destructive

Testing whether the chassis can read SBC memory produced the direction bit's meaning by
measurement rather than inference, and a trap worth recording.

**Attempt 1 — `FPS3K_SEQ="01:105E,06:0000"`.** Op `$1` set the address (`$0E58` reads back
`$0000105E`), then op `$6` ran. The prediction was a reply of `2`, since `$105E` is the
channel-present count and three XP tasks read it as `2` in the same log. Instead:

```
W 2 00105E 00000000  from PC=F04EC0        ; op $6 WROTE ZERO
```

**Command byte `$06` has bit 5 clear, and bit 5 clear means write.** The op did exactly what it
was told, and in doing so **zeroed the channel-present count** — which is the gate every XP
task checks (`cmpi.w #<own channel>,$105E / blt`). One malformed chassis command silently
disables all four XP tasks.

**Attempt 2 — `26:0000`, the same op with bit 5 set:**

```
R 2 00105E 00000002  from PC=F04EB8        ; READ, and got the right value
W 2 000E74 00000002  from PC=F04EB8        ; stored into the result word
```

**Exactly the prediction.** So the documented decode — *bit 5: 0 = write/store, 1 = read/return*
— is now confirmed in **both** states against a location whose value was independently known.

**Two things follow.**

*A practical hazard.* `$06` looks like the innocuous "read SBC RAM" op and is the natural thing
to type; it is a **destructive write of whatever `$E70` holds** to whatever `$E58` points at.
Anyone scripting chassis operations needs `$20` set on every read, and the failure is silent —
no error, no reject, just corrupted state that shows up much later as tasks mysteriously
gating off. That is worth a line in any chassis-driving documentation.

*The half-duplex gap again, from the other side.* The reply path `$F04924` ran **once** in this
run and shipped `$0000` — the result of the *first* command — while op `$6`'s `2` sat in
`$0E74` unshipped. So the model completes one reply cycle per sequence regardless of how many
commands it delivers. Combined with the earlier finding that nothing consumes the reply anyway,
the return direction is unmodelled at both ends: **not read by the chassis, and not re-armed
per command.**

*What is established regardless:* the SBC's side of the read path works end to end —
address → memory → result register — and the value is correct. Only the delivery of that
result back to a chassis model is missing, and that is a modelling gap rather than a firmware
question.

### VALIDATED IN EXECUTION: op `$B` returns `$0010`, exactly as derived

The whole chassis protocol was derived statically. Driving it settles it.

`FPS3K_RESP=0x94 FPS3K_XPIRQ=6 FPS3K_SEQ="0B:0000"` runs chassis op `$B` — documented as
*"return the staging base `$10010`"* — and the access log, which records PCs, shows the
complete round trip:

```
W 2 000E74 00000010  from PC=F05018     ; op $B's handler stores its answer
R 2 000E74 00000010  from PC=F04924     ; the reply path reads it
W 2 FF0204 00000010  from PC=F04924     ; and ships it to CHANNEL_SELECT
```

**`$0010` is the high half of `$00010010`** — the staging base, returned a half at a time as
command bit 6 selects. Every element of the derivation is confirmed by measurement:

| derived statically | observed |
|---|---|
| handlers store their answer in `$0E74` | `$F05018` writes `$0010` |
| `$F04924` ships `$0E74` to CHANNEL_SELECT | that exact read-then-write pair |
| the value is the operation's result | `$0010` = the documented `$10010`, high half |

**This is the measurement the retracted `$0E74` entry never had.** The mailbox claim was
reached by counting writes with a broken detector; this reading was reached by tracing the
data path and is now confirmed by watching the datum move. *The difference between the two is
not care — I was careful both times — it is that one made a prediction that execution could
check and the other did not.*

**One correction to the previous entry.** I wrote that `$F04910`-`$F04924` was a single reply
sequence. The trace shows `$F04910` executes **zero** times in this run while `$F04924`
executes once, so they are separate paths: the MODE0-acknowledge at `$F04910` belongs to the
bit-7=1 dispatcher (`$F0495C`, 468 entries here), and the result write is reached
independently. The reply consists of the CHANNEL_SELECT write; the acknowledge is a different
concern reached by a different route.

*And the `[REPLY]` log I added does not reliably catch it* — it fired once, on a panel-code
write from another path, and missed the real result. The gate was copied from the arming logic,
and MODE1 bit 12 is a beacon filter, not a reply marker. The model cannot see the PC, so the
reliable observation is `FPS3K_ACCESSLOG`. That caveat is now recorded in `versabus.c` beside
the log rather than left for someone to trip over.

### The emulated chassis is half-duplex: it never reads the SBC's replies

The protocol mapping has a direct consequence for the model, and it is a real gap.

`$FF0204` carries the SBC's answer — an op handler clears `$0E74`, stores its result there,
and `$F04924` ships it to CHANNEL_SELECT. **Every read-direction chassis op (`$3`, `$6` read,
`$A`, `$B`, `$C`) returns its data in that register.** In `versabus.c`:

- the write handler does `xltr.channel_select = val` (line 909);
- the only other reference to that field in the entire emulator is a **debug `printf`**
  (line 1751);
- and the *read* path returns a scripted value from `FPS3K_SEQ` or `FPS3K_CHSEL_RD`, unrelated
  to whatever the SBC last wrote.

So the two directions are disconnected. **The emulated chassis can command the SBC and write
its memory, but cannot read it** — the return path is not wired at all. That is why the
scripted-sequence work could program a transfer and verify it by dumping RAM, but never by
reading back through the protocol: there was nothing to read back *with*.

This is not a bug in the sense of producing wrong results — nothing currently asks for a
reply, so nothing is wrong. It is a **missing half of a modelled interface**, and it bounds
what the emulator can be used to demonstrate: any experiment of the form "ask the SBC for X
and check the answer" is unavailable, which includes the natural test of ops `$3`, `$A`, `$B`
and `$C`.

**Made visible, not fixed.** `FPS3K_LOGCHASSIS` now reports `[REPLY] SBC -> chassis: $xxxx
(op $N)` when a command is in flight, gated on the same MODE0-ACK and MODE1-bit-12 conditions
the arming logic uses. Verified inert: the default RAM digest is byte-identical either side
(`f72fb0a5…`). Wiring the value into a chassis model would be speculative while no consumer
exists — but a reply that is captured and logged is the prerequisite for one, and the gap is
now documented rather than latent.

*This is what the protocol work was for.* Six entries ago the chassis conversation was a set of
disconnected observations — a command byte, a jump table, some globals. Following it end to
end produced a testable statement about the emulator, and the test failed. **A protocol you
have fully traced tells you what your model is missing; one you have only sampled does not.**

### The chassis-protocol state model — `$E70` is the data register, `$E7A` is bounded 0..$C

Enumerating every protocol global with the validated tool gives the state an emulator needs to
carry between commands:

| global | refs | role |
|---|---|---|
| `$E58`/`$E5A` | 11 / 1 | transfer address, set by op `$1` (halves via command bit 6) |
| `$E5C` | 5 | CHANNEL_SELECT readback; tested for `$28` (the bulk gate) and `0` |
| `$E60` | 6 | validated channel, written by op `$5` (`XPSEL`) |
| `$E64`/`$E66` | 8 | transfer count, set by op `$2` |
| `$E68` | 2 | third parameter, set by op `$9` |
| **`$E70`** | **6** | **the data staging register — see below** |
| `$E74` | 37 | the operation result, shipped out via CHANNEL_SELECT |
| **`$E7A`** | **7** | **array index, bounds-checked `0..$C`** |
| `$E7C` | 1 | validated selector, latched by op `$D` |
| `$E86`/`$E87` | 8 / 22 | the command latch — one write in, then bit tests only |

**`$E70` completes the memory-access data path.** Its six references split exactly two ways:

```
$F04D96  [W] move.l (a1,d1.l),$e70    ; memory -> $E70
$F04DA0  [W] move.l (a1),$e70         ; memory -> $E70
$F04DCA  [W] move.w $204(a0),$e70     ; CHANNEL_SELECT -> $E70
$F04DA6  [R] move.w $e70,$e74         ; $E70 -> the result word
$F04E0A  [R] move.l $e70,(a1,d1.l)    ; $E70 -> memory
$F04E14  [R] move.l $e70,(a1)         ; $E70 -> memory
```

So ops `$3` (read chassis memory) and `$6` (read/write SBC RAM) move data through one
staging register, in whichever direction command bit 5 selects:

| direction | path |
|---|---|
| **read** | `(a1)` → `$E70` → `$E74` → `CHANNEL_SELECT` (out to the chassis) |
| **write** | `CHANNEL_SELECT` → `$E70` → `(a1)` (into memory) |

That is the whole mechanism by which the chassis reads and writes SBC memory, and it explains
why `$E74` is a *result* rather than a mailbox: on a read the datum passes through it on its
way out. The retraction two entries ago now has a positive account behind it.

**`$E7A` is bounded to `0..$C`.** `$F04FBA` and `$F04FC6` check `cmpi.l #$0` and `cmpi.l #$C`
before use, so the array op `$A` walks **13 entries maximum**. That is a concrete limit on a
structure whose extent was previously unrecorded — and it is checked on every access, not just
at reset, so a chassis that over-runs the index is rejected rather than allowed to walk off the
array.

The two `addq.l #$1,$e7a` sites are the auto-increment gated on command bit 4, and the single
`clr.w` is op `$D` resetting the walk — matching the bit-4 census above, where exactly four
ops test that bit.

### The command byte `$0E87`: 22 references, every one a bit test, and never written

Enumerating the latch with the validated tool gives a complete account of the chassis command
word:

| location | references | shape |
|---|---|---|
| `$0E86` (the word) | 8 | **7 reads, 1 write** — `$F04942 move.w d0,$e86.l`, the ISR latching it |
| `$0E87` (the low byte) | **22** | **every single one a `btst`** — never written, never read as a value |

The bit distribution confirms the documented command-byte decode independently, by usage:

| bit | `btst` sites | documented meaning |
|---|---|---|
| **7** | 2 | selects the other dispatcher (`$F0495C`) |
| **6** | **9** | half-select of a 32-bit parameter |
| **5** | 6 | direction — 0 = write/store, 1 = read/return |
| **4** | 4 | auto-increment the index `$E7A` |
| 0-3 | **0** | the operation — extracted by masking, not bit-testing |

Two things this settles.

**Bits 0-3 are never `btst`'d, and that is exactly right.** They carry the 4-bit operation
that indexes the 16-entry jump table, and the dispatcher extracts them with `(code & $F) << 2`
rather than testing them individually. A bit census that found *no* references to the
operation field would look like a gap; here it is positive evidence that the field is used as
a **number**, not as flags — and the two access styles cleanly partition the byte.

**The frequencies match the semantics.** Bit 6 (half-select) is tested **nine** times, the most
of any bit — which follows from `$1`, `$2` and `$9` all taking 32-bit parameters that arrive
one half per command, plus the `$3` and `$6` memory ops. Bit 4 (auto-increment) is tested
four times, once per op that walks an array. Bit 7 twice: once in RDHC's main loop
(`$F04740`, the documented `btst #7,$E87 / bne` wait) and once in the ISR at `$F04950`.

**And the whole latch is written exactly once**, at `$F04942`, by the ISR that received it.
Nothing else in the firmware modifies the command word — it is captured on arrival and then
only interrogated, which is what one wants of a value that must stay stable across a
dispatcher, a handler and a reply. Combined with the reply path above, the chassis protocol is
now closed on both sides: **one write in, one write out, everything between is inspection.**

### `$0E74` is the chassis-op RETURN VALUE, and CHANNEL_SELECT is the reply register

The read-out site the validated enumerator surfaced — `$F04924 [R] move.w $e74.l,$204(a5)` —
turns out to be the last step of the chassis reply sequence, and it completes the
request/response protocol:

```
$F04910:  move.w $e86.l,d1           ; the LATCHED command word
$F04916:  bclr.b #$a,d1              ; clear bit 10 -- acknowledge it
$F0491A:  move.w d1,$200(a5)         ; write it back to XLTR_MODE0
$F0491E:  move.w #$5e,$230(a5)       ; re-arm BIM0 ch0 (level 6, IRE set)
$F04924:  move.w $e74.l,$204(a5)     ; SEND THE RESULT to CHANNEL_SELECT
$F0492C:  bra    loc_F04736          ; back to RDHC's wait
```

So the full conversation is:

| direction | carrier |
|---|---|
| **chassis → SBC** | command byte in the **low byte of `XLTR_MODE0`**, latched at `$E86`/`$E87`, delivered by a **BIM0 ch0 interrupt** (vector `$41`, handler `$F04930`) |
| **SBC → chassis** | result word in **`$0E74`**, written to **`CHANNEL_SELECT`**; the command is acknowledged by clearing **MODE0 bit 10** |

**That is what `$0E74` is**: the op handlers clear it on entry (the 22 immediate zero-writes),
store their answer into it (the 11 register-sourced writes, including `move usp,a1 / swap /
move.w d1,$0E74` returning the user stack pointer's high half), and this site ships it back.
The `cmpi.w #$25A,$0E74` in RDHC's main loop is the firmware inspecting a *result* before
replying — exactly as the retraction guessed, now with the outbound site to support it.

**It also explains `CHANNEL_SELECT`'s double life.** `$FF0204` is the most-written register on
the board and this project has recorded two unrelated uses: the self-test's **phase beacon**
(`d6` with its low byte cleared) and the service path's **channel selection**. It is neither,
exactly — it is the SBC's general **outbound word to the chassis**, carrying whatever the SBC
currently has to say: a phase number during power-on, an operation result in service. The
~33k writes against 7 reads follow directly from that being the machine's only reply channel.

*And the retraction paid for itself.* Withdrawing the mailbox claim forced building a tool
that could enumerate references correctly, and the first thing that tool found was the read
that identifies `$0E74` properly. **The wrong answer was reached by a broken method that
happened to look thorough; the right one came from fixing the method rather than re-examining
the conclusion.**

### `tools/refs.py`: stop hand-decoding opcodes — and it settles `$10AA` vs `$0E74`

Six times this session I hand-decoded 68000 opcodes to enumerate references, and six times the
decoder was too narrow: wrong addressing mode, wrong source operand, wrong instruction form,
data mistaken for code. The disassembler had already solved that problem correctly. **`tools/refs.py`
parses its operand text instead**, classifying each reference by which side of the comma the
address sits on (`R` source, `W` destination, `RMW`, `T` test), stripping `[SYMBOL]`
annotations, resolving base registers, and skipping `lea`/`pea` and `DC.W` lines.

**Validated against four controls before use**, which is the practice these failures earned:

| control | expected | result |
|---|---|---|
| `$FF0048` | the `$F07EF6` read an absolute scan misses | **found**, `[R] move.w $48(a5),$1068.l` |
| `$0E74` | register-sourced writes my hand-decoder missed | **found**, 37 refs incl. `[W] move.w d1,$e74.l` |
| `$FF0204` | writes ≫ reads | **13 refs**, writes and tests |
| `$10AA` | documented as never a named write target | **1 ref**, a read |

It immediately surfaced a form I had not thought to look for at all —
`move.w (a7,d0.w),$e74.l`, an indexed-from-stack write — and a read that matters:
`$F04924 [R] move.w $e74.l,$204(a5)`, sending `$0E74`'s value **out to CHANNEL_SELECT**.

**And it settles why `$10AA` and `$0E74` looked alike but are not.** `$10AA` has **exactly one**
reference in the whole ROM and it is a *read* — the firmware never names it as a write
destination, which is precisely the documented conclusion reached independently by a runtime
write-watchpoint. `$0E74` has **eleven** named register-sourced writes. My broken detector saw
"only zero writes" for both because it counted only immediate stores; the validated tool
separates them cleanly. **So the `$10AA` off-board finding is now confirmed by a second
independent method, and my `$0E74` claim was specific error rather than a flaw in the
analogy.**

*One honest limitation:* the tool clears base registers at every `rts`/`rte`/`jmp`/`bra`, so a
base established in a caller and used after a branch is dropped. It reports **1** site for
`$FF0048` where the looser scoped sweep reported 13. **Counts are lower bounds**, deliberately
— after six false negatives from over-narrow detectors and one false positive flood from an
over-broad one, a tool that under-reports and says so is the useful failure direction.

### RETRACTED: `$0E74` is NOT a chassis mailbox — it is an op RESULT word

*The entry that stood here claimed `$0E74` was written only from off-board, on the `$10AA`
pattern. It is wrong and is withdrawn in full.*

The claim rested on enumerating writes and finding 22, all zero. That enumeration only
counted **immediate-source** stores (`move.w #imm,abs`). `$0E74` also has **11
register-sourced writes**, which are plainly nonzero:

```
$F04A0E:  move   usp,a1
          move.l a1,d1
          swap   d1
$F04A14:  move.w d1,$e74.l          ; the HIGH HALF OF THE USER STACK POINTER
$F04DA6:  move.w $e70.l,$e74.l      ; copied from another global
```

So the firmware writes `$0E74` with register values and with other globals' contents. It is
not chassis-written, and the `$10AA` analogy does not hold.

**What it actually looks like:** a **result word for the chassis-op handlers.** The handlers
clear it on entry (that is what the 22 immediate zero-writes are — one per op path) and store
an answer into it before returning; `move usp,a1 / swap / move.w d1,$0E74` is a handler
returning the user stack pointer's high half to whatever asked. The `cmpi.w #$25A,$0E74` at
`$F0475E` is then RDHC testing a *result*, not a posted code. That reading is consistent with
every site but I am not asserting it with the confidence of the retracted claim.

**How the error happened, precisely.** In the same entry I wrote *"the check was necessary,
not decorative"* about having tested absolute-**short** addressing. That check was real — but
absolute-short is a different **addressing mode for the same instruction**, whereas the writes
I missed use a different **source operand**. Having checked one axis thoroughly, I treated the
enumeration as complete. **Coverage along one dimension reads as coverage, and is not.**

*This is the sixth instance of the pattern this session and by far the most damaging*, because
unlike the earlier ones it produced a confident, structured, committed finding with an
attractive story — a second instance of a known mechanism — rather than an obviously-empty
result. **A false negative that confirms an existing hypothesis is much harder to notice than
one that contradicts it**, and that is the real lesson here: I stopped checking when the answer
started agreeing with something I already believed.

The detector that produced it has the same flaw and its other output is unreliable for the
same reason: it flagged `$0E58`, `$0E5C` and `$0E7A` alongside `$0E74`, and did **not** flag
`$10AA`, the one global known to fit the pattern — because `$10AA`'s zero-writes come from a
bulk-clear loop rather than immediate stores. A detector that misses its own control and
flags four cases, one of which is demonstrably wrong, has established nothing. **No mailbox
sweep is claimed.**

### A definitive panel-code census: 41 codes, 154 sites, 50 unused

With the code map available, the panel codes can finally be counted rather than inferred.
Scanning **only code addresses**, and both emission forms — `move.w #imm,d0` (`303C`) and
`move.l #imm,d0` (`203C`):

**41 distinct codes across 158 emission sites**, and 50 of the values in `$258`-`$2B2` are
never emitted at all. Three instruction forms produce them:

| form | sites |
|---|---|
| `move.w #imm,d0` | 151 |
| `addi.w #imm,d1` | **4** — all `$264`, one per XP task, with `d1` holding the channel |
| `move.l #imm,d0` | **3** — `$281`, `$282` and one other |

`$264` is the only code produced by **two different forms**, which is exactly what the
existing note describes: *"`$264` — two per task, one of them `addi.w #$264,d1` with `d1` =
the channel"*. The census recovers that independently.

The structural pattern is the useful part:

| shape | codes |
|---|---|
| **1 per XP task** (4 sites at `$A00` stride) | `$262`, `$263`, `$264`, `$269`, `$270` |
| **2 per XP task** (8 sites) | `$26E`, `$271` |
| heavily replicated | `$26C` ×45, `$26A` ×20, `$26B` ×10 |
| single site | 22 codes, including all nine `$29E`-`$2A6` exception reporters |

`$26C` at **45 sites** is the most-emitted code in the firmware by a wide margin — consistent
with its being `PCMD_RELEASE`, the `D2_FIN` finalize code every completed operation ends with.

**Two methodological corrections came out of building this.**

*A `move.w`-only scan misses seven sites across three forms*, including `$281` and `$282` —
the two host-protocol codes central to the byte handshake. They are emitted as `move.l #$281,d0` (`203C 0000 0281`),
so a scan keyed on `303C` reports the host protocol as having no emission sites at all. I
caught this only because I knew independently that `$281` had to exist; a code I had no prior
reason to expect would have been silently absent. **Instruction-form assumptions are the same
class of error as address-form assumptions**, and this session has now hit both.

**And the scan written to catch form-assumptions contained one.** My first attempt at the
all-forms sweep pre-filtered on `the word at a+2 is in range` before dispatching on the
opcode — which excludes `move.l #imm,d0` entirely, because for `203C 0000 0281` the word at
`a+2` is `$0000`. The scan built specifically to find instruction-form blind spots was blind
to the very form that motivated it, and reported 156 sites where the answer is 158. *Fifth
instance this session of a filter encoding the assumption it was meant to test.* The pattern
is specific enough now to state as a rule: **a pre-filter must not read the operand until the
opcode has told it where the operand is.**

*Regional attribution near task boundaries is unreliable and should not be used.* My first
census reported `$26E` in "IO1I ×2 + XP2I/3I/4I ×2" and `$271` in "XP1I ×2 + XP2I/3I/4I ×2",
an apparent asymmetry contradicting the established finding that all four XP tasks emit an
identical multiset. The site addresses settle it — `$26E` is at `$F05F92, $F05FC8, $F06992,
$F069C8, $F07392, $F073C8, $F07D92, $F07DC8`: **four pairs at exactly `$A00` stride**, one per
XP task. The first pair sits `$86` below XP4I's nominal body start and so falls in IO1I's
range. Identical to the `$92`-byte misattribution already documented for the `$2D` directive
sites. **Report structure (stride, pairing) rather than region membership**; the strides are
exact and the boundaries are not.

### The `$25D`-`$260` block settled: rejects and drain-completions, and `$FF0000` is a count

Following through on the previous entry rather than leaving the block half-corrected, every
site decodes:

| code | real sites | what each one is |
|---|---|---|
| `$25D` | 2 | **range rejects** — `CHANNEL_SELECT` outside `0..$F` |
| `$25E` | 1 | emitted then `bra ChannelConfigDispatch` — see the correction below |
| `$25F` | 2 | one **drain-completion**, one **S-record type reject** (`$5339` = `'S9'`) |
| `$260` | 2 | one **drain-completion**, one reject arm |
| `$261` | 0 | unused |

**So the block is a reject/completion family, and the "per-channel config" label is wrong for
all four codes** — not just `$25D`. The site counts are 2/1/2/2 with `$261` unused, which no
one-code-per-channel scheme produces.

**CORRECTION, made immediately after: my `$25E` dismissal was itself wrong.** I claimed the
site at `$F05142` was a false positive lying "inside the 16-entry `jmp` table". The table is
16 entries of 4 bytes starting at `$F05102`, so it ends at **`$F05141`** — and `$F05142` is
the first byte *after* it, and is genuine code:

```
$F05142:  move.w #$25e,d0
$F05146:  jsr    PanelIOConfigure_25A
$F0514C:  bra    ChannelConfigDispatch
```

So `$25E` has **one real site**, and only `$261` is genuinely unused. I dismissed a real
finding by asserting an address was data without checking — the *inverse* of the error I was
correcting in the same paragraph, and made while writing the sentence warning about it.

*This was caught by the code map built in the next entry, within minutes of writing it*, which
is the strongest argument for that tool: the first thing it did was contradict its author.

**`$FF0000` is polled as a signed remaining-count.** Both drain-completion sites share a shape:

```
.loop:  cmpi.w #$0,$0(a1)      ; a1 = $FF0000
        ble    .exit            ; leave when it goes <= 0
        move.w (a0),d0          ; read the port and DISCARD
        bra    .loop
.exit:  move.w #$25f,d0         ; (or $260)
```

The loop consumes from `(a0)` **while `$FF0000` stays positive**, discarding every word, and
emits a completion code when it reaches zero or goes negative. That gives `$FF0000` — which
the device map records only as "read, 3-4 sites" — a concrete role: **a count the chassis
presents, decrementing as words are taken**, with its sign as the exhausted flag.

It also makes this the *second* discard-drain in the firmware, alongside `$F0517E` found
earlier. Both read a port and never store the value; the difference is where the terminating
count lives — `d4` in `$F0517E`, the chassis-side `$FF0000` here. **The machine has two
draining mechanisms, one SBC-counted and one chassis-counted**, which is a distinction worth
having when modelling a transfer that must be abandoned.

### Chassis ops `$C` and `$D` decoded — and `$25D` is a reject, not a per-channel config

RDHC's second-largest gap, `$F05066-$F050D6`, is the tail of chassis op `$C` and the whole of
op `$D`.

**Op `$C` writes a 32-bit parameter into the array at `$101E`, half at a time**, and it
implements the command-byte bits literally:

```
bne    .low
move.w $204(a0),$1020(a1)      ; CHANNEL_SELECT -> low half
bra    .done
.low:
move.w $204(a0),$101e(a1)      ; CHANNEL_SELECT -> high half
.done:
move.w #$0,$e74
btst.b #$4,$e87                ; the AUTO-INCREMENT bit of the command byte
beq    .no_inc
addq.l #$1,$e7a                ; bump the array index
```

That is the documented command-byte decode executing: **bit 4 = auto-increment `$E7A`**, bit 6
selecting which half of the longword receives `CHANNEL_SELECT`. The array at `$1020` was
recorded as a *read* path; it is written here too.

**Op `$D` validates `CHANNEL_SELECT` in `0..$F`**, and on success resets the index and latches
the value:

```
cmpi.w #$0,$204(a0)  ;  blt  .reject
cmpi.w #$f,$204(a0)  ;  ble  .ok
.reject:  move.w #$25d,d0  ;  jsr PanelIOConfigure_25A
.ok:      clr.w   $e7a           ; reset the array index
          move.w  $204(a0),$e7c  ; latch the validated selector
          move.w  #$0,$e74
```

`$E7C` is a global this project has not recorded before: **the validated chassis selector**.

**Correction: `$25D` is a range-reject code.** The panel-code table lists `$25D`-`$260` as
`PCMD_CH{1..4}_CONFIG`, "per-channel config", reasoning that *"`$261` is used nowhere,
consistent with `$25D`-`$260` being the four per-channel config codes."* The call sites do not
support it:

| code | sites | context |
|---|---|---|
| **`$25D`** | **2** | **both immediately after a `ble.b` — the out-of-range arm** |
| `$25E` | 1 | |
| `$25F` | 2 | both after `bra.b` |
| `$260` | 2 | both after `bra.b` |
| `$261` | **0** | (the absence the inference rested on) |

A per-channel scheme would give one site per code. `$25D` has two, both on validation-failure
arms of range checks (`$F04FD2` and `$F050A2`), which is a **reject** and not a configuration.
The `$261` absence is real but supports nothing on its own — an unused code is equally
consistent with a reject family that happens to have four members.

**This is the second per-channel grouping in that table to fail.** The `$26D`-`$271` block was
already retracted — *"`$26E` is not a channel code at all; all four XP tasks emit the identical
multiset, so none of them can identify a channel; they index the RTOS directive that failed."*
Same shape here: codes that look channel-indexed turn out to index a **failure reason**. The
table's per-channel readings should be treated as unverified wherever they were inferred from
code adjacency rather than from a call site. I have decoded only `$25D`'s sites; `$25E`-`$260`
remain open, and I am not extending the correction to them without doing the same work.

### `PanelErrorMaskTable` decodes `XLTR_IRQ_MASK`: channel 1-4 are bits 5,4,3,2

RDHC's largest undocumented run, `$F05900-$F0597A`, is the **transfer teardown path**, and
decoding it gives `PanelErrorMaskTable` its first concrete role.

```
cmpi.l #$0,d5  ;  bne .not_done
move.w #$26c,d0  ;  jsr PanelIOConfigure_25A     ; PCMD_RELEASE -- the D2_FIN finalize code
.not_done:
btst.b #$d,d4  ;  beq .normal
move.w #$26a,d0  ;  jsr PanelIOConfigure_25A     ; PCMD_TIMEOUT_ABORT
move.w $21a(a4),d0                               ; read XLTR_IRQ_MASK
move.w (a7)+,d4                                  ; restore the operation/channel
lea    PanelErrorMaskTable,a5                    ; = $F05C4C
clr.l  d5
move.b (a5,d4.w),d5                              ; TABLE LOOKUP -> a BIT NUMBER
bclr.b d5,d0                                     ; clear that bit in the mask
move.w d0,$21a(a4)                               ; write XLTR_IRQ_MASK back
move.w #$5f,(a3)                                 ; BIM CR <- $5F, re-enabling the channel
rts
```

**The table is five bytes and fully readable.** It sits immediately after
`PanelStatusDispatchTable` (`$F05BA4` + 42x4 = `$F05C4C`), and holds:

| index | value |
|---|---|
| 0 | `$00` — unused; channels are 1-based |
| **1** | **`$05`** |
| **2** | **`$04`** |
| **3** | **`$03`** |
| **4** | **`$02`** |
| 5+ | `$00` |

So `d4` is a **channel number 1-4**, and the value is the bit to clear in `XLTR_IRQ_MASK`.
**This is the first bit-level decode of `$FF021A`**, which this project has only ever
recorded as "written `$FFF`":

```
$FF021A  XLTR_IRQ_MASK   bit 5 = channel 1
                         bit 4 = channel 2
                         bit 3 = channel 3
                         bit 2 = channel 4
```

**The order is descending, which is worth flagging** — channel 1 takes the *highest* of the
four bits. Nothing else in the machine numbers channels that way: the AP I/F windows ascend
(`ch1` at `$FF0040`, `ch4` at `$FF00A0`), and the BIM control registers ascend too
(`$FF0244`, `$46`, `$50`, `$52`). Anyone inferring the mask layout by analogy would get it
backwards, which is presumably why a table exists rather than arithmetic.

The path as a whole reads cleanly: on completion, issue `$26C` RELEASE if the count reached
zero; on timeout (bit 13 of `d4`), issue `$26A` TIMEOUT_ABORT, **disable that channel's
interrupt** via the table, and restore its BIM control register to `$5F`. That `$5F` is the
documented IRE-enabled value whose IRE-cleared partner `$4F` suppresses a channel during a
transfer — so the teardown re-arms the channel it just finished with, while masking it at the
XLTR level if it errored. Two independent disable mechanisms, used for different reasons.

### Where documentation actually stands: 59% covered, and the frontier is RDHC + RTOS init

Counting in-place annotations alone gives 33% of instruction bytes, which understates things
in two specific ways. Correcting both:

**1. Template copies.** 6,928 undocumented bytes lie in the four XP task regions, and
**5,808 of them (83%) have an annotated sibling** at ±`$A00`/`$1400`/`$1E00`. That is the
*same code*, already understood, simply not annotated on every copy. It is 38% of all
undocumented bytes.

**2. Zero padding**, removed above: 392 bytes that were never instructions.

With both accounted for:

| region | bytes | covered | frontier |
|---|---|---|---|
| RDHC | 5,292 | 48% | **2,706** |
| IO1I | 580 | 28% | 416 |
| XP4I / XP3I / XP2I / XP1I | ~2,300 each | **86-89%** | 250-320 each |
| self-test | 5,036 | 30% | **3,486** |
| RTOS init | 2,280 | 39% | 1,382 |
| pre-task | 120 | 35% | 78 |
| **total** | **22,588** | **59%** | **9,188** |

**The self-test's 3,486-byte "frontier" is misleading and worth being explicit about.** All
42 of its subroutines are decoded — that work is in *this file*, not as `;###` notes in
`fps3k.asm`. The same is partly true of RDHC. So a large share of what this table calls
frontier is **analysis that exists but has not been propagated into the disassembly**.

That splits the remaining work cleanly, which is the useful part:

- **Mechanical (no new analysis):** propagate this file's findings into `fps3k.asm` as `;###`
  notes, and replicate XP annotations across the three sibling copies. That alone would take
  in-place coverage from 59% toward ~85%.
- **Genuinely unexplored:** RDHC's 2,706 bytes and RTOS init's 1,382 — about **4,100 bytes,
  18% of the ROM's real instructions**. RDHC being the largest is consistent with everything
  else known about it: it is the master task, the least executed (1% before this project
  unblocked it, 47% after), and the one whose behaviour depends on a chassis conversation.

The XP tasks at 86-89% are the best-covered region by a wide margin — which follows from
their being template copies of one another, so every finding applies four times.

*The 33% figure was not wrong, it answered a different question:* "how much of the asm carries
a note?" rather than "how much of the machine do we understand?" Both are worth knowing, and
conflating them would have pointed the next session at the wrong 9,000 bytes.

### Zero padding in the instruction count, and what the largest run proves

Looking for the biggest undocumented stretches of code, the top hit was 214 bytes in RDHC at
`$F05C5C` — which turned out to be **zero fill**, decoded by the disassembler as
`ori.b #$0,d0` (opcode `0000 0000`). The measure was ranking disassembler artifacts.

Quantified across `fps3k.asm`:

| | bytes |
|---|---|
| lines counted as instructions | 22,980 |
| all-zero `ori.b #$0,d0` | **392 (1.7%)** |
| genuine instruction bytes | **22,588** |

So the coverage denominator this project quotes is slightly generous: **54% of instruction
bytes executed becomes 55%** against the corrected figure. A small correction, and worth
recording as small — I expected it to be larger and checked rather than assumed, which is
the only reason the number is trustworthy either way.

**22 zero-padding runs exist, and the largest is structurally informative.**
`$F05C54-$F05CFF` is 172 bytes of zero fill, and the next decoded instruction is at
**`$F05D00`** — exactly the TDTI table's declared start for TCBIO1I. RDHC's real code ends
at `$F05C54`; everything after it is fill to the task boundary.

*That confirms the TDTI region boundaries are genuine allocation boundaries rather than
labels this project imposed.* The task extents come from the ROM's own `!TCB` table at
`$F0A600`, and here the code layout independently agrees with them: the assembler padded
RDHC out to the boundary the table declares. Region bounds elsewhere in this project are
approximate (they misattributed the `$2D` sites by `$92` bytes), so having one confirmed
exactly is worth knowing.

The second-largest run, `$F09BC6-$F09BFA` (56 bytes), is the unused tail of the SCM pattern
table at `$F09BB6` — consistent with that table holding two complementary longword pairs and
then nothing, which is how it was read when decoding `$F09B20`.

*Method note:* this is the third measurement this session distorted by treating decoded
output as ground truth — after the `$400000-$7FFFFF` opcode flood and the `[SYMBOL]`
annotation breaking direction detection. **A disassembler emits a decode for every byte;
whether those bytes are instructions is a separate question it cannot answer.**

### Task-region tally: 42 call targets, and the last nine resolve into four routines

Applying the self-test's inventory method to the six task regions gives 42 distinct call
targets, of which 33 were already documented. The nine gaps are not nine routines — they are
**four**, template-replicated at the `$A00` XP stride:

| routine | copies | what it is |
|---|---|---|
| `$F0517E` | RDHC only | **polled bulk-read that DISCARDS** — new, see below |
| `$F070AA` / `$F07AAA` / … | per XP task | channel validator, reject code **`$263`** |
| `$F07150` / `$F07B50` / `$F08550` | per XP task | channel validator, reject code **`$264`** |
| `$F07216` / `$F07C16` | XP2I, XP3I | the **bit-11 test** path |

**`$F0517E` is a fourth transfer primitive.** It runs the documented bulk cycle — arm
`XLTR_STATUS_IRQ` with `$400`, poll bit 15, clear it, read the port — but:

```
move.w (a0),d1        ; read a word...
addq.l #$1,d0         ; ...count it
subq.w #$1,d4         ; ...decrement the remaining count
cmpi.w #$0,d4  ;  bne loop
```

**`d1` is never stored anywhere.** Where `BLK_XFR` moves channel→memory and `POLL` moves
memory→channel, this consumes N words and throws them away. It is a **drain/flush**: the
primitive for discarding a pending transfer without a destination buffer. That makes the
transfer set four operations, not three — two movers, a sender, a finalizer, and now a
discarder.

**The gap distribution independently confirms a documented asymmetry.** XP2I and XP3I each
had three gaps; XP4I and XP1I had one apiece. That is exactly what the bit-11 finding
predicts: this file already records that *"`$C801` sets bit 11, which XP1I/2/3 test to take a
short branch, and XP4I (which never tests bit 11) is unaffected"*. XP4I is missing the bit-11
routine entirely, so it cannot appear as a gap there — **a claim about branch behaviour,
made from execution counts months ago, reappearing as a structural fact in a subroutine
census.** Two unrelated methods, same asymmetry.

*(XP1I's single gap is its `$264` validator at `$F08550`; its `$263` and bit-11 copies were
already documented, which is why its count is low for a different reason than XP4I's.)*

With these four decoded, **both inventories are complete**: 42/42 self-test subroutines and
42/42 task-region call targets.

### `$F09A7E` is a DRAM refresh test — fill, wait 0.7 s, verify

Auditing my own labels after the `$F089EE` correction, this was the other one asserted from
too few instructions. Decoded properly it is the most physically interesting stage in the
suite:

```
move.l  #$09abcdef,d0            ; a fixed pattern
movea.l a0,a2                    ; remember the start
.fill:  move.l d0,(a0)+
        cmpa.l #$1fff0,a0  ; bne .  ; lea $4(a0),a0     ; skip the register longword
        cmpa.l a0,a1       ; bne .fill

move.l  #$000493e0,d5            ; 300,000
.delay: subq.l #$1,d5  ;  bne .delay      ; BUSY-WAIT, nothing else

.verify: cmp.l (a2)+,d0
         beq   ok
         move.l #$F0F0F0F0,d7    ; the pattern did NOT survive
```

**Fill memory with a pattern, do nothing at all for 300,000 iterations, then check the
pattern is still there.** At 18 cycles per iteration (`subq.l` 8 + `bne.b` taken 10) that is
**5,400,000 cycles = 0.675 seconds** at 8 MHz.

That is a **DRAM data-retention test**, and the duration is the point: unrefreshed dynamic
RAM loses charge in milliseconds, so data surviving two-thirds of a second proves the
**refresh circuitry is running**. No other stage tests this — the address-line, pattern and
rotating-pattern tests all read back immediately, where a dead refresh would pass.

Two consequences.

**It accounts for a large share of boot time.** 5.4 M cycles of pure busy-wait is roughly 4%
of the 120 M cycles a full boot takes, spent deliberately doing nothing.

**It is a constraint the emulator satisfies trivially and hardware might not.** A `ram[]`
array retains contents perfectly across any delay, so this stage cannot fail in emulation —
which means *a green emulator boot says nothing whatever about refresh*, and this is one more
entry for the "known divergences" list: the model cannot reproduce the failure mode the stage
exists to catch.

*It also contributes two of the eight `$1FFF0` exclusions* — `$F09A94` in the fill loop and
`$F09ABC` in the verify loop — so the register longword is skipped consistently on both
passes, which is what one would expect of a genuine exclusion rather than an accident.

**On the labels themselves.** Both corrections this round came from summaries I wrote after
reading four to eight instructions and inferring the rest from context. The pattern is worth
naming: *a routine's first few instructions establish its setup, not its purpose* — the
purpose is usually in the loop body and the failure branch, which is exactly what a short
read misses.

### What `$F089EE` actually probes — correcting a vague label

I first described `$F089EE` as a "chassis handshake probe". That was wrong enough to be
misleading. What it does, exactly:

```
lea    $1fff0,a5  ;  lea $f70018,a4
bclr.b #$6,$1(a5)              ; clear VMOD bit 6
move.w #$1000,$202(a6)         ; XLTR_MODE1 <- bit 12 set

move.w (a4),d2                 ; read the board-status WORD
btst   #$4,d2  ;  beq  .do_it  ; bit 4 clear -> proceed
btst   #$5,d2  ;  bne  .abort  ; bit 4 set AND bit 5 set -> abort

.do_it:
move.l d0,(a0)                 ; WRITE a longword
cmp.l  (a0),d0                 ; READ IT BACK and compare
beq    .recheck
move.l #$F0F0F0F0,d7           ; mismatch -> FAIL
move.w d1,$202(a6)             ; restore MODE1
bclr.b #$6,$1(a5)

.recheck:
move.w (a4),d2                 ; read board status AGAIN
btst   #$4,d2  ;  beq  ...
btst   #$5,d2  ;  bne  .abort
```

**It is a longword write/read-back test whose access is bracketed by a status check** — the
same two bits examined immediately before and immediately after the memory access. That
bracketing is the signature of an **error-status check**: perform the access, then ask the
hardware whether it faulted.

Precisely, it probes: *does a longword written to `(a0)` read back identically, with the
board reporting ready-and-no-error both before and after?*

Three details worth being exact about:

- **The bits are `$F70019` bits 4 and 5, not `$F70018`.** `move.w (a4),d2` loads `$F70018`
  into d2's bits 8-15 and `$F70019` into bits 0-7, so `btst #4,d2` and `btst #5,d2` reach
  the **low** byte. Those are the documented busy/ready bit and the `$D0`-checkpoint bit.
- **The gate is asymmetric.** Bit 4 clear proceeds immediately; only bit 4 **and** bit 5 set
  aborts. So bit 4 alone is not a stop condition — it is "busy", qualified by bit 5.
- **`XLTR_MODE1 <- $1000`** (bit 12) is set before the access and restored from `d1` on the
  failure path, so the XLTR is put into a specific mode *for the duration of the access* —
  which is why this helper exists rather than the test doing the `move.l` inline.

**Where it is called from matters**: `$F099D8` (the DRAM path) and `$F09B62` / `$F09B7C`
(both inside the SCM pattern test). In two of three call sites `(a0)` is **chassis memory
behind the `$400000` window**, which makes the bracketing check a *chassis access-error
status* rather than a local-bus one — the firmware verifying that a write which crossed the
XLTR actually landed, and that the far side reported no error either side of it.

*The correction matters beyond the label:* "handshake probe" suggests a protocol exchange with
no data, when this is a data-integrity test with an error-status gate. Anyone modelling
`$F70019` bits 4/5 from the wrong description would have modelled a handshake sequence instead
of an error indication.

### Generalising the discriminator: every address the memory tests refuse to touch

The `$1FFF0` skip is not a one-off. Scanning the whole ROM for `cmpa.l #imm,aN` followed by a
short branch over a pointer bump — the "skip this address" idiom — finds **eight** such sites,
and their targets are startlingly concentrated:

| skipped address | sites | |
|---|---|---|
| **`$01FFF0`** | **7** | `$F098FE`, `$F09916`, `$F09946`, `$F09960`, `$F099BE`, `$F09A94`, `$F09ABC` |
| `$01FFF4` | 1 | `$F099E0` |
| `$000400` | 2 | `$F09D06`, `$F09F2C` — the top of the exception vector table |

**Seven independent memory-test routines each hard-code an exclusion for `$1FFF0`.** Written
once, that is a hint; written seven times across separate walkers, it is the firmware stating
plainly that this longword must not be written with test patterns. Combined with the pattern
test's `-$20` back-off, that is **eight independent exclusions of one address** — and this is
now the best-evidenced fact in the whole VMOD discussion.

**Equally telling is what is absent.** There is no skip anywhere in the ROM for `$1FFE2`,
`$1FFE4` or `$1FFE6`. Seven routines took the trouble to special-case `$1FFF0`; not one
mentions the others. That independently confirms the retraction above — had those been
registers, the same authors who guarded `$1FFF0` seven times would have guarded them too.

`$000400` being skipped twice is a nice confirmation of an unrelated boundary: it is the end
of the 68000 exception vector table, and a memory test that clobbered vectors while running
with interrupts enabled would destroy itself. `$01FFF4`'s single exclusion is weaker
evidence and sits oddly against that address being walked by `$F098FC` and read-modify-written
as a counter at `$F0897C` — most likely a different routine's boundary rather than a second
register, and not something the ROM lets us settle.

**The resulting RAM/register partition of the 128 KB**, derived entirely from the firmware's
own behaviour rather than from any manual:

```
$000000-$0003FF   vector table    -- excluded by 2 routines (contents, not hardware)
$000400-$01FFEF   ordinary RAM    -- walked and verified by every test
$01FFF0-$01FFF3   REGISTER        -- excluded by 8 independent sites
$01FFF4-$01FFFF   ordinary RAM    -- walked (one routine's boundary at $1FFF4)
```

*Method note:* this is the same technique that produced the earlier over-claim, applied
correctly. The difference is that the question asked was "**where else** does this idiom
appear?" rather than "does my hypothesis have support?" — the first enumerates and lets the
distribution speak, the second stops at the first confirming instance.

### RESOLVED: the register block is `$1FFF0-$1FFF3`, and three of my four candidates are RAM

The address-line walker settles this, because it contains a hard-coded special case:

```
$F098FC:  move.l a0,(a0)+          ; write each address its own value
$F098FE:  cmpa.l #$1fff0,a0        ; did we just reach $1FFF0?
$F09904:  bne    $F0990A
$F09906:  lea    $4(a0),a0         ; YES -- SKIP THIS LONGWORD ENTIRELY
$F0990A:  cmpa.l a0,a1  ;  bne loop
```

**A branch in the middle of a tight loop, coded solely to avoid one longword.** That is far
stronger evidence than the `-$20` range back-off in the pattern test: nobody adds a special
case to a memory walker to protect scratch. `$1FFF0-$1FFF3` is protected by **both** memory
tests, independently.

The corollary is the part that corrects me. The walker writes **longwords**, so every
4-byte-aligned slot it does *not* skip has its whole longword overwritten and read back:

| address | walked? | consequence |
|---|---|---|
| `$1FFE0`-`$1FFEF` | **yes** (`E0, E4, E8, EC`) | must read back arbitrary written values → **behaves as RAM** |
| **`$1FFF0`-`$1FFF3`** | **no — explicitly skipped** | the register block |
| `$1FFF4`-`$1FFFF` | **yes** (`F4, F8, FC`) | behaves as RAM |

So of the four write-only locations I proposed as registers two entries above:

- **`$1FFF2` survives** — it lies inside the skipped longword, is written and never read, and
  is protected by both tests. The VERSAmodule register block really is **larger than the two
  documented bytes**: it is `$1FFF0-$1FFF3`.
- **`$1FFE2`, `$1FFE4`, `$1FFE6` are retracted.** All three sit in longwords the walker
  overwrites with each address's own value and then verifies. A hardware register that
  returned a written address would be indistinguishable from RAM, and one that did not would
  **fail the self-test and hang the machine**. They must behave as RAM.

That leaves `$1FFE2`'s `lsr #2` vector-number write — the single strongest-looking case in my
original argument — as a **write to RAM that nothing reads**. Either it is dead code, or its
consumer is something I have not traced; what it is *not* is a hardware vector register, and
the "signature of a vector register" reasoning was wrong to treat a suggestive value as
decisive over an access pattern.

**The methodological point.** My earlier inference used one test's exclusion as corroboration
without asking whether any other code contradicted it. Two rounds later the contradiction
appeared, and then resolved into a sharper answer than either version — but only because the
question "what else touches this range?" got asked. *A hypothesis supported by one piece of
evidence should be checked against the code that would refute it, not just the code that
suggested it.*

### Static map vs runtime: what each can see, and one claim it qualifies

Diffing the 59-address scoped map against a runtime access log (`FPS3K_ACCESSLOG`,
4-channel chassis) separates three things cleanly.

**49 of 59 appear in both.** The static map's lower-bound nature is visible and modest.

**10 are referenced in code but never touched at runtime** — and they are a single coherent
group:

```
$FF0000  $FF0004                       base window
$FF0048/$FF004A   $FF0068/$FF006A      channel 1, 2 data hi/lo
$FF0088/$FF008A   $FF00A8/$FF00AA      channel 3, 4 data hi/lo
```

Every one is read only by a channel ISR, which needs a channel interrupt to run. **This is a
coverage gap, not a modelling gap**, and it is exactly the earlier `$FF004A` observation
generalised: 15 static sites, zero runtime accesses in a boot that raises no channel
interrupt. Both numbers are right.

**4,118 addresses are touched at runtime but absent from the static map.** Not a defect —
these are *loop-generated*: the SCM address-line test alone sweeps 16 KB from one code site.
A static map enumerates **code sites**; a runtime log enumerates **addresses**. Neither
subsumes the other, and quoting one where the other is meant is how "`$FF0204` is the hottest
register" (runtime, ~33k) and "`$FF0204` has 7 write sites" (static) can both be true.

**A qualification to the protected-block argument.** I wrote earlier that the firmware
"carves a hole in its own memory test to protect `$1FFE0-$1FFFF`", and used that to argue the
block is registers rather than dead stores. Tracing which PCs touch it shows the picture is
split:

| test | treatment of `$1FFE0-$1FFFF` |
|---|---|
| pattern test (`$F08992`) | **excluded** — range end backed off by `$20` |
| address-line test (`$F098FC`/`$F09912`) | **walked** — writes `$0001FFE0` to `$1FFE0`, reads it back |

So one test protects the block and another writes arbitrary longwords into it. **That
weakens the inference I drew.** The pattern test's exclusion is still evidence — it is
deliberate and specific — but a block whose words are freely overwritten by a neighbouring
diagnostic is harder to read as a live register file, particularly one containing an
interrupt-request level field. The most that survives: `$1FFE0-$1FFFF` is treated
*specially by at least one test*, the write-only access pattern is real, and the M68KVM02
register map remains the thing that would settle it. **I should not have called it
"corroboration" without checking whether any other test contradicted it.**

*(This also explains the `FPS3K_POKE` / `FPS3K_DMA10AA` hangs recorded earlier at `$F098FC`
and `$F09904`: that walker writes each address's own value and reads it back, so any location
holding a constant — an injected value, or a hardware register — fails it.)*

### A scoped, base-register-aware device map — 59 addresses, 217 sites

With the addressing model understood, the map can finally be built the way the ROM is
actually written. `refs_extracted/device_map_scoped.json` is generated by a tracker that:

- follows `lea abs,An` / `movea.l #imm,An` to establish bases;
- **clears all bases at `rts`/`rte`/`jmp`/`bra`**, so a base never leaks into an unrelated
  routine (the failure that invented four registers earlier);
- **excludes `lea`/`pea`**, which compute addresses and access nothing;
- strips the `[SYMBOL]` annotations before matching operands — they sit between the operand
  and the end of the line and silently broke direction detection;
- resolves both `d16(An)` and bare `(An)`, and classifies `bset`/`bclr`/`addq`/`or` as
  **read-modify-write** rather than plain writes.

**Result: 59 device addresses across 217 code sites** — 83 reads, 91 writes, 43 RMW.

| block | addresses |
|---|---|
| XLTR `$FF0200+` | 28 |
| AP I/F `$FF0000-$FF00AE` | 19 |
| VMOD `$1FFE2-$1FFF2` | 6 |
| PTM / board status | 5 |
| chassis window `$400000` | 1 |

Spot-checks against independently established facts, all consistent:

| address | scoped result | corroborates |
|---|---|---|
| `$FF0204` | 7 write sites, 1 read | the "hottest register, writes >> reads" profile |
| `$1FFF1` | 34 of 39 sites are **RMW.b** | the `bset`/`bclr` bit protocol of `$200`-`$1400` |
| `$400000` | `R.l`x2, `W.l`x1 | the window is **32 bits wide**, longword-accessed |
| `$FF000E` | 7 sites, all **W.w** | command on write; the `$1A00` read-back is `cmpi`, classified R elsewhere |

**What this map is and is not.** It is a *static* map of code sites, not runtime frequency —
`$FF0204` has 7 write sites and ~33k runtime writes, and both numbers are correct answers to
different questions. It covers the FPS application region that `fps3k.asm` contains, so the
kernel's lone `$F70030` access is outside it. And it inherits one honest limitation: a base
established in a caller and used in a callee is not tracked across the call, so the count is
a **lower bound**. Every previous version of this map was an *upper* bound polluted by stale
bases; a lower bound built from validated rules is the more useful error direction.

*Four iterations were needed to get this right*, and each failure is recorded above: naive
global bases invented registers, an over-narrow regex missed `$FF0048`, the annotation
stripping was missing so every direction was wrong, and dropping bare `(An)` lost `$1FFF0`
and `$F70018` entirely. **The map is only as good as the tracker, and the tracker only became
trustworthy once each rule had been falsified once.**

### The firmware addresses devices ONLY through base registers — which explains everything

Applying the validated operand test (an absolute-long is preceded by an opcode that takes
one) across the whole 64 KB gives a small, sharp result. **Seven distinct device addresses
are referenced absolutely in the entire ROM**, and every sampled one is a `lea`:

| address | sites | preceded by |
|---|---|---|
| `$1FFF0` | 13 | `lea …,a5` / `lea …,a1` |
| `$F70018` | 9 | `lea …,a4` / `lea …,a2` |
| `$FF0000` | 4 | `lea …,a6` |
| `$F70001` | 2 | `lea …,a0` |
| `$400000`, `$403FFC`, `$404000` | 1 each | the SCM tests |
| `$F70030` | 1 | `move.b abs,d0` — the kernel's lone access |

**11 of 11 sampled absolute device references are `lea base,An`.** The firmware establishes
base registers and performs *all* actual device I/O through displacement addressing:

```
a6 = $FF0000    ->  $202(a6), $204(a6), $216(a6), $4E(a6) …   AP I/F + XLTR
a5 = $1FFF0     ->  (a5), $1(a5), -$e(a5) …                    VMOD_CTRL block
a4 = $F70018    ->  $1(a4) …                                   board status
a0 = $F70001    ->  $2(a0), $4(a0), $8(a0), $c(a0) …           MC6840 PTM
```

*This is the single most important structural fact for anyone analysing this ROM*, and it is
the root cause of six false negatives this session. Absolute-address scanning does not merely
miss *some* accesses here — it misses **essentially all of them**, because absolute forms
exist only to load the bases. `$FF0204` is the extreme case: the hottest register on the
board at ~33k writes, and it appears in **zero** absolute-long references. Any tool that
scans for `$FF0204` will report it unused.

So the addressing model is a two-level one and analysis has to match it: find the `lea` that
establishes a base, then attribute every `dN(An)` in scope to that base — with the caveats
already learned, that `lea` itself accesses nothing and that a base must not be carried
across unrelated routines.

*Two kernel hits discarded:* `$4A237C` and `$4A297C` pass the operand test (both preceded by
`$4EB9` = `jsr abs.l`) but the targets lie in unpopulated space where no code can exist, so
the `$4EB9` is data misread as an opcode. **The operand test raises confidence; it does not
replace a sanity check on the resulting address.**

### `$F70030` — one device register in the whole RMS68K kernel, and it is off our map

The kernel region `$F00000-$F04488` (17,544 bytes, 26% of the ROM) is excluded from
`fps3k.asm` on the grounds that it is stock Motorola code. Sweeping it for device references
gives a sharp result: **exactly one genuine absolute device access in the entire region.**

```
$F00A32:  movea.l $0C78.w,a7          ; supervisor stack from a saved slot
$F00A36:  ori.w   #$700,sr            ; mask all interrupts
$F00A3A:  move.b  $F70030,d0          ; READ
$F00A40:  ori.b   #$20,d0             ; set bit 5
$F00A44:  move.b  d0,$F70030          ; WRITE BACK
$F00A4A:  movea.l $0C78.w,a7
$F00A4E:  movem.l (a7)+,d0-d7/a0-a7
$F00A52:  clr.l   $0C78.w
$F00A56:  rte
```

**`$F70030` is not in any memory map this project holds.** The documented `$F7xxxx` devices
stop at `$F7001A` (PTM `$F70001-$F7000F`, SIO `$F70011-$F70017`, board status
`$F70018-$F7001A`). This is a separate register, read-modify-written to set **bit 5**, inside
a routine that masks interrupts, restores a saved stack and returns via `rte`.

Because the kernel is generic RMS68K rather than FPS code, `$F70030` is presumably a
**standard M68KVM02 register** that Motorola's kernel knows about and the FPS application
layer never uses. What it does is unestablished; the shape — mask interrupts, set one bit,
restore context, `rte` — fits an interrupt-acknowledge or a board-level status assertion,
but the ROM gives no way to choose between them.

**Emulator status: unmodelled, and dormant.** `versabus.h` maps `$F70000-$F7001C` and
nothing above, so `$F70030` falls through to unmapped handling — which, given phase `$600`
requires unmapped reads to raise BERR, means this code would bus-error if reached. It is not
reached: **`$F00A32`, `$F00A3A`, `$F00A44` and `$F00A56` all execute zero times** across a
full boot, in which 620 distinct kernel PCs do run. So the hazard is real but latent, and
worth a stub before any work that exercises more of the kernel.

**Method note — this sweep failed the opposite way from all the others.** My first pass
flagged **262** "device address constants" in the kernel by matching any longword in
`$400000-$7FFFFF`. That range is essentially the 68000 opcode space: `4E73` is `rte`, `48E7`
is `movem`, `60FE` is the spin, `4CDF` is the restore. Every one was noise. The five other
plausible-looking hits (`$FF0000`, `$FF0008`, `$FF0018`, `$FF004A`, `$FF0100`) are also
coincidences, and the test that separates them is cheap: **a genuine absolute-long operand
is preceded by an opcode word that takes one.** `$F70030`'s is `$1039` = `move.b abs,d0`;
the others are preceded by `$0C2A` (`cmpi.b #imm,d16(a2)`), `$11BC`, `$0C29`, `$48EE`
(`movem.l d0-d7,d16(a6)` — the `$00FF` is a *register mask*), none of which take an absolute
long. After six false negatives from over-narrow detectors this session, this is the first
false-positive flood from an over-broad one; both are the same discipline failure, and the
same fix applies — **validate the detector before believing its output.**

### The six unresolvable TRAP #1 sites are the ISR exits — and they pass the directive in the CCR

Resolving TRAP #1 directives by scanning backwards for a `d0` load reaches 65 of 71 sites.
The six it cannot reach are not a limitation of the scan window — **they do not load `d0` at
all**, and they are the most structurally important trap sites in the firmware:

| site | task |
|---|---|
| `$F05100` | RDHC |
| `$F05E50` | IO1I |
| `$F060F4` | XP4I |
| `$F06B0C` | XP3I |
| `$F0750C` | XP2I |
| `$F07F0C` | XP1I |

**Exactly one per task**, matching the six `{vector, TCB, ISR entry, ISR exit}` records in
`!IDV` at `$1F800`. All six carry a byte-identical prefix:

```
move.w #$c,ccr
trap   #$1
```

**`d0` cannot carry the directive here.** RDHC's stub is the clearest case: the instruction
immediately before is `movem.l (a7)+,d0-d7/a0-a7`, restoring the *interrupted task's* entire
register set. After that nothing in the register file belongs to the ISR — using `d0` would
corrupt the task being resumed. The `move.w #$c,ccr` is the only state the stub sets, and it
is the last thing before the trap.

**The mechanism is the stacked SR.** `trap #1` pushes SR — condition codes included — onto
the supervisor stack before entering the handler. So the kernel reads the directive out of
the stacked SR's low byte rather than a register. That is a genuinely elegant solution to
"pass an argument when every register must already hold the caller's value", and it is
invisible to any analysis that assumes the documented "directive in `d0`" convention holds
universally.

So the ROM uses **two** TRAP #1 calling conventions:

| convention | sites | used by |
|---|---|---|
| directive in `d0` | 65 | ordinary task-level calls |
| directive in `CCR` | 6 | **ISR exit, one per task** |

This also closes out the last gap in the directive inventory: 65 + 6 = 71, with nothing
unaccounted. The `$0C` value is the ISR-exit selector, and it is not a member of the 14
`d0`-passed directives — it lives in a separate space, which is consistent with it being
read from a different place.

*Method note:* this is the sixth false negative this session from a detector narrower than
its target, and the only one where the narrowness pointed at something real. The six sites
resisted resolution because they genuinely are different, not because the regex was wrong —
**worth distinguishing from the other five, where the code was ordinary and the tool was
not.**

### The DRAM test is a rotate-by-3 pattern generator — and the constants are its seed

The two magic longwords planted before `$F099F4` (`$FF000102` and `$01796AF3`) are not
sentinels, as I guessed when first noting them. They are the **seed pair** for a pseudo-random
pattern generator, left in RAM immediately below the region under test and pointed at by
`a5` — which `$F099F4` deliberately does **not** save, so it survives as an implicit
argument.

Four routines make up the test:

| routine | role |
|---|---|
| `$F099F4` | walks the range in **`$20` = 32-byte blocks** |
| `$F09A4C` | **generator** — `rol.l #3,d0`, then chains `d1..d5` each a further `rol.l #3` |
| `$F09A24` | **verifier** — feeds `d2,d3,d4,d5` to the comparator |
| `$F09A3A` | **comparator** — `rol.l #3,d0` to advance the expected value, `cmp.l d1,d0`, else `$F0F0F0F0` |

The arithmetic closes exactly: `$F09A24` is called **twice** per block and compares **four**
longwords each time — 8 longwords = **32 bytes**, precisely the `$20` stride `$F099F4`
advances by. Nothing is left over.

**Why rotate by three.** `gcd(3, 32) = 1`, so the 32 successive rotations of a longword are
all distinct — every longword in a block gets a different value, and adjacent longwords
differ across the whole width rather than in a few bits. That is a real pattern-sensitivity
test: it catches coupling faults between neighbouring cells that a uniform `$55555555` fill
cannot, because with a checkerboard every location holds the *same* value and a
cell-to-cell short is invisible. From the seed `$01796AF3` the block takes
`$0BCB5798, $5E5ABCC0, $F2D5E602, $96AF3017, …` — no structure an address decoder could
accidentally reproduce.

So the SBC's memory testing is layered, and each layer catches what the others cannot:

| layer | stage | catches |
|---|---|---|
| address lines | `$F09AD6` (SCM), `RAMAddressingTest` | shorted/open address lines, aliasing |
| uniform patterns | `$F09B20` — `$0/$FFFFFFFF`, `$55…/$AA…` | stuck bits, data-line shorts |
| **rotating pseudo-random** | `$F099F4` + friends | **pattern sensitivity, cell coupling** |

*Correcting my own note from the previous entry:* I described these constants as "boundary
sentinels, most likely" and flagged that I had not decoded `$F099F4`. They are seeds, and the
placement just below the tested region is simply a convenient scratch location for the
generator's starting state — not a guard against overrun.

### The last two stages test System Common Memory — and that closes the board map

`$F09AD6` and `$F09B20`, the final stages before the third `$D0` checkpoint, both operate on
`$400000` with `XLTR_MODE2 <- 0` (page 0). They are the textbook memory-test pair:

**`$F09AD6` — address-line test.**

```
movea.l #$400000,a0  ;  move.l #$4000,d0  ;  moveq #$4,d1
loop:  move.l d1,(a0,d1.l)     ; write each offset's own value AT that offset
       lsl.l  #$1,d1           ; walk the address bit
       cmp.l  d1,d0            ; until $4000
```

Offsets `4, 8, 16 … 8192` — **twelve powers of two, exercising address lines A2-A13** of the
chassis window (A0/A1 lie inside the longword). Writing each address's own value at that
address is the standard way to catch shorted or open address lines: any aliasing shows up as
a location holding the wrong offset.

**`$F09B20` — data-pattern test.** It fills `$400000-$404000` in longword strides from a ROM
pattern table at `$F09BB6`:

| pair | pattern | complement |
|---|---|---|
| 1 | `$00000000` | `$FFFFFFFF` |
| 2 | `$55555555` | `$AAAAAAAA` |

All-zeros/all-ones and checkerboard/inverse-checkerboard, in **32-bit** longwords —
consistent with everything else about this window being 32 bits wide, and complementary to
the `$AAAA` 16-bit test the AP I/F gets in `$1A00`.

**Both cover only 16 KB, at page 0** — not the megaword the MAIN DATA card carries. The
self-test verifies a window into SCM, not the array. (This matches the extent noted
independently for phase `$29xx`.)

**With that, every board the SBC can reach is accounted for:**

| board / device | stages that exercise it |
|---|---|
| SBC — RAM, ROM, vectors | `$200`-`$500`, sequence C DRAM walk |
| **ROM checksum** | `$300` |
| MC6840 PTM | `$800`, and `$1100`'s `movep` walk |
| VERSAmodule interrupter | `$700`, `$1300` |
| bus-timeout watchdog | `$600` |
| XLTR register file | `$1500`, `$1600` |
| XLTR window / page | `$1700`, `$1800` |
| XLTR data mux (16→32 conversion) | `$1900` |
| AP I/F | `$1A00` |
| **SCM / MAIN DATA via MEM CTL** | `$F09AD6`, `$F09B20` |
| **XP-32 EXEC (Am29116)** | **never** |
| **XP-32 ARITH** | **never** |
| **UNIV FMT** | **never** |

*That table is the structural answer to "map all communications to and from the devices,
including EU/AU".* The self-test is the firmware's own authoritative statement about what
the SBC can touch, and it exercises **every board in the chassis except the three on the far
side of the XP32 bus**. The EU and AU are not missing from our analysis through oversight —
they are outside the SBC's reach by design, and the machine's own diagnostics draw the same
boundary we kept arriving at. Nothing in this ROM can map them; only an EU PROM dump or a
bus trace on the XP32 side can.

### The VERSAmodule block is larger than two bytes — four write-only neighbours

Sweeping everything reached through `a5 = $1FFF0` (excluding `lea`, which accesses nothing)
turns up six locations beside the documented `VMOD_CTRL` pair, and they split cleanly by
access pattern:

| address | sites | access | value |
|---|---|---|---|
| `$1FFE2` | `$F08F8C` | **write only** | `$51` — vector number 81 (`$700`) |
| `$1FFE4` | `$F09354`, `$F093F0` | **write only** | `$148` (`$1300`), then `d1` (`$1400`) |
| `$1FFE6` | `$F0925C` | **write only** | `d0` (`$1200`) |
| `$1FFF2` | `$F093FA` | **write only** | `d1` (`$1400`) |
| `$1FFF4` | `$F0897C`, `$F08980` | `or.b` **read**, then `addq.b` RMW | a counter |

**Four locations are written and never read — anywhere in the ROM.** That asymmetry is the
useful discriminator. A scratch variable exists to be read back; a value written once and
never consumed by the firmware is either a hardware register whose consumer is the board, or
it is dead. `$1FFF4` is the control case sitting right beside them: it *is* read (`or.b
$4(a5),d0`) and incremented, exactly what a real scratch counter looks like.

So the inference is that **the VERSAmodule register block extends at least from `$1FFE2` to
`$1FFF2`**, not merely the two bytes at `$1FFF0-$1FFF1` that every map in this project
records. `$1FFE2` taking a vector *number* derived by `lsr #2` is the strongest single case,
since a stored vector number has no use unless hardware consumes it during IACK.

**Corroboration: the DRAM test explicitly protects `$1FFE0-$1FFFF`.** Sequence C calls the
memory-test helper `$F08992` with `a0 = $10000, a1 = $20000` — the whole upper 64 KB. The
helper opens with:

```
cmpa.l #$1fff0,a1
blt    .normal
lea    -$20(a1),a1        ; back the END of the range off by 32 bytes
```

`$20000 >= $1FFF0`, so the range end becomes **`$1FFE0`**. The destructive test stops there,
leaving `$1FFE0-$1FFFF` untouched — and that 32-byte block contains **every one of the
write-only locations above**, plus `VMOD_CTRL` itself:

| | |
|---|---|
| `$1FFE2` | vector-number register (`$700`) |
| `$1FFE4`, `$1FFE6`, `$1FFF2` | write-only |
| `$1FFF0`-`$1FFF1` | `VMOD_CTRL` |

**Firmware does not carve a hole in its own memory test to protect dead stores.** That moves
the inference well past "consistent with a register": the code treats this exact range as
something a write-pattern sweep must not touch, which is what you do for hardware and not
for scratch. It also independently confirms `VMOD_CTRL` is not ordinary RAM — a fact known
from the manual, here visible in the firmware's own behaviour.

**The honest caveat.** The block is protected *as a unit*, so the argument applies to
`$1FFE0-$1FFFF` collectively, not address by address. `$1FFF4` — the one location shown
above to be genuine read-and-increment scratch — is inside the protected range too, which is
exactly what a 32-byte granularity would produce and also exactly what a mixed
register/scratch block would produce. So: **the block is established as special; the role of
each individual word within it remains inferred.** The M68KVM02 register map for
`$1FFE0-$1FFFF` would still settle the details.

**Emulator consequence, currently benign.** The model treats all of `$1FFE0-$1FFFF` except
`$1FFF0-$1FFF1` as plain RAM, so these four writes land in memory and nothing reads them —
which produces correct behaviour whichever hypothesis is true, because the firmware never
reads them either. The divergence would only appear on hardware, where a real vector
register would change what the board supplies during IACK.

*Two sweep results discarded:* `$2001C` and `$20026` (from `$F0A0B2`/`$F0A0E2`) lie beyond
the 128 KB RAM top and come from a stale `a5` in the RTOS-init region, the same
base-tracking failure documented above. They are not accesses to anything.

### `$1FFE2` is a vector-number register, and the VMOD interrupter owns vectors 80-82

Phase `$700` (`$F08F70`) shows how the board's own interrupter is programmed:

```
move.w #$144,d0
lsr.w  #$2,d0            ; $144 / 4 = $51 = 81  -- the VECTOR NUMBER
move.w d0,-$e(a5)        ; $1FFE2 <- $51
move.l a3,$144.l         ; vector $144 = handler $F09052
andi.w #$f8ff,sr         ; unmask interrupts
```

Deriving a vector *number* from a vector *address* by `lsr #2` and writing it to a fixed
location, then installing the handler at the matching address, is the signature of a
**vector register**. So `$1FFE2` is where the VERSAmodule's interrupter is told which vector
to supply during IACK — a register two words below `VMOD_CTRL` and not previously in any
map.

Collecting the vectors the self-test programs:

| address | vector | stage |
|---|---|---|
| `$140` | **80** (`$50`) | `$1300` handler B — fires all 7 times |
| `$144` | **81** (`$51`) | `$700` handler `$F09052` |
| `$148` | **82** (`$52`) | `$1300` handler A — installed, never fires |

**A contiguous group 80-82**, entirely distinct from the BIM vectors `$41`/`$45`-`$4A` that
carry chassis interrupts. Two independent interrupt paths reach this CPU: the MC68153 BIMs
on the XLTR for chassis events, and the VERSAmodule's own interrupter for board-local ones.
The handler `$F09052` is a single `bset.b #$6,$1(a5)` then `rte` — it sets VMOD bit 6, the
same bit `$200` tests and `$F0903C` clears, so the interrupt path and the board-status
equation are wired to the same flag.

*Disassembly note:* `$F08F70` renders as `DC.W 0x48e7` followed by a bogus `or.b (a4)+,d0`.
That is a decode artifact — `48E7 801C` is `movem.l d0/a3-a5,-(a7)`, the standard prologue.
The stage entry is mis-disassembled, which is worth knowing before trusting the first two
lines of any routine in this file.

### On reading device datasheets to identify what a stage is testing

A suggestion worth recording, because it has already produced two of this session's
strongest results and is the right default:

- **MC6840 CR bit 2** = dual 8-bit mode is what turned T3's `$27C7` latch into a
  `(39+1)x(199+1) = 8000` cycle period and gave the exact **10 ms system tick** — and
  exposed that the emulator's 16-bit reload runs 27% slow.
- **MC68153 register layout** (4 control + 4 vector registers per BIM) is what made the
  `$C0`-to-`$D0`/`$D8` walk in `$1600` legible as **16 or 24 registers = 2 or 3 BIMs**,
  which in turn explained the long-standing "`$FF025E` is never touched" anomaly.

For the **Am29116** specifically, the constraint is structural rather than a lack of
willingness: that chip sits on the XP-32 **EXEC** card, and this ROM never addresses it.
Everything the SBC sends toward it goes as opaque codes through `$FF000E` and the XLTR
window. The existing decode of panel codes `$258`-`$27D` as Am29116 `SUBRC` instructions
came from exactly this method and remains the one place the chip's ISA touches this
firmware — and it is still ambiguous between "real instructions" and "dispatch indices that
happen to decode", which no amount of further datasheet reading can settle without an EU
PROM dump or a bus trace. **The self-test stages decoded so far are all SBC-side**, where
the relevant parts are the 68000, MC6840, MC68153 and the custom XLTR, so those are the
datasheets that have been carrying the work.

### Phase `$600` is the BUS-ERROR WATCHDOG test — and `$F80000` is not a device

`$F08F1C` walks `$F82001` down to `$F80001` in steps of 2, reading a byte at each with a
private bus-error handler installed. My first reading was "an undocumented 8 KB device
region". The exit condition says otherwise:

```
$F08F4C  tst.l  d1
$F08F4E  bne    $F08F5E          ; a fault occurred -> EXIT, PASS
$F08F50  cmpa.l #$f80001,a0
$F08F56  bne    $F08F3C          ; else keep walking down
$F08F58  move.l #$F0F0F0F0,d7    ; swept all 8 KB with NO fault -> FAIL
```

**The test requires a bus error.** Sweeping the whole range without one is the failure case.
So `$F80000-$F82000` is not a device at all — it is **deliberately unpopulated address
space, chosen as a safe place to provoke a bus timeout**. That is precisely why it appears
in no memory map: there is nothing there, by design. The stage verifies that the board's
**bus-timeout watchdog** still asserts BERR when no DTACK arrives, which is a genuinely
important thing to check — a dead watchdog means any stray access hangs the bus forever
instead of trapping.

**The handler is more careful than the one in `$1700`/`$1800`:**

```
$F08F06:  addi.l #$1,d1        ; count the fault
          beq    $F08F10       ; if it wrapped to zero...
          bra    $F08F16
$F08F10:  addi.l #$1,d1        ; ...count again, so d1 is NEVER zero after a fault
$F08F16:  lea    $8(a7),a7
          rte
```

The skip-zero guard makes `tst.l d1` a reliable "did we fault" test even across 2^32 faults.
And unlike `$F098E0`, this handler **does not advance the PC** — no `addq.w #4`. It relies
entirely on the three NOPs after the read to absorb the imprecise fault. Two bus-error
handlers in one ROM with deliberately different strategies, each matched to its probe.

**Measured — the stage passes on the first probe:**

| PC | count | |
|---|---|---|
| `$F08F3C` | 1 | one downward step |
| `$F08F40` | 1 | the byte read |
| `$F08F06` | 2 | the handler |
| `$F08F5E` | **1** | fault path — **PASS** |
| `$F08F58` | **0** | sweep-exhausted — never |

So the emulator does raise BERR on unmapped reads and satisfies the stage immediately.
*(The handler entering twice against a single logged read is unexplained; the pass/fail
outcome does not depend on it, and I have not chased it.)*

**Emulator constraint, now explicit:** reads anywhere in `$F80001-$F82001` must raise a bus
error. A model that silently returns zero for unmapped space — the common shortcut — fails
this stage, and since failure loops back to `$F08F36` it would **hang forever at phase
`$600`** rather than reporting anything. Combined with the phase beacon on `CHANNEL_SELECT`,
a board or model stuck at `$0600` is reporting exactly this.

For completeness, **`$800` (`$F0905A`) is the PTM stage**: it sets `a0 = $F70001`, derives
`$4(a0)`, `$8(a0)`, `$c(a0)` — the three timer MSB registers at `$F70005`/`$F70009`/`$F7000D`
— and calls the `movep` walking-ones routine at `$F09154` once per timer, at IPL 4
(`SR <- $2400`). That confirms from the calling side what was derived earlier from the
callee.

### RETRACTION: the firmware DOES verify the ROM checksum — phase `$300`

`$F08D1A` is a **whole-ROM XOR checksum test**, and it runs as the second stage of the
power-on self-test:

```
move.w  #$ffff,d0
movea.l #$f00000,a0  ;  movea.l #$f10000,a1
loop:  move.w (a0)+,d1
       eor.w  d1,d0              ; XOR-accumulate every word
       cmpa.l a0,a1  ;  bne loop ; across the entire 64 KB
cmpi.w  #$ffff,d0  ;  beq ok     ; the accumulator must still be $FFFF
move.l  #$F0F0F0F0,d7            ; else FAIL
```

Seeding with `$FFFF` and requiring `$FFFF` back is exactly "the XOR of all 32,768 ROM words
must be zero". Measured on the stock image: **XOR = `$0000`, so the test passes**, with the
final word `$F0FFFE = $C12D` acting as the correction term.

**This retracts two statements carried in `CLAUDE.md`.** The first is explicit: the ROM
"does carry a checksum ... **Nothing in the firmware checks it** — an EPROM programmer, a
factory tool or the VM02 monitor might." It is checked, by the firmware, at `$F08D1A`.

The second is subtler and more instructive. When the routine at `$F08DF8` was correctly
renamed from `ROMChecksumTest` to `BoardStatusPoll_3F11`, the note added: *"The old name had
people hypothesising that patching the ROM would fail a self-test; **it cannot, because no
such test exists**."* The rename was right — `$F08DF8` really does just poll `$F70018` — but
the conclusion drawn from it was an overreach. **A true belief was discarded along with the
wrong label.** The checksum test exists; it simply lives at `$F08D1A`, two hundred bytes
earlier, and nobody looked there once the name was gone.

**Consequences for real hardware, which are concrete.**

*Any ROM image whose words do not XOR to zero fails phase `$300`.* And failure here is not
graceful: the stage ends `bsr PollBoardStatus / tst.l d7 / bne` back to the top of the same
probe, so a bad checksum means **the machine retries forever and never boots**.

*That gives a diagnosable signature.* The phase counter is broadcast to `CHANNEL_SELECT`
(`$FF0204`) before each stage, so a board hung with `$0300` as the last value written there
is reporting a checksum failure specifically. On a machine with no serial output, that is a
readable beacon.

*It makes `monitor/patch_rom.py`'s checksum recomputation necessary rather than prudent.*
Every monitor image this project produced before 2026-07-29 broke the XOR — including the
one burned for the first hardware attempt. Any such image that boots the stock path would
hang at `$300`.

*Stated carefully:* this does **not** by itself explain the FAIL + HALTED outcome of that
burn. That image was built with `--reset`, so the monitor takes the reset vector and
`$F08D1A` never executes — the diagnosed SIO byte-lane and missing-vector-table defects
remain the explanation. But the **panic-only** image, described as "behaviourally identical
to stock", does run the self-test, and a broken checksum would stop it at phase `$300`. That
is a hazard on the documented bring-up path and it was not previously known.

### The self-test decomposes the board-status equations TERM BY TERM — and that yields a complete VMOD_CTRL bit map

Phase `$200` (`$F08C4A`) is the very first test the machine runs, and it is the simplest
possible probe:

```
moveq #$6,d0  ;  moveq #$3,d1
bclr d0,$1(a5)  ;  btst d0,$1(a5)  ;  beq ok    ; $1FFF1 bit 6 must clear and hold
bclr d0,$1(a5)  ;  btst d1,$1(a4)  ;  bne ok    ; then $F70019 bit 3 must be SET
```

Against the documented `bit 3 of $F70019 = NOT(bit 6 OR (bit 7 AND bit 1))`, `$200` drives
bit 6 low and requires bit 3 high — **it tests the bit-6 term alone**. `MemBusProbe` at
phase `$1000` then clears bit 6 and walks `(bit 7, bit 1)` as a 2x2 — **the AND term
alone**. One boolean expression, split across two *sequences*, each phase isolating one
term with the others held at their identity value.

That is the organising principle of the whole suite, and it makes the remaining stages
readable: **each stage is a term or a bit of the SBC↔chassis handshake specification**, not
an arbitrary numbered test. Collecting every stage decoded so far gives a complete bit-level
map of the VERSAmodule control register:

| register | bit | established by | role |
|---|---|---|---|
| `$1FFF1` | **0-2** | `$1300` | **interrupt-request level field** (walked 1..7, delivery mandatory) |
| `$1FFF1` | **3** | `$1400` | drives `$F70019` bit 2 via `(bit 3 AND bit 0)` |
| `$1FFF1` | **4** | `$1100` | **verified read/write flip-flop**; the `NOT(bit 4)` term of `$F70019` bit 1 |
| `$1FFF1` | **5** | `$1200` | `$F70019` bit 1 follows it directly; **self-clearing request** |
| `$1FFF1` | **6** | `$200` | the `NOT(bit 6)` term of `$F70019` bit 3 |
| `$1FFF1` | **7** | `$1000` | one input of the `(bit 7 AND bit 1)` term |
| `$1FFF0` | **0** | `$1200` | the `NOT(bit 0)` term of `$F70019` bit 1 |
| `$1FFF0` | **1** | `$1000` | the other input of `(bit 7 AND bit 1)` |

**Every bit of `$1FFF1` is accounted for**, and two of `$1FFF0`. That is a firmware-derived
specification of the register, obtained without any Motorola documentation — and where it
does overlap Motorola's wording it agrees, since the manual's description of VMOD writes
driving "chassis-mediated VERSAbus interrupter logic" is precisely the bits 0-2 field.

Two observations this map makes visible that no single stage did. **The bits have different
electrical natures and the firmware knows it**: bit 4 is probed as a flip-flop (write, read
back, both ways), bit 5 as a strobe (write, then poll for it to clear itself), bits 0-2 as a
value field (walked exhaustively). A test suite that treated them uniformly would be
testing the wrong things. And **the sequence-A/sequence-B split is not local-vs-remote as
the outward-walk reading suggested** — `$200` and `$1000` test the same equation from
opposite ends. The split is *before and after* `XLTR_MODE1 <- $2000`, so what changes is
whether the XLTR is enabled, not which board is under test.

### Phase `$1300`: `$1FFF1` bits 0-2 are an interrupt-request LEVEL field

`$F09338` is the self-test's interrupt-delivery stage, and it is the strongest hardware
requirement in the whole suite.

It installs two handlers and then loops:

```
move.l a3,$148.l            ; vector $148 = vector number 82
move.l a4,$140.l            ; vector $140 = vector number 80
moveq  #$1,d1
loop:  clr.w d2                    ; the flag a handler sets
       or.w  d1,(a5)               ; OR d1 into the WORD at $1FFF0   <- TRIGGER
       move.b #$ff,d3
       tst.w d2 ; dbne d3,.        ; wait up to 256 iterations
       tst.w d2 ; bne ok           ; HARD: the interrupt MUST have fired
       ...
       addq.w #$1,d1 ; cmpi.w #$8,d1   ; seven iterations, d1 = 1..7
```

`(a5)` is the **word** at `$1FFF0`, so on a big-endian 68000 its low byte is `$1FFF1`, and
`d1 = 1..7` sets **bits 0-2 of `$1FFF1`**. Seven distinct values, a three-bit field, walked
exhaustively — that is the 68000's interrupt levels 1-7 and nothing else plausibly fits.

**So `$1FFF1` bits 0-2 are the VERSAmodule's interrupt-request level field**, and writing a
nonzero level asserts an interrupt at that level. This is the mechanism the board uses to
interrupt *itself* — distinct from the BIM-supplied vectored interrupts from the chassis,
which arrive on `$FF0230`-`$FF025E` and carry vectors `$41`/`$45`-`$4A`. The two vectors
here, **80 (`$50`) and 82 (`$52`)**, are outside that documented set, so this stage exercises
interrupt plumbing no other part of the ROM touches.

**The assertion is hard, unlike `$1200`'s.** The 256-iteration `dbne` is only a timeout; what
follows is `tst.w d2 / bne`, and on failure `d7` takes `$F0F0F0F0` and the code branches
**back to the top of the same probe**. So a machine that does not deliver the interrupt does
not fail gracefully — *it retries forever*. That is a meaningful difference from the bit-5
poll in `$1200`, which tolerates a timeout: here delivery is mandatory.

**MEASURED: `$1300` passes, and the manual corroborates the finding.** I flagged this as an
open question on the assumption that VMOD_CTRL was unmodelled. It is not, and the trace
settles it:

| PC | count | |
|---|---|---|
| `$F0938A` | **7** | the `or.w d1,(a5)` trigger |
| `$F09396` | **7** | the assertion |
| `$F0939A` | **0** | the failure path — never taken |
| `$F093A8` | **7** | the success path |
| `$F093BE` | **7** | handler at vector `$140` (number 80) |
| `$F093C8` | **0** | handler at vector `$148` (number 82) — never fires |

All seven levels deliver. Only **one** of the two installed vectors is ever used; vector 82
is installed and never exercised, which is worth noting since it means the ROM prepares for
a second interrupt source this stage does not reach.

**Independent corroboration from the M68KVM02 manual**, quoted in the emulator at
`versabus.c:1117`: VMOD_CTRL is *"Control Register image only — register not directly
accessible. Writes go through chassis-mediated VERSAbus **interrupter logic**."* That is
Motorola describing exactly the mechanism derived here from the ROM — a write to `$1FFF0`
driving interrupt generation. The ROM-side derivation (a 3-bit field walked 1..7 against
mandatory delivery) and the manual's wording were reached independently and agree.

**Two corrections to the `$1200` entry above.** I wrote there that "`$1FFF0`/`$1FFF1` appear
nowhere in the emulator's C — VMOD_CTRL is plain RAM". **Both halves are wrong.**
`versabus.h:105` defines `VMOD_CTRL 0x01FFF0`; the model keeps `vmod_ctrl` state, splits it
big-endian, drives the board-status equations from it, and `versabus.c:95` carries a
purpose-built IRQ source labelled for phase `$1300`. My grep searched for the literal
`0x1FFF1`, which appears nowhere because the model addresses it as `VMOD_CTRL+1`.
Consequently the claim that `$1200`'s bit-5 handshake is "vestigial in emulation" is
**unsupported** and withdrawn — whether the model auto-clears bit 5 needs checking on its
own terms, not inferring from an absence I never established.

*That is the third false negative this session from grepping for a literal address form* —
after `$FF0048` (absolute-only scan) and `$1FFF0` bit-manipulation (same). The lesson has
now cost three corrections: **when checking whether something is handled, search for the
symbol and the concept, not one spelling of the number.**

`$1400` completes the sequence with the third board-status equation: it drives `$1FFF1` bit
3 both ways against bit 1 of a value read into `d2`, matching the documented
`bit 2 of $F70019 = NOT(bit 5) OR (bit 3 AND bit 0)`. With that, **all eleven sequence-B
stages are accounted for.**

### Phase `$1200`: bit 5 is a self-clearing request, and the phases are STATEFUL

`$F09236` is the busiest of the local-board stages and it yields three things.

**1. `$F70019` bit 1 follows `$1FFF1` bit 5 directly.** A hard set/clear assertion pair:

```
bset #5,$1(a5)  ;  btst #1,$1(a4)  ;  bne ok      ; board-status bit 1 must be SET
bclr #5,$1(a5)  ;  btst #1,$1(a4)  ;  beq ok      ; ...and CLEAR
```

**2. The phases share state, and this one depends on what `$1100` left behind.** The
documented equation is `bit 1 of $F70019 = NOT(bit 4 of $1FFF1) OR (bit 5 AND NOT bit 0 of
$1FFF0)`. On entry `$F09240` clears only bit **7**; bit 4 is left as `$1100` ended it — and
`$1100` runs set → clear → **set**, so **bit 4 arrives here SET**. That makes `NOT(bit 4)`
zero and reduces the equation to `bit1 = bit5 AND NOT bit0`, which is exactly the assertion
above. *The test is only correct because of the preceding phase's final write.* An emulator
that reset VMOD_CTRL between phases — a reasonable-looking tidiness — would break `$1200`
while leaving `$1100` passing.

**3. `$1FFF1` bit 5 is polled for self-clearing.** After setting bit 7 and bit 5 together:

```
bset #5,$1(a5)
move.w #$f,d0
loop:  btst #5,$1(a5)     ; poll THE BIT IT JUST SET
       dbeq d0,loop       ; until it reads CLEAR, 16 tries
```

The firmware waits for hardware to clear a bit it wrote. **Bit 5 is therefore a
request/strobe, not a latch** — which distinguishes it sharply from bit 4, whose
flip-flop behaviour `$1100` verifies explicitly. Two bits of the same register with
different natures, each tested in the way appropriate to it.

*Stated with the hedge it deserves:* the `dbeq` is a **bounded** wait and the pass/fail
assertion that follows is on `$F70019` bit 1, not on bit 5. So a machine where bit 5 never
clears times out and still passes. The polling is strong evidence of intent — nothing polls
a bit it expects to stay put — but it is not proof, and the ROM offers no way to close that
gap.

Then the whole sequence repeats with `$1FFF0` bit 0 **set** (`$F092F8`), isolating the
`NOT bit 0` term of the equation. So `$1200` covers both terms across both settings.

**Emulator status.** `$1FFF0`/`$1FFF1` appear nowhere in the emulator's C — VMOD_CTRL is
plain RAM inside the 128 KB array, so writes stick and nothing ever self-clears. `$1100`'s
flip-flop test passes trivially and correctly. `$1200`'s bit-5 wait always exhausts all
sixteen iterations, and the stage passes only because the separately-modelled board-status
equation carries it. **The handshake is vestigial in emulation** — harmless today, but it
means the model reproduces the *result* of this stage without reproducing its *mechanism*,
and anything later that depends on bit 5 actually clearing would fail without warning.

Also worth noting: `$F09246` sets `SR <- $2200`, dropping the interrupt mask to level 2 and
installing `$F09330` as a handler. `$1200` is the first stage to run with interrupts
enabled — it is an interrupt-driven test, not a polling one, and the `dbeq` loops are its
timeouts.

### Phase `$1100` is a writable-bit test; the PTM test is 16-bit walking ones over `movep`

Two more sequence-B stages decode cleanly, and both put hard constraints on the models.

**`$1100` (`$F0918C`) tests one VMOD_CTRL bit for writability.** It loads `d0 = 4` as the
bit index and calls a mirror pair:

```
$F091C6:  bset.b d0,$1(a5)  ;  btst d0,$1(a5)  ;  bne ok   ; must read SET
$F091FE:  bclr.b d0,$1(a5)  ;  btst d0,$1(a5)  ;  beq ok   ; must read CLEAR
```

driven set → clear → set. So **`$1FFF1` bit 4 must be a genuine read/write flip-flop**, not
a strobe and not read-only. That is the same bit the phase-`$1100`/`$1200` equation refers
to as "NOT bit 4 of `$1FFF1`", and it explains why the equation can treat it as state: the
firmware has just verified it holds a value.

Note the operand-size trap again: the disassembly renders the read-back as `btst.l`, but
`btst` against a memory operand is **always byte-sized** on a 68000. Taken literally it
would suggest a longword access to a control register that has none.

**`F09154` is a 16-bit walking-ones test on a PTM timer latch, and it is why `movep`
matters:**

```
d0 = 1
loop:  movep.w d0,$0(a1)      ; write the pattern
       movep.w $0(a1),d1      ; read it back
       cmp.w   d0,d1  /  bne FAIL
       asl.w   #1,d0
       bne     loop            ; 16 iterations -- every bit
```

`movep` is the 68000's instruction for byte-interleaved peripherals, moving alternate bytes
— exactly the odd-byte MC6840 layout at `$F70001`-`$F7000F`. The routine is called **three
times** (`$F0909A`, `$F090A8`, `$F090B6`) — once per timer — which fully accounts for the
walking pattern seen across T1/T2/T3 in the PTM write log, and confirms those writes are a
register test rather than operational programming.

**The read-back is only well-defined because the timers are held in reset.** Immediately
before, `$F0917E` writes `CR2 <- $01` (selecting CR1 at register 0) and `$F09184` writes
`CR1 <- $01`, whose bit 0 is the PTM's internal reset — all three timers stop. A running
counter would decrement between the write and the read and the comparison would be a race.

That retro-justifies a modelling choice the emulator made from the datasheet alone: its
comment says "counter is always loaded from latch on this write (timer is in preset state
during init)". **This test requires exactly that** — on a real 6840 a read of registers 2-7
returns the *counter*, not the latch, so write-then-read-back can only match if the write
loads the counter and nothing then decrements it. The model is right, and now has a
firmware-derived reason rather than only a datasheet reading.

**Emulator constraints from these two stages**, both checkable: `$1FFF1` bit 4 must store
and return a written value; and all three PTM timer latches must return, through `movep.w`,
each of the sixteen walking-ones patterns while CR1 bit 0 holds the timers.

### Sweeping for hidden registers: a negative result, and two ways the sweep lies

Prompted by the `$1FFF0` miss, I re-ran every "never accessed" claim over **base-register**
forms rather than absolute addresses. The outcome is a clean negative — no hidden registers
— but getting there required fixing two opposite failure modes, and both are worth
recording because this project keeps rediscovering them.

**Failure mode 1 — false negatives, from absolute-only scanning.** Already known: it hid
the `$FF0048` read at `$F07EF6` and all eight `$1FFF0` bit-manipulations.

**Failure mode 2 — false negatives from a broken matcher.** My first base-register sweep
reported `$FF0048` as *never accessed*, contradicting a known-true fact. Cause: the
consolidated asm renders the operand as `movea.l #$ff0000  [APIF_CMD_STATUS], a5`, and my
pattern required the comma to follow the hex immediately, so the symbol annotation broke
it. **Every "confirmed" in that run was worthless**, and it would have read as a set of
strong verifications. *The lesson is to run a tool against a known-positive case before
believing any negative it produces* — `$FF0048` at `$F07EF6` is the natural ground truth
here, and it now gates the sweep.

**Failure mode 3 — false positives, from naive base tracking.** With the matcher fixed, the
sweep reported four addresses outside the documented map, three of them inside the
`$FF0100-$FF01FF` range this file had just declared unpopulated. All four are artifacts:

| candidate | actual instruction | what it really is |
|---|---|---|
| `$FF010A` | `lea.l $10a(a0),a7` | **stack-pointer setup** |
| `$FF0114` | `lea.l $114(a0),a7` | stack-pointer setup |
| `$FF0116` | `lea.l $116(a0),a7` | stack-pointer setup |
| `$FF0002` | `move.w $2(a2),d6` | real read, but `a2` is not `$FF0000` |

Two distinct bugs. **`lea` and `pea` compute addresses and access nothing** — counting them
as accesses invents registers out of stack arithmetic. And a base register's value must not
be carried across unrelated code: all four inherited a stale `$FF0000` set in a different
routine. A sweep of this kind is only sound within the basic block that sets the base.

**The validated results.** With ground truth passing (13 sites for `$FF0048`, including
`$F07EF6`), these claims **hold in both absolute and base-register form**:

| address | claim | status |
|---|---|---|
| `$FF0010` | "CMD_ARG_HI", never accessed | **holds** — genuinely an emulator invention |
| `$FF0020` | AP I/F window 1 | **holds** — the reserved window is real |
| `$FF00C0`, `$FF00E0` | windows 6-7 | **holds** |
| `$FF0100`+ | the unpopulated upper half | **holds** — the window-grid reading survives |
| `$FF025E` | BIM2 VR3 | **holds** statically, consistent with its being reached only by a computed walk gated on `$FF0218` bit 4 |

And one phrasing to tighten: `$FF004A` has **15 static sites**, all in the XP channel ISRs.
That does not contradict the statement that it is "neither read nor written in a full boot"
— those ISRs do not run without a channel interrupt — but the unqualified wording invites
exactly the error that bit us on `$FF0048`. *Static absence and runtime absence are
different claims and should never share a sentence.*

**Net: the documented register map is complete for base-register forms.** That is a
worthwhile negative — it converts "we haven't seen anything else" into "we looked properly
and there is nothing else", which is what the emulator's device decode needs to rest on.

### `MemBusProbe` is a complete truth table, and `$1FFF0` IS bit-manipulated

Phase `$1000` (`MemBusProbe`, `$F08F9A`) sets two VMOD_CTRL bits in all four combinations
and calls a checker at `$F0903C` each time:

```
$F0903C:  bclr.b #$6,$1(a5)        ; clear $1FFF1 bit 6
          move.w #$f,d0
   loop:  btst.b #$3,$1(a4)        ; poll $F70019 bit 3
          dbeq   d0,loop           ; until it reads CLEAR, or 16 tries
          rts
```

| `$1FFF1` b7 | `$1FFF0` b1 | branch | requires |
|---|---|---|---|
| 0 | 0 | `bne` | bit 3 stays **set** |
| 0 | 1 | `bne` | bit 3 stays **set** |
| 1 | 0 | `bne` | bit 3 stays **set** |
| **1** | **1** | **`beq`** | bit 3 goes **clear** |

That is `bit3 = NOT(b7 AND b1)`, and since the checker clears bit 6 on entry it is exactly
the equation the emulator already models: **`bit 3 of $F70019 = NOT(bit 6 OR (bit 7 AND bit
1))`**. The equation was previously derived from observing phase `$800`; this is the
firmware testing it as a **complete four-case truth table**, which is considerably stronger
evidence than a spot-check — the AND is exercised on every input combination, so the
emulator's boolean cannot be accidentally right.

**Correction: `$1FFF0` is bit-manipulated, in eight places.** This file and `CLAUDE.md`
state that `$1FFF0` — the control register byte carrying *VersaBus Transfer Request* and
*Block Transfer Request* — "is written `$00` every time and never bit-manipulated", and use
that to conclude **the firmware never asserts a transfer request**. The scan behind it
found zero hits because there are **zero absolute-address forms**; every access is through
`a5`:

| site | operation | actual bit |
|---|---|---|
| `$F08FA8`, `$F08FCC`, `$F08FE8`, `$F09010`, `$F0902C` | `bclr`/`bset` `#$1,(a5)` | bit 1 |
| `$F092B2`, `$F092F8`, `$F09320` | `bclr`/`bset` `#$8,(a5)` | **bit 0** |

*Note the second row's reading trap:* `bclr.b #$8` on a byte operand is bit `8 mod 8` = **bit
0**, not bit 8. Taking the disassembly literally would invent a nonexistent bit and miss a
real one. Bit 0 is the same bit the phase-`$1200` equation refers to as "NOT bit 0 of
`$1FFF0`", which is the independent corroboration that this reading is right.

**This is the same blind spot that hid the `$FF0048` read** — an absolute-address sweep
cannot see `d16(An)` forms, and this project has now been bitten by it twice on separate
registers. Any claim of the form "X is never accessed" derived from an address scan should
be treated as unproven until re-run over base-register forms.

**What survives and what does not.** The narrow claim — that *service* code writes `$1FFF0`
as a whole byte of `$00` — is untouched; all eight manipulation sites are inside the
power-on self-test. The broad claim, that the firmware never asserts a transfer request, is
**retracted**: the self-test asserts bit 1 deliberately, four times, as one input of a
truth table. Whether bit 1 *is* the transfer-request line is a separate question the ROM
cannot answer, but "the firmware never touches it" is no longer available as a premise.

### Phase `$1900` is the 16-to-32-bit width conversion, and `$FF0214` is the low-half latch

This is the mechanism by which a **16-bit VersaBus SBC writes 32-bit words into a 32-bit
chassis memory**, and the self-test proves it in both directions.

`$1900` first establishes that the window is genuinely 32 bits wide: it writes
`$55555555` to `$400000` as a longword and reads it back with `cmp.l` — the complementary
pattern to the `$AAAA` used on the AP I/F, and the same all-data-lines logic one word
wider. It then runs two helpers, each twice, varying only `$FF0216` bit 4:

```
$F09806:  move.l d0,(a0)  ;  move.w d1,(a0)        ;  cmp.l (a0),d2
$F0981A:  move.l d0,(a0)  ;  move.w d1,$214(a6)    ;  cmp.w $2(a0),d2
```

| helper | `$FF0216` | required result | meaning |
|---|---|---|---|
| `$F09806` | `$10` | `$AAAA5555` | the CPU's word write **landed** in the high half |
| `$F09806` | `$00` | `$55555555` | the CPU's word write was **suppressed** |
| `$F0981A` | `$10` | low word `$5555` | `$FF0214` **did not reach** the window |
| `$F0981A` | `$00` | low word `$AAAA` | `$FF0214` **supplied** the low half |

**`$FF0216` bit 4 is a multiplexer on the low half of the 32-bit chassis word.** Set, the
CPU's own word writes take effect and `$FF0214` is inert. Clear, CPU word writes are
ignored and `$FF0214` sources the low half instead. The four cases are mutually
complementary — each configuration's *positive* result is the other's *negative* — which
is why the test needs exactly four probes and no more.

**This is the first concrete evidence for the width-conversion role** that the card
descriptions only hinted at. The chassis path is documented as
`XLTR → UNIV FMT → XP32`, with the FMT card's own part description reading "UNIV FMT 32 BIT
IEEE FPS3000", and this project has carried an open question about whether it does 16-to-32
width conversion. Here is a firmware-visible mechanism for assembling a 32-bit word from a
16-bit bus: latch the low half in `$FF0214`, then write the high half, with bit 4 selecting
which source feeds the low lanes. *Note this does not identify which card implements it* —
the SBC sees only the XLTR's registers, and whether the mux sits on the XLTR or further
down the path is not observable from here.

**It also resolves the `$216` naming conflict flagged above, against the asm.** The
consolidated disassembly labels `$FF0216` `XLTR_DATA_HI`, which would make it the partner
of `$FF0214` `XLTR_DATA_LO`. It cannot be: `$1700`/`$1800` use its **bit 5** as the window
access gate and `$1900` uses its **bit 4** as this mux. A data register does not have
per-bit control semantics. **`$FF0216` is a control register**, and the register table's
"mode/page register (not a command register)" reading is the correct one. The `XLTR_DATA_HI`
label should be treated as wrong wherever it appears.

That leaves `$FF0214` correctly named: it *is* a data register, specifically the low-half
latch, which explains the standing observation that it "never appears standalone — every
access is the leading half of a 32-bit access paired with `$FF0216`". The pairing is real;
the interpretation of the partner was not.

### `$FF0216` bit 5 gates the `$400000` chassis window, and `$1700`/`$1800` prove it

The `$1700`/`$1800` pair looked identical in register shape. They are the **read** and
**write** halves of one test, and what they test is an access gate.

Both install a private bus-error handler and probe `a1 = $400000` through a one-instruction
accessor:

```
$F096AC:  move.w (a1),d0    nop nop nop nop   rts     ; $1700 -- READ probe
$F096B8:  clr.w  (a1)       nop nop nop nop   rts     ; $1800 -- WRITE probe
```

and the handler is a trap-and-continue:

```
$F098E0:  moveq   #$1,d1          ; FLAG: a bus error happened
          lea     $8(a7),a7       ; drop 8 bytes of the 14-byte group-0 frame
          addq.w  #$4,$4(a7)      ; advance the saved PC by 4
          rte
```

**So `d1` nonzero means the access FAULTED, not that it succeeded** — and reading the test
with that polarity inverts its meaning:

| `$FF0216` | expectation | assertion |
|---|---|---|
| `$20` | `tst d1` / `bne` — **bus error REQUIRED** | fail if the access is answered |
| `$0` | `tst d1` / `beq` — **access must SUCCEED** | fail if it faults |

**`$FF0216` bit 5 blocks the `$400000` window.** It is a protect/disable bit, not an
enable: setting it makes chassis memory raise a bus error, clearing it lets the window
respond. The self-test verifies the gate in both directions and for both access
directions, which is four combinations and exactly the eight call sites observed
(`$F096AC` x4, `$F096B8` x4).

**The four NOPs are landing padding for the 68000's imprecise bus error.** A 68000 reports
a bus fault some cycles after the instruction that caused it, so the probe cannot be the
last instruction before `rts`. The handler's `addq.w #$4` is calibrated against that
padding: `move.w (a1),d0` at `$F096AC` is two bytes, so the saved PC is `$F096AE` and +4
resumes at `$F096B2` — *inside the NOPs*. The padding is what makes a fixed +4 skip safe
regardless of which instruction the fault is attributed to.

The frame arithmetic is worth spelling out because an emulator has to match it. The 68000
group-0 frame is 14 bytes — SSW, 4-byte fault address, IR, SR, 4-byte PC. `lea $8(a7),a7`
lands a7 on the SR, leaving `{SR, PC}` — a normal 6-byte RTE frame. `$4(a7)` is then the
**low word** of that PC longword, and `addq.w #4` advances it. *This is the code that the
vendored Musashi patch exists to satisfy*: the core was hard-coded for the 68010's frame
format, and against a 68010 frame the `lea $8` would land on the wrong word and the `rte`
would return to garbage.

**Emulator consequence.** The model must (a) raise a bus error on `$400000` accesses when
`$FF0216` bit 5 is set, (b) answer them when it is clear, and (c) push a genuine 68000
7-word frame. Getting (c) wrong fails silently into a wild `rte`, which is the worst
failure mode available — and this stage is the only place in the ROM that exercises it.

### Phase `$1600` is a written specification of the XLTR register file

`$F09518` is the most informative single stage on the board: it writes known values to
every XLTR register, then reads them back under explicit masks. **The masks are the
specification** — they say exactly which bits the firmware requires the hardware to
implement.

*Write phase.* Six named registers get fixed values (`CHANNEL_SELECT <- d6`,
`MODE1 <- $2000`, `MODE0 <- $0`, `COUNTER <- $1`, `STATUS_IRQ <- $400`,
`IRQ_MASK <- $FFF`), then two walks:

```
d0=$10, a0=$210:  write (a6,a0.w); a0+=2; lsl.b #1,d0; bcc loop
    -> $FF0210 <- $10   $FF0212 <- $20   $FF0214 <- $40   $FF0216 <- $80
d0=$C0, a0=$230:  write (a6,a0.w); a0+=2; d0+=1; cmp d1,d0; bne loop
    -> $FF0230 upward, one distinct value per register
```

*Read-back phase — the masks:*

| register | mask | must read | consequence |
|---|---|---|---|
| `CHANNEL_SELECT` `$204` | `$FFFF` | `d6` | all 16 bits implemented |
| `MODE1` `$202` | `$FFFF` | `$2000` | all 16 bits implemented |
| **`MODE0` `$200`** | **`$00FF`** | `0` | **only the low byte is required** |
| `COUNTER` `$20C` | `$FFFF` | `$1` | all 16 bits implemented |
| **`STATUS_IRQ` `$218`** | **`$0610`** | `$400` | **only bits 4, 9, 10 are required** |

MODE0's mask is the striking one, and it corroborates an independent finding: the chassis
command byte is **the low byte of MODE0**, latched at `$E86`/`$E87`. The self-test checks
exactly the half that carries the command and ignores the rest.

**`$FF0218` bit 4 selects a two-BIM or three-BIM machine.** The second walk's bound comes
from a test made at entry:

```
move.w $218(a6),d0 ; btst #4,d0
    bit 4 clear -> d1 = $D0    bit 4 set -> d1 = $D8
```

and the walk runs while `d0 != d1` from `$C0`:

| d1 | writes | range | = |
|---|---|---|---|
| `$D0` | 16 | `$FF0230`-`$FF024E` | **2 BIMs** |
| `$D8` | 24 | `$FF0230`-`$FF025E` | **3 BIMs** |

Landing exactly on BIM boundaries — 16 = 2x8, 24 = 3x8 — is what makes this more than
arithmetic coincidence. The natural reading is a **presence/configuration strap for the
third BIM**; the ROM alone cannot confirm the semantics, only the branch.

*This resolves a standing oddity.* The register table records three BIMs with "23 of the 24
used; only `$FF025E` (BIM2 VR3) is never touched". That is now explained rather than merely
observed: **`$FF025E` is the last register of the third BIM, and it is written only when
bit 4 is set.** Our configuration reads bit 4 clear, so the walk stops at `$FF024E` and the
final register is never reached. The apparent 23-of-24 asymmetry is not an asymmetry in the
firmware at all — it is our chassis model presenting a two-BIM machine.

**Emulator consequence.** If the intent is to model the documented three-BIM chassis, the
model must set `$FF0218` bit 4, and phase `$1600` will then write all 24 BIM registers. It
currently does not, which is a defensible choice only if a two-BIM chassis is what is
being modelled — and that should be a stated decision rather than an accident of a
default.

**And `$FF0212` is addressed as a standalone word here**, by `move.w d0,(a6,a0.w)` with
`a0 = $212`. This file elsewhere says `$FF0212` "is not a register — its bus-log accesses
are the second half of 32-bit accesses to `$FF0210`, split by the logger". That remains
true of the *service* code it was derived from, but it cannot be stated unconditionally:
the self-test writes `$FF0212` alone, so the hardware decodes it.

### Sequence B is an outward walk, and its last stage is an AP I/F data-line test

Resolving the eleven sequence-B stages against their base registers (`a6 = $FF0000`,
`a5 = $1FFF0`, `a4 = $F70018`) gives a per-stage device map. It is not an arbitrary
ordering — **the tests walk outward from the SBC's own registers to the chassis**:

| phase | addr | touches | what it is |
|---|---|---|---|
| `$1000`-`$1400` | `$F08FE2`-`$F093CE` | `$F70001`, `BOARD_STATUS`, `VMOD_CTRL` (absolute) | local board + PTM |
| `$1500` | `$F094F0` | `CHANNEL_SELECT` R/W only, 40 bytes | CHANNEL_SELECT readback |
| `$1600` | `$F09518` | MODE0, MODE1, CHANNEL_SELECT, COUNTER, MODE2, STATUS_IRQ, IRQ_MASK | **the XLTR register-file test** |
| `$1700` | `$F09602` | CHANNEL_SELECT, MODE2 R, `$216` R/W ×4 | window/page machinery |
| `$1800` | `$F096C4` | *identical shape to `$1700`* | its pair — second half |
| `$1900` | `$F09776` | CHANNEL_SELECT ×5, **MODE2 W**, **DATA W**, `$216` ×4 | the data path into chassis memory |
| `$1A00` | `$F09832` | **`APIF_CMD_STATUS` ×2 W**, CHANNEL_SELECT ×4, `$216`, STATUS_IRQ | **the AP I/F itself** |

`$1600` is the stage behind the emulator's "33 distinct XLTR registers" boot statistic, and
`$1A00` is the *only* sequence-B stage that touches `$FF000E`. So the self-test's own
ordering is a statement about the SBC's reach: own registers, then the window hardware,
then data into the chassis, then the chassis command port.

**Phase `$1A00` in detail — two findings.**

*It is bus-error-tolerant by construction.* `$F09836` saves the existing bus-error vector
and installs its own at `$F098E0`:

```
movea.l $8.w,a0                  ; save the old vector
move.l  #loc_F098E0,$8.w         ; install a private handler
```

So this stage **probes for presence** and expects that some accesses may not be answered —
which is exactly the right shape for a test of an interface whose far side may be absent.
Any emulator that BERRs here without a matching handler model diverges.

*It is an all-16-data-lines test on `$FF000E`.*

```
move.w  #$aaaa,$e(a6)            ; write
cmpi.w  #$aaaa,$e(a6)            ; read back and compare
beq     ok
move.l  #$F0F0F0F0,d7            ; else the failure marker
```

`$AAAA` is `1010101010101010` — the classic alternating pattern that exercises every data
line and catches shorts between adjacent bits. **The register reads back what was written.**

That is worth stating carefully against what this file says elsewhere. `+$0E` is documented
as *bidirectional — command on write, status on read*, and that stands for the channel
windows in service. But here, on the **base window** during self-test, it behaves as a plain
latch. Two readings fit and the ROM cannot separate them: the port genuinely latches when
no command is in flight, or the chassis is simply not answering during power-on so the
write survives to be read back. **Either way the emulator must return `$AAAA` from
`$FF000E` after a `$AAAA` write in this phase, or the self-test fails** — a hard,
checkable constraint on the chassis model that no previous note captured.

*Naming conflict noted, unresolved:* the consolidated asm labels `$216` as `XLTR_DATA_HI`
while the register table in `CLAUDE.md` calls it a mode/page register. The `$214`/`$216`
pairing as a 32-bit data register is the better-evidenced reading; the table entry predates
it and should be treated as suspect rather than authoritative.

### The self-test is THREE sequences separated by `$D0` checkpoint handshakes

The spine is `$F08764-$F088D0`, and it settles what the phase beacons mean. `d6` is the
phase counter, bumped `addi.w #$100,d6` between tests and written to **CHANNEL_SELECT**
with its low byte cleared (`$F098F0`) — which is why `$FF0204` is the hottest register on
the board at ~33 k writes against 7 reads. **The SBC broadcasts its test progress to the
chassis.**

Each sequence ends with the identical four-instruction epilogue —

```
move.w  #$d0,(a5)              ; VMOD_CTRL <- $D0   the checkpoint marker
move.w  #$8000,$202(a6)        ; XLTR_MODE1 bit 15  request
move.l  #loc_F088FA,$154.l     ; install a handler
btst d4/d5 on $F70018          ; wait for the chassis to answer
```

— and the next sequence opens by clearing VMOD and writing `XLTR_MODE1 <- $2000`. So
`$2000` is *run mode* and `$8000` is *request/handshake*, and the `$D0` markers are a
three-step conversation with the chassis. This is what the emulator's board-status bit 5
models by counting `$D0` writes; the spine confirms that reading was right.

| | `d6` base | tests | run under |
|---|---|---|---|
| **A** | `$200` | 8: `$F08C4A`, `$F08D1A`, `RAMAddressingTest`, `BoardStatusPoll_3F11`, `PTMInit`, `$F08E2E`, `$F08F1C`, `$F08F70`, `$F0905A` | the board's power-on XLTR mode |
| **B** | `$1000` | 11: `MemBusProbe`, `$F0918C`, `$F09236`, `$F09338`, `$F093CE`, `$F094F0`, `$F09518`, `$F09602`, `$F096C4`, `$F09776`, `$F09832` | **after `XLTR_MODE1 <- $2000`** |
| **C** | `$2000` | DRAM, then `$F09AD6`, `$F09B20` | ditto |

That accounts exactly for the observed phase range `$0100-$1A00` plus `$2000` — the groups
are not an arbitrary numbering, they are three passes with the counter re-based.

**Sequence C is the DRAM test, and it is destructive and self-aware.** It walks the two
64 KB halves with a scratch area outside each:

```
a0=$0      a1=$400     a2=$1F000   -> $F08A4C
a1=$10000                          -> $F08992    ; lower RAM, $0-$10000
lea $800.w,a7                      ; MOVE THE SUPERVISOR STACK
a0=$1F000  a1=$1F400  a2=$0        -> $F08A4C
a0=$10000  a1=$20000               -> $F08992    ; THE MICROCODE STAGING BUFFER
```

The `lea $800.w,a7` at `$F08886` is the tell: the normal supervisor stack at `$1FFD0` lies
*inside* the `$1F000-$1F400` region about to be written, so the test relocates its own
stack to `$800` first. A test that did not know it was destroying its own stack would not
do that. **And the second half tested is `$10000-$20000` — the XP32 microcode staging
buffer**, so the machine verifies the buffer the entire ROM exists to fill before it will
run.

**Documentation status, as a work list.** 42 distinct subroutines are called from
`$F08700-$F09C00`; **3 carry a `;###` note and 39 do not**. The spine above is the frame
they hang on, and sequence B is the high-value group for board mapping — it is the one
that runs with the XLTR enabled, so those eleven tests are where off-board communication
is exercised.

### The system tick is 10 ms — and the emulator's is 27% slow

The PTM's operational programming is a nine-write sequence at `$F0A298`-`$F0A2E4`, and the
walking-ones writes at `$F09156` that dominate the access log are a **register test**, not
configuration:

```
$F0A298  CR2      <- $01     ; bit 0 = 1, so register 0 addresses CR1
$F0A29E  CR1      <- $01     ; internal reset ON, all timers held
$F0A2C6  T3 latch <- $27C7
$F0A2CE  T1 latch <- $0100
$F0A2D2  CR2      <- $00     ; bit 0 = 0, so register 0 now addresses CR3
$F0A2D8  CR3      <- $C6
$F0A2DE  CR2      <- $01     ; back to CR1
$F0A2E4  CR1      <- $00     ; release reset, timers run
```

`CR3 = $C6` decodes as: prescaler **off** (bit 0), clock source **internal E** (bit 1),
**dual 8-bit** mode (bit 2), continuous (bits 3-5), interrupt **enabled** (bit 6), output
**enabled** (bit 7).

In dual 8-bit mode the period is **(MSB+1) × (LSB+1)**, not `latch+1`. With
`$27C7`: `MSB = $27 = 39`, `LSB = $C7 = 199`, so `40 × 200 = 8000` E-clock cycles. E is
CPU/10 = **800 kHz**, giving

**8000 / 800 000 = 10.0000 ms — a 10 ms system tick.**

Landing on exactly 10 ms is itself the check: a misread mode or divider would not produce a
round number, and RMS68K's `DELAY` directive is specified in *milliseconds*.

**T1 is not a timer.** `CR1 = $00` has bit 1 clear — **external clock** — and bit 6 clear,
interrupt disabled. So T1 (latch `$0100`) is an **external-input counter** the firmware can
read, not a periodic source. **T2 is never programmed operationally at all**; only the
register walk touches it.

#### The emulator's tick is 12.73 ms

`mc6840.c:170-176` decrements a 16-bit `counter[t]` and reloads `latch[t]` on underflow —
**dual 8-bit mode (CR bit 2) is not modelled**. So T3's period is `$27C7`+1 = 10 184 E
cycles = **12.73 ms**, making the emulated tick **27% slow**.

Fixing it needs the LSB half to count down each clock, decrement the MSB half on its
underflow, and fire only when the MSB half underflows — which also makes T3's counter reads
meaningful, and the firmware does read T3 MSB (`$F7000D`, 1852 reads). **This is left as a
flagged defect rather than a silent change: correcting the tick moves every timing-dependent
result, so all three golden-master digests will move with it, and that should be a
deliberate step taken with the diff in hand rather than a side effect of a documentation
pass.**

*One documentation error in the emulator while here: the comment at `mc6840.c:136` says "the
RTOS programs CR1 = $C6 at $F0A2D8". It programs **CR3** — `$F0A2D2` clears CR2 bit 0
immediately before, which switches register 0 from CR1 to CR3. The value and address are
right; the register name is wrong, and the distinction is exactly what makes the prescaler
bit T3-only.*

### The `$FF0100` "gap" is unpopulated windows, and window 1 is skipped by design

The AP I/F block reads as a uniform grid of `$20`-byte windows, index
`N = (addr − $FF0000) / $20`:

| N | range | populated as |
|---|---|---|
| 0 | `$FF0000-$FF001F` | host / bulk link |
| **1** | `$FF0020-$FF003F` | **never accessed** |
| 2 | `$FF0040-$FF005F` | XP channel 1 |
| 3 | `$FF0060-$FF007F` | XP channel 2 |
| 4 | `$FF0080-$FF009F` | XP channel 3 |
| 5 | `$FF00A0-$FF00BF` | XP channel 4 |
| **6-7** | `$FF00C0-$FF00FF` | **never accessed** |

**Window 1 is skipped by the firmware's own arithmetic, not by omission.** `$F053E8`
computes a channel's command port as `(ch+1)<<5 + $FF000E`, so channel 1 lands at window
**2**. The `+1` is deliberate: window 1 is architecturally reserved, with the host link at
window 0 ahead of it. What it is for is not established — a second host port, or the IOP
that `CHANNEL_SELECT` is documented to select among, are both consistent and neither is
evidenced.

**And the "unaccounted 256-byte gap at `$FF0100-$FF01FF`"** — carried as an open item in
the gap analysis — is simply **windows 8-15 of the same grid**, none populated. It is not a
hole in an otherwise-mapped block; it is the unpopulated upper half of a uniformly
windowed 512-byte region, and there is nothing to account for. *That retires the item
rather than answering it, which is the honest disposition: the question presupposed a
structure the block does not have.*

The emulator gets this right, which is worth recording since much of this session has been
corrections: `versabus.c:166` decodes channels as `addr >= 0xFF0040 && addr <= 0xFF00BF`
with `ch = ((addr − 0xFF0040) >> 5) + 1` — exactly windows 2-5, correctly excluding window
1 and windows 6-7. And `APIF_END` is `$FF0100`, so an access into the upper half falls
through to `versabus_note_unmapped()` and is reported rather than silently answered.

### "Panel command" is a project-invented name, and VERSAdos means something else by it

The whole of this project calls the `$FF000E` protocol "panel commands" —
`PanelIOCommand`, `PCMD_*`, `PanelStatusDispatch`, "the panel-command issuer". That name
has no basis in either FPS or Motorola terminology.

`SR10/U9995/PANEL.EQ` is fourteen lines and defines a **physical front panel**:

```
*         FRONT PANEL EQUATES
FPDMPTST  DS.W 1    MEMORY DUMP, ENABLE, SYSTEM TEST
FPTTO     DS.W 1    TEST TIME-OUT
FPLEDST   DS.W 1    LED STATUS
```

Switches and lamps. So in this ecosystem "panel" means a front panel, and the `$FF000E`
codes are not one — they are a **chassis command/status protocol** on the base AP I/F
window's command register. The naming came from the prior disassembly passes, not from
any document about this machine.

*This matters for the same reason the `$4F` status value and `$FF0010 = CMD_ARG_HI`
mattered: an invented name sitting in a document beside real findings starts to read like
one.* Three cases now — a fabricated register value, a modelled non-register, and a
borrowed word — and in each the tell was that no external source used it.

The names are not worth churning across a thousand annotations, but the record should say
plainly: **`PCMD_*`, `PanelIOCommand` and `PanelStatusDispatch` are this project's labels
for the chassis command/status protocol at `$FF000E`, chosen before the protocol was
understood, and imply nothing about a front panel.**

And the machine does have a front panel — `refs/FPS-3000/fps-3000-fp.jpg` — but the ROM's
front-panel-adjacent I/O is elsewhere: the **board status register** `$F70018`/`$F70019`
(9 absolute references) and the **VERSAmodule control register** `$1FFF0`/`$1FFF1` (23),
which is where the FAIL lamp the monitor drives actually lives. If any register in this
machine deserves the name "panel", it is those, not `$FF000E`.

### The ring queue is the TRACE BUFFER, and `!IDV` is the only non-standard structure

`INIT.SA` has a **seventh** build block after `BLDUDR`:

```
BLDTRAC  CLR.L  TRACEBEG      CLEAR SYSPAR ADDRESS IN CASE TRACE NOT NEEDED
         MOVE.L #T0PAGAL,D0
BLDTRC01 MOVE.L A0,TRACEBEG   SAVE ADDRESS FOR EXEC
BLDTIAT  MOVE.L #$01010000,TIAT   SET TRAP 0 AND 1 'USED BY EXEC'
```

**So the untagged ring at `$1F500` (slot `$0C30`) is the TRACE BUFFER.** This document
guessed, from the shape of `$F01688` — a masked-interrupt ring enqueue — that "a
masked-interrupt ring buffer filled by a driver hook is the shape of a trace or deferred-
event log", and flagged it as inference. `BLDTRAC` and `TRACEBEG` confirm it by name. It
carries no eye-catcher because `BLDTRAC` writes none, exactly as observed.

Two more globals fall out of the same four lines:

| address | name | evidence |
|---|---|---|
| `$0C30` | **`TRACEBEG`** | the trace buffer pointer, 7th allocation |
| `$0C34` | **trace flags** | `$F044A2` does `btst.b #$0E,$0C34`; `TRCFTRP1` = 15 and `TRCFDSPT` = 10 are neighbouring flags |
| `$0C9A` | **`TIAT`** | `$F0A04E` writes `$01010000` — *"set TRAP 0 and 1 'used by exec'"* |

`$0C9A` and its constant were recorded here with no meaning attached. `BLDTIAT` supplies
both: `$01010000` marks **TRAP 0 and TRAP 1 as claimed by the exec**, which is why this
firmware uses only those two and the other fourteen TRAP vectors are free — the fact the
monitor relies on, now with its mechanism.

**And the FPS kernel hook is a trace point.** `$F044A2` — the routine installed into
`+$4C` of a structure by two kernel sites — tests **bit 14 of the trace flags** and, if
set, calls `$F01688` to enqueue a trace record, *then* walks the driver chain. So the
insertion this document described as "a device-driver dispatch chain" is a **traced**
dispatch chain, and the trace half explains why it references `$0C34` at all.

#### The structure inventory is now closed

| ROM allocation | slot | `INIT.SA` block |
|---|---|---|
| `!GST` | `$0C20` | `BLDGST` |
| `!UST` | `$0C24` | `BLDUST` |
| VTU | `$0C66` | `BLDVTU` |
| `!IOV` | `$0C6A` | `BLDIOV` |
| **`!IDV`** | `$0C6E` | **none** |
| `!PAT` | `$0C2C` | `BLDPAT` |
| `!UDR` | `$0C28` | `BLDUDR` |
| trace buffer | `$0C30` | `BLDTRAC` |

Seven of the eight are standard RMS68K, **in `INIT.SA`'s own order**, with `!IDV` inserted
after `IOV`. So **`!IDV` is the single non-standard structure in the machine** — and
`IDV` appears nowhere in 44 MB of VERSAdos source, exactly like directive `$4C` = 76.

*Two independent absences pointing at one feature.* `!IDV` holds `{vector, TCB, ISR entry,
ISR exit}` — precisely what a connect-interrupt-vector directive would record — and `$4C`
is that directive. So they are one addition: **the connect-interrupt-vector facility and
its connection table are not in any RMS68K release available here**, whether because this
build is a later branch or because FPS added them. The slot grouping supports it too:
`$0C66`/`$0C6A`/`$0C6E` are a contiguous interrupt-and-vector pointer group, and `!IDV`'s
slot sits at its end.

### `$1FA00` is the **VTU**, not `!VCT` — and `!VCT` is ROM-resident

Searching the ROM for every eye-catcher, rather than only RAM, moves several markers.

#### `$1FA00` is the "Vector Table for Users"

`INIT.SA`'s `BLDVTU` block is line-for-line the code decoded here at `$F09F0E`:

```
BLDVTU   MOVE.L #1,A0        SIZE IS ALWAYS ONE PAGE
         MOVE.L #T0PAGAL,D0
         TRAP   #0
         BSR    KILLER
BLDVTU01 MOVE.L VCTUBGN,A4   RESTORE ADDRESS OF COMINT ROUTINE
BLDVTU02 CMP.L  (A2)+,A4     IS VECTOR POINTING AT COMINT ROUTINE?
         BEQ.S  BLDVTU04     BRANCH IF YES - DO NOT SET 'USED' FLAG
         MOVE.B D2,(A0)      SET 'USED' FLAG
BLDVTU04 LEA    1(A0),A0     INCREMENT TABLE ADDRESS
```

So the untagged one-page allocation at `$1FA00` (slot `$0C66`) is the **VTU — Vector
Table for Users**, one byte per exception vector. The register this document called "a
reference handler in `a4`" is **`VCTUBGN`, the address of the COMINT (common interrupt)
routine**, and the `$FF` byte is a **'used' flag**: set for every vector that does *not*
point at the common handler, i.e. every vector somebody has claimed.

That is a better account than the one published here, which described the same code
correctly but read the flag as "differs from the reference handler". It also explains why
the table carries no eye-catcher — `BLDVTU` writes none.

The later fill still holds: `$F0226A` overwrites each connected vector's byte with the
**owning task number**, which is how `$41`→6, `$45`→1 … `$4A`→5 arise. So the VTU's life
is: used-flags at init, task numbers as vectors are connected.

#### The real `!VCT` is in ROM at `$F0011A`, and it is searched for

`VECTINIT` searches from `ESTART` for the `'!VCT'` eye-catcher within `$200` bytes,
stepping **two** bytes at a time, and `BSR KILLER` if it is not found. The ROM has
`'!VCT'` at **`$F0011A`**, preceded by the longword `$00F00186` — an address, not an
opcode — so that is the linked-in table, part of the kernel image rather than an
allocation.

**This document states that `!CCB`, `!DLY` and `!VCT` "have kernel code but no tagged
instance". For `!VCT` that is wrong** — it has a ROM-resident instance, invisible to a
RAM-only search. `!CCB` at `$F03EF0` and `!DLY` at `$F02D9A` are each preceded by a
store opcode (`move.l #tag,(a1)`, `move.l #tag,d16(a2)`), so those eye-catchers are
*written at runtime*: their instances are dynamic and simply never created in this
configuration. Same for `!ASQ` at `$F023B6`.

#### And two smaller confirmations

`VECTSRCH`'s shape — compare an eye-catcher, step 2 bytes, bounded search, `BSR KILLER`
on failure — is **exactly** the `!TCB` search decoded here at `$F0A074`, which confirms
that **`$F0A306` is `KILLER`** (`T0KILLER`, "crash system — error detected"). The
inference that a failed table search crashes the machine was right.

*The lesson for the marker census: "no instance" meant "no instance in RAM". Three of the
twelve markers live in ROM or are created dynamically, and a census built from RAM dumps
cannot distinguish "absent" from "elsewhere".*

### `INIT.SA` is the source of the allocation sequence — and `+$0C` is *max entries*

`text/verdos10/M68XXX/INIT.SA` is the RTOS-init source, and its `BLDGST`/`BLDUST`
blocks are line-for-line what this document decoded at `$F09E78`-`$F09EFE`:

```
BLDGST   CLR.L  GSTBEG              ; clr.l $0C20         -- the directory slot
         MOVE.L GSTSIZ(PC),D2       ; move.l d16(pc),d2   -- the size
         BEQ.S  BLDUST              ; beq                 -- zero size, skip
         MOVE.L D2,A0
         MOVE.L #T0PAGAL,D0         ; moveq #$04,d0
         TRAP   #0
         BSR    KILLER              ; the bsr on the error path
         MOVE.L A0,GSTBEG           ; move.l a0,$0C20
         BSR    TBLCLR              ; clear to zeroes
         MOVE.L #'!GST',(A0)        ; the eye-catcher
         MOVE.W #1,GSTNSEG(A0)
         MOVE.W D2,GSTNPAGE(A0)
         LSL.L  #8,D2               ; pages -> bytes
         SUB.L  #GSTENTRY,D2        ; less the header
         DIVU   #GSTEL,D2           ; / entry length
         MOVE.W D2,GSTMENT(A0)      ; MAXIMUM NUMBER OF ENTRIES
         LEA    GSTENTRY(A0),A2
         MOVE.L A2,GSTFENT(A0)
```

Every element this document derived is there: the zero-size guard, the page allocator,
the eye-catcher, and the "capacity" arithmetic. The error `bsr` is **`KILLER`**, and
`STR.EQ` gives `T0KILLER EQU 32 "CRASH SYSTEM -- ERROR DETECTED"` — so the branch after
each failed allocation crashes the machine deliberately.

#### Correction: `+$0C` is `MENT`, maximum entries — not the record size

`GST.EQ` and `UST.EQ` name the header:

| offset | field | meaning | this document said |
|---|---|---|---|
| `+$00` | `UST`/`GST` | eye-catcher | ✓ |
| `+$04` | `xxxNEXT` | link to next table segment | — |
| `+$08` | `xxxNSEG` | number of segments in table | "`+$08` = 1, ?" |
| `+$0A` | `xxxNPAGE` | number of pages | ✓ pages |
| `+$0C` | **`xxxMENT`** | **maximum number of entries** | **"record size" ✗** |
| `+$0E` | `xxxCENT` | current number of entries | ✓ in use |
| `+$10` | `xxxFENT` | address of first entry | ✓ |

**The capacity figure published here was circular.** `!UST` holds `$16` at `+$0C`, which
this document read as a 22-byte record size and then used as the divisor to compute
"capacity 22" — dividing by the very field it was misnaming, and landing on the right
number because `MENT` *is* 22. Verified properly: `(NPAGE × 256 − $14) ÷ $16 =
(512 − 20) ÷ 22 = 22`, and the ROM holds `USTMENT = 22`. The record size is separately
`$16` because `USTEL` happens to be 22 in this build — two different quantities that
coincide, which is exactly what made the error invisible.

#### The UST entry, and a fourth confirmation of the semaphores

```
+$00 USTTNAME  originator's task name    XP1I      XP1I      XP2I
+$04 USTSESSN  originator's session      0         0         0
+$08 USTSNAME  SEMAPHORE NAME            AXP1      HXP1      AXP2
+$0C USTUCNT   # users of semaphore      1         1         1
+$0E USTXCNT   initial count             0         0         0
+$0F USTTYPE   SEMAPHORE TYPE (1,2 or 3) 2         2         2
+$10 USTSEM    the semaphore itself      0         0         0
```

**`USTSNAME` is "SEMAPHORE NAME"** and it holds `AXP1`/`HXP1`/`AXP2` — a fourth
independent confirmation, after the `CRSEM` counts, the `!UST` expansion and the null
`TCBASQ`. Each has one user and is **type 2** of the three the source allows.

#### A revision tension worth recording

SR10's `USTEL` sums to **28** bytes (`USTTNAME` 4, `USTSESSN` 4, `USTSNAME` 4, `USTUCNT`
2, `USTXCNT` 1, `USTTYPE` 1, `USTSEM` 6, **`USTSPTR` 4, pad 2**). This ROM's entry is
**22** — it omits `USTSPTR` and the pad, so its UST is an **earlier** revision than SR10.
Yet directive `$4C` = 76 is **beyond** SR10's directive table, which points *later*. So
this RMS68K build is not simply "SR10 or newer": it is a different branch, or FPS built
from mixed sources. *Two facts pulling opposite ways is worth leaving visible rather
than picking whichever supports a tidier story.*

### `!PAT` is the Periodic Activation Table, and the task prologue is a Segment PB

Two more structures named from the VERSAdos source, both matching decodes made here
empirically.

#### `!PAT` — entry length `$1E` computed from the field list

`SR10/U9995/PAT.EQ`:

```
+$00  PAT       '!PAT' eye-catcher
+$04  PATFHDR   ADDRESS OF 1ST ENTRY IN FREE LIST
+$08  PATHDR    address of 1st entry in list
+$0C  PATTSIZ   size of Periodic Activation table in bytes
      PATNEXT   pointer to next entry   4        PATOPT   options          2
      PATTCB    TCB to be activated     4        PATARID  request ID       4
      PATDELTA  time since previous     4        PATCNT   activation count 2
      PATINTV   activation interval     4        PATILVL  interrupt level  2
      PATASR    ASR address             4
```

`4+4+4+4+4+2+4+2+2 = 30 = $1E` — **exactly the stride measured** for the free list at
`$1F700`, and `PATFHDR` at `+$04` is exactly the "first-record pointer, a third header
shape" this document recorded. So:

- **`!PAT` = Periodic Activation Table**
- entries chained through `PATNEXT` at each entry's `+$00` ✓ as measured
- the `$FFFFFFFF` this document noted at each entry's `+$04` is **`PATTCB`** — "no task",
  i.e. the free marker ✓
- and it is empty because the firmware never issues `RQSTPA` (29) or `T0RQPA` (34).
  A wholly free Periodic Activation Table in a system that requests no periodic
  activations is not a mystery, which is how this document had been treating it.

#### The directive-`$01` block is a Segment Parameter Block

`SEG.EQ` defines `SGPB`, and RDHC's block at `$F046B0` lays over it exactly:

| offset | field | value |
|---|---|---|
| `+$00` | `SGPBTASK` target task name | `'RDHC'` |
| `+$04` | `SGPBSESS` session code | 0 |
| `+$08` | `SGPBOPT` directive options | **`$2000`** |
| `+$0A` | `SGPBATTR` segment attributes | 0 |
| `+$0C` | `SGPBNAME` **segment name** | `'STCK'` |
| `+$10` | `SGPBLA` logical address | 0 |
| `+$14` | `SGPBSL` **segment length in bytes** | **`$190`** = 400 |

So the thing this document calls "the directive `$01` parameter block: name, STCK tag,
`$190` stack" is a **request to allocate a segment named `STCK` of 400 bytes**. `STCK`
was never a tag — it is `SGPBNAME`, a *segment name*, which is why it looks like the
`!xxx` markers and is not one.

**`SGPBOPT = $2000` is bit 13 = `SGPBOPAD`, "EXEC SUPPLIES LOGICAL ADDRESS (= PHYS
ADDR)".** That is exactly right for a machine with no address translation, and it
explains why `SGPBLA` is zero: the caller declines to name an address and the exec
returns a physical one.

#### The whole allocation chain, now end to end in Motorola's own terms

```
GTSEG ($01)  with SGPBNAME='STCK', SGPBSL=$190, SGPBOPT=SGPBOPAD
   -> T0PAGAL ($04) "ALLOCATE PHYSICAL PAGES", rounding 400 up to 2 pages of 256
   -> a $200-byte segment, which is the per-task stride measured here
   -> its address lands in TCBA6 (+$138), semaphore descriptors at the base,
      stack growing down from the top
```

Every step of that was derived here from arithmetic and RAM dumps before any of the
names were known, and the names confirm each one. *The 400-to-512 rounding in
particular was inferred from `$190` becoming `$200`; `T0PAGAL` and `SGPBSL` together say
why in so many words.*

### The TCB layout from Motorola's source, and `TCBASQ = 0` clinches the semaphores

`~/src/claude/versados/SR10/U9995/TCB.EQ` names every offset this project has been
using positionally:

| offset | field | project's empirical name | verdict |
|---|---|---|---|
| `+$00` | `TCB` | `'!TCB'` eye-catcher | ✓ |
| `+$10` | **`TCBNAME`** | "task name at `+$10`" | **✓** |
| `+$36` | **`TCBTST`** | — | pointer to the Task Segment Table |
| `+$40` | **`TCBASQ`** | — | pointer to the ASQ |
| `+$6C` | **`TCBENTRY`** | "entry point at `+$6C`" | **✓** |
| `+$72` | **`TCBSSP`** — *exec stack depth* | "the PB length at `TCB+$72`" | **✗ corrected** |
| `+$138` | **`TCBA6`** — *user's saved A6* | "the ASQ/stack block pointer" | **✗ corrected** |
| `+$13C` | **`TCBUSP`** — *user's A7* | "saved stack pointer" | **✓** |
| `+$160` | start of the trailing pad | where `!TST` sits | see below |

Read against live RAM, three of these settle open questions:

```
task   TCBTST(+$36)   TCBASQ(+$40)   TCBENTRY(+$6C)   TCBA6(+$138)   TCBUSP(+$13C)
XP1I     $01EA60        $000000        $F07D4A          $1E700         $1E814
RDHC     $01F460        $000000        $F046F0          $1DD00         $1DE16
```

**`TCBASQ` is `$00000000` for all six tasks.** That is independent, decisive
confirmation of the semaphore correction: a task with no ASQ cannot have ASQ names, so
`AXP1`-`AXP4`/`HXP1`-`HXP4`/`HIO1` are semaphore names and nothing else. The evidence is
now threefold — the directive numbers (`CRSEM` counts 2/2/2/2/1/0), the marker expansion
(`!UST` = User Semaphore Table), and the null `TCBASQ`.

**`TCBTST` points at exactly `TCB+$160`** — `$1E900 + $160 = $1EA60` for XP1I, and so on
for all six. So the `!TST` marker this project found at `+$160` is not in an arbitrary
spot: the **Task Segment Table is embedded in the TCB's own trailing pad**, and RMS68K's
defined pointer confirms it. `TCB.EQ` ends with `DS.B $200-$20-*` starting at `$160`,
which is why the TCB stride is `$200`.

**`+$138` is not a structure field at all** — it is `TCBA6`, the task's saved A6. The
semaphore-descriptor block is simply *where A6 happened to point when the task blocked*,
which is exactly the a6-as-structure-pointer idiom established from the 150-positive /
0-negative displacement count. And `+$13C` = `TCBUSP` = user A7 sits in the same `$200`
segment, so **one segment serves as both semaphore-descriptor area (at its base) and
stack (growing down from its top)** — reconciling two names this document had been using
for the same block.

**And `+$72` is `TCBSSP`, "exec stack depth"** — not a parameter-block length. So the
copier at `$F00756` is pushing the parameter block onto the **exec stack** and recording
its depth, which makes better sense of the 80-byte cap than "a PB save area" did. That
corrects the reading published one commit ago, on the same day.

### `$4C` is in no available RMS68K release, and the "80" is a parameter-block limit

Two results on directive `$4C` = 76, one exhaustive negative and one self-caught
misreading.

**The negative is now complete.** The 44 MB VERSAdos tree contains exactly **one**
`TR1.EQ` (SR10/U9995), its table ends at 75 (`FLUSHC`), and a grep for `EQU 76` across
every `.EQ` and `.SA` file in all 25+ release trees returns **nothing**. `CISR`
("connect to interrupt service routine") is 61 = `$3D`, so `$4C` is not that either. So
`$4C` — traced here directly as the connect-interrupt-vector directive, implemented at
`$F0226A` and the writer of the `!VCT` ownership byte — is **either a later RMS68K
revision than anything in this tree, or an FPS addition**. The evidence leans to a later
revision: the FPS-insertion sweep found only four pointers and two calls into the
kernel, no sign of a wholesale patch, and `$F0226A` reads as ordinary kernel code.

**The misreading, caught before publishing.** Searching the kernel for a bound that
might date the build turned up one candidate, `cmpi.l #$50,d0` at `$F00760` — a maximum
of 80 where SR10 stops at 75, which looked like a later revision with five directives
added. Decoding the surrounding code kills that reading:

```
$F00756  move.l  $0C08.w,d0
$F0075A  lea     $10(a7),a5
$F0075E  sub.l   a5,d0          ; d0 = a LENGTH, not a directive number
$F00760  cmpi.l  #$50,d0
$F00766  ble     +4
$F00768  bsr.w   $F00186        ;   too long -> error
$F0076E  andi.l  #$ff,d7
$F00778  move.b  d7,$72(a6)     ; store the length in the TCB
$F0077C  move.w  (a5)+,(a4)+    ; copy loop
$F0077E  subq.w  #$2,d0 / bgt
```

It is the **TRAP #1 parameter-block copier**: the length is computed from a saved
pointer at `$0C08`, bounded at **80 bytes**, stored at `TCB+$72`, and the block is copied
word-by-word into the TCB. Nothing to do with directive numbering.

*Which is still worth having.* It names the mechanism by which the `a0`-pointed
parameter block reaches the kernel — **copied into a save area in the TCB, maximum 80
bytes, length byte at `TCB+$72`** — and that bound is a hard constraint on any parameter
block this firmware builds. The largest one seen so far is the 10-byte semaphore
descriptor, so nothing is close to the limit.

*Two of my last three attempts to date this RMS68K build have been wrong in the same
way: finding a numeric bound and assuming it counts the thing I was looking for. A
bound only means what the surrounding arithmetic says it means.*

### RESOLVED: every RMS68K directive named — and the "ASQ" naming was wrong

*From `~/src/claude/versados/SR10/U9995/TR1.EQ` and `STR.EQ`, at the user's
suggestion.* This document records that the firmware uses 14 distinct TRAP #1
directives and that **"None could be matched to Motorola's published directive
names."** They are all in the VERSAdos source tree, and the reason they never matched
is that **the source numbers them in decimal** while the firmware loads hex immediates.

**TRAP #1** — 13 of 14 named:

| firmware | dec | name | meaning | agrees with |
|---|---|---|---|---|
| `$01` | 1 | `GTSEG` | allocate segment | "task+stack setup" — it is the stack *segment* |
| `$0B` | 11 | `CRTCB` | create TCB | RDHC-only ✓ |
| `$0D` | 13 | `START` | start task | RDHC-only ✓, pairs with `CRTCB` |
| `$0F` | 15 | `TERM` | terminate task (self) | one site per task — the exit path |
| `$10` | 16 | `TERMT` | terminate task (not self) | |
| `$11` | 17 | `SUSPND` | suspend task (self) | |
| `$12` | 18 | `RESUME` | resume suspended task | **"RDHC issues `$12` five times, XP4I…XP1I then USER"** — it *resumes the other five tasks* ✓✓ |
| `$13` | 19 | `WAIT` | task becomes blocked | recorded as "the blocking wait" ✓✓ |
| `$29` | 41 | `ATSEM` | **attach to semaphore** | |
| `$2A` | 42 | `WTSEM` | **wait on semaphore** | |
| `$2B` | 43 | `SGSEM` | **signal semaphore** | |
| `$2D` | 45 | `CRSEM` | **create semaphore** | |
| `$43` | 67 | `RSTATE` | receive task state | used with the literal `'USER'` ✓✓ |
| `$4C` | 76 | — | **beyond this table**, which ends at 75 | traced as "connect interrupt vector"; `CISR` is 61 = `$3D`, so `$4C` is a later or vendor addition |

**TRAP #0** — all five named:

| firmware | dec | name | meaning |
|---|---|---|---|
| `$04` | 4 | `T0PAGAL` | **ALLOCATE PHYSICAL PAGES** |
| `$06` | 6 | `T0GETTCB` | search TCB list |
| `$16` | 22 | `T0WAKEUP` | wakeup task from exec mode |
| `$18` | 24 | `T0QEVNTI` | place event in ASQ, caller is an interrupt routine |
| `$1F` | 31 | `T0CRTCB` | create task control block |

**`$04` = "ALLOCATE PHYSICAL PAGES"** is an exact confirmation of a result derived here
independently from the arithmetic `end = base + (size<<8) - 1`. The name and the
inference agree without either informing the other.

#### Correction: `AXP1`/`HXP1` are semaphores, not ASQs

`$29`/`$2A` were identified in this document as "look up an ASQ by name" and "post to
that handle". They are **`ATSEM`** and **`WTSEM`** — attach to a semaphore by name, then
wait on it. And the counts settle it beyond doubt: `$2D` = **`CRSEM`**, *create
semaphore*, appears **twice per XP task, once in TCBIO1I, never in RDHC** — exactly the
2/2/2/2/1/0 pattern this document attributes to "ASQ declarations". `$2B` = `SGSEM` is
the signal.

So **every use of "ASQ" for `AXP1`-`AXP4`/`HXP1`-`HXP4`/`HIO1` in this project is
wrong**: those are semaphore names, the 10-byte records at `TCB+$138` are semaphore
descriptors, and the nine entries in `!UST` are a semaphore registry.

Which names the marker: **`T0FNDSEM` = "FIND ENTRY IN USER SEMAPHORE TABLE"**, so

| marker | expansion | source |
|---|---|---|
| `!UST` | **User Semaphore Table** | `T0FNDSEM` |
| `!GST` | **Global Segment Table** | `T0FNDGSG` "find segment name in GST" |
| `!TST` | **Task Segment Table** | `T0FNDSEG` "find segment name in TST" |

Three markers this document lists only as four-letter tags now have expansions from
Motorola's own source. *And the real ASQ directives — `GTASQ` 31, `RDEVNT` 34, `QEVNT`
35, `WTEVNT` 36 — appear **nowhere** in this firmware's TRAP #1 set. The FPS application
is built on semaphores and uses ASQs only from interrupt context via TRAP #0 `$18`,
which is why `!ASQ` has kernel code and no tagged instance.*

### The FPS↔RMS68K interface is four pointers and two calls — and `$1F500` is a ring queue

The "missing 27%" of the ROM is not undecoded: `$F04488 - $F00000` is **exactly 17,544
bytes**, so it is precisely the RMS68K kernel region that `fps3k.asm` deliberately
excludes. The question worth asking instead is how much of that kernel FPS modified.

**Scanning for FPS pointers, opcode-agnostically** — every longword in `$F00000-$F04487`
whose *value* lands in the application region — finds exactly four:

| site | value | what |
|---|---|---|
| `$F00004` | `$F09C00` | the **reset vector's PC** |
| `$F001A6` | `$F04500` | the panic stub's `jsr` target, followed by `bra .` |
| `$F03FDA` | `$F044A2` | `move.l #$F044A2,$4C(a1)` — **installs** the driver-chain hook |
| `$F040EA` | `$F044A2` | `move.l #$F044A2,$4C(a4)` — same, different base |

And in the other direction, only **two** kernel entry points are called from the FPS
region: `$F008B6` and `$F01688`. So the whole coupling is **four pointers out, two calls
in, and TRAP #0/#1 for everything else** — which justifies treating the kernel as
generic and is why excluding it from the annotated asm costs nothing.

*A first version of this sweep reported eight fingerprints including two references to
`$FF0100`, the 256-byte gap this project lists as unaccounted. All six of the extra hits
were false positives: every one is a `$FF` immediate followed by a displacement —
`cmpi.b #$FF,$18(a1)`, `movem.l …,$100(a6)` — which a longword-value test reads as
`$00FFxxxx`. The `$FF0100` gap remains unaccounted.*

#### Reset SSP is zero, and `MainInit` is the first thing to fix it

```
vector 0:  SSP = $00000000
vector 1:  PC  = $00F09C00
$F09C00    jmp MainInit.l        -> $F08700
$F08700    lea $1FFD0,a7         <- the supervisor stack pointer
```

**The reset stack pointer is `$00000000`**, so nothing may push before `MainInit` runs —
and its first instruction is the `lea` that fixes it. Worth knowing for any patched ROM:
a `--reset` image that jumps elsewhere inherits a zero SSP, which is the same class of
fault as the missing vector table that produced the first monitor burn's double fault.

*This also corrects a reading from the template-diff work: `4FF9 0001FFD0` at offset
`+$8EE` of XP1I's block was dismissed there as "region tail". It is `lea $1FFD0,a7`, the
first instruction of `MainInit` — the diff window had simply run past XP1I's region.*

#### `$F01688` identifies the last unidentified RTOS structure

```
$F01688  movem.l d0-d1/a3-a5,-(a7)
$F0168C  move    sr,-(a7)
$F0168E  movea.l $0C30.w,a3        ; the directory slot for $1F500
$F01692  ori     #$700,sr          ; MASK ALL INTERRUPTS
$F01696  movea.l (a3),a5           ; a5 = first  ($1F508)
$F01698  cmpa.l  $4(a3),a5         ; compare against last ($1F5F2)
$F0169E  lea     $8(a3),a5         ;   equal -> wrap to the base
$F016A2  lea     $1A(a5),a4        ; step one record
$F016A6  move.l  a4,(a3)           ; publish the new first
$F016A8  move    (a7)+,sr          ; unmask
$F016AA  move.l  d0,$10(a5)        ; fill the record
$F016AE  move.l  a0,$8(a5)
$F016B2  move.l  a6,$C(a5)
```

**That is a circular-queue enqueue.** So the untagged structure at `$1F500` — 9 records
of `$1A` bytes behind a `first`/`last` header, which this document could only describe as
"`!CCB` or `!DLY`, untouched in every configuration reached" — is a **9-entry ring buffer
of `$1A`-byte records**, enqueued with interrupts masked, fields written at `+$8`, `+$C`
and `+$10`. It is reached only from the FPS driver-chain hook at `$F044AC`, and only when
bit 14 of `$0C34` is set, which is why no configuration has ever touched it.

*A masked-interrupt ring buffer filled by a driver hook is the shape of a trace or
deferred-event log. That is inference, not established — but the structure itself now is:
all eight allocated RTOS structures have a decoded layout and a known writer.*

### Alternating wake/`$14` works, but buys 2 wakes not many — and op `$7` self-destructs

Acting on the prediction: `FPS3K_RESPSEQ=<code>,<code>,…` cycles a **sequence** of
response codes across successive BIM0-ch0 raises, which `FPS3K_RESP` cannot express.

| configuration | RDHC | wakes | cmd 1 | `$F0572C` |
|---|---|---|---|---|
| `RESP=$94` constant | 19.4% | **1** | 1 | 2 |
| `RESPSEQ=0B,94` | 22.0% | **2** | 1 | 2 |
| `RESPSEQ=0B,94,0B,14` | **23.3%** | 2 | 1 | 2 |
| `RESPSEQ=07,94` | **4.5%** | 1 | 0 | 0 |

**The prediction was directionally right and quantitatively wrong.** Alternating a
non-`$14` code with `$14` does produce another wake — 1 → 2 — and RDHC gains four
points, 19.4% → 23.3%. But two wakes, not many: `$0B` alone produces **1467** wakes,
yet interleaved with `$94` it produces two. So the `$14`-absorption mechanism was real
and is not the whole limit; something further along stops RDHC being wakeable after the
second time. *Recording the shortfall rather than the headline: a +4-point gain on a
hypothesis that predicted an order of magnitude more is weak confirmation at best.*

#### Op `$7` in a response sequence destroys the sequence

`RESPSEQ=07,94` collapses to **4.5%** — worse than doing nothing — and reaches neither
command 1 nor `$F0572C`. That is exactly right and self-consistent: **operation `$7` is
the BIM mask** (`$F04F3A`: read `$FF0230`, `bclr #4` — the IRE bit — write back). Using
it in a sequence disarms BIM0 ch0, which is the interrupt *delivering* the sequence, so
the second code never arrives.

An operation that switches off the channel it was delivered on is a nice independent
confirmation of what op `$7` does — the functional decode said "mask BIM0 ch0 (clear
IRE)", and the observable consequence of scheduling it is precisely that everything
afterwards goes silent. *It also makes op `$7` a hazard worth flagging for anyone
scripting chassis conversations: it is the one operation that cannot appear anywhere
except last.*

### Why only one RDHC command executes per boot: `$14` means two different things

With the descriptor layout known, a fully-populated command record was worth trying:
`{1, operation, channel, count, payload, param, buffer…}` at `$400000`. It gains
**nothing** — 19% of RDHC either way, identical to the minimal `1,14,1` probe, because
operation `$14` takes its buffer from a fixed ROM address (`$F0549E`) rather than the
inline one, and `$F0544A` computes the inline pointer regardless.

The real ceiling is that **RDHC wakes exactly once**: `$F0473C` (the `$13` wait) and
`$F04740` (the instruction after it) each execute once, whatever the descriptor. Tracing
where RDHC goes afterwards finds the reason, and it is four instructions in the ISR:

```
$F04976  cmpi.w  #$14,d0
$F0497A  beq.w   ChannelConfigDispatch      ; = $F050F8, the ISR EXIT STUB
```

**So `$14` has two different meanings depending on who reads it.** To RDHC's main loop
at `$F048D8`, `$E86 & $1F == $14` means *"a command record is waiting"*. To the ISR's
bit-7 dispatcher at `$F04976`, `d0 == $14` means *"acknowledge and return"* — straight
to `$F050F8`, `movem` / `move #$C,ccr` / `trap #1`, waking nobody.

And the ISR runs first. So the second and every subsequent `$14` notification is
absorbed by `$F0497A` and returns from interrupt; RDHC only ever saw the first one
because it was already past its wait at that moment. The last RDHC instruction in a
full trace is `$F05100` — the `trap #1` of that exit stub — reached via `$F04930` →
`$F0495C` → `$F04976` → `$F0497A`.

*This is a firmware property, not a modelling gap, and it changes what a host driver
has to do.* A stream of commands cannot be issued as a stream of `$14`s. Each command
needs RDHC re-woken by something that is **not** `$14` — the wake path is the `$13`
wait — and only then does a `$14` reach the command arm. The correct host sequence is
therefore alternating: *wake, `$14`, wake, `$14`…*, and the single-code
`FPS3K_RESP` hook cannot express it because it presents one constant value forever.

That is the concrete next step for driving RDHC past 47%: a response *sequence* that
alternates a waking code with `$14`, delivered through the BIM path rather than the
scripted-panel path. It is also a falsifiable prediction about the real machine — a bus
trace of a working FPS-3000 issuing several commands should show a non-`$14` code
between each pair of `$14`s.

### Two more phase specifications, and the set is now read end to end

**`$15xx` is a CHANNEL_SELECT read-back test.** Six phases, one PC, and the beacon
*is* the test:

```
$F094F2  cmpi.b  #$5,d6 / bgt -> done      ; d6 = 0..5, six iterations
$F094FA  move.w  d6,$204(a6)               ; write the counter
$F094FE  cmp.w   $204(a6),d6               ; READ IT BACK, must match
$F09504  move.l  #$f0f0f0f0,d7             ; else error
```

So the six "phases" `$1500`-`$1505` are the **six values being written**, and
`$FF0204` is specified as a plain read/write register holding 0-5. This is the only
group where the beacon write and the test are the same instruction — and it explains a
figure from the access log: `$FF0204` shows **7 reads** against 32,967 writes, six of
which are this test's read-backs. The register that carries every phase beacon is
itself validated exactly once, by six writes and six reads.

**`$23xx` is a DRAM data-retention test**, and it is the only phase that measures time:

```
$F09A8A  move.l  #$09abcdef,d0        ; a distinctive pattern
$F09A92  move.l  d0,(a0)+             ; fill
$F09A94  cmpa.l  #$1fff0,a0 / bne
$F09A9C  lea     $4(a0),a0            ;   STEP OVER $1FFF0-$1FFF3
$F09AA4  move.l  #$493e0,d5           ; 300,000
$F09AAA  subq.l  #$1,d5 / bne         ;   busy-wait
$F09AAE  cmp.l   (a2)+,d0             ; then verify every longword
$F09ABC  cmpa.l  #$1fff0,a2 / lea $4(a2),a2   ;   stepping over it again
```

Fill, wait ~300,000 iterations, verify — that is a **refresh test**: it checks DRAM
holds its contents across a delay rather than just accepting a write. And it **skips
`$1FFF0`-`$1FFF3` in both the fill and the verify**, which is the firmware stating
that those four bytes are a device and not memory — corroborating the VMOD control
register's width from the other direction, since the access log shows `$1FFF0` touched
at 1, 2 and 4 bytes and `$1FFF1` at byte width only.

#### The self-test read as a specification: what it establishes

| group | what it specifies |
|---|---|
| `$01xx` | 68000 register integrity, `moveq` sign-extension, all registers incl. USP |
| `$15xx` | `$FF0204` is a plain read/write register (values 0-5 round-trip) |
| `$16xx` | `$FF0210`-`$FF0216` are four writable registers (walking ones); `MODE0` checked masked `$FF`, `STATUS_IRQ` masked `$610` |
| `$17xx` | `$FF0216` **bit 5** = chassis-memory bus-error enable, both polarities |
| `$18xx` | `$FF0216` **bit 6** is **transparent**, all four read/write × set/clear cases |
| `$19xx` | `$FF0216` **bit 4** = 16-bit-access enable; longwords always round-trip |
| `$1Axx` | `$FF0216` **bit 7** = AP I/F bus-error enable; `$FF000E` is plain storage |
| `$23xx` | DRAM retention across a 300,000-iteration delay; `$1FFF0`-`$1FFF3` is not memory |
| `$29xx` | chassis memory over `$400000`-`$403FFF`, stride 4, four patterns |

*Read this way the self-test is the closest thing to a hardware manual this project
has.* It states positive behaviour, negative behaviour, and per-bit masks, with the
`$F0F0F0F0` marker as the assertion — and three of the emulator's rules have now been
either confirmed or corrected against it (`$400000` BERR gate confirmed; AP I/F gate
narrowed to bit 7; the word-access rule re-derived as bit 4 *and* bit 5 clear).

### `$E58` is a longword INDEX, and the window's size is still not pinned

Reconciling the 16 KB self-test extent with op `$3`'s `page = addr >> 20`. Reading the
bounds check properly settles the arithmetic:

```
$F04D72  lsr.l   #$14,d1         ; page  = index >> 20        -> MODE2
$F04D7E  andi.l  #$fffff,d1      ; offset = index & $FFFFF     (in LONGWORDS)
$F04D84  lsl.l   #$2,d1          ;        -> byte offset, max $3FFFFC
$F04D86  exg.l   d1,a1
$F04D88  cmpa.l  #$400000,a1
$F04D8E  bge     -> $F04DA0      ; offset >= 4 MB: read (a1) as an ABSOLUTE address
$F04D96  move.l  (a1,d1.l),$e70  ; else read $400000 + offset
```

**`$E58` holds a longword index, not a byte address.** Bits 0-19 index within a page,
bits 20 and up are the page number written to MODE2, and the offset is scaled by 4 to
become a byte displacement. That is why `page = addr >> 20` looked incompatible with a
16 KB extent: a page is 1M **longwords**, and the self-test's 16 KB is the first 4,096
longwords of page 0 — not a page.

#### An over-read, caught before publishing

The natural next step was "so the window spans `$400000`-`$7FFFFC`, 4 MB, and the
emulator's 1 MB is wrong by 4×". I enlarged it, and all three golden digests still
matched. Then a range check for accesses above 1 MB returned hits at **`$70001C` — the
mailbox**, which sits *inside* `$400000 + 4 MB`.

So the inference was wrong. **`cmpa.l #$400000` bounds the computed offset; it does not
assert that the hardware answers across that whole range.** A 4 MB window would
swallow the mailbox, which puts a hard ceiling of **under 3 MB** on the extent — and
nothing in the firmware pins it below that, because phase `$29xx` only ever walks
16 KB. Reverted to 1 MB, now with a comment saying it is an unforced choice rather than
a derived one.

*The digests matching is what makes this instructive: the change was invisible to every
existing guard, so "all tests pass" would have shipped a wrong 4× window size. What
caught it was a range check written for a different purpose returning an address I
recognised. The guards protect against regressions, not against plausible
over-readings.*

What is now established, and what is not:

| | |
|---|---|
| the address arithmetic | **known exactly** — longword index, page in MODE2, offset ×4 |
| offsets are windowed up to | **4 MB** (beyond that, treated as an absolute address) |
| the window's actual extent | **unknown**, ≤ 3 MB by the mailbox collision; the self-test only ever needs 16 KB |
| page size in bytes | 4 MB of window address space per page — *if* the window is that wide, which is not established |

### The chassis-memory test covers 16 KB, not "131k addresses"

Phase `$29xx` is a march test with the extent written into the code:

```
$F09B30  lea     $400000,a2         ; start
$F09B36  lea     $404000,a1         ; end  -> 16 KB
$F09B3C  lea     $F09BB6,a3         ; pattern table
$F09B42  move.l  (a3)+,d0 / move.l (a3)+,d1
$F09B48  move.l  d0,(a0) / lea (a0,d2.w),a0 / cmpa.l a1,a0 / bne     ; fill
$F09B58  cmp.l   (a0),d0            ; verify pattern 1
$F09B70  move.l  d1,(a0) / cmp.l (a0),d1                             ; overwrite, verify
$F09B84  lea     (a0,d2.w),a0       ; stride in d2
```

Measured against the width-aware access log:

| quantity | value |
|---|---|
| distinct addresses touched | **4,098** |
| range | `$400000`-`$404000` — **16 KB** |
| accesses at true width | **65,581**, of which 65,570 are **32-bit** |
| reads / writes | 32,789 / 32,792 — balanced write-then-verify |
| stride | **4** (longword; the eleven stride-2 gaps are phase `$19xx`'s word probes) |
| patterns at `$F09BB6` | `$00000000`, `$FFFFFFFF`, `$55555555`, `$AAAAAAAA` |

**Two corrections to a recorded figure.** This document says phase `$29` "walks 131k
chassis addresses". It walks **4,098** addresses. And `131,148` was never an address
count — it was the **byte-decomposed** access count from the old bus log; at true CPU
width the figure is **65,581 accesses**. A number produced by the decomposing logger
was written down as a property of the firmware, and it was wrong by 32× as an address
count and by 2× as an access count.

*That is the third recorded fact traceable to the decomposed log — after the phantom
register at `$FF0212` and the "hottest register" claim. The lesson is narrow and
worth stating plainly: any count taken from a log that splits wide accesses is a
count of bus cycles in the model, not of anything in the machine.*

**And the extent is a hardware expectation worth having.** The firmware validates
exactly 16 KB of the chassis window — not the 1 MB the emulator allocates, whose
comment says "the test only touches the first few words". It touches 16 KB, three
orders of magnitude more than that, and the allocation is right for a reason the
comment gets wrong. Whether 16 KB is the window's page size or merely as much as the
self-test bothers with is not settled here; op `$3`'s `page = addr >> 20` arithmetic
implies 1 MB pages, which does not match, so the two facts are not yet reconciled.

### Phase `$19xx`: bit 4 is the 16-bit-access enable — and why `data_hi == 0` worked

The chassis-memory data-path group specifies **bit 4** (`$10`) of `$FF0216`, in four
cases, using two comparators:

```
$F09806  move.l  d0,(a0)          ; write $55555555 at $400000
$F09808  move.w  d1,(a0)          ;   then a WORD $AAAA over its high half
$F0980A  cmp.l   (a0),d2          ; read the longword back

$F0981A  move.l  d0,(a0)
$F0981C  move.w  d1,$214(a6)      ;   write $AAAA to XLTR_DATA_LO
$F09820  cmp.w   $2(a0),d2        ; read the WORD at $400002
```

| phase | `$FF0216` | expected | meaning |
|---|---|---|---|
| `$1901` | `$10` | `$AAAA5555` | word write **takes effect** |
| `$1902` | `$00` | `$55555555` | word write **ignored** |
| `$1903` | `$10` | `$5555` | word read gives **chassis memory** |
| `$1904` | `$00` | `$AAAA` | word read gives **`$FF0214`** |

So **bit 4 is a 16-bit-access enable**: with it clear the window is longword-only,
word writes are dropped and word reads are shadowed by the XLTR data register. Phase
`$1900` separately establishes that a **full longword round-trips** with `$216`
untouched.

That completes `$FF0216` as a control register: **bit 4** 16-bit-access enable,
**bit 5** chassis-memory BERR enable, **bit 6** transparent, **bit 7** AP I/F BERR
enable. Its resting value `$C0` therefore means: longword-only chassis access, chassis
memory readable, AP I/F armed to fault. Every bit accounted for by a test.

#### The correction, and why the original condition was right by accident

The emulator keyed both behaviours on `versabus_xltr_data_hi() == 0`. Changing that to
bit 4 — which is what the phase text says — **broke the boot**: phase `$29xx` was never
reached and all three golden digests collapsed to a single value, the signature of an
early hang.

The width-aware access log shows why. Word accesses to the window happen with `$216`
= `$00`, `$10`, `$20` **and `$40`** — and the `$20` case is phase `$17xx`'s `clr.w
(a1)` **write probe, which must fault**. Bit 4 is clear in `$20`, so keying on bit 4
alone made the word-write rule **swallow the write before it could reach the bus-error
gate**. Phase `$17xx` then failed and took the boot with it.

**`data_hi == 0` was not a sloppy approximation of bit 4 — it was the condition that
kept one rule from shadowing the other.** The real fault is structural: in hardware the
bus-error gate and the 16-bit-access mux are independent mechanisms, and in this model
they are *sequential*, with the early return in the 16-bit path bypassing the BERR
check entirely.

The condition that satisfies both specifications is **bit 4 clear *and* bit 5 clear**:

```c
if (a == 0x400002 && !(versabus_xltr_data_hi() & 0x30)) ...   /* read shadow  */
if (a == 0x400000 && !(versabus_xltr_data_hi() & 0x30)) ...   /* write ignore */
```

With `$10` the word access goes through; with `$00` it is dropped or shadowed; with
`$20` or `$40` it falls through to the BERR path. All three golden digests match and
the self-test reaches phase `$29xx`.

*Note what changed and what did not.* At the resting value `$C0` the old condition let
word accesses through and the new one drops them, so the model's behaviour **is**
different — yet the digests are byte-identical, which means nothing in the golden
configurations does a word access to that window outside the self-test. So this is a
fidelity improvement with no observable effect today, and it will matter the first time
a chassis conversation moves data by word. *A change that is provably more correct and
provably invisible is worth recording as exactly that, rather than as a fix for a
symptom.*

### Phase `$18xx` is a *negative* specification: bit 6 is transparent

The remaining chassis-memory group tests **bit 6** (`$40`) of `$FF0216`, and every one
of its four phases requires **no fault**:

| phase | `$FF0216` | probe | required |
|---|---|---|---|
| `$1800` | `$40` (bit 6 set) | read `$F096AC` | `d1 == 0` — no fault |
| `$1801` | `$00` | read | `d1 == 0` |
| `$1802` | `$40` | **write** `$F096B8` | `d1 == 0` |
| `$1803` | `$00` | write | `d1 == 0` |

**Bit 6 does not gate bus errors at all**, and the firmware proves it across the full
2 × 2 of read/write × set/clear. That is worth having as a positive statement rather
than an absence: the self-test does not merely exercise the bits that *do* something,
it verifies that bit 6 is **transparent** to `$400000` access. A chassis model that
made bit 6 do anything to that window would fail phase `$18xx`.

So the three probe-tested bits of `$FF0216` now have roles:

| bit | role | established by |
|---|---|---|
| 5 | **chassis-memory (`$400000`) bus-error enable** | phase `$17xx`, both polarities |
| 6 | **transparent** to `$400000`, read and write | phase `$18xx`, all four combinations |
| 7 | **AP I/F bus-error enable** | phase `$1Axx`, both polarities |

This tightens what this document could previously say — that `$10/$20/$40/$80` "are
set-then-test probe pairs in the boot diagnostics only". They are not
interchangeable probe values; three of them name distinct behaviours and one of those
behaviours is *no behaviour*, deliberately checked.

**And it makes the resting value meaningful.** `$FF0216` settles at **`$C0`** =
bits 6 + 7. Bit 6 is transparent, so the operationally significant half is **bit 7 set
— the AP I/F fault enable is live in normal service.** That is exactly the condition
the emulator's narrowed gate now tests (`arm_pending && (data_hi & 0x80)`), so the
resting value and the gate agree: in service the AP I/F is armed to fault while the
chassis holds the bus, and bit 5 stays clear so chassis memory remains readable.

*Note the shape of these three groups taken together: `$17xx` asserts a bit does
something in both directions, `$18xx` asserts a bit does nothing in four
combinations, `$1Axx` asserts the third bit does something and that the port behind
it is plain storage. That is a register specification written as tests — and it is a
better source for a chassis model than any amount of usage-pattern inference, because
it states the negative cases too.*

### `$FF0216` carries two BERR-enable bits, and the AP I/F gate was too loose

Phase `$1Axx` is the only group that touches the AP I/F, and it is that card's
specification — the same three-part shape as the `$400000` test:

```
$F0984C  move.w #$80,$216(a6)   ; bit 7 SET   -> the probe MUST fault   (phase $1A00)
$F0987C  move.w #$aaaa,$e(a6)   ; with $218 CLEARED, $FF000E must
$F09882  cmpi.w #$aaaa,$e(a6)   ;   read back what was written          (phase $1A01)
$F098A0  clr.w  $216(a6)        ; bit 7 CLEAR -> it MUST NOT fault      (phase $1A02)
```

So **`$FF0216` holds two independent bus-error enables**: **bit 5** for the `$400000`
chassis-memory window (phase `$17xx`) and **bit 7** for the AP I/F (phase `$1Axx`).
That is a sharper statement of that register's role than "mode/page register,
read-modify-written" — it is at least partly a **bus-error enable register**, and the
firmware tests each bit in both polarities.

Phase `$1A01` also establishes that **`$FF000E` is a genuine read/write 16-bit
latch**: with the fault enable *set* but `STATUS_IRQ` cleared, `$AAAA` written there
must read back. So the AP I/F fault is conditional on more than bit 7 alone, and the
command port itself is plain storage. The probe at `$F098C4` opens with
`move.w #$FF,$20C(a6)` — one of the `$01`/`$FF` COUNTER values this document records
as "boot-diagnostic only", now with a purpose: it is part of arming the probe.

#### The emulator's AP I/F gate conflated the two bits

```c
/* before */ return xltr.arm_pending && xltr.data_hi != 0;
/* after  */ return xltr.arm_pending && (xltr.data_hi & 0x80);
```

Gating on `!= 0` meant a write of `$20` — intended only to arm the *chassis-memory*
gate, which the `$400000` path reads as `data_hi & 0x20` — would **also** arm the AP
I/F gate. The two enables live in one register and the model merged them. Narrowed to
bit 7, per the firmware's own test.

Verified rather than assumed, because a change like this can easily break a working
configuration:

| check | result |
|---|---|
| self-test completes, reaches phase `$29xx` | **yes**, both configurations |
| RDHC wakes, command arm taken, cmd 1 runs, `$F0572C` fires | **unchanged** (1/1/1/2) |
| all three golden-master digests | **byte-identical** |

*One process note. At 200 M cycles the RDHC-driven run's final PC moved from `F00FCC`
to `F056B8` and its RAM md5 changed, which read as a regression — `F056B8` is a
`bra .`. It is not: that is where RDHC's ISR legitimately sits between interrupts, and
the digests are taken at 400 M, where all three are unchanged. I nearly updated the
golden masters on the strength of a hash that is not what they measure. The tripwire
worked; my first reading of it did not.*

### Phases `$1700`-`$1703` specify the `$400000` BERR gate — and explain the NOPs

The first chassis-memory phase group is a **bus-error gating test**, and it is the
firmware's own specification of a rule the emulator already implements:

```
$F0961A  clr.w   $210(a6)          ; MODE2 = page 0
$F0961E  movea.l #$400000,a1
$F09626  move.w  #$20,$216(a6)     ; $FF0216 bit 5 SET
$F0962C  bsr     $F096AC           ;   probe
$F0962E  tst.w   d1 / bne -> ok    ;   d1 must be NONZERO (a fault was taken)
$F09632  move.l  #$f0f0f0f0,d7     ;   else error marker

$F09648  clr.w   $216(a6)          ; $FF0216 bit 5 CLEAR
$F0964C  bsr     $F096AC
$F0964E  tst.l   d1 / beq -> ok    ;   d1 must be ZERO (no fault)
```

**Both polarities are required**: bit 5 set must fault, bit 5 clear must not. The
emulator's gate — `if (!(versabus_xltr_data_hi() & 0x20))` serve memory, else BERR —
matches this exactly. *That is a validation rather than a correction, which is worth
recording in a document that has mostly been finding errors: this rule was inferred,
and the firmware's own test confirms it in both directions.*

#### Two probes, read and write, and a hand-installed bus-error vector

```
$F096AC  move.w  (a1),d0     ; READ probe   } each followed by
$F096B8  clr.w   (a1)        ; WRITE probe  } FOUR NOPs, then rts
$F096C4  movem.l d0-d1/a0-a1,-(a7)
$F096C8  movea.l $8.w,a0                ; save the old bus-error vector
$F096CC  move.l  #$F098E0,$8.w          ; install a temporary one
$F096A2  move.l  a0,$8.w                ; and restore it afterwards
```

and the temporary handler:

```
$F098E0  moveq   #$1,d1          ; flag that a fault happened
$F098E2  lea     $8(a7),a7       ; step over SSW + access address + IR
$F098E6  addq.w  #$4,$4(a7)      ; ADVANCE THE SAVED PC BY 4
$F098EA  rte
```

**This is why the probes are followed by four NOPs.** The handler resumes at
saved-PC + 4, but the probe instruction is only 2 bytes, and on a 68000 the PC saved
in a bus-error frame is *imprecise* — somewhere in or after the faulting instruction.
The NOP padding is slack that makes any landing point in that range harmless. What
looks like alignment filler is load-bearing.

Two consequences for emulation, both concrete:

- **The handler depends on the exact group-0 frame layout.** It does `lea $8(a7),a7`
  then `addq.w #$4,$4(a7)`, which only lands on the PC's low word for the **68000**
  7-word frame. The known-divergence table already records that Musashi had to be
  patched from its hard-coded 68010 frame; this is the code that would break, and it
  would break silently by resuming at a wrong address rather than by faulting.
- **The write probe is `clr.w`, and that matters.** A real 68000 **reads the
  destination before writing**, so on iron phase `$1702` exercises the read path too;
  the emulator models `CLR` as a pure write, so it exercises only the write path. The
  divergence table lists this as a parity-BERR risk for DRAM — here it changes what a
  *chassis* test actually covers, which is a second, unrecorded consequence of the
  same modelling gap.

### The self-test "phase" is a running counter in `d6`, not a test identifier

The phase beacon is `move.w d6,$204(a6)` and the value is maintained by hand:

```
$F08992  bsr.w   $F098EC        ; address-uniqueness RAM test   -> phases $20xx
$F08996  addi.w  #$100,d6       ; BUMP THE PHASE BASE
$F0899A  bsr.w   $F09986        ; pattern test                  -> phases $21xx
$F0899E  move.l  a5,-(a7)
$F089A0  addi.w  #$100,d6       ; bump again
$F089A4  cmpa.l  #$1fff0,a1     ; ... inside an OUTER LOOP
$F089AC  lea     -$20(a1),a1
```

`$F098F0` does `clr.b d6` — clearing only the **low** byte — then writes `d6` to
CHANNEL_SELECT, so the high byte is the caller's running base and the low byte counts
sub-steps within a test. **`$F098EC` is called from exactly one site**, `$F08992`, yet
produces both `$20xx` and `$24xx` phases: the outer loop runs a four-sub-test block
twice, and each iteration advances the base by `$400`.

**So `$20xx`-`$23xx` and `$24xx`-`$27xx` are the same code, run twice** — confirmed
independently by the beacon PCs, which are identical between the two groups
(`$F098F2`, `$F099B8`, `$F099FA`, `$F09A84`). And `$F099B8` is called from **six**
sites, which is exactly why `$21xx` and `$25xx` each have six phases.

*This changes how the phase space should be read.* This document and `CLAUDE.md` list
phase inventories — "phases `$0100`-`$1A00`, `$2000`", "13 confirmed", "30 phases" —
as though each value named a distinct test. They are **counter values**. Several
groups are re-runs of one block with a different base, so a count of distinct beacon
values overcounts distinct tests. The 105 values `$0100`-`$0168` are one test
incrementing per register, not 105 tests.

#### Phases `$0100`-`$0168` are the 68000 CPU register self-test

```
$F08A6E  moveq   #$ff,d7
$F08A70  cmpi.l  #$ffffffff,d7      ; does moveq sign-extend?
$F08A78  move.l  #$f0f0f0f0,d6      ;   no -> error marker, and spin
...
$F08AC8  move.l  d0,d1 / not.l d1
$F08ACC  movea.l d0,a6 / movea.l d1,a5 / movea.l a6,a4
$F08AD2  move    a5,usp             ; through the USER STACK POINTER
$F08AD6  move    usp,a3
$F08AD8  movea.l a2,a0 / movea.l a3,a1 / move.l a0,d4 / move.l a1,d5
```

A value and its complement are walked through **every register including the USP** —
reachable only via the privileged `move usp` forms — with the phase counter
incremented per step. Nothing chassis-side is involved.

#### What each phase group actually touches

Classifying every group by the devices its code accesses, **with the beacon write
itself excluded** (including it makes every group trivially "touch the XLTR", which is
how the first version of this classification came out useless):

| group | phases | touches | needs a chassis model? |
|---|---|---|---|
| `$01xx` | 105 | VMOD | no — CPU registers |
| `$02xx` `$05xx` `$08xx` `$09xx` `$11xx` `$12xx` `$14xx` | 4-6 each | BOARD/PTM, VMOD | **board-status handshake only** |
| `$03xx` `$04xx` `$07xx` `$10xx` `$20xx` `$21xx` `$22xx` | 1-6 each | **nothing** | no — pure RAM/CPU |
| `$06xx` `$13xx` | 8, 7 | VMOD | no |
| `$15xx` `$16xx` `$23xx` | 1-6 | XLTR | yes |
| `$17xx` `$18xx` `$19xx` `$28xx` `$29xx` | 1-5 | chassis memory + XLTR | yes |
| `$1Axx` | 3 | **AP I/F** + XLTR | yes |

**The bit-mapping rules this project derived "from phases `$0800`/`$1100`/`$1200`/
`$1400`" come from the board-status group** — `$F70019` and `$1FFF0/1` only, no XLTR or
AP I/F. That is consistent with those rules all being equations relating `$F70019` bits
to `$1FFF1` bits, and it means they were derived from the right phases; but it also
means **only ten of the thirty groups touch the XLTR, AP I/F or chassis memory at
all**. A chassis model has far less to answer for than the phase count suggests.

### The panel-code space is partitioned by owning task, not by channel

*This withdraws my own hypothesis from the section below.* Having found `$262`-`$268`
organised per channel, I suggested the code space runs in "per-channel runs of four".
Classifying **every** code by which task regions issue it shows the real structure,
and it is by **owning task**:

| range | issued by | evidence |
|---|---|---|
| `$258`-`$260` | **RDHC only** | 1-5 sites each, all in `$F04600-$F05CFF` |
| `$262`-`$264` | **XP tasks only** | 4, 4 and 8 sites — one or two per task |
| `$269`-`$26C` | **shared** — RDHC *and* all four XP tasks | 5, 20, 10, 45 sites |
| `$26D`-`$271` | **XP tasks only** | 4, 8, 4, 8 sites |
| `$276`-`$27B` | **RDHC only** | one site each |
| `$27D` | RDHC + IO1I | |
| `$27E`-`$280` | **IO1I only** | one site each |
| `$29E`-`$2A6` | **RTOS init only** | the nine exception reporters |

So each task owns a private block and there is one **shared group at `$269`-`$26C`** —
which is exactly the abort/timeout/release family every task needs. That is a stronger
and simpler rule than per-channel runs, and it predicts where an unassigned code
belongs.

#### Two label corrections it forces

**`$25D`-`$260` are not per-channel config.** They are recorded as
`PCMD_CH{1..4}_CONFIG`, but all four are **RDHC-only** with irregular site counts
(2, 1, 2, 2). A genuinely per-channel code appears once or twice *per XP task*, as
`$262`/`$263`/`$264` do. The `CH1`-`CH4` labelling on this block is unsupported.

**`$25B` (`PCMD_CH1_FLUSH`) is never issued.** The instruction sweep finds **zero**
sites. Likewise `$261`, `$26F` and `$27C` have no sites — and `$27C` is precisely the
"gap where `INIT_STEP7` would sit" this document already noted, now confirmed as a
real absence rather than a naming oversight. So of the codes named in the table, one
(`$25B`) names something the firmware never does.

*Methodological note, the fifth of its kind this session: a raw byte-pair search is
**not** a valid absence test here. Searching the ROM for the two bytes of each code
gives 71 hits for `$260` and 15 for `$258` — nearly all incidental matches inside
displacements and data. Only the instruction-level sweep (`move.w #imm,d0`,
`addi.w #imm,d1`) distinguishes a code being *issued* from its bytes merely occurring.
`$26F` is the one case where both agree at zero.*

### Seven undocumented panel codes, and RDHC's dispatch copy is 180 bytes short

Diffing the five copies of the dispatch subsystem over `$5C8` bytes:

| pair | differing bytes |
|---|---|
| RDHC vs any XP | **197** |
| XP4I vs XP3I/XP2I/XP1I | 49 |
| XP3I vs XP2I vs XP1I | 25 |

**RDHC's copy is the outlier, and most of the difference is that it ends earlier.**
From offset `+$51A` (`$F05C52`) to the end, RDHC is **all zeros** while the four XP
copies carry ~180 bytes of code RDHC does not have. So the subsystem is not five
copies of one thing — it is four copies of a longer version plus one shortened
variant.

The extra routine (XP1I's at `$F084AA`) is a channel-validating notifier:

```
$F084AA  cmpi.w  #$1,d0
$F084B0  cmp.w   $105E,d0          ; validate 1 <= channel <= channel count
$F084B8  move.w  #$263,d0          ; reject
$F084BC  jsr     $F086C0           ;   via the task's own issuer
$F084C2  moveq   #$18,d2
$F084C4  lsr.l   d2,d1             ; take the TOP BYTE of d1
$F084CA  beq     -> skip
$F084CE  moveq   #$10,d0
$F084D0  lea     $F07D40,a0        ; the task's own region base
$F084D6  trap    #1                ; directive $10
$F084DA  addi.w  #$264,d1          ; panel code $264 + CHANNEL
$F084DE  move.w  d1,$e(a5)         ;   -> the command port
```

#### The panel-code table is missing seven codes

Sweeping every `move.w #$2xx,d0` and `addi.w #$2xx,d1` against the documented table
turns up three constants that are not in it, all of them XP-task-only:

| code | sites | what |
|---|---|---|
| `$262` | 4 — one per XP task, in the ISR prologue (`$F07ED8` etc.) | issued immediately before `jsr <own issuer>` |
| `$263` | 4 — one per XP task | **channel-number reject** in the routine above |
| `$264` | 8 — two per XP task | once loaded plainly, once as **`addi.w #$264,d1`** with `d1` = the channel |

Because `$264` is *added* to a channel number, the family is **`$264`-`$268`** — a
per-channel code, `$265`-`$268` for channels 1-4. Together with `$262` and `$263`
that is **seven previously unrecorded codes, `$262`-`$268`**, filling exactly the gap
between the documented `$260` and `$269`.

**`$261` is used nowhere**, which is consistent: `$25D`-`$260` are the four
per-channel config codes, so a fifth at `$261` would have no channel to belong to.
The panel-code space is denser than recorded and organised in per-channel runs of
four.

Also worth noting: **directive `$10`** — one of the three "XP-side" directives — is
issued here with the task's **own region base** as its parameter block and a channel
number in `d1`, and only when the top byte of `d1` is nonzero. Alongside `$43`
(task-lookup-by-name) and `$29`/`$2A` (queue lookup and post), that makes four of the
fourteen directives with concrete call sites, though `$10`'s semantics are still
unnamed.

### The complete XP-task template parameterization, by diffing the four copies

Using the template-diff lever the authorship finding suggests. First the alignment,
because the recorded figures were wrong:

| task | body | best shift vs XP1I | differing bytes of 2304 |
|---|---|---|---|
| XP1I | `$F07E12` | — | — |
| XP2I | `$F07412` | 0 | **71** |
| XP3I | `$F06A12` | 0 | **72** |
| XP4I | `$F06018` | **−`$1E`** | **265** |

**The XP4I displacement is `$1E`, not `$18`**, and it is a clean minimum — the next
best alignment is 2026 differing bytes against 265, so there is no ambiguity. XP4I *is*
a template copy; its 265 divergences are accumulated constant patches, not a different
implementation. And **"XP1I/2/3 differ in exactly 77 bytes" applies to the XP2I/XP3I
pair only** — XP1I differs from each of them by 71-72 over the body.

Diffing all four yields the complete set of patched constants, and every family
resolves:

| family | XP1I | XP2I | XP3I | XP4I | what it is |
|---|---|---|---|---|---|
| channel literal | `01` | `02` | `03` | `04` | the channel number |
| **BIM CR low byte** | `44` | `46` | `50` | `52` | `$FF0244/46/50/52` |
| channel `+$0E` | `4E` | `6E` | `8E` | `AE` | command/status port |
| channel `+$08` | `48` | `68` | `88` | `A8` | data high |
| channel `+$0A` | `4A` | `6A` | `8A` | `AA` | data low |
| record base | `66` | `6C` | `72` | `78` | `$1066 + (ch-1)*6` |
| record `+2` | `68` | `6E` | `74` | `7A` | |
| record `+4` | `6A` | `70` | `76` | `7C` | |
| six routine addresses | `86 84 83 85 7D 7F` | `7C 7A 79 7B 73 75` | `72 70 6F 71 69 6B` | `68 66 65 67 5F 61` | third byte of `jsr abs.l` — each task calls **its own copies** |
| **scan mask** | `$FFF0` | `$FF0F` | `$F0FF` | `$0FFF` | one nibble per channel |

**The BIM CR family independently re-derives the documented BIM assignment table** —
`44/46/50/52` are exactly `$FF0244`, `$FF0246`, `$FF0250`, `$FF0252`, and the
irregular step (+2, +$A, +2) is why: the four XP channels are not contiguous across
the three BIMs. A diff of four code copies reproducing a table assembled from
datasheet reasoning is a good independent check on both.

**The scan mask is new and it types a register field.** Guarded on MODE1 bit 7 (busy),
each task loads a mask and calls its own copy of the channel scan:

```
$F07E3C  move.l  #$fff0,d2 / jsr $F08616     ; XP1I
$F0743C  move.l  #$ff0f,d2                   ; XP2I
$F06A3C  move.l  #$f0ff,d2                   ; XP3I
$F06042  move.l  #$fff,d2  / jsr $F067FE     ; XP4I  ($0FFF)
```

`FFF0 / FF0F / F0FF / 0FFF` — **a 16-bit word holding one nibble per channel, and each
task clears its own.** So the scan word is nibble-per-channel and the mask means "all
channels except mine". That is a field layout no usage pattern would have revealed, and
it tells a chassis model that the scan operand is four 4-bit per-channel fields rather
than a bitmask of flags.

*Small trap on the way: `grep '#\$0fff'` found nothing because the disassembler prints
`#$fff` without the leading zero, which briefly made XP4I look like it lacked the mask
entirely. Third time a search has failed on formatting rather than content.*

### Nor Pascal — and the positive evidence for hand-authorship

*Follow-up question: could it have been Pascal?* Pascal is a **harder** fit than C,
not an easier one. `link a6,#-N` exists on the 68000 largely to serve Algol-family
frames, and Pascal needs them more than C does — nested procedures with static links,
and local variables in every scope. Tested anyway, against Pascal's own distinctive
marks:

| signature | RMS68K kernel | FPS application |
|---|---|---|
| `link`/`unlk` | 0 / 0 | **0 / 0** |
| `CHK` (Pascal range/subrange checks) | 1 | **0** |
| `DBcc` | 4 | 13 |
| a7-relative positive displacements | — | **18 in 24 KB** |

**Zero `CHK` in 24 KB of application code.** A Pascal compiler emits `CHK` for array
indexing and subrange assignment; the ROM has a `CHK` *exception vector* (panel code
`$2A2`) and never executes the instruction. Compiling with checks disabled would
explain that — but not the missing frames.

And the frameless-compiled-code escape is closed too. A leaf routine compiled without
a frame reads parameters at small fixed `d(a7)` offsets after entry. There are only
**18** such accesses in the whole application, and they are not parameter reads:

```
$F05666  move.l   a0,$4(a7)      ; writing INTO a stack-built RTOS parameter block
$F05670  lea      $a(a7),a7      ; discarding that 10-byte block
$F0677E  movea.l  $3c(a7),a3     ; reaching over a 96-byte scratch area
                                 ;   allocated by lea -$60(a7),a7
```

That is hand-rolled stack scratch, not a calling convention.

#### The positive evidence, which is stronger than any absence

Absence of a signature can always be explained by a compiler setting. What cannot is
**byte-identical replication with hand-patched constants**, and this ROM is full of it:

- **8 panel-command issuers**, byte-identical over 48 bytes, each followed by its own
  `bra .`
- **5 copies of the whole `PanelStatusDispatch` subsystem** — the 42-entry table,
  `PanelErrorMaskTable`, and all four primitives — where `POLL` and `BLK_XFR` are
  byte-identical and the other two differ in **2 of 64 bytes**
- **4 XP task bodies** at a `$A00` stride, differing in 77 bytes of patched constants

The decisive detail is **XP4I's `$18` shift**. Three tasks sit on an exact `$A00`
grid; the fourth's code is displaced by `$18`, and its dispatch table lands `$18` off
the grid to match. A compiler emitting four instances of one routine produces a
uniform stride. A person copying a working block, editing the constants, and having
one copy end up eighteen bytes out does exactly this.

So: **hand-written 68000 assembly, by a small team working from a template**, and the
`$18` shift is the fingerprint. That also explains why `d7` is hand-preserved across a
dispatch, why `swap d0` carries two values in one register's halves, and why the same
`+$10000` staging arithmetic is implemented three separate times instead of once in a
shared routine.

*Useful consequence for the disassembly: template families can be diffed against each
other. That is how the 42-slot census was corrected and how the XP4I divergences were
found, and it only works because the copies are copies.*

### No compiled C anywhere — but the a6 idiom maps every parameter structure

*Prompted by a question about whether the application code is compiled C, and
whether frame layout could be used as a block-identification heuristic.* Tested
rather than assumed:

| region | `link a6` | `unlk` | `rts` | `rte` |
|---|---|---|---|---|
| RMS68K kernel | **0** | **0** | 25 | 191 |
| RDHC | **0** | **0** | 36 | 0 |
| XP1I-XP4I | **0** | **0** | 112 | 0 |
| self-test | **0** | **0** | 48 | 12 |
| RTOS init | **0** | **0** | 9 | 0 |
| **whole 64 KB** | **0** | **0** | 231 | 203 |

**There is not one `link`/`unlk` pair in the entire ROM**, kernel or application. None
of it is compiled C with a conventional stack frame — it is hand-written assembly
throughout, which is consistent with everything else found here: parameters passed in
registers, `d7` hand-preserved across a dispatch, `swap d0` carrying two values in
one register's halves, and byte-identical template copies with patched constants that
no compiler would emit.

**But a variant of the heuristic works, and it is a better tool than the original.**
The a6-relative accesses in the FPS region are **150 positive and 0 negative** —
exactly inverted from a C frame, which needs negative displacements for locals.
Positive-only means **a6 is a pointer to a caller-supplied structure**, so grouping
those accesses by the instruction that loads a6 yields a field map per structure:

| a6 set at | structure | fields |
|---|---|---|
| `$F05370` | **RDHC command descriptor** | `+$00 +$04 +$08 +$0C +$10 +$14` |
| `$F05D54` | TCBIO1I prologue block | `+$00 +$0A` |
| `$F05F68` / `$F06968` / `$F07368` / `$F07D68` | XP4I…XP1I prologue blocks | `+$00 +$0A +$14` |
| `$F08B02` | the `$FF0000` window in the self-test | 11 offsets, 112 accesses |
| `$F0A31A` | an RTOS-init structure | `+$00 +$08 +$38 +$3C` |

The four XP tasks share one prologue-block layout and TCBIO1I a reduced form of it —
which is the template relationship already established, now visible in the *data*
rather than the code.

#### The RDHC command descriptor has six fields, not three

This document published it as `{command, operation, channel}`. The a6 map shows three
more, and the sites decode them by where they go:

| offset | loaded into | role |
|---|---|---|
| `+$00` | `d0` | **operation code** — the `PanelStatusDispatch` index |
| `+$04` | `d4` | **channel**, defaulting to `$E62` |
| `+$08` | `d2` | **transfer count** — `BLK_XFR`/`POLL` loop bound `d1 = 1..d2` |
| `+$0C` | `d1` | **32-bit payload** — what `D1_SEND` pushes across |
| `+$10` | `d3` | third parameter |
| `+$14` | `a2` | **the buffer**, `lea $14(a6),a2` — *inline*, not a pointer |

`$F05446` loads `d1` from `+$0C`, `$F05460` loads `d2` from `+$08`, `$F05464` loads
`d3` from `+$10`, and `$F0544A` takes `a2` as `$14(a6)`. Cross-checking against the
primitives decoded earlier: `D1_SEND` sends `d1`, `BLK_XFR` and `POLL` use `d2` as
the count and `a2` as the other end, `D2_FIN` pushes `d2`. **Every field lands where
a primitive expects it**, which is what makes the layout convincing rather than
merely consistent.

Because `a2` is `lea`'d rather than loaded, the buffer is **inline in the
descriptor**: a command record is a `$14`-byte header followed by its data. So a host
driving this machine writes `{1, operation, channel, count, payload, param, data…}`
into chassis memory at `$400000` and lets RDHC pick it up — which is now a complete
enough specification to synthesise real commands rather than probe with `1,14,1`.

*The op-`$14` path is the exception: `$F0542C` sets `a2` to a fixed ROM address
(`$F0549E`) instead of the inline buffer, which is why that operation works without
any descriptor payload and made a convenient first probe.*

### `FPS3K_ACCESSLOG`: true access widths settle it — `$FF0212` IS a register

*Added at the user's suggestion, and it immediately overturned a conclusion reached
one section below.* The `-bus` log records accesses **after** the emulator
decomposes them: `m68k_write_memory_32` fans out into four `bus_write8` calls, and
`versabus_write()` only receives a width when the whole span happens to be device
space. `FPS3K_ACCESSLOG=<file>` logs at the **CPU boundary**, before any splitting,
recording `op width addr value pc` for every data access across the whole address
space. A 200 M-cycle run produces 32.8 M entries.

**Result: there are no 32-bit accesses anywhere in `$FF0200-$FF025F`.** Every XLTR
access is 2-byte. So the explanation given below — that `$FF0212` is the tail of a
longword access to `$FF0210`, split by the logger — is **wrong**. It was a plausible
story inferred from log adjacency, and the width data refutes it.

`$FF0212` is accessed exactly twice, and the PCs identify the code:

```
W 2 FF0212 = 0020  from PC F09560
R 2 FF0212 = 0020  from PC F095C0
```

`$F09560` is `move.w d0,(a6,a0.w)` and `$F095C0` is `cmp.w (a6,a0.w),d0` —
**indexed addressing**, which is why every static search for `$212(aN)` came up
empty. This is **self-test phase `$1600`** at `$F09536`, an XLTR register
write-then-read-back test with two walking loops:

```
$F09558  move.w  #$10,d0
$F0955C  movea.w #$210,a0
$F09560  move.w  d0,(a6,a0.w)     ; write
$F09564  lea     $2(a0),a0
$F09568  lsl.b   #$1,d0           ; $10 -> $20 -> $40 -> $80 -> carry
$F0956A  bcc     -> $F09560       ; so EXACTLY four registers

$F0956C  move.w  #$c0,d0
$F09570  movea.w #$230,a0         ; then the BIM block, ascending from $C0
$F09574  move.w  d0,(a6,a0.w)
$F0957C  addq.w  #$1,d0
$F0957E  cmp.w   d1,d0 / bne
```

**So `$FF0212` is a real, writable, read-backable 16-bit register.** The test writes
`$0020` and *requires* it to read back — `bne -> $F095E8` is the failure path. That
is a hardware fact: there is storage there. The firmware simply never uses it
functionally. **The documented register table is incomplete, not wrong**, and
`$FF0210`-`$FF0216` form a **four-register group** the self-test walks with
`$10/$20/$40/$80`.

*Three attempts at this one address: the static sweep said "not a register" (right
about functional use, wrong about existence), the bus log said "an undocumented
register" (right, for the wrong reason), and my adjacency argument said "a logging
artefact" (wrong). The width-aware log gave the answer in one read.*

#### Phase `$1600` also states which bits of each XLTR register are real

Its verification section is a specification of readback behaviour:

| register | written | checked |
|---|---|---|
| `CHANNEL_SELECT` `$204` | `d6` | must read back exactly |
| `MODE1` `$202` | `$2000` | must read back exactly |
| `MODE0` `$200` | `$0000` | **masked `$FF`** must be 0 — the high byte is not checked |
| `COUNTER` `$20C` | `$0001` | must read back exactly |
| `STATUS_IRQ` `$218` | `$0400` | **masked `$610`** must equal `$400` |
| `IRQ_MASK` `$21A` | `$0FFF` | must read back exactly |
| `$210`-`$216` | `$10/$20/$40/$80` | each must read back exactly |
| `$230`-`$23E`… | ascending from `$C0` | each must read back exactly |

**`MODE0`'s high byte and `STATUS_IRQ`'s bits outside `$610` are not required to
hold what was written** — which is exactly the sort of per-bit rule a chassis model
needs and cannot get from usage patterns alone.

#### And the hottest address in the machine is not what I said

The previous section called `$FF0204` "by far the hottest register in the machine"
at 32,968 writes. Across the *whole* address space the board status register
**`$F70019` is read 590,333 times** — eighteen times more traffic. The earlier claim
was scoped to the bus log's device subset without saying so. `$F70003` and `$F7000D`
(PTM) are read ~1,850 times each; `$01FFF0` is the only address in the machine
touched at all three widths, including genuine 32-bit accesses.

### The XLTR block by two methods, and why neither is authoritative alone

Giving `$FF0200-$FF025F` the same treatment produced a **false positive from each
method**, which is the useful part of the exercise.

**Static attribution under-counts.** The basic-block scan (register loaded with
`#$FF0000`, used within 80 instructions before any reload) reported `$FF0214` as
*documented but never touched*, and showed the BIM control registers with **zero
reads** — even though chassis operation `$7` at `$F04F3A` plainly does a
read-modify-write on `$FF0230`. The cause is the window: handlers reached through a
jump table have their base register loaded far away in the ISR prologue, well past 80
instructions. So every absence claim from that scan is unsound.

**Runtime logging over-counts.** Switching to the bus log — 696,226 device accesses —
gave 42 distinct addresses and one that is not in the documented table at all:
`$FF0212`, with 2 reads and 2 writes, which the emulator itself labels
`XLTR_unknown`. Inspecting the log ordering settles it:

```
WR 2-byte FF0210 = 0010   XLTR_MODE2
WR 2-byte FF0212 = 0020   XLTR_unknown     <-- same instruction
RD 2-byte FF0210 = 0010
RD 2-byte FF0212 = 0020                    <-- same instruction
```

**`$FF0212` is not a register.** It is the second half of a **32-bit access to
`$FF0210`**, which the logger decomposes into two word accesses. The two ROM sites
that looked like candidates — `move.b $12(a3),d4` at `$F0A086`/`$F0A08C` — are not
XLTR accesses either: `a3` there is walking the **TDTI table** searching for the
`!TCB` marker, so `$12(a3)` is a TDTI entry field.

*That is four false positives across two sweeps — `$FF0002`, `$FF0050`, `$FF00FF`,
`$FF0212` — and the fourth came from the method I had just called the reliable one.
Static attribution misses accesses; runtime logging invents them by splitting wide
transfers. Neither is authoritative, and every hit needs its site read.*

#### What the two methods agree on

**The channel windows are exactly four offsets**, now confirmed at runtime with the
ISRs actually running on all four channels:

| offset | ch1 | ch2 | ch3 | ch4 |
|---|---|---|---|---|
| `+$04` | 0R/1W | 0R/1W | 0R/1W | 0R/1W |
| `+$08` | 467R | 467R | 467R | 484R/6W |
| `+$0A` | 467R | 467R | 467R | 484R/6W |
| `+$0E` | 468R | 468R | 468R | 489R/23W |

Nothing else in any 32-byte window is touched. XP4I additionally *writes* `+$08`,
`+$0A` and `+$0E` where the other three only read — worth noting alongside the other
XP4I divergences rather than explaining away.

**`$FF0214` never appears standalone.** Every access to it is the leading half of a
32-bit access at `$FF0214`, paired with `$FF0216` carrying a different value
(`$0040`/`$0080`). `$FF0216` is *also* written alone 14 times. So `$214` behaves as
the high half of a 32-bit data register whose low half doubles as the independently
read-modify-written mode/page register — which is consistent with the table's
description of `$216` and refines what `$214` is for.

**23 of the 24 BIM registers are used.** All of BIM0 and BIM1's eight, and BIM2's
`$250`-`$25C`; **only `$FF025E` (BIM2 VR3) is never touched**, in any configuration.

**`$FF0204` is by far the hottest register in the machine** — 32,968 writes against
7 reads in one run, which is the phase/beacon traffic. Any performance work on a
chassis model should start there.

### The AP I/F is five identical windows, and `$FF0010` is an emulator invention

Repeating the sweep on the **base** window `$FF0000-$FF003F`, with a conservative
basic-block attribution (register loaded with `#$FF0000`, used before any reload),
gives exactly four offsets:

| offset | sites | role |
|---|---|---|
| `+$00` | 11 | compared against 0 |
| `+$04` | 10 | polled ready flag, bit 0 |
| `+$08` | 11 | bulk data port |
| `+$0E` | 7 | command on write / status on read |

**The same four offsets as the channel windows.** So the AP I/F presents **five
identical 32-byte windows** — one at `$FF0000` for the host/bulk link and four at
`$FF0040 + $20N` for the XP channels — and an emulator can model one window type
five times rather than two unrelated register blocks. This document already observed
that `$FF0000-$FF001F` "has the same shape"; the sweep makes it exact and shows
nothing else in either type is touched.

#### `$FF0010` (`APIF_CMD_ARG_HI`) is never accessed

`$FF0010` appears **nowhere**: not as an absolute address, not as an attributed
displacement, and not at runtime — `FPS3K_PCLOG` reports **zero** accesses across
the default, RDHC-driven and four-channel configurations, while `$FF000E` reports
three in the same runs.

The emulator nonetheless models it: `versabus.h:29` defines `APIF_CMD_ARG_HI
0xFF0010` with read and write handling at `versabus.c:552` and `:642`. This document
lists it in the memory map as "`0xFF0010` = CMD_ARG_HI … modelled in
`emulator/versabus.{c,h}`, neither yet confirmed against hardware." The stronger and
correct statement is that **the firmware never touches it**, so it is not awaiting
hardware confirmation — it is a register the model invents, in the same class as the
`$4F` status value that was withdrawn earlier.

**And `APIF_CMD_ARG_LO` at `$FF000E` is misnamed.** That register is the **panel
command port** — every one of the eight `PanelIOConfigure` copies writes the command
code there — and it is read back as status, exactly like the channel `+$0E`. The
disassembly's own symbol, `APIF_PANEL_CMD`, is right and the emulator's is not. There
is no "command argument" pair here; there is one command/status register per window.

*A third instance of the same trap in one sweep: `$FF00FF` also looked like an
address until inspection showed `move.l #$ff00ff,d0` is loading a RAM-test **data
pattern** — the next instructions are `not.l d0` and `move.l #$55aa55aa,d0`. Hex
that matches an address range is not an address.*

### The channel window is exactly four registers, and the ISR snapshots three

Applying the "revisit every claim that rested on a blind method" rule to the whole
`$FF00xx` window: enumerate every access through a base register holding `$FF0000`,
which is the form absolute-address scans miss.

**A first attempt over-counted badly** and is worth recording as a trap. Accepting
any register that holds `$FF0000` *somewhere* in the ROM produced 382 hits including
96 at `$FF0002` and 71 at `$FF0001` — but `a1` is loaded with `$FF0000` at four sites
and used as a *channel data pointer* everywhere else, so `$2(a1)` was counted as a
window access when it is the data-pair low half. It also reported a register at
**`$FF0050`**, past the documented `+$0E`, which turned out to be `lea.l -$50(a5),a5`
— a *negative* displacement in the driver-chain routine — plus a truncated
`$250(a5)`. *A sweep written to catch a blind spot introduced two of its own.*

Restricting to `a5`, which is reliably `$FF0000` inside the channel ISRs, and to
positive two-digit displacements, gives a clean and completely symmetric result:

| offset | ch1 | ch2 | ch3 | ch4 | direction |
|---|---|---|---|---|---|
| `+$04` | `$F07E00` | `$F07400` | `$F06A00` | `$F06000` | **written** `#$0` |
| `+$0E` | `$F07EEE` | `$F074EE` | `$F06AEE` | `$F060D6` | **read** → record `+$0` |
| `+$08` | `$F07EF6` | `$F074F6` | `$F06AF6` | `$F060DE` | **read** → record `+$2` |
| `+$0A` | `$F07EFE` | `$F074FE` | `$F06AFE` | `$F060E6` | **read** → record `+$4` |

**No other offset in any of the four 32-byte windows is touched.** The corrected
four-register table this project reconstructed from usage patterns is *complete* —
a negative result, but a real one: there is no fifth per-channel register hiding
behind the displacement form.

Two things it settles.

**`+$0E` is bidirectional.** The table lists it as the command/trigger register
because three tasks write `$8000` to it. The ISR **reads** it, first of the three,
and stores it as the word that is then bit-tested for bits 15, 14 and 11. So `+$0E`
is *command on write, status on read* — which is exactly why `FPS3K_CHCMD` works by
supplying a value on that port, and why the local symbol `g_ch_block` on `$1066` is
a misleading name for what is a channel **status** word.

**The 6-byte per-channel record is fully explained.** `$1066 + (ch-1)*6` holds
precisely `{status from +$0E, data-high from +$08, data-low from +$0A}` — three words,
six bytes, exactly the observed stride. The record is the ISR's snapshot of its
channel window, and the stride was never arbitrary.

### The complete `$10xx` per-channel state map, and `$FF004A` *is* read

Collecting every non-data reference into `$1000-$10FF` from the disassembly gives the
whole per-channel state area. It is several **parallel arrays**, not one structure:

| base | stride | entries | what |
|---|---|---|---|
| `$1062` | 2 | 4 | task's own channel number |
| `$1064` | 2 | 4 | word array, the one chassis operation `$A` reads back |
| `$1066` | 6 | 4 | per-channel record (`$1066`/`$106C`/`$1072`/`$1078`), bit-tested at `+$0` |
| `$1080` | 4 | 4 | pointer to the channel's register image (`&$101E`) |
| `$10A0` | 2 | 4 | flag word; command 1 writes `2`, and `btst #1,$10A1` gates the ASQ post |
| `$10AE` | 4 | 4 | **`USER`-connect gate** |
| `$10BE` | 4 | 4 | **`USER` task handle** from directive `$43` |
| `$10CE` | 4 | 4 | per-channel longword |
| `$10DE` | 4 | 4 | per-channel longword, cleared on entry |

The four longword arrays sit **exactly `$10` apart**, which is `4 × 4` — so
`$10AE-$10ED` is a clean 4-wide × 4-deep block, and the block ending at `$10ED` is
confirmed by RTOS init referencing `$10EE` as the start of something else. Shared,
non-per-channel: `$105E` (channel count), `$107E` (byte read by all four tasks),
`$1098` (word array cleared per channel), `$10AA` (TCBIO1I's gate).

#### Correction: `$FF004A` is read, 468 times per run

This document states of the value `$4F` that *"it has no connection to `$FF004A`,
which is neither read nor written in a full boot."* The second half is wrong.

```
$F07EFE  move.w  $4a(a5),$106a      ; XP1I   -- a5 = $FF0000
$F074FE  move.w  $6a(a5),$1070      ; XP2I
$F06AFE  move.w  $8a(a5),$1076      ; XP3I
$F060E6  move.w  $aa(a5),$107c      ; XP4I
```

Each channel ISR reads **both halves** of its channel data pair — `$48(a5)` at
`$F07EF6`, already recorded, and `$4A(a5)` two instructions later at `$F07EFE` — and
files the low half in its per-channel record. Measured: `FPS3K_XPIRQ=1` executes
`$F07EF6` and `$F07EFE` **468 times each**, and with a four-channel chassis all four
tasks' equivalents run 467 times.

*The instructive part is how this survived.* This document already retracted exactly
this claim for `$FF0048` — "over-stated as 'never read anywhere' and that is
retracted… absolute-address scans cannot see that form" — and the neighbouring
sentence about `$FF004A`, in the same paragraph, describing the same register pair
read by the same instruction sequence, was left standing. **A correction was applied
to one address and not to its twin two instructions away.** When a measurement method
is found to be blind, every claim that rests on it needs revisiting, not just the one
that prompted the check.

So the corrected reading of the channel window: the ISR reads `+$08` and `+$0A` as a
pair, exactly as the "one 32-bit data register" model predicts, and the low half ends
up in the per-channel record at `$106A + (ch-1)*6`.

### There is a seventh task, named `USER`, and this ROM never creates it

Sweeping for `d7` writes — now known to carry the operation code — turned up **nine
sites: one in RDHC and two in each XP task.** The first per XP task is the expected
template copy (`$F07F1C` = RDHC's `$F056C4` + `$2858`). The second has no RDHC twin,
and it is a different routine entirely:

```
$F0856A  move.w  d0,d7            ; here d7 is a CHANNEL index, not an operation
$F0856C  subq.w  #$1,d7
$F0856E  lsl.w   #$2,d7           ; (ch-1)*4
$F08570  movea.w d7,a2
$F08572  tst.l   $10AE(a2)        ; per-channel GATE
$F08576  beq     -> $F08608       ;   zero -> skip entirely
$F0857A  lea     -$60(a7),a7      ; 96-byte frame
$F0857E  pea     (a7)
$F08580  move.l  #$0,-(a7)
$F08586  move.l  #$55534552,-(a7) ; 'USER'
$F0858C  moveq   #$43,d0
$F08590  trap    #1               ; DIRECTIVE $43 -- resolve a TASK by name
$F0859A  move.l  d0,$10BE(a2)     ; store the result per channel
```

**Directive `$43` has exactly four sites — one per XP task** (`$F06774`, `$F0718C`,
`$F07B8C`, `$F0858C`) — and each pushes the literal `'USER'`. So every XP channel
controller tries to resolve a task called `USER`, gated on its per-channel longword
at `$10AE`, and files the answer at `$10BE`.

**No such task exists.** The TDTI table creates exactly `RDHC IO1I XP4I XP3I XP2I
XP1I`. But the name table at `$F0467E`, which RDHC walks issuing directive `$12`, has
**six entries: `XP1I XP2I XP3I XP4I USER USER`** — two `USER` slots — and `'USER'`
occurs **13 times** in the ROM, including immediately before each XP task's entry
point (`$F05F40`, `$F06940`, `$F07340`, `$F07D40`).

*So the firmware is built around a seventh task that the ROM does not supply.* That
fits the FPS-3000 programming model exactly: the host issues `CPLOAD` to load a
**control-processor program**, and that program is the `USER` task; the four XP
channel controllers notify it through directive `$43` when their work completes. The
ROM is the half of the system that boots the machine and moves microcode — the other
half arrives from the host.

Three consequences.

**Directive `$43` is task-lookup-by-name**, the task-level analogue of `$29` for
queues. That is a third directive identified, and the pair `$29`/`$43` shows the
kernel resolves both queues and tasks by 4-byte name at runtime rather than by
compile-time index.

**It explains a limit on how far an XP transaction can be driven here.** The
completion notification has no recipient, so no configuration of the chassis model
can carry an XP channel through a full cycle — not because a register is missing but
because the *counterparty* is missing. `$10AE` being zero is what keeps that from
being an error rather than a hang.

**And it is a concrete, testable prediction for hardware**: on a real machine running
a CP program, `$10BE + (ch-1)*4` holds a task handle, and `$10AE + (ch-1)*4` is
nonzero. On this ROM alone both stay zero. Anyone dumping SBC RAM from a working
FPS-3000 can check that in one read.

### RESOLVED: `$0A` is distinguished by `d7`, the preserved operation code

The operation sweep found that `$0A` and `$14` complete while the other 27 live
codes loop forever, and that `$0A` is an *ordinary* `POLL` slot — nothing in the
jump table distinguishes it from `$01`, `$16`, `$17`, `$19`, `$1B`, `$1F`, `$22` or
`$24`. That question is now answered.

`PanelSendAndWait` preserves the operation code before the dispatcher destroys it:

```
$F056C4  move.w  d0,d7          ; save the operation code
...
$F0572C  lsl.w   #$2,d0         ; d0 becomes index << 2 for the jmp
$F05734  jmp     (a4,d0.w)
```

**`$F056C4` is the only write to `d7` anywhere in RDHC's 5.5 KB region**, so `d7` is
unambiguously the preserved operation code for the whole subsystem. And `POLL`'s
exit tests it:

```
$F05AC8  move.w  $202(a4),d5    ; XLTR_MODE1
$F05ACC  btst.b  #$7,d5         ; busy?
$F05AD0  bne     -> $F05AF0     ;   busy -> ordinary exit
$F05AD2  cmpi.w  #$a,d7         ; operation $0A?
$F05AD6  bne     -> $F05AF0     ;   no -> ordinary exit
$F05AD8  move.w  (a0),d4        ; yes: drain to completion --
$F05ADA  btst.b  #$f,d4         ;   spin while bit 15 is set,
$F05ADE  bne     -> $F05AD8
$F05AE0  btst.b  #$d,d4         ;   then check the error bit
```

So **operation `$0A` is `POLL`'s drain-to-completion variant**: when the channel is
not busy and the code is `$0A`, it waits for bit 15 to clear and checks bit 13
before returning. Every other `POLL` code skips that and is simply re-entered on the
next interrupt — which is exactly the "fires once versus fires 1468 times" split the
sweep measured.

Two things worth carrying forward:

- **`d7` is the operation code, available in every handler.** That is a general fact
  about this subsystem and it was invisible until the sweep raised the question:
  `d0` is consumed by the dispatch, `d7` survives it. A handler distinguishing its
  own slots — as `POLL` does — must use `d7`, and any future reading of these four
  primitives should check for `d7` comparisons.
- **`$0A` and `$14` are the two terminating operations for the same structural
  reason.** `$14` terminates because it *is* `D2_FIN`, the single finalize slot;
  `$0A` terminates because `POLL` special-cases it. Different mechanisms, same
  observable — and the sweep could not have told them apart, which is why the static
  decode was needed to close it.

*This closes the last question the 42-operation sweep opened. The mechanism guess
recorded earlier — "the primitives contain `d0`-dependent early exits" — was the
right class and the wrong register.*

### `POLL` is `BLK_XFR`'s mirror, and it explains the `XLTR_COUNTER = $04`

With `BLK_XFR` and `D2_FIN` already decoded, the remaining two primitives complete
the set — and `POLL` is misnamed. It is not a status poll; it is the **outbound**
bulk mover.

```
$F05A12  swap    d0                 ; same mode-in-the-high-word trick as BLK_XFR
$F05A14  a4 = $FF0000
$F05A1A  lea     $8(a4),a5          ; the bulk port
$F05A1E  cmpa.l  a2,a5              ; is the SOURCE the bulk port?
$F05A22  poll    $FF0004 bit 0      ;   then wait for ready
$F05A2C  move.w  #$4,$20C(a4)       ;   and set XLTR_COUNTER = $04
$F05A32  d1 = 1
loop:
$F05A3C  move.w  #$400,$218(a4)     ; arm STATUS_IRQ
$F05A42  poll bit 15, then clear $218
$F05A52  move.w  (a2),d6            ; read from the SOURCE
$F05A54  move.w  d6,(a1)            ; write to the CHANNEL DATA PAIR
$F05A56  cmpi.w  #$0,d0             ; mode, exactly as in BLK_XFR
```

**`BLK_XFR` moves channel → memory; `POLL` moves memory → channel.** Identical
shape: `swap d0` for the mode, the `a5 == $FF0008` special case (here on the
*source*), `a1` the channel data pair, `a2` the other end, and the same
one-address-versus-consecutive mode split. So the four primitives are really
**two movers, one sender and one finalizer**, not four unrelated handlers — and the
9 `POLL` slots and 9 `BLK_XFR` slots are the outbound and inbound halves of the
same operation set.

*The name in this document has been `POLL` since the dispatch table was first
decoded, taken from the `$218` handshake it does. That handshake is real, but it is
the transfer handshake, not the point of the routine.*

**It also identifies one of the seven `XLTR_COUNTER` sites.** `$F05A2C` writes the
operational value `$04` to `$FF020C` **only when the source is the bulk port** — so
`$20C` is a **burst/width counter armed before a bulk read**, and the reason `$04`
is "operational" while `$01`/`$FF` are boot-diagnostic is that 4 is the real burst
size. That is a concrete role for a register this document has only been able to
describe by its observed values.

And the `$218 = $400` / poll bit 15 / clear sequence in the inner loop is the same
handshake as the polled bulk loop at `$F04AE2`, so those are one mechanism used from
two places.

### `D1_SEND` has a fire-and-forget exit

```
$F058B2  swap    d1
$F058B4  move.w  d1,(a1)            ; d1 HIGH half -> channel data high
$F058B6  swap    d1
$F058B8  move.w  d1,$2(a1)          ; d1 LOW half  -> channel data low
$F058BC  move.w  #$8004,(a0)        ; REQUEST-TRANSFER
$F058C0  cmpi.w  #$4,d0             ; low word of d0 == 4 ?
$F058C6    read $21A, pop d4, index PanelErrorMaskTable, bclr that bit,
$F058DA    write $21A back, restore the BIM CR to $5F, rts   <-- NO WAIT
$F058E4  else 1000-poll timeout on bit 14, as usual
```

So `D1_SEND` pushes a 32-bit value across as two halves, and **when `d0`'s low word
is `4` it returns without waiting** — unmasking the channel's interrupt bit through
`PanelErrorMaskTable` and restoring the BIM control register to `$5F` on the way
out. That is the *asynchronous* variant: fire the transfer, re-enable the interrupt,
let the ISR collect the completion.

This is the mechanism class behind the open `$0A`-terminates-but-`$01`-loops
question from the operation sweep: **the primitives contain `d0`-dependent early
exits**, so two slots sharing a handler need not share its control flow. Which
exact test distinguishes `$0A` is still unresolved — `$F0572C` does `lsl.w #2,d0`
before dispatching, so the value the handler compares is `index << 2`, and no
`D1_SEND` index satisfies `index << 2 == 4`. Either another caller enters
`D1_SEND` directly with `d0 = 4`, or `POLL` has its own exit further in. *Recorded
as open rather than guessed.*

### `BLK_XFR` decoded: the bulk mover, and its mode is the swapped high word of `d0`

`$F05B0E` is the block-transfer primitive — 9 of the 42 operation slots reach it —
and it is the only primitive that moves bulk data. Fully decoded:

```
$F05B0E  swap    d0                ; the HIGH word of d0 becomes the mode selector
$F05B10  a4 = $FF0000
$F05B16  a5 = $FF0008              ; the bulk data port
$F05B1A  cmpa.l  a2,a5             ; is the DESTINATION the bulk port?
$F05B1C  bne     -> $F05B28
$F05B1E  move.w  $4(a4),d4         ;   then wait for $FF0004 bit 0 (ready)
$F05B22  btst.b  #$0,d4
$F05B26  beq     -> $F05B1E
$F05B28  moveq   #$1,d1            ; d1 = iteration counter, 1..d2

loop:
$F05B2C  move.w  (a1),d6           ; channel data HIGH
$F05B2E  move.w  d6,(a2)           ;   -> destination
$F05B30  cmpi.w  #$0,d0            ; MODE
$F05B36  move.w  $2(a1),d6         ; mode 0: data LOW -> the SAME address,
$F05B3A  move.w  d6,(a2)           ;         a2 NOT advanced
$F05B3E  move.w  $2(a1),d6         ; mode != 0: data LOW -> a2+2,
$F05B42  move.w  d6,$2(a2)
$F05B46  addq.l  #$4,a2            ;            a2 advanced by 4
$F05B48  move.w  #$8004,(a0)       ; REQUEST-TRANSFER for the next pair
$F05B50  d5 = 1000                 ; then poll bit 14 (done), bit 13 (error)
$F05B76  move.w  #$26c,d0          ; on timeout: RELEASE
$F05B80  addq.l  #$1,d1
$F05B82  cmp.l   d2,d1 / ble -> loop
```

What an emulator needs from this:

| register | role |
|---|---|
| `d2` | **transfer count** — the loop runs `d1 = 1..d2` inclusive |
| `a1` | the **channel data pair**: `+$00` high, `+$02` low (e.g. `$FF0048`/`$FF004A`) |
| `a2` | the **destination pointer** |
| `a0` | the channel **command port**, written `$8004` once per iteration |
| `d0` high word | **mode**: zero deposits both halves at one address; nonzero deposits them at `a2` and `a2+2` and advances by 4 |

This document has described `BLK_XFR` as copying "word `(a1)`→`(a2)`, advance `a2` by
4" and separately noted that it "deposits them at one address **or** at consecutive
addresses". Both readings were right and they are the two *modes* — selected by the
caller's `d0` **high** word, which the `swap` at entry brings into the test. Note the
caller at `$F05422` loads `d0 = $FFFF000F`, so the high word is `$FFFF` and op `$14`
runs in **consecutive-address mode**; the low word `$000F` is the dispatch index.
*One register carries both the table index and the transfer mode, in different
halves* — which is why the `swap` is the first instruction.

Two details worth having:

- **The destination may be the chassis bulk port itself.** The entry check compares
  `a2` against `$FF0008` and, only in that case, waits for `$FF0004` bit 0. So
  `BLK_XFR` is a **RAM→chassis** mover as well as chassis→RAM, and the ready
  handshake is required only in the outbound direction. That makes `$FF0004` bit 0 an
  *input-side* flow-control flag, consistent with its use in the polled bulk loop at
  `$F04B22`.
- **Every iteration re-arms.** `$8004` is written per word-pair, not once per
  transfer, with a 1000-poll timeout each time and `$26C` RELEASE on expiry. So a
  chassis model must acknowledge bit 14 once per pair; acknowledging once per
  transfer stalls after the first.

### One operation per run: RDHC 36% → 47%, total 54%

Acting on the truncation finding below — replacing the single long `FPS3K_SEQ` with
**one chassis operation per run**, unioned over 63 configurations:

| region | instruction bytes | previous union | now |
|---|---|---|---|
| **RDHC** | 5484 | 36% | **47%** |
| IO1I | 422 | 46% | 46% |
| XP1I | 2358 | 40% | 40% |
| XP2I | 2310 | 34% | 34% |
| XP3I | 2300 | 34% | 34% |
| XP4I | 2342 | 37% | 37% |
| self-test | 5292 | 85% | 85% |
| RTOS init | 2352 | 76% | 76% |
| pre-task | 120 | 0% | 0% |
| **total** | **22980** | 51% | **54%** |

**RDHC gains 11 points from nothing but changing the shape of the experiment.** No
new hook, no new hardware inference — the long sequence had been discarding its own
tail, and every op in that tail was reachable the whole time.

*The lesson generalises past this project: when a driving mechanism has a hidden
capacity limit, a longer script does not probe more, it probes the same and hides the
rest. Sixteen one-code runs cost the same wall-clock as one sixteen-code run and
actually deliver sixteen codes.*

### Op `$5` is `XPSEL`, and the scripted-sequence hook delivers only ~4-6 codes

Two corrections to how the chassis operations were characterised and exercised.

#### Op `$5` writes `$E60`; it is the select-channel primitive

The operations table above described op `$5` as "validate CHANNEL_SELECT against
`$105E`". It also **stores** the value:

```
$F04F16  clr.w   $0E60
$F04F1C  move.w  $204(a0),$0E62      ; CHANNEL_SELECT -> the channel register
```

`$E60`/`$E62` are the only writes to that pair anywhere in the ROM, and `$E60` is
exactly what op `$4` validates (`$F04E3A`) and what command 1 defaults its channel
from (`$F0537E`). So **op `$5` is `XPSEL`** — the select-channel primitive from the
CPFORTRAN table — and it is the prerequisite for every operation that works on "the
current channel". High word at `$E60`, low at `$E62`, so `$45` sets the high half in
the usual bit-6 pattern.

#### Long scripted sequences are worse than short ones, and pacing is not why

A 27-code sequence reached ops `1 2 4 5 8 9 D` and not `0 3 6 7 A B C E`, which read
as those eight being unreachable. **They are all individually reachable** — a
one-code run `FPS3K_SEQ=0B:0001` reaches op `$B`, and the same holds for every one
of `$0`, `$3`, `$6`, `$7`, `$A`, `$C`, `$E`.

The sequence simply stops after **about four to six codes**. My first hypothesis was
pacing: `FPS3K_SEQGAP` defaults to 20 M cycles and 27 codes would need 540 M against
a 400 M budget. **That hypothesis is wrong.** Gaps of 20 M, 2 M, 500 K and 200 K, and
a run three times longer, all give byte-identical results:

| gap | cycles | RDHC | ops reached |
|---|---|---|---|
| 20 M | 400 M | 12% | `124589D` |
| 2 M | 400 M | 12% | `124589D` |
| 500 K | 400 M | 12% | `124589D` |
| 200 K | 400 M | 12% | `124589D` |
| 2 M | 1200 M | 12% | `124589D` |

The limiter is **arm events, not time**: a code is handed over only when the SBC
issues another panel command, and after a handful of operations it stops issuing. Put
the "unreachable" ops first and they are the ones that run (`00,03,06,07,...` reaches
`0 3 6 7`), which settles it.

*So a long `FPS3K_SEQ` is actively misleading — its tail is silently dropped, and a
reader sees "op $A does nothing" when op `$A` was never delivered. The right shape
for exercising the operation set is many one-code runs, unioned. That also means the
existing modelling caveat — "the chassis can only answer, it cannot initiate" — has a
measurable consequence: roughly five operations per conversation is all this model
can drive.*

### The "XP3I outlier" was the `$105E` presence gate; all four tasks are symmetric

XP3I sitting at 12-13% while XP1I reached 40% was recorded here as unexplained. It
is entirely the channel-presence gate. `versabus.c` defaults to `FPS3K_CHANNELS=2`
— the real 2-AC machine — so `$105E` reads 2, and each XP task's
`cmpi.w #<own channel>,$105E / blt` **gates tasks 3 and 4 off before they touch
their bodies**.

| task | `CHANNELS=2` | `CHANNELS=4` |
|---|---|---|
| XP1I | 36.7% | 36.7% |
| XP2I | 34.1% | 34.1% |
| XP3I | **13.0%** | **33.8%** |
| XP4I | **13.7%** | **36.5%** |

XP1I and XP2I are untouched; XP3I and XP4I roughly triple. **All four tasks reach
34-37% once their channel is present and their interrupt is raised** — the 12-to-40%
spread was never a property of the code, and XP4I is not the poor relation its
`$18`-shifted layout might suggest.

*Two things follow, and they pull in opposite directions.* For fidelity to Lovett's
machine `FPS3K_CHANNELS=2` is correct and XP3I/XP4I **should** be dormant — the
chassis has only AC1 and AC2 populated, and the presence gate working is a feature.
For *coverage*, `CHANNELS=4` exercises code the real box never runs. So the
4-channel figure is a tool for reading the disassembly, not a model of the machine,
and the two must not be conflated in a coverage claim.

The `13%` floor is worth naming for what it is: the cost of a task that starts,
runs its prologue, connects its vector, checks `$105E`, and parks. That is the
**self-gated baseline**, and it is the right expectation for AC3/AC4 on this
chassis.

#### Coverage with all four channels present

| region | instruction bytes | union |
|---|---|---|
| pre-task | 120 | 0% (kernel-panic path, by design) |
| RDHC | 5484 | 36% |
| IO1I | 422 | 46% |
| XP1I | 2358 | 40% |
| XP2I | 2310 | 34% |
| XP3I | 2300 | 34% |
| XP4I | 2342 | 37% |
| self-test | 5292 | 85% |
| RTOS init | 2352 | 76% |
| **total** | **22980** | **51%** |

**51% of instruction bytes**, union over 16 configurations — from the 25% recorded
at the start of this session, though note ~4 points of that gain is the denominator
correction rather than new execution.

### Correction: my coverage denominators counted `DC.W` data as code

Every coverage percentage produced in this session's measurements used a
denominator built by regex over `fps3k.asm` lines with hex bytes — which matches
`DC.W` data lines as readily as instructions. Of what the disassembler emits,
**6,482 lines are instructions (22,980 bytes) and 12,506 are `DC.W` data words
(25,012 bytes)** — very nearly half. Counting the data deflated every figure.

| region | instruction bytes | data bytes | as reported | correct |
|---|---|---|---|---|
| pre-task | 120 | 256 | 0% | 0% |
| RDHC | 5484 | 404 | 34% | **36%** |
| IO1I | 422 | 164 | 33% | **46%** |
| XP4I | 2342 | 218 | 13% | 14% |
| XP3I | 2300 | 260 | 12% | 13% |
| XP2I | 2310 | 250 | 31% | **34%** |
| XP1I | 2358 | 206 | 37% | **40%** |
| self-test | 5292 | 6 | 85% | 85% |
| RTOS init | 2352 | 208 | 70% | **76%** |
| **total** | **22980** | — | 43-44% | **47%** |

**Instruction coverage is 47%, not 44%.** IO1I moves most (33% → 46%) because a
quarter of its region is data. The direction of the error was always the same —
understating — so no conclusion about *which* configuration covers more is
affected, but the absolute numbers were low.

### The 0% "pre-task" region is kernel-panic and kernel-hook code

It is not 376 bytes of unreached code. It is **120 bytes of instructions and 256
bytes of zero padding**, and every one of the three routines has a reason not to run:

- **`$F04500`, panel issuer copy 1** (50 bytes) is called from **`$F001A4`** and its
  address is stored at `$F001A6` — that is the hand-placed FPS stub at `$F001A0`
  inside the RMS68K kernel that issues `PCMD_KERNEL_FATAL` (`$2B2`) and hangs. So
  this copy exists *only* to serve the kernel's fatal-error path. **Correctly dead in
  a healthy boot** — reaching it would mean the kernel had panicked.
- **`$F04488`** (28 bytes), a `TRAP #0` directive-`$18` helper, is called from
  `$F043E8` in the kernel. Reachable, just not exercised.
- **`$F044A2-$F044DC`** (42 bytes) is one routine, and its address is stored as a
  **function pointer at `$F03FDC` and `$F040EC`** — an RTOS hook, not called
  directly. It tests bit 14 of `$0C34`, optionally saves SR and calls `$F01688`,
  then **walks a linked list calling each node's handler at `+$1E` and following
  `+$8` to the next**, stopping when one returns carry set, and finally jumps to
  `$F008B6`:

```
$F044C0  movea.l $1e(a5),a1     ; node's handler
$F044C4  move.l  a5,-(a7)
$F044C6  jsr     (a1)
$F044CA  bcs     -> done        ; handled
$F044CC  move.l  $8(a5),d0      ; next node
$F044D0  beq     -> done
$F044D2  movea.l d0,a5
$F044D4  bra     $F044C0
```

That is a **device-driver dispatch chain**: descriptors linked at `+$8` with an
entry point at `+$1E`, polled in order until one claims the event. For emulation it
is the path by which a device interrupt would reach a driver — and the reason it
never runs is that this configuration registers no drivers, which is consistent
with `!IDV` holding only the six task ISRs and `!IOV` being empty.

*So "pre-task 0%" was never a driving gap. Two of the three routines are unreachable
by design in a working machine, and the third needs a registered driver that this
firmware configuration does not create.*

### `FPS3K_CHCMD=C801` was *suppressing* XP coverage, and `FPS3K_POKE` never booted

Two hook defects found while trying to drive the XP tasks, both of the shape this
document keeps cataloguing.

#### `FPS3K_POKE` had the ungated-injection bug that `FPS3K_DMA10AA` was fixed for

`FPS3K_POKE=10A0=0002` ended the boot at **`F098FC`** — the address-uniqueness RAM
test — instead of `F00FCC`, the RTOS idle loop. The power-on diagnostics walk all of
RAM writing a pattern and reading it back, so **any** location forced to read a
constant fails a pattern test. Every downstream measurement read as "the hook had no
effect" when the machine had never booted.

This is precisely the defect fixed for `FPS3K_DMA10AA` and left in place for
`FPS3K_POKE`. It is now gated on the same boot-complete signal (vector `$128` =
`F05DD6`), with `FPS3K_POKE_FROM_RESET=1` to reproduce the old behaviour. *A fix
applied to one injection hook should have been applied to every one of them; there
was no reason `$10AA` would be special.*

With the gate, `final PC=F00FCC` and **`$F05652` executes — RDHC's ASQ post to
`HXP1` runs for the first time.**

#### But the ASQ post does not wake the XP task; the channel interrupt does

| configuration | XP1I | RDHC |
|---|---|---|
| `XPIRQ=1` alone | **34.4%** | 0.9% |
| `XPIRQ=1` + `CHCMD=C801` | 16.7% | 3.3% |
| `XPIRQ=6,1` alone | 10.3% | 3.3% |
| `XPIRQ=6,1` + `RESP=$94` | 34.4% | 4.9% |
| + command 1 operation `$14` | 34.4% | 19.8% |
| + the ASQ post | 34.4% | 18.5% |

XP1I reaches 34.4% from **its own channel interrupt alone**. Adding RDHC's ASQ post
changes nothing. So the hand-off exists in the firmware and now executes, but it is
not what releases the XP task — that is the channel BIM interrupt, as before.

Note also that `XPIRQ=6,1` *without* a valid response code gives only 10.3%: raising
BIM0 ch0 with no code deadlocks the responder and starves the XP task. The level-6
deadlock does not just block RDHC, it steals time from everything.

#### `FPS3K_CHCMD=C801` halves XP1I and XP2I, and it is in the documented config

| task | own IRQ alone | + `CHCMD=C801` | all four IRQs | all four + `CHCMD` |
|---|---|---|---|---|
| XP1I | **34.4%** | 16.7% | 10.3% | 10.3% |
| XP2I | **31.4%** | 13.7% | 7.3% | 7.3% |
| XP3I | 12.1% | 12.1% | 7.0% | 7.0% |
| XP4I | 12.6% | 12.6% | 12.6% | 12.6% |

**`FPS3K_CHCMD=C801` cuts XP1I and XP2I coverage roughly in half**, and it is part of
the configuration this project recorded as the XP-driven best case — the one that
produced the "XP tasks 18-20% each" figure. Driving one channel with no `CHCMD` at
all is strictly better for every task.

The mechanism is a fact already in this document: `$C801` sets bits 15, 14 **and
11**, and *"XP1I/2/3 test command bits 15, 14, 11; XP4I only 15, 14."* With bit 11
set, XP1I and XP2I take the short `$8000`/`$1B` branch and finish; with it clear they
run the longer path. XP4I never tests bit 11, so it is unaffected — exactly the
asymmetry measured. *The bit that was added to unblock the channel transaction also
short-circuits the code it was meant to expose.*

**Driving all four channels together is worse than driving one**, dropping every task
to 7-12%. The four tasks contend, and a configuration meant to exercise all of them
exercises each less.

XP3I is the outlier: 12.1% regardless of `CHCMD`, despite testing bit 11 like its
siblings. Unexplained.

#### Coverage now

| region | bytes | earlier | now |
|---|---|---|---|
| RDHC | 5888 | 1% | **34%** |
| IO1I | 586 | 16% | 33% |
| XP1I | 2564 | 9% | **38%** |
| XP2I | 2560 | 6% | **31%** |
| XP3I | 2560 | 5% | 12% |
| XP4I | 2560 | 6% | 13% |
| self-test | 5298 | 85% | 85% |
| RTOS init | 2560 | 70% | 70% |
| pre-task | 376 | 0% | **0%** |
| **executable total** | **24952** | 25% | **44%** |

**44% of executable code**, union over 16 configurations.

### Coverage after the RDHC work: 38% of executable code

Union over 11 configurations (default, scripted operations, XP-driven, IO1I-driven,
RDHC commands 2/3/4, and command 1 at operations `$02`/`$03`/`$0A`/`$14`), measured
against decoded instruction bytes:

| region | bytes | before this work | now |
|---|---|---|---|
| pre-task `$F04488-$F045FF` | 376 | 0% | 0% |
| **RDHC** | 5888 | **1%** | **34%** |
| IO1I | 586 | 16% | 33% |
| XP4I | 2560 | 6% | 13% |
| XP1I / XP2I / XP3I | ~7700 | 5-9% | 7-10% |
| self-test | 5298 | 85% | 85% |
| RTOS init | 2560 | 70% | 70% |
| **executable total** | **24952** | — | **38%** |

**RDHC goes from 1% to 34%** — from the least-exercised region to better than the XP
tasks. The figure excludes `$F0A600-$F0FFFF`, which is tables and data, not code.

Two things this leaves pointing forward. The **XP tasks are now the laggards at
7-13%**, and command 1's ASQ post (`'HXP0' + channel` → `$F05652`) is the obvious
lever: RDHC hands work to `HXP1`-`HXP4` by name, and each XP task blocks on
directive `$13` exactly as RDHC did. The same three-part unlock probably applies.
And **`$F04488-$F045FF` is still 0%** — 376 bytes of pre-task code that no
configuration reaches at all.

### Executing all 42 operation codes confirms the static census 13 for 13

Sweeping command 1's operation code over `$00`-`$29`, one run each, counting which
primitive fires and how much of RDHC executes:

| operation codes | primitives fired | RDHC bytes |
|---|---|---|
| `$00 $0B $0C $11 $12 $13 $15 $20 $21 $26 $27 $28 $29` | **none** | 488 (8%) — identical for all 13 |
| `$01 $16 $17 $19 $1B $1F $22 $24` | `POLL` ×1468 | 642 (11%) |
| `$08 $09 $18 $1A $1C $1D $1E $23 $25` | `BLK_XFR` ×1468 | 622 (11%) |
| `$02 $04 $06 $0D $0F` | `POLL` + `D1_SEND` | 788-832 (13-14%) |
| `$03 $05 $07 $0E $10` | `BLK_XFR` + `D1_SEND` | 768 (13%) |
| `$0A` | `POLL` ×**1** | 540 (9%) |
| `$14` | `D2_FIN` + `POLL` + `D1_SEND`, ×**1** each | **1070 (18%)** |

**Every one of the 13 codes predicted to be a bare `rts` fires no primitive and
produces byte-identical coverage.** That is the static decode of the jump table
confirmed by execution, 13 for 13, and it is the kind of check the table's
handler-count corrections needed — the old census would have predicted 8 of these
to do something.

The live slots each fire exactly the primitive the table assigns them. Several fire
*two*, because `$F05468`'s caller walks successive descriptors at `$14(a6)` stride,
so a `D1_SEND` slot is reached as part of a sequence that also polls or block-moves.

**Two operations terminate; the other 27 do not.** `$0A` and `$14` fire their
primitives **once**, while every other live code fires **1468 times** — once per
re-raised interrupt, never completing. `$14` is the documented finalize code, and
this makes `$0A` the *other* terminating operation, which nothing in the static
table distinguishes: index `$0A` is an ordinary `POLL` slot. Whatever ends the
sequence is inside `POLL`'s own logic and is reached for `$0A` but not for `$01`,
`$16`, `$17`, `$19`, `$1B`, `$1F`, `$22` or `$24`, which share the same handler.
*That is a real open question the sweep exposes, and it is invisible to static
reading.*

**Union over all 42 operation codes: 1326 / 5888 bytes = 23% of RDHC**, from 1% at
baseline.

### RDHC's 42-slot table executes, and 13 of its slots are `rts`

Command 1's parameter block is `{command, operation, channel}`:

```
$F05322  move.l  (a0)+,d1      ; +$00 command number 1..4
$F05370  movea.l a0,a6         ; a6 now points at +$04
$F05372  move.l  $4(a6),d4     ; +$08 channel, defaulting to $E62 if zero
$F053C4  cmpi.l  #$14,(a6)     ; +$04 OPERATION CODE -- $14 is the interesting one
```

With `FPS3K_CHASSIS_CMD=1,14,1` — command 1, operation `$14`, channel 1 — RDHC
reaches `PanelSendAndWait` and **`$F0572C` executes.** Three of the four primitives
fire in one command: `D1_SEND` (`$F058B2`), `POLL` (`$F05A12`), `D2_FIN`
(`$F05738`).

**This retracts a claim in this document.** It said of the five copies of the
dispatch subsystem: *"RDHC's is the only one that never executes, because `$F0572C`
is unreached."* It is reached, by RDHC's own command 1, and the reason it looked
unreachable is the chain of blockers now cleared — the `$13` wait, the missing
MODE0 code, and the absent command record.

#### Corrected census of the 42 slots

The entries are `4EFA` `jmp d16(pc)` pairs, not addresses. Decoding all 42:

| handler | slots | indices |
|---|---|---|
| `POLL` `$F05A12` | **9** | `$01 $0A $16 $17 $19 $1B $1F $22 $24` |
| `D1_SEND` `$F058B2` | **10** | `$02`-`$07`, `$0D`-`$10` |
| `BLK_XFR` `$F05B0E` | **9** | `$08 $09 $18 $1A $1C $1D $1E $23 $25` |
| `D2_FIN` `$F05738` | **1** | `$14` |
| **`rts` — no-op** | **13** | `$00 $0B $0C $11 $12 $13 $15 $20 $21 $26 $27 $28 $29` |

**Two corrections and one omission.** This document has recorded "POLL (12 codes)"
and "BLK_XFR (11 codes)" — both wrong; they are 9 and 9. And it said "only 4
distinct handlers exist" while its own counts summed to 34 of 42, leaving 8
unexplained. There is a **fifth case**: `4E75`, a bare `rts`. **13 of the 42
operation codes are unimplemented no-ops**, including index `$00`. `9+10+9+1+13 =
42` exactly.

*That changes how the table should be read. It is not a dense 42-operation
instruction set; it is a sparse one with 29 live operations and 13 reserved slots
that return immediately — the shape of a table sized for a family of machines, of
which this configuration implements two thirds.*

Operation `$14` selects index `$0F`, which is `D1_SEND` — and the trace shows
`POLL` and `D2_FIN` running too, because `$F05468`'s caller walks successive
descriptors at `$14(a6)` stride. So one command drives a *sequence* of operations
ending in the single finalize code `$14`.

#### Command 1 also posts to the target task's ASQ

```
$F053AE  btst.b  #$1,$10A1(a1)      ; per-channel flag, (ch-1)*2
$F053B4  beq     -> skip
$F053B6  move.l  #$48585030,d1      ; 'HXP0'
$F053BC  add.b   d4,d1              ;   -> 'HXP1'..'HXP4'
$F053BE  jsr     $F05652            ; post by name
```

So command 1 optionally hands the work to the target XP task's **host-side queue**,
by name. That is the inter-task path between RDHC and the XP controllers, and it
uses exactly the `H`+name convention already recorded for the ASQ registry.

#### The firmware derives its own channel-window formula

```
$F053E8  d3 = (ch + 1) << 5
$F053EE  d3 += $FF000E        ; a0 = the channel COMMAND port
$F053FC  a1 = a0 - 6          ; a1 = the channel DATA pair
```

`ch = 1` gives `$FF004E` and `$FF0048`; `ch = 2` gives `$FF006E` and `$FF0068`.
**That is the `$FF0040 + $20*N` window computed by the firmware itself**, and it
independently confirms the corrected per-channel table — `+$0E` is the command
port, `+$08` the data pair — which this project had to reconstruct from usage
patterns. `a3` comes from the `$F046E0` BIM CR table plus `$FF0000`, the register
`PanelSendAndWait` mutes with `$4F` and restores with `$5F`.

#### Coverage

| configuration | RDHC instructions | decoded bytes |
|---|---|---|
| `RESP=$94` alone | 67 / 1653 (4%) | 286 (5%) |
| **+ command 1, operation `$14`** | **314 / 1653 (19%)** | **1070 (18%)** |

One command record more than quadruples RDHC's coverage — more than every other
configuration combined.

### END TO END: `CPLOAD` stages microcode through the firmware, no bypass

With RDHC awake and command 4 reachable, the whole reason this ROM exists now runs:

```
FPS3K_RESP=0x94 FPS3K_XPIRQ=6 FPS3K_CHASSIS_CMD=4,8,53310004,0000DEAD,BEEF0000

$10000: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 DE AD BE EF 00 00 ...
        ^-- $10000                                       ^-- $10010
staging buffer: 4 nonzero bytes, first at $10010
```

`DE AD BE EF` at **exactly `$10010`**, and nothing else in the 55 KB buffer
touched. The full chain, every step the firmware's own:

1. chassis presents response `$94` in MODE0 **and** raises BIM0 ch0
2. `$F04930` latches it, `$F0495C` dispatches the bit-7 arm
3. the ISR returns via `$F050F8`, releasing RDHC's directive-`$13` wait
4. `$F04740` sees bit 7, `$F048D8` sees `$14` → "command waiting"
5. `$F052F8` forces MODE2 to page 0 and fetches the record from `$400000`
6. `$F05322` reads command **4** → `$F05502`, `CPLOAD`
7. `$F05522` matches `$5331` = `'S1'` → `$F055A2`
8. `a1 = $10`, accumulate the address word, `a1 += $10000`, bounds-check,
   `move.w d2,(a1)+`

**No monitor `L` command, no hook writing into the buffer, no bypass.**

#### The S1 handler is binary, and it confirms the offset arithmetic independently

```
$F055A2  movea.l #$10,a1            ; the "+$10" seed
$F055A8  move.w  (a0)+,d2           ; address word
$F055B4  lsl.l   d5,d2              ; d5 is the shift: 16 for a high half, 0 for low
$F055B6  adda.l  d2,a1
$F055BA  subi.b  #$10,d5            ; next half
$F055C2  bge     $F055A8
$F055C4  adda.l  #$10000,a1         ; the staging base
$F055CA  move.w  (a0)+,d2           ; data word
$F055CC  cmpa.l  #$10000,a1 / blt reject
$F055D4  cmpa.l  #$1FFFF,a1 / bgt reject   -> panel $25A
$F055DC  move.w  d2,(a1)+
```

So there are **two S-record data paths**, `$F051A2` (the SLC/panel one) and
`$F055A2` (command 4's), and they implement the same `$10 + addr + $10000`
arithmetic and the same `$10000-$1FFFF` bound. That the two agree is a stronger
check on the offset rule than either alone. Note `d5` is the shift count, set to 0
for S1 (one 16-bit address word) — which is how record type selects address width.

*Also note the byte the ROM will happily accept: the bound is `$10000-$1FFFF`, the
full 64 KB, but the live TCBs start at `$1E900`. A record addressed past `$1E8F0`
passes the firmware's own check and corrupts RTOS state. That is a real hazard in
the firmware, not in our model.*

#### A trap in reading the result

With a byte count larger than the data supplied, the parser reads past the record
and stores whatever the chassis window returns — `AA AA` in these runs, the
self-test's pattern residue. It looks like data. Only the first case above has
count and payload matching, which is why it is the one asserted.

### RDHC UNBLOCKED: the code must be presented in MODE0 *with* the interrupt

The blocker described below turned out to be a **modelling defect, not a firmware
one**, and it is now fixed. `$F04930` latches MODE0 into `$E86` and dispatches on
its low byte. The model had two separate mechanisms that never met:

- the **arm path** (`versabus.c:929`) put an `FPS3K_RESP` code in MODE0, but in a
  clean boot nothing ever completes a panel command in a way that fires the ISR —
  `$F04930` executed **0** times through it;
- **`FPS3K_XPIRQ=6`** raised BIM0 ch0 directly and fired the ISR, but **never
  touched MODE0** — so `$E86` latched whatever MODE0 happened to hold.

A real chassis does both in one action: it presents the code *and* raises the
interrupt. `FPS3K_XPIRQ` now stamps the `FPS3K_RESP` code into MODE0 before
asserting BIM0 ch0. The effect is immediate:

| PC | meaning | before | `RESP=$0B` | `RESP=$94` |
|---|---|---|---|---|
| `$F04930` | ISR entry | 1 | 1467 | 1463 |
| `$F04A6E` | bit-7-clear dispatcher | 1 | 1467 | 0 |
| `$F0495C` | bit-7-set dispatcher | **0** | 0 | **1463** |
| `$F050F8` | ISR exit — the waker | **0** | **1467** | **1463** |
| `$F04740` | first instruction after the `$13` wait | **0** | **1467** | **1** |
| `$F048D8` | the command arm | **0** | 0 | **1** |

**RDHC leaves its blocking wait for the first time in this project's history**, the
bit-7 dispatcher `$F0495C` executes for the first time, and with `$94` the command
arm is taken.

*Note which claim this vindicates and which it corrects.* The deadlock analysis was
right about the mechanism — with the default code `$14` the ISR still picks
operation `$4`, fails validation, and spins in the panel issuer's `bra .`; that
check still passes. What was wrong was concluding the firmware had no escape: it
does, and the escape is simply *a code that selects an operation which validates*.
The model could never present one.

#### All four RDHC commands now execute, including CPLOAD

The command record cannot be staged in `chassis_mem` before the run. **Self-test
phase `$29` at `$F096AC` walks and writes 131,148 chassis addresses**, so anything
placed there is overwritten long before RDHC looks — the first attempt did exactly
that and RDHC read a command number of 0 while the hook cheerfully reported the
record was in place. `FPS3K_CHASSIS_CMD` now serves the record from a private
buffer and only once vector `$128` holds `F05DD6`, which leaves the self-test's own
write-then-read-back patterns intact.

| configuration | RDHC instructions | decoded bytes | reached |
|---|---|---|---|
| baseline | 16 / 1653 (1%) | 52 (1%) | — |
| `RESP=$94` only | 67 (4%) | 286 (5%) | dispatcher |
| + command 1 | 81 (5%) | 340 (6%) | `$F05370` |
| + command 2 | 94 (6%) | 372 (6%) | `$F054A2` |
| + command 3 | 84 (5%) | 348 (6%) | `$F054E8` |
| + **command 4** | **102 (6%)** | **408 (7%)** | `$F05502` **and the S-record type dispatch `$F05522`** |

**`CPLOAD` executes.** The path this ROM exists to implement now runs from a
command record through to the S-record parser, driven entirely by the firmware's
own mechanisms.

#### Coverage after the unlock

Union over five configurations (default, RDHC-driven, XP-driven, IO1I-driven,
scripted operations), measured against decoded instruction bytes:

| region | bytes | default | union |
|---|---|---|---|
| RDHC | 5888 | 1% | **15%** |
| IO1I | 586 | 16% | 33% |
| XP4I | 2560 | 6% | 13% |
| XP1I…XP3I | ~7700 | 5-9% | 7-10% |
| self-test | 5298 | 85% | 85% |
| RTOS init | 2560 | 70% | 70% |

**RDHC 1% → 15%**, and excluding the 23 KB of tables and data at `$F0A600+` the
executable total is **33%**. Two paths cover different code — the scripted
operations reach 10% of RDHC and the command-record path 7%, and they conflict by
design (`FPS3K_SEQ` overrides `FPS3K_RESP`), so the union is the honest figure.

### What blocks RDHC is one instruction: the directive-`$13` wait at `$F0473E`

RDHC's main loop is four instructions long:

```
$F0473C  moveq   #$13,d0
$F0473E  trap    #1              ; BLOCKING WAIT
$F04740  btst.b  #$7,$e87        ; bit 7 of the latched MODE0 low byte
$F04748  bne.w   $F048D8         ;   set   -> the command arm
$F0474C  move.w  $e86,d0         ;   clear -> the 4-bit sub-dispatch
$F04752  andi.w  #$f,d0
```

Measured over a full boot: **`$F0473C` executes exactly once and `$F04740` never
executes at all.** RDHC enters its blocking wait and never leaves it. Everything
this document has just decoded — the four-command host interface, `CPLOAD`, the
42-operation table, the whole 5,888-byte region — sits behind that single `trap #1`.

*That is the real reason RDHC's coverage has been stuck near zero through every
configuration this project has tried. It is not a missing register value or a
missing bit; it is one RTOS wait with no waker.*

#### The command arm, and two labels that are wrong

Bit 7 set takes RDHC to `$F048D8`, which tests `$E86 & $1F`:

- **`$14` → `jsr $F052F8`**, which fetches and executes a command record
- **`$13` → `moveq #$12,d0 / lea $F0469E,a0 / trap #1`**, RDHC's own directive `$12`

So `$14` is the chassis's "a command record is waiting" code, and the full trigger
byte is **`$94`** — bit 7 for the arm, `$14` for the reason.

Two labels in the disassembly are misnomers and should be read with care:

- **`TCBRDHC_ErrorPath` at `$F048D8` is not an error path.** It is the bit-7
  command arm — the most important arm in the task.
- **`ChannelConfigDispatch` at `$F050F8` is not a dispatcher.** It is the **ISR
  exit stub**: `movem.l (a7)+,d0-d7/a0-a7 / move #$C,ccr / trap #1`. It is the same
  address as operation `$F` in the 16-entry table, so every handler's `bra.w
  ChannelConfigDispatch` is a return-from-interrupt, and operation `$F` is simply
  "return immediately".

#### RDHC reads its command record from chassis memory, not SBC RAM

```
$F052F8  clr.l    $0E5C
$F05304  move.w   #$0,$0E74
$F0530C  movea.l  #$FF0000,a5
$F05312  move.w   $210(a5),-(a7)   ; save MODE2
$F05316  move.w   #$0,$210(a5)     ; select page 0
$F0531C  movea.l  #$400000,a0      ; the CHASSIS MEMORY WINDOW
$F05322  move.l   (a0)+,d1         ; command number
```

The record lives in **chassis memory at `$400000`, page 0** — consistent with
operation `$3`'s paged read, and it means the host writes command records into
shared chassis memory rather than poking SBC registers. A new hook,
`FPS3K_CHASSIS_CMD=<hex longwords>`, places a record there; it loads correctly and
reports `[chassis-cmd] N longwords placed at $400000`, but nothing consumes it yet
for the reason below.

#### The waker is RDHC's own ISR exit, and it deadlocks before reaching it

The `trap #1` at `$F050FC` inside the exit stub is what would release the `$13`
wait. Measured across every configuration tried — `FPS3K_XPIRQ=6` (BIM0 ch0),
`FPS3K_RESP` at `$0B`/`$07`/`$0E`/`$0F`/`$14`/`$94`, with and without a command
record:

| PC | meaning | executions |
|---|---|---|
| `$F04930` | RDHC's ISR entry | **1** |
| `$F04A6E` | bit-7-clear dispatcher | **1** |
| `$F0495C` | bit-7-set dispatcher | **0** |
| `$F050F8` | ISR exit stub — the waker | **0** |
| `$F04740` | first instruction after the wait | **0** |

The ISR enters once, dispatches once, and never returns. The mechanism is the
deadlock this document already recorded for TCBIO1I, now shown for RDHC: the
operation it selects fails its validation, issues a panel command through
`PanelIOConfigure`, and **that issuer ends in `bra .`** — one of the eight
byte-identical copies, each followed by its own spin. Escaping needs the responder
to rewrite the saved PC, but we are already *inside* the responder at level 6, so
no further level-6 interrupt can preempt it.

**So RDHC is blocked by the same self-programmed deadlock as TCBIO1I, one level
further out.** The firmware writes both interrupt levels itself, so this is not a
board-strap question.

#### Two emulator gaps, now precisely located

1. **`FPS3K_RESP` does not reach `$E86` on the BIM-interrupt path.** With
   `FPS3K_RESP=0x94` the bit-7 dispatcher `$F0495C` still never runs, and no
   response value makes `$F050F8` run. The response-injection path and the
   BIM-interrupt path are not connected in the model — the arm at `versabus.c:628`
   uses a hard-coded `0x14` while the `FPS3K_RESP` arm at `:929` sits behind a
   different condition.
2. **Nothing satisfies a directive-`$13` wait.** Even with a correct response, the
   ISR must reach `$F050F8`; that needs an operation whose validation succeeds,
   which needs `$E60` in `1..$105E`, which is set by command 1's body — which is
   itself behind the wait. The cycle has to be broken from outside, either by
   modelling the panel-issuer spin escape properly or by injecting the wake.

*Both are concrete and testable, which is a better position than "the chassis is a
black box". The gap has gone from a whole protocol to two named mechanisms.*

### RDHC's host interface is four commands, and command 4 is CPLOAD

`$F05320` is RDHC's command dispatcher, and it is tiny:

```
$F05322  move.l  (a0)+,d1        ; command number = FIRST LONGWORD of the block
$F05324  cmpi.l  #$0,d1
$F0532A  ble     -> reject
$F0532C  cmpi.l  #$4,d1
$F05332  ble     -> ok
$F05334  move.w  #$259,d0        ; out of range -> panel $259
$F05338  jsr     PanelIOConfigure
$F0533E  jmp     $F05678
$F05344  andi.w  #$7,d1
$F05348  subq.w  #1,d1
$F0534A  mulu    #$6,d1
$F0534E  lea     $F05358,a1
$F05354  jmp     (a1,d1.w)       ; 4-entry table of jmp abs.l
```

**Four commands, numbered 1-4.** The command number is not passed in a register by
the caller — it is the **first longword of the parameter block** in `a0`, fetched
with `move.l (a0)+,d1`, so each command's own arguments follow it in the same
block. That makes a command a self-contained record, which is what a host would
write into shared memory.

| cmd | entry | what it is |
|---|---|---|
| 1 | `$F05370` | **attach/configure a channel** — channel from `$4(a0)`, defaulting to `$E62`, validated `1 <= ch <= $105E` |
| 2 | `$F054A2` | **read or write the 16-longword parameter area at `$101E`** |
| 3 | `$F054E8` | **load `d2` longwords from the block into `$E8A`** onward |
| 4 | `$F05502` | **CPLOAD — the S-record loader** |

Command 2 is a bidirectional block move: `d1` is a direction flag, then an offset
and a length, `a1 = $101E + offset*4`, bounds-checked `offset + len <= $10` with
panel `$25B` on overflow, and `exg.l a1,a0` when `d1` is nonzero — so *one* command
both reads and writes the channel parameter area, direction chosen by the caller.

Command 4 sets the count at `$E64`, sets bit 4 of `$FF0216`, and then dispatches on
a 16-bit literal:

```
$F05522  cmpi.w  #$5330,d1   ; 'S0' -> jsr $F05594
$F05530  cmpi.w  #$5331,d1   ; 'S1' -> jsr $F055A2
$F05542  cmpi.w  #$5332,d1   ; 'S2'
$F05548  cmpi.w  #$5333,d1   ; 'S3'
```

**That is the S-record type dispatch, and it makes command 4 the `CPLOAD`
primitive** — the top-level entry point of the whole microcode-upload path this
ROM exists to implement. The path can now be named end to end: host issues RDHC
**command 4** with a count and S-record text → `$F05502` dispatches by record type
→ `SRecordDataHandler` at `$F051A2` applies the `$10 + addr + $10000` offset →
staging buffer → chassis command **op `$0`** arms the transfer.

#### Correction: `PanelStatusDispatch` is indexed by an operation selector, not a chassis response

This document has described the 42-slot table's index as "a 6-bit **response code**
supplied by the IRQ handler that completes a panel-command `bra .` spin-wait", and
read the subsystem as "a streaming-DMA state machine: chassis feeds SBC a stream of
`d0` codes". **That is wrong, and it is why sweeping 42 response values never
reached `$F0572C`.**

`$F0572C` is the *tail of `PanelSendAndWait`* (`$F056BA`). The routine mutes its
BIM with `$4F`, writes `$8004` REQUEST-TRANSFER, polls for done with a 1000-tick
countdown, and if the error bit is clear falls into `lsl.w #2,d0 / jmp (a4,d0.w)`
with **`d0` unchanged from entry**. So the index is the caller's argument. And the
callers take it from a command descriptor:

```
$F05468  jsr     PanelSendAndWait
$F0546E  move.l  (a6),d0          ; operation code from the descriptor
$F05470  cmpi.w  #$14,d0          ; ... compared against D2_FIN
```

with `a6 = a0` on entry at `$F05370` — an RTOS-style parameter block, fields at
`+$00` (operation), `+$04`, `+$08`, `+$10`, and the next descriptor at `+$14`.

So the subsystem is the **SBC's own operation dispatcher**: 42 operations, each
implemented by one of the four transfer primitives (`POLL`, `D1_SEND`, `BLK_XFR`,
`D2_FIN`), selected by an operation code the *caller* supplies. The earlier
"resolved — the different caller is the XP channel ISR" was structurally right
(`$F07F84` is the same tail in the XP copy, at offset `$2858`) but the semantics
stayed wrong: nothing about the index comes from the chassis.

*This retires the "streaming-DMA state machine, chassis feeds codes" reading. The
42 slots are an internal operation table, and the 42-value response sweep that
"failed to reach" the site was testing the wrong input.*

#### Driving the command language lifts RDHC from 1% to 8%

Measured against the decoded instructions in RDHC's TDTI region `$F04600-$F05CFF`:

| configuration | instructions | decoded bytes |
|---|---|---|
| baseline, no hooks | 16 / 1653 (1%) | 52 / 5888 (1%) |
| all 16 chassis operations | **139 / 1653 (8%)** | **618 / 5888 (10%)** |

An 8.7× increase from issuing the operations rather than guessing response codes.
Bit-7 codes (`$80`-`$94`, the `$F0495C` dispatcher) add nothing on top — consistent
with the correction above, since that dispatcher is not the route to the 42-slot
table either.

What is still missing is the *caller* of `$F05320`: RDHC's four commands need a
command number in `d1` and a parameter block in `a0`, and nothing in the emulator
supplies either. That, not a response code, is the conversation RDHC is waiting
for.

### RESOLVED: the chassis command language is 16 operations, and it can write SBC RAM

The `F04930` responder indexes `(code & $F) << 2` into a 16-entry jump table at
`$F05102`. This document has carried that table with **2 of 16 targets confirmed
and 14 unknown**, and called the chassis "a black box". All sixteen are now
decoded, and the byte is not an opaque index — it is a **structured command word**.

#### The command byte is the low byte of `XLTR_MODE0`

`F04930` reads MODE0, stores the word at `$E86`, and every handler then tests bits
of `$E87` — the *low byte* of that word. So the chassis presents its command in
MODE0, and the byte decodes as:

| bits | meaning |
|---|---|
| 0-3 | **operation** — index into the 16-entry table |
| 4 | **auto-increment** the index register `$E7A` after the access |
| 5 | **direction** — 0 = chassis writes / SBC stores, 1 = SBC reads and returns |
| 6 | **half select** — which 16-bit half of a 32-bit parameter |
| 7 | selects the *other* dispatcher (`$F0495C`, the 0..`$14` range-checked one) |

This is what the previously-recorded codes were all along: `$01` is operation 1
with bit 6 clear (address **low**), `$41` is operation 1 with bit 6 set (address
**high**), `$02`/`$42` the same pair for the count, `$00` operation 0. The "bit 6
of the code selects the half" rule recorded earlier was correct and is now
explained — it is a field of the command byte, tested by the handlers themselves.

#### The sixteen operations

| op | handler | what it does |
|---|---|---|
| `$0` | `$F04A84` | **validate/arm transfer** — read CHANNEL_SELECT, accept `0..$10` or `$28`, else panel `$259` |
| `$1` | `$F04CF2` | **set transfer address** half into `$E58`/`$E5A` |
| `$2` | `$F04D20` | **set transfer count** half into `$E64`/`$E66` |
| `$3` | `$F04D4E` | **read/write CHASSIS memory** through the `$400000` window (below) |
| `$4` | `$F04E3A` | validate the channel in `$E60` against `$105E`, else `$25C` |
| `$5` | `$F04EE4` | **select channel** — validate CHANNEL_SELECT against `$105E`, then **store it into `$E60`/`$E62`** (`$F04F16`/`$F04F1C`); this is `XPSEL` |
| `$6` | `$F04F30` | **read/write SBC RAM at the address in `$E58`** (below) |
| `$7` | `$F04F3A` | **mask BIM0 ch0** — `bclr #4` (IRE) on `$FF0230`, clear `$E74` |
| `$8` | `$F04F52` | if MODE1 bit 14 set and CHANNEL_SELECT is 0, panel `$258` (CH1 reset) |
| `$9` | `$F04FA0` | set a third parameter `$E68`/`$E6A` from CHANNEL_SELECT |
| `$A` | `$F04FBA` | **read the per-channel word array** — validate `$E7A` in `0..$C`, return `$1064 + $E7A*2`, auto-increment if bit 4 |
| `$B` | `$F05002` | **return the staging-buffer base** — `$10000 + $10` = `$10010` |
| `$C` | `$F0502C` | **read the longword array at `$1020`**, indexed `$E7A*4` |
| `$D` | `$F05092` | validate CHANNEL_SELECT in `0..$F`, else `$25D` |
| `$E` | `$F050CA` | **clear busy** — if CHANNEL_SELECT is 0, `bclr #7` on MODE1 |
| `$F` | `$F050F8` | **end of conversation** — `movem.l (a7)+,d0-d7/a0-a7`, `move #$C,ccr`, `trap #1` |

Two of these land squarely on things the project already had names for but no
mechanism. Operation `$E` clearing MODE1 bit 7 is the **`XPRUN` clear-busy**
primitive. Operation `$B` returning `$10010` is the **S-record staging base** — the
`$10 + addr + $10000` arithmetic in `SRecordDataHandler` — so the chassis can *ask*
where to put microcode rather than being told.

And operation `$F` is `$F050F8`, whose second instruction sits at **`$F050FC`** —
exactly the "ISR exit" address `!IDV` gives for RDHC. Two structures and a jump
table, built by unrelated code, agreeing on one address.

#### Operation `$3`: the SBC can read chassis memory through a paged window

```
$F04D6A  move.l  $e58,d1
$F04D70  moveq   #$14,d2
$F04D72  lsr.l   d2,d1
$F04D74  move.w  d1,$210(a0)     ; page = addr >> 20  -> MODE2
$F04D78  move.l  $e58,d1
$F04D7E  andi.l  #$fffff,d1      ; offset = addr & $FFFFF
$F04D84  lsl.l   #$2,d1          ;        scaled by 4 (longwords)
$F04D96  move.l  (a1,d1.l),$e70  ; read through the $400000 window
```

**`XLTR_MODE2` at `$FF0210` is the page register for the `$400000` chassis
window**, and the address decode is `page = addr >> 20`, `offset = (addr &
$FFFFF) << 2`. This document has recorded `$400000` as "the chassis window" and
MODE2 as "cleared during channel setup"; MODE2's actual job is paging, and the
window is longword-addressed. That is the SBC's read path into **System Common
Memory** — the one direction of the data path that had no mechanism at all.

#### Operation `$6`: this is how `$10AA` gets written, and no bus mastering is needed

```
$F04F30  movea.l $e58,a1            ; a1 = the address set by operation $1
$F04EA0  ... clear bit 7 of $216 ...
$F04EAE  btst.b  #$5,$e87
$F04EB8  move.w  (a1),$e74          ; bit 5 set: READ SBC RAM, return it
$F04EC0  move.w  $204(a0),(a1)      ; bit 5 clear: WRITE CHANNEL_SELECT to SBC RAM
```

The chassis sets an address with operation `$1` and then issues operation `$6`, and
**the SBC's own CPU performs the write**. Demonstrated:

```
FPS3K_SEQ="01:10AA,06:0002"
  [RAMWATCH] write 0010AA <- 00 from PC=F04EC0
  [RAMWATCH] write 0010AB <- 02 from PC=F04EC0
```

**This supersedes the bus-master conclusion.** This document argued that because
`$F053E2` is arithmetically barred from reaching `$10AA` and a write watchpoint
caught only zeros, "a nonzero `$10AA` must come from off-board — so the
chassis-as-bus-master reading is the only candidate." The premises were right and
the conclusion was too narrow: there is a second route, it needs no unmodelled
hardware capability, it uses only documented registers, and it is *the firmware's
own code*. The watchpoints missed it for the usual reason — RDHC's dispatcher was
never driven with operation `$6`, so the instrument could not fire.

Two refinements come with it. `$F05E12` reads `$10AA` as a **longword** and
compares against 2, while operation `$6` writes 16 bits, so the chassis must target
**`$10AC`** to set the gate. And a bus trace can now distinguish the hypotheses
directly: the bus-master route shows `$10AA` changing with no SBC cycle, the
command route shows a CPU write cycle from `$F04EC0`.

*The `$10AA` question was posed here as "unresolved — where does the value come
from". It has an answer, and the answer was inside the 14 table entries this
document had been calling a black box.*

### `FPS3K_RTOSDUMP`: the findings above, as a readout

Everything in the three sections that follow is a *readout* rather than an
inference, so it can be printed. `FPS3K_RTOSDUMP=1` decodes the RMS68K state out
of RAM at exit:

```
=== RMS68K state (decoded from RAM) ===
structure directory (TRAP #0 directive $04, page allocator):
  $0C20 -> $1FD00  !GST        $0C6E -> $1F800  !IDV
  $0C24 -> $1FB00  !UST        $0C2C -> $1F700  !PAT
  $0C66 -> $1FA00  ....        $0C28 -> $1F600  !UDR
  $0C6A -> $1F900  !IOV        $0C30 -> $1F500  ....
tasks (TCB: name +$10, ASQ/stack block +$138, saved SP +$13C):
  $1F300  RDHC  block=$1DD00  sp=$1DE16     $1ED00  XP3I  block=$1E300  sp=$1E414
  $1F100  IO1I  block=$1DF00  sp=$1E00A     $1EB00  XP2I  block=$1E500  sp=$1E614
  $1EF00  XP4I  block=$1E100  sp=$1E214     $1E900  XP1I  block=$1E700  sp=$1E814
!IDV interrupt table @ $1F800 {vector, TCB, ISR entry, ISR exit}:
  vec $45  TCB $1E900 XP1I  in $F07EE6  out $F07F08   !VCT owner=1
  ... (six records, !VCT owner 1..6 agreeing with the TCB in every row)
!VCT owned vectors @ $1FA00: $2D=flags:$BF $41->task6 $45->task1 ... $4A->task5
!UST ASQ registry @ $1FB00  9 of 22 records of $16 bytes:  XP1I/AXP1 ... IO1I/HIO1
heap: top $1FE00, bottom $1DD00 (33 pages handed out)  ->  microcode staging
       buffer usable range $10000-$1DCFF (56576 bytes)
=== end RMS68K state ===
```

The `!VCT owner=` column is a **consistency check that costs nothing**: it reads
the vector number out of `!IDV` and the owning task out of `!VCT`, two structures
built by different code at different times, and they agree in all six rows.

33 pages: 9 for the structures, 12 for the six TCBs, 12 for the six ASQ/stack
blocks. `$1FE00 - $1DD00 = $2100 = 33 × 256`, exactly.

Three bugs were fixed before this output was right, and all three are the
familiar shape: the task walk started one page-pair too high and printed **no
tasks at all**; the heap bottom was computed from the lowest *structure* and so
reported `$1F500` instead of `$1DD00`; and the `!VCT` filter excluded `$00` and
`$FF` but not `$BF`, reporting the flag byte at vector `$2D` as "task 191". The
harness checks then failed a fourth time because they asserted against `run()`,
which returns the **PC trace** — the dump goes to stderr, so the assertions were
vacuous. A `run_err()` helper now exists for exactly that.

*A correction to a figure this document introduced two sections ago: `$1DD00 -
$10000 = $DD00` is 56,576 bytes, which is **55.25 KB**, not 56.25 KB.*

### All eight RTOS structures decoded — including `!IDV`, the interrupt table

With the allocator understood, the eight blocks can simply be read. They do not
share one layout; there are four shapes.

| structure | shape | contents |
|---|---|---|
| `!GST` `$1FD00` | rich header | `$D`-byte records, capacity 18, **0 in use** |
| `!UST` `$1FB00` | rich header | `$16`-byte records, capacity 22, **9 in use** |
| `!IDV` `$1F800` | tag + end | **6 × 14-byte interrupt records** |
| `!PAT` `$1F700` | tag + first | **linked free-list, 8 × `$1E`-byte records** |
| `!IOV` `$1F900` | tag + end | empty |
| `!UDR` `$1F600` | tag + end | empty |
| `$1FA00` | none | `!VCT`, byte per vector (above) |
| `$1F500` | first/last | 9 × `$1A`-byte pool (above) |

#### `!IDV` is the interrupt-device table, and it is the whole IRQ wiring in one place

Six 14-byte records from `+$08`: **{vector word, TCB pointer, ISR entry, ISR
exit}**.

| vector | TCB | task | ISR entry | ISR exit |
|---|---|---|---|---|
| `$45` | `$1E900` | XP1I | `$F07EE6` | `$F07F08` |
| `$46` | `$1EB00` | XP2I | `$F074E6` | `$F07508` |
| `$47` | `$1ED00` | XP3I | `$F06AE6` | `$F06B08` |
| `$48` | `$1EF00` | XP4I | `$F060CE` | `$F060F0` |
| `$4A` | `$1F100` | IO1I | `$F05DD6` | `$F05E4C` |
| `$41` | `$1F300` | RDHC | `$F04930` | `$F050FC` |

The entry column matches, exactly and independently, the six handler addresses
this project assembled by hand from the BIM vector registers and the TCB headers.
The fourth column is new: it is the **ISR exit stub** for each task — and
`$F05E4C` in that column is the address already independently named `ISRExit` for
TCBIO1I, which is what confirms the field's meaning.

*This single 84-byte table is the entire interrupt wiring of the machine —
vector, owning task, handler in, handler out — and it can be read out of RAM
rather than reconstructed. Between this and `!VCT` at `$1FA00`, an emulator can
report the complete interrupt configuration without tracing a single directive.*

#### `!PAT` is a free-list, and it is completely empty

`+$04` holds a **first-record pointer** (`$1F714`), not an end address — a third
header shape. The records are chained through their first longword with a constant
stride of `$1E` (30 bytes) and `$FFFFFFFF` at `+$04`:

```
$1F714 -> $1F732 -> $1F750 -> $1F76E -> $1F78C -> $1F7AA -> $1F7C8 -> $1F7E6 -> NULL
```

Eight records, `8 × $1E = 240` bytes, plus the `$14` header = 254 of the page's
256. **The entire page is on the free list**, i.e. `!PAT` is allocated, correctly
initialised, and nothing has ever taken a record from it in any configuration
reached so far.

#### `!UST` is the ASQ name registry, and it confirms the counts a third way

Rich header: `+$0A` = pages, `+$0C` = record size, `+$0E` = records in use, `+$10`
= pointer to the first record at `base+$14`. Nine `$16`-byte records, each a
**(task name, ASQ name) pair**:

```
XP1I/AXP1  XP1I/HXP1  XP2I/AXP2  XP2I/HXP2  XP3I/AXP3
XP3I/HXP3  XP4I/AXP4  XP4I/HXP4  IO1I/HIO1
```

`2+2+2+2+1+0 = 9`. That is the third independent confirmation of the per-task ASQ
counts — after the task descriptors in ROM and the nonzero-byte counts in the
per-task blocks — and the first one that is a plain readable list rather than an
inference.

`!GST` has the same header shape with `$D`-byte records and **zero in use**;
`!IOV` and `!UDR` carry only a tag and an end address and are empty. So of the
eight structures the firmware allocates, **four are populated (`!UST`, `!IDV`,
`!PAT`'s free list, `!VCT`) and four are allocated-but-unused** in every
configuration reached so far.

### The two untagged structures: `!VCT` is a vector-ownership table

The eight allocations include two that stamp no marker tag. Both are now
identified, and one of them is the most directly useful RAM structure found so
far.

#### `$1FA00` (slot `$0C66`) — one byte per exception vector, holding the owner

Site 3's post-allocation code at `$F09F0E` is not a tag stamp, it is a table
build:

```
$F09F0E  moveq   #1,d2
$F09F10  bsr     $F0A332          ; BulkClear one page
$F09F14  moveq   #-1,d2
$F09F16  move.l  d2,(a0)+         ; \
$F09F18  move.l  d2,(a0)+         ;  > 10 bytes pre-set to $FF
$F09F1A  move.w  d2,(a0)+         ; /   -- vectors 0..9
$F09F1C  lea     $28,a2           ; a2 = the vector table, from vector 10
$F09F20  moveq   #-1,d2
$F09F22  cmpa.l  (a2)+,a4         ; compare each vector against a4
$F09F24  beq     $F09F28          ;   equal -> leave the byte 0
$F09F26  move.b  d2,(a0)          ;   differs -> mark $FF
$F09F28  lea     $1(a0),a0        ; ONE BYTE PER VECTOR
$F09F2C  cmpa.l  #$400,a2
$F09F32  bne     $F09F22
```

Ten bytes advanced before the loop, then one byte per longword from `$28` to
`$400`: **byte `k` of the block corresponds to exception vector number `k`,**
exactly. The block is 256 bytes for 256 vectors.

Then the kernel fills it in. `$F0226A` — one routine, the only code that writes
non-`$FF` values here — stores a small integer per vector, and the values are
decisive:

| byte | vector | value | owner |
|---|---|---|---|
| `+$41` | `$41` | 6 | `TCBRDHC` |
| `+$42` | `$42` | **0** | — |
| `+$43` | `$43` | **0** | — |
| `+$44` | `$44` | **0** | — |
| `+$45` | `$45` | 1 | `TCBXP1I` |
| `+$46` | `$46` | 2 | `TCBXP2I` |
| `+$47` | `$47` | 3 | `TCBXP3I` |
| `+$48` | `$48` | 4 | `TCBXP4I` |
| `+$49` | `$49` | **0** | — |
| `+$4A` | `$4A` | 5 | `TCBIO1I` |

Six for six against the TCB vector numbers, and **the four vectors that this
document already recorded as "programmed in a BIM vector register but belonging to
no TCB" — `$42`, `$43`, `$44`, `$49` — read exactly zero.** That is an
independent confirmation of a finding that previously rested on comparing two
tables by eye.

So `$1FA00` is the **`!VCT` structure**: `byte[vector number] = owning task
number, 0 = unowned`, written by the directive `$4C` (connect interrupt vector)
implementation at `$F0226A`. `!VCT` was listed as having kernel code but no tagged
instance; the instance is here, untagged.

It also fixes the **canonical task numbering**, which nothing else in the ROM
states outright: `XP1I`=1, `XP2I`=2, `XP3I`=3, `XP4I`=4, `IO1I`=5, `RDHC`=6. Note
this is *not* the TCB allocation order (which runs RDHC first) nor the ASQ-block
order (XP1I first) — it is a third ordering, and it is the one the kernel uses.

*For emulation this is a free readout: dump `$1FA00` and you have the complete
vector-to-task ownership map without tracing a single `$4C` call.*

#### `$1F500` (slot `$0C30`) — a 9-slot pool of 26-byte records

Site 8's code at `$F0A030` writes a two-pointer header instead of a tag:

```
$F0A030  lea     $8(a0),a2        ; first = base + 8
$F0A034  move.l  a2,(a0)
$F0A036  lsl.l   #8,d2            ; size in bytes
$F0A038  subq.l  #8,d2            ;   less the header
$F0A03A  divu    #$1A,d2          ; \ round DOWN to a whole
$F0A03E  mulu    #$1A,d2          ; /   number of $1A-byte records
$F0A042  add.l   a2,d2
$F0A044  move.l  d2,$4(a0)        ; last = first + n*$1A
```

One page: `(256-8) div 26 = 9` records of 26 bytes, giving `first = $1F508`,
`last = $1F5F2` — which is exactly what RAM holds. Untagged, and unchanged across
all three golden masters, so nothing exercises it in any configuration reached so
far. By elimination it is `!CCB` or `!DLY`; the record size `$1A` is the
discriminator to look for if either structure's layout ever turns up.

#### Methodological note: first writer vs last writer

A watchpoint on any of these addresses reports the **power-on RAM test** first —
`$F098FC` writes each location its own address (address-uniqueness), `$F09944` and
`$F099BC` write the four patterns at `$F09BB6`. Reading the first few watch lines
makes a genuine structure look like RAM-test residue, and reading the *contents*
without the watch makes the residue look like a structure. Only the **last** writer
identifies what a location is for. Both misreadings happened here before the
tables above came out right.

### The whole RAM heap, and a 512-byte correction to the staging buffer

Following the allocator down gives the complete picture. **The heap starts at
`$1FE00` — immediately below the supervisor stack region — and grows downward in
256-byte pages.** Twenty allocations happen during boot, contiguous, no gaps:

| # | what | extent | pages |
|---|---|---|---|
| 1 | `!GST` | `$1FD00-$1FDFF` | 1 |
| 2 | `!UST` | `$1FB00-$1FCFF` | 2 |
| 3 | untagged | `$1FA00-$1FAFF` | 1 |
| 4 | `!IOV` | `$1F900-$1F9FF` | 1 |
| 5 | `!IDV` | `$1F800-$1F8FF` | 1 |
| 6 | `!PAT` | `$1F700-$1F7FF` | 1 |
| 7 | `!UDR` | `$1F600-$1F6FF` | 1 |
| 8 | untagged | `$1F500-$1F5FF` | 1 |
| 9-14 | TCBs, `RDHC` `IO1I` `XP4I` `XP3I` `XP2I` `XP1I` | `$1E900-$1F4FF` | 2 each |
| 15-20 | ASQ/stack blocks, `XP1I` `XP2I` `XP3I` `XP4I` `IO1I` `RDHC` | `$1DD00-$1E8FF` | 2 each |

**Heap bottom after a clean boot: `$1DD00`.**

**The staging-buffer bound was 512 bytes too generous.** This document has
recorded the usable microcode-staging region as `$10000-$1DEFF`, derived from a
nonzero-byte scan. RDHC's ASQ/stack block at `$1DD00-$1DEFF` contains **zero
nonzero bytes** — RDHC declares no ASQ and never pushed deep enough to write it —
so a nonzero scan cannot see it, even though the allocator has handed it out and
RDHC will write it the moment it does any real work. The correct bound is
**`$10000-$1DCFF`, 55.25 KB (56,576 bytes)**.

*This is the same instrument defect as the others in this document, in its purest
form yet: an allocated-but-untouched buffer is indistinguishable from free memory
to any scan that looks at contents instead of at the allocator.* The fix is not a
better scan, it is reading `TCB+$138` — which is where the answer was all along.

**Three independent confirmations of the page unit.** The end-address arithmetic
(`base + (size<<8) - 1`); the `$x00` alignment of all twenty blocks; and the
rounding — every task descriptor requests `$190` (400 bytes) of stack and every
block is `$200`, i.e. `ceil(400/256) = 2` pages.

#### The block at `TCB+$138` is the ASQ block, and its size proves the ASQ count

`TCB+$138` points at the block; `TCB+$13C` is the task's saved stack pointer
inside it. At the block's base sits an array of **10-byte ASQ descriptors** —
4-byte name, longword, word:

```
$1E700  41 58 50 31  00 00 00 14  00 02      'AXP1'
$1E70A  48 58 50 31  00 00 00 2A  00 02      'HXP1'
```

Count the nonzero bytes per block and you recover the ASQ declarations exactly:

| task | nonzero | ASQs | declared in its descriptor |
|---|---|---|---|
| XP1I…XP4I | 12 | 2 | `AXPn` + `HXPn` ✓ |
| IO1I | 6 | 1 | `HIO1` ✓ |
| RDHC | 0 | 0 | none ✓ |

So `!ASQ` — one of the four markers with kernel code but no tagged instance —
**does have live instances; they are here, untagged.** That closes the loop on the
earlier finding that directive `$2D` creates the queues without stamping `!ASQ`:
this is where it puts them.

#### The allocation order is an observable of the startup sequence

The TCBs come out in TDTI table order — `RDHC` highest, `XP1I` lowest. The
ASQ/stack blocks come out in the **reverse** order — `XP1I` highest, `RDHC`
lowest. They cannot both be one loop. The reading that fits: TDTI creates all six
TCBs in table order, and then each task allocates its *own* block when it runs its
directive `$01`, in scheduling order. **The addresses therefore record which task
the scheduler ran first**, and they say XP1I — consistent with RDHC issuing its
directive `$12` five times as `XP4I..XP1I` then `USER`, i.e. RDHC starting the
others before settling into its own body.

*For emulation this matters more than it looks: a chassis model that changes how
many tasks start, or in what order, moves the heap bottom and shifts every one of
these addresses. They are not constants to hard-code.*

### Directive `$04` is the page allocator, and it explains every `$x00` address

Working the backlog from the top, the largest genuinely distinct span —
`$F09F0E-$F0A145`, 568 bytes of RTOS init — is the **RTOS structure allocator**.
It is eight repetitions of one sequence:

```
clr.l   $0C6A(a0)          ; clear the directory slot
move.l  <size>(pc),d2      ; size, in 256-byte pages
beq     -> skip            ; zero size -> structure not created
movea.l d2,a0
moveq   #$04,d0
TRAP    #0                 ; ALLOCATE -- block returned in a0
bra     -> ok              ; (error path skipped)
move.l  a0,$0C6A(a0)       ; register the pointer
move.l  #'!IOV',(a0)       ; stamp the marker tag
lsl.l   #8,d2
add.l   a0,d2
subq.l  #1,d2
move.l  d2,$4(a0)          ; end = base + (size << 8) - 1
```

Eight calls, eight structures, eight directory slots:

| site | tag stamped | slot | RAM |
|---|---|---|---|
| `$F09E78` | `!GST` | `$0C20` | `$1FD00` |
| `$F09EBE` | `!UST` | `$0C24` | `$1FB00` |
| `$F09EFE` | — | `$0C66` | `$1FA00` |
| `$F09F42` | `!IOV` | `$0C6A` | `$1F900` |
| `$F09F70` | `!IDV` | `$0C6E` | `$1F800` |
| `$F09FA2` | `!PAT` | `$0C2C` | `$1F700` |
| `$F09FF0` | `!UDR` | `$0C28` | `$1F600` |
| `$F0A020` | — | `$0C30` | `$1F500` |

Three things this settles.

**Directive `$04` is the allocator.** The `$04` ×8 in the TRAP #0 census, whose
purpose was recorded as "plausibly a segment or allocation call", is allocation:
size in pages going in, block address coming back in `a0`.

**It allocates in 256-byte pages.** The end address is computed `base + (size<<8)
- 1`, so the unit is 256 bytes — and that is **why every RTOS structure sits at a
`$1Fx00` boundary and why the TCBs stride by `$200`.** The strides that this
project has been recording as bare facts for many iterations are a consequence of
the allocator's page size.

**And it confirms the differential-analysis result while extending it.** The five
directory slots found by diffing golden masters — `$0C20`, `$0C24`, `$0C28`,
`$0C2C`, `$0C30` — are exactly right, and the static decode adds **three more**:
`$0C66`, `$0C6A`, `$0C6E`, holding `$1FA00`, `$1F900` (`!IOV`) and `$1F800`
(`!IDV`). Differential analysis found the slots that *moved*; the code shows all
eight.

*That is the two methods checking each other, which is the point of having both.
Neither would have given this alone: the diff could not see slots that never
change, and the static read could not have told which of the eight are live.*

### What is actually left: ~3.6 KB of distinct, unannotated code

With the replication mapped, the remaining work can be stated precisely. Marking
every byte that is either a replicated copy or within 64 bytes of a `;###` note,
and taking the residual spans of 128 bytes or more:

| span | bytes | region | note |
|---|---|---|---|
| `$F06692-$F068A7` | 534 | **XP4I** | genuinely distinct — see below |
| `$F09F0E-$F0A145` | 568 | RTOS init | |
| `$F08986-$F08B5B` | 470 | init / self-test | |
| `$F05F40-$F06107` | 456 | **XP4I** | genuinely distinct |
| `$F04F7A-$F050F7` | 382 | RDHC | |
| `$F09C40-$F09D97` | 344 | RTOS init | |
| `$F04D8E-$F04EE3` | 342 | RDHC | |
| `$F05542-$F05651` | 272 | RDHC | |
| `$F04970-$F04A6D` | 254 | RDHC | |

**RDHC accounts for ~1,250 bytes across four spans** — the largest single owner,
consistent with it being both the biggest region and the least executed at 7%.

**The XP3I and XP2I spans on the first pass were false entries.** `$F06940` and
`$F07340` are exactly `$A00` apart and differ in only 40 of 480 bytes — 8%, the
template-patch rate — so they are copies the replication marking had missed.
Removing them is what leaves the list above.

**XP4I's two spans are real.** Tested at `$A00`, `$A00-$18` and `$A00+$18`
against XP3I, the best match still differs in 52% of bytes. That is consistent
with what was established earlier: XP4I is not a clean template copy — it lacks
the bit-11 sub-case, carries its own `$8020` MODE1 write, and its dispatch table
sits `$18` off the grid. Roughly a kilobyte of XP4I is genuinely its own code.

So the honest remaining backlog is **about 3.6 KB of distinct, unannotated code**,
concentrated in four places: RDHC's body, RTOS init, the self-test area around
`$F08986`, and XP4I's divergent regions. Everything else in the 25 KB is either
annotated, replicated, or both.

### The transfer primitive, replicated 15 times — and a matching gap in the model

The original sweep also reported two **15-copy** groups, the highest replication
count in the ROM, and neither had been decoded. Both are the same primitive:

| group | first instructions | copies |
|---|---|---|
| `$F056C8` +52 | `move.w #$8004,(a0)` then poll bit 14, `d5 = $3E8` | **15** — 3 per task × 5 |
| `$F05742` +50 | `move.w #$8005,(a0)` then **the same poll** | **15** — 3 per task × 5 |

So the chassis transfer primitive is **issue-then-poll**, it exists three times per
task for each of the two commands, and — the useful part — **both commands poll
bit 14 with the same budget.**

The model acknowledged only `$8004`. All fifteen `$8005` sites were still running
their full 1000-iteration timeout. Fixed: `ch_request_transfer` now fires for both.

**It changes nothing measurable, and that is worth stating.** No new PCs, no digest
movement, 160/160 unchanged — because the `$8005` sites are not reached in any
configuration currently available. The fix is correct on the firmware's own terms
(the two commands share a poll, so they must share an acknowledge) and its value is
that it will not need finding again when a configuration does reach them.

It also explains why the `$8004` acknowledge produced such a large jump. It was
never one site: the primitive is replicated 15 times, and the ISR's poll is one
instance of an idiom used throughout.

### The last two replicated groups: a shared epilogue, and `$8005`

Decoding the two remaining 5-copy groups completes the set. Both **begin with the
same eight-instruction epilogue**:

```
clr.l   d5
move.b  $0(a5,d4.w),d5
move.w  d0,$21A(a0)        ; restore XLTR IRQ_MASK
move.w  #$005F,(a3)        ; BIM CR with IRE SET -- re-enable the channel
rts
```

**That identifies the `$4F`/`$5F` pairing.** `$4F` is written to a BIM control
register on entry to suppress the channel's interrupt during a transfer — already
documented — and **`$5F` here is the matching restore on exit.** Mute, transfer,
unmute. The five occurrences of `$4F` and the handler-exit `$5F` are two halves of
one idiom, which neither half's documentation said.

After the shared epilogue the two groups diverge:

**`$F057FA` +88** — `move.l a2,d1` / `swap d1` / `move.w d1,(a1)` / `swap d1` /
`move.w d1,$2(a1)` / `move.w #$8005,(a0)`. A 32-bit value pushed across the data
pair as two halves, then **`$8005` = CONTINUE-TRANSFER**. This is the `$8005`
counterpart to the `$8004` REQUEST-TRANSFER in the channel ISR, and the `swap`
idiom is the same one the tag census counted 35 times as `HA3A`/`HB3B`/`HC3C`.

**`$F0599C` +106** — `movea.l #$FF0000,a4` / `move.w $202(a4),d5` /
`btst #7,d5` / `bne`. A poll of **MODE1 bit 7, the busy flag** — the documented
`$FF0202` bit 7.

So all five replicated 5-copy groups are now accounted for:

| group | contents |
|---|---|
| 192 × 5 | the 42-entry dispatch table + `PanelErrorMaskTable` |
| 176 × 5 | the `POLL` handler |
| 130 × 5 | the `BLK_XFR` handler |
| 106 × 5 | shared epilogue + MODE1 busy-poll |
| 88 × 5 | shared epilogue + 32-bit push + `$8005` CONTINUE-TRANSFER |
| 408 × 4 | XP-only: the channel scan and the task tail |

Every one is part of the `PanelStatusDispatch` machinery. **The 36% duplication
figure is, almost entirely, this one subsystem replicated five times** — which is
a more useful description of the ROM's structure than the percentage was.

### RESOLVED: the 42-slot table's "different caller" is the channel ISR

CLAUDE.md has carried this as an open item since the dispatch table was decoded:

> `F0572C` (the `PanelStatusDispatchTable` site) is **never reached** from F04930
> on any of 42 swept response values. That 42-slot table is correctly decoded but
> belongs to a different caller.

**The different caller is the XP channel ISR's post-transfer dispatch at
`$F07F84`** — in each task's own copy of the table.

Decoding what the replication sweep had already found settles it. Taking the
offset between RDHC's table and XP1I's, `$2858`, and applying it to RDHC's four
documented handlers lands on XP1I's four exactly:

| RDHC handler | `+$2858` | XP1I | difference |
|---|---|---|---|
| `D2_FIN` `$F05738` | → | `$F07F90` | 2 of 64 bytes |
| `D1_SEND` `$F058B2` | → | `$F0810A` | 2 of 64 bytes |
| `POLL` `$F05A12` | → | `$F0826A` | **byte-identical** |
| `BLK_XFR` `$F05B0E` | → | `$F08366` | **byte-identical** |

So the **entire `PanelStatusDispatch` subsystem is replicated once per task** —
the 42-entry table, `PanelErrorMaskTable`, and all four handlers — with only
two-byte constant patches in two of them, the same template-patch pattern
measured across the task bodies.

Three consequences.

**The subsystem is not RDHC-specific.** It has been documented as RDHC's, and it
is shared library code that every task carries.

**The handler names transfer.** The handler executing most in XP1I, `$F0810A`, is
the `D1_SEND` position — "push `d1` as a longword in two halves, then
REQUEST-TRANSFER". That matches what the channel ISR was independently measured
doing: write the data pair, write `$8004`. The two readings were of the same code
and neither knew about the other.

**And RDHC's copy is the dead one.** `$F0572C` is unreached in every
configuration, while the XP copies dispatch on every completed transfer. The
subsystem was named after, and attributed to, the one instance that never runs —
which is the same error as the five-tables case, and for the same reason: it was
found in RDHC first because RDHC is where the disassembly starts.

*Method note: this came from decoding groups the original duplicate-block sweep
reported months of iterations ago, immediately after the previous section
concluded that interpretation, not detection, was the gap. Two of five groups
mapped straight onto documented handlers; the offset arithmetic did the rest.*

### `PanelStatusDispatchTable` is not one table — there are five

The 42-entry table is not a twin of RDHC's; it is a **copy of it**. Searching the
whole ROM for any 42-entry table with the same index-to-handler pattern —
`.ABBBBBBCCA..BBBB...D.AACACACCCA..ACAC....` — finds **five**, one per task:

| address | task | offset from XP1I's |
|---|---|---|
| `$F05BA4` | RDHC | — (the documented `PanelStatusDispatchTable`) |
| `$F065E4` | XP4I | `-$1E18` — **`$18` off the grid** |
| `$F06FFC` | XP3I | `-$1400` |
| `$F079FC` | XP2I | `-$0A00` |
| `$F083FC` | XP1I | reference |

168 bytes each, 840 bytes in total, byte-identical in structure. So this project's
named `PanelStatusDispatchTable` is one instance of a **replicated library
table**, and the "42 codes → 4 handlers" characterisation applies to all five.

Three things fall out.

**The 5-copy shape matches the dominant replication pattern** already measured —
one in RDHC and one in each XP task. In fact the table **is** one of those already-
reported groups: the 192-byte 5-copy block at `$F05B92` contains it, starting 18
bytes in. The sweep found it; nothing decoded it.

**XP4I's copy independently confirms the `$18` shift.** XP2I and XP3I sit on the
clean `$A00` grid; XP4I's is at `-$1E18`, `$18` past where the grid predicts —
which is precisely the offset established from the byte diff, arrived at here from
completely different evidence.

**And the documented one is the only copy that never runs.** RDHC's is reached
from `$F0572C`, which no configuration has ever executed; the XP copies execute.
That reframes a long-standing note: the table was correctly decoded but attributed
to the one owner whose path is dead, while four live owners of the same table went
unnoticed.

### XP1I has a 42-entry dispatch table — the twin of `PanelStatusDispatchTable`

Making the transaction complete exposed 124 new XP1I instructions, and the
structure at the centre of them was undocumented. After the poll succeeds the
ISR does:

```
$F07F56  btst #$D,d4        ; bit 13 = error
$F07F5A  beq  -> $F07F84    ; no error -> dispatch
$F07F5C  move.w #$0269,d0   ; ...else PCMD_ERROR_ABORT and spin
$F07F84  lsl.w #2,d0
$F07F86  lea   $F083FC,a4
$F07F8C  jmp   (a4,d0.w)    ; 16-entry dispatch
```

`$F083FC` is a **42 × 4-byte table** of inline stubs — `jmp d16(pc)` where a
handler exists, `rts` where none does — running `$F083FC-$F084A3` and ending
exactly where the `0005 0403` data begins. Forty-two indices collapse onto
**four** handlers:

| target | entries |
|---|---|
| `rts` — no handler | 13 |
| **`$F0810A`** | 10 |
| **`$F0826A`** | 9 |
| **`$F08366`** | 9 |
| `$F07F90` | 1 |

**It was first recorded here as "16 entries, 3 handlers", and that was wrong.** I
read only the first sixteen and assumed the size from the wrong analogy —
RDHC's *other* table at `$F05102` is 16 entries. Measuring the dispatch index
settled it: `FPS3K_REGLOG` at `$F07F84` shows `d0 = $FFFF0010` and `$FFFF000E`,
and since `lsl.w #2` and `(a4,d0.w)` use only the low word those are indices
**16** and 14 — index 16 being one past the assumed end, and a perfectly valid
`jmp` entry.

**It is the twin of RDHC's `PanelStatusDispatchTable` at `$F05BA4`**, and the
correspondence is exact:

| | entries | size | index | handlers |
|---|---|---|---|---|
| RDHC `$F05BA4-$F05C4B` | **42** | 4 B | `d0 << 2` | **4** |
| XP1I `$F083FC-$F084A3` | **42** | 4 B | `d0 << 2` | **4** |

Same length, same entry size, same indexing, same handler count. The documented
one is reached from `$F0572C` and has never executed in any configuration; this
one executes. This project had documented only the RDHC one; the channel's
existence was invisible while every transaction timed out before reaching it.

**But it does NOT dispatch on a channel command word — that was wrong.** Tracing
what sets `d0` between the ISR's `trap #1` at `$F07F0E` and the dispatch at
`$F07F84` finds three writes, and **all three are on paths not taken when the
transfer succeeds**: `$F07F4C` (`$26C`) is reached only on a full timeout, and
`$F07F5C` (`$269`) and `$F07F66` only on the bit-13 error path. On the
acknowledged path `d0` still holds **the return value of the `trap #1` carrying
directive `$0F`**.

So `$F083FC` dispatches on an **RTOS directive result**, not on anything the
chassis supplies. That changes what the two unreached handlers mean: `$F0826A`,
at indices 1 and 10, is gated by the kernel returning 1 or 10 from directive
`$0F`, so **no chassis model will ever reach it.** They are dark for a
kernel-side reason, and looking for a chassis stimulus would have been wasted
effort.

Measured, `d0` takes the values `$0E` and `$10` — so two of the 42 indices are
exercised, both landing on `$F0810A`. The other three handlers are unreached, and
because the index is an RTOS result rather than a chassis value, reaching them is
a kernel-side question.

**This is what the acknowledge bought beyond the coverage number.** A structure of
this size does not appear in a static reading as anything but data: the table is
16 longwords of `4EFA xxxx` that a disassembler renders as instructions with no
indication they are a table, and the `lsl.w #2` / `jmp (a4,d0.w)` that identifies
it is 90 bytes away in code that never ran.

### Coverage after the acknowledge: 19% → 25%, XP tasks quadrupled

Re-measuring the union across nine configurations, against the 19%/5-config
baseline recorded earlier:

| region | before | after |
|---|---|---|
| init / self-test | 52% | 51% |
| RTOS init | 41% | 41% |
| TCBIO1I | 30% | 29% |
| **TCBRDHC** | 8% | **7%** |
| **XP1I** | 6% | **20%** |
| **XP2I / XP3I / XP4I** | 4% each | **18% / 18% / 19%** |
| **overall** | **19%** | **25%** |

**The four channel tasks roughly quadrupled** — the single acknowledge bit was
what gated them. XP1I now reaches `$F08614`, and the channel service routines at
`$F0810A`-`$F081A8` execute for the first time.

The regions that did not move are the informative ones. `init/test` and `RTOS`
are unchanged because they never depended on a channel transaction, and the 1%
wobble is config-set noise rather than regression.

**TCBRDHC is still 7%**, and it is now clearly the whole remaining problem: it is
the largest region (5,888 bytes), it is the master task, and it is blocked on
something different in kind. The XP tasks were blocked on a *bit* — one
acknowledge the chassis never asserted. RDHC is blocked on a *conversation*: the
scripted-sequence hook is a monologue, and RDHC's body sits behind a protocol
exchange where each step depends on the previous response. Sweeping the 16
response codes bought it one percentage point.

So the remaining emulator-side headroom is concentrated in one place, and closing
it needs either the chassis's real response protocol — a bus trace — or a
reactive chassis model built on assumptions that nothing available can falsify.
The first is a bench task; the second is the kind of self-consistent invention
this session has spent most of its effort removing.

### The chassis now acknowledges REQUEST-TRANSFER — XP1I coverage doubles

The channel ISR writes `$8004` to its command port and polls that port for
bit 14, with a 1000-iteration budget (`$F07F26` loads `$3E8`). Measured, the poll
ran **exactly 1000 times, every time** — the full timeout. The chassis never
acknowledged a transfer.

Bit 14 is the completion flag, read off the firmware rather than assumed:
`$F07F30` is `btst #$E,d4` and `$F07F3E` is `btst #$D,d4`, so bit 14 is tested
first and bit 13 second — done, then error.

Making the chassis set bit 14 on a `$8004` write took **three shadowing layers**
off the same register, and each was a survival of a superseded model:

1. **Channel-port writes were dropped entirely**, with the comment *"read-only
   status from AP"* — the old model in which `+$08`/`+$0A`/`+$0E` were a read
   port, a status word and a second read port. Nothing recorded the request.
2. **A retracted host-byte block special-cased channel 1**, returning the
   invented `$4F` at `$FF004A` and treating a read of `$FF0048` as *consuming a
   host byte*. It also **shadowed the correct per-channel handler**, so channel 1
   could never reach the acknowledge. A retracted model left in place as
   dead-looking code was still changing behaviour.
3. **The `FPS3K_CHANNELS` presence stub intercepted every command-port read** and
   returned its constant, shadowing both the value the firmware had just written
   and the acknowledge. Presence is now the port's *power-on* value and yields
   once the firmware writes it.

With all three resolved:

| | poll iterations | XP1I distinct PCs |
|---|---|---|
| `FPS3K_NOACK=1` (old behaviour) | **1000** | 116 |
| acknowledged | **2** | **240** |

**Coverage on XP1I roughly doubles**, and the post-poll path at `$F07F56` is
reached for the first time.

Two notes on getting there. The acknowledge is **immediate**: a 40-cycle delay
never elapsed, because `versabus_tick` runs once per batch of interpreted
instructions and the entire 1000-iteration poll fits inside one batch — the
request fired and the acknowledge never did, visible only once both ends were
instrumented. Immediate is also defensible: any chassis fast enough to answer
within the firmware's own 1000-iteration budget is indistinguishable from one
that answers at once, and nothing here establishes the real latency.

And the **golden master did its job**. The XP1I digest changed, the other two did
not, so the effect was confined as expected. The diff was inspected before the
digest was updated: `$00B91` now holds `$F05102`, the 16-entry response jump
table; `$00E6E` stages panel code `$25C`; `$00BDB` carries `$FF0048`; and XP1I's
TCB and channel snapshot both advance. Seventy bytes moved, all of it progress.

### The RTOS scheduler control block, found by differential state analysis

Diffing the three golden masters against each other maps which RAM each
subsystem owns. Driving a task changes **only** its own structures plus one
shared region:

| driven | bytes changed |
|---|---|
| XP1I | its TCB `$1E90D`, its channel block `$1066`, its companion `$1EA0A`/`$1EA21`, **plus `$00BA3-$00BFB`** |
| TCBIO1I | its TCB `$1F10D`, its companion `$1F221`, `$1FBD4`, **plus `$00BA4-$00BFB`** |

The per-task confinement confirms the ownership model derived statically. The
**shared region is new** — but it is two different things, and an earlier draft of
this section conflated them.

**`$00C0C-$00C30` is scheduler state**: a current-task pointer and a structure
directory, both decoded below.

**`$00BA0-$00BFB` is a stack**, not a field table. Comparing XP1I, XP2I and XP3I
appeared to show *50 task-dependent bytes*, which looked like a rich per-task
structure. It is one stack observed at three different depths: the same byte
sequences recur at shifted offsets in each configuration, and they decode as
**68000 exception frames** — a status word followed by a 32-bit return PC:

```
27 08 00 F0 2C A2     SR $2708 (supervisor, IPL 7) + PC $F02CA2
27 04 00 F0 02 B6     SR $2704 (supervisor, IPL 7) + PC $F002B6
      00 F0 06 50     ... further kernel return addresses
      00 F0 05 18     constant at the base, $00BFC in all three
```

`$2704` and `$2708` differ only in their condition codes; both are supervisor at
IPL 7. So the "50 task-identity bytes" were an artefact of differencing a stack:
nesting depth varies with which task ran, so almost every byte moves without any
of them being a per-task field.

**That is the failure mode of differential analysis, and it is worth naming.** The
method finds *what changed*, which is exactly right for locating state — and
exactly wrong for interpreting it, because a stack changes wholesale for reasons
that carry no structure. The check on it is the same as everywhere else in this
session: decode the bytes before believing the diff.

**`$00C0C` is the current-task TCB pointer.** Verified across five
configurations, each time holding exactly the TCB of the task that was driven:

| configuration | `$00C0C` | task |
|---|---|---|
| default | `$1F300` | RDHC |
| `XPIRQ=1` | `$1E900` | XP1I |
| `XPIRQ=2` | `$1EB00` | XP2I |
| `XPIRQ=3` | `$1ED00` | XP3I |
| `XPIRQ=5` + `DMA10AA=2` + `MBOX` | `$1F100` | IO1I |

**`$00C0C` tracks what the scheduler *dispatched*, not merely whose ISR ran.**
With `XPIRQ=5` alone TCBIO1I's ISR executes but `$00C0C` still reads `$1F300`
(RDHC); it only moves once `$10AA = 2` lets the reply path complete. That
distinction was found by the check failing on the weaker configuration, and it
is the sharper reading — an ISR is not a dispatch.

**`$00C20` onward is a structure directory** — one pointer per singleton table,
matching the marker census exactly:

| address | points to | structure |
|---|---|---|
| `$00C10` | `$1E900` (constant) | TCB list head |
| `$00C20` | `$1FD00` | `!GST` |
| `$00C24` | `$1FB00` | `!UST` |
| `$00C28` | `$1F600` | `!UDR` |
| `$00C2C` | `$1F700` | `!PAT` |
| `$00C30` | `$1F500` | (untagged) |

And `$00BA2`/`$00BE6` hold `$1F700`/`$1F708` — `!PAT` pool pointers — only in the
configurations where a task actually ran, which is consistent with `!PAT` being
the allocation pool its 30-byte free-list shape suggested.

**No static reading would have produced this.** The region is
indistinguishable from any other zeroed globals area in the disassembly; what
identified it was holding the machine still and changing one variable — which is
what the golden masters made cheap. Differential state analysis is now the tool
of choice for the parts of the model that decoding cannot reach.

### Golden-master machine state: the whole model is now pinned

The pointwise checks read about twenty specific locations. The PTM clocking fix
showed that is not enough: two models gave **identical PC counts and identical
final PC** while **78 RAM bytes differed**, and the difference surfaced only
because one check happened to read the `!UST` directory. A coverage metric cannot
see state.

Post-boot RAM is **deterministic** — three identical runs give the same digest —
so the whole 128 KB can be pinned at once. Three configurations are now
golden-mastered:

| configuration | digest |
|---|---|
| default (2-AC, no hooks) | `698be039…` |
| XP1I driven to the `$8000` path | `a3f9384e…` |
| TCBIO1I reply path | `1eabc593…` |

Verified to bite: running with `FPS3K_PTM_LEGACY=1` gives `283e4d92…`, so the
state change the previous section describes would now be caught immediately
rather than by luck.

**A failure here is not necessarily a bug** — it means machine state changed. If
the change is intended, the digest gets updated *and* what moved is recorded. The
check is written to make that explicit, because a golden master updated without
looking at the diff is worse than no golden master: it converts a loud signal
into a ritual.

This is the counterweight to the session's other lesson. Absence checks fail
open — "nothing happened" reads as "nothing bad happened" — while a state digest
fails **closed**: it cannot pass by accident, cannot pass because the machine did
nothing, and cannot pass because an instrument was silently disabled. For a
whole-machine emulator built on 26 hooks, that is the one check whose meaning
does not depend on the hooks being right.

### The PTM was clocked from the CPU, not from E — and the "prescaler" was the fudge

The MC6840 model contained a contradiction. Its own comment says the prescaler is
**CR3 bit 0, for T3** — which matches the datasheet — while the code applied a
`/8` on **bit 1, to all three timers**. Bit 1 is the **clock source** (1 =
internal E, 0 = external), not a prescaler.

It looked like a plain bug, and it matters for the RTOS: the RTOS writes
**`CR1 = $C6`** at `$F0A2D8` — bit 1 set — so the model divided the tick rate
by 8.

**Applying the datasheet reading broke task initialisation.** With `/8` removed
and the real CR3-bit-0 prescaler in its place, `!UST` stops at **7 of 9 entries**
and stays there at 400M, 800M and 1,600M cycles: TCBIO1I never finishes
registering `HIO1`.

That failure identifies what the `/8` was really standing in for. **The PTM is
clocked by E, and on a 68000 E = CPU/10**, but `mc6840_tick` is handed *CPU*
cycles. The old `/8` was an undeclared approximation of the E divider — the
comment's "very rough prescale" admits as much — so removing it left the tick
**10× fast** and starved the RTOS.

The model now divides by **10 unconditionally** for the E clock, and applies the
datasheet's real prescaler — CR3 bit 0, T3 only — on top. All nine `!UST` entries
populate and the harness passes 144/144.

| model | `!UST` entries | harness |
|---|---|---|
| legacy: `/8` on bit 1, all timers | 9/9 | 144/144 |
| "datasheet", no divider | **7/9** | fails |
| **E clock `/10` + CR3 b0 on T3** | 9/9 | 144/144 |

*And a methodological note. The first comparison of legacy against strict looked
at self-test PC counts and the final PC, found them identical, and concluded the
change was free. It was not: 78 RAM bytes differed, including two `!UST` entries.
Equal PC counts with unequal RAM is exactly the case a coverage metric cannot
see, and the harness caught it only because a check happened to read that
directory.*

### Auditing the harness: three checks could not fail

The harness has grown from 21 checks to 144, and its own falsifiability test was
validated at 21. Re-establishing it:

| ROM | result |
|---|---|
| the real image | **144/144** |
| two bytes mutated (an issuer copy + `SRecordDataHandler`) | **100/144** — 44 catch it |
| a random 64 KB image | **97/144** — 47 catch it |

Forty-four checks are sensitive to a two-byte change, which is healthy. The
interesting number is the other direction: **97 checks pass on pure noise.** Most
legitimately so — they test the tooling rather than the ROM (that `fps3k.asm`
carries its notes, that `NOTES` merges duplicates, that hook conflicts warn, that
the run reports its instrumentation, that no unmapped chassis region is touched).

But **three were vacuous**, and all three had the same shape as the instrument
defects found earlier today — an absence claim with no presence precondition:

| check | why a garbage ROM satisfied it |
|---|---|
| "self-tests: zero error-flag hits" | a ROM that never runs the self-tests raises no error flag |
| "`$01110-$1DEFF` is entirely untouched" | a ROM that writes no RAM touches nothing |
| "`$10AA` from reset never boots" | a ROM that cannot boot never boots |

Each now carries a liveness guard: the self-test check requires >500 diagnostic
PCs *and* zero flags; the RAM check requires the RTOS areas to *be* occupied
(`!TCB` at `$1E900`, the stack region non-empty) as well as the free span to be
clear; and the `$10AA` check requires the run to have *reached* the diagnostics
it is supposed to hang in. All three now fail on noise, as they should.

**This is the same defect as the dead write-detector and the silently-overridden
hook, one level further out.** "Nothing bad happened" and "nothing happened" are
indistinguishable to an unguarded absence check — so a test suite full of them
reports health most reliably when the machine is most broken. For an emulator
whose correctness rests on 26 hooks, the harness needed the same audit as the
hooks.

### Unmapped chassis regions now announce themselves — and none is touched

The model returned **0** for any chassis-window address matching no handler,
which is indistinguishable from a card answering 0. Two regions are unmapped:
**`$FF0100-$FF01FF`**, the 256 bytes between the AP I/F and the XLTR
(`ds2/INDEX.md` item 18, "unaccounted"), and `$FF0260` upward.

Both sides now count and name such accesses, and every run reports the total:

```
[done] unmapped chassis accesses: 0 reads, 0 writes  (address map complete for this run)
```

**Zero across every configuration tested** — default, `XPIRQ=1,5,6` with
`CHCMD=C801`, and `CHSEL_RD=28`. So ds2's item 18 resolves the same way F.4 did:
the gap is real in the model but **the firmware never touches it**. The chassis
address map is complete for every path that executes.

*Three failed attempts at this detector, all instructive, all in one sitting:*

1. The write-side check tested `!versabus_is_device(addr)` — **never true**,
   because `versabus_write` is only reached *for* device addresses. Dead code
   reporting zero.
2. Replacing it with an `else` on the dispatch chain broke the braces, and the
   chain's tail is nested so the `else` would have bound to an inner `if` even
   once braced. It is now an explicit range test, independent of the chain shape.
3. **Twice I read results from a stale binary** after a failed compile, and both
   times the numbers looked plausible — zeros, which is what the working
   detector also reports. The build now gets checked before anything is measured.

The through-line matches the rest of this session: **an instrument that cannot
fire reports zero, and zero reads as "no problem".** Three of the five
instrument defects found today had exactly that shape, and the only defence is
to establish that the instrument *can* fire before believing that it did not.

### The run now reports its own instrumentation

Three measurements this session came back **empty for instrumental reasons
rather than machine ones**, and each initially read as a finding:

- the bus log does not record the `$400000` window, so phases `$20`-`$29` looked
  as though they touched nothing but board status;
- `FPS3K_LOGCHASSIS` writes to **stderr** while `-bus` redirects only the bus
  file, so two attempts at the MODE2 correlation returned nothing;
- `FPS3K_SEQ` silently overrode `FPS3K_RESP`, so a five-point sweep returned five
  identical values and looked like "this variable has no effect".

An empty result that looks like a finding is the expensive failure, so every run
now ends by stating what was instrumented and where each channel went:

```
[done] hooks active: (none - DEFAULT configuration)
[done] log channels: bus=(off)  chassis-mem=(off - NOT in the bus log)
                     uninit=(off)  chassis-uninit=(off)
```

and with hooks set:

```
[done] hooks active: FPS3K_XPIRQ=1 FPS3K_LOGCHASSIS=1
[done] log channels: bus=(off)  chassis-mem=stderr  ...
```

The `chassis-mem=(off - NOT in the bus log)` wording is deliberate: that channel's
absence from the bus log is the specific trap that cost two attempts, so the
summary names it rather than merely omitting it.

*And the inventory immediately contaminated a measurement of its own. The
vector-write check counted the string `VECWATCH` in stderr; the new summary
prints `FPS3K_VECWATCH` when that hook is set, taking a count of 4 to 5. The
check now matches the bracketed log tag `[VECWATCH]`. Adding an instrument
changed a reading — which is the same lesson, arriving one level up.*

### The firmware never pages the chassis window — so do not model paging

The previous section noted a latent gap: the model backs `$400000-$4FFFFF` with a
flat 1 MB array and ignores MODE2, so every page maps to the same megabyte, and
the three unpopulated `MAIN DATA` slots are not modelled as absent. Before
building that, it is worth asking whether the firmware uses paging at all.

**It does not.** A full boot writes MODE2 (`$FF0210`) nine times:

| value | PC | what |
|---|---|---|
| `$10` | `$F09560` | phase `$16`, the XLTR register-file walk |
| `$0F` | `$F0A1E0` | init, immediately zeroed again at `$F0A1FE` |
| `$00` | ×7, incl. `$F09AE2`, `$F09B24` | before each data walk |

And correlating the page in force against every chassis-memory access —
**262,292 of them, from six PCs** — puts **all of them on page 0**. The two
non-zero writes are register tests, not page selects: phase `$16` walks the XLTR
file, and init sets `$0F` then clears it eight instructions later.

Two conclusions.

**The flat 1 MB backing is adequate**, and implementing MODE2-indexed pages or
absent card slots would change nothing observable for this firmware. That is the
useful result: it is an argument against writing the code, not a gap to close.
Building a paging model here would be speculative work whose correctness nothing
could test.

**And the firmware's reach matches the hardware population.** It only ever
addresses page 0 — the first megabyte — which is exactly the one `MAIN DATA` card
this chassis has. Whether that is configuration for this machine or simply
because SCM paging is driven by the chassis rather than the SBC is not
established, but the two facts agree.

The bounded form of the claim: **for this firmware, on the boot and self-test
paths that execute, chassis paging is never used to address beyond the first
megabyte.** A microcode upload driving the chassis through the full command
protocol might well page, and nothing here rules that out.

*Method note: the first two attempts at this correlation returned nothing,
because the bus log does not record the chassis window (the blind spot fixed
earlier) and because `FPS3K_LOGCHASSIS` writes to stderr while `-bus` redirects
only the bus file. Two separate output paths, and the measurement needed both.*

### Chassis memory: the zero-fill is safe too, for the same reason

The SBC-side finding — the firmware never reads a DRAM byte it has not written,
so the parity strap is not a hazard for it — raises the same question for the
**MAIN DATA card**. `chassis_mem` is a zero-filled 1 MB array, a real card powers
up random, and self-test phases `$28`/`$29` walk that window 131,072 times.

`FPS3K_CHASSIS_UNINIT=<file>` now answers it. A full boot reads
never-written chassis memory **six times**, all at `$400000` (bytes 0 and 1,
three times over), all from **PC `$F096AC`**:

```
$F096AC  move.w (a1),d0      <- the probe read
$F096AE  nop / nop / nop / nop
$F096B6  rts
```

That is `ChassisProbe_Read`, and **the value is discarded** — four NOPs then
`rts`, `d0` never used. The routine tests whether the access *bus errors*, not
what the data is; the NOP padding exists so the 68000's asynchronous bus error
lands at a predictable PC. Its write counterpart at `$F096B8` has the same shape.

So the zero-fill is harmless on the chassis side as well, and for a sharper
reason than on the SBC side. It is not that the firmware always writes before
reading — here it genuinely reads unwritten memory — but that **the six reads it
makes are the only ones whose data it does not care about.**

This also confirms a pre-existing annotation by measurement rather than by
reading: the note calling `$F096AC`/`$F096B8` bus-error probes with deliberate
NOP padding is right, and the fact that `$400000` is never written before being
read is independent evidence for it.

The chassis window's **size** happens to be right too: `CHASSIS_MEM_SIZE` is
1 MB, and the one populated `MAIN DATA` card is 256 Kwords × 32 bits = 1 MB. The
three unpopulated card slots are not modelled as absent, so a firmware routine
that sized the whole 4 MB space would find memory the machine does not have —
but no routine does, since phases `$28`/`$29` walk only `$400000`-`$404000`.

### The model now defaults to the machine, not to an empty chassis

`FPS3K_CHANNELS` defaulted to **0** — a chassis with no XP cards at all. That is
not the machine being emulated: the chassis index plate shows the **2-AC
configuration**, AC1 and AC2 populated in slots 7-10, AC3 and AC4 absent.

The consequence was not cosmetic. `$105E` is the channel-present count, and with
it at 0 the presence gate at `$F07DF6` took the skip branch in **every task, in
every run, by default** — so the four XP tasks self-gated off unless someone
happened to set the hook. The default configuration modelled a machine nobody
has.

The default is now **2**, and it is free: `CHANNELS=0` and `CHANNELS=2` both boot
to `final PC = F00FCC` with 1,032 self-test PCs and **zero** error-flag hits, and
the harness passes 132/132 either way. `=2` adds exactly the two present-path
instructions.

By default the model now reports:

```
$105E = 2                       (was 0)
XP1I present path  F07E00  reached
XP2I present path  F07400  reached
XP3I / XP4I        skip path     (correct - not populated)
probe increments   F0A20A, F0A212 both execute
```

`FPS3K_CHANNELS=0` still models an empty chassis when that is the experiment.

This is a small change with a general point behind it: **for whole-machine
emulation the default has to be the machine.** A hook whose default describes a
configuration that does not exist is not a neutral starting point — it silently
suppressed four of the six tasks, and every coverage figure this project has
quoted was measured against it.

### Auditing the hooks against each other: four silent conflicts

Four defects in a row were hooks overriding each other, so the interactions
themselves were audited rather than waiting for the fifth. Scanning both emulator
sources for `getenv("FPS3K_*")` sites and recording which module-level state each
one writes finds **four genuine conflicts** (the rest of the matrix is
loop-variable noise):

| ignored | wins | shared state |
|---|---|---|
| `FPS3K_RESP` | `FPS3K_SEQ` | the MODE0 response code |
| `FPS3K_CHSEL_RD` | `FPS3K_SEQ` | the `CHANNEL_SELECT` readback |
| `FPS3K_RESP` | `FPS3K_INJECT` | MODE0 + the BIM0 ch0 request |
| `FPS3K_MBOX` | `FPS3K_APIF_LEGACY` | `mailbox.host_status` |

The second is the same shape as the one already found: `versabus_seq_chsel` is
consulted **before** the `FPS3K_CHSEL_RD` branch, so a scripted sequence silently
wins there too. Nothing had exercised that pair.

All four now warn at startup, naming which hook is ignored and what state is
contested. The reasoning is recorded in the code: **the dangerous failure is not
a wrong value but a flat one.** A sweep run with a conflicting hook set returns
identical results at every point, and identical results read as "this variable
has no effect" rather than as a broken experiment — which is precisely what the
`FPS3K_RESP` sweep did before the conflict was removed, five identical
measurements that became a 17-PC spread.

For whole-machine emulation this is the standing hazard rather than an incident:
**24 hooks stand in for absent hardware**, and the pairs that quietly cancel each
other cost more than the ones that are simply wrong, because a wrong value
eventually contradicts something and a cancelled hook never does.

### The chassis's default response code is the worst one for exploration

With commands now interpreted, the response code the chassis returns is the
variable that changes SBC behaviour. Sweeping it — `FPS3K_RESP`, in a fixed
`CHANNELS=2 XPIRQ=1` configuration:

| response code | RDHC distinct PCs |
|---|---|
| `$02` | **65** |
| `$0B` | **65** |
| `$00` | 52 |
| `$08` | 50 |
| **`$14`** — the model's default | **48** |

**The default is the least informative of the five.** `$14` is `D2_FIN`, the
finalize code, and it was chosen because it is the one code whose meaning this
project knows. That is a good reason for a default that must be *safe* and a bad
one for a default that must be *informative*: answering every command with
"transaction complete" ends the conversation immediately, which is exactly what
the coverage shows.

`$F0572C` — the 42-entry `PanelStatusDispatchTable` site — is **still never
reached** at any code, consistent with the documented finding that the table
belongs to a different caller.

#### A fourth instrument defect: two hooks that silently conflicted

The first attempt at this sweep produced **five identical results** and looked
like proof that the response code has no effect. It was run with `FPS3K_SEQ`
still set, and `versabus_seq_take` overwrites `panel_resp_code` — the scripted
sequence wins, silently, and `FPS3K_RESP` is ignored. Removing the conflict
turns "no effect" into a 17-PC spread.

The emulator now prints a warning once when both hooks are set. That matters
beyond this sweep: a hook that is silently ignored produces a *flat* result,
and a flat result reads as a negative finding rather than as a broken
experiment.

*Four instrument defects this session: the bus log's blind spot on `$400000`,
the write-tracking gate that treated zero writes as non-writes, the `arm=` line
that reported a different decision from the code, and now two hooks that
override each other without saying so. Each produced a confident wrong number,
and the flat-result case is the most dangerous because it looks like knowledge.*

### The chassis never interpreted the commands the issuer sent

Toward whole-machine emulation, the chassis model had a structural gap: it
processed a panel command only when the SBC wrote **`$8004`** (REQUEST-TRANSFER)
to `$FF0000`. But **the panel-command issuer never writes `$8004`.** All eight
copies write the code to `$FF000E`, adjust MODE1/MODE0, write `CHANNEL_SELECT`,
and spin; `$8004` belongs to the channel ISRs.

So every command the firmware issued through an issuer was answered with a
generic `$14` and **never looked at**. The chassis now interprets the code
staged at `$FF000E` at the moment the issuer completes the command — i.e. on the
`CHANNEL_SELECT` write with MODE1 bit 12 set. Driving the S-record path now
shows `panel cmd 0x25F (PCMD_CH3_CONFIG)` reaching the chassis, where before
nothing did.

**Coverage is unchanged — 0 new PCs — and that is the expected result.**
Interpreting the command changes what the chassis *sees*, not what the SBC
*executes*, because the response returned is still the generic `$14`. The gap
closed here is a precondition for per-code responses, not a behavioural change
in itself.

#### And a diagnostic that reported the wrong decision

The `[PANEL] CHANNEL_SELECT` log line printed `arm=yes` whenever the ACK bit was
clear, **ignoring the MODE1 bit-12 gate immediately below it**. Since the
self-test phase beacon writes to this same register, every one of the **32,972**
beacon writes in a boot logged `arm=yes` while nothing was armed. Reading that
log is what first suggested the beacon was arming responses; it was not.

The line now reports the actual decision, and the true count of armings in a
full boot plus a scripted sequence is **one** — the `$025F` command above.

*This is the third instrument defect found this session, after the bus log's
blind spot on `$400000` and the write-tracking gate that treated zero writes as
non-writes. All three produced specific, confident, wrong numbers, and none was
found by re-reading the firmware.*

### The emulator's host-byte model was wrong *and inert* — now corrected

Working toward whole-machine emulation, the AP I/F host-byte path turned out to
still implement the protocol this project disproved. `versabus_inject_apif_byte`
wrote the host byte into **channel 1's data ports** (`$FF0048`, `$FF004E`) and
presented **`$4F`** at `$FF004A`, and `chassis_process_panel_cmd`'s `$281`/`$282`
arms did the same. All three are wrong:

- `$FF0048`/`$FF004A`/`$FF004E` are **TCBXP1I's** registers. The only absolute
  reference to `$FF0048` in the ROM is a *write*, in XP1I, and the reads come
  from XP1I's own ISR as `$48(a5)`.
- **`$4F` never appears at `$FF004A`.** It occurs five times, all as
  `move.w #$4f,(a3)` with `a3` a BIM control register — the IRE-cleared form of
  `$5F`. It entered the docs from `host_sim.c`, and the docs then cited the
  emulator as evidence.
- the host payload rides in the **mailbox pair**, `$70001C` in and `$700020` out.

This is the code-side resolution of `ds2/ADVERSARIAL_REVIEW.md` D.3, which flags
the same conflict from the docs side (`$FF004A`: "status word" vs "data LOW").

**Two measurements make the correction safe, and both are worth recording.**

The regression harness passes **130/130 unchanged** after the removal, so no
verified finding depended on the invented model.

And running the same host transfer both ways — `FPS3K_APIF_LEGACY=1` versus
corrected — gives **identical execution**: 54 distinct TCBIO1I PCs, `$F05DFA`
once, `$FF0048` never read, in both. The channel-port writes and the `$4F`
status **had no effect on anything**. The firmware never read them.

That explains how the error survived so long. An invented protocol that
*changes behaviour* gets caught by the first contradicting measurement; one that
is inert looks like it is working and nothing ever disagrees with it. The tell
was not a failed test — it was noticing the value's provenance.

### Byte accesses to the VersaBUS window never happen

`ds2/ADVERSARIAL_REVIEW.md` F.4 flags that the emulator does not model what a
**byte-sized** access to a `$FF00xx` register does, and that the convention is
undocumented. Measured both ways, the gap is unreachable:

- **Dynamically: 0 byte accesses** to `$FF0000-$FF02FF` or `$700000+` in a full
  boot, against **33,095** word and long accesses to the same window.
- **Statically: 0 sites.** No `move.b` anywhere in the ROM carries an
  `$FF00xx`/`$FF02xx` absolute operand.

  *The static check must test the addressing mode, not just the size field.
  `$11BC` is `move.b #imm,d16(An)`, and at `$F03FF2` its immediate plus
  displacement read as `$00FF0000` — the same false positive already recorded
  above for the kernel-boundary scan, and the same instruction. A first version
  of the regression check omitted the mode test and duly reported one hit.*

So the firmware accesses the VersaBUS side exclusively in 16- and 32-bit units.
The modelling gap is real but **the stock firmware cannot exercise it**, which
moves it from "unmodelled behaviour" to "unmodelled behaviour that nothing
reaches". It matters only for code this project writes — the monitor's `w`
command can issue a byte write to a chassis register, and what that does on
hardware is genuinely unknown.

Note the contrast with the *on-board* peripherals, where byte access on odd
addresses is the only correct form (`$F70001`, `$F70011`, …) and the emulator
raises BERR on even-byte access. The two sides of the board have opposite
access conventions, and the firmware observes both.

### Naming the top unannotated routines

**58 of the 100 call targets carry no annotation anywhere.** Working the
backlog by call count:

**`$F0A332` — BulkClear (8 calls).** Zeroes `d2 << 8` bytes ending at `a0`,
working downward:

```
move.l  d2,d6
lsl.l   #8,d6            ; d6 = d2 * 256
movea.l d6,a6
adda.l  a0,a6            ; a6 = a0 + d2*256
clr.l   d6
$F0A33C: move.l d6,-(a6) ; *--a6 = 0
cmpa.l  a0,a6
bgt     -> $F0A33C
rts
```

This is one of the two routines CLAUDE.md names as the source of the zeros a
write-watchpoint sees at `$10AA` — and `$F0A33C`, the address that document
cites, is the **loop body inside it**, not a separate routine. The other,
`$F0A1D2`, is the same shape.

**`$F05652` — the `$29`/`$2A` caller (2 calls).** This is where RDHC's two
otherwise-unexplained exclusive directives are issued, as a pair, with a small
parameter block built on the stack:

```
move.l  a0,-(a7)
move.w  #$0002,-(a7)
move.l  #$00000000,-(a7)
move.l  d1,-(a7)
movea.l a7,a0            ; PB = the stack
moveq   #$29,d0 / trap #1
move.l  a0,$4(a7)
movea.l a7,a0
moveq   #$2A,d0          ; ...and immediately $2A
```

So `$29` and `$2A` are not independent calls but a **matched pair**, taking a
stack-built block whose first fields are a word `$0002` and a zero longword.
That is as far as inference goes — what they do is still open — but it removes
them from the "called once each, arguments unknown" category: they are one
operation in two steps, called from one routine, twice.

**`$F055A2` (2 calls)** loads `#$10` and scales an index with `lsl`/`adda` — an
address-computation helper, not independently interesting.

### The most-called routine in the ROM is the self-test checkpoint

Censusing call targets — `jsr`, `jmp` and both `bsr` forms — finds **100
distinct targets, of which this project had named 9**. The most-called is
`$F0891C`, with **65 calls, every one from the init/self-test region**, and it
had no name at all:

```
$F0891C  movem.l d1-d2,-(a7)
$F08920  lea     $F70018,a2          ; board status
$F08926  btst    #4,$1(a2)           ; $F70019 bit 4
$F0892C  beq     -> $F08936
$F0892E  btst    #5,$1(a2)           ; bit 5
$F08934  bne     -> $F0894E          ; both set -> exit path $F088F4
$F08936  tst.l   d7                  ; THE ERROR FLAG ($F0F0F0F0 on failure)
$F08938  beq     -> $F08952          ; clean -> return
$F0893A  lea     $1FFF0,a1
$F08940  bclr    #6,$1(a1)           ; clear VMOD control bit 6
$F08946  move.w  #$1000,$202(a6)     ; XLTR MODE1 <- $1000
$F08952  movem.l (a7)+,d1-d2
$F08956  rts
```

**This is where a self-test failure becomes externally visible.** It is called
once per subtest — which is why 65 — and does two things when `d7` is set:
clears **bit 6 of the VMOD control register at `$1FFF1`**, and writes **`$1000`
to XLTR MODE1**. `$F08940` is the **only** bit-6 operation on that register
anywhere in the ROM.

Per this project's own chassis model, `$F70019` bit 5 mirrors `$1FFF1` bit 6
directly, so clearing it changes what the board reports back. That pairs with
the phase beacon: **the beacon at `$FF0204` says which subtest, and this routine
is what signals that one failed.**

In every configuration tested the error path at `$F0893A` **never executes** —
no self-test failure in any run — so the signalling path itself is unexercised
and its effect on real hardware is inferred from the two writes, not observed.

*Correction made during this analysis: `$08A9` was first read as `bset`, which
inverted the meaning — it is `bclr`. The encoding is bits 7-6 of the opcode
word: `00` btst, `01` bchg, `10` bclr, `11` bset. The error path clears bit 6,
it does not set it.*

**91 of 100 call targets remain unnamed.** The nine named are the eight issuer
copies plus the dispatch sites this project decoded; everything else — the
`$F0A306` shared error path (16 calls), `$F0A332` (8), `$F05678` (7), the
`$F096AC`/`$F096B8` chassis probes (4 each) — is either annotated in the asm
without being in any table, or genuinely unlabelled.

### Complete RMS68K marker census: 12 tags, 7 undocumented

CLAUDE.md lists five structure markers. Scanning both ROM and post-boot RAM for
`!` followed by three capitals finds **twelve**, and identifies every remaining
unlabelled block in the RAM map:

| tag | ROM | RAM | address | reading |
|---|---:|---:|---|---|
| `!TCB` | 13 | **6** | `$1E900 + $200*n` | task control block |
| `!TST` | 1 | **6** | `$1EA60 + $200*n` | per-task, TCB+`$160` |
| `!UDR` | 1 | **1** | `$1F600` | — |
| `!PAT` | 1 | **1** | `$1F700` | 30-byte linked entries, a pool or free list |
| `!IDV` | 1 | **1** | `$1F800` | — |
| `!IOV` | 1 | **1** | `$1F900` | I/O vector — CLAUDE.md's memory map already names "IOVs" |
| `!UST` | 1 | **1** | `$1FB00` | User Segment Table — the (task, queue) directory |
| `!GST` | 1 | **1** | `$1FD00` | Global Segment Table |
| `!ASQ` | 2 | 0 | — | code exists, no tagged instance |
| `!CCB` | 1 | 0 | — | " |
| `!DLY` | 1 | 0 | — | " |
| `!VCT` | 2 | 0 | — | " |

**Seven were undocumented**: `!GST`, `!IDV`, `!IOV`, `!PAT`, `!UDR`, `!UST`,
`!VCT`. Two of them — `!GST` and `!UST` — were named in the asm annotations but
never made it into the marker list.

`!PAT` at `$1F700` is the most structured of the new ones: a linked list with
entries at `$1F714`, `$1F732`, `$1F750`, `$1F76E`, `$1F78C`, `$1F7AA` —
**stride `$1E`, thirty bytes** — each holding `$FFFFFFFF` and otherwise empty,
which reads as an unallocated pool. Six entries, matching the six tasks.

The expansions above are **inference from the tag letters and the contents**,
except `!IOV` (CLAUDE.md's memory map already lists IOVs) and `!GST`/`!UST`
(named in the asm annotations). `!PAT` and `!UDR` are not expanded here because
nothing establishes what they stand for.

**With this the RTOS working set is fully mapped.** Every one of the runs in the
post-boot occupancy table above now has an identity: six TCBs, six `!TST`
blocks, five untagged ASQ blocks, and one each of `!UDR`, `!PAT`, `!IDV`,
`!IOV`, `!UST`, `!GST` — plus the vector table, the stack, and two small global
areas.

### Which RTOS structures actually get created

Searching post-boot RAM for the five RMS68K markers:

| marker | in ROM | **created in RAM** |
|---|---|---|
| `!TCB` | 13 sites | **6** — `$1E900 + $200*n` |
| `!TST` | 1 site | **6** — `$1EA60 + $200*n`, i.e. TCB+`$160` |
| `!ASQ` | 2 sites | **0** |
| `!CCB` | 1 site | **0** |
| `!DLY` | 1 site | **0** |

Only task control blocks and `!TST` structures exist at runtime, both one per
task on the same `$200` grid.

**No `!ASQ`-tagged structure is created, but the queues do exist** — the
question left open by the marker search is resolved by looking for the names
instead of the tag. Directive `$2D` creates two things, neither tagged `!ASQ`:

**A 20-byte per-task ASQ block**, on the `$200` grid, in **reverse task order**
— the opposite of the TCB order:

| address | task | queues |
|---|---|---|
| `$1E700` | XP1I | `AXP1` +0, `HXP1` +`$A` |
| `$1E500` | XP2I | `AXP2`, `HXP2` |
| `$1E300` | XP3I | `AXP3`, `HXP3` |
| `$1E100` | XP4I | `AXP4`, `HXP4` |
| `$1DF00` | IO1I | `HIO1` only |

Each entry is the **same 10-byte shape the task header carries at `+$2C`/`+$36`**
— name, two zero bytes, a 16-bit value, then `$0002`. The 16-bit values run
`$14 $2A $40 $56 $6C $82 $98 $AE $C4` across the nine queues in task order:
`$14 + index*$16`, so every queue has an index and something downstream is 22
bytes per queue.

**And a `!UST` directory at `$1FB00`** — the User Segment Table — holding nine
**22-byte** `(task, queue)` entries starting at `$1FB14`:

```
XP1I/AXP1  XP1I/HXP1  XP2I/AXP2  XP2I/HXP2  XP3I/AXP3
XP3I/HXP3  XP4I/AXP4  XP4I/HXP4  IO1I/HIO1
```

`$1FB14 + 22*n` for n = 0..8, ending exactly on the `IO1I`/`HIO1` entry at
`$1FBC4`.

**The stride corrects an earlier claim and explains a loose end.** This document
first said "nine 14-byte pairs"; the stride is **22** = `$16`, and `$16` is
exactly the step in the per-task ASQ blocks' 16-bit values (`$14 + index*$16`).
Those values are **offsets into this table** — the loose end noted earlier as
"something downstream is 22 bytes per queue" is this directory.

So the attachments are recorded twice: once per task, once globally. `$2D` is
therefore an **ASQ attach that registers a name**, and the absence of an
`!ASQ` marker means RMS68K tags only some of its structures, not that the call
did nothing. The kernel's `!ASQ` code at `$F015EA`/`$F023B6` presumably builds
the tagged form when a queue is actually used.

The 164-byte companion block at `$1E9F8 + $200*n` is not marker-tagged. Its
contents point back into the task's own ROM structures — XP1I's copy holds
`$00F07E1C`, `$00F07D00` and `$00F07D34`, which are its body, its descriptor
base and its ASQ-name area.

### Complete post-boot RAM map: 3% touched, 115.5 KB free

Scanning the whole 128 KB at longword granularity after a clean boot:

| range | bytes | what |
|---|---|---|
| `$00000-$00807` | 2,056 | vector table, stack fill, stack top |
| `$00BC4-$00C9B` | 216 | globals |
| `$01108-$0110F` | 8 | two longwords |
| `$1DF00-$1DF0B` | 12 | RTOS |
| `$1E100`/`$1E300`/`$1E500`/`$1E700` | 20 each | four small blocks, stride `$200` |
| `$1E900`+`$200`*n | 116 each | **the six TCBs** |
| `$1E9F8`+`$200`*n | 164 each | six companion blocks (ASQs?) |
| `$1F500`-`$1FFFF` | ~770 | RTOS tables, `$1FFD0` supervisor stack |
| **total** | **4,828** | **3% of 131,072** |

**Free: `$01110-$1DEFF` — 115.5 KB contiguous**, plus 1.1 KB at
`$00C9C-$01107`.

Three things follow.

**The staging-buffer ceiling is confirmed from the other direction.** Nothing
between `$01110` and `$1DEFF` is touched, and everything from `$1DF00` up is,
so `$1DEFF` is exactly where the usable region ends — the same boundary the
TCB finding gives.

**The monitor's workspace choice was right.** It sits at `$0F800-$0FF00`,
inside the free span and nowhere near either cluster. The relocation from
`$1F000` moved it out of what is now demonstrably live RTOS memory.

**The per-task RAM is regular.** Each task owns a 116-byte TCB at
`$1E900 + $200*n` and a 164-byte block at `$1E9F8 + $200*n`, and four further
20-byte blocks sit at `$1E100`-`$1E700` on the same `$200` stride. The whole
RTOS working set is one `$200`-strided array per structure type.

*Method note: a first pass at this scanned for runs of nonzero **bytes** and
reported `$00000-$00403` as free — the vector table, missed because every
vector is `$00Fxxxxx` and the leading zero byte breaks each entry into a
3-byte fragment that a "runs ≥ 4 bytes" filter discards. Longword granularity
is the right unit for a map of 32-bit structures.*

### The live TCBs sit INSIDE the WCS staging buffer — the 64 KB claim is unsafe

Sweeping post-boot RAM for repeated longwords turns up `$21544342` six times —
`!TCB` — and they are **live task control blocks, inside the staging buffer**:

| address | task | entry point at `+$6C` |
|---|---|---|
| `$1E900` | XP1I | `$F07D4A` |
| `$1EB00` | XP2I | `$F0734A` |
| `$1ED00` | XP3I | `$F0694A` |
| `$1EF00` | XP4I | `$F05F4A` |
| `$1F100` | IO1I | `$F05D36` |
| `$1F300` | RDHC | `$F046F0` |

Stride `$200`. Each carries the marker `$969696` at `+$24`, the task name at
`+$10`, its entry point at `+$6C`, and a forward link at `+$04` — `$1E900` →
`$1EB00` → … → `$1F300` → `$0`, so they are a null-terminated list in task
order.

**Live RTOS data occupies `$1DF00-$1FFFF`** — 794 nonzero bytes spread across
the top **8.25 KB** of what this project calls the microcode staging buffer.

#### Two load-bearing claims are unsafe as written

CLAUDE.md says:

> The 64 KB staging buffer at `0x10000–0x1FFFF` exactly equals one WCS bank —
> so each S-record session loads one bank.

and, of the monitor:

> the full 64 KB WCS bank at `$10000-$1FFFF` is loadable end to end (verified
> by loading `$1FFE0` and `$1FFF0`)

**Loading `$1FFE0` and `$1FFF0` overwrites live RTOS data, and filling the
buffer end to end destroys all six TCBs.** The verification held only because
nothing in that emulator run subsequently scheduled a task. On hardware it
would take the RTOS down.

The genuinely usable staging region is **`$10000-$1DEFF`, about 56.75 KB** —
**less than one 64 KB WCS bank.**

#### The architectural consequence

If a WCS bank really is 4K × 128 bits = 64 KB, **it cannot be staged in a
single pass.** Three ways out, none established:

1. the bank is uploaded in two or more pieces;
2. the "staging buffer = exactly one bank" correspondence is a coincidence of
   round numbers rather than a design fact — the firmware's own range check
   allows `$10010-$1FFFF`, which is not 64 KB either;
3. the RTOS relocates or the upload happens with tasks stopped.

`SRecordDataHandler`'s range check permits writing over the TCBs, so the
firmware does not protect them. Anyone driving a real upload should treat
`$1DF00` as the ceiling until this is settled.

### The firmware fills its stack with `$09ABCDEF` — a free high-water gauge

`$F08886` is `lea $0800,a7`, so the supervisor stack top is **`$0800`**, and the
kilobyte below it is pre-filled with the repeating longword **`$09ABCDEF`**,
from **`$0404`** upward — the longword at `$0400` itself is left zero. That is a stack-fill pattern, and it makes stack depth
measurable from nothing but a memory dump: scan down from `$07FC` and the first
longword that is no longer `$09ABCDEF` is the high-water mark.

| configuration | deepest stack use | pattern longwords intact |
|---|---|---|
| clean boot | **76 bytes** of 1,024 | 236 of 256 |
| the `$281` deadlock | **1,024 of 1,024 — exhausted** | **0 of 256** |

A healthy machine uses **7.4%** of its supervisor stack. The deadlock consumes
all of it and then writes 764 bytes of vector table, which is the overrun the
previous section measured from the other side.

**This is usable on hardware.** Dump `$0400`-`$07FF` from a live board — the
monitor's `m` command does it — and count surviving `$09ABCDEF` longwords. 236
means normal; a low count means something recursed; zero means the vector table
below is already damaged and the machine is running on borrowed time. No
debugger, no instrumentation, one memory dump.

Note also what sits immediately below: **the vector table, with no guard region
at all.** `$0400` is the stack floor and `$03FF` is the top of the vector table.
The firmware's own margin is the 948 bytes it does not normally use.

*Method note: the first attempt at this measurement scanned upward from `$0400`
and reported "1,020 bytes used, 4 bytes of headroom" — exactly backwards, and
wrong by a factor of thirteen. A surviving pattern means the stack did **not**
reach that address. The high-water mark is found scanning down from the top,
not up from the floor.*

### The `$281` deadlock is worse than a hang: it destroys the vector table

`FPS3K_VECWATCH` used to watch four bytes — `$128`-`$12B`, TCBIO1I's vector —
because that is the one a re-entrant ISR corrupted in the incident that caused
an earlier retraction. Widened to the whole table, with a `post` mode that
reports only writes after the RTOS is up, it turns a one-off diagnosis into a
standing check. Running it over every configuration this session used:

| configuration | post-boot vector writes |
|---|---|
| plain boot | 4 |
| `CHANNELS=2 XPIRQ=1 CHCMD=C801` | 4 |
| `XPIRQ=5 DMA10AA=2 MBOX=$00010000` | 4 |
| **`XPIRQ=5,6 DMA10AA=2 MBOX=$20010000`** | **729** |

The four are benign and identical in every case — `$104 ← $00F04930` from
`PC=$F02278`, the kernel installing RDHC's vector, which simply happens after
TCBIO1I's in the boot order.

**The 729 are not.** They span `$000104` to `$0003FF` — the entire vector table
— and come from `PC=$F05DD6` (483), `$F05E86` (146) and `$F05E0C` (96): the
TCBIO1I ISR entry, the spin, and the call into the issuer. `$F05DD6` is
`movem.l <regs>,-(a7)`. **The stack has walked down through the vector table.**

The mechanism is a 68000 property this project had not connected to the
deadlock: **level 7 is non-maskable**. A handler spinning at IPL 7 can still be
re-entered by a new level-7 edge, and each re-entry pushes a frame. The task
stack is `$190` — 400 bytes — so it overflows quickly, and the vector table sits
just below.

**This does not undermine the deadlock finding; it sharpens it.** The load-
bearing datum was that the rescuer `F04930` executes *zero* times while the
spin executes 18,135, and stack corruption cannot manufacture a zero. What
changes is the severity: issuing a panel command from a channel ISR does not
merely hang the task, it **overruns the stack into the vector table**, which on
real hardware ends in a double bus fault and a halted CPU rather than a quiet
spin.

**One caveat, stated plainly.** The re-assertion is driven by this project's
own hook at a fixed 200,000-cycle interval. Whether a real chassis re-raises
the channel interrupt while the SBC is spinning is unknown, and if it does not,
the ISR is entered once and the stack survives. The stack overflow is therefore
conditional on repeated interrupts; the deadlock itself is not.

### The firmware never reads untouched DRAM — parity is not a hazard for it

CLAUDE.md's "Known divergences" table warns that real DRAM powers up with
invalid byte parity, that reading never-written memory can raise a bus error
if the parity strap is enabled, and that `clr` on untouched DRAM is a risk
because a 68000 reads the destination first. The emulator has always carried a
hook to detect exactly this (`FPS3K_UNINIT`), and it had never been run.

Run, it reported **302,649 reads of never-written RAM** across a full boot —
alarming, and wrong. The top offender was `$F08952`, which is
`movem.l (a7)+,d1-d2`, a **stack pop**; 253,883 of the reads were in the stack
page `$01Fxxx`.

The cause was one gate in the instrument:

```c
if (a < RAM_SIZE && v) ram_written[a] = 1;   /* nonzero writes only */
```

**A write of zero did not mark the byte as written**, so every stack push of a
zero byte — the high half of a small value, a cleared register — made the
matching pop look like a read of untouched memory. On real hardware a write of
zero establishes parity exactly like any other value.

With the gate removed, a full boot reports **zero** reads of never-written
DRAM. Not "few" — none.

**So the stock firmware maintains the discipline the hardware requires**: every
byte it reads, it has written first. The parity strap is not a hazard for it,
and the "Known divergences" warning, while correct about the hardware, does not
describe a risk this ROM takes.

It also retroactively validates the in-ROM monitor's precautions — using
`move.l #0` rather than `clr`, and having `cold_init` pre-write its whole
workspace including `MON_REGS`. Those were adopted defensively; the stock
firmware turns out to follow the same rule, so the monitor is consistent with
the machine rather than merely careful.

*Two instrument bugs in two consecutive investigations — the bus log's blind
spot on `$400000` and this write-tracking gate — both of which produced
confident, specific, wrong numbers. Neither was found by re-reading the
firmware; both were found by asking what the tool could not see.*

### The two-trap architecture, and TRAP #2-#15 are free

Sweeping **every** `TRAP #n` in the image, not just `TRAP #1`:

| trap | sites | where | directives |
|---|---|---|---|
| **#0** | 12 | kernel ×2, RTOS-init ×9, pre-task ×1 — **never in a task** | `$04` ×8, `$06`, `$16`, `$18`, `$1F` |
| **#1** | 71 | the six tasks only — **never in the kernel or init** | 14 distinct |
| **#2-#15** | **0** | — | — |

The split is exact and it is the cleanest architectural statement in the ROM:

- **`TRAP #0` is initialisation-time.** Eight of its twelve sites carry
  directive `$04` and sit between `$F09E78` and `$F0A020` — the stretch that
  builds the `!GST` and `!UST` segment tables — so `$04` is plausibly a
  segment or allocation call. The remaining four are one each of `$06`, `$16`,
  `$18` and `$1F`.
- **`TRAP #1` is runtime.** Every one of its 71 sites is inside a task region.

**No task ever issues `TRAP #0`, and no initialisation code ever issues
`TRAP #1`.** Combined with the earlier boundary test — no direct calls in
either direction, one hand-placed stub excepted — the firmware's internal
interfaces are: traps for kernel services, and a single panel-command issuer
replicated eight times for chassis I/O. Nothing else crosses.

**Practical consequence: `TRAP #2` through `TRAP #15` are entirely unused.**
The in-ROM monitor takes `TRAP #14` for breakpoints, and this confirms there is
no conflict — not by assumption but by sweep. It also means fourteen trap
vectors are available to anyone instrumenting this firmware.

### Definitive panel-code census: 41 codes

Tracing every site that loads `d0` and then reaches one of the **eight issuer
copies** — by `jsr` *or* by branch — gives the complete set:

```
$258 $259 $25A $25B $25C $25D $25E $25F $260 $262 $263 $264
$269 $26A $26B $26C $26D $26E $270 $271
$276 $277 $278 $279 $27A $27B $27D $27E $27F $280 $281
$29E $29F $2A0 $2A1 $2A2 $2A3 $2A4 $2A5 $2A6   $2B2
```

**41 distinct codes.** Nine of them — the whole exception block `$29E`-`$2A6` —
are reachable **only by branch**, which is exactly why a `jsr`-only scan misses
them and why they went undocumented. Each `bra.w`s to `$F0A57E`, and that
confirms both halves of the previous finding: the exception codes really do
reach `$FF000E`, and **issuer copy 8 exists to serve the panic path**. The
issuer census could say copy 8 was there but not what for; now it can.

Two codes in this project's tables are *not* confirmed by this census:

- **`$282`** (`PCMD_HOST_NULL`) is loaded at `$F05E1A` but the following branch
  does not land on an issuer. It may reach the port by falling into shared
  code; this census does not show it, so treat the identification as
  unconfirmed rather than wrong.
- **`$261`, `$265`-`$268`, `$26F`, `$272`-`$275`, `$27C`** never appear at all,
  which is consistent with the gaps already noted for `$26F` and `$27C`.

The census also adds **`$25B`**, which the earlier per-region count missed.

### The panel port reports which CPU exception killed the board

Nine panel codes were undocumented. They form one table at `$F0A23A`, eight
bytes per entry, and each entry is `move.w #<code>,d0` followed by a branch to
the common panic path:

| handler | code | vector | exception |
|---|---|---|---|
| `$F0A23A` | `$29E` | 2 | **bus error** |
| `$F0A242` | `$29F` | 3 | **address error** |
| `$F0A24A` | `$2A0` | 4 | illegal instruction |
| `$F0A252` | `$2A1` | 5 | divide by zero |
| `$F0A25A` | `$2A2` | 6 | CHK |
| `$F0A262` | `$2A3` | 7 | TRAPV |
| `$F0A26A` | `$2A4` | 8 | privilege violation |
| `$F0A272` | `$2A5` | 15 | uninitialised interrupt |
| `$F0A27A` | `$2A6` | — | **the catch-all on 182 unused user vectors** |

**This is a hardware-visible diagnostic.** If the board dies, the last value
written to the panel command port at `$FF000E` names the exception class. A
bus error reports `$29E`; a stray interrupt on any unwired vector reports
`$2A6`. Nothing in this project's bring-up material mentioned it, and it costs
nothing to watch for.

CLAUDE.md listed only `$29E` and `$29F`, as "`PCMD_RTOS_29E/29F` — RTOS-side
operations". That is vague and slightly wrong: they are the bus-error and
address-error reporters, and they are the first two entries of a nine-entry
table.

### There is FPS code inside the RMS68K kernel region

The kernel is described as generic Motorola code ending at `$F04487`, and it
very nearly is. Testing both directions:

- **kernel → FPS: exactly one reference.** `$F001A4` is `jsr $F04500` — a call
  into the panel-command issuer, copy 1.
- **FPS → kernel: two references**, both `$F00000` from `$F08D24`/`$F08D36`,
  which are the ROM readback walk of phase `$0300` reading the ROM base as
  *data*. No FPS code ever calls a kernel routine directly.
- **FPS-specific constants inside the kernel: none.** `$FF0000`, `$F70018`,
  `$F70011`, `$1FFF0`, `$105E`, `$10AA` — zero real occurrences; the two
  apparent hits straddle instruction boundaries.

So the boundary is clean in every respect **except one FPS-authored stub**:

```
$F001A0  move.w #$02B2,d0
$F001A4  jsr    $F04500      ; the panel-command issuer
$F001AA  bra .               ; unreachable - the issuer never returns
```

It sits immediately before the TRAP #0 vector target at `$F001AC`, issues a
**tenth otherwise-unused panel code `$2B2`**, and hangs. `$2B2` occurs exactly
once in the whole image. This also accounts for the ninth `bra .` — the one the
issuer census attributed to "the kernel".

The architecture is therefore stricter than the address split suggests: the
application talks to the kernel **only through TRAP #0 and TRAP #1**, and the
kernel talks to the application through exactly one hand-placed stub.

### Sweeping the response codes does not unlock RDHC

The coverage measurement below names the bottleneck as "a chassis model that
drives the full command protocol". The cheapest approximation of that is to
script every response code the 16-entry dispatcher at `$F05102` accepts. It
was tried, and it does not work.

Driven one at a time, each code reaches a useful slice of RDHC:

| code | RDHC PCs | | code | RDHC PCs |
|---|---|---|---|---|
| `$03` | 82 | | `$0A` | 69 |
| `$04` | 48 | | `$0B` | 65 |
| `$05` | 68 | | `$0C` | 71 |
| `$06` | 72 | | `$0D` | 66 |
| `$07` | 62 | | `$0E` | 66 |
| `$08` | 50 | | `$0F` | 65 |
| `$09` | 62 | | | |

Chained into one sequence they reach **147 distinct RDHC PCs, 56 of them new**.
But in coverage terms that is **4,834 → 4,946 bytes**: RDHC goes from 7% to 8%
and the overall figure stays at 19%.

**And combining hooks makes things worse, not better.** A single configuration
with the full code sweep *plus* channel presence, XP and host interrupts, a
command word and an S-record source reaches **RDHC 2%** — below either the code
sweep alone (4%) or the five-config union (7%). Driving several subsystems at
once makes the firmware take different and shorter paths, so the best coverage
comes from unioning separate focused runs, never from one maximal
configuration. Worth knowing before anyone tries to build "the one config that
exercises everything".

The reason the sweep fails is already recorded as a modelling caveat: after the
SBC acknowledges, the emulator queues the next step itself rather than waiting
for another `CHANNEL_SELECT` write. A scripted sequence is therefore a
monologue, and RDHC's bulk sits behind a conversation. Closing that needs a
chassis model that *reacts* — which needs to know what the real chassis does,
which is what the bus trace in Check 7c would tell us.

### How much of this firmware has actually been executed: 19%

Taking the union of five diverse emulator configurations — a plain boot, an XP
channel driven to its `$8000` path, TCBIO1I driven on both arms, the mailbox
reply path, and a full S-record staging run — and comparing against the FPS
application region `$F04488-$F0A5FF`:

| region | executed | of |
|---|---|---|
| init / self-test | **52%** | 5,888 b |
| RTOS init | **41%** | 2,560 b |
| TCBIO1I | **30%** | 512 b |
| **TCBRDHC** | **8%** | 5,888 b |
| XP1I | 6% | 2,560 b |
| XP2I / XP3I / XP4I | 4% each | 2,560 b each |
| pre-task | 7% | 376 b |
| **overall** | **19%** | **24,952 b** |

**Four fifths of this firmware has never run**, in any configuration this
project has constructed. The largest dark spans are the four XP task bodies —
about 2,350 bytes each, 92% of each task — and the middle of RDHC.

This is the calibration the rest of this document needs, so it is worth being
blunt about which claims sit on which side.

**Execution-verified**: the self-test suite and its phase beacon; the S-record
staging path end to end; the XP channel ISR and its `$8004` transaction; the
`$8000`/`$1B` path and the command-word bits that gate it; the `$105E`
presence gate; TCBIO1I's two arms and the `$00010002` reply; the BIM
programming and the resulting vector table; the `$281` deadlock.

**Static only**: essentially all of RDHC beyond its prologue — the panel
command processor's internals, most of the host command dispatch, the SLC
parser paths; and 94-96% of each XP task body, including everything past the
bit-11 dispatch. Those readings come from decoding, and decoding is what
produced three wrong claims in the audit above.

The reason is structural rather than a gap in effort: **every task blocks on
directive `$13` within ~45 instructions of its entry**, and only an interrupt
advances it. Without a chassis model that drives the full command protocol,
most of this firmware cannot be reached. That, not the ROM, is the limiting
factor on further progress from the emulator side.

### Audit of the pre-existing annotations — result

The `fps3k.asm` note table carried **64 annotations** written before this
session. Auditing the checkable ones against decode and measurement:

| claim | verdict |
|---|---|
| 16 self-test phase labels (`$0200`-`$1700` at named entry points) | **all correct** |
| `$26E`-`$271` are per-STEP, not per-channel | **correct** — and predates this session's rediscovery |
| the vector fill skips `$230` alone | **correct** |
| BIM programming: 6 CRs cleared, 10 VRs loaded `$41`-`$4A` | **correct** |
| `$4245` = `"BE"` bus-error marker, five app sites | **correct** |
| host command dispatch: `andi #7` / `subq #1` / 4-entry table | **correct** |
| cmd 1 builds the ASQ name from `"HXP0"` + channel | **correct** |
| `$0F` = 15 = `TERM`, terminate task | **WRONG** — retracted |
| vector 140 "is meant to be **serviced**" | **WRONG** — it is made non-fatal |
| (CLAUDE.md) `$10A0` index 6 lands on `$10AA` | **WRONG** — index 6 is `$10A6` |

The phase labels verify by a direct measure: for each of the sixteen, the PC
that writes that phase's sub-step 0 falls **after** the claimed entry point, at
offsets `$06` to `$4A` with a median of `$1E` — exactly the spread expected for
a routine that does some setup before announcing itself.

**Three wrong out of the checkable set, and the three share a shape**: each was
a plausible identification that nobody had put a number to. `TERM EQU 15`
matched `$0F` numerically; "index 6" was close enough to `$10AA` to pass a
glance; "serviced" is what one assumes when a vector is deliberately preserved.
None survived arithmetic or a decode. The rest of the table held up, which is
the more important half of the result.

### Two corrections found while propagating notes into `fps3k.asm`

**A silent data-loss bug in the note table.** `NOTES` in
`tools/mk_consolidated_asm.py` was a dict literal, so when this session's
entries collided with pre-existing ones at the same address, Python kept the
last and the other vanished with no warning. **Fifteen addresses collided**
and thirteen of this session's notes were dropped. It is now a list of pairs
merged into a dict of lists, so both notes at an address emit. Note count went
143 -> 158 on that change alone.

**`$0F` is not `TERM`.** A pre-existing note at `$F07DF6` reads *"Only `$0F`
is identified: 15 = TERM, terminate task, per the RMS68K source."* The
directive census places `$0F` **once per task, at the tail of the ISR-exit
path**, and five of the six tasks share the exact sequence

```
44FC 000C   move #$0C,ccr
4E41        trap #1
700F        moveq #$0F,d0
4E41        trap #1
```

Terminating the task there would end it on its first interrupt. `TERM EQU 15`
matching `$0F` is a numeric coincidence with a source file whose other
directive numbers — `GTASQ 31`, `WTEVNT 36`, `RDEVNT 34`, `RTEVNT 37`,
`CMR 60` — match nothing in this ROM either. The identification is retracted in
the asm.

RDHC is the exception: its stub is `move #$0C,ccr / trap #1` followed by a
**`jmp` back into its own code**, not the `$0F` call. So the ISR-exit
*sequence* is five of six, while the two-instruction *stub* is six of six.

**And an honesty note on the `$26E-$271` finding.** A pre-existing note at
`$F07DD6` already said *"`$26E` = step 1/2, `$270` = step 3, `$271` = step
4/5 … this confirms `$26E`-`$271` are per-STEP, not per-channel."* The
annotated asm had it right before this session did. What this session added
was an independent confirmation by a different method — identical panel-code
multisets across all four XP tasks — and the propagation of the correction
into CLAUDE.md, which still carried the per-channel labels. The finding was a
rediscovery, not a discovery.

### RDHC's five exclusive directives

Resolving the parameter block at each of RDHC's own directive sites:

| site | directive | parameter block |
|---|---|---|
| `$F0477C` | `$0B` | `$F04614` — `USER`, then `$6464`, `$08000001` |
| `$F047C8` | `$0D` | `$F04630` — `USER`, then zeros |
| `$F04854` | `$12` | `$F04696` — **`XP4I`** |
| `$F04866` | `$12` | `$F0468E` — **`XP3I`** |
| `$F04878` | `$12` | `$F04686` — **`XP2I`** |
| `$F04884` | `$12` | `$F0467E` — **`XP1I`** |
| `$F04904` | `$12` | `$F0469E` — `USER` |
| `$F05664` | `$29` | none loaded by `lea` |
| `$F0566E` | `$2A` | none loaded by `lea` |

The five `$12` calls draw from a **6-entry, 8-byte-per-entry name table** at
`$F0467E`, each entry a 4-character name followed by four zero bytes:

```
$F0467E  XP1I
$F04686  XP2I
$F0468E  XP3I
$F04696  XP4I
$F0469E  USER
$F046A6  USER
```

So RDHC names each of the four XP tasks in turn — **in reverse channel order,
4, 3, 2, 1** — and then `USER`. This is the clearest structural expression yet
of RDHC's master role: the other five tasks each talk only about themselves and
their own channel, while RDHC is the only code in the ROM that addresses the XP
tasks *by name*.

What `$12` does is not established. It takes a task name and RDHC is the only
caller, which is consistent with a start, resume or task-lookup operation —
TDTI has already created all six tasks by this point, so it is not creation.
`$29` and `$2A` are called once each with no `lea`-loaded block, so their
arguments are in registers or they take none.

The sixth table entry, a second `USER` at `$F046A6`, has no `$12` call. It sits
immediately before RDHC's `$01` block at `$F046B0` and may belong to that
block rather than to the table.

### RDHC builds the per-channel ASQ names at runtime

A census of 4-character A-Z0-9 sequences turns up `HXP0` twice, at `$F053B8`
and `$F05478` — a name no task declares. Both sites load the same literal and then add the channel number:

```
$F053B6  223C 48585030   move.l #'HXP0',d1
$F053BC  D204            add.b  d4,d1        -> 'HXP1' .. 'HXP4'

$F05476  223C 48585030   move.l #'HXP0',d1
$F0547C  282E 0004       move.l $4(a6),d4    ; channel number from the frame
$F05480  D204            add.b  d4,d1
```

The second site fetches the channel number from its stack frame first, which
is the more informative of the two: the channel number is a **parameter**, so
this is a general "attach to channel *n*'s host queue" path rather than four
unrolled cases.

RDHC **constructs** the host-side queue name from a template by adding the
channel number to the last character. `HXP0` is therefore not a fifth queue; it
is the base string, never used as-is. This is how RDHC addresses the per-channel
queues that the XP tasks attach to via their header's `+$36` entry.

The census also confirms two counts: **`PROG` appears exactly six times**, once
per TDTI entry, and **`STCK` six times**, once per task — RDHC's inside its
`$01` block at `$F046BC`, the other five at `base+$20`.

#### `$F09BB6` is the diagnostics' pattern table

```
$F09BB6  00000000
$F09BBA  FFFFFFFF
$F09BBE  55555555
$F09BC2  AAAAAAAA
```

The four classic RAM-test patterns, which is what the `UUUU` hits in the census
were. Worth recording because the `$10AA` injection defect found earlier —
a location that reads back a constant fails a pattern test — is precisely a
failure against this table.

#### Method note: most 4-char "tags" are instructions

Of the 29 sequences the census found, the majority are code read as ASCII:

| "tag" | actually |
|---|---|
| `HA3A` ×15 | `4841 3341` — `swap d1 / move.w d1,…` |
| `HB3B` ×10, `HC3C` ×10 | the same idiom on d2 and d3 |
| `42HN` ×4 | `3432 484E` — the channel-scan `move.w $4E(a2,d4.l),d2`, once per XP task |
| `CBXP`/`CBIO`/`CBRD` | `!TCB` + task name, read two bytes off |
| `F0NA` | the tail of `lea $F04630,a0` plus `trap #1` |
| `UUUU` | the `$55555555` test pattern |

Only `USER`, `STCK`, `PROG`, `UPGM`, the task names and the `AXPn`/`HXPn`/
`HIO1` queue names are real tags. The `HA3A` family is a useful accident: it
counts the 32-bit-split idiom — `swap` then store the low half — which is how
this firmware writes every 32-bit value to the 16-bit channel data pair.

### RDHC's header, and the `$F046E0` BIM table located exactly

RDHC's prologue differs from the XP tasks', and decoding it explains its odd
header:

```
$F046F0  moveq #$01,d0 / lea $F046B0,a0 / trap #1   ; NOT base+$14
$F046FC  fail -> panel $0276
$F04710  moveq #$4C,d0 / lea $F04600,a0 / trap #1   ; interrupt triple, base+$00
$F0471C  fail -> panel $0277
$F0472A  movea.l #$FF0000,a5
$F04730  move.w  #$5E,$230(a5)                      ; own BIM CR, level 6
$F0473C  moveq #$13,d0 / trap #1                    ; block
```

RDHC connects its vector and then **immediately enables its own BIM at level
6** — the value that later makes it unable to preempt a level-7 channel ISR.

**Its `$01` block is at `$F046B0`, not `base+$14`**, and is richer than the XP
tasks':

```
"RDHC"  $20000000  "STCK"  0  $00000190
"USER"  $01000000  "UPGM"  $00010000  $0000D000
```

The first line is the same shape the XP tasks use. The second adds an owner,
a second tag `UPGM`, and an address/size pair. `$00010000` is the WCS staging
buffer base and `$0000D000` is 52 KB — suggestive of a program-segment
declaration over that region, but **that is a guess from two numbers** and
nothing here establishes it.

So what is the odd material in RDHC's *header*? It is two more parameter
blocks, for the directives only RDHC uses:

| header offset | address | used by | failure code |
|---|---|---|---|
| `+$14` | `$F04614` | **directive `$0B`** at `$F04774` | `$0278` |
| `+$30` | `$F04630` | **directive `$0D`** at `$F047C0` | `$027A` |

Both are named `USER`. That completes the picture from the previous section:
**a task's header holds parameter blocks for whatever directives that task
calls**, and RDHC's look different because its directives are different.

#### `$F046E0` is a four-entry BIM control-register table

Immediately before RDHC's entry point:

```
$F046E0  00000244
$F046E4  00000246
$F046E8  00000250
$F046EC  00000252
$F046F0  <RDHC entry point>
```

These are the four **XP channel BIM control registers** — `$FF0244`,
`$FF0246`, `$FF0250`, `$FF0252` — in channel order 1, 2, 3, 4. This project
has cited "the F046E0 lookup table" as corroboration for the channel-to-BIM
mapping; its exact location, extent and contents are now pinned: four
longwords, offsets not full addresses, ending where RDHC's code begins.

That makes **four** independent statements of the channel-to-BIM mapping in
this ROM: this table, the per-task CR writes, the constant-ownership map, and
the task descriptors' vector numbers.

### The task descriptor is the whole prologue's parameter block

Reading past `+$14` shows the header is not just an interrupt declaration —
it is a contiguous parameter-block region holding the arguments for every call
the prologue makes:

| offset | field | XP1I |
|---|---|---|
| `+$00` | task name | `XP1I` |
| `+$08` | interrupt vector | `$45` |
| `+$0C` | ISR entry | `$F07EE6` |
| `+$10` | ISR exit stub | `$F07F08` |
| `+$14` | **directive `$01` PB starts** — task name | `XP1I` |
| `+$1C` | flags | `$20000000` |
| `+$20` | stack tag | `STCK` |
| `+$28` | stack size | `$190` |
| `+$2C` | **ASQ entry 1** — name, zero, `$0002` (10 bytes) | `AXP1` |
| `+$36` | **ASQ entry 2** — same shape | `HXP1` |

So `$F07D14`, which this document identified earlier as "the parameter block
for directive `$01`", is simply `base+$14`, and the two ASQ names the prologue
copies onto the stack are two 10-byte entries at `+$2C` and `+$36`. Every
argument the five prologue calls need sits in one 64-byte header.

**The ASQ layout confirms the documented assignments independently:**

| task | ASQ entries |
|---|---|
| XP1I…XP4I | `AXP1`/`HXP1` … `AXP4`/`HXP4` — **two each** |
| IO1I | `HIO1` — **one**, with code beginning right after |

That is exactly what CLAUDE.md records from the TDTI table — `TCBIO1I`
(ASQ "HIO1"), `TCBXP1I` (ASQ "AXP1"/"HXP1") — reached here from the header
layout instead. It also explains why the XP prologue makes **two** `$2D` calls
and TCBIO1I makes one.

**RDHC's header has a different profile entirely.** Its `+$14` is `USER`, and
where the other five carry `STCK`, a stack size and ASQ entries it has
`$6464`, `$08000001`, `$00003000` and a second `USER`. It declares no ASQ and
no `STCK` block — consistent with its role as the master task, and with it
being the only task using directives `$0B`, `$0D`, `$12`, `$29` and `$2A`.

### The descriptor's `+$10` field is the ISR **exit stub**

Six `trap #1` sites resisted directive recovery, and they turn out to be the
most structurally interesting ones. All six have the identical form:

```
44FC 000C     move #$0C,ccr
4E41          trap #1
```

and they sit at `$F050FC`, `$F05E4C`, `$F060F0`, `$F06B08`, `$F07508` and
`$F07F08` — **exactly the six addresses each task descriptor carries at
`+$10`**:

| task | `+$0C` ISR entry | `+$10` | bytes at `+$10` |
|---|---|---|---|
| RDHC | `$F04930` | `$F050FC` | `44FC000C4E41` |
| IO1I | `$F05DD6` | `$F05E4C` | `44FC000C4E41` |
| XP4I | `$F060CE` | `$F060F0` | `44FC000C4E41` |
| XP3I | `$F06AE6` | `$F06B08` | `44FC000C4E41` |
| XP2I | `$F074E6` | `$F07508` | `44FC000C4E41` |
| XP1I | `$F07EE6` | `$F07F08` | `44FC000C4E41` |

So the task descriptor declares an interrupt **triple** — vector number at
`+$08`, handler entry at `+$0C`, **exit stub at `+$10`** — and directive `$4C`
registers all three. The exit stub is a byte-identical 6-byte routine in every
task, a seventh replicated block on top of the eight issuer copies.

When this document first described the descriptor blocks it called `+$10`
"ISR exit / continuation", inferred only from the address landing just past
the handler. It is now identified: a stub whose whole body is *set the
condition codes, then trap*.

**The condition codes are the argument, not `d0`.** XP1I's ISR contains no
write to `d0` anywhere between its entry at `$F07EE6` and this trap, so
whatever `d0` holds is left over from the interrupted code and cannot be a
directive. `$0C` sets N and Z. TCBIO1I's ISR *does* write `d0` — `$281` or
`$282` on the two arms — but it writes those for the panel-command issuer, not
for this call.

This is a distinct calling convention from the other 65 `trap #1` sites, all
of which load `d0` immediately beforehand, and it is worth flagging for anyone
matching this firmware against RMS68K documentation: **the ISR-exit call is
not directive-numbered.**

### The firmware's complete RTOS API surface: 14 directives

Recovering the directive from every `trap #1` site — walking back for the last
write to `d0` — gives the full set the firmware uses, and the distribution is
as informative as the list:

| directive | sites | used by |
|---|---:|---|
| `$01` | 7 | **every task** + RDHC twice |
| `$0F` | 6 | **every task** |
| `$13` | 6 | **every task** |
| `$4C` | 6 | **every task** |
| `$2B` | 9 | IO1I, each XP task ×2 |
| `$2D` | 9 | IO1I, each XP task ×2 |
| `$10` | 5 | RDHC, each XP task |
| `$11` | 4 | each XP task |
| `$43` | 4 | each XP task |
| `$12` | 5 | **RDHC only** |
| `$0B` | 1 | **RDHC only** |
| `$0D` | 1 | **RDHC only** |
| `$29` | 1 | **RDHC only** |
| `$2A` | 1 | **RDHC only** |

65 sites resolved, 6 where the directive could not be recovered by this
method (`d0` set further back or computed).

The shape matches the task roles established elsewhere:

- **`$01`, `$0F`, `$13`, `$4C` are the common lifecycle** — every task makes
  each call exactly once. `$01` sets up the task and stack, `$4C` connects the
  interrupt vector (traced directly), `$13` is the blocking wait. `$0F` is the
  fourth member of that set and is also called once from every channel ISR.
- **`$2B` and `$2D` are paired and channel-oriented** — twice each in every XP
  task and once each in TCBIO1I, never in RDHC. The two `$2D` calls in the XP
  prologue attach the `AXP1`/`HXP1` ASQs; the `$2B` calls sit in the bit-14
  dispatch path.
- **Five directives are RDHC's alone** — `$0B`, `$0D`, `$12`, `$29`, `$2A`.
  That is consistent with RDHC being the master/dispatch task: it is the only
  one doing whatever those five do, and `$12` is its most-used call.

Note this is the TRAP #1 surface. CLAUDE.md separately records 37 internal
directives reached by TRAP #0 with the directive in `d0`; those are kernel
internals, not calls this firmware makes.

**None of these numbers could be matched against Motorola's published names.**
The RMS68K source at `~/src/claude/versados/rms68k_source.SA` gives
`GTASQ 31`, `WTEVNT 36`, `RDEVNT 34`, `RTEVNT 37`, `TERM 15`, `CMR 60`, none
of which line up, and the kernel's own 35-entry dispatch table at `$F001D6` is
too short to be indexed by `$43` or `$4C` directly. The roles above are
established from what the calls do in this ROM.

### The largest XP-only routine is a channel scan

The 408-byte block replicated across the four XP tasks and absent from RDHC
runs to the end of each task region, and its most substantial routine is at
`$F08616` in XP1I's copy — the target of the `jsr $F08616` in the task body at
`$F07E42`. It is a loop over the channel windows:

```
$F08668  movea.l #$FF0000,a2
$F08676  move.w  $4E(a2,d4.l),d2    ; this channel's command register
$F0867A  btst    #15,d2
$F08680  btst    #14,d2
$F08686  st      d5                 ; both set -> flag
$F08688  addi.l  #$20,d4            ; next channel window
$F0868E  addq.w  #1,d3
$F08690  cmp.w   $105E,d3           ; bounded by the channel-present count
$F08696  ble     -> $F08676
```

Three things this confirms from running code rather than from static reading:

1. **`$105E` is the channel count** — a third independent confirmation, after
   the probe at `$F0A224` that writes it and the per-task presence gate that
   reads it. Here it bounds a loop.
2. **`$20` is the channel-window stride**, which until now was inferred from
   the four windows' base addresses.
3. **Bits 15 and 14 are the dispatch field.** They were found gating the
   `$8000` path in the task body; the scan tests the same two bits across
   every channel.

The routine also touches the shared globals identified earlier — it reads and
increments `$107E` and accumulates into `$1064` — which is what those two are
for: scan state shared across the four tasks, as opposed to the per-channel
array at `$1066-$107D`.

Earlier in the same block, `$F0857E` pushes a longword `0`, the ASCII
`"USER"`, and `moveq #$43,d0` before a `trap #1` — a directive-`$43` call
naming the same owner string that RDHC's task descriptor carries at `+$14`.
That is the sixth distinct RTOS directive this ROM is now known to use
(`$01`, `$13`, `$2D`, `$43`, `$4C`, plus the `$0F` in the channel ISR).

### A third of the application code is byte-identical replication

Sweeping the FPS application region `$F04488-$F0A5FF` for duplicated blocks
(32-byte seed windows, grown to maximal length, non-overlapping) gives:

| length | copies | addresses |
|---:|---:|---|
| 408 | **4** | `$F06750` `$F07168` `$F07B68` `$F08568` — XP tasks only |
| 192 | **5** | `$F05B92` `$F065D2` `$F06FEA` `$F079EA` `$F083EA` |
| 176 | **5** | `$F05A0E` `$F0644E` `$F06E66` `$F07866` `$F08266` |
| 130 | 5 | `$F05AFC` `$F0653C` `$F06F54` `$F07954` `$F08354` |
| 106 | 5 | `$F0599C` `$F063DC` `$F06DF4` `$F077F4` `$F081F4` |
| 88 | 5 | `$F057FA` `$F0623A` `$F06C52` `$F07652` `$F08052` |
| 58 | 10 | `$F05A84` `$F05B44` `$F064C4` `$F06584` … |
| 52 | 15 | `$F056C8` `$F0594A` `$F059D2` `$F06108` … |
| 50 | 15 | `$F05742` `$F057AC` `$F05820` `$F06182` … |
| 50 | **8** | the panel-command issuer |

**9,182 of 24,952 bytes — 36% — are a byte-identical copy of an earlier
block.**

**RETRACTED: an earlier revision called this a lower bound for the wrong
reason.** It claimed byte-identical matching could not see the five 42-entry
dispatch tables because their `jmp d16(pc)` displacements differ per copy, and
put the corrected floor at ~38%.

**The five tables are byte-identical.** Because each task is a template copy at a
fixed stride, every handler sits at the same *relative* offset in every copy, so
the pc-relative displacements coincide exactly — all five tables begin
`4E754E714EFAFE684EFAFD044EFAFD00`. The sweep did not miss them.

In fact it *reported* them: the 192-byte 5-copy group at `$F05B92`/`$F065D2`/
`$F06FEA`/`$F079EA`/`$F083EA` **contains** the dispatch table, which starts 18
bytes in. What was missing was never detection — it was interpretation. The sweep
said "here is a 192-byte block replicated five times" and nobody decoded what was
inside it.

*Two attempts to improve on 36% both failed, in opposite directions. Blanking
pc-relative displacements before comparing produced "264% duplication" —
impossible on its face — because the displacements are what distinguish copies and
because overlapping windows within one task were counted separately. Replacing
each displacement with its target's offset *relative to the block base* is sound,
and validates on the known case, but with a conservative overlap guard it finds
only 15% — less sensitive, not more. So 36% stands as the measured figure, with no
established reason to think it low.*

**The transferable lesson is about interpretation, not measurement.** A structural
sweep that says "this 192-byte block appears five times" has already found
everything a better sweep would; the cost was in not asking what the block *was*
for several iterations.

The dominant shape is **five copies: one in RDHC and one in each of the four
XP tasks**. Read the first address of each 5-copy group and it is always in
RDHC's range, with the other four landing at the same offset within each XP
task. The 408-byte group is the exception, appearing in the four XP tasks and
not in RDHC.

Measuring the overlap directly:

| | windows also occurring in the other |
|---|---|
| XP1I vs RDHC | **32%** of XP1I |
| IO1I vs RDHC | **23%** of IO1I |
| RDHC vs XP1I | 13% of RDHC |

So each XP task is roughly a third shared library, and RDHC — much the largest
region — is mostly its own code.

**What this is good for.** Combined with the earlier finding that XP1I, XP2I
and XP3I differ in only 77 bytes, it means the ROM's ~25 KB of application
code contains about **15.8 KB of distinct code**. Anyone reading the
disassembly can cover essentially all of it by reading RDHC and one XP task;
the other three XP tasks and a third of each are already accounted for. It
also explains a result recorded earlier — that panel codes `$269`, `$26A`×4,
`$26B`×2 and `$26C`×9 appear with *identical counts* in RDHC and all four XP
tasks. They sit inside these replicated blocks.

This is also a strong hint about how the firmware was built: a library
included into each task at assembly time rather than linked as shared
routines. Nothing here identifies the toolchain, but wholesale duplication at
this scale, with no per-copy constants in the largest groups, is what textual
inclusion produces and not what a linker does.

### The panel-command issuer exists in eight byte-identical copies

There are exactly nine `bra .` (`60FE`) sites in the ROM, and **eight of them
are the tail of the same 48-byte routine**, replicated verbatim:

| entry | spin | reached from | note |
|---|---|---|---|
| `$F04500` | `$F04530` | pre-task region | |
| `$F05688` | `$F056B8` | RDHC | documented as "PanelIOCommand processor" |
| `$F05E56` | `$F05E86` | TCBIO1I | the `$281` deadlock above |
| `$F068A8` | `$F068D8` | XP4I | |
| `$F072C0` | `$F072F0` | XP3I | |
| `$F07CC0` | `$F07CF0` | XP2I | |
| `$F086C0` | `$F086F0` | XP1I | the `jsr $F086C0` all over XP1I |
| `$F0A57E` | `$F0A5AE` | RTOS/init | |

The ninth spin is `$F001AA`, in the RMS68K kernel.

All eight are **byte-identical over the full 48 bytes**, preamble included:

```
move.w  d0,$0E6E          ; stash the command code -- the SAME global in all 8
movea.l #$FF0000,a0
move.w  d0,$0E(a0)        ; command port
move.w  $202(a0),d1 / bclr #$E / bset #$C / move.w d1,$202(a0)
move.w  $200(a0),d1 / bclr #$A / move.w d1,$200(a0)
move.w  d0,$204(a0)       ; CHANNEL_SELECT
bra .
```

Because it takes its command in `d0` and addresses everything off `$FF0000`,
the routine needs no per-task constants — which is exactly why it could be
copied verbatim rather than parameterised. All eight write the same global
`$0E6E`, so there is no per-copy state either; the replication buys locality,
not behaviour.

Three loose ends close here:

- **`$F086C0`**, the target of the `jsr` that appears throughout XP1I and
  whose siblings `$F07CC0`/`$F072C0`/`$F068A8` show up in the template diff as
  differing constants, is this routine.
- **`$F0A57E`** is copy eight. This project previously recorded that address
  as `TCBDefinitionTable`, which was wrong (corrected earlier to `$F0A600`);
  it is a panel-command issuer.
- **`$F05688`**, already documented as the "PanelIOCommand processor", is one
  member of a family rather than a unique routine.

**The level constraint applies to every copy.** Each ends in a spin that only
`F04930` can break, and `F04930` is level 6. So any caller running at level 7
— which is every channel ISR, since the firmware writes `CR = $5F` to all of
them — cannot be rescued. Whether that matters depends on whether a given copy
is ever called from ISR context; measured so far, only TCBIO1I's is.

### The `$281` path is unserviceable as the firmware programs the BIMs

TCBIO1I's host-request arm ends in the documented `bra .` spin, and the
routine is short enough to give in full:

```
$F05E56  move.w  d0,$0E6E          ; stash the command code
$F05E5C  movea.l #$FF0000,a0
$F05E62  move.w  d0,$0E(a0)        ; $FF000E <- $281
$F05E66  move.w  $202(a0),d1
$F05E6A  bclr    #$E,d1            ; MODE1 bit 14 clear
$F05E6E  bset    #$C,d1            ; MODE1 bit 12 set
$F05E72  move.w  d1,$202(a0)
$F05E76  move.w  $200(a0),d1
$F05E7A  bclr    #$A,d1            ; MODE0 bit 10 clear
$F05E7E  move.w  d1,$200(a0)
$F05E82  move.w  d0,$204(a0)       ; CHANNEL_SELECT <- $281
$F05E86  bra .                     ; spin
```

The spin is terminal. Escape is only by the panel-status responder `F04930`
rewriting the saved PC — the mechanism documented for `PanelStatusDispatch`.

**That responder can never run here.** Measured three ways:

| configuration | spin `$F05E86` | rescuer `$F04930` |
|---|---|---|
| BIM0 ch0 raised, nothing spinning | – | **1** |
| TCBIO1I ISR spinning (bit 29 set) | 18,135 | **0** |
| both raised together | 18,135 | **0** |

The responder works when it can be reached, and is shut out entirely once
TCBIO1I is spinning. The reason is the level split the firmware itself
programs: TCBIO1I's BIM channel carries `CR = $5F` (level 7) and BIM0 ch0
carries `CR = $5E` (level 6), so on interrupt acknowledge the CPU masks to 7
and a level-6 request cannot preempt. **TCBIO1I contains no SR-modifying
instruction anywhere** — no `move #imm,SR`, no `andi #imm,SR` — so the ISR
never lowers the mask.

This matters because **the CR values are written by this ROM, not set by
straps** — the firmware itself chooses level 6 for the responder and level 7
for the channels.

**But an external review (`ds2/ADVERSARIAL_REVIEW.md` C.2) raises a fair
refinement, and it is accepted here.** The CR level bits select which
interrupt-request line the BIM asserts; how those BIM outputs are wired to the
68000's `IPL0-2` pins is **board wiring, and unverified**. If the board routes
the channel BIMs' requests at a level below 6, or the responder's above 7 (not
possible — 7 is the maximum), the deadlock does not arise. So the correct
statement is: **as programmed, and assuming conventional CR-to-IPL wiring, a
panel command issued from inside the host-link ISR cannot be completed.** The
firmware's contribution to the deadlock is established; the board's is not.

The same review notes a second possibility worth recording: the chassis might
answer `$281` by a mechanism that needs no interrupt at all — a bus cycle that
modifies the saved PC directly, which it is capable of as a bus master. That
would also dissolve the deadlock, and it is consistent with reading 1 below.

Three readings, none established:

1. **The chassis response does not arrive via BIM0 ch0.** The `$281` handshake
   may complete through some other path — which would also explain why the
   42-entry `PanelStatusDispatchTable` is never reached from `F04930`.
2. **The `$281` arm is not taken in normal operation.** Bit 29 set means "host
   needs attention"; if the real host link normally leaves it clear and works
   through the `$10AA` arm — the one that *does* run to completion and write
   `$00010002` — then this path is an edge case.
3. **Something outside the firmware clears the spin.** A chassis-driven write
   to the spinning task's stack frame would do it, and the chassis is a bus
   master. Nothing establishes this.

Reading 2 is the most economical, and it fits: the `$10AA` arm completes 1468
times in the same run in which the `$281` arm deadlocks.

### The mailbox class field, confirmed properly

The retraction below stands as to the *numbers*. The **substance** is now
confirmed, on a machine that boots, at the firmware's own interrupt level.

The missing ingredient was that the class bits must be presented with
**bit 29 clear** — the original account had bit 29 set, which selects the
other arm of the ISR entirely, so the reply path could never have run in that
configuration.

`FPS3K_XPIRQ=5 FPS3K_DMA10AA=2 FPS3K_MBOX=000n0000`:

| class bits 16-17 | `$F05E2C` | `$F05E40` | ISRExit |
|---|---|---|---|
| 0 | 1468 | **0** | 1468 |
| **1** | 1468 | **1468** | 1468 |
| 2 | 1468 | **0** | 1468 |
| 3 | 1468 | **0** | 1468 |

Exactly what `swap` + `andi #3` predicts: the field must read **1**, and the
other three values write nothing. The ISR runs and returns in all four cases —
only the reply is gated.

And the reply itself:

```
MAILBOX: host=00000000 reply=00010002
WR 4-byte 700020 = 00010002   (x1468)
final PC = F00FCC             (in the RTOS, not the diagnostics)
```

`$00010002` is the mailbox word with bit 1 set — precisely what `bset #1,d1`
predicts, and precisely the value the retracted account gave.

So the sequence of events on this claim is worth stating plainly: the original
**conclusion was right**, the **evidence offered for it was not** — it came
from a machine that had hung in the power-on diagnostics — and re-deriving it
required finding that bit 29 must be *clear*, which the original account had
backwards. Retracting the result did not cost the finding; it produced a
better one.

### Retraction: the "F05E40 executes 46,511 times" result does not reproduce

CLAUDE.md records this as the reply path being driven for the first time:

> Driving both in the emulator runs the path for the first time: with
> `$10AA = 2` and mailbox bits 16-17 = `1`, F05E40 executes 46,511 times and
> the SBC writes **`reply = $00010002`** to `$700020` … This is also the first
> configuration in which the ISR ever *returns*.

**It does not reproduce, and the configuration it describes never boots.**
`FPS3K_DMA10AA_FROM_RESET=1` restores the pre-fix ungated injection, and with
the described settings — `$10AA = 2` from reset, host ISR forced to level 5,
`FPS3K_MBOX` supplying class bits `1` — the machine ends at
**`final PC = F09904`**, inside the power-on diagnostics, having never reached
the scheduler:

```
F05E40 x0    ISRExit x0    scheduler idle F00262 reached: no
```

The cause is the defect described above: `$10AA` lies in the RAM the
diagnostics walk, and a constant-reading location fails a pattern test. Any
run with the injection live from reset hangs there.

**What is retracted** is the empirical result — the 46,511 count, the
`$00010002` reply, and the claim that this was the first configuration in
which the ISR returns. **What is not retracted** is the static reading behind
it: `$F05E2C` really does `swap` the mailbox word and mask `#3`, so bits 16-17
really are a two-bit field, and `bset #1,d1` really does predict a reply with
bit 1 set. That code has not changed; only the claim to have executed it has.

Two candidate explanations for the original numbers, neither checkable now:
the injection range was `$10A8-$10AB` at the time (the off-by-two this project
later fixed), so `$10AA` may not have been intercepted at all and the value
came from somewhere else; or other hooks were active and went unrecorded. The
lesson is the one this document keeps relearning — a result is only as good as
the state the machine was in, and "final PC" is the cheapest possible check
that it booted at all.

### The ISR has two arms, selected by mailbox bit 29

Testing bit 29 independently of everything else gives a clean split:

| mailbox bit 29 | path taken |
|---|---|
| **set** | `$F05DFA` — issues `PCMD_HOST_REQUEST` (`$281`) |
| **clear** | `$F05E12` → `$F05E2C` — the `$10AA`-dispatched reply path |

So the two paths are **alternatives, not stages**. This is consistent with the
documented reading of bit 29 as "host needs attention" — with it set the ISR
asks the chassis for a byte; the `$10AA` dispatch is what it does when there
is no such request outstanding.

It also explains why the reply branch is reached with the mailbox left alone
and not when the mailbox is driven: an untouched mailbox reads `0`, bit 29
clear, which is precisely the arm that reaches `$F05E2C`.

Reproducible now, at the firmware's own level 7 off the real BIM:

```
FPS3K_XPIRQ=5 FPS3K_DMA10AA=2     ->  F05E12 x1, F05E2C x1, ISRExit x1
```

`F05E40` still never executes. Reaching it needs the class field to read `1`
*while* bit 29 is clear, and nothing in the model can currently present that
combination — the only hook that sets the class bits sets bit 29 with them.

### TCBIO1I runs at the firmware's own interrupt level

Every previous result on the host-link path carried this caveat: *"they were
produced with the host ISR forced to level 5 (`FPS3K_HOSTLVL`), since at the
firmware's own level 7 the panel handshake never escapes its spin."* The
reason was that nothing in the model ever raised TCBIO1I's BIM channel —
BIM2 ch2 at `$FF0254`, control value `$5F` — so the only way in was a forged
level-5 autovector.

`FPS3K_XPIRQ=5` now raises that channel directly. **The ISR at `$F05DD6`
executes at level 7, off the real BIM, with no level override**, and TCBIO1I
reaches 57 distinct PCs including the `$10AA` read at `$F05E12`.

TCBIO1I is also unusually simple by the measures used on the XP tasks: **no
`btst` sites at all**, and exactly two RAM globals referenced by absolute
address — `$E6E` and `$10AA`.

#### A tooling defect: `FPS3K_DMA10AA` was hanging the self-test

Setting `FPS3K_DMA10AA=2` produced **zero** TCBIO1I instructions, and the
cause is not in the firmware. `$10AA` lies in the RAM the power-on
diagnostics walk, and a location that reads back a constant regardless of
what was written fails a pattern test — with the injection live from reset the
machine hangs in the diagnostics at `F09904` and never reaches the scheduler
at all.

The hook now gates on boot completion (vector `$128` holding `F05DD6`, the
same gate `host_sim` uses). **Any earlier `$10AA` result should be re-checked
against this**: if it was obtained with the injection active from reset, the
machine was not in the state the result assumed.

#### With that fixed, `$10AA = 2` reaches the reply branch at level 7

| configuration | `$F05E2C` | ISRExit `$F05E4C` |
|---|---|---|
| `XPIRQ=5` alone | no | no |
| `XPIRQ=5`, `DMA10AA=2` | **yes** | **yes** |
| `XPIRQ=5`, `DMA10AA=2`, `MBOX=$20010000` | no | no |

The reply branch is reached with `$10AA = 2` and **the mailbox left alone**.

That is worth flagging against the documented account, which has the reply
path requiring "mailbox bits 16-17 = 1". At level 7 the branch is taken
without touching the mailbox, and forcing the mailbox word *prevents* it,
diverting the ISR to `$F05DFA` — the `PCMD_HOST_REQUEST` (`$281`) site — and
the `$F05E56` path instead.

**Do not read that as refuting the mailbox class field.** `FPS3K_MBOX` returns
a **constant**, which no real mailbox does: the host word would change as the
handshake progressed. A constant that never clears is exactly the kind of
model artefact that produces a different branch for uninteresting reasons. The
honest statement is that the level-7 route reaches the reply branch on `$10AA`
alone, and that the mailbox class field could not be exercised at level 7 with
the crude constant-injection hook available.

### The XP tasks' RAM map

Classifying every absolute reference to `$1050`-`$1090` by which tasks make it
gives a complete and very regular picture:

```
$105E   SHARED    channel-present count (written at $F0A224)
$1062   SHARED
$1064   SHARED
$1066 ┐
$1068 ├ XP1I     { command, data HI, data LO }  <- filled by the ISR
$106A ┘
$106C ┐
$106E ├ XP2I
$1070 ┘
$1072 ┐
$1074 ├ XP3I
$1076 ┘
$1078 ┐
$107A ├ XP4I
$107C ┘
$107E   SHARED
$1080   SHARED
```

A contiguous **24-byte array at `$1066-$107D`, four entries of six bytes**,
bracketed by shared globals. Each entry is the three-word snapshot the channel
ISR takes of `{+$0E, +$08, +$0A}`, which is why the stride is 6.

The reference counts are identical across XP1I, XP2I and XP3I — 5 on the
command word, 2 on data-HI, 1 on data-LO — the template-copy signature again.
**XP4I references its command word 3 times, not 5**, and that difference is
the whole story of the next section.

### XP4I implements a strict subset of the dispatch

Listing every `btst` against each task's own command word:

| task | bits tested |
|---|---|
| XP1I | 15 `$F07E4C`, 14 `$F07E86`, 11 `$F07E90`, 11 `$F07EB6` |
| XP2I | 15 `$F0744C`, 14 `$F07486`, 11 `$F07490`, 11 `$F074B6` |
| XP3I | 15 `$F06A4C`, 14 `$F06A86`, 11 `$F06A90`, 11 `$F06AB6` |
| **XP4I** | 15 `$F06052`, 14 `$F06088` — **and nothing else** |

XP4I has **no bit-11 test anywhere**. Its dispatch is a strict prefix of the
other three: bit 15 and bit 14 are handled identically, and the bit-11
sub-case — both its tests and the `$8000`/`$1B` action they guard — is absent
entirely.

This is the final form of a finding that took four passes to get right, and
it is worth setting out what each pass got wrong:

1. "XP4I is 19.5% different" — an **alignment artefact**; XP4I's body sits
   `$18` off the grid the other three share.
2. "XP4I lacks the trigger site" — true but framed as a degraded copy, when
   XP4I also *adds* code the others lack.
3. "XP4I is receive-only" — **wrong**: its ISR is identical, reads all three
   registers and issues `$8004` exactly as the others do.
4. Correct: **the ISR is identical; the task body implements bits 15 and 14
   but not the bit-11 sub-case.**

Every one of the earlier readings was consistent with the evidence available
at the time. What settled it was counting the same thing four different ways —
byte diff, port-constant count, command-word reference count, and `btst` site
list — and requiring them to agree.

### The channel command word's high bits are a dispatch field

The `$8000`/`$1B` sequence that only XP1I/2/3 have is reached through a chain
of bit tests on `$1066` — which the ISR fills from the channel's **command
register** at `+$0E`. Decoding the chain:

```
$F07E4C  btst #$F,$1066    ; bit 15
$F07E54  bne  -> $F07E86
$F07E86  btst #$E,$1066    ; bit 14
$F07E8E  beq  -> $F07ED8   ; ...else fall through
$F07E90  btst #$B,$1066    ; bit 11
$F07E98  bne  -> $F07EB6
$F07EB6  btst #$B,$1066
$F07EBE  beq  -> $F07ED4
$F07EC0  movea.l #$FF004E,a0
$F07EC6  move.w  #$0,(a1)
$F07ECA  move.w  #$1B,$2(a1)
$F07ED0  move.w  #$8000,(a0)
```

So reaching the `$8000` write needs **bits 15, 14 and 11 all set**.

`FPS3K_CHCMD=<hex>` sets what the command port hands back, and testing the
bits one at a time confirms each one's role:

| `CHCMD` | bits 15/14/11 | XP1I distinct PCs | reaches `$F07EB6` | fires `$8000` |
|---|---|---|---|---|
| `$0001` | – – – | 116 | no | no |
| `$0801` | – – ✓ | 116 | no | no |
| `$8001` | ✓ – – | 78 | no | no |
| `$8801` | ✓ – ✓ | 78 | no | no |
| `$C001` | ✓ ✓ – | 91 | **yes** | no |
| `$C801` | ✓ ✓ ✓ | 75 | **yes** | **yes** |

With `$C801` the bus log shows the sequence executing for the first time:

```
WR FF0048 = 0000
WR FF004A = 001B
WR FF004E = 8000
```

That is the `$0000001B` written across the 32-bit pair as two halves — the
value CLAUDE.md records TCBXP1I as writing, now observed rather than read off
the disassembly.

Two things to note. The distinct-PC count is **not monotonic** (116, 78, 91,
75): these are different paths through the task, not more or less of one path,
so PC count is a discriminator here and not a progress metric. And an earlier
attempt at this predicted bit 11 alone would be enough and was **wrong** — the
`btst #$B` at `$F07EB6` is the last gate, not the only one, and setting bit 11
by itself changes nothing because the code never reaches that test.

**What is established** is that these three bits of the command register select
this path, verified by isolating each. **What is not** is what they mean to the
chassis: the register's semantics on real hardware are still unknown, and the
values here were chosen to reach the code, not because the XP-32 presents them.

### The chassis register set is closed

Redoing the access map with base-register tracking — the form the previous
absolute-address scans were blind to — gives a complete picture, and it turns
up **no undocumented registers**. Every access resolves to one of:
`$FF0004`, `$FF000E`, the four channel windows, and
`$FF0200`/`$0202`/`$0204`/`$020C`/`$0210`/`$0218`/`$021A` plus the BIM file.

| register | RDHC | IO1I | XP4I | XP3I | XP2I | XP1I | init |
|---|---|---|---|---|---|---|---|
| `$FF0004` ready | R | . | R | R | R | R | . |
| `$FF000E` panel cmd | W | W | W | W | W | W | W |
| channel `+$04` | . | . | W | W | W | W | . |
| channel `+$08` `+$0A` `+$0E` | . | . | R | R | R | R | . |
| `$FF0200` `$FF0202` | RW | RW | RW | RW | RW | RW | RW |
| `$FF0204` | W | W | W | W | W | W | W |
| `$FF020C` | W | . | W | W | W | W | . |
| `$FF0210` | RW | RW | . | . | . | . | . |
| `$FF0218` | RW | . | . | . | . | . | . |
| `$FF021A` | RW | . | RW | RW | RW | RW | . |
| own BIM CR | W | W | W | W | W | W | W |

Two limits on reading this as exhaustive. It only covers accesses made as a
displacement off a register holding `$FF0000`, so ports addressed through
their own base — `$FF0008`, the bulk data port — do not appear here; they are
in the constant-ownership map instead, and the two are complementary. And
`$FF0218` being RDHC-only while `$FF021A` is shared is a real asymmetry worth
noting rather than an artefact: the XP tasks manipulate the IRQ mask but not
the status register.

**Two candidate registers were rejected during this pass.** A first run with
a 600-instruction lookahead reported `$FF000C` (written) and `$FF0018` (read).
Checking the sites showed both were false: `$F0A49E` is
`movea.l $8A(pc),a0`, so `$18(a0)` there is a struct field, and the `$F0A3F0`
/`$F0A440` sites are RTOS structure initialisation. The scan had walked past
routine boundaries. Terminating on `rts`/`rte`/`bra` and on **any** reload of
the base register — not only `movea.l #imm` — removes them.

### XP4I again: the ISR is identical; only the `$8000` path is missing

Running XP4I's own interrupt (`FPS3K_CHANNELS=4 FPS3K_XPIRQ=4`) shows its ISR
at `$F060CE` doing exactly what XP1I's does — **117 distinct PCs against
XP1I's 116**:

```
RD FF00AE @F060D6    WR FF00A8 = 0000 @F06100
RD FF00A8 @F060DE    WR FF00AA = 0010 @F06106
RD FF00AA @F060E6    WR FF00AE = 8004 @F0610A
```

So the earlier framing needs one more correction. XP4I is **not** receive-only
and its channel handling is not degraded: the interrupt-driven transaction,
including the `$8004` REQUEST-TRANSFER, is present and identical.

What XP4I lacks is a **separate, non-ISR** sequence that the other three have
in their task body:

```
movea.l #$FF00xE,a0
move.w  #$0,(a1)        ; data HI
move.w  #$1B,$2(a1)     ; data LO = $1B
move.w  #$8000,(a0)     ; a different command from the ISR's $8004
```

Counting both commands across the image settles it exactly:

| | XP4I | XP3I | XP2I | XP1I | RDHC | total |
|---|---|---|---|---|---|---|
| `move.w #$8004,(a0)` | **6** | 6 | 6 | 6 | 6 | 30 |
| `move.w #$8000,(a0)` | **0** | 1 | 1 | 1 | 0 | **3** |

`$8004` is equally present in all four channel tasks. `$8000` occurs three
times in the whole ROM — once each in XP1I, XP2I and XP3I — and the constant
`$1B` appears only alongside it. The precise statement is therefore: **XP1I/2/3 can issue an
`$8000` command carrying the constant `$1B`; XP4I cannot. Everything
interrupt-driven is the same.** Whether `$8000` is an initialisation or a
mode-set is not established.

### `$FF0048` IS read — the claim was wrong, and so was my re-verification

Driving the XP channel interrupt runs the XP-32 channel ISR for the first
time, and it reads `$FF0048`.

`FPS3K_XPIRQ=<ch>` raises channel *ch*'s BIM request once its task has
enabled it. With `FPS3K_XPIRQ=1`, XP1I goes from **45 to 116 distinct PCs**
and the ISR at `$F07EE6` executes. The bus log, with PCs, shows:

```
RD 2-byte FF004E @F07EEE
RD 2-byte FF0048 @F07EF6      <-- here
RD 2-byte FF004A @F07EFE
WR 2-byte FF0048 = 0000 @F07F18
WR 2-byte FF004A = 0010 @F07F1E
WR 2-byte FF004E = 8004 @F07F22
```

`$F07EF6` is sixteen bytes into the ISR — ordinary ROM code, not an
instruction fetch from a corrupted vector, which is what the earlier
retracted sighting turned out to be.

**Two statements are retracted.** The documented one, "`$FF0048` is never
read anywhere in the ROM"; and my own re-verification of it earlier in this
session, which reported "exactly one occurrence of `$00FF0048` in the image,
at F07E2E, and zero runtime reads". That count was correct and the conclusion
did not follow: **the ISR reads the port as `$48(a5)` with `a5 = $FF0000`**,
a displacement form no absolute-address scan can see. The same blind spot is
already flagged in `fps3k.asm`'s own header, which declines to name short
displacements because the base register is unknown — and then I ran exactly
that scan and trusted it.

The right statement is: *`$FF0048` is referenced by absolute address exactly
once, as a write; every read of it goes through a base register.*

**What this does not overturn.** The host↔SBC payload still rides in the
mailbox pair, not the channel data ports — this is TCBXP1I, the XP-32 channel
task, not TCBIO1I, the host link. The revised host protocol stands.

### The XP-32 channel transaction

The ISR is a complete, coherent transaction:

```
$F07EE6  move.l  a5,-(a7)
$F07EE8  movea.l #$FF0000,a5
$F07EEE  move.w  $4E(a5),$1066      ; command  -> per-channel RAM +0
$F07EF6  move.w  $48(a5),$1068      ; data HI  -> per-channel RAM +2
$F07EFE  move.w  $4A(a5),$106A      ; data LO  -> per-channel RAM +4
         ... two RTOS calls ...
$F07F10  move.w  #$004F,(a3)        ; BIM CR with IRE cleared
$F07F16  move.w  #$0000,(a1)        ; data HI <- 0
$F07F1C  move.w  d0,$2(a1)          ; data LO <- d0
$F07F20  move.w  #$8004,(a0)        ; REQUEST-TRANSFER
$F07F24  move.l  #$3E8,d5           ; 1000-iteration timeout
$F07F2A  poll on $4E(a5)
```

It confirms four separate things that were previously established from other
directions:

1. **The channel window roles.** `+$08`/`+$0A` are read *and* written as a
   pair and `+$0E` carries `$8004`, exactly as the corrected table says. The
   old "read A / status / read B" labelling could not produce this.
2. **The per-channel RAM blocks.** The 6-byte blocks at `$1066`/`$106C`/
   `$1072`/`$1078` are a snapshot of `{command, data-hi, data-lo}` — three
   words, which is why the stride is 6.
3. **`$4F` is a BIM control-register value.** The ISR writes it to `(a3)`
   while a transfer is outstanding, which is the IRE-cleared form documented
   for `PanelSendAndWait`. This is a second, independent sighting of the
   pattern that showed `$4F` was never an `$FF004A` status value.
4. **`$8004` is REQUEST-TRANSFER**, the same command the `D1_SEND` handler in
   `PanelStatusDispatchTable` issues.

### The XP task prologue, decoded

Each XP task makes five `trap #1` calls and then blocks. Reading their
parameter blocks gives the whole startup sequence:

| # | directive | parameter block | function |
|---|---|---|---|
| 1 | `$01` | `$F07D14`: `"XP1I"` +0, `$20000000` +8, `"STCK"` +$C, `$190` +$14 | task / stack setup, 400-byte stack |
| 2 | `$2D` | stack copy of `"AXP1"`, `$0002` | attach ASQ — AC-side queue |
| 3 | `$2D` | stack copy of `"HXP1"`, `$0002` | attach ASQ — host-side queue |
| 4 | `$4C` | the descriptor block at `$F07D00` | **connect interrupt vector** |
| 5 | `$13` | — | **block / wait** |

`"AXP1"` and `"HXP1"` are exactly the ASQ names CLAUDE.md documents for this
task, which is independent confirmation that the two directive-`$2D` calls
are ASQ attaches. The names are assembled by a backwards copy loop
(`$F07D76`-`$F07D80`) from tables at `$F07D2C`/`$F07D36` onto the stack.

**Directive `$4C` is verified, not inferred.** A watchpoint on vector `$114`
(= `$45`×4, XP1I's) shows the final write of `$00F07EE6` coming from kernel
PC `$F02278`, and `$F07DDE` — the `trap #1` carrying `$4C` — is the nearest
preceding XP1I instruction, 141 instructions earlier. So `$4C` takes a
descriptor block and installs the vector it names.

That closes a gap left open above. The descriptor block's fields were
documented as a declaration; they are in fact **the parameter block for
directive `$4C`**, which is why vector number and handler address sit at
fixed offsets in it.

The remaining directives are inferred from their parameter blocks rather
than traced: `$01` carries a task name, a `"STCK"` tag and a size, and `$2D`
carries an ASQ name. `$13` carries nothing and is where every XP task stops.

#### What this means for the model

The blocking point is now fully characterised: each XP task completes setup,
registers its ISR, and waits on directive `$13` for an interrupt its BIM
channel will never raise in the emulator. Supplying that interrupt — not the
presence gate, not the panel handshake — is what would advance the four
channel tasks.

### The `$26E-$271` panel codes are not per-channel

CLAUDE.md labels `0x26E-0x271` as `PCMD_CH{1..4}_TCB_FAIL` and flags the
result as unresolved:

> **`0x26E` is labelled CH1 but appears in TCBXP4I context.** ... Either the
> CH1 label is wrong or the function attribution is. Unresolved — do not rely
> on the channel numbers in this block.

**The label is wrong; the attribution was fine.** Counting every
`move.w #$0nnn,d0` with `nnn` in the panel range, per task:

| task | codes emitted |
|---|---|
| XP1I | `$262 $263 $264 $269 $26A`×4 `$26B`×2 `$26C`×9 `$26D $26E`×2 `$270 $271`×2 |
| XP2I | *identical* |
| XP3I | *identical* |
| XP4I | *identical* |
| IO1I | `$27D $27E $27F $280` |
| RDHC | `$258 $259`×2 `$25A`×3 `$25C`×5 `$25D`×2 `$25E $25F`×2 `$260`×2 `$269 $26A`×4 `$26B`×2 `$26C`×9 `$276`-`$27B` `$27D` |

All four XP tasks emit **exactly the same multiset**. A code that every
channel emits cannot identify a channel. This follows necessarily from the
template-copy finding — the 77 differing bytes do not include any of these
constants — but it is worth stating separately because the per-channel
reading is load-bearing in the docs.

**What they actually index is the RTOS directive that failed.** The XP task
prologue makes five `trap #1` calls, and each failure path loads its own code:

| site | directive in `d0` | failure code |
|---|---|---|
| `$F07D52` | `$01` | `$26D` |
| `$F07D86` | `$2D` | `$26E` |
| `$F07DBC` | `$2D` | `$26E` |
| `$F07DDE` | `$4C` | `$270` |
| `$F07E1A` | `$13` | — (this is where the task blocks) |

The same directive gets the same code at two different sites, which is what a
directive-indexed scheme predicts and a site-indexed one does not.

`$26F` appears nowhere in any task, so the "block of four, only endpoints
named" reading was also an artefact of assuming a per-channel run.

#### The shared helper block

`$269`, `$26A`×4, `$26B`×2 and `$26C`×9 appear with **identical counts** in
RDHC and in all four XP tasks. That is replicated helper code — the abort and
release paths — copied into each task rather than called, consistent with how
the rest of the template was built.

#### What the XP tasks are waiting for

The prologue is five RTOS calls and then a block on directive `$13`. Every
XP task reaches `$F07E1A` (and its equivalents) and enters the kernel at
`$F00262` to wait. Nothing in the emulator's chassis model ever wakes them,
which is why each executes only ~45 instructions of its 2560 bytes.

Directive `$13` is therefore the single thing standing between the model and
live XP channel behaviour. Naming it against the RMS68K directive set is the
obvious next step, and does not need hardware.

### The XP task templates, diffed at exact bounds

With the TDTI table giving exact `$A00` extents, the four channel tasks can
be diffed byte-for-byte for the first time. The result splits cleanly in two.

#### XP1I / XP2I / XP3I: 77 single-byte patches, and nothing else

The three differ in **77 of 2560 bytes (3.0%)**, and **76 of the 77 runs are
a single byte**. Every one is a constant substitution, in a small number of
classes:

| bytes | what varies |
|---|---|
| `31`/`32`/`33` | ASCII channel digit in the task name |
| `45`/`46`/`47` | interrupt vector number |
| `01`/`02`/`03` | channel number as a literal |
| `7D`/`73`/`69` | own-region high byte (self-references) |
| `7E`/`74`/`6A`, `7F`/`75`/`6B` | handler / ISR-exit high bytes |
| `86`/`7C`/`72`, `84`/`7A`/`70`, `85`/`7B`/`71`, `83`/`79`/`6F` | in-region routine addresses |
| `48`/`68`/`88`, `4A`/`6A`/`8A`, `4E`/`6E`/`8E`, `68`/`6E`/`74` | channel port low bytes |
| `44`/`46`/`50` | BIM control-register low byte |
| `66`/`6C`/`72` | per-channel RAM variable low bytes |

This is what "byte-identical block replication" means, quantified: one
template, copied three times, with 77 constants patched. No structural
difference of any kind.

#### `$105E` is a channel-present count, written by the CPU

Each task carries the same test against its own channel number:

```
XP1I  $F07DF6:  cmpi.w #$0001,$105E   ; blt.s -> skip
XP2I  $F073F6:  cmpi.w #$0002,$105E
XP3I  $F069F6:  cmpi.w #$0003,$105E
XP4I  $F05FF6:  cmpi.w #$0004,$105E
```

**Two claims about `$105E` are retracted here**, one from CLAUDE.md and one
from this document.

CLAUDE.md lists `$105E` with `$10AA` as a location "read but never written
by CPU code", set by the chassis acting as a bus master. **It is written by
the CPU**, at `$F0A224`, and the routine that does it is unambiguous:

```
$F0A202  clr.w   d1
$F0A204  move.w  $FF004E,d0      ; channel 1 command port
$F0A208  beq.s   +2
$F0A20A  addq.w  #1,d1
$F0A20C  move.w  $FF006E,d0      ; channel 2
   ... same for $FF008E, $FF00AE ...
$F0A224  move.w  d1,$105E
```

It **probes all four channel command ports and counts the nonzero ones**.
So `$105E` is the number of XP-32 channels the chassis presents, and the
per-task test is a **presence gate**: task *n* proceeds only when the count
is at least *n*. With AC1 and AC2 populated the count is 2, and XP3I and
XP4I gate themselves off. The "dormant AC3/AC4 task slots" this project has
described now have their actual mechanism.

The second retraction is mine: an earlier revision of this section called
`$105E` a "channel selector" written by the chassis. Same location, wrong
direction and wrong meaning.

Only `$10AA` remains in the "written by something other than the CPU"
category, and even that one is qualified — F053E2 can write it, but never
runs in any tested configuration.

There are also **per-channel RAM blocks at `$1066`, `$106C`, `$1072`,
`$1078`** — stride 6, in channel order.

#### Emulator: the presence gate was never exercised

The four channel command ports were unmodelled and read back 0, so every
emulator run to date computed `$105E = 0` and every XP task took the skip
branch. `FPS3K_CHANNELS=<n>` now reports the first *n* channels as
populated; the default stays 0 so existing results are unchanged.

Verified per channel — with `FPS3K_CHANNELS=2` the newly-reached PCs are
exactly:

| PC | what it is |
|---|---|
| `F0A20A`, `F0A212` | the two `addq.w #1,d1` increments, channels 1 and 2 |
| `F07E00` | XP1I's present-path, previously skipped |
| `F07400` | XP2I's present-path |

and `F07E08`/`F07408` (the absent-path) drop out. XP3I and XP4I are
unchanged, since 2 < 3. That is precisely what the gate predicts.

**It does not unblock the XP tasks.** Each still executes about 45 distinct
instructions from its entry point and then enters the RMS68K kernel at
`$F00262` to wait — they are blocked on their BIM interrupt, which nothing
in the model generates. The gate was a second, independent reason the tasks
did nothing; removing it exposes the first. What a populated channel really
presents at `+$0E` is also unknown, so the stub returns a placeholder `$0001`
— the firmware only tests nonzero.

#### XP4I is a different variant, not a degraded copy

Sequence-aligning XP1I against XP4I shows XP4I both **adds and removes**
code, netting −1 byte:

| | XP1I | XP4I |
|---|---|---|
| `move.w #$8020,$202(a5)` (XLTR MODE1) | absent | **present** ($F06005) |
| `$1F41`/`$1F45` constants | absent | **present** ($F060B4) |
| `btst #$B,$1066` + `move.w #1,d0` (15 b) | present ($F07E8F) | absent |
| load-pair + trigger (18 b) | present ($F07EBE) | **absent** |

The 18-byte block XP4I lacks is exactly the sequence the previous commit
identified from constant counts:

```
$F07EC0  movea.l #$FF004E,a0     ; command port
$F07EC6  move.w  #$0,(a1)        ; 32-bit data, high half
$F07ECA  move.w  #$1B,$2(a1)     ; 32-bit data, low half
         move.w  #$8000,(a0)     ; fire
```

Counting the two halves separately makes the asymmetry exact:

| | XP1I | XP2I | XP3I | XP4I |
|---|---|---|---|---|
| `movea.l #$FF00xE,a0` | 2 | 2 | 2 | **1** |
| `move.w #$8000,(a0)` (fire) | 1 | 1 | 1 | **0** |

XP4I still loads its command port once — so it is not that channel 4 is
unaddressed — but it **never fires the trigger**.

That confirms the earlier finding by an independent method, and corrects its
framing. **XP4I is not "the same task minus a trigger".** It is a variant
with its own XLTR MODE1 write and its own constants, which happens also to
omit the load-and-fire sequence. The earlier "19.5% different" figure and
the follow-up "XP4I lacks the trigger site" both pointed at this without
resolving it; the exact-bounds diff resolves it.

**What it means is open.** Two readings, neither established:

1. **A different device on channel 4.** The `$8020` MODE1 write and the
   absence of the XP-32 data-load-and-fire suggest channel 4 addresses
   something that is not an XP-32 AC.
2. **Version skew.** XP4I may be an older or newer revision of the same
   template that the other three were not resynchronised with.

Reading 1 is the more interesting and reading 2 the more likely, since
`$8020` differs from the common `$8000` in one bit. Nothing here decides it,
and the chassis populates only AC1 and AC2, so channel 4 is dormant either
way.

### The TDTI table declares each task's entry point and exact code extent

The six `!TCB` entries at `$F0A600`, `$60` apart, carry more than a name.
Byte-exact field layout, relative to the `!TCB` marker:

| Offset | Field |
|---|---|
| +`$00` | `!TCB` marker |
| +`$04` | 4-char task name |
| +`$1C` | **entry point** (longword) |
| +`$20` | **region start**, high word (`<<8`) |
| +`$22` | **region end**, high word (`<<8 | $FF`) |
| +`$24` | `$00000001` |
| +`$40` | `PROG` + `$80000000` — section marker |

| task | entry | region | bytes |
|---|---|---|---|
| RDHC | `$F046F0` | `$F04600-$F05CFF` | 5888 |
| IO1I | `$F05D36` | `$F05D00-$F05EFF` | 512 |
| XP4I | `$F05F4A` | `$F05F00-$F068FF` | 2560 |
| XP3I | `$F0694A` | `$F06900-$F072FF` | 2560 |
| XP2I | `$F0734A` | `$F07300-$F07CFF` | 2560 |
| XP1I | `$F07D4A` | `$F07D00-$F086FF` | 2560 |

**The six regions partition `$F04600-$F086FF` exactly** — contiguous, no
gaps, no overlaps. This is the ROM's own statement of the task layout, and
it settles the region-boundary question completely.

Three details follow from it.

**All four XP tasks are exactly `$A00` bytes and all four enter at
base+`$4A`.** The `$A00` spacing this project has used was inferred from
code similarity; the table declares it. The identical entry offset is
further evidence for the template-copy reading of the four channel tasks.

**RDHC's entry `$F046F0` is the address already documented** as the TCBRDHC
main loop, reached independently. The other five entry points —
`$F05D36`, `$F05F4A`, `$F0694A`, `$F0734A`, `$F07D4A` — are the task bodies,
distinct from the ISR handlers at +`$0C` of the descriptor blocks.

**Entry point and interrupt handler are separate.** Each task has a body
(from the TDTI table) and an ISR (from its descriptor block), and neither
structure mentions the other's address. The RTOS uses the TDTI entry to
create the task; the vector table gets the descriptor's handler.

Together with the descriptor blocks and the BIM programming, there are now
three independent structural declarations in the ROM, and they agree.

### The ROM declares the vector-to-task mapping itself

Each task's region does not merely *begin* at the addresses this project
has been using — it begins with a **task descriptor block** that states the
task's identity and interrupt wiring in data:

| Offset | Field | RDHC | IO1I | XP4I | XP3I | XP2I | XP1I |
|---|---|---|---|---|---|---|---|
| +`$00` | name (ASCII) | `RDHC` | `IO1I` | `XP4I` | `XP3I` | `XP2I` | `XP1I` |
| +`$04` | zero | . | . | . | . | . | . |
| +`$08` | **vector number** | `$41` | `$4A` | `$48` | `$47` | `$46` | `$45` |
| +`$0C` | **handler address** | F04930 | F05DD6 | F060CE | F06AE6 | F074E6 | F07EE6 |
| +`$10` | ISR exit / continuation | F050FC | F05E4C | F060F0 | F06B08 | F07508 | F07F08 |
| +`$14` | owner string | `USER` | `IO1I` | `XP4I` | `XP3I` | `XP2I` | `XP1I` |

Two consequences.

**The vector-to-task mapping is no longer an inference.** It was derived
originally from the BIM control- and vector-register writes, then
corroborated by the F046E0 lookup table and by the constant-ownership map
above. This is the machine's own declaration, in a fixed-offset field, and
it agrees with all three.

**The region boundaries are exact, not heuristic.** CLAUDE.md warns that
"the region bounds in `build_clean_disasm.py` are approximate and a code
address can be attributed to the neighbouring task". Anything starting at
one of these six descriptor blocks and running to the next is exactly one
task. The `+$10` field also names F05E4C directly — the address this
project had already identified as TCBIO1I's ISR exit, reached for the first
time only after the mailbox path was driven correctly.

### Ten BIM vectors are programmed; six are enabled, four go nowhere

A single routine at **F0A164-F0A1CA** programs the BIM file, and it covers
considerably more than the six channels the firmware uses. It clears six
control registers and then writes **ten vector registers with the
contiguous block `$41`-`$4A`**, each value exactly once:

| BIM | base | ch0 | ch1 | ch2 | ch3 |
|---|---|---|---|---|---|
| 0 | `$FF0230` | `$41` **en** ($5E) | `$42` dis | `$43` dis | `$44` dis |
| 1 | `$FF0240` | — | `$49` dis | `$45` **en** ($5F) | `$46` **en** ($5F) |
| 2 | `$FF0250` | `$47` **en** ($5F) | `$48` **en** ($5F) | `$4A` **en** ($5F) | — |

Of the twelve BIM channels: **six enabled**, **four vectored but left
disabled** (`$42`, `$43`, `$44`, `$49`), **two untouched** (BIM1 ch0, BIM2
ch3).

The four disabled ones have **no handler anywhere in the firmware**. Vector
numbers are declared only in the six task descriptor blocks above, and none
of them carries `$42`, `$43`, `$44` or `$49`. So these are provisioned but
unimplemented: FPS allocated a contiguous ten-vector block across the three
BIMs, and this configuration wires up six of them.

The firmware is self-consistent about it — the four have their IRE bit
clear, so they cannot fire.

**A claim made here earlier is retracted.** This section originally said that
if one of the four *did* interrupt it would "dispatch through a DRAM vector the
RTOS never wrote … a jump to a garbage address". Dumping the whole vector table
after a boot shows every one of the 256 vectors is written, and the four split
two ways:

| BIM channel | vector | address | handler |
|---|---|---|---|
| BIM0 ch1 | `$42` | `$108` | `F00896` — RMS68K generic handler |
| BIM0 ch2 | `$43` | `$10C` | `F00896` |
| BIM0 ch3 | `$44` | `$110` | `F00896` |
| BIM1 ch1 | `$49` | `$124` | **`F0A27A` — the panic catch-all** |

The split is an accident of one address. The application's vector fill at
`$F0A146` starts at **`$124`** and runs 182 entries, so everything below it
keeps whatever earlier initialisation left — the generic handler — and `$124`
is *exactly* vector `$49`, the first entry the fill overwrites.

So three of the four spare channels would be serviced harmlessly and the fourth
would panic. That is a sharper and less alarming statement than the one it
replaces, and it was only reachable by dumping the table rather than reasoning
about it.

#### The rest of the table

| vectors | handler |
|---|---|
| 0, 1, 31 | `F088FC` |
| 2, 3, 4, 5, 6 (bus error, address error, illegal, div0, CHK) | `F0A23A`, `F0A242`, `F0A24A`, `F0A252`, `F0A25A` — one each |
| `$030`-`$110` assorted | `F00896` ×37 |
| `$104`, `$114`-`$128` | the six task ISRs |
| `$124`-`$3FF` | `F0A27A` ×182, **except `$230`** |

**`$230` (vector 140) is the fill's only deliberate exception** —
`cmpa.l #$230,a0 / beq` steps over it, preserving `F00896`. A watchpoint shows
`$F09CF6` (`move.l a4,(a3)+`, a generic fill loop) put it there earlier in the
same boot. So the firmware installs a handler at vector 140 and then takes care
not to clobber it.

**But "installs a handler" overstates it, and the earlier note's "meant to be
serviced" is wrong.** `F00896` is:

```
$F00896  btst #$E,$0C34      ; test a flag in RAM
$F0089C  beq  -> $F008A4
$F0089E  bsr  $F01688        ; ...optionally call something
$F008A4  rte
```

It tests a flag, optionally calls one routine, and returns. It is the handler
on **37 vectors**, and what it does is *ignore the interrupt*. So the fill's
exception for `$230` makes vector 140 **non-fatal**, not serviced — those are
different things, and the distinction matters for anyone reasoning about what
the hardware is expected to do.

Two negatives worth recording, since they bound the question:

- **Nothing in this ROM ever writes the value `$8C` to any register** — not in
  the FPS application region and not in the RMS68K kernel. Every vector number
  the firmware programs goes into a BIM vector register, and those only ever
  carry `$41`-`$4A`.
- **Nothing references `$230` anywhere except the fill's own `cmpa.l`** —
  again in neither region.

So vector 140 is not configured by this firmware at all. Either a device
supplies it from a power-on default or from configuration done elsewhere (a
card this ROM does not program), or it is an RMS68K-internal allocation the
kernel expects to survive. The firmware's only stated position on it is
"do not panic".

The natural reading of the block is that BIM0's four channels serve the
chassis command interface (ch0 = `$41` is the panel-status response handler)
and that FPS provisioned three more sources there than this chassis uses.
That is a reading, not a finding: nothing establishes what `$42`-`$44` would
have been.

### Correction: the TDTI table is at `$F0A600`

CLAUDE.md gives the `TCBDefinitionTable` as `$F0A57E`. The `!TCB` marker is
at **`$F0A600`** (`$F0A5FE` counting the two zero bytes before it).
`$F0A57E` is code — a panel-command issuer that writes `$FF000E`, `$FF0202`,
`$FF0204` and `$FF0200` and then ends in `60FE`, the documented `bra .`
spin-wait. The consolidated `fps3k.asm` already uses `$F0A600`.

### Every chassis address constant, by owning task

Scanning for `movea.l #imm,aN` (`2x7C`) and `lea imm.l,aN` (`4xF9`) with
a chassis operand gives a complete map of which task references which
address:

| constant | pre | RDHC | IO1I | XP4I | XP3I | XP2I | XP1I | init | RTOS |
|---|---|---|---|---|---|---|---|---|---|
| `$700000` | . | . | **1** | . | . | . | . | . | . |
| `$FF0000` | 1 | 15 | 4 | 9 | 9 | 9 | 9 | 4 | 2 |
| `$FF0048` / `$FF004E` | . | . | . | . | . | . | **1 / 2** | . | . |
| `$FF0068` / `$FF006E` | . | . | . | . | . | **1 / 2** | . | . | . |
| `$FF0088` / `$FF008E` | . | . | . | . | **1 / 2** | . | . | . | . |
| `$FF00A8` / `$FF00AE` | . | . | . | **1 / 1** | . | . | . | . | . |
| `$FF0244` | . | . | . | . | . | . | **1** | . | . |
| `$FF0246` | . | . | . | . | . | **1** | . | . | . |
| `$FF0250` | . | . | . | **·** | **1** | . | . | . | . |
| `$FF0252` | . | . | . | **1** | . | . | . | . | . |

Three things fall out.

**Channel isolation is total.** Each XP task references exactly three
chassis constants — its own data-hi port, its own command port, and its
own BIM control register — and never another channel's. There is no
cross-channel access anywhere in the firmware.

**`$700000` is loaded by TCBIO1I alone**, confirming from a third
direction that the host mailbox belongs exclusively to that task.

**The BIM column is a third independent confirmation** of the
channel-to-BIM mapping, after the F046E0 table and the CR write sites:
`$FF0244`→XP1I, `$FF0246`→XP2I, `$FF0250`→XP3I, `$FF0252`→XP4I.

`$FF0000` is simply the base register every region loads before using
displacements, which is why it dominates.

*Method note: the first run of this scan used the wrong opcode mask —
`movea.l #imm,aN` masks to `$207C`, not `$217C` — and returned four hits
in total. It was caught because the result contradicted an established
fact (that `$FF0048` appears once as a `movea.l` operand). Having
verified claims to check a new tool against is what makes the tool
trustworthy.*

### What TCBXP4I's divergence actually consists of

The task-body diff puts XP4I 19.5% different from XP3I without saying
*what* differs. Counting address constants answers it precisely.

Every channel-port constant appears as an explicit `movea.l #imm,aN`, and
the counts are symmetric except in one place:

| constant | ch1 | ch2 | ch3 | ch4 |
|---|---|---|---|---|
| data-hi `+$08` | 1 | 1 | 1 | 1 |
| command `+$0E` | **2** | **2** | **2** | **1** |

The site channel 4 lacks is the second `movea.l`, the one that precedes
the trigger. Channels 1-3 each contain:

```
movea.l #$FF00xE,a0       ; the command port
move.w  #$0,(a1)          ; 32-bit data, high half
move.w  #$1B,$2(a1)       ; 32-bit data, low half
move.w  #$8000,(a0)       ; fire
```

at F07EC2/F07EC6, F074C2/F074C6 and F06AC2/F06AC6. **TCBXP4I has no
equivalent — it writes `$8000` nowhere in `F05F00-F068FF`.**

So XP4I is not merely "the edited copy": it is missing the
load-pair-then-trigger sequence that the other three use to hand a 32-bit
value to their channel. Whether that is deliberate (channel 4 being
driven differently) or an omission in the original source is not
established, but it is a concrete, checkable difference rather than a
percentage.

It also explains the `$9FA` spacing seen between XP3I's and XP4I's port
constants where the task bodies align at `$A18`: the missing site shifts
everything after it.

### Bit 5 is not derived from VMOD at all

The bit-7 rule above is also wrong, and the **pattern table at F08E8C
settles the question**. F08E2E walks eight longwords through `$1FFF0`
and reads each back:

```
0010FFFF  009F00FF  0F1F0F0F  33133333
AA9AAAAA  55155555  FF9FFFFF  00100000
```

The byte landing in `$1FFF1` is `$10, $9F, $1F, $13, $9A, $15, $9F, $10`.
**Every one has bit 6 clear**, and several (`$9F`, `$9A`) have bit 7 set.
So:

- a **bit-6 mirror** reads back set at F08732 (because the gate write
  `$50` sets bit 6) and blocks the diagnostics entirely;
- a **bit-7 mirror** stays clear at the gate but goes set on the second
  pattern, and `PollBoardStatus` then takes its `bra F088F4` abort path
  in the middle of the test.

Neither can be the design. Read instead as an **independent chassis
status line** — 0 meaning no fault, run the diagnostics — both sites are
satisfied simultaneously. That the pattern author kept bit 6 clear in all
eight patterns is itself evidence the register's upper bits carry chassis
meaning that the test deliberately avoids disturbing.

With bit 5 modelled that way:

| | diagnostic PCs | XLTR accesses | MainInit reaches |
|---|---|---|---|
| original (bit-6 mirror) | 0 | 27 | gate skips everything |
| bit-7 mirror | 109 | 151 | F0878E |
| **independent line** | **351** | **142** | **F087AA** |

`F087AA` is `move.w #$d0,(a5)` — the "tests complete" write. The first
test block now runs to completion and execution proceeds into the
panel-bus diagnostics, ending at `F09126` in `IOChannelDiagnostic`, which
spins 331,919 times reading `$2(a0)` on the I/O Channel window. Per the
M68KVM02 memory map this chassis has **no I/O Channel boards**, so that
test may need an absent-board response modelled, or may not be intended
to pass here at all.

Hook: `FPS3K_BSTAT19_B5` forces the bit either way.

**Still inference, not proof.** What is established is negative and
solid: bit 5 is a mirror of neither bit 6 nor bit 7 of `$1FFF1`, because
each choice breaks one of the two sites that read it.

### What this calibrates

- The chassis bit-mapping equations in CLAUDE.md, each annotated
  "verified against phase `$1100`/`$1200`", "phase `$1400` stage 3",
  "phase `$800`" — **those phases do not run**. Whatever verification
  produced those equations is not reproducible in the current build, and
  they should be read as derived-from-static-reading, not validated.
- A green boot demonstrates the CPU core, RAM, ROM, vector table, RMS68K
  and the PTM. It demonstrates almost nothing about the VersaBus
  interface, because the boot barely touches it.
- Every register description written from boot behaviour was written from
  a sample of 27 XLTR accesses. That is why `$20C`, `$216` and the
  channel-window labels were all wrong: the operational values live in
  code the boot never reaches.

The actionable item is concrete: make `PollBoardStatus` pass, and the
entire `F08D00-F09BFF` diagnostic suite becomes available as a **test
harness for the chassis model** — several thousand instructions of the
firmware's own checks on hardware behaviour. Hook: `FPS3K_BSTAT19`.

## Two XLTR register descriptions cite diagnostics as operation

CLAUDE.md's XLTR table describes `$20C` as "Counter/Config, written
`0x01`, `0xFF`" and `$216` as "Command Register, single-bit cmds
`0x10`/`0x20`/`0x40`/`0x80`". Both take their values from the boot
self-test and miss what the register does in service.

**`$20C`** is written `$4` **seven times**, and that is the operational
value — F04AC2 immediately before the bulk-transfer loop, F04B2C, F05A2C
inside POLL, and the four task copies at F0646C, F06E84, F07884, F08284.
`$1` and `$FF` occur once each, both inside the boot diagnostics (F09546,
F098C4), and `$1` is read back and compared at F0959A, so the register is
also readable. The documented values are the two that never run outside
self-test; the one that matters is absent.

**`$216`** takes `$10`, `$20`, `$40` and `$80` exactly **twice each**,
all of them between F09626 and F09872 — the panel-bus diagnostic phases.
They are set-then-test probe pairs, not commands. The one value written
outside that range is `$C0` at F0A22A, in `RTOSKernelInit`, and `$C0` is
`$80|$40` — not single-bit at all, which contradicts the "single-bit
cmds" characterisation directly.

In service `$216` is **read-modify-written**: F04EA0/F04EAA,
F0550A/F05512, F05582/F0558A — three reads and thirteen writes in total.
That is the behaviour of a mode or page register, which is what the
emulator already treats it as (`xltr_data_hi() & $20` gates BERR on the
`$400000` window, derived from diagnostic phase `$1700`). Calling it a
command register with single-bit commands describes only the probe
sequence.

Note this leaves **two** page-like registers: `$210` (MODE2), which code
`$3` loads with address bits 20-31, and `$216`, which gates `$400000`
access. Whether they are independent or one qualifies the other is not
settled here.

## The AP I/F opcode names are ours, not sourced

`$8004` and `$8005` are real: 30 and 20 occurrences, both written to
`$FF0000`, and they are the only two values that port receives. But the
names **REQUEST-TRANSFER** and **CONTINUE-TRANSFER**, used throughout
these documents as though they were part numbers, appear in no primary
source — not the M68KVM02 manual, not the VERSAdos sources. They are our
own labels, chosen from observed behaviour.

The behaviour that justifies them is real enough — `$8004` precedes the
ready/error poll that starts an operation, `$8005` appears only in the
finalize path before `PCMD_RELEASE` — so the labels are reasonable. They
should simply not be mistaken for documented FPS terminology, and no
FPS-3000 manual exists to confirm them.

## `$4F` has no connection to `$FF004A`

CLAUDE.md's host-protocol section states that the host "presents status
`0x4F` at `$FF004A`", and adds that the meaning of `$4F` beyond "byte
ready" is unknown but that it "is what makes the ROM proceed".

**Neither part survives checking.** `$4F` occurs in the ROM exactly five
times, always as `move.w #$4f,(a3)` where `a3` is a **BIM control
register** — the IRE-cleared form of `$5F`, written by `PanelSendAndWait`
and its four task copies to suppress a channel's interrupt during a
transfer. It never appears as a `$FF004A` value, and `$FF004A` is neither
read nor written anywhere in a full boot.

The `0x4F` in the documentation traces back to `host_sim.c:132` and
`versabus.c:311`, which are our own emulator's invention. The doc then
cited the emulator as though it were evidence. It is circular, and the
value has no established meaning on that port.

## The complete chassis-to-SBC command protocol

Everything above assembles into one mechanism. `$FF0204` (CHANNEL_SELECT)
is **bidirectional**: the chassis presents arguments there for the SBC to
read, and the SBC returns results by writing to it. `$E74` is the
SBC-side result register.

### The cycle

```
chassis raises BIM0 ch0, opcode in MODE0 bits 0-7, argument in CHANNEL_SELECT
  F04930   latch MODE0 -> $E86, set ACK bit 10, dispatch on bit 7 + low nibble
  handler  consume the argument, compute a result into $E74
  F04910   clear ACK bit 10 in MODE0
  F0491E   BIM0 CR0 <- $5E   (re-enable IRE, level 6)
  F04924   $E74 -> CHANNEL_SELECT   (return the result)
  F0492C   back to the wait loop
```

### Registers the protocol maintains

| Global | Role | Loaded by |
|---|---|---|
| `$E58`/`$E5A` | 32-bit address | code `$1` / `$41` |
| `$E5C`/`$E5E` | latched opcode | code `$0` |
| `$E60`/`$E62` | channel number | code `$5` |
| `$E64`/`$E66` | 32-bit word count | code `$2` / `$42` |
| `$E68`/`$E6A` | 32-bit data parameter | code `$9` |
| `$E70`/`$E72` | 32-bit chassis-memory data | code `$3` family |
| `$E74` | **result returned to the chassis** | every handler |
| `$E7A` | control-block slot index | codes `$A` / `$C` |

### The command set

| Code | Operation | Argument | Result | Evidence |
|---|---|---|---|---|
| `$0` | latch opcode and execute | opcode 0..`$10`, or `$28` = bulk transfer | — | **executed** |
| `$1`/`$41` | set address low / high | address half | — | **executed** |
| `$2`/`$42` | set count low / high | count half | — | **executed** |
| `$3`/`$43`/`$63` | chassis memory write / load-high / read | data half | `$E70` | **executed** (round trip) |
| `$5` | argument 0: report AC count; argument N: select channel N | 0 or channel | `$105E` or — | inferred |
| `$7` | disable BIM0 ch0 interrupt | — | — | **executed** (CR `$5E`->`$4E`) |
| `$9` | set data parameter | data half | — | inferred |
| `$A` | read control-block word | index in `$E7A` | `$E74` | inferred |
| `$B` | report `$10010` | — | `$E74` | **executed** |
| `$C` | read/write register-file half | index in `$E7A` | `$E74` | inferred |
| `$F` | return from interrupt | — | — | **executed** |

Code `$5` doing double duty is the notable one: with argument 0 it is a
**query** — the SBC answers with `$105E`, the AC count — and with a
nonzero argument it selects a channel. That is the only command in the
set that reports a configuration value back, and it means the chassis can
ask the SBC what it believes the machine's population to be.

### Execution: `PanelSendAndWait`

Opcode `$28` runs the polled bulk loop from `$FF0008`. Any other opcode
0..`$10` reaches `PanelSendAndWait` with the accumulated parameters:

| Register | Contents |
|---|---|
| `d0` | opcode from `$E5C` — indexes the 42-slot table |
| `d1` | address from `$E58` |
| `d2` | word count from `$E64` |
| `d3` | data parameter from `$E68` |
| `d4` | channel number from `$E60` |
| `a0` | `$FF0000`, the AP I/F command port |
| `a1` | channel data port A, `$FF0000 + $20*(ch+1) - 6` |
| `a2` | `$FF0008`, the bulk data port |
| `a3` | that channel's BIM control register, via the F046E0 table |

The `a1` formula reproduces the documented channel windows exactly:
channel 1 gives `$FF0048`, channel 4 gives `$FF00A8`.

**This refines an earlier statement in this document.** The 42-slot table
was described as indexed by "the command code passed in, not a status
code returned by the chassis". `d0` comes from `$E5C`, which is the
latched **CHANNEL_SELECT readback** — so it is chassis-supplied after
all. The accurate statement is that it is a chassis-supplied *opcode*,
latched by an earlier command, rather than a status code produced by the
transfer that `PanelSendAndWait` is about to perform.

### Measured bit usage on the mode registers

Scanning every read-modify-write sequence on the XLTR registers gives
usage counts per bit, which confirms the existing decode quantitatively
and adds three bits it does not mention:

| Register | Bit | Operations | Reading |
|---|---|---|---|
| MODE0 `$200` | 10 | `bclr` x13, `bset` x1 | response-acknowledge |
| MODE0 | 11 | `bset` x4, `bclr` x1 | response-valid |
| MODE1 `$202` | 0 | `bset` x1 | **not previously noted** (F05E04, TCBIO1I) |
| MODE1 | 6 | `bset` x4 | **not previously noted** |
| MODE1 | 7 | `btst` x15, `bset` x1, `bclr` x1 | busy — by far the most-tested bit in the block |
| MODE1 | 12 | `bset` x8 | enable |
| MODE1 | 14 | `bclr` x12, `bset` x1, `btst` x1 | control |
| STATUS_IRQ `$218` | 4 | `btst` x1 | **not previously noted** |
| STATUS_IRQ | 15 | `btst` x22 | ready/done |
| BIM0 CR0 `$230` | 4 | `bclr` x1 | IRE, cleared by response code `$7` |

The busy/enable/control assignments for MODE1 bits 7/12/14 were already
in the register table; the counts confirm them independently. Immediate
writes are narrower than the bit operations: MODE1 takes only `$8000`,
`$2000`, `$1000` and one `$8020`; `STATUS_IRQ` takes `$400` and `$0`
exactly 22 times each, which is the arm/clear pairing of the polled
transfer loop.

`DATA_HI` `$216` takes `$10`, `$20`, `$40`, `$80`, `$C0` — page selects,
consistent with the emulator's bit-5 BERR gate derived from the boot
self-tests.

### RMS68K segment management, and a shared error path

`F09D96-F09E87` is the segment allocator's lookup: a table of **10-byte
entries** — a flags byte at +1, a start longword at +2, an end longword
at +6 — walked until `d6`, testing whether the address in `d2` falls
inside a range.

What follows confirms it. `F09E88` stamps `!GST` (`$21475354`, the global
segment table) and `F09ECE` stamps `!UST` (`$21555354`, the user segment
table) — two of the six RMS68K structure tags found in the strings sweep.

**`F0A306` is a shared error path reached two different ways.** The
allocator `bsr`s it directly when a lookup fails, and it is also the
recovery address pushed by the `'BE'` bus-error guard at `F09D0E`. It
saves context to `$800` (`g_ctx_save`) and continues. So a segment lookup
that walks off a table and one that faults on a bad pointer converge on
the same handler — which is why the guard and the search sit in the same
few hundred bytes.

### Two different bus-error strategies, and `$4245` is `'BE'`

A pattern occurring five times in the application region and three more
in the RMS68K kernel:

```
pea    <recovery>(pc)        ; where to resume if this faults
move.w #$4245,-(a7)          ; $4245 = ASCII "BE"
... an access that might bus-error ...
```

`rms68k_source.SA` names it outright:

```
    PEA    KILLER(PC)     PUT ERROR RETURN ON STACK
    MOVE.W #'BE',-(A7)    BUS ERROR RETURN FLAG
```

So this is RMS68K's **software bus-error recovery convention**: the
kernel's handler scans the supervisor stack for the `'BE'` marker and, if
it finds one, resumes at the address pushed below it instead of
panicking. Application sites are F09D0E, F0A290, F0A39E, F0A414 and
F0A44A; the kernel's own are at F00D02, F01F06 and F03E40.

**The firmware uses two incompatible strategies for the same problem.**
The self-tests do *not* use this convention — phases `$0700`, `$1000`,
`$1700` and `$1800` save vector `$8` and install their own handler
(F08F06, F098E0) around each probe, restoring it afterwards. That is why
those phases can count faults precisely, and why F096AC/F096B8 pad their
single access with four NOPs: a custom handler needs the fault to land
inside a known window, whereas the `'BE'` convention only needs a marker
to be somewhere on the stack.

Worth keeping straight when reading probe code: seeing no `pea`/`'BE'`
pair does not mean an access is unguarded — check whether vector `$8` was
redirected first.

### XP task startup: guarded syscalls with per-step failure codes

`F07DC0-F07F05` is TCBXP1I's startup, and since XP1I is the template the
same code runs in all four tasks. The shape is a chain of RMS68K
syscalls, each guarded:

```
F07DC2  cmpi.w #0,d0          ; result of the previous directive
F07DC6  beq    F07DD6         ; ok, continue
F07DC8  move.w #$26E,d0       ; else: the code names WHICH STEP failed
F07DCC  jsr    F086C0         ;       emit it via the local panel issuer
F07DD2  bra    F07F0E         ;       and give up

F07DD6  moveq  #$4C,d0        ; next directive
F07DD8  lea    TCBXP1I_Data,a0
F07DDE  trap   #1
F07DE0  beq    F07DF0
F07DE2  move.w #$270,d0       ; a different code for this step
```

**This confirms the `$26E`-`$271` correction from a second direction.**
Those codes identify *which startup step failed*, not which channel — XP1I
itself uses `$26E` for steps 1 and 2, `$270` for step 3 and `$271` for
steps 4 and 5, and every other task uses the same codes at the same
points. An earlier reading had them as `PCMD_CH{1..4}_TCB_FAIL`.

### The firmware's complete RTOS call inventory

`trap #1` occurs at **68 sites** using **13 distinct directive numbers**.
The RMS68K TRAP #1 handler takes the number in **`d0`**, masks it to a
word, range-checks it and scales it by 4 into a jump table — so `d0` is
the directive and `a0`, where present, points at a parameter block.

| directive | sites | | directive | sites |
|---|---|---|---|---|
| `$2D` | 9 | | `$10` | 5 |
| `$2B` | 9 | | `$01` | 5 |
| `$0F` | 6 | | `$43` | 4 |
| `$4C` | 6 | | `$11` | 4 |
| `$13` | 6 | | `$0D`, `$2A`, `$29` | 1 each |
| `$12` | 5 | | | |

**Only `$0F` is identified: 15 = TERM, terminate task.**

The other twelve are **deliberately left unnamed**. A search of
`rms68k_source.SA` for equates matching their values returns plausible
hits for almost all of them — and every one checked was a false positive:

| number | tempting match | why it is wrong |
|---|---|---|
| 43 | `NTSRSEQD EQU $43` | hex/decimal mismatch — `$43` is 67, not 43 |
| 17 | `T0DASQX EQU 17` | a task-*stop cleanup* function code, not a directive |
| 16 | `T0DSEMX EQU 16` | same family |
| 19 | `T0EXEQDQ EQU 19` | same family |
| 13 | `W_BRK1 EQU 13` | a terminal-driver function |

The source does carry real directive equates — GTASQ 31, RDEVNT 34,
WTEVNT 36, RTEVNT 37, CMR 60 — and **none of them matches any number this
firmware uses**, which is itself informative: the FPS tasks are not using
the event or ASQ-query directives. The rest of the TRAP #1 numbering is
not in that file, and the RMS68K manual PDF has no text layer, so naming
the remaining twelve needs a source this project does not have.



### One vector is deliberately spared the panic handler

`RTOSKernelInit` fills the user vector table with the panic catch-all,
and the loop has an explicit exception:

```
F0A146  d0 = $B6                    ; 183 vectors
F0A14A  a0 = $124
F0A150  cmpa.l #$230,a0
F0A156  beq    F0A15E               ; skip this one
F0A158  move.l a1,(a0)+             ; a1 = F0A27A, the panic catch-all
F0A15E  addq.l #4,a0                ; ... stepped over, not written
F0A160  dbra   d0,F0A150
```

So every user vector from `$124` to `$3FF` gets `F0A27A` **except
`$230`**, vector number **140** (`$8C`), which keeps whatever the RMS68K
kernel put there. A post-boot dump confirms it: `$22C` and `$234` hold
`F0A27A`, `$230` holds **`F00896`**, the RMS68K generic handler.

The firmware therefore expects *something* to raise vector 140 and wants
it **serviced rather than panicked on**. Which device that is, is not
established — it is not one of the ten BIM vectors (`$41`-`$4A`, at
`$104`-`$128`), and nothing else in the ROM writes `$230` as a vector
address.

Worth not confusing with a coincidence: `$230` also appears twice in
phase `$1600` (F09570, F095D2) as `movea.w #$230,a0`, but there it is an
**offset into the XLTR window** (`$FF0230`, BIM0 CR0), not a vector.

## TCBRDHC's host command interface — a four-command API

`F05356-F05687`, flagged as the highest-value unattributed run, turns out
to be the SBC's **command interface**: what a host can ask it to do.

The dispatch at F05344 is a jump table on a **3-bit code**:

```
F05344  andi.w #$7,d1        ; command code
F05348  subq.w #1,d1         ; 1-based
F0534A  mulu.w #$6,d1        ; 6 bytes per entry (jmp abs.l)
F0534E  lea    F05358,a1
F05354  jmp    (a1,d1.w)
```

The table holds **four** entries, so codes 5-7 would jump into handler
code — either the caller guarantees 1-4, or that is a latent bug.

| code | handler | what it does |
|---|---|---|
| 1 | `F05370` | **attach/configure a channel**. Takes the channel from `$4(a6)`, defaults to `$E62`, validates `1 <= ch <= $105E`, then sets `$1080[ch] = &$101E`, `$10A0[ch] = 2`, and builds the ASQ name from `$48585030` = `"HXP0"` + channel |
| 2 | `F054A2` | **register-file access** — copy to or from the 16-longword block at `$101E`, by a (direction, index, count) descriptor. The `exg a1,a0` makes one loop serve both directions |
| 3 | `F054E8` | same shape, for the block at `$E8A` |
| 4 | `F05502` | **start a transfer** — load the word count into `$E64`, then `bset #4` on `DATA_HI` |

Every handler saves MODE2 on entry and the shared exit at `F05678`
restores it (`move.w (a7)+,$210(a0)`), so a command cannot leave the
chassis page register disturbed. The entry from the main loop, `F05684`,
is `moveq #$F,d0 / trap #1` — RMS68K directive `$F`.

**`DATA_HI` bit 4 is a transfer enable.** Code 4 sets it to start a
transfer, and the self-tests write `$10` — bit 4 — to `DATA_HI` in phases
`$1700` and `$1800`. Two independent uses of the same bit for the same
purpose.

That is the fourth distinct command surface in this firmware, and worth
keeping separate from the others:

| surface | who drives it | where |
|---|---|---|
| chassis response codes | chassis -> SBC | F05102 table, 16 opcodes |
| panel commands `$258`-`$2A0` | SBC -> chassis | via `$FF000E` |
| 42-slot dispatch | chassis opcode via `PanelSendAndWait` | five copies |
| **host commands 1-4** | **host -> SBC** | **F05344, this section** |

### Coverage map: what is left to analyse

Combining the replication map with the named routines and finding notes
in `fps3k.asm` gives a defensible answer to "how much is understood".

Counting only **named** routines (45) and **finding notes** (36) — not
the 1,132 auto-generated `loc_F0xxxx` labels, which sit about 21 bytes
apart and would make any proximity metric meaningless:

| | bytes |
|---|---|
| unique logic (replication removed) | 14,792 |
| attributed to a named routine or finding | 12,796 — **87%** |
| unattributed, in runs of 200 B or more | **0** |

*(53% -> 69% -> 74% -> 76% -> 82% -> 87% as the backlog was worked. No
unattributed run of 200 bytes or more remains; what is left is scattered
fragments below that size, mostly RMS68K glue.)*

The last three runs closed were the tail of phase `$0100` (a
bit-manipulation test — 9 `bset.b`, 5 `bclr.b`, a `bchg.b` and an
`asl.l`, each guarded by the error flag), the second checkpoint at
`F08832` with its block-selection branch, and a register data-path test
at `F099EE` that propagates a value `d0`->`d1`->`d2`->`d3`->`d4` and
checks it survives — **not** a RAM verify, despite sitting next to the
RAM tests, which is what its position suggested before reading it.

**The ten largest unattributed runs**, which are the work queue:

| range | size | region |
|---|---|---|
| `F0929C-F098EB` | 1,616 B | self-test |
| `F05356-F05687` | 818 B | TCBRDHC |
| `F099EE-F09C05` | 536 B | self-test |
| `F08B5C-F08D5D` | 514 B | MainInit |
| `F0A14E-F0A331` | 484 B | init/RTOS |
| `F07DC0-F07F05` | 326 B | TCBXP1I |
| `F0A432-F0A55D` | 300 B | init/RTOS |
| `F09072-F09175` | 260 B | self-test |
| `F09D96-F09E87` | 242 B | init/RTOS |
| `F08832-F08901` | 208 B | MainInit |

Two observations worth acting on.

**The self-test backlog is now cleared.** It was 2,412 of the 5,304
bytes, and naming its phase routines took the total from 53% to 69%. All
twenty-two phase entry points now carry their phase number and what they
assert, cross-referenced to `selftest_reference.md`.

Two helpers found while doing it are worth recording on their own.
`F096AC` and `F096B8` are one instruction each — a single word read, and
a single word clear — followed by **four NOPs** and `rts`:

```
F096AC   move.w (a1),d0      F096B8   clr.w (a1)
         nop nop nop nop              nop nop nop nop
         rts                          rts
```

The padding is not filler. On a 68000 a bus error is **asynchronous** and
arrives some cycles after the access that caused it. Isolating the access
in a subroutine with four NOPs after it guarantees the exception is taken
*inside the helper*, at a known point, rather than at whatever
instruction the caller happens to be executing when it lands. That is
what lets phases `$1700` and `$1800` test the `$400000` window's access
gating reliably: the caller can tell whether its probe faulted.

**`F05356-F05687` in TCBRDHC is the highest-value single run.** It sits
immediately before `PanelIOConfigure_25A` and contains the descriptor
copy loop at F0549E and the `HXP0` ASQ-name builder at F053B6, both only
partly traced. It is command-path code, so it bears directly on driving
the machine.

The 47% figure should not be read as "half the firmware is a mystery".
Much of the unattributed remainder is RMS68K glue and init sequencing
whose *behaviour* is understood from traces even where no name has been
attached. It measures documentation coverage, not comprehension.

### A quarter of the application firmware is literal copy-paste

The seven-copy issuer and the five-copy dispatch table are not isolated
cases. Hashing every 48-byte window across `$F04488-$F0A600` and counting
recurrences:

| window | bytes that repeat earlier code | share |
|---|---|---|
| 32 B | 7,874 of 24,952 | **31.6%** |
| 48 B | 7,134 of 24,952 | **28.6%** |
| 64 B | 6,266 of 24,952 | **25.1%** |

579 distinct 48-byte blocks occur more than once, and the distribution is
telling: 481 of them appear **four or five times** — once per XP task,
sometimes plus TCBRDHC. Another 5 appear fifteen times, which is five
regions times three sites within each.

The longest exactly-duplicated runs are all at the `$A00` task stride:

```
  410 B   F07168 (XP3I) == F07B68 (XP2I)
  408 B   F07B68 (XP2I) == F08568 (XP1I)
  408 B   F06750 (XP4I) == F07168 (XP3I)
  214 B   F065D2 (XP4I) == F06FEA (XP3I) == F079EA (XP2I) == F083EA (XP1I)
  192 B   F05B92 (RDHC) == F065D2 (XP4I)
  176 B   F05A0E (RDHC) == F0644E (XP4I) == ... == F08266 (XP1I)
```

Note the last two: **TCBRDHC shares 192- and 176-byte blocks with the XP
tasks**, which are the dispatch handlers (`POLL`, `D1_SEND`, `BLK_XFR`,
`D2_FIN`) that the five copies of the 42-slot table jump into.

### Counting the near-copies too: 38%, and 15.1 KB of unique logic

28.6% counts only **exact** 48-byte repeats. The detector is
shift-independent — it hashes every window at every position, so XP4I's
`$18` offset does not hide anything by itself — but a window containing a
**single** differing byte never matches. Per-channel constants are
scattered through the task bodies, so most windows in a copied task
contain one.

Measuring each task against its template directly:

| task vs template | bytes shared | detector caught | uncounted |
|---|---|---|---|
| XP2I vs XP1I | 2452 / 2528 | 1686 | **766** |
| XP3I vs XP2I | 2451 / 2528 | 1686 | **765** |
| XP4I vs XP3I | 2035 / 2528 | 1186 | **849** |

XP4I's catch rate is lowest (48% against 67%) because it is both shifted
and the most edited, but all three lose roughly a third of their shared
content to the exact-match requirement.

| | bytes | share |
|---|---|---|
| exact repeats | 7,134 | 28.6% |
| + near-copies uncounted | 2,380 | |
| **= replicated** | **9,514** | **38.1%** |
| **unique logic** | **15,438** | **15.1 KB of 24.4 KB** |

**So nearly two fifths of the application firmware is the same code
again, and the genuinely distinct logic is about 15 KB.** That is the
number worth carrying.

Practically, it means a routine found in one task region can be assumed
present in the other four unless shown otherwise, and that time spent
analysing XP2I, XP3I **or XP4I** is largely wasted — TCBXP1I is the
template and all three others are near-copies (3%, 3% and 19.5%
different, each measured at its own stride).

Counting near-copies as well as exact repeats raises the figure to
**38.1%**, leaving **15.1 KB** of genuinely distinct logic — see the
table above.

### The panel-command issuer exists seven times, byte for byte

The "two tiers of spin" table elsewhere in this document lists seven
`bra .` sites: F04530, F056B8, F05E86, F068D8, F072F0, F07CF0, F086F0.
They are not seven similar routines — they are **seven byte-identical
copies of the same 50-byte block**, and each listed spin is that block's
final instruction.

| copy | starts | spins at | region |
|---|---|---|---|
| 1 | `F04500` | `F04530` | **pre-task init — outside every TDTI region** |
| 2 | `F05688` | `F056B8` | TCBRDHC (`PanelIOConfigure_25A`) |
| 3 | `F05E56` | `F05E86` | TCBIO1I |
| 4 | `F068A8` | `F068D8` | TCBXP4I |
| 5 | `F072C0` | `F072F0` | TCBXP3I |
| 6 | `F07CC0` | `F07CF0` | TCBXP2I |
| 7 | `F086C0` | `F086F0` | TCBXP1I |

The block is: stage the command in `$E6E`, write it to `$FF000E`, set
MODE1 bit 12 and clear bit 14, clear MODE0 bit 10, write CHANNEL_SELECT,
then `bra .`. A byte-for-byte search over `$F04488-$F0A000` finds exactly
these seven and nothing else.

Two things follow.

**The spin tiers are a property of context, not of code.** The same
instructions park at IPL 0 in a task and at IPL 7 inside an ISR. There is
no "task-context issuer" and "ISR-context issuer" to tell apart — the
difference is entirely who called it.

**Copy 1 is the interesting one.** It sits at `F04500`, before the first
TDTI region, so it runs when no task exists yet. That is the firmware
issuing a panel command during early initialisation, which is consistent
with the EU being alive at power-on from its mask PROM: the SBC can talk
to the chassis before it has an RTOS, let alone microcode.

This is the same replication pattern as the 42-slot dispatch table (five
copies) and the four XP task bodies on the `$A00` stride. The firmware
was built by copying blocks and patching constants, and recognising that
saves treating each copy as a separate routine to analyse.

### The dispatch table exists five times, and is position-independent

The 42-slot table decoded elsewhere in this document as
`PanelStatusDispatchTable` at `F05BA4` is the TCBRDHC copy. There are
**five**, one per task region, and they are **byte-for-byte identical**:

| Copy | Region |
|---|---|
| `F05BA4` | TCBRDHC |
| `F065E4` | TCBXP4I |
| `F06FFC` | TCBXP3I |
| `F079FC` | TCBXP2I |
| `F083FC` | TCBXP1I |

Identical bytes, different behaviour — because every slot is `4EFA`,
`jmp d16(pc)`, which is **PC-relative**. The same bytes at a different
address resolve to different targets, and each copy lands entirely inside
its own task:

| Copy | slot 1 | slot 2 | slot 8 | slot `$14` |
|---|---|---|---|---|
| RDHC | F05A12 | F058B2 | F05B0E | F05738 |
| XP4I | F06452 | F062F2 | F0654E | F06178 |
| XP3I | F06E6A | F06D0A | F06F66 | F06B90 |
| XP2I | F0786A | F0770A | F07966 | F07590 |
| XP1I | F0826A | F0810A | F08366 | F07F90 |

This is why the table is built from PC-relative jumps rather than a list
of addresses, and it completes the picture of how the four channel tasks
were produced. A task body is a **relocatable block**: its internal jump
tables need no relocation at all, so copying the block and patching the
~45 per-channel constants listed above yields a working new channel. The
FPS engineers wrote one channel task and replicated it — and TCBXP4I,
the 90%-divergent one, is where that replication stopped being literal.

An 82-byte companion table (`PanelErrorMaskTable` in the RDHC copy at
`F05C4C`) is replicated the same way, once per region.

### The TDTI table gives exact task code regions

The task definition table at `F0A600` has `$C0`-byte entries: `!TCB` plus
a 4-character name at +0, a start/end address pair at +`$20`, and `PROG`
at +`$40`. Decoding the pairs:

| Task | Region |
|---|---|
| TCBRDHC | `F04600-F05CFF` |
| TCBIO1I | `F05D00-F05EFF` |
| TCBXP4I | `F05F00-F068FF` |
| TCBXP3I | `F06900-F072FF` |
| TCBXP2I | `F07300-F07CFF` |
| TCBXP1I | `F07D00-F086FF` |

Every known entry point falls in its own region — F046F0 in RDHC, F05DD6
in IO1I, F06018 in XP4I, F07E12 in XP1I. This is **authoritative**
attribution from the ROM's own table, replacing the approximate region
bounds that `build_clean_disasm.py` uses and that CLAUDE.md flags as
unreliable.

### `$26E`-`$271` are failure types, not channels — correction

CLAUDE.md names `$26E`-`$271` as `PCMD_CH{1..4}_TCB_FAIL` and records the
channel numbering as unresolved, warning "do not rely on the channel
numbers in this block". The block is not per-channel at all.

| Code | Sites |
|---|---|
| `$26E` | F05F92, F05FC8, F06992, F069C8, F07392, F073C8, F07D92, F07DC8 |
| `$26F` | **unused** |
| `$270` | F05FE2, F069E2, F073E2, F07DE2 |
| `$271` | F0607A, F060A0, F06A78, F06AAC, F07478, F074AC, F07E78, F07EAC |

Each code appears in **all four** task regions, at the same offset within
each: `$26E` at +`$92`, `$270` at +`$E2`. They are **failure-type** codes
that every channel task emits, and the channel identity must travel
separately — `$1062` or the channel select. `$26F` is never emitted.

The old reading came from attributing one site to one task. With the TDTI
regions above, all four sites per code are visible and the pattern is
unambiguous.

### Two S-record parsers, differing in terminator

There are two independent type-code comparison chains:

| Parser | Accepts |
|---|---|
| F04B8A-F04C06 | S0 S1 S2 S3 **S8** S9 |
| F05522-F05560 | S0 S1 S2 S3 **S7** S9 |

S7, S8 and S9 are the 32-, 24- and 16-bit start-address terminators, so
the second parser is the one that pairs correctly with S3 data records.
CLAUDE.md lists only "S0/S1/S2/S3/S8/S9" for the ROM.

### RMS68K structure tags stamped by the application

Beyond the `!TCB`/`!CCB`/`!ASQ`/`!TST`/`!DLY` markers already documented,
the application's init code stamps six more:

| Tag | Written at |
|---|---|
| `!VCT` | F09C9A |
| `!GST` | F09E88 |
| `!UST` | F09ECE |
| `!IOV` | F09F52 |
| `!IDV` | F09F80 |
| `!PAT` | F09FB2 |
| `!UDR` | F0A000 |

### `PanelSendAndWait` — and who really calls the 42-slot table

An earlier section records that `F0572C`, the `PanelStatusDispatchTable`
dispatch site, is never reached from `F04930` and "belongs to a different
caller". The caller is **`PanelSendAndWait` (F056BA)**, and it has only
three call sites (F04CE8, F05436, F05468), none of which a stock boot
reaches. That is why the table never executes.

The engine, in order:

```
(a3) <- $4F              ; a3 = this channel's BIM CR — clears IRE bit 4
(a1) <- 0                ; a1 = channel data port
$2(a1) <- d0             ; the command word
(a0) <- $8004            ; REQUEST-TRANSFER
poll (a0) bit 14         ; ready, with a 1000-iteration timeout in d5
  bit 13 set -> error path
  else       -> F0572C:  lsl.w #2,d0 ; jmp (PanelStatusDispatch, d0.w)
(a3) <- $5F              ; restore IRE on the way out
```

Two things follow. First, `a3` is the **BIM control register** obtained
from the F046E0 channel table, and the engine **disables that channel's
interrupt for the duration of the transfer** and re-enables it after —
`$4F` and `$5F` differ only in bit 4, the IRE bit. Second, the index into
the 42-slot table is **`d0`, the command code passed in**, not a status
code returned by the chassis. The table is a command dispatch, not a
status dispatch, and its name in these docs is misleading.

### `XLTR_IRQ_MASK` bit assignment

On the error path the engine reads `$FF021A`, clears one bit and writes
it back. The bit number comes from `PanelErrorMaskTable` at F05C4C,
indexed by the channel number in `d4`:

```
   F05C4C:  00 05 04 03 02 00 00 00 ...
```

| Channel | `$FF021A` bit cleared |
|---|---|
| 1 | 5 |
| 2 | 4 |
| 3 | 3 |
| 4 | 2 |

So the IRQ-mask register carries one enable bit per XP channel in bits
5-2, descending as the channel number ascends. Earlier docs record this
register only as "IRQ Mask, written `$FFF`". A channel that errors gets
masked off individually.

That descending order is the same relationship the BIM control registers
show, and it is a seventh independent confirmation of the channel
identities.

### `$101E` is a 16-longword register file with a direction flag

F0549E takes a descriptor from the command stream and copies to or from
the block:

```
d1 = (a0)+                 ; direction: 0 = write in, nonzero = read out
d2 = (a0)+                 ; start index
d3 = d2;  d2 <<= 2
a1 = $101E + d2            ; pointer into the block
d2 = (a0)+                 ; count
d3 = index + count
if d3 > $10   -> error, panel cmd $25B
if d1 != 0    -> exg a1,a0 ; swap source and destination
loop: (a1)+ <- (a0)+  x count
```

The `exg` is the whole trick: one copy loop serves both directions, and
the bound `index + count <= $10` makes the block **16 longwords**,
`$101E-$105D`. F054E8 does the same thing for a second block at `$E8A`.

Note where that leaves `$105E`: immediately after the register file. The
control block is contiguous and its pieces now all have names.

### Map of the SBC control block

| Range | Size | Contents |
|---|---|---|
| `$101E-$105D` | 16 longwords | register file, read/written by descriptor (F0549E) or a half-word at a time by response code `$C` |
| `$105E` | word | **installed-AC count** — chassis-supplied, gates the four XP tasks |
| `$1062` | word | channel number, each task writes its own |
| `$1064` | word | shared bitmask, all four tasks `and`/`or` into it |
| `$1066-$107D` | 4 x 3 words | per-channel control blocks, stride 6 |
| `$1080-$108F` | 4 longwords | per-channel pointer table (F053DA) |
| `$10A0-` | words | per-channel array (F053E2), stride 2 — `$10AA` falls here |

Response code `$A` walks `$1064` through `$107C` as 13 words; the
descriptor path walks `$101E` through `$105D` as 16 longwords. Two
different windows onto one contiguous structure, which is why their
bounds (`$C` and `$10`) differ.

### The 13-slot range check, explained

The two RAM-slot rows above run at **stride 6**, giving a per-channel
control block of 6 bytes (3 words) at `$1066 + 6*(ch-1)`:

```
   $1062   channel number (each task writes its own)
   $1064   shared bitmask (all four tasks and/or into it)
   $1066   ch1: 3 words        $1072   ch3: 3 words
   $106C   ch2: 3 words        $1078   ch4: 3 words   ... ending $107D
```

Code `$A` indexes `$1064 + 2*$E7A` with `$E7A` range-checked 0..`$C`.
That is 13 words spanning `$1064` to `$107C` — **the shared mask plus
four channels of three words each**. The bound is not arbitrary: it is
exactly this block, and the auto-increment under `$E87` bit 4 lets the
chassis walk the whole thing with repeated codes.

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

Counts over all 42 slots are POLL 9, D1_SEND 10, BLK_XFR 9, D2_FIN 1 and
13 no-ops. Earlier notes give 12/10/11 and omit the no-ops.

**Those are not the counts that matter, and an earlier revision of this
paragraph labelled them "within the range check", which was wrong.** The
check stops at `$14`, so only 21 slots are reachable and the reachable
distribution is quite different:

| Class | reachable (0..`$14`) | all 42 |
|---|---|---|
| D1_SEND | 10 | 10 |
| no-op | 6 | 13 |
| POLL | 2 | 9 |
| BLK_XFR | 2 | 9 |
| D2_FIN | 1 | 1 |

Reachable layout, in order:

```
 $0 noop     $1 POLL     $2-$7 D1_SEND      $8-$9 BLK_XFR
 $A POLL     $B-$C noop  $D-$10 D1_SEND     $11-$13 noop    $14 D2_FIN
```

### Twenty-one opcodes, four behaviours — the discrimination is the chassis's

The SBC does only four distinct things across the whole reachable set,
and the three that move anything map onto the three parts of a DMA
descriptor:

| Class | What the SBC does | Descriptor part |
|---|---|---|
| D1_SEND | push `d1` to the channel port as two words | **address** |
| BLK_XFR | copy a word between the channel port and `$FF0008` | **data** |
| D2_FIN | push `d2`, CONTINUE-TRANSFER, then `PCMD_RELEASE` | **count**, and finish |
| POLL | wait on `$FF0004` bit 0 and `STATUS_IRQ` bit 15 | — |

Ten opcodes all perform the identical SBC-side action of handing over the
address. They cannot be distinguished by anything this ROM does. What
distinguishes them is that `PanelSendAndWait` also **delivers the opcode
to the chassis**: F056C6 writes `d0` to `$2(a1)`, which is the channel's
status port (`$FF004A` for channel 1, `$FF006A`/`$FF008A`/`$FF00AA` for
the others).

That is a **principled limit on what ROM analysis can establish here**.
The SBC is a conduit: it latches an opcode, marshals address, count and
data, hands all four to the chassis, and performs whichever of its four
transfer behaviours the table selects. The opcodes' *meanings* live in
the XLTR and the XP-32 boards, not in this firmware. No amount of further
static or emulator work on the ROM will recover them — that needs the
chassis, a bus trace, or host-side software that issues them.



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

## The TRAP #0 jump table names 34 kernel routines (2026-07-30)

The kernel dispatches directives with `move.l (a0),-(a7)` / `rts` — the return stack used
as an indirect jump. A disassembler following control flow linearly loses the thread at that
`rts`, which is one concrete reason the kernel resisted automatic analysis. Following the
table by hand recovers what the linear scan cannot reach.

The 35-entry table at `$F001D6`-`$F00262` holds **34 distinct entry points**, all inside
`$F00000`-`$F04487`. Slots `$00` and `$20` share `$F00182`, the error return. Mapping the
five directives this firmware actually issues:

| dir | name | address |
|---|---|---|
| `$04` | T0PAGAL — allocate physical pages | `$F01240` |
| `$06` | T0GETTCB | `$F01710` |
| `$16` | T0WAKEUP | `$F02C6E` |
| `$18` | T0QEVNTI | `$F01602` |
| `$1F` | T0CRTCB | `$F02894` |

`$F01240` opens `movem.l d3-d5/a3-a5,-(a7)` / `move.l a0,d3` / `move.w d3,d2` — it takes its
argument in `a0` and immediately splits it into halves, matching the "size in, block address
out in `a0`" signature this project derived from the allocator's *behaviour* (`end = base +
(size<<8) - 1`). Derivation and table agree, independently.

### T0WAKEUP has two entry points, and the two-byte offset is not an accident

```
F02C6C   move.w  sr,-(a7)        <- three bsr.w callers: $F002B2, $F00962, $F009C2
F02C6E   bset.b  #$7,$c5b.w      <- TRAP #0 directive $16, from the table slot at $F0022E
```

Internal callers enter at `$F02C6C` and push SR themselves. The directive path enters two
bytes later and skips that push — **because a TRAP exception has already stacked SR**. The
offset is the calling convention, not a coincidence, and it retires the guess that
`$F02C6C` was merely "the scheduler" inferred from context: the table names it.

Two measurement notes, both the same failure mode this file has recorded before:

- A longword-pointer scan finds **zero** references to `$F02C6C`. All three callers use
  `bsr.w` with a 16-bit displacement, which stores no address at all. An absolute-address
  scan cannot see a `bsr` target, and reporting "none" would have been a false negative.
- `fps3k.asm` spans `$F04488`-`$F0FFFE`. **The kernel's 17,544 bytes — 27% of the ROM — are
  not in the project's main disassembly at all.** So these 34 entry points were never "lost
  by the disassembler"; they are outside the file by construction. The distinction matters:
  the gap is a scope decision that was never revisited, not a tool failure.

## The kernel region now has a disassembly (2026-07-30)

`tools/disasm_kernel.py` covers `$F00000`-`$F04487`, which no project artifact did before:
**45.1% of 17,544 bytes, 2,429 instructions, 461 labels.** For scale, `fps3k.asm` reaches
49.6% on the application region, so the kernel is now documented to a comparable standard.

Three seed tiers, in descending confidence:

| tier | n | why it is trustworthy |
|---|---|---|
| TRAP #0 jump table + TRAP #0 handler | 35 | the kernel's own dispatch table |
| `bsr`/`jsr`/`jmp` targets, whole ROM | 71 | a call target is code by construction |
| longwords pointing at kernel code | 51 | weaker; each must decode before it is trusted |

The call-target tier exists because of a false-negative this file has now recorded twice:
**`bsr.w` stores no address anywhere, only a 16-bit displacement.** `$F02C6C` has three
`bsr.w` callers and zero longword references, so a pointer scan calls it unreachable.

### The ROM contains no exception vector table

Measured, not assumed: `+$00` = `$00000000`, `+$04` = `$00F09C00`, and **`$08`-`$3FF` are
zero**. The reset overlay aliases ROM at address 0 solely so the 68000 can fetch SSP and PC;
everything above that is built in RAM by RMS68K at boot. Sweeping `2..255` as a vector table
yields 2 plausible-looking hits out of 254, both coincidence.

An earlier revision of the tool did exactly that sweep. It cost nothing in output quality —
the two hits were harmless — but it is the same shape of error as the `$FF0010` register the
emulator invented: a scan that *runs* and *returns results* is not evidence the thing it
scans exists.

### Static vector installs are all self-test, and they explain phase $600

Scanning for `move.l #<kernel addr>,<low memory>` finds **eight** sites, all in the self-test:

| vector | handler | sites |
|---|---|---|
| 2 (bus error), 3 (address error) | `$F08902` | `$F08706`, `$F0870E` |
| 2 (bus error) | `$F098E0` | `$F0960A`, `$F096CC`, `$F0983A` |
| 85 (`$154`) | `$F088FA` | `$F087B4`, `$F0883C`, `$F088D6` |

This is the mechanism behind a phase already documented here: **`$600` requires a BERR in
`$F80001`-`$F82001`**, and it can only survive provoking one because it installs `$F08902` on
vectors 2 and 3 first. The DRAM phases install `$F098E0` on bus error for the same reason.
Vector 85 is not a BIM vector (those are `$41`-`$4A`) and its role is unestablished.

## Two kernel conventions, both recovered from the new listing (2026-07-30)

### Nearly every directive handler has two entry points, two bytes apart

`T0WAKEUP` looked like a curiosity: `$F02C6C` pushes SR and falls into `$F02C6E`, the TRAP #0
table target. It is not a curiosity. **29 of the 33 real handlers are preceded exactly two
bytes earlier by `move.w sr,-(a7)` (`$40E7`)** — 87%.

The convention: internal `bsr` callers enter at the earlier address and push SR themselves;
the TRAP path enters at the table pointer and skips the push, **because the trap has already
stacked SR**. One routine, two calling conventions, no duplicated code.

The four exceptions confirm rather than weaken it. `$F01108` and `$F02894` (T0CRTCB) are
preceded by `$4E73` = `rte`, i.e. the previous routine ends there and no prologue exists —
these are TRAP-entry-only handlers with no internal callers.

**Consequence for any analysis of this kernel: the real routine start is two bytes before
every table pointer.** A tool seeded from the table alone mislabels 29 routine boundaries,
and a caller census that looks only at the table pointer misses the `bsr` callers entirely.

### Structure teardown uses two different invalidation mechanisms

The free routine at `$F02FBA` does three things:

```
f02fc0: move.l  $e34.w,$4(a0)    ; push onto a free list at $E34
f02fc6: move.l  a0,$e34.w        ; LIFO head update
f02fd2: not.l   (a0)             ; one's-complement each linked structure's marker
f02fda: move.l  #$21746362,(a4)  ; stamp the TCB itself '!tcb', lowercase
```

- Subordinate structures are invalidated by **one's-complementing the marker longword**.
  `$F02FD2` is the only `not.l (an)` in the kernel.
- The TCB itself gets a **lowercase `!tcb`** — `$21746362`. This is the **only** lowercase
  marker variant in the whole 64 KB; the other eleven tags appear in uppercase only. That
  fits: the TCB is the one structure ever destroyed, since the other eleven are allocated
  once at boot and never freed.

**Neither invalidated form is ever tested for.** The ROM contains zero references to
`$DEABBCBD` (`~!TCB`) or any other complemented tag, so this is one-way destruction rather
than a recoverable state.

Hard prediction for a RAM dump after a task terminates: the TCB base reads `!tcb`, and
subordinate tags read as `$DEAB…` complements. **A scan counting `!TCB` undercounts** — this
project's marker inventory and `FPS3K_RTOSDUMP` both match uppercase only. No current
configuration terminates a task, so nothing measured so far is affected.

## The TRAP #1 directive table, decoded (2026-07-30)

TRAP #0's table was the smaller half. **The TRAP #1 dispatcher is `$F00310` and its table is
at `$F003D8`, 77 entries of 4 bytes covering directives `$00`-`$4C`.**

```
F00310  andi.l  #$ffff,d0        ; directive number
F00318  bmi.b   $f00378          ; negative -> the alternate path at $F00378
F0031A  lsl.l   #$2,d0           ; *4
F0031C  cmpi.l  #$130,d0
F00322  bgt.w   $f003c6          ; BGT, so d0 == $130 is ADMITTED
F00326  lea.l   $f003d8.l,a2     ; table base
F0036A  adda.w  (a2),a2          ; handler = ENTRY ADDRESS + sign_extend(w0)
F0036C  pea.l   $f003b2.l        ; synthesized return PC
F00372  move.w  #$2000,-(a7)     ; ...and SR: a fabricated exception frame
F00376  jmp     (a2)             ; the handler ends in RTE, returning to $F003B2
```

Two structural points:

- **`w0` is a self-relative signed offset, not an address.** Read as absolute it produces
  plausible-looking garbage — `RESUME` appears to collide with `T0CRTCB` at `$F02894`. Read
  correctly, `RESUME` is `$F02CB4`. **77/77 handlers land inside the kernel region** and every
  one sampled decodes as a valid instruction, which is what makes the reading safe.
- **The dispatcher fabricates an exception frame and `jmp`s.** Handlers therefore end in
  `rte`, not `rts`, and their return address is synthesized at dispatch time. This is the same
  family as the `move.l (a0),-(a7)` / `rts` idiom and a second reason linear control-flow
  analysis loses the thread in this kernel.

### `$4C` is inside the firmware's own table

The range check is `bgt`, not `bge`, so `d0 = $130` passes and directive `$4C` = 76 is the
**last valid entry**, not an out-of-range one. This file previously said `$4C` was "beyond
that table" — true of Motorola's published `TR1.EQ` list, but **not** of the table this
firmware actually dispatches through. Corroboration: `$4C`'s handler at `$F02216` opens
`movea.l $c66.w,a1`, and `$0C66` is the documented `!VCT` directory slot, exactly matching
the connect-interrupt-vector behaviour already traced to `$F0226A`.

### The directive names are confirmed by the code, not by the vendor list

The handlers verify each other in pairs:

| directive | handler | first instruction |
|---|---|---|
| `$11` SUSPND | `$F02CAC` | `bset.b #$9,$2c(a6)` |
| `$12` RESUME | `$F02CB4` | `bclr.b #$9,$2c(a0)` |
| `$13` WAIT | `$F02C3E` | `bset.b #$e,$2c(a6)` |
| `$16` T0WAKEUP (TRAP #0) | `$F02C6E` | `bclr.b #$e,$2c(a0)` |

**SUSPND/RESUME set and clear the same bit; WAIT/WAKEUP set and clear the same bit.** Two
independent inverse pairs, one of them spanning both trap tables. That confirms the vendor
directive names from the firmware's own behaviour rather than by matching numbers to a list —
the check that failed for three days because the source numbers directives in decimal.

It also identifies the field: **`TCB+$2C` is the task state word**, bit 9 = suspended,
bit 14 = waiting. The full handler table for all 77 directives is reproducible from
`$F003D8` with the offset arithmetic above.

## RETRACTION: the three-BIM model derails the boot (2026-07-30)

`cards/02_VBUS_XLTR.JPG` shows three `MC68153P` at positions F/G, H/J, K/L, and the card list
says "V-BUS XLTR 3 BIMS". That hardware fact is not in doubt. **The model of it was wrong, and
the measurement that appeared to confirm it was reading a crashed machine.**

Presenting three BIMs (bit 4 of `STATUS_IRQ` set at reset) gives, at 150 M cycles:

| config | `FPS3K_BIMS=2` | `FPS3K_BIMS=3` |
|---|---|---|
| `XPIRQ=5 DMA10AA=2` | final PC `$F00FD0` (RTOS idle) | final PC **`$011758`** |
| `XPIRQ=5,6 MBOX=20010000` | final PC `$F0A5AE` | final PC **`$011758`** |

`$011758` is **RAM**. In the three-BIM runs the machine leaves ROM entirely, vector `$128`
reads `$00000128` instead of `$F05DD6`, and TCBIO1I's ISR executes **0** times against 219
with two BIMs.

### The check that "confirmed" three BIMs was measuring a corpse

This file previously recorded: *"the three-BIM correction also removed a spurious interrupt
storm (730 → 1 vector writes)"*. That comparison was invalid. `FPS3K_VECWATCH=post` counts
vector writes **after boot completes**, and with three BIMs boot never completes — so the
counter reports 0 or 1 because nothing is ever counted, not because nothing is wrong.

**Storm-versus-clean was really crash-versus-run.** The harness check asserting
`vecwrites < 10` under three BIMs passed for precisely the wrong reason.

The general lesson, and it has now bitten this project repeatedly in different costumes: **a
metric that a crash drives to zero cannot distinguish health from death.** Any such check must
first assert the machine is alive. The replacement checks assert final PC is in ROM before
believing any counter derived from that run.

### Status

Bit 4 of `STATUS_IRQ` is **not** simply "a third BIM is fitted". That reading was inferred
from phase `$1600`'s 24-versus-16-register walk alone, and it cannot be the whole story if
setting it derails the boot. The model therefore defaults to **two** BIMs — the configuration
that demonstrably boots — with `FPS3K_BIMS=3` retained for whoever investigates the storm.

This is an **open modelling defect**, not a settled question: the real card carries three.

## The $F70030 routine, decoded (2026-07-30)

The kernel's single absolute device access sits in a handler at **`$F00A1C`**, which the 80.3%
kernel listing still leaves undecoded — nothing reaches it statically, so it has to be decoded
by hand:

```
F00A1C  tst.l    $c78.w           ; re-entrancy guard / saved-SP slot
F00A20  bne.b    $f00a32          ; already nested -> skip the context save
F00A22  ori.w    #$7000,sr        ; mask to level 7
F00A26  movem.l  d0-d7/a0-a6,-(a7)
F00A2A  move.l   a7,$c78.w        ; stash SP
F00A2E  move.w   $3c(a7),sr
F00A32  movea.l  $c78.w,a7
F00A36  ori.w    #$700,sr
F00A3A  move.b   $f70030.l,d0
F00A40  ori.b    #$20,d0          ; set bit 5
F00A44  move.b   d0,$f70030.l
F00A4E  movem.l  (a7)+,d0-d7/a0-a7 ; restores a7 too -- full context
F00A52  clr.l    $c78.w
F00A56  rte
```

It is an exception handler with a nesting guard, full register save/restore including `a7`,
and interrupts masked around the register touch. **No branch, call or pointer anywhere in the
64 KB reaches it**, so it is installed at runtime through the vector table or not at all.

**Dormancy confirmed by measurement, not inference:** after a full boot `$C78` reads `$00000000`.
That slot is written on entry and cleared on exit, so a zero means the handler never ran —
independent of the PC-trace argument used before.

### A false-negative that did not materialise

A scan of the decoded kernel for memory operands outside ROM and SBC RAM returns **zero**
device addresses. That is exactly the shape of result this project has learned to distrust,
because the firmware addresses devices through base registers and an absolute scan cannot see
that form. Two nearby sites do access through pointers — `movea.l $c3a.w,a1` then writes to
`$4(a1)`, and `movea.l $e48.w,a0` then `andi.w #$ffdf,(a0)`.

Checked rather than assumed: after a boot, **`$C3A` = `$00000800` and `$E48` = `$00000000`**.
`$800` is the register-save area the kernel itself writes with `movem.l d0-d7/a0-a7,$808.w`, so
these are RAM accesses, not disguised device I/O. The "kernel touches exactly one device
address" claim survives the stronger test.

One loose end: writing `$15`, `$35`, `$2E`, `$3E` in succession to the *same* address
(`$F009FC`-`$F00A0E`) is command-register behaviour, not RAM behaviour — four writes to RAM
would leave only the last. It is unreachable in every configuration run so far (`$C5C` never
reaches its `$64` threshold), so nothing is measurable here yet.

### Control: the 80.3% is the tables, not a better decoder

Pointing the same tool at the application region (`$F04488`-`$F0FFFF`) with the same three seed
tiers gives **47.5%**, against `disasm.py`'s **49.6%**. It is slightly *worse*.

| region | entry-point seeds | call seeds | pointer seeds | coverage |
|---|---|---|---|---|
| kernel `$F00000`-`$F04487` | **125** | 71 | 51 | **80.3%** |
| application `$F04488`-`$F0FFFF` | **1** | 137 | 127 | 47.5% |

The difference is entirely the entry-point tier: the kernel's TRAP #0 and TRAP #1 tables hand
over 125 routine starts, and the application has no equivalent this tool knows about.

So the honest reading is that **the kernel was never harder to disassemble than the
application — its entry points were simply never read out of its own dispatch tables.** Nothing
here suggests a generally better algorithm, and the application's remaining ~50% will not fall
to one. It needs its own entry-point source: the five 42-entry `PanelStatusDispatch` tables,
the 16-entry chassis-op table at `$F05102`, the TDTI table at `$F0A600`, and the 9-entry
exception table at `$F0A23A` are the obvious candidates, most of which `disasm.py` already
scans in some form.

Run the control with `FPS3K_DIS_START` / `FPS3K_DIS_END` / `FPS3K_DIS_OUT`.

## What "49.6% coverage" actually means (2026-07-30)

This project has repeatedly described the application region as about half decoded, with the
implication that the other half is un-understood code. Checking that reading:

| artifact | code bytes | data bytes |
|---|---|---|
| `fps3k.asm` (the file readers are pointed at) | 22,980 | 25,012 |
| `fps3k_custom.asm` (current `disasm.py` output) | 23,962 | 24,018 |

**The region is roughly half data by construction**, so 49.6% coverage is not a 50% gap. It is
close to the share of the region that is code at all.

### An apparent over-decode that was nothing of the sort

`disasm.py` decodes 23,818 bytes as code while `code_map.json` classifies 22,588 as code —
**105.4%**, which looks like a disassembler decoding data as instructions. It is not, for two
reasons, and both were mistakes I made before checking:

1. **The comparison is circular.** `code_map.json` is built *from* `fps3k.asm`, which descends
   from `disasm.py`. It cannot independently validate that disassembler's coverage; it can only
   measure disagreement between two artifacts in the same lineage.
2. **The disagreement is entirely jump tables.** The 982 differing bytes fall in 96 runs, and
   **77% start with a `jmp`/`rts`/`nop` opcode**; every 2-byte run is `$4E75` = `rts`, the
   slot-0 no-op entries. The largest runs are exactly the dispatch tables — `$F05106`-`$F05141`
   (the 16-entry chassis-op table) and five 44-byte runs at `$F05BA6`, `$F065E6`, `$F06FFE`,
   `$F079FE`, `$F083FE` (the `PanelStatusDispatch` copies).

A `jmp d16(pc)` table is **simultaneously code and a table**. One file renders it as
instructions, the other as `DC.W`. Neither is wrong and neither is stale — so the "982 bytes
behind" reading, which is where this started, is also withdrawn.

**Net:** there is no drift-attributable undecoded-code gap in the application region, and the
`105.4%` anomaly dissolves. What remains genuinely unknown is how much of the ~24 KB classified
as data is truly data — and no artifact in this lineage can answer that, because they all
inherit the same decisions.

## Whole-ROM accounting: 88.4% of the content is decoded, not 54% (2026-07-30)

Every coverage figure this project has quoted divides by a denominator that is **46.9% blank
ROM**. Verified directly from the image, not from any disassembly artifact:
`$F0A825`-`$F0FFFD` is **22,489 bytes with not one nonzero byte** — the free space the monitor
is patched into.

| range | bytes | decoded | |
|---|---:|---:|---|
| RMS68K kernel `$F00000`-`$F04487` | 17,544 | 14,084 | **80.3%** |
| application `$F04488`-`$F0A824` | 25,501 | 23,962 | **94.0%** |
| blank tail `$F0A825`-`$F0FFFD` | 22,489 | — | all zero |
| ROM checksum word `$F0FFFE` | 2 | — | |

**ROM content = 43,047 bytes, of which 38,046 are decoded = 88.4%.**

Against the full 65,536 the same work reads as 58.1%, and that is the number this project has
been quoting — most visibly "54% of INSTRUCTION bytes" and "the application region is 49.6%
decoded". Those figures are arithmetically correct and substantively misleading: they count
22 KB of deliberately empty ROM as un-understood firmware.

Two consequences worth stating plainly:

- **The application region is ~94% decoded, not ~50%.** Its remaining data is 690 bytes of
  ASCII and 637 bytes of other non-zero content — roughly 1.3 KB, not 24 KB. The "half the
  application is unknown" framing was an artifact of the denominator throughout.
- **The kernel is now the least-covered region**, at 80.3%, having been at 0% this morning.
  That inverts the standing assumption that the kernel was the well-understood stock part and
  the FPS application was the frontier.

Independent classification of the bytes `fps3k.asm` renders as `DC.W`, done without the
disassembler: **94.7% zero, 2.8% printable ASCII, 2.5% other**. So the "data" in this image is
overwhelmingly emptiness, and the genuinely unexplained non-code content across the whole
application region is on the order of one kilobyte.

## The TDTI table carries authoritative task bounds, and they settle the $26E question

The `!TCB` definition entries at `$F0A600` are `$60` bytes each. Field map, from diffing the six:

| offset | content |
|---|---|
| `+00` | `!TCB` marker |
| `+04` | 4-char task name |
| `+1C` | **task entry point** (longword) |
| `+20`, `+22` | **high words of the task's code region**, start and end |
| `+40` | segment name `PROG` |

| task | entry | region |
|---|---|---|
| RDHC | `$F046F0` | `$F04600`-`$F05CFF` |
| IO1I | `$F05D36` | `$F05D00`-`$F05EFF` |
| XP4I | `$F05F4A` | `$F05F00`-`$F068FF` |
| XP3I | `$F0694A` | `$F06900`-`$F072FF` |
| XP2I | `$F0734A` | `$F07300`-`$F07CFF` |
| XP1I | `$F07D4A` | `$F07D00`-`$F086FF` |

**The six regions tile contiguously with no gaps or overlaps, and every entry point lies inside
its own region.** Six independent consistency checks passing at once is what makes the field
identification safe.

### This resolves the `$26E` attribution, and the code was right

This file has carried an open item: *"`0x26E` at `$F05F92` sits in code our enclosing-function
heuristic attributes to TCBXP4I. Either the CH1 label is wrong or the function attribution is.
Unresolved — do not rely on the channel numbers in this block."*

`$F05F92` falls inside `$F05F00`-`$F068FF` — **XP4I**, by the ROM's own table. So the
*attribution was correct* and the *`CH1` label was wrong*, which is exactly what the later
finding concluded independently when it showed `$26D`-`$271` index the failed RTOS directive
rather than a channel. Two routes, same answer.

It also bounds the pre-task code precisely: the application region starts at `$F04488` but
RDHC's region starts at `$F04600`, so **`$F04488`-`$F045FF` is RTOS-init code owned by no
task** — 376 bytes, matching the separately-noted init block.

### `HXP1`-`HXP4` do not exist in the ROM; RDHC computes them

```
F053B6  move.l  #$48585030,d1    ; 'HXP0'
F053BC  add.b   d4,d1            ; + channel number -> 'HXP1'..'HXP4'
F053BE  jsr     $f05652
```

The same construction appears at `$F05476`. Only the literal `HXP0` is in the image; the four
real queue names are built at runtime by adding the channel to the ASCII digit.

Consequence for a documented claim: this file describes `$F05652` as **"RDHC's ASQ post to
`HXP1`"**. It is not `HXP1`-specific — it is the generic per-channel poster, and which queue it
addresses depends on `d4`. The `AXP*` names are *not* computed this way; each task declares its
own literally.

Segment names also recovered from the string scan: **`PROG`** in every TDTI entry, **`STCK`**
declared once per task (the stack segment), and **`UPGM`** once at `$F046D4` in RDHC's region.

## 62 of the 77 directives now have vendor names, and 17 are stubbed out

`~/src/claude/versados/SR10/U9995/TR1.EQ` names directives 1-75. Mapping them onto the 77-entry
table at `$F003D8` names **62** handlers and cross-checks the offset arithmetic independently:
`$0B CRTCB` → `$F0289E` and `$0D START` → `$F02A34` are the values computed from the table
before the vendor list was consulted.

**`$F003D0` is the unimplemented-directive stub** — `move.w #$1,$102(a6)` / `rte`, i.e. return
status 1. Seventeen of the 77 slots route there:

`$00`, `$0A GTTASKID`, `$0C GTTASKNM`, `$26 GTEVNT`, `$27`, `$28`, `$2F`, `$30`, `$31`, `$32`,
`$37`, `$38`, `$39`, `$3F`, `$46`, `$47`, `$4B FLUSHC`

Thirteen of those are numbers TR1.EQ does not name either, so they are simply reserved. The
substantive absences are **`GTTASKID`, `GTTASKNM`, `GTEVNT` and `FLUSHC`** — this kernel build
does not implement them.

No contradiction with the existing note that the ASQ directives "appear nowhere in this
firmware": `GTASQ` 31, `RDEVNT` 34, `QEVNT` 35 and `WTEVNT` 36 all have **real handlers** here.
That note is about call sites in the FPS application, not about kernel support, and both remain
true.

### `$3B` is an undocumented directive behind a magic key

Two slots are unnamed by TR1.EQ yet have real handlers: `$4C` and `$3B`.

`$4C` is the connect-interrupt-vector directive already traced — `$F02216` opens
`movea.l $c66.w,a1`, the `!VCT` slot. Its absence from TR1.EQ simply dates that file earlier
than this kernel.

`$3B` (59) is more interesting:

```
F039C2  move.w   #$1,$102(a6)      ; default status = error
F039C8  move.l   $120(a6),d0
F039CC  cmpi.l   #$4baa7bfb,d0     ; magic key
F039D2  bne.b    $f03a12           ; wrong key -> out
```

The caller must present **`$4BAA7BFB`** at `+$120` of its parameter block. Measured: that
constant occurs **exactly once in the 64 KB**, in the comparison itself, and **no site anywhere
loads `$3B` into `d0`**. So the ROM neither invokes this directive nor contains the key — it is
a kernel capability reachable only by host-side software or a Motorola tool that knows the
value.

Emulation consequence: none today, and that is the point — a chassis or host model can be
written without it, but a *host* implementation that appears to need a privileged RMS68K call
has exactly one gate to satisfy, and its constant is now known.

## The harness contained three checks that could not fail (2026-07-30)

While adding checks for the kernel findings I wrote one with a trailing `or True`, caught it
before committing, and then scanned for the pattern. **Three more were already there**, softened
at some earlier point when the assertion did not match and never repaired:

| check | what it claimed | truth |
|---|---|---|
| op `$6` read path opcode | one of `$33F9`/`$33D0`/`$33E8`/`$31F9` | **`$33D1`** — none of them |
| `$105E` gate at `$F05FF0`/`$F05FF6` | a `$0C79`/`$B079` compare | **true all along**; the `or True` was never needed |
| result-word feed at `$F04E14` | `$23F9 0000 0E70` | **`$22B9 0000 0E70`** — `movea.l`, not `move.l` |

Two of the three were asserting something **false** and reporting a pass. All three are now real
assertions against the measured bytes.

This matters more than three checks. The harness is this project's tripwire — it is what caught
the three-BIM regression — and a check that cannot fail is worse than no check, because it
occupies a slot in the pass count and reads as coverage. The pass totals quoted in this file
(`542/542`, `658/668`, `670/670`) were each inflated by three.

Guard for the future: `grep -n "or True" tools/verify_findings.py` should return only comments.

## Static ∪ runtime device map: 68 addresses, and each method's blind spot (2026-07-30)

`refs_extracted/device_communications_map.md` was built from runtime access logs over four
driving configurations. Sweeping the disassembly *statically* with base-register tracking — the
form absolute scans miss — gives an independent list. Combining them:

| | count |
|---|---|
| static (application + kernel listings) | 49 |
| runtime (four configurations) | 67 |
| **union** | **68** |

**Runtime-only: 19.** `$F70000`, `$F70001`, `$F70005`-`$F7000F` (the MC6840 `movep` registers),
`$F70010`, `$F70018`, the four channel-window `+$00` registers `$FF0040`/`$60`/`$80`/`$A0`, and
`$FF0212`/`$FF0214`/`$FF0216`, `$FF0240`, `$FF0248`. These are reached through base registers
whose value the static pass cannot resolve at that point — exactly the limitation this project
documented when it found that `$FF0204`, the hottest register on the board, has *zero*
absolute-long references.

**Static-only: 1 — `$FF0004`.** It is referenced in the disassembly (the polled ready flag at
`$F04B22`/`$F05A22`) but appears in no runtime log, so **none of the four driving configurations
ever executes that path.** That is a concrete, addressable gap in what the emulator exercises,
not a modelling error.

**Kernel static sweep: zero device addresses**, agreeing with the absolute-address result by a
second method. Caveat kept explicit: the one real kernel access, `$F70030` at `$F00A3A`, sits in
a routine nothing reaches statically, so it is absent from the kernel *listing* and therefore
invisible to a listing-based sweep. It is in the runtime map's `$F70030` entry via the emulator.

### A bug in the tool built to avoid exactly this

`tools/refs.py` matched `[0-9a-f]{1,6}`, so a 32-bit immediate such as `#$21544342` (`!TCB`)
was captured as `$215443` and treated as an address. The first kernel sweep therefore reported
**15 "device addresses"** that were all truncated constants — `$4BAA7B` (the magic key),
`$455845` (`EXE`), `$215443`, and so on.

The tool exists because "six times in one session I hand-decoded 68000 opcodes to find
references and six times the decoder was too narrow". It then carried a seventh instance of the
same class of error in its own regex. Fixed to capture the full hex run and skip anything
introduced by `#`; re-validated against the known positive `$FF0048` at `$F07EF6`, which still
resolves through its `$48(a5)` base form.

## Closing the $FF0004 gap, and what it exposes about the ready flag

The static∪runtime comparison left exactly one static-only address: `$FF0004`, the polled ready
flag at `$F04B22`. It is now reached — the runtime map simply lacked the configuration:

```
FPS3K_XPIRQ=6 FPS3K_RESP=0x00 FPS3K_SEQ="01:0000,41:0001,02:0008,42:0000,00:0028"
```

**`$F04B22` executes 1,365,711 times** in that run. So the union map is 68 addresses with no
static-only residue: every device address in the disassembly is now also reachable at runtime.

### The ready flag is gated on a hook, not on chassis state

Those 1.37 M iterations are a **spin**. `$FF0004` bit 0 is asserted only when `FPS3K_SREC` is
set (`versabus.c:560`), so with no S-record source configured the flag never goes ready and the
firmware polls forever — final PC `$F04B26`.

| config | `$F04B22` | `$FF0008` reads | final PC |
|---|---:|---:|---|
| SEQ + XPIRQ, no `SREC` | 1,365,711 | 0 | `$F04B26` (spinning) |
| SEQ + XPIRQ + `SREC` | 2 | 37 | `$F056B8` |

With a source configured the poll completes in **two** iterations and 37 words are read from the
bulk port. **That is a modelling weakness rather than a bug**: a real chassis asserts ready from
its own buffer state, not from whether the operator configured a file. Any experiment sensitive
to *when* ready rises is measuring the hook, not the hardware.

The 37 reads go through the **S-record front end** (`$F04B8A` compares against `$5330` = `"S0"`),
not the raw block-transfer loop — `$F04AF8` executes zero times. Nothing reaches the staging
buffer (`$10010` stays zero; the only nonzero bytes above `$10000` are the six at `$1DF00`, which
are RTOS data), and the run ends at `$F056B8` — the already-documented `PanelSendAndWait` spin.
So this configuration advances past the ready gate and then meets a blocker that is already
understood, rather than revealing a new one.

## Op $3 is bidirectional: the SBC's WRITE path into chassis memory (2026-07-30)

The chassis-op table in this file lists `$3` as **"read chassis memory via the `$400000`
window"**. That is only half of it. `$F04D52` tests **bit 5 of `$E87`** — the documented
direction bit — and branches to a second, symmetric implementation at `$F04DC0`:

```
F04DC0  btst.b  #$6,$e87          ; half-select
F04DCA  move.w  $204(a0),$e70     ; bit 6 set -> data HIGH half from CHANNEL_SELECT
F04DD6  move.w  $204(a0),$e72     ; bit 6 clear -> data LOW half
F04DE6  lsr.l   #$14,d1           ; page = addr >> 20
F04DE8  move.w  d1,$210(a0)       ; -> XLTR_MODE2 page register
F04DF2  andi.l  #$fffff,d1
F04DF8  lsl.l   #$2,d1            ; offset = (addr & $FFFFF) << 2
F04E0A  move.l  $e70,(a1,d1.l)    ; STORE 32 bits into the window
F04E26  btst.b  #$4,$e87          ; auto-increment flag
F04E30  addq.l  #$1,$e58          ; advance the transfer address
```

So the full command-byte layout already documented — bits 0-3 operation, bit 4 auto-increment,
bit 5 direction, bit 6 half-select — is realised *within a single operation*: `$23` reads
chassis memory and **`$03` writes it**, both with optional auto-increment and both assembling or
splitting a 32-bit word through `$FF0204` in two 16-bit halves.

This matters for the upload path. It means the SBC is **not** limited to staging microcode in
its own RAM and waiting to be read: it has a direct 32-bit write port into the chassis address
space, paged by `$FF0210`, with hardware-style auto-increment for streaming. It also explains
why `$FF0204` is the busiest register on the board — it is the data conduit, not merely a
channel selector.

Alongside it, **op `$B` is the handoff**: `$F05002` computes `$10000 + $10 = $10010` literally
and returns it in `$E74`, half-selected by the same bit 6. The SBC is telling the chassis where
the staging buffer starts.

**Status: static decode, not runtime-confirmed.** Driving op `$3` through `FPS3K_SEQ` failed in
every arrangement tried — single-op, padded, and with the address and count pre-set. `$F04D4E`
executes zero times in all of them, and the only `$400000` traffic in those runs comes from the
self-test at `$F096AC`/`$F09798`/`$F09AF6`. That is consistent with the already-recorded
limitation that a sequence hands over only a handful of codes and stops; it is a gap in the
driving hook, not evidence against the decode. The read side of the *same handler* is confirmed,
and the two paths differ only in the direction of one `move.l`.

## Why FPS3K_SEQ "silently drops its tail": delivery is acknowledgement-driven

This file records that a sequence delivers only ~4-6 codes, that pacing is not the cause (gaps
from 20 M down to 200 K cycles and a 3× longer run give identical results), and that the
workaround is one operation per run, unioned. The mechanism is now measured.

`panel_resp_tick` advances the script **only when the SBC acknowledges the previous response**
by setting `MODE0_RESP_ACK` (bit 10). So the delivery rate is not a clock — it is a handshake,
and **it stops dead whenever the SBC enters a spin**.

Measured with `FPS3K_XPIRQ=6 FPS3K_RESP=0x00` and the five-code staging sequence:

| | ISR `$F04930` fires | ops dispatched |
|---|---:|---|
| ready flag never asserts | **2** | `$1`, `$0` |
| ready flag asserts (`FPS3K_SREC` set) | **3** | `$1`, `$0` ×2 |

In the first case op `$0` arms the transfer and the SBC spins 1,365,711 times on `$FF0004`,
never acknowledging again, so codes 3-5 are never handed over. In the second the poll clears and
one more exchange happens before the run blocks at `$F056B8`, the `PanelSendAndWait` spin.

**This firmware is full of such blockers** — the ready poll, `PanelSendAndWait`, and the eight
panel-command issuers that end in `bra .`. Each one halts sequence delivery where it stands.

Two consequences:

- **No amount of pacing will deliver a longer script**, which is exactly what the earlier gap
  sweep found without being able to explain it. The observation and the mechanism now agree.
- The way to drive a deeper sequence is to **clear the blocker the SBC is sitting in**, not to
  lengthen the script or space it differently. Asserting the ready flag bought exactly one more
  exchange, which is the smallest possible confirmation of that principle.

This is also why op `$3`'s write path could not be reached: every arrangement tried put a
blocker between the start of the run and the code that would have dispatched it.

### Fix: the ready flag now tracks whether the chassis has data, not which hook is set

`$FF0004` bit 0 tested `getenv("FPS3K_SREC")` only. Two consequences, both now removed:

- **`FPS3K_DATAIN` could never drive the polled path.** It is the *other* bulk source — the
  incrementing pattern at `$FF0008` — and with the ready flag ignoring it the port stayed
  permanently not-ready. The documented `FPS3K_DATAIN` result must therefore have come through a
  path that does not poll `$FF0004`.
- **With no source configured the firmware span forever**, and that spin throttled
  `FPS3K_SEQ` delivery, because the script only advances on acknowledgement.

Now: `DATAIN` → ready; `SREC` → ready until exhausted; neither → not ready, which is what a
chassis with an empty buffer would say.

Measured, `FPS3K_XPIRQ=6 FPS3K_RESP=0x00 FPS3K_DATAIN=1` plus the staging sequence:

| | before | after |
|---|---:|---:|
| `$F04B22` iterations | 1,365,711 | **1** |
| final PC | `$F04B26` (spinning) | `$F04C32` |

The spin is gone. `$F04AF8` still does not run and the staging buffer stays empty: with an
incrementing pattern the S-record front end at `$F04B8A` is comparing against `$5330` = `"S0"`
and correctly rejecting what it is given. That is the firmware behaving properly, not a
remaining defect — feeding `DATAIN` to an S-record parser was never going to parse.

## The scripted chassis advances one blocker at a time; there are three in series

Delivery is acknowledgement-driven, so the script advances only as far as the next unbroken
spin. Chasing op `$3` through the sequence mechanism mapped the chain:

| # | blocker | mechanism | status |
|---|---|---|---|
| 1 | `$F04B22` ready poll | `$FF0004` bit 0 never asserted | **fixed** — flag now tracks the source |
| 2 | `$F04C28` drain loop | `cmpi.w #$0,$0(a1)` on `$FF0000`; exits only on end-of-stream | needs a **finite** source |
| 3 | `$F056B8` `PanelSendAndWait` | level-6 responder cannot preempt | **open**, long documented |

Blocker 2 is not a defect on either side. The loop drains the port until the chassis clears
`$FF0000` to say "nothing more" — the same end-of-stream convention already recorded for the
`$F05218` drain. With `FPS3K_DATAIN` the source is *endless*, so the firmware is correct to
drain forever: measured 1,040,513 iterations of the four-instruction loop. **`FPS3K_DATAIN` is
therefore unusable for driving any path that ends in a drain**, and `FPS3K_SREC` — which sets
`srec_exhausted` and returns 0 — is the source to use.

With a finite source the run clears blockers 1 and 2 and stops at 3:

```
FPS3K_XPIRQ=6 FPS3K_RESP=0x00 FPS3K_SREC=<file> FPS3K_SEQ="01:...,03:BEEF,..."
  -> ISR fires 3x, ops $0 x2 / $1 x1 / $F x2, final PC $F056B8
```

Op `$3` is still never dispatched, so **its write path remains statically decoded and unmeasured**.
The reason is now precise rather than mysterious: delivery stalls at blocker 3 before the code
carrying op `$3` is handed over. Clearing `$F056B8` is the single thing standing between this
project and a measured confirmation of the SBC's write port into chassis memory.

One further observation from these runs: with `FPS3K_RESP` and `FPS3K_SEQ` both set, the **first**
code delivered is `FPS3K_RESP`'s, not the script's. A run with a sequence containing no op `$0`
still dispatched op `$0` once. That is consistent with the warning already in `versabus.c` about
the two hooks interacting, and it means a sequence's first entry is effectively the *second*
code the SBC sees.

## Blocker 3 measured: the spin runs at IPL 6 and its rescuer is level 6

`$F056B8` is `bra.b` to itself — one of the eight panel-issuer spins. Escaping it requires the
panel-status responder `$F04930` to rewrite the saved PC. Three measurements, in the
configuration that clears blockers 1 and 2:

- **BIM0 ch0 is enabled.** The last write to `$FF0230` is `$5E` — level 6, IRE **set**. The
  rescuer is armed, not masked.
- **The `$4F` masking write never runs.** `$F056BA`, `PanelSendAndWait`'s entry and one of the
  five `move.w #$4f,(a3)` sites, executes **zero** times here. So the "firmware suppresses its
  own rescue interrupt" explanation does not apply to this spin.
- **The CPU is at `SR=$2600`.** Supervisor, **IPL = 6**.

On a 68000 an interrupt is taken only when its level is **greater** than the mask (level 7
excepted). A level-6 request against an IPL-6 mask is **never** delivered. The rescuer and the
spin sit at exactly the same level, so `$F04930` cannot preempt no matter how often the BIM is
raised — measured, it fires 3 times early and then never again while the spin runs.

**This refines the existing account.** This file already recorded that BIM0 ch0 at level 6
cannot preempt a *channel ISR* at level 7. The new measurement is that it cannot preempt this
spin either, because **the spin is itself running in interrupt context at IPL 6** — the chassis-op
handlers are reached from `$F04930` and end at the ISR exit stub `$F050F8`, so an operation that
issues a panel command spins inside the very ISR whose re-entry would release it.

The deadlock is therefore structural rather than a level-ordering accident: **the ISR waits for
an event only its own interrupt can deliver.** Escape needs one of

- the chassis response arriving at **level 7**, or
- the issuer lowering its mask before spinning — no SR-modifying instruction exists in that path, or
- the response being delivered by a mechanism that is not this BIM.

That third option is the one worth testing next, and it is the same shape as the conclusion
already reached for TCBIO1I: the `$281` arm is not the normal path. Here too, the economical
reading is that a real chassis does not answer a panel command through the level-6 responder
while the SBC sits at IPL 6.

## CONFIRMED: the SBC's 32-bit write port into chassis memory executes

Op `$3`'s write path was decoded statically and flagged as unmeasured. It is now measured.

Testing the level-7 hypothesis from the blocker-3 analysis with an experimental override
(`FPS3K_BIM0LVL=7`, raising BIM0 ch0 above the IPL-6 spin):

| | level 6 (as the firmware programs it) | level 7 (probe) |
|---|---:|---:|
| `$F04930` ISR fires | 3 | **44** |
| chassis ops dispatched | 5 | **219** |
| spin released | no | **yes** |

With `FPS3K_RESP=0x03` so every response carries op `$3`:

```
F04D4E  op $3 handler        219
F04DC0  write branch          219      (bit 5 clear)
F04E0A  move.l $e70,(a1,d1.l) 219      <- the store
F04D74  read branch             0
[CHASSIS-MEM] WR 400000=00 400001=00 400002=29 400003=03  @F04E0A
```

**Four byte-writes at `$400000`-`$400003` from a single instruction — a 32-bit longword into the
chassis window.** The decode was right: op `$3` is bidirectional, bit 5 selects direction, and
the write direction is a full-width paged store.

### What this does and does not establish

**Established:** the firmware's own instructions perform a 32-bit write into the `$400000`
window. Nothing about the handler was altered — the probe changes only *when the ISR may
preempt*, not what the handler does once entered.

**Not established:** that a real board delivers responses at level 7. The firmware writes `$5E`
to `$FF0230` itself, which is level 6, and `FPS3K_BIM0LVL=7` deliberately contradicts that. So
this confirms the *code path* while leaving the *delivery level* an open hardware question. The
override is kept as a probe and is not the default.

It does, however, make the level-7 reading considerably more attractive: at level 6 the machine
deadlocks in its own ISR, and at level 7 it runs 219 chassis operations and writes to system
common memory. One of those is what the hardware did for a decade.

## The `bra .` deadlock is circular, not a level-ordering problem (2026-07-30)

Raising the responder to level 7 releases the first spin but does not solve the class. With
`FPS3K_BIM0LVL=7` and a 16-op script:

| | ops dispatched in one run | final PC | SR |
|---|---:|---|---|
| level 6 | 3 of 16 (`$0 $4 $F`) | `$F056B8` | `$2600` (IPL 6) |
| level 7 | **7 of 16** (`$0`-`$5`, `$F`) | `$F056B8` | `$2700` (IPL 7) |

Delivery more than doubles and reaches op `$5` in order — a practical improvement over the
"one operation per run" workaround this file recommends. But it then deadlocks again, **one
level higher**, and the reason is not interrupt priority.

**Musashi models level 7 correctly.** `m68k_set_irq(7)` sets `nmi_pending` on a transition from
below 7 to 7, which is genuine edge-triggered non-maskable behaviour; `m68ki_check_interrupts`
takes `nmi_pending` unconditionally. So an IPL-7 mask does not block a *fresh* level-7 edge.

The blocker is that there is no fresh edge. The BIM request is **level-held**: `bim_assert` sets
it and only `versabus_bim_clear(0,0)` — reached from `panel_resp_tick` **when the SBC
acknowledges** — lowers it. A spinning SBC never acknowledges, so the line never drops, so no
new edge is generated, so the NMI path is never armed again.

**The escape requires an acknowledgement that only the escaped code could give.** That is
circular at every interrupt level, which is why raising the level moved the deadlock rather than
removing it.

### What this predicts about the hardware

A real chassis cannot be waiting for the SBC to acknowledge before re-asserting, or the machine
could never have worked. It must **pulse a fresh interrupt per response** — assert, release,
assert — generating an edge each time regardless of what the SBC is doing. Our model's
ack-gated, level-held request is the divergence.

That is a concrete, testable change: make the scripted chassis release the BIM between responses
instead of holding it until acknowledged. If the `bra .` spins then unwind on their own, the
"self-programmed deadlock" recorded throughout this file was our handshake all along, not the
firmware's design.

### REFUTED: the pulse hypothesis. The limiter is the script, not the interrupt line

The previous section predicted that a real chassis must **pulse** a fresh interrupt per response,
and that our level-held, ack-gated request was what stalled the `bra .` spins. That was
implemented (release the BIM on an earlier tick than the assert, so the CPU observes the drop)
and **measured to change nothing**:

| | ops dispatched | `$F04930` fires | final |
|---|---:|---:|---|
| level 6 | 3/16 | 2 | `$F056B8` `SR=$2600` |
| level 6 + pulse | 3/16 | 2 | `$F056B8` `SR=$2600` |
| level 7 | 7/16 | **224** | `$F056B8` `SR=$2700` |
| level 7 + pulse | 7/16 | **224** | `$F056B8` `SR=$2700` |

Byte-identical outcomes. The hook was reverted rather than left in as an unused option.

**The 224 figure is what refutes it.** The ISR was already re-entering 224 times at level 7, so
edges were never scarce — the interrupt line was not the constraint, and the "no fresh edge"
reasoning, though correct about the model's mechanics, was not describing the actual limiter.

What limits delivery is the **script advance**, which is a separate ack gate:
`panel_resp_tick` advances `FPS3K_SEQ` only when it observes `MODE0_RESP_ACK` set. And the panel
issuer **clears that very bit** at `$F056AC` (`bclr #$a,d1` on MODE0) immediately before it
spins. So the ISR sets bit 10, the issuer clears it, and the script advances only if the tick
samples the window in between — 224 interrupt entries yield 7 script advances.

So there are two independent ack dependencies and I conflated them: one on the interrupt line
(real, but not binding, since the ISR re-enters freely) and one on the script pointer (binding).
The correct target is the script advance — for instance advancing on ISR entry rather than on an
observed bit that the firmware deliberately clears four instructions later.

### Two more refuted hypotheses, and a diagnostic that describes the wrong path

Having found that the interrupt line was not the limiter, I proposed the **script advance** was:
`panel_resp_tick` samples `MODE0_RESP_ACK` as a level, and the panel issuer clears that bit at
`$F056AC` four instructions before spinning, so the tick must catch a closing window.

Implemented as `FPS3K_ACKLATCH` — latch the acknowledge on the *write* that sets bit 10, which
the firmware's later clear cannot race. **Measured: no change at either level.**

| | ops | ISR fires |
|---|---:|---:|
| level 6 / +ACKLATCH | 3/16 / 3/16 | 2 / 2 |
| level 7 / +ACKLATCH | 7/16 / 7/16 | 224 / 224 |

Reverted. That is two consecutive hypotheses — pulse the line, then latch the ack — both
plausible, both derived from reading the mechanism, and both wrong.

Measuring instead of proposing a third gives the useful result:

```
arm=yes:                  0
response acknowledged:  219
```

**The `[PANEL] … arm=yes/no` diagnostic describes a path that is not delivering any codes.** It
reports on the CHANNEL_SELECT arm route, gated on MODE1 bit 12, which logs 33,204 `arm=no` lines
during the self-test beacon and never once arms. Actual delivery goes through the `FPS3K_XPIRQ`
stamp route added later, which that diagnostic does not describe at all.

So a reader watching the panel log to understand why codes stop being delivered is watching the
wrong mechanism entirely — the same defect this file already records for "arm=yes" overstating
its case, now in a sharper form: the message is not merely overstated, it is about a different
code path than the one under investigation.

**What is actually established:** 219 responses are acknowledged and 224 ISR entries occur, yet
only 7 distinct operations dispatch. Delivery is plentiful; something downstream of the ISR is
not re-latching new codes. That is the next thing to measure — and it should be measured, not
guessed at, given the last two attempts.

### Measured: the ISR spends 218 of its 224 entries re-latching the SBC's own stale MODE0

Watching `$E87` — the byte the dispatcher actually tests, not `$E86` — gives the command stream
the ISR sees, at `FPS3K_BIM0LVL=7` with a 16-entry script:

```
00 14 01 14 02 14 03 14 04 05 14 14 14 …      $14 x218, everything else x1
```

Three facts fall out, none of them guessable from the earlier aggregate counts:

1. **Every scripted code is delivered exactly once**, in order, `$00` through `$05`. The script
   does not skip or corrupt entries — it simply stops after six.
2. **`$14` is not a chassis code at all.** It is the SBC's *own* last write to MODE0 being read
   back by the ISR. Once the script stops advancing, nothing stamps a new value, so `$F04930`
   re-latches the stale register 218 times and dispatches on it — the ISR is processing its own
   echo.
3. `$14` decodes as op `$4` with bit 4 (auto-increment) set, which is why op `$4` appeared in
   the dispatched set. **It is unrelated to `$14 = D2_FIN` in the 42-entry
   `PanelStatusDispatch` table** — same number, different table, and conflating them would be
   easy.

This is what "delivery stops after a handful" looks like at single-code resolution, and it
confirms the circular-deadlock reading from the code side: the script needs an acknowledgement,
the spinning SBC cannot give one, and the interrupt keeps firing into a register nobody is
updating. The two failed fixes were both aimed at machinery that was working; the broken part is
that **nothing re-stamps MODE0 once the SBC stops acknowledging.**

That also makes the fix concrete for the first time: the chassis model must stamp a fresh code on
every raise, independent of acknowledgement — not pulse the line, and not latch the ack bit.

### CORRECTION: the repeated `$14` is our own default stamp, not the SBC's echo

The previous section concluded that the 218 repetitions of `$14` were the SBC's own stale MODE0
being read back by the ISR. **That is wrong.** Reading the raise path settles it:

```c
const char *e = getenv("FPS3K_RESP");
code = (uint8_t)(e ? strtoul(e, NULL, 0) : 0x14) & MODE0_RESP_MASK;
xltr.mode0 = (xltr.mode0 & ~MODE0_RESP_MASK) | code | MODE0_RESP_VALID;
```

**`$14` is the emulator's hard-coded default**, stamped fresh on every raise because that run
did not set `FPS3K_RESP`. The ISR was reading exactly what the chassis model presented — no echo,
no staleness. The observation (218 × `$14`, each script code once) was correct; the explanation
attached to it was not, and it was reached by inference from the trace rather than by reading the
twelve lines that produce the value.

Everything else in that section stands: the script delivers each code once and stops after six,
and the ISR's remaining entries dispatch on the default rather than on new instructions.

### `FPS3K_RESPSEQ` already is the "stamp a fresh code per raise" mechanism

The fix proposed there — stamp independent of acknowledgement — **already exists**. `FPS3K_RESPSEQ`
cycles a list of codes across successive raises, precisely because `FPS3K_RESP` "presents one
constant forever".

But it cannot be used as a blunt sweep. Cycling all sixteen operations:

```
FPS3K_RESPSEQ=0x00,0x01,…,0x0F   ->  final PC $2602700, SR=$2708, only 2/16 ops dispatched
```

`$2602700` is outside ROM and RAM — the machine is destroyed, not stalled. The reason is that
**these operations take parameters**: op `$6` writes SBC RAM at the address in `$E58`, and
without a preceding op `$1` to set it that is a write to arbitrary low memory, including the
vector table. Op `$E` clears busy, op `$8` resets a channel.

So the operations must be driven as *(code, argument)* pairs with their parameters established
first — which is exactly what `FPS3K_SEQ`'s `code:chsel` form provides, and why the two hooks
exist separately. The practical driving recipe remains `FPS3K_SEQ` for parameterised sequences,
with `FPS3K_RESPSEQ` reserved for codes that need no setup.

## CORRECTION: the self-test installs THREE bus-error handlers, for different phases

Earlier today this file recorded that the static vector installs "explain a phase already
documented here: `$600` can only survive provoking a BERR because `$F08706`/`$F0870E` install a
handler on vectors 2 and 3 first." **The attribution was wrong.** Measured over a default boot
and two driven configurations:

| handler | installed at | vector | executions |
|---|---|---|---:|
| `$F08902` | `$F08706`, `$F0870E` | 2 and 3 | **0** |
| `$F08F06` | phase `$600`'s own setup | 2 | **2** |
| `$F098E0` | `$F0960A`, `$F096CC`, `$F0983A` | 2 | **3** |
| `$F088FA` | `$F087B4`, `$F0883C`, `$F088D6` | 85 (`$154`) | **0** |

All five install sites execute exactly once, so the installs are real. But `$F08902` **never
fires**, so it cannot be what carries phase `$600` through its fault.

**Phase `$600` uses its own handler**, `$F08F06` — the one the harness already describes as
"counts faults with a skip-zero guard, and does NOT adjust PC". Measured: the sweep at `$F08F36`
runs once, `$F08F06` fires **twice**, and the exit test at `$F08F4C` runs once. The bus-timeout
watchdog test does provoke its BERR, and it services it itself.

So the self-test installs **three different bus-error handlers across its run**, each belonging
to the phase that needs it, and hands vector 2 between them. `$F08902` and the vector-85 handler
are guards for faults a healthy machine never takes — which is why a green boot leaves them at
zero.

**Method note.** The harness's `$600` checks are *static byte assertions*: they verify the
decoded logic (`tst.l d1 / bne` after the sweep) and prove nothing about runtime. Reading
"`$600` EXITS on a fault ... PASS" as evidence that a fault occurred is exactly the mistake
that produced the wrong attribution. The runtime evidence had to be measured separately, and it
happens to agree.

## Why RDHC sits at 3%: 42 one-way calls to a routine that never returns

RDHC is the largest region (1,451 decoded instructions, `$F04600`-`$F05CFF` from the ROM's own
TDTI entry) and the least executed. Its internal call graph explains that completely — and it is
remarkably small:

| target | call sites | |
|---|---:|---|
| **`$F05688`** | **42** | the panel-command issuer |
| `$F05150` | 4 | |
| `$F051A2` | 3 | S-record data handler |
| `$F056BA` | 3 | `PanelSendAndWait` |
| `$F05652`, `$F055A2` | 2 each | ASQ post; S1 record handler |
| five others | 1 each | |

**Eleven distinct call targets in 1,451 instructions, and 42 of the call sites go to one
routine.** Nothing outside RDHC calls into it; it is self-contained.

`$F05688` does not return:

```
F05688  move.w   d0,$e6e          ; stash the command
F05694  move.w   d0,$e(a0)        ; -> $FF000E
F05698…  MODE1 / MODE0 / CHANNEL_SELECT setup
F056B8  bra.b    $F056B8          ; spin -- and there is no rts in the routine
```

The `rts` at `$F05682` belongs to the preceding routine. So every one of those 42 `jsr`s is a
**one-way transfer**: control returns only if the chassis-response ISR rewrites the stacked PC.

That is RDHC's architecture, not a defect — it is a state machine in which each command issue
parks the task until the chassis answers. And it fixes the meaning of RDHC's coverage number:
**RDHC's execution is bounded by how many chassis responses the model can deliver, not by
anything about its code.** Measured, delivery reaches 7 operations before stalling, which is why
1,399 of its 1,451 instructions never run.

So "RDHC is 3% covered" and "RDHC is poorly understood" are different claims, and only the first
is true. The region decodes cleanly, its call graph is fully mapped, and the single reason it
does not execute is a chassis conversation we cannot yet sustain past seven exchanges.

## RDHC's complete outbound command vocabulary, recovered statically

Since RDHC's execution is bounded by a chassis conversation we cannot sustain, its command set
was never observable at runtime. It is recoverable anyway: each of the 42 `jsr $F05688` sites is
preceded by the command in `d0`. Resolving 41 of 42 by look-back gives **19 distinct codes**:

| code | sites | name |
|---|---:|---|
| `$258` / `$259` / `$25A` | 1 / 2 / 3 | CH1 reset / init / acknowledge |
| `$25C` | 5 | reset status |
| `$25D` `$25E` `$25F` `$260` | 2 / **1** / 2 / 2 | the four per-channel config codes |
| `$269` `$26A` `$26B` | 1 / 4 / 2 | error abort / timeout abort / channel abort |
| **`$26C`** | **9** | release — the `D2_FIN` finalize code, the most-issued of all |
| `$276`-`$27B`, `$27D` | 1 each | init steps 1-6 and 8 |

Three things this settles or corroborates:

- **`$25E` has exactly one site**, independently confirming the correction already recorded when
  the code/data map contradicted an earlier "zero sites" claim. Two different methods, same
  answer.
- **`$262`-`$268` do not appear**, consistent with those being the XP-task-only codes; nor do
  `$281`/`$282`, which belong to TCBIO1I's host link. The three tasks' vocabularies are disjoint
  where this file said they were.
- **`$26C` release is issued nine times** — more than any other code, and more than twice the
  next. RDHC finalises far more often than it initialises, which fits a dispatcher that services
  many short transactions rather than one long one.

This is the SBC-side half of the panel protocol enumerated in full: 19 codes RDHC can send, the
16 chassis operations it can receive (`$F05102`), and the 42-slot status table it dispatches on.
What remains unknown about that protocol is not its vocabulary but its *grammar* — which
sequences the chassis actually drives, which needs hardware or a conversation longer than seven
exchanges.

## The SBC-side grammar is recoverable by inference after all

Last section concluded that what remained was "not vocabulary but grammar — which needs hardware
or a longer conversation". That was half right, and the half that was wrong is recoverable
statically.

Because `$F05688` never returns, the ISR must supply a PC. What each of the 39 resolved call
sites does *next* is therefore the continuation the firmware expects, and it is readable:

| continuation | sites | meaning |
|---|---:|---|
| inline | **18** | the command is a step; execution carries straight on |
| `bra $F050F8` | 8 | `ChannelConfigDispatch` — **end the ISR turn** |
| `rts` | 4 | the issue was a subroutine's last act |
| `jmp $F05678` | 3 | shared tail |
| `bra $F047E6` | 3 | shared init continuation |
| `bra $F05684` | 2 | `moveq #$f,d0 / trap #1` = directive **`$0F` TERM** — the task kills itself |
| `bra $F0481C` | 1 | |

Three things follow, none of which needed hardware:

- **The rescue returns to the instruction after the `jsr`.** Eighteen sites continue inline with
  code that plainly expects to run, so `$F04930`'s PC rewrite must effect the return that
  `$F05688` itself never performs — it pops the caller's address rather than resuming the spin.
- **Eight commands are terminal ISR actions.** "Issue this and end the turn" is the single most
  common *structured* continuation, which is what a response-driven state machine looks like from
  the SBC side.
- **Two commands are followed by task suicide.** Init steps `$276`/`$277` fall through to TERM,
  so a failure at the first two init steps ends RDHC rather than retrying.

**What genuinely still needs hardware** is narrower than stated before: not the SBC's grammar,
which is above, but the *chassis's* — which command sequences the chassis actually drives, and in
what order. The SBC's half of the conversation is now fully enumerated: 19 codes out, 16
operations in, 42 issue points, and the continuation after every one of them.

## RETRACTED: nothing "modifies the saved PC out of `bra .`"

Two claims die together here.

**Mine, from the previous section:** that the rescue "pops the caller's address rather than
resuming the spin", inferred from the 18 inline continuations after `jsr $F05688`.

**This project's, of long standing:** *"The IRQ handler that supplies `d0` and modifies the saved
PC out of `bra .` is `$F04930`."* It appears in this file, in `CLAUDE.md`, and in
`panel_status_dispatch_table.md`.

Searching `$F04930`-`$F05160` — the ISR plus all sixteen dispatch handlers — for any `a7`-relative
operand returns **two hits**, both of them op `$3` saving and restoring the page register:

```
$F04D4E  move.w  $210(a0),-(a7)
$F04E22  move.w  (a7)+,$210(a0)
```

**There is no instruction that writes the stacked PC anywhere in that path.** The mechanism
everyone has been describing does not exist in the code.

What the code does do is symmetric and unremarkable: `$F04930` opens
`movem.l d0-d7/a0-a7,-(a7)` — all sixteen registers, `a7` included — and the exit stub `$F050F8`
closes `movem.l (a7)+,d0-d7/a0-a7`, then `move #$0C,ccr` and `trap #1`. It restores the
interrupted context wholesale and leaves via an **RTOS directive**, not an `rte`.

So the escape from a `bra .` — if there is one — is the RTOS scheduler's business, not a PC
patch. That reopens a question this project treated as answered, and it explains why every
attempt to make the rescue work by driving interrupts harder has failed: **there was never a
rescue instruction to trigger.**

Method note, since this is the second time today: the claim was reasonable, widely repeated, and
never checked against a search for the operand form that would implement it. `a7`-relative writes
are a small, enumerable class — the check took one query.

## How a `bra .` spin is actually escaped: the frame is DISCARDED, not patched

With the PC-rewrite story retracted, the real mechanism is visible, and it was hiding behind the
same supervisor/user split that governs TRAP #0.

**TRAP #1 dispatches on the caller's mode.** At `$F002C6` the handler copies the stacked SR,
masks it with `$7F`, and `bne`s to **`$F0093A`** when the system byte is non-zero — i.e. when the
trap came from supervisor state. A `trap #1` issued from a task reaches the 77-entry directive
table; the *same instruction* issued from an ISR reaches a completely different routine. One
opcode, two interfaces, selected by privilege.

The ISR exit stub `$F050F8` ends `movem.l (a7)+,d0-d7/a0-a7` / `move #$0C,ccr` / `trap #1`, so it
arrives at `$F0093A`:

```
F0093A  btst.b   #$d,(a7)          ; check the stacked SR's S bit
F00942  addq.l   #$6,a7            ; DISCARD the exception frame -- SR and PC both
F00944  movea.l  (a7)+,a6          ; pop a TCB pointer
F00948  cmpi.l   #$21544342,d4     ; verify it really is a '!TCB'
F00954  tst.w    d0                ; 0 -> plain exit
F0095A  cmpi.w   #$1,d0
F00962  bsr.w    $f02c6c           ; 1 -> T0WAKEUP on that TCB
F0096A  cmpi.w   #$2,d0            ; 2 -> $F01600
```

**`addq.l #$6,a7` is the whole answer.** The ISR does not return to the code it interrupted — it
throws away the saved SR and PC and re-enters the kernel. A task spinning at `bra .` is not
rescued, redirected, or patched; **its context is simply abandoned** and the scheduler chooses
what runs next. `d0 = 1` additionally wakes the TCB whose pointer the handler left on the stack,
via `$F02C6C` — the routine the TRAP #0 table independently named **T0WAKEUP**, reached here
through its `bsr` entry point two bytes below the directive entry.

Three consequences:

- The asm annotation calling this `trap #1` **"THE WAKER"** is correct, and now has a mechanism
  rather than a label.
- **Every experiment this session that tried to free a spin by delivering interrupts harder was
  aimed at the wrong thing.** There is no rescue instruction; there is a kernel exit that
  discards the frame. What the interrupt must accomplish is reaching `$F050F8`, not returning.
- It explains the dual-entry convention from the other direction: `$F02C6C` needs a `bsr`-callable
  entry precisely because the kernel calls it internally from *this* path, while directive `$16`
  enters two bytes later.

## PARTIAL UN-RETRACTION: the PC *is* modified — at `$F00282`, not in `$F04930`

Two sections ago I retracted "the IRQ handler modifies the saved PC out of `bra .`" after
searching `$F04930`-`$F05160` and finding no `a7`-relative write. That search was correct and its
conclusion was too broad: **the instruction exists, in the kernel, outside the window I searched.**

TRAP #1 vectors to **`$F00262`** — not `$F002C6`, which I had assumed because it shares the
SR-masking idiom. `$F00262` is the byte immediately after the TRAP #0 jump table, and it tests a
**CCR sentinel**:

```
F00262  move.w  (a7),-(a7)
F00264  andi.b  #$c,$1(a7)     ; mask the stacked CCR with $0C
F0026A  andi.b  #$7f,(a7)      ; mask the system byte
F0026E  beq.b   $f00278        ; user mode -> ordinary directive dispatch
F00270  cmpi.b  #$c,$1(a7)     ; supervisor AND CCR == N|Z ?
F00276  beq.b   $f00280        ; -> the ISR-exit path
```

That is why every ISR exit stub executes `move #$0C,ccr` before its `trap #1`: **the sentinel is
the calling convention.** Mode alone is not enough — a supervisor `trap #1` without the sentinel
falls through to the normal path. This also explains why `$F0093A`, the supervisor branch I
decoded first, executes **zero** times: the sentinel diverts before reaching it.

The ISR-exit path itself:

```
F00280  addq.l   #$4,a7
F00282  subq.l   #$6,(a7)        <-- the stacked PC, backed up by 6
F00288  movea.l  $c6e.l,a5       <-- the !IDV directory slot
F00296  movea.l  $3c(a7),a4      <-- the interrupted PC
F0029A  cmpa.l   $a(a5),a4
F0029E  adda.l   #$e,a5          <-- stride $E = 14 bytes
F002AC  movea.l  -$c(a5),a6
F002B2  bsr.w    $f02c6c         <-- T0WAKEUP on that record's TCB
F002BE  rte
```

**It identifies which task's ISR just finished by matching the interrupted PC against the `!IDV`
table, then wakes that task.** The `$E` stride is exactly the 14-byte `!IDV` record this project
documented as `{vector, TCB, ISR entry, ISR exit}` — an independent confirmation of that
structure from code that was never examined when it was derived.

Measured, at `FPS3K_BIM0LVL=7`: `$F050F8` and `$F02C6C` each execute **219 times**, in lockstep.
The exit stub and the waker are the same event.

So the corrected attribution is: the PC adjustment is real, it is `subq.l #$6,(a7)` at
`$F00282`, it lives in the RMS68K kernel rather than the FPS panel handler, and it is reached
only via a CCR sentinel. Everything said about `$F04930` doing it remains wrong.

### What the `-6` adjustment does NOT do

`subq.l #$6,(a7)` at `$F00282` acts on the stacked PC after `$F00280` has popped the SR copy and
the SR. The `trap #1` at `$F05100` is two bytes, so the stacked PC is `$F05102` and the
adjustment targets **`$F050FC`** — the `move.w #$c,ccr` immediately before the trap.

That predicts the `rte` re-executes the sentinel and traps again, i.e. a loop in which `$F050FC`
runs more often than `$F050F8`. **Measured, it does not:**

```
F050F8 x219    F050FC x219    F05100 x219
F00280 x219    F00282 x219    F002BE x219   (the rte)
```

All equal — exactly one pass per ISR exit, no re-execution. The reason is two instructions before
the `rte`: `$F002BA` does `lea.l $4(a7),a7`, which **skips the very PC slot `$F00282` just
modified**. So the adjusted value is not what the `rte` consumes.

What the adjustment is *for* therefore remains open. The candidates are that it prepares a frame
consumed elsewhere (the `!IDV` record holds an "ISR exit" field this path could be maintaining),
or that it fixes up a saved context belonging to the woken task rather than the interrupted one.
**Not resolved, and stated as such** — the stack discipline across `$F00280`-`$F002BE` needs a
careful frame-by-frame model, not another inference.

What *is* established and measured: the CCR sentinel selects this path, it walks `!IDV` on a
14-byte stride to identify the finishing ISR, it wakes that record's TCB through `T0WAKEUP`, and
it runs exactly once per exit — 219 times in lockstep with the stub across a level-7 run.

## RESOLVED: the `-6` is a table-lookup key normalisation

The open question — what `subq.l #$6,(a7)` at `$F00282` is for — is answered by dumping `!IDV`.

Tracing the frame properly (rather than predicting from one instruction): after `$F00280`'s
`addq.l #$4,a7` the stack pointer is at the PC field; `$F00284` then pushes 15 registers, 60
bytes; so `$F00296`'s `movea.l $3c(a7),a4` — offset **60** — reads back **the adjusted PC**. It is
not a return address at all. It is a **search key**.

`!IDV` at `$1F800`, six live records on a 14-byte stride:

```
+000  0045  0001E900  00F07EE6  00F07F08     XP1I
+00E  0046  0001EB00  00F074E6  00F07508     XP2I
+01C  0047  0001ED00  00F06AE6  00F06B08     XP3I
+02A  0048  0001EF00  00F060CE  00F060F0     XP4I
+038  004A  0001F100  00F05DD6  00F05E4C     IO1I
+046  0041  0001F300  00F04930  00F050FC     RDHC   <- $F050FC
```

Field map confirmed exactly as this project documented it, now with offsets:
**`+0` vector (word), `+2` TCB (long), `+6` ISR entry (long), `+10` ISR exit (long)** = 14 bytes.

The chain closes:

1. `trap #1` from the exit stub stacks PC = `$F05102`.
2. `subq.l #$6` makes it **`$F050FC`** — the value the record stores.
3. `$F0029A`'s `cmpa.l $a(a5),a4` compares at **offset 10**, the ISR-exit field, and matches.
4. `$F002AC`'s `movea.l -$c(a5),a6` takes the TCB at offset 2 — **`$1F300`**, the sixth TCB,
   which is RDHC — and `$F002B2` wakes it via `T0WAKEUP`.
5. `lea.l $4(a7),a7` then discards the trap frame so the `rte` unwinds through the *interrupt's*
   frame, returning to whatever the interrupt interrupted.

So the adjustment exists because **the stacked PC points past the trap and the table stores the
address of the sentinel**. Six bytes is the distance from `move.w #$c,ccr` to the instruction
after `trap #1` — `4 + 2`. Every task's exit stub is at a different address, which is exactly why
the lookup is needed at all: one kernel routine serves six ISRs and identifies the caller by where
it trapped from.

This also independently re-derives the `!IDV` record layout from the code that consumes it,
having previously been read off the structure that produces it.

### The sentinel convention is uniform across all six tasks

Every `!IDV` record's ISR-exit field points at a `move.w #$c,ccr` — checked, all six:

| task | ISR-exit field | bytes at that address |
|---|---|---|
| XP1I | `$F07F08` | `44 fc 00 0c` |
| XP2I | `$F07508` | `44 fc 00 0c` |
| XP3I | `$F06B08` | `44 fc 00 0c` |
| XP4I | `$F060F0` | `44 fc 00 0c` |
| IO1I | `$F05E4C` | `44 fc 00 0c` |
| RDHC | `$F050FC` | `44 fc 00 0c` |

Six for six. So the CCR sentinel is not an RDHC quirk — it is **the ISR-exit calling convention
of the whole firmware**, and `!IDV` stores each task's sentinel address as the key that
identifies it to the one shared kernel routine.

This makes the mechanism emulator-relevant in a concrete way: a model that lets an ISR return by
`rte` instead of routing it through `trap #1` with `CCR = $0C` will never wake the task, and the
failure will look like "the interrupt fired but nothing happened" — which is exactly the symptom
this project chased for several sessions under the heading of the `bra .` deadlock.

## CORRECTION: TRAP #2-#15 vectors are populated, not free

This project records that the firmware "uses only TRAP #0 and TRAP #1 — a sweep of every
`TRAP #n` finds **zero** uses of #2-#15, so those fourteen vectors are free". The sweep is right;
the conclusion drawn from it is not.

Dumping the **runtime** vector table (built in RAM at boot, so invisible to any ROM scan) shows
those fourteen vectors pointing at fourteen consecutive addresses on a **2-byte stride**:

```
F00A78  61 1c   bsr.b $f00a96     <- TRAP #2
F00A7A  61 1a   bsr.b $f00a96     <- TRAP #3
  …                                  …
F00A92  61 02   bsr.b $f00a96     <- TRAP #15
F00A94  4e 71   nop
F00A96          move.w $4(a7),-(a7)   ; the shared handler
F00A9A          andi.b #$7f,(a7)      ; the same supervisor/user split
```

A **`bsr` fan-in ladder**: fourteen two-byte branches to one handler. Each `bsr` stacks its own
return address, so the handler can tell which trap fired from where it was called — the same
"identify the caller by where it came from" idiom the kernel uses for `!IDV`, and a second
instance of that pattern.

So the vectors are **live kernel handlers**, not empty slots. What the sweep established is
narrower: *this firmware never issues* TRAP #2-#15, which is a different statement from *nothing
is installed there*.

**Consequence for the monitor.** Installing a `TRAP #14` breakpoint handler overwrites a
populated kernel vector rather than filling an empty one. In practice that is still safe — the
firmware issues no TRAP #14, so the kernel handler at `$F00A90` is never reached — but the
existing note ("those fourteen vectors are free ... confirmed conflict-free by measurement")
describes the right conclusion for the wrong reason, and a reader planning to use another trap
number should know they are all occupied.

Also visible in the same dump: **`$F0A27A` serves 182 vectors** (the panic catch-all, matching
the documented count) and **`$F00896` serves 37**.

## The kernel's remaining 18.5% is unreached code, not data

Seeding `disasm_kernel.py` from the **runtime** vector table (`FPS3K_DIS_RAM=<dump>`) adds 20
entry points and lifts coverage **80.3% → 81.5%** (+218 bytes, +65 instructions). A modest gain:
most vector targets were already reachable by other routes.

That leaves 3,244 bytes in 83 gaps. Two of the largest are correctly *not* code:
`$F001D6`-`$F00261` is the TRAP #0 jump table (35 × 4 = 140 bytes exactly) and `$F003E8`-`$F0050B`
the tail of the TRAP #1 table. But sampling the rest shows **clean 68000 code**:

```
F01932  tst.l d5 / beq / move.w $a(a4),d0 / andi.w #$27ff,d1 / btst #$8,d1
F028C4  clr.l d0 / move.b $c73.w,d0 / swap d0 / movea.l d0,a0 / bsr.w $f0123e
F01C6E  move.l a1,d5 / move.l $10(a2),d6 / btst #$e,$8(a2) / bne
F031F0  bset #$7,$29(a6) / move.l d0,$120(a6) / move.l $10(a6),(a1,d3.w)
```

So the residue is **unreached code whose callers are themselves unreached** — orphaned
subgraphs. Either they are entered through a computed dispatch this tool does not model, or they
are dead in this build. Distinguishing those needs another entry-point source, not a better
decoder, which is the same conclusion the application-region control produced.

### The dual-entry convention, caught in use

`$F028D2` is `bsr.w $f0123e`. `$F01240` is **T0PAGAL**, the TRAP #0 directive-`$04` handler, and
`$F0123E` is two bytes earlier — measured, it contains **`$40E7` = `move.w sr,-(a7)`**.

That is the convention documented from the 29-of-33 census, now observed being *used*: an
internal caller enters at the `bsr` entry and pushes SR itself, while the directive path enters
two bytes later because the trap already stacked it. The census established the pattern from the
table side; this is the call side, in code the census never examined.

### The `rts`-dispatch idiom is exhausted as an entry-point source

The `move.l (a0),-(a7)` / `rts` idiom — the return stack used as an indirect jump, and the reason
linear control-flow following loses the thread in this kernel — was the obvious remaining source
of entry points for the orphaned subgraphs. Searching every `rts` in `$F00000`-`$F04487` for a
preceding push of a memory longword finds **exactly two sites**:

| site | dispatch through | status |
|---|---|---|
| `$F001D0` | `(a0)` — the TRAP #0 jump table | already the tool's main seed source |
| `$F00D52` | the longword at **`$0C36`** | **dormant** |

`$0C36` reads `$00F000BC` after a boot, which is a real kernel address — but `$F000BC` is
**zero-filled** (the 27 nonzero bytes in that 100-byte span are the `!VCT` marker at `$F0011A`,
past the zeros). And measured over a full boot, **`$F00D52` executes 0 times and `$F000BC` 0
times**. So it is a dispatch vector initialised to a placeholder and never taken.

**That closes the avenue.** The idiom yields no new entry points: one site is already exploited,
the other is inert. The kernel's orphaned 18.5% is therefore *not* reached through the return-stack
dispatch, which leaves computed jumps this tool does not model, or genuinely dead code in this
build — and distinguishing those now needs execution on a configuration that exercises more of the
kernel, not more static analysis.

Worth stating because the idiom was the leading hypothesis for where the missing entry points
were: it was a good hypothesis, it is now tested, and it is empty.

## The TRAP #1 table's `w1` field decoded: its low nibble is the exit action

Chasing register-indirect jumps found seven in the kernel. Two are the TRAP #1 dispatch pair —
`$F00376 jmp (a2)` (into the handler) and `$F003C2 jmp (a0,d0.w)` (the **exit** dispatch) — and
the second indexes a table at **`$F00650`** that had never been examined.

The table is **5 entries of 2 bytes**, not 16 as the `andi.l #$f,d0` mask suggests:

```
[0] F00650  bra.b $f0065a
[1] F00652  bra.b $f0066a
[2] F00654  bra.b $f00670
[3] F00656  bra.b $f0064c
[4] F00658  bra.b $f0067c
    F0065A  tst.b $c5b.w        <- entry 0's target; the table ends here
```

Index 5 is already code, so the table size is 5 — derived from where the entries stop being
`bra.b`, not from the mask.

**The index is the low nibble of `w1`**, the second word of each TRAP #1 table entry. `$F00332`
pushes `d2` = `w1`, and `$F003B2` pops it, masks `#$F`, doubles it and jumps. Checked across all
**77** entries:

| low nibble | entries |
|---|---:|
| 0 | 60 |
| 1 | 7 |
| 2 | 7 |
| 3 | 2 |
| 4 | 1 |

**Maximum 4, none out of range, and the table holds exactly 5.** Two independently derived
numbers agreeing exactly is what makes this a decode rather than a guess.

So a TRAP #1 table entry is now fully accounted for:

| field | meaning |
|---|---|
| `w0` | **self-relative signed offset** to the handler (`adda.w (a2),a2`) |
| `w1` bit 7 | tested at `$F00334`; selects a parameter-validation path |
| `w1` bit 6 | tested at `$F00354` |
| `w1` low nibble | **exit action**, 0-4, into the `$F00650` table |

That the common case is 0 (60 of 77) fits: most directives return through the same path, and the
seven-plus-seven-plus-two-plus-one tail is the set that needs special unwinding — `SUSPND` and
`WAIT` both carry `$0001`, and `START` and `TERMT` both carry `$0A82`, which is exactly the
pairing their semantics predict.

### All seven computed dispatches accounted for — and none yields a static entry point

| site | form | source of the target |
|---|---|---|
| `$F00376` | `jmp (a2)` | TRAP #1 table, `entry + w0` — **already seeded** |
| `$F003C2` | `jmp (a0,d0.w)` | the 5-entry exit table at `$F00650` — **now decoded** |
| `$F001D0` | `move.l (a0),-(a7)` / `rts` | TRAP #0 table — **already seeded** |
| `$F00D52` | `move.l $c36.w,-(a7)` / `rts` | **dormant**, points at zero fill, 0 executions |
| `$F013D0` | `jmp (a1)` | register, set elsewhere |
| `$F03A08` | `jsr (a5)` | `movea.l d6,a5` after `movem.l $100(a6),d0-d7/a0-a4` |
| `$F04340` | `jsr (a0)` | `movea.l $1a(a5),a0` then `adda.l $4(a0),a0` |
| `$F04004`, `$F04086` | `jsr`/`jmp (an)` | inside undecoded regions themselves |

Every dispatch mechanism in the kernel is now identified, and the conclusion is uniform: the
three that draw from **static tables are all exploited**, and the rest take their targets from
**runtime structures** — a TCB field, a two-level pointer chain, a register loaded from data.

**So the kernel's orphaned 18.5% is unreachable by static analysis in principle, not by
oversight.** It is entered through pointers that only exist once the machine is running, which
means the only route to it is execution on a configuration that populates those structures. That
retires the entry-point question rather than leaving it open.

One structural observation worth keeping, flagged as tentative: `$F03A02` does
`movem.l $100(a6),d0-d7/a0-a4` — thirteen registers, 52 bytes — immediately before `jsr (a5)`.
If `a6` is a TCB there, **`TCB+$100` is a saved register image** and this is a context restore.
Against that, the TRAP #1 path writes `$100(a6)` and `$102(a6)` as *word* status fields, so
either `a6` differs between the two paths or the offset is reused. Not resolved, and not assumed.

## `TCB+$0FC` is the saved resume PC — and it identifies where every task is parked

Computing the vendor `TCB.EQ` layout (it uses offset-accumulating `DS` directives, not `EQU`, so
the offsets have to be summed) gives a 320-byte TCB with a context block near the end:

```
+$0F8  TCBA6     user's A6
+$0FC  TCBUSP    user's A7
+$100  TCBSR     user's status register
+$102  TCBPC     user's program counter
```

Checked against live TCBs rather than adopted, and the build does **not** match:

| task | `+$0F8` | `+$0FC` | `+$100` | `+$102` |
|---|---|---|---|---|
| RDHC `$1F300` | `$00000004` | **`$00F04740`** | `$0000` | `$00000000` |
| IO1I `$1F100` | `$00000004` | **`$00F05DC2`** | `$0000` | `$00000000` |
| XP1I `$1E900` | `$00000004` | **`$00F07E1C`** | `$0000` | `$00000000` |

`+$0FC` holds a **ROM code address**, so it is a program counter, not a stack pointer — the
vendor layout is shifted by 6 in this region. And the value is self-verifying: **RDHC's is
`$F04740`**, the instruction this project has separately measured as *executing zero times*
because RDHC enters its directive-`$13` wait at `$F0473C` and never leaves. The saved PC is
exactly where the task will resume, and it matches the documented parked address on the nose.

So **`TCB+$0FC` gives any task's resume point from a RAM dump** — IO1I is parked at `$F05DC2`,
XP1I at `$F07E1C`. That is a directly useful emulation and debugging primitive, and it is
measured rather than inferred from the vendor file, which is wrong here.

**Retracting my own tentative reading** from the dispatch inventory: I suggested `TCB+$100` might
be a saved register image because `$F03A02` does `movem.l $100(a6),d0-d7/a0-a4`. It is **zero in
all three TCBs**, so it is not a populated register image in any configuration reached so far,
and `a6` at that site is evidently not a TCB.

## A complete task snapshot from two of today's findings

`TCB+$2C` is the task-state word (bit 9 suspended, bit 14 waiting, from the SUSPND/RESUME and
WAIT/WAKEUP inverse pairs) and `TCB+$0FC` is the saved resume PC. Together they read a whole
machine out of a RAM dump:

| TCB | name | state | flags | resume PC |
|---|---|---|---|---|
| `$1E900` | XP1I | `$4000` | WAITING | `$F07E1C` |
| `$1EB00` | XP2I | `$4000` | WAITING | `$F0741C` |
| `$1ED00` | XP3I | `$4000` | WAITING | `$F06A1C` |
| `$1EF00` | XP4I | `$4000` | WAITING | `$F06022` |
| `$1F100` | IO1I | `$4000` | WAITING | `$F05DC2` |
| `$1F300` | RDHC | `$4000` | WAITING | `$F04740` |

Three independent confirmations fall out of one table:

- **All six read `$4000` — bit 14 alone.** That is exactly the bit derived this morning from
  `WAIT` setting it and `WAKEUP` clearing it, and it matches the documented boot state in which
  every task blocks on directive `$13`. The bit identification and the boot description confirm
  each other.
- **RDHC's `$F04740`** is the instruction measured as executing *zero* times, because RDHC waits
  at `$F0473C` and never leaves. Saved PC and execution trace agree.
- **The XP4I offset anomaly appears again, as `+$6`.** XP1I→XP2I→XP3I step by exactly `$A00`,
  but XP3I→XP4I is `$9FA`. This project has recorded XP4I as `−$1E` in the task body and `−$18`
  in its `!IDV` ISR entry; here the same copy is `+$6`. **Three different deltas in three
  different fields** is the signature of a hand-patched template rather than a relocated one,
  which is what the "hand-written assembly, not compiled" finding predicts.

Practically: `TCB+$0FC` plus `TCB+$2C` answers "where is every task and why is it stopped" from a
single dump, with no trace required.

## The wake mechanism verified in machine state: RDHC's WAITING bit clears

Comparing task snapshots between a default boot and the level-7 driven configuration:

| task | default | driven |
|---|---|---|
| XP1I-XP4I, IO1I | `$4000` / unchanged | `$4000` / unchanged |
| **RDHC** | `$4000` (WAITING) | **`$0018`** — bit 14 **cleared** |

**Bit 14 is the WAITING bit**, derived this morning from `WAIT` setting it and `WAKEUP` clearing
it. Seeing it go from set to clear in a driven run is the first evidence *in machine state* —
rather than in PC counts — that the entire chain works end to end:

```
BIM0 ch0 raised → $F04930 → dispatch → $F050F8 exit stub → move #$0C,ccr → trap #1
   → $F00262 sentinel test → $F00280 → !IDV lookup on the -6'd PC → T0WAKEUP → bclr #$e,$2c
```

Every link in that chain was established separately today; this is the whole of it observed
working at once, on the one task whose vector (`$41`) is being driven. The other five are
untouched, exactly as they should be — nothing is raising their BIM channels.

Two honest limits on the claim:

- **RDHC is woken, not advanced.** Its saved PC stays `$F04740`, and its coverage stays at 3%.
  Waking a task and running it to completion are different things: it wakes, fails to sustain
  the chassis conversation past seven exchanges, and re-parks.
- **This is the level-7 probe**, which contradicts the `$5E` the firmware writes. At the
  firmware's own level 6 the state word does not change. So what is demonstrated is that the
  *mechanism* is correctly understood and correctly modelled — not that a real board delivers at
  level 7.

`$0018` (bits 3 and 4) is the state RDHC lands in; those bits are not yet identified.

## The task state word `TCB+$2C`: flag bits enumerated, low byte unresolved

A full census of bit operations on `+$2C` across the ROM — every `bset`/`bclr`/`btst` with a
`$2C` displacement — finds **13 sites on exactly five bits**:

| bit | sites | operations | first |
|---:|---:|---|---|
| 9 | 2 | `bset` + `bclr` | `$F02CAC` (SUSPND / RESUME) |
| 10 | 2 | `bset` + `btst` | `$F00D9A` |
| 12 | 2 | `bset` + `bclr` | `$F0285E` |
| 13 | 2 | `bset` + `bclr` | `$F00718` |
| 14 | 5 | 2 `bset`, 3 `bclr` | `$F02C3E` (WAIT / WAKEUP) |

Every one is a matched set/clear pair — a clean flag-word design. Bits 9 and 14 are already
identified (suspended, waiting); 10, 12 and 13 are unnamed but structurally the same kind of flag.

**Bits 3 and 4 are never touched by any bit operation**, so the `$0018` RDHC lands in after being
woken is not a pair of flags. The whole ROM contains only **four** writes into `+$2C`:

```
$F00866, $F0087C   move.w d6,$2c(a0)
$F02966            move.b #$80,$2c(a5)
$F0A0B2            move.w d2,$2c(a5)     -- immediately after T0CRTCB, so task creation
```

`$F0A0AE` loads that value from `$14(a3)` and `$F0A0B6` immediately tests bit 4 of it, which
looked like the origin. **It is not the TDTI entry**: the word at `+$14` of all six `!TCB`
definitions reads `$0000`, so `a3` at that point is some other structure.

So the low byte of the state word is a **value field, not flags**, written from a runtime source
this pass did not identify. Bounded, and left there rather than guessed at — the flag-bit census
is the durable result, and it is complete.

### Bit 12 named: the state word carries one bit per blocking reason

Mapping each state-word bit site to the directive handler containing it (using the 77 handler
addresses and the `TR1.EQ` names) identifies bit 12:

| bit | sites | enclosing handler |
|---:|---|---|
| 9 | `bset` / `bclr` | `$11` SUSPND / `$12` RESUME |
| **12** | `bset` `$F0285E`, `bclr` `$F0286C` | **both inside `$24` WTEVNT** |
| 14 | `bset` / `bclr` | `$13` WAIT / `$16` WAKEUP |

So three of the five flags are now named, and they form a coherent set: **one bit per reason a
task can be blocked** — suspended (9), waiting on an event (12), waiting on a directive (14).
Each is set by the directive that blocks and cleared by the one that releases.

Bits 10 and 13 are **kernel-internal**. Their sites (`$F00718`, `$F007B6`, `$F00D9A`) lie below
the lowest directive handler, so the enclosing-handler attribution reports the `$F003D0` stub for
them and means nothing — an artifact of "greatest handler start ≤ address" when the address
precedes them all. The one informative site is `$F0300E`, a **`btst` of bit 10 inside `$0F`
TERM**, so bit 10 is set by kernel code and consulted during task termination.

Consistency note: `WTEVNT` (36 = `$24`) is one of the ASQ directives this project records as
appearing **nowhere in this firmware**. That remains true of *call sites* — the FPS application
never issues it — while the kernel plainly implements it and manipulates a state bit for it. The
two statements describe different layers, as with the earlier `GTASQ`/`RDEVNT`/`QEVNT` check.

## A usage-derived TCB field map — 54 fields, and `+$102` is the directive status

Since `a6` is the TCB pointer throughout the kernel, every `$xx(a6)` displacement is a TCB field
reference. Sweeping the decoded kernel gives **54 distinct displacements over 372 accesses**:

| offset | accesses | operations | reading |
|---|---:|---|---|
| **`+$102`** | **119** | `addi, addq, clr, move, tst` | **directive status / return code** |
| `+$036` | 24 | `movea` | a pointer field |
| `+$014` | 23 | `cmp, move` | |
| `+$028` | 23 | `btst, move` | flag byte |
| `+$120` | 23 | `clr, move, movem` | vendor `TSTBEGIN` |
| `+$100` | 16 | `clr, move, movem` | |
| `+$02D` | 14 | `bclr, bset, btst` | flag byte |
| `+$02C` | 11 | `bclr, bset, move` | **the task state word** |
| `+$029` | 10 | `bclr, bset, btst` | flag byte |
| `+$13C` | 10 | `add, move, movea, subi, subq` | a counter |

**`+$102` is the busiest field in the kernel by a factor of five**, and the operations settle it:

```
F0030C  clr.w   $102(a6)      ; TRAP #1 entry — clear status before dispatch
F003C6  move.w  #$1,$102(a6)  ; range-check failure — status 1
F003D0  move.w  #$1,$102(a6)  ; the unimplemented-directive stub — status 1
```

Cleared on entry to every directive and set to 1 on every failure: it is the **return code**.
The vendor `TCB.EQ` calls `+$102` `TCBPC`, the user's program counter, which is wrong here for
the same reason its `+$0FC TCBUSP` was — **the measured saved PC is at `+$0FC`** (verified against
RDHC's parked `$F04740`). The vendor layout is displaced by 6 across this whole region, so
`TCBSR`→`+$0FA`, `TCBPC`→`+$0FC`, and what the file calls `TCBPC` at `+$102` is in fact the
status word.

Note `+$0FA` appears in the sweep with 5 accesses, exactly where the shifted `TCBSR` would land.

Usage-derived mapping like this is worth more than the vendor file for this build: it cannot be
wrong about which offsets the firmware touches, and it flags disagreements instead of inheriting
them.

### A better enclosing-routine finder, and what it says about bit 10

The "greatest directive-handler start ≤ address" heuristic is wrong for kernel-internal code — it
reports the `$F003D0` stub for anything below the lowest handler. Replacing it with a **scan back
to the instruction after the previous `rts`/`rte`/`jmp`/`bra`** gives true routine boundaries:

| bit | site | enclosing routine |
|---:|---|---|
| 13 | `bset $F00718` | `$F00718` (the site is the routine start; 2 callers, `$F00702` and `$F01326`) |
| 13 | `bclr $F007B6` | `$F007A0` |
| 10 | `bset $F00D9A` | `$F00D9A` |
| 10 | `btst $F0300E` | **`$F02FDA`** |

`$F02FDA` is the **lowercase `!tcb` teardown routine** decoded earlier today — the one that pushes
a block onto the free list at `$E34`, one's-complements each subordinate marker, and stamps the
TCB `!tcb`. So **bit 10 is consulted while a task's structures are being freed**, and the two
attribution methods agree: the directive-based mapping put this site "inside `$0F` TERM", and
TERM's handler at `$F02F64` runs into exactly this teardown code.

Bits 10 and 13 remain unnamed — `$F00D9A`, `$F007A0` and `$F02FDA` have **no `bsr`/`jsr` callers**
because they are fall-through continuations rather than separately-called routines, so naming them
needs execution tracing rather than more static structure. Recorded as bounded rather than
pursued further.

The finder itself is the reusable part: routine boundaries from terminator scan-back are correct
where handler-table attribution is not, and the difference matters for any field or flag whose
sites lie outside the directive handlers.

## The directives ARE the kernel's subroutine library

A routine inventory of the kernel — boundaries taken from terminator scan-back — finds **432
routine starts**, of which **58 have `bsr`/`jsr` callers** and 374 are fall-through continuations.

The call distribution is the finding:

| | |
|---|---:|
| total kernel call sites | 291 |
| sites landing on a **directive handler's `bsr` entry** (`handler − 2`) | **134** |
| **fraction** | **46%** |
| distinct such routines | 28 |

The ten most-called routines in the kernel are **all TRAP #0 handlers entered two bytes early**:

| routine | callers | is |
|---|---:|---|
| `$F0175C` | **31** | `$F0175E` = TRAP #0 directive `$08` |
| `$F00788` | 16 | `$F0078A` = directive `$02` |
| `$F007C0` | 7 | `$F007C2` = directive `$03` |
| `$F006E8` | 7 | `$F006EA` = directive `$01` |
| `$F017C4` | 7 | `$F017C6` = directive `$07` |
| `$F01494` | 7 | `$F01496` = directive `$05` |
| `$F0170E` | 6 | `$F01710` = **T0GETTCB** |

**So the dual-entry convention is load-bearing, not decorative.** Nearly half of everything the
kernel calls internally is a *directive*, reached through the `bsr` entry that pushes SR while
the TRAP path enters past it. The system-call interface and the internal subroutine library are
**the same code**, and the two-byte prologue is what lets one body serve both without a wrapper
per directive.

That reframes the 29-of-33 census from a curiosity into the kernel's basic organising principle,
and it explains the four exceptions: `$F01108` and `T0CRTCB` are preceded by `rte`, i.e. they are
the directives with **no internal callers**, so they never needed a `bsr` entry.

Incidentally the kernel's busiest subroutine is **directive `$08`** at `$F0175E`, with 31 internal
call sites — unnamed in `TR1.EQ`'s list and never issued by the FPS application, yet the single
most-used routine in the RMS68K kernel.

## Directive `$08` identified: the kernel's address-range validator

The busiest routine in the kernel — 31 internal call sites, unnamed in `TR1.EQ`, never issued by
the FPS application — is a **memory-range check**:

```
F0175C  move.w  sr,-(a7)        ; the bsr entry
F0175E  bclr.b  #$0,d6          ; TRAP entry starts here
F01762  andi.l  #$ffffff,d6     ; d6 = an address, 24 bits
F0176A  move.l  d6,d3
F0176C  lsr.l   #$8,d6          ; -> 256-byte PAGE number
F0176E  move.l  d5,d4           ; d5 = size
F01770  ble.b   $f017b6         ; size <= 0 -> reject
F01772  add.l   d3,d4
F01774  subq.l  #$1,d4
F01776  lsr.l   #$8,d4          ; -> end page
F0177A  move.w  $6(a0),d5       ; table index
F0177E  tst.b   $7(a0,d5.w)     ; entry in use?
F01784  cmp.w   (a0,d5.w),d6    ; page   vs record low bound
F0178A  cmp.w   $2(a0,d5.w),d6  ; page   vs record high bound
F01790  cmp.w   $2(a0,d5.w),d4  ; end pg vs record high bound
```

It takes **address in `d6`, size in `d5`**, converts both to page numbers, and walks a table of
`{low, high}` page-bound records looking for one that contains the whole range. That is
**"is this user buffer inside a segment this task owns?"** — the check every directive taking a
caller-supplied address must perform, which is exactly why it has 31 callers and is the most-used
routine in the kernel.

Two corroborations that this is the right reading:

- **The shift is `lsr.l #$8` — 256-byte pages**, the same granularity as `T0PAGAL`, the allocator
  that hands out memory in 256-byte pages and is why every RTOS structure sits on a `$1Fx00`
  boundary. Validator and allocator agree on page size, as they must.
- The record layout — bounds at `+0`/`+2`, an in-use byte at `+7`, indexed via `$6(a0)` — is a
  segment table, and segment allocation (`$01` GTSEG) is directive 1.

Named from behaviour rather than from a vendor list, and flagged as such: `TR1.EQ` does not name
directive `$08`, so this is an inference from what the code does, not a lookup.

## The kernel's two core primitives are TRAP #0 directives `$02` and `$03`

The second and third most-called routines in the kernel, after the address validator.

### `$02` at `$F0078A` — atomic counter increment under a `tas` lock (16 callers)

```
F0078A  ori.w   #$700,sr    ; critical section at level 7
F0078E  tas.b   (a0)        ; the 68000's atomic test-and-set
F00790  bmi.b   $f0078e     ; spin until the lock bit is won
F00792  move.w  (a0),d0
F00794  lsl.w   #$1,d0
F00796  asr.w   #$1,d0      ; strip the TAS bit
F00798  addq.w  #$1,d0      ; increment the count
F0079A  ble.b   $f007a0
F0079C  move.w  d0,(a0)     ; store back — also releases the lock
F0079E  rte
```

`tas.b` is the only atomic read-modify-write the 68000 has, so this is the kernel's **semaphore
signal**: acquire the lock byte, bump the count, release. It is the counterpart on the TRAP #0
side to the `ATSEM`/`WTSEM`/`SGSEM`/`CRSEM` family on the TRAP #1 side.

### `$03` at `$F007C2` — priority-ordered ready-queue insertion (7 callers)

```
F007C2  bset.b  #$4,$2d(a0)   ; "already queued" guard
F007C8  bne.b   $f007fa       ; set already -> nothing to do
F007CE  lea.l   $c08.w,a1     ; the queue head
F007D2  ori.w   #$700,sr
F007D6  move.b  $26(a0),d0    ; this task's PRIORITY
F007DC  movea.l $c(a2),a1     ; walk via the next pointer
F007E8  cmp.b   $26(a1),d0    ; compare priorities
F007EC  bls.b   $f007da       ; keep walking while <=
F007EE  move.l  a1,$c(a0)     ; link in
```

**Four structures named from one routine:**

| | |
|---|---|
| `TCB+$26` | **task priority** (byte, the ordering key) |
| `TCB+$0C` | **queue next-pointer** |
| `TCB+$2D` bit 4 | **already-queued flag**, a `bset`/`bne` double-insert guard |
| `$0C08` | **the ready-queue head** |

Both fields appear in the usage-derived map with matching profiles — `+$026` with 6 accesses all
`move`, consistent with a value read for comparison, and `+$02D` with 14 `bclr`/`bset`/`btst`,
consistent with a flag byte.

So the kernel's three busiest routines are, in order: **validate a user address range**, **signal
a semaphore**, and **insert a task into the ready queue by priority** — which is a reasonable
summary of what an RTOS kernel spends its time doing, and all three are directives reached through
their `bsr` entry.

## The `$1F500` pool identified: a circular trace ring, and why it is always empty

This project records `$1F500` (directory slot `$0C30`) as *"a pool of 9 records of `$1A` bytes
behind an 8-byte first/last header (`$1F508`/`$1F5F2`), untouched in every configuration reached
so far"* — allocated, sized, and unexplained.

`$F01688`, the most-called **non-directive** routine in the kernel (11 callers), is its writer:

```
F0168E  movea.l $c30.w,a3      ; the pool directory slot
F01692  ori.w   #$700,sr       ; critical section
F01696  movea.l (a3),a5        ; current record pointer
F01698  cmpa.l  $4(a3),a5      ; at the limit?
F0169E  lea.l   $8(a3),a5      ; yes -> wrap to the first record
F016A2  lea.l   $1a(a5),a4     ; advance by $1A
F016A6  move.l  a4,(a3)        ; store the new head
F016AA  move.l  d0,$10(a5)     ; record fields
F016AE  move.l  a0,$8(a5)
F016B2  move.l  a6,$c(a5)      ; a6 = the TCB
F016BA  move.w  (a4),(a5)
```

A **circular ring buffer**: wrap-on-limit, fixed `$1A` stride, written under interrupt mask. The
geometry closes to the byte — `$1F500 + 8 + 9 × $1A = $1F5F2`, exactly the documented limit —
and the header the routine uses (`(a3)` current, `$4(a3)` limit, `$8(a3)` first record) is
exactly the documented 8-byte first/last header.

**Record layout**, from the writer:

| offset | content |
|---|---|
| `+$00` | a word taken from the caller's stack |
| `+$08` | `a0` |
| `+$0C` | `a6` — the **TCB**, so each entry is attributed to a task |
| `+$10` | `d0` |

So it is an **event/trace log**, one entry per significant kernel event, tagged with the task it
belongs to.

**And it explains the dormancy.** `$F01688` executes **0 times** in a full boot: its callers are
exception paths — `$F002E4` in the TRAP #1 supervisor route, gated on `btst #$f,$c34.w`, and
`$F00ABE` in the TRAP #2-#15 fan-in handler. Nothing traps abnormally, so nothing is logged, and
the pool stays at its 6 initialised header bytes. **The structure is not unused; it is a
diagnostic buffer on a machine with no faults to report.**

## `$0C34` is a kernel trace-enable mask — and turning it on works

Eight `btst` sites read `$0C34`, one per bit of its high byte, and nothing ever writes it:

| bit | site | gates |
|---:|---|---|
| 15 | `$F002DC` | the trace ring at `$F01688` |
| 14 | `$F00896` | the generic handler serving 37 vectors |
| 13 | `$F00F5E` | |
| 12 | `$F00AB4` | the TRAP #2-#15 fan-in path |
| 11 | `$F00B52` | |
| 10 | `$F0059A` | |
| 9 | `$F008FC` | |
| 8 | `$F006D8` | |

The word reads **`$0000`** after boot, so **all eight kernel instrumentation hooks are disabled**
in this build. That is why so much of this kernel looks dormant.

**Enabling bit 15 works.** With `FPS3K_POKE="0C34=8000"` the boot still completes normally
(final PC `$F00FCC`, the RTOS idle loop) and the ring writer runs **4 times** against 0:

```
$F002DC (the test)        27
$F002E4 (the gated bsr)    4
$F01688 (the ring writer)  4
```

### What it logged

Reading the records back gives a **system-call trace**, and `d0` is the directive number:

| | task | `a0` (parameter block) | `d0` |
|---|---|---|---|
| [0] | IO1I | `$F05D00` | **`$13` WAIT** |
| [1] | RDHC | `$F046B0` | **`$01` GTSEG** |
| [2] | RDHC | `$F04600` | **`$4C` CNCTIRQ** |
| [3] | RDHC | `$F04600` | **`$13` WAIT** |

`$FF15` in every record is the constant at `$F002E8`, the word following the `bsr`, fetched via
`$14(a7)` — a **trace-point identifier**, so different call sites tag their entries differently.

**This independently confirms the documented task lifecycle.** This project records that
"`$01`/`$0F`/`$13`/`$4C` are a common lifecycle every task calls once — `$01` task+stack setup,
`$4C` connect interrupt vector, `$13` the blocking wait". The trace shows exactly that sequence,
in that order, produced by the kernel's own instrumentation rather than by our analysis.

Only four entries appear because `FPS3K_POKE` is gated on boot completion, so the trace catches
only late calls. Ungating it would capture the full boot — at the cost of the diagnostics hang
that gating exists to avoid.

**New diagnostic channel:** `FPS3K_POKE="0C34=8000"` gives a per-task, per-directive system-call
log with parameter-block pointers, straight out of a RAM dump, with no tracing infrastructure of
our own.

### Enabling all eight hooks is safe but adds almost nothing

| `$0C34` | final PC | distinct kernel PCs | % of the 4,351 decoded |
|---|---|---:|---:|
| `$0000` (stock) | `$F00FCC` | 620 | 14.2% |
| `$8000` (trace only) | `$F00FCC` | 669 | 15.4% |
| `$FF00` (all eight) | `$F00FC8` | 672 | 15.4% |

Both instrumented runs boot cleanly to the RTOS idle loop, so **the full mask is safe to enable**.
But bit 15 accounts for essentially the whole gain: the other seven hooks add **3 PCs**. Their
gated paths are diagnostic code for events — faults, aborts, abnormal traps — that a healthy boot
never produces, so switching them on gives nothing to log.

**Two coverage numbers that must not be confused**, and this project has only ever tracked the
first:

- **Decode coverage**: 81.5% of the kernel's bytes are disassembled.
- **Execution coverage**: **14.2%** of decoded kernel instructions ever run in a default boot.

The gap is not a decoding failure. It is a kernel that implements 60 directives of which this
firmware issues five, eight instrumentation hooks of which zero are enabled, and diagnostic paths
for faults that never occur. **Most of the RMS68K kernel is not dormant by accident — it is
generic Motorola code serving an application that uses a small slice of it.**

That also bounds what any future emulator work can achieve here: driving the chassis harder moves
the *application* regions, but the kernel's unexecuted 85% is mostly unreachable without faults,
unused directives, or instrumentation the build ships disabled.

### The trace confirms "RDHC wakes and re-parks", from the firmware's own log

Running the level-7 driven configuration with tracing on (`FPS3K_POKE="0C34=8000"`) gives five
records against four:

```
IO1I   $13 WAIT     a0=$F05D00
RDHC   $01 GTSEG    a0=$F046B0
RDHC   $4C CNCTIRQ  a0=$F04600
RDHC   $13 WAIT     a0=$F04600
RDHC   $13 WAIT     a0=$F04600      <- only in the driven run
```

**The single difference is RDHC issuing a second `WAIT`.** It is woken, does whatever the one
delivered chassis operation asks, and blocks again — which is exactly the "wakes but re-parks"
reading previously inferred from `TCB+$2C` flipping `$4000 → $0018`, now shown by the kernel's own
instrumentation rather than by our reading of a state word.

Equally informative is what is **absent**: no `$29`/`$2A` semaphore operations, no `$12` RESUME.
RDHC's dispatcher work — waking the XP tasks, posting to their queues — never begins. It is not
that RDHC does its job slowly under our chassis model; **it never reaches the part of its job that
would show up as new directive types.**

That makes the syscall trace a sharper progress metric than PC coverage for this question: any
future chassis model that genuinely drives RDHC should produce `$12` RESUME and semaphore
directives in this ring, and their absence is a cleaner failure signal than a coverage percentage.

## The 37-vector handler is a "log and return" stub — and it never fires

`$F00896`, the target of **37 exception vectors** (more than any handler except the 182-vector
panic catch-all), is five instructions:

```
F00896  btst.b  #$e,$c34.w    ; trace enabled?
F0089C  beq.b   $f008a4       ; no -> just return
F0089E  bsr.w   $f01688       ; yes -> log an entry
F008A2  dc.w    $EE14         ; this trace point's identifier
F008A4  rte
```

So **37 exception vectors silently swallow their exceptions** unless kernel tracing is switched on.
Anything landing there is invisible in a stock build — no lamp, no log, no state change.

**Trace-point identifiers are a convention**: `$F002E8` carries `$FF15`, `$F008A2` carries
`$EE14`. The writer fetches the word after the `bsr` via `$14(a7)`, so each site tags its records
distinctly and a populated ring can be read back to source.

### Zero executions is evidence about the emulator, not just the firmware

With `$0C34 = $C000` (bits 14 and 15) the stub executes **0 times** across a full boot. Nothing
reaches any of those 37 vectors.

That is worth stating positively: a model that generated **spurious exceptions** — a real hazard
given how much of this emulator is inferred bit-mapping — would deposit them here, and they would
now be visible. Zero is positive evidence that the model is not manufacturing phantom exceptions,
which no coverage or PC measurement could establish.

**`FPS3K_POKE="0C34=C000"` plus a count of `$F00896` is therefore a spurious-exception detector**,
using the firmware's own instrumentation. It costs one run and needs nothing added to the model.

## The complete `$0C34` instrumentation map — eight identical hooks, self-numbering

All eight hooks are the same five-instruction shape:

```
btst.b #<bit>,$c34.w
beq.b  <skip>
bsr.w  $f01688          ; the trace-ring writer
dc.w   <marker>         ; fetched by the writer via $14(a7)
<skip>:
```

| bit | test site | marker | gates |
|---:|---|---|---|
| 8 | `$F006D8` | `$DD08` | an `rte` path |
| 9 | `$F008FC` | `$EE09` | precedes a full `movem` context save |
| 10 | `$F0059A` | `$FD10` | precedes `bclr #$f,$148(a6)` |
| 11 | `$F00B52` | `$AA11` | |
| 12 | `$F00AB4` | `$AA12` | the TRAP #2-#15 fan-in handler |
| 13 | `$F00F5E` | `$FF13` | precedes `subq.w #$1,$c52.w` |
| 14 | `$F00896` | `$EE14` | the 37-vector exception stub |
| 15 | `$F002DC` | `$FF15` | the supervisor TRAP #1 (ISR-exit) route |

**The marker encodes its own hook number in BCD** — `$DD08`, `$EE09`, `$FD10`, `$AA11`, `$AA12`,
`$FF13`, `$EE14`, `$FF15`: low byte `$08`…`$15` reads as decimal 8…15. **Eight for eight.** So a
populated trace ring identifies which hook produced each record without any external table.

That completes the mask: **eight trace points, one per bit, self-identifying, all disabled in the
shipped build**, feeding a nine-record circular buffer that is consequently always empty.

A note on how this was nearly missed: comparing the marker's low byte to the bit number *as hex*
gives 2/8 and looks like a coincidence in two cases. `$10` is BCD 10, not 16. Same class of base
error as reading `$FF0044` as below `$400000` earlier today — worth flagging twice, because both
produced a confident wrong count that a second glance at the numbers fixed.

### The marker is a two-field encoding, and the ring uses the inline-parameter idiom

The `dc.w` after each `bsr $F01688` is an **inline parameter**, and the writer handles it
properly:

```
F016B6  movea.l $14(a7),a4       ; a4 = the return address, pointing AT the marker
F016BA  move.w  (a4),(a5)        ; copy it into the record
F016BC  addq.l  #$2,$14(a7)      ; advance the return address past it
```

Without that `addq` the `dc.w` would be executed on return — which is exactly why those words
disassemble as nonsense (`addx.b -(a0),-(a6)`, `roxr.b #$7,d4`) in a linear listing. Any
disassembler that does not know this idiom mis-decodes eight sites in the kernel.

**The marker's two halves do different jobs:**

- **low byte, BCD** — the hook number, 8 through 15
- **high byte** — the record format, via `cmpi.w #$efff,(a5)` at `$F016CC`

| marker | format |
|---|---|
| `$DD08`, `$EE09`, `$AA11`, `$AA12`, `$EE14` | ≤ `$EFFF` → **long**: also records `$20(a7)` at `+$08` |
| `$FD10`, `$FF13`, `$FF15` | > `$EFFF` → **short**: skips `+$08` |

So the high bytes are not decorative. Five hooks log an extra caller longword and three do not,
selected by a single magnitude compare on the marker itself.

**Full record layout** (26 bytes):

| offset | content |
|---|---|
| `+$00` | marker — hook number and format |
| `+$02` | caller's SR |
| `+$04` | caller longword |
| `+$08` | second caller longword, **long-format markers only** |
| `+$0C` | `a6` — the TCB |
| `+$10` | `d0` — the directive number on the TRAP #1 hook |
| `+$14` | result of `$F00F96`, a directive `bsr` entry called per record |

That last field is filled on every record from a kernel routine, which is what a timestamp or
sequence number would look like; the routine is directive `$1C`'s handler and is not otherwise
identified here.

## Directive `$1C` is the system clock read — and it explains `$F7000D`

`$F00F98` (TRAP #0 directive `$1C`, 6 callers, one per trace record) is a **race-safe
high-resolution clock read**:

```
F00F9A  movea.l $c4e.w,a0     ; device pointer
F00FA0  clr.b   $c5a.w        ; arm the race guard
F00FA4  movep.w $d(a0),d1     ; MOVEP -- the MC6840 byte-interleaved idiom
F00FAA  lsr.w   #$8,d1
F00FAC  neg.w   d1            ; the PTM counts DOWN
F00FAE  add.w   $c58.w,d1
F00FB2  lsr.w   #$2,d1
F00FB4  add.l   $c42.w,d1     ; + the software tick base
F00FB8  tst.b   $c5a.w        ; did the tick ISR fire mid-read?
F00FBC  bne.b   $f00f9e       ; yes -> read it again
```

Measured at runtime: **`$0C4E` = `$00F70000`**, so `$D(a0)` is **`$F7000D`** — inside the MC6840
PTM. `$0C42` holds the tick base (`$2A80` after a boot) and `$0C58` a counter.

So the kernel composes time from **coarse software ticks plus the live hardware counter**, with a
clear/test/retry guard against the tick ISR firing between the two reads. That is a
high-resolution timestamp, not a tick count.

Three things this connects:

- **`$F7000D` gets a purpose.** It appears in the device map only as a runtime-only address
  reached through `movep`; it is the **timer counter the clock routine samples**.
- **The trace ring's `+$14` field is a timestamp** — established by mechanism rather than by its
  looking like one, which is how it was first described.
- **The PTM period matters for it.** The dual-8-bit fix earlier in this project corrected the
  system tick from 12.73 ms to exactly 10.0000 ms; this routine is the consumer, so that fix
  changes every timestamp the kernel produces, not just the tick rate.

`neg.w` confirms the PTM counts **down**, which is what an MC6840 does and what the emulator must
model for these timestamps to be monotonic.

## The kernel clock is a seqlock, and the PTM tick is the level-4 autovector

Completing the timekeeping picture:

| | |
|---|---|
| **tick ISR** | `$F00EC8`, reached from **vector `$070` (#28) — the level-4 autovector** |
| **tick base** | `$0C42`, a longword advanced by `add.l d1,$c42.w` at `$F00EF2` |
| **race guard** | `$0C5A` bit 7 — `bset #$7` by the ISR at `$F00EDA`, `clr.b` by the reader at `$F00FA0`, `tst.b` at `$F00FB8` |
| **fine counter** | `$0C58`, added to the hardware counter before scaling |

**That is a seqlock.** The reader clears the guard, samples the hardware counter and the tick
base, then checks whether the ISR ran in between — and re-reads if it did. Composing a timestamp
from a software tick and a live down-counter is otherwise racy at exactly the tick boundary, and
this is the standard fix.

Two corroborations:

- **Vector #28 is the level-4 autovector** (autovectors occupy 25-31 for levels 1-7), and the
  emulator already raises the PTM at level 4 (`m68k_set_irq(4)` in `fps3k_sbc.c`). The firmware's
  vector table and the model agree — a choice that was made in the model and is now confirmed from
  the ROM side.
- **`$0C5A` reads `$80` after a boot** — bit 7 set, i.e. the last thing to touch it was the ISR,
  which is exactly the resting state this protocol predicts.

Emulation consequence: a model that delivers the PTM interrupt at any other level, or that lets a
clock read complete without the guard being observable, breaks timestamp monotonicity in a way
that only shows up in the trace ring — which is itself disabled by default, so it would be silent.

## Boot takes 100-120M cycles, and the 7-of-16 wall is not a time limit

Two measurements that bound how every result in this file should be read.

### The boot is 12.5-15 simulated seconds

| cycles | simulated | final PC | where |
|---:|---:|---|---|
| 40M | 5.00 s | `$F09A94` | DRAM tests |
| 80M | 10.00 s | `$F099E6` | DRAM tests |
| 100M | 12.50 s | `$F08956` | self-test |
| **120M** | **15.00 s** | **`$F00FD0`** | **RTOS idle loop** |
| 140M | 17.50 s | `$F00FC2` | idle loop |

**Boot completes between 100M and 120M cycles.** This project runs everything at 150M, which
leaves roughly **35M cycles — about 4 seconds — of post-boot execution**. Every driven-configuration
result here was obtained in that window.

Corroboration from the kernel's own clock: at 40M and 80M cycles `$0C42`, the tick base, still
reads **`$CDEF09AB`** — a self-test pattern, not a time. The RTOS clock is not live until the
diagnostics release that memory, which is a second, independent way to see that boot is
unfinished.

The DRAM tests dominate, which fits the documented refresh test: fill, busy-wait 300,000
iterations (0.675 s), verify.

### More time does not buy more chassis conversation

The obvious hypothesis was that the seven-operation wall is a cycle-budget artefact. It is not:

| cycles | ops dispatched | `$F04930` entries |
|---:|---|---:|
| 150M | 7/16 — `$0`-`$5`, `$F` | 224 |
| **400M** | **7/16 — identical** | **1468** |

**6.5× the interrupt entries, zero additional operations.** The sequence still stops after six
codes. That eliminates time as an explanation and confirms the earlier reading: delivery is
acknowledgement-gated, the SBC stops acknowledging once it parks, and no amount of running
changes that.

Worth noting 1468 is the same count this file records elsewhere for the `$10AA` arm path — it
appears to be a saturation figure for the raise-every-200k-cycles hook rather than anything about
the firmware.

## The XP task service loop, observed: `WAIT` → `SGSEM` → `WAIT`

Driving XP1I's channel with kernel tracing on (`FPS3K_POKE="0C34=8000" FPS3K_XPIRQ=1`) fills the
nine-record ring with one repeating cycle:

```
XP1I  $13 WAIT
XP1I  $13 WAIT
XP1I  $2B SGSEM      <- signal semaphore
XP1I  $13 WAIT
XP1I  $2B SGSEM
XP1I  $13 WAIT
XP1I  $2B SGSEM
XP1I  $13 WAIT
XP1I  $2B SGSEM
```

Every record comes from hook `$15`, the supervisor TRAP #1 route, as expected.

**So each channel interrupt makes the task signal a semaphore and block again.** That is the XP
channel service loop, and it is the first time this project has observed one of these tasks doing
its job rather than inferred it from coverage percentages.

**The contrast with RDHC is the useful part.** Under the same instrumentation RDHC produces one
extra `WAIT` and nothing else — no `SGSEM`, no `RESUME`. So:

| task | driven behaviour |
|---|---|
| **XP1I** | wakes, **signals a semaphore**, re-waits — a working cycle, repeating indefinitely |
| **RDHC** | wakes, re-waits — no semaphore traffic at all |

The XP tasks are functioning correctly in the model; **RDHC is the one that is stuck**, and it is
stuck before reaching any of its dispatcher work. That sharpens a distinction this project has
been carrying as "RDHC 3%, XP tasks 5-6%" — coverage numbers that made all five look equally
blocked when they are not.

`SGSEM` is `$2B`, one of the four semaphore directives, and the XP tasks each declare two
semaphores (`AXP`n and `HXP`n). Which of them is being signalled is not established here — the
trace records the directive and the TCB, not the parameter block contents.

### What triggers the signal: channel status bit 14 set, bit 11 clear

The trace's `+$04` field turns out to be the **caller's PC**, not a parameter block — every SGSEM
record carries `$00F07EAA`, a ROM address inside XP1I. That localises the call site exactly:

```
F07E86  btst.b #$e,$1066    ; channel status bit 14
F07E8E  beq.b  $f07ed8      ; clear -> no signal
F07E90  btst.b #$b,$1066    ; bit 11
F07E98  bne.b  $f07eb6      ; set   -> no signal
F07E9A  move.w #$1,d0
F07E9E  jsr    $f08550
F07EA4  moveq  #$2b,d0      ; SGSEM
F07EA6  lea.l  (a6),a0      ; parameter block = a6 = the TCB itself
F07EA8  trap   #$1          ; <- the traced call
F07EAA  beq.b  $f07eb6      ; the return address the trace recorded
```

So the service loop's condition is **bit 14 set AND bit 11 clear** in `$1066`, the per-channel
status record the ISR fills from `+$0E` of the channel window. This project already records that
the ISR-read word "is then bit-tested for bits 15/14/11" — the trace and the code together now
say what those tests *do*: bits 14 and 11 decide whether the task signals its semaphore.

The parameter block is `a6`, the TCB itself, consistent with each task's semaphore descriptor
living inside its own TCB at `+$138`.

**The caller-PC field makes the trace far more useful than expected.** It is not just "which task
issued which directive" but "from which instruction" — enough to walk straight to the call site and
read its guard conditions, which is how this entry was written.

### Channel validation is two-layered, and the inner layer never fires

Immediately before the SGSEM, XP1I calls `$F08550`:

```
F08550  cmpi.w #$1,d0          ; channel >= 1 ?
F08554  blt.b  $f0855e
F08556  cmp.w  $105e.l,d0      ; channel <= the AC count ?
F0855C  ble.b  $f0856a
F0855E  move.w #$264,d0        ; reject -> panel command $264
F08562  jsr    $f086c0         ; ...through the issuer that ends in bra .
```

Measured across chassis configurations:

| `FPS3K_CHANNELS` | `$F08550` calls | rejects at `$F0855E` | SGSEM records |
|---|---:|---:|---:|
| **2** (Lovett's machine) | 218 | **0** | 4 |
| **0** (empty chassis) | **0** | 0 | 0 |

Two layers, and only the outer one does work:

- **Outer**: each XP task gates itself in its prologue on `cmpi.w #<own channel>,$105E`, so with an
  empty chassis XP1I never reaches the validator at all — 0 calls, not 218 rejects.
- **Inner**: `$F08550` re-checks `1 <= ch <= $105E` before each signal and, on the real 2-AC
  configuration, **never rejects**.

So panel command `$264` is unreachable in a correctly-configured machine. This project records
`$264` as "two per task, one of them `addi.w #$264,d1` with `d1` = the channel, so the family is
`$265`-`$268` for channels 1-4" — consistent, and now with the emitting site and its guard
identified. Note the reject path issues its command through `$F086C0`, one of the eight `bra .`
issuers, so a malformed channel number would **park the XP task permanently** rather than return
an error.

That is a real hazard for any chassis model that reports a channel count inconsistent with the
channels it then drives: the failure is silent and terminal, not a returned status.

## The XP service path, traced end to end — and it stops exactly at the missing counterparty

Following the trace's caller-PC field through XP1I gives the complete cycle:

```
channel IRQ -> ISR fills $1066 with {status, data-hi, data-lo}
  -> task wakes from $13 WAIT
  -> outer gate: prologue cmpi.w #<own channel>,$105E
  -> $F07E86  btst #$e,$1066   AND  btst #$b,$1066     (bit 14 set, bit 11 clear)
  -> $F08550  inner validator, 1 <= ch <= $105E        (never rejects on a 2-AC machine)
  -> $F07EA8  trap #1, d0=$2B  SGSEM                   (signal own semaphore, a0 = the TCB)
  -> $F08572  tst.l $10ae(a2)  <-- THE USER-CONNECT GATE
       nonzero -> $F0857A: build a parameter block, push 'USER', d0=$43 RSTATE, look the task up
       zero    -> $F08608: skip
  -> back to $13 WAIT
```

Measured with XP1I's channel driven:

| site | executions |
|---|---:|
| `$F08572` — the gate test | **218** |
| `$F0857A` — the `USER` lookup | **0** |
| `$F08608` — the skip | **218** |
| `$10AE`, `$10BE` (all four channels) | all `$00000000` |

**The loop completes 218 times and stops at the gate every time.** Not because the path is
unreachable — it is reached on every iteration — but because `$10AE` is zero, and `$10AE` is
nonzero only when a host-loaded CP program has connected itself as the `USER` task.

This is the exact prediction this project recorded when it found the seventh task: *"on a real
machine running a CP program, `$10BE + (ch-1)*4` holds a task handle and `$10AE + (ch-1)*4` is
nonzero. On this ROM alone both stay zero."* **Both stay zero, measured, with the gate reached 218
times.**

So the XP side of the machine is now understood end to end, and the terminus is not a gap in the
analysis or a defect in the model — **it is the architectural boundary**. The ROM is the half that
boots the machine and moves microcode; the other half arrives from the host, and the XP service
loop runs correctly right up to the instruction that would hand off to it.

**That also means the emulator is behaving correctly here.** A model that somehow drove past this
gate would be wrong, not better.

### Forcing the gate proves it is the only blocker — but the aftermath is not attributable

Setting the gate with `FPS3K_POKE="0C34=8000,10AE=0001"` drives XP1I past it for the first time:

| site | before | after |
|---|---:|---:|
| `$F08572` gate test | 218 | 1 |
| `$F0857A` USER path | **0** | **1** |
| `$F0858C` (`moveq #$43`) | 0 | **1** |
| `$F08608` skip | 218 | 0 |

and the trace ring records the directive itself:

```
d0=$43 RSTATE   caller PC=$F08592
```

**So the `$10AE` gate is the sole thing preventing the `USER` handoff** — nothing else in the path
objects, and directive `$43` is issued with `'USER'` exactly as the static reading predicted.

**The run then derails to final PC `$C382008`**, outside ROM and RAM. I am *not* claiming the
firmware mishandles a missing `USER` task. `FPS3K_POKE` forces a location to *read* a constant,
so `$10AE` never behaves like a real longword — anything the handler stores there is not read
back. That is an inconsistent machine state of our making, and it is at least as likely a cause as
any firmware behaviour. Separating the two needs a writable poke, which the hook does not provide.

What is established: **the path is reachable, the gate is the only guard, and `$43 RSTATE` with
`'USER'` is what lies beyond it.**

Incidental find from the same trace: the SGSEM caller PC here is **`$F07E76`**, not the `$F07EAA`
seen earlier — so **XP1I has at least two SGSEM call sites**, and the service loop this file
described is one of several paths to the same directive.

### RESOLVED with a writable poke: the derail is firmware behaviour, not our artifact

The previous entry could not attribute the crash because `FPS3K_POKE` forces a location to *read*
a constant. `FPS3K_POKEONCE` performs a genuine one-time **write** after boot, which removes that
objection. Redone:

```
[POKEONCE] $010AE <- $0001 (one-time write)
$10AE after the run: $00010000     <- the write persisted, behaving like real memory
$10BE after the run: $08434303     <- was $00000000; the handler FILED a result
final PC=C382008
```

So with a properly writable gate the machine **still derails**, and `$10BE` now holds a value the
firmware wrote — exactly the field this project predicted would hold a task handle on a real
machine. `$08434303` is not a plausible handle; it is what a failed lookup returned.

The code explains it:

```
F08592  lea.l   $c(a7),a7        ; drop the parameter block
F08596  movea.l $3c(a7),a3
F0859A  move.l  d0,$10be(a2)     ; file the result -- NO STATUS CHECK
F0859E  move.l  d1,$10ce(a2)
F085AE  move.l  #$0,-(a3)        ; then write zeros through a pointer
F085B4  move.l  #$0,-(a3)
```

**The RSTATE status is never examined.** That is unusual for this firmware: the documented
`$26D`-`$271` pattern is `trap #1` → `cmpi.w #0,d0` → `beq` on success → panel command on failure,
and every other traced directive site follows it. Here `d0` goes straight into `$10BE` and
execution proceeds to pointer writes.

**Conclusion, now supportable:** the firmware assumes the `USER` task exists whenever `$10AE` is
set. It is not defensive about the handoff, because on a real machine nothing sets that gate
except a CP program that has already connected itself. Forcing the gate without the counterparty
is a state the firmware was never written to survive — which is a stronger statement than "it
crashed", and it is only sayable because the writable poke ruled out the alternative.

## The service path replicates across all four XP tasks — with four different XP4I offsets

The bit-14 guard exists once per task, and searching for the instruction rather than assuming the
grid finds all four:

| task | guard site | status address |
|---|---|---|
| XP1I | `$F07E86` | `$1066` |
| XP2I | `$F07486` | `$106C` |
| XP3I | `$F06A86` | `$1072` |
| XP4I | **`$F06088`** | `$1078` |

The status addresses are a perfect **6-byte stride** — `$1066`, `$106C`, `$1072`, `$1078` —
confirming `$1066 + (ch-1)*6` at the same instruction in all four copies, which this project had
derived from the ISR's write side only.

The code addresses are not. XP1I→XP2I and XP2I→XP3I step by exactly `$A00`; **XP3I→XP4I is
`$9FE`**, i.e. XP4I sits `+$2` off the grid at this site.

### XP4I is off-grid by a *different* amount in every field measured

| field | delta |
|---|---:|
| task body (template byte-diff) | `−$1E` |
| `!IDV` ISR entry | `−$18` |
| saved resume PC (`TCB+$0FC`) | `+$6` |
| service-loop guard (this) | `+$2` |

**Four fields, four distinct offsets, all in the same copy.** A relocated or compiler-emitted
fourth instance has one uniform delta by construction; only hand-patching produces four. This is
now the strongest evidence for the "hand-written assembly, not compiled" finding — stronger than
the original `$1E` observation, because a single odd displacement can be explained away and four
mutually inconsistent ones cannot.

Method note: the first three were found by assuming the `$A00` grid, and that assumption *failed*
for XP4I at every offset tried (`0`, `−$18`, `−$1E`, `+$6`). Searching the ROM for the instruction
encoding found it immediately. Grid arithmetic is a hypothesis about this firmware, not a property
of it.

## A systematic per-channel data map for the four XP tasks

Sweeping every `$10xx.l` operand in the four task regions and grouping by owner separates shared
globals from per-channel private state cleanly:

| address | XP1I | XP2I | XP3I | XP4I | |
|---|---:|---:|---:|---:|---|
| `$105E` | 4 | 4 | 4 | 4 | **shared** — the AC-count gate |
| `$1062` | 1 | 1 | 1 | 1 | shared |
| `$1064` | 2 | 2 | 2 | 2 | shared |
| `$107E` | 3 | 3 | 3 | 3 | shared |
| `$1066` / `$106C` / `$1072` / `$1078` | 5 | 5 | 5 | **3** | private — channel status |
| `$1068` / `$106E` / `$1074` / `$107A` | 2 | 2 | 2 | 2 | private — data high |
| `$106A` / `$1070` / `$1076` / `$107C` | 1 | 1 | 1 | 1 | private — data low |

Each task owns exactly **three words on a 6-byte stride** at `$1066 + (ch-1)*6`, referenced by
nobody else, and the four shared globals are referenced an identical number of times by every
task. That is the `{status, data-high, data-low}` record this project derived from the ISR's
write side, now confirmed from the read side in all four copies.

### The one asymmetry is XP4I's status word, and it is exactly the bit-11 difference

XP4I references its status word **3 times against 5**. Counting the guards directly:

| test | XP1I | XP2I | XP3I | XP4I |
|---|---:|---:|---:|---:|
| `btst #$b` (bit 11) | 2 | 2 | 2 | **0** |
| `btst #$f` (bit 15) | 1 | 1 | 1 | 1 |

**5 − 2 = 3.** The missing references are exactly the two bit-11 tests, and this project already
records the behavioural consequence: *"`$C801` sets bit 11, which XP1I/2/3 test to take a short
branch; XP4I (which never tests bit 11) is unaffected"* — measured then from coverage divergence
under `FPS3K_CHCMD`, and now confirmed by a static count that arrives at the same place by
arithmetic.

So XP4I differs from its siblings in **five** measured ways: four inconsistent address offsets and
one genuine behavioural omission. The offsets say it was hand-patched; the missing bit-11 tests say
the patching was not merely mechanical.

### The three shared globals identified

| address | uses per task | what |
|---|---|---|
| `$1062` | 1 — `move.w #$1,$1062` | a flag each task raises; written here, read elsewhere |
| **`$1064`** | 2 — `and.w d2` then `or.w d4` | **the four-nibble per-channel status word** |
| `$107E` | 3 — read, `addq.b #$1`, `clr.b` | a shared byte counter |

`$1064`'s indexing settles it:

```
F0864A  move.w d0,d3      ; channel number
F0864C  subq.w #$1,d3     ; ch-1
F0864E  lsl.w  #$2,d3     ; x4 -> a NIBBLE index
F08650  lsl.w  d3,d4      ; shift this channel's value into its nibble
F08652  and.w  d2,$1064   ; clear the nibble  (d2 = $FFF0 / $FF0F / $F0FF / $0FFF)
F08658  or.w   d4,$1064   ; set the new value
```

**A 16-bit word of four 4-bit fields, one per channel**, updated by a clear-then-set
read-modify-write at `(ch-1)*4`. That confirms the documented scan mask — this project derived
the `$FFF0`/`$FF0F`/`$F0FF`/`$0FFF` constants from the template byte-diff, and here is the
arithmetic that consumes them, with the shift width `lsl.w #$2` proving the 4-bit field size
rather than assuming it.

So the per-channel data area is now fully accounted for: **four shared globals** (`$105E` the AC
count, `$1062` a per-task flag, `$1064` the nibble status word, `$107E` a byte counter) and
**three private words per task** on a 6-byte stride. Every `$10xx` reference in all four XP task
regions falls into one of those seven slots.

### `$1062` is written by every XP task and read by nothing

Sweeping the whole image, not just the task regions:

```
$F06068 [XP4I]  move.w #$4,$1062.l
$F06A66 [XP3I]  move.w #$3,$1062.l
$F07466 [XP2I]  move.w #$2,$1062.l
$F07E66 [XP1I]  move.w #$1,$1062.l
```

Four writes, each task stamping **its own channel number**, and **no read anywhere in the ROM** —
not in RDHC, not in the RTOS, not in the self-test.

That makes `$1062` the exact mirror of `$10AA`, which this project established is *read* by
TCBIO1I and written by nothing the CPU executes. One is inbound, one outbound:

| location | CPU writes | CPU reads | reading |
|---|---|---|---|
| `$10AA` | never | `$F05E12` | a value the **chassis** supplies |
| `$1062` | four sites | **never** | a value the SBC publishes for **something off-board** |

**Inference, not fact:** a write-only global holding "which channel last ran" is what you would
provide for a bus master reading SBC RAM, and this chassis is a bus master. It could equally be
debug residue — a field someone watched with an emulator and never removed. Nothing in the ROM
distinguishes those, and a bus trace would settle it immediately by showing whether anything ever
reads that address.

`$107E` by contrast is entirely internal: read, `addq.b #$1`, `clr.b` in each of the four tasks
and referenced nowhere else in the image. A byte counter shared among the XP tasks only — safe
because the RTOS serialises them, which is worth noting as an assumption the emulator must not
break by running tasks concurrently.

## Sweeping for write-only / read-only RAM: two real channels, three artifact classes

A location the CPU only writes is a candidate for off-board consumption; one it only reads is a
candidate for off-board supply. Classifying every `$0400`-`$1FFF` operand in the application
region by side-of-comma gives **65 distinct globals**, of which 27 look write-only and 2 read-only.

**Most of that is artifact.** Three classes, all found by checking rather than assuming:

| class | example | why it misleads |
|---|---|---|
| **byte within a word** | `$0E87` — 22 `btst` reads, "never written" | written by `move.w d0,$e86.l`, which the matcher records under `$0E86` |
| **read-modify-write with two operands** | `$1064` — `and.w d2,$1064` | reads *and* writes, but the destination sits after the comma so it scores as a write |
| **word read as half of a longword** | `$106A` — written once, "never read" | `$F07E20` does `move.l $1068.l,d1`, which reads `$1068` **and** `$106A` |

That last one is a finding in itself: the task reads its channel data as **one 32-bit longword at
`$1068`**, which is why the low word never appears as a read. It confirms from the consumer side
what this project established from the ISR's write side — that `+$08` and `+$0A` are the halves of
a single 32-bit data register, not two ports.

**What survives verification is exactly two locations:**

| location | direction | evidence |
|---|---|---|
| `$10AA` | **read-only** — the chassis supplies it | 1 read at `$F05E12`, no CPU write anywhere; already documented |
| `$1062` | **write-only** — the SBC publishes it | 4 plain `move.w #imm` writes, one per XP task, no read in the image |

So the sweep found one already-known channel and one new one, and the other 25 candidates
dissolved on inspection. Worth stating the hit rate plainly: **two of four cases I checked by hand
were artifacts**, so this technique produces leads, not conclusions, and every candidate needs its
own look at the instruction.

### Corrected: the sweep must be whole-ROM, and it yields a ninth instrumentation flag

The region-limited sweeps above were wrong in both directions. Run over the kernel alone, **22**
locations look read-only — but `$0C20`, `$0C24`, `$0C28`, `$0C2C`, `$0C30`, `$0C66`, `$0C6A` and
`$0C6E` are the documented RTOS **directory slots**, written by the init code in the *application*
region. That is a fourth artifact class: **cross-region writes**.

Whole-ROM, `$0400`-`$1FFF`, 86 distinct globals, the read-only set collapses from 22 to **five**:

| location | verdict |
|---|---|
| `$10AA` | **genuine** — the chassis supplies it, 1 read at `$F05E12` |
| `$0880` | **genuine candidate** — one read at `$F004FC` (`move.w $880.w,(a1)`), no write anywhere |
| `$0E87` | artifact — low byte of the word written at `$0E86` |
| `$0C40` | artifact — low word of the **longword** at `$0C3E` (`move.l d0,$c3e.w`) |
| `$0C35` | artifact **and a finding** — see below |

### `$0C34` has a ninth flag, in its low byte

`$0C35` is read twice, by `btst.b #$7,$c35.w` at `$F022C0` and `$F022D0`. Since `$0C35` is the low
byte of the word at `$0C34`, that is **bit 7 of the instrumentation word** — a flag outside the
eight hooks documented above, which occupy the high byte (`btst.b #$f,$c34.w` is bit 7 *of that
byte*, since `btst` on memory is byte-sized and the immediate is taken mod 8).

So the mask is **at least nine flags**: eight trace hooks in the high byte, plus one in the low
byte tested at two sites in `$F022xx` — the region containing the connect-interrupt-vector
directive. It is `$0000` in the shipped build like the rest.

**Net effect of doing the sweep properly:** the write-only list drops from 27 to 25, the read-only
list from 22 (kernel) or 2 (application) to 5, and of those only `$10AA` and `$0880` survive as
one-sided. The technique is sound; the region limits were not, and every intermediate number this
sweep produced before being run whole-ROM was wrong.

### Final: exactly two one-sided RAM locations in the entire ROM

`$0880`'s single "read" at `$F004FC` is **not an instruction**. The seeded kernel disassembly
renders `$F004F0`-`$F004F8` as `DC.W`; the surrounding linear decode produces `dc.w $fee0`,
`ori.b #$dc,d0`, `dc.w $fecc` — the signature of data walked as code. That is a **fifth artifact
class: data decoded as code**, which is precisely what `code_map.json` exists to prevent and which
my sweep bypassed by decoding linearly.

So the complete, verified answer:

| location | direction | evidence |
|---|---|---|
| **`$10AA`** | read-only — **the chassis supplies it** | 1 read at `$F05E12`; no CPU write anywhere in the image |
| **`$1062`** | write-only — **the SBC publishes it** | 4 plain `move.w #imm`, one per XP task; no read anywhere |

**Two locations out of 86 RAM globals.** Everything else that looked one-sided was one of five
artifact classes:

1. byte within a word (`$0E87` under `$0E86`)
2. read-modify-write with two operands (`$1064`)
3. word read as half of a longword (`$106A` under `$1068`, `$0C40` under `$0C3E`)
4. cross-region writes (the eight RTOS directory slots)
5. data decoded as code (`$0880`)

The intermediate counts this sweep produced were 27/2, then 22 read-only, then 5, then 2. Each
correction came from checking a specific candidate rather than trusting the aggregate — and the
final number is small enough to state with confidence precisely because every survivor was
examined individually.

For the communications map this settles a question that could otherwise stay open indefinitely:
**there are no undiscovered RAM-mediated channels between the SBC and the chassis.** `$10AA` in,
`$1062` out, and nothing else.

## The instrumentation mask has TEN hooks, and the marker convention predicted the last two

Bit 7 of the `$0C34` word — reached as `btst.b #$7,$c35.w` on the low byte — gates **two** further
trace points, both in the connect-interrupt-vector region and both ending in `rte`:

```
F022C0  btst.b #$7,$c35.w      F022D0  btst.b #$7,$c35.w
F022C6  beq.b  $f022ce         F022D6  beq.b  $f022de
F022C8  bsr.w  $f01688         F022D8  bsr.w  $f01688
F022CC  dc.w   $EE07           F022DC  dc.w   $DD07
F022CE  rte                    F022DE  rte
```

Same five-instruction shape as the other eight. **The markers are `$EE07` and `$DD07` — BCD low
byte `07`, matching the gating bit exactly.** That was a prediction: the convention was derived
from eight hooks numbered 8-15, and it holds on two sites found afterwards by a completely
different route (a read-only RAM sweep), which is the strongest form of confirmation available
without hardware.

**The marker word is now fully decoded across ten sites:**

| field | meaning |
|---|---|
| low byte, BCD | **the gating bit number** — `$08`-`$15` for the eight, `$07` for these two |
| high byte | **distinguishes sites sharing one bit** (`$EE07` vs `$DD07`) **and** selects the record format via the `$EFFF` compare |

So `$0C34` is a **ten-hook** instrumentation mask, not eight: bits 8-15 with one trace point each,
and bit 7 with two. All ten write to the same nine-record ring, all ten self-identify, and all ten
are disabled in the shipped build.

That the high byte does double duty — site discriminator *and* format selector — is why it varies
across `$DD`, `$EE`, `$FD`, `$AA`, `$FF` rather than being constant, which looked arbitrary when
only the low byte's meaning was known.

### Practical use of the trace facility

`FPS3K_POKE="0C34=FF80"` enables all ten hooks. Measured:

| | |
|---|---|
| final PC | `$F00FE6` — the RTOS idle loop, so **enabling everything is safe** |
| ring-writer calls | **1,428** against 4 with bit 15 alone |
| active hooks | 10, 13, 15 |
| bit-7 hooks (`$F022C8`, `$F022D8`) | **0** — see below |

Hook 15 is the supervisor TRAP #1 route and carries the directive numbers (`SGSEM`, `WAIT`).
Hooks 10 (`$F0059A`, before `bclr #$f,$148(a6)`) and 13 (`$F00F5E`, before `subq.w #$1,$c52.w`)
fire frequently with `d0 = 0`, so they sit in hot paths rather than on directive dispatch.

**The two bit-7 hooks never fire**, and the reason is a timing artefact of our own: they live in
the connect-interrupt-vector directive, which each task issues **once during init** — before
`FPS3K_POKE` takes effect, since the poke is gated on boot completion to avoid the diagnostics
hang. Capturing them needs `FPS3K_POKE_FROM_RESET=1`, at the cost of that hang.

**The ring holds nine records and wrapped 158 times** in that run. It is a *sampling* window, not
a log: with all hooks on it shows the last nine events, and reading a full history means dumping
RAM periodically rather than once at the end. With bit 15 alone the volume is low enough that the
nine records are the whole story, which is why the directive traces earlier in this file are
complete and these are not.

## The RTOS "idle loop" is a tick-driven `!PAT` scan

Every boot in this project ends at `$F00FCC`/`$F00FD0`, described throughout as "the RMS68K idle
loop". It is not idle:

```
F00FC2  moveq   #$1,d1
F00FC4  add.w   $c56.w,d1
F00FC8  add.l   $c42.w,d1     ; + the TICK BASE -> a deadline
F00FCC  movea.l $c2c.w,a1     ; directory slot $0C2C
F00FD0  lea.l   $8(a1),a3     ; skip the 8-byte header
F00FD4  movea.l (a3),a2       ; walk the list
```

`$0C2C` reads **`$01F700`** at runtime, and the marker there is **`!PAT`**. So what the machine
does at rest is compute a deadline from the tick base and scan the `!PAT` structure against it —
a timer-driven sweep, not a spin. That also explains hook 13 (`$F00F5E`, `subq.w #$1,$c52.w`)
firing from `$F00FD0`/`$F00FC8`: it is a countdown maintained by this loop.

### Marker census, corrected

Searching the whole 128 KB RAM dump for all twelve tags:

| marker | instances | |
|---|---:|---|
| `!TCB` | 6 | `$1E900` + `$200n` |
| `!TST` | 6 | `$1EA60` + … |
| `!GST` `!IDV` `!IOV` `!PAT` `!UDR` `!UST` | 1 each | `$1FD00`, `$1F800`, `$1F900`, `$1F700`, `$1F600`, `$1FB00` |
| **`!CCB`** | **0** | absent |
| **`!DLY`** | **0** | absent |
| `!ASQ` | 0 | absent *as a tag* — the descriptors are untagged at `TCB+$138`, as documented |
| `!VCT` | 0 | absent *as a tag* — the table at `$1FA00` is untagged, as documented |

This project records *"Only **one** of `!CCB`/`!DLY` has no instance at all."* **Both have none.**
The `!ASQ` and `!VCT` zeros are expected and already explained — those structures exist untagged —
but `!CCB` and `!DLY` have neither a tag nor a documented untagged instance, so on this build the
RTOS creates neither a Channel Control Block nor a Delay record.

### Why the `!PAT` scan looks like idling: the active list is empty

`!PAT` at `$1F700`:

```
+00  '!PAT'
+04  $0001F714     -> a chain of records: $1F714, $1F732, $1F750 ... stride $1E = 30 bytes
+08  $00000000     <- the head the resting loop reads, via lea $8(a1),a3 / movea.l (a3),a2
     $FFFFFFFF     sentinels within the chain
```

**Two lists.** `+4` heads a populated pool of 30-byte records; `+8` heads the *active* list, and it
is **zero**. The resting loop loads `$8(a1)`, gets null, and goes round again — so the sweep this
project has called "the idle loop" is a real timer scan over an **empty work list**, which is why
it behaves like idling and why the machine sits there indefinitely.

That completes the resting-state picture:

| | |
|---|---|
| what the CPU runs at rest | a deadline computation (`$0C56` + tick base `$0C42`) and a `!PAT` active-list walk |
| why it never progresses | the active list head at `!PAT+8` is null — nothing has been queued |
| what would change it | anything that enqueues a `!PAT` record, which on this build nothing does |

So "final PC `$F00FCC`, the RTOS idle loop" — the sentence that ends nearly every measurement in
this project — means specifically: *the machine is scanning an empty pending-work list on a tick
deadline, forever*. The 30-byte pool at `+4` is allocated and never used, in the same way the
nine-record trace ring is allocated and never written.

## RTOS structure liveness: four populated, four header-only

Counting nonzero bytes in the first 256 of each allocated structure after a clean boot:

| structure | base | nonzero | state |
|---|---|---:|---|
| **`!UST`** | `$1FB00` | **101** | live — the semaphore registry |
| **`!IDV`** | `$1F800` | **61** | live — the six `{vector, TCB, ISR entry, ISR exit}` records |
| **`!PAT`** | `$1F700` | **61** | header + record pool; **active list empty** |
| **`!VCT`** | `$1FA00` | **40** | live — `byte[vector] = owning task` |
| `!GST` | `$1FD00` | 10 | header only |
| `!IOV` | `$1F900` | 7 | header only |
| trace ring | `$1F500` | 6 | header only |
| `!UDR` | `$1F600` | 5 | header only |

**I over-generalised last entry.** "Allocate everything, enable nothing" is wrong: half these
structures are genuinely populated, and they are precisely the ones the six tasks need —
semaphores (`!UST`), interrupt wiring (`!IDV`), vector ownership (`!VCT`), and the timer scan list
(`!PAT`). The header-only four correspond to facilities this build does not use: global segments,
I/O vectors, user data records, and the disabled trace ring.

So the correct statement is narrower and more useful: **the RTOS allocates eight structures and
populates the four its workload requires.** That is ordinary behaviour for a generic kernel hosting
a specific application, not a quirk.

For emulation this is the list of state that actually matters. A model that reproduces `!UST`,
`!IDV`, `!VCT` and `!PAT` reproduces everything the six tasks read; the other four can be
allocated and left empty without any observable difference, which is exactly what the firmware
itself does.

## `!UST` decoded: the nine semaphores, with their owners

`!UST` at `$1FB00` is self-describing — its header carries the geometry:

```
+00  '!UST'
+0C  $0016 = 22    record size
+0E  $0009 =  9    record count
+10  $0001FB14     first record
```

Reading the nine 22-byte records:

| # | owner | semaphore | | # | owner | semaphore |
|---:|---|---|---|---:|---|---|
| 0 | XP1I | `AXP1` | | 5 | XP3I | `HXP3` |
| 1 | XP1I | `HXP1` | | 6 | XP4I | `AXP4` |
| 2 | XP2I | `AXP2` | | 7 | XP4I | `HXP4` |
| 3 | XP2I | `HXP2` | | 8 | **IO1I** | **`HIO1`** |
| 4 | XP3I | `AXP3` | | | | |

**Exactly the documented declaration counts — 2/2/2/2/1/0** — with RDHC owning none. Every record
carries identical trailing state (`0001 0002 0000000000 00`), so all nine are in the same
condition after boot.

Record layout: `{owner task name (4), longword, semaphore name (4), state (10)}` = 22 bytes.

**This closes the `HXP0` question.** The ROM contains only the literal `HXP0` — `$F053B6` loads it
and adds the channel number — and here are the resulting `HXP1`-`HXP4` as live registry entries.
Names that exist nowhere in the image exist in RAM, exactly as the runtime-construction finding
predicted, and the registry is where they land.

For emulation: `!UST` is the single most populated RTOS structure (101 nonzero bytes) and is
entirely derivable — nine records, fixed layout, names constructed from a template plus a channel
number, all owners known from the TDTI table.

## RTOS structure headers come in two families

Comparing the first 16 bytes of every allocated structure:

**Family A — `{marker, limit}`**: `+4` holds an address bounding the structure.

| structure | `+4` | |
|---|---|---|
| `!IDV` | `$0001F8FF` | limit; records start at `+8` (`$0045` = vector, then TCB…) |
| `!IOV` | `$0001F9FF` | limit; no records |
| `!PAT` | `$0001F714` | first record of the pool; the **active head is at `+8`** and is null |
| *(untagged pool `$1F500`)* | `$0001F5F2` | limit, with `+0` = `$0001F508` first — the documented first/last header, no marker |

**Family B — `{marker, 0, …, size, count}`**: self-describing.

| structure | `+$0C` | record size | count |
|---|---|---:|---:|
| `!UST` | `$00160009` | **22** | **9** |
| `!GST` | `$000D0000` | **13** | **0** |

`!UST`'s 22 and 9 are confirmed against its nine readable records. **`!GST`'s count is zero** —
no global segments are allocated on this build, which is exactly why it shows only 10 nonzero
bytes and why directive `$01` GTSEG's registry sits empty.

So the family-B header answers "how many and how big" without walking anything, and family A
answers "where does it end". For a model, that means `!UST` and `!GST` can be validated by
arithmetic — record size × count against the populated extent — while `!IDV`, `!IOV` and `!PAT`
need their chains walked.

Two details worth keeping: `!UDR`'s `+4` is `$00190000`, whose high word is `$0019` = 25, most
likely a record size in the family-B position but with no count beside it; and the `$1F500` trace
pool is the only allocation with **no marker at all**, which is why it appears in the directory
(slot `$0C30`) but not in any marker census.

## `!IDV` read in full, and a refinement to the XP4I tally

All six records, stride 14, from `$1F808`:

| vector | TCB | task | ISR entry | ISR exit |
|---|---|---|---|---|
| `$45` | `$1E900` | XP1I | `$F07EE6` | `$F07F08` |
| `$46` | `$1EB00` | XP2I | `$F074E6` | `$F07508` |
| `$47` | `$1ED00` | XP3I | `$F06AE6` | `$F06B08` |
| `$48` | `$1EF00` | XP4I | `$F060CE` | `$F060F0` |
| `$4A` | `$1F100` | IO1I | `$F05DD6` | `$F05E4C` |
| `$41` | `$1F300` | RDHC | `$F04930` | `$F050FC` |

Exactly the documented BIM vector assignments, now read from the structure the kernel actually
uses rather than from the CR/VR writes that establish them.

**Refinement to my own claim.** I reported "four fields, four distinct offsets" for XP4I. With the
exit column read, it is **five fields and four distinct values** — entry and exit both shift by
`−$18`, which they must, being two points in the same ISR:

| field | offset |
|---|---:|
| task body | `−$1E` |
| `!IDV` ISR entry | `−$18` |
| `!IDV` ISR exit | `−$18` |
| saved resume PC | `+$6` |
| service-loop guard | `+$2` |

The conclusion is unchanged and slightly better supported: **four mutually inconsistent offsets
across five fields**, where a relocated or compiled copy would show one. But "four fields, four
offsets" overstated the independence of the measurements, since two of them were never going to
disagree.

## `!VCT` read out, with two corrections

The vector-ownership table at `$1FA00`, one byte per exception vector:

| vector | byte | owner |
|---|---|---|
| `$41` | 6 | RDHC |
| `$45` `$46` `$47` `$48` | 1 2 3 4 | XP1I-XP4I |
| `$4A` | 5 | IO1I |
| `$42` `$43` `$44` `$49` | 0 | the four orphan BIM vectors, unowned |

All exactly as documented. Two things are not:

**1. My own misreading.** Index `$2D` holds `$BF`, which I first read as "task 191". It is not a
task number — tasks run 1-6. `$BF` is **`$FF` with bit 6 cleared**, sitting in a run of `$FF`
bytes:

```
+20  ff ff ff ff ff ff ff ff ff ff ff ff ff bf ff ff
```

So it is an *unowned* entry carrying a flag, not an owned one. Vector `$2D` is 45 = **TRAP #13**,
whose runtime vector reads `$00F00A8E` — a rung of the `bsr` fan-in ladder found earlier today.
What clears bit 6 there, and why only for that one trap, is not established.

**2. The `$FF` prefix is longer than recorded.** This project describes the table as built with
*"ten `$FF` bytes for vectors 0-9, then one byte per vector"*. Measured, the `$FF` run extends to
index **`$2F`** — 48 bytes — and `$30`-`$3F` are `$00`, with the task numbers only from `$40` on.
So `$FF` is what an *unowned* entry reads in the low region and `$00` is what it reads from `$30`
up, which the "ten bytes" description does not capture.

Worth flagging that the anomaly was found only because I dumped the whole table rather than the
six entries the documentation lists. Reading a structure to confirm what is expected finds
nothing; reading all of it found a flagged entry nobody had noticed.

### Correcting my correction: the "ten `$FF` bytes" description was right

I wrote above that this project's description of `!VCT` — *"ten `$FF` bytes for vectors 0-9, then
one byte per vector"* — understated the `$FF` run, which measures 48 bytes. **The description was
accurate and my objection was not.** Reading the builder:

```
F09F0E  moveq  #$1,d2
F09F10  bsr.w  MemoryClear      ; zero the page
F09F14  moveq  #$ff,d2          ; sign-extends to $FFFFFFFF
F09F16  move.l d2,(a0)+         ; 4
F09F18  move.l d2,(a0)+         ; 4
F09F1A  move.w d2,(a0)+         ; 2  -> exactly TEN bytes of $FF
```

Ten, as stated. The `$FF` values at indices 10-47 come from the **per-vector loop that follows**,
which evidently writes `$FF` for vectors with no owner. Two mechanisms, one observed run — I saw
the run, assumed one mechanism, and contradicted a description that was describing the other.

That also reframes `$BF` at index `$2D`. It is not `$FF` with a bit cleared after the fact: **no
`bclr #$6` anywhere in the ROM targets this table** — all 24 bit-6 operations act on TCB flag
bytes (`$29`/`$2D` displacements) or self-test board registers (`$1(a5)`). So `$BF` is a value the
fill loop *wrote*, meaning vector 45 — TRAP #13 — is classified differently from its neighbours by
whatever that loop computes. Still unexplained, but now known to be deliberate rather than
residual.

The `!VCT` base is confirmed: slot `$0C66` reads `$0001FA00` at runtime, so the indexing above is
sound.

### What `!VCT` actually encodes

Measured across all 246 vectors above 9:

| tag | meaning | count |
|---|---|---:|
| `$00` | the vector is on a **default** handler — either `$F00896` (log-and-return) or `$F0A27A` (panic catch-all) | 216 |
| `$FF` | the vector has a **distinct** handler of its own | 23 |
| `1`-`6` | **owned** by that task, written later by directive `$4C` | 6 |
| `$BF` | vector `$2D` (TRAP #13) only | 1 |

The fill loop at `$F09F1C` writes `$FF` where a vector differs from the value in `a4` and leaves
`$00` where it matches:

```
F09F1C  lea.l  $28.w,a2        ; from vector 10
F09F22  cmpa.l (a2)+,a4
F09F24  beq.b  skip            ; matches -> leave $00
F09F26  move.b d2,(a0)         ; differs -> $FF
F09F2C  cmpa.l #$400,a2        ; to vector 255
```

**I guessed `a4` twice and was wrong twice** — first the catch-all, then the log-and-return stub.
The data shows vectors on *either* default handler carry `$00`, so a single comparison against one
address cannot produce the observed table. Either the loop runs more than once, or `a4` is
reloaded; I decoded one pass and should not have inferred the whole mechanism from it.

What the **table** encodes is nevertheless settled by the data itself, independent of how it is
built: **default handler → `$00`, own handler → `$FF`, owned by a task → 1-6.**

That leaves `$BF` at vector `$2D` as the single exception in 246 entries — TRAP #13, handler
`$F00A8E`, a rung of the `bsr` fan-in ladder. Precisely isolated, still unexplained, and now known
not to come from a `bclr` (none targets this table) nor from the one fill pass decoded here.

## RESOLVED by measurement: `$BF` comes from `bclr #$6,$2d(a6)` with `a6` = the `!VCT` base

Two inferences failed on this; one watchpoint settled it. `FPS3K_RAMWATCH=1FA2D` gives the write
history of that byte, and the last two writes are:

```
$1FA2D <- FF from PC=$F09F26     the fill loop, as expected
$1FA2D <- BF from PC=$F012E6     the final write
```

`$F012E6` is `bclr.b #$6,$2d(a6)` — **which was in my earlier list of all 24 bit-6 operations, and
I dismissed it**, having written that "all 24 act on TCB flag bytes or self-test board registers".
That was an assumption about `a6`, not an observation. Here `a6` holds `$1FA00`, so `$2d(a6)` is
`!VCT[$2D]` and the instruction clears bit 6 of TRAP #13's ownership byte.

**Two of my own claims fall:**

1. *"No `bclr #$6` anywhere in the ROM targets this table."* One does. The instruction is
   base-register-relative and I classified it by guessing the base.
2. **The usage-derived TCB field map is an upper bound, not a census.** It counted every
   `$xx(a6)` displacement as a TCB field, and at least one `+$2D` access is an `!VCT` access. The
   map's shapes were corroborated independently for `+$26`, `+$2C` and `+$102`, so its conclusions
   stand — but its *counts* include accesses to whatever else `a6` happens to point at.

This is the hazard this project documents for devices — *"devices are addressed ONLY through base
registers; absolute-address scanning misses essentially every access"* — appearing in the mirror.
I applied the lesson to device addresses and not to RAM structures, where the same instruction
reaches different objects depending on a register loaded elsewhere.

What clearing bit 6 of TRAP #13's `!VCT` byte *means* is still open. But it is now a question about
one identified instruction in one identified routine, rather than about an anomalous byte.

### The `+$2C` identification verified by watchpoint

Having found that the `$xx(a6)` field map counts are an upper bound, the fields it *names* deserve
a direct test. Watching RDHC's state word at `$1F32C` over a full boot gives its complete write
history, and every non-diagnostic writer is a routine already identified here:

| PC | value | what |
|---|---|---|
| `$F098FC`, `$F09944`, `$F099BC`, `$F09A6E`, `$F09A92`, `$F08A50` | patterns | self-test RAM walks |
| `$F0A3A8` | `00` | bulk clear |
| `$F02966` | `80` | the `move.b #$80,$2c(a5)` from the four-writes census |
| `$F0A0B2` | `00` | task creation — `move.w d2,$2c(a5)` after `T0CRTCB` |
| **`$F02C3E`** | **`40`** | **directive `$13` WAIT — `bset #$e`** |

The final write is `$40` in the high byte, i.e. `$4000` in the word — bit 14, WAITING — from the
routine identified as `WAIT` by the directive table. **Measured, not inferred**, and it closes the
loop on three separate claims at once: that `$F02C3E` is `WAIT`, that bit 14 is the waiting flag,
and that `+$2C` is the state word.

So the field map's *identifications* survive the base-register caveat even though its *counts* do
not. That distinction is worth preserving: a displacement census tells you which offsets are
touched and roughly how, and a watchpoint tells you by what and to what effect. The first is cheap
and approximate, the second exact and narrow, and today the second corrected the first twice.

## RESOLVED: `!VCT[$2D]` is allocator collateral, not a vector tag

`$F012E6`, the `bclr #$6,$2d(a6)` that writes `$BF`, sits at `$F012A6` — a fall-through block with
no callers. Execution counts settle what it belongs to:

| site | executions |
|---|---:|
| `$F01240` — **T0PAGAL**, the TRAP entry | **20** |
| `$F0123E` — its `bsr` entry | 12 |
| `$F012A6` — the block containing the `bclr` | **20** |
| `$F012E6` — the `bclr` itself | **20** |

**Identical to T0PAGAL's count**, so the block is part of the page allocator and the `bclr` runs
**once per allocation**. `a6` there is the structure the allocator is working with, and on one of
those twenty calls it held `$1FA00`.

So `$BF` at `!VCT[$2D]` is **not a vector-ownership value at all** — it is the page allocator
clearing bit 6 at offset `$2D` of a structure that happens to be the `!VCT` page. The byte is
collateral, and anyone reading `!VCT` should skip it rather than interpret it. That is why no
encoding made sense of it: it isn't in the encoding.

**And the count confirms the allocator independently.** This project records *"twenty allocations
tile `$1DD00`-`$1FDFF` with no gaps"*, derived from the heap layout. T0PAGAL executes **exactly
twenty times** in a boot — the same number reached from execution rather than from the address
map, which is a stronger check on the allocation census than either alone.

The 12-vs-20 split between `$F0123E` and `$F01240` is the dual-entry convention in use once more:
twelve of the twenty allocations come from internal `bsr` callers pushing SR themselves, eight
from the TRAP path.

### The allocator does not stamp every block — and that sharpens the `$BF` story

I supposed the `bclr #$6,$2d(a6)` might stamp every allocated page. Checking `+$2D` across all
allocations refutes it:

| structure | `+$2D` | bit 6 |
|---|---|---|
| `!IDV` | `$E6` | **set** |
| `!UST` | `$49` | **set** |
| `!VCT` | `$BF` | clear |
| `!UDR` `!PAT` `!IOV` `!GST`, the pool, all six TCBs | `$00` | clear |

`!IDV` and `!UST` carry **record content** at that offset with bit 6 **set**, so the `bclr` plainly
did not run against them. The twenty executions therefore act on a **varying `a6`**, not on every
block handed out.

What survives, and it is enough:

- The `bclr` executes 20 times, in lockstep with T0PAGAL.
- **One** of those executions targeted `$1FA2D`, measured by watchpoint.
- On a freshly zeroed block, clearing a bit of `$00` leaves `$00` — **invisible**. The write is
  observable at `!VCT` only because that byte had already been filled with `$FF`.

So `!VCT[$2D]` reads `$BF` because a page-allocator operation with `a6` pointing at the `!VCT`
page cleared bit 6 of a byte the fill loop had already set to `$FF`. Not a vector tag, not a
uniform stamp, and visible only by coincidence of ordering — which is why it looked anomalous in a
table where every other byte means something.

## Testing "the XP tasks work, RDHC is stuck" against all four channels

That claim was made from XP1I alone. Driving each channel in turn with tracing on:

| driven | SGSEM | WAIT | tasks appearing in the ring |
|---|---:|---:|---|
| XP1I | 4 | 5 | XP1I |
| XP2I | 4 | 5 | XP2I |
| XP3I | 4 | 5 | XP3I |
| **XP4I** | **3** | **4** | XP4I, **plus leftover IO1I and RDHC boot records** |

**The claim holds** — all four tasks signal semaphores and re-wait, so none of them is stuck in the
way RDHC is. XP1I, XP2I and XP3I are indistinguishable: 4 + 5 = 9 events, exactly filling and
wrapping the nine-record ring.

**XP4I produces measurably less.** Its 3 + 4 = 7 events leave two boot-time records unoverwritten,
which is why IO1I and RDHC still appear. Fewer service events in the same 150 M cycles.

That is a **sixth** measured XP4I difference, and the first observed in *behaviour under load*
rather than in addresses or static counts. It also corroborates the static finding from the
execution side: XP4I lacks the two `btst #$b` (bit 11) tests its siblings have, so it takes fewer
branches through the service path, and it duly generates fewer events.

Static reference counts and runtime event counts now agree that XP4I is not merely relocated but
functionally trimmed. Worth noting the test was run because a claim built on one task should be
checked against the other three — and the check both confirmed the claim and found something the
original measurement could not have shown.

## Auto-increment confirmed: the write port is a streaming channel

The `addq.l #$1,$e58` at `$F04E30`, gated on bit 4 of the command byte, was read from the
disassembly and never measured. Driving op `$3` with and without that bit:

| response code | bit 4 | distinct chassis addresses written |
|---|---|---:|
| `$03` | clear | **4** — `$400000`-`$400003`, rewritten every time |
| `$13` | set | **876** — `$400000`, `$400004`, `$400008`, … |

**876 = 219 × 4.** The 219 executions of `$F04E0A` measured earlier, four bytes each, landing on
consecutive longword addresses. The two measurements were taken for different reasons and the
arithmetic closes exactly.

So op `$3` with bit 4 is a **streaming write channel**: the chassis presents a code and a data
half through `CHANNEL_SELECT`, the SBC assembles 32 bits, stores them through the `$FF0210`-paged
`$400000` window, and advances the transfer address by one word — repeatedly, without further
address setup. That is a DMA-shaped path in software, and it is the mechanism by which bulk data
reaches System Common Memory.

The full op-`$3` picture, now entirely measured rather than decoded:

| aspect | how established |
|---|---|
| bidirectional, bit 5 selects | decoded, then both paths executed |
| 32-bit stores | four byte-writes per instruction in the bus log |
| bit 4 auto-increments | **876 vs 4 distinct addresses** |
| paged via `$FF0210` | `page = addr >> 20` in the decode |
| 219 stores in one run | PC count, cross-checked by 876/4 |

## Op `$3` has THREE sub-paths, and bit 6 means different things per direction

Driving every combination of bits 5 and 6, with the op entry `$F04D4E` dispatching 219 times in
all four:

| code | bit 5 | bit 6 | path | site |
|---|---|---|---|---|
| `$03` | 0 | 0 | **write** chassis memory | `$F04E0A` ×219 |
| `$23` | 1 | 0 | **alternate read** | `$F04DB2` ×219 |
| `$63` | 1 | 1 | **paged chassis-memory read** | `$F04D96` ×219 |
| `$73` | 1 | 1 | identical to `$63` | `$F04D96` ×219 |

So the command byte's bit 6 is **not** a single "half select" as this file previously described.
Its meaning depends on the direction bit:

| bit 5 | bit 6 | effect |
|---|---|---|
| 0 (write) | selects which **16-bit half** of the 32-bit datum `CHANNEL_SELECT` supplies (`$F04DCA` vs `$F04DD6`) |
| 1 (read) | selects **which read**: `$F04DB2` when clear, the paged `$400000` read at `$F04D96` when set |

Bit 4 does not affect the branch — `$63` and `$73` are identical in path — consistent with it
being purely the address auto-increment measured earlier.

**A correction I nearly missed.** My first attempt at this probed `$F04D74` and found 0 executions
for both `$23` and `$33`, which looked like "the read path never runs". `$F04D74` sits *inside* the
bit-6-set branch, so a code without bit 6 legitimately never reaches it. The probe was wrong, not
the firmware — and the 16,388 "addresses read" in that run were the self-test's SCM sweep, nothing
to do with op `$3`.

Full command-byte semantics for op `$3`, every bit now measured:

```
bits 0-3  operation (3)
bit 4     auto-increment the transfer address
bit 5     0 = write chassis memory, 1 = read
bit 6     write: which 16-bit half     read: which of two read forms
```

## Bit 5 is a consistent direction bit — confirmed by execution on op `$6` too

The harness carries a check that *"op `$26` = op `$6` with the read bit set"*, asserted purely as
arithmetic: `(0x26 & 0x0F) == 0x6 and (0x26 & 0x20)`. True by construction, and it says nothing
about what the firmware does. Now measured:

| code | bit 5 | read path `$F04EB8` | write path `$F04EC0` |
|---|---|---:|---:|
| `$06` | 0 | **0** | **219** |
| `$26` | 1 | **219** | **0** |

Perfect complementary split. Op `$6`'s shared body at `$F04EA0` tests `btst #$5,$e87` and branches:
read does `move.w (a1),$e74` — SBC RAM into the result register — while write takes `$F04EC0`.

So **bit 5 is the direction bit for op `$6` as well as op `$3`**, which makes it a property of the
command byte rather than of one operation. Combined with bit 4's auto-increment and bit 6's
per-direction meaning, the command byte's upper bits are now measured across two independent
operations.

### The same probe mistake, twice

Both attempts to test a direction bit initially used a site the firmware reaches **before** the
branch — `$F04D74` for op `$3`, `$F04F30` for op `$6` — and both produced identical counts for
codes that differ, which reads as "the bit has no effect". It does; the probe simply could not see
it.

The rule that fixes it: **instrument after the branch, not before.** A site both paths reach cannot
distinguish them, and a null result from such a site is evidence about the probe rather than about
the firmware. That is the third distinct form this session of the same underlying error — measuring
something that cannot answer the question asked, then reading the answer as informative.

## Auditing the harness for checks that cannot fail

Three classes of unfalsifiable check surfaced today: three softened with `or True`, one arithmetic
identity standing in for behaviour (`(0x26 & 0x0F) == 0x6`), and the `$600` byte-pattern
assertions I misread as runtime evidence. That warranted an audit rather than more spot fixes.

Scanning all **714** checks for conditions containing **no identifiers** — pure literal arithmetic,
which is exactly the shape of the `$26` identity — finds **two**, and both are
`except FileNotFoundError: check(..., False)`: deliberate failure paths for a missing file, not
tautologies.

**So no always-true check of that form remains.** The three `or True` cases were repaired this
morning and the identity was replaced with an executed test this afternoon.

Two limits on what the audit proves, worth stating so it is not over-trusted:

- It catches only **literal-only** conditions. Something like `len(x) >= 0` has identifiers and
  passes the scan while still being unfalsifiable.
- It says nothing about checks that *can* fail but do not test what their message claims — the
  `$600` case. Those assert real bytes; the defect is that the message describes runtime behaviour
  the assertion never touches. No automated scan finds that; it needs the message read against
  the condition.

Reusable form: `grep -n "or True" tools/verify_findings.py` should match only comments, and the
literal-only scan above should return only the `FileNotFoundError` guards.

## The two dispatchers are structurally asymmetric

`$F04930` picks between them on bit 7 of the command byte, and they are built differently:

**Bit 7 clear — `$F04A6E`:** `(code & $F) << 2` into a **16-entry jump table** at `$F05102`. One
operation per code, each a distinct handler. This is the path every measurement in this file has
used.

**Bit 7 set — `$F0495C`:** not a table at all. A **validator feeding one handler**:

```
F04962  andi.w #$1f,d0        ; 5-bit code, 0-31
F0496E  cmpi.w #$14,d0 / bgt  ; above $14 -> reject
F04976  cmpi.w #$14,d0 / beq  ; $14 itself -> absorbed, straight to the ISR exit stub
F0497E  btst.b #$6,$e87       ; bit 6 set AND code $10 -> reject
                              ; everything else -> $F04992
```

and `$F04992` computes an index rather than dispatching:

```
F04992  cmpi.w #$13,d0 / beq  ; code $13 -> result register = 0, exit
F049A8  lsl.w  #$2,d0         ; index = code * 4
F049AA  cmpi.w #$3c,d0 / ble
F049B0  subq.w #$2,d0         ; codes above $F are shifted by -2 -- a GAP in the table
F049B2  btst.b #$6,$e87       ; then bit 6, then bit 5
```

So the read-back path accepts **21 codes (`$00`-`$14`)**, indexes an array by `code * 4` with a
two-byte discontinuity above code `$F`, and honours **the same bits 5 and 6** the operation path
uses for direction and half-select. The command byte's upper bits mean the same thing on both
sides; only the low nibble's interpretation changes.

Two details this explains:

- **`$14` is absorbed by the dispatcher itself.** This file records that `$14` "means two different
  things — to RDHC's main loop a command record is waiting, to this dispatcher acknowledge and
  return". `$F04976` is that instruction, and it is why a stream of `$14`s yields exactly one
  command.
- **The `subq.w #$2` implies the collected array is not uniform.** Entries below code `$10` are
  four bytes apart and the run above starts two bytes earlier than `code * 4` would place it,
  which is the signature of a longword array preceded by a word-sized field.

### The `$14` absorption, measured

Driving the bit-7 collect path with four codes:

| response | code | validator `$F0495C` | handler `$F04992` | `$E74` writes |
|---|---|---:|---:|---:|
| `$80` | `$00` | 219 | **219** | 487 |
| `$8B` | `$0B` | 219 | **219** | 487 |
| `$93` | `$13` | 219 | **219** | 487 |
| **`$94`** | **`$14`** | 219 | **0** | **51** |

All four reach the validator equally — delivery is identical — but **code `$14` alone never
reaches the handler**, and the result register is touched 51 times instead of 487.

That is `$F0497A`'s `beq.w $f050f8` executing: the dispatcher recognises `$14` and branches
straight to the ISR exit stub. This project records the consequence — *"a stream of `$14`s yields
exactly one command"* — and here is the mechanism running, with the counts to distinguish it from
the other twenty codes.

`$E74` is written roughly twice per handler invocation (487 ≈ 219 × 2 + boot writes), consistent
with the handler assembling a 32-bit result from two halves under bit 6, the same way the
operation path does.

Note `FPS3K_RESP=0x94` is the value this project uses throughout for driving RDHC — and it is the
one code in the collect range that the dispatcher throws away. That is not a contradiction: `$94`
was chosen because it wakes RDHC via the ISR entry, and the absorption is precisely why it
produces one wake rather than a stream.
