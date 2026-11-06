#!/usr/bin/env python3
"""Generate the anti-aliased TGA textures used by ForeverTouch.

WoW loads uncompressed 32-bit TGA files whose sides are powers of two.
All textures are white so the addon can tint them with SetVertexColor.
Run:  python3 tools/make_textures.py
"""
import math
import os
import struct
import sys

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ForeverTouch", "media")
SIZE = 128
SS = 4  # supersampling per axis


def write_tga(path, size, alpha_fn):
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, size, size, 32, 0x28)
    rows = bytearray()
    for y in range(size):
        for x in range(size):
            acc = 0.0
            for sy in range(SS):
                for sx in range(SS):
                    # normalised coords in [-1, 1]
                    u = ((x + (sx + 0.5) / SS) / size) * 2 - 1
                    v = ((y + (sy + 0.5) / SS) / size) * 2 - 1
                    acc += alpha_fn(u, v)
            a = max(0, min(255, int(round(acc / (SS * SS) * 255))))
            rows += bytes((255, 255, 255, a))  # BGRA
    with open(path, "wb") as f:
        f.write(header)
        f.write(rows)


def circle(u, v):
    return 1.0 if u * u + v * v <= 0.97 * 0.97 else 0.0


def ring(u, v):
    d = math.hypot(u, v)
    return 1.0 if 0.82 <= d <= 0.97 else 0.0


def thin_ring(u, v):
    d = math.hypot(u, v)
    return 1.0 if 0.90 <= d <= 0.97 else 0.0


def glow(u, v):
    d = math.hypot(u, v)
    if d >= 1.0:
        return 0.0
    # soft halo peaking near the rim of a button
    peak = 0.72
    if d < peak:
        return (d / peak) ** 3 * 0.9
    return 0.9 * (1 - (d - peak) / (1 - peak)) ** 1.6


def soft(u, v):
    d = math.hypot(u, v)
    return max(0.0, 1 - d) ** 1.8


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in (("circle", circle), ("ring", ring), ("thinring", thin_ring), ("glow", glow), ("soft", soft)):
        path = os.path.join(OUT, name + ".tga")
        write_tga(path, SIZE, fn)
        print("wrote", os.path.relpath(path))


if __name__ == "__main__":
    sys.exit(main())
