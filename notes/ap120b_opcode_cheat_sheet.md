# AP-120B / FPS-100 opcode cheat sheet (Tables A-3, A-4, A-5)

**Source**: supplied by the project owner 2026-07-31 via Discord.
**Local copy**: `refs/FPS-100/opcode_cheat_sheet.png` (and the original `.webp`).
Discord CDN URLs carry an `ex=` expiry stamp, so the link itself is not a durable reference —
the local copy is.

It is Appendix A of the **AP-120B Programmer's Reference Manual**: Table A-3 "AP Instruction
Summary" (the 64-bit instruction-word field map plus octal codes for every unconditional field),
Table A-4 "SPEC Fields", Table A-5 "I/O Fields".

## What it confirms

**The field ORDER of the 64-bit microinstruction, independently of `SIM100.FTN`.** Reading the
diagram left to right: `B, SOP, SH, SPS, SPD, FADD, A1, A2, COND, DISP, DPX, DPY, DPBS, XR, YR,
XW, YW, FM, M1, M2, MI, MA, DPA, TMA` — the same 24 fields in the same order as the `SPLIT(CB,FV)`
decomposition recorded in `CLAUDE.md`, which was derived from the simulator source. Two independent
sources, one from FPS's own manual and one from FPS's own simulator, agreeing on the layout.

**The two sources number bits in OPPOSITE directions.** The manual puts `B` at bit **0** and `TMA`
at bits **62-63**; the `SPLIT`-derived table puts `DF` at bit **63** and `TMAF` at bits **0-1**.
Same layout, MSB-first versus LSB-first. Anyone comparing the two must flip, or every field appears
misplaced.

## What it ADDS beyond the recorded 24-field table

- **Table A-4, SPEC fields** — the sub-encodings selected when the S-Pad operation is `SPEC`:
  `STEST, HOSTPNL, SETPSA, PSEVEN, PSODD, PS, SETEXIT`, each with its own octal column. The note is
  explicit that **one SPEC field may be used per instruction word, and the S-Pad fields
  (D, SOP, SOP1, SH, SPS, SPD) are then disabled**.
- **Table A-5, I/O fields** — `LDREG, RDREG, INOUT, SENSE, FLAG, CONTROL`, likewise one per word,
  and **the floating-adder fields (FADD, FADD1, A1, A2) are then disabled**.
- The `VALUE` overlay: several entries are starred, meaning the instruction uses a **16-bit
  immediate in bits 48-63**, which disables `YW, FM, M1, M3, MI, MA, TMA, PDA`.

That last mechanism — a literal stealing the bottom quarter of the word and disabling eight fields —
is exactly the kind of thing an inferred layout cannot recover, and it is worth carrying into any
XP-32 layout reasoning as a *shape* the family uses.

## A discrepancy to resolve against `SIM100.FTN`

`CLAUDE.md` records the S-Pad operation codes as
`0 = single-op SPSF-dispatch, 2 = add, 3 = sub, 4 = mov, 5 = and, 6 = nor, 7 = xor`.
The manual's SOP column reads `0 = NOP, 1 = SPEC, 2 = ADD, 3 = SUB, 4 = MOV, 5 = AND, 6 = OR,
7 = EQV`.

Codes 2-5 agree. **Codes 6 and 7 do not**: the manual says `OR`/`EQV` where the recorded table says
`nor`/`xor` — and each pair is a complement (`EQV` is XNOR). Code 0/1 also differ in framing: the
manual has `NOP` at 0 and `SPEC` at 1, with the single-operand set living in the separate `SOP1`
column.

I have not resolved this. The manual is the primary source for the *architecture*; `SIM100.FTN` is
the primary source for what *this* simulator implements, and the two can legitimately differ if the
recorded table was read off the simulator's arithmetic rather than its mnemonics. **Check
`SUBROUTINE APSIM`'s S-Pad case for codes 6 and 7 before relying on either.** Flagged rather than
silently corrected, because the recovered AP-120B microcode was decoded with the existing table and
any change propagates into that work.

Note also the fine print in these tables is small; the octal columns above are read from a 1280-wide
scan and the structural claims are safe, but individual mnemonics in the denser columns
(SPEC/I/O) should be re-read at higher magnification before being quoted as exact.
