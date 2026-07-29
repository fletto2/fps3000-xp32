# FPS-3000 SBC self-test suite — per-test reference

The firmware's own power-on diagnostics, one entry per test. This is the
most detailed statement anyone has of how the SBC expects the chassis to
behave, because each test is an executable assertion about the hardware.

Two uses:

1. **Hardware bring-up.** Each test says what to drive and what should
   come back. The phase beacon (below) tells you which one failed on a
   real board with no debugger attached.
2. **Emulator/chassis modelling.** The suite is a test harness. Four
   chassis-stub bugs were found by making these pass; see
   `versabus_access_map.md`, "Validation record".

Addresses are ROM addresses in the `FPS3K_U11_U12_JOIN.bin` image.

---

## The phase beacon

Every test writes its progress to **`$FF0204` (CHANNEL_SELECT)** as
`phase << 8 | subtest`, and each subtest increments the low byte. On a
real board, reading or scoping that register during reset tells you
exactly where the firmware is. The **last value written before a hang is
the failing subtest**.

`d6` carries the value; `d7` is the error flag, loaded with `$F0F0F0F0`
on any failure. A test that fails generally re-runs its current subtest
rather than aborting, so a hang with a stable beacon value is a failed
assertion, not a crash.

### The thirteen phases nobody had labelled

The annotation table names phases `$02`-`$17`. Phases `$18`-`$1A` and
`$20`-`$29` had no identity. Combining each phase's entry PC with the chassis
registers it touches:

| phase | entry | touches | reading |
|---|---|---|---|
| `$18` | `$F096D8` | `$FF0216` ×4, `$FF0210` | XLTR **mode/page register** test |
| `$19` | `$F0977E` | `$FF0216` ×4, **`$FF0214` ×2**, `$FF0210` | XLTR **data register** test |
| `$1A` | `$F09846` | **`$FF0218` ×4**, `$FF0216` ×3, `$FF000E` ×3, `$FF020C` ×2 | **status/IRQ + panel-command** test |
| `$20` | `$F098F2` | board status ×4 | short gate |
| `$21` | `$F099B8` | board status ×196,608 | **3 × 64K** loop |
| `$22` | `$F099FA` | board status ×32,768 | 32K loop |
| `$23` | `$F09A84` | board status ×32,768 | 32K loop |
| `$24` | `$F098F2` | *identical to `$20`* | **second pass** |
| `$25` | `$F099B8` | *identical to `$21`* | second pass |
| `$26` | `$F099FA` | *identical to `$22`* | second pass |
| `$27` | `$F09A84` | *identical to `$23`* | second pass |
| `$28` | `$F09ADE` | board status ×26, `$FF0210` ×2, **65,536 + 104 chassis-window accesses** | **major chassis test**, not short |
| `$29` | `$F09B54` | board status ×65,536, **`$F70003` ×7,211, `$F7000D` ×7,209**, `$F70018` ×82 | **chassis-memory** test — see the correction below |

**`$20`-`$23` and `$24`-`$27` are the same four routines run twice**, which the
identical entry PCs make unambiguous. The block-3 setup says what differs:

```
$F0885A  clr.w   d5
$F08862  move.w  #$2000,d6          ; phase $20
$F08866  movea.l #$00000000,a0      ; base
$F0886C  movea.l #$00000400,a1      ; FIRST range start
$F08872  movea.l #$0001F000,a2      ; end
$F08876  bsr     $F08A4A
$F0887C  movea.l #$00010000,a1      ; SECOND range start
$F08882  bsr     $F08992
$F08886  lea     $0800,a7           ; stack reset
$F0888A  move.l  $1F800,$400
```

So the two passes are **RAM tests over `$400`-`$1F000` and then
`$10000`-`$1F000`** — the second covering exactly the WCS staging buffer. A
board that reaches `$24` but hangs in `$25`-`$27` has good low RAM and bad
staging RAM, which is a directly useful split for a bench session.

**Phase `$29` is the only test that touches the MC6840 PTM** (`$F70003` and
`$F7000D`, ~7,200 accesses each), alongside 65,536 board-status reads.

**Correction — it is primarily a chassis-memory test, not merely a timed one.**
The table above was built from the bus log, and **the bus log does not record
the `$400000` paged window at all** — it only counts it. A full boot makes
**131,144 reads and 131,148 writes** to that window, and bounding by cycle
count places essentially all of them in phases `$28`-`$29`: 20 reads / 24
writes by 80M cycles, 131,144 / 131,148 by 200M. The window is referenced from
`$F09AE8`, `$F09B32`, `$F09B38` (`$404000`) and `$F09BA2` (`$403FFC`), all
inside those two phases.

**The emulator now logs the window** (`FPS3K_LOGCHASSIS=1`, off by default —
a full boot emits ~262k lines), and that gives exact attribution rather than
inference. Four program counters do **65,536 accesses each**:

| PC | accesses | phase |
|---|---|---|
| `$F09B48` | 65,536 | `$28` |
| `$F09B58` | 65,536 | `$29` |
| `$F09B70` | 65,536 | `$29` |
| `$F09B72` | 65,536 | `$29` |
| `$F09AF6`, `$F09B00` | 52 each | `$28` |
| `$F0980A`, `$F0981A` | 8 each | `$19` |

So `$29` walks chassis memory through the paged window at three sites and uses
the PTM alongside it — most likely to time or bound the walk.

