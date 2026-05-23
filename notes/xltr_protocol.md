# FPS-3000 SBC ⇄ XLTR Command Protocol

Reverse-engineered from `fps3k_custom.asm` (the disassembled ROM at
`F04488–F0FFFF`). This documents the byte-level handshake the SBC uses
to drive the XLTR card across VersaBUS — i.e., one side of the
conversation with the XP32 EU.

## Hardware register map (XLTR / AP I/F at `0xFF0xxx`)

Confirmed by tracing every store to the `0xFF0000+` range:

| Address | Reg | Use observed | Code refs |
|---|---|---|---|
| `0xFF0000` | **AP I/F command/status (16-bit)** | Receives panel-command opcodes (`#$8004`, `#$8005`, etc.); read for status (bits 13–14 = ready/error) | `F056CA`, `F05742`, `F056D6` |
| `0xFF000E` | per-channel command-arg register | Echoes the `d0` parameter (channel/sub-cmd) | `F05694` |
| `0xFF0200` | **XLTR Mode 0 register** | bit 10 manipulated during configure | `F056A8`–`F056B0` |
| `0xFF0202` | **XLTR Mode 1 register** | bit 12 set, bit 14 cleared during configure | `F05698`–`F056A4` |
| `0xFF0204` | **Channel Select register** | written with channel ID | `F056B4` |
| `0xFF020C` | counter / config | written `0x01`, `0xFF` (init sequence) | (per CLAUDE.md) |
| `0xFF0210` | XLTR Mode 2 register | cleared during channel setup | (per CLAUDE.md) |
| `0xFF0214` | **Data register low half** | command argument lo word | `F05738`, `F056C0` |
| `0xFF0216` | **Data register high half** / Cmd | command argument hi word; single-bit cmds 0x10/0x20/0x40/0x80 | `F0573E`, `F056C6` |
| `0xFF0218` | **Status / IRQ register** | bit 15 = ready/done; arm by writing `0x400` | (per ROM init) |
| `0xFF021A` | **IRQ Mask register** | written `0xFFF` at init; bits cleared on per-error path via lookup table at `F05C4C` | `F0570E`, `F05722` |

Per-channel data registers (4 channels = TCBXP1I..TCBXP4I) are at
`0xFF0048/4E`, `0xFF0068/6E`, `0xFF0088/8E`, `0xFF00A8/AE`, with
config at `0xFF0244/46/50/52`.

## Bus-side command opcodes

Three short opcodes drive the AP I/F:

| Opcode (16-bit) | Name (inferred) | Used by |
|---|---|---|
| `0x8004` | **REQUEST-TRANSFER** — initiate a panel-command exchange | `F056CA` (every command) |
| `0x8005` | **CONTINUE-TRANSFER** — second half / 32-bit-data follow-up | `F05742` (after 32-bit data load) |
| (status read) | poll `(a0)` → check bits 13–14 | every poll loop |

After issuing the opcode the SBC polls `(a0)` with a 1000-iteration
timeout (`#$3E8`), checking:
- bit 14 set → transfer complete (good)
- bit 13 set → error path
- timeout → also error path (issue `0x26C` "abort/recovery")

## Channel-config opcodes (`PanelIOConfigure_25A` parameter codes)

`PanelIOConfigure_25A` (at `F05688`) takes a 16-bit code in `d0` and
performs:

```
save d0 → global at 0x000E6E
a0 = 0xFF0000
[FF000E] = d0
[FF0202] = (current & ~0x4000) | 0x1000      ; Mode 1: clear bit 14, set bit 12
[FF0200] = current & ~0x0400                  ; Mode 0: clear bit 10
[FF0204] = d0                                 ; Channel Select = d0
return
```

Codes observed (from 21 distinct `move.w #$xxxx, d0` callsites):

