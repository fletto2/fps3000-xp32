# Panel command codes (`0x258..0x27D`) — proper Am29116 decoding

## Status: corrects an earlier overconfident analysis

An earlier pass (in conversation, not committed) concluded that all
21 panel command codes decode as a clean "MOV R4 → R[D]" pattern in
the Am29116 ISA, "decisively confirming" interpretation B (codes are
literal Am29116 instructions). **That analysis was wrong** because it
used an incorrect instruction format.

The correct format (verified against both the Am29116 March 1986
bipolar datasheet and the Am29C116 March 1988 CMOS datasheet — same
ISA across both variants) is:

```
bit  15  | 14 13 |  12 11 10 9  | 8 7 6 5  |  4 3 2 1 0
     B/W |  Quad |    Opcode    | SRC/Dest |  RAM Address
     1   |   2   |       4      |    4     |       5
```

Five fields. Each Quad value selects an instruction-type family;
Opcode encodes the operation within that family; the SRC/Dest field
encodes operand source/destination combinations via lookup tables.
**Not** a flat T-class / S-reg / D-reg / mode model.

## Re-decoded panel commands

All 21 panel codes share `B/W=0, Quad=00, Opcode=0001`. Under
Quad=00 they're **TOR1** (Two-Operand RAM-source/dest type 1)
instructions. Under Opcode=0001 they're **SUBRC** — *S minus R with
carry, with the result stored in the destination*.

The SRC/Dest field divides the 21 codes into two groups:

### Group A — codes `0x258..0x25F` (SRC/Dest = 0010 = TORIA)

| Code | RAM addr | Decoded instruction |
|---|---|---|
| 0x258 | R24 | `TOR1 SUBRC TORIA R24` → ACC ← I − RAM[R24] − ¬carry |
| 0x259 | R25 | `TOR1 SUBRC TORIA R25` → ACC ← I − RAM[R25] − ¬carry |
| 0x25A | R26 | … |
| 0x25B | R27 | … |
| 0x25C | R28 | … |
| 0x25D | R29 | … |
| 0x25E | R30 | … |
| 0x25F | R31 | `TOR1 SUBRC TORIA R31` → ACC ← I − RAM[R31] − ¬carry |

`TORIA` operand pattern means R=RAM, S=Immediate, Dest=ACC. The
"Immediate" is the next instruction word — i.e., a 16-bit constant
follows the command in the instruction stream. So each of these
codes is "subtract RAM[R24..R31] from a host-supplied immediate
value, store result in ACC".

### Group B — codes `0x260..0x27D` (SRC/Dest = 0011 = TODRA)

| Code | RAM addr | Decoded instruction |
|---|---|---|
| 0x260 | R0  | `TOR1 SUBRC TODRA R0`  → ACC ← RAM[R0] − D − ¬carry |
| 0x269 | R9  | `TOR1 SUBRC TODRA R9`  |
| 0x26A | R10 | `TOR1 SUBRC TODRA R10` |
| 0x26B | R11 | `TOR1 SUBRC TODRA R11` |
| 0x26C | R12 | `TOR1 SUBRC TODRA R12` |
| 0x26E | R14 | `TOR1 SUBRC TODRA R14` |
| 0x271 | R17 | `TOR1 SUBRC TODRA R17` |
| 0x276 | R22 | `TOR1 SUBRC TODRA R22` |
| 0x277 | R23 | `TOR1 SUBRC TODRA R23` |
| 0x278 | R24 | `TOR1 SUBRC TODRA R24` |
| 0x279 | R25 | `TOR1 SUBRC TODRA R25` |
| 0x27A | R26 | … |
| 0x27B | R27 | … |
| 0x27D | R29 | `TOR1 SUBRC TODRA R29` → ACC ← RAM[R29] − D − ¬carry |

`TODRA` operand pattern means R=D-latch, S=RAM, Dest=ACC. The
"D-latch" is the chip's external data-latch register (separate from
RAM and ACC). So each of these is "subtract D-latch from RAM[N],
store result in ACC".

