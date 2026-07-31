#!/usr/bin/env python3
"""
Disassemble the RMS68K kernel region, 0xF00000-0xF04487.

Why this exists as a separate tool from disasm.py: fps3k.asm covers only
0xF04488-0xF0FFFE, the FPS application.  The kernel's 17,544 bytes -- 27% of
the ROM -- were outside the project's main disassembly entirely.  That was a
scope decision (the kernel is stock Motorola RMS68K) which was never revisited.

The kernel dispatches directives with `move.l (a0),-(a7)` / `rts`, using the
return stack as an indirect jump.  Linear control-flow following loses the
thread at that rts, so the entry points have to be supplied from the jump
table rather than discovered.  That table is the main seed source here.

Output: fps3k_kernel.asm
"""
import struct
from capstone import Cs, CS_ARCH_M68K, CS_MODE_M68K_000

ROM_PATH = "FPS3K_U11_U12_JOIN.bin"
import os
BASE = 0xF00000
# Region is overridable so the same seeding strategy can be pointed at the
# application region as a control -- if it beats disasm.py's 49.6% there, the
# gain is the strategy and not something peculiar to the kernel.
START = int(os.environ.get("FPS3K_DIS_START", "0xF00000"), 16)
END = int(os.environ.get("FPS3K_DIS_END", "0xF04488"), 16)
OUT_PATH = os.environ.get("FPS3K_DIS_OUT", "fps3k_kernel.asm")

# The TRAP #0 directive jump table.  35 longword slots; slot 0 and slot $20
# both hold the error return, so there are 34 distinct entry points.
TRAP0_TABLE, TRAP0_N = 0xF001D6, 35

# TRAP #0 directive names, from Motorola STR.EQ (decimal numbering).
# $05 T0PGFR independently confirms the page-deallocator reading of $F01496.
DIRECTIVE_NAMES = {
    0x01: "T0P", 0x02: "T0V", 0x03: "T0RYDLAY", 0x04: "T0PAGAL",
    0x05: "T0PGFR", 0x06: "T0GETTCB", 0x07: "T0FNDSEG", 0x08: "T0LOGPHY",
    0x09: "T0FNDGSG", 0x0B: "T0QEVNTN", 0x0C: "T0FNDSEM", 0x0D: "T0GTXTCB",
    0x0E: "T0PAUSE", 0x15: "T0EXABRT", 0x16: "T0WAKEUP", 0x17: "T0QEVNTT",
    0x18: "T0QEVNTI", 0x1A: "T0LOGPHO", 0x1C: "T0RDTIM", 0x1F: "T0CRTCB",
    0x20: "T0KILLER", 0x22: "T0RQPA",
}


# The TRAP #1 directive table.  Names from Motorola's TR1.EQ/STR.EQ, which
# number directives in DECIMAL -- the reason they went unmatched for so long.
TRAP1_TABLE, TRAP1_N = 0xF003D8, 77
TRAP1_NAMES = {
    0x4C: "CNCTIRQ",   # not in TR1.EQ (which stops at 75); handler $F02216
    0x01: "GTSEG", 0x02: "DESEG", 0x03: "TRSEG", 0x04: "ATTSEG",
    0x05: "SHRSEG", 0x06: "MOVELL", 0x07: "DCLSHR", 0x08: "SNPTRC",
    0x09: "RCVSA", 0x0A: "GTTASKID", 0x0B: "CRTCB", 0x0C: "GTTASKNM",
    0x0D: "START", 0x0E: "ABORT", 0x0F: "TERM", 0x10: "TERMT",
    0x11: "SUSPND", 0x12: "RESUME", 0x13: "WAIT", 0x14: "WAKEUP",
    0x15: "DELAY", 0x16: "RELINQ", 0x17: "TSKATTR", 0x18: "SETPRI",
    0x19: "STOP", 0x1A: "EXPVCT", 0x1B: "TRPVCT", 0x1C: "TSKINFO",
    0x1D: "RQSTPA", 0x1E: "DELAYW", 0x1F: "GTASQ", 0x20: "DEASQ",
    0x21: "SETASQ", 0x22: "RDEVNT", 0x23: "QEVNT", 0x24: "WTEVNT",
    0x25: "RTEVNT", 0x26: "GTEVNT", 0x29: "ATSEM", 0x2A: "WTSEM",
    0x2B: "SGSEM", 0x2C: "DESEM", 0x2D: "CRSEM", 0x2E: "DESEMA",
    0x33: "SERVER", 0x34: "DSERVE", 0x35: "DERQST", 0x36: "AKRQST",
    0x3A: "CDIR", 0x3C: "CMR", 0x3D: "CISR", 0x3E: "SINT",
    0x40: "EXMON", 0x41: "DEMON", 0x42: "EXMMSK", 0x43: "RSTATE",
    0x44: "PSTATE", 0x45: "REXMON", 0x48: "MOVEPL", 0x49: "STDTIM",
    0x4A: "GTDTIM", 0x4B: "FLUSHC",
}


