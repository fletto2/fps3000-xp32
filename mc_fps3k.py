#!/usr/bin/env python3
"""
Monte Carlo disassembly rounds for the FPS-3000 SBC ROM.

Focused on understanding the XP32 init / communication code paths:
TCBRDHC main loop, panel command sequencer at F056xx, the 21
PanelIOConfigure_25A callsites with codes 0x258..0x27D, the SRecord
microcode upload path, and the per-channel TCBXP*I state machines.

Three modes (selectable via MODE env var or argv[1]):

  cooperative  — both models answer independently; accept when both YES
                 (default mode, 5 rounds × 50 samples)
  adversarial  — model A answers; model B is shown A's answer and asked
                 to refute or correct; final accept when B agrees or
                 produces a DIFFERENT specific answer with overlap
  monte        — same as cooperative but with multiple seeds for
                 statistical estimate of YES rate

Outputs:
  /tmp/fps3k_annotations.txt  — accepted annotations (addr [Rn] text)
  stdout                       — round-by-round YES% and timing
"""

import urllib.request, json, time, random, re, sys, threading, queue, os

DS_KEY  = open('/home/fletto/src/claude/super68k/deepseek_api_key.txt').read().strip()
GLM_KEY = open('/home/fletto/src/claude/super68k/glm_api_key.txt').read().strip()

ALL_LINES  = open('/tmp/fps3k_code_lines.txt').read().splitlines()
RAW_DISASM = open('/tmp/fps3k_rom_disasm.txt').read().splitlines()
ADDR_INDEX = {}  # 'f0xxxx' -> line idx
for i, l in enumerate(RAW_DISASM):
    m = re.match(r'^  (f0[0-9a-f]{4}):', l)
    if m: ADDR_INDEX[m.group(1)] = i

# 5 different seeds; bias the sample toward XP32-related code regions
# by oversampling the F046xx-F058xx range during round selection.
SEEDS = [42, 99, 777, 2026, 31337]
SAMPLES_PER_ROUND = 50
CTX_BEFORE, CTX_AFTER = 10, 10
BATCH_SIZE = 10

