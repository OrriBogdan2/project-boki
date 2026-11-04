"""Ryzz's Meshy inputs (r2 art, docs/art/gen/wardens_r2/ryzz_{turnaround,side}.webp as PNG), in Blender's Python:
  blender -b --factory-startup --python tools/meshy/ryzz_inputs.py -- TURNAROUND.png SIDE.png OUT_DIR

The turnaround has four views side by side (front, 3/4, near profile, back); the 3/4 also draws a stray second
spear behind her left shoulder. Meshy gets the front, the 3/4, the side sheet's clean profile (scaled to the
turnaround's figure height; the turnaround's own profile has a ghost boot) and the back, each padded square on
the sheet's grey. The spear and its flag (in her RIGHT hand) are painted out of every view: every pixel in a
spear region is refilled along its row from the nearest pixels outside it (background over background, boot
over boot); the fist stays. The spear alone (from the side sheet, where it is drawn whole) is written as
spear_side.png and spear_front.png for its own run. Nothing is mirrored. Crop boxes go to views.json.
"""
import json
import os
import sys

import bpy
import numpy as np

TOP, BOTTOM = 26, 1110          # turnaround rows kept
MARGIN = 30
# per view: x range on the turnaround (or None for the side sheet), paint-out polygons, bands (p0, p1,
# half-width), and boxes kept (the fist). Sheet pixels.
VIEWS = [
    ("front", (36, 494), {
        "polys": [[(30, 40), (165, 40), (165, 290), (148, 385), (90, 390), (75, 472), (30, 472)]],
        "bands": [((125, 450), (170, 920), 32), ((160, 900), (184, 1095), 36)],
        "keep": [(86, 383, 162, 452)]}),
    ("three_quarter", (526, 980), {
        "polys": [[(520, 40), (645, 40), (645, 290), (638, 385), (578, 390), (565, 455), (520, 455)],
                  [(872, 222), (995, 222), (995, 442), (928, 442), (915, 330), (880, 318)],
                  [(928, 196), (984, 196), (984, 252), (928, 252)]],
        "bands": [((612, 450), (655, 910), 32), ((650, 895), (668, 1010), 34),
                  ((980, 50), (853, 348), 26), ((966, 136), (908, 268), 34)],
        "keep": [(575, 383, 645, 452)]}),
    ("profile", None, {
        "polys": [[(140, 150), (400, 150), (400, 520), (430, 860), (362, 875), (250, 960), (140, 970)]],
        "bands": [((404, 908), (602, 1860), 34)],
        "keep": [(362, 875, 472, 995)]}),
    ("back", (1538, 1982), {
        "polys": [[(1870, 40), (1995, 40), (1995, 480), (1932, 480), (1932, 385), (1880, 385), (1880, 280)]],
        "bands": [((1908, 452), (1866, 1010), 30)],
        "keep": [(1882, 383, 1932, 458)]}),
]
SIDE_ROWS = (60, 1935)          # side sheet rows kept (the figure, 1853 px tall vs ~1037 on the turnaround)


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


def resize(px, k):
    h, w = px.shape[:2]
    img = bpy.data.images.new("rs", w, h, alpha=True)
    img.pixels = px[::-1].ravel()
    nw, nh = int(round(w * k)), int(round(h * k))
    img.scale(nw, nh)
    return np.array(img.pixels[:], dtype=np.float32).reshape(nh, nw, 4)[::-1].copy()


def poly_mask(shape, poly):
    h, w = shape
    yy, xx = np.mgrid[0:h, 0:w]
    inside = np.zeros((h, w), bool)
    n = len(poly)
    for i in range(n):
        (x0, y0), (x1, y1) = poly[i], poly[(i + 1) % n]
        if y0 == y1:
            continue
        cond = ((yy >= min(y0, y1)) & (yy < max(y0, y1)))
        xc = x0 + (yy - y0) * (x1 - x0) / (y1 - y0)
        inside ^= cond & (xx < xc)
    return inside


