"""Zedran's Meshy inputs (r2 art, docs/art/gen/wardens_r2/zedran_{turnaround,side,portrait}.webp converted to png), in
Blender's Python (numpy; no PIL):
  blender -b --factory-startup --python tools/meshy/zedran_inputs.py -- ART_DIR OUT_DIR

ART_DIR holds zedran_turnaround.png (2000 x 848: front, two 3/4s, back), zedran_side.png (1493 x 2000, a true
profile of his RIGHT side) and zedran_portrait.png. Only the front and back of the turnaround and the side view go
to Meshy: the art's two 3/4 views lose the magma arm's cracks and swap what each hand holds.
Nothing is mirrored: the magma arm, the lion pauldron and the greatsword are his RIGHT, the chain in his LEFT hand.

Writes, in OUT_DIR:
 - view0..2.png (front, side, back): the figure with the greatsword painted out (it is its own run and the
   kit's weapon). Where the blade hid his right leg, the front view takes his left leg mirrored across the body's
   middle; the side view fills the hidden thigh and skirt with their own colours. The side view's yellow cape is
   painted out below the lion pelt (the turnaround has no cape; the pelt hangs down his back to the belt).
 - sword.png: the greatsword alone from the side view (the eye in the blade), its grip under the fist filled in.
 - head_portrait.png: the portrait's head, horns and laurel, everything else (the sword behind it) on grey.
 - views.json: each view's crop box on its sheet (for the texture projection in the fit).
 - mask_*.png: the painted-out areas tinted red, to check.
"""
import json
import os
import sys

import bpy
import numpy as np

# --- polygons, in sheet pixels (x right, y down) ---------------------------------------------------------------
# turnaround front: the sword's pommel and grip above the fist, and its guard and blade below it
F_HANDLE = [(62.5, 380), (85, 372.5), (92.5, 385), (110, 420), (100, 432.5), (90, 427.5), (75, 395), (62.5, 390)]
F_BLADE = [(86, 499), (92, 487.5), (126, 481), (146, 469), (159, 454), (176, 459), (175, 471), (190, 505),
           (205, 540), (235, 620), (250, 640), (275, 660), (300, 685), (292.5, 701), (260, 704), (252.5, 721),
           (205, 724), (176, 690), (146, 600), (121, 550), (103.5, 509)]
F_BITS = [[(92, 500), (114, 500), (114, 534), (92, 534)], [(250, 655), (314, 664), (312, 708), (250, 708)]]
F_MID = 275.0          # the body's middle column (his left leg is mirrored across it onto the hidden right leg)
F_MIRROR_FROM = 171.0  # columns right of this take the mirrored leg; left of it, the sheet's grey
# turnaround back
B_HANDLE = [(1907.5, 427.5), (1924, 384), (1952.5, 389), (1951, 404), (1936, 406), (1921, 440)]
B_BLADE = [(1830, 465), (1851, 454), (1876, 465), (1909, 505), (1903, 534), (1890, 538), (1893, 560), (1870, 591),
           (1851, 620), (1843, 620), (1842, 560), (1840, 496), (1835, 486)]
B_LEGS = [(1708, 686), (1725, 660), (1755, 630), (1770, 610), (1784, 597.5), (1781, 640), (1781, 721),
          (1770, 721), (1740, 701), (1711, 694)]
# side view (1493 x 2000)
S_CAPE = [(360, 731), (435, 731), (517, 712), (512, 800), (522, 900), (547, 981), (545, 1050), (547, 1225),
          (603, 1231), (600, 1720), (360, 1720)]
S_HANDLE = [(398, 918), (420, 920), (460, 945), (610, 1035), (615, 1060), (600, 1065), (455, 980), (430, 965),
            (405, 935)]
S_BLADE = [(660, 1220), (678, 1200), (805, 1072), (830, 1072), (852, 1090), (838, 1150), (960, 1220), (1150, 1330),
           (1165, 1380), (1400, 1462), (1400, 1475), (1388, 1492), (1200, 1716), (1190, 1712), (1098, 1565),
           (1078, 1522), (950, 1452), (750, 1312), (690, 1272), (660, 1250)]
