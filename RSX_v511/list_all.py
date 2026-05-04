#!/usr/bin/env python3
"""Generate a complete directory listing across all 15 RSX disks."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from ods1 import Volume, fmt_name

def list_one(img, out):
    try:
        v = Volume(img)
    except Exception as e:
        out.write(f"\n=== {os.path.basename(img)}: ERROR {e}\n")
        return
    out.write(f"\n=== {os.path.basename(img)} : volume '{v.home['vnam']}' "
              f"fmt={v.home['fmt']!r} fmax={v.home['fmax']} ===\n")
    mfd = v.list_dir(4)
    for e in mfd:
        if e['type'] == 'DIR' and e['fnum'] != 4:
            out.write(f"\n  {fmt_name(e)}  (UFD, file {e['fnum']}):\n")
            try:
                contents = v.list_dir(e['fnum'])
            except Exception as ex:
                out.write(f"    (parse error: {ex})\n")
                continue
            for c in contents:
                try:
                    ch = v.read_header(c['fnum'])
                    csz = ch.used_blocks * 512 if ch else 0
                except Exception:
                    csz = 0
                out.write(f"    [{c['fnum']:5d},{c['fseq']:5d}] "
                          f"{fmt_name(c):<22s} {csz:>8d}\n")
        else:
            try:
                h = v.read_header(e['fnum'])
                sz = h.used_blocks * 512 if h else 0
            except Exception:
                sz = 0
            out.write(f"  [{e['fnum']:5d},{e['fseq']:5d}] "
                      f"{fmt_name(e):<22s} {sz:>8d}\n")

if __name__ == "__main__":
    here = os.path.dirname(__file__) or '.'
    out_path = os.path.join(here, "DIRECTORY_LISTING.txt")
    with open(out_path, "w") as out:
        out.write("RSX-11M+ V5.1.1 distribution - complete directory listing\n")
        out.write("=" * 70 + "\n")
        for img in sorted(os.listdir(here)):
            if img.endswith('.img'):
                list_one(os.path.join(here, img), out)
    print(f"wrote {out_path}")
