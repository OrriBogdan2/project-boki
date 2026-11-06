"""ART-1 Claire: the rebuilt pieces as data: gloved hands, rabbit ears, ram horns of ice, bat wings of ice, the heart-tipped tail, the back bow and its ribbons,
the ice blades, the candy-cane spear, the upper lids. The body, hood and face are the scan's (claire_source.py).
Blender frame: Z up, she faces +Y, her right hand is +X. Recipe: /home/boki/shots-s2/art1/STYLE_NOTES.md."""
import json, os
import numpy as np
from meshkit import Piece, catmull, norm, smooth, sweep, frames, rot_about

HERE = os.path.dirname(os.path.abspath(__file__))
_rig = json.load(open(os.path.join(HERE, "..", "..", "art", "wardens", "src", "claire_rig.json")))["bones"]


def J(b):
    x, y, z = _rig[b]["head"]
    return np.array([x, -z, y], float)


SH, THIGH_X = J("upper_arm.R")[0], J("thigh.R")[0]
SHOULDER_Z, ELBOW_Z, HAND_Z, NECK_Z, HIPS_Z = J("upper_arm.R")[2], J("forearm.R")[2], J("hand.R")[2], J("head")[2], J("hips")[2]
ANKLE_Z, SOLE_Z = 0.19, 0.052
HK = 0.92                                      # the scan's head scale
ARM = {"R": 1.0, "L": -1.0}
SEC6 = [(np.cos(t), np.sin(t)) for t in np.linspace(0, 2 * np.pi, 6, endpoint=False)]
SEC8 = [(np.cos(t), np.sin(t)) for t in np.linspace(0, 2 * np.pi, 8, endpoint=False)]
FLAT = [(-1, 0), (-0.45, 0.5), (0.45, 0.5), (1, 0), (0.45, -0.5), (-0.45, -0.5)]


def hs(p):
    """The scan's head (its metres, sole at 0) -> rig."""
    return np.array([0, 0, NECK_Z]) + (np.asarray(p, float) - [0, 0, 1.50]) * HK


# ---- the eyes, on the scan (claire_face.py measured them)
EYE = np.array([0.0365, 0.098, 1.690])
EYE_W, EYE_H = 0.0235, 0.0165


def eye_c(s):
    return hs(EYE * [s, 1, 1])


# ---- gloved hands
GRIP_K = np.array([0.0, 1.0, 0.0])            # the fist's hole, rest pose: the spear runs through it, tip forward
_a = np.array([0, 0, -1.0])
WRIST_R = np.array([SH, 0.0, HAND_Z + 0.012])
GRIP_AT = WRIST_R + _a * 0.078 + np.array([-0.022, 0.0, 0.0])
SHAFT_R = 0.0125


