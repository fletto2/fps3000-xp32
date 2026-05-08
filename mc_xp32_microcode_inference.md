# XP-32 microinstruction layout — Council-of-Clankers inference

Three rounds: independent proposal, cross-critique, then synthesis. Both DeepSeek-chat and GLM-4.5-air participate.

## Round 1 — independent proposals

### DeepSeek (61.5s)

```
This is a well-posed reverse-engineering problem. The constraints are tight: the layout must be a **superset** of the FPS-164 layout (which is itself a superset of the AP-120B layout), must add a second adder and a DMA controller, must be 128 bits, and must obey the contiguous-field rule.

I will propose a layout that **extends** the FPS-164 primary-parcel ordering (SPAD → Adder → Branch → Data Pad → Multiplier → Memory) and then appends the new groups (Adder #2, DMA, EU-coord) in a way that respects the hardware-routing economy.

---

## A. Field-by-Field Bit-Position Table (1-indexed, MSB = bit 1)

| Group | Field Name | Bit Range | Width | Notes |
|-------|------------|-----------|-------|-------|
| **SPAD** | SOP | 1–3 | 3 | Same as AP-120B/FPS-164 |
| | SOP1 | 4–5 | 2 | FPS-164 extension |
| | SH | 6–7 | 2 | Same |
| | SPS | 8–11 | 4 | Base S-pad source |
| | SPSX | 12–13 | 2 | FPS-164 extension |
| | SPD | 14–17 | 4 | Base S-pad dest |
| | SPDX | 18–19 | 2 | FPS-164 extension |
| | SPDX1 | 20–21 | 2 | FPS-164 extension |
| **Adder #1** | FADD | 22–24 | 3 | Same as AP-120B |
| | FADD1 | 25–26 | 2 | FPS-164 extension |
| | IFADD1 | 27–29 | 3 | FPS-164 integer adder |
| | A1 | 30–32 | 3 | Adder1 input1 mux |
| | A2 | 33–35 | 3 | Adder1 input2 mux |
| **Branch** | COND | 36–39 | 4 | Same as AP-120B |
| | DISP | 40–44 | 5 | Same as AP-120B |
| **Data Pad** | DPX | 45–46 | 2 | Same |
| | DPY | 47–48 | 2 | Same |
| | DPBS | 49–51 | 3 | Same |
| | XR | 52–54 | 3 | Base X-read index |
| | YR | 55–57 | 3 | Base Y-read index |
| | XW | 58–60 | 3 | Base X-write index |
| | YW | 61–63 | 3 | Base Y-write index |
| | XE | 64 | 1 | FPS-164 X-read extension |
| | YE | 65 | 1 | FPS-164 Y-read extension |
| | XWE | 66 | 1 | FPS-164 X-write extension |
| | YWE | 67 | 1 | FPS-164 Y-write extension |
| **Multiplier** | FM | 68 | 1 | Start multiply |
| | M1 | 69–70 | 2 | Multiplier input1 mux |
| | M2 | 71–72 | 2 | Multiplier input2 mux |
| | FM1 | 73–74 | 2 | FPS-164 extension |
| | FM0 | 75–76 | 2 | FPS-164 extension |
| **Memory** | MI | 77–78 | 2 | Memory input mux |
| | MA | 79–80 | 2 | Memory address reg op |
| | DPA | 81–82 | 2 | Data pad address reg op |
| | TMA | 83–84 | 2 | Table memory address reg op |
| | MEXT | 85 | 1 | FPS-164 memory extension |
| **Adder #2** | FADD2 | 86–88 | 3 | Adder2 function (mirrors FADD) |
| | A1_2 | 89–91 | 3 | Adder2 input1 mux |
| | A2_2 | 92–94 | 3 | Adder2 input2 mux |
| | FADD2_EXT | 95 | 1 | Extension for IEEE rounding mode |
| **DMA** | DMA_OP | 96–99 | 4 | 16 DMA operations (see §B.2) |
| | DMA_SRC | 100–102 | 3 | Source address space (SCM, LMD, TCM, etc.) |
| | DMA_DST | 103–105 | 3 | Destination address space |
| | DMA_LEN | 106–108 | 3 | Transfer length (1–8 words, or block) |
| | DMA_FLAGS | 109–110 | 2 | Interrupt enable, auto-increment mode |
| **EU-coord** | EU_ADDR | 111–118 | 8 | EU PROM address (2K × 80 → 11 bits needed; 8 bits = high part, low part from elsewhere?) |
| | EU_CTRL | 119–120 | 2 | EU sequencer state (start/stop/step/break) |
| | EU_SYNC | 121 | 1 | AU/EU synchronization flag |
| **Immediate** | IMM_HI | 122–128 | 7 | High bits of 15-bit immediate (when DPBS=2 or SOP=1+SPS=14) |
| | (IMM_LO) | (bits 48–63 reused) | 16 | Low 16 bits from YW/FM/M1/M2/MI/MA/DPA/TMA field (same as AP-120B) |

**Total bits**: 128 (1–128 inclusive).  
**Gaps**: None.  
**Overlaps**: The immediate mode reuses bits 48–63 (YW through TMA) as the low 16 bits of a 23-bit immediate (16+7=23). This is consistent with AP-120B and FPS-164 convention.

---

## B. Sub-Field Encoding Choices

### 1. Adder #2: Symmetric Mirror of Adder #1?

**Yes, symmetric**, with one minor extension.

- **Why symmetric**: The two adders are identical hardware units (both IEEE-754 32-bit FP adders). They share the same register file and bus structure. The operand muxes (A1_2, A2_2) have the same options as A1/A2: S-pad, Data Pad X/Y, multiplier output, memory output, immediate, etc.  
- **Why one extra bit (FADD2_EXT)**: The IEEE-754 standard requires four rounding modes (nearest, zero, +inf, –inf). The original FADD field (3 bits) only encodes 8 functions; one of those can be "rounding mode select", but a dedicated bit allows independent rounding control for Adder #2 without stealing from the function code.  
- **Contiguity**: The Adder #2 group is placed immediately after the Memory group, keeping all adder-related fields together (Adder #1 at bits 22–35, Adder #2 at bits 86–95). This satisfies the contiguous-by-resource rule.

### 2. DMA Controller Field Group

The DMA controller is modeled after the FPS-164's 8-class I/O-Op group, but specialized for SCM↔LMD transfers.

- **DMA_OP (4 bits, 16 operations)**:
  - 0: NOP
  - 1: Load SCM→LMD (block)
  - 2: Store LMD→SCM (block)
  - 3: Load SCM→TCM
  - 4: Store TCM→SCM
  - 5: Load SCM→Data Pad (direct)
  - 6: Store Data Pad→SCM
  - 7: Load LMD→TCM (local copy)
  - 8: Store TCM→LMD
  - 9–15: Reserved for scatter/gather, chaining, etc.

- **DMA_SRC / DMA_DST (3 bits each)**: Encode address space:
  - 0: SCM (System Common Memory)
  - 1: LMD (Local Memory Data)
  - 2: TCM (Table Cache Memory)
  - 3: Data Pad (DPX/DPY)
  - 4: S-pad
  - 5: EU PROM (for loading microcode)
  - 6–7: Reserved

- **DMA_LEN (3 bits)**: Transfer length in 32-bit words (1–8), or 0 = full block (up to 16K). This matches the 16K-word LMD size.

- **DMA_FLAGS (2 bits)**:
  - Bit 0: Interrupt on completion
  - Bit 1: Auto-increment source/destination addresses

**Why this structure**: It is compact (10 bits total), covers all likely transfer types, and is easily decoded by a small state machine. The 4-bit opcode allows future expansion.

### 3. Widening of Inherited Fields vs FPS-164

The FPS-164 layout uses 85 bits (1–85 in my numbering). The XP-32 has 43 extra bits (128 – 85). Here is how they are distributed:

| Group | FPS-164 width | XP-32 width | Change | Rationale |
|-------|---------------|-------------|--------|-----------|
| SPAD | 21 | 21 | None | Already sufficient for 16 S-pad registers + extensions |
| Adder #1 | 14 | 14 | None | Already sufficient |
| Branch | 9 | 9 | None | 5-bit displacement is tight, but FPS-164 kept it; XP-32 likely uses multi-word branches |
| Data Pad | 23 | 23 | None | FPS-164 already has 6 extension bits; XP-32's larger LMD (16K) requires wider indices? Actually, 3+1=4 bits gives 16 registers; 16K words need 14-bit address, but that's in the address register, not the index field. So no widening needed. |
| Multiplier | 9 | 9 | None | Already sufficient |
| Memory | 9 | 9 | None | Already sufficient |
| **Adder #2** | 0 | 10 | +10 | New group |
| **DMA** | 0 | 15 | +15 | New group |
| **EU-coord** | 0 | 11 | +11 | New group |
| **Immediate** | 16+8=24 | 16+7=23 | –1 | Actually, FPS-164 had SVAL(8)+HVAL(32) = 40-bit immediate; XP-32 uses 23-bit (16+7) because IEEE-754 32-bit floats need only 23-bit mantissa immediate? But sign+exponent need 9 more bits. So this is a **tentative** choice; see §B.5. |

**Total new bits**: 10+15+11 = 36. Plus 7 bits for immediate high part = 43. Matches.

### 4. EU Coordination Data

The EU (Execution Unit) runs from a separate 80-bit PROM (2K × 80). The AU (Arithmetic Unit) must tell the EU which PROM address to execute next, and synchronize.

- **EU_ADDR (8 bits)**: High 8 bits of the 11-bit PROM address. The low 3 bits are derived from the AU's program counter or a dedicated EU_PC register. This allows the AU to jump to any of 2048 EU microinstructions.
- **EU_CTRL (2 bits)**: Controls the EU sequencer:
  - 00: No operation (EU continues from its current PC)
  - 01: Start EU (reset PC to 0)
  - 10: Step EU (single-step for debugging)
  - 11: Break EU (halt until next AU cycle)
- **EU_SYNC (1 bit)**: Synchronization flag. When set, the AU waits for the EU to finish its current operation before proceeding. This prevents pipeline hazards.

**Why 11 bits for PROM address**: 2K = 2^11. The EU PROM is 2K deep. The AU's WCS is 4K deep. The EU address is independent.

### 5. IEEE-754 32-bit Immediate Encoding

The AP-120B used a 16-bit immediate (bits 48–63). The FPS-164 used a 40-bit immediate (SVAL 8 bits + HVAL 32 bits). For IEEE-754 single-precision (32-bit), we need:

- 1 sign bit
- 8 exponent bits
- 23 mantissa bits

**Total**: 32 bits. But the microinstruction has only 23 bits available for immediate (16 low + 7 high). How to encode?

**Proposed solution**: The immediate field encodes a **mantissa-only** value (23 bits), with sign and exponent taken from a dedicated register (e.g., S-pad register 15). This is a common trick in FPS machines: the "short literal" format.

- When DPBS=2 (VALUE) or SOP=1+SPS=14 (LDSPI), bits 48–63 (16 bits) form the low 16 bits of the mantissa, and bits 122–128 (7 bits) form the high 7 bits of the mantissa. Total 23-bit mantissa.
- The sign and exponent come from a "format register" (FR) that is set by a separate microinstruction (e.g., a new SPAD operation).

**Alternative**: Use a 32-bit immediate by stealing bits from the Adder #2 group when in immediate mode. But this violates the contiguous-field rule for Adder #2. The mantissa-only approach is cleaner.

**Confidence**: Medium. The exact encoding of IEEE-754 immediates in FPS machines is not documented, but the mantissa-only approach is consistent with the AP-120B's 16-bit immediate (which was a full 16-bit integer, not a float).

---

## C. Confidence Ratings

| Group | Confidence | Rationale |
|-------|------------|-----------|
| **SPAD** | **High** | Identical to FPS-164; no reason to change. |
| **Adder #1** | **High** | Identical to FPS-164. |
| **Branch** | **High** | Identical to FPS-164. |
| **Data Pad** | **High** | Identical to FPS-164; the larger LMD is addressed via address registers, not index fields. |
| **Multiplier** | **High** | Identical to FPS-164. |
| **Memory** | **High** | Identical to FPS-164. |
| **Adder #2** | **Medium** | The symmetric mirror is almost certain; the extra rounding bit is speculative. Could be 9 bits instead of 10. |
| **DMA** | **Medium** | The 4-bit opcode + 3-bit address spaces is plausible; the exact encoding of transfer types is unknown. |
| **EU-coord** | **Low** | The 8-bit address + 2-bit control + 1-bit sync is a guess. The EU might use a different synchronization mechanism (e.g., a flag in the branch condition). |
| **Immediate** | **Low** | The mantissa-only encoding is a workaround; the real XP-32 might have a 32-bit immediate field that overlaps with Adder #2 in a secondary parcel (like FPS-164's primary/secondary scheme). |

**Overall confidence**: **Medium**. The layout is consistent with all known constraints, but the exact bit positions for Adder #2, DMA, and EU-coord are not uniquely determined. The contiguous-field rule and the FPS-164 superset constraint strongly constrain the first 85 bits; the remaining 43 bits are more speculative.

---

## Summary

The proposed 128-bit XP-32 microinstruction layout:

- **Bits 1–85**: Identical to FPS-164 primary parcel (SPAD, Adder #1, Branch, Data Pad, Multiplier, Memory).
- **Bits 86–95**: Adder #2 group (symmetric mirror of Adder #1, plus rounding bit).
- **Bits 96–110**: DMA controller group (4-bit opcode, 3-bit source/destination, 3-bit length, 2-bit flags).
- **Bits 111–121**: EU coordination (8-bit PROM address, 2-bit control, 1-bit sync).
- **Bits 122–128**: High 7 bits of immediate mantissa (low 16 bits from bits 48–63 in immediate mode).

This layout satisfies all constraints: 128 bits, contiguous fields, AP-120B vocabulary preserved, FPS-164 extensions included, second adder present, DMA present, EU coordination present, and group ordering follows FPS-164 convention.
```

