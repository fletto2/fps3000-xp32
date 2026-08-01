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


## RESOLVED 2026-07-31 — the phase `$1400` discrepancy was my error

This file recorded an unresolved discrepancy: phase `$1400` arm 2 needs a real interrupt, the
emulator appeared to have no VMOD-derived interrupt source, yet the project records it reaching
later phases. **The emulator does model the interrupter** — in the `$1FFF1` write path, edge-
triggered on bits 0-2 with bit 7 set, dispatching to vector `$50` or `$52` on bit 3. My sweep
for interrupt sources missed it because it looked at the tick and BIM routines rather than the
register write handler.

So there is no discrepancy, the recorded phase coverage is genuine, and the three candidate
resolutions listed above are all moot. **The abort path is not load-bearing in the current
model** — which was the substantive worry, and it is retired.

What survives from that investigation, and is independently useful, is the fault policy:
`PollBoardStatus` never clears `d7`, so a genuinely failing arm retries forever while
announcing itself, and the only exit is the chassis raising board-status bit 5. A model that
cannot raise bit 5 turns any real diagnostic failure into a silent hang.

---

# Consolidated conformance suite, self-test derived (2026-07-31)

Every item below is a behaviour the firmware's own diagnostics **require**. Each cites the site
that demands it. Because `PollBoardStatus` never clears `d7`, **failing any of these presents as
an infinite loop parked on the phase code in `CHANNEL_SELECT`, not as an error** — so a model
that is silently wrong here looks identical to a model that is hung for some other reason.

## A. The escape hatch

**A1.** Board-status bits 4 **and** 5 both set must be reachable, and must cause `PollBoardStatus`
(`$F0891C`) to `jmp Phase2Init`. This is the *only* exit from a failing test. `$D0` written to
`$1FFF1` sets bits 7 and 6, which is what drives board bit 5 in the current model — but note the
fault path itself **clears** `$1FFF1` bit 6, so a bit-5 derivation that depends on bit 6 makes
the abort unreachable exactly when it is needed. Bit 5 should be an independent chassis line.

## B. The VMOD interrupter (`$1FFF0`-`$1FFF3`)

**B1. SUPERSEDED 2026-07-31.** This said `$1FFF4`-`$1FFFF` is ordinary RAM because the DRAM
loops pattern-test it. The inference does not hold: a vector register that reads back what was
written is indistinguishable from RAM in a pattern test, and the DRAM walk runs *before*
`$F0A452` programs the file. The top 48 bytes are **three 16-byte interrupter blocks** —
control words at `$1FFD0`/`$1FFE0`/`$1FFF0`, each followed by **seven vector registers** for
levels 1-7. The DRAM loops skip only `$1FFF0` because that is the word that drives the chassis.
**B2.** `$1FFF1` bits 0-2 are the interrupt **request level**, walked 1..7 by phase `$1300`;
delivery is mandatory at every level.
**B3.** The vector for a request at level *N* comes from **`$1FFF2 + 2*(N-1)`** — a seven-entry
file per block. Phase `$1300` writes the vector before raising each request, and `$F0A452`
pre-loads all 21 registers across the three blocks at init, with `$8E` (the panic vector) as
filler for unassigned levels.
**B4.** `$1FFF1` **bit 3 selects the vector**: clear routes to `$50`, set routes to `$52`
(phase `$1400`, whose two handlers set different bits of `d2` so a wrong vector is
indistinguishable from no delivery).
**B5.** The handler acknowledges in **software** by clearing `$1FFF1` bits 0-2 — there is no
IACK-driven clear.
**B6.** `$1FFF1` bit 7 must be set for a request to be armed.

## C. The `$400000` chassis window

**C1.** `$400000`-`$403FFF` at page 0 must be **real read/write longword storage**, no aliasing,
no read side effects (address-line test `$F09AD6`, march test `$F09B20`).
**C2.** The page comes from `$FF0210`; `page = addr >> 20`, `offset = (addr & $FFFFF) << 2`, so
the window is **longword-granular** — the chassis names longwords, not bytes.
**C3.** `$FF0216` **bit 5 set ⇒ accesses to the window BUS-ERROR**, clear ⇒ they complete, and
this holds for **both directions**. The test is four arms — read/set `$F09626`, read/clear
`$F09648`, write/set `$F09668`, write/clear `$F0968A` — the two "set" arms requiring the fault
(`bne`) and the two "clear" arms forbidding it (`beq`).
**C4.** `$FF0216` **bit 6 must have no effect on faulting** — and this is the *same four-arm
harness* (`$F096C4`, same two access routines, same order) with **`beq` required in all four**.
The contrast is the point: bits 5 and 6 are tested identically and demanded to behave oppositely,
so bit 6's orthogonality is an asserted property, not an untested one.
**C5.** The width mux, `$FF0216` bit 4, is a full 2x2 (phase `$1900`):

