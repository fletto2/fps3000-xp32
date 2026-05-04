# FPS-3000 / XP32 Research

Reverse-engineering notes, disassembly, and recovered software for the
**Floating Point Systems FPS-3000** array processor — an FPS-5000-class
machine from the same family as the AP-120B, FPS-100, FPS-164, and
FPS-5320A.

This repo grew out of the **Usagi Electric / David Lovett** Bomem DA3
FTIR + PDP-11 + FPS revival work, and the broader effort to recover
information about FPS hardware before it disappears entirely.

> **FPS = Floating Point Systems Inc.** (Beaverton, OR; founded 1970).
> *Not* "Fire Protection System" — earlier guesses got the name wrong
> and labelled all the I/O accordingly.

## What's in here

### `FPS3K_U11_U12_JOIN.bin`
The 64 KB SBC (Control Processor) firmware ROM, byte-identical to
`FPS3K_combined.bin` previously circulated. Maps to `0xF00000` on a
Motorola **M68KVM02-3** VERSAmodule monoboard (MC68000 @ 8 MHz).

### Disassembly
- **`fps3k_clean.asm`** — *the readable one*. ~22 k lines with:
  - meaningful labels (`TCBRDHC`, `PanelSendAndWait`, `SRecordParseLoop`, …)
  - hex addresses preserved as a leading column
  - XLTR register accesses resolved (`$202(a0)` → `[XLTR_MODE1]`)
  - panel-command-code immediates named (`#$26C, d0` → `; PCMD_RELEASE`)
  - SBC-RAM globals named (`$E58.l` → `; g__srec_addr`)
  - Monte-Carlo-derived annotations as `;>>>>` lines above their target
- **`fps3k_custom.asm`** — raw 68000 disasm (recursive-descent +
  iterative convergence + RMS68K TRAP-skip heuristic).
- **`fps3k_custom_annotated.asm`** — raw + MC annotations, intermediate.

### Documentation
- **`architecture.md`** — system-level writeup: VersaBUS chassis,
  XLTR/AP-I-F register block, RMS68K marker inventory, panel-command
  protocol, S-record upload path.
- **`xltr_protocol.md`** — XLTR / AP-I-F command protocol decoded
  from the disassembly (`0x8004`/`0x8005` opcodes, `0x258..0x27D`
  command codes, panel-send-and-wait kernel at `F056BA`).
- **`xp32_microcode_format_inferred.md`** — what we can infer about
  the XP32 control-store layout from the AMD Am29116 sequencer
  identification on the EXEC card and the upload mechanism.
- **`xp32_opcode_clues.md`** — synthesis of MAXL / APAL / APMATH64
  microinstruction-format evolution across the FPS family.
- **`mc_results.md`** — Monte Carlo annotation pipeline results
  (15 rounds, 644 annotations on 576 unique addresses).

### AP-120B FFT/IFFT identity-test microcode
A 52-page assembly listing was vision-transcribed to a binary image:
- **`ap120b_ffttest_ucode.bin`** — 1,816 bytes, 227 instructions × 4 ×
  16-bit words, full coverage `0o0..0o342`. To my knowledge the first
  publicly recovered binary FPS microcode image.
- `ap120b_ffttest_ucode.{txt,md,gaps}` — human-readable form +
  transcription methodology.

This microcode is for the **AP-120B/FPS-100**, *not* the XP32 — the
two have different microinstruction widths (64 vs 128 bit) and float
formats (FPS proprietary 38-bit vs IEEE-754 32-bit). It's useful as
ground truth for the AP-120B microinstruction format and as a starting
point for understanding the family's microarchitecture.

### Bomem-customized RSX-11M+ V5.1.1 disks (`RSX_v511/`)
15 RX02 floppy images and 462 extracted files — the
PDP-11 host operating system distribution that originally shipped with
the Bomem DA3 FTIR + FPS-100 array processor. Notable files:
- `Boot{1..3}v511/001054/BOMICP.TSK` — Bomem's 17 KB ICP
- `Boot4v511/001054/LOABOM.CMD` — installer (references `loahpvp` for
  the array processor)
