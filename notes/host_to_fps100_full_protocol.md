# How the host PDP-11 communicates with the FPS-100 — full source-derived protocol

A comprehensive synthesis of every host↔FPS-100 interaction recovered
from MACRO-11 + APAL source in `fps100_archive/fps100sw/`. Supersedes
`host_to_fps100_protocol.md` (which covered just the device-driver
layer); this doc adds the APEX runtime, math-library wrappers,
register-level layout, message-passing channels, and reset/init.

> **Note on PDP-11 model**: the FPS-100 was sold as a **UNIBUS** device
> (default CSR base `0o176000`, vector `0o170` — see `FPSMC.MAC`).
> The PDP-11/44, /70, /84 are UNIBUS — these the recovered driver
> directly supports. The **PDP-11/73 is Q-bus**; using FPS-100 with
> a /73 would need either a Q-bus↔UNIBUS bridge (DEC's `UBC11`,
> `BCV1B`, etc.) or a different FPS-100 variant that this archive
> does not document. The protocol below is the standard UNIBUS one;
> on a /73 the PDP-11-side software is unchanged but the bus
> mechanics have an extra translation step.

## The big picture — three software tiers + three hardware channels

```
┌──────────────────────────────────────────────────────────────┐
│   USER FORTRAN                                               │
│      CALL ZRFFT(buf, 1, 16384)                               │
└────────────────┬─────────────────────────────────────────────┘
                 │ standard FPS calling convention
                 ▼
┌──────────────────────────────────────────────────────────────┐
│   MATH-LIBRARY WRAPPER (per *HSR.MAC stub)                   │
│      copies args into SLIST                                  │
│      JSR PC, APEX                                            │
│      microcode binary in PARAM block                         │
└────────────────┬─────────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────────┐
│   APEX RUNTIME — 2 source files                              │
│      IAPEX.FTN (host-independent, 2158 lines)                │
│      DAPEX.MAC (host-dependent, RSX-11M, 1294 lines)         │
│      ── the big switch:                                      │
│         APASGN/APRLSE  attach/release device                 │
│         APRSET         reset hardware                        │
│         APRUN          start AP program                      │
│         RUNDMA         start DMA transfer                    │
│         WTRUN/WTDMA    wait for completion                   │
│         APIN/APOUT     poll an AP register                   │
│         SPLDGO         load S-Pad regs and start             │
│         SENDER         send 4-word msg via SWR/APIRT         │
└────────────────┬─────────────────────────────────────────────┘
                 │ QIO IO.WLB to device "AP:" (function 1=RUNDMA, 5=SUPER, 6=TERM)
                 │ direct UNIBUS pokes of S.CSR(R4)+offset for everything else
                 ▼
┌──────────────────────────────────────────────────────────────┐
│   RSX DEVICE DRIVER (DRIVER.MAC, 333 lines)                  │
│      $APTBL: { APCHK, APCAN, APTIMO, APPWF }                 │
│      RUNDMA: pokes LITES + HMA + CTRL.HDMAGO                 │
│      ISR:    classifies DMA-done / RUN-done / CTL5           │
│              into RSX event flags                            │
└────────────────┬─────────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────────┐
│   UNIBUS — 10 device registers at 0o176000+ (FPSMC.MAC)      │
│   3 logical channels:                                        │
│      ① DMA    — bulk data, AP is bus master                  │
│      ② CTL5   — programmed I/O via SWR/LITES + irq           │
│      ③ APIRT  — host→AP interrupt to wake AP for SENDER msgs │
└──────────────────────────────────────────────────────────────┘
```

## The complete UNIBUS register layout (FPS-100 device)

From `DAPEX.MAC` lines 119-130 (octal offsets from CSR base):

| Offset | Name | Width | Role |
|---:|---|---|---|
| **`000`** | `FMTH` | 16 | Format High Register — IEEE↔FPS float conversion |
| **`002`** | `FMTL` | 16 | Format Low Register |
| **`100`** | `WC`   | 16 | DMA Word Count |
| **`102`** | `HMA`  | 16 | Host Memory Address (low 16 bits of 18-bit Unibus addr) |
| **`104`** | `CTRL` | 16 | Control register (bits below) |
| **`106`** | `APMA` | 16 | AP Memory Address (for examine/deposit) |
| **`110`** | `SWR`  | 16 | Switch Register (host↔AP single-word channel) |
| **`112`** | `FN`   | 16 | Function Register (status + handshake) |
| **`114`** | `LITES`| 16 | Lights Register (AP↔host single-word, w/ page-select for DMA) |
| **`116`** | `ABRT` | 16 | Abort/Reset Register (= `RSTAP` in DRIVER.MAC) |

