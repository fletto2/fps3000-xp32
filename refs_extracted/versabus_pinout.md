# VERSAbus connector pinouts (P1 / P2)

Sources:
- Motorola **VERSAbus Specification Manual** (M68KVBS, July 1981) —
  full Appendix C signal description + Appendix D Jl/Pl pin
  assignments
- Motorola **M68KVM02-3 VERSAmodule Monoboard Microcomputer User's
  Manual** — Table 2 (Signal Characteristics, I/O Connector P2)
- `refs/FPS3000_VersaBUSPinout.pdf` — FPS-specific reference (scanned
  bitmap; not OCR'd here, but consistent with the Motorola spec)

The FPS-3000 SBC uses Motorola's standard VERSAbus card form factor.
**P1 (140-pin)** carries the 16/32-bit data bus, address bus, and bus
control. **P2 (120-pin)** carries the local I/O channel (parallel
expansion) plus two RS-232 serial ports. On real hardware a chassis
slot has a 140-pin J1 socket and a 120-pin J2 socket; a card
populates P1 always, and P2 only when its functions are needed.

## P1 / J1 — VERSAbus backplane connector (140 pins)

Two rows: ODD-numbered pins on the **component side**, EVEN-numbered
pins on the **solder side**.

### Power and ground

| Pin | Signal       | Notes                                                    |
|----:|--------------|----------------------------------------------------------|
|   1 | +5V          | also pin 2 |
|   2 | +5V          | |
|   3 | GND          | also pins 4, 12, 14, 18, 20, 24, 28, 32, 62, 67, 68, 70, 72, 119, 120, 123, 124, 134-140 |
| 121 | -12V         | also pin 122 |
| 125 | +12V         | also pins 126, 127, 128 |
| 129 | +5V          | also pins 130, 131, 132 |
| 133 | +5V STDBY    | also pin 134 |

Standard VERSAbus power tree: +5 V (logic), ±12 V (RS-232 line
drivers etc.), +5 V Standby (battery-backed RAM).

### Data bus (16 bits)

| Pin | Signal      | | Pin | Signal      |
|----:|-------------|-|----:|-------------|
|   5 | D00*        | |   6 | D01*        |
|   7 | D02*        | |   8 | D03*        |
|   9 | D04*        | |  10 | D05*        |
|  11 | D06*        | |  12 | D07*        |
|  13 | D08*        | |  14 | D09*        |
|  15 | D10*        | |  16 | D11*        |
|  17 | D12*        | |  18 | D13*        |
|  19 | D14*        | |  20 | D15*        |
|  21 | DPARITY0*   | |  22 | DPARITY1*   |

3-state, bidirectional. DPARITY0 covers D0-D7, DPARITY1 covers D8-D15
(both even-parity).

### Address bus (24 bits) + extras

| Pin | Signal | | Pin | Signal | | Pin | Signal |
|----:|--------|-|----:|--------|-|----:|--------|
|  35 | LWORD* | |  36 | A01*   | |  37 | A02*   |
|  38 | A03*   | |  39 | A04*   | |  40 | A05*   |
|  41 | A06*   | |  42 | A07*   | |  43 | A08*   |
|  44 | A09*   | |  45 | A10*   | |  46 | A11*   |
|  47 | A12*   | |  48 | A13*   | |  49 | A14*   |
|  50 | A15*   | |  51 | A16*   | |  52 | A17*   |
|  53 | A18*   | |  54 | A19*   | |  55 | A20*   |
|  56 | A21*   | |  57 | A22*   | |  58 | A23*   |

`LWORD*` indicates a long-word (32-bit) cycle.

`APARITY0*` is on **pin 33** (even parity for A01-A23 + LWORD + AM0-AM7).
`APVAL*` is on **pin 117** (parity-valid strobe).

### Address modifier

| Pin | Signal |
|----:|--------|
|  59 | AM4*   |
|  60 | (continues) |
|  63 | AM3* (?) — see source table  |
|  83 | AM0*   |
|  84 | AM1*   |
|  85 | AM2*   |
|  86 | AM6*   |
|  94 | AM5*   |

Eight `AM0*-AM7*` lines (size, cycle type, master ID) — pin 59, 60, 63, 83-86, 94 per Appendix C; the bit-to-pin mapping is mixed across the connector. Used by the master to qualify the address.

### Bus control

| Pin | Signal     | Description                                                   |
|----:|------------|---------------------------------------------------------------|
|  29 | TEST0*     | Reserved test signal                                          |
|  30 | AS*        | **Address Strobe** — valid address on bus                     |
|  31 | TEST1*     | Reserved test signal                                          |
|  34 | WRITE*     | **R/W*** — high = read, low = write                           |
|  25 | DS0*       | Data Strobe 0 (low byte D0-D7)                                |
|  26 | (pair)     |                                                              |
|  27 | DTACK*     | **Data Transfer Acknowledge** — slave handshake               |
|  81 | BERR*      | **Bus Error** — slave indicates unrecoverable                 |
|  78 | ACFAIL*    | AC power failure (open collector)                            |
|  74 | SYSRESET*  | System reset                                                 |
|  80 | SYSFAIL*   | System failure                                               |

### Interrupts (7-level prioritised, like 68K's IPL)

| Pin | Signal | | Pin | Signal |
|----:|--------|-|----:|--------|
|  87 | IRQ1*  | |  88 | IRQ2*  |
|  89 | IRQ3*  | |  90 | IRQ4*  |
|  91 | IRQ5*  | |  92 | IRQ6*  |
|  93 | IRQ7*  | |     |        |

Open-collector. Wired-OR on the backplane. CPU resolves priority
on its IPL2-IPL0 inputs.

| Pin | Signal     | Description                                          |
|----:|------------|------------------------------------------------------|
|  95 | ACKIN*     | Daisy-chained acknowledge in                         |
|  96 | ACKOUT*    | Daisy-chained acknowledge out                        |

### Bus arbitration (5-level priority)

| Pin | BG-IN  | BG-OUT | BR    |
|----:|--------|--------|-------|
|  97 | BG0IN* |        |       |
|  98 |        | BG0OUT*|       |
|  99 | BG1IN* |        |       |
| 100 |        | BG1OUT*|       |
| 101 | BG2IN* |        |       |
| 102 |        | BG2OUT*|       |
| 103 | BG3IN* |        |       |
| 104 |        | BG3OUT*|       |
| 105 | BG4IN* |        |       |
| 106 |        | BG4OUT*|       |
| 107 |        |        | BR0*  |
| 108 |        |        | BR1*  |
| 109 |        |        | BR2*  |
| 110 |        |        | BR3*  |
| 111 |        |        | BR4*  |

Plus:

| Pin | Signal | Description                                                |
|----:|--------|------------------------------------------------------------|
| 112 | BBSY*  | Bus busy — current master asserts                          |
| 113 | BCLR*  | Bus clear — arbiter requests release                       |
| 114 | BREL*  | Bus release — emergency requester signals master to clear  |
| 117 | APVAL* | Address parity valid                                       |
| 118 | DPVAL* | Data parity valid                                          |

### Clocks

| Pin | Signal  | Description                                            |
|----:|---------|--------------------------------------------------------|
|  69 | ACCLK   | AC clock — power-line zero-cross / freq reference      |
|  70 | SYSCLK  | System clock — 16 MHz, driven by the SBC               |

The M68KVM02 sources SYSCLK from its on-board 16 MHz crystal and
drives the rest of the chassis from it.

### Reserved (per Motorola spec, must not be driven by user cards)

Pins 23, 33 (other side of APARITY), 65, 71, 73, 75, 77, 82, 115,
116 — explicitly listed as reserved in the spec.

## P2 / J2 — I/O channel + serial (120 pins)

Per the M68KVM02 manual, P2 carries the local I/O channel (parallel
expansion), two **independent RS-232C** serial ports (Channel 1 and
Channel 2 of the µPD7201 SIO), and three timer I/O lines (the
MC6840 PTM's Tn input/output pins).

### Power and ground

| Pin | Signal     | Notes |
|----:|------------|-------|
| 1-6 | GND        | |
| 7-10 | +5V        | logic supply |
| 11, 12 | +12V    | line-driver supply |
| 15, 16 | -12V    | line-driver supply |
| 17, 45, 69, 70 | +15V | not used on M68KVM02 |
| 67, 68 | -15V    | not used on M68KVM02 |
| 18, 20, 27, 30, 32, 24, 45, 48, 50, 52, 54, 56, 58, 60, 62, 64, 66, 71, 83, 99, 111, 117 | GND | |
| 93 | +5VOUTB    | jumper-selectable +5V to I/O |
| 95 | -12VOUTB   | jumper-selectable -12V to I/O |
| 97 | +12VOUTB   | jumper-selectable +12V to I/O |

### I/O channel (parallel expansion)

Used to talk to **non-VERSAbus** local boards (e.g. small
single-function carriers).

| Pin | Signal      | Description                                          |
|----:|-------------|------------------------------------------------------|
| 19, 21-27, 28 | D0-D7 | I/O channel data bits (8-bit)                        |
| 33, 35-44, 46 | A00-A11 | I/O channel address (12-bit)                        |
|  29 | WT*         | Write strobe                                         |
|  31 | STI3*       | Strobe                                               |
|  53 | CLK         | I/O channel 4 MHz clock                              |
|  55 | XACK*       | Transfer acknowledge from external                   |
|  57 | RESET*      | I/O channel reset (open collector output)            |
|  59 | INT1*       | I/O channel interrupt 1                              |
|  61 | INT2*       | I/O channel interrupt 2                              |
|  63 | INT3*       | I/O channel interrupt 3                              |
|  65 | INT4*       | I/O channel interrupt 4                              |

This is distinct from the VERSAbus on P1 — it's the M68KVM02's
local-expansion port. No populated boards are visible in the
FPS-3000 chassis photos using this channel.

### Serial ports — µPD7201 Channel A

| Pin | Signal | Direction | Description                           |
|----:|--------|-----------|---------------------------------------|
|  73 | TXD1   | bidirec.  | Transmit data — Channel 1 (chA)       |
|  75 | RXD1   | bidirec.  | Receive data                          |
|  77 | RTS1   | output    | Request to send                       |
|  79 | CTS1   | input     | Clear to send                         |
|  81 | DSR1   | input     | Data set ready                        |
|  85 | DCD1   | input     | Data carrier detect                   |
|  87 | DTR1   | output    | Data terminal ready                   |
|  89 | RXC1   | bidirec.  | Receive clock (BRG out OR ext input)  |
|  91 | TXC1   | bidirec.  | Transmit clock                        |

### Serial ports — µPD7201 Channel B

| Pin | Signal | Direction | Description                           |
|----:|--------|-----------|---------------------------------------|
| 101 | TXD2   | bidirec.  | Transmit data — Channel 2 (chB)       |
| 103 | RXD2   | bidirec.  | Receive data                          |
| 105 | RTS2   | output    | Request to send                       |
| 107 | CTS2   | input     | Clear to send                         |
| 109 | DSR2   | input     | Data set ready                        |
| 113 | DCD2   | input     | Data carrier detect                   |
| 115 | DTR2   | output    | Data terminal ready                   |
| 117 | RXC2   | bidirec.  | Receive clock                         |
| 119 | TXC2   | bidirec.  | Transmit clock                        |

All RS-232C signal levels (Type C in M68KVM02 Table 3 — ±7 V mark/space,
sinks ±8.3 mA).

### Timer I/O — MC6840 PTM

| Pin | Signal   | Direction | Description                          |
|----:|----------|-----------|--------------------------------------|
|  72 | CLOCK1*  | input     | External clock to timer 1            |
|  74 | GATE1*   | input     | Gate to inhibit CLOCK1*              |
|  76 | OUTPUT1  | output    | Timer 1 output (selectable)          |
|  78 | CLOCK2*  | input     | External clock to timer 2            |
|  80 | GATE2*   | input     | Gate to inhibit CLOCK2*              |
|  82 | OUTPUT2  | output    | Timer 2 output                       |
|  84 | CLOCK3*  | input     | External clock to timer 3            |
|  86 | GATE3*   | input     | Gate to inhibit CLOCK3*              |
|  88 | OUTPUT3  | output    | Timer 3 output                       |

These three timer channels are how the MC6840 PTM at `$F70001-$F7000F`
talks to the outside world — but, as with the rest of P2, no
chassis-level wiring of these is visible from the FPS-3000 photos.
The RTOS uses one of the timers internally as the system tick (T1
or T3, with the prescaler enabled per the IRQ trace).

## How the FPS-3000 uses each connector

**P1 — VERSAbus:** fully populated. SBC is the master, talks to
XLTR (slot 13), AP I/F (slot 11), MEM CTL (slot 6), the 5 SCM
memory cards (slots 1-5), and the 4 XP-32 cards (slots 7-10) via
this bus. Address-decode for our memory map (`$FF0000-$FF00FF` AP
I/F, `$FF0200+` XLTR, etc.) takes place on the destination cards
listening for `AS*` low and matching `A23*-A01*`.

**P2 — I/O / serial / timer:** mostly **unpopulated** in this
chassis. The host doesn't use P2 (it goes through AP I/F at slot
11, see `serial_ports.md`). The SIO ports could in theory expose
a maintenance console, but the firmware never enables them. The
timer I/O is internal to the SBC — used as the RTOS system tick
but not routed off-card.

## Cross-reference

- `monitor/monitor.s` exercises the SIO at `$F70010` (chA data) and
  `$F70012` (chA control) — those are SBC-bus addresses, not P2 pin
  numbers. The chassis-side wiring from those bus addresses to
  P2/J2 RXD1/TXD1 (pins 75/73) goes through level shifters (1488/1489
  or equivalent) on the SBC card.
- `panel_command_protocol.md` covers the AP I/F / XLTR signalling,
  which is entirely on P1 — VERSAbus reads/writes to specific
  off-board addresses.
- `serial_ports.md` notes that the µPD7201 is unused by the firmware
  but our monitor brings it back to life.
