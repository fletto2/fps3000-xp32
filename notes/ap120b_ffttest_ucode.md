# AP-120B FFT/IFFT Identity-Test Microcode

A 227-instruction APAL microcode image for the **Floating Point Systems
AP-120B array processor**, recovered from the bitsavers PDF
`AP120B_fast_mem_ucode.pdf` (52-page printer listing, REV 1, August
197x).

**Files:**
- `ap120b_ffttest_ucode.bin` — 1816 bytes, 227 × 4 × 16-bit big-endian
  microinstructions, MD5 `94b5614d5bfc7d9b9f24c39eca9444a1`
- `ap120b_ffttest_ucode.txt` — annotated octal dump
- `ucode_transcribed.py` — source-of-truth Python dict, builds the above

To my knowledge this is the first publicly recovered binary FPS
microcode image from the AP-120B / FPS-5000 family.

## What this microcode does

`FIFFT` ("FFT Identity Test") is a self-contained verification program:
it floats an integer array, runs a forward complex FFT, runs an inverse
complex FFT, applies a shift+fix, and checks that the round-trip
reproduces the input. It exercises the full DSP pipeline of the AP-120B
(S-PAD ALU, FALU, FMUL, data-pad X/Y, memory-address unit) and is the
canonical bring-up test for an AP-120B installation.

## Module map

The PDF is twelve separately-assembled APAL modules; their entry points
are the symbol table at the bottom of the PDF cover sheet (p-01).

| Module   | Range           | Instrs | Purpose |
|----------|-----------------|-------:|---------|
| `FIFFT`  | `0o000..0o023`  |  20 | Top-level identity test driver |
| `VFLT`   | `0o024..0o036`  |  11 | Vector float (int → float) |
| `VSHFX`  | `0o037..0o047`  |   9 | Vector shift + fix (float → int) |
| `CFFT`   | `0o050..0o074`  |  21 | Complex FFT outer driver (calls FFT4 / FFT2) |
| `STSTAT` | `0o075..0o107`  |  11 | Set status / save state |
| `CLSTAT` | `0o110..0o112`  |   3 | Clear status |
| `ILOG2`  | `0o113..0o117`  |   5 | Integer log₂ (loop, returns log₂N in S-PAD 7) |
| `ADV4`   | `0o120..0o123`  |   4 | Pointer advance for radix-4 pass |
| `ADV2`   | `0o124..0o127`  |   4 | Pointer advance for radix-2 pass |
| `BITREV` | `0o130..0o203`  |  44 | Bit-reverse permutation (separate paths for ≥256 vs <256) |
| `FFT2`   | `0o204..0o223`  |  16 | Radix-2 FFT pass |
| `FFT4`   | `0o224..0o342`  |  79 | Radix-4 FFT pass (the heavy lifter; forward + inverse paths) |
| **Total**| `0o000..0o342`  | **227** | **1816 bytes** |

The linker resolves `$ENTRY` / `$EXT` references and concatenates these
modules into the address space above. `HIGH = 0o342`.

## Microinstruction format

Each instruction is **64 bits = four 16-bit words**, written
big-endian in the binary file. Each word controls a different
functional unit:

```
   w1 (high 16)  S-PAD ALU op + register fields
   w2            FALU (floating-point ALU) op
   w3            FMUL + memory-address unit + DPX/DPY-write ops
   w4            pipeline / branch / control bits
```

Multiple functional units fire in parallel each cycle — that's the
horizontal-microcode design from which the AP-120B gets its
performance.

### w4 control-bit fingerprints (observed)

| w4 value      | Meaning |
|---------------|---------|
| `0o000020`    | INCMA — increment memory address |
| `0o000040`    | SETM — set memory cycle |
| `0o000060`    | SETM + read latch |
| `0o000120`    | MI<FA — write FALU result back to memory input |
| `0o000160`    | FADD-style writeback |
| `0o000340`    | RETURN |
| `0o140xxx`    | end-of-loop / pipeline drain (FFT2 tail) |

### w2 FALU sign convention

`FADD` and `FSUBR` differ only by bit `0o100000` of w2. Forward and
inverse FFT paths in FFT4 are byte-identical except for this single bit
flip — confirmed across `IFOR↔INV` (0o262↔0o270) and `JFOR↔JNV`
(0o321↔0o327).

### Common encodings

- `JSR <target>` → `(011014, 000000, 000000, 177777)` — w4=`-1` is the
  link-time placeholder; the linker patches in the actual target.
  Eleven occurrences in `FIFFT` and `CFFT`.
- `RETURN` → w4=`0o000340` always; w1..w3 carry whatever parallel work
  finishes on the return cycle.
- `LDSPI <reg>; DB=<n>` (load S-PAD immediate) → w1≈`0o001660..0o001674`,
  the immediate value lands in w3/w4.
