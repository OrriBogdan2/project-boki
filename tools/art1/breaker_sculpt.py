"""Breaker, the Barnacle Knight (ART-1, final design): the shapes, as signed distance fields (sculpt_kit.py). A non-human
sunken-ship construct: a round hull body, stubby legs, huge banded arms and fists, a small brass diving helmet, broken
mast stumps, moss and barnacles. Every piece is rigid, on its own bone, so pieces simply overlap at the joints.
Art: briefs/art-refs/breaker_FINAL_sheet, breaker_turnaround, breaker_weapons (shape only; the drum as big as the torso,
the haft as long as the arm, chain wound round the drum, the shield taller than he is)."""
import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import sculpt_kit as S
from sculpt_kit import Field, box, cap, cyl, ell, fbm, path, smooth, sph, vnoise

F = np.float32
# labels
WOOD, IRON, RIVET, BRASS, MOSS, BARN, GLASS = 1, 2, 3, 4, 5, 6, 7
HULL_C = (0.0, 0.0, 0.53)
HULL_R = (0.41, 0.39, 0.37)      # a full round hull, 1.1 wide to tall as the master sheet
HELM_C = (0.0, 0.03, 0.88)
HELM_R = (0.235, 0.205, 0.21)      # a round dome sunk in the collar (mossy_v2_turnaround, 298 px/m at 1600 wide)
PORT_C = (0.0, 0.905)
PORT_R = 0.15                      # the big face porthole: two thirds of the dome's width
HELM_TOP = HELM_C[2] + HELM_R[2]
SIDE_PORT = (HELM_R[0] - 0.01, HELM_C[1] - 0.01, 0.91, 0.075)    # x, y, z, ring radius: the cyan grid ports each side
PORT_Y = HELM_C[1] + HELM_R[1] - 0.012          # the porthole's glass
MAST_TIP = (0.72, -0.17, 1.3)                 # where the fish's line hangs from
FISH_AT = (0.72, -0.17, 1.02)


def joints(rig_path):
    with open(rig_path) as f:
        rig = json.load(f)
    return {k: np.array([v["head"][0], -v["head"][2], v["head"][1]], F) for k, v in rig["bones"].items()}


def onsurf(fld, pts, off=0.0):
    p = fld.project(np.array(pts, F), 14)      # (a point can start well off the surface: 3 cm a step)
    return p + fld.grad(p) * off


def rivets(fld, pts, r=0.0095, lab=RIVET, bone=None):
    """Rivets go on after the game mesh is cut (Field.rv): they are paint and shading; a decimate would spend its whole
    budget on them and flatten the forms round them."""
    if not hasattr(fld, "rv"):
        fld.rv = []
    for p in pts:
        fld.rv.append((sph(tuple(p), r), lab, bone))


def barnacle(fld, c, n, r, lab=BARN):
    c, n = np.array(c, F), np.array(n, F) / np.linalg.norm(n)
    fld.add(cap(c - n * r * 0.4, c + n * r * 0.3, r, r * 0.62), r * 0.3, lab)
    fld.sub(sph(c + n * r * 0.85, r * 0.42), r * 0.1, lab)


def strake(x, y, z):
    """Hull planks: long strakes that sweep round him and bow up to the sides in front, close to staves that gather at the
    stern behind, as a ship's lines. Returns the plank coordinate (1 = one plank)."""
    r = np.sqrt(x * x + y * y) + 1e-4
    sw = 0.13 * (r / 0.38) ** 2 * smooth(0.0, 0.35, np.abs(x))
    front = (z - 0.5 - sw) / 0.062
    back = np.arctan2(x, -y) / 0.17
    k = smooth(-0.22, -0.3, y)        # 1 astern
    return front, back, k


