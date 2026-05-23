# PanelStatusDispatchTable — fully reverse-engineered

Location: `F05BA4-F05C4B`. **42 entries × 4 bytes = 168 bytes.**

## How it's used

```
F0572C: lsl.w #$2, d0           ; d0 = response code → byte offset
F0572E: lea PanelStatusDispatchTable, a4
F05734: jmp (a4, d0.w)          ; computed jump
```

`d0` is a **6-bit response/state code** (range 0-41) supplied by the
chassis as part of the panel-command ack. It's set by the IRQ handler
that completes the panel-cmd "bra ." spin-wait, then read by the
dispatcher at F0572C.

## The four handlers

Only four distinct action handlers exist in the table; the rest of the
slots are RTS-fall-through (no-op for that response code).

| Symbol  | Address | What it does                                                     |
|---------|---------|------------------------------------------------------------------|
| POLL    | F05A12  | Poll `$FF0004` bit 0 high, then write `0x400` to XLTR_STATUS_IRQ (arm), poll bit 15 high, clear STATUS_IRQ. Synchronises with the chassis. |
| D1_SEND | F058B2  | Store d1 (long) to `(a1)` and `(a1+2)` (i.e. 4 bytes of d1 split across two words at the destination), write `0x8004` (REQUEST-TRANSFER) to `$FF0000`. Used to push a 4-byte header chunk to the chassis, then continue. On error (d0=4) consults `PanelErrorMaskTable` to mask off the relevant XLTR_IRQ_MASK bit. |
| BLK_XFR | F05B0E  | Copy a 16-bit word from `(a1)` to `(a2)`, conditionally also `2(a1)` to `(a2)` or to `2(a2)`, then `addq.l #4, a2`, then write `0x8004` to `$FF0000`. Bulk-data pull: chassis word goes into a buffer indexed by a2. |
| D2_FIN  | F05738  | Same shape as D1_SEND but with d2 instead of d1, and with `0x8005` (CONTINUE-TRANSFER) followed by `0x26C` (PCMD_RELEASE). This is the **transfer-complete** path. |

Plus:

- **`<RTS>`** at the start of an entry — falls through to whatever
  follows in the JSR call chain. Used for response codes that need
  no chassis-side action.

## Full table

| idx (d0) | bytes      | Target  | Class    |
|---------:|------------|---------|----------|
|   0 (00) | 4E 75 4E 71 | (RTS)   | noop     |
|   1 (01) | 4E FA FE 68 | F05A12  | POLL     |
|   2 (02) | 4E FA FD 04 | F058B2  | D1_SEND  |
|   3 (03) | 4E FA FD 00 | F058B2  | D1_SEND  |
|   4 (04) | 4E FA FC FC | F058B2  | D1_SEND  |
|   5 (05) | 4E FA FC F8 | F058B2  | D1_SEND  |
|   6 (06) | 4E FA FC F4 | F058B2  | D1_SEND  |
|   7 (07) | 4E FA FC F0 | F058B2  | D1_SEND  |
|   8 (08) | 4E FA FF 48 | F05B0E  | BLK_XFR  |
|   9 (09) | 4E FA FF 44 | F05B0E  | BLK_XFR  |
|  10 (0A) | 4E FA FE 44 | F05A12  | POLL     |
|  11 (0B) | 4E 75 4E 71 | (RTS)   | noop     |
|  12 (0C) | 4E 75 4E 71 | (RTS)   | noop     |
|  13 (0D) | 4E FA FC D8 | F058B2  | D1_SEND  |
|  14 (0E) | 4E FA FC D4 | F058B2  | D1_SEND  |
|  15 (0F) | 4E FA FC D0 | F058B2  | D1_SEND  |
|  16 (10) | 4E FA FC CC | F058B2  | D1_SEND  |
|  17 (11) | 4E 75 4E 71 | (RTS)   | noop     |
|  18 (12) | 4E 75 4E 71 | (RTS)   | noop     |
|  19 (13) | 4E 75 4E 71 | (RTS)   | noop     |
| **20 (14)** | 4E FA FB 42 | **F05738** | **D2_FIN** ← only FIN entry |
|  21 (15) | 4E 75 4E 71 | (RTS)   | noop     |
|  22 (16) | 4E FA FE 14 | F05A12  | POLL     |
|  23 (17) | 4E FA FE 10 | F05A12  | POLL     |
|  24 (18) | 4E FA FF 08 | F05B0E  | BLK_XFR  |
|  25 (19) | 4E FA FE 08 | F05A12  | POLL     |
|  26 (1A) | 4E FA FF 00 | F05B0E  | BLK_XFR  |
|  27 (1B) | 4E FA FE 00 | F05A12  | POLL     |
|  28 (1C) | 4E FA FE F8 | F05B0E  | BLK_XFR  |
|  29 (1D) | 4E FA FE F4 | F05B0E  | BLK_XFR  |
|  30 (1E) | 4E FA FE F0 | F05B0E  | BLK_XFR  |
|  31 (1F) | 4E FA FD F0 | F05A12  | POLL     |
|  32 (20) | 4E 75 4E 71 | (RTS)   | noop     |
|  33 (21) | 4E 75 4E 71 | (RTS)   | noop     |
|  34 (22) | 4E FA FD E4 | F05A12  | POLL     |
|  35 (23) | 4E FA FE DC | F05B0E  | BLK_XFR  |
|  36 (24) | 4E FA FD DC | F05A12  | POLL     |
|  37 (25) | 4E FA FE D4 | F05B0E  | BLK_XFR  |
|  38 (26) | 4E 75 4E 71 | (RTS)   | noop     |
|  39 (27) | 4E 75 4E 71 | (RTS)   | noop     |
|  40 (28) | 4E 75 4E 71 | (RTS)   | noop     |
|  41 (29) | 4E 75 4E 71 | (RTS)   | noop     |