**And phase `$28` is not "short".** The table above called it that on the
strength of 26 board-status reads; it in fact makes **65,536 + 104 chassis
accesses**, more than any phase except `$29`. That row is corrected. Both
mislabellings — `$29` as timed, `$28` as short — have the same single cause.

**Tooling note worth carrying forward:** any per-phase analysis built from the
bus log is blind to `$400000-$4FFFFF`. That is why the table above shows only
board-status reads for phases `$20`-`$29`, and it is the reason this correction
was needed. The other `$400000` sites — `$F09620`, `$F096E2`, `$F096EA`
(`$400216`), `$F09730` (`$400216`), `$F0978A` — put the window in phases `$17`,
`$18` and `$19` too, which the register table also could not show.

Note these readings come from *which registers each phase touches*, not from
decoding each routine. The register evidence is strong for `$18`-`$1A` and
`$29`, where the touched set is distinctive; `$20`-`$28` are distinguished
mainly by their loop counts and the setup above.

### Measured phase table — 30 phases, and their sub-step counts

Logging every write to `$FF0204` over a full boot gives the complete beacon
sequence. This is the bench fingerprint: a hang at `$0605` is phase 6, sub-step
5, and the table below says phase 6 has 8 sub-steps, so it died two short of
finishing.

| phase | sub-steps | writes | | phase | sub-steps | writes |
|---|---|---|---|---|---|---|
| `$01` | 0..104 | 105 | | `$16` | 0..0 | 1 |
| `$02` | 0..5 | 6 | | `$17` | 0..3 | 4 |
| `$03` | 0..0 | 1 | | `$18` | 0..3 | 4 |
| `$04` | 0..0 | 1 | | `$19` | 0..4 | 5 |
| `$05` | 0..0 | 1 | | `$1A` | 0..2 | 4 |
| `$06` | 0..7 | 8 | | `$20` | 0..1 | 2 |
| `$07` | 0..0 | 1 | | `$21` | 0..5 | 6 |
| `$08` | 0..3 | 4 | | `$22` | 0..0 | 1 |
| `$09` | 0..4 | 5 | | `$23` | 0..0 | 1 |
| `$10` | 0..0 | 1 | | `$24` | 0..1 | 2 |
| `$11` | 0..5 | 6 | | `$25` | 0..5 | 6 |
| `$12` | 0..3 | 4 | | `$26` | 0..0 | 1 |
| `$13` | 0..6 | 7 | | `$27` | 0..0 | 1 |
| `$14` | 0..3 | 4 | | `$28` | 0..0 | 1 |
| `$15` | 0..5 | 6 | | **`$29`** | 0..3 | **32,768** |

**30 phases: `$01`-`$09`, `$10`-`$1A`, `$20`-`$29`.** The numbering is **BCD**
— `$0A`-`$0F` and `$1B`-`$1F` do not exist — with exactly one exception,
`$1A`, which is a twentieth test squeezed in after `$19` rather than rolling
over to `$20`.

Two things stand out for bench use.

**Phase `$29` is a 32,768-iteration loop** and accounts for **99.4%** of the
32,967 beacon writes in a full boot. On a scope the beacon will appear to sit
in `$29xx` for essentially the whole self-test run; that is normal, not a hang.
Anything that stops *below* `$29` stopped early.

**Phase `$01` has 105 sub-steps**, far more than any other. It is the only
phase where a stable low byte is informative on its own — everywhere else the
phase number alone nearly identifies the test.

*Method note: read from a short sample this beacon looks like a plain
monotonically-incrementing counter, because the first hundred values are all
inside phase `$01`'s run. The `phase << 8 | subtest` structure only appears
once the log reaches `$0168 -> $0200`.*

## Control flow and the two checkpoints

```
F08728  wait for board-status bit 4 set        ; chassis ready
F08732  btst #5,$F70019 -> if SET, skip everything
F0873E  $1FFF0 <- 0
F0874E  BLOCK 1: phases $0100-$0900
F087AA  $1FFF0 <- $D0                          ; checkpoint marker
F087AE  MODE1 <- $8000
F087C2  read board status:
          bit4 clear, bit5 clear -> BLOCK 2    (F087D2, phases $1000-$1A00)
          bit4 clear, bit5 set   -> BLOCK 3    (F0885A, phases $2000+)
          bit4 set,   bit5 set   -> F088F4     (skip to exit)
          bit4 set,   bit5 clear -> spin
F08832  $1FFF0 <- $D0                          ; second checkpoint
```

Bit 5 selects **which block runs next**, so it cannot be a combinational
function of VMOD — it must be clear at the first checkpoint and set at
the second. Modelled as the chassis counting `$D0` markers.

`PollBoardStatus` (F0891C) is called after nearly every subtest: it reads
`$F70019`, and if bit 4 is set **and** bit 5 is set it abandons the suite
via `bra F088F4`. Any chassis that raises bit 5 mid-run kills the tests.

---

## Block 1 — CPU, memory and board plumbing

### Phase `$0100` — CPU arithmetic and condition codes (F08B36-F08C49)

82 instructions, 6 error sites, 105 subtests — the longest by subtest
count. Pure CPU: `subi.l #$80000000`, checks `V` via `bvc`, compares
against `$80000000`, and works through constants `$1234`, `$FEDC`,
`$FF00`, `$FF`. Touches no hardware except the beacon.

**Asserts:** the 68000 core sets overflow/carry correctly on signed
boundary arithmetic. Useful as an emulator core check — a CPU model with
wrong flag semantics fails here before any chassis code runs.

