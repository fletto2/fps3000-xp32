# What a chassis model must implement

Consolidated from the SBC ROM alone, 2026-07-31. Every statement here is traceable to an
instruction in `FPS3K_U11_U12_JOIN.bin`; the derivations are in `versabus_access_map.md`.

This is the *counterparty* specification — what the hardware on the other side of the AP I/F and
the XLTR must do for this firmware to run. It is not a description of the SBC.

---

## 1. Registers: which are split, which are latches

Three registers on this board have **different read and write sides** and must not be modelled as
storage:

| register | write side | read side |
|---|---|---|
| `$FF0202` MODE1 | 4 command words (self-test only) + 21 operational read-modify-writes | status; bit 7 = busy |
| `$FF0204` CHANNEL_SELECT | the SBC's phase broadcast, command echo and result return | **the chassis's argument port** — 20 read sites latch it into 9 private globals |
| `$1FFF0`/`$1FFF1` VMOD | 28 bit operations | **chassis-mediated image**, per the board manual |

Everything the SBC writes to `$FF0204` is *outbound telemetry*; every read expects a
chassis-supplied value. The only place the firmware reads back its own write is the self-test's
`cmp.w $204(a6),d6` register-existence check.

`$FF021A` IRQMASK **must be a genuine per-bit read/write latch** — 50 read-modify-write pairs
depend on reading back what is there.

`$FF0008` **must be a FIFO, not a register** — reads pop. A register model returns the last word
of every transfer.

## 2. Bit maps

**`XLTR_MODE1` `$FF0202`** — every bit now has an owner:

| bit | role |
|---:|---|
| 14 | control/grant — the firmware *releases* it (13 clears, 1 set) |
| 12 | enable — set 8x, **never cleared**, sticky for the machine's life |
| 7 | **busy** (read side); the `bclr`/`bset` pair at `$F050D2`/`$F050E0` is op `$E` = `XPRUN` |
| 6 | set by the panel-command issuers, never cleared |
| 0 | **host-link command** — set by TCBIO1I before panel `$281`/`$282` |

**`$FF0216`** is a **four-bit register, bits 4-7 only**: bit 7 gates chassis op `$6` (cleared for
the duration, original restored), bit 5 gates the `$400000` window (set => BERR), bit 4 is the
16->32 width mux and is **bracketed** around `CPLOAD` (set at `$F0550A`, cleared at `$F05582`),
bit 6 unidentified.

**`$F70019`** is **read-only** — zero writes anywhere in the ROM — and only bits 1-5 are tested,
at 11 sites total.

**`$FF0218`** is a two-command register: arm with `$0400`, disarm with `$0000`.

## 3. The command byte and its modifiers

`XLTR_MODE0`'s low byte, latched at `$E86`/`$E87`: bits 0-3 the operation, bit 4 auto-increment,
bit 5 direction, bit 6 half-select, bit 7 routes to the register interface.

**Seven of the sixteen operations honour no modifier bits at all** (`$5`, `$7`, `$8`, `$9`, `$D`,
`$E`, `$F`) — for those the modifiers are don't-care. `$1`, `$2`, `$B` honour only bit 6. `$3`,
`$C` and `$6` honour the full set. **Only `$0` uses bit 5 to select a different protocol** rather
than a direction.

## 4. The four transports

| transport | direction | port | framing | handshake |
|---|---|---|---|---|
| SLC S-records (op `$0`, `$E5C = 0`) | chassis -> SBC | `$FF0008` | S-records, **ASCII hex, TWO chars per 16-bit word** | **per word** |
| raw bulk (op `$0`, `$E5C = $28`) | chassis -> SBC | `$FF0008` | none | per word |
| readback (op `$0`, `$E87` bit 5 set) | **SBC -> chassis** | `$FF0008` | none | **NONE** |
| `CPLOAD` (RDHC command 4) | chassis -> SBC | `$400000` page 0 | S-records, binary | none |

