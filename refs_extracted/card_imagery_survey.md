# FPS card imagery — survey of Nakazoto/FloatingPointSystems

**Scope: IMAGES ONLY.** The FPS 3000 firmware / ROM / disassembly / emulator work already
exists in **`this repo`** (has its own `CLAUDE.md`, `architecture.md`,
`fps3k_clean.asm`, emulator, ROM dumps). **Do not duplicate it.** This file records only what
the repo holds photographically, for the copper/netlist-extraction question.

Source repo: `https://github.com/Nakazoto/FloatingPointSystems` (834 files, 322 images).
Survey done 2026-07-29 via the GitHub trees API (`/tmp/fps_tree.json`).

---

## Headline finding

| System | images | sides available | netlist extraction possible? |
|---|---|---|---|
| **FPS 3000** | 37 | **COMPONENT SIDE ONLY** | **NO** |
| **FPS 100** | 263 | **front AND back** (11 pairs + 1 scan pair) | yes — but different machine |
| AP 120B | 20 | not surveyed | ? |

**The FPS 3000 cards cannot be netlisted from this repo** — every card image is the populated
component side. Copper extraction needs the solder side; on a fully-populated board the
component side yields noise (measured 71 % occlusion on the AT&T 610 board, see
the AT&T-610 PCB notes (external to this repo)).

**The FPS 100 has both sides, but is NOT compatible with the FPS 3000** (earlier AP-120B
lineage vs the FPS 3000's Motorola VERSAbus/68000 design). So the FPS 100 imagery is useful as
a **pipeline test set**, not as FPS 3000 data.

---

## FPS 3000 — what exists (`FPS 3000/Cards/`)

Eight cards, each photographed **component side only**, in three redundant sets:

| # | Card | Notes from the images |
|---|---|---|
| 01 | **VBUS_SBC** | Motorola VERSAbus single-board computer, "© 1981 MOTOROLA INC", MOTOROLA microsystems, 68000-era |
| 02 | VBUS_XLTR | VERSAbus translator |
| 03 | UNIV_FMT | universal formatter |
| 04 | APIF | array-processor interface |
| 05 | XP32_EXEC | XP32 execution |
| 06 | **XP32_ARITH** | AMD **2901/2910** bit-slice + Am29xx, 3 × PGA sockets, 4 × ribbon headers |
| 07 | MEM_CTRL | memory controller |
| 08 | MAIN_DATA | main data path |

* `01_*.JPG … 08_*.JPG` — **6000×4000 (24 MP)**, teal background, even light, mild perspective.
  ≈ **650 DPI** over a ~9.2 in VME board — resolution is *fine*; it is the wrong side.
* `<NAME>.jpg` — 4080×3072 (12.5 MP), earlier workbench shots of the **same side**, rotated,
  poorer lighting.
* `Cards/Old/` — **byte-identical duplicates** of the 4080×3072 set. Nothing new.

Also in `FPS 3000/` (already covered by `this repo`, listed here only for
completeness): ROM dumps `FPS3K_U11/U12(.bin)`, disassemblies `FPS3K_DIS*.txt`,
`dis68k-master/`, `Layout.drawio(.png)`, `Comparo.*`, chassis photos, and datasheets
(VERSAbus spec, M68KVM02, MC68153, Weitek, AMD 29116, Motorola 1984 components).

---

## FPS 100 — the only front/back dataset (downloaded here)

### `fps100_pairs/` — 11 card pairs, 6000×4000 (24 MP each), 226 MB
`4401_FM` · `4402_DATAPAD` · `4408_P3` · `4421_PDP11IF` · `4422_P1` · `4423_P2` ·
`4424_MD` · `4425_TM` · `4426_FM` · `4429_FMT` · `4448_APIF`
— each as `_F` (front/component) and `_B` (back/solder). Photographs.

### `fps100_scans/` — `PDP11IF_Front.jpg`, `PDP11IF_Back.jpg`, 4488×2896 (13 MP)
**Actual scans**, not photographs — flat and evenly lit. The single best item in the repo for
copper extraction, and directly comparable to the AT&T 610 solder-side scan that the
`../pcb/` pipeline was built and validated on.

---

## What this imagery IS good for

1. **Pipeline validation** — `fps100_scans` (scanned both sides of one card) is an ideal test
   for `../pcb/scan_extract.py` → `scan_netlist.py` → `demerge_driver.py`, and for
   front↔back registration (`register_sides.py`). A second board would confirm the AT&T
   results generalise.
2. **Component inventory** — at 650 DPI the chip markings are legible, so the
   `dip_detect2.py` + front-projection contact-sheet method catalogues each card's ICs.
   This is the only thing the FPS 3000 images support.
3. **Architecture identification** — reading the parts identified the AT&T 610 board; the same
   route works here (e.g. XP32_ARITH is visibly AMD 2901/2910 bit-slice).

## What it is NOT good for
* **Any FPS 3000 netlist.** No solder-side imagery exists in the repo.
* Getting FPS 3000 copper would need new photographs of the solder side of those 8 cards.

---

## Files here
```
fps100_pairs/   22 files, 6000x4000  (11 cards x front+back, photos)
fps100_scans/    2 files, 4488x2896  (PDP11IF front+back, SCANS)
```
The FPS 3000 card images themselves are in `refs/cards/ (component-side photos; originals from Nakazoto/FloatingPointSystems)` (16 files, component side only).

---

## Where everything lives (file map)

**In this directory:**
| Path | Contents |
|---|---|
| `README.md` | this survey |
| `PARTS_INVENTORY.md` | per-card parts inventory, all 8 FPS 3000 cards |
| `VERSABUS_INTERFACE.md` | which ICs sit directly on the VERSAbus, per card (all 8 read directly) |
| `refs/datasheets/` + `INDEX.md` | 18 datasheets/databooks for the non-trivial ICs (317 MB) |
| `make_crops.py` | **regenerates the crops the two analyses were read from** |
| `repo_survey_tree.json` | full file listing of the source GitHub repo (survey input) |
| `fps100_pairs/`, `fps100_scans/` | FPS 100 front/back imagery (pipeline test set — NOT FPS 3000 compatible) |

**Deliberately NOT here:**
| Path | Why |
|---|---|
| `refs/cards/ (component-side photos; originals from Nakazoto/FloatingPointSystems)` | The **16 FPS 3000 card images** (105 MB) live here, as originally placed. Both analyses reference them |
| `a scratch dir (not retained): ` | 48 native-resolution crops (344 MB) — **not stored, reproducible**: run `python3 make_crops.py` |

`make_crops.py` defaults to reading `../pcb/pics2` and writing `/tmp/inv`; both are
overridable (`make_crops.py <out_dir> <cards_dir>`). Crop naming is
`<card>_r<row>c<col>.png`, where **row 1 contains the P1/P2 edge fingers** — so
`*_r1c1.png` are the connector-adjacent crops behind `VERSABUS_INTERFACE.md`.