| bit 4 | 16-bit write to the window | write to `$FF0214` |
|:-:|---|---|
| set | lands in the addressed half | **inert** |
| clear | **discarded** | supplies the **low half** |

**C6.** Op `$3`'s 32-bit protocol: the bus cycle happens on the **high** half for reads and the
**low** half for writes; the other half is cached in `$E70`/`$E72` with no bus access.

## D. The XLTR register file

**D1.** `$FF0204` is a **readable latch** — six write/read-back iterations at `$F094F0`.
**D2.** `$FF0210`, `$FF0212`, `$FF0214`, `$FF0216` are four **independent** registers, each
written one walking bit (`$10`/`$20`/`$40`/`$80`) and read back (`$F09558`).
**D3.** The BIM block is walked from `$FF0230` with **distinct** ascending values `$C0`+, for
**16 registers if `$FF0218` bit 4 is clear, 24 if set** (`$F0956C`). Distinct values are what
make the read-back detect aliasing rather than mere presence.

## E. The AP I/F

**E1.** `$FF000E` must latch and return `$AAAA` (`$F0987C`/`$F09882`) — with `$FF0218 = 0`.
**E2.** With the XLTR armed as `$F098C4` arms it (`$FF020C = $FF`, `$FF0218 = $400`), `$FF0216`
bit 7 **set** must make `$FF000E` bus-error and **clear** must not. Bit 7 alone must *not*
disable the port: it is set at rest (`$FF0216` reads `$C0`) while every panel command writes
`$FF000E`.
**E3.** Nothing else in the AP I/F is exercised by the self-test — no channel window, no data
port, no ready flag. The channel windows are constrained only by the operational paths.

## F. Bus errors

**F1.** The group-0 frame must be **14 bytes** — required by the self-test handler
(`lea $8(a7),a7` + `rte`) and by the seven guarded sites in the kernel.
**F2.** The stacked PC may be imprecise; the handler blindly adds 4 and relies on `nop` padding,
so a model stacking either the faulting address or that plus two is acceptable.
**F3.** A byte read at an odd address in `$F80001`-`$F82001` must fault (watchdog test
`$F08F1C`); one fault suffices, and failure re-probes forever.

## G. What is NOT specified anywhere

No self-test touches **XP-32 EXEC, XP-32 ARITH or UNIV FMT**, and there is **no MEM CTL register
interface** — System Common Memory is reached purely as paged memory through the window. The
mux's **read**-side behaviour is never exercised. These are gaps only hardware can close, and
they are the same boundary the machine's own diagnostics draw.

---

## The `$FF0218` bit-4 fix, stated precisely (2026-07-31)

The model currently does, on every read of `$FF0218`:

```c
if (xltr.bim3_present) xltr.status_irq |= (1u << 4);   /* versabus.c:804 */
```

That is a **sticky strap**: bit 4 is re-asserted after every write, so the sequence

```
$F0954C  $FF0218 <- $400
$F095A2  read $FF0218, mask $610, require == $400
```

reads back `$410`, fails, and the phase retries forever. This is the whole of why `FPS3K_BIMS=3`
"derails the boot" — it is not evidence about how many BIMs exist.

**The firmware's requirement is exact and easy to satisfy: bit 4 must read 1 before the arm write
and 0 after it.** So model it as an ordinary writable bit of `$FF0218` that **powers up set**:

```c
/* at reset */          xltr.status_irq |= (1u << 4);
/* on CPU write */      xltr.status_irq = value;        /* the $400 write clears bit 4 */
/* on read */           return xltr.status_irq;         /* no re-assertion */
```

**Prediction, and it is a sharp one.** With that change the machine should

1. **boot to the RTOS idle loop** exactly as the default two-BIM configuration does, because the
   `$610` readback now yields `$400`; **and**