### Phase `$0200` — VMOD ↔ board-status handshake (F08C4A-F08D19)

The most important test for chassis modelling. `d0 = 6`, `d1 = 3`,
`a5 = $1FFF0`, `a4 = $F70018`.

| Step | Action | Expected |
|---|---|---|
| F08C66 | `bclr #6,$1FFF1`, read back | bit 6 reads **0** |
| F08C84 | `bclr #6,$1FFF1`, test board bit 3 | board bit 3 reads **1** |
| F08CA2 | `bset #6,$1FFF1`, read back | bit 6 reads **1** |
| F08CC0 | `bset #6,$1FFF1`, test board bit 3 | board bit 3 reads **0** |

**Asserts:** `$F70019` bit 3 is the **inverse** of `$1FFF1` bit 6. This
is a real chassis wire, and it is the anchor for every other
board-status bit relationship.

### Phase `$0300` — ROM readback (F08D1A-F08D5D)

Walks `$F00000` to `$F10000` with `d0 = $FFFF`. Reads the whole 64 KB ROM
image. **Asserts:** ROM is readable across its full range and decodes
consistently. Despite the label on the *next* test, this is the closest
thing to a ROM integrity pass; there is still **no checksum** anywhere.

### Phase `$0400` — RAM addressing (F08D5E-F08DF7, `RAMAddressingTest`)

Writes `$8000` to address `$8000`, then byte `$00` at `$10000`, byte
`$01` at `$10001`, word `$0002` at `$10002`, and re-reads via `a0 =
$10000` with `d1 = 4`.

**Asserts:** no address aliasing between `$8000` and `$10000`, and that
byte and word accesses land on the right lanes. A RAM model that mirrors
or drops A15/A16 fails here.

### Phase `$0500` — board status mask (F08DF8-F08E2D)

Reads `$F70018`, masks `$3F31`, compares `$3F11`, polls until it matches.
Then `PTMInit`.

**Asserts:** `(board_status & $3F31) == $3F11`. This is the routine the
disassembly labels `ROMChecksumTest`; **it never touches ROM**. The
correct name is `BoardStatusPoll_3F11` and the old label has caused
repeated confusion about a ROM checksum that does not exist.

### Phase `$0600` — VMOD longword pattern walk (F08E2E-F08EAB)

Installs `F088FC` at vectors 2 and 3 (bus/address error), fills vectors
`$10`-`$3FF` with it, raises the mask to level 7 (`ori #$700,sr`), then
writes eight longwords to `$1FFF0` and reads each back:

```
0010FFFF  009F00FF  0F1F0F0F  33133333
AA9AAAAA  55155555  FF9FFFFF  00100000
```

**Asserts:** the VMOD control register round-trips all bit patterns.

**Note the pattern design:** the byte landing in `$1FFF1` is `$10, $9F,
$1F, $13, $9A, $15, $9F, $10` — **bit 6 is clear in all eight** while
bit 7 varies. The author deliberately avoided disturbing bit 6, the line
phase `$0200` proved drives board bit 3. That constraint is what proves
board bit 5 is not a mirror of either bit.

### Phase `$0700` — short-I/O bus error (F08F1C-F08F6F)

Saves vector `$8`, installs `F08F06`, probes `$F82001`.

**Asserts:** the VERSAbus short-I/O window at `$F82000+` **bus-errors**
when no board answers. The test wants the fault, not the data.

### Phase `$0800` — I/O channel (F08F70-F09059, `IOChannelDiagnostic`)

4 error sites; constants `$144` (a vector address) and `$F8FF`. Exercises
the I/O Channel window with board status and VMOD.

**Asserts:** the I/O Channel region behaves as unpopulated in this
chassis. Per the M68KVM02 memory map, `$F80000-$F81FFF` holds no boards.

### Phase `$0900` — PTM interrupt (F0905A-F0918B)

The most intricate test in block 1.

```
PTMInit                        ; CR2 <- 1, CR1 <- 1 (internal reset)
vector $150 <- F0911E          ; the handler
bset #7,$1FFF1                 ; enable PTM IRQ propagation
sr <- $2400                    ; allow level 5+
subtests 0-2: one timer at a time via $4(a0)/$8(a0)/$c(a0)
subtests 3-4: all three at once —
    latches T1,T2,T3 <- $0FFF  (movep.w to $4/$8/$c)
    CR2 <- $00   (reg0 now selects CR3)
    CR3 <- $C2
    CR2 <- $C3   (reg0 now selects CR1)
    CR1 <- $C2   (bit 0 clear: releases the internal reset)
    wait for the handler to set d2, timeout $5FFF
```

Handler F0911E reads the status register, and on subtest 3 requires
`status & 7 == 7` — **all three timers expiring together**.

**Asserts, in order of how easily a model gets them wrong:**
1. CR1 bit 0 is a **single internal reset for all three timers**, not a
   per-timer halt. CR2 bit 0 is the reg-0 address select; CR3 bit 0 is
   the T3 prescaler.
2. Setting the internal reset **clears the interrupt flags**. Without
   this the handler cannot dismiss its own interrupt on the subtest-3
   path, which reads status but not the counters.
3. Three timers loaded with equal latches expire on the same tick.
4. `$1FFF1` bit 7 gates PTM interrupt propagation to the CPU.

---

## Block 2 — panel bus, XLTR and the chassis window

### Phase `$1000` — memory bus probe (F08EAC-F08F1B, `MemBusProbe`)

