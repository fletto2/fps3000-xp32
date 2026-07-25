# NASA NTRS survey for FPS array-processor material (2026-07-25)

Sweep of the NASA Technical Reports Server for AP-120B / FPS-100 /
FPS-164 / FPS-5000 / FPS-3000 / XP-32 / APAL material. Two documents
were worth keeping; both are now in `refs/`. **No microcode or APAL
source listings were found.**

## Method and its one important limitation

Queried `https://ntrs.nasa.gov/api/citations/search?q=…` with 13 terms.
Downloaded every hit that had a PDF attached and grepped for
`APAL|microcode|microprogram|S-Pad|DPX|DPY|FADD|FMUL`.

**NTRS `q` indexes metadata and abstracts only — NOT PDF body text.**
Verified by searching two phrases that appear verbatim in the body of
`19850008016`, a document the same search engine does return by title:

| Probe phrase (body text of 19850008016) | Result |
|---|---|
| `"borrowed from another lab for feasibility studies"` | 0 hits |
| `"38 bits are used for floating point numbers"` | 0 hits |

Consequence: **a report carrying an APAL listing in an appendix is
invisible to this search unless its abstract names the array
processor.** The negative result below is therefore weak evidence, not
a clearance. Appendices are exactly where such listings live.

## Result counts

| Query | Hits |
|---|---|
| `"AP-120B"`, `"AP 120B"` | 4 (same 4 records) |
| `"Floating Point Systems"` | 7 |
| `"FPS-100"` | 1 — spurious ("800 fps" in a GE seal report) |
| `"AP-190L"` | 0 |
| `"FPS-164"` | 0 |
| `"FPS-5000"` | 0 |
| `"FPS-3000"` | 0 |
| `"XP-32"` | 0 |
| `XP32 MAXL` | 0 |
| `APAL array processor assembly language` | 0 |
| `array processor microcode listing` | 0 |
| `programmable array processor microprogram FFT` | 0 |

Note the FPS-5000 hits are 0 *by metadata* even though NTRS
`19850008016` contains a section on the FPS-5000 — another instance of
the body-text limitation.

## Kept: NASA-TM-84566 → `refs/AP-120B/`

Strohkorb, G. A. and Noor, A. K. (George Washington Univ. / NASA
Langley), *Potential of minicomputer/array-processor system for
nonlinear finite-element analysis*, June 1983. NASA-TM-84566 / L-15532
/ NAS 1.15:84566, RTOP 505-33-63-01. NTRS ID `19830018988`.

Prime 750 host + AP-120B, performance assessed through **APSIM**. No
listings, but a good independent secondary source on the ancestor
architecture. Relevant content:

- §3.2 AP-120B architecture; §3.3 the **APEX** host driver — translates
  host FORTRAN calls into "function control blocks" shipped to the AP.
  Structurally the same host→AP command-packet idea the FPS-3000 SBC
  implements as panel-command sequences.
- §3.4 confirms **167 ns instruction cycle**, 12 MFLOPS peak (6 MFLOPS
  adder + 6 MFLOPS multiplier), 6M integer/addressing ops/s concurrent.
- §3.5 + §10.4 on APSIM's limitations — simulates AP program execution
  only, **not** host interaction. Same boundary our `SIM100.FTN` work
  runs into.
- Names the full toolchain: APAL (assembler), APLINK (loader/linker),
  APSIM (simulator), ADBUG (debugger), APEX (executive driver), VFC
  (software chaining utility). Note **APLINK**, which is neither
  `LNK100` nor `LED100` — a third name for the link step, worth keeping
  in mind given `LNK100`/`LOD100` are the two files lost from the
  `fps100_archive` tape.

### Appendix A memory spec (cross-check for our AP-120B model)

| Store | Size | Word |
|---|---|---|
| Main-data memory | banks of 4K or 16K, expandable to 320K words | 38-bit |
| Table memory (ROM or RAM) | max 64K words | 38-bit |
| Program memory | max 4K words | **64-bit** |
| Data pads X and Y | 32 floats each | 38-bit |
| Address registers | 16 | 16-bit integer |

Confirms the 64-bit microinstruction width independently of the
`SIM100.FTN` `SPLIT` recipe, and the 2-stage adder / 3-stage multiplier
pipeline depths.

Timing detail worth having: main-data memory is **interleaved** across
odd/even banks; references allowed every 167 ns (fast) or 333 ns (slow)
only while interleave holds, else the AP executes a **"spin"** that
halts all processing. Main-data contents arrive 3 cycles after the
address register is altered; table memory 2 cycles; address and data-pad
registers same cycle. DPX and DPY cannot be referenced in the same
cycle. These are exactly the hazards an APSIM-equivalent has to model.

### Table I — sample vector-routine timings (FPS-supplied)

Directly usable as ground truth when validating cycle counts. `n` =
vector length, times in µs, as startup + per-element:

| Operation | Time (µs) |
|---|---|
| Sum of vector elements | 0.833 + 0.333n |
| Sum of squares | 1.333 + 0.333n |
| Vector add `{A}+{B}` | 2.667 + 0.500n |
| Vector multiply `{A}*{B}` | 2.667 + 0.500n |
| Vector-scalar multiply `A*{B}` | 2.667 + 0.500n |
| Vector-scalar multiply + vector add `A*{B}+{C}` | 3.333 + 0.500n |
| Dot product `{A}ᵀ*{B}` | 3.333 + 0.500n |
| Vector multiply and add `{A}*{B}+{C}` | 3.333 + 0.833n |
| Two multiplies + one add `({A}*{B})+({C}*{D})` | 4.167 + 0.833n |
| Vector divide `{A}/{B}` | 4.167 + 1.667n |

## Kept: NASA-CR-171283 → `refs/FPS-5000/`

Parker, K. G. (New Technology, Inc.), *Atmospheric Modeling And Sensor
Simulation (AMASS) study*, 12 Oct 1984. NASA-CR-171283 / FR1021 /
NAS 1.26:171283, contract NAS8-35189, for NASA Marshall. NTRS ID
`19850008016`.

MSFC array-processor procurement study. Section IV compares six
machines head-to-head: **FPS AP-120B, FPS-5000**, CSPI MAP-400,
Analogic AP500, Numerix MARS-432, Star Technologies ST-100. An FPS
AP-120B was borrowed from another MSFC lab for the evaluation; the
recommendation was to keep using it.

Value to this project: an **independent, contemporaneous (1984)
description of the FPS-5000 co-processor architecture**, i.e. the XP-32
family, from outside FPS's own literature and outside the Curington
papers. Verbatim from §IV:

> A fairly recent addition to the FPS product line is the FPS-5000
> series. […] Note that although the overall system is synchronous, the
> compute processors operate in an asychronous nature in order to
> achieve maximum throughput. Another feature of this series is that
> these multiple compute processors, termed "co-processors," may be
> used in a configuration to enhance performance. The 5200 and 5300
> series are designed to interface with a P-E host and operate in a
> manner similar to the AP-120B.

> Although the currently offered FPS FORTRAN compiler does not support
> the co-processor architecture, a new version offering this support is
> supposedly soon to be released. […] Currently another problem exists
> in programming the FPS — specifically the **64KW page limit**. The new
> compiler is also supposed to correct this problem.

Two things to follow up on. The synchronous-chassis /
asynchronous-compute-processor split corroborates our MIMD reading of
the two independent ACs sharing SCM through MEM CTL. And the **64 KW
page limit** sits suspiciously close to the 64 KB staging buffer at
`0x10000–0x1FFFF` and the 4K × 128-bit WCS bank size — worth deciding
whether it is the same constraint seen from the compiler side or a
coincidence of round numbers.

Also confirms the AP-120B word lengths from the vendor-survey side:
"the data word length and Kable [table] memory word length are each
38 bits; the instruction word length is 64 bits."

### Missing figure plates in the digitized copy

The §IV text calls out three FPS block diagrams that are **not present
in the scan**:

- **Figure 3** — architecture of the AP-120B
- **Figure 4** — FPS-5000 series general architecture design
- **Figure 5** — FPS-5000 system and architecture

Verified as absent rather than misordered: printed page numbers run
continuously 18 (PDF p22), 19 (p23), 20 (p24, the §IV text that
references Figs 3–5), 21 (p25, **Figure 6** = CSPI MAP-400), 22 (p26),
23 (p27, **Figure 7** = Analogic AP500), 24 (p28). The surviving
second-series plates are Figure 1 (p19, FP multiply pipeline stages)
and Figures 6–12. So the plates for Figures 2–5 were dropped at
microfiche/scan time. Two FPS-5000 block diagrams exist on paper but
not in any copy we have. See `notes/sti_request_draft.md`.

## Leads not pursued

- **`19820055680`** — Wu, Barkan, Karplus, Caswell (JPL), *Seasat
  synthetic-aperture radar data reduction using parallel programmable
  array processors*, 1982, contract NAS7-100. SEL 32/77 host driving
  **three AP-120B units** in parallel for production Seasat imagery.
  Implies a substantial real APAL codebase with JPL provenance. NTRS
  holds the citation only, no file (REPRINT — journal version).
- **`19870003657`** — 1985 AMASS extension study, conference paper,
  distribution PUBLIC but **no PDF attached**. Abstract describes
  further FPS-5000-era array-processor evaluation. Requestable.
- **`19840017832`** — *Demodulator and Accumulator for the High-speed
  Data Acquisition System*, 1984. Post-processing done by a "floating
  point systems **5210** array processor" — an FPS-5000-series part
  number we have not otherwise seen. Citation only, no file.
- **`19820063253`** — Landsat-D image registration, 1981. DEC VAX-780
  plus an unnamed FPS array processor. Citation only.

## Reproducing

Query script and raw JSON are not committed; regenerate with the API
directly, e.g.

    curl 'https://ntrs.nasa.gov/api/citations/search?q=%22AP-120B%22&size=25'
    curl -o 19830018988.pdf \
      'https://ntrs.nasa.gov/api/citations/19830018988/downloads/19830018988.pdf'
