"""Pin's Meshy inputs (r2 art: docs/art/gen/wardens_r2/pin_turnaround + pin_side), in Blender's Python (numpy; no PIL):
  blender -b --factory-startup --python tools/meshy/pin_inputs.py -- TURNAROUND.png SIDE.png OUT_DIR

Four views go to Meshy, front first: the turnaround's front, 3/4 and back, and the side view (a true profile with
planted boots; it stands in for the turnaround's near profile, whose feet float). Nothing is mirrored: the bow is
in her LEFT hand, the arrow in her RIGHT, the quiver over her right shoulder, as drawn. In each view:
- the bow, its string and the loose arrow are painted out (bands along their centrelines, filled from the band's
  edges inward), keeping the fists that hold them; the bow is its own `weapon` piece (built in the fit);
- the smoke round her shins and boots is painted out (grey, unsaturated pixels outside her legs), and the ground
  shadows and the ground line below the soles go too: she stands on planted boots, the smoke is in-game FX only;
- the red smoke wisps off the cape's ends are painted out (light pixels in their boxes);
- the red handprint over her mask is painted out (red pixels inside the mask, filled from the bone around them):
  it matches a real-world movement's symbol and is not used; the fit paints claw scratches in its place.
Each view is cut to the figure, padded square on the sheet's grey and enlarged to >= 1024 px (view0..3.png);
the full-size cleaned sheets (turnaround_clean.png, side_clean.png) are kept for the texture projection.
"""
import json
import os
import sys

import bpy
import numpy as np

