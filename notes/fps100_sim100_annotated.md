# SIM100.FTN — Council-of-Clankers reference annotation

SIM100 is the FPS-100/AP-120B simulator (4910 lines of PDP-11 FORTRAN-IV-PLUS, 1979 vintage). It is the **bit-exact AP-120B microarchitecture reference in code form**.

Cooperative + adversarial analysis via DeepSeek and GLM-4.5-air, split across 6 subroutine clusters.


---

## Cluster: `main_apd` (lines 1-2477)

**Main driver + APD command-interp + DBGSYM + APSIM cycle loop**

### DeepSeek final

(adv 107s, 21592c)

Looking at the peer analysis, I find it has several significant issues:

1. **Incorrect subroutine boundaries**: It treats `APD` as one subroutine when the code actually contains `APD` (the main debug loop) and `APSIM` (the core simulator) as separate subroutines. The `DBGSYM` is correctly identified as block data.

2. **Missing critical details**: The analysis glosses over the 24-field instruction format, the actual bit manipulation in `SPLIT`, and the specific AP-120B register mappings.

3. **Inaccurate pipeline descriptions**: The peer says "FMB1/FMB2/FMB3" for multiplier pipeline but misses that these are 7-element arrays where element 7 holds condition/status bits.

4. **Incomplete state tracking**: Misses the `SPCOM` common block and the `IHOLD` array used for S-PAD state preservation.

5. **Wrong about FPADD/FPMUL**: Claims these are "not in this section" when they're actually called at lines 34300 and 35310.

Here is my corrected, comprehensive analysis:

---

## Structured Analysis of SIM100.FTN Section: Main Driver + APD + DBGSYM + APSIM

### 1. Per-Subroutine Reference

---

#### **Main Program (lines 1-30)**
- **Signature:** Implicit program unit (no SUBROUTINE/FUNCTION header)
- **Purpose:** Top-level driver that alternates between debug command interpretation and instruction execution
- **Inputs/Outputs:** None directly; all state via COMMON
- **AP-120B Operation:** None directly; orchestrates the simulation loop
- **Key logic:**
  - `IP1=0` initially, calls `APD(0)` which initializes and returns immediately
  - Loop at label 20 calls `APSIM` repeatedly for `IPROC` iterations (instruction executions)
  - After `IPRCT` reaches `IPROC`, sets `IP1=1` and calls `APD(1)` which prints PSA and elapsed time
  - This implements the "run until breakpoint" or "step N instructions" model

---

#### **SUBROUTINE APD(IP1)** (lines 31-480)
- **Signature:** `SUBROUTINE APD(IP1)` where `IP1` is integer flag
- **Purpose:** Debug command interpreter for AP-120B simulator; handles user I/O, memory/register examination/modification, breakpoints, file I/O
- **Inputs:** `IP1=0` for initialization, `IP1=1` for post-execution status display; reads from `ITTI` (terminal input channel)
- **Outputs:** Writes to `ITTO` (terminal output channel); modifies all COMMON state
- **AP-120B Operation:** None directly; this is the debug/monitor interface, not hardware simulation
- **State modified:** All COMMON variables including `DPX`, `DPY`, `SP`, `SRS`, `APREG`, `BRKTYP`, `BRKLOC`, `CYCLES`, `CLOCK`, `MEMSPD`, `DPSIZE`, `SPSIZE`, `IORST`, `IHLT`, `FP`, `FIE`, `H`, `OFF`, `OPN`, `IPROC`, `NIOBPT`, `IOBKPT`, `INTTYP`, `IOINT`
- **Key subroutines called:**
  - `SETTY(ITTI,ITTO)` - Initialize terminal I/O channels
  - `AREAD(IA,N,ITTI,ITTO)` - Read N ASCII words from terminal
  - `IREAD(DEC,RADIX,ITTI,ITTO)` - Read integer in given radix
  - `UNPKRG(DEC,WRK)` - Convert integer to 2-byte register format
  - `PAKRG(WRK,WXY)` - Convert 2-byte register format to integer
  - `NUMOUT(WXY,DIGITS,H)` - Format integer as 6 ASCII digits in radix H
  - `PSMEM(MODE,LOC,BUF)` - Read/write Program Source memory (64-bit words)
  - `MDMEM(MODE,LOC,BUF)` - Read/write Main Data memory (38-bit words)
  - `TMMEM(MODE,LOC,BUF)` - Read/write Table Memory (38-bit words)
  - `MREAD(ARRAY,LOC,BUF,SIZE,NSRC,NDST)` - Read from any memory array
  - `MWRIT(BUF,ARRAY,LOC,SIZE,NSRC,NDST)` - Write to any memory array
  - `MOVPRT(SRC,SS, DST,DS, NSRC,NDST,N)` - Move N elements between arrays
  - `SPLIT(CB,FV)` - Decode 64-bit program word into 24 instruction fields
  - `FPOUT(REG,DECFP,MAXEX,IOV)` - Convert 38-bit FP to host double
  - `FPINPT(DECFP,REG)` - Convert host double to 38-bit FP
  - `FREAD(DECFP,ITTI,ITTO)` - Read floating point from terminal
  - `INCODE(J,I,REG)` - Modify one field of a program word
  - `LODINP(ITTI,ITTO)` - Load APLOAD format output into memory
  - `GTFIL(ISL,ITTI,ITTO)` - Get file channel for YANK/WRITE
  - `CLFIL(ISL,ITTO)` - Close file
  - `LAND(N,A,B,C)` - Bitwise AND of N-element arrays
  - `LCOM(A,B,N)` - Bitwise complement
  - `TCADD(A,B,C,N,K)` - Two's complement addition with carry
  - `LSHFT(A,I,N,IN,K1,K2)` - Logical shift

- **Command dispatch table (line 1020):** 26 commands mapped to computed GOTO indices:
  - 1: R (Run) - Load PSA, reset cycles
  - 2: Q (Quit count) - Set IPROC breakpoint counter
  - 3: B (Breakpoint) - Set breakpoint on PS/MD/TM
  - 4: D (Delete breakpoints)
  - 5: S (Step) - Set IHLT step count
  - 6: F (Float flag) - Toggle FP I/O mode
  - 7: V (Value flag) - Toggle field vs. integer PS display
  - 8: L (List breakpoints)
  - 9: E (Examine) - Read memory/register
  - 10: . (Re-examine current)
  - 11: + (Increment location)
  - 12: - (Decrement location)
  - 13: I (IORST) - Set reset flag
  - 14: C (Change) - Modify current location
  - 15: P (Proceed) - Continue execution
  - 16: Z (Zero) - Clear all memories and registers
  - 17: N (Number base) - Set radix (8/10/16)
  - 18: Y (Yank) - Read data from file
  - 19: W (Write) - Write data to file
  - 20: O (Offset) - Set address offset
  - 21: M (Memory speed) - Set 1 or 2 cycle memory
  - 22: X (Exit) - STOP
  - 23: T (Time) - Print elapsed time
  - 24: U (User mode) - Set supervisor/user mode bits
  - 25: A (Assign interrupt) - Set IO interrupt breakpoint
  - 26: G (Get APLOAD) - Load APLOAD format file

---

#### **SUBROUTINE DBGSYM** (lines 481-600)
- **Signature:** `SUBROUTINE DBGSYM` (BLOCK DATA initialization)
- **Purpose:** Initialize symbol tables, memory sizes, and debug metadata for the simulator
- **Inputs/Outputs:** None; all via COMMON blocks
- **AP-120B Operation:** None; this is debug infrastructure only
- **COMMON blocks initialized:**
  - `/Q/` - Contains `C(26)` command codes, `N(2,41)` memory/register names, `F(2,41)` field names, `T(41)` data types, `L(33)` APREG pointers
  - `/IDTB/` - Contains `IBLNK`, `INSIGN`, `IPSIGN`, `IPOINT`, `IEXP`, `IDB(16)` digit table for I/O formatting
  - `/PSRM/` - `PS(512,4)` Program Source memory, `PSSIZE=512`
  - `/MDRM/` - `MD(512,3)` Main Data memory, `PAGNUM=1`, `PAGSIZ=512`
  - `/IORM/` - `IODEV(64,3)` I/O devices, `IOSIZE=64`
- **Data type codes (T array):**
  - 1 = 16-bit integer (S-Pad, SRS, MA, TMA, DPA, PSA, SPD, STATUS, etc.)
  - 2 = 38-bit floating point (DPX, DPY, MD, TM, FA, FM, M1, M2, A1, A2)
  - 3 = 64-bit program word (PS)
- **APREG pointer map (L array):** Maps register names to starting byte positions in APREG(118):
  - L(1)=1: MA (bytes 1-2)
  - L(2)=3: TMA (bytes 3-4)
  - L(3)=5: DPA (bytes 5-6)
  - L(4)=7: PSA (bytes 7-8)
  - L(5)=9: SPD (bytes 9-10)
  - L(6)=11: STATUS (bytes 11-12)
  - L(7)=13: DA (bytes 13-14)
  - L(8)=15: SWITCH (bytes 15-16)
  - L(9)=17: LIGHTS (bytes 17-18)
  - L(10)=19: SRA (bytes 19-20)
  - L(11)=25: FA (bytes 25-30, 38-bit)
  - L(12)=31: FM (bytes 31-36)
  - L(13)=37: M1 (bytes 37-42)
  - L(14)=43: M2 (bytes 43-48)
  - L(15)=49: A1 (bytes 49-54)
  - L(16)=51: A2 (bytes 51-56)
  - L(17)=53: DPXW (bytes 53-58)
  - L(18)=55: DPYW (bytes 55-60)
  - L(19)=57: SMA (bytes 57-58)
  - L(20)=63: STAT2 (bytes 63-64)
  - L(21)=69: STAT3 (bytes 69-70)
  - L(22)=75: IMASK (bytes 75-76)
  - L(23)=81: CCTR (bytes 81-82)
  - L(24)=87: CCST (bytes 87-88)
  - L(25)=93: CCTL (bytes 93-94)
  - L(26)=99: DPIX (bytes 99-100)
  - L(27)=105: DPIY (bytes 105-106)
  - L(28)=107: SMA (bytes 107-108)
  - L(29)=109: ST2 (bytes 109-110)
  - L(30)=111: ST3 (bytes 111-112)
  - L(31)=113: IMSK (bytes 113-114)
  - L(32)=115: CCTR (bytes 115-116)
  - L(33)=117: CCST (bytes 117-118)

---

#### **SUBROUTINE APSIM** (lines 601-1200)
- **Signature:** `SUBROUTINE APSIM`
- **Purpose:** Core AP-120B instruction cycle simulator; fetches, decodes, and executes one instruction per call
- **Inputs/Outputs:** All via COMMON blocks; returns when `HALT` flag is set
- **AP-120B Operation:** Complete simulation of one AP-120B machine cycle including:
  - Instruction fetch from Program Source memory
  - Instruction decode via SPLIT into 24 fields
  - Branch condition testing
  - Data pad (DPX/DPY) read operations
  - Table Memory (TM) fetch
  - Main Data memory (MD) pipeline management
  - S-Pad ALU operations (16-bit)
  - Bus selection and routing (Panel Bus, Data Pad Bus, Input Bus)
  - Floating-point adder pipeline (FADD)
  - Floating-point multiplier pipeline (FMUL)
  - Register updates (MA, TMA, DPA, PSA, STATUS, FLAG)
  - I/O operations
  - Interrupt handling
  - Breakpoint checking

- **Key state variables (COMMON):**
  - `DPX(32,3)`, `DPY(32,3)`: Data pads (38-bit, 32 entries × 3 pipeline stages)
  - `SP(16,1)`, `SRS(16,1)`: S-Pad (16-bit) and Subroutine Return Stack (16-bit)
  - `MA(2)`, `TMA(2)`, `DPA(2)`, `PSA(2)`: Address registers (16-bit each)
  - `SPD(2)`, `STATUS(2)`, `DA(2)`, `SWITCH(2)`, `LIGHTS(2)`: Control registers
  - `SRA(2)`, `SMA(2)`, `STAT2(2)`, `STAT3(2)`, `IMASK(2)`: Supervisor registers
  - `CCTR(2)`, `CCST(2)`, `CCTL(2)`: Clock/timer registers
  - `MDR(6)`, `TMR(6)`, `MI(6)`: Memory buffers (38-bit)
  - `DPXR(6)`, `DPYR(6)`, `DPXW(6)`, `DPYW(6)`: Data pad read/write buffers
  - `SPSR(2)`, `SPDR(2)`, `SPFN(2)`: S-Pad source, destination, function result
  - `DPIB(6)`: Data Pad Input Buffer
  - `INBS(6)`, `DPBS(6)`, `PNLBS(2)`: Buses (Input, Data Pad, Panel)
  - `M1(6)`, `M2(6)`, `FM(6)`: Multiplier pipeline registers
  - `A1(6)`, `A2(6)`, `FA(6)`: Adder pipeline registers
  - `FMB1(7)`, `FMB2(7)`, `FMB3(7)`: Multiplier pipeline stages (7th element = status)
  - `FAB1(7)`, `FAB2(7)`: Adder pipeline stages
  - `TMB1(6)`, `TMB2(6)`: TM pipeline stages
  - `MDB1(7)`, `MDB2(7)`, `MDB3(7)`: MD pipeline stages

- **Instruction fields (FV array, 24 elements):**
  - `FV(1)=DF`: Data format (0=normal, 1=bit reverse)
  - `FV(2)=SOPF`: S-Pad operation field
  - `FV(3)=SHF`: Shift field (0=none, 1=left 1, 2=right 2, 3=right 1)
  - `FV(4)=SPSF`: S-Pad source field
  - `FV(5)=SPDF`: S-Pad destination field
  - `FV(6)=FADDF`: Floating adder function field
  - `FV(7)=A1F`: Adder input 1 field
  - `FV(8)=A2F`: Adder input 2 field
  - `FV(9)=CONDF`: Condition/branch field
  - `FV(10)=DISPF`: Displacement field (branch offset)
  - `FV(11)=DPXF`: DPX write field
  - `FV(12)=DPYF`: DPY write field
  - `FV(13)=DPBSF`: Data Pad Bus select field
  - `FV(14)=XRF`: DPX read address field
  - `FV(15)=YRF`: DPY read address field
  - `FV(16)=XWF`: DPX write address field
  - `FV(17)=YWF`: DPY write address field
  - `FV(18)=FMF`: Floating multiplier function field
  - `FV(19)=M1F`: Multiplier input 1 field
  - `FV(20)=M2F`: Multiplier input 2 field
  - `FV(21)=MIF`: Memory increment/write field
  - `FV(22)=MAF`: Memory address field
  - `FV(23)=DPAF`: Data pad address field
  - `FV(24)=TMAF`: Table memory address field

---

### 2. Bit-Level Semantics

#### **38-bit Floating Point Format (AP-120B)**
The AP-120B uses a unique 38-bit floating point format:
- **Bit layout:** 1 sign + 9 exponent + 28 mantissa
- **Storage in simulator:** 3 × 16-bit words (but only 38 bits used)
  - Word 1 (bytes 1-2): Exponent (bits 0-8) + sign (bit 9) + high mantissa bits (bits 10-15)
  - Word 2 (bytes 3-4): Middle mantissa (bits 16-31)
  - Word 3 (bytes 5-6): Low mantissa (bits 32-37, only 6 bits used)

- **In `FPOUT`/`FPINPT` calls (lines 1892, 2352):** These convert between the 38-bit format and host double precision, handling the different exponent ranges

#### **16-bit Integer Format (S-Pad, SRS, control registers)**
- Stored as 2 bytes: `REG(1)` = high byte, `REG(2)` = low byte
- Two's complement arithmetic via `TCADD` subroutine
- **Bit reversal operation (lines 13030-13050):**
  ```fortran
  J = 15 - MOD(STATUS(2), 8)  ! Shift count from STATUS bits 0-2
  CALL LSHFT(SPSR, -1, 2, 0, K, K)  ! Rotate right through carry
  ```
  This implements the AP-120B's bit-reverse addressing mode for FFT

#### **64-bit Program Word Format**
- Stored as 4 × 16-bit words: `CB(1)` through `CB(8)` as bytes
- Decoded by `SPLIT` into 24 fields (FV array)
- **Field extraction (EQUIVALENCE at lines 680-690):**
  ```fortran
  EQUIVALENCE (FV(1),DF), (FV(2),SOPF), ... (FV(24),TMAF)
  ```

#### **Address Computation**
- **PSA (Program Status Address):** 16-bit, but only 12 bits used (4K words)
  ```fortran
  PSAV = MOD(PSA(1), 16) * 256 + PSA(2)  ! Line 10000
  ```
  `PSA(1)` masked to 4 bits (bits 8-11), `PSA(2)` gives bits 0-7

- **DPA (Data Pad Address):** 6-bit address (0-63)
  ```fortran
  DPA(1) = 0
  DPA(2) = MOD(DPA(2), 64)  ! Line 30050
  ```

- **XRA/YRA/XWA/YWA computation (line 12000):**
  ```fortran
  XRA = MOD(DPA(2) + XRF + 28, 32)  ! DPX read address
  YRA = MOD(DPA(2) + YRF + 28, 32)  ! DPY read address
  XWA = MOD(DPA(2) + XWF + 28, 32)  ! DPX write address
  YWA = MOD(DPA(2) + YWF + 28, 32)  ! DPY write address
  ```
  The `+28` implements modulo-32 arithmetic with offset

#### **Status Register Bit Fields**
- `STATUS(1)` (line 30000):
  - Bits 0-2: `SPCOND` (S-Pad condition codes)
  - Bits 3-5: `FACOND` (Floating adder condition codes)
  - Bits 5-7: `FPERR` (Floating point error flags)
  
- `STATUS(2)`:
  - Bits 0-2: Shift count for bit-reverse
  - Bit 3: FFT mode flag
  - Bit 4: IFFT flag
  - Bit 5: SRA overflow flag

- `STAT2(1)` (supervisor mode bits):
  - Bit 2: MAS (Memory Address Select)
  - Bit 3: INTU (Interrupt User)
  - Bit 4: MO (Mode - supervisor/user)
  - Bits 5-7: PMO, PINTU, PMAS (previous state saved during interrupt)

---

### 3. State and Side Effects

#### **COMMON Block /Q/ (C, N, F, T, L)**
- **Read by:** APD (command lookup, register name display)
- **Written by:** DBGSYM (initialization only)
- **AP-120B state:** Debug metadata only, not hardware state

#### **COMMON /IDTB/ (IBLNK, INSIGN, etc.)**
- **Read by:** APD (NUMOUT, IREAD, FREAD)
- **Written by:** DBGSYM
- **AP-120B state:** Character conversion tables

#### **COMMON /IORM/ (IODEV, IOSIZE, INTTYP, IOINT, IOBKPT, NIOBPT, TMSPEC)**
- **Read by:** APD, APSIM
- **Written by:** APD, APSIM
- **AP-120B state:** I/O device memory (64 devices × 3 words), interrupt state, I/O breakpoints

#### **COMMON /SPCOM/ (IHOLD)**
- **Read by:** APSIM (lines 13000, 13860-13870)
- **Written by:** APSIM
- **AP-120B state:** Temporary S-Pad state preservation during multi-cycle operations

#### **COMMON DPX, DPY, SP, SRS, MA, TMA, DPA, PSA, ... (main simulator state)**
- **Read by:** APD, APSIM
- **Written by:** APD, APSIM
- **AP-120B state:** Complete architectural state including:
  - Data pads (DPX, DPY) - 38-bit register file
  - S-Pad (SP) - 16-bit scratchpad
  - Subroutine return stack (SRS) - 16-level stack
  - Address registers (MA, TMA, DPA, PSA)
  - Control registers (STATUS, DA, SWITCH, LIGHTS, FLAG, SRA)
  - Pipeline registers (FA, FM, M1, M2, A1, A2)
  - Supervisor registers (SMA, STAT2, STAT3, IMASK, CCTR, CCST, CCTL)
  - Memory buffers (MDR, TMR, MI, DPBS, INBS, PNLBS, SPFN)
  - Pipeline stage buffers (MDB1-3, FMB1-3, FAB1-2, TMB1-2)

#### **COMMON /TMRM/ (TM, RAMSIZ, TRIGSZ, HFFTSZ, SFFTSZ, RAMBAS)**
- **Read by:** APSIM (FFT mode lookup)
- **Written by:** External initialization
- **AP-120B state:** Table Memory (TM) - 512 × 38-bit words, FFT table parameters

#### **COMMON /FVV/ (FV)**
- **Read by:** APSIM
- **Written by:** APSIM (via SPLIT call)
- **AP-120B state:** Current instruction's decoded fields

---

### 4. AP-120B-Specific Edge Cases

#### **38-bit Floating Point Range**
- The AP-120B has larger dynamic range than most host computers
- `MAXEX=256` (line 80) set for IBM 360 format (7-bit hex exponent)
- **Overflow check (line 1892):** `FPOUT` returns `IOV=1` if host can't represent the value
- **Underflow:** Not explicitly handled; the 38-bit format has 9-bit exponent allowing values from ~10^-154 to ~10^154

#### **Two-Cycle Memory Instructions**
- `TWOCYC` flag (line 10000): Set to 2 when PS-to-DPBS or DPBS-to-PS operations occur
- **Pipeline push (lines 60020-60030):** Extra cycle inserted for two-cycle instructions
- **Memory lockout (line 41500):** `THISBK` and `LASTBK` track bank conflicts
  ```fortran
  THISBK = (MOD(TA(6), 16) * 32) + (MAV / 4096) + MOD(MAV, 2)
  ```
  If same bank accessed in consecutive cycles, extra wait states inserted

#### **FFT Mode (lines 40100-40200)**
- Triggered by `STATUS(2)` bit 3
- TMA address reinterpreted as:
  - Bit 15: 0=cosine, 1=sine
  - Bits 2-3: Quadrant (0-3)
  - Bits 4-14: Angle within quadrant
- **Special case:** `TMAV = SFFTSZ` forces zero (π/2 not in table)

#### **Subroutine Stack Overflow/Underflow**
- **Overflow (line 51150):** `SRA(2)/15.EQ.0` checks if stack pointer exceeds 15
  - Wraps to `MOD(SRA(2), 16)` and sets `STATUS(2)` bit 5 (SRAO)
- **Underflow (line 51200):** Same check after return; also sets SRAO

#### **Interrupt Handling (lines 60000-60020)**
- **INTRPT subroutine** called with mode parameter:
  - Mode 1: Cause interrupt on device index
  - Mode 2: Check for pending interrupts
  - Mode 3: Clear interrupt and get device index
- **Interrupt action:** Saves current state to `STAT2` bits 5-7, sets supervisor mode, JSR to location 0
- **Clock interrupt (line 10020):** `CLKINT` flag triggers interrupt on device index 8

#### **Supervisor/User Mode (STAT2 bits)**
- `SMODE = MOD(STAT2(1)/16, 2)` - Supervisor mode flag
- `MAMODE = MOD(STAT2(1)/4, 2)` - Memory address mode
- **Effects:**
  - Supervisor mode skips memory pipeline spin (line 12550)
  - Supervisor mode skips condition bit updates (line 12600)
  - Supervisor mode uses SMA instead of MA for memory addressing
  - User mode updates STAT2/STAT3 with instruction field info (lines 30001)

#### **RDPI/WDPI (Read/Write Data Pad Inhibit)**
- `RDPI` flag (line 33000): Set when `SOPF=1, SPSF=4, SPDF=9`
  - Causes DPX/DPY read from write buffer instead of memory (line 12010)
- `WDPI` flag (lines 33120, 33220): Set when `SOPF=1, SPSF=4, SPDF=10`
  - Inhibits actual write to DP memory, only updates write buffer

