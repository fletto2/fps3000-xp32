# Panel Command Protocol

## Two distinct send paths

The SBC ROM sends panel commands to the chassis via **two different
paths** with different completion mechanisms:

### Path A — `PanelSendAndWait` at F056BA (polling-based)

Used by: setup code, simple sync commands.

```
SBC writes panel cmd → $FF000E (XLTR_CMD_ARG)
SBC writes 0x8004    → $FF0000 (REQUEST-TRANSFER opcode)
SBC polls            → $FF0000 bit 14 (ready) up to 1000 reads
   bit 14 == 1 (ready):
     check bit 13 (error flag)
       not set → send PCMD_RELEASE (0x26C)
       set     → send PCMD_ERROR_ABORT (0x269)
   loop times out: PCMD_ERROR_ABORT
```

Chassis ack: bit 14 of `cmd_status` ($FF0000) goes high after
processing.

### Path B — `PanelIOConfigure_F05E56` (XLTR-driven, IRQ-completed)

Used by: TCBIO1I host-link ISR (F05DD6+), TCBRDHC dispatch,
PanelIOConfigure_25A.

```
SBC writes panel cmd → $FF000E (XLTR_CMD_ARG)
SBC reads  XLTR_MODE1; bclr bit 14; bset bit 12; writes back
SBC reads  XLTR_MODE0; bclr bit 10;              writes back
SBC writes panel cmd → $FF0204 (XLTR_CHANNEL_SELECT)
SBC executes         → bra .   (spin-wait)
```

Chassis ack: an IRQ (at level >current-IPL, vector specific to the
panel-cmd class) fires and the handler **modifies the saved return
PC on the stack** to skip past the `bra .`. This is the same pattern
used by:

- `loc_F0A57E` (the system trap dispatcher) — ends in `bra .`
- `PanelIOConfigure_25A` at F056B8 — ends in `bra .`

The dispatch table at **F05BA4-F05C4B** (`PanelStatusDispatchTable`)
is a series of `4E FA xxxx` (JMP PC+offset) entries indexed by some
status code from the chassis ack. Each entry jumps to a different
handler that does the saved-PC fixup.

## Panel command catalog

Inferred from disassembly references and call-site context. All
codes are 16-bit immediate values written to `$FF000E`.

| Code  | Symbol           | Meaning (inferred)                       |
|-------|------------------|------------------------------------------|
| 0x258 | PCMD_CH1_RESET   | Reset channel 1 state                    |
| 0x259 | PCMD_CH1_INIT    | Initialise channel 1                     |
| 0x25A | PCMD_CH1_ACK     | ACK channel 1 (also the "magic" 25A)     |
| 0x25B | PCMD_CH1_FLUSH   | Flush channel 1 buffer                   |
| 0x25C | PCMD_RESET_STATUS | Clear chassis error/status               |
| 0x25D | PCMD_CH1_CONFIG  | Programme channel 1 config               |
| 0x25E | PCMD_CH2_CONFIG  | Programme channel 2 config               |
| 0x25F | PCMD_CH3_CONFIG? | Programme channel 3 config (presumed)    |
| 0x260 | PCMD_CH4_CONFIG? | Programme channel 4 config (presumed)    |
| 0x269 | PCMD_ERROR_ABORT | Abort current op, error flagged          |
| 0x26A | PCMD_unknown_26A | Used in error-recovery; effect not isolated |
| 0x26B | PCMD_unknown_26B | Used in error-recovery                   |
| 0x26C | PCMD_RELEASE     | Cleanup after successful op              |
| 0x276 | PCMD_INIT_STEP1  | TCBRDHC startup step 1                   |
| 0x277 | PCMD_INIT_STEP2  | TCBRDHC startup step 2                   |
| 0x278 | PCMD_INIT_STEP3  | TCBRDHC startup step 3                   |
| 0x279 | PCMD_INIT_STEP4  | TCBRDHC startup step 4                   |
| 0x27A | PCMD_INIT_STEP5  | TCBRDHC startup step 5                   |
| 0x27B | PCMD_INIT_STEP6  | TCBRDHC startup step 6                   |
| 0x27D | PCMD_INIT_FINAL  | TCBRDHC startup completion               |
| 0x281 | PCMD_GET_HOST_BYTE | Pull next byte from host buffer        |
| 0x282 | PCMD_GET_HOST_BYTE_RESYNC | Re-pull current byte (no advance) |