S_SKIRT_BOTTOM = 1225          # rows above this inside the blade were skirt
S_SKIRT_X = 905                # (the skirt's front edge)
S_SKIRT_LEFT = 548             # (and its back edge)
S_THIGH_BACK = ((600, 1250), (605, 1450))      # the thigh's back edge (x, y) top and bottom
S_THIGH_FRONT = ((830, 1230), (800, 1400))     # its front edge, hidden by the blade
S_THIGH_AT = (640, 1300)       # where the thigh's colour is sampled
S_GRIP = ((610, 1050), (765, 1145), 17)        # the grip's hidden run under the fist (from, to, half width)
S_GRIP_AT = (540, 1010)
# portrait (2000 x 2000): the head, horns, laurel and neck kept
P_HEAD = [(486, 492), (568, 488), (636, 465), (630, 340), (645, 234), (699, 188), (780, 172), (845, 212), (918, 209),
          (980, 228), (1042, 190), (1092, 146), (1180, 130), (1305, 135), (1418, 180), (1482, 246), (1512, 340),
          (1505, 452), (1470, 565), (1420, 640), (1342, 680), (1255, 668), (1205, 628), (1186, 678), (1161, 790),
          (1136, 878), (1145, 965), (868, 965), (861, 865), (811, 765), (768, 715), (715, 642), (605, 555), (518, 518)]
P_BOX = (440, 90, 1560, 1000)  # x0, y0, x1, y1 of the head square (before padding)

VIEWS = [("front", 64, 515, "turn"), ("side", 370, 1030, "side"), ("back", 1500, 1951, "turn")]
ROWS = {"turn": (34, 806), "side": (78, 1918)}
MARGIN = 0.04                   # of the figure's height, grey round each view
OUT = 1600                      # px, each Meshy view


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


def poly_mask(shape, pts):
    h, w = shape[:2]
    ys, xs = np.mgrid[0:h, 0:w]
    x = xs + 0.5
    y = ys + 0.5
    inside = np.zeros((h, w), bool)
    n = len(pts)
    for i in range(n):
        x0, y0 = pts[i]
        x1, y1 = pts[(i + 1) % n]
        if y0 == y1:
            continue
        cross = ((y0 > y) != (y1 > y)) & (x < (x1 - x0) * (y - y0) / (y1 - y0) + x0)
        inside ^= cross
    return inside


def dilate(m, r):
    out = m.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= r * r:
                out |= np.roll(np.roll(m, dy, 0), dx, 1)
    return out


def bg_of(px):
    bg = np.median(px[5:20, 5:20].reshape(-1, 4), axis=0)
    bg[3] = 1.0
    return bg


def edge_x(a, b, y):
    t = (y - a[1]) / (b[1] - a[1])
    return a[0] + (b[0] - a[0]) * t


def paint_turn(sheet):
    bg = bg_of(sheet)
    out = sheet.copy()
    marks = np.zeros(sheet.shape[:2], bool)
    for poly in (F_HANDLE, B_HANDLE, B_BLADE, B_LEGS):
        m = dilate(poly_mask(sheet.shape, poly), 3)
        out[m] = bg
        marks |= m
    m = dilate(poly_mask(sheet.shape, F_BLADE), 3)
    for poly in F_BITS:
        m |= poly_mask(sheet.shape, poly)
    marks |= m
    ys, xs = np.nonzero(m)
    mir = (2 * F_MID - xs).astype(int)
    take = (xs >= F_MIRROR_FROM) & ~m[ys, mir]       # (a mirrored pixel that is blade itself stays grey)
    out[ys[take], xs[take]] = sheet[ys[take], mir[take]]
    out[ys[~take], xs[~take]] = bg
    return out, marks



