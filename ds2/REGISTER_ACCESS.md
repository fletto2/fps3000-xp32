# VersaBUS Register Access Inventory

Every VersaBUS-address register the firmware reads or writes, listed
by the code that performs the access. Based on the emulator bus log
(dynamic) and `fps3k.asm` static analysis (versabus_access_map.md).

"Observed" = seen in emulator bus log over full boot.
"Static only" = referenced in disassembly but never executed in emulator.

---

## AP I/F Registers ($FF0000-$FF00FF)

### $FF0000 — CMD_STATUS (opcode write, bit 14=ready, bit 13=error)

| PC | Function | Access | Value(s) | Observed? | Notes |
|---|---|---|---|---|---|
| F056A8 | PanelIOConfigure_25A | WR 0x8004 | 0x8004 | Yes | REQUEST-TRANSFER: triggers chassis to process queued panel cmd |
| F0575C | D2_FIN handler | WR 0x8005 | 0x8005 | No | CONTINUE-TRANSFER: re-fires current cmd |
| F0572C | PanelStatusDispatch | RD | poll bit 14 | No | Poll loop waits for ready=1 |
| F04ABE | Bulk transfer arm | RD | poll bit 14 | No | Wait for chassis ready |
| F05A18 | POLL handler | RD | — | No | Poll ready after STATUS_IRQ arm |
| F05218 | SRecord drain loop | RD | exit on ≤0 | No | Signed compare against 0 — chassis clears register at EOF |

### $FF0004 — APIF_READY (port-ready flag, bit 0)

| PC | Function | Access | Value | Observed? | Notes |
|---|---|---|---|---|---|
| F04B22 | SRecord port poll | RD | bit 0 = data available | No | Only accessed via FPS3K_SREC path |
| F05A22 | POLL handler | RD | bit 0 poll | No | Wait for port ready |

### $FF0008 — APIF_BULK_DATA (bidirectional bulk data port)

| PC | Function | Access | Value | Observed? | Notes |
|---|---|---|---|---|---|
| F04AE2 | Bulk transfer loop | RD | word from chassis | Yes (FPS3K_SEQ) | Read one word per cycle in loop: `move.w (a0),(a1)+` |
| F04C50 | Outbound bulk | WR | word to chassis | No | Same port, opposite direction |
| F04B22 | SRecord ASCII receiver | RD | two ASCII chars as word | No | "S0" = $5330 triggers SRecordDataHandler |

### $FF000E — APIF_CMD_ARG_LO (panel command staging)

| PC | Function | Access | Value(s) | Observed? | Notes |
|---|---|---|---|---|---|
| F04518 | PanelIOConfigure (copy 1) | WR | panel command | Yes | All 8 copies write here before $FF0000=0x8004 |
| F05696 | PanelIOConfigure (copy 2) | WR | panel command | Yes | |
| F05E6C | PanelIOConfigure (copy 3) | WR | panel command | No | In TCBIO1I |
| F068B6 | PanelIOConfigure (copy 4) | WR | panel command | No | In TCBXP2I |
| F072CE | PanelIOConfigure (copy 5) | WR | panel command | No | |
| F07CDE | PanelIOConfigure (copy 6) | WR | panel command | No | |
| F086CE | PanelIOConfigure (copy 7) | WR | panel command | No | |
| F0A598 | PanelIOConfigure (copy 8) | WR | panel command | No | |

### $FF0010 — APIF_CMD_ARG_HI (argument high word)

| PC | Function | Access | Value(s) | Observed? | Notes |
|---|---|---|---|---|---|
| F04522 | PanelIOConfigure (copy 1) | WR | 0 | Yes | Always written 0 in all 8 copies |
| (7 more copies) | | WR | 0 | Yes | Same pattern |

### $FF0040+ — Channel Windows (4 × 32-byte)

**Channel 1 ($FF0040-$FF005F):**

