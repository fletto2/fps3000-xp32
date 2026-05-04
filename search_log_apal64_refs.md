# Search log: hunting the APAL64 / XP-32 reference manuals

Recording the negative result so the search doesn't have to be re-run.

**Goal:** find any document that pins down the *bit-level* layout of
the FPS-164 64-bit microinstruction (any of: APAL64 Programmer's Guide
860-7484-000, APAL64 Programmer's Reference Manual 860-7485-000,
APLINK64 860-7486-000) or the XP-32 128-bit microinstruction (no
known document number).

**Date searched:** 2026-05-04.

## Sources checked

| Source | Result |
|---|---|
| bitsavers `pdf/floatingPointSystems/FPS-164/` | APMATH64 Vol 2-4, APSIM64, brochure, IBM/CMS host manual, MAX paper. **No APAL64 reference.** |
| bitsavers `pdf/floatingPointSystems/FPS-3000/` | 6 photos, zero PDFs |
| bitsavers `pdf/floatingPointSystems/FPS-5000/` | 3 Curington papers + ad — already have all locally |
| bitsavers `pdf/floatingPointSystems/AP-120B/` | Programmer's Reference Manual Pt1 + Pt2, Processor Handbook, Math Library, APDBUG, Diagnostic Manual — already have all |
| bitsavers `pdf/floatingPointSystems/FPS-100/` | software dist + manuals — already have |
| Computer History Museum collection search | empty for FPS-specific manuals |
| archive.org search (document numbers) | no hits |
| ACM Digital Library | Touzeau 1984 paper exists, paywalled |
| Google Scholar / general web | only paywalled / abstract-only academic refs |
| johngustafson.net | connection refused from here; might work elsewhere |

## Best remaining lead — Touzeau 1984

**"A Fortran compiler for the FPS-164 scientific computer"**, Roy F.
Touzeau, FPS Beaverton. SIGPLAN Symposium on Compiler Construction,
Montreal, June 17-22 1984, pp.48-57. DOI 10.1145/502874.502879. ACM
paywall. ~$15.

Why it's the best lead: written by an FPS internal compiler engineer
about how Fortran maps to FPS-164 microcode. A compiler paper almost
necessarily exposes more field-level detail than user manuals do, in
order to motivate code-generation choices.

## Used-book / auction channels (checked 2026-05-04)

| Channel | Query | Result |
|---|---|---|
| eBay | `"floating point systems" manual` | 0 hits |
| eBay | `FPS-164 manual` | only Ford / Mercedes / aviation manuals, no FPS Inc. |
| eBay | `FPS-100 manual` | camera modules, jukeboxes, irrelevant |
| eBay | `AP-120B` | Yamaha YZ450-F motorcycle parts |
| eBay | `APAL64` | APAL is a Belgian kitcar brand |
| eBay | `"floating point systems"` exact-phrase (broader sort) | **6 vintage print ads** (1977/1979×2/1982×2/1983×2/1987), $41-99 each — decorative |
| eBay | broader sweep with US-locale headers | **🎯 NASA AP-120B Array Processor (1975, all 28 boards)** ~$8,200 — listing ID `256771111122`. Hardware, not a manual; but a working unit lets us dump the EU PROM directly and validate the recovered FFT microcode |
| eBay UK + DE | `"floating point systems"` | 0 hits each |
| eBay sold-listings (historical) | `"floating point systems"` | 0 — no FPS-Inc transactions in recent history |
| abebooks | `floating point systems` | only generic numerical-computing books |
| abebooks | `FPS-164` / `AP-120B` | only **Frederic P. Miller** print-on-demand Wikipedia-scrape books — skip |
| bookfinder.com (federated) | `floating point systems manual` | 0 |
| Internet Archive item search | `"floating point systems" "FPS-164"` | 0 unique items beyond bitsavers mirror |

So **no FPS Inc. technical documentation is on the open used-book/auction market right now**. The vintage print ads are the only FPS-related items currently listed (~$50-60, decorative).

## Confirmed FPS card P/Ns (Dec 1989 catalog + Lovett's chassis)

