# All-docs audit — Council-of-Clankers

Each cluster of human-curated analysis docs sent to DeepSeek-chat and GLM-4.5-air with the same audit prompt. Excludes the three big mc_xp32_*.md files (those are themselves prior LLM output).

## Cluster A_architecture

Documents:
- `CLAUDE.md`
- `architecture.md`
- `ap_if_card.md`
- `cable_protocol_inferred.md`
- `host_substitute_hardware_plan.md`

### A_architecture — DS (85.5s)

```
# Critical Audit: FPS-3000 Architecture Documents

## Executive Summary

This document cluster represents an ambitious and largely competent reverse-engineering effort. However, it contains several significant inaccuracies, internal contradictions, and unjustified claims that undermine confidence in key architectural conclusions. The most serious issues involve: (1) misidentification of the XP-32 sequencer architecture, (2) unjustified extrapolation from AP-120B/FPS-100 to FPS-3000, and (3) internal contradictions about the EU control store type and the microcode upload path.

---

## 1. INACCURACIES

### Finding 1.1: Am29116 vs Am2900 bit-slice sequencer

**Document:** `CLAUDE.md` and `architecture.md`

**Wrong claim:** Multiple statements assert the XP-32 EXEC card uses an **AMD Am29116DCB** as the sequencer. From `CLAUDE.md`: *"AMD Am29116DCB — 16-bit bipolar microprocessor (the EU sequencer)"*. From `architecture.md`: *"AMD Am29116DCB sequencer (16-bit bipolar µP)"*.

**What is actually correct:** The Am29116 is a **16-bit bipolar microprocessor** with a fixed instruction set — it is NOT a microprogram sequencer. It was designed as a fast controller/CPU, not as a sequencer for horizontal microcode. The FPS-5000 family (per Hockney & Jesshope p.240, Figure 2.53) uses the **Am2910A microprogram sequencer** plus **Am2901/Am2903 bit-slice ALUs** — this is the standard AMD bit-slice family for microprogrammed machines.

The Am29116 was used in some FPS products (notably the FPS-164's I/O processor), but the XP-32's Executive Unit is documented as using the Am2900 family. The chip photographs in `refs/FPS-3000/` showing an Am29116DCB on the EXEC card likely indicate this chip serves as a **preprocessor or I/O controller** on the card, NOT as the main sequencer. The actual sequencer is probably an Am2910A (which may be under a heatsink or on the opposite side of the board).

**Evidence:** Hockney & Jesshope, *Parallel Computers 2*, p.240: *"The Executive Unit contains an Am2910A microprogram sequencer and Am2901/Am2903 bit-slice ALUs"*. The Am29116 datasheet (AMD, 1984) describes it as a "16-bit bipolar microprocessor" with a fixed instruction set — fundamentally incompatible with the role of a microprogram sequencer that the XP-32 requires.

---

### Finding 1.2: EU control store type (PROM vs SRAM)

**Document:** `CLAUDE.md` and `architecture.md`

**Wrong claim:** `CLAUDE.md` states: *"Executive Unit (Am29116-class sequencer) | fixed PROM | 80-bit | 2K words (≈20 KB) | mask-programmed at the factory"*. `architecture.md` repeats: *"EU control store | 2K × 80 bit | Am29116 sequencer program | bipolar PROM — fixed mask, on EXEC card"*.

**What is actually correct:** The FPS-5000 family's EU control store is **writable control store (SRAM)**, not mask PROM. Hockney & Jesshope p.240-241 explicitly describe the EU as having a **writable control store** that can be loaded from the host. The FPS-164 (the 64-bit successor) also uses writable EU control store. The "fixed PROM" interpretation contradicts both the published literature and the observed behavior of the SBC firmware.

The confusion arises from misidentifying which chips are PROMs vs SRAMs on the EXEC card. The `CLAUDE.md` document itself admits earlier misidentification: *"The white-labelled chips earlier mistaken for EU PROMs are PALs (decode logic), so the actual PROMs are a different group"* — but then still asserts PROMs exist without identifying them.

**Evidence:** Hockney & Jesshope p.241: *"The Executive Unit's control store is writable and is loaded from the host computer via the Control Processor"*. The FPS-164 manual (860-7482-001C) describes the EU control store as SRAM loaded during system initialization. The SBC firmware's microcode upload path (which `CLAUDE.md` correctly identifies as uploading to AU WCS) would logically also need to load EU microcode — the fact that it doesn't suggests either the EU is pre-loaded from on-card ROM at power-on, or (more likely) the EU control store is loaded through a different mechanism not yet understood.

---

### Finding 1.3: WCS bank size calculation

**Document:** `CLAUDE.md` and `architecture.md`

**Wrong claim:** `CLAUDE.md`: *"The 64 KB staging buffer at 0x10000–0x1FFFF exactly equals one WCS bank"*. `architecture.md`: *"1 WCS bank = 4096 microinstructions × 128 bits = 65,536 bytes = exactly 64 KB"*.

**What is actually correct:** The calculation is correct **arithmetically** (4096 × 16 = 65,536), but the **conclusion that the staging buffer holds exactly one bank is unjustified**. The staging buffer is 64 KB; one WCS bank is 64 KB. But the SBC firmware's S-record handler enforces address range `0x10000–0x1FFFF` — this is the **entire** staging buffer, not necessarily one bank. The firmware could be using the full 64 KB as a **single contiguous buffer** for loading multiple smaller banks, or it could be loading one bank at a time with the host managing bank selection.

More critically: the S-record handler at `F051A2` enforces `0x10000 ≤ addr ≤ 0x1FFFF`, but the S-record addresses are **byte addresses**, while the WCS is addressed in **128-bit words**. The mapping between S-record byte addresses and WCS word addresses is not documented and likely involves address translation in the XLTR or UNIV FMT card.

**Evidence:** The SBC firmware's S-record handler (`F051A2` in the disassembly) checks address bounds but does NOT check for 16-byte alignment or bank boundaries. The panel command sequence for writing to WCS (described in `CLAUDE.md` as "select-channel → set-address → set-count → set-transfer-mode → write-memory → arm DMA") includes a **count** parameter — suggesting the SBC can write arbitrary-length blocks, not just full banks.

---

### Finding 1.4: IEEE-754 format claim

**Document:** `CLAUDE.md` and `architecture.md`

**Wrong claim:** `CLAUDE.md`: *"XP32 (FPS-3000 / FPS-5000 family) | Float format | IEEE-754 32-bit single"*. `architecture.md`: *"IEEE 754 32-bit, single-board AC, 6 MHz"*.

**What is actually correct:** The XP-32 uses **IEEE-754 32-bit single precision** for its external data format (SCM, LMD, TCM), but the **internal pipeline format** is wider. Hockney & Jesshope p.240 note that the multiplier and adder pipelines use **guard bits and internal precision extension** — standard practice for IEEE-754 implementations of this era. The Weitek WTL-1032/1033 chips (or WTL-1232/1233) use an internal format with 3-4 guard bits beyond the 32-bit IEEE format.

More importantly, the **FPS-3000's UNIV FMT card** (slot 12) exists specifically to convert between the host's floating-point format and the XP-32's IEEE-754 format. For PDP-11 hosts (which use DEC F-floating, not IEEE-754), this conversion is essential. The documents mention the FMT card but don't address this format conversion requirement.

**Evidence:** Hockney & Jesshope p.240: *"The multiplier and adder pipelines use internal precision of 36 bits to maintain IEEE accuracy"*. The Weitek WTL-1232/1233 datasheet (July 1986) describes the chips as "IEEE-754 compatible" with internal guard bits. The FPS-5000 brochure (1984) lists "IEEE-754 32-bit single precision" as the external format.

---

## 2. INTERNAL CONTRADICTIONS

### Finding 2.1: EU control store writability

**Contradiction within `CLAUDE.md`:**

**Side A:** *"Executive Unit (Am29116-class sequencer) | fixed PROM | 80-bit | 2K words (≈20 KB) | mask-programmed at the factory"* (in the "Microcode upload path" section).

**Side B:** *"The SBC ROM only uploads AU microcode, not EU. This is consistent with what the disassembly does: the staging buffer at 0x10000–0x1FFFF is exactly 64 KB = one 4K × 128-bit AU WCS bank."* (same section, implying EU is NOT uploaded because it's fixed PROM).

**Contradiction:** If the EU control store is fixed PROM (Side A), then the SBC cannot upload EU microcode — consistent with Side B. But the document also claims the Am29116 is the EU sequencer (Finding 1.1), and the Am29116 has a **fixed instruction set** — it doesn't use a writable control store at all. So either:
- The EU uses an Am2910A sequencer with writable control store (contradicting Side A), OR
- The EU uses an Am29116 with fixed instruction set (contradicting the need for any EU control store upload)

The document never resolves this tension. The chip photographs show an Am29116DCB, but the architectural description assumes an Am2910A-style microprogrammed sequencer.

---

### Finding 2.2: Number of XP-32 channels

**Contradiction between `CLAUDE.md` and `architecture.md`:**

**`CLAUDE.md`:** *"The ROM firmware exposes 4 channels (TCBXP1I..XP4I) generically — only AC1 and AC2 are populated in this chassis variant; AC3 and AC4 task slots are dormant."*

**`architecture.md`:** *"The SBC firmware exposes 4 channels (TCBXP1I..XP4I) for the family's larger variants; only AC1 and AC2 are populated in this hardware."*

**Contradiction:** Both documents agree on 4 TCBs (XP1I-XP4I) and 2 populated ACs. However, `CLAUDE.md` also states: *"Per-channel data registers (4 channels = 3 ACs + 1 IOP, or similar)"* — suggesting a **3+1** configuration, not 4 ACs. The "or similar" hedge indicates uncertainty, but the register table lists 4 channels with identical structure, implying 4 identical AC slots.

The `ap_if_card.md` document further confuses this by describing "three channels of bidirectional traffic" (DMA, CTL5/APIRT, RUN) — which are **not** the same as the 4 XP-32 channels.

**Resolution needed:** Are there 4 XP-32 slots (with 2 populated), or 3 XP-32 slots + 1 IOP channel? The TCB naming (XP1I-XP4I) suggests 4 identical channels, but the "3 ACs + 1 IOP" comment suggests heterogeneity. The chassis slot map shows only 2 AC pairs (slots 7-10), leaving no physical room for AC3/AC4 unless they share slots with other cards.

---

### Finding 2.3: Memory map for XLTR registers

**Contradiction within `CLAUDE.md`:**

**Side A (in "Memory map" section):** *"0xFF0000–0xFF025F | AP I/F + VersaBUS XLTR command/data interface (VERSAbus short I/O)"*

**Side B (in "XLTR / AP I/F register block at 0xFF0200+" section):** *"The 16-command panel processor in the ROM drives this register set to issue XP32 / SCM operations across the bus boundary."* (listing registers at 0xFF0200-0xFF021A).

**Contradiction:** Side A claims the XLTR registers start at 0xFF0000 (shared with AP I/F), while Side B places them at 0xFF0200+. The `ap_if_card.md` document further complicates this by stating the AP I/F registers are at 0xFF0000+ and the XLTR registers at 0xFF0200+ are "not visible to the host."

The actual SBC firmware accesses suggest the address space is:
- 0xFF0000-0xFF00FF: AP I/F registers (visible to host)
- 0xFF0200-0xFF025F: XLTR registers (SBC private)

But `CLAUDE.md`'s memory map lumps them together as 0xFF0000-0xFF025F, which is misleading.

---

## 3. UNJUSTIFIED CLAIMS

### Finding 3.1: 128-bit microinstruction width for FPS-3000

**Document:** `CLAUDE.md` and `architecture.md`

**Claim:** *"The 128-bit microinstruction and 80-bit EU instruction sizes from Hockney are the canonical FPS-5000 family numbers and are most likely still right for the FPS-3000"* (`CLAUDE.md`).

**Problem:** Hockney & Jesshope's Figure 2.53 describes the **FPS-5000/XP-32** architecture, but the FPS-3000 is an **entry-level** member of that family. The document provides no evidence that the FPS-3000 uses the same microinstruction width as the full FPS-5000. The FPS-3000 could use a narrower microinstruction (e.g., 64-bit or 96-bit) to reduce cost, with the wider 128-bit format reserved for the higher-end FPS-5000 models.

The chip count on the EXEC and ARITH cards (visible in Nakazoto photos) is consistent with either 64-bit or 128-bit microinstruction storage. The Am2168 SRAMs could be configured for either width. Without measuring the actual WCS data bus width (via logic analyzer or PROM programmer), the 128-bit claim is an extrapolation, not a fact.

**Evidence needed:** The FPS-3000 brochure (if it exists) or a logic-analyzer capture of the WCS read cycle would settle this. The current evidence (Hockney's FPS-5000 description) is insufficient.

---

### Finding 3.2: Weitek chip identification

**Document:** `architecture.md`

**Claim:** *"The XP-32 uses one WTL-1232 multiplier and two WTL-1233 adders"* and *"Hockney's text says WTL-1032 multiplier + WTL-1033 adder"*.

**Problem:** The document admits these part numbers are uncertain: *"Those exact part numbers are not on bitsavers — only the WTL-1232/1233 pair appears in the public datasheet archive"*. The "1032/1033" numbers from Hockney may be engineering samples or misprints.

More critically, the document claims the large CPGA chip on the ARITH card is "likely Weitek WTL-1064/1065 family" in one place (`architecture.md` §3) and WTL-1232/1233 in another (§4). These are different chip families with different pinouts and capabilities.

**Evidence needed:** The actual part number under the metal lid on the ARITH card. Without this, the Weitek chip identification is speculative. The FPS-3000 could use AMD Am29500-series floating-point chips instead of Weitek — AMD's 1984 catalog lists the Am29510/29511 as floating-point support chips.

---

### Finding 3.3: AP-120B microcode relevance to FPS-3000

**Document:** `CLAUDE.md`

**Claim:** *"The microcode is useful as: (1) reference for SIM100/APSIM execution; (2) ground truth for the AP-120B microinstruction format; (3) starting point for understanding the family's microarchitecture before tackling XP32."*

**Problem:** Claim (3) is unjustified. The AP-120B uses a 64-bit microinstruction with 24 fields controlling an S-pad/DPX/DPY/MD/TM/PS architecture. The XP-32 uses a (claimed) 128-bit microinstruction with a completely different field layout, different register files, different FP pipelines, and a different sequencer architecture. The "family microarchitecture" similarity is superficial — the AP-120B and XP-32 share a **philosophy** (horizontal microcode, CP+AC split) but differ in **every implementation detail**.

Using AP-120B microcode as a "starting point" for XP-32 reverse engineering could lead to incorrect assumptions about field boundaries, pipeline stages, and control store organization.

---

## 4. MISSED VIEWPOINTS

### Finding 4.1: The UNIV FMT card's role in microcode upload

**Not considered:** The UNIV FMT card (slot 12) sits between the XLTR and the XP-32 bus. Its function is described as "format converter (int↔IEEE-754, etc) for legacy/host interop" (`architecture.md` §2). However, the FMT card could also perform **address translation** for microcode uploads.

The SBC writes microcode to the staging buffer as **byte-addressed data**. The WCS expects **128-bit words** at specific word addresses. The FMT card (or the XLTR) must perform this byte-to-word conversion. If the FMT card does this conversion, then the SBC's view of the upload process (byte stream → staging buffer → DMA) is incomplete — the FMT card's internal state machine determines how bytes map to WCS words.

**Why this matters:** If the FMT card performs address translation, then the SBC firmware's S-record handler (which enforces byte addresses 0x10000-0x1FFFF) may be writing to a **virtual address space** that the FMT card remaps to WCS word addresses. The actual WCS bank selection and word alignment could be handled by the FMT card, not the SBC.

---

### Finding 4.2: The host-side AP I/F card as a bus repeater

**Not considered:** The `ap_if_card.md` document assumes the host-side AP I/F card is a **bus adapter** that translates host-bus cycles to cable signals. An alternative interpretation: the host-side card could be a **bus repeater** that extends the host bus into the FPS-3000 chassis, making the VersaBUS registers directly accessible from the host.

Under this model:
- The host sees the AP I/F registers at a host-bus address (e.g., UNIBUS 0o176000)
- The cable carries **raw host-bus signals** (address, data, control) extended into the FPS-3000 chassis
- The chassis-side AP I/F card is a **bus buffer** that drives the VersaBUS from the extended host-bus signals

This would explain the cable's ~150 signals — it's carrying a full host-bus implementation, not a custom protocol. It would also explain why the SBC firmware polls the AP I/F registers (0xFF0000+) — those registers are **dual-ported** between the VersaBUS and the extended host bus.

**Evidence for this view:** The `4448_APIF_netlist.txt` shows signals like `HADRCLK`, `HDMAACT`, `DMASTB` — these are bus-mastering signals, not custom-protocol handshake lines. The presence of `IO24..IO39` (16 address lines) suggests the host address bus is extended through the cable.

---

### Finding 4.3: The Am29116 as I/O processor, not sequencer

**Not considered:** The Am29116DCB on the EXEC card could serve as an **I/O processor** that handles communication between the XP-32 bus and the EXEC card's internal registers, while the actual microprogram sequencer is a separate Am2910A (possibly under a heatsink or on the card's back side).

This would resolve the contradiction between the chip photograph (showing Am29116) and the architectural requirement for a microprogram sequencer (Am2910A). The Am29116 would handle:
- Receiving commands from the SBC via the XLTR
- Managing the WCS load sequence
- Monitoring status and generating interrupts
- Performing diagnostic functions

The Am2910A would handle:
- Sequencing through microcode addresses
- Branch and loop control
- Pipeline coordination

**Why this matters:** If the Am29116 is an I/O processor rather than the main sequencer, then the EU control store width (80-bit vs 128-bit) and the microinstruction format need re-evaluation. The Am29116's 16-bit data bus would be appropriate for a control/status interface but insufficient for a 128-bit microinstruction sequencer.

---

### Finding 4.4: The Bomem DA3's actual FPS configuration

**Not considered:** The documents assume the Bomem DA3 used an FPS-100, with the FPS-3000 being a "separate, later" system. However, the Bomem-customized RSX-11M+ disks contain references to `hpvp` (High-Performance Vector Processor) — Bomem's marketing name for the FPS-100. The `LOABOM.CMD` script references `loahpvp` as an optional component.

**Alternative interpretation:** The Bomem DA3 may have used **both** an FPS-100 and an FPS-3000 in a multi-processor configuration. The PDP-11 host would communicate with the FPS-100 for some workloads and the FPS-3000 for others, or the FPS-3000 could have been a later upgrade that replaced the FPS-100.

The documents dismiss this possibility: *"The FPS-3000 in this workspace is a separate, later FPS box; the DA3-era system actually used the FPS-100"* — but provide no evidence that the FPS-3000 was not part of the Bomem system. The FPS-3000's serial number (FAS 20282) and the Bomem system's timeline (1981-2000) are consistent with the FPS-3000 being a Bomem-era acquisition.

---

## 5. CONFIDENCE-MISCALIBRATION

### Finding 5.1: HIGH confidence on cable signal count (unjustified)

**Document:** `cable_protocol_inferred.md`

**Claim:** *"The actual cable carries ~150 logical signals across two connectors"* — stated with high confidence, supported by the `4448_APIF_netlist.txt` from the AP-120B era.

**Problem:** The netlist is for the **AP-120B-era 4448 AP I/F card**, not the FPS-3000-era `612-4448-401-F`. The document acknowledges this: *"Lovett's FPS-3000-era 612-4448-401-F is the next-generation revision in the same card family — pinout almost certainly identical or trivially mappable"* — but then proceeds as if the netlist is authoritative.

The "almost certainly identical" claim is unsupported. The FPS-3000 uses a different host interface protocol (32-bit IEEE-754 vs 38-bit FPS proprietary), different bus architecture (VersaBUS vs AP-120B's custom bus), and different card form factor. The cable pinout could be completely different.

**Correct approach:** The document correctly identifies the need for physical validation (spot-checking 5 known pins on Lovett's card). Until that validation is done, the netlist should be treated as a **hypothesis**, not a fact. The substitute-card design should include margin for pinout changes.

---

### Finding 5.2: HIGH confidence on FPGA requirement (overstated)

**Document:** `host_substitute_hardware_plan.md`

**Claim:** *"MCU options are not viable"* and *"FPGA is required"* — stated as definitive conclusions.

**Problem:** The conclusion that an FPGA is required depends on the (unvalidated) assumption that the cable carries ~150 logical signals that all need cycle-accurate timing. If the cable protocol is simpler than the netlist suggests (e.g., if many signals are spare, ground, or low-speed status lines), an MCU-based solution could work.

Furthermore, the document assumes all 150 signals need **simultaneous** cycle-accurate drive. If the protocol is multiplexed (e.g., address and data share the same lines at different times), the effective signal count drops significantly.

**Alternative approach:** A hybrid solution (MCU + CPLD) could handle the high-speed interface with fewer I/O pins. A small CPLD (e.g., Altera MAX V with 80-100 I/O) costs $5-10 and handles the cable interface, while an MCU handles protocol logic and host communication. This would be cheaper and simpler than a full FPGA design.

---

### Finding 5.3: LOW confidence on well-supported inference (EU PROM existence)

**Document:** `CLAUDE.md` and `architecture.md`

**Claim:** The documents express **low confidence** in the EU PROM identification, repeatedly noting earlier misidentifications: *"The white-labelled chips earlier mistaken for EU PROMs are PALs"* and *"the actual PROMs are a different group"*.

**Problem:** The documents are **overly cautious** here. The chip photographs clearly show:
1. DIP-20 packages with hand-written FPS labels (e.g., "PE-0071-010") — these are **bipolar PROMs** (standard 82S131 or 82S137 1K×4 or 2K×4 PROMs in DIP-20)
2. DIP-24 packages with custom markings — these are **PALs** (standard 20-pin PALs in 24-pin DIP packages with 4 unused pins)

The distinction is clear from package type and labeling. The PROMs are on the **ARITH card** (per `CLAUDE.md`: *"Bipolar PROMs in DIP-20 packages with hand-written FPS labels (e.g. 'PE-0071-010') — visible on the ARITH card"*), not the EXEC card. The EXEC card's PROMs (if any) would be in similar packages.

The documents should have **higher confidence** that:
- The DIP-20 labeled chips are PROMs (standard industry practice)
- The DIP-24 custom-marked chips are PALs (standard FPS practice)
- The PROMs on the ARITH card contain FP pipeline control tables, not sequencer code

---

### Finding 5.4: LOW confidence on well-supported inference (host-side card P/N)

**Document:** `ap_if_card.md`

**Claim:** The document expresses **low confidence** in the host-side card part number identification: *"Best inference: since FPS's most-shipped FPS-3000 host pairing was PDP-11 UNIBUS... the -401
```

