"""Cinder's Meshy inputs (r2 art, docs/art/gen/wardens_r2/cinder_turnaround.webp, 2000 px), in Blender's Python
(numpy; no PIL):
  blender -b --factory-startup --python tools/meshy/cinder_inputs.py -- TURNAROUND.png OUT_DIR

The sheet has four views side by side: front, 3/4, a near profile (her LEFT side, facing the sheet's left), back.
Nothing is mirrored. The syringe-spear in her left hand (needle, flame-filled glass barrel, brass fittings and
knob, a round flask on the shaft under her fist, the shaft) is painted out of every view, so Meshy builds her
with an empty fist: the spear is the separate `weapon` mesh (tools/meshy/cinder_spear.py, RIG_CONTRACT). The
profile has no shaft, only the flask in her fist; it goes too. The other view's spear tip that pokes into the
3/4 crop goes as well. Each view is padded square on the sheet's grey and enlarged to 1024 px; the ground line
is taken out. Writes view0..3.png (Meshy's order, front first) and views.json (crop boxes, for the projection).
"""
import json
import os
import sys

import bpy
import numpy as np

# column ranges on the 2000 px sheet
VIEWS = [("front", 20, 548), ("three_quarter", 548, 1085), ("profile", 1095, 1490), ("back", 1490, 1990)]
TOP, BOTTOM = 40, 818          # sheet rows kept (above the frills, below the claws)
GROUND = (781, 788)            # the drawn ground line's rows
MARGIN = 24
OUT_PX = 1024

# The spear per view, in sheet pixels: the needle's tip, the flask's middle (on the spear's axis) and radius,
# where the shaft goes out of sight behind her leg, the knob, and the fist around the grip (kept).
# Along the axis (fractions of tip -> flask): needle, collar, glass barrel, fittings, grip, flask, shaft.
SPEAR = {
    "front": {"tip": (559, 87), "flask": (452.5, 455), "r": 32, "end": (419, 553), "knob": (500, 347.5),
              "hand": [(439, 410), (445, 387.5), (462.5, 380), (487.5, 385), (494, 405), (490, 430), (460, 432.5),
                       (442.5, 427.5)]},
    "three_quarter": {"tip": (1060, 90), "flask": (961, 445), "r": 28, "end": (937, 521), "knob": (1012.5, 337.5),
                      "hand": [(940, 405), (955, 380), (975, 374), (997.5, 385), (1002.5, 405), (997.5, 420),
                               (980, 425), (960, 422.5), (942.5, 420)]},
    "back": {"tip": (1492.5, 95), "flask": (1585, 445), "r": 29, "end": (1601, 522), "knob": (1537.5, 332.5),
             "hand": [(1547.5, 385), (1557.5, 370), (1577.5, 365), (1592.5, 375), (1595, 390), (1590, 410),
                      (1572.5, 422.5), (1555, 410)]},
}
# (fraction from, fraction to, half-width as a fraction of tip -> flask)
SEGS = [(0.0, 0.33, 0.018), (0.31, 0.37, 0.026), (0.36, 0.63, 0.044), (0.61, 0.80, 0.026), (0.78, 0.95, 0.026),
        (1.0, 1.6, 0.016)]
# the profile's flask (held by the neck in her fist): polygons in sheet pixels
PROFILE_FLASK = [[(1131, 373), (1161, 373), (1161, 393), (1131, 393)],
                 [(1139, 436), (1186, 436), (1191, 460), (1186, 492), (1144, 494), (1136, 465)]]
# the front view's spear tip inside the 3/4 crop
OTHER_TIP = [(548, 40), (572, 40), (572, 330), (548, 330)]
# the 3/4 view's tail tip inside the front crop
OTHER_TAIL = [(533, 330), (560, 330), (560, 760), (533, 760)]


def load(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    return np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1].copy()      # row 0 = top


def save(px, path, size=None):
    h, w = px.shape[:2]
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=True)
    img.pixels = px[::-1].ravel()
    if size:
        img.scale(size, size)
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()


def inside(poly, h, w):
    yy, xx = np.mgrid[0:h, 0:w]
    m = np.zeros((h, w), bool)
    n = len(poly)
    for i in range(n):
        x0, y0 = poly[i]
        x1, y1 = poly[(i + 1) % n]
        if y0 == y1:
            continue
        cond = (yy >= min(y0, y1)) & (yy < max(y0, y1))
        xc = x0 + (yy - y0) * (x1 - x0) / (y1 - y0)
        m ^= cond & (xx < xc)
    return m


