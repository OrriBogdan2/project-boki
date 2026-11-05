"""Tarek's forms (ART-1), field by field: every part's signed distance field, its weights on the armature and its
paint, in the Blender frame (facing +Y, his right hand at +X, soles on z = 0, metres, in the rig's own size). Pure numpy:
tools/art1/tarek_build.py turns them into the .glb.

References: docs/art/gen/wardens_r2 tarek_front, tarek_head_sheet, tarek_stone_sheet (ext/imagegen). Lean and
long-legged, a normal head, huge rock bracers with amber cracks, a grin under the bandana.
"""
import math

import numpy as np

from sdf_kit import (box, capsule, cone, ellipsoid, fbm, hexc, length, mix, noise, polyline, ramp, rot_x, rot_y, rot_z,
                     smax, smin, sphere, sstep, torus_y, vec, voronoi)


class Rig:
    """The joints the mesh is built on (from the rig JSON, in the Blender frame)."""

    def __init__(self, bones):
        h = {k: np.array((v["head"][0], -v["head"][2], v["head"][1]), np.float32) for k, v in bones.items()}
        self.h = h
        self.sh = h["upper_arm.R"]
        self.el = h["forearm.R"]
        self.wr = h["hand.R"]
        self.hip = h["thigh.R"]
        self.kn = h["shin.R"]
        self.neck = h["head"]
        self.waist = h["hips"]
        self.hc = self.neck + vec(0, 0.014, 0.142)      # the head's middle
        self.ankle = vec(self.kn[0], -0.012, 0.095)


# ------------------------------------------------------------------------------------------------- helpers
def fold_x(P):
    Q = P.copy()
    Q[..., 0] = np.abs(Q[..., 0])
    return Q


def seg_t(P, a, b):
    ab = b - a
    return ((P - a) * ab).sum(-1) / float((ab * ab).sum())


# ---------------------------------------------------------------------------------------------------------- head
def mouth_arc(n=9, grin=1.0):
    """The smile line: x across, its front on the face, the corners high."""
    xs = np.linspace(-0.062, 0.062, n)
    return xs, 0.1215 - 3.3 * xs ** 2, -0.084 + 4.4 * grin * xs ** 2


def mouth_open(x):
    return 0.0012 + 0.0008 * np.sqrt(np.clip(1.0 - (x / 0.062) ** 2, 0.0, 1.0))


def head_base(q):
    """The bare head in head space (origin the head's middle)."""
    Qf = fold_x(q)
    d = ellipsoid(q, (0, -0.012, 0.03), (0.104, 0.124, 0.122))
    d = smin(d, ellipsoid(q, (0, 0.03, -0.042), (0.099, 0.094, 0.1)), 0.03)
    d = smin(d, ellipsoid(q, (0, 0.05, -0.098), (0.08, 0.066, 0.055)), 0.03)
    d = smin(d, ellipsoid(q, (0, 0.094, -0.134), (0.036, 0.024, 0.024)), 0.02)      # chin
    d = smin(d, sphere(Qf, (0.07, 0.08, -0.032), 0.033), 0.022)                     # the cheeks, pushed up by the grin
    d = smin(d, capsule(Qf, (0.0, 0.103, 0.036), (0.065, 0.08, 0.04), 0.014), 0.015)  # brow
    d = smin(d, cone(q, (0, 0.108, 0.022), (0, 0.133, -0.024), 0.0105, 0.0145), 0.012)  # nose bridge
    d = smin(d, ellipsoid(q, (0, 0.139, -0.033), (0.02, 0.02, 0.0165)), 0.012)
    d = smin(d, ellipsoid(Qf, (0.0195, 0.124, -0.04), (0.0125, 0.013, 0.0105)), 0.008)
    d = smax(d, -sphere(Qf, (0.0105, 0.131, -0.0525), 0.0058), 0.004)               # nostrils
    d = smin(d, ellipsoid(Qf, (0.108, -0.012, -0.012), (0.012, 0.028, 0.04)), 0.008)  # ears
    # the smile: a carved lens, the lips round it, cheek folds running down from the nose
    xs, ys, zs = mouth_arc()
    r = mouth_open(xs)
    open_ = mouth_lens(q)
    upper = [(x, y + 0.0035, z + rr + 0.0055 - 0.004 * math.exp(-(x / 0.012) ** 2)) for x, y, z, rr in zip(xs, ys, zs, r)]
    lower = [(x, y + 0.0015, z - rr - 0.0075) for x, y, z, rr in zip(xs, ys, zs, r)]
    d = smin(d, polyline(q, upper, [0.0045, 0.0065, 0.0075, 0.0085, 0.0085, 0.0085, 0.0075, 0.0065, 0.0045]), 0.009)
    d = smin(d, polyline(q, lower, [0.0045, 0.0075, 0.0095, 0.0105, 0.011, 0.0105, 0.0095, 0.0075, 0.0045]), 0.009)
    d = smin(d, sphere(Qf, (0.068, 0.092, -0.044), 0.0135), 0.016)                   # the grin's corners bunching up
    d = smax(d, -open_, 0.0035)
    fold = polyline(Qf, [(0.024, 0.128, -0.042), (0.05, 0.113, -0.052), (0.074, 0.083, -0.078)], 0.0026)
    d = smax(d, -fold, 0.0095)
    d = smax(d, -capsule(q, (0, 0.126, -0.058), (0, 0.127, -0.067), 0.0024), 0.006)   # philtrum
    # neck
    n = cone(q, (0, -0.03, -0.27), (0, -0.018, -0.09), 0.08, 0.07)
    n = smin(n, capsule(Qf, (0.056, -0.028, -0.1), (0.022, 0.05, -0.215), 0.012), 0.03)
    return smin(d, n, 0.03)


def mouth_lens(q):
    """The carved opening of the mouth (< 0 inside)."""
    xs, ys, zs = mouth_arc()
    r = mouth_open(xs)
    open_ = None
    for i in range(len(xs) - 1):
        e = cone(q, (xs[i], ys[i] + 0.002, zs[i]), (xs[i + 1], ys[i + 1] + 0.002, zs[i + 1]), float(r[i]), float(r[i + 1]))
        e2 = cone(q, (xs[i], ys[i] - 0.03, zs[i]), (xs[i + 1], ys[i + 1] - 0.03, zs[i + 1]), float(r[i]), float(r[i + 1]))
        e = smin(e, e2, 0.02)
        open_ = e if open_ is None else np.minimum(open_, e)
    return open_


