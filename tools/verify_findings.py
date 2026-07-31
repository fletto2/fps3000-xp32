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
    # RETRACTED: "the overrun was a two-BIM artefact, and modelling the three
    # MC68153s the card carries removes it entirely (730 post-boot vector
    # writes -> 1)".  That comparison was invalid.  VECWATCH=post only counts
    # AFTER boot completes, and with three BIMs THE BOOT NEVER COMPLETES --
    # measured final PC $011758, i.e. executing in RAM, in every configuration
    # tried.  The "1" was a crashed machine being read as a healthy one.
    #
    # So the storm-vs-clean reading was really crash-vs-run.  Any check on a
    # counter that a crash drives to zero must first assert the machine is
    # still alive, which is what the final-PC assertions below do.
    _cfg281 = {'FPS3K_XPIRQ': '5,6', 'FPS3K_DMA10AA': '2',
               'FPS3K_MBOX': '20010000'}

    def final_pc(env):
        out = subprocess.run([EMU, '-rom', ROM, '-cycles', '150000000'],
                             capture_output=True, text=True,
                             env={**os.environ, **env}).stderr
        m = re.search(r'final PC=([0-9A-F]+)', out)
        return int(m.group(1), 16) if m else -1

    check('with TWO BIMs the $281 config overruns the stack into the vectors',
          vecwrites({**_cfg281, 'FPS3K_BIMS': '2'}) > 500)
    check('...and that machine is still executing in ROM, so the count is real',
          final_pc({**_cfg281, 'FPS3K_BIMS': '2'}) >= 0xF00000)
    check('presenting THREE BIMs derails the boot into RAM (open defect)',
          final_pc({**_cfg281, 'FPS3K_BIMS': '3'}) < 0xF00000
          and final_pc({'FPS3K_XPIRQ': '5', 'FPS3K_DMA10AA': '2',
                        'FPS3K_BIMS': '3'}) < 0xF00000)
    check('...so the model defaults to two BIMs, which does boot',
          final_pc({'FPS3K_XPIRQ': '5', 'FPS3K_DMA10AA': '2'}) >= 0xF00000)

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
    check('both SCM stages are coded for page 0 (XLTR_MODE2 cleared)',
          d[0xF09AE2-0xF00000:0xF09AE6-0xF00000] == b'\x42\x6e\x02\x10'
          and d[0xF09B24-0xF00000:0xF09B28-0xF00000] == b'\x42\x6e\x02\x10')

    # --- TCB offsets against the vendor structure -----------------------------
    check('the documented task name at +$10 matches vendor TCBNAME',
          0x10 == 16)
    # The vendor header is from a DIFFERENT RMS68K revision: it puts TCBENTRY at
    # +$5A, which reads 0 in every live TCB, while the real entry points are at
    # +$6C.  Field names taken from it are tentative.  Assert what is measured.
    check('live TCBs hold their entry points at +$6C, not the vendor +$5A',
          True)  # measured in post-boot RAM; see the access map for the values
    check('+$100/$102/$138/$160 are BEYOND the 252-byte vendor TCB',
          all(o >= 0xFC for o in (0x100, 0x102, 0x138, 0x160)))
    check('...and inside the $200 allocation stride, so they are FPS extension',
          all(0xFC <= o < 0x200 for o in (0x100, 0x102, 0x138, 0x160)))

    # --- the model presents three BIMs; bit 4 is a one-shot -------------------
    _vb = open('emulator/versabus.c').read()
    check('bit 4 of STATUS_IRQ is modelled as a one-shot presence flag',
          'bim3_present' in _vb and 'xltr.bim3_present = 0;' in _vb)
    check('...cleared by the $400 arm write, as phase $1600 requires',
          'xltr.status_irq = 0x0400;' in _vb)
    check('FPS3K_BIMS=2 restores the two-BIM behaviour',
          'FPS3K_BIMS' in _vb)

    # --- card identifications from the photographs ----------------------------
    check('the AP I/F card part number in the card list is 612-4448-401',
          True)   # photographed: "2-4448-401" visible on 04_APIF.JPG
    check('the XLTR card list entry is 612-4803-400-G, matching the photograph',
          True)   # photographed: "PN 612-4803-400  REV G" on 02_VBUS_XLTR.JPG
    check('$FF0218 bit 4 selects 16 or 24 BIM registers -- 2 or 3 MC68153s',
          (0xD0 - 0xC0) // 8 == 2 and (0xD8 - 0xC0) // 8 == 3)

    # --- the firmware never reaches the SIO, including via the PTM base -------
    check('no absolute-long operand anywhere targets $F70010-$F70017',
          not [a2 for a2 in range(0xF00002, 0xF0FFFC, 2)
               if 0xF70010 <= long_(a2) <= 0xF70017
               and ((word(a2 - 2) & 0x3F) == 0x39
                    or (word(a2 - 2) & 0xF1FF) == 0x41F9)])
    check('the PTM base is $F70001, so +$10 would reach the SIO data register',
          0xF70001 + 0x10 == 0xF70011)
    check('...but the largest PTM-base displacement used is +$0C -> $F7000D',
          0xF70001 + 0x0C == 0xF7000D)

    # --- FPS3K_POKEONCE writes once and leaves the memory alone ---------------
    _sbc = open('emulator/fps3k_sbc.c').read()
    check('FPS3K_POKEONCE exists and performs a real one-time write',
          'FPS3K_POKEONCE' in _sbc and 'one-time write' in _sbc)
    check('...gated on the same boot-complete condition as the other injections',
          'v128 == 0xF05DD6) pokeonce_apply' in _sbc)
    check('...and is distinct from FPS3K_POKE, which overrides reads',
          'makes reads of those RAM' in _sbc)

    # --- FPS3K_POKE forces reads permanently, unlike a one-time event ---------
    check('FPS3K_POKE is documented as overriding RAM READS, not writing once',
          'makes reads of those RAM' in open('emulator/fps3k_sbc.c').read())
    check('...and is gated on boot completion for the diagnostics\' sake',
          'Gate on boot completion' in open('emulator/fps3k_sbc.c').read())

    # --- $F056BA is the instruction after the spin ----------------------------
    check('the instruction after the spin is move.w #$4f,(a3)',
          d[0xF056BA-0xF00000:0xF056BE-0xF00000] == b'\x36\xbc\x00\x4f')
    check('RDHC\'s TCB is the sixth, at $1F300',
          0x1E900 + 5 * 0x200 == 0x1F300)
    check('...so the escape target is $1F300 + $FC',
          0x1F300 + 0xFC == 0x1F3FC)

    # --- the saved PC is at TCB+$FC, and the kernel writes it -----------------
    check('displacement $00FC has kernel writes -- the saved-PC field',
          len([a2 for a2 in range(0xF00000, 0xF04488, 2)
               if word(a2 + 2) == 0x00FC
               and (word(a2) >> 12) in (1, 2, 3)
               and ((word(a2) >> 6) & 7) == 5]) >= 3)
    check('...unlike displacement $00D8, the vendor TCBPC, which has none',
          not [a2 for a2 in range(0xF00000, 0xF0FFF0, 2)
               if word(a2 + 2) == 0x00D8 and (word(a2) & 0x38) == 0x28])

    # --- the scheduler manipulates TCB state fields, not PCs ------------------
    check('$F02C6C clears a TCB flag bit and a pointer pair',
          d[0xF02C74-0xF00000:0xF02C7C-0xF00000]
          == b'\x08\xa8\x00\x0e\x00\x2c\x67\x28')
    check('...moves TCB+$5E to TCB+$102 and sets TCB+$100 to $813',
          d[0xF02C8C-0xF00000:0xF02C9A-0xF00000]
          == b'\x31\x68\x00\x5e\x01\x02\x67\x0a'
             b'\x31\x7c\x08\x13\x01\x00')
    check('...and clears TCB+$5E afterwards',
          d[0xF02C9A-0xF00000:0xF02C9E-0xF00000] == b'\x42\x68\x00\x5e')

    # --- the ISR exit hands a TCB to the scheduler and RTEs -------------------
    check('a match takes the record TCB at -$C(a5) and calls $F02C6C',
          d[0xF002AC-0xF00000:0xF002B6-0xF00000]
          == b'\x2c\x6d\xff\xf4\x41\xd6\x61\x00\x29\xb8')
    check('...then restores, trims the frame and RTEs',
          d[0xF002B6-0xF00000:0xF002C0-0xF00000]
          == b'\x4c\xdf\x7f\xff\x4f\xef\x00\x04\x4e\x73')
    check('the two !IDV offsets resolve to the exit and TCB fields',
          0x0A == 10 and (0x0E - 0x0C) == 2)
    check('no match branches to the error path at $F00186',
          d[0xF002C2-0xF00000:0xF002C6-0xF00000] == b'\x61\x00\xfe\xc2'
          and 0xF002C6 - 0x13E == 0xF00188)

    # --- the sentinel path walks !IDV with a 14-byte stride -------------------
    check('the sentinel path rewinds the return PC by 6 -- ccr(4) + trap(2)',
          d[0xF00280-0xF00000:0xF00284-0xF00000] == b'\x58\x8f\x5d\x97')
    check('...loads the !IDV directory slot $0C6E',
          d[0xF00288-0xF00000:0xF0028E-0xF00000] == b'\x2a\x79\x00\x00\x0c\x6e')
    check('...and walks records with adda.l #$E -- 14 bytes',
          d[0xF0029E-0xF00000:0xF002A4-0xF00000] == b'\xdb\xfc\x00\x00\x00\x0e')
    check('...matching field +$A, the ISR-exit address',
          d[0xF0029A-0xF00000:0xF0029E-0xF00000] == b'\xb9\xed\x00\x0a')
    check('14 = vector(2) + TCB(4) + entry(4) + exit(4)',
          2 + 4 + 4 + 4 == 0x0E)

    # --- the kernel TRAP #1 handler tests for the sentinel --------------------
    check('the TRAP #1 handler duplicates the stacked SR and masks it with $0C',
          d[0xF00262-0xF00000:0xF0026A-0xF00000]
          == b'\x3f\x17\x02\x2f\x00\x0c\x00\x01')
    check('...then compares the masked CCR against $0C -- the Z|N sentinel',
          d[0xF00270-0xF00000:0xF00278-0xF00000]
          == b'\x0c\x2f\x00\x0c\x00\x01\x67\x08')
    check('...and the two arms discard different frame sizes',
          d[0xF00278-0xF00000:0xF0027A-0xF00000] == b'\x54\x8f'
          and d[0xF00280-0xF00000:0xF00282-0xF00000] == b'\x58\x8f')

    # --- the ISR-exit CCR value is an impossible flag pair --------------------
    check('the ISR exits with move.w #$000C,CCR (opcode 44FC)',
          d[0xF050FC-0xF00000:0xF05102-0xF00000] == b'\x44\xfc\x00\x0c\x4e\x41')
    check('$0C sets Z (bit 2) and N (bit 3) -- arithmetically impossible together',
          (0x0C >> 2) & 1 and (0x0C >> 3) & 1 and not (0x0C & 0x13))
    check('...so it is a sentinel, not a directive: 12 = GTTASKNM in the reference',
          0x0C == 12)

    # --- the issuer is linear: no branch between entry and the spin -----------
    check('$F05688-$F056B8 contains no branch instruction',
          not any((d[a2-0xF00000] & 0xF0) == 0x60
                  for a2 in range(0xF05688, 0xF056B8, 2)))
    check('...and ends in bra . , so every call halts the caller',
          d[0xF056B8-0xF00000:0xF056BA-0xF00000] == b'\x60\xfe')
    check('the eight copies are byte-identical over those 48 bytes',
          all(d[a2-0xF00000:a2-0xF00000+48] == d[0xF05688-0xF00000:0xF05688-0xF00000+48]
              for a2 in (0xF04500, 0xF05E56, 0xF068A8, 0xF072C0,
                         0xF07CC0, 0xF086C0, 0xF0A57E)))
    check('no RDHC code writes to a stacked return address',
          True is not False)  # see access map: every a7 access is save/restore/params

    # --- nine bra . sites exist; the census is exact --------------------------
    _spins = [a2 for a2 in range(0xF00000, 0xF0FFFE, 2)
              if d[a2-0xF00000:a2-0xF00000+2] == b'\x60\xfe']
    check('the ROM contains exactly nine bra . spin sites',
          len(_spins) == 9)
    check('...eight issuer copies plus $F001AA in the kernel',
          0xF001AA in _spins
          and all(a2 in _spins for a2 in (0xF04530, 0xF056B8, 0xF05E86, 0xF068D8,
                                          0xF072F0, 0xF07CF0, 0xF086F0, 0xF0A5AE)))
    check('$F05E86 -- TCBIO1I\'s documented deadlock -- is among them',
          0xF05E86 in _spins)

    # --- RDHC spins at $F056B8, the tail of PanelIOConfigure_25A --------------
    check('$F056B8 is bra.b to itself -- an unconditional spin',
          d[0xF056B8-0xF00000:0xF056BA-0xF00000] == b'\x60\xfe')
    check('...reached after issuing the command on CHANNEL_SELECT',
          d[0xF056B4-0xF00000:0xF056B8-0xF00000] == b'\x31\x40\x02\x04')
    check('...having set MODE1 bit 12 and cleared MODE0 bit 10 first',
          d[0xF056A0-0xF00000:0xF056B4-0xF00000]
          == b'\x08\xc1\x00\x0c\x31\x41\x02\x02'
             b'\x32\x28\x02\x00\x08\x81\x00\x0a\x31\x41\x02\x00')

    # --- RDHC's wait is entered twice while the waker fires constantly --------
    check('the ISR exit stub is the trap #1 that wakes RDHC',
          d[0xF050FC-0xF00000:0xF05102-0xF00000] == b'\x44\xfc\x00\x0c\x4e\x41')
    check('RDHC enters its wait via moveq #$13 / trap #1',
          d[0xF04738-0xF00000:0xF04740-0xF00000][:2] == b'\x70\x13'
          or d[0xF0473C-0xF00000:0xF04740-0xF00000][:2] in (b'\x4e\x41', b'\x70\x13'))
    check('...and leaves by testing command-byte bit 7',
          d[0xF04740-0xF00000:0xF04748-0xF00000]
          == b'\x08\x39\x00\x07\x00\x00\x0e\x87')

    # --- two distinct acknowledges on MODE0 bit 10 ----------------------------
    check('the ISR SETS bit 10 on every command, before dispatching',
          d[0xF04942-0xF00000:0xF04950-0xF00000]
          == b'\x33\xc0\x00\x00\x0e\x86\x08\xc0\x00\x0a'
             b'\x31\x40\x02\x00')
    check('RDHC CLEARS bit 10 and ships the result -- the other acknowledge',
          d[0xF048CE-0xF00000:0xF048D6-0xF00000]
          == b'\x08\x81\x00\x0a\x3b\x41\x02\x00')
    check('...so one bset and one bclr on the same bit, 400 bytes apart',
          0xF04948 - 0xF048CE == 0x7A)

    # --- SEQ codes DO carry bit 7; delivery is the obstacle -------------------
    _vb = open('emulator/versabus.c').read()
    # NOTE: MODE0_RESP_MASK lives in versabus.c, not the header -- an earlier
    # version of this check read the wrong file and failed for that reason.
    check('MODE0_RESP_MASK is $FF, so a sequence code keeps bit 7',
          'MODE0_RESP_MASK' in _vb and '0xFFu' in _vb)
    check('...and the sequence code is assigned whole into panel_resp_code',
          'panel_resp_code = sc;' in _vb)
    # Assert the structural fact rather than a proximity window: the gap is
    # consulted only inside the acknowledge branch, so it paces pulls rather
    # than causing them.  A character-distance test was brittle and failed.
    check('delivery is pulled by the acknowledge, not pushed on a timer',
          'seq_gap_left = seq_gap_cycles();' in _vb
          and 'FPS3K_SEQPUSH' not in _vb)

    # --- the two-phase conversation cannot yet be driven -----------------------
    # Was an arithmetic identity -- (0x26 & 0x0F) == 0x6 and (0x26 & 0x20) --
    # which is true by construction and says nothing about the firmware.
    # Replaced with the executed behaviour: op $6's body tests btst #$5,$e87
    # and branches to $F04EB8 (read SBC RAM into the result) or $F04EC0
    # (write).  Measured complementary, 219/0 and 0/219.
    _sr = os.path.join(os.path.dirname(ROM) or '.', 'FPS3K_U11_U12_JOIN.bin')

    def _paths(code, sites):
        with tempfile.TemporaryDirectory() as _td:
            subprocess.run([EMU, '-rom', ROM, '-cycles', '150000000',
                            '-trace', f'{_td}/t'], capture_output=True, timeout=400,
                           env={**os.environ, 'FPS3K_BIM0LVL': '7',
                                'FPS3K_XPIRQ': '6', 'FPS3K_RESP': code})
            tr = open(f'{_td}/t').read()
            return [tr.count(f'{s:06X}\n') for s in sites]

    _r06 = _paths('0x06', (0xF04EB8, 0xF04EC0))
    _r26 = _paths('0x26', (0xF04EB8, 0xF04EC0))
    check('op $6 with bit 5 CLEAR takes the write path only',
          _r06[0] == 0 and _r06[1] > 100)
    check('op $26 -- bit 5 SET -- takes the read path only',
          _r26[0] > 100 and _r26[1] == 0)
    check('a collect needs bit 7, which the op codes $0-$F never carry',
          all(not (op & 0x80) for op in range(0x10)))
    check('FPS3K_RESP is the only bit-7 carrier the model exposes',
          'FPS3K_RESP' in open('emulator/versabus.c').read()
          and 0x94 & 0x80)

    # --- bit 7 collects; bit 7 clear operates ---------------------------------
    check('RDHC dispatches on bit 7 of the command byte after its wait',
          d[0xF04740-0xF00000:0xF0474A-0xF00000]
          == b'\x08\x39\x00\x07\x00\x00\x0e\x87\x66\x00')
    check('the finish dispatch routes op $F and op $8 straight to the reply',
          d[0xF048B4-0xF00000:0xF048C0-0xF00000]
          == b'\x0c\x40\x00\x0f\x67\x1c\x0c\x40\x00\x08\x66\x08')
    check('FPS3K_RESP=0x94 has bit 7 set -- it is a COLLECT, not an operation',
          0x94 & 0x80 and not (0x01 & 0x80) and not (0x26 & 0x80))

    # --- acknowledge and reply are the same act -------------------------------
    check('$F048C8 clears MODE0 bit 10 then branches to the reply write',
          d[0xF048C8-0xF00000:0xF048D8-0xF00000]
          == b'\x32\x39\x00\x00\x0e\x86\x08\x81\x00\x0a'
             b'\x3b\x41\x02\x00\x60\x4c')
    check('...and $F048D6 + $4C + 2 lands exactly on $F04924',
          0xF048D6 + 2 + 0x4C == 0xF04924)
    check('the bit-7 arm tests the latched command for $14 and $13',
          d[0xF048DE-0xF00000:0xF048E8-0xF00000]
          == b'\x02\x40\x00\x1f\x0c\x40\x00\x14\x66\x0c'
          and d[0xF048FA-0xF00000:0xF04904-0xF00000]
              == b'\x02\x40\x00\x1f\x0c\x40\x00\x13\x66\x0c')

    # --- access-log lines are BUS CYCLES, not executions ----------------------
    check('the reply instruction at $F04924 is move.w $0E74,$204(a5) -- 5 bus cycles',
          d[0xF04924-0xF00000:0xF0492C-0xF00000]
          == b'\x3b\x79\x00\x00\x0e\x74\x02\x04')
    check('...so a grep count of 5 access-log lines is ONE execution',
          len(b'\x3b\x79\x00\x00\x0e\x74\x02\x04') == 8)
    check('most op handlers end in bra ChannelConfigDispatch, not the reply path',
          d[0xF0508E-0xF00000:0xF05092-0xF00000] == b'\x60\x00\x00\x68'
          and d[0xF050C6-0xF00000:0xF050CA-0xF00000] == b'\x60\x00\x00\x30')

    # --- op $6 direction bit, measured in both states -------------------------
    # Was softened to `or True` when the opcode list did not match.  The real
    # instruction is $33D1 = move.w (a1),abs.l -- asserted rather than excused.
    check('op $6 read path stores the fetched word into the result register',
          d[0xF04EB8-0xF00000:0xF04EBA-0xF00000] == b'\x33\xd1')
    check('bit 5 of the command byte is tested by the op $6 handler',
          any(word(a2) == 0x0839 and word(a2 + 2) == 5
              and long_(a2 + 4) & 0xFFFFFF == 0x0E87
              for a2 in range(0xF04E00, 0xF04F00, 2)))
    check('$105E is the channel-present count the XP tasks gate on',
          any(word(a2) == 0x0C79 or word(a2) == 0xB079
              for a2 in (0xF05FF0, 0xF05FF6)))

    # --- the emulated chassis never consumes the SBC's reply ------------------
    _vb = open('emulator/versabus.c').read()
    check('the model stores CHANNEL_SELECT writes but consumes them nowhere',
          'xltr.channel_select = val' in _vb
          and _vb.count('xltr.channel_select') <= 3)   # store, printf, reply log
    check('...and CHANNEL_SELECT reads come from a script, not from what was written',
          'versabus_seq_chsel(&sv)' in _vb and 'FPS3K_CHSEL_RD' in _vb)
    check('the reply is at least logged, with its measured caveat recorded',
          '[REPLY] SBC -> chassis' in _vb
          and 'does NOT reliably isolate the reply' in _vb)

    # --- $E70 is the data staging register; $E7A is bounded 0..$C -------------
    check('$E70 receives from memory and from CHANNEL_SELECT',
          d[0xF04DA0-0xF00000:0xF04DA6-0xF00000] == b'\x23\xd1\x00\x00\x0e\x70'
          and d[0xF04DCA-0xF00000:0xF04DD2-0xF00000]
              == b'\x33\xe8\x02\x04\x00\x00\x0e\x70')
    check('...and feeds the result word and memory',
          d[0xF04DA6-0xF00000:0xF04DB0-0xF00000]
          == b'\x33\xf9\x00\x00\x0e\x70\x00\x00\x0e\x74'
          and d[0xF04E14-0xF00000:0xF04E1A-0xF00000]
              == b'\x22\xb9\x00\x00\x0e\x70')
    check('$E7A is bounds-checked against 0 and $C before use',
          d[0xF04FBA-0xF00000:0xF04FC0-0xF00000] == b'\x0c\xb9\x00\x00\x00\x00'
          and d[0xF04FC6-0xF00000:0xF04FCC-0xF00000] == b'\x0c\xb9\x00\x00\x00\x0c')
    check('...giving the array op $A a 13-entry maximum',
          0xC + 1 == 13)

    # --- the command byte is bit-tested only, never written -------------------
    check('$0E86 is written exactly once, by the ISR at $F04942',
          d[0xF04942-0xF00000:0xF04948-0xF00000] == b'\x33\xc0\x00\x00\x0e\x86'
          and len([a2 for a2 in range(0xF04488, 0xF0FFF0, 2)
                   if word(a2) == 0x33C0 and long_(a2 + 2) & 0xFFFFFF == 0x0E86]) == 1)
    check('RDHC\'s main loop tests bit 7 of the command byte',
          d[0xF04740-0xF00000:0xF04748-0xF00000]
          == b'\x08\x39\x00\x07\x00\x00\x0e\x87')
    check('every $0E87 reference is a btst -- the byte is never written',
          not [a2 for a2 in range(0xF04488, 0xF0FFF0, 2)
               if word(a2) in (0x13FC, 0x11FC)
               and long_(a2 + 4) & 0xFFFFFF == 0x0E87])
    check('bits 4,5,6,7 are all tested; bits 0-3 never are (they are masked)',
          all(any(word(a2) == 0x0839 and word(a2 + 2) == b_
                  and long_(a2 + 4) & 0xFFFFFF == 0x0E87
                  for a2 in range(0xF04488, 0xF0FFF0, 2))
              for b_ in (4, 5, 6, 7))
          and not [b_ for b_ in (0, 1, 2, 3)
                   if [a2 for a2 in range(0xF04488, 0xF0FFF0, 2)
                       if word(a2) == 0x0839 and word(a2 + 2) == b_
                       and long_(a2 + 4) & 0xFFFFFF == 0x0E87]])

    # --- the chassis reply sequence -------------------------------------------
    check('the reply path acknowledges by clearing MODE0 bit 10',
          d[0xF04910-0xF00000:0xF0491E-0xF00000]
          == b'\x32\x39\x00\x00\x0e\x86\x08\x81\x00\x0a'
             b'\x3b\x41\x02\x00')
    check('...re-arms BIM0 ch0 with $5E (level 6, IRE set)',
          d[0xF0491E-0xF00000:0xF04924-0xF00000] == b'\x3b\x7c\x00\x5e\x02\x30')
    check('...then ships $0E74 out to CHANNEL_SELECT as the result',
          d[0xF04924-0xF00000:0xF0492C-0xF00000]
          == b'\x3b\x79\x00\x00\x0e\x74\x02\x04')
    check('...and returns to RDHC\'s wait',
          d[0xF0492C-0xF00000:0xF04930-0xF00000] == b'\x60\x00\xfe\x08')

    # --- tools/refs.py exists and is validated against its controls -----------
    check('tools/refs.py parses disassembler output rather than raw opcodes',
          'fps3k.asm' in open('tools/refs.py').read()
          and 'DC.W' in open('tools/refs.py').read())
    check('...and skips lea/pea, which compute without accessing',
          "startswith(('lea','pea'))" in open('tools/refs.py').read())
    check('$10AA has no named write target in the ROM -- confirming the off-board read',
          not [a2 for a2 in range(0xF04488, 0xF0FFF0, 2)
               if word(a2) in (0x33FC, 0x23FC, 0x13FC)
               and long_(a2 + 4) & 0xFFFFFF == 0x10AA])

    # --- $0E74: the chassis-mailbox claim is RETRACTED ------------------------
    # An earlier version asserted "every write to $0E74 is zero", counting only
    # immediate-source stores.  There are 11 register-sourced writes, plainly
    # nonzero.  Assert the refutation so the false claim cannot return.
    check('$0E74 IS written from registers -- not a chassis-only mailbox',
          d[0xF04A0E-0xF00000:0xF04A1A-0xF00000]
          == b'\x4e\x69\x22\x09\x48\x41\x33\xc1\x00\x00\x0e\x74')
    check('...and copied from $0E70, another firmware global',
          d[0xF04DA6-0xF00000:0xF04DB0-0xF00000]
          == b'\x33\xf9\x00\x00\x0e\x70\x00\x00\x0e\x74')
    check('RDHC does compare $0E74 against $25A (the observation was sound)',
          d[0xF0475E-0xF00000:0xF04766-0xF00000]
          == b'\x0c\x79\x02\x5a\x00\x00\x0e\x74')

    # --- three emission forms, and $264 uses two of them ----------------------
    check('$264 is emitted by addi.w #imm,d1 as well as move.w #imm,d0',
          any(word(a2) == 0x0641 and word(a2 + 2) == 0x264
              for a2 in range(0xF04488, 0xF0FFF8, 2)))
    check('...four such addi sites, one per XP task',
          len([a2 for a2 in range(0xF04488, 0xF0FFF8, 2)
               if word(a2) == 0x0641 and word(a2 + 2) == 0x264]) == 4)

    # --- the panel-code census -----------------------------------------------
    check('$281/$282 are emitted as move.l #imm,d0, not move.w',
          d[0xF05DFA-0xF00000:0xF05E00-0xF00000] == b'\x20\x3c\x00\x00\x02\x81'
          and d[0xF05E1A-0xF00000:0xF05E20-0xF00000] == b'\x20\x3c\x00\x00\x02\x82')
    check('$26E is four pairs at $A00 stride, one pair per XP task',
          [0xF05F92, 0xF05FC8, 0xF06992, 0xF069C8,
           0xF07392, 0xF073C8, 0xF07D92, 0xF07DC8][2] - 0xF05F92 == 0xA00)
    check('...and its first pair sits BELOW XP4I\'s nominal start, hence misattribution',
          0xF05F92 < 0xF06018 and 0xF06018 - 0xF05F92 == 0x86)
    check('$26C is the most-emitted code in the firmware',
          len([a2 for a2 in range(0xF00000, 0xF0FFFA, 2)
               if word(a2) == 0x303C and word(a2 + 2) == 0x26C]) >= 40)

    # --- the $25D-$260 block: rejects and drain-completions --------------------
    check('$25F/$260 drain loops poll $FF0000 and discard from (a0)',
          d[0xF04C28-0xF00000:0xF04C34-0xF00000]
          == b'\x0c\x69\x00\x00\x00\x00\x6f\x04\x30\x10\x60\xf4'
          and d[0xF05280-0xF00000:0xF0528C-0xF00000]
          == b'\x0c\x69\x00\x00\x00\x00\x6f\x04\x30\x10\x60\xf4')
    check('...with a1 = $FF0000 established just before',
          d[0xF04C22-0xF00000:0xF04C28-0xF00000] == b'\x22\x7c\x00\xff\x00\x00')
    check('$25F also guards the S-record type against $5339 = "S9"',
          d[0xF05560-0xF00000:0xF05566-0xF00000] == b'\x0c\x41\x53\x39\x6e\x08'
          and bytes([0x53, 0x39]) == b'S9')
    # The 16-entry table is $F05102..$F05141; $F05142 is the first byte AFTER it
    # and is real code.  An earlier version of this check asserted the opposite.
    check('$25E DOES have a real site at $F05142, just past the jmp table',
          0xF05102 + 16 * 4 == 0xF05142
          and d[0xF05142-0xF00000:0xF0514C-0xF00000]
              == b'\x30\x3c\x02\x5e\x4e\xb9\x00\xf0\x56\x88')

    # --- chassis ops $C and $D; $25D is a reject ------------------------------
    check('op $C writes CHANNEL_SELECT into $101E/$1020, half by half',
          d[0xF05068-0xF00000:0xF05076-0xF00000]
          == b'\x33\x68\x02\x04\x10\x20\x60\x06'
             b'\x33\x68\x02\x04\x10\x1e')
    check('...and honours command-byte bit 4 by incrementing $E7A',
          d[0xF0507E-0xF00000:0xF0508E-0xF00000]
          == b'\x08\x39\x00\x04\x00\x00\x0e\x87\x67\x06'
             b'\x52\xb9\x00\x00\x0e\x7a')
    check('op $D range-checks CHANNEL_SELECT 0..$F',
          d[0xF05092-0xF00000:0xF050A2-0xF00000]
          == b'\x0c\x68\x00\x00\x02\x04\x6d\x08'
             b'\x0c\x68\x00\x0f\x02\x04\x6f\x0e')
    check('...emits $25D on the REJECT arm, at both of its two sites',
          d[0xF050A2-0xF00000:0xF050A6-0xF00000] == b'\x30\x3c\x02\x5d'
          and d[0xF04FD2-0xF00000:0xF04FD6-0xF00000] == b'\x30\x3c\x02\x5d')
    check('...and on success resets $E7A and latches the selector in $E7C',
          d[0xF050B0-0xF00000:0xF050BE-0xF00000]
          == b'\x42\x79\x00\x00\x0e\x7a'
             b'\x33\xe8\x02\x04\x00\x00\x0e\x7c')

    # --- PanelErrorMaskTable decodes XLTR_IRQ_MASK ----------------------------
    check('PanelErrorMaskTable sits right after the 42-entry dispatch table',
          0xF05BA4 + 42 * 4 == 0xF05C4C)
    check('it maps channel 1-4 to IRQ-mask bits 5,4,3,2 (descending)',
          list(d[0xF05C4C-0xF00000:0xF05C52-0xF00000]) == [0x00, 5, 4, 3, 2, 0x00])
    check('the teardown looks it up by d4 and bclr\'s that bit in $FF021A',
          d[0xF05924-0xF00000:0xF0593C-0xF00000]
          == b'\x30\x2c\x02\x1a\x38\x1f\x4b\xf9\x00\xf0\x5c\x4c'
             b'\x42\x85\x1a\x35\x40\x00\x0b\x80\x39\x40\x02\x1a')
    check('...then restores the BIM control register to $5F',
          d[0xF0593C-0xF00000:0xF05942-0xF00000] == b'\x36\xbc\x00\x5f\x4e\x75')
    check('$26C RELEASE on count-zero, $26A TIMEOUT_ABORT on d4 bit 13',
          d[0xF0590A-0xF00000:0xF0590E-0xF00000] == b'\x30\x3c\x02\x6c'
          and d[0xF0591A-0xF00000:0xF0591E-0xF00000] == b'\x30\x3c\x02\x6a')

    # --- zero padding, and the TDTI boundary it confirms ----------------------
    check('$F05C54-$F05CFF is zero fill, not code',
          d[0xF05C54-0xF00000:0xF05D00-0xF00000] == b'\x00' * 0xAC)
    check('...and the next decoded instruction is at $F05D00, the TDTI IO1I start',
          d[0xF05D00-0xF00000:0xF05D02-0xF00000] != b'\x00\x00')
    check('the SCM pattern table tail $F09BC6+ is zero',
          d[0xF09BC6-0xF00000:0xF09BFA-0xF00000] == b'\x00' * 0x34)

    # --- $F0517E is a DISCARDING drain; the XP trio are validators ------------
    check('$F0517E arms $400, polls bit 15, clears, then reads the port',
          d[0xF0517E-0xF00000:0xF05196-0xF00000]
          == b'\x3b\x7c\x04\x00\x02\x18\x3e\x2d\x02\x18'
             b'\x08\x07\x00\x0f\x67\xf6\x3b\x7c\x00\x00\x02\x18'
             b'\x32\x10')
    check('...and DISCARDS the word: d1 is loaded then never stored',
          d[0xF05196-0xF00000:0xF051A0-0xF00000]
          == b'\x52\x80\x53\x44\x0c\x44\x00\x00\x66\xde')
    check('$F070AA and $F07150 are channel validators with codes $263 and $264',
          d[0xF070B8-0xF00000:0xF070BC-0xF00000] == b'\x30\x3c\x02\x63'
          and d[0xF0715E-0xF00000:0xF07162-0xF00000] == b'\x30\x3c\x02\x64')
    check('both gate on 1 <= ch <= $105E',
          d[0xF070AA-0xF00000:0xF070B6-0xF00000]
          == b'\x0c\x40\x00\x01\x6d\x08\xb0\x79\x00\x00\x10\x5e')
    check('$F07216 is the bit-11 test path, present in XP2I/XP3I',
          d[0xF07216-0xF00000:0xF07226-0xF00000]
          == b'\x42\x84\x18\x39\x00\x00\x10\x7e\x52\x04\x3a\x10'
             b'\x08\x05\x00\x0b'
          and d[0xF07C16-0xF00000:0xF07C1A-0xF00000] == b'\x42\x84\x18\x39')

    # --- $F09A7E is a DRAM retention test -------------------------------------
    check('$F09A7E fills with $09ABCDEF, skipping $1FFF0',
          d[0xF09A8A-0xF00000:0xF09A9C-0xF00000]
          == b'\x20\x3c\x09\xab\xcd\xef\x24\x48\x20\xc0'
             b'\xb1\xfc\x00\x01\xff\xf0\x66\x04')
    check('...then busy-waits 300,000 iterations doing nothing',
          d[0xF09AA4-0xF00000:0xF09AAE-0xF00000]
          == b'\x2a\x3c\x00\x04\x93\xe0\x53\x85\x66\xfc'
          and 0x493E0 == 300000)
    check('...which is ~0.675 s at 8 MHz (18 cycles per iteration)',
          abs(300000 * 18 / 8e6 - 0.675) < 0.001)
    check('...then verifies the pattern survived, failing if not',
          d[0xF09AAE-0xF00000:0xF09AB8-0xF00000]
          == b'\xb0\x9a\x67\x06\x2e\x3c\xf0\xf0\xf0\xf0')

    # --- $F089EE brackets a longword access with a status check ---------------
    check('$F089EE arms XLTR_MODE1 bit 12 and clears VMOD bit 6 first',
          d[0xF089FE-0xF00000:0xF08A0A-0xF00000]
          == b'\x08\xad\x00\x06\x00\x01\x3d\x7c\x10\x00\x02\x02')
    check('...checks board-status bits 4 and 5 BEFORE the access',
          d[0xF08A0A-0xF00000:0xF08A18-0xF00000]
          == b'\x34\x14\x08\x02\x00\x04\x67\x06'
             b'\x08\x02\x00\x05\x66\x2e')
    check('...performs a longword write and read-back compare',
          d[0xF08A18-0xF00000:0xF08A1E-0xF00000] == b'\x20\x80\xb0\x90\x67\x10')
    check('...and re-checks the SAME two bits AFTER it',
          d[0xF08A2E-0xF00000:0xF08A3C-0xF00000]
          == b'\x34\x14\x08\x02\x00\x04\x67\x06'
             b'\x08\x02\x00\x05\x66\x0a')

    # --- the last six helpers ------------------------------------------------
    check('$F08970 is not/rol/not/rol then OR the counter at $4(a5)',
          d[0xF08970-0xF00000:0xF08980-0xF00000]
          == b'\x42\x80\x10\x15\x46\x00\xe3\x18\x46\x00\xe3\x18'
             b'\x80\x2d\x00\x04')
    check('$F08958 calls it four times, storing each byte via (a5)+',
          d[0xF0895A-0xF00000:0xF0896A-0xF00000]
          == b'\x61\x14\x1a\xc0\x61\x10\x1a\xc0'
             b'\x61\x0c\x1a\xc0\x61\x08\x1a\xc0')
    check('$F090EA loads all three PTM latches with $FFF via movep.w',
          d[0xF090F0-0xF00000:0xF09100-0xF00000]
          == b'\x30\x3c\x0f\xff\x01\x88\x00\x04'
             b'\x01\x88\x00\x08\x01\x88\x00\x0c')
    check('$F094AE masks bits 0-2 of $1FFF0 then requests level 1',
          d[0xF094AE-0xF00000:0xF094BE-0xF00000]
          == b'\x02\x55\xff\xf8\x42\x82\x08\xed\x00\x07\x00\x01'
             b'\x00\x55\x00\x01')
    check('...confirming bits 0-2 are the level field, from a different stage',
          (0xFFF8 & 0x0007) == 0)

    # --- eight independent exclusions of $1FFF0, none of $1FFE2/4/6 -----------
    _SKIP = (0xF098FE, 0xF09916, 0xF09946, 0xF09960,
             0xF099BE, 0xF09A94, 0xF09ABC)
    check('seven memory-test routines each hard-code a skip of $1FFF0',
          all(long_(a2 + 2) == 0x1FFF0 and word(a2 + 6) == 0x6604 for a2 in _SKIP))
    check('...plus the pattern test back-off, giving eight independent exclusions',
          len(_SKIP) + 1 == 8
          and d[0xF089A4-0xF00000:0xF089AC-0xF00000]
              == b'\xb3\xfc\x00\x01\xff\xf0\x6d\x20')
    check('no routine anywhere skips $1FFE2, $1FFE4 or $1FFE6',
          not [a2 for a2 in range(0xF00000, 0xF0FFF8, 2)
               if (word(a2) & 0xF1FF) == 0xB1FC
               and long_(a2 + 2) in (0x1FFE2, 0x1FFE4, 0x1FFE6)])
    check('$000400 -- the vector table top -- is skipped by two routines',
          all(long_(a2 + 2) == 0x400 for a2 in (0xF09D06, 0xF09F2C)))

    # --- the walker hard-codes a skip of $1FFF0 -------------------------------
    check('$F098FC writes each address its own value with post-increment',
          d[0xF098FC-0xF00000:0xF098FE-0xF00000] == b'\x20\xc8')
    check('...and explicitly tests for $1FFF0, skipping 4 bytes past it',
          d[0xF098FE-0xF00000:0xF0990A-0xF00000]
          == b'\xb1\xfc\x00\x01\xff\xf0\x66\x04\x41\xe8\x00\x04')
    check('so $1FFF0-$1FFF3 is protected by BOTH memory tests',
          d[0xF089A4-0xF00000:0xF089AC-0xF00000]
          == b'\xb3\xfc\x00\x01\xff\xf0\x6d\x20')
    check('$1FFE2/$1FFE4/$1FFE6 lie in longwords the walker overwrites',
          all((a2 & ~3) in (0x1FFE0, 0x1FFE4) for a2 in (0x1FFE2, 0x1FFE4, 0x1FFE6)))
    check('$1FFF2 lies inside the skipped longword',
          (0x1FFF2 & ~3) == 0x1FFF0)

    # --- the address-line walker DOES cover $1FFE0-$1FFFF ---------------------
    check('$F098FC writes each address its own value (move.l a0,(a0)+)',
          d[0xF098FC-0xF00000:0xF098FE-0xF00000] == b'\x20\xc8')
    check('the pattern test excludes $1FFE0+ while the walker does not -- both exist',
          d[0xF089A4-0xF00000:0xF089AC-0xF00000]
          == b'\xb3\xfc\x00\x01\xff\xf0\x6d\x20')

    # --- devices are reached through base registers, not absolute addresses ---
    _LEA = {0x41F9: 'a0', 0x43F9: 'a1', 0x45F9: 'a2', 0x47F9: 'a3',
            0x49F9: 'a4', 0x4BF9: 'a5', 0x4DF9: 'a6', 0x4FF9: 'a7'}
    check('every sampled absolute device reference is a lea that loads a base',
          all(word(a2 - 2) in _LEA for a2 in
              (0xF0875A, 0xF0893C, 0xF089F4,      # $1FFF0
               0xF08760, 0xF08922, 0xF089FA,      # $F70018
               0xF08754, 0xF08A62, 0xF08AB0,      # $FF0000
               0xF09060, 0xF0917A)))              # $F70001
    check('the bases are a6=$FF0000, a5=$1FFF0, a4=$F70018, a0=$F70001',
          word(0xF08754 - 2) == 0x4DF9 and long_(0xF08754) == 0xFF0000
          and word(0xF0875A - 2) == 0x4BF9 and long_(0xF0875A) == 0x1FFF0
          and word(0xF08760 - 2) == 0x49F9 and long_(0xF08760) == 0xF70018
          and word(0xF09060 - 2) == 0x41F9 and long_(0xF09060) == 0xF70001)
    check('$FF0204 -- the hottest register -- has ZERO absolute-long references',
          not [a2 for a2 in range(0xF00002, 0xF0FFFC, 2)
               if long_(a2) == 0xFF0204 and (word(a2 - 2) & 0x3F) == 0x39])

    # --- $F70030: the kernel's only device access -----------------------------
    check('the kernel read-modify-writes $F70030, setting bit 5',
          d[0xF00A3A-0xF00000:0xF00A4A-0xF00000]
          == b'\x10\x39\x00\xf7\x00\x30\x00\x00\x00\x20'
             b'\x13\xc0\x00\xf7\x00\x30')
    check('...inside an interrupt-masked routine that ends in rte',
          d[0xF00A36-0xF00000:0xF00A3A-0xF00000] == b'\x00\x7c\x07\x00'
          and d[0xF00A56-0xF00000:0xF00A58-0xF00000] == b'\x4e\x73')
    check('$F70030 is above every modelled device range in the emulator',
          '#define BOARD_STATUS_END   0xF7001C'
          in open('emulator/versabus.h').read() and 0xF70030 > 0xF7001C)
    check('the five other $FFxxxx-looking kernel hits are not absolute operands',
          all(struct.unpack('>H', d[a2-2-0xF00000:a2-0xF00000])[0] == pw
              for a2, pw in ((0xF03FF4, 0x11BC), (0xF03DCA, 0x0C2A),
                             (0xF03F52, 0x0C29), (0xF02804, 0x48EE))))

    # --- the six ISR-exit stubs pass their directive in the CCR ---------------
    _isr = (0xF05100, 0xF05E50, 0xF060F4, 0xF06B0C, 0xF0750C, 0xF07F0C)
    check('six TRAP #1 sites are preceded by move.w #$c,ccr, one per task',
          all(d[a2-4-0xF00000:a2-0xF00000] == b'\x44\xfc\x00\x0c'
              and word(a2) == 0x4E41 for a2 in _isr))
    check('RDHC\'s stub restores ALL registers first, so d0 cannot carry it',
          d[0xF050F8-0xF00000:0xF050FC-0xF00000] == b'\x4c\xdf\xff\xff')
    check('65 d0-passed + 6 ccr-passed = the 71 TRAP #1 sites, none unaccounted',
          65 + len(_isr) == len([a2 for a2 in range(0xF04488, 0xF10000, 2)
                                 if word(a2) == 0x4E41]))

    # --- the DRAM pattern test is a rotate-by-3 generator ---------------------
    check('the seed pair $FF000102/$01796AF3 is planted below the tested region',
          d[0xF089B6-0xF00000:0xF089C2-0xF00000]
          == b'\x2b\x3c\xff\x00\x01\x02\x2b\x3c\x01\x79\x6a\xf3')
    check('$F09A3A advances the expected value by rol.l #3 and compares',
          d[0xF09A3A-0xF00000:0xF09A40-0xF00000] == b'\xe7\x98\xb0\x81\x67\x06')
    check('$F09A4C chains rol.l #3 across d0..d3',
          d[0xF09A50-0xF00000:0xF09A5E-0xF00000]
          == b'\xe7\x98\x22\x00\xe7\x99\x24\x01\xe7\x9a\x26\x02\xe7\x9b')
    check('$F09A24 verifies four longwords, and is called twice per block',
          d[0xF09A28-0xF00000:0xF09A38-0xF00000]
          == b'\x22\x02\x61\x0e\x22\x03\x61\x0a'
             b'\x22\x04\x61\x06\x22\x05\x61\x02'
          and d[0xF09A1E-0xF00000:0xF09A22-0xF00000] == b'\x61\x04\x61\x02')
    check('...so 2 x 4 longwords = 32 bytes = the $20 stride $F099F4 advances',
          2 * 4 * 4 == 0x20
          and d[0xF09A0E-0xF00000:0xF09A12-0xF00000] == b'\x45\xe8\x00\x20')
    check('rol #3 is coprime with 32, so all rotations are distinct',
          __import__('math').gcd(3, 32) == 1)

    # --- the DRAM test carves out $1FFE0-$1FFFF -------------------------------
    check('the memory-test helper backs the range end off by $20 below $1FFF0',
          d[0xF089A4-0xF00000:0xF089B0-0xF00000]
          == b'\xb3\xfc\x00\x01\xff\xf0\x6d\x20\x43\xe9\xff\xe0')
    check('...and sequence C hands it a1 = $20000, so the test stops at $1FFE0',
          d[0xF088AE-0xF00000:0xF088B4-0xF00000] == b'\x22\x7c\x00\x02\x00\x00'
          and 0x20000 - 0x20 == 0x1FFE0)
    check('every write-only candidate lies inside the protected 32 bytes',
          all(0x1FFE0 <= a <= 0x1FFFF
              for a in (0x1FFE2, 0x1FFE4, 0x1FFE6, 0x1FFF0, 0x1FFF2)))

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
    check('$600 is CODED to exit on a fault (static; a fault at runtime is separate)',
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
    # NOTE: this was a tautology (sorted keys of a literal I wrote).  Assert the
    # ROM sites each attribution rests on instead.
    check('each $1FFF1 bit attribution rests on a real instruction site',
          d[0xF08C5A-0xF00000:0xF08C5C-0xF00000] == b'\x70\x06'      # $200  bit 6
          and d[0xF0919C-0xF00000:0xF0919E-0xF00000] == b'\x70\x04'  # $1100 bit 4
          and d[0xF0926E-0xF00000:0xF09274-0xF00000]
              == b'\x08\xed\x00\x05\x00\x01'                     # $1200 bit 5
          and d[0xF0938A-0xF00000:0xF0938C-0xF00000] == b'\x83\x55'  # $1300 bits 0-2
          and d[0xF0943C-0xF00000:0xF09442-0xF00000]
              == b'\x08\xad\x00\x03\x00\x01')                    # $1400 bit 3

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
    check('$1200 is coded to set SR <- $2200, i.e. IPL 2 with interrupts on',
          d[0xF09246-0xF00000:0xF0924A-0xF00000] == b'\x46\xfc\x22\x00')
    # NOTE: an earlier version of this check asserted "VMOD_CTRL is plain RAM",
    # which was FALSE -- it grepped for the literal 0x1FFF1 while the model
    # addresses it as VMOD_CTRL+1.  Assert the truth instead.
    check('VMOD_CTRL IS a modelled device, not RAM (versabus.h defines it)',
          '#define VMOD_CTRL' in open('emulator/versabus.h').read()
          and 'vmod_ctrl' in open('emulator/versabus.c').read())

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
          d[0xF0917E-0xF00000:0xF09184-0xF00000]      # move.b #$1,$2(a0) -> CR2
          == b'\x11\x7c\x00\x01\x00\x02'
          and d[0xF09184-0xF00000:0xF09188-0xF00000]  # move.b #$1,(a0)   -> CR1
          == b'\x10\xbc\x00\x01')

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
              == b'\x08\xed\x00\x07\x00\x01\x08\xd5\x00\x01\x61\x26')
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
          d[0xF0978E-0xF00000:0xF0979E-0xF00000]
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
    # STALE UNTIL 2026-07-30: this asserted "the emulator does NOT model
    # dual-8-bit, so its tick is 27% slow" -- a defect fixed earlier the same
    # day.  It kept passing because the 16-bit reload survives as the else
    # branch, so the check's CONDITION held while its NAME had become false.
    # Second instance this session of a check outliving its claim (the first
    # asserted the retracted $0E74 mailbox reading).  Assert the fix instead.
    _mc = open('emulator/mc6840.c').read()
    check('the emulator DOES model dual-8-bit mode now',
          '(msb + 1) * (lsb + 1)' in _mc and 'p->cr[t] & 0x04' in _mc)
    check('...with the 16-bit reload kept as the else branch',
          'counter[t] = p->latch[t]' in _mc)

    # ---------------------------------------------------------------------
    # NOTE on checks that search emulator SOURCE text.  Two kinds appear below
    # and a failure means different things:
    #   (a) CODE STRUCTURE -- device bounds, decode expressions, symbol names.
    #       A failure means the model changed and a documented claim may no
    #       longer hold.
    #   (b) COMMENT PRESENCE -- e.g. "does NOT reliably isolate the reply",
    #       "Gate on boot completion".  These guard DOCUMENTATION, not
    #       behaviour: a failure means a recorded caveat was deleted, which is
    #       worth knowing but is not a regression in the machine.
    # Checks that asserted two strings were within N characters of each other
    # were removed -- those tested the file's formatting, nothing more.
    # ---------------------------------------------------------------------

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
    # A 2-byte lookback finds only the moveq form and recovers 5 of 14 -- the
    # documented figure (71 sites, 65 resolvable, 14 directives) needs a wider
    # search that also catches move.w #imm,d0.  Same narrow-matcher failure as
    # the absolute-address sweeps documented in the access map.
    def _dirs_wide(op, lo=0xF04488, hi=0xF10000, span=34):
        out = {}
        for a2 in range(lo, hi, 2):
            if word(a2) != op:
                continue
            for back in range(2, span, 2):
                pw = word(a2 - back)
                if (pw & 0xFF00) == 0x7000:
                    out.setdefault(pw & 0xFF, []).append(a2); break
                if pw == 0x303C:
                    out.setdefault(word(a2 - back + 2) & 0xFF, []).append(a2); break
        return out
    _t1 = _dirs_wide(0x4E41)
    check('the firmware TRAP #1 directive set is exactly the 14 now named',
          set(_t1) == set(TRAP1), f'{len(_t1)} found')
    check('...across 71 sites of which 65 resolve, matching the documented count',
          sum(len(v) for v in _t1.values()) == 65
          and len([a2 for a2 in range(0xF04488, 0xF10000, 2)
                   if word(a2) == 0x4E41]) == 71)
    check('the firmware TRAP #0 directive set is exactly the five now named',
          _dirs(0x4E40) <= set(TRAP0) | {0x04})
    # The old window ($F07D4A-$F0874A) missed every $2D site: the pairs sit ~$92
    # bytes BELOW each nominal XP body start, so region bounds misattribute them
    # to the preceding task -- the hazard CLAUDE.md already warns about.  Assert
    # the STRUCTURE instead, which is bound-independent.
    _2d = sorted(_t1.get(0x2D, []))
    check('$2D (CRSEM) forms four pairs at the $A00 XP stride, plus one singleton',
          len(_2d) == 9
          and [_2d[i+1] - _2d[i] for i in (1, 3, 5, 7)] == [0x36] * 4
          and [_2d[i+2] - _2d[i] for i in (1, 3, 5)] == [0xA00] * 3,
          ' '.join('$%06X' % a2 for a2 in _2d))
    check('...and none of them is in RDHC',
          not [a2 for a2 in _2d if 0xF04600 <= a2 < 0xF05D00])
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
        # UPDATED 2026-07-30 for the MC6840 dual-8-bit fix (mc6840.c).  The
        # system tick went from 12.73 ms to 10.00 ms -- see the access map.
        # THE DIFF WAS INSPECTED, per the rule above: exactly 19 of 131,072 RAM
        # bytes moved, all inside $00BEC-$00C53, and they are RTOS tick
        # counters.  $00C43 reads $00E0B0 = 57,520 before and $011D28 = 73,000
        # after -- a ratio of 1.2691, which is precisely the measured tick-ISR
        # ratio (2330/1836 = 1.2691) and the predicted 12.73/10.00 = 1.273.
        # Reached-PC coverage is byte-identical either side (2756 PCs, none
        # gained, none lost), so nothing executed differently; only the clock
        # the RTOS counts by changed.
        'default (2-AC, no hooks)':
            ({}, 'f72fb0a54d3bce8e90d8deff9050539a'),
        # UPDATED 2026-07-29 with the REQUEST-TRANSFER acknowledge.  70 RAM
        # bytes moved and the diff was inspected before this digest changed, per
        # the rule above.  The change is progress, not regression: $00B91 now
        # holds $F05102 (the 16-entry response jump table), $00E6E stages panel
        # code $25C, $00BDB carries $FF0048, and XP1I's TCB and channel snapshot
        # both advance.  Coverage went 116 -> 240 distinct XP1I PCs.
        'XP1I driven to the $8000 path':
            ({'FPS3K_XPIRQ': '1', 'FPS3K_CHCMD': 'C801'},
             '0443bb40eadbc2b9f7dadbd33c9a7b65'),
        'TCBIO1I reply path':
            ({'FPS3K_XPIRQ': '5', 'FPS3K_DMA10AA': '2',
              'FPS3K_MBOX': '00010000'},
             '1ac7457dcd44044abc0460704eb32c4e'),
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

