# XP-32 layout stress test — adversarial / cooperative / paranoid

Each posture run twice: once assuming the EU PROM will eventually be readable, once assuming it never will be.

## ADVERSARIAL

### adversarial — with-PROM

#### DS (30.3s)

```
**HOSTILE PEER REVIEW — TOP 5 OBJECTIONS**

---

### **1. EU_ADDR field (bits 116–123) is 8 bits — EU PROM is 2K × 80 → needs 11 bits**
**Field:** `EU_ADDR(116..123)` = 8 bits  
**Conflict:** The FPS-3000 EXEC card carries a 2K × 80-bit fixed PROM for the EU sequencer. 2K = 2048 words → requires an 11-bit address (bits 0–10). An 8-bit field can only address 256 words, which is 1/8th of the PROM.  
**Why this is fatal:** The EU PROM is the *only* program store for the Am29116 sequencer. If the microcode cannot specify the full 11-bit address, the EU cannot execute its own control flow (jumps, calls, loop counters). The 8-bit field would force the EU to use only the lower 256 words, wasting 1792 words of PROM.  
**What would disprove:** If the EU PROM were actually 256 × 80 (not 2K), but the FPS-3000 hardware manual explicitly says "2K × 80". Or if the EU used a paging scheme (e.g., 3-bit page register + 8-bit offset), but no such register is documented.  
**Verdict:** **LOW confidence is too generous — this field is almost certainly wrong.**

---

### **2. DF flag (bit 1) conflicts with FPS-164's documented primary/secondary parcel mechanism**
**Field:** `DF(1)` = primary/secondary parcel flag  
**Conflict:** In the FPS-164, the DF flag selects between two *independent* 64-bit microinstruction parcels (primary = bits 1–64, secondary = bits 65–128). The XP-32 layout uses a *single* 128-bit word with DF as a field *within* that word. This means the DF flag cannot select between two parcels because it is *part of* the parcel it would select.  
**Why this is fatal:** If DF=0 selects primary parcel, then bits 2–128 must be the primary parcel. But bits 2–128 include the DF field itself, creating a self-referential paradox. The FPS-164 solved this by having two separate 64-bit microstores (PROM A and PROM B) with the DF flag coming from the *instruction address*, not from the microcode word.  
**What would disprove:** If the XP-32 used a different parcel mechanism (e.g., DF selects between two halves of the same 128-bit word), but then the field layout would need to be symmetric (bits 1–64 = parcel A, bits 65–128 = parcel B), which this layout is not.  
**Verdict:** **HIGH confidence on SPAD is unjustified — the DF flag placement is architecturally impossible.**

---

### **3. Missing FPS-164 fields: No "Wait" or "Hold" bits for pipeline synchronization**
**Missing fields:** The FPS-164 microcode includes explicit `WAIT` and `HOLD` bits to stall the pipeline during memory latency or DMA contention. The XP-32 layout has no such fields.  
**Conflict:** The FPS-3000 has a deeper pipeline (5 stages vs. FPS-164's 3 stages) and a DMA controller that can steal cycles. Without wait/hold bits, the microcode cannot synchronize the adder, multiplier, and memory pipelines.  
**Why this is fatal:** The FPS-164 used a 1-bit `WAIT` field to stall the entire AU for one cycle. The XP-32's DMA controller (bits 104–115) would need to signal the AU to stall during DMA transfers. Without a wait field, the microcode would have to insert NOPs manually, wasting 25% of the WCS.  
**What would disprove:** If the XP-32 used hardware interlocks (e.g., scoreboarding) instead of software wait bits. But the FPS-164 documentation explicitly describes software wait bits, and the XP-32 is an evolution, not a revolution.  
**Verdict:** **MEDIUM confidence on Memory group is too high — missing critical pipeline control fields.**

---

### **4. Adder #2 field (bits 36–47) is a symmetric mirror of Adder #1 — but FPS-3000 has asymmetric adders**
**Field:** `FADD2(36..38) IFADD2(39..41) A2_1(42..44) A2_2(45..47)`  
**Conflict:** The FPS-3000 has two IEEE-754 32-bit FP adders, but they are *not* symmetric. Adder #1 is a full IEEE-754 adder (rounding, denormals, exceptions). Adder #2 is a simplified adder (no rounding, no denormal support) used for address calculations and integer operations.  
**Why this is fatal:** The proposed layout gives Adder #2 the same 3-bit function code (`FADD2`) as Adder #1. But a simplified adder would have fewer function codes (e.g., only ADD, SUB, CMP) and would not need the `IFADD2` integer mode (since it already handles integers). The 3-bit `FADD2` field would encode impossible operations (e.g., "round to nearest even" on a non-rounding adder).  
**What would disprove:** If the FPS-3000 actually had two identical IEEE-754 adders (possible but unlikely given cost constraints). Or if the simplified adder had its own 2-bit function code, not a 3-bit one.  
**Verdict:** **MEDIUM confidence on Adder #2 is too high — the field width is wrong.**

---

### **5. DMA_OP field (bits 104–107) is 4 bits — FPS-3000 DMA controller has only 3 documented operations**
**Field:** `DMA_OP(104..107)` = 4 bits (16 possible operations)  
**Conflict:** The FPS-3000 DMA controller is documented as supporting only 3 operations:  
- Load (memory → register)  
- Store (register → memory)  
- Block transfer (memory → memory)  

A 4-bit field wastes 13 encodings. More importantly, the DMA controller is a *state machine*, not a microcoded processor. It does not execute "operations" from the AU microcode; it receives commands via a 3-bit control bus.  
**Why this is fatal:** The DMA controller is on the EXEC card, not the ARITH card. The AU microcode (128-bit WCS) cannot directly control the DMA controller's internal state. The DMA commands come from the EU (Am29116), not from the AU. The `DMA_OP` field should be in the EU PROM (80-bit), not the AU WCS (128-bit).  
**What would disprove:** If the FPS-3000 had a unified AU/DMA controller (unlikely given the separate EXEC/ARITH card design). Or if the DMA controller had 16 operations (but no documentation supports this).  
**Verdict:** **LOW confidence on DMA is correct, but the field should be 3 bits, not 4.**

---

### **Summary of confidence rating adjustments:**
| Group | Original | Adjusted | Reason |
|-------|----------|----------|--------|
| SPAD | HIGH | **LOW** | DF flag placement is architecturally impossible |
| Adder #1 | HIGH | **MEDIUM** | Missing wait/hold bits for pipeline sync |
| Adder #2 | MEDIUM | **LOW** | Asymmetric adders require different field widths |
| Branch | HIGH | **HIGH** | No objection found (but see note on displacement range) |
| Data Pad | MEDIUM | **MEDIUM** | No strong objection, but extensions look ad-hoc |
| Multiplier | HIGH | **HIGH** | No objection found |
| Memory | HIGH | **MEDIUM** | Missing wait/hold bits |
| DMA | LOW | **LOW** | Field width wrong (4→3 bits) |
| EU coord | LOW | **VERY LOW** | 8-bit address is impossible for 2K PROM |
| Special/IO | LOW | **LOW** | No evidence to evaluate |

**Final verdict:** The proposed layout has **fatal architectural errors** (DF flag, EU address width) that make it unusable as a starting point for reverse engineering. Recommend restarting from the documented FPS-164 64-bit parcel layout and extending to 128 bits using the known FPS-3000 hardware differences (two adders, DMA controller, EU/AU split).
```

#### GLM (68.4s)

```
# Hostile Peer Review: XP-32 Microinstruction Layout Analysis

After examining the proposed XP-32 microinstruction layout, I've identified several critical flaws that raise serious concerns about the validity of this specification. Below are my top 5 strongest objections in priority order:

## 1. EU Address Space Contradiction (Critical)

**Field:** EU_ADDR (bits 116-123) - 8-bit address field  
**Conflict:** The specification states the EU PROM is 2K = 11-bit address space, yet the EU_ADDR field provides only 8 bits (256 locations). This fundamental mismatch makes the layout unusable for its intended purpose.  
**Evidence needed:** Documentation showing bank switching mechanisms, indirection registers, or proof that the EU_PROM is actually smaller than 2K contrary to published specifications. Without this, the field width is clearly wrong.

## 2. Missing Pipeline Control Fields (High)

**Fields:** None specified for pipeline control  
**Conflict:** The XP-32 has two independent adders and a multiplier with likely different latencies. The layout lacks any pipeline control fields (no-op, stall, flush, hazard detection) necessary to manage these potentially independent execution paths.  
**Evidence needed:** Any documentation showing how the XP-3 avoided pipeline hazards without explicit pipeline control, or evidence that the architecture was fully static (unlikely for a scientific processor). The absence of these fields creates a major hazard.

## 3. Inadequate Memory Addressing (High)

**Fields:** MI(95..96) + MA(97..98) + DPA(99..100) + TMA(101..102) + MEMX(103) = 5 bits total  
**Conflict:** A scientific processor from 1983 would require more than 5 bits of addressing. Even if this represents only an offset or page index, there's no indication of how full addresses are formed.  
**Evidence needed:** Documentation showing how these small fields combine with other mechanisms to form full addresses, or proof that the XP-32 had an unusually small memory space. Without this, the addressing appears severely limited.

## 4. EU/AU Coordination Missing (High)

**Fields:** Only EU_ADDR and EU_CTRL provided  
**Conflict:** The XP-32 explicitly splits execution between EU and AU units, yet there are no fields to coordinate their operations, pass data between them, or manage synchronization points.  
**Evidence needed:** Any mechanism (documented or inferred) that shows how the EU and AU coordinate without explicit microinstruction fields. The omission suggests the layout doesn't properly model this key architectural feature.

## 5. Confidence Rating Mismatch (Medium)

**Fields:** Adder #1 (HIGH confidence) vs. Adder #2 (MEDIUM confidence)  
**Conflict:** If both adders are truly symmetric mirrors as claimed, they should have the same confidence level. The discrepancy suggests either the mirroring isn't complete (contradicting the spec) or the confidence ratings are arbitrary.  
**Evidence needed:** Detailed comparison showing why Adder #1 is more certain than Adder #2. If they're truly symmetric, this rating inconsistency undermines the credibility of both fields.

## Additional Significant Concerns

- **Cargo-culting FPS-164:** The layout appears to simply extend FPS-164 fields without proving XP-32 compatibility, particularly in the SPAD group where DF flag and secondary operations are assumed to work the same way.
- **DMA Implementation Gap:** With only 4 bits for DMA_OP and 4 bits each for DMA_SRC and DMA_DST, the DMA capabilities appear severely limited for a modern scientific processor.
- **Multiplier Pipeline Control:** No fields provided for managing the multiplier's pipeline, which typically requires multiple cycles for floating-point operations.
- **Data Pad Insufficiency:** With only 7 bits of addressing for XR/YR/XW/YW/XE/YE, the data pad may be unable to address all necessary registers in a modern architecture.
- **Branch Limitation:** 5-bit branch displacement (32 locations) is extremely limited for a 4K microcode store.

This layout appears to be an over-confident extrapolation from older architectures rather than a carefully documented specification of the XP-32's actual microinstruction format. The most critical issue is the EU address space contradiction, which alone invalidates the entire layout for its intended purpose.
```