def hull(J):
    """The hull: one wide egg, full at the shoulders; the turnaround is projected onto it, so it carries no carved detail."""
    f = Field((-0.56, -0.46, 0.06), (0.56, 0.5, 1.0), 0.0045)
    f.add(ell(HULL_C, HULL_R), 0.0, WOOD)
    f.add(ell((0, 0, 0.4), (0.42, 0.36, 0.2)), 0.08, WOOD)
    return f


def straps(hl):
    """Iron bands riveted over the hull: the chest's X and belt, the compass boss, the round back plate."""
    f = hl.like()
    f.d[:] = 1.0
    paths = []
    fr = 0.42
    # the X over the chest, from the shoulders to the flanks, through the compass
    for s in (-1, 1):
        paths.append([(s * 0.33, fr, 0.78), (s * 0.17, fr, 0.68), (0.0, fr, 0.6)])
        paths.append([(0.0, fr, 0.6), (s * 0.19, fr, 0.51), (s * 0.37, fr, 0.41)])
    paths.append([(0.0, fr, 0.6), (0.0, fr, 0.4), (0.0, fr, 0.2)])                 # down the front
    back = -0.42
    for s in (-1, 1):
        paths.append([(s * 0.34, back, 0.78), (s * 0.12, back, 0.65)])
        paths.append([(s * 0.12, back, 0.46), (s * 0.34, back, 0.3)])
    d_all = None
    hw = 0.036
    x, y, z = f.grid()
    pts_r = []
    for pa in paths:
        pp = onsurf(hl, [tuple(np.array(pa[i], F) * (1 - t) + np.array(pa[i + 1], F) * t) for i in range(len(pa) - 1)
                         for t in np.linspace(0, 1, 6)], 0.0)
        p = path(pp, [hw] * len(pp))
        d = p.fn(x, y, z)
        d_all = d if d_all is None else np.minimum(d_all, d)
        pts_r.extend(pp[3::5])
    # the belt round his middle, low
    zb = np.abs(z - (0.235 + 0.03 * ((np.abs(x) / 0.38) ** 2))) - 0.024
    d_all = np.minimum(d_all, zb)
    sh = np.abs(hl.d - 0.009) - 0.009
    f.d = np.maximum(sh, d_all).astype(F)
    f.lab[:] = IRON
    # the back plate, a big round boss
    c = onsurf(hl, [(0, -0.42, 0.56)], 0.008)[0]
    f.add(cyl(tuple(c), (math.pi / 2, 0, 0), 0.155, 0.018, 0.008), 0.004, IRON)
    f.add(sph(tuple(c + (0, 0.05, 0)), 0.09), 0.01, IRON)
    pp = [c + (0.13 * math.cos(a), -0.018, 0.13 * math.sin(a)) for a in np.linspace(0, 6.28, 10)[:-1]]
    rivets(f, pp)
    pts = onsurf(f, [tuple(p) for p in pts_r], 0.003)
    rivets(f, pts, 0.0105)
    return f


def compass_on(V, z=0.61):
    """The compass's centre and normal on the scan's chest (V: its verts): where its own painted compass sits."""
    band = lambda zz: V[(np.abs(V[:, 0]) < 0.05) & (np.abs(V[:, 2] - zz) < 0.03) & (V[:, 1] > 0), 1].max()
    y, y0, y1 = band(z), band(z - 0.06), band(z + 0.06)
    n = np.array((0.0, 1.0, -(y1 - y0) / 0.12), F)
    return np.array((0.0, y, z), F), n / np.linalg.norm(n)


