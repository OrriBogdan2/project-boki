"""Pip's sculpt (ART-1, the Dawnfox; id tender). No scan: signed distance fields for the body, arms and head (hem_sdf.py)
and scripted pieces (tail, ears, leaf mantle, apron, goggles, pouch, star lantern, wings), all on the rig's own joints
(art/wardens/src/pip_rig.json). Master sheet briefs/art-refs/pip_FINAL_sheet.png, views pip_turnaround.png, props pip_props.png.
Space: Blender's, facing +Y, her right hand +X, up +Z, metres at the class-neutral size. Her right hand has the lantern; the
bandaged ear is her left; the pouch sits on her left hip."""
import json
import math
import os

import numpy as np

import hem_sdf as S
from hem_sdf import Field, cap, ell, path, sph
from meshkit import Piece, catmull, norm, smooth, sweep

F = np.float32
ANKLE_Z = 0.085
HC = np.array((0.0, 0.03, 1.285))       # the head's sculpt centre
EYE = np.array((0.097, 0.086, 0.026))  # right eyeball centre, from HC; only the almond the socket cuts shows of it (sheet: 17% of the head's width)
EYE_R = 0.052
OPEN = (0.036, 0.040)                  # half width, half height of the opening (pip_head.png)
NOSE = np.array((0.0, 0.246, -0.052))
HEAD_K = 1.0
PIVOT_DROP = 0.066                     # the ring's top sits this far under the wrist, in the curled fingers


def joints(rig_path=None):
    p = rig_path or os.path.join(os.path.dirname(__file__), "..", "..", "art", "wardens", "src", "pip_rig.json")
    rig = json.load(open(p))
    return {k: np.array([v["head"][0], -v["head"][2], v["head"][1]]) for k, v in rig["bones"].items()}


J = joints()
SH = float(abs(J["upper_arm.R"][0]))
WRIST_Z = float(J["hand.R"][2])
HIP_Z = float(J["thigh.R"][2])
GRIP = np.array((SH, 0.0, WRIST_Z - PIVOT_DROP))    # the lantern's pivot, on the ring's top


def h(p):
    return np.asarray(p, dtype=np.float64) + HC


# ---------------------------------------------------------------- the trunk: torso and legs, one field
def body_field():
    f = Field((-0.36, -0.30, 0.0), (0.36, 0.32, 1.26), 0.0065)
    f.add(ell((0, 0, 0.60), (0.205, 0.165, 0.26)), k=0.0)                # the pear: belly and hips
    f.add(ell((0, -0.005, 0.90), (0.165, 0.125, 0.24)), k=0.08)          # chest
    f.add(cap((0, 0, 1.0), (0, 0.0, 1.24), 0.085, 0.09), k=0.05)         # neck, inside the head
    f.add(ell((0, -0.07, 0.50), (0.175, 0.13, 0.13)), k=0.06)            # rump
    for s in (1.0, -1.0):
        hip, knee = J["thigh.R"] * (s, 1, 1), J["shin.R"] * (s, 1, 1)
        kn = knee + (s * 0.012, 0.022, 0.0)
        an = np.array((s * 0.118, -0.012, ANKLE_Z))
        f.add(cap(hip + (0, -0.01, 0.02), kn, 0.115, 0.074), k=0.05)
        f.add(cap(kn, an, 0.074, 0.052), k=0.03)
        # the paw: heel, ball, three toes with grooves between
        f.add(ell((s * 0.126, 0.07, 0.05), (0.082, 0.15, 0.054)), k=0.03)
        for i, t in enumerate((-1.0, 0.0, 1.0)):
            f.add(ell((s * 0.126 + t * 0.052, 0.182 - abs(t) * 0.024, 0.036), (0.034, 0.058, 0.036)), k=0.012)
        # fur at the hip, the sheet's two or three tufts below the apron's hem
        for dz, ln in ((0.0, 0.055), (-0.06, 0.04)):
            f.add(cap((s * 0.17, -0.02, 0.50 + dz), (s * (0.205 + ln), -0.03, 0.44 + dz), 0.05, 0.004), k=0.03)
    # a ground plane under the soles
    f.d = np.maximum(f.d, 0.004 - f.grid()[2])
    return f


# ---------------------------------------------------------------- an arm with its hand; rest: hanging, the art's fluffy forearm
def arm_field(side):
    s = 1.0 if side == "R" else -1.0
    sh = np.array((s * SH, 0.0, J["upper_arm.R"][2]))
    el = np.array((s * SH, 0.0, J["forearm.R"][2]))
    wr = np.array((s * SH, 0.0, WRIST_Z))
    f = Field((s * SH - 0.15, -0.14, WRIST_Z - 0.19), (s * SH + 0.15, 0.14, sh[2] + 0.12), 0.0042)
    f.add(cap(sh + (0, 0, -0.012), el, 0.057, 0.048), k=0.0)
    f.add(cap(el, wr + (0, 0, 0.03), 0.048, 0.053), k=0.02)
    f.add(cap(el + (s * 0.03, -0.02, 0.02), el + (s * 0.075, -0.04, -0.06), 0.03, 0.003), k=0.025)   # elbow tuft
    pz = wr[2] - 0.04
    f.add(ell((s * SH, 0.0, pz), (0.043, 0.055, 0.052)), k=0.02)          # the palm
    if side == "R":
        # curled over the ring (it runs along Y here): each finger out, over and in under the tube
        for t in (-1.0, 0.0, 1.0):
            y = t * 0.03
            c = np.array((s * SH, y, GRIP[2]))
            p0 = np.array((s * (SH + 0.032), y, pz - 0.02))
            f.add(path([p0, c + (s * 0.034, 0, -0.006), c + (s * 0.012, 0, -0.03), c + (-s * 0.02, 0, -0.018)], [0.021, 0.02, 0.018, 0.016]), k=0.008)
        f.add(path([(s * (SH - 0.03), 0.045, pz - 0.0), (s * (SH - 0.038), 0.04, GRIP[2] + 0.008), (s * (SH - 0.024), 0.022, GRIP[2] - 0.02)], [0.022, 0.019, 0.015]), k=0.01)
    else:
        for t in (-1.0, 0.0, 1.0):
            y = t * 0.03 + 0.006
            k0 = np.array((s * (SH + 0.004), y, pz - 0.04))
            f.add(path([k0, k0 + (s * 0.004, 0.008, -0.036), k0 + (-s * 0.004, 0.014, -0.066)], [0.022, 0.02, 0.016]), k=0.009)
        f.add(path([(s * (SH - 0.03), 0.04, pz + 0.005), (s * (SH - 0.04), 0.062, pz - 0.03), (s * (SH - 0.036), 0.07, pz - 0.058)], [0.022, 0.019, 0.015]), k=0.01)
    return f


