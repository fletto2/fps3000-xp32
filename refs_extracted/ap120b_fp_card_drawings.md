# The AP-120B floating-point card drawings — all six complete, 27 sheets (2026-08-19)

`~/src/claude/ap120/schematics/AP-120B/` holds 33 zips, one per card.  This file surveys the
six that carry the **floating-point unit** — the cards whose flag names
(`FAOVF` / `FAUNF` / `FAZRO` / `FANEG`) this project currently takes from **connection lists**
rather than from schematics.

Every page is JPEG-2000, **6798 x 4399, RGB, upright** — no rotation, unlike the AP I/F PDF
whose native strips are stored upside-down.  `pdfimages`-style rotation guesses do not apply;
these are plain images in a zip.

## The survey: six drawings, all COMPLETE

| card | drawing | rev | sheets held | complete? |
|---|---|---|---:|---|
| `06_203B_FADD-1` | **`512-3203-000`** | B00 -> B01 | 6 of 6 | **YES** |
| `07_204B_FADD-2` | **`512-3204-000`** | B02 | 3 of 3 | **YES** |
| `08_205B_FADD-3` | **`512-3205-000`** | B00 | 4 of 4 | **YES** |
| `09_206A_FMUL-A` | **`512-3206-000`** | A01 | 5 of 5 | **YES** |
| `10_207B_FMUL-B` | **`512-3207-000`** | A02 | 5 of 5 | **YES** |
| `11_208_FMUL-C_Exponent` | **`512-3208-000`** | 03 | 4 of 4 | **YES** |

> **Nothing is missing.**  That is worth stating because the AP I/F drawing needed a
> 201-page compendium in another workspace to complete, and the FMT drawing's sheet count was
> misread as "3 of 13" before the rev/sheet convention was understood.

## THE DRAWING NUMBER ENCODES THE BOARD NUMBER — `512-3<BBB>-000`

| board | drawing | | board | drawing |
|---|---|---|---|---|
| 201 S-Pad | `512-3201-000` | | 207 FMUL-B | `512-3207-000` |
| 203 FADD-1 | `512-3203-000` | | 208 FMUL-C | `512-3208-000` |
| 204 FADD-2 | `512-3204-000` | | 226 FMT | `512-3226-000` |
| 205 FADD-3 | `512-3205-000` | | **448 AP I/F** | **`512-3448-000`** |
| 206 FMUL-A | `512-3206-000` | | | |

**Nine boards, nine drawings, no exception** — including the AP I/F, whose board is `448` and
whose drawing is `512-3448-010`.  So **any FPS board's drawing can be located from its board
number**, which is the number silkscreened on the card and listed in the Board Revision List.

## The rev/sheet suffix is confirmed a THIRD way — in plain English

The suffix is `-<rev><sheet><total>`: `B01/56` is **rev B01, sheet 5 of 6**.  This project
derived that convention twice before — from the S-Pad drawing reading `C02/17 .. C02/77`
(the rev constant while the post-slash digits increment, which a sheet number cannot be), and
from the FMT drawing's `A02/13`.

**The FADD title blocks state it outright.**  Beside the drawing number, in the draughtsman's
hand: **`Pg 3 of 6`** on the sheet whose suffix is `/36`, **`Pg 4 of 6`** on `/46`,
**`Pg 5 of 6`** on `/56`, **`Pg 6 of 6`** on `/66`, **`Pg 2 of 3`** on `/23`, **`Pg 3 of 3`**
on `/33`.

> **Six agreements between a hand-written page number and the suffix on the same sheet.**  The
> convention is no longer an inference from a pattern; it is written on the drawing.

`06_203B` also carries **two revisions inside one drawing** — sheets 1-2 at `B00`, sheets 3-6
at `B01` — which is normal for a maintained set and means a rev letter is per-sheet, not per
drawing.

## Sheet titles, where the draughtsman wrote one

| sheet | title |
|---|---|
| FADD-1 `/16`, `/26` | `AP-120B FADD-1 Bd.203B` — no sub-title |
| **FADD-1 `/36`** | **`SCALER, INPUT SELECT, 8 BIT SHIFTER`** |
| **FADD-1 `/46`** | **`SCALER, INPUT SELECTOR, 8-BIT SHIFTER`** |
| **FADD-1 `/56`** | **`ZERO DETECT`** |
| **FADD-1 `/66`** | **`INPUT SELECT, SCALER BYTE SELECT`** |
| FADD-2 `/23`, `/33` | `AP-120B FADD2 Bd.204B` — no sub-title |
| FADD-3 `/14`, `/24`, `/34` | `AP-120B FADD3 Bd.205B` — no sub-title |

Draughtsman **RJM**, dates 5/17/76 and 24-27 Feb 75; FADD-2 checked **12/8/75**, rev-checked
**9-25-75** — the same `REV CHK 9-25-75` stamp that appears on `09_206A_FMUL-A`.

**The card count is NOT the pipeline stage count.**  FADD is three cards (203, 204, 205) and
FMUL is three (206, 207, 208), while this project records from NASA-TM-84566 a **2-stage adder
and a 3-stage multiplier**.  A card is a packaging unit; a stage is a pipeline register.  The
two happen to coincide for the multiplier and do not for the adder.

## FADD-1 sheet 5, `ZERO DETECT`, read at native resolution

Built from **`74S134` 12-input NAND gates with 3-state outputs**, at `B4`, `B8`, `B12`, `B15`,
with **1K pull-ups** (`B16R1*`, `C16R*`) tying off the inputs each gate does not use.