Saves vector `$8`, installs `F08F06`, walks from `$1FFF0` and `$F00000`.
**Asserts:** unpopulated regions bus-error and populated ones do not —
the boundary map of the address space.

### Phase `$1100` — panel bus, VMOD bit 4 (F0918C-F09235)

`d0 = 4`, `d1 = 1`. Same shape as phase `$0200` one bit over.
**Asserts:** `$F70019` bit 1 responds to `$1FFF1` bit 4.

### Phase `$1200` — level-2 interrupt (F09236-F09337)

`bclr #7,$1FFF1`, `sr <- $2200` (allow level 3+), vector `$14C <- F09330`,
and stores `$14C >> 2` into `-$a(a5)` = `$1FFE6`.
**Asserts:** a chassis interrupt arrives at the programmed vector with
PTM propagation disabled.

### Phase `$1300` — dual-vector interrupt (F09338-F093CD)

Vectors `$148 <- F093C8` and `$140 <- F093BE`, constants `$FFF8`, `$F8FF`,
`$F0F0`. **Asserts:** two distinct chassis interrupt sources reach two
distinct vectors.

### Phase `$1400` — panel-bus interrupt with status (F093CE-F094EF)

Same vectors as `$1300` plus board status. 4 error sites.
**Asserts:** interrupt assertion is reflected in `$F70019` and clears
correctly.

### Phase `$1500` — CHANNEL_SELECT readback (F094F0-F09517)

Six subtests (`d6` 0..5): write `d6` to `$FF0204`, read it straight back,
compare. **Asserts:** CHANNEL_SELECT is a plain read/write register from
the SBC's side. Any chassis model that overwrites it — for instance by
arming a panel response — fails here.

### Phase `$1600` — XLTR register file (F09518-F09601)

```
d0 = STATUS_IRQ; btst #4
   bit 4 clear -> d1 = $D0   (16 BIM registers)
   bit 4 set   -> d1 = $D8   (24 BIM registers)
MODE1 <- $2000, MODE0 <- 0, COUNTER <- 1, STATUS_IRQ <- $400, IRQ_MASK <- $FFF
write $10,$20,$40,$80 to $210,$212,$214,$216
write $C0.. incrementing to $230,$232,... until d0 == d1
then read every one back and compare
```

**Asserts:**
- **Bit 4 of `XLTR_STATUS_IRQ` reports the BIM population** — 16 or 24
  registers, i.e. two BIMs or three. This card is "V-BUS XLTR 3 BIMS", so
  the bit should read set on real hardware.
- MODE1 reads back `$2000`; **MODE0's low byte reads back 0**;
  COUNTER reads back `$1`; `STATUS_IRQ & $610 == $400`; IRQ_MASK reads
  `$FFF`; and `$210`-`$216` plus the whole BIM block round-trip.

The MODE0 assertion is the sharp one: a chassis that puts a response code
into MODE0's low bits during a register walk fails this test.

### Phases `$1700`/`$1800` — chassis window access control (F09602-F096C3, F096C4-F096C3)

Both save vector `$8` and install `F098E0`, a bus-error handler, then set
`MODE2 <- 0`, point at `$400000`, and vary `DATA_HI` (`$FF0216`):
`$20`, `$00`, `$40`, `$10`, `$80`.

**Asserts:** `DATA_HI` selects whether the `$400000` chassis window
answers or bus-errors. `$20` selects an unpopulated page (fault
expected); other values select populated pages. The firmware installs its
own handler because **it expects the fault** — three bus errors during a
healthy boot are correct behaviour.

### Phase `$1900` — chassis memory data (F09776-F09831)

`MODE2 <- 0`, `a0 = $400000`, writes `$55555555`, reads back and compares;
then `$AAAA5555` with `DATA_HI <- $10`; also uses `DATA_LO` (`$FF0214`).

**Asserts:** the chassis memory window round-trips full 32-bit data with
both alternating-bit patterns — the classic stuck/shorted data-line test.

### Phase `$1A00` — AP I/F and transfer control (F09832-F098DF)

Installs the same BERR handler, touches `$FF00FF`, `STATUS_IRQ` and
`COUNTER`. **Asserts:** the AP I/F window responds and the
arm/poll/clear cycle on `STATUS_IRQ` works.

---

## Block 3 — RAM integrity, and two tests that never run

Block 3 starts at F0885A with `$1FFF0 <- 0`, `MODE1 <- $2000`,
`d6 = $2000`, then:

```
a0=$0, a1=$400, a2=$1F000
F08878  bsr F08A4C     ; save the vector table $0-$400 to $1F000
a1=$10000
F08882  bsr F08992     ; -> F098EC, the RAM address-uniqueness test
F08886  a7 <- $800     ; rebuild the stack afterwards
F0888A  restore $400 from $1F800
        ... further block moves over $1F000/$1F400/$10000/$20000
F088B8  phase $2100    ; F08992 again
F088C0  phase $2200    ; F09AD6
F088C8  phase $2300    ; F09B20
```

### Phase `$2000` — RAM address uniqueness (F098EC)

`move.l a0,(a0)+` from `$0` to `$10000`, writing **each address into
itself**, with `$1FFF0` explicitly skipped (F098FE) so the VMOD control
register is not clobbered. Then reads back and compares.

**Asserts:** every RAM location is independently addressable — the
strongest form of the address-decode test, catching any aliasing that
phase `$0400`'s spot checks would miss. Note it deliberately destroys the
vector table, which is why the caller saves `$0-$400` to `$1F000` first
and rebuilds the stack at `$800` afterwards.

