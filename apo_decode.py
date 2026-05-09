#!/usr/bin/env python3
"""
FPS-100 .APO file decoder — produces APAL-style disassembly.

The .APO format is the textual ASM100 object-file format consumed by
LED100 (the link editor). This decoder reads .APO files and emits
each CODE block's microinstructions decoded via the canonical SIM100
SPLIT recipe (24 fields per 8-byte microinstruction).

Format derived from LED100.FTN's LOAD subroutine (line 3031). The
file structure spec was produced by Council-of-Clankers (DeepSeek
+ GLM) and consolidated here, with the SPLIT decoder fixed to
match SIM100.FTN's canonical recipe.

Usage:
    python3 apo_decode.py <file.APO> [--no-split] [--routine NAME]
"""
import re, sys, argparse


# Block type table from LED100.FTN line 3370-3376
# (BLKTYP = STOI(SYM,RADIX) + 1)
BLOCK_TYPES = {
    1: 'CODE',          # microinstruction code records → label 1000
    2: 'END',           # → label 3000
    3: 'NU',            # not used → label 90020 (error)
    4: 'TITLE',         # → label 4000
    5: 'ENTRY',         # → label 4400
    6: 'LIB_END',       # → label 5000
    7: 'LIB_START',     # → label 5500
    8: 'DBDB',          # data block declaration block → label 5600
    9: 'DBIB',          # data block instance block → label 6000
    10: 'PARAM',        # parameter description → label 7000
    11: 'ALT_ENTRY',    # alternate entry point → label 8000
    12: 'INDEX_ALT',    # → label 4380
    13: 'INDEX',        # library index block → label 2000
    14: 'TASK',         # → label 9000
    15: 'ISR',          # interrupt service routine → label 10000
}


def split_sim100(reg):
    """
    Canonical SIM100 SPLIT routine (line 3863 of SIM100.FTN), rewritten
    in Python. Decodes 8 bytes into 24 named fields.

      REG[0..7] = the 8 bytes (REG(1) high-byte in MACRO-11 sense)
      Returns dict of {field_name: int_value} for all 24 fields.

    Field meanings (per FPS-7319 AP-120B Programmer's Reference + the
    SPLIT routine itself):
       1  DF      DPX bit-reverse flag                   (1 bit)
       2  SOPF    S-Pad operation                        (3 bits)
       3  SHF     shift                                  (2 bits)
       4  SPSF    S-Pad source register index            (4 bits)
       5  SPDF    S-Pad dest register index              (4 bits)
       6  FADDF   FALU function                          (3 bits)
       7  A1F     FALU input-1 source                    (3 bits)
       8  A2F     FALU input-2 source                    (3 bits)
       9  CONDF   branch condition                       (4 bits)
      10  DISPF   branch displacement / immediate        (5 bits)
      11  DPXF    DPX function                           (2 bits)
      12  DPYF    DPY function                           (2 bits)
      13  DPBSF   DP-Bus select                          (3 bits)
      14  XRF     DPX read addr                          (3 bits)
      15  YRF     DPY read addr                          (3 bits)
      16  XWF     DPX write addr                         (3 bits)
      17  YWF     DPY write addr                         (3 bits)
      18  FMF     FMUL fire                              (1 bit)
      19  M1F     FMUL input-1 source                    (2 bits)
      20  M2F     FMUL input-2 source                    (2 bits)
      21  MIF     memory input                           (2 bits)
      22  MAF     memory address function (MAF=1=INCMA)  (2 bits)
      23  DPAF    DP address                             (2 bits)
      24  TMAF    TM address                             (2 bits)
    """
    R = reg
    fv = [0] * 25  # 1-indexed
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


def fmt_split(fields):
    """Format a SPLIT result as a compact APAL-style mnemonic line."""
    nonzero = [f'{k}={v}' for k, v in fields.items() if v != 0]
    return ' '.join(nonzero) if nonzero else '(no-op)'


# ----- .APO format parser -----