def band_mask(shape, p0, p1, hw):
    h, w = shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    a, b = np.array(p0, np.float32), np.array(p1, np.float32)
    d = b - a
    t = np.clip(((xx - a[0]) * d[0] + (yy - a[1]) * d[1]) / float(d @ d), 0, 1)
    return np.hypot(xx - (a[0] + t * d[0]), yy - (a[1] + t * d[1])) <= hw


def copper(px):
    """The spear's copper and brown wood (warm, saturated, darker than her skin)."""
    c = px[..., :3]
    mx, mn = c.max(axis=2), c.min(axis=2)
    sat = (mx - mn) / np.maximum(mx, 1e-6)
    d = np.maximum(mx - mn, 1e-6)
    hue = np.where(mx == c[..., 0], ((c[..., 1] - c[..., 2]) / d) % 6, np.where(mx == c[..., 1],
                   (c[..., 2] - c[..., 0]) / d + 2, (c[..., 0] - c[..., 1]) / d + 4)) / 6
    warm = (hue < 0.13) | (hue > 0.8)
    # (the lower shaft fades to a dull mauve in the art's air: low saturation, mid-dark)
    return warm & (((sat > 0.08) & (mx > 0.18) & (mx < 0.55)) | ((sat > 0.3) & (mx < 0.62)) | ((sat > 0.42) & (mx < 0.92)))


def dilate(m, r):
    out = m.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= r * r:
                out |= np.roll(np.roll(m, dy, 0), dx, 1)
    return out


def paint_out(px, spec, bg_cols=None):
    sh = px.shape[:2]
    # the sheet's background per row (it is a soft vertical gradient), from its outer columns
    rows_bg = np.concatenate([px[:, 2:12, :3], px[:, -12:-2, :3]], axis=1).mean(axis=1)
    m = np.zeros(sh, bool)
    for p in spec.get("polys", []):
        m |= poly_mask(sh, p)
    zone = np.zeros(sh, bool)
    for p0, p1, hw in spec.get("bands", []):
        zone |= band_mask(sh, p0, p1, hw)
    m |= zone & dilate(copper(px), 3)
    for x0, y0, x1, y1 in spec.get("keep", []):
        m[y0:y1, x0:x1] = False
    out = px.copy()
    for y in np.nonzero(m.any(axis=1))[0]:
        row = m[y]
        xs = np.nonzero(row)[0]
        # runs of masked pixels, each filled from the pixels just outside it (a 3 px average on each side)
        starts = xs[np.r_[True, np.diff(xs) > 1]]
        ends = xs[np.r_[np.diff(xs) > 1, True]]
        for s, e in zip(starts, ends):
            lo, hi = max(0, s - 3), min(px.shape[1], e + 4)
            left = px[y, lo:s, :3].mean(axis=0) if s > 0 else px[y, e + 1:hi, :3].mean(axis=0)
            right = px[y, e + 1:hi, :3].mean(axis=0) if e + 1 < px.shape[1] else left
            if e - s > 40:
                # (a long run: a neighbour may be the fist or the hair; grade from the background instead)
                near_bg = lambda c: np.abs(c - rows_bg[y]).max() < 0.06
                left = left if near_bg(left) else rows_bg[y]
                right = right if near_bg(right) else rows_bg[y]
            k = np.linspace(0, 1, e - s + 3)[1:-1, None]
            if np.abs(left - right).max() > 0.12:
                k = (k > 0.5).astype(np.float32)     # (background on one side, cloth on the other: a clean edge, no smear)
            out[y, s:e + 1, :3] = left * (1 - k) + right * k
    return out, m


def square(crop, bg, n=None):
    h, w = crop.shape[:2]
    n = n or max(h, w)
    sq = np.empty((n, n, 4), np.float32)
    sq[:] = bg
    ox, oy = (n - w) // 2, (n - h) // 2
    sq[oy:oy + h, ox:ox + w] = crop
    return sq, ox, oy


