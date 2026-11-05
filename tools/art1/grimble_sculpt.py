"""Grimble, the Scrap King (ART-1; id and files stay `dredge`): the shapes, as signed distance fields on the rig's own joints.
Refs: briefs/art-refs/grimble_FINAL_sheet (master), grimble_turnaround, grimble_weapons. One eye behind the monocle, always.
Space: Blender's, he faces +Y, his right +X, up +Z, metres at the class-neutral size. The hoard is big simple shapes: it is a
silhouette from the match camera first, and it has to fit the 20k budget with him."""
import json
import math

import numpy as np

import hem_sdf as S
from hem_sdf import Field, Prim, box, cap, cyl, ell, fbm, path, smooth, sph

F = np.float32

# labels (below 100: materials; 100 and up: one hoard item each, HOARD)
SKIN, LIP, MOUTH, TOOTH, IRON, RUST, BRASS, LEATHER, LOIN, WOOD, BURLAP, GOLD, GLASS, EYE, LAMP, ROPE, DARK = range(1, 18)
HOARD_BASE = 100
HOARD = []          # {id, kind, c, R}: the painter reads an item's own frame from here

HEAD_C = np.array((0.0, 0.268, 1.174), F)      # the head's middle; it hangs ahead of the neck joint, the art's hunch
EYE_C = np.array((0.040, 0.345, 1.200), F)     # the eye (one, on his right), the monocle round it
EYE_R = 0.037
ANKLE = 0.075


def joints(rig_path):
    with open(rig_path) as f:
        rig = json.load(f)
    return {k: np.array([v["head"][0], -v["head"][2], v["head"][1]], F) for k, v in rig["bones"].items()}


def rot(yaw=0.0, pitch=0.0, roll=0.0):
    """Item frame -> model: yaw about Z, pitch about X, roll about Y (radians)."""
    cz, sz, cx, sx, cy, sy = math.cos(yaw), math.sin(yaw), math.cos(pitch), math.sin(pitch), math.cos(roll), math.sin(roll)
    Rz = np.array(((cz, -sz, 0), (sz, cz, 0), (0, 0, 1)), F)
    Rx = np.array(((1, 0, 0), (0, cx, -sx), (0, sx, cx)), F)
    Ry = np.array(((cy, 0, sy), (0, 1, 0), (-sy, 0, cy)), F)
    return Rz @ Rx @ Ry


def custom(fn, lo, hi):
    return Prim(fn, lo, hi)


def fixed(c, R, fn, e):
    """A prim written in an item's frame: fn(u, v, w) -> distance. e: its bounding radius."""
    c = np.array(c, F)

    def world(x, y, z):
        px, py, pz = x - c[0], y - c[1], z - c[2]
        return fn(R[0, 0] * px + R[1, 0] * py + R[2, 0] * pz, R[0, 1] * px + R[1, 1] * py + R[2, 1] * pz,
                  R[0, 2] * px + R[1, 2] * py + R[2, 2] * pz)
    return Prim(world, c - e, c + e)


def L(c, R, p):
    """An item's local point -> model."""
    return tuple(np.array(c, F) + R @ np.array(p, F))


# ------------------------------------------------------------------ the figure: trunk, arms and legs, one skin
def _arm(J, s, n, vox):
    sx, sz, ez, wz = float(J["upper_arm." + n][0]), float(J["upper_arm." + n][2]), float(J["forearm." + n][2]), float(J["hand." + n][2])
    a = Field((sx - 0.15, -0.16, wz - 0.06), (sx + 0.15, 0.16, sz + 0.14), vox)
    up, fo = "upper_arm." + n, "forearm." + n
    a.add(ell((sx - s * 0.004, -0.004, sz + 0.012), (0.086, 0.092, 0.088)), 0.0, SKIN, up)                  # deltoid
    a.add(ell((sx + s * 0.018, 0.0, sz - 0.056), (0.044, 0.054, 0.062)), 0.03, SKIN, up)
    a.add(cap((sx, 0, sz), (sx, 0, ez + 0.02), 0.046, 0.040), 0.02, SKIN, up)
    a.add(ell((sx - s * 0.002, 0.024, ez + 0.104), (0.047, 0.047, 0.082)), 0.014, SKIN, up)                 # biceps
    a.add(ell((sx + s * 0.004, -0.028, ez + 0.092), (0.047, 0.045, 0.092)), 0.012, SKIN, up)                # triceps
    a.add(sph((sx, -0.006, ez), 0.041), 0.02, SKIN, fo)
    a.add(ell((sx + s * 0.006, 0.010, ez - 0.075), (0.054, 0.052, 0.082)), 0.018, SKIN, fo)                 # the forearm's belly
    a.add(cap((sx, 0, ez - 0.02), (sx, 0, wz + 0.02), 0.042, 0.036), 0.016, SKIN, fo)
    return a


def _leg(J, s, n, vox):
    hx, hz, kz = float(J["thigh." + n][0]), float(J["thigh." + n][2]), float(J["shin." + n][2])
    a = Field((hx - 0.15, -0.14, -0.01), (hx + 0.15, 0.27, hz + 0.12), vox)
    th, sh, ft = "thigh." + n, "shin." + n, "foot." + n
    a.add(cap((hx - s * 0.02, 0.0, hz + 0.03), (hx, 0.004, kz + 0.03), 0.090, 0.056), 0.0, SKIN, th)
    a.add(ell((hx + s * 0.022, 0.024, kz + 0.17), (0.060, 0.064, 0.125)), 0.018, SKIN, th)                  # quad
    a.add(ell((hx - s * 0.002, -0.036, kz + 0.15), (0.062, 0.056, 0.120)), 0.014, SKIN, th)                 # hamstring
    a.add(sph((hx, 0.022, kz + 0.004), 0.050), 0.018, SKIN, sh)                                             # knee
    a.add(cap((hx, 0.004, kz), (hx, 0.0, ANKLE + 0.02), 0.047, 0.031), 0.018, SKIN, sh)
    a.add(ell((hx + s * 0.006, -0.030, kz - 0.095), (0.054, 0.057, 0.098)), 0.016, SKIN, sh)                # calf
    a.add(sph((hx, -0.030, 0.045), 0.036), 0.016, SKIN, ft)                                                 # heel
    a.add(ell((hx, 0.042, 0.042), (0.040, 0.095, 0.036)), 0.018, SKIN, ft)
    a.add(ell((hx - s * 0.006, 0.112, 0.030), (0.054, 0.052, 0.024)), 0.014, SKIN, ft)
    for i, (dx, ln, r) in enumerate(((-0.040, 0.066, 0.018), (-0.014, 0.058, 0.0145), (0.008, 0.050, 0.0135), (0.028, 0.042, 0.0125), (0.046, 0.034, 0.0115))):
        x = hx + s * dx
        a.add(cap((x, 0.135, 0.024), (x + s * dx * 0.2, 0.135 + ln, 0.016), r, r * 0.94), 0.004, SKIN, ft)
    return a


