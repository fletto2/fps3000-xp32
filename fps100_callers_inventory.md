# Which files talk to the FPS-100?

Direct survey of the recovered datasets. Two parts: the FPS-100
archive itself (which is the OEM stack and naturally talks to it),
and the Bomem RSX disks (which surprisingly do not).

## Part A — FPS-100 archive (`fps100_archive/fps100sw/[327,010]*`)

The 183-file FPS-100 RSX-11M v3.2 distribution divides into 4 layers
that all talk to the AP at increasing abstraction.

### Layer 0 — RSX kernel device driver

The kernel module that actually owns the AP hardware (CSR `0o176000`,
vector `0o170` by default):

| File | Role |
|---|---|
| `DRIVER.MAC` (`APDRV`) | The driver itself — handles QIO function codes 1 (RUN DMA), 5 (FPS100 supervisor CTL5), 6 (terminate supervisor) |
| `DEVTAB.MAC` | Device + unit control blocks. **Each AP = 2 UCBs**: DMA channel + CTL5 channel |
| `FPSMC.MAC` | Sysgen constants: `A$$P11=1` (number of APs), `APCSR0=0o176000`, `APVEC0=0o170`, `FPS100=1` flag |

### Layer 1 — APEX library (user-mode dispatcher)

The user-mode wrapper that builds QIO directives and submits them
to the AP driver. Exports the API the rest of the stack calls.

| File | Exports |
|---|---|
| `DAPEX.MAC` | `APASGN`, `APRSET`, `RUNDMA`, `RUNAP`, `TSTRUN`, `WTRUN`, `TSTDMA`, `WTDMA`, `APIENA`, `APIDIS`, `APWI`, `TSTINT`, `APIN`, `APOUT`, `SPLDGO` |
| `IAPEX.FTN` | FORTRAN-callable APEX wrappers (integer-mode) |
| `FDAPEX.FTN` | FORTRAN-callable APEX wrappers (double-mode) |

### Layer 2 — Host Service Routines (math-library stubs)

**217 host-callable wrappers**, each a ~12-line stub that builds a
parameter block and calls `JSR APEX`. Mapped to the AP-120B math
library entry points.

| HSR file | Library | Routines |
|---|---|---:|
| `BAAHSR.MAC` | `BAALIB` (Basic Algorithms A) | 88 |
| `BABHSR.MAC` | `BABLIB` (Basic Algorithms B) | 60 |
| `SIGHSR.MAC` | `SIGLIB` (Signal-processing) | 27 |
| `AMLHSR.MAC` | `AMLLIB` (Applied Math) | 23 |
| `IPRHSR.MAC` | `IPRLIB` (Image Processing) | 11 |
| `DGNHSR.MAC` | `DGNLIB` (Diagnostics) | 7 |
| `UTLHSR.MAC` | `UTLLIB` (Utility, just `APNOP`) | 1 |
| **Total** | | **217** |

All 9 matching `*LIB.APO` binary microcode files (62,130 AP-120B
microinstructions) are present. No matching HSR file for `APFLIB`
or `SYMLIB`.

### Layer 3 — User-facing tools

| File | Purpose | Calls AP via |
|---|---|---|
| `ASM100.FTN` | APAL assembler | (offline — produces `.APO` microcode) |
| `LED100.FTN` | Link editor | APEX (loads program to AP for test) |
| `SIM100.FTN` | Simulator | (offline — simulates AP execution) |
| `DBG100.FTN` | Debugger | APEX |
| `ART100.FTN` | Array runner | APEX |
| `MEM100.FTN` | Memory utility | APEX |
| `PTH100.FTN` | Path utility | APEX |
| `UFT100.FTN` | UFT utility | APEX |
| `VFC100.FTN` | Vector-function utility | APEX |
| `FFT100.FTN` | FFT runner | APEX |
| `TST100.FTN` | Test utility | APEX |

### Layer 4 — Test / demo programs

