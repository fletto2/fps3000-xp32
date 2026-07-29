# FPS-3000 VersaBUS Card Disassembly & Emulator — Gap Analysis

Analysis date: 2026-07-29. Based on reading all emulator source, all
consolidated asm, all refs_extracted, notes, ds/ audit files, and
CLAUDE.md.

---

## 1. DISASSEMBLY GAPS (fps3k.asm / fps3k_custom.asm)

### 1.1 Coverage ceiling: 49.6% of 48 KB decoded

6,725 instructions decoded out of 47,992 application bytes.
Remaining 50.4% is mixed: data tables (TCB definitions, dispatch tables,
pointer tables, error-mask tables) plus unreached code branches. Every
XP task body (TCBXP1I–XP4I) executes ~45 of its ~2,560 bytes; the rest
is unreachable in the emulator because no chassis model drives the
command protocol to advance past the initial `trap #1 $13` block.

**What's undecoded:**
- Data tables: TCBDefinitionTable contents (6 entries × ~330B at
  F0A57E), PanelStatusDispatchTable entries beyond the 4 handler
  addresses, PanelErrorMaskTable, ChannelConfigOffsetTable, the
  per-channel data-pointer table at $1080.
- Unreached code paths: bulk of PanelSendAndWait, the transfer-setup
  responders (F04CF2, F04D20, F04D4E, etc.), the S-record drain loop, all
  four XP task ISRs past their prologue, the TCBRDHC state machine body.
- The eight byte-identical panel-command issuer copies (F04500, F05688,
  F05E56, F068A8, F072C0, F07CC0, F086C0, F0A57E) are decoded but their
  individual roles (which task uses which copy) are not verified.

### 1.2 Panel status dispatch table not mapped to panel commands

The 42-entry dispatch table at F05BA4 is fully decoded as a data
structure but the mapping from panel command → response code → table
index → handler is unknown. Four handlers (POLL, D1_SEND, BLK_XFR,
D2_FIN) are identified but which code reaches which is not traced.
The table is never exercised in the emulator (the spinning `bra .` is
never escaped via this path; the panel-status responder F04930 is
blocked by its level-6 priority).

### 1.3 TCBDefinitionTable (F0A57E) not extracted

6 TCB entries of ~330 bytes each, containing task priorities, ASQ names
("RDHC", "HIO1", "AXP1"/"HXP1", etc.), entry-point addresses, initial
stack pointers, and extended RMS68K fields. These are the authoritative
task boundaries (used to banner the regions in fps3k.asm) but their
per-field contents are not extracted. The TDTI scanner uses them at boot
to TaskCreate each TCB; understanding their layout would confirm what
MC annotations hypothesize about priority ordering and inter-task queues.

### 1.4 TCBRDHC mode-state machine uncharacterized

The MC pass identified a "mode-state machine with 4+ states", with
state tracked at $E86 and channel-0x10 special-cased. The states and
their transitions are not mapped. Panel command 0x281 (HOST_REQUEST) and
0x282 (HOST_NULL) are known to arm the host-byte path but when TCBRDHC
enters each state relative to the command stream is unknown.

### 1.5 Per-channel code divergence in TCBXP2I/XP3I shared region

TCBXP2I and TCBXP3I share the same code region (F06914-F07CFF, ~5 KB),
with identical prologues. TCBXP1I (F07D00) and TCBXP4I (F05F00) are
separate. What actually differs per-channel in the shared body — the
condition that causes a divergent branch based on the channel number —
is not identified. Hypothesis: XP3I/XP2I may be "identical secondary
channels" vs "primary" (XP1I) and "special" (XP4I, error recovery), but
this is pure speculation.

### 1.6 RAM global variable map incomplete

Known globals (`fps3k.asm` names 66 RAM operands and 584 I/O operands
with corrected symbols) but the complete set of fixed-address RAM
references is not exhaustively enumerated:

| Address | Symbol | Width | Meaning | Status |
|---|---|---|---|---|
| $0E58 | `g_srec_addr` | long | S-record destination pointer | known |
| $0E60 | — | long | channel number (1-4) | known |
| $0E64 | `g_panel_expected` | word | transfer word count | known |
| $0E6E | — | word | panel command stash (shared global) | known |
| $0E74 | — | word | opcode latch | known |
| $0E86 | `g_channel_mode` | byte | mode-register cache | known |
| $0E87 | — | byte | flags: b5=32-bit arg, b6=addr-select, b7=error | known |
| $101E | — | word | address table entry 1 | known |
| $1020 | — | word | address table entry 2 | known |
| $105E | `g_ac_count` | word | channel presence count (CPU-written) | known |
| $1066 | — | word | ISR snapshot of channel command port | inferred |
| $1080 | — | — | per-channel data-pointer table (MC finding) | identified, not decoded |
| $10A0 | — | word[4] | per-channel init array | known |
| $10AA | — | word | chassis-DMA'd dispatch value | known as "external", not decoded |