| Code | Count | Inferred meaning (from caller context) |
|---|---:|---|
| `0x25C` | 5 | "Common reset / status-clear" — most-used recovery code |
| `0x26C` | 9 | **"ABORT / RELEASE"** — issued in poll-error and on timeout. Most frequent. |
| `0x26A` | 4 | (recovery variant) |
| `0x25A` | 3 | (channel ack) |
| `0x269` | 1 | **"ERROR-PATH ABORT"** — issued only when bit-13 set (true error) |
| `0x26B` | 2 | (alternate error abort) |
| `0x260`, `0x25F`, `0x25D`, `0x259` | 2 each | per-channel-state codes |
| `0x258`, `0x25B`, `0x25E` | 1 each | per-channel-state codes |
| `0x276`–`0x27D`, `0x269` | sequential init sequence | called from `TCBRDHC` boot/init |

The `0x276..0x27D` block being sequential (0x276, 0x277, 0x278, 0x279,
0x27A, 0x27B, _, 0x27D) and being called once each at adjacent
addresses in the dispatcher suggests this is the **per-channel
power-on reset / channel-init sequence**: 8 distinct sub-commands
issued in order to bring each XP32 channel out of reset.

## Canonical "send command + wait" sequence (at `F056BA`)

This is the inner kernel that issues a panel command and blocks until
done:

```asm
F056BA  move.w  #$4F,    (a3)        ; status flag := BUSY (0x4F)
F056BE  move.w  d4,      -(a7)       ; save d4
F056C0  move.w  #$0,     (a1)        ; data low := 0
F056C4  move.w  d0,      d7          ; remember command code
F056C6  move.w  d0,      $2(a1)      ; data high := command
F056CA  move.w  #$8004,  (a0)        ; AP I/F command := REQUEST-TRANSFER
F056CE  move.l  #$3E8,   d5          ; d5 := 1000 (timeout)

F056D4  poll:                         ; ── wait for completion ──
            d5 -= 1
            d4 := (a0)                 ; read status
            if d4 bit 14 set → exit-poll
            if d5 != 0     → poll
        end-poll

F056E6  if d4 bit 13 NOT set AND d5 != 0:
            issue PanelIOConfigure_25A(0x26C)   ; ABORT/RELEASE
F056FE  if d4 bit 13 set:                       ; error path
            issue PanelIOConfigure_25A(0x269)   ; ERROR-ABORT
            d0 := [FF021A]                       ; read IRQ mask
            d4 := stack
            d5 := lookup table[F05C4C][d4.w]
            d0 := d0 & ~(1 << d5)                ; clear corresponding mask bit
            [FF021A] := d0
            (a3) := 0x5F                         ; status := IDLE
            RTS
F0572C  else (success):
            jump-table dispatch via [F05BA4][d0*4]
            (per-cmd handler — e.g. F05738 = 32-bit data path)
```

## 32-bit data extension (at `F05738`, after success-dispatch)

For commands that carry a 32-bit datum (DMA address, count, register
value), the protocol extends:

```asm
F05738  swap    d2                    ; rotate to high half
F0573A  move.w  d2,      (a1)         ; data low (was high) := lo16
F0573C  swap    d2                    ; restore
F0573E  move.w  d2,      $2(a1)       ; data high := hi16
F05742  move.w  #$8005,  (a0)         ; AP I/F command := CONTINUE-TRANSFER
F05746  move.l  #$3E8,   d5           ; another 1000-tick timeout
        ... poll same as above (F0574C onwards) ...
```

So a 32-bit transfer is **two 16-bit transactions**: first half via
`#$8004` opcode, second half via `#$8005`.

## High-level XPMLIB API → byte sequence

Mapping the published FPS-5000 software API (Hockney p.241-242,
Curington 1984) onto the byte-level operations:

| API call | Bytes the SBC sends |
|---|---|
| `XPSEL` (select XP32 channel) | `[FF0204] = ch` (PanelIOConfigure_25A with channel-id 0..3) |
| `XPRUN` (start AC) | configure-channel + `(a0) = 0x8004` with command-code "RUN" + poll |
| `XPWAIT` | poll `(a0)` until bit 14 set, then check bit 13 |
| `XPSTAT` | "read device status" panel command — `(a0) = 0x8004` with status-read code, read result from `(a1)` |
| `XPDMAR` (SCM↔LMD DMA) | sequence: select-channel → set-address (32-bit, via `0x8004`+`0x8005`) → set-count (32-bit) → set-mode → arm DMA + clear-busy |
| `XTMDMA` | same primitive, different target memory selector |
| `XPISNC` | poll `(a0)` for ready (= XPWAIT bit-15 spec) |

