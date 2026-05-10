# What the FPS-100 archive lets us infer about the FPS-3000 68K ROM

The 68K SBC ROM disassembly was largely understood in isolation. Now
that we've decoded 13,440 AP-120B microinstructions, annotated the
full FPS-100 host-side dispatcher (`DAPEX.MAC`), the simulator source
(`SIM100.FTN`), and the AP-side supervisor (`*.S` files), several
new inferences become possible — some confirmatory, some new, some
genuinely surprising.

This is my analytical synthesis. A separate Council-of-Clankers
re-inference is in `fps3k_68k_reinference.md`.

## 1. The 21 panel commands map structurally to FPS-100's HSVC table

**New inference**: the panel-command codes `0x258..0x27D` aren't just
"Am29116 SUBRC instructions" in a vacuum. They almost certainly
correspond to **HSVC-style entry points in the EU PROM**.

Evidence chain:

- The FPS-100 has `HSVC.S`/`HSVCM.S` — a dispatch table of
  Host-Service routines that runs on the AP. Each entry is a
  pre-programmed routine the host can invoke by sending a function
  code over the QIO channel.
- `SYSSVC.S` (10 routines, 527 microinstructions in the .B file)
  implements the actual handlers — the AP-side syscall router.
- The FPS-3000's panel codes group into Group A (0x258-0x25F, 8
  codes) and Group B (0x260-0x27D, ~13 distinct codes, sparse) —
  21 total. **HSVC dispatch tables in FPS-100 are exactly this kind
  of structure**: a sparse set of opcode→handler entries.
