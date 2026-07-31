# FPS-3000 device communications map

Every address outside ROM and plain RAM that this firmware touches, with direction,
**true CPU-level access width**, and the number of distinct code sites reaching it.

Measured with `FPS3K_ACCESSLOG`, which logs at the CPU boundary *before* the emulator
decomposes wide accesses, over the union of four driving configurations: default, all
four XP channels, RDHC command 1, and the TCBIO1I reply path.

*Width matters. The older `-bus` log recorded accesses after decomposition, which
invented a register at `$FF0212` and inflated three separately published counts.*

## VERSAmodule control register
`$01FFF0-$01FFF3`

| address | name | R8 | R16 | R32 | W8 | W16 | W32 | sites |
|---|---|---|---|---|---|---|---|---|
| `$01FFF0` | VMOD ctrl | 32 | 92 | 32 | 32 | 128 | 36 | 27 |
| `$01FFF1` | VMOD ctrl (byte) | 336 |  |  | 184 |  |  | 45 |
| `$01FFF2` |  |  |  |  |  | 12 |  | 3 |

## host mailbox
`$70001C-$700023`

| address | name | R8 | R16 | R32 | W8 | W16 | W32 | sites |
|---|---|---|---|---|---|---|---|---|
| `$70001C` | host status |  |  | 473 |  |  |  | 2 |
| `$700020` | reply |  |  |  |  |  | 469 | 1 |

## chassis memory window (paged via MODE2)
`$400000-$4FFFFF`

**4098 distinct addresses**, `$400000-$404000` = 16 KB, in **262337 accesses** of which **262293 are 32-bit**.

Not a register block — this is the window onto MEM CTL / MAIN DATA.  Self-test
phase `$29xx` walks exactly the first 16 KB at stride 4 with four patterns.
Access is gated by `$FF0216`: bit 5 arms a bus error, bit 4 enables 16-bit
access (clear = longword-only, word writes dropped and word reads shadowed by
`$FF0214`).

## MC6840 PTM (odd bytes only)
`$F70000-$F7000F`

| address | name | R8 | R16 | R32 | W8 | W16 | W32 | sites |
|---|---|---|---|---|---|---|---|---|
| `$F70001` |  |  |  |  | 48 |  |  | 6 |
| `$F70003` |  | 5502 |  |  | 48 |  |  | 7 |
| `$F70005` |  | 64 |  |  | 76 |  |  | 4 |
| `$F70007` |  | 64 |  |  | 76 |  |  | 4 |
| `$F70009` |  | 64 |  |  | 72 |  |  | 3 |
| `$F7000B` |  | 64 |  |  | 72 |  |  | 3 |
| `$F7000D` |  | 5566 |  |  | 76 |  |  | 5 |
| `$F7000F` |  | 64 |  |  | 76 |  |  | 4 |

## uPD7201 SIO
`$F70010-$F70017`

**Never accessed by this firmware.**

Which is why the in-ROM monitor can co-opt it: the chip is entirely free.

## board status / control
`$F70018-$F7001F`

| address | name | R8 | R16 | R32 | W8 | W16 | W32 | sites |
|---|---|---|---|---|---|---|---|---|
| `$F70018` | board status (word) |  | 340 |  |  |  |  | 4 |
| `$F70019` | board status | 2361332 |  |  |  |  |  | 16 |

## AP I/F window 0 - host / bulk link
`$FF0000-$FF001F`

| address | name | R8 | R16 | R32 | W8 | W16 | W32 | sites |
|---|---|---|---|---|---|---|---|---|
| `$FF000E` | command/status |  | 8 |  |  | 6 |  | 5 |

## AP I/F window 1 - XP channel 1
`$FF0040-$FF005F`

| address | name | R8 | R16 | R32 | W8 | W16 | W32 | sites |
|---|---|---|---|---|---|---|---|---|
| `$FF0044` | write |  |  |  |  | 4 |  | 1 |
| `$FF0048` | data high |  | 467 |  |  | 9 |  | 9 |
| `$FF004A` | data low |  | 467 |  |  | 9 |  | 9 |
| `$FF004E` | command/status |  | 479 |  |  | 9 |  | 17 |