# ---------------------------------------------------------------- the head: skull, cheeks, muzzle (Field in HC space shifted to world)
def head_field():
    o = HC
    w = lambda p: tuple(np.asarray(p, dtype=np.float64) + o)
    f = Field(w((-0.30, -0.22, -0.20)), w((0.30, 0.28, 0.27)), 0.0032)
    f.add(ell(w((0, -0.012, 0.06)), (0.172, 0.158, 0.185)), k=0.0)
    for s in (1.0, -1.0):
        f.add(ell(w((s * 0.10, 0.04, -0.026)), (0.10, 0.10, 0.082)), k=0.055)      # cheeks
        # the fox's cheek ruff: three tufts swept out and down
        for a, b, r in (((0.17, 0.02, 0.0), (0.262, -0.02, 0.0), 0.052), ((0.15, 0.02, -0.05), (0.215, -0.01, -0.074), 0.042)):
            f.add(cap(w((s * a[0], a[1], a[2])), w((s * b[0], b[1], b[2])), r, 0.009), k=0.034)
        f.add(ell(w((s * 0.09, 0.105, 0.09)), (0.08, 0.05, 0.03)), k=0.04)             # the brow's ridge
    f.add(ell(w((0, 0.17, -0.072)), (0.066, 0.094, 0.05)), k=0.05)                    # muzzle
    f.add(cap(w((0, 0.10, 0.02)), w((0, 0.22, -0.05)), 0.042, 0.024), k=0.05)         # the bridge
    f.add(ell(w((0, 0.13, -0.108)), (0.052, 0.07, 0.028)), k=0.03)                   # chin
    f.add(ell(w((0, -0.06, -0.09)), (0.13, 0.12, 0.09)), k=0.05)                        # the neck's ruff behind the jaw
    return f


def jaw_weight(v):
    """The lower muzzle and chin; v in world."""
    q = v - HC
    below = smooth(-0.086, -0.100, q[:, 2] + 0.018 * (np.abs(q[:, 0]) / 0.06) ** 2 * 0 + (0.045 - np.minimum(np.abs(q[:, 0]), 0.06)) * -0.16)
    front = smooth(0.075, 0.115, q[:, 1])
    side = 1.0 - smooth(0.06, 0.085, np.abs(q[:, 0]))
    return np.clip(below * front * side, 0, 1)


# ---------------------------------------------------------------- generic scripted pieces
def _unit(a):
    a = np.asarray(a, dtype=np.float64)
    return a / max(np.linalg.norm(a), 1e-9)


def loft(name, mat, rings, cap_ends=True, room=1.0):
    """Rings of equal point count -> a closed quad mesh. rings: (R, N, 3)."""
    R = np.asarray(rings, dtype=np.float64)
    r, n = R.shape[:2]
    v = R.reshape(-1, 3).tolist()
    fa = []
    for i in range(r - 1):
        for j in range(n):
            fa.append([i * n + j, i * n + (j + 1) % n, (i + 1) * n + (j + 1) % n, (i + 1) * n + j])
    if cap_ends:
        c0, c1 = len(v), len(v) + 1
        v.append(R[0].mean(0).tolist())
        v.append(R[-1].mean(0).tolist())
        for j in range(n):
            fa.append([j, c0, (j + 1) % n][::-1])
            fa.append([(r - 1) * n + j, (r - 1) * n + (j + 1) % n, c1][::-1])
    p = Piece(name, mat, v, fa, room=room)
    p.ring_t = np.concatenate([np.repeat(np.linspace(0, 1, r), n), [0.0, 1.0]]) if cap_ends else np.repeat(np.linspace(0, 1, r), n)
    return p


def join(name, mat, parts, room=1.0):
    v, f, base = [], [], 0
    for p in parts:
        v.append(p.v)
        f += [[i + base for i in q] for q in p.f]
        base += len(p.v)
    return Piece(name, mat, np.vstack(v), f, room=room)


def tube(name, mat, pts, r, sides=6, room=1.0):
    """A closed round tube through pts. r: a value or one per point."""
    pts = np.asarray(pts, dtype=np.float64)
    r = np.full(len(pts), r) if np.isscalar(r) else np.asarray(r, dtype=np.float64)
    from meshkit import frames
    t, s_, n_ = frames(pts, (0.13, 0.37, 0.92))
    rings = []
    for i in range(len(pts)):
        a = np.linspace(0, 2 * np.pi, sides, endpoint=False)
        rings.append(pts[i] + np.outer(np.cos(a) * r[i], s_[i]) + np.outer(np.sin(a) * r[i], n_[i]))
    return loft(name, mat, rings, room=room)