### Phases `$2100`-`$2900` — the rest of block 3

An earlier revision said these were "not reached". They are, once the
checkpoint indication is modelled as a **pulse** rather than a level: the
suite now runs `$0100` through `$2903` and ends in Phase2Init.

The bug was in our chassis model, not the firmware. Board bit 5 was
latched permanently after the second `$D0` marker, and `PollBoardStatus`
aborts whenever bit 4 **and** bit 5 are both set — so every call in
block 3 took the `bra F088F4` exit and cut the block short. The marker is
consumed by the next non-`$D0` write to `$1FFF1` (block 3 opens with
`clr.w (a5)` at F0885A) and re-asserted by the next `$D0`. Three markers
are written in a full boot: F087AA, F08832 and F088CC.

**Phase `$2500`-ish contains a DRAM retention test.** F09AA4 loads
`d5 = $493E0` — exactly **300,000** — and spins it down before
`cmp.l (a2)+,d0`. Write a pattern, wait roughly 0.4 s at 8 MHz, then
re-read and compare. It is not a hang, and an emulator run needs a cycle
budget past ~200 M to get through it; shorter runs stop inside the delay
and look wedged.

### Phases `$2200` (F09AD6) and `$2300` (F09B20)

**These do not execute in a normal boot**, and an earlier revision of
this file listed them as phases `$1C00`/`$1D00`, which was wrong on both
the numbering and the fact. Tracing `d6` gives `$2200` and `$2300`; the
measured trace shows F08886 never executing, so control leaves F08992
without returning and arrives at F088F4 (`jmp Phase2Init`).

- **`$2200` (F09AD6)** — `MODE2 <- 0`, `a0 = $400000`, length `$4000`,
  4 passes. Sustained 16 KB access to chassis memory.
- **`$2300` (F09B20)** — `a2 = $400000`, `a1 = $404000`, `d2 = 4`, also
  touching `$403FFC`. Asserts `$400000` and `$404000` are distinct
  memory, i.e. A14 decoded and no 16 KB wrap.

Both now execute, and the chassis window is genuinely exercised. An
earlier revision flagged that the bus log records **zero** accesses in
the `$4xxxxx` range; that was a **logging artifact**, not a behavioural
gap. The `$400000` window is served inside `bus_read8`/`bus_write8`
before the device dispatch, so it never passes through `log_access`.
Counting it directly gives, over a full boot:

```
chassis window $400000: 131,144 reads, 131,148 writes, 1 BERR
```

Reads and writes are balanced to within four accesses, which is the
signature of write-then-read-back testing, and the single bus error is
the access-denied check. So phases `$1700`-`$2300` do exercise the window
hard, and the model satisfying them is real validation.

The lesson generalises: **`-bus` only logs device-window accesses**.
Anything served directly from `ram[]` or `chassis_mem[]` is invisible to
it, so "zero accesses in the log" never by itself means "never touched".
The `FPS3K_UNINIT` and `FPS3K_RAMWATCH` hooks exist for that reason.

Why control never returns from the `$2000` test is unresolved. The stack
at `$1FFD0` is above the test's `$0-$10000` range so it is not
overwritten, but the vector table within that range is, so any interrupt
taken during the window dispatches through garbage. The boot recovers and
completes — zero error flags, all six task vectors correct — but the last
two chassis-memory tests are skipped, and on real hardware they would be
the ones that exercise the `$400000` window hardest.

---

## Quick reference: what a hang means

| Beacon (`$FF0204`) | Suspect |
|---|---|
| `$01xx` | CPU core — flags/arithmetic, before any chassis access |
| `$0200`-`$0205` | `$1FFF1` bit 6 ↔ `$F70019` bit 3 wiring |
| `$0300` | ROM decode |
| `$0400` | RAM address decode / byte lanes |
| `$0500` | board status not reaching `(x & $3F31) == $3F11` |
| `$0600` | VMOD register not round-tripping a pattern |
| `$0700` | short-I/O window not bus-erroring |
| `$0800` | I/O channel |
| `$0900` | MC6840 PTM, its interrupt path, or `$1FFF1` bit 7 gating |
| `$1000` | address-space boundary map |
| `$11xx`-`$14xx` | panel-bus interrupts and vectors |
| `$1500` | CHANNEL_SELECT not a clean read/write register |
| `$1600` | XLTR register file or BIM population bit |
| `$17xx`/`$18xx` | `DATA_HI` page gating on the `$400000` window |
| `$1900` | chassis memory data lines |
| `$1A00` | AP I/F window |
| `$1C00`/`$1D00` | chassis memory bulk access or A14 decode |

## Registers the suite proves are real

Everything below is asserted by at least one test, so a working board
must implement it:

| Register | Established behaviour |
|---|---|
| `$1FFF0`/`$1FFF1` | VMOD control; bit 6 drives board bit 3 inverted; bit 7 gates PTM IRQ; full 16-bit round-trip |
| `$F70019` bit 1 | responds to `$1FFF1` bit 4 |
| `$F70019` bit 3 | inverse of `$1FFF1` bit 6 |
| `$F70019` bit 4 | chassis ready/engaged |
| `$F70019` bit 5 | test-block selector at the checkpoints; abort signal in `PollBoardStatus` |
| `$F70018/19` | `(x & $3F31) == $3F11` at phase `$0500` |
| `$FF0200` MODE0 | low byte reads 0 when idle |
| `$FF0202` MODE1 | reads back written value; bit 15 arms a chassis operation |
| `$FF0204` CHANNEL_SELECT | plain read/write; carries the phase beacon |
| `$FF020C` COUNTER | reads back written value |
| `$FF0210` MODE2 | chassis page select |
| `$FF0214`/`$FF0216` | DATA_LO / DATA_HI; `$216` gates `$400000` access |
| `$FF0218` STATUS_IRQ | bit 4 = BIM population (16 vs 24 regs); `& $610 == $400` after arming |
| `$FF021A` IRQ_MASK | reads back `$FFF` |
| `$FF0230`-`$FF025F` | BIM registers round-trip |
| `$400000+` | chassis memory; paged by MODE2/DATA_HI; A14 decoded |

