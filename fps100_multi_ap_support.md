# Does HPVP / DRIVER.MAC support uploading microcode/commands to a *slave* FPS-100?

**Short answer**: the FPS-100 PDP-11 driver supports **multiple
FPS-100 / AP-120B units attached to the same host as peers**, but
there is **no master-slave architecture and no inter-AP communication
path** in the public software stack.

A host task can hold open LUNs to two physical FPS-100s at once and
upload microcode + drive each independently — but they don't talk to
each other. Anything that looks like "AP A loads microcode into AP B"
has to go via the host RAM.

The Bomem-customized HPVP layer is **not visible in the recovered
dataset** (the BOM* application disks where it lived are missing),
so any HPVP-specific extensions to multi-AP behaviour can't be
confirmed or ruled out from what we have.

## Evidence — DRIVER.MAC / DAPEX.MAC

`fps100_archive/fps100sw/[327,010]DRIVER.MAC` (PDP-11 RSX-11M v3.2
device driver, rel B.1, Jan 1980) and
`fps100_archive/fps100sw/[327,010]DAPEX.MAC` (the host-dependent APEX,
PDP-11 RSX11M flavour, same rel) together implement the host-side
software for one or more attached FPS-100 / AP-120B processors.

### Sysgen parameter `A$$P11` = number of APs

Set at sysgen time from `$NOAP`. Default in `FIRST.CMD`:

```
.DATA .SETN $NOAP 1   .; ONE AP IS BEING CONNECTED.
…
.DATA A$$P11='NAP'
```

Customer can set `$NOAP` to whatever number of APs they have. The
driver allocates per-AP state structures sized by `A$$P11`:

```asm
; DRIVER.MAC
CNTBL:  .BLKW   A$$P11        ; DMA UCB
SUPVR:  .BLKW   A$$P11        ; supervisor switch (per-AP)
SVUCB:  .BLKW   A$$P11        ; LUN1 UCB temp store
        INTSV$  AP,PR4,A$$P11 ; interrupt-save macro

; DAPEX.MAC
CSRTBL: .REPT   A$$P11        ; CSR table — one entry per AP
        CSR     \N            ; (.WORD APCOM<N>)
        N=N+1
        .ENDR
```

So the system maintains parallel sets of "control register block,
supervisor flag, UCB pointer, CSR address" per AP — they're not
sharing state.

### `APASGN(APNO, ACTION, STATUS)`

The `APASGN` host service routine in `DAPEX.MAC` lets a host task
acquire any specific AP by number:

```
APNO = 0  - ASSIGN ANY FPS PROCESSOR TO THE TASK
     > 0  - ASSIGN (APNO) PROCESSOR TO THE TASK
```

When `APNO=0` the driver iterates through all configured APs trying
to attach a free one. Either way, after assignment, `SETCSR` looks up
that AP's CSR base from `CSRTBL` and stores it in `APCSR`. All
subsequent operations on that LUN target that one physical AP.

A task can call `APASGN` multiple times to hold multiple APs.

### Microcode upload routes through `APIO` / `APWR` / `RUNDMA`

Once an AP is assigned, microcode is uploaded by writing AP program
memory via the host DMA path:

- `APWR` writes a single AP register
- `RUNDMA` issues a DMA transfer (host RAM ↔ AP)
- `RUNAP` starts AP execution

These all act on `APCSR` (the currently-assigned AP's register base).
Loading microcode into AP #2 requires re-pointing `APCSR` (i.e.
`APASGN(2,…)`).

There is **no path** in this software that says "AP #1, please
upload program from your memory to AP #2". The host owns AP↔AP
data movement through its own RAM.

### `SPLDGO` and the "second unit" `UNIT1`

`SPLDGO` ("S-Pad Load and GO") loads scratch S-Pad registers and
starts execution — it's *parameter passing* to a single AP, not
microcode upload between APs.

The `UNIT1` / `LUN1` machinery in `DAPEX.MAC` is *not* a second
physical AP. It's a **second logical unit number on the same physical
AP**, used to issue the supervisor-mode SETMOD command (function 5)
in parallel with normal data I/O. Code:

```asm
; DAPEX.MAC line ~422
.IFT FPS100
        MOV     UNIT,UNIT1            ; ASSIGN SECOND UNIT FOR FPS100
        INC     UNIT1                 ;
        DIR$    #ASGN2                ; ASSIGN IT
.IFTF
…
ASGN2:  ALUN$   LUN1,AP,0            ; LUN 4 → device "AP" (same physical)
```

