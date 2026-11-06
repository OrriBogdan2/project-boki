"""Hem's (Lisette's) sculpt (ART-1, item 108. Model: briefs/art-refs/lisette_turnaround_apose.png; outfit and colour:
hem_FINAL_sheet.png; weapons and props: hem_v4_props.png): the shapes as signed distance fields (tools/art1/hem_sdf.py), all built on the
rig's own joints (art/wardens/src/hem_rig.json), so she stays on the contract armature.

The Red Stitch Archer: an adult woman of about 7 heads, tanned, a sharp mature face, a red-stitched eye mask, green eyes; a
high ponytail tied in red thread, pinned with a silver needle; a black-and-red stitched corset (closed high under the scarf:
tasteful, item 108), pauldrons and half-sleeves, bracers, black capris, tall laced boots; a long red scarf.
Space: Blender's, facing +Y, her right hand +X, up +Z, metres at the class-neutral size."""
import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import hem_sdf as S
from hem_sdf import Field, Prim, box, cap, cyl, ell, fbm, path, smooth, sph

F = np.float32
# labels (the paint's regions)
SKIN, LIP, BROW, EAR_IN, LID, NAIL = 1, 2, 3, 4, 5, 6
HAIR, HAIR_DK, NEEDLE = 10, 11, 12
PORC, GOLD, THREAD, SMILE = 20, 21, 22, 23
CORSET, CORSET_SEAM, TROUSER, BOOT, BOOT_TOP, LACE = 30, 31, 32, 33, 34, 35
JACKET, JACKET_DK, CUFF, TAPE, LEATHER, BUCKLE, STEEL = 40, 41, 42, 43, 44, 45, 46
SCARF, FEATHER, PAULDRON = 50, 51, 52

# the head is sculpted a shade small, then set: scaled up and sunk onto the neck (League-sized for the top-down camera)
HEAD_K, HEAD_C, HEAD_DZ = 1.08, np.array((0, 0, 1.60), F), -0.014


def head_xf(p):
    return (np.asarray(p, F) - HEAD_C) * HEAD_K + HEAD_C + (0, 0, HEAD_DZ)


# the head's landmarks
EYE = (0.0365, 0.0705, 1.6190)      # the eyeball's centre (right; mirror x for the left)
EYE_R = 0.0155
CANT = 0.16                        # rad: the outer corner sits higher than the inner one
EYE_W, EYE_H = 0.0185, 0.0082      # half width and half height of the opening


def joints(rig_path):
    with open(rig_path) as f:
        rig = json.load(f)
    return {k: np.array([v["head"][0], -v["head"][2], v["head"][1]], F) for k, v in rig["bones"].items()}


def loft(sec, p=2.2, pf=None):
    """A lofted solid: sec = [(z, cy, rx, ry_front, ry_back), ...] from low to high, interpolated smoothly. p: the
    cross-section's superellipse power, pf: the front half's. The value is a radial distance, close to a true sdf."""
    sec = np.array(sec, F)
    zs = np.linspace(sec[0, 0], sec[-1, 0], 256)
    from_pts = lambda i: _smooth_interp(zs, sec[:, 0], sec[:, i])
    cy, rx, rf, rb = [from_pts(i).astype(F) for i in (1, 2, 3, 4)]
    z0, z1 = float(sec[0, 0]), float(sec[-1, 0])
    pf = p if pf is None else pf

    def fn(x, y, z):
        q = np.clip((z - z0) / (z1 - z0), 0, 1) * 255
        i = np.minimum(q.astype(np.int32), 254)
        u = (q - i).astype(F)
        at = lambda a: a[i] * (1 - u) + a[i + 1] * u
        dy = y - at(cy)
        ry = np.where(dy > 0, at(rf), at(rb))
        pw = np.where(dy > 0, pf, p)
        ax, ay = np.abs(x) / at(rx), np.abs(dy) / ry
        rho = np.maximum(ax ** pw + ay ** pw, 1e-8) ** (1.0 / pw)
        rad = np.sqrt(x * x + dy * dy) / np.maximum(rho, 1e-4)
        d = (rho - 1.0) * np.minimum(rad, np.maximum(at(rx), ry))
        over = np.maximum(z - z1, z0 - z)
        return np.where(over > 0, np.sqrt(np.maximum(d, 0) ** 2 + over * over), np.maximum(d, over))
    r = float(max(sec[:, 2].max(), sec[:, 3].max(), sec[:, 4].max())) * 1.1
    cmin, cmax = float(sec[:, 1].min()), float(sec[:, 1].max())
    return Prim(fn, (-r, cmin - r, z0), (r, cmax + r, z1))


def _smooth_interp(xq, xs, ys):
    """A monotone-enough Catmull-Rom through (xs, ys) at xq."""
    n = len(xs)
    m = np.gradient(ys, xs)
    i = np.clip(np.searchsorted(xs, xq) - 1, 0, n - 2)
    h = xs[i + 1] - xs[i]
    t = (xq - xs[i]) / h
    return (2 * t ** 3 - 3 * t ** 2 + 1) * ys[i] + (t ** 3 - 2 * t ** 2 + t) * h * m[i] \
        + (-2 * t ** 3 + 3 * t ** 2) * ys[i + 1] + (t ** 3 - t ** 2) * h * m[i + 1]


def shell(fld, base, off, region, lab, k=0.0):
    """A layer `off` metres over the base field, where region(x, y, z) < 0 (its value is a distance): a garment."""
    x, y, z = fld.grid()
    d = np.maximum(base.d - off, region(x, y, z))
    if k > 0:
        h = np.clip(0.5 + 0.5 * (fld.d - d) / k, 0, 1)
        fld.lab = np.where(d < fld.d, lab, fld.lab)
        fld.d = fld.d * (1 - h) + d * h - k * h * (1 - h)
    else:
        fld.lab = np.where(d < fld.d, lab, fld.lab)
        fld.d = np.minimum(fld.d, d)
    return fld


# ---------------------------------------------------------------------------------------------- the head
def _almond(s):
    """The eye's opening: a vesica in the face's plane, canted, pushed through along y."""
    ex, ey, ez = EYE
    c, si = math.cos(CANT), math.sin(CANT)
    w, h = EYE_W, EYE_H
    R = (w * w + h * h) / (2 * h)      # the arcs' radius

    def fn(x, y, z):
        px, pz = s * x - ex, z - ez
        u = px * c + pz * si
        v = -px * si + pz * c
        # the upper lid arcs higher than the lower one, its peak a little to the inside
        up = np.sqrt((u + 0.0015) ** 2 + (v + (R - h)) ** 2) - R
        lo = np.sqrt(u * u + (v - (R * 1.25 - h * 0.72)) ** 2) - R * 1.25
        d2 = np.maximum(up, lo)
        return np.maximum(d2, np.maximum(ey - 0.008 - y, y - 0.15))
    return Prim(fn, (-0.08, ey - 0.012, ez - 0.03), (0.08, 0.15, ez + 0.03))