def paint_side(sheet):
    bg = bg_of(sheet)
    out = sheet.copy()
    marks = np.zeros(sheet.shape[:2], bool)
    for poly in (S_CAPE, S_HANDLE):
        m = dilate(poly_mask(sheet.shape, poly), 6)
        out[m] = bg
        marks |= m
        if poly is S_HANDLE:    # (where the grip crossed the skirt)
            ys, xs = np.nonzero(m)
            on = (xs > S_SKIRT_LEFT) & (ys > 1000)
            out[ys[on], xs[on]] = -1.0
    box = sheet[940:1060, 760:900].reshape(-1, 4)
    red = box[(box[:, 0] > 1.8 * box[:, 1]) & (box[:, 0] > 0.25)]
    skirt = np.median(red, axis=0)          # (the skirt's crimson between the gold stripes)
    thigh = np.median(sheet[S_THIGH_AT[1] - 6:S_THIGH_AT[1] + 6, S_THIGH_AT[0] - 6:S_THIGH_AT[0] + 6].reshape(-1, 4), axis=0)
    m = dilate(poly_mask(sheet.shape, S_BLADE), 6)
    marks |= m
    ys, xs = np.nonzero(m)
    back = edge_x(*S_THIGH_BACK, ys)
    front = edge_x(*S_THIGH_FRONT, ys)
    is_skirt = (ys < S_SKIRT_BOTTOM) & (xs < S_SKIRT_X)
    is_thigh = ~is_skirt & (xs >= back) & (xs <= front)
    out[ys, xs] = bg
    out[ys[is_skirt], xs[is_skirt]] = skirt
    # the thigh rounds off: a little darker toward its edges
    t = np.clip((xs[is_thigh] - back[is_thigh]) / np.maximum(front[is_thigh] - back[is_thigh], 1), 0, 1)
    shade = (0.95 + 0.25 * np.sin(np.pi * t))[:, None]
    col = np.tile(thigh, (int(is_thigh.sum()), 1))
    col[:, :3] *= shade
    out[ys[is_thigh], xs[is_thigh]] = col
    hole = out[..., 0] < -0.5
    out[hole] = skirt
    return out, marks


def sword_side(sheet):
    """The greatsword alone from the side view, on grey: pommel, grip (filled in under the fist), guard and blade."""
    bg = bg_of(sheet)
    keep = poly_mask(sheet.shape, S_BLADE) | poly_mask(sheet.shape, S_HANDLE)
    out = np.empty_like(sheet)
    out[:] = bg
    px = sheet[..., :3]
    crimson = (px[..., 0] > 1.8 * px[..., 1]) & (px[..., 2] >= 0.9 * px[..., 1]) & (px[..., 0] > 0.2)
    keep &= ~crimson                    # (the skirt seen past the guard)
    out[keep] = sheet[keep]
    (ax, ay), (bx, by), r = S_GRIP
    grip = np.median(sheet[S_GRIP_AT[1] - 3:S_GRIP_AT[1] + 3, S_GRIP_AT[0] - 3:S_GRIP_AT[0] + 3].reshape(-1, 4), axis=0)
    h, w = sheet.shape[:2]
    ys, xs = np.mgrid[0:h, 0:w]
    d = np.array([bx - ax, by - ay], float)
    L = np.linalg.norm(d)
    u = ((xs - ax) * d[0] + (ys - ay) * d[1]) / L
    v = np.abs(((xs - ax) * d[1] - (ys - ay) * d[0]) / L)
    run = (u >= 0) & (u <= L) & (v <= r) & ~keep
    out[run] = grip
    return out


def square(crop, bg, margin_px):
    h, w = crop.shape[:2]
    n = max(h, w) + 2 * margin_px
    sq = np.empty((n, n, 4), np.float32)
    sq[:] = bg
    ox, oy = (n - w) // 2, (n - h) // 2
    sq[oy:oy + h, ox:ox + w] = crop
    return sq, ox, oy