def lips(q):
    """Distance to the lips' lines (for the paint)."""
    xs, ys, zs = mouth_arc()
    r = mouth_open(xs)
    up = [(x, y + 0.0035, z + rr + 0.0055) for x, y, z, rr in zip(xs, ys, zs, r)]
    lo = [(x, y + 0.0015, z - rr - 0.0075) for x, y, z, rr in zip(xs, ys, zs, r)]
    return np.minimum(polyline(q, up, 0.0), polyline(q, lo, 0.0))


def teeth(q):
    xs, ys, zs = mouth_arc()
    pts = [(x, y - 0.0125, z + 0.0025) for x, y, z in zip(xs[1:-1], ys[1:-1], zs[1:-1])]
    d = polyline(q, pts, [0.0075, 0.0105, 0.0125, 0.013, 0.0125, 0.0105, 0.0075])
    return d


def scalp(q):
    """The skull the hair and the bandana sit on."""
    d = ellipsoid(q, (0, -0.012, 0.03), (0.104, 0.124, 0.122))
    d = smin(d, ellipsoid(q, (0, 0.03, -0.042), (0.09, 0.094, 0.1)), 0.03)
    d = smin(d, capsule(fold_x(q), (0.0, 0.103, 0.036), (0.065, 0.08, 0.04), 0.014), 0.015)
    d = smin(d, cone(q, (0, 0.108, 0.022), (0, 0.133, -0.024), 0.0105, 0.0145), 0.012)
    return d


def band_t(q):
    """Height from the bandana's middle line: over the eyes in front, a little higher at the knot."""
    return q[..., 2] - 0.04 + 0.006 * (q[..., 1] / 0.13)


def cap_shell(q):
    return ellipsoid(q, (0, -0.022, 0.052), (0.114, 0.146, 0.136))


def bandana(q):
    s = smin(scalp(q), cap_shell(q), 0.012)
    t = band_t(q)
    # (a soft wrap: thicker over the eyes, cloth folds crossing it)
    w = np.arctan2(q[..., 0], q[..., 1])
    folds = 0.0028 * np.sin(t * 95.0 + 3.0 * np.sin(w * 1.7) + 1.6 * noise(q, 22.0, 3)) + 0.003 * noise(q, 18.0, 5)
    sheet = np.abs(s - 0.0135) - 0.0115 + folds
    return smax(sheet, np.abs(t) - 0.058 + 0.008 * sstep(0.05, -0.12, q[..., 1]) - 0.004 * noise(q, 30.0, 7), 0.006)


def bandana_knot(q):
    d = ellipsoid(q, (0.012, -0.146, 0.052), (0.03, 0.022, 0.024))
    d = smin(d, ellipsoid(q, (-0.022, -0.148, 0.05), (0.024, 0.016, 0.018)), 0.01)
    return d + 0.002 * noise(q, 60.0, 2)


def hair_cap(q):
    """The hair over the crown: fat ropes running from the crown over the skull, swelling the head's top."""
    s = cap_shell(q)
    # (ropes: rings of a comb round the crown, wobbling)
    c = q - vec(0, -0.02, 0.17)
    az = np.arctan2(c[..., 1], c[..., 0])
    wob = 0.45 * noise(q, 9.0, 11)
    rope = np.abs(np.sin((az + wob) * 7.0))
    d = s - 0.026 * np.sqrt(rope) + 0.012
    d = d + 0.0035 * np.sin(length(c) * 110.0 + az * 3.0)
    # only above the bandana's top edge, and down the back of the head to the nape
    t = band_t(q)
    above = t - 0.056
    back = np.minimum(np.minimum(-0.035 - q[..., 1], q[..., 2] + 0.125), -0.05 - t)      # (under the band, down the nape)
    return smax(d, -np.maximum(above, back), 0.008)


# --------------------------------------------------------------------------------------------------- torso + arms
def ribs(P, R):
    z0 = R.waist[2]
    d = ellipsoid(P, (0, 0.0, z0 + 0.36), (0.205, 0.128, 0.205))
    d = smin(d, ellipsoid(P, (0, 0.0, z0 + 0.165), (0.155, 0.108, 0.15)), 0.06)
    return d


def torso(P, R):
    z0 = R.waist[2]
    Q = fold_x(P)
    d = ribs(P, R)
    # pecs, the lats, the trapezius and the collar bones
    d = smin(d, ellipsoid(Q, (0.098, 0.082, z0 + 0.405), (0.098, 0.052, 0.062), rot_y(-0.2)), 0.025)
    d = smin(d, ellipsoid(Q, (0.155, -0.02, z0 + 0.3), (0.06, 0.09, 0.15)), 0.05)
    d = smin(d, cone(Q, (0.05, -0.03, z0 + 0.635), (0.255, -0.01, z0 + 0.525), 0.05, 0.052), 0.05)
    d = smin(d, capsule(Q, (0.03, 0.082, z0 + 0.54), (0.205, 0.035, z0 + 0.555), 0.0125), 0.022)
    # the abs: two columns cut by a centre line and three rows
    d = smin(d, ellipsoid(Q, (0.052, 0.082, z0 + 0.195), (0.054, 0.05, 0.16)), 0.03)
    groove = capsule(P, (0, 0.13, z0 + 0.02), (0, 0.128, z0 + 0.45), 0.0035)
    for dz in (0.09, 0.165, 0.245):
        groove = np.minimum(groove, capsule(Q, (0.0, 0.135, z0 + dz + 0.02), (0.1, 0.11, z0 + dz), 0.0032))
    groove = np.minimum(groove, polyline(Q, [(0.0, 0.14, z0 + 0.345), (0.1, 0.143, z0 + 0.337), (0.19, 0.09, z0 + 0.375)], 0.0045))
    return smax(d, -groove, 0.018)


def arm(P, R):
    Q = fold_x(P)
    sh, el, wr = R.sh, R.el, R.wr
    d = cone(Q, sh, el, 0.066, 0.048)
    d = smin(d, ellipsoid(Q, sh + vec(0.012, 0, -0.03), (0.082, 0.086, 0.12), rot_y(0.1)), 0.03)        # deltoid
    d = smin(d, ellipsoid(Q, sh + vec(-0.004, 0.022, -0.17), (0.057, 0.058, 0.105)), 0.03)              # biceps
    d = smin(d, ellipsoid(Q, sh + vec(0.008, -0.026, -0.17), (0.054, 0.054, 0.12)), 0.03)               # triceps
    d = smin(d, cone(Q, el, wr + vec(0, 0, 0.03), 0.052, 0.038), 0.02)
    # (the arm stops inside the bracer, the wrist comes out of it: the hand part goes on from there)
    return d


