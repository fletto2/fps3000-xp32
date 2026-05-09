#!/usr/bin/env python3
"""
FPS-100 .APO file decoder — produces APAL-style disassembly.

The .APO format is the textual ASM100 object-file format consumed by
LED100 (the link editor). This decoder uses the explicit `***CODE`
markers in the file to locate microinstruction records, then applies
the canonical SIM100.FTN SPLIT recipe (24 fields per 8-byte
microinstruction) to each one.

Each block is a header line ending in `***NAME` followed by some
number of payload lines. The blocks we care about for microcode are:

  `***TITLE`   — 1 payload line: routine name
  `***CODE`    — header has 3 fields: relocation, RECCNT, address;
                 followed by RECCNT records of 4 octal 16-bit words
                 (= 8 bytes = 1 microinstruction each)
  `***END`     — closes a routine; 1 payload line: name

Other block types (`***LSB`, `***PB`, `***FPB`, `***AENTRY`,
`***ENTRY`, `***EXT`, `***DBDB`, `***DBIB`, `***PARAM`, `***INDEX`,
`***TASK`, `***ISR`) are surfaced in the block-counts summary but
their payloads are not needed for microcode extraction — the
`***CODE` marker is unambiguous so we never need to decode them.

Usage:
    python3 apo_decode.py <file.APO> [--no-split] [--routine NAME]
"""
import re, sys, argparse


