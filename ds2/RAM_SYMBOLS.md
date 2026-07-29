# FPS-3000 RAM Global Variable Table

Every absolute-address RAM reference in `fps3k.asm` at addresses
$0000-$2000, grouped by function. Cross-referenced against the
emulator model and known firmware behavior.

"Observed" = value seen in boot-time emulator RAM dump.
"Written by" = site(s) in firmware that write this address.
"Read by" = site(s) that read it.

---

## Exception Vector Table ($000-$3FF)

| Address | Width | Purpose | Observed value | Notes |
|---|---|---|---|---|
| $100-$103 | long | TRAP #0 vector (generic handler) | F00D0C | RMS68K kernel |
| $104-$107 | long | Vector #41 = BIM0 ch0 (TCBRDHC panel responder) | F04930 | Installed by RTOSKernelInit |
| $114-$117 | long | Vector #45 = BIM1 ch2 (TCBXP1I ISR) | F07EE6 | Installed by RTOSKernelInit |
| $118-$11B | long | Vector #46 = BIM1 ch3 (TCBXP2I ISR) | F074E6 | Installed by RTOSKernelInit |
| $11C-$11F | long | Vector #47 = BIM2 ch0 (TCBXP3I ISR) | F06AE6 | Installed by RTOSKernelInit |
| $120-$123 | long | Vector #48 = BIM2 ch1 (TCBXP4I ISR) | F060CE | Installed by RTOSKernelInit |
| $128-$12B | long | Vector #4A = BIM2 ch2 (TCBIO1I ISR) | F05DD6 | Boot-complete gate for host_sim and DMA10AA |
| $140-$143 | long | Vector #50 = chassis IRQ vector $50 | F09278 (self-test) → F0A27A (post-RTOS) | Phase 0x1300 test; RTOS overwrites with panic |
| $150-$153 | long | Vector #54 = PTM IRQ vector | F0911E (self-test) → F0A27A (post-RTOS) | Phase 9 test; RTOS overwrites with panic |

## Vector Table (higher)

| $800-$803 | long | Vector #200 (unused) | F000F0 | RMS68K kernel filler |

## RTOS Data Structures ($10000-$1FFFF)

The upper 64 KB of RAM. Multiple data structures live here; their
exact boundaries are known from RTOSKernelInit tag writes.

| Address | Width | Tag/Name | Content | Notes |
|---|---|---|---|---|
| $10000-$1DEFF | 56.75 KB | WCS staging buffer | Microcode data | The usable portion; live RTOS data above $1DF00 |
| $1E900 | ~352B | !TCB for TCBRDHC | TCB #1 | Task name "RDHC" at +$10, entry F046F0 at +$6C |
| $1EB00 | ~352B | !TCB for TCBXP1I | TCB #2 | Task name "XP1I" at +$10 |
| $1ED00 | ~352B | !TCB for TCBXP2I | TCB #3 | |
| $1EF00 | ~352B | !TCB for TCBXP3I | TCB #4 | |
| $1F100 | ~352B | !TCB for TCBXP4I | TCB #5 | |
| $1F300 | ~352B | !TCB for TCBIO1I | TCB #6 | ISR vector $128 = F05DD6 |
| $1F600 | ? | !UDR tag | |
| $1F700 | ? | !PAT tag | |
| $1F800 | ? | !IDV tag | |
| $1F900 | ? | !IOV tag | |
| $1FB00 | ? | !UST tag | |
| $1FD00 | ? | !GST tag | |
| $1FFD0 | long | Supervisor stack top | Initial SP | Hardware-defined |
| $1FFF0-$1FFF1 | word | VMOD control register image | Variable | Writes here gate chassis behavior |

## FPS Application Globals ($0E00-$10FF)

### Panel Command / Channel State

