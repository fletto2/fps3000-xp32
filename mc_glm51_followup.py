#!/usr/bin/env python3
"""
Targeted GLM-5.1 (coding/reasoning) follow-up on the FPS-3000 ROM.

Instead of running blanket rounds, this script picks specific
high-value samples from the cooperative MC run and asks the GLM-5.1
reasoning model to:

  1. Adversarially challenge the cooperative-MC consensus answer
  2. Provide a sharper, longer, reasoning-backed annotation
  3. Identify any contradictions or missing context in the consensus

Targets:
  - Single-source agreements (only one model said YES — needs review)
  - DATA-marked samples (was it really data?)
  - Hot-spots: PanelIOConfigure_25A callsites with rare command codes
  - Mode-state-machine sites ($E86 dispatch)
  - TCB-creation failure paths

Run:  python3 mc_glm51_followup.py
"""
import urllib.request, json, time, re, sys, os

GLM_KEY = open('/home/fletto/src/claude/super68k/glm_api_key.txt').read().strip()
DS_KEY  = open('/home/fletto/src/claude/super68k/deepseek_api_key.txt').read().strip()

RAW_DISASM = open('/tmp/fps3k_rom_disasm.txt').read().splitlines()
ADDR_INDEX = {}
for i, l in enumerate(RAW_DISASM):
    m = re.match(r'^  (f0[0-9a-f]{4}):', l)
    if m: ADDR_INDEX[m.group(1)] = i

# Read the cooperative annotations — they include the consensus answer per address
COOP = {}
with open('/tmp/fps3k_annotations_cooperative.txt') as f:
    for line in f:
        m = re.match(r'^0x(f0[0-9a-f]{4})\s+\[(R\d+)\s+([A-Z]+)\]\s+(.*)$', line.strip())
        if not m: continue
        addr, tag, agree, text = m.group(1), m.group(2), m.group(3), m.group(4)
        if addr not in COOP:
            COOP[addr] = (tag, agree, text)

# Pick targets
TARGETS = []
# 1. Single-source agreements
TARGETS += [a for a, (t,ag,_) in COOP.items() if ag != 'BOTH']
# 2. Specific architectural hot-spots
hot_spots = [
    'f04756', 'f0496e', 'f04966',     # mode-state machine
    'f0498c',                          # channel 0x10 special-case
    'f07110',                          # per-channel data table at $1080
    'f04b9e', 'f04bbc',                # S-record S1/S2 dispatch
    'f04d90',                          # staging buffer bound
    'f05244', 'f05210',                # SRecord finalize loop
    'f056ba', 'f056ca', 'f056d4',      # panel send-and-wait kernel core
    'f0517e',                          # write 0x400 to FF0218 (DMA arm)
    'f07dc6', 'f07476',                # TCB creation failure paths
]
for a in hot_spots:
    if a in COOP and a not in TARGETS:
        TARGETS.append(a)

# Cap at 25 to keep runtime sane (~30-60 min for reasoning model)
TARGETS = TARGETS[:25]

CTX_BEFORE, CTX_AFTER = 12, 12

HARDWARE_CONTEXT = open('/tmp/fps3k_hw_context.txt').read() if os.path.exists('/tmp/fps3k_hw_context.txt') else """
FPS-3000 SBC firmware (MC68000, 64 KB ROM at 0xF00000) — Control
Processor for FPS XP-32 array processor. AP I/F + VersaBUS XLTR at
0xFF0000–0xFF021F. Panel-command sender at F056BA: writes
0x8004/0x8005 opcodes to FF0000, polls bit 14 (ready) / bit 13 (error)
with 1000-tick timeout. PanelIOConfigure_25A at F05688 takes a 16-bit
code (0x258..0x27D, 21 distinct codes observed) and configures Mode 0
(FF0200, bit 10 cleared), Mode 1 (FF0202, bit 12 set + bit 14 cleared),
and Channel Select (FF0204). RMS68K kernel with !TCB/!CCB/!ASQ/!TST/
!DLY/!VCT/!GST/!UST/!IOV/!IDV/!PAT/!UDR markers. The XP-32 EXEC card
uses an AMD Am29116 16-bit bipolar microprocessor as sequencer; the
microcode upload writes 16-byte blocks (4×16-bit horizontal microwords)
to Am2168 SRAMs. SRecordDataHandler at F051A2 enforces 0x10000 ≤ addr ≤
0x1FFFF for the staging buffer (= one 4K×128-bit WCS bank).
"""


