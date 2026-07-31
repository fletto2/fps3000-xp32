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

## Update 2026-07-31: two register roles closed, and a fifth conversation

### `$FF0000` — window 0's `+$00` now has a mechanism

Listed above without a role. It is a **remaining-word count** that the chassis maintains and the
SBC polls: both S-record error paths (`$F04C22` invalid type, `$F05212` address out of range)
spin `while ($FF0000 > 0) read (a0)` to **drain the rejected record** before issuing their panel
code. The stream read has no post-increment, so `(a0)` is a FIFO port whose reads pop.

Window 0 is therefore complete: `+$00` remaining count, `+$04` ready flag (bit 0), `+$08` data,
`+$0E` command/status.

**Model requirement**: a chassis that streams records must decrement `$FF0000`. Returning a
constant non-zero value hangs the firmware, but *only* on a malformed record — the case least
likely to be exercised.

### A fifth conversation: remote register access

The four conversations listed earlier are joined by one that had been catalogued only by its
dispatch shape:

| # | conversation | initiator | carrier |
|---|---|---|---|
| 5 | **remote register access** | chassis | `$E87` bit 7 = 1 -> `$F0495C`; code `& $1F` indexes the saved frame |

The panel-status ISR saves `movem.l d0-d7/a0-a7` (16 longwords). `$F0495C` scales the chassis's
code by 4 into a byte offset in that frame, uses `$E87` bit 6 as half-select and bit 5 as
direction, and reads or writes through `$FF0204` / `$E74`. Codes 0-15 reach **d0-d7 and a0-a7**;
beyond `$44` the arms reach the **USP** with `move usp,aN` / `move aN,usp`. The exit stub's
`movem.l (a7)+,d0-d7/a0-a7` then loads whatever was poked into the real registers — **including
a7**.

So the chassis's total capability over the SBC is:

- arbitrary memory read/write (chassis op `$6`, no bounds check of any kind)
- chassis memory read/write (op `$3`, `$400000` window)
- **full CPU register read/write including the stack pointer** (conversation 5)
- resume (op `$F`)

**That is a complete remote debugger**, and it answers a question this document raises in "What
this ROM cannot show": how the machine was diagnosed with no console. It was diagnosed from the
host, through the AP I/F, using this protocol.

**Security/modelling note**: there is no validation on this path beyond `0 <= code <= $14`. The
chassis must be modelled as fully trusted, and any emulator asserting these codes must reproduce
the interrupt frame exactly — 16 longwords in `movem.l d0-d7/a0-a7` order followed by the 68000
group-1 exception frame — or it will corrupt the resumed program.

## Update 2026-07-31: the SLC stream port identified

The three upload transports are now all addressed:

| transport | direction | port | framing | handshake |
|---|---|---|---|---|
| SLC S-records (op `$0`, `$E5C = 0`, bit 5 clear) | chassis -> SBC | **`$FF0008`** | S-records, **ASCII hex 2 chars/word** | per word |
| raw bulk (op `$0`, `$E5C = $28`) | chassis -> SBC | **`$FF0008`** | none | per word |
| **readback (op `$0`, `$E87` bit 5 SET)** | **SBC -> chassis** | **`$FF0008`** | none | **NONE** |
| CPLOAD (RDHC command 4) | chassis -> SBC | **`$400000`** page 0 | S-records, binary | none (memory window) |

**The two raw directions are asymmetric**: inbound wraps every word in a full `$FF0218`
arm/poll-bit-15/clear cycle, outbound is a bare `move.w (a1)+,(a0)` loop at bus speed. That fits
`$FF0008` being a hardware FIFO the chassis drains on its own schedule — the SBC must wait for
data but need not wait to push. **A model that expects a handshake on the outbound direction
never sees the data, and one that models `$FF0008` as a register rather than a queue sees only
the last word.**

SLC and raw bulk **share `$FF0008`** and differ in framing and preamble: SLC polls `$FF0004`
bit 0 and declares `$FF020C = 4` before entering the parser, then performs one `$FF0218`
arm/poll-bit-15/clear handshake **per word**. The raw path skips the framing entirely and writes
words straight to the chassis-programmed address in `$E58`, with no bound check.

`$FF0010` remains **never referenced** in any form — an earlier trace appeared to reach it by
chaining two `lea $8(...)` instructions that lie on mutually exclusive branches. The register the
emulator models there has no counterpart in the firmware.

