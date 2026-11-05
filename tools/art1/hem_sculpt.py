"""Hem's sculpt (ART-1, item 108): the shapes as signed distance fields (tools/art1/hem_sdf.py), all built on the
rig's own joints (art/wardens/src/hem_rig.json), so she stays on the contract armature.
Art: docs/art/gen/wardens_r3/hem_turnaround / head_sheet / mask_sheet / weapons_sheet (ext/imagegen), HEM_KIT.md.

Item 108's look: an adult woman of about 7 heads with a mature, sharp face, a tailored crimson jacket over a fitted
black corset with a modest neckline, slim trousers and tall boots, a long asymmetric coat tail. Tasteful, not sexualised.
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
    # the nose: a straight fine bridge, a small tip (under the mask, whose form follows it)
    h.add(cap((0, 0.0905, 1.630), (0, 0.1030, 1.586), 0.0040, 0.0060), 0.012, SKIN, "head")
    h.add(ell((0, 0.1025, 1.5805), (0.0080, 0.0072, 0.0068)), 0.010, SKIN, "head")
    for s in (-1, 1):
        h.add(ell((s * 0.0100, 0.0912, 1.5735), (0.0052, 0.0062, 0.0048)), 0.008, SKIN, "head")
        h.sub(ell((s * 0.0048, 0.0960, 1.5700), (0.0024, 0.0036, 0.0015)), 0.0016, SKIN)
    h.sub(cap((0, 0.0985, 1.5665), (0, 0.0995, 1.5545), 0.0017, 0.0021), 0.005)        # the philtrum
    # the lips: low forms, the smile itself is carved on the mask
    h.add(ell((0, 0.0905, 1.5450), (0.0200, 0.0055, 0.0042)), 0.006, LIP, "head")
    h.add(ell((0, 0.0900, 1.5365), (0.0165, 0.0065, 0.0052)), 0.006, LIP, "head")
    h.sub(ell((0, 0.0985, 1.5275), (0.014, 0.0035, 0.0030)), 0.006)                    # under the lower lip
    h.add(ell((0, 0.0880, 1.5175), (0.0150, 0.0085, 0.0095)), 0.012, SKIN, "head")     # the chin
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
    # a narrow black band at the throat: breaks the long neck
    base = type("B", (), {"d": h.d.copy()})()
    shell(h, base, 0.0026, lambda x, y, z: np.abs(z - 1.438) - 0.0098, CUFF, 0.0008)
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


def _mask_top(x):
    """z of its upper rim: the gilt line under the eyes, rising to a point over the bridge of the nose."""
    a = np.abs(x)
    return 1.5935 + 0.0265 * np.exp(-(a / 0.0115) ** 2) + 0.0120 * smooth(0.040, 0.0745, a)


def mask_region(x, y, z):
    top = z - _mask_top(x)
    back = 0.024 - y
    jaw = (1.5005 + (0.088 - y) * 0.92 + 0.0065 * np.exp(-(x / 0.03) ** 2) * 0.0) - z
    return smax(smax(top, back, 0.006), jaw, 0.005)


def mask(h, vox=0.0013):
    f = h.like()
    x, y, z = f.grid()
    d0 = h.d
    reg = mask_region(x, y, z)
    sheet = np.maximum(d0 - 0.0046, -(d0 - 0.0006))      # 0.6 mm off the skin, 4 mm thick
    f.d = np.maximum(sheet, reg).astype(F)
    f.lab[:] = PORC
    # the gilt rim, raised
    rim = np.maximum(np.abs(reg + 0.0004) - 0.0021, np.maximum(d0 - 0.0058, -(d0 - 0.0006)))
    f.lab = np.where(rim < f.d, GOLD, f.lab)
    f.d = np.minimum(f.d, rim).astype(F)
    return f


# ---------------------------------------------------------------------------------------------- the hair
HAIRLINE = np.array(((0, 1.692), (22, 1.694), (40, 1.680), (55, 1.655), (68, 1.636), (85, 1.636), (100, 1.634), (109, 1.586),
                     (118, 1.558), (140, 1.526), (160, 1.510), (180, 1.506)), F)
BUN = (0.0, -0.064, 1.772)


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
    thick = 0.0018 + (0.0042 + 0.0105 * smooth(1.60, 1.70, z) + 0.005 * smooth(0.02, -0.08, y)) * fade
    # the volume: over the flat top of the skull (no ears, no face: the base field)
    cr = ell((0, -0.012, 1.655), (0.0835, 0.1225, 0.0885))
    base = h.base
    a = np.minimum(base - thick, cr.fn(x, y, z) + 0.02 * (1 - fade))
    # raked strands: grooves running from the hairline to the bun
    ph = np.arctan2(x - BUN[0], y - BUN[1])
    a = a + 0.0007 * np.sin(ph * 9 + 3.2 * fbm(x, y, z, 12.0, 2)) * fade
    d = smax(a, zh - z, 0.002)
    f.d = np.maximum(d, -(base + 0.004)).astype(F)
    f.lab[:] = HAIR
    # the bun, a coil of thick locks
    f.grp = 0
    f.add(ell(BUN, (0.046, 0.046, 0.041)), 0.012, HAIR, "head")
    for k in range(3):
        a0 = k * 2.1
        pts, rr = [], []
        for t in np.linspace(0, 1, 14):
            a1 = a0 + t * 5.2
            r = 0.041 - 0.02 * t
            zz = BUN[2] + 0.024 - 0.05 * (1 - t) * (k * 0.3 + 0.4)
            pts.append((BUN[0] + r * math.cos(a1), BUN[1] + r * math.sin(a1), zz + 0.014 * t))
            rr.append(0.0115 - 0.004 * t)
        f.add(path(pts, rr), 0.011, HAIR, "head")
    return f


def lock(pts, r0, r1, vox=0.0013, lab=HAIR):
    pts = np.array(pts, F)
    lo, hi = pts.min(0) - 0.03, pts.max(0) + 0.03
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
    rr = [float(r0 + (r1 - r0) * (i / (n - 1)) ** 1.2) for i in range(n)]
    f = Field(lo, hi, vox)
    f.add(path([tuple(c) for c in cc], rr), 0.0, lab, "head")
    return f


LOCKS = {
    # her right: the long lock past the cheek, down to the collar
    "lockR": [(0.016, 0.070, 1.700), (0.050, 0.070, 1.668), (0.0705, 0.060, 1.622), (0.0795, 0.050, 1.570), (0.0815, 0.044, 1.515),
              (0.0775, 0.050, 1.462), (0.0680, 0.062, 1.420)],
    "lockL": [(-0.048, 0.062, 1.684), (-0.0725, 0.044, 1.630), (-0.0805, 0.034, 1.578), (-0.0800, 0.036, 1.530), (-0.0740, 0.042, 1.492)],
    # the tail falling from the bun to between the shoulder blades
    "tail": [(0.0, -0.095, 1.764), (0.002, -0.128, 1.715), (0.004, -0.137, 1.640), (0.0, -0.132, 1.560), (-0.008, -0.132, 1.480),
             (-0.012, -0.146, 1.400), (-0.005, -0.164, 1.325)],
}


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


HAIR_NEEDLES = [((-0.150, -0.070, 1.827), (0.100, -0.058, 1.722), 0.0024), ((0.150, -0.070, 1.833), (-0.095, -0.050, 1.727), 0.0024),
                ((0.122, -0.095, 1.660), (-0.040, -0.045, 1.790), 0.0020)]


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
    """Where the corset's top runs: square and modest, just over the collarbones' hollow."""
    a = np.abs(x)
    return 1.2905 + 0.0140 * smooth(0.02, 0.105, a) - 0.0085 * np.exp(-(a / 0.016) ** 2)


def lapel_x(z):
    """How far from the middle the open jacket's edge lies, by height."""
    return np.interp(z, (0.96, 1.03, 1.11, 1.21, 1.30, 1.37, 1.45), (0.062, 0.080, 0.090, 0.095, 0.078, 0.056, 0.05)).astype(F)