def ring_tube(name, mat, c, u, v, R, r, n=14, sides=5, room=0.6):
    """A closed torus: centre c, in the plane (u, v)."""
    c, u, v = np.asarray(c, dtype=np.float64), _unit(u), _unit(v)
    w = np.cross(u, v)
    rs = []
    vs, fs = [], []
    for i in range(n):
        a = 2 * math.pi * i / n
        rad = u * math.cos(a) + v * math.sin(a)
        for j in range(sides):
            b = 2 * math.pi * j / sides
            vs.append(c + rad * (R + r * math.cos(b)) + w * r * math.sin(b))
    for i in range(n):
        for j in range(sides):
            a, b_ = i * sides + j, i * sides + (j + 1) % sides
            c_, d = (i + 1) % n * sides + (j + 1) % sides, (i + 1) % n * sides + j
            fs.append([a, d, c_, b_])
    return Piece(name, mat, vs, fs, room=room)


def ball(name, mat, c, r, n=8, m=6, room=0.5):
    c = np.asarray(c, dtype=np.float64)
    r = np.array(r, dtype=np.float64) * np.ones(3)
    rings = []
    for i in range(1, m):
        b = math.pi * i / m
        a = np.linspace(0, 2 * np.pi, n, endpoint=False)
        rings.append(c + np.stack([np.sin(b) * np.cos(a) * r[0], np.sin(b) * np.sin(a) * r[1], np.full(n, -math.cos(b) * r[2])], 1))
    return loft(name, mat, rings, room=room)


def leaf(name, mat, base, along, up, L, W, curl=0.25, n=6, room=0.5, cup=0.16, tip_k=0.72):
    """A closed leaf or petal: a lens-shaped loft along `along`, `up` its upper side, a crease down the middle. curl bends the tip
    down (against up). -> Piece with .u (0..1 along), .s (-1..1 across)."""
    b, a, nrm = np.asarray(base, dtype=np.float64), _unit(along), _unit(up)
    nrm = _unit(nrm - a * nrm.dot(a))
    sd = np.cross(a, nrm)
    us = np.linspace(0.0, 1.0, n + 1)[:-1]
    rings = []
    for u in us:
        w = W * max(math.sin(math.pi * u ** tip_k) ** 0.8, 0.10 if u == 0 else 0.0) * 0.5
        c = b + a * L * u - nrm * curl * L * u * u
        t = 0.003 + 0.005 * math.sin(math.pi * u)
        cu = cup * w
        rings.append([c - sd * w, c - sd * 0.5 * w + nrm * cu * 1.0, c + nrm * cu * 0.45, c + sd * 0.5 * w + nrm * cu * 1.0, c + sd * w, c - nrm * t])
    tip = b + a * L - nrm * curl * L
    p = loft(name, mat, rings, cap_ends=False, room=room)
    k = len(p.v)
    p.v = np.vstack([p.v, tip, b])
    nn = 6
    r = len(rings)
    for j in range(nn):
        p.f.append([(r - 1) * nn + j, (r - 1) * nn + (j + 1) % nn, k])
        p.f.append([(j + 1) % nn, j, k + 1])
    ub = np.concatenate([np.repeat(us, nn), [1.0, 0.0]])
    p.u = ub
    p.vein_o, p.vein_a, p.vein_s, p.vein_L, p.vein_W = b, a, sd, L, W
    return p


# ---------------------------------------------------------------- the tail (a loft: clean rings, fur notches in the outline)
TAIL_PATH = np.array(((0.0, -0.085, 0.47), (-0.012, -0.26, 0.33), (-0.05, -0.47, 0.25), (-0.15, -0.65, 0.28), (-0.29, -0.76, 0.40), (-0.42, -0.79, 0.58), (-0.51, -0.76, 0.76)))
TAIL_R = np.array((0.055, 0.135, 0.185, 0.19, 0.16, 0.105, 0.0))
TAIL_N = 5


def tail():
    n = 24
    pts = catmull(TAIL_PATH, n)
    s = np.linspace(0, 1, n)
    rr = np.interp(s, np.linspace(0, 1, len(TAIL_R)), TAIL_R)
    rr = rr * (1 + 0.10 * np.sin(s * 30.0))
    from meshkit import frames
    t, sd, nn = frames(pts, (0.5, 0.1, 0.85))
    tail_frames = (pts, sd, nn)
    m = 14
    rings = []
    for i in range(n - 1):
        a = np.linspace(0, 2 * np.pi, m, endpoint=False) + i * 0.29
        # tufted outline: every other point out, more toward the tip, at the cream's edge
        jag = 1.0 + (0.025 + 0.17 * s[i] ** 1.5) * np.where(np.arange(m) % 2 == 0, 1.0, -0.25)
        rings.append(pts[i] + np.outer(np.cos(a) * rr[i] * jag * 1.02, sd[i]) + np.outer(np.sin(a) * rr[i] * jag * 0.86, nn[i]))
    p = loft("tail", "skin", rings, cap_ends=False, room=0.7)
    k = len(p.v)
    p.v = np.vstack([p.v, pts[-1], pts[0]])
    r = len(rings)
    for j in range(m):
        p.f.append([(r - 1) * m + j, (r - 1) * m + (j + 1) % m, k])
        p.f.append([(j + 1) % m, j, k + 1])
    p.t = np.concatenate([np.repeat(s[:-1], m), [1.0, 0.0]])
    p.path = pts
    p.frames = tail_frames
    return p