def hand(side, grip_dir, curl, spread=0.0):
    """A slim gloved hand on the wrist. curl: finger joint angles (radians). k along the knuckles (first finger first), a wrist to knuckles, o out of its back."""
    s = ARM[side]
    wrist = np.array([s * SH, 0.0, HAND_Z + 0.012])
    k = norm(np.asarray(grip_dir, float))
    a = np.array([0, 0, -1.0])
    a = norm(a - k * np.dot(a, k))
    o = norm(np.cross(a, k))
    if o[0] * s < 0:
        o = -o
    pieces = []
    knuck = wrist + a * 0.07
    centre = [wrist - a * 0.022, wrist + a * 0.024, wrist + a * 0.052, knuck]
    width = np.array([0.027, 0.034, 0.039, 0.037])
    depth = np.array([0.024, 0.0205, 0.0195, 0.0165])
    palm = sweep("palm" + side, "fur-trim", centre, SEC8, width, side_hint=o, depth=depth)
    t_, s_, n_ = frames(np.asarray(centre), o)
    for i in range(len(centre)):
        for j in range(8):
            d = palm.v[i * 8 + j] - centre[i]
            x = np.dot(d, s_[i]) / width[i]
            y = np.dot(d, n_[i]) / depth[i]
            palm.v[i * 8 + j] = centre[i] + k * x * width[i] + o * y * depth[i]
    pieces.append(palm.rigid("hand." + side))
    lens = [(0.030, 0.021, 0.019), (0.033, 0.023, 0.020), (0.031, 0.022, 0.019), (0.025, 0.017, 0.016)]
    rads = [0.0088, 0.0092, 0.0087, 0.0077]
    for f in range(4):
        base = knuck + k * (0.0275 - f * 0.0183) + o * 0.003
        p = [base - a * 0.01]
        d = norm(rot_about(a, o, -spread * (f - 1.5)))
        p.append(base.copy())
        cur = base.copy()
        ang = 0.0
        for jn in range(3):
            ang += curl[jn]
            dd = rot_about(d, k, ang * (1.0 if np.dot(np.cross(k, a), o) < 0 else -1.0))
            cur = cur + dd * lens[f][jn]
            p.append(cur.copy())
        p = np.array(p)
        wd = np.array([1.0, 1.02, 1.0, 0.92, 0.76]) * rads[f]
        fp = sweep("finger%d%s" % (f, side), "fur-trim", p, SEC6, wd, side_hint=k)
        if side == "R":
            fp.rigid("hand.R")
        else:
            q = smooth(0.012, 0.018, np.linalg.norm(fp.v - base, axis=1))
            fp.w = {"hand.L": 1 - q, "fingers.L": q}
        pieces.append(fp)
    base = wrist + a * 0.022 + k * 0.036 - o * 0.006
    t1 = base + norm(a * 0.72 + k * 0.42 - o * 0.5) * 0.031
    t2 = t1 + norm(a * 0.9 + k * 0.05 - o * 0.45) * 0.024
    t3 = t2 + norm(a * 0.9 - k * 0.35 - o * 0.2) * 0.02
    tp = sweep("thumb" + side, "fur-trim", [base - a * 0.008, t1, t2, t3], SEC6, np.array([0.015, 0.0115, 0.0095, 0.008]), side_hint=o)
    if side == "R":
        tp.rigid("hand.R")
    else:
        q = smooth(0.008, 0.024, np.linalg.norm(tp.v - base, axis=1))
        tp.w = {"hand.L": 1 - q, "thumb.L": q}
    pieces.append(tp)
    return pieces


def cuff_cap(side):
    """Closes the sleeve's cut end inside the fur cuff."""
    s = ARM[side]
    c = np.array([s * SH, 0.0, HAND_Z])
    path = [c + [0, 0, 0.05], c + [0, 0, 0.012], c + [0, 0, -0.012]]
    p = sweep("cuffcap" + side, "fur-trim", path, SEC8, np.array([0.05, 0.05, 0.022]), side_hint=np.array([1.0, 0, 0]))
    return p.rigid("forearm." + side)


def skirt_panel(s, bell):
    """Covers the pit in the skirt's side: a curved piece of the bell, pelvis and skirt bone like the cloth round it."""
    side = "R" if s > 0 else "L"
    zs = np.array([z for z, r in bell if r > 0])
    rs = np.array([r for z, r in bell if r > 0])
    rows = np.linspace(0.815, 1.03, 8)
    azs = np.linspace(-0.62, 0.62, 9)
    v = []
    for z in rows:
        r = float(np.interp(z, zs, rs))
        for a in azs:
            k = 1.0 + 0.14 * np.cos(a * 2.2) ** 2 + 0.006 / max(r, 0.05)      # (the bell runs wider at the side than at the 30-50 degree ring)
            v.append((s * r * k * np.cos(a), r * k * np.sin(a), z))
    p = Piece("skirtpanel" + side, "cloth-dress", np.array(v), [[j * 9 + i, j * 9 + i + 1, (j + 1) * 9 + i + 1, (j + 1) * 9 + i] for j in range(7) for i in range(8)])
    p.orient((0, 0, 0.92))
    h = smooth(1.0, 0.84, p.v[:, 2])
    p.w = {"root": 1 - 0.45 * h, "skirt": 0.45 * h}
    return p