The inbound and outbound raw directions are **asymmetric**: inbound wraps every word in a full
`$FF0218` arm / poll bit 15 / clear cycle; outbound is a bare `move.w (a1)+,(a0)` loop at bus
speed. A model expecting an outbound handshake never sees the data.

**`$FF0000` is a remaining-word count** the chassis must decrement — both S-record error paths
spin `while ($FF0000 > 0) read (a0)` to drain a rejected record. A constant non-zero value hangs
the firmware, but only on a malformed record.

**The S-record checksum is not verified.** The last word of each record is read through a full
handshake and discarded. A host must still send it, because the framing depends on the count.

## 5. The channel transaction

```
SBC   +$04 <- $0000                       arm
SBC   +$08 <- $0000
SBC   +$0A <- the OPERATION code           $10, $0E or $1B -- the entire vocabulary
SBC   +$0E <- $8004 REQUEST-TRANSFER       (or $8005 CONTINUE)
      poll +$0E 1000 times: bit 14 DONE, bit 13 ERROR
ISR   reads +$0E, +$08, +$0A into $1066 + (ch-1)*6
```

A normal request is **two back-to-back transactions**: op `$10` with a literal payload, then op
`$0E` with a longword pre-decremented out of the `$101E` file. Timeout after 1000 polls reports
panel `$26C`; the error bit reports `$269`/`$26A`/`$26B`.

## 6. The chassis is fully trusted — four unbounded primitives

| primitive | capability |
|---|---|
| op `$6` | read/write **any** SBC address, 16-bit, no range check |
| op `$0` `$E5C = $28` | write `$E64` words to **any** SBC address |
| op `$0` bit 5 set | read `$E64` words from **any** SBC address |
| `$E87` bit 7 dispatcher | read/write **every CPU register including the USP** |

The register interface indexes the interrupt frame (`movem.l d0-d7/a0-a7`, 16 longwords) scaled
by 4, with `$E87` bit 6 half-select and bit 5 direction. The exit stub's `movem.l (a7)+` then
loads whatever was poked into the real registers, **a7 included**.

**Together these are a complete remote debugger.** The SBC validates channel numbers, array
indices, record framing and register indices meticulously, and validates **addresses essentially
nowhere**.

## 7. Timing

The RMS68K tick is **not** a hard-coded constant: `$F0A2A4` starts from `#$320` = **800, the E
clock in kHz**, takes the period from config word `$F0A530` = **10, in milliseconds**, and
composes `(4*10-1)<<8 | (800/4-1)` = `$27C7` into the MC6840 T3 latch in dual-8-bit mode. Period
= `E_kHz x period_ms` = 8000 E cycles = **10.0000 ms**.

## 8. Things that must fault

- **The ENTIRE gap `$20000`-`$EFFFFF` must fault** (`$F08EB6`, decoded 2026-07-31). A longword
  sweep walks up from `$20000` in **2 KB steps** to `$F00000` — 7,616 probes if none faults — and
  **retries forever** on failure. It **runs before the watchdog test**, so a model returning zero
  for unmapped reads hangs here first. It reaches `$20000` as `$1FFF0 + $10`, adapting to a
  differently-sized machine rather than hard-coding the boundary.
- **`$600`**, the bus-timeout watchdog test, requires a BERR in `$F80001`-`$F82001`, and the
  requirement is more specific than that (decoded 2026-07-31 at `$F08F1C`):
  - the probes are **byte reads at ODD addresses** — `$F82001` stepping **down** by two, so
    `$F82001`, `$F81FFF`, … `$F80001`. A model faulting only on word accesses or only on even
    addresses never satisfies it.
  - **one fault suffices** — the loop exits the moment its private handler sets `d1`, so the
    model need not fault across the whole range.
  - **five `nop`s** separate the access from the test, the only place this firmware accommodates
    bus-error *latency*.
  - failure **retries the entire sweep**, so a non-faulting model produces an infinite re-probe
    with the address bus cycling `$F82001` downward — externally visible on a scope.
  - the routine **saves and restores `$8.w`** around itself, so during this test the bus-error
    vector reads `$F08F06`, a value it holds nowhere else. That is what lets the kernel-fatal
    snapshot at `$084C` identify a fault as belonging to phase `$600`.