# Sheet pixels on the 2000 x 848 turnaround (x right, y down) and the 1493 x 2000 side view.
FRONT = {
    "crop": [8, 55, 505, 742],
    "bands": [
        # the bow: limb centreline, then the string
        ([(490, 70), (470, 100), (467, 127), (470, 167), (477, 210), (482, 250), (480, 290), (470, 323), (457, 343),
          (450, 370), (447, 383), (437, 423), (433, 457), (430, 490), (417, 523), (397, 557), (377, 590), (363, 623),
          (360, 650), (363, 676)], 14),
        ([(470, 97), (440, 200), (430, 250), (402, 380), (383, 483), (367, 600), (362, 640)], 5),
        # the arrow in her right hand
        ([(158, 348), (200, 455), (239, 558)], 7),
        ([(228, 525), (240, 560)], 10),
    ],
    "keep": [(436, 374, 464, 403), (173, 398, 207, 434)],          # the fists
    "smoke": {"box": (200, 551, 365, 742), "legs": [
        [(250, 550), (297, 550), (300, 650), (302, 703), (297, 727), (288, 735), (280, 733), (272, 717), (268, 693),
         (265, 660), (257, 617), (250, 570)],
        [(300, 550), (347, 550), (343, 617), (333, 660), (327, 690), (318, 698), (310, 697), (307, 683), (302, 650)]]},
    "wisps": [(8, 290, 150, 480)],
    "clear": [(350, 712, 505, 742), (8, 736, 505, 742)],
    "mask": (283, 153, 320, 192),
}
THREE_Q = {
    "crop": [505, 55, 1000, 742],
    "bands": [
        ([(987, 82), (975, 115), (967, 150), (972, 200), (980, 250), (977, 290), (962, 330), (947, 360), (935, 390),
          (925, 425), (925, 460), (910, 500), (880, 540), (850, 580), (835, 615), (830, 650), (832, 662)], 14),
        ([(968, 118), (960, 143), (880, 407), (845, 620), (832, 655)], 6),
        ([(660, 352), (708, 455), (757, 553)], 7),
    ],
    "keep": [(920, 371, 952, 407), (686, 391, 718, 429)],
    "smoke": {"box": (665, 551, 880, 742), "legs": [
        [(725, 540), (760, 540), (758, 590), (757, 640), (760, 693), (758, 720), (752, 727), (745, 723), (735, 707),
         (728, 687), (730, 647), (727, 607)],
        [(760, 550), (810, 547), (808, 590), (803, 623), (807, 650), (803, 673), (798, 687), (793, 687), (783, 670),
         (775, 650), (767, 623), (763, 590)]]},
    "wisps": [(505, 310, 610, 480)],
    "clear": [(880, 690, 1000, 742), (505, 731, 1000, 742)],
    "mask": (798, 150, 829, 188),
}
BACK = {
    "crop": [1512, 55, 1995, 742],
    "bands": [
        ([(1530, 70), (1547, 95), (1552, 135), (1542, 190), (1535, 240), (1540, 300), (1555, 345), (1570, 395),
          (1582, 430), (1590, 475), (1600, 500)], 14),
        ([(1638, 585), (1645, 600), (1652, 630), (1660, 670), (1662, 680)], 13),
        ([(1552, 100), (1590, 250), (1627, 400), (1645, 520), (1655, 625)], 5),
        ([(1838, 408), (1880, 470), (1924, 538)], 7),
    ],
    "keep": [(1555, 383, 1583, 417), (1826, 393, 1852, 424)],
    "smoke": {"box": (1655, 551, 1815, 742), "legs": [
        [(1682, 550), (1717, 547), (1720, 590), (1720, 627), (1718, 650), (1720, 673), (1717, 690), (1710, 697),
         (1700, 690), (1695, 667), (1693, 633), (1687, 600), (1682, 573)],
        [(1728, 547), (1757, 547), (1758, 590), (1755, 623), (1755, 657), (1758, 687), (1755, 707), (1747, 723),
         (1735, 725), (1727, 713), (1728, 673), (1725, 640), (1730, 607), (1728, 573)]]},
    "wisps": [(1880, 295, 1995, 480)],
    "clear": [(1512, 700, 1640, 742), (1512, 731, 1995, 742)],
}
SIDE = {
    "crop": [0, 140, 1493, 1925],
    "bands": [
        ([(1280, 175), (1240, 210), (1210, 270), (1195, 350), (1200, 450), (1220, 550), (1230, 650), (1215, 750),
          (1185, 780), (1140, 840), (1110, 880), (1080, 970), (1050, 1030), (1020, 1080), (990, 1120), (980, 1200),
          (965, 1255), (940, 1280), (870, 1310), (780, 1350), (690, 1400), (610, 1450), (560, 1510), (535, 1570),
          (525, 1628)], 30),
        ([(1190, 330), (1070, 540), (945, 750)], 10),
        ([(700, 1270), (640, 1380), (575, 1490)], 7),
        # the arrow in her right hand, fletching to head
        ([(580, 820), (840, 1065), (1245, 1468)], 11),
        ([(585, 825), (670, 905)], 18),
        ([(1165, 1385), (1240, 1462)], 24),
    ],
    "keep": [(1040, 925, 1120, 1030), (795, 1015, 885, 1115)],
    "smoke": {"box": (0, 1480, 1060, 1925), "legs": [
        [(668, 1480), (805, 1480), (805, 1760), (830, 1790), (870, 1830), (920, 1860), (950, 1890), (948, 1915),
         (690, 1915), (675, 1890), (680, 1800), (690, 1700)]]},
    "wisps": [(0, 560, 300, 1220), (0, 1220, 200, 1500)],
    "clear": [(950, 1800, 1493, 1925), (0, 1916, 1493, 1925)],
}


def load(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    return np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1].copy()      # row 0 = top


def save(px, path):
    h, w = px.shape[:2]
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=True)
    img.pixels = px[::-1].ravel()
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()


def seg_mask(shape, pts, r):
    h, w = shape
    yy, xx = np.mgrid[0:h, 0:w]
    m = np.zeros(shape, bool)
    for (x0, y0), (x1, y1) in zip(pts[:-1], pts[1:]):
        bx0, bx1 = int(min(x0, x1) - r - 1), int(max(x0, x1) + r + 2)
        by0, by1 = int(min(y0, y1) - r - 1), int(max(y0, y1) + r + 2)
        bx0, by0 = max(bx0, 0), max(by0, 0)
        X, Y = xx[by0:by1, bx0:bx1], yy[by0:by1, bx0:bx1]
        dx, dy = x1 - x0, y1 - y0
        t = np.clip(((X - x0) * dx + (Y - y0) * dy) / max(dx * dx + dy * dy, 1e-9), 0, 1)
        d = np.hypot(X - (x0 + t * dx), Y - (y0 + t * dy))
        m[by0:by1, bx0:bx1] |= d <= r
    return m