## What this means

### Three plausibilities, none confirmable without the EU PROM

**Possibility 1 — codes are dispatch indices that happen to be
valid Am29116 instructions.** Under this reading, the codes look
like SUBRC instructions but the EU's command-handler PROM doesn't
execute them as instructions — it dispatches on (some bits of) the
code via a jump table. The "syntactic validity" is FPS engineers
choosing dispatch numbers that don't trigger illegal-opcode traps if
the chip happens to see them.

Evidence for: the decoded operations (SUBRC) don't intuitively map
to the inferred semantics (channel reset, init step, RELEASE, etc.).
A subtract-with-carry doesn't naturally mean "reset channel 1".

**Possibility 2 — codes ARE executed as Am29116 instructions, but
their hardware side effects are what matter.** The Am29116's RAM
register file is 32 entries; FPS may have wired specific addresses
(R0, R9-R12, R14, R17, R22-R31) to external hardware so reading or
writing them produces side effects beyond the arithmetic result.
Under this reading, the SBC's panel command makes the EU execute
SUBRC, which reads RAM[N] — and the *act of reading R[N]* triggers
the hardware action wired to that address.

Evidence for: the structure is too clean to be random. All same
instruction type, same opcode, just two operand patterns, with RAM
addresses clustering in specific ranges. That pattern would arise
naturally if FPS used the Am29116's RAM-read as a "memory-mapped
trigger" mechanism.

**Possibility 3 — hybrid.** EU executes the code as an instruction,
producing a SUBRC result in ACC, then a separate dispatch mechanism
examines the ACC value and branches accordingly. Code is real, side
effect is the dispatch.

### Why my earlier "decisively interpretation B" claim was wrong

I had decoded the codes against an incorrect 4-bit T-class /
5-bit-S / 5-bit-D / 2-bit-M format. Under that wrong format,
everything happened to fall into a clean "T=0 (move), S=4, D=22..31,
M=0..3" pattern that *looked* like memory-mapped MOVs — exactly the
shape interpretation B predicts. **The pattern was an artifact of
the wrong field boundaries**; under the correct format, the
operations are not MOVs but arithmetic subtracts.

### What this changes for the project

The XP-32 EU's command-handling mechanism remains undetermined
between possibilities 1, 2, and 3. **All three require the EU PROM
read to disambiguate.**

What's still useful from the analysis:

1. The 21 codes are deliberately structured (single instruction
   type, single opcode, two operand patterns) — not random
2. They all decode as syntactically valid Am29116 SUBRC
   instructions
3. The RAM addresses cluster suggestively (R24-R31 in Group A;
   R0, R9-R12, R14, R17, R22-R31 in Group B) — suggesting FPS
   used a structured indexing scheme
4. Both bipolar Am29116 (1986) and CMOS Am29C116 (1988) variants
   have the same ISA; the FPS-3000 Am29116 (whatever vintage) almost
   certainly decodes the same way

What I retract: the "smoking gun proof of interpretation B" claim.
The pattern remains *suggestive* of interpretation B, but no longer
*decisive*.

## Erratum reference

This document corrects the conversation message that decoded the 21
codes as `MOV R4 → R[D], mode M`. The substance of that message
should be considered superseded by the analysis above.

Date of correction: 2026-05-09. Trigger: re-reading the actual AMD
datasheets (March 1986 bipolar + March 1988 CMOS) instead of relying
on memory.

## Cross-reference

- Datasheets: `refs/AMD/29116_dataSheet_Mar86.pdf` (bipolar),
  `refs/AMD/29C116_dataSheet_Mar88.pdf` (CMOS)
- Earlier analysis (now superseded for the panel-code section):
  `xp32_eu_command_protocol.md`, `inferring_xp32_microcode.md`
- Project-level dependency: `project_plan.md` task B3 (read EU PROM)
  — the only deterministic way to settle which possibility is real
