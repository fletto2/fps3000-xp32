# MONITORTEST — probing a real FPS-3000 through the ROM monitor

Running context for `tools/fps3k_probe.py`. Written as the work goes, so it
records **what each test asks, why it can answer it, and what it cannot**.

```
  python3 tools/fps3k_probe.py --port /dev/ttyUSB0            # read-only survey
  python3 tools/fps3k_probe.py --port /dev/ttyUSB0
  python3 tools/fps3k_probe.py --emulator                    # rehearsal
```

**9600 8-N-1**, and that is not a default to be casually raised — the VM02 has
**no BRCR**; the rate is a hardware strap. `MPSCDRV.SA` adds software baud for
the VM03 only.

---

## 1. The objective

Make the AU work. Concretely, three questions:

1. **how microcode gets in** — the SBC hands the AC an *address and a count*,
   not data, so a load is the AC **fetching SBC RAM**. Provable from this side?
2. **how results come back** — the AC's whole SBC-visible surface is four
   registers per channel.
3. **whether the layout hypotheses survive contact** — the AMD 128-bit map, of
   which only the 21-bit Am2910 sequencer field transfers with confidence.

---

## 2. The mechanism, and why the monitor alone is not enough

The monitor's `m`/`w` use **`move.b`**. The AP I/F and the XLTR are
**16-bit-only** blocks, so byte access cannot drive them at all.

The way in is **TRAP #14** — vector 46 (`$B8`), which the monitor owns. The
probe carries a small 68000 assembler, builds a stub in scratch RAM, `g`s to
it, and the stub ends in `trap #14` to land back at the prompt. Every
word-sized device access in the script goes through one, and results come back
through a fixed `RESULT_ADDR`.

On the `--panic` image the firmware owns the vector table, so `b <addr>` is
issued once first — arming a breakpoint is what installs the TRAP #14 vector.

### Doing work on the board, not over the wire

At 9600 baud the link is ~960 B/s, and that reshapes the design:

| | over the wire | on the board |
|---|---:|---:|
| ROM whole-image XOR (64 KB) | 512 round trips, **~6 min** | **one stub, one word back** |
| fill + verify 1 KB of staging | 64 `w` + 8 `m`, ~14 s | **one stub, one word back** |

Both are stubs now. The ROM XOR returned **`$0000`** on the emulator, matching
the file-computed checksum — an independent confirmation through a completely
different path.

---

## 3. Phases

| | what it asks |
|---|---|
| **A** link | banner, prompt, command set |
| **B** identity | which ROM image is fitted, from the six task ISR vectors |
| **C** memory | ROM XOR (on-board), staging, kernel globals, `!TCB` scan |
| **D** word devices | the XLTR block through stubs |
| **E** channels | which channel `+$0E` reads non-zero — the boot probe's own inventory, independently |
| **F** AC transaction | **the core**: drive `$F056BA`'s sequence by hand, firmware entirely out of the loop |
| **G** `$8000` + pair | fire-and-forget does no harm; is the data pair a real latch |
| **H** staging + handshake | fill the buffer, issue address/count, look for DMA |
| **J** interrupt exposure | can a channel write raise a BIM interrupt into live RTOS ISRs |
| **K** bus contention | **does the AC actually DMA** — timed with MC6840 T1 |
| **L** `$400000` window | does MODE2 really page; is `$FF0214` a real latch |
| **I** layout hypotheses | six microword shapes; does the AC discriminate |

---

## 4. Phase F, and the discriminator that keeps it honest

Phase F writes `+$08`←0, `+$0A`←opcode, `+$0E`←`$8004`, then polls `+$0E` for
bit 14 (DONE) with bit 13 (ERROR), 1000 iterations — the primitive's own
budget. On the emulator all ten opcodes report DONE, which reads as *"an AC
answered"* and **is not one**:

> every opcode returns the **same** status, completes in **zero** polls, and
> hands back **the word written to `+$0A`**.

