# Emulator Environment Variable Hook Inventory

Every `getenv("FPS3K_*")` call in the emulator. Each papers over a
hardware gap — the env var injects a value the real chassis would supply
or controls a model behavior that diverges from real hardware.

Source files scanned: `versabus.c`, `fps3k_sbc.c`, `host_sim.c`.
55 total getenv() calls across 24 distinct env vars.

---

## Bus / Memory Injection Hooks

### FPS3K_DMA10AA
| File | fps3k_sbc.c:122-141; gate reference at versabus.c:782 |
| Value | hex longword |
| Default | 0 (inactive) |
| What it papers over | The chassis writing $10AA as a VersaBUS bus master. TCBIO1I's ISR reads this at F05E12 to dispatch the reply arm ($10AA=2 → $F05E40 writes reply to $700020). No executed ROM code writes a nonzero value here. |
| Gate | Boot-complete: vector $128 must hold F05DD6 before injection activates (or FPS3K_DMA10AA_FROM_RESET=1 to bypass the gate, but this hangs power-on diagnostics). |

### FPS3K_DMA10AA_FROM_RESET
| File | fps3k_sbc.c:128 |
| Value | any nonempty |
| Default | off |
| What it papers over | Boot-complete gate on $10AA injection. Without it the injection only starts after TCBIO1I is running (preventing a diagnostic hang). Setting it restores pre-fix behaviour for checking old results. |

### FPS3K_POKE
| File | fps3k_sbc.c:99-113 |
| Value | "addr=word,addr=word,..." (hex) |
| Default | none |
| What it papers over | Any RAM location the chassis supplies but the ROM never writes. Used for $105E (channel count) and $10AA before FPS3K_DMA10AA existed. Multiple locations can be poked in one key. |

### FPS3K_RAMWATCH
| File | fps3k_sbc.c:285-291 |
| Value | hex address |
| Default | none |
| What it papers over | Nothing — diagnostic tool. Logs every CPU write to the named longword, verifying that a value the CPU never produces is indeed chassis-DMA'd. |

### FPS3K_VECWATCH
| File | fps3k_sbc.c:267-276 |
| Value | "" or "post" |
| Default | off |
| What it papers over | Nothing — diagnostic. Reports writes to the exception vector table. "post" reports only writes after TCBIO1I's vector ($128) is installed, so init-time vector programming is silent. |

### FPS3K_UNINIT
| File | fps3k_sbc.c:567 |
| Value | filename |
| Default | none |
| What it papers over | Nothing — diagnostic. Dumps every read of a RAM byte the CPU has never written (uninitialized-DRAM-read detector). Over a full stock-boot run: zero reports — the firmware never reads uninitialized RAM. |

---

## XLTR / AP I/F / Chassis State Hooks

### FPS3K_CHANNELS
| File | versabus.c:389 |
| Value | integer (0-4) |
| Default | 0 |
| What it papers over | The chassis's physical XP-32 channel population. The firmware counts nonzero command ports at F0A202 and gates each XP task on the count ($105E). With CHANNELS=0, all four XP tasks skip their work entirely. The documented chassis has AC1+AC2 → set to 2 for realistic behavior. |

### FPS3K_CHCMD
| File | versabus.c:398 |
| Value | hex word |
| Default | 0x0001 |
| What it papers over | What a populated channel's command port ($FF004E/$006E/$008E/$00AE) returns. The presence probe only tests nonzero, but the XP task body gates on bit 11 of this value (btst #$B at F07EB6). |

### FPS3K_CHSEL_RD
| File | versabus.c:527 |
| Value | hex word |
| Default | none (returns last write) |
| What it papers over | The chassis modifying XLTR_CHANNEL_SELECT between SBC writes. The bulk-transfer loop at F04AE2 gates on reading $28 from this register — the chassis signals "transfer pending" by changing the readback value. Without it, bulk transfers never start. |

### FPS3K_RESP
| File | versabus.c:750 |
| Value | hex byte |
| Default | 0x14 (D2_FIN) |
| What it papers over | The actual panel status response code the chassis returns in MODE0 bits 0-4. Overrides the default D2_FIN so the 0..$14 code space can be swept experimentally. The chassis's real response codes per panel command are unknown. |

### FPS3K_RESP_INSVC
| File | versabus.c:1301 |
| Value | any nonempty |
| Default | off |
| What it papers over | BIM interrupt routing. When set, panel responses are delivered to the BIM channel of the ISR that issued the command (tracked in bim_in_service_*), instead of the default BIM0 ch0. Tests whether a spinning level-7 channel ISR can be rescued. |

### FPS3K_SEQ
| File | versabus.c:1235 |
| Value | "code:chsel,code:chsel,..." (hex) |
| Default | none |
| What it papers over | The chassis command language. Scripts a sequence of (response code, CHANNEL_SELECT readback) pairs the chassis delivers. Verified the staging path with "01:0000,41:0001,02:0008,42:0000,00:0028". The chassis would naturally produce these codes in response to the SBC's panel commands; here they're scripted externally. |