def hand(P, R, curl=1.0):
    """His right hand and, mirrored, the left: hanging, palm in, a loose curl; big, as his kit is his fists."""
    Q = (fold_x(P) - R.wr) / HAND_K         # (x out, y forward, z up, the wrist at the origin)
    d = cone(Q, (0, 0, 0.06), (0, 0.0, -0.01), 0.04, 0.041)
    d = smin(d, box(Q, (-0.004, 0.002, -0.06), (0.029, 0.073, 0.056), None, 0.024), 0.018)              # palm
    d = smin(d, ellipsoid(Q, (-0.027, 0.04, -0.04), (0.02, 0.036, 0.04)), 0.012)                        # thenar pad
    d = smin(d, ellipsoid(Q, (-0.027, -0.044, -0.05), (0.018, 0.028, 0.05)), 0.012)                     # heel pad
    # the four fingers
    for y, ln, r in FINGERS:
        pts = finger_pts(y, ln)
        d = smin(d, polyline(Q, pts, [r * 1.08, r * 1.02, r * 0.94, r * 0.8]), 0.0075)
        d = smin(d, sphere(Q, pts[0] + np.array((0.008, 0, 0.002)), r * 1.05), 0.012)                    # knuckle
    d = smin(d, polyline(Q, THUMB, [0.02, 0.0185, 0.0165, 0.0135]), 0.012)
    return d * HAND_K


FINGERS = ((0.054, 0.104, 0.0205), (0.0185, 0.114, 0.0215), (-0.0185, 0.106, 0.0205), (-0.054, 0.086, 0.0185))
THUMB = np.array(((-0.008, 0.06, -0.01), (-0.016, 0.104, -0.038), (-0.03, 0.122, -0.08), (-0.04, 0.127, -0.112)), np.float32)
KNUCKLE_Z = -0.112


def finger_pts(y, ln):
    """A finger's joints, in wrist space: out of the knuckle, curling in toward the palm."""
    z = KNUCKLE_Z
    a = 0.22
    seg = (ln * 0.44, ln * 0.31, ln * 0.25)
    p = [np.array((0.0, y, z), np.float32)]
    for s in seg:
        p.append(p[-1] + np.array((-math.sin(a) * s, 0.0, -math.cos(a) * s), np.float32))
        a += 0.34
    return p


def bracer_seeds(R, sx, seed):
    """The rock slabs' centres, round his forearm from the elbow to the wrist."""
    rs = np.random.RandomState(seed)
    el = R.el * vec(sx, 1, 1)
    wr = R.wr * vec(sx, 1, 1)
    pts = []
    rows = 2
    for r in range(rows):
        t = 0.6 + 0.4 * (r + 0.5) / rows
        n = 4
        for i in range(n):
            a = 2 * math.pi * (i + 0.5 * (r % 2)) / n + rs.uniform(-0.2, 0.2)
            c = mix(el, wr, t + rs.uniform(-0.03, 0.03))
            pts.append(c + vec(math.cos(a), math.sin(a), 0) * 0.08)
    return np.array(pts, np.float32)


def bracer_axis(P, R, sx):
    el = R.el * vec(sx, 1, 1) + vec(0, 0, -0.025)
    wr = R.wr * vec(sx, 1, 1) + vec(0, 0, 0.0)
    return el, wr


def stone_seeds(R, seed=31):
    """The slabs of his stone arm: rings of them down the arm, more over the shoulder and onto the chest."""
    rs = np.random.RandomState(seed)
    sh, el, wr = R.sh, R.el, R.wr
    fist = wr + vec(0, 0, -0.11)
    path = ((sh + vec(0.03, 0, 0.1), 3, 0.1), (sh + vec(0.05, 0, -0.03), 4, 0.17), (sh + vec(0.02, 0, -0.16), 4, 0.13),
            (mix(sh, el, 0.72), 4, 0.12), (el + vec(0, 0, -0.03), 4, 0.12), (mix(el, wr, 0.38), 4, 0.13), (mix(el, wr, 0.72), 4, 0.13),
            (wr + vec(0, 0, 0.03), 4, 0.1), (fist, 4, 0.13))
    pts = []
    for ri, (c, n, r) in enumerate(path):
        for i in range(n):
            a = 2 * math.pi * (i + 0.5 * (ri % 2)) / n + rs.uniform(-0.22, 0.22)
            pts.append(c + vec(math.cos(a) * r, math.sin(a) * r, rs.uniform(-0.03, 0.03)))
    for d in ((-0.1, 0.09, -0.02), (-0.14, 0.06, -0.12), (-0.08, 0.1, -0.13), (-0.1, -0.07, -0.04)):
        pts.append(sh + vec(*d))
    return np.array(pts, np.float32)


def stone_core(P, R):
    sh, el, wr = R.sh, R.el, R.wr
    d = ellipsoid(P, sh + vec(0.03, 0.0, 0.015), (0.155, 0.155, 0.145))              # the shoulder boulder
    d = smin(d, ellipsoid(P, sh + vec(-0.085, 0.045, -0.08), (0.11, 0.085, 0.125), rot_y(-0.3)), 0.05)   # onto the chest
    d = smin(d, cone(P, sh, el, 0.112, 0.098), 0.05)
    d = smin(d, ellipsoid(P, mix(sh, el, 0.5), (0.122, 0.125, 0.15)), 0.04)
    d = smin(d, cone(P, el, wr, 0.098, 0.118), 0.03)
    d = smin(d, ellipsoid(P, mix(el, wr, 0.55), (0.118, 0.125, 0.19)), 0.04)
    return smin(d, fist(P - wr, 1.3), 0.02)


def fist(Q, k=1.0):
    """A closed fist hanging from the wrist (Q in wrist space, x out, y forward, palm side -x): four rolled fingers across
    its end, the thumb folded over them."""
    Q = Q / k
    d = ellipsoid(Q, (0.0, 0.0, -0.075), (0.056, 0.078, 0.082))
    for y in (-0.054, -0.018, 0.018, 0.054):
        d = smin(d, capsule(Q, (0.03, y, -0.14), (-0.042, y, -0.128), 0.0205), 0.006)
    d = smin(d, capsule(Q, (-0.05, 0.075, -0.075), (-0.058, 0.0, -0.118), 0.019), 0.012)
    d = smin(d, cone(Q, (0.0, 0.0, 0.02), (0.0, 0.0, -0.04), 0.042, 0.05), 0.02)
    return d * k


