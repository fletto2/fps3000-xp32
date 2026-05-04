#!/usr/bin/env python3
"""
Extract AP-120B microcode from OCR'd APAL listings using TSV output.

Strategy:
  1. For each page, run tesseract in TSV mode (gives bbox per word).
  2. Cluster words into lines by similar `top` coordinate.
  3. Within each line, words sorted by `left`.
  4. The listing has these columns at known left ranges:
       margin glyphs   left ≈   30..200    (¢, |, dots — ignore)
       address         left ≈  300..550    6-digit octal
       word            left ≈  580..900    6-digit octal (word1, or w2/3/4)
       mnemonic        left ≈ 950..1700    APAL text
       comment         left ≈ 1700+        text
  5. Lines with TWO octal tokens (address + word) and a mnemonic are
     instruction HEAD lines.
     Lines with ONE octal token in the word column and no other text
     to the right are CONTINUATION lines (word2/3/4).
  6. State machine collects 1 head + 3 continuations into one
     microinstruction (4×16-bit words = 64 bits).

OCR fixups: `B`→`0`, `O`→`0`, `b`→`6`, `o`→`0`, `l`→`1`, `I`→`1`,
`S`→`5`, `Z`→`2`, `g`/`G`/`Q`/`D`→`0`, `T`→`1`, `L`→`1`. After fixup,
require all chars in `[0-7]`. Accept token lengths 5..7 — if 7, try
trimming first or last char; if 5, reject (real microcode doesn't pad
leading zeros to fewer than 6 in this listing format).
"""
import os, re, sys, struct, subprocess

OCR_DIR = "/tmp/ucode_ocr"
SRC_PDF = "/home/fletto/src/claude/versabus/refs/AP120B_fast_mem_ucode.pdf"
OUT_BIN = "/home/fletto/ext/src/claude/fps3000/ap120b_ffttest_ucode.bin"
OUT_TXT = "/home/fletto/ext/src/claude/fps3000/ap120b_ffttest_ucode.txt"
OUT_GAP = "/home/fletto/ext/src/claude/fps3000/ap120b_ffttest_ucode.gaps"

FIXUP = str.maketrans({
    "B": "0", "O": "0", "o": "0",
    "l": "1", "I": "1", "i": "1",
    "S": "5", "s": "5",
    "Z": "2", "z": "2",
    "g": "0", "G": "0", "Q": "0", "D": "0",
    "T": "1", "L": "1",
    "b": "6", "j": "1",
})

OCT_OK = re.compile(r"^[0-7]+$")

def fix_oct(tok):
    """Try to convert a token to a valid 6-digit octal value, returning
    int or None. Tries length-6 first, then trims if length 7."""
    if not tok:
        return None
    cleaned = tok.translate(FIXUP)
    # Strip stray punctuation/colons that often appear glued to digits.
    cleaned = re.sub(r"[^0-7]", "", cleaned)
    if not cleaned:
        return None
    if len(cleaned) == 6:
        return int(cleaned, 8)
    if len(cleaned) == 7:
        # Try with first char dropped, then last.
        a = int(cleaned[1:], 8)
        b = int(cleaned[:-1], 8)
        # Prefer the smaller value (less likely to have spurious high bit).
        return a if a <= b else b
    if len(cleaned) == 8:
        return int(cleaned[1:7], 8)
    if len(cleaned) == 5:
        # Pad if reasonable (rare).
        return int(cleaned, 8)
    return None

def run_tsv(pgm):
    """Run tesseract on `pgm` and return list of (left, top, conf, text)
    rows for each detected word."""
    base = pgm[:-4]
    tsv_path = base + ".tsv"
    if not os.path.exists(tsv_path):
        subprocess.run(
            ["tesseract", pgm, base, "-c", "preserve_interword_spaces=1",
             "--psm", "6", "tsv"],
            check=True, capture_output=True,
        )
    rows = []
    with open(tsv_path) as f:
        next(f)  # skip header
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 12:
                continue
            level = parts[0]
            if level != "5":  # words only
                continue
            try:
                left = int(parts[6]); top = int(parts[7])
                conf = float(parts[10]); text = parts[11]
            except ValueError:
                continue
            if conf < 30:
                continue
            text = text.strip()
            if not text:
                continue
            rows.append((left, top, conf, text))
    return rows

