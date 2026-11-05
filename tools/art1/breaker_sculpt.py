"""Breaker, the Sunken Bulwark (ART-1, final design): the shapes, as signed distance fields (sculpt_kit.py). A non-human
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
HULL_C = (0.0, 0.0, 0.5)
HULL_R = (0.385, 0.365, 0.345)
HELM_C = (0.0, 0.13, 0.905)
HELM_R = 0.122
PORT_Y = HELM_C[1] + HELM_R - 0.012          # the porthole's glass
MAST_TIP = (0.64, -0.17, 1.3)                 # where the fish's line hangs from
FISH_AT = (0.64, -0.17, 1.02)


def joints(rig_path):
    with open(rig_path) as f:
        rig = json.load(f)
    return {k: np.array([v["head"][0], -v["head"][2], v["head"][1]], F) for k, v in rig["bones"].items()}


def onsurf(fld, pts, off=0.0):
    p = fld.project(np.array(pts, F), 4)
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


def hull(J):
    """The hull: a big round barrel of planks, a little squashed; plank seams carved shallow."""
    f = Field((-0.5, -0.46, 0.08), (0.5, 0.5, 1.0), 0.0045)
    wob = lambda x, y, z: (fbm(x, y, z, 6.0, 2) - 0.5) * 0.014
    f.add(ell(HULL_C, HULL_R), 0.0, WOOD, None, wob)
    f.add(ell((0, 0.0, 0.2), (0.2, 0.17, 0.09)), 0.1, WOOD)             # the belly's keel into the hips
    x, y, z = f.grid()
    r = np.sqrt(x * x + (y) ** 2) + 1e-4
    # horizontal planks bowed round him, in the art's fan: seams carved 4 mm deep
    v = (z - 0.5 - 0.12 * (r / 0.38) ** 2 * smooth(0.0, 0.35, np.abs(x))) / 0.058
    seam = smooth(0.1, 0.0, np.abs(((v + 0.5) % 1.0) - 0.5))
    f.d = (f.d + seam * 0.004).astype(F)
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
    hw = 0.033
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
    zb = np.abs(z - (0.25 + 0.03 * ((np.abs(x) / 0.38) ** 2))) - 0.024
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


def compass_field(hl):
    c = onsurf(hl, [(0, 0.42, 0.6)], 0.02)[0]
    n = hl.grad(np.array([c], F))[0]
    f = Field(c - 0.12, c + 0.12, 0.0016)
    f.add(cap(c - n * 0.02, c + n * 0.016, 0.092, 0.09), 0.003, IRON)
    f.sub(cap(c + n * 0.022, c + n * 0.05, 0.072, 0.072), 0.003, BRASS)
    for a in np.linspace(0, 6.28, 9)[:-1]:
        u = np.array((math.cos(a), 0, math.sin(a)), F)
        f.add(sph(tuple(c + u * 0.082 + n * 0.017), 0.006), 0.001, RIVET)
    return f, c, n


def helmet():
    """The small brass diving helmet: a dome, a thick collar of iron and rivets, the front porthole, side ports."""
    f = Field((-0.2, -0.1, 0.74), (0.2, 0.32, 1.07), 0.002)
    c = np.array(HELM_C, F)
    f.add(sph(HELM_C, HELM_R), 0.0, BRASS)
    f.add(ell((0, c[1], c[2] - 0.075), (0.112, 0.112, 0.06)), 0.02, BRASS)
    f.add(ell((0, c[1] - 0.005, 0.81), (0.17, 0.165, 0.032)), 0.012, IRON)                 # the collar
    f.add(ell((0, c[1], c[2] + 0.1), (0.05, 0.05, 0.03)), 0.015, BRASS)
    # the band over the dome
    f.add(box((0, c[1], c[2] + 0.02), (0.014, 0.125, 0.11), 0.01), 0.004, BRASS)
    f.d = np.maximum(f.d, -(f.grid()[2] - 0.775))
    # the front porthole: a thick ring, the glass sunk in it
    fy = PORT_Y
    f.add(cap((0, fy - 0.03, c[2]), (0, fy + 0.018, c[2]), 0.088, 0.083), 0.006, BRASS)
    f.sub(cap((0, fy + 0.002, c[2]), (0, fy + 0.05, c[2]), 0.067, 0.067), 0.004, BRASS)
    for a in np.linspace(0, 6.28, 11)[:-1]:
        rivets(f, [(0.078 * math.cos(a), fy + 0.016, c[2] + 0.078 * math.sin(a))], 0.006)
    for s in (-1, 1):
        q = c + np.array((s * 0.105, 0.03, 0.0), F)
        f.add(cap(q - (s * 0.02, 0, 0), q + (s * 0.024, 0, 0), 0.043, 0.04), 0.004, BRASS)
        f.sub(sph(tuple(q + (s * 0.04, 0, 0)), 0.03), 0.004, GLASS)
    for a in np.linspace(0, 6.28, 17)[:-1]:
        rivets(f, [(0.158 * math.cos(a), c[1] + 0.153 * math.sin(a), 0.828)], 0.0065)
    return f


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
    # the iron cap on the shoulder: a heavy bent plate
    pd.add(ell((sx + s * 0.03, 0, z_s + 0.075), (0.15, 0.155, 0.125)), 0.0, IRON, None, wob)
    pd.sub(ell((sx - s * 0.13, 0, z_s), (0.13, 0.2, 0.16)), 0.02)
    pd.add(ell((sx + s * 0.09, 0, z_s + 0.015), (0.09, 0.15, 0.07)), 0.02, IRON)
    for a in np.linspace(-1.1, 1.1, 7):
        rivets(pd, [(sx + s * (0.1 + 0.075 * math.cos(a)), 0.135 * math.sin(a), z_s + 0.1 - 0.05 * abs(a))], 0.009)
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
    """Moss, heaped on the shoulders and the collar, dribbling down the chest and back in strands."""
    f = Field((-0.62, -0.46, 0.2), (0.62, 0.48, 1.02), 0.0042)
    lump = lambda x, y, z: (fbm(x, y, z, 13.0, 3) - 0.5) * 0.09
    for s in (-1, 1):
        f.add(ell((s * 0.27, -0.03, 0.8), (0.19, 0.22, 0.065)), 0.05, MOSS, None, lump)
        f.add(ell((s * 0.45, -0.02, 0.83), (0.135, 0.15, 0.06)), 0.05, MOSS, None, lump)
    rng = np.random.default_rng(21)
    for i in range(16):
        s = 1 if i % 2 else -1
        x0 = s * float(rng.uniform(0.17, 0.36))
        fr = rng.random() > 0.3
        z0 = float(rng.uniform(0.7, 0.79))
        l = float(rng.uniform(0.18, 0.44))
        pts = []
        for t in np.linspace(0, 1, 8):
            pts.append((x0 + 0.018 * math.sin(t * 9 + i) * t, 0.5 if fr else -0.5, z0 - l * t))
        pp = onsurf(hl, pts, 0.03)
        f.add(path(pp, [0.034 * (1 - 0.72 * t) for t in np.linspace(0, 1, 8)]), 0.012, MOSS, None, lambda x, y, z: (fbm(x, y, z, 26.0, 2) - 0.5) * 0.012)
    # the skirt of hanging weed round the waist
    for i in range(9):
        a = i / 9 * math.tau + 0.3
        x0, y0 = math.sin(a) * 0.3, math.cos(a) * 0.3
        l = float(rng.uniform(0.08, 0.17))
        pp = onsurf(hl, [(x0 * 1.3, y0 * 1.3, 0.3 - l * t) for t in np.linspace(0, 1, 6)], 0.004)
        f.add(path(pp, [0.02 * (1 - 0.8 * t) for t in np.linspace(0, 1, 6)]), 0.01, MOSS)
    return f


def masts():
    """Two broken mast stumps from the shoulders, a yard and sail scraps on the taller, rope lashings."""
    f = Field((-0.75, -0.42, 0.72), (0.8, 0.12, 1.42), 0.0036)
    split = lambda x, y, z: (vnoise(x * 4, y * 4, z * 0.8, 40.0) - 0.5) * 0.012
    # his right: the tall one with the fishing boom
    f.add(path(((0.3, -0.13, 0.78), (0.43, -0.17, 1.14)), (0.042, 0.03)), 0.0, WOOD, None, split)
    f.add(path(((0.43, -0.17, 1.14), (0.46, -0.17, 1.2), (0.43, -0.19, 1.22)), (0.03, 0.017, 0.004)), 0.0, WOOD, None, split)
    f.add(path(((0.14, -0.15, 1.03), (0.42, -0.17, 1.09), (0.62, -0.17, 1.14)), (0.019, 0.022, 0.012)), 0.006, WOOD, None, split)     # the yard
    f.add(path(((0.33, -0.17, 1.02), (0.46, -0.17, 1.2), (0.64, -0.17, 1.31)), (0.018, 0.016, 0.01)), 0.006, WOOD, None, split)         # the rod
    # his left: the short stump with a yard across
    f.add(path(((-0.3, -0.13, 0.78), (-0.4, -0.16, 1.07)), (0.042, 0.03)), 0.0, WOOD, None, split)
    f.add(path(((-0.4, -0.16, 1.07), (-0.415, -0.16, 1.12), (-0.39, -0.17, 1.15)), (0.03, 0.016, 0.004)), 0.0, WOOD, None, split)
    f.add(path(((-0.54, -0.15, 0.93), (-0.38, -0.16, 1.0), (-0.28, -0.17, 1.05)), (0.016, 0.02, 0.012)), 0.006, WOOD, None, split)
    # lashings
    for c in ((0.41, -0.17, 1.085), (-0.385, -0.16, 0.985), (0.4, -0.17, 1.17)):
        for k in range(3):
            f.add(cyl((c[0], c[1], c[2] + (k - 1) * 0.014), "z", 0.036, 0.008, 0.006), 0.002, RIVET)
    return f


def sails():
    """Sail scraps torn on the yards: thin, one mesh each side."""
    f = Field((-0.66, -0.2, 0.74), (0.74, -0.12, 1.12), 0.003)
    x, y, z = f.grid()
    sh = np.abs(y + 0.165 + 0.012 * np.sin(x * 22.0)) - 0.0045
    tear = (fbm(x, np.zeros_like(x), z * 0.2, 20.0, 2) - 0.5) * 0.2
    top_r = 1.03 + (x - 0.14) * 0.2
    mx = lambda a, b, c: np.maximum(np.maximum(a, b), c)
    r = mx(z - top_r, 0.84 - z + tear, np.abs(x - 0.56) - 0.08)
    r2 = mx(z - top_r, 0.88 - z + tear, np.abs(x - 0.26) - 0.05)
    top_l = 0.95 + (x + 0.54) * 0.42
    l = mx(z - top_l, 0.8 - z + tear * 0.8, np.abs(x + 0.47) - 0.055)
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
    W = 0.31                  # half width
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
    plate = np.abs(y + 0.0 - bow) - 0.02
    f.d = np.maximum(plate, outline(x, v)).astype(F)
    f.lab[:] = WOOD
    R = lambda p, k=0.014: f.add(p, k, 4)
    # the woman: head, long hair, torso, a gown tapering down the door
    Z = lambda a: zc + a
    R(ell((0, -0.026, Z(0.335)), (0.056, 0.03, 0.074)), 0.02)
    R(ell((0, -0.016, Z(0.31)), (0.085, 0.022, 0.11)), 0.02)
    R(path(((0, -0.026, Z(0.26)), (0, -0.03, Z(0.16))), (0.03, 0.05)), 0.03)
    R(ell((-0.044, -0.042, Z(0.13)), (0.036, 0.028, 0.038)), 0.02)
    R(ell((0.044, -0.042, Z(0.13)), (0.036, 0.028, 0.038)), 0.02)
    R(path(((0, -0.034, Z(0.1)), (0, -0.028, Z(-0.03)), (0.0, -0.024, Z(-0.2)), (0, -0.016, Z(-0.46))), (0.07, 0.055, 0.06, 0.01)), 0.03)
    for s in (-1, 1):
        R(path(((s * 0.07, -0.016, Z(0.22)), (s * 0.13, -0.014, Z(0.1)), (s * 0.08, -0.016, Z(-0.08))), (0.03, 0.022, 0.008)), 0.02)
        R(path(((s * 0.08, -0.016, Z(0.02)), (s * 0.2, -0.012, Z(0.08)), (s * 0.24, -0.012, Z(0.2))), (0.02, 0.02, 0.006)), 0.02)
        f.sub(ell((s * 0.021, -0.062, Z(0.34)), (0.011, 0.007, 0.0055)), 0.005, 4)
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
    ZC = 0.5
    BL, BR, BW = 0.215, 0.178, 0.148      # half length, end radius, waist radius (a capstan)
    lo, hi = (-0.42, -0.27, -0.3), (0.42, 0.27, 0.78)
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
        q = sd * 0.188
        M.add(cyl((q, 0, ZC), "x", BR + 0.016, 0.034, 0.008), 0.0, IRON)
        M.add(cap((sd * BL, 0, ZC), (sd * (BL + 0.105), 0, ZC), 0.058, 0.002), 0.0, IRON)
        for a in np.linspace(0, 6.28, 11)[:-1]:
            rivets(M, [(q, (BR + 0.016) * math.cos(a), ZC + (BR + 0.016) * math.sin(a))], 0.0095)
    M.add(cyl((0, 0, ZC - BW - 0.012), "z", 0.07, 0.03, 0.01), 0.0, IRON)      # the haft's socket
    M.add(cyl((0, 0, ZC - BW - 0.056), "z", 0.052, 0.022, 0.008), 0.0, IRON)
    M.add(cap((0, 0, -0.17), (0, 0, ZC - BW), 0.031, 0.031), 0.0, IRON)
    M.add(cyl((0, 0, -0.195), "z", 0.052, 0.042, 0.01), 0.0, IRON)
    Ch = Field(lo, hi, 0.0028)

    def link(c, t, n, r=0.04, thick=0.0115):
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
        rr = BW + 0.014
        c = (-0.06 + a * 0.02, rr * math.cos(a), ZC + rr * math.sin(a))
        tg = (0.02, -math.sin(a), math.cos(a))
        rad_n = (0, math.cos(a), math.sin(a))
        side = (1, 0, 0)
        link(c, tg, rad_n if k % 2 else side)
        k += 1
        a += 0.082 / rr
    # and the loose end down to the wrist, a sagging curve
    pa = [(0.04, 0.14, ZC - 0.13), (0.1, 0.2, 0.2), (0.14, 0.2, -0.0), (0.12, 0.13, -0.12), (0.06, 0.05, -0.08)]
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