---

# Measured address traffic, per test

Every device access made by each test, captured from a full emulator boot
with the bus logger tagging each access with the PC that issued it
(`FPS3K_BUSPC=1`), then bucketed by which test routine owns that PC.

This is **measured, not inferred** — it is what the firmware actually
does, with the values it actually sees. Use it to check the address map
against the parts list and datasheets: any address here must be decoded
by some device on the board, and the widths say how wide that decode has
to be.

Two caveats. First, the values in the "seen" column are what *our chassis
model* returned, so treat read values as "what satisfies the firmware",
not "what the real board returns" — the write values and the addresses
are hardware facts either way. Second, only accesses issued from inside
each test's own address range are attributed to it; work done in shared
helpers (`PollBoardStatus`, `PTMInit`) is attributed to the helper's
range, which is why the beacon write often dominates a short test.

Interpreting the `$0200` rows as a worked example: `$01FFF1` is written
`$00` and `$40` (bit 6 clear, then set) and `$F70019` reads back `$1F`
and `$17` — bit 3 set, then clear. That is the inverse relationship the
test asserts, visible directly in the traffic.

**Phase `$0100`**

| Address | Width | Dir | Count | Values seen | Register |
|---|---|---|---|---|---|
| `$FF0204` | 16 | write | 4 | $165, $166, $167, $168 | XLTR_CHANNEL_SELECT |

**Phase `$0200`**

| Address | Width | Dir | Count | Values seen | Register |
|---|---|---|---|---|---|
| `$01FFF1` | 8 | read | 9 | $00, $40 |  |
| `$01FFF1` | 8 | write | 6 | $00, $40 |  |
| `$F70019` | 8 | read | 3 | $17, $1F |  |
| `$FF0204` | 16 | write | 6 | $200, $201, $202, $203… | XLTR_CHANNEL_SELECT |

**Phase `$0300`**

| Address | Width | Dir | Count | Values seen | Register |
|---|---|---|---|---|---|
| `$FF0204` | 16 | write | 1 | $300 | XLTR_CHANNEL_SELECT |

**Phase `$0400`**

| Address | Width | Dir | Count | Values seen | Register |
|---|---|---|---|---|---|
| `$FF0204` | 16 | write | 1 | $400 | XLTR_CHANNEL_SELECT |

**Phase `$0500`**

| Address | Width | Dir | Count | Values seen | Register |
|---|---|---|---|---|---|
| `$F70018` | 16 | read | 1 | $3F1F |  |
| `$FF0204` | 16 | write | 1 | $500 | XLTR_CHANNEL_SELECT |

**Phase `$0600`**

| Address | Width | Dir | Count | Values seen | Register |
|---|---|---|---|---|---|
| `$01FFF0` | 8 | read | 8 | $00, $0F, $33, $55… |  |
| `$01FFF0` | 8 | write | 8 | $00, $0F, $33, $55… |  |
| `$01FFF1` | 8 | read | 8 | $10, $13, $15, $1F… |  |
| `$01FFF1` | 8 | write | 8 | $10, $13, $15, $1F… |  |
| `$FF0204` | 16 | write | 8 | $600, $601, $602, $603… | XLTR_CHANNEL_SELECT |

**Phase `$0700`**

| Address | Width | Dir | Count | Values seen | Register |
|---|---|---|---|---|---|
| `$FF0204` | 16 | write | 1 | $700 | XLTR_CHANNEL_SELECT |

**Phase `$0800`**

| Address | Width | Dir | Count | Values seen | Register |
|---|---|---|---|---|---|
| `$01FFF0` | 8 | read | 5 | $00, $02 |  |
| `$01FFF0` | 8 | write | 5 | $00, $02 |  |
| `$01FFF1` | 8 | read | 10 | $10, $90 |  |
| `$01FFF1` | 8 | write | 10 | $10, $90 |  |
| `$F70019` | 8 | read | 49 | $15, $1D |  |
| `$FF0204` | 16 | write | 4 | $800, $801, $802, $803 | XLTR_CHANNEL_SELECT |

**Phase `$0900`**