def helmet():
    """The brass helmet (mossy_v2_turnaround): a round dome sunk in the collar, no neck, one big face porthole, a cyan
    grid port each side, a grille ring on the crown. Returns (dome field, collar field): the wide collar lies on the hull.
    The glowing glass (side ports, crown grille) is helm_glass()."""
    c = np.array(HELM_C, F)
    rx, ry, rz = HELM_R
    f = Field((-0.3, -0.24, 0.72), (0.3, 0.32, 1.16), 0.002)
    f.add(ell(HELM_C, HELM_R), 0.0, BRASS)
    pz = PORT_C[1]
    fy = PORT_Y
    f.add(cyl((0, fy - 0.006, pz), "y", PORT_R, 0.024, 0.008), 0.006, BRASS)
    f.sub(cyl((0, fy + 0.03, pz), "y", PORT_R * 0.74, 0.024), 0.004, BRASS)
    sx, sy, sz, sr = SIDE_PORT
    for sd in (-1, 1):
        f.add(cyl((sd * (sx + 0.003), sy, sz), "x", sr, 0.023, 0.006), 0.004, BRASS)
        f.sub(cyl((sd * (sx + 0.03), sy, sz), "x", sr * 0.72, 0.016), 0.003, GLASS)
    # the crown grille: a short brass ring, hollow (its glass glows)
    f.add(cyl((0, c[1], HELM_TOP + 0.0025), "z", 0.085, 0.0325, 0.008), 0.008, BRASS)
    f.sub(cyl((0, c[1], HELM_TOP + 0.04), "z", 0.064, 0.028), 0.003, GLASS)
    f.d = np.maximum(f.d, 0.745 - f.grid()[2])
    cl = Field((-0.56, -0.48, 0.64), (0.56, 0.48, 0.86), 0.0035)
    x, y, z = cl.grid()
    r = np.sqrt((x / 0.34) ** 2 + (y / 0.3) ** 2)
    # it lies on the hull, a dipped plate round the helmet
    hz = HULL_C[2] + HULL_R[2] * np.sqrt(np.maximum(1.0 - (x / HULL_R[0]) ** 2 - (y / HULL_R[1]) ** 2, 0.02))
    top = hz + 0.022
    d = np.maximum(np.maximum(z - top, top - 0.05 - z), r - 1.0)
    cl.d = (d * 0.7).astype(F)
    cl.lab[:] = BRASS
    return f, cl


def helm_glass():
    """The cyan glass in the side ports and the crown grille: flat discs on a glow slot (no keyed brass: bright brass
    would glow too)."""
    sx, sy, sz, sr = SIDE_PORT
    g = Field((-0.3, -0.12, 0.8), (0.3, 0.18, 1.14), 0.0016)
    for sd in (-1, 1):
        g.add(cyl((sd * (sx + 0.017), sy, sz), "x", sr * 0.72, 0.003, 0.001), 0.0, GLASS)
    g.add(cyl((0, HELM_C[1], HELM_TOP + 0.016), "z", 0.064, 0.004, 0.001), 0.0, GLASS)
    return g


