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
OUT_PATH = "fps3k_kernel.asm"
BASE, START, END = 0xF00000, 0xF00000, 0xF04488

# The TRAP #0 directive jump table.  35 longword slots; slot 0 and slot $20
# both hold the error return, so there are 34 distinct entry points.
TRAP0_TABLE, TRAP0_N = 0xF001D6, 35

# The five directives this firmware actually issues, from TR1.EQ/STR.EQ.
DIRECTIVE_NAMES = {
    0x04: "T0PAGAL",   # allocate physical pages -- the 256-byte page allocator
    0x06: "T0GETTCB",
    0x16: "T0WAKEUP",
    0x18: "T0QEVNTI",
    0x1F: "T0CRTCB",
}


def valid(a):
    return START <= a < END and (a & 1) == 0


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
    queue = list(seeds)

    while queue:
        a = queue.pop()
        while valid(a) and not visited[a - START]:
            try:
                ins = next(md.disasm(rom[a - BASE:a - BASE + 10], a, count=1))
            except StopIteration:
                break
            if ins.size == 0 or a + ins.size > END:
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


def main():
    rom = open(ROM_PATH, "rb").read()
    seeds, names = seed_set(rom)
    calls = scan_calls(rom)
    print(f"call-target seeds: {len(calls)}  (entry-point seeds: {len(seeds)})")
    ptrs = scan_pointer_tables(rom)
    print(f"pointer-table seeds: {len(ptrs)}")
    code, visited = decode(rom, seeds | calls | ptrs)

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
