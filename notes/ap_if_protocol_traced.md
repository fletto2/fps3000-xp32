# AP I/F card protocol — comprehensive trace from SBC ROM

The AP I/F card (slot 11 in the chassis) bridges the host computer
to the chassis-side VersaBUS. From the SBC's perspective it appears
as a memory-mapped device at `0xFF0000-0xFF00FF`, plus a separate
mailbox at `0x700000`. This document consolidates the full protocol
traced from the SBC ROM disassembly.

## Memory regions exposed by AP I/F

### Primary block at `0xFF0000-0xFF00FF` (256 bytes)

The host-visible SBC-side window. Two distinct sub-regions:

**`0xFF0000-0xFF0010` — command/argument transaction registers**

| Offset | Name | R/W | Purpose |
|---|---|---|---|
| 0xFF0000 | CMD/STATUS | R/W | Write opcode (0x8004=REQUEST-XFER, 0x8005=CONTINUE-XFER); read status (bit 14=ready, bit 13=error) |
| 0xFF000E | CMD_ARG_LO | W | Low word of command argument |
| 0xFF0010 | CMD_ARG_HI | W | High word of command argument (for 32-bit args) |

**`0xFF0048-0xFF00AE` — per-channel data ports** (4 channels of 16 bytes each)

| Offset | Channel | Reg |
|---|---|---|
| 0xFF0048 | CH1 | DATA_A |
| 0xFF004E | CH1 | DATA_B |
| 0xFF0068 | CH2 | DATA_A |
| 0xFF006E | CH2 | DATA_B |
| 0xFF0088 | CH3 | DATA_A |
| 0xFF008E | CH3 | DATA_B |
| 0xFF00A8 | CH4 | DATA_A |
| 0xFF00AE | CH4 | DATA_B |

DATA_A and DATA_B are each 16-bit registers. They report status from
the corresponding XP-32 channel; the SBC reads them during channel
detection at boot (`RTOSKernelInit` reads each to count active
channels).

### Mailbox at `0x700000-0x700020` (8 bytes used)

Discovered during EU-upload trace investigation (see
`eu_upload_trace_v3.md`):

| Offset | Direction | Purpose |
|---|---|---|
| 0x70001C | host→SBC | 32-bit status word; bit 29 = "host needs attention" |
| 0x700020 | SBC→host | 32-bit response word; bit 1 = SBC handled, status delta |

This is the AP I/F card's bidirectional mailbox — a small handshake
register pair separate from the main command path. Used by TCBIO1I
(the host I/O channel task) for asynchronous host event notification.

## Two panel-command dispatchers in the SBC ROM

### Dispatcher A: `PanelIOConfigure_25A` at F05688

Used 45 times throughout the SBC ROM. The standard panel-command
sender:

```asm
PanelIOConfigure_25A:
  f05688: move.w d0, g__last_panel_arg  ; save cmd (0xFF*** valid)
  f0568e: movea.l #$ff0000, a0
  f05694: move.w d0, $e(a0)              ; → XLTR_CMD_ARG (0xFF000E)
  f05698: move.w $202(a0), d1            ; read XLTR_MODE1
  f0569c: bclr.b #$e, d1                 ; clear bit 14
  f056a0: bset.b #$c, d1                 ; set bit 12 (enable)
  f056a4: move.w d1, $202(a0)            ; XLTR_MODE1 = updated
  f056a8: move.w $200(a0), d1            ; read XLTR_MODE0
  f056ac: bclr.b #$a, d1                 ; clear bit 10
  f056b0: move.w d1, $200(a0)            ; XLTR_MODE0 = updated
  f056b4: move.w d0, $204(a0)            ; → XLTR_CHANNEL_SELECT (0xFF0204)
  f056b8: bra.b *-2                       ; (anomalous — see notes)
```

The function writes the panel command to:
1. **XLTR_CMD_ARG** (`0xFF000E`)
2. **XLTR_CHANNEL_SELECT** (`0xFF0204`)

Plus mode-register manipulation: clear MODE1 bit 14, set MODE1 bit
12 (enable), clear MODE0 bit 10.

