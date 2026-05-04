#!/usr/bin/env python3
"""
Careful 68000 disassembler for the FPS-3000 custom code section.

ROM:    FPS3K_U11_U12_JOIN.bin (64 KB, MD5 47f133c1c2bab61f887e7e2a92a43dac)
Base:   0xF00000
Custom: 0xF04488 .. 0xF0FFFF  (37 KB application)

Heuristics applied (per super68k/HEURISTIC_GUIDE.md + HEURISTICS.md):
  - Reference scan: BSR/JSR/Bcc/JMP(d16,PC), JSR/JMP abs.L, even abs.L
    pointers in ROM range, plus the 256-byte vector table.
  - Recursive descent from known entries + all in-range references.
  - Iterative convergence: each pass picks up refs revealed by last pass.
  - Address coherence: only follow targets in the legal map.
  - Data protection: known data ranges (TCBDefinitionTable etc.) are
    pre-marked as DATA so they aren't walked as code.
  - Branch-target block splitting: visited[] is byte-precise so a fresh
    decode can't overlap an already-decoded instruction's interior.
"""

import os, sys, struct
from collections import defaultdict

try:
    from capstone import Cs, CS_ARCH_M68K, CS_MODE_M68K_000
    from capstone.m68k import (
        M68K_OP_IMM, M68K_OP_BR_DISP, M68K_OP_MEM,
        M68K_INS_RTS, M68K_INS_RTE, M68K_INS_RTR, M68K_INS_RTD,
        M68K_INS_JMP, M68K_INS_BRA, M68K_INS_BSR, M68K_INS_JSR,
        M68K_INS_TRAP, M68K_INS_STOP, M68K_INS_ILLEGAL,
        M68K_INS_LINK, M68K_INS_UNLK,
    )
except ImportError:
    sys.exit("install capstone: pip install --user capstone")

ROM_PATH = "/home/fletto/ext/src/claude/fps3000/FPS3K_U11_U12_JOIN.bin"
BASE     = 0xF00000
START    = 0xF04488
END      = 0xF10000
OUT_PATH = "/home/fletto/ext/src/claude/fps3000/fps3k_custom.asm"

# ----------------------------------------------------------------------
# Address-space map (for coherence validation)
# ----------------------------------------------------------------------
def is_valid_target(addr):
    """Is `addr` a legal in-ROM code target?"""
    return START <= addr < END and (addr & 1) == 0

def is_valid_data_ref(addr):
    """Is `addr` a legal data reference (RAM or ROM)?"""
    if 0x000000 <= addr < 0x020000: return True   # 128 K DRAM
    if 0xF00000 <= addr < 0xF10000: return True   # ROM
    if 0xF70000 <= addr < 0xF80000: return True   # PTM/UART/status
    if 0xFF0000 <= addr < 0xFF8000: return True   # panel I/O
    return False

