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
- **`notes/xltr_protocol.md`** — XLTR / AP-I-F command protocol decoded
  from the disassembly (`0x8004`/`0x8005` opcodes, `0x258..0x27D`
  command codes, panel-send-and-wait kernel at `F056BA`).
- **`notes/xp32_eu_command_protocol.md`** — inferred EU panel-command
  alphabet and three-register transaction protocol.
- **`notes/xp32_opcode_clues.md`** — XP-32 microinstruction format
  inferred from AP-120B (FPS-7319 manual) + FPS-164 (Touzeau 1984
  fig 2 + APSIM64 appendix A) + Curington 1986. The bit-level FPS-
  164 layout is now pinned; XP-32 is a structured widening of it.
- **`notes/xp32_microcode_format_inferred.md`** — older companion analysis
  focused on the AMD Am29116 sequencer side. Some claims here predate
  the Hockney fig 2.53 confirmation that the EU has a fixed PROM
  (not SRAM); the EU portion is pinned mask-PROM, the AU is the
  writable target.
- **`notes/fps_library_uniformity.md`** — how `VMUL`/`ZVMUL`/`DVMUL` are
  the same operation across AP-120B/FPS-100/FPS-3000-5000/FPS-164.
- **`notes/host_to_fps100_protocol.md`** — full host-side protocol:
  6 UNIBUS registers, 3 RSX event flags, RUNDMA function dispatch,
  recovered from the FPS-100 `DRIVER.MAC` source.
- **`hsr_decoded/`** — **217 routines, 21,066 microinstructions**
  of FPS-100 production microcode disassembled with full APAL-style
  output. See `hsr_decoded/README.md` and `hsr_decoded/CORPUS_ANALYSIS.md`.
- **`apo_decoded/`** — **313 routines, 11,469 microinstructions** of
  FPS-100 / AP-120B production microcode decoded from the bitsavers
  `*LIB.APO` files via `apo_decode.py`. Each routine emitted as
  APAL-style listing with octal addresses, hex bytes, and canonical
  SIM100 SPLIT field decode (24 fields per microinstruction). See
  `apo_decoded/README.md` and `notes/fps100_apo_format_spec.md`.
- **`apo_decode.py`** — from-scratch Python decoder for the FPS-100
  `.APO` (ASM100 object) text format. 180 lines, no dependencies.
  Format reverse-engineered from `LED100.FTN` source via
  Council-of-Clankers analysis.
- **`notes/fps100_dapex_annotated.md`** — Council-of-Clankers reference
  annotation of `DAPEX.MAC`, the FPS-100 host-side dispatcher
  library (the single chokepoint between user code and APDRV).
  100 KB.
- **`notes/fps100_callers_inventory.md`** — 32-file inventory of every
  source file in the FPS-100 archive that talks to APDRV, organized
  in 8 tiers (kernel driver → APEX → HSR stubs → toolchain → tests).
- **`notes/fps100_mac_files_audit.md`** — Council-of-Clankers analysis of
  all 12 host-side `.MAC` files in the FPS-100 archive (28K lines).
- **`notes/fps100_sim100_annotated.md`** — Council-of-Clankers reference
  annotation of `SIM100.FTN` (4910 lines, the canonical AP-120B
  simulator). 251 KB authoritative microarchitecture reference
  derived from the simulator source itself.
- **`notes/fps100_s_files_annotated.md`** — Council-of-Clankers analysis
  of all 36 AP-side supervisor `.S` files (7055 lines of APAL
  source for Super-100 / Mini-100 modes). 334 KB. Subsystem groups:
  kernel core, supervisor body, syssvc, I/O queue + RPC, RTC, boot
  + UPEX + tables, tests.
- **`apo_decoded/B_files/`** — 34 AP-side supervisor `.B` files
  decoded with `apo_decode.py` — same `.APO` format. 1,971
  microinstructions across 69 routines (KERNEL/SYSSVC/MINI/IOQUE/
  HIRP/HSVC/RTC/etc.). Combined with `apo_decoded/` math libraries:
  **382 routines, 13,440 microinstructions** of decoded AP-120B
  production microcode total.
- **`sim100_build/`** — working modern Linux build of SIM100 (the
  AP-120B simulator). Compiles cleanly with gfortran given
  `iutil_stubs.f`; runs to its interactive `*` prompt. Currently
  segfaults on input due to a documented COMMON-block size bug.
