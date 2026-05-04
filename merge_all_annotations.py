#!/usr/bin/env python3
"""Merge ALL MC annotation files (R1-R10) into the clean disassembly."""
import re, collections, os

ANNOT_FILES = [
    '/tmp/fps3k_annotations_cooperative.txt',  # R1-R5
    '/tmp/fps3k_annotations_adversarial.txt',  # R1 partial (salvaged)
    '/tmp/fps3k_annotations_round2.txt',       # R6-R10
    '/tmp/fps3k_annotations_round3.txt',       # R11-R15
]

anno = collections.defaultdict(list)
for path in ANNOT_FILES:
    if not os.path.exists(path): continue
    with open(path) as f:
        for line in f:
            m = re.match(r'^0x(f0[0-9a-f]{4})\s+\[(R\d+)\s+([A-Z]+)\]\s+(.*)$', line.strip())
            if not m: continue
            addr, tag, agree, text = m.group(1), m.group(2), m.group(3), m.group(4)
            anno[addr].append((tag, agree, text))

# De-duplicate exact-text duplicates (sometimes the same line is annotated by R1 and R2 with same content)
for addr in anno:
    seen = set()
    uniq = []
    for tag, agree, text in anno[addr]:
        # Use first ~80 chars as dedup key
        key = text[:80].lower()
        if key not in seen:
            seen.add(key)
            uniq.append((tag, agree, text))
    anno[addr] = uniq

out = []
with open('/tmp/fps3k_rom_disasm.txt') as f:
    for line in f:
        m = re.match(r'^  (f0[0-9a-f]{4}):', line)
        if m and m.group(1) in anno:
            for tag, agree, text in anno[m.group(1)]:
                out.append(f';>>>> [{tag}/{agree}] {text}\n')
        out.append(line)

with open('/home/fletto/ext/src/claude/fps3000/fps3k_custom_annotated.asm','w') as f:
    f.writelines(out)

total_addrs = len(anno)
total_annots = sum(len(v) for v in anno.values())
print(f'{total_addrs} unique addresses annotated, {total_annots} total annotations')
print(f'Output: fps3k_custom_annotated.asm')