## CORRECTION 2026-07-31: the host mailbox is INSIDE the paged chassis window

This document lists "host mailbox" as its own block, separate from "chassis memory window (paged
via MODE2)". **They are the same window.** `$700000` lies inside `$400000`-`$7FFFFF`, and
TCBIO1I's ISR proves the paging applies:

```
$F05DE6  move.w  $210(a5),d7        save XLTR_MODE2
$F05DEA  move.w  #$F,$210(a5)       select page $F
$F05DF0  move.l  $1C(a4),d1         read  $70001C   (a4 = $700000)
$F05E40  move.l  d1,$20(a4)         write $700020
$F05E44  move.w  d7,$210(a5)        restore XLTR_MODE2
```

**`$70001C` and `$700020` are only meaningful while `XLTR_MODE2 = $F`.** The ISR saves the
incoming page value rather than assuming one, which means other code pages the window
concurrently — RDHC's chassis-memory operations do exactly that.

**Model requirement**: `$FF0210` must gate the mailbox as it gates the rest of the window. A model
that answers `$70001C` unconditionally works by accident in a boot where nothing else pages, and
diverges the moment RDHC issues a chassis-memory operation.

## Independent re-derivation of the complete device set (2026-07-31)

Re-derived from scratch — decoding only at boundaries the listings validate, taking
absolute-long operands, and following every base register loaded with a non-RAM non-ROM
address through its displacement accesses until it is reloaded. **74 distinct addresses**,
and they partition entirely into blocks already in this document:

| block | addresses |
|---:|---|
| XLTR `$FF0200-$FF025F` | 29 |
| AP I/F `$FF0000-$FF00FF` | 20 |
| board `$F70000-$F7003F` | 8 |
| chassis window `$400000` | 4 |
| VMOD `$1FFF0` | 3 |
| mailbox `$70001C`/`$700020` | 2 |
| bus-watchdog target `$F82001` | 1 |

**No device block appears that this document does not already describe**, which is the
result worth having: the map is complete against a method that did not assume it.

Two honest caveats on the seven remaining addresses the sweep produced:

- **`$1FFE2`, `$1FFE4`, `$1FFE6`, `$1FFEA` are RAM, not registers.** They arise from
  *negative* displacements off the `$1FFF0` base. That they are ordinary RAM is exactly
  what the firmware's own exclusion pattern says — eight independent sites skip `$1FFF0`
  and none skips these — so the sweep re-derives the documented RAM/register partition
  rather than contradicting it.
- **`$201F4`, `$3FFFFC` and `$FF4342` are provenance artefacts.** Each is a base plus a
  displacement where the base was last written on a *different* branch than the one
  reaching the access. This is the known limitation recorded with the sweep method — the
  correct base is the most recent write **on the path actually taken**, which a linear
  walk cannot always determine. They are listed here rather than filtered out, because a
  sweep that silently drops what it cannot explain is how a map comes to look complete
  before it is.

**One methodological note, because it cost a full pass.** The first run of this census
returned **7** addresses instead of 74, having excluded everything at or above `$F00000`
as "ROM". ROM is `$F00000-$F0FFFF` only; the board registers at `$F7xxxx` and the whole
AP I/F and XLTR at `$FFxxxx` sit above it. The filter deleted three of the seven device
blocks and the run looked plausible — a clean instance of the failure mode this project
has recorded before, where a too-narrow matcher produces a confident "never accessed".

## The MC6840 PTM: complete register map and three addressing paths (2026-07-31)

All five PTM registers are used, but no single sweep finds them all, because the firmware
addresses the chip **three different ways**:

| path | base | displacements | used by |
|---|---|---|---|
| 1 | literal `$F70001` | **even** (`$2`, `$4`, `$8`, `$C`) | the **self-test** only |
| 2 | config `$F0A52C` = `$F70000` | **odd** (`$1`, `$3`, `$5`, `$D`) | the RTOS initialisation |
| 3 | cached pointer `$0C4E` | odd | the **tick ISR** and the sub-tick clock read |

Both base conventions land on the same odd byte addresses, which is what the chip requires;
they differ only in whether the odd bit lives in the base or the displacement.

