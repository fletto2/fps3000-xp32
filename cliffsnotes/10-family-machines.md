# 10 — The wider FPS family — what we know about each machine

The FPS-3000 sits inside a larger lineage of Floating Point Systems
machines spanning 1976–1991. Understanding what's known about each
sister machine is necessary for the AP-120B → FPS-164 → XP-32
inheritance chain that grounds our microcode-layout inference.

## Lineage at a glance

```
1976 ─ AP-120B ────┬──── FPS-100 (1977, cheaper)
        ╎          │
        ╎          ├──── AP-180V (later 16-bit, mainframe)
        ╎          │
        ╎          └──── AP-190L (1977, larger memory)
        ╎
1981 ─ FPS-164 ────┬──── FPS-164/MAX (1985, VLSI accelerator)
        ╎          │
        ╎          └──── FPS-264 (1986, ECL refresh)
        ╎
1983 ─ FPS-3000 ───┬──── FPS-5000 / 5100 / 5320A (1983-86)
                   │     (FPS-3000 + 1-3 XP-32 ACs in same chassis)
                   │
                   └──── FPS-5320A (specific 4-AC variant, Curington)
1985 ─ FPS-T Series (Transputer-based)
1988 ─ FPS-500 Series (after Celerity acquisition)
```

## AP-120B (1976)

The founding product — first FPS attached array processor to ship
under the FPS name. **Documented well**, both bitsavers and customer
manuals.

- **Co-designed** by George O'Leary and Alan Charlesworth
- 12 Mflop/s peak; ~4400 units shipped by 1985
- **38-bit FPS proprietary float format**
- **64-bit horizontal microcode** (24-field SPLIT decode in
  `SIM100.FTN`)
- 167 ns clock, Schottky-TTL MSI throughout
- ~28 boards per box
- Math API: APAL assembly + math libraries (`BAALIB`, `BABLIB`,
  `AMLLIB`, `IPRLIB`, `SIGLIB`, `UTLLIB`, `AMP/AML/SYM/DGN`)
- Toolchain: `ASM100`, `LNK100`, `LOD100`, `SIM100`, `DBG100`

**What we have**: full bitsavers documentation; 1,816-byte
recovered FFT identity-test microcode (`ap120b_ffttest_ucode.bin`);
SIM100 simulator source compiles and runs.

**Surviving units**: 4 known (LSSM Pittsburgh, eBay TX, China
bd4sup, China LandSat).

## FPS-100 (1977)

Cheaper variant of the AP-120B intended for embedding in OEM systems.
Same instruction set, same microcode format — different packaging
(10 boards, 250 ns clock).

- Possibly used by **Bomem in the DA3 FTIR spectrometer** as the
  optional "HPVP" (High-Performance Vector Processor) upgrade.
  **Identification unproven** — see `../notes/cmd_files_inventory.md` and
  `../notes/fps100_multi_ap_support.md` for the HPVP-identity analysis.
  Earlier confident "Bomem marketed FPS-100 as HPVP" claims have
  been retracted as unsupported.
- Documented in bitsavers `pdf/floatingPointSystems/FPS100/`

