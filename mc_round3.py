#!/usr/bin/env python3
"""
FPS-3000 ROM — third batch of 5 MC rounds.

Goals:
  - No region bias — sample uniformly across the ENTIRE custom-code
    range (F04488-F0FFFF, 6485 instruction lines)
  - Skip addresses already annotated in R1-R10 to maximize new coverage
  - Mix cooperative + adversarial; feed prior annotations as context
  - Use fresh seeds (100, 200, 300, 400, 500)

Round plan:
  R11 cooperative seed 100  random across all
  R12 cooperative seed 200  random across all
  R13 adversarial seed 300  random across all
  R14 cooperative seed 400  random across all
  R15 cooperative seed 500  random across all
"""
import urllib.request, json, time, random, re, sys, threading, queue, os

DS_KEY  = open('/home/fletto/src/claude/super68k/deepseek_api_key.txt').read().strip()
GLM_KEY = open('/home/fletto/src/claude/super68k/glm_api_key.txt').read().strip()

ANNOTATED = open('/home/fletto/ext/src/claude/fps3000/fps3k_clean.asm').read().splitlines()
ALL_LINES = open('/tmp/fps3k_code_lines.txt').read().splitlines()
ADDR_INDEX = {}
for i, l in enumerate(ANNOTATED):
    m = re.match(r'^  (f0[0-9a-f]{4}):', l)
    if m: ADDR_INDEX[m.group(1)] = i

# All addresses with prior annotations
PRIOR = set()
for path in ['/tmp/fps3k_annotations_cooperative.txt',
             '/tmp/fps3k_annotations_adversarial.txt',
             '/tmp/fps3k_annotations_round2.txt']:
    if os.path.exists(path):
        with open(path) as f:
            for line in f:
                m = re.match(r'^0x(f0[0-9a-f]{4})', line)
                if m: PRIOR.add(m.group(1))

print(f'Prior annotated addresses: {len(PRIOR)}', file=sys.stderr)

ROUNDS = [
    (11, 100, 'cooperative'),
    (12, 200, 'cooperative'),
    (13, 300, 'adversarial'),
    (14, 400, 'cooperative'),
    (15, 500, 'cooperative'),
]
SAMPLES_PER_ROUND = 40
CTX_BEFORE, CTX_AFTER = 12, 12
BATCH_SIZE = 10

# Reuse hardware context from mc_fps3k.py
src = open('/home/fletto/ext/src/claude/fps3000/mc_fps3k.py').read()
m = re.search(r'HARDWARE_CONTEXT\s*=\s*"""(.*?)"""', src, re.DOTALL)
HARDWARE_CONTEXT = m.group(1) if m else ""


def api_call(url, key, model, messages, max_tok=4000, timeout=180):
    body = json.dumps({'model': model, 'messages': messages,
                       'max_tokens': max_tok, 'temperature': 0.2}).encode()
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

def ask_deepseek(p):
    return api_call('https://api.deepseek.com/v1/chat/completions', DS_KEY,
                    'deepseek-chat', [{'role':'user','content':p}], max_tok=4000)
def ask_glm(p):
    return api_call('https://api.z.ai/api/coding/paas/v4/chat/completions', GLM_KEY,
                    'glm-4.5-air', [{'role':'user','content':p}], max_tok=8000)


def uniform_sample(seed, n):
    """Uniform random sample, skipping already-annotated addresses."""
    random.seed(seed)
    fresh = [l for l in ALL_LINES if not any(a in l for a in PRIOR)]
    return random.sample(fresh, min(n, len(fresh)))


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
        kw = sum(1 for k in DOMAIN_KEYWORDS if k in low)
        is_yes = (not is_unknown) and kw >= 1
        out[idx] = (text, is_yes, kw)
    return out


def build_prompt(batch, mode='cooperative', prior=None):
    sec = []
    for i, (addr, ctx) in enumerate(batch):
        s = f"--- Sample {i+1}/{len(batch)}  (address 0x{addr}) ---\n{ctx}\n"
        if mode == 'adversarial' and prior:
            p = prior.get(i, '')
            if p: s += f"\nPRIOR ANSWER (review/refute/refine): {p}\n"
        sec.append(s)
    if mode == 'adversarial':
        instr = ("Critically evaluate the PRIOR ANSWER. If wrong, give the correct "
                 "specific purpose. If vague, sharpen. If right, restate more precisely. "
                 "Cite FPS-3000 hardware. If data not code, say 'DATA'. Output:\n"
                 "  S<N>: <purpose>\n\n")
    else:
        instr = ("Identify in 1-2 sentences the specific purpose of the >>>> instruction "
                 "in the FPS-3000 ROM. The disassembly already includes prior MC "
                 "annotations as `;>>>>` lines — cite/extend them as appropriate. "
                 "Reference concrete subsystems, registers, functions, algorithms. "
                 "If you cannot, say 'UNKNOWN' or 'DATA'. Output:\n"
                 "  S<N>: <purpose>\n\n")
    return HARDWARE_CONTEXT + "\n\n" + instr + "\n".join(sec)