**Anomaly**: The function ends with `bra.b *-2` (infinite loop) at
F056B8 with no visible RTS. Yet 45 callers expect normal return.
Most plausible explanation: function exits via interrupt-driven
completion — the AP I/F card raises an IRQ when the panel command
completes, the interrupt handler unwinds the stack, and execution
resumes at the JSR's return address. This would explain the
documented "panel command IRQ" mechanism with mask register at
`0xFF021A`.

### Dispatcher B: `loc_F05E56` (TCBIO1I context only)

Used 5 times, all from TCBIO1I_ASQHandler. Functionally identical
to Dispatcher A (same XLTR register sequence) but separate function
because TCBIO1I needs its own dispatcher contextually:

```asm
loc_F05E56:
  f05e56: move.w d0, g__last_panel_arg
  f05e5c: movea.l #$ff0000, a0
  f05e62: move.w d0, $e(a0)              ; → XLTR_CMD_ARG
  f05e66: move.w $202(a0), d1
  f05e6a: bclr.b #$e, d1
  f05e6e: bset.b #$c, d1
  f05e72: move.w d1, $202(a0)
  f05e76: move.w $200(a0), d1
  f05e7a: bclr.b #$a, d1
  f05e7e: move.w d1, $200(a0)
  f05e82: move.w d0, $204(a0)            ; → XLTR_CHANNEL_SELECT
```

Same protocol as Dispatcher A, just a separate copy. Possibly
inlined to avoid stack overhead in the TCBIO1I context.

**Note from earlier trace**: I previously documented these as
"two different protocols". On closer inspection, **they're the same
protocol; Dispatcher B is just a duplicated version of Dispatcher
A in TCBIO1I**. The prior claim that they used "different routing"
was wrong.

## `PanelSendAndWait` at F056BA — the data-transaction kernel

A **separate** routine, called only 3 times, that handles
opcode-based data transactions via the FF0000 register:

| Caller | Context |
|---|---|
| F04CE8 | TCBRDHC channel-config dispatch |
| F05436 | SRecord parse path (per-record) |
| F05468 | SRecord parse path (per-record) |

This is the AU upload path. Different from PanelIOConfigure_25A:

```asm
PanelSendAndWait:           ; called with d0=cmd, a0=FF0000, a1=cmd_arg_addr,
                            ;             a3=busy_flag, a4=FF0200 (XLTR base)
  f056ba: move.w #$4f, (a3)        ; mark busy at busy-flag location
  f056be: move.w d4, -(a7)         ; save d4 on stack
  f056c0: move.w #$0, (a1)         ; clear arg-low
  f056c4: move.w d0, d7            ; save cmd
  f056c6: move.w d0, $2(a1)        ; arg-high = cmd
  f056ca: move.w #$8004, (a0)      ; AP I/F: REQUEST-TRANSFER
  f056ce: move.l #$3e8, d5         ; timeout = 1000 polls

POLL_REQ:
  f056d4: subq.l #$1, d5
  f056d6: move.w (a0), d4           ; read AP I/F status
  f056d8: btst.b #$e, d4            ; bit 14 = ready
  f056dc: bne.b CHECK_ERR
  f056de: cmpi.l #$0, d5            ; timeout?
  f056e4: bne.b POLL_REQ            ; if not, keep polling

CHECK_ERR:
  f056e6: btst.b #$d, d4            ; bit 13 = error
  f056ea: bne.b ERR_PATH
  f056ec: cmpi.l #$0, d5            ; timeout AND no error?
  f056f2: bne.b SUCCESS
  f056f4: move.w #$26c, d0          ; PCMD_RELEASE on timeout
  f056f8: jsr PanelIOConfigure_25A.l

ERR_PATH:
  f056fe: btst.b #$d, d4
  f05702: beq.b SUCCESS_DISPATCH
  f05704: move.w #$269, d0          ; PCMD_ERROR_ABORT on error
  f05708: jsr PanelIOConfigure_25A.l
  f0570e: move.w $21a(a4), d0       ; read XLTR_IRQ_MASK
  f05712: move.w (a7)+, d4
  f05714: lea.l PanelErrorMaskTable, a5
  f0571a: clr.l d5
  f0571c: move.b (a5, d4.w), d5     ; lookup error mask byte
  f05720: bclr.b d5, d0              ; clear bit in IRQ mask
  f05722: move.w d0, $21a(a4)       ; write back
  f05726: move.w #$5f, (a3)         ; mark idle
  f0572a: rts

SUCCESS_DISPATCH:
  f0572c: lsl.w #$2, d0              ; d0 << 2 (× 4)
  f0572e: lea.l PanelStatusDispatch, a4
  f05734: jmp (a4, d0.w)            ; jump table
  ...
  ; 32-bit arg path:
  f05738: swap d2
  f0573a: move.w d2, (a1)            ; arg-high
  f0573c: swap d2
  f0573e: move.w d2, $2(a1)         ; arg-low
  f05742: move.w #$8005, (a0)       ; AP I/F: CONTINUE-TRANSFER
  ; ... another poll loop ...
```

