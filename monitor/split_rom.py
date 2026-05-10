#!/usr/bin/env python3
"""Split a 64 KB joined ROM into the two 32 KB EPROM images that
would have been blown into the U11 / U12 sockets on the M68KVM02.

The MC68000 has a 16-bit data bus; each 16-bit word at an EVEN
address is split:
    D15..D8  (high byte) <- chip in the EVEN socket
    D7..D0   (low  byte) <- chip in the ODD socket

The original ROM filename in this project is `FPS3K_U11_U12_JOIN.bin`
and was reconstructed by interleaving the two 32 KB EPROM reads.
We empirically verified against the original `FPS3K_U11.bin` /
`FPS3K_U12.bin` split (in the prior versabus project) that the
M68KVM02 board uses this convention:

    U11 = LOW  byte ROM  (odd  addresses, D7..D0)
    U12 = HIGH byte ROM  (even addresses, D15..D8)

Pass --swap if a different board pairs them the other way.

Usage:
    split_rom.py FPS3K_with_monitor.bin
    split_rom.py FPS3K_with_monitor.bin --swap
"""
import sys
import argparse

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('rom', help='joined 64 KB ROM image')
    ap.add_argument('--swap', action='store_true',
                    help='write LOW byte to U11 and HIGH to U12 '
                         '(if your board uses that convention)')
    args = ap.parse_args()

    data = open(args.rom, 'rb').read()
    if len(data) != 65536:
        print(f'WARN: expected 64 KB image, got {len(data)} bytes',
              file=sys.stderr)

    high = bytes(data[i]   for i in range(0, len(data), 2))    # even addrs
    low  = bytes(data[i+1] for i in range(0, len(data), 2))    # odd addrs

    base = args.rom.rsplit('.', 1)[0]
    if args.swap:
        u11_name, u11_blob = f'{base}_U11_hi.bin', high
        u12_name, u12_blob = f'{base}_U12_lo.bin', low
    else:
        u11_name, u11_blob = f'{base}_U11_lo.bin', low
        u12_name, u12_blob = f'{base}_U12_hi.bin', high

    open(u11_name, 'wb').write(u11_blob)
    open(u12_name, 'wb').write(u12_blob)

    print(f'  {u11_name} ({len(u11_blob)} bytes)')
    print(f'  {u12_name} ({len(u12_blob)} bytes)')

    # Sanity verify: re-interleave and compare
    rejoined = bytearray(len(data))
    for i in range(0, len(data), 2):
        rejoined[i]   = high[i//2]
        rejoined[i+1] = low [i//2]
    if bytes(rejoined) == data:
        print('  ✓ round-trip verified (interleave reconstructs original)')
    else:
        print('  ✗ ROUND-TRIP FAILED', file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