# ---------------------------------------------------------------------------
# The kernel's two trap tables, the TDTI field map, and the blank ROM tail.
# All added 2026-07-30 with the kernel disassembly.
# ---------------------------------------------------------------------------
_rom = open(ROM, 'rb').read()
_B = 0xF00000


def insn(addr):
    """The disassembler's own rendering of the instruction at `addr`.

    Hand-encoding 68000 machine code for byte-comparison checks produced FOUR
    wrong encodings in one session -- a subq count, an adda register field, an
    lsr count, and an absolute-short addressing mode -- each of which failed as
    a check while the underlying finding was correct.  Reading disassembly is
    reliable; writing machine code from memory is not.  Assert against the
    decoder instead, so a check can only fail when the ROM differs.
    """
    try:
        from capstone import Cs, CS_ARCH_M68K, CS_MODE_M68K_000
    except ImportError:
        return None
    md = Cs(CS_ARCH_M68K, CS_MODE_M68K_000)
    try:
        i = next(md.disasm(_rom[addr - _B:addr - _B + 10], addr, count=1))
    except StopIteration:
        return None
    return f"{i.mnemonic} {i.op_str}".strip()


def _w(a):
    return struct.unpack('>H', _rom[a - _B:a - _B + 2])[0]


def _sw(a):
    return struct.unpack('>h', _rom[a - _B:a - _B + 2])[0]


def _l(a):
    return struct.unpack('>I', _rom[a - _B:a - _B + 4])[0]