| address | register | init | self-test | tick |
|---|---|:-:|:-:|:-:|
| `$F70001` | CR1 / CR3 (PTM address 0, selected by CR2 bit 0) | yes | yes | — |
| `$F70003` | CR2 | yes | yes | — |
| `$F70005` | T1 latch/counter — **loaded with `$0100`** | yes | yes | — |
| `$F70009` | T2 latch/counter | **no** | yes | — |
| `$F7000D` | T3 latch/counter — `$27C7`, the system tick | yes | yes | **read live** |

**T2 is exercised only by the self-test.** This document's earlier statement that "T2 is
never programmed operationally" is correct and now has its complement: it *is* programmed,
by the diagnostics, so a model that omits T2 entirely fails the self-test rather than the
RTOS.

**T3's counter must be readable while running**, because path 3 reads it mid-period for the
lock-free high-resolution clock (`movep.w $D(a0),d1`). A model whose read returns the reload
latch rather than the live count makes `TRAP #0 $1C` return garbage.

**Methodological note.** A sweep keyed on the `$F70001` literal returns *self-test sites
only* and would support the conclusion "the RTOS never touches the PTM" — which is exactly
backwards. The operational paths reach it through a configuration constant and a cached
pointer. This is the third time in this project that a base-register indirection has
produced a confident false negative, after `$FF0204` and the `$FF0048` read.

## There are exactly three cached device pointers (2026-07-31)

Since the PTM turned out to be reached through a cached pointer that no literal sweep sees,
the obvious question is whether any *other* device hides the same way. Enumerating every
global that is dereferenced as a pointer (`movea.l $g,aN`) answers it — 19 globals, and
only three hold device addresses:

| global | device |
|---|---|
| `$0C4E` | the **MC6840 PTM** base, cached at init |
| `$0C3A` | the **display device**, or scratch `$800` when unfitted |
| `$0E48` | the **VERSAmodule control register**, whose address is *computed* from RAM top |

Every other pointer global is an RTOS structure (`$0C20`/`$0C24`/`$0C28`/`$0C2C`/`$0C30`/
`$0C66`/`$0C6A`/`$0C6E`), a scheduler field (`$0C08`/`$0C0C`/`$0C10`/`$0C00`/`$0C78`), the
exception-monitor vector `$0C36`, or FPS transfer state (`$0E58`).

The two entries that look like devices are not: **`$0000` and `$0008` are vector-table
slots**. `$F08AE8` does `movea.l $0.w,a7`, reloading the supervisor stack from the reset
vector, and five sites do `movea.l $8.w,aN` to **save the bus-error vector** before
installing a temporary handler — all six inside the self-test.

Worth noting: this project documented the save/restore of the bus-error vector for the
phase-`$600` watchdog test. There are **five** such sites (`$F08EBA`, `$F08F2A`, `$F09606`,
`$F096C8`, `$F09836`), so temporarily replacing vector 2 is a routine technique in the
diagnostics rather than a one-off — a model must expect `$8.w` to change repeatedly during
the self-test and be restored each time.

**So the device-communication map is closed against the indirection that produced its last
three false negatives**: absolute references, base registers holding literals, base
registers from configuration, and cached pointers have all now been swept.

## The display channel, completely specified (2026-07-31)

The driver at `$F0A344`/`$F0A34A` is thirteen instructions and fully determines what the
optional front-panel display receives:

```
$F0A344: move.w #$10,d0     ; entry A
$F0A34A: move.w #$90,d0     ; entry B -- differs only in bit 7
         not.b  d1          ; INVERT the code
         ror.l  #$4,d1      ; ...and keep its HIGH nibble
         or.b   d1,d0
         move.w #$2,d1 / rol.l #$4,d1        ; d1 = $20
         movea.l $c3a.w,a1 / lea $4(a1),a1   ; the device register
         move.w d1,(a1) / ori.w #$30,d1 / move.w d1,(a1)   ; $20 then $30
         move.w d0,(a1) / ori.w #$30,d0 / move.w d0,(a1)   ; V then V|$30
```

**Only the high nibble of the code, inverted, ever reaches the display.** The low nibble is
discarded by the `ror.l #$4`, so `$BF` and `$B0` are indistinguishable on the panel.

There are exactly **three** driver call sites in the image:

| code | site | when | writes | digit |
|---|---|---|---|---|
| `$BF` | `$F09C54` | during early init, entry B | `$20 $30 $94 $B4` | 4 |
| `$C0` | `$F0A2FC` | after the PTM is running, just before the RTOS handoff | `$20 $30 $13 $33` | 3 |
| `$A2` | `$F0A32E` | **RTOS init failure**, in an endless loop | `$20 $30 $15 $35` | 5 |

**The arithmetic reproduces this project's own measurement.** A dump previously showed
`$0020,$0030,$0013,$0033` landing at `$0804`; feeding `$C0` through entry A gives exactly
that, byte for byte. The driver model and the recorded observation now agree without either
being used to derive the other.

**The write format is `{position nibble, data nibble}` followed by the same value with
`$30` set** — a value-then-strobe pair per digit. The constant first pair is position 2,
data 0; the second pair is position 1 (or 9 — entry B sets bit 7, which is a further flag
the ROM does not otherwise explain) carrying the data nibble.

**A collision that does NOT occur on this machine.** `$F009EA` writes `$15 $35 $2E $3E`
inline, and `$15 $35` is byte-identical to the data pair an `$A2` init failure produces —
so I originally recorded this as an ambiguity to watch for. It is not: `$F009EA` is the
**spurious-interrupt handler** (vector 24), which the FPS layer overrides with the panic
catch-all at `$F0A142`. It never executes, so the display gets no periodic traffic and
nothing overwrites the init reporter's snapshot.

**The display is a boot-only channel**: `$BF`, then `$C0`, or `$A2` looping on failure.

## SBC ↔ SCM: the whole conversation is one self-test routine (2026-07-31)

`$F09B20`-`$F09BB4` is the only code in the ROM that exercises System Common Memory, so it
is the complete specification of what the SBC ever says to the **MEM CTL** and **MAIN DATA**
boards on a machine running stock firmware.

```
clr.w  $210(a6)              ; XLTR_MODE2 = 0  -> chassis window PAGE 0
move.w #$4,d2                ; stride, longwords
lea.l  $400000.l,a2          ; window base
lea.l  $404000.l,a1          ; ...+ $4000  =  16 KB
lea.l  $f09bb6.l,a3          ; pattern table
next:  move.l (a3)+,d0 / move.l (a3)+,d1     ; a PAIR of complementary patterns
fill:  a0 = a2; move.l d0,(a0); a0 += d2; until a0 == a1
walk:  a0 = a2
         move.w d6,$204(a6)                  ; CHANNEL_SELECT <- sub-phase counter
         cmp.l (a0),d0        ; read back the fill
         addq.b #$1,d6 / move.w d6,$204(a6)
         move.l d1,(a0) / cmp.l (a0),d1      ; write the COMPLEMENT, read it back
         a0 += d2; d6 -= 1; until a0 == a1
       if d1 != $AAAAAAAA -> next pattern pair
       else: a2 = $403FFC, a1 = $3FFFFC, neg.w d2   ; ...and repeat DOWNWARD
```

**The pattern table at `$F09BB6`** is `$00000000 / $FFFFFFFF / $55555555 / $AAAAAAAA`,
followed by two zero longwords that are never reached (the `$AAAAAAAA` test ends the set).

**What a chassis model owes:**

- **`$400000`-`$403FFF` must be read/write memory that returns exactly what was written**,
  at longword granularity, with `$FF0210` = 0 selecting page 0. Any bit that does not
  read back sends the test to `$F089EE` with the marker `$F0F0F0F0` in `d7`.
- **16 KB is tested, not the whole window.** The SBC never touches SCM beyond `$403FFF`
  during the self-test, so a model need only back that much for a green boot — though the
  operational path (chassis op `$3`) can page anywhere.
- **Every element writes `$FF0204`** with a rolling sub-phase counter. This is a large part
  of why CHANNEL_SELECT is the hottest register on the board, and it means a chassis model
  sees heavy CHANNEL_SELECT traffic *during memory testing*, not only during commands.
- **The test runs forwards and then backwards.** `neg.w d2` with the bounds swapped to
  `$403FFC`/`$3FFFFC` re-runs every pattern descending, which catches address-line faults a
  single direction would miss. A model that special-cases ascending access patterns breaks
  on the second pass.

