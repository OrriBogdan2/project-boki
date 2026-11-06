"""ART-1 Ryzz: the rebuilt pieces as data (head and face, hair, pigtails, hands, the lightning rig, chain, gum).
Blender frame: Z up, she faces +Y, her right hand is +X. Budget: 15k tris with the scan body. See /home/boki/shots-s2/art1/STYLE_NOTES.md."""
import numpy as np
from meshkit import (Piece, catmull, norm, smooth, sweep, sd_ell, sd_cap, smin, smax, rot_about, frames)
from kael_pieces import chain_along, grid_faces

SH = 0.1299                      # the rig's shoulder (body.shoulder 0.85)
SHOULDER_Z, ELBOW_Z, HAND_Z = 1.319, 1.109, 0.874
NECK_Z = 1.4404
ANKLE_Z = 0.12
HS = 0.97                        # the sheet's head, a touch bigger for the match camera
C = np.array([0.0, 0.012, 1.602])
EYE = np.array([0.0395, 0.0595, 0.005])
EYE_R = 0.0265
WINK = 1.0                       # +1: her right eye (the sheet) carries the bolt and the wink
HEX6 = [(np.cos(t), np.sin(t)) for t in np.linspace(0, 2 * np.pi, 6, endpoint=False)]
HEX5 = [(np.cos(t), np.sin(t)) for t in np.linspace(0, 2 * np.pi, 5, endpoint=False)]
SQ = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
TRI = [(np.cos(t), np.sin(t)) for t in (0.5, 2.6, 4.7)]
LENS = [(-1, 0), (-0.45, 0.38), (0.45, 0.38), (1, 0), (0.45, -0.3), (-0.45, -0.3)]

# tile rectangles inside the atlas's shared column (u0, v0, u1, v1)
HAIR_R = (0.76, 0.42, 1.0, 1.0)      # across: 4 strips; up: blue -> pink
COPPER_R = (0.76, 0.33, 0.875, 0.41)
GLOWC_R = (0.88, 0.33, 1.0, 0.41)    # neon pink
GLOWW_R = (0.88, 0.24, 1.0, 0.32)    # wire peach
BLACK_R = (0.76, 0.24, 0.875, 0.32)  # dark gunmetal: rod collars


def hl(p):
    return C + np.asarray(p, dtype=np.float64) * HS


def head_sdf(p):
    d = sd_ell(p, (0, -0.012, 0.028), (0.082, 0.096, 0.086))
    d = smin(d, sd_ell(p, (0, 0.018, -0.036), (0.068, 0.070, 0.080)), 0.022)
    d = smin(d, sd_ell(p, (0, 0.040, -0.098), (0.030, 0.034, 0.026)), 0.026)                # the chin
    for s in (-1.0, 1.0):
        d = smin(d, sd_ell(p, (s * 0.054, 0.060, -0.030), (0.024, 0.024, 0.017)), 0.018)    # the cheek
        d = smin(d, sd_cap(p, (s * 0.018, 0.083, 0.036), (s * 0.062, 0.058, 0.046), 0.0065), 0.012)   # a light brow bone
        d = smax(d, -sd_ell(p, (s * EYE[0], 0.098, EYE[2]), (0.0285, 0.024, 0.0205)), 0.007)  # the socket
        d = smin(d, sd_ell(p, (s * 0.0105, 0.097, -0.040), (0.0065, 0.008, 0.0055)), 0.006)   # the nostril's wing
    d = smin(d, sd_cap(p, (0, 0.081, 0.012), (0, 0.1025, -0.030), 0.0058), 0.010)             # the slim bridge
    d = smin(d, sd_ell(p, (0, 0.1045, -0.036), (0.0095, 0.0095, 0.0085)), 0.007)              # the tip, a little turned up
    d = smin(d, sd_ell(p, (0, 0.0905, -0.0605), (0.0235, 0.0095, 0.0058)), 0.006)             # the upper lip
    d = smin(d, sd_ell(p, (0, 0.0880, -0.0725), (0.0190, 0.0105, 0.0072)), 0.006)             # the lower lip
    d = smax(d, -sd_ell(p, (0, 0.104, -0.0665), (0.030, 0.012, 0.0013)), 0.0022)              # the lips' line
    return d