# Regions that are KNOWN data and must never be decoded as instructions.  The
# dispatch tables are the ones that actually bit: a table of small
# self-relative offsets disassembles cleanly, so both the recursive descent
# (via a stale seed) and the gap-recovery sweep will happily turn 14 bytes of
# the TRAP #1 table into `ori.b`/`move.b`.  Guarding only the sweep was not
# enough -- the descent reached $F003DA on its own.
DATA_REGIONS = [
    (TRAP0_TABLE, TRAP0_TABLE + 4 * TRAP0_N),   # $F001D6 + 140
    (TRAP1_TABLE, TRAP1_TABLE + 4 * TRAP1_N),   # $F003D8 + 308
]


def is_data(a):
    return any(lo <= a < hi for lo, hi in DATA_REGIONS)


def is_padding(rom, a):
    """Opcode word $0000-$0007 is `ori.b #imm,dN` -- and in this image it is
    always alignment padding, never an instruction.

    Measured: 338 such "instructions" across the kernel and the application
    region, and NOT ONE was ever executed.  Meanwhile every one of the six
    executed PCs the decoder failed to place on an instruction boundary was
    swallowed by exactly this pattern -- a $0000 pad decoding as a 4-byte
    `ori.b` and eating the real `moveq #$1,d0` behind it.  $F09BFE is the
    sharpest case: it ate $F09C00, the reset entry point.
    """
    return struct.unpack(">H", rom[a - BASE:a - BASE + 2])[0] <= 0x0007


def valid(a):
    return START <= a < END and (a & 1) == 0 and not is_data(a)


