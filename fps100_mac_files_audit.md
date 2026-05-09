# FPS-100 .MAC files — Council-of-Clankers analysis

Each file analyzed via cooperative pass (DS + GLM independent) followed by adversarial pass (each model sees the other and revises).

## Index

- [`[327,010]ADUTIL.MAC`](#327010adutilmac) — 402 lines, 13 exports
- [`[327,010]AMLHSR.MAC`](#327010amlhsrmac) — 4296 lines, 24 exports
- [`[327,010]BAAHSR.MAC`](#327010baahsrmac) — 4448 lines, 89 exports
- [`[327,010]BABHSR.MAC`](#327010babhsrmac) — 4576 lines, 61 exports
- [`[327,010]DAPEX.MAC`](#327010dapexmac) — 1295 lines, 27 exports
- [`[327,010]DEVTAB.MAC`](#327010devtabmac) — 138 lines, 1 exports
- [`[327,010]DGNHSR.MAC`](#327010dgnhsrmac) — 717 lines, 8 exports
- [`[327,010]DRIVER.MAC`](#327010drivermac) — 334 lines, 1 exports
- [`[327,010]FPSMC.MAC`](#327010fpsmcmac) — 5 lines, 0 exports
- [`[327,010]IPRHSR.MAC`](#327010iprhsrmac) — 3631 lines, 12 exports
- [`[327,010]SIGHSR.MAC`](#327010sighsrmac) — 8155 lines, 28 exports
- [`[327,010]UTLHSR.MAC`](#327010utlhsrmac) — 24 lines, 2 exports

## [327,010]ADUTIL.MAC

- 402 lines
- 13 exported symbols
- exports: `DUTIL, IADD16, IAND16, IGRN16, ILOC, ILSH16, INOT16, INT16, IOR16, IP16, IRSH16, SREAD, TERM`

### Cooperative pass

**DeepSeek (26s):**

```
Here is a structured analysis of `[327,010]ADUTIL.MAC` from the FPS-100 RSX-11M v3.2 distribution.

---

### 1. Purpose

This file is a **host-dependent utility library** for the PDP-11 host CPU. It provides a set of low-level, 16-bit integer manipulation functions that are used by the FPS-100 host software (likely FORTRAN-callable). It is **not** a driver, device table, sysgen config, or AP-120B microcode file. Instead, it is a collection of small assembly-language stubs that implement operations that FORTRAN on the PDP-11 either does not support directly (e.g., full-word logical operations, unsigned shifts) or that require direct access to PDP-11 hardware registers (e.g., the front-panel switch register, terminal status register).

The file is part of the **host service routine (HSR) wrapper** layer, providing the PDP-11-specific glue between FORTRAN application code and the FPS-100 hardware/software interface.

---

### 2. Calling Convention / Structure

The file is a **stub-collection** of 13 separate entry points, each implementing a single function. The calling convention is the standard **FORTRAN-IV calling convention** on PDP-11 RSX-11M:

- Arguments are passed on the stack, pushed in left-to-right order.
- The return address is at `(R5)`.
- The first argument is at `2(R5)`, the second at `4(R5)`, etc.
- For functions returning a value, the result is placed in `R0`.
- For subroutines, the result is stored back through the argument pointer (e.g., `@2(R5)`).

The file uses a conditional assembly macro `RETURN`:
- If `DOS = 1`, it uses `RTS R5` (DOS convention).
- If `DOS = 0` (the actual setting), it uses `RTS PC` (RT-11 / RSX-11M convention).

All functions are simple, leaf routines (no nested calls), typically 2–6 instructions long.

---

### 3. Key Routines / Data Structures

There are no complex data structures. The file defines 13 global entry points, each a single function:

| Entry Point | Purpose |
|---|---|
| `IOR16` | 16-bit logical OR of two integers |
| `INOT16` | 16-bit logical NOT (complement) of an integer |
| `IADD16` | 16-bit integer addition (no overflow check) |
| `IRSH16` | 16-bit right shift with zero fill (loop-based) |
| `ILSH16` | 16-bit left shift with zero fill (loop-based) |
| `ILOC` | Returns the address (location) of its argument |
| `SREAD` | Reads the PDP-11 front-panel switch register into an integer |
| `TERM` | Checks if a character is available at the terminal (non-blocking) |
| `INT16` | Truncates an integer to 16 bits (no-op on PDP-11) |
| `IP16` | Converts a negative 16-bit integer to unsigned (no-op on PDP-11) |
| `IAND16` | 16-bit logical AND of two integers |
| `IGRN16` | 16-bit pseudo-random number generator (linear congruential) |

**Pattern summary:** All 13 functions follow the same pattern: load argument(s) from stack, perform operation, return result in `R0` (or store via pointer for subroutines). No local storage, no loops (except the shift functions which use a decrement-and-branch loop), no calls to other routines in this file.

---

### 4. External Dependencies

The file has minimal external dependencies:

- **RSX-11M directives:**
  - `GSSW$S` — Get Switches directive (reads the front-panel switch register into `$DSW`). Used by `SREAD` and `TERM`.
  - `.MCALL GSSW$S` — Macro call to include the directive.

- **Hardware registers (defined as symbols):**
  - `TERMS = 177560` — Terminal status register (not actually used in the code; defined but unused).
  - `SWREG = 177570` — Host switch register (also defined but unused; the code uses `GSSW$S` instead).

- **No calls to APEX, $GTPKT, ALUN$, ATTACH, or any FPS-100 hardware registers.** This file is purely PDP-11 host-side.

---

### 5. Subtleties

1. **Conditional assembly for DOS vs. RT/RSX:** The `DOS` symbol is set to `0`, meaning the file is assembled for RT-11 or RSX-11M. The `RETURN` macro changes the return instruction accordingly. This is a portability feature.

2. **`IAND16` implementation:** Instead of a simple `AND` instruction, it uses `MOV @4(R5),R0; MOV @2(R5),R1; COM R1; BIC R1,R0`. This is a clever trick: `BIC` (bit clear) with a complemented mask is equivalent to AND. This may be a workaround for FORTRAN compilers that do not generate the `AND` instruction for `.AND.` on 16-bit integers, or it may be a historical artifact.

3. **`IGRN16` random number generator:** The algorithm is a linear congruential generator:
   - `IXN = IXN + IYN`
   - `IYN = IYN + 156043` (decimal; `156043` octal = `0x1A0B` hex)
   - If the addition of `IYN` overflows (carry set), `IXN` is incremented and byte-swapped (`SWAB`).
   - The constant `156043` is `-9181` in 16-bit signed two's complement, matching the comment `IP16(-9181)`.

4. **`INT16` and `IP16` are no-ops:** On a 16-bit PDP-11, truncating to 16 bits and converting negative to unsigned are identity operations. They are included for portability to machines with larger word sizes (e.g., 32-bit VAX, 36-bit PDP-10). The comments explicitly note this.

5. **`SREAD` and `TERM` use `GSSW$S`:** Both read the front-panel switch register. `SREAD` returns the value directly. `TERM` checks if bit 15 (sign bit) is set (`BPL` branch if positive — i.e., if bit 15 is clear, skip increment). This is a non-standard use of the switch register as a user-interrupt flag: the user sets bit 15 on the front-panel switches to signal termination. This is a clever hack for systems without a keyboard interrupt.

6. **Shift routines use loops:** `IRSH16` and `ILSH16` implement shifts by looping one bit at a time (`ROR`/`ROL` with `CLC` before each). This is slow but correct. The comments note that if a hardware shift function (`RS`/`LS`) is available, it should be used instead. On the PDP-11, the `ASH` and `ASHC` instructions (on 11/45, 11/70, etc.) would be faster but are not used here, likely for compatibility with the 11/03 or 11/23.

7. **`ILOC` returns the argument's address:** `MOV 2(R5),R0` loads the *value* of the argument pointer (i.e., the address of the argument), not the argument itself. This is the standard FORTRAN `LOC()` function.

8. **No `.ENABL` or `.DSABL` directives:** The file does not use any assembler options like `AMA` or `FC` for floating-point, confirming it is purely integer/logic.

9. **File is self-contained:** No includes, no references to FPS-100 hardware, no APAL microcode. It is a pure PDP-11 host utility library.
```

**GLM (76s):**

```
# Analysis of FPS-100 PDP-11 Source File: [327,010]ADUTIL.MAC

## 1. Purpose

ADUTIL.MAC serves as a collection of **host-dependent utility routines** that provide the fundamental interface between the FPS-100 array processor software stack and the PDP-11 host operating system (DOS, RT-11, or RSX-11M). These utilities implement basic integer operations and system interaction capabilities that need to work across different PDP-11 environments and hardware configurations. The file acts as an abstraction layer, allowing higher-level FPS-100 code to function consistently regardless of the specific host system or hardware.

## 2. Calling Convention / Structure

This file is a **stub-collection** with a consistent pattern:

- **Standard PDP-11 calling convention**: Arguments accessed via `@2(R5)`, `@4(R5)`, etc.
- **Conditional return handling**: Uses a macro that generates different return sequences for DOS (`RTS R5`) vs. RT/RSX (`RTS PC`) systems.
- **No stack frame management**: Routines assume stack space is managed by the caller.
- **Simple parameter pattern**: Most routines follow a "load from stack → operate → return in R0" pattern.

The file defines configuration switches for operating system detection (`DOS = 0`) and hardware register addresses, demonstrating its purpose as system-dependent code.

## 3. Key Routines / Data Structures

This file exports 13 routines total, organized into three categories:

**Integer Operations (8 routines)**:
- `IOR16` - 16-bit logical OR
- `INOT16` - 16-bit logical NOT
- `IADD16` - 16-bit integer addition
- `IRSH16` - 16-bit right shift with zero fill
- `ILSH16` - 16-bit left shift with zero fill
- `IAND16` - Full word logical AND (using COM+BIC trick)
- `INT16` - Truncate to 16 bits
- `IP16` - Convert to positive 16-bit integer (no-op for PDP-11)

**System Interaction (3 routines)**:
- `SREAD` - Read CPU switches into user variable
- `TERM` - Check for terminal input (interrupt flag)
- `ILOC` - Get user address of argument

**Special Function (2 routines)**:
- `IGRN16` - 16-bit pseudo-random number generator with state

## 4. External Dependencies

- **System service `GSSW$S`**: Called by `SREAD` and `TERM` to read hardware switches
- **Hardware registers**: Defines `TERMS = 177560` and `SWREG = 177570` for terminal status and host switch register
- **Operating system differences**: Conditional assembly based on `DOS` flag
- **System variable `$DSW`**: Used internally to store switch register value
- **Standard MACRO-11 directives**: Uses `.MCALL GSSW$S` for system service access

## 5. Subtleties

1. **Conditional return handling**: The `RETURN` macro generates different code sequences for DOS vs. RT/RSX systems due to their different calling conventions.

2. **Logical operation implementation**: `IAND16` uses a non-obvious COM+BIC sequence instead of direct AND, suggesting hardware limitations or specific requirements of the PDP-11 instruction set.

3. **Random number algorithm**: `IGRN16` implements a specific pseudo-random number generator with fixed constants (#156043) and includes a SWAB operation when overflow occurs, indicating a carefully designed algorithm for FPS applications.

4. **Switch interpretation**: `TERM` and `SREAD` both use `GSSW$S` but interpret results differently - `TERM` uses BPL (plus branch) to check the sign bit for input availability, while `SREAD` returns the raw switch value.

5. **Shift implementation**: Both shift routines (`IRSH16`, `ILSH16`) implement shifting through loops rather than using dedicated shift instructions, suggesting the PDP-11 lacks direct variable-length shift operations or for compatibility reasons.

6. **Hardware abstraction**: Despite defining hardware register addresses, the code accesses them through the `GSSW$S` system service rather than direct memory access, indicating it's designed to work within RSX-11M's protection mechanisms.

This file represents a critical layer of system-dependent code that enables the FPS-100 software stack to function across different PDP-11 environments while providing a consistent interface to higher-level components.
```

### Adversarial pass (final)

**DeepSeek revised (38s):**

```
## Critical Evaluation of Peer Analysis

### Agreements

The peer correctly identifies the file as a **host-dependent utility collection** providing basic integer operations and system interaction. The calling convention analysis is accurate regarding the `@2(R5)`/`@4(R5)` pattern and the conditional `RETURN` macro. The categorization of routines into integer operations, system interaction, and special functions is reasonable.

### Disagreements and Omissions

**1. Fundamental misunderstanding of `IAND16` implementation**
The peer claims `IAND16` uses "COM+BIC trick" and suggests "hardware limitations or specific requirements of the PDP-11 instruction set." This is **wrong**. The PDP-11 has a perfectly good `AND` instruction. The code:
```
MOV @4(R5),R0    ; load IB
MOV @2(R5),R1    ; load IA
COM R1           ; complement IA
BIC R1,R0        ; clear bits in IB where IA is 1's complement
```
This implements `IA AND IB` using De Morgan's law: `A AND B = NOT(NOT A OR NOT B)`. The `BIC` instruction clears bits in the destination where the source has 1s. So `BIC R1,R0` with `R1 = NOT IA` gives `IB AND NOT(NOT IA) = IB AND IA`. This is a **deliberate choice** to use `BIC` (which is a single-cycle instruction on some PDP-11 models) rather than `AND` (which may be slower). It's a performance optimization, not a limitation.

**2. Missing the `IGRN16` algorithm details**
The peer says "fixed constants (#156043)" but doesn't recognize this as `-9181` in decimal (the comment says `IP16(-9181)`). The algorithm is a **linear congruential generator** with specific constants. The `SWAB` when carry occurs is not just "when overflow occurs" but specifically when `IYN` addition overflows 16 bits. The peer misses that this is a well-known random number generator pattern used in scientific computing.

**3. Incorrect analysis of `TERM` routine**
The peer says `TERM` "uses BPL (plus branch) to check the sign bit for input availability." This is **wrong**. `TERM` reads the switch register (`GSSW$S`), then checks `$DSW` with `BPL` (branch if plus). This checks **bit 15** (the sign bit) of the switch register. On the PDP-11 front panel, the switch register's bit 15 is typically the "run/halt" or "enable" switch. The routine is **not** checking terminal input at all - it's checking a **front-panel switch** to determine if the user wants to interrupt. The comment says "SET 'IA' TO 1 IF THE USER WISHES TO INTERRUPT" - this is done via the front-panel switch, not the terminal. The peer conflates this with terminal input checking.

**4. Missing the `SREAD`/`TERM` switch register interpretation**
Both `SREAD` and `TERM` read the **same switch register** (`GSSW$S`), but `SREAD` returns the full 16-bit value while `TERM` only checks bit 15. The peer doesn't note this shared hardware dependency.

**5. Overlooking the `ILOC` implementation**
`ILOC` returns `2(R5)` (not `@2(R5)`), meaning it returns the **address** of the argument, not its value. This is correct for a `LOC()` function. The peer doesn't comment on this distinction.

**6. Missing the `INT16`/`IP16` no-op pattern**
Both `INT16` and `IP16` are **no-ops** on the PDP-11 because the machine is already 16-bit. The peer notes this but doesn't explain *why* they exist - they're placeholders for portability to larger machines (like the VAX or 32-bit hosts).

**7. Incorrect count of routines**
The peer says "13 routines total" but the `.GLOBL` list shows 13 symbols: `IOR16, INOT16, IADD16, IRSH16, ILSH16, ILOC, SREAD, TERM, INT16, IP16, IAND16, IGRN16, DUTIL`. `DUTIL` is the `.TITLE` symbol, not a routine. So there are **12 routines** (or 11 if we exclude `DUTIL`).

**8. Missing the `GSSW$S` directive details**
The peer says `GSSW$S` is a "system service" but doesn't note that it's an **RSX-11M executive directive** that reads the front-panel switch register. The `BCS` (branch if carry set) after `GSSW$S` checks for the "no switch register" condition (e.g., on systems without front-panel switches). This is important for understanding the error handling.

**9. Overlooking the `TERMS` and `SWREG` definitions**
The file defines `TERMS = 177560` and `SWREG = 177570` but **never uses them** in the actual code. These are **documentation constants** or leftovers from an earlier version. The actual hardware access goes through `GSSW$S`, not direct memory access. The peer doesn't note this discrepancy.

**10. Missing the conditional assembly for DOS**
The `DOS = 0` setting means this is compiled for **RT-11 or RSX-11M** (not DOS). The `RETURN` macro generates `RTS PC` for these systems. The peer mentions this but doesn't explain the significance - DOS used `RTS R5` because it passed arguments in registers, while RT/RSX used the standard PDP-11 calling convention with `R5` as frame pointer.

### Final Analysis

## 1. Purpose

ADUTIL.MAC provides **host-dependent utility routines** that form the lowest-level interface between FPS-100 software and the PDP-11 host. It implements:

- **16-bit integer operations** that may not be reliably available in Fortran (logical operations, shifts, truncation)
- **System interaction** (reading front-panel switches, getting variable addresses)
- **A pseudo-random number generator** for scientific computing

The file is designed to be **portable across PDP-11 operating systems** (DOS, RT-11, RSX-11M) through conditional assembly.

## 2. Calling Convention / Structure

**Standard PDP-11 calling convention** with arguments on the stack:
- First argument at `@2(R5)` (value) or `2(R5)` (address for `ILOC`)
- Second argument at `@4(R5)`
- Return value in `R0`
- Return via `RTS PC` (RT/RSX) or `RTS R5` (DOS)

All routines are **leaf functions** (no calls to other routines in this file), though the comments reference `INT16` as a dependency for some operations.

## 3. Key Routines (12 total)

**Integer Operations (8):**
- `IOR16` - 16-bit logical OR (uses `BIS`)
- `INOT16` - 16-bit logical NOT (uses `COM`)
- `IADD16` - 16-bit addition (uses `ADD`)
- `IRSH16` - 16-bit right shift with zero fill (loop with `ROR`)
- `ILSH16` - 16-bit left shift with zero fill (loop with `ROL`)
- `IAND16` - 16-bit logical AND (uses `COM`/`BIC` trick for performance)
- `INT16` - Truncate to 16 bits (no-op on PDP-11)
- `IP16` - Convert to positive 16-bit integer (no-op on PDP-11)

**System Interaction (3):**
- `SREAD` - Read front-panel switch register via `GSSW$S`
- `TERM` - Check front-panel switch bit 15 for interrupt request
- `ILOC` - Return address of argument (like Fortran `LOC()`)

**Special Function (1):**
- `IGRN16` - Linear congruential random number generator with state update

## 4. External Dependencies

- **`GSSW$S`** - RSX-11M executive directive to read switch register (via `.MCALL`)
- **`$DSW`** - System variable holding switch register value
- **Conditional assembly** based on `DOS` flag (0 = RT/RSX, 1 = DOS)
- **No FPS-100 hardware dependencies** - this is pure host-side code

## 5. Subtleties

1. **`IAND16` uses `COM`/`BIC` instead of `AND`** - This is a performance optimization. `BIC` (bit clear) is a single-cycle instruction on some PDP-11 models, while `AND` may take longer. The implementation uses De Morgan's law: `A AND B = NOT(NOT A OR NOT B)`.

2. **`IGRN16` algorithm** - Implements: `IXN = IXN + IYN`; `IYN = IYN - 9181`; if `IYN` overflows, `IXN = SWAP(IXN + 1)`. The constant `156043` is the two's complement of `-9181` (i.e., `65536 - 9181 = 56445`? No - `156043` decimal is `0x2618B` which is 19 bits. This is actually `-9181` in 16-bit: `65536 - 9181 = 56355` = `0xDC23`. But `156043` = `0x2618B` which is 19 bits. This is **wrong** - the constant should be `56355` (`0xDC23`). The comment says `IP16(-9181)` which would give `56355`. The code has `#156043` which is `0x2618B` - this is a **bug** or the constant is being used differently. Actually, `156043` decimal = `0x2618B` which truncated to 16 bits is `0x618B` = `24971`. This doesn't match `-9181`. This appears to be a **different algorithm** than the comment describes, or the comment is misleading.

3. **`TERM` checks front-panel switch, not terminal** - Despite the name, `TERM` reads the switch register's sign bit (bit 15). On PDP-11 front panels, this bit is often the "enable" or "run" switch. The routine is checking for a **hardware interrupt request** via the front panel, not terminal input.

4. **`SREAD` and `TERM` share hardware** - Both use `GSSW$S` but interpret the result differently. `SREAD` returns the full 16-bit value; `TERM` only checks bit 15.

5. **Shift routines use loops** - `IRSH16` and `ILSH16` implement shifts via `ROR`/`ROL` loops rather than using `ASR`/`ASL` or `SEC`/`ROR` patterns. This is because the PDP-11 lacks a variable-count shift instruction. The `CLC` before each rotate ensures zero fill.

6. **`INT16` and `IP16` are no-ops** - They exist solely for portability to larger word-size machines (e.g., VAX, 32-bit hosts). On the PDP-11, 16-bit integers are already the correct size.

7. **Unused hardware register definitions** - `TERMS = 177560` and `SWREG = 177570` are defined but never used in the code. They may be documentation or remnants from a version that used direct memory access instead of `GSSW$S`.

8. **Conditional return convention** - The `RETURN` macro handles the difference between DOS (which used `RTS R5` with register-based argument passing) and RT/RSX (which used `RTS PC` with stack-based arguments). This is critical for cross-system compatibility.
```

**GLM revised (66s):**

```
### Evaluation of Peer Analysis

The peer's analysis is largely accurate and well-structured, but contains several important errors and omissions:

#### Where I Agree:
1. The identification of the file as a "host-dependent utility library" is correct.
2. The description of the FORTRAN-IV calling convention and conditional assembly for DOS/RT-11M is accurate.
3. Most of the routine descriptions are correct.
4. The external dependencies analysis is accurate (only GSSW$S and hardware registers).

#### Where the Peer is Wrong or Inaccurate:
1. **IGRN16 dependency claim**: The peer states "ROUTINES USED: IADD16,IADDC,ISWAP,IP16" but the code actually uses the PDP-11 `SWAB` instruction directly, not an `ISWAP` routine.
   
2. **IP16 implementation misunderstanding**: The peer claims IP16 is "no-op on PDP-11" but fails to note the commented code for larger-word machines: "IF (IP16.LT.0) IP16=IP16+65536".
   
3. **TERM function interpretation**: The peer says "checks if a character is available at terminal" but the actual implementation checks the sign bit of the front-panel switches (bit 15), not actual terminal input. This is a hardware-specific interrupt mechanism, not a terminal check.

4. **Missing subtle hardware interaction**: The peer misses that `SWREG = 177570` and `TERMS = 177560` are defined but unused - the code uses `GSSW$S` instead for switch register access.

5. **Shift routine analysis**: The peer correctly identifies the loop implementation but doesn't note that `ROR`/`ROL` with `CLC` is specifically for 16-bit operations - not a general-purpose shift.

#### Where the Peer is Vague:
1. **FPS-100 context**: The peer doesn't sufficiently emphasize how these utilities specifically serve the FPS-100's FORTRAN interface, particularly `SREAD` and `TERM` which interact with PDP-11 hardware as part of FPS-100 operation.
   
2. **Random number generator details**: The peer correctly identifies LCG but doesn't explain why the constant 156043 is special (it's -9181 in 16-bit 2's complement).

#### What the Peer Missed:
1. **Hardware register definitions**: The symbols `SWREG` and `TERMS` are defined but never used, indicating they might be leftover from other implementations.
   
2. **Stack frame usage**: All routines follow identical stack access patterns (@2(R5), @4(R5)), but the peer doesn't explicitly state this consistency.
   
3. **Zero-extension pattern**: Multiple routines (`IOR16`, `INOT16`, etc.) return results in R0 without explicit zero-extension, which is correct on PDP-11 but significant for portability.

---

### Final Analysis

#### 1. Purpose
This file is a **PDP-11-specific utility library** for the FPS-100 host software stack. It provides low-level integer operations and hardware access functions that FORTRAN cannot directly implement, serving as glue between application code and FPS-100 hardware interfaces. It's part of the host service routine layer, particularly important for FPS-100's FORTRAN callable routines.

#### 2. Calling Convention / Structure
A collection of 13 stub routines following strict FORTRAN-IV calling conventions:
- Arguments passed via stack (2(R5), 4(R5), etc.)
- Functions return values in R0
- Subroutines store results via @2(R5)
- Conditional `RETURN` macro adapts for DOS (RTS R5) vs RT/RSX-11M (RTS PC)
- All routines are simple leaf functions with 2-6 instructions

#### 3. Key Routines / Data Structures
| Routine   | Purpose                                              |
|-----------|------------------------------------------------------|
| IOR16     | 16-bit logical OR of two integers                   |
| INOT16    | 16-bit logical NOT (complement)                     |
| IADD16    | 16-bit integer addition (unsigned)                  |
| IRSH16    | 16-bit right shift with zero fill                   |
| ILSH16    | 16-bit left shift with zero fill                    |
| ILOC      | Returns address of argument (equivalent to FORTRAN LOC) |
| SREAD     | Reads front-panel switch register into integer      |
| TERM      | Checks sign bit of switches for user interrupt flag |
| INT16     | Truncates to 16 bits (identity on PDP-11)          |
| IP16      | Converts negative to unsigned (identity on PDP-11)   |
| IAND16    | Full-word logical AND using COM/BIC trick           |
| IGRN16    | 16-bit pseudo-random number generator               |

No complex data structures - all routines use registers and stack arguments exclusively.

#### 4. External Dependencies
- **RSX-11M directive**: `GSSW$S` (Get Switches) for front-panel register access
- **Hardware registers**: 
  - `SWREG = 177570` and `TERMS = 177560` defined but unused
  - Actual switch register access via `GSSW$S` which populates `$DSW`
- **No dependencies** on APEX, $GTPKT, ALUN$, ATTACH, or FPS-100 hardware registers

#### 5. Subtleties
1. **Conditional assembly**: `DOS=0` setting makes the code target RT/RSX-11M (not DOS), with `RETURN` using `RTS PC`
2. **IAND16 trick**: Uses `COM R1; BIC R1,R0` instead of direct AND, likely a FORTRAN compiler workaround
3. **IGRN16 algorithm**: Linear congruential generator with constant 156043 (-9181 in 2's complement), with carry handling and SWAB for byte-swapping
4. **Hardware interrupt mechanism**: `TERM` checks bit 15 of switch register (BPL branch) as non-standard interrupt flag
5. **Shift implementation**: Loop-based ROR/ROL with CLC for compatibility with PDP-11 models lacking hardware shifts
6. **Portability notes**: INT16 and IP16 include commented code for larger-word machines (adding 65536 if negative)
7. **Unused definitions**: SWREG and TERMS are defined but never referenced, suggesting they may be remnants from other implementations
```

## [327,010]AMLHSR.MAC

- 4296 lines (excerpted)
- 24 exported symbols
- exports: `APEX, EIGRS, FGEN, FGENT, IMTQL2, SCBAK, SCFWD, SCSFB, SCUFB, SKYSOL, SRBAK, SRFWD, SRSFB, SRUFB, TCVMUL, TRED2, TSCBAK, TSCFWD, TSCSFB, TSCUFB, TSRBAK, TSRFWD, TSRSFB, TSRUFB`

### Cooperative pass

**DeepSeek (22s):**

```
Based on the provided excerpt of `[327,010]AMLHSR.MAC` from the FPS-100 RSX-11M distribution, here is a structured analysis:

## 1. Purpose

This file is a **collection of Host Service Routines (HSRs)** for the FPS-100 array processor. It serves as the primary interface between the PDP-11 host (running RSX-11M) and the FPS-100 hardware. Each routine in this file is a self-contained wrapper that:

- Accepts parameters from the calling program (via the standard FPS-100 calling convention using register `%5`)
- Builds a parameter list (`SLIST`) for the FPS-100
- Calls the central dispatcher `APEX` to execute the actual microcode on the FPS-100
- Returns results to the caller

The file contains **24 distinct HSR entry points** that provide mathematical and signal processing functions.

## 2. Calling Convention / Structure

Each routine follows an identical pattern:

```
ROUTINE: MOV (%5)+,%0        ; Get count of parameters
         BEQ NONE             ; If zero, skip parameter loading
         MOV #SLIST,%1        ; Point to local parameter storage
LOOP:    MOV @(%5)+,(%1)+     ; Copy parameter addresses to SLIST
         DEC %0
         BNE LOOP
NONE:    MOV #PARAM,%5        ; Point to parameter block
         JSR %7,APEX          ; Call APEX dispatcher
         RTS %7               ; Return to caller
```

The parameter block structure is:
```
PARAM:  4                     ; Number of parameters in block
        CODE                  ; Microcode entry point number
        START                 ; Starting address in FPS-100 memory
        SLIST                 ; Address of parameter list
        NSPADS                ; Number of pad words in SLIST
```

## 3. Key Routines / Data Structures

**Entry Points (24 total):**

| Routine | Purpose |
|---------|---------|
| `FGEN` | Function generator (generates waveforms) |
| `SKYSOL` | Skyline solver (structural analysis) |
| `TSRBAK` | Triangular solve - backward (real) |
| `TCVMUL` | Triangular complex vector multiply |
| `EIGRS` | Eigenvalue routine (Givens/QR step) |
| `IMTQL2` | Implicit QL algorithm for eigenvalues |
| `SCBAK` | Solve - backward (complex) |
| `SCFWD` | Solve - forward (complex) |
| `SCSFB` | Solve - forward/backward (complex) |
| `SCUFB` | Solve - update/backward (complex) |
| `SRBAK` | Solve - backward (real) |
| `SRFWD` | Solve - forward (real) |
| `SRSFB` | Solve - forward/backward (real) |
| `SRUFB` | Solve - update/backward (real) |
| `TRED2` | Tridiagonal reduction (Householder) |
| `TSCBAK` | Triangular solve - backward (complex) |
| `TSCFWD` | Triangular solve - forward (complex) |
| `TSCSFB` | Triangular solve - forward/backward (complex) |
| `TSCUFB` | Triangular solve - update/backward (complex) |
| `TSRFWD` | Triangular solve - forward (real) |
| `TSRSFB` | Triangular solve - forward/backward (real) |
| `TSRUFB` | Triangular solve - update/backward (real) |

**Data Structures:**
- `SLIST`: Variable-length parameter list (size determined by `NSPADS`)
- `START`: Starting address for microcode execution (typically 0)
- `CODE`: Microcode entry point number (e.g., 442 for FGEN, 364 for SKYSOL, 33 for TSRBAK, 17 for TCVMUL)
- `NSPADS`: Number of pad words (ranges from 3 to 8 in the excerpt)

## 4. External Dependencies

- **`APEX`**: The central dispatcher routine (called via `JSR %7,APEX`). This is the core interface to the FPS-100 hardware, responsible for:
  - Loading microcode into the FPS-100
  - Setting up DMA transfers
  - Executing the microcode
  - Handling completion/interrupts

- **Register conventions**: Uses PDP-11 registers `%0`, `%1`, `%5`, `%7` (R0, R1, R5, PC) following standard FPS-100 calling conventions

- **No RSX-11M directives**: The routines themselves don't call any RSX-11M system directives (like `ALUN$`, `ATTACH`, `QIO$`). These are handled by `APEX`.

## 5. Subtleties

1. **Microcode format**: The `CODE` data blocks contain raw APAL microcode words (48-bit FPS-100 instructions stored as three 16-bit PDP-11 words each). The microcode is embedded directly in the HSR file rather than being loaded from separate `.STB` files.

2. **Code size variation**: Microcode sizes vary significantly:
   - FGEN: 442 words (largest in excerpt)
   - SKYSOL: 364 words
   - TSRBAK: 33 words (smallest)
   - TCVMUL: 17 words

3. **Parameter passing**: The `SLIST` contains addresses of actual parameters (not values), allowing the FPS-100 to directly access PDP-11 memory via DMA. The `NSPADS` value determines how many address slots are available.

4. **No conditional assembly**: The excerpt shows no `.IF DF FPS100` or similar conditionals, suggesting this file is specific to the FPS-100 (not shared with AP-120B).

5. **Memory layout**: The `START` value is always 0, indicating microcode is loaded starting at FPS-100 program memory address 0. The `CODE` value is the entry point offset within that microcode.

6. **Performance optimization**: The parameter loading loop (`LOOP`) uses auto-increment addressing (`(%5)+`) for efficient parameter traversal, and the `BEQ NONE` optimization skips the loop entirely when no parameters are needed.
```

**GLM (93s):**

```
### Analysis of `[327,010]AMLHSR.MAC` (FPS-100 RSX-11M v3.2)

#### 1. **Purpose**  
This file is a **host service routine (HSR) stub collection** for the FPS-100 array processor. It acts as an interface layer between PDP-11 application code and the FPS-100 microcode. Each stub prepares parameters and invokes the common `APEX` subroutine, which transfers execution to the FPS-100. The file defines entry points for 24 specific FPS-100 microcode programs (e.g., matrix solvers, FFTs), enabling RSX-11M applications to offload computations to the array processor.

#### 2. **Calling Convention / Structure**  
- **Stub Pattern**: All 24 routines follow an identical template:
  ```pdp11
  MOV (%5)+,%0      ; Load parameter count from R5
  BEQ NONE          ; Skip if zero parameters
  MOV #SLIST,%1     ; Setup parameter buffer
LOOP: MOV @(%5)+,(%1)+ ; Copy parameters to SLIST
      DEC %0
      BNE LOOP
NONE: MOV #PARAM,%5  ; Point R5 to microcode data block
      JSR %7,APEX    ; Call FPS-100 host service routine
      RTS %7         ; Return to caller
  ```
- **Data Block Structure**: Each stub is followed by:
  - `PARAM: 4` – Size of parameter block (words).
  - `CODE: <N>` – Word count of the embedded APAL microcode.
  - `START: 0` – Reserved (likely for microcode offsets).
  - `NSPADS: <K>` – Number of parameters (defines SLIST size).
  - `SLIST: .BLKW <K>` – Parameter buffer (filled by stub).
  - Microcode instructions (hex words, e.g., `040000,000000,046000,000000`).

- **Parameter Handling**:  
  - R5 holds the address of the caller's parameter list.
  - `NSPADS` values vary (e.g., 4 for `FGEN`, 8 for `SKYSOL`), dictating `SLIST` size.

#### 3. **Key Routines / Data Structures**  
- **Total Stubs**: 24 (excluding `APEX` itself).  
- **Pattern Summary**: Each stub is a minimal wrapper for one FPS-100 microcode program, stored in the `CODE` section.  
- **Representative Examples**:  
  - `FGEN`: Initializes Fourier generation (FFT-related).  
  - `SKYSOL`: Solves symmetric skyline linear systems.  
  - `TSRBAK`: Performs transpose and matrix backward substitution.  
  - `TCVMUL`: Transposes and complex multiplies vectors.  
  - `TRED2`: Tridiagonalizes a symmetric matrix (eigenvalue prelude).  
- **`APEX`**: Critical external dependency (not defined here). Handles FPS-100 I/O and microcode execution.

#### 4. **External Dependencies**  
- **APEX**: Host service routine for FPS-100 communication (defined elsewhere).  
- **FPS-100 Hardware**: Relies on hardware-specific APAL microcode (stored in `CODE` sections).  
- **RSX-11M Conventions**: Uses standard PDP-11 MACRO-11 calling conventions (R5/R7 registers).  
- **No Direct System Calls**: Stubs avoid RSX services (e.g., `ALUN$`, `ATTACH`); rely on `APEX` for hardware interaction.

#### 5. **Subtleties**  
- **Microcode Embedding**: The `CODE` sections contain compiled APAL microcode (hex words). For example:  
  - `040000,000000,046000,000000` → `LOAD A0, [B0]` (APAL syntax).  
- **Parameter Block Layout**:  
  ```
  PARAM (4 words) + CODE (N words) + START + NSPADS + SLIST (K words)
  ```  
  `PARAM=4` is fixed across stubs, likely signaling the header size to `APEX`.  
- **No Hardware Registers in Host Code**: Stubs manipulate only PDP-11 registers; FPS-100 state is managed entirely by `APEX` and microcode.  
- **Conditional Assembly**: No `.IF DF FPS100` directives seen; assumes FPS-100 target.  
- **Performance**: Stubs are lean (minimal instructions) to minimize overhead for microcode invocation.  
- **`FGENT` Symbol**: Present in exports but unused in the excerpt; may be an unused or future entry point.  

---

### Summary  
This file provides **parameterized entry points** for FPS-100 microcode routines, enabling RSX-11M applications to leverage the array processor for compute-intensive tasks (linear algebra, FFTs). The stubs abstract FPS-100 hardware details by delegating all work to `APEX` and embedded APAL microcode, adhering strictly to PDP-11 calling conventions. The 24 routines cover numerical methods optimized for the FPS-100, with `CODE` sections containing precompiled microcode instructions.
```

### Adversarial pass (final)

**DeepSeek revised (36s):**

```
## Critical Evaluation of Peer Analysis

### Areas of Agreement

1. **File purpose as HSR stub collection** - Correct. The pattern of 24 entry points all calling `APEX` with identical parameter-passing logic is clear.

2. **Stub pattern description** - Accurate. The `MOV (%5)+,%0` / `BEQ NONE` / copy loop / `JSR %7,APEX` pattern is correctly identified.

3. **External dependency on APEX** - Correct. APEX is the critical bridge to FPS-100 hardware.

### Areas of Disagreement or Omission

**1. Misidentification of `PARAM` structure (Critical Error)**
The peer states `PARAM: 4` is "fixed across stubs" and "likely signaling the header size to APEX." This is **wrong**. Looking at the actual code:

```pdp11
PARAM:  4
        CODE
        START
        SLIST
        NSPADS
```

`PARAM` is a **pointer block** passed to `APEX` via R5. The value `4` is the **number of words** in this parameter block (not a fixed header size). The block contains:
- Word 0: `CODE` (address of microcode)
- Word 1: `START` (entry point offset)
- Word 2: `SLIST` (address of parameter list)
- Word 3: `NSPADS` (number of parameters)

This is a standard FPS-100 host interface convention where `APEX` receives a 4-word descriptor.

**2. Misinterpretation of `NSPADS`**
The peer says `NSPADS` "defines SLIST size" but misses that `NSPADS` is **passed as a value** (not an address) in the parameter block. The `.BLKW` at `SLIST` allocates space, but `NSPADS` tells `APEX` how many parameters to expect. These are related but distinct concepts.

**3. Incorrect microcode interpretation**
The claim that `040000,000000,046000,000000` means `LOAD A0, [B0]` is **speculative and likely wrong**. APAL microcode for the FPS-100 is 64 bits wide (two PDP-11 words per instruction). The hex pairs represent:
- First word: control store address / opcode field
- Second word: operand / modifier field

Without the APAL assembler listing, we cannot decode individual instructions. The peer's "translation" is invented.

**4. Missing `START` field significance**
The peer dismisses `START: 0` as "reserved." In FPS-100 convention, `START` is the **microcode entry point offset** (in words from `CODE` base). Value 0 means execution begins at the first microinstruction. Non-zero values would indicate subroutine entry points within the microcode.

**5. `FGENT` symbol analysis is incomplete**
The peer notes `FGENT` is "unused or future" but misses that it's likely a **variant of FGEN** (perhaps "Fourier GENeration Transformed" or with different precision). The symbol exists in `.GLOBL` but has no corresponding `.TITLE` or code block in the excerpt - it may be defined later in the full file.

**6. Missing the `CODE` field semantics**
The peer treats `CODE: 442.` as just a word count. More importantly, this value tells `APEX` how many **microcode words** to load into the FPS-100 program memory. The decimal notation (442., 364., 33., 17.) indicates these are **instruction counts**, not byte counts.

**7. Overlooked register conventions**
The stub pattern uses `%5` (R5) for parameter pointer and `%7` (R7/PC) for return. This is standard PDP-11, but the peer doesn't note that:
- R5 is **caller-provided** (points to argument list)
- The stub **destroys R0, R1, R5** (no preservation)
- This implies callers must save these if needed

**8. Missing the `SKYSOL` microcode structure**
`SKYSOL` has `NSPADS: 8.` and `CODE: 364.` - significantly larger than `TCVMUL` (3 params, 17 words). This reflects the complexity of skyline solver vs. vector multiply. The peer doesn't correlate `NSPADS`/`CODE` sizes with algorithmic complexity.

**9. No discussion of `.TITLE` vs `.GLOBL` relationship**
Each stub has its own `.TITLE` (e.g., `FGEN`, `SKYSOL`, `TSRBAK`), but all `.GLOBL` their own name plus `APEX`. This means:
- Each routine can be linked independently
- `APEX` must be resolved by the linker (defined in another module)
- The `.TITLE` directives create separate object file sections

**10. Missing the significance of `CODE` values in decimal**
The peer doesn't note that `CODE: 442.`, `CODE: 364.`, `CODE: 33.`, `CODE: 17.` use **decimal notation** (trailing dot). This is unusual in MACRO-11 (octal is default) and suggests these counts were derived from the APAL assembler output.

## Final Analysis (Updated)

### 1. Purpose
This file is a **host service routine (HSR) library** for the FPS-100 array processor under RSX-11M. It provides 24 callable entry points that wrap FPS-100 microcode programs with a uniform parameter-passing interface. Each entry point corresponds to a specific numerical algorithm (FFT, linear system solver, eigenvalue routine, etc.) implemented in APAL microcode and stored inline.

### 2. Calling Convention / Structure

**Uniform Stub Pattern** (all 24 routines):
```pdp11
routine: MOV (%5)+,%0      ; Get parameter count from caller's list
         BEQ NONE           ; Handle zero-parameter case
         MOV #SLIST,%1      ; Point to local parameter buffer
LOOP:    MOV @(%5)+,(%1)+   ; Copy parameter addresses/values
         DEC %0
         BNE LOOP
NONE:    MOV #PARAM,%5      ; Point R5 to 4-word descriptor block
         JSR %7,APEX        ; Transfer to FPS-100 via APEX
         RTS %7             ; Return to caller
```

**Descriptor Block Layout** (4 words, pointed to by R5):
| Offset | Field | Description |
|--------|-------|-------------|
| 0 | `CODE` | Address of microcode instruction array |
| 1 | `START` | Entry point offset within microcode (0 = start) |
| 2 | `SLIST` | Address of parameter buffer |
| 3 | `NSPADS` | Number of parameters (as a value, not address) |

**Memory Layout After Each Stub**:
```
PARAM:  4              ; Descriptor block size (always 4)
        CODE           ; Address of CODE label
        START          ; Address of START label  
        SLIST          ; Address of SLIST label
        NSPADS         ; Address of NSPADS label
NSPADS: <decimal>      ; Parameter count value
SLIST:  .BLKW <NSPADS> ; Parameter buffer
START:  0.             ; Entry offset (usually 0)
CODE:   <decimal>      ; Microcode word count
        <hex words>    ; APAL microcode (64-bit instructions)
```

### 3. Key Routines / Data Structures

**24 Entry Points** (all follow same pattern):

| Routine | NSPADS | CODE Words | Algorithm Area |
|---------|--------|------------|----------------|
| FGEN | 4 | 442 | Fourier generation |
| SKYSOL | 8 | 364 | Skyline solver |
| TSRBAK | 5 | 33 | Transpose back-substitution |
| TCVMUL | 3 | 17 | Complex vector multiply |
| TRED2 | (not shown) | - | Tridiagonal reduction |
| IMTQL2 | (not shown) | - | Implicit QL iteration |
| EIGRS | (not shown) | - | Eigenvalues (real symmetric) |
| SRBAK, SRFWD, SRSFB, SRUFB | - | - | Real system solvers |
| SCBAK, SCFWD, SCSFB, SCUFB | - | - | Complex system solvers |
| TSCBAK, TSCFWD, TSCSFB, TSCUFB | - | - | Transposed complex solvers |
| TSRBAK, TSRFWD, TSRSFB, TSRUFB | - | - | Transposed real solvers |
| APEX | (external) | - | Common FPS-100 driver |

**APEX**: External routine (not in this file) that handles:
- Loading microcode into FPS-100 program memory
- Setting up data memory pointers
- Initiating execution
- Handling completion/interrupts

### 4. External Dependencies

- **APEX**: Required external symbol; the actual FPS-100 device driver
- **Caller conventions**: R5 points to argument list; R0,R1,R5 destroyed
- **No RSX directives**: All system interaction goes through APEX
- **No hardware register access**: FPS-100 registers managed by APEX

### 5. Subtleties

1. **Decimal notation for counts**: `CODE: 442.`, `NSPADS: 8.` use MACRO-11 decimal (trailing dot), indicating these values came from the APAL assembler or were calculated, not hand-written in octal.

2. **START field always 0**: All stubs use `START: 0.`, meaning execution begins at the first microinstruction. Non-zero would allow multiple entry points within one microcode block.

3. **Parameter passing by address**: The stub copies `@(%5)+` (indirect through R5) to SLIST. This means the caller's argument list contains **addresses** of parameters, not values - standard PDP-11 indirect calling convention.

4. **No parameter validation**: The stubs trust the caller's count (from `(%5)+`). If caller lies, the copy loop will corrupt memory beyond SLIST.

5. **Microcode size variation**: Ranges from 17 words (TCVMUL) to 442 words (FGEN), reflecting the complexity of the algorithm. The FPS-100 had limited program memory (~4K words), so larger routines like FGEN are significant.

6. **NSPADS determines SLIST size**: The `.BLKW` allocation matches `NSPADS`, but the stub copies exactly the number of words the caller specified (not NSPADS). This allows callers to pass fewer parameters than the maximum.

7. **No conditional assembly**: Unlike some FPS-100 files, this one has no `.IF DF FPS100` or AP-120B compatibility switches, suggesting it's FPS-100 specific.

8. **`FGENT` anomaly**: Exported but no corresponding code in excerpt - likely defined later in the full file or is a forward reference for a routine that shares FGEN's microcode with a different entry point.
```

**GLM revised (86s):**

```
# Analysis of `[327,010]AMLHSR.MAC`

## Evaluation of Peer Analysis

I find the peer's analysis largely accurate, but with a few areas that need refinement or additional detail:

### Agreements:
1. **Purpose**: Correctly identified as a collection of HSRs for the FPS-100 array processor.
2. **Calling Convention**: The pattern described is accurate and matches the code structure.
3. **Key Routines**: The 24 entry points listed match the .GLOBL exports, and descriptions are reasonable.
4. **External Dependencies**: Correctly identifies APEX as the central dispatcher and absence of direct RSX-11M directives.
5. **Microcode Format**: Correctly identifies the embedded APAL microcode words.
6. **Performance Optimization**: Correctly identifies the BEQ NONE optimization.

### Disagreements/Additions:
1. **Microcode Loading**: The peer states "the microcode is embedded directly in the HSR file rather than being loaded from separate .STB files." This is partially incorrect - in typical FPS-100 systems, microcode is indeed loaded from separate .STB files. However, this implementation appears to embed the microcode directly, suggesting either a special case or preloading mechanism.

2. **Parameter Structure**: The peer doesn't explicitly mention the fixed parameter count (always "4" in the excerpt) which is significant for understanding the interface design.

3. **FPS-100 vs AP-120B**: The peer notes the absence of conditional assembly but doesn't discuss potential behavioral differences between the systems.

4. **Hardware Integration**: The peer doesn't address how the microcode interacts with FPS-100 hardware registers, which is a key aspect of these implementations.

## Final Analysis

### 1. Purpose
This file is a **collection of Host Service Routines (HSRs)** for the FPS-100 array processor, serving as the primary interface between the PDP-11 host (running RSX-11M) and the FPS-100 hardware. Each routine acts as a standardized wrapper that:
- Accepts parameters via register %5 using the FPS-100 calling convention
- Builds a parameter list for the FPS-100
- Calls the central APEX dispatcher to execute microcode
- Returns control to the host

The file contains **24 distinct HSR entry points** providing mathematical and signal processing functions for scientific and engineering applications.

### 2. Calling Convention / Structure
Each routine follows an identical pattern:
```
ROUTINE: MOV (%5)+,%0        ; Get parameter count
         BEQ NONE             ; Skip if zero parameters
         MOV #SLIST,%1        ; Point to parameter storage
LOOP:    MOV @(%5)+,(%1)+     ; Copy parameter addresses
         DEC %0
         BNE LOOP
NONE:    MOV #PARAM,%5        ; Point to parameter block
         JSR %7,APEX          ; Call dispatcher
         RTS %7               ; Return
```

All routines use a **fixed parameter block structure**:
```
PARAM:  4                     ; Fixed parameter count
        CODE                  ; Microcode entry point
        START                 ; FPS-100 memory address
        SLIST                 ; Parameter list address
        NSPADS                ; Number of pad words
```

### 3. Key Routines / Data Structures

**Entry Points (24 total):**

| Routine | Purpose |
|---------|---------|
| `FGEN` | Function generator (creates waveforms) |
| `SKYSOL` | Skyline solver (structural analysis) |
| `TSRBAK` | Triangular solve - backward (real) |
| `TCVMUL` | Triangular complex vector multiply |
| `EIGRS` | Eigenvalue routine (Givens/QR) |
| `IMTQL2` | Implicit QL algorithm for eigenvalues |
| `SCBAK/SCFWD/SCSFB/SCUFB` | Complex solve routines |
| `SRBAK/SRFWD/SRSFB/SRUFB` | Real solve routines |
| `TSCBAK/TSCFWD/TSCSFB/TSCUFB` | Triangular complex solve |
| `TSRFWD/TSRSFB/TSRUFB` | Triangular real solve |
| `TRED2` | Tridiagonal reduction (Householder) |

**Data Structures:**
- `SLIST`: Variable-length parameter list (size determined by NSPADS, 3-8 words in excerpt)
- `START`: Always 0 (FPS-100 memory offset)
- `CODE`: Microcode entry point (17-442 words in excerpt)
- `NSPADS`: Number of parameter address slots

### 4. External Dependencies
- **APEX**: Central dispatcher for FPS-100 operations
- **Register conventions**: Uses %0 (R0), %1 (R1), %5 (R5), %7 (PC) per FPS-100 standard
- **No direct RSX-11M system calls**: Interface is handled entirely through APEX
- **Hardware integration**: Embedded microcode interacts directly with FPS-100 registers

### 5. Subtleties
1. **Embedded Microcode**: Unlike typical FPS-100 systems using separate .STB files, this implementation embeds microcode directly in the HSR files, suggesting either a special deployment model or preloading mechanism.

2. **Fixed Parameter Count**: All routines use exactly 4 parameters in their parameter block, indicating a standardized interface design despite varying operational needs.

3. **Microcode Size Variation**: Ranges from 17 words (TCVMUL) to 442 words (FGEN), reflecting computational complexity differences.

4. **Memory Layout**: START is always 0, indicating microcode is loaded at FPS-100 address 0, with CODE specifying the entry offset.

5. **DMA Access**: SLIST contains addresses, not values, enabling direct PDP-11 memory access via DMA transfers.

6. **Performance Optimization**: Uses auto-increment addressing for parameter copying and conditional branch to skip parameter handling when unnecessary.

7. **Hardware Register Access**: The embedded microcode contains instructions that directly manipulate FPS-100 hardware registers for computation and control, with no abstraction layer visible in the host code.
```

## [327,010]BAAHSR.MAC

- 4448 lines (excerpted)
- 89 exported symbols
- exports: `APEX, CDOTPR, CRVADD, CRVDIV, CRVMUL, CRVSUB, CVADD, CVCOMB, CVCONJ, CVEXP, CVFILL, CVMA, CVMAGS, CVMEXP, CVMOV, CVMUL, CVNEG, CVRCIP, CVREAL, CVSMUL, CVSUB, DOTPR, MAXMGV, MAXV, MEAMGV, MEANV, MEASQV, MINMGV, MINV, POLAR, ...`

### Cooperative pass

**DeepSeek (23s):**

```
Based on the provided excerpt of `[327,010]BAAHSR.MAC` from the FPS-100 RSX-11M distribution, here is the structured analysis:

## 1. Purpose

This file is a **Host Service Routine (HSR) wrapper library** for the FPS-100 array processor. It provides a collection of PDP-11 MACRO-11 subroutines that serve as the host-side entry points for vector/matrix math operations executed on the FPS-100. Each subroutine follows an identical pattern: it marshals arguments from the caller's parameter block into a local scratch area (`SLIST`), then calls the central dispatcher `APEX` to load and execute the corresponding APAL microcode on the FPS-100.

The file is not a driver, device table, or sysgen configuration module. It is a **stub library** that translates PDP-11 subroutine calls into FPS-100 operations, forming the high-level host interface layer of the FPS-100 software stack.

## 2. Calling Convention / Structure

Every subroutine in this file follows an identical pattern:

**Entry Protocol:**
1. `MOV (%5)+,%0` — Load argument count from the caller's parameter list (R5 points to a standard FORTRAN/RSX argument list)
2. `BEQ NONE` — If zero arguments, skip to dispatch
3. `MOV #SLIST,%1` — Point R1 to local scratch buffer
4. `LOOP: MOV @(%5)+,(%1)+` — Copy each argument pointer into SLIST
5. `DEC %0` / `BNE LOOP` — Loop for all arguments
6. `NONE: MOV #PARAM,%5` — Point R5 to the parameter block
7. `JSR %7,APEX` — Call the central dispatcher
8. `RTS %7` — Return to caller

**Parameter Block Structure (immediately after each subroutine):**
- `PARAM: 4` — Number of parameters in the block (always 4 for these stubs)
- `CODE` — Address of the APAL microcode data block
- `START` — Starting microcode address (always 0 for these)
- `SLIST` — Address of the scratch argument list
- `NSPADS` — Number of words allocated for SLIST
- `SLIST: .BLKW N` — Scratch buffer for argument pointers
- `START: 0.` — Starting address (decimal 0)
- `CODE: N.` — Number of 4-word microcode instructions
- Followed by the microcode data (4 words per instruction)

## 3. Key Routines / Data Structures

**Entry Points (89 total, based on export list):**

The file contains a large collection of vector/matrix math stubs. Representative examples from the excerpt:

| Routine | Purpose |
|---------|---------|
| `CVADD` | Complex vector addition |
| `CVSUB` | Complex vector subtraction |
| `CVMUL` | Complex vector multiplication |
| `CVMAGS` | Complex vector magnitude squared |
| `CVCONJ` | Complex vector conjugate |
| `CVMA` | Complex vector multiply-accumulate |
| `SCJMA` | Scalar-complex join multiply-accumulate |
| `VAAM` | Vector add-accumulate-multiply |
| `VSBSBM` | Vector subtract-accumulate-multiply |
| `VAND` | Vector logical AND |
| `VEQV` | Vector logical equivalence |
| `XMAXMG` | Vector maximum magnitude |
| `XMINMG` | Vector minimum magnitude |

**Key Data Structures:**

- **`APEX`** — Central dispatcher subroutine (external, not defined in this file). Handles loading microcode, setting up FPS-100 data memory, and initiating execution.
- **`SLIST`** — Per-routine scratch buffer for argument pointers, sized by `NSPADS`
- **`PARAM`** — Parameter block passed to APEX containing microcode address, start location, and argument list pointer
- **`CODE`** — Microcode instruction words (4 per instruction, format: `opcode, dest, src1, src2` in FPS-100 APAL format)

## 4. External Dependencies

- **`APEX`** — The central dispatcher routine (called via `JSR %7,APEX`). This is the only external subroutine call. APEX presumably handles:
  - FPS-100 initialization and synchronization
  - Loading microcode into the FPS-100 program memory
  - Setting up data memory pointers
  - Initiating execution
  - Handling completion and errors
  
- **Register conventions:**
  - `%5` (R5) — Argument list pointer (standard RSX-11M FORTRAN calling convention)
  - `%7` (R7/PC) — Return address for JSR
  - `%0` (R0) — Argument count
  - `%1` (R1) — Scratch pointer for argument copying

## 5. Subtleties

1. **Microcode format:** Each instruction is 4 words (64 bits), matching the FPS-100's 64-bit microinstruction word. The format appears to be: `word0=opcode/control, word1=destination, word2=source1, word3=source2`, consistent with FPS-100 APAL conventions.

2. **Code size variation:** The `CODE:` value indicates the number of 4-word microinstructions. Ranges from 10 (CVCONJ) to 30 (CVMA), reflecting operation complexity.

3. **Scratch buffer sizing:** `NSPADS` varies per routine (4-11 words), sized to hold all argument pointers plus any temporary workspace needed by APEX.

4. **No conditional assembly:** The excerpt shows no `.IF DF FPS100` or similar conditionals. This is a pure FPS-100 implementation with no AP-120B compatibility branching visible.

5. **All microcode starts at address 0:** The `START: 0.` field indicates all routines load their microcode starting at FPS-100 program memory address 0, suggesting APEX handles loading and possibly manages multiple concurrent microcode images.

6. **No error handling visible:** The stubs assume successful argument marshaling and APEX execution. No error checking or status return is implemented in the stubs themselves.

7. **Total count:** Based on the export list showing 89 symbols and the consistent pattern, this file contains approximately 89 vector/matrix operation stubs, each with its own microcode block.
```

**GLM (110s):**

```
### Analysis of `BAAHSR.MAC`

#### 1. **Purpose**
This file is a **collection of Host Service Routine (HSR) stubs** for the FPS-100 array processor. It acts as a bridge between PDP-11 application software and the FPS-100 microcode, translating high-level vector/scalar operations into direct FPS-100 microcode instructions. The routines handle argument marshaling, memory preparation, and invocation of the APEX (Array Processor Executive) firmware entry point. The file is **not** a driver, device table, or sysgen config but a **pre-compiled microcode library** for FPS-100 acceleration.

---

#### 2. **Calling Convention / Structure**
Each routine follows a **rigid stub pattern**:
- **Entry**: Takes vector arguments via `R5` (stack pointer), where `(R5)+` = number of vectors.
- **Argument Copying**:
  - If vector count = 0, jumps directly to `NONE`.
  - Otherwise, copies vector addresses from stack to `SLIST` (a temporary buffer).
- **APEX Invocation**: Sets up microcode parameters in `R5` (always `4`) and calls `APEX` (common entry point).
- **Microcode**: Embedded `CODE` section contains FPS-100 microinstructions (4-word opcodes).
- **Data Structures**:
  - `SLIST`: Temporary storage for vector addresses (size varies per routine).
  - `NSPADS`: Constant (floating-point value) used in microcode as a memory size/offset.
  - `START`: Always `0.` (microcode start address).
- **Return**: Standard PDP-11 `RTS %7`.

**Example Structure (CVADD)**:
```assembly
CVADD : MOV (%5)+,%0      ; Get vector count
        BEQ NONE         ; Skip if zero vectors
        MOV #SLIST,%1    ; Point to SLIST
LOOP:   MOV @(%5)+,(%1)+ ; Copy vector addresses
        DEC %0
        BNE LOOP
NONE:   MOV #PARAM,%5    ; Set parameter count (4)
        JSR %7,APEX      ; Call APEX
        RTS %7
PARAM:  4
CODE:   <microcode>
START:  0.
SLIST:  .BLKW 7         ; Buffer for addresses
NSPADS: 7.             ; Microcode parameter
```

---

#### 3. **Key Routines / Data Structures**
**Total Routines**: 89 (all follow the stub pattern).  
**Representative Examples**:
| Routine | Purpose | `NSPADS` | `SLIST` Size |
|---------|---------|----------|--------------|
| **CVADD**  | Complex vector addition (`z = x + y`) | `7.` | `7` words |
| **CVMUL**  | Complex vector multiplication (`z = x * y`) | `8.` | `8` words |
| **CVMAGS** | Complex vector magnitude (`|z|`) | `5.` | `5` words |
| **VAND**   | Vector logical AND | `7.` | `7` words |
| **SCJMA**  | Scalar-complex multiplication (output mag/angle) | `11.` | `11` words |

**Data Structures**:
- `SLIST`: Buffer for vector addresses (size varies per operation).
- `NSPADS`: Floating-point constant interpreted by microcode (e.g., vector size).
- `CODE`: Microcode instructions (4-word opcodes for FPS-100).

---

#### 4. **External Dependencies**
- **APEX**: Central entry point for FPS-100 microcode (routine name is global).
- **FPS-100 Hardware**: Microcode opcodes (e.g., `040000`=LOAD, `020100`=STORE) target FPS-100 registers and memory.
- **RSX-11M Conventions**: Uses standard PDP-11 calling (`R5` for arguments, `R7` for return) and stack operations.
- **No RSX Kernel Calls**: Direct hardware communication; no `ALUN$`, `ATTACH`, or `GTPKT` dependencies.

---

#### 5. **Subtleties**
- **Microcode Constants**: `NSPADS` values (e.g., `7.`, `8.`) are **floating-point literals** (e.g., `7.` = `16#00070000`). Used by FPS-100 microcode as offsets or sizes.
- **Operand Count**: All stubs set `PARAM=4`, implying APEX expects a fixed set of arguments (likely `SLIST`, `NSPADS`, and others).
- **Vector Handling**: Operations like `CVADD` use `NSPADS=7` for 3 vectors (2 inputs + 1 output), but `SLIST` is sized to match microcode data access, not vector count.
- **Conditional Assembly**: Conditional directives (e.g., `.IF DF FPS100`) appear elsewhere in the distribution but are **not visible here**. This file likely assumes FPS-100 hardware.
- **Performance**: Minimal host CPU work; delegates heavy lifting to FPS-100 microcode.
- **Hardware Layout**: Microcode uses FPS-100’s memory model (e.g., `SLIST` as a base for vector access, `NSPADS` for indexing).

--- 

### Summary
`BAAHSR.MAC` is a **microcode interface library** for FPS-100 acceleration routines. Each stub marshals PDP-11 vector arguments into FPS-100 memory, invokes the APEX microcode, and leverages embedded microcode instructions. The design prioritizes efficiency by minimizing host involvement and deferring computation to the array processor. Key constants (`NSPADS`, `START`) are critical for FPS-100 memory addressing.
```

### Adversarial pass (final)

**DeepSeek revised (23s):**

```
## Critical Evaluation of Peer Analysis

### Areas of Agreement

1. **File purpose**: Correctly identifies this as a collection of HSR stubs bridging PDP-11 applications to FPS-100 microcode.

2. **Calling convention**: Accurately describes the argument marshaling pattern via R5, SLIST buffer, and APEX invocation.

3. **External dependencies**: Correctly notes APEX as the central entry point and absence of RSX kernel directives.

### Areas of Disagreement / Corrections

1. **"Pre-compiled microcode library"** — This is misleading. The file contains **PDP-11 MACRO-11 assembly source** that embeds raw microcode data words. It is compiled by MACRO-11, not pre-compiled microcode. The microcode is loaded into FPS-100 memory at runtime by APEX.

2. **"NSPADS is a floating-point constant"** — **Wrong.** `NSPADS` is declared as `.BLKW 7.` in SLIST, but the value `7.` is a **decimal integer** (octal 7, hex 000007). The `.` suffix in MACRO-11 denotes decimal radix. It is **not** a floating-point literal. The FPS-100 microcode interprets this as an integer count or offset, not a floating-point number.

3. **"NSPADS values (e.g., 7., 8.) are floating-point literals (e.g., 7. = 16#00070000)"** — **Incorrect.** In MACRO-11, `7.` is decimal 7, stored as a 16-bit integer (000007 octal). The hex value 00070000 would be a 32-bit floating-point representation, but the PDP-11 stores 16-bit words. The microcode likely interprets this as a count or address offset, not a floating-point operand.

4. **"Operand Count: All stubs set PARAM=4"** — **Partially wrong.** `PARAM: 4` is not a parameter count; it's the **address of the parameter block** passed to APEX. The value `4` is the offset from the start of the parameter block to the CODE section. The actual parameter block structure is:
   - `PARAM+0`: CODE address
   - `PARAM+2`: START address
   - `PARAM+4`: SLIST address
   - `PARAM+6`: NSPADS value

5. **"SLIST size matches microcode data access, not vector count"** — **Vague and potentially wrong.** SLIST size directly corresponds to the number of vector arguments the microcode needs. For CVADD (3 vectors: 2 input, 1 output), SLIST is 7 words because the microcode also stores temporary values or control information alongside the vector addresses.

6. **"NSPADS: Floating-point constant interpreted by microcode (e.g., vector size)"** — **Unsubstantiated.** The microcode likely uses NSPADS as a **loop count** or **stride**, not a vector size. The FPS-100 vector length is typically passed separately via the APEX parameter block.

7. **Missing critical detail**: The analysis doesn't mention that `CODE` contains **APAL microcode** (4-word instructions) for the FPS-100's **pipeline architecture**. The first word (e.g., `040000`) is the opcode, and subsequent words are operands/addresses.

8. **"No RSX Kernel Calls"** — **Oversimplification.** While this file doesn't make kernel calls, the HSR mechanism itself is an RSX-11M construct. The file is loaded as part of the FPS-100 device driver's HSR table, and APEX likely handles the kernel interface.

9. **Missing the HSR table structure**: The file doesn't show the HSR table header (typically `.WORD` entries mapping function codes to routine addresses). The 89 routines are likely indexed by a separate table not shown in this excerpt.

### Final Analysis

**BAAHSR.MAC** is a **Host Service Routine (HSR) source file** for the FPS-100 array processor under RSX-11M. It contains 89 entry points, each implementing a vector/scalar operation by:

1. **Marshaling arguments** from the PDP-11 stack (R5) into a local SLIST buffer
2. **Invoking APEX** with a parameter block pointing to embedded FPS-100 microcode
3. **Returning** to the caller via RTS R7

**Key data structures:**
- **SLIST**: Variable-length buffer (4-11 words) holding vector addresses and temporary storage
- **NSPADS**: Integer constant (decimal) used by microcode as count/offset
- **CODE**: APAL microcode instructions (4-word format) for the FPS-100 pipeline
- **START**: Always 0 (microcode execution starts at address 0 in FPS-100 memory)

**Microcode format** (4 words per instruction):
- Word 0: Opcode (e.g., `040000` = LOAD, `020100` = STORE)
- Words 1-3: Operands (register addresses, memory offsets, control bits)

**Notable patterns:**
- Complex operations (CVADD, CVMUL) use larger SLIST (7-8 words) than real operations (VADD uses 5 words)
- Logical operations (VAND, VEQV) include additional microcode for bit manipulation
- The `040000` opcode at the start of each CODE section is likely a NOP or initialization instruction
- `000340` at the end of most CODE sections is a HALT/END instruction

**External dependencies:**
- **APEX**: FPS-100 firmware entry point (handles microcode loading and execution)
- **FPS-100 hardware**: Direct microcode execution on the array processor
- **RSX-11M HSR framework**: The file is part of the device driver's HSR table, though no kernel calls appear in the source

**Correction to peer analysis:** The file is not a "pre-compiled microcode library" but a **PDP-11 assembly source** that embeds microcode data. NSPADS values are decimal integers, not floating-point constants. PARAM=4 is a parameter block address, not a count. The analysis overstates the role of floating-point interpretation where integer values are clearly intended.
```

**GLM revised (68s):**

```
## Evaluation of Peer Analysis

### Agreement with Peer Analysis

The peer's analysis is fundamentally correct and well-structured. I agree with their identification of:
1. The file's purpose as an HSR wrapper library for FPS-100 operations
2. The consistent subroutine pattern (argument marshalling → APEX call)
3. The parameter block structure
4. The key data structures (APEX, SLIST, PARAM, CODE)
5. The external dependencies (APEX as central dispatcher)
6. Most of the subtleties (microcode format, code size variation, scratch buffer sizing)

### Disagreements and Missing Points

1. **Microcode Format Assumption**:  
   The peer states "Each instruction is 4 words (64 bits), matching the FPS-100's 64-bit microinstruction word. The format appears to be: `word0=opcode/control, word1=destination, word2=source1, word3=source2`."  
   **Issue**: This is an assumption not verifiable from the given code. The peer is extrapolating from FPS-100 architecture knowledge rather than analyzing the visible code patterns. While likely correct, it should be presented as such.

2. **Missing Assembly Directives**:  
   The peer states "No conditional assembly (.IF DF FPS100)..." but the actual file (which we only see an excerpt of) would typically contain these directives for different FPS configurations. The absence in the excerpt doesn't prove their absence in the full file.

3. **Performance Optimization Oversight**:  
   The peer misses that the fixed-size SLIST buffers (.BLKW with NSPADS values) represent a deliberate optimization to avoid dynamic memory allocation. This is a significant design choice for performance-critical math routines.

4. **Hardware Interaction Detail**:  
   While APEX is correctly identified as the dispatcher, the peer doesn't note that the stubs interact with FPS-100 through memory-mapped registers that would be accessed by APEX, not directly by these stubs.

### My Final Updated Analysis

## 1. Purpose
This file is a **Host Service Routine (HSR) wrapper library** for the FPS-100 array processor. It provides PDP-11 MACRO-11 subroutines that serve as the host-side entry points for vector/matrix math operations executed on the FPS-100. These stubs form the high-level interface between PDP-11 applications and the FPS-100's APAL microcode execution engine.

## 2. Calling Convention / Structure
Each subroutine follows an identical pattern optimized for minimal overhead:

**Entry Protocol:**
1. `MOV (%5)+,%0` - Load argument count from caller's parameter list (R5)
2. `BEQ NONE` - Skip if zero arguments
3. `MOV #SLIST,%1` - Point R1 to local scratch buffer
4. `LOOP: MOV @(%5)+,(%1)+` - Copy argument pointers into SLIST
5. `DEC %0`/`BNE LOOP` - Process all arguments
6. `NONE: MOV #PARAM,%5` - Set up parameter block for APEX
7. `JSR %7,APEX` - Call central dispatcher
8. `RTS %7` - Return to caller

**Parameter Block Structure (immediately after each subroutine):**
- `PARAM: 4` - Parameter count (always 4)
- `CODE` - APAL microcode data block address
- `START` - Starting microcode address (always 0)
- `SLIST` - Scratch buffer address
- `NSPADS` - Number of words allocated for SLIST
- `SLIST: .BLKW N` - Argument pointer storage
- `START: 0.` - Decimal starting address
- `CODE: N.` - Number of 4-word microcode instructions
- Microcode instruction data (4 words each)

## 3. Key Routines / Data Structures
**Entry Points (89 total):**
The file contains vector/matrix operation stubs with representative examples:

| Routine | Purpose |
|---------|---------|
| `CVADD` | Complex vector addition |
| `CVSUB` | Complex vector subtraction |
| `CVMUL` | Complex vector multiplication |
| `CVMAGS` | Complex vector magnitude squared |
| `CVMA` | Complex vector multiply-accumulate |
| `VAND` | Vector logical AND |
| `XMAXMG` | Vector maximum magnitude |
| `SCJMA` | Scalar-complex join multiply-accumulate |
| `VAAM` | Vector add-accumulate-multiply |

**Key Data Structures:**
- `APEX` - Central dispatcher (handles FPS-100 interaction, microcode loading, execution)
- `SLIST` - Per-routine scratch buffer (size varies by operation complexity)
- `PARAM` - Parameter block for APEX (contains metadata for microcode execution)
- `CODE` - APAL microcode instructions (variable length, 4 words each)

## 4. External Dependencies
- `APEX` - Only external dependency; central dispatcher that:
  - Manages FPS-100 hardware registers
  - Loads microcode into program memory
  - Sets up data memory pointers
  - Coordinates execution with FPS-100
  
- **Register Conventions:**
  - `%5` (R5) - Argument list pointer (RSX-11M standard)
  - `%7` (R7/PC) - Return address for JSR
  - `%0` (R0) - Argument count
  - `%1` (R1) - Scratch pointer for argument copying

- **FPS-100 Hardware:**
  - Memory-mapped registers (handled by APEX, not directly by stubs)
  - APAL microcode execution engine

## 5. Subtleties
1. **Microcode Format**: Each instruction is 4 words (64 bits), with likely format: `opcode/control, destination, source1, source2` (based on FPS-100 APAL conventions, not directly visible in code).

2. **Code Size Variation**: `CODE:` value ranges from 10 (CVCONJ) to 30 (CVMA), reflecting operation complexity.

3. **Scratch Buffer Sizing**: `NSPADS` varies (4-11 words), sized to hold argument pointers and any workspace needed by APEX.

4. **Performance Optimization**: Fixed-size SLIST buffers represent deliberate optimization to avoid dynamic memory allocation in performance-critical math routines.

5. **Hardware Abstraction**: Stub intentionally abstract away hardware details, delegating all FPS-100 interaction to APEX for cleaner host interface.

6. **Error Handling**: No error checking in stubs; assumes successful argument marshaling and APEX execution. Error handling likely occurs in APEX or at hardware level.

7. **Microcode Loading**: All routines specify `START: 0.`, suggesting APEX manages loading and may program multiple concurrent microcode images or handle address translation.

8. **Conditional Assembly**: Full file likely contains `.IF DF FPS100` directives for different FPS configurations, not visible in this excerpt.

The file represents a carefully designed interface between PDP-11 applications and the FPS-100 accelerator, with stubs optimized for minimal overhead while maintaining clean separation between host interface and hardware management.
```

## [327,010]BABHSR.MAC

- 4576 lines (excerpted)
- 61 exported symbols
- exports: `APEX, CFFT, CFFTB, CFFTSC, CONV, CTRN3, DAREAD, DAWRIT, DEQ22, FMMM, FMMM32, LVEQ, LVGE, LVGT, LVNE, LVNOT, MATINV, MDCOM, MMUL, MMUL32, MTRANS, MVML3, MVML4, RDC5, RFFT, RFFTB, RFFTSC, SETC5, SOLVEQ, VCLIP, ...`

### Cooperative pass

**DeepSeek (34s):**

```
Based on the provided excerpt of `BABHSR.MAC` (4576 lines total, 61 exported symbols), here is the structured analysis:

## 1. Purpose

This file is a **Host Service Routine (HSR) wrapper library** for the FPS-100 array processor. It provides the PDP-11 side of the host-AP software interface, translating high-level vector/matrix subroutine calls into parameter blocks that are passed to the FPS-100's APEX executive microcode.

Each entry point in this file:
- Accepts arguments via the standard FPS-100 calling convention (register R5 points to an argument list)
- Copies the argument list into a local parameter block (`SLIST`)
- Calls the central dispatcher `APEX` (also declared `.GLOBL` in this file)
- Returns to the caller

The file acts as a **stub collection** — it does not contain the actual array processor algorithms, but rather the host-side glue code that packages parameters and invokes the APEX microcode interpreter. The actual FPS-100 microcode (APAL) is embedded as raw data words in the `CODE` blocks.

## 2. Calling Convention / Structure

Every entry point follows an identical pattern:

```
ENTRY:  MOV (%5)+,%0        ; Get argument count from R5 list
        BEQ NONE             ; If zero, skip argument copy
        MOV #SLIST,%1        ; Point to local parameter storage
LOOP:   MOV @(%5)+,(%1)+     ; Copy each argument word
        DEC %0
        BNE LOOP
NONE:   MOV #PARAM,%5        ; Point R5 to parameter block
        JSR %7,APEX          ; Call APEX dispatcher
        RTS %7               ; Return to caller
```

The parameter block structure (at label `PARAM`) is:
```
PARAM:  4                    ; Number of parameters following
        CODE                 ; Address of microcode data block
        START                ; Starting address within microcode
        SLIST                ; Address of copied argument list
        NSPADS               ; Number of pad words in SLIST
```

The `SLIST` area is sized per routine (`.BLKW` with varying counts from 1 to 9) and holds the copied arguments plus any necessary padding.

## 3. Key Routines / Data Structures

### Entry Points (61 total, all follow the same pattern)

**Vector Operations (10):**
- `VMAX` - Find maximum element in vector
- `VMIN` - Find minimum element in vector
- `VSUM` - Sum vector elements
- `VSCALE` - Scale vector by scalar
- `VCLIP` - Clip vector values to range
- `VICLIP` - Integer clip vector values
- `VLIM` - Limit vector values
- `VLMERG` - Merge two vectors based on condition
- `VSHFX` - Shift vector elements
- `VSIMPS` - Simpson's rule integration

**Vector Comparison (5):**
- `LVGT` - Logical vector greater-than comparison
- `LVGE` - Logical vector greater-or-equal comparison
- `LVEQ` - Logical vector equality comparison
- `LVNE` - Logical vector not-equal comparison
- `LVNOT` - Logical vector NOT

**Matrix Operations (6):**
- `MMUL` - Matrix multiply (32-bit)
- `MMUL32` - Matrix multiply (32-bit, alternate)
- `MTRANS` - Matrix transpose
- `MATINV` - Matrix inversion
- `MVML3` - Matrix-vector multiply (3x3)
- `MVML4` - Matrix-vector multiply (4x4)

**FFT Operations (5):**
- `RFFT` - Real FFT
- `RFFTB` - Real FFT (bit-reversed)
- `RFFTSC` - Real FFT with scaling
- `CFFT` - Complex FFT
- `CFFTB` - Complex FFT (bit-reversed)
- `CFFTSC` - Complex FFT with scaling

**Conversion/Format (8):**
- `VFIX` - Float to integer conversion
- `VFIX32` - Float to 32-bit integer
- `VFLT` - Integer to float conversion
- `VFLT32` - 32-bit integer to float
- `VPK16` - Pack to 16-bit
- `VPK8` - Pack to 8-bit
- `VUP16` - Unpack from 16-bit
- `VUP8` - Unpack from 8-bit
- `VUPS16` - Unpack and scale from 16-bit
- `VUPS8` - Unpack and scale from 8-bit

**I/O and Control (6):**
- `DAREAD` - Read from FPS-100 data memory
- `DAWRIT` - Write to FPS-100 data memory
- `XDAREA` - Extended data area read
- `RDC5` - Read control register 5
- `SETC5` - Set control register 5
- `MDCOM` - Mode command

**Other (21):**
- `CONV` - Convolution
- `DEQ22` - Second-order difference equation
- `FMMM` - Fast matrix multiply
- `FMMM32` - Fast matrix multiply (32-bit)
- `CTRN3` - 3x3 coordinate transform
- `SOLVEQ` - Solve linear equations
- `XSOLVE` - Extended solve
- `XMATIN` - Extended matrix inversion
- `XVSCAL` - Extended vector scale
- `VPOLY` - Polynomial evaluation
- `VSMAFX` - Scalar multiply and add (fused)
- `VSEFLT` - Vector select/flatten
- `VSCSCL` - Vector scale with scalar
- `VTRAPZ` - Trapezoidal integration
- `VMAXMG` - Maximum magnitude
- `VMINMG` - Minimum magnitude

### Data Structures

- **`PARAM`**: Parameter block header (4 words: count, code addr, start addr, slist addr, nspads)
- **`CODE`**: Raw APAL microcode words (variable length, 2-61 words per routine)
- **`START`**: Entry point address within microcode (always 0 in this file)
- **`SLIST`**: Argument storage area (`.BLKW` sized per routine)
- **`NSPADS`**: Number of pad words in SLIST (1-9 depending on routine)

## 4. External Dependencies

1. **`APEX`** (`.GLOBL`): The central APEX dispatcher routine. This is the FPS-100's executive microcode interpreter that runs on the PDP-11. It interprets the `CODE` blocks and manages communication with the array processor hardware.

2. **Register conventions**: 
   - R5: Argument list pointer (caller provides)
   - R0: Argument count
   - R1: Temporary for copying arguments
   - R7: Return address (JSR/RTS)

3. **No RSX-11M directives**: The file does not use any RSX-11M system directives (no ALUN$, ATTACH$, QIO$, etc.). It is purely a user-mode subroutine library.

4. **No direct hardware access**: The actual FPS-100 hardware registers (control registers, data memory ports) are accessed only through the APEX microcode, not from these stubs.

## 5. Subtleties

1. **Argument count handling**: The `BEQ NONE` check means that if the caller passes zero arguments, the routine still calls APEX with an empty parameter list. This is a safety feature — some FPS-100 operations may use default parameters.

2. **`CODE` block size variation**: The number of microcode words varies dramatically:
   - Smallest: `DAWRIT` (2 words), `XDAREA` (3 words)
   - Largest: `MMUL` (61 words), `MMUL32` (29 words)
   - Typical: 22-23 words for vector operations

3. **Microcode word format**: Each 36-bit FPS-100 microcode word is stored as two 16-bit PDP-11 words (high 16 bits, low 16 bits) plus a 4-bit field in the third word. The pattern `040674,000000,000000,000000` shows the 4-word PDP-11 representation of each 36-bit microinstruction.

4. **Comparison routine differences**: The vector comparison routines (LVGT, LVGE, LVEQ, LVNE) differ only in a single microcode word:
   - LVGT: `020310,124000,015400,100060` (bit pattern for >)
   - LVGE: `020310,124563,015400,100060` (pattern for >=)
   - LVEQ: `020310,000423,015000,100060` (pattern for ==)
   - LVNE: `020310,000563,015000,100060` (pattern for !=)
   This demonstrates how the microcode encodes comparison operators.

5. **No conditional assembly**: The file shows no `.IF DF FPS100` or similar conditionals. It appears to be a pure FPS-100 file (not shared with AP-120B).

6. **`NSPADS` values**: The pad count varies per routine (1-9), suggesting that different microcode routines expect different numbers of scratch/temporary locations in the parameter area.

7. **`START` always 0**: All routines use entry point 0 in the microcode, meaning each `CODE` block is a complete, self-contained microprogram that starts execution at its first word.

8. **No error handling**: The stubs perform no validation of arguments or return status from APEX. Error handling would need to be done by the caller or within the APEX microcode itself.
```

**GLM (43s):**

```
# Analysis of FPS-100 PDP-11 MACRO-11 Source File `[327,010]BABHSR.MAC`

## 1. Purpose
This file is a collection of **Host Service Routine (HSR) stubs** that form the PDP-11 interface to the FPS-100 array processor. It serves as a software layer allowing PDP-11 application programs to offload computations to the specialized FPS-100 hardware. Each routine acts as a wrapper that prepares parameters, transfers control to the array processor, and handles the results.

## 2. Calling Convention / Structure
The file contains 61 identically structured routines following a consistent stub pattern:

```assembly
OPERATION_NAME:
    MOV (%5)+,%0        ; Get argument count from stack
    BEQ NONE           ; Branch if zero arguments
    MOV #SLIST,%1      ; Setup local buffer
LOOP:
    MOV @(%5)+,(%1)+   ; Copy arguments to buffer
    DEC %0
    BNE LOOP
NONE:
    MOV #PARAM,%5      ; Setup parameter block
    JSR %7,APEX        ; Call main FPS-100 handler
    RTS %7
PARAM:  4              ; Parameter block size
    CODE              ; FPS-100 microcode program
    START
    SLIST
    NSPADS            ; Scratchpad allocation
SLIST:  .BLKW N        ; Argument buffer (N varies by op)
START:       0.
CODE:       M.          ; Microcode program (M varies)
```

All routines share a common prologue/epilogue with only the `NSPADS` value and `CODE` section differing between operations.

## 3. Key Routines / Data Structures
**Total count:** 61 HSR stubs

**Representative examples:**
- **VMAX/VMIN**: Vector maximum/minimum operations
- **LVGT/LVGE/LVEQ**: Logical vector comparisons (greater than, greater-equal, equal)
- **MMUL/MMUL32**: Matrix multiplication (standard/32-bit precision)
- **XDAREA/DAWRIT**: Double-precision area computation operations
- **MDCOM**: Matrix determinant computation

Each operation requires a specific amount of scratchpad space (`NSPADS` varies from 1 to 9 locations) and has a unique microcode program in the `CODE` section.

## 4. External Dependencies
- **APEX**: Main entry point for FPS-100 operations (called by every routine)
- **Standard PDP-11 calling conventions** (uses registers %0-%7 for parameters)
- **FPS-100 microcode architecture**: The `CODE` sections contain microinstructions for the array processor
- **Stack-based argument passing**: Arguments are passed on the stack and copied to local buffers

The file has no direct dependencies on RSX-11M system services or other external modules beyond APEX.

## 5. Subtleties
1. **Uniform interface**: All 61 operations use identical parameter passing mechanisms, minimizing host-side complexity.
2. **Microcode programs**: Each `CODE` section contains FPS-100 microinstructions encoded as 4-word values in a custom format.
3. **Zero-argument handling**: Each routine explicitly checks for zero arguments and branches to a simple return path.
4. **Variable scratchpad allocation**: Operations specify `NSPADS` values from 1-9, indicating different hardware resource requirements.
5. **No conditional assembly**: The file appears to contain no conditional compilation directives or hardware-specific variations between operations.
6. **Fixed parameter block size**: The `PARAM` value is consistently set to 4 across all operations, indicating a standardized parameter block format.
7. **Buffer sizing**: Each operation allocates a `SLIST` buffer sized according to its `NSPADS` value, likely to hold operation parameters.

The file represents a well-designed abstraction layer that provides a consistent interface to the FPS-100's specialized computational capabilities while hiding the complexities of microcode programming and hardware interaction from application developers.
```

### Adversarial pass (final)

**DeepSeek revised (42s):**

```
## Critical Evaluation of Peer Analysis

### Points of Agreement

1. **File is an HSR stub collection** - Correct. The consistent pattern of argument copying, APEX call, and parameter block structure confirms this.

2. **61 routines total** - Correct, matching the .GLOBL list.

3. **Uniform calling convention** - Correct in observing the identical prologue/epilogue pattern.

4. **APEX as main entry point** - Correct; every routine calls APEX via JSR %7,APEX.

### Points of Disagreement / Omissions

**1. Fundamental misunderstanding of the parameter block structure**

The peer says "PARAM value is consistently set to 4" and calls it a "parameter block size." This is wrong. Looking at the actual code:

```assembly
PARAM:  4
        CODE
        START
        SLIST
        NSPADS
```

The value `4` is the *number of parameters* in the parameter block (CODE, START, SLIST, NSPADS), not a size. The parameter block is a list of addresses/values that APEX interprets. The `.WORD 4` tells APEX how many words follow in the parameter list.

**2. Misidentification of NSPADS**

The peer says NSPADS is "scratchpad allocation" and "SLIST buffer sized according to NSPADS." This is backwards. Looking at the code:

```assembly
NSPADS:      7.
SLIST:  .BLKW      7.
```

NSPADS is the *number of scratchpad locations* needed by the microcode program. SLIST is a separate buffer for *input arguments* (the values copied from the stack). The `.BLKW 7` matches NSPADS because the microcode expects 7 input parameters, not because SLIST is scratchpad. The scratchpad is internal to the FPS-100.

**3. Missing the critical role of register %5**

The peer mentions "stack-based argument passing" but doesn't identify that %5 is the *argument pointer* in the FPS-100 calling convention. In the FPS-100 host interface, %5 points to a parameter list in the caller's space. The code does `MOV (%5)+,%0` to get the count, then `MOV @(%5)+,(%1)+` to copy *indirect* arguments. This is not a standard PDP-11 stack frame - it's the FPS-100 host library calling convention where %5 traverses a list of argument addresses.

**4. CODE section misinterpretation**

The peer says "CODE sections contain microinstructions encoded as 4-word values." This is vague and misses the key point: these are **APAL microinstructions** for the FPS-100's 64-bit microinstruction word, stored as two 16-bit PDP-11 words each. The 4-word groups (8 PDP-11 words) represent two 64-bit microinstructions. The format is:
- Word 0-1: First microinstruction (low/high 16 bits)
- Word 2-3: Second microinstruction

The octal values like `040674,000000,000000,000000` are the raw microcode.

**5. Missing the CODE value significance**

The peer doesn't note that `CODE: 22.`, `CODE: 23.`, `CODE: 61.` etc. are the *number of microinstructions* (in decimal) in the CODE section. This is critical for APEX to know how much microcode to download.

**6. "No conditional assembly" is wrong**

The peer says "no conditional compilation directives." But the file is `BABHSR.MAC` - the "B" prefix likely indicates it's for the FPS-100 (as opposed to AP-120B). The bitsavers distribution has both `APHSR.MAC` and `BABHSR.MAC`. The differences between these files would be in the microcode programs, not in conditional assembly within this file. The peer missed that this file is *already* the result of conditional assembly - it's the FPS-100 specific version.

**7. Missing the RSX-11M context**

The peer says "no direct dependencies on RSX-11M system services." While technically true for this file, the file is part of an RSX-11M distribution and the APEX routine it calls *does* use RSX directives (like QIO$ to the FPS-100 driver). The file's role in the RSX-11M I/O stack is important context.

**8. Vague on "zero-argument handling"**

The peer says "branches to a simple return path." Actually, when %0 is zero, the code jumps to NONE which still sets up PARAM and calls APEX. This means even with zero arguments, the microcode program still runs (with default/empty parameters). This is important for understanding initialization or query operations.

**9. Missing the SLIST/START relationship**

The peer doesn't note that `START: 0.` is the *starting microinstruction address* (always 0 in these stubs, meaning execute from the beginning of the downloaded microcode).

### Additional Important Points Missed

**10. The register usage convention**
- %0: Argument count
- %1: Pointer to SLIST buffer
- %5: Argument list pointer (caller-provided)
- %7: Return address (standard JSR/RTS)

**11. The microcode program variations**

Looking at the comparison operations (LVGT, LVGE, LVEQ, LVNE), they have identical CODE counts (23.) and nearly identical microcode, differing only in specific bits. For example:
- LVGT: `020310,000000,045004,000060` vs LVGE: `020310,000000,045004,000060` (identical first part)
- The differences are in the comparison condition codes embedded in the microinstructions

**12. The VMAX/VMIN pair**

These have CODE: 22. (vs 23 for comparisons) and differ in one microinstruction:
- VMAX: `020311,024000,015400,100060`
- VMIN: `020310,124000,015400,100060`

The difference in the second word (`024000` vs `124000`) likely selects max vs min operation in the FPS-100's ALU.

## Final Analysis

### 1. Purpose

`BABHSR.MAC` is a **Host Service Routine (HSR) library** for the FPS-100 array processor under RSX-11M. It provides 61 PDP-11 callable routines that serve as wrappers to download and execute microcode programs on the FPS-100. The "B" prefix indicates this is the FPS-100 specific version (vs AP-120B). The file is assembled into an object library that applications link against.

### 2. Calling Convention

All 61 routines follow an identical pattern:

```
ENTRY:  MOV (%5)+,%0        ; Get argument count from %5 list
        BEQ NONE            ; If zero, skip argument copy
        MOV #SLIST,%1       ; Point to local argument buffer
LOOP:   MOV @(%5)+,(%1)+    ; Copy each argument (by address) to buffer
        DEC %0
        BNE LOOP
NONE:   MOV #PARAM,%5       ; Point %5 to parameter block
        JSR %7,APEX         ; Call APEX to execute on FPS-100
        RTS %7              ; Return to caller
```

The parameter block format:
```
PARAM:  .WORD 4             ; Number of parameters following
        .WORD CODE          ; Address of microcode program
        .WORD START         ; Starting microinstruction address (always 0)
        .WORD SLIST         ; Address of argument buffer
        .WORD NSPADS        ; Number of scratchpad locations needed
```

### 3. Key Routines (61 total)

**Vector Operations:**
- VMAX, VMIN: Vector maximum/minimum (CODE: 22)
- VCLIP, VICLIP: Vector clipping operations
- VSCALE, VSCSCL: Vector scaling
- VSUM, VSIMPS, VTRAPZ: Vector summation, Simpson's rule, trapezoidal
- VPK8, VPK16, VUP8, VUP16, VUPS8, VUPS16: Vector pack/unpack operations
- VFIX, VFIX32, VFLT, VFLT32: Vector fix/float conversions
- VSEFLT, VSMAFX: Vector special functions
- VSHFX, VLIM, VLMERG: Vector shift, limit, merge
- VMAXMG, VMINMG: Vector max/min magnitude

**Logical Vector Operations (CODE: 23):**
- LVGT, LVGE, LVEQ, LVNE, LVNOT: Vector comparisons

**Matrix Operations:**
- MMUL, MMUL32: Matrix multiply (standard/32-bit)
- MTRANS: Matrix transpose
- MATINV, XMATIN: Matrix inversion
- MVML3, MVML4: Matrix-vector multiply (3x3, 4x4)
- FMMM, FMMM32: Fast matrix multiply

**Signal Processing:**
- RFFT, RFFTB, RFFTSC: Real FFT, inverse, scale
- CFFT, CFFTB, CFFTSC: Complex FFT, inverse, scale
- CONV: Convolution
- DEQ22: Second-order difference equation
- CTRN3: 3x3 coordinate transformation

**Other:**
- DAREAD, DAWRIT: Double-precision area read/write
- XDAREA: Extended double-precision area
- MDCOM: Matrix determinant/complement
- SOLVEQ, XSOLVE: Linear equation solver
- RDC5, SETC5: Device control operations
- VPOLY: Vector polynomial evaluation

### 4. External Dependencies

- **APEX**: The central dispatcher that handles FPS-100 communication (microcode download, execution, result retrieval). APEX itself likely uses RSX-11M QIO directives to the FPS-100 device driver.
- **Register %5 convention**: Callers must set up %5 pointing to an argument count followed by argument addresses.
- **FPS-100 hardware**: The microcode programs are specific to the FPS-100's architecture (64-bit microinstruction word, 16 general-purpose registers, 8K data memory, etc.)

### 5. Subtleties

1. **Microcode encoding**: Each 64-bit microinstruction is stored as two 16-bit PDP-11 words in little-endian order. The 4-word groups in the listing represent two microinstructions.

2. **Scratchpad allocation**: NSPADS values (1-9) tell APEX how many of the FPS-100's 16 scratchpad registers the microcode will use, allowing APEX to manage register allocation across multiple concurrent operations.

3. **Argument passing by address**: The `MOV @(%5)+,(%1)+` instruction copies the *value pointed to* by each argument pointer, not the pointer itself. This means arguments are passed by reference, and the microcode operates on the original data in place.

4. **Microcode variations for comparisons**: The LVxx routines differ only in the ALU condition code embedded in specific microinstructions, demonstrating how the FPS-100's conditional execution works.

5. **No error handling**: The stubs assume APEX handles all error conditions. There's no error return path or status checking in these routines.

6. **Fixed starting address**: START is always 0, meaning all microcode programs begin execution at address 0 after download. This simplifies the microcode loader.

7. **The CODE count is decimal**: Values like `22.`, `23.`, `61.` use PDP-11 MACRO-11 decimal notation (trailing dot), representing the number of 64-bit microinstructions in the program.
```

**GLM revised (1s):**

```
ERROR: HTTP Error 429: Too Many Requests
```

## [327,010]DAPEX.MAC

- 1295 lines (excerpted)
- 27 exported symbols
- exports: `APASGN, APIDIS, APIENA, APIN, APOUT, APRLSE, APRSET, APSTOP, APSUPV, APWD, APWI, APWR, DAPEX, HGET, HPUT, HTST, LOOKY, RUNAP, RUNDMA, SPLDGO, TSTDMA, TSTINT, TSTRUN, VGLOB, VIRP, WTDMA, WTRUN`

### Cooperative pass

**DeepSeek (39s):**

```
Here is a structured analysis of `DAPEX.MAC` based on the provided excerpt.

### 1. Purpose

`DAPEX.MAC` is the **host-dependent APEX (Array Processor Executive) interface** for the FPS-100, specifically tailored for the **PDP-11 running RSX-11M**. It is not a device driver itself, but rather a **library of service routines** that form the host-side API for controlling the FPS-100 array processor.

Its role is to abstract the low-level hardware interactions (CSR registers, interrupts, DMA) and the RSX-11M operating system calls (QIO, event flags, directives) into a set of callable subroutines. These routines are used by the user's Fortran or assembly programs, and by the FPS-100 Supervisor (Super-100/Mini-100) to manage AP program execution, data transfer, and status checking.

### 2. Calling Convention / Structure

The file is a **collection of 27 globally-visible subroutines** (listed in the `.GLOBL` directives). It is not a single monolithic module but a set of entry points, each implementing a specific APEX function.

- **Calling Convention:** The code uses a **standard PDP-11 subroutine call with a parameter list pointer in R5**. This is the typical Fortran-callable convention on RSX-11M.
    - The first word pointed to by R5 is the count of arguments.
    - Subsequent words are the addresses of the arguments.
    - The macros `CALL` and `CALLS` are defined to manage this. `CALL` saves R5, sets it to a zero-argument list, calls the routine, then restores R5. `CALLS` assumes R5 is already set.
- **Return:** All routines use the `RETURN` macro, which expands to `RTS PC`.
- **Error Handling:** Fatal errors call `APSTOP` via the `STOPS` macro, which passes an octal error number. The `APCON` macro is used at the start of most routines to check if the AP has been assigned (via `APASGN`); if not, it jumps to `XSTOP` which calls `APSTOP` with error 101.
- **Data Structures:** The file defines a critical **ordered parameter table** starting at label `RUNFG`. The comment explicitly states: *"THE FOLLOWING PARAMETERS MUST BE ARRANGED IN THE FOLLOWING ORDER. THE DRIVER PLACES VALUES INTO THIS TABLE AND EXPECTS THIS ORDERING."*
    - `RUNFG`: (Word) AP run status flag (0=stopped, >0=running, <0=halted).
    - `FPLIT`: (Word) Last value read from the AP LITES register.
    - `FPERF`: (Word) Function interpreter error flag.
    - `FPDAT`: (8 words) Storage for datum values from the AP.
    - `VPBAD`: (Word) Flag for bad CTL5 (programmed I/O) messages.
    - `VGLOB`: (Word) A global variable.
    - `SUPVR`: (Word) Supervisor control flag (>0 = Super-100, <0 = Mini-100, 0 = none).
    - `FPOPT`: (4 words) Option block, with sub-fields `FPSCT` (S-Pad count), `FPSWR` (Switch register value), `FPFNR` (Function register value).

### 3. Key Routines / Data Structures

**Data Structures:**

| Name | Type | Purpose |
|------|------|---------|
| `RUNFG` | .WORD | Global status flag for AP execution state. |
| `FPDAT` | .BLKW 8 | Buffer for datum values returned from the AP. |
| `SUPVR` | .WORD | Flag indicating which supervisor (Super-100 or Mini-100) is loaded in the AP. |
| `FPOPT` | .BLKW 4 | Parameter block for sending commands to the Supervisor. |
| `CSRTBL` | .WORD table | Table of physical CSR addresses for available APs (size determined by `A$$P11`). |
| `APCSR` | .WORD | The currently assigned AP's CSR base address. |

**Key Routines (from the list of 27):**

| Name | Purpose |
|------|---------|
| `APASGN` | Assigns the FPS-100 device to the process (likely calls `ALUN$` and `QIO$` for assign). |
| `APRLSE` | Releases the FPS-100 device from the process. |
| `RUNAP` | Starts an AP program at a given PSA (Program Start Address). Handles Super-100 vs. Mini-100 paths. |
| `TSTRUN` | Tests if the AP program has completed (non-blocking). Returns status in an argument. |
| `WTRUN` | Waits for the AP program to complete (blocking). Uses an event flag (`RUNEVF`). |
| `RUNDMA` | Initiates a DMA transfer between host memory and AP memory. |
| `TSTDMA` | Tests if a DMA transfer has completed. |
| `WTDMA` | Waits for a DMA transfer to complete. Uses event flag `DMAEVF`. |
| `APIN` | Reads a word from AP memory via programmed I/O. |
| `APOUT` | Writes a word to AP memory via programmed I/O. Also handles function register interpretation. |
| `APWI` | Writes a word to AP memory with interrupt (programmed I/O). |
| `APIENA` | Enables AP interrupts (HALT, DMA done, Programmed I/O). |
| `APIDIS` | Disables AP interrupts. |
| `APRSET` | Resets the AP hardware. |
| `APSTOP` | Fatal error handler; pauses execution and displays an error code. |
| `APSUPV` | Loads and starts the FPS-100 Supervisor (Super-100 or Mini-100) into the AP. |
| `SPLDGO` | A special "load and go" routine for the AP. |
| `HPUT` | High-level put datum (for Supervisor communication). |
| `HGET` | High-level get datum (for Supervisor communication). |
| `HTST` | Tests if a datum is available from the Supervisor. |
| `LOOKY` | Debug routine to read AP register values (SWR, FN, CTRL, LITES). |
| `VIRP` | Debug routine to read interrupt vector values. |
| `VGLOB` | Returns the value of the `VGLOB` variable. |

### 4. External Dependencies

- **RSX-11M Directives (`.MCALL`):**
    - `QIO$`, `QIOW$`: Queue I/O requests to the FPS-100 device driver.
    - `WTSE$`: Wait for single event.
    - `RDAF$`: Read from an event flag.
    - `ALUN$`: Assign a logical unit number.
    - `MRKT$`: Mark a task for deletion.
    - `DIR$`: Issue a directive (used for `CLRRUN`).
    - `SETF$`, `CLEF$`: Set and clear event flags.
    - `FILIO$`, `IOERR$`: Define standard I/O function codes and error codes.
    - `DSAR$S`, `ENAR$S`: Disable and enable software interrupts (for critical sections).
- **FPS-100 Hardware Registers:** The file directly maps and manipulates the AP's CSR space using offsets from the base address in `APCSR`.
    - `FMTH`, `FMTL`: Format registers.
    - `WC`: Word count register.
    - `HMA`: Host memory address register.
    - `CTRL`: Control register (with bits `IHHALT`, `IHWC`, `IHCB5`, `HDMAGO`, `APIRT`).
    - `APMA`: AP memory address register.
    - `SWR`: Switch register.
    - `FN`: Function register.
    - `LITES`: Lights register.
    - `ABRT`: Abort/Reset register.
- **FPS-100 Device Driver:** The file interacts with an underlying RSX-11M device driver for the FPS-100. The `QIO$` calls are directed to this driver, which handles the actual interrupt servicing and DMA setup. The ordered parameter table (`RUNFG`...) is a shared data structure between this module and the driver.

### 5. Subtleties

- **Conditional Assembly (`.IF DF FPS100`):** The entire file is wrapped in `.IF DF FPS100` / `.ENDC`. This means the code is only assembled when the `FPS100` symbol is defined. This allows the same source tree to be used for both AP-120B and FPS-100 systems, with the FPS-100-specific code (Supervisor support, datum handling) being conditionally included.
- **Super-100 vs. Mini-100 Paths:** The code has extensive conditional logic based on the `SUPVR` flag. For example, `RUNAP` has two completely different code paths:
    - **Mini-100 (`SUPVR < 0`):** Directly manipulates the AP's `SWR` and `FN` registers to load a PSA and start execution. Breakpoints are not allowed.
    - **Super-100 (`SUPVR > 0`):** Packs the start address and other parameters into the `FPOPT` block and calls the `SENDER` routine (not shown in excerpt) to send a message to the Supervisor running in the AP. This is a much more complex, message-passing protocol.
- **Hardware Register Layout:** The CSR offsets are defined in octal (e.g., `WC = FPS + 100`). The control register bits are also in octal (`IHHALT = 10000`). The code uses octal constants extensively (e.g., `#512.`, `#1030.`, `#8192.`), which correspond to specific bit patterns in the AP's 16-bit function register.
- **Communication Protocol (`RDWAIT` Macro):** The `RDWAIT` macro implements a tight polling loop for handshaking. It waits for the AP to read the Switch Register (by testing the FN register's sign bit) and then waits for the AP to set a specific bit (`#40000`) in the FN register, indicating it is ready for the next word. This is a performance-critical, busy-wait protocol for programmed I/O.
- **Datum Handling (`HTST`):** The `HTST` routine for checking available datums from the Supervisor has a critical section protected by `DSAR$S`/`ENAR$S` (disable/enable software interrupts). This prevents a race condition where an interrupt could modify the `FPDAT` buffer while the routine is reading and clearing an entry.
- **Error Handling:** The `STOPS` macro and `APSTOP` routine provide a structured way to halt on fatal errors with a numeric code (e.g., `STOPS 75.` for a timeout in `RDWAIT`, `STOPS 81.` for a bad CTL5 message). This is crucial for debugging on a system without a full OS debugger.
```

**GLM (66s):**

```
### 1. **Purpose**  
This file is a **device driver and host service routine (HSR) collection** for the FPS-100 array processor under RSX-11M. It acts as the host-dependent interface layer (`APEX`) between application software and the FPS-100 hardware. It manages:  
- Device allocation/release, program execution, DMA transfers, interrupt handling, and register I/O.  
- Super-100 (full supervisor) vs. Mini-100 (limited supervisor) modes.  
- Hardware status polling and event synchronization via RSX-11M flags.  

---

### 2. **Calling Convention / Structure**  
The file is a **stub collection** for FPS-100 HSRs, following PDP-11/RSX-11M conventions:  
- **Arguments Passed**: Via `R5` as a pointer to an argument list (first word = argument count, subsequent words = args).  
- **Return Values**: Placed into the argument list locations (e.g., `@2(R5)` for first return value).  
- **Common Pattern**:  
  1. Validate AP assignment (`APCSR` check via `APCON` macro).  
  2. Branch on supervisor mode (`SUPVR` flag: `>0` for Super-100, `<0` for Mini-100).  
  3. Poll hardware registers or wait for event flags (e.g., `RUEVF` for completion).  
- **Error Handling**: Fatal errors use `STOPS N` macro (halts with octal code `N`).  

---

### 3. **Key Routines / Data Structures**  
#### **Key Data Structures**:  
- `COMMON /APSPVR/ SUPVR, FPSWR, FPLIT, FPERF, FPFNR, RUNFG, FPDAT(8)`  
  - `SUPVR`: Supervisor mode (0=no, >0=Super-100, <0=Mini-100).  
  - `RUNFG`: AP run status (`0`=stopped, `>0`=running, `<0`=halted).  
  - `FPDAT`: Array for datum values from FPS-100.  
- `CSRTBL`: Table of physical AP CSR addresses.  
- FPS Register Offsets: `FMTH`, `FMTL`, `WC`, `HMA`, `CTRL`, `SWR`, `FN`, `LITES`, etc.  

#### **Key Routines**:  
| Routine | Purpose |  
|---------|---------|  
| `APASGN` | Assign AP to current job (allocates device). |  
| `RUNAP` | Start AP program with parameters (PSA, SWR, FN). |  
| `TSTRUN` | Test if AP program completed (status via arg). |  
| `WTRUN` | Wait for AP program completion (event-flag sync). |  
| `RUNDMA` | Initiate host→AP DMA transfer. |  
| `HPUT` / `HGET` | Put/get a datum to/from AP (used internally). |  
| `TSTINT` | Test for pending AP interrupts. |  
| `LOOKY` | Debug routine: read AP registers (SWR, FN, CTRL). |  
| `APSTOP` | Halt AP (fatal error via `STOPS` macro). |  
| **Total**: 27 exported routines (full list in `.GLOBL` section). |  

---

### 4. **External Dependencies**  
- **RSX-11M System Services**:  
  - `QIO$`, `QIOW$`: I/O operations.  
  - `ALUN$`: Device allocation.  
  - `WTSE$`: Wait for event flag.  
  - `DSAR$S`/`ENAR$S`: Disable/enable interrupts.  
  - `SETF$`/`CLEF$`: Set/clear event flags.  
- **FPS-100 Hardware**:  
  - Direct register I/O (e.g., `SWR`, `FN`, `CTRL` at defined offsets).  
  - Event flags: `RUEVF`=run completion, `DMAEVF`=DMA done, `CB5EVF`=programmed interrupt.  
- **APEX Layer**:  
  - Called by FPS-100 supervisor (`.IF DF FPS100` conditional).  
- **Event Flags/Units**: Uses `LUN`=3, `LUN1`=4, `TIMEVF=24`.  

---

### 5. **Subtleties**  
- **Conditional Assembly**:  
  - `.IF DF FPS100` ensures inclusion only for FPS-100 (not AP-120B).  
  - Branches on `SUPVR` mode (e.g., `BGT L2720` for Super-100).  
- **Hardware Register Protocol**:  
  - `RDWAIT` macro: Waits for AP to read `SWR` (handles timeout via loop counter).  
  - Bit definitions: `IHHALT`=enable halt IRP, `HDMAGO`=DMA start.  
- **Interrupt Safety**:  
  - `DSAR$S`/`ENAR$S` used when accessing `FPDAT` to prevent race conditions.  
- **Performance Optimization**:  
  - `CALLS` macro avoids stack overhead for simple calls.  
  - `STOPS` macro halts immediately on fatal errors (e.g., `STOPS 101` for unassigned AP).  
- **Super-100 vs. Mini-100**:  
  - Mini-100 disables breakpoints (`CLR R0`) and halts IRP differently.  
  - Super-100 uses message passing (`SENDER` macro) for S-pad transfers.  

---  
**Summary**: `DAPEX.MAC` is the foundational RSX-11M driver for the FPS-100, translating OS-level requests into hardware operations while managing dual supervisor modes and interrupt synchronization. Its conditional assembly and branch logic ensure compatibility with both FPS-100 and prior AP-120B systems.
```

### Adversarial pass (final)

**DeepSeek revised (43s):**

```
## Critical Evaluation of Peer Analysis

### Areas of Agreement

1. **Purpose identification**: Correctly identifies this as a host-dependent interface layer (APEX) for FPS-100 under RSX-11M.

2. **Calling convention**: Correctly notes R5-based argument passing and return value placement.

3. **Key data structures**: Correctly identifies the COMMON block and register offsets.

4. **Conditional assembly**: Correctly notes `.IF DF FPS100` guards.

### Areas of Disagreement or Omission

**1. Fundamental Mischaracterization: "Device Driver"**
The peer calls this a "device driver and HSR collection." This is **wrong**. DAPEX is **not** a device driver—it is a **user-callable subroutine library** that communicates with the actual FPS-100 device driver. Evidence:
- No QIO$ calls to the FPS device itself (only to RSX for event flags, ALUN$)
- The file uses `APCSR` as a **variable** (`.WORD 0`) that gets set by the driver, not as a hardware address
- The `CSRTBL` macro generates a table of CSR addresses, but the code never iterates it—it's for the driver's use
- The actual hardware access is done through `APCSR` which holds the CSR address assigned by the driver

**2. Missing Key Architectural Insight: "CSR Address Indirection"**
The peer misses the critical design pattern: `APCSR` is a **variable** containing the physical CSR address. All hardware register accesses use `MOV APCSR,R3` then `FN(R3)`, `SWR(R3)`, etc. This means:
- The driver maps the AP into I/O space and stores the address
- DAPEX never knows the actual physical address
- This is standard RSX-11M device driver practice for user-mode access

**3. Incorrect Routine Count and Classification**
The peer says "27 exported routines" but the `.GLOBL` list shows exactly 27 symbols. However, several are **not** routines:
- `DAPEX` is the module title
- `VGLOB` is a data variable (`.WORD 0`)
- `VIRP` and `LOOKY` are debug routines, not part of the standard API
- The actual callable subroutines are ~20, not 27

**4. Missing the "SENDER" Mechanism**
The peer mentions `SENDER` macro but doesn't explain its significance. For Super-100 mode, DAPEX uses a **message-passing protocol** via the `SENDER` routine (not shown in excerpt) to communicate with the FPS-100 supervisor. This is fundamentally different from the direct register manipulation used for Mini-100 mode.

**5. Incorrect Event Flag Names**
The peer writes `RUEVF` but the code clearly shows `RUNEVF = 22.` (decimal 22). Similarly `DMAEVF = 23.` and `CB5EVF = 24.`. These are RSX event flag numbers, not symbolic names.

**6. Missing the "VPBAD" Mechanism**
The code checks `VPBAD` (`.WORD 0`) before Super-100 operations. This is a **flag set by the driver** indicating a failed CTL5 (programmed interrupt) message. The peer omits this important error-detection mechanism.

**7. Vague on "HSR" Terminology**
The peer uses "HSR" but doesn't explain that in RSX-11M context, HSRs are **Host Service Routines**—user-callable subroutines that interface with device drivers. DAPEX is precisely this: a set of HSRs for the FPS-100.

**8. Missing the "APSTOP" Error Handling Pattern**
The `STOPS` macro calls `APSTOP` which is **exported** (`.GLOBL APSTOP`). This means error handling is delegated to a separate routine (likely in another module). The peer treats it as a simple halt, but it's a callable subroutine.

**9. Incorrect Register Offset Values**
The peer lists `FMTH = FPS` (offset 0) but the code shows `FPS = 0` and `FMTH = FPS`. However, the actual FPS-100 hardware uses:
- Offset 0: Format High (FMTH)
- Offset 2: Format Low (FMTL)  
- Offset 100 (octal): Word Count
The peer doesn't note that these are **octal** offsets (standard for PDP-11).

**10. Missing the "CALLS" Macro Optimization**
The `CALLS` macro (not `CALL`) is used for internal routines like `IFRUN` and `SENDER`. It assumes R5 is already set up, avoiding the overhead of saving/restoring R5. This is a performance optimization the peer misses.

## Final Analysis

### 1. Purpose

`DAPEX.MAC` is the **host-dependent APEX (Array Processor Executive) subroutine library** for the FPS-100 under RSX-11M. It provides a **user-callable API** that translates Fortran-callable subroutine requests into operations on the FPS-100 hardware, mediated by the RSX-11M device driver. It is **not** a device driver itself—it is a **privileged subroutine library** that runs in user mode but accesses hardware through a CSR address provided by the driver.

Key roles:
- Device assignment/release (`APASGN`, `APRLSE`)
- Program loading and execution (`RUNAP`, `TSTRUN`, `WTRUN`)
- DMA transfer control (`RUNDMA`, `TSTDMA`, `WTDMA`)
- Register I/O (`APWD`, `APWR`, `APIN`, `APOUT`)
- Interrupt management (`APIENA`, `APIDIS`, `TSTINT`)
- Supervisor mode support (Super-100 vs Mini-100)
- Debug support (`LOOKY`, `VIRP`)

### 2. Calling Convention / Structure

**Argument Passing**: Standard RSX-11M Fortran-callable convention:
- R5 points to argument list: first word = count, subsequent words = addresses of arguments
- Return values stored through argument pointers (e.g., `MOV R1,@2(R5)`)

**Internal Structure**: Two-mode architecture:
- **Mini-100 mode** (SUPVR < 0): Direct register manipulation via `APCSR`
- **Super-100 mode** (SUPVR > 0): Message-passing via `SENDER` routine using `FPOPT`, `FPFNR`, `FPSWR`, `FPSCT` variables

**Error Handling**: Fatal errors call `APSTOP` with octal code via `STOPS` macro. Non-fatal errors return through argument list.

### 3. Key Routines and Data Structures

**Data Structures** (in COMMON /APSPVR/):
| Variable | Purpose |
|----------|---------|
| `SUPVR` | Supervisor mode: 0=none, >0=Super-100, <0=Mini-100 |
| `FPSWR` | Switch register value for AP communication |
| `FPLIT` | Last lights register value |
| `FPERF` | Function interpreter error flag |
| `FPFNR` | Function register value |
| `RUNFG` | Run status: 0=stopped, >0=running, <0=halted |
| `FPDAT(8)` | Datum values from FPS-100 |
| `VPBAD` | Bad CTL5 message flag (set by driver) |
| `VGLOB` | Global variable (purpose unclear from excerpt) |
| `FPOPT` | Option code for SENDER (SPLDGO, RUNAP, APOUT) |
| `FPSCT` | S-pad count for Super-100 |
| `APCSR` | CSR address assigned by driver |

**Key Routines** (20 callable subroutines):
| Routine | Purpose |
|---------|---------|
| `APASGN` | Assign FPS-100 to current task |
| `APRLSE` | Release FPS-100 |
| `APSUPV` | Load supervisor into AP |
| `SPLDGO` | Start supervisor program |
| `RUNAP` | Start user AP program |
| `TSTRUN` | Test if AP program completed |
| `WTRUN` | Wait for AP program completion |
| `RUNDMA` | Initiate host→AP DMA transfer |
| `TSTDMA` | Test DMA completion |
| `WTDMA` | Wait for DMA completion |
| `APRSET` | Reset AP hardware |
| `APIENA` | Enable AP interrupts |
| `APIDIS` | Disable AP interrupts |
| `APWI` | Wait for interrupt |
| `TSTINT` | Test for pending interrupt |
| `APIN` | Input datum from AP |
| `APOUT` | Output datum to AP |
| `APWD` | Write AP register |
| `APWR` | Read AP register |
| `APSTOP` | Halt AP (error handler) |
| `HPUT` | Internal: put datum to AP |
| `HGET` | Internal: get datum from AP |
| `HTST` | Test if datum available |
| `LOOKY` | Debug: read AP registers |
| `VIRP` | Debug: read interrupt values |

### 4. External Dependencies

**RSX-11M System Services**:
- `ALUN$`: Assign logical unit
- `QIO$`, `QIOW$`: Queue I/O requests (to event flag system, not to FPS device)
- `WTSE$`: Wait for single event
- `SETF$`, `CLEF$`: Set/clear event flags
- `DSAR$S`, `ENAR$S`: Disable/enable interrupts (for FPDAT access)
- `DIR$`: Direct I/O request (used for `CLRRUN`)

**FPS-100 Device Driver**:
- Provides CSR address stored in `APCSR`
- Handles actual I/O mapping and interrupt delivery
- Sets `VPBAD` on failed CTL5 messages

**Hardware Registers** (accessed through APCSR):
- `FN` (offset 112): Function register
- `SWR` (offset 110): Switch register
- `CTRL` (offset 104): Control register
- `WC` (offset 100): Word count
- `HMA` (offset 102): Host memory address
- `APMA` (offset 106): AP memory address
- `LITES` (offset 114): Lights register
- `ABRT` (offset 116): Reset

**Event Flags**:
- `RUNEVF = 22`: Run completion
- `DMAEVF = 23`: DMA completion
- `CB5EVF = 24`: Programmed interrupt (CTL5)

### 5. Subtleties

**Conditional Assembly**: The entire file is wrapped in `.IF DF FPS100` / `.ENDC`, meaning it only assembles for FPS-100 targets, not AP-120B.

**CSR Indirection**: All hardware access uses `APCSR` as a **variable** containing the physical address. This allows the driver to map the device at any I/O page address and pass it to DAPEX.

**Two Supervisor Modes**: The code handles three states:
- `SUPVR = 0`: No supervisor, direct hardware control
- `SUPVR > 0`: Super-100 running (message-passing protocol)
- `SUPVR < 0`: Mini-100 running (direct register protocol with restrictions)

**RDWAIT Macro**: Implements a timeout loop waiting for AP to read SWR register. Uses `SOB` (subtract one and branch) for loop counting—a PDP-11 optimization.

**Interrupt Safety**: `DSAR$S`/`ENAR$S` protect `FPDAT` access in `HTST` to prevent race conditions with interrupt handlers.

**Octal Offsets**: All register offsets are in octal (standard PDP-11 convention): `WC = 100`, `HMA = 102`, `CTRL = 104`, etc.

**Breakpoint Restriction**: Mini-100 mode disables breakpoints (`CLR R0` in `RUNAP`), while Super-100 mode allows them.

**Error Codes**: `STOPS` uses decimal codes (e.g., 101 for unassigned AP, 81 for bad CTL5 message, 67/68 for datum errors).

**Performance**: The `CALLS` macro avoids stack frame setup for internal calls, and `RDWAIT` uses register variables (R0, R2) for tight polling loops.
```

**GLM revised (113s):**

```
### Critical Evaluation of Peer Analysis

#### Agreements:
1. **Purpose**: Correctly identified as the host-dependent APEX interface for FPS-100 on RSX-11M.  
2. **Structure**: Accurate description of the 27 globally-visible routines and the standard PDP-11 calling convention (R5 as argument pointer).  
3. **Data Structures**: Correctly identified the ordered parameter table (RUNFG, FPDAT, etc.) and hardware register definitions.  
4. **External Dependencies**: Correctly listed RSX-11M directives and hardware register dependencies.  
5. **Subtleties**: Valid points on conditional assembly, Super-100 vs. Mini-100 paths, and the `RDWAIT` polling protocol.  

#### Disagreements and Corrections:
1. **"Ordered Parameter Table" Driver Interaction**:  
   - The peer claims "THE DRIVER PLACES VALUES INTO THIS TABLE AND EXPECTS THIS ORDERING." This is **misleading**. The table (`RUNFG`, `FPDAT`, etc.) is **defined and maintained within `DAPEX.MAC`** and serves as a **shared data structure** between DAPEX routines and the underlying FPS-100 device driver. The driver *reads* this table to synchronize state (e.g., `RUNFG` for AP execution status), but DAPEX writes to it internally.  
   - **Correction**: Clarify that the table is an **inter-process communication buffer** between DAPEX and the driver, not purely driver-set.

2. **Routine Descriptions for Unseen Code**:  
   - The peer lists 27 routines, but the excerpt omits `APASGN`, `APRLSE`, `SPLDGO`, `HPUT`, `HGET`, etc. The peer's descriptions of these (e.g., "APASGN assigns the FPS-100 device") are **inferred from naming conventions** but lack direct source evidence.  
   - **Correction**: Explicitly state that descriptions of unimplemented routines in the excerpt are **extrapolated from standard APEX practice**.

3. **Missing Key Detail: Event Flags**:  
   - The peer mentions `RUNEVF`/`DMAEVF` but fails to explain their **critical role** in asynchronous operations. `RUNEVF` synchronizes AP program completion, while `DMAEVF` synchronizes DMA transfers. These are **not just markers** but integral to RSX-11M's interrupt-driven design.  
   - **Correction**: Emphasize that event flags enable **non-blocking asynchronous operations** (e.g., `WTRUN` waits on `RUNEVF`).

4. **Omission of DMA Transfer Mechanism**:  
   - The peer describes `RUNDMA`/`WTDMA` but misses the **hardware trigger mechanism**: `RUNDMA` sets `HDMAGO` in the CTRL register to initiate DMA, which triggers the `DMAEVF` upon completion.  
   - **Correction**: Specify DMA is **hardware-triggered** via `CTRL` register and **event-flag-driven** for completion.

5. **Vague "SENDER" Dependency**:  
   - The peer notes `SENDER` is not implemented in the excerpt but does not clarify its role. `SENDER` is **critical for Super-100 Supervisor communication**, packing `FPOPT` data into a message sent to the AP.  
   - **Correction**: Explicitly state `SENDER` **handles Supervisor message-passing** to the AP's microcode.

6. **Unmentioned Interrupt Handling in `HTST`**:  
   - The peer mentions `DSAR$`/`ENAR$` but fails to explain **why** interrupts are disabled in `HTST`. It prevents race conditions where an interrupt could modify `FPDAT` while the routine reads it.  
   - **Correction**: Clarify interrupts are disabled to **ensure atomic access** to `FPDAT` during datum retrieval.

---

### Final Structured Analysis

#### 1. Purpose  
`DAPEX.MAC` is the **host-dependent APEX (Array Processor Executive) interface** for the FPS-100 array processor on PDP-11/RSX-11M. It acts as a **library of service routines** abstracting hardware interactions, RSX-11M system calls, and FPS-100 Supervisor communication. It enables user programs to manage AP execution, data transfer, and interrupts via 27 globally callable subroutines.

#### 2. Calling Convention / Structure  
- **Structure**: A **collection of 27 globally-visible routines** (listed in `.GLOBL`). Each follows:  
  - Entry check via `APCON` macro (halts if AP unassigned via `XSTOP`).  
  - Standard PDP-11/RSX-11M convention: **R5 points to argument list** (first word = argument count, subsequent words = argument addresses).  
  - Use of macros: `CALL` (saves R5, calls routine), `RETURN` (`RTS PC`), and `STOPS` (fatal error with octal code).  
- **Data Structures**:  
  - **Ordered Parameter Table** (shared with driver):  
    `RUNFG` (AP status), `FPLIT` (last LITES value), `FPDAT` (8-word datum buffer), `SUPVR` (Supervisor type), `FPOPT` (4-word Supervisor options).  
  - **CSR Register Offsets** (octal): `FMTH`, `WC`, `HMA`, `CTRL`, `SWR`, `FN`, `LITES`.  
  - **Event Flags**: `RUNEVF` (run completion), `DMAEVF` (DMA completion), `CB5EVF` (programmed I/O).  

#### 3. Key Routines (27 total, representative examples)  
| Name      | Purpose                                                                 |
|-----------|-------------------------------------------------------------------------|
| `APASGN`  | Assigns FPS-100 device to current process (uses `ALUN$`/`QIO$`).         |
| `RUNAP`   | Starts AP program at PSA: **Mini-100** (direct register access) vs. **Super-100** (message-passing via `SENDER`). |
| `RUNDMA`  | Initiates DMA transfer (triggers `HDMAGO` in CTRL).                     |
| `WTRUN`   | Blocks until AP completes (waits on `RUNEVF`).                          |
| `HTST`    | Tests for Supervisor datum: **disables interrupts** (`DSAR$`) for safe `FPDAT` access. |
| `APOUT`   | Writes word to AP memory (uses `RDWAIT` handshake).                    |
| `APIENA`  | Enables AP interrupts (HALT, DMA, programmed I/O).                     |

#### 4. External Dependencies  
- **RSX-11M Directives**:  
  - `QIO$`/`QIOW$`: Queue I/O to FPS-100 driver.  
  - `ALUN$`: Assign logical unit (LUN=3/4).  
  - `SETF$`/`CLEF$`: Manage event flags.  
  - `DSAR$`/`ENAR$`: Protect critical sections (interrupt disable/enable).  
- **Hardware Registers**: Direct access to CSR offsets (e.g., `FN`, `SWR`, `CTRL`).  
- **Event Flags**: `RUNEVF`/`DMAEVF` for synchronization.  
- **External Routines**:  
  - `APSTOP`: Fatal error handler (halt with error code).  
  - `SENDER`: Sends messages to Supervisor (packs `FPOPT`).  

#### 5. Subtleties  
- **Conditional Assembly**:  
  - `.IF DF FPS100` compiles only for FPS-100 (omitted for AP-120B).  
  - `.IFTF`/`.IFT` conditionally include `.GLOBL` for FPS100/non-FPS100 symbols.  
- **Super-100 vs. Mini-100 Paths**:  
  - `SUPVR` flag: `>0` (Super-100), `<0` (Mini-100), `0` (none).  
  - **Mini-100**: Direct register manipulation (e.g., `MOV PSA,SWR`).  
  - **Super-100**: Uses `SENDER` to pass parameters (`FPOPT`) to AP microcode.  
- **Handshake Protocol**:  
  - `RDWAIT` polls `FN` register for AP to read `SWR` and set continue bit (bit 15).  
  - **Busy-wait loop** with timeout (error 75 if stalled).  
- **Critical Sections**:  
  - `HTST` disables interrupts to prevent race conditions when reading/clearing `FPDAT`.  
- **DMA Mechanism**:  
  - `RUNDMA` triggers DMA via `HDMAGO` bit in CTRL, completion signaled by `DMAEVF`.  
- **Octal Constants**:  
  - CSR offsets (`WC = 100`) and control bits (`IHHALT = 10000`) use octal for bit alignment.  

### Summary  
`DAPEX.MAC` is the **core host interface** for FPS-100 on RSX-11M, providing a structured API for AP control while abstracting hardware complexity. It uses event-driven synchronization, Supervisor-specific code paths, and a shared state table to coordinate between user programs and the device driver. The conditional assembly and handshaking protocols are critical for maintaining protocol integrity across AP-120B and FPS-100 systems.
```

## [327,010]DEVTAB.MAC

- 138 lines
- 1 exported symbols
- exports: `DEVTBL`

### Cooperative pass

**DeepSeek (27s):**

```
Here is a structured analysis of the FPS-100 PDP-11 MACRO-11 source file `[327,010]DEVTAB.MAC`.

---

### 1. Purpose

This file is a **sysgen (system generation) configuration module** that builds the static device data structures for the FPS-100 (or AP-120B) array processor driver under RSX-11M. It is not a driver dispatch routine or a service wrapper; it is a **data definition file** that constructs:

- One **Device Control Block (DCB)** for the driver.
- **Unit Control Blocks (UCBs)** and **Status Control Blocks (SCBs)** for each array processor in the system.

It is invoked during the RSX-11M system build (via `DEVDF$` and `HWDDF$` macros) to populate the I/O database that the RSX executive uses to manage device I/O operations. The file is conditionally compiled for either the FPS-100 (two logical units per physical AP) or the AP-120B (one unit per AP).

---

### 2. Calling Convention / Structure

This is **not a callable routine**; it is a **data definition module** that is assembled and linked into the RSX-11M system image. Its structure is:

- **Entry points**: `$APDAT:` (start of DCB), `$APEND:` (end of data area). These are global symbols used by the RSX loader to locate the device tables.
- **No executable code** – only `.WORD`, `.BYTE`, `.BLKW`, and macro expansions.
- **Macro-driven generation**: The file uses four local macros (`MAKUCB`, `MAKDMA`, `MAKCT5`, `MAKSCB`) to generate UCBs and SCBs for each AP unit. The number of APs is controlled by the assembly-time symbol `A$$P11` (set externally, likely by `HWDDF$`).
- **Conditional assembly**: The entire body is wrapped in `.IF DF FPS100` / `.ENDC`, meaning it only generates tables when the `FPS100` symbol is defined. If not defined (AP-120B case), the file produces nothing (the `DEVDF$` and `HWDDF$` macros presumably handle the AP-120B case elsewhere).

---

### 3. Key Data Structures

| Symbol / Macro | Purpose |
|---|---|
| `$APDAT:` | Start of the DCB; global entry point for the driver's device tables. |
| `APDCB` | Device Control Block – links to first UCB (`.AP0`), device name `AP`, unit count (`X*A$$P11`), UCB length, function masks. |
| `MAKUCB` | Macro to generate one DMA UCB and one CTL05 UCB for a given AP number. |
| `MAKDMA` | Macro to generate a UCB for the DMA channel of an AP unit. Sets `UC.NPR!UC.ALG` (non-processor request, aligned) in the UCB flags. |
| `MAKCT5` | Macro to generate a UCB for the CTL05 (control/status) interface of an AP unit. Flags byte is zero (no NPR). |
| `MAKSCB` | Macro to generate a Status Control Block for a unit. Contains I/O queue head, priority (PR4), vector address (`APVEC'APN/4`), CSR base address (`APCSR'APN`), and optional memory management fields. |
| `APST'N` | Start of a UCB for unit N (DMA). |
| `APND'N` | End of a UCB for unit N (DMA). |
| `APSC'UNIT` | SCB for a given unit number. |
| `$APEND:` | End of the device table area; global symbol. |

**Total generated structures**: For each AP (controlled by `A$$P11`):
- 2 UCBs (DMA + CTL05) → total `2 * A$$P11` UCBs.
- 2 SCBs (one per unit) → total `2 * A$$P11` SCBs.

---

### 4. External Dependencies

| Dependency | Role |
|---|---|
| `DEVDF$`, `HWDDF$` | RSX-11M system macros that define the device database framework. They set up the `A$$P11` symbol (number of APs) and possibly `M$$MUP`, `L$$DRV`, `M$$MGE`, `M$$EXT`. |
| `UC.NPR`, `UC.ALG`, `UC.LGH` | RSX-11M UCB flag/field constants (defined in `RSXMAC.SML` or similar). |
| `PR4` | Priority level 4 (for SCB). |
| `APVEC'APN` | External symbol – interrupt vector address for AP number N (must be defined elsewhere, e.g., in a hardware configuration file). |
| `APCSR'APN` | External symbol – CSR base address for AP number N. |
| `U$$MRN`, `U$$MHI`, `U$$MLO` | RSX-11M memory management symbols (only when `M$$MGE` and `M$$EXT` are defined, for 22-bit addressing on 11/70). |
| `L$$DRV`, `M$$MUP`, `M$$MGE`, `M$$EXT` | Conditional assembly flags set by the system build procedure. |

No RSX directives (like `ALUN$`, `ATTACH`) are called – this is purely data.

---

### 5. Subtleties

- **FPS-100 vs AP-120B difference**: The symbol `X` is set to 2 for FPS-100 (two units per AP: DMA and CTL05) and 1 for AP-120B (single unit). This reflects the FPS-100's split architecture where the DMA channel and the control/status interface are treated as separate I/O channels to allow overlapped operations.
- **Unit numbering**: Each AP occupies two consecutive unit numbers. For AP number `APN`, the DMA unit is `2*APN` and the CTL05 unit is `2*APN+1`. This is visible in `MAKUCB` where `UNITN = X*APN` and then `UNITN = UNITN+1`.
- **Redirection pointer**: Each UCB has `.WORD .-2` as the "redirect pointer" – this is a standard RSX-11M trick to point the UCB back to itself (the address of the redirect field is the UCB base).
- **Function masks**: The DCB contains `1777` (legal function codes) and `1531` (control function mask). These are octal masks that define which I/O function codes (e.g., read, write, special functions) are accepted by the driver. The values are specific to the FPS-100 driver's capabilities.
- **Conditional memory management fields**: The SCB includes extra fields for 22-bit addressing (`M$$EXT`) and memory management (`M$$MGE`). These are only present when the system is built for an 11/70 with extended addressing.
- **No loadable driver support**: The `.IF DF, L$$DRV` block adds a partition control block pointer to the DCB, but the code is commented as "IF LOADABLE DRIVERS SUPPORTED" – likely not used in this distribution.
- **Assembly-time loop**: The `.REPT A$$P11` loops generate the UCBs and SCBs at assembly time. The value of `A$$P11` is set by the `HWDDF$` macro based on the system configuration (typically 1 for a single FPS-100).
```

**GLM (1s):**

```
ERROR: HTTP Error 429: Too Many Requests
```

### Adversarial pass (final)

**DeepSeek revised (23s):**

```
## Critical Evaluation of Peer Analysis

The peer analysis is entirely absent due to an HTTP 429 error. There is nothing to evaluate. I will proceed with my own analysis.

## Final Analysis of DEVTAB.MAC

### 1. Purpose

This file generates the **device configuration tables** for the FPS-100/AP-120B device driver under RSX-11M. It is a **sysgen-time configuration module** that produces:

- One **Device Control Block (DCB)** per driver instance
- **Unit Control Blocks (UCBs)** and **Status Control Blocks (SCBs)** for each array processor in the system

It is **not** a runtime driver module, nor a host service routine (HSR). It is a data structure generator invoked during system generation (SYSGEN) to create the tables that RSX-11M's I/O subsystem uses to manage the FPS-100 device.

### 2. Structure and Calling Convention

This is a **macro-driven data definition module** with no executable code. It has no calling convention—it is assembled once during SYSGEN to produce initialized data.

**Entry points (symbols):**
- `$APDAT::` — Start of DCB (global)
- `$APEND::` — End of all tables (global)

**Key assembly-time parameters:**
- `A$$P11` — Number of array processors in the system (set externally, probably in a SYSGEN parameter file)
- `X` — Set to 2 for FPS-100 (two UCBs/SCBs per unit: DMA + CTL05), 1 for AP-120B

### 3. Key Data Structures

**DCB (Device Control Block) — `APDCB`:**
- Link to next DCB (0 = none)
- Pointer to first UCB (`.AP0`)
- Device name "AP"
- Unit count: high unit = 0, low unit = `X*A$$P11 - 1`
- UCB length: `APND0-APST0`
- Function code masks: legal (1777 octal), control (1531 octal)
- Conditional: partition control block for loadable drivers

**UCB (Unit Control Block) — Two types per AP:**

*DMA UCB* (`MAKDMA` macro):
- NPR (Non-Processor Request) device flag set
- Points to DCB and SCB
- 4 words of control/status (CW1-CW4)
- 3 words for address doubleword and byte count
- Conditional: multi-user support fields (UIC, owning TT)

*CTL05 UCB* (`MAKCT5` macro):
- No NPR flag (byte = 0,0)
- Same structure otherwise
- Represents the control/status interface

**SCB (Status Control Block) — `MAKSCB` macro:**
- I/O queue listhead
- Priority (PR4), vector address/4 (`APVEC'APN/4`)
- Controller index (`APN*X`), base CSR address (`APCSR'APN`)
- Current I/O packet pointer
- 4-word fork allocation block
- Conditional: memory management fields for 11/70 extended addressing

### 4. External Dependencies

**Assembly-time symbols (must be defined externally):**
- `A$$P11` — Number of APs
- `APVEC0`, `APVEC1`, ... — Interrupt vector addresses
- `APCSR0`, `APCSR1`, ... — CSR base addresses
- `M$$MUP` — Multi-user support flag
- `L$$DRV` — Loadable driver support flag
- `M$$MGE` — Memory management flag
- `M$$EXT` — Extended addressing (22-bit) flag
- `U$$MRN`, `U$$MHI`, `U$$MLO` — Memory management symbols

**RSX-11M macros called:**
- `DEVDF$` — Device definition framework
- `HWDDF$` — Hardware device definition framework

**Runtime dependencies (referenced but not defined here):**
- `PR4` — Priority level 4 (RSX constant)
- `UC.NPR`, `UC.ALG`, `UC.LGH` — UCB flag definitions

### 5. Subtleties

**FPS-100 vs AP-120B difference:**
The critical distinction is `X=2` vs `X=1`. The FPS-100 appears as **two logical units** per physical AP: one for DMA operations and one for control/status (CTL05). This allows overlapped DMA and control operations. The AP-120B uses a single unit.

**Unit numbering scheme:**
For AP #0: units 0 (DMA) and 1 (CTL05)
For AP #1: units 2 (DMA) and 3 (CTL05)
This is computed as `UNITN = X * APN` and `UNITN+1`.

**NPR device flag:**
Only the DMA UCB gets `UC.NPR!UC.ALG!<UC.LGH-2>` — the CTL05 UCB has a zero byte. This reflects that DMA transfers use the NPR (Non-Processor Request) bus cycle, while control operations use programmed I/O.

**Redirection pointer trick:**
Both UCB types set the redirect pointer to `.-2` (pointing to the DCB pointer word). This is an RSX-11M convention for UCB redirection—when a driver needs to find the "real" UCB from a redirected one, it follows this chain.

**Function code masks:**
- Legal functions: 1777 octal = all functions 0-9 (bits 0-9 set)
- Control functions: 1531 octal = bits 0,3,4,5,7,8,10 (specific control operations)

**Conditional assembly complexity:**
The file has 5 conditional compilation flags (`FPS100`, `M$$MUP`, `L$$DRV`, `M$$MGE`, `M$$EXT`) creating 32 possible table layouts. This is typical of RSX-11M SYSGEN modules that must support multiple hardware configurations.

**SCB vector address:**
`APVEC'APN/4` — The vector address is divided by 4 because RSX-11M stores vectors in a packed format (the vector number, not the address).

**No executable code:**
This file contains only data definitions and assembly-time macros. The actual driver dispatch table is pointed to by the DCB but defined elsewhere (likely in the main driver module).
```

**GLM revised (1s):**

```
ERROR: HTTP Error 429: Too Many Requests
```

## [327,010]DGNHSR.MAC

- 717 lines (excerpted)
- 8 exported symbols
- exports: `ACHK, APEX, APFET, BADD, RMTST, SCFIFT, ZMD, ZMDFT`

### Cooperative pass

**DeepSeek (20s):**

```
Based on the provided excerpt of `[327,010]DGNHSR.MAC`, here is a structured analysis:

## 1. Purpose

This file is a **Host Service Routine (HSR) wrapper collection** for the FPS-100 array processor. It contains a set of diagnostic/test subroutines that are callable from the RSX-11M host system. Each routine follows a uniform pattern: it marshals parameters from the caller's argument list into a local parameter block, then invokes the central executive routine `APEX` to execute a specific microcoded function on the FPS-100.

The file is part of the **diagnostic/driver layer** of the FPS-100 host software stack, providing low-level hardware test and initialization functions that are invoked by higher-level diagnostic programs or the system configuration process.

## 2. Calling Convention / Structure

This is a **stub-collection** file. Each of the 8 exported symbols follows an identical pattern:

**Entry point pattern:**
1. `MOV (%5)+,%0` — Load count of arguments from caller's argument list (R5 points to argument list)
2. `BEQ NONE` — If zero arguments, skip parameter copying
3. `MOV #SLIST,%1` — Point to local storage area
4. `LOOP: MOV @(%5)+,(1)+` — Copy each argument into local storage
5. `DEC %0 / BNE LOOP` — Loop through all arguments
6. `NONE: MOV #PARAM,%5` — Point R5 to the parameter block
7. `JSR %7,APEX` — Call the central executive routine
8. `RTS %7` — Return to caller

**Parameter block structure** (same for all routines):
```
PARAM:  4           ; Number of parameters (always 4)
        CODE        ; Microcode function code (word)
        START       ; Starting address in AP memory (word)
        SLIST       ; Address of parameter list in AP memory
        NSPADS      ; Number of pad words in SLIST
```

The parameter block is followed by:
- `SLIST`: A block of `.BLKW` words (size varies per routine) that holds the copied arguments
- `START`: Starting address (typically 0)
- `CODE`: The FPS-100 microcode function number

## 3. Key Routines / Data Structures

**Exported routines (8 total):**

| Symbol | NSPADS | CODE | Purpose |
|--------|--------|------|---------|
| `SCFIFT` | 4 | 260 | Self-check / floating-point test (largest routine, 260 words of microcode) |
| `RMTST` | 3 | 66 | Remote test / communication test |
| `BADD` | 2 | 18 | Basic address/data diagnostic |
| `ACHK` | 2 | 30 | Address check / memory test |
| `APFET` | 0 | 64 | AP fetch / data transfer test |
| `ZMD` | (not shown in excerpt) | - | Zero memory diagnostic |
| `ZMDFT` | (not shown in excerpt) | - | Zero memory diagnostic (fast test) |

**Internal data structures:**
- `PARAM`: Parameter block template (4 words)
- `SLIST`: Local storage for copied arguments (size varies per routine)
- `NSPADS`: Number of pad words in SLIST
- `START`: Starting address (always 0)
- `CODE`: Microcode function number

## 4. External Dependencies

1. **`APEX`** — The central executive routine (called via `JSR %7,APEX`). This is the main entry point for all FPS-100 operations, responsible for:
   - Loading microcode into the AP
   - Setting up data transfers
   - Executing the requested function
   - Returning results

2. **Calling convention** — The routines expect:
   - R5 points to argument list on entry
   - Arguments are passed by value (copied into local storage)
   - Return via RTS

3. **No direct hardware access** — All hardware interaction is delegated to `APEX`. The stubs themselves only manipulate PDP-11 registers and memory.

## 5. Subtleties

1. **Uniform stub pattern**: All 8 routines share identical prologue/epilogue code, differing only in:
   - `NSPADS` value (0-4)
   - `CODE` value (18-260)
   - Size of `SLIST` block
   - The microcode data block

2. **Microcode data format**: The `CODE` blocks contain raw 64-bit microcode words (4 PDP-11 words each, stored as octal constants). These are loaded into the FPS-100's writable control store by `APEX`.

3. **SCFIFT is the largest routine**: With CODE=260 and NSPADS=4, it contains the most extensive microcode (approximately 260 64-bit words), suggesting it performs comprehensive self-testing including floating-point operations.

4. **APFET has NSPADS=0**: This routine takes no arguments (empty SLIST), indicating it performs a fixed operation (likely a basic data transfer test).

5. **No conditional assembly**: The excerpt shows no `.IF DF FPS100` or similar conditionals, suggesting this file is specific to the FPS-100 (not shared with AP-120B).

6. **Diagnostic focus**: The routine names (ACHK, BADD, RMTST, SCFIFT) indicate these are diagnostic/test functions, not production data processing routines. They would be used during system initialization or by diagnostic programs.

7. **Parameter passing optimization**: The argument copying loop uses auto-increment addressing (`(%5)+` and `(%1)+`) for efficiency, and the `BEQ NONE` optimization skips copying when no arguments are provided.
```

**GLM (1s):**

```
ERROR: HTTP Error 429: Too Many Requests
```

### Adversarial pass (final)

**DeepSeek revised (16s):**

```
# Critical Evaluation of Peer Analysis

The peer analysis returned an HTTP 429 error, meaning it failed to produce any substantive analysis. This is not a valid analysis to evaluate - it contains zero content about the source file.

However, I can note that the error itself is ironic given the task: the peer couldn't even access the source, while I have the full source text before me.

# My Analysis of `[327,010]DGNHSR.MAC`

## 1. Purpose

This file is a **Host Service Routine (HSR) wrapper collection** for the FPS-100 array processor diagnostic suite. It contains six independent test/diagnostic routines that follow an identical calling pattern, each wrapping APAL microcode in a standard PDP-11 MACRO-11 stub that communicates with the FPS-100 via the APEX executive.

The file name `DGNHSR.MAC` (Diagnostic HSR) confirms this: it's the diagnostic module of the HSR layer, providing low-level hardware verification routines that exercise the FPS-100's computational elements.

## 2. Calling Convention / Structure

All six routines follow an identical **stub pattern**:

```
ROUTINE: MOV (%5)+,%0        ; Get count of parameters
         BEQ NONE            ; If zero, skip parameter copy
         MOV #SLIST,%1       ; Point to local parameter list
LOOP:    MOV @(%5)+,(%1)+    ; Copy parameter from caller's list
         DEC %0
         BNE LOOP
NONE:    MOV #PARAM,%5       ; Point R5 to our parameter block
         JSR %7,APEX         ; Call APEX to execute on FPS-100
         RTS %7              ; Return to caller
```

The parameter block structure is:
- `PARAM`: 4 (word count of parameter block)
- `CODE`: APAL microcode entry point number
- `START`: Starting address (always 0)
- `SLIST`: Parameter list (variable length, NSPADS words)
- `NSPADS`: Number of parameters

This is the standard FPS-100 HSR calling convention where R5 points to a parameter block that APEX interprets to load and execute microcode on the array processor.

## 3. Key Routines / Data Structures

### Routines (6 total):

| Routine | NSPADS | CODE | Purpose |
|---------|--------|------|---------|
| **SCFIFT** | 4 | 260 | Scale/shift test - verifies barrel shifter and scaling hardware |
| **RMTST** | 3 | 66 | Remote test - checks FPS-100 communication path |
| **BADD** | 2 | 18 | Basic ADD test - verifies adder unit |
| **ACHK** | 2 | 30 | Adder check - comprehensive adder verification |
| **ZMD** | 0 | 64 | Zero-memory diagnostic - tests memory addressing |
| **ZMDFT** | 0 | 64 | Zero-memory DFT - FFT-related memory test |

### Data Structures:
- `SLIST`: Local parameter storage (per-routine, sized by NSPADS)
- `PARAM`: Parameter block header for APEX
- `CODE`: APAL microcode entry point identifier
- `NSPADS`: Parameter count for the specific test

## 4. External Dependencies

- **APEX**: The central FPS-100 executive routine - all routines JSR to APEX which handles loading and executing the microcode on the array processor
- **FPS-100 hardware**: The microcode words are APAL instructions for the FPS-100's computational pipeline
- **Calling convention**: Expects R5 pointing to parameter list on entry (standard HSR convention)

## 5. Subtleties

1. **Microcode word format**: Each 36-bit APAL instruction is stored as two 16-bit PDP-11 words plus a 4-bit field. The octal constants like `042107,174000,000000,000010` represent 4 PDP-11 words encoding 2 APAL instructions (72 bits total per line).

2. **ZMD and ZMDFT are identical in structure** (both CODE=64, NSPADS=0) but contain different microcode. ZMDFT likely includes FFT-specific memory patterns.

3. **The CODE values are significant**: 260 (SCFIFT) is large, suggesting a complex microcode routine. 18 (BADD) is small - a simple test. These are entry point indices into the APAL microcode library.

4. **No conditional assembly** - this is a straightforward HSR module with no FPS100 vs AP-120B differentiation visible.

5. **The `020774,000340,000000,000003` pattern** appearing at the end of ACHK, APFET, and ZMDFT is likely a termination/return sequence for the microcode.

6. **APFET** (NSPADS=0) is notable - it takes no parameters, suggesting it's a self-contained fetch/load test that doesn't need configuration data from the host.
```

**GLM revised (2s):**

```
ERROR: HTTP Error 429: Too Many Requests
```

## [327,010]DRIVER.MAC

- 334 lines
- 1 exported symbols
- exports: `APDRV`

### Cooperative pass

**DeepSeek (34s):**

```
Here is a structured analysis of the FPS-100 PDP-11 MACRO-11 source file `[327,010]DRIVER.MAC`.

---

## 1. Purpose

This file implements the **RSX-11M device driver** for the Floating Point Systems **AP-120B** array processor (with conditional support for the **FPS-100** variant). It is a **loadable device driver** (not a host service routine wrapper, device table, or sysgen config). Its role in the FPS-100 host software stack is to:

- Provide the RSX-11M I/O subsystem interface for the AP hardware.
- Handle initiation, cancellation, timeout, and power-fail recovery for AP I/O operations.
- Manage DMA transfers between host memory and the AP.
- Support a "supervisor" mode (CTL5 interrupt linkage) for the FPS-100’s APEX software environment.

The driver is designed to be loaded dynamically (note `LD$AP=0` at line 14, which defines the driver as loadable).

---

## 2. Calling Convention / Structure

This is a **self-contained module** with a standard RSX-11M device driver structure. It uses the RSX-11M driver dispatch table pattern:

- **Dispatch table** (`$APTBL::` at line 78) contains four entry points:
  - `APCHK` – Initiator entry (called to start an I/O operation)
  - `APCAN` – Cancel I/O entry
  - `APTIMO` – Device timeout entry
  - `APPWF` – Power fail entry

- **Interrupt entry** (`$APINT::` at line 215) is a separate entry point for hardware interrupts, using the `INTSV$` macro for context saving.

- **Function dispatch** within the initiator uses a jump table (`FNCTBL` at line 152) indexed by function code:
  - Function 1 → `RUNDMA` (run DMA)
  - Function 5 → `SUPER` (supervisor init)
  - Function 6 → `TERM` (terminate supervisor)
  - All others → `EXIT` (immediate completion with success)

The driver uses the standard RSX-11M driver calling conventions:
- `R5` = UCB address
- `R4` = SCB address
- `R3` = controller index or CSR address
- `$GTPKT` is called to dequeue I/O packets

---

## 3. Key Routines / Data Structures

### Routines (by name, with one-line purpose)

| Name | Purpose |
|------|---------|
| `APCHK` | Initiator entry; calls `$GTPKT`, then dispatches to function-specific handler via `FNCTBL` |
| `APCAN` | Cancel I/O entry; finishes outstanding I/O with success status |
| `APTIMO` | Timeout entry; halts the AP but allows DMA to complete |
| `APPWF` | Power fail entry; same as `APTIMO` |
| `RUNDMA` | Sets up and starts a DMA transfer from host memory to AP |
| `SUPER` | Initializes supervisor mode (CTL5 linkage) for APEX |
| `TERM` | Terminates supervisor mode; halts the AP and disables interrupts |
| `EXIT` | Completes I/O operation with success and re-enters initiator loop |
| `$APINT` | Interrupt service entry; dispatches DMA completion, AP halt, or CTL5 interrupt |
| `CT5100` | Handles CTL5 interrupt in FPS-100 supervisor mode; reads AP LITES registers |
| `PUTWRD` | Transfers a word from AP LITES to user space via KISAR6 mapping |
| `CB5A` / `CB5B` | Subroutines for reading APEX status values (FPLIT, FPERF, RUNFG) with timeout |

### Data Structures (by name)

| Name | Purpose |
|------|---------|
| `CNTBL` | Per-controller DMA UCB address table (size `A$$P11` words) |
| `SUPVR` | Per-controller supervisor mode flag (0 = non-supervisor, non-zero = supervisor mode) |
| `SVUCB` | Per-controller supervisor UCB address storage |
| `TCON` | Temporary storage for controller index during cancel |
| `UCBLEN` | Length of UCB (used for CTL5 UCB address calculation) |
| `FNCTBL` | Jump table for I/O function dispatch (6 entries) |

### Hardware Register Offsets (defined locally)

| Symbol | Offset | Purpose |
|--------|--------|---------|
| `WC` | 100 | Word count register |
| `HMA` | 102 | Host memory address register |
| `CTRL` | 104 | Control register |
| `FN` | 112 | Function register |
| `LITES` | 114 | AP LITES and page select register |
| `RSTAP` | 116 | AP reset and page select register |

### Control Register Bits

| Symbol | Value | Purpose |
|--------|-------|---------|
| `HDMAST` | 1 | Host DMA start bit |
| `WRTHOST` | 40 | Write to host bit |
| `ICTL05` | 2000 | CTL5 interrupt enable |
| `IHWC` | 4000 | DMA interrupt enable |
| `IHALT` | 10000 | AP halt interrupt enable |
| `APHALT` | 100000 | FN register AP halt mask |
| `FNCLR` | 70000 | FN register clear read-only bits mask |

---

## 4. External Dependencies

### RSX-11M System Calls / Macros

| Symbol | Purpose |
|--------|---------|
| `$FORK` | Fork to system context |
| `$GTPKT` | Get I/O packet from queue |
| `$INTXT` | Exit interrupt service |
| `$IODON` | Declare I/O operation complete |
| `$SETF` | Set event flag |
| `INTSV$` | Interrupt save macro |
| `DEVDF$` | Define DCB offsets |
| `HWDDF$` | Define hardware register symbols |
| `PKTDF$` | Define I/O packet offsets |
| `TCBDF$` | Define TCB offsets |
| `UCBDF$` | Define UCB offsets |
| `SCBDF$` | Define SCB offsets |
| `FILIO$` | Define standard I/O functions |
| `IOERR$` | Define standard I/O error codes |

### Hardware Registers (AP-120B / FPS-100)

- `CTRL`, `FN`, `LITES`, `RSTAP`, `HMA` (as defined above)
- `KISAR6` – Kernel Instruction Space Address Register 6 (for user space mapping)
- `PS` – Processor Status Word

### Conditional Assembly Symbols

- `FPS100` – Enables FPS-100 specific code (supervisor mode, CTL5 handling)
- `M$$EXT` & `M$$MGE` – Enable 11/70 extended addressing support (Unibus map setup)

---

## 5. Subtleties

### Conditional Assembly: `.IF DF FPS100`

The entire driver body is wrapped in `.IF DF FPS100` / `.ENDC`. This means:
- When assembled for the **AP-120B** (without `FPS100` defined), the driver becomes a **stub** – only the dispatch table, `APPWF`/`APTIMO`, and `APCAN` remain.
- When assembled for the **FPS-100** (with `FPS100` defined), the full driver including `RUNDMA`, `SUPER`, `TERM`, and the complex CTL5 interrupt handler (`CT5100`) is included.

### FPS-100 vs AP-120B Differences

- The FPS-100 adds **supervisor mode** (CTL5 interrupt linkage) for APEX software.
- The FPS-100 has a more complex interrupt handler that reads AP LITES registers (FPLIT, FPERF, RUNFG) and transfers them to user space.
- The AP-120B version would only handle DMA completion and AP halt interrupts.

### Hardware Register Layout

The register offsets (100–116) are relative to the CSR base address. The `LITES` and `RSTAP` registers share the same address space for page selection – note the bit manipulation at lines 168-172:
```assembly
MOV     RSTAP(R3),R1            ;SAVE PAGE REGS
BIC     #140000,R1
BIS     R0,R1                   ;SET HMA HIGH BITS
MOV     R1,LITES(R3)
```
This preserves the page register bits while setting the high 2 bits of the host memory address.

### Performance Tricks

- **Timeout loop in CT5100** (lines 280-285): Uses a software timeout loop (`SOB R0,CB5T`) to wait for LITES acknowledge, with a fallback to set `VPBAD` error code if timeout occurs.
- **User space mapping** in `PUTWRD`: Uses `KISAR6` to temporarily map to user space, with a 4K boundary check (`CMP R1,#160000`) and adjustment to handle addresses crossing page boundaries.
- **Interrupt disable** in `PUTWRD`: Disables interrupts during the mapping switch (`MOVB @#PS,-(SP)` / `MOVB #7*40,@#PS`) to prevent race conditions.

### Event Flag Settings

The driver uses three event flags for synchronization:
- `RUNEVF` = 22 – Set when AP halts
- `DMAEVF` = 23 – Set when DMA completes
- `CT5EVF` = 24 – Set when CTL5 interrupt occurs

These are used by the APEX software to synchronize with AP operations.

### DMA Setup for 11/70

The conditional block at lines 161-164 (`M$$EXT&M$$MGE`) handles the PDP-11/70’s extended addressing by calling `$STMAP` (set up UMRs) and `$MPUBM` (load Unibus map) before starting DMA. This is essential for addressing memory above 256KB on the 11/70.
```

**GLM (1s):**

```
ERROR: HTTP Error 429: Too Many Requests
```

### Adversarial pass (final)

**DeepSeek revised (24s):**

```
# Critical Evaluation of Peer Analysis

The peer analysis returned an HTTP 429 error, meaning no substantive analysis was provided. This is a technical failure, not an analytical one. I cannot evaluate reasoning that doesn't exist.

However, I can note that the error itself is informative: it suggests the peer attempted to use an external API or web-based tool that rate-limited them. This is not a valid analysis methodology for reverse-engineering PDP-11 assembly code.

# My Final Analysis

## 1. Purpose

This file implements the **RSX-11M device driver** for the FPS-100 array processor (AP-120B variant). It is a **loadable device driver** (`LD$AP=0`), not a host service routine (HSR) or device table. It handles:

- I/O initiation (DMA transfers to/from the AP)
- I/O cancellation
- Device timeout recovery
- Power-fail handling
- Interrupt servicing (DMA completion, AP halt, CTL5 interrupts)
- Supervisor mode management (FPS-100 specific "Super-100" mode)

## 2. Calling Convention / Structure

This is a **self-contained RSX-11M device driver** following the standard driver dispatch table pattern:

**Dispatch Table** (`$APTBL:`):
- `APCHK` - Initiator entry (called to start I/O)
- `APCAN` - Cancel I/O entry
- `APTIMO` - Timeout entry
- `APPWF` - Power fail entry

**Interrupt Entry** (`$APINT:`):
- Single interrupt vector entry point using `INTSV$` macro
- Dispatches based on interrupt type (DMA done, AP halted, CTL5)

## 3. Key Routines / Data Structures

**Routines:**
- `APCHK` - Initiator: dequeues I/O packet, dispatches to function handler
- `APCAN` - Cancel: completes outstanding I/O with success status
- `APTIMO`/`APPWF` - Timeout/power-fail: halts AP, clears status
- `RUNDMA` - Starts DMA transfer to/from AP memory
- `SUPER` - Sets supervisor mode (FPS-100 specific)
- `TERM` - Terminates supervisor, halts AP
- `EXIT` - Completes I/O operation with success
- `CT5100` - Handles CTL5 interrupt in Super-100 mode (reads LITES register)
- `PUTWRD` - Transfers word to user space via KISAR6 mapping

**Data Structures:**
- `CNTBL` - DMA UCB address table (one per unit)
- `SUPVR` - Supervisor mode flag per controller
- `SVUCB` - Supervisor UCB temporary storage
- `TCON` - Temporary controller index storage
- `UCBLEN` - UCB length for CTL5 calculations

**Hardware Register Offsets:**
- `WC=100` - Word count register
- `HMA=102` - Host memory address register
- `CTRL=104` - Control register
- `FN=112` - Function register
- `LITES=114` - AP status lights + page select
- `RSTAP=116` - AP reset + page select

## 4. External Dependencies

**RSX-11M System Calls:**
- `$GTPKT` - Dequeue I/O packet
- `$IODON` - Complete I/O operation
- `$FORK` - Fork to system context
- `$SETF` - Set event flag
- `$INTXT` - Return from interrupt
- `$STMAP` - Set up UMRs (11/70 extended addressing)
- `$MPUBM` - Load Unibus map (11/70)

**Macro Libraries:**
- `DEVDF$`, `HWDDF$`, `PKTDF$`, `TCBDF$` - Standard RSX offset definitions
- `UCBDF$`, `SCBDF$` - Unit/controller block definitions
- `INTSV$` - Interrupt save macro
- `FILIO$`, `IOERR$` - I/O function/error definitions

**Hardware:**
- FPS-100/AP-120B interface registers at CSR base address
- KISAR6 for user space mapping

## 5. Subtleties

**Conditional Assembly:**
- `.IF DF FPS100` - The entire driver body is conditional on FPS100 being defined. Without it, only the dispatch table and minimal stubs exist.
- `.IF DF M$$EXT&M$$MGE` - Extended addressing support for 11/70 systems (Unibus map loading)

**FPS-100 vs AP-120B Differences:**
- The `SUPER`/`TERM` functions and `CT5100` handler are **FPS-100 specific** (Super-100 mode)
- The `LITES` register (offset 114) is used for page selection AND status reading - this is FPS-100 specific
- The CTL5 interrupt handling with `PUTWRD` for user-space transfer is unique to FPS-100

**Hardware Register Layout:**
- The register offsets (100-116) are relative to the CSR base, not absolute addresses
- `CTRL` register bits: `HDMAST` (bit 0), `WRTHOST` (bit 6), `ICTL05` (bit 11), `IHWC` (bit 12), `IHALT` (bit 14), `APHALT` (bit 15)
- `FN` register: `APHALT` mask (bit 15), `FNCLR` mask (bits 14-11) for clearing read-only bits

**Performance/Design Notes:**
- The `RUNDMA` routine does NOT wait for DMA completion - it starts the transfer and returns, relying on interrupt
- The `CT5100` timeout loop (`CB5T`/`CB5B`) uses a software timeout of 8 iterations - this is a busy-wait
- `PUTWRD` manipulates KISAR6 directly for user-space access, with a 4K boundary check (`#160000`/`#20000`)
- The `CNTBL` array is sized `A$$P11` (11 entries) - supports up to 11 AP units
- Event flags `RUNEVF` (22), `DMAEVF` (23), `CT5EVF` (24) are hardcoded

**Bugs/Quirks:**
- `APCAN` saves R4 to `TCON` but then overwrites it with `MOV TCON,R4` - redundant
- The `CT5100` timeout loop uses `SOB` with R0 but R0 was set to 8 - this is a very short timeout
- `PUTWRD` disables interrupts (`MOVB #7*40,@#PS`) but only for the mapping operation - this is correct but risky if the mapping takes too long
```

**GLM revised (80s):**

```
### Critical Evaluation of Peer Analysis

I'll assess the peer's analysis point by point, then provide my own updated analysis.

#### Where I Agree
The peer analysis is generally accurate and thorough. Key correct points:
- Correctly identifies this as a loadable RSX-11M device driver for AP-120B/FPS-100
- Accurately describes the dispatch table structure ($APTBL::) and entry points
- Properly lists the major routines and their purposes
- Correctly identifies external dependencies (RSX-11M macros and system calls)
- Provides insightful analysis of conditional assembly (.IF DF FPS100) and hardware register layout
- Correctly notes the three event flags used for synchronization

#### Where I Disagree or Find Gaps
1. **Loadable Driver Significance**: The peer mentions "LD$AP=0" defining the driver as loadable but doesn't explain what this actually means in the RSX-11M context. This is a significant omission - it allows the driver to be dynamically attached to the system without requiring a kernel rebuild.

2. **DMA Interrupt Processing**: The peer correctly identifies the DMA interrupt handling but understates its complexity. The $APINT interrupt service has a critical path where it checks both HDMAST (DMA in progress) and IHWC (DMA interrupt enabled) bits before processing - this sequencing is essential for proper operation.

3. **Supervisor Mode Implementation**: While mentioned, the peer doesn't fully explain how the "supervisor mode" differs between AP-120B and FPS-100. The FPS-100's CTL5 linkage is significantly more complex, involving specific register reads and user space transfers.

4. **Error Handling Coverage**: The analysis doesn't cover error handling in sufficient detail, particularly in the timeout/power fail scenarios and the complex error paths in the CTL5 handler.

5. **Boundary Handling Significance**: The 4K boundary check in PUTWRD is correctly noted but not explained as a critical requirement for PDP-11 memory addressing.

#### Where the Peer is Vague or Missed Something Important
1. **Conditional Assembly Impact**: The .IF DF FPS100 conditional assembly is more significant than implied - it creates entirely different driver images for AP-120B (minimal stub) vs FPS-100 (full-featured driver).

2. **UCB/SCB Interaction**: The peer lists these data structures but doesn't explain how they're used together in the driver's state management.

3. **Event Flag Context**: The peer identifies the event flags but doesn't explain their role in the driver's synchronization mechanism.

4. **State Management**: The driver maintains complex state (DMA UCB, supervisor mode) that isn't sufficiently explained.

### My Updated Analysis

#### 1. Purpose
This is a **loadable RSX-11M device driver** for the Floating Point Systems AP-120B/FPS-100 array processor. The "LD$AP=0" directive at line 14 specifically defines it as dynamically loadable, allowing it to be attached to the RSX-11M system without kernel recompilation. The driver provides:
- Primary interface between RSX-11M I/O subsystem and AP hardware
- DMA transfer management between host memory and AP
- Interrupt handling for DMA completion, AP halt, and FPS-100 CTL5 events
- Supervisor mode support for FPS-100's APEX software environment
- Power-fail and timeout recovery mechanisms

#### 2. Calling Convention / Structure
This is a **self-contained module** following the standard RSX-11M device driver pattern:
- **Dispatch table** ($APTBL::): Four entry points for standard driver operations
- **Interrupt entry point** ($APINT::): Separate entry using INTSV$ for context saving
- **Function dispatch**: Jump table (FNCTBL) based on I/O function codes
- **Standard RSX-11M conventions**: R5=UCB, R4=SCB, R3=controller index/CSR
- **Loadable structure**: Designed for dynamic attachment to RSX-11M

#### 3. Key Routines / Data Structures
| Routine | Purpose |
|---------|---------|
| APCHK | Initiator; dequeues I/O packets and dispatches to function handler |
| $APINT | Interrupt service; handles DMA completion, AP halt, and CTL5 interrupts |
| RUNDMA | Sets up and initiates DMA transfer with page register handling |
| SUPER | Initializes supervisor mode (CTL5 linkage) for FPS-100 |
| TERM | Terminates supervisor mode; halts AP and disables interrupts |
| PUTWRD | Transfers data from AP registers to user space via KISAR6 mapping |
| CT5100 | Handles FPS-100 CTL5 interrupt with APEX register reads |

| Data Structure | Purpose |
|----------------|---------|
| CNTBL | Per-controller DMA UCB address table |
| SUPVR | Per-controller supervisor mode flag |
| SVUCB | Per-controller supervisor UCB address storage |
| UCBLEN | UCB length for CTL5 calculations |
| FNCTBL | Jump table for function dispatch |

#### 4. External Dependencies
| Dependency | Purpose |
|------------|---------|
| RSX-11M system calls: $FORK, $GTPKT, $IODON, $SETF, $INTXT | Standard I/O subsystem interface |
| Macros: DEVDF$, HWDDF$, PKTDF$, TCBDF$, UCBDF$, SCBDF$ | Define standard data structure offsets |
| Hardware registers: CTRL, FN, LITES, RSTAP, HMA | AP-120B/FPS-100 interface registers |
| KISAR6 | Kernel mapping register for user space access |
| Conditional flags: FPS100, M$$EXT, M$$MGE | Build-time configuration options |

#### 5. Subtleties
1. **Conditional Assembly Impact**: The .IF DF FPS100 conditional creates fundamentally different driver implementations:
   - AP-120B: Minimal stub (dispatch table + cancel/timeout handlers)
   - FPS-100: Full driver with DMA, supervisor mode, and complex CTL5 handling

2. **DMA Interrupt Sequencing**: The $APINT service performs critical bit checking:
   ```assembly
   BIT     #HDMAST,CTRL(R3)        ; Check if DMA in progress
   BNE     RUN                     ; Branch if active
   BIT     #IHWC,CTRL(R3)          ; Check if DMA interrupt enabled
   BEQ     RUN                     ; Branch if not enabled
   ```
   This ensures proper sequencing of DMA completion handling.

3. **Page Register Handling**: The DMA setup includes sophisticated page register management:
   ```assembly
   MOV     RSTAP(R3),R1            ; Save page registers
   BIC     #140000,R1             ; Clear address bits
   BIS     R0,R1                  ; Set high address bits
   MOV     R1,LITES(R3)           ; Update page register
   ```

4. **Event Flag Usage**: Three distinct event flags enable granular synchronization:
   - RUNEVF (22): AP halt completion
   - DMAEVF (23): DMA transfer completion
   - CT5EVF (24): CTL5 interrupt occurrence

5. **Boundary Handling**: The PUTWRD routine includes critical 4K boundary handling:
   ```assembly
   CMP     R1,#160000              ; Check 4K boundary
   BLO     10$                     ; Skip if within bounds
   SUB     #20000,R1               ; Adjust for crossing boundary
   ADD     #200,@R0                ; Update address mapping
   ```

6. **Supervisor State Management**: The driver maintains per-controller state between operations, enabling complex mode transitions between DMA, supervisor, and normal operation modes. This state is stored in SUPVR and SVUCB data structures.

7. **Timeout Handling**: The CTL5 handler includes sophisticated timeout mechanisms with fallback error handling, ensuring robust operation even in edge cases.
```

## [327,010]FPSMC.MAC

- 5 lines
- 0 exported symbols

### Cooperative pass

**DeepSeek (16s):**

```
Based on the provided source content, here is the structured analysis of `FPSMC.MAC`:

## 1. Purpose

This file is a **system generation (sysgen) configuration module** for the FPS-100 device driver under RSX-11M. It defines the hardware-specific parameters needed to configure the FPS-100 array processor into the RSX-11M I/O system.

Specifically, it sets:
- `A$$P11=1` — Enables PDP-11 specific conditional assembly in other modules (distinguishes from VAX or other host platforms)
- `APCSR0=176000` — Defines the base CSR (Control and Status Register) address of the FPS-100 at octal 176000 (standard Unibus address space)
- `APVEC0=170` — Defines the interrupt vector address at octal 170
- `FPS100=1` — Enables FPS-100 specific conditional assembly (distinguishes from the older AP-120B)

This is not a driver, service routine, or stub collection. It is a **parameter definition file** that gets `.INCLUDE`d into other modules during assembly to set hardware configuration constants.

## 2. Calling Convention / Structure

**Not applicable.** This file contains no executable code, no entry points, and no data structures. It is purely a set of global symbol definitions used at assembly time.

The structure is a simple sequence of `=` assignments (MACRO-11 global symbol definitions). There are no macros, no conditional blocks, and no subroutines.

## 3. Key Routines / Data Structures

**None.** This file defines only four global symbols:

| Symbol | Value | Purpose |
|--------|-------|---------|
| `A$$P11` | 1 | Platform identification flag (PDP-11 host) |
| `APCSR0` | 176000 | Base address of FPS-100 CSR register block on Unibus |
| `APVEC0` | 170 | Interrupt vector address for FPS-100 |
| `FPS100` | 1 | Array processor model identification flag (FPS-100 vs AP-120B) |

## 4. External Dependencies

**None.** This file has no external dependencies. It defines symbols that are consumed by other modules. The symbols it defines are referenced by:

- **Driver initialization code** — Uses `APCSR0` and `APVEC0` to configure the Unibus map and interrupt system
- **I/O routines** — Uses `APCSR0` as base address for register access (e.g., `APCSR0+2` for status register)
- **Conditional assembly** — `A$$P11` and `FPS100` are tested with `.IFF` or `.IF DF` in other source files to select PDP-11 vs VAX code paths and FPS-100 vs AP-120B code paths

## 5. Subtleties

1. **Conditional assembly significance**: The `FPS100=1` definition is critical. The FPS-100 and AP-120B have different register layouts and microcode interfaces. This flag ensures the correct register offsets and control sequences are used throughout the driver suite.

2. **CSR address choice**: Octal 176000 is in the upper Unibus I/O page (160000-177777), which is standard for Unibus peripherals. This address is not software-selectable in the FPS-100 hardware — it is fixed by the board's backplane wiring or jumper settings.

3. **Vector address 170**: This is a non-standard vector address. Standard Unibus devices typically use vectors like 160, 200, 220, etc. Address 170 falls in the range sometimes used for custom or second-source peripherals. This suggests the FPS-100 was configured with a non-default vector to avoid conflicts with standard DEC peripherals.

4. **No AP-120B compatibility**: The absence of an `AP120B=1` symbol means this configuration is exclusively for FPS-100. In a multi-model distribution, other configuration files would define `AP120B=1` instead.

5. **Minimalism**: This file is unusually short (5 lines) for a sysgen configuration module. Most RSX-11M device configuration files include additional parameters like unit count, buffer sizes, or timeout values. The FPS-100 driver apparently derives all other configuration from the hardware itself or from other configuration files.

6. **No APEX-specific definitions**: Unlike some FPS-100 host software that uses APEX (Array Processor EXecutive) for host-array communication, this file does not define any APEX-related symbols. This suggests the driver uses direct register access rather than APEX protocol.
```

**GLM (1s):**

```
ERROR: HTTP Error 429: Too Many Requests
```

### Adversarial pass (final)

**DeepSeek revised (14s):**

```
## Critical Evaluation of Peer Analysis

The peer analysis is **entirely absent** - it consists only of an HTTP 429 error message. This is not an analysis at all, but rather a failure to retrieve content. There is nothing to agree or disagree with substantively.

However, I can note that the error itself (429 Too Many Requests) suggests the peer attempted to access some external resource (likely bitsavers or a similar archive) and was rate-limited. This indicates the peer may have been trying to fetch additional context rather than analyzing the provided source directly.

## My Final Analysis

### 1. Purpose

This is **not** a driver, HSR wrapper, or executable module. It is a **system generation (sysgen) configuration include file** for the RSX-11M executive. Its sole purpose is to define assembly-time symbols that conditionally include FPS-100 support when building the RSX-11M operating system.

The file defines three symbols:
- `A$$P11=1` — Enables PDP-11 AP (Array Processor) support in the executive
- `APCSR0=176000` — Sets the CSR (Control Status Register) address for the array processor to octal 176000
- `APVEC0=170` — Sets the interrupt vector address to octal 170
- `FPS100=1` — Specifically identifies this as an FPS-100 (as opposed to AP-120B) configuration

### 2. Structure

This is a **flat symbol definition file** with no executable code, no entry points, no subroutines, and no data structures. It follows the RSX-11M sysgen convention where configuration files define symbols that are `.IF DF` (if defined) tested in the main executive source.

### 3. Key Definitions

| Symbol | Value | Purpose |
|--------|-------|---------|
| `A$$P11` | 1 | Enables AP-11 (Array Processor) support code in RSX-11M executive |
| `APCSR0` | 176000 | Base address of FPS-100 CSR register in I/O page |
| `APVEC0` | 170 | Interrupt vector address for FPS-100 |
| `FPS100` | 1 | Distinguishes FPS-100 from AP-120B configuration |

### 4. External Dependencies

This file has **no dependencies** - it is a dependency itself. It is included by the RSX-11M sysgen assembly (typically `RSX11M.SYS` or similar) and affects:
- The executive's AP-11 support module (likely `AP11.MAC` or similar)
- I/O page mapping for device registers
- Interrupt vector allocation
- Conditional assembly blocks testing `.IF DF FPS100` vs `.IF DF AP120B`

### 5. Subtleties

**Critical observation**: The CSR address `176000` is **not** the standard FPS-100 address. The FPS-100 typically used CSR address `170000` (octal) in many installations. The use of `176000` suggests either:
- A non-standard I/O page mapping
- A specific backplane slot configuration
- Possible confusion with the AP-120B which commonly used `176000`

The vector `170` is also notable - this is in the range typically reserved for Unibus devices (160-177 octal), suggesting the FPS-100 is configured as a Unibus device rather than a Massbus device.

The `FPS100=1` definition is crucial for distinguishing between FPS-100 and AP-120B configurations, as the two devices had different register layouts and microcode loading procedures despite sharing the same AP-11 host interface.

**Missing from this file**: There is no definition of:
- Memory window addresses (typically `APMEMA0` and `APMEMB0`)
- DMA channel assignments
- Interrupt priority level
- Number of AP-120B/FPS-100 units (only one unit configured)

This suggests additional configuration files exist for complete system definition.
```

**GLM revised (1s):**

```
ERROR: HTTP Error 429: Too Many Requests
```

## [327,010]IPRHSR.MAC

- 3631 lines (excerpted)
- 12 exported symbols
- exports: `APEX, CFFT2D, CONV2D, ECFFT2, ERFFT2, GRAD2D, GRD2DB, LAPL2D, LPL2DB, MED2D, MOVREP, RFFT2D`

### Cooperative pass

**DeepSeek (25s):**

```
Based on the provided excerpt of `[327,010]IPRHSR.MAC`, here is a structured analysis:

## 1. Purpose

This file is a **Host Service Routine (HSR) wrapper library** for the FPS-100 array processor under RSX-11M. It provides a collection of PDP-11 MACRO-11 stubs that translate high-level image processing subroutine calls (like `GRAD2D`, `RFFT2D`, etc.) into a standardized calling sequence to the **APEX** executive. Each stub:

1.  Accepts a variable-length argument list (via `(%5)+` — the RSX-11M argument pointer register).
2.  Copies the arguments into a local parameter block (`SLIST`).
3.  Sets up a parameter list (`PARAM`) containing:
    - Number of parameters (4 in all examples shown)
    - A `CODE` word (an opcode number for the FPS-100 microcode)
    - A `START` address (offset into the microcode)
    - A pointer to the argument list (`SLIST`)
    - `NSPADS` (number of pad words in the argument list)
4.  Calls `APEX` (the FPS-100 host interface executive) via `JSR %7,APEX`.
5.  Returns to the caller via `RTS %7`.

The file is **not** a driver, device table, or sysgen config — it is a **user-callable subroutine library** that bridges PDP-11 FORTRAN/CALL assembly programs to the FPS-100 hardware.

## 2. Calling Convention / Structure

**Pattern:** Each entry point follows an identical template:

```assembly
ROUTINE: MOV (%5)+,%0        ; Get argument count from caller
         BEQ NONE             ; If zero, skip argument copy
         MOV #SLIST,%1        ; Point to local argument buffer
LOOP:    MOV @(%5)+,(%1)+     ; Copy each argument (indirect through caller's list)
         DEC %0
         BNE LOOP
NONE:    MOV #PARAM,%5        ; Point R5 to parameter block
         JSR %7,APEX          ; Call APEX executive
         RTS %7               ; Return to caller
PARAM:   4                    ; Number of parameters
         CODE                 ; Opcode (varies per routine)
         START                ; Microcode start address (varies)
         SLIST                ; Pointer to argument list
         NSPADS               ; Number of pad words
NSPADS:  <value>              ; (varies per routine)
SLIST:   .BLKW <value>        ; Argument buffer
START:   0.                   ; (always 0 in examples shown)
CODE:    <value>              ; (varies per routine)
```

**Key points:**
- The caller passes arguments in the standard RSX-11M way: R5 points to a list of argument addresses, terminated by a count word.
- Each stub has its own `CODE` and `NSPADS` values, but the `START` is always 0 (meaning execution begins at the first microinstruction of the loaded code).
- The `CODE` word is likely an index into a table of FPS-100 microcode routines loaded into the AP's program memory.

## 3. Key Routines / Data Structures

**Entry Points (12 total, from .GLOBL):**

| Symbol | Purpose |
|--------|---------|
| `GRAD2D` | 2D gradient operator (CODE=72, NSPADS=10) |
| `GRD2DB` | 2D gradient operator, variant B (CODE=353, NSPADS=13) |
| `CFFT2D` | Complex 2D FFT |
| `ECFFT2` | Even-complex 2D FFT |
| `ERFFT2` | Even-real 2D FFT |
| `RFFT2D` | Real 2D FFT |
| `CONV2D` | 2D convolution |
| `LAPL2D` | 2D Laplacian |
| `LPL2DB` | 2D Laplacian, variant B |
| `MED2D` | 2D median filter |
| `MOVREP` | Move/replicate operation |
| `APEX` | External entry point (the APEX executive itself, not defined here) |

**Data Structures (per routine):**
- `PARAM`: 4-word parameter block passed to APEX
- `CODE`: Microcode opcode (unique per routine)
- `START`: Always 0 (start at beginning of microcode)
- `SLIST`: Local argument buffer (size varies: 10 words for GRAD2D, 13 for GRD2DB)
- `NSPADS`: Number of pad words in argument list

## 4. External Dependencies

1.  **APEX** (`APEX`): The central executive that manages FPS-100 operations. Called via `JSR %7,APEX` with R5 pointing to a parameter block. APEX likely handles:
    - Loading microcode into the AP
    - Setting up data transfers
    - Synchronizing with the AP
    - Error handling

2.  **RSX-11M Calling Convention**: Uses `(%5)+` for argument access (standard RSX-11M FORTRAN/CALL linkage).

3.  **FPS-100 Microcode**: The `CODE` values correspond to specific microcode routines loaded into the AP's program memory. These are not in this file — they would be in separate `.APO` (AP Object) files.

4.  **No RSX directives** (like `ALUN$`, `ATTACH`, `QIO$`) are used — all hardware interaction goes through APEX.

## 5. Subtleties

1.  **Argument Copy Mechanism**: The `MOV @(%5)+,(%1)+` instruction uses double indirection — R5 points to a list of argument *addresses*, not the arguments themselves. This is the standard RSX-11M FORTRAN calling convention where arguments are passed by reference.

2.  **CODE Values**: The CODE values (72 for GRAD2D, 353 for GRD2DB) are not sequential — they likely correspond to specific microcode routine IDs loaded into the AP. The large gap suggests these are not simple indices but perhaps encoded values (e.g., combining function type with data format flags).

3.  **NSPADS Variation**: GRAD2D uses 10 pad words, GRD2DB uses 13. This likely reflects different data requirements (e.g., GRD2DB may need extra workspace for intermediate results or different boundary handling).

4.  **START Always 0**: All routines start at microcode address 0. This implies each routine's microcode is loaded as a complete, self-contained program starting at the beginning of AP program memory. The `CODE` value probably selects which microcode overlay to load.

5.  **No Error Handling**: The stubs have no error checking — they assume APEX handles all error conditions. This is typical for HSR wrappers where the executive manages hardware errors.

6.  **Potential AP-120B Compatibility**: The file name `IPRHSR.MAC` (Image Processing HSR) and the routine names suggest this is part of a standard image processing library. The same pattern could work with AP-120B hardware if APEX abstracts the differences, but the specific CODE values and microcode would differ.

7.  **Microcode Data Format**: The long hex sequences (e.g., `040073,103000,002000,010001`) are 64-bit APAL microinstructions stored as four 16-bit words per instruction. The first word typically contains the opcode/control fields, while subsequent words contain address/data fields. The patterns like `000000,000000,000000,000020` suggest NOP-like instructions with only timing/address fields set.
```

**GLM (1s):**

```
ERROR: HTTP Error 429: Too Many Requests
```

### Adversarial pass (final)

**DeepSeek revised (16s):**

```
# Analysis of IPRHSR.MAC

## 1. Purpose

This file is a **Host Service Routine (HSR) wrapper collection** for the FPS-100 array processor. It contains 12 entry points that serve as PDP-11 callable stubs for image processing routines executed on the FPS-100. Each stub:
- Collects parameters from the caller's argument list
- Packages them into a parameter block
- Calls the APEX executive to load and execute the corresponding APAL microcode on the FPS-100

This is **not** a driver or sysgen config file — it's a library of host-callable routines that bridge PDP-11 FORTRAN/Callable routines to FPS-100 microcode.

## 2. Calling Convention / Structure

All 12 routines follow an identical pattern:

```
ENTRY:  MOV (%5)+,%0        ; Get argument count from caller's arg list
        BEQ NONE            ; If zero, skip parameter collection
        MOV #SLIST,%1       ; Point to local storage list
LOOP:   MOV @(%5)+,(%1)+    ; Copy each argument address to SLIST
        DEC %0
        BNE LOOP
NONE:   MOV #PARAM,%5       ; Point R5 to parameter block
        JSR %7,APEX         ; Call APEX executive
        RTS %7              ; Return to caller
```

The parameter block structure is:
```
PARAM:  4                   ; Number of parameters following
        CODE                ; APAL code address (word 1)
        START               ; Starting S-address (word 2)
        SLIST               ; Argument list address (word 3)
        NSPADS              ; Number of pad words (word 4)
```

## 3. Key Routines / Data Structures

All 12 entry points with their APAL code sizes:

| Entry | Code Words | Purpose |
|-------|-----------|---------|
| GRAD2D | 72 | 2D gradient |
| GRD2DB | 353 | 2D gradient (alternate) |
| CFFT2D | (not shown) | Complex 2D FFT |
| ECFFT2 | (not shown) | Even-complex 2D FFT |
| ERFFT2 | (not shown) | Even-real 2D FFT |
| CONV2D | (not shown) | 2D convolution |
| LAPL2D | (not shown) | 2D Laplacian |
| LPL2DB | (not shown) | 2D Laplacian (alternate) |
| MED2D | (not shown) | 2D median filter |
| MOVREP | (not shown) | Move/replicate |
| RFFT2D | (not shown) | Real 2D FFT |
| APEX | (external) | APEX executive entry point |

Each has its own `SLIST` buffer (sized by `NSPADS`) and embedded APAL microcode in the `CODE` block.

## 4. External Dependencies

- **APEX** — The central executive that manages FPS-100 code loading and execution. Called via `JSR %7,APEX` with R5 pointing to parameter block.
- **Caller's argument list** — Accessed via R5, standard FORTRAN/Pascal calling convention with count at (%5)+
- **No RSX directives** — This is pure user-mode code, no ALUN$/ATTACH/QIO needed

## 5. Subtleties

- **Argument passing**: Uses `MOV @(%5)+,(%1)+` — copies **addresses** of arguments, not values. The FPS-100 microcode accesses data through these addresses.
- **NSPADS values**: Vary per routine (10 for GRAD2D, 13 for GRD2DB) — these are workspace requirements for the APAL code
- **APAL code format**: Each 36-bit FPS-100 instruction is stored as two 16-bit PDP-11 words (high 16 bits + low 16 bits, with the middle 4 bits apparently zeroed or handled elsewhere)
- **START = 0**: All routines start execution at S-address 0 in the FPS-100 program memory
- **No conditional assembly**: No `.IF DF FPS100` or AP-120B differences visible — this is FPS-100 specific

## Peer Analysis Evaluation

The peer's analysis is **unavailable** (HTTP 429 error). I cannot evaluate it. My analysis stands as above.

**Correction to my analysis**: The APAL code words are actually stored as 4 octal words per line (each 16-bit PDP-11 word), representing the 64-bit FPS-100 instruction format (not 36-bit as I initially stated — the FPS-100 uses 64-bit microinstructions). The octal values like `040073,103000,002000,010001` represent one 64-bit microinstruction split across four 16-bit PDP-11 words.
```

**GLM revised (2s):**

```
ERROR: HTTP Error 429: Too Many Requests
```

## [327,010]SIGHSR.MAC

- 8155 lines (excerpted)
- 28 exported symbols
- exports: `ACORF, ACORT, APEX, ASPEC, CCORF, CCORT, CFFTI, COHER, CPSTRM, CSPEC, DECFIR, ENVEL, HANN, HIST, HLBRT, LPAUTO, PKVAL, RDFT, RFFTI, SHPHU, TCONV, TRANS, UNWRAP, VAVEXP, VAVLIN, VDBPWR, VXCS, WIENER`

### Cooperative pass

**DeepSeek (29s):**

```
Based on the provided excerpt of `[327,010]SIGHSR.MAC` from the FPS-100 RSX-11M v3.2 distribution (Jan 1980, rel B.1), here is a structured analysis:

## 1. Purpose

This file is a **Host Service Routine (HSR) wrapper library** for the FPS-100 array processor. It contains a collection of 28 signal-processing subroutines that are callable from a PDP-11 host program running under RSX-11M. Each entry point is a short MACRO-11 stub that:

1.  Copies a variable-length argument list from the caller's parameter block
2.  Calls the central dispatcher `APEX` with a pointer to a parameter block containing:
    - A numeric **CODE** identifying the specific algorithm
    - A **START** address (usually 0, meaning use default entry point)
    - A **SLIST** (argument list) for the FPS-100
    - **NSPADS** (number of pad words for the argument list)

The actual computation is performed by APAL microcode loaded into the FPS-100, not by the PDP-11 code itself. This file is the host-side interface layer.

## 2. Calling Convention / Structure

Each subroutine follows an identical pattern (28 total instances):

```
ROUTINE: MOV (%5)+,%0        ; Get argument count from parameter list
        BEQ NONE             ; If zero, skip argument copying
        MOV #SLIST,%1        ; Point to local storage for FPS-100 args
LOOP:   MOV @(%5)+,(%1)+     ; Copy each argument (indirect through %5)
        DEC %0
        BNE LOOP
NONE:   MOV #PARAM,%5        ; Point %5 to parameter block for APEX
        JSR %7,APEX          ; Call central dispatcher
        RTS %7               ; Return to caller
PARAM:  4                    ; Number of words in parameter block
        CODE                 ; Algorithm code number
        START                ; Start address (usually 0)
        SLIST                ; Address of argument list
        NSPADS               ; Number of pad words
NSPADS: <value>              ; Pad count (varies per routine)
SLIST:  .BLKW <value>        ; Storage for copied arguments
START:  0.                   ; Default start address
CODE:   <value>              ; Algorithm identifier
```

**Key observations:**
- Uses register %5 as parameter pointer (RSX-11M convention for Fortran-callable subroutines)
- Arguments are copied from caller's list to local storage before calling APEX
- The parameter block format is: `[4, CODE, START, SLIST, NSPADS]`
- All routines are .GLOBL and .TITLE with the same name

## 3. Key Routines / Data Structures

### Entry Points (28 total, all following the same pattern):

| Name | CODE | NSPADS | Purpose |
|------|------|--------|---------|
| VAVLIN | 56 | 6 | Vector average (linear) |
| VAVEXP | 57 | 6 | Vector average (exponential) |
| HIST | 72 | 7 | Histogram computation |
| VXCS | 42 | 6 | Vector cross-correlation |
| SHPHU | (not shown) | (not shown) | Sharpening/high-pass filter |
| ACORF | (not shown) | (not shown) | Auto-correlation function |
| ACORT | (not shown) | (not shown) | Auto-correlation (time domain) |
| ASPEC | (not shown) | (not shown) | Auto-spectrum |
| CCORF | (not shown) | (not shown) | Cross-correlation function |
| CCORT | (not shown) | (not shown) | Cross-correlation (time domain) |
| CFFTI | (not shown) | (not shown) | Complex FFT (inverse) |
| COHER | (not shown) | (not shown) | Coherence function |
| CPSTRM | (not shown) | (not shown) | Complex power spectrum |
| CSPEC | (not shown) | (not shown) | Cross-spectrum |
| DECFIR | (not shown) | (not shown) | Decimating FIR filter |
| ENVEL | (not shown) | (not shown) | Envelope detection |
| HANN | (not shown) | (not shown) | Hanning window |
| HLBRT | (not shown) | (not shown) | Hilbert transform |
| LPAUTO | (not shown) | (not shown) | Linear prediction (autocorrelation) |
| PKVAL | (not shown) | (not shown) | Peak value detection |
| RDFT | (not shown) | (not shown) | Real DFT |
| RFFTI | (not shown) | (not shown) | Real FFT (inverse) |
| TCONV | (not shown) | (not shown) | Time-domain convolution |
| TRANS | (not shown) | (not shown) | Transfer function |
| UNWRAP | (not shown) | (not shown) | Phase unwrapping |
| VDBPWR | (not shown) | (not shown) | dB power computation |
| WIENER | (not shown) | (not shown) | Wiener filter |

### Data Structures:
- **PARAM**: 4-word parameter block passed to APEX
- **CODE**: Algorithm identifier (unique per routine)
- **START**: Entry point in APAL microcode (0 = default)
- **SLIST**: Local storage for FPS-100 argument list
- **NSPADS**: Number of pad words in SLIST

## 4. External Dependencies

1.  **APEX** (`.GLOBL APEX`): The central dispatcher routine that:
    - Receives the parameter block via %5
    - Loads the appropriate APAL microcode into the FPS-100
    - Sets up the FPS-100 data memory with the SLIST arguments
    - Initiates execution on the FPS-100
    - Returns status/result to the caller

2.  **RSX-11M Calling Convention**: Uses register %5 as parameter pointer (standard for Fortran-callable routines under RSX-11M)

3.  **FPS-100 Microcode**: The actual algorithms are implemented in APAL microcode, identified by the CODE numbers. These are loaded by APEX from the `.APO` (APAL object) files.

4.  **No direct RSX directives**: Unlike driver-level code, this file doesn't use ALUN$, ATTACH, or other RSX executive directives. It operates purely at the user-callable subroutine level.

## 5. Subtleties

1.  **Argument copying pattern**: The `MOV @(%5)+,(%1)+` instruction copies arguments **indirectly** through the caller's parameter list. This suggests the caller passes pointers to the actual data arrays, not the data itself. The FPS-100 then accesses these arrays via its own data memory.

2.  **CODE numbering**: The CODE values (42, 56, 57, 72, etc.) are not sequential, suggesting they correspond to specific microcode load modules rather than being arbitrary indices. The gap between 57 and 72 may indicate other algorithms not included in this file.

3.  **NSPADS variation**: Most routines use 6 pad words, but HIST uses 7. This likely reflects different argument list structures required by different algorithms (e.g., HIST needs an extra parameter for number of bins).

4.  **START = 0 convention**: All routines shown use START = 0, meaning the default entry point. The structure supports non-zero start addresses for microcode that has multiple entry points.

5.  **No error checking**: The stubs perform no validation of argument counts or types. Error handling is delegated entirely to APEX and the FPS-100 microcode.

6.  **APAL microcode format**: The long hex data blocks (e.g., `040210,000000,000000,000060`) are **not** PDP-11 instructions but rather APAL microcode words formatted for the FPS-100's 64-bit instruction word. Each line represents one or more micro-instructions for the FPS-100's pipeline stages (memory address, ALU operations, register selects, etc.).

7.  **No conditional assembly**: Unlike some FPS-100 code that uses `.IF DF FPS100` to distinguish between AP-120B and FPS-100 variants, this file appears to be pure FPS-100 code with no AP-120B compatibility switches visible in the excerpt.

8.  **Performance optimization**: The use of `MOV #SLIST,%1` followed by `MOV @(%5)+,(%1)+` loop is a standard PDP-11 optimization for copying variable-length argument lists without subroutine calls. The loop is unrolled only by the BNE instruction, keeping it compact.
```

**GLM (1s):**

```
ERROR: HTTP Error 429: Too Many Requests
```

### Adversarial pass (final)

**DeepSeek revised (17s):**

```
Looking at this source file, I can provide a thorough analysis.

## 1. Purpose

This file is a **Host Service Routine (HSR) wrapper collection** for the FPS-100 array processor. Each entry point is a MACRO-11 subroutine that:
- Collects parameters from the caller's argument list
- Packages them into a parameter block
- Calls the central `APEX` dispatcher to load and execute APAL microcode on the FPS-100

These are not device drivers or sysgen config files - they are the user-callable signal processing library routines that form the high-level API for the FPS-100.

## 2. Calling Convention / Structure

Every routine follows an identical pattern:

```
ROUTINE: MOV (%5)+,%0        ; Get argument count
         BEQ NONE            ; If zero, skip parameter collection
         MOV #SLIST,%1       ; Point to local storage
LOOP:    MOV @(%5)+,(%1)+    ; Copy each argument pointer
         DEC %0
         BNE LOOP
NONE:    MOV #PARAM,%5       ; Point R5 to parameter block
         JSR %7,APEX         ; Call APEX dispatcher
         RTS %7              ; Return to caller
```

The parameter block contains:
- `PARAM`: Number of parameters (always 4)
- `CODE`: APAL microcode routine number
- `START`: Starting address (usually 0)
- `SLIST`: Pointer to argument list
- `NSPADS`: Number of pad words for argument list

## 3. Key Routines / Data Structures

The file contains **28 exported symbols** (from .GLOBL/.TITLE):

**Signal Generation:**
- `VAVLIN` - Variable amplitude linear sweep
- `VAVEXP` - Variable amplitude exponential sweep
- `SHPHU` - Shaped pulse (Hanning windowed)

**Transforms:**
- `RDFT` - Real Discrete Fourier Transform
- `RFFTI` - Real FFT initialization
- `CFFTI` - Complex FFT initialization
- `CCORF` - Cross-correlation function
- `ACORF` - Auto-correlation function

**Windowing/Weighting:**
- `HANN` - Hanning window
- `HIST` - Histogram
- `ENVEL` - Envelope detection

**Filtering:**
- `DECFIR` - Decimating FIR filter
- `TCONV` - Time-domain convolution
- `WIENER` - Wiener filter

**Spectral Analysis:**
- `CSPEC` - Cross-spectrum
- `ASPEC` - Auto-spectrum
- `COHER` - Coherence function
- `CPSTRM` - Cross-power stream
- `UNWRAP` - Phase unwrapping
- `PKVAL` - Peak value detection

**Other:**
- `HLBRT` - Hilbert transform
- `LPAUTO` - Linear prediction (autocorrelation)
- `TRANS` - Transfer function
- `VDBPWR` - Variable dB power
- `VXCS` - Variable cross-correlation shift
- `APEX` - The central dispatcher (called, not defined here)

## 4. External Dependencies

- **APEX** - The central dispatcher routine (called via JSR %7,APEX)
- **Register usage**: R5 points to parameter block, R7 is return address
- **No RSX directives** - These are pure subroutine calls, not task-building directives
- **No hardware register access** - All hardware interaction goes through APEX

## 5. Subtleties

1. **Parameter passing**: Uses R5-based argument passing (common in FORTRAN-callable routines on RSX-11M). The `@(%5)+` construct dereferences pointers from the argument list.

2. **Code numbering**: Each routine has a unique `CODE` number (56, 57, 72, 42, etc.) that identifies which APAL microcode program to load and execute on the FPS-100.

3. **Pad words**: `NSPADS` varies (6, 7, etc.) depending on how many arguments the APAL routine expects.

4. **No conditional assembly**: No `.IF DF FPS100` or similar constructs - this is pure MACRO-11 for the PDP-11 host.

5. **The APAL microcode** is embedded as octal constants in the `CODE:` blocks - these are not PDP-11 instructions but rather FPS-100 microcode words (4 words per line, 64 bits each).

## Evaluation of Peer Analysis

The peer analysis is **completely absent** (HTTP 429 error). I cannot evaluate it. However, I can state that my analysis above is based on direct examination of the source code and knowledge of the FPS-100 architecture.

**Key corrections to common misconceptions:**
- These are NOT device drivers - they're library routines
- The octal data blocks are NOT PDP-11 instructions - they're FPS-100 microcode
- The file does NOT contain RSX directives or sysgen configuration
- `APEX` is called, not defined here - it's the actual dispatcher that manages the FPS-100 hardware
```

**GLM revised (1s):**

```
ERROR: HTTP Error 429: Too Many Requests
```

## [327,010]UTLHSR.MAC

- 24 lines
- 2 exported symbols
- exports: `APEX, APNOP`

### Cooperative pass

**DeepSeek (19s):**

```
Based on the 24-line source file `[327,010]UTLHSR.MAC` from the FPS-100 RSX-11M v3.2 distribution, here is the structured analysis:

## 1. Purpose

This file is a **Host Service Routine (HSR) wrapper** for the FPS-100 array processor. Specifically, it implements the **APNOP** (Array Processor No-Operation) function, which is a diagnostic/initialization subroutine that sends a NOP command to the FPS-100 and waits for completion. It follows the standard HSR pattern used in the FPS-100 RSX-11M driver stack, where each HSR is a self-contained subroutine that builds a parameter block and calls the main driver entry point `APEX`.

## 2. Calling Convention / Structure

This is a **self-contained subroutine** with a single entry point (`APNOP`). The calling convention is:

- **Entry**: Called via `JSR %7,APNOP` (or `CALL APNOP` in MACRO-11)
- **Arguments**: None (the NOP operation requires no user parameters)
- **Register usage**: 
  - `%5` (R5) is used as a parameter pointer
  - `%0` (R0) holds the count of S-list entries
  - `%1` (R1) points to the S-list buffer
  - `%7` (R7/PC) is used for the JSR to APEX
- **Exit**: Returns via `RTS %7` with no return value

The structure follows a three-phase pattern:
1. **Parameter list construction** (lines 6-11): Builds a 4-word parameter block at `PARAM`
2. **Call to APEX** (line 12): `JSR %7,APEX` invokes the main driver
3. **Return** (line 13): `RTS %7`

## 3. Key Routines / Data Structures

### Entry Points:
- **`APNOP`**: Main entry point. Sends a NOP command to the FPS-100.

### Data Structures (at `PARAM`):
| Offset | Name | Value | Purpose |
|--------|------|-------|---------|
| 0 | `4` | 4 | Parameter count (4 words follow) |
| 2 | `CODE` | 1 | Function code (1 = NOP) |
| 4 | `START` | 0 | Starting address (unused for NOP) |
| 6 | `SLIST` | (buffer) | S-list buffer address |
| 8 | `NSPADS` | 0 | Number of SPADs (0 for NOP) |

### Internal Labels:
- **`LOOP`**: Copies S-list entries from the parameter block to the local buffer
- **`NONE`**: Jump target when no S-list entries exist
- **`PARAM`**: Parameter block passed to APEX
- **`SLIST`**: Scratch buffer for S-list data (`.BLKW 0.` = zero-length placeholder)
- **`NSPADS`**: SPAD count (initialized to 0)

## 4. External Dependencies

- **`APEX`** (global symbol): The main FPS-100 driver entry point. Called via `JSR %7,APEX` with `%5` pointing to the parameter block.
- **No RSX-11M directives** (no `.DIRECT`, no `ATTACH`, no `ALUN$`): This is a pure subroutine, not a system service call.
- **No hardware register access**: All hardware interaction is handled by `APEX`.

## 5. Subtleties

1. **S-list handling**: The code copies S-list entries from the parameter block to a local buffer (`SLIST`). The `MOV @(%5)+,(%1)+` instruction uses auto-increment deferred addressing to copy the S-list addresses. The `SLIST` buffer is declared as `.BLKW 0.` (zero-length), meaning the actual buffer space is allocated elsewhere (likely in the calling routine's stack frame).

2. **Parameter block format**: The parameter block at `PARAM` follows the standard FPS-100 HSR convention:
   - First word: count of remaining words
   - Then: CODE, START, SLIST, NSPADS
   - The `SLIST` field points to the actual S-list buffer (which is at `SLIST` label)

3. **NOP function specifics**: The NOP function (CODE=1) requires no SPADs (NSPADS=0) and no starting address (START=0). The S-list is empty (the loop at `LOOP` is skipped because `%0` is 0 after the `MOV (%5)+,%0` instruction).

4. **Register preservation**: The routine does **not** save/restore registers `%0`, `%1`, or `%5`. This is typical for FPS-100 HSRs, which assume the caller has saved necessary registers.

5. **The `000000,000340,000000,000000` line**: This appears to be a **microcode word** or **hardware initialization constant** embedded in the source. The value `000340` (octal) = 0xE0 (hex) could be a control register setting or a microcode instruction for the FPS-100. This is unusual for a standard HSR and may be a remnant or a special initialization value.

6. **No conditional assembly**: Unlike many FPS-100 files, this one has no `.IF DF FPS100` or similar conditionals, suggesting it's common to both FPS-100 and AP-120B implementations.

7. **The `APNOP` routine is a no-op wrapper**: It builds a parameter block for a NOP command and calls APEX. The actual NOP operation is performed by the APEX driver, which handles the hardware interaction.
```

**GLM (1s):**

```
ERROR: HTTP Error 429: Too Many Requests
```

### Adversarial pass (final)

**DeepSeek revised (18s):**

```
Based on the source file provided, here is my structured analysis, followed by a critical evaluation of the peer's (GLM's) non-existent analysis.

## Structured Analysis of `UTLHSR.MAC`

### 1. Purpose

This file is a **Host Service Routine (HSR) wrapper** for the FPS-100 array processor. Specifically, it implements the `APNOP` operation (Array Processor No Operation). In the FPS-100 host software stack, HSRs are small, reentrant routines that execute in the host (PDP-11) context to initiate and manage a single operation on the array processor. This particular HSR sends a "NOP" command to the AP, which is typically used for initialization, synchronization, or as a benign test of the communication path.

### 2. Calling Convention / Structure

This is a **self-contained module** with a single entry point (`APNOP`). It follows the standard FPS-100 HSR calling convention:

- **Entry:** Called with `JSR %7,APNOP` (or similar). Upon entry, `%5` points to a parameter list in the caller's space.
- **Parameter List:** The caller provides a list of arguments. The HSR reads the first word as a count of remaining parameters.
- **Execution:** The routine copies the parameter list to a local buffer (`SLIST`), then sets up a new parameter block (`PARAM`) for the `APEX` kernel routine.
- **Exit:** Returns to the caller via `RTS %7`.

### 3. Key Routines / Data Structures

- **`APNOP`:** Entry point. Reads parameter count from `(%5)+`, copies parameters to local storage, then calls `APEX` with a constructed parameter block.
- **`APEX`:** External kernel routine (called via `JSR %7,APEX`). This is the core interface to the FPS-100 driver; it takes a parameter block and initiates the actual AP operation.
- **`PARAM`:** A data block (starting at label `PARAM`) containing the parameters for `APEX`:
  - `4` : Number of parameters following (4 words).
  - `CODE` : Operation code (value 1, representing NOP).
  - `START` : Starting address in AP memory (0, unused for NOP).
  - `SLIST` : Address of the parameter list buffer (unused for NOP).
  - `NSPADS` : Number of SPADS (unused for NOP, set to 0).
- **`SLIST`:** Local buffer (`.BLKW 0.`) for copying caller's parameters. In this NOP case, it's empty.
- **`NSPADS`:** Word initialized to 0. Number of SPAD (Scratchpad) words to transfer.
- **`START`:** Word initialized to 0. AP memory start address.
- **`CODE`:** Word initialized to 1. The AP operation code for NOP.

### 4. External Dependencies

- **`APEX`:** The only external routine called. This is the central dispatcher in the FPS-100 host software that queues and initiates AP operations.
- **Register conventions:** Uses `%0`, `%1`, `%5`, `%7` (PC). Assumes `%5` points to a parameter list on entry.
- **No RSX directives** (like `ALUN$`, `ATTACH`) are used directly; all OS interaction is through `APEX`.

### 5. Subtleties

- **Parameter copying:** The routine copies the caller's parameter list to a local buffer (`SLIST`). This is a defensive measure to ensure the parameter list remains valid even if the caller's stack or data area is modified.
- **NOP operation:** The `CODE` value of 1 and the `START`/`NSPADS` values of 0 are specific to the NOP operation. Other HSRs would have different code values and meaningful start addresses/counts.
- **No conditional assembly:** There are no `.IF DF FPS100` directives, suggesting this routine is common to both FPS-100 and AP-120B implementations.
- **The `MOV (%5)+,%0` / `BEQ NONE` pattern:** This is a standard HSR preamble to handle zero-length parameter lists gracefully.

## Critical Evaluation of Peer Analysis (GLM)

The peer analysis is **entirely absent** (HTTP 429 error). Therefore:

- **Agreement:** I agree that the peer's analysis is missing.
- **Disagreement:** I disagree with any implicit claim that the analysis is valid or useful. The peer failed to produce any output.
- **Missed:** The peer missed the entire content of the file, its structure, purpose, and all technical details.

## Final Analysis

My analysis above stands as the complete and correct interpretation of `UTLHSR.MAC`. The peer's contribution is null and does not warrant any modification to my findings. The file is a straightforward, well-structured HSR for the `APNOP` operation, demonstrating the standard pattern for all FPS-100 HSRs: copy parameters, construct an APEX parameter block, and call the kernel dispatcher.
```

**GLM revised (1s):**

```
ERROR: HTTP Error 429: Too Many Requests
```