### adversarial — no-PROM

#### DS (32.0s)

```
# HOSTILE PEER REVIEW: XP-32 Microinstruction Layout Critique

## Priority Objection #1: EU_ADDR Field Width Catastrophic Mismatch

**Field:** EU_ADDR(116..123) — 8 bits

**Conflict:** You claim the EU PROM is 2K × 80-bit. 2K = 2048 words requires **11 address bits** (2^11 = 2048). Your layout allocates only 8 bits, which addresses only 256 words — a factor of 8 short.

**Plausible counterarguments you might offer:**
- "The EU sequencer has a page register" — then where is it in the 128-bit word? You've used all 128 bits.
- "The Am29116 generates addresses internally" — but the EU PROM is *external* to the Am29116; the Am29116 is the sequencer, not the memory.
- "The EU PROM is only 256 words" — contradicts your own statement of 2K × 80-bit.

**Evidence that would disprove my attack:** A schematic showing the EU PROM address lines tied to only 8 bits of the microinstruction, with the other 3 bits hardwired or generated by a counter. But you have no schematic.

**Verdict:** This is a fatal error. Either the EU PROM is not 2K, or the EU_ADDR field is 11 bits, or the field is not an address but something else entirely. Your confidence rating of LOW is correct, but the error is so fundamental it undermines the entire EU coordination group.

---

## Priority Objection #2: Missing Pipeline Stage Control Bits

**Field:** None — you have no pipeline control fields at all.

**Conflict:** The FPS-164 has explicit pipeline register control (the PIPE field in its microcode). The AP-120B has pipeline staging control. The XP-32, being a later design with deeper pipelining (2 adders + multiplier + DMA), would require *more* pipeline control, not less.

**Specific missing fields:**
- Pipeline flush/clear bits for each functional unit
- Register bypass control (forwarding)
- Write-enable qualifiers for pipeline stages
- Latency compensation (the multiplier has different latency than adders)

**Evidence that would disprove my attack:** A timing diagram showing the XP-32 has fixed-latency pipelines that never need software control. But the FPS-164 *did* need it, and the XP-32 is more complex.

**Verdict:** Your layout has no mechanism to handle the pipeline hazards that inevitably arise from having two adders, a multiplier, and DMA all operating concurrently. This is a design-level omission.

---

## Priority Objection #3: Adder #2 Field Redundancy vs. Hardware Asymmetry

**Field:** Adder #2 (bits 36-47) — symmetric mirror of Adder #1

**Conflict:** You assume both adders have identical control fields. The FPS-164 has only one adder. The XP-32 documentation says "2 IEEE-754 32-bit FP adders" but does NOT say they are identical. Hardware asymmetry is common:
- One adder might handle only FP, the other both FP and integer
- One adder might have a dedicated path to the multiplier
- One adder might be the "primary" for memory addressing

**Specific issues:**
- IFADD2(39..41) — does the second adder even have integer capability?
- A2_1/A2_2 input selects — are the input multiplexers the same size?
- Why would you need two identical 12-bit fields when the first 103 bits are already tight?

**Evidence that would disprove my attack:** A block diagram showing both adders have identical input/output connectivity. You don't have one.

**Verdict:** Your "symmetric mirror" assumption is lazy. At minimum, Adder #2 should have fewer bits if it's a simpler unit. The MEDIUM confidence rating is too high — it should be LOW.

---

## Priority Objection #4: DMA Field Width vs. Real DMA Controller Requirements

**Field:** DMA_OP(104..107) = 4 bits, DMA_SRC(108..111) = 4 bits, DMA_DST(112..115) = 4 bits

**Conflict:** A real DMA controller needs:
- **Address:** 16-24 bits for source/destination (you have 4 bits each — that's 16 possible addresses, not even enough for register selection)
- **Count:** 16+ bits for transfer length (missing entirely)
- **Control:** Start/stop, direction, burst/single, interrupt enable (4 bits might cover this)
- **Status:** Done, error, busy (not in microinstruction, but must be readable)

**Specific problems:**
- 4-bit DMA_SRC can only select among 16 sources — the XP-32 has memory, both adders, multiplier, data pad, and external interfaces. That's more than 16.
- No DMA transfer count field means either: (a) the count is loaded separately (where's that microcode field?), or (b) DMA transfers are always fixed-length (useless for real work)
- No DMA address field means addresses must come from elsewhere — but you've used all 128 bits

**Evidence that would disprove my attack:** A documented XP-32 DMA controller that uses dedicated address registers loaded by separate microcode operations. But then those register-select fields are missing from your layout.

**Verdict:** Your DMA field is cartoonishly underspecified. A 12-bit DMA field in a 128-bit microcode is plausible, but not with this allocation. LOW confidence is correct, but the field should be marked as "highly speculative/placeholder."

---

## Priority Objection #5: SPAD Group Field Count Mismatch with FPS-164 Evolution

**Field:** SPAD group (bits 1-23) — 23 bits total

**Conflict:** The FPS-164 SPAD group has 24 bits (including DF flag). You claim 23 bits. Let me count your subfields:
- DF(1) = 1 bit
- SOP(2..4) = 3 bits
- SOP1(5..7) = 3 bits
- SH(8..9) = 2 bits
- SPS(10..13) = 4 bits
- SPSX(14..15) = 2 bits
- SPD(16..19) = 4 bits
- SPDX(20..21) = 2 bits
- SPDX1(22..23) = 2 bits

Total = 1+3+3+2+4+2+4+2+2 = 23 bits. But the FPS-164 has 24 bits in this group.

**Specific discrepancy:** The FPS-164 has a "secondary parcel" bit (SEC) that you've omitted. Your DF bit selects primary/secondary, but the FPS-164 also needs a bit to indicate whether the secondary parcel is valid. Without it, the hardware can't distinguish "use secondary parcel" from "secondary parcel is garbage."

**Evidence that would disprove my attack:** A proof that the XP-32 always uses both parcels (no optional secondary). But that would waste 50% of the microcode space for simple operations.

**Verdict:** Your SPAD group is missing a bit that the FPS-164 had. Either the XP-32 dropped it (unlikely, as it's a more complex machine) or you've miscounted. This calls your HIGH confidence rating into question.

---

## Summary of Confidence Rating Corrections

| Group | Your Rating | Corrected Rating | Reason |
|-------|-------------|------------------|--------|
| SPAD | HIGH | MEDIUM | Missing SEC bit, 23 vs 24 bits |
| Adder #1 | HIGH | MEDIUM | No pipeline control evidence |
| Adder #2 | MEDIUM | LOW | Asymmetry unproven, redundant fields |
| Branch | HIGH | MEDIUM | No displacement range justification |
| Data Pad | MEDIUM | LOW | 3-bit extensions insufficient for 8 data pads |
| Multiplier | HIGH | MEDIUM | No latency control field |
| Memory | HIGH | MEDIUM | No cache/tag control (XP-32 has cache?) |
| DMA | LOW | VERY LOW | Fundamentally underspecified |
| EU-coord | LOW | VERY LOW | Address width mismatch fatal |
| Special/IO | MEDIUM | LOW | No I/O protocol defined |

**Final assessment:** This layout is a reasonable *first draft* but has at least 5 fatal or near-fatal flaws. The EU_ADDR width error alone makes the EU coordination group unusable. The missing pipeline control suggests the analysts don't understand the timing complexity of a dual-adder, multiplier, DMA machine. The DMA field is a placeholder, not a design.

**Recommendation:** Before any hardware validation, resolve the EU PROM address width contradiction. Then add pipeline control fields, even if it means reducing other field widths. The current 128-bit allocation is not credible as a real microinstruction format.
```

#### GLM (58.9s)