Many more short-displacement references through `$8(a5)` etc. are
unresolved because the base register's value at each site is not known.

### 1.7 S-record finalization path (F05256) partially traced

The high-level flow (S-record → staging buffer → panel command sequence
→ XLTR DMA → WCS) is known. But the exact XLTR register values at each
step (MODE0/MODE1/MODE2/COUNTER writes) are not extracted for each
operation type (XPSEL vs XPRUN vs XPDMAR). The `FPS3K_SEQ` scripting
verified the staging path but the per-channel differences in the final
WCS write sequence are untraced.

### 1.8 Self-test phase inventory incomplete

~15 phases known (0x700–0x1A00) from emulator model and ROM chsel writes
but:
- Phase numbering: are these through 0x1A00 only, or are there later phases?
- Phase 0x900 (PTM test) exercised but internal timing not decoded
- Phase 0x1000–0x1A00 (PanelBusDiagnostic) is 1,876 bytes and well-modeled
  but the per-stage sub-tests inside it are not individually documented
- The secondary "ROMChecksum_etc" at F098EE (792 bytes) is not analyzed

### 1.9 Missing symbolic resolution for AP I/F channel-window operands

`fps3k.asm` has the correct symbolic names (APIF_CHn_DATA_HI,
APIF_CHn_DATA_LO, APIF_CHn_CMD) but these are only substituted for
3-digit displacements ≥ $200 and absolute $FFxxxx forms. Short
displacements like `$8(a5)` through a channel-window base are
unresolved because the base register (a5) holds the window base at
runtime and the static view can't distinguish channel-1 from channel-2
indirection.

### 1.10 Panel command Am29116 decode is syntactic, not semantic

All 21 codes 0x258–0x27D decode as valid Am29116 SUBRC instructions
(Groups A and B). But whether the Am29116 actually executes them or
treats them as dispatch indices is unknown. The functional grouping
(CH1-specific vs config vs init-step vs error) crosses the Am29116
instruction boundary (0x25F/0x260), suggesting the dispatch-index
interpretation is more likely — but this is unverified.

---

## 2. EMULATOR GAPS

### 2.1 No chassis bus-master model

The real chassis DMAs into SBC RAM as a VersaBUS master. The emulator
has no DMA engine. Values known to be chassis-provided ($10AA, $105E
in older docs — $105E is now known to be CPU-written) are injected
via environment variables (FPS3K_DMA10AA, FPS3K_POKE). Without a
bus-master model:
- `$10AA` is never set without manual injection
- The TCBIO1I ISR dispatch that reads `$10AA` at F05E12 is unreachable
- Any chassis memory write to SBC RAM is invisible

### 2.2 No XP-32 arithmetic channel model

The emulator runs only the M68KVM02 SBC. No XP-32 AC is emulated:
- No Am29116 EU instruction execution
- No AU WCS (4K × 128-bit writable control store)
- No floating-point pipeline (2 adders + 1 multiplier)
- No data-pad registers (DPX/DPY)
- No S-pad registers
- No memory controller (MEM CTL)
- No shared common memory (SCM)

Panel commands that target the AC (XPSEL, XPRUN, XPWAIT, XPSTAT, XPDMAR)
are acked by the chassis stub but produce no AC-side effect.

### 2.3 TCBIO1I host byte path deadlocks at level 7 (emulator)

The firmware programs the host channel (BIM2 ch2) at level 7 and the
panel-status responder (BIM0 ch0) at level 6. When TCBIO1I writes
PCMD_HOST_REQUEST (0x281) and spins in `bra .`, the level-6 responder
F04930 never preempts the level-7 ISR — so the spin never escapes.
The emulator confirms this: F04930 executes **zero** times during
the spin (vs 18,135 spin iterations).

**Caveat:** This is confirmed in the EMULATOR. On real hardware, the
IRQ-pin wiring might deliver the host interrupt at a lower level,
or the chassis might respond via a non-interrupt mechanism (e.g.,
direct bus cycle modifying the saved PC). The $5F written to $FF0254
encodes level 7 but the actual electrical level is unverified
(Check 2 in the trace worksheet).

