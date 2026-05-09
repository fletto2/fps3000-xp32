# Cliff's Notes — FPS-3000 reverse-engineering

Concise overviews of every chunk of the project. Each page is ≤2 pages
of reading and points at the full docs in the repo root for depth.

## Index

| # | Page | Topic |
|---|---|---|
| 01 | [What this is](01-what-this-is.md) | The ROM, the machine, the project |
| 02 | [Hardware](02-hardware.md) | FPS-3000 chassis, cards, family chip-ID |
| 03 | [Firmware](03-firmware.md) | SBC ROM, RTOS (RMS68K), tasks, memory map |
| 04 | [Protocols](04-protocols.md) | Host↔SBC↔XLTR↔XP-32, panel commands, cable |
| 05 | [Microcode](05-microcode.md) | XP-32 128-bit layout consensus + open issues |
| 06 | [Validation](06-validation.md) | What's known, unknown, and how we'd check |
| 07 | [Resources](07-resources.md) | Recovered software + missing artifacts |
| 08 | [Methodology](08-methodology.md) | How the inferences were produced |
| 09 | [Status](09-status.md) | Current state, blocked vs unblocked work |
| 10 | [Family machines](10-family-machines.md) | What we know about each FPS sister machine |

## What's the goal

David Lovett (Usagi Electric) recovered an FPS-3000 array processor
plus a Bomem DA3 FTIR spectrometer with a PDP-11/73 host. The
FPS-3000 has no surviving software, no public documentation beyond a
handful of papers, and no other surviving units to cross-reference.
This project reverse-engineers it from its 64 KB SBC firmware ROM
plus the broader FPS family lineage.

Two end-goals:

1. Connect the FPS-3000 chassis to a PDP-11/73 host.
2. Devise working XP-32 microcode kernels.

## Status in one paragraph

The SBC ROM is fully disassembled and ~80% understood. The XP-32
microinstruction layout has a Council-of-Clankers consensus
(`mc_xp32_microcode_inference.md`) for the 128-bit AU word, with
the first 103 bits at HIGH/MEDIUM confidence by inheritance from
documented AP-120B/FPS-164 evolution. The remaining 25 bits and the
80-bit EU side are speculative. The 21 panel commands the SBC sends
to the XP-32 EXEC card decode as Am29116 TOR1 SUBRC instructions but
their semantic role (literal MMIO trigger vs dispatch index vs
hybrid) is unresolved without an EU PROM dump or live bus trace.
No public XPMLIB binary exists; the FPS-100 archive (62K AP-120B
microinstructions) is the closest validation substitute.
