# Emulating the Am29116 in the FPS-3000 EU Controller

How to model the AMD Am29116 16-bit bipolar microprocessor as it
appears on the XP-32 EXEC card (612-4805-002-R). Written to inform
emulator development — what to build, what's known, what must be
inferred, and what requires hardware access.

---

## 1. The Am29116 Chip — Architecture Summary

The Am29116 is a 16-bit bipolar microprocessor with a fixed instruction
set. It is NOT a microprogram sequencer (Am2910/ADSP-1401) — it's a
full CPU with a register file, ALU, status flags, and a program counter.

Per the AMD March 1986 bipolar datasheet (`refs/AMD/29116_dataSheet_Mar86.pdf`)
and March 1988 CMOS Am29C116 datasheet (same ISA):

| Feature | Specification |
|---|---|
| Data path width | 16 bits |
| Register file | 32 × 16-bit (R0-R31), dual-port (1 read + 1 write per cycle) |
| Accumulator | 16-bit ACC register |
| Status flags | Carry, Overflow, Sign, Zero, Parity, Link |
| PC / sequencer | 16-bit program counter with conditional branching |
| Instruction format | 4-field: B/W(1) + Quad(2) + Opcode(4) + SRC/Dest(4) + RAM-addr(5) |
| Instruction families | TOR1 (quad 00), TOR2 (01), ALU (10), Shift/Rotate (11), etc. |
| External buses | 16-bit data bus (bidirectional), 11-bit address bus (for PROM) |
| Pipeline | Single-cycle execution; instruction fetch + execute overlap |
| Clock | ~10 MHz max (100 ns cycle) |

### Register File

32 × 16-bit registers addressed as R0-R31. The dual-port design allows
one register to be read while another is written in the same cycle. On
the FPS-3000 EXEC card, specific RAM addresses may be wired to external
hardware for MMIO-style side effects (reading R[N] triggers a hardware
action).

### Status Register Bits

| Bit | Name | Set when |
|---|---|---|
| C | Carry | ALU operation produces carry-out |
| OVF | Overflow | Signed arithmetic overflow |
| N | Negative | Result bit 15 = 1 |
| Z | Zero | Result = 0 |
| P | Parity | Even parity on result bits 0-7 |
| Link | Link | Shift/rotate carry chain bit |

### Instruction Execution

One instruction per PROM clock cycle. The chip fetches a 16-bit
instruction word from the EU PROM address bus, decodes it, reads up to
one register, performs the ALU operation, writes back to ACC or a
register, and updates status flags — all in one cycle. Conditional
branches use status flags to modify the next PROM address.

---

## 2. The 80-Bit EU PROM Word

Hockney (p. 241) describes the EU PROM as 2K × 80-bit. The Am29116
instruction is 16 bits, so the remaining 64 bits are side-channel
control signals that fan out to the rest of the EXEC and ARITH cards.

### Inferred Layout

The Am29116's native instruction is 16 bits, so the remaining 64 bits
are presumed to be side-channel control signals. **This split (16+64)
is the project consensus, not confirmed by any primary source.**
Hockney p. 241 says "80-bit microcode instructions" without specifying
the internal field assignments.

```
Inferred: bits 0-15 likely = Am29116 instruction word (16 bits)
Inferred: bits 16-79     = side-channel control (64 bits)
```

**Caveat:** The 80-bit word might use a custom microcode format rather
than containing literal Am29116 instructions. The Am29116 might receive
decoded/translated signals from the PROM rather than raw instruction
words. This cannot be settled without a physical PROM dump.

The 64-bit side-channel's sub-field breakdown is entirely speculative.
No primary source confirms bit assignments. The groupings below are
educated guesses based on what the EU must control to coordinate the AU:

| Group | Bits (est.) | Function |
|---|---|---|
| AU WCS address | 12 | Next AU microinstruction address (4K address space) |
| AU pipeline controls | 16 | Function selects for multiplier (WTL-1032), two adders (WTL-1033) |
| S-Pad controls | 8 | Register source/destination, operation (ADD/SUB/MOV/AND/NOR/XOR) |
| Data Pad controls | 10 | DPX/DPY read/write addresses, bus selects |
| Memory controls | 8 | MD/TM read/write, INCMA, address sources |
| DMA controls | 4 | DMA operation type, source, destination |
| EU coordination | 6 | Stall/wait, interrupt acknowledge, channel select |

