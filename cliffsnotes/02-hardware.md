# 02 — Hardware

## Chassis

14-slot **VersaBUS** chassis (FPS Model 821-9008-011), confirmed from
`refs/FPS-3000/fps-3000.jpg`. Lovett's unit is populated as a
**2-AC configuration**:

| Slot | Card | Notes |
|---:|---|---|
| 14 | VBUS SBC | M68KVM02-3 — runs the 64 KB ROM |
| 13 | VBUS XLTR | host↔XP32-bus translator |
| 12 | FMT | Universal Format |
| 11 | AP I/F | host computer interface (chassis side) |
| **10** | **XP-32 EXEC (1)** | AC1 EU controller |
| **9** | **XP-32 ARITH (1)** | AC1 FP pipes |
| **8** | **XP-32 EXEC (2)** | AC2 EU controller |
| **7** | **XP-32 ARITH (2)** | AC2 FP pipes |
| 6 | MEM CTL | System Common Memory controller |
| 5–1 | MEMORY ×5 | SCM banks |

The MEM CTL + 5 MEMORY cards form **System Common Memory (SCM)**,
shared between AC1 and AC2 — this is the **MIMD** part. Each AC = an
ARITH card (FP pipelines) + an EXEC card (EU controller + control store).

## SBC card (slot 14)

- **CPU**: MC68000 @ 8 MHz, 24-bit address bus
- **RAM**: 128 KB at `0x000000–0x01FFFF`
- **ROM**: 64 KB at `0xF00000–0xF0FFFF` (the file we have)
- **Reset overlay**: ROM aliased at `0x000000` for the first fetches
- Memory map: see [03-firmware.md](03-firmware.md)

## EXEC card (XP-32 EU controller)

Per Nakazoto's photo (`refs/FPS-3000/cards/05_XP32_EXEC.JPG`), board
612-4805-002 carries:

- **AMD Am29116DCB** — 16-bit bipolar microprocessor (the EU
  instruction processor; not a microprogram sequencer in the bit-slice
  sense). **There are TWO on the one card** (owner, 2026-07-29). How the
  pair split the 80-bit microword is open, and it decides whether an EU
  PROM dump holds one instruction stream or two
- **Am2168-45PCB / CY7C168 SRAMs** in an array — likely the AU writable
  control store (4K × 128-bit, host-uploaded)
- **Bipolar PROMs** — these are the **EU PROM** per Hockney's
  Figure 2.53 + p. 241 text: "Microcode programs for the EU reside
  in EU PROM, which contains 2K 80-bit microinstructions." The EU
  store is **fixed factory mask**, NOT writable. Only the AU WCS is
  writable. (Earlier drafts of this doc had this backward; see
  `../notes/correction_eu_writable.md` for the retraction.)
- **PALs** (DIP-24, custom-marked "29F52 SDC") — combinational decode
- **74F-series TTL glue**

Open question: chip-to-function mapping on the EXEC card.
Hockney + the architecture diagram tell us *what* should be on the
card (Am29116 EU controller + 80-bit EU PROM + 128-bit AU WCS +
PALs), but matching each physical chip to its role still needs
audit-G5 photo re-inspection.

## ARITH card (XP-32 FP pipes)

Board 612-4806-002 carries:

- One **WEITEK WTL-1032** floating-point multiplier (64-pin DIP or
  68-pin LCC) — IEEE 754 32-bit single-precision, 3-stage internal
  pipeline. Datasheet in `refs/Weitek/WeitekDatasheet.pdf`.
- Two **WEITEK WTL-1033** floating-point ALUs (same package as
  WTL-1032; common pinout). Both chips do add/subtract/abs and FP↔
  fixed-point conversion. The "WTL-1232/1233" guess in earlier
  drafts (assumed production-part successor) was wrong — the
  WTL-1032/1033 datasheet identifies these as the parts Hockney
  refers to.
- Bipolar PROMs in DIP-20 — arithmetic-control fan-out PROMs
- Am2168 SRAMs — additional buffers/registers

Hockney p. 240 describes the AU as having "a five-stage floating-
point multiplier pipeline and two five-stage floating-point adder
pipelines." The WTL chips themselves have a 3-stage internal pipe
per the datasheet; the system-level "5-stage" pipe is 3 chip stages
+ 2 stages of external register staging (input mux + output
capture).

## Sequencer-chip identification across the FPS family

Critical finding ([fps164_chip_identification.md](../notes/fps164_chip_identification.md)):

| System | Year | EU control chip |
|---|---|---|
| AP-120B | 1976 | Schottky-TTL MSI |
| FPS-100 | 1977 | Schottky-TTL MSI |
| FPS-164 | 1981 | Schottky-TTL MSI (designed 1979, ~2000 chips) |
| FPS-164/MAX | 1985 | ADSP-1401 (MAX boards only) |
| **FPS-3000** | **1983** | **AMD Am29116** |
| FPS-264 | 1986 | ECL refresh of FPS-164 |

The Am29116 is **not** family-wide. Only the FPS-3000 EXEC card
carries one. The FPS-164 layout-evolution chain is therefore not
constrained by chip-level continuity.

## Surviving units

Per `Nakazoto/FloatingPointSystems/KnownSurviving.txt`:

- FPS-3000: **1** (Lovett, Texas) — complete, healthy
- AP-120B: 4 (LSSM, eBay, China; LSSM only powered)
- AP-180V: 2
- FPS-100: 2 (Cully MA powers up; "cw" undisclosed)
- FPS-5100: 1 (Europe)
- **FPS-164: 0** — none surviving in the public inventory

## Where to read more

- Full architecture writeup: [`architecture.md`](../architecture.md)
- AP I/F card details: [`ap_if_card.md`](../notes/ap_if_card.md)
- Cable protocol: [`cable_protocol_inferred.md`](../notes/cable_protocol_inferred.md)
- Family chip identification: [`fps164_chip_identification.md`](../notes/fps164_chip_identification.md)
- Board photos: `refs/FPS-3000/cards/01..08*.JPG`