So the AP I/F's transaction protocol (via FF0000) is:

1. **Set up argument**: write to FF000E (low) and FF0010 (high)
2. **Issue REQUEST-TRANSFER**: write `0x8004` to FF0000
3. **Poll status**: read FF0000, watch bit 14 (ready) and bit 13 (error)
4. **On error**: send `PCMD_ERROR_ABORT (0x269)` and update IRQ mask
5. **On success with 32-bit follow-up**: load second arg, write `0x8005`
   (CONTINUE-TRANSFER), poll again
6. **Final**: dispatch via PanelStatusDispatchTable indexed by response byte
7. **Cleanup**: timeout fires `PCMD_RELEASE (0x26C)` if both no-ready AND timeout

## AP I/F status word bits (from FF0000)

| Bit | Name | Meaning |
|---|---|---|
| 14 | READY | Set when last opcode complete |
| 13 | ERROR | Set when last opcode failed |
| Others | unknown | Not exercised by SBC ROM |

## XLTR mode register manipulations from PanelIOConfigure_25A

| Register | Bit | Action | Likely meaning |
|---|---|---|---|
| MODE0 (0xFF0200) | 10 | clear | reset/release something |
| MODE1 (0xFF0202) | 14 | clear | reset something |
| MODE1 (0xFF0202) | 12 | set | enable (panel cmd processor?) |

## Per-channel CONFIG registers (FF02xx)

These are separate from CHANNEL_SELECT and are written in
HardwareInit + boot:

| Reg | Channel | Init value |
|---|---|---|
| 0xFF0244 | CH1 | 0x5F |
| 0xFF0246 | CH2 | 0x5F |
| 0xFF0250 | CH3 | 0x5F |
| 0xFF0252 | CH4 | 0x5F |

**Correction (2026-07-29): these are not channel config registers.**
`0xFF0230-0xFF025F` holds three MC68153-style Bus Interface Modules, four
interrupt channels each, with CR0-3 at +$0/+2/+4/+6 and VR0-3 at
+$8/+A/+C/+E. `0x244`, `0x246`, `0x250` and `0x252` are BIM *control*
registers, and there is a fifth at `0x254` owned by TCBIO1I.

`0x5F` (`01011111`) decodes against the MC68153 datasheet as bits 0-2 =
IRQ request level **7**, bit 4 = IRE (interrupt enable). Bit 5 is IRAC
(auto-clear), clear here, so a channel stays armed after acknowledgement.
Bit 7 is the Flag, also clear.

The guess above was close on shape and wrong on function: it is an
enable-plus-interrupt setting, but it programs an interrupt controller
rather than a channel mode.

ChannelConfigOffsetTable at F046E0 stores `0x244, 0x246, 0x250, 0x252`.
**The 8-byte gap between `0x246` and `0x250` is now explained**: it holds
BIM1's four vector registers (`0x248`, `0x24A`, `0x24C`, `0x24E`), not
reserved space for two more channels. `0x24C` and `0x24E` are in active
use, carrying vectors `$45` and `$46` for TCBXP1I and TCBXP2I.

## IRQ mask register (`0xFF021A`)

