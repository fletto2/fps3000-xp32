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

- **`$600`**, the bus-timeout watchdog test, *requires* a BERR somewhere in `$F80001`-`$F82001`.
  A model returning zero for unmapped space hangs here.
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
