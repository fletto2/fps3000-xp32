# Where does XP-32 microcode come from? — answered

Two questions have been raised repeatedly by people working on the
machine. Both are now answerable from the ROM disassembly, the emulator
work and the datasheet set, so this note collects the evidence in one
place.

---

## Q1. Does the microcode have to come from the host, or can the machine make its own?

The concern, as put by the machine's owner: the sister machine (the Bomem
HPVP, same Am29116 + Weitek combination) loads its microcode from the
host's hard drive. If the XP-32 expects the same, and the original host
is gone, that is a serious problem. The hope was that the VersaBus card
or PROMs on the XP-32 might generate or hold microcode themselves.

### The answer is: from outside — but the path is open and tested

**The SBC ROM contains no microcode.** It is a conduit. What it contains
is the machinery to receive microcode and place it:

- **two** S-record parsers (F04B8A accepting S0/S1/S2/S3/S8/S9, F05522
  accepting S7 instead of S8)
- `SRecordDataHandler` at F051A2, which computes
  `$10 + <record address> + $10000` and range-checks the **result** to
  `$10000-$1FFFF` — 64 KB, exactly one 4K × 128-bit WCS bank. Records are
  therefore addressed **from zero**, not from `$10000`
- a polled bulk-transfer loop at F04AE2 reading `$FF0008` a word at a
  time into that buffer
- a chassis-driven command protocol that programs the destination
  address and word count before triggering the transfer

Nothing in the ROM synthesises microcode, and nothing reads microcode
from a PROM to forward it. The 64 KB staging buffer matching one WCS bank
exactly is the clearest structural evidence: the firmware is built to
shuttle one bank at a time from elsewhere.

**But "from the host" does not mean "from the original host."** The
staging buffer is ordinary SBC RAM at `$10000-$1FFFF`, and the in-ROM
monitor's `L` command loads S-records straight into it, bypassing the
chassis-side protocol entirely. That path is verified end to end in the
emulator — `DEADBEEF`/`CAFEBABE` landing at `$010000` — and the monitor
can address the full bank, checked at `$1FFE0` and `$1FFF0`.

The firmware's own path is verified too: driving the documented command
sequence programs destination `$00010000` and a count of 8, and eight
words arrive at `$10000` exactly (see `versabus_access_map.md`,
"End-to-end: the staging path driven through the firmware").

**So the situation is the good branch, not the bad one.** What is missing
is not a mechanism but a payload: an actual XPMLIB kernel. Any S-record
source will serve — a laptop on the serial port will do — once there is
something to send.

### What would still have to be worked out

The AU WCS is 4K × 128 bits × **4 banks** per AC, and one staging buffer
holds one bank, so a full load is four sessions.

**The bank cannot be selected from the SBC.** The outbound transfer loop
carries only a source address and a word count — no destination of any
kind — and the SBC never asserts bus mastership, so the chassis places
the data. Bank selection must therefore come from whatever configures the
XLTR or UNIV FMT ahead of the transfer, which is outside this ROM. See
"Resolved: there is no SBC-side bank select" in
`refs_extracted/versabus_access_map.md`.

This is worth knowing early: it means a revival attempt needs the
chassis-side command that sets the bank, and that command is not
discoverable from the firmware.

---

## Q2. Does the Am29116 have a ROM holding "the logic foundation" for handling microcode?

**Yes, and it is now confirmed from three directions.**

1. **Hockney & Jesshope**, figure 2.53: the Executive Unit runs from a
   **fixed 2K × 80-bit PROM**, mask-programmed at the factory, separate
   from the writable 4K × 128-bit AU store.
2. **The parts survey** finds `29F52 SDC` PROM banks on the XP32 EXEC
   card, alongside the Am29116 — the physical part.
3. **AMD's own reference design** for this chip set, in the Am29500
   handbook, has the Am29116 executing a program that generates address
   sequences for filters and matrix multiplication, with its 16-bit
   instruction carried in an overlaid microword field.

So the EU is not waiting to be told what to do — it boots from its own
mask ROM and is alive at power-on. That is *why* the SBC can issue a
panel command at all before any microcode is loaded, which the ROM's boot
sequence takes for granted.

The division is:

| Unit | Store | Contents | Loaded by |
|---|---|---|---|
| **EU** (Am29116) | 2K × 80-bit **PROM** | the "logic foundation" — fixed, factory | nobody; it is mask ROM |
| **AU** (FP pipes) | 4K × 128-bit × 4 **WCS** | the math kernels (ZVMUL, ZRFFT, …) | the SBC, from host S-records |

**Only the AU side is uploadable, and only the AU side is missing.**

---

## What this means for a revival attempt

- The transfer mechanism works and is tested in both forms, chassis-driven
  and monitor-driven.
- The EU is self-sufficient and needs nothing.
- The gap is one artefact: a real AU microcode image. Searches for XPMLIB
  binaries have come up empty (`notes/xpmlib_search_results.md`), so the
  realistic routes are recovering one from a surviving FPS-5000-family
  site, or writing kernels from scratch — which needs the 128-bit field
  layout, still open (`notes/mc_xp32_microcode_inference.md`,
  `notes/xp32_layout_vs_amd_reference.md`).

The bank-select question is **settled and closed**: there is no SBC-side
bank select at all, so the chassis-side command that sets it has to come
from somewhere other than this firmware. Budget for that when planning a
load of more than one bank.