Default CSR base = `0o176000` (`APCSR0` in `FPSMC.MAC`). Default
interrupt vector = `0o170` (`APVEC0`). Configurable per SYSGEN.

### CTRL register bit assignments

| Bit | Mask (octal) | Name | Meaning |
|---:|---|---|---|
| 0 | `1` | `HDMAGO` / `HDMAST` | Host DMA Start (write 1 → DMA fires) |
| 5 | `40` | `WRTHOST` | Direction: 1 = AP-writes-to-host, 0 = host-writes-to-AP |
| 10 | `2000` | `IHCB5` / `ICTL05` | Enable CTL5 (programmed I/O) interrupt |
| 11 | `4000` | `IHWC` | Enable DMA-complete interrupt |
| 12 | `10000` | `IHHALT` / `IHALT` | Enable AP-halted interrupt |
| **14** | `40000` | **`APIRT`** | **Interrupt the AP from the host** (this is how SENDER wakes AP-side message handler) |

(Two naming styles appear because `DRIVER.MAC` and `DAPEX.MAC` were
written by different people. Functionally identical.)

### FN register

- Bit 15 (`100000` octal, = `APHALT`): AP HALT (1 = halted, 0 = running)
- Bit 14 (`40000` octal): SWR-data-valid handshake bit (AP sets when
  it has read SWR; host clears after reading; this is what `RDWAIT`
  spins on)
- Bit 12 (`20000` octal): LITES-data-valid handshake bit
- Bits 14-12 (`70000` mask, = `FNCLR`): all read-only-modified bits
  the host must mask out before write

### Event-flag mappings (RSX-11M)

| EVF (decimal) | Macro | When set by ISR |
|---:|---|---|
| 22 | `RUNEVF` | AP halted itself (microcode `APH;` instruction; `IHALT` bit) |
| 23 | `DMAEVF` | DMA transfer completed (`IHWC` bit) |
| 24 | `CB5EVF` | Programmed CTL5 interrupt (one word came back via SWR/LITES) |

### Two UCBs per FPS-100 unit

Per `DEVTAB.MAC`: each FPS-100 is configured as **two adjacent RSX
units** in the device-control-block (DCB):
- **Unit 0** (`AP0:`) — DMA channel
- **Unit 1** (`AP1:`) — CTL5 channel

This way a task can `QIO IO.WLB` to `AP0:` for DMA and
simultaneously have a separate IO outstanding on `AP1:` for CTL5
messages — the driver tracks both independently.

## The three communication channels

### Channel ① — DMA (bulk)

Direction: **host RAM ↔ AP memory** via Unibus DMA, AP is bus master.

Setup sequence (from `DRIVER.MAC RUNDMA` + `DAPEX.MAC RUNDMA`):

```
host:  [WC]    ← word count
       [LITES] ← (preserve page bits) | (high 2 bits of 18-bit phys addr << 14)
       [HMA]   ← low 16 bits of host phys addr
       [CTRL]  |= HDMAGO         ← FIRES DMA
       [CTRL]  |= IHWC           ← arm completion interrupt
```

Arrival: AP becomes bus master, transfers `WC` words between host
RAM at `(LITES_high2 << 16) | HMA` and the AP's currently-selected
memory area (HOST↔MD by default; HOST↔PS for microcode upload).
Direction bit (`WRTHOST` in `CTRL`) selects which direction.

Completion: AP raises Unibus interrupt at vector `0o170`. Driver
ISR sees `CTRL.HDMAST==0 && CTRL.IHWC==1`, sets event flag
`DMAEVF=23`, calls `$IODON`.

**Throughput**: at the AP-120B/FPS-100 era, ~1.6 Mword/s (16-bit
words at ~3 MHz Unibus DMA cycle).

### Channel ② — CTL5 (programmed I/O, AP→host)

The AP-side microcode executes an `INTEN;` instruction (CONTROL.INTEN
in I/O field, control opcode 2) which:
1. Sets a flip-flop visible to the host as `FN[12]` (data-valid)
2. Raises Unibus interrupt at vector `0o170`

Host ISR reads the value from `LITES`, copies it into the user's
array space at the AP-internal-array index that AP has helpfully
placed in `LITES[2..0]` (3-bit register identifier).

