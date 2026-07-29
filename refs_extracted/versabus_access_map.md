# VersaBus access map — what the SBC firmware actually reads and writes

Every off-board access the FPS-3000 SBC firmware makes: address, direction,
width, values, and the code that does it.

Built 2026-07-28 from three independent sources, cross-checked against each
other:

1. **Static** — every memory-reference instruction in `fps3k_clean.asm`
   whose operand resolves into VersaBus space, with its PC and enclosing
   function. Catches code that never runs.
2. **Dynamic** — the emulator's bus logger (`-bus`) over a full boot to the
   RMS68K idle loop, plus a host S-record transfer. Ground truth for what
   executes, with observed values.
3. **RAM dump** — `-dump-ram` after boot, used to resolve interrupt vector
   numbers to their installed handlers.

Where static and dynamic disagree, the disagreement is itself recorded —
it marks code paths the boot never reaches.

---

## The one-line summary

The SBC drives **three** off-board windows, and **every data access to
them is a 16-bit word**. There is not a single byte-wide or long-wide
data access anywhere in `$FF0000-$FF025F`. The only non-word off-board
access in the firmware is a 32-bit read of the mailbox at `$70001C`.

| Window | Range | What it is |
|---|---|---|
| AP I/F | `$FF0000-$FF00FF` | host interface: command register + four 32-byte channel windows |
| XLTR control | `$FF0200-$FF021B` | mode/select/data/status/IRQ-mask register file |
| XLTR interrupt | `$FF0230-$FF025F` | **three Motorola-style BIMs** — see below |
| Mailbox | `$70001C` | 32-bit read, host-attention flag |

On-board peripherals (`$F70001-$F7001A` PTM / SIO / board status and
`$01FFF0` VMOD control) are *not* VersaBus and are excluded here; see
`M68KVM02_memory_map.md`.

---

## 1. The three BIMs at `$FF0230-$FF025F` — new finding

The card list calls the XLTR **"V-BUS XLTR 3 BIMS"** (612-4803-400-G).
That is literal: the block at `$FF0230` is **three Bus Interface Modules**,
Motorola MC68153-style, each with four interrupt channels laid out as

```
   CR0 = base+$0   CR1 = base+$2   CR2 = base+$4   CR3 = base+$6
   VR0 = base+$8   VR1 = base+$A   VR2 = base+$C   VR3 = base+$E
```

with BIM0 at `$FF0230`, BIM1 at `$FF0240`, BIM2 at `$FF0250`. Control
register `n` always pairs with vector register `n` at **+8**.

`RTOSKernelInit` (F0A164-F0A1CA) zeroes the control registers, then loads
the vector registers with the **sequential interrupt vector numbers
`$41`–`$4A`**. Each task later enables its own channel by writing `$5F`
to its control register (BIM0 ch0 is the exception, `$5E`). Resolving each vector number against the
post-boot vector table proves the chain end to end:

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

Every channel whose control register is enabled (`$5E`/`$5F`) has a real
handler. Every channel left at `$00` points at the generic handler or the
panic catch-all. The correspondence is exact, which is what makes this
an identification rather than a guess.

Each task writes its own control register and owns the ISR 8 bytes above
it — e.g. `TCBIO1I` writes `$5F` to `$FF0254` at F05DB8 and its ISR sits
on vector `$4A` from `$FF025C`.

### Consequences

- **`$FF025C` is where the host-link interrupt vector comes from.**
  `$4A` = 74; 74 × 4 = `$128`; `$128` holds `F05DD6`, the TCBIO1I ISR.
  That is the same vector `host_sim` gates on, arrived at from a
  completely different direction.
- **The host interrupt is *vectored*, not autovectored.** Docs that say
  "level 5 autovectored through vector `$128`" describe the effect but
  not the mechanism: the BIM supplies the vector number.
- **The registers we call `XLTR_CH{1..4}_CONFIG` are BIM control
  registers**, and `$5F` is a BIM control value, not a channel config
  word. There is a **fifth** one — `$FF0254`, owned by TCBIO1I — which no
  existing doc lists.
- Two channels are wired but unused (`$FF0240`/`$FF0248`,
  `$FF0256`/`$FF025E`), and BIM0 has one enabled channel, vector `$41` →
  `F04930`, whose role is not yet identified.