The workaround (FPS3K_HOSTLVL=5) bypasses the BIM entirely and
routes the host interrupt through a level-5 autovector — which is
wrong for the real hardware but necessary to exercise the path in
emulation.

### 2.4 host_sim sends only one byte before stalling

Because of the deadlock above, the SBC never consumes the byte that
host_sim queues. The emulator's `-host-srec` path sends one byte and
stops. The monitor's `L` command bypasses this (it writes directly to
RAM addresses without using the BIM/ISR path).

### 2.5 No UNIV FMT card model

The FMT card (612-4804-003-E) sits between XLTR and XP-32 bus. Its
documented role is "32 BIT IEEE" format conversion but:
- Whether it does 16↔32-bit width conversion is unknown
- Whether it handles DEC F-floating ↔ IEEE-754 is unknown
- Whether it participates in WCS write-port fan-out is unknown
- The emulator has no FMT model at all

### 2.6 No AP I/F counterpart card model (host side)

The AP I/F card (612-4448-401-F) is a dual-ported interface: the SBC
sees one side ($FF0000-$FF00FF), the host sees another. The host side
has its own register set (HMA, WC, CTRL, FN, LITES, RSTAP per FPS-100
DRIVER.MAC) that translates into SBC-side register values. The emulator
has host_sim injecting directly into SBC-side registers — there is no
counterpart-card state, no host-side register translation, and no
host-side bus model.

### 2.7 MC6840 PTM model is simplified

- **Prescaler**: hard-coded ÷8, not per-datasheet ÷1, ÷8, ÷64, ÷1024
  per CR bits 3-5
- **No external clock input**: timers count on every CPU cycle
- **No gate inputs**: G1/G2/G3 pins not modeled
- **No output pulses**: Tn outputs not connected to anything
- **No continuous vs single-shot mode distinction**: counter always
  reloads from latch (continuous mode)

Despite these simplifications the PTM model is sufficient for the
phase-0x900 self-test, which only checks that a timer expires and its
IRQ flag sets.

### 2.8 No DRAM parity model

The real M68KVM02 has strap-selectable byte parity. Reading never-written
DRAM can raise BERR if the parity strap is enabled. The emulator:
- Zero-fills all RAM at startup
- Has no parity bit tracking
- Has no parity-error BERR generation
- Models `CLR` as a write-only operation (real 68000 reads first)

`FPS3K_UNINIT` tracking confirmed the firmware never reads a byte it
has not written — but that is a finding about this specific ROM, not a
guarantee for patched images. The monitor's `cold_init` pre-writes its
workspace specifically to avoid uninitialized-read BERR.

### 2.9 No board-strap model

The M68KVM02 has user-configurable straps for:
- Baud rate (16 discrete rates from BRG dividers)
- Parity enable/disable
- ROM/RAM size
- Bus timeout duration
- Interrupt priority encoding

None are modeled. The emulator assumes a single fixed configuration.

### 2.10 No VersaBUS arbitration

The real chassis has bus request/grant, bus-busy, and bus-clear lines.
Multiple bus masters (SBC, chassis DMA engine) contend for the bus.
The emulator:
- Always gives the CPU the bus
- Has no bus-request mechanism from the chassis side
- Has no bus-hold or bus-grant states
- Chassis DMA is modelled as "delay + inject" rather than bus takeover

### 2.11 Self-test suite passes via model hacks, not accurate emulation

Critical self-test behaviors depend on specific model choices:
- **Bit 5 of F70019**: modeled as checkpoint counter (vmod_d0_writes ≥ 2)
  — if modeled as a direct mirror of VMOD bit 6, the firmware would
  always skip the self-test suite (F08732).
- **MODE1 bit 12 gate**: without this, the model arms panel responses
  during register-walk self-tests and corrupts MODE0, failing F09598.
- **MC6840 single internal reset** (CR1 bit 0 holding all timers): without
  this, T2 and T3 free-run and re-assert IRQ before the handler clears it.
- **M68K_EMULATE_TRACE on**: without this, the monitor's `t` command
  silently fails (trace exception never fires).

These are correct behavior choices but they highlight how much of the
boot path depends on getting the hardware model right.

### 2.12 Only 19% of FPS application code executes

Per CLAUDE.md's coverage reality check: self-test 52%, RTOS 41%,
TCBIO1I 30%, RDHC 8%, XP tasks 4-6%. The remaining 81% is unreachable
because:
- Every task blocks on `trap #1 $13` waiting for a chassis event
- No chassis model generates those events
- The panel-command protocol is scripted via FPS3K_SEQ but only for
  the staging path (5 codes); the other ~24 panel codes are never
  issued or responded to