| Offset | PC | Function | Access | Value | Observed? | Notes |
|---|---|---|---|---|---|---|
| +$04 ($FF0044) | F07E2C | TCBXP1I task body | WR | 0 | No | Write port — always cleared |
| +$08 ($FF0048) | F07E2C | TCBXP1I task body | WR | 0 | No | Data HIGH — always cleared first |
| +$08 ($FF0048) | F07EFA | TCBXP1I ISR | RD | — | No | ISR reads data HIGH from chassis |
| +$0A ($FF004A) | F07E38 | TCBXP1I task body | WR | $001B | No | Data LOW — $1B is the "ready" constant |
| +$0A ($FF004A) | F07F02 | TCBXP1I ISR | RD | — | No | ISR reads status from chassis |
| +$0E ($FF004E) | F07E3E | TCBXP1I task body | WR | $8000 | No | Command/trigger — $8000 fires the channel operation |
| +$0E ($FF004E) | F07ED6 | TCBXP1I ISR | RD | → $1066 | No | ISR snapshots command port; btst #$B gates $8000/$1B write |

**Channels 2-4** follow the same pattern at $FF0060+, $FF0080+, $FF00A0+.

### $FF004A — Channel 1 Status (host-injected)

| PC | Function | Access | Value | Observed? | Notes |
|---|---|---|---|---|---|
| TCBIO1I ISR (F05DD6) | Host-link ISR | RD | 0x4F | No (emulator stalled) | Read alongside $FF0048; host sim injects 0x4F |

---

## XLTR Registers ($FF0200-$FF021B)

### $FF0200 — XLTR_MODE0

| PC | Function | Access | Value | Observed? | Notes |
|---|---|---|---|---|---|
| F04942 | BIM0 ch0 ISR (F04930) | RD | chassis-supplied | No (level-6 blocked) | Reads chassis response code |
| F0495C | F04930 | WR | ack bit 10 set | No | Sets ACK bit after latching code |
| F04A6E | F04930 | RD | response code | No | bit 7 selects dispatcher: 0 → 16-entry table, 1 → F0495C path |
| F0452E-F0A5AE | All 8 issuer copies | WR | bit 10 cleared | Yes | Clear ACK before writing CHANNEL_SELECT |
| F056AC | PanelIOConfigure | WR | bit 10 cleared | Yes | Reads MODE0, clears ACK bit. F056A0 is a MODE1 write (see below). |
| F0958C | Phase 0x1600 self-test | RD+WR | walk patterns | Yes | Register round-trip test |

### $FF0202 — XLTR_MODE1

| PC | Function | Access | Value | Observed? | Notes |
|---|---|---|---|---|---|
| F056A0 | PanelIOConfigure | WR | bit 12 set, bit 14 cleared | Yes | Enables Path B panel command |
| F087C2 | Phase 0x1A00 self-test | WR | bit 15 (0x8000) engage | Yes | Arms chassis operation; busy_ticks starts |
| F08846 | Phase 0x1A00 wait | RD | poll bit 15 | Yes | Wait for chassis to report done |
| F0451A-F0A59A | All 8 issuer copies | WR | bit 14 cleared, bit 12 set | Yes | Same pattern in all 8 copies: `bclr #$e, d1` then `bset #$c, d1` |

### $FF0204 — XLTR_CHANNEL_SELECT

| PC | Function | Access | Value | Observed? | Notes |
|---|---|---|---|---|---|
| F04534-F0A5A4 | All 8 issuer copies | WR | panel command code | Yes | Written right before `bra .` spin |
| F04A84 | Channel config dispatch | RD | variable | No | Read back: $28 = bulk transfer pending |
| F04CF2 | Addr-low loader | RD | variable | No | Returns address low half from chassis |
| F04D20 | Addr-high loader | RD | variable | No | Returns address high half from chassis |
| F04D4E | Count-low loader | RD | variable | No | Returns count low half from chassis |
| F04D6A | Count-high loader | RD | variable | No | Returns count high half from chassis |
| F0502C | Response handler | WR | $E74 (result register) | No | Writes result back to chassis |
| Phase 0x1000-0x1A00 | Self-test | WR | phase IDs (0x1000, etc.) | Yes | Each phase writes its ID here |

### $FF020C — XLTR_COUNTER / CONFIG