def ray_y(x, z, y0=0.17, steps=48):
    x, z = np.asarray(x, float), np.asarray(z, float)
    y = np.full(x.shape, y0)
    for _ in range(steps):
        y = y - np.clip(head_sdf(np.stack([x, y, z], -1)), -0.01, 0.02) * 0.9
    return y


def ray_dir(D, r0=0.2, steps=48, c=(0, 0, 0)):
    r = np.full(D.shape[:-1], r0)
    for _ in range(steps):
        r = np.maximum(r - np.clip(head_sdf(np.asarray(c) + D * r[..., None]), -0.01, 0.03) * 0.9, 0.004)
    return r


def half_width(z):
    """The head's half width at each height, at y = 0.03: the mask's rows wrap to it, so no corner stands off the skull."""
    z = np.asarray(z, float)
    w = np.full(z.shape, 0.002)
    for _ in range(40):
        w = w + np.clip(-head_sdf(np.stack([w, np.full(z.shape, 0.03), z], -1)), -0.01, 0.01)
    return np.maximum(w, 0.004)


def face_patch():
    xs = np.concatenate([np.linspace(-1.0, -0.72, 3), np.linspace(-0.64, 0.64, 17), np.linspace(0.72, 1.0, 3)])
    zs = np.concatenate([np.linspace(-0.128, -0.094, 4), np.linspace(-0.086, -0.052, 7), np.linspace(-0.045, -0.018, 3), np.linspace(-0.012, 0.03, 8), np.linspace(0.04, 0.09, 3)])
    X, Z = np.meshgrid(xs, zs)
    X = X * half_width(Z) * 0.995
    Y = np.maximum(ray_y(X, Z), 0.0)
    v = hl(np.stack([X, Y, Z], -1).reshape(-1, 3))
    p = Piece("face", "skin-ryzz", v, grid_faces(len(zs), len(xs)))
    # the mouth's corners on their own bones, so she can grin
    mw = {"head": np.ones(len(v))}
    for s, nm in ((1.0, "mouth.R"), (-1.0, "mouth.L")):
        c = hl(np.array([s * 0.0255, 0.082, -0.0665]))
        k = 1 - smooth(0.006, 0.030, np.linalg.norm((v - c) * [1, 1, 1.25], axis=1))
        mw[nm] = k
        mw["head"] = mw["head"] - k
    mw["head"] = np.maximum(mw["head"], 0.0)
    p.w = mw
    return p


def skull():
    """The rest of the head, coarse, right under the hair."""
    rows, cols = 7, 12
    zs = np.linspace(0.09, -0.125, rows)
    angs = np.linspace(0, 2 * np.pi, cols, endpoint=False)
    A, Z = np.meshgrid(angs, zs)
    D = np.stack([np.sin(A), np.cos(A), np.zeros_like(A)], -1)
    R = ray_dir(D, c=np.stack([np.zeros_like(A), np.zeros_like(A), Z], -1), r0=0.14) * 0.985
    v = hl(np.stack([np.sin(A) * R, np.cos(A) * R, Z], -1).reshape(-1, 3))
    return Piece("skull", "skin-ryzz", v, grid_faces(rows, cols, True)).rigid("head")


def eyeball(s):
    c = EYE * [s, 1, 1]
    rows, cols = 5, 8
    v, uv = [], []
    for i in range(rows):
        for j in range(cols):
            a, b = (j / (cols - 1) - 0.5) * 2.0, (i / (rows - 1) - 0.5) * 1.5
            d = norm(np.array([np.sin(a) * np.cos(b), np.cos(a) * np.cos(b), np.sin(b)]))
            v.append(c + rot_about(d, (0, 0, 1), -s * 0.08) * EYE_R)
            uv.append((a, b))
    p = Piece("eye" + ("R" if s > 0 else "L"), "eyes-ryzz", hl(v), grid_faces(rows, cols)).rigid("head")
    p.eye_uv = np.array(uv)
    return p


