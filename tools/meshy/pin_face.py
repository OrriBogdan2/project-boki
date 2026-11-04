"""Pin's face paint for the texture projection (r2 portrait, docs/art/gen/wardens_r2/pin_portrait), in Blender's
Python (numpy; no PIL):
  blender -b --factory-startup --python tools/meshy/pin_face.py -- PORTRAIT.png OUT.png

- The red handprint over her bone mask is painted out (it matches a real-world movement's symbol and is not
  used): its red pixels, and two pixels round them, are filled from the bone around them (the hood's shadow
  and her hair never feed the fill). The mask's mouth seam it covered is drawn back.
- In its place, four diagonal red-brown claw scratches across the lower face, tapered at both ends, a darker
  core in a lighter wound edge (as her side view draws them on the cheek).
- The alpha is the face region (mask, eyes, brows), feathered at its edge, so only that part projects.
Pixel coordinates are the 2000 x 2000 portrait's (x right, y down).
"""
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pin_inputs import fill, load, poly_mask, save, seg_mask  # noqa: E402

FACE = [(705, 655), (800, 610), (950, 600), (1080, 635), (1150, 700), (1172, 790), (1180, 880), (1150, 1000),
        (1080, 1080), (990, 1126), (900, 1130), (820, 1094), (778, 1030), (748, 948), (716, 860), (702, 760)]
PRINT_BOX = (790, 790, 1180, 1140)        # the handprint's reach
SEAM = [(782, 986), (860, 998), (930, 1001), (1000, 997), (1080, 990), (1132, 980)]
SCRATCH_DIR = np.array([0.6, 0.8])
SCRATCHES = [((812, 842), 235), ((868, 838), 255), ((924, 842), 250), ((978, 856), 215)]
CORE = np.array([0.40, 0.08, 0.07])
EDGE = np.array([0.62, 0.20, 0.16])


def main():
    a = sys.argv[sys.argv.index("--") + 1:]
    px = load(a[0])
    shape = px.shape[:2]
    rgb = px[..., :3]
    box = np.zeros(shape, bool)
    x0, y0, x1, y1 = PRINT_BOX
    box[y0:y1, x0:x1] = True
    face = poly_mask(shape, FACE)
    red = box & face & ((rgb[..., 0] - np.maximum(rgb[..., 1], rgb[..., 2])) > 0.12)
    for _ in range(2):
        red = red | np.roll(red, 1, 0) | np.roll(red, -1, 0) | np.roll(red, 1, 1) | np.roll(red, -1, 1)
    red &= face
    dark = rgb.mean(axis=2) < 0.55
    fill(px, red, skip=(dark | ~face) & ~red)
    rgb = px[..., :3]
    # the mouth seam back where the print hid it
    seam = seg_mask(shape, SEAM, 1.6)
    rgb[seam] = rgb[seam] * 0.45 + np.array([0.30, 0.24, 0.18]) * 0.55
    # the claw scratches
    yy, xx = np.mgrid[0:shape[0], 0:shape[1]]
    d = SCRATCH_DIR / np.linalg.norm(SCRATCH_DIR)
    n = np.array([-d[1], d[0]])
    for (sx, sy), ln in SCRATCHES:
        bx0, bx1 = int(sx - 30), int(sx + d[0] * ln + 30)
        by0, by1 = int(sy - 30), int(sy + d[1] * ln + 30)
        X, Y = xx[by0:by1, bx0:bx1] - sx, yy[by0:by1, bx0:bx1] - sy
        t = (X * d[0] + Y * d[1]) / ln
        s = X * n[0] + Y * n[1]
        wob = 1.2 * np.sin(t * 19.0 + sx * 0.1)
        half = 7.5 * np.clip(np.sin(np.clip(t, 0, 1) * np.pi), 0, 1) ** 0.6
        dist = np.abs(s - wob)
        on = (t >= 0) & (t <= 1) & (dist < half + 1.0)
        edge_a = np.clip(half + 1.0 - dist, 0, 1)
        core = np.clip((half * 0.55 - dist) / 1.5, 0, 1)
        sub = rgb[by0:by1, bx0:bx1]
        col = EDGE[None, None] * (1 - core[..., None]) + CORE[None, None] * core[..., None]
        k = (edge_a * 0.92)[..., None] * on[..., None]
        sub[:] = sub * (1 - k) + col * k
        face[by0:by1, bx0:bx1] |= on
    px[..., :3] = rgb
    # the alpha: the face region, feathered ~16 px
    al = face.astype(np.float32)
    for _ in range(8):
        al = (al + np.roll(al, 2, 0) + np.roll(al, -2, 0) + np.roll(al, 2, 1) + np.roll(al, -2, 1)) / 5.0
    px[..., 3] = np.clip((al - 0.5) * 2.2 + 0.5, 0, 1) * face + 0.0
    save(px, a[1])
    print("PINFACE wrote", a[1])


main()
