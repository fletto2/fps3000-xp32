#!/usr/bin/env python3
"""
FPS-3000 ROM — second batch of 5 MC rounds.

Builds on the first 5-round campaign:
  • R1-R5 annotated 238 addresses with 96% model-agreement
  • This second batch uses different seeds, different region biases,
    and feeds the prior annotations back into the disassembly context
    so models can cite previous work
  • Mix: 3 cooperative + 2 adversarial (faster than GLM-5.1 reasoning)

Round plan:
  R6  cooperative  seed 11  bias toward TCBXP1I-XP4I region (F05F00-F08700)
  R7  cooperative  seed 22  bias toward MainInit/HardwareInit (F08700-F09BFF)
  R8  cooperative  seed 33  bias toward RTOSKernelInit (F09C00-F0A57E)
  R9  adversarial  seed 44  random across F04488-F0A57E
  R10 adversarial  seed 55  re-sample previously-DS-only addresses (challenge mode)

Annotations from prior rounds are inserted into the disassembly as
inline `;>>>> [Rn/agree] ...` comments, so model gets the running
knowledge as context.
"""

import urllib.request, json, time, random, re, sys, threading, queue, os

DS_KEY  = open('/home/fletto/src/claude/super68k/deepseek_api_key.txt').read().strip()
GLM_KEY = open('/home/fletto/src/claude/super68k/glm_api_key.txt').read().strip()

# Use the ANNOTATED disassembly so models see prior MC findings
ANNOTATED = open('/home/fletto/ext/src/claude/fps3000/fps3k_clean.asm').read().splitlines()
ALL_LINES = open('/tmp/fps3k_code_lines.txt').read().splitlines()
ADDR_INDEX = {}
for i, l in enumerate(ANNOTATED):
    m = re.match(r'^  (f0[0-9a-f]{4}):', l)
    if m: ADDR_INDEX[m.group(1)] = i

# Track addresses already annotated to avoid wasted re-queries
PRIOR_ANNOT_ADDRS = set()
with open('/tmp/fps3k_annotations_cooperative.txt') as f:
    for line in f:
        m = re.match(r'^0x(f0[0-9a-f]{4})', line)
        if m: PRIOR_ANNOT_ADDRS.add(m.group(1))

# Existing addresses from the salvaged adversarial R1
try:
    with open('/tmp/fps3k_annotations_adversarial.txt') as f:
        for line in f:
            m = re.match(r'^0x(f0[0-9a-f]{4})', line)
            if m: PRIOR_ANNOT_ADDRS.add(m.group(1))
except FileNotFoundError:
    pass

print(f'Prior annotated addresses: {len(PRIOR_ANNOT_ADDRS)}', file=sys.stderr)

# Per-round configuration
ROUNDS = [
    (6,  11, 'cooperative',  ('f05[fF]', 'f06', 'f07', 'f08[0-6]')),  # TCBXP4I,3I,2I,1I region
    (7,  22, 'cooperative',  ('f08[7-9a-fA-F]', 'f09[0-9a-bA-B]')),    # init/diagnostics
    (8,  33, 'cooperative',  ('f09[c-fC-F]', 'f0a')),                    # RTOSKernelInit
    (9,  44, 'adversarial',  None),                                      # random across all
    (10, 55, 'cooperative',  None),                                      # all (broad sweep)
]

SAMPLES_PER_ROUND = 40
CTX_BEFORE, CTX_AFTER = 12, 12
BATCH_SIZE = 10

HARDWARE_CONTEXT = open('/home/fletto/ext/src/claude/fps3000/mc_fps3k.py').read()
# Extract the HARDWARE_CONTEXT triple-quoted block
m = re.search(r'HARDWARE_CONTEXT\s*=\s*"""(.*?)"""', HARDWARE_CONTEXT, re.DOTALL)
HARDWARE_CONTEXT = m.group(1) if m else ""


def api_call(url, key, model, messages, max_tok=4000, timeout=180):
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