def lid_up(az):
    return 0.02 + 0.40 * (1 - (az / 1.05) ** 2) + 0.14 * az


def lid_down(az):
    return -0.03 - 0.30 * (1 - (az / 1.05) ** 2) + 0.14 * az


def lids(s):
    """Shells on a sphere round the eye: a big open eye at rest; the upper lid turns down on its bone, the lower stays."""
    c = EYE * [s, 1, 1]
    out = []
    for up in (True, False):
        rows, cols = 4, 7
        v = []
        for i in range(rows):
            for j in range(cols):
                az = (j / (cols - 1) - 0.5) * 2.1
                edge, top = (lid_up(az), 1.2) if up else (lid_down(az), -1.1)
                el = edge + (top - edge) * i / (rows - 1)
                d = np.array([np.sin(az) * s * np.cos(el), np.cos(az) * np.cos(el), np.sin(el)])
                v.append(c + d * (EYE_R * (1.08 + 0.05 * i / (rows - 1))))
        p = Piece("lid%s%s" % ("U" if up else "D", "R" if s > 0 else "L"), "skin-ryzz", hl(v), grid_faces(rows, cols))
        p.rigid(("lid.%s" % ("R" if s > 0 else "L")) if up else "head")
        out.append(p)
    return out


def brow(s):
    side = "R" if s > 0 else "L"
    pts = np.array([(0.013, 0.0955, 0.036), (0.034, 0.0925, 0.048), (0.056, 0.078, 0.052), (0.077, 0.052, 0.042)]) * [s, 1, 1]
    pts[:, 1] = ray_y(pts[:, 0], pts[:, 2]) + 0.0035
    wd = 0.0062 * np.array([0.8, 1.0, 0.8, 0.25])
    b = sweep("brow" + side, "hair-ryzz", hl(pts), [(-1, 0), (0, 0.32), (1, 0), (0, -0.32)], wd * HS * 1.1,
              side_hint=np.array([0, 1.0, 0.3]), uv_rect=(HAIR_R[0] + 0.02, HAIR_R[1], HAIR_R[0] + 0.06, HAIR_R[1] + 0.03), room=0.0)
    return b.rigid("brow." + side)


def ear(s):
    side = "R" if s > 0 else "L"
    p = hl(np.array([(0.086, -0.004, 0.012), (0.094, -0.016, 0.0), (0.090, -0.012, -0.024), (0.080, 0.0, -0.036)]) * [s, 1, 1])
    e = sweep("ear" + side, "skin-ryzz", p, HEX5, np.array([0.009, 0.012, 0.010, 0.005]), side_hint=np.array([0, 1.0, 0]))
    return e.rigid("head")


SURF = None        # set by ryzz_finish: the scan head's radius along head-local directions


def part_r(D):
    """The hair's outer surface along directions D (head-local), a soft groove down the centre parting."""
    r = SURF(D) if SURF is not None else ray_dir(D, c=(0, -0.01, 0.0), r0=0.16)
    groove = np.exp(-(D[..., 0] / 0.09) ** 2) * smooth(-0.1, 0.5, D[..., 2]) * 0.0035
    return r + 0.0065 - groove