def figure(J, vox=0.0042):
    """Skinny and ropey: a narrow waist, a sunken belly, a big hunched yoke of shoulder and trapezius. It stands upright on
    the rig; the hunch is the head hung forward, the hump, and the pose."""
    t = Field((-0.47, -0.32, -0.01), (0.47, 0.34, 1.34), vox)
    # pelvis and belly
    t.add(ell((0, 0.0, 0.71), (0.150, 0.108, 0.085)), 0.0, SKIN, "root")
    t.add(cap((0, 0.0, 0.73), (0, -0.012, 0.86), 0.104, 0.112), 0.03, SKIN, "root")
    # the ribcage and the hump
    t.add(ell((0, -0.016, 0.985), (0.160, 0.112, 0.155)), 0.04, SKIN, "hips")
    t.add(ell((0, -0.085, 1.075), (0.170, 0.128, 0.135)), 0.05, SKIN, "hips")
    t.add(ell((0, -0.050, 1.170), (0.245, 0.118, 0.066)), 0.05, SKIN, "hips")               # the yoke, shoulder to shoulder
    for s in (1, -1):
        t.add(ell((s * 0.082, 0.082, 1.058), (0.083, 0.044, 0.056), (0.18, s * 0.26, 0)), 0.016, SKIN, "hips")     # pecs
        t.add(ell((s * 0.140, -0.040, 0.935), (0.046, 0.082, 0.105)), 0.03, SKIN, "hips")        # lats
        t.add(cap((s * 0.055, 0.02, 1.215), (s * 0.25, -0.02, 1.145), 0.042, 0.032), 0.03, SKIN, "hips")     # traps
    # the abs: three pairs, sunken
    for i, z in enumerate((0.905, 0.850, 0.797)):
        for s in (1, -1):
            t.add(ell((s * 0.038, 0.098 - i * 0.002, z), (0.036, 0.018, 0.024)), 0.009, SKIN, "root" if i == 2 else "hips")
    for i in range(3):
        for s in (1, -1):
            t.add(cap((s * (0.145 - i * 0.012), 0.070, 0.975 - i * 0.042), (s * (0.112 - i * 0.012), 0.094, 0.960 - i * 0.042), 0.010), 0.012, SKIN, "hips")     # ribs
    t.grp = 0
    arms = {}
    for i, (s, n) in enumerate(((1, "R"), (-1, "L"))):
        a = _arm(J, s, n, vox)
        full = t.like()
        full.grp = 1 + i
        _copy(full, a)
        ax = float(J["upper_arm." + n][0])
        arms[n] = full
        t.merge(full, kfn=lambda x, y, z: 0.05 * smooth(0.97, 1.08, z))
    for i, (s, n) in enumerate(((1, "R"), (-1, "L"))):
        a = _leg(J, s, n, vox)
        full = t.like()
        full.grp = 3 + i
        _copy(full, a)
        t.merge(full, kfn=lambda x, y, z: 0.06 * smooth(0.60, 0.70, z))
    return t


def _copy(dst, src):
    """A small field onto a large grid of the same voxel size (snapped to the voxels)."""
    off = np.rint((src.lo - dst.lo) / dst.vox).astype(int)
    a = np.maximum(off, 0)
    b = np.minimum(off + src.n, dst.n)
    s0 = tuple(slice(int(a[i]), int(b[i])) for i in range(3))
    s1 = tuple(slice(int(a[i] - off[i]), int(b[i] - off[i])) for i in range(3))
    dst.d[s0] = src.d[s1]
    dst.lab[s0] = src.lab[s1]
    dst.prims += [(p, bn, dst.grp) for p, bn, _ in src.prims]


# ------------------------------------------------------------------ the head: the grin is the character
MOUTH_W = 0.089


def grin_z(x):
    """The mouth's centre line, head space: a wide upturned curve, crooked (his left corner higher)."""
    return -0.046 + 2.1 * x * x - 0.10 * x


def grin_h(x):
    return 0.0395 * np.clip(1 - (x / MOUTH_W) ** 2, 0, 1) ** 0.62


def face_y(x, z):
    """The muzzle's front, head space (used to sit the teeth just behind the lips)."""
    return 0.062 + 0.066 * np.sqrt(np.clip(1 - (x / 0.098) ** 2 - ((z + 0.04) / 0.11) ** 2, 0.0, 1))


def head(vox=0.0017):
    c = HEAD_C
    h = Field((-0.135, 0.0, 0.99), (0.135, 0.365, 1.315), vox)

    def P(x, y, z):
        return (float(x), float(c[1] + y), float(c[2] + z))
    h.add(ell(P(0, -0.012, 0.030), (0.094, 0.108, 0.086)), 0.0, SKIN)
    h.add(ell(P(0, 0.052, -0.030), (0.092, 0.078, 0.062)), 0.03, SKIN)
    h.add(ell(P(0.004, 0.046, -0.088), (0.069, 0.066, 0.038)), 0.022, SKIN)                 # the chin
    for s in (1, -1):
        h.add(ell(P(s * 0.070, 0.066, -0.012), (0.032, 0.034, 0.026)), 0.016, SKIN)         # cheeks, shoved up by the grin
    h.add(cap(P(0.074, 0.076, 0.056), P(-0.004, 0.100, 0.048), 0.016, 0.0125), 0.012, SKIN)    # the heavy brow over the eye
    h.add(cap(P(-0.024, 0.096, 0.040), P(-0.070, 0.074, 0.038), 0.0125, 0.0105), 0.012, SKIN)
    h.add(cap(P(0, -0.06, -0.012), P(0, -0.165, -0.022), 0.066, 0.090), 0.03, SKIN)         # the neck, back into the yoke
    # the nose: no bridge, two slits
    for s in (1, -1):
        h.sub(ell(P(s * 0.012 - 0.002, 0.118, 0.0065), (0.0045, 0.012, 0.0030), (0, s * 0.5, 0)), 0.002, LIP)
    # the other socket: empty, sunk, stitched shut (paint: grimble_paint.head)
    h.sub(ell(P(-0.052, 0.112, 0.012), (0.026, 0.020, 0.012)), 0.012, SKIN)
    # the socket
    h.sub(sph(tuple(EYE_C), EYE_R + 0.0035), 0.004, DARK)
    # the mouth: a crescent carved in deep, walled in red
    def grin(x, y, z):
        lx, ly, lz = x - c[0], y - c[1], z - c[2]
        dz = np.abs(lz - grin_z(lx)) - grin_h(lx)
        dx = np.abs(lx) - MOUTH_W
        return np.maximum(np.maximum(dz, dx), 0.022 - ly)
    h.sub(custom(grin, (c[0] - 0.10, c[1] + 0.0, c[2] - 0.10), (c[0] + 0.10, c[1] + 0.15, c[2] + 0.05)), 0.003, MOUTH)
    # the lips: thin, dark, drawn along the crescent
    for sgn in (1, -1):
        xs = np.linspace(-MOUTH_W - 0.002, MOUTH_W + 0.002, 15)
        pts = [P(x, face_y(x, float(grin_z(x))) + 0.0015, float(grin_z(x) + sgn * grin_h(x)) + sgn * 0.0025) for x in xs]
        h.add(path(pts, [0.0048] * len(pts)), 0.004, LIP)
    return h