Access volume works out at roughly `4096 x (1 fill + 3 walk) x 2 pairs x 2 directions` ≈
**65,000 window accesses**, which is consistent with the ">100k chassis-memory accesses,
always with MODE2 = 0" already measured from the bus log — two independent routes to the
same behaviour.

**This is the boundary of the SBC's reach into the array processor.** It talks to SCM
through the XLTR's paged window; it never addresses the XP-32 EXEC, ARITH or UNIV FMT cards
at all. The machine's own diagnostics draw exactly the same line.

### The SCM test polls the board-status register ~32,000 times

`$F0891C`, called twice per element from the walk loop, is not a checkpoint — it is a
**board-status poll with an abort path**:

```
lea.l  $f70018.l,a2
btst.b #$4,$1(a2)        ; $F70019 bit 4
beq    continue
btst.b #$5,$1(a2)        ; ...and bit 5
bne    $f088f4           ; BOTH set -> abort the test
continue:
tst.l  d7                ; the fault marker
beq    out
lea.l  $1fff0.l,a1
bclr.b #$6,$1(a1)        ; VMOD control $1FFF1 bit 6
move.w #$1000,$202(a6)   ; XLTR MODE1 <- $1000  (bit 12)
out: rts
```

**Emulator consequences, all load-bearing:**

- **`$F70019` is read roughly 32,000 times during the SCM test alone** — twice per element
  across both directions. A model that computes board status expensively will dominate the
  boot's runtime here.
- **Bits 4 and 5 must not both read as set**, or the memory test aborts to `$F088F4` before
  completing. This is a *new* constraint on the board-status model: the documented bit
  equations cover bits 1, 2, 3, 4 and 5 individually, but nothing recorded that their
  *combination* is an abort condition.
- **The failure path manipulates two registers already documented as puzzling**: it clears
  **bit 6 of `$1FFF1`** — one of the 28 bit operations on the VMOD pair this project counted
  — and writes the literal **`$1000` to MODE1**, confirming the note that whole-word MODE1
  literals are self-test-only. Both now have a caller and a reason.

`$F089EE`, the mismatch reporter, does the same two writes and then **retries the failing
write and compare**, so a single transient does not immediately fail the test — the marker
`$F0F0F0F0` in `d7` is what makes the failure sticky.

## `XLTR_MODE2` — the complete paging discipline (2026-07-31, uncapped sweep)

Fourteen access sites, and the firmware only ever *selects* **two** pages:

| region | sites | what |
|---|---|---|
| **RDHC** | `$F05312`/`$F05316`/`$F0567E` | read the current page, set **0**, restore it afterwards |
| **TCBIO1I** | `$F05DE6`/`$F05DEA`/`$F05E44` | read, set **`$F`**, restore — the mailbox window |
| **self-test** | `$F095F8`, `$F0961A`, `$F096DC`, `$F09782`, `$F09AE2`, `$F09B24` | always **0** |
| **init** | `$F0A1E0`/`$F0A1FE` | set **`$F`**, then clear to **0** |

> **CORRECTED 2026-07-31, same day.** The table above lists 14 sites and was built from a
> provenance sweep. Operand-form matching — sound here, since `$210` is a distinctive
> displacement — finds **18**. The four missed sites are all in **chassis operation `$3`**
> (`$F04D4E`, `$F04D74`, `$F04DE8`, `$F04E22`), which this same session decoded separately
> without noticing the two results disagreed.

**Only `$0` and `$F` are ever written as *literals*.** But op `$3` writes a **computed**
page: `move.l $e58,d1 / moveq #$14,d2 / lsr.l d2,d1 / move.w d1,$210(a0)` — the top bits of
whatever 32-bit address the chassis supplied. It saves the previous page on entry and
restores it on exit, which is why a bus log shows values the firmware never names.

**So the claim that "only two pages need backing" is wrong.** Page 0 (SCM, and the window
generally) and page `$F` (the host mailbox) are the only two the firmware *selects by name*,
but **op `$3` can select any page the chassis asks for**, and a model must back whatever the
chassis addresses. That is the whole point of the operation: it is the SBC's arbitrary
read/write path into chassis memory.

The rest of the discipline stands: read the current page, set the one needed, restore it —
now confirmed in **three** places rather than two, since op `$3` brackets a single access
the same way RDHC and TCBIO1I bracket their sequences.