# ---------------------------------------------------------------- ears
def _ear_ring(c, ax, sd, fr, w, d, cup, n=10, grow=0.0):
    """A ring across the ear: convex back, a hollow front."""
    out = []
    for i in range(n):
        a = 2 * math.pi * i / n
        x, y = math.cos(a), math.sin(a)
        yy = y * d if y < 0 else y * d * 0.35 - cup * (1 - x * x)
        out.append(c + sd * x * (w + grow) + fr * (yy + (-grow if y < 0 else grow)))
    return out


def ear(s, grow=0.0, name=None, mat="skin", t0=0.0, t1=1.0, room=0.6):
    """s: +1 her right. Base inside the skull, tip well above it."""
    base = h((s * 0.122, -0.022, 0.12))
    tip = h((s * 0.215, -0.03, 0.378))
    ax = _unit(tip - base)
    fr = _unit(np.array((s * 0.32, 1.0, 0.0)) - ax * np.dot((s * 0.32, 1.0, 0.0), ax))
    sd = np.cross(ax, fr) * s
    rings = []
    ts = np.linspace(t0, t1, 8)
    L = np.linalg.norm(tip - base)
    for t in ts:
        c = base + ax * L * t
        w = (0.112 * (1 - t) ** 0.5 + 0.004) * (0.62 + 0.38 * smooth(0.0, 0.32, t))
        rings.append(_ear_ring(c, ax, sd, fr, float(w), 0.04 * (1 - t) ** 0.7 + 0.002, 0.03 * (1 - t) ** 0.8, grow=grow))
    p = loft(name or ("ear" + ("R" if s > 0 else "L")), mat, rings, room=room)
    p.c0, p.ax, p.fr, p.sd, p.L = base, ax, fr, sd, L
    return p


# ---------------------------------------------------------------- eye, lid, brow
def eye_axis(s):
    return _unit((s * 0.20, 1.0, 0.02))


def eyeball(s):
    c = h(EYE * (s, 1, 1))
    ax = eye_axis(s)
    sd = _unit(np.cross(ax, (0, 0, 1)))
    up = np.cross(sd, ax)
    rings = []
    uvs = []
    n, m = 12, 5
    vs = []
    for i in range(m + 1):
        b = i / m * 1.35
        for j in range(n):
            a = j / n * 2 * math.pi
            d = ax * math.cos(b) + (sd * math.cos(a) + up * math.sin(a)) * math.sin(b)
            vs.append(c + d * EYE_R)
            uvs.append((0.5 + 0.5 * math.sin(b) / 0.98 * math.cos(a) * 0.98, 0.5 + 0.5 * math.sin(b) / 0.98 * math.sin(a) * 0.98))
    fa, fu = [], []
    for j in range(1, n - 1):      # the pole
        q = [0, j, j + 1]
        fa.append(q[::-1] if False else q)
        fu.append([uvs[x] for x in q])
    for i in range(m):
        for j in range(n):
            q = [i * n + j, (i + 1) * n + j, (i + 1) * n + (j + 1) % n, i * n + (j + 1) % n]
            fa.append(q)
            fu.append([uvs[x] for x in q])
    p = Piece("eye" + ("R" if s > 0 else "L"), "eyes", vs, fa, fu, room=0.0)
    return p


def lid(s):
    """The upper lid: a shell a little bigger than the eyeball, rotating about the eye's side axis; at rest above the iris's top."""
    c = h(EYE * (s, 1, 1))
    ax = eye_axis(s)
    sd = _unit(np.cross(ax, (0, 0, 1)))
    up = np.cross(sd, ax)
    R = EYE_R * 1.07
    n, m = 11, 4
    vs, fa = [], []
    for i in range(m + 1):
        e = 0.86 + (2.2 - 0.86) * i / m          # from the rim (angle above the axis) over the top and back
        for j in range(n):
            a = -1.55 + 3.1 * j / (n - 1)
            d = ax * math.cos(e) * math.cos(a) + up * math.sin(e) * math.cos(a * 0.9) + sd * math.sin(a) * math.cos(e * 0.6)
            vs.append(c + _unit(d) * R)
    for i in range(m):
        for j in range(n - 1):
            fa.append([i * n + j, i * n + j + 1, (i + 1) * n + j + 1, (i + 1) * n + j])
    return Piece("lid" + ("R" if s > 0 else "L"), "skin", vs, fa, room=0.0).orient(c)


def brow(s, fld):
    """The sheet's pale oval brow mark, a thin pad lying on the forehead, moved by a bone."""
    c = h((s * 0.06, 0.13, 0.098))
    u = _unit((s * 1.0, -0.12, 0.22))
    rings = []
    k = np.linspace(-1, 1, 6)
    out = []
    for i, t in enumerate(k):
        w = 0.0125 * math.sqrt(max(1 - t * t * 0.92, 0.02))
        q = c + u * t * 0.036
        d = fld.grad(np.array([q], F))[0]
        q = fld.project(np.array([q], F), it=4)[0].astype(np.float64)
        out.append((q, d))
    vs, fa = [], []
    for q, d in out:
        d = _unit(d)
        sd = _unit(np.cross(d, u))
        w = 0.0125
        vs += [q + sd * w + d * 0.0012, q + d * 0.0052, q - sd * w + d * 0.0012, q - d * 0.003]
    for i in range(5):
        for j in range(4):
            fa.append([i * 4 + j, i * 4 + (j + 1) % 4, (i + 1) * 4 + (j + 1) % 4, (i + 1) * 4 + j])
    fa.append([3, 2, 1, 0])
    fa.append([20, 21, 22, 23])
    ws = np.abs(k)
    for i, t in enumerate(k):
        pinch = 0.25 + 0.75 * math.sqrt(max(1 - t * t, 0))
        c_ = np.mean([vs[i * 4], vs[i * 4 + 2]], 0)
        for j in (0, 2):
            vs[i * 4 + j] = c_ + (vs[i * 4 + j] - c_) * pinch
    p = Piece("brow" + ("R" if s > 0 else "L"), "skin", vs, fa, room=0.0)
    return p.orient()