def strap_d(x, z, a=(-0.135, 1.335), b=(0.150, 0.955)):
    """Signed distance across the bandolier in the front view."""
    ax, az = a
    dx, dz = b[0] - ax, b[1] - az
    n = math.hypot(dx, dz)
    return ((x - ax) * dz - (z - az) * dx) / n


def dress_labels(p, lab):
    """The garment edges, exactly (the labels are per voxel: 3 mm stairs in the paint). Same order as dress()."""
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    a = np.abs(x)
    out = lab.copy()
    up = np.isin(lab, (SKIN, CORSET, CORSET_SEAM, JACKET, JACKET_DK, TROUSER, LEATHER))
    nl = neckline(x)
    low = 0.925 + 0.070 * smooth(0.0, 0.10, a)
    o2 = np.where(z > nl, SKIN, CORSET)
    o2 = np.where(z < low, TROUSER, o2)
    le = lapel_x(z)
    front = np.where(y > -0.01, le - a, -1.0)
    lo = 0.975 + 0.04 * smooth(-0.02, 0.09, y)
    jk = (front < 0) & (z > lo)
    o2 = np.where(jk, JACKET, o2)
    o2 = np.where((np.abs(front + 0.0075) < 0.0075) & (z > lo), JACKET_DK, o2)
    belt = np.abs(z - (0.965 + 0.022 * smooth(0.0, 0.1, a) * (y > 0))) < 0.0165
    o2 = np.where(belt, LEATHER, o2)
    st = (np.abs(strap_d(x, z)) < 0.0185) & (y > 0) & (z > 0.955) & (z < 1.345)
    o2 = np.where(st, LEATHER, o2)
    return np.where(up & (z > 0.8), o2, out)