## Class distribution

| Class    | Count | Codes |
|----------|------:|-------|
| POLL     | 12    | 1, 10 (0A), 22-23 (16-17), 25 (19), 27 (1B), 31 (1F), 34 (22), 36 (24) |
| D1_SEND  | 10    | 2-7 (02-07), 13-16 (0D-10) |
| BLK_XFR  | 11    | 8-9 (08-09), 24 (18), 26 (1A), 28-30 (1C-1E), 33 (21), 35 (23), 37 (25) |
| D2_FIN   |  1    | 20 (14) ← **transfer-complete** |
| noop     |  9    | 0, 11-12 (0B-0C), 17-19 (11-13), 21 (15), 32 (20), 38-41 (26-29) |

## Read as a state machine

The codes break into rough groups consistent with a streaming-DMA
protocol:

- **00:** initial / idle / unused fall-through
- **01:** waiting-for-chassis (POLL)
- **02-07:** "send next 4-byte header chunk from d1" — six consecutive
  D1_SEND codes suggest a 6×4 = 24-byte protocol-header negotiation
- **08-09:** "pull next 16-bit word into your buffer" (BLK_XFR)
- **0A:** sync (POLL)
- **0B-0C:** unused / no-op
- **0D-10:** another four D1_SEND header chunks (channel-specific config?)
- **11-13:** unused
- **14:** **FIN** — terminate transfer with d2 + RELEASE (the only
  finalize code)
- **15:** unused
- **16-1F:** sustained streaming — alternating POLL/BLK_XFR (POLL at
  16, 17, 19, 1B; BLK_XFR at 18, 1A, 1C, 1D, 1E; POLL at 1F)
- **22-25:** another stream block (POLL/BLK_XFR pairs at 22/23, 24/25)
- **26-29:** unused / terminator codes

So the chassis essentially feeds the SBC a stream of `d0` codes, and
the SBC reacts at each code: send some header bytes, pull data words,
poll, eventually receive a FIN, releasing.

## Identifying the IRQ handler that supplies `d0`

`d0` is set by some IRQ handler that completes a panel-cmd "bra ."
spin-wait. Searching the ROM for places where `d0` is loaded with a
6-bit value just before an `RTE` would isolate this. Candidate
locations:

- `F00896` — autovec L5/L6 generic dispatcher (visited heavily by
  the running RTOS). Reads `$0C34` bit 14, branches to BSR if set.
- `F00EC8` — autovec L4 (system tick / PTM); unlikely to do panel-cmd
  ack.
- The vectors at `$124-$13C` — most point at `F0A27A` panic, but
  some are populated by the RTOS at task creation time.

Closing this requires tracing what `$0C34` bit 14 means and what
`F0168A` (the BSR target inside F00896) does. F0168A is in the RMS68K
kernel, so it's likely a kernel-level dispatcher that ultimately
calls into one of the 4 handlers above with the response code in d0.

The `$10AA` puzzle (read at F05E12, never written in ROM) probably
gets set by the same path: kernel ISR receives the chassis ack,
extracts the response code, stuffs it into `$10AA` for TCBIO1I to
read, sets `d0` for the dispatch table, advances saved PC, RTEs.

## Implementing the chassis side

For end-to-end S-record reception in the emulator, the chassis state
machine needs to drive these codes in the right sequence. A minimal
implementation that exercises the byte-pull path:

1. SBC writes panel cmd to `$FF000E` and chsel to `$FF0204` (panel
   cmd 0x281 to fetch a host byte)
2. Emulator pulses level-5 IRQ
3. ISR reads response code from chassis (we provide it via an XLTR
   shadow register)
4. For "byte transfer in progress": codes 16-1F alternating POLL/BLK_XFR
5. For "transfer complete": code 0x14 (D2_FIN) → SBC sends RELEASE
6. SBC's `(a2)` buffer fills with received bytes — that's the
   staging area at `$10000-$1FFFF` set by SRecordDataHandler

Without the exact IRQ vector / handler discovered yet, the cleanest
emulator approach is to **install a custom panel-cmd-completion ISR
in the 22 KB of free ROM** (at `F0A825` onwards) and point a chassis
vector at it. The ISR reads the response code from a chassis-side
shadow register (we can use unused XLTR slots), sets d0, modifies
saved PC to `F0572C`, RTEs.