def seed_set(rom):
    """Entry points a linear scan cannot reach, plus the ones it can."""
    seeds, names = set(), {}

    rv = struct.unpack(">I", rom[4:8])[0] & 0xFFFFFF
    if valid(rv):
        seeds.add(rv)
        names[rv] = "RESET"

    for i in range(TRAP0_N):
        off = TRAP0_TABLE - BASE + 4 * i
        t = struct.unpack(">I", rom[off:off + 4])[0] & 0xFFFFFF
        if valid(t):
            seeds.add(t)
            # Name the directives we can; the rest get a generic tag so the
            # listing still shows which slot reaches them.
            nm = DIRECTIVE_NAMES.get(i)
            names.setdefault(t, f"TRAP0_{nm}" if nm else f"TRAP0_dir_{i:02X}")

            # 29 of the 33 real handlers are preceded two bytes earlier by
            # `move.w sr,-(a7)` (0x40E7).  That is the kernel's calling
            # convention, not a coincidence: internal bsr callers enter at the
            # earlier address and push SR themselves, while the TRAP path
            # enters at the table pointer and skips the push BECAUSE THE TRAP
            # HAS ALREADY STACKED SR.  So the real routine start is two bytes
            # before every table entry, and seeding only the pointer loses it.
            if t - 2 >= START and struct.unpack(
                    ">H", rom[t - 2 - BASE:t - BASE])[0] == 0x40E7:
                seeds.add(t - 2)
                names.setdefault(t - 2, f"{names[t]}_bsr")

    # The TRAP #1 directive table.  77 entries of 4 bytes covering directives
    # $00-$4C; the dispatcher at $F00310 range-checks with `bgt #$130`, so
    # d0 == $130 passes and $4C is the last valid entry, not an overflow.
    #
    # w0 is a SELF-RELATIVE SIGNED offset -- `adda.w (a2),a2` at $F0036A --
    # so the handler is the entry's own address plus w0.  Reading it as an
    # absolute address yields plausible-looking garbage.
    for i in range(TRAP1_N):
        e = TRAP1_TABLE + 4 * i
        w0 = struct.unpack(">h", rom[e - BASE:e - BASE + 2])[0]
        h = e + w0
        if valid(h):
            seeds.add(h)
            nm = TRAP1_NAMES.get(i)
            names.setdefault(h, f"TRAP1_{nm}" if nm else f"TRAP1_dir_{i:02X}")

    # FPS3K_DIS_RAM=<dump> seeds from the RUNTIME vector table.
    #
    # The ROM has no vector table (see below), but RMS68K builds one in RAM at
    # boot, and it points at handlers no ROM scan can reach -- including the
    # 14-entry bsr fan-in ladder at $F00A78 that services TRAP #2-#15, which
    # this project had recorded as "free vectors".
    _ram = os.environ.get("FPS3K_DIS_RAM")
    if _ram:
        try:
            rd = open(_ram, "rb").read()
        except OSError:
            rd = b""
        for v in range(256):
            if 4 * v + 4 > len(rd):
                break
            t = struct.unpack(">I", rd[4 * v:4 * v + 4])[0] & 0xFFFFFF
            if valid(t):
                seeds.add(t)
                names.setdefault(t, f"VEC_{v:02X}_{t:06X}")

    # FPS3K_DIS_TRACE=<pc trace> seeds from PCs the CPU actually executed.
    #
    # This is the strongest seed source available: an executed PC is an
    # instruction boundary by construction, not by inference.  It cannot
    # mistake data for code the way a linear sweep can.  It is of course only
    # as complete as the run that produced it, so it supplements the static
    # seeds rather than replacing them.
    _tr = os.environ.get("FPS3K_DIS_TRACE")
    if _tr:
        try:
            import re as _re
            for _p in {int(x, 16) for x in
                       _re.findall(r"[0-9A-F]{6}", open(_tr).read())}:
                if valid(_p):
                    seeds.add(_p)
                    TRACE_SEEDS.add(_p)
        except OSError:
            pass

    # NOT a vector table.  The reset overlay aliases ROM at 0 only so the
    # 68000 can fetch SSP from +0 and PC from +4; measured, +4 = $F09C00 and
    # offsets $08-$3FF are zero.  RMS68K builds the whole vector table in RAM
    # at boot, so there is nothing to seed from here -- an earlier version of
    # this tool swept 2..255 as if it were a vector table and got 2 hits out
    # of 254, both coincidence.
    #
    # Handlers installed statically by the self-test, found by scanning for
    # `move.l #kernel_addr, <low memory>`.  Vectors 2 and 3 matter: pointing
    # bus error and address error at a handler is how self-test phase $600
    # survives the BERR its bus-timeout watchdog test deliberately provokes.
    for a, nm in ((0xF001AC, "TRAP0_HANDLER"),):
        if valid(a):
            seeds.add(a)
            names.setdefault(a, nm)

    return seeds, names


def scan_calls(rom):
    """Every bsr/jsr/jmp target in the whole ROM that lands in the kernel.

    A call target is code by construction, which makes this a much safer
    seed source than a linear sweep.  It scans the application region too,
    because the FPS layer calls into the kernel.

    Note bsr.w stores no address anywhere -- only a 16-bit displacement --
    so a scan for absolute pointers cannot see these targets at all.  That
    is a real false-negative class: $F02C6C has three bsr.w callers and
    zero longword references to it.
    """
    out = set()
    for off in range(0, len(rom) - 5, 2):
        op = struct.unpack(">H", rom[off:off + 2])[0]
        a = BASE + off
        t = None
        if op in (0x4EB9, 0x4EF9):                      # jsr/jmp abs.l
            t = struct.unpack(">I", rom[off + 2:off + 6])[0] & 0xFFFFFF
        elif op in (0x4EBA, 0x4EFA):                    # jsr/jmp d16(pc)
            t = a + 2 + struct.unpack(">h", rom[off + 2:off + 4])[0]
        elif op == 0x6100:                              # bsr.w
            t = a + 2 + struct.unpack(">h", rom[off + 2:off + 4])[0]
        elif (op >> 8) == 0x61 and (op & 0xFF) not in (0x00, 0xFF):
            t = a + 2 + struct.unpack(">b", rom[off + 1:off + 2])[0]
        if t is not None and valid(t):
            out.add(t)
    return out


