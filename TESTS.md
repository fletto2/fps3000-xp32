# The FPS-3000 hardware probe — what each test does and why

`tools/fps3k_probe.py`. Companion to `MONITORTEST.md`, which is the running
build log; this is the reference for the tests themselves.

```
python3 tools/fps3k_probe.py --port /dev/ttyUSB0        # the board
py -3 tools\fps3k_probe.py --port COM3                  # ...on Windows
python3 tools/fps3k_probe.py --emulator                 # rehearsal
```

**Finding the port.** `python -m serial.tools.list_ports -v` lists every port
with its VID/PID; unplug the adapter and run it again, and the entry that
disappears is yours. The probe does the same enumeration itself if the port
will not open. Two Windows specifics: **COM9 and above** need a `\\.\` prefix,
which pyserial applies itself (`serialwin32.py:49`), so `--port COM12` works
unmodified; and **serial ports are exclusive**, so PuTTY, TeraTerm or the
Arduino IDE holding the port gives `PermissionError(13, 'Access is denied.')`,
which reads exactly like a dead board.

**No gates.** Writes, AC access, the `rts`/`nop` opcodes and the ISR neuter all
run unconditionally, because a gated run reports *"skipped"* where a bench
session needs a result. The remaining flags pick the transport and the output
file.

---

## 1. What the probe is for

Three questions the disassembly cannot answer, because they are about silicon
the SBC can barely see:

1. **Does anything behind an AC channel window interpret an operation code**, or
   is the window a latch?
2. **Does the AC fetch the staging buffer itself?** The firmware sends an
   address and a count and never copies the buffer, so the AC must DMA — but
   that is an inference from a bus-master argument, not a measurement.
3. **Is any part of the AU microword being interpreted yet?**

Everything else in the run exists to stop those three being misread.

---

## 2. The mechanism: TRAP #14 stubs

The monitor's `m` and `w` use **`move.b`**, and the AP I/F and XLTR are
**16-bit-only blocks** — byte access cannot drive them at all. So every
word-sized access assembles a short 68000 stub into scratch RAM, `g`s to it,
and returns through **TRAP #14** (vector `$B8` → `monitor_entry`).

> **That premise no longer holds, and the probe has not been rewritten.** The
> monitor gained native word and long access (`mw` `ml` `ww` `wl`), the two
> register maps (`x` `y`), the AC transaction (`c` `ca`), the chassis window
> (`p` `pw`), the bulk drain (`e`), the ready poll (`q`), the ISR taps (`s`)
> and the region checksum (`z`). A plain device read or write needs no stub
> now, and several phases here assemble one to do what a single command does.
> The probe still works — the stubs are still valid 68000 — but read section 2
> as history rather than as a constraint.
>
> **What survives untouched is the second half of the rule below.** A stub is
> still the only way to *compute* on the board: a timed loop, a bounded poll
> with its own exit, or anything that must run at full speed between two
> round trips. Phase K's bus-contention timing could not be written any other
> way.

There is a mini assembler in the script for this. It has been wrong once, in a
way worth remembering:

> `movew_d_abs` put the register in bits **9-11** — the *destination* field —
> instead of bits **0-2**. Correct only for `d0`, so status read fine while
> `d1`/`d2`/`d3` all returned `d0`. It produced `polls=-48156` and **a false
> finding that the AC data pair does not read back**, contradicting what the
> listing says about `+$08`/`+$0A`. Unit-verified now: `move.w d3,($1400).L`
> assembles to `33c3`.

### Why work runs on the 68000

At **9600 baud** the link is ~960 B/s. A 64 KB ROM sweep through `m` is about
**512 round trips, six minutes**. The same checksum as a stub is **one round
trip**. The rule throughout: *compute on the board, return a number.*

---

## 3. Ordering: ascending mutation footprint

The run is unattended, so the order is chosen so that **if a phase hangs the
board, the cheap results are already banked**, and **no later phase can make an
earlier one lie**.

| tier | phases | what changes on the board |
|---|---|---|
| **R0** | A, B, J | nothing |
| **R1** | C | scratch RAM + stub execution, monitor workspace only |
| **R2** | D, E | device **reads** |
| **R3** | L | XLTR **writes**, restored and verified |
| **R4** | G, F, I | AC channel writes |
| **R5** | H | 1 KB of SBC RAM + the address/count handshake |
| **R6** | K | reprograms the MC6840 |

Execution order: **A B J J2 C D E L G F I H K**.

**J2 runs out of order.** It rewrites the vector table, R5 by footprint, but
its purpose is to stop the RTOS pre-empting everything below it. Originals are
printed, and restored at exit.

Twelve regression checks pin the ordering, including that read-only precedes
the first RAM write, device reads precede device writes, and the PTM phase is
last.

---

## 4. The phases

### R0 — read only

**A — link and monitor identity.** Banner, prompt, command list.

The only phase whose failure is about the **cable**, so its diagnostic is
deliberately long: 9600 8-N-1 (strap on a VM02 — there is no BRCR), RX/TX not
swapped (P2 pin 73 is the SBC's TXD → adapter RX, pin 75 is RXD), ground on
pin 1, and the **±12 V the chassis does not supply**. Correct code driving
unpowered RS-232 drivers looks exactly like a dead board.

**B — board identity.** Reads the six task ISR vectors against an **exact
address table**. A range test ("is it in ROM?") is not enough: all six vectors
in the `--reset` image read `$00F0A840` and would pass one. Distinguishes stock
ROM / reset image / uniform fill.

**J — interrupt exposure.** Whether the RTOS ISRs are live, since a stub that
runs with them armed can be pre-empted mid-transaction. Reads the saved SR and
reports the IPL. It runs before any write because it says whether writing is
safe.

### R1 — scratch RAM

**C — memory survey.** ROM XOR **computed on the 68000**, then the staging
buffer, the kernel globals, and an `!TCB` scan. This is also the first phase
that proves the stub mechanism works; everything below depends on it.

### R2 — device reads

**D — 16-bit device survey.** The XLTR register block through stubs.

**E — channel presence.** Which channel's `+$0E` reads non-zero — the boot
probe's own inventory (`$105E`) re-derived from outside the firmware. Later
phases take their channel list from here.

### R3 — XLTR writes

**L — the `$400000` window.** MODE2 paging, and `$FF0216` bit 4 with `$FF0214`
as the 16→32 width mux.

Both registers are put back. MODE2 → `$0000`, which is what RTOS init does.
**`$FF0216` bit 4 matters more:** the firmware *brackets* it around a single
`CPLOAD` (`bset $F0550A`, `bclr $F05582`) and never leaves it set — so a probe
that did would change how every AC transaction below behaves. The restore is
**read back and reported**, not assumed.

On paging the phase declines to conclude: one address cannot separate *no
paging* from *same value on every page* from *nothing there*, and it says so.

### R4 — AC channel writes

**G — fire-and-forget and the data pair.** `$8000` does no harm; `+$08`/`+$0A`
is a real 32-bit latch, three patterns written and read back. Ordered before F
because it starts no transaction.

**F — the AC transaction, by hand.** The core experiment: drives `$F056BA`'s
sequence directly —

```
+$08 <- $0000
+$0A <- opcode
+$0E <- $8004            REQUEST-TRANSFER
poll +$0E bit 14, up to 1000 times, watching bit 13 for error
```

**The echo discriminator is the important part.** If every opcode returns the
same status, in **zero polls**, handing back **the word we wrote to `+$0A`**,
that is a latch echoing — not an AC responding. Without it a passing emulator
run looks exactly like a live AC.

> **A live AC is a status that VARIES by opcode, with a non-zero poll count.**

Opcodes `$0B`/`$0C` land on the `rts`/`nop` slots of the firmware's 42-entry
dispatch table, which **crash the SBC**. They run anyway, because this probe
writes the channel window directly and **never enters that table**.

**I — microcode layout hypotheses.** Six microword shapes: all zero, all ones,
sequencer `CONT`, sequencer `JMAP`, walking bit 0, walking bit 127. If all six
give the same status, nothing is interpreting a microword and **a full bit-walk
is premature**.

### R5 — SBC RAM

**H — microcode injection.** Fills 1 KB at `$10010`, verifies by XOR on-board,
issues the address/count handshake (`$8004` then `$8005`), re-reads the buffer.
The fill stops well short of `$1DD00`, where the live TCBs begin.

**Re-reading proves little on its own** — a microcode load is the AC *reading*
SBC RAM, so it changes no memory. That is what K is for.

### R6 — the MC6840

**K — bus contention.** The **only DMA detector the SBC can see**. Timer 1 free-
running; an identical RAM-touching loop timed with and without a transfer
outstanding. A bus master cannot hide cycle stealing.

**Calibrated, not assumed:**

```
  5954 ticks / 2000 passes = 29.8 CPU cycles each
  predicted from instruction timings:  8 + 12 + 10 = 30
  spread across four runs:             1 tick