def jaw_points(x):
    return None


def teeth(vox=0.0013):
    """Big, crooked and few, one gap in the top row (the art's)."""
    c = HEAD_C
    t = Field((-0.11, 0.17, 1.03), (0.11, 0.35, 1.23), vox)
    rng = np.random.RandomState(7)
    tp = []

    def tooth(x, top, ln, w, lean):
        zc = float(grin_z(x))
        hh = float(grin_h(x))
        z0 = zc + (hh + 0.003) * top
        y0 = float(face_y(x, zc)) - 0.0115
        a = (c[0] + x, c[1] + y0, c[2] + z0)
        b = (c[0] + x + lean, c[1] + y0 + 0.002, c[2] + z0 - top * ln)
        t.add(cap(a, b, w, w * 0.26), 0.0, TOOTH)
        tp.append((a, top))
    xs = np.linspace(-0.070, 0.070, 11)
    for i, x in enumerate(xs):
        if i == 6:          # the gap
            continue
        ln = float(grin_h(x)) * rng.uniform(0.95, 1.18)
        tooth(float(x + rng.uniform(-0.002, 0.002)), 1, ln + 0.006, 0.0088, rng.uniform(-0.004, 0.004))
    for i, x in enumerate(np.linspace(-0.062, 0.062, 9)):
        ln = float(grin_h(x)) * rng.uniform(0.70, 1.0)
        tooth(float(x + rng.uniform(-0.002, 0.002)), -1, ln + 0.005, 0.0080, rng.uniform(-0.004, 0.004))
    return t


def eye(vox=0.0012):
    e = Field(EYE_C - 0.045, EYE_C + 0.045, vox)
    e.add(sph(tuple(EYE_C), EYE_R), 0.0, EYE)
    return e


def lid(vox=0.0012):
    """The upper lid: a shell over the eyeball, turned by bone `lid`. Rest: the eye a little over half open, the art's slit."""
    e = Field(EYE_C - 0.052, EYE_C + 0.052, vox)

    def fn(x, y, z):
        px, py, pz = x - EYE_C[0], y - EYE_C[1], z - EYE_C[2]
        r = np.sqrt(px * px + py * py + pz * pz)
        sh = np.abs(r - (EYE_R + 0.0032)) - 0.0020
        # keep what lies above a plane tipped back about X, so the lid's edge crosses the eye
        cut = -(pz * 0.97 + py * -0.10 - 0.0095)
        back = -(py + 0.008)
        return np.maximum(np.maximum(sh, cut), back)
    e.add(custom(fn, EYE_C - 0.05, EYE_C + 0.05), 0.0, SKIN)
    return e


MONO_AX = np.array((0.04, 1.0, 0.06), F) / np.linalg.norm((0.04, 1.0, 0.06))
MONO_C = EYE_C + MONO_AX * 0.040
MONO_R = 0.0505
LENS = (((-0.058, 0.012, 0.070), 0.0205), ((-0.082, 0.012, 0.032), 0.0165))       # the two small lenses, his left of the big one


def _ring(c, ax, r, t, wide=0.8):
    """A flat ring round axis ax (a torus of a squashed section)."""
    c = np.array(c, F)
    ax = np.array(ax, F)

    def fn(x, y, z):
        px, py, pz = x - c[0], y - c[1], z - c[2]
        along = px * ax[0] + py * ax[1] + pz * ax[2]
        qx, qy, qz = px - ax[0] * along, py - ax[1] * along, pz - ax[2] * along
        rad = np.sqrt(qx * qx + qy * qy + qz * qz)
        return np.sqrt((rad - r) ** 2 + (along / wide) ** 2) - t
    return Prim(fn, c - r - t - 0.01, c + r + t + 0.01)


def monocle(vox=0.0012):
    m = Field(EYE_C - (0.14, 0.05, 0.09), EYE_C + (0.08, 0.09, 0.11), vox)
    m.add(_ring(MONO_C, MONO_AX, MONO_R, 0.0105, 1.2), 0.0, BRASS)
    m.add(_ring(MONO_C - MONO_AX * 0.024, MONO_AX, MONO_R - 0.004, 0.0100, 2.2), 0.002, BRASS)
    for off, r in LENS:
        c = MONO_C + np.array(off, F) * (1, 0, 1)
        m.add(_ring(c, MONO_AX, r, 0.0060, 1.3), 0.0, BRASS)
        m.add(cap(MONO_C + (off[0] * 0.70, 0, off[2] * 0.70), c, 0.0060, 0.0052), 0.002, BRASS)
    # the chain's lug on the ring's far side
    m.add(sph(tuple(MONO_C + (MONO_R + 0.012, -0.004, -0.008)), 0.0085), 0.002, BRASS)
    return m


# ------------------------------------------------------------------ gear on the body
def belt(vox=0.0028):
    b = Field((-0.20, -0.17, 0.42), (0.20, 0.19, 0.82), vox)

    def ring(x, y, z):
        q = np.sqrt((x / 0.160) ** 2 + (y / 0.128) ** 2)
        return np.maximum(np.abs(q - 1.0) * 0.128 - 0.012, np.abs(z - 0.742 + 0.03 * x) - 0.030)
    b.add(custom(ring, (-0.19, -0.16, 0.66), (0.19, 0.16, 0.82)), 0.0, LEATHER)
    fr = (0.0, 0.142, 0.742)
    b.add(box(fr, (0.042, 0.010, 0.033), 0.004), 0.0, IRON)
    b.sub(box((0.0, 0.156, 0.742), (0.024, 0.012, 0.017), 0.002), 0.002, LEATHER)
    b.add(box((0.0, 0.142, 0.742), (0.030, 0.005, 0.013), 0.002), 0.001, LEATHER)
    # a little pouch on the right
    b.add(ell((0.150, 0.075, 0.700), (0.040, 0.030, 0.052)), 0.0, LEATHER)
    b.add(ell((-0.166, -0.010, 0.690), (0.024, 0.042, 0.056)), 0.0, LEATHER)
    return b