| gate | inputs | first input |
|---|---|---|
| **`B4`** | `IS06*`-`IS14*` (9) + `D08T15NZ*` + `D16T23NZ*` + `D24T27NZ*` | **IS06** |
| **`B8`** | `IS14`-`IS22` (9) + `D16T23NZ*` + `D24T27NZ*` + pull-up | **IS14** |
| **`B12`** | `IS22*`-`IS30*` (9) + `D24T27NZ*` + pull-ups | **IS22** |
| **`B15`** | `IS30*`-`IS34*` (5) + pull-ups | **IS30** |

> **The windows OVERLAP and step by EIGHT** — 06, 14, 22, 30.  A plain zero detect *partitions*
> the bits; overlapping windows sliding by a fixed stride do not.

### The names decode themselves, and the stride matches the card

**`D08T15NZ*` = D, bits **08 T**hrough** 15, **N**on-**Z**ero** — and likewise `D16T23NZ*` and
`D24T27NZ*`.  Three group terms in bands of **8, 8, 4** covering **bits 8 through 27**, feeding
the wide gates as pre-reduced summaries.

Two things follow, and the second is the one that matters:

* **the top of the range is 27.**  This project measured the AP-120B/FPS-100 mantissa as
  **28 bits** — `DPMBS00-27`, `FAM00-27`, `FMM00-27` — from *connector pin names* on seven
  buses.  Here the same width appears as the **structure of a zero-detect tree** on a card
  drawing.  Two artefacts, two documents, one width, neither used to derive the other;
* **the stride is 8, and this card's other sheets are `SCALER`, `INPUT SELECT` and
  `8-BIT SHIFTER`.**

### So this sheet is NOT the origin of `FAZRO` — a distinction worth making

A floating adder's prescale aligns mantissas by shifting, and a **byte-granular** shifter needs
to know *how many leading bytes are zero*.  Overlapping 12-bit windows stepping by 8, on the
card that carries the 8-bit shifter, is **normalisation/scale detection** — an input to the
shift-amount decision — not the result flag a condition mux would test.

> **Recorded as a reading, and recorded because the alternative was tempting.**  A sheet titled
> `ZERO DETECT` on a floating adder invites being written down as "where `FAZRO` comes from".
> The window overlap refutes that: a result-zero flag is one term over the whole mantissa, not
> four overlapping ones at a stride matching the shifter's granularity.

`FAZRO`'s origin is therefore still unlocated, and **FADD-3 (board 205, the last stage) is
where to look** — a result flag belongs with the result.

## Signals crossing to other sheets

| signal | direction | note |
|---|---|---|
| `SCIN` | in, from sheet 6 | gated through `C16` `74S00` with a 1K pull-up |
| `IS06`-`IS34` | in, from sheets 3 and 4 | the `INPUT SELECT` / `SCALER` sheets |
| `D08T15NZ*` `D16T23NZ*` `D24T27NZ*` | in, from sheet 4 | the group-nonzero terms |
| **`DE07*` `DE08*`** | out, from `B18` / `B20` -> `B10` `74S00` | **NOT identified** |
| `FSM278*` `FSM288*` `FSM298*` `FSM300*` | on FADD-2 sheet 1 | **NOT identified** |

**`DE` and `FSM` are deliberately left unidentified.**  `DE` invites "Difference of Exponents",
which is exactly the quantity a floating adder's prescale needs and would fit this sheet
perfectly — and that is the reason to distrust it without a trace.  Nothing here traces either
group to its source.

## What this does and does not settle

**Settled**: six complete drawings, the board-number-to-drawing-number rule, the sheet-suffix
convention confirmed in the draughtsman's own words, FADD-1's sheet titles, sheet 5's device
inventory and window structure, and the 28-bit mantissa appearing in a second kind of artefact.

**Not settled**: where `FAOVF` / `FAUNF` / `FAZRO` / `FANEG` are generated; what `DE` and `FSM`
are; and **whether any of it transfers to the XP-32**, whose AU uses **Weitek** VLSI where the
AP-120B uses discrete TTL and AMD bit-slice arrays.  The lineage argument is about FPS's
*vocabulary* — floating-point flags with UNDERFLOW where AMD's integer reference has CARRY —
not about circuitry.

## METHOD

**Locate title blocks by their own bounding box, not by fixed crop fractions.**  These scans
are **not registered** — the drawing sits at a different offset on every page, and a fixed crop
that works on one page lands on component outlines on the next (which is how
`07_204B_FADD-2/01`'s block was missed, the crop returning a `B64` designator instead).  Find
the dark-pixel bounding box in the bottom-right quadrant, then crop relative to *that*:

```python
g = np.asarray(im.convert('L').crop((int(.55*W), int(.85*H), W, H)))
dark = (g < 110)
ry = np.where(dark.sum(1) > 40)[0];  cx = np.where(dark.sum(0) > 10)[0]
x1 = int(.55*W) + cx.max();  y1 = int(.85*H) + ry.max()
strip = im.crop((x1 - 1560, y1 - 420, x1, y1 + 12))     # title + drawing number
```

**Normalise, then crop — never downscale the normalised image.**  Local contrast normalisation
`(I - gaussian(I,4)) / sqrt(gaussian((I-mean)^2,4))` makes these drawings legible, and
downscaling the result destroys exactly the high-frequency detail it recovered: an overview
built that way showed a uniform grey field with the schematic barely visible.  The recorded
rule — *crop at full resolution, never downscale* — applies to the **output** of the
normaliser, not only to the input.

**A plain downscaled overview is still the right way to LOCATE.**  It showed in one read that
the drawing occupies only the **left third** of the scanned area, which is what made the native
crops cheap.  Two title blocks appear at the bottom of that page carrying the *same* drawing
number, so the sheet is smaller than the scan frame.