def fist_seeds(R):
    """Slabs over a stone fist, right side."""
    f = R.wr + vec(0, 0, -0.11)
    pts = []
    for z, n, r in ((0.08, 3, 0.09), (0.0, 4, 0.1), (-0.08, 4, 0.1), (-0.14, 2, 0.05)):
        for i in range(n):
            a = 2 * math.pi * (i + 0.4 * (n == 4)) / n
            pts.append(f + vec(math.cos(a) * r, math.sin(a) * r, z))
    return np.array(pts, np.float32)


def gauntlet_seeds(R, seed=37):
    """The right arm's slabs: tall ones up the forearm, smaller over the fist."""
    rs = np.random.RandomState(seed)
    el, wr = R.el, R.wr
    path = ((mix(el, wr, 0.42), 4, 0.09), (mix(el, wr, 0.72), 4, 0.1), (wr + vec(0, 0, 0.04), 4, 0.09))
    pts = []
    for ri, (c, n, r) in enumerate(path):
        for i in range(n):
            a = 2 * math.pi * (i + 0.5 * (ri % 2)) / n + rs.uniform(-0.2, 0.2)
            pts.append(c + vec(math.cos(a) * r, math.sin(a) * r, rs.uniform(-0.03, 0.03)))
    return np.array(pts, np.float32)


def gauntlet_core(P, R):
    """The stone gauntlet on the right forearm: much slighter than the left arm, one slab standing at the elbow side, ending
    at the wrist so the fist shows."""
    el, wr = R.el, R.wr
    d = ellipsoid(P, mix(el, wr, 0.68), (0.088, 0.094, 0.165))
    d = smin(d, cone(P, mix(el, wr, 0.2) + vec(0.045, 0.0, 0.02), mix(el, wr, 0.55), 0.016, 0.06), 0.02)
    return smax(d, wr[2] + 0.002 - P[..., 2], 0.01)


def stone_hi(P, R, seeds, heights, core_fn=None):
    """The same stone with deep narrow cracks and chipped faces: what the normal map is baked from."""
    idx, d1, gap = voronoi(P, seeds)
    return stone_arm(P, R, seeds, heights, core_fn) + 0.012 * sstep(0.012, 0.002, gap) + 0.0035 * fbm(P, 38.0, 8, 3)


def stone_arm(P, R, seeds, heights, core_fn=None):
    """Stone slabs on an arm's mass: thick and faceted, cracks between them. P in the right-side frame."""
    core = (core_fn or stone_core)(P, R)
    idx, d1, gap = voronoi(P, seeds)
    q = P - seeds[idx]
    tilt = (np.sin(idx * 2.3)[:, None] * vec(1, 0, 0) + np.cos(idx * 1.7)[:, None] * vec(0, 1, 0) +
            np.sin(idx * 3.1)[:, None] * vec(0, 0, 1))
    # (wide bevels, no groove: the cracks are painted and glow; deep thin grooves collapse into duplicate faces at this tri
    # budget, and at the match camera only the slabs' big shapes count)
    crack = sstep(0.0, 0.026, gap)
    return core - heights[idx] * crack - (q * tilt).sum(-1) * 0.2 * crack + (1.0 - crack) * 0.006


def strata(P, R):
    """His strata tattoos on the stone side of the chest, ribs and back: 1 on a dark angular band, fading to his middle."""
    x, y, z = -P[..., 0], P[..., 1], P[..., 2]       # (the stone arm is his left)
    z0 = float(R.waist[2])
    band = np.sin((z - 0.75 * x + 0.05 * noise(P, 7.0, 3)) * 30.0 + 2.0 * noise(P, 5.0, 6))
    m = sstep(-0.075, -0.01, x + 0.1 * (z - z0 - 0.3)) * sstep(z0 + 0.1, z0 + 0.2, z)
    return sstep(-0.2, 0.05, band) * m


def left_tattoos(P, R):
    """The crescent on his bare right shoulder and a band under it."""
    Q = P - vec(float(R.sh[0]) + 0.03, 0.0, float(R.sh[2]) - 0.06)
    r = np.sqrt(Q[..., 2] ** 2 + Q[..., 1] ** 2)
    moon = sstep(0.012, 0.004, np.abs(r - 0.05)) * sstep(0.03, -0.01, Q[..., 1] * 0.7 - Q[..., 2] * 0.7) * sstep(0.02, 0.05, Q[..., 0] + 0.03)
    bands = sstep(0.022, 0.012, np.abs(P[..., 2] - float(R.el[2]) - 0.1 - 0.15 * P[..., 1])) * (P[..., 0] > 0)
    return np.maximum(moon, bands)


def skirt(P, R):
    """The sash's cloth, falling over his hips and open down the front: the orange from above."""
    z0 = float(R.waist[2])
    z = P[..., 2]
    t = np.clip((z0 + 0.06 - z) / 0.42, 0.0, 1.0)
    rx, ry = 0.205 + 0.06 * t, 0.165 + 0.05 * t
    rad = (np.sqrt((P[..., 0] / rx) ** 2 + (P[..., 1] / ry) ** 2) - 1.0) * rx
    az = np.arctan2(P[..., 0], P[..., 1])
    folds = 0.009 * t * np.sin(az * 9.0 + 3.0 * noise(P, 7.0, 11))
    sheet = np.abs(rad + folds) - 0.008
    d = smax(sheet, z - (z0 + 0.075), 0.01)
    hem = z0 - 0.3 - 0.1 * sstep(0.9, 0.2, np.abs(az)) + 0.14 * sstep(1.2, 2.8, np.abs(az)) + 0.02 * noise(P, 22.0, 13)
    d = smax(d, hem - z, 0.008)
    open_ = (0.5 * t + 0.02 - np.abs(az)) * 0.2
    return smax(d, open_, 0.01)


def bracer(P, R, sx, seeds, heights):
    """Rock grown round the forearm: thick slabs, faceted and chipped, deep cracks between them."""
    el, wr = bracer_axis(P, R, sx)
    t = np.clip(seg_t(P, el, wr), -0.3, 1.3)
    bulge = np.maximum(np.sin(np.clip(t, 0, 1) * math.pi), 0.0) ** 0.8
    core = cone(P, el, wr, 0.05, 0.05) - 0.018 * bulge
    idx, d1, gap = voronoi(P, seeds)
    # (each slab its own height; its top is flat-faceted: a plane per slab tilts the facet)
    h = heights[idx]
    q = P - seeds[idx]
    tilt = (np.sin(idx * 2.3)[:, None] * vec(1, 0, 0) + np.cos(idx * 1.7)[:, None] * vec(0, 1, 0) +
            np.sin(idx * 3.1)[:, None] * vec(0, 0, 1))
    facet = (q * tilt).sum(-1) * 0.22
    crack = sstep(0.0, 0.04, gap)
    d = core - h * crack - facet * crack + (1.0 - crack) * 0.006
    d = d + 0.0028 * fbm(P, 42.0, 8, 2)
    # (it ends in chipped rims at the elbow and the wrist)
    ln = float(length(wr - el))
    d = smax(d, -(t - 0.46) * ln - 0.012 + 0.012 * noise(P, 26.0, 9), 0.008)
    return smax(d, (t - 1.0) * ln - 0.012 + 0.012 * noise(P, 26.0, 13), 0.008)