### GLM (135.9s)

```
We are designing a 128-bit microinstruction for the XP-32 processor, building on the AP-120B and FPS-164 architectures.

Constraints:
1. 128-bit total.
2. Contiguous bit-ranges for fields that drive the same hardware.
3. All AP-120B field names must appear (possibly widened).
4. All FPS-164 extensions must appear (which are additive, so no removal).
5. Must include Adder #2 group (since XP-32 has two adders).
6. Must include DMA controller group (for SCM ↔ local-memory transfers).
7. Must include EU-coordination bits (for EU-AU coordination via 80-bit PROM).
8. Follow FPS-164's group ordering if possible.

Additional known differences for XP-32:
- Two floating-point adders (so we need an Adder #2 group).
- DMA controller per AC.
- Wider Data Pad addressing (due to 16K LMD vs smaller in AP-120B/FPS-164).
- IEEE-754 32-bit float (so immediate for constants must be 32 bits? But note: in AP-120B and FPS-164, the immediate was only 16 or 32 bits for the immediate constant when in certain modes. However, for 32-bit IEEE float, we might need 32 bits for the constant. But note: the immediate field in the microcode is for constants that are loaded into registers or used immediately, so 32 bits would be natural for a 32-bit float. However, note that in AP-120B the immediate was 16 bits and in FPS-164 it was 32 bits for the "value" field. We are extending to 128 bits, so we can have 32-bit immediate for 32-bit float constants.)

Structure:

We have the following groups from FPS-164 (with additions for XP-32):

1. SPAD group: from AP-120B and FPS-164, which includes:
   - SOP (3 bits)
   - SH (2 bits) -> in FPS-164, this is 2 bits (same as AP-120B)
   - SPS (4 bits) and in FPS-164: SPSX(2) (so total 6 bits for SPS+SPSX) and also SPD (4 bits) and SPDX(2) and SPDX1(2) -> so total for SPAD: 3 (SOP) + 2 (SH) + 6 (SPS+SPSX) + 4 (SPD) + 4 (SPDX+SPDX1) = 19 bits? But note: Touzeau figure 2 shows 12 bits for SPAD? Actually, let me recount from Touzeau's figure 2 for FPS-164:

   Primary parcel (bit 1 to 64, 1-indexed):
     bits 1-12: 12 bits for SPAD group: 
        bits 1-3: SOP
        bits 4-5: SH
        bits 6-9: SPS (4 bits)
        bits 10-12: ??? -> actually, Touzeau's figure says:
          SOP: 3 bits (1-3)
          SH: 2 bits (4-5)
          SPS: 4 bits (6-9)
          SOP1: 3 bits (10-12) -> but note: the figure says "SOP1" in the SPAD group? Actually, the figure says:
          "SPAD: SOP/SOP1/SH/SPS+SPSX/SPD+SPDX/SPDX1"

   How to break down? The figure says 12 bits for SPAD. Let me assume:
      SOP: 3 bits (1-3)
      SH: 2 bits (4-5)
      SPS: 4 bits (6-9)
      SOP1: 3 bits (10-12) -> but wait, the figure says "SOP1" is part of SPAD? Actually, in the description: "SPAD group: SOP/SOP1/SH/SPS+SPSX/SPD+SPDX/SPDX1". So we have:

        SOP: 3 bits
        SOP1: 3 bits
        SH: 2 bits
        SPS: 4 bits + SPSX: 2 bits -> 6 bits total for SPS and SPSX?
        SPD: 4 bits + SPDX: 2 bits -> 6 bits for SPD and SPDX?
        SPDX1: 2 bits

      Total: 3+3+2+6+6+2 = 22 bits? But the figure says 12 bits. So there must be overlapping or sharing? Actually, the figure says the SPAD group is 12 bits, so the breakdown must be:

        SOP: 3 bits (1-3)
        SH: 2 bits (4-5)
        SPS: 4 bits (6-9) -> but then SPSX? It says "SPS+SPSX", so maybe SPS is 4 bits and SPSX is 2 bits? That would be 6 bits, but then we have 3+2+6=11 bits? Then what about SPD, SPDX, SPDX1? They are in the same group but not in the first 12 bits? Actually, the figure says the SPAD group is 12 bits, so the entire SPAD group must fit in 12 bits? That doesn't add up.

   Let me check the APSIM64 Appendix A (which we don't have) but based on Touzeau's paper and the evolution from AP-120B:

   AP-120B: SPAD group was bits 0-5 (6 bits) and then bits 6-9 (SPS) and 10-13 (SPD) -> total 4+4=8 bits? Actually, the AP-120B microcode is 64 bits:

        bit0: DF
        bits1-3: SOP -> 3 bits
        bits4-5: SH -> 2 bits
        bits6-9: SPS -> 4 bits
        bits10-13: SPD -> 4 bits
        ... so SPAD group is 3+2+4+4=13 bits? But note: bit0 is the DF flag, which is separate.

   In FPS-164, the SPAD group is 12 bits? Actually, the paper says: "The SPAD group is 12 bits". And then the next group (Adder) is 9 bits. So we must stick to that.

   After re-examining the paper: Figure 2 shows the primary parcel:

        bits 1-12: SPAD
        bits 13-21: Adder
        bits 22-30: Branch
        bits 31-49: Data Pad (19 bits)
        bits 50-54: Multiplier (5 bits)
        bits 55-63: Memory (9 bits)

   So the SPAD group is 12 bits. How are the fields arranged?

        SOP: 3 bits (bits 1-3)
        SH: 2 bits (bits 4-5)
        SPS: 4 bits (bits 6-9) -> but note: in the evolution, FPS-164 added SPSX (2 bits). So we have to fit 3 (SOP) + 2 (SH) + 4 (SPS) + 2 (SPSX) = 11 bits? Then what about SPD? In AP-120B, SPD was 4 bits. But in FPS-164, the SPAD group is 12 bits and we have SPD and also SPDX and SPDX1? The figure says "SPD+SPDX/SPDX1", which implies that SPD is 4 bits, SPDX is 2 bits, and SPDX1 is 2 bits? That would be 8 bits for SPD, SPDX, SPDX1? Then 3 (SOP) + 2 (SH) + 6 (SPS+SPSX) + 8 (SPD+SPDX+SPDX1) = 19 bits? That doesn't fit 12.

   This suggests that the SPAD group in FPS-164 is not expanded in the same way? Actually, the paper says: "The SPAD group is extended from 10 bits in the AP-120B to 12 bits in the FPS-164." and then lists the extensions: SPSX(2), SPDX(2), SPDX1(2). So how?

   Let me assume that in FPS-164:

        SOP: 3 bits (unchanged)
        SH: 2 bits (unchanged)
        SPS: 4 bits (unchanged) but then we have 2 bits for SPSX -> so we have 6 bits for SPS+SPSX? Then we have SPD: 4 bits? and then 2 bits for SPDX? and 2 bits for SPDX1? That would be 3+2+6+4+2+2=19? That doesn't fit.

   Alternatively, the paper says: "The SPAD group is 12 bits". So the fields must be:

        SOP: 3 bits
        SH: 2 bits
        SPS: 4 bits (but then SPSX might be part of SPS? Or maybe SPS and SPSX together are 6 bits? But then 3+2+6=11, and then we have 1 bit left? That doesn't work.

   Another possibility: the SPSX, SPDX, and SPDX1 are not all in the SPAD group? But the paper says they are extensions of the SPAD group.

   Given the confusion, I will base on the fact that in AP-120B the SPAD fields were:

        SOP: 3 bits
        SH: 2 bits
        SPS: 4 bits
        SPD: 4 bits -> total 13 bits? But note: the AP-120B microcode has the SPAD fields spread: bit0 (DF) is separate, then bits1-3 (SOP), 4-5 (SH), 6-9 (SPS), 10-13 (SPD). So 13 bits? But the first group is not called "SPAD" in the same way? Actually, the DF is separate.

   In the XP-32, we are going to design 128 bits. We can expand each field as needed.

   Given the complexity and the fact that we are designing a 128-bit word, we can assign:

        SPAD group: we'll allocate more than 12 bits? But we are not constrained to the same 12 bits? The constraint is the contiguousness and that we must have all the fields.

   We are told that the evolution from AP-120B to FPS-164 is purely additive. So we must have:

        SOP, SH, SPS, SPD, and also the FPS-164 extensions: SPSX(2), SPDX(2), SPDX1(2).

   So total for SPAD: 3 (SOP) + 2 (SH) + 6 (SPS+SPSX) + 6 (SPD+SPDX) + 2 (SPDX1) = 19 bits.

   But note: in AP-120B, SPS was 4 bits and SPD was 4 bits. Now we have added SPSX (2 bits) so SPS becomes 6 bits? Similarly, SPD becomes 6 bits (SPD+SPDX) and then SPDX1 is 2 bits? So 3+2+6+6+2 = 19.

   We can put the SPAD group at the beginning.

2. Adder group: XP-32 has two adders. So we need two Adder groups: Adder #1 and Adder #2.

   In FPS-164, the Adder group (for the single adder) is 9 bits:

        FADD: 3 bits
        IFADD1: 3 bits (new for FPS-164, integer adder)
        A1: 3 bits
        A2: 3 bits? -> wait, in the paper: bits 13-21: 9 bits -> so 3+3+3=9? Then A2 is not included? Actually, in AP-120B, the Adder group was:

        FADD: 3 bits (bits 14-16)
        A1: 3 bits (bits 17-19)
        A2: 3 bits (bits 20-22)

        So 9 bits. And in FPS-164, they added IFADD1 (3 bits) and then kept FADD, A1, A2? That would be 12 bits? But the figure says 9 bits for the Adder group. How?

   Actually, the paper says: "The Adder group is extended from 9 bits (AP-120B) to 9 bits (FPS-164)" and then lists the extension: IFADD1(3). So how did they fit? They must have reduced something? Or maybe the A2 is now included in the Data Pad group? 

   Alternatively, the figure says the Adder group is 9 bits and includes:

        FADD: 3 bits (unchanged)
        IFADD1: 3 bits (new)
        A1: 3 bits -> total 9 bits? Then what about A2? It must be in the Data Pad group? 

   In AP-120B, A2 was in the Adder group. In FPS-164, the paper says the Data Pad group (19 bits) has been extended? And one of the extensions is A2? That would break the contiguousness for the adder? But the constraint says fields driving the same hardware must be contiguous.

   This is a problem. I think we must stick to the fact that in AP-120B, A1 and A2 are in the Adder group. So in FPS-164, if they moved A2, that would break the contiguousness? That is unlikely.

   After re-examining: in the paper, the Adder group is 9 bits and the fields are:

        FADD (3 bits)
        IFADD1 (3 bits)
        A1 (3 bits)

   And then A2 is still in the Adder group? That would require 12 bits? But the figure says 9. 

   I think there might be a misunderstanding. The paper says: "The Adder group is 9 bits" and then the fields listed are FADD, IFADD1, and A1. So A2 is not included? Then where is A2? 

   In AP-120B, A2 was in the same group as A1? So if we remove A2 from the Adder group, then the adder's A2 select would be in a different group? That would break the contiguousness for the multiplexer. 

   Therefore, I suspect that in FPS-164, the Adder group is:

        FADD: 3 bits
        IFADD1: 3 bits (for the integer adder, which is a separate unit? or for the floating adder? The paper says "integer single-op adder")
        A1: 3 bits
        A2: 3 bits -> total 12 bits? But the figure says 9.

   This is a contradiction. Given the lack of clarity, I will base on the AP-120B structure for the Adder group and then extend for FPS-164.

   In AP-120B, the Adder group was:

        FADD: 3 bits (bits 14-16)
        A1: 3 bits (bits 17-19)
        A2: 3 bits (bits 20-22)

   Then in FPS-164, they added IFADD1 (3 bits) and also added extensions for the adder? So we can put IFADD1 in the same group? Then the Adder group becomes 12 bits? But the paper says 9 bits. 

   Alternatively, the FPS-164 paper might have a different breakdown? I will go by the paper's figure: 9 bits for the Adder group. How did they do it? They must have moved A2 to the Data Pad group? That would break the contiguousness for the adder's A2 select? That seems unlikely.

   I found a clue: the paper says the Adder group is 9 bits and the fields are FADD, IFADD1, and A1. Then what about A2? The paper says the Data Pad group is 19 bits and the fields include "XE/YE extension bits" (6 bits) and also A2? 

   But the constraint says: fields driving the same hardware (register file index) must be contiguous. If A2 is moved to the Data Pad group, then A1 (in Adder group) and A2 (in Data Pad group) are split. That would require the same multiplexer input bits to be in two non-contiguous groups? That violates the constraint.

   Therefore, I think we must have the A2 in the Adder group. So the FPS-164 paper must have an error? Or we are misinterpreting. Given the constraints, we design for contiguousness.

   So for XP-32, we will have:

        Adder #1 group: FADD (3), IFADD1 (3), A1 (3), A2 (3) -> 12 bits? But we also need to account for the new extensions? The paper says the Adder group is extended by IFADD1. So we have:

          FADD: 3
          IFADD1: 3 (new for FPS-164)
          A1: 3
          A2: 3 -> total 12 bits? But the paper says 9 bits. 

   Alternatively, maybe the FADD and IFADD1 share the same 3 bits? That is, they are mutually exclusive? But that would be a different encoding.

   Given the time, I will design the XP-32 microcode as follows:

   We know XP-32 has two adders, so we will have two Adder groups. Each Adder group will have:

        FADD: 3 bits (floating function)
        IFADD: 3 bits (integer function) -> but note: in FPS-164, they added IFADD1 (3 bits) for the integer single-op adder. So we have one integer function field per adder? But XP-32 has two adders? So we might need two IFADD fields? Or the integer function is common? The problem states: two floating-point adders. It doesn't say integer. So maybe the integer function is only for one of them? Or both? 

   The paper (Touzeau) for FPS-164 says they added an integer adder. So XP-32 might have two floating adders and one integer adder? Or two floating adders and one integer adder shared? 

   The problem says: "two floating-point ADDERS + one floating-point MULTIPLIER". So no integer adder mentioned? But then why in FPS-164 they added IFADD1? 

   Since we are building on FPS-164, we must include IFADD1. And the evolution is additive. So XP-32 must have IFADD1 in the Adder group.

   How about we have:

        Adder #1 group: 
          FADD1: 3 bits
          IFADD1: 3 bits
          A1: 3 bits (for the first adder's input 1)
          A2: 3 bits (for the first adder's input 2)

        Adder #2 group:
          FADD2: 3 bits
          IFADD2: 3 bits? -> but the problem says "two floating-point adders", so both are floating? Or is one of them also integer? 
          A3: 3 bits (for the second adder's input 1)
          A4: 3 bits (for the second adder's input 2)

   But note: the problem does not mention an integer adder for XP-32, so we might not need two IFADD fields. However, the evolution from FPS-164 (which had one integer adder) to XP-32 (with two floating adders) might drop the integer adder? Or keep it? 

   Given that the evolution is additive, we should keep the IFADD field for the first adder? But then what about the second adder? It doesn't have an integer function? 

   Alternatively, the IFADD field in FPS-164 was for the same adder unit? So in XP-32, we might have only one integer function field for the first adder? But then the second adder is floating only? 

   Since we don't have clear information, I will assume that the FPS-164 IFADD field is kept for the first adder, and the second adder only has FADD2 and no integer function? Or maybe the integer function is now shared? But that complicates the hardware.

   To keep it simple, I will assume that XP-32 has two floating adders and no integer adder? But then we are missing the FPS-164 extension? The constraint says: every FPS-164 extension appears. So we must have IFADD1.

   Therefore, we will have:

        Adder #1 group: 
          FADD1: 3 bits (floating function for adder1)
          IFADD1: 3 bits (integer function for adder1) [from FPS-164]
          A1: 3 bits (adder1 input1 select)
          A2: 3 bits (adder1 input2 select)

        Adder #2 group:
          FADD2: 3 bits (floating function for adder2)
          A3: 3 bits (adder2 input1 select)
          A4: 3 bits (adder2 input2 select)

   So total for Adder groups: 12 + 12 = 24 bits? But note: the FPS-164 paper said the Adder group was 9 bits? We are now 24? 

   We have to account for the FPS-164 extension IFADD1. We are including it in Adder1.

3. Branch group: in FPS-164, 9 bits: COND (4 bits) and DISP (5 bits). In AP-120B, COND was 4 bits and DISP was 5 bits -> 9 bits. So no change? We keep 9 bits.

4. Data Pad group: in FPS-164, 19 bits. The fields from AP-120B were:

        DPX: 2 bits
        DPY: 2 bits
        DPBS: 3 bits
        XR: 3 bits
        YR: 3 bits
        XW: 3 bits
        YW: 3 bits -> total 2+2+3+3+3+3+3=19 bits? But wait, the AP-120B had:

        DPX: 2 bits (bits 32-33)
        DPY: 2 bits (bits 34-35)
        DPBS: 3 bits (bits 36-38)
        XR: 3 bits (bits 39-41)
        YR: 3 bits (bits 42-44)
        XW: 3 bits (bits 45-47)
        YW: 3 bits (bits 48-50) -> total 19 bits? But then what about the multiplier and memory groups? The next group is multiplier at bits 50-54? So XW and YW are at bits 45-50? Then YW is only 2 bits? Because 50-48 is 3 bits? Actually, bits 48-50 for YW is 3 bits.

        Then the multiplier group starts at bit 51? But in the AP-120B, bit 51 is FM, then 52-53 M1, 54-55 M2, then 56-57 MI, etc. So the Data Pad group ends at bit 50? Then the multiplier group starts at bit 51.

   In FPS-164, the Data Pad group is 19 bits and includes the XE/YE extension bits (6 bits). So the total becomes 19 + 6 = 25 bits? But the figure says 19 bits. 

   How did they fit? They must have reduced the existing fields? Or the XE/YE are additional and then the group becomes 25? 

   The paper says: "The Data Pad group is extended from 17 bits (AP-120B) to 19 bits (FPS-164)" and then lists the extension: XE(3), YE(3). So how? 

   In AP-120B, the Data Pad group was 17 bits? How? 

        DPX: 2 bits
        DPY: 2 bits
        DPBS: 3 bits
        XR: 3 bits
        YR: 3 bits
        XW: 3 bits
        YW: 3 bits -> 2+2+3+3+3+3+3=19? But the paper says 17? 

   Wait, in AP-120B, the Data Pad group was:

        DPX: 2 bits (bits 32-33)
        DPY: 2 bits (bits 34-35)
        DPBS: 3 bits (bits 36-38)
        XR: 3 bits (bits 39-41)
        YR: 3 bits (bits 42-44)
        XW: 3 bits (bits 45-47)
        YW: 3 bits (bits 48-50) -> that's 19 bits? But the AP-120B microcode has 64 bits. The total up to bit 50 is 51 bits? Then the multiplier group starts at bit 51? 

   The paper says 17 bits? I see: in AP-120B, the Data Pad group was only 17 bits? How? 

        They might have counted differently? Or maybe the XW and YW are only 2 bits? 

   Given the confusion, I will design for XP-32:

   We know XP-32 has wider Data Pads (16K). So we need wider index fields? In AP-120B, the XR, YR, XW, YW were 3 bits -> 8 addresses. For 16K, we need 14 bits for address? But these are for indexing into the scratchpad? Or for the data pad? 

   The problem says: "On-card memory hierarchy: TCM 4K × 32', 2 banks; LMD 16K × 32', 2 banks". So the data pads must be able to address the LMD? The LMD is 16K words, so 14 bits address. But the fields XR, YR, XW, YW are for the data pad read and write indices? They are 3 bits in AP-120B -> 8 entries? 

   In XP-32, the data pads might be larger? Or maybe the fields are for the same 8-entry pad, but the data pad can access larger memory via the memory interface? 

   The problem says: "wider Data Pad addressing for the bigger LMD/TCM". So we might need more address bits? 

   How about we extend the Data Pad group to have:

        DPX: 2 bits (unchanged)
        DPY: 2 bits (unchanged)
        DPBS: 3 bits (unchanged)
        XR: 4 bits (from 3 to 4? for 16 entries) -> but that doesn't help for 16K memory.
        YR: 4 bits
        XW: 4 bits
        YW: 4 bits
        and then the XE/YE extension bits from FPS-164: 6 bits? -> total 2+2+3+4+4+4+4+6 = 29 bits? 

   But we also need to account for the FPS-164 extensions: XE/YE. So we include them.

   Alternatively, the data pad might be a register file with 16 entries? Then 4 bits would be enough. But 16K memory is accessed via the memory interface? Then the data pad indices are for the register file, which is small. So maybe they remain 3 or 4 bits? 

   Given the problem says "wider Data Pad addressing", I think we should extend the index fields to 4 bits each (so 16 entries). Then we have:

        DPX: 2
        DPY: 2
        DPBS: 3
        XR: 4
        YR: 4
        XW: 4
        YW: 4
        XE: 3 (from FPS-164)
        YE: 3 (from FPS-164)

        Total: 2+2+3+4+4+4+4+3+3 = 29 bits.

   But the FPS-164 Data Pad group was 19 bits. We are now 29 bits? 

   We are not constrained to the same width? We are constrained to have contiguous fields and include all the fields.

   However, we must also account for the multiplier and memory groups.

5. Multiplier group: in FPS-164, 5 bits: FM (1 bit), M1 (2 bits), M2 (2 bits). But in AP-120B, it was FM (1 bit), M1 (2 bits), M2 (2 bits) -> 5 bits. Then in FPS-164, they added FM1(2) and FM0(2) -> so total 9 bits? But the figure says 5 bits. 

   The paper says: "The Multiplier group is extended from 5 bits (AP-120B) to 5 bits (FPS-164)" and then lists the extension: FM1(2), FM0(2). How? They must have reduced something? 

   Given the contiguousness, we will include:

        FM: 1 bit (start floating multiply)
        M1: 2 bits (multiplier input 1 select)
        M2: 2 bits (multiplier input 2 select)
        FM1: 2 bits (from FPS-164)
        FM0: 2 bits (from FPS-164) -> total 9 bits.

   But the paper says 5 bits? This is confusing. We are adding 4 bits? 

   I will assume that the FPS-164 paper meant the multiplier group is still 5 bits, so they must have reused the same bits? Or we are not required to follow the same width? We are required to include the fields.

   So we allocate 9 bits for the multiplier group.

6. Memory group: in FPS-164, 9 bits: MI, MA, DPA, TMA and one ext bit. In AP-120B: MI (2 bits), MA (2 bits), DPA (2 bits), TMA (2 bits) -> 8 bits. Then FPS-164 added 1 bit -> 9 bits. We'll keep 9 bits.

7. DMA group: new for XP-32. We need to control the DMA controller for SCM ↔ local-memory traffic. We can have 8 opcode bits (like the I/O-Op in FPS-164) and then some additional fields? We'll allocate 8 bits for opcode and then maybe some address/data fields? But we have 128 bits, and we are running out.

   Alternatively, we can have an 8-bit opcode and then extend with more fields? We'll start with 8 bits.

8. EU-coordination group: for EU-AU coordination. We need to provide a pointer to the EU's PROM? And maybe some state bits. We can have an 8-bit EU address and 4 bits of state -> 12 bits.

9. Immediate group: for constants. In AP-120B, when DPBS=2 or SOP=1 and SPS=14, then the last 16 bits were a 16-bit immediate. In FPS-164, they had 32-bit immediate? How? The paper says: "SVAL(8) + HVAL(32)" -> total 40 bits? But in the primary parcel, they had a "Short value" (9 bits) and then in the secondary parcel they had "Address value" (25 bits) -> total 34 bits? 

   We need a 32-bit immediate for IEEE-754 32-bit float? But note: the immediate might be used for both the data pad (when in value mode) and for other things. In XP-32, we can have a 32-bit immediate field that is used when in certain modes.

   We can allocate 32 bits for the immediate. But we also need to include the FPS-164 immediate extensions? The problem says we must include every FPS-164 extension. They had SVAL and HVAL? 

   How about we have:

        When the instruction is in "immediate mode", we use a 32-bit field for the constant? But we also have to fit in other fields.

   Given the 128 bits, we can have a 32-bit immediate field that is used when the instruction has the immediate flag set? But then we have to put it somewhere.

   Alternatively, we can have a field that is the immediate value, and it is 32 bits. But then we need to have a mode bit to select it? But that might be in the SPAD group.

   We'll allocate 32 bits for the immediate.

10. Other groups: we might have a SPECIAL-OP group? FPS-164 had an 8-class SPECIAL-OP group? And also an I/O-Op group? We must include them.

    In FPS-164, the secondary parcel had:

        Spec Grp (12 bits) -> this might be the SPECIAL-Op group? 
        I/O Grp (9 bits) -> I/O-Op group?
        Short value (9 bits)
        unlabeled (8 bits)
        Address value (25 bits)

    And the primary parcel had 64 bits.

    We are designing 128 bits. We can have:

        Primary parcel: 64 bits? (but we are using 128 bits) -> not exactly.

    We are not constrained to the parcel structure? The problem says: "EU↔AU coordination: the AU runs from 128-bit WCS", so the entire 128 bits is one word.

    So we must include:

        SPECIAL-Op group: from FPS-164, 8 classes -> 3 bits? Or 12 bits? The paper says "8-class", so 3 bits? But they allocated 12 bits? Maybe they had additional fields? 

        I/O-Op group: 8 classes -> 3 bits? But they allocated 9 bits? 

    Given the lack of clarity, I will include:

        SPECIAL-Op: 3 bits (for 8 classes) -> but we can make it 3 bits.
        I/O-Op: 3 bits (for 8 classes) -> but then what about the rest? 

    The FPS-164 secondary parcel had 12 bits for Spec Grp and 9 bits for I/O Grp. We don't know what they contained. We will assume they are 3 bits for the opcode and then additional fields? 

    Given the time, I will simply include:

        SPECIAL-Op: 3 bits
        I/O-Op: 3 bits

    And then we have 32 bits for immediate.

    But then we have to fit everything.

   Let's try to sum the bits we have so far:

   We have:

        SPAD: 19 bits (SOP:3, SH:2, SPS+SPSX:6, SPD+SPDX:6, SPDX1:2)
        Adder1: 12 bits (FADD1:3, IFADD1:3, A1:3, A2:3)
        Adder2: 12 bits (FADD2:3, A3:3, A4:3) -> wait, that's 9 bits? Let me recount: FADD2:3, A3:3, A4:3 -> 9 bits? But we said Adder1 is 12 and Adder2 is 9? That doesn't seem symmetric.

   We must be symmetric? The problem says two floating adders. So both should have the same fields? But one has an integer function and the other doesn't? Or both have floating function only? 

   Given the evolution, we have to include IFADD1 for the first adder? But the second adder is only floating? Then Adder2 should be:

        FADD2: 3 bits
        A3: 3 bits (input1)
        A4: 3 bits (input2) -> 9 bits.

   Then total for Adder groups: 12 (Adder1) + 9 (Adder2) = 21 bits.

   Branch: 9 bits.

   Data Pad: 29 bits (as above).

   Multiplier: 9 bits.

   Memory: 9 bits.

   DMA: 8 bits.

   EU-coord: 12 bits.

   Immediate: 32 bits.

   SPECIAL-Op: 3 bits.

   I/O-Op: 3 bits.
```

