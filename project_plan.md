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
| **Inferred cable protocol** | `cable_protocol_inferred.md` | Objective A |
| AP I/F card details (P/N 612-4448-401-F + family) | `ap_if_card.md` | Objective A |
| XLTR↔XP-32 protocol doc | `xltr_protocol.md` + `xp32_eu_command_protocol.md` | Objectives A + B |
| AP-120B field tables (FPS-7319) | `refs/AP-120B/` | Objective B |
| FPS-164 instruction layout (Touzeau 1984 fig 2) | `refs/FPS-164/Touzeau...pdf` | Objective B |
| FPS-100 host driver source (DRIVER.MAC + DAPEX.MAC + IAPEX.FTN) | `fps100_archive/fps100sw/` | Objective A (ancestor reference) |
| 217 AP-120B HSR microcode kernels | `hsr_decoded/` | Objective B (reference corpus) |
| AP-120B FFT identity-test microcode | `ucode_transcribed.py` | Objective B (validation) |
| FPS-3000 EU PROM | physically on EXEC card | **read-out pending (B2/B3)** |
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

The cable's **logical protocol is now derived from existing
sources** (FPS-100 IOP-UNI ancestor + multi-host-bus catalog
evidence + SBC firmware accesses) — see
`cable_protocol_inferred.md`. So we know:

- Cable carries register-poke (9-bit addr + 16-bit data + R/W
  + DTACK), bus-master DMA (full host-address pass-through +
  arbitration), 3-source AP→host irq, 1-line host→AP irq
  (APIRT), reset
- ~50 logical signal lines + power/ground = ~70-80 conductors
- Cable is **host-bus-abstracted** (same cable for Q-bus / UNIBUS
  / LSI-11; the host-side card translates per bus type)

What remains is **a much narrower physical-mapping question**:
which conductor on the chassis-side connector carries which
logical signal. This needs either:
- Visual inspection of `612-4448-401-F`'s cable-connector pads
  and tracing back to identifiable chip pins, OR
- Logic-analyzer capture during SBC boot to correlate poke
  patterns to active conductors

Both are short bench tasks (hours not days) — they validate and
pin down the inferred protocol; they don't have to discover it.

The substitute host-side card design (FPGA + bus transceivers)
**can start now in parallel**.

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

## Order of operations (dependency-aware, post cable-inference)

```
DESK WORK — startable now, no bench inputs needed:

  D1. FPGA design for substitute host-side card
       — register-poke handler at chassis-side cable interface
       — bus-master DMA emulator on host-side bus
       — irq translation (3 sources cable→host; 1 line host→cable)
       — based on cable_protocol_inferred.md spec
  D2. Am29116 disassembler (Python, analogous to disasm.py for 68K)
       — implements the AMD Am29116 datasheet ISA
       — ready to decode the EU PROM contents the moment they're read
  D3. XP-32 candidate AU control-word layout
       — extends FPS-164 layout (Touzeau fig 2) with second-adder
         + DMA-controller groups
       — provisional encoding for hand-authoring trial kernels

BENCH WORK — narrow, on Lovett's hardware:

  B1. Pin-out of 612-4448-401-F's cable connector
       — visual / DMM / brief LA capture during SBC boot
       — outputs: physical-pin → logical-signal map
       [unblocks D1 final step: the FPGA's pin assignments]
  B2. Visual ID of EU PROM chips on the EXEC card
       — chip type, package, vendor markings
       — identify a working PROM-programmer + adapter combo
  B3. Read EU PROMs
       — output: 2K × 80-bit binary microcode image

INTEGRATION WORK — combines desk + bench:

  I1. Substitute host-side card built (D1 + B1)
       — Q-bus dev board + FPGA + cable to chassis
  I2. Bring-up: send simple commands from host substitute,
       observe SBC response on chassis-side
  I3. Disassemble EU PROM (B3 + D2)
       — outputs: Am29116 instruction trace of the EU at boot,
         and EU↔AU coordination patterns
  I4. Infer AU layout (I3 → refines D3)
       — outputs: validated XP-32 AU control-word semantics
  I5. Author first XP-32 µkernel (D3 + I4)
       — start with single-instruction NOP, then ZVMUL on 1-vector
  I6. Upload + run µkernel via I1
       — observe AU register state, iterate until correct

FINAL DEMO:

  ZVMUL on a 16-element vector, host substitute → SBC →
  XP-32 AU, result back to host. End-to-end on both objectives.
```

Dependency graph:
- `D1`, `D2`, `D3` independent of each other and of bench work
- `B1`, `B2`, `B3` independent of each other (B1 is for Obj A; B2,B3 for Obj B)
- `I1` needs D1 + B1
- `I3` needs D2 + B3
- `I4` refines D3 using I3 outputs
- `I5` needs D3 (or refined I4) + AU layout
- `I6` needs I1 + I5

### Effort total (revised — cable inference saves ~30h)

| Task | Hours |
|---|---|
| D1 (substitute host-side FPGA + transceivers + cable end-points) | ~80 |
| D2 (Am29116 disassembler) | ~30 |
| D3 (candidate AU layout) | ~20 |
| B1 + B2 + B3 (bench, pin-out + PROM read) | ~10 |
| I1 (host-side bring-up) | ~30 |
| I2 (host↔SBC validation) | ~20 |
| I3 (EU disassembly) | ~40 |
| I4 (AU layout inference) | ~50 |
| I5 (first µkernel authoring) | ~30 |
| I6 (microcode bring-up + iterate) | ~50 |
| Integration / overhead | ~30 |
| **Total** | **~390** engineering hours |

Same overall scope — cable-protocol inference doesn't reduce
total engineering effort, but it **unblocks the parallelism**:
the FPGA work (D1) can now run concurrently with all the bench
work, instead of being gated on a long reverse-engineering
phase.

This is a many-month part-time project. Each milestone is
independently meaningful, so even partial completion produces
durable value.
