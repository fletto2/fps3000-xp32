# `pdp11_disasm.py` — PDP-11 disassembler for RSX-11M+ task images

Single-file Python disassembler for PDP-11 binaries, with light tooling
aimed at RSX-11M+ V5.1.1 `.TSK` task images.

## What it does

- **Full PDP-11 base ISA decoder**: single-op (CLR/COM/INC/.../JMP),
  double-op (MOV/CMP/ADD/SUB/...), branches (BR/BNE/.../SOB), JSR,
  RTS, EMT/TRAP, EIS (MUL/DIV/ASH/ASHC), MFPI/MTPI/MFPD/MTPD,
  MFPS/MTPS, all 8 addressing modes including PC-relative immediate
  (`#imm`) and absolute-via-PC (`@#abs`).
- **Recursive-descent disassembly** from a configurable entry point,
  with a linear-sweep fill afterwards so unreachable bytes still
  decode (as `.word`).
- **Code-region finder** (`--scan`): density-based scan over the whole
  file reporting offset / size / instruction-density of plausible-code
  windows. Sorts by size descending — the biggest high-density region
  is almost always the actual program text.
- **`--auto`**: shorthand for "run `--scan`, pick the longest run with
  density ≥ 0.7, disassemble from there".
- **Inline ASCII-string detection** (`--strings`, default on): runs of
  ≥4 consecutive printable bytes are emitted as `.ascii "..."`
  instead of garbage opcodes.

## Usage

```
# fully manual — you tell it where code starts and what virtual address
python3 pdp11_disasm.py --offset 0o2000 --base 0o1000 --entry 0o1000 TASK.TSK

# auto: scan the file and pick the biggest high-density region
python3 pdp11_disasm.py --auto TASK.TSK > TASK.asm

# scan-only: don't disassemble, just report candidate code regions
python3 pdp11_disasm.py --scan TASK.TSK
```

Output format (octal throughout, matches the FPS-3000 tool style):

```
001000: * 016746 000004           mov     4(pc), -(sp)
001006:   004767 000050           jsr     pc, 1062
001012:   012700 000005           mov     #5, r0
001016:   000241                  clc
```

The leading `*` flags addresses that are referenced from elsewhere
(branch targets, JSR call sites, etc.) — useful for spotting routine
entry points in the linear sweep.

## Limitations / known open questions

The runtime task header layout (where `H.IPC` lives so we can pick up
the entry point automatically) is defined by the `HDRDF$` macro in the
RSX-11M Executive Macro Library `EXEMC.MLB` — present in the extracted
files at `RSX01v511/001001/EXEMC.MLB` but it's a *binary* macro
library, so the exact byte offsets aren't textually readable from
here. The authoritative documented source is **DEC publication
AA-L680A-TC, RSX-11M/M-PLUS Task Builder Reference Manual**, which is
not on bitsavers as of this writing.

Until that's resolved, this tool does NOT auto-locate the entry point
— it relies on the `--scan`/`--auto` density heuristic. In practice
the `--auto` pick has been correct on the Bomem-customised RSX-11M+
disks we tested; the failure mode (data misread as code) is visible
as runs of `.word` fallbacks and unusual sequences (`wait`/`bpt`
where they shouldn't be).

## Verification of the decoder

The PDP-11 instruction decoder was sanity-checked on hand-assembled
test sequences:

```
0000 | c0 15 05 00    | mov      #5, r0       (012700 + 5)
0006 | 87 00          | rts      pc           (000207)
0014 | c4 15 42 00    | mov      #102, r4     (012704 + 0o102)
```

— all decode correctly. The decoder has no known wrong cases on
plain user-mode instructions.

## Testing on actual files

Quickest test: the `DCL.TSK` from `RSX07v511/001054/`. With `--auto`
this picks the largest code-dense region (file offset 0o245000,
~16 KB) and produces 25 K disassembled lines, of which 89% are real
instructions (the rest fall back to `.word`).

Smaller / driver-only tasks (e.g. `CODRV.TSK` at 1.5 KB) are mostly
zero-padding and produce small but meaningful output.

## Wishlist

- Proper `parse_tsk_header()` once the H.* offsets are known.
- Symbol-file (`.STB`) ingestion → name JSR targets and reference
  labels in the output.
- RSX directive identification: any `EMT 377` followed by a Directive
  Parameter Block (DPB) gets annotated with the directive name
  (`QIO$`, `EXIT$`, etc.) per the RSX-11M Executive Reference Manual.
- A `--func` label mode that emits `loc_<addr>:` markers above branch
  targets, like the FPS-3000 disassembler does.