def _flap(front):
    """A torn hanging flap of hide, as a thin sheet wrapped on the hips."""
    sgn = 1.0 if front else -1.0

    def fn(x, y, z):
        wrap = 0.125 - 0.85 * x * x + 0.20 * np.maximum(0.70 - z, 0) * (0 if front else 1) * 0
        sheet = np.abs(y * sgn - wrap - 0.012 - 0.045 * np.maximum(0.72 - z, 0)) - 0.0042
        top = z - 0.725
        width = 0.150 if front else 0.175
        zb = 0.455 + (0.040 * np.sin(x * 37.0 + 0.9) + 0.030 * np.sin(x * 83.0 + sgn) + 0.024 * np.abs(np.sin(x * 141.0))) \
            - 1.2 * np.abs(x) * (0.20 if front else 0.05) + (0.0 if front else 0.012)
        tip = -(0.38 / 0.15) * 0
        return np.maximum(np.maximum(sheet, top), np.maximum(zb - z, np.abs(x) - width + 0.14 * np.maximum(0.72 - z, 0)))
    return custom(fn, (-0.2, -0.22, 0.38), (0.2, 0.22, 0.75))


def loincloth(vox=0.0026):
    l = Field((-0.20, -0.22, 0.38), (0.20, 0.24, 0.76), vox)
    l.add(_flap(True), 0.0, LOIN)
    l.add(_flap(False), 0.0, LOIN)
    return l


def straps(vox=0.003):
    """The pack's harness: over both shoulders, the broad diagonal across his chest."""
    s = Field((-0.27, -0.20, 0.80), (0.27, 0.22, 1.28), vox)
    for sd in (1, -1):
        s.add(path([(sd * 0.135, -0.13, 1.195), (sd * 0.145, -0.03, 1.238), (sd * 0.150, 0.075, 1.170), (sd * 0.168, 0.094, 1.03), (sd * 0.208, 0.0, 0.915)],
                    [0.0135] * 5), 0.0, LEATHER)
    s.add(path([(-0.10, 0.122, 1.122), (-0.02, 0.138, 1.040), (0.08, 0.128, 0.955), (0.18, 0.084, 0.885)], [0.0125] * 4), 0.0, LEATHER)
    s.add(box((0.012, 0.142, 1.016), (0.022, 0.009, 0.024), 0.003, (0, 0.6, 0)), 0.0, IRON)
    return s


def cuff(J, n, s, vox=0.0024):
    """The riveted iron cuff on each wrist."""
    sx, wz = float(J["hand." + n][0]), float(J["hand." + n][2])
    c = Field((sx - 0.11, -0.11, wz - 0.11), (sx + 0.11, 0.11, wz + 0.15), vox)

    def fn(x, y, z):
        r = np.sqrt((x - sx) ** 2 + y ** 2)
        k = np.clip((z - (wz - 0.055)) / 0.15, 0, 1)
        rad = 0.074 + 0.012 * k
        return np.maximum(np.abs(r - rad) - 0.0115, np.abs(z - (wz + 0.020)) - 0.078)
    c.add(custom(fn, (sx - 0.1, -0.1, wz - 0.07), (sx + 0.1, 0.1, wz + 0.11)), 0.0, RUST)
    c.add(cyl((sx, 0, wz + 0.092), (0, 0, 1), 0.092, 0.012, 0.004), 0.0, IRON)
    c.add(cyl((sx, 0, wz - 0.056), (0, 0, 1), 0.082, 0.012, 0.004), 0.0, IRON)
    # a torn lip on the top edge
    for i, a in enumerate((0.4, 1.9, 3.5, 5.0)):
        c.add(ell((sx + 0.094 * math.cos(a), 0.094 * math.sin(a), wz + 0.108), (0.020, 0.020, 0.016)), 0.002, IRON)
    return c


# the gauntlet (left): a heavy scrap fist. Fingers on bones: fingers.L (knuckle), fingers2.L (the rest); thumb.L
def gauntlet_joints(J):
    x, z = float(J["hand.L"][0]), float(J["hand.L"][2])
    return {"wrist": np.array((x, 0, z), F), "knuckle": np.array((x - 0.004, 0.006, z - 0.122), F),
            "mid": np.array((x - 0.004, 0.030, z - 0.190), F), "thumb": np.array((x + 0.052, 0.040, z - 0.052), F),
            "thumb2": np.array((x + 0.068, 0.070, z - 0.122), F)}


def gauntlet(J, vox=0.0024):
    g = gauntlet_joints(J)
    x, z = float(g["wrist"][0]), float(g["wrist"][2])
    p = {"palm": Field((x - 0.14, -0.11, z - 0.34), (x + 0.14, 0.15, z + 0.03), vox)}
    a = p["palm"]
    a.add(box((x, 0.004, z - 0.074), (0.058, 0.066, 0.058), 0.018), 0.0, IRON, "hand.L")
    a.add(ell((x - 0.044, 0.004, z - 0.080), (0.030, 0.060, 0.060)), 0.012, RUST, "hand.L")                 # the back of the hand
    kx = (-0.046, -0.022, 0.003, 0.027)
    fy = (-0.040, -0.014, 0.014, 0.042)
    lens = (0.74, 0.92, 1.0, 0.86)
    for i in range(4):
        y = fy[i]
        l = lens[i]
        k0 = np.array((x - 0.006, y, z - 0.126), F)
        k1 = k0 + (0.006, 0.0, -0.062 * l)
        k2 = k1 + (0.022, 0.0, -0.046 * l)
        k3 = k2 + (0.032, 0.0, -0.028 * l)
        a.add(sph(tuple(k0), 0.0185), 0.004, RUST, "fingers.L")
        a.add(cap(k0, k1, 0.0165, 0.0155), 0.0, IRON, "fingers.L")
        a.add(sph(tuple(k1), 0.0170), 0.0, RUST, "fingers2.L")
        a.add(cap(k1, k2, 0.0150, 0.0138), 0.0, IRON, "fingers2.L")
        a.add(cap(k2, k3, 0.0130, 0.0062), 0.003, IRON, "fingers2.L")
    t0, t1 = g["thumb"], g["thumb2"]
    a.add(sph(tuple(t0), 0.024), 0.008, IRON, "thumb.L")
    a.add(cap(t0, t1, 0.0185, 0.0135), 0.0, IRON, "thumb.L")
    return a


def hook_frame(J):
    """The hook's own frame on the right wrist: shank straight down, the curve in the sagittal plane, the point forward and up."""
    w = np.array((float(J["hand.R"][0]), 0, float(J["hand.R"][2])), F)
    return w


HOOK_SCALE = 1.30           # past the art: from above this has to read as THE hook