def bracer_crack(P, seeds):
    return voronoi(P, seeds)[2]


# ---------------------------------------------------------------------------------------------------------- legs
def fold_noise(P, sd=0):
    return 0.6 * noise(P, 9.0, sd) + 0.4 * noise(P, 21.0, sd + 1)


def trousers(P, R):
    Q = fold_x(P)
    kn, hip = R.kn, R.hip
    x = float(hip[0])
    d = ellipsoid(P, (0, 0.0, hip[2] - 0.035), (0.205, 0.148, 0.125))
    thigh = cone(Q, (x - 0.005, 0.0, hip[2] - 0.05), (x + 0.012, 0.012, kn[2] + 0.02), 0.128, 0.118)
    shin = cone(Q, (x + 0.012, 0.012, kn[2] + 0.02), (x + 0.012, -0.004, 0.5), 0.118, 0.112)
    bag = ellipsoid(Q, (x + 0.012, 0.004, 0.495), (0.119, 0.122, 0.105))
    d = smin(d, smin(smin(thigh, shin, 0.05), bag, 0.05), 0.03)
    # the cuff gathered on the ankle
    cuff = cone(Q, (x + 0.008, -0.004, 0.46), (x + 0.004, -0.008, 0.385), 0.08, 0.072)
    d = smin(d, cuff, 0.02)
    d = smax(d, (0.378 - P[..., 2]), 0.006)
    d = smax(d, P[..., 2] - (hip[2] + 0.035), 0.02)
    # folds: long drapes down the legs, creases raying from the knee and the crotch, gathers at the cuff
    w = np.arctan2(Q[..., 1], Q[..., 0] - x)
    z = P[..., 2]
    n = fold_noise(P, 4)
    dia = np.sin(z * 26.0 + w * 2.0 + n * 3.0)
    knee = sstep(0.16, 0.0, np.abs(z - kn[2]))
    drape = np.sin(w * 3.0 + z * 4.0 + n * 2.5)
    cuffk = sstep(0.62, 0.42, z)
    gather = np.sin(w * 11.0 + n * 2.0)
    crot = sstep(0.18, 0.02, np.abs(z - (hip[2] - 0.22))) * sstep(0.2, 0.05, np.abs(Q[..., 0] - 0.04))
    d = d + 0.0085 * dia * (0.35 + 0.65 * knee) + 0.0055 * drape * (1 - cuffk) + 0.0075 * gather * cuffk + 0.006 * dia * crot
    # the legs part at the crotch, last, so no fold bridges the gap and a wide stance never webs them
    split = 0.016 - np.abs(P[..., 0])
    return smax(d, np.minimum(split, hip[2] - 0.15 - P[..., 2]), 0.012)


def trouser_patch(P):
    """His right knee's patch (the art's left, as you face him), a raised rag: > 0 inside."""
    q = (P - vec(0.128, 0.115, 0.71)) @ rot_y(0.22)
    e = noise(P, 30.0, 12) * 0.008
    return np.minimum(0.058 + e - np.abs(q[..., 0]), 0.078 + e - np.abs(q[..., 2]))


def shin_foot(P, R):
    Q = fold_x(P)
    x = float(R.kn[0])
    d = cone(Q, (x, 0.0, R.kn[2]), (x, -0.012, 0.1), 0.06, 0.042)
    d = smin(d, ellipsoid(Q, (x, -0.022, 0.33), (0.054, 0.062, 0.12)), 0.03)                # calf
    d = smin(d, foot(Q, x), 0.03)
    return d


def foot(Q, x):
    d = ellipsoid(Q, (x, -0.05, 0.052), (0.05, 0.062, 0.052))
    d = smin(d, ellipsoid(Q, (x + 0.006, 0.075, 0.042), (0.06, 0.135, 0.042)), 0.035)
    d = smin(d, sphere(Q, (x - 0.046, -0.005, 0.078), 0.016), 0.015)                         # ankle bones
    d = smin(d, sphere(Q, (x + 0.046, -0.012, 0.074), 0.016), 0.015)
    for dx, y, r, l in ((-0.044, 0.19, 0.0185, 0.03), (-0.012, 0.2, 0.0145, 0.03), (0.012, 0.195, 0.0135, 0.026),
                        (0.034, 0.183, 0.0125, 0.022), (0.054, 0.165, 0.0115, 0.018)):
        d = smin(d, capsule(Q, (x + dx, y - l, 0.024), (x + dx, y + l * 0.6, 0.016), r), 0.009)
    d = smax(d, 0.001 - Q[..., 2], 0.012)
    return d


def wraps_mask(P, R):
    """Where the cloth wraps run on his ankles and insteps (1 cloth, 0 bare skin)."""
    Q = fold_x(P)
    z = Q[..., 2]
    y = Q[..., 1]
    a = sstep(0.09, 0.105, z) * sstep(0.24, 0.22, z)                # round the ankle
    b = sstep(0.14, 0.12, z) * sstep(-0.07, -0.03, y) * sstep(0.11, 0.09, y)      # over the instep
    return np.maximum(a, b)


def foot_wraps(P, R):
    """The cloth strip wound on the ankle, a shell on the leg, with its turns standing proud."""
    Q = fold_x(P)
    s = shin_foot(P, R)
    z = Q[..., 2]
    turns = np.sin((z - 0.5 * Q[..., 1]) * 92.0 + 2.0 * noise(P, 12.0, 9))
    sheet = s - 0.0045 - 0.0028 * turns
    y = Q[..., 1]
    m = np.maximum(sstep(0.42, 0.4, z) * sstep(0.05, 0.075, z) * sstep(0.09, 0.05, y),
                   sstep(0.14, 0.12, z) * sstep(0.16, 0.13, y) * sstep(0.012, 0.03, z))
    return smax(sheet, (0.5 - m) * 0.03, 0.004)