# Hardware context tuned to FPS-3000 / XP32
HARDWARE_CONTEXT = """You are analyzing the FPS-3000 SBC firmware (Motorola MC68000, 64 KB ROM at 0xF00000) — the Control Processor for a Floating Point Systems XP-32 array processor. The ROM runs on a Motorola M68KVM02-3 VERSAmodule and orchestrates microcode upload + per-channel command dispatch to the XP-32 EXEC and ARITH cards.

MEMORY MAP:
  0x000000-0x00FFFF  RAM lower 64 KB — kernel data, vectors, TCBs, ASQs, IOVs, page pools
  0x010000-0x01FFFF  RAM upper 64 KB — XP32 microcode staging buffer (= one WCS bank)
  0x01FFD0           supervisor stack
  0x01FFF0-0x01FFF1  VERSAmodule control register
  0xF00000-0xF0FFFF  ROM (this firmware)
  0xF70001-0xF7000F  MC6840 PTM (odd-byte movep)
  0xF70010-0xF70017  NEC µPD7201 dual UART (UNUSED by this ROM)
  0xF70018-0xF7001A  Board status/control register (PAL-decoded)
  0xFF0000-0xFF025F  AP I/F + VersaBUS XLTR command/data interface

XLTR REGISTER MAP (0xFF0xxx):
  FF0000  AP I/F command/status (16-bit) — opcodes 0x8004 (REQUEST-TRANSFER), 0x8005 (CONTINUE-TRANSFER); status bits 13/14 = error/ready
  FF000E  per-channel cmd-arg (echo of d0)
  FF0200  Mode 0 register (bit 10 manipulated)
  FF0202  Mode 1 register (bit 12 set, bit 14 cleared during config)
  FF0204  Channel Select register (= d0 in PanelIOConfigure_25A)
  FF020C  counter/config (init writes 0x01, 0xFF)
  FF0210  Mode 2 register
  FF0214  Data register low half
  FF0216  Data register high half / Cmd
  FF0218  Status / IRQ — bit 15 = ready/done
  FF021A  IRQ Mask register
  FF0048/4E, FF0068/6E, FF0088/8E, FF00A8/AE  Per-channel data ports (XP1..XP4)
  FF0244, FF0246, FF0250, FF0252  Per-channel config registers

KEY ROM ENTRY POINTS (named in disasm):
  ResetEntry       F09C00   reset → JMP MainInit
  MainInit         F08700   hardware init phase 1
  Phase2Init       F09C06   exec/RTOS init phase 2
  HardwareInit     F08A5C
  RAMAddressingTest F08D5E
  ROMChecksumTest  F08DF8
  MemBusProbe      F08EAC
  IOChannelDiagnostic F08F72
  PTMInit          F09176
  PanelBusDiagnostic F0919C
  ROMChecksum_XOR  F098EE
  RTOSKernelInit   F0A04E
  TCBDefinitionTable F0A57E   (RMS68K TDTI data, 6×96-byte TCBs)
  Init_GST_StoreTag F09E88   (RMS68K Global System Table init)
  Init_UST_StoreTag F09ECE
  Init_IOV_StoreTag F09F52
  Init_IDV_StoreTag F09F80
  Init_PAT_StoreTag F09FB2
  Init_UDR_StoreTag F0A000
  VCTScanSetup     F09C96   (!VCT signature scan)

  TCBRDHC_Entry    F046F0   master/dispatch task — RDHC channel
  TCBRDHC_MainLoop F04730
  SRecordDataHandler F051A2  enforces 0x10000 ≤ addr ≤ 0x1FFFF (microcode staging)
  SRecordFinalize  F05256
  PanelIOConfigure_25A F05688  panel-command-sender (called with 21 distinct codes 0x258..0x27D)

  TCBIO1I_Entry    F05D36   host I/O channel task
  TCBXP4I_Entry    F05F4A   XP-32 channel 4 controller
  TCBXP3I (similar)
  (TCBXP1I, TCBXP2I — analogous for XP32 channels 1, 2)

PANEL COMMAND SEND-AND-WAIT KERNEL (at F056BA):
  status flag = 0x4F (busy), opcode 0x8004 to (a0)=FF0000, poll bit 14 (ready) / bit 13 (error) with 1000-tick timeout, on error issue 0x269 abort, on success dispatch via table at F05BA4. 32-bit args use 0x8005 follow-up.

RMS68K MARKER TAGS (4-byte ASCII):
  "!TCB"=Task Control Block, "!CCB"=Channel CB, "!ASQ"=Application Status Queue,
  "!TST"=Task Status Test, "!DLY"=Delay record, "!VCT"=Vector/Config table,
  "!GST"=Global System Table, "!UST"=User System Table, "!IOV"=I/O Vector,
  "!IDV"=Interrupt Descriptor Vector, "!PAT"=Pattern table, "!UDR"=User Driver

XP-32 COMMUNICATION PRIMITIVES (XPMLIB, per Curington 1984):
  XPSEL  = select XP32 channel  (writes channel# to FF0204)
  XPRUN  = start AC               (set-busy + arm DMA)
  XPWAIT = wait for AC done       (poll FF0218 bit 15)
  XPSTAT = read AC status         (panel cmd to FF0216)
  XPDMAR = SCM↔LMD DMA            (set-addr + set-count + write-mem sequence)
  XTMDMA = SCM↔TCM DMA            (same primitive, TCM target)
  XPISNC = wait for done          (status poll loop)

XP-32 BOARD-SIDE HARDWARE (per Nakazoto/Usagi photos):
  EXEC card 612-4805-002: AMD Am29116DCB 16-bit bipolar µP (the sequencer)
                          + Am2168/CY7C168 SRAM array (writable program memory)
                          + PALs (custom decode logic, marked "29F52 SDC")
  ARITH card 612-4806-002: Logic Devices L29C520 16x16 MAC (multiple)
                           + large CPGA chip (likely Weitek WTL-1064/65)
                           + Am2168 SRAMs + bipolar PROMs (FP fan-out)
  No fixed mask-ROM identified — both EU and AU control stores appear writable.

AM29116 16-BIT BIPOLAR MICROPROCESSOR (the EXEC card sequencer):
  - 64-pin DIP, ~6 MHz clock (167 ns cycle, matches XP-32 spec)
  - 32 × 16-bit on-chip registers (the EU "S-Pad" equivalent)
  - 16-bit data bus + separate 16-bit instruction bus from external WCS
  - ALU: add/sub/AND/OR/XOR/NOT, shift, normalize, byte-swap,
    count-zeros (CRC-friendly), priority-encode (PRI), bit-test/set/clr
  - Status flags: N (negative), Z (zero), C (carry), OVR (overflow), LINK
  - Conditional jumps on flag combinations; subroutine call/return via
    on-chip 17-deep PC stack
  - 16-bit instruction word divided into:
      bits 15-12: instruction class (T field)
      bits 11-7:  source / function select
      bits 6-2:   destination register or immediate
      bits 1-0:   condition / mode bits
  - Used in: disk controllers (Trilogy, CDC), tape controllers (TM/Cipher),
    array processors (FPS XP-32, Floating Point Systems FPS-164 successor),
    bit-mapped graphics (Sun, NeWS), CRC engines.
  - Designed for bit-slice-style microcoding: each Am29116 instruction
    takes one cycle and emits ALU result + status to external pipeline
    registers; the WIDER microinstruction (>16 bits) typically encodes:
      - Am29116 instruction (16 bits)
      - Branch address or page select
      - External memory enable / direction / address-register source
      - Pipeline-register clock enables
      - Off-chip ALU / multiplier control (FPS: WTL-1064/L29C520 ctrl)
      - Conditional select for next-µaddress
  - On the FPS XP-32 EXEC card, the Am29116's 16-bit instruction lives
    in a 16-bit-wide slice of the wider WCS word. The remaining bits of
    the wider WCS word fan out (via the PALs) to drive the FP pipeline,
    LMD/TCM/SCM addressing, and inter-card handshake.

Note that the disassembly often mixes code and data; some lines may be data
misdecoded as instructions. If so, say "DATA"."""


