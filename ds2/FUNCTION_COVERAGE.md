# FPS-3000 ROM — Function Coverage Table

Combines FIRMWARE_GAPS.md's function inventory with emulator execution
data and static disassembly status. Coverage % is fraction of function
body instructions actually executed in a full boot + host transfer run.

"Decoded" = static disassembly meaningful. "Executed" = PC reached in emulator.
"Unknown" = body not traced through due to unreached code paths.

---

## Application Code Region ($F04488-$F0A57E, ~24 KB)

| Address | Size | Function | Decoded? | Executed? | Coverage | Notes |
|---|---|---|---|---|---|
| F04488 | ~600B | `task__init_misc` | Partial | Partial | ~15% | Pre-TDTI task bootstrap. Static init only; runtime paths unreached. |
| F046E0 | 16B | `ChannelConfigOffsetTable` | Yes (DATA) | N/A | — | 4 longwords: $244,$246,$250,$252 = BIM control registers XP1I..XP4I. |
| F046F0 | ~2722B | **TCBRDHC** | Partial | Partial | **8%** | Master/dispatch task. SLC parser, panel cmd dispatch, S-record handler. 8% executed = prologue + startup handshake only; main loop body waits on chassis events. |
| F051A2 | ~180B | `SRecordDataHandler` | Yes | No | 0% | Validates $10000-$1FFFF address range, hex→binary. Never called without a host transfer. |
| F05256 | ~1074B | `SRecordFinalize_andHelpers` | Partial | No | 0% | Posts microcode to XP-32 via panel commands. Only reached after full S-record receive. |
| F05688 | ~50B | `PanelIOConfigure_25A` | Yes | Yes | 100% | One of 8 identical copies. Writes panel cmd to $FF000E, sends 0x8004. |
| F056BA | ~1258B | `PanelSendAndWait_andDispatch` | Partial | Minimal | ~5% | Polls $FF0000 bit 14, dispatches via PanelStatusDispatchTable. Most handlers unreached. |
| F05BA4 | 168B | `PanelStatusDispatchTable` | Yes (DATA) | N/A | — | 42 entries × 4B. Fully decoded as data; per-code mapping unknown. |
| F05C4C | ~180B | `PanelErrorMaskTable` | Yes (DATA) | No | — | 5-entry error→bit mapping. Untraced. |
| F05D00 | ~512B | **TCBIO1I** | Partial | Partial | **30%** | Host I/O channel. Prologue + ISR entry; byte-path arms unreached without chassis model. |
| F05F00 | ~2580B | **TCBXP4I** | Partial | Minimal | **4%** | XP-32 channel 4 controller. Blocks on `trap #1 $13` after ~45 instructions. |
| F06914 | ~5100B | **TCBXP3I/XP2I** | Partial | Minimal | **4%** | Shared channel 2+3 implementation. Same 45-instruction block. Per-channel divergence unknown. |
| F07D00 | ~2560B | **TCBXP1I** | Partial | Minimal | **6%** | XP-32 channel 1 controller. Slightly more executes (ISR entry is in this region). |
| | | **Panel-cmd issuer copies (×7)** | Yes | Partial | — | F04500, F05688, F05E56, F068A8, F072C0, F07CC0, F086C0. 48B each, all identical. |
| | | **$F0A57E copy (#8)** | Yes | Unknown | — | The 8th identical copy, inside TCB definition table region. |

## Self-Test / Boot Region ($F08700-$F09BFF, ~5.4 KB)

| Address | Size | Function | Decoded? | Executed? | Coverage | Notes |
|---|---|---|---|---|---|
| F08700 | ~512B | `MainInit` | Yes | Yes | 100% | Boot orchestrator: 13 confirmed self-test phases, RAM init. Fully exercised every boot. |
| F08902 | ~25B | `BusAddressErrorHandler` | Yes | Conditional | — | 68000 bus/address error handler. Runs only on BERR phases (0x1700/0x1A00). |
| F0891C | ~320B | `PollBoardStatus` | Yes | Yes | 100% | Reads $F70019, validates bit 4 during handshake waits. |
| F08A5C | ~770B | `HardwareInit` | Partial | Yes | ~70% | DUART, DPRAM, memory test phases. Most phases reachable; some gated on checkpoints. |
| F08D5E | ~140B | `RAMAddressingTest` | Yes | Yes | 100% | Write/read pattern over 0-128KB. |
| F08DF8 | ~174B | `BoardStatusPoll_3F11` | Yes | Yes | 100% | Polls $F70018, masks $3F31, compares $3F11. NOT a ROM checksum. |
| F08EAC | ~198B | `MemBusProbe` | Partial | Yes | ~50% | BERR-walk through chassis address space (chsel 0x700, 0x1000). |
| F08F72 | ~516B | `IOChannelDiagnostic` | Partial | Yes | ~60% | Test chassis/XLTR handshake (phase 0x800). |
| F09176 | ~38B | `PTMInit` | Yes | Yes | 100% | MC6840 PTM timeout configuration. |
| F0919C | ~1876B | `PanelBusDiagnostic` | Partial | Yes | ~70% | Panel-bus interrupter test (phases 0x1100-0x1A00). Largest single test, well-modeled. |
| F098EE | ~792B | `ROMChecksum_etc` | Unknown | Conditional | ? | Secondary checksum + Phase2Init. Executes only after self-test passes. |

## RTOS / Kernel Region ($F09C00-$F0A57E, ~2.6 KB)

| Address | Size | Function | Decoded? | Executed? | Coverage | Notes |
|---|---|---|---|---|---|
| F09C00 | ~648B | `Phase2Init_VCTscan` | Partial | Yes | ~50% | !VCT scan, expansion card enumeration. Runs at end of boot. |
| F09E88 | ~454B | `Init_RMS68K_StoreTags` | Yes | Yes | 100% | !GST/!UST/!IOV/!IDV/!PAT/!UDR tag init. |
| F0A04E | ~1328B | `RTOSKernelInit` | Yes | Yes | ~80% | TDTI task creation, RMS68K startup. Creates all 6 tasks; some paths use RMS68K kernel code not in this region. |

## Data Tables ($F0A57E-$F0A5FE + $F0A600-$F10000)

| Address | Size | Content | Decoded? | Notes |
|---|---|---|---|---|
| F0A57E | ~128B | Panel-cmd issuer copy #8 | Yes | 8th identical 48B copy + padding. The `jsr` target for TCBRDHC. |
| F0A600 | ~2816B | **TCBDefinitionTable** | Partial | 6 TCB entries × ~330B. Contains task priorities, entry points, ASQ names, initial SP. Not extracted field-by-field. |
| F0A600+6 | 6×8B | Task name table | Yes (DATA) | "XP1I", "XP2I", "XP3I", "XP4I", "USER", "USER". Used by directive $12. |
| F0B17E | ~20162B | Trailing tables + padding | No | Filler/table region to ROM end at $F10000. Contains exception-code table at F0A23A (9 entries × 4B). |

## RMS68K Kernel ($F00000-$F04487)

The RMS68K kernel (17.4 KB) is generic Motorola RTOS code. It is the
same kernel found at `~/src/claude/versados/rms68k_disasm.SA`. Not
FPS-3000-specific, so not analyzed per-function here. Coverage: ~41%
executed (primarily init paths + scheduler + syscall dispatch).

---

## Coverage Summary

| Region | Size | Coverage | What's holding it back |
|---|---|---|---|
| RMS68K kernel | 17.4 KB | 41% | Most syscalls unreached; scheduler idle only |
| Self-test | 5.4 KB | 52% | Some phases gated on checkpoints; 13 confirmed phases (0x700-0x1A00) |
| RTOS init | 2.6 KB | ~70% | VCT scan incomplete; some Phase2Init paths conditional |
| TCBRDHC | 2.7 KB | **8%** | Main loop waits on chassis events ($E86 panel response dispatch) |
| TCBIO1I | 0.5 KB | 30% | Host-byte path deadlocked at level 7; $10AA dispatch + reply arm unreached |
| TCBXP1I | 2.6 KB | 6% | Blocks on `trap #1 $13` waiting for chassis BIM interrupt |
| TCBXP2I/XP3I | 5.1 KB | 4% | Same block; shared code body unreached |
| TCBXP4I | 2.6 KB | 4% | Same block |
| Data tables | 22.8 KB | ~10% | Only dispatch/offset tables decoded; TCB fields unextracted |

**Overall FPS application code: 19% executed across all runs.**
