# How the host PDP-11 talks to the FPS-100

Recovered from MACRO-11 source in `fps100_archive/fps100sw/`:
- `DRIVER.MAC` — the PDP-11 RSX device driver (`APDRV`)
- `HSVC.S` / `HSVCM.S` — host-communication services
- `*HSR.MAC` (AMLHSR / BAAHSR / BABHSR / IPRHSR / SIGHSR / DGNHSR /
  UTLHSR) — Host Service Routines, one per math-library batch

> **Caveat:** the **Bomem-customized** layer (HPVP / IV2DRV / MGDRV /
> BOMRES) was on floppies BOM1–BOM13 which we don't have. But the
> stock FPS-100 layer below it is fully recovered, and Bomem's HPVP
> almost certainly sits on top of it.

## Layer cake

```
  Bomem application (FORTRAN)        ← BOMRES, GRAFIK, etc. (missing)
       │ CALL ZRFFT(...) etc.
       v
  FPS-100 math library (PDP-11)      ← AMLLIB, BAALIB, ... (recovered)
       │ JSR pc, APEX                  (one stub per routine)
       v
  APEX runtime (PDP-11 + FPS-100)    ← APEX.TSK, FAPEX.FTN
       │
       ├── upload microcode + params via QIO IO.WLB to AP:
       │
       v
  RSX device driver  APDRV / DRIVER.MAC
       │ direct UNIBUS register pokes at S.CSR(R4)
       v
  FPS-100 device registers (UNIBUS I/O space)
       │
       v
  AP-120B / FPS-100 hardware (executes microcode)
```

## The wire-level protocol — 6 device registers on the UNIBUS

The FPS-100 occupies 6 UNIBUS device registers at offsets from its
base CSR address (typically `0o172000` or similar; configured per
SYSGEN). Names and offsets are direct quotes from `DRIVER.MAC`:

| Offset (octal) | Name | Direction | Function |
|---|---|---|---|
| `100` | **WC** | host→AP | DMA Word Count |
| `102` | **HMA** | host→AP | Host Memory Address (low 16 bits) |
| `104` | **CTRL** | bidirectional | Control / status; bits below |
| `112` | **FN** | bidirectional | Function register (AP halt / run / state) |
| `114` | **LITES** | bidirectional | AP "lites" + page-select (high address bits) |
| `116` | **RSTAP** | bidirectional | AP Reset + page-select |

### CTRL register bits (from `DRIVER.MAC`)

| Bit | Mask (octal) | Name | Meaning |
|---|---|---|---|
| 0  | `1`     | `HDMAST`  | Host DMA Start (write 1 to launch DMA) |
| 5  | `40`    | `WRTHOST` | Direction: write to host (0 = read from host) |
| 10 | `2000`  | `ICTL05`  | CTL5 interrupt enable |
| 11 | `4000`  | `IHWC`    | DMA-complete interrupt enable |
| 12 | `10000` | `IHALT`   | AP-halt interrupt enable |

### FN register bits

| Bit | Mask (octal) | Name | Meaning |
|---|---|---|---|
| 15 | `100000` | `APHALT` | AP HALT (set = halt, clear = run) |
| 12 | `20000` | (data-valid handshake on CTL5 transfers) |
| 14..12 | `70000` (mask) | `FNCLR` | read-only-bits mask (AND-NOT before write) |

### Event-flag mappings (RSX-11M event flags signalled by ISR)

| EVF (decimal) | Name | When set |
|---|---|---|
| 22 | `RUNEVF` | AP halted itself (microcode `APH;` instruction, IHALT bit) |
| 23 | `DMAEVF` | DMA transfer completed (IHWC bit) |
| 24 | `CT5EVF` | CTL5 user interrupt (microcode INTEN; pulses CTL5) |

## Host-driven command set — what the driver dispatches on

QIO `IO.WLB` (write logical block) function code byte is dispatched to
a 7-entry function table:

| Function code | Action |
|---|---|
| 0 | EXIT (no-op) |
| **1** | **RUNDMA — start a DMA transfer** |
| 2,3,4 | EXIT (reserved / no-op) |
| 5 | SUPER — supervisor init / CTL5 linkage setup |
| 6 | TERM — terminate supervisor (sets APHALT bit) |