2. **walk all 24 BIM registers** in phase `$1600`, because `$F09522` samples bit 4 *before* the
   arm write and picks the `$D8` limit — which means **`$FF025E` gets written for the first time**,
   closing the last "never touched" register on the card. **And the phase then READS THEM BACK**
   (`$F095CE`-`$F095E4`, `cmp.w (a6,a0.w),d0` against `$C0+n`), so `$FF025E` must be a working
   read/write latch, not merely writable. The pass condition is boot-to-idle **plus 24 successful
   read-backs**.

Both outcomes are checkable in one run (final PC, plus an access log filtered to `$FF025E`). If
the boot completes but `$FF025E` stays untouched, the sampling order is wrong; if `$FF025E` is
written but the boot stalls, something else in the `$610` mask is mismodelled.

This supersedes the "RETRACTED — setting that bit DERAILS THE BOOT" note: the retraction was
correct about the observation and wrong about the cause. Three BIMs are not optional — BIM2 is
programmed unconditionally by init and by three tasks — so a correct model has **three BIMs and
bit 4 clear after arming**, which were never in tension.


---

## MEASURED 2026-07-31: the bit-4 fix is ALREADY IMPLEMENTED, and the docs are stale

The fix specified above — bit 4 readable before the arm write, clear after — **is already in
`versabus.c`**, implemented on the *write* side rather than the read side: the `$0400` case does
`xltr.status_irq = 0x0400; xltr.bim3_present = 0;`, so the read-path OR stops firing after the arm.
Its own comment states the mechanism in the same terms this session re-derived from the ROM, with
measured retry counts (`$F09574` executed 3,055,728 times when it was wrong).

So my "fix and prediction" re-derived something already done. What is genuinely new is the
measurement, and it retires a stale claim.

**Measured, unpatched, 400 M cycles:**

| configuration | final PC | `$FF025E` accesses |
|---|---|---:|
| default (bit 4 clear) | **`$F00FC2`** | 0 |
| **`FPS3K_BIMS=3`** | **`$F00FC2`** — identical | **2** |

Both reach the same final PC with the same `XLTR mode1=8020 chsel=2903`. **`FPS3K_BIMS=3` does not
derail the boot.** And `$FF025E` is touched exactly **twice** — one write from phase `$1600`'s
24-register walk and one read from its verify pass, precisely the two accesses the phase structure
predicts and the confirmation the prediction asked for.

**`CLAUDE.md` therefore carries a stale retraction**: "RETRACTED 2026-07-30 — setting that bit
DERAILS THE BOOT ... with three BIMs the machine ends at final PC `$011758`". That was true of the
model as it stood then; it is not true of the model as it stands now. The observation was correct,
the cause was mis-attributed to BIM count, and the code was subsequently fixed without the note
being updated.

What this session adds beyond the fix: **BIM2 is programmed unconditionally** by init and by three
tasks, so three BIMs were never optional — which the code comment does not say, and which is the
reason the bit cannot be a presence strap in the first place.

---

# The chassis INPUT surface — everything the chassis can use to influence the SBC

The conformance suite above says what a model must *do*. This is the dual: the complete set of
values the chassis supplies that the firmware actually branches on. Anything not in this list
cannot change the SBC's behaviour, however the chassis sets it.

Derived by pairing every device-register read with the test applied to its destination register
within five instructions, then completing it from findings established elsewhere in this session.

| input | how the firmware uses it | tests |
|---|---|---:|
| **`$FF0202` MODE1 bit 7** | "chassis busy" — the XP tasks' contention check | **15** |
| `$FF0202` bit 14 | cleared by the SBC when issuing; chassis sets it | 1 |
| **`$FF0200` MODE0 low byte** | `andi #$ff` — **the 16-operation command dispatch**, latched at `$E86`/`$E87`; bit 7 selects the alternate register-access dispatcher | 1 read, 2 dispatchers |
| **`$FF0204` CHANNEL_SELECT** | the general argument register; compared against **`$0`**, **`$10`**, **`$28`** | 4 |
| **`$FF0218` bit 15** | ready/done — every bulk and stream handshake | **20** |
| `$FF0218` bit 4 | sizes the phase-`$1600` BIM walk (16 or 24) | 1 |
| **`$F70019` bits 1-5** | board status: 11 literal-bit tests plus **5 with computed bit numbers** | 16 |
| **channel `+$0E` bits 15, 14, 13, 11** | latched into `$1066` by the ISR, then decoded by the task body | 4 arms |
| **`$FF0000`** | remaining-word count — the S-record drain loop spins while `> 0` | 1 |
| **`$70001C` mailbox** | host-presence probe at init (`$10A8`), and TCBIO1I's class field / bit 29 | 3 |
| `$400000` window contents | chassis memory, read back by op `$3` and by RDHC's record fetch | — |

