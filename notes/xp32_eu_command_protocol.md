# XP-32 EU command-protocol — inferred from SBC ROM traffic

What we *can* infer from the FPS-3000 SBC ROM, and what we *can't*.

> **Important scope note.** The 80-bit EU microinstruction format is
> mask-programmed in PROM on the EXEC card and **never travels over
> any bus the SBC touches** — so we cannot reverse-engineer the EU
> opcode/microinstruction layout from this ROM. What we *can* infer
> is the **EU's external command alphabet**: the 16-bit "panel-command"
> codes the SBC pokes into the XLTR/AP-I/F, and the FSM that consumes
> them on the EXEC side. That's an *interface* spec, not a uarch spec,
> but it's enough to drive the EU once we have AU microcode loaded.

## The three-register transaction

Every panel command issued by the SBC follows the same 3-register
sequence at the AP-I/F base (`a1` ≈ `0xFF0214` in `PanelSendAndWait` at
`F056BA`):

```
  move.w  d_hi, (a1)              ; $214: data parameter HI (often 0)
  move.w  d_lo, $2(a1)            ; $216: data parameter LO (e.g. cmd code)
  move.w  #$8004, (a0)            ; $218: trigger word — kicks the EU
  ; — poll —
  loop:   move.w  (a0), d4        ; $218: read back status
          btst.b  #$E, d4         ; bit 14 = command-done
          bne     done
          subq.l  #$1, timer
          bne     loop
  done:   btst.b  #$D, d4         ; bit 13 = error
          ...
```

So the wire-level shape of an EU panel command is:

| Reg | Offset | Direction | Meaning |
|---|---|---|---|
| **DATA_HI** | `$214` | SBC→EU | Argument high word (24-bit address upper, count, mode bits) |
| **DATA_LO / CMD** | `$216` | SBC→EU | Command code (`0x258..0x27D`) or argument low word |
| **TRIGGER / STATUS** | `$218` | bidir | SBC writes opcode; SBC reads status |

Two distinct bus opcodes are written to TRIGGER:

| Opcode | Use site | Inferred meaning |
|---|---|---|
| `0x8004` | first phase of every transaction | "execute command, no read-back" |
| `0x8005` | second/third phase after a successful 0x8004 | "execute command, return data into DATA_HI/LO" |

The two differ in bit 0 only, so the encoding is plausibly:

```
  bit 15 = strobe ('this register write is a command, not status')
  bit 14..3 = 0
  bit 2 = opcode class    ('1' = "panel command")
  bit 1 = reserved/zero
  bit 0 = direction       (0 = write, 1 = read-back)
```

— which makes `0x8004` "panel-command-write-no-readback" and `0x8005`
"panel-command-write-then-read". Consistent with how the dispatcher
issues a write to set up state, then a read to fetch a result word.

## Status word layout (read from `$218`)

`PanelSendAndWait` reads `$218`, masks bits 14/13, and dispatches:

| Bit | Meaning | Where used |
|---|---|---|
| 15 | strobe / valid | Set when a status word is present |
| 14 | command-done | `btst #$E` at F056D8 |
| 13 | error | `btst #$D` at F056E6, F056FE |
| 11..0 | status detail | Lower 12 bits index `PanelStatusDispatch` (×4 for jmp-table stride) and `PanelErrorMaskTable` |

The dispatcher does `lsl.w #2,d0; jmp (PanelStatusDispatch.l,d0.w)` —
i.e. masks the lower bits, multiplies by 4, indexes a table of
`JMP d16(PC)` instructions. We previously identified that table as a
20-entry jump dispatch (`F05BA4..F05BF7`), so **the EU returns one of
20 possible status codes** in bits `0..4` of the status word.

The IRQ-mask byte at `$21A` is also used as an error-class lookup:
`PanelErrorMaskTable` (`F05C4C..F05CFF`) is a per-status byte that
tells the SBC which IRQ-mask bit to clear after handling the error.

## The 16-bit panel-command alphabet

Codes the SBC writes to `$216`, with use frequency from the ROM:

| Code | Binary (12-bit) | Inferred function | Uses | Notes |
|---|---|---|---|---|
| `0x258` | `001001 011 000` | CH1 reset | 1 | first of channel-1 op set |
| `0x259` | `001001 011 001` | CH1 init | 1 | |
| `0x25A` | `001001 011 010` | CH1 ack/finalize | 2 | end of S-record upload |
| `0x25B` | `001001 011 011` | CH1 flush | 1 | |
| `0x25C` | `001001 011 100` | reset-status | 5 | most common channel op |
| `0x25D` | `001001 011 101` | CH1 config | 1 | |
| `0x25E` | `001001 011 110` | CH2 config | 1 | |
| `0x25F` | `001001 011 111` | CH3 config | 1 | |
| `0x260` | `001001 100 000` | CH4 config | 1 | |
| `0x269` | `001001 101 001` | error-abort | ≥1 | sent on bit-13 error path |
| `0x26A` | `001001 101 010` | timeout-abort | 1 | |
| `0x26B` | `001001 101 011` | channel-abort | 1 | |
| `0x26C` | `001001 101 100` | RELEASE / no-op-recover | 9 | most common abort/release |
| `0x26E` | `001001 101 110` | CH1 TCB-fail | 1 | |
| `0x271` | `001001 110 001` | CH4 TCB-fail | 1 | |
| `0x276..0x27D` | `001001 110/111 xxx` | INIT-step 1..8 | 8 | startup sequence |

Holding `code & 0xFC0 == 0x240` (i.e. bits 11..6 always = `0b001001`)
across every panel-command site — strong evidence that **bits 11..6
are a fixed namespace selector**: "this is an EU panel command" vs
some other AP-I/F traffic class.

### Bit-field hypothesis

```
  15..12:   0          (unused — top nibble always 0)
  11..6:    0b001001   (constant — "panel command" namespace, = 0x09)
   5..3:    class      (3 bits, 8 classes)
   2..0:    sub-cmd    (3 bits, 8 sub-codes; often = channel# when relevant)
```

Class field decode (from observed groupings):

| `class` | Range | What lives there |
|---|---|---|
| `011` | `0x258..0x25F` | Channel-1 op set + status reset |
| `100` | `0x260..0x267` | Channel 2/3/4 config |
| `101` | `0x268..0x26F` | Errors / aborts / RELEASE |
| `110` | `0x270..0x277` | TCB-fail + early init steps |
| `111` | `0x278..0x27F` | Late init steps |

This isn't airtight — class `011` mixes per-channel ops with the
"reset-status" generic — but `101` (errors) and `110/111` (init
sequence) are clean groupings.

## What the host-side software actually does (XPMLIB primitive ⇄ panel command)

Cross-walking against the published API (Curington 1984; Hockney
p.241–242):

| XPMLIB call | What the SBC must issue |
|---|---|
| **XPSEL** *channel* | write `$204` (channel-select) directly — not a panel command |
| **XPRUN** | RELEASE (`0x26C`) on selected channel? — clears pending status, kicks the AC |
| **XPWAIT** | poll-loop in TCBXP*I — runs the per-channel state-machine dispatcher |
| **XPSTAT** | read-back via 0x8005 transaction with `0x25C` (status) |
| **XPDMAR** *src,dst,n* | sequence: select-channel → set-address → set-count → "transfer" → arm |
| **XTMDMA** | same primitive as XPDMAR with TCM target — bit in DATA_HI selects |
| **XPISNC** | poll status until bit 14 set + bit 13 clear |

So the panel-command alphabet implements a **DMA-controller-with-
status-dispatch**, not a general-purpose EU-instruction interface.
The EU PROM sequencer interprets `0x258..0x27D` and walks its own
microcoded FSM (visible to us only as the 20-state dispatch table on
the SBC side); the actual *math* happens inside microcoded loops
running on the AU WCS, which are uploaded out-of-band via S-records.

## What we still can't infer

1. **The EU microinstruction encoding.** 80-bit per word, 2K words,
   mask-PROM, never on the bus. Reverse-engineering it requires
   reading the PROM contents off the EXEC card directly.
2. **The AU 128-bit microinstruction format.** The SBC uploads it as
   opaque bytes; field assignments would have to come from disassembling
   a known XPMLIB kernel binary (e.g., `ZRFFT`) once one is recovered.
3. **What "init-step 1..8" actually configures.** We can see the
   sequence (`0x276 → 0x27D` issued in order during boot at one
   site) but not what each step pokes inside the EU FSM.
4. **The exact status-code → recovery mapping.** We have the 20-entry
   dispatch table at `F05BA4` and the per-entry IRQ-mask byte at
   `F05C4C`, but the *meanings* of statuses 0..19 require looking at
   what each branch handler does — a target for a future MC pass.

The first item is the only one that requires physical access to a
working EXEC card. The other three are all reachable from this ROM +
host-side software analysis alone, given enough time.
