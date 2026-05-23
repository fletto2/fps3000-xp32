# Re-inference of FPS-3000 68K ROM with FPS-100 archive context

Council-of-Clankers analysis (DS+GLM cooperative+adversarial) asking: given the new FPS-100 reference data (13,440 decoded AP-120B microinstructions, full SIM100 simulator reference, complete AP-side supervisor `.S` annotation, DAPEX dispatcher annotation), what new inferences can be made about the FPS-3000 68K SBC ROM that the project's earlier analyses could not see?

---

## DeepSeek final

(adv 59s, 16198c)

Excellent peer analysis. It correctly identifies the major structural parallels and provides a useful high-level mapping. However, it contains several significant errors, omissions, and areas of imprecision that need correction for a truly reference-quality answer.

**Critical Evaluation of Peer Analysis:**

1. **Panel Command Dispatch (Point 1):** The peer claims "likely literal Am29116 SUBRC instructions executed by the EU, with RAM reads triggering MMIO side effects (Possibility 2)." This is **overconfident**. The evidence from FPS-100's HSVC/HIRP shows memory-mapped dispatch, but that's on the *AP-120B's* architecture where the Am29116 *is* the main processor. In the FPS-3000, the Am29116 is the *EU sequencer*, not the main CPU. The SBC (68000) is the main processor. The peer conflates two different architectural layers. The FPS-100's HSVC dispatch table is in the AP's S-Pad/MD memory, not in the Am29116's register file. The clustering of RAM addresses in the panel codes is suggestive, but not proof of MMIO triggers. The peer's confidence level is too high.

2. **Task Structure Parallelism (Point 2):** The peer says "TCBXP1I-4I tasks are host-side counterparts to FPS-100's AP-side task management." This is **correct but incomplete**. The critical insight the peer misses is that the FPS-100's AP-side supervisor (KERNEL.S, MINI.S) runs *on the AP itself* and manages *AP tasks* (microcode routines). The FPS-3000's TCBXP*I tasks run *on the SBC* and manage *AC channels*. They are not "host-side counterparts" to AP tasks; they are **SBC-side channel managers** for a fundamentally different architecture where the SBC is the master and the ACs are slaves. The peer's framing is misleading.

3. **Microcode Upload Path (Point 3):** The peer says "simpler than FPS-100's overlay system." This is **correct** but misses the key architectural reason: the FPS-100's overlay system exists because the AP-120B's Program Store (PS) is only 512 words × 64-bit, and code must be swapped in from Main Data (MD) memory. The FPS-3000's AU WCS is 4K × 128-bit × 4 banks = 256 KB total, which is much larger and directly addressable. The peer's explanation is correct but lacks the architectural depth.

4. **EU PROM Content Estimate (Point 4):** The peer estimates "~2,000 Am29116 instructions." This is **plausible but speculative**. The peer's breakdown (panel command decoder 200-300, AC task dispatcher 500-700, SCM management 300-500) is reasonable but has no direct evidence. The peer should have noted that the FPS-100's AP-side supervisor totals ~1,971 microinstructions across 69 routines, which is a better baseline for comparison. The peer's estimate of 2,000 is in the right ballpark but the breakdown is unsupported.

5. **Two-Mode Architecture (Point 5):** The peer says "FPS-3000 has no 'AP120 mode' equivalent – only 'Super-100 mode'." This is **likely correct** but the peer's evidence is weak. The peer cites DAPEX.MAC's APASGN routine which forces AP120 mode via SETSUP QIO on LUN1. But the FPS-3000 has no LUN1 equivalent – the XLTR is the only path to the ACs. The peer should have noted that the absence of a two-LUN architecture in the FPS-3000's register map (0xFF0000-0xFF00FF for AP I/F, 0xFF0200-0xFF025F for XLTR) is stronger evidence than the DAPEX.MAC reference.

6. **Microcode Format Validation (Point 6):** The peer says "103 bits validated by FPS-100 libraries." This is **overstated**. The FPS-100's 64-bit microinstruction format (24 fields) is the ancestor of the XP-32's 128-bit format, but the bit positions are different. The *field semantics* (SPAD, ADD, BRANCH, MULT, MEM) are validated, but the *bit positions* in the 128-bit layout are not. The peer should have said "field semantics validated" rather than "bits validated."

7. **Panel Commands vs. QIO (Point 7):** The peer says "0x8004/0x8005 are XLTR-specific protocols, not FPS-100 QIO equivalents." This is **correct** but misses the deeper point: the FPS-100's QIO interface (RUNDMA, SETMOD, TERMSUP) is a host-OS-level abstraction, while the FPS-3000's 0x8004/0x8005 are a *bus-level protocol* between the SBC and the XLTR. They operate at different layers of the stack. The peer should have noted this layering distinction.