## AP I/F window 2 - XP channel 2
`$FF0060-$FF007F`

| address | name | R8 | R16 | R32 | W8 | W16 | W32 | sites |
|---|---|---|---|---|---|---|---|---|
| `$FF0064` | write |  |  |  |  | 4 |  | 1 |
| `$FF0068` | data high |  | 467 |  |  |  |  | 1 |
| `$FF006A` | data low |  | 467 |  |  |  |  | 1 |
| `$FF006E` | command/status |  | 471 |  |  |  |  | 2 |

## AP I/F window 3 - XP channel 3
`$FF0080-$FF009F`

| address | name | R8 | R16 | R32 | W8 | W16 | W32 | sites |
|---|---|---|---|---|---|---|---|---|
| `$FF0084` | write |  |  |  |  | 1 |  | 1 |
| `$FF0088` | data high |  | 467 |  |  |  |  | 1 |
| `$FF008A` | data low |  | 467 |  |  |  |  | 1 |
| `$FF008E` | command/status |  | 471 |  |  |  |  | 2 |

## AP I/F window 4 - XP channel 4
`$FF00A0-$FF00BF`

| address | name | R8 | R16 | R32 | W8 | W16 | W32 | sites |
|---|---|---|---|---|---|---|---|---|
| `$FF00A4` | write |  |  |  |  | 1 |  | 1 |
| `$FF00A8` | data high |  | 484 |  |  | 6 |  | 5 |
| `$FF00AA` | data low |  | 484 |  |  | 6 |  | 5 |
| `$FF00AE` | command/status |  | 492 |  |  | 23 |  | 10 |

## XLTR control registers
`$FF0200-$FF022F`

| address | name | R8 | R16 | R32 | W8 | W16 | W32 | sites |
|---|---|---|---|---|---|---|---|---|
| `$FF0200` | MODE0 |  | 474 |  |  | 475 |  | 9 |
| `$FF0202` | MODE1 |  | 14 |  |  | 38 |  | 19 |
| `$FF0204` | CHANNEL_SELECT |  | 28 |  |  | 131871 |  | 76 |
| `$FF020C` | COUNTER |  | 4 |  |  | 12 |  | 3 |
| `$FF0210` | MODE2/page |  | 474 |  |  | 975 |  | 15 |
| `$FF0212` | (probe-only, phase $1600) |  | 4 |  |  | 4 |  | 2 |
| `$FF0214` | DATA **low** half |  | 4 |  |  | 12 |  | 3 |
| `$FF0216` | BERR/width enables |  | 4 |  |  | 68 |  | 18 |
| `$FF0218` | STATUS_IRQ |  | 8 |  |  | 20 |  | 6 |
| `$FF021A` | IRQ_MASK |  | 8 |  |  | 8 |  | 8 |

## three MC68153 bus-interrupt modules
`$FF0230-$FF025F`