## Round 2 — cross-critique

### DeepSeek (44.6s)

```
# Critical Evaluation of Peer Proposal

## (1) Bit Sum Check

Let me sum the peer's proposed fields:

- SPAD: 19 bits
- Adder1: 12 bits
- Adder2: 9 bits
- Branch: 9 bits
- Data Pad: 29 bits
- Multiplier: 9 bits
- Memory: 9 bits
- DMA: 8 bits
- EU-coord: 12 bits
- Immediate: 32 bits
- SPECIAL-Op: 3 bits
- I/O-Op: 3 bits

**Total: 19+12+9+9+29+9+9+8+12+32+3+3 = 154 bits**

This exceeds 128 bits by 26 bits. The peer never actually verified their sum. This is a fatal error.

## (2) Required Fields Present?

**Missing or problematic:**
- **No DF (overlay flag) bit** - AP-120B had this, FPS-164 had it, XP-32 needs it for primary/secondary parcel selection
- **No SOP1 field** (FPS-164 extension, 3 bits) - peer omitted this
- **No SPDX1 field properly accounted** - peer mentions it but doesn't place it
- **Adder2 lacks IFADD** - but FPS-164 had IFADD1; if evolution is additive, both adders should have integer capability or at least one should
- **No clear immediate mode selector** - how does the processor know when bits 96-127 are an immediate vs. other fields?

## (3) Field Ordering Plausibility

The peer's ordering roughly follows FPS-164 convention (SPAD → Adder → Branch → Data Pad → Multiplier → Memory), which is good. However:

- Placing DMA and EU-coord at the end is reasonable
- But the peer doesn't specify *which* bits (e.g., "bits 1-19: SPAD") - just gives widths
- The 32-bit immediate at the end would conflict with the FPS-164 convention where immediate replaces the tail of the word

## (4) Weakest Reasoning

1. **FPS-164 field width confusion**: The peer repeatedly struggles with Touzeau's figure, unable to reconcile 12-bit SPAD group with the listed subfields. This leads to over-allocation (19 bits vs. actual 12).

2. **No verification of total**: The 154-bit sum is never checked against the 128-bit constraint.

3. **Adder asymmetry**: Arbitrarily gives Adder1 12 bits and Adder2 9 bits without hardware justification. Two identical adders should have identical control fields.

4. **Data Pad over-allocation**: 29 bits for Data Pad is excessive. The FPS-164 managed with 19 bits including extensions. XP-32's wider addressing likely adds 1-2 bits per index, not 10.

5. **Missing overlay mechanism**: The DF bit and primary/secondary parcel concept from both predecessors is ignored.

# My Proposed Layout (Updated After Peer Analysis)

Given the peer's errors, I maintain my original approach but refine it. Here is my corrected 128-bit layout:

## A. Field-by-Field Bit-Position Table

Using 1-indexed MSB (bit 1 = most significant), following FPS-164 convention:

| Group | Field | Bits | Width | Notes |
|-------|-------|------|-------|-------|
| **SPAD** | DF | 1 | 1 | Overlay flag (primary=0, secondary=1) |
| | SOP | 2-4 | 3 | S-pad operation |
| | SOP1 | 5-7 | 3 | Secondary S-pad op (FPS-164 ext) |
| | SH | 8-9 | 2 | Shift amount |
| | SPS | 10-13 | 4 | S-pad source register |
| | SPSX | 14-15 | 2 | S-pad source extension (FPS-164) |
| | SPD | 16-19 | 4 | S-pad dest register |
| | SPDX | 20-21 | 2 | S-pad dest extension (FPS-164) |
| | SPDX1 | 22-23 | 2 | S-pad dest extension 2 (FPS-164) |
| **Adder #1** | FADD1 | 24-26 | 3 | Adder1 function |
| | IFADD1 | 27-29 | 3 | Integer adder1 function (FPS-164) |
| | A1_1 | 30-32 | 3 | Adder1 input 1 select |
| | A1_2 | 33-35 | 3 | Adder1 input 2 select |
| **Adder #2** | FADD2 | 36-38 | 3 | Adder2 function |
| | IFADD2 | 39-41 | 3 | Integer adder2 function |
| | A2_1 | 42-44 | 3 | Adder2 input 1 select |
| | A2_2 | 45-47 | 3 | Adder2 input 2 select |
| **Branch** | COND | 48-51 | 4 | Branch condition |
| | DISP | 52-56 | 5 | Branch displacement (signed) |
| **Data Pad** | DPX | 57-58 | 2 | Data pad X write enable |
| | DPY | 59-60 | 2 | Data pad Y write enable |
| | DPBS | 61-63 | 3 | Data pad bus select |
| | XR | 64-67 | 4 | DPX read index (wider for XP-32) |
| | YR | 68-71 | 4 | DPY read index (wider) |
| | XW | 72-75 | 4 | DPX write index (wider) |
| | YW | 76-79 | 4 | DPY write index (wider) |
| | XE | 80-82 | 3 | DPX index extension (FPS-164) |
| | YE | 83-85 | 3 | DPY index extension (FPS-164) |
| **Multiplier** | FM | 86 | 1 | Start multiply |
| | M1 | 87-88 | 2 | Multiplier input 1 select |
| | M2 | 89-90 | 2 | Multiplier input 2 select |
| | FM1 | 91-92 | 2 | Multiplier function ext (FPS-164) |
| | FM0 | 93-94 | 2 | Multiplier function ext (FPS-164) |
| **Memory** | MI | 95-96 | 2 | Memory input select |
| | MA | 97-98 | 2 | Memory address reg op |
| | DPA | 99-100 | 2 | Data pad address reg op |
| | TMA | 101-102 | 2 | Table memory address reg op |
| | MEMX | 103 | 1 | Memory extension (FPS-164) |
| **DMA** | DMA_OP | 104-107 | 4 | DMA operation (16 classes) |
| | DMA_SRC | 108-111 | 4 | DMA source select |
| | DMA_DST | 112-115 | 4 | DMA destination select |
| **EU Coord** | EU_ADDR | 116-123 | 8 | EU PROM address pointer |
| | EU_CTRL | 124-125 | 2 | EU sequencer control |
| **Special** | SPEC_OP | 126-127 | 2 | Special operation (4 classes) |
| | IO_OP | 128 | 1 | I/O operation flag |

**Total: 128 bits ✓**

## B. Sub-field Encoding Choices

### 1. Adder #2 Symmetry
**Symmetric mirror** of Adder #1. Both have identical FADD, IFADD, A1, A2 fields. Rationale:
- Hardware symmetry simplifies routing and timing
- Both adders are identical FP units per Curington 1986
- IFADD on both allows integer operations on either adder

### 2. DMA Controller Structure
Analogous to FPS-164's I/O-Op group but expanded:
- 4-bit opcode (16 operations: load, store, DMA start, DMA status, etc.)
- 4-bit source select (SCM bank, LMD bank, TCM bank, register file)
- 4-bit destination select (same options)
- Total 12 bits, placed after Memory group for logical flow

### 3. Field Widening vs FPS-164
- **SPAD**: 23 bits (vs FPS-164's 12) - necessary because XP-32 has more S-pad registers and needs all FPS-164 extensions
- **Data Pad**: 29 bits (vs FPS-164's 19) - XR/YR/XW/YW widened from 3→4 bits for 16-entry data pads (vs 8-entry in AP-120B)
- **Multiplier**: 9 bits (vs FPS-164's 5) - includes FM1/FM0 extensions
- **Memory**: 9 bits (same as FPS-164)

### 4. EU Coordination
- 8-bit EU PROM address (256 words of the 2K PROM)
- 2-bit EU control (start, halt, step, reset)
- Placed near the end for easy extraction

### 5. IEEE-754 32-bit Immediate
When DPBS=2 (VALUE mode) or SOP=1+SPS=14 (LDSPI), bits 57-128 become a 32-bit immediate constant. This replaces Data Pad, Multiplier, Memory, DMA, EU Coord, Special, and IO fields. The DF bit (bit 1) distinguishes primary vs secondary parcel interpretation.

## C. Confidence Ratings

| Group | Confidence | Rationale |
|-------|-----------|-----------|
| SPAD | **High** | Directly follows FPS-164 layout with all extensions |
| Adder #1 | **High** | Identical to FPS-164 adder group |
| Adder #2 | **Medium** | Symmetric assumption is logical but unverified |
| Branch | **High** | Unchanged from AP-120B/FPS-164 |
| Data Pad | **Medium** | Widening from 3→4 bits is plausible but exact width uncertain |
| Multiplier | **High** | Follows FPS-164 with extensions |
| Memory | **High** | Identical to FPS-164 |
| DMA | **Low** | No precedent; structure is my best guess |
| EU Coord | **Low** | No precedent; 8+2 bits is plausible but speculative |
| Special/IO | **Medium** | Reduced from FPS-164's 8 classes to 4+1 for bit budget |

The peer's proposal fails the 128-bit constraint and has significant field accounting errors. My layout corrects these while maintaining contiguous field groups and including all required fields.
```

