# Panel Command Cross-Reference

Three views of the panel command codes, synthesized from the disassembly,
the emulator model, and the Am29116 decode.

---

## 1. Functional Map (from ROM behavior)

These names are determined by tracing what the firmware does around each
code write. 29 codes are named this way; the names live in `versabus.c`
and are applied as `; PCMD_*` comments in `fps3k.asm`.

### Channel-Specific Operations

| Code | Emulator Name | What the ROM does | Am29116 Group |
|---|---|---|---|
| 0x258 | `PCMD_CH1_RESET` | Channel 1 reset — issued during init | TORIA (Grp A) |
| 0x259 | `PCMD_CH1_INIT` | Channel 1 init — initial channel configuration | TORIA (Grp A) |
| 0x25A | `PCMD_CH1_ACK` | Channel 1 acknowledge — response handshake | TORIA (Grp A) |
| 0x25B | `PCMD_CH1_FLUSH` | Channel 1 flush — drain pending operations | TORIA (Grp A) |
| 0x25C | `PCMD_RESET_STATUS` | Global status reset — clear all channel state | TORIA (Grp A) |

### Per-Channel Configuration

| Code | Emulator Name | What the ROM does | Am29116 Group |
|---|---|---|---|
| 0x25D | `PCMD_CH1_CONFIG` | Channel 1 config | TORIA (Grp A) |
| 0x25E | `PCMD_CH2_CONFIG` | Channel 2 config | TORIA (Grp A) |
| 0x25F | `PCMD_CH3_CONFIG` | Channel 3 config | TORIA (Grp A) |
| 0x260 | `PCMD_CH4_CONFIG` | Channel 4 config | **TODRA (Grp B)** ← crosses boundary |

**Note:** The last CONFIG code (0x260) crosses the TORIA/TODRA boundary.
If the codes are literal Am29116 instructions, CH4_CONFIG uses a
different instruction (TODRA: ACC ← RAM[N] - D - ¬c) than CH1-3
(TORIA: ACC ← I - RAM[R24..R31] - ¬c). This is a different semantic
and weakly suggests the codes are dispatch indices, not literal
instructions.

### Abort / Error Paths

| Code | Emulator Name | What the ROM does |
|---|---|---|
| 0x269 | `PCMD_ERROR_ABORT` | Error abort path — written after detecting a fault |
| 0x26A | `PCMD_TIMEOUT_ABORT` | Timeout abort — emitted by PanelTimeoutAbortPath (F068A8) |
| 0x26B | `PCMD_CH_ABORT` | Channel abort — generic per-channel abort |
| 0x26C | `PCMD_RELEASE` | Release — the D2_FIN finalize code |
| 0x26D | `PCMD_DIRECTIVE_FAIL` | Trap #1 directive $01 failure |
| 0x26E | `PCMD_DIRECTIVE_FAIL` | Trap #1 directive $2D failure |
| 0x270 | `PCMD_DIRECTIVE_FAIL` | Trap #1 directive $4C failure |
| 0x271 | `PCMD_DIRECTIVE_FAIL` | Trap #1 directive ? failure |

**Note on $26D-$271:** These are NOT per-channel codes. All four XP tasks
emit the identical multiset; the code indexes the RTOS directive that
failed. The "CH1_TCB_FAIL" label for $26E in `versabus.c` is stale.

### Init Sequence (Path B)

| Code | Emulator Name | Phase |
|---|---|---|
| 0x276 | `PCMD_INIT_STEP1` | Early init, pre-channel |
| 0x277 | `PCMD_INIT_STEP2` | Channel enumeration |
| 0x278 | `PCMD_INIT_STEP3` | Channel config table walk |
| 0x279 | `PCMD_INIT_STEP4` | Channel ready check |
| 0x27A | `PCMD_INIT_STEP5` | BIM programming |
| 0x27B | `PCMD_INIT_STEP6` | ASQ attach |
| 0x27D | `PCMD_INIT_STEP8` | Final init step |
| **0x27C** | — | **GAP — no init step uses this code** |

### TCBIO1I Host Link

| Code | Emulator Name | What the ROM does |
|---|---|---|
| 0x27E | `PCMD_TCBIO1I_INIT_FAIL` | TCBIO1I init phase failure |
| 0x27F | `PCMD_TCBIO1I_DATA_FAIL` | TCBIO1I data phase failure |
| 0x280 | `PCMD_TCBIO1I_RUN_FAIL` | TCBIO1I run phase failure |
| 0x281 | `PCMD_HOST_REQUEST` | "Give me the next host byte" — ISR writes this to request data |
| 0x282 | `PCMD_HOST_NULL` | "Re-sync" — same byte again, no consume |

### Exception Reporters (non-SUBRC range)

| Code | Emulator Name | Exception Class |
|---|---|---|
| 0x29E | `PCMD_EXCEPTION_BUSERR` | Bus error |
| 0x29F | `PCMD_EXCEPTION_ADDRERR` | Address error |
| 0x2A0 | `PCMD_EXCEPTION_ILLEGAL` | Illegal instruction |
| 0x2A1 | `PCMD_EXCEPTION_DIVZERO` | Divide by zero |
| 0x2A2 | `PCMD_EXCEPTION_CHK` | CHK instruction |
| 0x2A3 | `PCMD_EXCEPTION_TRAPV` | TRAPV overflow |
| 0x2A4 | `PCMD_EXCEPTION_PRIVILEGE` | Privilege violation |
| 0x2A5 | `PCMD_EXCEPTION_UNINIT_INT` | Uninitialised interrupt |
| 0x2A6 | `PCMD_EXCEPTION_CATCHALL` | 182 unused user vectors |