**The discipline is uniform**: read the current value, set the page needed, restore. Three
independent code regions do it the same way, and the self-test — which has the window to
itself — skips the save and simply clears. A model that latches MODE2 without honouring the
restore will diverge only when two users interleave, which is exactly the case the
save/restore exists to handle.

## The board register block is READ-ONLY, and one byte of it does not exist (2026-07-31)

An uncapped sweep of every base register holding `$F70000`/`$F70018`, plus every absolute
reference, gives the complete map of `$F70000`-`$F7003F`:

| address | register | sites | operations |
|---|---|---:|---|
| `$F70001` | PTM CR1 / CR3 | 5 | `move` |
| `$F70003` | PTM CR2 | 5 | `move`, `clr`, `and`, `tst` |
| `$F70005` | PTM T1 | 3 | `movep`, `tst` |
| `$F70009` | PTM T2 | 3 | `movep`, `tst` |
| `$F7000D` | PTM T3 | 3 | `movep`, `tst` |
| `$F70018` | board status, word | 16 | **`move` — reads only** |
| `$F70019` | board status, byte | 16 | **`btst` — tests only** |
| `$F70030` | the kernel's single device access | 2 | `move` read + write |

Two results worth stating plainly:

- **The board status register is never written.** Zero writes through any base register and
  zero absolute writes, across the whole image. `$F70018` is only ever read as a word and
  `$F70019` only ever bit-tested. So an emulator needs no write path for it at all — a
  simplification, and a check on any model that thinks it is handling writes there.
- **`$F7001A` is never referenced.** This project describes the block as "board
  status/control register (PAL-decoded, **28 bits**)", which implies three meaningful bytes.
  The firmware touches two. Whatever the PAL decodes into the third byte, this ROM neither
  reads nor writes it.

Combined with the PTM's three addressing paths and the earlier cached-pointer census, the
`$F7xxxx` device space is now completely mapped: **eight live addresses, one of them
dormant** (`$F70030`, zero executions in a full boot), and nothing else decoded.

## Chassis operation `$3` — the chassis-memory access primitive, fully specified (2026-07-31)

`$F04D4E`-`$F04E36` is the complete read/write path into chassis memory through the paged
window, and it is emulatable as stated:

```
move.w $210(a0),-(a7)          ; SAVE the current page
btst.b #$5,$e87                ; DIRECTION: set = read, clear = write
btst.b #$6,$e87                ; HALF SELECT: which 16 bits the chassis is exchanging

; address computation, identical on both paths:
move.l $e58,d1 / moveq #$14,d2 / lsr.l d2,d1
move.w d1,$210(a0)             ; PAGE  = addr >> 20
move.l $e58,d1 / andi.l #$fffff,d1 / lsl.l #$2,d1
exg.l  d1,a1                   ; OFFSET = (addr & $FFFFF) << 2
cmpa.l #$400000,a1 / bge .
move.l #$400000,d1             ; ...rebased into the window if it is not already
move.l (a1,d1.l),$e70          ; READ  -- a 32-BIT access
move.l $e70,(a1,d1.l)          ; WRITE -- likewise

move.w (a7)+,$210(a0)          ; RESTORE the page
btst.b #$4,$e87 / addq.l #$1,$e58   ; bit 4 auto-increments, by ONE
bra $f050f8                    ; the ISR exit stub
```

Points that matter for a model:

- **The window really is accessed 32 bits at a time.** This is the contrast with the XLTR
  register block, where no `.l` operation exists anywhere: the *registers* are word-only,
  the *memory window* is longword. A model may not treat them the same way.
- **The address is in longword units.** The `<<2` on the offset and the `addq.l #$1` on the
  auto-increment agree: `$0E58` counts longwords, not bytes.
- **Addresses below `$400000` are rebased** by adding the window base, so the chassis may
  name a location either way and get the same result.
- **The page register is saved on entry and restored on exit** — the same discipline as
  RDHC's `$400000` accesses and TCBIO1I's mailbox paging, here with the save and restore
  eleven instructions apart around a single access.
- **The 32-bit value crosses the boundary as two 16-bit halves** in `$0E70`/`$0E72`, selected
  by `$E87` bit 6, with `$0E74` returning the selected half to the chassis. So a full
  longword transfer takes **two** chassis operations, one per half.
