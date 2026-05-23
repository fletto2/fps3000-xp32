# DAPEX.MAC — fully annotated reference

Council-of-Clankers analysis (DeepSeek + GLM-4.5-air, cooperative + adversarial). The file is 1294 lines of MACRO-11 from the FPS-100 RSX-11M v3.2 distribution (Rel B.1, Jan 1980), implementing the host-side APEX library. It is the single chokepoint between user code and the AP-120B/FPS-100 kernel driver (APDRV).

Source: `fps100_archive/fps100sw/[327,010]DAPEX.MAC`

---

## DeepSeek — final annotation

(adversarial pass 105s, 25569 chars)

Excellent peer annotation. It provides a solid high-level overview and correctly identifies the major structural elements. However, it contains several significant errors, omissions, and areas of vagueness that need correction for a truly reference-quality document.

Here is a critical evaluation followed by my final, corrected, and comprehensive annotation.

### Critical Evaluation of Peer Annotation

**Correct & Good Points:**
- **File-level overview:** Accurate on purpose, calling convention, and RSX integration model.
- **Data Structures:** Correctly identifies the core globals and their basic purpose.
- **Two-Mode Model:** The table is a good summary of the high-level differences.
- **Call Graph:** Reasonably accurate for the main flow.
- **Two-LUN Architecture:** Correctly identifies the purpose of LUN and LUN1.
- **Glossary:** Mostly correct definitions.

**Errors & Omissions:**

1.  **`APASGN` - `SETCSR` Logic:** The peer says "Forces AP120 mode initially via `SETSUP`." This is correct, but it misses the critical detail that the `SETSUP` QIO$ is issued on **LUN1**, not LUN. This is the entire point of the two-LUN architecture. The peer's description of `SETCSR` is too vague.
2.  **`SPLDGO` - `SBRGO` Path:** The peer says "starts AP (8448)". This is only for the **AP120** path. The value `8448` (octal) is `#8448.` which is decimal 8448 = 0o20400. This is `FN` register value for the AP120 path. The peer fails to distinguish the Mini-100 path (`SBRGO2`) which uses `#8192.` (0o20000, the "continue" bit). This is a major omission.
3.  **`RUNDMA` - Format Handling:** The peer says "Adjusts word count for 16-bit formats (formats 3/4)." This is vague and slightly wrong. The code checks for format 3 or 4 (`BIT R1,#4`) and format 1 (`BIT R1,#2`). If either is true, it doubles the word count (`ASL R0`). This is because these formats transfer 16-bit elements, but the WC register counts 32-bit words. The peer's description is imprecise.
4.  **`APRSET` - `CLR ABRT(R3)`:** The peer omits this crucial step. The reset sequence is: `CLR ABRT(R3)` (reset the AP), then `CLR CTRL(R3)` (clear control), then `MOV #4000,FN(R3)` (set FN to a known state). This is the standard AP-120B reset sequence.
5.  **`APIN`/`APOUT` - Extended Memory Registers:** The peer's description is too simplistic. It says "Special handling for extended memory (MASK/APMAE/MAE via LITES)." The code is much more specific. It reads the `ABRT` register (which is a read-only register that returns the combined state of MASK, APMAE, and MAE) and then masks and shifts to extract the desired field. For writes, it reads `ABRT`, modifies the specific field, and writes the combined result back to the **LITES** register. This is a critical hardware quirk that the peer misses.
6.  **`APIN` - Register 15:** The peer completely misses the special case for register 15, which returns the `SAVLIT` value (a saved copy of LITES from `WTRUN`). This is a diagnostic feature.
7.  **`APOUT` - `L4300`:** The peer says "Cannot write LITES reg" for Super-100 mode. This is correct, but it doesn't explain *why*. In Super-100 mode, the LITES register is managed by the AP's supervisor, not the host. The host's write would conflict.
8.  **`HPUT` - Datum Shifting:** The peer says "Send/receive 13-bit datums." This is correct, but it doesn't explain the *mechanism*. The code shifts the datum left 3 bits and ORs it with the destination address. This is the FPS-100's internal protocol for addressing internal registers (like S-Pads) via the SWR register.
9.  **`HTST` - `FPDAT` Access:** The peer says "Written by `SENDER`, read by `HTST`." This is correct but misses the critical detail that `HTST` disables interrupts (`DSAR$S`) while reading and clearing `FPDAT`. This is a classic critical section to prevent a race condition with the interrupt service routine that fills `FPDAT`.
10. **`IFRUN`:** The peer says "Tests FN register high bit; negative = running." This is backwards. `TST FN(R0); BGE 1$` means if the FN register is *positive* (bit 15 = 0), the AP is running. If it's *negative* (bit 15 = 1), the AP has halted. The code then sets `RUNFG = -1` to indicate a halt. The peer's description is inverted.
11. **`APWD`/`APWR`:** The peer says these are "Macros" that "Wrap QIOW$ function 5 (SETMOD)." This is incorrect. These are **subroutines** (called via `CALL` or `CALLS`), not macros. They are defined elsewhere (likely in a separate file like `APDRV.MAC` or `APUTIL.MAC`). The annotation should state they are external subroutines.
12. **`SENDER` - `APIRT` Bit:** The peer says "interrupts AP (set `APIRT`)". This is correct, but it misses the subtlety that the code first sets `APIRT`, then immediately clears it. This creates a pulse on the interrupt line to the AP, which is the correct way to signal it.
13. **`RDWAIT` Macro:** The peer's description is too simple. The macro has a timeout counter (`SOB R0,L`). If the AP doesn't respond after 65536 iterations, it calls `STOPS 75.` This is a watchdog timer, not an infinite loop.
14. **`VPBAD`:** The peer says "Non-zero if bad CTL5 message received." This is correct, but it doesn't explain *how* it gets set. It's set by the driver (APDRV) when a CTL5 interrupt occurs but the associated message is malformed. The host library checks it in `TSTRUN`/`WTRUN` to detect this condition.
15. **`FPERF`:** The peer says "Set by `SENDER`". This is wrong. `FPERF` is set by the AP's function interpreter in response to an `APOUT` (FN register write) in Super-100 mode. The `SENDER` routine sends the message, and the AP's response (or lack thereof) determines `FPERF`. The host code in `APOUT` checks it after `SENDER` returns.

---

### Final Annotated Reference: DAPEX.MAC (Rel B.1, Jan 1980)

### 1. File-Level Overview

**Purpose:** `DAPEX.MAC` is the host-side, high-level dispatcher library for the FPS-100 array processor on RSX-11M. It provides a Fortran-callable interface for managing the AP lifecycle, executing programs, performing DMA transfers, and handling interrupts. It abstracts the low-level details of the AP-120B hardware and the RSX-11M device driver (`APDRV`).

**Calling Convention:**
- **Public Routines:** Follow the standard RSX-11M Fortran calling convention. The caller pushes arguments onto the stack. On entry, R5 points to a list of argument addresses: `(R5)+` = count, `(R5)+` = addr of arg1, `(R5)+` = addr of arg2, etc. Status or return values are written back to the memory locations pointed to by these addresses.
- **Internal Routines:** Use PDP-11 register conventions. R0-R5 are scratch. R5 is often used as an argument pointer for internal calls. R2, R3, R4 are frequently used to hold the AP CSR address (from `APCSR`).

**RSX Integration Model:**
- **Device Driver:** Relies on `APDRV` (DRIVER.MAC), a kernel-level device driver that handles QIO$ directives.
- **QIO$ Functions:**
    - `1` = `RUNDMA`: Initiate a DMA transfer.
    - `5` = `SETMOD`/`CTL5`: Set AP operating mode or send a control message.
    - `6` = `TERMSUP`: Terminate a supervisor operation.
- **Event Flags:** Used for synchronization between the host task and the driver's interrupt service routines.
    - `RUNEVF` (22): Signaled when the AP program stops or halts.
    - `DMAEVF` (23): Signaled when a DMA transfer completes.
    - `CB5EVF` (24): Signaled when a programmed I/O interrupt (CTL5) occurs.
- **Directives:** Uses `ALUN$`, `ATT$`, `DET$`, `SETF$`, `CLEF$`, `WTSE$`, `MRKT$`, `RDAF$` for resource management and synchronization.

**Dependencies:**
- **`DRIVER.MAC` (APDRV):** The kernel device driver. This file builds QIO$ directives for it.
- **`APUTIL.MAC` (or similar):** Contains the subroutines `APWD`, `APWR`, `APSTOP`, `HPUT`, `HGET`, `HTST`, `LOOKY`, `VIRP`. These are declared `.GLOBL` and called from this file.
- **Conditional Assembly:** The entire file is wrapped in `.IF DF FPS100`. The `.IFT` (if true) and `.IFTF` (if true or false) blocks contain code specific to the FPS-100 (Super/Mini mode) and common code, respectively. The `.ENDC` at the end closes the conditional.

### 2. Data Structures and Globals

| **Name** | **Size** | **Purpose** | **Access Pattern** |
| :--- | :--- | :--- | :--- |
| `RUNFG` | `.WORD` | AP execution state. `0` = stopped, `>0` = running, `<0` = halted. | Set by `RUNAP`, `SPLDGO`, `SENDER`. Read by `TSTRUN`, `WTRUN`, `HTST`, `LOOKY`. |
| `FPLIT` | `.WORD` | Last known value of the AP's LITES register. | Set by `WTRUN` (AP120 mode) or `SENDER` (Super mode). Read by `APIN`, `LOOKY`. |
| `FPERF` | `.WORD` | Function interpreter error flag (Super-100 mode). `0` = success, `1` = unimplemented function. | Set by the AP's response to a function register write. Checked by `APOUT`. |
| `FPDAT` | `.BLKW 8` | Buffer for 8 datums received from the FPS-100 supervisor (via `HPUT`/`HGET` protocol). | Written by the driver's interrupt handler. Read and cleared by `HTST` (with interrupts disabled). |
| `VPBAD` | `.WORD` | "Virtual Packet Bad" flag. Set by the driver (`APDRV`) if a CTL5 message from the AP is malformed. | Checked by `TSTRUN` and `WTRUN`; triggers a fatal error (`STOPS 81.`). |
| `VGLOB` | `.WORD` | Global variable. Purpose is unclear from this file; likely used by other modules. | Declared but not referenced in `DAPEX.MAC`. |
| `SUPVR` | `.WORD` | Supervisor mode flag. `0` = AP120 mode, `>0` = Super-100 mode, `<0` = Mini-100 mode. | Set by `APSUPV`. Tested by almost every routine to select the correct code path. |
| `FPOPT` | `.BLKW 4` | Message parameter block for `SENDER`. Contains 4 words: `FPOPT` (option), `FPSCT` (S-Pad count), `FPSWR` (SWR value), `FPFNR` (FN value). | Prepared by `APOUT`, `RUNAP`, `SPLDGO`. Read by `SENDER`. |
| `CSRTBL` | `.REPT A$$P11` | Table of physical CSR addresses for each possible AP unit. | Indexed by unit number (0-based) in `APASGN` to set `APCSR`. |
| `APCSR` | `.WORD` | The physical address of the assigned AP's CSR block. | Set once by `APASGN`. Used as a base pointer for all hardware register access. |
| `SAVLIT` | `.WORD` | Saved copy of the LITES register, captured by `WTRUN` in AP120 mode. Used by `APIN` for register 15 (diagnostics). | Written by `WTRUN`. Read by `APIN`. |
| `IOSB` | `.BLKW 2` | I/O Status Block for QIO$ directives. | Used by `APASGN`, `APRLSE`, `APSUPV`, `RUNDMA`. |
| `IFLG` | `.WORD` | Internal flag for `APASGN`'s "assign any" loop. Set to 1 if at least one unit was successfully assigned. | Used only within `APASGN`. |
| `FLGBUF` | `.BLKW 4` | Buffer for `RDAF$` directive in `TSTINT`. | Used only within `TSTINT`. |

### 3. Subroutine Catalog

#### Public Routines (Fortran-Callable)

##### `APASGN` (Line ~239)
- **Purpose:** Assign an FPS-100 unit to the calling task.
- **Args:** `APNO` (0=any, >0=specific), `ACTION` (0=wait, 1=no wait), `STATUS`.
- **Returns:** `STATUS` = APNO (>0) on success, -1 (in use), -2 (unavailable), or a directive error code.
- **Effect:**
    1.  If `APNO=0`, loops through units 0 to `A$$P11-1` trying to assign and attach.
    2.  If `APNO>0`, assigns the specific unit.
    3.  On successful attach, calls `SETCSR`:
        - Sets event flags `RUNEVF`, `DMAEVF`, `CB5EVF`.
        - **FPS100 only:** Assigns a second LUN (`LUN1`) via `ASGN2` for supervisor commands.
        - Sets `APCSR` from `CSRTBL`.
        - Performs a hardware reset: `CLR CTRL(R0)`, `MOV #4000,FN(R0)`.
        - **FPS100 only:** Issues a `SETSUP` QIO$ on `LUN1` to force the AP into AP120 mode (`MODE=0`). This is the initial state.
- **Two-LUN Architecture:** This routine establishes the two-LUN model. `LUN` (3) is for DMA and standard operations. `LUN1` (4) is for mode-setting and supervisor control.

##### `APRLSE` (Line ~360)
- **Purpose:** Release the AP and detach from the task.
- **Args:** None.
- **Effect:**
    1.  Checks if AP is assigned (`APCON`).
    2.  Calls `APWD` to wait for any pending DMA.
    3.  **FPS100 only:** Issues `CANSUP` to cancel any supervisor mode in the driver, then `TERM` (QIOW$ function 6) to finish any pending driver I/O.
    4.  Clears `APCSR` to zero.
    5.  Issues `DETACH` directive.

##### `APSUPV` (Line ~370)
- **Purpose:** Inform the library of the AP's operating mode.
- **Args:** `MODE` (0=AP120, >0=Super-100, <0=Mini-100).
- **Effect:**
    1.  Stores `MODE` in `SUPVR`.
    2.  If `MODE != 0` (Super/Mini):
        - Clears `RUNFG`.
        - Enables CTL5 interrupt (`IHCB5`) in the hardware.
        - Issues a `STSUP2` QIO$ on `LUN1` to tell the driver the new mode.
    3.  If `MODE == 0` (AP120):
        - Issues `CANSUP` to tell the driver to revert to AP120 mode.