def hair_cap():
    """A shell over the skull: lat-long rows, cut along the hairline. Its strands run from the parting to the ties, down in the paint."""
    rows, cols = 9, 18
    v, f, uv = [], [], []
    el = np.linspace(1.5, -0.95, rows)
    az = np.linspace(-np.pi, np.pi, cols + 1)
    A, E = np.meshgrid(az, el)
    D = np.stack([np.sin(A) * np.cos(E), np.cos(A) * np.cos(E), np.sin(E)], -1)
    P = D * part_r(D)[..., None] + np.array([0, -0.01, 0])
    P[..., 2] = np.where(E < -0.2, P[..., 2], P[..., 2])
    # the hairline: drops from the parting to the temples, then behind the ears; the nape sits on the neck
    def inside(q):
        x, y, z = q
        if y <= 0.018:
            return z > -0.115
        return z > 0.082 - 0.70 * abs(x) * (1 + 3.0 * abs(x))
    index, vs = {}, []
    def vid(i, j):
        k = (i, j % cols)
        if k not in index:
            index[k] = len(vs)
            vs.append(P[i, j % cols])
        return index[k]
    for i in range(rows - 1):
        for j in range(cols):
            q = (P[i, j] + P[i, j + 1] + P[i + 1, j] + P[i + 1, j + 1]) / 4
            if not inside(q):
                continue
            f.append([vid(i, j), vid(i, j + 1), vid(i + 1, j + 1), vid(i + 1, j)])
            u0, u1 = HAIR_R[0] + 0.24 * (j % 4) / 4, HAIR_R[0] + 0.24 * ((j % 4) + 1) / 4
            uv.append([(u0, HAIR_R[1]), (u1, HAIR_R[1]), (u1, HAIR_R[1] + 0.10), (u0, HAIR_R[1] + 0.10)])
    return Piece("cap", "hair-ryzz", hl(vs), f, uv, room=0.0).rigid("head")


def lock(name, pts, w0, rings=8, peak=0.3, root=0.6, uv=(0.0, 0.0, 0.25, 1.0), hint=None, thick=0.62, tip=0.0):
    """A soft-tipped hair clump (LENS section), wide across `hint`. uv: tile strip + range along the blue->pink ramp."""
    path = catmull(pts, rings)
    k = np.linspace(0, 1, rings)
    prof = np.minimum(1.0, root + k / peak * (1 - root)) * (1 - smooth(peak, 1.0, k)) ** 0.75
    wd = w0 * np.maximum(prof, 0.03) + tip
    r = HAIR_R
    rect = (r[0] + (r[2] - r[0]) * uv[0], r[1] + (r[3] - r[1]) * uv[1], r[0] + (r[2] - r[0]) * uv[2], r[1] + (r[3] - r[1]) * uv[3])
    p = sweep(name, "hair-ryzz", path, LENS, wd, side_hint=hint if hint is not None else np.array([0, 1.0, 0.1]), uv_rect=rect, room=0.0, depth=wd * thick)
    p.t = np.repeat(k, len(LENS))
    p.path = path
    return p


TIE = np.array([0.0755, -0.012, 0.074])   # head-local, x mirrored


def tie_at(s):
    return hl(TIE * [s, 1, 1])


def fringe():
    """The centre parting's two side falls round the face, as the sheet: thin curved strands down to the cheek."""
    out = []
    for s in (1.0, -1.0):
        sd = "R" if s > 0 else "L"
        out.append(lock("fringeA" + sd, hl(np.array([(0.006, 0.076, 0.098), (0.046, 0.088, 0.066), (0.073, 0.072, 0.010), (0.082, 0.058, -0.045), (0.074, 0.062, -0.088)]) * [s, 1, 1]),
                        0.024, rings=7, peak=0.25, root=0.5, uv=(0.0, 0.0, 0.25, 0.26), hint=np.array([s * 0.4, 1.0, 0.2]), thick=0.5))
        out.append(lock("fringeB" + sd, hl(np.array([(0.05, 0.058, 0.086), (0.082, 0.042, 0.03), (0.092, 0.03, -0.03), (0.086, 0.044, -0.076)]) * [s, 1, 1]),
                        0.020, rings=6, peak=0.25, root=0.5, uv=(0.25, 0.0, 0.5, 0.26), hint=np.array([s * 0.7, 0.7, 0.2]), thick=0.5))
    return [p.rigid("head") for p in out]