- **`$FF0216` bit 5 set** must make the `$400000` window raise BERR.
- The self-test installs its own handler on **both** bus and address error and **counts** faults
  at `$1F800` (or `$400` when the stack has been relocated), discarding 8 bytes and `rte`-ing —
  which requires the **68000-format 7-word exception frame**, not the 68010's.

## 9. CPU core requirements

- **`moveq` must sign-extend** — phase `$101` compares `moveq #$FF,d6` against `$FFFFFFFF`.
- **`move usp,aN` / `move aN,usp` must be implemented** and round-trip 32 bits — required in three
  independent places, including a self-test write/read-back.
- The reset SP longword is **zero**; `$F09C00` is a bare `jmp $F08700` and the self-test's first
  instruction reloads `a7`. Nothing may push in between.

## 10. What no chassis model can supply

Two counterparties are missing from the image and cannot be inferred from it:

- **the CP program** that fills the trampoline at `$10AE + (ch-1)*4`, which the firmware `jsr`s
  into with a FORTRAN-style argument frame built on the `USER` task's own stack;
- **the AP I/F's partner card** in the host chassis, driven over RS-422 differential pairs.

And the meaning of the three AC operation codes lives in the XP-32 EXEC card's 80-bit PROM, which
the SBC cannot read and the self-test never touches. **The SBC-side boundary is closed; past it
needs hardware.**


---

# Addendum: findings since the first draft (2026-07-31)

## 11. Two unmapped-space requirements, not one

| test | range | probe | stride | on failure |
|---|---|---|---|---|
| `$F08EB6` (runs FIRST) | **`$20000`-`$EFFFFF`** | **longword** read | 2 KB | retry forever |
| `$F08F1C` phase `$600` | `$F80001`-`$F82001` | **byte** read, **odd addresses** | 2, downward | retry forever |

A model returning zero for unmapped reads hangs in the **first**, before ever reaching the
documented watchdog phase. Both exit on the first fault, so faulting anywhere in range suffices.
Both save and restore `$8.w` around themselves.

## 12. Three fault handlers with three policies

| handler | policy |
|---|---|
| `$F08902` | **count** at `$1F800` (or `$400` when the stack is low) |
| `$F08F06` | **flag** `d1` only |
| `$F098E0` | **flag and advance the stacked PC by 4** |

The probes are **two-byte** instructions followed by **four `nop`s**, so `+4` lands in padding.
**Byte-exact bus-error PC semantics are NOT required** — only that the stacked PC be at or just
after the faulting instruction.

## 13. The chassis window is paged, not indexed

`$FF0210` selects the page for the whole `$400000`-`$7FFFFF` range. Every access is at
displacement `+$0000` except the **mailbox** at page `$F`, offsets `$1C` (inbound) and `$20`
(outbound). The mailbox and the SCM share the window at different pages — the only place two
structures do.

## 14. The AP I/F is exactly five windows of four registers

Windows 0, 2, 3, 4, 5 each touch `+$00`, `+$04`, `+$08`, `+$0E` and nothing else. **Windows 1, 6
and 7 have zero references by any addressing form.** Window 1 is additionally skipped by the
firmware's own `((ch+1)<<5)` arithmetic, so it is reserved rather than merely unused.

## 15. `$FF0000` is a remaining-word count

Both S-record error paths spin `while ($FF0000 > 0) read (a0)` to drain a rejected record. A
constant non-zero value hangs the firmware — **but only on a malformed record**, the case least
likely to be exercised.

## 16. CPU-model requirements beyond the instruction set