def main():
    a = sys.argv[sys.argv.index("--") + 1:]
    sheet, side, out = load(a[0]), load(a[1]), a[2]
    os.makedirs(out, exist_ok=True)
    sheet[..., 3] = 1.0
    side[..., 3] = 1.0
    bg = np.median(sheet[5:20, 5:20].reshape(-1, 4), axis=0)
    sbg = np.median(side[5:20, 5:20].reshape(-1, 4), axis=0)
    clean, mask = paint_out(sheet, {k: sum((v[2][k] for v in VIEWS if v[1]), []) for k in ("polys", "bands", "keep")})
    sclean, smask = paint_out(side, VIEWS[2][2])
    k_side = (1037.0) / (SIDE_ROWS[1] - SIDE_ROWS[0])
    n = (BOTTOM - TOP) + 2 * MARGIN
    boxes = {}
    for i, (name, xr, _spec) in enumerate(VIEWS):
        if xr:
            x0, x1 = xr[0] - MARGIN, xr[1] + MARGIN
            crop = clean[TOP:BOTTOM, x0:x1].copy()
            sq, ox, oy = square(crop, bg, n)
            boxes[name] = {"file": "view%d.png" % i, "sheet": "turnaround", "sheet_x0": x0 - ox, "sheet_y0": TOP - oy,
                           "scale": 1, "sheet_k": 1.0}
            save(np.where(mask[TOP:BOTTOM, x0:x1, None], np.array([1, 0, 1, 1], np.float32), sheet[TOP:BOTTOM, x0:x1]),
                 os.path.join(out, "mask%d.png" % i))
        else:
            crop = sclean[SIDE_ROWS[0]:SIDE_ROWS[1]].copy()
            crop = resize(crop, k_side)
            crop = crop - sbg + bg          # (the side sheet's flatter grey onto the turnaround's)
            crop[..., 3] = 1.0
            cols = np.nonzero((np.abs(crop[..., :3] - bg[:3]).max(axis=2) > 0.08).any(axis=0))[0]
            crop = crop[:, max(0, cols.min() - MARGIN):cols.max() + MARGIN]
            sq, ox, oy = square(crop, bg, n)
            boxes[name] = {"file": "view%d.png" % i, "sheet": "side", "k": k_side, "rows": SIDE_ROWS}
            save(np.where(smask[..., None], np.array([1, 0, 1, 1], np.float32), side), os.path.join(out, "mask%d.png" % i))
        save(np.clip(sq, 0, 1), os.path.join(out, "view%d.png" % i))
    # the spear alone, from the side sheet (drawn whole there): everything but the spear region greyed
    sm = np.zeros(side.shape[:2], bool)
    sp = VIEWS[2][2]
    for p in sp["polys"]:
        sm |= poly_mask(side.shape[:2], p)
    for p0, p1, hw in sp["bands"]:
        sm |= band_mask(side.shape[:2], p0, p1, hw) & dilate(copper(side), 3)
    kx0, ky0, kx1, ky1 = sp["keep"][0]
    sm[ky0 - 20:ky1 + 10, kx0:kx1 + 10] = False      # (the fist; the shaft is drawn through it below)
    alone = np.where(sm[..., None], side, sbg)
    alone[..., 3] = 1.0
    # the shaft through the fist: the shaft's cross-section just below the hand, carried up along its line
    (ax, ay), (bx, by), _zone = sp["bands"][0]
    hw = 16
    slope = (bx - ax) / float(by - ay)
    ref_y = 1010
    rc = int(round(ax + (ref_y - ay) * slope))
    prof = side[ref_y, rc - hw:rc + hw + 1].copy()
    x0, y0, x1, y1 = sp["keep"][0]
    for y in range(y0 - 20, y1 + 10):
        c = int(round(ax + (y - ay) * slope))
        alone[y, c - hw:c + hw + 1] = prof
    ys, xs = np.nonzero(sm)
    crop = alone[max(0, ys.min() - 40):ys.max() + 40, max(0, xs.min() - 40):xs.max() + 40]
    sq, _ox, _oy = square(crop, sbg)
    save(sq, os.path.join(out, "spear_side.png"))
    json.dump(boxes, open(os.path.join(out, "views.json"), "w"), indent=1)
    print("RYZZINPUTS wrote", out)


main()