def nose():
    return ball("nose", "leather", h(NOSE), (0.03, 0.02, 0.02), n=8, m=5, room=0.0)


# ---------------------------------------------------------------- goggles, band, head flowers, bandage
def _skull_out(fld, c, d, gap):
    """From a point c along direction d, the far edge of the head + a gap (rays per ring point)."""
    t = 0.36
    for _ in range(46):
        q = np.array([c + d * t], F)
        if fld.sample(q)[0] < gap:
            break
        t -= 0.008
    return c + d * t


def band(fld):
    c0 = h((0, -0.015, 0.095))
    nrm = _unit((0, -0.2, 1.0))       # a ring tipped: high on the brow, lower at the back
    a_ = _unit(np.cross(nrm, (1, 0, 0)))
    b_ = np.cross(nrm, a_)
    pts = []
    for i in range(22):
        t = 2 * math.pi * i / 22
        d = a_ * math.cos(t) + b_ * math.sin(t)
        pts.append(_skull_out(fld, c0, _unit(d + nrm * 0.0), 0.006))
    pts = np.array(pts)
    for _ in range(3):
        pts = (np.roll(pts, 1, 0) + pts + np.roll(pts, -1, 0)) / 3
    rings = []
    for i in range(len(pts)):
        rad = _unit(pts[i] - c0)
        rings.append([pts[i] + nrm * 0.019 + rad * 0.002, pts[i] + nrm * 0.019 + rad * 0.009, pts[i] - nrm * 0.019 + rad * 0.009, pts[i] - nrm * 0.019 + rad * 0.002])
    R = np.array(rings)
    r, n = R.shape[:2]
    fa = []
    for i in range(r):
        for j in range(n):
            fa.append([i * n + j, i * n + (j + 1) % n, (i + 1) % r * n + (j + 1) % n, (i + 1) % r * n + j])
    return Piece("band", "leather", R.reshape(-1, 3), fa, room=0.3).orient(c0)


def goggles():
    out = []
    for s in (1.0, -1.0):
        c = h((s * 0.095, 0.098, 0.19))
        ax = _unit((s * 0.24, 0.70, 0.66))             # they sit pushed up, lenses to the sky: the top-down read
        u = _unit(np.cross(ax, (1, 0, 0)))
        v = np.cross(ax, u)
        tag = "R" if s > 0 else "L"
        out.append(ring_tube("gogrim" + tag, "metal", c, u, v, 0.056, 0.0145, n=14, sides=5))
        out.append(ring_tube("gogrim2" + tag, "metal", c - ax * 0.02, u, v, 0.053, 0.0125, n=10, sides=4))
        n = 12
        vs = [c + ax * 0.006] + [c + ax * 0.002 + (u * math.cos(i / n * 2 * math.pi) + v * math.sin(i / n * 2 * math.pi)) * 0.05 for i in range(n)]
        fa = [[0, i + 1, (i + 1) % n + 1] for i in range(n)]
        out.append(Piece("lens" + tag, "metal", vs, fa, room=0.0).orient(c - ax * 0.05))
    a, b = h((0.036, 0.13, 0.212)), h((-0.036, 0.13, 0.212))
    out.append(tube("gogbridge", "metal", [a, (a + b) / 2 + (0, 0.004, 0.01), b], 0.009, sides=5))
    return out


def flower(name, mat, c, nrm, R, petals=5, rot=0.0, centre="glow", w=0.72, n=3):
    """Pointed petals round a little dome centre."""
    out = []
    nrm = _unit(nrm)
    u = _unit(np.cross(nrm, (0.3, 0.2, 1.0)))
    v = np.cross(nrm, u)
    for i in range(petals):
        a = rot + i / petals * 2 * math.pi
        d = u * math.cos(a) + v * math.sin(a)
        p = leaf("%s_p%d" % (name, i), mat, np.asarray(c) + d * R * 0.1, d + nrm * 0.1, nrm, R, R * w, curl=0.1, n=n, room=0.2, cup=0.1)
        p.flower_c = np.asarray(c, dtype=np.float64)
        out.append(p)
    out.append(ball(name + "_c", centre, np.asarray(c) + nrm * R * 0.08, (R * 0.26, R * 0.26, R * 0.26), n=7, m=4, room=0.0))
    return out


def bandage(ear_p):
    """Wraps of cream cloth round her left ear: a second, fatter ear, its top rounded off; the paint draws the wraps."""
    s = -1.0
    p = ear(s, grow=0.008, name="bandage", mat="cloth", t0=0.30, t1=0.80, room=0.4)
    n = 10
    c = p.v[len(p.v) - 2 - n:len(p.v) - 2]
    m = c.mean(0)
    p.v[len(p.v) - 2 - n:len(p.v) - 2] = m + (c - m) * 0.66
    p.v[-1] = m + p.ax * 0.018
    return p