These 9 codes are from a table at $F0A23A (4 bytes each). They fall
outside the SUBRC range (0x258-0x27D) and cannot be Am29116 instructions.
If the board dies, the last value at $FF000E names the exception.

| Code | Emulator Name | What the ROM does |
|---|---|---|
| 0x2B2 | `PCMD_KERNEL_FATAL` | Issued by hand-placed FPS stub at $F001A0 inside RMS68K region, then hangs |

---

## 2. Am29116 SUBRC Decode

All 38 codes 0x258-0x27D decode as TOR1 SUBRC ("S minus R with carry").

### Group A: TORIA ($258-$25F)

Instruction: `ACC ← I - RAM[R24..R31] - ¬c`
- Source = I (immediate operand)
- Destination = TORIA (RAM indexed by R24..R31)
- Operand: R24..R31 index select via low 3 bits

| Code | Low 3 bits | RAM Index |
|---|---|---|
| 0x258 | 000 | R24 |
| 0x259 | 001 | R25 |
| 0x25A | 010 | R26 |
| 0x25B | 011 | R27 |
| 0x25C | 100 | R28 |
| 0x25D | 101 | R29 |
| 0x25E | 110 | R30 |
| 0x25F | 111 | R31 |

### Group B: TODRA ($260-$27D)

Instruction: `ACC ← RAM[N] - D - ¬c`
- Source = RAM[N] (N = R0, R9-R29, selected by low 5 bits)
- Destination = D (direct data)
- 30 codes in this range (0x260-0x27D = 30 codes, 0x27E+ outside SUBRC)

The D (direct data) field encodes a 16-bit immediate value in the
Am29116 instruction. If these codes are literal instructions, the
"data" values would be hardware-significant constants.

---

## 3. PanelStatusDispatchTable Response Codes

The 42-entry dispatch table maps response codes (0..41) to 4 handlers.
What panel command produces each response code is **unknown** — this
is the central gap in the protocol model.

| Code (d0) | Handler | Class | Notes |
|---|---|---|---|
| 0 | RTS | noop | |
| 1 | POLL (F05A12) | sync | Poll $FF0004 b0, arm STATUS_IRQ, wait b15 |
| 2-7 | D1_SEND (F058B2) | push | Send d1 to chassis |
| 8-9 | BLK_XFR (F05B0E) | copy | Copy word chassis→SBC buffer |
| 10 | POLL | sync | |
| 11-12 | RTS | noop | |
| 13-16 | D1_SEND | push | |
| 17-19 | RTS | noop | |
| **20 (0x14)** | **D2_FIN (F05738)** | **finalize** | **The only FIN entry. Push d2, CONTINUE-TRANSFER, PCMD_RELEASE.** |
| 21 | RTS | noop | |
| 22-23 | POLL | sync | |
| 24 | BLK_XFR | copy | |
| 25 | POLL | sync | |
| 26 | BLK_XFR | copy | |
| 27 | POLL | sync | |
| 28-30 | BLK_XFR | copy | |
| 31 | POLL | sync | |
| 32-34 | — | — | (table continues, 10 more entries) |

The D2_FIN handler at index 0x14 is special: it is the only one that
issues PCMD_RELEASE (0x26C) and CONTINUE-TRANSFER (0x8005). This is
the transfer-complete path — the chassis sends code 0x14 when a DMA
transfer finishes, and the SBC finalizes.

---

## 4. Unresolved Cross-References

### Panel Command → Response Code Mapping (Unknown)

```
SBC writes panel command → chassis processes → chassis returns response code
```

The mapping from panel command to response code is a black box.
Example unknown chain:
- SBC writes `PCMD_HOST_REQUEST` (0x281) → chassis returns what?
- SBC writes `PCMD_CH1_RESET` (0x258) → chassis returns what?
- SBC writes `PCMD_CH1_CONFIG` (0x25D) → chassis returns what?

Without a bus trace, schematic, or chassis model, this chain is
unobservable from the SBC side alone.

### Response Code → Dispatch Handler (Known)

This is the only part we fully know — the 42-entry dispatch table
maps each response code to one of 4 handlers. The table is
unambiguous (hard-coded jump addresses).

### Three-Interpretations Model (Open)

| Interpretation | Evidence For | Evidence Against |
|---|---|---|
| 1. Dispatch indices | Functional grouping crosses Am29116 instruction boundary (CH4_CONFIG at 0x260 = TODRA while CH1-3 = TORIA). Exception codes (0x29E+) are outside SUBRC range entirely. | The codes ARE valid SUBRC instructions — why pick exactly these if they're just indices? |
| 2. Literal Am29116 instructions | Codes decode as valid SUBRC; the EU's Am29116 could execute them directly. ACC result might be the dispatch input. | The functional split doesn't match the instruction grouping. Four codes (0x281/0x282/0x29E/0x29F) are outside the SUBRC range. |
| 3. Hybrid: real code + MMIO side-effect | The Am29116 executes the instruction; RAM-read at the destination address triggers MMIO side-effects that act as dispatch. | No confirmation possible without EU PROM contents. |

The functional mapping (interpretation 1) is the most useful for driving
the hardware. The instruction mapping (interpretation 2) may be correct
at the electrical level but does not predict what the chassis does.
