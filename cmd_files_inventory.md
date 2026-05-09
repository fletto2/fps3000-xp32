# All `.CMD` files in the recovered datasets — inventory + HPVP evidence

`.CMD` files in RSX-11M are **indirect command files** — RSX's batch
scripts. Lines starting with `.` are indirect-processor directives
(`.ASKS`, `.ASK`, `.IFT`, `.GOTO`, etc.); other lines are MCR
commands. `@filename` invokes a nested script.

Surveyed **42 .CMD files** total:
- 17 in `RSX_v511/extracted/` (Bomem-customized RSX-11M+ V5.1.1)
- 25 in `fps100_archive/fps100sw/[327,010]*.CMD` (FPS-100 RSX-11M v3.2)

## Inventory

### Bomem RSX disks (17 .CMD files)

| File | Size | Author / Date | Purpose |
|---|---:|---|---|
| `LOABOM.CMD;2` | 4 KB | — | **Top-level Bomem app installer**, 13 BOM disks + optional HPVP |
| `RESRSX.CMD;2` | 2 KB | Claude Lafond, 28-dec-84 | Copy RSX floppies (rsx1..rsx11) onto winchester |
| `STARTUPIN.CMD` | — | Claude Lafond | RSX startup for "RSXBOM on winchester" |
| `STARTBOO5.CMD` | — | Ginette Aubertin, 20-oct-85 | Boot-5 startup; `boo bb0:[1,54]rsx11mrsxbom` |
| `STARTBOO{1..4}.CMD` | — | — | Per-boot-disk startup |
| `STARTUP.CMD` (×4) | — | — | Per-disk startup hook |
| `VMRBOO5.CMD` | — | Claude Lafond, 27-dec-84 | VMR for first bootable winchester disk |
| `RSXWINVMR.CMD` | — | — | RSX winchester VMR config |
| `SGNPARM.CMD` | — | — | Sysgen parameters |
| `BIGRSX.CMD` | — | — | Build big RSX |
| `FMTDY.CMD` (Bomem copy) | — | — | DY (RX02) format command |

### FPS-100 archive (25 .CMD files, all dated FEB 80)

| File | Purpose |
|---|---|
| `FIRST.CMD` | First-stage sysgen — asks tape device, BPI, sets `$NOAP=1` |
| `SETUP.CMD` | Common preamble — find TKB, MAC, F4P, LBR, PIP, EDT |
| `MASTER.CMD` | Complete install — runs DRV100 + HSR100 + LIB100 + DGN100 + APL100 + PDSTST + SUP100 |
| `DRV100.CMD` | **AP driver install** — generates `FPSMC.MAC` with `A$$P11=$NOAP`, asks per-AP CSR + vector |
| `HSR100.CMD` | Host service routines library install |
| `LIB100.CMD`* | (referenced; not in archive — possibly tape-only) |
| `APL100.CMD` | AP library install |
| `DGN100.CMD` | Diagnostics install |
| `SUP100.CMD` | Supervisor install — pass 8 from tape |
| `PDS100.CMD` | PDS software install |
| `PDSTST.CMD` | PDS tests |
| `APX10.CMD` `ART10.CMD` `ASM10.CMD` `DBG10.CMD` `LED10.CMD` `MEM10.CMD` `PTH10.CMD` `SIM10.CMD` `UFT10.CMD` `UTL10.CMD` `VFC10.CMD` `FFT10.CMD` `TST10.CMD` | Per-tool-pass installers (assembler, linker, simulator, debugger, etc.) |
| `CLEAN.CMD` | Cleanup |
| `TREAD.CMD` | Tape-reader |

## Key user-prompt questions across all .CMD files

These are the questions that BOM/install scripts ask during sysgen:

| File | Question |
|---|---|
| FPS-100 `FIRST.CMD` | `WHAT IS THE MAGTAPE DEVICE NAME?` (sets `$MM0`) |
| FPS-100 `FIRST.CMD` | `IS THE INSTALLATION TAPE 800 BPI` |
| FPS-100 `DRV100.CMD` | `ENTER CSR LOCATION FOR AP # N` (per AP) |
| FPS-100 `DRV100.CMD` | `ENTER VECTOR LOCATION FOR AP # N` (per AP) |
| Bomem `STARTUPIN.CMD` | `Please enter time and date (13:47 25-dec-84)` |
| Bomem `RESRSX.CMD` | `Enter source drive unit (dy0:)` / destination |
| Bomem `RESRSX.CMD` | `Insert floppy rsx1..rsx11 and press return` |
| Bomem `LOABOM.CMD` | `Enter source drive unit (dy0:)` / destination |
| Bomem `LOABOM.CMD` | `Insert floppy disc "BOM1..BOM13" then push return` |
| Bomem `LOABOM.CMD` | **`Are you using the HPVP processor ?`** |

`FIRST.CMD` defaults `$NOAP` to **1** ("ONE AP IS BEING CONNECTED").
`DRV100.CMD` then asks the customer for one CSR address + one vector
per AP. So the FPS-100 install supports `$NOAP > 1` but ships with
`$NOAP=1` default.