- **`notes/mc_tsk_analysis.md`** — Council-of-Clankers analysis of 7
  Bomem-customized RSX-11M task images (BOMICP/RSX11M/EXCOM/etc.).
- **`notes/cmd_files_inventory.md`** — inventory of all 42 `.CMD` files
  in both datasets, plus the HPVP-identity analysis from LOABOM.CMD.
- **`notes/fps100_multi_ap_support.md`** — does the FPS-100 driver support
  a slave/secondary FPS-100? Multi-AP yes (peers); master-slave no.
- **`RSX_v511/PDP11_DISASM_README.md`** — full PDP-11 disassembler
  for RSX-11M+ task images.
- **`notes/mc_results.md`** — Monte Carlo annotation pipeline results
  (15 rounds, 644 annotations on 576 unique addresses).
- **`notes/mc_xp32_debate_log.md`** — Council-of-Clankers debate on
  inferring the XP-32 microinstruction layout (4 rounds incl. strict
  bit-accounting verification).
- **`notes/mc_xp32_microcode_inference.md`** — three-round consensus
  inference producing the proposed 128-bit XP-32 layout
  (DeepSeek + GLM independent + cross-critique + synthesis).
- **`notes/mc_xp32_layout_stress.md`** — adversarial / cooperative /
  paranoid stress test of that consensus layout, with and without
  the assumption of a future EU PROM dump. 6 passes × 2 LLMs.
- **`notes/panel_codes_am29116_decoded.md`** — verified decoding of all
  21 panel command codes as Am29116 TOR1 SUBRC instructions
  (TORIA / TODRA operand patterns). Three live interpretations
  remain; EU PROM read or bus trace required to disambiguate.
- **`notes/fps164_chip_identification.md`** — sequencer-chip identification
  across the family. The Am29116 is **not** family-wide: only the
  FPS-3000 EXEC card carries one. FPS-164 used Schottky-TTL MSI;
  FPS-164/MAX uses ADSP-1401. No FPS-164 board photos exist online.
- **`notes/xpmlib_search_results.md`** — record of the search for an XPMLIB
  binary kernel as a layout-validation artifact. Result: no public
  XPMLIB exists. Pivot to the FPS-100 archive (11,469 AP-120B
  microinstructions, 9 .APO files + matching .APS source) as the
  ancestor-side validation corpus.
- **`notes/mc_doc_audit.md` / `notes/mc_doc_audit_triage.md`** — Council-of-
  Clankers audit of all curated docs followed by manual triage
  separating 9 verified findings (G1–G9) from 5 hallucinated
  citations (H1–H5). Lesson: LLM auditors fabricate plausible
  citations; treat findings as hypotheses, not verdicts.
- **`notes/mc_fps3k_pass2_summary.md`** — second MC pass on the disassembly
  with the updated context. 250 annotations, 99.6% YES, 77.2% BOTH-
  agreement (highest of any pass to date). Identified
  `ChannelConfigOffsetTable @ F046E0` (4 longwords of XLTR config
  offsets) — now in `fps3k_clean.asm`.
- **`notes/mc_fps3k_adversarial_focus.md`** — focused 3-stage adversarial
  pass on the 55 disagreed samples from pass 2. 100% revised — but
  the pattern was vague-vs-specific not wrong-vs-right; debate
  collapsed every disagreement to GLM's sharper formulation.
- **`notes/search_log_apal64_refs.md`** — negative-result search log for
  the APAL64 / XP-32 reference manuals (eBay/abebooks/bitsavers/
  Internet Archive).

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
        XP-32 AC1   XP-32 AC2  MEM CTL ─── SCM (5 banks)
        (ARITH+    (ARITH+
         EXEC)      EXEC)
              EU = fixed bipolar PROM (2K × 80-bit, mask)
              AU = writable control store (4K × 128-bit, 4 banks,
                   Am2168 SRAM, host-uploaded)
```

The CP/SBC is the integer/address/control brain. Each XP-32 AC has
its EU running fixed mask-PROM microcode at power-on, but its AU
**writable control store starts empty**. The whole point of this
ROM is to upload AU microcode from the host (via the AP I/F, in
S-record format) and arm the XP-32 to run it. Lovett's specific
chassis (model 821-9008-011, per the index plate photo) is
populated as a 2-AC configuration; the SBC firmware exposes 4
channels (`TCBXP1I..XP4I`) for the family's larger variants.

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
notable findings are in `notes/mc_results.md`.

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
