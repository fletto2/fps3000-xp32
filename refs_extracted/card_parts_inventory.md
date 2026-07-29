# FPS 3000 — per-card parts inventory

Read directly from the component-side photographs in `refs/cards/ (component-side photos; originals from Nakazoto/FloatingPointSystems)` (8 cards, 6000×4000,
≈650 DPI). Method: native-resolution 2000×2000 crops (3×2 grid per card) with CLAHE, markings
read by eye — OCR fails on this material (see the AT&T-610 PCB notes (external to this repo)).

**Coverage caveat:** this is a *representative* survey, not an exhaustive per-reference-designator
BOM. 1–2 crops per card were read (the CPU/identity regions); repeated array parts are counted
approximately. Board part numbers and all distinctive LSI are captured. All crops are retained
in `a scratch dir (not retained): <card>_r<row>c<col>.png` if a deeper pass is wanted.

---

## 01 — VBUS SBC  =  **Motorola M68KVM02** VERSAmodule monoboard computer
Board marks: `M68KVM02`, `01-W30908`, `© 1981 MOTOROLA INC`, `MOTOROLA microsystems`

| Part | Role | Qty |
|---|---|---|
| **MC68000L10** (purple ceramic/gold lid) | CPU | 1 |
| Crystals **32.000 MHz**, **20.000 MHz** (K1145AM/K1146AM) | clocks | 2 |
| EPROMs `51AW1940X14 U80`, `51AW4039B02 U81`, both **"VM02 1.0"** | firmware | 2 |
| **MSK4164AP-15** | 64K×1 DRAM | ~16+ (two banks, U15–U21, U29–U35 …) |
| **MC74F280N** | 9-bit parity generator | ≥2 |
| MC6888P / MC8T98P | bus driver | ≥1 |
| SP8552 / DM74LS244N, 74S373N ×4, 74S163N, 74S74N | glue | many |
| SN74LS273N, LS27N, LS00N, LS12N, LS151N, LS374N, LS11N, LS148N, LS32N, LS10N, LS373N, LS03N, LS09N, LS148N | TTL | many |
| VALOR **DM2584 50NS**, **DM2328 3×60NS**, DM2270 3×50NS, DM2587 250NS | delay lines | 4 |
| AMD EPROM (© 1983 AMD, ceramic window) | — | 2 |

**Note:** an AT&T-610-style route is open here — the VM02 firmware is a known Motorola product,
so its ROM contents/behaviour may be documented elsewhere.

---

## 02 — V-BUS XLTR (VERSAbus translator)
Board marks: `412-4803-001`, `PN 612-480…`

All discrete Schottky/LS TTL — **no LSI**:
`74S74N` · `SN74S175N` · `74S11N` · `74148N` · `74S138N` · `SN74S02N` · `SN74LS74AN` ·
`SN74S32N` · `SN74S132N` · `SN74S30N` · `74LS240N` · `SN74LS244N` · `74LS30N`

*This crop is partly out of focus on the left — lower confidence than the other cards.*

---

## 03 — UNIV FMT (universal formatter)
Board marks: `200-…-002`

| Part | Role | Qty |
|---|---|---|
| **MC74F153N** | 4:1 multiplexer | **many** (dominant part — banks down the board) |
| **AM29823DC** | 9-bit bus register | ≥4 |
| 74F157N, MC74F10N, 74F08N, 74S139N, 74F350, SN74LS240N | glue | many |

Architecture reads as a wide **multiplexer/shifter data formatter**.

---

## 04 — AP I/F (array-processor interface)
Board marks: `412-4448-401`

All Schottky TTL — **no LSI**:
`SN74S175N` · `SN74S02N` · `SN74S74N` · `SN74S51N` · `74S20N` · `74S00N` · `74S04N` ·
`74S169A` · `74S10N` · `74S64N` · `74S153N` · `74S374N` · `DM74S30N` · `74LS377N` ·
`74LS240N` · `SN74LS00N`
Several **SPARE** (unpopulated) positions.