**That is the whole surface.** Eleven inputs, of which four carry almost all the traffic: MODE1
bit 7, MODE0's command byte, `$FF0218` bit 15, and board status.

Two consequences worth drawing out:

- **A chassis model that gets these eleven right is behaviourally complete for the SBC**, whatever
  else it does. Registers outside this list are latches the firmware writes and reads back but
  never branches on — they must *store* correctly (phase `$1600` verifies many by read-back) but
  their values cannot steer execution.
- **The command byte is the only wide input.** Everything else is a single bit or a comparison
  against one of three constants. So the chassis→SBC channel is, in information terms, one 8-bit
  opcode plus about a dozen flags — which is why the 16-entry dispatch table at `$F05102` and the
  42-entry table at `$F05BA4` between them account for essentially all chassis-driven behaviour.

**Caveat on the derivation**: the read-then-test pairing sees only reads into a data register
followed by a test within five instructions. It misses tests through a base-register displacement
(board status, which is why that row is completed from the separate census) and anything where the
value is stored and tested later (the channel status, latched into `$1066` first). Those are
filled in from findings established independently, and are marked as such.

---

# The AC-side contract: what an XP-32 model owes the SBC

The objective asks for communications to and from the EU/AU. The SBC cannot reach either — the
self-test's board coverage stops at the XP-32 boundary and no operational path addresses an EXEC
or ARITH register. What the ROM *does* specify completely is the **arithmetic controller's
obligations at the AP I/F channel window**, which is the entire CP↔AC interface. Collected here as
a model contract.

Each populated channel *N* (windows 2-5, i.e. `$FF0040 + $20*(N+1)`) owes exactly this:

### Registers

| offset | direction | contract |
|---|---|---|
| `+$04` | SBC writes `#$0` | acknowledged; no observable effect required |
| `+$08` | both | **high half** of a 32-bit data register |
| `+$0A` | both | **low half** of the same register |
| `+$0E` | **bidirectional** | **command on write, status on read** |

### Commands the SBC can issue — and there are only three

| value | meaning | what the AC must do |
|---|---|---|
| `$8000` | trigger | act on the 32-bit value just written to `+$08`/`+$0A` |
| `$8004` | REQUEST-TRANSFER | begin; set **bit 14 (DONE)** or **bit 13 (ERROR)** at `+$0E` |
| `$8005` | CONTINUE-TRANSFER | same, for the second half of a two-part transfer |

**No other value is ever written.** A census of every literal reaching a channel `+$0E` finds
`$8004` ×30, `$8005` ×20, `$8000` ×3, and nothing else anywhere in the ROM.

### Timing

The SBC polls `+$0E` **1000 times** after `$8004`/`$8005`, roughly 62 cycles per iteration — about
**62,000 CPU cycles**, ~7.75 ms at 8 MHz. Completing inside that window is the only timing
requirement; the emulator measured ~66 cycles per iteration against 62 predicted. Missing it
reports panel `$26C` (timeout); setting bit 13 reports `$269`.

### Status the AC supplies at `+$0E`

The ISR latches `+$0E`, `+$08`, `+$0A` into `$1066`/`$1068`/`$106A`; the task body decodes:

| b15 | b14 | b11 | the SBC's response |
|:-:|:-:|:-:|---|
| 0 | — | — | the data's high byte is an opcode; non-zero ⇒ `$10` TERMT on `'USER'` |
| 1 | 0 | — | panel `$262` — interrupt with no valid transaction |
| 1 | 1 | 0 | notify the `USER` handle at `$10AE+(N-1)*4`, or set `$10A1+(N-1)*2` bit 0 |
| 1 | 1 | 1 | write `$0000`/`$001B` to the data pair, then `$8000` |

### Operation codes the SBC can emit unaided