def split_sim100(reg):
    """
    Canonical SIM100 SPLIT (line 3863 of SIM100.FTN). Decodes the
    8 bytes of one AP-120B microinstruction into 24 named fields.
    `reg` is REG[0..7] with REG[0] the high-byte (per the FORTRAN
    indexing where REG(1) is high).
    """
    R = reg
    fv = [0] * 25
    fv[1]  = (R[0] // 128) % 2
    fv[2]  = (R[0] // 16) % 8
    fv[3]  = (R[0] // 4) % 4
    fv[4]  = (R[0] % 4) * 4 + (R[1] // 64) % 4
    fv[5]  = (R[1] // 4) % 16
    fv[6]  = (R[1] % 4) * 2 + (R[2] // 128) % 2
    fv[7]  = (R[2] // 16) % 8
    fv[8]  = (R[2] // 2) % 8
    fv[9]  = (R[2] % 2) * 8 + (R[3] // 32) % 8
    fv[10] = R[3] % 32
    fv[11] = (R[4] // 64) % 4
    fv[12] = (R[4] // 16) % 4
    fv[13] = (R[4] // 2) % 8
    fv[14] = (R[4] % 2) * 4 + (R[5] // 64) % 4
    fv[15] = (R[5] // 8) % 8
    fv[16] = R[5] % 8
    fv[17] = (R[6] // 32) % 8
    fv[18] = (R[6] // 16) % 2
    fv[19] = (R[6] // 4) % 4
    fv[20] = R[6] % 4
    fv[21] = (R[7] // 64) % 4
    fv[22] = (R[7] // 16) % 4
    fv[23] = (R[7] // 4) % 4
    fv[24] = R[7] % 4
    return {
        'DF': fv[1], 'SOPF': fv[2], 'SHF': fv[3], 'SPSF': fv[4],
        'SPDF': fv[5], 'FADDF': fv[6], 'A1F': fv[7], 'A2F': fv[8],
        'CONDF': fv[9], 'DISPF': fv[10], 'DPXF': fv[11], 'DPYF': fv[12],
        'DPBSF': fv[13], 'XRF': fv[14], 'YRF': fv[15], 'XWF': fv[16],
        'YWF': fv[17], 'FMF': fv[18], 'M1F': fv[19], 'M2F': fv[20],
        'MIF': fv[21], 'MAF': fv[22], 'DPAF': fv[23], 'TMAF': fv[24],
    }


def fmt_split(f):
    """One-line APAL-style mnemonic showing nonzero fields."""
    nz = [f'{k}={v}' for k, v in f.items() if v != 0]
    return ' '.join(nz) if nz else '(no-op)'


def words_to_bytes(words):
    """
    Convert a list of 16-bit words (octal) into a flat byte array,
    high-byte first within each word. Per the AP-120B convention
    matching SIM100's REG ordering.
    """
    out = []
    for w in words:
        out.append((w >> 8) & 0xFF)
        out.append(w & 0xFF)
    return out


def parse_apo(path, radix=8):
    """
    Walk the .APO file looking for explicit ***CODE markers. Each
    ***CODE header is `<reloc> <RECCNT> <addr> ***CODE` and is
    followed by exactly RECCNT records of microinstruction data
    (each = 4 octal 16-bit words on one line).

    Returns: list of routines, each a dict { 'name', 'code' }
    where 'code' is a list of (addr, [8 bytes]) pairs.
    """
    with open(path, errors='replace') as f:
        lines = f.read().replace('\r', '').split('\n')

    # Strip blank lines, but keep their indices for diagnostics
    routines = []
    cur = None  # current routine in progress
    block_counts = {}
    i = 0
    n = len(lines)
    while i < n:
        raw = lines[i]
        line = raw.rstrip()
        i += 1
        if not line.strip():
            continue

        # Detect a block-type marker
        m = re.search(r'\*\*\*([A-Z_]+)', line)
        if not m:
            continue  # not a block header — skip (shouldn't happen at top level)
        marker = m.group(1)
        block_counts[marker] = block_counts.get(marker, 0) + 1

        # Tokens BEFORE the marker, parsed as integers in current radix
        tokens_part = line[:m.start()].strip()
        toks = []
        for t in tokens_part.split():
            try:
                toks.append(int(t, radix))
            except ValueError:
                pass

        if marker == 'TITLE':
            # next non-blank line is the routine name
            while i < n and not lines[i].strip(): i += 1
            if i < n:
                name = lines[i].strip()
                cur = {'name': name, 'code': []}
                routines.append(cur)
                i += 1

        elif marker == 'CODE':
            # toks = [reloc, RECCNT, addr] — but tokens before *** can vary
            if len(toks) >= 3:
                reccnt, addr0 = toks[1], toks[2]
            elif len(toks) >= 2:
                reccnt, addr0 = toks[0], toks[1]
            else:
                # malformed — skip
                continue

            # Read RECCNT non-blank lines, each is one microinstruction
            reads = 0
            while reads < reccnt and i < n:
                rec = lines[i].strip()
                i += 1
                if not rec:
                    continue
                # Strip leading '*' if present (relocation marker)
                rec = re.sub(r'^\*\s*', '', rec)
                # Pull integer tokens
                words = []
                for t in rec.split():
                    try:
                        words.append(int(t, radix))
                    except ValueError:
                        pass
                if not words:
                    continue
                # Take the first 4 words = 8 bytes; ignore extra
                # (extra tokens are relocation triplets per LED100 label 2000)
                w4 = (words + [0, 0, 0, 0])[:4]
                bytes_ = words_to_bytes(w4)
                if cur is not None:
                    cur['code'].append((addr0 + reads, bytes_))
                reads += 1

        elif marker == 'END':
            # next line is routine name; consume it
            while i < n and not lines[i].strip(): i += 1
            if i < n: i += 1
            cur = None

        # all other markers (LSB, PB, FPB, AENTRY, ENTRY, EXT, DBDB, DBIB,
        # PARAM, INDEX, TASK, ISR, etc.) — we don't need their payloads
        # for microcode extraction. The ***CODE marker is unambiguous
        # and will resync us automatically. So skip silently.

    return routines, block_counts


def emit(routines, do_split=True, only_routine=None):
    for r in routines:
        if only_routine and r['name'] != only_routine:
            continue
        if not r['code']:
            continue
        print(f'\n; {"=" * 60}')
        print(f'; ROUTINE: {r["name"]} ({len(r["code"])} microinstructions)')
        print(f'; {"=" * 60}')
        for addr, bytes_ in r['code']:
            hex_ = ' '.join(f'{b:02x}' for b in bytes_)
            print(f'  {addr:04o}: {hex_}')
            if do_split:
                fields = split_sim100(bytes_)
                print(f'        ; {fmt_split(fields)}')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('apo_path')
    ap.add_argument('--no-split', action='store_true')
    ap.add_argument('--routine')
    ap.add_argument('--summary', action='store_true')
    ap.add_argument('--list', action='store_true',
                    help='list routine names + sizes')
    args = ap.parse_args()

    routines, counts = parse_apo(args.apo_path)
    total = sum(len(r['code']) for r in routines)
    code_routines = [r for r in routines if r['code']]
    print(f'; APO: {args.apo_path}', file=sys.stderr)
    print(f'; Block counts: {counts}', file=sys.stderr)
    print(f'; Routines (with code): {len(code_routines)} / total {len(routines)}',
          file=sys.stderr)
    print(f'; Total microinstructions: {total}', file=sys.stderr)

    if args.list:
        for r in routines:
            print(f'  {r["name"]:10s} {len(r["code"]):4d} microinstr')
        return

    if not args.summary:
        emit(routines, do_split=not args.no_split,
             only_routine=args.routine)


if __name__ == '__main__':
    main()
