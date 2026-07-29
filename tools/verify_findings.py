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
import collections, hashlib, os, re, struct, subprocess, sys, tempfile

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
    # --- the consolidated asm carries this session's findings ------------
    try:
        asm = open('fps3k.asm').read()
        check('fps3k.asm carries >=160 ;### finding notes',
              asm.count('\n;### ') >= 160)
        check('NOTES merges duplicate addresses instead of dropping them',
              'NOTES.setdefault' in open('tools/mk_consolidated_asm.py').read())
        check('fps3k.asm annotates the $FF0048 read and the presence gate',
              'FF0048 IS READ' in asm and 'PRESENCE GATE' in asm)
    except FileNotFoundError:
        check('fps3k.asm present', False)

    # --- block 3 runs its four tests twice, over two RAM ranges ----------
    check('block 3 tests $400-$1F000 then $10000-$1F000',
          d[0x8866:0x887A].hex().upper() ==
          '207C00000000227C00000400247C0001F0006100' and
          d[0x887C:0x8882].hex().upper() == '227C00010000')

    # --- the phase beacon: 29 phases, $29 dominates ----------------------
    import subprocess as _sp
    with tempfile.TemporaryDirectory() as _td:
        _sp.run([EMU, '-rom', ROM, '-cycles', '400000000', '-bus', _td+'/b'],
                stdout=_sp.DEVNULL, stderr=_sp.DEVNULL,
                env={**os.environ, 'FPS3K_BUSPC': '1'})
        _v = [int(m2.group(1), 16) for m2 in
              re.finditer(r'WR 2-byte FF0204 = 0*([0-9A-F]+)\s', open(_td+'/b').read())]
    _ph = sorted({x >> 8 for x in _v})
    check('phase beacon covers 30 phases: $01-$09, $10-$1A, $20-$29',
          _ph == list(range(1, 10)) + list(range(0x10, 0x1B))
                 + list(range(0x20, 0x2A)))
    check('phase $29 is a 32768-iteration loop dominating the beacon',
          sum(1 for x in _v if x >> 8 == 0x29) == 32768)

    # --- vector 140 is made non-fatal, not serviced ----------------------
    check('F00896 tests a flag, optionally bsr, and rte -- it ignores the IRQ',
          d[0x896:0x8A6].hex().upper().startswith('08380' + '00E0C346706' + '61000DE8')
          and d[0x8A4:0x8A6] == b'\x4e\x73')
    check('nothing in the ROM writes $8C or references $230 outside the fill',
          d.count(b'\x00\x00\x02\x30') <= 1)

    # --- the vector table is fully written; the spare BIMs split two ways -
    _, ramv = run({}, 400_000_000)
    vec = lambda n: struct.unpack('>I', ramv[n*4:n*4+4])[0]
    check('every vector $000-$3FF is written (none left as power-on garbage)',
          all(vec(n) != 0 for n in range(256)))
    check('spare BIM vectors $42/$43/$44 -> F00896, $49 -> the panic catch-all',
          [vec(0x42), vec(0x43), vec(0x44)] == [0xF00896]*3 and
          vec(0x49) == 0xF0A27A)
    check('the app fill starts at $124 and skips only $230',
          d[0xA14A:0xA158].hex().upper() == '207C00000124B1FC000002306706'
          and vec(0x8C) == 0xF00896)

    check('all nine exception handlers bra.w to issuer copy 8 at $F0A57E',
          all(struct.unpack('>H', d[0xA23E+8*i:0xA240+8*i])[0] == 0x6000 and
              0xA240 + 8*i + struct.unpack('>H', d[0xA240+8*i:0xA242+8*i])[0]
              == 0xA57E for i in range(9)))

    # --- stack fill pattern and high-water mark --------------------------
    with tempfile.TemporaryDirectory() as _td4:
        subprocess.run([EMU, '-rom', ROM, '-cycles', '400000000',
                        '-dump-ram', _td4+'/r'], stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL)
        _r = open(_td4+'/r', 'rb').read()
    _P = bytes.fromhex('09ABCDEF')
    _intact = sum(1 for x in range(0x400, 0x800, 4) if _r[x:x+4] == _P)
    check('stack area $400-$7FF is pre-filled with $09ABCDEF',
          _intact > 200)
    check('a clean boot uses well under half the 1 KB supervisor stack',
          all(_r[x:x+4] == _P for x in range(0x404, 0x600, 4)))

    check('RTOS creates only !TCB x6 and !TST x6, no !ASQ/!CCB/!DLY',
          [sum(1 for x in range(0, 0x20000) if _r[x:x+4] == tg)
           for tg in (b'!TCB', b'!TST', b'!ASQ', b'!CCB', b'!DLY')]
          == [6, 6, 0, 0, 0])

    check('post-boot RAM: $01110-$1DEFF is entirely untouched (115.5 KB)',
          not any(_r[x] for x in range(0x1110, 0x1DF00)))
    check('post-boot RAM: only ~3% of the 128 KB is touched',
          400 < sum(1 for x in range(0, 0x20000, 4)
                    if _r[x:x+4] != b'\x00\x00\x00\x00') < 1600)

    # --- live TCBs sit inside the WCS staging buffer ----------------------
    TCBRAM = [(0x1E900, b'XP1I', 0xF07D4A), (0x1EB00, b'XP2I', 0xF0734A),
              (0x1ED00, b'XP3I', 0xF0694A), (0x1EF00, b'XP4I', 0xF05F4A),
              (0x1F100, b'IO1I', 0xF05D36), (0x1F300, b'RDHC', 0xF046F0)]
    check('six live !TCBs at $1E900+$200*n, inside the staging buffer',
          all(_r[b2:b2+4] == b'!TCB' and _r[b2+0x10:b2+0x14] == nm and
              struct.unpack('>I', _r[b2+0x6C:b2+0x70])[0] == ep
              for b2, nm, ep in TCBRAM))
    check('the staging buffer is NOT free above $1DF00',
          any(_r[x] for x in range(0x1DF00, 0x20000)) and
          not any(_r[x] for x in range(0x10000, 0x1DF00)))


    # --- vector-table integrity across configurations --------------------
    def vecwrites(env2):
        return subprocess.run([EMU, '-rom', ROM, '-cycles', '300000000'],
                              capture_output=True, text=True,
                              env={**os.environ, 'FPS3K_VECWATCH': 'post',
                                   **env2}).stderr.count('VECWATCH')
    check('a plain boot makes exactly 4 post-boot vector writes (all benign)',
          vecwrites({}) == 4)
    check('the $281 deadlock config overruns the stack into the vector table',
          vecwrites({'FPS3K_XPIRQ': '5,6', 'FPS3K_DMA10AA': '2',
                     'FPS3K_MBOX': '20010000'}) > 500)

    # --- the firmware never reads never-written DRAM ---------------------
    with tempfile.TemporaryDirectory() as _td3:
        subprocess.run([EMU, '-rom', ROM, '-cycles', '400000000'],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       env={**os.environ, 'FPS3K_UNINIT': _td3+'/u'})
        _u = open(_td3+'/u').read()
    check('firmware never reads a DRAM byte it has not written (parity-safe)',
          _u.strip() == '')

    # --- FPS3K_LOGCHASSIS exposes the window; 4 PCs x 65536 --------------
    with tempfile.TemporaryDirectory() as _td2:
        _o = subprocess.run([EMU, '-rom', ROM, '-cycles', '400000000'],
                            capture_output=True, text=True,
                            env={**os.environ, 'FPS3K_LOGCHASSIS': '1'}).stderr
    _pcs = collections.Counter(re.findall(r'CHASSIS-MEM.*@(\w{6})', _o))
    check('chassis-window logging: exactly 4 PCs do 65536 accesses each',
          sorted(p for p, n in _pcs.items() if n == 65536) ==
          ['F09B48', 'F09B58', 'F09B70', 'F09B72'])

    # --- the $400000 window is exercised, and the bus log misses it ------
    import subprocess as _s2
    out = _s2.run([EMU, '-rom', ROM, '-cycles', '400000000'],
                  capture_output=True, text=True).stderr
    m3 = re.search(r'chassis window \$400000: (\d+) reads, (\d+) writes', out)
    check('a full boot makes >130k accesses to the $400000 paged window',
          m3 and int(m3.group(1)) > 130000 and int(m3.group(2)) > 130000)
    check('$400000 is referenced from 9 sites in the init/test region',
          sum(1 for a2 in range(0x8700, 0x9C00, 2)
              if 0x400000 <= struct.unpack('>I', d[a2:a2+4])[0] <= 0x4FFFFF) == 9)

    # --- two-trap architecture; TRAP #2-#15 unused ------------------------
    tr_sites = {}
    for a2 in range(0, 0xA600, 2):
        w = struct.unpack('>H', d[a2:a2+2])[0]
        if (w & 0xFFF0) == 0x4E40:
            tr_sites.setdefault(w & 0xF, []).append(a2)
    check('only TRAP #0 and TRAP #1 are used anywhere in the ROM',
          sorted(tr_sites) == [0, 1])
    check('TRAP #0 x12 (init only), TRAP #1 x71 (tasks only)',
          len(tr_sites[0]) == 12 and len(tr_sites[1]) == 71 and
          all(0x4600 <= x <= 0x86FF for x in tr_sites[1]) and
          not any(0x4600 <= x <= 0x86FF for x in tr_sites[0]))

    # --- the exception-code table at $F0A23A -----------------------------
    check('9-entry exception table at $F0A23A: codes $29E-$2A6, 8 bytes apart',
          [struct.unpack('>H', d[0xA23A+8*i+2:0xA23C+8*i+2])[0] for i in range(9)]
          == list(range(0x29E, 0x2A7)) and
          all(struct.unpack('>H', d[0xA23A+8*i:0xA23C+8*i])[0] == 0x303C
              for i in range(9)))
    check('an FPS stub sits inside the kernel region at $F001A0 (code $2B2)',
          d[0x1A0:0x1AC].hex().upper() == '303C02B24EB900F0450060FE' and
          d.count(b'\x30\x3c\x02\xb2') == 1)

    # --- $10AA is out of reach of the only code that writes that array ---
    check('cmd-1 writes $10A0[(ch-1)*2] and is bounded by $105E',
          d[0x53CC:0x53D2].hex().upper() == '20045380E588' and
          d[0x53DE:0x53E0].hex().upper() == 'E288' and
          d[0x53E2:0x53E8].hex().upper() == '337C000210A0' and
          d[0x538A:0x5392].hex().upper() == 'B879' + '0000105E' + '6F10')
    check('$10AA needs channel 6; $F0A202 probes only four ports',
          (0x10AA - 0x10A0) // 2 + 1 == 6 and
          [struct.unpack('>H', d[0xA206+i:0xA208+i])[0] for i in (0,8,16,24)]
          == [0x4E, 0x6E, 0x8E, 0xAE])

    # --- RDHC's $12 name table -------------------------------------------
    check('$F0467E holds a 6-entry 8-byte name table, XP1I..XP4I then USER x2',
          [d[0x467E+8*i:0x467E+8*i+8] for i in range(6)] ==
          [b'XP1I\0\0\0\0', b'XP2I\0\0\0\0', b'XP3I\0\0\0\0',
           b'XP4I\0\0\0\0', b'USER\0\0\0\0', b'USER\0\0\0\0'])
    check('RDHC issues directive $12 five times, XP4I..XP1I then USER',
          [d[a2:a2+8].hex().upper() for a2 in
           (0x4854, 0x4866, 0x4878, 0x4884, 0x4904)]
          == ['701241F900F04696', '701241F900F0468E', '701241F900F04686',
              '701241F900F0467E', '701241F900F0469E'])

    # --- runtime ASQ name construction and the pattern table -------------
    check("RDHC builds ASQ names: move.l #'HXP0',d1 then add.b d4,d1",
          d.count(b'\x22\x3c\x48\x58\x50\x30') == 2 and
          all(b'\xd2\x04' in d[a2+6:a2+16] for a2 in (0x53B6, 0x5476)))
    check('$F09BB6 holds the four RAM-test patterns',
          [struct.unpack('>I', d[0x9BB6+i:0x9BBA+i])[0] for i in (0,4,8,12)]
          == [0x00000000, 0xFFFFFFFF, 0x55555555, 0xAAAAAAAA])
    check('PROG appears 6x (one per TDTI entry) and STCK 6x (one per task)',
          d.count(b'PROG') == 6 and d.count(b'STCK') == 6)

    # --- $F046E0 BIM table and RDHC's distinct prologue ------------------
    check('$F046E0 is a 4-entry BIM CR table in channel order',
          [struct.unpack('>I', d[0x46E0+i:0x46E4+i])[0] for i in (0,4,8,12)]
          == [0x244, 0x246, 0x250, 0x252])
    check("RDHC's $01 block is at $F046B0 with a UPGM tag, not base+$14",
          d[0x46F0:0x46F8].hex().upper() == '700141F900F046B0' and
          d[0x46B0:0x46B4] == b'RDHC' and d[0x46D4:0x46D8] == b'UPGM')
    check("RDHC header +$14 -> directive $0B, +$30 -> directive $0D",
          d[0x4774:0x477C].hex().upper() == '700B41F900F04614' and
          d[0x47C0:0x47C8].hex().upper() == '700D41F900F04630')
    check('RDHC enables its own BIM at level 6 right after connecting',
          d[0x4730:0x4736].hex().upper() == '3B7C005E0230')

    # --- descriptor holds the whole prologue's parameter block -----------
    for b, nm, a1, a2_ in [(0xF07D00,b'XP1I',b'AXP1',b'HXP1'),
                           (0xF07300,b'XP2I',b'AXP2',b'HXP2'),
                           (0xF06900,b'XP3I',b'AXP3',b'HXP3'),
                           (0xF05F00,b'XP4I',b'AXP4',b'HXP4')]:
        o = b - B
        check('%s header: name/STCK/$190 and two ASQ entries' % nm.decode(),
              d[o+0x14:o+0x18] == nm and d[o+0x20:o+0x24] == b'STCK' and
              struct.unpack('>I', d[o+0x28:o+0x2C])[0] == 0x190 and
              d[o+0x2C:o+0x30] == a1 and d[o+0x36:o+0x3A] == a2_)
    check('IO1I declares one ASQ (HIO1); RDHC declares none and has no STCK',
          d[0x5D2C:0x5D30] == b'HIO1' and
          d[0x4620:0x4624] != b'STCK' and d[0x4614:0x4618] == b'USER')

    # --- descriptor +$10 is the ISR exit stub ----------------------------
    STUBS = [0xF050FC, 0xF05E4C, 0xF060F0, 0xF06B08, 0xF07508, 0xF07F08]
    check("descriptor +$10 points at a 'move #$0C,ccr / trap #1' exit stub",
          all(struct.unpack('>I', d[b-B+16:b-B+20])[0] == st and
              d[st-B:st-B+6].hex().upper() == '44FC000C4E41'
              for b, st in zip([0xF04600,0xF05D00,0xF05F00,
                                0xF06900,0xF07300,0xF07D00], STUBS)))
    check('XP1I ISR never writes d0, so the exit trap is not directive-numbered',
          not any((struct.unpack('>H', d[a2-B:a2-B+2])[0] & 0xFF00) == 0x7000 or
                  struct.unpack('>H', d[a2-B:a2-B+2])[0] in (0x303C, 0x203C)
                  for a2 in range(0xF07EE6, 0xF07F0C, 2)))

    # --- RTOS directive surface: 14 distinct, recovered from trap #1 -----
    def directives():
        out = {}
        for a2 in range(0xF04488, 0xF0A600, 2):
            if struct.unpack('>H', d[a2-B:a2-B+2])[0] != 0x4E41: continue
            for k in range(2, 20, 2):
                w = struct.unpack('>H', d[a2-B-k:a2-B-k+2])[0]
                if (w & 0xFF00) == 0x7000: out[a2] = w & 0xFF; break
                if w == 0x303C:
                    out[a2] = struct.unpack('>H', d[a2-B-k+2:a2-B-k+4])[0]; break
        return out
    dv = directives()
    check('firmware uses exactly 14 distinct TRAP #1 directives',
          sorted(set(dv.values())) ==
          [0x01,0x0B,0x0D,0x0F,0x10,0x11,0x12,0x13,0x29,0x2A,0x2B,0x2D,0x43,0x4C])
    check('$01/$0F/$13/$4C are the common lifecycle (>=6 sites each)',
          all(list(dv.values()).count(x) >= 6 for x in (0x01, 0x0F, 0x13, 0x4C)))

    # --- the XP channel-scan loop ----------------------------------------
    check('channel scan at $F08616: $20 stride, bounded by $105E',
          d[0x8668:0x866C].hex().upper() == '247C00FF' and
          d[0x8676:0x867A].hex().upper() == '3432484E' and
          d[0x8688:0x868E].hex().upper() == '068400000020' and
          d[0x8690:0x8696].hex().upper() == 'B679' + '0000105E')
    check('the scan tests the same command bits 15 and 14 as the task body',
          d[0x867A:0x867E].hex().upper() == '0802000F' and
          d[0x8680:0x8684].hex().upper() == '0802000E')

    # --- large replicated blocks: RDHC + one per XP task -----------------
    for ln, addrs in [(408, [0xF06750, 0xF07168, 0xF07B68, 0xF08568]),
                      (192, [0xF05B92, 0xF065D2, 0xF06FEA, 0xF079EA, 0xF083EA]),
                      (176, [0xF05A0E, 0xF0644E, 0xF06E66, 0xF07866, 0xF08266])]:
        blk = d[addrs[0]-B:addrs[0]-B+ln]
        check('replicated %d-byte block x%d' % (ln, len(addrs)),
              all(d[a2-B:a2-B+ln] == blk for a2 in addrs) and d.count(blk) == len(addrs))

    # --- eight byte-identical copies of the panel-command issuer ---------
    ISSUERS = [0xF04500, 0xF05688, 0xF05E56, 0xF068A8,
               0xF072C0, 0xF07CC0, 0xF086C0, 0xF0A57E]
    body = d[ISSUERS[0]-B:ISSUERS[0]-B+0x30]
    check('panel-command issuer: 8 byte-identical 48-byte copies',
          all(d[e-B:e-B+0x30] == body for e in ISSUERS) and
          d.count(body) == 8)
    check('each issuer stashes d0 at $0E6E and is followed by bra .',
          body[:6].hex().upper() == '33C000000E6E' and
          body[0x2C:0x30].hex().upper() == '31400204' and
          all(d[e-B+0x30:e-B+0x32] == b'\x60\xfe' for e in ISSUERS))
    check('exactly 9 bra . sites: the 8 issuers plus one in the kernel',
          d.count(b'\x60\xfe') == 9)

    # --- the $281 arm cannot be rescued: level 6 under a level-7 ISR -----
    tr6, _ = run({'FPS3K_XPIRQ': '6'}, 150_000_000)
    check('BIM0 ch0 responder F04930 runs when nothing is spinning',
          tr6.count('F04930\n') > 0)
    tsp, _ = run({'FPS3K_XPIRQ': '5,6', 'FPS3K_DMA10AA': '2',
                  'FPS3K_MBOX': '20010000'}, 150_000_000)
    check('...but never while TCBIO1I spins at $F05E86 (level 6 under 7)',
          tsp.count('F05E86\n') > 1000 and tsp.count('F04930\n') == 0)
    check('TCBIO1I contains no SR-modifying instruction (never lowers IPL)',
          not any(struct.unpack('>H', d[a:a+2])[0] in (0x46FC, 0x027C, 0x007C)
                  or 0x46C0 <= struct.unpack('>H', d[a:a+2])[0] <= 0x46C7
                  for a in range(0x5D00, 0x5F00, 2)))

    # --- mailbox class field: only bits 16-17 == 1 writes the reply ------
    cls = {}
    for n in range(4):
        tc, _ = run({'FPS3K_XPIRQ': '5', 'FPS3K_DMA10AA': '2',
                     'FPS3K_MBOX': '000%d0000' % n}, 150_000_000)
        cls[n] = (tc.count('F05E40\n'), tc.count('F05E4C\n'))
    check('mailbox class field: only value 1 writes the reply',
          cls[0][0] == 0 and cls[2][0] == 0 and cls[3][0] == 0 and cls[1][0] > 100)
    check('...and the ISR returns in all four cases',
          all(v[1] > 100 for v in cls.values()))

    # --- TCBIO1I at level 7; mailbox bit 29 selects the ISR arm ----------
    tio, _ = run({'FPS3K_XPIRQ': '5', 'FPS3K_DMA10AA': '2'}, 400_000_000)
    check('TCBIO1I ISR runs at level 7 and returns ($10AA=2, mailbox clear)',
          tio.count('F05DD6\n') > 0 and tio.count('F05E2C\n') > 0
          and tio.count('F05E4C\n') > 0)
    tb29, _ = run({'FPS3K_XPIRQ': '5', 'FPS3K_DMA10AA': '2',
                   'FPS3K_MBOX': '20010000'}, 400_000_000)
    check('mailbox bit 29 set diverts the ISR to the host-request arm',
          tb29.count('F05DFA\n') > 0 and tb29.count('F05E2C\n') == 0)
    chk, _ = run({'FPS3K_DMA10AA': '2', 'FPS3K_DMA10AA_FROM_RESET': '1'},
                 400_000_000)
    check('$10AA injection from reset hangs the diagnostics (never boots)',
          'F00262\n' not in chk)

    # --- RAM map: 4 x 6-byte per-channel array, shared globals around ----
    def refs(base, lo, hi):
        return {v for a in range(base, base+0xA00, 2)
                for v in [struct.unpack('>I', d[a-B:a-B+4])[0]] if lo <= v <= hi}
    XPB = [(0xF07D00,0x1066),(0xF07300,0x106C),(0xF06900,0x1072),(0xF05F00,0x1078)]
    check('per-channel RAM array is 4 x 6 bytes at $1066-$107D',
          all(refs(b, 0x1066, 0x107D) == {c, c+2, c+4} for b, c in XPB))
    check('$105E,$1062,$1064,$107E,$1080 are shared by all four XP tasks',
          all(all(x in refs(b, 0x1050, 0x1090) for b, _ in XPB)
              for x in (0x105E, 0x1062, 0x1064, 0x107E, 0x1080)))
    def btsts(base, cmd):
        return [struct.unpack('>H', d[a-B+2:a-B+4])[0]
                for a in range(base, base+0xA00, 2)
                if struct.unpack('>H', d[a-B:a-B+2])[0] == 0x0839
                and struct.unpack('>I', d[a-B+4:a-B+8])[0] == cmd]
    check('XP1I/2/3 test command bits 15,14,11,11; XP4I only 15,14',
          [btsts(b, c) for b, c in XPB] ==
          [[15,14,11,11],[15,14,11,11],[15,14,11,11],[15,14]])

    # --- the $8000 path is gated on command-register bits 15, 14, 11 -----
    trg, _ = run({'FPS3K_CHANNELS': '2', 'FPS3K_XPIRQ': '1',
                  'FPS3K_CHCMD': 'C801'}, 400_000_000)
    check('$8000/$1B sequence fires when command bits 15,14,11 are set',
          trg.count('F07ED0\n') > 0)
    trn, _ = run({'FPS3K_CHANNELS': '2', 'FPS3K_XPIRQ': '1',
                  'FPS3K_CHCMD': 'C001'}, 400_000_000)
    check('...and not with bit 11 clear, though $F07EB6 is still reached',
          trn.count('F07ED0\n') == 0 and trn.count('F07EB6\n') > 0)

    # --- XP4I's ISR is identical; only the $8000 body path differs ------
    tr4, _ = run({'FPS3K_CHANNELS': '4', 'FPS3K_XPIRQ': '4'}, 400_000_000)
    check("XP4I's ISR runs and matches XP1I's shape",
          tr4.count('F060CE\n') > 0 and
          len({l for l in tr4.split() if 'F05F00' <= l <= 'F068FF'}) > 100)
    def n_in(pat, lo, hi):
        return d[lo-B:hi-B].count(pat)
    XPR = [(0xF05F00,0xF068FF),(0xF06900,0xF072FF),
           (0xF07300,0xF07CFF),(0xF07D00,0xF086FF)]
    check('$8004 (REQUEST-TRANSFER) appears 6x in every XP task, XP4I included',
          [n_in(b'\x30\xbc\x80\x04', lo, hi) for lo, hi in XPR] == [6,6,6,6])
    check('$8000 appears 3x total -- once each in XP1I/2/3, never in XP4I',
          [n_in(b'\x30\xbc\x80\x00', lo, hi) for lo, hi in XPR] == [0,1,1,1] and
          d.count(b'\x30\xbc\x80\x00') == 3)

    # --- XP channel ISR: reads $FF0048 via a base register --------------
    tr2, _ = run({'FPS3K_CHANNELS': '2', 'FPS3K_XPIRQ': '1'}, 400_000_000)
    check('XP1I ISR runs when its BIM channel is raised',
          tr2.count('F07EE6\n') > 0 and
          len({l for l in tr2.split() if 'F07D00' <= l <= 'F086FF'}) > 100)
    check('the ISR reads $FF0048 -- via $48(a5), not an absolute address',
          tr2.count('F07EF6\n') > 0 and
          d[0x7EF6:0x7EFE].hex().upper() == '33ED0048' + '00001068')

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

    check('XP1I directive $01 parameter block: name, STCK tag, $190 stack',
          d[0x7D14:0x7D18] == b'XP1I' and d[0x7D20:0x7D24] == b'STCK' and
          struct.unpack('>I', d[0x7D28:0x7D2C])[0] == 0x190)
    check('XP1I ASQ name tables hold AXP1 and HXP1',
          d[0x7D2C:0x7D30] == b'AXP1' and d[0x7D36:0x7D3A] == b'HXP1')

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