**`$1B`, `$10`, `$0E`** — carried in the *data* pair, not the command word. Anything richer comes
from host-loaded CP code. **And `$1B` is issued by three channels only**: XP4I contains no `#$1b`
immediate at all, so channel 4 can never request it.

### Interrupts

Each channel owns a BIM channel (`$FF0244`/`$0246`/`$0250`/`$0252`, control `$5F` = level 7) and a
vector register eight bytes above it (`$45`-`$48`). The AC raises its channel; the BIM supplies the
vector.

### What the ROM cannot tell us

Everything past `+$0E`: how the AC decodes an operation code, how the EU sequences the AU, how
microcode reaches the WCS once it leaves `$FF0008`, and anything about UNIV FMT's conversion on
AC-initiated traffic. Those need a schematic, an EU PROM dump, or a bus trace — and the machine's
own diagnostics draw the same boundary, which is the strongest evidence that the boundary is real
rather than an artefact of what has been read so far.

## Two contract items added 2026-07-31

### Input #12 — the mailbox must answer at BOOT, not just to TCBIO1I

`$F0A1E0` selects window page `$F` and reads `$70001C` **during init**, before the RTOS starts,
recording the result as a host-present flag at `$10A8`. A model that only services the mailbox once
TCBIO1I is running reports "no host" and is never asked again — there is no second probe. Page `$F`
is now the mailbox's address on two independent selectors, not an ISR convention.

### SCM: `$400000`-`$403FFF` must be 16 KB of faithful read/write memory

Self-test `$F09B20` fills and verifies that region with `$00000000`, `$FFFFFFFF`, `$55555555` and
`$AAAAAAAA`, ascending and then descending, at longword stride, at window page 0. Requirements:

| requirement | why |
|---|---|
| all four patterns must read back exactly | zero-returning stubs fail at pattern 2 |
| the bulk-filled pattern must survive 4096 intervening writes | it is an aliasing test |
| both directions must work | it is an address-decode test |

Failure is reported with `d7 = $F0F0F0F0` and, per this suite's fault policy, **retried forever** —
so an unmodelled SCM presents as a hang showing `$2xxx` in `CHANNEL_SELECT`, never as an error.

## Consolidated XLTR / window / AP I/F contract (derived 2026-07-31)

Everything below is read off the self-test's own requirements, not fitted to observed behaviour.
Unless noted, failure is **retry-forever**, so a wrong answer presents as a stalled phase counter in
`CHANNEL_SELECT`, never as a diagnostic.

### `$FF0216` — a four-bit control register

| bit | contract |
|---:|---|
| **7** | **bus-error gate.** A read of `$FF000E` must BERR **iff** bit 7 is set **and** `$FF0218` holds `$400`. With bit 7 set but `$FF0218` cleared, `$FF000E` is an ordinary R/W latch. Chassis op `$6` clears bit 7 because its peek/poke touches arbitrary addresses. Scope beyond `$FF000E` is untested. |
| **6** | **not** a `$400000` gate — all four combinations of {set,clear} x {read,write} must **not** fault. |
| **5** | gates `$400000` **in both directions**: set ⇒ read and write both BERR; clear ⇒ both succeed. |
| **4** | width mux, polarity below. |

### The 16->32 width conversion, on the `$400000` window

| bit 4 | 16-bit write to the window | 16-bit write to `$FF0214` |
|---|---|---|
| **set** | lands in the **HIGH** half | **inert** |
| **clear** | **absorbed**, no effect | writes the **LOW** half |

Two mutually exclusive routes. Enabling the latch on bit 4 *set* is the natural guess and is wrong.

### `$FF0218` — bit 4 means two different things at two different times

| when read | requirement |
|---|---|
| **unarmed** | bit 4 may be set; it sizes phase `$1600`'s BIM walk (clear ⇒ 16 registers, set ⇒ 24) |
| after `$FF0218 <- $400` | `($FF0218 & $610) == $400` — bit 10 set, bits 9 and **4 clear** |

A sticky-strap model satisfies the first and fails the second. Three BIMs and bit 4 reading clear
once armed are not in tension.

### Register-file read-back (phase `$1600`)