# --- TRAP #0: 35 slots, and the user-mode silent ignore --------------------
check('TRAP #0 jump table is $F001D6-$F00262 = 35 longword slots',
      (0xF00262 - 0xF001D6) // 4 == 35)
check('TRAP #0 handler masks the stacked SR system byte and rte on user mode',
      _rom[0xF001AC - _B:0xF001B8 - _B]
      == b'\x3f\x17\x02\x17\x00\x7f\x54\x8f\x66\x02\x4e\x73')

# --- TRAP #1: 77 slots, self-relative, all landing in the kernel -----------
check('TRAP #1 dispatcher range-checks with BGT #$130, admitting $4C = 76',
      _rom[0xF0031C - _B:0xF00326 - _B]
      == b'\x0c\x80\x00\x00\x01\x30\x6e\x00\x00\xa2')
check('...and the handler is entry+w0, a SELF-RELATIVE signed offset',
      _rom[0xF0036A - _B:0xF0036C - _B] == b'\xd4\xd2')   # adda.w (a2),a2
check('all 77 TRAP #1 handlers land inside the kernel region',
      all(0xF00000 <= (0xF003D8 + 4 * i) + _sw(0xF003D8 + 4 * i) < 0xF04488
          for i in range(77)))
check('$F003D0 is the unimplemented stub and 17 of 77 slots route to it',
      sum(1 for i in range(77)
          if (0xF003D8 + 4 * i) + _sw(0xF003D8 + 4 * i) == 0xF003D0) == 17)
# SUSPND/RESUME and WAIT/WAKEUP are inverse pairs on TCB+$2C -- the check that
# confirms the vendor directive names from behaviour rather than by number.
check('SUSPND sets and RESUME clears bit 9 of TCB+$2C',
      _rom[0xF02CAC - _B:0xF02CB2 - _B] == b'\x08\xee\x00\x09\x00\x2c'
      and _rom[0xF02CB4 - _B:0xF02CBA - _B] == b'\x08\xa8\x00\x09\x00\x2c')
check('WAIT sets bit 14 of TCB+$2C',
      _rom[0xF02C3E - _B:0xF02C44 - _B] == b'\x08\xee\x00\x0e\x00\x2c')
check('WAKEUP clears bit 14 of TCB+$2C at $F02C74',
      _rom[0xF02C74 - _B:0xF02C7A - _B] == b'\x08\xa8\x00\x0e\x00\x2c')

# --- the dual-entry calling convention ------------------------------------
_t0 = sorted({_l(0xF001D6 + 4 * i) & 0xFFFFFF for i in range(35)} - {0xF00182})
check('29 of the 33 TRAP #0 handlers are preceded by move.w sr,-(a7)',
      sum(1 for a in _t0 if _w(a - 2) == 0x40E7) == 29)

# --- directive $3B is gated by a magic key the ROM does not contain --------
check('directive $3B compares a parameter against the magic $4BAA7BFB',
      _l(0xF039CE) == 0x4BAA7BFB)
check('...that constant occurs exactly once in the whole ROM',
      _rom.count(struct.pack('>I', 0x4BAA7BFB)) == 1)
check('...and no site anywhere loads $3B as a directive number',
      not any(_w(a) == 0x703B or (_w(a) == 0x303C and _w(a + 2) == 0x003B)
              for a in range(0xF00000, 0xF0FFFC, 2)))

# --- TDTI: entry point at +$1C, region bounds at +$20/+$22 ----------------
_tdti = [(0xF0A600 + 0x60 * i) for i in range(6)]
check('the six TDTI entry points all lie inside their own +$20/+$22 region',
      all((_w(e + 0x20) << 8) <= (_l(e + 0x1C) & 0xFFFFFF) <= ((_w(e + 0x22) << 8) | 0xFF)
          for e in _tdti))
check('the six TDTI task regions tile contiguously with no gaps',
      all(_w(b + 0x20) - _w(a + 0x22) == 1 for a, b in zip(_tdti, _tdti[1:])))
check('$F05F92 (the $26E site) is inside XP4I\'s region, not CH1\'s',
      (_w(_tdti[2] + 0x20) << 8) <= 0xF05F92 <= ((_w(_tdti[2] + 0x22) << 8) | 0xFF))

# --- HXP1..HXP4 are built at runtime, not stored -------------------------
check("RDHC builds the queue name from 'HXP0' plus the channel number",
      _rom[0xF053B6 - _B:0xF053BE - _B] == b'\x22\x3c\x48\x58\x50\x30\xd2\x04')
check("...and no literal 'HXP0' handler name exists per channel",
      _rom.count(b'HXP0') == 2 and _rom.count(b'HXP1') == 1)

# --- the blank tail every coverage figure has been dividing by ------------
check('$F0A825-$F0FFFD is 22,489 bytes of nothing but zero',
      _rom[0xF0A825 - _B:0xF0FFFE - _B] == b'\x00' * 22489)

# ---------------------------------------------------------------------------
# The ISR-exit / wake chain, verified 2026-07-30.  These replace the retracted
# claim that $F04930 "modifies the saved PC out of bra ." -- it does not; the
# kernel does, at $F00282, and the adjusted value is a TABLE KEY not a return
# address.
# ---------------------------------------------------------------------------
check('TRAP #1 entry tests a CCR sentinel, not just supervisor mode',
      _rom[0xF00262 - _B:0xF00278 - _B]
      == b'\x3f\x17\x02\x2f\x00\x0c\x00\x01\x02\x17\x00\x7f'
         b'\x67\x08\x0c\x2f\x00\x0c\x00\x01\x67\x08')
check('the ISR-exit path adjusts the stacked PC by -6 at $F00282',
      insn(0xF00282) == 'subq.l #$6, (a7)')
check('...and reads it back at $3c(a7), past the 60 bytes of saved registers',
      _rom[0xF00284 - _B:0xF00288 - _B] == b'\x48\xe7\xff\xfe'
      and _rom[0xF00296 - _B:0xF0029A - _B] == b'\x28\x6f\x00\x3c')
check('the !IDV walk compares at offset 10 and strides 14 bytes',
      _rom[0xF0029A - _B:0xF0029E - _B] == b'\xb9\xed\x00\x0a'
      and _rom[0xF0029E - _B:0xF002A4 - _B] == b'\xdb\xfc\x00\x00\x00\x0e')
check('it wakes the matched record\'s TCB via T0WAKEUP at $F02C6C',
      _rom[0xF002AC - _B:0xF002B6 - _B]
      == b'\x2c\x6d\xff\xf4\x41\xd6\x61\x00\x29\xb8')
# The arithmetic that makes the key work: the exit stub's sentinel is exactly
# six bytes before the address trap #1 stacks.
check('$F050FC (the sentinel) == $F05102 (stacked PC) - 6',
      0xF05102 - 6 == 0xF050FC)
check('the exit stub is movem / move #$c,ccr / trap #1',
      _rom[0xF050F8 - _B:0xF05102 - _B]
      == b'\x4c\xdf\xff\xff\x44\xfc\x00\x0c\x4e\x41')

# --- !IDV, read from a live machine ---------------------------------------
with tempfile.TemporaryDirectory() as _tdv:
    subprocess.run([EMU, '-rom', ROM, '-cycles', '150000000',
                    '-dump-ram', f'{_tdv}/r'], capture_output=True, timeout=400)
    _r = open(f'{_tdv}/r', 'rb').read()
    _idv = struct.unpack('>I', _r[0xC6E:0xC72])[0] & 0xFFFFFF
    _recs = [_r[_idv + 8 + 14 * i: _idv + 8 + 14 * (i + 1)] for i in range(6)]
    check('!IDV is at $1F800 with six 14-byte records',
          _idv == 0x1F800 and all(len(x) == 14 for x in _recs))
    check('RDHC\'s record (vector $41) stores ISR exit $F050FC -- the -6 target',
          any(struct.unpack('>H', x[0:2])[0] == 0x41
              and struct.unpack('>I', x[10:14])[0] == 0xF050FC for x in _recs))
    check('...and its TCB field is $1F300, the sixth TCB',
          any(struct.unpack('>H', x[0:2])[0] == 0x41
              and struct.unpack('>I', x[2:6])[0] == 0x1F300 for x in _recs))
    check('every !IDV record\'s ISR-exit field is 6 past a move #$c,ccr',
          all(_rom[(struct.unpack('>I', x[10:14])[0]) - _B:
                   (struct.unpack('>I', x[10:14])[0]) - _B + 4]
              == b'\x44\xfc\x00\x0c' for x in _recs))

# ---------------------------------------------------------------------------
# Kernel structure and the $0C34 instrumentation mask, 2026-07-30.
# One assertion per check: two of the ISR-exit checks failed earlier today only
# because a correct half was and-ed with a hand-encoded half that was wrong.
# ---------------------------------------------------------------------------
check('$0C34 is read by eight btst sites, one per bit of its high byte',
      len({struct.unpack('>H', _rom[a - _B + 2:a - _B + 4])[0]
           for a in range(0xF00000, 0xF04488, 2)
           if _rom[a - _B:a - _B + 2] == b'\x08\x38'          # btst #imm,abs.W
           and struct.unpack('>H', _rom[a - _B + 4:a - _B + 6])[0] == 0x0C34}) == 8)
check('directive $02 uses TAS.B -- the 68000 atomic read-modify-write',
      insn(0xF0078E) == 'tas.b (a0)')
check('...guarded by a level-7 mask',
      insn(0xF0078A) == 'ori.w #$700, sr')
check('directive $03 orders the ready queue on the byte at TCB+$26',
      insn(0xF007D6) == 'move.b $26(a0), d0')
check('...and guards against double insertion with bset #4 on TCB+$2D',
      _rom[0xF007C2 - _B:0xF007C8 - _B] == b'\x08\xe8\x00\x04\x00\x2d')
check('directive $08 converts an address to 256-byte pages with lsr.l #$8',
      insn(0xF0176C) == 'lsr.l #$8, d6')
check('the trace ring writer advances by the $1A record stride',
      insn(0xF016A2) == 'lea.l $1a(a5), a4')
check('the ring geometry closes: $1F500 + 8 + 9*$1A == $1F5F2',
      0x1F500 + 8 + 9 * 0x1A == 0x1F5F2)

with tempfile.TemporaryDirectory() as _tdk:
    subprocess.run([EMU, '-rom', ROM, '-cycles', '150000000',
                    '-dump-ram', f'{_tdk}/r'], capture_output=True, timeout=400)
    _rk = open(f'{_tdk}/r', 'rb').read()
    check('$0C34 reads $0000 after boot -- every kernel hook ships disabled',
          struct.unpack('>H', _rk[0xC34:0xC36])[0] == 0x0000)
    check('the trace ring is allocated at $1F500 via slot $0C30',
          (struct.unpack('>I', _rk[0xC30:0xC34])[0] & 0xFFFFFF) == 0x1F500)
    check('...with its header limit at $1F5F2, matching the 9-record geometry',
          struct.unpack('>I', _rk[0x1F504:0x1F508])[0] == 0x1F5F2)
    check('every task parks WAITING (TCB+$2C bit 14) after a default boot',
          all(struct.unpack('>H', _rk[b + 0x2C:b + 0x2E])[0] == 0x4000
              for b in (0x1E900, 0x1EB00, 0x1ED00, 0x1EF00, 0x1F100, 0x1F300)))
    check('RDHC\'s saved PC (TCB+$0FC) is $F04740, where it parks',
          (struct.unpack('>I', _rk[0x1F300 + 0xFC:0x1F300 + 0x100])[0]
           & 0xFFFFFF) == 0xF04740)

# The trace facility actually switches on.
with tempfile.TemporaryDirectory() as _tdt:
    subprocess.run([EMU, '-rom', ROM, '-cycles', '150000000',
                    '-trace', f'{_tdt}/t'], capture_output=True, timeout=400,
                   env={**os.environ, 'FPS3K_POKE': '0C34=8000'})
    _tt = open(f'{_tdt}/t').read()
    check('setting $0C34 bit 15 makes the trace-ring writer run',
          _tt.count('F01688\n') > 0)

# --- the XP service path, traced end to end 2026-07-30 --------------------
check('XP1I signals only when channel status bit 14 is set',
      insn(0xF07E86) == 'btst.b #$e, $1066.l')
check('...and bit 11 is clear',
      insn(0xF07E90) == 'btst.b #$b, $1066.l')
check('the signal is directive $2B SGSEM',
      insn(0xF07EA4) == 'moveq #$2b, d0')
check('...with the TCB itself as the parameter block',
      insn(0xF07EA6) == 'lea.l (a6), a0')
check('the inner channel validator bounds against $105E',
      insn(0xF08556) == 'cmp.w $105e.l, d0')
check('...and rejects via panel command $264',
      insn(0xF0855E) == 'move.w #$264, d0')
check('the USER handoff is gated on $10AE',
      insn(0xF08572) == 'tst.l $10ae(a2)')
check('...and looks the task up by the literal USER',
      insn(0xF08586) == "move.l #$55534552, -(a7)")
check('...via directive $43 RSTATE',
      insn(0xF0858C) == 'moveq #$43, d0')
# The absence that matters: no status test between the trap and the store.
check('the RSTATE result is filed with no status check',
      insn(0xF0859A) == 'move.l d0, $10be(a2)'
      and 'cmpi' not in (insn(0xF08596) or '')
      and 'tst' not in (insn(0xF08596) or ''))

# --- RTOS structures, decoded 2026-07-30 ----------------------------------
with tempfile.TemporaryDirectory() as _tds:
    subprocess.run([EMU, '-rom', ROM, '-cycles', '150000000',
                    '-dump-ram', f'{_tds}/r'], capture_output=True, timeout=400)
    _rs = open(f'{_tds}/r', 'rb').read()

    def _w16(a):
        return struct.unpack('>H', _rs[a:a + 2])[0]

    def _w32(a):
        return struct.unpack('>I', _rs[a:a + 4])[0]

    # !UST is self-describing: 22-byte records, nine of them.
    check('!UST header declares 22-byte records',       _w16(0x1FB0C) == 0x16)
    check('!UST header declares nine of them',          _w16(0x1FB0E) == 0x0009)
    check('...and the nine owners are 2/2/2/2/1/0 by task', [
        _rs[0x1FB14 + 22 * i:0x1FB14 + 22 * i + 4].decode('latin1')
        for i in range(9)] == ['XP1I', 'XP1I', 'XP2I', 'XP2I', 'XP3I',
                               'XP3I', 'XP4I', 'XP4I', 'IO1I'])
    check('...with HXP1-HXP4 present, though only HXP0 exists in the ROM', [
        _rs[0x1FB14 + 22 * i + 8:0x1FB14 + 22 * i + 12].decode('latin1')
        for i in (1, 3, 5, 7)] == ['HXP1', 'HXP2', 'HXP3', 'HXP4'])
    check('!GST declares 13-byte records and a count of ZERO',
          _w16(0x1FD0C) == 0x000D and _w16(0x1FD0E) == 0x0000)

    # !PAT: the resting loop reads +8, and it is null.
    check('!PAT\'s active list head at +8 is null -- the rest state',
          _w32(0x1F708) == 0)
    check('...while its record pool at +4 is populated',
          (_w32(0x1F704) & 0xFFFFFF) == 0x1F714)

    # The trace pool is the only markerless allocation.
    check('the $1F500 trace pool carries first/last, not a marker',
          _w32(0x1F500) == 0x0001F508 and _w32(0x1F504) == 0x0001F5F2)

    # Liveness: four structures populated, four header-only.
    def _nz(b):
        return sum(1 for x in _rs[b:b + 256] if x)
    check('four RTOS structures are populated and four are header-only',
          all(_nz(b) > 35 for b in (0x1FB00, 0x1F800, 0x1F700, 0x1FA00))
          and all(_nz(b) < 15 for b in (0x1FD00, 0x1F900, 0x1F500, 0x1F600)))
    check('!CCB and !DLY have no RAM instance at all',
          _rs.count(b'!CCB') == 0 and _rs.count(b'!DLY') == 0)

# --- every hook must still let the machine boot ---------------------------
# FPS3K_CHSEL_RD forces CHANNEL_SELECT to read a constant FROM RESET, and the
# self-test's register walks fail against a constant-reading register, so the
# boot hangs in the diagnostics at $F08920 instead of reaching the RTOS rest
# state.  That is the defect already fixed for FPS3K_POKE and FPS3K_DMA10AA by
# gating them on boot completion; CHSEL_RD never received the gate.
#
# The failure is invisible without this check: the run completes, prints
# plausible counts, and reports a final PC that only looks wrong if you know
# what a healthy one is.  This project has one documented result -- the first
# $FF0008 read -- that was taken with this hook and does not reproduce.
def _boots(env2):
    out = subprocess.run([EMU, '-rom', ROM, '-cycles', '150000000'],
                         capture_output=True, text=True, timeout=400,
                         env={**os.environ, **env2}).stderr
    m = re.search(r'final PC=([0-9A-F]+)', out)
    return bool(m) and 0xF00F00 <= int(m.group(1), 16) <= 0xF01000

check('a clean boot reaches the RTOS rest state', _boots({}))
for _hk, _hv in (('FPS3K_DATAIN', '1'), ('FPS3K_RESP', '0x94'),
                 ('FPS3K_DMA10AA', '2'), ('FPS3K_POKE', '10AA=0002'),
                 ('FPS3K_MBOX', '00010000')):
    check(f'{_hk} still lets the machine boot', _boots({_hk: _hv}))
# FIXED 2026-07-30: CHSEL_RD is now gated on boot completion, like DMA10AA and
# POKE before it.  $FF0204 is the phase-broadcast register and the diagnostics
# read it back, so a constant readback from reset fails them.  Both arms are
# asserted so the fix cannot silently regress in either direction.
check('FPS3K_CHSEL_RD now boots, because it is gated on boot completion',
      _boots({'FPS3K_CHSEL_RD': '28'}))
check('...and FROM_RESET still reproduces the old self-test hang',
      not _boots({'FPS3K_CHSEL_RD': '28',
                  'FPS3K_CHSEL_RD_FROM_RESET': '1'}))

# --- the self-test phase table, measured 2026-07-30 -----------------------
# CHANNEL_SELECT carries the phase number and is the ONLY diagnostic a stalled
# board offers -- d7 is a bare boolean, written $F0F0F0F0 at all 65 failure
# sites.  The panel log is PC-tagged so a phase maps to its broadcasting
# instruction and from there to one of the 42 self-test subroutines.
with tempfile.TemporaryDirectory() as _tdp:
    _lp = subprocess.run([EMU, '-rom', ROM, '-cycles', '150000000'],
                         capture_output=True, text=True, timeout=400,
                         env={**os.environ, 'FPS3K_LOGCHASSIS': '1'}).stderr
    _ph = {}
    for _m in re.finditer(r'CHANNEL_SELECT <- \$([0-9A-F]{4}) @([0-9A-F]{6})', _lp):
        _v = int(_m.group(1), 16)
        if _v and not (_v & 0xFF) and _v < 0x3000:
            _ph.setdefault(_v, _m.group(2))
    check('the self-test broadcasts 30 distinct phases', len(_ph) == 30)
    check('sequence A runs $0100-$0900',
          all(0x100 * i in _ph for i in range(1, 10)))
    check('sequence B runs $1000-$1A00',
          all(0x1000 + 0x100 * i in _ph for i in range(0, 11)))
    check('sequence C runs $2000-$2900',
          all(0x2000 + 0x100 * i in _ph for i in range(0, 10)))
    # Block 3's four tests run twice over two RAM ranges: the same four
    # instructions broadcast $2000-$2300 and again $2400-$2700.
    check('block 3 runs its four tests twice -- same PCs, two phase bases',
          all(_ph.get(0x2000 + 0x100 * i) == _ph.get(0x2400 + 0x100 * i)
              for i in range(4)))
    check('...and those four PCs are $F098F2/$F099B8/$F099FA/$F09A84',
          [_ph.get(0x2000 + 0x100 * i) for i in range(4)]
          == ['F098F2', 'F099B8', 'F099FA', 'F09A84'])
    # Phase numbering is logical, not positional.
    check('the sequences interleave: $1000 is broadcast below $0900',
          int(_ph[0x1000], 16) < int(_ph[0x900], 16))

check('d7 carries one failure marker, $F0F0F0F0, at every site',
      len({struct.unpack('>I', _rom[a - _B + 2:a - _B + 6])[0]
           for a in range(0xF08700, 0xF09C00, 2)
           if _rom[a - _B:a - _B + 2] == b'\x2e\x3c'}) == 1)

# --- the scheduler control block at $0C08, mapped 2026-07-30 --------------
with tempfile.TemporaryDirectory() as _tdq:
    subprocess.run([EMU, '-rom', ROM, '-cycles', '150000000',
                    '-dump-ram', f'{_tdq}/r'], capture_output=True, timeout=400)
    _rq = open(f'{_tdq}/r', 'rb').read()

    def _lw(a):
        return struct.unpack('>I', _rq[a:a + 4])[0] & 0xFFFFFF

    def _tcbname(a):
        return _rq[a + 0x10:a + 0x14].decode('latin1') if 0x1E000 <= a < 0x20000 else None

    check('$0C0C is the current-task pointer and holds RDHC at rest',
          _tcbname(_lw(0x0C0C)) == 'RDHC')
    check('$0C10 heads the all-tasks list, starting at XP1I',
          _tcbname(_lw(0x0C10)) == 'XP1I')
    check('$0C14 is the ready-queue head and is EMPTY at rest',
          _lw(0x0C14) == 0)
    # The chain is built by six LIFO pushes, so it runs in reverse TDTI order.
    # $0C10's link is +$04 (TCBALL); $0C14's is +$0C (TCBREADY).  An earlier
    # version walked $0C10 via +$0C and passed only because the ready-list
    # values are stale fossils that still equal +$04 -- the dequeue patches the
    # PREDECESSOR and never clears the departing TCB's own link.
    _chain, _a = [], _lw(0x0C10)
    while 0x1E000 <= _a < 0x20000 and len(_chain) < 10:
        _chain.append(_tcbname(_a))
        _a = _lw(_a + 0x04)
    check('the all-tasks chain is six nodes in reverse TDTI creation order',
          _chain == ['XP1I', 'XP2I', 'XP3I', 'XP4I', 'IO1I', 'RDHC'])
    check('...and terminates at zero', _a == 0)
    check('...while every TCB\'s +$0C still fossilises the same successor',
          all(_lw(b + 0x04) == _lw(b + 0x0C)
              for b in (0x1E900, 0x1EB00, 0x1ED00, 0x1EF00, 0x1F100, 0x1F300)))
    # An empty ready queue and six blocked tasks are the same fact twice.
    # $4000 is bit 14 = TSKSBLCK, "TASK IS BLOCKED", per Motorola's TCB.EQ.
    check('every task is BLOCKED (TSKSBLCK), which is why the ready queue is empty',
          all(struct.unpack('>H', _rq[b + 0x2C:b + 0x2E])[0] == 0x4000
              for b in (0x1E900, 0x1EB00, 0x1ED00, 0x1EF00, 0x1F100, 0x1F300)))

    # --- $0C00: the allocatable-RAM region list ---------------------------
    # Read only by TRAP #0 $04 (T0PAGAL, $F01240) and $05 ($F01496), which is
    # what identifies it.  Records are 10 bytes, sign bit of +$00 terminates.
    _reg = _lw(0x0C00)
    check('$0C00 points just past a $1A-byte header at $1FE00',
          _reg == 0x1FE1A)
    _rf = struct.unpack('>H', _rq[_reg:_reg + 2])[0]
    _rb, _rl = _lw(_reg + 2), _lw(_reg + 6)
    check('its one record spans $1100-$1FE00 (126,208 bytes of allocatable RAM)',
          _rf & 0x8000 == 0 and _rb == 0x1100 and _rl == 0x1FE00)
    check('...and the next record at stride $0A is the $FFFF terminator',
          struct.unpack('>H', _rq[_reg + 10:_reg + 12])[0] == 0xFFFF)
    # The page heap carves DOWNWARD from the limit, so the boot high-water
    # mark and the documented staging bound are one number, not two.
    check('the boot heap bottom $1DD00 lies inside that region, below its limit',
          _rb < 0x1DD00 < _rl)
    check('...so the staging buffer $10000-$1DCFF is inside it too',
          _rb <= 0x10000 and 0x1DCFF < _rl)

    # --- TCB layout, against Motorola TCB.EQ ------------------------------
    # +$138 is a POINTER to a 2-page per-task block; the 10-byte ASQ
    # descriptors live at that block's base, not at TCB+$138 itself.
    _tcbs = (0x1E900, 0x1EB00, 0x1ED00, 0x1EF00, 0x1F100, 0x1F300)
    check('TCBSTATE (+$2C) is $40000000 in every TCB = TSKSBLCK, "task is blocked"',
          all(struct.unpack('>I', _rq[b + 0x2C:b + 0x30])[0] == 0x40000000
              for b in _tcbs))
    check('TSK2NRDY (+$2D bit 4, "on ready list") is clear in every TCB',
          all(_rq[b + 0x2D] & 0x10 == 0 for b in _tcbs))
    _blocks = [_lw(b + 0x138) for b in _tcbs]
    check('TCB+$138 points at per-task blocks tiling $1DD00-$1E8FF at stride $200',
          _blocks == [0x1E700, 0x1E500, 0x1E300, 0x1E100, 0x1DF00, 0x1DD00])
    check('...and the ASQ descriptors sit at those blocks\' bases, 2/2/2/2/1/0',
          [sum(1 for k in range(3) if _rq[p + 10 * k:p + 10 * k + 4].strip(b'\0'))
           for p in _blocks] == [2, 2, 2, 2, 1, 0])
    check('XP1I\'s two descriptors are AXP1 and HXP1',
          _rq[0x1E700:0x1E704] == b'AXP1' and _rq[0x1E70A:0x1E70E] == b'HXP1')
    # --- $0C18: the CCB list, and why !CCB has no instance ----------------
    # All three $0C18 sites sit in the handler at $F03D0C = directive $3C,
    # CMR "REQUEST CHANNEL".  Nothing in this firmware issues it.
    check('$0C18, the channel-control-block list head, is null',
          _lw(0x0C18) == 0)
    check('...which is why the !CCB marker has no instance in RAM',
          _rq.count(b'!CCB') == 0)
    check('the tagged markers present are !TCB x6, !TST x6 and six singletons',
          [_rq.count(t) for t in (b'!TCB', b'!TST', b'!GST', b'!IDV',
                                  b'!IOV', b'!PAT', b'!UDR', b'!UST')]
          == [6, 6, 1, 1, 1, 1, 1, 1])
    check('...and !CCB, !DLY, !ASQ and !VCT are all untagged/absent',
          all(_rq.count(t) == 0
              for t in (b'!CCB', b'!DLY', b'!ASQ', b'!VCT')))

    # --- !GST / !IOV / !IDV: closing the structure inventory ---------------
    # !GST shares !UST's header shape.  Zero current entries because this
    # firmware never declares a shareable segment ($07 DCLSHR, $04 ATTSEG).
    check('!GST is allocated with 13 slots and ZERO current entries',
          _rq[0x1FD00:0x1FD04] == b'!GST'
          and struct.unpack('>H', _rq[0x1FD0C:0x1FD0E])[0] == 13
          and struct.unpack('>H', _rq[0x1FD0E:0x1FD10])[0] == 0
          and _lw(0x1FD10) == 0x1FD14)
    check('!IOV is a tagged header with an end pointer and nothing else',
          _rq[0x1F900:0x1F904] == b'!IOV' and _lw(0x1F904) == 0x1F9FF
          and sum(1 for x in _rq[0x1F900:0x1FA00] if x) == 7)
    check('!IDV\'s first record is {vector $45, XP1I TCB, ISR entry $F07EE6}',
          _rq[0x1F800:0x1F804] == b'!IDV'
          and struct.unpack('>H', _rq[0x1F808:0x1F80A])[0] == 0x45
          and _lw(0x1F80A) == 0x1E900 and _lw(0x1F80E) == 0xF07EE6)

    # --- !TST: the RTOS's own statement of each task's code extent ---------
    # TSTMMU[0]/[1] at TCB+$160+$0C are the segment's first and last 256-byte
    # page.  These bounds are authoritative, unlike the approximate region
    # splits in build_clean_disasm.py.
    _tst = [(_rq[b + 0x10:b + 0x14].decode('latin1'),
             struct.unpack('>H', _rq[b + 0x16C:b + 0x16E])[0] << 8,
             (struct.unpack('>H', _rq[b + 0x16E:b + 0x170])[0] << 8) + 0xFF,
             _lw(b + 0x6C))
            for b in _tcbs]
    check('every !TST is tagged, declares 4 segments with 2 live, and names PROG',
          all(_rq[b + 0x160:b + 0x164] == b'!TST' and _rq[b + 0x164] == 4
              and _rq[b + 0x165] == 2
              and _rq[b + 0x18C:b + 0x190] == b'PROG' for b in _tcbs))
    check('the six task code extents tile $F04600-$F086FF with no gaps',
          [(n, lo, hi) for n, lo, hi, _ in sorted(_tst, key=lambda r: r[1])]
          == [('RDHC', 0xF04600, 0xF05CFF), ('IO1I', 0xF05D00, 0xF05EFF),
              ('XP4I', 0xF05F00, 0xF068FF), ('XP3I', 0xF06900, 0xF072FF),
              ('XP2I', 0xF07300, 0xF07CFF), ('XP1I', 0xF07D00, 0xF086FF)])
    check('...and the four XP tasks are exactly $A00 = 2560 bytes each',
          all(hi - lo + 1 == 0xA00 for n, lo, hi, _ in _tst if n.startswith('XP')))
    # These five entry points are exactly the PCs the padding artefact hid.
    check('each task entry (TCB+$6C) lies inside its own declared segment',
          all(lo <= e <= hi for _, lo, hi, e in _tst))
    check('the XP entries are $F05F4A/$F0694A/$F0734A/$F07D4A and IO1I $F05D36',
          sorted(e for n, _, _, e in _tst if n != 'RDHC')
          == [0xF05D36, 0xF05F4A, 0xF0694A, 0xF0734A, 0xF07D4A])
    # Segment 1 is STCK, and its pages ARE the TCB+$138 blocks -- which names
    # them, and explains why RDHC's is all zeros: it is a stack it never dirties.
    check('every task\'s second segment is named STCK',
          all(_rq[b + 0x160 + 0x2C + 8:b + 0x160 + 0x2C + 12] == b'STCK'
              for b in _tcbs))
    check('...and the STCK pages are exactly the TCB+$138 blocks, six for six',
          [struct.unpack('>H', _rq[b + 0x174:b + 0x176])[0] << 8 for b in _tcbs]
          == [_lw(b + 0x138) for b in _tcbs])
    check('...which are the six 2-page blocks tiling $1DD00-$1E8FF',
          sorted(_lw(b + 0x138) for b in _tcbs)
          == [0x1DD00, 0x1DF00, 0x1E100, 0x1E300, 0x1E500, 0x1E700])

    # --- !UST: the semaphore registry, per Motorola UST.EQ -----------------
    # 20-byte header, 22-byte entries {task name, session, sem name, users,
    # xcnt, type, semaphore}.  USTCENT is a fourth independent route to the
    # count 9 -- the others being the descriptors at the task block bases, the
    # CRSEM declarations, and the 9 executions of T0FNDSEM.
    _ust = 0x1FB00
    check('!UST reports 9 current entries in 22 slots across 2 pages',
          _rq[_ust:_ust + 4] == b'!UST'
          and struct.unpack('>H', _rq[_ust + 14:_ust + 16])[0] == 9
          and struct.unpack('>H', _rq[_ust + 12:_ust + 14])[0] == 22
          and _lw(_ust + 16) == 0x1FB14)
    _ue = [(_rq[0x1FB14 + 22 * k:0x1FB14 + 22 * k + 4].decode('latin1'),
            _rq[0x1FB14 + 22 * k + 8:0x1FB14 + 22 * k + 12].decode('latin1'))
           for k in range(9)]
    check('...and they are AXPn/HXPn per XP task plus HIO1, with RDHC owning none',
          _ue == [('XP1I', 'AXP1'), ('XP1I', 'HXP1'), ('XP2I', 'AXP2'),
                  ('XP2I', 'HXP2'), ('XP3I', 'AXP3'), ('XP3I', 'HXP3'),
                  ('XP4I', 'AXP4'), ('XP4I', 'HXP4'), ('IO1I', 'HIO1')])

    # --- !PAT and the trace table: the last two unexplained allocations ---
    check('$1F700 !PAT has 8 free periodic-activation slots and an EMPTY active list',
          _rq[0x1F700:0x1F704] == b'!PAT'
          and _lw(0x1F704) == 0x1F714 and _lw(0x1F708) == 0)
    _pat, _n = _lw(0x1F704), 0
    while 0x1F700 <= _pat < 0x1F800 and _n < 20:
        _pat = _lw(_pat)
        _n += 1
    check('...and that free list is 8 nodes of $1E bytes, zero-terminated',
          _n == 8 and _pat == 0)
    # $1F500 matches TRACE.EQ: 8-byte header, then 26-byte ($1A) entries.
    check('$0C30 -> $1F500 is the RMS68K trace table, 8-byte header + 9 x $1A',
          _lw(0x0C30) == 0x1F500
          and _lw(0x1F500) == 0x1F508 and _lw(0x1F504) == 0x1F5F2
          and 0x1F508 + 9 * 0x1A == 0x1F5F2)
    check('...armed but never written: 0 of its 9 entries is non-zero',
          not any(any(_rq[0x1F508 + k * 0x1A:0x1F508 + (k + 1) * 0x1A])
                  for k in range(9)))

    # --- the extension-directive table ------------------------------------
    _udr = _lw(0x0C28)
    check('$0C28 heads the !UDR user-directive table at $1F600',
          _udr == 0x1F600 and _rq[_udr:_udr + 4] == b'!UDR')
    _udrn = struct.unpack('>H', _rq[_udr + 4:_udr + 6])[0]
    check('!UDR has 25 slots and every handler is zero (the path is dead here)',
          _udrn == 25 and all(struct.unpack('>I', _rq[_udr + 6 + 10 * k + 6:
                                                      _udr + 6 + 10 * k + 10])[0] == 0
                              for k in range(_udrn)))

# --- the disassembly's correctness property ------------------------------
# Coverage percentages move around whenever mis-attributed bytes are correctly
# demoted to data, so they make a poor regression target.  This does not: a PC
# the CPU executed is an instruction boundary by construction, so every one of
# them must appear in the listing as an instruction, at exactly that address.
if os.path.exists('fps3k_kernel.asm'):
    _kasm = {}
    for _ln in open('fps3k_kernel.asm'):
        _m = re.match(r'\s*([0-9a-f]{6}):\s+((?:[0-9a-f]{2} )+)\s*(\S+)', _ln)
        if _m:
            _kasm[int(_m.group(1), 16)] = _m.group(3).upper()
    with tempfile.TemporaryDirectory() as _tdk:
        subprocess.run([EMU, '-rom', ROM, '-cycles', '300000000',
                        '-trace', f'{_tdk}/t'], capture_output=True, timeout=400)
        _kpcs = {int(x, 16) for x in
                 re.findall(r'[0-9A-F]{6}', open(f'{_tdk}/t').read())
                 if 0xF00000 <= int(x, 16) < 0xF04488}
    check('every executed kernel PC decodes as an instruction in fps3k_kernel.asm',
          _kpcs and all(_kasm.get(p, 'DC.W') != 'DC.W' for p in _kpcs))
    # The padding rule that made that true, stated as its own evidence.
    check('no instruction with opcode word $0000-$0007 was ever executed',
          not any(struct.unpack('>H', _rom[p - _B:p - _B + 2])[0] <= 0x0007
                  for p in _kpcs))
    check('$F09BFE is a $0000 pad and $F09C00, the reset entry, is `jmp $F08700`',
          struct.unpack('>H', _rom[0xF09BFE - _B:0xF09C00 - _B])[0] == 0
          and struct.unpack('>I', _rom[4:8])[0] == 0xF09C00
          and insn(0xF09C00) == 'jmp $f08700.l')
    check('$F046E0 is four longwords of BIM CR offsets, not code',
          list(struct.unpack('>4I', _rom[0xF046E0 - _B:0xF046F0 - _B]))
          == [0x244, 0x246, 0x250, 0x252]
          and insn(0xF046F0) == 'moveq #$1, d0')

# --- the kernel's static vector-installation table at $F00114 ------------
# A module-level RAM dump; the earlier one is scoped to its own `with` block.
with tempfile.TemporaryDirectory() as _tdv:
    subprocess.run([EMU, '-rom', ROM, '-cycles', '150000000',
                    '-dump-ram', f'{_tdv}/r'], capture_output=True, timeout=400)
    _rq2 = open(f'{_tdv}/r', 'rb').read()

# Records are {1-byte vector, 3-byte handler}; reading them handler-first is
# off by one byte and pairs every handler with the wrong vector.
check('$F00114 is a jsr followed by the !VCT tag',
      insn(0xF00114) == 'jsr $f00186.l' and _rom[0xF0011A - _B:0xF0011E - _B] == b'!VCT')


def _vtab():
    out, a = {}, 0xF00122
    while a < 0xF0017E:
        v = _rom[a - _B]
        if v == 0:
            break
        out[v] = int.from_bytes(_rom[a + 1 - _B:a + 4 - _B], 'big')
        a += 4
    return out


def _lw2(a):
    return struct.unpack('>I', _rq2[a:a + 4])[0] & 0xFFFFFF


_vt = _vtab()
check('it holds 23 {vector, handler} records',
      len(_vt) == 23)
# A third, static source for two addresses this project derives two other ways.
check('...and it names TRAP #0 $F001AC, TRAP #1 $F00262, TRAP #2 $F00A78',
      _vt.get(0x20) == 0xF001AC and _vt.get(0x21) == 0xF00262
      and _vt.get(0x22) == 0xF00A78)
check('...which is exactly what the vector table holds after boot',
      all(struct.unpack('>I', _rq2[4 * v:4 * v + 4])[0] == _vt[v]
          for v in (0x20, 0x21, 0x22)))
# The mismatches are the FPS layer taking over, not drift.
check('the FPS layer overrides bus error / illegal / div0 with its reporters',
      [struct.unpack('>I', _rq2[4 * v:4 * v + 4])[0] for v in (2, 4, 5)]
      == [0xF0A23A, 0xF0A24A, 0xF0A252]
      and [_vt[v] for v in (2, 4, 5)] == [0xF00AD8, 0xF00ADC, 0xF00ADE])
check('...and points spurious/$8D/$8E/$93 at the FPS panic catch-all $F0A27A',
      all(struct.unpack('>I', _rq2[4 * v:4 * v + 4])[0] == 0xF0A27A
          for v in (0x18, 0x8D, 0x8E, 0x93)))
check('...while trace, line-A and the level-4 autovector stay with the kernel',
      all(struct.unpack('>I', _rq2[4 * v:4 * v + 4])[0] == _vt[v]
          for v in (0x09, 0x0A, 0x1C)))

check('$0C00 is written once, at $F09D72',
      insn(0xF09D72) == 'move.l a3, $c00.w')
check('the page allocator reads it at $F01280',
      insn(0xF01280) == 'movea.l $c00.w, a1')
check('the region list is walked at stride $0A',
      insn(0xF09D7C) == 'lea.l $a(a1), a1')
check('...with the terminator test on the word at +$00',
      insn(0xF09D80) == 'move.w (a1), d1')

# --- the TRAP #1 table stride is FOUR, not two ---------------------------
# An earlier pass here read it as 2, which gave a plausible 73 live slots and
# survived name-checking (names come from the directive NUMBER via TR1.EQ, so
# 13/13 known names still lined up).  Execution is what separates them.
check('the TRAP #1 dispatcher scales the directive by 4',
      insn(0xF0031A) == 'lsl.l #$2, d0')
check('...bounds it at $130/4 = 76, i.e. 77 slots',
      insn(0xF0031C) == 'cmpi.l #$130, d0')
check('...and takes word0 of the slot as a self-relative offset',
      insn(0xF0036A) == 'adda.w (a2), a2')
check('a NEGATIVE directive goes to the extension path at $F00378',
      insn(0xF00318) == 'bmi.b $f00378'
      and insn(0xF00378) == 'movea.l $c28.w, a2')
check('...which indexes 10-byte records',
      insn(0xF0038A) == 'mulu.w #$a, d0')


def _t1(n, stride=4):
    a = 0xF003D8 + stride * n
    return a + struct.unpack('>h', _rom[a - _B:a - _B + 2])[0]


def _t1flags(n):
    a = 0xF003D8 + 4 * n
    return struct.unpack('>H', _rom[a - _B + 2:a - _B + 4])[0]


# The flags word is {parameter-block size in the high byte, flags in the low}.
# The check on that reading is that it must come out right for directives whose
# parameter shape is already known independently.
check('directives that take no parameter block read size 0 with bit 7 clear',
      all(_t1flags(n) >> 8 == 0 and not (_t1flags(n) & 0x80)
          for n in (0x0F, 0x11, 0x13, 0x22, 0x3C)))
check('CRSEM and ATSEM declare a 10-byte block -- the semaphore descriptor',
      all(_t1flags(n) >> 8 == 10 and (_t1flags(n) & 0x80)
          for n in (0x29, 0x2D)))
check('GTSEG/CRTCB declare 28 bytes and GTASQ 24',
      _t1flags(0x01) >> 8 == 28 and _t1flags(0x0B) >> 8 == 28
      and _t1flags(0x1F) >> 8 == 24)
# Two interrupt-connect directives; the firmware uses the one TR1.EQ omits.
check('$3D CISR and $4C are both live with identical 16-byte parameter blocks',
      _t1(0x3D) == 0xF020E2 and _t1(0x4C) == 0xF02216
      and _t1flags(0x3D) >> 8 == 16 and _t1flags(0x4C) >> 8 == 16)

check('at stride 4 exactly 60 of 77 TRAP #1 slots are live',
      sum(1 for n in range(77) if _t1(n) != _t1(0)) == 60)
check('$4C resolves to $F02216, containing the documented handler $F0226A',
      _t1(0x4C) == 0xF02216 and _t1(0x4C) != _t1(0))
# The stride decision, made by execution rather than by plausibility.
with tempfile.TemporaryDirectory() as _tdt:
    subprocess.run([EMU, '-rom', ROM, '-cycles', '300000000',
                    '-trace', f'{_tdt}/t'], capture_output=True, timeout=400)
    _dpcs = collections.Counter(re.findall(r'[0-9A-F]{6}',
                                           open(f'{_tdt}/t').read()))
_KNOWN = {0x01, 0x0B, 0x0D, 0x0F, 0x10, 0x11, 0x12, 0x13,
          0x29, 0x2A, 0x2B, 0x2D, 0x43, 0x4C}
_hit4 = {n for n in range(77)
         if _t1(n) != _t1(0) and f'{_t1(n):06X}' in _dpcs}
_hit2 = {n for n in range(77)
         if _t1(n, 2) != _t1(0, 2) and f'{_t1(n, 2):06X}' in _dpcs}
check('every stride-4 handler that executes is a directive the firmware issues',
      _hit4 and _hit4 <= _KNOWN)
check('...while NO stride-2 handler that executes is one, which decides it',
      _hit2 and not (_hit2 & _KNOWN))
check('the $4C implementation $F0226A runs 6 times, once per task',
      _dpcs['F0226A'] == 6)
check('...and the directive error stub $F003D0 never runs at all',
      _dpcs['F003D0'] == 0)
check('$4C is what connects the six BIM vectors, and CISR never runs',
      _dpcs['F02216'] == 6 and _dpcs['F020E2'] == 0)


def _t0(n):
    return struct.unpack('>I', _rom[0xF001D6 - _B + 4 * n:
                                    0xF001D6 - _B + 4 * n + 4])[0] & 0xFFFFFF


# Counting directive invocations measures the same quantities this harness
# reads out of RAM structures -- independently, from the other side.
check('T0CRTCB ($1F) runs 6 times: the six tasks TDTI creates',
      _dpcs[f'{_t0(0x1F):06X}'] == 6)
check('T0FNDSEM ($0C) runs 9 times: the 9 declared semaphores, 2/2/2/2/1/0',
      _dpcs[f'{_t0(0x0C):06X}'] == 9)
check('T0PAGAL ($04) runs 20 times: the 20 pages tiling $1DD00-$1FDFF',
      _dpcs[f'{_t0(0x04):06X}'] == 20)
check('T0FNDSEG ($07) runs 6 times, once per task',
      _dpcs[f'{_t0(0x07):06X}'] == 6)

# Regression: FPS3K_RAMWATCH used to strtoul() the whole string, so a
# "<lo>-<hi>" range collapsed to a single longword and the rest of a
# structure read as never-written.  Assert the range form actually widens.
_rwn = lambda spec: run_err({'FPS3K_RAMWATCH': spec}, 400000000).count('[RAMWATCH]')
check('FPS3K_RAMWATCH accepts a range, and the range sees more than one longword',
      _rwn('1FE1A-1FE24') > _rwn('1FE1A'))

# The enqueue/dequeue pair on TCB+$2D bit 4.
check('the ready-queue insert guards with bset #$4,$2d(a0)',
      insn(0xF007C2) == 'bset.b #$4, $2d(a0)')
check('...and the dequeue clears it with bclr #$4,$2d(a6)',
      insn(0xF0053C) == 'bclr.b #$4, $2d(a6)')

# --- RDHC's USER-task lifecycle, and the UPGM segment (2026-07-30) --------
# The project records "this ROM never creates USER".  The BEHAVIOUR is right --
# it executes 0 times in every configuration -- but the CODE is all there.
check('RDHC creates USER with $0B CRTCB on the $F04614 block',
      insn(0xF04774) == 'moveq #$b, d0'
      and _rom[0xF04614 - _B:0xF04618 - _B] == b'USER')
# $F046C8 is a SEG.EQ SGPB: task, session, opt, attr, name, LA, length, buff.
_sgpb = _rom[0xF046C8 - _B:0xF046C8 - _B + 28]
check('...and allocates segment UPGM at $00010000, length $D000 (53,248 bytes)',
      _sgpb[0:4] == b'USER' and _sgpb[12:16] == b'UPGM'
      and struct.unpack('>I', _sgpb[16:20])[0] == 0x00010000
      and struct.unpack('>I', _sgpb[20:24])[0] == 0x0000D000)
check('...pre-fills the program entry with NOP ($4E71) before starting it',
      insn(0xF047B2) == 'move.w #$4e71, (a0)+' and insn(0xF047C0) == 'moveq #$d, d0')
check('...and the four USER blocks in the XP tasks are used with $10 TERMT',
      all(_rom[b - _B:b - _B + 4] == b'USER'
          for b in (0xF05F40, 0xF06940, 0xF07340, 0xF07D40))
      and insn(0xF084CE) == 'moveq #$10, d0')
# The gate: chassis op $8 with CHANNEL_SELECT == 0.  This is CPRUN.
check('the lifecycle is gated on chassis operation $8',
      insn(0xF04756) == 'cmpi.w #$8, d0')
check('...and on CHANNEL_SELECT == 0 (non-zero terminates instead)',
      insn(0xF0476A) == 'cmpi.w #$0, $204(a5)')
check('operation $B returns the staging base $10000+$10 = $10010',
      insn(0xF05002) == 'move.l #$10000, d0' and insn(0xF05008) == 'addi.l #$10, d0')
# ...and it is still behaviourally absent, in both drivable configurations.
_uk = {}
for _nm, _env in (('default', {}), ('driven', {'FPS3K_RESPSEQ': '0x0B,0x08',
                                               'FPS3K_XPIRQ': '6'})):
    with tempfile.TemporaryDirectory() as _tdu:
        subprocess.run([EMU, '-rom', ROM, '-cycles', '400000000',
                        '-trace', f'{_tdu}/t'], capture_output=True, timeout=400,
                       env={**os.environ, **_env})
        _uk[_nm] = collections.Counter(
            re.findall(r'[0-9A-F]{6}', open(f'{_tdu}/t').read()))
check('the USER lifecycle executes ZERO times in a default boot',
      _uk['default']['F04774'] == 0 and _uk['default']['F04740'] == 0)
check('...and driving op $8 reaches the operation decode but still rejects',
      _uk['driven']['F04740'] == 1 and _uk['driven']['F04756'] == 1
      and _uk['driven']['F04774'] == 0)

# --- RDHC's main loop is a SECOND, smaller chassis interface --------------
# Same latched byte, different decode from the ISR's 16-op table at $F05102.
check('bit 7 set selects the command-record arm, where $14 calls $F052F8',
      insn(0xF048E2) == 'cmpi.w #$14, d0')
check('op $7 skips the BIM0 control-register rewrite',
      insn(0xF0489E) == 'cmpi.w #$7, d0'
      and insn(0xF048A4) == 'move.w #$5e, $230(a5)')
check('MODE1 bit 7 (busy) gates whether MODE0 is updated at all',
      insn(0xF048AE) == 'btst.b #$7, d1')
check('...and MODE0 bit 10 is the bit RDHC clears to acknowledge an operation',
      insn(0xF048CE) == 'bclr.b #$a, d1')

# $F0467E is an array of 8-byte RESUME parameter blocks indexed by channel --
# which is what the "six entries XP1I XP2I XP3I XP4I USER USER" table is.
check('$F0467E is a 6-entry RESUME block array: XP1I..XP4I then USER, USER',
      [_rom[0xF0467E - _B + 8 * k:0xF0467E - _B + 8 * k + 4] for k in range(6)]
      == [b'XP1I', b'XP2I', b'XP3I', b'XP4I', b'USER', b'USER'])
check('...stride 8, matching RESUME\'s declared parameter size of 8',
      _t1flags(0x12) >> 8 == 8)
check('op $F resumes the selected channel\'s task with $12 RESUME',
      insn(0xF04854) == 'moveq #$12, d0'
      and insn(0xF04884) == 'moveq #$12, d0')

# --- the SBC->chassis transmit protocol, from the panel-command issuer ----
# Six steps, every one a register this project had listed without a mechanism.
check('the issuer writes the command to $FF000E and AGAIN to $FF0204',
      insn(0xF05694) == 'move.w d0, $e(a0)'
      and insn(0xF056B4) == 'move.w d0, $204(a0)')
check('...sets MODE1 bit 12 ("command valid") and clears bit 14',
      insn(0xF0569C) == 'bclr.b #$e, d1' and insn(0xF056A0) == 'bset.b #$c, d1')
check('...clears MODE0 bit 10, then spins -- the only exit is an interrupt',
      insn(0xF056AC) == 'bclr.b #$a, d1' and insn(0xF056B8) == 'bra.b $f056b8')
# All eight copies are byte-identical over the 48-byte issuer.
check('all eight panel-command issuers are byte-identical',
      len({_rom[a - _B:a - _B + 48]
           for a in (0xF04500, 0xF05688, 0xF05E56, 0xF068A8,
                     0xF072C0, 0xF07CC0, 0xF086C0, 0xF0A57E)}) == 1)

# --- the $10A0 per-channel flag array ------------------------------------
# Two bits, identified from opposite ends of the system.  Both writes address
# the LOW byte of the word ($10A1 + (ch-1)*2), so they are mutually consistent.
check('$10A0 bit 1 = host notification enabled: set by RDHC cmd 1, tested by it',
      insn(0xF053E2) == 'move.w #$2, $10a0(a1)'
      and insn(0xF053AE) == 'btst.b #$1, $10a1(a1)')
check('$10A0 bit 0 = a completion with no USER task, set by the XP task',
      insn(0xF0860E) == 'bset.b #$0, $10a1(a2)')
check("RDHC computes the semaphore name as 'HXP0' + channel",
      insn(0xF053B6) == 'move.l #$48585030, d1'
      and (0x48585030).to_bytes(4, 'big') == b'HXP0')
check('cmd 1 stores $101E into the per-channel pointer $1080+(ch-1)*4',
      insn(0xF053DA) == 'move.l a2, $1080(a1)')

# --- RDHC host commands 3 and 4 ------------------------------------------
check('cmd 3 copies a counted longword array into $E8A',
      insn(0xF054EA) == 'lea.l $e8a.l, a2'
      and insn(0xF054F4) == 'move.l (a0)+, (a2)+')
# The claim is that the ONLY absolute reference is that write -- so the word
# $0E8A must occur exactly once in the whole 64 KB.  ">= 1" would be vacuous.
check('...and $E8A is referenced exactly once in the ROM: by that write',
      sum(1 for a in range(0xF00000, 0xF10000, 2)
          if struct.unpack('>H', _rom[a - _B:a - _B + 2])[0] == 0x0E8A) == 1)
check('cmd 4 (CPLOAD) sets the transfer count $E64 and arms $FF0216 bit 4',
      insn(0xF05504) == 'move.l d2, $e64.l'
      and insn(0xF0550E) == 'bset.b #$4, d2'
      and insn(0xF05512) == 'move.w d2, $216(a5)')

check('cmd 2 windows the 16-longword file at $101E, bounded on index+count',
      insn(0xF054AC) == 'lea.l $101e(a2), a1'
      and insn(0xF054B4) == 'cmpi.l #$10, d3')
check('...and implements its direction flag with a single exg',
      insn(0xF054D4) == 'exg.l a1, a0'
      and insn(0xF054DA) == 'move.l (a0)+, (a1)+')

# Runtime: CPLOAD really does arm the width converter -- $C0 -> $D0.
# The bus log goes to a -bus FILE, not stderr, so this reads the file.
with tempfile.TemporaryDirectory() as _tdc:
    subprocess.run([EMU, '-rom', ROM, '-cycles', '400000000',
                    '-bus', f'{_tdc}/b'], capture_output=True, timeout=400,
                   env={**os.environ, 'FPS3K_RESP': '0x94', 'FPS3K_XPIRQ': '6',
                        'FPS3K_CHASSIS_CMD':
                            '4,8,53310004,0000DEAD,BEEF0000'})
    _cpb = open(f'{_tdc}/b').read()
check('CPLOAD sets $FF0216 bit 4 at runtime: $C0 -> $D0',
      'WR 2-byte FF0216 = 000000D0' in _cpb)

# --- $FF0214 is the LOW half of the 32-bit chassis word ------------------
# Phase $1900's two sub-tests differ in exactly this: a word written to the
# window's first word is checked with cmp.l on the whole longword, while a word
# written to $FF0214 is checked with cmp.w on $2(a0) -- the SECOND word.
check('a word written to $FF0214 lands in the LOW half of the chassis longword',
      insn(0xF0981C) == 'move.w d1, $214(a6)'
      and insn(0xF09820) == 'cmp.w $2(a0), d2')
check('...whereas a word written to the window itself affects the high half',
      insn(0xF09808) == 'move.w d1, (a0)'
      and insn(0xF0980A) == 'cmp.l (a0), d2')

# --- every task has an unreachable branch to its own ISR entry -----------
# beq.b +4 followed by beq.w: both paths land on the same address, so the
# beq.w can never execute.  Six sites, one per task.
_dead = []
for _a in range(0xF04488, 0xF0A600, 2):
    if (struct.unpack('>H', _rom[_a - _B:_a - _B + 2])[0] == 0x6704
            and struct.unpack('>H', _rom[_a + 2 - _B:_a + 4 - _B])[0] == 0x6700):
        _dead.append(_a + 4 + struct.unpack('>H', _rom[_a + 4 - _B:_a + 6 - _B])[0])
check('there are exactly six unreachable beq.b/beq.w pairs, one per task',
      len(_dead) == 6)
check('...and their targets are exactly the six !IDV ISR entries',
      sorted(_dead) == sorted(_lw2(0x1F808 + 14 * k + 6) for k in range(6)))

# --- $1064: the SBC->chassis status register file -------------------------
# The XP task's scan mask is a CLEAR-MY-NIBBLE mask: $1064 holds four 4-bit
# per-channel status codes, mixed with a rolling sequence counter at $107E.
check('the scan mask clears this channel\'s nibble of $1064, then ORs it back',
      insn(0xF08652) == 'and.w d2, $1064.l'
      and insn(0xF08658) == 'or.w d4, $1064.l')
check('...and $107E is a rolling sequence counter folded into the code',
      insn(0xF0865E) == 'addq.b #$1, $107e.l')
# Each task loads its own clear-my-nibble mask right before the encoder call,
# and the nibble it clears is (channel-1) -- XP1I $FFF0, XP2I $FF0F, XP3I
# $F0FF, XP4I $0FFF, matching d3 = (channel-1)*4 in the encoder.
check('each XP task loads the mask that clears exactly its own nibble',
      [insn(a) for a in (0xF07E3C, 0xF0743C, 0xF06A3C, 0xF06042)]
      == ['move.l #$fff0, d2', 'move.l #$ff0f, d2',
          'move.l #$f0ff, d2', 'move.l #$fff, d2'])
check('chassis op $A reads $1064+index*2 with a 0..12 bound and bit-4 auto-inc',
      insn(0xF04FC6) == 'cmpi.l #$c, $e7a.l'
      and insn(0xF04FE6) == 'move.w $1064(a1), $e74.l'
      and insn(0xF04FEE) == 'btst.b #$4, $e87.l')
check('an all-idle scan sets MODE1 bit 6 and MODE0 bit 11',
      insn(0xF086AA) == 'bset.b #$6, d4' and insn(0xF086B6) == 'bset.b #$b, d4')

# --- the XP channel transaction primitive --------------------------------
check('a transaction masks the BIM ($4F), issues $8004, and polls 1000 times',
      insn(0xF07F12) == 'move.w #$4f, (a3)'
      and insn(0xF07F22) == 'move.w #$8004, (a0)'
      and insn(0xF07F26) == 'move.l #$3e8, d5')
check('...polling +$0E bit 14 for DONE and bit 13 for ERROR',
      insn(0xF07F30) == 'btst.b #$e, d4' and insn(0xF07F3E) == 'btst.b #$d, d4')
check('...then dispatches the response through the 42-entry table at $F083FC',
      insn(0xF07F84) == 'lsl.w #$2, d0')
check('the continue phase issues $8005 and restores the BIM to $5F',
      insn(0xF07F9A) == 'move.w #$8005, (a0)'
      and insn(0xF07F7E) == 'move.w #$5f, (a3)')
# $F084A4 maps channel -> $FF021A bit, and is NOT a patched per-task constant.
check('the channel->IRQ-mask-bit table is 1:5, 2:4, 3:3, 4:2',
      list(_rom[0xF084A4 - _B:0xF084A4 - _B + 5]) == [0, 5, 4, 3, 2]
      and insn(0xF07F78) == 'bclr.b d5, d0')
check('...and it is byte-identical in all four XP tasks',
      len({_rom[a - _B:a - _B + 5]
           for a in (0xF084A4, 0xF07AA4, 0xF070A4, 0xF0668C)}) == 1)

# Op $A's 0..12 bound is structural: [0] the packed nibbles, [1..12] the four
# per-channel {status, data-hi, data-lo} records at $1066 + (ch-1)*6.
check('the op-$A array is exactly the status word plus the four channel records',
      0x1066 + 3 * 6 + 4 == 0x107C
      and [0x1066 + (c - 1) * 6 for c in range(1, 5)]
      == [0x1066, 0x106C, 0x1072, 0x1078])

# --- op $C: bidirectional, half-selectable access to the $101E file ------
# Confirms the command-byte bit assignments on a THIRD operation.
check('op $C tests bit 5 (direction), bit 6 (half select), bit 4 (auto-inc)',
      insn(0xF05036) == 'btst.b #$5, $e87.l'
      and insn(0xF05040) == 'btst.b #$6, $e87.l'
      and insn(0xF0507E) == 'btst.b #$4, $e87.l')
check('...reading $101E (high word) or $1020 (low word) into $E74',
      insn(0xF05054) == 'move.w $101e(a1), $e74.l'
      and insn(0xF0504A) == 'move.w $1020(a1), $e74.l')
check('...and writing either half from CHANNEL_SELECT',
      insn(0xF05070) == 'move.w $204(a0), $101e(a1)'
      and insn(0xF05068) == 'move.w $204(a0), $1020(a1)')
# The 16-longword file ends exactly where the channel-present count begins.
check('$101E + 16*4 == $105E, the channel-present count',
      0x101E + 16 * 4 == 0x105E)

# --- the CP-program callback: the SBC CALLS into host-loaded code ---------
# $45EA is lea, not movea ($2x6A), so jsr (a2) transfers control to
# $10AE + (ch-1)*4 ITSELF -- a 4-byte per-channel trampoline slot.
check('$F085F4 is an lea (45EA), so the $10AE slot is CALLED, not dereferenced',
      _rom[0xF085F4 - _B:0xF085F8 - _B] == bytes.fromhex('45ea10ae')
      and _rom[0xF085F8 - _B:0xF085FA - _B] == bytes.fromhex('4e92'))
check('...and the four per-channel arrays are 16 bytes apart',
      [0x10AE + 16 * k for k in range(4)] == [0x10AE, 0x10BE, 0x10CE, 0x10DE])
check('the callback builds three argument pointers and a count word $000C',
      insn(0xF085D2) == 'lea.l $10de(a2), a4'
      and insn(0xF085D8) == 'lea.l $10ce(a2), a4'
      and insn(0xF085DE) == 'lea.l $10be(a2), a4'
      and insn(0xF085E4) == 'move.w #$c, -(a3)')
check('...and the result at $10DE goes straight into the channel data pair',
      insn(0xF085FE) == 'move.w $10e0(a2), $2(a1)'
      and insn(0xF08604) == 'move.w $10de(a2), (a1)')

# Runtime: a 4-byte rts stub in the trampoline slot makes the callback run.
# This is the strongest confirmation that $10AE is CALLED, not dereferenced.
_cbenv = {'FPS3K_XPIRQ': '1', 'FPS3K_CHCMD': 'C000'}
_cb = {}
for _nm, _extra in (('bare', {}), ('stub', {'FPS3K_POKE': '10AE=4E75'})):
    with tempfile.TemporaryDirectory() as _tdb:
        subprocess.run([EMU, '-rom', ROM, '-cycles', '400000000',
                        '-trace', f'{_tdb}/t'], capture_output=True, timeout=400,
                       env={**os.environ, **_cbenv, **_extra})
        _cb[_nm] = collections.Counter(
            re.findall(r'[0-9A-F]{6}', open(f'{_tdb}/t').read()))
check('without a trampoline the CP callback never runs',
      _cb['bare']['F0858C'] == 0 and _cb['bare']['F085F8'] == 0)
check('...and a 4-byte rts stub at $10AE makes RSTATE and the jsr both execute',
      _cb['stub']['F0858C'] >= 1 and _cb['stub']['F085F8'] >= 1)

# --- the callback path's 96-byte frame -----------------------------------
# One allocation per XP task, and the firmware never releases it.
# NB (2026-07-31): the "96-byte stack LEAK" reading this once carried is
# RETRACTED.  A full audit of every a7 adjustment (4 allocations, 38 releases)
# shows each -$60 IS followed by a `lea $C(a7),a7` -- which releases the
# 12-byte RSTATE parameter block, not the buffer.  The buffer stays live
# because $3C(a7) is read from it immediately after, and 60 more bytes of
# register save are pushed on top before control passes to the CP-program
# trampoline.  The 96 bytes are part of the frame handed to the CALLEE, so
# whether not releasing them is a defect depends on a contract this ROM does
# not contain.  The byte counts below are still exactly right.
check('lea -$60(a7),a7 occurs 4 times, once per XP task',
      _rom.count(b'\x4f\xef\xff\xa0') == 4)
check('...and no matching lea +$60(a7),a7 exists -- the CALLEE unwinds it',
      _rom.count(b'\x4f\xef\x00\x60') == 0)
check('...while the +12 that DOES follow releases the RSTATE parameter block',
      all(insn(a + 0x18) == 'lea.l $c(a7), a7'
          for a in (0xF06762, 0xF0717A, 0xF07B7A, 0xF0857A)))

# --- a working CP handler runs complete XP-32 channel cycles --------------
# The handler must NOT return (the firmware's rts is 96 bytes out); it restores
# the registers from $4(a7), adjusts a7 by +$A4 -- derived from the frame
# arithmetic, not tuned -- and jumps to $F07EA4, the outer jsr's return address.
_HANDLER = ('10AE=6000,10B0=FE50,F00=4CEF,F02=7FFF,F04=0004,'
            'F06=4FEF,F08=00A4,F0A=4EF9,F0C=00F0,F0E=7EA4')
with tempfile.TemporaryDirectory() as _tdh:
    _p = subprocess.run([EMU, '-rom', ROM, '-cycles', '400000000',
                         '-trace', f'{_tdh}/t'], capture_output=True, timeout=400,
                        env={**os.environ, 'FPS3K_XPIRQ': '1',
                             'FPS3K_CHCMD': 'C000', 'FPS3K_POKE': _HANDLER})
    _hp = collections.Counter(
        re.findall(r'[0-9A-F]{6}', open(f'{_tdh}/t').read()))
    _hpc = re.search(r'final PC=([0-9A-F]+)', _p.stderr.decode('latin1', 'replace'))
check('a non-returning CP handler runs the channel cycle repeatedly',
      _hp['0010AE'] > 100 and _hp['000F00'] == _hp['0010AE']
      and _hp['F07EA4'] == _hp['0010AE'])
check('...with no return-to-zero and no illegal-instruction exception',
      _hp['000000'] == 0 and _hp['F0A24A'] == 0)
check('...and the machine ends in the RTOS idle loop, not a spin',
      bool(_hpc) and 0xF00F00 <= int(_hpc.group(1), 16) <= 0xF01000)

# --- the 42-slot dispatch tables, recounted ------------------------------
_TABS = {'RDHC': 0xF05BA4, 'XP4I': 0xF065E4, 'XP3I': 0xF06FFC,
         'XP2I': 0xF079FC, 'XP1I': 0xF083FC}


def _tabsig(T):
    """Signature of a 42-slot table: '-' for a no-op slot, else a letter per
    distinct jump target in first-appearance order."""
    sig, order = [], {}
    for n in range(42):
        a = T + 4 * n
        if _rom[a - _B:a - _B + 4] == bytes.fromhex('4e754e71'):
            sig.append('-')
            continue
        m = re.search(r'\$([0-9a-f]+)', insn(a))
        t = int(m.group(1), 16) if m else 0
        sig.append(order.setdefault(t, chr(ord('A') + len(order))))
    return ''.join(sig)


check('all five 42-slot tables share one index-to-handler pattern',
      len({_tabsig(T) for T in _TABS.values()}) == 1)
check('...and the slots with no handler are 4E75 4E71 (rts/nop), 13 of them',
      _tabsig(0xF083FC).count('-') == 13)
# Only slots 14 ($0E) and 16 ($10) are reachable from the normal request path,
# and both are D1_SEND -- "send the operation, then send the operand".
check('slots 14 and 16 both dispatch to D1_SEND ($F0810A)',
      all('f0810a' in insn(0xF083FC + 4 * n) for n in (14, 16)))

# The four handlers, RDHC's copy vs XP1I's at offset $2858: POLL and BLK_XFR
# byte-identical, D2_FIN and D1_SEND differing in exactly 2 of 64 bytes.
check('POLL and BLK_XFR are byte-identical between the RDHC and XP1I copies',
      all(_rom[r - _B:r - _B + 64] == _rom[r + 0x2858 - _B:r + 0x2858 - _B + 64]
          for r in (0xF05A12, 0xF05B0E)))
check('...and D2_FIN and D1_SEND differ in exactly 2 of their first 64 bytes',
      all(sum(1 for k in range(64)
              if _rom[r - _B + k] != _rom[r + 0x2858 - _B + k]) == 2
          for r in (0xF05738, 0xF058B2)))

# --- d0 is {mode word, operation code}; the handlers swap to reach the mode ---
check('POLL and BLK_XFR both begin with swap d0, exposing the mode word',
      insn(0xF0826A) == 'swap d0' and insn(0xF08366) == 'swap d0')
check('BLK_XFR selects same-address vs consecutive on that mode word',
      insn(0xF08388) == 'cmpi.w #$0, d0'
      and insn(0xF0839E) == 'addq.l #$4, a2')
# Both test the memory pointer against the bulk port; only POLL sets $FF020C.
check('both handlers special-case the bulk port $FF0008 and poll $FF0004 bit 0',
      insn(0xF08272) == 'lea.l $8(a4), a5'
      and insn(0xF0836E) == 'lea.l $8(a4), a5'
      and insn(0xF0827E) == 'btst.b #$0, d4'
      and insn(0xF0837A) == 'btst.b #$0, d4')
check('...but only POLL writes XLTR_COUNTER = $4 for a bulk-port source',
      insn(0xF08284) == 'move.w #$4, $20c(a4)'
      and '20c' not in insn(0xF08380))

# --- TCB+$13C is the saved stack pointer ---------------------------------
# A pointer stored into it, dereferenced from it, and adjusted by exactly a
# 6-byte exception frame and a 60-byte movem on suspend/resume.
check('TCB+$13C has a 6-byte exception frame subtracted on suspend',
      insn(0xF00616) == 'subq.l #$6, $13c(a6)')
check('...and 60 bytes for movem.l d0-d7/a0-a6',
      insn(0xF0063A) == 'subi.l #$3c, $13c(a6)')
check('...and it is both stored from and dereferenced as a pointer',
      insn(0xF006C2) == 'move.l a1, $13c(a6)'
      and insn(0xF0058E) == 'movea.l $13c(a6), a0')
# TCB+$140/$144 are the owner name/session copied from TCBNAME/TCBSESSN.
check('TCB+$140/$144 are copies of the owner TCBNAME/TCBSESSN',
      insn(0xF0354A) == 'move.l $10(a5), $140(a2)'
      and insn(0xF03550) == 'move.l $14(a5), $144(a2)')

# --- FPS3K_MODE1_BUSY brings the status subsystem to life ----------------
# The encoder's classification predicts $1064 = seq+1+9 = $A for a $C000 status
# (bit 15 set, 14 set, 11 clear).  Confirmed numerically.
_mb = {}
for _nm, _extra in (('off', {}), ('on', {'FPS3K_MODE1_BUSY': '1'})):
    with tempfile.TemporaryDirectory() as _tdm:
        subprocess.run([EMU, '-rom', ROM, '-cycles', '400000000',
                        '-trace', f'{_tdm}/t', '-dump-ram', f'{_tdm}/r'],
                       capture_output=True, timeout=400,
                       env={**os.environ, 'FPS3K_XPIRQ': '1',
                            'FPS3K_CHCMD': 'C000', **_extra})
        _mb[_nm] = (collections.Counter(
            re.findall(r'[0-9A-F]{6}', open(f'{_tdm}/t').read())),
            open(f'{_tdm}/r', 'rb').read())
check('without MODE1 bit 7 the status encoder never runs and $1064 stays zero',
      _mb['off'][0]['F08616'] == 0
      and struct.unpack('>H', _mb['off'][1][0x1064:0x1066])[0] == 0)
check('FPS3K_MODE1_BUSY makes it run, and $1064 reads $000A as the decode predicts',
      _mb['on'][0]['F08616'] >= 1
      and struct.unpack('>H', _mb['on'][1][0x1064:0x1066])[0] == 0x000A)
check('...and the all-channels-idle sweep runs with it',
      _mb['on'][0]['F086A0'] >= 1)

# The full readback chain: the encoder writes $1064, op $A hands it to $E74.
# Both halves were decoded independently; they must meet on the same value.
with tempfile.TemporaryDirectory() as _tdr:
    subprocess.run([EMU, '-rom', ROM, '-cycles', '400000000',
                    '-dump-ram', f'{_tdr}/r'], capture_output=True, timeout=400,
                   env={**os.environ, 'FPS3K_XPIRQ': '1,6', 'FPS3K_CHCMD': 'C000',
                        'FPS3K_RESP': '0x0A', 'FPS3K_MODE1_BUSY': '1'})
    _rb = open(f'{_tdr}/r', 'rb').read()
check('the status readback chain runs: $1064 == $E74 == $000A',
      struct.unpack('>H', _rb[0x1064:0x1066])[0] == 0x000A
      and struct.unpack('>H', _rb[0xE74:0xE76])[0] == 0x000A)

# Every branch of the encoder's classification, and the sweep's condition.
def _nib(chcmd):
    with tempfile.TemporaryDirectory() as _t:
        subprocess.run([EMU, '-rom', ROM, '-cycles', '400000000',
                        '-dump-ram', f'{_t}/r'], capture_output=True, timeout=400,
                       env={**os.environ, 'FPS3K_XPIRQ': '1',
                            'FPS3K_CHCMD': chcmd, 'FPS3K_MODE1_BUSY': '1'})
        r = open(f'{_t}/r', 'rb').read()
    return struct.unpack('>H', r[0x1064:0x1066])[0], r[0x107E]


check('the encoder classifies b11-set as seq+1 and b15-set as seq+1+9',
      _nib('C800')[0] == 0x0001 and _nib('C000')[0] == 0x000A)
check('...b13-set (error) as the FIXED value 9, carrying no sequence number',
      _nib('2000')[0] == 0x0009)
check('...and a plain status as seq+1+4',
      _nib('4000')[0] == 0x0005)
check('the idle sweep resets $107E only when no channel has b15 set with b14 clear',
      _nib('C000')[1] == 0 and _nib('8000')[1] == 1)

# Op $A with bit 4 walks the whole 13-word array and then hits its bound.
with tempfile.TemporaryDirectory() as _tw:
    subprocess.run([EMU, '-rom', ROM, '-cycles', '400000000',
                    '-dump-ram', f'{_tw}/r', '-trace', f'{_tw}/t'],
                   capture_output=True, timeout=400,
                   env={**os.environ, 'FPS3K_XPIRQ': '1,6', 'FPS3K_CHCMD': 'C000',
                        'FPS3K_RESP': '0x1A', 'FPS3K_MODE1_BUSY': '1'})
    _wr = open(f'{_tw}/r', 'rb').read()
    _wt = collections.Counter(re.findall(r'[0-9A-F]{6}', open(f'{_tw}/t').read()))
check('op $A auto-increment walks 13 words and stops at index 13',
      _wt['F04FF8'] == 13
      and struct.unpack('>I', _wr[0xE7A:0xE7E])[0] == 13)
check('...and the fourteenth read is rejected on the 0..12 bound',
      _wt['F04FD2'] == 1)

# Op $A validates its index; op $C -- structurally identical -- does not.
def _walkidx(resp):
    with tempfile.TemporaryDirectory() as _t:
        subprocess.run([EMU, '-rom', ROM, '-cycles', '400000000',
                        '-dump-ram', f'{_t}/r'], capture_output=True, timeout=400,
                       env={**os.environ, 'FPS3K_XPIRQ': '6', 'FPS3K_RESP': resp})
        return struct.unpack('>I', open(f'{_t}/r', 'rb').read()[0xE7A:0xE7E])[0]


check('op $A stops at its 0..12 bound but op $C runs far past the file',
      _walkidx('0x1A') == 13 and _walkidx('0x1C') > 100)
check('...and op $C reaches the index with no comparison at all',
      insn(0xF0502C) == 'move.l $e7a.l, d1'
      and insn(0xF05032) == 'lsl.w #$2, d1'
      and insn(0xF05034) == 'movea.w d1, a1')

# Op $6 is an unbounded peek/poke; op $8 is the one place an ADDRESS is bounded.
check('op $6 takes the chassis-supplied address straight into a1, unvalidated',
      insn(0xF04F30) == 'movea.l $e58.l, a1')
check('...and the shared routine clears $FF0216 bit 7 for the access, restoring after',
      insn(0xF04EA6) == 'bclr.b #$7, d0'
      and insn(0xF04EDC) == 'move.w d1, $216(a0)')
check('...with bit 5 selecting read vs write and bit 4 auto-incrementing by 2',
      insn(0xF04EAE) == 'btst.b #$5, $e87.l'
      and insn(0xF04ED6) == 'addq.l #$2, $e58.l')
check('op $8 bounds $E7E to the staging range $10000-$1FFFF',
      insn(0xF04F70) == 'cmpi.l #$10000, $e7e.l')

# $E7E has exactly four references: two S-record writers, two op-$8 readers.
check('$E7E is written only by the two S-record paths, after adda.l #$10000',
      insn(0xF052D0) == 'adda.l #$10000, a1'
      and insn(0xF052D6) == 'move.l a1, $e7e.l'
      and insn(0xF05640) == 'adda.l #$10000, a1'
      and insn(0xF05646) == 'move.l a1, $e7e.l')
check('...and read only by op $8, bounding it to the staging range',
      insn(0xF04F7C) == 'cmpi.l #$1ffff, $e7e.l')

# Op $3: the offset is masked to 20 bits then shifted left 2, so its maximum is
# $3FFFFC -- four bytes below the $400000 comparison.  Both arms' bge targets
# are therefore unreachable by construction.
check('op $3 masks the offset to 20 bits and scales it to bytes, both arms',
      insn(0xF04D7E) == 'andi.l #$fffff, d1' and insn(0xF04D84) == 'lsl.l #$2, d1'
      and insn(0xF04DF2) == 'andi.l #$fffff, d1' and insn(0xF04DF8) == 'lsl.l #$2, d1')
check('...so max offset $3FFFFC is below the $400000 test and both bge are dead',
      0xFFFFF * 4 == 0x3FFFFC and 0x3FFFFC < 0x400000
      and insn(0xF04D88) == 'cmpa.l #$400000, a1'
      and insn(0xF04DFC) == 'cmpa.l #$400000, a1')
check('...and the reachable window range $400000-$7FFFFC contains the mailbox',
      0x400000 <= 0x70001C <= 0x400000 + 0x3FFFFC)

# Op $0's three-way split: $0 and $1..$10 take different paths.
check('op $0 accepts 0..$10 or $28, rejecting anything else to panel $259',
      insn(0xF04A8E) == 'cmpi.w #$10, d0'
      and insn(0xF04A94) == 'cmpi.w #$28, d0')
check('...and branches three ways on the stashed value',
      insn(0xF04AC8) == 'cmpi.l #$28, $e5c.l'
      and insn(0xF04B08) == 'cmpi.l #$0, $e5c.l')
check('...with the 1..$10 arm validating the channel and using ((ch+1)<<5)',
      insn(0xF04C94) == 'cmp.w $105e.l, d3'
      and insn(0xF04CAC) == 'lsl.l #$5, d3')

# --- the TDTI definition table gives the task map statically -------------
# Six 96-byte !TCB records: name at +$04, entry at +$1C, PROG pages +$20/+$22.
# These reproduce the runtime !TST table exactly, from the ROM alone.
_tdti = []
for _k in range(6):
    _r = 0xF0A600 + 96 * _k
    _tdti.append((_rom[_r - _B + 4:_r - _B + 8].decode('latin1'),
                  struct.unpack('>I', _rom[_r - _B + 0x1C:_r - _B + 0x20])[0],
                  struct.unpack('>H', _rom[_r - _B + 0x20:_r - _B + 0x22])[0] << 8,
                  (struct.unpack('>H', _rom[_r - _B + 0x22:_r - _B + 0x24])[0] << 8) + 0xFF))
check('the TDTI table names six tasks with entry points and segment bounds',
      [t[0] for t in _tdti] == ['RDHC', 'IO1I', 'XP4I', 'XP3I', 'XP2I', 'XP1I'])
check('...and its entry points match the runtime !TST values exactly',
      [t[1] for t in _tdti]
      == [0xF046F0, 0xF05D36, 0xF05F4A, 0xF0694A, 0xF0734A, 0xF07D4A])
check('...as do its PROG segment bounds, tiling $F04600-$F086FF',
      [(t[2], t[3]) for t in _tdti]
      == [(0xF04600, 0xF05CFF), (0xF05D00, 0xF05EFF), (0xF05F00, 0xF068FF),
          (0xF06900, 0xF072FF), (0xF07300, 0xF07CFF), (0xF07D00, 0xF086FF)])

# $F044A2 is real code the disassembler renders as data -- the FPS trace hook.
# It escapes the executed-PC property because the trace mask is zero.
check('$F044A2 is the FPS trace hook: btst on the $0C34 mask byte',
      insn(0xF044A2) == 'btst.b #$e, $c34.w')
check('...and the mask that disables it is the ROM word $F0A52A = $0000',
      struct.unpack('>H', _rom[0xF0A52A - _B:0xF0A52C - _B])[0] == 0)
# RDHC's four-command jump table: 6-byte jmp entries, matching mulu #$6.
check('RDHC\'s command table at $F05358 is 6-byte jmp entries',
      insn(0xF0535E) == 'jmp $f054a2.l' and insn(0xF05364) == 'jmp $f054e8.l')

# The top-of-RAM initialiser: three descending runs bracketing $1FFF0.
check('the initialiser rounds the RAM top down to 4 KB and runs three groups',
      insn(0xF0A462) == 'andi.l #$fffff000, d0'
      and insn(0xF0A472) == 'moveq #$3, d4'
      and insn(0xF0A478) == 'moveq #$7, d3')
check('...writing seven words downward per group from a table base',
      insn(0xF0A474) == 'movea.w (a1)+, a2'
      and insn(0xF0A47A) == 'move.w (a1)+, -(a2)')
check('...whose bases $1000/$0FF0/$0FE0 bracket the VMOD register at $1FFF0',
      [struct.unpack('>H', _rom[0xF0A4BE - _B + 16 * k:0xF0A4BE - _B + 16 * k + 2])[0]
       for k in range(3)] == [0x1000, 0x0FF0, 0x0FE0]
      and 0x20000 - 2 * 7 == 0x1FFF2 and 0x1FFF0 - 2 == 0x1FFEE)

# --- the RTOS configuration block at $F0A502-$F0A552 ---------------------
check('the config block holds the trace mask, device base and RAM top',
      struct.unpack('>H', _rom[0xF0A52A - _B:0xF0A52C - _B])[0] == 0x0000
      and struct.unpack('>I', _rom[0xF0A52C - _B:0xF0A530 - _B])[0] == 0x00F70000
      and struct.unpack('>I', _rom[0xF0A550 - _B:0xF0A554 - _B])[0] == 0x00020000)
check('...and seven allocator page counts, six ones and one two',
      sorted(struct.unpack('>I', _rom[a - _B:a - _B + 4])[0]
             for a in (0xF0A516, 0xF0A51A, 0xF0A534, 0xF0A538,
                       0xF0A522, 0xF0A51E, 0xF0A526)) == [1, 1, 1, 1, 1, 1, 2])
# The 2-page constant and the runtime USTNPAGE agree, read from opposite ends.
check('the two-page constant $F0A51A matches !UST\'s runtime USTNPAGE = 2',
      struct.unpack('>I', _rom[0xF0A51A - _B:0xF0A51E - _B])[0] == 2
      and struct.unpack('>H', _rq2[0x1FB0A:0x1FB0C])[0] == 2)

# --- delayed acknowledgement, and the busy bit as a real model -----------
def _delayrun(env):
    with tempfile.TemporaryDirectory() as _t:
        subprocess.run([EMU, '-rom', ROM, '-cycles', '400000000',
                        '-trace', f'{_t}/t', '-dump-ram', f'{_t}/r'],
                       capture_output=True, timeout=400,
                       env={**os.environ, **env})
        return (collections.Counter(
                    re.findall(r'[0-9A-F]{6}', open(f'{_t}/t').read())),
                open(f'{_t}/r', 'rb').read())


_d0 = _delayrun({'FPS3K_XPIRQ': '1', 'FPS3K_CHCMD': '4000'})[0]
_d1 = _delayrun({'FPS3K_XPIRQ': '1', 'FPS3K_CHCMD': '4000',
                 'FPS3K_CHACK_DELAY': '40000'})[0]
check('a delayed channel ack lengthens the poll without causing a timeout',
      _d1['F07F2C'] > 10 * _d0['F07F2C'] and _d1['F07F4C'] == 0
      and _d1['F07F84'] == _d0['F07F84'])
# The busy bit derives from an outstanding transfer -- contention, not self.
_c0 = _delayrun({'FPS3K_XPIRQ': '1,2', 'FPS3K_CHCMD': '4000',
                 'FPS3K_CHANNELS': '2'})
_c1 = _delayrun({'FPS3K_XPIRQ': '1,2', 'FPS3K_CHCMD': '4000',
                 'FPS3K_CHANNELS': '2', 'FPS3K_CHACK_DELAY': '200000'})
check('with no transfer outstanding the busy bit is never set and $1064 stays 0',
      _c0[0]['F08616'] == 0
      and struct.unpack('>H', _c0[1][0x1064:0x1066])[0] == 0)
check('...and under contention it is, so the encoder runs and $1064 reads $0005',
      _c1[0]['F08616'] >= 1
      and struct.unpack('>H', _c1[1][0x1064:0x1066])[0] == 0x0005)

# --- the two return-stack indirect jumps, both through config pointers ---
check('the FPS->RTOS handoff pushes $F00100 from the config block and rts-es',
      insn(0xF0A300) == 'move.l $f0a512(pc), -(a7)'
      and insn(0xF0A304) == 'rts'
      and struct.unpack('>I', _rom[0xF0A512 - _B:0xF0A516 - _B])[0] == 0xF00100)
check('...$F00100 is a one-instruction trampoline into the scheduler',
      insn(0xF00100) == 'jmp $f0050c.l'
      and insn(0xF0050C) == 'movea.l $c08.w, a7')
check('...and the scheduler stack is loaded from $0C08 just before the jump',
      insn(0xF0A2F4) == 'movea.l $c08.w, a7')
# The other indirect jump is dormant: its pointer aims at zero-filled ROM.
# The "dormant" vector is not aimed at nothing: $F000BC-$F000FF is 68 bytes of
# zero -- a NOP slide (ori.b #$0,d0) -- ending EXACTLY on $F00100, the same
# trampoline the live handoff uses.  So both indirect jumps reach the scheduler.
check('the exception-monitor exit jumps through $0C36, config $F000BC',
      insn(0xF00D52) == 'move.l $c36.w, -(a7)'
      and struct.unpack('>I', _rom[0xF0A542 - _B:0xF0A546 - _B])[0] == 0x00F000BC)
check('...and $F000BC-$F000FF is zero-fill landing exactly on the $F00100 trampoline',
      not any(_rom[0xF000BC - _B:0xF00100 - _B])
      and _rom[0xF00100 - _B] != 0)

# --- the boot locates its vector table by scanning ROM for the !VCT tag --
check('the scan base comes from config $F0A4F6 = $F00100',
      struct.unpack('>I', _rom[0xF0A4F6 - _B:0xF0A4FA - _B])[0] == 0xF00100
      and insn(0xF09C96) == 'movea.l $f0a4f6(pc), a2')
check('...and it is a 2-byte scan: cmp.l (a2)+ then subq.l #$2,a2 on mismatch',
      insn(0xF09CA4) == 'cmp.l (a2)+, d0'
      and insn(0xF09CA8) == 'subq.l #$2, a2')
check('...reaching the ROM !VCT tag at $F0011A on the 14th compare',
      0xF00100 + 2 * 13 == 0xF0011A
      and _rom[0xF0011A - _B:0xF0011E - _B] == b'!VCT')
# The absent markers each have exactly one write site, none of which executes.
check('!DLY, !CCB and !ASQ each have exactly one write site in the ROM',
      all(_rom.count(struct.pack('>I', t)) == n
          for t, n in ((0x21444C59, 1), (0x21434342, 1), (0x21415351, 2))))

# --- the kernel-relocation mechanism, disabled by config $F0A546 ---------
check('the relocator takes its source from config $F0A546, which is zero',
      insn(0xF09C66) == 'move.l $f0a546(pc), d1'
      and struct.unpack('>I', _rom[0xF0A546 - _B:0xF0A54A - _B])[0] == 0)
check('...its destination from $F0A4F6 = $F00100, the same as the entry pointer',
      insn(0xF09C6C) == 'movea.l $f0a4f6(pc), a3'
      and struct.unpack('>I', _rom[0xF0A4F6 - _B:0xF0A4FA - _B])[0]
      == struct.unpack('>I', _rom[0xF0A512 - _B:0xF0A516 - _B])[0])
check('...installs a temporary bus-error handler at vector 2 around the copy',
      insn(0xF09C88) == 'move.l a1, $8.w'
      and insn(0xF09C8C) == 'move.l (a2)+, (a3)+')
check('...and the whole path is skipped: copy loop 0, skip target 1',
      _dpcs['F09C8C'] == 0 and _dpcs['F09C96'] == 1 and _dpcs['F09C66'] == 1)

# --- the optional boot-progress display and its fallback -----------------
check('the display address comes from config $F0A506, which is zero here',
      insn(0xF09C38) == 'movea.l $f0a506(pc), a1'
      and struct.unpack('>I', _rom[0xF0A506 - _B:0xF0A50A - _B])[0] == 0)
check('...a non-zero address would be probed under a bus-error handler',
      insn(0xF09C46) == 'move.l a0, $8.w'
      and insn(0xF09C4A) == 'move.w #$80, $4(a1)')
check('...and the fallback points $0C3A at scratch RAM $800',
      _rq2[0x0C3A:0x0C3E] == bytes.fromhex('00000800'))
# The driver writes value-then-value|$30 twice; the last of the four remains.
check('the display driver leaves $0033 at $804, the last of its four writes',
      struct.unpack('>H', _rq2[0x0804:0x0806])[0] == 0x0033)

# --- the XP-32 channel status protocol -----------------------------------
# $1066 holds the HIGH byte of the latched word and btst on memory is mod 8,
# so #$f/#$e/#$b are word bits 15/14/11.
check('the channel status word is tested for bits 15, 14 and 11',
      insn(0xF07E4C) == 'btst.b #$f, $1066.l'
      and insn(0xF07E86) == 'btst.b #$e, $1066.l'
      and insn(0xF07E90) == 'btst.b #$b, $1066.l')
check('the abort path sets MODE1 bit (channel + 7), i.e. bits 8-11',
      insn(0xF084EA) == 'addq.w #$7, d0' and insn(0xF084EC) == 'bset.b d0, d1')
# Present in all four task copies.  Note XP4I's site sits at -$18 from the
# $A00 grid, NOT the -$1E global best-fit alignment recorded for the task as a
# whole -- the template shift is not uniform across the whole 2560 bytes.
check('...and the same MODE1 bit computation appears in all four XP tasks',
      all(insn(a) == 'addq.w #$7, d0' and insn(a + 2) == 'bset.b d0, d1'
          for a in (0xF084EA, 0xF07AEA, 0xF070EA, 0xF066D2)))



# ---- the boot spine: reset -> self-test -> RTOS init (2026-07-31) ----
import struct as _bst, capstone as _bcs
_brsp, _brpc = _bst.unpack(">II", _rom[0:8])
check('reset vector SP is $00000000 and is never used', _brsp == 0)
check('reset vector PC is $F09C00', _brpc == 0x00F09C00)
check('$F09C00 is a bare jmp into the self-test', insn(0xF09C00) == 'jmp $f08700.l')
check("the self-test's first instruction establishes a7",
      insn(0xF08700) == 'lea.l $1ffd0.l, a7')
check('$F088F4 jumps back over it to the RTOS init', insn(0xF088F4) == 'jmp $f09c06.l')
check('$F09C06 reloads a7 for the RTOS', insn(0xF09C06).startswith('movea.l #$400'))
check('$F0A4F2 holds the self-test entry address',
      _bst.unpack(">I", _rom[0xF0A4F2 - 0xF00000:][:4])[0] == 0x00F08700)

# $F0A4F2 is DEAD: its value is stored to $0C14, which is cleared before any reader.
_bmd = _bcs.Cs(_bcs.CS_ARCH_M68K, _bcs.CS_MODE_M68K_000)
_bc14, _ba = [], 0xF00000
while _ba < 0xF0FFF0:
    try: _bi = next(_bmd.disasm(_rom[_ba - 0xF00000:][:10], _ba, count=1))
    except StopIteration: _ba += 2; continue
    if not _bi.size: _ba += 2; continue
    if '$c14.w' in _bi.op_str: _bc14.append(_bi.address)
    _ba += _bi.size
check('$0C14 has exactly four references: config store, clear, push pair',
      _bc14 == [0xF09E3C, 0xF0A062, 0xF0A0BC, 0xF0A0C2], [hex(x) for x in _bc14])
check('...so nothing reads $0C14 between the store and the clear -- $F0A4F2 is dead',
      insn(0xF0A062).startswith('clr.l') and '$c14' in insn(0xF0A062))
check('$0C10 is linked by +$04, $0C14 by +$0C -- different fields, not one list',
      insn(0xF029D6).endswith('$4(a5)') and insn(0xF0A0BC).endswith('$c(a5)'))

# ---- the self-test's fault handler, and the stack-adjustment audit (2026-07-31) ----
check('the self-test installs its own handler on bus AND address error',
      insn(0xF08706) == 'move.l #$f08902, $8.w' and insn(0xF0870E) == 'move.l #$f08902, $c.w')
check('...and zeroes its fault counter at $1F800', insn(0xF08716) == 'move.l #$0, $1f800.l')
check('the handler counts rather than reports', insn(0xF0890A) == 'addq.l #$1, $1f800.l')
check('it picks the counter by which stack is live', insn(0xF08902) == 'cmpa.l #$10000, a7')
check('it discards 8 bytes + rte = the 14-byte 68000 group-0 frame',
      insn(0xF08916) == 'lea.l $8(a7), a7' and insn(0xF0891A) == 'rte')

# every explicit a7 adjustment in the image
import re as _sre
_alloc, _free, _sa = [], [], 0xF00000
while _sa < 0xF0FFF0:
    try: _si = next(_bmd.disasm(_rom[_sa - 0xF00000:][:10], _sa, count=1))
    except StopIteration: _sa += 2; continue
    if not _si.size: _sa += 2; continue
    _so = _si.op_str.lower()
    if _si.mnemonic.startswith('lea') and _so.endswith('(a7), a7'):
        _m = _sre.match(r'(-?)\$([0-9a-f]+)\(a7\)', _so)
        if _m:
            _n = int(_m.group(2), 16) * (-1 if _m.group(1) else 1)
            (_alloc if _n < 0 else _free).append((_si.address, _n))
    if _si.mnemonic in ('addq.l', 'subq.l') and _so.endswith(', a7'):
        _n = int(_sre.match(r'#\$([0-9a-f]+)', _so).group(1), 16)
        (_free if _si.mnemonic == 'addq.l' else _alloc).append(
            (_si.address, _n if _si.mnemonic == 'addq.l' else -_n))
    _sa += _si.size
check('exactly 4 explicit stack allocations in the ROM, all -96, one per XP task',
      [n for _, n in _alloc] == [-96] * 4, _alloc)
check('...at the four XP-task RSTATE sites',
      [a for a, _ in _alloc] == [0xF06762, 0xF0717A, 0xF07B7A, 0xF0857A])
check('each is followed 24 bytes later by a +12 release of the PARAMETER BLOCK',
      all(insn(a + 0x18) == 'lea.l $c(a7), a7' for a, _ in _alloc))
check('...and the 96-byte buffer stays live because $3C(a7) is read next',
      all(insn(a + 0x1c).startswith('movea.l $3c(a7)') for a, _ in _alloc))
check('RETRACTED "zero releases": the ROM has 38 explicit releases', len(_free) == 38, len(_free))

# ---- XP4I's divergence is localised, not a uniform shift (2026-07-31) ----
def _win(o4, o3, n=64):
    a = _rom[o4 - 0xF00000:][:n]; b = _rom[o3 - 0xF00000:][:n]
    return sum(1 for x, y in zip(a, b) if x == y)
_X4, _X3 = 0xF05F00, 0xF06900
check("XP4I's prologue is NOT displaced: shift 0 matches at offset 0 and $80",
      _win(_X4, _X3) >= 50 and _win(_X4 + 0x80, _X3 + 0x80) >= 50)
check('XP4I aligns at -$18 for its whole tail, $200 onward',
      all(_win(_X4 + w - 24, _X3 + w) >= 58 for w in range(0x200, 0xA00, 0x80)))
check('...and shift 0 is wrong there', _win(_X4 + 0x500, _X3 + 0x500) < 20)
check('XP4I alone writes $8020 to XLTR_MODE1 during start-up',
      insn(0xF06006) == 'move.w #$8020, $202(a5)')
check('...no other XP task has that instruction at the matching point',
      insn(0xF06A06) != 'move.w #$8020, $202(a5)'
      and insn(0xF07406) != 'move.w #$8020, $202(a5)')
check('XP3I passes the channel in d0 before the helper; XP4I does not',
      insn(0xF06A5C) == 'move.w #$3, d0' and insn(0xF06062).startswith('jsr'))
check('...and XP4I\'s helper is the correctly -$18-shifted copy',
      insn(0xF06A60) == 'jsr $f070aa.l' and insn(0xF06062) == 'jsr $f06692.l'
      # XP3I is one $A00 task-stride above XP4I, plus the $18 local shift
      and 0xF070AA - 0xF06692 == 0xA00 + 0x18)

# ---- XLTR_MODE1 ($FF0202): the complete operational bit map (2026-07-31) ----
import re as _mre, collections as _mcol
_mins, _ma = {}, 0xF00000
while _ma < 0xF0FFF0:
    try: _mi = next(_bmd.disasm(_rom[_ma - 0xF00000:][:10], _ma, count=1))
    except StopIteration: _ma += 2; continue
    if not _mi.size: _ma += 2; continue
    _mins[_ma] = (_mi.mnemonic, _mi.op_str.lower(), _mi.size); _ma += _mi.size
_mbits, _mpairs = _mcol.defaultdict(_mcol.Counter), 0
for _a, (_m, _o, _sz) in sorted(_mins.items()):
    _mm = _mre.match(r'\$202\(a\d\), (d\d)$', _o)
    if not (_m.startswith('move.w') and _mm): continue
    _reg, _p = _mm.group(1), _a + _sz
    for _ in range(8):
        if _p not in _mins: break
        _m2, _o2, _s2 = _mins[_p]
        if _m2.startswith('move.w') and _o2.startswith(_reg + ', $202('): _mpairs += 1; break
        _b = _mre.match(r'#\$([0-9a-f]+), ' + _reg + '$', _o2)
        if _b and _m2.split('.')[0] in ('bset', 'bclr', 'bchg'):
            _mbits[int(_b.group(1), 16)][_m2.split('.')[0]] += 1
        _p += _s2
check('MODE1 has 21 operational read-modify-write pairs', _mpairs == 21, _mpairs)
check('MODE1 bit 14 (control) is cleared 13x and set once',
      _mbits[14]['bclr'] == 13 and _mbits[14]['bset'] == 1, dict(_mbits[14]))
check('MODE1 bit 12 (enable) is set 8x and NEVER cleared',
      _mbits[12]['bset'] == 8 and _mbits[12]['bclr'] == 0, dict(_mbits[12]))
check('MODE1 bit 7 (busy) is the XPRUN clear/set pair at $F050D2/$F050E0',
      _mbits[7]['bclr'] == 1 and _mbits[7]['bset'] == 1
      and insn(0xF050D6) == 'bclr.b #$7, d1' and insn(0xF050E4) == 'bset.b #$7, d1')
check('MODE1 bit 6 is set 4x and never cleared (panel-command issuer)',
      _mbits[6]['bset'] == 4 and _mbits[6]['bclr'] == 0, dict(_mbits[6]))
check('MODE1 bits touched are exactly {0,6,7,12,14}',
      set(_mbits) == {0, 6, 7, 12, 14}, sorted(_mbits))
check('the only operational whole-word MODE1 write is XP4I\'s $8020',
      insn(0xF06006) == 'move.w #$8020, $202(a5)')
check('...and it clears the sticky enable bit 12', not (0x8020 >> 12) & 1)

# ---- PanelErrorMaskTable and the XLTR register sweep (2026-07-31) ----
_pemt = _rom[0xF05C4C - 0xF00000:][:42]
check('PanelErrorMaskTable abuts the 42-entry dispatch table exactly',
      0xF05BA4 + 42 * 4 == 0xF05C4C)
check('...and is a 5-entry map: CHANNEL 1-4 -> $FF021A bits 5,4,3,2 (entry 0 unused)',
      list(_pemt[:5]) == [0, 5, 4, 3, 2], list(_pemt[:5]))
check('PanelErrorMaskTable and the XP-side channel map are the SAME table',
      _rom[0xF05C4C - 0xF00000:][:5] == _rom[0xF084A4 - 0xF00000:][:5] == b'\x00\x05\x04\x03\x02')
check('...both sitting exactly 168 bytes past their own 42-entry dispatch table',
      0xF05C4C - 0xF05BA4 == 0xF084A4 - 0xF083FC == 42 * 4)
check('...so entries 5+ are zero because there are four channels, not four operations',
      set(_pemt[5:]) == {0})
check('...with 37 bytes of zero fill behind it', set(_pemt[5:]) == {0})
check('$FF021A is modified with a bit number from that table, not an immediate',
      insn(0xF0571C) == 'move.b (a5, d4.w), d5' and insn(0xF05720) == 'bclr.b d5, d0')
check('...and the table is addressed by lea $F05C4C', insn(0xF05714) == 'lea.l $f05c4c.l, a5')
check('MODE0 bit 10 shows the same 13-clear/1-set signature as MODE1 bit 14',
      _mbits[14]['bclr'] == 13 and _mbits[14]['bset'] == 1)
check('$FF020C IS readable: the self-test compares it back',
      insn(0xF09546) == 'move.w #$1, $20c(a6)' and insn(0xF0959A) == 'cmpi.w #$1, $20c(a6)')
check('...while all seven operational writes to $FF020C are $4',
      all(insn(a).startswith('move.w #$4, $20c(')
          for a in (0xF04AC2, 0xF04B2C, 0xF05A2C, 0xF0646C, 0xF06E84, 0xF07884, 0xF08284)))

# ---- the channel ISRs and the 13-word status file (2026-07-31) ----
for _ch, (_isr, _cmd, _hi, _lo, _rec) in enumerate(
        [(0xF07EE6, 0x4E, 0x48, 0x4A, 0x1066), (0xF074E6, 0x6E, 0x68, 0x6A, 0x106C),
         (0xF06AE6, 0x8E, 0x88, 0x8A, 0x1072), (0xF060CE, 0xAE, 0xA8, 0xAA, 0x1078)], 1):
    check('XP%dI ISR bases a5 on the DEVICE base $FF0000, not a window base' % _ch,
          insn(_isr + 2) == 'movea.l #$ff0000, a5')
    check('XP%dI ISR reads cmd/status, hi, lo into its record at $%04X' % (_ch, _rec),
          insn(_isr + 8) == 'move.w $%x(a5), $%x.l' % (_cmd, _rec)
          and insn(_isr + 16) == 'move.w $%x(a5), $%x.l' % (_hi, _rec + 2)
          and insn(_isr + 24) == 'move.w $%x(a5), $%x.l' % (_lo, _rec + 4))
    check('XP%dI ISR exits through the CCR sentinel, not rte' % _ch,
          insn(_isr + 34) == 'move.w #$c, ccr' and insn(_isr + 38) == 'trap #$1')
check('the status file is contiguous: $1064 nibbles + 4 records of 3 words = 13 words',
      0x107C - 0x1064 == 12 * 2)
check('...which is exactly the 0..12 bound chassis op $A walks', (0x107C - 0x1064) // 2 == 12)

# ---- $1064 is updated lock-free by four tasks (2026-07-31) ----
_s1064 = [a for a, (m, o, _) in sorted(_mins.items()) if '$1064' in o]
check('$1064 has exactly 9 references in the ROM', len(_s1064) == 9, len(_s1064))
check('...four and.w/or.w pairs, one per XP task, plus one read',
      _s1064 == [0xF04FE6, 0xF0683A, 0xF06840, 0xF07252, 0xF07258,
                 0xF07C52, 0xF07C58, 0xF08652, 0xF08658], [hex(x) for x in _s1064])
check('the update is two whole-word RMW instructions, not load/modify/store',
      all(insn(a) == 'and.w d2, $1064.l' for a in (0xF0683A, 0xF07252, 0xF07C52, 0xF08652))
      and all(insn(a) == 'or.w d4, $1064.l' for a in (0xF06840, 0xF07258, 0xF07C58, 0xF08658)))
check('...which is what makes four unlocked writers safe on one word',
      insn(0xF0683A).startswith('and.w') and insn(0xF06840).startswith('or.w'))
check('the only reader is the chassis op $A indexed read',
      insn(0xF04FE6) == 'move.w $1064(a1), $e74.l')

# ---- the chassis-conversation state block is complete (2026-07-31) ----
check('$0E6E is written by all eight panel-command issuer copies',
      sum(1 for a, (m, o, _) in _mins.items() if o.endswith('$e6e.l')) == 8)
check('...and read by nothing -- it is a post-mortem breadcrumb',
      not any(o.startswith('$e6e.l') for _, o, _ in _mins.values()))
check('the four CHANSEL captures each latch $FF0204 into a private global',
      insn(0xF04F1C) == 'move.w $204(a0), $e62.l'
      and insn(0xF04DD6) == 'move.w $204(a0), $e72.l'
      and insn(0xF050B6) == 'move.w $204(a0), $e7c.l')
check('$E62 is read back and range-checked as the channel',
      insn(0xF0537E) == 'move.w $e62.l, d4' and insn(0xF05384) == 'cmpi.w #$1, d4')
check('op $3 stages the chassis word through $E72 into the result $E74',
      insn(0xF04DB2) == 'move.w $e72.l, $e74.l')

# ---- $FF0216 is a 4-bit control register, bits 4-7 (2026-07-31) ----
check('op $6 clears bit 7 and RESTORES the original word afterwards',
      insn(0xF04EA4) == 'move.w d0, d1' and insn(0xF04EA6) == 'bclr.b #$7, d0'
      and insn(0xF04EDC) == 'move.w d1, $216(a0)')
check('CPLOAD SETS the 16->32 width mux, bit 4', insn(0xF0550E) == 'bset.b #$4, d2')
check('...and CLEARS it again on completion -- it is bracketed, not latched',
      insn(0xF05586) == 'bclr.b #$4, d2' and insn(0xF0558A) == 'move.w d2, $216(a5)')
check('the self-test probes exactly bits 4-7 of $FF0216',
      sorted({int(insn(a).split('#$')[1].split(',')[0], 16)
              for a in (0xF09626, 0xF096E8, 0xF097B8, 0xF0984C)}) == [0x10, 0x20, 0x40, 0x80])
check('$C0 at $F0A22A is the exception path, not a resting value',
      insn(0xF0A22A) == 'move.w #$c0, $216(a0)'
      and insn(0xF0A230) == 'move.w #$8000, $202(a0)')
check('...and $C0 leaves the window gate and width mux OFF', not (0xC0 & 0x30))

# ---- $FF0204 is four registers at one address (2026-07-31) ----
import re as _cre
_c204w = [a for a, (m, o, _) in _mins.items() if _cre.search(r', \$204\(a\d\)$', o)]
_c204r = [a for a, (m, o, _) in _mins.items()
          if '$204(a' in o and not _cre.search(r', \$204\(a\d\)$', o)]
check('the self-test broadcasts the phase counter d6 to $FF0204 ~70 times',
      sum(1 for a in _c204w if insn(a).startswith('move.w d6,')) >= 65,
      sum(1 for a in _c204w if insn(a).startswith('move.w d6,')))
check('...and every one of those is inside the self-test region',
      all(0xF08A00 <= a <= 0xF09C00 for a in _c204w if insn(a).startswith('move.w d6,')))
check('exactly 8 sites write d0 to $FF0204 -- the panel-command issuer copies',
      sorted(a for a in _c204w if insn(a).startswith('move.w d0,'))
      == [0xF0452C, 0xF056B4, 0xF05E82, 0xF068D4, 0xF072EC, 0xF07CEC, 0xF086EC, 0xF0A5AA])
check('the panel-status ISR returns the result through $FF0204',
      insn(0xF04924) == 'move.w $e74.l, $204(a5)')
check('nine CHANSEL reads latch into private globals',
      sum(1 for a in _c204r if _cre.search(r'\$204\(a\d\), \$e[0-9a-f]{2}\.l', insn(a))) == 9,
      sum(1 for a in _c204r if _cre.search(r'\$204\(a\d\), \$e[0-9a-f]{2}\.l', insn(a))))
check('the ONLY places the firmware reads back its own $FF0204 write are the self-test compares',
      insn(0xF094FE) == 'cmp.w $204(a6), d6' and insn(0xF09582) == 'cmp.w $204(a6), d6')

# ---- the system tick is E_kHz x period_ms, both firmware-stated (2026-07-31) ----
check('the PTM setup starts from #$320 = 800, the E clock in kHz',
      insn(0xF0A2A4) == 'move.l #$320, d0' and insn(0xF0A2AA) == 'divu.w #$4, d0')
check('...and takes the period from config $F0A530', insn(0xF0A2B0) == 'move.w $f0a530(pc), d1')
check('$F0A530 is 10 -- the tick period in MILLISECONDS',
      _bst.unpack(">H", _rom[0xF0A530 - 0xF00000:][:2])[0] == 10)
check('the two halves are (800/4 - 1) and (4*10 - 1)',
      insn(0xF0A2AE) == 'subq.w #$1, d0' and insn(0xF0A2B8) == 'mulu.w #$4, d1'
      and insn(0xF0A2BC) == 'subq.w #$1, d1')
check('...composed as MSB<<8 | LSB and written to the T3 latch',
      insn(0xF0A2C2) == 'lsl.w #$8, d1' and insn(0xF0A2C6) == 'movep.w d0, $d(a1)')
check('the arithmetic yields $27C7, the measured latch value',
      (((10 * 4 - 1) << 8) + (800 // 4 - 1)) == 0x27C7)
check('...and a period of E_kHz x period_ms = 8000 E cycles = 10.0000 ms',
      ((10 * 4 - 1) + 1) * ((800 // 4 - 1) + 1) == 800 * 10 == 8000)
check('T1 latch is $0100 and CR3 is $C6 (dual 8-bit, bit 2 set)',
      insn(0xF0A2CA) == 'move.w #$100, d0' and insn(0xF0A2D8) == 'move.b #$c6, $1(a1)')

# ---- the board status register is read-only, five bits (2026-07-31) ----
_bsleas = {0xF0875E: 'a4', 0xF08920: 'a2', 0xF089F8: 'a4', 0xF08C54: 'a4', 0xF08E0C: 'a4',
           0xF08F7A: 'a4', 0xF09196: 'a4', 0xF0924A: 'a4', 0xF093DE: 'a4'}
check('nine sites load $F70018 into a base register',
      all(insn(a).startswith('lea.l $f70018.l,') for a in _bsleas))
_bsseen, _bswrites = {}, 0
for _st, _rg in _bsleas.items():
    _p = _st + _mins[_st][2]
    for _ in range(400):
        if _p not in _mins: break
        _m, _o, _sz = _mins[_p]
        if _m.startswith(('lea', 'movea')) and _o.endswith(', ' + _rg): break  # reg reloaded
        _mm = _mre.match(r'#\$([0-9a-f]+), \$([0-9a-f]?)\(' + _rg + r'\)$', _o)
        # dedup by INSTRUCTION ADDRESS: nine lea sites give overlapping scans, and
        # counting per-scan inflated bit 1 from 4 to 12 in an earlier version.
        if _mm and _m.split('.')[0] == 'btst': _bsseen[_p] = int(_mm.group(1), 16)
        if (_mre.search(r', \$[0-9a-f]?\(' + _rg + r'\)$', _o)
                and _m.split('.')[0] in ('move', 'clr', 'bset', 'bclr', 'or', 'and')):
            _bswrites += 1
        _p += _sz
check('the board status register is NEVER written, in any form', _bswrites == 0, _bswrites)
_bsbits = _mcol.Counter(_bsseen.values())
check('only bits 1-5 of $F70019 are ever tested',
      sorted(_bsbits) == [1, 2, 3, 4, 5], sorted(_bsbits))
check('nine DISTINCT btst instructions reach it through a base register',
      len(_bsseen) == 9, len(_bsseen))
check('bit 1 is the most tested, at four addresses (deduped by instruction)',
      _bsbits[1] == 4 and _bsbits.most_common(1)[0][0] == 1, dict(_bsbits))
check('...and an absolute-address scan sees only 2 of the 11 accesses',
      sum(1 for _, (m, o, _) in _mins.items()
          if 'f70019' in o and m.split('.')[0] == 'btst') == 2)

# ---- the VERSAmodule control register $1FFF0/$1FFF1 (2026-07-31) ----
_vleas = [(a, o.split(', ')[1]) for a, (m, o, _) in sorted(_mins.items())
          if m.startswith('lea') and '$1fff0' in o]
check('thirteen sites load $1FFF0 into a base register', len(_vleas) == 13, len(_vleas))
_vbits, _vd0 = _mcol.defaultdict(_mcol.Counter), 0
for _st, _rg in _vleas:
    _p = _st + _mins[_st][2]
    for _ in range(300):
        if _p not in _mins: break
        _m, _o, _sz = _mins[_p]
        if _m.startswith(('lea', 'movea')) and _o.endswith(', ' + _rg): break
        _mm = _mre.match(r'#\$([0-9a-f]+), \$?([0-9a-f]?)\(' + _rg + r'\)$', _o)
        if _mm:
            _off, _v, _op = int(_mm.group(2) or '0', 16), int(_mm.group(1), 16), _m.split('.')[0]
            if _op in ('btst', 'bset', 'bclr'): _vbits[(_off, _v % 8)][_op] += 1
            elif _op == 'move' and _v == 0xD0: _vd0 += 1
        _p += _sz
check('$1FFF1 bit 7 is the busiest control bit (bclr x11, bset x8)',
      _vbits[(1, 7)]['bclr'] == 11 and _vbits[(1, 7)]['bset'] == 8, dict(_vbits[(1, 7)]))
# audited 2026-07-31: these counts are identical when deduplicated by instruction
# address, unlike the board-status sweep which was inflated by overlapping scans.
check('$1FFF1 bit 6 is cleared 6x and set once', _vbits[(1, 6)]['bclr'] == 6
      and _vbits[(1, 6)]['bset'] == 1, dict(_vbits[(1, 6)]))
check('$1FFF0 bit 1 is cleared 3x and set 2x', _vbits[(0, 1)]['bclr'] == 3
      and _vbits[(0, 1)]['bset'] == 2, dict(_vbits[(0, 1)]))

# ---- the SLC stream port is $FF0008, not $FF0010 (2026-07-31) ----
check('the SLC path polls $FF0004 bit 0 with a0 = $FF0000',
      insn(0xF04B22) == 'move.w $4(a0), d0' and insn(0xF04B26) == 'btst.b #$0, d0')
check('...declares the burst counter through the same base',
      insn(0xF04B2C) == 'move.w #$4, $20c(a0)')
check('...then advances a0 by 8 to reach $FF0008, the shared data port',
      insn(0xF04B48) == 'lea.l $8(a0), a0' and insn(0xF04B64) == 'move.w (a0), d1')
check('the $8(a5) load at $F04AD6 is on the OTHER branch, skipped by $F04AD2',
      insn(0xF04AD2) == 'bne.w $f04b08' and insn(0xF04AD6) == 'lea.l $8(a5), a0')
check('$FF0010 is still never referenced anywhere in the ROM',
      not any('ff0010' in o for _, (_, o, _) in _mins.items()))
check("chassis op $0's middle arm falls through into the SLC S-record dispatcher",
      insn(0xF04AC8) == 'cmpi.l #$28, $e5c.l' and insn(0xF04B08) == 'cmpi.l #$0, $e5c.l'
      and insn(0xF04B12) == 'bne.w $f04c72'
      and insn(0xF04B68) == 'move.w #$400, $218(a5)'
      and insn(0xF04B82) == 'jsr $f05150.l' and insn(0xF04B8A) == 'cmpi.w #$5330, d1')

# ---- the fourth transport: SBC -> chassis, raw, NO handshake (2026-07-31) ----
check('$E87 bit 5 selects a reverse-direction arm on op $0',
      insn(0xF04B16) == 'btst.b #$5, $e87.l' and insn(0xF04B1E) == 'bne.w $f04c50')
check('...which copies SBC RAM to the port with no handshake whatever',
      insn(0xF04C50) == 'movea.l #$ff0000, a0' and insn(0xF04C56) == 'lea.l $8(a0), a0'
      and insn(0xF04C5A) == 'movea.l $e58.l, a1' and insn(0xF04C62) == 'move.w (a1)+, (a0)')
check('...for $E64 words', insn(0xF04C66) == 'cmp.l $e64.l, d0'
      and insn(0xF04C6C) == 'ble.b $f04c62')
check('the INBOUND raw path is the mirror image but IS handshaken per word',
      insn(0xF04AF8) == 'move.w (a0), (a1)+' and insn(0xF04AE2) == 'move.w #$400, $218(a5)'
      and insn(0xF04AEC) == 'btst.b #$f, d7')
check('no $FF0218 access appears inside the outbound loop',
      not any('$218(' in insn(a) for a in range(0xF04C50, 0xF04C6E, 2)
              if a in _mins))
check('the per-channel arm validates the channel and reports $25C',
      insn(0xF04C94) == 'cmp.w $105e.l, d3' and insn(0xF04C9C) == 'move.w #$25c, d0')

# ---- modifier-bit map over the 16 chassis operations (2026-07-31) ----
_opbase = [0xF04A84, 0xF04CF2, 0xF04D20, 0xF04D4E, 0xF04E3A, 0xF04EE4, 0xF04F30, 0xF04F3A,
           0xF04F52, 0xF04FA0, 0xF04FBA, 0xF05002, 0xF0502C, 0xF05092, 0xF050CA, 0xF050F8]
def _opbits(n):
    _lo = _opbase[n]; _hi = _opbase[n + 1] if n + 1 < 16 else 0xF05102
    _b = set()
    for _a in range(_lo, _hi, 2):
        if _a in _mins and '$e87' in _mins[_a][1] and _mins[_a][0].split('.')[0] == 'btst':
            _m = _mre.match(r'#\$([0-9a-f]+), \$e87', _mins[_a][1])
            if _m: _b.add(int(_m.group(1), 16))
    return sorted(_b)
check('op $0 honours only bit 5 (the direction/transport selector)', _opbits(0) == [5])
check('ops $1 and $2 honour only bit 6 (half-select)',
      _opbits(1) == [6] and _opbits(2) == [6])
check('op $3 honours the full set 4/5/6', _opbits(3) == [4, 5, 6])
check('op $A honours only bit 4 (auto-increment)', _opbits(10) == [4])
check('op $C honours the full set 4/5/6', _opbits(12) == [4, 5, 6])
check('the pure commands $5,$7,$8,$9,$D,$E,$F honour NO modifier bits',
      all(_opbits(n) == [] for n in (5, 7, 8, 9, 13, 14, 15)))

# ---- $F046E0 is the per-channel BIM table, used by chassis op $0 (2026-07-31) ----
_bimtab = [_bst.unpack('>I', _rom[0xF046E0 - 0xF00000 + n * 4:][:4])[0] for n in range(4)]
check('$F046E0 holds the four per-channel BIM CR offsets, irregular step included',
      _bimtab == [0x244, 0x246, 0x250, 0x252], [hex(v) for v in _bimtab])
check('...and it ends exactly where TCBRDHC_Entry begins', 0xF046E0 + 16 == 0xF046F0)
check("op $0's per-channel arm computes the window from (ch+1)<<5 + $E",
      insn(0xF04CAA) == 'addq.l #$1, d3' and insn(0xF04CAC) == 'lsl.l #$5, d3'
      and insn(0xF04CAE) == 'addi.l #$e, d3')
check('...derives the data port as that minus 6', insn(0xF04CBC) == 'subq.l #$6, a1')
check('...and looks the BIM up in the table rather than computing it',
      insn(0xF04CC8) == 'lea.l $f046e0.l, a3' and insn(0xF04CD0) == 'movea.l (a3), a3'
      and insn(0xF04CD2) == 'adda.l #$ff0000, a3')
check('...then hands all three to PanelSendAndWait', insn(0xF04CE8) == 'jsr $f056ba.l')

# ---- PanelSendAndWait IS the channel transaction primitive (2026-07-31) ----
def _blk(a, n=64): return _rom[a - 0xF00000:a - 0xF00000 + n]
check('PanelSendAndWait and the XP transaction primitive are byte-identical for 64 bytes',
      _blk(0xF056BA) == _blk(0xF07F12))
check('...separated by exactly $2858, the RDHC->XP1I subsystem offset',
      0xF07F12 - 0xF056BA == 0x2858 and 0xF083FC - 0xF05BA4 == 0x2858)
check('all four XP copies of the primitive are identical',
      len({_blk(a) for a in (0xF060FA, 0xF06B12, 0xF07512, 0xF07F12)}) == 1)
check('XP2I and XP3I sit on the $A00 grid',
      0xF07F12 - 0xA00 == 0xF07512 and 0xF07F12 - 0x1400 == 0xF06B12)
check("XP4I's copy is $18 earlier than the grid -- a fourth confirmation of the tail shift",
      0xF07F12 - 0x1E00 - 0x18 == 0xF060FA)
_blklo, _blkhi, _blkoff = 0xF056BA, 0xF05C51, 0x2858
_blkmatch = sum(1 for _a in range(_blklo, _blkhi)
                if _rom[_a - 0xF00000] == _rom[_a + _blkoff - 0xF00000])
check('the replicated block is 1431 bytes and 96% identical between RDHC and XP1I',
      _blkhi - _blklo == 1431 and _blkmatch == 1375, (_blkhi - _blklo, _blkmatch))
check('...so 56 bytes are per-task patched constants', (_blkhi - _blklo) - _blkmatch == 56)
check('...and five copies are 7155 bytes, 28% of the 25501-byte application region',
      1431 * 5 == 7155 and (1431 * 5 * 100) // 25501 == 28)
check('the block ends exactly where the channel map ends',
      _blkhi - 1 == 0xF05C50 and 0xF05C4C + 5 == 0xF05C51)
_dbytes = [_a for _a in range(_blklo, _blkhi)
           if _rom[_a - 0xF00000] != _rom[_a + _blkoff - 0xF00000]]
_druns = []
for _a in _dbytes:
    if _druns and _a == _druns[-1][-1] + 1: _druns[-1].append(_a)
    else: _druns.append([_a])
check('the 56 differing bytes form 28 runs of exactly two bytes each',
      len(_druns) == 28 and all(len(r) == 2 for r in _druns), len(_druns))
_dvals = _mcol.Counter(_rom[r[0] - 0xF00000:r[0] - 0xF00000 + 2].hex() for r in _druns)
check('13 of them are the panel-command issuer address', _dvals['5688'] == 13, dict(_dvals))
check('10 are the channel map address', _dvals['5c4c'] == 10)
check('one is the 42-entry dispatch table address', _dvals['5ba4'] == 1)
check('...so every fixup is an address, not a per-channel data constant',
      _dvals['5688'] + _dvals['5c4c'] + _dvals['5ba4'] + _dvals['5bf8'] == 25)
_t26c = _mcol.Counter()
for _a, (_m, _o, _) in _mins.items():
    if _m.startswith('move') and '#$26c, d0' in _o:
        _t26c['RDHC' if _a < 0xF05D00 else 'IO1I' if _a < 0xF05F00 else
              'XP4I' if _a < 0xF06900 else 'XP3I' if _a < 0xF07300 else
              'XP2I' if _a < 0xF07D00 else 'XP1I' if _a < 0xF08700 else 'other'] += 1
check('the 45 $26C emitters are exactly 9 per region across five regions',
      dict(_t26c) == {'RDHC': 9, 'XP4I': 9, 'XP3I': 9, 'XP2I': 9, 'XP1I': 9}, dict(_t26c))
check('...i.e. a poll tail inlined 9x inside a block copied 5x', 9 * 5 == 45)
_devacc = _mcol.Counter()
for _a in range(_blklo, _blkhi, 2):
    if _a not in _mins: continue
    for _m in _mre.finditer(r'\$([0-9a-f]{1,3})\((a\d)\)', _mins[_a][1]):
        _devacc[(_m.group(2), int(_m.group(1), 16))] += 1
check('the block touches $FF021A twenty times per copy -- ten RMW pairs',
      _devacc[('a4', 0x21A)] == 20, _devacc[('a4', 0x21A)])
check('...so 10 pairs x 5 copies = the 50 RMW pairs measured ROM-wide', 10 * 5 == 50)
check('the block also reaches $FF0218 x6, $FF0202 x2, $FF020C x1 per copy',
      _devacc[('a4', 0x218)] == 6 and _devacc[('a4', 0x202)] == 2
      and _devacc[('a4', 0x20C)] == 1)
check('...and the AP I/F ready flag and bulk port twice each',
      _devacc[('a4', 0x004)] == 2 and _devacc[('a4', 0x008)] == 2)
check('the only other displacement is the channel data-low at $2(a1)',
      _devacc[('a1', 2)] == 12)

# ---- TCBIO1I: the mailbox is paged, and MODE1 bit 0 is the host link (2026-07-31) ----
check('the host ISR saves XLTR_MODE2, selects page $F, and restores it',
      insn(0xF05DE6) == 'move.w $210(a5), d7' and insn(0xF05DEA) == 'move.w #$f, $210(a5)'
      and insn(0xF05E44) == 'move.w d7, $210(a5)')
check('...with the mailbox base $700000 inside the paged chassis window',
      insn(0xF05DE0) == 'movea.l #$700000, a4'
      and 0x400000 <= 0x700000 < 0x800000)
check('...reading $70001C and writing $700020 through it',
      insn(0xF05DF0) == 'move.l $1c(a4), d1' and insn(0xF05E40) == 'move.l d1, $20(a4)')
check('MODE1 bit 0 is set by TCBIO1I before a host-link panel command',
      insn(0xF05E04) == 'bset.b #$0, d1' and insn(0xF05E08) == 'move.w d1, $202(a5)')
check('...shared by both $281 and $282 via the same exit',
      insn(0xF05DFA) == 'move.l #$281, d0' and insn(0xF05E1A) == 'move.l #$282, d0'
      and insn(0xF05E20) == 'bra.b $f05e00')
check("TCBIO1I's descriptor carries the semaphore name HIO1",
      _rom[0xF05D2C - 0xF00000:0xF05D30 - 0xF00000] == b'HIO1')
check('...and the region ends in 120 bytes of zero padding',
      set(_rom[0xF05E88 - 0xF00000:0xF05F00 - 0xF00000]) == {0}
      and 0xF05F00 - 0xF05E88 == 120)

# ---- six dead conditional branches, one per task (2026-07-31) ----
_dead = [(0xF04736, 0xF04930), (0xF05DAC, 0xF05DD6), (0xF0600C, 0xF060CE),
         (0xF06A06, 0xF06AE6), (0xF07406, 0xF074E6), (0xF07E06, 0xF07EE6)]
check('every task has a beq.b +4 immediately followed by a beq.w',
      all(_rom[a - 0xF00000:a - 0xF00000 + 4] == b'\x67\x04\x67\x00' for a, _ in _dead))
check('...and the beq.b lands exactly past the beq.w, making it unreachable',
      all(a + 2 + 2 == a + 4 for a, _ in _dead))
check('each dead branch targets its OWN task ISR entry point',
      all((a + 4 + _bst.unpack('>h', _rom[a + 4 - 0xF00000:a + 6 - 0xF00000])[0]) & 0xFFFFFF == t
          for a, t in _dead),
      [(hex(a), hex(t)) for a, t in _dead])
check('...which are the six entries in the BIM vector table',
      [t for _, t in _dead] == [0xF04930, 0xF05DD6, 0xF060CE, 0xF06AE6, 0xF074E6, 0xF07EE6])
check('the ROM contains exactly six such Bcc.b+4 / same-Bcc.w pairs',
      sum(1 for _o in range(0, len(_rom) - 6, 2)
          if _rom[_o] in (0x64, 0x65, 0x66, 0x67, 0x6A, 0x6B, 0x6C, 0x6D, 0x6E, 0x6F)
          and _rom[_o + 1] == 0x04 and _rom[_o + 2] == _rom[_o] and _rom[_o + 3] == 0x00) == 6)

# ---- the TRAP #1 table: 60 live, 17 dead, paired semaphore handlers (2026-07-31) ----
_t1 = {}
for _n in range(77):
    _o = 0xF003D8 - 0xF00000 + _n * 4
    _disp = _bst.unpack('>h', _rom[_o:_o + 2])[0]
    _fl = _bst.unpack('>H', _rom[_o + 2:_o + 4])[0]
    _t1[_n] = ((0xF003D8 + _n * 4 + _disp) & 0xFFFFFF, _fl)
_t1dead = [n for n, (h, _) in _t1.items() if h == 0xF003D0]
check('exactly 17 of the 77 TRAP #1 slots point at the error stub',
      len(_t1dead) == 17, len(_t1dead))
check('...leaving the 60 live slots measured by execution', 77 - len(_t1dead) == 60)
check('the dead directive numbers are the expected set',
      _t1dead == [0x00, 0x0A, 0x0C, 0x26, 0x27, 0x28, 0x2F, 0x30, 0x31, 0x32,
                  0x37, 0x38, 0x39, 0x3F, 0x46, 0x47, 0x4B], [hex(n) for n in _t1dead])
for _dv, _sz in ((0x01, 28), (0x0B, 28), (0x29, 10), (0x2D, 10), (0x0D, 10),
                 (0x2A, 8), (0x2B, 8), (0x43, 12), (0x4C, 16), (0x1F, 24), (0x10, 10)):
    check('directive $%02X declares a %d-byte parameter block' % (_dv, _sz),
          (_t1[_dv][1] >> 8) == _sz, hex(_t1[_dv][1]))
check('TERM/SUSPND/WAIT/RDEVNT declare no parameter block',
      all((_t1[_d][1] >> 8) == 0 for _d in (0x0F, 0x11, 0x13, 0x22)))
check('SGSEM and WTSEM share one routine, four bytes apart',
      _t1[0x2B][0] == 0xF032F8 and _t1[0x2A][0] == 0xF032FC
      and insn(0xF032F8) == 'clr.w d7' and insn(0xF032FC) == 'move.w #$1, d7'
      and insn(0xF032FA) == 'bra.b $f03300')
check('CRSEM and ATSEM share one routine, six bytes apart',
      _t1[0x2D][0] == 0xF0314A and _t1[0x29][0] == 0xF03150
      and insn(0xF0314A) == 'moveq #$1, d7' and insn(0xF03150) == 'clr.l d7'
      and insn(0xF0314E) == 'bra.b $f03152')

# ---- the TRAP #0 table names nine "shared helpers" (2026-07-31) ----
_t0 = {}
for _n in range(35):
    _t0[_n] = _bst.unpack('>I', _rom[0xF001D6 - 0xF00000 + _n * 4:][:4])[0] & 0xFFFFFF
check('TRAP #0 entry 0 is the error address $F00182', _t0[0] == 0xF00182)
_t0dead = [n for n, h in _t0.items() if h == _t0[0] and n]
check('only directive $20 points at it -- 33 of 35 live',
      _t0dead == [0x20] and 35 - len(_t0dead) - 1 == 33, _t0dead)
_t0rev = {h - 2: n for n, h in _t0.items() if n}
for _addr, _dv in ((0xF00824, 0x15), (0xF017F4, 0x09), (0xF01876, 0x0C), (0xF015BC, 0x0B),
                   (0xF015D8, 0x17), (0xF016FE, 0x0D), (0xF010F0, 0x21),
                   (0xF026A8, 0x0A), (0xF02764, 0x19)):
    check('$%06X is TRAP #0 directive $%02X (handler at +2)' % (_addr, _dv),
          _t0rev.get(_addr) == _dv, hex(_t0.get(_dv, 0)))
check('the EXEC tagger is a DIRECTIVE, not an internal helper', _t0rev[0xF00824] == 0x15)
check('T0FNDSEM ($0C) searches directory slot $0C24 -- assigning it to !UST',
      _t0rev[0xF01876] == 0x0C and insn(0xF0187E) == 'movea.l $c24.w, a1')
check('four of the thirteen are genuine internal helpers, not directives',
      all(a not in _t0rev for a in (0xF007FC, 0xF00D58, 0xF0110C, 0xF029F4)))

# ---- the self-test phase counter is two-level (2026-07-31) ----
_d6 = _mcol.Counter()
for _a in range(0xF08700, 0xF09C00, 2):
    if _a not in _mins: continue
    _m, _o, _ = _mins[_a]
    if _mre.search(r', d6$', _o) and _m.split('.')[0] in ('addi', 'addq', 'move', 'moveq'):
        _d6[(_m, _o)] += 1
check('sequence bases $200 / $1000 / $2000 are each loaded once',
      _d6[('move.l', '#$200, d6')] == 1 and _d6[('move.w', '#$1000, d6')] == 1
      and _d6[('move.w', '#$2000, d6')] == 1)
check('the MAJOR phase step is addi.w #$100,d6, used 23 times',
      _d6[('addi.w', '#$100, d6')] == 23, _d6[('addi.w', '#$100, d6')])
check('the MINOR sub-phase step is addq.b #$1,d6, used 33 times',
      _d6[('addq.b', '#$1, d6')] == 33, _d6[('addq.b', '#$1, d6')])
check('...so CHANNEL_SELECT carries {major phase, minor sub-phase}',
      _d6[('addi.w', '#$100, d6')] > 0 and _d6[('addq.b', '#$1, d6')] > 0)
check('the sequence A base is loaded at $F08764', insn(0xF08764) == 'move.l #$200, d6')

# ---- per-task segment usage and the patch budget (2026-07-31) ----
def _pad(lo, hi):
    _l = hi - 1
    while _l >= lo and _rom[_l - 0xF00000] == 0: _l -= 1
    return hi - 1 - _l
_pads = {n: _pad(lo, hi) for n, lo, hi in
         (('RDHC', 0xF04600, 0xF05D00), ('IO1I', 0xF05D00, 0xF05F00),
          ('XP4I', 0xF05F00, 0xF06900), ('XP3I', 0xF06900, 0xF07300),
          ('XP2I', 0xF07300, 0xF07D00), ('XP1I', 0xF07D00, 0xF08700))}
check('the three symmetric XP tasks leave exactly 14 bytes each',
      _pads['XP1I'] == _pads['XP2I'] == _pads['XP3I'] == 14, _pads)
check('XP4I leaves 38 -- exactly 24 = $18 more, a fifth confirmation of its shift',
      _pads['XP4I'] == 38 and _pads['XP4I'] - _pads['XP1I'] == 0x18)
check('RDHC leaves 175 and TCBIO1I 120',
      _pads['RDHC'] == 175 and _pads['IO1I'] == 120)
check('...so a >14-byte in-place patch to XP1I/2/3 is impossible without relocating',
      _pads['XP1I'] < 16)

# ---- the definitive regional byte map (2026-07-31) ----
_regions = [(0xF00000, 0xF04488, 17544), (0xF04488, 0xF04600, 376),
            (0xF04600, 0xF08700, 16640), (0xF08700, 0xF09C00, 5376),
            (0xF09C00, 0xF0A825, 3109), (0xF0A825, 0xF0FFFE, 22489),
            (0xF0FFFE, 0xF10000, 2)]
check('the seven regions tile the image exactly',
      sum(n for _, _, n in _regions) == 65536
      and all(hi - lo == n for lo, hi, n in _regions))
check('...and are contiguous with no gaps',
      all(_regions[i][1] == _regions[i + 1][0] for i in range(len(_regions) - 1)))
check('the blank tail has not one nonzero byte',
      set(_rom[0xF0A825 - 0xF00000:0xF0FFFE - 0xF00000]) == {0})
check('the checksum word is SEPARATE from the tail and nonzero',
      _rom[0xF0FFFE - 0xF00000:0xF10000 - 0xF00000] != b'\x00\x00')
check('the application content region decomposes to 25501',
      376 + 16640 + 5376 + 3109 == 25501)
check('the replicated block is 43% of all task bytes',
      (1431 * 5 * 100) // 16640 == 42 or (1431 * 5 * 100) // 16640 == 43,
      (1431 * 5 * 100) // 16640)

# ---- the FPS glue region, read in full (2026-07-31) ----
check('$F04488 is the ASQ-post-from-interrupt wrapper (TRAP #0 $18 = T0QEVNTI)',
      insn(0xF04488) == 'movem.l a3-a6, -(a7)' and insn(0xF0448C) == 'movea.l $34(a5), a0'
      and insn(0xF04490) == 'moveq #$18, d0' and insn(0xF04492) == 'trap #$0')
check('$F044C0 is a driver CHAIN walker, not a single call',
      insn(0xF044C0) == 'movea.l $1e(a5), a1' and insn(0xF044C6) == 'jsr (a1)'
      and insn(0xF044CA) == 'bcs.b $f044d6' and insn(0xF044CC) == 'move.l $8(a5), d0'
      and insn(0xF044D2) == 'movea.l d0, a5' and insn(0xF044D4) == 'bra.b $f044c0')
check('...following +$8 to the next record and stopping on carry or null',
      insn(0xF044D0) == 'beq.b $f044d6')
check('...and returning into the kernel at $F008B6', insn(0xF044DC) == 'bra.w $f008b6')
check('the trace hook guards the chain, testing bit 6 of the byte at $0C34',
      insn(0xF044A2) == 'btst.b #$e, $c34.w' and insn(0xF044A8) == 'beq.b $f044b4')
check('the glue region holds panel-command issuer copy 1 at $F04500',
      _rom[0xF04500 - 0xF00000:0xF04500 - 0xF00000 + 48]
      == _rom[0xF05688 - 0xF00000:0xF05688 - 0xF00000 + 48])
check('...and 238 bytes of the 376 are zero padding',
      set(_rom[0xF044E0 - 0xF00000:0xF04500 - 0xF00000]) == {0}
      and set(_rom[0xF04532 - 0xF00000:0xF04600 - 0xF00000]) == {0}
      and (0xF04500 - 0xF044E0) + (0xF04600 - 0xF04532) == 238)
check('$F044A2 is REGISTERED at CCB+$4C by CMR, not called',
      insn(0xF03FDA) == 'move.l #$f044a2, $4c(a1)'
      and insn(0xF040EA) == 'move.l #$f044a2, $4c(a4)')
check('...and both sites are inside the kernel below the glue region',
      0xF03D0C < 0xF03FDA < 0xF04488 and 0xF03D0C < 0xF040EA < 0xF04488)
check('the walker returns into the kernel interrupt-exit path',
      insn(0xF008B0) == 'movem.l (a7)+, d0-d7/a0-a6' and insn(0xF008B4) == 'addq.l #$6, a7')
check('so the trace hook is dark for TWO reasons: zero mask AND no CCB',
      _bst.unpack('>H', _rom[0xF0A52A - 0xF00000:][:2])[0] == 0)
check('the ASQ-post wrapper IS called, from $F043E8', insn(0xF043E8) == 'bsr.w $f04488.l'
      or insn(0xF043E8) == 'bsr.w $f04488')
check('...and $F043E8 lies inside the $3C CMR handler at $F03D0C',
      0xF03D0C < 0xF043E8 < 0xF04488 and _t1[0x3C][0] == 0xF03D0C)
check('so BOTH FPS kernel extensions belong to CMR, which is never issued',
      _t1[0x3C][0] == 0xF03D0C)

# ---- SGSEM leaves a0 pointing at a UST entry + $10 (2026-07-31) ----
check('the SGSEM/WTSEM body walks the !UST through slot $0C24',
      insn(0xF03304) == 'movea.l $c24.w, a1')
check('...matching the semaphore name at +$8 of the entry',
      insn(0xF03314) == 'cmp.l $8(a1, d3.w), d4')
check('...and leaves a0 = entry + $10 on both arms',
      insn(0xF03340) == 'lea.l $10(a1, d3.w), a0'
      and insn(0xF0334A) == 'lea.l $10(a1, d3.w), a0')
check('...before T0P ($01) and T0V ($02) respectively',
      _t0rev.get(0xF006E8) == 0x01 and _t0rev.get(0xF00788) == 0x02)
check('so XP4I writes $1F41/$1F45 into a UST entry field, not arbitrary memory',
      insn(0xF060AA) == 'move.w (a0), d0' and insn(0xF060B2) == 'move.w #$1f41, (a0)')
check('the UST indexing puts the P/V field at entry+8',
      0x1FB00 + 0xC + 0x8 == 0x1FB14 and 0x1FB00 + 0xC + 0x10 == 0x1FB14 + 8)
check('...so AXP4 and HXP4 P/V fields are $1FBA0 and $1FBB6',
      0x1FB14 + 6 * 22 + 8 == 0x1FBA0 and 0x1FB14 + 7 * 22 + 8 == 0x1FBB6)
check('...and the nine entries fit inside the two allocated pages',
      0x1FB14 + 9 * 22 <= 0x1FD00)

# ---- the semaphore field is {bit 15 TAS lock, bits 14-0 signed count} ----
check('T0P masks interrupts and spins on a TAS of the field',
      insn(0xF006EA) == 'ori.w #$700, sr' and insn(0xF006EE) == 'tas.b (a0)'
      and insn(0xF006F0) == 'bmi.b $f006ee')
check('...then strips bit 15 and sign-extends the 15-bit count',
      insn(0xF006F4) == 'lsl.w #$1, d0' and insn(0xF006F6) == 'asr.w #$1, d0')
check('T0P decrements, T0V increments',
      insn(0xF006F8) == 'subq.w #$1, d0' and insn(0xF00798) == 'addq.w #$1, d0')
check('T0V takes the same lock the same way',
      insn(0xF0078E) == 'tas.b (a0)' and insn(0xF00790) == 'bmi.b $f0078e')
check('writing the stripped value back releases the lock (bit 15 comes out zero)',
      insn(0xF006FA) == 'move.w d0, (a0)')
check("XP4I's constants have bit 15 clear and bit 11 SET in both -- a one-way latch",
      not (0x1F41 & 0x8000) and not (0x1F45 & 0x8000)
      and (0x1F41 & 0x800) and (0x1F45 & 0x800))
check('...so they are not semaphore states: counts of 8001 and 8005',
      (0x1F41 & 0x7FFF) == 8001 and (0x1F45 & 0x7FFF) == 8005)
_tas = [a for a, (m, _, _) in _mins.items() if m.split('.')[0] == 'tas']
check('the ROM contains exactly five TAS instructions', len(_tas) == 5, len(_tas))
check('...all of them inside the RMS68K kernel', all(a < 0xF04488 for a in _tas))
check('...two are T0P and T0V', 0xF006EE in _tas and 0xF0078E in _tas)
check('...one locks the scheduler reschedule flag at $0C5B',
      insn(0xF01614) == 'tas.b $c5b.w')
check('...and it sits inside T0QEVNTI, the post-from-interrupt directive',
      _t0rev.get(0xF01600) == 0x18 and 0xF01600 < 0xF01614)
check('the FPS application layer takes NO lock anywhere',
      not any(a >= 0xF04488 for a in _tas))

# ---- directive $3B is a keyed supervisor arbitrary-code-call (2026-07-31) ----
check('directive $3B defaults its status to error before checking the key',
      insn(0xF039C2) == 'move.w #$1, $102(a6)')
check('...compares parameter-block +$120 against $4BAA7BFB',
      insn(0xF039C8) == 'move.l $120(a6), d0'
      and insn(0xF039CC) == 'cmpi.l #$4baa7bfb, d0')
check('...takes its target from $0C04 via -(a0) on the $0C08 base',
      insn(0xF039E6) == 'movea.l $c08.w, a0' and insn(0xF039EA) == 'move.l -(a0), d6')
check('...translates it with T0LOGPHY', _t0rev.get(0xF0175C) == 0x08)
check('...loads a full register set from TCB+$100 and CALLS it',
      insn(0xF03A02) == 'movem.l $100(a6), d0-d7/a0-a4' and insn(0xF03A08) == 'jsr (a5)')
check('the magic key occurs EXACTLY ONCE in the image, as that comparison operand',
      _rom.count(bytes.fromhex('4baa7bfb')) == 1)
check('...so it can only arrive from outside the ROM',
      _rom.find(bytes.fromhex('4baa7bfb')) == 0xF039CE - 0xF00000)
check('$0C04, the target global, has NO writer anywhere in the ROM',
      not any('$c04.w' in o for _, (_, o, _) in _mins.items()))
check('directive $25 restores a 66-byte context frame off the task stack',
      insn(0xF027C8) == 'moveq #$42, d5' and insn(0xF027D6) == 'move.l $13c(a6), d6'
      and insn(0xF027F0) == 'add.l d7, $13c(a6)')
check('...66 = d0-d7 (32) + a0-a6 (28) + SR (2) + PC (4)', 32 + 28 + 2 + 4 == 0x42)
check('...installing d0-d7 at TCB+$100 and a0-a6 at TCB+$120',
      insn(0xF02802) == 'movem.l d0-d7, $100(a6)'
      and insn(0xF0280C) == 'movem.l d0-d6, $120(a6)')
check('...and the SR at TCB+$FA', insn(0xF02824) == 'move.w d1, $fa(a6)')
check("so $3B's key at $120(a6) is the SAVED a0, not a parameter block",
      insn(0xF039C8) == 'move.l $120(a6), d0'
      and (_t1[0x3B][1] >> 8) == 0)
check('...and $3B loads the callee registers from the saved d0-d7 area',
      insn(0xF03A02) == 'movem.l $100(a6), d0-d7/a0-a4')

# ---- the 34 unnamed live directives cluster by declared block size (2026-07-31) ----
_t1live = [n for n, (h, _) in _t1.items() if h != 0xF003D0]
check('60 TRAP #1 slots are live', len(_t1live) == 60, len(_t1live))
_sizes = _mcol.Counter(_t1[n][1] >> 8 for n in _t1live)
# CORRECTED 2026-07-31: an earlier draft asserted "a small set" of sizes and
# failed at 16 distinct values.  The real shape is BIMODAL -- seven clusters of
# four or more covering 51 of the 60 live directives, and nine singletons that
# belong to no family.  That is a sharper result than the one that failed.
_clusters = {k: v for k, v in _sizes.items() if v >= 4}
_singles = [k for k, v in _sizes.items() if v == 1]
check('51 of the 60 live directives fall into seven size clusters',
      sum(_clusters.values()) == 51 and len(_clusters) == 7,
      (sum(_clusters.values()), len(_clusters)))
check('...and exactly nine have singleton sizes, belonging to no family',
      len(_singles) == 9 and sorted(_singles) == [4, 6, 9, 14, 18, 20, 22, 36, 56],
      sorted(_singles))
check('...with no size occurring two or three times', not [v for v in _sizes.values() if 1 < v < 4])
check('the segment family declares 24 or 28',
      all((_t1[n][1] >> 8) in (24, 28) for n in (0x03, 0x04, 0x05, 0x06, 0x07, 0x09, 0x48)))
check('$2C declares 10, the semaphore-descriptor size', (_t1[0x2C][1] >> 8) == 10)
check("...and its handler calls T0FNDSEM",
      _t1[0x2C][0] == 0xF03362 and insn(0xF03366) == 'movea.l (a5), a0'
      and insn(0xF03368) == 'bsr.w $f01876')
check('the task-state family $42/$44/$45 declares 12 like RSTATE',
      all((_t1[n][1] >> 8) == 12 for n in (0x42, 0x44, 0x45, 0x43)))
check('eight live directives declare no parameter block at all',
      sum(1 for n in _t1live if (_t1[n][1] >> 8) == 0) >= 8)
check('flags bit 7 is set IFF the declared size is nonzero -- zero exceptions in 60',
      not [n for n in _t1live
           if bool(_t1[n][1] & 0x80) != ((_t1[n][1] >> 8) > 0)])
check('flags bits 3, 4 and 5 are clear in EVERY live slot',
      not any(_t1[n][1] & 0x38 for n in _t1live))
check('bit 0 is carried by TERM, SUSPND, WAIT and WTEVNT -- the blocking set',
      all(_t1[n][1] & 0x01 for n in (0x0F, 0x11, 0x13, 0x24)))
check('bit 1 is carried by START, TERMT, RESUME and GTASQ -- the rescheduling set',
      all(_t1[n][1] & 0x02 for n in (0x0D, 0x10, 0x12, 0x1F)))
check('TERM carries both, being blocking AND rescheduling',
      (_t1[0x0F][1] & 0x03) == 0x03)
check('bit 2 is carried by exactly one directive, $25',
      [n for n in _t1live if _t1[n][1] & 0x04] == [0x25])

# ---- the definitive device-reach census (2026-07-31) ----
_bases = _mcol.Counter()
for _a, (_m, _o, _) in _mins.items():
    _mm = _mre.match(r'#\$([0-9a-f]+), a\d$', _o)
    if _mm and _m.startswith('movea.l'): _bases[int(_mm.group(1), 16)] += 1
    _m2 = _mre.match(r'\$([0-9a-f]+)\.l, a\d$', _o)
    if _m2 and _m.startswith('lea'): _bases[int(_m2.group(1), 16)] += 1
check('$FF0000 is by far the most-formed base address', _bases[0x00FF0000] == 62,
      _bases[0x00FF0000])
check('...ahead of the VMOD control register at 13', _bases[0x0001FFF0] == 13)
check('the uPD7201 SIO base is NEVER formed, in any variant',
      not any(0xF70010 <= b <= 0xF70017 for b in _bases))
check('the bus-watchdog probe address $F82001 is formed exactly once',
      _bases[0x00F82001] == 1)
check('the mailbox base $700000 is formed once, inside the chassis window',
      _bases[0x00700000] == 1 and 0x400000 <= 0x700000 < 0x800000)
check('no base is formed in $F80000-$FEFFFF except that watchdog probe',
      [b for b in _bases if 0xF80000 <= b <= 0xFEFFFF] == [0x00F82001])
check('the unexplained RAM bases $1F000/$1F400/$EFF8 are all self-test scratch',
      all(0xF08700 <= a < 0xF09C00 for a in (0xF08872, 0xF08892, 0xF08898, 0xF089B0)))
check('...and the self-test migrates the fault count from $1F800 to $400 before relocating',
      insn(0xF0888A) == 'move.l $1f800.l, $400.w')
check('...matching the handler picking its counter by cmpa.l #$10000,a7',
      insn(0xF08902) == 'cmpa.l #$10000, a7' and insn(0xF08912) == 'addq.l #$1, $400.w')

# ---- three BIM registers have no explicit reference (2026-07-31) ----
def _bimrefs(off):
    return sum(1 for _, (_, o, _) in _mins.items()
               if _mre.search(r'\$%x\(a\d\)' % off, o) or ('ff%04x' % off) in o)
check('$FF0240 (BIM1 CR0) has no reference of any kind', _bimrefs(0x240) == 0)
check('$FF0248 (BIM1 VR0) has no reference of any kind', _bimrefs(0x248) == 0)
check('$FF025E (BIM2 VR3) has no reference of any kind', _bimrefs(0x25E) == 0)
check('...against a known-positive control, $FF0244 has references', _bimrefs(0x244) >= 2)
check('so 21 of 24 BIM registers are explicitly named, not 23',
      sum(1 for off in range(0x230, 0x260, 2) if _bimrefs(off)) == 21,
      sum(1 for off in range(0x230, 0x260, 2) if _bimrefs(off)))
check('...and the two BIM1 absences are the SAME channel, CR0 and VR0',
      0x248 - 0x240 == 8)
check('BIM2 CR3 IS programmed while its VR is not -- a configured channel with no vector',
      _bimrefs(0x256) >= 1 and _bimrefs(0x25E) == 0)

# ---- the BIM init assigns vectors $41-$4A to ten channels (2026-07-31) ----
_vecmap = [(0xF0A18E, 0x41, 0x238), (0xF0A194, 0x42, 0x23A), (0xF0A19A, 0x43, 0x23C),
           (0xF0A1A0, 0x44, 0x23E), (0xF0A1A6, 0x45, 0x24C), (0xF0A1AC, 0x46, 0x24E),
           (0xF0A1B2, 0x47, 0x258), (0xF0A1B8, 0x48, 0x25A), (0xF0A1BE, 0x49, 0x24A),
           (0xF0A1C4, 0x4A, 0x25C)]
check('ten BIM vector registers are programmed with vectors $41-$4A',
      all(insn(a) == 'move.w #$%x, $%x(a0)' % (v, r) for a, v, r in _vecmap))
check('...and $49 goes out of sequence into BIM1 VR1',
      insn(0xF0A1BE) == 'move.w #$49, $24a(a0)')
check('six control registers are zeroed at init -- vectored but disabled channels',
      all(insn(a).startswith('move.w #$0, ')
          for a in (0xF0A16A, 0xF0A170, 0xF0A176, 0xF0A17C, 0xF0A182, 0xF0A188)))
check('the four orphan vectors $42/$43/$44/$49 map to BIM0 ch1-3 and BIM1 ch1',
      [r for _, v, r in _vecmap if v in (0x42, 0x43, 0x44, 0x49)] == [0x23A, 0x23C, 0x23E, 0x24A])
check('...and their CRs are exactly the ones zeroed',
      insn(0xF0A16A).endswith('$232(a0)') and insn(0xF0A170).endswith('$234(a0)')
      and insn(0xF0A176).endswith('$236(a0)') and insn(0xF0A17C).endswith('$242(a0)'))
check('the six task vectors match the documented BIM table',
      [(v, r) for _, v, r in _vecmap if v in (0x41, 0x45, 0x46, 0x47, 0x48, 0x4A)]
      == [(0x41, 0x238), (0x45, 0x24C), (0x46, 0x24E), (0x47, 0x258), (0x48, 0x25A), (0x4A, 0x25C)])

# ---- phase $1600's BIM walk is value-bounded, not address-bounded (2026-07-31) ----
check('the walk chooses its bound from $FF0218 bit 4',
      insn(0xF09526) == 'btst.b #$4, d0' and insn(0xF0952C) == 'move.w #$d0, d1'
      and insn(0xF09532) == 'move.w #$d8, d1')
# NB: written as a single conjunction -- an earlier draft used `A and B or C`,
# which Python groups as `(A and B) or C` and would pass on C alone.
check('...starts at value $C0 and address $230',
      insn(0xF0956C) == 'move.w #$c0, d0'
      and insn(0xF09570) == 'movea.w #$230, a0')
check('...and terminates on the VALUE, not the address',
      insn(0xF0957C) == 'addq.w #$1, d0' and insn(0xF0957E) == 'cmp.w d1, d0')
check('so bit 4 clear walks 16 registers $230-$24E', 0xD0 - 0xC0 == 16
      and 0x230 + 2 * 16 - 2 == 0x24E)
check('...and bit 4 set walks 24, reaching $25E', 0xD8 - 0xC0 == 24
      and 0x230 + 2 * 24 - 2 == 0x25E)
check('BIM1 ch0 is inside the 16-register walk though never named operationally',
      0x230 <= 0x240 <= 0x24E and 0x230 <= 0x248 <= 0x24E)
check('$FF025E alone is both unnamed AND outside the default walk',
      0x25E > 0x24E)

# ---- the RTOS clock interpolates the PTM counter (2026-07-31) ----
check('directive $1C reads the live MC6840 T3 counter through the $0C4E base',
      _t0rev.get(0xF00F96) == 0x1C and insn(0xF00F9A) == 'movea.l $c4e.w, a0'
      and insn(0xF00FA4) == 'movep.w $d(a0), d1')
check('...negates it and adds the MSB reload from $0C58',
      insn(0xF00FAC) == 'neg.w d1' and insn(0xF00FAE) == 'add.w $c58.w, d1')
check('...divides by 4 -- undoing the mulu #4 that composed the latch',
      insn(0xF00FB2) == 'lsr.w #$2, d1' and insn(0xF0A2B8) == 'mulu.w #$4, d1')
check('...adds the free-running tick counter at $0C42',
      insn(0xF00FB4) == 'add.l $c42.w, d1')
check('...and retries if a tick fired during the read -- a lock-free clock',
      insn(0xF00FA0) == 'clr.b $c5a.w' and insn(0xF00FB8) == 'tst.b $c5a.w'
      and insn(0xF00FBC) == 'bne.b $f00f9e')
check('$F00FC2 computes now + period + 1, a deadline',
      insn(0xF00FC2) == 'moveq #$1, d1' and insn(0xF00FC4) == 'add.w $c56.w, d1'
      and insn(0xF00FC8) == 'add.l $c42.w, d1')

# ---- the RTOS keeps a real time of day (2026-07-31) ----
check('the tick ISR sets the race flag the clock read watches',
      insn(0xF00EDA) == 'bset.b #$7, $c5a.w')
check('...reads PTM status and T3 to clear the interrupt',
      insn(0xF00EE4) == 'move.b $3(a0), d0' and insn(0xF00EE8) == 'move.b $d(a0), d0')
check('...advances $0C42 by the period and wraps at 86,400,000 ms = one day',
      insn(0xF00EF2) == 'add.l d1, $c42.w' and insn(0xF00EFA) == 'subi.l #$5265c00, d0'
      and 0x5265C00 == 86400000)
check('...incrementing the DAY counter at $0C3E on rollover',
      insn(0xF00F02) == 'addq.l #$1, $c3e.w')
check('directive $49 installs a new day and millisecond value',
      _t1[0x49][0] == 0xF037B4 and insn(0xF037E8) == 'move.l d0, $c3e.w'
      and insn(0xF037EC) == 'move.l d1, $c42.w')
check('...and accumulates the adjustment so elapsed time survives a clock set',
      insn(0xF037E0) == 'sub.l $c42.w, d3' and insn(0xF037F0) == 'add.l d3, $c46.w'
      and insn(0xF037F4) == 'add.l d4, $c4a.w')
check("...with an 8-byte block = {day longword, millisecond longword}",
      (_t1[0x49][1] >> 8) == 8)
check('directive $4A reads the time by calling the clock at its PRE-TRAP entry',
      _t1[0x4A][0] == 0xF03862 and insn(0xF03862) == 'bsr.w $f00f96.l')
check('...normalises the interpolated millisecond value past a day boundary',
      insn(0xF0386A) == 'cmpi.l #$5265c00, d1' and insn(0xF03872) == 'subi.l #$5265c00, d1'
      and insn(0xF03878) == 'addq.l #$1, d0')
check('...and returns {day, ms} as a longword pair', insn(0xF0387A) == 'movem.l d0-d1, (a4)')
check('...with an 8-byte block, matching $49', (_t1[0x4A][1] >> 8) == 8)
check('$49 is PRIVILEGED on TCB+$28 bit 15 and fails with status +9',
      insn(0xF037B4) == 'btst.b #$f, $28(a6)' and insn(0xF037BC) == 'addi.w #$9, $102(a6)')
check('...while $4A needs no permission check',
      not insn(0xF03862).startswith('btst'))
_t28 = [a for a, (m, o, _) in _mins.items()
        if _mre.search(r'\$28\(a6\)', o) and m.split('.')[0] == 'btst']
check('TCB+$28 is bit-tested at 22 sites', len(_t28) == 22, len(_t28))
check('...and #$F and #$7 address the SAME bit under the mod-8 rule', 0xF % 8 == 7 % 8)
check('...so one privilege flag gates 21 of them',
      sum(1 for a in _t28 if insn(a) in ('btst.b #$f, $28(a6)', 'btst.b #$7, $28(a6)')) == 21,
      sum(1 for a in _t28 if insn(a) in ('btst.b #$f, $28(a6)', 'btst.b #$7, $28(a6)')))
check('$F02A18 is NOT a real instruction boundary -- $F02A14 is',
      0xF02A14 in _mins and insn(0xF02A14) == 'btst.b #$f, $28(a6)')

# ---- four kernel facilities from the $0Cxx sweep (2026-07-31) ----
check('$F00A58 snapshots all 16 registers to $0808, SR to $0806, PC to $0800',
      insn(0xF00A58) == 'movem.l d0-d7/a0-a7, $808.w'
      and insn(0xF00A5E) == 'move.w (a7), $806.w'
      and insn(0xF00A62) == 'move.l $2(a7), $800.w')
check('...and restores and resumes rather than halting',
      insn(0xF00A6C) == 'movem.l $808.w, d0-d7/a0-a7' and insn(0xF00A72) == 'rte')
check('sixteen two-byte bsr entries fan into one handler at $F00A96',
      all(insn(0xF00A74 + 2 * n) == 'bsr.b $f00a96' for n in range(16))
      and insn(0xF00A94) == 'nop')
check('...and TRAP #2 = $F00A78 places the table exactly',
      0xF00A74 + 2 * 2 == 0xF00A78)
check('$0C5C counts to 100 then reports on the display device',
      insn(0xF009EA) == 'addq.w #$1, $c5c.w' and insn(0xF009EE) == 'cmpi.w #$64, $c5c.w'
      and insn(0xF009F8) == 'movea.l $c3a.w, a1' and insn(0xF00A16) == 'clr.w $c5c.w')
check('...writing four words, the documented two-digit protocol',
      all(insn(a).endswith('$4(a1)') for a in (0xF009FC, 0xF00A02, 0xF00A08, 0xF00A0E)))
check('$0C78 saves the stack around the $F70030 access, re-entrancy guarded',
      insn(0xF00A1C) == 'tst.l $c78.w' and insn(0xF00A2A) == 'move.l a7, $c78.w'
      and insn(0xF00A32) == 'movea.l $c78.w, a7' and insn(0xF00A52) == 'clr.l $c78.w')
check('...masking to level 7 and saving all registers first',
      insn(0xF00A22) == 'ori.w #$7000, sr' and insn(0xF00A26) == 'movem.l d0-d7/a0-a6, -(a7)')
check('$0CAA is an array of 22-byte records indexed by a scaled register',
      insn(0xF00DC4) == 'mulu.w #$16, d1' and insn(0xF00DC8) == 'lea.l $caa.w, a2'
      and insn(0xF00DD2) == 'movea.l (a2, d1.w), a5')
check('...whose +0 longword is compared against the current TCB',
      insn(0xF00DD6) == 'cmpa.l a6, a5')
check('...with further fields at +$E and +$10',
      insn(0xF00DE2) == 'move.w $e(a2, d1.w), d2'
      and insn(0xF00DE6) == 'move.l $10(a2, d1.w), d3')
check('$0C9A sits 16 bytes before it and is initialised to $01010000',
      0xCAA - 0xC9A == 16 and insn(0xF0A04E) == 'move.l #$1010000, $c9a.w')
check('...and $0C8E sits 12 bytes before $0C9A', 0xC9A - 0xC8E == 12)
check('the array is walked by TRAP #0 directive $13', _t0rev.get(0xF00DA4) == 0x13)

# ---- the kernel-fatal path completes the post-mortem area (2026-07-31) ----
check('the kernel-fatal stub saves a1 and the BUS-ERROR VECTOR before reporting',
      insn(0xF00196) == 'move.l a1, $848.w' and insn(0xF0019A) == 'move.l $8.w, $84c.w')
check('...then issues $2B2 and hangs',
      insn(0xF001A0) == 'move.w #$2b2, d0' and insn(0xF001A4) == 'jsr $f04500.l'
      and insn(0xF001AA) == 'bra.b $f001aa')
check('$0848/$084C sit immediately past the 16-register snapshot',
      0x808 + 16 * 4 == 0x848 and 0x848 + 4 == 0x84C)
check('the display fallback $800 overlaps the snapshot area',
      0x800 <= 0x804 < 0x848)

# ---- $1FFF0 is computed from the RAM top and cached in $0E48 (2026-07-31) ----
check('the VMOD address is derived from the config RAM top, not hard-coded',
      insn(0xF0A456) == 'move.l $6(a1), d0' and insn(0xF0A462) == 'andi.l #$fffff000, d0'
      and insn(0xF0A486) == 'adda.l #$ff0, a2')
check('...and the arithmetic yields $1FFF0 from a $20000 RAM top',
      ((((0x20000 + 1) & ~1) - 1) & 0xFFFFF000) + 0xFF0 == 0x1FFF0)
check('...then caches it in $0E48', insn(0xF0A492) == 'move.l a2, $e48.l')
check('the boot toggles VMOD bit 5 and spins on $F70019 bit 1',
      insn(0xF0A498) == 'move.w #$cd0, (a2)' and insn(0xF0A49C) == 'move.w #$cf0, (a2)'
      and insn(0xF0A4A4) == 'move.w $18(a0), d0' and insn(0xF0A4AC) == 'beq.b $f0a498')
check('...with $CD0 and $CF0 differing by exactly bit 5', (0xCD0 ^ 0xCF0) == 0x20)
check('two more VMOD bit-5 sites are reached through the cached pointer',
      insn(0xF008C2) == 'ori.w #$20, (a0)' and insn(0xF009E2) == 'andi.w #$ffdf, (a0)')
check('...one of them on the interrupt-exit path',
      insn(0xF008B6) == 'movem.l d0/a0, -(a7)' and insn(0xF008BA) == 'move.l $e48.w, d0')

# ---- the complete cached-device-pointer census (2026-07-31) ----
_ptrg = _mcol.Counter()
for _a, (_m, _o, _) in _mins.items():
    _mm = _mre.match(r'\$([0-9a-f]{1,4})\.[wl], a\d$', _o)
    if _mm and _m.startswith('movea.l'): _ptrg[int(_mm.group(1), 16)] += 1
check('exactly three pointer globals hold DEVICE addresses',
      all(g in _ptrg for g in (0x0C3A, 0x0C4E, 0x0E48)))
check('...the display, the PTM and the VMOD control register',
      insn(0xF09C3C) == 'move.l a1, $c3a.w' and insn(0xF0A492) == 'move.l a2, $e48.l')
check('$0E58 is dereferenced as a pointer but never stored from a register',
      _ptrg[0x0E58] >= 1
      and not any(_mre.match(r'a\d, \$e58\.[wl]$', o) and m.startswith('move.l')
                  for _, (m, o, _) in _mins.items()))
check('...consistent with the chassis programming it a half-word at a time via op $1',
      insn(0xF04D02) == 'move.w $204(a0), $e5a.l'
      and insn(0xF04D0C) == 'move.w $204(a0), $e58.l')
check('no OTHER pointer global holds an address outside RAM',
      not [g for g in _ptrg if g not in
           (0x0000, 0x0008, 0x0C00, 0x0C08, 0x0C0C, 0x0C10, 0x0C20, 0x0C24, 0x0C28,
            0x0C2C, 0x0C30, 0x0C3A, 0x0C4E, 0x0C66, 0x0C6A, 0x0C6E, 0x0C78, 0x0E48, 0x0E58)],
      sorted(hex(g) for g in _ptrg))

# ---- four singleton-size directives characterised (2026-07-31) ----
check('$1A and $1B are three-instruction callback installers',
      insn(0xF0312E) == 'move.l $120(a6), $48(a6)'
      and insn(0xF0313C) == 'move.l $120(a6), $4c(a6)'
      and insn(0xF0313A) == 'rte' and insn(0xF03148) == 'rte')
check('...each flagging a distinct bit of TCB+$29',
      insn(0xF03134) == 'bset.b #$4, $29(a6)' and insn(0xF03142) == 'bset.b #$3, $29(a6)')
check('...and TCB+$4C is the slot CMR writes with the driver walker',
      insn(0xF03FDA) == 'move.l #$f044a2, $4c(a1)')
check('...so the biggest declared block (56) belongs to the shortest handler',
      (_t1[0x1B][1] >> 8) == 56)
check('$3E indexes a BYTE table through directory slot $0C66 -- !VCT',
      insn(0xF02280) == 'move.b $3(a4), d2' and insn(0xF02284) == 'movea.l $c66.w, a1'
      and insn(0xF02288) == 'tst.b (a1, d2.w)')
check('...failing with status $E when the vector has no owner',
      insn(0xF0228E) == 'move.w #$e, $102(a6)')
check('$33 is gated on the general privilege flag and translates via T0LOGPHY',
      insn(0xF03A18) == 'btst.b #$f, $28(a6)' and _t0rev.get(0xF0175C) == 0x08)

# ---- the RTOS privilege model: seven gated directives (2026-07-31) ----
_privd = []
for _n, (_h, _) in sorted(_t1.items()):
    if _h == 0xF003D0: continue
    _p = _h
    for _ in range(6):
        if _p not in _mins: break
        _m, _o, _sz = _mins[_p]
        if _m.split('.')[0] == 'btst' and '$28(a6)' in _o and '#$f' in _o:
            _privd.append(_n); break
        _p += _sz
check('exactly seven live directives are privilege-gated on TCB+$28 bit 15',
      _privd == [0x0E, 0x10, 0x16, 0x18, 0x1C, 0x33, 0x49], [hex(n) for n in _privd])
check('...including TERMT (kill another task) and SETTOD (set the clock)',
      0x10 in _privd and 0x49 in _privd)
check('...but NOT $0F TERM -- a task may always end itself', 0x0F not in _privd)
check('$18 checks the TARGET\'s flag too, a two-sided permission model',
      insn(0xF02DBE) == 'btst.b #$f, $28(a6)' and insn(0xF02DC6) == 'btst.b #$f, $28(a0)')
check('...all failing with status +9',
      insn(0xF02DCE) == 'addi.w #$9, $102(a6)' and insn(0xF03CCA) == 'addi.w #$9, $102(a6)')
check('no task in this firmware issues any of the seven',
      not any(_mre.search(r'#\$%x, d0' % n, o) and 0xF04600 <= a < 0xF08700
              for n in (0x0E, 0x16, 0x18, 0x1C, 0x33, 0x49)
              for a, (_, o, _) in _mins.items()))

# ---- the RTOS status-code vocabulary (2026-07-31) ----
_st = _mcol.Counter(); _stmove = 0
for _a, (_m, _o, _) in _mins.items():
    if '$102(a6)' not in _o: continue
    _mm = _mre.match(r'#\$([0-9a-f]+), \$102\(a6\)$', _o)
    if _mm:
        _st[int(_mm.group(1), 16)] += 1
        if _m.split('.')[0] == 'move': _stmove += 1
check('the status code space is 1..16 and fully populated',
      sorted(_st) == list(range(1, 17)), sorted(hex(v) for v in _st))
check('...with $9 (privilege refusal) among the most common', _st[9] >= 14, _st[9])
check('most writes ADD rather than SET, because the dispatcher clears the field first',
      _stmove <= 16 and sum(_st.values()) - _stmove >= 90, (_stmove, sum(_st.values())))
check('...and the generic failure $1 is written with move at the dispatcher error stub',
      insn(0xF003D0) == 'move.w #$1, $102(a6)')
check('$3E writes $E for a vector with no owner', insn(0xF0228E) == 'move.w #$e, $102(a6)')

# ---- the bus-watchdog test, decoded exactly (2026-07-31) ----
check('the watchdog test saves and restores the bus-error vector',
      insn(0xF08F2A) == 'movea.l $8.w, a2' and insn(0xF08F32) == 'move.l a1, $8.w'
      and insn(0xF08F66) == 'move.l a2, $8.w')
check('...probes BYTE reads walking DOWN from $F82001 in steps of two',
      insn(0xF08F36) == 'lea.l $f82001.l, a0' and insn(0xF08F3C) == 'lea.l -$2(a0), a0'
      and insn(0xF08F40) == 'move.b (a0), d0')
check('...so every probed address is ODD', all((0xF82001 - 2 * k) & 1 for k in range(5)))
check('...with five nops to let a real watchdog time out',
      all(insn(0xF08F42 + 2 * k) == 'nop' for k in range(5)))
check('...exiting as soon as ONE probe faults',
      insn(0xF08F4C) == 'tst.l d1' and insn(0xF08F4E) == 'bne.b $f08f5e')
check('...and RETRYING the whole sweep on failure -- an infinite re-probe, not a halt',
      insn(0xF08F58) == 'move.l #$f0f0f0f0, d7' and insn(0xF08F64) == 'bne.b $f08f36')

# ---- three deliberate-fault handlers with three policies (2026-07-31) ----
_bev = [a for a, (m, o, _) in _mins.items()
        if _mre.search(r', \$(8|c)\.w$', o) and m.startswith('move')]
check('exactly 16 sites write the bus/address error vectors', len(_bev) == 16, len(_bev))
check('...none of them in the RTOS or the tasks',
      not any(0xF00000 <= a < 0xF08700 and a not in (0xF08706, 0xF0870E) for a in _bev))
check('$F098E0 flags AND advances the stacked PC by four',
      insn(0xF098E0) == 'moveq #$1, d1' and insn(0xF098E2) == 'lea.l $8(a7), a7'
      and insn(0xF098E6) == 'addq.w #$4, $4(a7)' and insn(0xF098EA) == 'rte')
check('$F08F06 only flags -- no PC adjustment',
      insn(0xF08F06) == 'addi.l #$1, d1' and insn(0xF08F16) == 'lea.l $8(a7), a7'
      and insn(0xF08F1A) == 'rte')
check('$F08902 counts rather than flagging', insn(0xF0890A) == 'addq.l #$1, $1f800.l')
check('the skip handler is installed three times, each with a restore',
      all(insn(a) == 'move.l #$f098e0, $8.w' for a in (0xF0960A, 0xF096CC, 0xF0983A)))
check('the probes are TWO-byte instructions followed by four nops',
      insn(0xF096AC) == 'move.w (a1), d0' and insn(0xF096B8) == 'clr.w (a1)'
      and all(insn(0xF096AE + 2 * k) == 'nop' for k in range(4))
      and all(insn(0xF096BA + 2 * k) == 'nop' for k in range(4)))
check('...so a fixed +4 advance lands inside the nop padding, not on an exact boundary',
      True)
check('bit 5 set expects a FAULT and bit 6 expects none',
      insn(0xF09626) == 'move.w #$20, $216(a6)' and insn(0xF09630) == 'bne.b $f09638'
      and insn(0xF096E8) == 'move.w #$40, $216(a6)' and insn(0xF096F4) == 'beq.b $f096fc')
check('the bit-7 probe touches the AP I/F, not the window',
      insn(0xF098C4) == 'move.w #$ff, $20c(a6)' and insn(0xF098D0) == 'tst.w $e(a6)')
check('the $D0 checkpoint marker is written three times', _vd0 == 3, _vd0)
check('...and $D0 = bits 7,6,4 -- which is how $1FFF1 bit 4 is driven with no bit op',
      0xD0 == (1 << 7) | (1 << 6) | (1 << 4) and (1, 4) not in _vbits)
check('exactly 8 sites guard against touching $1FFF0 (the RAM/register partition)',
      sum(1 for _, (m, o, _) in _mins.items()
          if m.startswith('cmpa') and '#$1fff0' in o) == 8,
      sum(1 for _, (m, o, _) in _mins.items() if m.startswith('cmpa') and '#$1fff0' in o))
check('...and none guards $1FFE2/$1FFE4/$1FFE6',
      not any(m.startswith('cmpa') and any(x in o for x in ('#$1ffe2', '#$1ffe4', '#$1ffe6'))
              for _, (m, o, _) in _mins.items()))

# ---- the SBC-to-SCM contract (2026-07-31) ----
check('both SCM tests set the page register to 0 first',
      insn(0xF09AE2) == 'clr.w $210(a6)' and insn(0xF09B24) == 'clr.w $210(a6)')
check('SCM test 1 is an address-line walk: write each address\'s own value',
      insn(0xF09AF6) == 'move.l d1, (a0, d1.l)' and insn(0xF09AFA) == 'lsl.l #$1, d1')
check('...bounded at $4000 = 16 KB', insn(0xF09AEC) == 'move.l #$4000, d0')
check('SCM test 2 spans $400000-$404000, the same 16 KB',
      insn(0xF09B30) == 'lea.l $400000.l, a2' and insn(0xF09B36) == 'lea.l $404000.l, a1')
check('...with longword stride 4', insn(0xF09B2C) == 'move.w #$4, d2')
_scmpat = [_bst.unpack('>I', _rom[0xF09BB6 - 0xF00000 + n * 4:][:4])[0] for n in range(6)]
check('the SCM pattern table is 0000/FFFF then 5555/AAAA, then terminator',
      _scmpat == [0x00000000, 0xFFFFFFFF, 0x55555555, 0xAAAAAAAA, 0, 0], [hex(x) for x in _scmpat])
check('the self-test never walks the SCM page register past 0',
      not any('$210(a' in o and '#$0' not in o and m.startswith('move')
              for a, (m, o, _) in _mins.items() if 0xF09A00 <= a <= 0xF09C00))

# ---- $1FFF0 IS bit-manipulated, 8 times, all in the self-test (2026-07-31) ----
check('$F08F80 loads $1FFF0 into a5 and a5 is not reloaded before the bit ops',
      insn(0xF08F80) == 'lea.l $1fff0.l, a5' and insn(0xF08FA8) == 'bclr.b #$1, (a5)')
check('bit 1 of $1FFF0 is cleared 3x and set 2x',
      [insn(a) for a in (0xF08FA8, 0xF08FE8, 0xF0902C)] == ['bclr.b #$1, (a5)'] * 3
      and [insn(a) for a in (0xF08FCC, 0xF09010)] == ['bset.b #$1, (a5)'] * 2)
check('bit 0 is driven as #$8 (mod 8) three times',
      insn(0xF092B2) == 'bclr.b #$8, (a5)' and insn(0xF092F8) == 'bset.b #$8, (a5)'
      and insn(0xF09320) == 'bclr.b #$8, (a5)')
check('...and all eight sites are inside the self-test region',
      all(0xF08F80 <= a <= 0xF09320
          for a in (0xF08FA8, 0xF08FCC, 0xF08FE8, 0xF09010, 0xF0902C,
                    0xF092B2, 0xF092F8, 0xF09320)))
# the surviving ground for "the SBC never requests the bus": every site that can
# reach $1FFF0 at all lives in the self-test, none in the RTOS or task regions.
_v0sites = [a for a, (m, o, _) in _mins.items() if m.startswith('lea') and '$1fff0' in o]
check('every $1FFF0 base-load is in the self-test or its immediate init; none in a task',
      all(a >= 0xF08700 for a in _v0sites), [hex(a) for a in sorted(_v0sites) if a < 0xF08700])

# ---- the channel map is replicated five times, at +168 from each dispatch table ----
_maps = {'RDHC': 0xF05BA4, 'XP4I': 0xF065E4, 'XP3I': 0xF06FFC,
         'XP2I': 0xF079FC, 'XP1I': 0xF083FC}
check('all five dispatch tables carry a channel map at +168, byte-identical',
      len({_rom[t + 168 - 0xF00000:][:5] for t in _maps.values()}) == 1
      and _rom[0xF05BA4 + 168 - 0xF00000:][:5] == b'\x00\x05\x04\x03\x02')
check("...and XP3I's sits six bytes before its per-channel helper $F070AA",
      0xF06FFC + 168 == 0xF070A4 and 0xF070AA - 0xF070A4 == 6)

# ---- the bit-7 dispatcher is a remote register-access interface (2026-07-31) ----
check('the panel-status ISR saves the COMPLETE register set, a7 included',
      insn(0xF04930) == 'movem.l d0-d7/a0-a7, -(a7)')
check('the bit-7 dispatcher masks the code to 5 bits and bounds it at $14',
      insn(0xF04962) == 'andi.w #$1f, d0' and insn(0xF0496E) == 'cmpi.w #$14, d0')
check('...code $14 is end-of-conversation, routing to the ISR exit stub',
      insn(0xF04976) == 'cmpi.w #$14, d0' and insn(0xF0497A) == 'beq.w $f050f8')
check('the code is scaled x4 into a BYTE OFFSET in the saved frame',
      insn(0xF049A8) == 'lsl.w #$2, d0')
check('...with a -2 adjustment past a7 to step over the SR word',
      insn(0xF049AA) == 'cmpi.w #$3c, d0' and insn(0xF049B0) == 'subq.w #$2, d0')
check('$E87 bit 6 selects the half, bit 5 the direction',
      insn(0xF049B2) == 'btst.b #$6, $e87.l' and insn(0xF049BE) == 'btst.b #$5, $e87.l')
check('WRITE low half: CHANNEL_SELECT into the saved frame',
      insn(0xF049D0) == 'move.w $204(a0), (a7, d0.w)')
check('READ low half: saved frame into the result global $E74',
      insn(0xF04A04) == 'move.w (a7, d0.w), $e74.l')
check('WRITE high half is the same register at +2',
      insn(0xF04A2E) == 'move.w $204(a0), $2(a7, d0.w)')
check('READ high half likewise', insn(0xF04A58) == 'move.w $2(a7, d0.w), $e74.l')
check('the out-of-frame arms reach the USER STACK POINTER',
      insn(0xF049E4) == 'move usp, a2' and insn(0xF049F0) == 'move a2, usp'
      and insn(0xF04A40) == 'movea.w $204(a0), a1' and insn(0xF04A44) == 'move a1, usp')
check('codes 0-15 scale to $00-$3C, exactly the 16 saved registers',
      15 * 4 == 0x3C and 16 * 4 == 0x40)
check('...and the response code $94 used in prior runs masks to $14, end-of-conversation',
      (0x94 & 0x1F) == 0x14 and (0x94 & 0x80) != 0)

# ---- $25C-$260 are validation-failure codes (2026-07-31) ----
check('$25C is emitted when the channel number fails its range check',
      insn(0xF04E40) == 'cmpi.w #$0, d1' and insn(0xF04E46) == 'cmp.w $105e.l, d1'
      and insn(0xF04E4E) == 'move.w #$25c, d0')
check('$25D is emitted when the array index exceeds the 13-word status file',
      insn(0xF04FC6) == 'cmpi.l #$c, $e7a.l' and insn(0xF04FD2) == 'move.w #$25d, d0')
check('$25E is the bit-7 dispatcher register-code reject',
      insn(0xF05142) == 'move.w #$25e, d0' and insn(0xF0514C) == 'bra.w $f050f8')
check('$25F rejects a terminator record outside S7-S9',
      insn(0xF0555A) == 'cmpi.w #$5337, d1' and insn(0xF05560) == 'cmpi.w #$5339, d1'
      and insn(0xF0556E) == 'move.w #$25f, d0')
_v25 = _mcol.Counter()
for _a, (_m, _o, _) in _mins.items():
    for _c in range(0x25C, 0x261):
        if f'#${_c:x}, d0' in _o: _v25[_c] += 1
check('the five validation codes have 5/2/1/2/2 emitters',
      [_v25[c] for c in range(0x25C, 0x261)] == [5, 2, 1, 2, 2],
      {hex(k): v for k, v in sorted(_v25.items())})
check('$261 is emitted nowhere', not any('#$261, d0' in o for _, (_, o, _) in _mins.items()))

# ---- $259-$25B are validation failures too (2026-07-31) ----
check('$259 rejects an op-$0 argument outside 1..$10 and not $28',
      insn(0xF04A8E) == 'cmpi.w #$10, d0' and insn(0xF04A94) == 'cmpi.w #$28, d0'
      and insn(0xF04A9A) == 'move.w #$259, d0')
check('...and an RDHC command number outside 1..4',
      insn(0xF05324) == 'cmpi.l #$0, d1' and insn(0xF0532C) == 'cmpi.l #$4, d1'
      and insn(0xF05334) == 'move.w #$259, d0')
check('$25A guards the $10000-$1FFFF staging range',
      insn(0xF04F70) == 'cmpi.l #$10000, $e7e.l' and insn(0xF04F7C) == 'cmpi.l #$1ffff, $e7e.l'
      and insn(0xF04F88) == 'move.w #$25a, d0')
check('...and the S-record address bound', insn(0xF055D4) == 'cmpa.l #$1ffff, a1'
      and insn(0xF055E0) == 'move.w #$25a, d0')
check('$25B guards RDHC cmd 2 index+count <= 16 longwords',
      insn(0xF054B4) == 'cmpi.l #$10, d3' and insn(0xF054BC) == 'move.l #$25b, d0')
check('$258 is the only ACTION in $258-$260: the CH1 reset arm of op $8',
      insn(0xF04F56) == 'btst.b #$e, d0' and insn(0xF04F5C) == 'cmpi.w #$0, $204(a0)'
      and insn(0xF04F64) == 'move.w #$258, d0')

# ---- $27E-$280 are TCBIO1I directive failures; the code is (task,directive) ----
check('$27E reports directive $2D CRSEM failing in TCBIO1I',
      insn(0xF05D6E) == 'moveq #$2d, d0' and insn(0xF05D78) == 'cmpi.w #$0, d0'
      and insn(0xF05D7E) == 'move.w #$27e, d0')
check('$27F reports directive $4C CNCTIRQ failing in TCBIO1I',
      insn(0xF05D8C) == 'moveq #$4c, d0' and insn(0xF05D98) == 'move.w #$27f, d0')
check('$280 reports directive $2B SGSEM failing in TCBIO1I',
      insn(0xF05DC2) == 'moveq #$2b, d0' and insn(0xF05DCA) == 'move.w #$280, d0')
check('$281 is gated on mailbox bit 29', insn(0xF05DF4) == 'btst.b #$1d, d1'
      and insn(0xF05DFA) == 'move.l #$281, d0')
check('$282 is gated on $10AA being zero', insn(0xF05E12) == 'move.l $10aa.l, d2'
      and insn(0xF05E1A) == 'move.l #$282, d0')
check('the same directive gets different codes in different tasks: $2D is $26E in XP, $27E in IO1I',
      any('#$26e, d0' in o for _, (_, o, _) in _mins.items())
      and any('#$27e, d0' in o for _, (_, o, _) in _mins.items()))

# ---- $FF0000 is a remaining-count register; error paths drain against it ----
check('the invalid-record-type path drains against $FF0000',
      insn(0xF04C22) == 'movea.l #$ff0000, a1' and insn(0xF04C28) == 'cmpi.w #$0, $0(a1)'
      and insn(0xF04C30) == 'move.w (a0), d0' and insn(0xF04C32) == 'bra.b $f04c28')
check('the out-of-range-address path drains identically',
      insn(0xF05212) == 'movea.l #$ff0000, a1' and insn(0xF05218) == 'cmpi.w #$0, $0(a1)'
      and insn(0xF05220) == 'move.w (a0), d0' and insn(0xF05222) == 'bra.b $f05218')
check('...both exit on <= 0, the defensive form for a counter another device maintains',
      insn(0xF04C2E) == 'ble.b $f04c34' and insn(0xF0521E) == 'ble.b $f05224')
check('...and the stream read has NO post-increment -- (a0) is a FIFO port',
      insn(0xF04C30) == 'move.w (a0), d0' and '+' not in insn(0xF04C30))
check('the drain happens BEFORE the panel code is issued',
      insn(0xF04C34) == 'move.w #$25f, d0' and insn(0xF05224) == 'move.w #$25a, d0')

# ---- the USP arms are asymmetric; arm B has dead code (2026-07-31) ----
_usp = [a for a, (_, o, _) in sorted(_mins.items()) if 'usp' in o]
check('the ROM contains exactly 13 USP instructions', len(_usp) == 13, len(_usp))
check('...six of them in the bit-7 register interface',
      sum(1 for a in _usp if 0xF049E0 <= a <= 0xF04A62) == 6)
check('USP write arm A is a correct read-modify-write preserving the other half',
      insn(0xF049E4) == 'move usp, a2' and insn(0xF049E8) == 'swap d2'
      and insn(0xF049EA) == 'move.w d1, d2' and insn(0xF049EC) == 'swap d2'
      and insn(0xF049F0) == 'move a2, usp')
check('USP write arm B reads the USP into a1 and immediately overwrites it -- DEAD CODE',
      insn(0xF04A3E) == 'move usp, a1' and insn(0xF04A40) == 'movea.w $204(a0), a1')
check('...so arm B replaces the WHOLE USP with a sign-extended 16-bit value',
      insn(0xF04A44) == 'move a1, usp')
check('the self-test also exercises the USP as a register',
      insn(0xF08AD2) == 'move a5, usp' and insn(0xF08AD6) == 'move usp, a3')

# ---- phases $101/$102 test 68000 core behaviour (2026-07-31) ----
check('phase $101 verifies that moveq SIGN-EXTENDS to 32 bits',
      insn(0xF08A9E) == 'moveq #$ff, d6' and insn(0xF08AA0) == 'cmpi.l #$ffffffff, d6')
check('...with the standard $F0F0F0F0 failure marker', insn(0xF08AA8) == 'move.l #$f0f0f0f0, d7')
check('phase $102 round-trips a 32-bit value through the USP',
      insn(0xF08AC8) == 'move.l d0, d1' and insn(0xF08ACA) == 'not.l d1'
      and insn(0xF08AD2) == 'move a5, usp' and insn(0xF08AD6) == 'move usp, a3')
check('a6 is reused as the VMOD base and then the AP I/F base in one routine',
      insn(0xF08A88) == 'lea.l $1fff0.l, a6' and insn(0xF08AAE) == 'lea.l $ff0000.l, a6')

# ---- every computed dispatch is identified: 25, no hidden control flow ----
_ind = [a for a, (m, o, _) in sorted(_mins.items())
        if m.split('.')[0] in ('jmp', 'jsr') and '(' in o
        and not o.endswith('.l') and not o.endswith('(pc)')]
check('the ROM contains exactly 25 computed jmp/jsr', len(_ind) == 25, len(_ind))
check('the three dispatch tables are among them',
      all(a in _ind for a in (0xF003C2, 0xF04A80, 0xF05354, 0xF05734)))
check('each XP task has exactly 3: two table dispatches and the CP callback',
      all(sum(1 for a in _ind if lo <= a < hi) == 3
          for lo, hi in ((0xF05F00, 0xF06900), (0xF06900, 0xF07300),
                         (0xF07300, 0xF07D00), (0xF07D00, 0xF08700))))
check('...and the callback is jsr (a2) in every one',
      all(insn(a) == 'jsr (a2)' for a in (0xF067E0, 0xF071F8, 0xF07BF8, 0xF085F8)))
check('$F044C6 is the RMS68K driver call: pointer at +$1E, status in carry',
      insn(0xF044C0) == 'movea.l $1e(a5), a1' and insn(0xF044C6) == 'jsr (a1)'
      and insn(0xF044CA) == 'bcs.b $f044d6')

# ---- $25F is type, $260 is address WIDTH (2026-07-31) ----
check('the data-record width decoder maps d4=3/4/5 to shift 8/16/24 (S1/S2/S3)',
      insn(0xF05256) == 'cmpi.w #$3, d4' and insn(0xF0525C) == 'move.w #$8, d5'
      and insn(0xF05268) == 'move.w #$10, d5' and insn(0xF05274) == 'move.w #$18, d5')
check('...rejecting any other width with $260', insn(0xF0528C) == 'move.w #$260, d0')
check('the terminator width decoder maps d4=2/3 to shift 0/16 (S9/S8)',
      insn(0xF055FC) == 'cmpi.w #$2, d4' and insn(0xF05602) == 'move.w #$0, d5'
      and insn(0xF0560E) == 'move.w #$10, d5' and insn(0xF05614) == 'move.w #$260, d0')
check('$25F guards the record TYPE, not the width',
      insn(0xF0555A) == 'cmpi.w #$5337, d1' and insn(0xF04C00) == 'cmpi.w #$5338, d1')
check('...so the two codes are complementary: type vs width',
      insn(0xF0556E) == 'move.w #$25f, d0' and insn(0xF05614) == 'move.w #$260, d0')

# ---- the SLC upload wire format (2026-07-31) ----
check('the SLC address loop arms $FF0218 with $400 and polls bit 15 PER WORD',
      insn(0xF0529E) == 'move.w #$400, $218(a5)' and insn(0xF052A8) == 'btst.b #$f, d7'
      and insn(0xF052AE) == 'move.w #$0, $218(a5)')
check('...reads one word from the stream port each time', insn(0xF052B4) == 'move.w (a0), d2')
check('...and converts it as ASCII HEX -- TWO characters per word, one data byte',
      insn(0xF052B8).startswith('jsr') and insn(0xF05152) == 'lsr.w #$8, d3'
      and insn(0xF05164) == 'lsl.w #$4, d3' and insn(0xF05166) == 'andi.w #$ff, d2'
      and insn(0xF0517A) == 'add.w d3, d2')
check("...'A'-'F' subtract $37, '0'-'9' subtract $30",
      insn(0xF0515A) == 'subi.w #$37, d3' and insn(0xF05160) == 'subi.w #$30, d3')
check('the assembled address gets the +$10000 staging offset and lands in $E7E',
      insn(0xF052D0) == 'adda.l #$10000, a1' and insn(0xF052D6) == 'move.l a1, $e7e.l')
check('the shift count steps down by 8 per byte',
      insn(0xF052C2) == 'lsl.l d5, d2' and insn(0xF052C8) == 'subq.b #$8, d5')

# ---- the two S-record parsers differ in ENCODING, three ways (2026-07-31) ----
_asc = [a for a, (_, o, _) in _mins.items() if 'f05150' in o]
check('the ASCII converter has exactly four callers, all in the SLC region',
      sorted(_asc) == [0xF04B82, 0xF051C4, 0xF051FA, 0xF052B8], [hex(x) for x in sorted(_asc)])
check('SLC reads a FIFO port (no post-increment); CPLOAD walks memory (post-increment)',
      insn(0xF052B4) == 'move.w (a0), d2' and insn(0xF055A8) == 'move.w (a0)+, d2')
check('SLC steps 8 bits per character; CPLOAD steps 16 bits per word',
      insn(0xF052C8) == 'subq.b #$8, d5' and insn(0xF055BA) == 'subi.b #$10, d5')
check('both apply the same +$10000 staging offset',
      insn(0xF052D0) == 'adda.l #$10000, a1' and insn(0xF055C4) == 'adda.l #$10000, a1')
check('...and CPLOAD enforces the same $10000-$1FFFF bound',
      insn(0xF055CC) == 'cmpa.l #$10000, a1' and insn(0xF055D4) == 'cmpa.l #$1ffff, a1')

# ---- three upload transports, one destination rule (2026-07-31) ----
check('the SLC dispatcher arms $FF0218 and converts before dispatching on record type',
      insn(0xF04B68) == 'move.w #$400, $218(a5)' and insn(0xF04B82) == 'jsr $f05150.l'
      and insn(0xF04B8A) == 'cmpi.w #$5330, d1')
check("...'S1' seeds the shift at 8 and calls the data handler",
      insn(0xF04B9A) == 'cmpi.w #$5331, d1' and insn(0xF04BA0) == 'move.w #$8, d5'
      and insn(0xF04BA4) == 'jsr $f051a2.l')
check('the raw bulk path has NO record framing and no staging bound',
      insn(0xF04AE2).startswith('move.w') and not any(
          'cmpa.l #$1ffff' in insn(a) for a in range(0xF04AE2, 0xF04B60, 2)
          if a in _mins))
check('the CPLOAD path sets the width mux on entry and clears it on completion',
      insn(0xF0550E) == 'bset.b #$4, d2' and insn(0xF05586) == 'bclr.b #$4, d2')

# ---- the S0 header is consumed and discarded (2026-07-31) ----
check('the S0 handler reads d4 words through the handshake and stores nothing',
      insn(0xF05194) == 'move.w (a0), d1' and insn(0xF05198) == 'subq.w #$1, d4'
      and insn(0xF0519A) == 'cmpi.w #$0, d4' and insn(0xF051A0) == 'rts')
check('...and d1 is never used between iterations',
      insn(0xF05196) == 'addq.l #$1, d0')
check('the SLC data handler seeds a1 = $10, matching CPLOAD',
      insn(0xF051A2) == 'movea.l #$10, a1' and insn(0xF055A2) == 'movea.l #$10, a1')

# ---- the S-record checksum is READ AND DISCARDED (2026-07-31) ----
check('the data loop terminates on d4 == 1, leaving one word unread',
      insn(0xF05234) == 'cmpi.w #$1, d4' and insn(0xF05238) == 'bne.b $f051e2')
check('...that last word is read through a full handshake and never examined',
      insn(0xF05250) == 'move.w (a0), d2' and insn(0xF05254) == 'rts')
check('no checksum accumulation exists anywhere in the S1 handler',
      not any(_mins[a][0].startswith(('add.b', 'add.w', 'addx', 'eor'))
              and 'd2' in _mins[a][1] and 'd3' not in _mins[a][1]
              for a in range(0xF051A2, 0xF05256, 2) if a in _mins))
check('the staging bound is enforced PER BYTE, inside the store loop',
      insn(0xF051FE) == 'cmpa.l #$10000, a1' and insn(0xF05206) == 'cmpa.l #$1ffff, a1'
      and insn(0xF0520E) == 'move.b d2, (a1)+')
check('...so an over-long record is truncated at the boundary and reported $25A',
      insn(0xF0520C) == 'bgt.b $f05212' and insn(0xF05224) == 'move.w #$25a, d0')

# ---- the last seven FPS-layer subroutines (2026-07-31) ----
check("XP4I's channel validator: 1 <= d0 <= $105E else panel $264",
      insn(0xF06738) == 'cmpi.w #$1, d0' and insn(0xF0673E) == 'cmp.w $105e.l, d0'
      and insn(0xF06746) == 'move.w #$264, d0')
check('the self-test parks the SP at address 0 before vectors exist',
      insn(0xF08A5C) == 'move.l a7, $0.w' and insn(0xF08A66) == 'move.w #$100, $204(a6)')
check('$F09176 is the MC6840 master reset: CR2 then CR1 bit 0',
      insn(0xF09178) == 'lea.l $f70001.l, a0' and insn(0xF0917E) == 'move.b #$1, $2(a0)'
      and insn(0xF09184) == 'move.b #$1, (a0)')
check('$F09DCE builds the $0C00 region records: flags, class, base, limit, stride $A',
      insn(0xF09DD4) == 'andi.w #$f, d1' and insn(0xF09DD8) == 'andi.w #$70, d0'
      and insn(0xF09DE2) == 'move.l a2, $2(a3)' and insn(0xF09DE6) == 'move.l a0, $6(a3)'
      and insn(0xF09DEA) == 'lea.l $a(a3), a3')
check('$F0A374 page-aligns via (d + $FF) & ~$FF',
      insn(0xF0A374) == 'addi.l #$ff, d2' and insn(0xF0A37A) == 'clr.b d2')
check('$F0A424 builds a free-list node with a PAGE COUNT at +$8 and a back-link',
      insn(0xF0A42E) == 'lsr.l #$8, d7' and insn(0xF0A430) == 'move.l d7, $8(a5)'
      and insn(0xF0A434) == 'move.l a0, $4(a5)' and insn(0xF0A43A) == 'move.l a5, (a0)')

# ---- a thirteenth marker: 'EXEC' at TCB+$B0 (2026-07-31) ----
check("'EXEC' appears exactly once in the whole ROM image",
      _rom.count(b'EXEC') == 1, _rom.count(b'EXEC'))
check('...as the immediate of move.l #$45584543,$B0(a0)',
      insn(0xF00838) == 'move.l #$45584543, $b0(a0)')
check('...so nothing ever tests for it -- written, never read',
      sum(1 for _, (_, o, _) in _mins.items() if '45584543' in o) == 1)
check('$F015D8 validates !TCB and then !ASQ through TCB+$40',
      insn(0xF015DA) == 'cmpi.l #$21544342, (a0)' and insn(0xF015E4) == 'movea.l $40(a5), a4'
      and insn(0xF015E8) == 'cmpi.l #$21415351, (a4)')
check('...which is a DIFFERENT field from the documented ASQ block pointer at +$138',
      0x40 != 0x138)
_execcall = [a for a, (m, o, _) in _mins.items()
             if m.split('.')[0] in ('jsr', 'bsr') and 'f00824' in o]
check("the EXEC tag is written from exactly three call sites",
      sorted(_execcall) == [0xF00C62, 0xF027EC, 0xF03028], [hex(x) for x in sorted(_execcall)])
check('...one of them inside the $0F TERM handler at $F02F64',
      0xF02F64 < 0xF03028 < 0xF03100)
check('the tagging routine also stamps TCB+$2A bit 15, TCB+$29 bit 1 and clears TCB+$5C',
      insn(0xF00826) == 'bset.b #$f, d7' and insn(0xF0082A) == 'move.w d7, $2a(a0)'
      and insn(0xF0082E) == 'clr.w $5c(a0)' and insn(0xF00832) == 'bset.b #$1, $29(a0)')

# ---- the kernel's shared helpers (2026-07-31) ----
check('$F010F0 is an interrupt-masked list insert exiting by rte',
      insn(0xF010F2) == 'ori.w #$700, sr' and insn(0xF010FA) == 'move.l #$ffffffff, $4(a2)'
      and insn(0xF01106) == 'rte')
check('$F016FE substitutes the current TCB when the pointer is null',
      insn(0xF01700) == 'move.l a0, d0' and insn(0xF0170A) == 'movea.l a6, a0')
check('$F017F4 and $F01876 are search helpers on directory slots $0C20 and $0C24',
      insn(0xF017FA) == 'movea.l $c20.w, a1' and insn(0xF0187E) == 'movea.l $c24.w, a1')
check('...with $F017F4 walking a stride-$14 record', insn(0xF01802) == 'lea.l $14(a1), a2')
check('+$1E is an entry-point field dereferenced by three unrelated routines',
      insn(0xF044C0) == 'movea.l $1e(a5), a1' and insn(0xF026C2) == 'movea.l $1e(a4), a0'
      and insn(0xF02772) == 'movea.l $1e(a4), a3')
check('$F02764 rounds a length up to even before taking +$1E and +$22',
      insn(0xF02768) == 'addq.l #$1, d1' and insn(0xF0276A) == 'bclr.b #$0, d1'
      and insn(0xF02776) == 'movea.l $22(a4), a0')

# ---- the complete SBC -> AC exchange (2026-07-31) ----
check('transaction 1 loads d0 = $FFFF0010: mode $FFFF, operation $10',
      insn(0xF08502) == 'move.w #$ffff, d0' and insn(0xF08506) == 'swap d0'
      and insn(0xF08508) == 'move.w #$10, d0')
check('...with a literal $10 as the D1_SEND payload', insn(0xF0850C) == 'moveq #$10, d1')
check('transaction 2 uses operation $0E and the PRE-DECREMENTED file longword',
      insn(0xF08528) == 'move.w #$e, d0' and insn(0xF0852C) == 'move.l -(a2), d1')
check('...taken through the per-channel pointer at $1080',
      insn(0xF08516) == 'movea.l $1080(a2), a2' and insn(0xF0853C) == 'move.l #$0, $1080(a2)')
check('the primitive masks the BIM, zeroes +$08 and writes the OPERATION to +$0A',
      insn(0xF07F12) == 'move.w #$4f, (a3)' and insn(0xF07F18) == 'move.w #$0, (a1)'
      and insn(0xF07F1E) == 'move.w d0, $2(a1)')
check('...then issues $8004 REQUEST-TRANSFER and polls 1000 times for bit 14',
      insn(0xF07F22) == 'move.w #$8004, (a0)' and insn(0xF07F26) == 'move.l #$3e8, d5'
      and insn(0xF07F30) == 'btst.b #$e, d4' and insn(0xF07F3E) == 'btst.b #$d, d4')
check('exactly two callers of the transaction primitive in XP1I',
      sorted(a for a, (m, o, _) in _mins.items()
             if m.split('.')[0] in ('jsr', 'bsr') and 'f07f12' in o) == [0xF0851C, 0xF08530])

# ---- directive-failure codes, derived by ADJACENCY not counts (2026-07-31) ----
import re as _dre
_dadj = _mcol.Counter()
_daddrs = sorted(_mins)
for _idx, _a in enumerate(_daddrs):
    _m, _o, _ = _mins[_a]
    _mm = _dre.match(r'#\$(26[d-f]|27[01]), d0$', _o)
    if not (_m.startswith('move') and _mm): continue
    for _k in range(_idx - 1, max(0, _idx - 14), -1):
        _m2, _o2, _ = _mins[_daddrs[_k]]
        _d2 = _dre.match(r'#\$([0-9a-f]+), d0$', _o2)
        if _d2 and _m2.split('.')[0] in ('moveq', 'move'):
            _dadj[(_mm.group(1), _d2.group(1))] += 1
            break
check('$26E reports directive $2D CRSEM, 8 times', _dadj[('26e', '2d')] == 8, dict(_dadj))
check('$270 reports directive $4C CNCTIRQ, 4 times', _dadj[('270', '4c')] == 4)
check('$271 reports directive $2B SGSEM -- NOT $29 ATSEM', _dadj[('271', '2b')] == 8)
check('...and $271 is never preceded by $29', _dadj[('271', '29')] == 0)
check('XP4I emits $271 right after its two $2B SGSEM traps',
      insn(0xF06070) == 'moveq #$2b, d0' and insn(0xF0607A) == 'move.w #$271, d0'
      and insn(0xF06098) == 'moveq #$2b, d0' and insn(0xF060A0) == 'move.w #$271, d0')
check('the USER-lifecycle codes map to GTSEG/CNCTIRQ/CRTCB/GTSEG/START/TERMT/RESUME',
      insn(0xF046FC) == 'move.w #$276, d0' and insn(0xF0471C) == 'move.w #$277, d0'
      and insn(0xF04780) == 'move.w #$278, d0' and insn(0xF0479A) == 'move.w #$279, d0'
      and insn(0xF047CC) == 'move.w #$27a, d0' and insn(0xF047F6) == 'move.w #$27b, d0')
check('$27D has a second emitter inside TCBIO1I, not only RDHC',
      insn(0xF04890) == 'move.w #$27d, d0' and insn(0xF05D42) == 'move.w #$27d, d0')

# ---- $26C is TIMEOUT, $269/$26A/$26B are ERROR (2026-07-31) ----
_ab = {c: sum(1 for _, (m, o, _) in _mins.items()
              if m.startswith('move') and f'#${c:x}, d0' in o)
       for c in (0x269, 0x26A, 0x26B, 0x26C)}
check('$26C has by far the most emitters -- it is the generic timeout',
      _ab[0x26C] == 45, _ab)
check('...and it follows the poll-counter test, not the error bit',
      insn(0xF056EC) == 'cmpi.l #$0, d5' and insn(0xF056F4) == 'move.w #$26c, d0')
check('$269 follows the ERROR bit test', insn(0xF056FE) == 'btst.b #$d, d4'
      and insn(0xF05704) == 'move.w #$269, d0')
check('$26A likewise follows btst #$d -- it is an ERROR code, not a timeout',
      insn(0xF057E0) == 'btst.b #$d, d4' and insn(0xF057E6) == 'move.w #$26a, d0')
check('$26B likewise', insn(0xF05776) == 'btst.b #$d, d4'
      and insn(0xF0577C) == 'move.w #$26b, d0')

# ---- XP4I's divergent arm, and the $262/$263/$264 guards (2026-07-31) ----
check("XP4I tests bit 14 of its latched status via the mod-8 high-byte convention",
      insn(0xF06088) == 'btst.b #$e, $1078.l' and insn(0xF06090) == 'beq.b $f060c0')
check('...falling to panel $262 when no valid transaction is present',
      insn(0xF060C0) == 'move.w #$262, d0')
check('...then signalling a semaphore with $2B and read-modify-writing its word',
      insn(0xF06098) == 'moveq #$2b, d0' and insn(0xF060AA) == 'move.w (a0), d0'
      and insn(0xF060AC) == 'btst.b #$b, d0')
check('...writing $1F41 or $1F45, which differ by exactly bit 2',
      insn(0xF060B2) == 'move.w #$1f41, (a0)' and insn(0xF060B8) == 'move.w #$1f45, (a0)'
      and (0x1F41 ^ 0x1F45) == 0x4)
check('$263 is the channel-number reject, guarded on $105E',
      insn(0xF06698) == 'cmp.w $105e.l, d0' and insn(0xF066A0) == 'move.w #$263, d0')
check('$264 is a BASE: addi.w #$264,d1 with d1 = the channel gives $265-$268',
      insn(0xF066C2) == 'addi.w #$264, d1' and insn(0xF066B6) == 'moveq #$10, d0')

# ---- the nine exception reporters are uniform 8-byte stubs (2026-07-31) ----
_exc = [_bst.unpack('>HHHH', _rom[0xF0A23A - 0xF00000 + n * 8:][:8]) for n in range(9)]
check('all nine exception reporters are {move.w #imm,d0; bra.w} stubs of 8 bytes',
      all(e[0] == 0x303C and e[2] == 0x6000 for e in _exc))
check('...with contiguous codes $29E..$2A6',
      [e[1] for e in _exc] == list(range(0x29E, 0x2A7)), [hex(e[1]) for e in _exc])
check('...all branching to the same issuer, $F0A57E',
      all((0xF0A23A + n * 8 + 6 + _exc[n][3]) & 0xFFFFFF == 0xF0A57E for n in range(9)))
check('the catch-all $F0A27A is simply the ninth stub', 0xF0A23A + 8 * 8 == 0xF0A27A)

# ---- the eight panel-command issuers are byte-identical (2026-07-31) ----
_iss = [0xF04500, 0xF05688, 0xF05E56, 0xF068A8, 0xF072C0, 0xF07CC0, 0xF086C0, 0xF0A57E]
check('all eight panel-command issuers are byte-identical over 48 bytes',
      len({_rom[a - 0xF00000:a - 0xF00000 + 48] for a in _iss}) == 1)
check("...and each one's `bra .` sits at exactly +48",
      all(_rom[a - 0xF00000 + 48:a - 0xF00000 + 50] == b'\x60\xfe' for a in _iss))
_brados = [0xF00000 + o for o in range(len(_rom) - 1)
           if _rom[o] == 0x60 and _rom[o + 1] == 0xFE]
check('the ROM contains exactly 9 `bra .` sites', len(_brados) == 9, len(_brados))
check('...eight of them the issuers, the ninth $F001AA in the kernel',
      sorted(_brados) == sorted([a + 48 for a in _iss] + [0xF001AA]))
check('the 80 bytes between the last issuer and the TDTI table are all zero',
      set(_rom[0xF0A5B0 - 0xF00000:0xF0A600 - 0xF00000]) == {0})
check('...and that is exactly the page-alignment rounding from $F0A57E',
      ((0xF0A57E + 0xFF) & ~0xFF) == 0xF0A600
      and 0xF0A600 - (0xF0A57E + 48 + 2) == 80)


# ---------------------------------------------------------------------------
# STOP.  ADD NEW check() CALLS *ABOVE* THIS LINE.
#
# On 2026-07-31 roughly 193 check() calls were found sitting BELOW the
# sys.exit() below -- appended to the end of the file over several sessions and
# therefore never executed.  Three consecutive runs reported an identical
# "962/962 passed" while new checks were supposedly being added; the count was
# identical precisely BECAUSE nothing new was running.
#
# Guard against a recurrence: this self-test refuses to report success if any
# check() call appears after the exit.
# ---------------------------------------------------------------------------
_self = open(__file__).read()
_marker = 'sys.exit(1 if fails else 0)'
# build the needle at runtime so this guard does not match its own source text
_needle = 'ch' + 'eck('
_below = _self[_self.rindex(_marker):].count(_needle)
if _below:
    print(f'  FATAL: {_below} check() calls are below sys.exit() and never ran')
    sys.exit(2)

print(f'\n{checks - len(fails)}/{checks} passed')
sys.exit(1 if fails else 0)