# ---- rabbit ears: long, soft, cupped toward the front; they spill out and down off the hood so they read from above
EAR_N = 5


def ear(s):
    side = "R" if s > 0 else "L"
    top = NECK_Z
    pts = [(0.090, -0.05, top + 0.30), (0.160, -0.07, top + 0.305), (0.208, -0.08, top + 0.225), (0.230, -0.075, top + 0.09),
           (0.236, -0.055, top - 0.05), (0.224, -0.03, top - 0.165)]
    path = catmull(np.array(pts) * [s, 1, 1], 13)
    u = np.linspace(0, 1, 13)
    wd = 0.036 + 0.052 * np.sin(np.clip(u * 1.15, 0, 1) * np.pi) ** 0.8 + 0.012 * smooth(0.2, 0.7, u)
    wd[-1] = 0.012
    wd[-2] *= 0.72
    sec = [(-1, 0.0), (-0.6, -0.42), (0.0, -0.62), (0.6, -0.42), (1, 0.0), (0.6, 0.3), (0.0, 0.52), (-0.6, 0.3)]
    p = sweep("ear" + side, "fur-trim", path, sec, wd, side_hint=np.array([s, 0.0, 0.25]), depth=np.full(13, 0.022))
    p.path, p.u = path, u
    return p


def ear_points(p):
    return [tuple(p.path[int(round(t * (len(p.path) - 1)))]) for t in np.linspace(0.04, 1.0, EAR_N)]


# ---- ram horns: ice, through the hood, one full curl close to the head and the tip turning forward
def horn(s):
    """The head sheet's ram horn: thick at the hood, up and out, over and down behind, the tip turning up and forward; segmented."""
    side = "R" if s > 0 else "L"
    n = NECK_Z
    pts = [(0.06, -0.01, n + 0.325), (0.085, -0.022, n + 0.388), (0.125, -0.052, n + 0.428), (0.17, -0.09, n + 0.415), (0.2, -0.1, n + 0.36),
           (0.2, -0.066, n + 0.312), (0.214, -0.018, n + 0.292), (0.242, 0.016, n + 0.316)]
    path = catmull(np.array(pts) * [s, 1, 1], 22)
    u = np.linspace(0, 1, 22)
    wd = 0.036 * (1 - u) ** 0.8 + 0.0035
    wd *= 1 + 0.05 * np.abs(np.sin(u * 24))          # the plates
    p = sweep("horn" + side, "ice-horn", path, SEC8, wd, side_hint=np.array([0, 1.0, 0.1]))
    p.path, p.u = path, u
    return p.rigid("head")


# ---- bat wings of ice: a thin arm and a scalloped web; two sheets back to back, on a three-bone chain so a skate folds them
WING_N = 4