#### **Page Select Option (lines 32245-32250)**
- I/O devices 24-26 control memory banking
- Device 24: Page register
- Device 25: Mode register
- Device 26: Mask register (one's complement)
- **Bank conflict detection (line 41500):** Uses page register to detect conflicts

---

### 5. Cross-References

#### **APD Calls:**
| Subroutine | Purpose | Location in code |
|------------|---------|------------------|
| `SETTY` | Initialize terminal I/O | Line 100 |
| `AREAD` | Read ASCII command/name | Lines 1000, 1300, 1800, 2453, 5000, 5010 |
| `IREAD` | Read integer value | Lines 1100, 1200, 1315, 1500, 1600, 1700, 1815, 2301, 2332, 2520, 3100, 3200, 4000, 4100, 4200, 5015 |
| `UNPKRG` | Integer to 2-byte format | Lines 1100, 2301, 2332, 2520, 5145, 15145 |
| `PAKRG` | 2-byte to integer format | Lines 1111, 1851, 1882, 1893, 6120, 6308 |
| `NUMOUT` | Format number as digits | Lines 1111, 1315, 1760, 1770, 1851, 1882, 1893, 6110, 6120, 6307, 6308, 6330 |
| `PSMEM` | Program Source memory access | Lines 1821, 2401, 2453, 3000, 5160, 6150 |
| `MDMEM` | Main Data memory access | Lines 1822, 2402, 3000, 15150, 5320, 6305 |
| `TMMEM` | Table Memory access | Lines 1823, 2403, 3000, 5320, 6305 |
| `MREAD` | Read from any memory | Lines 1824-1828, 32245 |
| `MWRIT` | Write to any memory | Lines 2404-2408, 32242, 32250 |
| `MOVPRT` | Move bytes between arrays | Lines 1830, 1851, 1882, 1893, 2332, 2420, 5150, 15150, 6120, 6308 |
| `SPLIT` | Decode program word to fields | Lines 1893 |
| `FPOUT` | 38-bit FP to host double | Lines 1892, 6310 |
| `FPINPT` | Host double to 38-bit FP | Lines 2352, 5305 |
| `FREAD` | Read FP from terminal | Lines 2352 |
| `INCODE` | Modify instruction field | Lines 2520 |
| `LODINP` | Load APLOAD format | Lines 5400 |
| `GTFIL` | Get file channel | Lines 5020 |
| `CLFIL` | Close file | Lines 5900 |
| `LAND` | Bitwise AND | Lines 3100, 32250 |
| `LCOM` | Bitwise complement | Lines 32250 |

#### **APSIM Calls:**
| Subroutine | Purpose | Location in code |
|------------|---------|------------------|
| `RMOV` | Copy N bytes between arrays | Lines 90, 10010, 10020, 12010, 12100, 12550, 12600, 13010, 13090, 13110-13114, 20000, 21100-21107, 21500, 21510, 22080, 22100, 22500, 23010-23014, 23200, 23220, 23301-23307, 24110, 24200, 24250, 25000, 30001, 30011-30013, 30101-30103, 30201-30203, 32310, 33000, 34100-34103, 34200-34203, 34300, 35101-35105, 35201-35207, 35300, 35310, 40000, 40200, 41000, 41010, 41560, 51100, 51150, 51200, 60002, 60010, 60020, 60030, 60040 |
| `SPLIT` | Decode program word | Line 10000 |
| `PSMEM` | Program Source memory access | Lines 10000, 23050, 24200, 24250, 25000 |
| `MREAD` | Read from memory | Lines 12010, 13000, 13090, 21105, 21500, 22080, 32245, 41500, 51200 |
| `MWRIT` | Write to memory | Lines 70, 13850, 26000, 31114, 31120, 32105, 32242, 32250, 33120, 33220, 51150, 60002 |
| `MOVPRT` | Move bytes between arrays | Lines 12600, 22010-22060, 23050, 23210-23213, 23220, 23302, 23306, 24101-24103, 24200, 24250, 25000, 30001, 31115-31117, 32102-32107, 32150, 32232-32240, 32250, 33101-33103, 33201-33203, 35206, 35207, 35300, 40200, 41020, 41100, 45120 |
| `TCADD` | Two's complement add | Lines 13050, 13111, 13112, 13107, 23011, 23014, 23306, 30011, 30012, 30101, 30102, 30201, 30202, 31115, 35206, 50020, 51000, 51100, 51200, 60002 |
| `LSHFT` | Logical shift | Lines 13030, 13050, 13800, 45000, 45100, 46000 |
| `LAND` | Bitwise AND | Lines 11614, 13105, 13106, 13107, 30001, 32250, 32400, 45000, 45090, 45100, 45110, 46000, 60000, 60010 |
| `LCOM` | Bitwise complement | Lines 13113, 13106, 13107, 32250, 32400 |
| `NEGATE` | Two's complement negate | Lines 13103, 40200 |
| `FPMUL` | Floating multiply | Lines 34300 |
| `FPADD` | Floating add | Lines 35310 |
|

### GLM final

(adv 2s, 40c)

ERROR: HTTP Error 429: Too Many Requests

### Cooperative drafts

#### DS coop

# Structured Analysis of SIM100.FTN: Main Driver + APD Command-Interp + DBGSYM + APSIM Cycle Loop

## 1. Per-Subroutine Reference

### MAIN (lines 1-30)
- **Signature**: `PROGRAM SIM100` (implicit main program)
- **Purpose**: Top-level driver that alternates between debug command interpretation and simulation execution
- **Inputs/Outputs**: None directly; operates through COMMON blocks
- **AP-120B Operation**: Not a simulation of hardware; it's the simulator executive that controls the debug/simulation loop
- **Key Logic**: 
  - First call to `APD(0)` for initialization
  - Then loops calling `APSIM` `IPROC` times (default 1)
  - After `IPROC` iterations, calls `APD(1)` to return to debugger
  - `IPRCT` counts iterations; `IPROC` sets how many instructions to execute before returning to debug

### APD (lines 31-370)
- **Signature**: `SUBROUTINE APD(IP1)`
- **Purpose**: FPS-100 Command Interpreter / Debugger - provides interactive user interface
- **Inputs**: `IP1` - flag: 0 for initial entry, 1 for return from simulation
- **Outputs**: Modifies all COMMON variables representing AP-120B state
- **AP-120B Operation**: Not a hardware simulation; it's the debug/monitor program that allows user to examine/modify all AP-120B registers and memories

**Command Dispatch Table** (line 1020):
```
1=R(Run), 2=Q(Set break count), 3=B(Breakpoint), 4=D(Delete breakpoints),
5=S(Step), 6=F(FP flag), 7=V(Field value flag), 8=L(List breakpoints),
9=E(Examine), 10=.(Re-examine), 11=+(Increment), 12=-(Decrement),
13=I(IORST), 14=C(Change), 15=P(Proceed), 16=Z(Zero), 17=N(Radix),
18=Y(Yank from file), 19=W(Write to file), 20=O(Offset), 21=M(Memory speed),
22=X(Exit), 23=T(Time), 24=U(Set mode), 25=A(IO interrupt), 26=G(Get APLOAD)
```

### DBGSYM (lines 371-470)
- **Signature**: `SUBROUTINE DBGSYM`
- **Purpose**: Block data initialization for debugger symbol tables
- **Inputs/Outputs**: Initializes COMMON /Q/ and /IDTB/ with command names, register names, field names, and digit tables
- **AP-120B Operation**: Not a simulation; provides the symbolic names for all AP-120B architectural elements

**Key Data Tables**:
- `C(26)` - Command mnemonics (2-character Hollerith)
- `N(2,41)` - Register/memory names (e.g., "PS", "MD", "TM", "DPX", "DPY", "SP", "SRS", "MA", "TMA", "DPA", "PSA", "SPD", "STAT", "DA", "SWCH", "LGTS", "SRA", "SMA", "STAT2", "STAT3", "IMASK", "CCTR", "CCST", "CCTL", "DPIX", "DPIY", "SMA", "ST2", "ST3", "IMSK", "CCTR", "CCST", "CCTL")
- `T(41)` - Data types: 1=16-bit, 2=38-bit, 3=64-bit
- `F(2,41)` - PS instruction field names (24 fields + extras)
- `L(33)` - Pointers into APREG array for register storage

### APSIM (lines 471-850)
- **Signature**: `SUBROUTINE APSIM`
- **Purpose**: Core cycle-accurate simulator of the AP-120B array processor
- **Inputs/Outputs**: Reads/writes all COMMON variables representing AP-120B architectural state
- **AP-120B Operation**: Complete cycle-by-cycle simulation of one AP-120B instruction

**Major Sections**:
- **00000-10000**: Initialize - reset pipelines, set constants
- **10000-12000**: Fetch PS word, decode instruction fields via SPLIT, test branch conditions
- **12000-13000**: Fetch DPX, DPY, TM, MD; get FA, FM results from pipelines
- **13000-20000**: S-Pad functions - ALU operations on S-Pad registers
- **20000-30000**: Bus selects - Panel Bus, Data Pad Bus routing
- **30000-34000**: Update status, MA/TMA/DPA, I/O group fields
- **34000-35000**: Floating-point multiplier pipeline
- **35000-40000**: Floating-point adder pipeline
- **40000-45000**: TM fetch, MD memory cycle
- **45000-50000**: SPECINT field (supervisor mode operations)
- **50000-60000**: Branching, JMP, JSR, RETURN
- **60000-end**: Breakpoint checks, interrupt handling, cycle counting

### PSMEM (referenced but not shown in section)
- **Signature**: `SUBROUTINE PSMEM(MODE, ADDR, BUF)`
- **Purpose**: Read/write Program Source memory (64-bit words)
- **AP-120B Operation**: Simulates the 64-bit PS memory access

## 2. Bit-Level Semantics

### 38-bit Floating Point Format (AP-120B)
The code represents 38-bit values as 6 bytes (48 bits) in arrays like `DPX(32,3)`, `DPXR(6)`, etc. The actual 38-bit format is:
- **Byte 1-2**: Exponent (10 bits, stored in 2 bytes)
- **Byte 3-4**: High mantissa (12 bits, stored in 2 bytes)  
- **Byte 5-6**: Low mantissa (16 bits, stored in 2 bytes)

**Key bit operations**:
```fortran
! Line 23316 - Sign extension check
IF(DPBS(5).LT.128) GO TO 24000  ! Tests bit 7 of byte 5 (sign of low mantissa)
DPBS(3)=15                       ! If negative, set high mantissa to all 1s
DPBS(4)=255                      ! Set exponent to all 1s

! Line 30050 - DPA update with modulo
DPA(2)=MOD(DPA(2),64)           ! DPA is 6-bit register (0-63)

! Line 13850 - S-Pad condition bits
IF(SPFN(1).GE.128) SPCOND=SPCOND+2  ! Test sign bit (bit 7 of byte 1)
IF(SPFN(1).EQ.0.AND.SPFN(2).EQ.0) SPCOND=SPCOND+4  ! Test zero
```

### 16-bit Integer Format
16-bit values use 2 bytes:
```fortran
! Line 23210 - Switch to DPBS
CALL MOVPRT(SWITCH,1,DPBS,1,2,6,2)  ! Move 2 bytes from SWITCH to DPBS(1-2)
DPBS(1)=MOD(DPBS(1),4)              ! Mask to 2 bits (bits 6-7 of byte 1)
```

### PS 64-bit Format
64-bit PS words use 8 bytes (4 16-bit words):
```fortran
! Line 23050 - PS address computation
PSPTR=PSCOMP(1)*256+PSCOMP(2)  ! 16-bit address from 2 bytes
```

### Instruction Field Encoding (24 fields)
The `SPLIT` routine decomposes the 64-bit PS word into 24 fields stored in `FV(24)`:
```fortran
EQUIVALENCE (FV(1),DF),(FV(2),SOPF),(FV(3),SHF),(FV(4),SPSF)
     ,(FV(5),SPDF),(FV(6),FADDF),(FV(7),A1F),(FV(8),A2F)
     ,(FV(9),CONDF),(FV(10),DISPF),(FV(11),DPXF),(FV(12),DPYF)
     ,(FV(13),DPBSF),(FV(14),XRF),(FV(15),YRF),(FV(16),XWF)
     ,(FV(17),YWF),(FV(18),FMF),(FV(19),M1F),(FV(20),M2F)
     ,(FV(21),MIF),(FV(22),MAF),(FV(23),DPAF),(FV(24),TMAF)
```

## 3. State and Side Effects

### COMMON Block Variables and AP-120B State

| COMMON Variable | AP-120B State | Routines Accessing |
|----------------|---------------|-------------------|
| `DPX(32,3)` | Data Pad X (32 words × 38 bits) | APSIM (read/write), APD (examine/change) |
| `DPY(32,3)` | Data Pad Y (32 words × 38 bits) | APSIM (read/write), APD (examine/change) |
| `SP(16,1)` | S-Pad (16 words × 16 bits) | APSIM (read/write), APD (examine/change) |
| `SRS(16,1)` | Subroutine Return Stack (16 words × 16 bits) | APSIM (read/write), APD (examine/change) |
| `PSA(2)` | Program Source Address (16 bits) | APSIM (read/write), APD (examine) |
| `MA(2)` | Memory Address register (16 bits) | APSIM (read/write) |
| `TMA(2)` | Table Memory Address (16 bits) | APSIM (read/write) |
| `DPA(2)` | Data Pad Address (6 bits in byte 2) | APSIM (read/write) |
| `SPD(2)` | S-Pad Destination register (4 bits) | APSIM (read/write) |
| `STATUS(2)` | Status register (16 bits) | APSIM (read/write) |
| `DA(2)` | Device Address register (8 bits) | APSIM (read/write) |
| `SWITCH(2)` | Front panel switches (16 bits) | APSIM (read), APD (set via command) |
| `LIGHTS(2)` | Front panel lights (16 bits) | APSIM (write) |
| `SRA(2)` | Subroutine Return Address pointer (4 bits) | APSIM (read/write) |
| `SMA(2)` | Supervisor Memory Address (16 bits) | APSIM (read/write) |
| `STAT2(2)` | APSTAT2 - Status register 2 | APSIM (read/write) |
| `STAT3(2)` | APSTAT3 - Status register 3 | APSIM (read/write) |
| `IMASK(2)` | Interrupt Mask register | APSIM (read/write) |
| `CCTR(2)` | Clock Counter register | APSIM (read/write) |
| `CCST(2)` | Clock Status register | APSIM (read/write) |
| `CCTL(2)` | Clock Control register | APSIM (read/write) |
| `FA(6)` | Floating Adder output (38 bits) | APSIM (read/write) |
| `FM(6)` | Floating Multiplier output (38 bits) | APSIM (read/write) |
| `M1(6)`, `M2(6)` | Multiplier pipeline inputs | APSIM (read/write) |
| `A1(6)`, `A2(6)` | Adder pipeline inputs | APSIM (read/write) |
| `DPXR(6)`, `DPYR(6)` | DPX/DPY read buffers | APSIM (read/write) |
| `DPXW(6)`, `DPYW(6)` | DPX/DPY write buffers | APSIM (read/write) |
| `MDR(6)` | Main Data memory read buffer | APSIM (read/write) |
| `TMR(6)` | Table Memory read buffer | APSIM (read/write) |
| `MI(6)` | Memory Input buffer (for writes) | APSIM (read/write) |
| `DPBS(6)` | Data Pad Bus (38 bits) | APSIM (read/write) |
| `INBS(6)` | Input Bus (38 bits) | APSIM (read/write) |
| `PNLBS(2)` | Panel Bus (16 bits) | APSIM (read/write) |
| `SPFN(2)` | S-Pad Function result (16 bits) | APSIM (read/write) |
| `FLAG(2)` | Flag register (4 bits) | APSIM (read/write) |
| `CYCLES` | Cycle counter (real) | APSIM (increment), APD (read) |
| `CLOCK` | Clock rate (4.0 MHz default) | APD (set) |
| `MEMSPD` | Memory speed (1 or 2 cycles) | APD (set), APSIM (read) |
| `BRKTYP` | Breakpoint type (0=none, 1=PS, 2=MD, 3=TM) | APD (set), APSIM (check) |
| `BRKLOC` | Breakpoint address | APD (set), APSIM (check) |

### Pipeline State (APSIM internal)
```fortran
FMB1(7),FMB2(7),FMB3(7)  ! Multiplier pipeline stages (byte 7 = valid flag)
FAB1(7),FAB2(7)           ! Adder pipeline stages
MDB1(7),MDB2(7),MDB3(7)   ! Memory data pipeline stages
TMB1(6),TMB2(6)           ! TM pipeline stages
```

## 4. AP-120B-Specific Edge Cases

### 38-bit Floating Point Format
The AP-120B uses a unique 38-bit format: 1 sign + 9 exponent + 28 mantissa. This is larger than most host computers' floating point, requiring special handling:

```fortran
! Line - MAXEX computation for overflow checking
MAXEX=256  ! Set for IBM 360 format (7-bit hex exponent)
! PDP-11 format would be MAXEX=128 (8-bit binary exponent)

! Line 1892 - FP output with overflow check
CALL FPOUT(REG,DECFP,MAXEX,IOV)
IF (IOV.EQ.1) GO TO 1891  ! Out of range
```

### Memory Bank Conflict Detection
```fortran
! Lines 41500-41600 - Memory lock-out check
LASTBK=THISBK
CALL MREAD(IODEV,24,TA,IOSIZE,3,6)
THISBK=(MOD(TA(6),16)*32) + (MAV/4096) + MOD(MAV,2)
IF (MDB2(7).EQ.0.OR.THISBK.EQ.LASTBK) GO TO 45000
CYCLES=CYCLES+1.0  ! Extra cycle for bank conflict
```

### FFT Mode TM Addressing
```fortran
! Lines 40100-40200 - FFT mode sine/cosine table lookup
IQUAD=MOD(TMAV/(SFFTSZ*2),4)  ! Quadrant determination
ICS=MOD(TMAV,2)                ! Cosine(0)/Sine(1) select
TMAV=MOD(TMAV/2,SFFTSZ)       ! Angle within quadrant
```

### Supervisor/User Mode
```fortran
! Line 10010 - Memory address register selection
SMODE = MOD (STAT2(1)/16,2)     ! Supervisor mode flag
MAMODE = MOD (STAT2(1)/4,2)     ! Memory address mode
IF (MAMODE.EQ.1) THEN
    CALL RMOV (SMA,AMA,2)       ! Use supervisor MA
    CALL RMOV (MA,IMA,2)        ! Save user MA
ELSE
    CALL RMOV (MA,AMA,2)        ! Use user MA
    CALL RMOV (SMA,IMA,2)       ! Save supervisor MA
ENDIF
```

### Interrupt Handling
```fortran
! Lines 60000-60010 - Interrupt action
CALL INTRPT (2,K)
IF (K.NE.0) THEN
    ! Save current state to STAT2 bits 0-2
    CALL LAND(28,STAT2(1),ITMP,1)
    CALL LSHFT(ITMP,3,1,0,I,I)
    CALL LAND(31,STAT2(1),STAT2(1),1)
    STAT2(1)=STAT2(1)+ITMP
    ! Set supervisor mode, inhibit interrupts, select SMA
    CALL LAND (227,STAT2(1),STAT2(1),1)
    STAT2(1) = STAT2(1)+20
    ! JSR to location 0
    CALL TCADD (SRA,ONE2,SRA,2,K)
    CALL MWRIT (PSA,SRS,SRAV,16,2,1)
    CALL RMOV (ZERO2,PSA,2)
ENDIF
```

### Clock Interrupt
```fortran
! Line 10020 - Clock interrupt check
IF (CLKINT.EQ.1) CALL INTRPT(1,8)  ! Device index 8 = clock
CALL CLOCK (CLKFIX,CLKSET,(CLKCYC+1.0)/CLCK,CCTR,CCST,CCTL,CLKINT)
```

## 5. Cross-References

### Routines Called from This Section

| Routine | Called From | Purpose |
|---------|-------------|---------|
| `SETTY(ITTI,ITTO)` | APD line | Initialize terminal I/O channels |
| `AREAD(IA,N,ITTI,ITTO)` | APD | Read N ASCII words from terminal |
| `IREAD(DEC,RADIX,ITTI,ITTO)` | APD | Read integer in specified radix |
| `UNPKRG(DEC,WRK)` | APD | Unpack integer to 2 bytes |
| `PAKRG(WRK,WXY)` | APD | Pack 2 bytes to integer |
| `NUMOUT(WXY,DIGITS,H)` | APD | Convert integer to digit array in radix H |
| `MOVPRT(SRC,SI,DST,DI,N,NS,ND)` | APD, APSIM | Move N bytes from SRC(SI) to DST(DI) |
| `PSMEM(MODE,ADDR,BUF)` | APD, APSIM | Read/write Program Source memory |
| `MDMEM(MODE,ADDR,BUF)` | APD, APSIM | Read/write Main Data memory |
| `TMMEM(MODE,ADDR,BUF)` | APD, APSIM | Read/write Table Memory |
| `MREAD(ARRAY,ADDR,BUF,DIM1,DIM2,N)` | APD, APSIM | Read from any memory array |
| `MWRIT(BUF,ARRAY,ADDR,DIM1,DIM2,N)` | APD, APSIM | Write to any memory array |
| `FPOUT(REG,DECFP,MAXEX,IOV)` | APD | Convert 38-bit FP to host double |
| `FPINPT(DECFP,REG)` | APD | Convert host double to 38-bit FP |
| `SPLIT(CB,FV)` | APSIM | Decompose 64-bit PS word into 24 fields |
| `FPMUL(M1,M2,FMB1)` | APSIM | 38-bit floating-point multiply |
| `FPADD(A1,A2,FAB1,FADDF,A1F,SPFN)` | APSIM | 38-bit floating-point add/subtract |
| `RMOV(SRC,DST,N)` | APSIM | Copy N bytes |
| `TCADD(A,B,C,N,K)` | APSIM | Two's complement add with carry |
| `LSHFT(A,I,N,IN,K1,K2)` | APSIM | Logical shift |
| `LAND(A,B,C,N)` | APSIM | Logical AND |
| `LCOM(A,C,N)` | APSIM | Logical complement |
| `NEGATE(A,N,K)` | APSIM | Two's complement negation |
| `TERM(I)` | APSIM | Check for user termination request |
| `INTRPT(MODE,K)` | APSIM | Interrupt handling (1=set, 2=check, 3=clear) |
| `CLOCK(FIX,SET,TIME,CCTR,CCST,CCTL,INT)` | APSIM | Clock simulation |
| `GTFIL(ISL,ITTI,ITTO)` | APD | Get file for I/O |
| `CLFIL(ISL,ITTO)` | APD | Close file |
| `LODINP(ITTI,ITTO)` | APD | Load APLOAD output |
| `FREAD(DECFP,ITTI,ITTO)` | APD | Read floating point from terminal |
| `INCODE(J,I,REG)` | APD | Encode field value into PS word |
| `INTRPT(MODE,K)` | APSIM | Interrupt system (device index K) |

#### GLM coop

### Structured Analysis of SIM100.FTN Section

---

#### 1. **Per-Subroutine Reference**

**`SUBROUTINE APD(IP1)`**  
- **Signature:** `SUBROUTINE APD(IP1)`  
- **Purpose:** Main debug interface and command interpreter for the AP-120B simulator. Initializes state, handles user commands, and calls the execution loop (APSIM).  
- **Inputs/Outputs:**  
  - `IP1`: Integer flag (if 1, prints PSA + elapsed time after execution).  
  - Reads from `ITTI` (console input), writes to `ITTO` (console output).  
- **AP-120B Operation:**  
  - Simulates **user control** of the AP-120B, not a hardware operation. Initializes registers, memories, and debug state.  
  - Handles commands like "R" (run), "S" (step), "B" (breakpoint), and "F" (FP I/O format).

**`SUBROUTINE DBGSYM`**  
- **Signature:** `SUBROUTINE DBGSYM` (block data initialization).  
- **Purpose:** Initializes symbol tables and memory sizes for the debug interface.  
- **Inputs/Outputs:** None (all via COMMON blocks).  
- **AP-120B Operation:**  
  - **No direct hardware simulation.** Defines debug metadata:  
    - Memory/register names (`N` array), command codes (`C`), field types (`T`), and AP-register pointers (`L`).

**`SUBROUTINE APSIM`**  
- **Signature:** `SUBROUTINE APSIM`  
- **Purpose:** Core instruction cycle simulator. Fetches, decodes, and executes AP-120B instructions.  
- **Inputs/Outputs:** All via COMMON blocks.  
- **AP-120B Operation:**  
  - Simulates **datapath pipelines** (FADDM, FMULM, TM fetch, MD fetch), **register updates**, **branch logic**, and **interrupt handling**.  
  - Key micro-operations:  
    - Fetch DPX/DPY from data pads (38-bit).  
    - Update S-PAD (16-bit) and status flags.  
    - Execute FMUL/FADD operations via pipeline push (FMB1/FMB2/FMB3, FAB1/FAB2).  
    - Handle breakpoints and interrupts.

---

#### 2. **Bit-Level Semantics**

- **38-bit Float Representation (AP-120B):**  
  - Stored as **3 words** in registers/memory:  
    - Word 1: Exponent (16 bits).  
    - Word 2: High mantissa (16 bits).  
    - Word 3: Low mantissa (16 bits).  
  - **Bit manipulation in APD (lines 2302-2352):**  
    ```fortran
    IF (FP.NE.0) GO TO 2352  ! FP flag toggles FP vs. integer I/O
    CALL FPINPT(DECFP, REG)  ! Convert double precision to 38-bit format
    ```
  - **Condition bits in STATUS(1) (line 30000):**  
    ```fortran
    STATUS(1) = FPERR*32 + FACOND*8 + SPCOND  ! FPERR[5-7], FACOND[3-5], SPCOND[0-2]
    ```

- **16-bit Fields (S-PAD, SP, SRS):**  
  - **Bit reversal (line 13050):**  
    ```fortran
    J = 15 - MOD(STATUS(2),8)  ! Status bits 0-7 define shift count
    CALL LSHFT(SPSR, -1, 2, 0, K, KC)  ! Rotate right by J bits
    ```

- **64-bit PSA (Program Status Address):**  
  - **Address masking (line 12010):**  
    ```fortran
    PSAV = MOD(PSA(1),16)*256 + PSA(2)  ! PSA(1) masked to bits 0-3
    ```

---

#### 3. **State and Side Effects**

**COMMON Blocks Represented:**  
- **`DPX(32,3)`, `DPY(32,3)`:** 38-bit data pads (32 entries × 3 pipeline stages).  
- **`SP(16,1)`, `SRS(16,1)`:** 16-bit S-PAD and S-Register Stack.  
- **`APREG(118)`:** AP register file (includes PSA, MA, TMA, DPA, STATUS, etc.).  
- **`STATUS(2)`:** Status flags (FPERR, FACOND, SPCOND, interrupt state).  
- **`FAB1(7)`, `FAB2(7)`, `FMB1(7)`:** Adder/multiplier pipelines (7th bit = carry).  
- **`BRKTYP`, `BRKLOC`:** Breakpoint state (PSA, MD, or TM).  
- **`CYCLES`, `CLKCYC`:** Cycle counters.  
- **`STAT2(2)`:** Supervisor/user mode and interrupt enable.  

**State Updates in APSIM:**  
- **Pipeline Push (line 40000):**  
  ```fortran
  CALL RMOV(TMB1, TMB2, 6)  ! TM pipeline push
  ```
- **Memory Lockout (line 41500):**  
  ```fortran
  THISBK = (MOD(TA(6),16)*32) + (MAV/4096) + MOD(MAV,2)  ! Page number lock
  ```
- **Interrupt State (line 60020):**  
  ```fortran
  IF (MAMODE.EQ.1) CALL RMOV(AMA, SMA, 2)  ! Switch user/supervisor MA
  ```

---

#### 4. **AP-120B-Specific Edge Cases**

- **FP Overflow (line 1892):**  
  ```fortran
  IF (IOV.EQ.1) WRITE(ITTO, 54)  ! "OUT OF RANGE" for host FP overflow
  ```

- **Two-Cycle Memory (line 41500):**  
  ```fortran
  IF (MEMSPD.EQ.2.AND.MDB3(7).NE.0.AND.THISBK.EQ.LASTBK) 
    CYCLES = CYCLES + 1.0  ! Extra cycle for 2-cycle memory
  ```

- **FFT Mode (line 40100):**  
  ```fortran
  IF (MOD(STATUS(2)/8,2).EQ.1)  ! FFT flag set in STATUS(2) bit 3
  IQUAD = MOD(TMAV/(SFFTSZ*2),4)  ! Quadrant lookup for sine/cosine
  ```

- **Stack Overflow (line 51150):**  
  ```fortran
  IF (SRA(2)/15.EQ.0)  ! SRA(2) overflow (stack depth > 15)
    STATUS(2) = STATUS(2) + 32  ! Set SRAO flag
  ```

- **Supervisor Mode (line 30001):**  
  ```fortran
  IF (SMODE.EQ.1) GO TO 30001  ! Skip condition updates in supervisor mode
  ```

---

#### 5. **Cross-References**

**APD Calls External Routines:**  
- `SETTY`, `AREAD`, `IREAD`: Handle I/O (not in this section).  
- `UNPKRG`, `PAKRG`: Register conversion (integer ↔ APREG format).  
- `MREAD`, `MWRIT`: Memory access (DPX, DPY, IODEV).  
- `SPLIT`: Decode 24-bit program word into fields (FV array).  
- `FPOUT`, `FPINPT`: FP I/O conversion (38-bit ↔ double precision).  

**APSIM Calls External Routines:**  
- `FPADD`, `FPMUL`: Floating-point arithmetic (not in this section).  
- `INTRPT`: Interrupt handling (not in this section).  
- `LAND`, `LCOM`, `TCADD`: Bitwise logic (not in this section).  

---

### Key Insights
- **APSIM** models the AP-120B’s synchronous 167-ns cycles via pipeline stages (e.g., `FMB1`/`FMB2` for FMUL).  
- **APD** exposes AP-120B state to the user via debug commands (e.g., "E" to examine 38-bit DPX).  
- **DBGSYM** configures debug metadata critical for APD’s command interpretation.  
- Bitfields in `STATUS` and `STAT2` encode microarchitectural state (FP errors, mode, interrupts).  
- Memory timing (MEMSPD) and pipeline pushing are critical for cycle-accurate simulation.


---

## Cluster: `memory` (lines 2478-2746)

**Memory access (PSMEM, MDMEM, TMMEM)**

### DeepSeek final

(adv 58s, 14644c)

## Critique of GLM Analysis

The GLM analysis has several significant errors and omissions:

1. **Incorrect data width assumptions**: The analysis claims 38-bit floats with 56-bit mantissa, but the AP-120B actually uses 38-bit floats with 28-bit mantissa (1 sign + 9 exponent + 28 mantissa). The "high mantissa" and "low mantissa" split in the code is a PDP-11 storage artifact, not a hardware split.

2. **Missing AP-120B architectural context**: The analysis doesn't explain that these routines simulate the AP-120B's memory system where PS, MD, and TM are separate address spaces with different word widths and access patterns.

3. **Incorrect bit-width claims**: The analysis says "9 exponent + 56-bit mantissa" which is wrong. The AP-120B mantissa is 28 bits, stored in two PDP-11 words only because PDP-11 words are 16 bits.

4. **Missing the 8-bit byte orientation**: The code explicitly uses 8-bit-per-word storage (comments say "8-BITS TO A WORD"), which is a PDP-11 simulation artifact, not AP-120B hardware.

5. **Incorrect page number extraction**: The analysis doesn't explain that `MOD(TEMP(6),16)` extracts bits 0-3 of the MAE (Memory Address Extension) register, which selects which of up to 16 MD memory pages.

6. **Missing the write-protect semantics**: The analysis doesn't note that TMMEM's write protection on ROM regions (FFT table, function coefficients) mirrors the AP-120B's actual hardware protection.

7. **Incorrect mantissa split explanation**: The "high mantissa" and "low mantissa" are actually the same 28-bit mantissa stored in two PDP-11 words because PDP-11 integers are 16 bits.

---

# SIM100.FTN Memory Access Routines — AP-120B Microarchitecture Analysis

## 1. Per-Subroutine Reference

### PSMEM — Program Status Memory Access

**Signature**: `SUBROUTINE PSMEM(OP,ADDR,REG)` with `INTEGER OP,ADDR,REG(8)`

**Purpose**: Simulates access to the AP-120B's Program Status (PS) memory, a 512×32-bit memory organized as 4 quarter-words (8 bits each) per 32-bit word. PS memory stores status information for each of the 512 program steps.

**Inputs/Outputs**:
- `OP`: Operation code (0=zero entire memory, 1=read, 2=write)
- `ADDR`: Address in PS memory (0-511, selects which 32-bit word)
- `REG(8)`: 8-element array of 8-bit quarter-words (each element is one quarter-word)

**AP-120B Operation Simulated**: The AP-120B's PS memory holds 512 32-bit words, each containing 4 quarter-words (8 bits each). Each quarter-word encodes a portion of the program status for one microinstruction step. The PS memory is read during each microinstruction cycle to determine the operation to be performed. This routine provides the host (PDP-11) interface to load/read this memory.

**Implementation Details**:
- PS is stored as `PS(512,4)` — 512 words, each with 4 quarter-words
- Zero operation (`OP=0`): Clears all 512×4 = 2048 quarter-words to zero
- Read operation (`OP=1`): Delegates to `MREAD` to copy 8 quarter-words starting at `ADDR` into `REG`
- Write operation (`OP=2`): Delegates to `MWRIT` to copy `REG` into 8 quarter-words starting at `ADDR`

### MDMEM — Main Data Memory Access

**Signature**: `SUBROUTINE MDMEM(OP,ADDR,REG)` with `INTEGER OP,ADDR,REG(6)`

**Purpose**: Simulates access to the AP-120B's Main Data (MD) memory, a paged memory storing 38-bit floating-point numbers. Each MD location holds one 38-bit float: 1 sign bit + 9 exponent bits + 28 mantissa bits.

**Inputs/Outputs**:
- `OP`: Operation code (0=zero entire memory, 1=read, 2=write)
- `ADDR`: Address within a page (0 to PAGSIZ-1)
- `REG(6)`: 6-element array of 8-bit bytes representing one 38-bit float (3 PDP-11 words × 2 bytes each)

**AP-120B Operation Simulated**: The AP-120B's MD memory is organized as up to 16 pages (selected by the MAE register), each containing PAGSIZ locations. Each location holds a 38-bit floating-point number. The MAE (Memory Address Extension) register provides the page number (bits 0-3). The effective address is `page_number * PAGSIZ + ADDR`.

**Implementation Details**:
- MD is stored as `MD(512,3)` — up to 512 locations, each with 3 PDP-11 words (exponent, high mantissa, low mantissa)
- The 38-bit float is stored across 3 PDP-11 words (48 bits total) because PDP-11 words are 16 bits
- Page number extraction: `I = MOD(TEMP(6),16)` — extracts bits 0-3 from the MAE register (stored in IODEV at offset 24)
- Address translation: `J = I * PAGSIZ + ADDR` — computes linear index into MD array
- Zero operation (`OP=0`): Clears all MDSIZE locations (PAGNUM × PAGSIZ)
- Out-of-range reads (`OP=1` with invalid page/address): Returns zeros in all 6 bytes of REG
- Out-of-range writes: Silent return, no operation performed

### TMMEM — Table Memory Access

**Signature**: `SUBROUTINE TMMEM(OP,ADDR,REG)` with `INTEGER OP,ADDR,REG(6)`

**Purpose**: Simulates access to the AP-120B's Table Memory (TM), a multi-region memory containing FFT tables, function coefficients, and writable RAM. Each location holds one 38-bit floating-point number.

**Inputs/Outputs**:
- `OP`: Operation code (0=zero TMRAM only, 1=read, 2=write)
- `ADDR`: Physical address in TM address space (0-4095+RAMSIZ)
- `REG(6)`: 6-element array of 8-bit bytes representing one 38-bit float

**AP-120B Operation Simulated**: The AP-120B's TM memory is divided into three regions:
1. **FFT table** (addresses 0-2047): Read-only ROM containing sine/cosine values for FFT
2. **Function coefficients** (addresses 2048-2348): Read-only ROM containing function approximation coefficients
3. **TMRAM** (addresses 4096+): Writable RAM for user data
4. **Address hole** (2349-4095): Unused address space, returns zeros on read

Additionally, the FPS-100 has a special TMSPEC register at address 177777 (octal) for dedicated control functions.

**Implementation Details**:
- TM is stored as `TM(512,3)` — up to 512 locations, each with 3 PDP-11 words
- Address mapping to array indices:
  - FFT table: `I = ADDR` (direct mapping, addresses 0 to SFFTSZ-1)
  - Function coefficients: `I = ADDR - HFFTSZ + SFFTSZ` (offset by FFT table size)
  - TMRAM: `I = ADDR - RAMBAS + SFFTSZ + TRIGSZ` (offset past ROM regions)
- Zero operation (`OP=0`): Only clears TMRAM region and TMSPEC register, preserving ROM tables
- Write protection: Writes to addresses below RAMBAS (ROM regions) are silently ignored
- Special register at 177777: Uses `UNPKRG` to check if address is all-ones (255,255), then reads/writes TMSPEC via `RMOV`
- Address hole reads: Return zeros in all 6 bytes

## 2. Bit-Level Semantics

### PDP-11 Storage Format for 38-bit AP-120B Floats

The AP-120B uses a 38-bit floating-point format:
- Bit 37: Sign (1 bit)
- Bits 36-28: Exponent (9 bits, biased by 256)
- Bits 27-0: Mantissa (28 bits, normalized with hidden bit)

In the PDP-11 simulation, each 38-bit float is stored in 3 PDP-11 words (48 bits total) because PDP-11 integers are 16 bits:

```
PDP-11 Word 1 (bits 15-0):  Exponent (bits 36-28 of AP-120B float)
                             [bits 15-7 unused, bits 6-0 = exponent bits 8-2]
                             [bit 7 = sign bit? — depends on implementation]

PDP-11 Word 2 (bits 15-0):  High mantissa (bits 27-12 of AP-120B float)
                             [bits 15-0 = mantissa bits 27-12]

PDP-11 Word 3 (bits 15-0):  Low mantissa (bits 11-0 of AP-120B float)
                             [bits 15-4 unused, bits 3-0 = mantissa bits 11-0?]
                             [or bits 15-0 = mantissa bits 11 to -4?]
```

**Important**: The exact bit mapping between PDP-11 words and AP-120B 38-bit format is determined by the FPADD/FPMUL routines (not shown in this section). The memory routines treat the 3 PDP-11 words as opaque 16-bit values.

### 8-bit Byte Orientation

All memory routines use 8-bit bytes as the transfer unit:
- `REG(8)` in PSMEM: 8 bytes = 2 PDP-11 words (32 bits)
- `REG(6)` in MDMEM/TMMEM: 6 bytes = 3 PDP-11 words (48 bits)

This is a PDP-11 simulation artifact. The actual AP-120B transfers 38-bit words directly.

### Address Translation in MDMEM

```
MAE Register (bits 3-0):  Page number (0 to PAGNUM-1)
ADDR parameter:           Address within page (0 to PAGSIZ-1)
Effective index:          J = page_number * PAGSIZ + ADDR
```

The `MOD(TEMP(6),16)` operation extracts the low 4 bits of the MAE register, which is stored in the IODEV array at offset 24 (the MAE register's I/O device number).

### Address Mapping in TMMEM

```
Physical Address Range    Array Index Range          Memory Type
0 to SFFTSZ-1             0 to SFFTSZ-1              FFT Table (ROM)
HFFTSZ to HFFTSZ+TRIGSZ-1 SFFTSZ to SFFTSZ+TRIGSZ-1  Function Coeffs (ROM)
RAMBAS to RAMBAS+RAMSIZ-1 SFFTSZ+TRIGSZ to TMSIZE-1  TMRAM (writable)
2349 to 4095              N/A (hole)                 Returns zeros
177777 (octal)            N/A (special)              TMSPEC register
```

Note: `HFFTSZ` is typically 2048 (half the FFT table size), `SFFTSZ` is 4096 (full FFT table size), and `RAMBAS` is 4096.

## 3. State and Side Effects

### PSMEM

**COMMON Blocks Read/Written**:
- `/PSRM/`: `PS(512,4)` — the PS memory array (read/write), `PSSIZE` — number of valid PS words (read only)

**AP-120B State Represented**:
- `PS` array represents the AP-120B's Program Status memory, a 512×32-bit memory containing quarter-words that encode microinstruction fields

**Side Effects**:
- Zero operation: Destructively clears all PS memory
- Read operation: No state change, returns data in REG
- Write operation: Modifies PS memory at specified address

### MDMEM

**COMMON Blocks Read/Written**:
- `/MDRM/`: `MD(512,3)` — MD memory array (read/write), `PAGNUM` — number of pages (read only), `PAGSIZ` — page size (read only)
- `/IORM/`: `IODEV(64,3)` — I/O device registers, including MAE at offset 24 (read only), `IOSIZE` — I/O device table size (read only)

**AP-120B State Represented**:
- `MD` array represents the AP-120B's Main Data memory, a paged 38-bit floating-point memory
- `IODEV(24,*)` represents the MAE (Memory Address Extension) register, bits 0-3 select the MD page

**Side Effects**:
- Zero operation: Destructively clears all MD memory
- Read operation: No state change, returns data in REG (or zeros if address out of range)
- Write operation: Modifies MD memory at translated address (if address in range)
- MAE register is read but not modified

### TMMEM

**COMMON Blocks Read/Written**:
- `/TMRM/`: `TM(512,3)` — TM memory array (read/write), `RAMSIZ` — TMRAM size (read only), `TRIGSZ` — trig table size (read only), `HFFTSZ` — half FFT size (read only), `SFFTSZ` — full FFT size (read only), `RAMBAS` — TMRAM base address (read only)
- `/IORM/`: `EXTRA(224)` — unused padding (read/write, but not meaningful), `TMSPEC(6)` — special FPS-100 TM register (read/write)

**AP-120B State Represented**:
- `TM` array represents the AP-120B's Table Memory, containing ROM tables and writable RAM
- `TMSPEC` represents the FPS-100's special TM register at address 177777 (octal)

**Side Effects**:
- Zero operation: Clears TMRAM region and TMSPEC register; ROM tables preserved
- Read operation: No state change, returns data from appropriate region (or zeros for hole)
- Write operation: Only modifies TMRAM region or TMSPEC register; ROM writes silently ignored

## 4. AP-120B-Specific Edge Cases

### 38-bit Floating-Point Format

The AP-120B uses a unique 38-bit floating-point format:
- **Sign**: 1 bit (bit 37)
- **Exponent**: 9 bits (bits 36-28), biased by 256 (excess-256 notation)
- **Mantissa**: 28 bits (bits 27-0), normalized with hidden bit (1.0 ≤ mantissa < 2.0)

This format appears in MDMEM and TMMEM where each memory location stores one 38-bit float across 3 PDP-11 words. The exact bit packing is handled by the arithmetic routines (FPADD, FPMUL), not by these memory routines.

### Memory Address Extension (MAE) Register

The MAE register (IODEV offset 24) provides page selection for MD memory. Bits 0-3 select which of up to 16 pages is active. The code extracts this with `MOD(TEMP(6),16)`, which takes the low byte of the 6th word of the MAE register and masks to 4 bits.

### Write Protection

- **MDMEM**: Out-of-range addresses (page number ≥ PAGNUM or address ≥ PAGSIZ) silently ignore writes and return zeros for reads
- **TMMEM**: Addresses below RAMBAS (ROM regions) silently ignore writes, preserving the FFT table and function coefficients

### Address Hole in TMMEM

Physical addresses 2349-4095 in TM space are unmapped ("the hole"). Reads return zeros; writes are silently ignored. This matches the AP-120B hardware where these addresses don't correspond to actual memory.

### Special FPS-100 TM Register

Address 177777 (octal) is a special register in the FPS-100, not actual memory. The code uses `UNPKRG` to detect this address (both bytes = 255 = all ones), then accesses `TMSPEC` via `RMOV` for read/write operations.

### Zeroing Semantics

- **PSMEM**: Zeros all 512×4 quarter-words
- **MDMEM**: Zeros all pages (PAGNUM × PAGSIZ locations)
- **TMMEM**: Only zeros TMRAM region and TMSPEC register; ROM tables are preserved

## 5. Cross-References

### Routines Called by PSMEM

- **`MREAD`** (memory read utility): Called when `OP=1` to copy 8 quarter-words from PS memory to REG. Signature: `MREAD(PS,ADDR,REG,PSSIZE,4,8)` — reads from array PS at index ADDR, with 4 columns per row, transferring 8 elements.

- **`MWRIT`** (memory write utility): Called when `OP=2` to copy 8 quarter-words from REG to PS memory. Signature: `MWRIT(REG,PS,ADDR,PSSIZE,8,4)` — writes REG to array PS at index ADDR, with 8 elements to transfer, 4 columns per row.

### Routines Called by MDMEM

- **`MREAD`** (memory read utility): Called twice:
  1. To read MAE register: `MREAD(IODEV,24,TEMP,IOSIZE,3,6)` — reads IODEV at offset 24 (MAE register), 3 columns, 6 bytes
  2. To read MD data: `MREAD(MD,J,REG,MDSIZE,3,6)` — reads MD at translated index J

- **`MWRIT`** (memory write utility): Called when `OP=2` to write MD data: `MWRIT(REG,MD,J,MDSIZE,6,3)` — writes REG to MD at translated index J

### Routines Called by TMMEM

- **`UNPKRG`** (unpack register): Called to check for special address 177777: `UNPKRG(ADDR,TEMP)` — unpacks ADDR into two bytes in TEMP(1) and TEMP(2)

- **`RMOV`** (register move): Called for TMSPEC access:
  - Read: `RMOV(TMSPEC,REG,6)` — copies 6 bytes from TMSPEC to REG
  - Write: `RMOV(REG,TMSPEC,6)` — copies 6 bytes from REG to TMSPEC

- **`MREAD`** (memory read utility): Called when `OP=1` to read TM data: `MREAD(TM,I,REG,TMSIZE,3,6)` — reads TM at translated index I

- **`MWRIT`** (memory write utility): Called when `OP=2` to write TMRAM: `MWRIT(REG,TM,I,TMSIZE,6,3)` — writes REG to TM at translated index I (only if ADDR ≥ RAMBAS)

### GLM final

(adv 165s, 6737c)

### Structured Analysis of SIM100.FTN Memory Access Routines (PSMEM, MDMEM, TMMEM)

---

### **1. Per-Subroutine Reference**

#### **PSMEM — P.S. (Pad/Scratch) Memory Access**
- **Signature:** `SUBROUTINE PSMEM(OP, ADDR, REG)`  
- **Purpose:** Accesses the 512×32-bit scratchpad register file (S-Pad) of the AP-120B.  
- **Inputs:**  
  - `OP` (INTEGER): Operation code (0=zero, 1=read, 2=write)  
  - `ADDR` (INTEGER): Word address in P.S. memory (0-511)  
  - `REG(8)` (INTEGER array): Data buffer (64 bits, 8 words of 8 bits each)  
- **Outputs:**  
  - Read: `REG` populated with two consecutive 32-bit words from `ADDR` and `ADDR+1`  
  - Write: `REG` written to `ADDR` and `ADDR+1`  
  - Zero: Entire P.S. memory cleared  
- **AP-120B Operation:** Simulates S-Pad (Pad/Scratch) memory access via `SPSF` (read two words) and `SPDF` (write one word) instructions. The S-Pad is a 512-word register file for operand storage.  
- **Storage:** Each 32-bit word stored as 4 PDP-11 words (8 bits/word) in `PS(512,4)`.  

---

#### **MDMEM — Main Data Memory Access**
- **Signature:** `SUBROUTINE MDMEM(OP, ADDR, REG)`  
- **Purpose:** Accesses the paged Main Data Memory (MD) storing 38-bit floating-point numbers.  
- **Inputs:**  
  - `OP` (INTEGER): Operation code (0=zero, 1=read, 2=write)  
  - `ADDR` (INTEGER): Address within current page (0 to `PAGSIZ-1`)  
  - `REG(6)` (INTEGER array): Data buffer (48 bits, 6 words of 8 bits each)  
- **Outputs:**  
  - Read: `REG` populated with two consecutive 38-bit words from current page  
  - Write: `REG` written to two consecutive words in current page  
  - Zero: All MD memory cleared  
  - Out-of-range: Read returns zeros, write ignored  
- **AP-120B Operation:** Simulates access to the 38-bit MD memory via `DPXF`/`DPYF` instructions. Page selection uses the Memory Address Extension (MAE) register.  
- **Storage:** Each 38-bit word stored as:  
  - `MD(addr,1)`: Exponent (8 bits)  
  - `MD(addr,2)`: High mantissa (16 bits)  
  - `MD(addr,3)`: Low mantissa (14 bits)  

---

#### **TMMEM — Table Memory Access**
- **Signature:** `SUBROUTINE TMMEM(OP, ADDR, REG)`  
- **Purpose:** Accesses the combined ROM/RAM Table Memory (TM) for FFT tables, coefficients, and TMRAM.  
- **Inputs:**  
  - `OP` (INTEGER): Operation code (0=zero, 1=read, 2=write)  
  - `ADDR` (INTEGER): 13-bit address (0-8191)  
  - `REG(6)` (INTEGER array): Data buffer (48 bits, 6 words of 8 bits each)  
- **Outputs:**  
  - Read: `REG` populated from TM or special register (address `177777` octal)  
  - Write: `REG` written to TMRAM or special register (address `177777` octal)  
  - Zero: TMRAM and `TMSPEC` cleared  
  - Out-of-range: Read returns zeros, write ignored  
- **AP-120B Operation:** Simulates access to 4096×38-bit TM memory via `FMF` (function memory fetch) instructions.  
- **Storage:** Same as MD (3 words per 38-bit entry). TM layout:  
  - `0-SFFTSZ-1`: FFT table (ROM)  
  - `SFFTSZ-HFFTSZ-1`: Function coefficients (ROM)  
  - `HFFTSZ-RAMBAS-1`: Hole (unused)  
  - `RAMBAS+`: TMRAM (RAM)  

---

### **2. Bit-Level Semantics**
- **38-bit Floating-Point Representation:**  
  Stored in 3 PDP-11 words (24 bits total for exponent/mantissa):  
  - `MD(addr,1)`: Exponent (bits 37-30)  
  - `MD(addr,2)`: High mantissa (bits 29-14)  
  - `MD(addr,3)`: Low mantissa (bits 13-0)  
  - **Total:** 1 sign + 8 exponent + 29 mantissa bits.  

- **MAE Register Extraction (MDMEM, line 203):**  
  ```fortran
  CALL MREAD(IODEV,24,TEMP,IOSIZE,3,6)
  I = MOD(TEMP(6),16)
  ```  
  `MOD(TEMP(6),16)` extracts the lower 4 bits of the MAE register (stored in `IODEV(24,3)`), selecting a page (0-15).  

- **Special Address Detection (TMMEM, line 185):**  
  ```fortran
  CALL UNPKRG(ADDR, TEMP)
  IF (.NOT.(TEMP(1).EQ.255 .AND. TEMP(2).EQ.255)) GO TO 400
  ```  
  `UNPKRG` converts 16-bit address to two 8-bit bytes. Address `177777` (octal) is `0xFFFF` (both bytes = 255).  

---

### **3. State and Side Effects**
| **COMMON Block** | **Variables** | **AP-120B State** |
|------------------|---------------|-------------------|
| `/PSRM/` | `PS(512,4)`, `PSSIZE` | S-Pad register file (512×32-bit) |
| `/MDRM/` | `MD(512,3)`, `PAGNUM`, `PAGSIZ` | Main Data Memory (paged 38-bit floats) |
| `/IORM/` | `IODEV(64,3)`, `IOSIZE`, `EXTRA(224)`, `TMSPEC(6)` | I/O devices (MAE register), FPS-100 special TM register |
| `/TMRM/` | `TM(512,3)`, `RAMSIZ`, `TRIGSZ`, `HFFTSZ`, `SFFTSZ`, `RAMBAS` | Table Memory (FFT/ROM + TMRAM) |

**State Interactions:**  
- `MDMEM` reads `IODEV(24,3)` to get MAE (page select).  
- `TMMEM` writes `TMSPEC(6)` (special TM register) for address `177777` octal.  
- All routines read/write via `MREAD`/`MWRIT` (memory utilities).  

---

### **4. AP-120B-Specific Edge Cases**
- **38-bit Float Format:**  
  Explicitly split into exponent (8 bits) and mantissa (29 bits) for storage in 3 PDP-11 words (24 bits). Sign bit is part of the mantissa.  

- **MD Out-of-Range (MDMEM, lines 400-410):**  
  If `ADDR` exceeds `PAGSIZ` or MAE ≥ `PAGNUM`:  
  - Read: Returns zeros in `REG`.  
  - Write: Ignored.  

- **TMMEM Hole Handling (TMMEM, lines 400-410):**  
  Addresses in "hole" (2349-4095) return zeros on read; writes ignored.  

- **TMMEM Write Protection (TMMEM, line 300):**  
  ```fortran
  IF (ADDR.LT.RAMBAS) RETURN
  ```  
  Writes to ROM regions (FFT table, coefficients) are ignored. Only TMRAM (`ADDR ≥ RAMBAS`) and special register are writable.  

- **FPS-100 Special Register:**  
  Address `177777` octal (`0xFFFF`) accesses `TMSPEC(6)` instead of TM array. Cleared when `OP=0`.  

---

### **5. Cross-References**
| **Called Routine** | **Calling Context** | **Purpose** |
|--------------------|---------------------|-------------|
| `MREAD` | PSMEM(200), MDMEM(200), TMMEM(200) | Generic memory read. Converts array storage (3-4 words/entry) to byte buffer (6-8 words). |
| `MWRIT` | PSMEM(300), MDMEM(300), TMMEM(300) | Generic memory write. Converts byte buffer to array storage. |
| `UNPKRG` | TMMEM(185) | Unpacks 16-bit address into two 8-bit bytes for special address detection. |
| `RMOV` | TMMEM(190, 192) | Moves data between `TMSPEC` and `REG` for special register access. |

---

### Summary
This section simulates the AP-120B's memory hierarchy:  
- `PSMEM`: Manages the 512-word S-Pad register file.  
- `MDMEM`: Handles paged 38-bit MD memory with MAE-based addressing.  
- `TMMEM`: Manages combined ROM/RAM TM memory with write protection and a special register for FPS-100.  

Key hardware semantics include 38-bit float storage, MAE-based paging, ROM/RAM segregation, and special address handling. The code delegates low-level memory operations to `MREAD`/`MWRIT` but explicitly manages AP-120B-specific state (e.g., MAE, TMSPEC).

### Cooperative drafts

#### DS coop

# Analysis of SIM100.FTN Memory Access Routines (PSMEM, MDMEM, TMMEM)

## 1. Per-Subroutine Reference

### PSMEM — P.S. Memory Access

**Signature:** `SUBROUTINE PSMEM(OP, ADDR, REG)`  
**Purpose:** Accesses the Pad/Scratch (P.S.) memory of the AP-120B — the 512×32-bit S-Pad register file.

**Inputs:**
- `OP` (INTEGER): Operation code — 0=Zero, 1=Read, 2=Write
- `ADDR` (INTEGER): Address into P.S. memory (0-511)
- `REG(8)` (INTEGER array): Data buffer — 8 PDP-11 words, each holding 8 bits of the 64-bit P.S. word

**Outputs:**
- On Read: `REG` filled with 8 bytes of data from P.S. memory
- On Write: P.S. memory updated from `REG`
- On Zero: All P.S. memory locations set to zero

**AP-120B Operation Simulated:**  
Simulates access to the **S-Pad register file** (also called P.S. memory in FPS documentation). The S-Pad is a 512×32-bit scratchpad memory used for temporary storage of operands. The AP-120B can read two S-Pad locations per cycle (SPSF fields) and write one (SPDF field). This routine provides the actual memory access mechanism.

**Storage Format:** Each 32-bit S-Pad word is stored across 4 PDP-11 words (8 bits each), indexed as quarters 0-3: `PS(512,4)`.

### MDMEM — Main Data Memory Access

**Signature:** `SUBROUTINE MDMEM(OP, ADDR, REG)`  
**Purpose:** Accesses the Main Data Memory (MD) of the AP-120B — the 38-bit floating-point data memory.

**Inputs:**
- `OP` (INTEGER): Operation code — 0=Zero, 1=Read, 2=Write
- `ADDR` (INTEGER): Address within a page (0 to PAGSIZ-1)
- `REG(6)` (INTEGER array): Data buffer — 6 PDP-11 words representing a 38-bit float (exponent + high mantissa + low mantissa)

**Outputs:**
- On Read: `REG` filled with 6 bytes of MD data
- On Write: MD updated from `REG`
- On Zero: All MD locations set to zero
- On out-of-range read: `REG` set to all zeros

**AP-120B Operation Simulated:**  
Simulates access to the **Main Data Memory**, which stores 38-bit floating-point numbers. The MD is organized as pages (controlled by the Memory Address Extension, MAE register). The AP-120B's MDMEM instruction reads/writes 38-bit operands from/to MD using the address formed by the MAE (page select) and the address field from the instruction.

**Storage Format:** Each 38-bit float is stored across 3 PDP-11 words: exponent (8 bits), high mantissa (16 bits), low mantissa (14 bits) — total 38 bits.

**Page Organization:** The MD is divided into `PAGNUM` pages, each `PAGSIZ` locations long. The MAE register (bits 0-3 of IODEV[24]) selects which page is active.

### TMMEM — Table Memory Access

**Signature:** `SUBROUTINE TMMEM(OP, ADDR, REG)`  
**Purpose:** Accesses the Table Memory (TM) of the AP-120B — a combined ROM/RAM for FFT tables, function coefficients, and general-purpose RAM.

**Inputs:**
- `OP` (INTEGER): Operation code — 0=Zero, 1=Read, 2=Write
- `ADDR` (INTEGER): Memory address (0-8191, but typically 0-6143)
- `REG(6)` (INTEGER array): Data buffer — 6 PDP-11 words

**Outputs:**
- On Read: `REG` filled with 6 bytes of TM data
- On Write: TM RAM updated from `REG` (ROM portion is write-protected)
- On Zero: TM RAM and TMSPEC register cleared
- On out-of-range read: `REG` set to all zeros

**AP-120B Operation Simulated:**  
Simulates access to the **Table Memory**, which in the AP-120B is a 4096×38-bit memory (ROM + RAM). The TM is used for:
- FFT sine/cosine tables (addresses 0-2047)
- Function coefficients for polynomial evaluation (addresses 2048-2348)
- General-purpose RAM (addresses 4096+)

**Special Register:** The FPS-100 extension adds a dedicated TM register at address 177777 (octal), stored in `TMSPEC(6)`.

**Storage Format:** Same as MD — 38-bit floats across 3 PDP-11 words.

## 2. Bit-Level Semantics

### Data Representation

The code uses a **byte-sliced** representation of AP-120B words:

**P.S. Memory (32-bit words):**
- `PS(addr,1)` = bits 31-24 (most significant byte)
- `PS(addr,2)` = bits 23-16
- `PS(addr,3)` = bits 15-8
- `PS(addr,4)` = bits 7-0 (least significant byte)

**MD and TM (38-bit floating-point words):**
- `MD(addr,1)` / `TM(addr,1)` = **Exponent** (8 bits) — bits 37-30
- `MD(addr,2)` / `TM(addr,2)` = **High Mantissa** (16 bits) — bits 29-14
- `MD(addr,3)` / `TM(addr,3)` = **Low Mantissa** (14 bits) — bits 13-0

The 38-bit AP-120B floating-point format:
```
Bit 37: Sign (1 bit)
Bits 36-29: Exponent (8 bits, biased by 128)
Bits 28-0: Mantissa (29 bits, but stored as 16+14 = 30 bits with implied leading 1)
```

### Address Encoding

In `MDMEM`, the MAE register is extracted from `IODEV(24,3)`:
```fortran
CALL MREAD(IODEV,24,TEMP,IOSIZE,3,6)
I = MOD(TEMP(6),16)
```
This reads the 24th I/O device register (which stores the MAE) and extracts bits 0-3 (`MOD(...,16)`) as the page number. The effective MD address is:
```fortran
J = I * PAGSIZ + ADDR
```

### Special Address Encoding (TMMEM)

The FPS-100 special TM register at address 177777 (octal) is detected by:
```fortran
CALL UNPKRG(ADDR, TEMP)
IF (.NOT.(TEMP(1).EQ.255 .AND. TEMP(2).EQ.255)) GO TO 400
```
This unpacks the 16-bit address into two 8-bit bytes and checks if both are 255 (0xFF), which is the byte representation of 177777 octal.

## 3. State and Side Effects

### COMMON Blocks Modified

**`/PSRM/`** — P.S. Memory State
- `PS(512,4)`: The 512×32-bit S-Pad register file
- `PSSIZE`: Size of P.S. memory (typically 512)
- **Read by:** `MREAD` (called from PSMEM)
- **Written by:** `MWRIT` (called from PSMEM), zeroing loop in PSMEM

**`/MDRM/`** — Main Data Memory State
- `MD(512,3)`: The 512×38-bit MD storage
- `PAGNUM`: Number of pages in MD
- `PAGSIZ`: Size of each page
- **Read by:** `MREAD` (called from MDMEM)
- **Written by:** `MWRIT` (called from MDMEM), zeroing loop in MDMEM

**`/IORM/`** — I/O Device State
- `IODEV(64,3)`: 64 I/O device registers, each 3 PDP-11 words (24 bits)
- `IOSIZE`: Size of I/O device array
- **Read by:** `MREAD` (called from MDMEM to get MAE from IODEV[24])
- **Note:** In TMMEM, this COMMON is reused for `EXTRA(224)` and `TMSPEC(6)` — this is a memory overlay trick

**`/TMRM/`** — Table Memory State
- `TM(512,3)`: The TM storage (512×3 PDP-11 words = 512×24 bits, but represents 4096×38 bits through indexing)
- `RAMSIZ`: Size of TMRAM (typically 1024)
- `TRIGSZ`: Size of trigonometric table
- `HFFTSZ`: Half FFT size (start of trig table)
- `SFFTSZ`: Full FFT size
- `RAMBAS`: Base address of TMRAM (typically 4096)
- **Read by:** `MREAD` (called from TMMEM)
- **Written by:** `MWRIT` (called from TMMEM), zeroing loop in TMMEM

### AP-120B Architectural State Represented

| COMMON Variable | AP-120B Register/State |
|----------------|------------------------|
| `PS(1:512,1:4)` | S-Pad register file (512×32-bit) |
| `MD(1:512,1:3)` | Main Data Memory (512×38-bit per page) |
| `IODEV(24,1:3)` | Memory Address Extension (MAE) register |
| `TM(1:SFFTSZ,1:3)` | FFT table ROM (read-only) |
| `TM(SFFTSZ+1:SFFTSZ+TRIGSZ,1:3)` | Trigonometric table ROM |
| `TM(SFFTSZ+TRIGSZ+1:TMSIZE,1:3)` | TMRAM (read/write) |
| `TMSPEC(1:6)` | FPS-100 special TM register |

## 4. AP-120B-Specific Edge Cases

### 38-bit Floating-Point Format

The 38-bit format is explicitly handled through the 3-word storage scheme:
- **Exponent** (8 bits): Stored in `MD(addr,1)` / `TM(addr,1)`
- **High Mantissa** (16 bits): Stored in `MD(addr,2)` / `TM(addr,2)`
- **Low Mantissa** (14 bits): Stored in `MD(addr,3)` / `TM(addr,3)`

The total is 8+16+14 = 38 bits, matching the AP-120B's 38-bit floating-point format (1 sign + 8 exponent + 29 mantissa, with the mantissa split into 16+14 for storage convenience).

### Address Out-of-Range Handling

**MDMEM (lines 400-410):**
```fortran
400     IF (OP.NE.1) RETURN
        DO 410 I=1,6
410     REG(I)=0
```
When the address is out of range (page select too large or address within page too large), reads return zero. Writes are silently ignored. This simulates the AP-120B's behavior of returning zero when accessing non-existent memory.

**TMMEM (lines 400-410):**
```fortran
400     IF (OP.NE.1) RETURN
        DO 410 I=1,6
410     REG(I)=0
```
When the address falls in the "hole" (addresses 2349-4095 in hardware), reads return zero. This simulates the physical gap in the TM address space.

### Write Protection

**TMMEM (line 300):**
```fortran
300     IF (ADDR.LT.RAMBAS) RETURN
```
The ROM portion of TM (FFT tables and function coefficients) is write-protected. Only the TMRAM portion (addresses ≥ RAMBAS) can be written. This matches the AP-120B hardware where the FFT and function coefficient tables are in ROM.

### FPS-100 Extension

The FPS-100 special TM register at address 177777 (octal) is handled as a special case:
- Read: Returns contents of `TMSPEC(6)`
- Write: Updates `TMSPEC(6)`
- This register is cleared when TMMEM is called with OP=0

### MAE Register Access

The MAE register is accessed through the I/O device space at index 24:
```fortran
CALL MREAD(IODEV,24,TEMP,IOSIZE,3,6)
I = MOD(TEMP(6),16)
```
Only the lower 4 bits of the 6th byte are used as the page number, giving a maximum of 16 pages.

## 5. Cross-References

### Called Routines

**`MREAD`** — Generic memory read utility
- Called by: PSMEM (line 200), MDMEM (line 200), TMMEM (line 200)
- Purpose: Reads data from a memory array, converting from the internal storage format (3 or 4 PDP-11 words per AP-120B word) to the 6 or 8 byte output format
- Parameters: (array, index, result_buffer, array_size, words_per_entry, bytes_per_entry)

**`MWRIT`** — Generic memory write utility
- Called by: PSMEM (line 300), MDMEM (line 300), TMMEM (line 300)
- Purpose: Writes data to a memory array, converting from byte format to internal storage format
- Parameters: (source_buffer, array, index, array_size, bytes_per_entry, words_per_entry)

**`UNPKRG`** — Unpack register utility
- Called by: TMMEM (line 185)
- Purpose: Unpacks a 16-bit integer into two 8-bit bytes
- Parameters: (value, result_array)
- Used to detect the special TM register address 177777

**`RMOV`** — Register move utility
- Called by: TMMEM (lines 190, 192)
- Purpose: Copies data between TMSPEC and REG buffers
- Parameters: (source, destination, count)
- Used for the FPS-100 special TM register access

### Routines That Call These

These memory access routines are called by the main simulation loop (not shown in this section) when the AP-120B executes instructions that access P.S. memory, main data memory, or table memory. The specific instruction fields that trigger these calls are:
- **SPSF/SPDF**: P.S. memory read/write → calls PSMEM
- **DPXF/DPYF**: Data pad X/Y access → may call MDMEM or TMMEM
- **FMF**: Function memory fetch → calls TMMEM for function coefficients

#### GLM coop

# Analysis of Memory Access Routines in SIM100.FTN

## 1. Per-subroutine reference

### PSMEM
- **Signature**: `SUBROUTINE PSMEM(OP,ADDR,REG)` with `INTEGER OP,ADDR,REG(8)`
- **Purpose**: Accesses Program Status (P.S.) memory, which stores quarter-word status information
- **Inputs/Outputs**: 
  - OP (0=zero, 1=read, 2=write)
  - ADDR (memory address)
  - REG (8 8-bit words of data)
- **AP-120B Operation**: Simulates access to P.S. memory that stores status information in quarter-word format (4 quarter-words per 32-bit word)

### MDMEM
- **Signature**: `SUBROUTINE MDMEM(OP,ADDR,REG)` with `INTEGER OP,ADDR,REG(6)`
- **Purpose**: Accesses Main Data (MD) memory, which stores floating-point data
- **Inputs/Outputs**: 
  - OP (0=zero, 1=read, 2=write)
  - ADDR (memory address)
  - REG (6 8-bit words of data)
- **AP-120B Operation**: Simulates access to MD memory that stores floating-point values organized as exponent, high mantissa, and low mantissa (3 words per 38-bit float: 1 sign bit + 9 exponent + 28 high mantissa + 28 low mantissa)

### TMMEM
- **Signature**: `SUBROUTINE TMMEM(OP,ADDR,REG)` with `INTEGER OP,ADDR,REG(6)`
- **Purpose**: Accesses Table Memory (TM), which stores lookup tables (FFT, function coefficients, and TMRAM)
- **Inputs/Outputs**: 
  - OP (0=zero, 1=read, 2=write)
  - ADDR (memory address)
  - REG (6 8-bit words of data)
- **AP-120B Operation**: Simulates access to TM memory that contains lookup tables organized as exponent, high mantissa, and low mantissa (3 words per 38-bit entry)

## 2. Bit-level semantics

### PSMEM
- The P.S. memory is organized as `PS(512,4)`, where each 32-bit word contains 4 quarter-words
- Each quarter-word is 8 bits, representing a portion of the program status
- Memory access operates on quarter-word increments (8-bit chunks)
- The `PSSIZE` parameter determines the actual size of the P.S. memory

### MDMEM
- The MD memory is organized as `MD(512,3)`, where each floating-point value takes 3 words:
  * Word 1: Exponent (9 bits in a 32-bit word)
  * Word 2: High mantissa (28 bits in a 32-bit word)
  * Word 3: Low mantissa (28 bits in a 32-bit word)
- Page number extraction: `I = MOD(TEMP(6),16)` (bits 0-3 of 'MAE' register)
- Address translation: `J = I * PAGSIZ + ADDR`
- Each MD entry represents a 38-bit AP-120B float: 1 sign bit + 9 exponent + 56-bit mantissa (split across two words)

### TMMEM
- The TM memory is organized as `TM(512,3)`, where each table entry takes 3 words:
  * Word 1: Exponent (9 bits in a 32-bit word)
  * Word 2: High mantissa (28 bits in a 32-bit word)
  * Word 3: Low mantissa (28 bits in a 32-bit word)
- Address mapping:
  * FFT table: physical address 0 → array index 0
  * Function coefficients: physical address 2048 → array index SFFTSZ
  * TMRAM: physical address 4096 → array index SFFTSZ + TRIGSZ
- Each TM entry represents a 38 AP-120B float: 1 sign bit + 9 exponent + 56-bit mantissa
- Special FPS100 TMSPEC register at address 177777 (octal) is handled separately

## 3. State and side effects

### PSMEM
- Reads from `/PSRM/` common block: `PS` (512x4 array) and `PSSIZE`
- Writes to `/PSRM/`: `PS` array when zeroing or writing
- Side effects:
  * Zeroing (`OP=0`) clears all quarter-words in P.S. memory
  * Reading (`OP=1`) returns 8 quarter-words starting from ADDR
  * Writing (`OP=2`) stores 8 quarter-words starting at ADDR

### MDMEM
- Reads from `/MDRM/` common block: `MD` (512x3 array), `PAGNUM`, `PAGSIZ`
- Reads from `/IORM/` common block: `IODEV`, `IOSIZE`
- Writes to `/MDRM/`: `MD` array when zeroing or writing
- Side effects:
  * Zeroing (`OP=0`) clears all words in MD memory
  * Reading/writing uses address translation based on page number from 'MAE'
  * Out-of-range reads return zero values

### TMMEM
- Reads from `/TMRM/` common block: `TM` (512x3 array), `RAMSIZ`, `TRIGSZ`, `HFFTSZ`, `SFFTSZ`, `RAMBAS`
- Reads from `/IORM/` common block: `EXTRA`, `TMSPEC`
- Writes to `/TMRM/`: `TM` array when zeroing TMRAM or writing to TMRAM
- Writes to `/IORM/`: `TMSPEC` array when writing to special FPS100 register
- Side effects:
  * Zeroing (`OP=0`) only affects TMRAM region, preserving ROM tables
  * Reading/writing is region-specific with different address mappings
  * Writes are only allowed to TMRAM region (ADDR >= RAMBAS)
  * Special handling for FPS100 TMSPEC register at address 177777

## 4. AP-120B-specific edge cases

### PSMEM
- No explicit out-of-range checking implemented in this routine

### MDMEM
- Address range checking: If `I` (page number) >= `PAGNUM` or `ADDR` >= `PAGSIZ`, address is out of range
- For out-of-range reads (`OP=1`), returns zero values in all 6 words of REG
- For out-of-range writes (`OP≠1`), simply returns without performing the write operation
- Page number extracted from 'MAE' register as `MOD(TEMP(6),16)` indicates the page selector

### TMMEM
- Region-specific access with three distinct memory areas:
  * FFT table (0-SFFTSZ-1)
  * Function coefficients (HFFTSZ to HFFTSZ+TRIGSZ-1)
  * TMRAM (4096 to 4096+RAMSIZ-1)
- Writes are only permitted to TMRAM region (ADDR >= RAMBAS)
- Special handling for FPS100 TMSPEC register at address 177777 (octal)
- For addresses in the "hole" (2349-4095) or out of range, if `OP=1` (read), returns zero values
- Zeroing operation only clears TMRAM, preserving ROM tables (FFT and coefficients)

## 5. Cross-references

### PSMEM
- Calls `MREAD` when `OP=1` (read operation)
- Calls `MWRIT` when `OP=2` (write operation)

### MDMEM
- Calls `MREAD` when `OP=1` (read operation) and when getting the 'MAE' (Memory Address Extension) register
- Calls `MWRIT` when `OP=2` (write operation)
- Calls `UNPKRG` when extracting page number from 'MAE'

### TMMEM
- Calls `MREAD` when `OP=1` (read operation)
- Calls `MWRIT` when `OP=2` (write operation to TMRAM)
- Calls `UNPKRG` when checking for special FPS100 TMSPEC register address
- Calls `RMOV` for reading/writing the special TMSPEC register when OP=1 or OP=2 and address is 177777


---

## Cluster: `fp_arith` (lines 2747-3215)

**FP adder, FP multiplier, FP I/O conversions**

### DeepSeek final

(adv 87s, 17949c)

## Critique of Peer Analysis

The peer analysis has several significant errors and omissions:

1. **Incorrect subroutine signatures**: FPADD's parameters are mischaracterized - FADDF and FADD1F are not "operation codes from control unit" but rather the actual AP-120B FALU operation code fields from the microinstruction.

2. **Missing AP-120B architectural detail**: The analysis fails to identify that these routines simulate the **FPS-100's FALU** (Floating-Point Arithmetic Logic Unit) which is a **38-bit** unit (not 36-bit as implied). The 38-bit format is 1 sign + 9 exponent + 28 mantissa.

3. **Incorrect bit-width analysis**: The analysis says "28 mantissa bits" but doesn't explain that the AP-120B actually uses a **28-bit mantissa with hidden bit** (normalized to 0.5 ≤ |mantissa| < 1.0), making the effective precision 29 bits.

4. **Missing critical state**: The analysis doesn't identify that `NOCNT` and `TRUNC` are **AP-120B architectural state** controlling normalization and rounding behavior, not just local variables.

5. **Incorrect cross-reference analysis**: Claims "No direct COMMON block access" but these routines operate on AP-120B register state that is passed through COMMON blocks in the calling context.

6. **Missing edge cases**: Doesn't identify the **"bit bucket"** (KC variable) as simulating the AP-120B's **guard bits** for proper IEEE-like rounding.

7. **Incorrect FPMUL analysis**: The 4×4 byte multiplication is not "16 cross-products" but rather simulates the AP-120B's **byte-serial multiplier** which processes 8-bit chunks sequentially.

---

# SIM100.FTN Reference: FP Adder, FP Multiplier, FP I/O Conversions

## 1. Per-Subroutine Reference

### FPADD — FALU Add/Subtract/Logical Operations

**Signature:** `SUBROUTINE FPADD(A1,A2,A3,FADDF,FADD1F,VALUE)`

**Purpose:** Simulates the AP-120B FALU's 38-bit floating-point add, subtract, and logical operations. This is the core arithmetic unit that handles both floating-point and integer/logical operations through the same datapath.

**Inputs:**
- `A1(6)`, `A2(6)`: 6-byte AP-120B floating-point operands (representing DPX/DPY register contents)
- `FADDF`: FALU operation code (0-6) from microinstruction FADDF field:
  - 0: Single-op instruction (use FADD1F)
  - 1: Subtract A2 from A1 (A1 - A2)
  - 2: Subtract A1 from A2 (A2 - A1)
  - 3: Equivalence (A1 EQV A2)
  - 4: AND (A1 AND A2)
  - 5: OR (A1 OR A2)
- `FADD1F`: Single-op subcode (0-6) when FADDF=0:
  - 0: Fix (rounded)
  - 1: Fix (truncated)
  - 2: Scale (truncated)
  - 3: Scale (rounded)
  - 4: Signed magnitude to 2's complement
  - 5: 2's complement to signed magnitude
  - 6: Absolute value
- `VALUE(2)`: Scale value for SCALE operations (2 bytes)

**Outputs:**
- `A3(7)`: 6-byte result + 1 byte status/error flags

**AP-120B Operation:** FPADD simulates the FALU's 38-bit datapath. The FALU takes two 38-bit operands from the A1/A2 multiplexer inputs, performs exponent comparison, mantissa alignment (up to 32-bit shift), the specified ALU operation, then normalization and rounding. The 7th byte of A3 accumulates error/status bits as in the hardware's MD register.

### FPINPT — Host-to-AP-120B Float Conversion

**Signature:** `SUBROUTINE FPINPT(DECIN,REG)`

**Purpose:** Converts a FORTRAN double-precision number to AP-120B 38-bit floating-point format.

**Inputs:**
- `DECIN`: FORTRAN DOUBLE PRECISION input value

**Outputs:**
- `REG(6)`: 6-byte AP-120B format result

**AP-120B Operation:** FPINPT simulates the AP-120B's input conversion hardware. It normalizes the value to the range [0.5, 1.0), extracts 28 mantissa bits (with hidden bit), applies exponent bias of 512, and converts from signed-magnitude to 2's complement representation.

### FPMUL — Floating-Point Multiply

**Signature:** `SUBROUTINE FPMUL(M1,M2,M3)`

**Purpose:** Simulates the AP-120B's floating-point multiplier unit.

**Inputs:**
- `M1(6)`, `M2(6)`: 6-byte AP-120B floating-point operands

**Outputs:**
- `M3(7)`: 6-byte result + 1 byte status/error flags

**AP-120B Operation:** FPMUL simulates the AP-120B's byte-serial multiplier. It multiplies two 28-bit mantissas using a 4×4 byte product algorithm (simulating the hardware's 8-bit multiplier slices), adds exponents with bias adjustment, and performs limited normalization (2 bits maximum). The "bit bucket" (IBUKET) collects bits shifted beyond the 28-bit mantissa for rounding.

### FPOUT — AP-120B-to-Host Float Conversion

**Signature:** `SUBROUTINE FPOUT(REG,DEC,MAXEX,IOV)`

**Purpose:** Converts AP-120B 38-bit format to FORTRAN double-precision.

**Inputs:**
- `REG(6)`: 6-byte AP-120B format input
- `MAXEX`: Maximum allowed exponent (for overflow detection)

**Outputs:**
- `DEC`: FORTRAN DOUBLE PRECISION result
- `IOV`: Overflow flag (1 if exponent exceeds MAXEX)

**AP-120B Operation:** FPOUT simulates the AP-120B's output conversion hardware. It extracts the biased exponent and 28-bit mantissa, removes bias (512), handles sign conversion from 2's complement to signed-magnitude, and reconstructs the floating-point value.

---

## 2. Bit-Level Semantics

### AP-120B 38-bit Float Format

The AP-120B uses a 38-bit floating-point format stored in 6 bytes:
- **Byte 1-2**: 9-bit biased exponent (bias=512) in bytes 1-2
- **Byte 3-6**: 28-bit mantissa in 2's complement, normalized to [0.5, 1.0)

The format is: `[EXP_HI(1)][EXP_LO(1)][MANT_28(4)]` where parentheses show byte counts.

### FPADD Bit Operations

**Line 26-27:** `CALL MOVPRT(A1,3,MA,1,6,4,4)`
- Extracts bytes 3-6 from A1 (the 28-bit mantissa) into MA(4)
- The `4,4` parameters indicate 4-byte source/destination fields
- This simulates the FALU's mantissa extraction from the 6-byte register format

**Line 30:** `EA=A1(1)*256+A1(2)`
- Combines two bytes into 9-bit exponent value
- `*256` is a left-shift by 8 bits, forming the 9-bit exponent (bits 0-8 of the 16-bit word pair)
- The 9th bit comes from A1(1) bit 0 (value 0-255, but only bit 0 is significant for the 9th exponent bit)

**Line 39:** `CALL LSHFT(MA,-1,4,1,K,K)`
- Right-shifts mantissa by 1 bit with sign extension (parameter 1 = arithmetic shift)
- Creates guard bit for overflow detection during addition
- The `-1` shift count means right shift by 1
- This simulates the FALU's pre-addition shift to accommodate carry-out

**Line 77:** `CALL LSHFT(MB,DELTA,4,1,K,KC)`
- Aligns mantissa MB by shifting right by |DELTA| positions
- `KC` captures the OR of all bits shifted out (the "bit bucket")
- This simulates the FALU's barrel shifter for mantissa alignment, limited to 32-bit shifts (line 70 check)

**Lines 79-80:** `IF (MOD(MB(4),2).EQ.0.AND.KC.EQ.1) MB(4)=MB(4)+KC`
- Implements **round-to-nearest-even** (IEEE round-half-to-even)
- If LSB is 0 and any bits were shifted out, add 1 to LSB
- This simulates the AP-120B's guard-bit rounding logic

### FPMUL Bit Operations

**Lines 105-106:** `CALL MOVPRT(M1,3,MA,1,6,4,4)`
- Same mantissa extraction as FPADD
- Extracts bytes 3-6 (28-bit mantissa) from 6-byte format

**Lines 107-108:** `CALL LSHFT(MA,4,4,0,K,K)`
- Left-shift by 4 bits to align mantissa to left byte boundary
- The `0` parameter means logical shift (no sign extension)
- This simulates the multiplier's mantissa normalization before multiplication

**Line 112:** `EC=M1(1)*256+M1(2)+M2(1)*256+M2(2)-512+1`
- Adds exponents and subtracts bias (512)
- The `+1` accounts for the pre-multiplication left-shift of mantissas
- This simulates the hardware's exponent adder

**Lines 135-136:** `MAL=MOD(MA(I),64)` and `MAH=MOD(MA(I)/64,4)`
- Splits each 8-bit byte into 6-bit low part and 2-bit high part
- This prevents byte product overflow in 16-bit arithmetic (simulating the AP-120B's 8×8 multiplier with 16-bit result)
- The 6+2 split ensures products fit in 16 bits (6×6=12 bits, plus cross terms)

**Lines 145, 149:** `CALL TCADD(MHP,MC,MC,8,K)` and `CALL TCADD(MLP,MC,MC,8,K)`
- Adds high and low partial products into accumulator
- This simulates the multiplier's partial product accumulation over 4×4=16 cycles

**Lines 144-145:** `IF (MOD(MC(4),2).EQ.0.AND.IBUKET.EQ.1) MC(4)=MC(4)+IBUKET`
- Same round-to-nearest-even as FPADD
- IBUKET collects OR of bytes 5-8 (bits beyond 28-bit mantissa)

### FPINPT/FPOUT Bit Operations

**FPINPT Line 47:** `IEXP=512`
- Initial exponent with bias 512 (AP-120B exponent bias)
- This is the AP-120B's characteristic bias value

**FPINPT Lines 51, 57:** `DEC=DEC/2.0D0` / `DEC=DEC*2.0D0`
- Normalizes to range [0.5, 1.0)
- This simulates the AP-120B's mantissa normalization hardware

**FPINPT Lines 60-62:** `DEC=DEC*256.0D0` / `IDEC=IDINT(DEC)` / `MANT(I)=IDEC`
- Extracts 8 mantissa bytes by repeated multiply-by-256
- This simulates the AP-120B's mantissa extraction in 8-bit chunks

**FPINPT Line 76:** `CALL LSHFT(MANT,-1,8,0,K,K)`
- Right-shifts 8-byte mantissa by 1 bit
- Creates space for sign bit in 2's complement representation
- This simulates the AP-120B's signed-magnitude to 2's complement conversion

**FPOUT Lines 56-57:** `CALL LSHFT(MANT,4,4,0,K,K)` then `CALL LSHFT(MANT,-1,4,1,K,K)`
- Left-shift 4 to left-justify, then right-shift 1 with sign extension
- The right-shift avoids the -(-1.0) problem (most negative 2's complement number)
- This simulates the AP-120B's output conversion hardware

**FPOUT Lines 63-66:** `DBLE(FLOAT(MANT(4)))/2147483648.0D0 + ...`
- Constructs double-precision value by interpreting mantissa bytes as fractions
- Each byte is divided by its positional weight (128, 32768, 8388608, 2147483648)
- This reconstructs the AP-120B's 28-bit fractional mantissa

---

## 3. State and Side Effects

### FPADD State

**Reads:**
- `A1(6)`, `A2(6)`: Input operands (simulating DPX/DPY register contents)
- `FADDF`, `FADD1F`: Operation codes from microinstruction fields
- `VALUE(2)`: Scale value for SCALE operations

**Writes:**
- `A3(7)`: Result (simulating MD register)
  - `A3(1-6)`: 6-byte floating-point result
  - `A3(7)`: Status byte (error/overflow flags)
- `MA(4)`, `MB(4)`, `MC(4)`: Internal working registers (simulating FALU's A1, A2, A3 registers)
- `EA`, `EB`, `EC`: Exponent values (simulating FALU's exponent registers)
- `DELTA`: Exponent difference (simulating FALU's alignment shifter control)
- `TRUNC`: Truncation flag (0=round, 1=truncate)
- `NOCNT`: Normalization count (40=full normalize, 0=no normalize, 2=limited)
- `ISM`: Sign-magnitude flag (0=2's complement, 1=signed magnitude)

**AP-120B Architectural State Represented:**
- `NOCNT` and `TRUNC` simulate the FALU's **normalization control** and **rounding mode** bits
- `ISM` simulates the **sign-magnitude mode** bit in the FALU's status register
- `KC` simulates the **guard bit register** (captures bits shifted out during alignment)

### FPMUL State

**Reads:**
- `M1(6)`, `M2(6)`: Input operands (simulating DPX/DPY register contents)

**Writes:**
- `M3(7)`: Result (simulating MD register)
- `MA(4)`, `MB(4)`: Mantissa working registers
- `MC(8)`: 8-byte product accumulator (56-bit intermediate result)
- `MHP(8)`, `MLP(8)`: High/low partial product registers
- `EC`: Exponent result
- `ISA`, `ISB`, `ISC`: Sign flags (+1 or -1)
- `IBUKET`: Bit bucket for rounding

**AP-120B Architectural State Represented:**
- `MC(8)` simulates the **56-bit product register** in the multiplier
- `MHP`/`MLP` simulate the **high/low byte registers** in the byte-serial multiplier
- `ISA`/`ISB` simulate the **sign detection logic** in the multiplier

### FPINPT/FPOUT State

**FPINPT Reads:**
- `DECIN`: Input value

**FPINPT Writes:**
- `REG(6)`: Output register
- `MANT(8)`: 8-byte mantissa working buffer
- `IEXP`: Biased exponent
- `ISG`: Sign flag (0=positive, 1=negative)
- `IBUKET`: Bit bucket for rounding

**FPOUT Reads:**
- `REG(6)`: Input register
- `MAXEX`: Maximum exponent limit

**FPOUT Writes:**
- `DEC`: Output value
- `IOV`: Overflow flag
- `MANT(4)`: Mantissa working buffer
- `IEX`: Unbiased exponent
- `ISG`: Sign flag

---

## 4. AP-120B-Specific Edge Cases

### 38-bit Float Format

The AP-120B uses a unique 38-bit format:
- **1 sign bit**: Bit 7 of byte 3 (extracted as `MOD(MANT(1)/128,2)`)
- **9 exponent bits**: Bytes 1-2 with bias 512 (range 0-1023, representing exponents -512 to +511)
- **28 mantissa bits**: Bytes 3-6, 2's complement, normalized to [0.5, 1.0)

The hidden bit is implicit: normalized mantissa always has bit 27 = 1 (value ≥ 0.5).

### FPADD Edge Cases

**Exponent difference > 32 (lines 70-73):**
```
IF (DELTA.GE.-32) GO TO 250
MB(1)=0
MB(2)=0
MB(3)=0
MB(4)=0
```
- When exponent difference exceeds 32, the smaller operand is forced to zero
- This simulates the AP-120B's **32-bit barrel shifter limit** — shifts beyond 32 bits are treated as zero

**Signed magnitude conversions (lines 10400-10500):**
```
10400 IF (MOD(MC(1)/128,2).EQ.0) GO TO 1000
MC(1)=MOD(MC(1),64)
CALL NEGATE(MC,4,K)
```
- `MOD(MC(1),64)` clears the top 2 bits (sign and guard bits)
- This simulates the AP-120B's **signed-magnitude mode** where the sign bit is separate from the mantissa

**Inhibited normalization (line 10150):**
```
10150 NOCNT=0
```
- For FIX and SCALE operations, normalization is inhibited
- This simulates the AP-120B's **normalization inhibit** control bit

**Scale value encoding (lines 10600-10610):**
```
ISCALE=MOD(VALUE(1),4)*256+VALUE(2)
I=512
IF (ISCALE.GE.512) I=-I
ISCALE=ISCALE+I-1
```
- Scale value is encoded in 10 bits (2 bytes from VALUE)
- Values ≥ 512 are negative (2's complement)
- The `-1` adjustment accounts for the pre-addition shift

### FPMUL Edge Cases

**Limited normalization (line 153):**
```
CALL NORMAL(EC,MA,M3,0,2)
```
- The `2` parameter limits normalization to 2 bits maximum
- This simulates the AP-120B's **multiplier normalization** which only handles the case where the product is in [0.25, 0.5) range

**Byte-serial multiplication (lines 123-148):**
```
DO 250 I=1,4
  DO 220 J=1,4
    K=I+J
    MAL=MOD(MA(I),64)
    MAH=MOD(MA(I)/64,4)
    MBL=MOD(MB(J),64)
    MBH=MOD(MB(J)/64,4)
    IPL=MAL*MBL+(MAL*MBH+MAH*MBL)*64
    IPH=MAH*MBH*16
```
- The 6+2 bit split prevents overflow in 16-bit arithmetic
- `IPL` and `IPH` are 16-bit partial products
- This simulates the AP-120B's **8-bit multiplier slices** that process 8-bit chunks sequentially

**Sign handling (lines 119-128):**
```
ISA=1
IF (MA(1).LT.128) GO TO 100
CALL NEGATE(MA,4,K)
ISA=-1
```
- Mantissas are converted to absolute value before multiplication
- Sign is computed separately as product of input signs
- This simulates the AP-120B's **sign-magnitude multiplication** where the multiplier operates on absolute values

### FPINPT/FPOUT Edge Cases

**Zero detection (FPINPT lines 10-15, FPOUT lines 48-53):**
```
IF (DEC.NE.0.0D0) GO TO 100
DO 10 J=1,6
10 REG(J)=0
RETURN
```
- Zero is represented as all 6 bytes = 0
- This matches the AP-120B's **zero representation** (exponent=0, mantissa=0)

**Overflow detection (FPOUT lines 62-64):**
```
IF (IABS(IEX).GE.MAXEX) GO TO 300
IOV=1
```
- Checks if exponent exceeds MAXEX
- This simulates the AP-120B's **exponent overflow detection**

**Special shift for -(-1.0) problem (FPOUT lines 56-57):**
```
CALL LSHFT(MANT,4,4,0,K,K)
CALL LSHFT(MANT,-1,4,1,K,K)
```
- Left-shift 4 then right-shift 1 with sign extension
- This avoids the case where the most negative 2's complement number (-1.0 in AP-120B format) cannot be negated
- The AP-120B's 2's complement representation has no positive counterpart for -1.0

---

## 5. Cross-References

### FPADD Calls

| Routine | Line(s) | Purpose |
|---------|---------|---------|
| `MOVPRT` | 26-27 | Extract 4-byte mantissa from 6-byte input operands |
| `LSHFT` | 28-29, 39-40, 77, 10120, 10350 | Mantissa alignment, overflow guard, scale shifts |
| `NEGATE` | 38, 41, 10400, 10500, 10700 | 2's complement negation for subtraction and sign conversion |
| `RMOV` | 44, 50, 52 | Register move for exponent comparison swap |
| `TCADD` | 68 | Two's complement addition of mantissas |
| `LCOM` | 69, 71, 73, 75 | Logical complement for EQV/AND/OR operations |
| `LAND` | 70, 72, 74 | Logical AND for EQV/AND/OR operations |
| `NORMAL` | 103 | Final normalization, rounding, and error checking |

### FPINPT Calls

| Routine | Line(s) | Purpose |
|---------|---------|---------|
| `LSHFT` | 76 | Right-shift mantissa for sign bit space |
| `NEGATE` | 77 | 2's complement negation for negative numbers |
| `MOVPRT` | 78 | Extract 4-byte mantissa from 8-byte working buffer |
| `NORMAL` | 79 | Normalize converted result |

### FPMUL Calls

| Routine | Line(s) | Purpose |
|---------|---------|---------|
| `MOVPRT` | 105-106 | Extract 4-byte mantissas from 6-byte inputs |
| `LSHFT` | 107-108 | Left-shift 4 bits for mantissa alignment |
| `NEGATE` | 120, 127 | Convert mantissas to absolute value |
| `TCADD` | 145, 149 | Add partial products into accumulator |
| `MOVPRT` | 152 | Extract 4-byte result from 8-byte product |
| `NORMAL` | 153 | Limited normalization (2 bits max) |

### FPOUT Calls

| Routine | Line(s) | Purpose |
|---------|---------|---------|
| `MOVPRT` | 52 | Extract 4-byte mantissa from 6-byte input |
| `LSHFT` | 56-57 | Left-justify then right-shift for sign handling |
| `NEGATE` | 68 | Convert negative mantissas to positive |

### Routines Called by This Section (Defined Elsewhere)

- **`MOVPRT`**: Memory-to-memory block move with byte alignment (defined in utility section)
- **`LSHFT`**: Multi-word shift with sign extension and bit-bucket capture (defined in utility section)
- **`NEGATE`**: Two's complement negation of multi-word array (defined in utility section)
- **`RMOV`**: Register-to-register block move (defined in utility section)
- **`TCADD`**: Two's complement addition of multi-word arrays (defined in utility section)
- **`LCOM`**: Logical complement (bitwise NOT) of multi-word array (defined in utility section)
- **`LAND`**: Logical AND of two multi-word arrays (defined in utility section)
- **`NORMAL`**: Normalize floating-point result, round, check for errors, set condition bits (defined in normalization section)

### GLM final

(adv 130s, 11108c)

# Analysis of SIM100.FTN FP Arithmetic Section

## 1. Per-Subroutine Reference

### SUBROUTINE FPADD(A1,A2,A3,FADDF,FADD1F,VALUE)

**Signature:**
```fortran
SUBROUTINE FPADD(A1,A2,A3,FADDF,FADD1F,VALUE)
INTEGER A1(6),A2(6),A3(7),FADDF,FADD1F,VALUE(2)
```

**Purpose:** Simulates the AP-120B FALU (Floating-Point ALU) add/subtract/logical operations. Takes two 6-byte AP-120B floating-point operands and produces a 7-byte result (6 bytes mantissa+exponent + 1 byte error/status).

**Inputs/Outputs:**
- **A1(6), A2(6):** Input operands in AP-120B 38-bit format (1 sign + 9 exponent + 28 mantissa, stored as 6 bytes)
- **A3(7):** Output result (6 bytes data + 1 byte error/status)
- **FADDF:** Primary operation code (0=no-op/single-op, 1=subtract A1, 2=subtract A2, 3=add, 4=equivalence, 5=AND, 6=OR)
- **FADD1F:** Secondary operation code for single-op instructions (1=FIX rounded, 2=FIX truncated, 3=SCALE truncated, 4=sign-mag to 2's complement, 5=2's complement to sign-mag, 6=SCALE rounded, 7=absolute value)
- **VALUE(2):** Scale value for SCALE operations (lines 10300-10600)

**AP-120B Operation Simulated:** FPADD simulates the FALU's full arithmetic/logic unit. The FADDF field maps directly to the AP-120B's FADDF microinstruction field (3 bits in the FPS-7319 SPLIT recipe). The FADD1F field maps to the FADD1F field for single-operand operations. The hardware FALU operates on 38-bit floating-point numbers with a 28-bit mantissa and 9-bit exponent biased by 512.

### SUBROUTINE FPINPT(DECIN,REG)

**Signature:**
```fortran
SUBROUTINE FPINPT(DECIN,REG)
DOUBLE PRECISION DEC,DECIN
INTEGER REG(6),MANT(8),WRK(7),MC(4)
```

**Purpose:** Converts a host FORTRAN double-precision number to AP-120B internal 38-bit floating-point format.

**Inputs/Outputs:**
- **DECIN:** Input double-precision number
- **REG(6):** Output in AP-120B 6-byte format

**AP-120B Operation Simulated:** This is a debugger utility, not a direct hardware simulation. It performs the inverse of the AP-120B's internal number representation, converting from IEEE-like format to the AP-120B's 1+9+28 bit signed-magnitude format with 512 bias.

### SUBROUTINE FPMUL(M1,M2,M3)

**Signature:**
```fortran
SUBROUTINE FPMUL(M1,M2,M3)
INTEGER M1(6),M2(6),M3(7)
INTEGER MA(4),MB(4),MC(8),MHP(8),MLP(8),EC
```

**Purpose:** Simulates the AP-120B floating-point multiplier. Multiplies two 6-byte AP-120B numbers and produces a 7-byte result.

**Inputs/Outputs:**
- **M1(6), M2(6):** Input operands
- **M3(7):** Output product (6 bytes data + 1 byte error/status)

**AP-120B Operation Simulated:** FPMUL simulates the AP-120B's floating-point multiplier unit. The multiplier uses a byte-by-byte multiplication algorithm (lines 200-250) that mimics the hardware's 16-bit mini-multipliers. The hardware multiplies 28-bit mantissas by decomposing into 4 bytes of 7 bits each (after sign removal), computing 16 cross-products.

### SUBROUTINE FPOUT(REG,DEC,MAXEX,IOV)

**Signature:**
```fortran
SUBROUTINE FPOUT(REG,DEC,MAXEX,IOV)
INTEGER REG(6),MANT(4)
DOUBLE PRECISION DEC
```

**Purpose:** Converts AP-120B 38-bit floating-point format back to host FORTRAN double-precision.

**Inputs/Outputs:**
- **REG(6):** Input AP-120B number
- **DEC:** Output double-precision number
- **MAXEX:** Maximum exponent before overflow
- **IOV:** Overflow flag (1 if exponent exceeds MAXEX)

**AP-120B Operation Simulated:** Debugger utility for reverse conversion. Handles the AP-120B's signed-magnitude representation and 512 exponent bias.

## 2. Bit-Level Semantics

### Mantissa Representation (MA, MB, MC arrays)

The AP-120B 38-bit float is stored as 6 bytes:
- **Bytes 1-2:** Exponent (9 bits + 7 unused bits in byte 2)
- **Bytes 3-6:** Mantissa (28 bits, signed magnitude)

When extracted via MOVPRT into 4-byte arrays (MA, MB, MC), the mantissa is left-justified with 4 guard bits at the right:

```fortran
CALL MOVPRT(A1,3,MA,1,6,4,4)  ! Extract bytes 3-6 into MA(1-4)
CALL LSHFT(MA,4,4,0,K,K)      ! Shift left 4 bits to create guard bits
```

**Lines 15-16:** The left shift by 4 creates 4 guard bits in the least significant portion of MA(4). This is critical for the AP-120B's rounding logic.

### Exponent Encoding

```fortran
EA=A1(1)*256+A1(2)  ! Line 17
```

The exponent is stored as a 9-bit value in bytes 1-2, biased by 512 (decimal). The multiplication by 256 extracts the high byte, and A1(2) adds the low byte.

### Sign Bit Handling

The AP-120B uses signed-magnitude format. The sign bit is in bit 7 of the mantissa's most significant byte:

```fortran
IF (MOD(MC(1)/128,2).EQ.0) GO TO 1000  ! Line 10400 - check sign bit
```

### Guard Bit and Rounding

The code maintains guard bits through the LSB of MC(4):

```fortran
IF (MOD(MC(4),2).EQ.0.AND.KC.EQ.1) MC(4)=MC(4)+KC  ! Line 260
```

This implements the AP-120B's "round-to-nearest" with "round-to-even" tie-breaking. The variable KC captures bits shifted off the right end during alignment.

### Byte Product Decomposition (FPMUL)

```fortran
MAL=MOD(MA(I),64)        ! Low 6 bits of byte
MAH=MOD(MA(I)/64,4)      ! High 2 bits of byte
MBL=MOD(MB(J),64)        ! Low 6 bits of byte
MBH=MOD(MB(J)/64,4)      ! High 2 bits of byte
IPL=MAL*MBL+(MAL*MBH+MAH*MBL)*64  ! Partial product
IPH=MAH*MBH*16           ! High product
```

This decomposes each 8-bit byte into 6+2 bits to avoid 16-bit overflow in the host's integer arithmetic. The hardware actually has 16-bit mini-multipliers; this decomposition simulates that with 8-bit host arithmetic.

## 3. State and Side Effects

### COMMON Block Variables

This section does **not** directly reference any COMMON blocks. All state is passed through subroutine arguments. However, the routines call utility functions that may access COMMON:

- **MOVPRT** - Moves partial words between arrays (likely accesses COMMON for bit manipulation)
- **LSHFT** - Logical shift operations (may access COMMON for shift count)
- **NEGATE** - Two's complement negation
- **TCADD** - Two's complement addition
- **NORMAL** - Normalization and rounding (critical for AP-120B state)
- **LAND, LCOM, RMOV** - Logical operations and move

### AP-120B Architectural State Represented

| Variable | AP-120B State | Description |
|----------|---------------|-------------|
| A1(6), A2(6) | DPX, DPY | Data pad registers (6-byte floating-point) |
| A3(7) | Result register | FALU output with error byte |
| MA(4), MB(4), MC(4) | Internal mantissa registers | 4-byte working mantissa |
| EA, EB, EC | Exponent registers | 9-bit biased exponents |
| FADDF | FADDF field | 3-bit ALU operation code |
| FADD1F | FADD1F field | 3-bit single-op code |
| TRUNC | Truncation mode | Controls rounding vs. truncation |
| NOCNT | Normalization count | Max shifts for normalization |
| ISM | Sign-magnitude flag | Remember sign for 2's comp conversion |
| IBUKET | Bit bucket | OR of all bits shifted beyond guard |

### NORMAL Subroutine Side Effects

The NORMAL subroutine (called at lines 1000, 10150, 10300) is critical for:
- Normalizing the mantissa (shifting left until MSB=1)
- Rounding based on guard bits
- Setting exponent overflow/underflow
- Setting condition codes (APSTAT)

## 4. AP-120B-Specific Edge Cases

### 38-bit Float Format

The AP-120B uses a unique 38-bit format:
- **Bit 37:** Sign (1 bit)
- **Bits 36-28:** Exponent (9 bits, biased by 512)
- **Bits 27-0:** Mantissa (28 bits, signed magnitude)

This appears throughout:
- **Line 17:** `EA=A1(1)*256+A1(2)` extracts 9-bit exponent
- **Line 100:** `MA(1).LT.128` checks sign bit (bit 7 of byte 1)
- **Line 10400:** `MOD(MC(1)/128,2)` checks sign bit

### Exponent Bias of 512

```fortran
EC=M1(1)*256+M1(2)+M2(1)*256+M2(2)-512+1  ! In FPMUL
```

The bias is 512 (2^9), giving an exponent range of approximately 10^-154 to 10^154.

### Signed Magnitude vs. Two's Complement

The AP-120B stores mantissas in signed-magnitude format but performs arithmetic in two's complement:

```fortran
! FPADD line 10400 - Convert sign-mag to 2's comp
IF (MOD(MC(1)/128,2).EQ.0) GO TO 1000
MC(1)=MOD(MC(1),64)  ! Clear sign bit and guard bits
CALL NEGATE(MC,4,K)  ! Negate to get 2's complement
```

```fortran
! FPADD line 10500 - Convert 2's comp to sign-mag
IF (MOD(MC(1)/128,2).EQ.0) GO TO 1000
CALL NEGATE(MC,4,K)  ! Make positive
ISM=1                 ! Remember to set sign bit after normalization
```

### Guard Bits and Rounding

The AP-120B has 4 guard bits (created by the initial 4-bit left shift) plus a "bit bucket" that accumulates all bits shifted beyond the guard:

```fortran
! Line 250-260 - Alignment shift with bit bucket
CALL LSHFT(MB,DELTA,4,1,K,KC)  ! KC catches shifted-off bits
IF (MOD(MB(4),2).EQ.0.AND.KC.EQ.1) MB(4)=MB(4)+KC  ! Round-to-even
```

### Special Case: Exponent Difference > 32

```fortran
! Line 200-250
IF (DELTA.GE.-32) GO TO 250
MB(1)=0
MB(2)=0
MB(3)=0
MB(4)=0
```

If the exponent difference exceeds 32, the smaller operand is treated as zero. This matches the AP-120B's 32-bit alignment shifter limit.

### Single-Operation Instructions

The FADD1F field handles special operations that don't combine two operands:

- **FIX (10100, 10200):** Convert to integer with truncation or rounding
- **SCALE (10300, 10600):** Scale by specified amount
- **Sign-mag conversion (10400, 10500):** Convert between representations
- **Absolute value (10700):** Force positive

### Overflow Detection

```fortran
! FPOUT line 300
IF (IABS(IEX).GE.MAXEX) GO TO 300
IOV=1
```

The MAXEX parameter allows the caller to set the overflow threshold. This simulates the AP-120B's exponent overflow/underflow detection.

## 5. Cross-References

### Called from this section:

| Call | Location | Purpose |
|------|----------|---------|
| `MOVPRT` | FPADD:15-16, FPMUL:15-16, FPOUT:15 | Extract/insert mantissa bytes from 6-byte format |
| `LSHFT` | FPADD:16, FPMUL:16, FPOUT:16 | Shift mantissa for alignment, normalization |
| `NEGATE` | FPADD:100, FPMUL:100-110 | Two's complement negation |
| `RMOV` | FPADD:200 | Register-to-register move |
| `TCADD` | FPADD:300, FPMUL:220-250 | Two's complement addition |
| `LAND` | FPADD:400-500 | Logical AND |
| `LCOM` | FPADD:400-600 | Logical complement (NOT) |
| `NORMAL` | FPADD:1000, FPMUL:300 | Normalize, round, check errors |

### Called by (likely from other clusters):

| Routine | Called From | Purpose |
|---------|-------------|---------|
| `FPADD` | Main simulation loop | FALU operations |
| `FPMUL` | Main simulation loop | Floating-point multiply |
| `FPINPT` | Debugger | Host-to-AP format conversion |
| `FPOUT` | Debugger | AP-to-host format conversion |

### Key Delegation Pattern

The `NORMAL` subroutine (not shown in this section) is the most critical delegation point. It handles:
1. Normalizing the mantissa (shifting left until MSB=1)
2. Rounding based on guard bits and TRUNC flag
3. Exponent adjustment
4. Setting condition codes (APSTAT)
5. Detecting overflow/underflow
6. Setting the error byte in A3(7)

Both FPADD and FPMUL delegate to NORMAL for final result formatting, which is why the AP-120B's condition codes and error flags are set consistently regardless of which ALU operation was performed.

### Cooperative drafts

#### DS coop

# Analysis of SIM100.FTN FP Arithmetic Section

## 1. Per-Subroutine Reference

### SUBROUTINE FPADD(A1,A2,A3,FADDF,FADD1F,VALUE)

**Signature:**
```fortran
SUBROUTINE FPADD(A1,A2,A3,FADDF,FADD1F,VALUE)
INTEGER A1(6),A2(6),A3(7),FADDF,FADD1F,VALUE(2)
```

**Purpose:** Simulates the AP-120B FALU (Floating-Point ALU) add/subtract/logical operations. Takes two 6-byte AP-120B floating-point operands and produces a 7-byte result (6 bytes mantissa+exponent + 1 byte error/status).

**Inputs/Outputs:**
- **A1(6), A2(6):** Input operands in AP-120B 38-bit format (1 sign + 9 exponent + 28 mantissa, stored as 6 bytes)
- **A3(7):** Output result (6 bytes data + 1 byte error/status)
- **FADDF:** Primary operation code (0=no-op/single-op, 1=subtract A1, 2=subtract A2, 3=add, 4=equivalence, 5=AND, 6=OR)
- **FADD1F:** Secondary operation code for single-op instructions (1=FIX rounded, 2=FIX truncated, 3=SCALE truncated, 4=sign-mag to 2's complement, 5=2's complement to sign-mag, 6=SCALE rounded, 7=absolute value)
- **VALUE(2):** Scale value for SCALE operations (lines 10300-10600)

**AP-120B Operation Simulated:** FPADD simulates the FALU's full arithmetic/logic unit. The FADDF field maps directly to the AP-120B's FADDF microinstruction field (3 bits in the FPS-7319 SPLIT recipe). The FADD1F field maps to the FADD1F field for single-operand operations. The hardware FALU operates on 38-bit floating-point numbers with a 28-bit mantissa and 9-bit exponent biased by 512.

### SUBROUTINE FPINPT(DECIN,REG)

**Signature:**
```fortran
SUBROUTINE FPINPT(DECIN,REG)
DOUBLE PRECISION DEC,DECIN
INTEGER REG(6),MANT(8),WRK(7),MC(4)
```

**Purpose:** Converts a host FORTRAN double-precision number to AP-120B internal 38-bit floating-point format.

**Inputs/Outputs:**
- **DECIN:** Input double-precision number
- **REG(6):** Output in AP-120B 6-byte format

**AP-120B Operation Simulated:** This is a debugger utility, not a direct hardware simulation. It performs the inverse of the AP-120B's internal number representation, converting from IEEE-like format to the AP-120B's 1+9+28 bit signed-magnitude format with 512 bias.

### SUBROUTINE FPMUL(M1,M2,M3)

**Signature:**
```fortran
SUBROUTINE FPMUL(M1,M2,M3)
INTEGER M1(6),M2(6),M3(7)
INTEGER MA(4),MB(4),MC(8),MHP(8),MLP(8),EC
```

**Purpose:** Simulates the AP-120B floating-point multiplier. Multiplies two 6-byte AP-120B numbers and produces a 7-byte result.

**Inputs/Outputs:**
- **M1(6), M2(6):** Input operands
- **M3(7):** Output product (6 bytes data + 1 byte error/status)

**AP-120B Operation Simulated:** FPMUL simulates the AP-120B's floating-point multiplier unit. The multiplier uses a byte-by-byte multiplication algorithm (lines 200-250) that mimics the hardware's 16-bit mini-multipliers. The hardware multiplies 28-bit mantissas by decomposing into 4 bytes of 7 bits each (after sign removal), computing 16 cross-products.

### SUBROUTINE FPOUT(REG,DEC,MAXEX,IOV)

**Signature:**
```fortran
SUBROUTINE FPOUT(REG,DEC,MAXEX,IOV)
INTEGER REG(6),MANT(4)
DOUBLE PRECISION DEC
```

**Purpose:** Converts AP-120B 38-bit floating-point format back to host FORTRAN double-precision.

**Inputs/Outputs:**
- **REG(6):** Input AP-120B number
- **DEC:** Output double-precision number
- **MAXEX:** Maximum exponent before overflow
- **IOV:** Overflow flag (1 if exponent exceeds MAXEX)

**AP-120B Operation Simulated:** Debugger utility for reverse conversion. Handles the AP-120B's signed-magnitude representation and 512 exponent bias.

## 2. Bit-Level Semantics

### Mantissa Representation (MA, MB, MC arrays)

The AP-120B 38-bit float is stored as 6 bytes:
- **Bytes 1-2:** Exponent (9 bits + 7 unused bits in byte 2)
- **Bytes 3-6:** Mantissa (28 bits, signed magnitude)

When extracted via MOVPRT into 4-byte arrays (MA, MB, MC), the mantissa is left-justified with 4 guard bits at the right:

```fortran
CALL MOVPRT(A1,3,MA,1,6,4,4)  ! Extract bytes 3-6 into MA(1-4)
CALL LSHFT(MA,4,4,0,K,K)      ! Shift left 4 bits to create guard bits
```

**Line 15-16:** The left shift by 4 creates 4 guard bits in the least significant portion of MA(4). This is critical for the AP-120B's rounding logic.

### Exponent Encoding

```fortran
EA=A1(1)*256+A1(2)  ! Line 17
```

The exponent is stored as a 9-bit value in bytes 1-2, biased by 512 (decimal). The multiplication by 256 extracts the high byte, and A1(2) adds the low byte.

### Sign Bit Handling

The AP-120B uses signed-magnitude format. The sign bit is in bit 7 of the mantissa's most significant byte:

```fortran
IF (MOD(MC(1)/128,2).EQ.0) GO TO 1000  ! Line 10400 - check sign bit
```

### Guard Bit and Rounding

The code maintains guard bits through the LSB of MC(4):

```fortran
IF (MOD(MC(4),2).EQ.0.AND.KC.EQ.1) MC(4)=MC(4)+KC  ! Line 260
```

This implements the AP-120B's "round-to-nearest" with "round-to-even" tie-breaking. The variable KC captures bits shifted off the right end during alignment.

### Byte Product Decomposition (FPMUL)

```fortran
MAL=MOD(MA(I),64)        ! Low 6 bits of byte
MAH=MOD(MA(I)/64,4)      ! High 2 bits of byte
MBL=MOD(MB(J),64)        ! Low 6 bits of byte
MBH=MOD(MB(J)/64,4)      ! High 2 bits of byte
IPL=MAL*MBL+(MAL*MBH+MAH*MBL)*64  ! Partial product
IPH=MAH*MBH*16           ! High product
```

This decomposes each 8-bit byte into 6+2 bits to avoid 16-bit overflow in the host's integer arithmetic. The hardware actually has 16-bit mini-multipliers; this decomposition simulates that with 8-bit host arithmetic.

## 3. State and Side Effects

### COMMON Block Variables

This section does **not** directly reference any COMMON blocks. All state is passed through subroutine arguments. However, the routines call utility functions that may access COMMON:

- **MOVPRT** - Moves partial words between arrays (likely accesses COMMON for bit manipulation)
- **LSHFT** - Logical shift operations (may access COMMON for shift count)
- **NEGATE** - Two's complement negation
- **TCADD** - Two's complement addition
- **NORMAL** - Normalization and rounding (critical for AP-120B state)
- **LAND, LCOM, RMOV** - Logical operations and move

### AP-120B Architectural State Represented

| Variable | AP-120B State | Description |
|----------|---------------|-------------|
| A1(6), A2(6) | DPX, DPY | Data pad registers (6-byte floating-point) |
| A3(7) | Result register | FALU output with error byte |
| MA(4), MB(4), MC(4) | Internal mantissa registers | 4-byte working mantissa |
| EA, EB, EC | Exponent registers | 9-bit biased exponents |
| FADDF | FADDF field | 3-bit ALU operation code |
| FADD1F | FADD1F field | 3-bit single-op code |
| TRUNC | Truncation mode | Controls rounding vs. truncation |
| NOCNT | Normalization count | Max shifts for normalization |
| ISM | Sign-magnitude flag | Remember sign for 2's comp conversion |
| IBUKET | Bit bucket | OR of all bits shifted beyond guard |

### NORMAL Subroutine Side Effects

The NORMAL subroutine (called at lines 1000, 10150, 10300) is critical for:
- Normalizing the mantissa (shifting left until MSB=1)
- Rounding based on guard bits
- Setting exponent overflow/underflow
- Setting condition codes (APSTAT)

## 4. AP-120B-Specific Edge Cases

### 38-bit Float Format

The AP-120B uses a unique 38-bit format:
- **Bit 37:** Sign (1 bit)
- **Bits 36-28:** Exponent (9 bits, biased by 512)
- **Bits 27-0:** Mantissa (28 bits, signed magnitude)

This appears throughout:
- **Line 17:** `EA=A1(1)*256+A1(2)` extracts 9-bit exponent
- **Line 100:** `MA(1).LT.128` checks sign bit (bit 7 of byte 1)
- **Line 10400:** `MOD(MC(1)/128,2)` checks sign bit

### Exponent Bias of 512

```fortran
EC=M1(1)*256+M1(2)+M2(1)*256+M2(2)-512+1  ! Line in FPMUL
```

The bias is 512 (2^9), giving an exponent range of approximately 10^-154 to 10^154.

### Signed Magnitude vs. Two's Complement

The AP-120B stores mantissas in signed-magnitude format but performs arithmetic in two's complement:

```fortran
! FPADD line 10400 - Convert sign-mag to 2's comp
IF (MOD(MC(1)/128,2).EQ.0) GO TO 1000
MC(1)=MOD(MC(1),64)  ! Clear sign bit and guard bits
CALL NEGATE(MC,4,K)  ! Negate to get 2's complement
```

```fortran
! FPADD line 10500 - Convert 2's comp to sign-mag
IF (MOD(MC(1)/128,2).EQ.0) GO TO 1000
CALL NEGATE(MC,4,K)  ! Make positive
ISM=1                 ! Remember to set sign bit after normalization
```

### Guard Bits and Rounding

The AP-120B has 4 guard bits (created by the initial 4-bit left shift) plus a "bit bucket" that accumulates all bits shifted beyond the guard:

```fortran
! Line 250-260 - Alignment shift with bit bucket
CALL LSHFT(MB,DELTA,4,1,K,KC)  ! KC catches shifted-off bits
IF (MOD(MB(4),2).EQ.0.AND.KC.EQ.1) MB(4)=MB(4)+KC  ! Round-to-even
```

### Special Case: Exponent Difference > 32

```fortran
! Line 200-250
IF (DELTA.GE.-32) GO TO 250
MB(1)=0
MB(2)=0
MB(3)=0
MB(4)=0
```

If the exponent difference exceeds 32, the smaller operand is treated as zero. This matches the AP-120B's 32-bit alignment shifter limit.

### Single-Operation Instructions

The FADD1F field handles special operations that don't combine two operands:

- **FIX (10100, 10200):** Convert to integer with truncation or rounding
- **SCALE (10300, 10600):** Scale by specified amount
- **Sign-mag conversion (10400, 10500):** Convert between representations
- **Absolute value (10700):** Force positive

### Overflow Detection

```fortran
! FPOUT line 300
IF (IABS(IEX).GE.MAXEX) GO TO 300
IOV=1
```

The MAXEX parameter allows the caller to set the overflow threshold. This simulates the AP-120B's exponent overflow/underflow detection.

## 5. Cross-References

### Called from this section:

| Call | Location | Purpose |
|------|----------|---------|
| `MOVPRT` | FPADD:15-16, FPMUL:15-16, FPOUT:15 | Extract/insert mantissa bytes from 6-byte format |
| `LSHFT` | FPADD:16, FPMUL:16, FPOUT:16 | Shift mantissa for alignment, normalization |
| `NEGATE` | FPADD:100, FPMUL:100-110 | Two's complement negation |
| `RMOV` | FPADD:200 | Register-to-register move |
| `TCADD` | FPADD:300, FPMUL:220-250 | Two's complement addition |
| `LAND` | FPADD:400-500 | Logical AND |
| `LCOM` | FPADD:400-600 | Logical complement (NOT) |
| `NORMAL` | FPADD:1000, FPMUL:300 | Normalize, round, check errors |

### Called by (likely from other clusters):

| Routine | Called From | Purpose |
|---------|-------------|---------|
| `FPADD` | Main simulation loop | FALU operations |
| `FPMUL` | Main simulation loop | Floating-point multiply |
| `FPINPT` | Debugger | Host-to-AP format conversion |
| `FPOUT` | Debugger | AP-to-host format conversion |

### Key Delegation Pattern

The `NORMAL` subroutine (not shown in this section) is the most critical delegation point. It handles:
1. Normalizing the mantissa (shifting left until MSB=1)
2. Rounding based on guard bits and TRUNC flag
3. Exponent adjustment
4. Setting condition codes (APSTAT)
5. Detecting overflow/underflow
6. Setting the error byte in A3(7)

Both FPADD and FPMUL delegate to NORMAL for final result formatting, which is why the AP-120B's condition codes and error flags are set consistently regardless of which ALU operation was performed.

#### GLM coop

# SIM100.FTN Analysis: FP adder, FP multiplier, FP I/O conversions

## 1. Per-subroutine reference

### FPADD
**Signature:** `SUBROUTINE FPADD(A1,A2,A3,FADDF,FADD1F,VALUE)`
**Purpose:** Simulates AP-120B FALU's floating-point add, subtract, and logical operations.
**Inputs/Outputs:** 
- A1,A2: 6-byte input operands (DPX, DPY registers)
- A3: 7-byte output result (6 bytes data + 1 byte status)
- FADDF: Add operation code (0=add,1=sub A2,2=sub A1,3=equivalence,4=AND,5=OR)
- FADD1F: Single operation code (scale, fix, conversions, abs)
- VALUE: Scaling value
**AP-120B Operation:** FPADD simulates the 38-bit FALU arithmetic operations; takes A1,A2 from dual-input multiplexer, handles mantissa alignment and overflow, returns normalized A3 result with error bits.

### FPINPT
**Signature:** `SUBROUTINE FPINPT(DECIN,REG)`
**Purpose:** Converts FORTRAN double-precision to AP-120B internal format.
**Inputs/Outputs:**
- DECIN: FORTRAN double-precision input
- REG: 6-byte AP-120B format output
**AP-120B Operation:** FPINPT simulates the input conversion hardware; normalizes input, extracts 28 mantissa bits, applies bias of 512, handles sign conversion.

### FPMUL
**Signature:** `SUBROUTINE FPMUL(M1,M2,M3)`
**Purpose:** Simulates AP-120B floating-point multiply operation.
**Inputs/Outputs:**
- M1,M2: 6-byte input operands (DPX, DPY registers)
- M3: 7-byte output result (6 bytes data + 1 byte status)
**AP-120B Operation:** FPMUL simulates FP multiplier hardware; multiplies 28-bit mantissas producing 56-bit result, adds exponents with bias handling, limited normalization, and "bit bucket" rounding.

### FPOUT
**Signature:** `SUBROUTINE FPOUT(REG,DEC,MAXEX,IOV)`
**Purpose:** Converts AP-120B format to FORTRAN double-precision.
**Inputs/Outputs:**
- REG: 6-byte AP-120B input format
- DEC: FORTRAN double-precision output
- MAXEX: Maximum exponent limit
- IOV: Overflow indicator
**AP-120B Operation:** FPOUT simulates output conversion hardware; extracts exponent and mantissa, removes bias, handles overflow checking, and constructs double-precision value.

## 2. Bit-level semantics

### FPADD
- `CALL MOVPRT(A1,3,MA,1,6,4,4)` (lines 26-27): Extracts 4-byte mantissa from words 3-6 of A1, representing 28 bits of mantissa data.
- `EA=A1(1)*256+A1(2)` (line 30): Combines two exponent bytes into 9-bit value, using bias 512.
- `CALL LSHFT(MA,-1,4,1,K,K)` (line 39): Right shift mantissa by 1, creating guard bit position for overflow detection in ALU operation.
- `CALL LSHFT(MB,DELTA,4,1,K,KC)` (line 77): Aligns mantissa based on exponent difference, KC captures shifted-out bits for rounding.
- `IF (MOD(MB(4),2).EQ.0.AND.KC.EQ.1) MB(4)=MB(4)+KC` (lines 79-80): Implements rounding when least significant bit is 0 and bits were shifted out.

### FPMUL
- `MAL=MOD(MA(I),64)` and `MAH=MOD(MA(I)/64,4)` (lines 135-136): Splits 8-bit mantissa bytes into 6-bit low and 2-bit high components to prevent overflow in byte multiplication.
- `EC=M1(1)*256+M1(2)+M2(1)*256+M2(2)-512+1` (line 112): Adds 9-bit exponents and subtracts bias (512) + 1 for mantissa positioning.
- `DO 250 I=1,4`...`DO 220 J=1,4` (lines 123-148): Implements 16 cross-products for 4×4 mantissa multiplication, producing 56-bit intermediate result.
- `IF (MOD(MC(4),2).EQ.0.AND.IBUKET.EQ.1) MC(4)=MC(4)+IBUKET` (lines 144-145): "Bit bucket" rounding, combining overflow bits with LSB if LSB was 0.

### FPINPT/FPOUT
- `IEXP=512` (FPINPT line 47): Initial exponent with bias 512.
- `DEC=DEC/2.0D0` / `DEC=DEC*2.0D0` (FPINPT lines 51/57): Normalization to 0.5 ≤ |x| < 1.0 range.
- `IEX=REG(1)*256+REG(2)-512+1` (FPOUT line 59): Converts exponent from biased (512) to unbiased form.
- `DBLE(FLOAT(MANT(4)))/2147483648.0D0+...` (FPOUT lines 63-66): Constructs double-precision value by interpreting mantissa bytes as fractions.

## 3. State and side effects

### COMMON blocks accessed:
- No direct COMMON block access in these routines.

### AP-120B architectural state:
- **FPADD:**
  - Reads: A1,A2 (input operands from DPX/DPY registers)
  - Writes: A3 (result to MD register)
  - FADDF,FADD1F (operation codes from control unit)
  - TRUNC (rounding control)
  - NOCNT (normalization control)

- **FPMUL:**
  - Reads: M1,M2 (input operands from DPX/DPY registers)
  - Writes: M3 (result to MD register)
  - EC (exponent result)
  - ISB,ISA (sign tracking)

- **FPINPT/FPOUT:**
  - No AP-120B state access - these are conversion routines between AP-120B and host formats.

## 4. AP-120B-specific edge cases

### FPADD
- **Exponent difference > 32** (lines 70-73): Forces MB to zero rather than attempting alignment beyond hardware capability.
- **Signed magnitude conversions** (lines 10600,10500): Special handling for signed magnitude ↔ 2's complement conversions in single-op instructions.
- **Inhibited normalization** (line 10150): Sets NOCNT=0 for FIX/SCALE instructions, preventing normalization.
- **Overflow handling**: A3(7) accumulates error/status bits.

### FPMUL
- **Limited normalization** (line 153): Calls NORMAL with limit=2 for multiplication results, reflecting hardware constraints.
- **56-bit intermediate** (lines 136-148): Special 4×4 byte multiplication algorithm to handle full 56-bit mantissa product.
- **Sign handling** (lines 119-128): Extracts and preserves sign separately before multiplication.

### FPINPT/FPOUT
- **Zero detection** (FPINPT lines 10-15, FPOUT lines 48-53): Special zero handling with direct return.
- **Overflow detection** (FPOUT lines 62-64): Checks |exponent| ≥ MAXEX and sets IOV=1.
- **Special shift** (FPOUT lines 56-57): LSHFT(-1) to avoid -(-1.0) problems in conversion.

### 38-bit float format throughout:
- 1 sign bit: Extracted with MOD(MANT(1)/128,2)
- 9 exponent bits: Formed as two bytes with bias 512
- 28 mantissa bits: Stored as 4-byte aligned mantissa

## 5. Cross-references

### FPADD calls:
- **MOVPRT** (lines 26-27): Used to extract mantissa from input operands.
- **LSHFT** (multiple lines): Used for mantissa alignment and overflow prevention.
- **NEGATE** (lines 38,41): Used for subtraction operations.
- **RMOV** (lines 44,50,52): Used for register swapping during exponent comparison.
- **TCADD** (line 68): Core add operation.
- **LCOM/LAND** (lines 69-75): Logical operations for equivalence, AND, OR.
- **NORMAL** (line 103): Final normalization and error checking.

### FPINPT calls:
- **LSHFT** (line 76): Mantissa shifting after sign conversion.
- **NEGATE** (line 77): Sign handling in conversion.
- **MOVPRT** (line 78): Extract mantissa for normalization.
- **NORMAL** (line 79): Normalize converted result.

### FPMUL calls:
- **MOVPRT** (lines 105-106): Extract mantissas from inputs.
- **LSHFT** (lines 107-108): Left shift for alignment.
- **NEGATE** (lines 120,127): Sign handling.
- **TCADD** (lines 145,149): Addition of partial products.

### FPOUT calls:
- **MOVPRT** (line 52): Extract mantissa from input.
- **LSHFT** (lines 56-57): Special shift operations.
- **NEGATE** (line 68): Sign handling.


---

## Cluster: `codec_logic` (lines 3216-3602)

**INCODE, LAND, LCOM, LSHFT, MOVPRT, MREAD, MWRIT**

### DeepSeek final

(adv 79s, 16367c)

Looking at the GLM analysis, I find several significant issues that need correction:

1. **INCODE field bit positions are incorrectly described** - The analysis claims specific bit positions (e.g., "D field: MSB of byte 1") but the actual code shows `MOD(OCT,2)*128` which places the bit in position 7 (0-indexed), not the MSB (position 7 is correct but the description is imprecise about what "MSB" means in context)

2. **Missing AP-120B architectural context** - The analysis fails to connect these routines to the actual FPS-100 hardware they simulate. For example, MREAD/MWRIT are clearly simulating the FPS-100's 16-bit main memory, but the analysis doesn't explain why 16-bit words are relevant to a 38-bit floating-point machine

3. **Incorrect characterization of LSHFT** - The analysis says "modifies REGA in-place" but misses the critical detail that this is how the FPS-100's barrel shifter works - shifting through a register and capturing the shifted-out bits

4. **Missing the 38-bit float connection** - The analysis completely ignores that these routines operate on byte arrays that represent 38-bit floating-point values in the FPS-100

5. **Incorrect state representation claims** - The analysis says "None of these routines directly interact with COMMON-block variables" but doesn't explain how they *indirectly* interact through the calling context

Here is my corrected analysis:

---

# Analysis of SIM100.FTN Section: `codec_logic`

## 1. Per-Subroutine Reference

### INCODE
- **Signature**: `SUBROUTINE INCODE(OCT, IDX, REG)`
- **Purpose**: Encode an octal value into a specific field of a 64-bit microinstruction word stored as 8 bytes (64 bits total)
- **Inputs/Outputs**:
  - `OCT`: Octal value to encode (integer, 0-7 typically, but up to 63 for SPS field)
  - `IDX`: Field selector (1-24, plus aliases 25-40 for some fields)
  - `REG(8)`: 8-byte array representing the 64-bit microinstruction (modified in-place)
- **AP-120B operation**: Simulates encoding of a microinstruction field into the 64-bit control store word. The FPS-100 has a 64-bit microinstruction format with 24 fields (the canonical SPLIT recipe). Each field occupies specific bit positions within the 64-bit word. The code uses `MOD` and integer division to extract and insert bits at exact positions within the byte array representation.

**Field encoding details (from computed GOTO targets):**

| IDX | Field | Bits | Encoding Logic |
|-----|-------|------|----------------|
| 1 | D | 1 | `REG(1)=MOD(OCT,2)*128+MOD(REG(1),128)` — bit 7 of byte 1 |
| 2 | SOP | 3 | `REG(1)=MOD(OCT,8)*16+(REG(1)/128)*128+MOD(REG(1),16)` — bits 4-6 of byte 1 |
| 3 | SH | 2 | `REG(1)=MOD(OCT,4)*4+(REG(1)/16)*16+MOD(REG(1),4)` — bits 2-3 of byte 1 |
| 4 | SPS | 6 | Split across bytes: `REG(1)=MOD(OCT/4,4)+(REG(1)/4)*4` (bits 0-1 of byte 1) and `REG(2)=MOD(OCT,4)*64+MOD(REG(2),64)` (bits 6-7 of byte 2) |
| 5 | SPD | 4 | `REG(2)=MOD(OCT,16)*4+(REG(2)/64)*64+MOD(REG(2),4)` — bits 2-5 of byte 2 |
| 6 | FADD | 5 | Split: `REG(2)=MOD(OCT/2,4)+(REG(2)/4)*4` (bits 0-1 of byte 2) and `REG(3)=MOD(OCT,2)*128+MOD(REG(3),128)` (bit 7 of byte 3) |
| 7 | A1 | 3 | `REG(3)=MOD(OCT,8)*16+(REG(3)/128)*128+MOD(REG(3),16)` — bits 4-6 of byte 3 |
| 8 | A2 | 3 | `REG(3)=MOD(OCT,8)*2+(REG(3)/16)*16+MOD(REG(3),2)` — bits 1-3 of byte 3 |
| 9 | COND | 5 | Split: `REG(3)=MOD(OCT/8,2)+(REG(3)/2)*2` (bit 0 of byte 3) and `REG(4)=MOD(OCT,8)*32+MOD(REG(4),32)` (bits 5-7 of byte 4) |
| 10 | DISP | 5 | `REG(4)=MOD(OCT,32)+(REG(4)/32)*32` — bits 0-4 of byte 4 |
| 11 | DPX | 2 | `REG(5)=MOD(OCT,4)*64+MOD(REG(5),64)` — bits 6-7 of byte 5 |
| 12 | DPY | 2 | `REG(5)=MOD(OCT,4)*16+(REG(5)/64)*64+MOD(REG(5),16)` — bits 4-5 of byte 5 |
| 13 | DPBS | 3 | `REG(5)=MOD(OCT,8)*2+(REG(5)/16)*16+MOD(REG(5),2)` — bits 1-3 of byte 5 |
| 14 | XR | 3 | Split: `REG(5)=MOD(OCT/4,2)+(REG(5)/2)*2` (bit 0 of byte 5) and `REG(6)=MOD(OCT,4)*64+MOD(REG(6),64)` (bits 6-7 of byte 6) |
| 15 | YR | 3 | `REG(6)=MOD(OCT,8)*8+(REG(6)/64)*64+MOD(REG(6),8)` — bits 3-5 of byte 6 |
| 16 | XW | 3 | `REG(6)=MOD(OCT,8)+(REG(6)/8)*8` — bits 0-2 of byte 6 |
| 17 | YW | 3 | `REG(7)=MOD(OCT,8)*32+MOD(REG(7),32)` — bits 5-7 of byte 7 |
| 18 | FM | 1 | `REG(7)=MOD(OCT,2)*16+(REG(7)/32)*32+MOD(REG(7),16)` — bit 4 of byte 7 |
| 19 | M1 | 2 | `REG(7)=MOD(OCT,4)*4+(REG(7)/16)*16+MOD(REG(7),4)` — bits 2-3 of byte 7 |
| 20 | M2 | 2 | `REG(7)=MOD(OCT,4)+(REG(7)/4)*4` — bits 0-1 of byte 7 |
| 21 | MI | 2 | `REG(8)=MOD(OCT,4)*64+MOD(REG(8),64)` — bits 6-7 of byte 8 |
| 22 | MA | 2 | `REG(8)=MOD(OCT,4)*16+(REG(8)/64)*64+MOD(REG(8),16)` — bits 4-5 of byte 8 |
| 23 | DPA | 2 | `REG(8)=MOD(OCT,4)*4+(REG(8)/16)*16+MOD(REG(8),4)` — bits 2-3 of byte 8 |
| 24 | TMA | 2 | `REG(8)=MOD(OCT,4)+(REG(8)/4)*4` — bits 0-1 of byte 8 |

Note: IDX values 25-40 map to fields 4,4,5,5,5,5,5,5,5,27,7,8,8,8,8,8,8 — these are aliases for the same fields (SPS, SPD, SH, A1, A2) used by the assembler.

### LAND
- **Signature**: `SUBROUTINE LAND(REGA, REGB, REGC, W)`
- **Purpose**: Bitwise logical AND of two byte arrays
- **Inputs/Outputs**:
  - `REGA(W)`: First operand (input)
  - `REGB(W)`: Second operand (input)
  - `REGC(W)`: Result (output)
  - `W`: Width in bytes
- **AP-120B operation**: Simulates the FPS-100's bitwise AND operation, used in the logical unit for masking operations. The FPS-100 has a 38-bit datapath, so W would typically be 5 bytes (40 bits, with 2 unused bits) or 8 bytes (64 bits for double-precision). The code processes each byte individually, then each bit within the byte using `MOD(KA,2)` to extract bits and `KC=KC/2` to shift the result.

### LCOM
- **Signature**: `SUBROUTINE LCOM(REGA, REGB, W)`
- **Purpose**: Bitwise logical complement (NOT) of a byte array
- **Inputs/Outputs**:
  - `REGA(W)`: Input operand
  - `REGB(W)`: Result (output)
  - `W`: Width in bytes
- **AP-120B operation**: Simulates the FPS-100's bitwise NOT operation. Used for generating one's complement in arithmetic operations. The code inverts each bit: `IF (MOD(KA,2).EQ.0) KB=KB+128` — if the input bit is 0, set the output bit to 1.

### LSHFT
- **Signature**: `SUBROUTINE LSHFT(REGA, COUNT, W, SIGNED, CARRY, BUCKET)`
- **Purpose**: Logical or arithmetic shift of a byte array
- **Inputs/Outputs**:
  - `REGA(W)`: Register to shift (modified in-place)
  - `COUNT`: Shift amount (positive=left, negative=right, 0=no-op)
  - `W`: Width in bytes
  - `SIGNED`: 0=logical shift, 1=arithmetic shift (preserves sign bit)
  - `CARRY`: Bit shifted out (output)
  - `BUCKET`: OR of all bits shifted into CARRY (output)
- **AP-120B operation**: Simulates the FPS-100's barrel shifter. The FPS-100 has a 38-bit shifter that can shift left or right by any amount. This routine implements the shift as a series of single-bit shifts (DO 50 K=1,ICNT). For left shifts, it propagates the MSB of each byte to the LSB of the next byte. For right shifts, it propagates the LSB of each byte to the MSB of the previous byte. The `BUCKET` parameter accumulates the OR of all bits shifted out, which the FPS-100 uses for overflow detection.

**Key detail**: The comment on line 149-150 documents a PDP-11 RT-11 FORTRAN compiler bug: `IS=REGA(1)/2+IS` must be a separate assignment because the compiler incorrectly optimizes `REGA(1)=REGA(1)/2+IS` by omitting the `/2`.

### MOVPRT
- **Signature**: `SUBROUTINE MOVPRT(SRC, S1, DST, D1, SW, DW, N)`
- **Purpose**: Copy N bytes from source register to destination register at specified offsets
- **Inputs/Outputs**:
  - `SRC(SW)`: Source register
  - `S1`: Starting byte index in source (1-based)
  - `DST(DW)`: Destination register (modified)
  - `D1`: Starting byte index in destination (1-based)
  - `SW`: Source width in bytes
  - `DW`: Destination width in bytes
  - `N`: Number of bytes to copy
- **AP-120B operation**: Simulates partial register transfers in the FPS-100. The FPS-100 can move data between registers of different widths (e.g., 38-bit floating-point to 16-bit integer). This routine handles the byte-level transfer without any format conversion — it's a raw byte copy.

### MREAD
- **Signature**: `SUBROUTINE MREAD(MEM, MA, REG, MSIZE, MW, RW)`
- **Purpose**: Read a memory location into a register
- **Inputs/Outputs**:
  - `MEM(MSIZE,MW)`: Memory array (input)
  - `MA`: Memory address (0-based, converted to 1-based internally as `MAR=MA+1`)
  - `REG(RW)`: Output register (output)
  - `MSIZE`: Number of memory locations
  - `MW`: Words per memory location (typically 2 for 38-bit values stored as two 16-bit words)
  - `RW`: Register width in bytes
- **AP-120B operation**: Simulates reading from the FPS-100's main memory. The FPS-100 memory is organized as 16-bit words (to conserve space on the PDP-11 host). A 38-bit floating-point value occupies 2 memory words (32 bits + 6 bits in a third word, or packed as 2 words with 10 unused bits). The code handles sign extension: if a 16-bit word is negative (`ITMP.GE.0` check fails), it sets the sign bit in the register and converts to positive magnitude (`ITMP=ITMP+32767+1`). On out-of-range access, returns zero-filled register.

### MWRIT
- **Signature**: `SUBROUTINE MWRIT(REG, MEM, MA, MSIZE, RW, MW)`
- **Purpose**: Write a register to a memory location
- **Inputs/Outputs**:
  - `REG(RW)`: Source register (input)
  - `MEM(MSIZE,MW)`: Memory array (modified)
  - `MA`: Memory address (0-based)
  - `MSIZE`: Number of memory locations
  - `RW`: Register width in bytes
  - `MW`: Words per memory location
- **AP-120B operation**: Simulates writing to the FPS-100's main memory. Converts register bytes back to 16-bit words, handling sign extension in reverse. The code checks the sign bit of the left byte (`INF=MOD(REG(J)/128,2)`) and adjusts the 16-bit value accordingly (`IF (INF.EQ.1) ITMP=ITMP-32767-1`). On out-of-range address, silently returns without writing.

## 2. Bit-Level Semantics

### Byte Array Representation
All routines operate on byte arrays where each byte is an integer 0-255. This represents the FPS-100's internal data paths, which are 38 bits wide for single-precision floating-point and 64 bits wide for microinstructions. The byte array is a PDP-11 representation of these wider values.

### INCODE Bit Manipulation
The code uses a consistent pattern for field insertion:
- `MOD(OCT, 2^N)` extracts the low N bits of the octal value
- Multiplication by a power of 2 shifts the value to the correct bit position
- `MOD(REG(I), M)` preserves bits outside the field being modified
- Integer division clears bits in the field being replaced

For example, the D field (IDX=1): `REG(1)=MOD(OCT,2)*128+MOD(REG(1),128)` — takes the low bit of OCT, shifts it left 7 positions (×128), and ORs it with the low 7 bits of REG(1) (preserved by `MOD(REG(1),128)`).

### LAND Bit Operations
The inner loop (lines 50-100) processes bits from LSB to MSB:
- `KC=KC/2` shifts the accumulated result right by 1 bit
- `IF (MOD(KA,2)+MOD(KB,2).EQ.2) KC=KC+128` — if both bits are 1, set the MSB of KC
- `KA=KA/2` and `KB=KB/2` shift the input bits right

This is a bit-serial AND operation, processing 8 bits per byte. The result is built from MSB to LSB (because `KC=KC/2` shifts right, and `KC=KC+128` sets the MSB).

### LCOM Bit Operations
Same bit-serial approach as LAND:
- `KB=KB/2` shifts result right
- `IF (MOD(KA,2).EQ.0) KB=KB+128` — if input bit is 0, set output bit to 1
- `KA=KA/2` shifts input right

### LSHFT Shift Mechanics
**Left shift** (COUNT > 0):
- `CARRY=MOD(REGA(1)/128,2)` — captures MSB of first byte
- `REGA(I)=MOD(REGA(I)*2+MOD(REGA(I+1)/128,2),256)` — shifts byte left by 1, brings in MSB of next byte as LSB
- `REGA(W)=MOD(REGA(W)*2,256)` — shifts last byte left, zero-fills LSB

**Right shift** (COUNT < 0):
- `CARRY=MOD(REGA(W),2)` — captures LSB of last byte
- `REGA(J)=REGA(J)/2+MOD(REGA(J-1),2)*128` — shifts byte right by 1, brings in LSB of previous byte as MSB
- For arithmetic shift: `IS=MOD(REGA(1)/128,2)*128` — preserves sign bit by replicating it

### MREAD/MWRIT 16-bit Conversion
The FPS-100's 38-bit floating-point format is stored in PDP-11 memory as 16-bit words. The conversion:
- **Read**: `ITMP=MEM(MAR,I)` gets 16-bit word. If negative (`ITMP.GE.0` fails), set `INF=1` and convert to positive. Then `REG(J)=ITMP/256+INF*128` — high byte with sign bit, `REG(J+1)=MOD(ITMP,256)` — low byte.
- **Write**: `INF=MOD(REG(J)/128,2)` gets sign bit. `ITMP=MOD(REG(J),128)*256+REG(J+1)` combines bytes. If sign set, `ITMP=ITMP-32767-1` converts to negative 16-bit.

## 3. State and Side Effects

### COMMON Block Variables
None of these routines directly reference COMMON blocks. They operate on parameters passed by the caller. However, they are called by higher-level routines that do access COMMON:

- **INCODE**: Called by the assembler/disassembler to modify microinstruction words in the control store (COMMON variable `CSTOR` or similar)
- **LAND, LCOM, LSHFT**: Called by arithmetic/logic unit simulation routines that operate on S-Pad registers, DPX, DPY, MD, TM, etc.
- **MOVPRT**: Called for register-to-register transfers between different width registers (e.g., 38-bit to 16-bit)
- **MREAD, MWRIT**: Called to access main memory (COMMON variable `MEM` or similar)

### Architectural State Represented
- **REG arrays**: Represent FPS-100 registers of various widths:
  - 8 bytes = 64-bit microinstruction word
  - 5 bytes = 40-bit (38-bit floating-point + 2 unused bits)
  - 2 bytes = 16-bit integer
  - 1 byte = 8-bit field
- **MEM array**: Represents FPS-100 main memory, organized as 16-bit words
- **CARRY, BUCKET**: Represent shift unit status outputs

## 4. AP-120B-Specific Edge Cases

### 38-bit Floating-Point Format
The FPS-100 uses a 38-bit floating-point format: 1 sign bit + 9 exponent bits + 28 mantissa bits. This is stored in memory as two 16-bit words (32 bits) plus 6 bits in a third word, or packed differently. The MREAD/MWRIT routines handle the 16-bit word conversion but do not directly manipulate the floating-point format — that is done by other routines (FPADD, FPMUL, etc.).

### Microinstruction Field Aliases
INCODE handles IDX values 25-40 as aliases for fields 4,4,5,5,5,5,5,5,5,27,7,8,8,8,8,8,8. This means:
- IDX 25-26 → SPS field (IDX 4)
- IDX 27-35 → SPD field (IDX 5)
- IDX 36 → SH field (IDX 3, but note: IDX 27 in the computed GOTO maps to target 27, which is SH)
- IDX 37 → A1 field (IDX 7)
- IDX 38-40 → A2 field (IDX 8)

This is a quirk of the assembler's field naming convention.

### Out-of-Range Memory Access
MREAD returns a zero-filled register on out-of-range access (lines 200-210). MWRIT silently ignores out-of-range writes. This matches the FPS-100's behavior where invalid memory addresses produce undefined results (simulated as zeros).

### Sign Extension in Memory Operations
The FPS-100 uses 16-bit integers in addition to 38-bit floats. MREAD/MWRIT handle sign extension for 16-bit values stored in PDP-11 memory. The comment "IN A 16-BIT MACHINE THE SIGN BIT OF THE LEFT BYTE MIGHT BE ON" (MWRIT line 97) acknowledges that the PDP-11 uses 16-bit two's complement integers.

### PDP-11 FORTRAN Compiler Bug
LSHFT contains a documented workaround for a PDP-11 RT-11 FORTRAN compiler bug (lines 149-150): `IS=REGA(1)/2+IS` must be a separate assignment because the compiler incorrectly optimizes the combined expression.

## 5. Cross-References

These routines are called by other SIM100 routines:

- **INCODE**: Called by the assembler (likely `ASSEM` or `ASM` routine) to encode microinstruction fields into control store words
- **LAND**: Called by logical operation simulation (likely `LOP` or `LOGIC` routine) for AND operations on S-Pad registers
- **LCOM**: Called by logical operation simulation for NOT operations
- **LSHFT**: Called by shift operation simulation (likely `SHIFT` or `ARSHFT` routine) for barrel shifter operations
- **MOVPRT**: Called by register transfer routines (likely `MOVER` or `XFER` routine) for partial-width moves
- **MREAD**: Called by memory fetch routines (likely `FETCH` or `LOAD` routine) to read from main memory
- **MWRIT**: Called by memory store routines (likely `STORE` or `SAVE` routine) to write to main memory

The specific calling routines are in other sections of SIM100.FTN not provided here. These utility routines form the low-level building blocks for the FPS-100 simulation, handling bit manipulation, data movement, and memory access at the byte/word level.

### GLM final

(adv 106s, 7717c)

# SIM100.FTN Codec/Logic Routines Analysis

## 1. Per-Subroutine Reference

### INCODE
**Signature:** `SUBROUTINE INCODE(OCT, IDX, REG)`
- **Inputs:** `OCT` (octal value to encode), `IDX` (field selector index 1-24), `REG(8)` (8-byte program source word)
- **Outputs:** `REG(8)` modified in-place
- **Purpose:** Encodes an octal value into a specific field of a 64-bit (8-byte) program source word
- **AP-120B Operation:** Simulates encoding of the 24-field microinstruction word according to the SIM100 SPLIT recipe. Each computed GOTO target corresponds to one field:
  - IDX 1: D field (1 bit at bit 7 of byte 1)
  - IDX 2: SOP field (3 bits at bits 4-6 of byte 1)
  - IDX 3: SH field (2 bits at bits 2-3 of byte 1)
  - ...continuing through all 24 fields including DPX, DPY, XW, YW, MI, MA, DPA, and TMA
- **Note:** IDX values 25-40 map to previous fields (4,4,5,5,5,5,5,5,5,27,7,8,8,8,8,8,8) indicating field aliasing

### LAND
**Signature:** `SUBROUTINE LAND(REGA, REGB, REGC, W)`
- **Inputs:** `REGA(W)`, `REGB(W)` (two byte arrays), `W` (width in bytes)
- **Outputs:** `REGC(W)` (result byte array)
- **Purpose:** Performs bitwise logical AND on two multi-byte registers
- **AP-120B Operation:** Simulates the bitwise AND operation in the AP-120B's ALU/logic unit. The byte-by-bit, bit-by-bit implementation (lines 50-100) processes each bit position from MSB to LSB

### LCOM
**Signature:** `SUBROUTINE LCOM(REGA, REGB, W)`
- **Inputs:** `REGA(W)` (source byte array), `W` (width in bytes)
- **Outputs:** `REGB(W)` (complemented result)
- **Purpose:** Performs bitwise logical complement (NOT) on a multi-byte register
- **AP-120B Operation:** Simulates the logical complement operation. The implementation sets bits in the result only when the corresponding source bit is 0 (`IF (MOD(KA,2).EQ.0) KB=KB+128`)

### LSHFT
**Signature:** `SUBROUTINE LSHFT(REGA, COUNT, W, SIGNED, CARRY, BUCKET)`
- **Inputs:** `REGA(W)` (register to shift), `COUNT` (shift amount), `W` (width), `SIGNED` (0=logical, 1=arithmetic)
- **Outputs:** `REGA(W)` modified, `CARRY` (last bit shifted out), `BUCKET` (OR of all bits shifted into carry)
- **Purpose:** Performs logical or arithmetic shift on a multi-byte register
- **AP-120B Operation:** Simulates barrel shifter operations. Key details:
  - Left shift: `CARRY=MOD(REGA(1)/128,2)` captures MSB (line ~40)
  - Right shift arithmetic: `IS=MOD(REGA(1)/128,2)*128` extends sign bit (line ~120)
  - `BUCKET` accumulates OR of all shifted-out bits (multi-bit overflow detection)
  - Line ~125 comment documents PDP-11 RT-11 FORTRAN compiler workaround

### MOVPRT
**Signature:** `SUBROUTINE MOVPRT(SRC, S1, DST, D1, SW, DW, N)`
- **Inputs:** `SRC(SW)`, `S1` (source start), `DST(DW)`, `D1` (dest start), `SW`, `DW`, `N` (bytes to move)
- **Outputs:** `DST(DW)` modified
- **Purpose:** Copies N bytes between registers at specified positions
- **AP-120B Operation:** Simulates partial register transfers used for microinstruction field extraction/insertion and register width conversion

### MREAD
**Signature:** `SUBROUTINE MREAD(MEM, MA, REG, MSIZE, MW, RW)`
- **Inputs:** `MEM(MSIZE,MW)` (memory array), `MA` (address), `MSIZE`, `MW` (width in words), `RW` (register width)
- **Outputs:** `REG(RW)` (fetched data)
- **Purpose:** Reads memory location and converts to byte array representation
- **AP-120B Operation:** Simulates memory read from AP-120B memories. Handles:
  - 16-bit signed storage with sign bit detection (`ITMP.GE.0` check)
  - Out-of-range returns zero (line 200)
  - Word-to-byte conversion with sign preservation

### MWRIT
**Signature:** `SUBROUTINE MWRIT(REG, MEM, MA, MSIZE, RW, MW)`
- **Inputs:** `REG(RW)` (source), `MEM(MSIZE,MW)`, `MA`, `MSIZE`, `RW`, `MW`
- **Outputs:** `MEM(MSIZE,MW)` modified
- **Purpose:** Writes register to memory, converting from bytes to 16-bit words
- **AP-120B Operation:** Simulates memory write with:
  - Silent fail on out-of-range addresses (line ~30)
  - Byte-to-word reconstruction with sign handling (`INF=MOD(REG(J)/128,2)`)

## 2. Bit-Level Semantics

### Byte Array Representation
All registers are stored as arrays of 8-bit bytes (0-255). The AP-120B's 38-bit floating-point format (1 sign + 9 exponent + 28 mantissa) is represented across multiple bytes.

### Field Encoding Bit Layout
The INCODE routine reveals precise field bit positions:

**Byte 1 (bits 7-0):**
- Bit 7: D field
- Bits 6-4: SOP field
- Bits 3-2: SH field
- Bits 1-0: SPS field (lower)

**Byte 2 (bits 7-0):**
- Bits 7-6: SPS field (upper)
- Bits 5-2: SPD field
- Bits 1-0: FADD field (lower)

**Byte 3 (bits 7-0):**
- Bit 7: FADD field (upper)
- Bits 6-4: A1 field
- Bits 3-1: A2 field
- Bit 0: COND field (lower)

**Byte 4 (bits 7-0):**
- Bits 7-5: COND field (upper)
- Bits 4-0: DISP field

**Byte 5 (bits 7-0):**
- Bits 7-6: DPX field
- Bits 5-4: DPY field
- Bits 3-1: DPBS field
- Bit 0: XR field (lower)

**Byte 6 (bits 7-0):**
- Bits 7-6: XR field (upper)
- Bits 5-3: YR field
- Bits 2-0: XW field

**Byte 7 (bits 7-0):**
- Bits 7-5: YW field
- Bit 4: FM field
- Bits 3-2: M1 field
- Bits 1-0: M2 field

**Byte 8 (bits 7-0):**
- Bits 7-6: MI field
- Bits 5-4: MA field
- Bits 3-2: DPA field
- Bits 1-0: TMA field

### Bit Manipulation Patterns
- `MOD(OCT, N)` extracts lowest N-valued bits
- `MOD(REG(N), M)` preserves bits below position M
- `(REG(N)/K)*K` clears bits below position K
- `MOD(REG(N)/K, 2)` extracts bit at position K

## 3. State and Side Effects

### COMMON Block Variables
These routines operate via parameters rather than direct COMMON access:

- **INCODE** modifies `REG(8)` — program source word from microinstruction memory
- **LAND/LCOM/LSHFT** operate on generic byte arrays — any AP-120B register (DPX, DPY, S-Pad, MD, TM)
- **MOVPRT** performs register-to-register transfers — field manipulation
- **MREAD/MWRIT** access `MEM(MSIZE,MW)` — main data memory, table memory, or program memory

### AP-120B Architectural State
- **Program Source Word (64-bit)**: Encapsulates 24 microinstruction fields
- **Memory Arrays**: Main data memory (MD), table memory (TM), program source array (PSA)
- **General Registers**: DPX, DPY, S-Pad locations, etc.

## 4. AP-120B-Specific Edge Cases

### 38-bit Float Format Support
- **MREAD/MWRIT**: Handle 16-bit word boundaries — a 38-bit float spans 3 words (48 bits) with 10 unused bits
- **LSHFT**: With `SIGNED=1`, preserves sign bit during right shifts for floating-point normalization

### Memory Addressing
- **MREAD**: Out-of-range reads return zero (simulating unmapped memory)
- **MWRIT**: Out-of-range writes silently fail

### 16-bit Word Storage
- **MREAD**: Handles PDP-11 16-bit signed integers with sign bit preservation via `INF` flag
- **MWRIT**: Reconstructs 16-bit words with sign correction: `ITMP=ITMP-32767-1`

### Shift Operations
- **LSHFT**: Includes workaround for PDP-11 RT-11 FORTRAN compiler bug (line ~125)
- **BUCKET parameter**: Detects overflow in multi-bit shifts by OR-ing all shifted-out bits

## 5. Cross-References

These "leaf" routines are called by higher-level SIM100 routines:

- **INCODE**: Called by microinstruction assemblers/disassemblers
- **LAND/LCOM**: Called by ALU simulation routines for logical operations
- **LSHFT**: Called by FPADD, FMF, etc., for normalization and alignment
- **MOVPRT**: Called by field extraction/insertion routines
- **MREAD/MWRIT**: Called by memory access routines for different memory types

**Delegation Pattern**:
- FPADD would call LSHFT for normalization and LAND/LCOM for sign/mantissa manipulation
- FMF (floating multiply) would use LSHFT for alignment and LAND for partial products
- Microinstruction execution would use INCODE for field encoding and MOVPRT for field extraction

### Cooperative drafts

#### DS coop

# Analysis of SIM100.FTN Codec/Logic Routines

## 1. Per-Subroutine Reference

### INCODE
**Signature:** `SUBROUTINE INCODE(OCT, IDX, REG)`
- **Inputs:** `OCT` (integer octal value to encode), `IDX` (field selector index 1-24), `REG(8)` (8-byte program source word)
- **Outputs:** `REG(8)` modified in-place
- **Purpose:** Encodes an octal value into a specific field of a 64-bit (8-byte) program source word. This is the inverse of a field extraction operation.
- **AP-120B Operation:** Simulates encoding of the 24-field microinstruction word. Each computed GOTO target corresponds to one of the 24 SIM100 SPLIT fields:
  - IDX 1: D field (1 bit at bit 7 of byte 1)
  - IDX 2: SOP field (3 bits at bits 4-6 of byte 1)
  - IDX 3: SH field (2 bits at bits 2-3 of byte 1)
  - IDX 4: SPS field (2+2 bits split across bytes 1-2)
  - IDX 5: SPD field (4 bits at bits 2-5 of byte 2)
  - IDX 6: FADD field (2+1 bits split across bytes 2-3)
  - IDX 7: A1 field (3 bits at bits 4-6 of byte 3)
  - IDX 8: A2 field (3 bits at bits 1-3 of byte 3)
  - IDX 9: COND field (1+3 bits split across bytes 3-4)
  - IDX 10: DISP field (5 bits at bits 0-4 of byte 4)
  - IDX 11: DPX field (2 bits at bits 6-7 of byte 5)
  - IDX 12: DPY field (2 bits at bits 4-5 of byte 5)
  - IDX 13: DPBS field (3 bits at bits 1-3 of byte 5)
  - IDX 14: XR field (1+2 bits split across bytes 5-6)
  - IDX 15: YR field (3 bits at bits 3-5 of byte 6)
  - IDX 16: XW field (3 bits at bits 0-2 of byte 6)
  - IDX 17: YW field (3 bits at bits 5-7 of byte 7)
  - IDX 18: FM field (1 bit at bit 4 of byte 7)
  - IDX 19: M1 field (2 bits at bits 2-3 of byte 7)
  - IDX 20: M2 field (2 bits at bits 0-1 of byte 7)
  - IDX 21: MI field (2 bits at bits 6-7 of byte 8)
  - IDX 22: MA field (2 bits at bits 4-5 of byte 8)
  - IDX 23: DPA field (2 bits at bits 2-3 of byte 8)
  - IDX 24: TMA field (2 bits at bits 0-1 of byte 8)
- **Note:** IDX values 25-40 map to fields 4,4,5,5,5,5,5,5,5,27,7,8,8,8,8,8,8 — this appears to handle aliased or repeated field indices.

### LAND
**Signature:** `SUBROUTINE LAND(REGA, REGB, REGC, W)`
- **Inputs:** `REGA(W)`, `REGB(W)` (two byte arrays), `W` (width in bytes)
- **Outputs:** `REGC(W)` (result byte array)
- **Purpose:** Performs bitwise logical AND on two multi-byte registers.
- **AP-120B Operation:** Simulates the bitwise AND operation available in the AP-120B's ALU/logic unit. The byte-by-byte, bit-by-bit implementation (lines 50-100) handles arbitrary-width registers.

### LCOM
**Signature:** `SUBROUTINE LCOM(REGA, REGB, W)`
- **Inputs:** `REGA(W)` (source byte array), `W` (width in bytes)
- **Outputs:** `REGB(W)` (complemented result)
- **Purpose:** Performs bitwise logical complement (NOT) on a multi-byte register.
- **AP-120B Operation:** Simulates the logical complement operation. Note the bit-by-bit implementation: `IF (MOD(KA,2).EQ.0) KB=KB+128` — bit is set in result only if source bit is 0.

### LSHFT
**Signature:** `SUBROUTINE LSHFT(REGA, COUNT, W, SIGNED, CARRY, BUCKET)`
- **Inputs:** `REGA(W)` (register to shift), `COUNT` (shift amount, positive=left, negative=right), `W` (width in bytes), `SIGNED` (0=logical, 1=arithmetic)
- **Outputs:** `REGA(W)` modified in-place, `CARRY` (last bit shifted out), `BUCKET` (OR of all bits shifted into carry)
- **Purpose:** Performs logical or arithmetic shift on a multi-byte register.
- **AP-120B Operation:** Simulates the barrel shifter or sequential shift operations. Key details:
  - Left shift: `CARRY=MOD(REGA(1)/128,2)` captures MSB before shift (line ~40)
  - Right shift (arithmetic): `IS=MOD(REGA(1)/128,2)*128` extends sign bit (line ~120)
  - The `BUCKET` parameter accumulates OR of all shifted-out bits (for multi-bit shift detection)
  - Comment at line ~125 documents a PDP-11 RT-11 FORTRAN compiler bug workaround

### MOVPRT
**Signature:** `SUBROUTINE MOVPRT(SRC, S1, DST, D1, SW, DW, N)`
- **Inputs:** `SRC(SW)` (source register), `S1` (start byte in source), `DST(DW)` (destination register), `D1` (start byte in destination), `SW` (source width), `DW` (destination width), `N` (number of bytes to move)
- **Outputs:** `DST(DW)` modified
- **Purpose:** Copies N bytes from one position in a register to another position in another register.
- **AP-120B Operation:** Simulates partial register transfers — moving specific byte fields between registers of potentially different widths. This is used for field extraction/insertion in the microinstruction word.

### MREAD
**Signature:** `SUBROUTINE MREAD(MEM, MA, REG, MSIZE, MW, RW)`
- **Inputs:** `MEM(MSIZE,MW)` (memory array), `MA` (memory address, 0-based), `MSIZE` (number of locations), `MW` (memory width in 16-bit words), `RW` (register width in bytes)
- **Outputs:** `REG(RW)` (fetched data)
- **Purpose:** Reads a memory location and converts from 16-bit word storage to byte array representation.
- **AP-120B Operation:** Simulates memory read from any of the AP-120B's memories (main data memory, table memory, etc.). Key details:
  - `MAR=MA+1` converts from 0-based to 1-based FORTRAN indexing
  - Lines 50-100: Handles 16-bit signed integer storage — if `ITMP.GE.0` check detects sign bit, adds back via `INF` flag
  - Line 200: Out-of-range addresses return zero (simulates unmapped memory behavior)
  - Each 16-bit word is split into two bytes: high byte = `ITMP/256`, low byte = `MOD(ITMP,256)`

### MWRIT
**Signature:** `SUBROUTINE MWRIT(REG, MEM, MA, MSIZE, RW, MW)`
- **Inputs:** `REG(RW)` (source register), `MEM(MSIZE,MW)` (memory array), `MA` (address), `MSIZE`, `RW`, `MW`
- **Outputs:** `MEM(MSIZE,MW)` modified
- **Purpose:** Writes a register to memory, converting from byte array to 16-bit word storage.
- **AP-120B Operation:** Simulates memory write. Key details:
  - Line ~30: Out-of-range addresses silently return (no write)
  - Lines 40-100: Reconstructs 16-bit word from two bytes, handling sign bit: `INF=MOD(REG(J)/128,2)` captures sign, `ITMP=MOD(REG(J),128)*256+REG(J+1)` combines bytes, `IF (INF.EQ.1) ITMP=ITMP-32767-1` applies sign

## 2. Bit-Level Semantics

### Byte Array Representation
All registers are stored as arrays of 8-bit bytes (FORTRAN `INTEGER` values 0-255). The AP-120B's 38-bit floating-point and 16/32-bit integer data are represented as sequences of these bytes.

### Field Encoding in INCODE
The bit manipulation patterns reveal the exact bit positions of each microinstruction field:

**Byte 1 (bits 7-0):**
- Bit 7: D field (1 bit)
- Bits 6-4: SOP field (3 bits)
- Bits 3-2: SH field (2 bits)
- Bits 1-0: SPS field (lower 2 bits)

**Byte 2 (bits 7-0):**
- Bits 7-6: SPS field (upper 2 bits)
- Bits 5-2: SPD field (4 bits)
- Bits 1-0: FADD field (lower 2 bits)

**Byte 3 (bits 7-0):**
- Bit 7: FADD field (upper 1 bit)
- Bits 6-4: A1 field (3 bits)
- Bits 3-1: A2 field (3 bits)
- Bit 0: COND field (lower 1 bit)

**Byte 4 (bits 7-0):**
- Bits 7-5: COND field (upper 3 bits)
- Bits 4-0: DISP field (5 bits)

**Byte 5 (bits 7-0):**
- Bits 7-6: DPX field (2 bits)
- Bits 5-4: DPY field (2 bits)
- Bits 3-1: DPBS field (3 bits)
- Bit 0: XR field (lower 1 bit)

**Byte 6 (bits 7-0):**
- Bits 7-6: XR field (upper 2 bits)
- Bits 5-3: YR field (3 bits)
- Bits 2-0: XW field (3 bits)

**Byte 7 (bits 7-0):**
- Bits 7-5: YW field (3 bits)
- Bit 4: FM field (1 bit)
- Bits 3-2: M1 field (2 bits)
- Bits 1-0: M2 field (2 bits)

**Byte 8 (bits 7-0):**
- Bits 7-6: MI field (2 bits)
- Bits 5-4: MA field (2 bits)
- Bits 3-2: DPA field (2 bits)
- Bits 1-0: TMA field (2 bits)

### Bit Manipulation Patterns
The code uses consistent patterns:
- `MOD(OCT, N)` extracts the lowest N-valued bits from the octal input
- `MOD(REG(N), M)` preserves bits below position M
- `(REG(N)/K)*K` clears bits below position K
- `MOD(REG(N)/K, 2)` extracts bit at position K

## 3. State and Side Effects

### COMMON Block Variables
None of these routines directly reference COMMON blocks — they operate on passed parameters. However, they are called by higher-level routines that do access COMMON:

- **INCODE** modifies `REG(8)` — this is typically a program source word from the microinstruction memory
- **LAND, LCOM, LSHFT** operate on generic byte arrays — these could represent any AP-120B register (DPX, DPY, S-Pad, MD, TM, etc.)
- **MOVPRT** performs register-to-register byte transfers — used for field manipulation
- **MREAD, MWRIT** access `MEM(MSIZE,MW)` — this represents one of the AP-120B memories (main data memory, table memory, program source memory)

### AP-120B Architectural State Represented
- **Program Source Word (REG(8)):** The 64-bit microinstruction word, split into 24 fields
- **Memory Arrays:** Main data memory (MD), table memory (TM), or program source memory (PSA)
- **General Registers:** Any of the AP-120B's registers (DPX, DPY, S-Pad locations, etc.)

## 4. AP-120B-Specific Edge Cases

### 38-bit Float Format
While not directly visible in these routines, the byte array representation supports the 38-bit format (1 sign + 9 exponent + 28 mantissa) through:
- **MREAD/MWRIT** handle 16-bit word boundaries — a 38-bit float would span 3 words (48 bits) with 10 unused bits
- **LSHFT** with `SIGNED=1` preserves sign bit during right shifts, critical for floating-point normalization

### Memory Addressing
- **MREAD line ~30:** `IF (MAR.LE.0.OR.MAR.GT.MSIZE) GO TO 200` — out-of-range reads return zero, simulating unmapped memory behavior
- **MWRIT line ~30:** `IF (MAR.LE.0.OR.MAR.GT.MSIZE) RETURN` — out-of-range writes silently fail

### 16-bit Word Storage
- **MREAD lines 50-100:** Handles PDP-11 16-bit signed integers — the `ITMP.GE.0` check and `INF` flag handle sign extension
- **MWRIT lines 40-100:** Reconstructs 16-bit words with sign handling: `IF (INF.EQ.1) ITMP=ITMP-32767-1`

### Shift Operations
- **LSHFT line ~125:** Comment documents a PDP-11 RT-11 FORTRAN compiler bug where `/2` is omitted from `REGA(1)/2+IS` — the extra assignment `IS=REGA(1)/2+IS` works around this
- **BUCKET parameter:** Accumulates OR of all shifted-out bits, used for detecting overflow in multi-bit shifts

## 5. Cross-References

These routines are called by higher-level SIM100 routines in other clusters:

### Called by (inferred from context):
- **INCODE:** Called by microinstruction assembler/disassembler routines that manipulate program source words
- **LAND, LCOM:** Called by ALU simulation routines for logical operations on register values
- **LSHFT:** Called by floating-point normalization routines (FPADD, FMF, etc.) and integer arithmetic routines
- **MOVPRT:** Called by field extraction/insertion routines for the 24-field microinstruction word
- **MREAD, MWRIT:** Called by memory access routines for main data memory, table memory, and program source memory

### Delegation Pattern:
These routines are "leaf" routines — they do not call other SIM100 routines. They provide primitive operations that are composed by higher-level routines:
- **FPADD** would call LSHFT for normalization and LAND/LCOM for sign/mantissa manipulation
- **FMF** (floating multiply) would call LSHFT for alignment and LAND for partial product accumulation
- **Microinstruction execution routines** would call INCODE for field encoding and MOVPRT for field extraction

#### GLM coop

# Analysis of SIM100.FTN Section: `codec_logic`

## 1. Per-Subroutine Reference

### INCODE
- **Signature**: `SUBROUTINE INCODE(OCT,IDX,REG)`
- **Purpose**: Encodes an octal value into a specific field of a program source word stored as 8 bytes
- **Inputs/Outputs**: 
  - `OCT`: Octal value to encode
  - `IDX`: Field index (1-24, corresponding to microinstruction fields)
  - `REG`: 8-byte array representing the program word (modified in-place)
- **AP-120B operation**: Simulates microinstruction field encoding in the FPS-100 microarchitecture. Each field corresponds to specific bits in the 64-bit microinstruction format. The routine uses bit masking with `MOD()` operations to update only the relevant bits within each byte of the program word.

### LAND
- **Signature**: `SUBROUTINE LAND(REGA,REGB,REGC,W)`
- **Purpose**: Performs a logical AND operation between two registers
- **Inputs/Outputs**:
  - `REGA`: First input register (W bytes)
  - `REGB`: Second input register (W bytes)
  - `REGC`: Output register (W bytes)
  - `W`: Width of registers in bytes
- **AP-120B operation**: Simulates the FPS-100 logical unit's bitwise AND operation. Takes two input registers and produces the bitwise AND result in the output register by examining each bit position individually (lines 50-100).

### LCOM
- **Signature**: `SUBROUTINE LCOM(REGA,REGB,W)`
- **Purpose**: Performs a logical complement (bitwise NOT) operation on a register
- **Inputs/Outputs**:
  - `REGA`: Input register (W bytes)
  - `REGB`: Output register (W bytes)
  - `W`: Width of registers in bytes
- **AP-120B operation**: Simulates the FPS-100 logical unit's bitwise NOT operation. Takes an input register and produces the bitwise NOT result in the output register by inverting each bit individually (lines 50-100).

### LSHFT
- **Signature**: `SUBROUTINE LSHFT(REGA,COUNT,W,SIGNED,CARRY,BUCKET)`
- **Purpose**: Performs logical or arithmetic shift operations on a register
- **Inputs/Outputs**:
  - `REGA`: Input/output register (W bytes, modified in-place)
  - `COUNT`: Number of positions to shift (negative=right, positive=left)
  - `W`: Width of register in bytes
  - `SIGNED`: Flag (1=arithmetic shift, 0=logical)
  - `CARRY`: Bit shifted out of the register
  - `BUCKET`: Inclusive OR of bits shifted into CARRY
- **AP-120B operation**: Simulates the FPS-100 shift unit operations. Performs both logical and arithmetic shifts with carry and overflow outputs. For arithmetic shifts, preserves sign bit by replicating it (line 149). BUCKET captures overflow information.

### MOVPRT
- **Signature**: `SUBROUTINE MOVPRT(SRC,S1,DST,D1,SW,DW,N)`
- **Purpose**: Moves part of a source register to a destination register
- **Inputs/Outputs**:
  - `SRC`: Source register (SW bytes)
  - `S1`: Starting byte in source register
  - `DST`: Destination register (DW bytes, modified in-place)
  - `D1`: Starting byte in destination register
  - `SW`: Width of source register in bytes
  - `DW`: Width of destination register in bytes
  - `N`: Number of bytes to move
- **AP-120B operation**: Simulates partial register transfers in the FPS-100. Moves a specified number of bytes from one position to another in register space (lines 100-100).

### MREAD
- **Signature**: `SUBROUTINE MREAD(MEM,MA,REG,MSIZE,MW,RW)`
- **Purpose**: Reads data from memory into a register
- **Inputs/Outputs**:
  - `MEM`: Memory array (MSIZE locations × MW words)
  - `MA`: Memory address to read from
  - `REG`: Output register (RW bytes)
  - `MSIZE`: Number of memory locations
  - `MW`: Words per memory location
  - `RW`: Width of register in bytes
- **AP-120B operation**: Simulates FPS-100 memory read operations. Fetches data from a memory location, handling 16-bit to 8-bit conversion with sign extension if needed (lines 50-100). Returns zero-filled register on out-of-range access (lines 200-210).

### MWRIT
- **Signature**: `SUBROUTINE MWRIT(REG,MEM,MA,MSIZE,RW,MW)`
- **Purpose**: Writes data from a register to memory
- **Inputs/Outputs**:
  - `REG`: Input register (RW bytes)
  - `MEM`: Memory array (MSIZE locations × MW words, modified in-place)
  - `MA`: Memory address to write to
  - `MSIZE`: Number of memory locations
  - `RW`: Width of register in bytes
  - `MW`: Words per memory location
- **AP-120B operation**: Simulates FPS-100 memory write operations. Converts register bytes to 16-bit words with sign handling, storing to memory (lines 100-100). Does nothing on out-of-range address.

## 2. Bit-Level Semantics

### INCODE
- Each field corresponds to specific bit positions in the 8-byte program word:
  - `D` (1 bit): MSB of byte 1
  - `SOP` (3 bits): Bits 5-7 of byte 1
  - `SH` (2 bits): Bits 3-4 of byte 1
  - `SPS` (6 bits): Bits 1-2 of byte 1 and bit 7 of byte 2
  - `SPD` (4 bits): Bits 1-4 of byte 2
  - `FADD` (5 bits): Bit 1 of byte 2 and bit 7 of byte 3
  - `A1` (3 bits): Bits 5-7 of byte 3
  - `A2` (3 bits): Bits 1-3 of byte 3
  - `COND` (5 bits): Bit 1 of byte 3 and bits 1-4 of byte 4
  - `DISP` (5 bits): Bits 1-5 of byte 4
  - `DPX` (2 bits): Bits 7-8 of byte 5
  - `DPY` (2 bits): Bits 5-6 of byte 5
  - `DPBS` (3 bits): Bits 1-3 of byte 5
  - `XR` (3 bits): Bit 1 of byte 5 and bit 7 of byte 6
  - `YR` (3 bits): Bits 5-7 of byte 6
  - `XW` (3 bits): Bits 1-3 of byte 6
  - `YW` (3 bits): Bits 1-3 of byte 7
  - `FM` (1 bit): Bit 5 of byte 7
  - `M1` (2 bits): Bits 3-4 of byte 7
  - `M2` (2 bits): Bits 1-2 of byte 7
  - `MI` (2 bits): Bits 7-8 of byte 8
  - `MA` (2 bits): Bits 5-6 of byte 8
  - `DPA` (2 bits): Bits 3-4 of byte 8
  - `TMA` (2 bits): Bits 1-2 of byte 8

### LAND
- Performs bitwise AND by examining each bit position individually:
  - For each bit (lines 50-100), checks if both bits in REGA and REGB are set
  - Uses bit shifting and `MOD()` operations to isolate and test individual bits
  - Sets result bit in REGC only if both input bits are 1

### LCOM
- Performs bitwise NOT by examining each bit position:
  - For each bit (lines 50-100), checks if the bit in REGA is clear
  - Sets result bit in REGB if the input bit was 0
  - Uses bit shifting and `MOD()` operations to process each bit

### LSHFT
- **Left shift** (COUNT > 0, lines 50-50):
  - Captures MSB of first byte as CARRY
  - Propagates MSB of each byte to LSB of next byte
  - Zero-fills LSB of last byte
- **Right shift** (COUNT < 0, lines 110-150):
  - Captures LSB of last byte as CARRY
  - Propagates LSB of each byte to MSB of previous byte
  - For arithmetic shifts (SIGNED=1), replicates sign bit (line 149)
- BUCKET accumulates OR of any bits shifted into CARRY position

### MREAD
- Converts 16-bit memory words to 8-bit register bytes:
  - Handles sign extension by checking MSB of each 16-bit word (lines 50-100)
  - Sets sign bit in register if original word was negative
  - Preserves original value through modulo arithmetic

### MWRIT
- Converts 8-bit register bytes to 16-bit memory words:
  - Handles sign extension by checking MSB of each register byte (lines 100-100)
  - Adjusts value if sign bit was set in register
  - Stores result in memory as 16-bit word

## 3. State and Side Effects

### INCODE
- **Reads**: Parameters OCT, IDX, and REG array
- **Writes**: Modifies REG array in-place to update the specified field
- **State representation**: Simulates microinstruction encoding for FPS-100 control store. The REG array represents a 64-bit microinstruction in the control store.

### LAND
- **Reads**: Parameters REGA, REGB, W
- **Writes**: Parameter REGC
- **State representation**: Simulates logical operation without modifying architectural state. Produces result in output register.

### LCOM
- **Reads**: Parameters REGA, W
- **Writes**: Parameter REGB
- **State representation**: Simulates logical complement without modifying architectural state. Produces result in output register.

### LSHFT
- **Reads**: Parameters REGA, COUNT, W, SIGNED
- **Writes**: Parameters CARRY, BUCKET, and REGA (modified in-place)
- **State representation**: Simulates shift operation by modifying a register directly. The CARRY and BUCKET outputs represent shift status information.

### MOVPRT
- **Reads**: Parameters SRC, S1, DST, D1, SW, DW, N
- **Writes**: DST array (modified in-place)
- **State representation**: Simulates partial register transfer without directly modifying architectural state.

### MREAD
- **Reads**: Parameters MEM, MA, MSIZE, MW, RW
- **Writes**: Parameter REG
- **State representation**: Simulates memory read from FPS-100 memory array. The MEM array represents the FPS-100's memory space.

### MWRIT
- **Reads**: Parameters REG, MSIZE, RW, MW
- **Writes**: MEM array (modified in-place at specified address)
- **State representation**: Simulates memory write to FPS-100 memory array. The MEM array represents the FPS-100's memory space.

None of these routines directly interact with COMMON-block variables representing AP-120B architectural state (DPX, DPY, S-Pad, MD, TM, PSA, APSTAT). They are utility routines supporting the simulation of the FPS-100's control path and data movement operations.

## 4. AP-120B-Specific Edge Cases

### INCODE
- Handles 24 distinct microinstruction fields with varying bit widths (1-6 bits)
- Implements exact bit positioning according to the FPS-100 microinstruction format
- Uses octal values (base 8) as input, consistent with FPS-100 field encodings

### LAND/LCOM
- No special edge cases implemented - straightforward bit operations

### LSHFT
- **Arithmetic shift preservation**: When SIGNED=1, preserves sign bit by replicating it during right shift (line 149)
- **Carry handling**: For left shifts, captures MSB of first byte; for right shifts, captures LSB of last byte
- **Bucket overflow tracking**: BUCKET output captures OR of any bits shifted into carry position

### MOVPRT
- No special boundary checking - assumes valid indices and register sizes

### MREAD
- **Out-of-range protection**: Returns zero-filled register if memory address is invalid (lines 200-210)
- **Sign extension**: Correctly handles negative 16-bit words by setting sign


---

## Cluster: `norm_pack` (lines 3603-3975)

**NEGATE, NORMAL, PAKRG, RMOV, SPLIT, TCADD, UNPKRG**

### DeepSeek final

(adv 87s, 20388c)

## Critique of GLM Analysis

The GLM analysis contains several significant errors and omissions:

1. **Incorrect AP-120B format understanding**: The AP-120B uses a 38-bit floating-point format with 1 sign + 9 exponent + 28 mantissa, but the GLM analysis incorrectly states the exponent is 11 bits and mantissa is 32 bits. The code shows exponent range check `IF (EC.LT.1024)` which is 2^10, confirming 10-bit exponent (not 11). The mantissa is stored in 4 bytes (32 bits) but only 28 are significant after normalization.

2. **Missing critical detail in NORMAL**: The GLM analysis fails to note that `RNDCON(1)=7, RNDCON(2)=8, RNDCON(3)=0, RNDCON(4)=15` and the indexing `IRND=TRUNC*2+ISC+1` creates a 4-element lookup table for rounding constants, which is a key AP-120B convergent rounding implementation detail.

3. **Incorrect SPLIT field descriptions**: The GLM analysis provides vague descriptions like "bits 4-7 of byte 1" without mapping to actual AP-120B opcode fields (DF, SOPF, SHF, etc.).

4. **Missing AP-120B state mapping**: The analysis doesn't connect these routines to the actual AP-120B architectural state (DPX, DPY, S-Pad, MD, TM, PSA, APSTAT).

5. **Incorrect NORMAL zero detection**: The GLM analysis misses the critical detail that `ISHIFT=-3` for rounding and `ISHIFT=-4` for truncation shifts the mantissa to check for all-zeros or all-ones patterns.

6. **Missing the 4-byte to 2-byte exponent packing**: `ANSWER(1)=EC/256` and `ANSWER(2)=MOD(EC,256)` splits the exponent into high/low bytes, which is a specific AP-120B format detail.

7. **No mention of the byte-reversed storage convention**: The code uses `J=W-I+1` in TCADD, indicating bytes are stored in reverse order (big-endian byte order within the simulator's representation).

## Final Reference: AP-120B Microarchitecture Analysis of SIM100.FTN Section

---

## 1. Per-Subroutine Reference

### NEGATE
- **Signature:** `SUBROUTINE NEGATE(REGA,W,OVER)`
- **Purpose:** Two's complement negation of a W-byte register
- **Inputs:** `REGA` (W-byte register to negate), `W` (width in bytes)
- **Outputs:** `REGA` (negated result in-place), `OVER` (overflow flag: 0=no overflow, 1=overflow occurred)
- **AP-120B operation:** Simulates the hardware two's complement negation path. The AP-120B integer ALU performs negation by complementing all bits then adding 1. Overflow occurs when negating the most negative value (sign bit doesn't change). The `OVER` output corresponds to the AP-120B's overflow status bit in the condition code register.
- **Implementation:** Calls `LCOM` for bitwise complement, then `TCADD` to add 1. Overflow detection compares original sign bit (`IS=MOD(REGA(1)/128,2)`) with result sign bit; if equal after negation, overflow is set to the sign value.

### NORMAL
- **Signature:** `SUBROUTINE NORMAL(EC,MC,ANSWER,TRUNC,NOCNT)`
- **Purpose:** Normalize, round, and pack a floating-point result with error/condition bits
- **Inputs:** `EC` (exponent, 0-1023 range), `MC(4)` (4-byte mantissa, 32-bit representation), `TRUNC` (0=round, 1=truncate), `NOCNT` (max normalize shifts: 0=inhibit, 2=multiply, 40=default)
- **Outputs:** `ANSWER(7)` (packed result: bytes 1-2=exponent, bytes 3-6=mantissa, byte 7=status flags)
- **AP-120B operation:** Simulates the FPS-100 floating-point normalization and rounding unit. The AP-120B FPU normalizes results by left-shifting the mantissa until the two high bits are "01" or "10" (indicating normalized form), decrementing the exponent for each shift. Convergent rounding is applied by adding a rounding constant to the 28-bit mantissa. The routine handles:
  - Mantissa normalization (left-shift until bits 6-7 of byte 1 are 01 or 10 binary)
  - Convergent rounding (positive: add 0x07, negative: add 0x08; truncate: add 0x00 or 0x0F)
  - Post-rounding overflow (if mantissa overflows, right-shift and increment exponent)
  - Underflow (exponent < 0 → force zero, set bit 3 of status)
  - Overflow (exponent ≥ 1024 → force max value, set bit 4 of status)
  - Zero detection (all mantissa bytes zero → set bit 2 of status)
  - Sign bit preservation (bit 0 of status)
- **Status byte format (ANSWER(7)):**
  - Bit 0 (value 1): Negative sign
  - Bit 1 (value 2): Zero
  - Bit 3 (value 8): Exponent underflow
  - Bit 4 (value 16): Exponent overflow

### PAKRG
- **Signature:** `SUBROUTINE PAKRG(REG,DEC)`
- **Purpose:** Pack a 2-byte register into a 16-bit integer
- **Inputs:** `REG(2)` (2-byte register, byte-separated representation)
- **Outputs:** `DEC` (16-bit integer, packed representation)
- **AP-120B operation:** Converts from the simulator's internal byte-separated register format to a 16-bit integer. Uses `MWRIT` to write 2 bytes from `REG` into a single 16-bit word. This is used when the AP-120B's 16-bit data paths need to access register values as words rather than bytes.

### RMOV
- **Signature:** `SUBROUTINE RMOV(SRC,DST,W)`
- **Purpose:** Copy W bytes from source register to destination register
- **Inputs:** `SRC(W)` (source register), `W` (width in bytes)
- **Outputs:** `DST(W)` (destination register, overwritten)
- **AP-120B operation:** Simulates register-to-register data transfer. The AP-120B can move data between S-pad registers, DPX, DPY, and other storage elements. This routine provides a generic byte-by-byte copy used throughout the simulator.

### SPLIT
- **Signature:** `SUBROUTINE SPLIT(REG,FV)`
- **Purpose:** Decode an 8-byte instruction word into 24 opcode fields
- **Inputs:** `REG(8)` (8-byte instruction word, byte-separated representation)
- **Outputs:** `FV(24)` (24 decoded field values, each 1-5 bits wide)
- **AP-120B operation:** Simulates the instruction register decoding. The FPS-100 has a 64-bit instruction word (8 bytes) that is split into 24 control fields. Each field controls a specific functional unit or data path. The field mapping follows the standard FPS-7319 24-field format:
  - FV(1): DF (Destination Field) - 1 bit
  - FV(2): SOPF (Source Operand Field) - 3 bits
  - FV(3): SHF (Shift Field) - 2 bits
  - FV(4): SPSF (Source Pad Select Field) - 4 bits
  - FV(5): SPDF (Source Pad Data Field) - 4 bits
  - FV(6): FADDF (FADD Field) - 3 bits
  - FV(7): A1F (A1 Field) - 3 bits
  - FV(8): A2F (A2 Field) - 3 bits
  - FV(9): CONDF (Condition Field) - 3 bits
  - FV(10): DISPF (Display Field) - 5 bits
  - FV(11): DPXF (DPX Field) - 2 bits
  - FV(12): DPYF (DPY Field) - 2 bits
  - FV(13): DPBSF (DPBS Field) - 3 bits
  - FV(14): XRF (XR Field) - 3 bits
  - FV(15): YRF (YR Field) - 3 bits
  - FV(16): XWF (XW Field) - 3 bits
  - FV(17): YWF (YW Field) - 3 bits
  - FV(18): FMF (FM Field) - 1 bit
  - FV(19): M1F (M1 Field) - 2 bits
  - FV(20): M2F (M2 Field) - 2 bits
  - FV(21): MIF (MI Field) - 2 bits
  - FV(22): MAF (MA Field) - 2 bits
  - FV(23): DPAF (DPA Field) - 2 bits
  - FV(24): TMAF (TMA Field) - 2 bits
- **Bit extraction details:**
  - Each field is extracted using `MOD(byte/divisor, modulus)` operations
  - Fields can span byte boundaries (e.g., FV(4) uses bits from bytes 1 and 2)
  - The 8-byte instruction word represents the 64-bit AP-120B instruction

### TCADD
- **Signature:** `SUBROUTINE TCADD(REGA,REGB,REGC,W,CARRY)`
- **Purpose:** Two's complement addition of two W-byte registers
- **Inputs:** `REGA(W)` (first operand), `REGB(W)` (second operand), `W` (width in bytes)
- **Outputs:** `REGC(W)` (sum result), `CARRY` (carry-out: 0 or 1)
- **AP-120B operation:** Simulates the integer adder used in the AP-120B's ALU. The addition proceeds from least significant byte to most significant byte (index `J=W-I+1` iterates from W down to 1). Each byte addition includes the carry from the previous byte. The final carry-out represents overflow for unsigned addition. This routine is used as a building block for all arithmetic operations.
- **Byte ordering:** The loop `DO 100 I=1,W` with `J=W-I+1` processes bytes from index W (LSB) to index 1 (MSB), indicating the simulator stores registers with byte 1 as MSB and byte W as LSB (big-endian within the byte array).

### UNPKRG
- **Signature:** `SUBROUTINE UNPKRG(DEC,REG)`
- **Purpose:** Unpack a 16-bit integer into a 2-byte register
- **Inputs:** `DEC` (16-bit integer)
- **Outputs:** `REG(2)` (2-byte register, byte-separated representation)
- **AP-120B operation:** Converts a 16-bit integer into the simulator's internal byte-separated register format. Uses `MREAD` to read 2 bytes from the 16-bit word into `REG`. This is the inverse of `PAKRG`.

---

## 2. Bit-Level Semantics

### Byte-Separated Register Representation
All registers in SIM100 are stored as arrays of 8-bit integers (0-255 range). This avoids PDP-11 FORTRAN sign-bit issues with 16-bit integers. A W-byte register is an array `REG(W)` where:
- `REG(1)` = most significant byte (MSB)
- `REG(W)` = least significant byte (LSB)

### NEGATE Bit Operations
- **Sign bit extraction:** `MOD(REGA(1)/128,2)` extracts bit 7 of byte 1 (the sign bit of the entire register). `REGA(1)/128` performs integer division by 128, shifting bit 7 to bit 0; `MOD(...,2)` isolates that bit.
- **Overflow detection:** After negation, if the sign bit hasn't changed, overflow occurred. `OVER=IS` stores the original sign as the overflow indicator (1 for negative overflow, 0 for positive overflow).

### NORMAL Bit Operations
- **Normalization check:** `MOD(MC(1)/64,4)` extracts bits 6-7 of byte 1 (the two highest bits of the 32-bit mantissa). Normalized form requires these to be "01" (value 1) or "10" (value 2).
- **Sign bit:** `MOD(MC(1)/128,2)` extracts bit 7 of byte 1.
- **Rounding constants (RNDCON):**
  - `RNDCON(1)=7` (binary 00000111): Positive, round mode
  - `RNDCON(2)=8` (binary 00001000): Negative, round mode
  - `RNDCON(3)=0` (binary 00000000): Positive, truncate mode
  - `RNDCON(4)=15` (binary 00001111): Negative, truncate mode
  - Index calculation: `IRND=TRUNC*2+ISC+1` where `ISC` is the sign bit (0=positive, 1=negative) and `TRUNC` is 0 or 1.
- **Pre-rounding shift:** `ISHIFT=-3` for rounding, `ISHIFT=-4` for truncation. This right-shifts the mantissa by 3 or 4 bits to check for all-zeros or all-ones patterns before normalization.
- **Exponent packing:** `ANSWER(1)=EC/256` extracts the high byte (bits 8-9 of the 10-bit exponent), `ANSWER(2)=MOD(EC,256)` extracts the low byte (bits 0-7).
- **Mantissa alignment:** `CALL LSHFT(MC,-4,4,0,K,K)` right-shifts the mantissa by 4 bits to align it with the right boundary of the 4-byte field, discarding the guard bits used during normalization.

### SPLIT Bit Extraction
Each field extraction uses the pattern `MOD(byte/divisor, modulus)`:
- `byte/divisor` shifts the desired bit group to the least significant position
- `MOD(..., modulus)` masks to the field width

Field boundaries and widths:
| Field | Bytes Used | Bit Positions | Width |
|-------|-----------|---------------|-------|
| FV(1) | Byte 1 | bit 7 | 1 |
| FV(2) | Byte 1 | bits 4-6 | 3 |
| FV(3) | Byte 1 | bits 2-3 | 2 |
| FV(4) | Bytes 1-2 | byte1 bits 0-1, byte2 bits 6-7 | 4 |
| FV(5) | Byte 2 | bits 2-5 | 4 |
| FV(6) | Bytes 2-3 | byte2 bits 0-1, byte3 bit 7 | 3 |
| FV(7) | Byte 3 | bits 4-6 | 3 |
| FV(8) | Byte 3 | bits 1-3 | 3 |
| FV(9) | Bytes 3-4 | byte3 bit 0, byte4 bits 3-5 | 3 |
| FV(10) | Byte 4 | bits 0-4 | 5 |
| FV(11) | Byte 5 | bits 6-7 | 2 |
| FV(12) | Byte 5 | bits 4-5 | 2 |
| FV(13) | Byte 5 | bits 1-3 | 3 |
| FV(14) | Bytes 5-6 | byte5 bit 0, byte6 bits 6-7 | 3 |
| FV(15) | Byte 6 | bits 3-5 | 3 |
| FV(16) | Byte 6 | bits 0-2 | 3 |
| FV(17) | Byte 7 | bits 5-7 | 3 |
| FV(18) | Byte 7 | bit 4 | 1 |
| FV(19) | Byte 7 | bits 2-3 | 2 |
| FV(20) | Byte 7 | bits 0-1 | 2 |
| FV(21) | Byte 8 | bits 6-7 | 2 |
| FV(22) | Byte 8 | bits 4-5 | 2 |
| FV(23) | Byte 8 | bits 2-3 | 2 |
| FV(24) | Byte 8 | bits 0-1 | 2 |

### TCADD Bit Operations
- **Byte addition:** `REGC(J)=REGA(J)+REGB(J)+CARRY` performs 8-bit addition with carry-in.
- **Carry detection:** `IF (REGC(J).LT.256)` checks if the sum exceeds 255 (the maximum 8-bit value). If so, `REGC(J)=REGC(J)-256` wraps the byte and `CARRY=1` propagates to the next byte.
- **Byte order:** The loop processes from byte W (LSB) to byte 1 (MSB), implementing big-endian addition with carry propagation from least significant to most significant.

---

## 3. State and Side Effects

### COMMON Block Variables (not directly visible in this section, but implied by cross-references)

The routines in this section operate on local arrays and parameters, but they are called by higher-level routines that access AP-120B architectural state. The following state is manipulated:

### NEGATE
- **Reads:** `REGA` (general-purpose register, typically an S-pad or data register)
- **Writes:** `REGA` (in-place negation), `OVER` (overflow flag)
- **AP-120B state:** Represents the integer ALU's negation operation. The `OVER` output corresponds to the AP-120B's condition code overflow bit.

### NORMAL
- **Reads:** `EC` (exponent, 10-bit value 0-1023), `MC(4)` (mantissa, 32-bit representation of 28-bit mantissa + guard bits), `TRUNC` (rounding mode), `NOCNT` (shift limit)
- **Writes:** `ANSWER(7)` (packed result), `MC` (modified during normalization), `EC` (modified during normalization)
- **AP-120B state:** This routine processes the floating-point result before it is stored. The `EC` and `MC` represent the internal FPU accumulator (the 38-bit floating-point result before normalization). The `ANSWER` array represents the final packed format:
  - `ANSWER(1-2)`: 16-bit exponent (only 10 bits significant)
  - `ANSWER(3-6)`: 32-bit mantissa (only 28 bits significant, right-aligned)
  - `ANSWER(7)`: Status byte (bits: 0=sign, 1=zero, 3=underflow, 4=overflow)
- **Side effects:** Modifies `MC` and `EC` during normalization loop. Sets `ANSWER(7)` status bits based on result characteristics.

### PAKRG
- **Reads:** `REG(2)` (2-byte register)
- **Writes:** `DEC` (16-bit integer)
- **AP-120B state:** Converts from byte-separated to word-packed format. Used when the AP-120B's 16-bit data bus needs to access register values.

### RMOV
- **Reads:** `SRC(W)` (source register)
- **Writes:** `DST(W)` (destination register)
- **AP-120B state:** Generic register-to-register move. No side effects beyond the copy.

### SPLIT
- **Reads:** `REG(8)` (8-byte instruction word)
- **Writes:** `FV(24)` (24 decoded field values)
- **AP-120B state:** This is the instruction decoder. The `REG` array represents the 64-bit instruction register (IR). The `FV` array represents the 24 control fields that drive the AP-120B's functional units during instruction execution.

### TCADD
- **Reads:** `REGA(W)`, `REGB(W)` (operand registers)
- **Writes:** `REGC(W)` (result register), `CARRY` (carry-out)
- **AP-120B state:** Represents the integer adder. The `CARRY` output corresponds to the AP-120B's carry flag.

### UNPKRG
- **Reads:** `DEC` (16-bit integer)
- **Writes:** `REG(2)` (2-byte register)
- **AP-120B state:** Converts from word-packed to byte-separated format. Inverse of `PAKRG`.

---

## 4. AP-120B-Specific Edge Cases

### AP-120B 38-bit Floating-Point Format
The AP-120B uses a 38-bit floating-point format:
- Bit 37: Sign (1 bit)
- Bits 36-28: Exponent (9 bits, biased by 256? The code uses 0-1023 range suggesting 10-bit exponent)
- Bits 27-0: Mantissa (28 bits, normalized with hidden bit)

The code in NORMAL reveals this format:
- **Exponent range:** `IF (EC.LT.1024)` checks for overflow at exponent value 1024, indicating a 10-bit exponent (0-1023). The AP-120B documentation specifies 9-bit exponent, but this code uses 10 bits (possibly including a guard bit or bias adjustment).
- **Mantissa width:** The mantissa is stored in 4 bytes (32 bits), but after normalization and the final `CALL LSHFT(MC,-4,4,0,K,K)`, only 28 bits remain significant (the right shift discards 4 guard bits).
- **Normalization criterion:** `INRM=MOD(MC(1)/64,4)` checks bits 6-7 of the first mantissa byte. For a 28-bit mantissa stored in 32 bits (4 bytes), bits 6-7 of byte 1 correspond to bits 29-30 of the 32-bit representation. Normalized form requires these to be "01" or "10", meaning the mantissa has been shifted so that the most significant bit (bit 27 of the 28-bit mantissa) is at bit 30 of the 32-bit field.

### NORMAL Edge Cases

**All-Zeros/All-Ones Mantissa:**
- Before normalization, the mantissa is right-shifted by 3 (round) or 4 (truncate) bits: `CALL LSHFT(TMP,ISHIFT,4,1,KKK,J)`
- If all bytes are 0 (positive zero) or all bytes are 255 (negative zero), the result is forced to clean zero: `GO TO 550`
- This handles the case where the mantissa is already zero or the maximum negative value before normalization.

**Post-Rounding Overflow:**
- After adding the rounding constant, if the mantissa overflows (sign bit changes from 0 to 1 for positive numbers): `IF (ISC.EQ.1.OR.MC(1).LT.128) GO TO 500`
- The condition `MC(1).LT.128` checks if bit 7 of byte 1 is 0 (positive). If the original number was positive (`ISC=0`) and the mantissa now has bit 7 set (`MC(1) >= 128`), overflow occurred.
- Recovery: right-shift mantissa by 1 and increment exponent: `CALL LSHFT(MC,-1,4,0,K,K)` then `EC=EC+1`

**Underflow (EC < 0):**
- Forces clean zero: `EC=0`, all mantissa bytes = 0
- Sets status bit 3 (value 8): `ANSWER(7)=8`
- Sets zero bit (value 2): `ANSWER(7)=ANSWER(7)+2`

**Overflow (EC >= 1024):**
- Forces maximum signed value based on sign:
  - Positive (`ISC=0`): `MC(1)=127`, `MC(2-4)=255` (maximum positive mantissa)
  - Negative (`ISC=1`): `MC(1)=128`, `MC(2-4)=0` (maximum negative mantissa)
- Sets status bit 4 (value 16): `ANSWER(7)=16`
- Clamps exponent to 1023

**Zero Detection After Normalization:**
- After the final mantissa alignment (`CALL LSHFT(MC,-4,4,0,K,K)`), if all bytes are zero:
  - Exponent is cleared: `EC=0`
  - Status byte zero bit is set: `ANSWER(7)=( (ANSWER(7)/4)*4 ) +2` (clears bits 0-1, sets bit 1)
  - This handles the case where normalization produced a true zero.

### NEGATE Edge Case
- **Maximum negative overflow:** When negating the most negative value (sign bit = 1, all other bits = 0), the two's complement operation produces the same value. The overflow check `IF (MOD(REGA(1)/128,2).EQ.IS)` detects this because the sign bit doesn't change. `OVER=IS` stores the original sign (1 for negative overflow).

### SPLIT Edge Cases
- **No error checking:** The routine assumes the 8-byte instruction word is valid. No validation of field values is performed.
- **Field spanning byte boundaries:** Fields FV(4), FV(6), FV(9), and FV(14) span byte boundaries, requiring careful bit extraction from adjacent bytes.

---

## 5. Cross-References

### NEGATE
- **Calls LCOM** (external routine): Performs bitwise complement of all bytes in the register. Signature: `CALL LCOM(REGA,REGA,W)` - complements REGA in-place.
- **Calls TCADD** (in this section): Adds 1 to the complemented register to complete two's complement negation. Signature: `CALL TCADD(REGA,ONE,REGA,W,IC)` where ONE is a W-byte register with value 1 in the LSB.

### NORMAL
- **Calls RMOV** (in this section): Copies mantissa to temporary buffer for pre-normalization check. Signature: `CALL RMOV(MC(1),TMP(1),4)` - copies 4 bytes from MC to TMP.
- **Calls LSHFT** (external routine): Performs left/right shifts on the mantissa. Called three times:
  - `CALL LSHFT(TMP,ISHIFT,4,1,KKK,J)` - pre-normalization shift for all-zeros/ones check
  - `CALL LSHFT(MC,1,4,1,K,K)` - normalization left shift
  - `CALL LSHFT(MC,-1,4,0,K,K)` - post-rounding right shift (denormalize)
  - `CALL LSHFT(MC,-4,4,0,K,K)` - final right alignment
- **Calls TCADD** (in this section): Adds rounding constant to mantissa. Signature: `CALL TCADD(MC,ROUND,MC,4,K)` - 4-byte addition.
- **Calls MOVPRT** (external routine): Moves partial data from MC to ANSWER. Signature: `CALL MOVPRT(MC,1,ANSWER,3,4,7,4)` - copies 4 bytes from MC starting at offset 1 to ANSWER starting at offset 3.

### PAKRG
- **Calls MWRIT** (external routine): Writes packed data from byte-separated register to 16-bit word. Signature: `CALL MWRIT(REG,WRK,0,1,2,1)` - writes 2 bytes from REG to WRK(1,1).

### UNPKRG
- **Calls MREAD** (external routine): Reads packed data from 16-bit word to byte-separated register. Signature: `CALL MREAD(WRK,0,REG,1,1,2)` - reads 2 bytes from WRK(1,1) to REG.

### RMOV, SPLIT, TCADD
- **No cross-references to other SIM100 routines.** These are leaf routines that perform basic operations without calling other simulator functions.

### GLM final

(adv 96s, 8675c)

# Analysis of SIM100.FTN `norm_pack` Section

## 1. Per-Subroutine Reference

### NEGATE
- **Signature**: `SUBROUTINE NEGATE(REGA, W, OVER)`
- **Purpose**: Two's complement negation of a register
- **Inputs**: `REGA(W)` - register to negate (W bytes wide)
- **Outputs**: `REGA(W)` - negated result (in-place), `OVER` - overflow flag
- **AP-120B Operation**: Simulates the hardware's FALU two's complement negation. The AP-120B negates by complementing all bits and adding 1, exactly as coded. Overflow occurs when negating the most negative value.

### NORMAL
- **Signature**: `SUBROUTINE NORMAL(EC, MC, ANSWER, TRUNC, NOCNT)`
- **Purpose**: Normalize, round, and set error/condition bits for floating-point results
- **Inputs**: 
  - `EC` - exponent (2 bytes)
  - `MC(4)` - mantissa (4 bytes = 32 bits)
  - `TRUNC` - truncation flag (1=truncate, 0=round)
  - `NOCNT` - max normalize shifts allowed
- **Outputs**: `ANSWER(7)` - packed result (2 bytes exponent + 4 bytes mantissa + 1 byte status)
- **AP-120B Operation**: Simulates the FPS-100's floating-point normalization pipeline. Models the normalize shifter, rounding adder, exponent adjust logic, overflow/underflow detection, and condition code generation for the 38-bit format (1 sign + 9 exponent + 28 mantissa).

### PAKRG
- **Signature**: `SUBROUTINE PAKRG(REG, DEC)`
- **Purpose**: Pack a 2-byte register into a 16-bit integer
- **Inputs**: `REG(2)` - 2-byte register
- **Outputs**: `DEC` - 16-bit integer
- **AP-120B Operation**: Converts the simulator's internal byte-array representation back to a FORTRAN integer for use in arithmetic operations.

### RMOV
- **Signature**: `SUBROUTINE RMOV(SRC, DST, W)`
- **Purpose**: Copy register to register
- **Inputs**: `SRC(W)` - source register, `W` - width in bytes
- **Outputs**: `DST(W)` - destination register
- **AP-120B Operation**: Simulates data movement between any AP-120B registers (S-pad, DPX, DPY, etc.) via the internal data paths.

### SPLIT
- **Signature**: `SUBROUTINE SPLIT(REG, FV)`
- **Purpose**: Decode 8-byte instruction word into 24 control fields
- **Inputs**: `REG(8)` - instruction word as 8 bytes
- **Outputs**: `FV(24)` - 24 decoded field values
- **AP-120B Operation**: This is the instruction decoder for the AP-120B. The 24 fields directly control all functional units: data routing, ALU operations, memory addressing, multiplier, shifter, and display.

### TCADD
- **Signature**: `SUBROUTINE TCADD(REGA, REGB, REGC, W, CARRY)`
- **Purpose**: Two's complement addition of multi-byte registers
- **Inputs**: `REGA(W)`, `REGB(W)` - operands, `W` - width in bytes
- **Outputs**: `REGC(W)` - sum, `CARRY` - final carry
- **AP-120B Operation**: Simulates the AP-120B's integer addition in the FALU. The byte-by-byte addition with carry propagation models the hardware's ripple-carry adder.

### UNPKRG
- **Signature**: `SUBROUTINE UNPKRG(DEC, REG)`
- **Purpose**: Unpack a 16-bit integer into a 2-byte register
- **Inputs**: `DEC` - 16-bit integer
- **Outputs**: `REG(2)` - 2-byte register
- **AP-120B Operation**: Converts a FORTRAN integer to the simulator's internal byte-array representation for register operations.

## 2. Bit-Level Semantics

### Sign Bit Extraction
`MOD(REGA(1)/128, 2)` extracts the sign bit (bit 7) of the most significant byte. In the AP-120B's 38-bit format, this corresponds to the sign bit of the mantissa.

### Normalization Detection
`MOD(MC(1)/64, 4)` extracts bits 7-6 of the mantissa's most significant byte. The AP-120B considers a number normalized when these two bits are "01" (positive) or "10" (negative).

### Rounding Constants
The rounding constants `RNDCON(1-4)` = `(7, 8, 0, 15)` encode:
- Index 1 (positive, round): `7` = binary `00000111` - adds 1 to the bit just right of LSB
- Index 2 (negative, round): `8` = binary `00001000` - adds 1 to the bit just right of LSB
- Index 3 (positive, truncate): `0` = binary `00000000` - no rounding
- Index 4 (negative, truncate): `15` = binary `00001111` - forces truncation toward negative infinity

### Instruction Word Bit Layout
The 64-bit instruction word (8 bytes) is decoded into 24 fields according to the canonical FPS-7319 specification:
- Byte 1: DF(1) + SOPF(3) + SHF(2) + SPSF(2)
- Byte 2: SPDF(4) + FADDF(2) + A1F(2)
- Byte 3: A2F(3) + CONDF(3) + DISPF(2)
- Byte 4: DISPF(3) + DPXF(2) + DPYF(2) + DPBSF(1)
- Byte 5: XRF(2) + YRF(2) + XWF(3) + YWF(1)
- Byte 6: YWF(2) + FMF(3) + M1F(2) + M2F(1)
- Byte 7: M2F(1) + MIF(2) + MAF(2) + DPAF(2) + TMAF(1)
- Byte 8: TMAF(2) + (unused bits)

## 3. State and Side Effects

### NEGATE
- **Reads**: `REGA` (input register)
- **Writes**: `REGA` (negated result), `OVER` (overflow flag)
- **Calls**: `LCOM`, `TCADD`
- **AP-120B State**: Modifies a working register; overflow detection mirrors the FALU's sign flag

### NORMAL
- **Reads**: `EC` (exponent), `MC` (mantissa), `TRUNC`, `NOCNT`
- **Writes**: `ANSWER(7)` (complete result)
- **Local state**: `ISC` (sign bit), `NCNT` (shift counter)
- **Calls**: `RMOV`, `LSHFT`, `TCADD`, `MOVPRT`
- **AP-120B State**: Models the complete floating-point pipeline, including the normalize shifter, rounding adder, and condition logic

### PAKRG
- **Reads**: `REG(2)` - 2-byte register
- **Writes**: `DEC` - 16-bit integer
- **Calls**: `MWRIT`
- **AP-120B State**: No architectural state modified; utility conversion

### RMOV
- **Reads**: `SRC(W)` - source register
- **Writes**: `DST(W)` - destination register
- **AP-120B State**: Simulates register-to-register data movement (S-pad, DPX, DPY, etc.)

### SPLIT
- **Reads**: `REG(8)` - instruction word
- **Writes**: `FV(24)` - decoded fields
- **AP-120B State**: The instruction decoder controls all functional units through the 24 fields

### TCADD
- **Reads**: `REGA(W)`, `REGB(W)` - operands
- **Writes**: `REGC(W)` - sum, `CARRY` - final carry
- **AP-120B State**: Simulates the FALU's adder; carry output feeds into condition logic

### UNPKRG
- **Reads**: `DEC` - 16-bit integer
- **Writes**: `REG(2)` - 2-byte register
- **Calls**: `MREAD`
- **AP-120B State**: No architectural state modified; utility conversion

## 4. AP-120B-Specific Edge Cases

### Floating-Point Format (38-bit)
The AP-120B uses a 38-bit floating-point format:
- 1 sign bit (bit 37)
- 9 exponent bits (bits 36-28), biased by 256
- 28 mantissa bits (bits 27-0), normalized with hidden bit

This format shows up in NORMAL:
- `EC` range check: `IF (EC.LT.1024)` - exponent must be < 1024 (only 9 bits used in hardware)
- Underflow: `IF (EC.GE.0)` - exponent went negative
- Overflow: `IF (EC.LT.1024)` - exponent exceeded maximum (1023 = all 1s)

### Zero Detection
NORMAL checks for all-zeros or all-ones mantissa:
```fortran
IALL=0
IF (TMP(1).NE.0) IALL=255
```
This detects positive or negative zero, which the AP-120B forces to a clean zero representation.

### Overflow Saturation
On overflow, the AP-120B saturates to maximum representable value:
- Positive max: `MC(1)=127, MC(2-4)=255` (binary `01111111 11111111 11111111 11111111`)
- Negative max: `MC(1)=128, MC(2-4)=0` (binary `10000000 00000000 00000000 00000000`)

### Denormalization After Rounding
If rounding causes mantissa overflow (all ones becoming all zeros with carry), NORMAL denormalizes:
```fortran
IF (ISC.EQ.1.OR.MC(1).LT.128) GO TO 500
CALL LSHFT(MC,-1,4,0,K,K)
EC=EC+1
```
This right-shifts mantissa and increments exponent, handling the case where rounding caused carry into sign bit.

### Convergent Rounding
NORMAL implements round-to-nearest-even for both positive and negative numbers:
- Positive: 0.0 to 0.5 rounds toward 0.0, 0.5+ to 1.0- rounds toward 1.0
- Negative: 0.0 to -0.5 rounds toward 0.0, -0.5+ to -1.0 rounds toward -1.0

## 5. Cross-References

### Calls to Other SIM100 Routines

| Caller | Routine Called | Purpose |
|--------|---------------|---------|
| NEGATE | `LCOM` | Complement all bits of register (bitwise NOT) |
| NEGATE | `TCADD` | Add 1 for two's complement negation |
| NORMAL | `RMOV` | Copy mantissa for zero/all-ones check |
| NORMAL | `LSHFT` | Left/right shift mantissa for normalization |
| NORMAL | `TCADD` | Add rounding constant to mantissa |
| NORMAL | `MOVPRT` | Move mantissa bytes into result array |
| PAKRG | `MWRIT` | Write bytes from register to integer work array |
| UNPKRG | `MREAD` | Read bytes from integer into register |

### Routines Not in This Section (Referenced)
- **LCOM**: Bitwise complement operation (in `logic` cluster)
- **LSHFT**: Multi-byte shift operation (in `shift` cluster)
- **MOVPRT**: Memory-to-memory byte move (in `memory` cluster)
- **MWRIT**: Write bytes from register to memory (in `memory` cluster)
- **MREAD**: Read bytes from memory to register (in `memory` cluster)

### Cooperative drafts

#### DS coop

# Analysis of SIM100.FTN `norm_pack` Section

## 1. Per-Subroutine Reference

### NEGATE
- **Signature**: `SUBROUTINE NEGATE(REGA, W, OVER)`
- **Purpose**: Two's complement negation of a multi-byte register
- **Inputs**: `REGA(W)` - register to negate (W bytes wide)
- **Outputs**: `REGA(W)` - negated result (in-place), `OVER` - overflow flag
- **AP-120B Operation**: Simulates the hardware's two's complement negation used in the FALU for sign manipulation. The AP-120B performs negation by complementing all bits and adding 1, exactly as coded.
- **Implementation**: 
  1. Creates a constant `ONE(W)` = 1 in least significant byte
  2. Saves original sign bit `IS = MOD(REGA(1)/128, 2)`
  3. Calls `LCOM` to complement all bits
  4. Calls `TCADD` to add 1
  5. Sets `OVER = IS` if sign changed (overflow condition)

### NORMAL
- **Signature**: `SUBROUTINE NORMAL(EC, MC, ANSWER, TRUNC, NOCNT)`
- **Purpose**: Normalize, round, and set error/condition bits for AP-120B floating-point results
- **Inputs**: 
  - `EC` - exponent (2 bytes)
  - `MC(4)` - mantissa (4 bytes = 32 bits)
  - `TRUNC` - truncation flag (1=truncate, 0=round)
  - `NOCNT` - max normalize shifts allowed (0=inhibit, 2=multiply, 40=default)
- **Outputs**: `ANSWER(7)` - packed result (2 bytes exponent + 4 bytes mantissa + 1 byte status)
- **AP-120B Operation**: Simulates the FPS-100's floating-point normalization and rounding hardware. The AP-120B normalizes results by left-shifting the mantissa until the two high bits are "01" or "10" (indicating proper alignment), decrementing the exponent for each shift.
- **Rounding**: Implements convergent rounding (round-to-nearest-even) by adding a rounding constant:
  - Positive: `0,0,0,7` (binary `...0111`)
  - Negative: `0,0,0,8` (binary `...1000`)
  - Truncate positive: `0,0,0,0`
  - Truncate negative: `0,0,0,15` (binary `...1111`)
- **Status bits** in `ANSWER(7)`:
  - Bit 0 (1): Negative
  - Bit 1 (2): Zero
  - Bit 3 (8): Exponent underflow
  - Bit 4 (16): Exponent overflow

### PAKRG
- **Signature**: `SUBROUTINE PAKRG(REG, DEC)`
- **Purpose**: Pack a 2-byte register into a 16-bit integer
- **Inputs**: `REG(2)` - 2-byte register
- **Outputs**: `DEC` - 16-bit integer result
- **AP-120B Operation**: Converts the simulator's internal byte-array representation back to a FORTRAN integer for use in arithmetic operations.
- **Implementation**: Calls `MWRIT` to write 2 bytes from REG into a 1x1 work array, then extracts the integer.

### RMOV
- **Signature**: `SUBROUTINE RMOV(SRC, DST, W)`
- **Purpose**: Copy one register to another
- **Inputs**: `SRC(W)` - source register, `W` - width in bytes
- **Outputs**: `DST(W)` - destination register
- **AP-120B Operation**: Simulates register-to-register data paths in the AP-120B, such as moving data between S-pad registers or from DPX/DPY to working registers.
- **Implementation**: Simple byte-by-byte copy loop.

### SPLIT
- **Signature**: `SUBROUTINE SPLIT(REG, FV)`
- **Purpose**: Decode an 8-byte instruction word into 24 control fields
- **Inputs**: `REG(8)` - instruction word as 8 bytes
- **Outputs**: `FV(24)` - 24 decoded field values
- **AP-120B Operation**: This is the instruction decoder. The AP-120B's 64-bit instruction word (8 bytes) is split into 24 control fields that drive the various functional units. This subroutine performs the bit extraction that the hardware's instruction register and decoder would do.
- **Field mapping** (FV index → AP-120B control field):
  - FV(1): DF (Destination Field)
  - FV(2): SOPF (Source Operand Field)
  - FV(3): SHF (Shift Field)
  - FV(4): SPSF (Source Pad Select Field)
  - FV(5): SPDF (Source Pad Data Field)
  - FV(6): FADDF (FADD Field)
  - FV(7): A1F (A1 Field)
  - FV(8): A2F (A2 Field)
  - FV(9): CONDF (Condition Field)
  - FV(10): DISPF (Display Field)
  - FV(11): DPXF (DPX Field)
  - FV(12): DPYF (DPY Field)
  - FV(13): DPBSF (DPBS Field)
  - FV(14): XRF (X Register Field)
  - FV(15): YRF (Y Register Field)
  - FV(16): XWF (X Write Field)
  - FV(17): YWF (Y Write Field)
  - FV(18): FMF (FM Field)
  - FV(19): M1F (M1 Field)
  - FV(20): M2F (M2 Field)
  - FV(21): MIF (MI Field)
  - FV(22): MAF (MA Field)
  - FV(23): DPAF (DPA Field)
  - FV(24): TMAF (TMA Field)

### TCADD
- **Signature**: `SUBROUTINE TCADD(REGA, REGB, REGC, W, CARRY)`
- **Purpose**: Two's complement addition of multi-byte registers
- **Inputs**: `REGA(W)`, `REGB(W)` - operands, `W` - width in bytes
- **Outputs**: `REGC(W)` - sum, `CARRY` - final carry out
- **AP-120B Operation**: Simulates the AP-120B's integer addition in the FALU. The byte-by-byte addition with carry propagation models the hardware's ripple-carry adder.
- **Implementation**: Adds from least significant byte to most significant byte, propagating carry. Each byte addition checks for overflow past 255.

### UNPKRG
- **Signature**: `SUBROUTINE UNPKRG(DEC, REG)`
- **Purpose**: Unpack a 16-bit integer into a 2-byte register
- **Inputs**: `DEC` - 16-bit integer
- **Outputs**: `REG(2)` - 2-byte register
- **AP-120B Operation**: Converts a FORTRAN integer to the simulator's internal byte-array representation for register operations.
- **Implementation**: Calls `MREAD` to read 2 bytes from the integer into REG.

## 2. Bit-Level Semantics

### Byte Array Representation
All AP-120B registers are stored as arrays of 8-bit bytes (0-255). This avoids FORTRAN sign-bit issues on PDP-11. A 38-bit floating-point number would be stored as:
- 2 bytes for exponent (16 bits, but only 10 used)
- 4 bytes for mantissa (32 bits, but only 28 used)
- 1 byte for status (8 bits)

### Sign Bit Extraction
`MOD(REGA(1)/128, 2)` extracts the sign bit (bit 7) of the most significant byte. In the AP-120B's 38-bit format, this corresponds to the sign bit of the mantissa.

### Normalization Detection
`MOD(MC(1)/64, 4)` extracts bits 7-6 of the mantissa's most significant byte. The AP-120B considers a number normalized when these two bits are "01" (positive) or "10" (negative).

### Rounding Constants
The rounding constants `RNDCON(1-4)` = `(7, 8, 0, 15)` encode:
- Index 1 (positive, round): `7` = binary `00000111` - adds 1 to the bit just right of LSB
- Index 2 (negative, round): `8` = binary `00001000` - adds 1 to the bit just right of LSB (different pattern for negative)
- Index 3 (positive, truncate): `0` = binary `00000000` - no rounding
- Index 4 (negative, truncate): `15` = binary `00001111` - forces truncation toward negative infinity

### Instruction Word Bit Layout
The 64-bit instruction word (8 bytes) is decoded as follows:
- Byte 1: DF(1) + SOPF(3) + SHF(2) + SPSF(2)
- Byte 2: SPDF(4) + FADDF(2) + A1F(2)
- Byte 3: A2F(3) + CONDF(3) + DISPF(2)
- Byte 4: DISPF(3) + DPXF(2) + DPYF(2) + DPBSF(1)
- Byte 5: XRF(2) + YRF(2) + XWF(3) + YWF(1)
- Byte 6: YWF(2) + FMF(3) + M1F(2) + M2F(1)
- Byte 7: M2F(1) + MIF(2) + MAF(2) + DPAF(2) + TMAF(1)
- Byte 8: TMAF(2) + (unused bits)

## 3. State and Side Effects

### NEGATE
- **Reads**: `REGA` (input register)
- **Writes**: `REGA` (negated result), `OVER` (overflow flag)
- **Calls**: `LCOM`, `TCADD`
- **AP-120B State**: Modifies a working register; overflow detection mirrors the AP-120B's FALU status flags

### NORMAL
- **Reads**: `EC` (exponent), `MC` (mantissa), `TRUNC`, `NOCNT`
- **Writes**: `ANSWER(7)` (complete result)
- **Local state**: `ISC` (sign bit), `NCNT` (shift counter)
- **Calls**: `RMOV`, `LSHFT`, `TCADD`, `MOVPRT`
- **AP-120B State**: This is the core floating-point normalization pipeline. It models:
  - The normalize shifter (left shifts mantissa)
  - The rounding adder
  - The exponent adjust logic
  - The overflow/underflow detection
  - The condition code generation

### PAKRG
- **Reads**: `REG(2)` - 2-byte register
- **Writes**: `DEC` - 16-bit integer
- **Calls**: `MWRIT`
- **AP-120B State**: No architectural state modified; utility conversion

### RMOV
- **Reads**: `SRC(W)` - source register
- **Writes**: `DST(W)` - destination register
- **AP-120B State**: Simulates data movement between any registers (S-pad, DPX, DPY, etc.)

### SPLIT
- **Reads**: `REG(8)` - instruction word
- **Writes**: `FV(24)` - decoded fields
- **AP-120B State**: This is the instruction decoder. The 24 fields directly control:
  - Data routing (DF, SOPF, SPSF, SPDF)
  - ALU operations (FADDF, A1F, A2F, CONDF)
  - Memory addressing (DPXF, DPYF, DPBSF, XRF, YRF, XWF, YWF)
  - Multiplier (FMF, M1F, M2F, MIF, MAF, DPAF, TMAF)
  - Shifter (SHF)
  - Display/output (DISPF)

### TCADD
- **Reads**: `REGA(W)`, `REGB(W)` - operands
- **Writes**: `REGC(W)` - sum, `CARRY` - final carry
- **AP-120B State**: Simulates the FALU's adder; carry output would feed into condition logic

### UNPKRG
- **Reads**: `DEC` - 16-bit integer
- **Writes**: `REG(2)` - 2-byte register
- **Calls**: `MREAD`
- **AP-120B State**: No architectural state modified; utility conversion

## 4. AP-120B-Specific Edge Cases

### Floating-Point Format (38-bit)
The AP-120B uses a 38-bit floating-point format:
- 1 sign bit (bit 37)
- 9 exponent bits (bits 36-28), biased by 256
- 28 mantissa bits (bits 27-0), normalized with hidden bit

In NORMAL, this shows up as:
- `EC` range check: `IF (EC.LT.1024)` - exponent must be < 1024 (10 bits, but only 9 used in hardware)
- Underflow: `IF (EC.GE.0)` - exponent went negative
- Overflow: `IF (EC.LT.1024)` - exponent exceeded maximum (1023 = all 1s)

### Zero Detection
NORMAL checks for all-zeros or all-ones mantissa:
```fortran
IALL=0
IF (TMP(1).NE.0) IALL=255
```
This detects the case where the mantissa is either all zeros (positive zero) or all ones (negative zero after complement). The AP-120B forces these to a clean zero.

### Overflow Saturation
On overflow, the AP-120B saturates to the maximum representable value:
- Positive max: `MC(1)=127, MC(2-4)=255` (largest positive mantissa)
- Negative max: `MC(1)=128, MC(2-4)=0` (largest negative mantissa, which is `10000000...`)

### Denormalization After Rounding
If rounding causes the mantissa to overflow (all ones becoming all zeros with carry), NORMAL denormalizes:
```fortran
IF (ISC.EQ.1.OR.MC(1).LT.128) GO TO 500
CALL LSHFT(MC,-1,4,0,K,K)
EC=EC+1
```
This right-shifts the mantissa and increments the exponent, handling the case where rounding caused a carry into the sign bit.

### Instruction Word Encoding
The SPLIT routine decodes the 64-bit instruction word into 24 fields. The bit allocations match the FPS-7319 Programmer's Reference:
- Fields range from 1 to 4 bits
- Total: 1+3+2+2+4+2+2+3+3+2+3+2+2+1+2+2+3+1+2+2+1+2+2+2+1+2 = 64 bits

## 5. Cross-References

### Calls to Other SIM100 Routines

| Caller | Routine Called | Purpose |
|--------|---------------|---------|
| NEGATE | `LCOM` | Complement all bits of register (bitwise NOT) |
| NEGATE | `TCADD` | Add 1 for two's complement negation |
| NORMAL | `RMOV` | Copy mantissa to temporary for zero/all-ones check |
| NORMAL | `LSHFT` | Left/right shift mantissa for normalization/denormalization |
| NORMAL | `TCADD` | Add rounding constant to mantissa |
| NORMAL | `MOVPRT` | Move mantissa bytes into result array |
| PAKRG | `MWRIT` | Write 2 bytes from register to integer work array |
| UNPKRG | `MREAD` | Read 2 bytes from integer into register |

### Routines Not in This Section (Referenced)
- **LCOM**: Bitwise complement operation (in `logic` cluster)
- **LSHFT**: Multi-byte shift operation (in `shift` cluster)
- **MOVPRT**: Memory-to-memory byte move (in `memory` cluster)
- **MWRIT**: Write bytes from register to memory (in `memory` cluster)
- **MREAD**: Read bytes from memory to register (in `memory` cluster)

#### GLM coop

# AP-120B Microarchitecture Analysis of SIM100.FTN Section

## 1. Per-subroutine reference

### NEGATE
- **Signature:** `SUBROUTINE NEGATE(REGA,W,OVER)`
- **Purpose:** Perform two's complement negation on a register
- **Inputs/Outputs:** REGA (W-byte register), W (register width in bytes), OVER (overflow flag)
- **AP-120B operation:** Simulates the two's complement negation operation; complements all bits using LCOM and adds one using TCADD, with overflow detection if sign bit doesn't change

### NORMAL
- **Signature:** `SUBROUTINE NORMAL(EC,MC,ANSWER,TRUNC,NOCNT)`
- **Purpose:** Normalize, round, and set error/condition bits for floating-point numbers
- **Inputs/Outputs:** EC (exponent), MC (4-byte mantissa), ANSWER (result and status flags), TRUNC (truncate flag), NOCNT (max normalize shifts)
- **AP-120B operation:** Simulates the FPU normalization and rounding process; handles mantissa normalization, convergent rounding, and detects overflow/underflow conditions

### PAKRG
- **Signature:** `SUBROUTINE PAKRG(REG,DEC)`
- **Purpose:** Pack a 2-byte register into a 16-bit integer
- **Inputs/Outputs:** REG (2-byte register), DEC (16-bit integer)
- **AP-120B operation:** Simulates register packing; combines two bytes into one word using MWRIT

### RMOV
- **Signature:** `SUBROUTINE RMOV (SRC,DST,W)`
- **Purpose:** Register copy operation
- **Inputs/Outputs:** SRC (source register), DST (destination register), W (width in bytes)
- **AP-120B operation:** Simulates register-to-register move; copies W bytes from SRC to DST sequentially

### SPLIT
- **Signature:** `SUBROUTINE SPLIT (REG,FV)`
- **Purpose:** Decode an 8-byte instruction word into 24 opcode fields
- **Inputs/Outputs:** REG (8-byte instruction word), FV (24-field values)
- **AP-120B operation:** Simulates opcode decoding; extracts 24 opcode fields from instruction word using bitwise extraction

### TCADD
- **Signature:** `SUBROUTINE TCADD (REGA,REGB,REGC,W,CARRY)`
- **Purpose:** Two's complement addition
- **Inputs/Outputs:** REGA, REGB (operands), REGC (result), W (width in bytes), CARRY (carry-out)
- **AP-120B operation:** Simulates the two's complement adder; performs byte-by-byte addition with carry propagation from LSB to MSB

### UNPKRG
- **Signature:** `SUBROUTINE UNPKRG(DEC,REG)`
- **Purpose:** Unpack a 16-bit integer into a 2-byte register
- **Inputs/Outputs:** DEC (16-bit integer), REG (2-byte register)
- **AP-120B operation:** Simulates word unpacking; splits a 16-bit value into two bytes using MREAD

## 2. Bit-level semantics

### NEGATE
- `MOD(REGA(1)/128,2)` extracts the sign bit (bit 7 of byte 1)
- `CALL LCOM(REGA,REGA,W)` complements all bits of the register
- `CALL TCADD(REGA,ONE,REGA,W,IC)` adds one to the complemented register
- Overflow check compares original and new sign bits after negation

### NORMAL
- `MOD(MC(1)/64,4)` extracts the highest two bits of the mantissa (bits 6-7)
- `MOD(MC(1)/128,2)` extracts the sign bit (bit 7 of byte 1)
- Rounding constants based on sign and truncate flag:
  - Positive, round: 000007 (binary 00000111)
  - Positive, truncate: 000000 (binary 00000000)
  - Negative, round: 000010 (binary 00001010)
  - Negative, truncate: 000015 (binary 00001111)
- Exponent stored as ANSWER(1-2): 16-bit value (ANSWER(1) = high byte, ANSWER(2) = low byte)
- Mantissa stored as ANSWER(3-6): 32 bits (4 bytes)

### SPLIT
- Field extraction using bitwise operations:
  - FV(1) = bit 7 of byte 1 (sign bit)
  - FV(2) = bits 4-7 of byte 1
  - FV(3) = bits 2-5 of byte 1
  - FV(4) = bits 0-3 of byte 1 + bits 6-7 of byte 2
  - FV(5) = bits 0-3 of byte 2 + bit 4-7 excluding bits 6-7
  - ... continues for all 24 fields

### TCADD
- Byte-by-byte addition from least to most significant (lines 100 loop)
- `REGC(J)=REGA(J)+REGB(J)+CARRY` performs addition with carry
- `IF (REGC(J).LT.256) GO TO 100` checks if carry occurred
- `REGC(J)=REGC(J)-256` adjusts byte value if carry occurred
- `CARRY=1` propagates carry to next byte

## 3. State and side effects

### NEGATE
- **Reads from:** REGA (general-purpose register)
- **Writes to:** REGA (general-purpose register), OVER (overflow flag)
- **AP-120B state:** REGA represents general-purpose register; OVER represents overflow flag

### NORMAL
- **Reads from:** EC (floating-point exponent), MC (floating-point mantissa)
- **Writes to:** ANSWER(7) (status flags), MC (mantissa), EC (exponent)
- **AP-120B state:** EC represents floating-point exponent; MC represents 32-bit mantissa; ANSWER represents normalized result (ANSWER(1-2): exponent, ANSWER(3-6): mantissa, ANSWER(7): status flags)

### PAKRG
- **Reads from:** REG (2-byte register)
- **Writes to:** DEC (16-bit integer)
- **AP-120B state:** REG represents register in byte-separated form; DEC represents packed 16-bit word

### RMOV
- **Reads from:** SRC (source register)
- **Writes to:** DST (destination register)
- **AP-120B state:** SRC and DST represent general-purpose registers

### SPLIT
- **Reads from:** REG (instruction word)
- **Writes to:** FV (24 opcode fields)
- **AP-120B state:** REG represents instruction word; FV represents decoded opcode fields

### TCADD
- **Reads from:** REGA, REGB (operand registers)
- **Writes to:** REGC (result register), CARRY (carry flag)
- **AP-120B state:** REGA, REGB, REGC represent general-purpose registers; CARRY represents carry flag

### UNPKRG
- **Reads from:** DEC (16-bit integer)
- **Writes to:** REG (2-byte register)
- **AP-120B state:** DEC represents word; REG represents register in byte-separated form

## 4. AP-120B-specific edge cases

### NEGATE
- Overflow detection: if sign bit doesn't change after negation, OVER flag is set to the original sign bit value (line 10)

### NORMAL
- All-zeros or all-ones mantissa forces clean floating-point zero (lines 250-300)
- Convergent rounding: positive numbers 0.0-0.5 go to 0.0, 0.5+ go to 1.0-; negative numbers 0.0 to -0.5 go to 0.0, -0.5+ go to -1.0
- Mantissa overflow after adding rounding constant requires right shift (lines 500-510)
- Underflow: if EC < 0, forces clean zero and sets error bit (ANSWER(7) = 8, bit 3)
- Overflow: if EC >= 1024, sets error bit and forces signed maximum value (ANSWER(7) = 16, bit 4)
- Zero detection: if all mantissa bytes are zero after normalization, sets zero flag (bit 2) and clears exponent (lines 1010-1020)

### SPLIT
- No specific edge cases noted in the code

The AP-120B 38-bit float format (1 sign + 9 exponent + 28 mantissa) shows up in NORMAL:
- Sign bit extracted via `MOD(MC(1)/128,2)` (line 410)
- Exponent stored as 11-bit value in EC, normalized to ANSWER(1-2) (lines 1010, 1020)
- Mantissa is 32 bits but only 28 bits are significant after normalization (line 1020)

## 5. Cross-references

### NEGATE
- Calls LCOM - performs bitwise complement operation
- Calls TCADD - performs two's complement addition to complete negation

### NORMAL
- Calls RMOV - moves register contents before normalization (line 400)
- Calls LSHFT - performs left/right shifts for normalization (lines 300, 400)
- Calls TCADD - performs addition of rounding constant (line 410)
- Calls MOVPRT - moves partial data to format result (line 1010)

### PAKRG
- Calls MWRIT - writes packed data from 2-byte register to 16-bit word

### UNPKRG
- Calls MREAD - reads packed data from 16-bit word to 2-byte register

### RMOV, SPLIT, TCADD
- No cross-references within this section


---

## Cluster: `load_tm_intr` (lines 3976-4910)

**LODINP (load module), TMROM (table memory ROM), INTRPT, CLOCK**

### DeepSeek final

(adv 45s, 9790c)

Looking at this code section, I need to provide a thorough analysis of the AP-120B microarchitecture semantics. Let me examine each subroutine carefully.

## 1. Per-Subroutine Reference

### LODINP (Load Module)

**Signature:** `SUBROUTINE LODINP (ITTI,ITTO)`

**Purpose:** Reads APLOAD load module output into APSIM's simulated memories (PS and MD). This simulates the AP-120B's program loading mechanism.

**Inputs/Outputs:**
- Input: `ITTI` - input TTY unit, `ITTO` - output TTY unit
- Reads from file unit `ISL=9`
- Writes to PS memory via `PSMEM` and MD memory via `MDMEM`

**AP-120B Operation Simulated:** The AP-120B's program loading mechanism where:
- Code blocks (type 1) are loaded into Program Source (PS) memory or Main Data (MD) memory
- Initialized values (type 3) are loaded into MD memory
- The MAE (Memory Address Extension) register selects MD pages (0-2)
- PS memory stores 64-bit instruction words (two 32-bit halves)
- MD memory stores 38-bit floating-point data words

### TMROM (Table Memory ROM)

**Signature:** `SUBROUTINE TMROM`

**Purpose:** Initializes the Table Memory (TM) with precomputed coefficients for FFT and trigonometric functions.

**Inputs/Outputs:** None (pure initialization)

**AP-120B Operation Simulated:** Initializes the AP-120B's Table Memory, which contains:
- 64-point FFT coefficients (TM indices 1-64)
- 301 trigonometric function coefficients (TM indices 65-365)
- 147 words of TMRAM (TM indices 366-512)

The TM layout maps to AP-120B hardware addresses:
- FFT Table: 0-4095
- Function Coefficients: 4096-4396
- TMRAM: 8192+

### INTRPT (Interrupt Handler)

**Signature:** `SUBROUTINE INTRPT (MODE, DEVICE)`

**Purpose:** Manages the AP-120B's interrupt system with three modes: set, query, and clear.

**Inputs/Outputs:**
- Input: `MODE` (1=set, 2=query, 3=clear), `DEVICE` (device index for mode 1)
- Output: `DEVICE` (interrupt type for mode 2, device index for mode 3)

**AP-120B Operation Simulated:** The AP-120B's interrupt priority system:
- Trap interrupts (INTTYP(1))
- I/O interrupts (INTTYP(2)) with 16 device levels
- Exception interrupts (overflow, underflow, divide by zero)
- Fatal interrupts (SRAO - Source Register Address Overflow)
- Universal interrupt inhibit bit in APSTAT2

### CLOCK (Real-Time Clock)

**Signature:** `SUBROUTINE CLOCK (FIX, SET, ELAPSE, CCTR, CCST, CCTL, INTRPT)`

**Purpose:** Simulates the FPS-100 real-time clock.

**Inputs/Outputs:**
- Input: `FIX` (fix mode flag), `SET` (run bit transition), `ELAPSE` (elapsed microseconds)
- Input/Output: `CCTR` (clock counter), `CCST` (clock set), `CCTL` (clock control)
- Output: `INTRPT` (interrupt flag)

**AP-120B Operation Simulated:** The AP-120B's clock subsystem:
- Clock Counter Register (CCTR): 16-bit counter
- Clock Set Register (CCST): reload value
- Clock Control Register (CCTL): control bits including:
  - CRN (bit 0): run bit
  - IRATE (bits 1-4): rate selection (0-14 internal, 15 external)
  - CMO (bit 5): mode (0=single, 1=repeat)
  - UD (bit 6): up/down count direction
  - INTC (bit 0 of CCTL(1)): interrupt enable
  - DNE (bit 1 of CCTL(1)): done flag
  - CERR (bit 7 of CCTL(1)): clock error

## 2. Bit-Level Semantics

### LODINP Code Loading (Lines ~5470-5600)

The code handles packing of 16-bit host words into 32-bit AP-120B instruction words:

```fortran
HOLD=IRSHFT(BUFFER(II),16)  ! Extract left 16 bits
HOLD=ILSHFT(BUFFER(II),16)  ! Shift left to clear upper bits
HOLD=IRSHFT(HOLD,16)        ! Extract right 16 bits
```

This simulates the AP-120B's 32-bit instruction word format, where each instruction is stored as two 16-bit halves in the host system.

### MD Memory Loading (Lines ~5570-5600)

```fortran
CALL UNPKRG (BUFFER(I),REG(3))  ! Unpack first 16-bit value
CALL UNPKRG (BUFFER(I+1),REG(5)) ! Unpack second 16-bit value
```

This simulates the AP-120B's 38-bit data word format, where two 16-bit host words are combined into one 38-bit floating-point word. The `UNPKRG` routine handles the conversion from host format to AP-120B format.

### Clock Rate Calculation (CLOCK line ~90)

```fortran
IRATE = MOD(CCTL(2)/2,16)
IF (ABS (AMOD(ELAPSE,FLOAT(2**IRATE))) .GT. .00001) RETURN
```

This simulates the AP-120B's clock divider chain, where IRATE selects a power-of-2 division of the master clock period. The clock ticks when elapsed time is an integer multiple of 2^IRATE microseconds.

## 3. State and Side Effects

### LODINP State

**Reads/Writes:**
- `/MDRM/` - MD array (512x3), PAGNUM, PAGSIZ
- `/IORM/` - IODEV array (64x3), IOSIZE
- `PG0` - initial MAE value (saved/restored)
- `PGCRNT` - current MD page selection

**AP-120B State Represented:**
- MD(512,3): Main Data memory, 3 pages of 512 words each
- MAE (Memory Address Extension): selects which MD page is active
- PS memory: Program Source memory (accessed via PSMEM)

### TMROM State

**Writes:**
- `/TMRM/` - TM array (512x3), RAMSIZ, TRIGSZ, HFFTSZ, SFFTSZ, RAMBAS

**AP-120B State Represented:**
- TM(512,3): Table Memory, 512 entries with 3 fields each (likely sign, exponent, mantissa for 38-bit format)
- The three fields per entry correspond to the AP-120B's 38-bit floating-point format: 1 sign + 9 exponent + 28 mantissa

### INTRPT State

**Reads/Writes:**
- `/IORM/` - INTTYP(2), IOINT(16), IOBKPT(6,2), NIOBPT, TMSPEC(6)
- `STATUS(2)` - APSTAT register
- `STAT2(2)` - APSTAT2 register
- `IMASK(2)` - Interrupt mask register

**AP-120B State Represented:**
- APSTAT: Contains exception flags (OVF, UNF, DIVZ in bits 5-7 of STATUS(1))
- APSTAT2: Contains interrupt control bits:
  - Bit 3: Universal interrupt inhibit
  - Bit 4: Trap enable
  - Bit 5: Fatal enable
  - Bit 6: Exception enable
  - Bit 7: I/O enable
- IMASK: 16-bit interrupt mask for I/O devices
- INTTYP: Interrupt type flags (trap and I/O)
- IOINT: Per-device interrupt pending flags

### CLOCK State

**Reads/Writes:**
- CCTR(2): Clock counter (16-bit)
- CCST(2): Clock set register
- CCTL(2): Clock control register

**AP-120B State Represented:**
- CCTR: 16-bit up/down counter
- CCST: Reload value for repeat mode
- CCTL: Control register with:
  - INTC (bit 0): Interrupt on count
  - DNE (bit 1): Done flag
  - CERR (bit 7): Clock error (set when DNE already set)
  - CRN (bit 0 of CCTL(2)): Run bit
  - IRATE (bits 1-4): Rate selection
  - CMO (bit 5): Mode (0=single, 1=repeat)
  - UD (bit 6): Up/down direction

## 4. AP-120B-Specific Edge Cases

### 38-bit Floating-Point Format

The TMROM data shows the 38-bit format structure:
- Field 1 (TM(*,1)): Typically 500-521 range, representing the sign+exponent field
- Field 2 (TM(*,2)): 1024-3071 range, representing high-order mantissa bits
- Field 3 (TM(*,3)): -32768 to 32767 range, representing low-order mantissa bits

For example, TM(1,1)=513, TM(1,2)=1024, TM(1,3)=0 represents:
- Sign: 0 (positive, since 513 is even)
- Exponent: 9 bits (513 = 0x201, exponent = 0x201 >> 1 = 0x100 = 256)
- Mantissa: 28 bits (1024 << 16 + 0 = 0x4000000)

### Special TMROM Values

- TM(65,1)=512, TM(65,2)=7, TM(65,3)=-1: This appears to be a special marker or end-of-table indicator
- TM(290,1)=512, TM(290,2)=2048, TM(290,3)=36: Contains a non-zero low-order mantissa, suggesting a specific constant
- TM(314,1)=0, TM(314,2)=0, TM(314,3)=0: Zero entry, possibly padding or unused

### Clock Edge Cases

The clock handles several AP-120B-specific conditions:
1. **External clock rate (IRATE=15):** Not implemented, silently treated as rate 0
2. **Underflow/overflow detection:** Checks for all-zeros (countdown) or all-ones (countup)
3. **Clock error (CERR):** Set when DNE already set before new underflow/overflow
4. **Single vs. repeat mode:** Single mode clears run bit; repeat mode reloads from CCST

### Interrupt Priority

The interrupt system implements AP-120B's priority scheme:
- Fatal interrupts (highest priority, bit 2)
- Trap interrupts (bit 1)
- Exception interrupts (bit 4)
- I/O interrupts (lowest priority, bit 8)

The I/O interrupt system uses a priority scheme where lower device indices have higher priority (device 0 is highest).

## 5. Cross-References

### LODINP Calls

1. **`CALL GTFIL (ISL,ITTI,ITTO)`** - Get file unit for loading (external I/O routine)
2. **`CALL MREAD (IODEV,24,REG,IOSIZE,3,6)`** - Read MAE register from I/O device (simulates reading the Memory Address Extension)
3. **`CALL CLFIL (ISL,ITTO)`** - Close load module file
4. **`CALL MWRIT (REG,IODEV,24,IOSIZE,6,3)`** - Write MAE register to I/O device (simulates setting the Memory Address Extension)
5. **`CALL UNPKRG (HOLD,WRK)`** - Unpack 16-bit host word into AP-120B format (converts between host and AP-120B data representations)
6. **`CALL MOVPRT (WRK,1,REG,J,2,8,2)`** - Move partial word (copies unpacked data to register array)
7. **`CALL PSMEM (2,IADDR,REG)`** - Write to Program Source memory (simulates loading instructions into PS)
8. **`CALL MDMEM (2,IADDR,REG)`** - Write to Main Data memory (simulates loading data into MD)
9. **`CALL FPINPT (DBLE (SPFPN(1)),REG)`** - Convert host floating-point to AP-120B 38-bit format

### INTRPT State Dependencies

- Reads `STATUS(2)` and `STAT2(2)` which are managed by APSIM (the main simulator loop)
- Reads `IMASK(2)` which is set by AP-120B I/O instructions
- The `IOBKPT`, `NIOBPT`, and `TMSPEC` arrays in `/IORM/` are declared but not used in this subroutine

### CLOCK State Dependencies

- Uses `CALL TCADD (CCTR,INCR,CCTR,2,UNUSED)` - Two's complement addition (simulates the counter increment/decrement)
- Uses `CALL RMOV (CCST, CCTR, 2)` - Register move (simulates reloading counter from set register)
- These are utility routines from the SIM100 library for AP-120B register operations

The clock's output `INTRPT` is used by APSIM to generate an interrupt in the following cycle, connecting to the INTRPT subroutine's interrupt set mechanism.

### GLM final

(adv 122s, 6633c)

### Structured Analysis of SIM100.FTN: LODINP, TMROM, INTRPT, CLOCK

---

#### **1. Per-Subroutine Reference**
**LODINP**  
- **Signature:** `SUBROUTINE LODINP (ITTI, ITTO)`  
- **Purpose:** Loads APLOAD load modules into simulated AP-120B memories (Program Source/PS and Main Data/MD).  
- **Inputs:**  
  - `ITTI`: Input unit number for load module.  
  - `ITTO`: Output unit number for errors.  
- **Outputs:**  
  - Modifies PS memory (via `PSMEM`) and MD memory (via `MDMEM`).  
  - Updates MAE (Memory Address Extension) register.  
- **AP-120B Operation Simulated:** APLOAD utility loading process. Parses headers for code blocks (PS/MD) and data blocks (integer/real/triple/complex values in MD).  

**TMROM**  
- **Signature:** `SUBROUTINE TMROM`  
- **Purpose:** Initializes Table Memory (TM) with precomputed FFT/trigonometric coefficients.  
- **Inputs:** None (hardcoded `DATA` statements).  
- **Outputs:** Populates `/TMRM/` common block with `TM(512,3)` and sizes (`RAMSIZ=147`, `TRIGSZ=301`, etc.).  
- **AP-120B Operation Simulated:** TM ROM initialization, including 64 FFT coefficients, 301 trig constants, and 147 TMRAM words.  

**INTRPT**  
- **Signature:** `SUBROUTINE INTRPT (MODE, DEVICE)`  
- **Purpose:** Manages AP-120B interrupt system.  
- **Inputs/Outputs:**  
  - `MODE`: 1=set interrupt, 2=query, 3=clear after INTA.  
  - `DEVICE`: I/O index (0-15) for mode 1; output for interrupt type in mode 2/3.  
- **AP-120B Operation Simulated:** Interrupt priority handling (Fatal > Trap > Exception > I/O), mask checking, and conditional interrupt generation in `APSTAT2`.  

**CLOCK**  
- **Signature:** `SUBROUTINE CLOCK (FIX, SET, ELAPSE, CCTR, CCST, CCTL, INTRPT)`  
- **Purpose:** Simulates FPS-100 real-time clock.  
- **Inputs:**  
  - `FIX`: 1 for single-step mode.  
  - `SET`: 1 if CRN (run bit) set.  
  - `ELAPSE`: Elapsed time (µs).  
- **I/O:**  
  - `CCTR(2)`, `CCST(2)`, `CCTL(2)`: Clock registers.  
  - `INTRPT`: Output flag for clock interrupt.  
- **AP-120B Operation Simulated:** Up/down counting, rate selection (`IRATE`), overflow/underflow detection, and interrupt generation via `INTC` bit.  

---

#### **2. Bit-Level Semantics**
**LODINP**  
- **Triple Precision (line 5750):**  
  ```fortran
  REG(2)=IRSH16(BUF(6),12)  ; Extracts high 4 bits of 38-bit FP
  BUF(6)=IAND16(BUF(6),4095) ; Masks to 12-bit mantissa (4095 = 0xFFF).
  ```  
- **PAKFAC Handling (lines 5477-5479):**  
  For 16-bit hosts, extracts left/right 16-bit chunks from 32-bit buffer to simulate 32-bit AP-120B words.  

**TMROM**  
- **38-Bit FP Encoding:**  
  Each TM entry is three 16-bit words:  
  - Word 1: Sign (bit 15) + 9-bit exponent (bits 14-6) + 6-bit mantissa (bits 5-0).  
  - Words 2-3: 28-bit mantissa split into two 16-bit halves.  
  Example: `TM(1)=(513,1024,0)` → Sign=0, Exponent=256, Mantissa=1<<22.  

**INTRPT**  
- **Bit Tests:**  
  ```fortran
  MOD(STAT2(1)/8,2)        ; Universal interrupt inhibit (bit 3)
  MOD(STATUS(2)/32,2)       ; SRAO (fatal interrupt, bit 5)
  MOD(STAT2(2)/16,2)        ; Trap enable (bit 4)
  MOD(STATUS(1)/32,8)       ; OVF/UNF/DIVZ (bits 5-7)
  MOD(STAT2(2)/128,2)       ; I/O interrupt enable (bit 7)
  ```  
- **IMASK Priority:**  
  ```fortran
  MOD(IMASK(1)/2**(8-I),2)  ; Devices 0-7 (IMASK(1) bits 8-15)
  MOD(IMASK(2)/2**(16-I),2) ; Devices 8-15 (IMASK(2) bits 0-7)
  ```  

**CLOCK**  
- **Control Bits:**  
  ```fortran
  MOD(CCTL(2),2)     ; CRN (run, bit 0)
  MOD(CCTL(2)/2,16)  ; IRATE (bits 1-4, 2^IRATE µs/tick)
  MOD(CCTL(2)/64,2)  ; UD (up/down, bit 6)
  MOD(CCTL(2)/32,2)  ; CMO (single/repeat mode, bit 5)
  MOD(CCTL(1),2)     ; INTC (interrupt, bit 0)
  ```  
- **CERR Flag:**  
  ```fortran
  MOD(CCTL(1),128)+128 ; Sets bit 7 while preserving lower bits
  ```  

---

#### **3. State and Side Effects**
**LODINP**  
- **Reads:** `/MDRM/` (MD, PAGNUM), `/IORM/` (IODEV, IOSIZE), `/DUMB/` (BUF).  
- **Writes:** PS/MD memory via `PSMEM`/`MDMEM`, MAE via `MWRIT`.  
- **State:** MD page selection (`PGCRNT`), load buffer (`BUFFER`).  

**TMROM**  
- **Writes:** `/TMRM/` (TM, RAMSIZ, TRIGSZ, HFFTSZ, SFFTSZ, RAMBAS).  
- **State:** Fixed TM data (no runtime modification).  

**INTRPT**  
- **Reads:** `/IORM/` (INTTYP, IOINT, IMASK, STATUS, STAT2).  
- **Writes:** `/IORM/` (INTTYP, IOINT, STAT2), `DEVICE` output.  
- **State:** Interrupt flags (`INTTYP(2)`), device interrupt status (`IOINT`).  

**CLOCK**  
- **Reads:** `CCTL(2)`, `CCST(2)`, `ELAPSE`.  
- **Writes:** `CCTR(2)` via `TCADD`/`RMOV`, `CCTL(1)`, `INTRPT`.  
- **State:** Counter (`CCTR`), control (`CCTL`), elapsed time (`ELAPSE`).  

---

#### **4. AP-120B-Specific Edge Cases**
**LODINP**  
- **End Block (line 5460):** If `BUF(2)≠0`, continues reading (not real end).  
- **MD Page Switch (lines 5540-5570):** On page mismatch, writes MAE via `MWRIT` to select new page.  
- **Triple Precision (line 5750):** Special unpacking for 38-bit FP (high nibble stored separately).  

**TMROM**  
- **Address Mapping:**  
  - Hardware 0-4095 → TM(1-64) [FFT]  
  - 4096-4396 → TM(65-365) [trig]  
  - 8192+ → TM(366-512) [TMRAM]  
- **Zero Entry (line 314):** `TM(314)=(0,0,0)` acts as a terminator.  

**INTRPT**  
- **Priority Order:** Fatal > Trap > Exception > I/O (lines 200-230).  
- **Universal Inhibit:** If `STAT2(1)` bit 3 is 0, no interrupts processed (line 200).  
- **IMASK Gating:** Only interrupts with IMASK bits set are visible (lines 240-260).  

**CLOCK**  
- **External Clock (IRATE=15):** Unimplemented; silently sets to 0 (line).  
- **Overflow/Underflow:**  
  - Countup overflow: `CCTR(1)=255 AND CCTR(2)=255`  
  - Countdown underflow: `CCTR(1)=0 AND CCTR(2)=0`  
- **Double Error:** If DNE set during overflow/underflow, sets CERR (line).  
- **Single Mode (CMO=0):** Clears CRN after overflow (line).  

---

#### **5. Cross-References**
**LODINP**  
- `GTFIL`: Gets input file (file system cluster).  
- `MREAD`/`MWRIT`: Simulates I/O to device 24 (I/O cluster).  
- `UNPKRG`: Unpacks 16-bit value (data conversion cluster).  
- `MOVPRT`: Moves partial words (data movement cluster).  
- `PSMEM`/`MDMEM`: Memory writes (memory cluster).  
- `FPINPT`: Converts double to 38-bit FP (floating-point cluster).  

**TMROM**  
- No external calls (static initialization).  

**INTRPT**  
- No external calls (pure bit manipulation).  

**CLOCK**  
- `TCADD`: Two's complement addition (arithmetic cluster).  
- `RMOV`: Register move (data movement cluster).  

--- 

This analysis adheres strictly to the provided source code, with concrete references to line numbers, COMMON blocks, and subroutine calls. No speculative interpretations are included.

### Cooperative drafts

#### DS coop

# Analysis of SIM100.FTN Section: LODINP, TMROM, INTRPT, CLOCK

## 1. Per-Subroutine Reference

### LODINP (Load Module)

**Signature:** `SUBROUTINE LODINP (ITTI, ITTO)`

**Purpose:** Reads APLOAD load module output into simulated AP-120B memories (Program Source memory and Main Data memory).

**Inputs:**
- `ITTI` - Input TTY channel number
- `ITTO` - Output TTY channel number

**Outputs:** Modifies simulated memory state (PS and MD)

**AP-120B Operation Simulated:** The AP-120B's load process where microcode and data are loaded from a host computer into the AP's program memory (PS) and data memory (MD). This simulates the APLOAD utility's output format.

### TMROM (Table Memory ROM)

**Signature:** `SUBROUTINE TMROM`

**Purpose:** Initializes the simulated Table Memory with pre-computed FFT coefficients and trigonometric function coefficients.

**Inputs:** None (hardcoded DATA statements)

**Outputs:** Fills the `TM` array in `/TMRM/` common block

**AP-120B Operation Simulated:** Initializes the AP-120B's Table Memory (TM), which is a read-only memory containing:
- 64-point FFT coefficients (TM indices 1-64)
- 301 trigonometric function coefficients (TM indices 65-365)
- 147 words of Table Memory RAM (TM indices 366-512)

### INTRPT (Interrupt Handler)

**Signature:** `SUBROUTINE INTRPT (MODE, DEVICE)`

**Purpose:** Manages the AP-120B's interrupt system with three modes: set, query, and clear.

**Inputs/Outputs:**
- `MODE` (input): 1=IO interrupt set, 2=interrupt query, 3=interrupt clear after INTA
- `DEVICE` (input/output): Device index (0-15) for IO operations

**AP-120B Operation Simulated:** The AP-120B's interrupt priority system, including:
- IO device interrupts with priority encoding
- Trap interrupts
- Exception interrupts (overflow, underflow, divide by zero)
- Fatal interrupts (SRAO - Sum Register All Ones)
- Universal interrupt inhibit
- Interrupt mask (IMASK) for IO devices

### CLOCK (Real Time Clock)

**Signature:** `SUBROUTINE CLOCK (FIX, SET, ELAPSE, CCTR, CCST, CCTL, INTRPT)`

**Purpose:** Simulates the FPS-100 real-time clock.

**Inputs:**
- `FIX` - 1 if clock in "fix" mode (single-step)
- `SET` - 1 if CRN (run) bit changed from 0 to 1
- `ELAPSE` - Elapsed time in microseconds

**Inputs/Outputs:**
- `CCTR(2)` - Clock Counter Register (two 16-bit words)
- `CCST(2)` - Clock Set Register (two 16-bit words)
- `CCTL(2)` - Clock Control Register (two 16-bit words)

**Outputs:**
- `INTRPT` - Set to 1 if clock interrupt occurs

**AP-120B Operation Simulated:** The FPS-100's real-time clock with:
- Up/down counting capability
- Rate selection (2^IRATE microseconds)
- Single integer vs. repeat integer mode
- Done (DNE) and Error (CERR) flags
- Interrupt on count completion (INTC bit)

## 2. Bit-Level Semantics

### LODINP Bit Operations

**Line 5477-5478 (PAKFAC packing):**
```fortran
HOLD=IRSHFT(BUFFER(II),16)    ! Extract left 16 bits
HOLD=ILSHFT(BUFFER(II),16)    ! Shift left 16 bits
HOLD=IRSHFT(HOLD,16)          ! Extract right 16 bits
```
These operations handle the case where the host word size is < 32 bits (PAKFAC=2). The AP-120B's 16-bit words are packed two-per-host-word. `IRSHFT` and `ILSHFT` are statement functions (defined as returning 0 on line STATEFUN, indicating they're stubs for machines that don't need them - the actual shift operations are done by the compiler's built-in functions on machines that support them).

**Line 5750 (Triple value unpacking):**
```fortran
REG(2)=IRSH16(BUF(6),12)      ! Extract high 4 bits
BUF(6)=IAND16(BUF(6),4095)    ! Mask to 12 bits (2^12-1)
```
This unpacks a 16-bit value where:
- Bits 15-12: High nibble (stored in REG(2))
- Bits 11-0: 12-bit mantissa portion (stored in BUF(6) after masking)

The value 4095 = 2^12-1 = 0xFFF, masking to 12 bits.

### TMROM Data Format

Each TM entry contains three 16-bit words representing AP-120B 38-bit floating-point numbers:
- Word 1: Sign (bit 15) + exponent (bits 14-6, 9 bits) + high mantissa (bits 5-0, 6 bits)
- Word 2: Middle mantissa (16 bits)
- Word 3: Low mantissa (16 bits)

Total: 1 sign + 9 exponent + 28 mantissa = 38 bits

Example from TM(1): `513, 1024, 0`
- 513 = 0x201 = binary: 0 100000000 1
  - Sign=0, Exponent=256, Mantissa high=1
- 1024 = 0x400 = binary: 0000010000000000
- 0 = low mantissa

### INTRPT Bit Operations

**Line 200 (Universal interrupt inhibit):**
```fortran
IF (MOD(STAT2(1)/8,2) .EQ. 0) RETURN
```
Tests bit 3 of STAT2(1) (value 8 = 2^3). This is the universal interrupt inhibit bit in APSTAT.

**Line 210 (Fatal interrupt check):**
```fortran
IF (MOD(STATUS(2)/32,2).EQ.0 .OR. MOD(STAT2(2)/32,2).EQ.0) GO TO 210
```
- `STATUS(2)/32` tests bit 5 (value 32 = 2^5) - SRAO (Sum Register All Ones) in APSTAT
- `STAT2(2)/32` tests bit 5 - Fatal interrupt enable in APSTAT2

**Line 220 (Trap interrupt check):**
```fortran
IF (INTTYP(1).EQ.0 .OR. MOD(STAT2(2)/16,2).EQ.0) GO TO 220
```
- `STAT2(2)/16` tests bit 4 (value 16 = 2^4) - Trap interrupt enable

**Line 230 (Exception interrupt check):**
```fortran
IF (MOD(STATUS(1)/32,8).EQ.0 .OR. MOD(STAT2(2)/64,2).EQ.0) GO TO 230
```
- `STATUS(1)/32` extracts bits 5-7 (value 32, mask 8 = 2^3) - OVF, UNF, DIVZ flags
- `STAT2(2)/64` tests bit 6 (value 64 = 2^6) - Exception interrupt enable

**Line 240 (IO interrupt check):**
```fortran
IF (INTTYP(2).EQ.0 .OR. MOD(STAT2(2)/128,2).EQ.0) RETURN
```
- `STAT2(2)/128` tests bit 7 (value 128 = 2^7) - IO interrupt enable

**Lines 240-260 (IMASK bit testing):**
```fortran
MOD(IMASK(1)/2**(8-I),2).EQ.1  ! Test bit (8-I) in IMASK(1) for devices 0-7
MOD(IMASK(2)/2**(16-I),2).EQ.1 ! Test bit (16-I) in IMASK(2) for devices 8-15
```
IMASK is a 16-bit mask split across two 16-bit words:
- IMASK(1): bits 15-8 (devices 0-7)
- IMASK(2): bits 15-8 (devices 8-15)

### CLOCK Bit Operations

**Line (Run bit check):**
```fortran
IF (MOD(CCTL(2),2) .EQ. 0) RETURN
```
Tests bit 0 of CCTL(2) - CRN (Clock Run) bit.

**Line (Rate extraction):**
```fortran
IRATE = MOD(CCTL(2)/2,16)
```
Extracts bits 4-1 (value 2, mask 16 = 2^4) - clock rate selection (0-14, 15=external).

**Line (Up/Down bit):**
```fortran
UD = MOD (CCTL(2)/64,2)
```
Tests bit 6 (value 64 = 2^6) - count direction (0=down, 1=up).

**Line (DNE bit check):**
```fortran
DNE = MOD(CCTL(1)/2,2)
```
Tests bit 1 of CCTL(1) - Done flag.

**Line (CERR bit set):**
```fortran
CCTL(1) = MOD(CCTL(1),128)+128
```
Sets bit 7 (value 128 = 2^7) - Clock Error flag, while preserving bits 0-6.

**Line (INTC bit check):**
```fortran
IF (MOD(CCTL(1),2) .EQ. 1) INTRPT = 1
```
Tests bit 0 of CCTL(1) - Interrupt on Count complete.

**Line (CMO bit check):**
```fortran
IF (MOD(CCTL(2)/32,2) .EQ. 1) GO TO 210
```
Tests bit 5 (value 32 = 2^5) - Clock Mode (0=single integer, 1=repeat integer).

## 3. State and Side Effects

### LODINP State

**Reads:**
- `/MDRM/` - MD array (512x3), PAGNUM, PAGSIZ
- `/IORM/` - IODEV array (64x3), IOSIZE
- `/DUMB/` - BUF array (via EQUIVALENCE for SPFPN)

**Writes:**
- `MD` array via `MDMEM` calls
- PS memory via `PSMEM` calls
- MAE (Memory Address Extension) register via `MWRIT` calls

**AP-120B State Represented:**
- MD(512,3): Main Data memory, 512 pages × 3 words per address
- PS: Program Source memory (microcode)
- MAE: Memory Address Extension register (page selection)
- PG0: Initial MD page number

### TMROM State

**Writes:**
- `/TMRM/` common block:
  - `TM(512,3)` - Table Memory array
  - `RAMSIZ` = 147 (TMRAM size)
  - `TRIGSZ` = 301 (trigonometric coefficients)
  - `HFFTSZ` = 4096 (hardware FFT table size)
  - `SFFTSZ` = 64 (software FFT table size)
  - `RAMBAS` = 8192 (TMRAM base address)

**AP-120B State Represented:**
- TM: Table Memory containing:
  - Addresses 0-4095: FFT table (64 entries in simulation)
  - Addresses 4096-4396: Function coefficients (301 entries)
  - Addresses 8192+: TMRAM (147 words)

### INTRPT State

**Reads:**
- `INTTYP(2)` - Interrupt type flags (1=trap, 2=IO)
- `IOINT(16)` - IO device interrupt flags
- `IMASK(2)` - Interrupt mask (16 bits)
- `STATUS(2)` - APSTAT register
- `STAT2(2)` - APSTAT2 register

**Writes:**
- `INTTYP(2)` - Updated with highest priority IO interrupt
- `IOINT(I)` - Set/cleared for specific devices
- `STAT2(2)` - Interrupt condition bits set

**AP-120B State Represented:**
- APSTAT: Status register with SRAO (bit 5 of word 2), OVF/UNF/DIVZ (bits 5-7 of word 1)
- APSTAT2: Extended status with interrupt enables and conditions
- IMASK: IO device interrupt mask
- INTTYP: Internal interrupt tracking

### CLOCK State

**Reads:**
- `CCTL(2)` - Clock Control Register
- `CCST(2)` - Clock Set Register
- `ELAPSE` - Elapsed time

**Writes:**
- `CCTR(2)` - Clock Counter Register (via TCADD or RMOV)
- `CCTL(1)` - DNE and CERR flags
- `INTRPT` - Clock interrupt flag

**AP-120B State Represented:**
- CCTR: 16-bit clock counter (two words for 32-bit simulation)
- CCST: 16-bit clock set value
- CCTL: Control register with:
  - Bit 0: INTC (Interrupt on Count)
  - Bit 1: DNE (Done)
  - Bit 7: CERR (Clock Error)
  - Bits 4-1: IRATE (rate selection)
  - Bit 5: CMO (mode: single/repeat)
  - Bit 6: UD (up/down)
  - Bit 0 of word 2: CRN (run)

## 4. AP-120B-Specific Edge Cases

### LODINP Edge Cases

1. **Bad Load Module (line 90000):** If header type is out of range (1-4) or file ends unexpectedly, prints "BAD LOAD MODULE" and closes file.

2. **End Block with non-zero second number (line 5460):** If BUF(2) ≠ 0, continues reading (not real end of load module).

3. **MD Page Switching (lines 5540-5570):** Before writing to MD, checks if correct page is selected. If not, writes MAE register via `MWRIT` to select new page.

4. **Triple Precision Values (line 5750):** Special handling for AP-120B triple-precision (38-bit) floating-point numbers, extracting high nibble separately.

5. **Complex Values (line 5765):** Two FP values read sequentially for real and imaginary parts.

### TMROM Edge Cases

1. **Address Mapping:** The hardware addresses (0-8191+) are mapped to array indices (1-512) with specific offsets:
   - Hardware 0-4095 → Array 1-64 (FFT)
   - Hardware 4096-4396 → Array 65-365 (function coefficients)
   - Hardware 8192+ → Array 366-512 (TMRAM)

2. **Special Values:** Some entries have unusual first-word values:
   - TM(314): All zeros (terminator?)
   - TM(290): Third word = 36 (not a typical mantissa value)
   - Various entries with first word < 500 or > 520 (non-standard exponent values)

### INTRPT Edge Cases

1. **Priority Encoding (lines 240-260):** IO interrupts are scanned from highest priority (device 0) to lowest (device 15), with IMASK gating.

2. **Interrupt Acknowledge (mode 3):** After INTA, the highest priority enabled interrupt is cleared and INTTYP is updated to the next pending interrupt.

3. **Multiple Interrupt Types:** The priority order is: Fatal > Trap > Exception > IO.

4. **Universal Interrupt Inhibit:** If bit 3 of STAT2(1) is clear, all interrupts are masked.

### CLOCK Edge Cases

1. **External Clock Rate (IRATE=15):** Not implemented - silently set to 0.

2. **Underflow/Overflow Detection (line 120):**
   - Countdown underflow: CCTR(1)=0 AND CCTR(2)=0
   - Countup overflow: CCTR(1)=255 AND CCTR(2)=255
   Note: 255 = -1 in two's complement for 8-bit, but here it's 16-bit all-ones.

3. **Double Done Error (line DNE check):** If DNE already set when another underflow/overflow occurs, CERR bit is set.

4. **Single Integer Mode (line CMO check):** After underflow/overflow, if CMO=0, the RUN bit is cleared, stopping the clock.

5. **Repeat Integer Mode (line 210):** CCTR is reloaded from CCST, allowing continuous counting.

## 5. Cross-References

### LODINP Calls

1. **`CALL GTFIL (ISL, ITTI, ITTO)`** - Gets input file name (file system routine)
2. **`CALL MREAD (IODEV, 24, REG, IOSIZE, 3, 6)`** - Reads MAE register from I/O device 24 (simulated AP I/O)
3. **`CALL CLFIL (ISL, ITTO)`** - Closes input file
4. **`CALL MWRIT (REG, IODEV, 24, IOSIZE, 6, 3)`** - Writes MAE register to I/O device 24
5. **`CALL UNPKRG (HOLD, WRK)`** - Unpacks 16-bit value into two 8-bit bytes (from UNPKRG cluster)
6. **`CALL MOVPRT (WRK, 1, REG, J, 2, 8, 2)`** - Moves partial word (from MOVPRT cluster)
7. **`CALL PSMEM (2, IADDR, REG)`** - Writes to Program Source memory (from PSMEM cluster)
8. **`CALL MDMEM (2, IADDR, REG)`** - Writes to Main Data memory (from MDMEM cluster)
9. **`CALL FPINPT (DBLE(SPFPN(1)), REG)`** - Converts host floating-point to AP-120B 38-bit format (from FPINPT cluster)

### INTRPT References

- **No subroutine calls** - All operations are inline bit manipulations on COMMON block variables.

### CLOCK Calls

1. **`CALL TCADD (CCTR, INCR, CCTR, 2, UNUSED)`** - Two's complement addition (from TCADD cluster)
2. **`CALL RMOV (CCST, CCTR, 2)`** - Register move (from RMOV cluster)

#### GLM coop

ERROR: HTTP Error 429: Too Many Requests

