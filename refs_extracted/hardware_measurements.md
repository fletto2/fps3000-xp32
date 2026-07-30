# Measurements the working monitor can now make

The monitor runs on the real machine (owner, 2026-07-30). Its `m`/`d` command dumps memory and
I/O, which makes several questions this project could only infer directly answerable. Each entry
below gives the address, what the emulator currently says, and **what a differing answer would
mean** — the last column is the point, since a measurement that cannot surprise us is not worth
the owner's time.

Ordered by how much the answer would change.

## 1. `$FF0218` bit 4 — two BIMs or three?

    m FF0218

| | |
|---|---|
| emulator | **bit 4 SET** (three BIMs), as of this session |
| photograph | three `MC68153P` are physically fitted |
| **if bit 4 reads CLEAR** | the presence bit is not what selects the walk, and the 3-BIM card is being told to behave as 2 — the self-test would only ever touch 16 of 24 registers on real iron |

Highest value: it tests a change made this session on photographic evidence alone, and the
firmware has a code path for each answer.

**Caveat that matters:** phase `$1600` *clears* bit 4 by writing `$400` during the self-test, so
a post-boot read may show it clear regardless. Read it **before** any `w` to `$FF0218`, and
treat a clear reading as inconclusive rather than as a refutation.

## 2. `$10AA` — does the chassis write it?

    m 10AA

| | |
|---|---|
| this ROM | **never names it as a write target** — one reference in 64 KB, and it is a read |
| emulator | reads 0 unless forced |
| **if nonzero on hardware** | confirms the off-board write, and chassis op `$6` is the mechanism |
| if zero | the value arrives only in configurations we have not reproduced |

## 3. `$105E` — the channel-present count

    m 105E

Expect **2** on Lovett's 2-AC machine. The XP tasks gate on `cmpi.w #<own channel>,$105E`, so
this single word decides whether XP3I and XP4I run at all. A value of 4 would mean the count is
not what we think.

## 4. RDHC's saved PC — `$1F3FC`

    m 1F3FC

| | |
|---|---|
| emulator, clean boot | **`$F04740`** — parked in the directive-`$13` wait |
| emulator, driven | **`$F056B8`** — the `bra .` spin |
| **on hardware** | if it reads **anything else**, RDHC gets further than any emulator configuration has managed, and that address names where |

This is the single most informative word in RAM for the emulation effort.

## 5. The `$1FFE0-$1FFFF` block — registers or RAM?

    m 1FFE0

Read, then `w` a pattern, then read back. `$1FFF0-$1FFF3` is excluded by **eight** independent
memory-test sites and is the only part this project believes is hardware. `$1FFE2`/`$1FFE4`/
`$1FFE6` are walked by the address-line test and should behave as RAM. **A location that does
not read back what was written is a register**, and that settles a question three entries of
this file argue about.

## 6. `$F70030` — the kernel's lone device access

    m F70030

Read, set bit 5, read back. The RMS68K kernel does exactly this at `$F00A3A` and it is the only
device access in the whole 17.5 KB kernel region. The emulator models it as a plain latch
because a BERR there would fault the kernel. **Whether it reads back what was written is
unknown**, and the answer names what kind of register it is.

## 7. `!IDV` — confirm the 14-byte record layout

    m 1F800

Expect `!IDV` as the first longword, an end pointer at `+$4`, then **six 14-byte records** of
`{vector, TCB, ISR entry, ISR exit}` starting at `+$8`. The layout was derived from the kernel's
own traversal; a hardware dump confirms it against a live table.

## 8. TCB layout — `$1E900`, stride `$200`

    m 1E900

Confirm task name at `+$10`, entry point at `+$6C`, saved PC at `+$FC`. The vendor `TCB.EQ` from
SR10 disagrees about the entry point (`+$5A`, reads zero), so **this build's layout differs from
that header** and a hardware dump is the only authority.

---

*A note on what not to read.* `$FF0204` is the SBC's outbound word and `$FF000E` is a command
port; reading them is harmless, but **writing** either issues a chassis command. `w` to
`$FF0216` bit 5 gates the `$400000` window and bit 4 muxes the data path. The monitor's `L`
loader already refuses writes at or above `$20000` for this reason.