- **`moveq` must sign-extend** — phase `$101` fails otherwise, at the second stage of boot.
- **`move usp,aN` / `move aN,usp`** must round-trip 32 bits — needed in three places.
- **The trace exception must fire once and let the handler clear the stacked T bit** — `$F005BA`
  dispatches a task with T set and `$F00AF2` clears it. This is a **stock-ROM** facility, not only
  the monitor's.
- **`tas` must be atomic against bus masters**, not only against interrupts — five kernel locks
  depend on it and the chassis is a master.
- **The firmware is self-modifying**: it builds `jsr` instructions at runtime in three places. No
  68000 icache exists, but any model caching decoded instructions must invalidate on RAM writes.
- **The CPU never halts** — no `stop` anywhere. A hung machine spins, with visible bus activity.
- **`reset` is never issued** — peripherals are reset only through their own registers.

## 17. Task creation is data-driven and self-terminating

Six tasks exist because six consecutive `!TCB` records precede the blank tail; the seventh slot at
`$F0A840` is zero. **"Six" is not a constant anywhere.** Each record differs from the others in
only three fields — name, entry point, PROG pages — and its `+$18` word becomes the TCB's initial
state, with **bit 4 meaning "enqueue on the ready list"**.

## Hard CPU requirement: the bus-error frame must be exactly 14 bytes

The firmware recovers from bus errors by a stack-marker protocol, and the marker's position
is derived from the 68000 group-0 frame size. A caller pushes a **continuation address (4
bytes)** and the marker **`$4245`** (2 bytes), performs a risky access, and drops the guard
on success. On a fault, vector 2 reaches `$F00D00`, which tests `$12(a7)` for the marker and
releases `$14` bytes:

```
6 (caller's guard) + 14 (CPU's group-0 frame) = 20 = $14
marker offset seen by the handler = 14 + 4     = 18 = $12
```

**A model that pushes a 68010-format frame (58 bytes) breaks all seven guarded sites** —
`$12(a7)` no longer holds the marker, the check fails, and every recoverable probe becomes
`PCMD_KERNEL_FATAL`. One of the seven guards the **MC6840 programming**, so the failure
appears during initialisation rather than somewhere diagnosable.

This is the mechanism behind the vendored-core patch already recorded as a divergence fix.
It is not cosmetic and must not be reverted.

Related requirements this makes concrete:

- **Unmapped space must fault.** Two separate sweeps depend on it — the `$20000`-`$EFFFFF`
  walk at `$F08EC8` (stride `$800`) and the documented `$F80001`-`$F82001` watchdog test.
- **`$8.w` changes during the self-test.** Five sites save and restore the bus-error vector
  around temporary handlers; a model that caches vector 2 rather than reading it per fault
  will dispatch to the wrong handler.
- **The faulting instruction need not be restartable.** Recovery is by `rts` to a
  continuation, not by resuming the access, so a model does not need precise bus-error
  restart semantics — only a correctly-sized frame and a correct stacked PC.

## The chassis window: the model backs 1 MB, the firmware can address 4 MB (2026-07-31)

Chassis operation `$3` computes its window address as

```
offset = (addr & $FFFFF) << 2        ; addr is the chassis-supplied longword address
target = offset + $400000            ; rebased if it is not already in the window
```

so the reachable range is **`$400000`-`$7FFFFC`, four megabytes**. The emulator declares
`CHASSIS_MEM_SIZE = 1 << 20` and indexes with `chassis_mem[a - CHASSIS_MEM_BASE]`, backing
only `$400000`-`$4FFFFF`.

**This is adequate for everything the firmware does by itself** — the SCM self-test uses
`$400000`-`$403FFF`, 16 KB — but a chassis driving op `$3` with an address whose low 20 bits
exceed `$3FFFF` lands outside the array. Worth fixing by construction rather than waiting
for it to bite, since the size is a one-line constant.