# ---------------------------------------------------------------- the leaf-and-petal mantle
def _cape_dir(th):
    """th degrees round the neck: 0 front, + toward her left, 180 back."""
    a = math.radians(th)
    return np.array((-math.sin(a), math.cos(a), 0.0))


def cape(body, arms):
    """-> pieces; every vertex is kept out of the body so leaves ride on her, not through her."""
    cz = 1.15
    pieces = []

    def add(name, mat, th, base_r, base_z, L, W, droop, curl=0.2, tw=0.0, n=6):
        d = _cape_dir(th)
        o = np.array((0, -0.01, base_z)) + d * np.array((base_r, base_r * 0.86, 0))
        al = _unit(d * math.cos(math.radians(droop)) + np.array((0, 0, -math.sin(math.radians(droop)))))
        up = _unit(d * math.sin(math.radians(droop)) + np.array((0, 0, math.cos(math.radians(droop)))))
        sd = np.cross(al, up)
        up = _unit(up + sd * tw)
        p = leaf(name, mat, o, al, up, L, W, curl=curl, n=n)
        p.th = th
        pieces.append(p)
        return p

    # the long green layer, from the art's outline: longest at the back, the front left open for the apron
    for i, (th, L, W, dr, tw) in enumerate(((56, 0.35, 0.155, 62, -0.2), (92, 0.36, 0.145, 66, -0.1), (124, 0.42, 0.16, 71, 0.05), (153, 0.47, 0.17, 76, 0.03), (180, 0.50, 0.18, 79, 0.0),
                                            (207, 0.47, 0.17, 76, -0.03), (236, 0.42, 0.16, 71, -0.05), (268, 0.36, 0.145, 66, 0.1), (304, 0.35, 0.155, 62, 0.2))):
        add("leafG%d" % i, "cloth", th, 0.175, 1.075, L, W, dr - 8, tw=tw, curl=0.30)
    # the pink petals over it
    for i, (th, L, W, dr) in enumerate(((36, 0.235, 0.135, 42), (84, 0.29, 0.165, 54), (128, 0.30, 0.175, 60), (180, 0.345, 0.19, 66), (232, 0.30, 0.175, 60), (276, 0.29, 0.165, 54), (324, 0.235, 0.135, 42))):
        add("petal%d" % i, "cloth", th, 0.135, 1.128, L, W, dr - 14, curl=0.34)
    # the small collar leaves on top, round the neck
    for i, (th, L, W, dr) in enumerate(((16, 0.165, 0.11, 8), (344, 0.165, 0.11, 8), (62, 0.19, 0.12, 18), (298, 0.19, 0.12, 18), (116, 0.17, 0.10, 26), (244, 0.17, 0.10, 26), (180, 0.19, 0.115, 30))):
        add("collar%d" % i, "cloth", th, 0.095, 1.15, L, W, dr, curl=0.28, n=5)
    # stay outside the trunk and the arms
    fields = [body] + arms
    for p in pieces:
        q = p.v.astype(F)
        for it in range(3):
            for fl in fields:
                lo, hi = fl.lo, fl.lo + (fl.n - 1) * fl.vox
                m = np.all((q > lo + fl.vox) & (q < hi - fl.vox), 1)
                if not m.any():
                    continue
                d = fl.sample(q[m])
                want = 0.010
                g = fl.grad(q[m], e=0.012)
                q[m] += g * np.maximum(want - d, 0.0)[:, None]
        p.v = q.astype(np.float64)
    return pieces


# ---------------------------------------------------------------- the apron (a front sheet shrink-wrapped to the body; hangs free below the belly)
APRON_TOP, APRON_HEM = 1.02, 0.385


def apron(body):
    cols, rows = 11, 11
    zs = np.linspace(APRON_TOP, APRON_HEM, rows)
    G = np.zeros((rows, cols, 3))
    front_y = 0.0
    prof = np.zeros(cols)
    for r, z in enumerate(zs):
        t = (APRON_TOP - z) / (APRON_TOP - APRON_HEM)
        half = 0.10 + 0.112 * smooth(0.0, 0.62, t) * 1.0 + 0.012 * t
        for c in range(cols):
            x = (c / (cols - 1) * 2 - 1) * half
            y = 0.30
            while y > -0.1:
                if body.sample(np.array([[x, y, z]], F))[0] < 0.012:
                    break
                y -= 0.005
            prof[c] = max(prof[c], y - 0.012 * t) if t > 0.45 else y
            # (a hem: little torn notches)
            dz = 0.0
            if r == rows - 1:
                dz = (-0.018, 0.022, -0.012, 0.03, -0.024, 0.0, -0.02, 0.018, -0.02, 0.026, -0.008)[c]
            G[r, c] = (x, prof[c], z + dz)
    n = rows * cols
    th = 0.006
    v = np.vstack([G.reshape(-1, 3), G.reshape(-1, 3) - (0, th, 0)])
    fa = []
    for r in range(rows - 1):
        for c in range(cols - 1):
            a, b, d, e = r * cols + c, r * cols + c + 1, (r + 1) * cols + c + 1, (r + 1) * cols + c
            fa.append([a, e, d, b])
            fa.append([n + b, n + d, n + e, n + a])
    for c in range(cols - 1):
        a, b = (rows - 1) * cols + c, (rows - 1) * cols + c + 1
        fa.append([a, n + a, n + b, b])
        a, b = c, c + 1
        fa.append([a, b, n + b, n + a])
    for r in range(rows - 1):
        a, b = r * cols, (r + 1) * cols
        fa.append([a, b, n + b, n + a])
        a, b = r * cols + cols - 1, (r + 1) * cols + cols - 1
        fa.append([b, a, n + a, n + b])
    p = Piece("apron", "cloth", v, fa, room=0.2)
    p.G = G
    return p


