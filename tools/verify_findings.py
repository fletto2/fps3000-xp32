#!/usr/bin/env python3
"""Assert the verified claims in refs_extracted/versabus_access_map.md.

    python3 tools/verify_findings.py [rom]

Pass an alternate ROM path to test the harness itself.  Measured 2026-07-29 at
144 checks: the real image gives 144/144, a two-byte mutation (an issuer copy
plus SRecordDataHandler) gives 100/144 so 44 checks catch it, and a random 64 KB
image gives 97/144 so 47 do.

The 97 that survive noise are mostly checks of the TOOLING rather than the ROM,
which is legitimate.  But three were vacuous when this was last audited --
"zero error-flag hits", "$01110-$1DEFF untouched", and "$10AA from reset never
boots" -- because a ROM that does nothing satisfies all three.  Each now carries
a liveness guard requiring that the run actually got somewhere.  An absence claim
without a presence precondition cannot fail.

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
    # Memoised: the suite reached 61 emulator invocations at ~10-15 s each and
    # blew past its 10-minute budget, while many configurations (notably the
    # bare default) are launched by a dozen different checks.  Keying on the
    # env delta plus cycle count is safe because the emulator is deterministic
    # -- three golden-master digests in this file assert exactly that.
    class _PCs(collections.Counter):
        """Counter of trace PCs that also answers .count(), so call sites which
        did `trace.split('\n').count('F04930')` keep working unchanged."""
        def count(self, x):
            return self[x.rstrip('\n')]

    class _Trace:
        """Lazily-histogrammed PC trace.

        A 400 M-cycle trace is 232 MB / 34.7 M lines.  Checks used it three
        ways -- .split('\n') then .count(), .count('PC\n') on the raw string,
        and `'PC\n' in trace` -- and each of those rescanned the whole thing:
        ~1.1 s per split and ~0.3 s per count, which with ~60 configurations
        was most of the suite's 10-minute runtime.  All three now resolve
        against one histogram built once, on first use.

        Iterating .split('\n') now yields DISTINCT PCs rather than every line.
        The two call sites that iterate build a set of ints from it, so that is
        the same answer and much cheaper -- but a future check that needs
        execution ORDER must use .raw, not this."""
        def __init__(self, raw):
            self.raw = raw
            self._pcs = None

        def _hist(self):
            if self._pcs is None:
                self._pcs = _PCs(self.raw.split('\n'))
            return self._pcs

        def split(self, sep=None):
            return self._hist()

        def count(self, s):
            return self._hist()[s.rstrip('\n')]

        def __contains__(self, s):
            return self._hist()[s.rstrip('\n')] > 0

    # Cycle budget for ordinary checks.  Boot completes by 120 M cycles, and the
    # set of PCs reached is byte-identical at 150 M, 200 M and 400 M across every
    # configuration tested -- only the repetition COUNTS scale, since the chassis
    # re-raises every 200 K cycles.  Halving the budget halves the suite.  The
    # golden-master digests keep 400 M: they were computed there, and a digest is
    # a whole-RAM hash, not a reached-set.
    CYC = 200_000_000
    _GOLDEN_CYC = 400_000_000

    _run_cache = {}

    def run(env, cycles, extra=None):
        key = (tuple(sorted(env.items())), cycles, tuple(extra or ()))
        if key in _run_cache:
            return _run_cache[key]
        e = dict(os.environ); e.update(env)
        cmd = [EMU, '-rom', ROM, '-cycles', str(cycles),
               '-trace', f'{tmp}/t', '-dump-ram', f'{tmp}/r']
        if extra: cmd += extra
        subprocess.run(cmd, env=e, capture_output=True, timeout=400)
        out = (_Trace(open(f'{tmp}/t').read()), open(f'{tmp}/r', 'rb').read())
        _run_cache[key] = out
        return out

    class _PCs(collections.Counter):
        """Counter of trace PCs with a .count() shim, so call sites that used
        `.split('\n')` on the raw trace keep working unchanged."""
        def count(self, x):
            return self[x]

    _pc_cache = {}

    def pcs(env, cycles):
        """Cached PC histogram for a configuration.

        The trace for a 400 M-cycle run is 232 MB / 34.7 M lines.  Every check
        that split it paid ~1.1 s for the split and ~0.3 s per .count(), and
        with ~60 configurations and several counts each that was most of the
        suite's 10-minute runtime.  Building the histogram once per
        configuration costs 1.65 s and makes every later lookup O(1)."""
        key = (tuple(sorted(env.items())), cycles)
        if key not in _pc_cache:
            _pc_cache[key] = _PCs(run(env, cycles)[0].split('\n'))
        return _pc_cache[key]

    def run_err(env, cycles):
        """Same, but returns the emulator's STDERR -- where the diagnostic
        channels (RTOSDUMP, RAMWATCH, the exit summary) all write.  run()
        returns the PC trace, and using it for a stderr assertion makes the
        check vacuous, which is how the first RTOSDUMP checks failed."""
        key = ('err', tuple(sorted(env.items())), cycles)
        if key in _run_cache:
            return _run_cache[key]
        e = dict(os.environ); e.update(env)
        r = subprocess.run([EMU, '-rom', ROM, '-cycles', str(cycles)],
                           env=e, capture_output=True, timeout=400)
        _run_cache[key] = r.stderr.decode('utf-8', 'replace')
        return _run_cache[key]
    tr, ram = run({}, CYC)
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
        # Only CODE lines matter: the header deliberately mentions the old
        # name to explain the correction, and ";>>>>" prose is unverified.
        check('no code line in fps3k.asm still uses the TCBDefinitionTable label',
              not [l for l in asm.split('\n')
                   if re.match(r'^\s+f0[0-9a-f]{4}:', l)
                   and 'TCBDefinitionTable' in l])
        check('fps3k.asm no longer carries the retracted "never read" claim',
              'never read anywhere' not in asm)
        check('fps3k.asm labels $F0A57E as PanelCmdIssuer_8 at all four sites',
              asm.count('PanelCmdIssuer_8(pc)') == 3 and
              'bra.w    PanelCmdIssuer_8' in asm)
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
    _, ramv = run({}, CYC)
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

    check('12 RMS68K markers exist; 8 tags are instantiated in RAM',
          {_r[x:x+4] for x in range(0, 0x20000)
           if _r[x:x+1] == b'!' and _r[x+1:x+4].isalpha()
           and _r[x+1:x+4].isupper()} ==
          {b'!TCB', b'!TST', b'!UDR', b'!PAT', b'!IDV', b'!IOV', b'!UST', b'!GST'})

    check('directive $2D creates per-task ASQ blocks in reverse task order',
          [(_r[x:x+4], _r[x+10:x+14]) for x in
           (0x1E700, 0x1E500, 0x1E300, 0x1E100)] ==
          [(b'AXP1', b'HXP1'), (b'AXP2', b'HXP2'),
           (b'AXP3', b'HXP3'), (b'AXP4', b'HXP4')] and
          _r[0x1DF00:0x1DF04] == b'HIO1')
    # Stride is 22 ($16), not 14: $1FB14 + 22*8 = $1FBC4, the ninth entry.
    # $16 is also the step in the ASQ blocks' 16-bit values, which are offsets
    # into this table.
    check('$1FB00 is a !UST directory of nine 22-byte (task, queue) entries',
          _r[0x1FB00:0x1FB04] == b'!UST' and
          [(_r[0x1FB14+22*i:0x1FB18+22*i], _r[0x1FB1C+22*i:0x1FB20+22*i])
           for i in range(9)] ==
          [(b'XP1I', b'AXP1'), (b'XP1I', b'HXP1'), (b'XP2I', b'AXP2'),
           (b'XP2I', b'HXP2'), (b'XP3I', b'AXP3'), (b'XP3I', b'HXP3'),
           (b'XP4I', b'AXP4'), (b'XP4I', b'HXP4'), (b'IO1I', b'HIO1')])

    check('RTOS creates only !TCB x6 and !TST x6, no !ASQ/!CCB/!DLY',
          [sum(1 for x in range(0, 0x20000) if _r[x:x+4] == tg)
           for tg in (b'!TCB', b'!TST', b'!ASQ', b'!CCB', b'!DLY')]
          == [6, 6, 0, 0, 0])

    # LIVENESS-GUARDED: "this range is untouched" passes on a ROM that touches
    # NO ram.  Require that the ranges known to be occupied really are.
    check('post-boot RAM: $01110-$1DEFF untouched, and the RTOS areas ARE used',
          not any(_r[x] for x in range(0x1110, 0x1DF00))
          and _r[0x1E900:0x1E904] == b'!TCB'
          and any(_r[x] for x in range(0x400, 0x808)))
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
                                   **env2}).stderr.count('[VECWATCH]')
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

    check('$F0A332 BulkClear: lsl.l #8 then move.l d6,-(a6) loop',
          d[0xA332:0xA342].hex().upper() ==
          '2C02E18E2C46DDC842862D06BDC86EFA')
    check('$F05652 issues $29 and $2A as a pair',
          d[0x5662:0x5666].hex().upper() == '70294E41' and
          d[0x566C:0x5670].hex().upper() == '702A4E41')

    # --- ds2 F.4: the firmware never byte-accesses the VersaBUS window ----
    # The addressing mode must be tested, not just the size field: $11BC is
    # move.b #imm,d16(An), whose immediate + displacement read as $00FF0000
    # and yield a false positive.  Require absolute-long as source (mode 111
    # reg 001 in the low 6 bits) or as destination (bits 8-6 = 001, 11-9 = 111).
    def moveb_abs(op):
        if (op >> 12) != 1: return False
        return (op & 0x3F) == 0x39 or (op & 0x0FC0) == 0x03C0
    check('no move.b anywhere carries an $FF00xx/$FF02xx absolute operand',
          not any(moveb_abs(struct.unpack('>H', d[a2:a2+2])[0]) and
                  0xFF0000 <= struct.unpack('>I', d[a2+2:a2+6])[0] <= 0xFF02FF
                  for a2 in range(0, 0xA600, 2)))

    # --- the chassis address map is complete for this firmware -------------
    for _e in ({}, {'FPS3K_XPIRQ': '1,5,6', 'FPS3K_CHCMD': 'C801'},
               {'FPS3K_CHSEL_RD': '28'}):
        _um = subprocess.run([EMU, '-rom', ROM, '-cycles', '300000000'],
                             capture_output=True, text=True,
                             env={**os.environ, **_e}).stderr
        check('no unmapped chassis access (%s)' % (list(_e) or 'default'),
              'unmapped chassis accesses: 0 reads, 0 writes' in _um)

    # --- the run reports its own instrumentation ---------------------------
    _inv = subprocess.run([EMU, '-rom', ROM, '-cycles', '5000000'],
                          capture_output=True, text=True).stderr
    check('a default run states that no hooks are active',
          'hooks active: (none - DEFAULT configuration)' in _inv)
    check('the summary warns that chassis-mem is not in the bus log',
          'chassis-mem=(off - NOT in the bus log)' in _inv)
    _inv2 = subprocess.run([EMU, '-rom', ROM, '-cycles', '5000000'],
                           capture_output=True, text=True,
                           env={**os.environ, 'FPS3K_XPIRQ': '1'}).stderr
    check('an instrumented run names the active hook',
          'FPS3K_XPIRQ=1' in _inv2)

    # --- all chassis-memory access happens on MODE2 page 0 -----------------
    with tempfile.TemporaryDirectory() as _td6:
        _r6 = subprocess.run([EMU, '-rom', ROM, '-cycles', '400000000',
                              '-bus', _td6+'/b'], capture_output=True, text=True,
                             env={**os.environ, 'FPS3K_LOGCHASSIS': '1',
                                  'FPS3K_BUSPC': '1'})
        _page, _pages = 0, {}
        _buslog = open(_td6+'/b').read().split('\n')
        for _l in _r6.stderr.split('\n'):
            if 'CHASSIS-MEM' in _l: _pages[_page] = _pages.get(_page, 0) + 1
        _m2 = re.findall(r'WR 2-byte FF0210 = 0*([0-9A-F]*)\s', '\n'.join(_buslog))
    check('MODE2 takes only three distinct values: 0, $0F, $10',
          sorted({int(x or '0', 16) for x in _m2}) == [0x00, 0x0F, 0x10])
    check('chassis memory is accessed >100k times, always with MODE2 = 0',
          sum(_pages.values()) > 30000 and set(_pages) == {0})

    # --- chassis memory: only the BERR probe reads it unwritten ------------
    with tempfile.TemporaryDirectory() as _td5:
        subprocess.run([EMU, '-rom', ROM, '-cycles', '400000000'],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       env={**os.environ, 'FPS3K_CHASSIS_UNINIT': _td5+'/c'})
        _cu = [l.split() for l in open(_td5+'/c') if l.strip()]
    check('unwritten chassis reads come only from ChassisProbe_Read $F096AC',
          _cu and all(x[1] == 'F096AC' for x in _cu)
          and all(x[0].startswith('40000') for x in _cu))
    check('$F096AC is a probe: read then 4 NOPs then rts, value discarded',
          d[0x96AC:0x96B8].hex().upper() == '30114E714E714E714E714E75')

    check('XP3I/XP2I 480-byte spans are template copies (8% patch rate)',
          sum(1 for i in range(480) if d[0x6940+i] != d[0x7340+i]) == 40)
    check("XP4I's spans are NOT copies at any grid offset (>40% differ)",
          min(sum(1 for i in range(400) if d[0x6940-o+i] != d[0x6940+i])
              for o in (0xA00, 0xA00-0x18, 0xA00+0x18)) > 160)

    check('the transfer primitive is replicated 15 times for each command',
          d.count(d[0x56C8:0x56C8+52]) == 15 and d.count(d[0x5742:0x5742+50]) == 15)
    check('$F056C8 issues $8004 and $F05742 issues $8005, both polling bit 14',
          d[0x56CA:0x56CE].hex().upper() == '30BC8004' and
          d[0x5742:0x5746].hex().upper() == '30BC8005' and
          d[0x56D8:0x56DC] == d[0x5750:0x5754])

    check('both remaining 5-copy groups open with the same $5F re-enable epilogue',
          d[0x57FA:0x580C] == d[0x599C:0x59AE] and
          d[0x5806:0x580A].hex().upper() == '36BC005F')
    check('the 88-byte group ends in $8005 CONTINUE-TRANSFER',
          d[0x5820:0x5824].hex().upper() == '30BC8005')

    check("RDHC's four dispatch handlers map onto XP1I's at +$2858",
          all(d[a2-0xF00000:a2-0xF00000+64] == d[a2+0x2858-0xF00000:a2+0x2858-0xF00000+64]
              for a2 in (0xF05A12, 0xF05B0E)) and
          all(sum(1 for i in range(64)
                  if d[a2-0xF00000+i] != d[a2+0x2858-0xF00000+i]) == 2
              for a2 in (0xF05738, 0xF058B2)))

    check('the five dispatch tables are byte-identical, not just same-shaped',
          len({bytes(d[a2-0xF00000:a2-0xF00000+168]) for a2 in
               (0xF05BA4, 0xF065E4, 0xF06FFC, 0xF079FC, 0xF083FC)}) == 1)

    # --- five copies of the 42-entry dispatch table ------------------------
    def _pat(base):
        hs, out = {}, ''
        for i in range(42):
            x = base + i*4
            w1 = struct.unpack('>H', d[x:x+2])[0]
            if w1 == 0x4E75: out += '.'; continue
            if w1 != 0x4EFA: return None
            w2 = struct.unpack('>H', d[x+2:x+4])[0]
            tg2 = x + 2 + (w2 - 0x10000 if w2 >= 0x8000 else w2)
            hs.setdefault(tg2, chr(ord('A') + len(hs)))
            out += hs[tg2]
        return out
    _P = '.ABBBBBBCCA..BBBB...D.AACACACCCA..ACAC....'
    check('five 42-entry dispatch tables share one handler pattern',
          [0xF00000 + x for x in range(0x4488, 0xA600, 2) if _pat(x) == _P]
          == [0xF05BA4, 0xF065E4, 0xF06FFC, 0xF079FC, 0xF083FC])
    check("XP4I's copy is $18 off the $A00 grid, as the byte diff predicts",
          (0xF083FC - 0xF065E4) == 0x1E18 and (0xF083FC - 0xF079FC) == 0x0A00)

    # --- the XP channel command dispatch table ----------------------------
    def _tbl42(base):
        out = []
        for i in range(42):
            x = base + i*4
            w1 = struct.unpack('>H', d[x:x+2])[0]
            if w1 == 0x4E75: out.append('rts'); continue
            if w1 != 0x4EFA: break
            w2 = struct.unpack('>H', d[x+2:x+4])[0]
            out.append(x + 2 + (w2 - 0x10000 if w2 >= 0x8000 else w2) + 0xF00000)
        return out

    def _tbl(base):
        out = []
        for i in range(16):
            x = base + i*4
            w1 = struct.unpack('>H', d[x:x+2])[0]
            if w1 == 0x4E75: out.append(None); continue
            w2 = struct.unpack('>H', d[x+2:x+4])[0]
            out.append(x + 2 + (w2 - 0x10000 if w2 >= 0x8000 else w2) + 0xF00000)
        return out
    # 42 entries, not 16: the table runs $F083FC-$F084A3 and ends where the
    # 0005 0403 data begins.  Same length, entry size, indexing and handler
    # count as RDHC's PanelStatusDispatchTable at $F05BA4-$F05C4B.
    _t42 = _tbl42(0x83FC)
    check('$F083FC is a 42-entry dispatch table with 4 handlers',
          len(_t42) == 42 and
          sorted(collections.Counter(_t42).values(), reverse=True)
          == [13, 10, 9, 9, 1])
    check('it is the same shape as PanelStatusDispatchTable at $F05BA4',
          (0xF05C4C - 0xF05BA4) // 4 == 42)
    check('the ISR reaches it via lsl.w #2,d0 / jmp (a4,d0.w)',
          d[0x7F84:0x7F8E].hex().upper() == 'E54849F900F083FC4EF4')

    # --- the channel transaction completes instead of timing out -----------
    trk, _ = run({'FPS3K_XPIRQ': '1'}, CYC)
    trn2, _ = run({'FPS3K_XPIRQ': '1', 'FPS3K_NOACK': '1'}, CYC)
    check('REQUEST-TRANSFER is acknowledged: the ISR poll exits in a few passes',
          trk.count('F07F2E\n') < 10 and trn2.count('F07F2E\n') == 1000)
    check('the acknowledge roughly doubles XP1I coverage (116 -> 240)',
          len({l for l in trk.split() if 'F07D00' <= l <= 'F086FF'}) > 200 and
          len({l for l in trn2.split() if 'F07D00' <= l <= 'F086FF'}) < 130)

    # Decoded-instruction starts and lengths, parsed once from the asm, so a
    # coverage assertion measures executed DECODED BYTES rather than raw PCs.
    import re as _re
    ASM_STARTS = {}
    # EXCLUDE DC.W lines.  A denominator built from every hex-bytes line counts
    # the 12,506 DC.W data words (25,012 bytes) alongside the 6,482 instructions
    # (22,980 bytes) -- very nearly half -- and deflated every coverage figure
    # this project measured.  Instruction coverage is 47%, not 44%.
    for _l in open('fps3k.asm'):
        _m = _re.match(r'^  ([0-9a-f]{6}): ((?:[0-9a-f]{2} )+)\s*(.*)$', _l)
        if _m and not _m.group(3).strip().startswith('DC.W'):
            ASM_STARTS[int(_m.group(1), 16)] = len(_m.group(2).split())
    check('asm has ~6.5k instructions and ~12.5k DC.W data words',
          6300 <= len(ASM_STARTS) <= 6700)

    # --- the last two stages test SCM through the $400000 window --------------
    check('$F09AD6 walks address lines A2-A13 writing each offset at itself',
          d[0xF09AE6-0xF00000:0xF09AFE-0xF00000]
          == b'\x20\x7c\x00\x40\x00\x00\x20\x3c\x00\x00\x40\x00'
             b'\x74\x04\x72\x04\x21\x81\x18\x00\xe3\x89\xb0\x81')
    check('...which is exactly 12 powers of two from 4 to 8192',
          [4 << i for i in range(12)] == [4, 8, 16, 32, 64, 128, 256, 512,
                                          1024, 2048, 4096, 8192])
    check('$F09B20 spans $400000-$404000 from a ROM pattern table at $F09BB6',
          d[0xF09B30-0xF00000:0xF09B42-0xF00000]
          == b'\x45\xf9\x00\x40\x00\x00\x43\xf9\x00\x40\x40\x00'
             b'\x47\xf9\x00\xf0\x9b\xb6')
    check('the pattern table is two complementary longword pairs',
          d[0xF09BB6-0xF00000:0xF09BC6-0xF00000]
          == b'\x00\x00\x00\x00\xff\xff\xff\xff'
             b'\x55\x55\x55\x55\xaa\xaa\xaa\xaa')
    check('both SCM stages run at page 0 (XLTR_MODE2 cleared)',
          d[0xF09AE2-0xF00000:0xF09AE6-0xF00000] == b'\x42\x6e\x02\x10'
          and d[0xF09B24-0xF00000:0xF09B28-0xF00000] == b'\x42\x6e\x02\x10')

    # --- four write-only neighbours of VMOD_CTRL ------------------------------
    check('$1FFE2/$1FFE4/$1FFE6/$1FFF2 are all move.w writes through a5',
          d[0xF08F8C-0xF00000:0xF08F90-0xF00000] == b'\x3b\x40\xff\xf2'
          and d[0xF09354-0xF00000:0xF09358-0xF00000] == b'\x3b\x40\xff\xf4'
          and d[0xF093F0-0xF00000:0xF093F4-0xF00000] == b'\x3b\x41\xff\xf4'
          and d[0xF0925C-0xF00000:0xF09260-0xF00000] == b'\x3b\x40\xff\xf6'
          and d[0xF093FA-0xF00000:0xF093FE-0xF00000] == b'\x3b\x41\x00\x02')
    check('$1FFF4 is the control case: read (or.b) then read-modify-write (addq.b)',
          d[0xF0897C-0xF00000:0xF08984-0xF00000]
          == b'\x80\x2d\x00\x04\x52\x2d\x00\x04')
    check('the displacements resolve to $1FFE2/$1FFE4/$1FFE6/$1FFF2/$1FFF4',
          [0x1FFF0 + o for o in (-0xE, -0xC, -0xA, 2, 4)]
          == [0x1FFE2, 0x1FFE4, 0x1FFE6, 0x1FFF2, 0x1FFF4])

    # --- $1FFE2 is a vector-number register; vectors 80-82 -------------------
    check('$700 derives a vector number by lsr #2 and writes it to $1FFE2',
          d[0xF08F86-0xF00000:0xF08F96-0xF00000]
          == b'\x30\x3c\x01\x44\xe4\x48\x3b\x40\xff\xf2'
             b'\x23\xcb\x00\x00\x01\x44'
          and 0x144 // 4 == 0x51)
    check('the three self-test vectors are the contiguous group 80/81/82',
          [a // 4 for a in (0x140, 0x144, 0x148)] == [80, 81, 82])
    check('$700 unmasks interrupts after installing the vector',
          d[0xF08F96-0xF00000:0xF08F9A-0xF00000] == b'\x02\x7c\xf8\xff')
    check('handler $F09052 sets VMOD bit 6 -- the bit $200 tests -- and rte',
          d[0xF09052-0xF00000:0xF0905A-0xF00000]
          == b'\x08\xed\x00\x06\x00\x01\x4e\x73')
    check('$F08F70 really is movem.l d0/a3-a5,-(a7), mis-disassembled as DC.W',
          d[0xF08F70-0xF00000:0xF08F74-0xF00000] == b'\x48\xe7\x80\x1c')

    # --- phase $600 is the bus-error watchdog test ----------------------------
    check('$600 walks $F82001 down by 2 with a byte read and NOP padding',
          d[0xF08F36-0xF00000:0xF08F48-0xF00000]
          == b'\x41\xf9\x00\xf8\x20\x01\x41\xe8\xff\xfe'
             b'\x10\x10\x4e\x71\x4e\x71\x4e\x71')
    check('$600 EXITS on a fault and FAILS if the sweep completes cleanly',
          d[0xF08F4C-0xF00000:0xF08F5E-0xF00000]
          == b'\x4a\x81\x66\x0e\xb1\xfc\x00\xf8\x00\x01'
             b'\x66\xe4\x2e\x3c\xf0\xf0\xf0\xf0')
    check('its handler counts faults with a skip-zero guard, and does NOT adjust PC',
          d[0xF08F06-0xF00000:0xF08F1C-0xF00000]
          == b'\x06\x81\x00\x00\x00\x01\x67\x02\x60\x06'
             b'\x06\x81\x00\x00\x00\x01\x4f\xef\x00\x08\x4e\x73')
    check('$800 derives the three PTM timer MSBs from a0 = $F70001',
          d[0xF0905E-0xF00000:0xF09064-0xF00000] == b'\x41\xf9\x00\xf7\x00\x01'
          and d[0xF09096-0xF00000:0xF0909A-0xF00000] == b'\x43\xe8\x00\x04'
          and d[0xF090A4-0xF00000:0xF090A8-0xF00000] == b'\x43\xe8\x00\x08'
          and d[0xF090B2-0xF00000:0xF090B6-0xF00000] == b'\x43\xe8\x00\x0c')

    # --- phase $300 IS a whole-ROM XOR checksum test --------------------------
    check('$300 sweeps $F00000-$F10000 XOR-accumulating into d0',
          d[0xF08D32-0xF00000:0xF08D44-0xF00000]
          == b'\x30\x3c\xff\xff\x20\x7c\x00\xf0\x00\x00'
             b'\x32\x18\xb3\x40\xb3\xc8\x66\xf8')
    check('...and requires the accumulator to still be $FFFF',
          d[0xF08D44-0xF00000:0xF08D4A-0xF00000] == b'\x0c\x40\xff\xff\x67\x06')
    check('the stock image satisfies it: all 32768 words XOR to zero',
          __import__('functools').reduce(
              lambda a, i: a ^ ((d[i] << 8) | d[i+1]), range(0, len(d), 2), 0) == 0)
    check('...with $C12D at $F0FFFE as the correction word',
          d[-2:] == b'\xc1\x2d')

    # --- $200 tests the bit-6 term; $1000 tests the AND term -----------------
    check('$200 loads d0=6 (VMOD bit) and d1=3 (board-status bit)',
          d[0xF08C5A-0xF00000:0xF08C5E-0xF00000] == b'\x70\x06\x72\x03')
    check('$200 clears $1FFF1 bit 6 and requires it to read back CLEAR',
          d[0xF08C66-0xF00000:0xF08C70-0xF00000]
          == b'\x01\xad\x00\x01\x01\x2d\x00\x01\x67\x06')
    check('$200 then requires $F70019 bit 3 SET with bit 6 clear',
          d[0xF08C84-0xF00000:0xF08C8E-0xF00000]
          == b'\x01\xad\x00\x01\x03\x2c\x00\x01\x66\x06')
    check('every bit of $1FFF1 is attributed to a self-test stage',
          sorted({0:'$1300',1:'$1300',2:'$1300',3:'$1400',4:'$1100',
                  5:'$1200',6:'$200',7:'$1000'}) == list(range(8)))

    # --- $1300: $1FFF1 bits 0-2 are an interrupt-request level field ----------
    check('$1300 installs handlers at vectors $140 and $148 (numbers 80 and 82)',
          d[0xF0935E-0xF00000:0xF0936A-0xF00000]
          == b'\x23\xcb\x00\x00\x01\x48\x23\xcc\x00\x00\x01\x40'
          and 0x140 // 4 == 80 and 0x148 // 4 == 82)
    check('$1300 triggers by OR-ing d1 into the word at $1FFF0',
          d[0xF0938A-0xF00000:0xF0938C-0xF00000] == b'\x83\x55')
    check('...waits up to 256 iterations for a handler to set d2',
          d[0xF0938C-0xF00000:0xF09396-0xF00000]
          == b'\x16\x3c\x00\xff\x4a\x42\x56\xcb\xff\xfc')
    check('...and HARD-asserts d2 nonzero, retrying forever on failure',
          d[0xF09396-0xF00000:0xF0939A-0xF00000] == b'\x4a\x42\x66\x06'
          and d[0xF093A6-0xF00000] == 0x66)
    check('the loop walks d1 = 1..7, exactly the 68000 interrupt levels',
          d[0xF093AA-0xF00000:0xF093B0-0xF00000] == b'\x52\x41\x0c\x41\x00\x08')

    # --- $1200: bit 5 self-clears; phases inherit VMOD state ------------------
    check('$1200 asserts board-status bit 1 follows $1FFF1 bit 5, set and clear',
          d[0xF0926E-0xF00000:0xF0927C-0xF00000]
          == b'\x08\xed\x00\x05\x00\x01\x08\x2c\x00\x01\x00\x01\x66\x06'
          and d[0xF09290-0xF00000:0xF0929E-0xF00000]
          == b'\x08\xad\x00\x05\x00\x01\x08\x2c\x00\x01\x00\x01\x67\x06')
    check('$1200 clears ONLY bit 7 on entry, inheriting bit 4 from $1100',
          d[0xF09240-0xF00000:0xF09246-0xF00000]
          == b'\x08\xad\x00\x07\x00\x01')
    check('...and $1100 ends with a bset, so bit 4 arrives at $1200 SET',
          d[0xF091BE-0xF00000:0xF091C0-0xF00000] == b'\x61\x06'   # bsr F091C6
          and d[0xF091C6-0xF00000:0xF091CA-0xF00000] == b'\x01\xed\x00\x01')
    check('$1200 polls $1FFF1 bit 5 for SELF-CLEARING, bounded to 16 tries',
          d[0xF092C2-0xF00000:0xF092D0-0xF00000]
          == b'\x30\x3c\x00\x0f\x08\x2d\x00\x05\x00\x01\x57\xc8\xff\xf8')
    check('$1200 runs with interrupts enabled at IPL 2 (SR <- $2200)',
          d[0xF09246-0xF00000:0xF0924A-0xF00000] == b'\x46\xfc\x22\x00')
    check('the emulator models VMOD_CTRL as plain RAM -- no auto-clear anywhere',
          not any('0x1FFF1' in open(f).read()
                  for f in ('emulator/versabus.c', 'emulator/fps3k_sbc.c')))

    # --- $1100 writable-bit test; PTM walking ones over movep -----------------
    check('$1100 loads d0=4 as the bit index and clears $1FFF1 bit 7 first',
          d[0xF0919C-0xF00000:0xF091A6-0xF00000]
          == b'\x70\x04\x72\x01\x08\xad\x00\x07\x00\x01')
    check('$F091C6 is bset-then-verify-SET on $1(a5)',
          d[0xF091C6-0xF00000:0xF091D0-0xF00000]
          == b'\x01\xed\x00\x01\x01\x2d\x00\x01\x66\x06')
    check('$F091FE is the exact mirror: bclr-then-verify-CLEAR',
          d[0xF091FE-0xF00000:0xF09208-0xF00000]
          == b'\x01\xad\x00\x01\x01\x2d\x00\x01\x67\x06')
    check('$F09154 walks ones through a PTM latch with movep.w both ways',
          d[0xF09154-0xF00000:0xF09160-0xF00000]
          == b'\x70\x01\x01\x89\x00\x00\x03\x09\x00\x00\xb2\x40')
    check('...asl.w #1 from 1 until zero is exactly 16 iterations',
          d[0xF0916C-0xF00000:0xF09170-0xF00000] == b'\xe3\x40\x66\xe6')
    check('the PTM is held in internal reset (CR2<-$01, CR1<-$01) during the walk',
          d[0xF0917E-0xF00000:0xF09182-0xF00000] == b'\x10\xbc\x00\x01'
          and d[0xF09184-0xF00000:0xF09188-0xF00000] == b'\x10\xbc\x00\x01')

    # --- the hidden-register sweep: candidates were lea, not accesses ---------
    check('$FF010A/$FF0114/$FF0116 candidates are lea (4fe8), not memory accesses',
          all(d[a-0xF00000:a-0xF00000+2] == b'\x4f\xe8'
              for a in (0xF05D50, 0xF05F64, 0xF0470A)))
    check('the $FF0002 candidate is move.w $2(a2),d6 -- a2 is not $FF0000',
          d[0xF06ED6-0xF00000:0xF06EDA-0xF00000] == b'\x3c\x2a\x00\x02')
    check('ground truth for base-register sweeps: $F07EF6 reads $48(a5)',
          d[0xF07EE8-0xF00000:0xF07EEE-0xF00000] == b'\x2a\x7c\x00\xff\x00\x00'
          and d[0xF07EF6-0xF00000:0xF07EFA-0xF00000] == b'\x33\xed\x00\x48')

    # --- MemBusProbe is a 4-case truth table; $1FFF0 IS bit-manipulated -------
    check('the checker clears $1FFF1 bit 6 then polls $F70019 bit 3, 16 tries',
          d[0xF0903C-0xF00000:0xF09050-0xF00000]
          == b'\x08\xad\x00\x06\x00\x01\x30\x3c\x00\x0f'
             b'\x08\x2c\x00\x03\x00\x01\x57\xc8\xff\xf8')
    check('cases (0,0) (0,1) (1,0) all require bit 3 to stay set (bne = $66)',
          all(d[a-0xF00000] == 0x66
              for a in (0xF08FB0, 0xF08FD2, 0xF08FF4)))
    check('case (1,1) alone requires bit 3 to go clear (beq = $67)',
          d[0xF09016-0xF00000] == 0x67
          and d[0xF0900A-0xF00000:0xF09016-0xF00000]
              == b'\x08\xed\x00\x07\x00\x01\x08\xd5\x00\x01\x61\x2a')
    check('$1FFF0 bit 1 is bset/bclr in five places, via (a5) not absolutely',
          sum(1 for a in (0xF08FA8, 0xF08FCC, 0xF08FE8, 0xF09010, 0xF0902C)
              if d[a-0xF00000:a-0xF00000+4] in (b'\x08\x95\x00\x01',
                                                b'\x08\xd5\x00\x01')) == 5)
    check('bclr.b #$8,(a5) is bit 8 mod 8 = bit 0, at three further sites',
          all(d[a-0xF00000:a-0xF00000+4] in (b'\x08\x95\x00\x08',
                                             b'\x08\xd5\x00\x08')
              for a in (0xF092B2, 0xF092F8, 0xF09320)))

    # --- $1900: bit 4 muxes the low half; $FF0214 is the latch ----------------
    check('$1900 writes $55555555 to $400000 and reads it back as a longword',
          d[0xF0978E-0xF00000:0xF0979C-0xF00000]
          == b'\x20\x3c\x55\x55\x55\x55\x32\x3c\xaa\xaa'
             b'\x20\x80\xb0\x90\x67\x06')
    check('$F09806 writes a word to the window itself',
          d[0xF09806-0xF00000:0xF0980C-0xF00000] == b'\x20\x80\x30\x81\xb4\x90')
    check('$F0981A writes that word to $FF0214 instead, and reads the LOW half',
          d[0xF0981A-0xF00000:0xF09824-0xF00000]
          == b'\x20\x80\x3d\x41\x02\x14\xb4\x68\x00\x02')
    check('bit4 SET expects $AAAA5555 (word write landed)',
          d[0xF097B2-0xF00000:0xF097BE-0xF00000]
          == b'\x24\x3c\xaa\xaa\x55\x55\x3d\x7c\x00\x10\x02\x16')
    check('bit4 CLEAR expects $55555555 (word write suppressed)',
          d[0xF097CA-0xF00000:0xF097D0-0xF00000] == b'\x24\x00\x42\x6e\x02\x16')
    check('bit4 CLEAR expects $FF0214 to supply the low half ($AAAA from d1)',
          d[0xF097F4-0xF00000:0xF097FA-0xF00000] == b'\x24\x01\x42\x6e\x02\x16')

    # --- $FF0216 bit 5 gates the $400000 window; $1700/$1800 are read/write ----
    check('$1700 probes $400000 with a READ, padded by four NOPs',
          d[0xF096AC-0xF00000:0xF096B8-0xF00000]
          == b'\x30\x11\x4e\x71\x4e\x71\x4e\x71\x4e\x71\x4e\x75')
    check('$1800 probes it with a WRITE, same padding',
          d[0xF096B8-0xF00000:0xF096C4-0xF00000]
          == b'\x42\x51\x4e\x71\x4e\x71\x4e\x71\x4e\x71\x4e\x75')
    check('the BERR handler sets d1=1, trims the frame by 8, skips PC by 4',
          d[0xF098E0-0xF00000:0xF098EC-0xF00000]
          == b'\x72\x01\x4f\xef\x00\x08\x58\x6f\x00\x04\x4e\x73')
    check('...so d1 NONZERO means the access faulted, inverting the naive reading',
          d[0xF098E0-0xF00000:0xF098E2-0xF00000] == b'\x72\x01'   # moveq #1,d1
          and d[0xF0962E-0xF00000:0xF09630-0xF00000] == b'\x4a\x41'  # tst.w d1
          and d[0xF09630-0xF00000] == 0x66)                          # bne -> fault OK
    check('$216 <- $20 then require a fault; $216 <- 0 then require success',
          d[0xF09626-0xF00000:0xF09632-0xF00000]
          == b'\x3d\x7c\x00\x20\x02\x16\x61\x7e\x4a\x41\x66\x06'
          and d[0xF09648-0xF00000:0xF09652-0xF00000]
          == b'\x42\x6e\x02\x16\x61\x5e\x4a\x81\x67\x06')
    check('a fixed +4 skip lands inside the NOP padding (F096AE + 4 = F096B2)',
          0xF096AC + 2 + 4 == 0xF096B2)

    # --- phase $1600 specifies the XLTR register file --------------------------
    check('$1600 reads STATUS_IRQ and branches on bit 4 to pick $D0 or $D8',
          d[0xF09522-0xF00000:0xF09536-0xF00000]
          == b'\x30\x2e\x02\x18\x08\x00\x00\x04\x66\x06'
             b'\x32\x3c\x00\xd0\x60\x04\x32\x3c\x00\xd8')
    check('...and $D0/$D8 from $C0 is exactly 16 or 24 BIM registers',
          (0xD0 - 0xC0) == 16 and (0xD8 - 0xC0) == 24
          and 0x230 + 2*15 == 0x24E and 0x230 + 2*23 == 0x25E)
    check('the $210 walk writes $210/$212/$214/$216 as standalone words',
          d[0xF09558-0xF00000:0xF0956C-0xF00000]
          == b'\x30\x3c\x00\x10\x30\x7c\x02\x10\x3d\x80\x80\x00'
             b'\x41\xe8\x00\x02\xe3\x08\x64\xf4')
    check('MODE0 is read back under mask $00FF -- only the command byte',
          d[0xF09590-0xF00000:0xF09598-0xF00000]
          == b'\x30\x2e\x02\x00\x02\x40\x00\xff')
    check('STATUS_IRQ is read back under mask $0610, required $400',
          d[0xF095A2-0xF00000:0xF095AE-0xF00000]
          == b'\x30\x2e\x02\x18\x02\x40\x06\x10\x0c\x40\x04\x00')

    # --- phase $1A00 is a bus-error-tolerant AP I/F data-line test -------------
    check('$1A00 saves the bus-error vector and installs its own at $F098E0',
          d[0xF09836-0xF00000:0xF09842-0xF00000]
          == b'\x20\x78\x00\x08\x21\xfc\x00\xf0\x98\xe0\x00\x08')
    check('$1A00 writes $AAAA to $FF000E and reads it back for equality',
          d[0xF0987C-0xF00000:0xF09888-0xF00000]
          == b'\x3d\x7c\xaa\xaa\x00\x0e\x0c\x6e\xaa\xaa\x00\x0e')
    check('...with $F0F0F0F0 as the failure marker on mismatch',
          d[0xF0988A-0xF00000:0xF09890-0xF00000] == b'\x2e\x3c\xf0\xf0\xf0\xf0')
    check('$1500 is a CHANNEL_SELECT-only stage, 40 bytes',
          0xF09518 - 0xF094F0 == 40)
    check('$1700 and $1800 are a matched pair on the window machinery',
          d[0xF09602-0xF00000:0xF09606-0xF00000][:2]
          == d[0xF096C4-0xF00000:0xF096C8-0xF00000][:2])

    # --- the self-test spine: three sequences, $D0 checkpoints -----------------
    check('sequence A bases d6 at $200 ($F08764)',
          d[0xF08764-0xF00000:0xF0876A-0xF00000] == b'\x2c\x3c\x00\x00\x02\x00')
    check('sequence B re-bases d6 to $1000 after XLTR_MODE1 <- $2000',
          d[0xF087D4-0xF00000:0xF087DE-0xF00000]
          == b'\x3d\x7c\x20\x00\x02\x02\x3c\x3c\x10\x00')
    check('sequence C re-bases d6 to $2000',
          d[0xF08862-0xF00000:0xF08866-0xF00000] == b'\x3c\x3c\x20\x00')
    check('each sequence ends VMOD <- $D0 then XLTR_MODE1 <- $8000',
          all(d[a-0xF00000:a-0xF00000+10]
              == b'\x3a\xbc\x00\xd0\x3d\x7c\x80\x00\x02\x02'
              for a in (0xF087AA, 0xF08832, 0xF088CC)))
    check('the DRAM test relocates the supervisor stack to $800 first',
          d[0xF08886-0xF00000:0xF0888A-0xF00000] == b'\x4f\xf8\x08\x00')
    check('...because it then tests $1F000-$1F400, which contains $1FFD0',
          d[0xF08892-0xF00000:0xF0889E-0xF00000]
          == b'\x20\x7c\x00\x01\xf0\x00\x22\x7c\x00\x01\xf4\x00')
    check('and the last region tested is $10000-$20000, the staging buffer',
          d[0xF088A8-0xF00000:0xF088B4-0xF00000]
          == b'\x20\x7c\x00\x01\x00\x00\x22\x7c\x00\x02\x00\x00')

    # --- the PTM tick: T3 = $27C7 in dual-8-bit mode off the 800 kHz E clock --
    check('$F0A2C6 programs T3 = $27C7 (MSB $27, LSB $C7)',
          d[0xF0A2C8-0xF00000:0xF0A2CC-0xF00000] == b'\x00\x0d\x30\x3c')
    check('$F0A2D2 clears CR2 bit 0, so $F0A2D8 addresses CR3 not CR1',
          d[0xF0A2D2-0xF00000:0xF0A2DA-0xF00000]
          == b'\x13\x7c\x00\x00\x00\x03\x13\x7c')
    check('CR3 = $C6: dual-8-bit (bit2), internal E clock (bit1), no /8 (bit0)',
          d[0xF0A2DA-0xF00000:0xF0A2DE-0xF00000] == b'\x00\xc6\x00\x01'
          and (0xC6 & 0x04) and (0xC6 & 0x02) and not (0xC6 & 0x01))
    check('...giving (39+1)*(199+1) = 8000 E cycles = exactly 10 ms at 800 kHz',
          (0x27 + 1) * (0xC7 + 1) == 8000
          and abs(8000 / (8_000_000 / 10) - 0.010) < 1e-9)
    check('the emulator does NOT model dual-8-bit, so its tick is 27% slow',
          'counter[t] = p->latch[t]' in open('emulator/mc6840.c').read()
          and '0x04' not in open('emulator/mc6840.c').read().split('mc6840_tick')[1])

    # --- the AP I/F is 8 windows of $20; only five are populated --------------
    check('the channel port formula is (ch+1)<<5 + $FF000E, so ch1 is window 2',
          d[0xF053EA-0xF00000:0xF053F4-0xF00000]
          == b'\x52\x83\xeb\x8b\x06\x83\x00\xff\x00\x0e')
    _vb = open('emulator/versabus.c').read()
    check('the emulator decodes only windows 2-5 as channels, excluding 1 and 6-7',
          'addr >= 0xFF0040 && addr <= 0xFF00BF' in _vb
          and '((addr - 0xFF0040) >> 5) + 1' in _vb)
    check('...and APIF_END is $FF0100, so the upper half is reported unmapped',
          '#define APIF_END       0xFF0100' in open('emulator/versabus.h').read())

    # --- "panel" is a project label, not FPS or Motorola terminology ----------
    _am = open('refs_extracted/versabus_access_map.md').read()
    check('the access map records that "panel command" is a project-invented name',
          'project-invented name' in _am and 'FRONT PANEL EQUATES' in _am)
    check('...and that $FF000E is the base window command/status register',
          "chassis command/status protocol at `$FF000E`" in _am)

    # --- $0C30 is TRACEBEG, $0C34 trace flags, $0C9A TIAT --------------------
    check('$F0A04E writes $01010000 to $0C9A -- TIAT, "TRAP 0 and 1 used by exec"',
          d[0xF0A04E-0xF00000:0xF0A056-0xF00000]
          == b'\x21\xfc\x01\x01\x00\x00\x0c\x9a')
    check('the FPS kernel hook tests bit 14 of the trace flags at $0C34',
          d[0xF044A2-0xF00000:0xF044AA-0xF00000]
          == b'\x08\x38\x00\x0e\x0c\x34\x67\x0a')
    check('...and only then calls the trace enqueue at $F01688',
          0xF044AE + struct.unpack('>h', d[0xF044AE-0xF00000:0xF044B0-0xF00000])[0]
          == 0xF01688)
    _, rtr = run({}, CYC)
    check('the trace buffer at $1F500 is registered in slot $0C30 (TRACEBEG)',
          struct.unpack('>I', rtr[0x0C30:0x0C34])[0] == 0x1F500)
    check('...and carries no eye-catcher, because BLDTRAC writes none',
          rtr[0x1F500:0x1F504] != b'!TRC' and rtr[0x1F500] != 0x21)

    # --- $1FA00 is the VTU; !VCT is ROM-resident -----------------------------
    check("'!VCT' is present in ROM at $F0011A, preceded by an address not an opcode",
          d[0xF0011A-0xF00000:0xF0011E-0xF00000] == b'!VCT'
          and struct.unpack('>I', d[0xF00116-0xF00000:0xF0011A-0xF00000])[0] == 0xF00186)
    check("...and at $F09C9C as VECTINIT's comparison immediate (move.l #'!VCT',d0)",
          d[0xF09C9A-0xF00000:0xF09CA0-0xF00000] == b'\x20\x3c!VCT')
    check('!CCB and !DLY eye-catchers are WRITTEN by kernel code, not linked tables',
          d[0xF03EEE-0xF00000:0xF03EF0-0xF00000] == b'\x22\xbc'
          and d[0xF02D98-0xF00000:0xF02D9A-0xF00000] == b'\x25\x7c')
    check('the VTU build writes a per-vector USED flag, one byte at a time',
          d[0xF09F22-0xF00000:0xF09F2C-0xF00000]
          == b'\xb9\xda\x67\x02\x10\x82\x41\xe8\x00\x01')

    # --- !UST header fields per UST.EQ; +$0C is MENT, not the record size ----
    _, ru2 = run({}, CYC)
    _h16 = lambda x: struct.unpack('>H', ru2[x:x+2])[0]
    check('!UST header: NSEG=1, NPAGE=2, MENT=22, CENT=9, FENT=$1FB14',
          (_h16(0x1FB08), _h16(0x1FB0A), _h16(0x1FB0C), _h16(0x1FB0E),
           struct.unpack('>I', ru2[0x1FB10:0x1FB14])[0])
          == (1, 2, 22, 9, 0x1FB14))
    check('...and MENT is the ENTRY COUNT: (NPAGE*256 - $14) // $16 == MENT',
          (_h16(0x1FB0A) * 256 - 0x14) // 0x16 == _h16(0x1FB0C))
    check('USTSNAME (+$08 of each entry) holds the semaphore names AXP1/HXP1/AXP2',
          [ru2[0x1FB14 + 0x16*i + 8:0x1FB14 + 0x16*i + 12] for i in range(3)]
          == [b'AXP1', b'HXP1', b'AXP2'])
    check('...each with USTUCNT=1 and USTTYPE=2',
          all(_h16(0x1FB14 + 0x16*i + 0x0C) == 1
              and ru2[0x1FB14 + 0x16*i + 0x0F] == 2 for i in range(9)))

    # --- the directive-$01 block is a Segment Parameter Block ----------------
    check("RDHC's $01 block is a SGPB: task 'RDHC', name 'STCK', length $190",
          d[0xF046B0-0xF00000:0xF046B4-0xF00000] == b'RDHC'
          and d[0xF046BC-0xF00000:0xF046C0-0xF00000] == b'STCK'
          and struct.unpack('>I', d[0xF046C4-0xF00000:0xF046C8-0xF00000])[0] == 0x190)
    check('...with SGPBOPT = $2000, i.e. bit 13 SGPBOPAD (exec supplies the address)',
          struct.unpack('>H', d[0xF046B8-0xF00000:0xF046BA-0xF00000])[0] == 0x2000)
    check('...and SGPBLA zero, consistent with letting the exec choose',
          struct.unpack('>I', d[0xF046C0-0xF00000:0xF046C4-0xF00000])[0] == 0)
    # !PAT entry length: the PAT.EQ field list sums to $1E, the measured stride
    check('!PAT free-list stride is $1E, matching PAT.EQ field sum 4+4+4+4+4+2+4+2+2',
          4+4+4+4+4+2+4+2+2 == 0x1E)

    # --- TCB fields named from TCB.EQ, verified against RAM -------------------
    _, rtcb = run({}, CYC)
    _g = lambda x: struct.unpack('>I', rtcb[x:x+4])[0]
    check('TCBASQ (+$40) is NULL for all six tasks -- no ASQs, so they are semaphores',
          all(_g(0x1E900 + 0x200*i + 0x40) == 0 for i in range(6)))
    check('TCBTST (+$36) points at exactly TCB+$160, where the !TST marker sits',
          all(_g(0x1E900 + 0x200*i + 0x36) == 0x1E900 + 0x200*i + 0x160
              for i in range(6))
          and all(rtcb[0x1E900 + 0x200*i + 0x160:
                       0x1E900 + 0x200*i + 0x164] == b'!TST' for i in range(6)))
    check('TCBENTRY (+$6C) holds each task entry point from the TDTI table',
          [_g(0x1E900 + 0x200*i + 0x6C) for i in range(6)]
          == [0xF07D4A, 0xF0734A, 0xF0694A, 0xF05F4A, 0xF05D36, 0xF046F0])
    check('TCBA6 (+$138) and TCBUSP (+$13C) lie in one $200 segment per task',
          all(_g(0x1E900 + 0x200*i + 0x138) <= _g(0x1E900 + 0x200*i + 0x13C)
              < _g(0x1E900 + 0x200*i + 0x138) + 0x200 for i in range(6)))

    # --- $F00760's "80" is a parameter-block length limit, not a directive max -
    check('$F00760 bounds a LENGTH derived from $0C08 minus a stack pointer',
          d[0xF00756-0xF00000:0xF00760-0xF00000]
              == b'\x20\x38\x0c\x08\x4b\xef\x00\x10\x90\x8d'
          and d[0xF00760-0xF00000:0xF00768-0xF00000]
              == b'\x0c\x80\x00\x00\x00\x50\x6f\x04')
    check('...and stores that length at TCB+$72 before a word copy loop',
          d[0xF00778-0xF00000:0xF00780-0xF00000]
          == b'\x1d\x47\x00\x72\x38\xdd\x55\x40')
    # A real assertion rather than a label: the largest stack-built parameter block
    # in the firmware is the 10-byte semaphore descriptor, well under the 80-byte cap.
    check('no firmware parameter block approaches the 80-byte cap',
          d[0xF05670-0xF00000:0xF05674-0xF00000] == b'\x4f\xef\x00\x0a'   # lea $A(a7),a7
          # SIGNED displacements: negative ones are stack ALLOCATIONS (the -$60
          # scratch area at $F0857A), positive ones are block discards -- i.e. the
          # parameter-block sizes.  Only the positive ones bear on the 80-byte cap.
          and max([v for v in
                   (struct.unpack('>h', d[a2-0xF00000+2:a2-0xF00000+4])[0]
                    for a2 in range(0xF04488, 0xF0A800, 2)
                    if struct.unpack('>H', d[a2-0xF00000:a2-0xF00000+2])[0] == 0x4FEF)
                   if v > 0]) <= 0x50)

    # --- RMS68K directive names, from the VERSAdos source --------------------
    # TR1.EQ / STR.EQ number directives in DECIMAL; the firmware loads hex.
    TRAP1 = {0x01: 'GTSEG', 0x0B: 'CRTCB', 0x0D: 'START', 0x0F: 'TERM',
             0x10: 'TERMT', 0x11: 'SUSPND', 0x12: 'RESUME', 0x13: 'WAIT',
             0x29: 'ATSEM', 0x2A: 'WTSEM', 0x2B: 'SGSEM', 0x2D: 'CRSEM',
             0x43: 'RSTATE', 0x4C: '(beyond TR1.EQ)'}
    TRAP0 = {0x04: 'T0PAGAL', 0x06: 'T0GETTCB', 0x16: 'T0WAKEUP',
             0x18: 'T0QEVNTI', 0x1F: 'T0CRTCB'}
    def _dirs(trapop):
        out = set()
        for a2 in range(0xF04488, 0xF0A800, 2):
            if struct.unpack('>H', d[a2-0xF00000:a2-0xF00000+2])[0] != trapop:
                continue
            pw = struct.unpack('>H', d[a2-0xF00000-2:a2-0xF00000])[0]
            if (pw & 0xFF00) == 0x7000:
                out.add(pw & 0xFF)
        return out
    check('the firmware TRAP #1 directive set is exactly the 14 now named',
          _dirs(0x4E41) <= set(TRAP1) and len(_dirs(0x4E41)) >= 12)
    check('the firmware TRAP #0 directive set is exactly the five now named',
          _dirs(0x4E40) <= set(TRAP0) | {0x04})
    check('$2D (CRSEM, create semaphore) appears twice per XP task, never in RDHC',
          len([a2 for a2 in range(0xF07D4A, 0xF0874A, 2)
               if struct.unpack('>H', d[a2-0xF00000:a2-0xF00000+2])[0] == 0x4E41
               and struct.unpack('>H', d[a2-0xF00000-2:a2-0xF00000])[0] == 0x702D]) == 2
          and not [a2 for a2 in range(0xF04600, 0xF05D00, 2)
                   if struct.unpack('>H', d[a2-0xF00000:a2-0xF00000+2])[0] == 0x4E41
                   and struct.unpack('>H', d[a2-0xF00000-2:a2-0xF00000])[0] == 0x702D])
    check('$29/$2A at $F05652 are ATSEM then WTSEM, not queue lookup and post',
          d[0xF05662-0xF00000:0xF05666-0xF00000] == b'\x70\x29\x4e\x41'
          and d[0xF0566C-0xF00000:0xF05670-0xF00000] == b'\x70\x2a\x4e\x41')

    # --- the FPS/RMS68K interface: 4 pointers out, 2 calls in ----------------
    _fps_ptrs = [a2 for a2 in range(0xF00000, 0xF04488, 2)
                 if 0xF04488 <= struct.unpack('>I', d[a2-0xF00000:a2-0xF00000+4])[0]
                                <= 0xF0FFFF]
    check('exactly four FPS pointers inside the RMS68K kernel region',
          _fps_ptrs == [0xF00004, 0xF001A6, 0xF03FDC, 0xF040EC])
    _back = set()
    for a2 in range(0xF04488, 0xF0A800, 2):
        w2 = struct.unpack('>H', d[a2-0xF00000:a2-0xF00000+2])[0]
        if w2 in (0x4EB9, 0x4EF9):
            tt2 = struct.unpack('>I', d[a2-0xF00000+2:a2-0xF00000+6])[0]
        elif w2 in (0x6000, 0x6100):
            tt2 = a2 + 2 + struct.unpack('>h', d[a2-0xF00000+2:a2-0xF00000+4])[0]
        else:
            continue
        if 0xF00000 <= tt2 < 0xF04488:
            _back.add(tt2)
    check('...and only two kernel entry points called from the FPS region',
          _back == {0xF008B6, 0xF01688})
    check('reset SSP is $00000000 and PC is $F09C00, which jmps to MainInit $F08700',
          struct.unpack('>I', d[0:4])[0] == 0
          and struct.unpack('>I', d[4:8])[0] == 0xF09C00
          and d[0xF09C00-0xF00000:0xF09C06-0xF00000]
              == b'\x4e\xf9\x00\xf0\x87\x00')
    check('...and MainInit opens by loading the supervisor stack pointer',
          d[0xF08700-0xF00000:0xF08706-0xF00000]
          == b'\x4f\xf9\x00\x01\xff\xd0')
    check('$F01688 is a masked-interrupt ring enqueue on the $0C30 pool',
          d[0xF0168E-0xF00000:0xF0169E-0xF00000]
          == b'\x26\x78\x0c\x30\x00\x7c\x07\x00'
             b'\x2a\x53\xbb\xeb\x00\x04\x66\x04'
          and d[0xF016A2-0xF00000:0xF016A8-0xF00000]
              == b'\x49\xed\x00\x1a\x26\x8c')

    # --- the device communications map stays in step with the machine --------
    try:
        _cm = open('refs_extracted/device_communications_map.md').read()
        check('the comms map covers every device block the firmware touches',
              all(k in _cm for k in ('$01FFF0', '$70001C', '$400000', '$F70000',
                                     '$F70010', '$F70018', '$FF0000', '$FF0040',
                                     '$FF0060', '$FF0080', '$FF00A0', '$FF0200',
                                     '$FF0230')))
        check('...records the SIO as never accessed (which is why the monitor has it)',
              'Never accessed by this firmware' in _cm)
        check('...and names what the ROM cannot show (EU/AU, UNIV FMT, MEM CTL, AP I/F)',
              all(k in _cm for k in ('EU \u2194 AU', 'UNIV FMT', 'MEM CTL',
                                     'AP I/F counterpart')))
    except FileNotFoundError:
        check('device communications map exists', False)

    # --- FPS3K_RESPSEQ: alternating wake/$14 gains a second wake -------------
    tseq = pcs({'FPS3K_RESPSEQ': '0x0B,0x94', 'FPS3K_XPIRQ': '6',
                'FPS3K_CHASSIS_CMD': '1,14,1'}, CYC)
    tcon = pcs({'FPS3K_RESP': '0x94', 'FPS3K_XPIRQ': '6',
                'FPS3K_CHASSIS_CMD': '1,14,1'}, CYC)
    check('alternating 0B,94 gives RDHC a second wake where $94 alone gives one',
          tseq.count('F04740') == 2 and tcon.count('F04740') == 1)
    check('...but only two, though $0B alone wakes it >300 times',
          pcs({'FPS3K_RESP': '0x0B', 'FPS3K_XPIRQ': '6'}, CYC).count('F04740') > 300)
    # op $7 masks BIM0 ch0 -- scheduling it silences the very channel it came on
    t07 = pcs({'FPS3K_RESPSEQ': '0x07,0x94', 'FPS3K_XPIRQ': '6',
               'FPS3K_CHASSIS_CMD': '1,14,1'}, CYC)
    check('op $7 in a sequence destroys the sequence (it masks BIM0 ch0)',
          t07.count('F05370') == 0 and t07.count('F0572C') == 0)
    check('...which matches its decode: read $FF0230, bclr #4 (IRE), write back',
          d[0xF04F3A-0xF00000:0xF04F46-0xF00000]
          == b'\x32\x28\x02\x30\x08\x81\x00\x04\x31\x41\x02\x30')

    # --- $14 means "command waiting" to RDHC but "just return" to the ISR ----
    check('$F04976 tests d0 == $14 and branches straight to the ISR exit stub',
          d[0xF04976-0xF00000:0xF0497E-0xF00000]
          == b'\x0c\x40\x00\x14\x67\x00\x07\x7c')
    check('...whose target is $F050F8, the movem/ccr/trap exit',
          0xF0497A + 2 + struct.unpack('>H', d[0xF0497C-0xF00000:0xF0497E-0xF00000])[0]
          == 0xF050F8)
    t14b = pcs({'FPS3K_RESP': '0x94', 'FPS3K_XPIRQ': '6',
                'FPS3K_CHASSIS_CMD': '1,14,1'}, CYC)
    check('RDHC therefore wakes exactly ONCE however many $14s arrive',
          t14b.count('F0473C') == 1 and t14b.count('F04740') == 1
          and t14b.count('F0495C') > 300)
    check('...and a fully-populated descriptor gains nothing over the probe',
          t14b.count('F05370') == 1)

    # --- phases $15xx and $23xx ----------------------------------------------
    check('$15xx writes CHANNEL_SELECT 0..5 and reads each back',
          d[0xF094F2-0xF00000:0xF094F8-0xF00000] == b'\x0c\x06\x00\x05\x6e\x1e'
          and d[0xF094FA-0xF00000:0xF09504-0xF00000]
              == b'\x3d\x46\x02\x04\xbc\x6e\x02\x04\x67\x06')
    check('$23xx fills with $09ABCDEF, waits 300,000 iterations, then verifies',
          struct.unpack('>I', d[0xF09A8A-0xF00000+2:0xF09A8A-0xF00000+6])[0]
              == 0x09ABCDEF
          and struct.unpack('>I', d[0xF09AA4-0xF00000+2:0xF09AA4-0xF00000+6])[0]
              == 0x000493E0
          and d[0xF09AAA-0xF00000:0xF09AAE-0xF00000] == b'\x53\x85\x66\xfc')
    check('...and steps over $1FFF0-$1FFF3 in both the fill and the verify',
          d[0xF09A94-0xF00000:0xF09AA0-0xF00000]
              == b'\xb1\xfc\x00\x01\xff\xf0\x66\x04\x41\xe8\x00\x04'
          and d[0xF09ABC-0xF00000:0xF09AC8-0xF00000]
              == b'\xb5\xfc\x00\x01\xff\xf0\x66\x04\x45\xea\x00\x04')

    # --- op $3: $E58 is a longword INDEX, offsets windowed up to 4 MB --------
    check('op $3 takes page = index >> 20 and offset = (index & $FFFFF) << 2',
          d[0xF04D70-0xF00000:0xF04D78-0xF00000]
              == b'\x74\x14\xe4\xa9\x31\x41\x02\x10'
          and d[0xF04D7E-0xF00000:0xF04D86-0xF00000]
              == b'\x02\x81\x00\x0f\xff\xff\xe5\x89')
    check('...and bounds the OFFSET at 4 MB, not the window',
          d[0xF04D88-0xF00000:0xF04D90-0xF00000]
          == b'\xb3\xfc\x00\x40\x00\x00\x6c\x10')
    check('the emulator window stays 1 MB, recorded as an unforced choice',
          '(1u << 20)' in open('emulator/fps3k_sbc.c').read()
          and 'not derived' in open('emulator/fps3k_sbc.c').read())

    # --- phase $29xx covers 16 KB of chassis memory, not "131k addresses" ----
    check('phase $29xx walks $400000 to $404000 -- 16 KB',
          d[0xF09B30-0xF00000:0xF09B3C-0xF00000]
          == b'\x45\xf9\x00\x40\x00\x00\x43\xf9\x00\x40\x40\x00')
    check('...with the stride in d2 and patterns from the table at $F09BB6',
          d[0xF09B3C-0xF00000:0xF09B46-0xF00000]
              == b'\x47\xf9\x00\xf0\x9b\xb6\x20\x1b\x22\x1b'
          and d[0xF09B84-0xF00000:0xF09B88-0xF00000] == b'\x41\xf0\x20\x00')
    check('the four patterns are $00000000/$FFFFFFFF/$55555555/$AAAAAAAA',
          [struct.unpack('>I', d[0xF09BB6-0xF00000+4*i:0xF09BB6-0xF00000+4*i+4])[0]
           for i in range(4)] == [0x00000000, 0xFFFFFFFF, 0x55555555, 0xAAAAAAAA])
    # measured at TRUE width, not from the byte-decomposing bus log
    import tempfile as _tf2
    _al2 = _tf2.mktemp()
    run_err({'FPS3K_ACCESSLOG': _al2}, CYC)
    _cw = [l.split() for l in open(_al2) if l[:1] in 'RW']
    _win = [l for l in _cw if 0x400000 <= int(l[2], 16) < 0x500000]
    _addrs = {int(l[2], 16) for l in _win}
    check('measured: 4,098 distinct chassis addresses spanning exactly 16 KB',
          len(_addrs) == 4098
          and min(_addrs) == 0x400000 and max(_addrs) == 0x404000)
    check('...and the accesses are overwhelmingly 32-bit (not 131k byte cycles)',
          sum(1 for l in _win if l[1] == '4') > 0.99 * len(_win)
          and 60000 < len(_win) < 70000)

    # --- phase $19xx: bit 4 is the 16-bit-access enable ----------------------
    check('$F09806 writes a longword then a WORD over its high half',
          d[0xF09806-0xF00000:0xF0980C-0xF00000]
          == b'\x20\x80\x30\x81\xb4\x90')
    check('$F0981A writes XLTR_DATA_LO then reads the word at $400002',
          d[0xF0981A-0xF00000:0xF09824-0xF00000]
          == b'\x20\x80\x3d\x41\x02\x14\xb4\x68\x00\x02')
    check('phase $1901 expects $AAAA5555 with bit 4 set, $1902 $55555555 without',
          struct.unpack('>I', d[0xF097B2-0xF00000+2:0xF097B2-0xF00000+6])[0]
              == 0xAAAA5555
          and d[0xF097B8-0xF00000:0xF097BE-0xF00000]
              == b'\x3d\x7c\x00\x10\x02\x16')
    check('phase $1900 round-trips a full longword through $400000',
          d[0xF09798-0xF00000:0xF0979C-0xF00000] == b'\x20\x80\xb0\x90')
    check('the word-access rules gate on bit 4 AND bit 5 clear, not data_hi == 0',
          open('emulator/fps3k_sbc.c').read().count(
              'versabus_xltr_data_hi() & 0x30') == 2)

    # --- phase $18xx: bit 6 is transparent, all four combinations -----------
    for _ph, _at, _val, _probe in (('$1800', 0xF096E8, 0x40, 'read'),
                                   ('$1802', 0xF0972E, 0x40, 'write')):
        check(f'phase {_ph} sets $FF0216 bit 6 for the {_probe} probe',
              d[_at-0xF00000:_at-0xF00000+6]
              == bytes([0x3d, 0x7c, 0x00, _val, 0x02, 0x16]))
    # all four $18xx phases branch on beq (require d1 == 0, i.e. NO fault)
    check('all four $18xx phases require NO fault (beq, not bne)',
          all(d[a2-0xF00000:a2-0xF00000+4] == b'\x4a\x41\x67\x06'
              for a2 in (0xF096F2, 0xF09714, 0xF09738, 0xF0975A)))
    check('...whereas $17xx and $1Axx require a fault on their set case (bne)',
          d[0xF0962E-0xF00000:0xF09632-0xF00000] == b'\x4a\x41\x66\x06'
          and d[0xF09854-0xF00000:0xF09856-0xF00000] == b'\x66\x06')

    # --- phase $1Axx: $FF0216 bit 7 is the AP I/F bus-error enable ------------
    check('phase $1A00 sets $FF0216 bit 7 and requires a fault',
          d[0xF0984C-0xF00000:0xF09856-0xF00000]
          == b'\x3d\x7c\x00\x80\x02\x16\x61\x70\x66\x06')
    check('phase $1A02 clears it and requires NO fault',
          d[0xF098A0-0xF00000:0xF098A8-0xF00000]
          == b'\x42\x6e\x02\x16\x61\x1e\x67\x06')
    check('phase $1A01: $FF000E round-trips $AAAA with STATUS_IRQ cleared',
          d[0xF09878-0xF00000:0xF09888-0xF00000]
          == b'\x42\x6e\x02\x18\x3d\x7c\xaa\xaa\x00\x0e'
             b'\x0c\x6e\xaa\xaa\x00\x0e')
    check('the emulator gates AP I/F BERR on bit 7, not on data_hi != 0',
          'xltr.data_hi & 0x80' in open('emulator/versabus.c').read())

    # --- phase $1700 specifies the $400000 BERR gate, both polarities --------
    check('phase $1700 requires a fault with $FF0216 bit 5 SET',
          d[0xF09626-0xF00000:0xF09632-0xF00000]
          == b'\x3d\x7c\x00\x20\x02\x16\x61\x7e\x4a\x41\x66\x06')
    check('...and NO fault with bit 5 CLEAR',
          d[0xF09648-0xF00000:0xF09652-0xF00000]
          == b'\x42\x6e\x02\x16\x61\x5e\x4a\x81\x67\x06')
    check('the probes are a word READ and a word WRITE, each padded with four NOPs',
          d[0xF096AC-0xF00000:0xF096B8-0xF00000]
              == b'\x30\x11\x4e\x71\x4e\x71\x4e\x71\x4e\x71\x4e\x75'
          and d[0xF096B8-0xF00000:0xF096C4-0xF00000]
              == b'\x42\x51\x4e\x71\x4e\x71\x4e\x71\x4e\x71\x4e\x75')
    check('a temporary bus-error vector is installed at $8 and restored',
          d[0xF096CC-0xF00000:0xF096D4-0xF00000]
              == b'\x21\xfc\x00\xf0\x98\xe0\x00\x08'
          and d[0xF096A2-0xF00000:0xF096A6-0xF00000] == b'\x21\xc8\x00\x08')
    check('...and it resumes at saved-PC + 4, which is why the NOPs are there',
          d[0xF098E0-0xF00000:0xF098EA-0xF00000]
          == b'\x72\x01\x4f\xef\x00\x08\x58\x6f\x00\x04')

    # --- the phase beacon is a running counter in d6 -------------------------
    check('the phase beacon writes d6, and clr.b d6 preserves the high byte',
          d[0xF098F0-0xF00000:0xF098F6-0xF00000] == b'\x42\x06\x3d\x46\x02\x04')
    check('the base is bumped by $100 between sub-tests',
          d[0xF08996-0xF00000:0xF0899A-0xF00000] == b'\x06\x46\x01\x00'
          and d[0xF089A0-0xF00000:0xF089A4-0xF00000] == b'\x06\x46\x01\x00')
    check('$F098EC (the RAM test) is called from exactly ONE site, $F08992',
          [a2 for a2 in range(0xF08700, 0xF0A000, 2)
           if struct.unpack('>H', d[a2-0xF00000:a2-0xF00000+2])[0] == 0x6100
           and a2 + 2 + struct.unpack('>h', d[a2-0xF00000+2:a2-0xF00000+4])[0]
               == 0xF098EC] == [0xF08992])
    check('...so $20xx and $24xx are the same code twice, not distinct tests',
          d[0xF098EC-0xF00000:0xF098F0-0xF00000] == b'\x48\xe7\x80\xe0')
    check('phase $01xx is the CPU register test: moveq #$FF then a $FFFFFFFF compare',
          d[0xF08A6E-0xF00000:0xF08A78-0xF00000]
          == b'\x7e\xff\x0c\x87\xff\xff\xff\xff\x67\x06')
    check('...and it walks the value through the USER STACK POINTER',
          d[0xF08AD2-0xF00000:0xF08AD8-0xF00000] == b'\x4e\x65\x24\x4c\x4e\x6b')

    # --- the panel-code space is partitioned by owning task -----------------
    def _regions_of(v):
        RG = [(0xF04600, 0xF05D00, 'RDHC'), (0xF05D00, 0xF05F4A, 'IO1I'),
              (0xF05F4A, 0xF0694A, 'XP4'), (0xF0694A, 0xF0734A, 'XP3'),
              (0xF0734A, 0xF07D4A, 'XP2'), (0xF07D4A, 0xF0874A, 'XP1'),
              (0xF09C00, 0xF0A600, 'init')]
        out = set()
        for a2 in range(0xF04400, 0xF0A800, 2):
            if struct.unpack('>H', d[a2-0xF00000:a2-0xF00000+2])[0] \
                    not in (0x303C, 0x323C, 0x203C, 0x223C, 0x0641, 0x0640):
                continue
            if struct.unpack('>H', d[a2-0xF00000+2:a2-0xF00000+4])[0] != v:
                continue
            for lo, hi, n in RG:
                if lo <= a2 < hi:
                    out.add(n)
        return out
    check('$258-$260 are RDHC-only (so the CH1..CH4 labels are unsupported)',
          all(_regions_of(v) == {'RDHC'} for v in (0x258, 0x259, 0x25A, 0x25C,
                                                   0x25D, 0x25E, 0x25F, 0x260)))
    check('$262/$263/$264 are XP-task-only',
          all(_regions_of(v) == {'XP1', 'XP2', 'XP3', 'XP4'}
              for v in (0x262, 0x263, 0x264)))
    check('$269-$26C are the shared group: RDHC AND all four XP tasks',
          all(_regions_of(v) == {'RDHC', 'XP1', 'XP2', 'XP3', 'XP4'}
              for v in (0x269, 0x26A, 0x26B, 0x26C)))
    check('$27E-$280 are IO1I-only and $29E-$2A6 are RTOS-init-only',
          all(_regions_of(v) == {'IO1I'} for v in (0x27E, 0x27F, 0x280))
          and all(_regions_of(v) == {'init'} for v in range(0x29E, 0x2A7)))
    check('$25B (named PCMD_CH1_FLUSH), $261, $26F and $27C are never issued',
          all(_regions_of(v) == set() for v in (0x25B, 0x261, 0x26F, 0x27C)))

    # --- seven undocumented panel codes $262-$268 ---------------------------
    def _code_sites(v):
        return [a2 for a2 in range(0xF04400, 0xF0A800, 2)
                if struct.unpack('>H', d[a2-0xF00000:a2-0xF00000+2])[0]
                   in (0x303C, 0x323C, 0x0641)
                and struct.unpack('>H', d[a2-0xF00000+2:a2-0xF00000+4])[0] == v]
    check('$262 has one site per XP task, in the ISR prologue',
          _code_sites(0x262) == [0xF060C0, 0xF06AD8, 0xF074D8, 0xF07ED8])
    check('$263 has one site per XP task (the channel reject)',
          _code_sites(0x263) == [0xF066A0, 0xF070B8, 0xF07AB8, 0xF084B8])
    check('$264 has two sites per XP task, one of them addi.w #$264,d1',
          len(_code_sites(0x264)) == 8
          and d[0xF084DA-0xF00000:0xF084DE-0xF00000] == b'\x06\x41\x02\x64')
    check('$261 is used nowhere (the per-channel runs are four wide)',
          _code_sites(0x261) == [])
    check("RDHC's dispatch copy is ~180 bytes shorter: all zeros from $F05C52",
          not any(d[0xF05C52-0xF00000:0xF05D00-0xF00000])
          and any(d[0xF084AA-0xF00000:0xF08558-0xF00000]))
    check('the extra XP routine validates the channel then issues directive $10',
          d[0xF084AA-0xF00000:0xF084B8-0xF00000]
              == b'\x0c\x40\x00\x01\x6d\x08\xb0\x79\x00\x00\x10\x5e\x6f\x0a'
          and d[0xF084CE-0xF00000:0xF084D8-0xF00000]
              == b'\x70\x10\x41\xf9\x00\xf0\x7d\x40\x4e\x41')

    # --- the XP-task template: alignment and the per-channel scan mask -------
    BODY = {1: 0xF07E12, 2: 0xF07412, 3: 0xF06A12, 4: 0xF06018}
    _ref = d[BODY[1]-0xF00000:BODY[1]-0xF00000+0x900]
    def _nd(sh, base):
        o = base - 0xF00000 + sh
        return sum(1 for x, y in zip(_ref, d[o:o+0x900]) if x != y)
    check('XP2I and XP3I align with XP1I at zero shift, ~71 bytes differing',
          _nd(0, BODY[2]) < 90 and _nd(0, BODY[3]) < 90)
    check('XP4I aligns at -$1E (not -$18), and it is an unambiguous minimum',
          _nd(-0x1E, BODY[4]) < 300
          and min(_nd(s, BODY[4]) for s in range(-0x100, 0x101, 2)
                  if s != -0x1E) > 1500)
    check('the per-channel scan mask is one nibble per channel, own cleared',
          [struct.unpack('>I', d[a2-0xF00000+2:a2-0xF00000+6])[0]
           for a2 in (0xF07E3C, 0xF0743C, 0xF06A3C, 0xF06042)]
          == [0xFFF0, 0xFF0F, 0xF0FF, 0x0FFF])
    # btst.b #$7,d2 / beq.b +$10 sits immediately before each mask load
    check('...each guarded on MODE1 bit 7 (btst #7,d2 / beq just above the mask)',
          all(d[a2-0xF00000-6:a2-0xF00000] == b'\x08\x02\x00\x07\x67\x10'
              for a2 in (0xF07E3C, 0xF0743C, 0xF06A3C, 0xF06042)))

    # --- not Pascal either: zero CHK in the application ---------------------
    check('zero CHK instructions in the FPS application (Pascal range checks)',
          not any((struct.unpack('>H', d[i:i+2])[0] & 0xF1C0) == 0x4180
                  for i in range(0xF04488-0xF00000, 0xF0A600-0xF00000, 2)))

    # --- no compiled C; the a6 idiom is a structure pointer -----------------
    check('there is not one link/unlk pair in the entire 64 KB ROM',
          not any(struct.unpack('>H', d[i:i+2])[0] in (0x4E56, 0x4E5E)
                  for i in range(0, len(d) - 1, 2)))
    check('RDHC command descriptor: +$08 -> d2 (count), +$0C -> d1 (payload), '
          '+$10 -> d3, +$14 -> a2 (inline buffer)',
          d[0xF05446-0xF00000:0xF0544A-0xF00000] == b'\x22\x2e\x00\x0c'
          and d[0xF0544A-0xF00000:0xF0544E-0xF00000] == b'\x45\xee\x00\x14'
          and d[0xF05460-0xF00000:0xF05464-0xF00000] == b'\x24\x2e\x00\x08'
          and d[0xF05464-0xF00000:0xF05468-0xF00000] == b'\x26\x2e\x00\x10')
    check('the four XP tasks share one a6 prologue-block layout',
          all(d[a2-0xF00000:a2-0xF00000+2] == b'\x2c\x48'
              for a2 in (0xF05F68, 0xF06968, 0xF07368, 0xF07D68)))

    # --- $FF0212 IS a register: phase $1600 writes and reads it back --------
    # Settled by FPS3K_ACCESSLOG (true CPU-level widths).  The static sweep said
    # "not a register", the bus log said "undocumented register", and an
    # adjacency argument said "longword-split artefact"; only the width log was
    # right.  Phase $1600 walks $210-$216 with $10/$20/$40/$80 via INDEXED
    # addressing, which is why no static search for $212(aN) found anything.
    check('phase $1600 walks four registers from $210 with a walking-ones pattern',
          d[0xF09558-0xF00000:0xF0956C-0xF00000]
          == b'\x30\x3c\x00\x10\x30\x7c\x02\x10\x3d\x80\x80\x00'
             b'\x41\xe8\x00\x02\xe3\x08\x64\xf4')
    check('...and reads them back, failing to $F095E8 on mismatch',
          d[0xF095C0-0xF00000:0xF095CE-0xF00000]
          == b'\xb0\x76\x80\x00\x66\x22\x41\xe8\x00\x02\xe3\x08\x64\xf2')
    check('phase $1600 checks MODE0 masked $FF and STATUS_IRQ masked $610 == $400',
          d[0xF09594-0xF00000:0xF09598-0xF00000] == b'\x02\x40\x00\xff'
          and d[0xF095A6-0xF00000:0xF095AE-0xF00000]
              == b'\x02\x40\x06\x10\x0c\x40\x04\x00')
    # Runtime evidence that $FF0212 has storage: a 2-byte write of $0020 followed
    # by a 2-byte read-back of $0020, and no 32-bit access anywhere in the XLTR
    # block (which is what refuted the longword-split explanation).
    import tempfile as _tf
    _al = _tf.mktemp()
    run_err({'FPS3K_ACCESSLOG': _al}, CYC)
    _lines = [l.split() for l in open(_al) if l[:1] in 'RW']
    _x = [l for l in _lines if l[2] == 'FF0212']
    check('$FF0212: a 2-byte write of $0020 and a 2-byte read-back of $0020',
          [(l[0], l[1], l[3]) for l in _x]
          == [('W', '2', '00000020'), ('R', '2', '00000020')])
    check('...and NO 32-bit access anywhere in $FF0200-$FF025F',
          not [l for l in _lines
               if l[1] == '4' and 0xFF0200 <= int(l[2], 16) <= 0xFF025F])
    check('the hottest address in the machine is $F70019, not $FF0204',
          sum(1 for l in _lines if l[2] == 'F70019')
          > 10 * sum(1 for l in _lines if l[2] == 'FF0204'))

    # --- the XLTR block: $FF0212 is a logging artefact, not a register -------
    check('the $F0A086 "$12(a3)" sites walk the TDTI table, not the XLTR',
          d[0xF0A06E-0xF00000:0xF0A074-0xF00000]
              == b'\x20\x3c\x21\x54\x43\x42'          # move.l #'!TCB',d0
          and d[0xF0A086-0xF00000:0xF0A08A-0xF00000] == b'\x18\x2b\x00\x12')
    check('chassis op $7 read-modify-writes $FF0230, so BIM CRs are NOT write-only',
          d[0xF04F3A-0xF00000:0xF04F46-0xF00000]
          == b'\x32\x28\x02\x30\x08\x81\x00\x04\x31\x41\x02\x30')

    # --- $FF0010 is never accessed; $FF000E is the panel command port --------
    for _cfg in ({}, {'FPS3K_RESP': '0x94', 'FPS3K_XPIRQ': '6'},
                 {'FPS3K_XPIRQ': '1,2,3,4', 'FPS3K_CHANNELS': '4'}):
        _e = dict(_cfg); _e['FPS3K_PCLOG'] = '1'
        check('$FF0010 (APIF_CMD_ARG_HI) is never accessed: %s'
              % (','.join(f'{k}={v}' for k, v in _cfg.items()) or 'default'),
              'FF0010' not in run_err(_e, CYC))
    check('...while $FF000E IS accessed in the same run (the check can fire)',
          'FF000E' in run_err({'FPS3K_PCLOG': '1'}, CYC))
    check('$FF0010 appears nowhere in the ROM as an absolute address',
          b'\x00\xff\x00\x10' not in d)
    check('the emulator still defines APIF_CMD_ARG_HI -- a modelled non-register',
          '0xFF0010' in open('emulator/versabus.h').read())
    check('$FF00FF in the ROM is a RAM-test DATA pattern, not an address',
          d[0xF0998E-0xF00000:0xF0999A-0xF00000]
          == b'\x20\x3c\x00\xff\x00\xff\x61\x22\x46\x80\x61\x1e')

    # --- the channel window is exactly four registers ------------------------
    # Each ISR reads +$0E, +$08, +$0A in that order into a 6-byte record, and the
    # task body clears +$04.  No other offset in any 32-byte window is touched.
    for ch, (sts, dhi, dlo, rec) in enumerate(
            [(0xF07EEE, 0xF07EF6, 0xF07EFE, 0x1066),
             (0xF074EE, 0xF074F6, 0xF074FE, 0x106C),
             (0xF06AEE, 0xF06AF6, 0xF06AFE, 0x1072),
             (0xF060D6, 0xF060DE, 0xF060E6, 0x1078)], 1):
        off = 0x40 + 0x20 * (ch - 1)
        # Check the displacement and destination fields directly rather than a
        # whole byte string: the opcode is the same in all four copies and only
        # the displacement and destination differ, so this is what varies.
        ok = (struct.unpack('>H', d[sts-0xF00000+2:sts-0xF00000+4])[0] == off + 0x0E
              and struct.unpack('>I', d[sts-0xF00000+4:sts-0xF00000+8])[0] == rec
              and struct.unpack('>H', d[dhi-0xF00000+2:dhi-0xF00000+4])[0] == off + 0x08
              and struct.unpack('>I', d[dhi-0xF00000+4:dhi-0xF00000+8])[0] == rec + 2
              and struct.unpack('>H', d[dlo-0xF00000+2:dlo-0xF00000+4])[0] == off + 0x0A
              and struct.unpack('>I', d[dlo-0xF00000+4:dlo-0xF00000+8])[0] == rec + 4)
        check(f'ch{ch} ISR snapshots +$0E/+$08/+$0A into the 6-byte record ${rec:04X}',
              ok)

    # --- $FF004A IS read: each channel ISR takes both halves of the pair ----
    check('each channel ISR reads its data LOW half into the per-channel record',
          d[0xF07EFE-0xF00000:0xF07F06-0xF00000]
              == b'\x33\xed\x00\x4a\x00\x00\x10\x6a'
          and d[0xF074FE-0xF00000:0xF07506-0xF00000]
              == b'\x33\xed\x00\x6a\x00\x00\x10\x70'
          and d[0xF06AFE-0xF00000:0xF06B06-0xF00000]
              == b'\x33\xed\x00\x8a\x00\x00\x10\x76'
          and d[0xF060E6-0xF00000:0xF060EE-0xF00000]
              == b'\x33\xed\x00\xaa\x00\x00\x10\x7c')
    tio = pcs({'FPS3K_XPIRQ': '1'}, CYC)
    check('...and it EXECUTES -- $FF004A is not "neither read nor written"',
          tio.count('F07EF6') > 300 and tio.count('F07EFE') > 300)
    tall = pcs({'FPS3K_XPIRQ': '1,2,3,4', 'FPS3K_CHANNELS': '4'}, CYC)
    check('...for all four channels with a 4-channel chassis',
          all(tall.count(p2) > 300
              for p2 in ('F07EFE', 'F074FE', 'F06AFE', 'F060E6')))
    # the four per-channel longword arrays are exactly $10 apart
    check('$10AE/$10BE/$10CE/$10DE are four 4-entry longword arrays, $10 apart',
          d[0xF08572-0xF00000+2:0xF08572-0xF00000+4] == b'\x10\xae'
          and d[0xF0859A-0xF00000+2:0xF0859A-0xF00000+4] == b'\x10\xbe')

    # --- the seventh task: USER, never created ------------------------------
    check('each XP task pushes the literal \'USER\' and issues directive $43',
          d[0xF08586-0xF00000:0xF0858E-0xF00000]
          == b'\x2f\x3c\x55\x53\x45\x52\x70\x43')
    check('...at exactly four sites, one per XP task',
          [a2 for a2 in range(0xF04400, 0xF0A800, 2)
           if struct.unpack('>H', d[a2-0xF00000:a2-0xF00000+2])[0] == 0x7043]
          == [0xF06774, 0xF0718C, 0xF07B8C, 0xF0858C])
    check('...gated on the per-channel longword $10AE, result filed at $10BE',
          d[0xF08572-0xF00000:0xF08578-0xF00000] == b'\x4a\xaa\x10\xae\x67\x00'
          and d[0xF0859A-0xF00000:0xF0859E-0xF00000] == b'\x25\x40\x10\xbe')
    check("the name table at $F0467E is XP1I..XP4I then USER twice",
          [d[0xF0467E-0xF00000+8*i:0xF0467E-0xF00000+8*i+4] for i in range(6)]
          == [b'XP1I', b'XP2I', b'XP3I', b'XP4I', b'USER', b'USER'])
    check('...but no USER task exists: TDTI creates only the six known names',
          [d[0xF0A600-0xF00000+0x60*i+4:0xF0A600-0xF00000+0x60*i+8] for i in range(6)]
          == [b'RDHC', b'IO1I', b'XP4I', b'XP3I', b'XP2I', b'XP1I'])
    check('d7 is written 9 times: once in RDHC, twice per XP task',
          [a2 for a2 in range(0xF04400, 0xF0A800, 2)
           if struct.unpack('>H', d[a2-0xF00000:a2-0xF00000+2])[0] == 0x3E00]
          == [0xF056C4, 0xF06104, 0xF06752, 0xF06B1C, 0xF0716A,
              0xF0751C, 0xF07B6A, 0xF07F1C, 0xF0856A])
    check('...and cmpi.w #$A,d7 appears exactly 5 times, one per dispatch copy',
          [a2 for a2 in range(0xF04400, 0xF0A800, 2)
           if struct.unpack('>H', d[a2-0xF00000:a2-0xF00000+2])[0] == 0x0C47
           and struct.unpack('>H', d[a2-0xF00000+2:a2-0xF00000+4])[0] == 0x000A]
          == [0xF05AD2, 0xF06512, 0xF06F2A, 0xF0792A, 0xF0832A])
    _, ru = run({}, CYC)
    check('on this ROM alone $10AE and $10BE stay zero for all four channels',
          not any(ru[0x10AE:0x10BE]) and not any(ru[0x10BE:0x10CE]))

    # --- RESOLVED: $0A is distinguished by d7, the preserved operation code --
    check('PanelSendAndWait preserves the operation code in d7 ($F056C4)',
          d[0xF056C4-0xF00000:0xF056C6-0xF00000] == b'\x3e\x00')
    check('...and that is the ONLY write to d7 in all of RDHC $F04600-$F05CFF',
          sum(1 for a2 in range(0xF04600, 0xF05D00, 2)
              if struct.unpack('>H', d[a2-0xF00000:a2-0xF00000+2])[0]
              in (0x3E00, 0x3E80, 0x2E00, 0x3E3C, 0x7E00)) == 1)
    check('POLL exits via MODE1 bit 7 then cmpi.w #$A,d7 -- the $0A special case',
          d[0xF05AC8-0xF00000:0xF05AD4-0xF00000]
          == b'\x3a\x2c\x02\x02\x08\x05\x00\x07\x66\x1e\x0c\x47')
    check('...and the $0A path drains bit 15 then checks the error bit 13',
          d[0xF05AD8-0xF00000:0xF05AE4-0xF00000]
          == b'\x38\x10\x08\x04\x00\x0f\x66\xf8\x08\x04\x00\x0d')

    # --- POLL is BLK_XFR's mirror; D1_SEND has a fire-and-forget exit --------
    check('POLL opens with the same swap d0 mode trick as BLK_XFR',
          d[0xF05A12-0xF00000:0xF05A14-0xF00000] == b'\x48\x40')
    check('...and the same $FF0008 special case, here on the SOURCE',
          d[0xF05A1A-0xF00000:0xF05A20-0xF00000] == b'\x4b\xec\x00\x08\xbb\xca')
    check('...it sets XLTR_COUNTER = $04 only for a bulk-port source',
          d[0xF05A2C-0xF00000:0xF05A32-0xF00000] == b'\x39\x7c\x00\x04\x02\x0c')
    check('...its inner loop arms $218 = $400 and polls bit 15',
          d[0xF05A3C-0xF00000:0xF05A48-0xF00000]
          == b'\x39\x7c\x04\x00\x02\x18\x38\x2c\x02\x18\x08\x04')
    check('...and it moves SOURCE -> channel pair, the reverse of BLK_XFR',
          d[0xF05A52-0xF00000:0xF05A5C-0xF00000]
          == b'\x3c\x12\x32\x86\x0c\x40\x00\x00\x66\x22')
    check('D1_SEND splits d1 into two halves across the channel data pair',
          d[0xF058B2-0xF00000:0xF058BC-0xF00000]
          == b'\x48\x41\x32\x81\x48\x41\x33\x41\x00\x02')
    check('...then $8004, and takes a fire-and-forget exit when d0 low word == 4',
          d[0xF058BC-0xF00000:0xF058C4-0xF00000]
          == b'\x30\xbc\x80\x04\x0c\x40\x00\x04')
    check('...that exit restores the BIM CR to $5F (re-enabling the interrupt)',
          d[0xF058DE-0xF00000:0xF058E2-0xF00000] == b'\x36\xbc\x00\x5f')

    # --- directives $29/$2A are ASQ name-lookup and post --------------------
    check('$F05652 builds a 10-byte {name, longword, word} block on the stack',
          d[0xF05654-0xF00000:0xF05660-0xF00000]
          == b'\x3f\x3c\x00\x02\x2f\x3c\x00\x00\x00\x00\x2f\x01')
    check('...then TRAP #1 directive $29 (look up by name) and $2A (post)',
          d[0xF05662-0xF00000:0xF05666-0xF00000] == b'\x70\x29\x4e\x41'
          and d[0xF0566C-0xF00000:0xF05670-0xF00000] == b'\x70\x2a\x4e\x41')
    check('...storing the handle $29 returned in a0 back into the block at +$4',
          d[0xF05666-0xF00000:0xF0566A-0xF00000] == b'\x2f\x48\x00\x04')
    check('...and the block is discarded with lea $A(a7),a7 -- 10 bytes',
          d[0xF05670-0xF00000:0xF05674-0xF00000] == b'\x4f\xef\x00\x0a')
    check('the S2/S3 handler picks the address width from d4 (2 -> 1 word, 3 -> 2)',
          d[0xF055FC-0xF00000:0xF05600-0xF00000] == b'\x0c\x44\x00\x02'
          and d[0xF05608-0xF00000:0xF0560C-0xF00000] == b'\x0c\x44\x00\x03'
          and d[0xF05602-0xF00000:0xF05606-0xF00000] == b'\x3a\x3c\x00\x00'
          and d[0xF0560E-0xF00000:0xF05612-0xF00000] == b'\x3a\x3c\x00\x10')
    check('...rejects other record types with panel $260',
          struct.unpack('>H', d[0xF05614-0xF00000+2:0xF05614-0xF00000+4])[0] == 0x260)
    check('...and applies the same +$10000 staging offset, storing to $E7E',
          d[0xF05640-0xF00000:0xF05646-0xF00000] == b'\xd3\xfc\x00\x01\x00\x00'
          and d[0xF05646-0xF00000:0xF0564C-0xF00000] == b'\x23\xc9\x00\x00\x0e\x7e')

    # --- BLK_XFR: the bulk mover, mode from the swapped high word of d0 -----
    check('BLK_XFR opens with swap d0 -- the HIGH word carries the mode',
          d[0xF05B0E-0xF00000:0xF05B10-0xF00000] == b'\x48\x40')
    check('...it checks whether the DESTINATION is the bulk port $FF0008',
          d[0xF05B16-0xF00000:0xF05B1C-0xF00000] == b'\x4b\xec\x00\x08\xbb\xca')
    check('...and only then waits on $FF0004 bit 0 (outbound flow control)',
          d[0xF05B1E-0xF00000:0xF05B28-0xF00000]
          == b'\x38\x2c\x00\x04\x08\x04\x00\x00\x67\xf6')
    check('...mode 0 writes both halves to (a2); mode !=0 uses a2+2 and adds 4',
          d[0xF05B36-0xF00000:0xF05B3C-0xF00000] == b'\x3c\x29\x00\x02\x34\x86'
          and d[0xF05B3E-0xF00000:0xF05B48-0xF00000]
              == b'\x3c\x29\x00\x02\x35\x46\x00\x02\x58\x8a')
    check('...and re-arms $8004 once per WORD PAIR, not once per transfer',
          d[0xF05B48-0xF00000:0xF05B4C-0xF00000] == b'\x30\xbc\x80\x04'
          and d[0xF05B82-0xF00000:0xF05B86-0xF00000] == b'\xb2\x82\x6f\xa6')
    check('the op-$14 caller loads d0 = $FFFF000F: mode $FFFF, dispatch index $0F',
          d[0xF05422-0xF00000:0xF0542C-0xF00000]
          == b'\x30\x3c\xff\xff\x48\x40\x30\x3c\x00\x0f')

    # --- op $5 is XPSEL: it WRITES $E60/$E62 --------------------------------
    check('op $5 stores CHANNEL_SELECT into $E60/$E62 (it is XPSEL, not just a check)',
          d[0xF04F16-0xF00000:0xF04F1C-0xF00000]
              == b'\x42\x79\x00\x00\x0e\x60'
          and d[0xF04F1C-0xF00000:0xF04F24-0xF00000]
              == b'\x33\xe8\x02\x04\x00\x00\x0e\x62')
    check('...and $E60 is what op $4 validates and cmd 1 defaults from',
          d[0xF04E3A-0xF00000:0xF04E40-0xF00000] == b'\x22\x39\x00\x00\x0e\x60'
          and d[0xF0537E-0xF00000:0xF05384-0xF00000] == b'\x38\x39\x00\x00\x0e\x62')
    # every operation is individually reachable; long sequences drop their tail
    reach = []
    for op in (0x00, 0x03, 0x06, 0x0A, 0x0B, 0x0E):
        entry = {0x00: 'F04A84', 0x03: 'F04D4E', 0x06: 'F04F30',
                 0x0A: 'F04FBA', 0x0B: 'F05002', 0x0E: 'F050CA'}[op]
        reach.append(run({'FPS3K_SEQ': f'{op:02X}:0001'},
                         CYC)[0].split('\n').count(entry) >= 1)
    check('each chassis operation IS reachable on its own (6 sampled of 16)',
          all(reach))
    long_seq = ('05:0001,45:0000,01:1000,41:0000,02:0008,42:0000,09:0001,49:0000,'
                '04:0001,0D:0001,08:0000,0A:0000,0B:0000,0C:0000,03:0001,06:0002,'
                '07:0000,0E:0000,00:0028')
    tl = run({'FPS3K_SEQ': long_seq}, CYC)[0].split('\n')
    check('...but a long sequence silently drops its tail (op $E never arrives)',
          tl.count('F04EE4') >= 1 and tl.count('F050CA') == 0)
    # Compare the DERIVED fact (which operation entry points ran), not raw trace
    # equality -- a 100x smaller gap shifts cycle-level timing, so identical
    # traces was never what the measurement showed.
    OPENTRY = ('F04A84', 'F04CF2', 'F04D20', 'F04D4E', 'F04E3A', 'F04EE4',
               'F04F30', 'F04F3A', 'F04F52', 'F04FA0', 'F04FBA', 'F05002',
               'F0502C', 'F05092', 'F050CA')
    def ops_of(env):
        tt = run(env, CYC)[0].split('\n')
        return tuple(o for o in OPENTRY if tt.count(o) >= 1)
    # Pinned to the FULL budget: the invariance was measured at 400 M, and at
    # 200 M it does NOT hold -- with only half the cycles a 100x smaller gap does
    # change how many codes get delivered.  So the finding is "at a budget long
    # enough for the SBC to stop issuing commands, pacing is irrelevant", which
    # is the regime that matters; at a short budget pacing binds again.
    def ops_full(env):
        tt = pcs(env, _GOLDEN_CYC)
        return tuple(o for o in OPENTRY if tt.count(o) >= 1)
    check('...and the truncation is arm-driven, not pacing: SEQGAP changes nothing',
          ops_full({'FPS3K_SEQ': long_seq, 'FPS3K_SEQGAP': '200000'})
          == ops_full({'FPS3K_SEQ': long_seq}))

    # --- the XP3I "outlier" is the $105E presence gate ----------------------
    def rpct(env, lo, hi):
        ex = set()
        for ln in run(env, CYC)[0].split('\n'):
            try:
                ex.add(int(ln, 16))
            except ValueError:
                pass
        dd = {a2: n for a2, n in ASM_STARTS.items() if lo <= a2 < hi}
        return 100.0 * sum(dd[a2] for a2 in dd if a2 in ex) / max(1, sum(dd.values()))
    XP3, XP1 = (0xF0694A, 0xF0734A), (0xF07D4A, 0xF0874A)
    check('XP3I roughly triples with a 4-channel chassis (the $105E gate)',
          rpct({'FPS3K_XPIRQ': '3'}, *XP3) < 20
          and rpct({'FPS3K_XPIRQ': '3', 'FPS3K_CHANNELS': '4'}, *XP3) > 30)
    check('...while XP1I is unaffected by the channel count',
          abs(rpct({'FPS3K_XPIRQ': '1'}, *XP1)
              - rpct({'FPS3K_XPIRQ': '1', 'FPS3K_CHANNELS': '4'}, *XP1)) < 1.0)
    _, r4 = run({'FPS3K_CHANNELS': '4'}, CYC)
    _, r2 = run({'FPS3K_CHANNELS': '2'}, CYC)
    check('$105E tracks FPS3K_CHANNELS: 4 and 2 respectively',
          struct.unpack('>H', r4[0x105E:0x1060])[0] == 4
          and struct.unpack('>H', r2[0x105E:0x1060])[0] == 2)

    # --- the 0% pre-task region is kernel-panic and kernel-hook code --------
    check('panel issuer copy 1 $F04500 is called from the kernel panic stub $F001A4',
          struct.unpack('>I', d[0xF001A6-0xF00000:0xF001AA-0xF00000])[0] == 0xF04500)
    check('$F044A2 is a function POINTER stored at $F03FDC and $F040EC, not called',
          struct.unpack('>I', d[0xF03FDC-0xF00000:0xF03FE0-0xF00000])[0] == 0xF044A2
          and struct.unpack('>I', d[0xF040EC-0xF00000:0xF040F0-0xF00000])[0] == 0xF044A2)
    check('...and it walks a driver chain: handler at +$1E, next at +$8',
          d[0xF044C0-0xF00000:0xF044C8-0xF00000]
              == b'\x22\x6d\x00\x1e\x2f\x0d\x4e\x91'   # movea.l $1E(a5),a1 / push a5 / jsr (a1)
          and d[0xF044CC-0xF00000:0xF044D0-0xF00000] == b'\x20\x2d\x00\x08')

    # --- hook defects: POKE ungated, CHCMD suppressing coverage -------------
    check('FPS3K_POKE is gated on boot completion (the DMA10AA defect, repeated)',
          'FPS3K_POKE_FROM_RESET' in open('emulator/fps3k_sbc.c').read())
    # Full budget: the diagnostics need more than 200 M cycles to walk far enough
    # to reach the location that fails, so at CYC the run ends elsewhere.
    ep = run_err({'FPS3K_POKE': '10A0=0002', 'FPS3K_POKE_FROM_RESET': '1'},
                 _GOLDEN_CYC)
    check('...ungated it ends the boot in the RAM test, not the RTOS idle loop',
          'final PC=F098FC' in ep)
    # Assert the SEMANTIC property, not a literal final PC: the exact idle
    # address varies with the rest of the configuration (F00FCC with the RDHC
    # hooks, F00510 with the poke alone), and pinning one of them made this
    # check fail for a reason unrelated to what it is testing.
    _, rg = run({'FPS3K_POKE': '10A0=0002'}, CYC)
    check('...gated it completes boot: all six task ISR vectors installed',
          all(struct.unpack('>I', rg[v:v+4])[0] == hh for v, hh in
              [(0x104, 0xF04930), (0x114, 0xF07EE6), (0x118, 0xF074E6),
               (0x11C, 0xF06AE6), (0x120, 0xF060CE), (0x128, 0xF05DD6)]))
    tpost = run({'FPS3K_RESP': '0x94', 'FPS3K_XPIRQ': '6',
                 'FPS3K_POKE': '10A0=0002',
                 'FPS3K_CHASSIS_CMD': '1,14,1'}, CYC)[0].split('\n')
    check("RDHC's ASQ post to HXP1 ($F05652) executes once the gate is fixed",
          tpost.count('F05652') >= 1 and tpost.count('F053BE') >= 1)

    def region_pct(env, lo, hi):
        ex = set()
        for ln in run(env, CYC)[0].split('\n'):
            try:
                ex.add(int(ln, 16))
            except ValueError:
                pass
        dd = {a2: n for a2, n in ASM_STARTS.items() if lo <= a2 < hi}
        return 100.0 * sum(dd[a2] for a2 in dd if a2 in ex) / max(1, sum(dd.values()))
    xp1 = (0xF07D4A, 0xF0874A)
    bare = region_pct({'FPS3K_XPIRQ': '1'}, *xp1)
    with_c = region_pct({'FPS3K_XPIRQ': '1', 'FPS3K_CHCMD': 'C801'}, *xp1)
    check('FPS3K_CHCMD=C801 SUPPRESSES XP1I coverage (bit 11 short-circuits it)',
          bare > 30 and with_c < bare * 0.65)
    xp4 = (0xF05F4A, 0xF0694A)
    check('...but not XP4I, which never tests bit 11',
          abs(region_pct({'FPS3K_XPIRQ': '4'}, *xp4)
              - region_pct({'FPS3K_XPIRQ': '4', 'FPS3K_CHCMD': 'C801'}, *xp4)) < 1.0)

    # --- executing all 42 operation codes confirms the census ---------------
    # Every slot the jump table decodes as a bare rts must fire NO primitive and
    # give byte-identical coverage; the old census would have predicted 8 of
    # these 13 to do something.
    # SAMPLED, not exhaustive: the full 13 cost ~13 emulator runs and pushed the
    # suite past 10 minutes.  All 13 were verified once by hand (see the access
    # map, "Executing all 42 operation codes"); these 4 are the regression guard.
    RTS_OPS = (0x00, 0x13, 0x21, 0x29)
    prims = ('F05738', 'F058B2', 'F05A12', 'F05B0E')
    quiet = []
    for op in RTS_OPS:
        tro = run({'FPS3K_RESP': '0x94', 'FPS3K_XPIRQ': '6',
                   'FPS3K_CHASSIS_CMD': f'1,{op:X},1'}, CYC)[0].split('\n')
        quiet.append(all(tro.count(pp) == 0 for pp in prims))
    check('sampled rts slots $00/$13/$21/$29 fire NO primitive (4 of 13 checked)',
          all(quiet))
    # ... and a live slot from each handler does fire its own
    live = {0x01: 'F05A12', 0x08: 'F05B0E', 0x14: 'F05738'}
    fired = []
    for op, pp in live.items():
        trl = run({'FPS3K_RESP': '0x94', 'FPS3K_XPIRQ': '6',
                   'FPS3K_CHASSIS_CMD': f'1,{op:X},1'}, CYC)[0].split('\n')
        fired.append(trl.count(pp) >= 1)
    check('...while live slots $01/$08/$14 fire POLL/BLK_XFR/D2_FIN respectively',
          all(fired))
    tr0a = run({'FPS3K_RESP': '0x94', 'FPS3K_XPIRQ': '6',
                'FPS3K_CHASSIS_CMD': '1,A,1'}, CYC)[0].split('\n')
    tr01 = run({'FPS3K_RESP': '0x94', 'FPS3K_XPIRQ': '6',
                'FPS3K_CHASSIS_CMD': '1,1,1'}, CYC)[0].split('\n')
    check('op $0A terminates (POLL once) while op $01 loops, though both are POLL',
          tr0a.count('F05A12') == 1 and tr01.count('F05A12') > 300)

    # --- RDHC's 42-slot table executes; corrected census --------------------
    def slot(i):
        a2 = 0xF05BA4 + 4 * i - 0xF00000
        if struct.unpack('>H', d[a2:a2+2])[0] != 0x4EFA:
            return 'rts' if d[a2:a2+2] == b'\x4e\x75' else '?'
        return {0xF05738: 'D2_FIN', 0xF058B2: 'D1_SEND', 0xF05A12: 'POLL',
                0xF05B0E: 'BLK_XFR'}.get(
                    0xF05BA4 + 4*i + 2 + struct.unpack('>h', d[a2+2:a2+4])[0], '?')
    census = {}
    for i in range(42):
        census[slot(i)] = census.get(slot(i), 0) + 1
    check('42-slot census is POLL 9, D1_SEND 10, BLK_XFR 9, D2_FIN 1, rts 13',
          census == {'POLL': 9, 'D1_SEND': 10, 'BLK_XFR': 9, 'D2_FIN': 1, 'rts': 13})
    check('...D2_FIN is the single finalize code and it is index $14',
          slot(0x14) == 'D2_FIN')
    check('...operation $14 selects index $0F, which is D1_SEND', slot(0x0F) == 'D1_SEND')
    t14 = run({'FPS3K_RESP': '0x94', 'FPS3K_XPIRQ': '6',
               'FPS3K_CHASSIS_CMD': '1,14,1'}, CYC)[0].split('\n')
    check("RDHC's $F0572C EXECUTES (it was recorded as never reached)",
          t14.count('F0572C') >= 1 and t14.count('F05370') >= 1)
    check('...and D1_SEND, POLL and D2_FIN all fire from one command',
          all(t14.count(h2) >= 1 for h2 in ('F058B2', 'F05A12', 'F05738')))
    check('cmd 1 posts to the target task ASQ by name: $48585030 + channel',
          d[0xF053B6-0xF00000:0xF053BE-0xF00000]
          == b'\x22\x3c\x48\x58\x50\x30\xd2\x04')
    # addq.l #1,d3 / lsl.l #5,d3 / addi.l #$FF000E,d3 / movea.l d3,a0
    # ... lea $0(a0),a0 / movea.l a0,a1 / subq.l #6,a1
    check('cmd 1 derives the channel port as (ch+1)<<5 + $FF000E',
          d[0xF053EA-0xF00000:0xF053F4-0xF00000]
          == b'\x52\x83\xeb\x8b\x06\x83\x00\xff\x00\x0e')
    check('...and the channel DATA pair as that port minus 6',
          d[0xF053FA-0xF00000:0xF053FE-0xF00000] == b'\x22\x48\x5d\x89')

    # --- END TO END: CPLOAD stages microcode with no bypass -----------------
    # Chassis presents response $94 + IRQ -> RDHC wakes from its $13 wait ->
    # bit-7 command arm -> fetch record from $400000 -> command 4 (CPLOAD) ->
    # the S1 handler at $F055A2 -> a1 = $10 + addr + $10000 -> store.
    _, ramsr = run({'FPS3K_RESP': '0x94', 'FPS3K_XPIRQ': '6',
                    'FPS3K_CHASSIS_CMD': '4,8,53310004,0000DEAD,BEEF0000'},
                   CYC)
    check('CPLOAD end to end: DEADBEEF lands at $10010 via the firmware itself',
          ramsr[0x10010:0x10014] == b'\xde\xad\xbe\xef')
    check('...and nothing else in the staging buffer is touched',
          not any(ramsr[0x10000:0x10010]) and not any(ramsr[0x10014:0x1DD00]))
    check('the S1 handler seeds a1 = $10 and adds $10000, like $F051A2 does',
          d[0xF055A2-0xF00000:0xF055A8-0xF00000]
              == b'\x22\x7c\x00\x00\x00\x10'
          and d[0xF055C4-0xF00000:0xF055CA-0xF00000]
              == b'\xd3\xfc\x00\x01\x00\x00')   # adda.l #$10000,a1
    check('...and bounds-checks $10000..$1FFFF, rejecting with panel $25A',
          d[0xF055CC-0xF00000:0xF055D4-0xF00000]
              == b'\xb3\xfc\x00\x01\x00\x00\x6d\x0c'
          and struct.unpack('>H', d[0xF055E0-0xF00000+2:0xF055E0-0xF00000+4])[0] == 0x25A)

    # --- what blocks RDHC: the directive-$13 wait ---------------------------
    check("RDHC's main loop is moveq #$13 / trap #1 / btst #7,$E87 / bne",
          d[0xF0473C-0xF00000:0xF04740-0xF00000] == b'\x70\x13\x4e\x41'
          and d[0xF04740-0xF00000:0xF0474C-0xF00000]
              == b'\x08\x39\x00\x07\x00\x00\x0e\x87\x66\x00\x01\x8e')
    tr, _ = run({}, CYC)
    pcs = tr.split('\n')
    check('RDHC enters its $13 wait exactly once and NEVER returns from it',
          pcs.count('F0473C') == 1 and pcs.count('F04740') == 0)
    # The ISR needs its BIM raised to run at all; the default config never
    # raises BIM0 ch0, so assert against the config where the ISR DOES enter.
    tr6 = run({'FPS3K_XPIRQ': '6'}, CYC)[0].split('\n')
    check('...its ISR enters once and its exit stub $F050F8, the only waker, never runs',
          tr6.count('F04930') == 1 and tr6.count('F04A6E') == 1
          and tr6.count('F050F8') == 0 and tr6.count('F04740') == 0)
    check('ChannelConfigDispatch IS $F050F8, an ISR exit stub, not a dispatcher',
          d[0xF050F8-0xF00000:0xF05102-0xF00000]
          == b'\x4c\xdf\xff\xff\x44\xfc\x00\x0c\x4e\x41')
    check('the bit-7 arm $F048D8 tests $E86 & $1F for $14 (command) and $13 (dir $12)',
          d[0xF048D8-0xF00000:0xF048E8-0xF00000]
              == b'\x30\x39\x00\x00\x0e\x86\x02\x40\x00\x1f'
                 b'\x0c\x40\x00\x14\x66\x0c'
          and d[0xF048FE-0xF00000:0xF04902-0xF00000] == b'\x0c\x40\x00\x13')
    check('RDHC fetches its command record from $400000 with MODE2 forced to page 0',
          d[0xF05316-0xF00000:0xF05322-0xF00000]
          == b'\x3b\x7c\x00\x00\x02\x10\x20\x7c\x00\x40\x00\x00')
    err = run_err({'FPS3K_CHASSIS_CMD': '1,1'}, CYC)
    check('FPS3K_CHASSIS_CMD stages the record and says so',
          '[chassis-cmd] 2 longwords served at $400000' in err)

    # --- RDHC UNBLOCKED: the code must be PRESENTED IN MODE0 with the IRQ ----
    # $F04930 latches MODE0 into $E86 and dispatches on its low byte, so raising
    # BIM0 ch0 without also putting a code there left $E86 holding whatever
    # MODE0 happened to be -- which is why every FPS3K_RESP value looked inert.
    t94 = run({'FPS3K_RESP': '0x94', 'FPS3K_XPIRQ': '6'}, CYC)[0].split('\n')
    check('RESP=$94 + IRQ: the bit-7 dispatcher $F0495C runs (it never had before)',
          t94.count('F0495C') > 300 and t94.count('F04A6E') == 0)
    check('...the ISR now returns via $F050F8 and RDHC leaves its $13 wait',
          t94.count('F050F8') > 300 and t94.count('F04740') >= 1)
    check('...and the bit-7 command arm $F048D8 is taken',
          t94.count('F048D8') >= 1)
    t0b = run({'FPS3K_RESP': '0x0B', 'FPS3K_XPIRQ': '6'}, CYC)[0].split('\n')
    check('a benign op ($B) also lets the ISR return and wakes RDHC repeatedly',
          t0b.count('F050F8') > 300 and t0b.count('F04740') > 300)
    # all four RDHC commands now execute
    for num, spec, entry in ((1, '1,1', 'F05370'), (2, '2,0,0,4', 'F054A2'),
                             (3, '3,4,11,22,33,44', 'F054E8'),
                             (4, '4,8,53300000', 'F05502')):
        tc = run({'FPS3K_RESP': '0x94', 'FPS3K_XPIRQ': '6',
                  'FPS3K_CHASSIS_CMD': spec}, CYC)[0].split('\n')
        check(f'RDHC command {num} executes (entry {entry})', tc.count(entry) >= 1)
    tc4 = run({'FPS3K_RESP': '0x94', 'FPS3K_XPIRQ': '6',
               'FPS3K_CHASSIS_CMD': '4,8,53300000'}, CYC)[0].split('\n')
    check('command 4 reaches the S-record type dispatch at $F05522', tc4.count('F05522') >= 1)

    # --- RDHC's four-command host interface ---------------------------------
    check('RDHC dispatcher: cmd number is the FIRST LONGWORD of the block, 1..4',
          d[0xF05322-0xF00000:0xF05324-0xF00000] == b'\x22\x18'   # move.l (a0)+,d1
          and d[0xF0532C-0xF00000:0xF05334-0xF00000]
              == b'\x0c\x81\x00\x00\x00\x04\x6f\x10')
    check('...then andi.w #$7 / subq #1 / mulu #$6 into the table at $F05358',
          d[0xF05344-0xF00000:0xF0534E-0xF00000]
              == b'\x02\x41\x00\x07\x53\x41\xc2\xfc\x00\x06'
          and d[0xF05354-0xF00000:0xF05358-0xF00000] == b'\x4e\xf1\x10\x00')
    check('...the table at $F05358 is 4 x jmp abs.l to $F05370/$F054A2/$F054E8/$F05502',
          [struct.unpack('>I', d[0xF05358-0xF00000+6*i+2:0xF05358-0xF00000+6*i+6])[0]
           for i in range(4)] == [0xF05370, 0xF054A2, 0xF054E8, 0xF05502]
          and all(d[0xF05358-0xF00000+6*i:0xF05358-0xF00000+6*i+2] == b'\x4e\xf9'
                  for i in range(4)))
    check('cmd 4 is CPLOAD: it dispatches on $5330/$5331/$5332/$5333 = S0/S1/S2/S3',
          all(struct.unpack('>H', d[a2-0xF00000+2:a2-0xF00000+4])[0] == v
              for a2, v in ((0xF05522, 0x5330), (0xF05530, 0x5331),
                            (0xF05542, 0x5332), (0xF05548, 0x5333))))
    check('cmd 2 bounds-checks offset+len <= $10 and rejects with panel $25B',
          d[0xF054B4-0xF00000:0xF054BA-0xF00000]
              == b'\x0c\x83\x00\x00\x00\x10'
          and struct.unpack('>I', d[0xF054BC-0xF00000+2:0xF054BC-0xF00000+6])[0] == 0x25B)
    check('cmd 2 is bidirectional: exg.l a1,a0 when the direction flag is nonzero',
          d[0xF054D4-0xF00000:0xF054D6-0xF00000] == b'\xc3\x48')
    check('PanelStatusDispatch index is the CALLER d0: $F0572C is PanelSendAndWait tail',
          d[0xF0572C-0xF00000:0xF05734-0xF00000][:2] == b'\xe5\x48'
          and d[0xF056FE-0xF00000:0xF05704-0xF00000]
              == b'\x08\x04\x00\x0d\x67\x28')
    check('...and the caller takes that d0 from a descriptor at (a6)',
          d[0xF0546E-0xF00000:0xF05474-0xF00000]
          == b'\x20\x16\x0c\x40\x00\x14')   # move.l (a6),d0 / cmpi.w #$14,d0

    # --- the 16-operation chassis command language --------------------------
    TBL = [0xF04A84, 0xF04CF2, 0xF04D20, 0xF04D4E, 0xF04E3A, 0xF04EE4,
           0xF04F30, 0xF04F3A, 0xF04F52, 0xF04FA0, 0xF04FBA, 0xF05002,
           0xF0502C, 0xF05092, 0xF050CA, 0xF050F8]
    def jmptgt(i):
        e = 0xF05102 + 4 * i - 0xF00000
        return 0xF05102 + 4 * i + 2 + struct.unpack('>h', d[e+2:e+4])[0]
    check('$F05102: all 16 jmp d16(pc) targets are the documented handlers',
          [jmptgt(i) for i in range(16)] == TBL)
    check('op $3 reads chassis memory: addr>>$14 to MODE2, (addr&$FFFFF)<<2, base $400000',
          d[0xF04D70-0xF00000:0xF04D78-0xF00000]
              == b'\x74\x14\xe4\xa9\x31\x41\x02\x10'   # moveq $14 / lsr.l d2,d1 / -> MODE2
          and d[0xF04D7E-0xF00000:0xF04D86-0xF00000]
              == b'\x02\x81\x00\x0f\xff\xff\xe5\x89'   # andi.l #$FFFFF / lsl.l #2
          and d[0xF04D88-0xF00000:0xF04D8E-0xF00000]
              == b'\xb3\xfc\x00\x40\x00\x00')            # cmpa.l #$400000,a1
    check('op $6 takes its address from $E58 and reaches the RAM access at $F04EA0',
          d[0xF04F30-0xF00000:0xF04F36-0xF00000] == b'\x22\x79\x00\x00\x0e\x58')
    check('op $6 bit 5 selects read $F04EB8 / write $F04EC0 of SBC RAM',
          d[0xF04EAE-0xF00000:0xF04EB6-0xF00000][:2] == b'\x08\x39'
          and d[0xF04EB8-0xF00000:0xF04EBE-0xF00000] == b'\x33\xd1\x00\x00\x0e\x74'
          and d[0xF04EC0-0xF00000:0xF04EC4-0xF00000] == b'\x32\xa8\x02\x04')
    check('op $B returns the staging base $10000 + $10 = $10010',
          d[0xF05002-0xF00000:0xF0500E-0xF00000]
          == b'\x20\x3c\x00\x01\x00\x00\x06\x80\x00\x00\x00\x10')
    check('op $F is $F050F8, whose exit stub $F050FC is what !IDV gives for RDHC',
          d[0xF050F8-0xF00000:0xF05102-0xF00000]
          == b'\x4c\xdf\xff\xff\x44\xfc\x00\x0c\x4e\x41')
    # the demonstration: op $6 writes SBC RAM from the firmware's own code
    err = run_err({'FPS3K_SEQ': '01:10AA,06:0002', 'FPS3K_RAMWATCH': '10AA'},
                  CYC)
    check('op $6 DEMONSTRATED writing $10AA from $F04EC0 (no bus mastering needed)',
          'write 0010AA <- 00 from PC=F04EC0' in err
          and 'write 0010AB <- 02 from PC=F04EC0' in err)
    check('...and the same route with no op $6 issued writes nothing there',
          'from PC=F04EC0' not in run_err({'FPS3K_RAMWATCH': '10AA'}, CYC))
    check('$F05E12 reads $10AA as a LONGWORD and compares against 2',
          d[0xF05E12-0xF00000:0xF05E18-0xF00000] == b'\x24\x39\x00\x00\x10\xaa'
          and d[0xF05E22-0xF00000:0xF05E28-0xF00000]
              == b'\x0c\x82\x00\x00\x00\x02')

    # --- FPS3K_RTOSDUMP reports the decoded state ---------------------------
    out = run_err({'FPS3K_RTOSDUMP': '1'}, CYC)
    check('FPS3K_RTOSDUMP names all six tasks and their ASQ/stack blocks',
          all(f'{n}  block=' in out for n in
              ('RDHC', 'IO1I', 'XP4I', 'XP3I', 'XP2I', 'XP1I')))
    check('...prints the !IDV interrupt wiring with !VCT owners agreeing',
          all(f'!VCT owner={k}' in out for k in range(1, 7)))
    check('...and reports heap bottom $1DD00, 33 pages, staging $10000-$1DCFF',
          'bottom $1DD00 (33 pages handed out)' in out
          and '$10000-$1DCFF (56576 bytes)' in out)
    check('...and flags the non-task $BF byte at vector $2D rather than '
          'reporting it as task 191', '$2D=flags:$BF' in out)

    # --- the eight RTOS structures, read out of RAM ------------------------
    _, rs = run({}, CYC)
    s16 = lambda x: struct.unpack('>H', rs[x:x+2])[0]
    s32 = lambda x: struct.unpack('>I', rs[x:x+4])[0]
    check('!IDV holds 6 x 14-byte records: {vector, TCB, ISR entry, ISR exit}',
          [(s16(0x1F808+i*14), s32(0x1F808+i*14+2), s32(0x1F808+i*14+6),
            s32(0x1F808+i*14+10)) for i in range(6)] ==
          [(0x45, 0x1E900, 0xF07EE6, 0xF07F08), (0x46, 0x1EB00, 0xF074E6, 0xF07508),
           (0x47, 0x1ED00, 0xF06AE6, 0xF06B08), (0x48, 0x1EF00, 0xF060CE, 0xF060F0),
           (0x4A, 0x1F100, 0xF05DD6, 0xF05E4C), (0x41, 0x1F300, 0xF04930, 0xF050FC)])
    chain, q = [], s32(0x1F704)
    while 0x1F700 <= q < 0x1F800 and len(chain) < 12:
        chain.append(q)
        q = s32(q)
    check('!PAT is a free-list of 8 records, stride $1E, terminating in NULL',
          chain == [0x1F714 + 0x1E * i for i in range(8)] and s32(chain[-1]) == 0)
    check('!UST rich header: 2 pages, $16 records, 9 in use, first at base+$14',
          (s16(0x1FB0A), s16(0x1FB0C), s16(0x1FB0E), s32(0x1FB10)) ==
          (2, 0x16, 9, 0x1FB14))
    check('!UST records are the nine (task, ASQ) pairs, 2+2+2+2+1+0',
          [(rs[0x1FB14+i*0x16:0x1FB18+i*0x16].decode(),
            rs[0x1FB1C+i*0x16:0x1FB20+i*0x16].decode()) for i in range(9)] ==
          [('XP1I', 'AXP1'), ('XP1I', 'HXP1'), ('XP2I', 'AXP2'), ('XP2I', 'HXP2'),
           ('XP3I', 'AXP3'), ('XP3I', 'HXP3'), ('XP4I', 'AXP4'), ('XP4I', 'HXP4'),
           ('IO1I', 'HIO1')])
    check('!GST same header shape, $D records, ZERO in use',
          (s16(0x1FD0A), s16(0x1FD0C), s16(0x1FD0E), s32(0x1FD10)) ==
          (1, 0xD, 0, 0x1FD14))
    check('!IOV and !UDR are tag + end address and hold no records',
          s32(0x1F904) == 0x1F9FF and not any(rs[0x1F908:0x1FA00])
          and not any(rs[0x1F608:0x1F700]))

    # --- $1FA00 is !VCT: byte[vector number] = owning task ----------------
    _, rv = run({}, CYC)
    OWN = {0x41: 6, 0x45: 1, 0x46: 2, 0x47: 3, 0x48: 4, 0x4A: 5}
    check('$1FA00[vector] holds the owning task number for all six TCB vectors',
          all(rv[0x1FA00 + v] == n for v, n in OWN.items()))
    check('...and the four orphan BIM vectors $42/$43/$44/$49 read 0 (unowned)',
          all(rv[0x1FA00 + v] == 0 for v in (0x42, 0x43, 0x44, 0x49)))
    check('vector-map init: lea $28,a2 then one byte per longword up to $400',
          d[0xF09F1C-0xF00000:0xF09F20-0xF00000] == b'\x45\xf8\x00\x28' and
          d[0xF09F2C-0xF00000:0xF09F32-0xF00000] == b'\xb5\xfc\x00\x00\x04\x00')
    check('...preceded by 10 bytes of $FF (vectors 0-9): move.l,move.l,move.w',
          d[0xF09F16-0xF00000:0xF09F1C-0xF00000] == b'\x20\xc2\x20\xc2\x30\xc2')
    check('$1F500 pool header: first = base+8, last = first + 9*$1A',
          struct.unpack('>I', rv[0x1F500:0x1F504])[0] == 0x1F508 and
          struct.unpack('>I', rv[0x1F504:0x1F508])[0] == 0x1F508 + 9 * 0x1A)
    check('pool record size $1A comes from a divu/mulu pair at $F0A03A',
          d[0xF0A03A-0xF00000:0xF0A042-0xF00000] ==
          b'\x84\xfc\x00\x1a\xc4\xfc\x00\x1a')
    check('pool header stores: first at $F0A034, last at $F0A044 (matches RAMWATCH)',
          d[0xF0A034-0xF00000:0xF0A036-0xF00000] == b'\x20\x8a' and
          d[0xF0A044-0xF00000:0xF0A048-0xF00000] == b'\x21\x42\x00\x04')

    # --- the downward page heap ------------------------------------------
    _, rh = run({}, CYC)
    g32 = lambda x: struct.unpack('>I', rh[x:x+4])[0]
    HEAP = [(0x1FD00, 1), (0x1FB00, 2), (0x1FA00, 1), (0x1F900, 1), (0x1F800, 1),
            (0x1F700, 1), (0x1F600, 1), (0x1F500, 1)] + \
           [(0x1F300 - 0x200 * i, 2) for i in range(6)] + \
           [(0x1E700 - 0x200 * i, 2) for i in range(6)]
    top = 0x1FE00
    contig = True
    for b, pg in HEAP:
        if b + pg * 256 != top:
            contig = False
        top = b
    check('heap: 20 allocations tile $1DD00-$1FDFF contiguously, downward', contig)
    check('heap bottom is $1DD00 (not $1DF00 -- RDHC block is allocated, all-zero)',
          top == 0x1DD00 and not any(rh[0x1DD00:0x1DF00]))
    check('every task TCB+$138 points at its own $x00-aligned ASQ/stack block',
          [g32(0x1E900 + 0x200 * i + 0x138) for i in range(6)] ==
          [0x1E700, 0x1E500, 0x1E300, 0x1E100, 0x1DF00, 0x1DD00])
    check('ASQ block nonzero count recovers the declared ASQ count (2,2,2,2,1,0)',
          [sum(1 for x in rh[b:b + 0x200] if x) for b in
           (0x1E700, 0x1E500, 0x1E300, 0x1E100, 0x1DF00, 0x1DD00)] ==
          [12, 12, 12, 12, 6, 0])
    check("first ASQ descriptor is 'AXP1' + longword + word at the block base",
          rh[0x1E700:0x1E70A] == b'AXP1\x00\x00\x00\x14\x00\x02' and
          rh[0x1E70A:0x1E714] == b'HXP1\x00\x00\x00\x2a\x00\x02')

    # --- directive $04 is the page allocator ------------------------------
    ALLOC = [(0xF09E78, 0x0C20), (0xF09EBE, 0x0C24), (0xF09EFE, 0x0C66),
             (0xF09F42, 0x0C6A), (0xF09F70, 0x0C6E), (0xF09FA2, 0x0C2C),
             (0xF09FF0, 0x0C28), (0xF0A020, 0x0C30)]
    check('eight TRAP #0 $04 allocator calls, each storing to its own slot',
          all(struct.unpack('>H', d[a2-0xF00000-2:a2-0xF00000])[0] == 0x7004 and
              struct.unpack('>H', d[a2-0xF00000:a2-0xF00000+2])[0] == 0x4E40
              for a2, _ in ALLOC))
    _, ral = run({}, CYC)
    check('all eight directory slots hold $x00-aligned page addresses',
          all(struct.unpack('>I', ral[g:g+4])[0] & 0xFF == 0 and
              0x1F400 <= struct.unpack('>I', ral[g:g+4])[0] <= 0x1FE00
              for _, g in ALLOC))

    # --- the RTOS scheduler control block ---------------------------------
    TCBP = {0x1E900: 'XP1I', 0x1EB00: 'XP2I', 0x1ED00: 'XP3I',
            0x1EF00: 'XP4I', 0x1F100: 'IO1I', 0x1F300: 'RDHC'}
    _cur = {}
    for _n, _e in (('RDHC', {}), ('XP1I', {'FPS3K_XPIRQ': '1'}),
                   ('XP2I', {'FPS3K_XPIRQ': '2', 'FPS3K_CHANNELS': '4'}),
                   # TCBIO1I needs $10AA=2 as well: XPIRQ=5 alone enters its
                   # ISR but the scheduler never dispatches the TASK, so $00C0C
                   # still reads RDHC.  $00C0C tracks what was DISPATCHED, not
                   # merely whose ISR ran -- which is itself the sharper reading.
                   ('IO1I', {'FPS3K_XPIRQ': '5', 'FPS3K_DMA10AA': '2',
                             'FPS3K_MBOX': '00010000'})):
        _, _rc = run(_e, CYC)
        _cur[_n] = TCBP.get(struct.unpack('>I', _rc[0xC0C:0xC10])[0])
    check('$00C0C is the current-task TCB pointer (4 configurations)',
          all(_cur[k] == k for k in _cur), str(_cur))
    _, _rd = run({}, CYC)
    check('$00C20 onward is a structure directory matching the marker census',
          [struct.unpack('>I', _rd[x:x+4])[0] for x in
           (0xC10, 0xC20, 0xC24, 0xC28, 0xC2C)]
          == [0x1E900, 0x1FD00, 0x1FB00, 0x1F600, 0x1F700])

    # --- golden-master machine state --------------------------------------
    #
    # The pointwise checks above read ~20 specific locations.  The PTM clocking
    # fix showed that is not enough: two models gave IDENTICAL PC counts and
    # final PC while 78 RAM bytes differed, including two !UST entries, and the
    # difference was caught only because one check happened to read that
    # directory.  Post-boot RAM is deterministic (three identical runs give the
    # same digest), so the whole state can be pinned at once.
    #
    # A FAILURE HERE IS NOT NECESSARILY A BUG -- it means machine state changed.
    # If the change is intended, update the digest AND record what moved and why.
    # Do not update it without looking at the diff; that is the whole point.
    GOLDEN = {
        'default (2-AC, no hooks)':
            ({}, '698be0397ed132d519d56cd629236238'),
        # UPDATED 2026-07-29 with the REQUEST-TRANSFER acknowledge.  70 RAM
        # bytes moved and the diff was inspected before this digest changed, per
        # the rule above.  The change is progress, not regression: $00B91 now
        # holds $F05102 (the 16-entry response jump table), $00E6E stages panel
        # code $25C, $00BDB carries $FF0048, and XP1I's TCB and channel snapshot
        # both advance.  Coverage went 116 -> 240 distinct XP1I PCs.
        'XP1I driven to the $8000 path':
            ({'FPS3K_XPIRQ': '1', 'FPS3K_CHCMD': 'C801'},
             'dc7215ad5c2292d2082b75da1a9e171b'),
        'TCBIO1I reply path':
            ({'FPS3K_XPIRQ': '5', 'FPS3K_DMA10AA': '2',
              'FPS3K_MBOX': '00010000'},
             '1eabc593413b4261a6b8bdf71f394813'),
    }
    for _name, (_env, _want) in GOLDEN.items():
        _, _ram = run(_env, _GOLDEN_CYC)
        check('machine-state digest: %s' % _name,
              hashlib.md5(_ram).hexdigest() == _want,
              'got ' + hashlib.md5(_ram).hexdigest())

    # --- the model defaults to the real 2-AC machine ----------------------
    _, rdef = run({}, CYC)
    check('default configuration reports $105E = 2 (AC1+AC2 populated)',
          struct.unpack('>H', rdef[0x105E:0x1060])[0] == 2)
    trdef, _ = run({}, CYC)
    check('by default XP1I and XP2I take the present path, XP3I/XP4I do not',
          'F07E00\n' in trdef and 'F07400\n' in trdef
          and 'F06A00\n' not in trdef)

    # --- hook conflicts are announced, not silent -------------------------
    def warns(env2):
        return subprocess.run([EMU, '-rom', ROM, '-cycles', '1000000'],
                              capture_output=True, text=True,
                              env={**os.environ, **env2}).stderr.count('[WARN]')
    check('all four known hook conflicts warn at startup',
          all(warns(e2) >= 1 for e2 in (
              {'FPS3K_RESP': '2', 'FPS3K_SEQ': '00:0028'},
              {'FPS3K_CHSEL_RD': '28', 'FPS3K_SEQ': '00:0028'},
              {'FPS3K_RESP': '2', 'FPS3K_INJECT': '2'},
              {'FPS3K_MBOX': '1', 'FPS3K_APIF_LEGACY': '1'})))
    check('a clean run emits no hook-conflict warning',
          warns({}) == 0)

    # --- $F0891C is the self-test checkpoint, most-called routine ---------
    check('$F0891C tests d7 and on failure clears VMOD bit 6 + MODE1 $1000',
          d[0x8936:0x894C].hex().upper() ==
          '4A87' + '6718' + '43F90001FFF0' + '08A900060001' + '3D7C10000202')
    check('$F08940 is the only bit-6 operation on the VMOD control register',
          d.count(bytes.fromhex('08A900060001')) == 1)

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
          tsp.count('F05E86\n') > 300 and tsp.count('F04930\n') == 0)
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
    tio, _ = run({'FPS3K_XPIRQ': '5', 'FPS3K_DMA10AA': '2'}, CYC)
    check('TCBIO1I ISR runs at level 7 and returns ($10AA=2, mailbox clear)',
          tio.count('F05DD6\n') > 0 and tio.count('F05E2C\n') > 0
          and tio.count('F05E4C\n') > 0)
    tb29, _ = run({'FPS3K_XPIRQ': '5', 'FPS3K_DMA10AA': '2',
                   'FPS3K_MBOX': '20010000'}, CYC)
    check('mailbox bit 29 set diverts the ISR to the host-request arm',
          tb29.count('F05DFA\n') > 0 and tb29.count('F05E2C\n') == 0)
    chk, _ = run({'FPS3K_DMA10AA': '2', 'FPS3K_DMA10AA_FROM_RESET': '1'},
                 CYC)
    # LIVENESS-GUARDED: "never reaches the scheduler" is satisfied by any ROM
    # that cannot boot.  Require that it DID reach the diagnostics it hangs in.
    check('$10AA from reset reaches the diagnostics but never the scheduler',
          'F00262\n' not in chk
          and len({l for l in chk.split() if 'F08D00' <= l <= 'F09BFF'}) > 100)

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
                  'FPS3K_CHCMD': 'C801'}, CYC)
    check('$8000/$1B sequence fires when command bits 15,14,11 are set',
          trg.count('F07ED0\n') > 0)
    trn, _ = run({'FPS3K_CHANNELS': '2', 'FPS3K_XPIRQ': '1',
                  'FPS3K_CHCMD': 'C001'}, CYC)
    check('...and not with bit 11 clear, though $F07EB6 is still reached',
          trn.count('F07ED0\n') == 0 and trn.count('F07EB6\n') > 0)

    # --- XP4I's ISR is identical; only the $8000 body path differs ------
    tr4, _ = run({'FPS3K_CHANNELS': '4', 'FPS3K_XPIRQ': '4'}, CYC)
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
    tr2, _ = run({'FPS3K_CHANNELS': '2', 'FPS3K_XPIRQ': '1'}, CYC)
    check('XP1I ISR runs when its BIM channel is raised',
          tr2.count('F07EE6\n') > 0 and
          len({l for l in tr2.split() if 'F07D00' <= l <= 'F086FF'}) > 100)
    check('the ISR reads $FF0048 -- via $48(a5), not an absolute address',
          tr2.count('F07EF6\n') > 0 and
          d[0x7EF6:0x7EFE].hex().upper() == '33ED0048' + '00001068')

    # LIVENESS-GUARDED.  "zero error-flag hits" passes trivially on a ROM that
    # never runs the self-tests at all -- a random 64 KB image satisfies it.  An
    # absence claim needs a presence precondition, or it cannot fail.
    _diag = len({l for l in tr.split() if 'F08D00' <= l <= 'F09BFF'})
    check('self-tests ran AND hit zero error flags',
          _diag > 500 and tr.count('F0F0F0F0') == 0 and 'F08B88\n' not in tr)
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