### Confirmed against the MC68153 datasheet (2026-07-28)

`refs/MC68153L.pdf` has no text layer, so it was read by rendering the
pages. Three statements from it close the identification:

- *"The MC68153 can be used with many system buses, however, it is
  primarily intended for VMEbus, **VERSAbus** and MC68000 applications"*
  — right bus, right CPU.
- *"**All eight BIM registers** can be accessed from the system bus …
  the internal registers are selected by **A1, A2, and A3**"* — eight
  registers selected by A1-A3, i.e. **2-byte spacing**, exactly the
  layout derived from the firmware's writes.
- *"Each input is regulated by **Bit 4 (IRE)** … (**CR0 controls INT0,
  CR1 controls INT1**, etc.) … The asserted IRQX output is selected by
  the value programmed in **Bits 0, 1, and 2 of the control register
  (L0, L1, L2). This 3-bit field determines the interrupt request
  level** … **If the interrupt request level is set to zero, the
  interrupt is disabled** because there is no corresponding IRQ output."*

That last sentence decodes our observed values exactly:

| CR value | bits 2-0 (level) | bit 4 (IRE) | meaning |
|---|---|---|---|
| `$5F` | `111` = **7** | 1 | enabled, requests **IRQ level 7** |
| `$5E` | `110` = **6** | 1 | enabled, requests **IRQ level 6** |
| `$00` | `000` = **0** | 0 | **disabled** — no IRQ output exists at level 0 |

`level 0 = disabled` independently explains why every channel we observed
at `$00` points at the generic handler or the panic catch-all: those
channels cannot raise an interrupt at all. The CR_n ↔ INT_n pairing in
the datasheet confirms the control/vector channel mapping.

### The interrupt level: our emulator is wrong

This resolves the open question, and not in our favour. The host link
(TCBIO1I, `CR = $FF0254 = $5F`) requests **IRQ level 7** — not level 5.
All five task channels are `$5F`, so they all request level 7 and are
distinguished by vector, which is exactly the case the datasheet
describes: *"Two or more interrupt sources can be programmed to the same
request level"*, resolved by the IACKIN*/IACKOUT* daisy chain. BIM0 ch0
(`$5E`) sits alone at level 6.

Our emulator raises **level 5** and hard-codes `return 0x4A` as the
vector in `m68k_irq_callback` (`emulator/fps3k_sbc.c`). Both halves are
wrong: the level should be 7, and the vector should come from the
modelled BIM vector register during the IACK cycle rather than a
constant. The datasheet's Figure 6 flow is explicit — the interrupter
"places vector byte on data bus" and the handler "reads vector" — which
is precisely the mechanism to model.

This also explains a loose end: autovector 7 (`$07C`) is never
installed (`00000000`), which would be reckless if level 7 were
autovectored. It is not — the BIM supplies vector `$4A`, so the
level-7 autovector is genuinely unused.

**A note on how this was settled.** An LLM reviewer asserted with HIGH
confidence that the level lives in bits 6-4, which would have made both
`$5E` and `$5F` level 5 and dissolved the conflict. The datasheet says
bits 0-2. The claim was specific, plausible, and wrong — and had it been
accepted, it would have "confirmed" the emulator's incorrect level.

### Remaining caveat

**The register *structure* is empirical; the *chip* is inferred.** The
CR/VR layout above is derived from what the firmware writes and from the
+8 CR→VR pairing holding for all five enabled channels — that stands on
its own evidence. Calling the part an MC68153 rests on the card
description "3 BIMS" plus the fit, and `refs/MC68153L.pdf` has no text
layer, so the exact register map has **not** been checked against the
datasheet. Read "MC68153-style" as "a four-channel BIM with this
layout", not as a confirmed part number.

The post-boot autovector table independently settles that this is a
**vectored** interrupt, not an autovectored one:

| autovector | address | handler |
|---|---|---|
| L1, L2, L3 | `$064`-`$06C` | `F00896` generic |
| **L4** | `$070` | **`F00EC8`** — the only real autovector handler (PTM tick) |
| **L5** | `$074` | `F00896` generic |
| L6 | `$078` | `F00896` generic |
| L7 | `$07C` | **`00000000`** — never installed |

