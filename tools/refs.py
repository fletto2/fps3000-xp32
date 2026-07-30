#!/usr/bin/env python3
"""Enumerate every reference to an address, from the DISASSEMBLER'S OWN operand text.

Six times in one session I hand-decoded 68000 opcodes to find references and six
times the decoder was too narrow -- wrong addressing mode, wrong source operand,
wrong instruction form, data mistaken for code.  The disassembler has already
solved that problem correctly.  This parses its output instead.

A reference is classified by which side of the comma it sits on:
  R   the address is the SOURCE operand
  W   the address is the DESTINATION operand
  RMW single-operand read-modify-write (bset/bclr/addq/clr/not/neg/...)
  T   a test (tst/cmpi/btst) -- a read whose value is only compared
"""
import re, sys, json

ASM = 'fps3k.asm'
RMW = ('bset','bclr','bchg','addq','subq','not','neg','clr','ori','andi','eori','addi','subi')
TST = ('tst','cmpi','cmp','btst')

def load(asm=ASM):
    out, base = [], {}
    for line in open(asm):
        m = re.match(r'\s+f0([0-9a-f]{4}): ((?:[0-9a-f]{2} )+)\s+(\S+)\s*(.*)', line)
        if not m:
            continue
        pc = 0xF00000 | int(m.group(1), 16)
        mn = m.group(3)
        ops = re.sub(r'\s*\[[^\]]*\]', '', m.group(4)).strip()   # drop [SYMBOL]
        if mn.startswith('DC.W'):
            out.append((pc, mn, ops, 'DATA')); continue
        out.append((pc, mn, ops, 'CODE'))
    return out

def refs(target, asm=ASM):
    """All references to `target`, as (pc, mnemonic, kind, operands)."""
    rows, base, res = load(asm), {}, []
    for pc, mn, ops, k in rows:
        if k == 'DATA':
            continue
        s = re.search(r'(?:lea\.l|movea\.[lw])\s+#?\$([0-9a-f]+)(?:\.[lw])?\s*,\s*a([0-7])', mn+' '+ops, re.I)
        if s:
            base[int(s.group(2))] = int(s.group(1), 16); continue
        if re.match(r'(rts|rte|jmp|bra)', mn):
            base.clear()
        if mn.startswith(('lea','pea')):
            continue                                  # computes, accesses nothing
        # every operand form that can name `target`
        found = []
        for mm in re.finditer(r'(-?)\$([0-9a-f]{1,6})(?:\.[lw])?(?:\((a[0-7])\))?', ops, re.I):
            sign, hexv, reg = mm.group(1), mm.group(2), mm.group(3)
            if reg:
                rn = int(reg[1])
                if rn not in base: continue
                off = int(hexv, 16); off = -off if sign == '-' else off
                addr = base[rn] + off
            else:
                addr = int(hexv, 16)
                if addr < 0x400 and '#' in ops.split(',')[0]: continue   # immediate
            if addr == target:
                found.append(mm.span()[0])
        if not found:
            continue
        comma = ops.rfind(',')
        for pos in found:
            if mn.startswith(TST):   kind = 'T'
            elif mn.startswith(RMW) and comma < 0: kind = 'RMW'
            elif comma >= 0 and pos > comma: kind = 'W'
            elif mn.startswith(RMW): kind = 'RMW'
            else: kind = 'R'
            res.append((pc, mn, kind, ops))
    return res

if __name__ == '__main__':
    t = int(sys.argv[1], 16)
    r = refs(t)
    print(f"${t:06X}: {len(r)} reference(s)")
    for pc, mn, k, ops in r:
        print(f"   ${pc:06X}  [{k:3}] {mn:12} {ops}")