# ---------------------------------------------------------------------------------------------------- clothes etc.
def vest(P, R):
    z0 = R.waist[2]
    Q = fold_x(P)
    body = ellipsoid(P, (0, 0.0, z0 + 0.35), (0.236, 0.172, 0.262))
    body = smin(body, ellipsoid(P, (0, 0.0, z0 + 0.2), (0.205, 0.15, 0.19)), 0.08)
    body = smin(body, cone(Q, (0.06, -0.03, z0 + 0.625), (0.215, -0.01, z0 + 0.545), 0.058, 0.062), 0.05)
    n = 0.004 * noise(P, 16.0, 21)
    sheet = np.abs(body - 0.005 + n) - 0.0078
    z = P[..., 2]
    front = sstep(-0.02, 0.02, P[..., 1])
    # the open front: narrow at the collar, wider to the hem
    edge = 0.066 + 0.1 * np.clip((z0 + 0.6 - z) / 0.42, 0.0, 1.0) + 0.006 * noise(P, 28.0, 6)
    d = smax(sheet, (edge - np.abs(P[..., 0])) * (front * 2 - 1) - (1 - front) * 0.2, 0.004)
    # armholes, the neck, the hem (a little torn)
    hole = ellipsoid(Q, R.sh + vec(0.008, 0.0, -0.075), (0.1, 0.14, 0.17))
    d = smax(d, -hole, 0.006)
    d = smax(d, -cone(P, (0, -0.012, z0 + 0.655), (0, -0.012, z0 + 0.8), 0.088, 0.098), 0.008)
    hem = z0 + 0.158 + 0.008 * noise(P, 34.0, 8) + 0.008 * sstep(0.05, 0.1, np.abs(noise(P, 12.0, 10)))
    return smax(d, hem - z, 0.004)


def vest_trim(P, R):
    """A lighter paint band along the vest's edges: 1 on the seam line."""
    z0 = R.waist[2]
    z = P[..., 2]
    edge = 0.066 + 0.1 * np.clip((z0 + 0.6 - z) / 0.42, 0.0, 1.0)
    a = sstep(0.02, 0.0, np.abs(np.abs(P[..., 0]) - edge - 0.012)) * (P[..., 1] > 0)
    return a


def sash(P, R):
    z0 = float(R.waist[2])
    z = P[..., 2]
    w = np.arctan2(P[..., 1], P[..., 0])
    n = noise(P, 14.0, 31)
    base = ellipsoid(P, (0, 0.0, z0 + 0.09), (0.236, 0.182, 0.4))
    ridges = 0.005 * np.sin(z * 120.0 + w * 2.0 + n * 2.0)
    d = smax(base - 0.006 + ridges, np.abs(z - (z0 + 0.09)) - 0.064 - 0.006 * n, 0.012)
    # the knot, front and a little to his left
    k = vec(-0.012, 0.192, z0 + 0.075)
    knot = ellipsoid(P, k, (0.05, 0.034, 0.042), rot_y(0.35))
    knot = smin(knot, ellipsoid(P, k + vec(0.05, -0.012, 0.01), (0.04, 0.022, 0.026), rot_y(-0.5)), 0.012)
    knot = smin(knot, ellipsoid(P, k + vec(-0.05, -0.012, -0.004), (0.04, 0.022, 0.026), rot_y(0.5)), 0.012)
    knot = knot + 0.0035 * np.sin((P[..., 0] + P[..., 2]) * 120.0 + n * 3)
    return smin(d, knot, 0.012)


def wrap_band(P, R):
    """The pale cloth wound above the sash."""
    z0 = float(R.waist[2])
    z = P[..., 2]
    base = ellipsoid(P, (0, 0.0, z0 + 0.15), (0.178, 0.137, 0.3))
    n = noise(P, 18.0, 37)
    return smax(base - 0.004 + 0.002 * np.sin(z * 150 + n * 2), np.abs(z - (z0 + 0.155)) - 0.03 - 0.004 * n, 0.008)


def belt_ring(P, c, rx, ry, tilt_y, half_h, half_t):
    """A flat strap round a loop (rx, ry, tipped forward by tilt_y m per front-back)."""
    q = P - np.asarray(c, np.float32)
    z = q[..., 2] - tilt_y * q[..., 1]
    rad = (np.sqrt((q[..., 0] / rx) ** 2 + (q[..., 1] / ry) ** 2) - 1.0) * min(rx, ry)
    dx = np.abs(rad) - half_t
    dy = np.abs(z) - half_h
    return length(np.stack((np.maximum(dx, 0), np.maximum(dy, 0)), -1)) + np.minimum(np.maximum(dx, dy), 0.0) - 0.002


def harness(P, R):
    hip = R.hip
    Q = fold_x(P)
    x = float(hip[0]) + 0.012
    d = belt_ring(P, (0, 0, hip[2] - 0.075), 0.215, 0.16, 0.0, 0.018, 0.007)
    # leg loops, tipped: high at the outside of the hip, low on the inner thigh
    q = Q - vec(x, 0.0, hip[2] - 0.21)
    tip = q[..., 2] + 0.45 * (q[..., 0])
    rad = (np.sqrt((q[..., 0] / 0.139) ** 2 + (q[..., 1] / 0.142) ** 2) - 1.0) * 0.139
    dx = np.abs(rad) - 0.0075
    dy = np.abs(tip) - 0.018
    loop = length(np.stack((np.maximum(dx, 0), np.maximum(dy, 0)), -1)) + np.minimum(np.maximum(dx, dy), 0.0) - 0.002
    d = np.minimum(d, loop)
    # the straps from the belt's front to the loops, and behind
    d = np.minimum(d, polyline(Q, [(0.03, 0.158, hip[2] - 0.08), (0.055, 0.156, hip[2] - 0.19), (0.052, 0.13, hip[2] - 0.255)], 0.012))
    d = np.minimum(d, polyline(Q, [(0.09, -0.153, hip[2] - 0.08), (0.12, -0.14, hip[2] - 0.21)], 0.011))
    return d


def biner(P, c, rot, sx=0.03, sz=0.05, r=0.0065):
    """A carabiner: an oval ring."""
    q = (P - np.asarray(c, np.float32)) @ np.asarray(rot, np.float32)
    zz = q[..., 2]
    zc = np.clip(zz, -sz + sx, sz - sx)
    rad = np.sqrt(q[..., 0] ** 2 + (zz - zc) ** 2)
    return np.sqrt((rad - sx) ** 2 + q[..., 1] ** 2) - r