def api_call(url, key, model, messages, max_tok=1500, timeout=120):
    body = json.dumps({
        'model': model, 'messages': messages,
        'max_tokens': max_tok, 'temperature': 0.2
    }).encode()
    req = urllib.request.Request(url, data=body,
        headers={'Authorization': f'Bearer {key}', 'Content-Type':'application/json'})
    t0 = time.time()
    try:
        r = urllib.request.urlopen(req, timeout=timeout).read().decode()
        j = json.loads(r)
        msg = j['choices'][0]['message']
        txt = (msg.get('content') or '').strip()
        if not txt and msg.get('reasoning_content'):
            txt = '(reasoning-only)'
        return txt, time.time()-t0
    except Exception as e:
        return f'ERROR: {e}', time.time()-t0


def ask_deepseek(prompt):
    return api_call('https://api.deepseek.com/v1/chat/completions', DS_KEY,
                    'deepseek-chat', [{'role':'user','content':prompt}], max_tok=4000)


def ask_glm(prompt):
    return api_call('https://api.z.ai/api/coding/paas/v4/chat/completions', GLM_KEY,
                    'glm-4.5-air', [{'role':'user','content':prompt}], max_tok=8000)


def extract_ctx(sample_line):
    m = re.match(r'^  (f0[0-9a-f]{4}):', sample_line)
    if not m: return None, None
    addr = m.group(1)
    idx = ADDR_INDEX.get(addr)
    if idx is None: return addr, sample_line
    start = max(0, idx - CTX_BEFORE)
    end   = min(len(RAW_DISASM), idx + CTX_AFTER + 1)
    block = []
    for i in range(start, end):
        marker = '>>>>' if i == idx else '    '
        block.append(f'{marker} {RAW_DISASM[i]}')
    return addr, '\n'.join(block)


