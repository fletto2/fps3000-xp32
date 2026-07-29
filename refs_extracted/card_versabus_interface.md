# FPS 3000 — components directly on the VERSAbus (signal lines only)

Per card: which ICs connect **directly** to the P1/P2 backplane signal lines (excluding VCC/GND).

## Method

**No netlist exists** (component-side photos only — see `README.md`), so this is inference from:

1. **Physical adjacency to the edge fingers** — bus buffers are always placed in the row(s)
   immediately behind the connector to minimise stub length.
   **All 8 cards have now been read directly at native resolution.**
2. **Part function** — only octal/hex 3-state buffers, transceivers and dedicated bus
   registers drive a backplane; CPUs, ALUs, PROM and RAM never do.
3. **VERSAbus structure** — `refs/datasheets/M68KVBS_VERSAbus_Specification_Manual_Jul81.pdf`
   has the P1/P2 pinout for a future buffer→signal-group mapping.

Adjacency is strong evidence but **not a traced connection**. Confidence: high for *which
devices are the bus interface*; the specific signal each drives is not established.

---

## 01 — VBUS SBC (Motorola M68KVM02)

| Part | Qty | Role |
|---|---|---|
| **SN74LS240N** | 6+ | inverting octal 3-state buffer — address/control |
| **SN74LS245N** | 2 | octal transceiver — **bidirectional data bus** |
| **DM74LS244N** | 2 | non-inverting octal buffer — address |
| **MC6888P / MC8T98P** | 2 | hex 3-state bus driver — control/handshake |
| 74S257N, 74S38N (open-collector), 74S125AN | — | select mux, wired-OR drivers, quad 3-state |

**The MC68000 is fully buffered — it does not touch the bus.** Expected but not located:
MC68153 Bus Interrupter (datasheet present in the repo set).

## 02 — V-BUS XLTR

| Part | Qty | Role |
|---|---|---|
| **AM2927DCB** | 8+ | **quad 3-state bus transceiver** — AMD's dedicated backplane driver |
| **AM29823DC** | 4 | 9-bit bus register |
| **AM25S07PCB** | 2 | quad bus transceiver |
| 74S244N, 74S240N, SN74LS244N, 74F245, 74S157, 74LS273N, 7417N | — | buffers/latches |
| R42, R52, R61–R69 networks at the connector | — | **bus termination** |

## 03 — UNIV FMT

| Part | Qty | Role |
|---|---|---|
| **AM29827DC** | 3+ | 10-bit bus buffer |
| **AM29824DC** | 2 | 9-bit bus buffer |
| **AM2952DC** | 1 | 8-bit **bidirectional** I/O port |
| 74LS244N, 74F244N, 74LS240N, 74S157N, 74F32N, 74F350N, SN74S251N | — | buffers, shifters |
| R6–R9 networks at the connector | — | **bus termination** |

The MC74F153N multiplexer banks are internal datapath, not bus-facing.

## 04 — AP I/F

| Part | Qty | Role |
|---|---|---|
| **74LS240N / 74LS244N / 74S240N / MC74F240N** | many | VERSAbus buffers |
| **MC3487P** | 2 | **quad differential line DRIVER** (RS-422) |
| **MC3486P** | 2 | **quad differential line RECEIVER** (RS-422) |
| 74S169AN counters, SN74S174N, SN74279N, 74S139N | — | sequencing |
| Grayhill DIP switch S2; R30–R35 networks | — | configuration; **termination** |

**Key finding:** this card carries *two* interfaces — the VERSAbus buffers **and** an RS-422
**differential** link (MC3487/MC3486) driving the ribbon cables to the array-processor chassis.

## 05 — XP32 EXEC

| Part | Qty | Role |
|---|---|---|
| **MC74F534N / 74S534N** | 3 | registered octal 3-state (inverting) buffer |
| **AM29823DC-B** | 3+ | 9-bit bus register |
| **L29C520PC-R** | 4+ | Logic Devices 29C520 multilevel pipeline register |
| MC74F240NDS, MC74F244NDS, 74F157N, 74S260N | — | buffers |

`SN74S381N` ALUs, Am29116, 29F52 PROM and Am2168 SRAM are internal.

## 06 — XP32 ARITH

| Part | Qty | Role |
|---|---|---|
| **L29C520PC-R** | 6+ | pipeline register — solid bank at the connector |
| **AM29821DC** | many | 10-bit bus register |
| **74F245N** | several | octal transceiver |

Also confirmed on this card: **AM2910ADC** microprogram sequencer (internal) and an empty PGA
socket. Am29540/Am2168/CY7C168/29F52 are internal datapath.

## 07 — MEM CTRL

| Part | Qty | Role |
|---|---|---|
| **SN74LS240N / 74S240N / 74S244N / MC74F244ND** | 5+ | address/control buffers |
| **SN74LS374N** | 1 | registered buffer |
| **74F521** | 1 | **8-bit identity comparator — the board-address comparator** |
| SN74LS137N, SN74LS163AN, SN74S132N; DL15CC151 delay | — | decode/timing |
| R48–R54 networks at the connector | — | **bus termination** |

## 08 — MAIN DATA

| Part | Qty | Role |
|---|---|---|
| **74S374N** | 4+ | registered octal buffer |
| **74S534N** | 3+ | registered octal 3-state (inverting) buffer |
| 74S37N, 74S14N | — | drivers / Schmitt |
| R49–R56 networks at the connector | — | **bus termination** |

**The MSM4256P DRAM array does not touch the bus.** `PAGE SELECT` jumpers set the address
window (compare card 07's 74F521 comparator).

---

## Findings across all eight cards

**1. The rule holds without exception.**
> Only octal/hex 3-state buffers, transceivers and dedicated bus registers touch the
> backplane. Every CPU, ALU, sequencer, PROM and RAM sits behind them.

**2. Two clearly different interface styles.**
* **Card 01 (Motorola's own SBC)** — *combinational* buffers: 74LS240/244/245 + MC8T98.
* **Cards 02–08 (FPS-designed)** — *registered / dedicated bus parts*: 74S374/74S534/MC74F534,
  Am2927, Am29821/29823/29824/29827, Am2952, Am25S07, L29C520 pipeline registers.
  Consistent with a pipelined array processor that latches bus data every clock.

**3. AMD bus-interface silicon dominates the FPS cards** — Am2927 transceivers, the Am298xx
buffer/register family and Am2952 bidirectional ports. `refs/datasheets/AMD_Bus_Interface_Products_1988.pdf`
covers these.

**4. Termination networks sit at the connector on 02, 03, 04, 07 and 08** — resistor packs
directly behind the fingers.

**5. Board-address decoding is explicit**: 74F521 comparator (07), PAGE SELECT jumpers (08),
Grayhill DIP switch (04).

**6. Card 04 is a dual-interface bridge** — VERSAbus on one side, RS-422 differential
(MC3487/MC3486) to the AP chassis on the other. That is the physical boundary between the
68000 host system and the array processor.

### Corrections to the earlier inferred draft
* **08**: guessed `74F240/74AS240/AM25S07`; actually **74S374N / 74S534N** registered buffers.
* **02**: guessed `74LS240/244`; those exist, but the primary interface is **Am2927** quad bus
  transceivers.
* **03**: guessed `Am29823`; actually **Am29827 / Am29824 / Am2952**.
* **04**: the **MC3487/MC3486 differential pair was not predicted at all** — it changes the
  reading of this card's role.

## To turn inference into fact
1. Photograph the **solder side** of each card → run the `../pcb/` netlist pipeline.
2. Map buffer positions to P1/P2 signal groups using the VERSAbus spec pinout.
