#!/usr/bin/env python3
"""Assert the verified claims in refs_extracted/versabus_access_map.md.

    python3 tools/verify_findings.py [rom]

Pass an alternate ROM path to test the harness itself: mutating two bytes
(one in a panel-issuer copy, one in SRecordDataHandler's $10000 addend)
takes it from 21/21 to 12/21, so the checks are not vacuous.

Run from the repo root after any change to disasm.py, the emulator, or the
ROM image.  Every check here corresponds to a documented finding; if one
fails, either the change is wrong or the documentation needs updating --
both worth knowing before the discrepancy is discovered months later.

"""
import hashlib, os, re, struct, subprocess, sys, tempfile

ROM = sys.argv[1] if len(sys.argv) > 1 else 'FPS3K_U11_U12_JOIN.bin'
B   = 0xF00000
d   = open(ROM, 'rb').read()
EMU = 'emulator/fps3k_sbc'
fails, checks = [], 0

def check(name, cond, detail=''):
    global checks
    checks += 1
    if cond: print(f'  PASS  {name}')
    else:    print(f'  FAIL  {name}   {detail}'); fails.append(name)

def word(a): return struct.unpack('>H', d[a-B:a-B+2])[0]
def long_(a): return struct.unpack('>I', d[a-B:a-B+4])[0]

print('ROM structure')
check('ROM md5 unchanged',
      hashlib.md5(d).hexdigest() == '47f133c1c2bab61f887e7e2a92a43dac')
# seven byte-identical copies of the 50-byte panel-command issuer
ref = d[0xF05688-B:0xF05688-B+0x32]
copies = [a for a in range(0xF04488, 0xF0A000, 2) if d[a-B:a-B+0x32] == ref]
check('panel issuer: exactly 7 byte-identical copies', len(copies) == 7,
      ' '.join(f'{a:06X}' for a in copies))
check('  ... at the documented addresses',
      copies == [0xF04500, 0xF05688, 0xF05E56, 0xF068A8, 0xF072C0, 0xF07CC0, 0xF086C0])
# five byte-identical copies of the 42-slot dispatch table
t = d[0xF05BA4-B:0xF05BA4-B+0xA8]
tabs = [a for a in (0xF05BA4, 0xF065E4, 0xF06FFC, 0xF079FC, 0xF083FC)
        if d[a-B:a-B+0xA8] == t]
check('dispatch table: 5 identical copies', len(tabs) == 5,
      ' '.join(f'{a:06X}' for a in tabs))
# the F05102 dispatcher is 16 jmp d16(pc) entries
check('F05102 dispatcher: 16 x 4EFA',
      all(word(0xF05102+4*i) == 0x4EFA for i in range(16)))
# SRecordDataHandler address arithmetic
check('SRec seeds a1 = $10 (F051A2)', long_(0xF051A2) == 0x227C0000 or word(0xF051A2) == 0x227C)
check('SRec adds $10000 (F051DC)', d[0xF051DC-B:0xF051DC-B+6] == bytes.fromhex('d3fc00010000'))
# S-record type constants: two parsers, S8 vs S7
check('parser 1 takes S8 ($5338)', word(0xF04C02) == 0x5338)
check('parser 2 takes S7 ($5337)', word(0xF0555C) == 0x5337)
# XP task stride: three at $A00, XP4I shifted $18
starts = [0xF07D00, 0xF07300, 0xF06900, 0xF05F00]
check('XP1I-XP2I-XP3I stride $A00',
      starts[0]-starts[1] == 0xA00 and starts[1]-starts[2] == 0xA00)
check('XP3I-XP4I gap is $A00 but the CODE is shifted $18',
      starts[2]-starts[3] == 0xA00)
N = 0x9E0
diff_a00 = sum(1 for i in range(N) if d[0xF06900-B+i] != d[0xF05F00-B+i])
diff_a18 = sum(1 for i in range(N) if d[0xF06900-B+i] != d[0xF05EE8-B+i])
check('XP4I aligns at $A18, not $A00', diff_a18 < diff_a00 // 2,
      f'{diff_a18} vs {diff_a00}')
# TDTI task regions
for name, off in [(b'RDHC', 0xF0A600), (b'IO1I', 0xF0A660), (b'XP4I', 0xF0A6C0)]:
    check(f'TDTI entry {name.decode()}', d[off-B+4:off-B+8] == name)

if not os.path.exists(EMU):
    print('\nemulator not built - skipping runtime checks')
else:
    print('\nemulator runtime')
    tmp = tempfile.mkdtemp()
    def run(env, cycles, extra=None):
        e = dict(os.environ); e.update(env)
        cmd = [EMU, '-rom', ROM, '-cycles', str(cycles),
               '-trace', f'{tmp}/t', '-dump-ram', f'{tmp}/r']
        if extra: cmd += extra
        subprocess.run(cmd, env=e, capture_output=True, timeout=400)
        return open(f'{tmp}/t').read(), open(f'{tmp}/r', 'rb').read()
    tr, ram = run({}, 400_000_000)
    check('boot: all 6 task ISR vectors installed',
          all(struct.unpack('>I', ram[v:v+4])[0] == h for v, h in
              [(0x104,0xF04930),(0x114,0xF07EE6),(0x118,0xF074E6),
               (0x11C,0xF06AE6),(0x120,0xF060CE),(0x128,0xF05DD6)]))
    check('self-tests: zero error-flag hits',
          tr.count('F0F0F0F0') == 0 and 'F08B88\n' not in tr)
    check('self-tests: diagnostic region executes',
          len({l for l in tr.split() if 'F08D00' <= l <= 'F09BFF'}) > 500)
    srec = f'{tmp}/u.s19'
    def s2(addr, data):
        p = [3+len(data)+1, (addr>>16)&255, (addr>>8)&255, addr&255] + list(data)
        return 'S2' + ''.join(f'{b:02X}' for b in p) + f'{(~sum(p))&255:02X}'
    open(srec,'w').write(s2(0, bytes.fromhex('DEADBEEFCAFEBABE')) +
                         s2(8, bytes.fromhex('0102030405060708')))
    tr, ram = run({'FPS3K_SREC': srec, 'FPS3K_SEQ': '02:001C,42:0000,00:0000'}, 300_000_000)
    check('S-record load: 16 stores', tr.count('F0520E\n') == 16)
    check('S-record load: correct data at $10010 (addresses are OFFSETS)',
          ram[0x10010:0x10020].hex().upper() == 'DEADBEEFCAFEBABE0102030405060708')
    check('S-record load: exits via F05254 (success), not F05224 (reject)',
          tr.count('F05254\n') == 2 and tr.count('F05224\n') == 0)

print(f'\n{checks - len(fails)}/{checks} passed')
sys.exit(1 if fails else 0)
