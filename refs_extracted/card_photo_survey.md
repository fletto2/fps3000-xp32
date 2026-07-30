# What the card photographs established (2026-07-30)

Six of the eight cards in `refs/FPS-3000/cards/` were surveyed at native resolution (6000x4000,
tiled to stay under the vision cap). This records what was **read off the boards**, separately
from what was inferred from firmware — the two lines of evidence are independent and several
findings depend on that.

## Findings that changed a documented claim

| card | finding | what it changed |
|---|---|---|
| **XLTR** | **three `MC68153P`** BIMs, positions F/G, H/J, K/L | the emulator modelled **two**; correcting it also removed a spurious interrupt storm |
| **EXEC** | **`AM2910ADC`** microprogram sequencer | retracted *"not a microprogram sequencer... the wrong mental model for how the EU is controlled"* |
| **EXEC** | **exactly ten** `225-0600-0NN` PROMs, 24-pin AMD | `10 x 8 = 80` — the EU word is **one** stream, not two |
| **AP I/F** | **`MC3487`/`MC3486`** differential driver/receiver pairs | the host link is **RS-422 differential**, not single-ended |
| **UNIV FMT** | two **`74S181`** ALUs + **`74F350`** shifters | the card does **format conversion**, not width conversion or fan-out |
| **XLTR** | **`MC26S10`** arbitration transceivers | the "no VERSAbus arbitration" divergence omits **real, identifiable silicon** |

## Confirmations of existing records

- XLTR part number **`612-4803-400 REV G`** — matches the owner's card list exactly, revision included
- AP I/F **`AM29705DCB`** dual-port SRAM — the 32-bit width this project infers
- **`AM2168-45PCB`** SRAM banks on both EXEC and ARITH — the writable control stores
- **`29F52 SDC`** PALs — **nine counted** in the EXEC left column, the first hard count
- ARITH carries **three** large FP packages — Hockney's "1 multiplier + 2 adders"
- SBC **`MC1488`/`MC1489`** RS-232 driver/receiver pairs, jumper blocks `J21`-`J24`, DIP banks `J25`/`J26`

## Firm negatives — recorded as such

- **The ARITH FP packages are UNMARKED.** Gold-lidded LCCs in sockets, date code `8541`, no part
  number on any visible face. The Weitek WTL 1032/1033 hypothesis is **untested**, not supported.
  Two photographs from the same angle add nothing; this needs the board.
- **Individual EU PROM labels are illegible.** The count is solid, the **order within the word is
  not** — so a dump must be assembled in board order and the bit lanes corrected afterwards.

## What photographs cannot reach

The EU↔AU interface, the AP I/F counterpart card in the host chassis, and the internal behaviour
of any of the above. Chip identification bounds what a component *can* do; it does not show what
it *does*. Every dynamic claim in this project still rests on the firmware or the emulator.

## Method notes

- Tile at **native resolution** — never downscale a board photo. A 4x3 tiling of 6000x4000 gives
  1500x1333 tiles, under the vision cap with no loss.
- **Count twice at different magnifications.** The EU PROM count went from "approximately ten"
  to exactly ten only after cropping tightly and splitting the column.
- **White-labelled DIPs are ambiguous** — this board carries at least three distinct
  hand-labelled series (`225-0071`, `225-0600`, `PE-0071`) plus PALs that look identical at low
  magnification. This project has already once mistaken PALs for PROMs.
