#!/usr/bin/env python3
"""
EasyOCR-based extraction of AP-120B microcode from fast_mem_ucode.pdf.

Per-page strategy:
  1. easyocr.readtext on the .pgm
  2. Cluster boxes into rows by Y coordinate
  3. In each row identify columns by X:
       addr   x_left ~ 280..580
       word   x_left ~ 580..900
       (mnemonic / comment ignored — we trust the symbol table)
  4. HEAD row    = addr (1..3 oct digits) + word (6 oct digits) + text
     CONT row    = only one 6-octal-digit token in the word column
  5. State machine: HEAD then 3 CONTs → 4×16-bit microinstruction.

Multi-module: each module's listing restarts addresses at 0o0.
We resolve to the linked-binary address using the symbol table.
"""
import os, re, sys, struct, pickle
import easyocr

OCR_DIR = "/tmp/ucode_ocr"
CACHE   = "/tmp/ucode_ocr/easyocr_cache.pkl"
OUT_BIN = "/home/fletto/ext/src/claude/fps3000/ap120b_ffttest_ucode.bin"
OUT_TXT = "/home/fletto/ext/src/claude/fps3000/ap120b_ffttest_ucode.txt"
OUT_GAP = "/home/fletto/ext/src/claude/fps3000/ap120b_ffttest_ucode.gaps"

# Linked-binary symbol table (from p-01 cover sheet).
SYMBOLS = {
    "FIFFT":  0o000,   # 0..23
    "VFLT":   0o024,   # 24..36
    "VSHFX":  0o037,   # 37..47
    "CFFT":   0o050,   # 50..74
    "STSTAT": 0o075,   # 75..107
    "CLSTAT": 0o110,   # 110..112
    "ILOG2":  0o113,   # 113..117
    "ADV4":   0o120,   # 120..123
    "ADV2":   0o124,   # 124..127
    "BITREV": 0o130,   # 130..203
    "FFT2":   0o204,   # 204..223
    "FFT4":   0o224,   # 224..341
}
HIGH = 0o342

# Page → module name mapping. Each module's listing has a "PAGE 0001" cover.
# Filled in by inspection (incremental); start with what we know.
# Entries: pgm-page-number (1-indexed) -> module name OR None for cover/skip.
PAGE_MODULE = {
    1:  None,        # hand-annotated cover
    2:  "FIFFT",
    3:  "FIFFT",
    4:  "FIFFT",     # ends here
    5:  "VFLT",      # header
    6:  "VFLT",
    7:  "VFLT",      # ends here
    # remaining filled in dynamically by detecting "$TITLE <name>" lines
}

OCT_OK = re.compile(r"^[0-7]+$")

def fix_oct(tok):
    """Strict: token must already be all-octal. Return int or None.
    EasyOCR with allowlist=01234567 gives clean tokens — no fixups needed."""
    if not tok or not OCT_OK.match(tok):
        return None
    n = len(tok)
    if 1 <= n <= 6:
        return int(tok, 8)
    return None  # 7+ digits is suspicious

def run_easyocr(reader, pgm):
    """Returns list of (x_left, y_top, conf, text). Caches results."""
    cache = {}
    if os.path.exists(CACHE):
        with open(CACHE, "rb") as f:
            cache = pickle.load(f)
    if pgm in cache:
        return cache[pgm]
    res = reader.readtext(pgm, allowlist="01234567", paragraph=False)
    rows = []
    for bbox, text, conf in res:
        x = int(bbox[0][0]); y = int(bbox[0][1])
        rows.append((x, y, float(conf), text))
    cache[pgm] = rows
    with open(CACHE, "wb") as f:
        pickle.dump(cache, f)
    return rows

def cluster_lines(words, vtol=20):
    if not words:
        return []
    words = sorted(words, key=lambda w: (w[1], w[0]))
    lines = [[words[0]]]
    for w in words[1:]:
        if abs(w[1] - lines[-1][-1][1]) <= vtol:
            lines[-1].append(w)
        else:
            lines.append([w])
    for ln in lines:
        ln.sort(key=lambda w: w[0])
    return lines

