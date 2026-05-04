#!/usr/bin/env python3
"""
Files-11 ODS-1 reader for RSX-11M+ RX02 floppy images.

Image layout (verified against SimH RY device + sim_disk.c source):
  - 77 tracks × 26 sectors × 256 bytes = 500,032 raw bytes
  - 12,480 bytes of additional padding/duplicate-sector data → 512,512 byte file
  - Files-11 LBN = 2 physical 256-byte sectors
  - LBN N's two halves live at LBA 2N and 2N+1, each translated to a
    physical sector (PSA) by RX02 interleave (2:1 with skew 6, track 0
    skipped so PSA = sector + track*26 + 26).

  PSA(lba) = ((((lba mod 26) * 2) + (1 if (lba mod 26) * 2 >= 26 else 0)
              + (lba // 26) * 6) mod 26) + (lba // 26) * 26 + 26
  byte_offset = PSA * 256
"""
import struct, sys, os
from collections import namedtuple

NSECT, INTER, SKEW = 26, 2, 6
TRACK0_OFFSET = NSECT             # skip track 0 (boot reserved)
SECT_BYTES = 256

def lba_to_psa(lba):
    """Map a 256-byte logical sector index to physical sector index in image."""
    track = lba // NSECT
    i = (lba % NSECT) * INTER
    if i >= NSECT:
        i += 1
    sector = (i + track * SKEW) % NSECT
    return sector + track * NSECT + TRACK0_OFFSET

def read_lbn(image, lbn, count=1):
    """Read `count` consecutive Files-11 logical blocks (each 512 bytes)."""
    out = bytearray()
    for n in range(count):
        for half in range(2):
            lba = (lbn + n) * 2 + half
            psa = lba_to_psa(lba)
            o = psa * SECT_BYTES
            out += image[o:o + SECT_BYTES]
    return bytes(out)

