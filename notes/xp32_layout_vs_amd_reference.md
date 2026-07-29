# The consensus XP-32 layout compared against AMD's published 128-bit word

Both layouts are 128 bits and both describe a machine built to do FFTs
from Am29500-family parts. Comparing them raises two objections to the
consensus layout in `notes/mc_xp32_microcode_inference.md` that the
FPS-lineage reasoning could not surface on its own.

| | consensus XP-32 | AMD reference |
|---|---|---|
| total | 128 ✓ | 128 ✓ |
| two arithmetic channels + operand routing | Adder#1 12 + Adder#2 12 + Data Pad 29 = **53** | Real ALU 32 + Imaginary ALU 32 = **64** |
| sequencing | Branch = **9** | Program Sequence = **32** |
| no counterpart in the other | SPAD 23, DMA 12, EU-coord 10 = **45** | — |

The arithmetic figure is reassuring: 53 against 64 bits for "two channels
plus the routing that feeds them" is the same ballpark, and the
difference is explained by AMD folding port selects and write enables
*into* each ALU group where the consensus separates them into a Data Pad
group. Nothing is wrong there.

The other two rows are the interesting ones.

---

## Objection 1: the S-Pad probably does not belong in the AU word at all

The consensus gives bits 1–23 to SPAD, at **HIGH** confidence, inherited
from the AP-120B where S-Pad is the integer/address register file living
in the same microword as everything else.

**The XP-32 is not that machine.** Hockney's split is explicit:

- **EU** — Am29116 controller, 2K × 80-bit fixed PROM
- **AU** — FP pipelines, 4K × 128-bit writable WCS

The Am29116 *is* a 16-bit integer processor with its own register file
and ALU. That is precisely the S-Pad's job. And AMD's design confirms the
division of labour directly: the Am29116 there "is programmed to produce
the address sequence for Filters and Matrix Multiplication" — integer
address arithmetic, in the part that has an integer datapath.

So on the XP-32 the S-Pad function plausibly **moved out of the AU
microword into the EU**, and the 23 bits the consensus allocates to it in
the AU word may be an artefact of importing AP-120B structure into a
machine that split the two units apart.

The AU word is what the S-record path uploads. If this is right:

- the AU word has **no S-Pad field**, freeing ~23 bits;
- S-Pad operations appear in the **EU PROM** instead, encoded as Am29116
  instructions — which is exactly what an EU PROM dump would show;
- the consensus's `EU_ADDR` difficulty (8 bits for an 11-bit 2K address
  space, flagged in `mc_xp32_layout_stress.md`) looks different if the EU
  is not being *addressed* by the AU word but running its own program.

**Testable.** An EU PROM dump containing recognisable S-Pad-style integer
ops confirms it. A real XPMLIB AU kernel showing a coherent 23-bit field
in bits 1–23 refutes it.

---

## Objection 2: a 9-bit branch field cannot address a 4K store

The consensus gives 9 bits to Branch (COND + DISP), inherited from the
AP-120B's `CONDF` (4 bits) + `DISPF` (5 bits).

AMD's design spends **12 bits on the branch address alone** (`BR11…BR0`)
plus condition-select bits, for a store "up to 2K deep". The XP-32's WCS
is **4K × 128 per bank** — deeper still, needing 12 bits for a direct
address.

Nine bits cannot express a 4K target directly. Two ways out, both
consistent with the FPS lineage:

1. **Short relative displacement**, as on the AP-120B: `DISP` is a signed
   offset from the current address, with long transfers going through a
   sequencer stack or an address register rather than the microword. This
   is the more likely reading, since it is what the ancestor did.
2. **A separate address field** elsewhere in the word that the consensus
   has assigned to another group.

This is not a refutation — option 1 is perfectly workable — but the
consensus should state which mechanism it assumes, because a reader
checking "can this word address its own store?" will otherwise find that
it cannot, and the answer "it branches relatively" is load-bearing.

---

## What this does not change

The consensus's HIGH-confidence groups for Adder, Multiplier and Memory
survive the comparison intact; the arithmetic-plus-routing budget agrees
to within 11 bits, which for two independently-derived layouts of the
same-width word is close.

And both objections are **inference from a related design**, not
measurement of the XP-32. AMD's board is 16-bit fixed-point with Am29501
slices and an Am2910A sequencer; the XP-32 is 32-bit IEEE-754 with Weitek
parts and an Am29116-based EU. The comparison is legitimate because the
parts overlap and the workload is identical, not because the machines are
the same.