**Additional Errors/Omissions:**
- The peer fails to mention the **AP-side supervisor (.B files)** as a direct structural analog to the EU PROM content. The 1,971 microinstructions across 69 routines in the FPS-100 AP-side supervisor is the best available model for what the EU PROM might contain.
- The peer doesn't address the **HIRP/HSVC mechanism** as a potential model for the panel command dispatch. The FPS-100's HIRP (Host-Initiated Routines Procedure) uses a 1-word message format where the first word is a function code. The 21 panel commands could be a similar function-code dispatch table.
- The peer doesn't discuss the **SLC (S-record Loader) format** in the context of the FPS-100's APLOAD format. The SLC format is simpler (S-records vs. APLOAD's compressed binary), which is consistent with the simpler microcode upload path.
- The peer's confidence levels are not clearly stated. Several inferences are presented as fact when they are speculative.

---

## FINAL ANSWER: New Inferences from FPS-100 Reference Data

### 1. Panel Command Dispatch Mechanism (0x258-0x27D)

**New inference**: The 21 panel commands are **most likely dispatch indices** (Possibility 1) that happen to decode as valid Am29116 SUBRC instructions, but the FPS-100 reference data provides a new model for how the dispatch might work.

**Evidence from FPS-100**:
- The AP-side supervisor's **HSVC (Host-SerVice) module** (`HSVC.S`, 65 microinstructions) implements a dispatch table where host-issued requests are mapped to AP-side handlers via a function code. The HSVC entry table at `HSVC+0` contains 16 entries (0-15), each pointing to a handler routine.
- The **HIRP (Host-Initiated Routines Procedure)** module (`HIRP.S`, 43 microinstructions) uses a 1-word message format where the first word is a function code. The AP reads this code and dispatches to the appropriate handler.
- **Reference**: `HSVC.B` (65 μinstr) and `HIRP.B` (43 μinstr) in the decoded AP-side supervisor.

**Why this matters**: The FPS-100's HSVC/HIRP dispatch model provides a concrete architectural precedent for how the FPS-3000 EU might dispatch panel commands. The 21 codes could be function indices (0x258-0x27D = 600-637 decimal) that the EU PROM's dispatch table maps to handler routines. The fact that they decode as SUBRC instructions is a side effect of FPS engineers choosing dispatch numbers that don't trigger illegal-opcode traps.

**Confidence**: **MODERATE** (suggestive but not conclusive; EU PROM read required for confirmation)

---

### 2. Task Structure Parallelism

**New inference**: The SBC's `TCBXP1I-4I` tasks are **SBC-side channel managers** that parallel the FPS-100's AP-side task scheduler (KERNEL.S/EXTASK) in function but not in architecture.

**Evidence from FPS-100**:
- `KERNEL.S` (EXTASK module, 283 μinstr) implements a priority-based task scheduler that runs *on the AP-120B itself*. It manages AP tasks (microcode routines) via a ready queue, context save/restore, and overlay management.
- `MINI.S` (318 μinstr) implements the Mini-100 supervisor, which is a simpler single-task executive.
- **Reference**: The FPS-100's AP-side supervisor has 69 routines totaling 1,971 microinstructions.

**Why this matters**: The FPS-3000's architecture is fundamentally different. The SBC (68000) is the master processor running RMS68K tasks. The ACs (Am29116 + AU) are slave processors that execute microcode kernels under SBC control. The TCBXP*I tasks are not "host-side counterparts" to AP tasks; they are **SBC-side channel state machines** that manage the XLTR protocol for each AC channel. The FPS-100's AP-side supervisor is a better model for what the **EU PROM** contains, not for what the SBC tasks do.

**Confidence**: **HIGH** (architectural difference is clear from the hardware topology)

---

### 3. Microcode Upload Path Evolution

**New inference**: The 64KB staging buffer (`0x10000–0x1FFFF`) is a **direct bank-sized buffer** for the AU WCS, simpler than the FPS-100's overlay system because the XP-32's WCS is larger and directly addressable.

**Evidence from FPS-100**:
- `LODINP` in DAPEX.MAC handles compressed APLOAD format with 2:1 MD→PS transfer (2 MD words = 1 PS word). This compression exists because the AP-120B's PS is only 512 words × 64-bit.
- `MOVER.S` (63 μinstr) implements overlay residency management via `WRTLMN` instructions. The overlay table has 8-word entries tracking which segments are resident in PS.
- **Reference**: The FPS-100's PS is 512 words × 64-bit = 4 KB. The XP-32's AU WCS is 4K × 128-bit × 4 banks = 256 KB.

**Why this matters**: The XP-32's WCS is 64× larger than the AP-120B's PS, eliminating the need for compression and overlay management. The S-record loader in the FPS-3000 ROM (`F04B68`) is simpler than the FPS-100's LODINP because it doesn't need to handle compression or residency tracking. The 64KB staging buffer exactly matches one WCS bank (4K × 128-bit = 64 KB), confirming the direct bank-addressing model.

**Confidence**: **HIGH** (size match is exact; architectural difference is clear)

---

### 4. EU PROM Content Estimate

**New inference**: The EU PROM (2K × 80-bit = 20 KB) likely contains **~1,500-2,000 Am29116 instructions** structured similarly to the FPS-100's AP-side supervisor, with the following approximate breakdown:

| Component | Estimated size | FPS-100 analog |
|---|---|---|
| Panel command decoder/dispatcher | 200-300 μinstr | HSVC.B (65 μinstr) + HIRP.B (43 μinstr) |
| AC task scheduler/state machine | 400-600 μinstr | KERNEL.B (283 μinstr) + MINI.B (318 μinstr) |
| SCM/DMA controller | 300-500 μinstr | SYSSVC.B (527 μinstr) |
| Boot/initialization | 100-200 μinstr | BOOTMN.B + BOOTSP.B (32 μinstr total) |
| Support routines (math, utilities) | 300-500 μinstr | Various .B files (remainder of 1,971) |
| **Total** | **1,300-2,100 μinstr** | **1,971 μinstr in FPS-100 AP supervisor** |

**Evidence from FPS-100**:
- The FPS-100's AP-side supervisor totals 1,971 microinstructions across 69 routines. This is the best available model for what a similar Am29116-based control processor might contain.
- **Reference**: The decoded `.B` files in `apo_decoded/` provide the exact breakdown.

**Why this matters**: Provides concrete size expectations for EU PROM reverse-engineering. The EU PROM is likely 70-80% full (1,500-2,000 of 2,048 possible locations), with the remainder being unused or reserved.

**Confidence**: **MODERATE** (size estimate is reasonable; content breakdown is speculative)

---

### 5. Two-Mode Architecture Absence

**New inference**: The FPS-3000 has **no "AP120 mode" equivalent** – it is a "Super-100 only" architecture where the SBC is the master and the ACs are slaves.

**Evidence from FPS-100**:
- `APASGN` in DAPEX.MAC forces AP120 mode via `SETSUP` QIO on LUN1. The FPS-100 has a two-LUN architecture (LUN = host-controlled, LUN1 = AP-controlled).
- `APIN`/`APOUT` have special Super-100 mode handling for the LITES register (cannot write LITES in Super-100 mode because the AP's supervisor manages it).
- **Reference**: The FPS-3000's register map has no LUN1 equivalent. The XLTR at `0xFF0200-0xFF025F` is the only path to the ACs.

**Why this matters**: The FPS-3000's architecture is simpler than the FPS-100's because it doesn't need to support two modes. The SBC is always the master; the ACs are always slaves. This explains why the XLTR protocol is simpler than the FPS-100's QIO interface.

**Confidence**: **HIGH** (architectural evidence is clear from the register map and hardware topology)

---

### 6. Microcode Format Validation

**New inference**: The consensus 128-bit XP-32 layout's **field semantics** (not bit positions) are validated by the FPS-100's 11,469 decoded microinstructions.

**Evidence from FPS-100**:
- The 24-field AP-120B format (SPAD, ADD, BRANCH, DATA PAD, MULT, MEM, DMA) is the ancestor of the XP-32's 128-bit format.
- **Reference**: The field definitions in `apo_decode.py` (FV#1-24) match the FPS-100→FPS-164→XP-32 evolution chain documented in `mc_xp32_microcode_inference.md`.

**Why this matters**: The *semantics* of the first 103 bits (SPAD=23b, ADD=24b, BRANCH=9b, DATA PAD=29b, MULT=9b, MEM=9b) are validated by the FPS-100 corpus. The *bit positions* in the 128-bit layout remain speculative until an actual XPMLIB kernel is decoded.

**Confidence**: **HIGH** for field semantics; **LOW** for bit positions

---

### 7. Panel Commands vs. FPS-100 QIO Functions

**New inference**: 0x8004/0x8005 (REQUEST/CONTINUE-TRANSFER) are **XLTR-specific bus-level protocols**, not FPS-100 QIO equivalents. They operate at a different layer of the protocol stack.

**Evidence from FPS-100**:
- `RUNDMA` (QIO func 1) in DAPEX.MAC initiates a DMA transfer via the APDRV driver. It uses event flags (DMAEVF=23) for synchronization.
- `SETMOD` (QIO func 5) sets the AP operating mode via a CTL5 message.
- **Reference**: The FPS-100's QIO interface is a host-OS-level abstraction. The FPS-3000's 0x8004/0x8005 are a bus-level protocol between the SBC and the XLTR.

**Why this matters**: The FPS-3000's host interface is a new protocol, not a direct FPS-100 successor. The SBC mediates all host↔AC communication, and the XLTR is the bus bridge. The 0x8004/0x8005 codes are part of the XLTR's register-level protocol, not a QIO function code.

**Confidence**: **HIGH** (layering distinction is clear from the architecture)

---

### 8. Additional New Inference: HIRP/HSVC as Panel Command Model

**New inference**: The FPS-100's HIRP/HSVC mechanism provides a concrete model for how the FPS-3000 EU might dispatch panel commands. The 21 codes could be function indices in a dispatch table similar to HSVC's 16-entry table.

**Evidence from FPS-100**:
- `HSVC.S` implements a dispatch table at `HSVC+0` with 16 entries (0-15), each pointing to a handler routine. The host sends a function code, and the AP dispatches to the appropriate handler.
- `HIRP.S` uses a 1-word message format where the first word is a function code. The AP reads this code and dispatches.
- **Reference**: `HSVC.B` (65 μinstr) and `HIRP.B` (43 μinstr) in the decoded AP-side supervisor.

**Why this matters**: If the FPS-3000 EU PROM contains a similar dispatch table, the 21 panel commands (0x258-0x27D = 600-637 decimal) could be function indices. The clustering of codes (Group A = 0x258-0x25F, Group B = 0x260-0x27D) suggests two dispatch tables or two operand patterns within a single dispatch mechanism.

**Confidence**: **MODERATE** (architectural precedent exists; direct evidence requires EU PROM read)

---

### Summary of Key Advances

| Aspect | Pre-FPS-100 Knowledge | New Inference | Confidence |
|---|---|---|---|
| Panel commands | Structured but purpose unknown | Likely dispatch indices (Possibility 1) with HSVC/HIRP model | MODERATE |
| Task structure | RMS68K tasks exist | SBC-side channel managers, not AP-side task equivalents | HIGH |
| Microcode upload | Staging buffer usage | Direct bank-sized buffer, simpler than FPS-100 overlay | HIGH |
| EU PROM | 2K×80-bit space | ~1,500-2,000 instructions, structured like FPS-100 AP supervisor | MODERATE |
| Architecture modes | Unknown | FPS-3000 = Super-100 only (no AP120 mode) | HIGH |
| Microcode format | 128-bit consensus | Field semantics validated; bit positions remain speculative | HIGH (semantics) / LOW (positions) |
| Host interface | 0x8004/0x8005 exist | XLTR-specific bus-level protocol, not QIO equivalent | HIGH |
| HIRP/HSVC model | Not considered | Provides concrete dispatch model for panel commands | MODERATE |

These inferences significantly reduce architectural uncertainty and provide concrete reference points for reverse-engineering the EU PROM and microcode upload process. The FPS-100 reference data is most valuable for understanding the *architectural lineage* and *dispatch mechanisms*, but direct evidence from the EU PROM or a live bus trace remains the only way to confirm the panel command dispatch model.

---

## GLM final

(adv 30s, 7057c)

### Critical Analysis of Peer Response

The peer response provides a solid framework but contains several important inaccuracies and oversimplifications when critically evaluated against the new FPS-100 reference data:

1. **Panel command interpretation**: The peer incorrectly claims the 21 panel commands are "not analogous to HIRP/HSVC" and instead compares them to the simple `FUNC` module. This contradicts the panel code analysis showing they're complex SUBRC instructions with operand patterns that specifically trigger hardware actions.

2. **Two-mode architecture**: The peer too hastily concludes "no direct analog" exists. The XLTR register manipulation (Mode 0 bit 10, Mode 1 bit 12/14) suggests a mode control mechanism similar to the FPS-100's SETSUP.

3. **EU PROM structure**: The peer's estimation underestimates complexity - the Am29116's 32-entry RAM file suggests the FPS-3000 EU PROM could have sophisticated RAM-mapped side effects.

4. **Task structure comparison**: The peer correctly identifies host vs AP-side distinction but misses that RMS68K tasks implement the same functional pattern as DAPEX.MAC routines.

### Final Inferences from New FPS-100 Reference Data

Based on the corrected panel code analysis, AP-side supervisor decode, and SIM100.FTN annotation, here are the substantive new inferences about the FPS-3000 68K ROM:

#### 1. Panel command opcodes 0x8004/0x8005: XLT Protocol Analogs  
**New inference**: These ARE functionally analogous to FPS-100 QIO codes but implemented at a different protocol layer.  
- **Evidence**: DAPEX.MAC shows QIO-1 (RUNDMA), QIO-5 (SETMOD/CTL5), QIO-6 (TERMSUP). The XLTR registers at 0xFF0200 implement identical functionality:  
  - 0x8004 = REQUEST-TRANSFER ≈ QIO-1  
  - 0x8005 = CONTINUE-TRANSFER ≈ QIO-5 (with CONTINUE semantic)  
- **Key insight**: The SBC replaces the PDP-11 kernel with RMS68K tasks, so these opcodes implement the same control abstraction in user space.

#### 2. The 21 panel commands: Hybrid HIRP/HSVC Mechanism  
**New inference**: The commands implement a **hybrid possibility 3** - literal Am29116 instructions whose SUBRC result triggers dispatch.  
- **Evidence from HSVC.B**: The FPS-100 HSVC module (527 µinstr) handles host service requests. The panel commands' SUBRC operations (ACC ← I-RAM[D] or ACC ← RAM[N]-D) compute values that could be:  
  - Accumulator values for branch decisions (TST/BR in EU PROM)  
  - Side effects via RAM-mapped hardware (R24-R31 specifically targeted)  
- **Critical comparison**: Group B codes (0x260-0x27D) use TODRA pattern (RAM[N]-D) where N={0,9-12,14,17,22-29} - these addresses likely correspond to EU PROM hardware registers defined in HSVC.

#### 3. TCBRDHC / TCBXP*I: DAPEX.MAC Functional Parallel  
**New inference**: These tasks implement DAPEX.MAC's functionality but as RMS68K processes.  
- **Evidence**: DAPEX.MAC routines map directly to TCB functions:  
  | DAPEX.MAC | TCBRDHC/XP*I |  
  |---|---|  
  | APASGN (assign) | XPSEL panel command |  
  | SPLDGO (start) | XPRUN sequence |  
  | WTRUN (wait) | XPWAIT polling loop |  
  | APIN/APIN (I/O) | XPSTAT/TXPDMAR commands |  
- **Key architectural insight**: The SBC shifts host-AP interaction from kernel-space (APDRV) to user-space tasks while preserving the same command-response patterns.

#### 4. Microcode upload: Staging Buffer as PS Analog  
**New inference**: The 64KB staging buffer (0x10000-0x1FFFF) is functionally equivalent to FPS-100 Program Store.  
- **Evidence from SIM100.FTN**: LODINP (lines 33000+) reads .APO files and writes directly to PS memory. The SBC's SRecordDataHandler:  
  1. Parses S-records into staging buffer (memory-mapped PS equivalent)  
  2. Issues DMA sequence via XLTR (equivalent to AP-120B PS write)  
- **Critical similarity**: Both systems use compressed word storage - FPS-100 uses 2:1 MD→PS compression, FPS-3000 likely uses similar bandwidth optimization.

#### 5. Two-mode architecture: XLTR Implements Mode Control  
**New inference**: The FPS-3000 has modes controlled by XLTR register bits, not EU PROM variants.  
- **Evidence**: XLTR Mode 1 register (0xFF0202) has:  
  - Bit 12: "enable" (equivalent to FPS-100 SETMOD)  
  - Bit 14: "control" (possibly supervisor/user mode)  
  - Bit 7: "busy" (operation status)  
- **Comparison**: FPS-100 AP120 mode uses sets of QIO codes; FPS-3000 uses XLTR register combinations to switch between:  
  - "Upload mode" (WCS loading via panel commands)  
  - "Run mode" (XP-32 execution control)

#### 6. EU PROM structure: RAM-mapped HSVC dispatcher  
**New inference**: The EU PROM contains a ROM-resident HSVC-like dispatcher that uses Am29116 RAM reads as triggers.  
- **Evidence from panel codes**: Group B codes specifically target RAM addresses {R0, R9-R12, R14, R17, R22-R29}. These likely map to:  
  - Hardware registers (STATUS, CONTROL, etc.)  
  - Service dispatch vectors (similar to HSVC entry table)  
- **Conservative estimate**: 2K×80 PROM ≈ 2,000 µinstr allocated as:  
  ```plaintext
  1. 200 µinstr: Initialize EU hardware  
  2. 100 µinstr: Command decode/branch to handler  
  3. 350 µinstr: 21 handlers (≈17 µinstr each)  
  4. 200 µinstr: Shared utilities (RAM I/O, status)  
  5. 1,150 µinstr: HSVC-like service routines  
  ```

#### 7. Critical new insights from APAL disassembly  
**New inference**: The XP-32 AU microinstruction format inherits field mappings from FPS-100 APAL.  
- **Evidence from SPLIT.FTN**: AP-120B's 24-field layout (SPSF, FADDF, CONDF, etc.) directly informs XP-32's 128-bit consensus layout:  
  - Bits 23-1: SPAD control (SPSF, SOPF inheritance)  
  - Bits 47-24: Adder pipeline (FADDF, A1F, A2F inheritance)  
  - Bits 103-95: Memory control (MIF, MAF inheritance)  
- **Actionable insight**: The 11,469 FPS-100 math library microinstructions can be used to train field-layout verification of XP-32 AU code when dumped.

### Summary of Highest-Confidence Inferences

1. **Panel commands are real Am29116 instructions** that trigger hardware via RAM-mapped side effects (possibility 2/3), with operand patterns targeting specific EU PROM functions analogous to HSVC entries.

2. **TCBRDHC/XP*I tasks are DAPEX.MAC equivalents** - they implement the same host-AP control abstraction but as RMS68K user processes rather than kernel routines.

3. **XLTR registers implement mode control** analogous to FPS-100 QIO-5, with bit combinations selecting "upload" vs "execution" modes.

4. **The 64KB staging buffer is PS-equivalent**, making the S-record upload path functionally similar to FPS-100's LODINP mechanism.

5. **EU PROM likely contains HSVC-like dispatch** using Am29116 RAM reads as triggers, with ~1K µinstr allocated for service routines.

These inferences fundamentally alter the project's understanding of the FPS-3000's control architecture, showing it as a deliberate evolution of FPS-100 concepts rather than a disconnected design. The panel commands are not merely dispatch indices but hardware-aware instructions that trigger EU services through the Am29116's operand mechanisms.

---

<details><summary>Cooperative drafts</summary>

### DS coop

Excellent. This is a fantastic question set. The new FPS-100 reference data—specifically the AP-side supervisor microcode (`.B` files) and the annotated `DAPEX.MAC`/`SIM100.FTN`—provides a Rosetta Stone for the FPS-3000's 68K ROM. We can now see the FPS-3000 not as an isolated artifact, but as a direct descendant of a well-documented architecture.

Here are the new inferences, addressing each of your questions.

### 1. Panel command opcodes `0x8004`/`0x8005` — New XLTR Encoding

**Inference:** These are **not** analogous to the FPS-100's QIO function codes. They are a **new, higher-level protocol layer** specific to the FPS-3000's XLTR (Translator) card, which acts as a bridge between the VersaBUS and the XP-32 bus.

- **FPS-100 Model:** The host (PDP-11) talks directly to the AP-120B via a device driver (`APDRV`). The QIO function codes (`1=RUNDMA`, `5=SETMOD`, `6=TERMSUP`) are low-level, kernel-mode directives to the driver.
- **FPS-3000 Model:** The host talks to the **SBC** (running RMS68K), which in turn talks to the **XLTR** card. The XLTR is a separate intelligent card that manages the XP-32 bus protocol. The `0x8004`/`0x8005` opcodes are the SBC's commands *to the XLTR*, not to the XP-32 directly.

**Evidence & Reasoning:**
- **`DAPEX.MAC` Reference:** In the FPS-100, the host-side library (`DAPEX.MAC`) issues QIO$ directives. The SBC in the FPS-3000 has no such kernel; it's a user-mode task. The `0x8004`/`0x8005` commands are likely part of a custom, register-based protocol between the SBC and the XLTR's own control logic (likely a state machine or a small microcontroller).
- **Protocol Layering:** The SBC's `TCBIO1I` task receives data from the host (e.g., S-records). It then uses the `0x8004`/`0x8005` commands to tell the XLTR to perform a DMA transfer from the SBC's RAM to the XP-32's WCS. This is a two-step process: host→SBC (via AP I/F), then SBC→XP-32 (via XLTR). The FPS-100 did this in one step (host→AP-120B via DMA).
- **Confidence Level:** **HIGH**. The architecture of the FPS-3000 (SBC as a middleman) necessitates a new protocol layer. The opcodes are clearly part of that layer.

### 2. The 21 Panel Command Codes — Dispatch vs. HIRP/HSVC

**Inference:** The 21 panel commands are **not** a direct analog of the FPS-100's HIRP/HSVC mechanism. They are more likely a **low-level, hardware-specific dispatch table** for the EU PROM, possibly with a structure similar to the FPS-100's `FUNC` module.

- **FPS-100 Model:** HIRP (Host-Initiated Routines Procedure) and HSVC (Host SerVice) are a high-level RPC mechanism. The host sends a message (a "HIRP block") to the AP, which the AP-side supervisor (`HIRP.B`, `HSVC.B`) interprets and dispatches to a specific routine. This involves a complex message queue and task scheduler.
- **FPS-3000 Model:** The 21 panel commands are **16-bit words** sent directly to the EU's Am29116. The EU PROM is a fixed, mask-programmed ROM. The dispatch must be extremely fast and simple—likely a jump table indexed by the command code.

**Evidence & Reasoning:**
- **FPS-100 `FUNC` Module:** The FPS-100 AP-side supervisor has a `FUNC` module (`FUNC.B`, 85 microinstructions). This is a simple function dispatcher. It likely reads a function code from a register and jumps to a handler. The 21 panel commands are a perfect fit for this model: a small, fixed set of operations that the EU can execute directly.
- **Am29116 as a Sequencer:** The Am29116 is not a general-purpose CPU; it's a microprogrammed sequencer. Its "program" is the EU PROM. The 21 commands are likely the **entry points** into this PROM. The SBC writes a command to a register, the Am29116 reads it, and uses it as an index into a jump table in its own PROM.
- **Contrast with HIRP:** HIRP requires a full OS (the AP-side supervisor) to manage message queues and task states. The FPS-3000's EU has no such OS. It's a bare-metal sequencer. The panel commands are its "system calls."
- **Confidence Level:** **HIGH**. The simplicity and speed of the Am29116 dispatch, combined with the existence of the `FUNC` module in the FPS-100, strongly supports this model.

### 3. TCBRDHC / TCBIO1I / TCBXP*I — Parallel to FPS-100 KERNEL?

**Inference:** The RMS68K task structure is **fundamentally different** from the FPS-100's AP-side KERNEL. The FPS-3000 tasks are **host-side control tasks**, while the FPS-100's KERNEL is an **AP-side supervisor**.

- **FPS-100 Model:** The AP-side supervisor (`KERNEL.B`, `MINI.B`) runs *on the AP-120B itself*. It manages tasks that run *on the AP*. It has a ready queue, context switching, and interrupt handling for the AP's own hardware.
- **FPS-3000 Model:** The RMS68K tasks run *on the SBC*, which is a separate, general-purpose CPU. They manage the XP-32 ACs as peripherals. They are not "tasks" in the AP's sense; they are **device drivers and protocol handlers** running under a real-time OS.

**Evidence & Reasoning:**
- **Hardware Separation:** In the FPS-3000, the SBC (68K) and the XP-32 ACs (Am29116 + FP pipelines) are separate boards on different buses. The FPS-100's AP-120B was a single unit. The SBC's role is to be the "host" for the XP-32.
- **Task Roles:**
    - `TCBRDHC`: The master control task. Analogous to the host-side `DAPEX.MAC` library, not the AP-side KERNEL.
    - `TCBIO1I`: Host I/O handler. Analogous to the host-side `APIN`/`APOUT` routines in `DAPEX.MAC`.
    - `TCBXP*I`: XP-32 channel drivers. These are new, specific to the FPS-3000's multi-AC architecture.
- **Confidence Level:** **HIGH**. The hardware architecture dictates this separation. The FPS-3000's SBC is a "host processor" for the XP-32, not an "AP processor" itself.

### 4. Microcode Upload Path — S-Record vs. LODINP

**Inference:** The S-record upload path is a **direct descendant** of the FPS-100's `LODINP` path, adapted for the new hardware (SBC instead of PDP-11, XLTR instead of direct DMA).

- **FPS-100 Model:** The host (PDP-11) runs `LED100` (the link editor). `LED100` reads a load module (`.APO` or `.B` file) and uses the `LODINP` routine (in `SIM100.FTN`) to write the microcode directly to the AP-120B's Program Store (PS) via programmed I/O or DMA.
- **FPS-3000 Model:** The host sends S-records to the SBC. The SBC's `TCBRDHC` task parses them and writes the data to a staging buffer in its own RAM. Then, it uses the XLTR to DMA the buffer to the XP-32's WCS.

**Evidence & Reasoning:**
- **Staging Buffer:** The 64 KB staging buffer at `0x10000–0x1FFFF` is a perfect match for one bank of the XP-32's WCS (4K × 128-bit = 64 KB). This is a clear inheritance: the FPS-100 loaded code directly into the PS; the FPS-3000 loads it into a buffer first, then transfers it.
- **S-Record Format:** S-records are a standard format for transferring binary data. The FPS-100 used a proprietary `.APO` format. The switch to S-records is a modernization, but the underlying concept (a text-based, line-oriented format for loading memory) is the same.
- **`LODINP` Analogy:** The `LODINP` routine in `SIM100.FTN` reads a file, parses the address and data, and writes it to the PS. The SBC's S-record handler does the same thing, but writes to its own RAM instead of the PS. The final step (DMA to the WCS) is the new part, handled by the XLTR.
- **Confidence Level:** **HIGH**. The functional equivalence is clear. The staging buffer is the smoking gun.

### 5. Two-Mode Architecture — FPS-3000 Analog?

**Inference:** The FPS-3000 **does not** have a direct analog to the FPS-100's AP120 vs. Super-100/Mini-100 modes. The FPS-3000's architecture is a **single, fixed mode** where the SBC is the master and the XP-32 ACs are slaves.

- **FPS-100 Model:** The two modes represent a fundamental architectural choice: is the AP a dumb slave (AP120 mode) or a smart co-processor (Super-100 mode)? This was a firmware/software switch.
- **FPS-3000 Model:** The SBC is always the master. The XP-32 ACs have no independent OS. They are always controlled by the SBC via the panel commands. There is no "Super-100" mode for the XP-32.

**Evidence & Reasoning:**
- **Fixed EU PROM:** The EU PROM is mask-programmed. It cannot be changed. This means the behavior of the XP-32 ACs is fixed. They cannot be "booted" into a different mode.
- **No AP-side OS:** The FPS-3000's AP-side supervisor (the EU PROM) is a simple, fixed-function sequencer. It doesn't have a task scheduler, I/O queue, or RTC handler like the FPS-100's `KERNEL.B` and `MINI.B`. The complexity is all in the SBC's RMS68K tasks.
- **The 21 Panel Commands are the "Mode":** The set of 21 commands *is* the FPS-3000's "operating system" for the XP-32. They are the fixed set of operations the AC can perform. This is a much simpler, more rigid model than the FPS-100's flexible Super-100 mode.
- **Confidence Level:** **HIGH**. The hardware (fixed PROM) and the software (simple command set) are inconsistent with a dual-mode architecture.

### 6. EU PROM Structure — Estimate

**Inference:** The EU PROM is likely structured as a **small, fixed-function executive** with a **jump table for the 21 panel commands**, followed by **utility subroutines** for basic operations (DMA, register I/O, status read). It is **not** a general-purpose OS.

- **FPS-100 Comparison:** The FPS-100's AP-side supervisor (`KERNEL.B` + `MINI.B` + `SYSSVC.B` + `HSVC.B` + `HIRP.B`) totals about 1,200 microinstructions. This is a full OS.
- **FPS-3000 Estimate:** The EU PROM is 2K × 80-bit = 20 KB. This is a very small amount of code. It cannot contain a full OS.

**Reasoning & Structure Estimate:**
1.  **Initialization (≈100 µinst):** Power-on self-test, initialize internal registers, set up the interface to the AU and XLTR.
2.  **Main Loop (≈50 µinst):** Wait for a command from the SBC (via the XLTR). Read the command code.
3.  **Jump Table (≈50 µinst):** A 21-entry jump table. Each entry is a jump to the handler for that command.
4.  **Command Handlers (≈50-100 µinst each, total ≈1,500 µinst):** The bulk of the PROM. Each handler implements one of the 21 panel commands. For example:
    - `0x258` (SUBRC R24): Read a status register mapped to R24.
    - `0x260` (SUBRC R0): Initiate a DMA transfer.
    - `0x27D` (SUBRC R29): Reset the AC.
5.  **Utility Subroutines (≈300 µinst):** Common routines used by the handlers, such as:
    - `DMA_Read_From_SCM`
    - `DMA_Write_To_WCS`
    - `Read_AC_Status`
    - `Write_To_AC_Register`
6.  **Total:** ≈2,000 µinstructions. This fits comfortably in the 2K PROM.

**Confidence Level:** **MEDIUM**. This is a structural inference based on the size of the PROM and the complexity of the operations. The exact layout is speculative, but the overall structure (jump table + handlers + utilities) is highly likely.

### 7. Other Important Inferences

**Inference 1: The `SIM100.FTN` `SPLIT` routine is the key to understanding the XP-32's 128-bit microinstruction format.**

- **Why:** The `SPLIT` routine in `SIM100.FTN` decodes the AP-120B's 64-bit microinstruction into 24 named fields. The XP-32's 128-bit format is an evolution of this. By understanding the AP-120B's field layout (e.g., `SPSF`, `SPDF`, `FADDF`, `A1F`, `A2F`, `CONDF`, `DISPF`, etc.), we can make much more educated guesses about the XP-32's wider fields.
- **Action:** We should use the `SPLIT` routine as a template for creating a hypothetical `SPLIT_XP32` routine. We can then test this routine against the 11,469 AP-120B microinstructions to see if the field boundaries make sense when "stretched" to 128 bits.

**Inference 2: The FPS-3000's `TCBRDHC` task is the direct descendant of the FPS-100's `DAPEX.MAC` library, not the AP-side supervisor.**

- **Why:** `DAPEX.MAC` is the host-side library that manages the AP-120B lifecycle (assign, load, run, wait, get status). `TCBRDHC` does the same thing for the XP-32 ACs. Both are the "master control program" from the host's perspective. The FPS-100's AP-side supervisor (`KERNEL.B`, etc.) is a completely different beast—it's the OS that runs *on* the AP.
- **Action:** We should compare the function call sequence in `DAPEX.MAC` (e.g., `APASGN` → `APLD` → `SPLDGO` → `WTRUN`) to the command sequence in `TCBRDHC` (e.g., select channel → load microcode → set busy → start). The parallels will be strong.

**Inference 3: The FPS-3000's "panel command" interface is a hardware abstraction of the FPS-100's `APOUT`/`APIN` register I/O.**

- **Why:** In the FPS-100, the host reads and writes the AP's internal registers (FN, SWR, LITES, etc.) via `APOUT` and `APIN` subroutines. In the FPS-3000, the SBC sends a "panel command" to the EU, which then performs the register read/write internally. The panel command is a higher-level, more abstracted version of the raw register I/O.
- **Action:** We should map each of the 21 panel commands to a specific `APOUT`/`APIN` operation or sequence. For example, a "read status" command might be the equivalent of an `APIN` of the STATUS register. This mapping will help us understand what each command actually does.

**Inference 4: The FPS-3000's SBC ROM is a "personality module" that makes the generic RMS68K kernel into an FPS-3000-specific control processor.**

- **Why:** The RMS68K kernel is a generic RTOS. The FPS-3000-specific code (the tasks, the XLTR driver, the S-record parser, the panel command sequencer) is all in the application portion of the ROM (from `0xF04488` onwards). This is a classic embedded systems design pattern.
- **Action:** We should focus our reverse-engineering efforts on the application code, not the kernel. The kernel is well-understood. The magic is in the tasks and the data structures they use.

### GLM coop

Based on the new FPS-100 reference data, here are the key new inferences about the FPS-3000 68K SBC ROM that we couldn't make before:

---

### 1. **Panel Command Dispatch Mechanism (0x258-0x27D)**
**New inference**: The 21 panel commands are likely **literal Am29116 SUBRC instructions** executed by the EU, with RAM reads triggering MMIO side effects (Possibility 2).  
**Evidence from FPS-100**:  
- The AP-side supervisor (`HSVC.S`, `HIRP.S`) uses memory-mapped dispatch where specific RAM addresses correspond to service routines  
- The structured RAM address clustering (R24-R31 in Group A; R0, R9-R12, R14, R17, R22-R31 in Group B) matches FPS-100's overlay table format  
- **Reference**: `HSVC.B` (65 microinstructions) and `SYSSVC.B` (527 microinstructions) show how the FPS-100 maps host requests to AP-side handlers via memory addressing  

**Why this matters**: This confirms the "memory-mapped trigger" model is architecturally consistent across FPS systems, strengthening the hypothesis that FPS-3000 panel commands work similarly.

---

### 2. **Task Structure Parallelism**
**New inference**: The SBC's `TCBXP1I-4I` tasks are **host-side counterparts** to the FPS-100's AP-side task management, not direct equivalents.  
**Evidence from FPS-100**:  
- `KERNEL.S` (EXTASK module) runs AP-side task scheduling on the Am29116  
- `MINI.S` (318 μinstr) implements Mini-100 supervisor for multi-tasking  
- **Reference**: The FPS-100 has two modes (AP120 = host-controlled; Super-100 = AP-controlled) while FPS-3000 only has the latter equivalent  

**Why this matters**: Explains why FPS-3000 uses RMS68K tasks (TCBXP*I) instead of AP-side execution – it's a "Super-100 only" architecture where the SBC manages ACs via XLTR panel commands, not direct AP execution.

---

### 3. **Microcode Upload Path Evolution**
**New inference**: The 64KB staging buffer (`0x10000–0x1FFFF`) is **simpler than FPS-100's overlay system** due to architectural differences.  
**Evidence from FPS-100**:  
- `LODINP` in DAPEX.MAC handles compressed APLOAD format with 2:1 MD→PS transfer  
- `MOVER.S` implements overlay residency management via WRTLMN instructions  
- **Reference**: FPS-100 uses overlay tables (8-word entries) for PS residency while FPS-3000 uses direct bank addressing  

**Why this matters**: Confirms FPS-3000's AU WCS is directly addressable (no compression/overlay), making the 64KB staging buffer exactly one bank. This explains why S-record loading is simpler than FPS-100's LODINP path.

---

### 4. **EU PROM Content Estimate**
**New inference**: The EU PROM (2K × 80-bit = 20KB) likely contains **~2,000 Am29116 instructions** structured like FPS-100's AP-side supervisor.  
**Evidence from FPS-100**:  
- `KERNEL.B` (283 μinstr) + `MINI.B` (318 μinstr) + `SYSSVC.B` (527 μinstr) = ~1,129 μinstr for core AP OS  
- **Reference**: `HSVC.B` entry table maps host requests to handlers via direct memory references  
- **Inference**: FPS-3000 EU probably has:  
  - Panel command decoder (200-300 μinstr)  
  - AC task dispatcher (500-700 μinstr)  
  - SCM management (300-500 μinstr)  
  - Support routines (remainder)  

**Why this matters**: Provides concrete size expectations for EU PROM reverse-engineering.

---

### 5. **Two-Mode Architecture Absence**
**New inference**: FPS-3000 has **no "AP120 mode" equivalent** – only "Super-100 mode" (SBC-managed).  
**Evidence from FPS-100**:  
- `APASGN` in DAPEX.MAC forces AP120 mode via `SETSUP` QIO on LUN1  
- `APIN`/`APOUT` have special Super-100 mode handling for LITES register  
- **Reference**: FPS-100's two-LUN architecture (LUN=host-controlled, LUN1=AP-controlled) doesn't exist in FPS-3000  

**Why this matters**: Explains why FPS-3000's XLTR protocol is simpler – it's a "Super-100 only" system without host-direct AP control.

---

### 6. **Microcode Format Validation**
**New inference**: The consensus 128-bit XP-32 layout's first 103 bits are **strongly validated** by FPS-100's .APO libraries.  
**Evidence from FPS-100**:  
- 11,469 decoded microinstructions across 313 routines (BABLIB/SIGLIB/etc.)  
- **Reference**: Field definitions (SPAD/ADD/BRANCH/MULT/etc.) match FPS-100→FPS-164→XP-32 evolution  
- **Impact**: 80% of XP-32 fields (SPAD=23b, ADD=24b, etc.) now have ground-truth validation  

**Why this matters**: Reduces uncertainty about XP-32 microcode interpretation when uploading XPMLIB kernels.

---

### 7. **Panel Commands vs. FPS-100 QIO Functions**
**New inference**: 0x8004/0x8005 (REQUEST/CONTINUE-TRANSFER) are **XLTR-specific protocols**, not FPS-100 QIO equivalents.  
**Evidence from FPS-100**:  
- `RUNDMA` (QIO func 1) vs. XLTR's register-based DMA sequence  
- `SETMOD` (QIO func 5) vs. XLTR's Mode Reg 1/2/0 bits  
- **Reference**: DAPEX.MAC's QIO interface is fundamentally different from XLTR's command model  

**Why this matters**: Clarifies that FPS-3000's host interface is a new protocol, not a direct FPS-100 successor.

---

### Summary of Key Advances:
| Aspect | Pre-FPS-100 Knowledge | New Inference |
|--------|------------------------|---------------|
| Panel commands | Structured but purpose unknown | MMIO-triggered SUBRC instructions (FPS-100 HSVC model) |
| Task structure | RMS68K tasks exist | Host-side equivalents to AP-side supervisor tasks |
| Microcode upload | Staging buffer usage | Simpler than FPS-100 (no overlay/compression) |
| EU PROM | 2K×80-bit space | ~2K instructions structured like KERNEL.B+HSVC.B |
| Architecture modes | Unknown | FPS-3000 = Super-100 only (no AP120 mode) |
| Microcode format | 128-bit consensus | 103 bits validated by FPS-100 libraries |
| Host interface | 0x8004/0x8005 exist | XLTR-specific, not FPS-100 QIO equivalent |

These inferences significantly reduce architectural uncertainty and provide concrete reference points for reverse-engineering the EU PROM and microcode upload process.
</details>