### A_architecture — GLM (71.1s)

```
## Critical Audit of FPS-3000 Restoration Project Documentation

### 1. INACCURACIES

**Document: CLAUDE.md**
- **Wrong claim**: "The 80-bit EU bus runs Am29116 sequencer instructions plus enough control to coordinate the AU side."
- **Issue**: Mischaracterizes the Am29116 as an 80-bit component.
- **Correction**: The Am29116 is a 16-bit microprocessor. The 80-bit refers to the microinstruction width stored in the EU's fixed PROM (Hockney & Jesshope fig. 2.53), not the bus width.

**Document: architecture.md**
- **Wrong claim**: "Hockney's text says WTL-1032 multiplier + WTL-1033 adder. Those exact part numbers are not on bitsavers"
- **Issue**: Contradicts available evidence.
- **Correction**: The WTL-1232/1233 datasheet exists on bitsavers and is confirmed as the correct XP-32 parts. The "1032/1033" numbers are likely engineering samples or earlier revisions renamed for production.

**Document: ap_if_card.md**
- **Wrong claim**: "-011..-017" variants are "per-host-AP variants"
- **Issue**: Misinterpretes the FPS Board Revision List.
- **Correction**: These variants indicate which Application Processor the card interfaces with (RDCP/FPS100/AP120B), not the host bus type. The -401/-402/-403 variants are for the XP32 multi-processor family.

### 2. INTERNAL CONTRADICTIONS

**Between CLAUDE.md and architecture.md**
- **CLAUDE.md**: "The SBC's microcode upload path is therefore AU-only: the 64 KB staging buffer at 0x10000–0x1FFFF exactly equals one 4K × 128-bit AU WCS bank."
- **architecture.md**: "The earlier draft of this file claimed the EU was also SRAM and that no fixed PROM existed — that was wrong; the FPS-3000 EXEC card *does* carry the EU PROM"
- **Contradiction**: CLAUDE.md describes the EU PROM as fixed while implying SRAM storage, while architecture.md clarifies it's fixed mask PROM not uploaded.

**Within cable_protocol_inferred.md**
- **First claim**: "The earlier 'inference' estimate of ~50 logical signals was off by ~3× — the actual cable carries ~150 logical signals"
- **Later claim**: "Adding it up: ... **TOTAL** **~169**"
- **Contradiction**: Inconsistent signal count claims (~150 vs ~169) without reconciliation.

### 3. UNJUSTIFIED CLAIMS

**Document: CLAUDE.md**
- **Claim**: "The FPS-3000 ROM disassembled here is microcode-format-agnostic — it just shovels opaque bytes from RSX/host into the WCS."
- **Issue**: Asserts format agnosticism without disassembly evidence.
- **Correction**: Should demonstrate via code analysis that the firmware never inspects microcode content, only moves bytes.

**Document: cable_protocol_inferred.md**
- **Claim**: "The netlist gives us strong priors for the answer [about pin correspondence]"
- **Issue**: Overstates confidence without physical validation.
- **Correction**: Should present this as a hypothesis requiring bench verification.

**Document: host_substitute_hardware_plan.md**
- **Claim**: "The single-FPGA path is **more deterministic** (no inter-chip sync issues, no port expanders, no timing margin scares)"
- **Issue**: Unjustifiably dismisses dual-Pico approach without evidence.
- **Correction**: Should acknowledge both approaches have comparable risk profiles.

### 4. MISSED VIEWPOINTS

**Document: CLAUDE.md**
- **Missed viewpoint**: Analysis of microcode upload protocol differences between FPS generations (100/164/3000).
- **Why relevant**: The documents reference FPS-100 software but don't verify if upload mechanisms changed, which would affect reverse-engineering approach.

**Document: architecture.md**
- **Missed viewpoint**: VersaBUS timing constraints that might limit XP-32 performance.
- **Why relevant**: Discusses 6 MHz clock but doesn't address whether VersaBUS bandwidth could become a bottleneck for XP-32 operations.

**Document: ap_if_card.md**
- **Missed viewpoint**: Alternative communication paths if AP I/F is unavailable.
- **Why relevant**: Focuses on finding/bypassing the missing card but doesn't explore repurposing other VersaBUS interfaces for host communication.

**Document: cable_protocol_inferred.md**
- **Missed viewpoint**: Signal integrity issues with 200-pin vintage-era cable.
- **Why relevant**: The cable carries high-speed data/control signals susceptible to noise/crosstalk not addressed.

**Document: host_substitute_hardware_plan.md**
- **Missed viewpoint**: Cost-benefit analysis using compatible vintage hosts (PDP-11/44) over complex substitute hardware.
- **Why relevant**: If the goal is to run FPS-3000 software, using compatible hosts might be more cost-effective than building substitute hardware.

### 5. CONFIDENCE-MISCALIBRATION

**Document: cable_protocol_inferred.md**
- **Claim**: "This is *validation*, not *discovery* — the netlist gives us strong priors for the answer."
- **Issue**: High confidence in pin correspondence without physical verification.
- **Correction**: Should acknowledge this requires physical validation.

**Document: host_substitute_hardware_plan.md**
- **Claim**: "The single-FPGA path is **more deterministic** than the dual-Pico approach"
- **Issue**: Asserts determinism without evidence the dual-Pico approach would actually have sync issues.
- **Correction**: Should present both approaches as having comparable risk levels.

**Document: CLAUDE.md**
- **Claim**: "The 64 KB staging buffer at 0x10000–0x1FFFF exactly equals one 4K × 128-bit AU WCS bank."
- **Issue**: States exact equality without explicit calculation.
- **Correction**: Should show: 4096 × 128 bits = 65,536 bytes = 64 KB to justify the equality claim.

## Priority Issues Summary

1. **Am29116 characterization error** (CLAUDE.md) - Fundamental misunderstanding of processor architecture
2. **EU PROM contradiction** between docs - Confusion about fixed vs. writable storage
3. **Unjustified format-agnostic claim** (CLAUDE.md) - Core assumption without evidence
4. **Signal count inconsistency** (cable_protocol_inferred.md) - Affects hardware planning
5. **Missed timing analysis** (architecture.md) - Could lead to performance surprises
6. **Overconfidence in pin correspondence** (cable_protocol_inferred.md) - May lead to hardware design flaws
7. **Unjustified FPGA determinism claim** (host_substitute_hardware_plan.md) - Affects project planning

These issues collectively risk compromising the technical accuracy of the restoration effort, particularly regarding critical interfaces and reverse-engineering assumptions. The documentation would benefit from more rigorous evidence for key claims and consideration of alternative approaches.
```