def parse_lines(lines):
    """For each line, classify as HEAD/CONT/OTHER. Local addresses (per-module)."""
    parsed = []
    for ln in lines:
        addr_cand = [w for w in ln if 280 <= w[0] <= 580]
        word_cand = [w for w in ln if 580 <  w[0] <= 950]

        addr = None
        for w in addr_cand:
            v = fix_oct(w[3])
            if v is not None and v <= 0o7777:
                addr = v
                break

        word1 = None
        for w in word_cand:
            v = fix_oct(w[3])
            if v is not None and v <= 0o177777 and len(w[3]) >= 4:
                word1 = v
                break

        if addr is not None and word1 is not None:
            parsed.append(("HEAD", addr, word1))
        elif word1 is not None and not addr_cand:
            parsed.append(("CONT", None, word1))
        else:
            parsed.append(("OTHER", None, None))
    return parsed

def extract_module_pages(reader, page_nums):
    """Run OCR on a contiguous set of pages and return list of
    (local_addr, [w1,w2,w3,w4]) tuples for the module they contain."""
    all_lines = []
    for n in page_nums:
        pgm = f"{OCR_DIR}/p-{n:02d}.pgm"
        if not os.path.exists(pgm):
            continue
        rows = run_easyocr(reader, pgm)
        all_lines.extend(cluster_lines(rows))
    parsed = parse_lines(all_lines)

    out = []
    i = 0
    while i < len(parsed):
        kind, addr, w1 = parsed[i]
        if kind != "HEAD":
            i += 1
            continue
        collected = [w1]
        j = i + 1
        while len(collected) < 4 and j < len(parsed):
            k, _, w = parsed[j]
            if k == "CONT":
                collected.append(w)
                j += 1
            elif k == "OTHER":
                j += 1
            else:
                break
        if len(collected) == 4:
            out.append((addr, collected))
        i = j
    return out

def main():
    print("loading easyocr (CPU)...")
    reader = easyocr.Reader(["en"], gpu=False, verbose=False)

    # Group pages by module per PAGE_MODULE (we extend it as we discover
    # via the printed module title pages).
    by_module = {}
    for pg, mod in PAGE_MODULE.items():
        if mod:
            by_module.setdefault(mod, []).append(pg)

    by_addr = {}
    for mod, pages in by_module.items():
        base = SYMBOLS[mod]
        print(f"\n== module {mod} (base 0o{base:o}) pages {pages} ==")
        instrs = extract_module_pages(reader, sorted(pages))
        print(f"   recovered {len(instrs)} instructions")
        for local, words in instrs:
            linked = base + local
            if linked not in by_addr:
                by_addr[linked] = (mod, words)

    if not by_addr:
        sys.exit("nothing recovered")

    lo = 0; hi = HIGH
    print(f"\ntotal recovered: {len(by_addr)} / {hi+1} slots")
    print(f"address range  : 0o0 .. 0o{hi:o}")

    with open(OUT_BIN, "wb") as f:
        for addr in range(lo, hi + 1):
            entry = by_addr.get(addr)
            if entry is None:
                f.write(b"\x00" * 8)
            else:
                _, words = entry
                for w in words:
                    f.write(struct.pack(">H", w))

    gaps = [a for a in range(lo, hi + 1) if a not in by_addr]
    with open(OUT_GAP, "w") as f:
        for a in gaps:
            f.write(f"{a:06o}\n")

    with open(OUT_TXT, "w") as f:
        f.write("# AP-120B FFT/IFFT identity-test microcode (recovered via EasyOCR)\n")
        f.write(f"# range 0o0..0o{hi:o}, {len(by_addr)} recovered, {len(gaps)} gaps\n")
        f.write("#  addr   word1  word2  word3  word4   module\n")
        for addr in range(lo, hi + 1):
            entry = by_addr.get(addr)
            if entry is None:
                f.write(f"{addr:06o}  ??????  ??????  ??????  ??????   GAP\n")
            else:
                mod, words = entry
                w = "  ".join(f"{x:06o}" for x in words)
                f.write(f"{addr:06o}  {w}   ({mod})\n")

    cov = 100 * len(by_addr) / (hi + 1)
    print(f"coverage : {len(by_addr)}/{hi+1}  ({cov:.1f}%)")
    print(f"binary   : {OUT_BIN}")
    print(f"text     : {OUT_TXT}")

if __name__ == "__main__":
    main()