| register | requirement |
|---|---|
| `$FF0200` | `& $00FF` must be **zero**; the high byte is unconstrained (chassis-owned) |
| `$FF0202` | full 16-bit R/W latch (`$2000` in, `$2000` out) |
| `$FF0204` | must still hold the phase counter — a readable latch |
| `$FF020C` | full R/W latch |
| `$FF021A` | 12-bit R/W latch (`$FFF`) |
| `$FF0210`/`$0212`/`$0214`/`$0216` | four **independent** word registers (`$10`/`$20`/`$40`/`$80`) |
| `$FF0230`+ | 16 or 24 independent readable latches (`$C0`,`$C1`,…) |

**No aliasing anywhere in that list** — the verify pass re-walks both runs and fails at the first
aliased pair.

### SCM

`$400000`-`$403FFF` must be 16 KB of faithful memory at page 0, holding `$00000000`, `$FFFFFFFF`,
`$55555555`, `$AAAAAAAA` through an ascending and a descending pass at longword stride.

### Interrupts

Installed handlers **write `$1FFF0`/`$1FFF1`** (six of the twelve self-test handlers do), so an
interrupt handler and the main line must be able to interleave on that register. Delivery must occur
within a **16-iteration `btst`/`dbeq` budget**. These particular waits **fall through** on timeout
rather than retrying, so a non-delivering model fails later and elsewhere.

### Board status `$F70018`/`$F70019`

**Never written** — read-only. Confirmed correspondences, with polarity:

| drive | response |
|---|---|
| `$1FFF1` bit 6 = 0 / 1 | `$F70019` bit 3 = 1 / 0 |
| `$1FFF1` bit 4 = 1 / 0 | `$F70019` bit 1 = 0 / 1 |
| `$1FFF1` bit 5 = 1 / 0 | `$F70019` bit 1 = 1 / 0 |
| `$1FFF0` bit 0 = 0 with `$1FFF1` bit 5 set | `$F70019` bit 1 = 1 |
| `$1FFF1` bits 0-2 non-zero (bit 7 enabling) | `$F70019` bit 2 = 1 |

Bit 3's test repeats its first condition after toggling, so the response must **follow**, not latch.

## Channel-transaction contract, measured (2026-07-31)

**A driven channel touches exactly five registers**: `+$08`, `+$0A`, `+$0E`, `$FF0202` (MODE1) and
its own BIM control register. Nothing else in the AP I/F or XLTR moves during a transaction.

| requirement | detail |
|---|---|
| `+$0E` accepts | **`$8004`** REQUEST-TRANSFER (all handlers) and **`$8005`** CONTINUE-TRANSFER (`D2_FIN` only) |
| `+$0E` returns | bit **14** = DONE, bit **13** = ERROR; polled 1000 times |
| `+$08`/`+$0A` | one 32-bit register, written high half first; the operation code goes to `+$0A` |
| BIM CR | driven to **`$4F`** for the transaction and restored to **`$5F`** |
| `$FF021A` | the channel's bit is cleared on teardown — map `1->5, 2->4, 3->3, 4->2` |

**The bulk-port path needs BOTH ready mechanisms.** When the source or destination is `$FF0008`,
`POLL` and `BLK_XFR` first spin on **`$FF0004` bit 0**, and `POLL` additionally arms **`$FF0218` with
`$400`, waits for bit 15, and clears it**. A model implementing only one hangs in the other; the two
sit 32 bytes apart in the same routine.

**Operation code `$04` is a special case**: `D1_SEND` issues the transfer and returns *without*
polling for DONE, going straight to teardown. A model that expects every `$8004` to be followed by a
DONE poll will see one that never comes.

## AP I/F hardware structure, from the `512-3448-010` schematics (2026-07-31)

Read from an FPS-100-class AP I/F drawing whose connector assignment matches the 4448 board in this
chassis on **fifteen independently-checked signals**, several to the exact pin. Structure should
transfer; AP-facing detail should not be assumed to.

### The register file

**One write bus (`RGBS00`-`RGBS15`), one read bus (`IFDB00`-`IFDB15`), per-register decoded strobes.**
Registers: `HMA-high`, `HMA-low`, `APMA`, `WC`, `CTL`, `TEMP`.

Selection is **six lines, `REGSEL00`-`REGSEL05`**, into **five `74S138` decoders** (two WRITE, three
READ) on sheet 5, producing `CTLCLK#`, `HMACLK#`, `HMALCLK#`, `RDCTL#`, `RDFIF#`, `RDHMAH`, `RDHMAL`,
`RDAPMA#` and about twenty more.