**Warning:** The sub-field breakdown above is entirely speculative. No
primary source confirms the bit assignments. The consensus layout in
CLAUDE.md gives medium-low confidence for the equivalent AU-side fields.
Also note: the EU PROM's 64-bit side-channel (EXEC card) and the AU
microinstruction's 128-bit fields (ARITH card) are SEPARATE memories
on separate cards with different purposes. The EU PROM controls
high-level sequencing (which AU microinstruction runs next). The AU WCS
controls the FP pipelines cycle-by-cycle. The side-channel breakdown
here describes the EU PROM's signals, not the AU microinstruction
fields.

### PROM Address Space

2K words = 11-bit address space. The Am29116's PC drives the PROM
address bus. Branch targets must fit within 2K. The 2K space is large
enough for:

- A reset/bootstrap sequence (~50-100 instructions)
- Panel command dispatch table + handler routines (~500-800 instructions)
- AC task management (channel state machines, SCM arbitration) (~500-700 instructions)
- Infrastructure (interrupt handlers, default idle loops) (~200-400 instructions)

Total: ~1,500-2,000 instructions. This is comparable to the FPS-100's
AP-side supervisor (1,971 instructions across 69 routines in the `.B`
files decoded in `apo_decoded/B_files/`).

---

## 3. The Two-Am29116 Configuration

The EXEC card has **two** Am29116DCB chips (owner confirmation,
2026-07-29). How they share the 80-bit PROM word is unresolved:

### Possibility A: Split instruction stream
Both chips fetch from the same 80-bit PROM but receive different halves
of the word. Chip 1 gets bits 0-15 (its instruction) + side-channel
bits 16-47. Chip 2 gets another 16-bit instruction field from bits
48-63 + side-channel bits 64-79.

### Possibility B: Master/slave cascade
One chip is the primary EU controller (fetching instructions and
driving the AU). The second chip handles address computation or
integer arithmetic, receiving its operands from the master via the
16-bit data bus and returning results the same way.

### Possibility C: Independent sequencing
Each chip has its own portion of the 80-bit word with independent
instruction streams. Both execute simultaneously but on different
aspects of the pipeline (e.g., one handles DPX/DPY addressing while
the other handles AU pipeline control).

**Unresolved.** Settling this requires either:
- Physical PROM dump + analysis (if the two chips share one PROM, the
  dump contains both streams; if they have separate PROMs, two dumps)
- Board-level tracing of PROM address/data lines to each Am29116

### Emulator Approach

For a first-cut emulator, model only **one** Am29116. The second can
be treated as an address/data coprocessor that runs in lockstep. This
is adequate for:
- Panel command dispatch (the primary function affected by Am29116 execution)
- AU pipeline coordination (the second chip likely handles data routing,
  not instruction sequencing)

---

## 4. Panel Command Interface — SUBRC Decode

The SBC writes panel commands (0x258-0x27D) to $FF000E, then writes
0x8004 to $FF0000. This triggers the chassis, which delivers the command
to the EU's Am29116 input.

### How the Am29116 Receives Panel Commands

The SBC writes a 16-bit command code to $FF000E (AP I/F register).
Whether this reaches the Am29116 directly or through intermediate
decoding logic (XLTR, FMT, PALs) is unverified. The 21 codes
decode as valid Am29116 SUBRC instructions, but this proves only
that FPS chose codes matching the Am29116 ISA — not that the
Am29116 receives them as instructions.

```
Bit 15    | 14-13  | 12-9    | 8-5       | 4-0
B/W=0     | Quad=00| Opcode=0001 | SRC/Dest  | RAM Addr
Word op   | TOR1   | SUBRC    | see below  | register index
```

### Group A: TORIA ($258-$25F)
SRC/Dest = 0010
Operation: `ACC ← I − RAM[R24..R31] − ¬carry`

The "I" (immediate) is the next word in the instruction stream — so
the chassis must also supply a 16-bit argument following the command.
Each code addresses a different RAM register (R24-R31).

### Group B: TODRA ($260-$27D)
SRC/Dest = 0011
Operation: `ACC ← RAM[N] − D − ¬carry`

The "D" is the chip's data-latch register, loaded externally. The
RAM address N varies by code (R0, R9-R12, R14, R17, R22-R31).

### Emulator Design Decision

There are three interpretations for how the Am29116 processes these
codes. An emulator must pick one:

**Option 1: Dispatch index (simplest to implement)**
Treat the code as a jump-table index. The EU PROM has a dispatch table
at a fixed address; each code indexes into it. The Am29116 jumps to
the handler for that code without executing SUBRC.