def wing(s):
    side = "R" if s > 0 else "L"
    y0 = -0.175
    root = np.array([s * 0.075, y0 + 0.02, 1.235])
    elbow = np.array([s * 0.185, y0 - 0.03, 1.415])
    wrist = np.array([s * 0.28, y0 - 0.055, 1.465])
    tip = np.array([s * 0.495, y0 - 0.085, 1.285])
    spine = catmull([root, elbow, wrist, tip], 9)
    # the web's lower edge: scallops between finger tips, tip -> root
    tips = [tip, np.array([s * 0.41, y0 - 0.075, 1.205]), np.array([s * 0.31, y0 - 0.06, 1.145]), np.array([s * 0.2, y0 - 0.03, 1.15]), root + [s * 0.012, 0, -0.03]]
    edge = []
    for i in range(len(tips) - 1):
        a, b = tips[i], tips[i + 1]
        m = (a + b) / 2 + norm(wrist - (a + b) / 2) * 0.042
        edge += [a, (a + m) / 2 + [0, 0, -0.004], m, (m + b) / 2 + [0, 0, -0.004]]
    edge.append(tips[-1])
    edge = np.array(edge)[::-1]                 # root -> tip
    # columns: spine point i to edge point i
    idx = np.linspace(0, len(edge) - 1, len(spine))
    e2 = np.stack([np.interp(idx, np.arange(len(edge)), edge[:, k]) for k in range(3)], 1)
    # (the web fans from the wrist: the upper rows pinch toward the arm)
    rows = 5
    v, f = [], []
    for lay, off in ((0, 0.0035), (1, -0.0035)):
        base = len(v)
        for j in range(rows):
            t = j / (rows - 1)
            for i in range(len(spine)):
                v.append(spine[i] * (1 - t) + e2[i] * t + [0, off, 0])
        for j in range(rows - 1):
            for i in range(len(spine) - 1):
                a = base + j * len(spine) + i
                q = [a, a + 1, a + 1 + len(spine), a + len(spine)]
                f.append(q if lay == 0 else q[::-1])
    p = Piece("wing" + side, "ice-wing", np.array(v), f)
    if s < 0:
        p.f = [q[::-1] for q in p.f]
    p.spine, p.tips, p.wrist = spine, tips, wrist
    rod = sweep("wingarm" + side, "ice-wing", spine, SEC6, 0.0125 * (1 - np.linspace(0, 1, 9)) ** 0.5 + 0.003, side_hint=np.array([0, 1.0, 0]))
    rods = [rod]
    for i, t_ in enumerate(tips[1:4]):
        path = catmull([wrist, (wrist + t_) / 2 + [0, 0, 0.012], t_], 4)
        rods.append(sweep("wingrod%d%s" % (i, side), "ice-wing", path, SEC6[::2], np.array([0.006, 0.005, 0.004, 0.0015]), side_hint=np.array([0, 1.0, 0])))
    return p, rods


def wing_points(s):
    return [np.array([s * 0.075, -0.155, 1.235]), np.array([s * 0.185, -0.205, 1.415]), np.array([s * 0.31, -0.235, 1.41]), np.array([s * 0.495, -0.26, 1.285])]


# ---- the heart-tipped tail
TAIL_N = 7


def tail():
    pts = [(0.0, -0.075, 0.965), (-0.012, -0.205, 0.83), (-0.03, -0.275, 0.66), (-0.075, -0.31, 0.5), (-0.145, -0.315, 0.37), (-0.235, -0.285, 0.28), (-0.30, -0.235, 0.255)]
    path = catmull(pts, 22)
    wd = np.linspace(0.0185, 0.0075, 22)
    p = sweep("tail", "skin-body", path, SEC6, wd, side_hint=np.array([0, 0, 1.0]))
    p.path = path
    return p


def heart_outline(n=9):
    """A heart in (across, along), the point at along=-1.. tip end; lobes toward +."""
    t = np.linspace(0, np.pi, n)
    x = np.sin(t) ** 3
    y = (13 * np.cos(t) - 5 * np.cos(2 * t) - 2 * np.cos(3 * t) - np.cos(4 * t)) / 16.0
    return np.stack([x, y], 1)


def heart_solid(name, mat, c, along, across, size, th):
    """A faceted heart: an outline ring and a raised middle on both faces. along: from the lobes' notch toward the point."""
    along, across = norm(along), norm(across)
    nrm = norm(np.cross(across, along))
    h = heart_outline()
    ring = list(h) + [(-x, y) for x, y in h[::-1][1:-1]]
    v = [c + across * x * size - along * y * size for x, y in ring]
    n = len(v)
    mid = c - along * (-0.05) * size
    v.append(mid + nrm * th)
    v.append(mid - nrm * th)
    f = []
    for i in range(n):
        f.append([i, (i + 1) % n, n])
        f.append([(i + 1) % n, i, n + 1])
    return Piece(name, mat, np.array(v), f)