- The Am29116-SUBRC interpretation works perfectly with this:
  the EU's command-handler reads the 16-bit code, executes it as a
  SUBRC (which has the side effect of accessing R[N] in the
  Am29116's RAM file), and the side effect IS the dispatch.

So the panel codes are HSVC-equivalents. R[N]-as-dispatch-index
gives ~32 possible handlers, of which 21 are populated in the
FPS-3000.

Confidence: **high** that it's HSVC-style; **medium** that the
Am29116 RAM-as-dispatch-table is the specific mechanism (vs. a
separate decoder reading the SUBRC result in ACC).

## 2. `0x8004`/`0x8005` are NOT FPS-100 driver function codes

**New inference**: the SBC writes `0x8004` (REQUEST-XFER) and
`0x8005` (CONTINUE) to `0xFF0000` to initiate AP I/F transactions.
With the FPS-100 archive in hand we can check: do these match
anything in FPS-100?

- FPS-100 driver QIO function codes are **1, 5, 6** (RUNDMA,
  SETMOD, TERMSUP). All small integers.
- `0x8004` / `0x8005` have the high bit set — they look like
  **command-with-flag** encodings, not function codes.
- Likely: `0x8000` is a "command valid" flag, with low bits
  (4, 5, etc.) being specific commands. So `0x8004` = "command 4",
  `0x8005` = "command 5", with the 0x8000 acting as strobe.

This is a different protocol from FPS-100's QIO dispatch. The
FPS-3000 uses VersaBUS short-I/O semantics (16-bit commands at
fixed register offsets), while the FPS-100 uses RSX QIO (function
codes in I/O packets). Different abstraction levels, different
encodings. **The FPS-3000 is closer to bare-metal AP-control than
FPS-100's QIO-wrapped dispatch.**

Confidence: **high**.

## 3. RMS68K task structure parallels AP-side KERNEL.S

**Confirmation, sharpened**: we knew RMS68K runs `TCBRDHC`,
`TCBIO1I`, `TCBXP1I-4I` as concurrent tasks. With FPS-100's
`KERNEL.S` (1216 lines, EXTASK module) annotated, we can see the
specific design pattern:

- FPS-100 KERNEL: priority-based ready-queue dispatcher; each task
  has its own context (S-Pad slice + DPX slice). When a task
  blocks on I/O or syscall, it suspends and EXTASK picks the next
  ready task.
- FPS-3000 RMS68K: same model but on the M68000 with full virtual
  task contexts. TCBRDHC is the highest-priority dispatcher; TCBIO1I
  handles host I/O; TCBXP1I-4I handle per-channel XP-32 ops.

The novelty: the FPS-3000 essentially **moves the FPS-100's AP-side
task scheduler to the host-side SBC**. Where the FPS-100 ran KERNEL
on the AP itself in Super-100 mode, the FPS-3000 runs a parallel
RMS68K-based scheduler on the SBC. Both designs fan out one host
request to one of many parallel AP-side execution channels.

This supports the inference that the FPS-3000 EU PROM does NOT need
a full task scheduler — that role moved to the SBC. The EU PROM is
just a command-dispatch + microcode-execution-loop. Smaller, simpler.

Confidence: **medium-high**.

## 4. Microcode-upload path mirrors LODINP

**Confirmation**: the SBC ROM's S-record-driven microcode upload
into the 64KB staging buffer (`0x10000-0x1FFFF`) followed by
panel-command-driven WCS write is functionally analogous to FPS-100's
`LODINP` (LED100, line 3976) — which reads load-module records
into AP program memory.

The structural match:

| FPS-100 LODINP | FPS-3000 SBC |
|---|---|
| Read load-module records | Receive S-records from host |
| Parse type+addr+data per record | Parse type+addr+data per S-record |
| Validate addr range vs AP memory | Validate `0x10000 ≤ addr ≤ 0x1FFFF` |
| Write byte-by-byte to AP via DMA | Stage in SBC RAM, then DMA-equivalent |
| Trigger end-of-load action | Issue panel command sequence |

This pattern — "host streams microcode records into a staging area,
then triggers a transfer" — is consistent across both generations.
The FPS-3000 just adds an extra layer (SBC) between host and AP.

Confidence: **high**.

## 5. Two-mode architecture question — likely no analog

The FPS-100 has two distinct runtime modes:
- **AP120 mode**: host fully drives, FPS-100 is a pure coprocessor
- **Super-100/Mini-100 mode**: FPS-100 runs `KERNEL.S` etc. on the
  AP, host sends RPC requests via HSVC/HIRP

**Inference**: the FPS-3000 likely has only one mode, equivalent to
"Super-100" — the EU PROM always runs the dispatcher, and host
requests are always RPC-style (panel-command-driven). Reasoning:

- The 68K SBC is itself a Super-100-equivalent — it provides the
  task scheduler, the I/O queue, the host-RPC endpoints. The
  FPS-3000 separates those duties to a dedicated processor.
- With the SBC handling scheduling, there's no use case for an
  "AP120 mode" where host directly programs the AP — the SBC is
  always between them.
- The 21 panel commands are too few to be a full instruction set;
  they're too many to be just operating modes; they fit perfectly
  with "RPC dispatch table".

Confidence: **medium**.

## 6. EU PROM size estimate, with structure

Hockney describes the EU as 2K × 80 bits = 20 KB. Given the FPS-100
AP-side supervisor body sizes:

| FPS-100 module | Microinstr | AP-120B 64-bit at 8 bytes |
|---|---:|---:|
| KERNEL (task scheduler) | 283 | 2.3 KB |
| MINI (Mini-100 supervisor) | 318 | 2.5 KB |
| SYSSVC (syscall handlers) | 527 | 4.2 KB |
| IOQUE (I/O queue) | 43 | 0.3 KB |
| HIRP/HSVC (RPC) | ~150 | 1.2 KB |
| RTC (interrupt-driven clock) | 248 | 2.0 KB |
| **Total core supervisor** | ~1,500 | ~12 KB |

**Inference**: 12 KB of FPS-100 AP-side supervisor maps to roughly
1,200 EU PROM words at 80 bits (10 bytes each) on the FPS-3000.
Out of 2K total words, that leaves ~800 words = 8 KB for the
panel-command dispatcher + Am29116-specific bootstrap + per-panel-
command handlers + any FPS-3000-specific bookkeeping.

Realistic structure of the EU PROM (estimate):

```
0o0000-0o0177  (256 words)  Reset / power-on init / Am29116 bootstrap
0o0200-0o0777  (1.5K words) Per-panel-command handlers (21 × ~70 words)
0o1000-0o1777  (1K words)   Common subroutines: AU WCS write, DMA setup,
                            SCM access, status reporting, error paths
0o2000-0o3777  (1K words)   Reserved / unused (or extended dispatch)
                            EU PROM is 2K × 80 = 0o4000 words total
```

Confidence: **low-medium** — this is a structural estimate based on
analogous FPS-100 sizing, not direct evidence. Reading the actual
EU PROM would settle it, but the estimate gives Lovett a target
size budget if/when he reads it.

## 7. What the FPS-3000 ROM does NOT have (and the FPS-100 does)

The FPS-100 has a **host-side LED100 link editor** that produces
load modules to upload to the AP. The FPS-3000 SBC ROM clearly
**does not link** — it just receives pre-linked S-records and
shovels them into the AU WCS staging buffer.

**Inference**: the host system that talks to the FPS-3000 must
include the equivalent of LED100 — i.e., XPMLIB kernels are
pre-linked on the host, then sent as raw bytes to the SBC.

This is consistent with what we'd expect — XPMLIB binaries (which
we don't have) would be pre-built at compile time on the host, not
linked at the FPS-3000 SBC. So if/when we recover an XPMLIB binary
artifact, it'll be in **load-module form, not object form** — much
simpler than `.APO`.

Confidence: **high**.

## 8. The Bomem RSX-11M+ disks: what role for the SBC?

**New inference, with implications for the HPVP question**: if HPVP
is FPS-100-equivalent (still unproven), then on the Bomem DA3 system
the SBC ROM we're analyzing wouldn't be in the picture — the FPS-100
talks directly to the PDP-11 host via APDRV.

But Lovett's chassis has BOTH an FPS-100 AND an FPS-3000. So either:
- HPVP is FPS-100, and the FPS-3000 is a separate later acquisition
  that's NOT part of the original DA3 system, OR
- HPVP is FPS-3000, and this SBC ROM is what BOMICP/loahpvp installed
  software talks to, OR
- HPVP is a third thing entirely

The 68K ROM doesn't constrain this either way — it's compatible with
either an FPS-100-host or FPS-3000-host scenario, just at different
levels of abstraction.

Confidence: open question, no new evidence.

## 9. Specific 68K addresses with new context

With FPS-100 reference in hand, several SBC ROM addresses get clearer
interpretations:

| Addr | Old reading | New reading with FPS-100 context |
|---|---|---|
| `F046E0` | `ChannelConfigOffsetTable` (4 longwords) | Confirmed: per-channel XLTR config offsets `0x244, 0x246, 0x250, 0x252` — exactly the structure expected for a multi-channel HSVC dispatcher |
| `F051A2` `SRecordDataHandler` | Validates `0x10000 ≤ addr ≤ 0x1FFFF` | Now clearly mirrors FPS-100 LODINP's address-range validation |
| `F056BA` `PanelSendAndWait` | Sends panel command, polls ready | Functionally equivalent to FPS-100's APIO dispatch loop in DAPEX.MAC |
| `F05BA4` `PanelStatusDispatchTable` | 20-entry status dispatch | If panel codes are HSVC-style, this is the host-side equivalent of HSVC's status-return table |
| `F046F0` `TCBRDHC` | RDHC master/dispatch task | The "Read/Display/Help/Channel" task is functionally the SBC's KERNEL — it's the central dispatcher |

## 10. Net new artifacts the FPS-100 archive justifies producing

Given we now have:
- Full AP-120B microcode reference (`apo_decoded/`)
- AP-side supervisor reference (`*.S` annotations)
- Working SIM100 (modulo COMMON-block fix)
- DAPEX dispatcher reference

We're well-positioned to produce:

1. **An FPS-3000 SBC ROM "annotated mirror" of DAPEX** — i.e., for
   each major SBC routine, identify the DAPEX/SYSSVC analog. This
   would close the loop between host-side (SBC) and AP-side (EU PROM)
   architecture even without an EU PROM dump.

2. **A panel-code-to-HSVC mapping table** — speculative for now,
   becomes verifiable when EU PROM is read.

3. **A "host should send what to talk to the FPS-3000" cookbook** —
   given XPMLIB API names (XPSEL/XPRUN/XPWAIT/XPDMAR) and the panel-
   command alphabet, document the exact byte sequences a host would
   send for each operation. Useful for the FPGA AP-I/F substitute
   work.

4. **A SIM100-based simulator for the FPS-3000** — once SIM100's
   COMMON-block bug is fixed, extending its execution model to
   handle XP-32-style microinstructions becomes feasible. This
   would let us *run* the consensus 128-bit layout against synthetic
   microcode and observe behavior.

These all become achievable now in a way they weren't before.

## Summary

The FPS-100 archive is more than just "ancestor-side reference for
the AP-120B microcode format". It's a **complete software-stack
template**: KERNEL, IOQUE, HSVC, HIRP, SYSSVC, RTC, boot, host-side
dispatcher (DAPEX), user-callable HSR stubs, math libraries — all
labeled, all annotated.

The FPS-3000 SBC ROM implements roughly the **same software stack**
but moved up one level (host-side instead of AP-side) and adapted
to RMS68K + VersaBUS. With the FPS-100 archive as a labeled mirror,
many SBC routines that we'd inferred functionally now have specific
named analogs.

The strongest new inferences:
- Panel codes are HSVC-style RPC dispatch (not just opaque opcodes)
- `0x8004`/`0x8005` are command-with-flag, not function codes
- The EU PROM likely has ~1,200 words supervisor + ~800 words
  dispatcher + handlers (out of 2K total)
- The FPS-3000 has no AP120-mode equivalent (always Super-100-like)
- Host system needs LED100-equivalent for XPMLIB; pre-linked load
  modules sent to SBC

The weakest still-open questions:
- HPVP identity
- EU PROM contents (still requires physical read)
- Per-panel-code semantics (handler-by-handler)
- Whether the AU WCS write port is wired exactly as we assume
