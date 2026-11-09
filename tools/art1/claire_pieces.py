"""ART-1 Claire (v2, the snow-bunny sheet): the rebuilt pieces as data: gloved hands, the rabbit ears (one upright, one folded), the small puff tail,
the braid with its snowflake clasp, the ice blades, the candy-cane spear. The body, hair and face are the scan's (claire_source.py).
Blender frame: Z up, she faces +Y, her right hand is +X. Recipe: /home/boki/shots-s2/art1/STYLE_NOTES.md."""
import json, os
import numpy as np
from mathutils import Vector
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


# ---- the eyes, on the scan (measured on its front and side orthos, 0.4 mm a pixel)
EYE = np.array([0.051, 0.086, 1.668])
EYE_W, EYE_H = 0.024, 0.018


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


# ---- rabbit ears (the sheet): her right one stands straight up, her left one rises a hand and folds out and down by the candy-cane bow.
# Rigid shells, cupped toward the front (the pink inside), each on a short chain: two skinned bones and a tip
EAR_N = 3
EAR_PATH = {1.0: [(0.062, -0.035, 1.775), (0.078, -0.04, 1.86), (0.092, -0.036, 1.96), (0.102, -0.03, 2.04), (0.106, -0.026, 2.085)],
            -1.0: [(-0.066, -0.035, 1.775), (-0.084, -0.04, 1.86), (-0.104, -0.034, 1.94), (-0.15, -0.02, 1.965), (-0.205, -0.008, 1.93), (-0.235, 0.0, 1.885)]}


def ear(s):
    side = "R" if s > 0 else "L"
    path = catmull(np.array([hs(q) for q in EAR_PATH[s]]), 13)
    u = np.linspace(0, 1, 13)
    wd = (0.016 + 0.03 * np.sin(np.clip(u * 1.05, 0, 1) * np.pi) ** 0.7) * HK
    wd[-1] = 0.004
    sec = [(-1, 0.0), (-0.6, -0.42), (0.0, -0.62), (0.6, -0.42), (1, 0.0), (0.6, 0.3), (0.0, 0.52), (-0.6, 0.3)]
    p = sweep("ear" + side, "fur-trim", path, sec, wd, side_hint=np.array([0.0, -1.0, 0.0]), depth=np.full(13, 0.013))   # (side = t x hint: the broad face fronts +y)
    p.path, p.u, p.wd = path, u, wd
    return p


def ear_points(p):
    return [tuple(p.path[int(round(t * (len(p.path) - 1)))]) for t in np.linspace(0.0, 1.0, EAR_N)]


# ---- the tail: a small round puff at the base of her back, about a fist (the owner: small); rigid on the pelvis
def tail_puff(c):
    v, f = [], []
    rows, cols = 7, 12
    for j in range(rows + 1):
        th = np.pi * j / rows
        for i in range(cols):
            ph = 2 * np.pi * i / cols
            d = np.array([np.sin(th) * np.cos(ph), np.sin(th) * np.sin(ph), np.cos(th)])
            r = 0.05 * (1 + 0.12 * np.sin(5 * ph + 3 * th) * np.sin(th))           # (tufted)
            v.append(c + d * r * [1.0, 0.9, 0.95])
    for j in range(rows):
        for i in range(cols):
            a, b = j * cols + i, j * cols + (i + 1) % cols
            f.append([a, b, b + cols, a + cols])
    p = Piece("tailpuff", "fur-trim", np.array(v), f)
    p.c = c
    return p.rigid("root")


# ---- the braid: one thick plait from behind her left ear over the shoulder and down the front past the sash, white to ice blue,
# the snowflake clasp near its end. Built in rig metres; claire_finish pushes it off the body. A spring chain on the head.
BRAID_N = 5


def braid(path):
    path = catmull(np.asarray(path, float), 26)
    u = np.linspace(0, 1, 26)
    wd = (0.034 - 0.012 * u) * (1 + 0.16 * np.abs(np.sin(u * np.pi * 11))) * smooth(1.0, 0.86, u) + 0.022 * smooth(0.84, 0.93, u) * smooth(1.0, 0.95, u)
    wd[-1] = 0.004
    p = sweep("braid", "fur-trim", path, SEC8, wd, side_hint=np.array([1.0, 0.0, 0.0]), depth=wd * 0.8)
    p.path, p.u = path, u
    return p


