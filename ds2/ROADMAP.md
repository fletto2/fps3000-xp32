# Closing the Gaps — Impact/Priority Roadmap

What can be done, in what order, to close the most impactful gaps.
Separates "can do now" from "needs hardware access."

---

## TIER 1: Could Close Now (no hardware needed, code/reverse-engineering only)

### T1.1 Build chassis command processor (closes gaps 1, 2, 11)

**What to build:** A state machine in `versabus.c` that interprets panel
commands the SBC writes and responds with the expected status codes.
This is the single most impactful missing piece — it unblocks the
TCBRDHC main loop, the XP task bodies, the TCBIO1I host path, and the
S-record finalization path.

**Input:** Panel command written to $FF000E; $FF0000=0x8004 trigger.
**Output:** Response code in MODE0 bits 0-4; BIM0 ch0 interrupt.

**What we need to know first** (blockers):
- The panel command → response code mapping (unknown without bus trace).
  Workaround: treat response codes as dispatch table indices and
  implement a function-level emulation (each panel command maps to one
  of the 4 handlers: POLL/D1_SEND/BLK_XFR/D2_FIN), with D2_FIN (0x14)
  as the default completion code.

**Impact:** Unlocks ~60% of unexecuted FPS application code.

### T1.2 Model chassis DMA into SBC RAM (closes gaps 3, 4, 7)

**What to build:** A bus-master engine that posts longwords into SBC
RAM at chassis-defined addresses, triggered by panel command completion.

**Key target:** Write `$00000002` to `$10AA-$10AD` when a host transfer
completes. This triggers the TCBIO1I ISR's class-field dispatch
(`$10AA=2 → reply arm at F05E40`).

**Impact:** Unlocks the TCBIO1I host-byte reply path and the mailbox
handshake.

### T1.3 Decode the TCBRDHC mode-state machine (closes gap 5)

**What to do:** Static trace from F04752 (the `cmpi.w #8,$E86` gate)
through the dispatch branches. Identify:
- State 0: idle/waiting (the `bra F04736` spin)
- State 8: S-record upload active (gated on $E86 == 8)
- State 0x13: channel config dispatch (gated on $E86 == 0x13)
- State 0x14: channel finalize (gated on $E86 == 0x14)

**Impact:** Understanding the state transitions enables building the
chassis command processor (T1.1) with correct state-dependent responses.

### T1.4 Extract TCBDefinitionTable fields (closes gap 12)

**What to do:** Read ROM bytes F0A600-F0B17E (6 × ~330B entries).
Parse RMS68K TCB structure:
- Offset +$00: TCB link pointer
- Offset +$04: Task priority (byte)
- Offset +$10: Task name (8 ASCII bytes)
- Offset +$1C: Initial PC
- Offset +$20: Initial SP
- Offset +$6C: Entry point address
- Offset +$160: !TST tag

**Impact:** Confirms task priorities, entry points, and ASQ names.
Low effort, high confidence.

### T1.5 Trace S-record finalization sequence (closes gap SI-7)

**What to do:** Starting from SRecordFinalize_andHelpers (F05256),
follow the panel command writes to extract the exact register sequence:
1. Select channel (CHANNEL_SELECT write)
2. Set WCS address (DATA_LO/DATA_HI writes)
3. Set transfer count (COUNTER write)
4. Set transfer mode (MODE0/MODE2 writes)
5. Arm DMA (STATUS_IRQ = 0x400)
6. Finalize (MODE1 bit 15 engage)

**Impact:** Knowing the exact register values per operation type
(XPSEL vs XPRUN vs XPDMAR) makes T1.1 tractable.

---

## TIER 2: Needs Hardware Access (board-level measurement)

### T2.1 BIM daisy-chain ordering (Check 3)

**What to measure:** IACKIN/IACKOUT chain on the XLTR card. Determines
which BIM chip has priority when multiple chips request the same level
simultaneously.

**Impact:** Confirms or corrects the emulator's BIM2-first scan order.

### T2.2 Host IRQ-pin level (Check 2)

**What to measure:** Scope the IRQ pin from BIM2 ch2 ($FF0254) to the
68000 IPL lines. The firmware programs level 7 ($5F) but if the
board wiring routes it at a lower level, the behavior diverges
dramatically.

**Impact at level 7:** TCBIO1I ISR blocks panel responder F04930;
host-byte path deadlocked. Monitor `L` command is the only working
host interface.
**Impact at level ≤5:** Panel responder preempts host ISR; the
`bra .` spin escapes; host-byte path works through the normal
interrupt mechanism.

### T2.3 $10AA bus-master write timing

**What to measure:** Logic-analyze VersaBUS during a host-to-SBC
transfer. Capture the chassis writing to $10AA — gives the value,
the timing relative to the transfer, and the triggering condition
(panel command completion? DMA done? mailbox reply?).

**Impact:** Replaces the FPS3K_DMA10AA env var with a hardware-derived
value, and confirms or refutes the "class field = 2" hypothesis.

### T2.4 EU PROM dump

**What to do:** Read the bipolar PROMs on the EXEC card with a
universal PROM programmer. Recovers the 80-bit × 2K Am29116
instruction stream.

**Impact:** Settles the panel-code interpretation question (dispatch
index vs literal instruction vs hybrid). Reveals how the EU responds
to each panel command, how it sequences through microcode addresses,
and how it coordinates with the AU.

### T2.5 XP-32 bus trace during WCS upload

**What to measure:** Capture AU WCS write cycles during a host
microcode upload. Shows the 128-bit data path from SBC → XLTR →
UNIV FMT → WCS write port.

**Impact:** Verifies the 128-bit microinstruction layout consensus.
Confirms WCS bank addressing, data bus width, and the FMT card's
role in the data path.

---

## TIER 3: Long-Term (full hardware modeling)

### T3.1 AU WCS emulation

Model the 4K × 128-bit × 4-bank AU writable control store. Accept
microcode uploads from the staging buffer path and store them.
Read out microinstructions for a future AC pipeline model.

### T3.2 Am29116 EU emulation

Implement the Am29116 16-bit microprocessor instruction set. Execute
EU PROM instructions (would need T2.4 first) to model how the EU
controller sequences AC operations. See `AM29116_EMULATION.md` for
the detailed integration plan, 80-bit PROM structure, panel command
SUBRC decode, and three-phase development roadmap.

### T3.3 FP pipeline emulation

Model the ARITH card's FP pipelines: 1 multiplier + 2 adders,
IEEE-754 32-bit. Execute AU microcode through the pipeline stages
to produce cycle-accurate results comparable to published XPMLIB
timings (Curington 1984).

### T3.4 Full chassis model

Connect all cards (SBC ↔ XLTR ↔ FMT ↔ AC1/AC2 ↔ MEM CTL ↔ SCM)
into a cycle-accurate system model. Run MAXL FORTRAN programs
through the host→SBC→AC→SCM→host round-trip.

---

## Summary of Blockers

| Blocker | What's needed | Can we work around it? |
|---|---|---|
| Panel cmd → response mapping | Bus trace or EU PROM | Yes: treat all commands as D2_FIN responders |
| $10AA value and timing | Bus trace | Partially: FPS3K_DMA10AA=2 works for reply arm |
| Host IRQ level | Board scope | Yes: FPS3K_HOSTLVL=5 for emulator |
| EU PROM contents | Physical chip read | No: blocks AC-side simulation entirely |
| BIM daisy chain | Card trace | Partially: most runs only use one BIM at a time |
| 128-bit AU layout | XP-32 bus trace | Partially: consensus layout ~80% confidence |