- The host-byte protocol deadlocks at level 7 (see 2.3)

### 2.13 No partial-word XLTR access modelling

The firmware accesses XLTR registers as 16-bit words exclusively. But
what happens on a byte access is not modeled — the real card might
respond on one byte lane or bus-error. The XLTR raw backing store
handles 16-bit accesses only.

### 2.14 AP I/F byte/long write splitting is incomplete

`versabus_write` at line 1131-1136 handles 16-bit APIF writes but
byte/long writes are commented "split" with no implementation. The
firmware uses only 16-bit accesses so this has never been hit, but
it means the emulator is incomplete for non-firmware code (e.g. the
monitor).

### 2.15 Missing AP I/F register zones

- **$FF0100-$FF01FF**: 256-byte gap between AP I/F and XLTR blocks.
  Unaccounted for in the memory map and unmodeled. Could contain
  undocumented AP I/F or XLTR registers.
- **$FF004A (and $6A, $8A, $AA)**: channel status words at Data_A+2.
  Modeling is ad-hoc (apif_inj_status injected by host_sim) rather
  than derived from hardware behavior.

### 2.16 FPS3K_DATAIN is a debug hook, not a chassis model

The bulk data port at $FF0008 returns an incrementing pattern from
`FPS3K_DATAIN` or S-records from `FPS3K_SREC`. These are diagnostic
hooks, not a chassis model. A real chassis would feed data from the
AP I/F's host-side FIFO into this port byte by byte as the SBC polls.

### 2.17 Emulator bug: `-host-srec` option hidden from usage()

`fps3k_sbc.c:usage()` does not list `-host-srec`. Users cannot discover
it without reading the source.

---

## 3. CROSS-CUTTING GAPS (affect both disassembly and emulator)

### 3.1 Panel command → response code → dispatch index mapping

Neither the disassembly nor the emulator knows which panel command
produces which response code. The chassis returns a 6-bit code in
XLTR_MODE0 bits 0-4; the firmware dispatches on it via
PanelStatusDispatchTable. The mapping chain is:

```
panel command (0x258-0x27D)
  → writes to APIF_CMD_ARG_LO + APIF_CMD_STATUS=0x8004
  → chassis processes command
  → chassis returns response code in XLTR_MODE0 plus BIM0 ch0 interrupt
  → firmware handler F04930 reads code
  → dispatches via PanelStatusDispatchTable
  → handler (POLL/D1_SEND/BLK_XFR/D2_FIN)
```

The chassis is a black box at this level. Without a bus trace or
chassis schematic, the code-to-response mapping is unobservable.

### 3.2 The `$10AA` delivery mechanism

`$10AA` is read by TCBIO1I's ISR at F05E12 to decide which
dispatch arm to take. No executed code in the ROM writes a nonzero
value there — the write watchpoint catches only bulk-zero writes from
F0A1D2 and F0A33C. The chassis must deliver it as a bus master, but
when and with what value is unknown. Without it, the host-byte path
can never indicate "data-class payload" to the ISR.

### 3.3 Host interrupt level is untested on hardware

The BIM programs CR $FF0254 = $5F = level 7. The panel-command
responder BIM0 ch0 is level 6. If the IRQ-pin wiring on the board
actually delivers the host interrupt at level 7, the level-6 responder
can never preempt the host ISR, and the host-byte path is permanently
deadlocked in `bra .`. If the wiring routes it at level 5 (as suggested
by earlier autovector docs), the responder works. This is **Check 2**
in the trace worksheet — unresolvable without a board-level measurement.

### 3.4 BIM daisy-chain ordering is unknown

Between BIM chips, the IACKIN/IACKOUT daisy chain determines priority.
The emulator scans BIM2 first (plausible for a chassis where the last
chip is closest to the CPU). The real ordering is check **Check 3**.

### 3.5 No emulation of what the chassis actually sends as responses

The emulator always returns `$14` (D2_FIN) as the panel response code,
or scripted codes via FPS3K_SEQ. The full response-code repertoire
(0..$14) and what conditions trigger each code is known from the dispatch
table but the chassis-side logic that generates them is a black box.

### 3.6 UNIV FMT / XLTR / AP I/F schematic-level understanding

All register-level understanding is reverse-engineered from firmware
behavior (self-test pass patterns). No schematic or netlist exists for
any of these cards. Every bit assignment in versabus.c is "verified
against phase X" — i.e., this value makes the test pass — not derived
from a datasheet.