def dress(b):
    """Clothes on the figure: the labels and layers, all one surface (nothing to poke through at the joints)."""
    base = b.d.copy()
    out = b
    x, y, z = b.grid()
    a = np.abs(x)
    # the skin above the neckline
    nl = neckline(x)
    b.lab = np.where(z > nl, SKIN, b.lab)
    # the corset, cut to a point below the waist in front and laced at the back
    corset_low = 0.925 + 0.070 * smooth(0.0, 0.10, a)
    reg = np.maximum(corset_low - z, z - nl)
    shell(out, type("B", (), {"d": base})(), 0.0050, lambda x, y, z: reg, CORSET)
    # its boning: seams with a slight pad between them
    for dx in (0.034, 0.078, 0.116):
        seam = (np.abs(a - dx) - 0.0028).astype(F)
        out.d = np.where(reg < -0.003, out.d + 0.0020 * smooth(0.0016, -0.0016, seam), out.d)
    # the slim trousers: a soft waist under it
    out.lab = np.where((z <= corset_low) & (b.lab == CORSET), TROUSER, out.lab)
    # the tall boots, a turned cuff at the top
    top = 0.492 + 0.026 * np.where(y > 0.0, 1.0, 0.2)
    rb = z - top
    shell(out, type("B", (), {"d": base})(), 0.0058, lambda x, y, z: rb, BOOT, 0.002)
    rc = np.maximum(z - top, top - 0.040 - z)
    shell(out, type("B", (), {"d": base})(), 0.0092, lambda x, y, z: rc, BOOT_TOP, 0.001)
    # the sole
    sole = z - 0.016
    out.lab = np.where((sole < 0) & (out.d > -0.012), LEATHER, out.lab)
    # the thigh strap, right leg
    rt = np.maximum(np.maximum(np.abs(z - 0.655) - 0.0165, 0.02 - x), x - 0.26)
    shell(out, type("B", (), {"d": base})(), 0.0082, lambda x, y, z: rt, LEATHER, 0.0008)
    # the cropped jacket: open in front, closing round the ribs, a dark inner band along the edge
    le = lapel_x(z)
    front = np.where(y > -0.01, le - a, -1.0)
    lo, hi = 0.975 + 0.04 * smooth(-0.02, 0.09, y), 1.455
    rj = np.maximum(front, np.maximum(lo - z, z - hi))
    shell(out, type("B", (), {"d": base})(), 0.0125, lambda x, y, z: rj, JACKET, 0.0012)
    edge = np.maximum(np.abs(front + 0.0075) - 0.0075, np.maximum(lo - z, z - hi))
    shell(out, type("B", (), {"d": base})(), 0.0150, lambda x, y, z: edge, JACKET_DK, 0.0012)
    # the waist belt, with a square buckle on her left hip side
    belt = np.abs(z - (0.965 + 0.022 * smooth(0.0, 0.1, a) * (y > 0))) - 0.0165
    shell(out, type("B", (), {"d": base})(), 0.0165, lambda x, y, z: belt, LEATHER, 0.0008)
    # the bandolier across her front
    st = np.maximum(np.abs(strap_d(x, z)) - 0.0185, -y + 0.0)
    st = np.maximum(st, np.maximum(0.955 - z, z - 1.345))
    shell(out, type("B", (), {"d": base})(), 0.0205, lambda x, y, z: st, LEATHER, 0.0008)
    return out