def _lid_edge(s, upper, n=11):
    ex, ey, ez = EYE
    c, si = math.cos(CANT), math.sin(CANT)
    pts = []
    for t in np.linspace(-1, 1, n):
        u = t * EYE_W * 1.02
        v = (EYE_H * (1 - t * t) ** 0.8 + 0.0002) * (1.0 if upper else -0.62) + (0.0009 * (1 - t) * upper)
        x = ex + u * c - v * si
        z = ez + u * si + v * c
        # on the eyeball's sphere, a hair out
        dx, dz = x - ex, z - ez
        dy = math.sqrt(max((EYE_R + 0.0018) ** 2 - dx * dx - dz * dz, 1e-6))
        pts.append((s * x, ey + dy, z))
    return pts


def head(vox=0.0013):
    """Skin of the head and neck (the mask rides on this field)."""
    h = Field((-0.125, -0.19, 1.33), (0.125, 0.145, 1.87), vox)
    # the skull and jaw: an adult oval, the cheekbones high, the jaw tapering to a defined chin
    skull = loft([(1.504, 0.072, 0.012, 0.016, 0.014), (1.514, 0.061, 0.033, 0.033, 0.033), (1.530, 0.050, 0.0485, 0.043, 0.052),
                  (1.552, 0.040, 0.0620, 0.052, 0.074), (1.580, 0.030, 0.0705, 0.0625, 0.092), (1.610, 0.022, 0.0760, 0.0715, 0.104),
                  (1.640, 0.016, 0.0785, 0.0765, 0.110), (1.665, 0.012, 0.0785, 0.0780, 0.112), (1.690, 0.008, 0.0730, 0.0740, 0.105),
                  (1.710, 0.004, 0.0580, 0.0600, 0.083), (1.724, 0.000, 0.0320, 0.0340, 0.046)], 2.1, 2.5)
    h.add(skull, 0.0, SKIN, "head")
    h.add(cap((0, -0.012, 1.36), (0, 0.004, 1.545), 0.0485, 0.0445), 0.018, SKIN, "head")
    h.base = h.d.copy()
    for s in (-1, 1):
        # the sternomastoid's line and the cheekbone: quiet forms, she's lean
        h.add(cap((s * 0.043, -0.03, 1.545), (s * 0.016, 0.03, 1.385), 0.0095, 0.012), 0.016, SKIN, "head")
        h.add(ell((s * 0.056, 0.055, 1.594), (0.0145, 0.020, 0.0105), (0.0, 0.0, -s * 0.38)), 0.016, SKIN, "head")
        h.add(ell((s * 0.041, 0.0785, 1.6425), (0.026, 0.0095, 0.0052)), 0.020, SKIN, "head")      # the brow bone
    # the nose: a straight fine bridge, a neat tip, narrow wings
    h.add(cap((0, 0.0900, 1.632), (0, 0.1050, 1.586), 0.0034, 0.0050), 0.010, SKIN, "head")
    h.add(ell((0, 0.1038, 1.5815), (0.0066, 0.0066, 0.0058)), 0.008, SKIN, "head")
    for s in (-1, 1):
        h.add(ell((s * 0.0088, 0.0950, 1.5755), (0.0043, 0.0058, 0.0040)), 0.005, SKIN, "head")
        h.sub(ell((s * 0.0044, 0.1010, 1.5722), (0.0021, 0.0034, 0.0013)), 0.0014, SKIN)
    h.sub(cap((0, 0.0985, 1.5675), (0, 0.0990, 1.5565), 0.0014, 0.0019), 0.005)        # the philtrum
    # the lips, full and clearly shaped: a cupid's bow, the lower lip the fuller, a slight knowing lift at the corners
    upper = path([(-0.0232, 0.0872, 1.5486), (-0.0140, 0.0932, 1.5462), (-0.0052, 0.0985, 1.5495), (0, 0.0985, 1.5472),
                  (0.0052, 0.0985, 1.5495), (0.0140, 0.0932, 1.5462), (0.0232, 0.0872, 1.5486)],
                 [0.0012, 0.0034, 0.0042, 0.0040, 0.0042, 0.0034, 0.0012])
    lower = path([(-0.0215, 0.0872, 1.5478), (-0.0115, 0.0938, 1.5398), (0, 0.0978, 1.5368), (0.0115, 0.0938, 1.5398),
                  (0.0215, 0.0872, 1.5478)], [0.0012, 0.0046, 0.0062, 0.0046, 0.0012])
    h.add(upper, 0.0026, LIP, "head")
    h.add(lower, 0.0026, LIP, "head")
    h.sub(path([(-0.0240, 0.0885, 1.5490), (-0.0125, 0.0985, 1.5436), (-0.0040, 0.1038, 1.5436), (0, 0.1042, 1.5424), (0.0040, 0.1038, 1.5436),
                (0.0125, 0.0985, 1.5436), (0.0240, 0.0885, 1.5490)], [0.0005, 0.0009, 0.0010, 0.0010, 0.0010, 0.0009, 0.0005]), 0.0009, LIP)
    h.sub(ell((0, 0.0985, 1.5272), (0.0135, 0.0036, 0.0028)), 0.005)                    # under the lower lip
    h.add(ell((0, 0.0890, 1.5170), (0.0135, 0.0088, 0.0095)), 0.010, SKIN, "head")      # the chin
    for s in (-1, 1):
        h.sub(ell((s * 0.0285, 0.0870, 1.5465), (0.0035, 0.0030, 0.0045)), 0.007)       # the mouth's corners set in
    h.base = h.d.copy()
    # the eye sockets, the lids
    for s in (-1, 1):
        ex, ey, ez = EYE
        h.sub(ell((s * (ex + 0.001), 0.0985, ez + 0.002), (0.025, 0.0095, 0.0125)), 0.010)
        h.add(ell((s * (ex + 0.0015), ey + 0.0040, ez + 0.0070), (0.0215, 0.0155, 0.0072)), 0.008, LID, "head")     # the upper lid's fold
        h.add(ell((s * (ex + 0.0005), ey + 0.0035, ez - 0.0085), (0.0195, 0.0145, 0.0055)), 0.006, LID, "head")     # the lower lid
        h.sub(_almond(s), 0.0007, LID)
        h.add(path(_lid_edge(s, True), [0.0010] + [0.0015] * 9 + [0.0009]), 0.0012, LID, "head")
        h.add(path(_lid_edge(s, False), [0.0006] + [0.0009] * 9 + [0.0006]), 0.0010, LID, "head")
    # the ears: flat to the head
    for s in (-1, 1):
        at = np.array((s * 0.0755, -0.008, 1.600), F)
        h.add(ell(tuple(at + (s * 0.0035, 0, 0)), (0.0042, 0.0155, 0.0265), (0.0, s * 0.16, 0.0)), 0.004, SKIN, "head")
        h.sub(ell(tuple(at + (s * 0.0090, 0.0015, 0.004)), (0.0040, 0.0090, 0.0165)), 0.0030, EAR_IN)
    return h