def hook_curve():
    """Centre line in (y, z) from the socket's ball to the point, wrist at the origin, metres."""
    k = HOOK_SCALE
    pts = [(0.0, -0.100), (0.0, -0.15), (-0.003, -0.20)]
    cz = -0.275
    R = 0.088
    for a in np.radians(np.linspace(180 + 8, 360 + 55, 11)):
        pts.append((R * math.cos(a) + R, cz + R * math.sin(a)))
    return np.array([(y * k, z * k) for y, z in pts], F)


def hook(J, vox=0.0028):
    """A gaff: socket, ball, a flat tapered J with a barb. In the wrist's frame, moved onto the wrist at build time by hook_xf."""
    x = float(J["hand.R"][0])
    wz = float(J["hand.R"][2])
    k = HOOK_SCALE
    h = Field((x - 0.07, -0.13, wz - 0.74), (x + 0.07, 0.34, wz - 0.03), vox)
    c = hook_curve()
    n = len(c)
    rx = np.interp(np.arange(n), (0, 4, n - 1), (0.024 * k, 0.019 * k, 0.0035))        # across: flat
    ry = np.interp(np.arange(n), (0, 4, n - 1), (0.029 * k, 0.026 * k, 0.004))         # in the plane
    pts = np.stack((np.full(n, x, F), c[:, 0], wz + c[:, 1]), 1)

    def blade(px, py, pz):
        best = np.full(np.broadcast(px, py, pz).shape, 9.0, F)
        for i in range(n - 1):
            a, b = pts[i], pts[i + 1]
            ab = b[1:] - a[1:]
            l2 = float(ab @ ab)
            t = np.clip(((py - a[1]) * ab[0] + (pz - a[2]) * ab[1]) / l2, 0, 1)
            dy = py - a[1] - ab[0] * t
            dz = pz - a[2] - ab[1] * t
            ri = ry[i] + (ry[i + 1] - ry[i]) * t
            xi = rx[i] + (rx[i + 1] - rx[i]) * t
            d = np.sqrt((dy * dy + dz * dz) / (ri * ri) + ((px - x) / xi) ** 2) - 1.0
            best = np.minimum(best, d * np.minimum(ri, xi))
        return best
    h.add(custom(blade, (x - 0.05, -0.13, wz - 0.74), (x + 0.05, 0.34, wz - 0.1)), 0.0, IRON)
    # the barb, inside the point
    t = pts[-3]
    u = pts[-1] - pts[-3]
    u = u / np.linalg.norm(u)
    h.add(cap(t, t + np.array((0, -0.040, 0.0), F) * k + u * -0.03, 0.012, 0.003), 0.003, IRON)
    # the socket bell and ball (the art's: a bell, a ball, then the shank)
    bell = lambda px, py, pz: np.maximum(np.sqrt((px - x) ** 2 + py ** 2) - (0.066 - 0.32 * (wz - 0.052 - pz) * 0.5), np.abs(pz - (wz - 0.095)) - 0.046)
    h.add(custom(bell, (x - 0.08, -0.08, wz - 0.15), (x + 0.08, 0.08, wz - 0.04)), 0.0, RUST)
    h.add(sph((x, 0.0, wz - 0.150), 0.026), 0.004, IRON)
    h.add(cyl((x, 0, wz - 0.140), (0, 0, 1), 0.066, 0.006, 0.003), 0.0, IRON)
    return h


def hook_tip(J):
    c = hook_curve()[-1]
    return np.array((float(J["hand.R"][0]), float(c[0]), float(J["hand.R"][2]) + float(c[1])), F)