Per-bit mask of IRQs from the AP I/F. Bits correspond to channels.
PanelErrorMaskTable at F05C4C maps an error-status byte to a bit
position in this register. On error, that bit is cleared (disabling
further IRQs from the offending channel) until reset.

## Full call graph (AP I/F transaction layer)

```
TCBRDHC tasks
    │
    ├──── PanelIOConfigure_25A (45 callers, 21 distinct codes 0x258..0x27D)
    │         │
    │         └── writes XLTR_CMD_ARG + XLTR_CHANNEL_SELECT
    │             then exits (anomaly: bra.b *-2; assume IRQ-completed)
    │
    ├──── PanelSendAndWait (3 callers, used for data transactions)
    │         │
    │         ├── 0x8004 REQUEST-TRANSFER opcode at FF0000
    │         ├── poll FF0000 bit 14 (ready), bit 13 (error)
    │         ├── 0x8005 CONTINUE-TRANSFER for 32-bit args
    │         └── dispatch via PanelStatusDispatchTable (42 entries)
    │
    ├──── TCBIO1I → loc_F05E56 (5 callers, codes 0x27E..0x282)
    │         │
    │         └── duplicate of PanelIOConfigure_25A
    │
    └──── 0x700000 mailbox (8 bytes total)
              │
              ├── read 0x70001C bit 29 → trigger 0x281 dispatch
              └── write 0x700020 bit 1 → respond to host
```

## What the AP I/F card does (inferred function)

Given the SBC ROM behavior, the AP I/F card mediates these
host↔chassis transactions:

1. **Command channel** (host → 0xFF0000 opcode → AP I/F → SBC notified
   via IRQ): host issues `0x8004 REQUEST-TRANSFER` and gets routed
   to the SBC for handling.
2. **Data channel** (host → cable → AP I/F → SBC RAM via DMA): bulk
   data transfers, e.g. S-records into the 64KB AU staging buffer.
3. **Mailbox** (host ↔ 0x700000 region): asynchronous status/event
   signals.
4. **IRQ generator**: AP I/F card raises CPU IRQs on transaction
   complete, error, or host event. SBC's 6840 PTM (at 0xF70001+)
   plus the per-channel IRQ-mask at FF021A handle the IRQ vectoring.

## What's UNKNOWN about the AP I/F protocol

These pieces are NOT in the SBC ROM and need physical investigation:

1. **Cable signal mapping**: ~169 nets per the 4448 netlist; specific
   pin → AP I/F register correspondence not yet verified by bench
   probing of an actual chassis-side card.
2. **Host-side AP I/F card**: missing from Lovett's setup. The
   substitute-hardware plan (FPGA, see
   `host_substitute_hardware_plan.md`) needs to implement the host
   side of all the above protocols.
3. **Specific XLTR_MODE0 / MODE1 / MODE2 bit semantics**: Mode regs
   manipulated by the SBC, but the actual hardware effects are
   inferred from context, not documented.
4. **`0x700000` mapping mechanism**: how the AP I/F card maps this
   region into the SBC's bus (and presumably also into the host's
   bus) is not visible in the SBC ROM.
5. **Why `bra.b *-2` at F056B8**: anomalous infinite loop in
   PanelIOConfigure_25A. Either dead code, IRQ-driven exit, or
   disassembler error.

## Implications for FPGA substitute design

The host-side AP I/F substitute (per `host_substitute_hardware_plan.md`)
must implement, on the host-bus side:

- **Cable interface**: 169 signals × VersaBUS-electrical-spec
- **Command register decoder**: opcodes 0x8004 / 0x8005 routed to
  appropriate handler
- **Status register**: bits 14 (ready) and 13 (error) settable from
  internal state
- **Data registers**: per-channel DATA_A/B (4 × 16-bit each)
- **Mailbox**: 8-byte 0x700000 region with bit-29-on-write semantics
- **IRQ generator**: at least 12 distinct IRQ sources per the
  XLTR_IRQ_MASK register's `0xFFF` width
- **DMA engine**: for bulk data transfers from host RAM to
  the SBC's 64KB AU staging buffer

All other behaviors (panel-command dispatch, microcode upload,
channel state machines) are SBC-ROM-resident and don't need to be
implemented in the substitute.