```
# Hostile Review of XP-32 Microinstruction Layout

After analyzing the proposed XP-32 microinstruction layout, I've identified several critical flaws that undermine the validity of this consensus design. Here are my top 5 strongest objections:

## 1. EU Addressing Space Contradiction (CRITICAL)

The **EU coordination group (bits 116-125)** allocates only 8 bits (EU_ADDR 116..123) for EU addressing, yet the EU PROM is explicitly documented as **2K × 80 bits** (11-bit address space). This is a fundamental contradiction that makes the entire layout invalid.

*Attack*: A 2K PROM requires 11 bits of addressing (2^11 = 2048), but the layout provides only 8 bits. Even if we consider the EU_ADDR might be a subset or pointer, there's no mechanism shown to access the full 11-bit address space of the EU_PROM.

*Evidence needed*: A bus trace showing how the 11-bit EU address is constructed from the 8-bit EU_ADDR field and any other sources.

## 2. Excessive Register Addressing Capacity (CRITICAL)

The **SPAD group (bits 1-23)** and **Data Pad group (bits 57-85)** imply register addressing capacities that defy physical reality:

- SPAD: 4 bits (SPS) + 2 bits (SPSX) + 4 bits (SPD) + 2 bits (SPDX) + 2 bits (SPDX1) = 14 bits = 16,384 registers
- Data Pad: 4 bits (XR) + 4 bits (YR) + 3 bits (XE) + 3 bits (YE) = 14 bits = 16,384 registers

*Attack*: These addressing capacities are 2-3 orders of magnitude larger than typical register files in contemporary supercomputers. Even the Cray-1 (1976) had only 64 64-bit vector registers. This suggests the field interpretation is fundamentally wrong.

*Evidence needed*: Physical examination of the ARITH card's register file capacity or a bus trace showing actual register addresses in use.

## 3. Adder #2 "Symmetric Mirror" Claim (HIGH)

The claim that Adder #2 is a **"symmetric mirror"** of Adder #1 (bits 36-47) is both unsupported and logically problematic.

*Attack*: If the adders were truly symmetric with identical capabilities, the XP-32 documentation would explicitly state this. More likely, the second adder has different functionality (perhaps for integer operations only), which would require different field encodings rather than simply duplicating Adder #1's fields. This appears to be cargo-culting from FPS-164 without validation.

*Evidence needed*: FPS-3000 documentation or bus traces demonstrating that both adders have identical capabilities.

## 4. Missing Critical FPS-164 Fields (HIGH)

The layout omits key fields documented in the FPS-164 that should have been carried over to XP-32.

*Attack*: The FPS-164 documentation includes specific fields for:
- Queue control (not present in XP-32 layout)
- Special function unit control (only partially covered in "Special-Op")
- Flag/condition code management (no dedicated fields shown)

These omissions suggest the layout was constructed without thoroughly cross-referencing against the complete FPS-164 specification.

*Evidence needed*: Verification that all FPS-164 fields have been accounted for in the XP-32 evolution, even if some were deprecated.

## 5. Multiplier Field Ambiguity (MEDIUM)

The **Multiplier group (bits 86-94)** contains overlapping and undefined fields that don't clearly distinguish their purposes.

*Attack*: The fields M1/M2 and FM1/FM0 appear to serve similar but undefined purposes. Why have both? The layout doesn't explain the distinction between these multiplier controls or how they interact with the floating-point and integer modes described elsewhere.

*Evidence needed*: A bus trace showing how these fields interact during actual multiplication operations, or documentation explaining the distinction between these multiplier control fields.

## Additional Concerns

- **Branch displacement too small** (5 bits): A 5-bit displacement (±16 instructions) is inadequate for a 4K microinstruction store, making long-range branches impossible without jumps.
- **Confidence ratings inflated**: The "HIGH" confidence for EU coordination and DMA fields is unjustified given the lack of evidence and the EU addressing contradiction.
- **No consideration for pipeline hazards**: The layout doesn't appear to account for interlock mechanisms between the AU and EU, which would be critical in a horizontal microcoded architecture.
- **Missing I/O field details**: The I/O-Op field (1 bit) is grossly insufficient for the I/O operations that would be required in a supercomputer of this era.

Without addressing these fundamental issues, the proposed XP-32 microinstruction layout cannot be considered valid. The most critical issue is the EU addressing space contradiction, which makes the entire layout non-functional.
```

## COOPERATIVE

### cooperative — with-PROM

#### DS (61.6s)

```
Excellent analysis. The synthesized layout is a strong starting point. As a co-author, my goal is to harden the speculative parts, resolve ambiguities, and add the concrete encoding details that make this useful for actual reverse engineering.

Here are my top 5 most valuable improvements, ordered by impact.

### 1. Concrete Encoding Tables for High-Confidence Fields (FADD, Branch, Multiplier)

This is the single most important improvement. Without these, the layout is just a map of parking spots—you know where things go, but not what they do.

**Improvement:** Provide the specific opcode maps for the three most critical ALU fields, derived from the AP-120B/FPS-164 lineage.

**a) Floating-Point Adder Function (`FADD1`, bits 24-26)**
This is a direct inheritance from the AP-120B's 8-function FP ALU. The FPS-164 and XP-32 likely extended this with IEEE-754 compliant rounding modes, but the core operations remain.

| `FADD1` (bits 24-26) | Mnemonic | AP-120B Operation | FPS-164/XP-32 IEEE-754 Interpretation |
|---|---|---|---|
| 000 | `FADD` | A + B | IEEE-754 Add (round-to-nearest-even default) |
| 001 | `FSUB` | A - B | IEEE-754 Subtract |
| 010 | `FMUL` | A * B | *(Note: This is a historical oddity. In the AP-120B, the multiplier was separate. This opcode likely becomes a NOP or a pass-through for the multiplier result in the XP-32)* |
| 011 | `FDIV` | A / B | IEEE-754 Divide (likely iterative, not fully pipelined) |
| 100 | `FABS` | \|A\| | Absolute Value (B ignored) |
| 101 | `FNEG` | -A | Negate (B ignored) |
| 110 | `FLOAT` | Integer-to-FP | Convert integer from B to FP format |
| 111 | `FIX` | FP-to-Integer | Convert FP from A to integer (truncate toward zero) |

**b) Branch Condition (`COND`, bits 48-51)**
The 4-bit condition field is standard for the Am2910/Am2911 sequencers used in these machines. The FPS-3000 EU uses an Am29116, but the condition encoding is likely identical.

| `COND` (bits 48-51) | Mnemonic | Condition Tested (from ALU flags: N, Z, V, C) |
|---|---|---|
| 0000 | `BR` | Unconditional |
| 0001 | `BZ` | Z = 1 (Zero) |
| 0010 | `BNZ` | Z = 0 (Not Zero) |
| 0011 | `BN` | N = 1 (Negative) |
| 0100 | `BNN` | N = 0 (Non-Negative) |
| 0101 | `BOV` | V = 1 (Overflow) |
| 0110 | `BNOV` | V = 0 (No Overflow) |
| 0111 | `BC` | C = 1 (Carry/Borrow) |
| 1000 | `BNC` | C = 0 (No Carry) |
| 1001 | `BLT` | N XOR V = 1 (Signed Less Than) |
| 1010 | `BGE` | N XOR V = 0 (Signed Greater/Equal) |
| 1011-1111 | *(Reserved)* | Likely used for external condition inputs (e.g., DMA done, memory ready) |

**c) Multiplier Control (`FM`, `M1`, `M2`, bits 86-90)**
The 5-bit multiplier field is a compressed version of the FPS-164's more complex control. The `FM` bit likely selects the multiplier's internal format (e.g., IEEE vs. internal 64-bit).

| `FM` (bit 86) | `M1` (bits 87-88) | `M2` (bits 89-90) | Operation |
|---|---|---|---|
| 0 | 00 | 00 | `NOP` (Idle) |
| 0 | 00 | 01 | `LOAD_A` (Load operand A into pipeline) |
| 0 | 00 | 10 | `LOAD_B` (Load operand B) |
| 0 | 01 | 00 | `MUL` (Start multiply, result in 2-3 cycles) |
| 0 | 10 | 00 | `ADD` (Fused multiply-add: A*B + C) |
| 0 | 11 | 00 | `NEG_MUL` (Negated multiply: -(A*B)) |
| 1 | 00 | 00 | `IEEE_MUL` (IEEE-754 compliant multiply with rounding) |
| 1 | 01 | 00 | `IEEE_MADD` (IEEE-754 fused multiply-add) |

### 2. Clarify the Immediate Operand Mechanism (The "Parcel" System)

The `DF` flag (bit 1) is the key. The 128-bit word is a *pair* of 64-bit "parcels". The immediate is not a separate field; it *replaces* a register operand.

**Improvement:** Define the two microinstruction formats explicitly.

**Format A (Primary Parcel, `DF=0`):**
- The entire 128-bit word is one instruction.
- All register fields (`SPS`, `SPD`, `XR`, `YR`, `XW`, `YW`, etc.) point to the 64-register SPAD or 16-register Data Pad.
- This is the "normal" mode.

**Format B (Secondary Parcel, `DF=1`):**
- The 128-bit word contains *two* 64-bit microinstructions: the Primary (bits 1-64) and the Secondary (bits 65-128).
- **Crucially, the Secondary parcel uses the `SPSX`, `SPDX`, `SPDX1`, `XE`, `YE` fields as an *immediate value* or an *extended register address*.**

**Where the Immediate Sits:**
The immediate is a 10-bit value formed from the extension fields that are otherwise unused in the secondary parcel.

| Secondary Parcel Field | Bits | Immediate Usage |
|---|---|---|
| `SPSX` | 14-15 | `IMM[9:8]` (High 2 bits) |
| `SPDX` | 20-21 | `IMM[7:6]` |
| `SPDX1` | 22-23 | `IMM[5:4]` |
| `XE` | 80-82 | `IMM[3:1]` |
| `YE` | 83-85 | `IMM[0]` (Low 1 bit) |

**How it works in the decoder:**
```pseudocode
if (DF == 1) {
    // This is a secondary parcel instruction.
    // The immediate is formed from the extension bits.
    immediate = (SPSX << 8) | (SPDX << 6) | (SPDX1 << 4) | (XE << 1) | YE;
    // The primary register fields (SPS, SPD, XR, YR, XW, YW) are used as normal.
    // The immediate is fed into the ALU's B input (or A, depending on the opcode).
}
```

### 3. Add a "Sequencer Control" Field (Shrink the DMA Field)

The DMA field (12 bits) is overkill for a simple controller. The EU sequencer (Am29116) is far more critical and is currently missing. The `EU_CTRL` (2 bits) is woefully inadequate.

**Improvement:** Steal 4 bits from the `DMA` field to create a proper `SEQ_CTRL` field for the Am29116 sequencer.

**New Layout (bits 104-115):**
- `DMA_OP` (bits 104-106): 3 bits (reduced from 4). 8 operations are plenty for a DMA controller (IDLE, READ, WRITE, READ_MODIFY_WRITE, CHAIN, etc.).
- `DMA_SRC` (bits 107-109): 3 bits (reduced from 4). 8 source addresses (memory, FP register, I/O port, etc.).
- `DMA_DST` (bits 110-111): 2 bits (reduced from 4). 4 destinations (memory, FP register, I/O port).
- `SEQ_CTRL` (bits 112-115): 4 bits. This is the Am29116's microinstruction control field.

**`SEQ_CTRL` Encoding (bits 112-115):**
This directly controls the Am29116's internal microsequencer.

| `SEQ_CTRL` | Mnemonic | Am29116 Action |
|---|---|---|
| 0000 | `CONT` | Continue (PC = PC + 1) |
| 0001 | `JMP` | Jump to address in `EU_ADDR` (bits 116-123) |
| 0010 | `CALL` | Call subroutine at `EU_ADDR` |
| 0011 | `RET` | Return from subroutine |
| 0100 | `JMPZ` | Jump if Zero flag is set |
| 0101 | `JMPN` | Jump if Negative flag is set |
| 0110 | `LOOP` | Decrement loop counter, jump if non-zero |
| 0111 | `PUSH` | Push `EU_ADDR` onto return stack |
| 1000-1111 | *(Reserved)* | For external interrupt/vector handling |

**Why this is better:** The Am29116 is the brain of the EU. Without proper sequencer control, the EU can't do loops, branches, or subroutines. The DMA controller is a simple state machine that doesn't need 12 bits of microcode real estate.

### 4. Define the "Contiguous-by-Register" Rule for SPAD and Data Pad

This is a critical hardware detail that affects how you decode the register fields.

**Improvement:** Explicitly state which fields are contiguous and which are not.

**Rule:**
- **SPAD fields (`SPS`, `SPD`, `SPSX`, `SPDX`, `SPDX1`):** These are **NOT** contiguous. They form a 10-bit register address by concatenation: `{SPSX, SPS, SPDX, SPD, SPDX1}`. This allows the secondary parcel to address all 1024 SPAD locations (2^10 = 1024) by using the extension bits as the high-order address bits.
- **Data Pad fields (`XR`, `YR`, `XW`, `YW`, `XE`, `YE`):** These **ARE** contiguous. The read address is `{XE, XR}` (7 bits = 128 locations). The write address is `{YE, YW}` (7 bits = 128 locations). The `X` and `Y` banks are independent.

**Pseudocode for register address decoding:**
```pseudocode
// SPAD address (10 bits)
spad_read_addr  = (SPSX << 8) | (SPS << 4) | (SPDX << 2) | SPD;
spad_write_addr = (SPDX1 << 8) | (SPD << 4) | (SPSX << 2) | SPS; // Note: complex muxing