# ----------------------------------------------------------------------
# Known symbols (carried over from the prior versabus annotation pass)
# ----------------------------------------------------------------------
NAMED = {
    0xF046F0: "TCBRDHC_Entry",
    0xF04730: "TCBRDHC_MainLoop",
    0xF051A2: "SRecordDataHandler",
    0xF05256: "SRecordFinalize",
    0xF05688: "PanelIOConfigure_25A",
    0xF05D00: "TCBIO1I_Data",
    0xF05D14: "TCBIO1I_CRTCBParams",
    0xF05D36: "TCBIO1I_Entry",
    0xF05DD6: "TCBIO1I_ASQHandler",
    0xF05E4C: "TCBIO1I_ISRExit",
    0xF05F00: "TCBXP4I_Data",
    0xF05F14: "TCBXP4I_CRTCBParams",
    0xF05F4A: "TCBXP4I_Entry",
    0xF060CE: "TCBXP4I_MainEntry",
    0xF060F0: "TCBXP4I_ISRExit",
    0xF06914: "TCBXP3I_CRTCBParams",
    0xF07D00: "TCBXP1I_Data",
    0xF08700: "MainInit",
    0xF08902: "BusAddressErrorHandler",
    0xF0891C: "PollBoardStatus",
    0xF08A5C: "HardwareInit",
    0xF08D5E: "RAMAddressingTest",
    0xF08DF8: "ROMChecksumTest",
    0xF08EAC: "MemBusProbe",
    0xF08F72: "IOChannelDiagnostic",
    0xF09176: "PTMInit",
    0xF0919C: "PanelBusDiagnostic",
    0xF098EE: "ROMChecksum_XOR",
    0xF09C00: "ResetEntry",
    0xF09C06: "Phase2Init",          # MainInit jumps here after hw_init succeeds
    0xF09C96: "VCTScanSetup",        # loads scan area pointer for !VCT search
    # ---- Recovered from Monte-Carlo annotation pass (R1-R5) ----
    0xF056BA: "PanelSendAndWait",    # canonical send-cmd + wait kernel
    0xF05BA4: "PanelStatusDispatch", # 256-entry × 4-byte dispatcher (data, not code)
    0xF05C4C: "PanelErrorMaskTable", # error-code → IRQ-mask-bit lookup (16-byte LUT)
    0xF068A8: "PanelTimeoutAbortPath", # abort subroutine called on cmd timeout
    0xF05230: "SRecordParseLoop",
    0xF04600: "TCBLookupTable",
    0xF04614: "TCBDefEntry_RDHC",
    0xF046BC: "TCBDefEntry_STCK",
    0xF046D4: "TCBDefEntry_UPGM",
    0xF050F8: "ChannelConfigDispatch",  # mode-state-machine target
    0xF048D8: "TCBRDHC_ErrorPath",      # bit 7 of $E87 set → branched here
    # ---- RMS68K kernel data-structure init routines (each writes a !XXX tag) ----
    0xF09E88: "Init_GST_StoreTag",   # MOVE.L #'!GST', (A0) — Global System Table
    0xF09ECE: "Init_UST_StoreTag",   # MOVE.L #'!UST', (A0) — User System Table
    0xF09F52: "Init_IOV_StoreTag",   # MOVE.L #'!IOV', (A0) — I/O Vector
    0xF09F80: "Init_IDV_StoreTag",   # MOVE.L #'!IDV', (A0) — Interrupt Descriptor Vector
    0xF09FB2: "Init_PAT_StoreTag",   # MOVE.L #'!PAT', (A0) — pattern table
    0xF0A000: "Init_UDR_StoreTag",   # MOVE.L #'!UDR', (A0) — User Driver record
    0xF0A04E: "RTOSKernelInit",
    0xF0A332: "MemoryClear",
    0xF0A57E: "TCBDefinitionTable",
}

# Pre-known DATA regions — never walk these as code.
# - TCBDefinitionTable starts with hand-decoded error-dispatch code (visible
#   in prior analysis) followed by an 80-byte gap and 6×96B TCB entries
#   ("!TCB"+"RDHC"/"IO1I"/"XP[1-4]I"+config+"PROG" terminator). Total ~0xC00.
# - Trailing data tables and padding fill the rest of ROM to F10000.
DATA_RANGES = [
    (0xF0A57E, 0xF0B17E, "TCBDefinitionTable + 6×96B TCB entries"),
    (0xF0B17E, 0xF10000, "Trailing data tables / padding"),
]

# ----------------------------------------------------------------------
# Reference scan
# ----------------------------------------------------------------------
def scan_references(rom):
    """Return set of in-range absolute targets found in the ROM image.

    Detects:
      - vector table entries (file offsets 0..0xFC, 4-byte big-endian)
      - BSR.B / Bcc.B (0x6Xxx, displacement != 0/FF)
      - BSR.W / Bcc.W (0x6X00 + i16)
      - BRA.B / BRA.W
      - JSR/JMP (d16,PC) (0x4EBA / 0x4EFA + i16)
      - JSR/JMP abs.L     (0x4EB9 / 0x4EF9 + i32)
      - any 4-byte big-endian word at even offset whose value lies inside
        [START, END) and is even (absolute pointer table heuristic)
    """
    refs = set()

    # Vector table at 0..0xFF (lives in kernel region but vectors point here).
    for off in range(0, 0x100, 4):
        v = struct.unpack(">I", rom[off:off+4])[0]
        v &= 0x00FFFFFF  # 24-bit address bus
        if is_valid_target(v):
            refs.add(v)

    # Walk every even offset.
    n = len(rom)
    for off in range(0, n - 1, 2):
        w = (rom[off] << 8) | rom[off + 1]
        op_hi = w >> 8

        # 0x6X — BRA/BSR/Bcc family
        if 0x60 <= op_hi <= 0x6F:
            disp8 = w & 0xFF
            if disp8 == 0x00 and off + 4 <= n:           # 16-bit disp
                d16 = struct.unpack(">h", rom[off+2:off+4])[0]
                tgt = BASE + off + 2 + d16
                if is_valid_target(tgt): refs.add(tgt)
            elif disp8 != 0xFF:                           # 8-bit disp
                d8 = struct.unpack(">b", bytes([disp8]))[0]
                tgt = BASE + off + 2 + d8
                if is_valid_target(tgt): refs.add(tgt)

        # 0x4EBA / 0x4EFA — JSR/JMP (d16,PC)
        elif w in (0x4EBA, 0x4EFA) and off + 4 <= n:
            d16 = struct.unpack(">h", rom[off+2:off+4])[0]
            tgt = BASE + off + 2 + d16
            if is_valid_target(tgt): refs.add(tgt)

        # 0x4EB9 / 0x4EF9 — JSR/JMP abs.L
        elif w in (0x4EB9, 0x4EF9) and off + 6 <= n:
            v = struct.unpack(">I", rom[off+2:off+6])[0] & 0x00FFFFFF
            if is_valid_target(v): refs.add(v)

        # NB: the unrestricted "any abs.L pointer in ROM range" heuristic
        # (Tier 3, 97.8% precision per super68k/HEURISTIC_GUIDE.md) is
        # intentionally NOT applied — it pulls in junk targets from data
        # tables and pollutes the recursive descent. We rely on Tier 1+2
        # (BSR/JSR + Bcc/JMP) only, which gives ~99.5%+ precision.

    return refs