def arm(J, s):
    """(pauldron, upper arm, forearm, fist) of one side: staved wood, iron bands, barnacles on the forearm."""
    sx = float(J["hand.R"][0]) * s
    S1, E, W = J["upper_arm.R"].copy(), J["forearm.R"].copy(), J["hand.R"].copy()
    z_s, z_e, z_w = float(S1[2]), float(E[2]), float(W[2])
    bx = (sx - 0.3, -0.26, 0.03), (sx + 0.3, 0.26, 0.98)
    lo = (min(bx[0][0], bx[1][0]), bx[0][1], bx[0][2])
    hi = (max(bx[0][0], bx[1][0]), bx[1][1], bx[1][2])
    V = 0.0038
    wob = lambda x, y, z: (fbm(x, y, z, 9.0, 2) - 0.5) * 0.01

    def staves(fld, cx, n=9):
        x, y, z = fld.grid()
        a = np.arctan2(y, x - cx) / math.tau * n
        seam = smooth(0.12, 0.0, np.abs((a + 0.5) % 1.0 - 0.5))
        fld.d = (fld.d + seam * 0.0035 * (fld.lab == WOOD)).astype(F)

    pd = Field(lo, hi, V)
    # the iron cap on the shoulder: a bent square slab, as the art, its edge turned down
    tilt = (0, s * 0.42, 0)
    pd.add(box((sx + s * 0.035, 0, z_s + 0.075), (0.135, 0.155, 0.03), 0.018, tilt), 0.0, IRON, None, wob)
    pd.add(box((sx + s * 0.135, 0, z_s - 0.01), (0.035, 0.15, 0.09), 0.016, (0, s * 0.12, 0)), 0.02, IRON, None, wob)
    pd.add(cyl((sx, 0, z_s + 0.015), "z", 0.118, 0.022, 0.008), 0.01, IRON)
    for a in np.linspace(-0.13, 0.13, 4):
        rivets(pd, [(sx + s * 0.172, a, z_s + 0.045), (sx + s * 0.172, a, z_s - 0.075)], 0.009)
    up = Field(lo, hi, V)
    up.add(cap((sx, 0, z_s + 0.02), (sx, 0, z_e + 0.01), 0.1, 0.105), 0.0, WOOD, None, wob)
    staves(up, sx, 8)
    fa = Field(lo, hi, V)
    fa.add(cap((sx, 0, z_e + 0.02), (sx, 0, z_w + 0.03), 0.112, 0.138), 0.0, WOOD, None, wob)
    fa.add(sph((sx, 0, z_e), 0.108), 0.01, IRON)                               # the elbow's knuckle
    staves(fa, sx, 9)
    for z, h, r in ((z_e - 0.03, 0.022, 0.13), (z_w + 0.125, 0.024, 0.15), (z_w + 0.055, 0.03, 0.158)):
        fa.add(cyl((sx, 0, z), "z", r, h, 0.008), 0.003, IRON)
        for a in np.linspace(0, 6.28, 9)[:-1]:
            rivets(fa, [(sx + r * math.cos(a), r * math.sin(a), z)], 0.0085)
    rng = np.random.default_rng(3 if s > 0 else 8)
    for i in range(16):
        a = rng.uniform(-1.4, 1.9) if s > 0 else math.pi - rng.uniform(-1.4, 1.9)
        z = rng.uniform(z_w + 0.03, z_e - 0.05)
        q = onsurf(fa, [(sx + 0.15 * math.cos(a), 0.15 * math.sin(a), z)], 0.0)[0]
        barnacle(fa, q, fa.grad(np.array([q], F))[0], float(rng.uniform(0.013, 0.026)))
    fi = Field(lo, hi, 0.003)
    # the fist: a block of a palm, four block fingers, a thumb across; the fingers on their own bones
    h = (s * 0.0)
    zw = z_w
    fi.add(box((sx, 0, zw - 0.045), (0.105, 0.135, 0.075), 0.035), 0.0, WOOD, "hand")
    fi.add(cyl((sx, 0, zw + 0.012), "z", 0.128, 0.02, 0.008), 0.003, IRON, "hand")
    fingers = []
    for i, yo in enumerate((0.1, 0.034, -0.034, -0.1)):
        k = np.array((sx + s * 0.05, yo, zw - 0.115), F)
        m1 = k + (0, 0, -0.06)
        m2 = m1 + (-s * 0.06, 0, -0.03)
        fi.add(box(tuple((k + m1) / 2), (0.046, 0.031, 0.046), 0.016), 0.002, WOOD, "x_fing")
        fi.add(box(tuple((m1 + m2) / 2), (0.05, 0.03, 0.03), 0.014), 0.002, WOOD, "x_fing2")
        fi.add(cyl((float(k[0]), yo, float(k[2]) + 0.02), "y", 0.05, 0.03, 0.006), 0.002, IRON, "hand")
    t0, t1 = (sx - s * 0.05, 0.13, zw - 0.03), (sx - s * 0.05, 0.16, zw - 0.11)
    fi.add(path((t0, t1), (0.045, 0.035)), 0.008, WOOD, "x_thumb")
    return pd, up, fa, fi