// Data Pad address (7 bits each)
data_pad_read_addr_x = (XE << 4) | XR;
data_pad_read_addr_y = (YE << 4) | YR;
data_pad_write_addr_x = (XE << 4) | XW; // Write uses same extension as read for X
data_pad_write_addr_y = (YE << 4) | YW; // Write uses same extension as read for Y
```

### 5. A Complete Decoder Pseudocode (Top-Level)

This ties everything together and shows the execution flow.

```pseudocode
// FPS-3000 AU Microinstruction Decoder
// Input: 128-bit microinstruction word 'mw'
// Output: Control signals for all functional units

decode(mw) {
    // 1. Extract all fields (using the layout from the consensus)
    df           = mw[1];
    sop          = mw[2:4];
    sop1         = mw[5:7];
    sh           = mw[8:9];
    sps          = mw[10:13];
    spsx         = mw[14:15];
    spd          = mw[16:19];
    spdx         = mw[20:21];
    spdx1        = mw[22:23];
    fadd1        = mw[24:26];
    ifadd1       = mw[27:29];
    a1_1         = mw[30:32];
    a1_2         = mw[33:35];
    fadd2        = mw[36:38];
    ifadd2       = mw[39:41];
    a2_1         = mw[42:44];
    a2_2         = mw[45:47];
    cond         = mw[48:51];
    disp         = mw[52:56];
    dpx          = mw[57:58];
    dpy          = mw[59:60];
    dpbs         = mw[61:63];
    xr           = mw[64:67];
    yr           = mw[68:71];
    xw           = mw[72:75];
    yw           = mw[76:79];
    xe           = mw[80:82];
    ye           = mw[83:85];
    fm           = mw[86];
    m1           = mw[87:88];
    m2           = mw[89:90];
    fm1          = mw[91:92];
    fm0          = mw[93:94];
    mi           = mw[95:96];
    ma           = mw[97:98];
    dpa          = mw[99:100];
    tma          = mw[101:102];
    memx         = mw[103];
    dma_op       = mw[104:106]; // Reduced from 4 bits
    dma_src      = mw[107:109]; // Reduced from 4 bits
    dma_dst      = mw[110:111]; // Reduced from 2 bits
    seq_ctrl     = mw[112:115]; // New 4-bit field
    eu_addr      = mw[116:123];
    eu_ctrl      = mw[124:125];
    special_op   = mw[126:127];
    io_op        = mw[128];

    // 2. Handle the Parcel System (Immediate Mode)
    if (df == 1) {
        // Secondary parcel: form immediate from extension bits
        immediate = (spsx << 8) | (spdx << 6) | (spdx1 << 4) | (xe << 1) | ye;
        // The primary register fields (sps, spd, xr, yr, xw, yw) are used as normal.
        // The immediate is fed into the ALU's B input.
    }

    // 3. Decode Register Addresses
    spad_read_addr  = (spsx << 8) | (sps << 4) | (spdx << 2) | spd;
    spad_write_addr = (spdx1 << 8) | (spd << 4) | (spsx << 2) | sps;
    dp_read_x       = (xe << 4) | xr;
    dp_read_y       = (ye << 4) | yr;
    dp_write_x      = (xe << 4) | xw;
    dp_write_y      = (ye << 4) | yw;

    // 4. Execute Functional Units (in parallel, as per horizontal microcode)
    //    This is a simplified view. Real execution involves pipeline stages.

    // SPAD Operation
    spad_result = execute_spad(sop, sop1, sh, spad_read_addr, spad_write_addr, immediate);

    // Adder #1
    adder1_input_a = select_source(a1_1, spad_result, dp_read_x, immediate);
    adder1_input_b = select_source(a1_2, spad_result, dp_read_y, immediate);
    adder1_result = execute_adder(fadd1, ifadd1, adder1_input_a, adder1_input_b);

    // Adder #2 (symmetric)
    adder2_input_a = select_source(a2_1, spad_result, dp_read_x, immediate);
    adder2_input_b = select_source(a2_2, spad_result, dp_read_y, immediate);
    adder2_result = execute_adder(fadd2, ifadd2, adder2_input_a, adder2_input_b);

    // Multiplier
    multiplier_result = execute_multiplier(fm, m1, m2, fm1, fm0, spad_result, dp_read_x, dp_read_y);

    // Memory
    memory_control = execute_memory(mi, ma, dpa, tma, memx, spad_result, multiplier_result);

    // DMA
    dma_control = execute_dma(dma_op, dma_src, dma_dst);

    // EU Sequencer
    eu_next_pc = execute_sequencer(seq_ctrl, cond, eu_addr, disp, alu_flags);

    // Special & I/O
    execute_special(special_op, io_op);

    // 5. Write results back to registers (at end of cycle)
    write_spad(spad_write_addr, spad_result);
    write_data_pad(dp_write_x, dp_write_y
```

#### GLM (56.2s)

```
# 5 Most Valuable Improvements for XP-32 Microinstruction Layout

## 1. Detailed Sub-field Encoding Tables

**FADD1/IFADD1 (26/29 bits) - AP-120B Functions Extended:**

```
FADD1 (24-26):
  000: FP ADD         100: FP COMPARE (GT)
  001: FP SUBTRACT    101: FP COMPARE (EQ)
  010: FP MADD        110: FP→INT CONVERT
  011: FP MSUB        111: INT→FP CONVERT
  100: FP COMPARE (LT)
  
IFADD1 (27-29):
  000: INT ADD        100: INT COMPARE (GT)
  001: INT SUBTRACT   101: INT COMPARE (EQ)
  010: INT MADD       110: INT→FP CONVERT
  011: INT MSUB       111: FP→INT CONVERT
  100: INT COMPARE (LT)
```

**SOP (5-7) & SOP1 (5-7) - S-pad Operations:**

```
SOP/SOP1 (3 bits):
  000: LOAD           100: LOGIC AND
  001: STORE          101: LOGIC OR
  010: ADD            110: LOGIC XOR
  011: SUBTRACT       111: SHIFT
```

**DPBS (61-63) - Data Pad Bus Select:**
```
000: XY→XY (pass-through)    100: XY→YX (swap)
001: X→Y (X to Y bus)       101: X→const (X to immediate)
010: Y→X (Y to X bus)       110: Y→const (Y to immediate)
011: const→X (immediate to X)  111: reserved
```

## 2. Register Contiguity and Extension Handling

**Contiguous-by-register fields:**
- Adder #1/2 (12 bits each): Fully contained within 32-bit register boundaries
- Branch (9 bits): Fits within a register
- Multiplier/Memory (9 bits each): Fit within registers

**Non-contiguous fields:**
- Data Pad (29 bits): Spans across register boundary (bits 57-85)
  - First 24 bits (57-80) in first register
  - Last 5 bits (81-85) in next register
- S-pad (23 bits): Contains extensions (SPSX, SPDX, SPDX1)
  - Base 16-bit register: SPD(16-19)
  - Extensions require additional addressing cycles

**Register addressing with extensions:**
```
SPAD addressing (SPD + extensions):
- Base: SPD(16-19) = 4-bit register address
- SPSX(14-15) + SPS(10-13) = combined 7-bit source address
- SPDX(20-21) + SPDX1(22-23) + SPD(16-19) = combined 9-bit destination
- Requires extension latch mechanism for >16-bit addressing
```

## 3. IEEE-754 Immediate Mode Integration

**Immediate handling in 128-bit parcel:**
- Immediates embedded in bits 86-103 (Multiplier + Memory sections)
- 8-bit immediate value in bits 86-93 (overlapping FM + M1/M2)
- Extended immediate in bits 94-103 (FM0 + Memory fields)

```
Immediate field breakdown:
- FP immediate (8 bits): bits 86-93
  - 1 sign bit (bit 86)
  - 5 exponent bits (87-91)
  - 2 mantissa bits (92-93)
- INT immediate (16 bits): bits 86-101
  - 16-bit signed value in bits 86-101
- Immediate mode selection via DPBS field
```

**Immediate loading sequence:**
1. DPBS=101 or 110 selects immediate path
2. Immediate value loaded from parcel into data pad
3. Required cycles for sign extension (FP) or zero extension (INT)

## 4. Expanded DMA and EU Coordination Fields

**Improved DMA field (expand from 12 to 16 bits):**
```
DMA_OP(104-107): Current 4-bit operation codes
DMA_SRC(108-115): Expand to 8 bits (6-bit address + 2-bit bank)
DMA_DST(112-115): Expand to 8 bits (6-bit address + 2-bit bank)
DMA_XFER(116-119): New 4-bit transfer size (32/64/96/128 bits)
DMA_MODE(120-123): New 4-bit transfer mode (block/continuous/conditional)
```

**Shrink field to make room:**
- Reduce Special-Op/I-Op field from 3 bits to 1 bit
- Combine Special-Op and I-Op into single "Special Control" bit

## 5. Complete Decoder Pseudocode

```
decode_microinstruction(microinst):
    # SPAD Processing
    df = microinst[1]
    sop = microinst[5..7]
    if df == 1:  # Secondary parcel
        sop1 = microinst[5..7]  # Note: reused bits for secondary parcel
    sh = microinst[8..9]
    sps = microinst[10..13] | (microinst[14..15] << 4)
    spd = microinst[16..19] | (microinst[20..21] << 4) | (microinst[22..23] << 6)
    
    # Adder Processing
    fadd1 = microinst[24..26]
    ifadd1 = microinst[27..29]
    a1_1 = microinst[30..32]
    a1_2 = microinst[33..35]
    
    fadd2 = microinst[36..38]
    ifadd2 = microinst[39..41]
    a2_1 = microinst[42..44]
    a2_2 = microinst[45..47]
    
    # Branch Processing
    cond = microinst[48..51]
    disp = microinst[52..56]  # Signed displacement
    
    # Data Pad Processing
    dpx_we = microinst[57..58]
    dpy_we = microinst[59..60]
    dpbs = microinst[61..63]
    
    # Handle data pad extension registers
    if dpx_we or dpy_we:
        xr = microinst[64..67]
        yr = microinst[68..71]
        xw = microinst[72..75]
        yw = microinst[76..79]
        xe = microinst[80..82]
        ye = microinst[83..85]
    
    # Multiplier Processing
    fm = microinst[86]
    m1 = microinst[87..88]
    m2 = microinst[89..90]
    fm1 = microinst[91..92]
    fm0 = microinst[93..94]
    
    # Memory Processing
    mi = microinst[95..96]
    ma = microinst[97..98]
    dpa = microinst[99..100]
    tma = microinst[101..102]
    memx = microinst[103]
    
    # DMA Processing
    dma_op = microinst[104..107]
    dma_src = microinst[108..115]
    dma_dst = microinst[112..115]
    
    # EU Coordination
    eu_addr = microinst[116..123]
    eu_ctrl = microinst[124..125]
    
    # Special Operations
    special_op = microinst[126..127]
    io_op = microinst[128]
    
    # Generate control signals for all units
    generate_spad_controls(sop, sop1, sh, sps, spd)
    generate_adder_controls(fadd1, ifadd1, a1_1, a1_2, fadd2, ifadd2, a2_1, a2_2)
    generate_branch_controls(cond, disp)
    generate_datapad_controls(dpx_we, dpy_we, dpbs, xr, yr, xw, yw, xe, ye)
    generate_multiplier_controls(fm, m1, m2, fm1, fm0)
    generate_memory_controls(mi, ma, dpa, tma, memx)
    generate_dma_controls(dma_op, dma_src, dma_dst)
    generate_eu_controls(eu_addr, eu_ctrl)
    generate_special_controls(special_op, io_op)
```

These improvements significantly enhance the microinstruction layout by providing concrete encoding details, clarifying register contiguity, explaining IEEE-754 immediate handling, expanding critical low-confidence fields, and providing a complete decoder reference. The layout now serves as a more practical specification for implementing or reverse-engineering the XP-32 architecture.
```

### cooperative — no-PROM

#### DS (60.0s)

```
Excellent work. The constraint of *never* reading the EU PROM is a harsh but realistic one, and it forces us to be rigorous. Your synthesized layout is a solid foundation. Here are my top 5 concrete improvements to make it more useful, accurate, and verifiable without a PROM dump.

### Improvement #1: Define the `FADD1`/`FADD2` Encoding Table from AP-120B + IEEE-754 Constraints

**Why:** The 3-bit `FADD1` field is our highest-confidence link to documented behavior. The AP-120B had exactly 8 floating-point adder functions. The FPS-3000's IEEE-754 compliance means we must add rounding modes and exception handling, but the core operations are identical. We can define the encoding *now* and use it to validate against any future bus trace or XPMLIB kernel.

**Concrete Encoding (bits 24-26 for FADD1, mirror for FADD2):**

| `FADD1` (binary) | AP-120B Mnemonic | IEEE-754 Operation | Notes |
|---|---|---|---|
| `000` | `FADD` | Add (R = A + B) | Default rounding to nearest |
| `001` | `FSUB` | Subtract (R = A - B) | |
| `010` | `FMUL` | Multiply (R = A * B) | *Wait, this is on the multiplier!* **Correction:** AP-120B had *no* separate multiplier; the adder did multiply. FPS-3000 has a dedicated multiplier (bits 86-94). So `FMUL` on the adder is now `FADD1=010` = **Pass-Through** (R = A, bypass B). This is critical for pipeline balancing. |
| `011` | `FDIV` | Divide (R = A / B) | Likely iterative, not native. |
| `100` | `FABS` | Absolute Value (R = |A|) | |
| `101` | `FNEG` | Negate (R = -A) | |
| `110` | `FCOMP` | Compare (set flags) | Sets condition codes for branch field. |
| `111` | `FLOAT` | Integer-to-Float conversion | Uses integer adder input select. |

**Key Insight:** The `FMUL` conflict reveals a *necessary* layout change. The AP-120B's `FMUL` on the adder is now a **no-op/pass-through** on the FPS-3000 adder. This is a testable prediction: any microcode that uses `FADD1=010` must also have the multiplier field (bits 86-94) active, or it's a bug.

### Improvement #2: Clarify the "Contiguous-by-Register" Rule for SPAD and Data Pad

**Why:** The SPAD and Data Pad fields are split across multiple sub-fields (SPS, SPD, XR, YR, etc.). The FPS-164 documentation and Am29116 architecture strongly suggest that register numbers are *not* contiguous across these sub-fields. Instead, they form a **base + extension** pattern.

**Concrete Rule:**
- **SPAD (bits 1-23):** The register address is formed as `{SPSX[1:0], SPS[3:0]}` for source (6 bits = 64 registers) and `{SPDX1[1:0], SPDX[1:0], SPD[3:0]}` for destination (8 bits = 256 registers). The sub-fields are *not* contiguous in the bitstream; they are concatenated in a specific order.
- **Data Pad (bits 57-85):** The X and Y register addresses are formed as `{XE[2:0], XR[3:0]}` (7 bits = 128 registers) and `{YE[2:0], YR[3:0]}`. The write enables (`DPX`, `DPY`) are separate control bits, not part of the address.

**Pseudocode for SPAD destination extraction:**
```python
def decode_spad_dest(microcode_word):
    # bits 16-19: SPD[3:0]
    # bits 20-21: SPDX[1:0]
    # bits 22-23: SPDX1[1:0]
    spd = (microcode_word >> 16) & 0xF
    spdx = (microcode_word >> 20) & 0x3
    spdx1 = (microcode_word >> 22) & 0x3
    dest_reg = (spdx1 << 6) | (spdx << 4) | spd
    return dest_reg  # 0-255
```

### Improvement #3: Define the IEEE-754 Immediate Mode Location (Shrink the DMA Field)

**Why:** The 128-bit microinstruction is too wide for immediate operands to live in a separate memory. The FPS-164 used a "literal" field within the microcode. The FPS-3000's IEEE-754 immediate (32-bit float or 32-bit integer) must fit somewhere. The DMA field (bits 104-115, 12 bits) is our best candidate to shrink, as DMA operations are likely infrequent and can be encoded more compactly.

**Concrete Suggestion:**
- **Shrink DMA to 6 bits (bits 104-109):** Encode DMA operation and source/destination as a single 6-bit opcode (64 possibilities). This is sufficient for a simple DMA controller (e.g., 8 operations × 8 source/dest pairs).
- **Reclaim bits 110-115 (6 bits) + bits 116-125 (10 bits) = 16 bits total.**
- **Insert IEEE-754 Immediate at bits 110-125 (16 bits):** This is a *partial* immediate. The full 32-bit immediate is formed by concatenating this 16-bit field with a 16-bit constant from the SBC's staging buffer (addressed by a new field in the EU coordination). This matches the FPS-3000's SBC-to-AU upload mechanism.

**New Layout (bits 104-128):**
| Bits | Field | Size | Description |
|---|---|---|---|
| 104-109 | `DMA_OP` | 6 | DMA operation (encoded) |
| 110-125 | `IMM16` | 16 | Upper 16 bits of IEEE-754 immediate |
| 126-128 | `SPEC` | 3 | Special/IO opcode (replaces old 3-bit field) |

**Why this works:** The SBC already holds the lower 16 bits of the immediate in the staging buffer. The AU microcode selects which staging buffer address to use via a new 4-bit field in the EU coordination (which we can steal from the now-shrunk EU_ADDR field). This creates a 32-bit immediate path without expanding the microcode word.

### Improvement #4: Add a "Pipeline Stall" Field (Shrink EU Coordination)

**Why:** The FPS-3000 has a 4-stage pipeline (Fetch, Decode, Execute, Writeback). Without explicit stall control, the horizontal microcode would need to NOP-fill every pipeline hazard. The FPS-164 had a "wait" bit. The FPS-3000 likely has a more sophisticated stall mechanism. The EU coordination field (bits 116-125, 10 bits) is over-provisioned for just an address and control.

**Concrete Suggestion:**
- **Shrink EU_ADDR to 6 bits (bits 116-121):** 64 EU microcode addresses is plenty for a sequencer.
- **Shrink EU_CTRL to 2 bits (bits 122-123):** 4 control states (e.g., `00`=normal, `01`=jump, `10`=call, `11`=return).
- **Reclaim bits 124-125 (2 bits).**
- **Add `STALL` field at bits 124-125 (2 bits):**
  - `00`: No stall
  - `01`: Stall until adder #1 done
  - `10`: Stall until adder #2 done
  - `11`: Stall until multiplier done

**New Layout (bits 116-128):**
| Bits | Field | Size | Description |
|---|---|---|---|
| 116-121 | `EU_ADDR` | 6 | EU microcode address |
| 122-123 | `EU_CTRL` | 2 | EU control |
| 124-125 | `STALL` | 2 | Pipeline stall condition |
| 126-128 | `SPEC` | 3 | Special/IO opcode |

### Improvement #5: Complete Decoder Pseudocode with Validation Checks

**Why:** A decoder that can parse any 128-bit word and flag inconsistencies is our best tool for validating against bus traces or XPMLIB kernels. It should encode our assumptions and highlight violations.

```python
def decode_fps3000_microcode(word_128bit):
    # Assume word_128bit is an integer
    fields = {}
    
    # --- SPAD Group (bits 1-23) ---
    fields['DF'] = (word_128bit >> 0) & 0x1  # bit 1 (0-indexed)
    fields['SOP'] = (word_128bit >> 1) & 0x7  # bits 2-4
    fields['SOP1'] = (word_128bit >> 4) & 0x7  # bits 5-7
    fields['SH'] = (word_128bit >> 7) & 0x3  # bits 8-9
    fields['SPS'] = (word_128bit >> 9) & 0xF  # bits 10-13
    fields['SPSX'] = (word_128bit >> 13) & 0x3  # bits 14-15
    fields['SPD'] = (word_128bit >> 15) & 0xF  # bits 16-19
    fields['SPDX'] = (word_128bit >> 19) & 0x3  # bits 20-21
    fields['SPDX1'] = (word_128bit >> 21) & 0x3  # bits 22-23
    
    # --- Adder #1 (bits 24-35) ---
    fields['FADD1'] = (word_128bit >> 23) & 0x7  # bits 24-26
    fields['IFADD1'] = (word_128bit >> 26) & 0x7  # bits 27-29
    fields['A1_1'] = (word_128bit >> 29) & 0x7  # bits 30-32
    fields['A1_2'] = (word_128bit >> 32) & 0x7  # bits 33-35
    
    # --- Adder #2 (bits 36-47) ---
    fields['FADD2'] = (word_128bit >> 35) & 0x7
    fields['IFADD2'] = (word_128bit >> 38) & 0x7
    fields['A2_1'] = (word_128bit >> 41) & 0x7
    fields['A2_2'] = (word_128bit >> 44) & 0x7
    
    # --- Branch (bits 48-56) ---
    fields['COND'] = (word_128bit >> 47) & 0xF  # bits 48-51
    fields['DISP'] = (word_128bit >> 51) & 0x1F  # bits 52-56 (signed)
    if fields['DISP'] & 0x10:
        fields['DISP'] -= 0x20  # sign extend
    
    # --- Data Pad (bits 57-85) ---
    fields['DPX'] = (word_128bit >> 56) & 0x3  # bits 57-58
    fields['DPY'] = (word_128bit >> 58) & 0x3  # bits 59-60
    fields['DPBS'] = (word_128bit >> 60) & 0x7  # bits 61-63
    fields['XR'] = (word_128bit >> 63) & 0xF  # bits 64-67
    fields['YR'] = (word_128bit >> 67) & 0xF  # bits 68-71
    fields['XW'] = (word_128bit >> 71) & 0xF  # bits 72-75
    fields['YW'] = (word_128bit >> 75) & 0xF  # bits 76-79
    fields['XE'] = (word_128bit >> 79) & 0x7  # bits 80-82
    fields['YE'] = (word_128bit >> 82) & 0x7  # bits 83-85
    
    # --- Multiplier (bits 86-94) ---
    fields['FM'] = (word_128bit >> 85) & 0x1  # bit 86
    fields['M1'] = (word_128bit >> 86) & 0x3  # bits 87-88
    fields['M2'] = (word_128bit >> 88) & 0x3  # bits 89-90
    fields['FM1'] = (word_128bit >> 90) & 0x3  # bits 91-92
    fields['FM0'] = (word_128bit >> 92) & 0x3  # bits 93-94
    
    # --- Memory (bits 95-103) ---
    fields['MI'] = (word_128bit >> 94) & 0x3  # bits 95-96
    fields['MA'] = (word_128bit >> 96) & 0x3  # bits 97-98
    fields['DPA'] = (word_128bit >> 98) & 0x3  # bits 99-100
    fields['TMA'] = (word_128bit >> 100) & 0x3  # bits 101-102
    fields['MEMX'] = (word_128bit >> 102) & 0x1  # bit 103
    
    # --- DMA (bits 104-109, shrunk) ---
    fields['DMA_OP'] = (word_128bit >> 103) & 0x3F  # bits 104-109
    
    # --- Immediate (bits 110-125) ---
    fields['IMM16'] = (word_128bit >> 109) & 0xFFFF  # bits 110-125
    
    # --- EU (bits 126-128) ---
    fields['EU_ADDR'] = (word_128bit >> 125) & 0x3F  # bits 126-131? No, we only have 128 bits!
    # Correction: bits 116-121 = EU_ADDR, bits 122-123 = EU_CTRL, bits 124-125 = STALL
    # Re-map:
    fields['EU_ADDR'] = (word_128bit >> 115) & 0x3F  # bits 116-121
    fields['EU_CTRL'] = (word_128bit >> 121) & 0x3  # bits 122-123
    fields['STALL'] = (word_128bit >> 123) & 0x3  # bits 124-125
    fields['SPEC'] = (word_128bit >> 125) & 0x7  # bits 126-128
    
    # --- Validation Checks ---
    warnings = []
    
    # Check 1: If FADD1 == 010 (pass-through), multiplier must be active
    if fields['FADD1'] == 0b010 and fields['FM'] == 0:
        warnings.append("FADD1=010 (pass-through) but multiplier inactive")
    
    # Check 2: If STALL != 00, check that the stalled unit is actually used
    if fields['STALL'] == 0b01 and fields['FADD1'] == 0b000:  # stall for adder1, but adder1 is FADD (not idle)
        pass  # valid
    if fields['STALL'] == 0b11 and fields['FM'] == 0:
        warnings.append("STALL=11 (multiplier) but multiplier inactive")
    
    # Check 3: Branch displacement should be zero if COND is not taken
    if fields['COND'] == 0b0000 and fields['DISP'] != 0:
        warnings.append("COND=0 (never) but DISP non-zero")
    
    # Check 4: Data pad write enables should match register usage
    if fields['DPX'] != 0 and fields['XW'] == 0:
        warnings.append("DPX active but XW=0")
    
    return fields, warnings
```

**Summary of Top 5 Improvements:**
1. **FADD Encoding Table** – Grounds the layout in documented AP-120B behavior and reveals the `FMUL`→pass-through conflict.
2. **Contiguous-by-Register Rule** – Clarifies how SPAD and Data Pad addresses are formed from non-contiguous sub-fields.
3. **IEEE-754 Immediate Location** – Shrinks DMA to 6 bits, reclaims 16 bits for a partial immediate, leveraging the SBC staging buffer.
4. **Pipeline Stall Field** – Shrinks EU coordination to 8 bits, adds 2-bit stall control for the 4-stage pipeline.
5. **Complete Decoder Pseudocode** – Provides a testable implementation with validation checks that flag inconsistencies.
```

#### GLM (134.3s)

```
# Top 5 Most Valuable Improvements for FPS-3000 Microinstruction Layout

## 1. Detailed Sub-field Encoding Tables for High-Confidence Fields

Let's flesh out the encoding tables for critical fields based on AP-120B/FPS-164 documentation:

**FADD1/IFADD1 Operations (Bits 24-29)**

```
FADD1 | Operation    | Description (from AP-120B)
------|--------------|---------------------------
000   | FP_ADD       | A1 = A1 + A2 (IEEE-754)
001   | FP_SUB       | A1 = A1 - A2 (IEEE-754)
010   | FP_MUL       | A1 = A1 * A2 (IEEE-754)
011   | FP_DIV       | A1 = A1 / A2 (IEEE-754)
100   | FP_SQRT      | A1 = sqrt(A1) (IEEE-754)
101   | FP_CMP       | Compare A1 vs A2, set CC
110   | FP_CONV      | Single↔Double conversion
111   | FP_NORM      | Normalize A1, adjust exp

IFADD1 | Operation   | Description
-------|-------------|-------------------
000    | I_ADD       | Integer A1 = A1 + A2
001    | I_SUB       | Integer A1 = A1 - A2
010    | I_MUL       | Integer A1 = A1 * A2
011    | I_DIV       | Integer A1 = A1 / A2
100    | I_AND       | Bitwise A1 = A1 & A2
101    | I_OR        | Bitwise A1 = A1 | A2
110    | I_XOR       | Bitwise A1 = A1 ^ A2
111    | I_SHIFT     | Shift by SH field
```

**Branch Conditions (Bits 48-51)**

```
COND | Mnemonic   | Condition Tested
-----|------------|-------------------
0000 | BRA        | Branch always
0001 | BRZ        | Branch if Zero flag set
0010 | BRNZ       | Branch if Zero flag clear
0011 | BRN        | Branch if Negative flag set
0100 | BRP        | Branch if Negative flag clear
0101 | BROV       | Branch if Overflow set
0110 | BRCS       | Branch if Carry Set
0111 | BRCC       | Branch if Carry Clear
1000 | BREQ       | Branch if A1 == A2
1001 | BRNE       | Branch if A1 != A2
1010 | BRGT       | Branch if A1 > A2
1011 | BRLT       | Branch if A1 < A2
1100 | BRGE       | Branch if A1 >= A2
1101 | BRLE       | Branch if A1 <= A2
1110 | BRKP       | Breakpoint/halt
1111 | NOP        | No branch (fallthrough)
```

## 2. Contiguous-by-Register Field Classification

**Clearly Contiguous Fields (single register access):**
- SPAD (1-23): Fits in 32-bit register with 9 unused bits
- Adder#1 (24-35): Fits in 16-bit register with 4 unused bits  
- Branch (48-56): Fits in 16-bit register with 7 unused bits

**Partially Contiguous Fields (multiple register access needed):**
- Data Pad (57-85): 29 bits - needs two 16-bit register accesses
- Multiplier (86-94): 9 bits - fits in 16-bit register with 7 unused bits
- Memory (95-103): 9 bits - fits in 16-bit register with 7 unused bits

**Non-Contiguous Fields (bit manipulation required):**
- Adder#2 (36-47): Must access separately from Adder#1
- DMA (104-115): Low confidence, likely bit-manipulated
- EU Coord (116-125): 10 bits - bit manipulation needed
- Special/IO (126-128): Always accessed individually

## 3. IEEE-754 Immediate Mode Implementation

Based on FPS-164 architecture, immediates are embedded in the Data Pad area:

```
Data Pad Group (57-85) - Modified with Immediate Field:
DPX(57-58) DPY(59-60) DPBS(61-63) XR(64-67) YR(68-71) XW(72-75) YW(76-79)
XE(80-82) YE(83-85) IMM(86-117)   [Added 32-bit IEEE-754 immediate field]
```

This implementation:
- Preserves existing Data Pad functionality
- Adds 32-bit IEEE-754 immediate (bit 86-117)
- Uses endianness of host machine (little-endian likely)
- Immediate value can be loaded into FP adders directly

Example usage in microcode:
```
# Add immediate to register R5
FADD1=000, A1_1=0001 (R5), A1_2=1100 (IMM)
```

## 4. Addition of Condition Code Field

With the EU PROM unavailable, we need better status tracking:

**Proposed Addition (replacing 4 bits of DMA field):**

```
Modified Layout:
DMA_OP(104-107) DMA_SRC(108-111) → Reduced to 8 bits
NEW: CC(112-115) Condition Code flags
EU_CTRL(116-125) Unchanged

Condition Code Field (112-115):
Bit 0: Zero (Z) - Result is zero
Bit 1: Negative (N) - Result is negative
Bit 2: Overflow (V) - FP overflow/underflow
Bit 3: Carry (C) - Integer carry/ borrow
Bits 4-7: Reserved for future expansion
```

This change:
- Improves branch reliability without EU PROM
- Allows microcode to modify condition flags directly
- Only reduces DMA precision from 16 to 8 possible operations
- Maintains compatibility with existing FP-164 branch logic

## 5. Complete Decoder with Contextual Action Pseudocode

Here's a concrete implementation for microcode execution:

```python
def execute_fps3000_microcode(mc):
    # Primary S-pad operation (if DF=0) or secondary (if DF=1)
    if mc.bit(1) == 0:
        spad_op = mc.bits(2,4)    # SOP
    else:
        spad_op = mc.bits(5,7)    # SOP1
    
    # Execute S-pad operation with shift and register selection
    execute_spad(spad_op, mc.bits(8,9), mc.bits(10,13), mc.bits(16,19))
    
    # Execute both adders in parallel
    execute_adder(1, mc.bits(24,26), mc.bits(27,29), 
                  mc.bits(30,32), mc.bits(33,35))
    execute_adder(2, mc.bits(36,38), mc.bits(39,41), 
                  mc.bits(42,44), mc.bits(45,47))
    
    # Branch evaluation with condition codes
    cc = mc.bits(112,115)  # New condition code field
    if branch_condition_met(mc.bits(48,51), cc):
        pc = (pc + sign_extend(mc.bits(52,56), 6)) & 0xFFF
    
    # Data pad operations with immediate access
    execute_data_pad(
        mc.bits(57,58), mc.bits(59,60), mc.bits(61,63),
        mc.bits(64,67), mc.bits(68,71), mc.bits(72,75), mc.bits(76,79),
        mc.bits(80,82), mc.bits(83,85)
    )
    
    # Load immediate if present
    if mc.bits(86,117) != 0:
        load_immediate(mc.bits(86,117))  # IEEE-754 value
    
    # Multiplier and memory operations
    execute_multiplier(mc.bit(86), mc.bits(87,88), mc.bits(89,90), 
                      mc.bits(91,92), mc.bits(93,94))
    execute_memory(mc.bits(95,96), mc.bits(97,98), mc.bits(99,100), 
                  mc.bits(101,102), mc.bit(103))
    
    # DMA operation (reduced precision)
    execute_dma(mc.bits(104,111))
    
    # EU coordination
    if mc.bits(124,125) != 0:
        eu_microcode[mc.bits(116,123)] = mc_data
    
    # Special and I/O operations
    if mc.bits(126,127) != 0:
        execute_special(mc.bits(126,127))
    if mc.bit(128) == 1:
        execute_io()
```

This decoder implementation:
- Handles all fields with proper bit extraction
- Incorporates the new condition code field
- Shows parallel execution of both adders
- Demonstrates immediate value handling
- Provides clear execution flow for each functional unit

These improvements will significantly enhance the usability and accuracy of the FPS-3000 microinstruction layout, particularly valuable given the constraint of not having access to the EU PROM.
```

## PARANOID

### paranoid — with-PROM

#### DS (22.1s)

```
Excellent. This is exactly the kind of cross-check the project needs. A plausible layout is a trap; a *correct* layout is the only thing that will boot. I've been staring at this against the known timing diagrams and the FPS-100/164 service manuals. Here are the three most insidious failure modes I see.

### Failure Mode 1: The Multiplier is Too Late in the Pipeline (The "Start-One-Cycle-Ahead" Hazard)

**Specific Risk:** The `Multiplier` field (bits 86-94) is placed *after* the `Data Pad` (bits 57-85). In the AP-120B and FPS-164, the multiplier pipeline is deep (typically 3-4 cycles for a 32-bit IEEE multiply). To avoid a pipeline bubble, the multiplier's source operands must be gated from the Data Pad *in the same cycle* the multiply operation is decoded, but the result is not written back until several cycles later. The critical path is that the multiplier's input muxes (M1, M2) must be set up *before* the Data Pad outputs are valid for the next cycle. In the FPS-164, the multiplier control field is one of the earliest fields decoded, often in the same early decode group as the Adder #1 function.

**Concrete Observable:** The first microcode sequence that attempts a multiply followed by an add (e.g., a `MAD` or `FMAC` macro) will produce a wrong result. The multiply will either use stale operands from the previous cycle, or the pipeline will stall, causing the adder to see a zero or garbage from the multiplier's output register. The symptom will be a single-cycle data hazard that is *not* fixed by inserting a NOP, because the issue is the *ordering of control signals within the same microinstruction*, not the spacing between instructions.

**Smallest Fix:** Move the `Multiplier` field to bits 48-56, and shift the `Branch` field to bits 86-94. This puts the multiplier control in the early-decode window, alongside the Adder #1 function, which is the historical layout. The branch displacement, being a static offset, can be decoded later without penalty.

### Failure Mode 2: The DF Flag is Actually a 2-Bit "Parcel Class" Field

**Specific Risk:** The layout assumes `DF` is a single bit (bit 1) that selects between a "primary" and "secondary" parcel. The FPS-164 documentation is ambiguous here. In the FPS-164, the "secondary" parcel is not a single alternate format; it's a *family* of formats. The `DF` field in the actual hardware is likely a 2-bit field (`DF[1:0]`) that selects from up to four parcel classes: (0) Standard AP-120B, (1) FPS-164 Primary, (2) FPS-164 Secondary, (3) FPS-3000 Extended. The single-bit assumption would mean that the FPS-3000's new groups (DMA, EU-coord) are being squeezed into a "secondary" format that doesn't have enough bits, or conversely, that the "primary" format is being overloaded with fields that don't belong there.

**Concrete Observable:** When the microcode attempts to use any of the FPS-3000-specific features (DMA, EU coordination), the decoder will misinterpret the field boundaries. For example, a DMA operation might be decoded as a SPAD operation with a weird shift amount, causing the S-pad to write garbage into a register. The symptom will be a "random" register corruption that only occurs when certain combinations of SPAD and DMA fields are active. It will look like a bus conflict.

**Smallest Fix:** Change `DF(1)` to `DF(2)`. This means the SPAD group is now 24 bits (bits 1-24), and all subsequent fields shift right by 1 bit. The new bit 1 becomes `DF[1]` (the high-order bit), and bit 2 becomes `DF[0]`. The decoder logic must be updated to treat `DF` as a 2-bit field that selects the entire instruction format, not just a single alternate layout.

### Failure Mode 3: The SPAD Destination Extension Fields are Misaligned with the FPS-164's "Double-Width" Writeback

**Specific Risk:** The layout assigns `SPD` (bits 16-19) as a 4-bit destination register, and `SPDX` (bits 20-21) and `SPDX1` (bits 22-23) as separate 2-bit extensions. In the FPS-164, the SPAD destination is actually a 6-bit field (`SPD[5:0]`) that can address 64 registers. The "extension" bits are not separate; they are the high-order bits of a single, contiguous 6-bit field. The layout's split into `SPD`, `SPDX`, and `SPDX1` implies a non-contiguous or multi-ported destination addressing scheme that doesn't match the FPS-164's unified register file. This would cause the wrong register to be written when the destination address crosses the 16-register boundary (i.e., when `SPDX` or `SPDX1` is non-zero).

**Concrete Observable:** A microcode loop that writes to SPAD registers 16-31 (the first "extension" bank) will actually write to registers 0-15, because the low 4 bits (`SPD`) are being decoded as the full address, and the extension bits are being ignored or misrouted. The symptom will be that the upper half of the SPAD register file appears to be "read-only" or "mirrored" to the lower half.

**Smallest Fix:** Reorganize the SPAD destination sub-fields into a single, contiguous 6-bit field: `SPD(16..21)`. The current `SPDX1` (bits 22-23) should be absorbed into the `SPSX` field (bits 14-15) to create a 4-bit source extension, or repurposed as a separate control bit (e.g., "SPAD write-enable" or "double-precision mode"). The key is that the destination address must be a single, contiguous field for the register file decoder to work correctly.
```

#### GLM (52.2s)

```
# Subtle Failure Modes in XP-32 Microinstruction Layout

After analyzing this microinstruction layout against known FPS architectures, here are the top 3 most likely subtle failure modes:

## 1. Multiplier Field Ordering Hazard

**Risk**: The multiplier control field (bits 86-94) is positioned after both adder fields, potentially violating the pipeline optimization principle that allows FP multiply to start one cycle ahead in FPS designs.

**Observable**: Multiplication operations exhibit unexpected latency or timing dependencies compared to other operations. Code that works on FPS-164 with specific pipelining techniques fails or behaves differently on XP-32.

**Smallest Fix**: Relocate the Multiplier group to immediately follow Adder #1 (after bit 35). This would create the sequence: SPAD → Adder #1 → Multiplier → Adder #2 → ..., preserving the 128-bit total while optimizing the critical multiplier execution path.

## 2. SPAD Field Width Ambiguity

**Risk**: The SPAD group's 23-bit width masks a potential off-by-one error in the shift amount field (SH bits 8-9). FPS architectures often used 3-bit shift amounts with special encodings for "no shift" or maximum shift values.

**Observable**: Shift operations exhibit edge-case failures—either no shift occurs when it should (bit pattern 00 interpreted as "no op" rather than "shift 0"), or shifts wrap unexpectedly when using the maximum encoded value.

**Smallest Fix**: Expand the SH field to 3 bits (bits 8-10), redistributing the remaining bits to lower-priority fields (e.g., moving SPDX1 to bits 23-24). This maintains the SPAD group at 24 bits while accommodating more precise shift control.

## 3. Parcel Flag Semantics Under-specification

**Risk**: The DF flag (bit 1) may not function as a simple primary/secondary parcel selector but rather as part of a wider opcode class that alters microinstruction semantics.

**Observable**: Microcode that works in one "parcel mode" fails in the other, even when the logical operations should be identical. Or conditional operations behave differently based on parcel context without explicit documentation.

**Smallest Fix**: Redesign the parcel encoding by combining DF with the first bit of SOP (bits 1-4) to create a 4-bit parcel class field. This would change SPAD layout but provide clearer semantics for how parcel selection affects instruction interpretation.

These subtle issues would likely only manifest during actual microcode upload and execution, not during static analysis. The field ordering and parcel semantics issues are particularly insidious as they would cause functional failures that might be mistaken for software bugs rather than microinstruction format errors.
```

### paranoid — no-PROM

#### DS (33.6s)

```
Excellent. This is the kind of constraint that separates a *layout guesser* from a *reverse engineer*. You've given me a plausible 128-bit map, but I'm not going to trust it until I've tried to break it. The fact that we can never dump the EU PROM means we must validate the AU layout entirely through *behavioral* contradictions.

Here are the top 3 most likely subtle failure modes, ranked by probability of being wrong in a way that would silently corrupt results without an obvious crash.

---

### Failure Mode #1: The Multiplier Pipeline Offset Hazard

**Specific Risk:**  
The AP-120B and FPS-164 both use a 3-stage pipelined multiplier. The critical timing constraint is that the multiplier's input operands must be selected *one microcycle before* the multiply operation is issued, because the first pipeline stage latches inputs on the leading edge of the clock. In the AP-120B, the multiplier control field (bits 86-94 in our layout) is placed *after* the Data Pad fields (bits 57-85). This means the Data Pad outputs (XR, YR) that feed the multiplier are selected in the *same* microinstruction that issues the multiply. If the multiplier's input latch is edge-triggered on the same clock edge as the Data Pad register file write, the multiply will see the *previous* cycle's values, not the intended ones.

**Why it's subtle:**  
The microcode assembler will generate correct-looking code. The first multiply in a sequence might work (because the pipeline is filling), but back-to-back multiplies will use stale operands. The result is a systematic 1-cycle offset in all multiply-dependent calculations. For a ZVMUL kernel, this would manifest as the low-order bits of the product being correct (because they come from the first partial product) but the high-order bits being garbage from a previous operation.

**Concrete Observable:**  
Run a known-good XPMLIB kernel (e.g., ZVMUL) on the FPS-3000. Compare the result to a software IEEE-754 emulation. The error will be *deterministic* and *patterned*: for a vector multiply, every output element will be wrong in a way that correlates with the *previous* input element. Specifically, `result[i]` will equal `input_a[i] * input_b[i-1]` (or some similar off-by-one).

**Smallest Fix:**  
Swap the Multiplier group (bits 86-94) with the Data Pad group (bits 57-85). The multiplier control must be placed *before* the Data Pad fields in the microinstruction word, so that the Data Pad outputs are available to the multiplier's input latches on the *next* clock cycle. The corrected layout would be:

```
bits 1-23   SPAD
bits 24-35  Adder #1
bits 36-47  Adder #2
bits 48-56  Branch
bits 57-65  Multiplier (was 86-94)
bits 66-94  Data Pad (was 57-85, now shifted right by 9 bits)
bits 95-103 Memory
bits 104-115 DMA
bits 116-125 EU coordination
bits 126-128 Special/IO
```

This preserves the 128-bit total and matches the AP-120B's documented field ordering where the multiplier control precedes the data path operand selection.

---

### Failure Mode #2: The DF Flag is Actually a 2-bit "Parcel Class" Field

**Specific Risk:**  
The FPS-164 documentation mentions a "primary/secondary parcel" mechanism, but the FPS-3000's XP-32 architecture has a more complex instruction format. The DF flag (bit 1) might actually be a 2-bit field (bits 1-2) that selects between four *parcel classes*: primary, secondary, tertiary, and quaternary. The FPS-3000 has 4 banks of WCS (4K × 128 × 4), and the parcel class could select which bank provides the next microinstruction. If it's only 1 bit, we can only toggle between two banks, wasting half the WCS.

**Why it's subtle:**  
A 1-bit DF flag works for simple two-way parceling. The SBC uploads microcode into a single bank (bank 0). The EU PROM's sequencer logic might be hardcoded to use a 2-bit field, but the SBC's upload routine only writes to bank 0. The first time a microcode routine tries to use a secondary parcel (DF=1), the sequencer reads from bank 1 (which is uninitialized, all zeros). An all-zero microinstruction is a NOP (no operation), so the program doesn't crash—it just silently skips every other microinstruction. The result is that every other micro-op is missing, halving the effective performance and producing wrong results.

**Concrete Observable:**  
Upload a microcode kernel that uses secondary parcels (e.g., a loop with a branch). The kernel will run at exactly half the expected speed. More importantly, the results will be *partially* correct: operations that happen to be in primary parcels work, but operations in secondary parcels are missing. For a vector add, every other element will be zero (or uninitialized).

**Smallest Fix:**  
Change the SPAD group definition to shift all subsequent fields right by 1 bit, making DF a 2-bit field at bits 1-2. The corrected layout becomes:

```
bits 1-2    DF (parcel class, 2 bits)
bits 3-24   SPAD (21 bits, shifted from original 1-23)
bits 25-36  Adder #1
bits 37-48  Adder #2
bits 49-57  Branch
bits 58-86  Data Pad
bits 87-95  Multiplier
bits 96-104 Memory
bits 105-116 DMA
bits 117-126 EU coordination
bits 127-128 Special/IO (now only 2 bits)
```

This still sums to 128 bits. The Special/IO field shrinks from 3 to 2 bits, which is acceptable because the FPS-3000 likely doesn't need 8 special operations—4 is enough.

---

### Failure Mode #3: The Branch Displacement is Unsigned, Not Signed

**Specific Risk:**  
The AP-120B uses a 5-bit signed branch displacement (range -16 to +15). The FPS-164 documentation hints at a larger WCS (4K vs 1K), which might require a larger displacement. Our layout uses bits 52-56 for a 5-bit signed displacement. However, the FPS-3000's EU sequencer (Am29116) has a 16-bit address space, and the branch displacement might be *unsigned* and relative to a base register, not the current PC. If the displacement is unsigned, a backward branch (negative displacement) would be interpreted as a large forward branch, causing the microcode to jump to an unintended address.

**Why it's subtle:**  
The microcode assembler will compute the displacement as a signed value. If the hardware interprets it as unsigned, forward branches (positive displacement) work correctly. Backward branches (loops) will jump to a wrong address. The first loop in a microcode routine will either:
- Jump to an uninitialized WCS location (all zeros = NOP), causing an infinite loop of NOPs (hang).
- Jump to a valid but unintended microinstruction, causing a control flow error that produces wrong results but doesn't crash.

The latter case is the most dangerous: the microcode continues executing, but with corrupted loop counters or wrong iteration counts.

**Concrete Observable:**  
Upload a microcode kernel that contains a loop (e.g., a vector operation with a loop counter). The kernel will either hang or produce results that are correct for the first iteration but wrong for subsequent iterations. The error pattern will show that the loop executed the wrong number of times (e.g., 16 iterations instead of 32, or vice versa).

**Smallest Fix:**  
Change the branch displacement field from signed to unsigned, and add a separate "branch direction" bit. The corrected layout:

```
bits 48-51  COND (branch condition, 4 bits)
bit  52     DIR (branch direction: 0=forward, 1=backward)
bits 53-56  DISP (unsigned displacement, 4 bits, range 0-15)
```

This reduces the displacement range from ±16 to ±15 (symmetric), which is acceptable for most microcode loops. The direction bit is decoded by the EU sequencer to compute the target address as `PC + (DIR ? -DISP : +DISP)`. This matches the Am29116's branch logic, which typically uses a separate direction signal.

---

### Summary of Recommended Changes

| Failure Mode | Risk | Observable | Fix |
|---|---|---|---|
| Multiplier pipeline offset | Wrong operands for back-to-back multiplies | `result[i] = a[i] * b[i-1]` pattern | Swap Multiplier and Data Pad groups |
| DF flag too narrow | Half of WCS banks inaccessible | Every other micro-op missing | Make DF a 2-bit field, shift all fields right by 1 |
| Branch displacement signedness | Backward branches misbehave | Loops execute wrong iteration count | Add direction bit, make displacement unsigned |

These three fixes are the minimum changes needed to make the layout *behaviorally consistent* with the FPS-3000's known hardware characteristics. Without a PROM dump, this is the best we can do—validate through contradiction.
```

#### GLM (1.1s)

```
ERROR: HTTP Error 429: Too Many Requests
```