The whole point of this channel: **let microcode hand individual
result values back to the host without using the DMA channel**.
Used heavily by FPUT/FGET/FTST primitives in `HSVCM.S`/`HSVC.S`.

The **handshake** is bidirectional — to send another CTL5 word the
microcode first calls `WATLIT` (wait for host to read LITES), which
spins on `FN[13]` until the host clears it. This is asymmetric with
the SWR channel below (which has the host waiting on the AP).

### Channel ③ — APIRT (programmed interrupt, host→AP)

When the host wants to send a message TO the AP (rather than just
streaming data via DMA), it pokes `CTRL.APIRT = bit 14`. This raises
an interrupt-level signal on the AP, which causes the AP-side
microcode to vector into a message-handler routine.

The actual message words travel through the SWR register:

```
host:  RDWAIT                  ; spin until AP has read previous SWR
       [SWR] ← word_0            ; first word
       [CTRL] |= APIRT           ; pulse interrupt-AP bit
       [CTRL] &= ~APIRT          ; one-shot
       (loop for words 1..3, each preceded by RDWAIT)
```

AP-side, in `HSVC.S` / `HSVCM.S`:

```
WATSWR: LDSPI R1; DB=4000        ; mask for SWR-valid bit
        BR WATSL                   ; (shared with WATLIT)
WATSL:  LDDA; DB=APST3              ; addr of APSTAT3
        IN; DB=INBS                ; read APSTAT3
          LDSPI R0
        AND# R1,R0                 ; pick out the desired flag bit
        BNE WATSL                  ; if still set, wait
        RETURN
```

So host writes to SWR, AP polls the FN-bit, AP reads value, AP
clears flag, host sees flag clear and writes next word, repeat.

This is a **slow, polled, single-word channel** — typical for
control messages (parameter setup, microcode loader commands), not
for bulk data. The SENDER routine in `DAPEX.MAC` always sends
**4 words** per message.

## Reset and assignment — coming up cold

### `APRSET` — hardware reset

```
DAPEX.MAC APRSET:
   move APCSR, R3                     ; R3 = device base
   move 100000, FN(R3)                ; APHALT — halt the AP
   move 0, RSTAP(R3)                  ; reset AP (bus tells AP to clear state)
   ; now wait until AP comes back ready
```

Resets the AP to its initial state (microcode loaded but no user
state). PS (program memory) and MD (main data memory) keep their
contents because they're physical RAM on the AP card.

### `APASGN` — assign an FPS-100 to the calling task

Multi-AP system: there can be `A$$P11` (a SYSGEN constant) FPS-100s
on one PDP-11. `APASGN` does:

```
   if APNO == 0:                       ; "any AP"
       loop over UNIT 0..A$$P11-1:
           ALUN$ LUN to UNIT          ; assign LUN to this device
           ATT$ — try to attach
           if attached: success — set APCSR from CSRTBL[UNIT]; return UNIT+1
           else:        try next
       if none: return -2
   else:
       ALUN$ LUN to UNIT=APNO-1
       ATT$ either ATTW (wait) or ATT (no-wait)
       set APCSR from CSRTBL[APNO-1]
```

The `CSRTBL` global is built at SYSGEN time from `APCSR0`, `APCSR0+200`,
`APCSR0+400`, ... — one entry per installed FPS-100, 0o200-byte
spacing in I/O space. The default config is one FPS-100 at `0o176000`.

`APRLSE` is the corresponding cleanup: detach LUN, mark APCSR=0.

## Calling pattern from a math library

Tracing `CALL ZRFFT(buf, 1, 16384)` end-to-end:

1. Fortran runtime resolves `ZRFFT` via the linker against
   `SIGLIB` — it's a label in `*HSR.MAC` somewhere. Wait — that's
   for FPS-5000 XPMLIB. For FPS-100 the equivalent is `RFFT`/`CFFT`
   in `SIGHSR.MAC`. Same call shape.
2. The `RFFT` stub (per pattern in `AMLHSR.MAC`):

   ```
   RFFT:   MOV (%5)+, %0           ; arg count from caller's stack
           MOV #SLIST, %1
   LOOP:   MOV @(%5)+, (%1)+      ; copy each arg ptr → SLIST
           DEC %0
           BNE LOOP
           MOV #PARAM, %5
           JSR %7, APEX            ; call into the runtime
           RTS %7
   PARAM:  4                        ; arg count
           CODE                     ; ↓ pointer to embedded microcode
           START                    ; entry uPC
           SLIST                    ; pointer to SPAD-load values
           NSPADS                   ; how many SPADs to load
   ```