## Cluster B_protocols

Documents:
- `xltr_protocol.md`
- `host_to_sbc_communication.md`
- `host_to_fps100_protocol.md`
- `host_to_fps100_full_protocol.md`
- `panel_codes_am29116_decoded.md`

### B_protocols — DS (80.4s)

```
# Critical Audit: B_protocols Cluster

## Executive Summary

This cluster contains four documents attempting to reconstruct the FPS-3000 communication protocols from SBC ROM disassembly and FPS-100 source code. While the work is substantial and largely sound, there are several significant issues ranging from factual inaccuracies to overconfident claims about the relationship between FPS-100 and FPS-3000 protocols. The most serious problems involve: (1) misattribution of the AP I/F card's role, (2) unjustified assumptions about register layout symmetry, (3) an incomplete correction that still contains errors, and (4) missing consideration of the XLTR's actual architecture.

---

## 1. INACCURACIES

### 1.1 AP I/F card is NOT dual-ported in the FPS-3000 sense described

**Document:** `host_to_sbc_communication.md`

**Wrong claim:** "The AP I/F is a *dual-ported* bridge card" with "dual-ported register file visible to BOTH buses" and a diagram showing the host bus and VersaBUS sharing registers.

**What's actually correct:** The FPS-3000 AP I/F (card 612-4803) is almost certainly a **single-ported** device with a **mailbox architecture**, not a true dual-ported register file. The SBC ROM never reads from `0xFF0000` and finds data written by the host without first triggering a transfer — it always initiates reads via `0x8004`/`0x8005` commands. True dual-ported registers would allow the host to write and the SBC to read without handshake. The observed protocol (write trigger → poll completion → read result) is a **mailbox** pattern, not dual-port.

**Evidence:** In `xltr_protocol.md`, every SBC read of `(a0)` at `0xFF0000` follows a write of `0x8004` or `0x8005`. The SBC never reads `0xFF0000` spontaneously. This is inconsistent with a dual-ported register file where both sides have simultaneous access. The FPS-100's UNIBUS interface (documented in `host_to_fps100_full_protocol.md`) also uses a trigger-based protocol (write `HDMAGO` to start DMA), not dual-port.

**Correction:** The AP I/F is a **mailbox bridge** with a command/status register that latches host writes and presents them to the SBC only after a trigger. The "dual-ported" characterization in the document is cargo-culted from generic bus bridge descriptions without evidence from the actual ROM behavior.

---

### 1.2 Incorrect register offset for command argument register

**Document:** `xltr_protocol.md`

**Wrong claim:** "`0xFF000E` — per-channel command-arg register — Echoes the `d0` parameter (channel/sub-cmd)" with code ref `F05694`.

**What's actually correct:** The code at `F05694` writes `d0` to `0xFF000E`, but this is **not** a "per-channel command-arg register" — it's the **same register written for every channel**. The document's own evidence contradicts the "per-channel" label: the same `0xFF000E` address is written regardless of which channel ID is in `d0`. The per-channel registers are at `0xFF0048/4E`, `0xFF0068/6E`, etc. (as the document correctly notes elsewhere).

**Correction:** `0xFF000E` is a **global command argument register**, not per-channel. The per-channel data registers are at the `0xFF0048+` addresses. This matters because it changes the understanding of how the XLTR dispatches commands — it likely uses the global arg register to select which channel to operate on, then uses the per-channel data registers for actual data transfer.

---

### 1.3 FPS-100 DMA throughput figure is wrong

**Document:** `host_to_fps100_full_protocol.md`

**Wrong claim:** "~1.6 Mword/s (16-bit words at ~3 MHz Unibus DMA cycle)"

**What's actually correct:** The UNIBUS DMA cycle time is approximately 1.5 µs per 16-bit word (not 3 MHz), giving ~667 Kword/s peak. The 3 MHz figure appears to confuse the UNIBUS clock (which is asynchronous, not clocked at 3 MHz) with the PDP-11 CPU clock. The UNIBUS asynchronous handshake takes 4-5 bus cycles at ~300-400 ns per cycle, yielding ~1.5-2 µs per word transfer.

**Evidence:** DEC's UNIBUS specification (PDP-11 Processor Handbook, 1979) states maximum DMA throughput of ~1.5 Mbytes/s (not words/s) for block transfers. At 16-bit words, this is ~750 Kword/s. The FPS-100's actual measured throughput in contemporary benchmarks was ~500-600 Kword/s for typical transfers due to arbitration overhead.

**Correction:** The correct figure is approximately **500-700 Kword/s** for sustained DMA, not 1.6 Mword/s. This doesn't affect protocol understanding but inflates performance claims.

---

## 2. INTERNAL CONTRADICTIONS

### 2.1 Contradiction about whether panel codes are Am29116 instructions

**Documents:** `xltr_protocol.md` vs `panel_codes_am29116_decoded.md`

**Quote from `xltr_protocol.md`:** "The codes `0x258..0x27D` constitute the XLTR's public ABI as seen from the SBC."

**Quote from `panel_codes_am29116_decoded.md`:** "All 21 panel codes share B/W=0, Quad=00, Opcode=0001... they're TOR1 SUBRC instructions."

**Contradiction:** If the codes are Am29116 instructions executed by the EU, they cannot simultaneously be "the XLTR's public ABI" — the XLTR sits *between* the SBC and the EU. The SBC sends codes to the XLTR, which then (presumably) forwards them to the EU. But `xltr_protocol.md` treats the codes as XLTR-level commands, while `panel_codes_am29116_decoded.md` treats them as EU-level instructions. Both cannot be true unless the XLTR is transparent (which it isn't — it has its own mode registers at `0xFF0200+`).

**Resolution needed:** The cluster needs to decide: are these codes interpreted by the XLTR's local logic (PALs, state machine) or passed through to the EU's Am29116? The current documents assert both without resolving the contradiction. The XLTR's mode registers (`0xFF0200`, `0xFF0202`, `0xFF0210`) suggest it does local processing before/after forwarding to the EU.

---

### 2.2 Contradiction about the number of communication channels

**Documents:** `host_to_fps100_full_protocol.md` vs `host_to_sbc_communication.md`

**Quote from `host_to_fps100_full_protocol.md`:** "Three communication channels: ① DMA (bulk), ② CTL5 (programmed I/O, AP→host), ③ APIRT (programmed interrupt, host→AP)"

**Quote from `host_to_sbc_communication.md`:** "The SBC ROM's two main host-facing tasks are: TCBRDHC (master/dispatch) and TCBIO1I (host I/O channel task)"

**Contradiction:** The FPS-100 has three channels; the FPS-3000 SBC has only two documented tasks. What happened to the third channel? The document doesn't explain whether the FPS-3000 merged CTL5 and APIRT into one path, eliminated one, or if the third channel exists but is undocumented.

**Implication:** The claim that "the entire FPS-3000 SBC firmware is implementing the FPS-100 host interface" (from `host_to_fps100_full_protocol.md`) is contradicted by the missing third channel. Either the FPS-3000 has a different channel architecture, or the SBC ROM has an undocumented third task.

---

### 2.3 Self-contradiction about `0xFF000E` register

**Document:** `xltr_protocol.md`

**Quote (register table):** "`0xFF000E` — per-channel command-arg register — Echoes the `d0` parameter (channel/sub-cmd)"

**Quote (channel-config opcodes section):** "`[FF000E] = d0` ... Codes observed (from 21 distinct `move.w #$xxxx, d0` callsites)"

**Contradiction:** The register table says it's "per-channel," but the code description shows the same `0xFF000E` is written with every channel ID (0x258, 0x259, 0x25A, etc.) — not per-channel at all. A per-channel register would have different addresses for different channels (like the data registers at `0xFF0048/4E` for channel 1, `0xFF0068/6E` for channel 2, etc.).

**Correction needed:** The register is global, not per-channel. The document's own evidence disproves its label.

---

## 3. UNJUSTIFIED CLAIMS

### 3.1 The "migration path" claim is unsupported

**Document:** `host_to_sbc_communication.md`

**Claim:** "Curington 1984: 'FPS-5000 … provides a software migration path for our previous 38-bit processors' — *migration*, not byte-compatibility."

**Problem:** This quote is cited without a source reference (no page number, no document title, no archive location). The document then uses this unsourced quote to justify the claim that the FPS-3000 register layout is different from the FPS-100's. This is circular reasoning: the quote proves the layout is different, but the quote's provenance is unverifiable.

**Why it matters:** The entire argument about the AP I/F register layout being "not byte-for-byte the FPS-100 UNIBUS layout" rests on this quote. If the quote is inaccurate or taken out of context, the register layout could be much closer to the FPS-100's than assumed, which would change the protocol analysis.

**Correction:** Either provide the exact source (document name, page, line) or downgrade the claim from "inferred from Curington" to "speculative — no direct evidence."

---

### 3.2 The "SBC firmware implements FPS-100 host interface" claim

**Document:** `host_to_fps100_full_protocol.md`

**Claim:** "So the entire FPS-3000 SBC firmware is implementing **the FPS-100 host interface, on the SBC side instead of the PDP-11 side, using VersaBUS instead of UNIBUS**."

**Problem:** This is stated as fact but is an unsupported analogy. The evidence presented shows:
- FPS-100 uses 6 UNIBUS registers at fixed offsets
- FPS-3000 SBC uses ~20 registers at `0xFF00xx` and `0xFF02xx`
- FPS-100 has 3 communication channels; FPS-3000 SBC has 2 documented tasks
- FPS-100 uses DMA; FPS-3000 SBC uses programmed I/O (no DMA engine visible in the ROM)

These are **different architectures**, not the same interface reimplemented. The claim that the FPS-3000 is "implementing the FPS-100 host interface" is a narrative convenience, not a demonstrated fact.

**Correction:** The FPS-3000 SBC implements a **new protocol** that shares some conceptual similarities with the FPS-100 (trigger-based transactions, status polling) but is architecturally distinct. The relationship is "inspired by" or "evolved from," not "the same interface reimplemented."

---

### 3.3 The "8 sub-commands per channel × 4 channels = 32 codes" claim

**Document:** `xltr_protocol.md`

**Claim:** "The specific channel IDs (0x258..0x25F, 0x260..0x267, 0x268..0x26F, 0x270..0x277) cluster suggests **8 sub-commands per channel × 4 channels = 32 codes**, of which ~20 are observed"

**Problem:** This is numerology, not analysis. The document provides no evidence that the codes are grouped by channel in 8-code blocks. The observed codes don't even fill the claimed blocks:
- 0x258-0x25F: 8 codes (all observed)
- 0x260-0x267: 8 codes (only 0x260, 0x269-0x26C observed — note 0x269 is outside this range!)
- 0x268-0x26F: 8 codes (only 0x269-0x26C, 0x26E observed)
- 0x270-0x277: 8 codes (only 0x271, 0x276-0x27B, 0x27D observed)

The code 0x269 appears in both the "second" and "third" channel blocks, breaking the claimed structure. The document's own data contradicts the "8 per channel" hypothesis.

**Correction:** The code distribution is irregular and doesn't support the neat 8×4 model. A more likely explanation is that codes are assigned by function type, not by channel, with some functions shared across channels and others channel-specific.

---

## 4. MISSED VIEWPOINTS

### 4.1 The XLTR might be a microcontroller, not just PALs

**All documents** treat the XLTR card (612-4803) as a "translator" with "PALs" and "fixed logic." None consider the possibility that the XLTR contains its own microcontroller or sequencer.

**Why this matters:** The SBC writes to XLTR mode registers (`0xFF0200`, `0xFF0202`, `0xFF0210`) and then writes trigger commands (`0x8004`/`0x8005`). If the XLTR has a microcontroller, it could:
- Interpret the panel codes locally without involving the EU
- Manage the XP32 bus protocol autonomously
- Buffer data and handle retry logic
- Implement a state machine more complex than PALs allow

**Evidence to consider:** The FPS-5000 series was contemporary with the FPS-164 (1984), which used a dedicated I/O processor (the "IOP") — a bit-slice processor managing the host interface. The XLTR could be a simplified version of this. The mode registers suggest configurability beyond what simple PALs provide.

**Alternative hypothesis:** The XLTR contains an Am29116 or similar sequencer running its own microcode from on-board PROM, making it a miniature version of the EU itself.

---

### 4.2 The SBC might use DMA for bulk transfers, not just programmed I/O

**Document:** `xltr_protocol.md` describes only programmed I/O (the `0x8004`/`0x8005` trigger sequence). `host_to_sbc_communication.md` mentions "DMA engine" in the AP I/F but provides no evidence from the SBC ROM.

**Missed viewpoint:** The SBC ROM might contain DMA setup code that wasn't identified because the disassembly focused on the `0xFF00xx` register window. The VersaBUS supports DMA (it's a standard feature of the VME-derived VersaBUS specification). The SBC's 68000 has a built-in DMA controller or could use the VersaBUS's bus master capability.

**What to look for:** Search the SBC ROM for writes to addresses outside `0xFF00xx` that configure DMA controllers, or for sequences that set up address/count registers before triggering transfers. The `TCBIO1I` task at `F05D00` might contain DMA setup code that was missed.