# ----------------------------------------------------------------------
# Recursive-descent decode
# ----------------------------------------------------------------------
def decode(rom, seeds, data_mask, priority_seeds=None):
    md = Cs(CS_ARCH_M68K, CS_MODE_M68K_000)
    md.detail = True

    code = {}                 # addr -> (size, mnemonic, op_str, raw, target)
    visited = bytearray(END - START)  # 1 byte per ROM byte; 1 = decoded
    # Priority seeds processed first (LIFO via pop), so add them LAST.
    priority_seeds = priority_seeds or set()
    queue = list(seeds - priority_seeds) + list(priority_seeds)
    new_targets = set()

    def in_data(a, sz=2):
        for i in range(sz):
            if data_mask[a - START + i]:
                return True
        return False

    def already_visited(a, sz):
        for i in range(sz):
            if visited[a - START + i]:
                return True
        return False

    def mark_visited(a, sz):
        for i in range(sz):
            visited[a - START + i] = 1

    def disas_one(addr):
        off = addr - BASE
        chunk = rom[off:off+10]
        try:
            return next(md.disasm(chunk, addr, count=1))
        except StopIteration:
            return None

    while queue:
        addr = queue.pop()
        if not is_valid_target(addr):
            continue
        # Walk straight-line.
        while is_valid_target(addr):
            if in_data(addr):
                break
            if already_visited(addr, 1):
                break
            insn = disas_one(addr)
            if insn is None or insn.size == 0:
                break
            if already_visited(addr + 1, insn.size - 1):
                # Would overlap an existing instruction's interior.
                break
            if any(data_mask[addr - START + i] for i in range(insn.size)):
                break

            mark_visited(addr, insn.size)

            mnem  = insn.mnemonic.lower()
            opstr = insn.op_str
            raw   = bytes(insn.bytes)
            ins_id = insn.id

            # Find a target if the instruction has one.
            target = None

            # Capstone gives us operand objects; honor BR_DISP first (the
            # branch's resolved absolute target on m68k). Some Capstone
            # versions raise on .operands for unrecognized opcodes; ignore.
            try:
                ops_list = insn.operands
            except Exception:
                ops_list = ()
            for op in ops_list:
                try:
                    if op.type == M68K_OP_BR_DISP:
                        target = (addr + 2 + op.br_disp.disp) & 0xFFFFFFFF
                        break
                except Exception:
                    pass

            # JMP / JSR with absolute or PC-relative immediate.
            # Capstone emits hex literals as either "$XXX" or "0xXXX".
            if target is None:
                cleaned = opstr.replace(",", " ").replace("(", " ").replace(")", " ")
                for tok in cleaned.split():
                    t = tok.strip().rstrip(".lwLWbB").lstrip("#")
                    if t.startswith("$"):
                        t = t[1:]
                        is_hex = True
                    elif t.startswith("0x") or t.startswith("0X"):
                        t = t[2:]
                        is_hex = True
                    else:
                        is_hex = False
                    if is_hex and t:
                        try:
                            v = int(t, 16) & 0x00FFFFFF
                        except ValueError:
                            continue
                        if is_valid_target(v):
                            target = v
                            break

            code[addr] = (insn.size, mnem, opstr, raw, target)

            # Flow control.
            stops = False
            if ins_id in (M68K_INS_RTS, M68K_INS_RTE, M68K_INS_RTR, M68K_INS_RTD):
                stops = True
            elif ins_id == M68K_INS_JMP:
                if target is not None and is_valid_target(target):
                    queue.append(target); new_targets.add(target)
                stops = True
            elif ins_id == M68K_INS_BRA:
                if target is not None and is_valid_target(target):
                    queue.append(target); new_targets.add(target)
                stops = True
            elif ins_id in (M68K_INS_BSR, M68K_INS_JSR):
                if target is not None and is_valid_target(target):
                    queue.append(target); new_targets.add(target)
            elif ins_id == M68K_INS_TRAP:
                # RMS68K convention: directives return to next instruction
                # on success and skip-one-word on error. Queue both paths.
                err_path = addr + insn.size + 2
                if is_valid_target(err_path):
                    queue.append(err_path); new_targets.add(err_path)
            elif ins_id == M68K_INS_ILLEGAL:
                stops = True
            else:
                # conditional branches: mnem starts with 'b' but isn't bset/bclr/bchg/btst/bra
                if mnem.startswith("b") and mnem not in ("bset", "bclr", "bchg", "btst", "bra"):
                    if target is not None and is_valid_target(target):
                        queue.append(target); new_targets.add(target)

            if stops:
                break
            addr += insn.size

    return code, visited, new_targets