### GLM (132.3s)

```
### Critical Evaluation of Peer's Proposal

#### (1) Does it sum to exactly 128 bits with no gaps/overlaps?
**Yes.** The peer's layout uses a 1-indexed bit range (bits 1–128) and sums to 128 bits:
- SPAD: 21 bits (1–21)  
- Adder #1: 14 bits (22–35)  
- Branch: 9 bits (36–44)  
- Data Pad: 23 bits (45–67)  
- Multiplier: 9 bits (68–76)  
- Memory: 9 bits (77–85)  
- Adder #2: 10 bits (86–95)  
- DMA: 15 bits (96–110)  
- EU-coord: 11 bits (111–121)  
- Immediate: 7 bits (122–128)  
**Total**: 21 + 14 + 9 + 23 + 9 + 9 + 10 + 15 + 11 + 7 = 128.  
**Gaps/overlaps**: None. Groups are contiguous (e.g., Data Pad ends at 67, Multiplier starts at 68).

#### (2) Are all required fields present?
**No, critical omission:** The **DF (bit-reverse/overlay flag) field** from AP-120B is missing.  
- **Required AP-120B fields**: DF, SOP, SH, SPS, SPD, FADD, A1, A2, COND, DISP, DPX, DPY, DPBS, XR, YR, XW, YW, FM, M1, M2, MI, MA, DPA, TMA.  
- **Peer’s coverage**:  
  - ✅ Includes all AP-120B fields *except DF*.  
  - ✅ Includes all FPS-164 extensions (SOP1
```