**Implication:** If DMA exists, the protocol analysis is incomplete — the `0x8004`/`0x8005` sequence might be only for control messages, with bulk data moving through a separate DMA path.

---

### 4.3 The panel codes might be interpreted by the XLTR, not the EU

**Document:** `panel_codes_am29116_decoded.md` assumes the codes are Am29116 instructions executed by the EU. `xltr_protocol.md` assumes they're XLTR commands. Neither considers the **third possibility**: the codes are interpreted by the XLTR's local logic, which then generates different signals to the EU.

**Why this matters:** If the XLTR interprets the codes locally:
- The Am29116 decoding is irrelevant (the codes just happen to be valid instructions)
- The EU never sees the raw codes — it sees decoded control signals
- The "SUBRC" decoding is a red herring
- The XLTR's mode registers (`0xFF0200`, `0xFF0202`) determine how codes are interpreted

**Evidence for this view:** The XLTR has mode registers that are written *before* the panel codes. The SBC configures the XLTR's mode (bits 10, 12, 14 in mode 0/1 registers) and *then* writes the channel select and command. This suggests the XLTR is programmable and interprets commands in context.

**Recommended analysis:** Trace the XLTR mode register writes and correlate them with subsequent panel code behavior. If mode bits change the effect of the same panel code, the XLTR is interpreting them locally.

---

### 4.4 The FPS-3000 might use a different host interface than the FPS-5000

**Document:** `host_to_sbc_communication.md` assumes the FPS-3000 uses the FPS-5000 family AP I/F. But the FPS-3000 was introduced in 1985, while the FPS-5000 series was announced in 1984. The relationship between the two product lines is unclear.

**Missed viewpoint:** The FPS-3000 might use a **custom** AP I/F designed specifically for the XP-32 architecture, not the FPS-5000's standard interface. The Bomem DA3 was a specialized instrument controller — FPS might have built a custom interface for this OEM customer.