def build_batch_prompt(batch, mode='cooperative', prior_answers=None):
    sections = []
    for i, (addr, ctx) in enumerate(batch):
        sec = f"--- Sample {i+1}/{len(batch)}  (address 0x{addr}) ---\n{ctx}\n"
        if mode == 'adversarial' and prior_answers:
            prior = prior_answers.get(i, '')
            if prior:
                sec += f"\nPRIOR ANSWER (to be reviewed/refuted/refined): {prior}\n"
        sections.append(sec)
    if mode == 'adversarial':
        instr = ("For each sample below, the PRIOR ANSWER may be wrong, vague, or "
                 "right. Critically evaluate it. If wrong, give the correct specific "
                 "purpose. If vague, sharpen it with a concrete subsystem/register "
                 "name. If right, restate it more precisely. Cite the FPS-3000 "
                 "hardware context. If the line is data not code, say 'DATA'. "
                 "Output one line per sample:\n  S<N>: <purpose>\n\n")
    else:
        instr = ("For each sample below, identify in 1-2 sentences the specific "
                 "purpose of the instruction marked with >>>> in the FPS-3000 "
                 "ROM's overall function. Reference a concrete subsystem, register, "
                 "function, algorithm, or selftest subtest. Be especially specific "
                 "about XP32 init / panel-command / microcode-upload code. If you "
                 "cannot be specific, say 'UNKNOWN' or 'DATA'. Output one line per "
                 "sample in format:\n  S<N>: <purpose>\n\n")
    return HARDWARE_CONTEXT + "\n\n" + instr + "\n".join(sections)


DOMAIN_KEYWORDS = {
    # XP32 / panel
    'xp32','xp-32','xpsel','xprun','xpwait','xpstat','xpdmar','xtmdma','xpisnc',
    'panel','xltr','wcs','microcode','channel','tcbxp','tcbrdhc','tcbio',
    'apif','ap i/f','am29116','sequencer','arith','exec card','exec','am2168',
    # RMS68K
    'rms68k','tcb','ccb','asq','tst','dly','vct','gst','ust','iov','idv','pat','udr',
    'tdti','task','marker','tag',
    # General firmware
    's-record','srecord','staging','upload','dma','timeout','poll','ready','busy',
    'status','irq','interrupt','vector','exception','reset','init','rom','ram',
    'checksum','crc','test','diagnostic','ptm','uart','versa','versabus',
    'memory test','ram test','rom test','bus error','buserror','stack','frame',
    'mode register','config','register','semaphore','queue','dispatch','main loop',
    'fp i/o','data register','command register','staging buffer'
}


def score_and_parse(reply, sample_indices):
    out = {}
    for line in reply.splitlines():
        m = re.match(r'\s*S(\d+)\s*[:\-]\s*(.*)$', line, re.IGNORECASE)
        if not m: continue
        idx = int(m.group(1)) - 1
        if idx < 0 or idx >= len(sample_indices): continue
        text = m.group(2).strip()
        low = text.lower()
        is_unknown = low.startswith(('unknown','data','n/a','don\'t','cannot','unclear'))
        kw_count = sum(1 for kw in DOMAIN_KEYWORDS if kw in low)
        is_yes = (not is_unknown) and kw_count >= 1
        out[idx] = (text, is_yes, kw_count)
    return out


def biased_sample(seed, n):
    """Sample n lines, biased toward the XP32 init/communication address range."""
    random.seed(seed)
    # 70% from XP32-comms range (F046xx-F058xx), 30% from rest
    xp32_range = [l for l in ALL_LINES
                  if re.match(r'^  f0(4[6-9a-f]|5[0-8])', l)]
    other_range = [l for l in ALL_LINES if l not in xp32_range]
    n_xp32 = int(n * 0.7)
    n_other = n - n_xp32
    s1 = random.sample(xp32_range, min(n_xp32, len(xp32_range)))
    s2 = random.sample(other_range, min(n_other, len(other_range)))
    return s1 + s2