def eyes(vox=0.0007):
    """The two eyeballs."""
    ex, ey, ez = EYE
    f = Field((-0.06, ey - 0.02, ez - 0.02), (0.06, ey + 0.02, ez + 0.02), vox)
    for s in (-1, 1):
        f.add(sph((s * ex, ey, ez), EYE_R), 0.0, 1, "head")
    return f


# ---- the porcelain half-mask: a shell on the face
def smax(a, b, k):
    h = np.clip(0.5 + 0.5 * (a - b) / k, 0, 1)
    return b * (1 - h) + a * h + k * h * (1 - h)


# the face plate (px in a 640 frame) -> the head sculpt: x by the eyes' spacing, z by landmarks (brow, eyes, nose tip, mouth, chin)
PLATE_PX = 170.0 / (2 * EYE[0])
PLATE_Z = ((1.504, 565.0), (1.5424, 462.0), (1.5825, 400.0), (1.619, 312.0), (1.6425, 265.0), (1.724, 55.0))
MASK_OFF = (0.0, 30.0, 60.0, 85.0, 110.0, 140.0, 165.0, 178.0)        # px off the middle
MASK_TOP = (324.0, 332.0, 344.0, 347.0, 340.0, 312.0, 272.0, 254.0)   # its upper and lower edge, px down the plate
MASK_BOT = (366.0, 378.0, 390.0, 393.0, 390.0, 376.0, 343.0, 298.0)


def plate_z(py):
    zs = np.array([p[0] for p in PLATE_Z], F)
    ys = np.array([p[1] for p in PLATE_Z], F)
    return np.interp(-np.asarray(py, F), -ys, zs).astype(F)


def mask_region(x, y, z):
    """The band, on the plate's own lines."""
    off = np.abs(x) * PLATE_PX
    px = np.array(MASK_OFF, F)
    top = plate_z(np.interp(off, px, np.array(MASK_TOP, F)))
    bot = plate_z(np.interp(off, px, np.array(MASK_BOT, F)))
    r = smax(z - top, bot - z, 0.002)
    return smax(smax(r, 0.012 - y, 0.003), off - 178.0, 1.0)


def mask(h, vox=0.0013):
    f = h.like()
    x, y, z = f.grid()
    d0 = h.d
    reg = mask_region(x, y, z)
    f.d = np.maximum(np.maximum(d0 - 0.0034, -(d0 - 0.0002)), reg).astype(F)
    f.lab[:] = PORC
    return f


# ---------------------------------------------------------------------------------------------- the hair
HAIRLINE = np.array(((0, 1.682), (22, 1.684), (40, 1.672), (55, 1.655), (68, 1.636), (85, 1.636), (100, 1.634), (109, 1.586),
                     (118, 1.558), (140, 1.526), (160, 1.510), (180, 1.506)), F)
BUN = (0.0, -0.058, 1.748)      # where the ponytail is tied


def S_interp(xq, xs, ys):
    return _smooth_interp(np.clip(xq, xs[0], xs[-1]), xs, ys)


def hair(h):
    """The sleek cap pulled up into the bun: a shell on the skull below the hairline, its big locks raked to the bun."""
    f = h.like()
    x, y, z = f.grid()
    th = np.degrees(np.arctan2(np.abs(x), y - 0.01))
    zh = S_interp(th, HAIRLINE[:, 0], HAIRLINE[:, 1]).astype(F)
    # (the parting's little dip off centre)
    fade = smooth(0.0, 0.035, z - zh)
    thick = 0.0022 + (0.0048 + 0.0080 * smooth(1.60, 1.70, z) + 0.008 * smooth(0.02, -0.08, y)) * fade
    # the volume: over the flat top of the skull (no ears, no face: the base field)
    cr = ell((0, -0.016, 1.650), (0.0830, 0.1230, 0.0890))
    base = h.base
    b0, b1 = base - thick, cr.fn(x, y, z) + 0.02 * (1 - fade)
    kk = 0.022
    hh = np.clip(0.5 + 0.5 * (b0 - b1) / kk, 0, 1)
    a = b0 * (1 - hh) + b1 * hh - kk * hh * (1 - hh)        # (a smooth union: no shelf at the temple)
    # raked strands: grooves running from the hairline to the bun
    ph = np.arctan2(x - BUN[0], y - BUN[1])
    a = a + 0.0022 * np.sin(ph * 7 + 3.6 * fbm(x, y, z, 9.0, 2)) * fade
    d = smax(a, zh - z, 0.002)
    f.d = np.maximum(d, -(base + 0.004)).astype(F)
    f.lab[:] = HAIR
    # the ponytail's base, the red thread tied round it
    f.add(ell(BUN, (0.034, 0.036, 0.020)), 0.018, HAIR, "head")
    for k in range(4):
        z0 = BUN[2] + 0.010 + k * 0.0052
        ring = [(BUN[0] + 0.0245 * math.cos(a), BUN[1] - 0.012 + 0.0245 * math.sin(a), z0 + 0.003 * math.sin(a * 2 + k)) for a in np.linspace(0, math.tau, 13)]
        f.add(path(ring, [0.0034] * 13), 0.0, THREAD, "head")
    return f


def lock(pts, r0, r1, vox=0.0013, lab=HAIR, spread=0.0):
    pts = np.array(pts, F)
    lo, hi = pts.min(0) - 0.045, pts.max(0) + 0.045
    # a catmull chain
    q = np.vstack([2 * pts[0] - pts[1], pts, 2 * pts[-1] - pts[-2]])
    cc = []
    for i in range(1, len(q) - 2):
        for t in np.linspace(0, 1, 6, endpoint=False):
            a, b, c, d = q[i - 1], q[i], q[i + 1], q[i + 2]
            cc.append(0.5 * (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (3 * b - a - 3 * c + d) * t ** 3))
    cc.append(pts[-1])
    cc = np.array(cc, F)
    n = len(cc)
    rr = [float(r0 + (r1 - r0) * (i / (n - 1)) ** 1.2) * min(1.0, (0.62 if r0 > 0.02 else 0.28) + (2.4 if r0 > 0.02 else 3.2) * i / (n - 1)) for i in range(n)]
    f = Field(lo, hi, vox)
    f.add(path([tuple(c) for c in cc], rr), 0.0, lab, "head")
    if r0 > 0.03:
        for k, tw in ((-1, 0.4), (1, 1.5), (1, 3.1)):
            tt = np.linspace(0, 1, n)
            off = np.stack((np.cos(tt * 5.0 + tw), np.sin(tt * 5.0 + tw) * 0.8, 0 * tt), 1) * (0.018 * np.sin(np.minimum(tt * 1.1, 1.0) * math.pi))[:, None]
            f.add(path([tuple(c) for c in (cc + off)], [r * 0.66 for r in rr]), 0.008, lab, "head")
    if spread > 0:
        for k in (-1, 1):
            tt = np.linspace(0, 1, n)
            side = np.array((np.sign(pts[-1][0]) * 0.75, -0.65, 0.0), F)
            off = cc + side[None, :] * (spread * k * np.sin(np.minimum(tt * 1.15, 1.0) * math.pi) ** 0.7)[:, None]
            f.add(path([tuple(c) for c in off], [r * 0.86 for r in rr]), 0.004, lab, "head")
    return f