**Related, and already recorded as a divergence: `XLTR_MODE2` is stored but never used to
index the window.** The model keeps `xltr.mode2` and reports it in dumps, but the address
decode ignores it, so two chassis addresses differing only above bit 19 alias onto the same
byte. On hardware they select different pages. The firmware itself cannot expose this — it
uses page 0 for SCM and page `$F` for the mailbox, and the mailbox is served by a separate
handler in the model — but **op `$3` makes the page chassis-controlled**, so any experiment
driving it with a paged address is mismodelled.

The two together give the fix: index the window as `page * $100000 + offset` and size the
array accordingly, or explicitly document the model as single-page and reject non-zero
pages rather than silently aliasing.

### The two window divergences have one root cause

The model carries a **separate mailbox device** answering `$70001C`/`$700020`
unconditionally, recorded as a divergence because the mailbox is really inside the paged
chassis window. That special case exists *because* of the sizing problem above:

```
mailbox CPU address        $70001C
window CPU extent          $400000-$7FFFFF   (4 MB)
offset within the window   $30001C            (3.0 MB in)
emulator window backing    1 MB               -> the mailbox falls outside it
```

With a 1 MB array the mailbox simply is not in the window, so it needed a handler of its
own. Size the window to its real 4 MB CPU extent and index it by the page `XLTR_MODE2`
selects, and **the mailbox stops being a special case**: it is page `$F`, offset `$30001C`,
which is exactly what TCBIO1I's save-set-`$F`-restore sequence says it is.

So one fix retires two divergences — the undersized window and the invented mailbox device
— and makes the model match the firmware's own description of the hardware rather than
working around it.

**The ROM does constrain the page semantics, more than I first allowed.** TCBIO1I selects
`MODE2 = $F` and then touches CPU address `$70001C`. Within the 4 MB aperture that address
sits at offset `$30001C`, whose own bits 20-21 are **3**. So `MODE2` (`$F`) and the CPU
address's high offset bits (`3`) **disagree** — they cannot be the same field.

`MODE2` therefore selects a **chassis-side page** independently of the CPU address, which
supplies only the offset within the aperture. The mailbox is "chassis page `$F`, aperture
offset `$30001C`", and op `$3` reaches its target by writing the page it wants and using the
low bits as the offset — the same two-part scheme, driven from the chassis rather than from
a fixed address.

What remains unestablished is the *width* of the page field and how many pages the backplane
decodes; the firmware only ever names `$0` and `$F` by literal, with op `$3` supplying the
rest at runtime. A model should implement page-plus-offset and accept any page value rather
than assuming 16.

## Fault-conformance suite: nine assertions extracted from the self-test (2026-07-31)

The self-test is written as a specification **with negative cases** — it checks not only
that gates fault, but that the wrong bits do *not*. Extracting every
`probe → tst.w d1 → beq/bne` and `probe → beq/bne` pattern gives a complete table a model
must satisfy.

**The three probes**, each with a four-`nop` landing zone so byte-exact PC semantics are not
required:

| probe | what it does |
|---|---|
| `$F096AC` | `move.w (a1),d0` — **read** `$400000` |
| `$F096B8` | `clr.w (a1)` — **write** `$400000` |
| `$F098C4` | `$FF020C <- $FF`, `$FF0218 <- $400`, then `tst.w $e(a6)` — access `$FF000E` |

**The nine assertions:**

| site | probe | `$FF0216` | required |
|---|---|---|---|
| `$F0962C` | read `$400000` | `$20` | **bus error** |
| `$F0966E` | write `$400000` | `$20` | **bus error** |
| `$F0968E` | write `$400000` | `$0000` | no fault |
| `$F096EE` | read `$400000` | `$40` | no fault |
| `$F09710` | read `$400000` | `$0000` | no fault |
| `$F09734` | write `$400000` | `$40` | no fault |
| `$F09756` | write `$400000` | `$0000` | no fault |
| `$F09852` | access `$FF000E` | `$80` | **bus error** |
| `$F098A4` | access `$FF000E` | `$0000` | no fault |

Reduced to rules:

1. **`$FF0216` bit 5 set ⇒ any access to `$400000` faults**, read or write.
2. **`$FF0216` bit 7 set, with `$FF0218` armed ⇒ access to `$FF000E` faults.**
3. **Bit 6 is inert** with respect to the chassis window, in all four combinations.
4. With `$FF0216` clear, both regions are accessible.

Each failure sets `d7 = $F0F0F0F0` and retries the arm indefinitely, so a model that gets one
of these backwards **hangs in that phase** rather than reporting — the observable symptom is
a stuck `CHANNEL_SELECT` sub-phase, not a message.

Two further fault requirements documented elsewhere complete the picture: the phase-`$600`
watchdog needs a fault somewhere in `$F80001`-`$F82001`, and the earlier `$20000`-`$EFFFFF`
sweep needs unmapped space to fault at a `$800` stride.

## Board-status derivation: what the firmware actually requires (2026-07-31)

`versabus.c` derives `$F70019` from a set of bit equations described in the notes as
reverse-engineered by tuning until the self-test passed. **Five of the six are specified
outright by the suite**, in the form of arms that set VMOD state and demand a particular
board-status reading. This is the implementable contract, with the site that proves each.

### Resting state — phase `$0500`

`($F70018 & $3F31) == $3F11`: **bit 0 set, bit 4 set, bit 5 clear, bits 8-13 set.**

### Board bit 3 — phase `$0800`, full 2x2 truth table

With `$1FFF1` bit 6 forced clear by the helper at `$F0903C`:

| `$1FFF1` bit 7 | `$1FFF0` bit 1 | board bit 3 |
|:-:|:-:|---|
| 0 | 0 | set |
| 0 | 1 | set |
| 1 | 0 | set |
| 1 | 1 | **clear** |

i.e. `bit 3 = NOT( bit6 OR (bit7 AND bit1) )`. Four arms, all four combinations.

### Board bit 1 — phase `$1200`

| source | `$1FFF1` bit 4 | bit 5 | `$1FFF0` bit 0 | board bit 1 |
|---|:-:|:-:|:-:|---|
| phase `$1100` | **set** | — | — | **clear** |
| phase `$1200` | — | set | — | set |
| phase `$1200` | — | clear | — | clear |
| phase `$1200` | — | set | clear | set |

Both terms of `NOT(bit4) OR (bit5 AND NOT bit0)` are exercised — bit 4 by phase `$1100`
(**setting** it requires board bit 1 **clear**), bit 5 and `$1FFF0` bit 0 by phase `$1200`.

### Board bit 2 — phase `$1400`

| condition | board bit 2 |
|---|---|
| request-level field zero | clear |
| line 2 gated on (bit 3) **and** level requested | set |

The equation's `bit 3 AND bit 0` is **the interrupt request condition** — bit 3 gates the
second request line, bit 0 is the level field's low bit. Bit 2 is a *status* line, not a
combinational echo of control bits.

### Board bit 5 — phase `$0200`

Parameterised mapping test with `d0 = 6`, `d1 = 3`: **clear `$1FFF1` bit 6 ⇒ board bit 3
reads 1**. (The documented "bit 5 = `$1FFF1` bit 6 directly" is the same relationship seen
from the other end.)

### `$FF0216` gates — phases `$1700`, `$1800`, `$1A00`

Nine fault assertions: bit 5 set ⇒ `$400000` faults both directions; bit 7 set with
`$FF0218` armed ⇒ `$FF000E` faults; bit 6 inert in all four combinations.

### Board bit 4 — NOT specified

`MODE1 <- $8000` occurs only at the three checkpoints, and board bit 4 is literal-tested at
one site. The "busy/ready from MODE1 bit 15" reading is inferred from the handshake's shape.
A model should implement it, but should not treat it as pinned the way the others are.

## Model gap: the VMOD interrupter's vector registers are not implemented (2026-07-31)

The emulator declares `VMOD_CTRL` as **exactly two bytes** — `static uint16_t vmod_ctrl` at
`$1FFF0`-`$1FFF1` — and its own comment notes that "a long write at `$1FFF0` covers RAM at
`$1FFF2-3` too". So:

| address | firmware role | emulator |
|---|---|---|
| `$1FFF0`-`$1FFF1` | control | modelled |
| `$1FFF2` | **interrupter vector register → `$50`** | plain RAM |
| `$1FFE2` | **vector register → `$51`** | plain RAM |
| `$1FFE4` | **vector register → `$52`** | plain RAM |
| `$1FFE6` | **vector register → `$53`** | plain RAM |
| `$1FFEA` | **vector register → `$54`** | plain RAM |

**Why this has gone unnoticed**: every self-test that touches them only writes and reads
back, and RAM does that perfectly. Phases `$0600` (longword patterns), `$1600` (the
register-file walk) and `$2100` (address uniqueness) all pass against RAM. The registers'
*storage* behaviour is indistinguishable.

**Where it must matter**: the vector registers exist so the interrupter can supply a vector
during the IACK cycle. A model that stores them in RAM has no way to read back what the
firmware programmed, so any VMOD interrupt it delivers cannot be using the programmed
vector — it must be hard-coding or autovectoring. Phases `$0800`, `$1200`, `$1300` and
`$1400` install handlers at `$140`-`$150` and require delivery *to those vectors*.

**What to check next** (needs a run, so recorded rather than concluded): how the current
model satisfies phase `$1400`'s delivery arm, which requires `d2` bit 1 to be set by a
handler at vector `$52`. Either it delivers to a hard-coded vector that happens to match, or
that arm is not reached. Both are worth knowing.

The fix is small and principled: back `$1FFE2`, `$1FFE4`, `$1FFE6`, `$1FFEA` and `$1FFF2`
as device registers, and supply their contents as the vector when the corresponding request
line is acknowledged.

## An unresolved discrepancy: phase `$1400` requires an interrupt the model cannot deliver

Phase `$1400` arm 2 is unambiguous:

```
$F0945E  bset.b #$3,$1(a5)      ; gate request line 2 on
$F09464  bsr.b  $f094ae         ; arm bit 7, request level 1, spin for delivery
$F09466  btst.b #$1,d2          ; d2 bit 1 is set ONLY by the handler at vector $52
$F0946A  bne.b  $f09472         ; ...bne skips the fault marker, so bne is the OK path
$F0946C  move.l #$f0f0f0f0,d7
$F09478  bne.b  $f0945e         ; UNBOUNDED retry
```

Without a real interrupt reaching `$F094E4`, `d2` stays zero and this arm retries forever.

**The emulator has no VMOD interrupter path.** Its only `m68k_set_irq` sources are
`versabus_bim_pending_level()` (the MC68153 BIMs), the PTM, and two fixed fallbacks. Nothing
derives an interrupt from `vmod_ctrl` bits 0-2 or bit 7, and the vector registers that would
supply `$50`-`$54` are modelled as RAM.

Yet this project records the emulator reaching phases `$0100`-`$1A00` and `$2000`. **Both
cannot be true**, so one of these holds:

1. an interrupt from another source (a BIM, or a fallback level) happens to land on vector
   `$52` and set `d2` bit 1 — accidental success;
2. the suite **aborts** out of phase `$1400` via `$F0891C`, whose bits-4-and-5 test jumps to
   `$F088F4` → `$F09C06` and ends the self-test — in which case "phases reached" counts phase
   *codes broadcast*, not phases *passed*, and the later codes come from somewhere else;
3. phase `$1400` is not actually reached and the recorded range is optimistic.

**This is directly measurable** — count executions of `$F094E4` (the vector-`$52` handler)
and of `$F088F4` (the abort) in a normal run. I have not run it here because a regression
pass was in flight, so this is recorded as a discrepancy rather than resolved.

It matters beyond bookkeeping: if the answer is (2), then **the abort path is load-bearing in
the current model** — the boot completes because the self-test gives up, not because it
passes. That would make several "the emulator reaches X" claims weaker than they read.