def leg(J, s):
    tx = float(J["thigh.R"][0]) * s
    kz, hz = float(J["shin.R"][2]), float(J["thigh.R"][2])
    lo, hi = (tx - 0.17, -0.2, -0.01), (tx + 0.17, 0.3, 0.33)
    th = Field(lo, hi, 0.0034)
    th.add(cap((tx, 0, hz + 0.05), (tx, 0, kz + 0.02), 0.095, 0.085), 0.0, WOOD)
    sn = Field(lo, hi, 0.0034)
    sn.add(sph((tx, 0.012, kz + 0.012), 0.075), 0.0, IRON)                       # the knee
    sn.add(cap((tx, 0, kz), (tx, 0, 0.07), 0.08, 0.082), 0.01, WOOD)
    sn.add(cyl((tx, 0, 0.09), "z", 0.09, 0.016, 0.006), 0.002, IRON)
    ft = Field(lo, hi, 0.0034)
    ft.add(box((tx, 0.06, 0.042), (0.09, 0.15, 0.042), 0.034), 0.0, WOOD)
    ft.add(cyl((tx, -0.0, 0.076), "z", 0.086, 0.014, 0.006), 0.003, IRON)
    ft.add(box((tx, 0.17, 0.05), (0.094, 0.045, 0.05), 0.03), 0.006, IRON)        # the iron toe cap
    ft.d = np.maximum(ft.d, -np.arange(ft.n[2], dtype=F)[None, None, :] * ft.vox - ft.lo[2])
    return th, sn, ft


def moss(hl, pads):
    """Moss heaped on the shoulder edges and the hull's flanks, hanging down the hull in long dripping beards; from above
    the hull stays the big shape, so the heaps sit out by the shoulders."""
    f = Field((-0.72, -0.34, 0.66), (0.72, 0.34, 0.92), 0.0042)
    lump = lambda x, y, z: (fbm(x, y, z, 13.0, 3) - 0.5) * 0.08
    fine = lambda x, y, z: (fbm(x, y, z, 26.0, 2) - 0.5) * 0.016
    for s in (-1, 1):
        f.add(ell((s * 0.44, -0.02, 0.76), (0.12, 0.2, 0.045)), 0.05, MOSS, None, lump)
        f.add(ell((s * 0.58, 0.0, 0.76), (0.09, 0.14, 0.045)), 0.05, MOSS, None, lump)
    return f


def masts():
    """Two broken mast stumps from the shoulders, a yard and sail scraps on the taller, rope lashings."""
    f = Field((-0.8, -0.42, 0.7), (0.9, 0.12, 1.42), 0.0036)
    split = lambda x, y, z: (vnoise(x * 4, y * 4, z * 0.8, 40.0) - 0.5) * 0.012
    # his right: the tall one with the fishing boom
    f.add(path(((0.33, -0.13, 0.76), (0.5, -0.17, 1.14)), (0.042, 0.03)), 0.0, WOOD, None, split)
    f.add(path(((0.5, -0.17, 1.14), (0.53, -0.17, 1.2), (0.5, -0.19, 1.22)), (0.03, 0.017, 0.004)), 0.0, WOOD, None, split)
    f.add(path(((0.24, -0.15, 1.02), (0.5, -0.17, 1.09), (0.7, -0.17, 1.14)), (0.019, 0.022, 0.012)), 0.006, WOOD, None, split)     # the yard
    f.add(path(((0.42, -0.17, 1.02), (0.55, -0.17, 1.2), (0.72, -0.17, 1.31)), (0.018, 0.016, 0.01)), 0.006, WOOD, None, split)         # the rod
    # his left: the short stump with a yard across
    f.add(path(((-0.33, -0.13, 0.76), (-0.47, -0.16, 1.07)), (0.042, 0.03)), 0.0, WOOD, None, split)
    f.add(path(((-0.47, -0.16, 1.07), (-0.485, -0.16, 1.12), (-0.46, -0.17, 1.15)), (0.03, 0.016, 0.004)), 0.0, WOOD, None, split)
    f.add(path(((-0.6, -0.15, 0.93), (-0.45, -0.16, 1.0), (-0.35, -0.17, 1.05)), (0.016, 0.02, 0.012)), 0.006, WOOD, None, split)
    # lashings
    for c in ((0.49, -0.17, 1.085), (-0.455, -0.16, 0.985), (0.5, -0.17, 1.17)):
        for k in range(3):
            f.add(cyl((c[0], c[1], c[2] + (k - 1) * 0.014), "z", 0.036, 0.008, 0.006), 0.002, RIVET)
    return f