def biased_sample(seed, n, focus_patterns=None):
    random.seed(seed)
    if focus_patterns:
        bag = [l for l in ALL_LINES if any(re.match(r'^  '+p, l) for p in focus_patterns)]
    else:
        bag = ALL_LINES
    # Skip lines we already have a confirmed annotation for, with 60% bias
    fresh = [l for l in bag
             if not any(addr in l for addr in PRIOR_ANNOT_ADDRS)]
    n_fresh = int(n * 0.7)
    n_replicate = n - n_fresh
    s_fresh = random.sample(fresh, min(n_fresh, len(fresh))) if fresh else []
    s_repl  = random.sample(bag, min(n_replicate, len(bag)))
    return (s_fresh + s_repl)[:n]


def extract_ctx(sample_line):
    m = re.match(r'^  (f0[0-9a-f]{4}):', sample_line)
    if not m: return None, None
    addr = m.group(1)
    idx = ADDR_INDEX.get(addr)
    if idx is None: return addr, sample_line
    start = max(0, idx - CTX_BEFORE)
    end   = min(len(ANNOTATED), idx + CTX_AFTER + 1)
    block = []
    for i in range(start, end):
        marker = '>>>>' if i == idx else '    '
        block.append(f'{marker} {ANNOTATED[i]}')
    return addr, '\n'.join(block)