| address | name | R8 | R16 | R32 | W8 | W16 | W32 | sites |
|---|---|---|---|---|---|---|---|---|
| `$FF0230` | BIM0 CR0 |  | 4 |  |  | 9 |  | 4 |
| `$FF0232` | BIM0 CR1 |  | 4 |  |  | 8 |  | 3 |
| `$FF0234` | BIM0 CR2 |  | 4 |  |  | 8 |  | 3 |
| `$FF0236` | BIM0 CR3 |  | 4 |  |  | 8 |  | 3 |
| `$FF0238` | BIM0 VR0 |  | 4 |  |  | 8 |  | 3 |
| `$FF023A` | BIM0 VR1 |  | 4 |  |  | 8 |  | 3 |
| `$FF023C` | BIM0 VR2 |  | 4 |  |  | 8 |  | 3 |
| `$FF023E` | BIM0 VR3 |  | 4 |  |  | 8 |  | 3 |
| `$FF0240` | BIM1 CR0 |  | 4 |  |  | 4 |  | 2 |
| `$FF0242` | BIM1 CR1 |  | 4 |  |  | 8 |  | 3 |
| `$FF0244` | BIM1 CR2 |  | 4 |  |  | 12 |  | 6 |
| `$FF0246` | BIM1 CR3 |  | 4 |  |  | 8 |  | 3 |
| `$FF0248` | BIM1 VR0 |  | 4 |  |  | 4 |  | 2 |
| `$FF024A` | BIM1 VR1 |  | 4 |  |  | 8 |  | 3 |
| `$FF024C` | BIM1 VR2 |  | 4 |  |  | 8 |  | 3 |
| `$FF024E` | BIM1 VR3 |  | 4 |  |  | 8 |  | 3 |
| `$FF0250` | BIM2 CR0 |  |  |  |  | 4 |  | 1 |
| `$FF0252` | BIM2 CR1 |  |  |  |  | 10 |  | 3 |
| `$FF0254` | BIM2 CR2 |  |  |  |  | 477 |  | 2 |
| `$FF0256` | BIM2 CR3 |  |  |  |  | 4 |  | 1 |
| `$FF0258` | BIM2 VR0 |  |  |  |  | 4 |  | 1 |
| `$FF025A` | BIM2 VR1 |  |  |  |  | 4 |  | 1 |
| `$FF025C` | BIM2 VR2 |  |  |  |  | 4 |  | 1 |

## What this ROM cannot show

The map above is the **SBC↔chassis boundary** and nothing beyond it. Four parts of the
machine leave no trace in this firmware:

| device | why it is invisible here |
|---|---|
| **EU ↔ AU** (EXEC ↔ ARITH) | The 80-bit EU instruction stream and the 128-bit AU microword are internal to the card pair. The SBC hands over opaque bytes and pokes channel registers; it never sees a microinstruction field. |
| **UNIV FMT** | Has no register block in the SBC's address space at all. It sits in the XLTR → XP-32 data path and is driven by the transfer, not addressed. |
| **MEM CTL / MAIN DATA** | Reached only *through* the `$400000` window. The SBC cannot distinguish the controller from the memory behind it. |
| **AP I/F counterpart** | Lives in the host chassis on the other end of the two ribbon cables. Not present in this machine. |

So "map all communications to and from the devices" is answerable in full for the SBC
and its four immediate neighbours, and **not answerable from this ROM** for the XP-32
internals. Those need the EU PROM dumped or a bus trace on the EXEC/ARITH card pair —
the two artefacts this project has recorded as blocked on hardware from the start.


---

## Update 2026-07-30: static∪runtime = 68 addresses, and the window is bidirectional

This document was built from runtime access logs over four driving configurations. Sweeping the
**disassembly** statically with base-register tracking gives an independent list, and the two
together close the map:

| | count |
|---|---:|
| static (application + kernel listings) | 49 |
| runtime (four configurations) | 67 |
| **union** | **68** |
| static-only residue after driving | **0** |

The 19 runtime-only addresses are reached through base registers a static pass cannot resolve —
the MC6840 `movep` registers `$F70001`-`$F7000F`, the four channel-window `+$00` registers,
`$FF0212`/`$FF0214`/`$FF0216`, `$FF0240`, `$FF0248`.

**`$FF0004` was the one static-only address** — the bulk-port ready flag polled at `$F04B22` and
`$F05A22`, present in the code and in no runtime log. It is now reached
(`FPS3K_XPIRQ=6 FPS3K_RESP=0x00` plus a staging sequence drives `$F04B22` 1,365,711 times), so
**every device address in the disassembly is also reachable at runtime**.

### The `$400000` window carries SBC **writes**, not only reads

Chassis operation `$3` is listed in the op table as "read chassis memory". It is **bidirectional**
— `$F04D52` tests bit 5 of the command byte, the documented direction bit, and branches to a
symmetric write implementation at `$F04DC0`:

```
F04DD6  move.w  $204(a0),$e72     ; data half from CHANNEL_SELECT
F04DE8  move.w  d1,$210(a0)       ; page = addr >> 20
F04DF8  lsl.l   #$2,d1            ; offset = (addr & $FFFFF) << 2
F04E0A  move.l  $e70,(a1,d1.l)    ; STORE 32 bits into the window
F04E30  addq.l  #$1,$e58          ; bit 4 = auto-increment
```

Confirmed executing: **219 stores**, logged as four byte-writes at `$400000`-`$400003` from that
single instruction. So the SBC has a **32-bit paged write port with auto-increment** into the
chassis address space, not merely a read window — which is the mechanism by which data reaches
System Common Memory and, through it, the XP-32 side.

This also explains why `$FF0204` is the busiest register on the board (~33k writes): it is the
**data conduit** for that port, assembled in two 16-bit halves selected by bit 6, not merely a
channel selector.

### What is still out of reach

Unchanged: the SBC never addresses XP-32 EXEC, XP-32 ARITH or UNIV FMT. The self-test draws the
same boundary — it exercises SBC, PTM, VMOD, bus watchdog, XLTR, AP I/F and SCM via MEM CTL, and
touches none of those three. They sit behind the chassis, reachable only through the `$400000`
window and the channel command ports, so no amount of firmware analysis will map them; that needs
hardware.


## Correction: `$FF0214` is the LOW half, not the high half (2026-07-30)

This table labelled `$FF0214` "DATA hi half". The self-test settles it directly. Phase
`$1900` has two sub-tests, and they differ in exactly this:

```
$F09806  move.l d0,(a0)      ; write a longword to the $400000 window
$F09808  move.w d1,(a0)      ; ...then a word to the window's FIRST word
$F0980A  cmp.l  (a0),d2      ; check the whole longword

$F0981A  move.l d0,(a0)      ; write a longword to the window
$F0981C  move.w d1,$214(a6)  ; ...then a word to $FF0214
$F09820  cmp.w  $2(a0),d2    ; check the SECOND word -- the LOW half
```

A word written to `$FF0214` lands in `$2(a0)`, the low half of the 32-bit chassis word.
So `$FF0214` is the **low-half write port**, which is what the phase-`$1900` note in
`versabus_access_map.md` says and what `emulator/versabus.h` already encodes
(`XLTR_DATA_LO`). Only this table's label was wrong; no code or model depended on it.

The confusion is worth naming, because it will recur: `$FF0214` is also the **leading**
half of every 32-bit CPU access that pairs it with `$FF0216`, so on the CPU side it is the
"high" longword half while on the chassis side it latches the "low" data half. Both
statements are true about different words.

## The protocol layer above the registers (2026-07-31)

The sections above are the *register* map — every address, direction and width. This section is
the *transaction* map: what conversations those registers carry. Together they are the complete
communications picture for everything the SBC can reach.

### Four conversations exist, and they are strictly layered

| # | conversation | initiator | carrier | terminator |
|---|---|---|---|---|
| 1 | **chassis → SBC command language** | chassis | `XLTR_MODE0` low byte, latched at `$E86`/`$E87` | op `$F` (ISR exit stub `$F050F8`) |
| 2 | **host → RDHC command block** | host, via the chassis window | 4 commands, number in the first longword of a parameter block | return to the directive-`$13` wait |
| 3 | **SBC ↔ XP channel transaction** | SBC | AP I/F window `+$04`/`+$08`/`+$0A`/`+$0E` | status bit 14 (DONE) |
| 4 | **XP channel → CP program callback** | SBC, on behalf of a channel | the trampoline at `$10AE + (ch-1)*4` | the callback's own `rts` |

Conversation 1 carries 2; 3 is driven from 2; 4 is the tail of 3. **Nothing on the SBC ever
addresses the EU or the AU** — conversation 3 stops at the AP I/F window, and what happens
beyond it is the XLTR's and the UNIV FMT's business. That boundary is not an absence of
evidence; the machine's own power-on self-test draws the same line, exercising SBC, PTM, VMOD,
watchdog, XLTR, AP I/F and SCM and touching XP-32 EXEC, XP-32 ARITH and UNIV FMT never.

