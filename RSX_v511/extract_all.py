#!/usr/bin/env python3
"""Extract all files from each RSX-11 disk image into per-volume folders."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__) or '.')
from ods1 import Volume, fmt_name, read_file

def safe_filename(name, typ, ver):
    n = name.strip().replace('/', '_').replace('\\', '_')
    t = typ.strip()
    fn = f"{n}.{t}" if t else n
    if ver and ver != 1:
        fn += f";{ver}"
    return fn

def extract_image(img_path, dest_root):
    name = os.path.splitext(os.path.basename(img_path))[0]
    dest = os.path.join(dest_root, name)
    os.makedirs(dest, exist_ok=True)
    try:
        v = Volume(img_path)
    except Exception as e:
        print(f"  {name}: FAILED to open: {e}")
        return 0, 0
    info = open(os.path.join(dest, "_VOLUME.txt"), "w")
    info.write(f"Volume: {v.home['vnam']!r}\n")
    info.write(f"Format: {v.home['fmt']!r}\n")
    info.write(f"Owner UIC: [{v.home['vown']>>8:o},{v.home['vown']&0xff:o}]\n")
    info.write(f"Max files: {v.home['fmax']}\n")
    info.write(f"Index file LBN: {v.idx_start}\n\n")

    n_ok, n_err = 0, 0
    mfd = v.list_dir(4)
    info.write("MFD entries:\n")
    for e in mfd:
        info.write(f"  [{e['fnum']:5d},{e['fseq']:5d}] {fmt_name(e)}\n")
    info.write("\n")

    # also dump the system files (INDEXF, BITMAP, BADBLK, MFD, CORIMG)
    sys_dir = os.path.join(dest, "_SYSTEM")
    os.makedirs(sys_dir, exist_ok=True)

    for e in mfd:
        if e['type'] == 'DIR' and e['fnum'] != 4:
            ufd_name = e['name'].strip()
            ufd_dir = os.path.join(dest, ufd_name)
            os.makedirs(ufd_dir, exist_ok=True)
            try:
                contents = v.list_dir(e['fnum'])
            except Exception as ex:
                info.write(f"!! UFD {ufd_name} parse error: {ex}\n")
                continue
            info.write(f"\n{ufd_name}/ ({len(contents)} entries):\n")
            for c in contents:
                fn = safe_filename(c['name'], c['type'], c['ver'])
                info.write(f"  {fn}\n")
                try:
                    h = v.read_header(c['fnum'])
                    if h is None or not h.retrieval_pointers:
                        # zero-byte file or unreadable header; create empty
                        open(os.path.join(ufd_dir, fn), 'wb').close()
                        n_ok += 1
                        continue
                    data = read_file(v.image, h)
                    out_path = os.path.join(ufd_dir, fn)
                    with open(out_path, 'wb') as fp:
                        fp.write(data)
                    n_ok += 1
                except Exception as ex:
                    info.write(f"    EXTRACTION ERROR: {ex}\n")
                    n_err += 1
        else:
            # system file at MFD level
            fn = safe_filename(e['name'], e['type'], e['ver'])
            try:
                h = v.read_header(e['fnum'])
                if h is None:
                    open(os.path.join(sys_dir, fn), 'wb').close()
                    continue
                data = read_file(v.image, h)
                with open(os.path.join(sys_dir, fn), 'wb') as fp:
                    fp.write(data)
                n_ok += 1
            except Exception as ex:
                info.write(f"  SYS file {fn} error: {ex}\n")
                n_err += 1
    info.close()
    return n_ok, n_err

if __name__ == "__main__":
    here = os.path.dirname(__file__) or '.'
    dest_root = os.path.join(here, "extracted")
    os.makedirs(dest_root, exist_ok=True)
    total_ok, total_err = 0, 0
    for img in sorted(os.listdir(here)):
        if img.endswith('.img'):
            ok, err = extract_image(os.path.join(here, img), dest_root)
            print(f"  {img}: {ok} ok, {err} errors")
            total_ok += ok
            total_err += err
    print(f"\nTotal: {total_ok} files extracted, {total_err} errors")
    print(f"Destination: {dest_root}")