# ----------------------------------------------------------------------
# Driver
# ----------------------------------------------------------------------
def main():
    with open(ROM_PATH, "rb") as f:
        rom = f.read()
    assert len(rom) == 0x10000

    # Pre-mark data ranges.
    data_mask = bytearray(END - START)
    for lo, hi, _ in DATA_RANGES:
        for a in range(max(lo, START), min(hi, END)):
            data_mask[a - START] = 1

    # Seed in two tiers:
    #   tier-A = named entries + reset vector — processed FIRST so they
    #            claim their own bytes before any wandering linear decode.
    #   tier-B = scan_references() (BSR/JSR/Bcc/JMP targets, vectors).
    rv = struct.unpack(">I", rom[4:8])[0] & 0x00FFFFFF
    tier_a = set(a for a in NAMED if is_valid_target(a))
    if is_valid_target(rv):
        tier_a.add(rv)
    tier_b = scan_references(rom) - tier_a
    seeds = tier_a | tier_b

    print(f"initial seeds: {len(seeds)}  (tier-A={len(tier_a)}, tier-B={len(tier_b)})")

    # Iterative convergence loop: re-scan op_str for new in-range targets
    # after each decode, requeue, repeat until stable.
    code = {}
    visited = bytearray(END - START)
    iteration = 0
    while True:
        iteration += 1
        new_code, new_visited, new_targets = decode(rom, seeds, data_mask,
                                                     priority_seeds=tier_a)
        added = 0
        for a, v in new_code.items():
            if a not in code:
                code[a] = v
                added += 1
        for i in range(len(visited)):
            if new_visited[i]:
                visited[i] = 1
        # Mine decoded instructions for targets we hadn't seeded.
        more = set()
        for a, (sz, mnem, ops, raw, tgt) in code.items():
            if tgt is not None and is_valid_target(tgt) and tgt not in seeds:
                more.add(tgt)
        print(f"iter {iteration}: +{added} insns (total {len(code)}), "
              f"+{len(more)} new seeds")
        if not more:
            break
        seeds |= more
        if iteration > 8:
            break

    # Build the set of all referenced in-range targets (for label emission).
    referenced = set()
    for a, (sz, mnem, ops, raw, tgt) in code.items():
        if tgt is not None and is_valid_target(tgt):
            referenced.add(tgt)
    referenced |= set(NAMED.keys())

    def labelfor(a):
        if a in NAMED: return NAMED[a]
        return f"loc_{a:06X}"

    # Emit
    decoded_bytes = sum(sz for (sz,_,_,_,_) in code.values())
    total = END - START
    pct = 100.0 * decoded_bytes / total

    with open(OUT_PATH, "w") as f:
        f.write(f"; FPS-3000 custom code disassembly\n")
        f.write(f"; ROM    : {os.path.basename(ROM_PATH)}\n")
        f.write(f"; Base   : 0x{BASE:06X}\n")
        f.write(f"; Range  : 0x{START:06X}-0x{END-1:06X}  ({total} bytes)\n")
        f.write(f"; Method : recursive-descent + reference scan + convergence loop\n")
        f.write(f"; Coverage: {decoded_bytes}/{total} bytes as code  ({pct:.1f}%)\n")
        f.write(f"; Instructions decoded: {len(code)}\n")
        for lo, hi, why in DATA_RANGES:
            f.write(f"; DATA   : 0x{lo:06X}-0x{hi:06X}  {why}\n")
        f.write("\n")
        f.write("; ============================================================\n")
        f.write("; RMS68K marker tags (4-byte ASCII signatures used by kernel)\n")
        f.write("; ============================================================\n")
        f.write(';   !TCB  Task Control Block               (multiple sites in tables)\n')
        f.write(';   !CCB  Channel Control Block            (0xF03EF0)\n')
        f.write(';   !ASQ  Application Status Queue         (multiple sites)\n')
        f.write(';   !TST  Task Status / Test record        (0xF0298C)\n')
        f.write(';   !DLY  Delay record                     (0xF02D9A)\n')
        f.write(';   !VCT  Vector / config table            (0xF09C9C, 0xF0011A)\n')
        f.write(';   !GST  Global System Table              (0xF09E8A)\n')
        f.write(';   !UST  User System Table                (0xF09ED0)\n')
        f.write(';   !IOV  I/O Vector                       (0xF09F54)\n')
        f.write(';   !IDV  Interrupt Descriptor Vector      (0xF09F82)\n')
        f.write(';   !PAT  Pattern table                    (0xF09FB4)\n')
        f.write(';   !UDR  User Driver record               (0xF0A002)\n')
        f.write(";\n")
        f.write("; 4-letter context tags found in TCB / dispatch tables\n")
        f.write(';   "EXEC"  Executive identifier\n')
        f.write(';   "USER"  User-context identifier\n')
        f.write(';   "STCK"  Stack-context identifier\n')
        f.write(';   "UPGM"  User Program identifier\n')
        f.write(';   "PROG"  TCB terminator (end of TCB record)\n')
        f.write(';   "RDHC"  Master/dispatch task name        (TCBRDHC)\n')
        f.write(';   "IO1I"  Host I/O channel task name       (TCBIO1I)\n')
        f.write(';   "XP1I".."XP4I"  XP-32 channel 1-4 task names (TCBXP1I..4I)\n')
        f.write(';   "AS0f".."AS3f"  Application-Specific function tables\n')
        f.write("\n")

        addr = START
        while addr < END:
            # Section banner for known names.
            if addr in NAMED:
                f.write(f"\n; ============================================================\n")
                f.write(f"; {NAMED[addr]}\n")
                f.write(f"; ============================================================\n")
                f.write(f"{NAMED[addr]}:\n")
            elif addr in referenced and addr in code:
                f.write(f"\n{labelfor(addr)}:\n")
            elif addr in referenced and not (addr in code) and not data_mask[addr - START]:
                # Reference into data — still emit a label.
                f.write(f"\n{labelfor(addr)}:\n")

            if addr in code:
                sz, mnem, ops, raw, tgt = code[addr]
                bytestr = " ".join(f"{b:02x}" for b in raw)
                if tgt is not None and is_valid_target(tgt):
                    name  = labelfor(tgt)
                    for fmt in (f"0x{tgt:x}", f"0x{tgt:X}",
                                f"${tgt:x}", f"${tgt:X}"):
                        if fmt in ops:
                            ops = ops.replace(fmt, name)
                            break
                f.write(f"{addr:06X}  {bytestr:<22}  {mnem:8} {ops}\n")
                addr += sz
            else:
                off = addr - BASE
                if data_mask[addr - START]:
                    # Known data table — emit as DC.W in bursts.
                    if off + 2 <= len(rom):
                        w = struct.unpack(">H", rom[off:off+2])[0]
                        f.write(f"{addr:06X}  {w>>8:02x} {w&0xff:02x}                   DC.W     0x{w:04x}\n")
                        addr += 2
                    else:
                        addr += 1
                else:
                    if off + 2 <= len(rom):
                        w = struct.unpack(">H", rom[off:off+2])[0]
                        # If the word happens to be ASCII pair, annotate.
                        annot = ""
                        b1, b2 = w >> 8, w & 0xff
                        if 0x20 <= b1 < 0x7f and 0x20 <= b2 < 0x7f:
                            annot = f"  ; '{chr(b1)}{chr(b2)}'"
                        f.write(f"{addr:06X}  {b1:02x} {b2:02x}                   DC.W     0x{w:04x}{annot}\n")
                        addr += 2
                    else:
                        addr += 1

    print(f"\ncoverage : {pct:.1f}%   ({decoded_bytes}/{total} bytes)")
    print(f"insns    : {len(code)}")
    print(f"labels   : {len(referenced)}")
    print(f"output   : {OUT_PATH}")

if __name__ == "__main__":
    main()