def spear_mask(sp, h, w):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    tip = np.array(sp["tip"], np.float32)
    fl = np.array(sp["flask"], np.float32)
    ax = fl - tip
    n = float(np.linalg.norm(ax))
    ax /= n
    rel_x, rel_y = xx - tip[0], yy - tip[1]
    t = (rel_x * ax[0] + rel_y * ax[1]) / n
    d = np.abs(rel_x * ax[1] - rel_y * ax[0]) / n
    end = np.array(sp["end"], np.float32)
    t_end = float(((end - tip) @ ax) / n)
    m = np.zeros((h, w), bool)
    for t0, t1, hw in SEGS:
        m |= (t >= t0 - 0.02) & (t <= min(t1, t_end)) & (d <= hw * 1.3 + 6.0 / n)
    m |= np.hypot(xx - fl[0], yy - fl[1]) <= sp["r"] + 6.0
    k = np.array(sp["knob"], np.float32)
    m |= np.hypot(xx - k[0], yy - k[1]) <= 13.0
    m &= ~inside(sp["hand"], h, w)
    return m


def ground(px, holes):
    """The sheet's grey behind the figure per pixel: each row's grey pixels interpolated across the row."""
    h, w = px.shape[:2]
    rgb = px[..., :3]
    grey = (rgb.max(axis=2) - rgb.min(axis=2) < 0.03) & (rgb.mean(axis=2) > 0.7) & ~holes
    out = np.empty_like(px)
    cols = np.arange(w)
    for y in range(h):
        g = np.nonzero(grey[y])[0]
        if g.size == 0:
            out[y] = out[y - 1] if y else px[y]
            continue
        for c in range(4):
            out[y, :, c] = np.interp(cols, g, px[y, g, c])
    return out


def fill(px, holes):
    """Wide holes take the sheet's grey; a thin run (the shaft crossing her leg or tail) takes its row
    neighbours' colours across it, so the body behind isn't notched."""
    bg = np.median(px[5:20, 5:20].reshape(-1, 4), axis=0)
    h, w = holes.shape
    out = px.copy()
    for y in range(h):
        row = holes[y]
        x = 0
        while x < w:
            if not row[x]:
                x += 1
                continue
            x0 = x
            while x < w and row[x]:
                x += 1
            x1 = x
            if x1 - x0 <= 22 and x0 > 0 and x1 < w:
                a, b = px[y, x0 - 1], px[y, x1]
                for i in range(x0, x1):
                    f = (i - x0 + 1) / (x1 - x0 + 1)
                    out[y, i] = a * (1 - f) + b * f
            else:
                out[y, x0:x1] = bg
    return out


def main():
    a = sys.argv[sys.argv.index("--") + 1:]
    sheet, out = load(a[0]), a[1]
    os.makedirs(out, exist_ok=True)
    H, W = sheet.shape[:2]
    holes = np.zeros((H, W), bool)
    for sp in SPEAR.values():
        holes |= spear_mask(sp, H, W)
    for poly in PROFILE_FLASK + [OTHER_TIP, OTHER_TAIL]:
        holes |= inside(poly, H, W)
    rgb = sheet[..., :3]
    line = np.zeros((H, W), bool)
    line[GROUND[0]:GROUND[1]] = True
    line &= (rgb.max(axis=2) - rgb.min(axis=2) < 0.05) & (rgb.mean(axis=2) > 0.4) & (rgb.mean(axis=2) < 0.8)
    holes |= line
    spear_only = np.empty_like(sheet)
    clean = fill(sheet, holes)
    bg = np.median(sheet[5:20, 5:20].reshape(-1, 4), axis=0)
    bg[3] = 1.0
    spear_only[:] = bg
    sp_holes = holes & ~line
    spear_only[sp_holes] = sheet[sp_holes]
    save(clean, os.path.join(out, "sheet_clean.png"))
    save(spear_only, os.path.join(out, "sheet_spear.png"))
    boxes = {}
    for i, (name, x0, x1) in enumerate(VIEWS):
        x0, x1 = max(0, x0 - MARGIN), min(W, x1 + MARGIN)
        crop = clean[TOP:BOTTOM, x0:x1].copy()
        # the margins: grey only (not the neighbouring view)
        lo, hi = VIEWS[i][1] - x0, VIEWS[i][2] - x0
        g = ground(crop, np.zeros(crop.shape[:2], bool))
        crop[:, :lo] = g[:, :lo]
        crop[:, hi:] = g[:, hi:]
        crop[..., 3] = 1.0
        h, w = crop.shape[:2]
        n = max(h, w) + 2 * MARGIN
        sq = np.empty((n, n, 4), np.float32)
        sq[:] = bg
        ox, oy = (n - w) // 2, (n - h) // 2
        sq[oy:oy + h, ox:ox + w] = crop
        save(sq, os.path.join(out, "view%d.png" % i), OUT_PX)
        boxes[name] = {"file": "view%d.png" % i, "sheet_x0": x0 - ox, "sheet_y0": TOP - oy, "n": n, "px": OUT_PX}
    json.dump(boxes, open(os.path.join(out, "views.json"), "w"), indent=1)
    print("CINDERINPUTS wrote", out)


main()
