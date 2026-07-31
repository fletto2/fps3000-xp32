# RMS68K structures on the FPS-3000 — a single reference

Everything a model or a RAM-dump reader needs about the RTOS's data, in one place.
Derived from the ROM (allocation code, walk routines, directive handlers) and cross-checked
against live RAM. Sources: `refs_extracted/versabus_access_map.md`.

## The allocator directory at `$0C20`-`$0C6E`

Eight structures, each a 256-byte-page allocation registered in a kernel global. The heap
grows **downward** from `$1FE00`, so allocation order is descending address order.

| slot | tag | base | pages | header | entry stride |
|---|---|---|---:|---|---:|
| `$0C20` | `!GST` | `$1FD00` | 1 | counted | `$12` = 18 |
| `$0C24` | `!UST` | `$1FB00` | **2** | counted | `$16` = 22 |
| `$0C66` | `!VCT` | `$1FA00` | 1 | none (byte array) | 1 |
| `$0C6A` | `!IOV` | `$1F900` | 1 | bounded | `$14` = 20 |
| `$0C6E` | `!IDV` | `$1F800` | 1 | bounded | `$0E` = 14 |
| `$0C2C` | `!PAT` | `$1F700` | 1 | list-heads | `$1E` = 30 |
| `$0C28` | `!UDR` | `$1F600` | 1 | — | 25 slots, all empty |
| `$0C30` | trace | `$1F500` | 1 | bounded | `$1A` = 26 |

Three of these assignments were wrong in this project's notes until 2026-07-31 (`$0C20`
"unassigned", `$0C6A` called `!PAT`, `!UDR` attributed to `$0C20`). Both the tag literal
each allocation writes and the descending-address ordering confirm the table above.

## The three header conventions

**Counted** — used by the two tables searched *by name*, which need a free-slot scan:
`+$0C` maximum, `+$0E` current, entries from `+$14`. (`!GST`, `!UST`.)

**Bounded** — `+$00` marker, `+$04` = `base + pages*256 - 1`, entries from `+$08`; walks
run until the pointer passes `+$04`. (`!IOV`, `!IDV`, trace.)

**List-heads** (`!PAT` only) — `+$04` free list, `+$08` and `+$0C` the two active lists the
tick walks, `+$10` size, slots from `+$14`.

## Entry layouts

| structure | layout |
|---|---|
| `!GST` | `+$00` name, `+$04` owner, `+$08` flags (3-way share/exclusive test), `+$0A` in-use (0 = free) |
| `!UST` | `+$00` name, users/type/session, **`+$10` the semaphore object** — `{word: bit 15 TAS lock, bits 14-0 signed count}` then a longword waiter list |
| `!IDV` | `+$00` vector, `+$02` TCB, `+$06` ISR entry, `+$0A` ISR exit |
| `!VCT` | `byte[vector] = owning task number`; `$41`→6 RDHC, `$45`-`$48`→1-4 XP, `$4A`→5 IO1I |
| trace | `{code, SR, PC, A0, A6, D0, time_ms, time_us}` = 26 bytes; header `TRCPTR`/`TRCLNG` |
| `!PAT` | 30-byte slots, free ones marked `$FFFFFFFF` at `+$04` |

## The clock

| global | meaning |
|---|---|
| `$0C3E` | **days** (longword) |
| `$0C42` | **milliseconds within the day**, rolls at 86,400,000 |
| `$0C46`/`$0C4A` | accumulated clock *adjustment*, so intervals survive a `$49` set-time |
| `$0C56` | tick period in ms = **10**, from config `$F0A530` |
| `$0C58` | 39, the MC6840 MSB reload derived from the same constant |
| `$0C5C` | a divider of 100 in the **spurious-interrupt** handler — which the FPS layer overrides, so it never fires. Not a heartbeat |

One ROM constant (`$F0A530 = 10`) generates the PTM latch `$27C7`, the 10.0000 ms tick and
the millisecond arithmetic. (It does **not** drive a display heartbeat — that reading was
retracted: the divider lives in the spurious-interrupt handler, which is overridden.)