def hook_mouth(J):
    c = hook_curve()
    m = c[len(c) // 2 + 1]
    return np.array((float(J["hand.R"][0]), float(m[0]) * 0.75, float(J["hand.R"][2]) + float(m[1]) * 0.9), F)


# the blunderbuss: lies across his left hip on a swivel, a flared mouth. Local: +Y to the muzzle; the swivel at the origin
GUN_AT = np.array((-0.122, 0.150, 0.655), F)
GUN_R = rot(yaw=math.radians(-42.0), pitch=math.radians(-7.0))        # (rest: muzzle forward and to his right)


def gun(vox=0.0020):
    g = Field((-0.09, -0.36, -0.13), (0.09, 0.38, 0.11), vox)
    # barrel, lock, stock, the flare
    g.add(cap((0, -0.015, 0.012), (0, 0.285, 0.012), 0.0175, 0.0200), 0.0, IRON)
    def flare(x, y, z):
        u = np.clip((y - 0.255) / 0.095, 0, 1)
        r = 0.022 + 0.052 * u ** 2.0
        d = np.sqrt(x * x + (z - 0.012) ** 2)
        wall = np.abs(d - r + 0.006) - 0.0072
        return np.maximum(wall, np.maximum(0.255 - y, y - 0.350))
    g.add(custom(flare, (-0.1, 0.24, -0.09), (0.1, 0.36, 0.11)), 0.0, IRON)
    g.add(box((0, -0.030, 0.014), (0.019, 0.040, 0.021), 0.005), 0.0, IRON)
    g.add(cap((0, -0.010, 0.040), (0, -0.044, 0.058), 0.0065, 0.0045), 0.0, BRASS)             # the hammer
    g.add(_ring((0, -0.022, -0.020), (1, 0, 0), 0.016, 0.0034), 0.0, BRASS)                    # the guard
    g.add(path([(0, -0.045, 0.006), (0, -0.115, -0.010), (0, -0.200, -0.042), (0, -0.300, -0.070)], [0.024, 0.024, 0.030, 0.039]), 0.0, WOOD)
    g.add(box((0, -0.326, -0.074), (0.020, 0.012, 0.046), 0.008, (math.radians(-18), 0, 0)), 0.0, IRON)
    g.add(path([(0, 0.0, -0.018), (0, 0.13, -0.012), (0, 0.21, -0.008)], [0.015] * 3), 0.0, WOOD)
    return g


def gun_xf(p):
    return GUN_AT + np.asarray(p, F) @ GUN_R.T


# ------------------------------------------------------------------ the hoard: big simple shapes
def _item(kind, c, R):
    i = len(HOARD)
    HOARD.append({"id": HOARD_BASE + i, "kind": kind, "c": np.array(c, F), "R": R})
    return HOARD_BASE + i


def chest(h, c, hw, hd, hb, hl, R):
    """A chest: a box of hb under an arched lid of hl; iron corners and two straps."""
    wid = _item("chest", c, R)

    def lid_fn(u, v, w):
        ov = (v * v / (hd * hd) + (w / hl) ** 2)
        a = (np.sqrt(ov) - 1.0) * min(hd, hl)
        return np.maximum(np.maximum(a, -w), np.abs(u) - hw)

    def body(u, v, w):
        q = np.abs(np.stack(np.broadcast_arrays(u, v, w + hb), 0)) - np.array((hw, hd, hb), F)[:, None, None, None]
        return np.sqrt(np.sum(np.maximum(q, 0) ** 2, 0)) + np.minimum(np.max(q, 0), 0) - 0.0
    e = math.sqrt(hw * hw + hd * hd + (hb * 2 + hl) ** 2)
    h.add(fixed(c, R, body, e), 0.0, wid)
    h.add(fixed(c, R, lid_fn, e), 0.0, wid)
    # the seam under the lid
    h.sub(fixed(c, R, lambda u, v, w: np.maximum(np.abs(w + 0.002) - 0.0045, -(np.maximum(np.abs(u) - hw + 0.004, np.abs(v) - hd + 0.009))), e), 0.0, DARK)
    # iron: end caps and two straps, proud of the wood
    for ux in (-hw * 0.60, hw * 0.60):
        def band(u, v, w, ux=ux):
            ov = np.sqrt(v * v / ((hd + 0.008) ** 2) + (w / (hl + 0.008)) ** 2) - 1.0
            top = np.where(w > 0, ov * min(hd, hl), np.maximum(np.abs(v) - hd - 0.008, -w - hb * 2 - 0.008))
            return np.maximum(top, np.abs(u - ux) - 0.024)
        h.add(fixed(c, R, band, e), 0.0, IRON)
    def edge(u, v, w):
        return np.maximum(np.maximum(np.abs(u) - hw - 0.005, np.abs(np.abs(u) - hw) - 0.016), np.where(w > 0, (np.sqrt(v * v / ((hd + 0.006) ** 2) + (w / (hl + 0.006)) ** 2) - 1.0) * min(hd, hl), np.maximum(np.abs(v) - hd - 0.006, -w - hb * 2 - 0.006)))
    h.add(fixed(c, R, edge, e), 0.0, IRON)
    # the lock, on the front (+v)
    fr = L(c, R, (0, hd + 0.006, -0.012))
    h.add(box(fr, (0.034, 0.008, 0.040), 0.004, R), 0.0, IRON)


def barrel(h, c, r, hl, R):
    wid = _item("barrel", c, R)

    def fn(u, v, w):
        q = np.sqrt(u * u + v * v)
        rad = r * (0.80 + 0.20 * np.clip(1 - (w / hl) ** 2, 0, 1))
        return np.maximum(q - rad, np.abs(w) - hl)
    e = math.hypot(r, hl) + 0.02
    h.add(fixed(c, R, fn, e), 0.0, wid)
    for t, wd in ((0.86, 0.020), (0.42, 0.016), (-0.42, 0.016), (-0.86, 0.020)):
        def hoop(u, v, w, t=t, wd=wd):
            q = np.sqrt(u * u + v * v)
            rad = r * (0.80 + 0.20 * np.clip(1 - (t) ** 2, 0, 1)) + 0.007
            return np.maximum(np.abs(q - rad + 0.004) - 0.006, np.abs(w - t * hl) - wd)
        h.add(fixed(c, R, hoop, e), 0.0, IRON)
    # the sunk end
    h.sub(fixed(c, R, lambda u, v, w: np.maximum(np.sqrt(u * u + v * v) - r * 0.68, np.abs(w) * -1 + hl - 0.014), e), 0.004, wid)


def shield(h, c, R, sz):
    """A heater shield: wood face, iron rim, a boss."""
    wid = _item("shield", c, R)

    def outline(u, w):
        # top straight, sides curving to the point at the bottom (normalised)
        wn = w / sz
        half = np.where(wn > 0.25, 0.86 + (1 - wn) * 0.06, 0.92 * np.sqrt(np.clip((wn + 1.25) / 1.5, 0, 1)) * (1 - 0.15 * np.clip(-wn, 0, 1)))
        top = wn - 1.0 - 0.10 * np.abs(u / sz) * -1
        return np.maximum(np.abs(u / sz) - half, np.maximum(top, -wn - 1.25)) * sz

    def plate(u, v, w):
        d = outline(u, w)
        return np.maximum(d, np.abs(v - 0.02 * (u / sz) ** 2 * -2) - 0.016)
    e = sz * 1.8
    h.add(fixed(c, R, plate, e), 0.0, wid)
    h.add(fixed(c, R, lambda u, v, w: np.maximum(np.maximum(outline(u, w), -outline(u, w) - 0.028), np.abs(v) - 0.026), e), 0.0, IRON)
    h.add(ell(L(c, R, (0, 0.022, 0.03 * sz)), (0.058, 0.040, 0.058), R), 0.006, IRON)


def scrap(h, c, hw, hh, R, seed):
    """A torn sheet of plate."""
    wid = _item("plate", c, R)

    def fn(u, v, w):
        rim = np.sin(u * 13 + seed) * 0.022 + np.sin(w * 17 + seed * 2) * 0.020 + np.sin((u + w) * 41 + seed) * 0.008
        return np.maximum(np.abs(v) - 0.014, np.maximum(np.abs(u) - hw + rim, np.abs(w) - hh - rim))
    h.add(fixed(c, R, fn, math.hypot(hw, hh) + 0.04), 0.0, wid)


def door(h, c, hw, hh, R):
    """The plank door lashed upright on the back of the pile, two straps crossed over it."""
    wid = _item("door", c, R)

    def fn(u, v, w):
        rim = 0.018 * np.sin(u * 44.0) * (w > 0)
        return np.maximum(np.abs(v) - 0.021, np.maximum(np.abs(u) - hw, np.abs(w) - hh + rim))
    h.add(fixed(c, R, fn, math.hypot(hw, hh) + 0.04), 0.0, wid)
    for sgn in (1, -1):
        a, b = L(c, R, (-hw * 0.92, 0.0, sgn * hh * 0.80)), L(c, R, (hw * 0.92, 0.0, -sgn * hh * 0.80))
        ax = R[:, 2] * -sgn * hh * 1.6 + R[:, 0] * hw * 1.84
        def strap(u, v, w, sgn=sgn):
            t = (u * (hw * 1.84) + w * (-sgn * hh * 1.6)) / float((hw * 1.84) ** 2 + (hh * 1.6) ** 2)
            t = np.clip(t, -0.5, 0.5)
            du, dw = u - t * hw * 1.84, w + t * sgn * hh * 1.6
            return np.maximum(np.sqrt(du * du + dw * dw) - 0.022, np.abs(v) - 0.029)
        h.add(fixed(c, R, strap, math.hypot(hw, hh) + 0.05), 0.0, LEATHER)


HB = np.array((0.0, -0.30, 1.12), F)      # the hoard bone's head


def hoard(vox=0.0052):
    """Front view (his back at y = -0.14): a sack against the spine, then the pile stacked up and behind it."""
    HOARD.clear()
    h = Field((-0.48, -0.74, 0.60), (0.48, 0.02, 1.80), vox)
    bag = lambda x, y, z: 0.014 * np.sin(x * 19 + z * 7) * np.sin(z * 15)
    h.add(ell((0.0, -0.285, 1.05), (0.300, 0.150, 0.300)), 0.0, BURLAP, None, bag)
    h.add(ell((-0.10, -0.32, 0.84), (0.210, 0.150, 0.170)), 0.03, BURLAP, None, bag)
    # the stack, bottom to top
    chest(h, (0.075, -0.495, 0.835), 0.205, 0.120, 0.075, 0.075, rot(yaw=math.radians(190 - 12)), )
    barrel(h, (-0.270, -0.350, 1.055), 0.112, 0.145, rot(yaw=math.radians(-18), pitch=math.radians(78)))
    barrel(h, (0.272, -0.300, 1.075), 0.105, 0.135, rot(yaw=math.radians(26), pitch=math.radians(-74)))
    chest(h, (-0.030, -0.285, 1.270), 0.215, 0.135, 0.090, 0.085, rot(yaw=math.radians(-7)))
    barrel(h, (0.060, -0.360, 1.475), 0.118, 0.170, rot(yaw=math.radians(90 - 9), pitch=math.radians(90)))
    chest(h, (-0.035, -0.300, 1.610), 0.205, 0.128, 0.078, 0.082, rot(yaw=math.radians(13), roll=math.radians(-5)))
    door(h, (0.020, -0.530, 1.440), 0.145, 0.290, rot(yaw=math.radians(180 + 4), roll=math.radians(4)))
    shield(h, (0.235, -0.580, 1.055), rot(yaw=math.radians(180 + 18), roll=math.radians(-8)), 0.155)
    shield(h, (-0.105, -0.115, 1.440), rot(yaw=math.radians(6), pitch=math.radians(-4), roll=math.radians(-7)), 0.125)
    scrap(h, (0.235, -0.150, 1.480), 0.115, 0.125, rot(yaw=math.radians(-16), roll=math.radians(16)), 1.3)
    scrap(h, (-0.215, -0.580, 0.960), 0.130, 0.120, rot(yaw=math.radians(180 - 16), roll=math.radians(-14)), 2.9)
    scrap(h, (-0.235, -0.545, 1.215), 0.090, 0.100, rot(yaw=math.radians(180 - 28), roll=math.radians(21)), 4.4)
    # the coin heap behind his head, spilling to his left (the gold is the pile's bright spot from above)
    coin = lambda x, y, z: 0.0
    coin = lambda x, y, z: 0.018 * np.sin(x * 37 + y * 11) * np.sin(y * 29 + z * 13)
    h.add(ell((0.125, -0.135, 1.265), (0.150, 0.095, 0.085), (0.10, 0.10, 0)), 0.02, GOLD, None, coin)
    h.add(ell((-0.085, -0.150, 1.285), (0.115, 0.085, 0.070), (0.0, -0.2, 0)), 0.02, GOLD, None, coin)
    h.add(ell((-0.245, -0.125, 1.205), (0.085, 0.080, 0.062)), 0.03, GOLD, None, coin)
    rng = np.random.RandomState(3)
    for i in range(24):
        a = rng.uniform(0, math.tau)
        c = (0.02 + rng.uniform(-0.29, 0.25), -0.135 + rng.uniform(-0.08, 0.07), 1.33 + rng.uniform(-0.07, 0.03))
        ax = np.array((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), 1.0), F)
        ax /= np.linalg.norm(ax)
        h.add(cyl(c, ax, 0.040, 0.0075, 0.002), 0.0, GOLD)
    # the frames: timbers fanning out of the pile to carry the bells and lanterns
    for s in (1, -1):
        h.add(path([(s * 0.10, -0.22, 1.30), (s * 0.255, -0.22, 1.56), (s * 0.30, -0.22, 1.62)], [0.024, 0.021, 0.019]), 0.0, _item("beam", (0, 0, 0), np.eye(3, dtype=F)) if s > 0 else HOARD[-1]["id"])
        h.add(path([(s * 0.42, -0.21, 1.33), (s * 0.325, -0.215, 1.57), (s * 0.30, -0.215, 1.625)], [0.021, 0.020, 0.018]), 0.0, HOARD[-1]["id"])
        h.add(path([(s * 0.14, -0.215, 1.46), (s * 0.40, -0.21, 1.42)], [0.0175, 0.0175]), 0.0, HOARD[-1]["id"])
        h.add(sph((s * 0.303, -0.215, 1.640), 0.024), 0.0, IRON)
        # iron arm out from the apex, the lantern's chain hangs from it
        h.add(path([(s * 0.305, -0.215, 1.635), (s * 0.395, -0.215, 1.69), (s * 0.475, -0.215, 1.645)], [0.0115, 0.0105, 0.0095]), 0.0, IRON)
    # two lashings of big-link chain over the pile (one solid rope of links: painted, see P.chainlink)
    h.add(path([(0.27, -0.15, 1.72), (0.215, -0.44, 1.75), (0.19, -0.585, 1.42), (-0.03, -0.635, 1.10), (-0.33, -0.56, 0.84)], [0.0135] * 5), 0.0, ROPE)
    h.add(path([(-0.28, -0.20, 1.40), (-0.28, -0.60, 1.36), (0.0, -0.645, 1.18), (0.31, -0.59, 0.90)], [0.0135] * 4), 0.0, ROPE)
    # the hook on top, the art's crown
    h.add(path([(0.075, -0.385, 1.68), (0.095, -0.395, 1.79)], [0.010, 0.010]), 0.0, IRON)
    h.add(_ring((0.095, -0.395, 1.805), (0, 1, 0), 0.020, 0.0068), 0.0, IRON)
    return h