| Address | Width | Dir | Count | Values seen | Register |
|---|---|---|---|---|---|
| `$01FFF1` | 8 | read | 2 | $10, $90 |  |
| `$01FFF1` | 8 | write | 2 | $10, $90 |  |
| `$F70001` | 8 | write | 9 | $01, $C2 |  |
| `$F70003` | 8 | write | 9 | $00, $01, $C3 |  |
| `$F70005` | 8 | read | 16 | $00, $01, $02, $04… |  |
| `$F70005` | 8 | write | 18 | $00, $01, $02, $04… |  |
| `$F70007` | 8 | read | 16 | $00, $01, $02, $04… |  |
| `$F70007` | 8 | write | 18 | $00, $01, $02, $04… |  |
| `$F70009` | 8 | read | 16 | $00, $01, $02, $04… |  |
| `$F70009` | 8 | write | 18 | $00, $01, $02, $04… |  |
| `$F7000B` | 8 | read | 16 | $00, $01, $02, $04… |  |
| `$F7000B` | 8 | write | 18 | $00, $01, $02, $04… |  |
| `$F7000D` | 8 | read | 16 | $00, $01, $02, $04… |  |
| `$F7000D` | 8 | write | 18 | $00, $01, $02, $04… |  |
| `$F7000F` | 8 | read | 16 | $00, $01, $02, $04… |  |
| `$F7000F` | 8 | write | 18 | $00, $01, $02, $04… |  |
| `$FF0204` | 16 | write | 5 | $900, $901, $902, $903… | XLTR_CHANNEL_SELECT |

**Phase `$1000`**

| Address | Width | Dir | Count | Values seen | Register |
|---|---|---|---|---|---|
| `$FF0204` | 16 | write | 1 | $1000 | XLTR_CHANNEL_SELECT |

**Phase `$1100`**

| Address | Width | Dir | Count | Values seen | Register |
|---|---|---|---|---|---|
| `$01FFF1` | 8 | read | 10 | $00, $10 |  |
| `$01FFF1` | 8 | write | 7 | $00, $10 |  |
| `$F70019` | 8 | read | 3 | $1D, $1F |  |
| `$FF0204` | 16 | write | 6 | $1100, $1101, $1102, $1103… | XLTR_CHANNEL_SELECT |

**Phase `$1200`**

| Address | Width | Dir | Count | Values seen | Register |
|---|---|---|---|---|---|
| `$01FFF0` | 8 | read | 3 | $00, $01 |  |
| `$01FFF0` | 8 | write | 3 | $00, $01 |  |
| `$01FFF1` | 8 | read | 40 | $10, $30, $90, $B0 |  |
| `$01FFF1` | 8 | write | 8 | $10, $30, $90, $B0 |  |
| `$F70019` | 8 | read | 4 | $19, $1B, $1D |  |
| `$FF0204` | 16 | write | 4 | $1200, $1201, $1202, $1203 | XLTR_CHANNEL_SELECT |

**Phase `$1300`**

| Address | Width | Dir | Count | Values seen | Register |
|---|---|---|---|---|---|
| `$01FFF0` | 16 | read | 15 | $30, $B0, $B1, $B2… |  |
| `$01FFF0` | 16 | write | 15 | $30, $B0, $B1, $B2… |  |
| `$01FFF1` | 8 | read | 2 | $30, $B0 |  |
| `$01FFF1` | 8 | write | 2 | $30, $B0 |  |
| `$FF0204` | 16 | write | 7 | $1300, $1301, $1302, $1303… | XLTR_CHANNEL_SELECT |

**Phase `$1400`**

| Address | Width | Dir | Count | Values seen | Register |
|---|---|---|---|---|---|
| `$01FFF0` | 16 | read | 8 | $39, $B0, $B8, $B9 |  |
| `$01FFF0` | 16 | write | 8 | $38, $B0, $B1, $B8… |  |
| `$01FFF1` | 8 | read | 11 | $30, $31, $38, $B0… |  |
| `$01FFF1` | 8 | write | 11 | $30, $31, $39, $B0… |  |
| `$F70019` | 8 | read | 2 | $1B, $1F |  |
| `$FF0204` | 16 | write | 4 | $1400, $1401, $1402, $1403 | XLTR_CHANNEL_SELECT |

**Phase `$1500`**

| Address | Width | Dir | Count | Values seen | Register |
|---|---|---|---|---|---|
| `$FF0204` | 16 | read | 6 | $1500, $1501, $1502, $1503… | XLTR_CHANNEL_SELECT |
| `$FF0204` | 16 | write | 6 | $1500, $1501, $1502, $1503… | XLTR_CHANNEL_SELECT |

**Phase `$1600`**