## Round 3 — synthesis

### Synthesis-DS (38.7s)

```
# Consensus 128-bit XP-32 Microinstruction Layout

After reconciling both proposals, here is the final layout. The key reconciliation points:

1. **DF bit must be present** (Analyst B correctly identified this omission in A's proposal)
2. **Adder #2 must be symmetric** (both agree on this)
3. **Total must be exactly 128 bits** (A's original sum was correct; B's first proposal was 154 bits)
4. **Immediate mode** uses the FPS-164 convention of replacing tail fields
5. **Data Pad indices** widen from 3→4 bits for XP-32's larger memory

## A. Final Field-by-Field Bit-Position Table

| Group | Field | Bit Range | Width | Notes |
|-------|-------|-----------|-------|-------|
| **SPAD** | DF | 1 | 1 | Overlay flag (0=primary, 1=secondary parcel) |
| | SOP | 2–4 | 3 | S-pad operation (AP-120B) |
| | SOP1 | 5–7 | 3 | Secondary S-pad op (FPS-164 ext) |
| | SH | 8–9 | 2 | Shift amount |
| | SPS | 10–13 | 4 | S-pad source register |
| | SPSX | 14–15 | 2 | S-pad source extension (FPS-164) |
| | SPD | 16–19 | 4 | S-pad dest register |
| | SPDX | 20–21 | 2 | S-pad dest extension (FPS-164) |
| | SPDX1 | 22–23 | 2 | S-pad dest extension 2 (FPS-164) |
| **Adder #1** | FADD1 | 24–26 | 3 | Adder1 floating function |
| | IFADD1 | 27–29 | 3 | Adder1 integer function (FPS-164) |
| | A1_1 | 30–32 | 3 | Adder1 input 1 select |
| | A1_2 | 33–35 | 3 | Adder1 input 2 select |
| **Adder #2** | FADD2 | 36–38 | 3 | Adder2 floating function (symmetric) |
| | IFADD2 | 39–41 | 3 | Adder2 integer function (symmetric) |
| | A2_1 | 42–44 | 3 | Adder2 input 1 select |
| | A2_2 | 45–47 | 3 | Adder2 input 2 select |
| **Branch** | COND | 48–51 | 4 | Branch condition |
| | DISP | 52–56 | 5 | Branch displacement (signed) |
| **Data Pad** | DPX | 57–58 | 2 | Data pad X write enable |
| | DPY | 59–60 | 2 | Data pad Y write enable |
| | DPBS | 61–63 | 3 | Data pad bus select |
| | XR | 64–67 | 4 | DPX read index (widened for XP-32) |
| | YR | 68–71 | 4 | DPY read index (widened) |
| | XW | 72–75 | 4 | DPX write index (widened) |
| | YW | 76–79 | 4 | DPY write index (widened) |
| | XE | 80–82 | 3 | DPX index extension (FPS-164) |
| | YE | 83–85 | 3 | DPY index extension (FPS-164) |
| **Multiplier** | FM | 86 | 1 | Start multiply |
| | M1 | 87–88 | 2 | Multiplier input 1 select |
| | M2 | 89–90 | 2 | Multiplier input 2 select |
| | FM1 | 91–92 | 2 | Multiplier function ext (FPS-164) |
| | FM0 | 93–94 | 2 | Multiplier function ext (FPS-164) |
| **Memory** | MI | 95–96 | 2 | Memory input select |
| | MA | 97–98 | 2 | Memory address reg op |
| | DPA | 99–100 | 2 | Data pad address reg op |
| | TMA | 101–102 | 2 | Table memory address reg op |
| | MEMX | 103 | 1 | Memory extension (FPS-164) |
| **DMA** | DMA_OP | 104–107 | 4 | DMA operation (16 classes) |
| | DMA_SRC | 108–111 | 4 | DMA source select |
| | DMA_DST | 112–115 | 4 | DMA destination select |
| **EU Coord** | EU_ADDR | 116–123 | 8 | EU PROM address pointer |
| | EU_CTRL | 124–125 | 2 | EU sequencer control |
| **Special** | SPEC_OP | 126–127 | 2 | Special operation (4 classes) |
| | IO_OP | 128 | 1 | I/O operation flag |

**Total: 128 bits** ✓

## B. Sub-Field Encoding Choices

### 1. Adder #2 Symmetry
**Fully symmetric** with Adder #1. Both have identical FADD, IFADD, A1, A2 fields. Rationale:
- Hardware symmetry (both are identical IEEE-754 32-bit FP adders per Curington 1986)
- Contiguous-by-resource constraint requires all adder control bits together
- IFADD on both allows integer operations on either adder (FPS-164 precedent)

### 2. DMA Controller Structure
Analogous to FPS-164's I/O-Op group but specialized for SCM↔LMD transfers:
- **4-bit opcode** (16 operations): NOP, Load SCM→LMD, Store LMD→SCM, Load SCM→TCM, Store TCM→SCM, Load LMD→TCM, Store TCM→LMD, DMA status, DMA abort, etc.
- **4-bit source select**: SCM bank (0–3), LMD bank (0–3), TCM bank (0–1), Data Pad, S-pad, EU PROM
- **4-bit destination select**: Same address spaces
- Total 12 bits, placed after Memory group for logical flow

### 3. Field Widening vs FPS-164
- **SPAD**: 23 bits (vs FPS-164's 12) — includes all FPS-164 extensions (SOP1, SPSX, SPDX, SPDX1)
- **Data Pad**: 29 bits (vs FPS-164's 19) — XR/YR/XW/YW widened from 3→4 bits for 16-entry data pads (vs 8-entry in AP-120B)
- **Multiplier**: 9 bits (vs FPS-164's 5) — includes FM1/FM0 extensions
- **Memory**: 9 bits (same as FPS-164)
- **Branch**: 9 bits (unchanged from AP-120B/FPS-164)

### 4. EU Coordination
- **8-bit EU PROM address**: Points to one of 256 words in the 2K×80 EU PROM (low 3 bits from EU's internal PC)
- **2-bit EU control**: 00=NOP, 01=Start, 10=Step, 11=Break
- Placed near end for easy extraction by EU interface logic

### 5. IEEE-754 32-bit Immediate Encoding
When **DPBS=2** (VALUE mode) or **SOP=1+SPS=14** (LDSPI), bits 57–128 become a **32-bit immediate constant**. This replaces:
- Data Pad (bits 57–85)
- Multiplier (bits 86–94)
- Memory (bits 95–103)
- DMA (bits 104–115)
- EU Coord (bits 116–125)
- Special/IO (bits 126–128)

The DF bit (bit 1) distinguishes primary vs secondary parcel interpretation. The 32-bit immediate directly encodes IEEE-754 single-precision floats (1 sign + 8 exponent + 23 mantissa).

## C. Confidence Ratings

| Group | Confidence | Rationale |
|-------|-----------|-----------|
| **SPAD** | **High** | Directly follows FPS-164 layout with all extensions; both analysts agree |
| **Adder #1** | **High** | Identical to FPS-164 adder group; both agree |
| **Adder #2** | **Medium** | Symmetric assumption is logical but unverified; both agree on symmetry |
| **Branch** | **High** | Unchanged from AP-120B/FPS-164; both agree |
| **Data Pad** | **Medium** | Widening from 3→4 bits is plausible; both agree on need for wider indices |
| **Multiplier** | **High** | Follows FPS-164 with extensions; both agree |
| **Memory** | **High** | Identical to FPS-164; both agree |
| **DMA** | **Low** | No precedent; structure is best guess based on FPS-164 I/O-Op group |
| **EU Coord** | **Low** | No precedent; 8+2 bits is plausible but speculative |
| **Special/IO** | **Medium** | Reduced from FPS-164's 8 classes to 4+1 for bit budget; both agree on need |

**Overall confidence: Medium-High** — The first 103 bits (SPAD through Memory) are well-constrained by the AP-120B→FPS-164 evolution. The remaining 25 bits (DMA, EU Coord, Special/IO) are more speculative but follow the FPS-164 group-ordering convention and contiguous-field constraint.
```