##### `SPLDGO` (Line ~377)
- **Purpose:** Load S-Pad parameters and start an AP program.
- **Args:** `SLIST` (array of S-Pad values), `NSPADS` (count), `STRT` (start address), `BRKLOC` (breakpoint address).
- **Effect:**
    1.  Calls `APWR` to wait for AP to stop.
    2.  **AP120/Mini-100 Path (`SUPVR <= 0`):**
        - Clears `RUNEVF`.
        - Loads S-Pads by writing address to `SWR`, then function `513.` (write S-Pad), then value to `SWR`, then function `517.` (load S-Pad).
        - **AP120 (`SUPVR == 0`):** Writes `STRT` to `SWR`, function `515.` (set TMA). Writes `8.` to `SWR`, function `512.` (set PSA to boot-strap starter). Clears `SWR`, function `518.` (clear APSTAT). Writes `BRKLOC` to `SWR`, function `8448.` (start AP with breakpoint).
        - **Mini-100 (`SUPVR < 0`):** Writes `STRT` to `SWR`, function `512.` (set PSA directly). Writes `8192.` to `FN` (set continue bit).
        - Enables halt interrupt (`IHHALT`).
    3.  **Super-100 Path (`SUPVR > 0`):**
        - Prepares `FPOPT` with `OPTSPD`, `FPFNR` with `STRT`, `FPSWR` with `BRKLOC`.
        - Calls `SENDER` to send a message to the AP supervisor.
        - Then sends S-Pad values one by one via `SENDER` with `R0=0` (APEX message type).