def pigtail(s):
    """Two big soft masses that spring up and out of the tie, the outer one rolling over and falling; pink flicks at the crown of the
    arc; two S-curl tails to the collarbone. Everything in tie-relative metres, her right side; x mirrored for the left."""
    sd = "R" if s > 0 else "L"
    T0 = tie_at(s)
    K = 1.16                                         # a touch bigger than the sheet: this is the match-camera read
    def W(pts):
        return T0 + np.array(pts) * K * [s, 1, 1]
    out = []
    hint_f = np.array([0.0, 1.0, 0.25])
    main = [(0, 0, 0), (0.05, -0.012, 0.05), (0.125, -0.02, 0.062), (0.185, -0.028, -0.005), (0.19, -0.03, -0.095), (0.15, -0.03, -0.175)]
    M_ = dict(root=0.42, peak=0.5, thick=0.95, tip=0.006)
    out.append(lock("pigA" + sd, W(main), 0.098, rings=11, uv=(0.0, 0.0, 0.25, 0.46), hint=hint_f, **M_))
    out.append(lock("pigB" + sd, W([(0, -0.002, 0.005), (0.04, -0.045, 0.066), (0.11, -0.068, 0.088), (0.168, -0.078, 0.022), (0.175, -0.085, -0.08)]), 0.082, rings=10,
                    uv=(0.25, 0.0, 0.5, 0.46), hint=np.array([0.2, 1.0, 0.3]), **M_))
    out.append(lock("pigC" + sd, W([(0, 0.004, 0.0), (0.04, 0.03, 0.04), (0.10, 0.04, 0.034), (0.145, 0.042, -0.04), (0.135, 0.042, -0.125)]), 0.074, rings=10,
                    uv=(0.5, 0.0, 0.75, 0.46), hint=hint_f, **M_))
    F_ = dict(root=0.7, peak=0.4, thick=0.7, tip=0.003)
    out.append(lock("pigF0" + sd, W([(0.03, -0.012, 0.045), (0.066, -0.014, 0.105), (0.062, -0.018, 0.165), (0.038, -0.022, 0.208)]), 0.042, rings=7,
                    uv=(0.75, 0.26, 1.0, 1.0), hint=hint_f, **F_))
    out.append(lock("pigF1" + sd, W([(0.09, -0.032, 0.066), (0.16, -0.04, 0.098), (0.218, -0.042, 0.09), (0.262, -0.046, 0.054)]), 0.04, rings=7,
                    uv=(0.0, 0.26, 0.25, 1.0), hint=hint_f, **F_))
    out.append(lock("pigF2" + sd, W([(0.15, -0.032, 0.02), (0.218, -0.04, -0.008), (0.268, -0.046, -0.052), (0.288, -0.05, -0.098)]), 0.038, rings=7,
                    uv=(0.25, 0.26, 0.5, 1.0), hint=hint_f, **F_))
    # the S-curl tails, pink through their outer half, side by side so they never cross
    T_ = dict(root=0.85, peak=0.34, thick=0.72, tip=0.004)
    out.append(lock("pigS0" + sd, W([(0.18, -0.03, -0.09), (0.222, -0.03, -0.16), (0.19, -0.032, -0.22), (0.224, -0.034, -0.28), (0.196, -0.036, -0.335), (0.178, -0.038, -0.365)]), 0.052, rings=11,
                    uv=(0.5, 0.2, 0.75, 1.0), hint=hint_f, **T_))
    out.append(lock("pigS1" + sd, W([(0.115, -0.03, -0.11), (0.138, -0.03, -0.17), (0.106, -0.03, -0.225), (0.136, -0.03, -0.28), (0.116, -0.03, -0.32)]), 0.044, rings=10,
                    uv=(0.75, 0.2, 1.0, 1.0), hint=hint_f, **T_))
    chain = catmull(W(main + [(0.17, -0.032, -0.26)]), CHAIN_BONES + 1)
    names = ["spring_pig%s_%d" % (sd, i) for i in range(CHAIN_BONES)]
    for p in out:
        along_chain(p, chain, names)
    return out, names, chain