## The scheduler and task state

| global | meaning |
|---|---|
| `$0C08` | scheduler block: base/stack, current task `+$04`, all-tasks head `+$08`, ready head `+$0C` |
| `$0C52`/`$0C54` | quantum countdown / reload (2 ticks = 20 ms) |
| `$0C78` | saved `a7` + re-entry guard for the `$F70030` handler |
| `$0C8E` | a lock taken via P/V |
| `$0C9A`/`$0CAA` | server registry: slot states, then 22-byte records |
| `$0C7C` | five 6-byte records `{1, null}`, ending exactly at `$0C9A` |

### TCB fields (usage-derived; the vendor `TCB.EQ` is displaced in this build)

| offset | field |
|---|---|
| `+$20` | semaphore waiter-list link |
| `+$25` | **maximum** priority (ceiling, inherited downward by `CRTCB`) |
| `+$26` | **current** priority (raised to `$F0` in kernel critical sections) |
| `+$2C` | state word — 2 & 11 server, 6 context-saved, 9 SUSPND, 12 WTEVNT, **13 semaphore**, 14 WAIT |
| `+$74` | register save area, `d0-d7/a0-a6`, 60 bytes (`+$77` is the saved `d0`'s low byte, not a field) |
| `+$FC` | saved resume PC |
| `+$100`/`+$102` | directive status/return code (1..16, all populated; `$9` = privilege refusal) |
| `+$138` | stack/ASQ block pointer |
| `+$13C` | saved stack pointer |
| `+$140`/`+$144` | owner name/session copy (the `RSTATE` permission check) |
| `+$148` | per-task trace control — bits 3-5 class enables, bit 7 armed |
| `+$158`/`+$15A` | a counter and its limit, loaded together as one longword |
| `+$160` | `!TST`, 80 bytes |
| `+$08` | **no kernel accesses at all** — unused in this build |

## Blocking

`P` = `$F006E8`, `V` = `$F00788`. Both mask to level 7, spin on `tas.b`, read the count with
`lsl.w #1`/`asr.w #1`, and update it. `P`'s slow path links the TCB through `+$20`, sets
state bit 13, releases the lock, installs the scheduler stack from `$0C08` and `bra`s to
`$F0050C` — it does not return. **`tas` must be atomic against the chassis bus master.**

## The TDTI boot table at `$F0A600`

Six 96-byte records; the loop at `$F0A066` consumes each and calls `T0CRTCB`.

| offset | role |
|---|---|
| `+$00` | `!TCB` marker — also the terminator test |
| `+$04` | task name |
| `+$14` | word → `d6` (zero here) |
| `+$16` | byte `$96`, **duplicated into both halves** of `d4`'s high word → `$9696` |
| `+$18` | **initial task state word** → `TCB+$2C`; **bit 4 = put on the ready list** |
| `+$1A` | word `$A000` → `d4` low |
| `+$1C` | **task entry point** → `d5` |
| `+$20`-`+$5F` | segment descriptor block, 16 longwords copied verbatim into `!TST` |

The segment *count* is not stored — TDTI walks four 8-byte slots from `+$20` and counts
those with a non-zero word at `+$06`. Exactly one qualifies (`PROG`), which is why `!TST`
reads `TSTNSEGS=4, TSTCSEGS=2`: the second is `STCK`, added later by the task's own `GTSEG`.

## Device pointers

Only three globals hold device addresses: `$0C4E` (PTM), `$0C3A` (display, or scratch `$800`
when unfitted), `$0E48` (VERSAmodule control register, address *computed* from RAM top).

The PTM is reached **three ways** — the `$F70001` literal with even displacements
(self-test only), config `$F0A52C` = `$F70000` with odd displacements (RTOS init), and the
cached pointer (tick ISR). All five PTM registers are used; **T2 only by the self-test**.

---

## The TCB, re-derived 2026-07-31

A census of all 52 `a6` offsets in the kernel (395 accesses), classified against the two register
frames. **Nearly half the traffic is register-frame access, not field access** — the distinction
matters, because writing a field changes kernel state while writing a frame slot changes what the
task sees in a register when it next runs.

### Register frames — 12 offsets, 179 accesses

| range | contents | used by |
|---|---|---|
| `+$74`-`$AF` | `d0`-`d7`/`a0`-`a6` (60 bytes) | the **full-context** dispatch exit (state bit 6) |
| **`+$FA`-`$FF`** | the **exception frame `{SR, PC}`**; `+$FB` is the CCR byte | copied back onto the task stack before `rte` |
| `+$100`-`$13F` | `d0`-`d7`/`a0`-`a7` — **`a6` at `+$138`, `a7` at `+$13C`** | the **normal** dispatch exit |

`movem` restores `d0`-`a5`; `a6` and `a7` must be restored separately (`a6` is the TCB pointer,
`a7` is the USP). The suspend path reserves `6 + $3C = 66` bytes on the task's own stack — exactly
the exception frame plus the register block.

**`+$102`, the kernel's busiest offset (119 accesses), is `saved d0 + 2`** — which is the whole
explanation of the status-in-`d0` return convention and of why it is cleared at TRAP #1 entry.
Likewise `+$77`, `+$94`, `+$120`, `+$122`, `+$123`, `+$124`, `+$130` are saved-register bytes.

### Identity — three `{name, session}` pairs

| pair | role |
|---|---|
| `+$10` / `+$14` | the task's **own** identity — `T0GETTCB`'s lookup key |
| `+$B0` / `+$B4` | a **self-copy**; overwritten with `'EXEC'` on termination, i.e. a **rename** |
| `+$140` / `+$144` | the **owner's** identity, stamped in from another TCB |

### Flags and state

| offset | bits |
|---|---|
| `+$28` (word) | **7 = privilege** (also a session wildcard in `T0GETTCB`); **3, 4 = `$F00B74` dispatch enables** |
| `+$29` (its low byte) | **6 = an owner is registered at `+$140`/`+$144`** |
| `+$2C`/`+$2D` (state word) | **4 = on the ready list, 5 = ASQ pending, 6 = context saved, 7 = deferred work** — each selecting a different dispatch exit; plus documented bits 2, 9-14 |
| `+$2E` | a saved copy of the state word |
| `+$148` | **bit 7 = one-shot single-step enable** — armed by the exception monitor at `$F00D3E`, consumed at `$F005A8` |

### Other fields

| offset | role |
|---|---|
| `+$04`, `+$0C` | all-tasks and ready-list links |
| `+$20` | semaphore waiter link |
| `+$25`, `+$26` | priority bytes (both raised to `$F0` in critical sections) |
| **`+$36`** | **logical→physical translation base** — passed to `T0LOGPHY` at 24 sites |
| `+$40` | second ASQ pointer |
| `+$44` | a structure base, only ever `lea`'d |
| **`+$5E`** | a **staged return status**, later moved into `+$102` and cleared |
| `+$6C` | entry point |
| `+$14C`-`$15B` | a mask (`+$14C`), two values, and the **count/limit** longword at `+$158`/`+$15A` |
| `+$160` | `!TST` |

### What changed

Five items in the previous map were re-attributed: `+$138` is **saved `a6`**, not an ASQ block
pointer; `+$B0` is a **name field**, not an `'EXEC'` marker slot; `+$102`/`+$114`/`+$120`/`+$123`
are **register slots**, not independent fields; and `+$00` is **not a field at all** — its 23
apparent accesses are `lea`/`pea` passing the TCB pointer itself.

---

## Live contents of every RTOS structure (2026-07-31, from a boot RAM dump)

### `!GST` shares `!UST`'s header format — and is empty

`UST.EQ`'s 20-byte header layout applies verbatim to the Global Segment Table:

| field | `!UST` `$1FB00` | `!GST` `$1FD00` |
|---|---|---|
| `NSEG` | 1 | 1 |
| **`NPAGE`** | **2** | **1** |
| `MENT` (entry size) | 22 | **13** |
| **`CENT` (entries)** | **9** | **0** |
| `FENT` (first entry) | `$1FB14` | `$1FD14` |

Two things follow. **`!GST` is empty** — no global segments exist, which is why directive `$09`
`T0FNDGSG` would never find anything. And **`NPAGE` matches the configuration block from the other
end**: this project records the allocator page counts as `1, 2, 1, 1, 1, 1, 1`, with the two-page
entry at `$F0A51A` allocating the structure whose header reports `USTNPAGE = 2`. `!GST` reports
`NPAGE = 1`, consistent with the remaining single-page entries. Two structures now confirm the
config block's page counts against their own live headers.

### The rest, measured

| structure | live state |
|---|---|
| `!IDV` `$1F800` | **populated** — bound `$1F8FF`, then 14-byte records `{vector, TCB, ISR entry, ISR exit}`; the first is `{$45, $1E900, $F07EE6, $F07F08}` = XP1I, matching the documented IRQ table exactly |
| `!IOV` `$1F900` | **empty** — tag and bound pointer only, 7 non-zero bytes in the page |
| `!UDR` `$1F600` | **empty** — count `$19` = **25 slots**, all unused, confirming the documented figure |
| `!PAT` `$1F700` | **free list only** — head `$1F714`, chaining to `$1F732` at the documented `$1E` stride; active list null |
| `!GST` `$1FD00` | **empty** — `CENT = 0` |
| `!UST` `$1FB00` | **9 entries**, first named `XP1I`, exactly as recorded |
| `!VCT` `$1FA00` | 256 bytes, `byte[vector] = owning task` |

So of the eight allocated structures, **three are populated** (`!IDV`, `!UST`, `!VCT`), one holds
only a free list (`!PAT`), and **four are empty** (`!IOV`, `!UDR`, `!GST`, plus `!CCB`/`!DLY` which
have no instance at all). That is the machine's real shape: the interrupt wiring and the semaphore
registry are live; segments, user directives, I/O vectors and periodic activations are all
mechanisms present and unused.

---

## `!TST` measured across all six tasks (2026-07-31)

Every field is identical except the two page ranges:

| field | value |
|---|---|
| `+$04` | `$04020024` — **`TSTNSEGS=4`, `TSTCSEGS=2`** for all six |
| `+$08` | `$00440000` for all six |
| `PROG` attributes | `$80000000` for all six — from the TDTI record's `+$44` |
| `STCK` attributes | `$8000FF00` for all six |
| `PROG` pages | **per task**, byte-identical to the TDTI record's `+$20` |
| `STCK` pages | **per task**, two pages, allocated descending |

The `STCK` allocation is a clean descending tile, two pages each from the `$190` request in every
region head's `CRTCB` block:

| task | pages | bytes |
|---|---|---|
| XP1I | `$1E7`-`$1E8` | `$1E700`-`$1E8FF` |
| XP2I | `$1E5`-`$1E6` | `$1E500`-`$1E6FF` |
| XP3I | `$1E3`-`$1E4` | `$1E300`-`$1E4FF` |
| XP4I | `$1E1`-`$1E2` | `$1E100`-`$1E2FF` |
| IO1I | `$1DF`-`$1E0` | `$1DF00`-`$1E0FF` |
| RDHC | `$1DD`-`$1DE` | `$1DD00`-`$1DEFF` |

confirming this project's "the blocks tile `$1DD00`-`$1E8FF` at stride `$200` **in reverse task
order**" — XP1I is allocated first and gets the highest pair. Each base is also the task's
`TCB+$138` (its saved `a6`), and each `$190` request really does round up to `$200`, six times over.

So `!TST` holds **no per-task information that is not either a ROM constant or a deterministic
consequence of allocation order.**