**What we have**: the full **FPS-100 RSX-11M v3.2 distribution** (Al
Kossow's tape recovery from a damaged tape):

- 9 binary math-library `.APO` files = **11,469 AP-120B
  microinstructions**
- 9 matching APAL source `.APS` files
- Toolchain in FORTRAN-77 source (`ASM100/LED100/SIM100/DBG100`)
- Full host-side OS (`KERNEL.{B,S}`, `IOQUE.{B,S}`, `HSVC.{B,S}`)
- Installation manual `INSTAL.TXT` (162 KB)

**Missing from the recovery** (per VCFed thread): `LNK100`, `LOD100`
linker/loader. `LED100` may be their replacement.

**Surviving units**: 2 known. Cully (Massachusetts) has one that
powers up but no comms yet; "cw" undisclosed location, complete but
not yet powered.

## AP-180V / AP-190L (1977-1980)

Larger-memory variants of the AP-120B for IBM 370 mainframes (190L)
and DG/SEL/HP minicomputers (180V).

**Surviving units**: 2 AP-180Vs (LSSM, China).

## FPS-164 (1981)

The 64-bit refresh of the AP-120B. **Designed in 1979** with
Schottky-TTL MSI per Charlesworth & Gustafson 1986 (Table 1):

- Data unit alone needed ~2000 chips on 7 large 16″×22″ PCBs
- 760 W power dissipation
- 11 Mflop/s peak — actually slower than the AP-120B!
- 1 Mword → 7.25 Mword memory (vs AP-120B's 16-bit address space)
- 24-bit address bus
- 64-bit microinstruction with primary + secondary parcel structure
  (Touzeau 1984 fig 2)
- Math API: MAXL FORTRAN compiler + APMATH64/MAX library
- ~180 units shipped by 1985

**Critical for our work**: the FPS-164 microinstruction layout
(Touzeau 1984) is the direct ancestor of the XP-32 layout. The
primary-parcel groups (SPAD, Adder, Branch, Data Pad, Multiplier,
Memory) all carry through to XP-32 with widening.

**What we have**:
- APMATH64/MAX manual Vol 2/3/4 (vol 1 missing!)
- APSIM64 + APDEBUG64 manual
- Charlesworth IEEE Micro 1986 paper
- Gustafson 1985 historical retrospective
- FPS-164 Software Programming Class notes
- IBM CMS front-end manual
- Touzeau 1984 FORTRAN compiler paper

**What's missing**: Vol 1 of the APMATH64 manual; APAL64 reference
manual (never publicly archived); software distribution; **board
photos** (none publicly available!).

**Surviving units**: 0 in the public inventory. The CHM has at
least one in collection per inventory references but no online photo
gallery.

## FPS-164/MAX (1985)

Matrix accelerator add-on to the FPS-164. Each MAX board ≈ 2
additional FPS-164 CPUs of arithmetic power. Maximum 15 MAX boards
= 31 FPS-164 CPUs = 341 Mflop/s theoretical peak.

- First commercial computer built from **replicated VLSI arithmetic
  parts** (Charlesworth 1986)
- **Weitek WTL 1264** multiplier (NMOS, 8 MFLOPS)
- **Weitek WTL 1265** ALU
- **ADI ADSP-3210** multiplier (alternative)
- **ADI ADSP-3220** ALU (alternative)
- **WTL 2068** register reservation unit
- **ADSP-1401** program sequencer ⚠ *not* Am29116
- Two **ADSP-1201** integer ALUs

The MAX boards bolt into an existing FPS-164 chassis; the original
control unit (still TTL MSI) is retained.

## FPS-264 (1986)

ECL refresh of the FPS-164. Same MSI-class architecture, ECL parts
for ~3.5× speed (38 Mflop/s).

## FPS-3000 / FPS-5000 family (1983-1986)

The XP-32-based MIMD line. Different terminology in different sources
makes this confusing — Hockney & Jesshope treats "FPS-5000" as the
family name, with FPS-3000 / FPS-5100 / FPS-5320A as configuration
variants in the same chassis lineage. Curington's papers use
"FPS-5000" generically for the whole MAXL/XP-32 ecosystem.

Per Hockney § 2.5:

- 1–3 (or 1–4 per other sources) **XP-32 Arithmetic Coprocessors** in
  one chassis, sharing System Common Memory (SCM)
- Each XP-32 = ARITH card (FP pipes) + EXEC card (Am29116 + control
  stores)
- 32-bit IEEE-754 single precision (the first IEEE-754 array
  processor)
- 128-bit horizontal AU microcode, 4K × 128 × 4 banks per AC
- 80-bit fixed EU PROM, 2K words per AC
- MAXL FORTRAN-like compiler (Curington 1984), XPMLIB math library
- VersaBUS chassis with M68KVM02 SBC running RMS68K

**FPS-3000** in this project = **2-AC configuration** of this family.

**FPS-5100**: per the VCFed FPS-100 thread, this is "an FPS-100 with
a coprocessor" — possibly a transitional SKU bridging the FPS-100
and the XP-32 lineage.

**FPS-5320A**: per Curington's "Performance Estimation Methods for
XP32 MAXL" (1984), a specific chassis variant, possibly 4-AC.

**What we have**:
- Hockney & Jesshope chapter (the only published architecture
  description)
- 4 Curington papers (1983-86) including the unpublished
  "Symbolic Execution Methods for XP32" (`refs/FPS-5000/`)
- FPS-5000 ad
- The 64 KB SBC ROM (this project's centerpiece)
- Nakazoto's board photos for Lovett's FPS-3000

**What's missing**: every byte of XPMLIB; the EU PROM contents; the
APAL64 reference; XP-32 hardware schematics; the host-side AP I/F
card.

**Surviving units**: 1 FPS-3000 (Lovett TX), 1 FPS-5100 (Europe).

## FPS T Series (1985)

Transputer-based parallel computer. Different architecture entirely
— uses **INMOS T414/T800 transputers** instead of XP-32 ACs. Outside
the lineage that informs our XP-32 work but worth knowing about.

**What we have**: Gustafson 1986 *Programming the FPS T Series* on
bitsavers.

## FPS Computing era (1988-1991)

In 1988 FPS acquired Celerity Computing of San Diego, renaming
itself FPS Computing. Celerity's lines became the FPS Model 500
series (Sun-based parallel servers). FPS itself was acquired by
**Cray in 1991** for $3.25M; the products became Cray's S-MP and
APP lines. Cray was acquired by SGI in 1996.

This timeline matters because FPS source code and design files
*may* exist in Cray → SGI → HPE archives. The Computer History
Museum is the most likely public-archive contact.

## Implication for XP-32 microcode inference

Only the **AP-120B → FPS-100 → FPS-164** chain provides documented
microinstruction-format precedent for the XP-32. Specifically:

1. AP-120B microcode format is bit-exact (FPS-7319 manual + recovered
   binaries cross-checked via SIM100)
2. FPS-164 primary parcel layout is documented (Touzeau fig 2 +
   APSIM64 appendix A)
3. XP-32 must (per APAL compatibility) carry every field exercised
   in those — that's the basis for the consensus 128-bit layout's
   first 103 bits

**Sequencer-chip inheritance is broken** — Am29116 appears only on
the FPS-3000. The control-logic implementation differs from family
ancestors. Careful interpretation needed when reasoning about EU
behavior.

## Where to read more

- Family chip-id chain: [`fps164_chip_identification.md`](../notes/fps164_chip_identification.md)
- Curington FPS-5000 papers: `refs/FPS-5000/`
- Hockney chapter: `refs/FPS-5000/FPS3000_fps.pdf`
- Charlesworth FPS-164 paper: `refs/FPS-164/Charlesworth_..._1986.pdf`
- AP-120B reference: `refs/AP-120B/FPS-7319_Programmers_Reference_*`
- Surviving units inventory: `Nakazoto/FloatingPointSystems/KnownSurviving.txt`