def arm(J, s, n, vox=0.0026):
    """The sleeve and forearm of one arm: the sleeve's cap at the shoulder, turned back at the elbow, a tape-measure wrap
    from there to the black cuff; ending at the wrist (the hand is its own, finer part)."""
    sx = float(J["upper_arm." + n][0])
    sz, ez, wz = float(J["upper_arm." + n][2]), float(J["forearm." + n][2]), float(J["hand." + n][2])
    a = Field((sx - 0.10, -0.1, wz - 0.05), (sx + 0.10, 0.1, sz + 0.09), vox)
    a.add(ell((sx + s * 0.002, 0.0, sz + 0.003), (0.0465, 0.052, 0.047)), 0.0, JACKET, "pauldron." + n)
    a.add(cap((sx, 0, sz + 0.005), (sx, 0, ez + 0.03), 0.0445, 0.0375), 0.02, JACKET, "upper_arm." + n)
    a.add(ell((sx - s * 0.003, 0.008, ez + 0.105), (0.040, 0.043, 0.075)), 0.02, JACKET, "upper_arm." + n)
    a.add(cap((sx, 0, ez + 0.03), (sx, 0.001, ez - 0.012), 0.0385, 0.0375), 0.012, JACKET, "forearm." + n)
    a.add(cap((sx, 0.001, ez - 0.012), (sx, 0, wz + 0.006), 0.0375, 0.0275), 0.012, TAPE, "forearm." + n)
    a.add(ell((sx, 0.003, ez - 0.055), (0.0375, 0.039, 0.07)), 0.014, TAPE, "forearm." + n)
    x, y, z = a.grid()
    # the turned-back sleeve end and the cuff
    cuff0, cuff1 = ez - 0.022, ez + 0.012
    base = type("B", (), {"d": a.d.copy()})()
    rc = np.maximum(cuff0 - z, z - cuff1)
    shell(a, base, 0.0045, lambda x, y, z: rc, JACKET_DK, 0.0016)
    wc = np.maximum(wz - 0.022 - z, z - (wz + 0.030))
    shell(a, base, 0.0042, lambda x, y, z: wc, CUFF, 0.001)
    # the tape's wraps, slanted
    t = (z + 0.18 * y - wz) * 125.0
    rt = (cuff0 > z) & (z > wz + 0.030)
    a.d = np.where(rt, a.d + 0.0007 * (np.abs(np.sin(t)) - 0.5), a.d)
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
        if k in "amr":
            # the thimble over the last joint, its hooked claw past the tip
            u = (P[3] - P[2]) / np.linalg.norm(P[3] - P[2])
            f.add(cap(P[2] + u * 0.004, P[3] + u * 0.002, r * 1.12, r * 0.98), 0.0008, STEEL, b2)
            hook = P[3] + u * 0.012 + np.array((-s * 0.0035, 0, 0), F)
            tip = P[3] + u * 0.034 + np.array((-s * 0.0115, 0, 0), F)
            f.add(path([P[3] + u * 0.001, hook, tip], [r * 0.72, r * 0.38, 0.0006]), 0.001, STEEL, b2)
        else:
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


# ---------------------------------------------------------------------------------------------- gear
# The bow's own frame: x her side, y away from the string (where the arrow flies), z the long axis, the grip at 0.
BOW_LEN = 0.56
STRING_Y = -0.150


def _bow_curve():
    z = np.array((0.0, 0.055, 0.075, 0.110, 0.165, 0.250, 0.345, 0.440, 0.505, 0.5350, 0.560), F)
    y = np.array((0.0, 0.000, 0.012, 0.028, 0.012, -0.040, -0.098, -0.142, -0.150, -0.138, -0.112), F)
    t = np.array((0.0150, 0.0150, 0.0165, 0.0255, 0.0215, 0.0175, 0.0140, 0.0115, 0.0095, 0.0060, 0.0012), F)   # half depth
    w = np.array((0.0150, 0.0150, 0.0160, 0.0185, 0.0170, 0.0145, 0.0125, 0.0105, 0.0090, 0.0060, 0.0012), F)   # half width
    return z, y, t, w


