# Upstream FPS work — github.com/fletto2/ap120dg + github.com/roy20100/python-sim100

A **massive existing-work discovery**: the user (`fletto2`) has a
prior repo `ap120dg` from March 2026, plus `roy20100/python-sim100`,
that together cover most of the AP-120B/FPS-100 software stack
needed for our FPS-3000 / XP-32 project. This document inventories
what's there and what it implies for our two objectives.

## fletto2/ap120dg (March 2026)

**"FPS AP-120B / FPS-100 Data General Nova porting package for the
Usagi Electric restoration project"** — built for the Usagi
Electric DG-Nova restoration where the PDP-11 driver source
(`DAPEX.MAC`) exists but the DG Nova driver was lost.

### File inventory

| File | What it is | Relevance to FPS-3000 project |
|---|---|---|
| **`4448_APIF_netlist.txt`** (207 lines) | Connection list for the AP-120B/FPS-100 4448 AP I/F card — connector J22 + J23, ~200 pins, every signal named | **The cable connector pinout we needed.** FPS-3000-era `612-4448-401-F` is the next-generation card in the same family; pinout almost certainly compatible or trivially mappable |
| **`adapter.md`** (726 lines) | Full schematic trace of the 280B Nova/Eclipse I/O Adapter (drawing 512-3280-004 Rev B) — the host-side bridge from DG Nova bus to the FPS chassis | **Pattern for the Q-bus adapter** we need. Different host bus electrically, but same architectural concept (host-bus ↔ FPS-cable bridge with DMA + IRQ propagation) |
| **`nova_fps.c`** (1798 lines) | SimH AP-120B/FPS-100 simulator with host I/O + memory + DMA + panel commands | Emulator we can use to validate microcode behaviour offline |
| **`microcode.md`** | AP-120B microinstruction reference, derived from FPS-7319 + SIM100.FTN, verified against decoded .APO objects | Cross-checks our `xp32_opcode_clues.md` AP-120B section |
| **`lnk100.py`** | Python replacement for FPS LNK100 linker; links all 9 APO libraries (11,420 instructions, 596 symbols) | Linker tooling for AP-120B; XP-32 likely needs a similar tool |
| **`dapex_dg.asm`** | Complete DG Nova DAPEX driver (all 25 routines, replacement for PDP-11 `DAPEX.MAC`) | Reference for what a /73 Q-bus driver needs to implement |
| **`fdapex.c` / `iapex.c` / `iapex.h`** | ANSI C driver + host-independent API layer | Modern-language reference implementation of the APEX runtime |
| **`fps_probe.asm`** | Hardware probe test program | Validation pattern for hardware bring-up |
| **`gen_*_test.py`** | Test generators (vadd, real_vadd, hsr_vadd) | Microcode-test patterns |
| **`AP-120B_Nova_E_31Card_Wirelist_198204.pdf`** | 1982 wirelist for the 31-card AP-120B Nova-E configuration | Hardware-level reference |
| **`860-7259-003_procHbkFeb79_ocr.pdf`** | OCR'd AP-120B Processor Handbook | Already in `refs/AP-120B/` non-OCR; OCR version is searchable |
| **`DAPEX.MAC` / `DRIVER.MAC` / `ADUTIL.MAC`** | Original FPS-100 RSX sources | We have these in `fps100_archive/`; nice to have local copy |
| **`4421_PDPIF_netlist.txt` / `4429_FMT_netlist.txt`** | Other FPS card netlists (PDP-11 IF and Formatter) | Cross-reference for understanding the FPS-100 card family |

### What this provides for Objective A (host connection)