- `RSX05v511/001002/STARTUPIN.CMD` — RSXBOM startup script
  ("Programmer: Claude Lafond")

Includes a from-scratch **Files-11 ODS-1 reader/extractor** that
handles RX02 2:1 interleave (skew 6, track 0 reserved). Note: the
extractor scripts (`*.py`) are not committed to this repo to keep it
focused on the recovered artifacts.

> The actual Bomem application disks (BOM1..BOM13, TASK, HELP, MENU)
> are **missing** from this set — `LOABOM.CMD` references their files
> (`bomres`, `clk50`, `grafik`, `hpvp`, `phk`, `traduit`, `IV2DRV.MAC`,
> `MGDRV2.MAC`, `BOMRES.STB`, …) but they aren't in this dataset. If
> you have copies, please get in touch.

## System architecture (CP side)

```
                     VersaBUS SBC                    ← THIS ROM runs here
                          │                              (M68KVM02 board)
                ──────────┴─────────── VersaBUS (16-bit)
                  │                  │
            VersaBUS XLTR        AP I/F ──► Host computer
                  │                              (PDP-11/VAX/IBM)
              UNIV FMT
                  │
                ──┴───────────────────  XP32 BUS (32-bit IEEE-754)
                  │            │            │
            XP32 ARITH      MEM CTRL    MAIN DATA
                 │
            XP32 EXEC
              (Am29116 16-bit + Am2168 SRAM WCS + PALs)
```

The CP/SBC is the integer/address/control brain. The XP32 ARITH+EXEC
cards are bit-slice floating-point coprocessors that **do nothing
without microcode loaded into their writable control store**. The
whole point of this ROM is to upload that microcode from the host (via
the AP I/F, in S-record format) and arm the XP32 to run it.

### Microcode upload path
```
Host computer
    │ S-records over the AP I/F (S0/S1/S2/S3/S8/S9)
    ▼
TCBRDHC main loop                              [F046F0]
    │ panel commands dispatch SLC parser
    ▼
SRecordDataHandler                             [F051A2]
    │ enforces 0x10000 ≤ addr ≤ 0x1FFFF
    ▼
SBC RAM 0x10000–0x1FFFF       ← 64 KB staging buffer = one WCS bank
    │ host issues panel command sequence:
    │   select-channel → set-address → set-count →
    │   set-transfer-mode → write-memory → arm DMA
    ▼
PanelIOCommand processor                       [F05688+]
    │ writes XLTR control regs at 0xFF0200+
    ▼
VersaBUS XLTR  →  UNIV FMT  →  XP32 BUS
    │
    ▼
target XP32 control-store write port
```

## Methodology

The disassembly was annotated using a Monte-Carlo cross-validation
approach: a **Council of Clankers** (multiple independent code-
analysis agents) was asked, per round, to identify the specific
purpose of randomly-sampled instructions, given a hardware-context
prompt. Annotations were accepted only when at least one Clanker
gave a specific, keyword-rich answer with no contradiction.

15 rounds of 40-50 samples each across cooperative and adversarial
modes produced **644 annotations on 576 unique addresses** (~9% of
the 6,485 custom-code instructions). Round-by-round details and
notable findings are in `mc_results.md`.

## References

The repository does **not** vendor third-party documentation — the
PDFs and external software archives are mirrored locally but
gitignored. Public sources used:

- Hockney & Jesshope, *Parallel Computers 2: Architecture, Programming
  and Algorithms*, §2.5 (FPS-5000 architecture)
- Curington & Tracy 1984, *Performance Estimation Methods for XP32 MAXL*
- Bitsavers FPS-100/AP-120B/FPS-164 software & manual archives
- Nakazoto / Usagi Electric FPS-3000 board photos:
  https://github.com/Nakazoto/FloatingPointSystems
- VCFed FPS-100 thread:
  https://forum.vcfed.org/index.php?threads/floating-point-systems-fps-100-found.1254035/

## License

Original analysis, documentation, and tooling: MIT. Files derived
from FPS / Bomem / DEC binaries retain whatever rights their
respective owners hold; included here on a fair-use research /
preservation basis. If you are a rights holder and would like
something removed, please open an issue.