def scan_pointer_tables(rom):
    """Longwords anywhere in ROM that point at kernel code.

    The TRAP #0 table is not the only dispatch table in here -- the kernel
    resolves queues and tasks by name at runtime and uses tables throughout.
    This is a weaker signal than a call target (any longword can coincidentally
    look like an address), so it is kept as a separate tier and each candidate
    must decode into a plausible instruction before it is trusted.
    """
    md = Cs(CS_ARCH_M68K, CS_MODE_M68K_000)
    out = set()
    for off in range(0, len(rom) - 3, 2):
        t = struct.unpack(">I", rom[off:off + 4])[0]
        if (t >> 24) or not valid(t & 0xFFFFFF):
            continue
        t &= 0xFFFFFF
        try:
            ins = next(md.disasm(rom[t - BASE:t - BASE + 10], t, count=1))
        except StopIteration:
            continue
        if ins.size:
            out.add(t)
    return out


# Instructions after which straight-line decoding must stop.
TERMINAL = {"rts", "rte", "rtr", "jmp", "bra", "bra.b", "bra.w", "bra.s", "stop"}


def decode(rom, seeds):
    md = Cs(CS_ARCH_M68K, CS_MODE_M68K_000)
    md.detail = True
    code, visited = {}, bytearray(END - START)

    # Trace-derived seeds go first.  An executed PC is an instruction boundary
    # by construction, so it must be allowed to claim its own bytes before any
    # inferred seed can swallow them.  $F046F0 (`moveq #$1,d0`, the TCBRDHC
    # main loop) was being eaten by `andi.w #$7001,(a2)` decoded at $F046EE --
    # which is really the tail of a four-longword table of BIM CR offsets
    # ($244/$246/$250/$252), not an instruction at all.
    queue = sorted(seeds - TRACE_SEEDS) + sorted(seeds & TRACE_SEEDS)

    while queue:
        a = queue.pop()
        while valid(a) and not visited[a - START]:
            try:
                ins = next(md.disasm(rom[a - BASE:a - BASE + 10], a, count=1))
            except StopIteration:
                break
            if ins.size == 0 or a + ins.size > END:
                break
            if is_padding(rom, a):
                break
            # Refuse an instruction that would overlap bytes already claimed.
            # Only the START byte was checked before, so a 4-byte decode could
            # straddle and hide an instruction boundary established earlier --
            # `andi.w #$7001,(a2)` at $F046EE swallowing `moveq #$1,d0` at
            # $F046F0 (the TCBRDHC main loop) is the case.  $F046EE is really
            # the tail of a four-longword table of BIM CR offsets.
            if any(visited[a - START + i] for i in range(ins.size)):
                break
            for i in range(ins.size):
                visited[a - START + i] = 1
            code[a] = ins

            # Queue any branch/call target so the descent stays recursive.
            for tok in ins.op_str.replace(",", " ").split():
                tok = tok.strip("#$()").rstrip(".lwbLWB")
                try:
                    t = int(tok, 16)
                except ValueError:
                    continue
                if valid(t) and not visited[t - START]:
                    queue.append(t)

            if ins.mnemonic.lower() in TERMINAL:
                break
            a += ins.size
    return code, visited


MAX_RUN = 512

# Seeds that came from a PC trace.  These are decoded FIRST -- see decode().
TRACE_SEEDS = set()