def frames(vox=0.0052):
    """What the scan hoard doesn't carry: the coin heap behind his head, the timbers and iron arms for the bells and lanterns, the top hook."""
    h = Field((-0.56, -0.40, 1.08), (0.56, 0.0, 1.86), vox)
    # the coin heap behind his head, spilling to his left (the gold is the pile's bright spot from above)
    coin = lambda x, y, z: 0.0
    coin = lambda x, y, z: 0.018 * np.sin(x * 37 + y * 11) * np.sin(y * 29 + z * 13)
    h.add(ell((0.125, -0.135, 1.265), (0.150, 0.095, 0.085), (0.10, 0.10, 0)), 0.02, GOLD, None, coin)
    h.add(ell((-0.085, -0.150, 1.285), (0.115, 0.085, 0.070), (0.0, -0.2, 0)), 0.02, GOLD, None, coin)
    h.add(ell((-0.245, -0.125, 1.205), (0.085, 0.080, 0.062)), 0.03, GOLD, None, coin)
    rng = np.random.RandomState(3)
    for i in range(24):
        a = rng.uniform(0, math.tau)
        c = (0.02 + rng.uniform(-0.29, 0.25), -0.135 + rng.uniform(-0.08, 0.07), 1.33 + rng.uniform(-0.07, 0.03))
        ax = np.array((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), 1.0), F)
        ax /= np.linalg.norm(ax)
        h.add(cyl(c, ax, 0.040, 0.0075, 0.002), 0.0, GOLD)
    # the frames: timbers fanning out of the pile to carry the bells and lanterns
    for s in (1, -1):
        h.add(path([(s * 0.10, -0.22, 1.30), (s * 0.255, -0.22, 1.56), (s * 0.30, -0.22, 1.62)], [0.024, 0.021, 0.019]), 0.0, _item("beam", (0, 0, 0), np.eye(3, dtype=F)) if s > 0 else HOARD[-1]["id"])
        h.add(path([(s * 0.42, -0.21, 1.33), (s * 0.325, -0.215, 1.57), (s * 0.30, -0.215, 1.625)], [0.021, 0.020, 0.018]), 0.0, HOARD[-1]["id"])
        h.add(path([(s * 0.14, -0.215, 1.46), (s * 0.40, -0.21, 1.42)], [0.0175, 0.0175]), 0.0, HOARD[-1]["id"])
        h.add(sph((s * 0.303, -0.215, 1.640), 0.024), 0.0, IRON)
        # iron arm out from the apex, the lantern's chain hangs from it
        h.add(path([(s * 0.305, -0.215, 1.635), (s * 0.395, -0.215, 1.69), (s * 0.475, -0.215, 1.645)], [0.0115, 0.0105, 0.0095]), 0.0, IRON)
    # the hook on top, the art's crown
    h.add(path([(0.075, -0.385, 1.68), (0.095, -0.395, 1.79)], [0.010, 0.010]), 0.0, IRON)
    h.add(_ring((0.095, -0.395, 1.805), (0, 1, 0), 0.020, 0.0068), 0.0, IRON)
    return h