class ApoParser:
    """
    Read a .APO file as a stream of records. Each record is one line
    of column-formatted decimal numbers possibly followed by a string
    payload (TITLE name, etc.).

    Per LED100 LOAD subroutine: each record's first integer is
    BLKTYP-1 (zero-indexed), then per-block-type fields follow.
    """

    def __init__(self, path):
        with open(path, errors='replace') as f:
            text = f.read().replace('\r', '')
        # Split on newlines, drop blanks
        self.lines = [l for l in text.split('\n') if l.strip() != '']
        self.idx = 0
        self.radix = 8  # APAL default; can be overridden by ***RADIX
        self.routines = []  # list of {name, code: [(addr, [bytes])]}
        self.cur_routine = None
        self.block_counts = {}

    def _consume_line(self):
        if self.idx >= len(self.lines):
            return None
        l = self.lines[self.idx]
        self.idx += 1
        return l

    def _parse_tokens(self, line):
        """
        Pull integer tokens out of a record line. Stops at any '***'
        marker or string-payload section.
        """
        # Strip trailing comment-marker like "***LSB" if present
        line = re.sub(r'\*\*\*.*$', '', line).strip()
        toks = []
        for tok in line.split():
            try:
                toks.append(int(tok, self.radix))
            except ValueError:
                pass
        return toks

    def parse(self):
        while self.idx < len(self.lines):
            self._parse_one_block()

    def _parse_one_block(self):
        line = self._consume_line()
        if line is None: return
        # Detect block type from first token
        toks = self._parse_tokens(line)
        if not toks:
            return  # skip blank/garbage
        blktyp_field = toks[0]
        # LED100: BLKTYP = STOI(SYM,RADIX) + 1
        blktyp = blktyp_field + 1
        block = BLOCK_TYPES.get(blktyp, f'UNK_{blktyp}')
        self.block_counts[block] = self.block_counts.get(block, 0) + 1

        if block == 'TITLE':
            # Next line is the title string (the routine name)
            name_line = self._consume_line()
            if name_line is not None:
                name = name_line.strip()
                self.cur_routine = {'name': name, 'code': []}
                self.routines.append(self.cur_routine)
        elif block == 'CODE':
            # Per LED100 line 1020-1100:
            # next two tokens of *this* record are RECCNT, LOC
            # then RECCNT data records follow, each one microinstr
            if len(toks) >= 3:
                reccnt, loc = toks[1], toks[2]
            elif len(toks) >= 2:
                reccnt, loc = toks[1], 0
            else:
                # missing — try to read from next line
                hdr2 = self._consume_line()
                t2 = self._parse_tokens(hdr2 or '')
                reccnt, loc = (t2[0], t2[1]) if len(t2) >= 2 else (0, 0)

            for i in range(reccnt):
                data_line = self._consume_line()
                if data_line is None: break
                # Each record contains 8 bytes of one microinstruction
                # The bytes are decimal integers in the file's RADIX
                bytes_ = self._parse_tokens(data_line)
                # Pad/truncate to exactly 8 bytes
                while len(bytes_) < 8:
                    extra = self._consume_line()
                    if extra is None: break
                    bytes_ += self._parse_tokens(extra)
                bytes_ = bytes_[:8]
                # Mask each to 0..255
                bytes_ = [b & 0xFF for b in bytes_]
                if self.cur_routine and len(bytes_) == 8:
                    self.cur_routine['code'].append((loc + i, bytes_))
        elif block == 'END':
            # routine boundary; no payload to consume
            pass
        elif block in ('LIB_START', 'LIB_END', 'NU'):
            pass  # informational
        elif block in ('ENTRY', 'ALT_ENTRY'):
            # Next line(s) usually contain symbol name + address
            self._consume_line()
        elif block in ('TASK', 'ISR'):
            self._consume_line()
        elif block == 'INDEX':
            # j entries follow; skip data record + j entry records
            if len(toks) >= 2:
                j = toks[1]
                self._consume_line()  # data record
                for _ in range(j):
                    self._consume_line()
        else:
            # Unknown block — skip its likely payload line if any
            pass


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
    ap = argparse.ArgumentParser(description='FPS-100 .APO decoder')
    ap.add_argument('apo_path', help='path to .APO file')
    ap.add_argument('--no-split', action='store_true',
                    help='skip SPLIT field decoding')
    ap.add_argument('--routine', help='only emit named routine')
    ap.add_argument('--summary', action='store_true',
                    help='print block counts only')
    args = ap.parse_args()

    p = ApoParser(args.apo_path)
    p.parse()
    print(f'; FPS-100 .APO decode: {args.apo_path}', file=sys.stderr)
    print(f'; Block counts: {p.block_counts}', file=sys.stderr)
    print(f'; Routines: {len(p.routines)}', file=sys.stderr)
    total_instr = sum(len(r['code']) for r in p.routines)
    print(f'; Total microinstructions: {total_instr}', file=sys.stderr)

    if not args.summary:
        emit(p.routines, do_split=not args.no_split,
             only_routine=args.routine)


if __name__ == '__main__':
    main()
