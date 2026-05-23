# Serial Ports on the FPS-3000 SBC

## Hardware: NEC µPD7201 dual SIO

The M68KVM02-3 board carries one **NEC µPD7201 Multiprotocol Serial
Communications Controller (MPSC)** at SBC-bus address `0xF70010-0xF70017`:

| Address | Function           |
|---------|---------------------|
| F70010  | Channel A — data    |
| F70012  | Channel A — control/status |
| F70014  | Channel B — data    |
| F70016  | Channel B — control/status |

The µPD7201 is **register-compatible with the Z80-SIO and the Intel
i8274** — same WR0..WR7 / RR0..RR2 layout, same access pattern (write
WR0 with low-3-bit register pointer, then write the next byte; reads
auto-pointer-reset). MAME's `z80sio.cpp` (3027-line implementation,
includes `upd7201_device` deriving from `i8274_device`) is the
authoritative model.

Per the M68KVM02 manual (`refs/versabus2.pdf` Figure 2):

- Two **independent full-duplex serial channels** (A and B)
- Programmable rate from 50 bps to 19.2 kbps with the on-chip baud-rate
  generator
- External-clock support up to 600 kbps
- Multiprotocol: async, byte-sync (BSC, IBM 3271/3275), bit-sync (HDLC, SDLC)
- 8-byte status FIFO per channel for SDLC frame address recognition
- DMA-style auto-vectored interrupts with prioritized vector return

The µPD7201 is wired to **VERSAbus IRQ level 4** with vectored ack on
this board — but the FPS-3000 firmware never enables it, so this
detail is unverified from the ROM side.

## Firmware usage: NONE

`grep` of every 32-bit immediate, every (PC-relative) absolute long
EA, and every byte sequence `F7 00 1X` in `FPS3K_U11_U12_JOIN.bin`
returns **zero hits**. The FPS-3000 SBC firmware (this ROM,
~64 KB total, ~37 KB application code excluding RMS68K kernel) **does
not access the SIO at all**.

The SIO chip is physically present, properly wired, and has its own
8 MHz clock — but no code path in the firmware programs WR0..WR7,
reads RR0..RR2, sends a byte, or installs an ISR for it. The level-4
auto-vector handler points at the RTOS generic dispatcher (F00EC8),
which doesn't differentiate sources.

## Why isn't it used?

Three plausible reasons (all undocumented; pick your favorite):

1. **The DA3 / Bomem application doesn't need it.** The host-link
   path goes through the AP I/F card (slot 11) at high bandwidth.
   The FTIR data set is large; serial would be far too slow. The
   maintenance console — typically the second use case for an SBC
   serial port — was probably never wired up at the chassis level
   on this configuration.

2. **It was reserved for FPS factory use.** A development build
   of the firmware presumably had a serial console for diagnostics,
   stripped from the production ROM that ships in the chassis.
   The hardware support is there for the test fixture; the
   shipping firmware just doesn't reference it.

3. **Bomem-customised firmware variant.** The FPS-3000 ROM here
   is from David Lovett's chassis configured for the Bomem DA3.
   It's possible Bomem (or FPS, on Bomem's request) stripped any
   serial handler that wasn't load-bearing for the application.
   Without earlier ROM dumps to compare against, we can't know.

## What we COULD do with it (emulator-side)

Since the chip IS present and our emulator models it (see
`emulator/upd7201.c`), we could:

- **Inject debug serial input** by writing to channel A — but no
  ROM code would respond (no RX-interrupt handler installed).
- **Observe TX writes** — but again, no ROM code writes to it.
- **Re-flash the SIO** to a known-working baud (e.g. 9600 8-N-1)
  and watch — same result, silent.

The serial ports are essentially **a dormant bus stub** in this ROM.
Worth keeping the emulator model in case a different ROM image
(e.g., from a different FPS-3000 chassis variant) does use them.

## Connector / cabling

Unverified from physical inspection of David Lovett's chassis. The
M68KVM02 manual specifies:

- DB-25 connector(s) on the SBC card edge or carrier
- RS-232C signal levels via on-board level-shifters (likely 1488/1489)
- Channel A and Channel B exposed independently

The FPS-3000 chassis backplane and front-panel arrangement may bring
these out to a different connector style — chassis-specific.

## Path comparison: AP I/F vs. SIO

| | AP I/F (slot 11) | SIO (on SBC) |
|---|---|---|
| Bandwidth | DMA, full VERSAbus rate (~1-2 MB/s peak) | 19.2 kbps async max in normal mode |
| Latency | Sub-microsecond | ~0.5 ms per byte at 19.2 kbps |
| Used by ROM | ✓ (host-link, S-record load, EXPUT/EXGET) | ✗ |
| Driver in DRIVER.MAC | ✓ APDRV | ✗ |
| Cable type | Ribbon / parallel | RS-232 serial |
| Card location | Slot 11 of FPS-3000 chassis | On SBC card itself |
| Direction | Bidirectional, master/slave | Bidirectional, full-duplex |
| Use case | Bulk data, microcode upload, math ops | (Unused — could be console) |

So the emulator's serial path is **inert with respect to this firmware**
— nothing will come out of stdout via the SIO. All useful interaction
goes through the AP I/F.