BELL_R = 0.082
BELL_H = 0.135


def bell(vox=0.0022):
    """Local: the crown at the origin, hanging down -Z."""
    b = Field((-0.11, -0.11, -0.18), (0.11, 0.11, 0.05), vox)

    def fn(x, y, z):
        d = np.sqrt(x * x + y * y)
        u = np.clip(-z / BELL_H, 0, 1)
        r = 0.040 + 0.012 * u + 0.030 * u ** 5
        wall = np.abs(d - r) - 0.0075
        return np.maximum(wall, np.maximum(z + 0.0, -z - BELL_H))
    b.add(custom(fn, (-0.1, -0.1, -0.15), (0.1, 0.1, 0.01)), 0.0, IRON)
    b.add(ell((0, 0, -0.002), (0.041, 0.041, 0.022)), 0.0, IRON)
    b.add(_ring((0, 0, 0.022), (0, 1, 0), 0.015, 0.0055), 0.0, IRON)
    b.add(sph((0, 0, -0.125), 0.014), 0.0, BRASS)
    return b


LANTERN_H = 0.20


def lantern(vox=0.0020):
    """Local: the ring at the origin, hanging down -Z. Hexagonal cage, the glow inside."""
    l = Field((-0.075, -0.075, -0.23), (0.075, 0.075, 0.03), vox)
    l.add(cyl((0, 0, -0.105), (0, 0, 1), 0.040, 0.058, 0.002), 0.0, LAMP)
    for i in range(4):
        a = math.tau * (i + 0.5) / 4
        cx, cy = math.cos(a) * 0.044, math.sin(a) * 0.044
        l.add(cap((cx * 0.8, cy * 0.8, -0.040), (cx, cy, -0.170), 0.0060), 0.0, BRASS)
    l.add(cyl((0, 0, -0.044), (0, 0, 1), 0.055, 0.007, 0.002), 0.0, BRASS)
    l.add(cap((0, 0, -0.034), (0, 0, -0.005), 0.034, 0.008), 0.0, BRASS)
    l.add(cyl((0, 0, -0.170), (0, 0, 1), 0.056, 0.007, 0.002), 0.0, BRASS)
    l.add(cap((0, 0, -0.176), (0, 0, -0.205), 0.030, 0.005), 0.0, BRASS)
    l.add(_ring((0, 0, 0.010), (0, 1, 0), 0.0125, 0.0040), 0.0, BRASS)
    return l


# the junk ball: built at true size round the origin, the mesh is shrunk into the sack at rest (bone `ball`); the roll scales it back up
BALL_R = 0.52
BALL_REST = 1.0 / 3.8        # (at rest it hides inside the sack)
BALL_AT = np.array((0.0, -0.29, 1.04), F)


def ball(vox=0.030):
    """Panel d of the sheet: a ball of bent plates and planks in chains, one window the grin looks out of (+Y)."""
    b = Field((-0.62, -0.62, -0.62), (0.62, 0.62, 0.62), vox)
    b.add(sph((0, 0, 0), BALL_R * 0.95), 0.0, IRON)
    rng = np.random.RandomState(11)
    wid = _item("ballplate", (0, 0, 0), np.eye(3, dtype=F))
    wood = _item("ballwood", (0, 0, 0), np.eye(3, dtype=F))
    # plates laid on the sphere, on a fibonacci spiral, skipping the window
    N = 18
    for i in range(N):
        zz = 1 - 2 * (i + 0.5) / N
        r = math.sqrt(1 - zz * zz)
        a = i * 2.39996
        n = np.array((r * math.cos(a), r * math.sin(a), zz), F)
        if n[1] > 0.70:
            continue
        up = np.array((0.1, 0.2, 1.0), F)
        u = np.cross(up, n)
        u /= max(np.linalg.norm(u), 1e-5)
        w = np.cross(n, u)
        R = np.stack((u, n, w), 1)
        tw = rng.uniform(0, 3.1)
        Rt = R @ rot(roll=tw)
        c = n * BALL_R * 0.97
        hw, hh = rng.uniform(0.20, 0.30), rng.uniform(0.15, 0.24)
        lab = wood if i % 4 == 2 else (RUST if i % 4 == 0 else wid)
        b.add(box(tuple(c), (hw, 0.030, hh), 0.012, Rt), 0.012, lab)
    # the window: a deep pocket for the head
    b.sub(ell((0, 0.46, 0.0), (0.27, 0.30, 0.27)), 0.02, DARK)
    return b


def ball_frame(vox=0.012):
    """The brass frame round the ball's window."""
    b = Field((-0.40, 0.30, -0.40), (0.40, 0.60, 0.40), vox)
    b.add(_ring((0, 0.44, 0), (0, 1, 0), 0.285, 0.030, 1.2), 0.0, BRASS)
    return b


def ball_xf(p):
    return BALL_AT + np.asarray(p, F) * BALL_REST