def piton(P, c, rot):
    """A rock piton: a wedge blade under an eye."""
    q = (P - np.asarray(c, np.float32)) @ np.asarray(rot, np.float32)
    k = np.clip((q[..., 2] + 0.05) / 0.07, 0.15, 1.0)
    bl = box(np.stack((q[..., 0] / k, q[..., 1], q[..., 2] + 0.02), -1), (0, 0, 0), (0.016, 0.0035, 0.038), None, 0.002)
    eye = np.sqrt((np.sqrt(q[..., 0] ** 2 + (q[..., 2] - 0.03) ** 2) - 0.012) ** 2 + q[..., 1] ** 2) - 0.0045
    return np.minimum(bl * 0.8, eye)


def gear_metal(P, R):
    hip = R.hip
    z = float(hip[2])
    d = biner(P, (0.178, 0.135, z - 0.15), rot_z(0.45) @ rot_y(0.12), 0.026, 0.056, 0.0072)
    d = np.minimum(d, biner(P, (-0.086, 0.158, z - 0.145), rot_z(-0.25) @ rot_y(0.1), 0.021, 0.042, 0.0058))
    d = np.minimum(d, biner(P, (-0.128, 0.148, z - 0.155), rot_z(-0.15) @ rot_y(-0.1), 0.021, 0.042, 0.0058))
    d = np.minimum(d, piton(P, (-0.086, 0.162, z - 0.255), rot_y(0.12)))
    d = np.minimum(d, piton(P, (-0.13, 0.152, z - 0.268), rot_y(-0.14)))
    d = np.minimum(d, capsule(fold_x(P), (0.03, 0.163, z - 0.08), (0.03, 0.163, z - 0.075), 0.012))
    return d


def pouch(P, R):
    z = float(R.hip[2])
    c = vec(-0.222, 0.05, z - 0.165)
    d = ellipsoid(P, c, (0.05, 0.058, 0.072))
    d = smax(d, P[..., 2] - (c[2] + 0.055), 0.006)
    d = smin(d, torus_y(P, c + vec(0, 0, 0.055), 0.042, 0.0085, 1.2), 0.004)
    d = smax(d, -ellipsoid(P, c + vec(0, 0, 0.068), (0.032, 0.036, 0.022)), 0.005)
    return d + 0.0025 * noise(P, 34.0, 41)


# --------------------------------------------------------------------------------------------------------- geode
def geode(P, r=1.0, seed=3):
    """A seeing-stone in its own space (radius r ~ 1), the eye toward +Y (tarek_head): a flat angular rock, a shallow socket
    round the eye, a plain back."""
    Pn = P / r
    rock = ellipsoid(Pn, (0, -0.1, 0), (1.0, 0.56, 1.1))
    # (facets: a few cutting planes, so the outline is a chipped polygon, not an egg)
    for i in range(9):
        a = i * 2.4 + seed
        n = vec(math.cos(a), 0.34 * math.sin(a * 2.1), math.sin(a))
        n = n / length(n)
        rock = smax(rock, (Pn * n).sum(-1) - 0.8 - 0.1 * math.sin(a * 3.0), 0.05)
    rock = rock + 0.022 * fbm(Pn, 6.0, seed + 5, 2)
    return smax(rock, -ellipsoid(Pn, (0, 0.46, 0), (0.62, 0.3, 0.72)), 0.05) * r


def geode_iris(P, r=1.0):
    Pn = P / r
    return ellipsoid(Pn, (0, 0.1, 0), (0.56, 0.2, 0.66)) * r


# ----------------------------------------------------------------------------------------------- swept tube helper
def smooth_path(pts, n):
    """Catmull-Rom through pts, n samples."""
    p = np.array(pts, np.float64)
    q = np.concatenate((2 * p[:1] - p[1:2], p, 2 * p[-1:] - p[-2:-1]))
    out = []
    segs = len(p) - 1
    for i in range(n):
        u = i / (n - 1) * segs
        k = min(int(u), segs - 1)
        t = u - k
        a, b, c, d = q[k], q[k + 1], q[k + 2], q[k + 3]
        out.append(0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (-a + 3 * b - 3 * c + d) * t ** 3))
    return np.array(out, np.float32)


def frames(path):
    """A rotation-minimising frame along a path."""
    t = np.gradient(path, axis=0)
    t /= np.maximum(length(t), 1e-9)[:, None]
    up = np.array((0.3, 0.2, 1.0), np.float32)
    n = np.cross(t[0], up)
    n /= max(float(length(n)), 1e-9)
    N = [n]
    for i in range(1, len(t)):
        n = N[-1] - t[i] * float((N[-1] * t[i]).sum())
        n /= max(float(length(n)), 1e-9)
        N.append(n)
    N = np.array(N, np.float32)
    return t, N, np.cross(t, N)


# ------------------------------------------------------------------------------------------------------ the paint
def key_shade(N, k=0.5):
    """A painted key light (up, front, from his right), wrapped."""
    L = vec(0.16, 0.46, 0.87)
    L = L / length(L)
    # (a key from above and in front, a soft fill on the flanks and the back, so no side of him goes dark as he turns)
    side = np.abs(N[..., 0]) * 0.16 + np.maximum(-N[..., 1], 0.0) * 0.3
    return np.clip((N * L).sum(-1) * 0.5 + 0.5 + side, 0.0, 1.0)


def strokes(P, scale=26.0, seed=1):
    """Soft brush-stroke value noise."""
    return 0.6 * noise(P * vec(1.0, 1.0, 0.45), scale, seed) + 0.4 * noise(P * vec(0.5, 1.0, 1.0), scale * 2.2, seed + 3)


def light_ramp(col_dark, col_mid, col_light, v):
    """Three painted values by the light v (0..1), with a soft step in each."""
    a = sstep(0.28, 0.5, v)
    b = sstep(0.62, 0.86, v)
    return mix(mix(col_dark[None, :], col_mid[None, :], a), col_light[None, :], b)