**Found and pulled locally**: bitsavers had two FPS catalogs all
along — `FPS_Board_Revision_List_198912.pdf` (26 pages, Dec 1989)
and `FPS_Pricing_198403.pdf` (9 pages, Mar 1984). Both now in
`refs/`.

Reading the BRL gave the full host-bus mapping for Lovett's
chassis card:

| P/N | Card | Notes |
|---|---|---|
| `612-4448-401-F` | **AP I/F (chassis-side)** | "APIF"; current Dec 1989; Lovett's slot-11 card |
| `612-4448-402..403` | AP I/F MP32 | Multi-Processor 32-bit variants (newer than -401) |
| `612-4448-301..307` | UNIV APIF | Older Universal APIF generation |
| `612-4448-011..017` | 448 APIF (specific) | Per-host-AP variants from FPS-100/AP-120B era |
| **`612-4012-003`** | **Q-bus host-side adapter** | "Q22 BUS ADPTR FPS3000/5000" — for PDP-11/73, /23, /83 |
| **`612-4013-001`** | **UNIBUS host-side adapter** | "UNIBUS ADPTR FPS3000/5000" — for PDP-11/44, /70, /84 |
| `612-4014-000` | UNIBUS terminator | Companion to 4013 |
| `612-4850-000` | LSI-11 hex-height adapter | Alt for LSI-11 hosts |
| `612-4805-002` | XP-32 EXEC | Am29116 + EU PROM |
| `612-4806-002` | XP-32 ARITH | FP pipes |
| `612-4498-401-A` | MEMORY | |
| `612-4456-461` | MEMORY | |
| `422-0015-001` | Co-Processor Interconnect Cable | per 1984 pricing list ($100) |

System-level identifiers (from data plate):
- Model: `FPS 3000`
- System P/N: `833-2003-004` REV B
- System S/N: `FAS 20282`
- Chassis P/N (index plate): `821-9008-011`

The catalogs **resolved every host-bus-variant question** — the
specific part to find for Lovett's PDP-11/73 is `612-4012-003`
("Q22 BUS ADPTR FPS3000/5000"), and the UNIBUS counterpart is
`612-4013-001`.

## Curington's personal publications page (thames3.org)

`https://thames3.org/curington_pubs.html` hosts ~30 papers by Ian
Curington (FPS UK signal/image specialist, 1979-onward). The
FPS-era subset (1983-1989) overlaps with bitsavers but contains
several papers we didn't have:

| Year | Title | Source | Local? |
|---|---|---|---|
| 1983 | Multiple AP Landsat Adaptive Filtering / FPS-5000 | CHECKPOINT 1(8) | (only metadata online) |
| 1983 | Power Spectrum Analysis with the FPS-5000 | CHECKPOINT 1(7) | yes (refs/FPS-5000/) |
| 1983 | **IOP-UNI Applications** | CHECKPOINT 1(4) | **bib only — PDF 404** |
| 1983 | Using A/D Converters with the IOP-16 | CHECKPOINT 1(3) | yes (refs/curington_extras/) |
| 1984 | Performance Estimation Methods for XP32 MAXL | FUSE-84 | yes (refs/FPS-5000/) |
| 1985 | Fast Vectorized Surface Shading on FPS-5000 | ARRAY-85 | not downloadable |
| 1985 | Multi-Band Image Classification | Image Vision Computing | not downloadable |
| 1986 | Synchronization & Pipeline Overhead / FPS-5000 | Parallel Computing 85 | yes (refs/FPS-5000/) |
| 1986 | Graphics on the FPS M64 | CHECKPOINT 1986 | not downloadable |
| 1986 | **Symbolic Data Memory Allocation for XP-32** | CHECKPOINT 4(7) | yes (refs/curington_extras/) |
| 1986 | Run Length Encoding (RLE) for XP-32 | CHECKPOINT 4(3) | yes (refs/curington_extras/) |
| 1987 | The Application of Array Processing in Earth Resources | DECUS Rome | not downloadable |
| 1989 | f∞ memory/comm bottleneck parameter | Parallel Computing 10(3) | not downloadable |

### What CHECKPOINT was

