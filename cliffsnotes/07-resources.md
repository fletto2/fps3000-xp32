# 07 — Resources: what we have, what's missing

## Recovered ✓

### FPS-100 software archive (Al Kossow's tape recovery)

`fps100_archive/fps100sw/[327,010]*` — 183 files extracted from
`fps100sw.zip` (originally `fps100flxDamaged.tap` on bitsavers).

| File group | Count | Bytes | Purpose |
|---|---:|---:|---|
| `*LIB.APO` (BAA, BAB, AML, IPR, SIG, UTL, APF, DGN, SYM) | 9 | 494,580 | **62,130 AP-120B microinstructions** |
| `*SRC.APS` | 9 | — | matching APAL assembly source with comments + revision history |
| `ASM100.FTN` / `LED100.FTN` / `SIM100.FTN` / `DBG100.FTN` | 4 | — | toolchain (assembler, linker, simulator, debugger) |
| `KERNEL.{B,S}`, `IOQUE.{B,S}`, `HSVC.{B,S}` | 6 | — | host-side OS pieces |
| `INSTAL.TXT` | 1 | 162 KB | installation manual |

This is the **most useful single resource** in the project for
validating the AP-120B layout and the layout-evolution chain. See
[`xpmlib_search_results.md`](../xpmlib_search_results.md).

### AP-120B FFT/IFFT identity-test microcode

Vision-transcribed from a 52-page PDF listing in `AP120B_fast_mem_ucode.pdf`:

- 1,816 bytes binary microcode (`ap120b_ffttest_ucode.bin`,
  MD5 `94b5614d5bfc7d9b9f24c39eca9444a1`)
- 227 instructions × 4 × 16-bit words, full coverage `0o0..0o342`
- Modules: FIFFT, VFLT, VSHFX, CFFT, STSTAT/CLSTAT/ILOG2, ADV4/ADV2,
  BITREV, FFT2, FFT4

**To my knowledge the first publicly recovered binary FPS microcode image.**
See [`ap120b_ffttest_ucode.md`](../ap120b_ffttest_ucode.md).

### Bomem-customized RSX-11M+ V5.1.1 disks

`RSX_v511/` — 15 RX02 floppy images (4 boot + 11 OS distribution)
extracted with a from-scratch Files-11 ODS-1 reader. 462 entries,
6.2 MB total. Bomem-tagged files: `BOMICP.TSK`, `LOABOM.CMD`,
`STARTUPIN.CMD`, the `BOMEM` user account.

⚠️ **Missing**: the actual Bomem application disks (BOM1..BOM13,
TASK, HELP, MENU). LOABOM.CMD references their files but they
aren't in the dataset.

## Reference documentation ✓

`refs/` (mirrored from bitsavers + `~/src/claude/versabus/`):

| Family | Highlights |
|---|---|
| **AP-120B** | FPS-7319 Programmer's Reference (canonical bit fields), AP-120B Processor Handbook, Math Library reference, APDBUG manual, FPS-7350 IOP manual |
| **FPS-5000** | Hockney chapter, 4× Curington papers (incl. unpublished Symbolic Execution paper), FPS-5000 ad |
| **FPS-164** | APMATH64/MAX manual vols 2/3/4 (vol 1 missing!), APSIM64+APDEBUG64, training notes, IBM CMS front-end manual, brochure, Charlesworth IEEE Micro 1986 |
| **FPS-3000** | Board photos only — no docs ever published |
| **General** | FPS Board Revision List (12 MB!), FPS Pricing 1984, brochures |

## Missing ✗

| Artifact | Status | Realistic path to recovery |
|---|---|---|
| **XPMLIB binary** | No public copy anywhere | Contact Myron White (FPS-100 lead designer); FPS-5000 customer sites (LANL/NCAR/USGS); CHM Cray archives |
| **EU PROM contents** | Never read | Desolder + read on Lovett's chassis (risky) |
| **Host-side AP I/F card** | Missing from chassis | Build FPGA substitute (ECP5 recommended) |
| **APMATH64/MAX manual Vol 1** | Not on bitsavers | Asking the community |
| **APAL64 reference manual** | Never publicly archived | Long shot — see [`search_log_apal64_refs.md`](../search_log_apal64_refs.md) |
| **Bomem application disks (BOM1..BOM13)** | Lost | Contact Bomem retirees / Claude Lafond if findable |
| **`LNK100` / `LOD100`** | Tape damage on bitsavers FPS-100 archive | `LED100` (present) may be their replacement |
| **FPS-164 board photos** | No public archive has any | Ask CHM (has at least one FPS-164 in collection) |

## Toolchain (in the repo)

| Tool | Purpose |
|---|---|
| `disasm.py` | Recursive-descent + iterative MC68000 disassembler |
| `build_clean_disasm.py` | Generates `fps3k_clean.asm` from raw + annotations |
| `mc_fps3k.py` | MC annotation runner (cooperative + adversarial modes) |
| `mc_xp32_microcode_inference.py` | Layout consensus via 2-LLM Council |
| `mc_xp32_layout_stress.py` | Adversarial / cooperative / paranoid stress |
| `mc_doc_audit.py` | Council audit of all curated docs |
| `mc_fps3k_adversarial_focus.py` | 3-stage debate on disagreed samples |
| `RSX_v511/ods1.py` | Files-11 ODS-1 reader for RX02 floppies |
| `ucode_transcribed.py` | AP-120B microcode source-of-truth |

(Most `mc_*.py` are gitignored — they regenerate from project state.)

## Where to read more

- [`README.md`](../README.md) — full file inventory
- [`upstream_repos.md`](../upstream_repos.md) — fletto2/ap120dg + roy20100/python-sim100