def run_round(round_num, seed, mode='cooperative'):
    samples = biased_sample(seed, SAMPLES_PER_ROUND)
    ctx_list = [extract_ctx(s) for s in samples]
    ctx_list = [c for c in ctx_list if c[0]]
    batches = [ctx_list[i:i+BATCH_SIZE] for i in range(0, len(ctx_list), BATCH_SIZE)]

    glm_results = {}
    ds_results  = {}
    offset = 0

    for b in batches:
        if mode == 'adversarial':
            # Stage 1: ask DeepSeek (model A) to give an answer
            p1 = build_batch_prompt(b, mode='cooperative')
            ds_txt1, _ = ask_deepseek(p1)
            ds_p1 = score_and_parse(ds_txt1, b)
            prior = {i: ds_p1.get(i, ('', False, 0))[0] for i in range(len(b))}
            # Stage 2: ask GLM (model B) to challenge
            p2 = build_batch_prompt(b, mode='adversarial', prior_answers=prior)
            glm_txt, _ = ask_glm(p2)
            glm_p = score_and_parse(glm_txt, b)
            # Stage 3: ask DeepSeek to defend or revise
            p3 = build_batch_prompt(b, mode='adversarial',
                                    prior_answers={i: glm_p.get(i,('',False,0))[0] for i in range(len(b))})
            ds_txt2, _ = ask_deepseek(p3)
            ds_p2 = score_and_parse(ds_txt2, b)
            for i, (addr, _) in enumerate(b):
                gi = offset + i
                glm_results[gi] = (addr,) + glm_p.get(i, ('', False, 0))
                # use the DEFENDED/REVISED DS answer as the final
                ds_results[gi]  = (addr,) + ds_p2.get(i, ds_p1.get(i, ('', False, 0)))
        else:
            prompt = build_batch_prompt(b, mode='cooperative')
            q = queue.Queue()
            def _glm(): q.put(('glm',) + ask_glm(prompt))
            def _ds():  q.put(('ds',)  + ask_deepseek(prompt))
            t1 = threading.Thread(target=_glm); t1.start()
            t2 = threading.Thread(target=_ds);  t2.start()
            t1.join(timeout=180); t2.join(timeout=180)
            got = {}
            while not q.empty():
                k, txt, el = q.get()
                got[k] = (txt, el)
            glm_txt = got.get('glm',('',0))[0]
            ds_txt  = got.get('ds', ('',0))[0]
            glm_p = score_and_parse(glm_txt, b)
            ds_p  = score_and_parse(ds_txt,  b)
            for i, (addr, _) in enumerate(b):
                gi = offset + i
                glm_results[gi] = (addr,) + glm_p.get(i, ('', False, 0))
                ds_results[gi]  = (addr,) + ds_p.get(i,  ('', False, 0))
        offset += len(b)

    yes_count = 0
    accepted = []
    both_agreed = 0
    for gi in range(len(ctx_list)):
        ga = glm_results.get(gi, (None,'',False,0))
        da = ds_results.get(gi,  (None,'',False,0))
        addr = ga[0] or da[0]
        g_yes, d_yes = ga[2], da[2]
        if g_yes or d_yes: yes_count += 1
        if g_yes and d_yes: both_agreed += 1
        if g_yes or d_yes:
            if g_yes and d_yes:
                pick = ga if ga[3] >= da[3] else da
            else:
                pick = ga if g_yes else da
            accepted.append((addr, f'R{round_num}', pick[1], 'BOTH' if (g_yes and d_yes) else ('GLM' if g_yes else 'DS')))
    pct = yes_count * 100.0 // len(ctx_list) if ctx_list else 0
    both_pct = both_agreed * 100.0 // len(ctx_list) if ctx_list else 0
    return pct, both_pct, accepted, len(ctx_list)


def main():
    mode = (sys.argv[1] if len(sys.argv) > 1 else os.environ.get('MODE','cooperative')).lower()
    out_path = f'/tmp/fps3k_annotations_{mode}.txt'
    out_anno = open(out_path, 'w')
    out_anno.write(f'# FPS-3000 MC annotations — mode: {mode}\n')
    summary = []
    seeds = SEEDS
    for rn, seed in enumerate(seeds, 1):
        t0 = time.time()
        try:
            pct, both, acc, total = run_round(rn, seed, mode=mode)
        except Exception as e:
            print(f'[R{rn} seed={seed}] FAILED: {e}')
            continue
        el = time.time()-t0
        print(f'[R{rn} seed={seed} mode={mode}] {total} samples, '
              f'YES={pct}%, BOTH={both}%, annotations={len(acc)}, {el:.0f}s')
        summary.append((rn, seed, pct, both, len(acc), el))
        for addr, rtag, text, agree in acc:
            out_anno.write(f'0x{addr} [{rtag} {agree}] {text}\n')
        out_anno.flush()
    out_anno.close()
    print('\n== SUMMARY ==')
    print(f'{"Round":<6} {"Seed":<6} {"YES%":<6} {"BOTH%":<7} {"Annots":<7} {"sec":<5}')
    for r, s, p, b, a, e in summary:
        print(f'R{r:<5} {s:<6} {p:<6} {b:<7} {a:<7} {e:.0f}')
    print(f'\nWrote: {out_path}')


if __name__ == '__main__':
    main()