# ---- the big bow at the small of her back, with long ribbons past the hem
BOW_Z = 1.0
BT_N = 4
BOW_Y = -0.145


def bow():
    out = []
    knot = np.array([0, BOW_Y - 0.035, BOW_Z])
    kn = sweep("bowknot", "cloth-dress", [knot + [0, 0, 0.042], knot + [0, -0.012, 0.018], knot + [0, -0.016, -0.018], knot + [0, 0, -0.042]], SEC8, np.array([0.03, 0.044, 0.044, 0.03]), side_hint=np.array([1.0, 0, 0]), depth=np.array([0.018, 0.028, 0.028, 0.018]))
    out.append(kn.rigid("root"))
    for s in (1.0, -1.0):
        side = "R" if s > 0 else "L"
        # a loop: a flat ribbon out and back
        t = np.linspace(0, 2 * np.pi, 15)
        path = np.stack([s * (0.09 - 0.082 * np.cos(t)), BOW_Y - 0.03 - 0.006 * np.sin(t) - 0.014 * (1 - np.cos(t)), BOW_Z + 0.008 + 0.046 * np.sin(t) + 0.016 * (1 - np.cos(t))], 1)
        wd = 0.042 + 0.024 * (1 - np.cos(t)) * 0.5
        lp = sweep("bowloop" + side, "cloth-dress", path, [(-1, 0), (-0.3, 0.13), (0.3, 0.13), (1, 0), (0.3, -0.13), (-0.3, -0.13)], wd, side_hint=np.array([1.0, 0, 0.0]), depth=wd)
        out.append(lp.rigid("root"))
    return out


def ribbon(s):
    side = "R" if s > 0 else "L"
    pts = [(s * 0.02, BOW_Y - 0.03, BOW_Z - 0.02), (s * 0.075, BOW_Y - 0.062, BOW_Z - 0.13), (s * 0.13, BOW_Y - 0.10, BOW_Z - 0.27), (s * 0.165, BOW_Y - 0.125, BOW_Z - 0.38), (s * 0.195, BOW_Y - 0.15, BOW_Z - 0.50)]
    path = catmull(pts, 10)
    u = np.linspace(0, 1, 10)
    wd = 0.03 + 0.042 * smooth(0, 0.8, u)
    sh = np.array([0.0, 1.0, 0.0])
    p = sweep("ribbon" + side, "cloth-dress", path, [(-1, 0), (-0.35, 0.08), (0.35, 0.08), (1, 0), (0.35, -0.08), (-0.35, -0.08)], wd, side_hint=sh, depth=wd)
    # the swallowtail: the last ring's middle pulled up
    m = len(FLAT)
    last = (len(path) - 1) * m
    for j in (1, 2, 4, 5):
        p.v[last + j] += norm(path[-3] - path[-1]) * 0.05
    p.path = path
    return p


def ribbon_points(p):
    return [tuple(p.path[int(round(t * (len(p.path) - 1)))]) for t in np.linspace(0.0, 1.0, BT_N)]


# ---- ice blades
def blade(s):
    """A runner with a rocker, a toe pick, two open stanchions up to the sole. One outline, cut into panels so the gaps are real."""
    side = "R" if s > 0 else "L"
    x0 = s * THIGH_X
    pos = []
    f = []
    th = 0.0062

    def plate(name_pts):
        b = len(pos)
        n = len(name_pts)
        for yy, zz in name_pts:
            pos.append((x0 + th, yy, zz))
        for yy, zz in name_pts:
            pos.append((x0 - th, yy, zz))
        f.append(list(range(b, b + n)))
        f.append(list(range(b + 2 * n - 1, b + n - 1, -1)))
        for i in range(n):
            j = (i + 1) % n
            f.append([b + j, b + i, b + n + i, b + n + j])
    # the runner: heel to toe, along the ice
    run = [(-0.165, 0.016), (-0.14, 0.0), (0.0, -0.0), (0.135, 0.002), (0.19, 0.024), (0.205, 0.05), (0.175, 0.034), (0.13, 0.024), (0.0, 0.021), (-0.14, 0.023)]
    plate(run)
    plate([(0.095, 0.022), (0.125, 0.022), (0.115, SOLE_Z + 0.004), (0.045, SOLE_Z + 0.004)])       # the front stanchion
    plate([(-0.105, 0.022), (-0.07, 0.022), (-0.035, SOLE_Z + 0.004), (-0.11, SOLE_Z + 0.004)])      # the back
    tris = []
    for q in f:
        for k in range(1, len(q) - 1):
            tris.append([q[0], q[k], q[k + 1]])
    return Piece("blade" + side, "ice-bright", np.array(pos), tris).rigid("foot." + side)