def cluster_lines(words, vtol=25):
    """Group word tuples into rows by `top` coordinate proximity."""
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
    """Return list of (kind, addr_or_none, words, head_text) entries.

    kind = 'HEAD' (addr+word1+mnemonic) | 'CONT' (single word) | 'OTHER'.
    """
    parsed = []
    for ln in lines:
        # Strip margin junk (left < 250) and very-low-conf single-char.
        clean = [(l, t, c, x) for (l, t, c, x) in ln if l >= 250]
        if not clean:
            parsed.append(("OTHER", None, [], ""))
            continue

        # Try to identify address (in 280..560) and word1 (in 580..900).
        addr_cand = [(l,t,c,x) for (l,t,c,x) in clean if 280 <= l <= 580]
        word_cand = [(l,t,c,x) for (l,t,c,x) in clean if 580 <= l <= 950]
        mnem_cand = [(l,t,c,x) for (l,t,c,x) in clean if l >= 950]

        addr = None
        if addr_cand:
            for w in addr_cand:
                v = fix_oct(w[3])
                if v is not None and v <= 0o7777:
                    addr = v
                    break

        word1 = None
        if word_cand:
            for w in word_cand:
                v = fix_oct(w[3])
                if v is not None and v <= 0o177777:
                    word1 = v
                    break

        head_text = " ".join(x for (_,_,_,x) in clean)

        if addr is not None and word1 is not None and mnem_cand:
            parsed.append(("HEAD", addr, [word1], head_text))
        elif word1 is not None and not addr_cand and not mnem_cand:
            parsed.append(("CONT", None, [word1], head_text))
        else:
            parsed.append(("OTHER", None, [], head_text))
    return parsed

def main():
    if not os.path.isdir(OCR_DIR):
        sys.exit(f"missing {OCR_DIR}")
    pgms = sorted(p for p in os.listdir(OCR_DIR) if p.endswith(".pgm"))

    by_addr = {}
    bad_groups = 0
    head_count = 0

    for pgm in pgms:
        page = int(re.search(r"\d+", pgm).group())
        rows = run_tsv(os.path.join(OCR_DIR, pgm))
        lines = cluster_lines(rows)
        parsed = parse_lines(lines)

        # State machine: HEAD then 3 CONTs.
        i = 0
        while i < len(parsed):
            kind, addr, words, head = parsed[i]
            if kind != "HEAD":
                i += 1
                continue
            head_count += 1
            collected = list(words)
            j = i + 1
            ok = True
            while len(collected) < 4 and j < len(parsed):
                k, a, ws, _ = parsed[j]
                if k == "CONT":
                    collected.extend(ws)
                    j += 1
                elif k == "OTHER":
                    j += 1
                    continue
                else:
                    ok = False
                    break
            if ok and len(collected) == 4:
                if addr not in by_addr:
                    by_addr[addr] = (page, collected, head)
            else:
                bad_groups += 1
            i = j if ok else i + 1

    print(f"head lines found:       {head_count}")
    print(f"complete instructions:  {len(by_addr)}")
    print(f"incomplete groups:      {bad_groups}")

    if not by_addr:
        sys.exit("nothing recovered")

    lo = min(by_addr); hi = max(by_addr)
    print(f"address range: {lo:#o} .. {hi:#o}  ({hi-lo+1} slots)")

    # Validate: drop entries whose address falls way outside the
    # documented program (HIGH=0o342). Keep <= 0o400 as safety margin.
    HIGH_LIMIT = 0o400
    bogus = [a for a in by_addr if a > HIGH_LIMIT]
    for a in bogus:
        del by_addr[a]
    if bogus:
        print(f"dropped {len(bogus)} entries above 0o{HIGH_LIMIT:o}")

    lo = min(by_addr); hi = max(by_addr)

    with open(OUT_BIN, "wb") as f:
        for addr in range(lo, hi + 1):
            entry = by_addr.get(addr)
            if entry is None:
                f.write(b"\x00" * 8)
            else:
                _, words, _ = entry
                for w in words:
                    f.write(struct.pack(">H", w))

    gaps = [a for a in range(lo, hi + 1) if a not in by_addr]
    with open(OUT_GAP, "w") as f:
        for a in gaps:
            f.write(f"{a:06o}\n")

    with open(OUT_TXT, "w") as f:
        f.write(f"# AP-120B FFT/IFFT identity-test microcode (recovered from OCR)\n")
        f.write(f"# source: fast_mem_ucode.pdf (52pp APAL listing on bitsavers)\n")
        f.write(f"# range: {lo:#o}..{hi:#o}, {hi-lo+1} slots, "
                f"{len(by_addr)} recovered, {len(gaps)} gaps "
                f"({100*len(by_addr)/(hi-lo+1):.1f}% coverage)\n#\n")
        f.write(f"#  addr   word1  word2  word3  word4   (page)  head-text (raw OCR)\n")
        for addr in range(lo, hi + 1):
            entry = by_addr.get(addr)
            if entry is None:
                f.write(f"{addr:06o}  ??????  ??????  ??????  ??????   GAP\n")
            else:
                page, words, head = entry
                w = "  ".join(f"{w:06o}" for w in words)
                f.write(f"{addr:06o}  {w}   (p{page:02d})  {head[:100]}\n")

    print(f"\nbinary    : {OUT_BIN}  ({(hi-lo+1)*8} bytes)")
    print(f"text      : {OUT_TXT}")
    print(f"gaps      : {OUT_GAP}  ({len(gaps)} addresses)")
    cov = 100 * len(by_addr) / (hi - lo + 1)
    print(f"coverage  : {len(by_addr)}/{hi-lo+1}  ({cov:.1f}%)")

if __name__ == "__main__":
    main()