So host→AP traffic is essentially **just DMA + supervisor lifecycle**.
The actual AP work is driven by *what's in the DMA'd data* — the AP
loads microcode, parameters, and data via that one DMA path.

## RUNDMA sequence — the heart of host→AP traffic

```mac
RUNDMA: MOV     S.CSR(R4),R3            ; R3 = AP CSR base
        ;                               ; --- only on 11/70 with extended addr ---
        CALL    $STMAP                  ; set up UMRs
        CALL    $MPUBM                  ; load Unibus Map
        ;                               ; --- always ---
        MOV     U.BUF(R5),R0            ; high word of physical buffer addr
        ASL     R0                      ; align high 2 bits
        ASL     R0
        SWAB    R0
        BIC     #37777,R0               ; mask off low 14 bits
        MOV     RSTAP(R3),R1            ; preserve RSTAP page bits
        BIC     #140000,R1
        BIS     R0,R1
        MOV     R1,LITES(R3)            ; high address bits → LITES
        MOV     U.BUF+2(R5),HMA(R3)     ; low 16 bits → HMA
        BIS     #HDMAST,CTRL(R3)        ; ★ start DMA
        BIS     #IHWC,CTRL(R3)          ; ★ enable completion irq
```

So the host:
1. Writes high 2 bits of the 18-bit Unibus address to `LITES`.
2. Writes low 16 bits of address to `HMA`.
3. Sets `HDMAST` bit in `CTRL` — DMA fires immediately (the AP is
   the bus master from this point).
4. Sets `IHWC` bit so the completion will raise an interrupt back.

Word count is implicitly known to the AP from a previous setup step
(presumably the AP's `WC` register was loaded by an earlier
microcode/host exchange — see `APEX.FTN`/SIM100 for the AP-side
counterpart).

## ISR — what the host sees on AP-initiated interrupts

The driver's `$APINT::` interrupt entry distinguishes three sources
based on what's set in `CTRL` and `FN`:

```
  if CTRL.HDMAST==0 and CTRL.IHWC==1:
      → DMA completed → set DMAEVF (#23), call $IODON
  elif FN.APHALT (sign bit) and CTRL.IHALT:
      → AP halted itself → set RUNEVF (#22)
  elif CTRL.ICTL05:
      → CTL5 user interrupt → set CT5EVF (#24); also the FN[12]
        20000 bit acts as a data-valid handshake; LITES carries
        a 3-bit register select + value
  else:
      → noise (spurious); ignore
```

The CT5 path doubles as a **microcode-to-host data channel**: when AP
microcode executes an `INTEN;` instruction (raises CTL5), the FN[12]
flip-flop latches data-valid, and the host reads register-id+value
from `LITES` and copies it into the user's array space (using the
`PUTWRD` routine in the driver — that does `KISAR6` mapping
manipulation to write into the user's address space safely).

## TERM — clean shutdown

```mac
TERM:   CLR     CTRL(R3)        ; disable HALT and CTL5 interrupts
        MOV     FN(R3),R2       ; read FN
        BIC     #FNCLR,R2       ; mask off read-only bits
        BIS     #APHALT,R2      ; set HALT
        MOV     R2,FN(R3)       ; halt the AP
        MOV     #IS.SUC,R0
        CALL    $IODON
```

## Library-call layer — `*HSR.MAC` files

Each math-library routine's host-side wrapper is one of the `*HSR.MAC`
files. Example from `AMLHSR.MAC` (FGEN routine):

```mac
FGEN:   MOV  (%5)+, %0          ; pick up arg count
        BEQ  NONE
        MOV  #SLIST, %1
LOOP:   MOV  @(%5)+, (%1)+      ; copy SPAD args into SLIST table
        DEC  %0
        BNE  LOOP
NONE:   MOV  #PARAM, %5
        JSR  %7, APEX           ; ★ call into the APEX runtime
        RTS  %7
PARAM:  4                       ; arg count for APEX
        CODE                    ; pointer to embedded microcode
        START                   ; start address (0)
        SLIST                   ; SPAD value list
        NSPADS                  ; number of SPADs
NSPADS: 4.
SLIST:  .BLKW 4.
START:  0.
CODE:   442.                    ; microcode entry offset
        001620,000000,002000,000001     ; ← raw AP-120B
        040000,000000,016000,020060     ;   microinstructions,
        030404,000000,000000,000000     ;   4 × 16-bit octal words
        ...                              ;   per 64-bit instruction
```