| Address | Width | Symbol | Meaning | Written by | Read by |
|---|---|---|---|---|---|
| $E58 | long | `g_srec_addr` | S-record destination pointer (high word at $E58, low at $E5A) | F04CF2 (addr high), scripted chassis responses | F04AE2 (bulk transfer loop) |
| $E5A | word | `g_srec_addr` low | Low 16 bits of destination | F04CF2+F04D20 (addr low from CHANNEL_SELECT) | F04AE2 |
| $E5C | word | `g_xfer_mode` | CHANNEL_SELECT readback cache ($28 = bulk pending) | F04A84 | F04AC8 (gate for bulk transfer) |
| $E5E | word | — | Unknown | Unresolved | Unresolved |
| $E60 | word | channel # | Current XP channel number (1-4), validated ≤ $105E | F0534C | F04992, F0538A (range check) |
| $E62 | word | — | Unknown | | |
| $E64 | long | `g_panel_expected` | Transfer word count (high at $E64, low at $E66) | F04D20 (count high), F04D4E (count low) | F04AF8 (loop limit) |
| $E66 | word | `g_panel_expected` low | Low 16 bits of word count | | |
| $E68 | word | — | Unknown | | |
| $E6A | word | — | Unknown | | |
| $E6E | word | `g_opcode_latch` | Panel command stash (all 8 issuer copies write here) | F0450E, F05696, F05E64, etc. | Unknown |
| $E70 | word | — | Unknown | | |
| $E72 | word | — | Unknown | | |
| $E74 | word | `g_result` | Command result register (returned to chassis via CHANNEL_SELECT) | F04C74, F0502C | F04CF2 readback |
| $E7A | — | — | Unknown | | |
| $E7C | — | — | Unknown | | |
| $E7E | — | — | Unknown | | |
| $E86 | byte | `g_latched_mode` | Latched chassis response code in bits 0-4; ack flag bit 10 set by handler | F04942 (handler latches MODE0) | F04752 (==8 check), F0497A (range 0..$14), F04A6E+ |
| $E87 | byte | `g_response_flags` | bit 5 = 32-bit argument mode; bit 6 = address table select; bit 7 = error condition | Various branches | F048D8 (bit 7 error), F04A6E (bit 7 dispatcher select), F04A1E (bit 6 addr select), F04B22 (bit 5 mode) |

### Per-Channel Data ($1000-$10FF)

| Address | Width | Symbol | Meaning | Notes |
|---|---|---|---|---|
| $101E | word | — | Address table entry 1 (used when bit 6 of $E87 is clear) | Referenced at F04A1E+ |
| $1020 | word | — | Address table entry 2 (used when bit 6 of $E87 is set) | Referenced at F04A1E+ |
| $105E | word | `g_ac_count` | Channel presence count — CPU-written at F0A224, not chassis-DMA'd | Probes 4 command ports; count of nonzero ones |
| $1062 | word[4] | — | ISR scratchpad for channel 1 ($1062-$1069) | FP07ED6: ISR reads $FF004E → $1066 |
| $1064 | word | — | Unknown | |
| $1066 | word | — | ISR snapshot of $FF004E (channel command port) for XP1I | btst #$B at F07EB6 gates the $8000/$1B sequence |
| $1068 | word | — | ISR snapshot of $FF0048 (channel data HIGH) | F07EFA |
| $106A | word | — | ISR snapshot of $FF004A (channel status) | F07F02 |
| $106C-$107E | word[10] | — | ISR scratchpad for channels 2,3,4 (windowed at +$20) | Same pattern as 1066-$106A for other channels |
| $1080 | — | — | Per-channel data-pointer table (MC finding) | Identified, not decoded |
| $10A0-$10A6 | word[4] | — | Per-channel init array (channels 1-4) | Written by F053E2 (indexed `(ch-1)*2`) |
| $10A8 | word | — | Unknown | |
| $10AA | word | — | **Chassis-DMA'd dispatch value** | Read by TCBIO1I ISR at F05E12; no ROM code writes nonzero. Value=2 → reply arm at F05E40 |
| $10AC | word | — | Unknown (likely paired with $10AA as longword) | |

## Status / Open Items

- **$E4C**: referenced but purpose unclear. Possibly panel-cmd scratch.
- **$E68, $E6A, $E70, $E72**: gap words in the channel state block. Never
  referenced by absolute address in the disassembly but may be
  accessed via computed offsets.
- **$10A8-$10AD**: the word before and after $10AA. Likely a 4-byte
  structure the chassis writes as a longword.
- **$1080**: "per-channel data-pointer table" — identified by MC pass
  as indexed table, never decoded. May be how the four XP tasks
  locate their per-channel state.
- **The $1060-$107F block**: each channel's ISR stores results to
  consecutive words at $1060 + (ch-1)*$20, so the channel's private
  state window is 32 bytes. This is the same stride as the APIF
  channel windows ($FF0040 + ch*$20) — likely not coincidence.
- **$E58/$E5C/$E60/$E64 block**: 16 consecutive bytes at $E58-$E67
  form a parameter block loaded by channel-config and transfer-setup
  routines. All 16 bytes are accounted for as fields above.
- **$E87 bit assignments**: bit 0-4 = response code (cleared on ack),
  bit 5 = 32-bit argument mode, bit 6 = address table select,
  bit 7 = error condition. Bits 0-4 confirmed by F0496E (andi #$1F).
  Bits 5-7 confirmed by branch sites. No other bits referenced.