| PC | Function | Access | Value | Observed? | Notes |
|---|---|---|---|---|---|
| F056A0+ | PanelIOConfigure | WR | 0x04 | No | Operational value during channel setup |
| F0A19C | Boot init | WR | 0x01/0xFF | No | Boot diagnostic values |
| Phase 0x1600 | Self-test | RD+WR | walk patterns | Yes | Register round-trip test |

### $FF0210 — XLTR_MODE2

| PC | Function | Access | Value | Observed? | Notes |
|---|---|---|---|---|---|
| Various channel setup | — | WR | 0x0000 | No | Cleared during channel configuration |
| Phase 0x1600 | Self-test | RD+WR | walk patterns | Yes | Round-trip test |

### $FF0214 — XLTR_DATA_LO

| PC | Function | Access | Value | Observed? | Notes |
|---|---|---|---|---|---|
| Self-test | Phase 0x1900 | RD+WR | patterns | Yes | Writes pattern, verifies readback via chassis window |

### $FF0216 — XLTR_DATA_HI

| PC | Function | Access | Value | Observed? | Notes |
|---|---|---|---|---|---|
| Self-test | Phase 0x1700/0x1800 | WR | 0x00, 0x20, 0x40 | Yes | Selects chassis memory page; bit 5 = BERR gate |

### $FF0218 — XLTR_STATUS_IRQ

| PC | Function | Access | Value | Observed? | Notes |
|---|---|---|---|---|---|
| F04A8C | Bulk transfer arm | WR | 0x0400 | No | Arm — chassis DMA ready gate |
| F05A14 | POLL handler | WR | 0x0400 | No | Arm in POLL dispatch path |
| F04A92 | Bulk transfer wait | RD | poll bit 15 | No | Wait for bit 15 = ready/done |
| F05A18 | POLL handler | RD | poll bit 15 | No | |
| F04A9C | Bulk transfer done | WR | 0x0000 | No | Clear after transfer completes |
| Phase 0x1600 | Self-test | RD+WR | 0x400, 0x000 | Yes | Tests arm + verify status = 0x610 |
| Phase 0x1A00 | Self-test | WR | 0x400 | Yes | Arm for DMA BERR test |

### $FF021A — XLTR_IRQ_MASK

| PC | Function | Access | Value | Observed? | Notes |
|---|---|---|---|---|---|
| F05D0C | TCBIO1I init | WR | 0xFFF | No (TCBIO1I not fully run) | Mask all IRQs during init |
| PanelErrorMaskTable | Error handler | WR | per-error bitmask | No | Selective unmask during error recovery |

---

## BIM Registers ($FF0230-$FF025F)

### $FF0230 — BIM0 ch0 CR (TCBRDHC, level 6)

| PC | Function | Access | Value | Observed? | Notes |
|---|---|---|---|---|---|
| F04750 | TCBRDHC init | WR | $5E | Yes | Level 6, IRE set. This is WHY RDHC can never preempt a level-7 channel ISR. |

### $FF0232-$FF0236 — BIM0 ch1-ch3 CR (disabled after boot)

| PC | Function | Access | Value | Observed? | Notes |
|---|---|---|---|---|---|
| F0A164-F0A1CA | RTOSKernelInit | WR | $00 | Yes | Zeroed — all disabled |

### $FF0238-$FF023E — BIM0 VR0-VR3

| PC | Function | Access | Value | Observed? | Notes |
|---|---|---|---|---|---|
| F0A164+ | RTOSKernelInit | WR | $41, $42, $43, $44 | Yes | vec 41 (F04930), 42-44 (generic F00896) |

### $FF0240 — BIM1 ch0 CR (unused)

| PC | Function | Access | Value | Observed? | Notes |
|---|---|---|---|---|---|
| — | — | — | never written | — | This BIM channel is never touched by any code |

### $FF0242 — BIM1 ch1 CR (disabled)

| PC | Function | Access | Value | Observed? | Notes |
|---|---|---|---|---|---|
| F0A1B0 | RTOSKernelInit | WR | $00 | Yes | Disabled; vector VR = $49 ($124 = panic F0A27A) |

### $FF0244 — BIM1 ch2 CR (TCBXP1I, level 7)