Floating Point Systems' **internal customer newsletter**, printed
and mailed to FPS customers ~quarterly during 1983-1989. Each
issue contains technical articles + product announcements + tips.
**The single most-likely-to-be-relevant document for the AP I/F
question** is `IOP-UNI Applications` (CHECKPOINT 1(4), 1983) which
the bib confirms exists but no PDF is online.

### What the OCR pass added (2026-05-04)

- **`IOP-16` paper (1983) confirmed the IOP family inventory**:
  - IOP-16 = DMA for external devices (A/D etc.), 1 board
  - IOP-38 = General-purpose 38-bit parallel, 2 boards
  - **IOP-UNI = UNIBUS host interface with cable, 1 board** ←
    this is the FPS-100-era predecessor to `612-4013-001`
- **GPIOP** (General Purpose I/O Processor) confirmed as separate
  card variant (mentioned in RLE paper)
- FPS-5205 / FPS-5320 confirmed as CP variants of FPS-5000 family
  (same architecture, different speed grades)
- The XP-32 LMD has **16K × 32-bit** standard size (= LMDMAX 65535
  in CPFORTRAN allocator) — confirms the 16K LMD figure from
  Hockney fig 2.53

### Direct contact opportunity

Curington maintains the publications page (newest entries 2003).
A polite email asking specifically for IOP-UNI Applications + any
FPS-3000-specific CHECKPOINT articles he kept would have a non-
trivial hit rate. Currently visible web presence: Floating Point
Systems UK Ltd alumnus → AVS/Express visualization (1990s) →
present-day independent. LinkedIn-findable.

## Higher-yield retro-computing channels (untried as of 2026-05-04)

These don't have public-search APIs, but tend to surface FPS docs ~1×/year:

- **VCFed.org forum** — David Lovett's existing FPS-100 thread already
  there; would be cheap to bump with a specific "looking for APAL64
  Programmer's Reference Manual, FPS doc 860-7485-000" post
- **Computer Reset (Dallas)** — periodically liquidates FPS-era kit
  including documentation; usually phone/email
- **Weirdstuff Warehouse / NextStaging** — Bay Area surplus channels
- **University equipment-surplus auctions** — sites that ran FPS-164s
  in the 80s sometimes still have docs
- **eBay saved-search alerts** — "floating point systems" with email
  notification (free); periodic listings do appear
- **abebooks "Want" alerts** — same idea

## Acquisition paths

1. **ACM Digital Library** — pay or institutional access for Touzeau 1984.
2. **Hackaday/VCFed appeal extension** — David Lovett already has a
   public ask going (per CLAUDE.md). Specific request for "APAL64
   Programmer's Reference Manual, FPS document number 860-7485-000"
   would be cheap to add.
3. **eBay / abebooks / weirdstuffwarehouse** — FPS engineering manuals
   surface periodically; usually $30-80 if found.
4. **FPS alumni direct outreach**:
   - Bill Curington (3 cited XP-32/FPS-5000 papers) — likely retired
   - Roy F. Touzeau (compiler paper)
   - Alan Charlesworth (FPS-164/MAX paper)
   - John Gustafson (T-series book, FPS alum) — public-facing,
     johngustafson.net + LinkedIn reachable from elsewhere

## What this rules out for now

The FPS-3000/XP-32 microinstruction layout cannot be definitively
pinned down from currently-online documents. We have:

- **AP-120B** layout: definitive (FPS-7319 + SIM100 SPLIT)
- **FPS-164** layout: field taxonomy with widths (APSIM64 App. A); no
  public bit-position offsets
- **XP-32** layout: only architectural-level descriptions (Hockney,
  Curington 1984/1986); no field tables anywhere public

Inference can constrain the XP-32 layout to a structure-preserving
widening of FPS-164 (per the additive-evolution pattern), but exact
bit positions stay open. Recovery options that don't depend on
finding documentation:

1. Disassemble a recovered XPMLIB binary kernel (need a working
   FPS-3000 + microcode dump first)
2. Read the EU PROM contents off a working XP-32 EXEC card (Usagi
   Electric has one) and reverse-engineer the 80-bit format from
   sequencer-instruction patterns
3. Acquire the documents (paths 1-4 above)