CHAIN_BONES = 5


def along_chain(p, pts, names, root="head", still=0.02):
    """Each vertex to its place along a chain: nearest point on the polyline; the first `still` metres stay on the root bone."""
    a, b = pts[:-1], pts[1:]
    best = np.full(len(p.v), 1e9)
    f = np.zeros(len(p.v))
    for i in range(len(a)):
        u = b[i] - a[i]
        h = np.clip(((p.v - a[i]) @ u) / (u @ u), 0, 1)
        d = np.linalg.norm(p.v - (a[i] + h[:, None] * u), axis=1)
        m = d < best
        best[m], f[m] = d[m], (i + h[m])
    w = {n: np.zeros(len(p.v)) for n in names}
    w[root] = np.zeros(len(p.v))
    i0 = np.clip(f.astype(int), 0, len(names) - 1)
    q = f - i0
    for i, n in enumerate(names):
        w[n][i0 == i] = 1 - q[i0 == i] * 0.5
        if i + 1 < len(names):
            m = i0 == i
            w[names[i + 1]][m] += q[m] * 0.5
    r = 1 - smooth(0.0, 0.5, f)
    for n in names:
        w[n] *= 1 - r
    w[root] = r
    p.w = w
    return p


def tie_band(s):
    """The copper coil at the pigtail's root."""
    sd = "R" if s > 0 else "L"
    c = tie_at(s)
    d = norm(np.array([s * 0.74, -0.03, 0.67]))
    u, v = norm(np.cross(d, (0, 1, 0))), np.array([0, 1.0, 0])
    v = norm(np.cross(u, d))
    out = []
    r = 0.031 * HS
    for k, off in enumerate((-0.012, 0.0, 0.012)):
        ring = [c + d * off + (u * np.cos(t) + v * np.sin(t)) * r * (1.05 if k == 1 else 1.0) for t in np.linspace(0, 2 * np.pi, 9)]
        q = sweep("tie%d%s" % (k, sd), "metal-ryzz", ring, HEX5[:4] if False else SQ, np.full(9, 0.0068), side_hint=d, uv_rect=COPPER_R)
        out.append(q.rigid("head"))
    return out


# ------------------------------------------------------------------ hands. Rest: hanging, palm in, thumb forward, fingers straight down and a little curled.
FINGER_L = [(0.040, 0.028, 0.024), (0.044, 0.030, 0.025), (0.041, 0.028, 0.024), (0.032, 0.022, 0.020)]
FINGER_R_ = [0.0095, 0.0098, 0.0093, 0.0083]
KNUCK_D = 0.082
HAND_K = 1.18                    # a stylised big hand: the finger gun has to read at the match camera


def wrist_at(s):
    return np.array([s * SH, 0.0, HAND_Z])