def glm51_call(prompt, max_tok=12000, timeout=300):
    """Call GLM-5.1 (reasoning model on Z.ai coding plan)."""
    body = json.dumps({
        'model': 'glm-5.1',     # reasoning model
        'messages': [{'role':'user','content':prompt}],
        'max_tokens': max_tok, 'temperature': 0.2
    }).encode()
    req = urllib.request.Request(
        'https://api.z.ai/api/coding/paas/v4/chat/completions',
        data=body, headers={'Authorization': f'Bearer {GLM_KEY}',
                            'Content-Type':'application/json'})
    t0 = time.time()
    try:
        r = urllib.request.urlopen(req, timeout=timeout).read().decode()
        j = json.loads(r)
        msg = j['choices'][0]['message']
        content = (msg.get('content') or '').strip()
        reasoning = (msg.get('reasoning_content') or '').strip()
        return content, reasoning, time.time()-t0
    except Exception as e:
        return f'ERROR: {e}', '', time.time()-t0


def extract_ctx(addr):
    idx = ADDR_INDEX.get(addr)
    if idx is None: return None
    start = max(0, idx - CTX_BEFORE)
    end   = min(len(RAW_DISASM), idx + CTX_AFTER + 1)
    block = []
    for i in range(start, end):
        marker = '>>>>' if i == idx else '    '
        block.append(f'{marker} {RAW_DISASM[i]}')
    return '\n'.join(block)


def main():
    out = open('/tmp/fps3k_glm51_followup.txt','w')
    out.write(f'# GLM-5.1 adversarial follow-up — {len(TARGETS)} targets\n\n')

    for n, addr in enumerate(TARGETS, 1):
        ctx = extract_ctx(addr)
        if not ctx: continue
        coop_tag, coop_agree, coop_text = COOP.get(addr, ('R0','—','(no prior)'))
        prompt = (HARDWARE_CONTEXT + "\n\n" +
            f"Below is a single instruction at address 0x{addr} in the FPS-3000 ROM, "
            f"with surrounding context. The cooperative MC pass produced this "
            f"consensus annotation (model agreement: {coop_agree}):\n\n"
            f"  → {coop_text}\n\n"
            f"Your task as the adversarial reviewer:\n"
            f"  1. Decide whether the consensus is CORRECT, INCOMPLETE, or WRONG\n"
            f"  2. If CORRECT, provide a sharper restatement (more specific register "
            f"names, exact bits, or function role within the larger XP-32 protocol)\n"
            f"  3. If INCOMPLETE, name what's missing (cite specific FPS-3000 hardware)\n"
            f"  4. If WRONG, give the correct interpretation with reasoning\n\n"
            f"Output format (no preamble):\n"
            f"  VERDICT: <CORRECT|INCOMPLETE|WRONG>\n"
            f"  ANNOTATION: <one or two sentences, sharper than the consensus>\n"
            f"  REASONING: <up to 4 sentences on why>\n\n"
            f"--- Context (>>>> marks the target line) ---\n{ctx}\n")

        print(f'[{n}/{len(TARGETS)}] 0x{addr}...', flush=True)
        content, reasoning, el = glm51_call(prompt)
        out.write(f'## 0x{addr}  (cooperative: {coop_tag}/{coop_agree})\n\n')
        out.write(f'**Consensus:** {coop_text}\n\n')
        out.write(f'**GLM-5.1 ({el:.0f}s):**\n```\n{content}\n```\n')
        if reasoning:
            out.write(f'\n<details><summary>reasoning</summary>\n\n```\n{reasoning[:3000]}\n```\n</details>\n')
        out.write('\n---\n\n')
        out.flush()

    out.close()
    print(f'Wrote /tmp/fps3k_glm51_followup.txt')


if __name__ == '__main__':
    main()