So **every math-library `.MAC` file in `fps100_archive/fps100sw/`
contains the actual AP-120B microcode binary for that routine**,
embedded as `.WORD` directives. This is the same format we already
decoded for the AP-120B FFT/IFFT identity-test microcode using the
SIM100 `SPLIT` decoder.

That means:

> **We have ~100 production AP-120B microcode kernels, in source
> form, ready to disassemble into APAL with our existing tooling.**

Library routine inventory (per `BAANAM.NAM`, `BABNAM.NAM`, etc.):

| Library | Routines |
|---|---|
| BAALIB | `CVADD`, `CVSUB`, `CVMUL`, `CVMAGS`, `CVMA`, `CDOTPR`, `VCLR`, `VMOV`, `VADD`, `VSUB`, `VMUL`, etc. |
| BABLIB | `VMAX`, `VMIN`, `VFLT`, `VFIX`, `VSCALE`, `VLIM`, `VSMAFX`, etc. |
| AMLLIB | `FGEN`, `EIGRS`, `TRED2`, `IMTQL2`, `SKYSOL`, `SCSFB`, ... |
| SIGLIB | FFT family (presumably) |
| IPRLIB | inner products / matrix products |
| UTLLIB | utilities |
| DGNLIB | diagnostics |

## What's missing — the Bomem layer

The Bomem-specific tasks (HPVP loader, IV2 driver, BOMRES library)
sit ON TOP of the APEX/library stack documented above. From
`LOABOM.CMD` we know the file names exist but they are on floppies
BOM1–BOM13 + TASK + HELP + MENU which we don't have.

Two reasonable inferences about what Bomem added:
1. **HPVP loader** (`loahpvp` per LOABOM.CMD) — initializes the
   FPS-100 with Bomem-specific microcode (probably FFT + apodization
   + interferogram-processing kernels). Same APEX upload mechanism;
   different microcode payloads.
2. **IV2DRV / MGDRV2** — A/D and motor/galvo drivers for the DA3
   spectrometer hardware. These are *separate* from the FPS-100;
   they handle the front-end optics control and digitization. Not
   FPS-related.

The HPVP-relevant layer is therefore just "more APEX kernels", in
the same source-file format as the BAA/BAB/SIG/IPR libraries we
have, just with FFT/spectrometry-specific algorithms. If those
floppies surface, plugging them in is mostly mechanical.

## Summary — answering the original question

**How do the Bomem/HPVP executables talk to the FPS-100?**

1. They make Fortran `CALL` to a math-library routine (e.g. `ZRFFT`,
   or a Bomem-specific HPVP wrapper).
2. The wrapper is a small PDP-11 stub in a `.MAC` file (`*HSR`-style)
   that copies args into a fixed-format parameter block and calls
   `APEX` via `JSR PC, APEX`.
3. `APEX` issues an RSX `QIO IO.WLB` to the device "AP:" — function
   code 1 (RUNDMA) — passing the parameter block + microcode +
   data buffer addresses.
4. The RSX device driver `APDRV` ($APTBL) dispatches to RUNDMA, which
   pokes 6 UNIBUS registers (LITES + HMA address, CTRL.HDMAST start,
   CTRL.IHWC enable) to launch the DMA and arm the completion irq.
5. The FPS-100 hardware DMAs the microcode + params + data out of host
   memory, runs the microcode (executing `INTEN;` to send results
   back via CTL5, or just halting via `APH;` when done).
6. The host gets either a DMA-complete interrupt (`DMAEVF=23`), a
   run-complete interrupt (`RUNEVF=22`), or per-word CT5 interrupts
   (`CT5EVF=24`) carrying inline microcode-to-host data.
7. The wrapper returns to the Fortran caller with results in the
   user's output array.

The whole thing is **6 device registers + 3 event flags**, plus a
microcode upload-and-execute mechanism that's just DMA. Bomem's HPVP
is the same machinery with different microcode payloads.