That is a latch echoing — exactly the emulator's model (*the AC is an
acknowledger, not a processor*; `ch_lo` is written and never read). The probe
tests for that triple and reports **"LATCH ECHOING, not an AC responding"**.
Without it a passing emulator run looks like a live AC.

**On hardware the signature of a real AC is a non-zero poll count and a status
that VARIES by opcode.**

Opcodes `$0B` and `$0C` land on the 42-slot table's `rts`/`nop` entries and
**crash** the SBC; they run anyway, which is safe here
only because the probe bypasses the firmware dispatch entirely.

---

## 5. Phase K — the only way to see a DMA from this side

A microcode load is the AC **reading** SBC RAM. A read changes no memory, so
re-reading the buffer proves nothing either way. What a bus master cannot hide
is **cycle stealing**: if the AC arbitrates for the VersaBUS, the 68000 stalls.

So: program MC6840 **timer 1** free-running, time an identical RAM-touching
loop with and without an outstanding transfer, compare.

Measured on the emulator, and the calibration is exact:

```
  T1 ticks for 2000 idle passes      5955  (FFFF -> E8BC)
  spread over 4 identical runs       1 tick
```

5955 ticks at E = 800 kHz is 7.4 ms; at 8 MHz that is 59,500 CPU cycles over
2000 iterations = **30 cycles each**, which is exactly
`move.w (a0)+,d2` (8) + `movea.l #imm,a0` (12) + `dbra` (10). **The timing path
is verified against the instruction timings**, and the resolution is 1 part in
6000 — a DMA stealing 0.1% of the bus would show.

**Safety**: CR1's reset bit holds **all three** timers and T3 is the RTOS
system tick, so this runs only on the `--reset` image.

Two PTM bugs the rehearsal caught, both of which would have failed on iron:

- **`CR1 = $00` selects the EXTERNAL clock** (bit 1 = 0). That is how the
  firmware leaves T1 — *"an external-input counter"* — and nothing drives the
  pin, so the counter never moved. `$02` is internal. The documented `CR3 =
  $C6` has the same bit set, which is the cross-check.
- **the PTM is on ODD bytes** (`$F70001`-`$F7000F`) because it hangs off D0-D7.
  A `move.w` there is an **address error**. Every PTM access must be
  `move.b`, and the 16-bit counter is two byte reads — MSB first, because
  reading the MSB latches the LSB.

---

## 6. Reporting the fault ADDRESS — a monitor change

A 68000 group-0 frame is 7 words and carries the **address that faulted** at
`(sp)+2`. The monitor read the SR and PC out of it and **discarded the
address**, so a bring-up fault reported *"bus error at PC X"* with no way to say
what X touched — which on this board is the one thing you want.

Added `MON_FADDR` (long) and `MON_SSW` (word) at `$0F898`/`$0F89C`, captured in
`grp0_entry`, cleared on the short-frame path and at cold init (a stale address
must not read as a live one), and printed both in the fault banner and by `i`:

```
  entered at PC=$00001006  SR=$2700  FAULT@$00001001  SSW=$0015
  grp0/nest/txfail   = $01/01/00  FAULT@$00001001  SSW=$0015
```

Verified by deliberately faulting: a `move.w` at an odd address reports the
odd address exactly, and `SSW=$0015` decodes as **bit 4 = read, FC 5 =
supervisor data**. Monitor grows 4060 → 4254 bytes, ~18 KB still free.

**SSW bits**: 4 = R/W (1 = read), 3 = I/N, 2-0 = function code (5 = supervisor
data, 6 = supervisor program).

---

## 7. An emulator divergence this work found and fixed

`M68K_EMULATE_ADDRESS_ERROR` was **OFF** in `emulator/musashi/m68kconf.h`, so
the emulator silently completed odd-address word accesses. That is why the
`move.w`-to-the-PTM bug above survived: it was caught by reasoning, not by the
rehearsal that was supposed to catch it.