# ------------------------------------------------------------------------------------------------- swept pieces
# Locs in head space (x his right, y front, z up): chain, radius, the path.  The chain names their spring bones.
LOCS = [
    # falling in front of his shoulders, down the chest
    ("fr", 0.02, ((0.05, 0.085, 0.112), (0.105, 0.103, 0.05), (0.122, 0.112, -0.05), (0.118, 0.1, -0.18), (0.098, 0.112, -0.31), (0.104, 0.128, -0.45))),
    ("fr", 0.021, ((0.078, 0.05, 0.125), (0.132, 0.058, 0.04), (0.15, 0.058, -0.08), (0.155, 0.05, -0.22), (0.142, 0.07, -0.36), (0.15, 0.09, -0.5), (0.158, 0.1, -0.55))),
    ("fr", 0.019, ((0.092, 0.012, 0.115), (0.142, 0.022, 0.02), (0.172, 0.008, -0.09), (0.186, 0.012, -0.2), (0.18, 0.028, -0.32))),
    ("fl", 0.02, ((-0.04, 0.09, 0.115), (-0.1, 0.108, 0.055), (-0.124, 0.113, -0.04), (-0.13, 0.102, -0.17), (-0.112, 0.112, -0.28), (-0.1, 0.13, -0.4), (-0.103, 0.138, -0.47))),
    ("fl", 0.021, ((-0.075, 0.052, 0.125), (-0.134, 0.06, 0.04), (-0.155, 0.056, -0.09), (-0.156, 0.05, -0.24), (-0.14, 0.074, -0.38), (-0.145, 0.09, -0.48))),
    ("fl", 0.019, ((-0.092, 0.014, 0.115), (-0.145, 0.02, 0.02), (-0.176, 0.008, -0.1), (-0.182, 0.018, -0.21), (-0.166, 0.038, -0.3))),
    # the short ones that kick out at the sides
    ("sr", 0.019, ((0.09, -0.012, 0.12), (0.14, -0.012, 0.075), (0.185, -0.01, 0.015), (0.232, 0.005, -0.02), (0.272, 0.022, -0.02), (0.292, 0.03, 0.008))),
    ("sl", 0.019, ((-0.09, -0.012, 0.12), (-0.142, -0.02, 0.08), (-0.195, -0.022, 0.022), (-0.243, -0.008, -0.04), (-0.285, 0.0, -0.075), (-0.315, 0.012, -0.066))),
    ("sl", 0.018, ((-0.085, 0.03, 0.128), (-0.133, 0.03, 0.09), (-0.183, 0.03, 0.078), (-0.23, 0.035, 0.088), (-0.268, 0.04, 0.112))),
    # down the back
    ("br", 0.021, ((0.03, -0.07, 0.15), (0.075, -0.14, 0.08), (0.095, -0.17, -0.06), (0.1, -0.175, -0.22), (0.105, -0.18, -0.38), (0.108, -0.19, -0.54), (0.1, -0.2, -0.62))),
    ("br", 0.021, ((0.07, -0.05, 0.14), (0.115, -0.11, 0.06), (0.15, -0.135, -0.07), (0.168, -0.13, -0.22), (0.17, -0.14, -0.36), (0.165, -0.155, -0.48))),
    ("br", 0.02, ((0.09, -0.02, 0.125), (0.13, -0.05, 0.03), (0.19, -0.075, -0.09), (0.215, -0.08, -0.2), (0.225, -0.085, -0.32))),
    ("bc", 0.022, ((0.0, -0.08, 0.155), (0.015, -0.16, 0.06), (0.02, -0.19, -0.08), (0.03, -0.195, -0.25), (0.03, -0.2, -0.42), (0.022, -0.21, -0.6), (0.03, -0.22, -0.68))),
    ("bc", 0.021, ((-0.03, -0.09, 0.15), (-0.04, -0.165, 0.05), (-0.045, -0.19, -0.1), (-0.05, -0.195, -0.26), (-0.04, -0.2, -0.44), (-0.05, -0.21, -0.56))),
    ("bl", 0.021, ((-0.06, -0.06, 0.145), (-0.105, -0.13, 0.07), (-0.11, -0.17, -0.07), (-0.115, -0.175, -0.24), (-0.12, -0.18, -0.4), (-0.11, -0.195, -0.58))),
    ("bl", 0.021, ((-0.08, -0.03, 0.135), (-0.135, -0.095, 0.05), (-0.165, -0.125, -0.08), (-0.175, -0.13, -0.24), (-0.17, -0.14, -0.38), (-0.18, -0.15, -0.46))),
    ("bl", 0.02, ((-0.092, -0.01, 0.125), (-0.14, -0.05, 0.03), (-0.195, -0.08, -0.08), (-0.22, -0.085, -0.2), (-0.225, -0.095, -0.34))),
]
def _shorter(pts):
    """The master's locs end on the collar and chest: everything under the jaw line closes up."""
    return tuple((x, y, z if z > -0.1 else -0.1 + (z + 0.1) * 0.66) for x, y, z in pts)


LOCS = [(c, r * 1.5, _shorter(p)) for c, r, p in LOCS]
# (loc index, how far along it 0..1, kind): copper rings, stone beads, amber crystals, as tarek_head_sheet draws them
BEADS = [(0, 0.58, "copper"), (0, 0.72, "copper"), (0, 0.9, "copper"), (1, 0.5, "steel"), (1, 0.66, "copper"), (1, 0.8, "copper"),
         (2, 0.62, "copper"), (2, 0.82, "copper"), (3, 0.56, "copper"), (3, 0.7, "copper"), (3, 0.84, "copper"),
         (4, 0.45, "copper"), (4, 0.62, "copper"), (4, 0.82, "copper"), (5, 0.5, "steel"), (5, 0.76, "copper"),
         (6, 0.62, "copper"), (7, 0.72, "steel"), (8, 0.6, "copper"), (9, 0.3, "copper"), (9, 0.55, "copper"),
         (10, 0.4, "copper"), (10, 0.72, "copper"), (11, 0.6, "steel"), (12, 0.34, "copper"), (12, 0.6, "copper"),
         (13, 0.5, "copper"), (14, 0.42, "copper"), (14, 0.7, "copper"), (15, 0.6, "steel"), (16, 0.55, "copper"),
         (1, 0.28, "copper"), (4, 0.28, "copper")]
# The hair's spring chains (head space), one per bunch of locs: every loc rides the chain named above.
CHAINS = {
    "fr": ((0.135, 0.07, 0.06), (0.15, 0.075, -0.13), (0.14, 0.08, -0.3), (0.145, 0.1, -0.5)),
    "fl": ((-0.135, 0.07, 0.06), (-0.15, 0.075, -0.13), (-0.135, 0.08, -0.3), (-0.13, 0.11, -0.48)),
    "sr": ((0.125, -0.01, 0.09), (0.2, 0.0, 0.0), (0.3, 0.03, 0.01)),
    "sl": ((-0.125, 0.0, 0.09), (-0.205, 0.0, 0.04), (-0.31, 0.01, -0.03)),
    "br": ((0.11, -0.11, 0.07), (0.16, -0.135, -0.11), (0.16, -0.14, -0.33), (0.13, -0.17, -0.55)),
    "bc": ((0.0, -0.15, 0.08), (0.0, -0.19, -0.1), (0.0, -0.2, -0.36), (0.02, -0.22, -0.66)),
    "bl": ((-0.11, -0.11, 0.07), (-0.16, -0.135, -0.11), (-0.16, -0.14, -0.33), (-0.14, -0.18, -0.55)),
}
