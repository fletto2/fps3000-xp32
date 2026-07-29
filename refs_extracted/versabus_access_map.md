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

This matters because **the levels are written by this ROM, not set by
straps**. It is not a board-wiring question that a bench session could
resolve: as programmed, a panel command issued from inside the host-link ISR
cannot be completed.

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
clear, so they cannot fire, and a vector installed at the BIM for a source
that can never assert is harmless. But it is worth knowing before a bring-up
attempt: if any of those four channels *does* interrupt, on real hardware it
dispatches through a DRAM vector the RTOS never wrote, which on a
power-on-random board is a jump to a garbage address.

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