def braid_points(p):
    return [tuple(p.path[int(round(t * (len(p.path) - 1)))]) for t in np.linspace(0.0, 1.0, BRAID_N)]


def snowflake(c, nrm, up, r=0.034):
    """The clasp: a flat six-armed star, two faces, a little proud of the plait."""
    nrm, up = norm(nrm), norm(up)
    side = norm(np.cross(up, nrm))
    v, f = [], []
    for k in range(6):
        a = np.pi / 3 * k
        d = up * np.cos(a) + side * np.sin(a)
        e = up * np.cos(a + np.pi / 2) + side * np.sin(a + np.pi / 2)
        b = len(v)
        for off in (0.004, -0.004):
            v += [c + nrm * off + e * 0.006, c + nrm * off + d * r * 0.62 + e * 0.012, c + nrm * off + d * r, c + nrm * off + d * r * 0.62 - e * 0.012, c + nrm * off - e * 0.006]
        f.append([b, b + 1, b + 2, b + 3, b + 4])
        f.append([b + 9, b + 8, b + 7, b + 6, b + 5])
        for i in range(4):
            f.append([b + i + 1, b + i, b + 5 + i, b + 6 + i])
    return Piece("flake", "ice-wing", np.array(v), [t for q in f for t in ([q[0], q[k], q[k + 1]] for k in range(1, len(q) - 1))])


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


# ---- the skates (nivi_v2_weapon_sheet): the fluffy fur cuff round the boot top, candy-cane laces crossing up the instep
BOOT_X, BOOT_Y = 0.092, -0.03          # the shin's axis at the ankle (the scan's metres)
CUFF_Z, CUFF_R, CUFF_T = 0.265, 0.064, 0.03


def fur_cuff(side):
    """A fat tufted ring (tube of 16 x 6) round the boot top, on the shin."""
    sg = 1.0 if side == "R" else -1.0
    nm, nt = 16, 6
    v = []
    for i in range(nm):
        a = 2 * np.pi * i / nm
        tuft = 1.0 + 0.18 * np.sin(a * 5 + (1.3 if sg > 0 else 0.4))
        for j in range(nt):
            b = 2 * np.pi * j / nt
            r = CUFF_R + CUFF_T * tuft * np.cos(b)
            v.append([sg * BOOT_X + r * np.cos(a), BOOT_Y + r * np.sin(a), CUFF_Z + CUFF_T * 1.15 * tuft * np.sin(b)])
    f = [[i * nt + j, i * nt + (j + 1) % nt, ((i + 1) % nm) * nt + (j + 1) % nt, ((i + 1) % nm) * nt + j] for i in range(nm) for j in range(nt)]
    return Piece("bootcuff" + side, "fur-trim", np.array(v), f).rigid("shin." + side)


def candy_laces(side, tree):
    """Two strips cross at each of three levels up the instep (ray-cast onto the boot), candy-striped: crossed laces up to the cuff."""
    sg = 1.0 if side == "R" else -1.0
    out = []
    n = np.array([0.0, 1.0, 0.45])
    n = n / np.linalg.norm(n)

    def on_boot(t, dx):
        c = np.array([sg * BOOT_X + dx, 0.115 - 0.075 * t, 0.085 + 0.18 * t])
        h = tree.ray_cast(Vector(c + n * 0.12), Vector(-n), 0.3)
        return (np.array(h[0]) if h[0] is not None else c) + n * 0.004
    levels = np.linspace(0.0, 0.78, 4)
    for k in range(3):
        for flip in (1.0, -1.0):
            path = [on_boot(levels[k] + (levels[k + 1] - levels[k]) * u, flip * 0.028 * (1 - 2 * u)) for u in np.linspace(0, 1, 5)]
            out.append(sweep("lace%s%d%d" % (side, k, flip > 0), "fur-trim", path, SEC6, np.full(5, 0.0055), side_hint=np.array([1.0, 0, 0]), room=0.3)
                       .rigid("foot." + side))
    return out


# ---- the spear (the sheet's, 2.0 m against her 1.81 m to the crown): candy-cane shaft, a heart guard, a long crystal head, a spike at the butt
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