### Conversation 1 — the command byte is a bit-field, not an opcode

| bits | meaning |
|---|---|
| 0-3 | operation, into the 16-entry table at `$F05102` |
| 4 | auto-increment the index at `$E7A` |
| 5 | direction: 0 = write/store, 1 = read/return |
| 6 | half-select of a 32-bit parameter |
| 7 | route to the other dispatcher, `$F0495C` |

So `$01`/`$41` are one operation with bit 6 clear/set, and the sixteen operations are the
SBC's whole externally-commandable surface: set address, set count, chassis-memory read/write,
channel validate, SBC-RAM read/write, BIM mask, CH1 reset, third parameter, status-file read,
staging base, longword-array read, channel range check, **clear busy (`XPRUN`)**, and exit.

### Conversation 3 — the channel transaction, register by register

```
SBC   write  +$04 <- $0000            arm
SBC   write  +$08 <- data high        32-bit payload, high half
SBC   write  +$0A <- data low                          low half
SBC   write  +$0E <- $8000            trigger  ($8004 REQUEST, $8005 CONTINUE)
      ...                             MODE1 bit 7 reads busy while in flight
ISR   read   +$0E -> status           bit 15 class, 14 DONE, 13 ERROR, 11 sub-mode
ISR   read   +$08, +$0A -> payload
ISR   store  {status, hi, lo} at $1066 + (ch-1)*6
```

The three-word per-channel record at `$1066` is the *transaction* result; the four-bit-per-
channel nibble at `$1064` is the *status file* the chassis reads back with op `$A`. They are
different structures with different lifetimes and both are read by the chassis.

### Conversation 4 — the only path out of the firmware

`$10AE + (ch-1)*4` is a **callable trampoline**, not a handle: the bytes are executed. On this
ROM alone it is zero and every channel skips it, which is why the firmware completes but never
computes. A CP program loaded by `CPLOAD` fills it, and the channel ISR then calls it with the
transaction result. Driving it in the emulator with a 16-byte handler produced **1466 complete
channel cycles** ending in the RTOS idle loop — the first time this firmware has been carried
through a full channel lifecycle.

**One firmware hazard on that path is real; the other is RETRACTED (2026-07-31).**

*Retracted:* the "96-byte stack leak, no matching release anywhere in the ROM". A full audit of
every explicit `a7` adjustment in the image — 4 allocations, 38 releases — shows each of the
four `lea -$60(a7),a7` **is** followed 24 bytes later by a `lea $C(a7),a7`. That release is the
12-byte `RSTATE` parameter block, not the 96-byte buffer, so the arithmetic in the original
claim was right; the conclusion was not. The buffer is still live and is read immediately
after (`movea.l $3C(a7),a3`), then 60 more bytes of `movem.l d0-d7/a0-a6,-(a7)` are pushed on
top and control passes to the CP-program trampoline. **The 96 bytes are part of the frame
handed to the callee.** Whether not releasing them is a leak depends on the CP program's
unwind contract, which this ROM does not contain — and the whole path is skipped when
`$10AE` is zero, so on this firmware alone the imbalance is unobservable. Calling it a
firmware bug over-read the evidence.

*Stands:* the unchecked `RSTATE` return. `$F08590` issues directive `$43` and `$F08596` reads
`$3C(a7)` into `a3` with **no test of the returned status**, then writes 77 bytes through it.
On a failed lookup `a3` is garbage and the writes land in low RAM.

### What a complete emulator still needs, and it is not a register

Everything addressable is modelled. The missing piece is the **counterparty**: the AP I/F's
partner card in the host chassis, and the CP program that fills `$10AE`. Neither is a device
the ROM talks to — they are the other ends of conversations 2 and 4. No amount of further ROM
reading produces them.
