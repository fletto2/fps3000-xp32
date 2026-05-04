# FPS-3000 / XP-32 — focused project plan

Two objectives, in priority order:

> **A.** Get a PDP-11/73 talking to the FPS-3000 chassis at the
> bus level. End state: SBC firmware accepts commands from the
> /73, host can do `XPSEL` / `XPDMAR` / `XPRUN` / `XPWAIT`.
>
> **B.** Get working microcode running on at least one XP-32 AU.
> End state: a small FP test (e.g. ZVMUL on a 16-element vector)
> executes correctly end-to-end and the host can read results back.

Bomem-specific things (HPVP / DA3 / IV2DRV / BOMRES / etc.) are
**out of scope** — they're application-layer stuff that sits on
top of the two objectives above.

## What's already in hand

### Hardware
- **FPS-3000 chassis**, model `833-2003-004` rev B,
  configured 2-AC (slot 11 AP I/F + slots 7-10 two XP-32 ARITH+EXEC
  pairs + slot 13 XLTR + slot 14 SBC + slots 1-6 memory)
- **SBC** (M68KVM02 + ROM `FPS3K_U11_U12_JOIN.bin`) functional
- **AP I/F chassis-side card** = `612-4448-401-F` confirmed
- **PDP-11/73** as the intended host

### Software / docs already recovered
| Resource | Location | Used for |
|---|---|---|
| SBC ROM disassembly (~22 K lines) | `fps3k_clean.asm` | Objective A — protocol on SBC side |
| MC-derived annotations (644) | merged into clean asm | Objective A |
| AP I/F protocol doc | `host_to_sbc_communication.md` | Objective A |
| XLTR↔XP-32 protocol doc | `xltr_protocol.md` + `xp32_eu_command_protocol.md` | Objectives A + B |
| AP-120B field tables (FPS-7319) | `refs/AP-120B/` | Objective B |
| FPS-164 instruction layout (Touzeau 1984 fig 2) | `refs/FPS-164/Touzeau...pdf` | Objective B |
| 217 AP-120B HSR microcode kernels | `hsr_decoded/` | Objective B (reference corpus) |
| AP-120B FFT identity-test microcode | `ucode_transcribed.py` | Objective B (validation) |
| FPS-3000 EU PROM | physically on EXEC card | **read-out pending** |
| FPS Board Revision List (Dec 1989) | `refs/FPS_Board_Revision_List_198912.pdf` | Both — P/N reference |

### Known unknowns
- **Host-side AP I/F card** (the matching `612-4012-003 Q22 BUS
  ADPTR FPS3000/5000`) is missing
- **Cable** between host-side and chassis-side AP I/F is missing
- **FPS-3000-era host driver software** is missing (FPS-100
  ancestor exists in `fps100_archive/`, but the FPS-3000 driver
  was a different rewrite)
- **XP-32-specific microinstruction bit-position layout** —
  inferred to be FPS-164 + extra adder + DMA-controller fields,
  but exact positions unverified
- **XP-32 EU PROM contents** — extractable from Lovett's hardware

---

## Objective A — PDP-11/73 ↔ FPS-3000

### What the path looks like

```
PDP-11/73 (Q-bus)
   │
   │ Q-bus signals
   ▼
[ host-side AP I/F card ]   ← THIS IS THE GAP
   │
   │ FPS proprietary cable (~40-50 conductors)
   ▼
[ chassis-side AP I/F = 612-4448-401-F ]   ← Lovett has this
   │
   │ VersaBUS
   ▼
SBC + XLTR + XP-32s
```

### Three sub-paths

#### A.1 Find an original `612-4012-003` host-side card

The "ideal" path. The card existed (catalog confirms) and was
shipped with FPS-3000 systems paired with PDP-11/23/73/83 hosts.
Currently zero online presence in any inventory channel.

Effort: weeks-to-years of searching (eBay alerts + VCFed thread
+ direct outreach). Hit rate: random surfacing of estate sales.
Cost if found: probably $0–500 (vintage hardware from estates).

#### A.2 Build a substitute host-side card with modern hardware

Practical retrocomputing path. Requires:

1. **Reverse-engineer the cable protocol** between host-side and
   chassis-side AP I/F. This is *the* critical-path step — once
   the protocol is known, the host-side hardware can be anything
   that sources/sinks the right signals.
   - Start: probe Lovett's chassis-side AP I/F connector pinout
     with multimeter (continuity to known VersaBUS pins on the
     card edge, identify ground/power/data/control)
   - Then: logic-analyzer captures during SBC boot and during
     panel-init sequence (SBC pokes registers even with no host
     attached — `0x276..0x27D` boot codes → XLTR responses
     visible across cable interface)
   - Cross-reference: FPS-100's `IOP-UNI` UNIBUS interface (we
     have the FPS-100 protocol fully documented — likely
     similar architecture, the cable signals probably evolved
     directly from it)

2. **Implement the cable-protocol on a modern board**:
   - **FPGA option**: Cyclone IV / Spartan-3 small dev board.
     20-50 hours of HDL work for a register-bus extender
     equivalent.
   - **Microcontroller option**: Teensy 4.1 / RP2040. Easier to
     program (C/Python) but slower; OK for low-speed register
     pokes. Probably not fast enough for actual DMA but
     sufficient for command/control validation.

3. **Connect the modern board to the PDP-11/73**: easiest via
   USB or Ethernet. The /73 runs RSX-11M+ or RT-11; a small
   custom driver pokes the modern board which acts as a Q-bus
   peripheral OR (simpler) the modern board is a USB device
   driven from a PC and the /73 is bypassed for early bring-up.