*Implementation:* `handler_addr = dispatch_table[code - 0x258]; PC = handler_addr;`

**Option 2: Literal execution with MMIO side effects (moderate)**
Execute the SUBRC instruction. The RAM read at R[N] triggers MMIO
side effects wired to specific register addresses. The arithmetic
result in ACC may be used or discarded.

*Implementation:*
```c
// Execute SUBRC TORIA
acc = immediate - ram[ram_addr] - !carry;
update_flags(acc);
// Side effect: RAM read at ram_addr triggers hardware action
handle_mmio_read(ram_addr);
```

**Option 3: Hybrid — execute then dispatch (most accurate)**
Execute SUBRC to compute ACC, then use ACC as a dispatch input.
The handler examines ACC and branches.

*Implementation:* like Option 2, but then `dispatch_by_acc(acc);`

**Recommendation:** Start with Option 1 and add Option 2/3 complexity
as the EU PROM contents become available. Option 1 unblocks the SBC
side (panel commands get responses) without requiring correct Am29116
execution.

---

## 5. Emulator Integration Plan

### 5.1 Minimal Viable Emulation (Phase 1)

**Goal:** Make panel commands produce responses so the SBC firmware
can advance past its current 19% coverage.

**What to build:**
1. An `am29116_t` state structure:
   ```c
   typedef struct {
       uint16_t pc;          // 11-bit PROM address (0-2047)
       uint16_t acc;         // accumulator
       uint16_t ram[32];     // register file R0-R31
       uint16_t d_latch;     // external data latch
       uint8_t  carry;       // C flag
       uint8_t  overflow;    // OVF flag
       uint8_t  negative;    // N flag
       uint8_t  zero;        // Z flag
       uint16_t prom[2048];  // if PROM contents available
       // For dispatch-only mode:
       int      (*dispatch)(uint16_t panel_cmd);
   } am29116_t;
   ```

2. A panel command dispatch function:
   ```c
   int am29116_panel_dispatch(am29116_t *eu, uint16_t cmd) {
       // Option 1: dispatch index
       switch (cmd) {
           case 0x258: return handle_ch1_reset(eu);
           case 0x259: return handle_ch1_init(eu);
           // ... all 38 codes
           default:    return -1;  // unknown command
       }
   }
   ```

3. Each handler:
   - Performs the Am29116-side operation (if Option 2/3)
   - Triggers any MMIO side effects
   - Returns a response code (0x00-0x14) that becomes the MODE0
     response the SBC's handler reads

4. Wire into `versabus.c`:
   - When `chassis_process_panel_cmd()` is called, pass the command to
     `am29116_panel_dispatch()`
   - The return value becomes the panel response code
   - Use the existing `versabus_arm_panel_response()` mechanism

### 5.2 PROM-Driven Execution (Phase 2)

**Prerequisite:** EU PROM dump from physical EXEC card.

**What to build:**
1. Load 2K × 80-bit PROM image
2. Implement the full Am29116 instruction set:
   - TOR1/TOR2 (two-operand RAM instructions): ADD, SUBR, SUBS, AND, OR,
     XOR, MOV, SUBRC, etc.
   - ALU operations (no RAM operand): arithmetic/logical on ACC
   - Shift/Rotate: SHL, SHR, ROL, ROR with link bit
   - Branches: conditional jumps based on status flags
   - I/O: IN/OUT for external bus cycles
   - Control: HALT, NOP

3. Decode and execute the 64-bit side-channel on each cycle:
   - Update AU WCS address
   - Assert pipeline control signals
   - Update S-Pad/Data-Pad controls

4. Cycle-accurate execution loop:
   ```c
   while (running) {
       uint64_t instr = eu->prom[eu->pc & 0x7FF];
       uint16_t ami   = instr & 0xFFFF;       // Am29116 instruction
       uint64_t side  = instr >> 16;          // side-channel controls

       am29116_execute(eu, ami);              // update ACC, flags, RAM
       side_channel_apply(side);              // update AU state
       eu->pc = am29116_next_pc(eu, ami);     // sequential or branch
       total_cycles++;
   }
   ```

### 5.3 Full AC Simulation (Phase 3)

**Prerequisite:** Phase 2 + AU WCS contents (from host upload).

**What to build:**
1. AU WCS (4K × 128-bit × 4 banks) — initially empty, populated by
   the S-record upload path