3. `APEX` (in `IAPEX.FTN`):
   - calls `APASGN(0, 0, status)` if not yet assigned to this task
   - calls `APXSET` (clear AP state) if microcode bank changed
   - calls `LOADPS(CODE, len)` — DMA-uploads microcode into PS via
     `RUNDMA` with `WRTHOST=0`
   - calls `SPLDGO(SLIST, NSPADS, START)` — loads N S-Pad regs via
     SENDER messages, then bumps PC to START and clears APHALT
   - calls `APWAIT` — blocks on `RUNEVF` event flag until AP halts
   - calls `APCHK`/`APSTAT` — read back error codes, return to caller
4. While the AP is running:
   - It accesses MD (main data) freely
   - It can send progress / result words via CTL5 (each one wakes
     the host's CT5 ISR which copies the value into the user's
     output array)
   - When done it executes `APH;` microcode (sets `FN.APHALT`),
     causing a host RUN-complete interrupt → `RUNEVF=22` set →
     `APWAIT` returns

## Summary table — host ↔ AP traffic types

| Direction | Channel | Latency | Throughput | Used for |
|---|---|---|---|---|
| host→AP | DMA | ~1µs setup | ~1.6 MW/s | bulk data, microcode upload, parameter blocks |
| host→AP | APIRT (CTRL bit 14) + SWR | ~5µs/word | ~200 KW/s | SENDER 4-word control messages, S-Pad loads |
| AP→host | DMA | same | same | bulk results |
| AP→host | CTL5 + LITES (programmed irq) | ~5µs/word | ~200 KW/s | per-result values, FGET/FPUT/FTST |
| AP→host | RUNEVF (RSX event) | irq latency | event-driven | "AP halted itself" — microcode is done |
| AP→host | DMAEVF (RSX event) | irq latency | event-driven | "DMA completed" |

## What this means for the FPS-3000 / XP-32 work

The XP-32's panel-command interface (`xp32_eu_command_protocol.md`) is
a **direct evolution of this**:
- The 6 UNIBUS registers became XLTR registers at `0xFF02xx`
- Function-code dispatch (1=RUNDMA, 5=SUPER, 6=TERM) became
  panel-command codes (`0x258..0x27D`)
- 4-word SENDER messages became 3-register transactions (data-hi,
  data-lo, trigger 0x8004/0x8005)
- RUNEVF/DMAEVF/CB5EVF event flags carried over conceptually as
  status-word bits 13/14/15

So the entire FPS-3000 SBC firmware is implementing **the FPS-100
host interface, on the SBC side instead of the PDP-11 side, using
VersaBUS instead of UNIBUS**. Bomem's HPVP (when its disks surface)
will be FPS-100-protocol code calling into this same APEX runtime,
just talking to the XP-32 instead of the AP-120B.

## Source files cross-reference

| File | Lines | Role |
|---|---:|---|
| `DRIVER.MAC` | 333 | RSX-11M kernel-mode device driver (`APDRV`) |
| `DEVTAB.MAC` | 137 | DCB/UCB/SCB definitions for `AP0:`/`AP1:` |
| `FPSMC.MAC` | 4 | SYSGEN: APCSR0=0o176000, APVEC0=0o170 |
| `DAPEX.MAC` | 1294 | Host-Dependent APEX (RSX-11M) — APASGN/RUNDMA/SPLDGO/SENDER/etc. |
| `FDAPEX.FTN` | 1043 | Host-Dependent APEX (RT-11) — same protocol, RT-11 syscalls |
| `IAPEX.FTN` | 2158 | Host-Independent APEX — APRUN/APWAIT/APCHK/APPUT/APGET/APSTAT |
| `HSVC.S` | — | AP-side host-comms (MTS supervisor variant) |
| `HSVCM.S` | — | AP-side host-comms (RTS supervisor variant) |
| `KERNEL.S/.B` | — | AP-side scheduler (EXTASK/EMPTY/CHKPT/IDLE) |
| `IOQUE.S/.B` | — | AP-side I/O queue |
| `*HSR.MAC` (×7) | ~90 KB | host-side math-library wrappers + AP-side microcode |
| `DRV100.CMD` | 127 | install command file for the AP driver |

Putting it all together: ~10,000 lines of recovered MACRO-11 +
APAL source covering every layer from user `CALL ZRFFT(...)` down
to a Unibus DMA cycle. The protocol is fully documented; only the
Bomem-specific microcode payloads (HPVP) are missing.
