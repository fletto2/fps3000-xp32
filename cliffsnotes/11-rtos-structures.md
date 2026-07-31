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
| `$0C5C` | 100-tick divider → a **1 Hz write to the display** at `$0C3A` |

One ROM constant (`$F0A530 = 10`) generates the PTM latch `$27C7`, the 10.0000 ms tick, the
millisecond arithmetic and the 1 Hz heartbeat.

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