- `INCMA` (bare) → `(000000, 000000, 000000, 000020)` at 0o141.
- `DPX(<reg>)<MD` (data-pad X write from memory) → encoded in w3 as
  `0o045000 | reg`; e.g. `DPX(CR)<MD` with CR=4 → w3=`0o045004`.
- `MOVRR` vs `MOVR` (shift-by-2 vs shift-by-1) → w1 differs by bit
  `0o002000`. Visible in ADV4 (uses MOVRR, /4) vs ADV2 (uses MOVR, /2).

## Call graph

```
FIFFT (0o0)  ── identity-test driver
   ├── JSR VFLT      (int → float)
   ├── JSR CFFT      (forward FFT)
   ├── JSR CFFT      (inverse FFT)
   ├── JSR VSHFX     (float → int with shift)
   └── JSR ILOG2     (log₂N for loop count)

CFFT (0o50)  ── complex FFT
   ├── JSR STSTAT    (save status)
   ├── JSR BITREV    (bit-reverse permute)
   ├── loop:
   │     JSR FFT4    (radix-4 pass)  ─── most common
   │     JSR ADV4    (advance pointers ×4 / ÷4)
   │     ...
   │     JSR FFT2    (radix-2 pass)  ─── used when N is not a power of 4
   │     JSR ADV2    (advance pointers ×2 / ÷2)
   └── JSR CLSTAT    (clear status)
```

## S-PAD register map (from the per-module $EQU declarations)

These are the integer/address registers shared by FFT4, FFT2, BITREV,
ADV2, ADV4. Names that recur across modules:

| Register | Index | Use |
|----------|------:|-----|
| BASE     | 0     | base address of array |
| READ     | 3     | read pointer |
| WRITE    | 4     | write pointer |
| ICTR     | 5     | inner-loop counter (decrement) |
| TEMP     | 7     | scratch |
| N2       | 0o10  | N/2 (current butterfly stride) |
| W1..W3   | 0o11..0o13 | twiddle-factor pointers |
| WD       | 0o14  | twiddle delta |
| MDEL     | 0o15  | memory delta (stride) |
| ICOUNT   | 0o16  | inner-loop initial count |
| JCOUNT   | 0o17  | outer-loop counter (FFT4 only) |

Data-pad Y holds AR/AI (input complex), BR/BI/BRR/BRI/BIR/BII (twiddled
intermediates), DR/DI/DRR/DRI/DIR/DII (radix-4 corner products), CR/CI
(common subexpressions). Indices come from the FFT4 `$EQU` block.

## Errata

The original printer listing has one **handwritten correction**, faithfully
applied in the binary:

| Linked addr | Module | Field | Listing | Corrected | Mnemonic |
|------------:|--------|-------|--------:|----------:|----------|
| `0o127`     | ADV2   | w1    | `047670` | `045670`  | `MOVR ICOUNT,ICOUNT;RETURN` |

The handwritten "45670" overstrikes the printed "47670" — bit `0o002000`
flipped to make it match the parallel `MOVR` opcode used elsewhere in
the module.

## Reproducing

```bash
cd /home/fletto/ext/src/claude/fps3000
python3 ucode_transcribed.py
# → emits ap120b_ffttest_ucode.bin and ap120b_ffttest_ucode.txt
```

The Python source is the canonical form: each entry is one
microinstruction with a brief mnemonic comment. To audit any
particular instruction, the tile-grid PNGs at
`/tmp/ucode_ocr/split/p-{02..47}-r{0..2}c{0..2}.png` are the original
high-DPI page renderings used for the vision-based transcription.

## How transcription was done

Tesseract and EasyOCR both choked on the dot-matrix font (15-25%
per-token error rate even with preprocessing). The PDF was rasterised
at 400 DPI to PNG (5798×4399), each page tiled into a 3×3 grid of
1933×1466 sub-images (under the vision-input dimension cap), and each
addr+word column transcribed by hand from the rendered tiles.

A grammar consistency pass cross-checked every transcription:

- All 908 words within 16-bit range ✓
- 11× exact repetition of the canonical JSR pattern ✓
- IFOR/INV and JFOR/JNV pairs differ only in the FALU sign bit ✓
- ADV4/ADV2 differ only in the ADD↔MOV opcode bit (entries 0,2) and
  the shift-count bit (entry 1); entry 3 is byte-identical (shared
  RETURN) ✓

## References

- `AP120B_fast_mem_ucode.pdf` — the source listing
  (bitsavers / `~/src/claude/versabus/refs/`)
- AP-120B Processor Handbook (Floating Point Systems, 1976) — the
  microinstruction-format reference
- `~/src/claude/fps3000/CLAUDE.md` — system architecture context (this
  microcode is what the FPS-3000 CP firmware uploads to the XP32 EXEC
  card's writable control store via the panel/XLTR interface)