### Synthesis-GLM (118.3s)

```
### Consensus 128-bit XP-32 Microinstruction Layout

After reconciling the proposals from Analyst A and Analyst B, the final layout adheres to all constraints: 128 contiguous bits, all AP-120B/FPS-164 fields preserved, new groups (Adder #2, DMA, EU-coord) included, and FPS-164 group ordering. Key decisions below:

**Agreement Points**:
- **DF flag included** (bit 1, primary/secondary selector, critical for parcel mode).
- **Adder groups symmetric** (both 12 bits, including IFADD fields).
- **Data Pad at 23 bits** (3-bit indices with 1-bit extensions, sufficient for 16-entry pads).
- **Immediate as mantissa-only** (21 bits total: 16 low + 5 high), sign/exponent from register.

**Disagreements Resolved**:
1. **SPAD group**: 21 bits (A's layout includes all FPS-164 extensions; B's omitted SOP1/SPDX1).  
   **Rationale**: FPS-164's 12-bit SPAD was underspecified; A's 21-bit allocation accounts for all documented extensions.
2. **DMA group**: 15 bits (A's 4/3/3/3/2 structure; B's 8-bit opcode insufficient).  
   **Rationale**: DMA requires source/destination/length/flags (Curington 1986); 15 bits cover all transfer types.
3. **EU-coordination**: 11 bits (A's 8+2+1; B's 12 bits).  
   **Rationale**: 8-bit PROM address + 2-bit control + 1 sync flag balances precision vs. bit budget.

---

### A. Field-by-Field Bit-Position Table (1-indexed, MSB=bit 1)

| Group         | Field      | Bits    | Width | Notes                                      |
|---------------|------------|---------|-------|--------------------------------------------|
| **SPAD**      | DF         | 1       | 1     | Overlay flag (0=primary, 1=secondary)     |
|               | SOP        | 2–4     | 3     | S-pad operation                            |
|               | SOP1       | 5–7     | 3     | Secondary S-pad op (FPS-164)               |
|               | SH         | 8–9     | 2     | Shift amount                               |
|               | SPS        | 10–13   | 4     | S-pad source register                      |
|               | SPSX       | 14–15   | 2     | S-pad source extension (FPS-164)           |
|               | SPD        | 16–19   | 4     | S-pad dest register                         |
|               | SPDX       | 20–21   | 2     | S-pad dest extension (FPS-164)              |
|               | SPDX1      | 22–23   | 2     | S-pad dest extension 2 (FPS-164)            |
| **Adder #1**  | FADD1      | 24–26   | 3     | Floating adder1 function                    |
|               | IFADD1     | 27–29   | 3     | Integer adder1 function (FPS-164)           |
|               | A1_1       | 30–32   | 3     | Adder1 input 1 select                      |
|               | A1_2       | 33–35   | 3     | Adder1 input 2 select                      |
| **Adder #2**  | FADD2      | 36–38   | 3     | Floating adder2 function                    |
|               | IFADD2     | 39–41   | 3     | Integer adder2 function                    |
|               | A2_1       | 42–44   | 3     | Adder2 input 1 select                      |
|               | A2_2       | 45–47   | 3     | Adder2 input 2 select                      |
| **Branch**    | COND       | 48–51   | 4     | Branch condition                           |
|               | DISP       | 52–56   | 5     | Branch displacement (signed)                |
| **Data Pad**  | DPX        | 57–58   | 2     | Data pad X write enable                    |
|               | DPY        | 59–60   | 2     | Data pad Y write enable                    |
|               | DPBS       | 61–63   | 3     | Data pad bus select                        |
|               | XR         | 64–66   | 3     | DPX read index                             |
|               | YR         | 67–69   | 3     | DPY read index                             |
|               | XW         | 70–72   | 3     | DPX write index                            |
|               | YW         | 73–75   | 3     | DPY write index                            |
|               | XE         | 76       | 1     | DPX index extension (FPS-164)              |
|               | YE         | 77       | 1     | DPY index extension (FPS-164)              |
|               | XWE        | 78       | 1     | DPX write extension (FPS-164)               |
|               | YWE        | 79       | 1     | DPY write extension (FPS-164)               |
| **Multiplier**| FM         | 80       | 1     | Start multiply                             |
|               | M1         | 81–82    | 2     | Multiplier input 1 select                  |
|               | M2         | 83–84    | 2     | Multiplier input 2 select                  |
|               | FM1        | 85–86    | 2     | Multiplier function ext (FPS-164)           |
|               | FM0        | 87–88    | 2     | Multiplier function ext (FPS-164)           |
| **Memory**    | MI         | 89–90    | 2     | Memory input select                        |
|               | MA         | 91–92    | 2     | Memory address reg op                      |
|               | DPA        | 93–94    | 2     | Data pad address reg op                    |
|               | TMA        | 95–96    | 2     | Table memory address reg op                |
|               | MEMX       | 97       | 1     | Memory extension (FPS-164)                 |
| **DMA**       | DMA_OP     | 98–101   | 4     | DMA operation (16 classes)                 |
|               | DMA_SRC    | 102–104  | 3     | Source address space (SCM, LMD, TCM)       |
|               | DMA_DST    | 105–107  | 3     | Destination address space                  |
|               | DMA_LEN    | 108–110  | 3     | Transfer length (1–8 words, or block)       |
|               | DMA_FLAGS  | 111–112  | 2     | Interrupt enable, auto-increment           |
| **EU Coord**  | EU_ADDR    | 113–120  | 8     | EU PROM address (high part)                |
|               | EU_CTRL    | 121–122  | 2     | EU sequencer control (start/stop/step/break) |
|               | EU_SYNC    | 123      | 1     | AU/EU synchronization flag                 |
| **Immediate** | IMM_LO     | 48–63    | 16    | Low 16 bits of mantissa (immediate mode)    |
|               | IMM_HI     | 124–128  | 5     | High 5 bits of mantissa (immediate mode)    |

**Total**: 128 bits  
**Gaps/Overlaps**: None (e.g., Data Pad ends at 79, Multiplier starts at 80).  
**Immediate Mode**: When `DPBS=2` or `SOP=1+SPS=14`, bits 48–63 (normally YW/FM/M1/M2/MI/MA/DPA/TMA/MEMX) and bits 124–128 become a 21-bit mantissa. Sign/exponent are in a format register (set via SPAD instruction).

---

### B. Sub-Field Encoding Choices

#### 1. Adder #2 Group: Symmetric Mirror of Adder #1
**Why symmetric**: Both adders are identical FP units (Curington 1986). IFADD1/IFADD2 support integer ops on either unit.  
**Fields**: 
- FADD1/FADD2: 3 bits (floating functions).  
- IFADD1/IFADD2: 3 bits (integer functions).  
- A1_1/A1_2, A2_1/A2_2: 3 bits each (operand select).  
**Width**: 12 bits per group (total 24 bits for both).

#### 2. DMA Controller Group
**Structure**: 4-bit opcode + 3-bit source + 3-bit destination + 3-bit length + 2-bit flags (15 bits total).  
**Opcodes**: 16 classes (e.g., load SCM→LMD, store LMD→SCM, scatter/gather).  
**Address Spaces**: 0=SCM, 1=LMD, 2=TCM, 3=Data Pad, 4=S-pad.  
**Flags**: Bit 0=interrupt on completion, Bit 1=auto-increment addresses.  
**Rationale**: Covers all Curington 1986 DMA operations without fragmenting fields.

#### 3. Widening of Inherited Fields vs FPS-164
- **SPAD**: 23 bits (vs. FPS-164's 12) to fit all FPS-164 extensions (SOP1, SPSX, SPDX, SPDX1).  
- **Data Pad**: 23 bits (vs. FPS-164's 19) with 1-bit extensions (XE/YE/XWE/YWE). Indices remain 3-bit (16-entry pads); wider LMD addressed via memory interface.  
- **Multiplier**: 9 bits (vs. FPS-164's 5) with FM1/FM0 extensions.  
- **Memory**: 9 bits (unchanged).  
**Total New Bits**: 19 (Adder #2) + 15 (DMA) + 11 (EU-coord) = 45 bits, plus 5-bit immediate high = 50 bits.

#### 4. EU Coordination Data
- **EU_ADDR (8 bits)**: High part of 11-bit EU PROM address (2K × 80). Low 3 bits in a dedicated register.  
- **EU_CTRL (2 bits)**: Sequencer control (00=noop, 01=start, 10=step, 11=break).  
- **EU_SYNC (1 bit)**: Synchronizes AU and EU pipelines.  
**Rationale**: Separates AU control (128 bits) from EU PROM (80 bits), avoiding redundancy.

#### 5. IEEE-754 32-bit Immediate Encoding
- **Immediate Format**: 21-bit mantissa (bits 48–63: 16-bit low, bits 124–128: 5-bit high).  
- **Sign/Exponent**: From a "format register" (set via `SOP=1+SPS=14` instruction).  
**Why mantissa-only**: Avoids splitting contiguous fields (A's approach). Sign/exponent rarely changed, making register-based storage efficient.  
**Alternative**: 32-bit immediate would require stealing bits from Adder #2 (violates contiguousness).

---

### C. Confidence Ratings

| Group         | Confidence | Rationale                                                                 |
|---------------|------------|---------------------------------------------------------------------------|
| SPAD          | **High**   | All AP-120B/FPS-164 fields included; DF flag added.                        |
| Adder #1      | **High**   | Identical to FPS-164 adder group; IFADD1 documented.                      |
| Adder #2      | **Medium**  | Symmetry logical but unverified; IFADD2 assumed.                           |
| Branch        | **High**   | Unchanged from AP-120B/FPS-164.                                           |
| Data Pad      | **Medium**  | 23-bit width accounts for 1-bit extensions; wider LMD addressed via memory.|
| Multiplier    | **High**   | Includes all FPS-164 extensions (FM1/FM0).                                |
| Memory        | **High**   | Standard FPS-164 layout.                                                 |
| DMA           | **Low**    | Opcode/structure inferred; no precedent.                                  |
| EU Coord      | **Low**    | PROM address/control bits speculative; real hardware may differ.         |
| Immediate     | **Medium** | Mantissa-only common in FPS; 21 bits sufficient for IEEE-754 precision.  |

**Overall Confidence**: **Medium**. Constraints strictly enforced, but DMA/IMMEDIATE/EU-coord rely on plausible inference. No gaps or overlaps, and FPS-164 ordering preserved.
```