### FPS3K_SEQGAP
| File | versabus.c:87 |
| Value | decimal cycles |
| Default | 20,000,000 |
| What it papers over | Timing between scripted chassis commands. The space between commands must be long enough for the SBC to finish processing the previous one. |

### FPS3K_INJECT
| File | versabus.c:1391 |
| Value | hex byte (0x00-0x14) |
| Default | none (inactive) |
| What it papers over | Direct injection of one panel-status response on BIM0 ch0 once the machine is idle. Sweeps the 0..$14 response code space to observe the dispatch at F04930 without going through the panel command protocol. |

### FPS3K_DATAIN
| File | versabus.c:406 |
| Value | any nonempty |
| Default | off |
| What it papers over | The bulk data-in port at $FF0008 source. When set, returns an incrementing pattern starting at 0x1000 so the destination decode (transfer to $10000-$1FFFF) can be verified against a RAM dump. |

### FPS3K_SREC
| File | versabus.c:428-440 |
| Value | filename |
| Default | none |
| What it papers over | The bulk data-in port source, S-record mode. Feeds an S-record text file through $FF0008 as two ASCII characters per 16-bit word, which the S-record front-end at F04B22 reads. Sets bit 0 of $FF0004 as "data available" flag. |

### FPS3K_MBOX
| File | versabus.c:278,802 |
| Value | hex longword (32-bit) |
| Default | none |
| What it papers over | The host mailbox word at $70001C. Sets both bit 29 (host-needs-attention, selects the TCBIO1I ISR's receive arm at F05DFA) and bits 16-17 (class field; class=1 → reply arm at F05E40). The real mailbox is written by the host over VersaBUS. |

### FPS3K_BSTAT19_B5
| File | versabus.c:1027 |
| Value | 0 or 1 |
| Default | derived (vmod_d0_writes >= 2 && !vmod_d0_ack) |
| What it papers over | The chassis's checkpoint-handshake indication on bit 5 of $F70019. The derived formula tracks $D0 marker writes to $1FFF1 and latches bit 5 after two of them. Without this, the self-test suite either never runs (bit 5 set from reset → F08732 skips it) or runs forever (bit 5 never sets → F088EE never advances to Phase2Init). |

### FPS3K_BSTAT19
| File | versabus.c:933 (documented but unused) |
| What it papers over | Documented as an old forced-override for $F70019 byte. The comment says it "breaks the dynamic bit relationships" and "makes self-tests fail for the wrong reason." FPS3K_BSTAT19_B5 with a clearing mask is preferred. |

---

## Interrupt / IRQ Hooks

### FPS3K_HOSTLVL
| File | versabus.c:609 |
| Value | decimal IRQ level (1-7) |
| Default | none (reads from BIM CR) |
| What it papers over | The host BIM channel's IRQ request level. The firmware programs BIM2 ch2 at level 7 ($5F), but if the board's IRQ-pin wiring routes the host interrupt at a lower level, this overrides. The level-6 panel responder F04930 can only preempt the host ISR if the host's level is < 6. |

### FPS3K_XPIRQ
| File | versabus.c:1337 |
| Value | comma-separated channel numbers (1-6) |
| Default | 0 (inactive) |
| What it papers over | Raising channel BIM interrupts. Channel-to-BIM mapping: 1=XP1I (BIM1 ch2), 2=XP2I (BIM1 ch3), 3=XP3I (BIM2 ch0), 4=XP4I (BIM2 ch1), 5=TCBIO1I (BIM2 ch2), 6=BIM0 ch0 (panel responder). Each channel gets its interrupt raised periodically once enabled, so the ISR bodies execute past their prologues. |

---

## Diagnostic / Logging Hooks

### FPS3K_BUSPC
| File | versabus.c:203 |
| Value | any nonempty |
| Default | off |
| What it papers over | Nothing — diagnostic. Appends the program counter to every bus access log line, so the code that performed the access is identified. |

### FPS3K_PCLOG
| File | fps3k_sbc.c:171,352 |
| Value | any nonempty |
| Default | off |
| What it papers over | Nothing — diagnostic. Logs every AP I/F read to stderr with PC, for correlating register accesses to specific instructions. |

### FPS3K_LOGCHASSIS
| File | fps3k_sbc.c:196,312 |
| Value | any nonempty |
| Default | off |
| What it papers over | Nothing — diagnostic. Logs reads and writes to the chassis memory window at $400000-$4FFFFF. A full boot emits ~262k lines, so it's off by default. |

### FPS3K_REGLOG
| File | fps3k_sbc.c:489 |
| Value | hex address |
| Default | none |
| What it papers over | Nothing — diagnostic. At every instruction, if PC matches the given address, logs A1/D2/D4/D5 register values to stderr. Used to trace argument values at specific code sites. |