LOCKS = {
    # two thick curtains from the centre part, sweeping over the temples, falling past the jaw, the tips turning in
    "lockR": [(0.004, 0.083, 1.700), (0.040, 0.081, 1.678), (0.0690, 0.067, 1.640), (0.0830, 0.052, 1.585), (0.0860, 0.048, 1.530),
              (0.0790, 0.056, 1.478), (0.0620, 0.074, 1.440)],
    "lockL": [(-0.004, 0.083, 1.700), (-0.040, 0.081, 1.678), (-0.0690, 0.067, 1.640), (-0.0830, 0.052, 1.585), (-0.0860, 0.048, 1.530),
              (-0.0790, 0.056, 1.478), (-0.0620, 0.074, 1.440)],
    # the high ponytail: up off the tie, arching back, full through the middle, an S down to her waist
    "tail": [(0.0, -0.078, 1.748), (0.003, -0.116, 1.772), (0.008, -0.158, 1.740), (0.016, -0.190, 1.650), (0.028, -0.200, 1.530),
             (0.040, -0.186, 1.400), (0.046, -0.176, 1.270), (0.036, -0.192, 1.150), (0.016, -0.214, 1.040)],
}
LOCK_R = {"lockR": (0.0125, 0.0012), "lockL": (0.0125, 0.0012), "tail": (0.0440, 0.0030)}


def needle_field(items, vox=0.0011, eye_w=0.0062, eye_l=0.021):
    """Long sewing needles [(eye end, point, r)], flattened at a pierced eye. Returns a field."""
    pts = np.array([p for a, b, r in items for p in (a, b)], F)
    f = Field(pts.min(0) - 0.016, pts.max(0) + 0.016, vox)
    for a, b, r in items:
        a, b = np.array(a, F), np.array(b, F)
        u = (b - a) / np.linalg.norm(b - a)
        # the eye in a plane holding the needle
        nrm = np.cross(u, (0.31, 0.21, 0.92))
        nrm /= np.linalg.norm(nrm)
        f.add(path([a + u * 0.002, a + u * 0.05, a + u * 0.11, b], [r * 1.05, r * 1.2, r * 0.85, 0.0007]), 0.0, NEEDLE, "head")
        cc = a + u * (eye_l * 0.75)
        ring_a = [cc + nrm * eye_w * math.cos(t) * 1.0 + u * eye_l * math.sin(t) for t in np.linspace(0, math.tau, 15)]
        f.add(path(ring_a, [r * 0.72] * 15), 0.0015, NEEDLE, "head")
        f.sub(ell(tuple(cc), (0.0001, 0.0001, 0.0001)), 0.0)
        hole = lambda x, y, z, cc=cc, u=u, nrm=nrm: (((x - cc[0]) * u[0] + (y - cc[1]) * u[1] + (z - cc[2]) * u[2]) / (eye_l - 0.0022)) ** 2
        side = np.cross(u, nrm)
        def carve(x, y, z, cc=cc, u=u, nrm=nrm, side=side):
            px, py, pz = x - cc[0], y - cc[1], z - cc[2]
            a1 = px * u[0] + py * u[1] + pz * u[2]
            a2 = px * nrm[0] + py * nrm[1] + pz * nrm[2]
            return (np.sqrt((a1 / (eye_l - r)) ** 2 + (a2 / (eye_w - r * 0.75)) ** 2) - 1.0) * (eye_w - r)
        f.sub(Prim(carve, cc - 0.035, cc + 0.035), 0.0)
    return f


HAIR_NEEDLES = [((-0.190, -0.090, 1.842), (0.185, -0.030, 1.690), 0.0040)]      # the one silver pin through the tie


# ---------------------------------------------------------------------------------------------- the body
def figure(J, vox=0.0032):
    """The fitted figure, feet to collar: torso + pelvis (group 0), each leg (groups 1, 2): a mannequin the clothes
    are shells on. An athletic adult woman: the waist at 59%, long legs, modest bust."""
    b = Field((-0.27, -0.18, -0.01), (0.27, 0.27, 1.44), vox)
    tor = loft([(0.768, 0.000, 0.105, 0.070, 0.075), (0.800, 0.000, 0.147, 0.089, 0.098), (0.845, -0.004, 0.156, 0.094, 0.106),
                (0.905, -0.002, 0.148, 0.090, 0.099), (0.965, 0.000, 0.127, 0.082, 0.088), (1.020, 0.002, 0.109, 0.077, 0.074),
                (1.070, 0.004, 0.113, 0.082, 0.076), (1.130, 0.006, 0.128, 0.092, 0.084), (1.200, 0.008, 0.145, 0.100, 0.092),
                (1.270, 0.006, 0.150, 0.092, 0.088), (1.325, 0.000, 0.128, 0.070, 0.070), (1.372, -0.006, 0.070, 0.054, 0.056),
                (1.400, -0.010, 0.050, 0.048, 0.050)], 2.25)
    b.add(tor, 0.0, CORSET, "hips")
    for s in (-1, 1):
        b.add(cap((s * 0.03, -0.012, 1.378), (s * 0.150, -0.002, 1.300), 0.041, 0.043), 0.03, CORSET, "hips")     # the shoulder's slope
        b.add(ell((s * 0.066, 0.078, 1.190), (0.062, 0.042, 0.056), (-0.1, 0, s * 0.12)), 0.035, CORSET, "hips")   # the bust, modest
        b.add(ell((s * 0.072, -0.048, 0.838), (0.070, 0.056, 0.074)), 0.05, CORSET, "hips")
    b.sub(cap((0, -0.085, 1.27), (0, -0.075, 0.98), 0.005, 0.007), 0.03)                  # the spine's valley
    return b