def resize(px, n):
    sh, sw = px.shape[:2]
    ys = np.clip(((np.arange(n) + 0.5) * sh / n).astype(int), 0, sh - 1)
    xs = np.clip(((np.arange(n) + 0.5) * sw / n).astype(int), 0, sw - 1)
    if n < sh:      # (box-filter a shrink so it doesn't alias)
        k = sh / n
        acc = np.zeros((n, n, 4), np.float32)
        cnt = 0
        for dy in np.linspace(-0.5, 0.5, max(2, int(k) + 1)):
            for dx in np.linspace(-0.5, 0.5, max(2, int(k) + 1)):
                yy = np.clip(((np.arange(n) + 0.5 + dy) * sh / n).astype(int), 0, sh - 1)
                xx = np.clip(((np.arange(n) + 0.5 + dx) * sw / n).astype(int), 0, sw - 1)
                acc += px[yy][:, xx]
                cnt += 1
        return acc / cnt
    return px[ys][:, xs]


def tinted(px, marks):
    out = px.copy()
    out[marks, 0] = out[marks, 0] * 0.5 + 0.5
    out[marks, 1] *= 0.5
    out[marks, 2] *= 0.5
    return out


def main():
    a = sys.argv[sys.argv.index("--") + 1:]
    src, out = a[0], a[1]
    os.makedirs(out, exist_ok=True)
    turn = load(os.path.join(src, "zedran_turnaround.png"))
    side = load(os.path.join(src, "zedran_side.png"))
    turn_p, turn_m = paint_turn(turn)
    side_p, side_m = paint_side(side)
    save(tinted(turn, turn_m), os.path.join(out, "mask_turnaround.png"))
    save(tinted(side, side_m), os.path.join(out, "mask_side.png"))
    sheets = {"turn": (turn_p, bg_of(turn)), "side": (side_p, bg_of(side))}
    boxes = {}
    for i, (name, x0, x1, which) in enumerate(VIEWS):
        px, bg = sheets[which]
        top, bottom = ROWS[which]
        crop = px[top:bottom, x0:x1].copy()
        crop[..., 3] = 1.0
        sq, ox, oy = square(crop, bg, int(MARGIN * (bottom - top)))
        n0 = sq.shape[0]
        save(resize(sq, OUT), os.path.join(out, "view%d.png" % i))
        boxes[name] = {"file": "view%d.png" % i, "sheet": which, "sheet_x0": x0 - ox, "sheet_y0": top - oy, "size": n0, "out": OUT}
    sw = sword_side(side)
    x0, y0, x1, y1 = 380, 880, 1420, 1740
    sq, _ox, _oy = square(sw[y0:y1, x0:x1], bg_of(side), 40)
    save(resize(sq, 1200), os.path.join(out, "sword.png"))
    if os.path.exists(os.path.join(src, "zedran_portrait.png")):
        por = load(os.path.join(src, "zedran_portrait.png"))
        keep = poly_mask(por.shape, P_HEAD)
        mx, mn = por[..., :3].max(axis=2), por[..., :3].min(axis=2)
        steel = ((mx - mn) < 0.09 * np.maximum(mx, 1e-3) + 0.02) & (mx > 0.4)
        keep &= ~(steel & (np.arange(por.shape[1])[None, :] > 1150))     # (the blade behind his left horn)
        grey = np.array([0.5, 0.5, 0.5, 1.0], np.float32)
        hp = np.empty_like(por)
        hp[:] = grey
        hp[keep] = por[keep]
        hp[..., 3] = 1.0
        bx0, by0, bx1, by1 = P_BOX
        sq, _ox, _oy = square(hp[by0:by1, bx0:bx1], grey, 40)
        save(resize(sq, 1200), os.path.join(out, "head_portrait.png"))
        save(tinted(por, ~keep), os.path.join(out, "mask_portrait.png"))
    json.dump(boxes, open(os.path.join(out, "views.json"), "w"), indent=1)
    print("ZEDRANINPUTS wrote", out)


main()