def poly_mask(shape, poly):
    h, w = shape
    yy, xx = np.mgrid[0:h, 0:w]
    inside = np.zeros(shape, bool)
    n = len(poly)
    for i in range(n):
        (x0, y0), (x1, y1) = poly[i], poly[(i + 1) % n]
        if y0 == y1:
            continue
        cond = ((yy >= min(y0, y1)) & (yy < max(y0, y1)))
        xc = x0 + (yy - y0) * (x1 - x0) / (y1 - y0)
        inside ^= cond & (xx < xc)
    return inside


def box_mask(shape, b):
    m = np.zeros(shape, bool)
    m[max(b[1], 0):b[3], max(b[0], 0):b[2]] = True
    return m


def fill(px, hole, skip=None):
    """Onion-peel fill: each pass, the hole's edge pixels take the mean of their known neighbours (`skip` pixels,
    the kept fists, never feed it: their grip wraps would bleed in)."""
    known = ~hole if skip is None else ~hole & ~skip
    rgb = px[..., :3].copy()
    rgb[hole] = 0
    for _ in range(200):
        if known[hole].all():
            break
        acc = np.zeros_like(rgb)
        cnt = np.zeros(hole.shape, np.float32)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dx == 0 and dy == 0:
                    continue
                k = np.roll(np.roll(known, dy, 0), dx, 1)
                acc += np.roll(np.roll(rgb, dy, 0), dx, 1) * k[..., None]
                cnt += k
        grow = hole & (~known) & (cnt >= 2)
        rgb[grow] = acc[grow] / cnt[grow][:, None]
        known = known | grow
    px[..., :3] = rgb


def clean(px, spec, bg):
    shape = px.shape[:2]
    rgb = px[..., :3]
    keep = np.zeros(shape, bool)
    for b in spec.get("keep", []):
        keep |= box_mask(shape, b)
    hole = np.zeros(shape, bool)
    limbs = np.zeros(shape, bool)
    for pts, r in spec["bands"]:
        m = seg_mask(shape, pts, r)
        hole |= m
        if r >= 13:                    # (the bow's limbs; the string and arrow bands are exact)
            limbs |= m
    # and the bow's black lacquer just past the band (its limbs are wider than the band in places)
    lum0 = rgb.mean(axis=2)
    sat0 = rgb.max(axis=2) - rgb.min(axis=2)
    near = limbs.copy()
    for _ in range(spec.get("grow", 8)):
        near = near | np.roll(near, 1, 0) | np.roll(near, -1, 0) | np.roll(near, 1, 1) | np.roll(near, -1, 1)
    off0 = np.abs(rgb - bg[:3]).sum(axis=2) > 0.07
    hole |= near & off0 & (sat0 < 0.16)
    hole &= ~keep
    # her handprint: red pixels on the mask, and a pixel round them
    if "mask" in spec:
        mb = box_mask(shape, spec["mask"])
        red = mb & ((rgb[..., 0] - np.maximum(rgb[..., 1], rgb[..., 2])) > 0.14)
        red = red | np.roll(red, 1, 0) | np.roll(red, -1, 0) | np.roll(red, 1, 1) | np.roll(red, -1, 1)
        hole |= red & mb
        # (only the bone of the mask feeds the fill there, not the hood's shadow round it)
        keep = keep | (mb & ~red & (rgb.mean(axis=2) < 0.5))
    fill(px, hole, keep)
    rgb = px[..., :3]
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    lum = rgb.mean(axis=2)
    off = np.abs(rgb - bg[:3]).sum(axis=2) > 0.04
    sm = spec.get("smoke")
    if sm:
        legs = np.zeros(shape, bool)
        for poly in sm["legs"]:
            legs |= poly_mask(shape, poly)
        box = box_mask(shape, sm["box"])
        px[box & ~legs & (sat < 0.05) & off, :3] = bg[:3]
        # smoke drifting over her shins: light grey on the black boots, filled from the boot round it
        fill(px, box & legs & (sat < 0.08) & (lum > 0.36))
    for b in spec.get("wisps", []):
        z = box_mask(shape, b) & (lum > 0.42) & off
        px[z, :3] = bg[:3]
    for b in spec.get("clear", []):
        px[box_mask(shape, b), :3] = bg[:3]
    px[..., 3] = 1.0


