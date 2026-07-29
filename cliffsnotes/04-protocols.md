# 04 — Protocols

Three layers of protocol exist in this system:

```
PDP-11 host  ──cable──  AP I/F card  ──VersaBUS──  SBC  ──XLTR──  XP-32 ACs
              (~169 nets)              (host-visible)    (SBC-private)
```

## Layer 1 — host ↔ AP I/F (cable)

The cable carries **169 distinct net names** per the 4448 netlist
(reverse-engineered from a related card; see
[`upstream_repos.md`](../notes/upstream_repos.md)). Of those, ~150 are
unique logical signals after excluding ground/power returns.

Key signal groups (per `cable_protocol_inferred.md`):

- 6-bit **REGSEL[0..5]** bus → selects 1 of 64 chassis-side regs
- 16-bit **HD/DMA/HST** data buses
- multiple clocks, interrupts, handshakes

**Implication for substitute hardware**: a microcontroller with
~50 GPIO is insufficient. An FPGA with ≥150 user I/O is required —
recommended: Lattice ECP5 (ULX3S or ECP5-5G-EVN). See
[`host_substitute_hardware_plan.md`](../notes/host_substitute_hardware_plan.md).

The actual host-side AP I/F card is **missing** from Lovett's chassis.
Pin correspondence between the 4448 netlist and the host card is a
high-confidence hypothesis pending bench probe — not yet verified.

## Layer 2 — SBC ↔ XLTR (VersaBUS)

### AP I/F register block at `0xFF00xx` (host-visible)

| Offset | Name | Notes |
|---|---|---|
| `0x00` | command/status | 16-bit; opcodes `0x8004` (REQUEST-XFER), `0x8005` (CONTINUE) |
| `0x0E` | per-channel cmd-arg | echo of `d0` |
| `0x44`, `64`, `84`, `A4` | per-channel **write** port (XP1..XP4) | |
| `0x48`, `68`, `88`, `A8` | per-channel **read A**; this read consumes a host byte | |
| `0x4A`, `6A`, `8A`, `AA` | per-channel **status**; host presents `$4F` | |
| `0x4E`, `6E`, `8E`, `AE` | per-channel **read B** | |

### XLTR register block at `0xFF02xx` (SBC-private)

| Offset | Name | Notes |
|---|---|---|
| `0x200` | Mode 0 | bit 10 manipulated |
| `0x202` | Mode 1 | bit 7=busy, bit 12=enable, bit 14=control |
| `0x204` | Channel Select | 1 of 4 XP-32/IOP channels |
| `0x20C` | Counter/Config | written `0x01`, `0xFF` |
| `0x210` | Mode 2 | cleared during channel setup |
| `0x214` | Data Lo | data output |
| `0x216` | Data Hi / Cmd | single-bit cmds `0x10`/`0x20`/`0x40`/`0x80` |
| `0x218` | Status / IRQ | bit 15 = ready/done; arm by writing `0x400` |
| `0x21A` | IRQ Mask | written `0xFFF` |
| `0x230`-`0x25F` | **three MC68153-style BIMs**, 4 channels each: CR0-3 at +$0/+2/+4/+6, VR0-3 at +$8/+A/+C/+E | |
| `0x244`, `0x246`, `0x250`, `0x252`, **`0x254`** | BIM *control* registers, one per task (XP1-4 and TCBIO1I). `$5F` = IRQ level 7 + enable | |
| `0x24C`, `0x24E`, `0x258`, `0x25A`, `0x25C` | matching BIM *vector* registers, 8 bytes above each control register | |

## Layer 3 — XLTR ↔ XP-32 EU (panel commands)

The SBC firmware sends **21 distinct 16-bit panel commands** to the
XP-32 EXEC card:

`0x258, 0x259, 0x25A..0x25F, 0x260, 0x269..0x26C, 0x26E, 0x271,
0x276..0x27D` (minus `0x27C`).

Verified against AMD March 1986 bipolar Am29116 datasheet + March
1988 CMOS Am29C116 datasheet (same ISA): all 21 codes decode as
**TOR1 SUBRC** ("S minus R with carry") instructions in two
operand-pattern groups:

| Group | Codes | SRC/Dest | Effect |
|---|---|---|---|
| A | `0x258..0x25F` | `0010` (TORIA) | ACC ← I − RAM[R24..R31] − ¬c |
| B | `0x260..0x27D` | `0011` (TODRA) | ACC ← RAM[N] − D − ¬c, N ∈ {R0,R9..R29} |

Three live interpretations (`panel_codes_am29116_decoded.md`):

1. **Dispatch indices** that happen to be valid Am29116 instructions
2. **Literal Am29116 instructions** whose RAM-read triggers MMIO
   side-effects on specific R-addresses (memory-mapped trigger model)
3. **Hybrid** — code is real, ACC result is the dispatch input

EU PROM read or live bus trace is required to disambiguate.

## CPFORTRAN / XPMLIB ⇄ ROM mapping

The published FPS-5000 software API (Hockney p.241; Curington 1984)
maps to ROM functions:

| API call | ROM responsibility |
|---|---|
| CPLOAD | TCBRDHC + SLC S-record loader at `F04B68` |
| CPRUN | "set-busy + start" panel command |
| EXPUT / EXGET | TCBIO1I host↔FPS data movement |
| **XPSEL** | "select channel" → `0xFF0204` |
| **XPRUN** | arm DMA + clear-busy |
| **XPWAIT** | TCBXP*I channel-state-machine poll |
| **XPSTAT** | "read device status" panel command |
| **XPDMAR** | SCM↔LMD DMA primitive |

## Where to read more

- [`xltr_protocol.md`](../notes/xltr_protocol.md)
- [`host_to_sbc_communication.md`](../notes/host_to_sbc_communication.md)
- [`host_to_fps100_full_protocol.md`](../notes/host_to_fps100_full_protocol.md)
- [`panel_codes_am29116_decoded.md`](../notes/panel_codes_am29116_decoded.md)
- [`cable_protocol_inferred.md`](../notes/cable_protocol_inferred.md)
- [`ap_if_card.md`](../notes/ap_if_card.md)