---

## 4. ACTIONABLE NEXT STEPS

### Doable now (no new hardware access needed):

1. **Extract TCBDefinitionTable fields** — read ROM bytes F0A57E-F0B17E,
   parse RMS68K TCB structure to get task priorities, entry points,
   ASQ names, initial SP. ~1 hour of hex reading.

2. **Build complete RAM global variable map** — scan all `$XXXX.l`
   absolute references in 0x0000-0x2000 across fps3k.asm and produce
   a complete address→symbol table. Automatable with a script.

3. **Map PanelSendAndWait state machine** — static trace of which code
   paths write which panel commands to $FF000E, and what d2/a1/a2
   values are loaded before each. Requires careful asm reading.

4. **Extract MODE0/MODE1/MODE2/COUNTER write sequences** — search for
   all writes to XLTR_MODE0/1/2/COUNTER, group by context (channel
   init, transfer setup, DMA arm, abort).

5. **Trace the S-record finalization sequence** — starting from
   SRecordFinalize_andHelpers (F05256), follow the panel command
   writes to identify the exact XPSEL → XPRUN → XPDMAR sequence.

6. **Resolve TCBRDHC state machine states** — trace the F04752 check
   ($E86 == 8) and the surrounding code to identify the 4+ states
   and their transitions.

7. **Analyze the 256-byte gap at $FF0100-$FF01FF** — check if the
   firmware ever reads or writes addresses in this range across a
   full static sweep of fps3k.asm.

8. **Fix -host-srec usage() visibility** — add the option to the help
   text; it's a one-line fix.

### Needs hardware or bus trace:

9. **BIM daisy-chain ordering** — measure IACKIN/IACKOUT on the XLTR
   card to resolve **Check 3**.

10. **Host interrupt level** — scope the IRQ pin from the host BIM
    channel to the CPU to resolve **Check 2** (level 7 vs level 5).

11. **$10AA bus-master write** — logic-analyze the VersaBUS during
    a host transfer to capture the chassis writing $10AA. This would
    give the value, the timing, and the triggering condition.

12. **XP-32 bus trace** — capture WCS write cycles to confirm the
    128-bit microinstruction layout and the WCS write-port wiring.

13. **EU PROM dump** — read the bipolar PROMs on the EXEC card to
    recover the Am29116 instruction stream and the 80-bit microcode.

### Needs chassis model development:

14. **Implement a chassis bus-master DMA engine** — the most impactful
    single addition. Would allow the chassis to write $10AA into RAM
    (triggering the TCBIO1I dispatch), deliver panel response codes
    into MODE0 (breaking the `bra .` spin), and stream bytes into the
    staging buffer.

15. **Build a chassis command processor** — a state machine that
    interprets the panel commands the SBC writes and produces the
    expected response codes, closing the loop on the panel protocol.

16. **Model the UNIV FMT card** — at minimum, enough to track the
    format-conversion path between the 16-bit VersaBUS and 32-bit
    XP-32 bus for the WCS write sequence.

---

## 5. SEVERITY ASSESSMENT

| Gap | Severity | Impact |
|---|---|---|
| No chassis DMA model (2.1) | **CRITICAL** | $10AA unreachable, host-byte path dead |
| TCBIO1I host path deadlocks (2.3) | **CRITICAL** | `-host-srec` stalls after 1 byte |
| Panel command → response mapping unknown (3.1) | **CRITICAL** | Can't drive panel protocol beyond SEQ hook |
| No XP-32 AC model (2.2) | **HIGH** | No microcode execution, no pipeline effects |
| Only 19% code executes (2.12) | **HIGH** | Most firmware behavior is static-only |
| Mode-state machine uncharacterized (1.4) | **HIGH** | TCBRDHC body is 8% covered |
| $10AA delivery mechanism unknown (3.2) | **HIGH** | TCBIO1I dispatch arm unknown |
| Self-test phase inventory incomplete (1.8) | **MEDIUM** | Affects hardware verification |
| No AP I/F counterpart model (2.6) | **MEDIUM** | Host side of protocol is unsimulated |
| No UNIV FMT model (2.5) | **MEDIUM** | WCS write-path format unknown |
| TCBDefinitionTable not extracted (1.3) | **LOW** | Useful but not blocking |
| PTM model simplified (2.7) | **LOW** | Adequate for self-test pass |
| No DRAM parity (2.8) | **LOW** | Firmware never reads uninitialized RAM |