def run_round(rn, seed, mode):
    samples = uniform_sample(seed, SAMPLES_PER_ROUND)
    ctx_list = [extract_ctx(s) for s in samples]
    ctx_list = [c for c in ctx_list if c[0]]
    batches = [ctx_list[i:i+BATCH_SIZE] for i in range(0,len(ctx_list),BATCH_SIZE)]
    glm_r, ds_r = {}, {}
    offset = 0
    for b in batches:
        if mode == 'adversarial':
            ds_txt, _ = ask_deepseek(build_prompt(b, 'cooperative'))
            ds_p = score_and_parse(ds_txt, b)
            prior = {i: ds_p.get(i,('',False,0))[0] for i in range(len(b))}
            glm_txt, _ = ask_glm(build_prompt(b, 'adversarial', prior))
            glm_p = score_and_parse(glm_txt, b)
            for i,(a,_) in enumerate(b):
                gi = offset+i
                ds_r[gi]  = (a,)+ds_p.get(i,('',False,0))
                glm_r[gi] = (a,)+glm_p.get(i,('',False,0))
        else:
            p = build_prompt(b, 'cooperative')
            q = queue.Queue()
            t1 = threading.Thread(target=lambda: q.put(('glm',)+ask_glm(p)))
            t2 = threading.Thread(target=lambda: q.put(('ds',)+ask_deepseek(p)))
            t1.start(); t2.start(); t1.join(timeout=200); t2.join(timeout=200)
            got = {}
            while not q.empty():
                k, txt, el = q.get()
                got[k]=(txt,el)
            glm_p = score_and_parse(got.get('glm',('',0))[0], b)
            ds_p  = score_and_parse(got.get('ds',('',0))[0], b)
            for i,(a,_) in enumerate(b):
                gi = offset+i
                glm_r[gi] = (a,)+glm_p.get(i,('',False,0))
                ds_r[gi]  = (a,)+ds_p.get(i,('',False,0))
        offset += len(b)
    yes,both = 0,0; acc=[]
    for gi in range(len(ctx_list)):
        ga = glm_r.get(gi,(None,'',False,0))
        da = ds_r.get(gi,(None,'',False,0))
        a = ga[0] or da[0]
        gy,dy = ga[2],da[2]
        if gy or dy: yes += 1
        if gy and dy: both += 1
        if gy or dy:
            if gy and dy: pick, tag = (ga if ga[3]>=da[3] else da), 'BOTH'
            elif gy: pick, tag = ga, 'GLM'
            else:    pick, tag = da, 'DS'
            acc.append((a, f'R{rn}', pick[1], tag))
    pct = yes*100//len(ctx_list) if ctx_list else 0
    bpct = both*100//len(ctx_list) if ctx_list else 0
    return pct, bpct, acc, len(ctx_list)


def main():
    out = open('/tmp/fps3k_annotations_round3.txt','w')
    out.write('# FPS-3000 MC annotations — round 3 (R11-R15, uniform sampling)\n')
    summary=[]
    for rn,seed,mode in ROUNDS:
        t0 = time.time()
        try:
            pct,bpct,acc,total = run_round(rn,seed,mode)
        except Exception as e:
            print(f'[R{rn}] FAILED: {e}', flush=True); continue
        el = time.time()-t0
        print(f'[R{rn} seed={seed} mode={mode}] {total} samples, '
              f'YES={pct}%, BOTH={bpct}%, annot={len(acc)}, {el:.0f}s', flush=True)
        summary.append((rn,seed,mode,pct,bpct,len(acc),el))
        for addr,rt,t,tag in acc:
            out.write(f'0x{addr} [{rt} {tag}] {t}\n')
        out.flush()
    out.close()
    print('\n== SUMMARY ==')
    print(f'{"Round":<6} {"Seed":<6} {"Mode":<13} {"YES%":<6} {"BOTH%":<7} {"Annots":<7} {"sec":<5}')
    for r,s,m,p,b,a,e in summary:
        print(f'R{r:<5} {s:<6} {m:<13} {p:<6} {b:<7} {a:<7} {e:.0f}')


if __name__=='__main__':
    main()