def bow_prim():
    zc, yc, tc, wc = _bow_curve()

    def fn(x, y, z):
        a = np.abs(z)
        cy = np.interp(a, zc, yc).astype(F)
        t = np.interp(a, zc, tc).astype(F)
        w = np.interp(a, zc, wc).astype(F)
        ax, ay = np.abs(x) / w, np.abs(y - cy) / t
        rho = np.maximum(np.maximum(ax, ay), (ax + ay) * 0.74)       # an octagon: the lacquer's facets
        d = (rho - 1.0) * np.minimum(w, t)
        return np.maximum(d, a - BOW_LEN)
    return Prim(fn, (-0.03, -0.2, -BOW_LEN), (0.03, 0.06, BOW_LEN))


def bow(vox=0.0017):
    f = Field((-0.075, -0.19, -0.585), (0.075, 0.06, 0.585), vox)
    f.add(bow_prim(), 0.0, BOOT, None)
    # the grip's dark wrap, the red cord under the tips
    x, y, z = f.grid()
    base = type("B", (), {"d": f.d.copy()})()
    rg = np.abs(z) - 0.056
    shell(f, base, 0.0030, lambda x, y, z: rg, LEATHER, 0.0006)
    for sg in (-1, 1):
        rc = np.abs(z - sg * 0.49) - 0.0085
        shell(f, base, 0.0022, lambda x, y, z: rc, THREAD, 0.0005)
    # the spool on the grip's side, below the fist
    c = (0.0, 0.043, -0.083)
    f.add(cyl(c, "x", 0.0062, 0.021), 0.001, LACE)
    f.add(cyl((0, c[1], c[2]), "x", 0.0145, 0.0165), 0.0, THREAD)
    for sg in (-1, 1):
        f.add(cyl((sg * 0.0185, c[1], c[2]), "x", 0.0185, 0.0035), 0.0, LACE)
    # from the spool up to the grip, a loose thread
    f.add(path([(0.012, 0.03, -0.075), (0.019, 0.02, -0.058), (0.012, 0.016, -0.046)], [0.0016, 0.0016, 0.0016]), 0.0, THREAD)
    return f


def bow_to_model(p, J):
    c, A, Sd = grip_frame(J)
    X = np.array((1.0, 0, 0), F)
    Y = -Sd
    p = np.asarray(p, F)
    return c + p[..., 0:1] * X + p[..., 1:2] * Y + p[..., 2:3] * A


QUIVER_A = np.array((0.030, -0.158, 1.060), F)     # its foot (her left of the spine), and its mouth over her right shoulder
QUIVER_B = np.array((0.168, -0.150, 1.415), F)


def quiver(vox=0.0022):
    a, b = QUIVER_A, QUIVER_B
    f = Field(np.minimum(a, b) - 0.09, np.maximum(a, b) + 0.09, vox)
    f.add(cap(a, b, 0.040, 0.047), 0.0, LEATHER, "hips")
    u = (b - a) / np.linalg.norm(b - a)
    f.sub(cap(b - u * 0.03, b + u * 0.12, 0.039, 0.040), 0.002)
    for t, lab in ((0.965, LACE), (0.03, LACE)):
        f.add(cyl(tuple(a + (b - a) * t), _align(u), 0.0495 if t > 0.5 else 0.0435, 0.0125), 0.002, lab)
    return f


def _align(u):
    """A rotation taking +Z to u."""
    u = np.array(u, F)
    z = np.array((0, 0, 1), F)
    v = np.cross(z, u)
    c = float(z @ u)
    k = np.array(((0, -v[2], v[1]), (v[2], 0, -v[0]), (-v[1], v[0], 0)), F)
    return np.eye(3, dtype=F) + k + k @ k / (1 + c)


def spikes(items, vox=0.0013):
    """Plain tapered pins: [(tail, point, r)]."""
    pts = np.array([p for a, b, r in items for p in (a, b)], F)
    f = Field(pts.min(0) - 0.012, pts.max(0) + 0.012, vox)
    for a, b, r in items:
        a, b = np.array(a, F), np.array(b, F)
        f.add(path([a, a * 0.8 + b * 0.2, b], [r, r * 0.85, 0.0006]), 0.0, NEEDLE)
    return f


def quiver_needles():
    """The needles in the quiver, eye up, fanned. The last one is the arrow's rest."""
    a, b = QUIVER_A, QUIVER_B
    u = (b - a) / np.linalg.norm(b - a)
    s = np.cross(u, (0, -1, 0))
    s = s / np.linalg.norm(s)
    out = []
    for i, (o, up, spread) in enumerate(((-0.024, 0.255, -0.05), (-0.006, 0.310, -0.012), (0.017, 0.270, 0.03), (0.030, 0.215, 0.06))):
        e = b + u * up + s * (o + spread)
        out.append((tuple(e), tuple(b - u * 0.12 + s * o * 0.7), 0.0062))
    return out