2. AU pipeline model:
   - WTL-1032 multiplier (3-stage internal pipeline, IEEE-754 32-bit)
   - Two WTL-1033 adders (same pipeline depth)
   - Pipeline register stages (input mux + 3 chip stages + output capture)
3. Data Pad (DPX, DPY registers — count unknown, likely 16-32 entries)
4. S-Pad (register file — count unknown, likely 16-32 entries)
5. MD/TM memory (LMD 16K × 32-bit, TCM 4K × 32-bit)
6. SCM interface (shared memory via MEM CTL)
7. Cycle-accurate AU execution driven by the 128-bit microinstruction

---

## 6. What's Known vs What's Inferred

| Feature | Status | Source |
|---|---|---|
| Am29116 chip ID | **KNOWN** | Nakazoto EXEC photo (AMD Am29116DCB) |
| Dual-Am29116 count | **KNOWN** | Owner confirmation 2026-07-29 |
| Am29116 ISA (all variants) | **KNOWN** | AMD datasheets (Mar 1986/1988) |
| Panel codes decode as SUBRC | **KNOWN** | Verified against both datasheets |
| Panel code RAM addresses | **KNOWN** | Decoded from low 5 bits of each code |
| EU PROM width (80-bit) | **KNOWN** | Hockney p. 241 |
| EU PROM size (2K) | **KNOWN** | Hockney p. 241 |
| EU PROM contents | **UNKNOWN** | Requires physical chip read |
| Side-channel bit assignments | **UNKNOWN** | Pure inference; no primary source |
| Two-chip configuration | **UNKNOWN** | Split vs cascade vs independent |
| MMIO wiring on RAM reads | **UNKNOWN** | Requires board-level tracing |
| Panel command interpretation | **UNKNOWN** | 3 possibilities; needs EU PROM |
| AU microinstruction format | **UNKNOWN** | Consensus layout ~80% confidence |
| WTL chip mode (PIPE/FLOW) | **UNKNOWN** | Needs EU PROM or XPMLIB binary |

---

## 7. Development Priorities

1. **Phase 1A — Dispatch-only panel command emulation**
   - 2-3 days of coding in `versabus.c`
   - Unblocks the SBC's panel command protocol
   - No Am29116 execution needed
   - Uses the existing `versabus_arm_panel_response()` path

2. **Phase 1B — Basic Am29116 state structure**
   - 1 day: define `am29116_t`, wire into `versabus_tick()`
   - Enables tracking register state across panel commands
   - Prerequisite for MMIO-side-effect modeling

3. **Phase 2 — PROM-driven execution**
   - Requires EU PROM dump (physical hardware access)
   - 2-4 weeks for full Am29116 instruction set emulation
   - 2-4 weeks for side-channel decode (reverse-engineering 64 bits)
   - Unlocks full AC-side simulation

4. **Phase 3 — Full AC pipeline**
   - Requires AU WCS contents + microinstruction format confirmation
   - 4-8 weeks for FP pipeline model with correct IEEE-754 behavior
   - Enables running actual XPMLIB kernels and comparing against
     published performance numbers (Curington 1984)

---

## 8. The Panel Command Data Flow

```
SBC (68000)                          EU (Am29116)                AU (WTL chips)
    │                                       │                           │
    │  write panel cmd to $FF000E           │                           │
    │  write 0x8004 to $FF0000              │                           │
    │─────────────────────────────────────→│                           │
    │                                       │  decode cmd as SUBRC      │
    │                                       │  (or dispatch index)      │
    │                                       │                           │
    │                                       │  read RAM[R24..R31]       │
    │                                       │  (may trigger MMIO)       │
    │                                       │                           │
    │                                       │  compute ACC result       │
    │                                       │──────────────────────────→│
    │                                       │                           │  execute
    │                                       │                           │  AU operation
    │                                       │                           │  (if applicable)
    │                                       │←──────────────────────────│
    │                                       │  AU status/done           │
    │                                       │                           │
    │                                       │  return response code     │
    │←─────────────────────────────────────│  in MODE0 bits 0-4        │
    │  read MODE0 via BIM0 ch0 ISR          │  + BIM0 ch0 interrupt     │
    │  dispatch via PanelStatusDispatchTable│                           │
```

The chassis model in the emulator currently implements only the SBC side
of this — the left and right edges. The Am29116 emulation fills in the
middle. Phase 1 (dispatch-only) collapses the Am29116 and AU into a
single function call that returns the response code. This is enough to
unblock the SBC firmware. Phases 2-3 model the actual computation.
