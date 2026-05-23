# Inferred XP32 microinstruction format (using Am29116 datasheet)

> **Note (post-revision):** parts of this doc were written assuming
> the EU sequencer's program lives in writable SRAM, host-uploaded.
> Hockney figure 2.53 + chassis-photo confirmation later clarified
> that the **EU runs from a fixed 2K × 80-bit mask PROM** on the
> EXEC card; only the AU's 4K × 128-bit × 4 banks of writable
> control store is host-uploaded. So **the SBC's 64 KB staging
> buffer feeds the AU, not the EU**. The Am29116-side analysis
> below is still factually correct as ISA reference for that chip,
> but its interpretation as "what the SBC uploads" was wrong.
> See `xp32_opcode_clues.md` for the better-grounded analysis
> based on the Touzeau 1984 / APSIM64 manual sources.

Combining: (a) the Nakazoto/Usagi photographs of the EXEC card showing
the AMD Am29116 sequencer + SRAM array + PALs; (b) Hockney's "4K ×
128-bit, 4 banks" WCS description; (c) the FPS-3000 ROM's S-record
upload path that stages exactly 64 KB at `0x10000–0x1FFFF` (= one bank);
(d) the Am29116 datasheet (AMD 1981, well-documented).

## The arithmetic checks out

```
1 WCS bank        = 4096 microinstructions × 128 bits
                  = 4096 × 16 bytes
                  = 65536 bytes
                  = 64 KB                          ← matches staging buffer
```

`SRecordDataHandler` at `F051A2` enforces `0x10000 ≤ addr ≤ 0x1FFFF`,
exactly one bank. Each microinstruction = **16 bytes = 8 × 16-bit
words** in the staging buffer.

## Layout per microinstruction (16-byte block)

Most likely word assignment, deduced from chip-level functional
decomposition:

| Word | Byte offset | Bits | Functional unit |
|---|---|---|---|
| W0 | 0–1 | 16 | **Am29116 instruction word** (the EXEC sequencer's instruction; defines source/dest registers, ALU op, condition) |
| W1 | 2–3 | 16 | Branch target / immediate / page-select for next-µaddr |
| W2 | 4–5 | 16 | LMD/TCM/SCM address (24-bit, two halves) |
| W3 | 6–7 | 16 | (continuation of address + memory direction/enable bits) |
| W4 | 8–9 | 16 | DPX/DPY register file selects (read & write addrs, function) |
| W5 | 10–11 | 16 | FALU control (operand select, function code, sign) |
| W6 | 12–13 | 16 | FMUL control (operand select, MAC enable, accumulator) |
| W7 | 14–15 | 16 | Pipeline-stage clock enables, condition-code source, host-handshake bits, parity |

The exact partitioning is **not yet confirmed** — the assignment above
is plausible given the chip set (Am29116 + 4× L29C520 MAC + Weitek
WTL-1064/65 + Am2168 SRAM banks + PALs) and the 128-bit total width.

## Am29116 instruction word (the W0 slot — confident)

From AMD's 1981/1984 datasheet:

```
bit 15 14 13 12 │ 11 10  9  8  7 │  6  5  4  3  2 │  1  0
   T   T   T   T │  S  S  S  S  S │  D  D  D  D  D │  M  M
   ───────────── │  ───────────── │  ───────────── │  ───
   instr class   │  source field  │  dest. field   │  mode
```

**T (4 bits) — instruction class**:
| T | Class |
|---|---|
| 0 | Move (R↔R, R↔immediate) |
| 1 | ALU two-operand (ADD, SUB, AND, OR, XOR, ...) |
| 2 | ALU single-operand (NOT, INC, DEC, NEG, ...) |
| 3 | Shift (logical/arith/rotate, 1-bit) |
| 4 | Bit (TEST, SET, CLR, indexed by S/D) |
| 5 | Branch (conditional, on flags) |
| 6 | Subroutine call / return / loop |
| 7 | Status / external / I/O |
| 8 | Multi-bit shift (count from S register) |
| 9 | Normalize / count-leading-zeros / priority |
| 10 | Byte ops (swap, sign-extend, mask) |
| 11 | CRC step |
| 12-15 | reserved / vendor |

**S (5 bits) — source register** index 0–31 (Am29116 has 32 internal
16-bit registers).

**D (5 bits) — destination register** index 0–31.

**M (2 bits) — addressing mode**: register-direct, register-indirect
via address register, immediate (next instruction word = data),
external memory.

This Am29116 "S-Pad" register file (32 × 16-bit) is the FPS XP-32's
**EU integer register set**. When MAXL/CPFORTRAN code references
"S-Pad register N", it's an Am29116 register at index N.

## What this implies for the FPS-3000 ROM

The ROM's panel-command sequencer (`F056BA` and friends) is
**uploading 16-byte blocks into the 64 KB staging buffer**, then
walking that buffer 16 bytes at a time across the XLTR + UNIV-FMT to
the EXEC card's WCS write port.

Specifically:

1. Host sends S-records over the AP I/F. `SRecordDataHandler` parses
   the address (must be in `0x10000-0x1FFFF`) and the 16-byte (or
   sub-block) payload, copies into staging RAM.
2. When `SRecordFinalize` (at `F05256`) sees an S9 / S8 termination, it
   triggers the upload sequence.
3. The upload sequence walks the buffer 16 bytes at a time, issuing
   panel-command code XX (one of `0x258..0x27D` — most likely `0x276`
   based on its position in the init sequence) per microinstruction.
   Each panel command transmits the 16-byte block to the WCS via
   the `0x8004`+`0x8005` two-half protocol (since a 16-byte block is
   8 transfers, not 1).
4. Once all banks needed by the user microcode are loaded, the host
   issues XPRUN, which sets the Am29116's PC to a configured entry
   point (probably stored in one of the per-channel config registers
   `FF0244/46/50/52`) and clears the busy flag, letting the EU + AU
   run.

## What I still don't know

- **Exact byte ordering** within a microinstruction (which slot is the
  Am29116 instruction — could be W7 instead of W0)
- **Endianness** of the multi-byte fields (the SBC is big-endian m68k
  but the WCS write port could re-order bytes in the XLTR)
- **Which `0x276..0x27D` panel-command code** specifically uploads a
  16-byte block. Need to trace the SRecord finalize → panel-command
  call chain.
- **Exact assignment of FP-pipeline control bits** to each L29C520 /
  Weitek chip. Without the AU schematic, this is guesswork.

## What's now actionable

Even at "guesswork" quality the above gives a useful invariant: if you
disassemble any 16-byte block from the WCS, the **W0 (or whichever)
slot must be a valid Am29116 instruction**. That's testable. Patterns:

- All zeros → NOP (Am29116 has a zero-opcode NOP)
- High nibble `0x5_` → branch
- High nibble `0x1_`–`0x2_` → ALU op
- Repeated patterns of `0x0_` (move) interspersed with branch/ALU →
  typical microcode loop body

If we ever find or write a candidate XP-32 microcode binary, the
Am29116 datasheet + this layout is enough to **disassemble the EU
half** of every microinstruction, even without knowing the FP pipeline
encoding. That's the crack we have to start with.