##### `RUNAP` (Line ~440)
- **Purpose:** Start an AP program from a given PSA.
- **Args:** `PSA`, `NOLOAD` (0=load PSA, non-zero=don't), `SWR`, `FN`.
- **Effect:**
    1.  Calls `APWR`.
    2.  **AP120/Mini-100 Path:**
        - Clears `RUNEVF`.
        - Clears parity enable (FN 518).
        - Optionally loads `PSA` (FN 512).
        - Clears parity error enable (FN 1030).
        - Writes `SWR` value.
        - Constructs final `FN` value: takes `FN` arg, masks to keep only breakpoint bits, ORs with `8192.` (continue bit). **Mini-100:** Clears breakpoint bits (`CLR R0`).
        - Writes final `FN` to start AP.
        - Enables halt interrupt (`IHHALT`).
    3.  **Super-100 Path:**
        - Prepares `FPOPT` with `OPTAPR`, `FPFNR` with `PSA`, `FPSWR` with `SWR`.
        - Calls `SENDER`.

##### `TSTRUN` (Line ~490)
- **Purpose:** Test if the AP program has finished without waiting.
- **Args:** `I` (return value).
- **Returns:** `I` = 0 (running), 1 (stopped).
- **Effect:**
    1.  Checks `VPBAD` for errors.
    2.  **AP120/Mini-100 Path:** Tests the sign bit of the `FN` register. If positive (bit 15=0), AP is running, return 0. If negative, AP has halted, return 1.
    3.  **Super-100 Path:** Calls `IFRUN` to update `RUNFG`. Returns `1 - RUNFG`.

##### `WTRUN` (Line ~510)
- **Purpose:** Wait for the AP program to finish.
- **Args:** `IERR` (return value).
- **Returns:** `IERR` = 0 (normal stop), 1 (SRAO error), 2 (parity error) for AP120. For Mini-100, returns LITES value. For Super-100, returns `FPLIT`.
- **Effect:**
    1.  Checks `VPBAD`.
    2.  **AP120 Path:** Waits on `RUNEVF`. Saves LITES to `SAVLIT`. Reads AP status (FN 1030). Checks LITES for parity (bit 7) or SRAO (bit 5) error.
    3.  **Mini-100 Path:** Waits on `RUNEVF`. Returns the LITES register value.
    4.  **Super-100 Path:** Polls `RUNFG` and the hardware `FN` register. If AP halts, sets `FPLIT` and `RUNFG` to -1. Returns `FPLIT`.

##### `RUNDMA` (Line ~594)
- **Purpose:** Initiate a DMA transfer between host and AP memory.
- **Args:** `HOST` (host address), `APMA` (AP address), `N` (word count), `CTRL` (control bits).
- **Effect:**
    1.  Calls `APWD` to wait for any previous DMA.
    2.  Sets AP memory address (`APMA`).
    3.  Calculates word count. If format 1, 3, or 4 (16-bit elements), doubles the count for the WC register (which counts 32-bit words).
    4.  Sets the WC register.
    5.  Calculates byte count for the QIO$ (word count * 2).
    6.  Clears old DMA bits in the hardware `CTRL` register.
    7.  Sets the new control bits (without the GO bit).
    8.  Issues a `QIO$` (function 1) to the driver, which sets the host address and starts the DMA.

##### `TSTDMA` (Line ~634)
- **Purpose:** Test if a DMA transfer is complete.
- **Args:** `I` (return value).
- **Returns:** `I` = 0 (done), 1 (busy).
- **Effect:** Returns the state of the `HDMAGO` bit (bit 0) in the hardware `CTRL` register.

##### `WTDMA` (Line ~648)
- **Purpose:** Wait for a DMA transfer to complete.
- **Args:** `IERR` (return value).
- **Returns:** `IERR` = data-late bit from the CTRL register.
- **Effect:** Waits on `DMAEVF`. Returns the upper byte of the hardware `CTRL` register (which contains status bits like data late).

##### `APRSET` (Line ~667)
- **Purpose:** Perform a complete hardware and software reset of the AP.
- **Args:** None.
- **Effect:**
    1.  Resets hardware: `CLR ABRT(R3)` (pulse reset), `CLR CTRL(R3)`, `MOV #4000,FN(R3)`.
    2.  **FPS100 only:** Clears `RUNFG`, `SUPVR`, `FPLIT`, `FPSWR`, `FPERF`. Issues `CANSUP` to driver.
    3.  Sets all three event flags (`RUNEVF`, `DMAEVF`, `CB5EVF`) to the "set" state.

##### `APIENA` (Line ~701)
- **Purpose:** Enable programmed AP interrupts (CTL5).
- **Args:** None.
- **Effect:** **AP120 mode only.** Clears `CB5EVF`. Sets the `IHCB5` bit in the hardware `CTRL` register.
- **Error:** `STOPS 80.` if called in Super/Mini mode.

##### `APIDIS` (Line ~720)
- **Purpose:** Disable programmed AP interrupts.
- **Args:** None.
- **Effect:** **AP120 mode only.** Clears the `IHCB5` bit in the hardware `CTRL` register.
- **Error:** `STOPS 80.` if called in Super/Mini mode.

##### `APWI` (Line ~740)
- **Purpose:** Wait for a programmed AP interrupt.
- **Args:** None.
- **Effect:** **AP120 mode only.** Waits on `CB5EVF`.
- **Error:** `STOPS 80.` if called in Super/Mini mode.

##### `TSTINT` (Line ~760)
- **Purpose:** Test if a programmed AP interrupt has occurred.
- **Args:** `FLAG` (return value).
- **Returns:** `FLAG` = 0 (no interrupt), 1 (interrupt occurred).
- **Effect:** **AP120 mode only.** Uses `RDAF$` to read the event flag state. Checks if `CB5EVF` (bit 24) is set.
- **Error:** `STOPS 80.` if called in Super/Mini mode.

##### `APIN` (Line ~800)
- **Purpose:** Read an AP interface register.
- **Args:** `DATA` (return value), `NUM` (register number).
- **Register Numbers:** 1=SWR, 2=FN, 3=LITES, 4=APMA, 5=HMA, 6=WC, 7=CTRL, 8=FMTH, 9=FMTL, 10=RESET, 11=IFSTAT, 12=MASK, 13=APMAE, 14=MAE, 15=SAVLIT.
- **Effect:**
    - **Super-100 Mode (regs 1-3):** Returns values from globals (`FPSWR`, `FPFNR`, `FPLIT`).
    - **All Modes (regs 4-11):** Direct read from hardware register via `TABLE`.
    - **All Modes (regs 12-14):** Reads the `ABRT` register, which returns a combined value of MASK, APMAE, and MAE. Then masks and shifts to extract the requested field.
    - **All Modes (reg 15):** Returns `SAVLIT` (diagnostic).
- **Note:** Reading `SWR` or `LITES` directly from hardware can disrupt the communication protocol with the AP supervisor. The library uses software copies instead.

##### `APOUT` (Line ~870)
- **Purpose:** Write to an AP interface register.
- **Args:** `DATA` (value to write), `NUM` (register number).
- **Effect:**
    - **Super-100 Mode (regs 1-3):**
        - `SWR`: Stores value in `FPSWR`.
        - `FN`: Stores value in `FPFNR`, then calls `SENDER` with `OPT=OPTFNR` to send the function to the AP. Checks `FPERF` for errors.
        - `LITES`: **No-op.** The supervisor owns this register.
    - **All Modes (regs 4-11):** Direct write to hardware register via `TABLE`.
    - **All Modes (regs 12-14):** Reads the `ABRT` register, modifies the specific field (MASK, APMAE, or MAE), and writes the combined result to the **LITES** register. This is the hardware's method for setting these extended memory registers.

#### Internal Routines

##### `SENDER` (Line ~248)
- **Purpose:** Send a message to the FPS-100 supervisor (Super/Mini mode only).
- **Inputs:** `R0` (datum, 0 for APEX message), `FPOPT`, `FPSCT`, `FPSWR`, `FPFNR` (global).
- **Effect:**
    1.  Waits for AP to be ready (`RDWAIT`).
    2.  Writes `R0` to `SWR`.
    3.  Pulses the `APIRT` bit in `CTRL` to interrupt the AP.
    4.  If `R0 != 0` (HPUT message), returns.
    5.  If `R0 == 0` (APEX message):
        - Sets `RUNFG` to indicate AP is running.
        - Enables `IHCB5` interrupt.
        - Sends the 4-word message from `FPOPT` block via `SWR`, using `RDWAIT` between each word.

##### `IFRUN` (Line ~232)
- **Purpose:** Check if the AP hardware is running.
- **Effect:** Tests the sign bit of the `FN` register. If negative (bit 15=1), the AP has halted, and `RUNFG` is set to -1.

##### `RDWAIT` (Macro, Line ~455)
- **Purpose:** Wait for the AP to read the `SWR` register.
- **Effect:** Loops, testing the `FN` register. The AP sets bit 15 of `FN` when it has read `SWR`. Includes a timeout counter; if it expires, calls `STOPS 75.`

##### `APCON` (Macro, Line ~430)
- **Purpose:** Assert that the AP has been assigned.
- **Effect:** Tests `APCSR`. If zero, jumps to `XSTOP` which calls `APSTOP` with error 101.

##### `APWD`, `APWR`, `APSTOP`, `HPUT`, `HGET`, `HTST`, `LOOKY`, `VIRP`
- These are declared `.GLOBL` and are defined in another module (e.g., `APUTIL.MAC`).
- `APWD`: Waits for DMA to stop.
- `APWR`: Waits for the AP program to stop.
- `APSTOP`: Fatal error handler.
- `HPUT`/`HGET`/`HTST`: High-level host-AP communication for Super/Mini mode. `HPUT` sends a datum, `HGET` waits for and retrieves a datum, `HTST` tests for a datum's availability.
- `LOOKY`/`VIRP`: Debug routines.

### 4. The Two-Mode Model

| **Aspect** | **AP120 Mode (`SUPVR == 0`)** | **Super-100/Mini-100 Mode (`SUPVR != 0`)** |
| :--- | :--- | :--- |
| **Control Model** | Host directly controls AP via CSR register reads/writes. | Host communicates with an embedded supervisor in the AP via a message protocol. |
| **AP Start** | Direct writes to `SWR` and `FN` registers. | `SENDER` subroutine sends a message block to the supervisor. |
| **S-Pad Loading** | Direct writes to `SWR` and `FN` registers. | `SENDER` subroutine sends values. |
| **DMA** | Supported via `RUNDMA`/`TSTDMA`/`WTDMA`. | Not used. Data transfer is via the message protocol. |
| **Interrupts (CTL5)** | `APIENA`/`APIDIS`/`APWI`/`TSTINT` are functional. | These routines return an error (`STOPS 80.`). The supervisor manages interrupts. |
| **Register Access** | `APIN`/`APOUT` read/write hardware directly. | `APIN`/`APOUT` for registers 1-3 use software globals (`FPSWR`, `FPFNR`, `FPLIT`). Writing LITES is a no-op. |
| **Host-AP Data** | Via DMA. | Via `HPUT`/`HGET`/`HTST` (13-bit datums). |
| **Error Handling** | Checks hardware LITES for parity/SRAO errors. | Checks `FPERF` for unimplemented function errors. |

### 5. Call Graph

```
APASGN
  ├── ANYAP -> TRYAGN -> NEXT -> WAIT -> WAIT1
  ├── NOWAIT -> TOLATE
  └── SETCSR -> ASSIGN, ASGN2, SETSUP

APRLSE -> APWD, CANSUP, TERM, DETACH

APSUPV -> CANSUP, STSUP2

SPLDGO -> APWR, SENDER (Super only)
RUNAP   -> APWR, SENDER (Super only)

TSTRUN -> IFRUN (Super only)
WTRUN  -> IFRUN (Super only)

RUNDMA -> APWD, QIO$(1)

APRSET -> CANSUP

APIENA -> CLRCL5
APIDIS -> (direct CSR write)
APWI   -> WTAP
TSTINT -> RDFLG

APIN  -> (direct CSR read or global read)
APOUT -> SENDER (Super only, for FN write)

HPUT -> SENDER
HGET -> HTST -> IFRUN
```

### 6. The Two-LUN Architecture

The FPS-100 requires two logical unit numbers (LUNs) for proper operation under RSX-11M.

- **`LUN` (3): The Primary Interface.**
    - Used for all DMA operations (`RUNDMA`).
    - Used for standard AP control (attach, detach).
    - The driver's primary function codes (1, 6) are issued on this LUN.

- **`LUN1` (4): The Supervisor/Mode-Setting Interface.**
    - Used exclusively for the `SETMOD` (function 5) QIO$.
    - This is used to:
        - Force the AP into AP120 mode on initialization (`SETSUP` in `APASGN`).
        - Inform the driver of a mode change to Super/Mini (`STSUP2` in `APSUPV`).
        - Cancel the supervisor mode (`CANSUP` in `APRLSE`, `APRSET`, `APSUPV`).
- **Rationale:** This separation allows the driver to maintain different internal states for the two interfaces. The supervisor commands on `LUN1` can be processed without interfering with a potentially active DMA transfer on `LUN`. It also allows the driver to properly manage the different interrupt vectors and completion routines associated with each mode.

### 7. Glossary of FPS-Specific Terms

| **Term** | **Definition** |
| :--- | :--- |
| **S-Pad** | Scratch Pad memory inside the AP-120B. A small, fast memory used for parameters and temporary values. |
| **PSA** | Program Start Address. The memory address in the AP where program execution begins. |
| **TMA** | Temporary Memory Address. An alias for the AP Memory Address register (`APMA`), used in `SPLDGO` to set a starting address for a loader routine. |
| **APSTAT** | AP Status Register. An internal AP register that holds status flags (e.g., parity error enable). Accessed via function code 518. |
| **LITES** | A 16-bit read/write register on the AP-120B front panel. Used for status display and, in this context, for reading error codes and writing extended memory registers. |
| **SWR

---

## GLM-4.5-air — final annotation

(adversarial pass 166s, 41218 chars)

I need to analyze the provided code for DAPEX.MAC, a vintage minicomputer assembly file that serves as a host-side dispatcher library for the FPS-100 array processor under RSX-11M. Let's start by understanding the file structure and components.

### File-Level Overview

This file contains the interface for the FPS-100 array processor on a PDP-11 running RSX-11M. The FPS-100 could operate in different modes:
- AP120 mode (direct host control)
- Super-100 mode (with embedded supervisor)
- Mini-100 mode (simplified supervisor)

The library provides FORTRAN-callable routines for:
1. AP assignment and release (APASGN, APRLSE)
2. Supervisor mode management (APSUPV)
3. Program loading and execution (SPLDGO, RUNAP, TSTRUN, WTRUN)
4. DMA operations (RUNDMA, TSTDMA, WTDMA)
5. AP control (APRSET, APIENA, APIDIS, APWI)
6. Register I/O (APIN, APOUT)
7. Host-AP communication (HPUT, HGET, HTST)
8. Debugging utilities (LOOKY, VIRP)

The code uses two LUNs per AP processor: one for DMA and basic operations (LUN0) and one for supervisor communication (LUN1).

### Data Structures and Globals

Let's examine the data structures and global variables defined in the file:

**Parameter Block (must be in this order for driver):**
- RUNFG: AP execution status (0=stopped, >0=running, <0=halted)
- FPLIT: Last LITES register value
- FPERF: Function interpreter error flag
- FPDAT(8): Storage for datum values from FPS-100
- VPBAD: Bad CTL5 message flag

**FPS-100 Variables:**
- VGLOB: Global variable (unused)
- SUPVR: Supervisor mode (0=no supervisor, >0=Super-100, <0=Mini-100)
- FPOPT(4): Option word for SENDER messages
  - FPSCT: S-Pad count for SENDER
  - FPSWR: Switch register value for SENDER
  - FPFNR: Function register value for SENDER

**Other Globals:**
- CSRTBL: Table of AP CSR addresses
- APCSR: Current AP CSR address
- IOSB: I/O Status Block for QIO directives
- IFLG: Flag for "any AP" assignment loop
- UNIT: Current AP unit number
- UNIT1: Second LUN unit number
- SAVLIT: Saved LITES value for diagnostics
- FLGBUF: Event flag storage for RDAF$

### Subroutine Catalog

Let's go through each subroutine in the file, analyzing its purpose, flow, and important details.

#### APASGN
Purpose: Assign an AP processor to the calling task.
- Arguments: APNO (processor number), ACTION (wait flag), STATUS (return value)
- Flow:
  - If APNO=0, tries all processors in ANYAP loop
  - If APNO>0, tries to assign that specific processor
  - On success, calls SETCSR to configure event flags and CSR address
  - For FPS100, also assigns second LUN (UNIT1) and forces AP120 mode
- Edge cases: Returns -1 if processor busy, -2 if not available, directive errors return DSW, I/O errors return IOSB

#### APRLSE
Purpose: Release an AP processor.
- Flow:
  - Checks AP is assigned
  - Waits for DMA to stop
  - For FPS100: cancels supervisor mode, terminates driver I/O
  - Detaches from processor
- RSX Directives: QIOW$ (function 6=TERMSUP), DETACH

#### APSUPV
Purpose: Indicate AP supervisor on/off.
- Arguments: MODE (0=no supervisor, >0=Super-100, <0=Mini-100)
- Flow:
  - Saves MODE to SUPVR
  - If MODE=0, cancels supervisor in driver
  - If MODE≠0, enables CB5 interrupts, issues SETSUP QIO with mode value
- Hardware Effect: Enables IHCB5 bit in CTRL register

#### SPLDGO
Purpose: S-Pad Load and Go - load S-pad values and start AP program.
- Arguments: SLIST (array of S-pad values), NSPADS (number of S-pads), STRT (starting address), BRKLOC (breakpoint)
- Flow varies by mode:
  - AP120 mode: Direct register writes to load S-pads and start program
  - Mini-100: Direct PSA write with continue bit
  - Super-100: Sends messages via SENDER protocol

#### RUNAP
Purpose: Start an AP program at a given PSA.
- Arguments: PSA (program start), NOLOAD (load flag), SWR (switch value), FN (function value)
- Flow varies by mode:
  - AP120 mode: Direct register writes to load PSA and start program
  - Mini-100: Similar to AP120 but clears breakpoint bits
  - Super-100: Sends messages via SENDER protocol

#### TSTRUN
Purpose: Test if AP program has completed (non-blocking).
- Arguments: I (return value)
- Flow varies by mode:
  - AP120 mode: Checks FN register sign bit
  - Super-100: Computes 1-RUNFG
  - Mini-100: Same as AP120

#### WTRUN
Purpose: Wait for AP program to complete (blocking).
- Arguments: IERR (error code)
- Flow varies by mode:
  - AP120 mode: Waits for RUNEVF, checks LITES for errors
  - Mini-100: Returns LITES value directly
  - Super-100: Loops until RUNFG ≤ 0 or AP halted

#### RUNDMA
Purpose: Start a DMA transfer between host and AP memory.
- Arguments: HOST (host address), APMA (AP address), N (word count), CTRL (control bits)
- Flow:
  - Waits for previous DMA to stop
  - Sets up APMA, WC, CTRL registers
  - Issues QIO$ IO.WLB to start DMA
- Hardware Effect: Writes to APMA, WC, CTRL registers

#### TSTDMA
Purpose: Test if DMA transfer is complete (non-blocking).
- Arguments: I (0=busy, 1=complete)
- Flow: Returns bit 0 of CTRL register (HDMAGO bit)

#### WTDMA
Purpose: Wait for DMA transfer to complete (blocking).
- Arguments: IERR (data late bit)
- Flow: Waits for DMAEVF, returns data late indicator from CTRL register

#### APRSET
Purpose: Reset AP hardware to known state.
- Flow:
  - Resets ABRT, CTRL, FN registers
  - For FPS100: clears RUNFG, SUPVR, cancels supervisor, etc.
  - Sets all three event flags

#### APIENA
Purpose: Enable programmed AP interrupt (CTL5).
- Flow:
  - For FPS100: errors if supervisor running
  - Clears CB5EVF event flag
  - Sets IHCB5 bit in CTRL register

#### APIDIS
Purpose: Disable programmed AP interrupt (CTL5).
- Flow:
  - For FPS100: errors if supervisor running
  - Clears IHCB5 bit in CTRL register

#### APWI
Purpose: Wait for programmed AP interrupt (CTL5).
- Flow:
  - For FPS100: errors if supervisor running
  - Waits for CB5EVF event flag

#### TSTINT
Purpose: Test if programmed interrupt has occurred (non-blocking).
- Arguments: FLAG (0=no interrupt, 1=interrupt occurred)
- Flow:
  - For FPS100: errors if supervisor running
  - Reads event flags via RDAF$
  - Checks bit 24 (CB5EVF) in FLGBUF+2

#### APIN
Purpose: Read an AP interface register.
- Arguments: DATA (returned value), NUM (register number 1-15)
- Flow varies by mode:
  - AP120 mode: Reads directly from hardware registers
  - Super-100: Returns cached values from FPSWR, FPFNR, FPLIT
  - Mini-100: Same as AP120

#### APOUT
Purpose: Write to an AP interface register.
- Arguments: DATA (value to write), NUM (register number 1-15)
- Flow varies by mode:
  - AP120 mode: Writes directly to hardware registers
  - Super-100: Caches values, uses SENDER for function register
  - Mini-100: Same as AP120

#### Internal Helpers

Let's analyze the internal helper routines:

#### SENDER
Purpose: Send a message to the FPS-100 supervisor.
- Arguments: R0=datum, FPOPT/FPSCT/FPSWR/FPFNR set by caller
- Flow:
  - RDWAIT for AP to read previous SWR
  - Writes R0 to SWR register
  - Interrupts AP via CTRL
  - If R0=0 (APEX message), sends 4 words from FPOPT
  - If R0≠0 (HPUT message), returns immediately

#### SEND4
Purpose: Send 4 message words to FPS-100.
- Flow: Loop 4 times, each writing a word to SWR after RDWAIT

#### SDUN
Purpose: Sender done - restore R2 and return.

#### NOWAIT
Purpose: Handle non-waiting attach in APASGN.
- Flow: Issues ATT, checks IOSB; if busy, detaches and returns -1

#### TOLATE
Purpose: Handle case where processor is already attached.
- Flow: Detaches, returns -1

#### DIRER
Purpose: Handle directive error.
- Flow: Returns DSW value in status argument

#### IOER
Purpose: Handle I/O error.
- Flow: Returns IOSB value in status argument

#### ANYAP
Purpose: Scan all AP processors to find an available one.
- Flow: Loops through unit numbers, tries ALUN$+ATT on each

#### TRYAGN
Purpose: Try next processor in ANYAP loop.

#### BUSY
Purpose: Handle busy processor in ANYAP.
- Flow: Detaches, continues to NEXT

#### NEXT
Purpose: Increment unit number and check if more processors exist.

#### WAIT/WAIT1
Purpose: Wait and retry processor assignment.
- Flow: Issues MRKT$ (5-minute mark) then WTSE$, jumps back to ANYAP

#### SETCSR
Purpose: Configure CSR address and event flags after successful attach.
- Flow:
  - Sets DMAEVF, RUNEVF, CB5EVF event flags
  - For FPS100: assigns second LUN (UNIT1)
  - Sets APCSR from CSRTBL
  - Clears CTRL register, sets FN=4000
  - For FPS100: forces AP120 mode via SETSUP QIO

#### ASSIGN/ASGN2
Purpose: ALUN$ directive definitions for LUN and LUN1.

#### SETSUP
Purpose: QIO$ definition for mode set (function 5).
- Parameters: IRUNFG (RUNFG address), 11 words, mode value

#### ATT/ATTW/DETACH
Purpose: QIO$ definitions for attach, attach-and-wait, detach.

#### MARK/TWAIT
Purpose: MRKT$ and WTSE$ definitions for wait/retry.

#### SETF
Purpose: SETF$ definition for event flag setting.

#### IFRUN
Purpose: Check if AP hardware is running.
- Flow: Tests FN register sign bit; if negative, sets RUNFG=-1

#### XSTOP
Purpose: Error handler for unassigned AP.
- Flow: Calls APSTOP(101)

#### ERR
Purpose: DMA error handler.
- Flow: Calls APSTOP(7)

### The Two-Mode Model

The file handles three modes of AP operation, controlled by the SUPVR variable:

1. **AP120 Mode (SUPVR = 0)**:
   - Direct hardware register access
   - Host directly controls AP
   - Event flag synchronization
   - Used by most routines

2. **Super-100 Mode (SUPVR > 0)**:
   - FPS-100 runs embedded supervisor
   - Communication via message protocol
   - Cached register access
   - Limited interrupt capabilities

3. **Mini-100 Mode (SUPVR < 0)**:
   - Similar to Super-100 but simplified
   - Direct register access for some operations
   - No breakpoint support

### The Two-LUN Architecture

The FPS-100 uses two LUNs per physical AP processor:

1. **LUN0 (base unit)**:
   - Purpose: DMA transfers and standard AP control
   - Used by: RUNDMA, TERM
   - Event flags: DMAEVF, RUNEVF

2. **LUN1 (UNIT+1)**:
   - Purpose: Mode setting and supervisor communication
   - Used by: SETSUP, CANSUP
   - Event flags: RUNEVF, CB5EVF

This architecture allows for concurrent DMA and supervisor operations.

### Glossary of FPS-Specific Terms

I'll now go through the specific terms used in the code:

1. **S-Pad**: Scratch-pad memory locations (512 words) for temporary storage
2. **PSA**: Program Start Address where AP execution begins
3. **TMA**: Table Memory Address for constants/tables
4. **APSTAT**: AP Status Register for error control
5. **SWR**: Switch Register for host-to-AP communication
6. **FN**: Function Register that controls AP operations
7. **LITES**: Lights Register for AP-to-host communication
8. **CTRL**: Control Register for DMA and interrupt control
9. **WC**: Word Count Register for DMA transfers
10. **HMA/APMA**: Host/AP Memory Address registers for DMA
11. **ABRT**: Reset/Abort register
12. **FMTH/FMTL**: Format registers for DMA data packing
13. **CTL5**: Control Bit 5 for programmed interrupts
14. **SRAO**: Status Register Address Out error condition
15. **GPIOP**: General Purpose I/O Processor for diagnostics
16. **IOSB**: I/O Status Block for QIO completion status
17. **DSW**: Directive Status Word for RSX-11M directive errors
18. **Event Flags**: RSX-11M synchronization primitives
19. **ALUN$**: RSX-11M directive to associate a LUN with a device
20. **QIO$**: RSX-11M directive for device I/O operations

Now I'll evaluate the peer's annotation and create a more complete reference.

### Evaluation of Peer's Annotation

The peer's annotation is generally good but has several areas for improvement:

**Strengths:**
1. Correctly identified the two-LUN architecture and its purpose
2. Accurately described the three modes of operation (AP120, Super-100, Mini-100)
3. Most subroutine descriptions are detailed and accurate
4. Included the call graph which is helpful

**Areas for Improvement:**
1. **Missing Subroutines**: Did not cover internal helper routines like SENDER, SDUN, etc.
2. **Incomplete Edge Cases**: Some edge cases and error returns were not thoroughly explained
3. **Limited Details on Register Interactions**: Could be more specific about register bits and their effects
4. **Missing Details on Conditional Assembly**: Didn't explain how .IF DF FPS100 affects the code
5. **Some Minor Inaccuracies**: For example, in the description of RUNDMA flow
6. **Missing Details on Initialization Process**: Not clear on how the AP is initially configured

Let me create a more complete and accurate annotation, addressing these gaps.

## DAPEX.MAC — Complete Reference Annotation

### 1. File-Level Overview

**Purpose:** DAPEX.MAC is the host-side dispatcher library for the FPS-100 (and AP-120B) array processor under RSX-11M. It provides a FORTRAN-callable interface for AP initialization, program loading, execution control, DMA transfers, interrupt handling, and register I/O.

**Calling Convention:** Standard FORTRAN-style subroutine linkage:
- R5 points to argument list (word count followed by argument addresses)
- Arguments passed by reference (addresses on stack)
- Return via RTS PC
- Scratch registers R0-R5 used freely

**Conditional Assembly (.IF DF FPS100):** The code includes conditional compilation directives to handle FPS100-specific features. When DF FPS100 is defined (presumably for systems with FPS-100 hardware), additional supervisor-mode routines and two-LUN support are included. When not defined, only AP120-mode operations are available.

**RSX Integration Model:**
- Uses RSX-11M QIO directives for device I/O
- Requires a kernel device driver (APDRV/DRIVER.MAC) that implements function codes:
  - 1 = RUNDMA (DMA transfer)
  - 5 = SETMOD/CTL5 (mode set and programmed interrupts)
  - 6 = TERMSUP (terminate supervisor)
- Uses event flags for synchronization:
  - RUNEVF (22) - AP program completion
  - DMAEVF (23) - DMA transfer completion
  - CB5EVF (24) - Programmed interrupt (CTL5)
- Uses two LUNs per AP processor (see Section 6)

**Dependency on DRIVER.MAC/APDRV:**
- All QIO operations go through the AP device driver
- The driver handles CSR register access, interrupt servicing, and DMA setup
- The driver's IOSB (I/O Status Block) provides completion status
- The driver expects the parameter block ordering: RUNFG, FPLIT, FPERF, FPDAT

### 2. Data Structures and Globals

#### Parameter Block (must be in this order for driver)

| Symbol | Offset | Size | Purpose | Access Pattern |
|--------|--------|------|---------|----------------|
| `RUNFG` | 0 | .WORD | AP execution status: 0=stopped, >0=running, <0=halted | Written by RUNAP/WTRUN, read by TSTRUN |
| `FPLIT` | 2 | .WORD | Last LITES register value from AP run or examine | Written by WTRUN, read by APIN/LOOKY |
| `FPERF` | 4 | .WORD | Function interpreter error flag: 0=ok, 1=unimplemented | Set by SENDER, read by APOUT/SPLDGO |
| `FPDAT` | 6 | 8 .WORD | Storage for datum values from FPS-100 | Written by SENDER, read by HTST |
| `VPBAD` | 22 | .WORD | Bad CTL5 message flag | Set by TSTDMA/WTDMA, cleared by APIENA |

#### FPS-100 Variables

| Symbol | Offset | Size | Purpose | Access Pattern |
|--------|--------|------|---------|----------------|
| `VGLOB` | 24 | .WORD | Global variable (unused in this file) | Declared but not referenced |
| `SUPVR` | 26 | .WORD | Supervisor mode: 0=none, >0=Super-100, <0=Mini-100 | Set by APSUPV, tested throughout |
| `FPOPT` | 28 | 4 .WORD | Option word for SENDER messages | Written by SPLDGO/RUNAP/APOUT, read by SENDER |
| `FPSCT` | 30 | .WORD | S-Pad count for SENDER | Written by SPLDGO, used by SEND4 |
| `FPSWR` | 32 | .WORD | Switch register value for SENDER | Written by SPLDGO/RUNAP/HPUT/APOUT, read by APIN |
| `FPFNR` | 34 | .WORD | Function register value for SENDER | Written by SPLDGO/RUNAP/APOUT, read by APIN |

#### Other Globals

| Symbol | Size | Purpose |
|--------|------|---------|
| `CSRTBL` | A$$P11 words | Table of AP CSR addresses (physical) |
| `APCSR` | .WORD | Current AP CSR address (set by SETCSR) |
| `IOSB` | 2 .WORD | I/O Status Block for QIO directives |
| `IFLG` | .WORD | Flag for "any AP" assignment loop |
| `UNIT` | .WORD | Current AP unit number (0-based) |
| `UNIT1` | .WORD | Second LUN unit number (UNIT+1) |
| `SAVLIT` | .WORD | Saved LITES value for GPIOP diagnostics |
| `FLGBUF` | 4 .WORD | Event flag storage for RDAF$ |

### 3. Subroutine Catalog

### Public Routines

#### APASGN (line ~APASGN::)
**Purpose:** Assign an AP processor to the calling task.

**Calling Convention:** `CALL APASGN(APNO, ACTION, STATUS)`
- APNO: 0=any processor, >0=specific processor number
- ACTION: 0=wait if busy, 1=return immediately if busy
- STATUS: return value (>0=AP number assigned, -1=in use, -2=not available, -N=error)

**Flow:**
1. If APNO=0, call ANYAP to scan all processors
2. If APNO>0, convert to 0-based unit number, issue ALUN$ then ATT or ATTW
3. On success, call SETCSR to configure event flags and CSR address
4. For FPS100, also assign second LUN (UNIT1) and force AP120 mode via SETSUP

**Hardware Effect:** Clears CTRL register, sets FN register to 4000 (reset function)

**RSX Directives:** ALUN$, ATT, ATTW, DETACH, SETF, MRKT$, WTSE$

**Edge Cases:**
- If ACTION=1 and processor busy, returns -1
- If no processors exist, returns -2
- Directive errors return DSW value
- I/O errors return IOSB value

#### APRLSE (line ~APRLSE::)
**Purpose:** Release an AP processor.

**Calling Convention:** `CALL APRLSE`

**Flow:**
1. Check AP is assigned (APCON)
2. Wait for DMA to stop (CALL APWD)
3. For FPS100: cancel supervisor mode, terminate driver I/O
4. Clear APCSR, detach from processor

**Hardware Effect:** None directly (driver handles cleanup)

**RSX Directives:** QIOW$ (function 6=TERMSUP), DETACH

#### APSUPV (line ~APSUPV::)
**Purpose:** Indicate AP supervisor on/off.

**Calling Convention:** `CALL APSUPV(MODE)`
- MODE: 0=no supervisor, >0=Super-100, <0=Mini-100

**Flow:**
1. Save MODE to SUPVR
2. If MODE=0, cancel supervisor in driver
3. If MODE≠0, enable CB5 interrupts, issue SETSUP QIO with mode value

**Hardware Effect:** Enables IHCB5 bit in CTRL register

**RSX Directives:** QIO$ (function 5=SETMOD), QIO$ (IO.KIL to cancel)

#### SPLDGO (line ~SPLDGO::)
**Purpose:** S-Pad Load and Go - load S-pad values and start AP program.

**Calling Convention:** `CALL SPLDGO(SLIST, NSPADS, STRT, BRKLOC)`
- SLIST: array of S-pad values
- NSPADS: number of S-pads to load
- STRT: starting address (TMA or PSA)
- BRKLOC: breakpoint address

**Flow (AP120 mode):**
1. Wait for DMA to stop
2. For each S-pad: write address to SWR, function 513 (into SPD), value to SWR, function 517 (into S-Pad)
3. Write starting address to SWR, function 515 (into TMA)
4. Write 8 to SWR, function 512 (into PSA) - bootstrap starter
5. Clear SWR, function 518 (clear APSTAT)
6. Write breakpoint to SWR, function 8448 (set breakpoint and go)
7. Enable halt interrupt

**Flow (Mini-100):**
1. Write start address to SWR, function 512 (into PSA)
2. Write 8192 to SWR, function 512 (set continue bit)
3. Enable halt interrupt

**Flow (Super-100):**
1. Save NSPADS to FPSCT, SLIST pointer on stack
2. Set FPOPT=1 (OPTSPD), FPFNR=start address, FPSWR=breakpoint
3. Call SENDER with R0=0 (APEX message)
4. Restore SLIST pointer, send S-pad values via RDWAIT/SWR loop
5. Return (no hardware start)

**Hardware Effect:** Writes to SWR, FN registers; sets IHHALT in CTRL

#### RUNAP (line ~RUNAP::)
**Purpose:** Start an AP program at a given PSA.

**Calling Convention:** `CALL RUNAP(PSA, NOLOAD, SWR, FN)`
- PSA: program start address
- NOLOAD: 0=load PSA, non-zero=skip PSA load
- SWR: switch register value
- FN: function register value (with breakpoint bits)

**Flow (AP120 mode):**
1. Clear parity enable in status register (function 518)
2. If NOLOAD=0, write PSA to SWR, function 512 (into PSA)
3. Clear parity error enable (function 1030)
4. Write SWR value to SWR register
5. Set continue bit (8192) in FN, write to FN register
6. Enable halt interrupt

**Flow (Mini-100):** Same but clears breakpoint bits from FN

**Flow (Super-100):**
1. Store start address in FPFNR, SWR value in FPSWR
2. Set FPOPT=2 (OPTAPR), FPSCT=0
3. Call SENDER with R0=0

**Hardware Effect:** Writes to SWR, FN registers; sets IHHALT in CTRL

#### TSTRUN (line ~TSTRUN::)
**Purpose:** Test if AP program has completed (non-blocking).

**Calling Convention:** `CALL TSTRUN(I)`
- I: return value (0=still running, 1=completed)

**Flow (AP120 mode):**
1. Check VPBAD for bad CTL5 message
2. Test FN register sign bit: if negative, AP is running; return 1 if stopped

**Flow (Super-100):**
1. Call IFRUN to check hardware
2. Return 1-RUNFG

#### WTRUN (line ~WTRUN::)
**Purpose:** Wait for AP program to complete (blocking).

**Calling Convention:** `CALL WTRUN(IERR)`
- IERR: error code (0=normal, 1=SRAO error, 2=parity error, or LITES value)

**Flow (AP120 mode):**
1. Check VPBAD
2. Wait on RUNEVF event flag
3. Read LITES register, save to SAVLIT
4. Issue function 1030 to get AP status
5. Check LITES bits 7-8 for parity (200) or SRAO (40) errors
6. Return error code

**Flow (Mini-100):** Return LITES register value directly

**Flow (Super-100):**
1. Loop until RUNFG ≤ 0 or FN sign bit indicates halt
2. Return FPLIT value

#### RUNDMA (line ~RUNDMA::)
**Purpose:** Start a DMA transfer between host and AP memory.

**Calling Convention:** `CALL RUNDMA(HOST, APMA, N, CTRL)`
- HOST: host memory address
- APMA: AP memory address
- N: word count
- CTRL: control bits (format, direction, etc.)

**Flow:**
1. Wait for previous DMA to stop (CALL APWD)
2. Set host address in QIO parameter block
3. Write APMA to APMA register
4. Adjust word count for format 3/4 (double words) or format 1
5. Write word count to WC register
6. Convert to byte count for QIO
7. Set up control register (mask off old DMA bits, set new ones)
8. Issue QIO$ IO.WLB to start DMA

**Hardware Effect:** Writes to APMA, WC, CTRL registers

**RSX Directives:** QIO$ (function 1=RUNDMA)

#### TSTDMA (line ~TSTDMA::)
**Purpose:** Test if DMA transfer is complete (non-blocking).

**Calling Convention:** `CALL TSTDMA(I)`
- I: 0=still busy, 1=complete

**Flow:** Return bit 0 of CTRL register (HDMAGO bit cleared = complete)

#### WTDMA (line ~WTDMA::)
**Purpose:** Wait for DMA transfer to complete (blocking).

**Calling Convention:** `CALL WTDMA(IERR)`
- IERR: data late bit from control register

**Flow:**
1. Wait on DMAEVF event flag
2. Read CTRL register, extract bits 8-15 (data late status)
3. Return the data late indicator

#### APRSET (line ~APRSET::)
**Purpose:** Reset AP hardware to known state.

**Calling Convention:** `CALL APRSET`

**Flow:**
1. Write 0 to ABRT (reset) register
2. Write 0 to CTRL register
3. Write 4000 to FN register
4. For FPS100: clear RUNFG, SUPVR, cancel supervisor, clear LITES, FPLIT, FPSWR, FPERF
5. Set all three event flags (DMAEVF, RUNEVF, CB5EVF)

**Hardware Effect:** Hardware reset of AP interface

#### APIENA (line ~APIENA::)
**Purpose:** Enable programmed AP interrupt (CTL5).

**Calling Convention:** `CALL APIENA`

**Flow:**
1. For FPS100: error if supervisor running
2. Clear CB5EVF event flag
3. Set IHCB5 bit in CTRL register

**Hardware Effect:** Enables CB5 interrupt generation

#### APIDIS (line ~APIDIS::)
**Purpose:** Disable programmed AP interrupt (CTL5).

**Calling Convention:** `CALL APIDIS`

**Flow:**
1. For FPS100: error if supervisor running
2. Clear IHCB5 bit in CTRL register

**Hardware Effect:** Disables CB5 interrupt generation

#### APWI (line ~APWI::)
**Purpose:** Wait for programmed AP interrupt (CTL5).

**Calling Convention:** `CALL APWI`

**Flow:**
1. For FPS100: error if supervisor running
2. Wait on CB5EVF event flag

#### TSTINT (line ~TSTINT::)
**Purpose:** Test if programmed interrupt has occurred (non-blocking).

**Calling Convention:** `CALL TSTINT(FLAG)`
- FLAG: 0=no interrupt, 1=interrupt occurred

**Flow:**
1. For FPS100: error if supervisor running
2. Read event flags via RDAF$
3. Check bit 24 (CB5EVF) in FLGBUF+2

#### APIN (line ~APIN::)
**Purpose:** Read an AP interface register.

**Calling Convention:** `CALL APIN(DATA, NUM)`
- NUM: register number (1-15, see table below)
- DATA: returned register value

**Register Numbers:**
1. SWR (Switch Register)
2. FN (Function Register)
3. LITES (Lites Register)
4. APMA (AP DMA Memory Address)
5. HMA (Host DMA Memory Address)
6. WC (Word Count)
7. CTRL (Control Register)
8. FMTH (Format High)
9. FMTL (Format Low)
10. RESET (External Reset - no-op for read)
11. IFSTAT (Interface Status)
12. MASK (Page Select Mask)
13. APMAE (MA Extension)
14. MAE (APMA Extension)
15. SAVLIT (Saved LITES for diagnostics)

**Super-100 Special Handling:**
- NUM=1: return FPSWR (cached SWR)
- NUM=2: return FPFNR (cached FN)
- NUM=3: return FPLIT (cached LITES)

**Extended Memory Registers (12-14):** Read from ABRT register, extract appropriate bit fields

#### APOUT (line ~APOUT::)
**Purpose:** Write to an AP interface register.

**Calling Convention:** `CALL APOUT(DATA, NUM)`
- NUM: register number (same as APIN)
- DATA: value to write

**Super-100 Special Handling:**
- NUM=1: store DATA in FPSWR (cached)
- NUM=2: store DATA in FPFNR, call SENDER with OPTFNR option, check FPERF for errors
- NUM=3: no-op (cannot write LITES in supervisor mode)

**Extended Memory Registers (12-14):** Read-modify-write via LITES register

#### HPUT (line ~HPUT::)
**Purpose:** Send a datum to FPS-100 supervisor.

**Calling Convention:** `CALL HPUT(DEST, DATUM)`
- DEST: destination slot (1-10)
- DATUM: 13-bit value to send

**Flow:**
1. Check FPS100 mode (must be Super-100 or Mini-100)
2. Validate DEST (1-10) and DATUM (≤13 bits)
3. Combine DEST and DATUM, store in FPSWR
4. Call SENDER with R0=0 (APEX message)

**Hardware Effect:** None (message protocol through SENDER)

#### HGET (line ~HGET::)
**Purpose:** Get a datum from FPS-100 supervisor (blocking).

**Calling Convention:** `CALL HGET(SORS, FLAG, DATUM)`
- SORS: source slot (0-10)
- FLAG: 0=success, -1=not available, 2=halted
- DATUM: returned 13-bit value

**Flow:**
1. Loop calling HTST until FLAG indicates success
2. On success, extract and return the datum

#### HTST (line ~HTST::)
**Purpose:** Test if a datum is available from FPS-100 (non-blocking).

**Calling Convention:** `CALL HTST(SORS, FLAG, DATUM)`
- SORS: source slot (0-10)
- FLAG: 0=success, -1=not available, 2=halted
- DATUM: returned 13-bit value

**Flow:**
1. Check FPS100 mode
2. Call IFRUN to check hardware
3. Set FLAG=-1 (not available)
4. If FPDAT(0)≠0, error (datum should be cleared)
5. If SORS=0, search for first available datum in FPDAT
6. If SORS>0, check that specific slot
7. If found, disable interrupts, extract datum, clear slot, restore interrupts
8. Set FLAG=0 or 2 depending on RUNFG

#### LOOKY (line ~LOOKY::)
**Purpose:** Debug routine to display current AP state.

**Calling Convention:** `CALL LOOKY(SWR, RUNFG, FN, CTRL, LITES)`

**Flow:**
1. Call IFRUN to check hardware
2. Read current values of SWR, FN, CTRL, LITES registers
3. Return values in arguments

#### VIRP (line ~VIRP::)
**Purpose:** Debug routine to read interrupt values.

**Calling Convention:** `CALL VIRP(PC, SUM, HALT, DMA, CB5)`
- PC: supervisor mode (SUPVR)
- SUM, HALT, DMA, CB5: interrupt values (unused)

**Flow:**
1. Return SUPVR value in first argument

### Internal Helpers

#### SENDER (line ~SENDER::)
**Purpose:** Send a message to the FPS-100 supervisor.

**Calling Convention:** Internal, called with R0=datum, FPOPT/FPSCT/FPSWR/FPFNR set

**Flow:**
1. RDWAIT for AP to read previous SWR
2. Write R0 to SWR register
3. Interrupt AP via CTRL (set APIRT bit, then clear it)
4. If R0=0 (APEX message), increment RUNFG, enable IHCB5, then send 4 words from FPOPT via SEND4
5. If R0≠0 (HPUT message), return immediately

**Hardware Effect:** Writes SWR, toggles APIRT in CTRL, enables IHCB5

#### SEND4 (line ~SEND4::)
**Purpose:** Send 4 message words to FPS-100.

**Flow:** Loop 4 times: RDWAIT, write (R1)+ to SWR

#### SDUN (line ~SDUN::)
**Purpose:** Sender done - restore R2 and return.

#### RDWAIT (macro)
**Purpose:** Wait for FPS-100 to read SWR register.

**Flow:**
1. Initialize timeout counter (R0)
2. Loop until bit 15 of FN is set (AP has read SWR)
3. Timeout after 255 iterations (STOPS 75)

#### APCON (macro)
**Purpose:** Check if AP is assigned.

**Flow:**
1. Test FN register sign bit
2. If negative (AP not running), call XSTOP

#### NOWAIT (line ~NOWAIT::)
**Purpose:** Handle non-waiting attach in APASGN.

**Flow:** Issue ATT, check IOSB; if busy (IOSB=0), detach and return -1

#### TOLATE (line ~TOLATE::)
**Purpose:** Handle case where processor is already attached by another task.

**Flow:** Detach, return -1

#### DIRER (line ~DIRER::)
**Purpose:** Handle directive error.

**Flow:** Return DSW value in status argument

#### IOER (line ~IOER::)
**Purpose:** Handle I/O error.

**Flow:** Return IOSB value in status argument

#### ANYAP (line ~ANYAP::)
**Purpose:** Scan all AP processors to find an available one.

**Flow:** Loop through unit numbers 0 to A$$P11-1, try ALUN$+ATT on each; if all busy and ACTION=0, wait and retry

#### TRYAGN (line ~TRYAGN::)
**Purpose:** Try next processor in ANYAP loop.

#### BUSY (line ~BUSY::)
**Purpose:** Handle busy processor in ANYAP.

**Flow:** Detach, continue to NEXT

#### NEXT (line ~NEXT::)
**Purpose:** Increment unit number and check if more processors exist.

#### WAIT/WAIT1 (line ~WAIT::)
**Purpose:** Wait and retry processor assignment.

**Flow:** Issue MRKT$ (5-minute mark) then WTSE$, jump back to ANYAP

#### SETCSR (line ~SETCSR::)
**Purpose:** Configure CSR address and event flags after successful attach.

**Flow:**
1. Set DMAEVF, RUNEVF, CB5EVF event flags
2. For FPS100: assign second LUN (UNIT1)
3. Set APCSR from CSRTBL
4. Clear CTRL register, set FN=4000
5. For FPS100: force AP120 mode via SETSUP QIO

#### ASSIGN/ASGN2 (line ~ASSIGN::)
**Purpose:** ALUN$ directive definitions for LUN and LUN1.

#### SETSUP (line ~SETSUP::)
**Purpose:** QIO$ definition for mode set (function 5).

**Parameters:** IRUNFG (RUNFG address), 11 words, mode value

#### ATT/ATTW/DETACH (line ~ATT::)
**Purpose:** QIO$ definitions for attach, attach-and-wait, detach.

#### MARK/TWAIT (line ~MARK::)
**Purpose:** MRKT$ and WTSE$ definitions for wait/retry.

#### SETF (line ~SETF::)
**Purpose:** SETF$ definition for event flag setting.

#### IFRUN (line ~IFRUN::)
**Purpose:** Check if AP hardware is running.

**Flow:** Test FN register sign bit; if negative (AP stopped), set RUNFG=-1

#### XSTOP (line ~XSTOP::)
**Purpose:** Error handler for unassigned AP.

**Flow:** Call APSTOP(101)

#### ERR (line ~ERR::)
**Purpose:** DMA error handler.

**Flow:** Call APSTOP(7)

### 4. The Two-Mode Model

The file explicitly handles three modes of AP operation, controlled by the `SUPVR` variable:

#### AP120 Mode (SUPVR = 0)
- Direct hardware register access via CSR pointer
- Host directly controls AP via DMA, SWR, FN, LITES registers
- Program loading via SPLDGO/RUNAP writes to AP registers
- Synchronization via event flags (RUNEVF, DMAEVF, CB5EVF)
- Interrupt handling via CTL5 (IHCB5 bit)
- Used by: APASGN (initial mode), APRSET, APIENA, APIDIS, APWI, TSTINT

#### Super-100 Mode (SUPVR > 0)
- FPS-100 runs an embedded supervisor
- Communication via message protocol through SENDER
- Host writes to cached registers (FPSWR, FPFNR, FPLIT)
- SPLDGO sends OPTSPD message with start address and breakpoint
- RUNAP sends OPTAPR message with start address and SWR
- APOUT with NUM=2 sends OPTFNR message to interpret function
- HPUT/HPUT/HTST use FPDAT array for datum exchange
- IFRUN checks hardware, TSTRUN/WTRUN use RUNFG

#### Mini-100 Mode (SUPVR < 0)
- Similar to Super-100 but with simplified protocol
- SPLDGO writes start address directly to PSA with continue bit
- RUNAP clears breakpoint bits
- WTRUN returns LITES value directly
- No breakpoint support

### 5. Call Graph

```
APASGN
  ├── ANYAP
  │   ├── ASSIGN (ALUN$)
  │   ├── ATT (QIO$)
  │   ├── BUSY → DETACH (QIO$)
  │   ├── NEXT
  │   ├── WAIT → MARK (MRKT$) → TWAIT (WTSE$)
  │   └── SETCSR
  ├── NOWAIT → ATT (QIO$)
  ├── TOLATE → DETACH (QIO$)
  ├── DIRER
  ├── IOER
  └── SETCSR
      ├── SETF (×3)
      ├── ASGN2 (ALUN$)
      └── SETSUP (QIO$)

APRLSE
  ├── APCON
  ├── APWD (CALL)
  ├── CANSUP (QIO$)
  ├── TERM (QIOW$)
  └── DETACH (QIO$)

APSUPV
  ├── APCON
  ├── STSUP2 (QIO$)
  └── CANSUP (QIO$)

SPLDGO
  ├── APCON
  ├── APWR (CALL)
  ├── CLRRUN (CLEF$)
  ├── SENDER (CALLS) [Super-100 only]
  └── (direct register writes)

RUNAP
  ├── APCON
  ├── APWR (CALL)
  ├── CLRRUN (CLEF$)
  ├── SENDER (CALLS) [Super-100 only]
  └── (direct register writes)

TSTRUN
  ├── APCON
  ├── IFRUN (CALLS) [Super-100 only]
  └── (FN register test)

WTRUN
  ├── APCON
  ├── RUNWT (WTSE$)
  └── (LITES register read)

RUNDMA
  ├── APCON
  ├── APWD (CALL)
  └── RDMA (QIO$)

TSTDMA
  └── APCON

WTDMA
  ├── APCON
  └── DMAWT (WTSE$)

APRSET
  ├── APCON
  ├── CANSUP (QIO$)
  └── SETF (×3)

APIENA
  ├── APCON
  └── CLRCL5 (CLEF$)

APIDIS
  └── APCON

APWI
  └── WTAP (WTSE$)

TSTINT
  ├── APCON
  └── RDFLG (RDAF$)

APIN
  └── APCON

APOUT
  ├── APCON
  ├── APWR (CALL)
  └── SENDER (CALLS) [Super-100, NUM=2]

HPUT
  ├── APCON
  └── SENDER (CALLS)

HGET
  ├── APCON
  └── HTST (CALLS)

HTST
  ├── APCON
  └── IFRUN (CALLS)

LOOKY
  ├── APCON
  └── IFRUN (CALLS)

VIRP
  └── APCON
```

### 6. The Two-LUN Architecture

The FPS-100 requires two logical unit numbers (LUNs) per physical AP processor:

#### LUN0 (base unit, stored in UNIT)
- **Purpose:** DMA transfers and standard AP control
- **Used by:** RUNDMA (QIO$ IO.WLB), TERM (QIOW$ function 6)
- **Event flags:** DMAEVF (23), RUNEVF (22)
- **Driver function codes:** 1 (RUNDMA), 6 (TERMSUP)

#### LUN1 (UNIT+1, stored in UNIT1)
- **Purpose:** Mode setting and supervisor communication
- **Used by:** SETSUP (QIO$ function 5), STSUP2, CANSUP (IO.KIL)
- **Event flags:** RUNEVF (22), CB5EVF (24)
- **Driver function codes:** 5 (SETMOD/CTL5)

#### Why Two LUNs?
1. The AP driver uses different QIO function codes for DMA (1) vs. mode control (5)
2. The driver needs separate I/O channels for concurrent operations
3. The supervisor communication uses CTL5 interrupts which are managed through LUN1
4. DMA transfers on LUN0 can proceed independently of supervisor messages on LUN1

#### Assignment:
- APASGN assigns LUN0 via ALUN$ with the AP device
- SETCSR then assigns LUN1 (UNIT+1) via ASGN2
- Both LUNs point to the same physical AP processor

### 7. Glossary of FPS-Specific Terms

#### S-Pad (S-PAD)
- **Definition:** Scratch-pad memory locations in the AP-120B/FPS-100
- **Addressing:** 512 words (0-511) of high-speed memory
- **Usage in code:** SPLDGO loads values into S-pads using function codes 513 (into SPD) and 517 (into S-Pad)
- **PDP-11 equivalent:** Like a small, fast array in AP memory

#### MD (Memory Data)
- **Context:** Not explicitly used in DAPEX, but referenced in AP-120B documentation
- **Definition:** The main data memory of the AP
- **Relevance:** DMA transfers (RUNDMA) move data between host memory and AP MD

#### PSA (Program Start Address)
- **Definition:** The starting address for AP program execution
- **Register:** Written via function code 512
- **Usage:** RUNAP writes PSA to start a program; SPLDGO writes bootstrap starter address

#### TMA (Table Memory Address)
- **Definition:** Address in AP table memory (used for constants/tables)
- **Register:** Written via function code 515
- **Usage:** SPLDGO writes starting address to TMA

#### APSTAT (AP Status Register)
- **Definition:** Status/control register in the AP
- **Register:** Written via function code 518
- **Usage:** SPLDGO clears parity enable; RUNAP clears parity error enable (function 1030)

#### SWR (Switch Register)
- **Definition:** 16-bit register for host-to-AP communication
- **Address:** FPS+110 (offset 110 octal)
- **Usage:** Primary data transfer register; host writes data, AP reads it
- **Protocol:** AP sets bit when it reads; host clears by writing

#### FN (Function Register)
- **Definition:** 16-bit register that controls AP operations
- **Address:** FPS+112 (offset 112 octal)
- **Usage:** 
  - Bit 15 (sign): AP running flag (0=running, 1=stopped)
  - Bit 14: AP read SWR flag
  - Lower bits: function codes for various operations
- **Function codes used:**
  - 512 (1000 octal): Load PSA
  - 513 (1001 octal): Into SPD (S-pad data)
  - 515 (1003 octal): Into TMA
  - 517 (1005 octal): Into S-Pad
  - 518 (1006 octal): Into APSTAT
  - 1030 (2006 octal): Clear parity error enable
  - 8192 (20000 octal): Continue bit
  - 8448 (20400 octal): Set breakpoint and go

#### LITES (Lights Register)
- **Definition:** 16-bit register for AP-to-host communication
- **Address:** FPS+114 (offset 114 octal)
- **Usage:** AP writes status/result; host reads it
- **Bits:** 7-8 indicate parity (200) or SRAO (40) errors

#### CTRL (Control Register)
- **Definition:** 16-bit register for DMA and interrupt control
- **Address:** FPS+104 (offset 104 octal)
- **Bits:**
  - Bit 0 (HDMAGO=1): Start DMA transfer
  - Bit 11 (IHCB5=2000): Enable programmed interrupt (CTL5)
  - Bit 14 (IHWC=4000): Enable DMA done interrupt
  - Bit 15 (IHHALT=10000): Enable AP halt interrupt
  - Bit 14 (APIRT=40000): Interrupt the AP

#### WC (Word Count Register)
- **Definition:** DMA word count register
- **Address:** FPS+100 (offset 100 octal)
- **Usage:** Set by RUNDMA before starting DMA transfer

#### HMA (Host Memory Address Register)
- **Definition:** Host memory address for DMA
- **Address:** FPS+102 (offset 102 octal)
- **Usage:** Set by driver during DMA setup

#### APMA (AP Memory Address Register)
- **Definition:** AP memory address for DMA
- **Address:** FPS+106 (offset 106 octal)
- **Usage:** Set by RUNDMA before starting DMA

#### ABRT (Reset Register)
- **Definition:** AP reset/abort register
- **Address:** FPS+116 (offset 116 octal)
- **Usage:** Writing 0 resets the AP; also contains extended memory register values

#### FMTH/FMTL (Format High/Low)
- **Definition:** Data format registers for DMA
- **Address:** FPS+0 (FMTH), FPS+2 (FMTL)
- **Usage:** Control data packing/unpacking during DMA

#### CTL5 (Control Bit 5)
- **Definition:** Programmed interrupt mechanism
- **Register bit:** IHCB5 (2000) in CTRL register
- **Usage:** AP can interrupt host for attention; used for supervisor communication

#### SRAO (Status Register Address Out)
- **Definition:** Error condition in AP
- **Detection:** Bit 6 (40 octal) in LITES register
- **Usage:** WTRUN checks for this error after program completion

#### GPIOP (General Purpose I/O Processor)
- **Context:** Diagnostic tool for FPS-100
- **Usage:** SAVLIT stores LITES value for GPIOP diagnostics

#### IOSB (I/O Status Block)
- **Definition:** RSX-11M data structure for QIO completion status
- **Size:** 2 words
- **Usage:** All QIO operations check IOSB for success/failure

#### DSW (Directive Status Word)
- **Definition:** RSX-11M system variable containing last directive error code
- **Usage:** DIRER returns DSW value as error code

#### Event Flags (RUNEVF, DMAEVF, CB5EVF)
- **Definition:** RSX-11M synchronization primitives
- **Values:** 22 (RUNEVF), 23 (DMAEVF), 24 (CB5EVF/TIMEVF)
- **Usage:** 
  - RUNEVF: Set when AP program completes or halts
  - DMAEVF: Set when DMA transfer completes
  - CB5EVF: Set when CTL5 interrupt occurs
  - TIMEVF: Reused for timing (MRKT$/WTSE$)

#### ALUN$ (Assign Logical Unit Number)
- **Definition:** RSX-11M directive to associate a LUN with a device
- **Usage:** ASSIGN and ASGN2 macros create ALUN$ directives for LUN0 and LUN1

#### QIO$ (Queue I/O)
- **Definition:** RSX-11M directive for device I/O operations
- **Function codes used:**
  - IO.ATT (attach)
  - IO.DET (detach)
  - IO.WLB (load with buffer - DMA)
  - IO.KIL (kill - cancel supervisor)
  - Function 1 (RUNDMA)
  - Function 5 (SETMOD/CTL5)
  - Function 6 (TERMSUP)

#### WTSE$ (Wait Set Event)
- **Definition:** RSX-11M directive to wait for an event flag to be set
- **Usage:** Used in WTRUN, WTDMA, APWI, etc.

#### MRKT$ (Mark Timer)
- **Definition:** RSX-11M directive to schedule a future time mark
- **Usage:** Used in APASGN to retry processor assignment after a delay

#### RDAF$ (Read All Flags)
- **Definition:** RSX-11M directive to read all event flags
- **Usage:** Used in TSTINT to check for CTL5 interrupt

#### STOPS (macro)
- **Definition:** Call APSTOP with error code
- **Usage:** Used for error conditions throughout the code

#### APCON (macro)
- **Definition:** Check if AP is assigned
- **Usage:** Entry guard for all AP operations

#### APWD (CALL)
- **Purpose:** Wait for DMA to complete
- **Usage:** Called before starting new DMA operation

#### APWR (CALL)
- **Purpose:** Wait for AP to be ready (not used in code but declared)
- **Usage:** Called before AP operations that require the AP to be idle

#### RUNWT (macro)
- **Definition:** WTSE$ for RUNEVF
- **Usage:** Used in WTRUN to wait for AP program completion

#### DMAWT (macro)
- **Definition:** WTSE$ for DMAEVF
- **Usage:** Used in WTDMA to wait for DMA completion

#### WTAP (macro)
- **Definition:** WTSE$ for CB5EVF
- **Usage:** Used in APWI to wait for CTL5 interrupt

#### CLRRUN (macro)
- **Definition:** CLEF

---

## Cooperative pass — independent first drafts

### DeepSeek cooperative

(116s, 25452 chars)

# DAPEX.MAC — Complete Reference Annotation

## 1. File-Level Overview

**Purpose:** DAPEX.MAC is the host-side dispatcher library for the FPS-100 (and AP-120B) array processor under RSX-11M. It provides a FORTRAN-callable interface for AP initialization, program loading, execution control, DMA transfers, interrupt handling, and register I/O.

**Calling Convention:** Standard FORTRAN-style subroutine linkage:
- R5 points to argument list (word count followed by argument addresses)
- Arguments passed by reference (addresses on stack)
- Return via RTS PC
- Scratch registers R0-R5 used freely

**RSX Integration Model:**
- Uses RSX-11M QIO directives for device I/O
- Requires a kernel device driver (APDRV/DRIVER.MAC) that implements function codes:
  - 1 = RUNDMA (DMA transfer)
  - 5 = SETMOD/CTL5 (mode set and programmed interrupts)
  - 6 = TERMSUP (terminate supervisor)
- Uses event flags for synchronization:
  - RUNEVF (22) - AP program completion
  - DMAEVF (23) - DMA transfer completion
  - CB5EVF (24) - Programmed interrupt (CTL5)
- Uses two LUNs per AP processor (see Section 6)

**Dependency on DRIVER.MAC/APDRV:**
- All QIO operations go through the AP device driver
- The driver handles CSR register access, interrupt servicing, and DMA setup
- The driver's IOSB (I/O Status Block) provides completion status
- The driver expects the parameter block ordering: RUNFG, FPLIT, FPERF, FPDAT

## 2. Data Structures and Globals

### Parameter Block (must be in this order for driver)

| Symbol | Offset | Size | Purpose | Access Pattern |
|--------|--------|------|---------|----------------|
| `RUNFG` | 0 | .WORD | AP execution status: 0=stopped, >0=running, <0=halted | Read/written by host and driver |
| `FPLIT` | 2 | .WORD | Last LITES register value from AP run or examine | Written by WTRUN, read by APIN/LOOKY |
| `FPERF` | 4 | .WORD | Function interpreter error flag: 0=ok, 1=unimplemented | Set by APOUT/SENDER, read by caller |
| `FPDAT` | 6 | 8 .WORD | Storage for datum values from FPS-100 | Used by HGET/HTST for supervisor messages |
| `VPBAD` | 22 | .WORD | Bad CTL5 message flag | Tested by TSTRUN/WTRUN |

### FPS-100 Variables

| Symbol | Offset | Size | Purpose | Access Pattern |
|--------|--------|------|---------|----------------|
| `VGLOB` | 24 | .WORD | Global variable (unused in this file) | Declared but not referenced |
| `SUPVR` | 26 | .WORD | Supervisor mode: 0=none, >0=Super-100, <0=Mini-100 | Set by APSUPV, tested throughout |
| `FPOPT` | 28 | 4 .WORD | Option word for SENDER messages | Written by SPLDGO/RUNAP/APOUT |
| `FPSCT` | 30 | .WORD | S-Pad count for SENDER | Written by SPLDGO |
| `FPSWR` | 32 | .WORD | Switch register value for SENDER | Written by SPLDGO/RUNAP/HPUT/APOUT |
| `FPFNR` | 34 | .WORD | Function register value for SENDER | Written by SPLDGO/RUNAP/APOUT |

### Other Globals

| Symbol | Size | Purpose |
|--------|------|---------|
| `CSRTBL` | A$$P11 words | Table of AP CSR addresses (physical) |
| `APCSR` | .WORD | Current AP CSR address (set by SETCSR) |
| `IOSB` | 2 .WORD | I/O Status Block for QIO directives |
| `IFLG` | .WORD | Flag for "any AP" assignment loop |
| `UNIT` | .WORD | Current AP unit number (0-based) |
| `UNIT1` | .WORD | Second LUN unit number (UNIT+1) |
| `SAVLIT` | .WORD | Saved LITES value for GPIOP diagnostics |
| `FLGBUF` | 4 .WORD | Event flag storage for RDAF$ |

## 3. Subroutine Catalog

### Public Routines

---

#### APASGN (line ~APASGN::)
**Purpose:** Assign an AP processor to the calling task.

**Calling Convention:** `CALL APASGN(APNO, ACTION, STATUS)`
- APNO: 0=any processor, >0=specific processor number
- ACTION: 0=wait if busy, 1=return immediately if busy
- STATUS: return value (>0=AP number assigned, -1=in use, -2=not available, -N=error)

**Flow:**
1. If APNO=0, call ANYAP to scan all processors
2. If APNO>0, convert to 0-based unit number, issue ALUN$ then ATT or ATTW
3. On success, call SETCSR to configure event flags and CSR address
4. For FPS100, also assign second LUN (UNIT1) and force AP120 mode via SETSUP

**Hardware Effect:** Clears CTRL register, sets FN register to 4000 (reset function)

**RSX Directives:** ALUN$, ATT, ATTW, DETACH, SETF, MRKT$, WTSE$

**Edge Cases:**
- If ACTION=1 and processor busy, returns -1
- If no processors exist, returns -2
- Directive errors return DSW value
- I/O errors return IOSB value

---

#### APRLSE (line ~APRLSE::)
**Purpose:** Release an AP processor.

**Calling Convention:** `CALL APRLSE`

**Flow:**
1. Check AP is assigned (APCON)
2. Wait for DMA to stop (CALL APWD)
3. For FPS100: cancel supervisor mode, terminate driver I/O
4. Clear APCSR, detach from processor

**Hardware Effect:** None directly (driver handles cleanup)

**RSX Directives:** QIOW$ (function 6=TERMSUP), DETACH

---

#### APSUPV (line ~APSUPV::)
**Purpose:** Indicate AP supervisor on/off.

**Calling Convention:** `CALL APSUPV(MODE)`
- MODE: 0=no supervisor, >0=Super-100, <0=Mini-100

**Flow:**
1. Save MODE to SUPVR
2. If MODE=0, cancel supervisor in driver
3. If MODE≠0, enable CB5 interrupts, issue SETSUP QIO with mode value

**Hardware Effect:** Enables IHCB5 bit in CTRL register

**RSX Directives:** QIO$ (function 5=SETMOD), QIO$ (IO.KIL to cancel)

---

#### SPLDGO (line ~SPLDGO::)
**Purpose:** S-Pad Load and Go - load S-pad values and start AP program.

**Calling Convention:** `CALL SPLDGO(SLIST, NSPADS, STRT, BRKLOC)`
- SLIST: array of S-pad values
- NSPADS: number of S-pads to load
- STRT: starting address (TMA or PSA)
- BRKLOC: breakpoint address

**Flow (AP120 mode):**
1. Wait for DMA to stop
2. For each S-pad: write address to SWR, function 513 (into SPD), value to SWR, function 517 (into S-Pad)
3. Write starting address to SWR, function 515 (into TMA)
4. Write 8 to SWR, function 512 (into PSA) - bootstrap starter
5. Clear SWR, function 518 (clear APSTAT)
6. Write breakpoint to SWR, function 8448 (set breakpoint and go)
7. Enable halt interrupt

**Flow (Mini-100):**
1. Write start address to SWR, function 512 (into PSA)
2. Write 8192 to SWR, function 512 (set continue bit)
3. Enable halt interrupt

**Flow (Super-100):**
1. Save NSPADS to FPSCT, SLIST pointer on stack
2. Set FPOPT=1 (OPTSPD), FPFNR=start address, FPSWR=breakpoint
3. Call SENDER with R0=0 (APEX message)
4. Restore SLIST pointer, send S-pad values via RDWAIT/SWR loop
5. Return (no hardware start)

**Hardware Effect:** Writes to SWR, FN registers; sets IHHALT in CTRL

---

#### RUNAP (line ~RUNAP::)
**Purpose:** Start an AP program at a given PSA.

**Calling Convention:** `CALL RUNAP(PSA, NOLOAD, SWR, FN)`
- PSA: program start address
- NOLOAD: 0=load PSA, non-zero=skip PSA load
- SWR: switch register value
- FN: function register value (with breakpoint bits)

**Flow (AP120 mode):**
1. Clear parity enable in status register (function 518)
2. If NOLOAD=0, write PSA to SWR, function 512 (into PSA)
3. Clear parity error enable (function 1030)
4. Write SWR value to SWR register
5. Set continue bit (8192) in FN, write to FN register
6. Enable halt interrupt

**Flow (Mini-100):** Same but clears breakpoint bits from FN

**Flow (Super-100):**
1. Store start address in FPFNR, SWR value in FPSWR
2. Set FPOPT=2 (OPTAPR), FPSCT=0
3. Call SENDER with R0=0

**Hardware Effect:** Writes to SWR, FN registers; sets IHHALT in CTRL

---

#### TSTRUN (line ~TSTRUN::)
**Purpose:** Test if AP program has completed (non-blocking).

**Calling Convention:** `CALL TSTRUN(I)`
- I: return value (0=still running, 1=completed)

**Flow (AP120 mode):**
1. Check VPBAD for bad CTL5 message
2. Test FN register sign bit: if negative, AP is running; return 1 if stopped

**Flow (Super-100):**
1. Call IFRUN to check hardware
2. Return 1-RUNFG

---

#### WTRUN (line ~WTRUN::)
**Purpose:** Wait for AP program to complete (blocking).

**Calling Convention:** `CALL WTRUN(IERR)`
- IERR: error code (0=normal, 1=SRAO error, 2=parity error, or LITES value)

**Flow (AP120 mode):**
1. Check VPBAD
2. Wait on RUNEVF event flag
3. Read LITES register, save to SAVLIT
4. Issue function 1030 to get AP status
5. Check LITES bits 7-8 for parity (200) or SRAO (40) errors
6. Return error code

**Flow (Mini-100):** Return LITES register value directly

**Flow (Super-100):**
1. Loop until RUNFG ≤ 0 or FN sign bit indicates halt
2. Return FPLIT value

---

#### RUNDMA (line ~RUNDMA::)
**Purpose:** Start a DMA transfer between host and AP memory.

**Calling Convention:** `CALL RUNDMA(HOST, APMA, N, CTRL)`
- HOST: host memory address
- APMA: AP memory address
- N: word count
- CTRL: control bits (format, direction, etc.)

**Flow:**
1. Wait for previous DMA to stop (CALL APWD)
2. Set host address in QIO parameter block
3. Write APMA to APMA register
4. Adjust word count for format 3/4 (double words) or format 1
5. Write word count to WC register
6. Convert to byte count for QIO
7. Set up control register (mask off old DMA bits, set new ones)
8. Issue QIO$ IO.WLB to start DMA

**Hardware Effect:** Writes to APMA, WC, CTRL registers

**RSX Directives:** QIO$ (function 1=RUNDMA)

---

#### TSTDMA (line ~TSTDMA::)
**Purpose:** Test if DMA transfer is complete (non-blocking).

**Calling Convention:** `CALL TSTDMA(I)`
- I: 0=still busy, 1=complete

**Flow:** Return bit 0 of CTRL register (HDMAGO bit cleared = complete)

---

#### WTDMA (line ~WTDMA::)
**Purpose:** Wait for DMA transfer to complete (blocking).

**Calling Convention:** `CALL WTDMA(IERR)`
- IERR: data late bit from control register

**Flow:**
1. Wait on DMAEVF event flag
2. Read CTRL register, extract bits 8-15 (data late status)
3. Return the data late indicator

---

#### APRSET (line ~APRSET::)
**Purpose:** Reset AP hardware to known state.

**Calling Convention:** `CALL APRSET`

**Flow:**
1. Write 0 to ABRT (reset) register
2. Write 0 to CTRL register
3. Write 4000 to FN register
4. For FPS100: clear RUNFG, SUPVR, cancel supervisor, clear LITES, FPLIT, FPSWR, FPERF
5. Set all three event flags (DMAEVF, RUNEVF, CB5EVF)

**Hardware Effect:** Hardware reset of AP interface

---

#### APIENA (line ~APIENA::)
**Purpose:** Enable programmed AP interrupt (CTL5).

**Calling Convention:** `CALL APIENA`

**Flow:**
1. For FPS100: error if supervisor running
2. Clear CB5EVF event flag
3. Set IHCB5 bit in CTRL register

**Hardware Effect:** Enables CB5 interrupt generation

---

#### APIDIS (line ~APIDIS::)
**Purpose:** Disable programmed AP interrupt (CTL5).

**Calling Convention:** `CALL APIDIS`

**Flow:**
1. For FPS100: error if supervisor running
2. Clear IHCB5 bit in CTRL register

**Hardware Effect:** Disables CB5 interrupt generation

---

#### APWI (line ~APWI::)
**Purpose:** Wait for programmed AP interrupt (CTL5).

**Calling Convention:** `CALL APWI`

**Flow:**
1. For FPS100: error if supervisor running
2. Wait on CB5EVF event flag

---

#### TSTINT (line ~TSTINT::)
**Purpose:** Test if programmed interrupt has occurred (non-blocking).

**Calling Convention:** `CALL TSTINT(FLAG)`
- FLAG: 0=no interrupt, 1=interrupt occurred

**Flow:**
1. For FPS100: error if supervisor running
2. Read event flags via RDAF$
3. Check bit 24 (CB5EVF) in FLGBUF+2

---

#### APIN (line ~APIN::)
**Purpose:** Read an AP interface register.

**Calling Convention:** `CALL APIN(DATA, NUM)`
- NUM: register number (1-15, see table below)
- DATA: returned register value

**Register Numbers:**
1. SWR (Switch Register)
2. FN (Function Register)
3. LITES (Lites Register)
4. APMA (AP DMA Memory Address)
5. HMA (Host DMA Memory Address)
6. WC (Word Count)
7. CTRL (Control Register)
8. FMTH (Format High)
9. FMTL (Format Low)
10. RESET (External Reset - no-op for read)
11. IFSTAT (Interface Status)
12. MASK (Page Select Mask)
13. APMAE (MA Extension)
14. MAE (APMA Extension)
15. SAVLIT (Saved LITES for diagnostics)

**Super-100 Special Handling:**
- NUM=1: return FPSWR (cached SWR)
- NUM=2: return FPFNR (cached FN)
- NUM=3: return FPLIT (cached LITES)

**Extended Memory Registers (12-14):** Read from ABRT register, extract appropriate bit fields

---

#### APOUT (line ~APOUT::)
**Purpose:** Write to an AP interface register.

**Calling Convention:** `CALL APOUT(DATA, NUM)`
- NUM: register number (same as APIN)
- DATA: value to write

**Super-100 Special Handling:**
- NUM=1: store DATA in FPSWR (cached)
- NUM=2: store DATA in FPFNR, call SENDER with OPTFNR option, check FPERF for errors
- NUM=3: no-op (cannot write LITES in supervisor mode)

**Extended Memory Registers (12-14):** Read-modify-write via LITES register

---

### Internal Helpers

---

#### SENDER (line ~SENDER::)
**Purpose:** Send a message to the FPS-100 supervisor.

**Calling Convention:** Internal, called with R0=datum, FPOPT/FPSCT/FPSWR/FPFNR set

**Flow:**
1. RDWAIT for AP to read previous SWR
2. Write R0 to SWR register
3. Interrupt AP via CTRL (set APIRT bit, then clear it)
4. If R0=0 (APEX message), increment RUNFG, enable IHCB5, then send 4 words from FPOPT via SEND4
5. If R0≠0 (HPUT message), return immediately

**Hardware Effect:** Writes SWR, toggles APIRT in CTRL, enables IHCB5

---

#### SEND4 (line ~SEND4::)
**Purpose:** Send 4 message words to FPS-100.

**Flow:** Loop 4 times: RDWAIT, write (R1)+ to SWR

---

#### SDUN (line ~SDUN::)
**Purpose:** Sender done - restore R2 and return.

---

#### NOWAIT (line ~NOWAIT::)
**Purpose:** Handle non-waiting attach in APASGN.

**Flow:** Issue ATT, check IOSB; if busy (IOSB=0), detach and return -1

---

#### TOLATE (line ~TOLATE::)
**Purpose:** Handle case where processor is already attached by another task.

**Flow:** Detach, return -1

---

#### DIRER (line ~DIRER::)
**Purpose:** Handle directive error.

**Flow:** Return DSW value in status argument

---

#### IOER (line ~IOER::)
**Purpose:** Handle I/O error.

**Flow:** Return IOSB value in status argument

---

#### ANYAP (line ~ANYAP::)
**Purpose:** Scan all AP processors to find an available one.

**Flow:** Loop through unit numbers 0 to A$$P11-1, try ALUN$+ATT on each; if all busy and ACTION=0, wait and retry

---

#### TRYAGN (line ~TRYAGN::)
**Purpose:** Try next processor in ANYAP loop.

---

#### BUSY (line ~BUSY::)
**Purpose:** Handle busy processor in ANYAP.

**Flow:** Detach, continue to NEXT

---

#### NEXT (line ~NEXT::)
**Purpose:** Increment unit number and check if more processors exist.

---

#### WAIT / WAIT1 (line ~WAIT::)
**Purpose:** Wait and retry processor assignment.

**Flow:** Issue MRKT$ (5-minute mark) then WTSE$, jump back to ANYAP

---

#### SETCSR (line ~SETCSR::)
**Purpose:** Configure CSR address and event flags after successful attach.

**Flow:**
1. Set DMAEVF, RUNEVF, CB5EVF event flags
2. For FPS100: assign second LUN (UNIT1)
3. Set APCSR from CSRTBL
4. Clear CTRL register, set FN=4000
5. For FPS100: force AP120 mode via SETSUP QIO

---

#### ASSIGN / ASGN2 (line ~ASSIGN::)
**Purpose:** ALUN$ directive definitions for LUN and LUN1.

---

#### SETSUP (line ~SETSUP::)
**Purpose:** QIO$ definition for mode set (function 5).

**Parameters:** IRUNFG (RUNFG address), 11 words, mode value

---

#### ATT / ATTW / DETACH (line ~ATT::)
**Purpose:** QIO$ definitions for attach, attach-and-wait, detach.

---

#### MARK / TWAIT (line ~MARK::)
**Purpose:** MRKT$ and WTSE$ definitions for wait/retry.

---

#### SETF (line ~SETF::)
**Purpose:** SETF$ definition for event flag setting.

---

#### IFRUN (line ~IFRUN::)
**Purpose:** Check if AP hardware is running.

**Flow:** Test FN register sign bit; if negative (AP stopped), set RUNFG=-1

---

#### XSTOP (line ~XSTOP::)
**Purpose:** Error handler for unassigned AP.

**Flow:** Call APSTOP(101)

---

#### ERR (line ~ERR::)
**Purpose:** DMA error handler.

**Flow:** Call APSTOP(7)

---

## 4. The Two-Mode Model

The file explicitly handles three modes of AP operation, controlled by the `SUPVR` variable:

### AP120 Mode (SUPVR = 0)
- Direct hardware register access via CSR pointer
- Host directly controls AP via DMA, SWR, FN, LITES registers
- Program loading via SPLDGO/RUNAP writes to AP registers
- Synchronization via event flags (RUNEVF, DMAEVF, CB5EVF)
- Interrupt handling via CTL5 (IHCB5 bit)
- Used by: APASGN (initial mode), APRSET, APIENA, APIDIS, APWI, TSTINT

### Super-100 Mode (SUPVR > 0)
- FPS-100 runs an embedded supervisor
- Communication via message protocol through SENDER
- Host writes to cached registers (FPSWR, FPFNR, FPLIT)
- SPLDGO sends OPTSPD message with start address and breakpoint
- RUNAP sends OPTAPR message with start address and SWR
- APOUT with NUM=2 sends OPTFNR message to interpret function
- HPUT/HPUT/HTST use FPDAT array for datum exchange
- IFRUN checks hardware, TSTRUN/WTRUN use RUNFG

### Mini-100 Mode (SUPVR < 0)
- Similar to Super-100 but with simplified protocol
- SPLDGO writes start address directly to PSA with continue bit
- RUNAP clears breakpoint bits
- WTRUN returns LITES value directly
- No breakpoint support

### Key Differences in Code Paths:

| Routine | AP120 Path | Super-100 Path | Mini-100 Path |
|---------|------------|----------------|---------------|
| SPLDGO | Direct register writes | SENDER with OPTSPD | Direct PSA write + continue |
| RUNAP | Direct register writes | SENDER with OPTAPR | Same as AP120 but no breakpoint |
| TSTRUN | Test FN sign bit | IFRUN + 1-RUNFG | Same as AP120 |
| WTRUN | Wait RUNEVF, check LITES | Loop on RUNFG, return FPLIT | Return LITES directly |
| APIN | Read hardware register | Return cached value | Same as AP120 |
| APOUT | Write hardware register | Cache value, SENDER for FN | Same as AP120 |
| APIENA | Enable IHCB5 | Error (STOPS 80) | Error |
| APIDIS | Disable IHCB5 | Error | Error |
| APWI | Wait CB5EVF | Error | Error |
| TSTINT | Read event flags | Error | Error |

## 5. Call Graph

```
APASGN
  ├── ANYAP
  │   ├── ASSIGN (ALUN$)
  │   ├── ATT (QIO$)
  │   ├── BUSY → DETACH (QIO$)
  │   ├── NEXT
  │   ├── WAIT → MARK (MRKT$) → TWAIT (WTSE$)
  │   └── SETCSR
  ├── NOWAIT → ATT (QIO$)
  ├── TOLATE → DETACH (QIO$)
  ├── DIRER
  ├── IOER
  └── SETCSR
      ├── SETF (×3)
      ├── ASGN2 (ALUN$)
      └── SETSUP (QIO$)

APRLSE
  ├── APCON
  ├── APWD (CALL)
  ├── CANSUP (QIO$)
  ├── TERM (QIOW$)
  └── DETACH (QIO$)

APSUPV
  ├── APCON
  ├── STSUP2 (QIO$)
  └── CANSUP (QIO$)

SPLDGO
  ├── APCON
  ├── APWR (CALL)
  ├── CLRRUN (CLEF$)
  ├── SENDER (CALLS) [Super-100 only]
  └── (direct register writes)

RUNAP
  ├── APCON
  ├── APWR (CALL)
  ├── CLRRUN (CLEF$)
  ├── SENDER (CALLS) [Super-100 only]
  └── (direct register writes)

TSTRUN
  ├── APCON
  ├── IFRUN (CALLS) [Super-100 only]
  └── (FN register test)

WTRUN
  ├── APCON
  ├── RUNWT (WTSE$)
  └── (LITES register read)

RUNDMA
  ├── APCON
  ├── APWD (CALL)
  └── RDMA (QIO$)

TSTDMA
  └── APCON

WTDMA
  ├── APCON
  └── DMAWT (WTSE$)

APRSET
  ├── APCON
  ├── CANSUP (QIO$)
  └── SETF (×3)

APIENA
  ├── APCON
  └── CLRCL5 (CLEF$)

APIDIS
  └── APCON

APWI
  └── WTAP (WTSE$)

TSTINT
  ├── APCON
  └── RDFLG (RDAF$)

APIN
  └── APCON

APOUT
  ├── APCON
  ├── APWR (CALL)
  └── SENDER (CALLS) [Super-100, NUM=2]

HPUT
  ├── APCON
  └── SENDER (CALLS)

HGET
  ├── APCON
  └── HTST (CALLS)

HTST
  ├── APCON
  └── IFRUN (CALLS)

LOOKY
  ├── APCON
  └── IFRUN (CALLS)

VIRP
  └── APCON
```

## 6. The Two-LUN Architecture

The FPS-100 requires two logical unit numbers (LUNs) per physical AP processor:

### LUN0 (base unit, stored in UNIT)
- **Purpose:** DMA transfers and standard AP control
- **Used by:** RUNDMA (QIO$ IO.WLB), TERM (QIOW$ function 6)
- **Event flags:** DMAEVF (23), RUNEVF (22)
- **Driver function codes:** 1 (RUNDMA), 6 (TERMSUP)

### LUN1 (UNIT+1, stored in UNIT1)
- **Purpose:** Mode setting and supervisor communication
- **Used by:** SETSUP (QIO$ function 5), STSUP2, CANSUP (IO.KIL)
- **Event flags:** RUNEVF (22), CB5EVF (24)
- **Driver function codes:** 5 (SETMOD/CTL5)

### Why Two LUNs?
1. The AP driver uses different QIO function codes for DMA (1) vs. mode control (5)
2. The driver needs separate I/O channels for concurrent operations
3. The supervisor communication uses CTL5 interrupts which are managed through LUN1
4. DMA transfers on LUN0 can proceed independently of supervisor messages on LUN1

### Assignment:
- APASGN assigns LUN0 via ALUN$ with the AP device
- SETCSR then assigns LUN1 (UNIT+1) via ASGN2
- Both LUNs point to the same physical AP processor

## 7. Glossary of FPS-Specific Terms

### S-Pad (S-PAD)
- **Definition:** Scratch-pad memory locations in the AP-120B/FPS-100
- **Addressing:** 512 words (0-511) of high-speed memory
- **Usage in code:** SPLDGO loads values into S-pads using function codes 513 (into SPD) and 517 (into S-Pad)
- **PDP-11 equivalent:** Like a small, fast array in AP memory

### MD (Memory Data)
- **Context:** Not explicitly used in DAPEX, but referenced in AP-120B documentation
- **Definition:** The main data memory of the AP
- **Relevance:** DMA transfers (RUNDMA) move data between host memory and AP MD

### PSA (Program Start Address)
- **Definition:** The starting address for AP program execution
- **Register:** Written via function code 512
- **Usage:** RUNAP writes PSA to start a program; SPLDGO writes bootstrap starter address

### TMA (Table Memory Address)
- **Definition:** Address in AP table memory (used for constants/tables)
- **Register:** Written via function code 515
- **Usage:** SPLDGO writes starting address to TMA

### APSTAT (AP Status Register)
- **Definition:** Status/control register in the AP
- **Register:** Written via function code 518
- **Usage:** SPLDGO clears parity enable; RUNAP clears parity error enable (function 1030)

### SWR (Switch Register)
- **Definition:** 16-bit register for host-to-AP communication
- **Address:** FPS+110 (offset 110 octal)
- **Usage:** Primary data transfer register; host writes data, AP reads it
- **Protocol:** AP sets bit when it reads; host clears by writing

### FN (Function Register)
- **Definition:** 16-bit register that controls AP operations
- **Address:** FPS+112 (offset 112 octal)
- **Usage:** 
  - Bit 15 (sign): AP running flag (0=running, 1=stopped)
  - Bit 14: AP read SWR flag
  - Lower bits: function codes for various operations
- **Function codes used:**
  - 512 (1000 octal): Load PSA
  - 513 (1001 octal): Into SPD (S-pad data)
  - 515 (1003 octal): Into TMA
  - 517 (1005 octal): Into S-Pad
  - 518 (1006 octal): Into APSTAT
  - 1030 (2006 octal): Clear parity error enable
  - 8192 (20000 octal): Continue bit
  - 8448 (20400 octal): Set breakpoint and go

### LITES (Lights Register)
- **Definition:** 16-bit register for AP-to-host communication
- **Address:** FPS+114 (offset 114 octal)
- **Usage:** AP writes status/result; host reads it
- **Bits:** 7-8 indicate parity (200) or SRAO (40) errors

### CTRL (Control Register)
- **Definition:** 16-bit register for DMA and interrupt control
- **Address:** FPS+104 (offset 104 octal)
- **Bits:**
  - Bit 0 (HDMAGO=1): Start DMA transfer
  - Bit 11 (IHCB5=2000): Enable programmed interrupt (CTL5)
  - Bit 14 (IHWC=4000): Enable DMA done interrupt
  - Bit 15 (IHHALT=10000): Enable AP halt interrupt
  - Bit 14 (APIRT=40000): Interrupt the AP

### WC (Word Count Register)
- **Definition:** DMA word count register
- **Address:** FPS+100 (offset 100 octal)
- **Usage:** Set by RUNDMA before starting DMA transfer

### HMA (Host Memory Address Register)
- **Definition:** Host memory address for DMA
- **Address:** FPS+102 (offset 102 octal)
- **Usage:** Set by driver during DMA setup

### APMA (AP Memory Address Register)
- **Definition:** AP memory address for DMA
- **Address:** FPS+106 (offset 106 octal)
- **Usage:** Set by RUNDMA before starting DMA

### ABRT (Reset Register)
- **Definition:** AP reset/abort register
- **Address:** FPS+116 (offset 116 octal)
- **Usage:** Writing 0 resets the AP; also contains extended memory register values

### FMTH/FMTL (Format High/Low)
- **Definition:** Data format registers for DMA
- **Address:** FPS+0 (FMTH), FPS+2 (FMTL)
- **Usage:** Control data packing/unpacking during DMA

### CTL5 (Control Bit 5)
- **Definition:** Programmed interrupt mechanism
- **Register bit:** IHCB5 (2000) in CTRL register
- **Usage:** AP can interrupt host for attention; used for supervisor communication

### SRAO (Status Register Address Out)
- **Definition:** Error condition in AP
- **Detection:** Bit 6 (40 octal) in LITES register
- **Usage:** WTRUN checks for this error after program completion

### GPIOP (General Purpose I/O Processor)
- **Context:** Diagnostic tool for FPS-100
- **Usage:** SAVLIT stores LITES value for GPIOP diagnostics

### IOSB (I/O Status Block)
- **Definition:** RSX-11M data structure for QIO completion status
- **Size:** 2 words
- **Usage:** All QIO operations check IOSB for success/failure

### DSW (Directive Status Word)
- **Definition:** RSX-11M system variable containing last directive error code
- **Usage:** DIRER returns DSW value as error code

### Event Flags (RUNEVF, DMAEVF, CB5EVF)
- **Definition:** RSX-11M synchronization primitives
- **Values:** 22 (RUNEVF), 23 (DMAEVF), 24 (CB5EVF/TIMEVF)
- **Usage:** 
  - RUNEVF: Set when AP program completes or halts
  - DMAEVF: Set when DMA transfer completes
  - CB5EVF: Set when CTL5 interrupt occurs
  - TIMEVF: Reused for timing (MRKT$/WTSE$)

### ALUN$ (Assign Logical Unit Number)
- **Definition:** RSX-11M directive to associate a LUN with a device
- **Usage:** ASSIGN and ASGN2 macros create ALUN$ directives for LUN0 and LUN1

### QIO$ (Queue I/O)
- **Definition:** RSX-11M directive for device I/O operations
- **Function codes used:**
  - IO

### GLM cooperative

(212s, 9899 chars)

### **1. File-level Overview**
**Purpose**:  
DAPEX.MAC is the host-side dispatcher library for the FPS-100 array processor on RSX-11M. It manages AP assignment, release, I/O, interrupt handling, and supports two operating modes:  
- **AP120**: Host-driven DMA, direct CSR register access.  
- **Super-100/Mini-100**: AP runs embedded supervisor; host communicates via messages (HPUT/HGET).  

**Calling Convention**:  
- Public routines use Fortran-style stack arguments (R5 points to argument list).  
- Status returns placed in R5+0 (e.g., `APASGN` returns status in `@6(R5)`).  
- Internals use register conventions (e.g., R0/R1 scratch, R2/R3 for CSR pointers).  

**RSX Integration**:  
- Uses QIO$/QIOW$ for I/O, ALUN$/ATT/DET for assignment, SETF/CLEF for event flags.  
- Leverages APDRV driver (DRIVER.MAC) with function codes:  
  - `1=RUNDMA`, `5=SETMOD/CTL5`, `6=TERMSUP`.  
- Event flags: `RUNEVF=22`, `DMAEVF=23`, `CB5EVF=24`.  

**Dependencies**:  
- Requires DRIVER.MAC for low-level CSR access and kernel functions.  
- Conditionally compiled for `DF FPS100` (Super-100 support) vs. AP120-only paths.  

---

### **2. Data Structures and Globals**
| **Name**   | **Size** | **Purpose**                                                                 | **Access Pattern**                                  |
|------------|----------|-----------------------------------------------------------------------------|-----------------------------------------------------|
| `RUNFG`    | .WORD    | AP state: `0`=stopped, `>0`=running, `<0`=halted.                          | Read/modified by `RUNAP`, `TSTRUN`, `WTRUN`.         |
| `FPLIT`    | .WORD    | Last LITES register value from AP run or examine.                           | Read by `APIN`, `TSTRUN`, `WTRUN`.                  |
| `FPERF`    | .WORD    | FPS function interpreter flag: `0`=OK, `1`=unimplemented function.          | Set by `SENDER`, checked in `APOUT`.                |
| `FPDAT`    | .BLKW 8  | Stores 8 datums received from FPS-100 (HGET).                               | Written by `SENDER`, read by `HTST`.                |
| `VPBAD`    | .WORD    | Non-zero if bad CTL5 message received.                                     | Checked in `TSTRUN`/`WTRUN`; triggers stop on error.|
| `VGLOB`    | .WORD    | Global variable (purpose unclear).                                          | Unused.                                             |
| `SUPVR`    | .WORD    | Supervisor flag: `0`=none, `>0`=Super-100, `<0`=Mini-100.                   | Set by `APSUPV`; branches mode-specific code.       |
| `FPOPT`    | .BLKW 4  | Message parameters: `(FPOPT, FPSCT, FPSWR, FPFNR)`.                         | Prepared by `APOUT`, `RUNAP`, `SPLDGO`.              |
| `CSRTBL`   | .REPT A$$P11 | Array of CSR addresses for each AP unit.                                | Indexed by unit in `APASGN`.                         |
| `APCSR`    | .WORD    | Current AP CSR address (set in `APASGN`).                                  | Global pointer for CSR access.                      |

---

### **3. Subroutine Catalog**
#### **Public Routines**
##### **APASGN** (Lines 239-320)  
- **Purpose**: Assign FPS-100 unit to task.  
- **Args**: `APNO`, `ACTION`, `STATUS` (via R5 stack).  
- **Effect**:  
  - Assigns LUN (DMA) and LUN1 (supervisor).  
  - Forces AP120 mode initially via `SETSUP`.  
  - Uses `ALUN$`/`ATT`/`DETACH` for unit management.  
- **Conditional**: Path depends on `DF FPS100` (Super-100 support).  
- **Error**: Returns `-1` (in use), `-2` (unavailable), or directive error.  

##### **SPLDGO** (Lines 377-436)  
- **Purpose**: Load S-Pad parameters and start AP program.  
- **Args**: `SLIST`, `NSPADS`, `STRT`, `BRKLOC` (via R5 stack).  
- **Effect**:  
  - **AP120**: Writes S-Pad via `SWR`/`FN` (513/517), sets PSA (512), starts AP (8448).  
  - **Super-100**: Uses `SENDER` with message (option `OPTSPD`).  
  - Enables halt interrupt (`IHHALT`).  
- **Conditional**: Branches on `SUPVR` (L2510 for Super-100).  

##### **RUNDMA** (Lines 594-630)  
- **Purpose**: Start DMA transfer (AP120 mode).  
- **Args**: `HOST`, `APMA`, `N`, `CTRL` (via R5 stack).  
- **Effect**:  
  - Adjusts word count for 16-bit formats (formats 3/4).  
  - Issues `QIO$` function `1` (RUNDMA) via driver.  
- **Error**: STOPS 7 if QIO$ fails.  

##### **TSTDMA/WTDMA** (Lines 634-644, 648-663)  
- **Purpose**: Test/wait for DMA completion.  
- **Effect**:  
  - `TSTDMA`: Returns `0` if done (bit cleared), `1` if busy.  
  - `WTDMA`: Uses `WTSE$ DMAEVF` to wait; returns data-late bit from CTRL.  

##### **APRSET** (Lines 667-697)  
- **Purpose**: Reset AP hardware and state.  
- **Effect**:  
  - Clears CSR registers, resets `RUNFG`/`SUPVR`/`FPLIT`.  
  - Sets event flags (`RUNEVF`, `DMAEVF`, `CB5EVF`).  

##### **APIENA/APIDIS/TSTINT/APWI** (Lines 701-796)  
- **Purpose**: Manage programmed AP interrupts (CTL5) in AP120 mode only.  
- **Effect**:  
  - `APIENA`: Enables IHCB5 bit, clears CB5EVF.  
  - `APIDIS`: Disables IHCB5 bit.  
  - `TSTINT`: Checks CB5EVF flag.  
- **Error**: STOPS 80 if called in Super-100 mode.  

##### **APIN/APOUT** (Lines 800-1040)  
- **Purpose**: Read/write AP interface registers.  
- **Args**: `DATA`, `NUM` (register number: 1=SWR, 2=FN, 3=LITES, ...).  
- **Effect**:  
  - **AP120**: Direct CSR access via `TABLE`.  
  - **Super-100**: Reads/writes globals (`FPSWR`, `FPFNR`, `FPLIT`).  
  - Special handling for extended memory (MASK/APMAE/MAE via LITES).  
- **Conditional**: Branches on `SUPVR` for registers 1-3.  

---

#### **Internal Routines**
##### **SENDER** (Lines 248-338)  
- **Purpose**: Send message to FPS-100 (Super-100 mode only).  
- **Inputs**: R0 (datum), `FPOPT` (options), `FPSCT` (S-Pad count).  
- **Effect**:  
  - Waits for AP to read SWR (via `RDWAIT`).  
  - Writes datum to SWR, interrupts AP (set `APIRT`), then sends 4-word message.  
  - Increments `RUNFG` for APEX messages.  
- **Conditional**: Used only if `SUPVR` ≠ 0.  

##### **IFRUN** (Lines 232-245)  
- **Purpose**: Check AP run state; set `RUNFG = -1` if halted.  
- **Effect**: Tests FN register high bit; negative = running.  

##### **RDWAIT** (Macro, Lines 455-483)  
- **Purpose**: Wait for AP to read SWR register.  
- **Effect**: Loops until FN bit 15 set or timeout (stops 75).  

##### **APWD/APWR** (Macros)  
- **Purpose**: Wrap QIOW$ function 5 (SETMOD) for AP120 mode.  
- **Effect**: Used in `SPLDGO`/`RUNAP` to set AP mode.  

---

### **4. Two-Mode Model**
| **Aspect**          | **AP120 Mode**                                      | **Super-100/Mini-100 Mode**                          |
|---------------------|-----------------------------------------------------|------------------------------------------------------|
| **CSR Access**      | Direct register I/O (`APIN`/`APOUT`).              | Indirect via globals (`FPSWR`, `FPFNR`, `FPLIT`).      |
| **DMA**             | Supported via `RUNDMA`/`TSTDMA`/`WTDMA`.             | Not used; host communicates via messages.            |
| **Interrupts**      | `APIENA`/`APIDIS`/`APWI`/`TSTINT` available.       | Disabled; return error 80.                           |
| **AP Start**        | Direct CSR writes (e.g., FN=8448).                  | Message via `SENDER` (option `OPTAPR`).               |
| **S-Pad Loading**   | Sequential SWR/FN writes.                           | Message via `SENDER` (option `OPTSPD`).              |
| **HPUT/HGET**       | Not supported.                                      | Primary host-AP communication.                      |

---

### **5. Call Graph**
```plaintext
APASGN → NOWAIT/ANYAP → SETCSR → ASSIGN/ASGN2
         ↓
SPLDGO → APWR → [AP120: CSR writes] / [Super: SENDER]
         ↓
RUNAP → APWR → [AP120: CSR writes] / [Super: SENDER]
         ↓
TSTRUN → [AP120: FN read] / [Super: IFRUN]
         ↓
RUNDMA → APWD → QIO$(1)
         ↓
WTRUN → [AP120: WTSE$(RUNEVF)] / [Super: RUNFG loop]
         ↓
APIN → [AP120: CSR read] / [Super: FPLIT/FPSWR/FPFNR]
         ↓
APOUT → [AP120: CSR write] / [Super: SENDER for FN]
         ↓
HPUT → SENDER (Super only)
         ↓
HGET → HTST → IFRUN
```

---

### **6. Two-LUN Architecture**
- **LUN (3)**: Main interface for DMA and AP control.  
  - Used in `RUNDMA`, `RUNAP`, `TSTDMA`, etc.  
- **LUN1 (4)**: Reserved for supervisor communication.  
  - Used in `SETSUP` (set AP120 mode), `CANSUP` (cancel supervisor).  
- **Purpose**: Separates DMA (LUN) from supervisor commands (LUN1), enabling safe mode switching.

---

### **7. Glossary of FPS Terms**
| **Term**      | **Definition**                                                                |
|---------------|------------------------------------------------------------------------------|
| **S-Pad**     | Scratch Pad memory in AP; loaded via SWR (addr) + FN (513/517 = write value). |
| **MD**        | Memory Data (part of CTRL register bits for DMA).                           |
| **PSA**       | Program Start Address; AP program entry point.                                |
| **TMA**       | Temporary Memory Address (alias for APMA in SPLDGO).                          |
| **APSTAT**    | AP Status register; written via FN 518 (clear parity).                        |
| **LITES**     | 16-bit register reflecting AP state/errors.                                  |
| **HPUT/HGET** | Host Put/Get: Send/receive 13-bit datums via FPS-100 (Super mode only).      |
| **RUNFG**     | Run Flag: Software state of AP (running/stopped/halted).                     |
| **FPDAT**     | Array storing 8 received datums from FPS-100.                                |
| **FPLIT**     | FP Lights: Last captured LITES value.                                        |
| **FPERF**     | FP Error: Indicates unimplemented function in Super mode.                     |
| **SUPVR**     | Supervisor flag: Controls AP mode (0=AP120, >0=Super-100, <0=Mini-100).    |