```

Resolution ~1 part in 6000 — a DMA stealing 0.1% of the bus would show.

Runs last, and only on the `--reset` image: the CR1 reset bit holds **all
three** timers and **T3 is the RTOS system tick**.

Two PTM constraints that would each have failed on iron:

* **odd-byte only** (`$F70001`-`$F7000F` on D0-D7) → every access is `move.b`,
  and the 16-bit counter is two byte reads **MSB first**, because reading the
  MSB latches the LSB;
* **CR1 bit 1 is the clock source** — `0` is the *external pin*, which is how
  the firmware leaves T1 and why the counter would never move. `$02` is the E
  clock.

---

## 5. Resilience

| | |
|---|---|
| **per-phase guard** | one failure cannot end the run |
| **link loss** | detected once and reported as such, so a dead cable cannot masquerade as twelve findings about the board |
| **fault reporting** | a bus or address error reports **the faulting address and function code**, not just a PC inside the stub — `MON_FADDR`/`MON_SSW`, added to the monitor for this |
| **vector restore** | in a `finally`, and the originals are printed so they can be restored by hand if the script dies |

### Line endings

`read_line` terminates on **CR *or* LF**, so a `\r\n` ends the line on the CR
and the LF then starts and ends an **empty** one — and the monitor answers that
with **another prompt**. Left in the buffer, that silently desynchronises every
later command by one reply. Reproduced against a control:

```
  baseline  : 00F00000: 00 00 00 00 00 F0 A8 26 00 00
  unfixed   : fps3k> m 00F00000 10          <- stale prompt + echo, no data