# ---------------------------------------------------------------- the strap, the woven pouch, vials and scroll (her left hip)
POUCH = np.array((-0.255, 0.075, 0.545))


def strap(body):
    """Over her right shoulder, across the apron, down to the pouch; and round her back."""
    front = [(0.115, 0.09, 1.06), (0.06, 0.17, 0.97), (-0.05, 0.19, 0.82), (-0.17, 0.165, 0.67), (-0.235, 0.09, 0.62)]
    back = [(-0.27, 0.0, 0.64), (-0.19, -0.13, 0.76), (-0.03, -0.15, 0.92), (0.10, -0.08, 1.04)]
    all_p = catmull(np.array(front + back + [front[0]]), 28)
    q = all_p.astype(F)
    for it in range(4):
        d = body.sample(q)
        q += body.grad(q, e=0.012) * (0.016 - d)[:, None]
    rings = []
    t = np.gradient(q.astype(np.float64), axis=0)
    t = t / np.linalg.norm(t, axis=1, keepdims=True)
    for i in range(len(q) - 1):
        n_ = body.grad(q[i:i + 1], e=0.012)[0].astype(np.float64)
        sd = _unit(np.cross(t[i], n_))
        p = q[i].astype(np.float64)
        rings.append([p + sd * 0.019 + n_ * 0.002, p + sd * 0.019 - n_ * 0.004, p - sd * 0.019 - n_ * 0.004, p - sd * 0.019 + n_ * 0.002])
    R = np.array(rings)
    r, n = R.shape[:2]
    fa = [[i * n + j, i * n + (j + 1) % n, (i + 1) % r * n + (j + 1) % n, (i + 1) % r * n + j] for i in range(r) for j in range(n)]
    return Piece("strap", "leather", R.reshape(-1, 3), fa, room=0.2).orient()


def pouch():
    """A rounded woven bag; the flap a separate piece over its top."""
    c = POUCH
    rings = []
    n = 12
    for z, w, d in ((-0.128, 0.03, 0.02), (-0.112, 0.092, 0.05), (-0.07, 0.132, 0.068), (-0.012, 0.142, 0.074), (0.05, 0.128, 0.068), (0.098, 0.10, 0.05), (0.112, 0.07, 0.03)):
        a = np.linspace(0, 2 * np.pi, n, endpoint=False)
        rings.append(c + np.stack([np.cos(a) * w, np.sin(a) * d, np.full(n, z)], 1))
    bag = loft("pouch", "leather", rings, room=0.5)
    flap = []
    for z, w, y in ((0.118, 0.098, 0.0), (0.098, 0.128, 0.052), (0.05, 0.135, 0.078), (0.0, 0.112, 0.086), (-0.03, 0.06, 0.086), (-0.044, 0.008, 0.084)):
        rw = []
        for k in np.linspace(-1, 1, 7):
            rw.append(c + (k * w, y + 0.012 * (1 - k * k), z))
        for k in np.linspace(1, -1, 7)[1:-1]:
            rw.append(c + (k * w, y + 0.0, z))
        flap.append(rw)
    fl = loft("flap", "leather", flap, room=0.4)
    buckle = ring_tube("buckle", "metal", c + (0, 0.092, -0.022), (1, 0, 0), (0, 0, 1), 0.013, 0.0035, n=8, sides=4)
    vials = []
    for nm, at, r, ht in (("vialP", (0.052, 0.086, -0.052), 0.046, 0.05), ("vialV", (-0.052, 0.082, -0.02), 0.024, 0.08), ("vialT", (-0.148, 0.0, -0.062), 0.04, 0.04)):
        p0 = c + at
        vials.append(ball(nm, "leather", p0, (r, r, r * (1.0 if ht < 0.06 else 1.5)), n=8, m=5))
        vials.append(tube(nm + "_neck", "metal", [p0 + (0, 0, r * (0.9 if ht < 0.06 else 1.35)), p0 + (0, 0, r + ht * 0.62)], 0.0125, sides=6))
        vials.append(tube(nm + "_cork", "leather", [p0 + (0, 0, r + ht * 0.6), p0 + (0, 0, r + ht * 0.95)], 0.0145, sides=6))
    a, b = c + (-0.07, -0.022, 0.04), c + (-0.155, -0.04, 0.215)
    scroll = tube("scroll", "cloth", [a, (a + b) / 2, b], (0.031, 0.034, 0.036), sides=8)
    tie = tube("scrolltie", "leather", [(a + b) / 2 + (b - a) * -0.06, (a + b) / 2 + (b - a) * 0.08], 0.037, sides=8)
    return [bag, fl, buckle, scroll, tie] + vials


# ---------------------------------------------------------------- the star lantern (hangs from the ring in her right hand)
LZ = {"ring": GRIP[2] - 0.05, "top": GRIP[2] - 0.122, "eave": GRIP[2] - 0.20, "bottom": GRIP[2] - 0.39, "tip": GRIP[2] - 0.47}