def sails():
    """Sail scraps torn on the yards: thin, one mesh each side."""
    f = Field((-0.72, -0.2, 0.74), (0.82, -0.12, 1.12), 0.003)
    x, y, z = f.grid()
    sh = np.abs(y + 0.165 + 0.012 * np.sin(x * 22.0)) - 0.0045
    tear = (fbm(x, np.zeros_like(x), z * 0.2, 20.0, 2) - 0.5) * 0.2
    top_r = 1.02 + (x - 0.24) * 0.2
    mx = lambda a, b, c: np.maximum(np.maximum(a, b), c)
    r = mx(z - top_r, 0.84 - z + tear, np.abs(x - 0.64) - 0.08)
    r2 = mx(z - top_r, 0.88 - z + tear, np.abs(x - 0.34) - 0.05)
    top_l = 0.95 + (x + 0.6) * 0.42
    l = mx(z - top_l, 0.8 - z + tear * 0.8, np.abs(x + 0.53) - 0.055)
    f.d = np.maximum(sh, np.minimum(np.minimum(r, r2), l)).astype(F)
    f.lab[:] = 1
    return f


def fish():
    """The anglerfish: a fat teal body facing +Y (out of his side view), a wide toothy mouth, a stalk and its lure."""
    c = np.array(FISH_AT, F)
    f = Field(c + (-0.14, -0.14, -0.11), c + (0.14, 0.14, 0.14), 0.0022)
    O = lambda x, y, z: tuple(c + np.array((x, y, z), F) * 0.8)
    f.add(ell(O(0, 0, 0), (0.078, 0.105, 0.085)), 0.0, 1)
    f.add(ell(O(0, 0.06, -0.025), (0.08, 0.07, 0.06)), 0.03, 1)                 # the jaw
    f.sub(ell(O(0, 0.13, -0.022), (0.07, 0.07, 0.024)), 0.006, 2)              # the mouth
    for a in np.linspace(-1.2, 1.2, 8):
        tip = O(0.06 * math.sin(a), 0.06 + 0.05 * math.cos(a), -0.01)
        f.add(path((O(0.062 * math.sin(a), 0.062 + 0.05 * math.cos(a), 0.012), tip), (0.009, 0.001)), 0.0, 3)
        tip = O(0.06 * math.sin(a), 0.06 + 0.05 * math.cos(a), -0.034)
        f.add(path((O(0.062 * math.sin(a), 0.062 + 0.05 * math.cos(a), -0.052), tip), (0.009, 0.001)), 0.0, 3)
    for s in (-1, 1):
        f.add(sph(O(s * 0.06, 0.05, 0.04), 0.0095), 0.002, 4)                   # eyes
        f.add(path((O(s * 0.07, -0.01, -0.01), O(s * 0.125, -0.05, -0.05)), (0.022, 0.006)), 0.01, 1)     # fins
    f.add(path((O(0, -0.09, 0), O(0, -0.15, 0.04)), (0.03, 0.006)), 0.01, 1)     # tail
    f.add(path((O(0, -0.09, 0), O(0, -0.15, -0.04)), (0.03, 0.006)), 0.01, 1)
    f.add(path((O(0, 0.0, 0.08), O(0, 0.06, 0.135), O(0, 0.13, 0.12), O(0, 0.16, 0.09)), (0.009, 0.006, 0.005, 0.004)), 0.004, 1)
    return f, np.array(O(0, 0.163, 0.082), F)