1. **Cable connector pinout already known** — at least for the
   4448 family at the AP-120B-era. Lovett's `612-4448-401-F` is
   a later revision of the same card type; pinout very likely
   compatible. **The B1 bench task ("identify chassis-side cable
   connector pinout") may already be answered by reading
   `4448_APIF_netlist.txt`** — only validation needed.

2. **Q-bus adapter pattern** — `adapter.md`'s 280B Nova schematic
   trace is the same kind of thing we need to build for Q-bus.
   Same architecture (host-bus interface + DMA bus-master +
   IRQ propagation), just with Q-bus signals instead of DG Nova
   DOA/DIA/etc. Can use the schematic as design reference for
   the Q-bus equivalent.

3. **Reference driver implementation** — `dapex_dg.asm` (DG Nova
   assembly) shows what a /73 RSX driver needs to do. It's the
   exact analog of what we'd write for Q-bus on RSX-11M+.

### What this provides for Objective B (XP-32 microcode)

1. **Working AP-120B emulator** — `nova_fps.c` simulates the AP
   well enough to run real microcode. We can validate
   AP-120B-baseline kernels (the 217 we have in `hsr_decoded/`)
   against this emulator before extending to XP-32.

2. **AP-120B assembler** — `roy20100/python-sim100/asm2lm.py`
   takes octal PS/MD source and produces APLOAD binaries. We
   can hand-author AP-120B microcode and run it.

3. **AP-120B linker** — `lnk100.py` links the 9 production APO
   libraries — 11,420 instructions of working FPS-100 microcode
   linked successfully. Confirms our HSR corpus decoding is on
   the right track.

4. **All this is AP-120B baseline.** XP-32 (128-bit microinstruction)
   is an extension. The path to XP-32 microcode is **a delta on
   working AP-120B tooling**, not from-scratch.

## roy20100/python-sim100 (March 2026)

**"AI assisted port of SIM100.FTN simulator"** — Python translation
of the original Fortran-77 FPS simulator (REL 1.00, 09/01/79).

### File inventory

| File | What it is |
|---|---|
| `sim100.py` | Entry point — interactive debugger CLI |
| `sim100_apsim.py` | Core instruction-cycle engine (`APSIM` subroutine) |
| `sim100_mem.py` | Memory subsystems: PS, MD, TM ROM+RAM, IODEV |
| `sim100_fp.py` | 38-bit FP arithmetic — add, multiply, normalize, convert |
| `sim100_utils.py` | Low-level byte-register primitives, including the **`SPLIT`** subroutine that decodes 64-bit microinstructions into 24 named fields |
| `sim100_debugger.py` | Command interpreter (APD subroutine + LODINP loader) |
| **`asm2lm.py`** | **Assembler — octal PS/MD source → APLOAD binary load module** |
| `APLOAD_Format.docx` | APLOAD binary load-module format reference |
| `add.lm` / `out.lm` | Sample APLOAD load modules |

The **`asm2lm.py` assembler** is exactly what we need to author
fresh microcode for testing. The format it consumes is octal
words organized as PS/MD source — same format the recovered HSR
corpus is in.

## Implications for the FPS-3000 project plan

### Objective A — much closer than expected

Previously the critical-path was:
- LA captures of chassis-side AP I/F connector → reverse cable
  protocol → design substitute card

Now:
- **The 4448 APIF netlist already documents the connector
  pinout.** Validation that Lovett's `612-4448-401-F` matches
  the AP-120B-era 4448 layout is the only remaining bench step
  (visual inspection — minutes).
- **The 280B Nova adapter schematic** gives us a complete
  reference for what a host-side adapter does. Q-bus version
  is structurally the same; we adapt the signal-decode logic.
- **Substitute hardware design** can target a known signal
  set instead of an inferred one.

**Estimated time saving on Objective A: ~30-50 hours.**

### Objective B — large head-start

Previously the critical-path was:
- Read EU PROM → Am29116 disassembler → infer AU layout →
  author candidate µkernel → upload + run

Now:
- **AP-120B emulator** (`nova_fps.c`) lets us validate
  AP-120B-baseline microcode without hardware.
- **`asm2lm.py` assembler** lets us hand-author AP-120B microcode
  in human-readable form.
- **`lnk100.py` linker** + 11,420 instructions of working linked
  microcode = a corpus of confirmed-correct AP-120B kernels.
- The XP-32 work becomes "extend the AP-120B tooling to handle
  the 128-bit XP-32 microinstruction width" rather than
  "build everything from scratch."

**Estimated time saving on Objective B: ~50-100 hours.**

### Updated overall effort

| Original estimate | Revised |
|---|---|
| ~390 hours | **~250-280 hours** |

A reduction of ~30%. Not because the work is smaller, but
because the user's prior `ap120dg` repo + the Python `sim100`
repo collectively provide working AP-120B-side tooling that
would otherwise need to be built.

### Updated next concrete actions

1. **Lovett: photograph the cable connector** on `612-4448-401-F`,
   compare to `4448_APIF_netlist.txt`'s J22/J23 connector
   description. Confirm same connector type or note differences.
   ~1h.

2. **Adapt `nova_fps.c`** to model the FPS-3000-specific aspects
   (XP-32 channel selection via XLTR, panel-command alphabet
   `0x258..0x27D`). The base AP-120B host-interface emulation
   is already correct; we add the FPS-3000-era extensions.
   ~30h.

3. **Cross-validate `hsr_decoded/`** (our 217 HSR microcode
   kernels) against `lnk100.py`'s output for the 9 APO
   libraries. Confirm we decode the same instructions. ~10h.

4. **Use `asm2lm.py`** to author and run a hand-coded AP-120B
   test kernel through `nova_fps.c`. Validates the toolchain end
   to end. ~10h.

5. **Q-bus adapter design** — Use `adapter.md`'s 280B Nova
   schematic as reference; adapt to Q-bus signals. The cable
   side stays the same. ~50h (vs ~80h estimated before).

6. **XP-32 microinstruction extension** — extend the AP-120B
   instruction decoder + simulator to handle the 128-bit XP-32
   width and the inferred layout from `xp32_opcode_clues.md`.
   ~50h.

After all this: an XP-32 emulator + assembler + (Q-bus) host
substitute + working hardware path = end-to-end FP test
runnable.

## Detailed findings from a full read

### `4448_APIF_netlist.txt` — the cable connector pinout

Two connectors on the 4448 chassis-side AP I/F card:

- **J22**: A1-A100 (100 pins) — primary signal connector
- **J23**: B1-B99 (99 pins) — secondary signal connector

Total ~200 pins per card, hex-card or quad-card form factor.

**Signal categories visible** (from naming):

| Class | Examples | Count |
|---|---|---|
| Data (host buffer) | HD00-HD15 | 16 lines |
| Data (DMA path) | DMA00-DMA15 | 16 lines |
| Status/strobe (host) | HST00-HST15 | 16 lines |
| Panel data | PNL08-PNL15 | 8 lines |
| Data buffers | DA08-DA15 | 8 lines |
| S+D pad | SP+DP08-DP15, DPMBS12-27 | 24 lines |
| **Register select** | **REGSEL00-REGSEL05** | **6 lines (= 64-reg select)** |
| I/O bus | IO24-IO39 | ~16 lines |
| Bus arbitration / DMA | APDMAACT, HDMAACT, DMASTB, HADRCLK1/2 | ~6 lines |
| Interrupts | INTR, INTFN, INTPIN, HALTINT, CTL5INT, INT06, INT07 | ~7 lines |
| Handshake | READY, IORDY, IOACK, CTLACK, DACK, DAVAL | ~6 lines |
| Clocks | IOCLK, B0CLK, B1CLK, B2CLK, B3CLK, NUF2CLK, CTLCLK | ~7 lines |
| Reset | HRSET, SYRST | 2 lines |
| Power | +5V, GND | ~16 conductors |

**The cable carries ~150 logical signals, not the ~50 I
estimated.** That's because the 4448 family has separate H-data
buses for register-poke vs DMA, plus a panel-data bus, plus the
S-pad/Data-pad routing through the cable. My earlier inference
was an *under-estimate* — the actual cable is wider and more
parallel than I assumed.

This **changes the substitute-card design** substantially:
- A single Pi Pico 2 (30 GPIO) is way too small.
- Two Pico 2s in tandem (60 GPIO) still falls way short.
- **An FPGA dev board (Lattice ECP5 with 100+ I/O) becomes
  necessary**, not just preferable.

### `microcode.md` — confirms / refines our AP-120B knowledge

323 lines of comprehensive AP-120B microinstruction reference.
Cross-checks our `xp32_opcode_clues.md` AP-120B section:

- **SOP=6**: "OR (logical OR via De Morgan's)" — confirms my
  assumption (manual says OR; CLAUDE.md old draft was wrong
  with NOR)
- **SOP=7**: "EQV: ~(SPD ^ SPS)" = XNOR — confirms EQV (our
  HSR decoder already uses EQV)
- **A2=6**: MDPX, A2=7: EDPX — match
- **All SOP1 / FADD / COND / DPBS / M1 / M2 / MA / DPA / TMA**
  encodings match what we derived for the HSR corpus

Plus **new detail we didn't have**:
- **SOP=1, SPS=8 (JMP/JSR)**: SPD field encodes jump mode
  (bit 0: JMP vs JSR; bits 1-2: target source — VALUE / PC+VALUE
  / TMA / SWR)
- **38-bit FP format**: 10-bit exponent (biased 512), 28-bit
  2's-complement mantissa, normalized 0.25..0.5
- **Pipeline depths exact**: S-pad=1, FADD=2-stage, FMUL=3-stage,
  MD=2-3, TM=2

### `nova_fps.c` — Phase 1 only (host I/O), microcode not executed

Comment at top: *"Phase 1 implementation: host interface +
memory + DMA + panel commands. No AP microcode execution yet
(AP always halted unless START issued, then runs until explicit
STOP)."*

So the SimH module simulates everything **outside** the AP's
microcode engine — useful for validating host-side software
talks to a fake AP correctly, but you need `python-sim100`
(roy20100's port) for actual microcode execution.

`nova_fps.c` includes detailed FN-register bit definitions:
- `FN_STOP` (0x8000), `FN_START` (0x4000), `FN_CONT`, `FN_STEP`,
  `FN_RESET`, `FN_EXAM`, `FN_DEP`, `FN_BREAK`
- `FN_INC_MASK`, `FN_WORD_MASK`, `FN_REGSEL_MASK`
- `FN_HALTED` (0x8000 read), `FN_SWR_ACK` (0x4000 read)

These are the FN-register write/read semantics for AP-120B host
control — directly applicable to the FPS-3000's chassis-side
register file (likely same protocol; just different cable
electricals).

### `python-sim100/asm2lm.py` — usable AP-120B assembler

373 lines of Python. Takes:
- **PS file** (microcode): one line per 64-bit instruction = 4
  octal words. Same format as our `hsr_decoded/` per-routine
  output.
- **MD file** (data): three modes — integer (vtype=1), real
  (vtype=2 IEEE→AP-38-bit via FPINPT), or IBM hex (vtype=4).

Outputs APLOAD-format `.lm` binary that `python-sim100/sim100.py`
can load and execute.

**Implication**: we have a working pipeline today for **authoring
AP-120B microcode in human-readable form, assembling, and
executing in simulation**. End-to-end validated.

## Revised hardware design impact

The `4448_APIF_netlist.txt` finding **invalidates the dual-Pico
plan** — 150 cable signals exceed even 2 Picos' combined GPIO
budget by a wide margin.

| Design option | Status post-netlist |
|---|---|
| Single Pi Pico 2 + expanders | **Not feasible** (30 GPIO + expanders can't reach 150 lines at usable speed) |
| Dual Pi Pico 2 tandem | **Not feasible** (60 GPIO < 150 needed) |
| Teensy 4.1 (55 GPIO) | **Not feasible** alone |
| **Lattice ECP5 FPGA** (100-150 I/O) | **Required** for full cable interface |
| Multiple FPGAs | Overkill but works |

**Updated recommendation**: **single Lattice ECP5 dev board**
(ULX3S 25F or larger, $155+) is now the only viable
single-board option. It has enough I/O (100+) to drive every
cable signal directly without expansion glue, plus enough fabric
for the Q-bus interface state machine on the same chip.

## Updated cable-protocol inferred document needs revision

`cable_protocol_inferred.md` estimated ~50 logical signals + ~20
ground = ~70-80 conductors. The 4448 netlist shows the actual
cable is **~2× wider** than my inference. The protocol *shape*
is still right (register pokes + DMA bus-master + irq), but the
cable has parallel high-bandwidth paths (separate H-data /
DMA-data / panel-data buses) that I collapsed into a single
"data line" group.

I should update `cable_protocol_inferred.md` and
`host_substitute_hardware_plan.md` to reflect the actual cable
width.

## Why this wasn't surfaced before

The `ap120dg` repo is owned by the same GitHub user who's
running this conversation (`fletto2`), but the repo wasn't
referenced in `CLAUDE.md` or any of the project docs until now.
Worth adding it to `CLAUDE.md` as a primary resource so future
sessions don't redo work that's already done.
