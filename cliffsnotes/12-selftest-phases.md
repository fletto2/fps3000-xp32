# The power-on self-test, phase by phase

The self-test broadcasts a two-level phase counter to `CHANNEL_SELECT` (`$FF0204`) — the
high byte is the major phase, the low byte a sub-phase within it. On a board with no serial
output that counter is the primary diagnostic, so this table maps every code to the routine
running and to what a model must do to get past it.

Derived mechanically by walking `d6` through the `move.l #base,d6` and `addi.w #$100,d6`
steps, so it can be regenerated rather than trusted.

## Sequence A — base `$0200`

| phase | routine | what it does | model must |
|---|---|---|---|
| `$0200` | `$F08C4A` | VMOD bit 6 ↔ board bit 3 mapping | clear VMOD bit 6 ⇒ board bit 3 reads 1 |
| `$0300` | `$F08D1A` | **ROM checksum** — whole image XORs to zero | ship an image whose XOR is zero; failure **retries forever** |
| `$0400` | `$F08D5E` | DRAM address-line walk from `$10000` | distinct storage at every power-of-two offset |
| `$0500` | `$F08DF8` | `BoardStatusPoll_3F11` | `$F70019` masked `$3F31` must equal `$3F11` |
| `$0600` | `$F08E2E` | **VMOD longword pattern test** — 8 patterns | `$1FFF0`-`$1FFF3` reads back exactly what was written |
| `$0700` | `$F08F1C` | **bus-timeout watchdog** | a fault somewhere in `$F80001`-`$F82001` |
| `$0800` | `$F08F70` | interrupt delivery, vector `$51`, CPU mask 0 | deliver via the VMOD interrupter |
| `$0900` | `$F0905A` | PTM interrupt + latch walk, CPU mask 4 | T1/T2/T3 latches read back all 16 bits; interrupt routed through the interrupter as vector `$54` |

## Sequence B — base `$1000`

| phase | routine | what it does | model must |
|---|---|---|---|
| `$1100` | `$F0918C` | VMOD bit 4 ↔ board bit 1 | set VMOD bit 4 ⇒ board bit 1 reads **0** |
| `$1200` | `$F09236` | interrupt delivery, vector `$53`, **CPU mask 2** | honour the SR mask against the request level |
| `$1300` | `$F09338` | the interrupter and its request-level field | level 0 ⇒ board bit 2 clear; non-zero ⇒ set |
| `$1400` | `$F093CE` | vectors `$50`/`$52`, **nested delivery** | deliver a second interrupt inside a running handler |
| `$1500` | `$F094F0` | **CHANNEL_SELECT read-back**, values 0-5 | `$FF0204` must latch, not return a chassis value |
| `$1600` | `$F09518` | **XLTR register file** — four indexed walks | `$FF0210`-`$FF0216` and all BIM registers read back |
| `$1700` | `$F09602` | `$FF0216` bit 5 | set ⇒ bus error on `$400000`, read **and** write |
| `$1800` | `$F096C4` | `$FF0216` bit 6 | **inert** — no fault, all four combinations |
| `$1900` | `$F09776` | the 16→32 width mux | |
| `$1A00` | `$F09832` | `$FF0216` bit 7 | set with `$FF0218` armed ⇒ bus error on `$FF000E` |

## Sequence C — base `$2000`

| phase | routine | what it does | model must |
|---|---|---|---|
| `$2100` | `$F08992` | **exhaustive DRAM uniqueness** — every address at itself | no aliasing anywhere; skips 4 bytes at `$1FFF0` |
| `$2200` | `$F09AD6` | SCM address-line walk to `$4000` | distinct storage in the chassis window |
| `$2300` | `$F09B20` | **SCM pattern test** — 16 KB, forwards then backwards | `$400000`-`$403FFF` true read/write at page 0 |
| `$2400` | `$F09986` | DRAM patterns — 3 complementary pairs | |
| `$2500` | *(inline)* | DRAM boundary signature at `$EFF0`/`$10000` | |
| `$2600` | `$F09A7E` | **DRAM refresh** — fill, wait 0.675 s, verify | untestable in a model with perfect RAM |

## Between sequences

Each sequence ends in a **checkpoint handshake**: write `$D0` to `$1FFF0`, `MODE1 <- $8000`,
arm vector `$55` with a bare `rte`, then poll `$F70019` bits 4 and 5. **Both set means stop**
— the same signal that aborts the SCM test. Both clear means carry on.

## Failure behaviour

Every failure sets `d7 = $F0F0F0F0` and **retries its arm indefinitely**. So a model that
gets a requirement backwards **hangs in that phase** — the symptom is a stuck sub-phase in
`CHANNEL_SELECT`, not a message. Two fault counters accumulate at `$0400` (low stack) and
`$1F800` (high stack), but only `$0400` survives to a post-boot dump; `$1F800` becomes
`!IDV`'s base.

A failed suite still **continues into RTOS initialisation** — `$F088F4` jumps to `$F09C06`
either way — so reaching the RTOS is not evidence the self-test passed.

---

## How the suite handles a failure — read this before interpreting any phase

Added 2026-07-31, after decoding `PollBoardStatus` (`$F0891C`). It changes how every phase
below should be read.

**There is no failure exit.** Each test arm, on a mismatch, loads `d7 = $F0F0F0F0`, calls
`PollBoardStatus`, then `tst.l d7` / `bne` back to the top of the arm. `PollBoardStatus` **never
clears `d7`**. So a failing test re-runs forever. No counter, no timeout, no "record it and move
on" anywhere in the suite.

What the poller does on a fault is *announce* it — clear `$1FFF1` bit 6 and write **MODE1 =
`$1000`** — and then check whether the chassis has authorised giving up:

```
board bit 4 set AND board bit 5 set  ->  jmp Phase2Init   ; abandon diagnostics, boot anyway
```

So the fault policy is **retry indefinitely while signalling, until the chassis says stop**.
That is a service-mode design: a technician can hold the machine inside the failing test with a
scope on the failing line, then release it.

Three practical consequences:

1. **A stalled board is diagnosable.** `CHANNEL_SELECT` holds the two-level phase code of the
   looping test — major byte = which test, minor byte = which stage. That is what the counter is
   for, and it is the only diagnostic an unpowered-serial board offers.
2. **In an emulator, a modelling shortcut presents as a hang, not an error.** Anything the
   tests require — SCM being real memory, `$400000` faulting when `$FF0216` bit 5 is set, the
   VMOD interrupter delivering — turns into a silent infinite loop if unmodelled.
3. **A model that cannot raise board bit 5 can never reach the abort**, so it has no way to
   skip a test it fails. The escape hatch is the chassis's, not the SBC's.

### The idioms every phase shares

| idiom | meaning |
|---|---|
| `d7 = $F0F0F0F0` | the fault flag; set on failure, never cleared |
| `d2` / `d1` set by a handler | ISR-to-mainline signalling — an interrupt or bus-error handler deliberately clobbers a register so the interrupted code can see it happened |
| `dbne d3` with `d3 = $F`/`$FF` | a **bounded** wait for that signal (16 or 256 iterations) — a missing event never hangs *here*, it falls through and the arm records a fault |
| trailing `nop` padding | absorbs the 68000's imprecise bus-error PC; the handler blindly does `addq.w #$4,$4(a7)` and lands in the padding |
| `[$8]` saved and restored | a temporary bus-error handler is installed for the duration of a guarded probe |
| `addi.w #$100,d6` / `addq.b #$1,d6` | step the major / minor phase, then broadcast `d6` to `CHANNEL_SELECT` |