def shield():
    """The hatch-door shield, in its own frame: face toward -Y, up +Z, the grip at the origin. Taller than he is: a chamfered
    door of planks in a heavy iron frame, a carved woman in low relief; a cross brace on the back."""
    H = 0.585                 # half height
    W = 0.3                   # half width
    zc = 0.28                 # the door's middle above the grip
    lo, hi = (-0.38, -0.16, -0.36), (0.38, 0.1, 0.92)
    f = Field(lo, hi, 0.0032)
    x, y, z = f.grid()
    u, v = np.abs(x), z - zc

    def outline(x_, v_):
        ax = np.abs(x_)
        # a tall octagon, the top corners cut hard, the bottom a little
        c = np.maximum(ax - W, np.abs(v_) - H)
        tp = (ax + v_ - (W + H - 0.15)) * 0.7071
        bt = (ax - v_ - (W + H - 0.09)) * 0.7071
        return np.maximum(np.maximum(c, tp), bt)
    bow = 0.02 * (x / W) ** 2
    plate = np.abs(y + 0.0 - bow) - 0.03
    f.d = np.maximum(plate, outline(x, v)).astype(F)
    f.lab[:] = WOOD
    M = f.like()
    frame = np.abs(outline(x, v) + 0.03) - 0.03
    M.d = np.maximum(frame, np.abs(y + 0.008 - bow) - 0.036).astype(F)
    M.lab[:] = IRON
    M.d = (M.d - (fbm(x, y, z, 20.0, 2) - 0.5) * 0.008).astype(F)
    for t in np.linspace(-0.5, 0.42, 9):
        for sd in (-1, 1):
            rivets(M, [(sd * (W - 0.03), -0.046, zc + t)], 0.0095)
    # the back's cross brace and grip
    M.add(box((0, 0.03, zc), (0.05, 0.012, H - 0.05), 0.006), 0.0, IRON)
    M.add(box((0, 0.03, zc + 0.2), (W - 0.04, 0.012, 0.042), 0.006), 0.0, IRON)
    M.add(box((0, 0.03, zc - 0.2), (W - 0.04, 0.012, 0.042), 0.006), 0.0, IRON)
    M.add(path(((-0.09, 0.03, 0.0), (0.0, 0.08, 0.0), (0.09, 0.03, 0.0)), (0.016, 0.016, 0.016)), 0.004, IRON)
    return f, M