| PC | Function | Access | Value | Observed? | Notes |
|---|---|---|---|---|---|
| F07E22 | TCBXP1I prologue | WR | $5F | No (XP1I blocks before this) | Level 7, IRE set |

### $FF0246 — BIM1 ch3 CR (TCBXP2I, level 7)

| PC | Function | Access | Value | Observed? | Notes |
|---|---|---|---|---|---|
| F07422 (shared body) | TCBXP2I prologue | WR | $5F | No | Level 7, IRE set |

### $FF0248-$FF024F — BIM1 VR0-VR3

| PC | Function | Access | Value | Observed? | Notes |
|---|---|---|---|---|---|
| F0A1B4+ | RTOSKernelInit | WR (VR1 only, vec $49) | $49 | Yes | Only VR1 loaded; VR0/VR2/VR3 never written |

### $FF0250 — BIM2 ch0 CR (TCBXP3I, level 7)

| PC | Function | Access | Value | Observed? | Notes |
|---|---|---|---|---|---|
| F06A02 (shared body) | TCBXP3I prologue | WR | $5F | No | Level 7, IRE set |

### $FF0252 — BIM2 ch1 CR (TCBXP4I, level 7)

| PC | Function | Access | Value | Observed? | Notes |
|---|---|---|---|---|---|
| F05F0E | TCBXP4I prologue | WR | $5F | No | Level 7, IRE set |

### $FF0254 — BIM2 ch2 CR (TCBIO1I, level 7)

| PC | Function | Access | Value | Observed? | Notes |
|---|---|---|---|---|---|
| F05DB8 | TCBIO1I init | WR | $5F | Yes | Level 7, IRE set. Host-link channel. |

### $FF0256 — BIM2 ch3 CR (disabled)

| PC | Function | Access | Value | Observed? | Notes |
|---|---|---|---|---|---|
| F0A1C2 | RTOSKernelInit | WR | $00 | Yes | Disabled |

### $FF0258-$FF025E — BIM2 VR0-VR3

| PC | Function | Access | Value | Observed? | Notes |
|---|---|---|---|---|---|
| F0A1C6+ | RTOSKernelInit | WR | $47, $48, $4A | Yes | vec 47 (XP3I), 48 (XP4I), 4A (TCBIO1I). VR3 never loaded. |

---

## Mailbox ($70001C, $700020)

### $70001C — MAILBOX_HOST_STATUS

| PC | Function | Access | Value | Observed? | Notes |
|---|---|---|---|---|---|
| F05DFA | TCBIO1I ISR | RD (long) | $20000000 | Yes (with host_sim) | Bit 29 set → enters receive arm (PCMD_HOST_REQUEST) |

### $700020 — MAILBOX_SBC_REPLY

| PC | Function | Access | Value | Observed? | Notes |
|---|---|---|---|---|---|
| F05E40 | TCBIO1I ISR (reply arm) | WR (long) | $00010002 | Yes (with DMA10AA=2) | Reply word with bit 1 set — class field response |

---

## Known Static-Only Accesses (never observed in emulator)

These code sites reference VersaBUS registers but never execute in any
emulator run:

- **All four XP task bodies past $trap #1 $13**: ~2500 bytes each of
  panel command writes, channel register configurations, DMA init
  sequences. Blocked waiting for BIM interrupt.
- **TCBRDHC main loop body (F04752+)**: Mode-state machine, channel
  dispatch ($E86 decisions), SRecordDataHandler.
- **PanelSendAndWait body (F056BA+)**: POLL/D1_SEND/BLK_XFR handlers,
  transfer-setup subroutines (F04CF2-F04F3A).
- **TCBIO1I host-byte receive path (F05DFA+)**: $70001C read with
  bit 29 set, PCMD_HOST_REQUEST (0x281), byte response handling.
  Deadlocked at level 7.
- **SRecordFinalize_andHelpers (F05256+)**: The WCS bank finalization
  sequence — select-channel, set-address, set-count, write-memory,
  arm DMA.

The table above is comprehensive for dynamic accesses. For static-only
accesses, the complete catalog is in `refs_extracted/versabus_access_map.md`
(Section 2: "Static-only VersaBus references").