Effort: ~100 engineering hours (LA captures, FPGA/MCU bring-up,
cable wiring, validation). Hit rate: deterministic if Lovett can
get logic-analyzer captures.

#### A.3 Bypass the AP I/F entirely

Skip the host-side hardware. Plug a custom VersaBUS card into a
free slot of the FPS-3000 chassis that presents itself to the SBC
as the AP I/F at `0xFF0000+`. Modern interface (USB/Ethernet) on
the other side feeds the simulated AP-I/F register file.

Effort: more than A.2 because needs both VersaBUS spec compliance
AND simulating the AP I/F register-file behaviour exactly enough
to fool the SBC firmware.

**Recommendation**: pursue **A.2** as primary. The cable-protocol
reverse engineering is a self-contained achievable milestone, and
once done, both A.2 (substitute host card) and A.3 (substitute
chassis-card) become buildable. So the LA-capture work pays for
either.

### Critical-path next step for Objective A

**Get a logic-analyzer capture of the chassis-side AP I/F connector
pins during SBC boot + panel-init (`0x276..0x27D`)**, with the
SBC running its existing ROM firmware, no host attached. The
boot-init sequence pokes the AP I/F registers with predictable
patterns, so the bus traffic is decodable even without
documentation.

---

## Objective B — Working XP-32 microcode

### What the path looks like

```
SBC (running this ROM)  ←  panel commands  ─→  XLTR  ─→  XP-32 EU
                                                          │
                                                          ▼
                                                       AU WCS  ← microcode here
```

Two halves:
- **EU side**: runs from fixed PROM, reverse-engineerable from
  Am29116 instruction stream (PROM is mask, but readable)
- **AU side**: WCS is host-uploaded; we need to author bytes that
  the AU executes correctly

### The core challenge

We don't know the **128-bit AU microinstruction bit layout** for
the XP-32. We have:
- AP-120B 64-bit layout (definitive, FPS-7319 manual)
- FPS-164 64-bit layout (Touzeau 1984 fig 2)
- Strong inference that XP-32 is "FPS-164 widened"

But the exact bit positions (which bit selects which mux, which
3-bit field is `XR` vs `YR`, etc.) are not documented.

### Two attack modes

#### B.1 Reverse-engineer from the EU PROM

The XP-32 EU runs from a fixed 2K × 80-bit PROM. The Am29116
sequencer's ISA is documented (AMD datasheet). If we can:

1. Read the PROM contents off Lovett's EXEC card
2. Disassemble the Am29116 instruction stream
3. Identify how the EU drives the AU side (the cycle-by-cycle
   pattern of writes to AU control registers and reads of AU
   state registers)
4. From that, derive the AU control-word semantics

We get **the AU layout** by inference from how the EU *uses* it.

Effort:
- PROM read: 1-4 hours with a vintage PROM programmer + adapter
  for the specific bipolar PROM type FPS used
- Am29116 disassembly: 20-50 hours, AMD datasheet + a custom
  Python disassembler (analogous to the one we wrote for the SBC)
- AU-semantics inference: 50-200 hours, depends on how much the
  EU PROM does vs. how much it just streams from the AU WCS

Hit rate: very high if the PROM can be read.

#### B.2 Author microcode "from outside"

Skip reverse-engineering and **synthesize XP-32 microcode by
analogy** with the AP-120B / FPS-164. Pick a minimal kernel
(e.g. `ZVMUL` for a length-1 vector — just one IEEE-754
multiplication), encode it using the inferred field layout, upload
via the SBC's S-record path, and see what happens. Iterate until
the AU produces correct results.

Effort: less per attempt but lots of attempts. Each attempt is
"upload, run, observe failure mode, adjust". Highly informative
because the failure pattern (which functional unit fires when,
what's in MD afterwards) reveals the actual layout.

### Realistic plan

**B.1 first** because it's deterministic and the PROM read is
cheap. **B.2** as the validation/end-game once B.1 has produced
a candidate AU layout.

### Critical-path next step for Objective B

**Identify the EU PROM chips on Lovett's EXEC card** (visible
chip list, package types, vendor markings) and confirm a vintage
PROM programmer + adapter combination that can read them. Then
read the PROMs.

---

## Order of operations (dependency-aware)

```
1.  Lovett does logic-analyzer captures of:
     (a) AP I/F connector pins during SBC boot
     (b) EU PROM chip identification (visual)

2.  Reverse-engineer cable protocol from (a)
    [unblocks Objective A — substitute host-side card]
    +
    Read EU PROMs from (b)
    [unblocks Objective B — disassemble EU, infer AU layout]

3a. Build modern host-side substitute board (FPGA or Teensy)
3b. Disassemble Am29116 EU instructions, derive AU layout

4a. Validate host-side: send simple commands, observe SBC response
4b. Author candidate AU microcode for one routine, upload via the
    host-side substitute (now working from step 3a)

5.  ZVMUL on a 1-element vector — end-to-end test of both objectives.
```

Steps 1, 2, 3 are independent of each other (parallelisable).
Step 4 needs both 3a and 3b. Step 5 needs all of 1-4.

### Effort total

Order-of-magnitude: **300-500 engineering hours**, distributed:
- ~50h reverse-engineering cable protocol (Objective A path)
- ~50h building modern host-side substitute (Objective A path)
- ~100h reverse-engineering EU + inferring AU layout (Objective B path)
- ~50h authoring + validating first XP-32 microcode (Objective B path)
- ~50h overhead/integration

This is a many-month part-time project. Each milestone is
independently meaningful, so even partial completion produces
durable value.
