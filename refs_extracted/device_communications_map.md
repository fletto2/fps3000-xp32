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
| `$FF0214` | DATA hi half |  | 4 |  |  | 12 |  | 3 |
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