def hand(s):
    """A proper hand on the extra bones: index.*, index2.*, curl.*, curl2.* (the other three), thumb.*. Gloved palm, bare fingers, copper caps on
    the index and thumb. a: wrist to knuckles; k: along the knuckles, the index side first; o: out of the back of the hand."""
    sd = "R" if s > 0 else "L"
    wrist = wrist_at(s)
    a, k, o = np.array([0, 0, -1.0]), np.array([0, 1.0, 0]), np.array([s, 0, 0])
    out = []
    knuck = wrist + a * KNUCK_D
    # (the glove's cuff runs up under the hazard band: the scan's arm stops above the wrist)
    cen = np.array([wrist - a * 0.062, wrist + a * 0.026, wrist + a * 0.058, knuck - a * 0.002])
    wid = np.array([0.034, 0.040, 0.046, 0.044])
    dep = np.array([0.031, 0.024, 0.023, 0.018])
    v = []
    SEC = [(np.cos(t), np.sin(t)) for t in np.linspace(0, 2 * np.pi, 8, endpoint=False)]
    for c, w, d in zip(cen, wid, dep):
        for x, y in SEC:
            v.append(c + k * x * w + o * y * d)
    f = [[i * 8 + j, i * 8 + (j + 1) % 8, (i + 1) * 8 + (j + 1) % 8, (i + 1) * 8 + j] for i in range(3) for j in range(8)]
    f.append([24 + j for j in range(8)])
    out.append(Piece("palm" + sd, "leather-ryzz", v, f).rigid("hand." + sd))
    for fi in range(4):
        base = knuck + k * (0.033 - fi * 0.022) + o * 0.004
        ln = FINGER_L[fi]
        d0 = rot_about(a, o, -s * 0.05 * (fi - 1.5))
        pts = [base - a * 0.010, base.copy()]
        cur, ang = base.copy(), 0.0
        for jn in range(3):
            ang += (0.10, 0.16, 0.12)[jn]
            dd = norm(d0 * np.cos(ang) - o * np.sin(ang))         # a soft curl toward the palm
            cur = cur + dd * ln[jn]
            pts.append(cur.copy())
        pts = np.array(pts)
        wd = np.array([1.05, 1.05, 1.0, 0.92, 0.72]) * FINGER_R_[fi]
        fp = sweep("finger%d%s" % (fi, sd), "skin-ryzz", pts, HEX5, wd, side_hint=k)
        b0, b1 = ("index.", "index2.") if fi == 0 else ("curl.", "curl2.")
        rr = fp.v - base
        along = np.linalg.norm(rr, axis=1)
        k2 = smooth(ln[0] - 0.006, ln[0] + 0.006, along)
        k1 = smooth(-0.006, 0.004, rr @ a)
        fp.w = {"hand." + sd: 1 - k1, b0 + sd: k1 * (1 - k2), b1 + sd: k1 * k2}
        fp.tip = pts[-1]
        fp.base = base
        fp.dirn = norm(pts[-1] - pts[-2])
        out.append(fp)
    base = wrist + a * 0.030 + k * 0.040 - o * 0.010
    t1 = base + norm(a * 0.66 + k * 0.55 - o * 0.42) * 0.040
    t2 = t1 + norm(a * 0.86 + k * 0.28 - o * 0.32) * 0.032
    t3 = t2 + norm(a * 0.92 + k * 0.05 - o * 0.25) * 0.028
    tp = sweep("thumb" + sd, "skin-ryzz", [base - a * 0.008, t1, t2, t3], HEX5, np.array([0.017, 0.0135, 0.0115, 0.0088]), side_hint=o)
    q = smooth(0.0, 0.02, np.linalg.norm(tp.v - base, axis=1))
    tp.w = {"hand." + sd: 1 - q, "thumb." + sd: q}
    tp.tip = t3
    tp.dirn = norm(t3 - t2)
    out.append(tp)
    for p in out:
        p.v = wrist + (p.v - wrist) * HAND_K
        if hasattr(p, "tip"):
            p.tip = wrist + (p.tip - wrist) * HAND_K
        if hasattr(p, "base"):
            p.base = wrist + (p.base - wrist) * HAND_K
    return out


# ------------------------------------------------------------------ the lightning rig
# rod bases on the plate's top edge -> tips: (x, y, z). Fanned wide and leaned back so all four tips read from above.
PLATE_Y = -0.150                      # set from the scan in ryzz_assemble (back of the jacket)
RODS = [((-0.083, -0.15, 1.385), (-0.355, -0.30, 1.785)), ((-0.030, -0.155, 1.405), (-0.150, -0.36, 1.945)),
        ((0.030, -0.155, 1.405), (0.150, -0.36, 1.945)), ((0.083, -0.15, 1.385), (0.355, -0.30, 1.785))]
ROD_R = 0.0108