Now ON, and **verified behaviour-neutral by clean builds both ways** — same
final PC `$F00FE6` and a **byte-identical 128 KB RAM image**. So the stock
firmware never performs an odd-address word access.

> **Caution that nearly cost the result**: the first comparison used
> `make` after editing a *header*, and make does not track header
> dependencies here — both "different" binaries were the same file, so the
> control was vacuous. `md5sum` the two binaries and require them to differ
> before believing any A/B on this emulator.

---

## 8. Bugs the emulator rehearsal caught in the probe itself

| | |
|---|---|
| **MOVE encoding** | the register went in bits **9-11** (a MOVE's DESTINATION) instead of **0-2** (its source), so every register but d0 assembled as d0. Symptoms: `polls=-48156`, and **a false finding that the AC data pair does not read back** — which contradicts the listing. Corrected, all three patterns latch exactly |
| **image detection** | six vectors all reading `$F0A840` matched an "address in ROM" range test → wrongly *"the RTOS booted"* |
| **`MON_GRP0` polarity** | `$FF`→`$0` is the **normal** TRAP #14 return; only `1` is a fault. Would have reported a bus error on every successful stub |
| **stale local** | the on-board fill removed the Python-side `page`, but the DMA check still compared against it → `NameError`, caught by the phase guard |
| **PTM clock / width** | see §5 |
| **missing `return`** | `probe_channels` never returned the decorator's value, so phase K always saw "no channel present" and skipped the contention test entirely — a silent skip, not an error |

The first is the instructive one: it produced a **plausible, quotable negative
result**. *Test on the emulator first* is not a formality — a hardware session
would have recorded that as a finding about the machine.

---

## 9. What a hardware run can and cannot settle

**Can**: which ROM image; the ROM checksum; the XLTR register block; which
channels are populated; whether the AC answers `$8004` and how fast; whether
the data pair latches; whether the `$400000` window pages; whether `$FF0214`
and `$FF0216` bit 4 behave as the width-mux reading requires; whether anything
steals bus cycles during a transfer.

**Cannot**: anything past the channel window. The path is
**XLTR → UNIV FMT → XP32 bus → AC**, and none of it is addressable by the SBC —
the firmware's own diagnostics draw the same line, never touching XP-32 EXEC,
ARITH or UNIV FMT. The EU↔AU link is a private 160-conductor ribbon on neither
bus.

So the probe bounds the AU from outside. **Reading the AU's microcode still
needs the WCS contents, and the WCS is RAM** — 32 × `AM2168` at 4K × 4 = 128
bits × 4K = 64 KB = exactly one bank = exactly the staging buffer. It does not
survive power-off, which is why there is an upload path at all.

---

## 10. Interrupts

A channel write can raise a BIM interrupt. On the `--panic` image the RTOS ISRs
are live and will run, changing firmware state underneath the probe. Phase J
detects which image is fitted; phase J2 points the six task vectors at
an RTE stub for the duration and restores them afterwards.

On the `--reset` image the RTOS never started, so there is nothing to disturb —
which is why that image is the right one for phases K and L.


---

## 11. Emulator baseline (what a clean rehearsal looks like)

```
  --reset image: all six vectors read $00F0A840 (cold_init fill)
  ROM XOR of all 32768 words         $0000
  channels with non-zero +$0E: 1, 2
  LATCH ECHOING, not an AC: all opcodes -> status $C004, 0 polls, +$0A handed back
  data pair $FF0048/$FF004A latches exactly -- real registers
  1 KB staging verified on-board, XOR $3000 as predicted
  address/count handshake completed both phases
  T1 ticks for 2000 idle passes      5954  (spread 1 over 4 runs)
  T1 ticks with a transfer outstanding 5954   -> no contention: +0 vs 1 spread
  all pages read $0000  (one address cannot separate the three explanations)
  $FF0216 bit 4 latches;  $FF0214 latches
  all six microword shapes -> same status
```

Read-only default: 18 s.  Full run with writes and AC: 7 s (the read-only path
spends its time on the over-the-wire ROM sweep, which stubs replace).

**Every one of these is the CORRECT emulator answer**, and four of them are the
ones to watch on hardware:

| emulator says | hardware would say, if the AC is live |
|---|---|
| LATCH ECHOING | status **varies by opcode**, non-zero poll count |
| no contention, +0 ticks | **positive** tick delta during a transfer |
| all pages read $0000 | **different** values per MODE2 page |
| all six shapes -> same status | status **differs** by microword shape |

## 12. Style

The script is terse on purpose: its output is hardware feedback, not an essay.
Rationale lives here.  Roughly 1250 lines, 190 lines of output on a full run.

---

## 13. A detector that reported EVERYTHING as a collision

The suite's guard #10 forbids naming a check-local accessor after a
module-level loop target, and this file's rule is to verify candidates against
**every** module-level name with `ast`. The obvious implementation is wrong:

```python
for n in tree.body:
    for x in ast.walk(n):          # <-- walks INTO function bodies
        ...collect Name targets
```

`ast.walk` descends into every `FunctionDef`, so it collects ~1300 names
including every local in the file, and reports **every** candidate as
colliding. That is the mirror of the usual failure here: not a detector that
misses, but one that flags everything — equally useless, and more likely to be
believed because "be careful" feels like the right answer.

The correct scan visits `tree.body` and descends into `if`/`for`/`try`/`with`
**but not into functions**. It finds 1263 module-level names, of which six of
my twelve candidates genuinely collided (`_sp`, `_m`, `_b`, `_n`, `_op`,
`_cfg`) — a real result the broken version could not have distinguished from
noise.

---

## 14. FAULT RECOVERY — tested, and it exposed a monitor bug that ends a session

Driving a deliberately faulting stub through the probe's own `Monitor` class:

```
  info before   : grp0=$FF nest=0 txfail=0
  ... run a stub whose first instruction is a move.w at an odd address ...
  info after    : grp0=$01 nest=0 txfail=0     <- fault correctly detected
  regs still work : True
  mem still works : True
  next stub       : MonitorError -- "?no resumable frame (cold entry, or
                                     bus/address error)"
```

The session **survives** — the prompt, `r` and `m` all keep working, so the
probe's phase guards do their job. But **every later stub fails**, because
`MON_GRP0` stays `1` and `cmd_go` refuses:

```
                cmpi.b  #$FF,MON_GRP0
                beq.w   .fresh          ; cold entry + address -> synthesise
                tst.b   MON_GRP0
                bne.w   .no_frame       ; group-0 -> REFUSED, even with an address
```

**That is wrong for the address form.** `g <addr>` is not a resume — it is a
*start*, and the `.fresh` path that already exists for cold entry does exactly
the right thing. Only a bare `g` needs a resumable short frame.

Consequence on hardware: **one bus error and no further stub runs until a power
cycle**, which for a bring-up tool is the worst possible failure mode — the
probe would report every remaining phase as broken and none of it would be about
the machine.

Fix applied: with an explicit address, branch to `.fresh` for **any**
non-resumable frame (`$FF` cold *or* `1` group-0); bare `g` keeps the strict
check. **Verified** — after a deliberate address error:

```
  grp0 after fault:          1
  NEXT STUB AFTER A FAULT -> 5a5a
  and another             -> beef
```

Monitor 4254 -> 4216 bytes (the fix removes an instruction).

### And a second, smaller one — fixed too

The probe's `info()` parsed `grp0`/`nest`/`txfail` but not the new `FAULT@` and
`SSW=` fields, so it reported `faddr: None` on a run where the monitor had them.
Now parsed, with a `Monitor.fault()` returning `(addr, r/w, fc)`, and **the
phase guard queries it after every phase** — so a probe that faults says where:

```
  [FAIL] BUS/ADDRESS ERROR at $00001001 (read, FC5)
```

Verified against a deliberate odd-address read: `$00001001 read FC5`.

### A hazard that is NOT a bug

A fault re-enters `monitor_common`, which calls `sio_init` — and that
**discards bytes in flight**. Feeding the monitor a script with `printf` loses
whatever was already sent when the fault hit. The probe is immune because
`cmd()` waits for a prompt before sending the next line, but any hand-driven
session should know it.

---

## 15. THE SERIAL PATH IS NOW TESTED — 9600 baud, end to end

Everything above ran through `EmulatorTransport`. **`SerialTransport` — the only
code path that matters on the bench — had never executed.**
`tools/pty_bridge.py` fixes that: it opens a PTY, runs the emulator behind it,
and **rate-limits the bridge to 10 bits per byte at 9600 baud**, so timeouts are
exercised at true wire speed.

```
  python3 tools/pty_bridge.py <rom> ./emulator/fps3k_sbc 200000000000   # prints /dev/pts/N
  python3 tools/fps3k_probe.py --port /dev/pts/N
```

**Result: all twelve phases, 7 findings, ZERO failures, 120.1 s** — findings
identical to the emulator-transport run. So a full hardware probe should take
**about two minutes**, not the six-plus the over-the-wire ROM sweep would have
cost before the stubs.

### Three bugs it found that the emulator path could not

| | |
|---|---|
| **phases K and L were NOT behind the phase guard** | they called `rep.section` directly, so a serial hiccup in the bus-contention phase **killed the whole run with a traceback**. Both now use `@phase` |
| **no link-loss handling** | once the port died every later phase failed with the same `SerialException`. The first `Input/output error` now sets `link_lost` and the rest report *"skipped: the link is gone"* -- so a dead cable cannot masquerade as twelve findings about the board |
| **the link diagnostic had been over-trimmed** | the terseness pass cut *"no monitor prompt"* down from the list of things to check. For **that** failure the detail is the entire value, so it is restored in full -- 9600 8-N-1, RX/TX orientation, ground, and the +/-12 V the chassis does not supply |

### And two harness traps, both mine

* **the PTY starts with `ECHO` and canonical mode on**, so the emulator's own
  banner is echoed back at it as if typed -- a feedback loop that emits help text
  and looks exactly like a probe bug. `tty.setraw()` on *both* ends before the
  emulator starts.
* **two probes on one PTY** gives *"device reports readiness to read but returned
  no data (device disconnected or multiple access on port?)"*. That string is the
  tell for a stray process, not a board fault -- worth recognising on the bench,
  where a forgotten `screen`/`minicom` session does the same thing.

---

## 16. LINE ENDINGS — the monitor accepts both, and that is the trap

`read_line` terminates on **CR (13) _or_ LF (10)**. So a `\r\n` ending ends the
line on the CR and then **the LF starts and immediately ends an empty one** —
and the monitor answers an empty command with another prompt.

**That extra prompt is never an error.** `_drain_to_prompt` returns on the stale
one, so from then on every `cmd()` reads the *previous* command's reply. The
probe carries on and reports wrong numbers as board state.

Reproduced against a control, with the flush disabled:

```
  baseline  : 00F00000: 00 00 00 00 00 F0 A8 26 00 00
  unfixed   : fps3k> m 00F00000 10          <- the stale prompt and the echo
```

`read_mem` parses that with `_DUMP` and gets **nothing**, silently.

**Fixes, both cheap:** `cmd()` calls `tr.flush_input()` before every write (
`reset_input_buffer()` on serial, queue drain on the emulator), and the echo
strip now does `txt.lstrip('\r\n')` so a leading ending cannot defeat it. The
probe itself has always sent a **bare CR** and still does.

Seven regression checks pin it, including the two `cmpi.b` in `read_line` that
make the hazard real — so if the monitor is ever changed to accept one
terminator only, the check that explains *why* the flush exists fails first.

**On the bench this matters more than on a PTY**: a terminal program set to send
CRLF, or an adapter with translation on, produces it on the first command.

## THE MONITOR GAINS THE I/F CARD'S OWN ACCESS WIDTHS — five tiers, 4216 -> 8760 bytes (2026-08-18)

The monitor's `m`/`w` are **byte** operations, and this project establishes that
the AP I/F and the XLTR are **16-bit-only blocks** — all 20 AP I/F registers are
reached by plain `move.w` (bar three `cmpi` on `$FF0000`), and the whole
`$FF0200`-`$FF025F` XLTR block likewise. So the two commands that exist could
not drive either device, and every word-sized access in `tools/fps3k_probe.py`
has to assemble a TRAP #14 stub into scratch RAM and `g` to it.

Five tiers close that, in **4544 bytes**, leaving **13,730** of the ROM tail free.

| tier | commands | what it removes |
|---|---|---|
| **1 width** | `mw` `ml` `ww` `wl` | the stub round-trip for every device access |
| **2 maps** | `x` `y` | 20 AP I/F + 34 XLTR/BIM registers in one command |
| **3 AC** | `c CH OP` | the `$F07F12` transaction primitive, by hand |
| **4 taps** | `s` `s-` `sl` `sc` `s+` | **channel ISR capture** — the tier that argues for ROM residency |
| **5 DMA** | `e` `p` `q` | bulk drain, chassis-window paging, ready poll |

### The design decisions are the record's, not convenience

**Byte commands are KEPT.** The MC6840 PTM (`$F70001`-`$F7000F`) and the µPD7201
SIO (`$F70011`-`$F70017`) are **odd-byte-only**, hanging off D0-D7, so a word
access to either is an address error. Both widths have to coexist; neither
replaces the other.

**Odd addresses are REFUSED, not faulted.** `M68K_EMULATE_ADDRESS_ERROR` is now
on, so `mw FF0201` would fault for real — and a fault report on this board reads
as *"the device did not answer"*, which is exactly the wrong diagnosis. It
prints `?odd address (word/long access would be an ADDRESS ERROR)` instead.

**The device maps WALK A ROM TABLE of established addresses, they do not sweep
the block.** An unanswered address here is a bus error that aborts the dump, and
the census has already settled which 20 of the AP I/F's 256 bytes exist. **The
tables are the census**: `$FF000A`, `$FF0010`, the four window `+$00` registers
and the whole of window 1 (`$FF0020`) are absent because the firmware's own
`(ch+1)<<5` arithmetic skips them by construction.

**`$FF0008` is deliberately NOT in the AP I/F map** — it is the bulk FIFO whose
**reads pop**, which is how the S-record error paths drain a rejected record
(`while ($FF0000 > 0) read (a0)`). A register map that pops a FIFO is a probe
that changes what it measures. `e` exists to read it on purpose.

**The AC teardown is UNCONDITIONAL and it SAVES AND RESTORES.** The firmware's
own teardown is one-way — `$FF021A` is **clear-only**, 50 `bclr` and 0 `bset` —
and the record's model obligation is that *a chassis that errors and ignores the
resulting `$269` leaves that channel's bit SET and its BIM masked at `$4F`
permanently*. A probe that did the same would strand the channel it was
diagnosing, so `c` stashes `(BIM CR)` and `$FF021A` on entry and restores both on
**every** exit — done, error and timeout alike — and says so.

### The latch discriminator, carried over from the probe

`tools/fps3k_probe.py` reports *"LATCH ECHOING, not an AC responding"* when every
opcode returns the same status in zero polls with the data pair echoing the
write. `c` carries the same test, and it fires in the emulator exactly as it
should:

```
fps3k> c 1 10
  DONE  status=$C004 polls=$00000000 data=$0000:0010
  NOTE: zero polls AND +$0A echoes the opcode -> this is a LATCH
        ECHOING, not an AC responding.
  (BIM CR and FF021A restored)
```

### Tier 4 is why this belongs in ROM

Everything else can be a transient stub poked into RAM and jumped to. **An
interrupt handler must still be there when the interrupt arrives.**

`s` installs four handlers at vectors `$45`-`$48` (`$114`-`$120`), each latching
`{channel, timestamp, +$0E status, +$08 hi, +$0A lo}` into a 64-entry ring at
`$0F900` and then **chaining to the vector it replaced**:

```asm
                move.l  MON_TAPTGT,-(sp)
                rts                     ; pops the target, leaving the
                                        ; exception frame below it for the
                                        ; original handler's own rte
```

`MON_TAPTGT` is one global slot, so the chain is **not re-entrant** — which is
safe here for a reason the firmware supplies: all four channel BIMs are
programmed to `$5F`, **level 7**, and a 68000 masks the level it is already
servicing. Two channel taps cannot nest. When the saved vector is
`monitor_entry` (cold_init's filler for all 256), it `rte`s instead.

### The timestamp is T3, and switching to it removed the only PTM write

The first version read **T1**, which needed `s+` to start it — and T1 is an
**external-input counter** (`CR1 = $00`, bit 1 clear) with nothing driving the
pin, so it reads a constant until reprogrammed. Reading **T3** instead is
strictly better:

* on the **panic image the RTOS has already programmed it** — latch `$27C7`,
  dual 8-bit, a 10.0000 ms tick at E = 800 kHz — so the tap needs **no PTM
  writes at all in the configuration that matters**;
* it is the counter the firmware's **own sub-tick clock** reads (TRAP #0 `$1C`
  at `$F00F96`), so the tap and the RTOS agree on what time is;
* `s+` remains for the `--reset` image, and now follows the firmware's own
  initialisation ordering (`$F0A294`-`$F0A2E4`): **assert the internal reset,
  load the latch, configure, release**. Its warning states the part that
  matters — **CR1 bit 0 is a CHIP-WIDE reset**, so starting T3 restarts T1 and
  T2 and replaces the RTOS tick.

### The timestamps VALIDATE THEMSELVES against a known period

Driving channel 1 with `FPS3K_XPIRQ=1`, whose raise loop is throttled to **one
per 200,000 CPU cycles**:

```
fps3k> sl
CH TSTMP STAT DHI :DLO
01 536F 0001 0000:0000
01 0558 0001 0000:0000
01 B786 0001 0000:0000
01 6974 0001 0000:0000
```

T3 counts **down**, so successive deltas are `$4E17`, `$4DD2` (across a wrap),
`$4E12`, `$4E14` — **19,922 to 19,991 counts, spread 0.35%**. At E = 800 kHz
that is **24.99 ms**, against the model's `200000 / 8 MHz` = **25.00 ms**.

> **An independently-known period, recovered from the tap's own readings through
> the E = CPU/10 relationship and the down-count direction, to within 0.05%.**
> That exercises the timestamp, the ring, the ordering and the E-clock figure in
> one measurement — and none of it was fitted.

### The chain path is exercised, not merely written

On the `--reset` image every vector is `monitor_entry`, so the first test took
the `.own` (`rte`) branch and never touched `MON_TAPTGT`. Poking a two-byte
`rte` stub and pointing the vector at it forces the real path:

```
ww 1000 4E73        ; an rte stub in RAM
wl 114 00001000     ; vector $45 -> the stub
ww FF0244 5F        ; BIM1 ch2: level 7, IRE set
ww FF024C 45        ; its vector number
s / q / sl / s- / ml 114 1
```

**64 interrupts captured and chained without a crash**, `wraps=$0001` on a
longer run (the ring is 64 deep and the head wrapped once), and `s-` restored
`$114` to `$00001000`. The ring accounting and the vector save/restore are both
verified rather than asserted.

### Two bugs found by testing, both mine

**`xdump` looped ~4 billion times on a zero count.** With `d2 = 0` the
items-per-line `min` gives 0, and `subq.l #1,d3` on 0 goes to −1 with `bne`
taking the branch. Guarded with `tst.l d2 / beq` at entry.

**`cmd_page` restored the WRONG MODE2** — it held the saved page in `d4` across
a call to `xdump`, which uses `d3`/`d4`/`d6` for its own line arithmetic. It
reported `MODE2 restored to $0004` on a page that had been `$0000`.

> **A restore that reports the wrong value is worse than no restore, because it
> is believed.** Saving on the stack instead is immune to any callee's register
> use, and it is the fix to prefer whenever the value is going to survive a
> `bsr`.

### What the emulator run establishes, and what it does not

```
fps3k> x
  ... C1 CMD $FF004E = $0001    C2 CMD $FF006E = $0001
      C3 CMD $FF008E = $0000    C4 CMD $FF00AE = $0000
```

**Channels 1 and 2 answer and 3 and 4 do not** — independently reproducing the
emulator's `FPS3K_CHANNELS=2` default, and reading the very ports the firmware's
own presence probe at `$F0A202` counts into `$105E`. On hardware that same
command answers the question the record flags against the index plate: whether
this chassis is populated as 1 AC or 2.

```
fps3k> e 4
FF0000 before drain = $0000
FF0000 after  drain = $0000
  -> count did NOT fall: port not popping, or counter not loaded
```

**That is the correct emulator answer, not a defect**: the model's bulk path has
no word counter behind `$FF0000`, and the record establishes the hardware one is
a **down-counter loaded from off-card** — six `74S169` up/down parts on the AP
I/F against three up-only, with the CPU never writing it. So `e` is a test the
emulator can only fail, which is exactly what makes it worth having on iron.

### Both images rebuilt, and the checksum still matters

`monitor.bin` 8760 bytes, `monitor_end = $F0CA5D`. Whole-image XOR **zero** for
both — `$C12D -> $4EAD` (reset+panic) and `$C12D -> $7A8B` (panic only) — which
is not cosmetic: **self-test phase `$300` verifies it and retries forever**, so
an image with a broken checksum never boots. Splits round-trip verified.

The panic image still boots the RTOS to **`final PC=F00FC2`**, the delay-list
expiry scanner, with 5 bus errors — the stock resting state.

---

## FINAL STATE (2026-08-19)

The entries above are chronological, so the sizes in them are the sizes at the
time each was written. This is where it ended.

`monitor.bin` is **10,842 bytes**, occupying `F0A826` to `F0D27F`. `F0D280` to
`F0FFFD` is still zero: **11,646 bytes**, with the checksum in the last word.
Both images XOR to zero — `$C12D -> $7094` for reset+panic and `$C12D -> $44B2`
for panic only — and the panic image still boots the RTOS to `final PC=F00FC2`.

Twenty-two command routines: `cmd_loop cmd_help cmd_about cmd_regs cmd_mem
cmd_err cmd_dump cmd_write cmd_go cmd_bp cmd_trace cmd_info cmd_load_srec
cmd_apif cmd_xltr cmd_ac cmd_tap cmd_bulk cmd_page cmd_ready cmd_sum cmd_fill`.

The build recipe reproduces every checked-in artefact byte for byte, verified
by running it into a scratch directory and comparing: `monitor.bin`,
`FPS3K_with_monitor.bin`, `FPS3K_panic_only.bin` and the splits all match.

### The probe was not rewritten to use any of it

`tools/fps3k_probe.py` still issues only `m`, `w`, `r`, `i`, `g`, `h` and `b`,
and still assembles a TRAP #14 stub for every word-sized access. It predates
the five tiers. It works, and several of its phases now do by stub what one
command does. `TESTS.md` section 2 carries the note.

### Where the documentation lives now

`monitor/MONITOR_MANUAL.pdf` is the user's guide — commands, wiring, what each
command touches in the chassis, and the cautions. `monitor/README.md` is the
build note. This file stays as it is: a log, not a reference.