def legs(b, J):
    """One Field per leg's prims, merged in `b`, with their bones (groups 1, 2)."""
    for g, s, n in ((1, 1, "R"), (2, -1, "L")):
        L = b.like()
        L.grp = g
        hx = float(J["thigh." + n][0])
        kz, az = float(J["shin." + n][2]), 0.082
        L.add(cap((hx + s * 0.006, -0.004, 0.790), (hx + s * 0.002, 0.004, kz + 0.018), 0.082, 0.0485), 0.0, TROUSER, "thigh." + n)
        L.add(ell((hx + s * 0.022, 0.0, 0.662), (0.050, 0.068, 0.145), (0, -s * 0.05, 0)), 0.03, TROUSER, "thigh." + n)    # the outer thigh
        L.add(ell((hx, 0.024, 0.635), (0.056, 0.05, 0.14)), 0.03, TROUSER, "thigh." + n)
        L.add(cap((hx, 0.004, kz + 0.015), (hx, -0.002, kz - 0.03), 0.0465, 0.0425), 0.02, TROUSER, "shin." + n)
        L.add(ell((hx, 0.024, kz + 0.002), (0.030, 0.0235, 0.03)), 0.014, TROUSER, "shin." + n)                            # the knee
        L.add(cap((hx, -0.002, kz - 0.02), (hx, 0.000, az + 0.035), 0.043, 0.030), 0.02, TROUSER, "shin." + n)
        L.add(ell((hx + s * 0.002, -0.022, kz - 0.115), (0.0385, 0.043, 0.105)), 0.03, TROUSER, "shin." + n)               # the calf
        # the foot in its heeled boot (a low 3.5 cm heel: a long line, still a fighter's boot)
        L.add(cap((hx, 0.000, az + 0.03), (hx, 0.012, az - 0.012), 0.031, 0.036), 0.015, BOOT, "shin." + n)
        L.add(ell((hx + s * 0.002, 0.06, 0.052), (0.0385, 0.082, 0.0355)), 0.026, BOOT, "foot." + n)
        L.add(ell((hx + s * 0.004, 0.128, 0.034), (0.0375, 0.062, 0.0255)), 0.018, BOOT, "foot." + n)
        L.add(cap((hx, -0.032, 0.060), (hx, -0.046, 0.028), 0.030, 0.0265), 0.012, BOOT, "foot." + n)                    # the heel block
        L.sub(box((hx, 0.09, -0.03), (0.08, 0.17, 0.03)), 0.002)
        L.sub(box((hx, 0.042, 0.002), (0.06, 0.042, 0.018)), 0.006)                        # the arch, under the heel's step
        b.merge(L, k=0.014, kfn=lambda x, y, z: 0.016 * smooth(0.74, 0.80, z))
    return b


def neckline(x):
    """The corset's top: closed high, under the scarf (the reference's cut-out is left out: tasteful, item 108)."""
    return 1.345 + 0.0 * x


def corset_low(x, y):
    """Its lower edge: a point at the middle front, above the bare midriff."""
    a = np.abs(x)
    return np.where(y > -0.02, 1.012 - 0.044 * np.exp(-(a / 0.022) ** 2) + 0.020 * smooth(0.03, 0.11, a), 1.040)


WAIST_Z = 0.936                    # the capris' top


def lapel_x(z):
    """The shrug's front edge: how far from the middle it stands open over the corset."""
    return np.interp(z, (1.15, 1.22, 1.30, 1.37, 1.45), (0.125, 0.106, 0.086, 0.062, 0.05)).astype(F)


def strap_d(x, z, a=(-0.135, 1.335), b=(0.150, 0.955)):
    ax, az = a
    dx, dz = b[0] - ax, b[1] - az
    return ((x - ax) * dz - (z - az) * dx) / math.hypot(dx, dz)


def dress_labels(p, lab):
    """The garment edges, exactly (the labels are per voxel: 3 mm stairs in the paint). Same order as dress()."""
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    a = np.abs(x)
    up = np.isin(lab, (SKIN, CORSET, CORSET_SEAM, JACKET, JACKET_DK, TROUSER, LEATHER))
    o2 = np.where(z >= WAIST_Z, SKIN, TROUSER)
    cl = corset_low(x, y)
    o2 = np.where((z >= cl) & (z <= neckline(x)), CORSET, o2)
    front = np.where(y > -0.01, lapel_x(z) - a, -1.0)
    jk = (front < 0) & (z > 1.15 + 0.05 * smooth(-0.02, 0.09, y))
    o2 = np.where(jk, JACKET, o2)
    o2 = np.where((np.abs(front + 0.0045) < 0.0045) & (z > 1.15), JACKET_DK, o2)
    belt = np.abs(z - 0.922 + 0.010 * (x > 0) * smooth(0.0, 0.14, a)) < 0.0150
    o2 = np.where(belt, LEATHER, o2)
    return np.where(up & (z > 0.8), o2, lab)


def dress(b):
    """Clothes on the figure: labels and thin layers, all one surface (nothing to poke through at the joints)."""
    base = type("B", (), {"d": b.d.copy()})()
    out = b
    x, y, z = b.grid()
    a = np.abs(x)
    cl = corset_low(x, y)
    nl = neckline(x)
    out.lab = np.where(z > WAIST_Z, SKIN, TROUSER)
    # the corset
    reg = np.maximum(cl - z, z - nl)
    shell(out, base, 0.0052, lambda x, y, z: reg, CORSET)
    # its seams
    for dx in (0.0, 0.040, 0.086):
        seam = (np.abs(a - dx) - 0.0030).astype(F)
        out.d = np.where(reg < -0.003, out.d + 0.0016 * smooth(0.0016, -0.0016, seam), out.d)
    # the capris end mid-calf in a turned cuff, standing a little off the leg; a bare span of calf; then the boots
    hem = 0.418
    out.d = np.where((z > hem - 0.0) & (z < 0.56) & (z < 0.8), out.d - 0.0035 * smooth(0.56, 0.46, z), out.d)
    cuff = np.maximum(hem - z, z - (hem + 0.024))
    shell(out, base, 0.0078, lambda x, y, z: cuff, TROUSER, 0.0010)
    bare = (z < hem) & (z > 0.372)
    out.lab = np.where(bare & (z < 0.8), SKIN, out.lab)
    out.d = np.where(bare, out.d + 0.0020, out.d)
    top = 0.368 + 0.014 * np.where(y > 0.0, 1.0, 0.0)
    rb = z - top
    shell(out, base, 0.0052, lambda x, y, z: rb, BOOT, 0.002)
    rc = np.maximum(z - top, top - 0.016 - z)
    shell(out, base, 0.0074, lambda x, y, z: rc, BOOT_TOP, 0.001)
    sole = z - 0.016
    out.lab = np.where((sole < 0) & (out.d > -0.012), LEATHER, out.lab)
    # the two straps round her right thigh
    for zz in (0.690, 0.615):
        rt = np.maximum(np.maximum(np.abs(z - zz) - 0.0125, 0.02 - x), x - 0.26)
        shell(out, base, 0.0072, lambda x, y, z: rt, LEATHER, 0.0008)
    # the short shrug: shoulders and back, the front edge piped red
    front = np.where(y > -0.01, lapel_x(z) - a, -1.0)
    lo, hi = 1.15 + 0.05 * smooth(-0.02, 0.09, y), 1.455
    rj = np.maximum(front, np.maximum(lo - z, z - hi))
    shell(out, base, 0.0096, lambda x, y, z: rj, JACKET, 0.0012)
    edge = np.maximum(np.abs(front + 0.0045) - 0.0045, np.maximum(lo - z, z - hi))
    shell(out, base, 0.0118, lambda x, y, z: edge, JACKET_DK, 0.0012)
    # the belt, its tail dropping toward the spool at her right hip
    belt = np.abs(z - 0.922 + 0.010 * (x > 0) * smooth(0.0, 0.14, a)) - 0.0150
    shell(out, base, 0.0120, lambda x, y, z: belt, LEATHER, 0.0008)
    return out