### The counters

| counter | parts | width | notes |
|---|---|---:|---|
| **APMA** | 4 x `74S169` | 16 | drives `DMA00*`-`DMA15*` to the connector |
| **WC** | 4 x `25LS2569` | 16 | **`WC = 0` generates `DMADONE`** — the transfer terminator |

The `AM25LS2569PC` visible on the 4448 board photograph is the same part in the same role.

### The FIFO

**16 words deep**, eight `27S03` 16x4 RAMs, with independent `74S161` read and write pointers
(`RADDR00`-`03`, `WADDR00`-`03`) and two banks (`CS1#`/`CS2#`, `WRTE1#`/`WRTE2#`).

- **write side is host-driven**: `DMASTB` arrives differentially, is synchronised, and generates
  `WRTCLK`/`FIFOWRT`
- **read side is SBC-driven**: `RDFIFO#`/`RDCLK` advances the read pointer

### The host link is RS-422 throughout

`3487` drivers and `3486` receivers with termination networks. Differential pairs identified:
`DMASTB`/`DMASTBR` (B22/23), `SAPX`/`SAPXR` (B25/27), `SHSTX`/`SHSTXR` (B29/31), `CTLACK`/`CTLACKR`
(B5/6), `APDMAACT`/`APDMAACTR` (B7/8), `HDMAACT`/`HDMAACTR` (B19/21), `DAVAL`/`DAVALR` (A71/73),
`DACK`/`DACKR` (A75/77), `CTLOUT`/`CTLOUTR` (A94/95).

### Where DONE and ERROR could come from

The control register takes **`WC-0`**, **`OVFL*`** (A70) and **`UNFL*`** (A72) as inputs — a
transfer-complete condition and two FIFO error conditions, feeding a register the processor reads
back through `RDCTL#`. That is the first hardware-side account of the **bit 14 = DONE** and
**bit 13 = ERROR** the firmware polls at `+$0E`.

### Bus inventory

Five 16-bit buses (`DMA`=APMA address, `HST`=host link, `HD`, `DPMBS`, `IO`) plus `PNL`, `DA`,
`SP+DP` at 8 bits each and `REGSEL` at 6. **200 pins across two connectors** — which is why the
counterpart host adapter cannot be improvised.

## RDHC command interface and the S-record loaders (measured 2026-07-31)

### The four commands

| cmd | validates | reject | model must |
|---:|---|---|---|
| 1 | channel `1..$105E`, defaulting from `$E62` | `$25C` | be able to supply an out-of-range channel |
| 2 | `index + count <= 16` longwords (on the **sum**) | `$25B` | be able to violate the sum with either field in range |
| **3** | **nothing** | — | **not add a bound** — the hardware has none |
| 4 | record type; destination address range | `$25F`, `$25A` | supply bad types and out-of-range addresses |

### The SLC ASCII loader

**Record set `S0 S1 S2 S3 S8 S9`**, dispatched by ASCII value at `$F04B68`; anything else drains and
reports `$25F`.

| record | handler | address shift |
|---|---|---|
| `S0` | skip `d4` words, contents ignored | — |
| `S1`/`S2`/`S3` | `SRecordDataHandler` | `$08`/`$10`/`$18` |
| `S8`/`S9` | `SRecordFinalize` — writes **`$E7E`** | — |

- **Stream is unframed**: two ASCII characters per 16-bit word, records back to back, **no delimiters**.
  Anything between records desynchronises permanently.
- **Every word costs a full `$FF0218` arm / poll-bit-15 / clear handshake**, including the address field.
- Destination is `$10 + addr + $10000`, **demonstrated for all three data widths**.
- The bound is enforced **per byte** and truncates exactly at `$1FFFF`, reporting `$25A`.

### What neither loader validates

**Checksums are consumed and ignored by both** the ASCII and binary paths — verified by a
control-validated sweep for accumulating arithmetic in each, and demonstrated by loading records with
deliberately wrong checksums to identical results.

Three silent failure modes, each demonstrated: **wrong checksum** (loads anyway), **framing**
(desynchronises), **S0 byte count** (discards the whole transfer). None produces an error code.

**Model consequence**: do not compute or check checksums; do not resynchronise the stream on a record
start; do not validate the S0 count. All three would be more forgiving than the hardware and would
hide real failure modes.