The 0x258-0x27D codes also have an **alternative interpretation**:
they all decode as valid **Am29116 SUBRC** instructions (per
`panel_codes_am29116_decoded.md`). The byte the chassis sees may
literally be an Am29116 opcode that the EU sequencer executes — three
hypotheses remain live (raw-instr, MMIO-side-effect, hybrid). The
chassis-side responder just acks and returns predictable data; the
microcode-vs-dispatch dichotomy doesn't matter for the SBC firmware.

## SBC-side workflow for a single host byte (Path B)

```
SBC TCBIO1I task body (entry F05DD6, also installed at vec $128):
  1. Read mailbox $70001C, btst bit 29 (host-attention flag)
        bit set:
            d0 = 0x281 (PCMD_GET_HOST_BYTE)
            jsr F05E56 (IRQ-driven send)
            ; chassis fires IRQ here, ISR returns past the bra .
            ; channel-1 data ports now hold the next byte
            d2 = mem[$10AA] (long)  ← chassis cmd-state field
            d2 == 0:  d0 = 0x282; loop (re-fetch)
            d2 == 2:  process byte
            d2 == other: F05E44 (alt path)
        bit clear: skip to byte-process step
  2. Read $FF0048 (CH1_DATA_A) for the byte
  3. RMS68K trap to forward byte to TCBRDHC's ASQ
  4. RTE
```

## Open question: how is `$10AA` set?

`$10AA.l` is read at F05E12 to dispatch on the chassis's response
class. Searching the ROM finds **only one reference** to the address
(the load at F05E14). Nothing in the ROM writes to `$10AA`.

Hypotheses:

1. **Chassis DMAs into RAM**. The chassis (via XLTR DMA) writes the
   response code directly into SBC RAM at $10AA. The SBC reads it
   back through normal memory access. This matches FPS-100's
   DRIVER.MAC where the chassis can DMA into host memory at HMA.

2. **It's a kernel-side variable** updated by the RMS68K syscall
   (TRAP #1 dir 15) the ISR posts. The kernel tracks state on behalf
   of TCBIO1I.

3. **It's set by another task we haven't traced.** Possibly by an
   ISR for a different vector that fires alongside the panel-cmd
   completion.

Implementing the proper responder requires resolving this — without
$10AA being set, the SBC loops between 0x281 and 0x282 forever.

## Emulator status

Implemented:

- `versabus_chassis_queue_byte()` — host_sim queues a byte
- Path A (polling) responder: `chassis_process_panel_cmd()` triggered
  by 0x8004/0x8005 write to $FF0000. Sets cmd_status bit 14 (ready),
  clears bit 13. For 0x281 also delivers queued byte to ch1 ports.
- Boot-complete gate so host_sim doesn't fire IRQs during init.
- Level-5 vectored IACK returns 0x4A → vec $128 → F05DD6.

Not yet implemented (needed for end-to-end S-record upload):

- Path B (XLTR + bra .) IRQ that modifies saved PC. Requires either:
  - Reverse-engineering `PanelStatusDispatchTable` and emitting the
    correct vector + handler combination, or
  - Modeling chassis DMA into SBC RAM (writing $10AA, $1066-$106A,
    etc.) so the bra .-spinning code finds its expected response in
    memory and proceeds.

The infrastructure is in place; closing the loop on Path B requires
~1-2 days of further reverse engineering of F05BA4-F05C4B and the
`$10AA` writer.