def hammer():
    """The capstan hammer, upright with its grip on the origin (haft along +Z, the drum's middle at z = ZC): a waisted drum
    of iron-bound staves across the haft's end, spikes on both ends, chain wound round its waist; an iron haft as long as
    his arm. Returns (wood field, iron field, chain field, ZC)."""
    ZC = 0.54
    BL, BR, BW = 0.215, 0.205, 0.175      # half length, end radius, waist radius (a capstan)
    lo, hi = (-0.42, -0.3, -0.3), (0.42, 0.3, 0.84)
    W = Field(lo, hi, 0.0036)
    x, y, z = W.grid()
    r = np.sqrt(y * y + (z - ZC) ** 2)
    u = np.abs(x) / BL
    rad = BW + (BR - BW) * u ** 2
    W.d = np.maximum(r - rad, np.abs(x) - BL).astype(F)
    W.lab[:] = WOOD
    ang = np.arctan2(z - ZC, y) / math.tau * 16
    W.d = (W.d + smooth(0.08, 0.0, np.abs((ang + 0.5) % 1.0 - 0.5)) * 0.004).astype(F)
    M = W.like()
    for sd in (-1, 1):
        q = sd * 0.19
        M.add(cyl((q, 0, ZC), "x", BR + 0.016, 0.034, 0.008), 0.0, IRON)
        M.add(cap((sd * BL, 0, ZC), (sd * (BL + 0.08), 0, ZC), 0.06, 0.002), 0.0, IRON)
        for a in np.linspace(0, 6.28, 11)[:-1]:
            rivets(M, [(q, (BR + 0.016) * math.cos(a), ZC + (BR + 0.016) * math.sin(a))], 0.0095)
    M.add(cyl((0, 0, ZC - BW - 0.012), "z", 0.07, 0.03, 0.01), 0.0, IRON)      # the haft's socket
    M.add(cyl((0, 0, ZC - BW - 0.056), "z", 0.052, 0.022, 0.008), 0.0, IRON)
    M.add(cap((0, 0, -0.17), (0, 0, ZC - BW), 0.031, 0.031), 0.0, IRON)
    M.add(cyl((0, 0, -0.195), "z", 0.052, 0.042, 0.01), 0.0, IRON)
    Ch = Field(lo, hi, 0.0028)

    def link(c, t, n, r=0.045, thick=0.0135):
        """One chain link at c: long along t, its plane holding n."""
        c, t, n = [np.array(a, F) for a in (c, t, n)]
        t = t / np.linalg.norm(t)
        n = n / np.linalg.norm(n)
        pts = [c + t * r * 1.1 * math.cos(a) + n * r * 0.62 * math.sin(a) for a in np.linspace(0, 6.283, 9)]
        Ch.add(path(pts, [thick] * 9), 0.0, IRON)
    # wound three times round the waist
    a = 0.0
    k = 0
    while a < math.tau * 2.3:
        rr = BW + 0.016
        c = (-0.09 + a * 0.024, rr * math.cos(a), ZC + rr * math.sin(a))
        tg = (0.024, -math.sin(a), math.cos(a))
        rad_n = (0, math.cos(a), math.sin(a))
        side = (1, 0, 0)
        link(c, tg, rad_n if k % 2 else side)
        k += 1
        a += 0.092 / rr
    # and the loose end down to the wrist, a sagging curve
    pa = [(0.04, 0.16, ZC - 0.16), (0.1, 0.22, 0.2), (0.14, 0.2, -0.0), (0.12, 0.13, -0.12), (0.06, 0.05, -0.08)]
    pts = []
    for i in range(len(pa) - 1):
        for t in np.linspace(0, 1, 8, endpoint=False):
            pts.append(np.array(pa[i], F) * (1 - t) + np.array(pa[i + 1], F) * t)
    pts = np.array(pts)
    L = np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
    for j, d in enumerate(np.arange(0.03, L[-1], 0.08)):
        q = np.array([np.interp(d, L, pts[:, i]) for i in range(3)], F)
        q2 = np.array([np.interp(d + 0.01, L, pts[:, i]) for i in range(3)], F)
        t = q2 - q
        n = np.cross(t, (1, 0.2, 0.3)) if j % 2 else np.cross(np.cross(t, (1, 0.2, 0.3)), t)
        link(q, t, n)
    return W, M, Ch, ZC


def wrist_chain(J):
    """The shackle and chain wound round his right wrist (the forearm's, it stays when the hammer flies)."""
    sx = float(J["hand.R"][0])
    z0 = float(J["hand.R"][2]) + 0.085
    f = Field((sx - 0.2, -0.2, z0 - 0.1), (sx + 0.2, 0.2, z0 + 0.1), 0.0028)
    a = 0.0
    k = 0
    r = 0.152
    while a < math.tau * 1.9:
        c = np.array((sx + r * math.cos(a), r * math.sin(a), z0 - 0.03 + a * 0.008), F)
        t = np.array((-math.sin(a), math.cos(a), 0.05), F)
        n = np.array((math.cos(a), math.sin(a), 0), F) if k % 2 else np.array((0, 0, 1), F)
        pts = [c + t * 0.04 * math.cos(b) + n * 0.024 * math.sin(b) for b in np.linspace(0, 6.283, 9)]
        f.add(path(pts, [0.0115] * 9), 0.0, IRON)
        k += 1
        a += 0.082 / r
    return f
