#!/usr/bin/env python3
"""Patch FPS-3000 ROM with the monitor.

Two patch modes:
  --reset    Replace reset PC ($F00004) with monitor entry ($F0A825).
             Bypasses normal boot — drops directly into monitor.
  --panic    Replace F0A27A (the panic catch-all) with JMP $F0A825.
             Normal boot proceeds; monitor only runs on unhandled
             exceptions.  The default.
  --both     Apply both patches.

Outputs FPS3K_U11_U12_JOIN_with_monitor.bin in the same dir as
the source ROM.
"""

import sys
import argparse
import struct

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('rom', help='source ROM image')
    ap.add_argument('monitor', help='assembled monitor.bin')
    ap.add_argument('out', help='patched output ROM')
    ap.add_argument('--reset', action='store_true', help='patch reset PC')
    ap.add_argument('--panic', action='store_true', help='patch F0A27A panic')
    args = ap.parse_args()

    if not (args.reset or args.panic):
        args.panic = True

    rom = bytearray(open(args.rom, 'rb').read())
    mon = open(args.monitor, 'rb').read()

    if len(rom) != 65536:
        print(f'WARN: ROM size {len(rom)} != 65536', file=sys.stderr)

    MON_BASE  = 0xA826    # ROM offset = F0A826 — monitor_cold
    MON_ENTRY = 0xA840    # ROM offset = F0A840 — monitor_entry
    if MON_BASE + len(mon) > len(rom):
        print(f'ERROR: monitor would overflow ROM end '
              f'({MON_BASE + len(mon):X} > {len(rom):X})', file=sys.stderr)
        sys.exit(1)

    # Verify the destination region is currently free (mostly zeros)
    region = rom[MON_BASE:MON_BASE + len(mon)]
    nonzero = sum(1 for b in region if b != 0)
    if nonzero > 32:
        print(f'WARN: target region has {nonzero} non-zero bytes — overwriting',
              file=sys.stderr)

    # Place monitor
    rom[MON_BASE:MON_BASE + len(mon)] = mon
    print(f'  monitor.bin ({len(mon)} bytes) placed at F0{MON_BASE:04X}')

    if args.reset:
        # Reset PC at offset $4 in ROM = address $F00004 (read at reset
        # via the M68KVM02 reset overlay)
        old_pc = struct.unpack('>I', bytes(rom[4:8]))[0]
        new_pc = 0xF00000 + MON_BASE
        rom[4:8] = struct.pack('>I', new_pc)
        print(f'  reset PC: {old_pc:08X} -> {new_pc:08X}')

    if args.panic:
        # F0A27A: 30 3C 02 A6 60 00 02 FE
        #         (move.w #$2A6,d0; bra.w F0A57E)
        # Patch to: JMP $F0A825 = 4E F9 00 F0 A8 25
        target = 0xF00000 + MON_ENTRY
        patch = bytes([0x4E, 0xF9]) + struct.pack('>I', target)
        rom[0xA27A:0xA27A + len(patch)] = patch
        print(f'  panic vector F0A27A -> JMP ${target:08X} (monitor_entry)')

    # ------------------------------------------------------------------
    # Restore the image checksum.
    #
    # The stock ROM's final word ($F0FFFE) is the XOR of every preceding
    # 16-bit word, so the whole image XORs to zero.  Nothing in the
    # firmware verifies this -- see CLAUDE.md -- but an EPROM programmer,
    # a factory tool or the VM02 monitor may, and every patched image
    # this script produced before 2026-07-29 left it broken.
    # Recompute so the patched image XORs to zero again.
    x = 0
    for i in range(0, len(rom) - 2, 2):
        x ^= (rom[i] << 8) | rom[i + 1]
    old_ck = (rom[-2] << 8) | rom[-1]
    rom[-2] = (x >> 8) & 0xFF
    rom[-1] = x & 0xFF
    print(f'  image checksum: ${old_ck:04X} -> ${x:04X} (whole image now XORs to 0)')

    open(args.out, 'wb').write(bytes(rom))
    print(f'Wrote {args.out} ({len(rom)} bytes)')

if __name__ == '__main__':
    main()