def arm(J, s, n, vox=0.0026):
    """One arm: a layered stitched pauldron, a half-sleeve to the elbow, a little bare forearm, a laced bracer to the wrist."""
    sx = float(J["upper_arm." + n][0])
    sz, ez, wz = float(J["upper_arm." + n][2]), float(J["forearm." + n][2]), float(J["hand." + n][2])
    a = Field((sx - 0.11, -0.11, wz - 0.05), (sx + 0.11, 0.11, sz + 0.10), vox)
    a.add(cap((sx, 0, sz + 0.005), (sx, 0, ez + 0.03), 0.0425, 0.0355), 0.0, JACKET, "upper_arm." + n)
    a.add(ell((sx - s * 0.003, 0.008, ez + 0.105), (0.0385, 0.0415, 0.075)), 0.02, JACKET, "upper_arm." + n)
    a.add(cap((sx, 0, ez + 0.03), (sx, 0.001, ez - 0.012), 0.0355, 0.0345), 0.012, JACKET, "forearm." + n)
    a.add(cap((sx, 0.001, ez - 0.012), (sx, 0, wz + 0.006), 0.0345, 0.0245), 0.012, SKIN, "forearm." + n)
    a.add(ell((sx, 0.003, ez - 0.055), (0.0345, 0.036, 0.07)), 0.014, SKIN, "forearm." + n)
    base = type("B", (), {"d": a.d.copy()})()
    # the stitched bracer
    br = lambda x, y, z: np.maximum(wz - 0.024 - z, z - (ez - 0.040))
    shell(a, base, 0.0048, br, TAPE, 0.001)
    # the half-sleeve's red end
    rc = lambda x, y, z: np.maximum(ez - 0.016 - z, z - (ez + 0.004))
    shell(a, base, 0.0030, rc, JACKET_DK, 0.0012)
    # the pauldron, two lapped plates over the shoulder
    a.add(ell((sx + s * 0.004, 0.0, sz + 0.008), (0.0530, 0.0610, 0.0480), (0, s * 0.30, 0)), 0.006, PAULDRON, "pauldron." + n)
    a.add(ell((sx + s * 0.012, 0.0, sz - 0.030), (0.0490, 0.0570, 0.0290), (0, s * 0.42, 0)), 0.0025, PAULDRON, "pauldron." + n)
    return a


FING = {"a": ("index", 0.0290, 0.0745), "m": ("middle", 0.0100, 0.0835), "r": ("ring", -0.0090, 0.0770), "p": ("pinky", -0.0265, 0.0600)}


def finger_points(sx, wz, s, y0, ln, curl):
    """Knuckle, two joints and the tip of a gently curled finger, the palm facing the thigh (-s on x)."""
    k = np.array((sx - s * 0.002, y0, wz - 0.0885), F)
    seg = [ln * 0.44, ln * 0.31, ln * 0.25]
    ang = 0.0
    p = [k]
    for i, l in enumerate(seg):
        ang += curl[i]
        p.append(p[-1] + np.array((-s * math.sin(ang) * l, 0.03 * l, -math.cos(ang) * l), F))
    return p


def right_hand(J, vox=0.00115):
    """Her draw hand: long adult fingers, the palm to the thigh, three thimble claws (the kit's silver claw-tips)."""
    s, n = 1, "R"
    sx, wz = float(J["hand.R"][0]), float(J["hand.R"][2])
    f = Field((sx - 0.075, -0.075, wz - 0.20), (sx + 0.05, 0.085, wz + 0.035), vox)
    f.add(cap((sx, 0, wz + 0.02), (sx, 0.002, wz - 0.012), 0.0255, 0.0235), 0.0, SKIN, "hand.R")
    f.add(ell((sx + 0.001, 0.002, wz - 0.052), (0.0155, 0.0405, 0.044)), 0.012, SKIN, "hand.R")
    f.add(ell((sx - 0.0055, 0.024, wz - 0.040), (0.0115, 0.018, 0.028)), 0.008, SKIN, "hand.R")     # the thumb's pad
    bones = {"a": ("fing_a1.R", "fing_a2.R"), "m": ("fing_b1.R", "fing_b2.R"), "r": ("fing_b1.R", "fing_b2.R"), "p": ("fing_b1.R", "fing_b2.R")}
    knuckles = {}
    tips = {}
    for k, (nm, y0, ln) in FING.items():
        P = finger_points(sx, wz, s, y0, ln, (0.10, 0.30, 0.34))
        knuckles[k], tips[k] = P, P[-1]
        r = 0.0088 if k != "p" else 0.0075
        b1, b2 = bones[k]
        f.add(cap(P[0], P[1], r * 1.04, r * 0.96), 0.006, SKIN, b1)
        f.add(cap(P[1], P[2], r * 0.96, r * 0.86), 0.0015, SKIN, b2)
        f.add(cap(P[2], P[3], r * 0.86, r * 0.72), 0.001, SKIN, b2)
        f.add(ell(tuple(P[3] - (P[3] - P[2]) * 0.02 + np.array((s * 0.0045, 0, 0), F)), (0.0024, 0.0058, 0.0072)), 0.0005, NAIL, b2)
    # the thumb
    t0 = np.array((sx - 0.006, 0.030, wz - 0.022), F)
    t1 = t0 + (-0.012, 0.022, -0.030)
    t2 = t1 + (-0.009, 0.010, -0.026)
    t3 = t2 + (-0.007, 0.006, -0.021)
    f.add(cap(t0, t1, 0.0125, 0.0105), 0.008, SKIN, "thumb1.R")
    f.add(cap(t1, t2, 0.0100, 0.0092), 0.0015, SKIN, "thumb2.R")
    f.add(cap(t2, t3, 0.0092, 0.0072), 0.001, SKIN, "thumb2.R")
    return f, {"tips": tips, "knuckles": knuckles, "thumb": (t0, t1, t2, t3)}


def grip_frame(J):
    """The bow in her left hand at rest: the fist's centre, the bow's long axis A (top forward and up) and the side the
    string lies on, S (toward her elbow): so with the arm out and the bow upright the string comes to her."""
    sx, wz = float(J["hand.L"][0]), float(J["hand.L"][2])
    c = np.array((sx, 0.002, wz - 0.066), F)
    A = np.array((0.0, 0.72, 0.694), F)
    A = A / np.linalg.norm(A)
    S = np.array((0.0, -A[2], A[1]), F)
    return c, A, S


GRIP_R = 0.0172