# ---- the spear: candy-cane shaft, a heart guard, a long crystal head, a spike at the butt
TIP_U, BUTT_U = 1.05, -0.845
HILT_L = 0.34


def sp(u, w=0.0, n=0.0):
    """A point on the spear in the rest pose: u along the shaft from the grip, w across its flat, n out of it."""
    return GRIP_AT + GRIP_K * u + np.array([0, 0, 1.0]) * w + np.array([1.0, 0, 0]) * n


def spear():
    out = []
    us = np.linspace(-0.66, 0.60, 14)
    path = [sp(u) for u in us]
    shaft = sweep("shaft", "cloth-dress", path, SEC8, np.full(14, SHAFT_R), side_hint=np.array([0, 0, 1.0]))
    out.append(shaft)

    def spike(name, u0, u1, w0, n0, mids, mat="ice-bright"):
        """A crystal: rings of a four-sided section down its length. mids: (u fraction, width k)."""
        sec = [(1, 0), (0, 1), (-1, 0), (0, -1)]
        pts = [(u0, w0)] + [(u0 + (u1 - u0) * a, w0 * b) for a, b in mids] + [(u1, 0.0015)]
        p_ = [sp(u) for u, _ in pts]
        wd = np.array([w for _, w in pts])
        dp = wd * n0 / w0
        return sweep(name, mat, p_, sec, wd, side_hint=np.array([0, 0, 1.0]), depth=dp)
    out.append(spike("head", 0.745, TIP_U, 0.05, 0.016, [(0.12, 1.2), (0.3, 0.9), (0.42, 0.72)]))
    out.append(spike("butt", -0.665, BUTT_U, 0.034, 0.014, [(0.15, 1.0), (0.42, 0.82)]))
    for nm, u in (("collarA", 0.6), ("collarB", -0.66)):
        out.append(sweep(nm, "ice-horn", [sp(u - 0.012), sp(u), sp(u + 0.012)], SEC8, np.array([0.015, 0.0205, 0.015]), side_hint=np.array([0, 0, 1.0])))
    h = heart_solid("heart", "ice-bright", sp(0.683), -GRIP_K, np.array([0, 0, 1.0]), 0.082, 0.021)
    out.append(h)
    h2 = heart_solid("heartcore", "ice-bright", sp(0.68, 0, 0.0005), -GRIP_K, np.array([0, 0, 1.0]), 0.05, 0.03)
    out.append(h2)
    for s in (1.0, -1.0):        # the two icicles off the guard
        out.append(spike("prong" + ("R" if s > 0 else "L"), 0.665, 0.665, 0.01, 0.01, [(0.5, 0.8)]) if False else
                   sweep("prong" + ("R" if s > 0 else "L"), "ice-bright", [sp(0.70, s * 0.078), sp(0.655, s * 0.087), sp(0.585, s * 0.09)], [(1, 0), (0, 1), (-1, 0), (0, -1)], np.array([0.012, 0.009, 0.001]), side_hint=np.array([1.0, 0, 0])))
    for q in out:
        q.rigid("hand.R")
    return out


def spear_frame():
    return tuple(GRIP_K), (0.0, 0.0, 1.0)


GRIP_AT_T = tuple(GRIP_AT)