ARROW_LEN = 0.92


def arrow(vox=0.0015):
    """The nocked needle: arm-length iron, in its own frame (x, y, z), the eye at the origin (nock), the point along +y."""
    f = needle_field([((0, -0.022, 0), (0, ARROW_LEN - 0.022, 0), 0.0052)], vox, 0.0115, 0.036)
    return f


def shears(vox=0.0012):
    """Tailor's shears, hanging closed at her right hip. Frame: built at z up, handles on top."""
    f = Field((-0.055, -0.016, -0.24), (0.055, 0.016, 0.075), vox)
    for sg in (-1, 1):
        f.add(path([(sg * 0.007, 0, 0.0), (sg * 0.010, 0, -0.08), (-sg * 0.002, 0, -0.218)], [0.0090, 0.0072, 0.0007]), 0.0, STEEL)
        t = (sg * 0.026, 0, 0.042)
        ring = [(t[0] + 0.0195 * math.cos(a), 0, t[2] + 0.030 * math.sin(a)) for a in np.linspace(0, math.tau, 17)]
        f.add(path(ring, [0.0052] * 17), 0.0, STEEL)
        f.add(path([(sg * 0.012, 0, 0.018), (sg * 0.006, 0, -0.004)], [0.0048, 0.0052]), 0.002, STEEL)
    f.add(cyl((0, 0, -0.006), "y", 0.0062, 0.0115), 0.0, BUCKLE)
    return f


SHEARS_AT = np.array((0.176, 0.046, 0.782), F)


def shears_to_model(p):
    a = math.radians(9)
    p = np.asarray(p, F)
    q = np.stack((p[..., 0] * 0.0 + p[..., 1], p[..., 0], p[..., 2]), -1)       # flat to the thigh
    q = np.stack((q[..., 0] * math.cos(a) - q[..., 2] * math.sin(a), q[..., 1], q[..., 0] * math.sin(a) + q[..., 2] * math.cos(a)), -1)
    return q + SHEARS_AT


if __name__ == "__main__":
    out = sys.argv[-1]
    os.makedirs(out, exist_ok=True)
    REPO = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
    J = joints(os.path.join(REPO, "art/wardens/src/hem_rig.json"))
    which = sys.argv[1]

    def dump(nm, f, col):
        v, q = S.surface_nets(f)
        np.savez(os.path.join(out, nm + ".npz"), v=v, q=q, col=np.array(col))
    if which == "head":
        h = head()
        dump("head", h, (0.86, 0.72, 0.66))
        dump("mask", mask(h), (0.95, 0.95, 0.93))
        dump("eyes", eyes(), (0.15, 0.1, 0.1))
        dump("hair", hair(h), (0.08, 0.08, 0.1))
        for k, v in LOCKS.items():
            dump(k, lock(v, 0.0085 if k == "lockR" else (0.0065 if k == "lockL" else 0.022), 0.0012 if k != "tail" else 0.003), (0.08, 0.08, 0.1))
        dump("needles", needle_field(HAIR_NEEDLES), (0.75, 0.76, 0.8))
    else:
        b = figure(J)
        legs(b, J)
        dress(b)
        dump("trunk", b, (0.55, 0.15, 0.2))
        dump("armR", arm(J, 1, "R"), (0.55, 0.15, 0.2))
        dump("armL", arm(J, -1, "L"), (0.55, 0.15, 0.2))
        dump("handR", right_hand(J)[0], (0.86, 0.72, 0.66))
        dump("handL", left_hand(J), (0.86, 0.72, 0.66))
        q = quiver()
        dump("quiver", q, (0.3, 0.2, 0.12))
        dump("qn", needle_field(quiver_needles(), 0.0016, 0.013, 0.04), (0.75, 0.76, 0.8))
        v, qq = S.surface_nets(bow())
        np.savez(os.path.join(out, "bow.npz"), v=bow_to_model(v, J), q=qq, col=np.array((0.1, 0.1, 0.12)))
        v, qq = S.surface_nets(shears())
        np.savez(os.path.join(out, "shears.npz"), v=shears_to_model(v), q=qq[:, ::-1], col=np.array((0.7, 0.7, 0.75)))
