#!/usr/bin/env python3
"""Bake art/vfx/noise.png, the tiling noise the Hero VFX shaders sample instead of computing it per pixel.

R: billows (a dome over each cell, two octaves): the lumpy outline and fake relief of a cel smoke puff.
G: smooth value-noise fbm: erosion thresholds and wobble.
B: cell walls (F2 - F1): cracks and ice crackle.
Stdlib only and seeded, so a rerun writes the same file: python3 tools/gen_vfx_noise.py
"""
import math
import random
import struct
import zlib
from pathlib import Path

SIZE = 256          # px per side; every channel tiles
SEED = 1110
OUT = Path(__file__).resolve().parent.parent / "art" / "vfx" / "noise.png"


def cell_points(cells, rng):
    return [[(rng.random(), rng.random()) for _ in range(cells)] for _ in range(cells)]


def worley(x, y, cells, pts):
    """F1 and F2 distances (in cell units) at x, y in 0..1, wrapping so the tile repeats."""
    gx, gy = x * cells, y * cells
    ix, iy = int(gx), int(gy)
    f1 = f2 = 9.0
    for oy in (-1, 0, 1):
        for ox in (-1, 0, 1):
            cx, cy = ix + ox, iy + oy
            px, py = pts[cy % cells][cx % cells]
            d = math.hypot(cx + px - gx, cy + py - gy)
            if d < f1:
                f1, f2 = d, f1
            elif d < f2:
                f2 = d
    return f1, f2


def value_fbm(x, y, lattices):
    v, amp, total = 0.0, 0.5, 0.0
    for period, grid in lattices:
        gx, gy = x * period, y * period
        ix, iy = int(gx), int(gy)
        fx, fy = gx - ix, gy - iy
        ux, uy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        a = grid[iy % period][ix % period]
        b = grid[iy % period][(ix + 1) % period]
        c = grid[(iy + 1) % period][ix % period]
        d = grid[(iy + 1) % period][(ix + 1) % period]
        v += amp * (a + (b - a) * ux + (c - a) * uy + (a - b - c + d) * ux * uy)
        total += amp
        amp *= 0.5
    return v / total


def png(path, w, h, rows):
    raw = b"".join(b"\x00" + bytes(r) for r in rows)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    head = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", head) + chunk(b"IDAT", zlib.compress(raw, 9))
                     + chunk(b"IEND", b""))


def main():
    rng = random.Random(SEED)
    billow_lo, billow_hi = cell_points(6, rng), cell_points(13, rng)
    crack = cell_points(8, rng)
    lattices = [(p, [[rng.random() for _ in range(p)] for _ in range(p)]) for p in (4, 8, 16, 32)]
    rows = []
    for j in range(SIZE):
        row = []
        y = j / SIZE
        for i in range(SIZE):
            x = i / SIZE
            lo, _ = worley(x, y, 6, billow_lo)
            hi, _ = worley(x, y, 13, billow_hi)
            billow = math.sqrt(max(0.0, 1.0 - lo * lo)) * 0.72 + math.sqrt(max(0.0, 1.0 - hi * hi)) * 0.28
            f1, f2 = worley(x, y, 8, crack)
            row += [round(min(billow, 1.0) * 255), round(value_fbm(x, y, lattices) * 255),
                    round(min((f2 - f1) * 1.6, 1.0) * 255)]
        rows.append(row)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    png(OUT, SIZE, SIZE, rows)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