---

## 05 — XP32 EXEC (execution/sequencer)
Board marks: `412-4805-002`

| Part | Role | Qty |
|---|---|---|
| **AM29116DCB** | **16-bit bipolar microprocessor** | 1 |
| **29F52 SDC** (Fujitsu) | microcode PROM | **many** (large banks) |
| **AM2168-45PCB** | 4K×4 SRAM | several |
| 74F175N, 74F109N, 74F74N, 74F245N, 74F374N, MC74F244NDS, MC74F138N, 74F08N, MC74F11N, MC74F00NDS, 74S38N, 74F86N, 74F32N, MC74F04N | glue | many |

Extensive **green wire-wrap rework** across this board.
The repo carries `Datasheets/amd-29116.pdf` — consistent with this being the XP32 sequencer.

---

## 06 — XP32 ARITH (arithmetic unit)
Board marks: `200-940A?-215`

| Part | Role | Qty |
|---|---|---|
| **AM29540DC** (ceramic, gold lid) | **FFT address generator / sequencer** | 1 |
| **AM29821DC** | 10-bit bus register | **many** |
| **AM2168-45PCB** | 4K×4 SRAM | **many** (large arrays) |
| **29F52 SDC** | PROM | many |
| **L29C520PC-R** (Logic Devices) | — | ≥6 |
| CY7C168-45PC | SRAM | some |
| 74F245N, 74F08N, 74F139N, 74F10N, 74LS240N, SN74S74N, SN74S86N, SN74S51N, MC74F04N, SN74LS157N | glue | many |
| DL14CB300 20933 | delay line | 1 |

3 × PGA sockets and 4 × ribbon headers (visible in the overview).

---

## 07 — MEM CTRL (memory controller)
Board marks: `412-4498-000`

| Part | Role | Qty |
|---|---|---|
| **AM29823DC** | 9-bit register | ≥1 |
| SN74LS244N, 74F374N, MC74F244ND, SN74LS163AN, SN74LS11N, SN74LS00N, SN74LS240N, SN74LS138N, 74AS20N | glue | many |

**Sparsely populated** — many positions silkscreened `SPARE` and left empty.

---

## 08 — MAIN DATA (main data memory)
Board marks: `412-4456-004`

| Part | Role | Qty |
|---|---|---|
| **MSM4256P-15** (OKI) | **256K×1 DRAM** | **very many** (full-board array, UA6…UF9+) |
| AMP `53137-1` | connector | 1 |
| AM25S07PP, 74AS139N, DM74AS30N, SN74AS74N, 74AS240N, 74F157N, 74F240N, SN74S32N, SN74S74N | glue | many |
| `PAGE SELECT` jumper block | — | 1 |

---

## Cross-card observations

* **Two processor families**: Motorola **68000** (VBUS SBC host) + AMD **29116/29540** bipolar
  bit-slice (XP32 array processor). The FPS 3000 is a 68000 host driving a custom AP.
* **Logic families track function**: host/glue = LS/S TTL; XP32 datapath = **74F** throughout
  (speed-critical), consistent with an array processor.
* **Memory**: MSK4164 (64K) on the SBC, **MSM4256 (256K)** on MAIN DATA, AM2168 SRAM as fast
  scratch in the XP32 pair.
* **Rework**: green wire mods on XP32 EXEC, UNIV FMT, MEM CTRL, V-BUS XLTR — a
  development/field-revised system.
* Card part numbers cluster as `412-4xxx-xxx` (FPS) with `200-xxxx` on two boards.

## Limitations
* Component side only — **no netlist is possible from this imagery** (see `README.md`).
* Quantities for array parts are estimates from the surveyed crops.
* Card 02's read is lower-confidence (focus).
* Reference designators (U-numbers) were not transcribed; the silkscreen carries them and a
  full pass could map part → designator using the `dip_detect2.py` + contact-sheet method.