| File | Purpose |
|---|---|
| `RUN1.FTN` … `RUN6.FTN` | Numbered test programs |
| `RUN2X.FTN`, `RUN5X.FTN`, `RUN6X.FTN` | Extended variants |
| `GLBTST.FTN` | Global system test |
| `FFT100.FTN`, `VFC100.FTN`, `TST100.FTN` | (see Layer 3) |

### Call chain

```
user FORTRAN code
    │
    │ CALL ZVMUL(N, A, IA, B, IB, C, IC)
    ▼
HSR stub (one per library entry point — e.g. ZVMUL in BABHSR.MAC)
    │
    │ JSR APEX
    ▼
APEX library (DAPEX.MAC)
    │
    │ QIO$ <function_code, LUN, params>
    ▼
APDRV (DRIVER.MAC) — kernel driver
    │
    │ DMA / programmed I/O at CSR 0o176000
    ▼
AP hardware (FPS-100 / AP-120B)
```

## Part B — Bomem RSX disks: no AP-comm code at all

Searched every recovered CMD, MAC, TSK file for any reference to the
FPS-100 communication path. **All searches returned zero hits**:

| Search target | Pattern | Hits |
|---|---|---:|
| APEX dispatcher symbols | `APEX\|APASGN\|APRSET\|RUNDMA\|RUNAP\|SPLDGO\|APIN\|APOUT` | 0 |
| LUN assignment to AP device | `ALUN.*AP\|ASN.*AP[0-9]\|ASSIGN.*AP[0-9]` | 0 |
| AP device names | `AP[0-9]:\|AP:[0-9]\|\bAP0:\b\|\bAP1:\b` | 0 |
| FPS-100 product strings | `FPS-100\|FPS100\|AP-120\|AP120` | 0 |
| FPS-100 software-stack file names | `APDRV\|APX10\|HSR100\|SUP100\|DRV100\|MIN100\|SUPER100\|MINI100` | 0 |
| Math API strings | `XPMLIB\|MAXL` | 0 |
| AP-typical CSR address (octal) | `176000\|176200` | 0 |

Driver-load list in `VMRBOO5.CMD` (the Bomem boot's actual driver
loads): only standard DEC peripherals — `DL`, `DM`, `DR`, `DU`,
`DY`, `TT`, `LP`, `MS`, `CO`. **No `LOA AP:`.**

## What this means

The recovered Bomem RSX disks contain only the **OS layer** and the
**Bomem-customized OS tasks** (BOMICP/RSX11M/EXCOM1/EXCOM2/FCSRES/
DYCOM/POKE). None of these talk to an FPS-100, an AP-120B, or any
array processor.

Whatever talks to the FPS-100 (or HPVP, if HPVP=FPS-100) on this
Bomem system **lives entirely on the missing BOM* application
disks** (BOM1..BOM13). LOABOM.CMD references files `hpvp.*`,
`hpcoad.*`, `hpregs.*`, `hptest.*`, plus `loahpvp.cmd`, plus
`bomres.*`, `clk50.*`, `grafik.*`, `phk.*`, etc. None of those are
in the recovered dataset.

If those disks are recovered, we'd expect to find:
- the AP driver (`APDRV.TSK` or rebranded `hpvp_drv.tsk`)
- the APEX equivalent (Bomem-rebranded DAPEX wrappers)
- the math-library HSR stubs
- the application-level FTIR co-add code (`hpcoad.*`)
- the host I/F register definitions (`hpregs.*`)
- the hardware test program (`hptest.*`)
- the `loahpvp.cmd` install script

This is also the only way to definitively answer the HPVP-identity
question — `loahpvp.cmd` would name what hardware it's installing
for, and `hpvp.*` driver source would identify the chip set.

## Reverse-engineering implication

If the BOM* disks can't be recovered, the host-side AP I/F
protocol must be reverse-engineered from:

1. The (existing) FPS-100 stack as a reference for what an FPS-100
   driver looks like
2. The 4448 chassis-side AP I/F card netlist
3. Direct bus-trace probing of Lovett's chassis

That's the path the project is currently on. Recovering BOM*
short-circuits a substantial fraction of it.
