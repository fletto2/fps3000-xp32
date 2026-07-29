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
x = 0
for i in range(0, len(d), 2): x ^= (d[i] << 8) | d[i+1]
check('image XORs to zero (final word is an XOR checksum)', x == 0, f'${x:04X}')
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
# XP4I lacks the second command-port constant that ch1-3 have
import struct as _s
for port, want in [(0xFF004E,2),(0xFF006E,2),(0xFF008E,2),(0xFF00AE,1)]:
    pat = _s.pack('>I', port)
    n = sum(1 for i in range(len(d)-3) if d[i:i+4] == pat)
    check(f'${port:06X} appears {want}x (XP4I lacks the trigger site)', n == want, n)
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
    # --- XP template diff at exact TDTI bounds ---------------------------
    xp = {n: d[b-B:b-B+0xA00] for n, b in
          [('1',0xF07D00),('2',0xF07300),('3',0xF06900),('4',0xF05F00)]}
    check('XP1I/2/3 differ in exactly 77 bytes (template + constant patches)',
          sum(1 for i in range(0xA00)
              if len({xp[n][i] for n in '123'}) > 1) == 77)
    check('$105E presence gate: each task tests its own channel number',
          all(struct.unpack('>HHI', xp[n][0xF6:0xFE]) == (0x0C79, int(n), 0x105E)
              for n in '1234'))
    check('$105E is written by the CPU at $F0A224 (a channel-present count)',
          d[0xA224:0xA22A].hex().upper() == '33C10000105E' and
          [struct.unpack('>H', d[0xA204+i:0xA206+i])[0] for i in (0,8,16,24)]
          == [0x3028]*4 and
          [struct.unpack('>H', d[0xA206+i:0xA208+i])[0] for i in (0,8,16,24)]
          == [0x4E,0x6E,0x8E,0xAE])

    check('XP4I has the $8020 XLTR MODE1 write the others lack',
          xp['4'][0x105:0x10C].hex().upper() == 'A43B7C80200202' and
          all(xp[n][0x105:0x10C].hex().upper() != 'A43B7C80200202' for n in '123'))
    check('XP4I lacks the 18-byte load-and-fire block',
          xp['1'][0x1BE:0x1D0].hex().upper() ==
          '6714207C00FF004E32BC0000337C001B0002' and
          [xp[n].count(bytes([0x20,0x7c,0,0xff,0,c])) for n, c in
           zip('1234', (0x4E,0x6E,0x8E,0xAE))] == [2,2,2,1] and
          [xp[n].count(bytes.fromhex('30BC8000')) for n in '1234'] == [1,1,1,0])

    # --- panel failure codes are directive-indexed, not per-channel -------
    def codes(lo, hi):
        c = []
        for a in range(lo, hi, 2):
            if struct.unpack('>H', d[a-B:a-B+2])[0] == 0x303C:
                v = struct.unpack('>H', d[a-B+2:a-B+4])[0]
                if 0x258 <= v <= 0x2FF: c.append(v)
        return sorted(c)
    xpc = [codes(lo, hi) for lo, hi in
           [(0xF07D00,0xF086FF),(0xF07300,0xF07CFF),
            (0xF06900,0xF072FF),(0xF05F00,0xF068FF)]]
    check('all four XP tasks emit an identical panel-code multiset',
          xpc[0] == xpc[1] == xpc[2] == xpc[3] and len(xpc[0]) == 25)
    check('$26F appears in no task (the per-channel block is not a block)',
          all(0x26F not in c for c in xpc))
    check('XP prologue: directive $01->$26D, $2D->$26E, $4C->$270',
          [(struct.unpack('>H', d[m-B:m-B+2])[0] & 0xFF,
            struct.unpack('>H', d[t2-B+6:t2-B+8])[0])
           for m, t2 in [(0xF07D4A,0xF07D52),(0xF07DD6,0xF07DDE)]]
          == [(0x01,0x26D),(0x4C,0x270)])

    # --- TDTI table: entry points and exact region extents ---------------
    TDTI = [('RDHC',0xF046F0,0xF04600,0xF05CFF),('IO1I',0xF05D36,0xF05D00,0xF05EFF),
            ('XP4I',0xF05F4A,0xF05F00,0xF068FF),('XP3I',0xF0694A,0xF06900,0xF072FF),
            ('XP2I',0xF0734A,0xF07300,0xF07CFF),('XP1I',0xF07D4A,0xF07D00,0xF086FF)]
    def tdti(i):
        o = 0xA600 + i*0x60
        return (d[o+4:o+8].decode(), struct.unpack('>I', d[o+0x1C:o+0x20])[0],
                struct.unpack('>H', d[o+0x20:o+0x22])[0] << 8,
                (struct.unpack('>H', d[o+0x22:o+0x24])[0] << 8) | 0xFF)
    check('TDTI: name, entry point and region extent for all 6 tasks',
          [tdti(i) for i in range(6)] == TDTI)
    check('TDTI regions partition $F04600-$F086FF with no gaps',
          all(TDTI[i][3] + 1 == TDTI[i+1][2] for i in range(5)))
    check('TDTI: all four XP tasks are $A00 bytes, entry at base+$4A',
          all(hi - lo + 1 == 0xA00 and e - lo == 0x4A
              for n, e, lo, hi in TDTI if n.startswith('XP')))

    # --- TCB headers: the ROM's own vector-to-task declaration -----------
    TCB = [(0xF04600,b'RDHC',0x41,0xF04930),(0xF05D00,b'IO1I',0x4A,0xF05DD6),
           (0xF05F00,b'XP4I',0x48,0xF060CE),(0xF06900,b'XP3I',0x47,0xF06AE6),
           (0xF07300,b'XP2I',0x46,0xF074E6),(0xF07D00,b'XP1I',0x45,0xF07EE6)]
    check('TCB headers: name/vector/handler at +$00/+$08/+$0C',
          all(d[b-B:b-B+4] == nm and
              struct.unpack('>I', d[b-B+8:b-B+12])[0] == vec and
              struct.unpack('>I', d[b-B+12:b-B+16])[0] == h
              for b, nm, vec, h in TCB))
    check('TCB vector numbers match the BIM vector registers',
          sorted(v for _,_,v,_ in TCB) == [0x41,0x45,0x46,0x47,0x48,0x4A])
    check('four BIM vectors are programmed but belong to no TCB',
          not ({0x42,0x43,0x44,0x49} & {v for _,_,v,_ in TCB}))
    check('BIM vector registers hold the contiguous block $41-$4A',
          sorted(struct.unpack('>H', d[i+2:i+4])[0]
                 for i in range(0xA18E, 0xA1CA, 6)) == list(range(0x41, 0x4B)))
    check("TDTI '!TCB' marker is at $F0A600, not $F0A57E",
          d[0xA5FE:0xA60A] == b'\x00\x00!TCBRDHC\x00\x00')

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