| Address | Width | Dir | Count | Values seen | Register |
|---|---|---|---|---|---|
| `$01FFF0` | 16 | write | 1 | $00 |  |
| `$FF0200` | 16 | read | 1 | $00 | XLTR_MODE0 |
| `$FF0200` | 16 | write | 1 | $00 | XLTR_MODE0 |
| `$FF0202` | 16 | read | 1 | $2000 | XLTR_MODE1 |
| `$FF0202` | 16 | write | 1 | $2000 | XLTR_MODE1 |
| `$FF0204` | 16 | read | 1 | $1600 | XLTR_CHANNEL_SELECT |
| `$FF0204` | 16 | write | 1 | $1600 | XLTR_CHANNEL_SELECT |
| `$FF020C` | 16 | read | 1 | $01 | XLTR_COUNTER |
| `$FF020C` | 16 | write | 1 | $01 | XLTR_COUNTER |
| `$FF0210` | 16 | read | 1 | $10 | XLTR_MODE2 |
| `$FF0210` | 16 | write | 2 | $00, $10 | XLTR_MODE2 |
| `$FF0212` | 16 | read | 1 | $20 | XLTR_unknown |
| `$FF0212` | 16 | write | 1 | $20 | XLTR_unknown |
| `$FF0214` | 16 | read | 1 | $40 | XLTR_DATA_LO |
| `$FF0214` | 16 | write | 1 | $40 | XLTR_DATA_LO |
| `$FF0216` | 16 | read | 1 | $80 | XLTR_DATA_HI |
| `$FF0216` | 16 | write | 1 | $80 | XLTR_DATA_HI |
| `$FF0218` | 16 | read | 2 | $00, $8400 | XLTR_STATUS_IRQ |
| `$FF0218` | 16 | write | 1 | $400 | XLTR_STATUS_IRQ |
| `$FF021A` | 16 | read | 1 | $FFF | XLTR_IRQ_MASK |
| `$FF021A` | 16 | write | 1 | $FFF | XLTR_IRQ_MASK |
| `$FF0230` | 16 | read | 1 | $C0 | XLTR_unknown |
| `$FF0230` | 16 | write | 1 | $C0 | XLTR_unknown |
| `$FF0232` | 16 | read | 1 | $C1 | XLTR_unknown |
| `$FF0232` | 16 | write | 1 | $C1 | XLTR_unknown |
| `$FF0234` | 16 | read | 1 | $C2 | XLTR_unknown |
| `$FF0234` | 16 | write | 1 | $C2 | XLTR_unknown |
| `$FF0236` | 16 | read | 1 | $C3 | XLTR_unknown |
| `$FF0236` | 16 | write | 1 | $C3 | XLTR_unknown |
| `$FF0238` | 16 | read | 1 | $C4 | XLTR_unknown |
| `$FF0238` | 16 | write | 1 | $C4 | XLTR_unknown |
| `$FF023A` | 16 | read | 1 | $C5 | XLTR_unknown |
| `$FF023A` | 16 | write | 1 | $C5 | XLTR_unknown |
| `$FF023C` | 16 | read | 1 | $C6 | XLTR_unknown |
| `$FF023C` | 16 | write | 1 | $C6 | XLTR_unknown |
| `$FF023E` | 16 | read | 1 | $C7 | XLTR_unknown |
| `$FF023E` | 16 | write | 1 | $C7 | XLTR_unknown |
| `$FF0240` | 16 | read | 1 | $C8 | XLTR_unknown |
| `$FF0240` | 16 | write | 1 | $C8 | XLTR_unknown |
| `$FF0242` | 16 | read | 1 | $C9 | XLTR_unknown |
| `$FF0242` | 16 | write | 1 | $C9 | XLTR_unknown |
| `$FF0244` | 16 | read | 1 | $CA | XLTR_CH1_CONFIG |
| `$FF0244` | 16 | write | 1 | $CA | XLTR_CH1_CONFIG |
| `$FF0246` | 16 | read | 1 | $CB | XLTR_CH2_CONFIG |
| `$FF0246` | 16 | write | 1 | $CB | XLTR_CH2_CONFIG |
| `$FF0248` | 16 | read | 1 | $CC | XLTR_unknown |
| `$FF0248` | 16 | write | 1 | $CC | XLTR_unknown |
| `$FF024A` | 16 | read | 1 | $CD | XLTR_unknown |
| `$FF024A` | 16 | write | 1 | $CD | XLTR_unknown |
| `$FF024C` | 16 | read | 1 | $CE | XLTR_unknown |
| `$FF024C` | 16 | write | 1 | $CE | XLTR_unknown |
| `$FF024E` | 16 | read | 1 | $CF | XLTR_unknown |
| `$FF024E` | 16 | write | 1 | $CF | XLTR_unknown |

**Phase `$1700`**

| Address | Width | Dir | Count | Values seen | Register |
|---|---|---|---|---|---|
| `$FF0204` | 16 | write | 4 | $1700, $1701, $1702, $1703 | XLTR_CHANNEL_SELECT |
| `$FF0210` | 16 | write | 1 | $00 | XLTR_MODE2 |
| `$FF0216` | 16 | write | 4 | $00, $20 | XLTR_DATA_HI |

**Phase `$1800`**

| Address | Width | Dir | Count | Values seen | Register |
|---|---|---|---|---|---|
| `$FF0204` | 16 | write | 4 | $1800, $1801, $1802, $1803 | XLTR_CHANNEL_SELECT |
| `$FF0210` | 16 | write | 1 | $00 | XLTR_MODE2 |
| `$FF0216` | 16 | write | 4 | $00, $40 | XLTR_DATA_HI |

**Phase `$1900`**

| Address | Width | Dir | Count | Values seen | Register |
|---|---|---|---|---|---|
| `$FF0204` | 16 | write | 5 | $1900, $1901, $1902, $1903… | XLTR_CHANNEL_SELECT |
| `$FF0210` | 16 | write | 1 | $00 | XLTR_MODE2 |
| `$FF0214` | 16 | write | 2 | $AAAA | XLTR_DATA_LO |
| `$FF0216` | 16 | write | 4 | $00, $10 | XLTR_DATA_HI |

**Phase `$1A00`**

| Address | Width | Dir | Count | Values seen | Register |
|---|---|---|---|---|---|
| `$FF000E` | 16 | read | 2 | $AAAA | APIF_CMD_ARG_LO |
| `$FF000E` | 16 | write | 1 | $AAAA | APIF_CMD_ARG_LO |
| `$FF0204` | 16 | write | 5 | $1A00, $1A01, $1A02, $2000 | XLTR_CHANNEL_SELECT |
| `$FF020C` | 16 | write | 2 | $FF | XLTR_COUNTER |
| `$FF0216` | 16 | write | 3 | $00, $80 | XLTR_DATA_HI |
| `$FF0218` | 16 | write | 4 | $00, $400 | XLTR_STATUS_IRQ |
