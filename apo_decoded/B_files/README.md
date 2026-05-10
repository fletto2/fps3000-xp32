# FPS-100 AP-side supervisor microcode (decoded)

The `.B` files in the FPS-100 archive are **APAL binary objects in
the same `***CODE`-block format as `.APO` files**, decodable with
the same `apo_decode.py`. While the `.APO` files contain the math
libraries (host-callable from FORTRAN), the `.B` files contain the
**code that runs on the AP itself** — the Super-100 / Mini-100
embedded supervisor and its supporting subsystems.

This directory has 34 decoded files: 1,971 microinstructions across
69 AP-side routines.

## What's in the AP-side supervisor

| File | Routines | Microinstr | Purpose |
|---|---:|---:|---|
| `KERNEL.dis` | 15 | 283 | AP-side task scheduler (EXTASK = Execute Task module, plus context save/restore) |
| `IOQUE.dis` | 4 | 43 | I/O queue manager |
| `HIRP.dis` | 1 | 43 | Host-Initiated Routines Procedure (the AP-side endpoint of HIRP RPC) |
| `HIRPM.dis` | 1 | 13 | HIRP Macros |
| `HSVC.dis` | 1 | 65 | Host-SerVice routines (AP-side handlers for host-issued requests) |
| `HSVCM.dis` | 1 | 64 | HSVC Macros |
| `BOOTMN.dis` | 1 | 16 | Boot loader for **Mini-100** mode |
| `BOOTSP.dis` | 1 | 16 | Boot loader for **Super-100** mode |
| `MINI.dis` | 9 | 318 | Mini-100 supervisor body |
| `SYSSVC.dis` | 10 | 527 | System service routines (AP-side syscall handlers) |
| `RTC.dis` | 3 | 129 | Real-Time Clock support |
| `RTCISR.dis` | 1 | 48 | RTC Interrupt Service Routine |
| `RTCREQ.dis` | 1 | 51 | RTC request handler |
| `RTCTST.dis` | 1 | 20 | RTC test |
| `RTCDUM.dis` | 0 | 0 | RTC dummy stub |
| `NORTC.dis` | 2 | 2 | No-RTC (system without RTC) |
| `ECHO.dis` | 1 | 14 | Echo test |
| `ENABLE.dis` | 1 | 20 | Enable interrupts |
| `FUNC.dis` | 1 | 85 | Function dispatch |
| `UPEX.dis` | 1 | 15 | User-Process EXecutive (AP-side) |
| `UPEXM.dis` | 1 | 1 | UPEX Macros |
| `SHOOT.dis` `SHOOTM.dis` | 1+1 | 10+10 | "Shoot" test (likely test program for AP execution paths) |
| `SUB1` `SUB2` `SUBR1`-`SUBR4.dis` | 1 each | 4-47 | Test subroutines |
| `TASK51` `TASK52` `TASK53.dis` | 1 each | 11 | Test tasks (used by RUN5/RUN5X) |
| `TEST2.dis` | 1 | 14 | Test 2 |
| `TABLES.dis` | 0 | 0 | Symbol/data tables only |
| **Total** | **69** | **1,971** | |

## Architectural significance

These are the **AP-side counterparts** to the host-side code in the
parent `apo_decoded/` directory. The math libraries call the
host-side APEX (`DAPEX.MAC`) → APDRV → AP hardware. When the FPS-100
runs in Super-100 / Mini-100 mode, it executes these `.B`-format
programs *on the AP itself* — the AP becomes a complete executive
processor with its own task scheduler, I/O queue, and interrupt
handling.

The two-mode architecture:

```
       AP120 mode                      Super-100 / Mini-100 mode
       ──────────                      ─────────────────────────
   Host fully drives AP            FPS-100 runs its own OS
   via APDRV/QIO                   on the AP
                                    │
   Each program loaded fully        Programs queued via IOQUE,
   before run                       scheduled by KERNEL/EXTASK,
                                    serviced by HSVC/SYSSVC
   Single-program, batch            Multi-task, RTC-aware
```

The host-side APEX library still exists in Super-100 mode but the
calling pattern shifts: instead of "load this whole program", the
host sends "run this routine" requests via the HIRP/HSVC channels,
and the AP-side supervisor schedules and executes them.

## Combined preservation totals

This makes the FPS-100/AP-120B preservation total:

| Source | Routines | Microinstructions |
|---|---:|---:|
| Math libraries (`*.APO`) | 313 | 11,469 |
| AP-side supervisor (`*.B`) | 69 | 1,971 |
| **Grand total** | **382** | **13,440** |

13,440 microinstructions × 8 bytes = **107,520 bytes of decoded
AP-120B production microcode**, preserved as APAL-style listings
with octal addresses and hex bytes. This is roughly 59× the previous
publicly-recovered AP-120B microcode corpus (227 instructions in
`ap120b_ffttest_ucode.bin`).
