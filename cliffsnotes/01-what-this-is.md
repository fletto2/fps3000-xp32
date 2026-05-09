# 01 — What this is

## The ROM

`FPS3K_U11_U12_JOIN.bin` (64 KB, MD5 `47f133c1c2bab61f887e7e2a92a43dac`)
is the **Control Processor (CP) firmware** for a Floating Point
Systems FPS-3000 array processor. Maps to `0xF00000` on a Motorola
**M68KVM02-3** VERSAmodule monoboard (MC68000 @ 8 MHz). Byte-identical
to `FPS3K_combined.bin` from earlier circulation.

## The machine

The FPS-3000 (1983) is an **FPS-5000-class** MIMD array processor —
same family as the AP-120B (1976), FPS-100 (1978), FPS-164 (1981),
and FPS-264 (1986). The XP-32 is its arithmetic core: IEEE-754 32-bit
single-precision FP, 1 multiplier + 2 adders, 128-bit horizontal
microcode in a 4K × 128 × 4-bank writable control store.

> **FPS = Floating Point Systems Inc.**, Beaverton OR (founded 1970
> by C N Winningstad). NOT "Fire Protection System" — earlier guesses
> got the name wrong and labelled all the I/O accordingly.

The 14-slot VersaBUS chassis in this project is configured **2-AC**
(two XP-32 channels populated, two dormant). See
[02-hardware.md](02-hardware.md) for the slot map.

## The project

David Lovett (**Usagi Electric**) recovered an FPS-3000 along with a
**Bomem DA3** FTIR spectrometer and a **PDP-11/73** host as part of
his vintage-supercomputing restoration work.

The FPS-3000 is essentially undocumented:
- one chapter (Hockney & Jesshope, *Parallel Computers 2*, §2.5)
- a handful of Curington 1983-86 papers on the FPS-5000 / XP-32
- two Bitsavers entries (the FPS-5000 ad + a brochure)
- no surviving software tape or microcode binary
- no other powered-up unit in any community inventory

The FPS-3000 is the only surviving system in `Nakazoto/
FloatingPointSystems/KnownSurviving.txt` (the FPS-164 is effectively
extinct in the wild — see [02-hardware.md](02-hardware.md)).

## Why bother

1. **Connect it to a PDP-11/73 host.** Requires reverse-engineering
   the host-side AP I/F card protocol (the original card is missing).
2. **Devise working XP-32 microcode kernels.** Requires reverse-
   engineering the 128-bit AU microinstruction format, the EU
   instruction stream, and the panel-command protocol.

Both goals depend on the same underlying knowledge: how the SBC ROM
talks to the rest of the chassis, and how the chassis talks back.

## Where to read more

- [Hockney & Jesshope chapter](../refs/FPS-5000/FPS3000_fps.pdf)
  — the only published architecture description
- [Curington 1984 MAXL paper](../refs/FPS-5000/FPS5000_Curington_-_Performance_Estimation_Methods_for_XP32_MAXL_1984.pdf)
- [Bomem DA3 / Usagi context](../CLAUDE.md) — local CLAUDE.md
- [Hackaday Usagi appeal](https://hackaday.com/2025/01/12/usagis-pdp-11-supercomputer-and-appeal-for-floating-point-systems-info/)
