# How host computers talk to the FPS-3000 SBC (the 68K)

The path is **host's native bus → AP I/F card (slot 11) → VersaBUS →
SBC's AP-I/F register window at `0xFF0000+` → TCBRDHC / TCBIO1I tasks
on the 68K**. This doc unpacks each link.

> What we directly observe from the SBC ROM disassembly is the
> *VersaBUS side* of the AP I/F (the SBC's view). The *host side*
> (UNIBUS / Q-bus / VAX-BI / IBM-channel) we have no FPS-3000-era
> driver source for — only the FPS-100's. So everything below about
> how the host's software end works is inferred from (a) the symmetry
> the AP I/F must have, (b) FPS-5000 family conventions documented
> in Hockney/Curington, and (c) the FPS-100 RSX-11M driver as the
> closest documented analog.

## The AP I/F is a *dual-ported* bridge card

```
   Host side                                 FPS-3000 side
   ─────────                                 ──────────────
   Host's native bus                         VersaBUS (16-bit, 68K)
   ─┬─────────────                           ──────────┬──
    │                                                  │
    │       ┌──────────────────────────────────┐       │
    │       │    AP I/F card (slot 11)         │       │
    │       │  ─────────────────────────       │       │
    └───────┤  • dual-ported register file     ├───────┘
            │     visible to BOTH buses        │
            │  • DMA engine (host RAM ↔        │
            │     VersaBUS / SBC RAM)          │
            │  • bidirectional interrupt       │
            │     propagation                  │
            │  • host-side bus interface       │
            │     (UNIBUS by default; other    │
            │      flavours per SYSGEN)        │
            └──────────────────────────────────┘
```

The card is **two PCBs' worth of glue** that lets two completely
different bus architectures share one register file. Hockney p.241
calls it "the AP I/F"; the FPS-5000 brochure (1984) lists it as a
separately-orderable card with multiple host-bus variants.

## What the host sees

The host plugs the AP I/F into its own backplane and sees **a
device-register block at a SYSGEN-configured I/O address** (default
typical of FPS gear: `0o176000` on a UNIBUS host, equivalent address
on Q-bus). From the host's perspective, this is its only visible
piece of the FPS-3000 — everything inside the chassis is opaque.

The host runs an **FPS-5000-family device driver** (not the FPS-100
`APDRV` we have source for, but its successor — which we *don't*
have source for in this archive). The driver dispatches on
QIO/IOQB-style commands much like the FPS-100 driver did, just with
a different command alphabet matching the FPS-3000's panel-command
codes (`0x258..0x27D`).

What we infer about the host-side register block (from the SBC's
view of the same registers via VersaBUS at `0xFF00xx`):

| Offset (hex) | Per SBC ROM observation | Likely host-side role |
|---:|---|---|
| `0x00` | command/status word; SBC writes `0x8004`/`0x8005` here as triggers | host writes commands here, polls for done/error |
| `0x0E` | per-channel command argument register | host writes channel-specific arg |
| `0x14` | data low | bidirectional 16-bit data register |
| `0x16` | command-code (e.g. `0x258..0x27D`) | host writes panel-command codes here |
| `0x18` | trigger / status (writes `0x400` to arm; bit 15 ready) | host arms transactions, polls completion |
| `0x1A` | IRQ mask | host configures which interrupts wake it |
| `0x48/0x4E` | channel 1 data A / data B | per-channel I/O |
| `0x68/0x6E` | channel 2 data A / B | |
| `0x88/0x8E` | channel 3 data A / B | |
| `0xA8/0xAE` | channel 4 data A / B | |
| `0x244/0x246` | channel 1/2 config | |
| `0x250/0x252` | channel 3/4 config | |
| `0x200..0x21A` | XLTR mode/status registers | (XLTR-side, not host-facing — only SBC pokes these) |

So the AP I/F's host-side window is roughly **64–80 bytes of
register-file** plus per-channel data ports. The register layout is
**not** byte-for-byte the FPS-100 UNIBUS layout — FPS redesigned it
for the multi-AC FPS-5000 family. (Curington 1984: "FPS-5000 …
provides a software migration path for our previous 38-bit
processors" — *migration*, not byte-compatibility.)

## What the SBC sees

The same registers, mapped into the SBC's VersaBUS short-I/O space
at base `0xFF0000`. Plus the XLTR's separate register block at
`0xFF0200..0xFF025F` which is **not** visible to the host (it's the
SBC's private control plane for talking to the XP-32 cards).

The SBC ROM's two main host-facing tasks are:

- **`TCBRDHC`** (`F046F0`) — master/dispatch task. Wakes on ASQ
  messages from `TCBIO1I` (or external interrupts via the AP I/F),
  parses incoming commands, dispatches to subordinate tasks. Also
  hosts the S-record parser for microcode upload.
- **`TCBIO1I`** (`F05D00–F05EFF`, ASQ name `HIO1`) — host I/O
  channel task. Implements the **EXPUT/EXGET** primitives — bulk
  data movement between host RAM and the FPS-3000's SCM.

The SBC ROM polls AP-I/F register `0xFF0000` (bit 14 = ready,
bit 13 = error) when sending to or receiving from the host — the
*same bit-13/14 protocol* the FPS-100's host-side driver used on
its UNIBUS device, just on the opposite side of the dual-port.

## The protocol — host kicks SBC, SBC services the host

**Host → SBC (host wants to do something):**

1. Host's driver pokes AP I/F register `0x14`/`0x16` with a command
   code + argument
2. Host writes a trigger word to `0x18` (writes `0x400` to arm, or a
   command-class word like `0x8004`)
3. AP I/F card raises an interrupt on the SBC's VersaBUS; SBC's
   AP-I/F-irq handler wakes `TCBRDHC` via ASQ
4. `TCBRDHC` reads the registers, decides what to do
5. If the command is host I/O, it forwards to `TCBIO1I`
6. If the command is "talk to an XP-32", it goes through the panel-
   command path (`PanelSendAndWait` at `F056BA`) — which uses the
   *XLTR* registers at `0xFF0200+`, not the AP I/F
7. SBC writes the result back into the AP I/F register file
8. SBC sets the AP I/F's status bits (bit 14 = done, bit 13 = error)
9. AP I/F card raises an interrupt on the host's bus
10. Host's driver wakes, reads result

**Host → SBC bulk data transfer (CPLOAD, EXPUT):**

1. Host issues a bulk-transfer command (e.g. "load microcode from
   addr X for N words")
2. SBC parses, writes back the destination address (typically the
   `0x10000-0x1FFFF` staging buffer for microcode) into the AP I/F's
   DMA-config registers
3. AP I/F's DMA engine fetches bytes from host RAM (host bus)
   and writes them to SBC RAM (VersaBUS)
4. Once complete, AP I/F raises completion interrupt on the SBC's
   side; SBC verifies and acknowledges back to host

For microcode upload specifically: the host sends **S-record format
bytes** to the SBC's serial-line-like interface on the AP I/F. The
SBC parses S-records (`SRecordDataHandler` at `F051A2`), reassembles
the binary into the staging buffer, then on the S9 termination
record uploads the staged microcode into the XP-32's WCS via the
XLTR (the *other* translator).

**SBC → Host (SBC has a result to deliver):**

Symmetric to the above. SBC writes data into the AP I/F register
file, sets a status bit, the AP I/F raises an interrupt on the
host's bus, the host's driver picks up the value.

## Concrete code references in the SBC ROM

From the disassembly + Monte-Carlo annotations:

| Address | Action | Purpose |
|---|---|---|
| `F046F0` | `TCBRDHC:` | Master dispatch task entry — main loop polling for events |
| `F051A2` | `SRecordDataHandler` | Parses S-records arriving via AP I/F, populates staging buffer |
| `F05256` | `SRecordFinalize_andHelpers` | On S8/S9, kicks off WCS upload |
| `F056BA` | `PanelSendAndWait_andDispatch` | The "talk to XLTR / XP-32" kernel; reads/writes AP I/F at `0xFF0000` |
| `F05688` | `PanelIOConfigure_25A` | Issues a panel command code (e.g. `0x26C` PCMD_RELEASE) to the XP-32 channel |
| `F05D00–F05EFF` | `TCBIO1I` | Host I/O channel task — uses RMS68K TRAP #1 syscalls heavily; copies parameter blocks backward onto stack |

The AP-I/F address `0xFF0000` shows up many times in the SBC ROM as
both read (status polling) and write (command issue) target — it's
the "is host trying to talk to me?" register from the SBC's side,
and the "is the SBC ready?" register from the host's side. Same
bytes, different perspective.

## PDP-11/73 specifically

The PDP-11/73 is a **Q-bus** machine (LSI-11 family with J-11 chip).
The stock FPS-100 was UNIBUS-only; the FPS-5000 family AP I/F card
came in multiple host-bus variants (UNIBUS, Q-bus, VAX BI, IBM
channel adapter). Whether a Q-bus AP I/F variant existed and what
its part number is, we don't have documentation for in this archive.

If you're driving an FPS-3000 from a PDP-11/73, three options:

1. **Native Q-bus AP I/F variant** — if FPS made one, it's a
   different-part-number AP I/F card that the FPS-3000 chassis
   accepts in slot 11 instead of the UNIBUS variant. Same VersaBUS-
   side protocol; different host-side connector.
2. **Q-bus ↔ UNIBUS bridge** — DEC's UBA, Able UNIBUS-Q boxes, or
   similar. The PDP-11/73 sees a Q-bus device that maps through to
   the UNIBUS AP I/F. Common in mid-1980s mixed-bus shops.
3. **Different host model** — Lovett's actual machine is a
   PDP-11/44 (UNIBUS) per the Hackaday article. If your reference
   to the /73 was a typo for /44, no bridge is needed.

The **SBC firmware is independent of which option** — it only ever
sees the VersaBUS side of the AP I/F, and that side is unchanged
across host-bus variants.

## Connection to the rest of the analysis

This document covers the **host ↔ SBC** half of the picture. The
**SBC ↔ XP-32** half is in `xltr_protocol.md` and
`xp32_eu_command_protocol.md`. End-to-end traffic for a typical
math-library call (host's `CALL ZRFFT(...)` running an FPS-3000
kernel) thus crosses two translation boundaries:

```
host CALL → host driver → AP I/F (host side)
         ↓ dual-port register write + irq propagation
            AP I/F (VersaBUS side) → SBC TCBRDHC
                                  → SBC PanelSendAndWait
                                  → XLTR (VersaBUS side)
                                       ↓ XP32 BUS bridge
                                       XLTR (XP32 BUS side) → XP-32
```

Two translators, two protocols, both descended in spirit from the
single FPS-100 host interface but reimplemented for the layered
chassis architecture of the FPS-5000 family.