The exact sub-command code per high-level call lives in the `0x258..0x27D`
range — different XPMLIB primitives map to different `d0` values fed
to `PanelIOConfigure_25A`. The full mapping requires walking each of
the 21 callsites in the disassembly and identifying which TCB function
is invoking it.

## Per-channel hot-path

The `TCBXP1I..TCBXP4I` channel-state-machine tasks each cycle through:

1. Wait for ASQ message (host-side I/O request from `TCBRDHC`)
2. `PanelIOConfigure_25A(channel_id)` — `XPSEL` equivalent
3. For each operation the host requests:
   - Issue panel command via `F056BA` ("send + wait")
   - On error → cleanup via `0x26C` recovery sequence
4. Acknowledge ASQ, loop

The specific channel IDs (0x258..0x25F, 0x260..0x267, 0x268..0x26F,
0x270..0x277) cluster suggests **8 sub-commands per channel × 4
channels = 32 codes**, of which ~20 are observed in this firmware
(unused: read/write of certain registers, debug/scan ops, etc.).

## What this enables

With this protocol now documented byte-for-byte:

1. **Hardware bring-up without microcode** — even if the WCS is empty,
   the SBC's basic command sequence to the XLTR can be observed and
   verified on a logic analyzer. If the XLTR responds correctly to
   `0x8004`/`0x8005` opcodes, the bus path is alive.
2. **XLTR-side ABI target** — whatever firmware (or pure logic) lives
   on the XLTR card (612-4803) must respond to exactly the command set
   documented here. The codes `0x258..0x27D` constitute the XLTR's
   public ABI as seen from the SBC. Note: the actual XP32 EXEC sequencer
   (Am29116 + SRAM control store) sits *behind* the XLTR; the SBC
   doesn't talk to it directly. The XLTR is the bridge.
3. **Microcode-loader ground truth** — the SRecordDataHandler at
   `F051A2` shovels bytes into `0x10000–0x1FFFF` SBC RAM, then this
   panel-command sequence ships them across the XLTR to the XP32 AU
   control store. The panel-command codes for "WCS WRITE" must be
   among the `0x258..0x27D` codes, identifiable by tracing which one is
   invoked from the SRecord finalize path at `F05256`. Per Hockney
   fig 2.53 (and the user's confirmation that PROMs *are* present on
   the EXEC card), the **EU runs from a fixed 2K × 80-bit mask PROM**
   on the EXEC card and is alive at power-on; only the **AU writable
   control store (4K × 128-bit, 4 banks)** is host-uploaded. The
   64 KB SBC staging buffer = exactly one AU bank.
4. **A working test sequence** — issue a single
   `PanelIOConfigure_25A(0x276)` manually (the start of the init
   sequence) and expect bit-14 of `[FF0000]` to go high within 1000
   cycles. If it does, the XLTR card (and whatever fixed logic it
   contains, e.g. PALs) is responsive. This test only validates the
   bus path and the XLTR's local state machine — it does **not**
   require the XP32 EXEC/ARITH cards to have microcode loaded.

## Open items

- **Exact mapping of `0x276..0x27D` to specific bring-up steps** —
  requires reading the corresponding caller blocks at F046FA, F0471A,
  etc. Each is a self-contained sub-procedure ~20 instructions long.
  Quick to do; just deferred for length.
- **`0x4F` and `0x5F` on (a3)** — what address `(a3)` resolves to. It's
  set up by the caller (likely a per-task control word in TCB area
  0x800-0xC00). The values 0x4F/0x5F are status flags for the SCHEDULER,
  not for the XLTR.
- **The dispatch table at `F05BA4`** — 256 4-byte entries indexed by
  `d0` (status code from `(a0)` read). This is the per-status-code
  handler dispatcher; walking it would enumerate every distinct error
  / continuation case the SBC handles.
- **The error-mask table at `F05C4C`** — used to clear specific
  IRQ-mask bits per error code. 16-byte lookup table.