def recover_gaps(rom, code, visited, rounds=4):
    """Linear-sweep recovery for code the recursive descent cannot reach.

    Descent stops dead at an unconditional flow break (`bra`, `rts`, `jmp`),
    so a block whose only entry is a computed jump or a fallthrough from an
    undecoded neighbour stays dark -- $F01932 (`tst.l d5` / `beq`, 54 bytes
    into GTSEG) is the type case.

    Turning data into code is the failure mode to avoid, so a run is accepted
    ONLY if it reconnects: every instruction must decode, and the sweep must
    end either exactly on the first byte of already-known code or on a
    terminator.  A run that decodes into the middle of a known instruction,
    or that runs off the end, is rejected whole.
    """
    md = Cs(CS_ARCH_M68K, CS_MODE_M68K_000)
    recovered = 0
    for _ in range(rounds):
        gained = 0
        # Gap starts: an even, unvisited byte whose predecessor is visited or
        # which begins the region.
        # Every even unvisited address is a candidate start, not just the
        # first byte of a gap.  A gap often opens with a few words of table or
        # with the tail of a preceding instruction ($F04088's `fffe` is the
        # case that forced this), so anchoring only at the gap head loses the
        # real entry point a few words later.  Trying interiors is safe
        # BECAUSE acceptance still requires the run to reconnect; a wrong
        # start almost never lands back on an instruction boundary.
        starts = [a for a in range(START, END, 2)
                  if not visited[a - START] and not is_data(a)]
        for g in starts:
            # Cap the run length.  Trying every even address in a gap is
            # quadratic in the gap size, and an unbounded failed run rescans
            # the whole tail; over the 47 KB application region that does not
            # finish.  Real basic blocks between reconnection points are
            # short, so a cap costs nothing and bounds the sweep.
            run, a, ok = [], g, False
            while (valid(a) and not visited[a - START]
                   and a - g < MAX_RUN):
                if is_data(a):
                    break            # ran into a known table: reject the run
                try:
                    ins = next(md.disasm(rom[a - BASE:a - BASE + 10], a, count=1))
                except StopIteration:
                    break
                if ins.size == 0 or a + ins.size > END:
                    break
                if any(is_data(x) for x in range(a, a + ins.size)):
                    break
                if is_padding(rom, a):
                    break
                # Same overlap rule as the descent: the while-condition only
                # tests the START byte, so a 4-byte decode can straddle into
                # bytes already claimed and hide a known boundary.
                if any(visited[a - START + i] for i in range(ins.size)):
                    break
                run.append(ins)
                a += ins.size
                if ins.mnemonic.lower() in TERMINAL:
                    ok = True
                    break
            else:
                # Fell out because we reached visited bytes -- only valid if we
                # landed on an instruction boundary, not inside one.
                ok = valid(a) and a in code
            if not ok or not run:
                continue
            for ins in run:
                for i in range(ins.size):
                    visited[ins.address - START + i] = 1
                code[ins.address] = ins
                gained += ins.size
        recovered += gained
        if not gained:
            break
    return recovered


def main():
    rom = open(ROM_PATH, "rb").read()
    seeds, names = seed_set(rom)
    calls = scan_calls(rom)
    print(f"call-target seeds: {len(calls)}  (entry-point seeds: {len(seeds)})")
    ptrs = scan_pointer_tables(rom)
    print(f"pointer-table seeds: {len(ptrs)}")
    code, visited = decode(rom, seeds | calls | ptrs)
    rec = recover_gaps(rom, code, visited)
    print(f"gap recovery : +{rec} bytes")

    # Any address that is branched to gets a label, so the listing is navigable.
    labels = dict(names)
    for ins in code.values():
        for tok in ins.op_str.replace(",", " ").split():
            tok = tok.strip("#$()").rstrip(".lwbLWB")
            try:
                t = int(tok, 16)
            except ValueError:
                continue
            if t in code and t not in labels:
                labels[t] = f"loc_{t:06X}"

    nbytes = sum(visited)
    total = END - START
    with open(OUT_PATH, "w") as f:
        f.write("; FPS-3000 RMS68K kernel disassembly\n")
        f.write(f"; ROM     : {ROM_PATH}\n")
        f.write(f"; Range   : 0x{START:06X}-0x{END-1:06X}  ({total} bytes)\n")
        f.write(f"; Method  : recursive descent seeded from the TRAP #0 jump\n")
        f.write(f";           table at 0x{TRAP0_TABLE:06X} + exception vectors\n")
        f.write(f"; Coverage: {nbytes}/{total} bytes as code  "
                f"({100.0*nbytes/total:.1f}%)\n")
        f.write(f"; Instructions: {len(code)}   Labels: {len(labels)}\n\n")

        a = START
        while a < END:
            if a in code:
                ins = code[a]
                if a in labels:
                    f.write(f"\n{labels[a]}:\n")
                raw = " ".join(f"{b:02x}" for b in ins.bytes)
                f.write(f"  {a:06x}: {raw:<24} {ins.mnemonic:<8} {ins.op_str}\n")
                a += ins.size
            else:
                # Emit undecoded bytes as aligned words so the listing never
                # drifts off even boundaries.
                w = struct.unpack(">H", rom[a - BASE:a - BASE + 2])[0]
                f.write(f"  {a:06x}: {w>>8:02x} {w&0xFF:02x}"
                        f"                    DC.W     ${w:04x}\n")
                a += 2

    print(f"coverage : {100.0*nbytes/total:.1f}%   ({nbytes}/{total} bytes)")
    print(f"insns    : {len(code)}")
    print(f"labels   : {len(labels)}")
    print(f"seeds    : {len(seeds)}")
    print(f"output   : {OUT_PATH}")


if __name__ == "__main__":
    main()