def left_hand(J, vox=0.00115):
    """Her bow hand, closed for good round the grip (Hem never lets the bow go): four fingers wrapped, thumb over."""
    sx, wz = float(J["hand.L"][0]), float(J["hand.L"][2])
    c, A, S = grip_frame(J)
    X = np.array((1.0, 0, 0), F)
    f = Field((sx - 0.075, -0.09, wz - 0.135), (sx + 0.075, 0.09, wz + 0.035), vox)
    f.add(cap((sx, 0, wz + 0.02), (sx, 0.002, wz - 0.012), 0.0255, 0.0235), 0.0, SKIN, "hand.L")
    # the back of the hand, outside (-x), from the wrist round to the knuckles
    f.add(ell((sx - 0.0125, 0.003, wz - 0.052), (0.0135, 0.038, 0.042)), 0.012, SKIN, "hand.L")
    f.add(ell((sx + 0.010, 0.012, wz - 0.040), (0.012, 0.024, 0.026)), 0.010, SKIN, "hand.L")     # the heel of the thumb
    # four fingers, each a loop round the grip (from the back of the hand, under, up the palm side)
    for i, (off, rr) in enumerate(((0.030, 0.0088), (0.0115, 0.0092), (-0.007, 0.0086), (-0.0245, 0.0075))):
        at = c + A * off
        pts = []
        for t in np.linspace(-1.75, 1.55, 8):
            d = (GRIP_R + rr * 0.92) * (-X * math.cos(t) + (-S) * math.sin(t))
            pts.append(at + d)
        f.add(path([tuple(p) for p in pts], [rr * 1.04] * 3 + [rr] * 3 + [rr * 0.82] * 2), 0.0014, SKIN, "hand.L")
    # the thumb, along the grip's far side
    a = c + A * 0.012
    pts = [a + (0.021 * X + 0.016 * S - A * 0.016), a + (0.0255 * X + 0.0005 * S + A * 0.012), a + (0.0245 * X - 0.0115 * S + A * 0.035),
           a + (0.0185 * X - 0.0185 * S + A * 0.047)]
    f.add(path([tuple(p) for p in pts], [0.0118, 0.0102, 0.0095, 0.0078]), 0.003, SKIN, "hand.L")
    return f


def coat_hem(th):
    """z of the long coat's hem at angle th (radians, 0 at the back, + toward her left... see hem_art1.coat_grid)."""
    a0 = math.radians(128)
    th = np.asarray(th, F)
    h = 0.355 + 0.205 * (np.abs(th) / a0) ** 2.4 + 0.075 * np.sin(th) + 0.026 * np.cos(th * 5.0)
    h = h - 0.09 * np.exp(-((th + 0.72) / 0.42) ** 2)        # the tail's point at the left-back
    return h + 0.07 * smooth(1.8, a0, np.abs(th))


# ---------------------------------------------------------------------------------------------- gear
# The bow's own frame: x her side, y away from the string (where the arrow flies), z the long axis, the grip at 0.
# The curve is read straight off hem_v4_props.png's left bow: the silhouette is the owner's.
BOW_LEN = 0.625
STRING_Y = -0.200
STRING_Z = 0.566


def _bow_curve():
    z = np.array((0.0, 0.060, 0.130, 0.230, 0.317, 0.447, 0.523, 0.566, 0.600, 0.625), F)
    y = np.array((0.0, 0.006, 0.027, 0.005, -0.044, -0.131, -0.180, -0.198, -0.204, -0.204), F)
    t = np.array((0.0165, 0.0180, 0.0340, 0.0250, 0.0175, 0.0135, 0.0115, 0.0160, 0.0150, 0.0018), F)     # half depth
    w = np.array((0.0165, 0.0150, 0.0100, 0.0090, 0.0078, 0.0066, 0.0060, 0.0056, 0.0050, 0.0020), F)     # half width: a flat needle
    return z, y, t, w


def _slot(zc, half_l, half_w):
    """A needle's eye through the limb, a long slot along it."""
    zs, ys, _, _ = _bow_curve()
    yc = float(np.interp(zc, zs, ys))
    dy = float(np.interp(zc + 0.01, zs, ys) - np.interp(zc - 0.01, zs, ys)) / 0.02
    n = math.hypot(1, dy)

    def fn(x, y, z):
        px, py = (np.abs(z) - zc), y - yc
        u = (px + py * dy) / n
        v = (py - px * dy) / n
        return np.sqrt((u / half_l) ** 2 + (v / half_w) ** 2) * min(half_l, half_w) - min(half_l, half_w)
    return Prim(fn, (-0.05, yc - 0.06, -0.64), (0.05, yc + 0.06, 0.64))


def bow_prim():
    zc, yc, tc, wc = _bow_curve()

    def fn(x, y, z):
        a = np.abs(z)
        cy = np.interp(a, zc, yc).astype(F)
        t = np.interp(a, zc, tc).astype(F)
        w = np.interp(a, zc, wc).astype(F)
        ax, ay = np.abs(x) / w, np.abs(y - cy) / t
        d = (np.sqrt(ax * ax + ay * ay) - 1.0) * np.minimum(w, t)
        return np.maximum(d, a - BOW_LEN)
    return Prim(fn, (-0.03, -0.25, -BOW_LEN), (0.03, 0.08, BOW_LEN))


def bow(vox=0.0016):
    f = Field((-0.05, -0.24, -0.645), (0.05, 0.07, 0.645), vox)
    f.add(bow_prim(), 0.0, STEEL, None)
    # the eyes: two long slots either side of the grip, the true needle eye at each tip
    f.sub(_slot(0.132, 0.044, 0.0165), 0.0015, STEEL)
    f.sub(_slot(0.232, 0.019, 0.0105), 0.0012, STEEL)
    f.sub(_slot(0.580, 0.025, 0.0082), 0.0010, STEEL)
    # the red-wrapped grip, thread at the string's ends
    base = type("B", (), {"d": f.d.copy()})()
    shell(f, base, 0.0034, lambda x, y, z: np.abs(z) - 0.072, THREAD, 0.0006)
    return f


def bow_to_model(p, J):
    c, A, Sd = grip_frame(J)
    X = np.array((1.0, 0, 0), F)
    Y = -Sd
    p = np.asarray(p, F)
    return c + p[..., 0:1] * X + p[..., 1:2] * Y + p[..., 2:3] * A


def _align(u):
    """A rotation taking +Z to u."""
    u = np.array(u, F)
    z = np.array((0, 0, 1), F)
    v = np.cross(z, u)
    c = float(z @ u)
    k = np.array(((0, -v[2], v[1]), (v[2], 0, -v[0]), (-v[1], v[0], 0)), F)
    return np.eye(3, dtype=F) + k + k @ k / (1 + c)


# the thread-spool quiver on her right hip, tipped out, foot behind the thigh
QUIVER_A = np.array((0.262, -0.075, 0.500), F)
QUIVER_B = np.array((0.205, 0.022, 0.860), F)
SPOOL_R = 0.066


def quiver(vox=0.0022):
    a, b = QUIVER_A, QUIVER_B
    f = Field(np.minimum(a, b) - 0.12, np.maximum(a, b) + 0.12, vox)
    u = (b - a) / np.linalg.norm(b - a)
    m = _align(u)
    c = (a + b) * 0.5
    L = float(np.linalg.norm(b - a)) * 0.5
    f.add(cyl(tuple(c), m, SPOOL_R, L - 0.010, 0.006), 0.0, THREAD, "hips")
    for t, sg in ((a, -1), (b, 1)):
        f.add(cyl(tuple(t), m, SPOOL_R + 0.024, 0.0125, 0.006), 0.0015, LACE, "hips")
    f.sub(cyl(tuple(b + u * 0.012), m, 0.034, 0.05, 0.002), 0.002, LACE)
    return f