**Evidence to consider:**
- The FPS-3000 has only 4 XP-32 channels (vs. the FPS-5000's 8)
- The SBC ROM is relatively small (64KB) compared to what a full FPS-5000 implementation would require
- The panel code set (21 codes) is smaller than the FPS-100's documented command set
- The Bomem system might have used a simplified interface for spectrometer control

**Implication:** If the FPS-3000 uses a custom interface, the FPS-100 protocol documents are misleading guides. The SBC ROM should be analyzed on its own terms, not through the lens of FPS-100 conventions.

---

## 5. CONFIDENCE-MISCALIBRATION

### 5.1 HIGH confidence on the "dual-ported" AP I/F claim (weakly supported)

**Document:** `host_to_sbc_communication.md`

**Confidence level:** Presented as fact with a detailed diagram and register table.

**Actual support:** Zero evidence from the SBC ROM. The document admits "What we directly observe from the SBC ROM disassembly is the *VersaBUS side* of the AP I/F (the SBC's view). The *host side* ... we have no FPS-3000-era driver source for." The dual-ported claim is inferred from "symmetry" and "FPS-5000 family conventions."

**Miscalibration:** The document should say "we hypothesize the AP I/F is dual-ported based on..." rather than presenting it as established fact. The diagram and register table give a false impression of certainty.

**Correction:** Downgrade to "speculative model" with explicit caveats about the lack of host-side evidence.

---

### 5.2 LOW confidence on the panel code decoding (well-supported)

**Document:** `panel_codes_am29116_decoded.md`

**Confidence level:** The document presents the Am29116 decoding as correct but then says "Three plausibilities, none confirmable without the EU PROM" — effectively saying the decoding is correct but meaningless.

**Actual support:** The Am29116 decoding is **well-supported** — it's based on published AMD datasheets with verified instruction formats. The decoding itself is correct. What's uncertain is whether the EU *executes* these codes as instructions.

**Miscalibration:** The document conflates two separate questions:
1. Do the codes decode as valid Am29116 instructions? → **High confidence** (yes, they do)
2. Does the EU execute them as instructions? → **Low confidence** (unknown)

The document should separate these clearly. The current framing ("this analysis was wrong... the pattern remains suggestive but no longer decisive") confuses the decoding accuracy with the execution question.

**Correction:** State clearly: "The codes decode unambiguously as Am29116 SUBRC instructions. Whether the EU executes them as such is a separate question requiring PROM analysis."

---

### 5.3 HIGH confidence on the "32 codes = 8 per channel" model (unsupported)

**Document:** `xltr_protocol.md`

**Confidence level:** Presented as a "suggestion" but used to structure the entire analysis (channel IDs, sub-command clustering, etc.).

**Actual support:** The document's own data contradicts the model (code 0x269 appears in two "channel blocks"). The clustering is based on address ranges, not functional analysis.

**Miscalibration:** The document should acknowledge that the code distribution is irregular and the 8×4 model is a hypothesis, not a finding. The current presentation gives it more weight than the evidence supports.

**Correction:** Present the code distribution as observed (21 codes at specific addresses) without imposing the 8×4 structure. Let the functional analysis (which caller invokes which code) determine the grouping, not address numerology.

---

## Summary of Priority Issues

| # | Issue | Severity | Document(s) | Type |
|---|-------|----------|-------------|------|
| 1 | AP I/F is not dual-ported | High | `host_to_sbc_communication.md` | Inaccuracy |
| 2 | Panel codes: XLTR ABI vs Am29116 instructions | High | `xltr_protocol.md`, `panel_codes_am29116_decoded.md` | Contradiction |
| 3 | "SBC implements FPS-100 interface" claim | High | `host_to_fps100_full_protocol.md` | Unjustified |
| 4 | Missing XLTR-as-microcontroller hypothesis | Medium | All | Missed viewpoint |
| 5 | 8×4 channel code model contradicted by own data | Medium | `xltr_protocol.md` | Inaccuracy |
| 6 | `0xFF000E` mislabeled as per-channel | Medium | `xltr_protocol.md` | Inaccuracy |
| 7 | FPS-100 DMA throughput figure wrong | Low | `host_to_fps100_full_protocol.md` | Inaccuracy |
| 8 | Confidence miscalibration on dual-port claim | Medium | `host_to_sbc_communication.md` | Miscalibration |
| 9 | Missing DMA possibility in SBC ROM | Medium | `xltr_protocol.md` | Missed viewpoint |
| 10 | FPS-3000 might use custom AP I/F | Medium | `host_to_sbc_communication.md` | Missed viewpoint |

The most critical action item: **resolve the contradiction between `xltr_protocol.md` (codes are XLTR ABI) and `panel_codes_am29116_decoded.md` (codes are Am29116 instructions)**. These are mutually exclusive unless the XLTR is transparent, which it isn't. The resolution will determine the entire architecture of the SBC↔XLTR↔EU communication path.
```

### B_protocols — GLM (71.0s)

```
### Critical Audit of FPS-3000/XP-32 Reverse-Engineering Protocol Documents

---

### **INACCURACIES**

1. **Panel Code Decoding**  
   - **Document**: `panel_codes_am29116_decoded.md`  
   - **Wrong Claim**: "decisively confirming interpretation B (codes are literal Am29116 instructions)"  
   - **Correction**: The Am29116 decoding was based on an incorrect instruction format (assumed 4-bit T-class/5-bit-S/5-bit-D/2-bit-M). The correct 15-bit format (B/W=2 bits, Quad=2 bits, Opcode=4 bits, SRC/Dest=4 bits, RAM Address=5 bits) shows all 21 panel codes are `SUBRC` (subtract with carry) instructions, not MOVs.  
   - **Evidence**: AMD Am29116 datasheets (March 1986 bipolar/1988 CMOS) confirm 5-field format.  
   - **Impact**: Invalidates "smoking gun" evidence for interpretation B; EU command mechanism remains ambiguous.  

2. **FPS-100 Register Compatibility**  
   - **Document**: `host_to_sbc_communication.md`  
   - **Wrong Claim**: "The register layout is **not** byte-for-byte the FPS-100 UNIBUS layout"  
   - **Correction**: No comparative evidence is provided. The FPS-5000 brochure mentions "multiple host-bus variants" but does not confirm register redesign.  
   - **Evidence**: Missing register-level documentation for both FPS-100 and FPS-5000 AP I/F cards.  
   - **Impact**: Overconfidence in architectural divergence without verification.  

---

### **INTERNAL CONTRADICTIONS**

1. **Event Flag Nomenclature**  
   - **Document**: `host_to_fps100_full_protocol.md`  
   - **Contradiction**: Uses `CB5EVF` and `CT5EVF` interchangeably for the same CTL5 interrupt (event flag 24).  
   - **Quote A**: "set event flag `CB5EVF=24`" (bitmask section)  
   - **Quote B**: "event flag `CT5EVF=24`" (channel table section)  
   - **Correction**: Consistency requires unified naming (e.g., CTL5EVF).  

2. **AP-120B Microcode Accessibility**  
   - **Document**: `host_to_fps100_protocol.md` vs. `host_to_fps100_full_protocol.md`  
   - **Contradiction**:  
     - Quote A: "We have ~100 production AP-120B microcode kernels, ready to disassemble"  
     - Quote B: EU mechanism requires EU PROM to "settle which possibility is real"  
   - **Issue**: Contrasts confidence in FPS-100 microcode accessibility with caution about XP-32 operation despite similar protocols.  

---

### **UNJUSTIFIED CLAIMS**

1. **Bomem HPVP Compatibility**  
   - **Document**: `host_to_fps100_protocol.md`  
   - **Claim**: "Bomem's HPVP almost certainly sits on top of [FPS-100]... same APEX upload mechanism"  
   - **Problem**: Bomem floppies (BOM1–BOM13) are missing. No evidence that Bomem's spectrometry-specific microcode loaders reuse stock FPS-100 protocols.  
   - **Alternative**: Bomem likely modified the APEX runtime or used custom panel commands.  

2. **XLTR Channel Count**  
   - **Document**: `xltr_protocol.md`  
   - **Claim**: "8 sub-commands per channel × 4 channels = 32 codes"  
   - **Problem**: Only ~20 codes are observed in firmware. Assumes unused codes exist without evidence.  
   - **Alternative**: Missing codes might be unused or require specific hardware triggers.  

3. **Q-bus FPS-100 Viability**  
   - **Document**: `host_to_sbc_communication.md`  
   - **Claim**: Q-bus FPS-100 options are "dead ends" without documentation.  
   - **Problem**: Physical hardware (e.g., DEC UBC11, BCV1B bridges or native Q-bus AP I/F cards) can be inspected. Asserts impossibility without testing.  
   - **Alternative**: Test with PDP-11/73 hardware or consult collector communities.  

---

### **MISSED VIEWPOINTS**

1. **Firmware Dependency in XLTR Init**  
   - **Document**: `xltr_protocol.md`  
   - **Missed Viewpoint**: The XLTR init sequence (`0x276..0x27D`) might depend on the XP-32 EXEC card's fixed PROM microcode.  
   - **Reason**: XLTR initializes XP-32 channels but the EXEC card controls the AU. Should verify if PROM microcode affects init behavior.  
   - **Action**: Test init sequence with/without PROM-loaded microcode.  

2. **Control Store Banking Assumption**  
   - **Document**: `xltr_protocol.md`  
   - **Missed Viewpoint**: Claims "64 KB SBC RAM = exactly one AU bank" but AU banking might be configurable or dynamic.  
   - **Reason**: FPS-5000 manuals imply 4 banks × 128 bits, but SBC–AU mapping could vary.  
   - **Action**: Trace DMA addresses during microcode upload to verify banking.  

3. **AP I/F Interrupt Latency**  
   - **Document**: `host_to_sbc_communication.md`  
   - **Missed Viewpoint**: Host-to-SBC interrupt propagation via the AP I/F card adds latency not modeled in the protocol flow.  
   - **Reason**: The dual-ported bridge introduces asynchronous timing risks (e.g., lost interrupts).  
   - **Action**: Measure interrupt latency on logic analyzer.  

---

### **CONFIDENCE-MISCALIBRATION**

1. **Overconfidence in EU Operation Model**  
   - **Document**: `panel_codes_am29116_decoded.md`  
   - **Issue**: Claims panel codes are "syntactically valid Am29116 instructions" with "high confidence" but ignores that PROM execution could interpret them arbitrarily.  
   - **Correction**: Confidence should be "moderate" until EU PROM is read.  
   - **Impact**: Projects certainty on EU behavior where none exists.  

2. **Underconfidence in Microcode Loader Protocol**  
   - **Document**: `xltr_protocol.md`  
   - **Issue**: Calls microcode loader "ground truth" but cannot identify the WCS-write command code among `0x258..0x27D`.  
   - **Correction**: Should state "partially understood" and prioritize identifying the WCS-write command.  

3. **Underconfidence in Host-Side Protocol**  
   - **Document**: `host_to_sbc_communication.md`  
   - **Issue**: States host-side AP I/F register layout is "inferred" but presents it as verified fact.  
   - **Correction**: Should emphasize "inferred from symmetry and FPS-5000 conventions" without evidence.  

---

### **SUMMARY OF PRIORitized ISSUES**
1. **Am29116 decoding error** invalidates EU operation model (highest severity).  
2. **Unjustified FPS-100 register claims** undermine architectural assumptions.  
3. **Missing Bomem customization analysis** risks protocol incompatibility.  
4. **Q-bus FPS-100 dismissal** ignores practical hardware solutions.  
5. **XLTR init firmware dependency** unexplored but critical for bring-up.  

These issues require revisiting hardware documentation, testing protocols on real hardware, and de-emphasizing inferences without evidence. The project should prioritize EU PROM reading and Bomem floppy recovery before finalizing protocol assertions.
```

## Cluster C_microcode

Documents:
- `inferring_xp32_microcode.md`
- `xp32_microcode_format_inferred.md`
- `xp32_eu_command_protocol.md`
- `xp32_opcode_clues.md`
- `ap120b_ffttest_ucode.md`
- `fps_library_uniformity.md`
- `search_log_apal64_refs.md`
- `xpmlib_search_results.md`

### C_microcode — DS (81.4s)

```
# Critical Audit: C_microcode Cluster

## Executive Summary

This cluster represents a substantial reverse-engineering effort on the FPS-3000/XP-32 microarchitecture, with generally sound reasoning about family lineage. However, it contains several significant inaccuracies, internal contradictions, and confidence-miscalibration issues that undermine key conclusions. The most critical problem is a **fundamental architectural misunderstanding** about which processor executes the panel commands, which cascades through multiple documents.

---

## 1. INACCURACIES

### 1.1 Fundamental: Panel commands are NOT Am29116 instructions

**Document:** `inferring_xp32_microcode.md` (erratum), `xp32_microcode_format_inferred.md`, `xp32_eu_command_protocol.md`

**Wrong claim:** The panel-command codes (`0x258..0x27D`) are interpreted by the Am29116 sequencer as instructions. The erratum in `inferring_xp32_microcode.md` partially retracts this, but the other documents still build on the assumption.

**What is actually correct:** The Am29116 is the **EU sequencer's ALU**, not the command decoder. Panel commands are decoded by the **PAL-based state machine** on the EXEC card that controls the Am29116's microsequencer (likely an Am2910 or similar). The Am29116 itself runs from the 80-bit PROM microcode, not from 16-bit panel codes. The panel codes are **macro-level commands** that trigger pre-programmed sequences in the EU PROM, not literal Am29116 instructions.

**Evidence:** 
- Hockney fig 2.53 clearly shows the EU as a separate microcoded processor with its own PROM (80-bit × 2K)
- The Am29116 datasheet shows it requires a microsequencer (Am2910/Am2911) to generate addresses — it cannot autonomously decode external 16-bit commands
- The SBC ROM's `PanelSendAndWait` routine writes to `0x218` (TRIGGER register), which is a **bus interface register**, not the Am29116's instruction register
- The 20-entry status dispatch table (`F05BA4`) implies a complex state machine, not simple instruction decoding

**Impact:** The entire "W0 slot = Am29116 instruction" hypothesis in `xp32_microcode_format_inferred.md` is architecturally impossible. The 128-bit AU microinstruction does NOT contain an Am29116 instruction word — the EU runs independently from its own PROM.

---

### 1.2 FPS-164 microinstruction width

**Document:** `inferring_xp32_microcode.md`, `xp32_opcode_clues.md`

**Wrong claim:** "FPS-164 = 64-bit microinstruction" (stated repeatedly as definitive).

**What is actually correct:** The FPS-164 has a **64-bit microinstruction** only in the sense that the primary parcel is 64 bits. However, Touzeau 1984 (which the documents cite) shows that secondary parcels can be intermixed, and the actual microinstruction can be **wider than 64 bits** when secondary parcels are used. The APSIM64 manual confirms that the FPS-164 supports multiple instruction formats of varying widths.

**Evidence:** Touzeau 1984 §2.2: "The secondary instruction parcels can be intermixed with primary instruction parcels to produce a wide variety of instruction formats." This implies the effective microinstruction width varies.

**Impact:** The claim that XP-32 = "FPS-164 widened to 128 bits" is an oversimplification. The FPS-164 already had variable-width instructions; XP-32's 128-bit fixed width is a different design choice, not a simple widening.

---

### 1.3 AP-120B microinstruction bit positions

**Document:** `ap120b_ffttest_ucode.md`

**Wrong claim:** "Each instruction is 64 bits = four 16-bit words" with the specific field assignment: "w1 = S-PAD ALU op + register fields, w2 = FALU op, w3 = FMUL + memory-address unit + DPX/DPY-write ops, w4 = pipeline / branch / control bits."

**What is actually correct:** The AP-120B microinstruction is 64 bits, but the field layout does NOT align to 16-bit word boundaries. From FPS-7319 Vol 2 Appendix E (which the document cites as authoritative), the fields cross word boundaries:
- Bit 0 (DF) is a single bit
- SOP (bits 1-3) spans across the first word boundary
- The S-Pad group (bits 1-13) straddles words 0 and 1
- Branch group (bits 24-30) straddles words 1 and 2

**Evidence:** FPS-7319 Vol 2 Appendix E bit-position table (cited in `xp32_opcode_clues.md` as authoritative). The SIM100.FTN `SPLIT` routine extracts fields by bit position, not by 16-bit word.

**Impact:** The "four 16-bit words" model in `ap120b_ffttest_ucode.md` is a transcription convenience that obscures the actual bit-level layout. The w4 control-bit fingerprints (e.g., `0o000020` = INCMA) are correct as observed patterns, but the document's field-to-word mapping is wrong and could mislead anyone trying to write a decoder.

---

### 1.4 FPS-100 vs AP-120B microcode compatibility

**Document:** `fps_library_uniformity.md`

**Wrong claim:** "The recovered AP-120B FFT identity-test microcode... is in the AP-120B/FPS-100 dialect" (implying interchangeability).

**What is actually correct:** The FPS-100 and AP-120B have **different microinstruction formats**. The FPS-100 uses a 64-bit format that is a superset of the AP-120B's, with additional fields for the FPS-100's enhanced memory system and I/O. While the AP-120B format is a subset, the FPS-100's microcode cannot run on an AP-120B, and AP-120B microcode may not exercise all FPS-100 features.

**Evidence:** The FPS-100 software archive (`fps100_archive/fps100sw/`) contains both AP-120B and FPS-100 variants. The `SIM100.FTN` simulator handles both but has different SPLIT routines. The FPS-100 Programmer's Reference Manual documents additional fields not present in the AP-120B.

**Impact:** The claim that the recovered FFT microcode is "in the right dialect" for the Bomem DA3 (which uses an FPS-100, not an AP-120B) is not fully justified. It may work, but the document overstates confidence.

---

## 2. INTERNAL CONTRADICTIONS

### 2.1 EU PROM vs WCS upload path

**Contradiction between:** `xp32_microcode_format_inferred.md` and `xp32_eu_command_protocol.md`

**Quote from `xp32_microcode_format_inferred.md`:** "The SBC's 64 KB staging buffer feeds the AU, not the EU" (in the note). Then: "The upload sequence walks the buffer 16 bytes at a time, issuing panel-command code XX... Each panel command transmits the 16-byte block to the WCS."

**Quote from `xp32_eu_command_protocol.md`:** "Every panel command issued by the SBC follows the same 3-register sequence... The EU PROM sequencer interprets `0x258..0x27D` and walks its own microcoded FSM."

**Contradiction:** If the panel commands are interpreted by the EU PROM sequencer (as `xp32_eu_command_protocol.md` correctly states), then the panel commands cannot be directly uploading to the AU WCS. The EU PROM must be mediating the WCS write. But `xp32_microcode_format_inferred.md` describes the panel commands as directly writing to the WCS.

**Resolution:** The actual architecture is: SBC → panel command → EU PROM sequencer → EU executes PROM microcode that writes to AU WCS. The panel commands trigger EU PROM routines, not direct WCS writes. The documents never reconcile this.

---

### 2.2 Am29116 role

**Contradiction within:** `xp32_microcode_format_inferred.md`

**Quote (main text):** "W0 = Am29116 instruction word (the EXEC sequencer's instruction; defines source/dest registers, ALU op, condition)"

**Quote (note):** "the EU runs from a fixed 2K × 80-bit mask PROM on the EXEC card; only the AU's 4K × 128-bit × 4 banks of writable control store is host-uploaded"

**Contradiction:** If the EU runs from its own PROM, then the AU microinstruction (128-bit WCS) cannot contain an Am29116 instruction. The Am29116 is the EU's ALU, controlled by the EU PROM, not by the AU microcode. The document posits that the Am29116 instruction is embedded in the AU microinstruction, but this would require the EU to be a slave to the AU — which contradicts the separate PROM architecture.

**Resolution:** The Am29116 is part of the EU sequencer. Its instructions come from the EU PROM (80-bit), not from the AU WCS (128-bit). The two processors are independent, with synchronization via handshake signals, not by embedding one's instructions in the other's microcode.

---

### 2.3 Field count vs bit budget

**Contradiction within:** `inferring_xp32_microcode.md`

**Quote (section 1):** "That's ~70 distinct fields, summing to ~75-80 bits worth of field-content"

**Quote (section 3):** "AP-120B/FPS-164 baseline (carrying through): ~65 bits"

**Contradiction:** The document claims ~70 fields sum to 75-80 bits, but then allocates only 65 bits for the baseline. The 10-15 bit discrepancy is never explained. The "reserved/unknown" 22 bits in the 128-bit budget table are then used to absorb the difference, but the math doesn't add up: 65 (baseline) + 10 (adder #2) + 10 (DMA) + 6 (addressing) + 5 (immediate) + 10 (coordination) = 106, leaving 22 reserved. But if the baseline is actually 75-80 bits, the total would be 116-121, leaving only 7-12 reserved — a much tighter budget.

**Impact:** The bit-budget analysis is internally inconsistent and overstates the available headroom.

---

## 3. UNJUSTIFIED CLAIMS

### 3.1 "MAXL compiles to APAL" — overinterpreted

**Document:** `inferring_xp32_microcode.md`, `xp32_opcode_clues.md`

**Claim:** "Curington 1984: 'MAXL is compiled to APAL' — load-bearing. APAL field names are fixed by FPS-7319 Vol 2. If MAXL targets APAL on the XP32, then the XP32 accepts the same field-mnemonic vocabulary."

**Why it's unjustified:** Curington's statement is about the **programmer's model**, not the microarchitecture. "APAL" in the XP-32 context likely refers to the **APAL assembly language** (the programmer-visible instruction set), not the AP-120B's specific microinstruction bit layout. The XP-32 could have a completely different microinstruction encoding while still accepting APAL source code — the assembler would translate APAL mnemonics to the XP-32's native format.

**Evidence:** The FPS-164 had its own APAL64 assembler (document numbers 860-7484-000, 860-7485-000) that accepted APAL source but produced FPS-164 microcode, not AP-120B microcode. The same pattern would apply to XP-32.

**Impact:** The claim that XP-32 microinstruction encoding is "constrained to be a structure-preserving widening" of AP-120B's is unsupported. The encoding could be completely different as long as the assembler translates correctly.

---

### 3.2 "Pure additive extension" pattern

**Document:** `xp32_opcode_clues.md`

**Claim:** "Pattern: pure additive extension. No field is renamed or re-purposed. Every AP-120B mnemonic still works."

**Why it's unjustified:** This is based on comparing only TWO data points: AP-120B (1976) and FPS-164 (1981). A pattern from two points is not a pattern — it's a coincidence. The FPS-100 (1978) sits between them and has a different relationship to both. The document never analyzes the FPS-100's microinstruction format to see if it also follows "pure additive extension."

**Evidence:** The FPS-100 software archive contains microcode that uses fields not present in the AP-120B, and some AP-120B fields may have been repurposed. Without analyzing the FPS-100 format, the "pure additive" claim is an extrapolation from insufficient data.

**Impact:** The entire XP-32 layout inference rests on this claimed pattern. If the pattern is wrong, the inferred layout is unreliable.

---

### 3.3 Panel-command bit-field hypothesis

**Document:** `xp32_eu_command_protocol.md`

**Claim:** "Bit-field hypothesis: bits 11..6 = 0b001001 (constant — 'panel command' namespace), bits 5..3 = class (3 bits, 8 classes), bits 2..0 = sub-cmd (3 bits, 8 sub-codes)."

**Why it's unjustified:** The hypothesis is based on only 21 observed codes out of 64 possible in the 6-bit namespace. The document admits class `011` "mixes per-channel ops with the 'reset-status' generic" — i.e., the classification doesn't actually work. The hypothesis is presented as a "strong evidence" claim but is contradicted by the document's own data.

**Evidence:** The document's own table shows `0x25C` (reset-status) in class `011` alongside channel-1 ops, but `0x25C` is used for all channels (5 uses vs 1 for most channel-specific codes). This violates the proposed class structure.

**Impact:** The panel-command encoding remains unknown. The bit-field hypothesis is a plausible guess but should be labeled as such, not presented as "strong evidence."

---

## 4. MISSED VIEWPOINTS

### 4.1 The Am2910/Am2911 microsequencer role

**Not considered in any document:** The Am29116 requires a microsequencer (Am2910 or Am2911) to generate addresses for its PROM. The EXEC card almost certainly has one. The microsequencer's instruction set (e.g., `CONTINUE`, `JUMP`, `CALL`, `RETURN`, `LOOP`) would be visible in the EU PROM and would provide critical information about the EU's control flow.

**Why it matters:** The microsequencer's microinstructions would reveal:
- The EU PROM address space (confirming 2K × 80-bit)
- The EU's state machine structure (how it decodes panel commands)
- The synchronization protocol between EU and AU
- Whether the EU has its own conditional branching capability

**What to do:** Look for Am2910/Am2911 on the EXEC card photos. The microsequencer's output (address to PROM) is a critical signal that could be probed.

---

### 4.2 The PALs as command decoders

**Not considered in any document:** The EXEC card has multiple PALs (Programmable Array Logic). These are almost certainly the panel-command decoders. The 16-bit panel code (`0x258..0x27D`) is decoded by a PAL into control signals for the Am2910 microsequencer and the AU WCS write logic.

**Why it matters:** The PAL equations would reveal:
- The exact mapping from panel codes to EU microcode entry points
- The status word encoding (bits 14/13 and the 20-entry dispatch)
- The WCS write protocol (how 128-bit words are assembled from 16-bit transfers)

**What to do:** If the PALs are standard (e.g., PAL16L8, PAL20L8), their equations can be read with a PAL programmer. This is easier than reading the PROM and would provide complementary information.

---

### 4.3 The XLTR (Translator) board's role

**Not considered in any document:** The SBC communicates with the EXEC card through an "XLTR" board (mentioned in `xp32_eu_command_protocol.md` but never analyzed). The XLTR likely performs:
- Bus protocol conversion (Q-bus/UNIBUS to EXEC card internal bus)
- Data width conversion (16-bit SBC words to 80-bit EU PROM words or 128-bit AU WCS words)
- Address mapping

**Why it matters:** The XLTR could be reordering bytes, splitting/combining words, or adding protocol overhead. The assumption that "16 bytes in the staging buffer = one 128-bit microinstruction" may be wrong if the XLTR transforms the data.

**What to do:** Find the XLTR schematics or part number. The FPS Board Revision List (Dec 1989) in `refs/` may list it.

---

### 4.4 The FPS-100 as a missing link

**Not considered in any document:** The FPS-100 (1978) sits between the AP-120B (1976) and the FPS-164 (1981) in the family lineage. Its microinstruction format is documented in the FPS-100 software archive (`fps100_archive/fps100sw/`). Analyzing it would:
- Test the "pure additive extension" hypothesis with a third data point
- Reveal whether the FPS-100 already had some of the fields attributed to the FPS-164
- Show the actual evolution pattern, which may not be purely additive

**Why it matters:** The entire XP-32 inference chain depends on the claimed evolution pattern. Without the FPS-100 data point, the pattern is unsubstantiated.

**What to do:** Extract the FPS-100 microinstruction format from `SIM100.FTN`'s `SPLIT` routine and compare it to the AP-120B format.

---

### 4.5 Alternative: XP-32 could be a clean-sheet design

**Not considered in any document:** The XP-32 might not be an evolution of the AP-120B/FPS-164 at all. Consider:
- The XP-32 uses IEEE-754 32-bit float (vs AP-120B's proprietary 38-bit)
- The XP-32 has a completely different memory hierarchy (TCM + LMD + SCM)
- The XP-32 has an EU/AU split architecture (unique in the family)
- The XP-32's 128-bit microinstruction is twice the width of any predecessor

**Why it matters:** These differences are architectural, not incremental. A clean-sheet design would have no obligation to preserve AP-120B field layouts. The "MAXL compiles to APAL" statement could mean the assembler translates, not that the hardware is compatible.

**What to do:** Consider the hypothesis that XP-32 is a new architecture that happens to share the APAL programming model. This would invalidate most of the inference work.

---

## 5. CONFIDENCE-MISCALIBRATION

### 5.1 HIGH confidence on "what fields exist" — unjustified

**Document:** `inferring_xp32_microcode.md`

**Claim:** "What fields exist? ✓ (yes, with high confidence)"

**Problem:** This is stated as "high confidence" but depends on the "pure additive extension" pattern, which is based on only two data points (AP-120B and FPS-164). The document itself admits the FPS-100 is not analyzed. The XP-32 could have a completely different field taxonomy.

**Correct calibration:** "What fields exist? ⚠ (plausible inference from family lineage, but unconfirmed — XP-32 may have a different taxonomy)"

---

### 5.2 HIGH confidence on "groups they're in" — unjustified

**Document:** `inferring_xp32_microcode.md`

**Claim:** "What groups they're in? ✓"

**Problem:** The group structure (S-Pad, Adder, Branch, Data Pad, Multiplier, Memory) is derived from the AP-120B's 64-bit format. The XP-32 has 128 bits and new functional units (second adder, DMA controller). There is no evidence that the group structure is preserved — the new units could be in completely different groups, or the grouping could be reorganized.

**Correct calibration:** "What groups they're in? ⚠ (inherited groups likely preserved, but new groups for DMA and second adder could be placed anywhere)"

---

### 5.3 LOW confidence on "EU PROM read is the only way" — understated

**Document:** `inferring_xp32_microcode.md`

**Claim:** "The PROM read is the only way to settle the question definitively" (paraphrased from the erratum and Path 2 discussion).

**Problem:** This understates the value of the EU PROM. The EU PROM contains the actual microcode that controls the Am29116 and the Am2910 microsequencer. Reading it would reveal:
- The exact EU microinstruction format (80-bit)
- The panel-command dispatch table (which PROM addresses correspond to which commands)
- The WCS write protocol (how the EU writes to AU WCS)
- The EU/AU synchronization mechanism
- The status word encoding

This is far more valuable than the document suggests. The document estimates 100-150 hours for "a working AU microinstruction layout" from the PROM, but the PROM would also give the EU layout, the command protocol, and the synchronization mechanism — essentially the entire control architecture.

**Correct calibration:** "The EU PROM read is the single highest-value task. It would resolve most unknowns about both EU and AU architectures, not just the AU layout."

---

### 5.4 HIGH confidence on "AP-120B field layout is definitive" — overconfident

**Document:** `xp32_opcode_clues.md`

**Claim:** "The AP-120B baseline (authoritative)... Encoding is solid."

**Problem:** The document cites FPS-7319 Vol 2 Appendix E and SIM100.FTN's SPLIT routine as definitive. However:
- The FPS-7319 document describes the AP-120B, not the FPS-100 or FPS-164
- The SIM100.FTN SPLIT routine may have bugs or version-specific differences
- The recovered FFT microcode was transcribed by hand from a dot-matrix printout — the document admits Tesseract and EasyOCR failed, and transcription was manual. Human error in 227 instructions × 4 words = 908 16-bit values is possible.

**Correct calibration:** "The AP-120B field layout is well-documented and cross-validated, but the transcribed microcode should be independently verified against the original PDF before being treated as ground truth."

---

## Summary of Critical Issues

| # | Issue | Severity | Documents Affected |
|---|---|---|---|
| 1 | Panel commands are NOT Am29116 instructions (fundamental architectural error) | **CRITICAL** | `xp32_microcode_format_inferred.md`, `xp32_eu_command_protocol.md` |
| 2 | EU PROM vs WCS upload path contradiction | **HIGH** | `xp32_microcode_format_inferred.md` vs `xp32_eu_command_protocol.md` |
| 3 | Am29116 role contradiction (embedded in AU microcode vs separate PROM) | **HIGH** | `xp32_microcode_format_inferred.md` |
| 4 | "Pure additive extension" pattern based on only 2 data points | **HIGH** | `xp32_opcode_clues.md`, `inferring_xp32_microcode.md` |
| 5 | "MAXL compiles to APAL" overinterpreted as microarchitecture constraint | **HIGH** | `inferring_xp32_microcode.md`, `xp32_opcode_clues.md` |
| 6 | FPS-164 microinstruction width misstated (variable, not fixed 64-bit) | **MEDIUM** | `inferring_xp32_microcode.md`, `xp32_opcode_clues.md` |
| 7 | AP-120B microinstruction word-boundary model is wrong | **MEDIUM** | `ap120b_ffttest_ucode.md` |
| 8 | Bit-budget analysis internally inconsistent | **MEDIUM** | `inferring_xp32_microcode.md` |
| 9 | Panel-command bit-field hypothesis contradicted by own data | **MEDIUM** | `xp32_eu_command_protocol.md` |
| 10 | Missing: Am2910/Am2911 microsequencer, PAL decoders, XLTR role | **MEDIUM** | All documents |

## Recommended Corrections

1. **Rewrite `xp32_microcode_format_inferred.md`** to remove the "W0 = Am29116 instruction" claim. Replace with a correct description: the 128-bit AU microinstruction controls the arithmetic pipelines (FP adders, multiplier, DMA controller, memory addressing). The EU runs independently from its own 80-bit PROM.

2. **Reconcile `xp32_eu_command_protocol.md` and `xp32_microcode_format_inferred.md`** to present a consistent architecture: SBC → panel command → EU PROM sequencer → EU executes PROM microcode → EU writes to AU WCS via dedicated hardware.

3. **Add an FPS-100 microinstruction format analysis** to test the "pure additive extension" hypothesis with a third data point. The SIM100.FTN SPLIT routine in the FPS-100 archive is the key resource.

4. **Lower confidence claims** on XP-32 field taxonomy, group structure, and encoding preservation. Label all inferences as "plausible but unconfirmed" until the EU PROM is read or an XP-32 reference manual is found.

5. **Raise the priority of the EU PROM read** — it is the single most valuable task, not just one of several paths. It would resolve the fundamental architectural questions that the current documents get wrong.
```

### C_microcode — GLM (73.6s)

```
# Critical Audit: FPS-3000/XP-32 Microcode Reverse Engineering

## 1. INACCURACIES

### Document: `inferring_xp32_microcode.md`
- **Wrong claim**: "inheritance from AP-120B → FPS-164 was purely additive — AP-120B every field name carries through with same widths or wider"
- **Correction**: While APSIM64 Appendix A shows field extensions, there is no evidence that evolution was "purely additive." The document doesn't account for possible field repurposing, encoding changes, or semantic shifts between generations. The FPS-164's secondary parcel structure and overlay mechanisms represent non-additive design choices that affect field interpretation.

### Document: `xp32_opcode_clues.md`
- **Wrong claim**: "no XP32 microinstruction reference manual exists publicly"
- **Correction**: This claim requires stronger documentation of the search methodology. While the search log documents comprehensive efforts, it doesn't exhaustively prove that *every possible repository* has been checked, particularly institutional archives, former customer sites, or private collections that might hold undocumented copies.

### Document: `xp32_microcode_format_inferred.md`
- **Wrong claim**: "The arithmetic checks out" in the 128-bit budget allocation
- **Correction**: The addition (~128 bits) is approximate and doesn't account for potential overlap between fields or engineering realities of bus width vs. actual implementation. The document states the total is "close enough" but provides no evidence for this tolerance level.

## 2. INTERNAL CONTRADICTIONS

### Document: `inferring_xp32_microcode.md`
- **Contradiction**: The document claims high confidence in field structure ("What fields exist? ✓ (yes, with high confidence)") while acknowledging fundamental uncertainties about bit positions, sub-field encodings, and asymmetries between functional units.
  - Quote 1: "we can infer the structure is straightforward; inferring the encoding is not"
  - Quote 2: "What fields exist? ✓ (yes, with high confidence)"
- **Resolution**: The field *taxonomy* can be inferred with confidence, but the actual *encoding* (bit positions, values) cannot be, yet the document presents these as separate questions without clearly distinguishing between them.

### Document: `xp32_microcode_format_inferred.md`
- **Contradiction**: Initial interpretation of SBC's upload path targeting EU PROM vs. later correction that EU runs from fixed mask PROM.
  - Quote 1 (initial): "the SBC's S-record upload path that stages exactly 64 KB at `0x10000–0x1FFFF` (= one bank); each microinstruction = 16 bytes"
  - Quote 2 (corrected): "Hockney figure 2.53 + chassis-photo confirmation later clarified that the **EU runs from a fixed 2K × 80-bit mask PROM** on the EXEC card; only the AU's 4K × 128-bit × 4 banks of writable control store is host-uploaded"
- **Resolution**: The document correctly self-corrects, but the initial interpretation (treating EU uploadable) significantly affected the entire analysis, suggesting a need for greater initial skepticism about hardware assumptions.

## 3. UNJUSTIFIED CLAIMS

### Document: `xp32_opcode_clues.md`
- **Unjustified claim**: "the XP32 microinstruction is the AP-120B/FPS-164 microinstruction widened to 128 bits to accommodate a second adder, a separate DMA controller..."
- **Problem**: This architectural inference is presented as fact ("the frame I'd stand behind") but lacks sufficient evidence. The document acknowledges speculation ("which of these are actually present, and what their exact widths and positions are, is unknown") but presents the overall picture with unwarranted confidence.
- **Evidence gap**: While Curington 1986 confirms the existence of these features, it doesn't specify their microcode-level implementation or how they're integrated into the 128-bit format.

### Document: `inferring_xp32_microcode.md`
- **Unjustified claim**: "we can write XP-32 microcode that is structurally plausible without any new information"
- **Problem**: This overstates what can be inferred. The document later admits that "we cannot author microcode that is guaranteed to execute correctly on real XP-32 hardware without either" reading the PROM or finding reference manuals.
- **Correction**: The claim should acknowledge that while structural plausibility is possible, functional correctness cannot be guaranteed without implementation details.

### Document: `fps_library_uniformity.md`
- **Unjustified claim**: The FPS math-library interface is "uniform across the family"
- **Problem**: While naming conventions are similar, the document doesn't address potential differences in error handling, precision models, or hardware-specific optimizations that would affect actual usage.
- **Correction**: The interface similarity should be presented as "nominally uniform" with possible implementation differences.

## 4. MISSED VIEWPOINTS

### Document: `inferring_xp32_microcode.md`
- **Missed viewpoint**: Consider that the EU/AU split architecture might necessitate fundamentally different microcode design patterns compared to unified microcode architectures.
  - **Reason**: The documents assume APAL compatibility but don't adequately address how the EU (80-bit PROM) controlling the AU (128-bit WCS) might affect microcode structure, potentially requiring new coordination fields or encoding schemes not present in earlier generations.

### Document: `xp32_opcode_clues.md`
- **Missed viewpoint**: Consider that the microcode evolution might include non-additive changes like field repurposing or semantic shifts.
  - **Reason**: The document assumes "pure additive extension" but doesn't consider that new architectural features might require reusing or reinterpreting existing fields in ways that aren't simple width increases.

### Document: `xp32_microcode_format_inferred.md`
- **Missed viewpoint**: Consider potential endianness or byte reordering in the XLTR/AP-I/F that could affect microinstruction interpretation.
  - **Reason**: The document mentions endianness as unknown but doesn't systematically consider how different byte ordering schemes could affect the functional assignment of words within the 16-byte block.

### Document: `search_log_apal64_refs.md`
- **Missed viewpoint**: Consider that reference manuals might exist in non-obvious locations like former customer sites, university archives, or with FPS alumni who don't actively participate in technical communities.
  - **Reason**: The search focuses on public repositories and known collectors, but doesn't systematically target institutions that likely owned FPS equipment (e.g., oil companies, universities with signal processing labs).

## 5. CONFIDENCE-MISCALIBRATION

### Document: `inferring_xp32_microcode.md`
- **Miscalibration**: High confidence in field structure ("What fields exist? ✓ (yes, with high confidence)") despite acknowledging fundamental uncertainties about bit positions, sub-field encodings, and asymmetries.
  - **Problem**: The confidence assessment doesn't properly distinguish between field existence (which can be inferred) and field encoding (which cannot), leading to an inflated overall confidence rating.

### Document: `xp32_opcode_clues.md`
- **Miscalibration**: Presenting the "pure additive extension" pattern with high confidence ("the frame I'd stand behind") when the evidence is limited.
  - **Problem**: While the additive pattern is observable in the known evolution (AP-120B→FPS-164), extending this to XP-32 requires additional assumptions that aren't well supported by evidence.

### Document: `xp32_eu_command_protocol.md`
- **Miscalibration**: Presenting status-code decoding with low confidence ("What we still can't infer") while actually providing substantial information about the command protocol.
  - **Problem**: The document downplays the value of the protocol analysis while acknowledging that understanding the EU command interface is sufficient to "drive the EU once we have AU microcode loaded," representing an underconfident assessment of its contribution.

### Document: `fps_library_uniformity.md`
- **Miscalibration**: High confidence in uniformity while ignoring potential implementation differences.
  - **Problem**: The document presents naming convention similarity as evidence of full interface compatibility without adequately considering potential differences in behavior or error handling between implementations.

## Summary of Strongest Issues

1. **Overconfidence in additive evolution pattern** across multiple documents - claims about "pure additive" extension aren't sufficiently supported by evidence
2. **Insufficient distinction between field taxonomy and encoding** - what fields exist can be inferred with confidence, but their actual bit positions and values cannot
3. **Missed consideration of EU/AU split architecture** - the separation between control (EU) and execution (AU) units may require fundamentally different microcode design patterns
4. **Unjustified assumptions about microcode width allocation** - the 128-bit budget is presented as more constrained than engineering realities might allow
5. **Underutilization of FPS-100 archive** - the rich dataset from the FPS-100 software archive could provide stronger validation for the evolution hypothesis but isn't fully exploited

The reverse-engineering project would benefit from more rigorous confidence calibration, clearer distinction between what can and cannot be inferred, and deeper consideration of how the EU/AU split architecture might affect microcode design patterns not present in earlier unified microcode architectures.
```

## Cluster D_meta

Documents:
- `README.md`
- `project_plan.md`
- `upstream_repos.md`

### D_meta — DS (81.7s)

```
# Critical Audit: D_meta Document Cluster

## Executive Summary

This cluster represents a substantial reverse-engineering effort on the FPS-3000/XP-32 array processor, with significant recovered artifacts (SBC ROM disassembly, AP-120B microcode corpus, cable netlists). However, the documents contain several serious inaccuracies, internal contradictions, and unjustified claims that undermine confidence in key conclusions. The most critical issues cluster around: (1) the cable signal count and its implications for hardware design, (2) the relationship between AP-120B and XP-32 microarchitectures, and (3) the claimed completeness of the EU PROM reverse-engineering path.

---

## 1. INACCURACIES

### 1.1 The 150-signal cable claim is demonstrably wrong

**Document:** `upstream_repos.md` (and echoed in `project_plan.md`)

**Wrong claim:** "The cable carries ~150 logical signals" and "~200 pins per card" with the implication that ~150 of these are unique logical signals requiring separate FPGA I/O.

**What's actually correct:** The `4448_APIF_netlist.txt` file (which the document itself references) lists **199 pins total across J22 (100) and J23 (99)**. However, a careful reading of the netlist reveals:

- **~40-50 pins are power and ground** (VCC, GND, multiple returns)
- **~20-30 pins are NC (no connect) or spares**
- **Many "signal" pins are redundant or parallel** — e.g., `HD00-HD15` appear on both connectors as the same 16-bit bus, not 32 unique signals
- **The register select lines (REGSEL00-05)** are 6 lines, not 64 — the document's parenthetical "(= 64-reg select)" is correct in addressing space but the physical signals are only 6

The actual unique logical signal count is approximately **70-85**, consistent with the original ~50 estimate plus the parallel buses the document mentions. The jump to "~150" appears to come from double-counting pins that appear on both connectors, counting power/ground as "logical signals," and including NC pins.

**Evidence:** The netlist itself, which the document quotes selectively. A proper count: HD00-15 (16) + DMA00-15 (16) + HST00-15 (16) + PNL08-15 (8) + DA08-15 (8) + REGSEL00-05 (6) + control/handshake (~20) + clocks/reset (~10) = ~100 signals maximum, minus duplicates across connectors = ~75-85 unique.

**Impact:** This error cascades into the hardware recommendation. The document concludes "FPGA is required, Pico is infeasible" based on 150 signals. At ~80 signals, a dual-Pico or Teensy 4.1 + GPIO expander solution remains viable, saving significant cost and development time.

### 1.2 The "FPS-3000 EU PROM is 2K × 80-bit" claim is unverified and likely wrong

**Document:** `project_plan.md`, `xp32_microcode_format_inferred.md`

**Wrong claim:** "The XP-32 EU runs from a fixed 2K × 80-bit PROM" and "2K × 80-bit binary microcode image" as the expected output of reading the PROMs.

**What's actually correct:** The FPS-164 (the closest documented relative) uses a **4K × 64-bit** control store for its EU, not 2K × 80-bit. The XP-32 is described in Hockney & Jesshope as having a "wider" instruction word than the FPS-164, but the EU PROM width is never specified as 80 bits. The 80-bit figure appears to come from:

1. The Am29116 sequencer has a 16-bit instruction word
2. The EU needs to control multiple functional units in parallel
3. Someone added 64 bits of horizontal control to the 16-bit sequencer word = 80 bits

This is arithmetic without evidence. The actual width could be 64, 72, 80, 96, or 128 bits depending on how many functional units the EU directly controls vs. delegates to the AU.

**Evidence:** No FPS-3000/XP-32 documentation anywhere specifies the EU PROM width. The FPS-164 (Touzeau 1984) uses 64-bit microinstructions. The AP-120B uses 64-bit. The FPS-5000 series (which includes the XP-32) is described as having "128-bit" microinstructions in the AU, but the EU PROM width is a separate question.

**Impact:** The entire B.1 reverse-engineering plan assumes 2K × 80-bit. If the PROM is actually 4K × 64-bit, the reading hardware, disassembler, and inference methodology all need adjustment. The document should acknowledge this uncertainty and plan for multiple possible widths.

### 1.3 The "4448 netlist matches FPS-3000 card" claim is premature

**Document:** `upstream_repos.md`, `project_plan.md`

**Wrong claim:** "Lovett's FPS-3000-era 612-4448-401-F is the next-generation revision in the same card family; pinout almost certainly identical or trivially mappable."

**What's actually correct:** The 4448 is an **AP-120B/FPS-100 era** card. The FPS-3000 uses card **612-4448-401-F**, which has a different suffix (-401-F vs. the base 4448). The FPS-3000 was a complete architectural redesign (different host interface protocol, different bus structure, different microarchitecture). There is **no evidence** that the connector pinout is compatible.

**Evidence:** 
- The FPS-100 used UNIBUS; the FPS-3000 used Q-bus. These have different signal sets.
- The FPS-100's host protocol (documented in `host_to_fps100_protocol.md`) uses 6 UNIBUS registers; the FPS-3000 uses a different register set at `0xFF0000+`.
- The FPS-3000 SBC firmware (in `fps3k_clean.asm`) shows a completely different command protocol than the FPS-100's `DRIVER.MAC`.

**Impact:** The document claims "the B1 bench task may already be answered" — this is dangerously overconfident. The netlist is a useful reference but must be validated against the actual FPS-3000 card before any hardware design proceeds.

---

## 2. INTERNAL CONTRADICTIONS

### 2.1 Cable signal count: 50 vs. 150 vs. 80

**Contradiction across documents:**

- `project_plan.md` (original estimate): "~50 logical signals" for the cable
- `upstream_repos.md`: "~150 logical signals" after reading the netlist
- `upstream_repos.md` (netlist table): lists approximately 80-100 unique signal names in the table, many of which are duplicates across connectors

The document explicitly says "The cable carries ~150 logical signals (much wider than my earlier ~50 estimate)" but then provides a table that sums to far fewer unique signals. The 150 figure appears to be a misreading of the netlist's 199 total pins.

**Resolution needed:** A proper unique-signal count from the netlist, distinguishing between physical pins and logical signals.

### 2.2 EU PROM: fixed vs. writable characterization

**Contradiction within `xp32_microcode_format_inferred.md`:**

The document states: "the EU portion is pinned mask-PROM, the AU is the writable target" but also describes the EU as having "writable control store" in some passages.

More critically, `project_plan.md` says the EU runs "fixed mask-PROM microcode at power-on" but the B.1 reverse-engineering plan assumes the PROM can be read and modified. If it's truly a mask PROM (manufactured with the microcode hard-wired), it cannot be reprogrammed — only read. The document conflates "mask-programmed ROM" (which is what mask PROM means) with "field-programmable PROM" (which can be read and potentially rewritten).

**Resolution needed:** Clarify whether the EU store is mask-ROM (unchangeable, readable only) or field-programmable PROM (readable and potentially rewritable). The Am29116 sequencer typically uses bipolar PROMs that are field-programmable, but the document's language suggests mask-programmed parts.

### 2.3 AP-120B emulator capability

**Contradiction between `upstream_repos.md` and `project_plan.md`:**

- `upstream_repos.md` (citing `nova_fps.c`): "Phase 1 implementation: host interface + memory + DMA + panel commands. No AP microcode execution yet"
- `project_plan.md`: Lists `nova_fps.c` as usable for "Objective B (microcode-execution sim)" and "validate microcode behaviour offline"

The document explicitly states the emulator doesn't execute microcode, then immediately lists it as a microcode execution simulator. This is a direct contradiction.

**Resolution needed:** The `python-sim100` simulator (from `roy20100`) does execute microcode; `nova_fps.c` does not. The project plan should correctly attribute capabilities.

---

## 3. UNJUSTIFIED CLAIMS

### 3.1 XP-32 microinstruction format is "FPS-164 widened"

**Document:** `xp32_opcode_clues.md`, `project_plan.md`

**Claim:** "XP-32 is a structured widening of [the FPS-164 layout]" and "Strong inference that XP-32 is 'FPS-164 widened'"

**Problem:** There is **no evidence** that the XP-32 microinstruction format is derived from the FPS-164. The FPS-5000 series (which includes the XP-32) was a completely new design, not an evolution of the FPS-164. Key differences:

- FPS-164: 64-bit microinstructions, proprietary 64-bit floating-point format
- XP-32: 128-bit microinstructions, IEEE-754 32-bit floating-point
- FPS-164: ECL logic, water-cooled in some configurations
- XP-32: TTL logic, air-cooled

The document's reasoning appears to be: "Both are FPS machines, both have horizontal microcode, therefore one is an extension of the other." This is cargo-cult reasoning. The FPS-5000 was a ground-up redesign to compete with mini-supercomputers like the Convex C1.

**Evidence needed:** Any architectural document showing the XP-32's microinstruction format. The document admits "exact positions unverified" but then proceeds as if the inference is solid enough for microcode authoring.

**Impact:** If the XP-32 format is not FPS-164-derived, the entire B.2 approach (author microcode by analogy) will produce non-functional code. The failure modes will be confusing and hard to debug because the bit positions will be wrong in unpredictable ways.

### 3.2 The "Am29116 disassembler is straightforward" claim

**Document:** `project_plan.md`

**Claim:** "D2 (Am29116 disassembler) ~30 hours" and "implements the AMD Am29116 datasheet ISA — ready to decode the EU PROM contents the moment they're read"

**Problem:** The Am29116 is a **bit-slice processor** whose instruction set is not a simple opcode map. Key complications:

- The Am29116 has **no fixed instruction format** — the 16-bit instruction word is interpreted differently depending on the microinstruction context (the "microinstruction" is wider than 16 bits and includes control bits for the sequencer)
- The Am29116 is typically used as part of a microprogrammed sequencer where the instruction is decoded by external logic (PROMs, PALs) that the document hasn't reverse-engineered
- The AMD datasheet describes the Am29116's ALU and register file operations, but the actual instruction set depends on how the chip is wired into the system

**Evidence:** The AMD Am29116 datasheet (available on Bitsavers) shows that the chip has 16-bit instructions but the mapping to operations depends on external microcode sequencing logic. Without knowing the external decode logic, a "disassembler" can only produce raw field decodes, not meaningful instruction mnemonics.

**Impact:** The 30-hour estimate is optimistic by at least 2-3x. The disassembler will need to be developed iteratively as the EU PROM contents are read and the external decode logic is understood.

### 3.3 The "EU PROM read is 1-4 hours" claim

**Document:** `project_plan.md`

**Claim:** "PROM read: 1-4 hours with a vintage PROM programmer + adapter for the specific bipolar PROM type FPS used"

**Problem:** This assumes:
1. The PROM type is known (it isn't — the document says "visual ID" is a separate task)
2. A compatible programmer exists and works
3. The PROMs are socketed and easily removable
4. The PROMs are not protected (some FPS parts had security fuses)

The FPS-3000 is from the mid-1980s. Bipolar PROMs from that era include 82S131, 82S137, 82S191, 53/63S081, and many others, each requiring different programming adapters. Some are in 20-pin DIP, others in 24-pin, some in PLCC. The document acknowledges "identify a working PROM-programmer + adapter combo" but then estimates 1-4 hours for the read.

**Evidence:** The FPS Board Revision List (Dec 1989) referenced in the document lists many board revisions but doesn't specify PROM types. Vintage PROM programming is notoriously finicky — even with the right programmer, some PROMs have degraded over 40 years.

**Impact:** A more realistic estimate is 1-2 weeks for identification, adapter sourcing, and read attempts, with a non-trivial chance that some PROMs are unreadable.

---

## 4. MISSED VIEWPOINTS

### 4.1 The host-side AP I/F card may not be Q-bus

**Missed consideration:** The document assumes the missing host-side card is `612-4012-003 Q22 BUS ADPTR FPS3000/5000` — a Q-bus card. However, the FPS-3000 was also sold with VAX (UNIBUS) and IBM host interfaces. The Bomem DA3 system used a PDP-11/73 (Q-bus), but the specific card in Lovett's chassis might be different.

**Why this matters:** If the host interface is UNIBUS rather than Q-bus, the substitute card design changes significantly (different signal levels, different DMA protocol, different interrupt handling). The document should consider the possibility that the missing card is not Q-bus and plan for multiple host bus types.

### 4.2 The SBC firmware may have Bomem-specific modifications

**Missed consideration:** The SBC ROM (`FPS3K_U11_U12_JOIN.bin`) came from a Bomem DA3 system. Bomem was known to customize FPS firmware for their FTIR instruments. The document treats the ROM as "standard FPS-3000 firmware" but it may contain Bomem-specific extensions, bug fixes, or workarounds.

**Why this matters:** If the ROM is customized, the reverse-engineered protocol may not match standard FPS-3000 behavior. Commands that work on this ROM might fail on a different FPS-3000, and vice versa. The document should note this uncertainty and ideally compare against a second FPS-3000 ROM if available.

### 4.3 The XP-32 may have multiple EU PROM variants

**Missed consideration:** The document assumes a single EU PROM type across all XP-32 configurations. However, the FPS-5000 series had multiple AC (Arithmetic/Control) configurations — the document mentions "2-AC configuration" for Lovett's chassis but the firmware exposes 4 channels. Different AC types (AC1 vs AC2) might have different EU PROMs.

**Why this matters:** If the two ACs in Lovett's chassis have different EU PROMs (e.g., one optimized for addition, one for multiplication), the reverse-engineering must handle both. Reading only one PROM and assuming it represents all EU microcode would be a significant error.

### 4.4 The AU microcode upload path may have security/validation checks

**Missed consideration:** The document describes the S-record upload path as straightforward: "SBC RAM 0x10000–0x1FFFF ← 64 KB staging buffer = one WCS bank" followed by DMA to the XP-32. However, the SBC firmware may validate the uploaded microcode (checksums, signature verification, or format checks) before allowing execution.

**Why this matters:** If the firmware rejects non-standard microcode (e.g., microcode that doesn't match expected patterns), the B.2 approach of "upload, run, observe failure mode, adjust" will fail at the upload stage, not the execution stage. The failure mode would be misleading — the document would conclude the microcode format is wrong when actually the upload was rejected.

### 4.5 The FPS-3000 may use a different float format than IEEE-754

**Missed consideration:** The document states "XP-32 BUS (32-bit IEEE-754)" but the FPS-5000 series was designed before IEEE-754 was universally adopted (IEEE-754 was standardized in 1985; the FPS-3000 was introduced around 1986). FPS historically used proprietary floating-point formats (38-bit in the AP-120B, 64-bit in the FPS-164).

**Why this matters:** If the XP-32 uses a proprietary 32-bit float format (e.g., 1-8-23 with different bias or normalization), IEEE-754 data uploaded from the host would produce incorrect results even with correct microcode. The document should verify the float format before assuming IEEE-754 compatibility.

---

## 5. CONFIDENCE-MISCALIBRATION

### 5.1 HIGH confidence on the cable netlist compatibility (unjustified)

**Document:** `upstream_repos.md`, `project_plan.md`

**Claim:** "The 4448 APIF netlist already documents the connector pinout. Validation that Lovett's 612-4448-401-F matches the AP-120B-era 4448 layout is the only remaining bench step (visual inspection — minutes)."

**Confidence level stated:** Very high — presented as a solved problem with only "validation" remaining.

**Actual confidence warranted:** Low to moderate. The 4448 is an AP-120B card; the 612-4448-401-F is an FPS-3000 card. They share a base number but have different suffixes, different eras, and different system architectures. The pinout could be completely different. Even if the connector is physically identical, the signal assignments may have changed.

**Correction:** This should be presented as a hypothesis to be tested, not a conclusion. The bench task should be described as "determine if the pinout matches" rather than "validate that it matches."

### 5.2 HIGH confidence on the XP-32 microinstruction format inference (unjustified)

**Document:** `xp32_opcode_clues.md`, `project_plan.md`

**Claim:** "The bit-level FPS-164 layout is now pinned; XP-32 is a structured widening of it" and "provisional encoding for hand-authoring trial kernels"

**Confidence level stated:** High enough to begin microcode authoring.

**Actual confidence warranted:** Very low. There is no evidence that the XP-32 format is derived from the FPS-164. The two machines have different word widths, different float formats, different logic families, and different design philosophies. The "widening" claim is speculation.

**Correction:** The document should explicitly state that the XP-32 microinstruction format is **unknown** and that the FPS-164 format is used only as a starting point for exploration, with the understanding that the actual format may be completely different.

### 5.3 LOW confidence on the "EU PROM read is feasible" claim (understated risk)

**Document:** `project_plan.md`

**Claim:** "B.1 first because it's deterministic and the PROM read is cheap" and "Hit rate: very high if the PROM can be read."

**Confidence level stated:** High for the PROM read being feasible.

**Actual confidence warranted:** Moderate at best. The document acknowledges "identify a working PROM-programmer + adapter combo" as a prerequisite but doesn't discuss the significant risks: PROM degradation over 40 years, incompatible programmers, security fuses, or the possibility that the PROMs are soldered (not socketed).

**Correction:** The risk assessment should include: (1) probability that PROMs are unreadable (maybe 20-30%), (2) probability that PROMs are soldered (maybe 40-50% for production hardware), (3) time and cost to source alternative reading methods.

### 5.4 LOW confidence on the "500 engineering hours" estimate (overly precise)

**Document:** `project_plan.md`

**Claim:** "Total ~500 engineering hours" with per-task breakdowns to the hour.

**Confidence level stated:** Precise enough for project planning.

**Actual confidence warranted:** Very low. The estimate is based on:
- Unknown hardware (PROM types, cable compatibility, EU microarchitecture)
- Unvalidated assumptions (microinstruction format, float format, firmware customization)
- Optimistic tooling estimates (30-hour Am29116 disassembler, 50-hour AU layout inference)

A realistic estimate would be 800-1200 hours with a wide error bar (±50%).

**Correction:** The document should present the estimate as a rough order of magnitude (500-1500 hours) with explicit acknowledgment of the major uncertainties.

---

## Summary of Critical Issues

| # | Issue | Severity | Documents Affected |
|---|---|---|---|
| 1 | Cable signal count inflated from ~80 to ~150 | High | `upstream_repos.md`, `project_plan.md` |
| 2 | EU PROM width (2K×80) unverified | High | `project_plan.md`, `xp32_microcode_format_inferred.md` |
| 3 | 4448 netlist ≠ FPS-3000 card pinout | High | `upstream_repos.md`, `project_plan.md` |
| 4 | XP-32 = "FPS-164 widened" is speculation | Critical | `xp32_opcode_clues.md`, `project_plan.md` |
| 5 | Am29116 disassembler complexity underestimated | Medium | `project_plan.md` |
| 6 | EU PROM read feasibility overestimated | Medium | `project_plan.md` |
| 7 | AP-120B emulator ≠ microcode simulator | Medium | `upstream_repos.md`, `project_plan.md` |
| 8 | Host interface type assumed (Q-bus) | Medium | `project_plan.md` |
| 9 | SBC firmware may be Bomem-customized | Low-Medium | `README.md`, `project_plan.md` |
| 10 | Float format assumed IEEE-754 | Medium | `README.md`, `xp32_opcode_clues.md` |

**Most critical finding:** The entire Objective B approach (author XP-32 microcode by extending FPS-164 format) is based on an unverified assumption. If the XP-32 microinstruction format is not FPS-164-derived, the B.2 approach will produce non-functional code and the failure modes will be uninformative. The document should prioritize PROM reading (B.1) and treat B.2 as a fallback, not a parallel path.

**Most actionable finding:** The cable signal count error (issue #1) has cascading effects on hardware recommendations. Correcting this from ~150 to ~80 signals opens up simpler, cheaper hardware options (dual-Pico, Teensy + expander) that should be evaluated before committing to an FPGA.
```

### D_meta — GLM (78.8s)

```
# Critical Audit: FPS-3000/XP-32 Restoration Project

## INACCURACIES

1. **README.md**
   - **Claim**: "This microcode is for the AP-120B/FPS-100, *not* the XP32 — the two have different microinstruction widths (64 vs 128 bit) and float formats (FPS proprietary 38-bit vs IEEE-754 32-bit)."
   - **Problem**: The microinstruction width difference is correct, but the float format claim is partially inaccurate. While the AP-120B used a proprietary 38-bit format, the XP-32 actually used IEEE-754 32-bit format. The claim that XP-32 *only* used IEEE-754 32-bit is unsupported - FPS systems typically supported multiple formats.
   - **Correction**: "The microcode is for the AP-120B/FPS-100, not the XP-32 — they have different microinstruction widths (64 vs 128 bits). The AP-120B used a proprietary 38-bit float format, while the XP-32 used IEEE-754 32-bit as its primary format but likely supported other formats as well."

2. **project_plan.md**
   - **Claim**: "The cable carries ~150 logical signals (much wider than my earlier ~50 estimate)..."
   - **Problem**: This contradicts the upstream_repos.md which shows the actual 4448_APIF_netlist.txt documents ~200 pins across J22 and J23 connectors.
   - **Correction**: "The cable carries ~200 logical signals (much wider than my earlier ~50 estimate), as documented in the 4448_APIF_netlist.txt..."

## INTERNAL CONTRADICTIONS

1. **Signal count inconsistency**
   - **upstream_repos.md**: "The cable carries ~150 logical signals... based on naming: J22: A1-A100 (100 pins) and J23: B1-B99 (99 pins) - Total ~200 pins per card"
   - **upstream_repos.md**: "The cable carries ~150 logical signals"
   - **Contradiction**: The same document claims both ~200 pins and ~150 signals without explanation of which pins are not active signals.

2. **Chassis model inconsistency**
   - **README.md**: Describes the system as "FPS-3000 / XP32" and "FPS-3000 chassis, model 833-2003-004"
   - **README.md**: Mentions "AP-120B/FPS-100" systems in the context of microcode differences
   - **Contradiction**: While not a direct contradiction, the model numbering (833-2003-004 vs 612-4448-401-F for the AP I/F card) suggests these are different components of the system, but the relationship isn't clearly explained.

## UNJUSTIFIED CLAIMS

1. **project_plan.md**
   - **Claim**: "FPS-3000-era host driver software is missing (FPS-100 ancestor exists in fps100_archive/, but the FPS-3000 driver was a different rewrite)"
   - **Problem**: This is stated as fact without evidence. The project should search for or attempt to recover the actual FPS-3000 driver before declaring it definitively different.
   - **Correction**: "FPS-3000-era host driver software appears to be missing. While the FPS-100 ancestor exists in fps100_archive/, we need to verify whether the FPS-3000 driver was a different rewrite."

2. **upstream_repos.md**
   - **Claim**: "The 4448 APIF netlist already documents the connector pinout. FPS-3000-era 612-4448-401-F is a later revision of the same card type; pinout very likely compatible."
   - **Problem**: This assumes compatibility without direct evidence. While reasonable, it should be validated rather than assumed.
   - **Correction**: "The 4448 APIF netlist documents the connector pinout for the AP-120B-era card. We need to validate whether the FPS-3000-era 612-4448-401-F, as a later revision of the same card type, maintains pinout compatibility."

3. **README.md**
   - **Claim**: "The EU portion is pinned mask-PROM, the AU is the writable target."
   - **Problem**: High confidence without direct evidence for the FPS-3000 specifically.
   - **Correction**: "Based on FPS family architecture patterns, the EU portion is likely a pinned mask-PROM while the AU is the writable target, but this needs verification through hardware inspection."

## MISSED VIEWPOINTS

1. **Bomem customization impact**
   - **Issue**: The documents don't consider potential firmware modifications by Bomem (the company that customized the system for FTIR).
   - **Recommendation**: "Consider examining the firmware for Bomem-specific modifications that might alter standard FPS-3000 behavior, as customizations could affect reverse-engineering efforts."

2. **Alternative host systems**
   - **Issue**: Project focuses exclusively on PDP-11/73 as the host.
   - **Recommendation**: "Consider that FPS-3000 systems might have been used with other hosts (VAX, IBM, etc.). Understanding the full host ecosystem could provide additional architectural insights."

3. **Security implications**
   - **Issue**: No consideration of potential undocumented features or vulnerabilities.
   - **Recommendation**: "Consider potential security implications, such as undocumented backdoors or privilege escalation paths in the microcode that should be identified during reverse-engineering."

## CONFIDENCE-MISCALIBRATION

1. **upstream_repos.md**
   - **Claim**: "The 4448 APIF netlist already documents the connector pinout... FPS-3000-era 612-4448-401-F is a later revision of the same card type; pinout very likely compatible."
   - **Problem**: High confidence ("very likely") without direct evidence.
   - **Correction**: "The 4448 APIF netlist documents the connector pinout for the AP-120B-era card. While the FPS-3000-era 612-4448-401-F is likely compatible as a later revision, we should validate this assumption rather than treating it as certain."

2. **project_plan.md**
   - **Claim**: "The cable carries ~150 logical signals..."
   - **Problem**: Confidence expressed when actual cable has ~200 pins, suggesting potential overconfidence.
   - **Correction**: "Based on the 4448_APIF_netlist.txt, the cable carries approximately 200 logical signals..."

3. **README.md**
   - **Claim**: "The EU portion is pinned mask-PROM, the AU is the writable target."
   - **Problem**: High confidence without direct verification for FPS-3000 specifically.
   - **Correction**: "Consistent with FPS architecture patterns, the EU portion is believed to be a pinned mask-PROM while the AU serves as the writable target, but this requires hardware verification."

## SUMMARY OF STRONGEST ISSUES

1. **Signal count inconsistency**: Documents claim both ~150 and ~200 signals for the cable without reconciliation.

2. **Unverified hardware compatibility**: Assumption that FPS-3000-era AP I/F card is compatible with AP-120B-era netlist needs validation.

3. **Unsubstantiated driver difference**: Claim that FPS-3000 driver is definitively different from FPS-100 lacks evidence.

4. **Missed Bomem customizations**: Potential firmware modifications by the end-user company aren't considered.

5. **Overconfident architecture claims**: EU/AU implementation details presented with high confidence without direct verification.

6. **Incomplete host ecosystem**: Project narrowly focused on PDP-11/73 while ignoring other potential hosts.

7. **Potential firmware address mismatch**: Claim that SBC firmware maps to 0xF00000 conflicts with typical 68000 memory maps.

8. **Security considerations**: Undocumented features or vulnerabilities in the microcode aren't examined.

These issues represent significant gaps in the project's approach and should be addressed to ensure accurate reverse-engineering of the FPS-3000/XP-32 system.
```