def lantern():
    """All in the bone's rest: centred under GRIP."""
    x, y = GRIP[0], GRIP[1]
    c = lambda z: np.array((x, y, z))
    out = []

    def sq(z, w, chamfer=0.14, n=8):
        w = max(w, 0.001)
        pts = []
        for i in range(4):
            a = math.pi / 2 * i + math.pi / 4
            cc = np.array((math.cos(a), math.sin(a))) * w * 1.414
            t = np.array((-math.sin(a), math.cos(a)))
            for sgn in (-1, 1):
                o = cc + sgn * t * w * chamfer
                pts.append(c(z) + (o[0], o[1], 0))
        return pts
    # the ring and its loop
    ring_c = c(LZ["ring"])
    out.append(ring_tube("lring", "metal", ring_c, (0, 1, 0), (0, 0, 1), 0.050, 0.0105, n=14, sides=5))
    out.append(tube("lneck", "metal", [c(LZ["ring"] - 0.05), c(LZ["top"] + 0.012)], (0.016, 0.019), sides=6))
    Zt, Ze, Zb = LZ["top"], LZ["eave"], LZ["bottom"]
    roof = [sq(Zt + 0.01, 0.018), sq(Zt - 0.002, 0.030), sq(Ze + 0.012, 0.094), sq(Ze, 0.106), sq(Ze - 0.012, 0.102)]
    out.append(loft("lroof", "metal", roof, room=0.5))
    body = [sq(Ze - 0.012, 0.086), sq(Zb + 0.016, 0.070)]
    out.append(loft("lbody", "metal", body, room=0.2))
    foot = [sq(Zb + 0.018, 0.074), sq(Zb, 0.086), sq(Zb - 0.012, 0.08), sq(LZ["tip"], 0.003)]
    out.append(loft("lfoot", "metal", foot, room=0.5))
    # the four corner posts stand proud
    for i in range(4):
        a = math.pi / 2 * i + math.pi / 4
        d = np.array((math.cos(a), math.sin(a), 0.0)) * 1.414
        out.append(tube("lpost%d" % i, "metal", [c(Ze - 0.008) + d * 0.087, c(Zb + 0.016) + d * 0.071], 0.0078, sides=4))
    # arched panes on all four sides: the glow
    for i in range(4):
        a = math.pi / 2 * i
        n_ = np.array((math.cos(a), math.sin(a), 0.0))
        t_ = np.array((-math.sin(a), math.cos(a), 0.0))
        zc = (Ze + Zb) / 2 - 0.004
        hh = (Ze - Zb) / 2 * 0.76
        rim = []
        for k in range(13):
            b = k / 12 * 2 * math.pi
            cb, sb = math.cos(b), math.sin(b)
            w = 0.058 * abs(cb) ** 0.62 * (1 if cb > 0 else -1)
            z = zc + hh * abs(sb) ** 0.72 * (1 if sb > 0 else -1)
            wall = 0.086 + (0.070 - 0.086) * (Ze - 0.012 - z) / (Ze - Zb - 0.028)
            rim.append(c(z) + n_ * (wall * 1.1 + 0.0025) + t_ * w)
        mid = c(zc) + n_ * (0.0885)
        v = [mid] + rim[:-1]
        n = len(rim) - 1
        p = Piece("lpane%d" % i, "glow", v, [[0, j + 1, (j + 1) % n + 1] for j in range(n)], room=0.0)
        p.orient(c(zc))
        # the pane's own chart: planar on the side
        p.pane_n, p.pane_t, p.pane_c, p.pane_w, p.pane_h = n_, t_, c(zc), 0.058, hh
        out.append(p)
    return out


# ---------------------------------------------------------------- the wings: alpha cards, two a side, gold veined (pip_paint.wing_atlas)
def wing_frame(s, upper):
    root = np.array((s * 0.035, -0.135, 1.02 if upper else 0.92))
    if upper:
        span = _unit((s * 0.85, -0.38, 0.38))
        L, Wd = 0.88, 0.50
    else:
        span = _unit((s * 0.62, -0.50, -0.60))
        L, Wd = 0.50, 0.32
    # the card's plane faces up and back: the match camera sees 65 degrees down, from behind or in front, so a wing never goes edge-on
    tilt = _unit((0, 0.7, 0.71))
    ch = _unit(tilt - span * tilt.dot(span))
    return root, span, ch, L, Wd


def wing(s, upper):
    root, span, ch, L, Wd = wing_frame(s, upper)
    nrm = np.cross(span, ch)
    cols, rows = 6, 5
    vs, uv, fa, us = [], [], [], []
    v0, v1 = (0.5, 1.0) if upper else (0.0, 0.5)
    for i in range(cols):
        u = i / (cols - 1)
        for j in range(rows):
            v = j / (rows - 1)
            sag = 0.05 * math.sin(u * math.pi) * (1 - 2 * abs(v - 0.5))
            vs.append(root + span * L * u + ch * Wd * (v - 0.5) + nrm * sag * s)
            uv.append((u, v0 + (v1 - v0) * v))
            us.append(u)
    fus = []
    for i in range(cols - 1):
        for j in range(rows - 1):
            q = [i * rows + j, (i + 1) * rows + j, (i + 1) * rows + j + 1, i * rows + j + 1]
            fa.append(q)
            fus.append([uv[x] for x in q])
    p = Piece("wing%s%s" % ("U" if upper else "D", "R" if s > 0 else "L"), "card", vs, fa, fus, room=0.0)
    p.u = np.array(us)
    return p


def seat_eyes(fld):
    """The eyeball pokes 12 mm through the head's surface: its visible disc is then the sheet's eye (r ~ 34 mm), no socket to read as a hole."""
    q = np.array([[EYE[0] + HC[0], y, EYE[2] + HC[2]] for y in np.arange(0.35, 0.0, -0.002) + HC[1]], F)
    d = fld.sample(q)
    surf = q[np.argmax(d < 0), 1] - HC[1]
    EYE[1] = surf + 0.012 - EYE_R