def rod(i):
    """A rod on its own bone: socket, stepped collars, the shaft and a spear tip."""
    a, b = np.array(RODS[i][0]), np.array(RODS[i][1])
    d = norm(b - a)
    L = np.linalg.norm(b - a)
    sk = np.array([(0.0, 0.5), (0.02, 1.0), (0.14, 1.0), (0.15, 1.5), (0.19, 1.5), (0.20, 1.0), (0.255, 0.85), (0.27, 0.42)])  # (m along, radius / 0.03)
    pts = np.array([a + d * s_ for s_, _ in sk])
    sock = sweep("sock%d" % i, "metal-ryzz", pts, HEX6, sk[:, 1] * 0.0185, side_hint=np.array([1.0, 0, 0]), uv_rect=COPPER_R, tip=False)
    shaft_t = np.array([0.24, 0.30, L - 0.12, L - 0.10, L - 0.09, L])
    shaft_r = np.array([1.0, 1.0, 1.0, 1.9, 1.7, 0.06]) * ROD_R
    sh = sweep("rod%d" % i, "metal-ryzz", np.array([a + d * s_ for s_ in shaft_t]), HEX6, shaft_r, side_hint=np.array([1.0, 0, 0]), uv_rect=COPPER_R)
    sock.rigid("rod.%d" % i)
    sh.rigid("rod.%d" % i)
    # a thin glow sleeve lives inside the shaft; its bone flares it out past the copper when the rods light (Kitefall)
    gl_t = np.linspace(0.30, L - 0.02, 4)
    gl = sweep("rodglow%d" % i, "glow-ryzz", np.array([a + d * s_ for s_ in gl_t]), TRI, np.full(4, ROD_R * 0.45), side_hint=np.array([1.0, 0, 0]), uv_rect=GLOWC_R, room=0.0)
    gl.rigid("rodlit.%d" % i)
    return [sock, sh, gl], a, b, d


def strip(name, mat, pts, w, th, uv=None, hint=None, room=1.0):
    pts = np.asarray(pts)
    p = sweep(name, mat, pts, SQ, np.full(len(pts), w) if np.isscalar(w) else w, side_hint=hint, depth=np.full(len(pts), th), uv_rect=uv or (0, 0, 1, 1), room=room)
    return p


def wire(name, path, w=0.0052, mat="glow-wire", uv=GLOWW_R):
    return sweep(name, mat, path, TRI, np.full(len(path), w), side_hint=np.array([0.3, 0.5, 0.8]), uv_rect=uv, room=0.0)


def gum(c, r=0.046):
    """The bubble: a closed sphere at the lips on its own bone."""
    c = np.asarray(c, float)
    rows, cols = 8, 12
    v = [c + np.array([0, 0, r])]
    for i in range(1, rows):
        e = np.pi * i / rows
        for j in range(cols):
            t = 2 * np.pi * j / cols
            v.append(c + r * np.array([np.sin(e) * np.cos(t), np.sin(e) * np.sin(t), np.cos(e)]))
    v.append(c - np.array([0, 0, r]))
    f = []
    for j in range(cols):
        f.append([0, 1 + j, 1 + (j + 1) % cols])
    for i in range(rows - 2):
        for j in range(cols):
            a, b = 1 + i * cols + j, 1 + i * cols + (j + 1) % cols
            f.append([a, a + cols, b + cols, b])
    last = len(v) - 1
    for j in range(cols):
        f.append([last, 1 + (rows - 2) * cols + (j + 1) % cols, 1 + (rows - 2) * cols + j])
    p = Piece("gum", "cloth-gum", v, f, room=0.0).rigid("gum")
    p.c = c
    return p


def nose_ring(c):
    ring = [np.asarray(c) + np.array([0.0088 * np.cos(t), 0.003, 0.0088 * np.sin(t) * 0.9 - 0.004]) for t in np.linspace(-0.5, np.pi + 0.5, 6)]
    return sweep("nosering", "metal-ryzz", ring, TRI, np.full(6, 0.0016), side_hint=np.array([0, 1.0, 0]), uv_rect=COPPER_R, room=0.0).rigid("head")