DOMAIN_KEYWORDS = {
    'xp32','xp-32','xpsel','xprun','xpwait','xpstat','xpdmar','xtmdma','xpisnc',
    'panel','xltr','wcs','microcode','channel','tcbxp','tcbrdhc','tcbio',
    'apif','ap i/f','am29116','sequencer','arith','exec card','exec','am2168',
    'rms68k','tcb','ccb','asq','tst','dly','vct','gst','ust','iov','idv','pat','udr',
    'tdti','task','marker','tag',
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


def build_batch_prompt(batch, mode='cooperative', prior=None):
    sections = []
    for i, (addr, ctx) in enumerate(batch):
        sec = f"--- Sample {i+1}/{len(batch)}  (address 0x{addr}) ---\n{ctx}\n"
        if mode == 'adversarial' and prior:
            p = prior.get(i, '')
            if p: sec += f"\nPRIOR ANSWER (review/refute/refine): {p}\n"
        sections.append(sec)
    if mode == 'adversarial':
        instr = ("For each sample, the PRIOR ANSWER may be wrong, vague, or right. "
                 "Critically evaluate it. If wrong, give the correct specific purpose. "
                 "If vague, sharpen with specific names. If right, restate more precisely. "
                 "Cite FPS-3000 hardware. If data not code, say 'DATA'. "
                 "Output:\n  S<N>: <purpose>\n\n")
    else:
        instr = ("Identify in 1-2 sentences the specific purpose of the >>>> instruction "
                 "in the FPS-3000 ROM. Reference a concrete subsystem, register, function, "
                 "algorithm, or selftest subtest. Be specific. If you cannot, say 'UNKNOWN' "
                 "or 'DATA'. The disassembly already includes prior MC annotations as "
                 "`;>>>>` lines — cite them as appropriate. Output one line per sample:\n"
                 "  S<N>: <purpose>\n\n")
    return HARDWARE_CONTEXT + "\n\n" + instr + "\n".join(sections)


def run_round(round_num, seed, mode, focus):
    samples = biased_sample(seed, SAMPLES_PER_ROUND, focus_patterns=focus)
    ctx_list = [extract_ctx(s) for s in samples]
    ctx_list = [c for c in ctx_list if c[0]]
    batches = [ctx_list[i:i+BATCH_SIZE] for i in range(0, len(ctx_list), BATCH_SIZE)]

    glm_results = {}
    ds_results  = {}
    offset = 0
    for b in batches:
        if mode == 'adversarial':
            # 2-stage: DS-coop, then GLM-challenge (skip 3rd defense for speed)
            p1 = build_batch_prompt(b, mode='cooperative')
            ds_txt, _ = ask_deepseek(p1)
            ds_p = score_and_parse(ds_txt, b)
            prior = {i: ds_p.get(i, ('', False, 0))[0] for i in range(len(b))}
            p2 = build_batch_prompt(b, mode='adversarial', prior=prior)
            glm_txt, _ = ask_glm(p2)
            glm_p = score_and_parse(glm_txt, b)
            for i, (addr, _) in enumerate(b):
                gi = offset + i
                ds_results[gi]  = (addr,) + ds_p.get(i, ('', False, 0))
                glm_results[gi] = (addr,) + glm_p.get(i, ('', False, 0))
        else:
            prompt = build_batch_prompt(b, mode='cooperative')
            q = queue.Queue()
            def _glm(): q.put(('glm',) + ask_glm(prompt))
            def _ds():  q.put(('ds',)  + ask_deepseek(prompt))
            t1 = threading.Thread(target=_glm); t1.start()
            t2 = threading.Thread(target=_ds);  t2.start()
            t1.join(timeout=200); t2.join(timeout=200)
            got = {}
            while not q.empty():
                k, txt, el = q.get()
                got[k] = (txt, el)
            glm_txt = got.get('glm',('',0))[0]
            ds_txt  = got.get('ds', ('',0))[0]
            glm_p = score_and_parse(glm_txt, b)
            ds_p  = score_and_parse(ds_txt, b)
            for i, (addr, _) in enumerate(b):
                gi = offset + i
                glm_results[gi] = (addr,) + glm_p.get(i, ('', False, 0))
                ds_results[gi]  = (addr,) + ds_p.get(i, ('', False, 0))
        offset += len(b)

    yes_count, both_count = 0, 0
    accepted = []
    for gi in range(len(ctx_list)):
        ga = glm_results.get(gi, (None,'',False,0))
        da = ds_results.get(gi,  (None,'',False,0))
        addr = ga[0] or da[0]
        g_yes, d_yes = ga[2], da[2]
        if g_yes or d_yes: yes_count += 1
        if g_yes and d_yes: both_count += 1
        if g_yes or d_yes:
            if g_yes and d_yes:
                pick = ga if ga[3] >= da[3] else da
                tag = 'BOTH'
            else:
                pick = ga if g_yes else da
                tag = 'GLM' if g_yes else 'DS'
            accepted.append((addr, f'R{round_num}', pick[1], tag))
    pct = yes_count*100//len(ctx_list) if ctx_list else 0
    bpct = both_count*100//len(ctx_list) if ctx_list else 0
    return pct, bpct, accepted, len(ctx_list)


def main():
    out = open('/tmp/fps3k_annotations_round2.txt', 'w')
    out.write('# FPS-3000 MC annotations — round 2 (R6-R10)\n')
    summary = []
    for rn, seed, mode, focus in ROUNDS:
        t0 = time.time()
        try:
            pct, bpct, acc, total = run_round(rn, seed, mode, focus)
        except Exception as e:
            print(f'[R{rn} seed={seed}] FAILED: {e}', flush=True)
            continue
        el = time.time() - t0
        print(f'[R{rn} seed={seed} mode={mode}] {total} samples, '
              f'YES={pct}%, BOTH={bpct}%, annot={len(acc)}, {el:.0f}s', flush=True)
        summary.append((rn, seed, mode, pct, bpct, len(acc), el))
        for addr, rtag, text, tag in acc:
            out.write(f'0x{addr} [{rtag} {tag}] {text}\n')
        out.flush()
    out.close()
    print('\n== SUMMARY ==')
    print(f'{"Round":<6} {"Seed":<6} {"Mode":<13} {"YES%":<6} {"BOTH%":<7} {"Annots":<7} {"sec":<5}')
    for r, s, m, p, b, a, e in summary:
        print(f'R{r:<5} {s:<6} {m:<13} {p:<6} {b:<7} {a:<7} {e:.0f}')


if __name__ == '__main__':
    main()