## What this confirms about HPVP

### Critical finding: NO `APDRV` task image in the Bomem RSX disks

I searched every file in `RSX_v511/extracted/`. Every loaded driver
in `VMRBOO5.CMD` is a standard DEC peripheral:

```
LOA DL:   ; RL01/02 disk
LOA DM:   ; RK06/07 disk
LOA DR:   ; RM02/03 disk (Massbus)
LOA DU:   ; MSCP disk
LOA DY:   ; RX02 floppy
LOA TT:   ; terminal
LOA LP:   ; line printer
LOA MS:   ; magtape
LOA CO:   ; console
```

**No `LOA AP:`. No `APDRV.TSK` anywhere on the recovered disks.**
The standard FPS-100 driver is *not* installed in the running Bomem
RSX system.

### What that implies

If HPVP were just the FPS-100, then either:
- (a) `APDRV.TSK` would be present and loaded by `VMRBOO5.CMD`, or
- (b) `LOABOM.CMD` would invoke the FPS-100 install scripts (`@DRV100`,
  `@HSR100` etc.) — but it doesn't.

Neither is true. The actual installer flow is:

```
LOABOM:
  ... copies BOM1..BOM13 (Bomem application disks) ...
  ... runs @iv2drv0 / @mgdrv2  (graphics drivers) ...
  ASK: "Are you using the HPVP processor?"
    YES → run @bb0:[1,54]loahpvp  (NOT IN RECOVERED DATASET)
    NO  → skip
```

So `loahpvp.cmd` (missing from our recovery) is responsible for
installing whatever driver and helper code HPVP needs. The
hardware-presence question `Are you using the HPVP processor?`
strongly implies HPVP is hardware some Bomem customers have and
others don't — making it an **optional, customer-paid upgrade**.

### What HPVP is NOT (defensible)

- **NOT the FPS-100 standard install** (no APDRV anywhere; LOABOM
  doesn't call DRV100/HSR100)
- **NOT a software-only feature** (file naming `hpcoad.*`, `hpregs.*`,
  `hptest.*` looks like driver + register-config + test, all
  hardware-tied)

### What HPVP plausibly IS (inferred)

Most plausible reading: **HPVP is the FPS-3000** (or another
XP-32-class machine). Supporting:

- "High-Performance Vector Processor" matches the XP-32's vector-
  oriented XPMLIB API (`ZVMUL`, `ZVADD`, `ZRFFT`...) more cleanly
  than the FPS-100's scalar pipeline
- Lovett's chassis has both an FPS-100 *and* an FPS-3000 — exactly
  the "standard + HPVP upgrade" topology
- "VPtest" file in the deletion list points at "Vector Processor"
- HPVP being optional matches FPS-3000 being a price-tier option

Cannot be proven from the .CMD evidence alone — `loahpvp.cmd` and
`hpvp.*` files would settle it. They are missing.

### What HPVP could alternately be (less likely)

- A different (non-FPS) array processor brand Bomem also supported
- A Bomem-built coprocessor — unlikely for a spectrometer vendor
- A renamed FPS-100 with Bomem-customized driver (would explain
  no APDRV but still requires HPVP install to bring its own driver)

## Project-impact reframing

If HPVP = FPS-3000, then **the missing BOM* application disks
contain Bomem-customized FPS-3000 host software** — including:

- `loahpvp.cmd` install script (driver build steps)
- `hpvp.*` driver/runtime modules
- `hpcoad.*` co-add / signal-averaging routines
- `hpregs.*` register definitions for the host-side AP I/F card
- `hptest.*` hardware test programs

This is **strictly more valuable** than chasing XPMLIB:
- The driver code would tell us the **host-side AP I/F protocol**
  directly (which we currently reverse-engineer)
- The register definitions would give us the **chassis-side
  command interface** independent of our SBC ROM disassembly
- The test programs would exercise specific hardware paths we
  could trace
- The *combination* with our existing SBC ROM disassembly would
  let us validate both ends of the protocol against each other

Recovery paths for the BOM* disks:

1. **Lovett directly** — does he have the original Bomem floppies
   or know who does?
2. **Other DA3 owners** — per NDACC there are DA3 spectrometers at
   several atmospheric-research sites worldwide; one of them might
   have surviving software
3. **Bomem (now ABB Bomem)** — successor company may have archives
4. **Bomem retirees** — Claude Lafond and Ginette Aubertin are
   named in the existing scripts (1984–85); if findable, they may
   have copies or know where they went

## Updated priority order

| Path | Pre-reframing rank | Post-reframing rank |
|---|---|---|
| Recover Bomem BOM* application disks | low | **HIGH** |
| Read EU PROM on Lovett's chassis | high | high |
| Acquire XPMLIB binary | medium | medium |
| Contact Myron White | medium | medium |
| Build FPGA AP I/F substitute | high | medium (if BOM* recovers) |

The BOM* disks would short-circuit a substantial fraction of the
host-side-protocol work. If they can't be recovered, the FPGA
substitute path remains the active line.