def quiver_arrows(vox=0.0016):
    """Arrows standing in the spool's bore, nock end up, fletched."""
    a, b = QUIVER_A, QUIVER_B
    u = (b - a) / np.linalg.norm(b - a)
    s = np.cross(u, (0, 1, 0))
    s = s / np.linalg.norm(s)
    t = np.cross(u, s)
    pts = [b + u * 0.3 + s * 0.05 + t * 0.03, b - u * 0.05 + s * 0.05 + t * 0.03]
    f = Field(b - 0.16, b + u * 0.34 + 0.16, vox)
    for i, (o1, o2, up) in enumerate(((-0.022, -0.010, 0.255), (0.0, 0.016, 0.305), (0.020, -0.012, 0.275), (0.006, -0.020, 0.230))):
        e = b + u * up + s * o1 * 2.0 + t * o2 * 2.0
        lo = b - u * 0.03 + s * o1 * 0.6 + t * o2 * 0.6
        f.add(cap(tuple(e), tuple(lo), 0.0036, 0.0036), 0.0, STEEL, "hips")
        v = (lo - e) / np.linalg.norm(lo - e)
        # the fletching: two flat vanes, and a red binding under them
        for sg in (-1, 1):
            f.add(ell(tuple(e + v * 0.050 + s * sg * 0.011), (0.0165, 0.0030, 0.046), m_along(v, s)), 0.0005, FEATHER, "hips")
        f.add(cap(tuple(e + v * 0.100), tuple(e + v * 0.110), 0.0056, 0.0056), 0.0, THREAD, "hips")
    return f


def m_along(v, s):
    """A rotation: +Z along v, +X along s."""
    z = np.array(v, F)
    x = np.array(s, F)
    x = x - z * float(x @ z)
    x = x / np.linalg.norm(x)
    y = np.cross(z, x)
    return np.stack((x, y, z), 1)


ARROW_LEN = 0.78


def arrow(vox=0.0013):
    """The nocked arrow in its own frame: the nock at the origin, flying along +y: a silver needle, its spear head slotted,
    red thread bound at the head and the fletching, two tan vanes."""
    L = ARROW_LEN
    f = Field((-0.05, -0.03, -0.05), (0.05, L + 0.03, 0.05), vox)
    f.add(cap((0, 0, 0), (0, L - 0.12, 0), 0.0040, 0.0040), 0.0, STEEL)
    f.add(path([(0, L - 0.13, 0), (0, L - 0.10, 0), (0, L - 0.075, 0), (0, L, 0)], [0.0040, 0.0105, 0.0120, 0.0006]), 0.002, STEEL)
    for sg in (-1, 1):
        f.add(ell((sg * 0.0145, 0.075, 0), (0.0130, 0.052, 0.0028)), 0.0006, FEATHER)
    for yy in (0.016, 0.142, L - 0.145):
        f.add(cyl((0, yy, 0), "y", 0.0062, 0.007, 0.001), 0.0, THREAD)
    return f


def shears(vox=0.0012):
    """Tailor's scissors, closed, hanging by a red thread. Built points down, finger rings on top, flat in x-z."""
    f = Field((-0.075, -0.016, -0.25), (0.075, 0.016, 0.115), vox)
    for sg in (-1, 1):
        f.add(path([(sg * 0.0065, 0, 0.0), (sg * 0.0115, 0, -0.08), (-sg * 0.001, 0, -0.232)], [0.0095, 0.0080, 0.0007]), 0.0, STEEL)
        t = (sg * 0.031, 0, 0.066)
        ring = [(t[0] + 0.0245 * math.cos(a), 0, t[2] + 0.0365 * math.sin(a)) for a in np.linspace(0, math.tau, 19)]
        f.add(path(ring, [0.0056] * 19), 0.0, STEEL)
        f.add(path([(sg * 0.021, 0, 0.033), (sg * 0.006, 0, -0.004)], [0.0055, 0.0060]), 0.002, STEEL)
    f.add(cyl((0, 0, -0.006), "y", 0.0072, 0.0125), 0.0, BUCKLE)
    return f


SHEARS_AT = np.array((-0.098, 0.122, 0.795), F)       # at her left front, hanging from the belt


def shears_to_model(p):
    a = math.radians(-7)
    p = np.asarray(p, F)
    q = np.stack((p[..., 0] * math.cos(a) - p[..., 2] * math.sin(a), p[..., 1], p[..., 0] * math.sin(a) + p[..., 2] * math.cos(a)), -1)
    return q + SHEARS_AT


def cowl(vox=0.0028):
    """The scarf wrapped loose round her neck: soft folds slanting round it, its front sagging over the collarbones."""
    f = Field((-0.2, -0.17, 1.29), (0.2, 0.19, 1.54), vox)

    def folds(x, y, z):
        th = np.arctan2(x, y)
        return 0.0050 * np.sin(th * 3.0 + z * 34.0) + 0.0028 * np.sin(th * 7.0 - z * 52.0)
    f.add(loft([(1.330, 0.022, 0.086, 0.088, 0.078), (1.363, 0.012, 0.106, 0.098, 0.096), (1.403, 0.004, 0.096, 0.088, 0.092),
                (1.443, -0.006, 0.074, 0.074, 0.074), (1.470, -0.010, 0.062, 0.064, 0.064)], 2.0), 0.0, SCARF, "hips", folds)
    # two loose wraps, slanting opposite ways, the top one under her chin
    for z0, slant, r, rad in ((1.396, 0.016, 0.0235, 0.098), (1.444, -0.012, 0.0205, 0.080)):
        pts = [(rad * math.sin(t), 0.004 + (rad + 0.004) * math.cos(t), z0 + slant * math.sin(t) - 0.016 * (0.5 + 0.5 * math.cos(t))) for t in np.linspace(0, math.tau, 21)]
        f.add(path(pts, [r] * 21), 0.016, SCARF, "hips", folds)
    # the head and neck's room
    f.sub(cap((0, -0.012, 1.36), (0, 0.004, 1.56), 0.052, 0.050), 0.006, SCARF)
    return f


# the scarf's two long tails, hanging down her back to the thigh (the turnaround's rest; the springs stream them behind her)
SCARF_PATHS = {
    "scarftailR": [(0.028, -0.088, 1.400), (0.052, -0.116, 1.300), (0.072, -0.146, 1.125), (0.086, -0.186, 0.925), (0.092, -0.206, 0.720), (0.090, -0.216, 0.500)],
    "scarftailL": [(-0.028, -0.088, 1.400), (-0.052, -0.116, 1.300), (-0.070, -0.146, 1.125), (-0.082, -0.184, 0.925), (-0.086, -0.202, 0.700), (-0.082, -0.210, 0.455)],
}
SCARF_W = [0.040, 0.056, 0.070, 0.078, 0.076, 0.012]


if __name__ == "__main__":
    pass