```

The probe sends a **bare CR** and **flushes stale input before every command**.

---

## 6. What hardware can and cannot settle

**Can:** whether the AC interprets an operation code (F); whether it fetches
(K); whether the data pair, `$FF0214` and MODE2 are real registers; which
channels are populated; whether any microword shape is interpreted (I).

**Cannot, ever, from the SBC side:** anything past the channel window. The
self-test itself never touches XP-32 EXEC, ARITH or UNIV FMT, and the EU↔AU
link is a **private 160-conductor ribbon** on neither the VersaBUS nor the XP32
bus. No amount of probing from here reaches it.

---

## 7. The emulator baseline

`probe_emulator_output.txt` is a full captured run. It is a **model, not a
board**, and reads that way:

```
  elapsed     10.8 s
  findings    7
  failures    0
  >> --reset image: all six vectors read $00F0A840 (cold_init fill)
  >> channels with non-zero +$0E: 1, 2
  >> $FF0214 latches -- a real register (one access site in the listing)
  >> data pair $FF0048/$FF004A latches exactly -- real registers
  >> every microword shape produced the SAME status
  >> address/count handshake completed both phases
  >> no contention: +0 ticks vs 0 spread.
```

Phase F's discriminator fires here exactly as designed — identical status, zero
polls, data equal to what was written. That is the honest reading for a model
whose AC is an acknowledger (`ch_lo` is written and never read), and it is the
line that stops a bench run being over-read.

**Timing:** ~11 s over the emulator transport, **~120 s over a rate-limited PTY
at true 9600 baud** — which is what a bench run should take.

---

## 8. Regression coverage

38 check sites in `tools/verify_findings.py`, across three blocks
(`_PROBE_assembler_encodings` 21, `_PROBE_line_endings` 7,
`_PROBE_risk_order` 10):

* assembler encodings, including the MOVE source/destination field;
* PTM byte-only access and `CR1 = $02`;
* the reset-image gate on phase K;
* `MON_FADDR`/`MON_SSW` in the monitor, and the `cmd_go` fix that let it run
  another stub after a fault;
* address-error emulation ON;
* **line endings** — including the two `cmpi.b` in `read_line` that make the
  hazard real, so if the monitor is ever changed to accept one terminator the
  check explaining the flush fails first;
* **risk ordering** — that the gates default on, that the twelve phases are in
  ascending order, and that phase L restores `$FF0216` *and reads it back*.