If the host link were autovectored at level 5 it would land on the
generic handler `F00896`, **not** on `F05DD6`. The only route to
`F05DD6` is vector `$4A`, which only the BIM can supply. So the
mechanism is confirmed even though the level is not.

Consequences: "level 5" is our invention and should not be repeated as
fact; the emulator should obtain the vector from the modelled BIM
register rather than a constant; and vector 31 (level-7 / NMI autovector)
being `00000000` means a spurious NMI on real hardware jumps to zero.

---

## 2. AP I/F at `$FF0000-$FF00FF`

Four channel windows on a regular 32-byte stride, base `$FF0040 + $20·N`:

| Offset | Dir | ch1 | ch2 | ch3 | ch4 | Notes |
|---|---|---|---|---|---|---|
| +`$04` | **W** | `$FF0044` | `$FF0064` | `$FF0084` | `$FF00A4` | write port |
| +`$08` | **R** | `$FF0048` | `$FF0068` | `$FF0088` | `$FF00A8` | read port A — the byte-consume read |
| +`$0A` | **R** | `$FF004A` | `$FF006A` | `$FF008A` | `$FF00AA` | status (host injects `$4F` here) |
| +`$0E` | **R** | `$FF004E` | `$FF006E` | `$FF008E` | `$FF00AE` | read port B |

Plus `$FF000E` — command/argument register, **write-only**, 8 static write
sites and the only AP I/F write observed during boot (value `$281`,
`PCMD_HOST_REQUEST`).

**Observed vs. not.** In a full boot the firmware reads only the `+$0E`
port of each channel, twice each, during `RTOSKernelInit`. The `+$08` and
`+$0A` ports are referenced only in `TCBXP*I` code that a plain boot never
reaches. This is the static/dynamic disagreement that corroborates the
stalled host path: **`$FF0048` is never read**, so a queued host byte is
never consumed.

Naming caution: `build_clean_disasm.py` labels `$FF0048` etc.
`XLTR_CH1_DATA_A`, but `$FF0000-$FF00FF` is the **AP I/F**, not the XLTR
(which starts at `$FF0200`). The label is a misnomer inherited from an
early guess.

---

## 3. XLTR control file at `$FF0200-$FF021B`

All word accesses. Static counts are read/write instruction *sites*;
"observed" is what a boot actually executed.

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

`CHANNEL_SELECT` is the most written register in the whole map (80 write
sites) and is heavily read as well — consistent with it being the
multiplexer every panel operation sets first.

---

## 4. Mailbox `$70001C`

The **only 32-bit off-board access** in the firmware. Read-only, 2 static
sites (`RTOSKernelInit`, `TCBIO1I_ASQHandler`), observed 3 times. Bit 29
is the "host needs attention" flag: observed values `00000000` and
`20000000`.

---

## 5. Chassis memory `$400000`, `$403FFC`, `$404000`

Referenced only by `lea`/`movea` in the self-test region — address
computations, not data accesses, and not exercised in a plain boot. Listed
for completeness; do not treat as a confirmed memory window.

---

## Never executed in a plain boot

Static-only, i.e. real code with no coverage: `XLTR_COUNTER`,
`XLTR_DATA_LO`, `XLTR_STATUS_IRQ`, `XLTR_IRQ_MASK`, and every channel
`+$04`/`+$08`/`+$0A` port. These are the panel-command path
(`PanelSendAndWait_andDispatch`) and the per-channel data paths — the
parts that need the chassis to answer. Any emulator work aimed at
completing the host handshake should target exactly this set, since it is
precisely the code the current chassis model never provokes.

---

## Corrections this analysis implies

1. `XLTR_CH{1..4}_CONFIG` are **BIM control registers**, and there is a
   fifth (`$FF0254`, TCBIO1I). The "config init value `$5F`" is a BIM
   control value.
2. The host-link interrupt is **vectored via the BIM**, not autovectored.
3. `$FF0048`-style names carry an `XLTR_` prefix but belong to the AP I/F.
4. The AP I/F channel window is a regular `$20` stride with one write port
   and three read ports — previously documented as just "Data A / Data B".
5. All VersaBus data traffic is word-width; anything modelling byte or
   long accesses to `$FF____` is modelling something the firmware never does.