`UNIT1 = UNIT + 1` — it's the *next* logical unit on the *same*
physical AP. This is FPS-100-specific because the FPS-100 needs an
explicit `SETMOD` ("force to AP120 mode") supervisor call at startup
that the AP-120B doesn't need; using a second LUN keeps that
control-channel separate from the data-channel.

## Two operating modes: AP120 mode vs Super-100 mode

The FPS-100 firmware has two modes the host can drive through:

- **AP120 mode** — host directly drives the AP's program memory via
  DMA, then issues `RUNDMA` / `RUNAP`. The AP is "dumb"; the host
  uploads everything.
- **Super-100 mode** — the FPS-100 runs an embedded supervisor
  ("Super-100" or "Mini-100") that the host messages via a
  command-block protocol. `SPLDGO` paths split on `TST SUPVR`:
  branch to `L2510` for Super-100 running, fall through for AP120
  mode.

Multi-AP coordination is not visible in either path. Each AP runs
its own supervisor independently when in Super-100 mode; the host
sends separate command blocks to each.

## Bomem HPVP — what we can't see

Bomem marketed the FPS-100 as the "HPVP" (High-Performance Vector
Processor) and their installer (`LOABOM.CMD;2` in the recovered
RSX-11M+ disks) references HPVP-specific files:

```
del bb0:hpvp.*;*4
.ask ans1 Are you using the HPVP processor ?
.100: @bb0:[1,54]loahpvp
```

Plus deletion entries for `hpcoad.*`, `hpregs.*`, `hptest.*` and
others. Those `loahpvp.cmd` and `hpvp.*` files **are not in the
recovered dataset** — they lived on the BOM1..BOM13 application
floppies that were not part of the bitsavers tape recovery and are
currently lost.

So we can't confirm or rule out whether Bomem extended the standard
multi-AP semantics with anything custom (e.g. coordinator-worker
splits across two FPS-100s for parallel FFT). Probably they didn't —
Bomem's typical installation is one HPVP per DA3 — but the question
is open until those files surface.

## Summary table

| Capability | Available in DRIVER.MAC + DAPEX.MAC? |
|---|---|
| Multiple FPS-100s attached to same RSX-11M host | **YES** (sysgen `$NOAP`/`A$$P11`) |
| Host task can hold LUNs to two FPS-100s in parallel | **YES** (two `APASGN` calls) |
| Independent microcode uploads to each FPS-100 | **YES** (each via its own LUN) |
| Master/slave AP↔AP communication path | **NO** (no such path in the driver) |
| AP-A uploads microcode to AP-B without host RAM in the loop | **NO** (host always intermediates) |
| Bomem HPVP-specific multi-AP extensions | **UNKNOWN** (BOM* application disks lost) |

## What this means for the FPS-3000 effort

The FPS-3000 chassis has **two XP-32 ACs sharing System Common Memory
through MEM CTL** — that's a different multi-processor model entirely
(true MIMD with shared memory). The FPS-100 multi-AP support
described here is just "two independent boxes on one host" and
doesn't carry a protocol useful for AC1↔AC2 coordination inside the
FPS-3000.

For host-side software to drive *the FPS-3000's* two ACs, the
relevant model is closer to: TCBXP1I and TCBXP2I (the two channel
tasks in the SBC ROM) each independently dispatch to their AC, with
the SBC managing arbitration. The FPS-100 multi-AP code wouldn't
apply directly even if it had a slave-AP path.

## Where to read more

- `fps100_archive/fps100sw/[327,010]DRIVER.MAC` — device driver
- `fps100_archive/fps100sw/[327,010]DAPEX.MAC` — APASGN/APRSET/SPLDGO etc.
- `fps100_archive/fps100sw/[327,010]FIRST.CMD` — `$NOAP` sysgen var
- `fps100_archive/fps100sw/[327,010]INSTAL.TXT` — § supervisors
- [`host_to_fps100_full_protocol.md`](host_to_fps100_full_protocol.md)
  — full host-side protocol reverse-engineered from these sources
- [`xpmlib_search_results.md`](xpmlib_search_results.md) — context
  on missing Bomem application disks