def rad50_decode(word):
    chars = " ABCDEFGHIJKLMNOPQRSTUVWXYZ$.?0123456789"
    a = word // 1600
    b = (word // 40) % 40
    c = word % 40
    if a >= 40 or b >= 40 or c >= 40:
        return "???"
    return chars[a] + chars[b] + chars[c]

def parse_home_block(blk):
    """Parse the ODS-1 home block (DEC's HM1 layout)."""
    if len(blk) != 512:
        raise ValueError("home block must be 512 bytes")
    h = {}
    h['ibsz']    = struct.unpack('<H', blk[0:2])[0]
    # H.IBLB is 4 bytes split high-low (PDP-11 convention)
    iblb_hi, iblb_lo = struct.unpack('<HH', blk[2:6])
    h['iblb']    = (iblb_hi << 16) | iblb_lo
    h['fmax']    = struct.unpack('<H', blk[6:8])[0]
    h['cluster'] = struct.unpack('<H', blk[8:10])[0]
    h['dvty']    = struct.unpack('<H', blk[10:12])[0]
    h['vlev']    = struct.unpack('<H', blk[12:14])[0]
    h['vnam']    = blk[14:26].decode('ascii', 'replace').rstrip(' \x00')
    h['vown']    = struct.unpack('<H', blk[30:32])[0]
    h['vpro']    = struct.unpack('<H', blk[32:34])[0]
    # Volume label (formatted) and format-id near end of home block
    h['vlbl']    = blk[472:484].decode('ascii', 'replace').rstrip(' \x00')
    h['vidx']    = blk[484:496].decode('ascii', 'replace').rstrip(' \x00')
    h['fmt']     = blk[496:508].decode('ascii', 'replace').rstrip(' \x00')
    h['chk1']    = struct.unpack('<H', blk[58:60])[0]    # checksum 1 location
    h['chk2']    = struct.unpack('<H', blk[508:510])[0]
    return h

FileHeader = namedtuple('FileHeader',
    'fnum fseq fname ftyp fver retrieval_pointers used_blocks')

def parse_file_header(blk):
    """Parse a 512-byte file header. Returns FileHeader or None if empty."""
    if len(blk) != 512: return None
    if all(b == 0 for b in blk[:32]): return None
    idof = blk[0]
    mpof = blk[1]
    fnum = struct.unpack('<H', blk[2:4])[0]
    fseq = struct.unpack('<H', blk[4:6])[0]
    if fnum == 0: return None
    o = idof * 2
    if o + 10 > 512: return None
    w1, w2, w3, w4 = struct.unpack('<HHHH', blk[o:o+8])
    fname = (rad50_decode(w1) + rad50_decode(w2) + rad50_decode(w3)).rstrip()
    ftyp  = rad50_decode(w4).rstrip()
    fver  = struct.unpack('<h', blk[o+8:o+10])[0]
    m = mpof * 2
    if m + 10 > 512: return None
    # ODS-1 ODS1_Retreval struct (per SimH/DEC):
    #   m+0  ex_segnum (1B)
    #   m+1  ex_rvn (1B)
    #   m+2  ex_filnum (2B)
    #   m+4  ex_filseq (2B)
    #   m+6  CTSZ (1B)
    #   m+7  LBSZ (1B)
    #   m+8  USE (1B, count of words used in pointer area)
    #   m+9  AVAIL (1B, max words available)
    #   m+10..  retrieval pointers
    ctsz = blk[m+6]
    lbsz = blk[m+7]
    use_ = blk[m+8]    # words used
    max_ = blk[m+9]
    ptrs = []
    p = m + 10
    end = min(m + 10 + use_*2, 512)
    used_blocks = 0
    while p + 4 <= end:
        if ctsz == 1 and lbsz == 3:
            hi  = blk[p]
            cnt = blk[p+1] + 1
            lo  = struct.unpack('<H', blk[p+2:p+4])[0]
            lbn = (hi << 16) | lo
            if cnt == 0: break
            ptrs.append((lbn, cnt))
            used_blocks += cnt
            p += 4
        else:
            break
    return FileHeader(fnum, fseq, fname, ftyp, fver, ptrs, used_blocks)

def read_file(image, hdr, max_bytes=None):
    out = bytearray()
    for lbn, cnt in hdr.retrieval_pointers:
        out += read_lbn(image, lbn, cnt)
        if max_bytes and len(out) >= max_bytes: break
    return bytes(out)

def parse_directory(blk):
    """Parse a directory file's contents (sequence of 16-byte entries)."""
    entries = []
    for i in range(0, len(blk), 16):
        e = blk[i:i+16]
        if len(e) < 16: break
        fnum = struct.unpack('<H', e[0:2])[0]
        if fnum == 0: continue
        fseq = struct.unpack('<H', e[2:4])[0]
        fvol = struct.unpack('<H', e[4:6])[0]
        w1, w2, w3, w4 = struct.unpack('<HHHH', e[6:14])
        fname = (rad50_decode(w1) + rad50_decode(w2) + rad50_decode(w3)).rstrip()
        ftyp  = rad50_decode(w4).rstrip()
        fver  = struct.unpack('<h', e[14:16])[0]
        entries.append({'fnum':fnum, 'fseq':fseq, 'name':fname, 'type':ftyp, 'ver':fver})
    return entries

class Volume:
    def __init__(self, image_path):
        self.path = image_path
        with open(image_path, 'rb') as f:
            self.image = f.read()
        # Files-11 home block lives at LBN 1
        self.home = parse_home_block(read_lbn(self.image, 1))
        # iblb + ibsz is the start of the static-area file-header region
        self.idx_start = self.home['iblb'] + self.home['ibsz']
        # Bootstrap: read INDEXF.SYS (file 1) header from its static-area location,
        # then follow its own retrieval pointers to read the entire index file.
        # Index file layout: [boot(LBN 0), home(LBN 1), bitmap(ibsz blocks),
        #                     file 1's header, file 2's header, ...]
        h1 = parse_file_header(read_lbn(self.image, self.idx_start))
        if h1 is None:
            raise ValueError("INDEXF.SYS header not parseable")
        self.indexf = read_file(self.image, h1)
        # File N's header in INDEXF.SYS is at offset (2 + ibsz + (N-1)) * 512:
        #   skip boot (1 block) + home (1 block) + bitmap (ibsz blocks)
        self._hdr_base = (2 + self.home['ibsz']) * 512

    def read_header(self, fnum):
        o = self._hdr_base + (fnum - 1) * 512
        if o + 512 > len(self.indexf):
            return None
        h = parse_file_header(self.indexf[o:o+512])
        # Reject obviously corrupt headers (filename outside ASCII)
        if h is None:
            return None
        if not all(c == ' ' or 'A' <= c <= 'Z' or '0' <= c <= '9' or c in '$.?'
                   for c in (h.fname + h.ftyp)):
            return None
        if h.fnum != fnum:  # sanity: header self-id should match
            return None
        return h

    def read_file(self, fnum):
        h = self.read_header(fnum)
        return None if h is None else read_file(self.image, h)

    def list_dir(self, fnum):
        data = self.read_file(fnum)
        return [] if data is None else parse_directory(data)

def fmt_name(e):
    n = e['name'].strip() or '?'
    t = e['type'].strip()
    s = f"{n}.{t}" if t else n
    return f"{s};{e['ver']}"

def main():
    if len(sys.argv) < 2:
        print("usage: ods1.py <image>")
        sys.exit(1)
    img = sys.argv[1]
    v = Volume(img)
    print(f"=== {os.path.basename(img)} ===")
    print(f"Volume: '{v.home['vnam']}' fmt='{v.home['fmt']}' fmax={v.home['fmax']} "
          f"vlev=0x{v.home['vlev']:04x} ibsz={v.home['ibsz']} iblb={v.home['iblb']}")
    print(f"Index file headers start at LBN {v.idx_start}")
    print(f"Owner UIC: [{v.home['vown']>>8:o},{v.home['vown']&0xff:o}]")
    print()
    print("--- MFD (file 4) ---")
    for e in v.list_dir(4):
        h = v.read_header(e['fnum'])
        sz = h.used_blocks * 512 if h else 0
        print(f"  [{e['fnum']:5d},{e['fseq']:5d}] {fmt_name(e):<22s} {sz:>8d} bytes")

if __name__ == "__main__":
    main()