def drop_specks(c, bg, frac=0.02):
    """Bits left over the background (the ends of a painted-out string, a wrap, a shadow's corner) that don't
    touch the figure: connected pieces under `frac` of the largest are painted grey."""
    from collections import deque
    fg = np.abs(c[..., :3] - bg[:3]).sum(axis=2) > 0.08
    h, w = fg.shape
    lab = np.zeros((h, w), np.int32)
    sizes = [0]
    for y0, x0 in zip(*np.nonzero(fg)):
        if lab[y0, x0]:
            continue
        n = len(sizes)
        lab[y0, x0] = n
        q, cnt = deque([(y0, x0)]), 0
        while q:
            y, x = q.popleft()
            cnt += 1
            for yy, xx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= yy < h and 0 <= xx < w and fg[yy, xx] and not lab[yy, xx]:
                    lab[yy, xx] = n
                    q.append((yy, xx))
        sizes.append(cnt)
    sizes = np.array(sizes)
    small = sizes < frac * sizes.max()
    small[0] = False
    c[small[lab], :3] = bg[:3]


def square(px, crop, bg, margin=24, min_px=1024):
    x0, y0, x1, y1 = crop
    c = px[y0:y1, x0:x1].copy()
    drop_specks(c, bg)
    fg = np.abs(c[..., :3] - bg[:3]).sum(axis=2) > 0.08
    ys, xs = np.nonzero(fg)
    c = c[max(ys.min() - margin, 0):ys.max() + margin, max(xs.min() - margin, 0):xs.max() + margin]
    h, w = c.shape[:2]
    n = max(h, w)
    sq = np.empty((n, n, 4), np.float32)
    sq[:] = bg
    ox, oy = (n - w) // 2, (n - h) // 2
    sq[oy:oy + h, ox:ox + w] = c
    k = int(np.ceil(min_px / n))
    if k > 1:
        sq = np.repeat(np.repeat(sq, k, 0), k, 1)
    return sq


def main():
    a = sys.argv[sys.argv.index("--") + 1:]
    turn, side, out = load(a[0]), load(a[1]), a[2]
    os.makedirs(out, exist_ok=True)
    bg = np.median(turn[5:20, 5:20].reshape(-1, 4), axis=0)
    bg[3] = 1.0
    for spec in (FRONT, THREE_Q, BACK):
        clean(turn, spec, bg)
    sbg = np.median(side[5:20, 5:20].reshape(-1, 4), axis=0)
    sbg[3] = 1.0
    clean(side, SIDE, sbg)
    save(turn, os.path.join(out, "turnaround_clean.png"))
    save(side, os.path.join(out, "side_clean.png"))
    views = [("front", turn, FRONT, bg), ("three_quarter", turn, THREE_Q, bg), ("side", side, SIDE, sbg),
             ("back", turn, BACK, bg)]
    for i, (name, px, spec, b) in enumerate(views):
        save(square(px, spec["crop"], b), os.path.join(out, "view%d.png" % i))
    json.dump({n: {"file": "view%d.png" % i, "crop": s["crop"]} for i, (n, _p, s, _b) in enumerate(views)},
              open(os.path.join(out, "views.json"), "w"), indent=1)
    print("PININPUTS wrote", out)


if __name__ == "__main__":
    main()
