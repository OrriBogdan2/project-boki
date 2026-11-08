"""ART-1 Sable v2: the rebuilt pieces as data: fingerless gloved hands round twin flintlocks, fuzzy moth antennae, the one long white braid, the long coat's split panels and violet lining, the moth wings
under them, the hip sheaths and their moth-curved knives, the belt's keys and tiny bell, the gem and midriff chains, the upper lids, the skull's back. The body, front hair and face are the scan's (sable_source.py).
Blender frame: Z up, she faces +Y, her right hand is +X. Budget: <=15k tris incl. both pistols, <=8 materials. Measures: briefs/art-refs/sable_v2 (turnaround FINAL; master sheet for detail)."""
import json, os
import numpy as np
from meshkit import Piece, catmull, norm, smooth, sweep, frames, rot_about

HERE = os.path.dirname(os.path.abspath(__file__))
_rig = json.load(open(os.path.join(HERE, "..", "..", "art", "wardens", "src", "sable_rig.json")))["bones"]


def J(b):
    x, y, z = _rig[b]["head"]
    return np.array([x, -z, y], float)


SH, THIGH_X = J("upper_arm.R")[0], J("thigh.R")[0]
SHOULDER_Z, ELBOW_Z, HAND_Z, NECK_Z, HIPS_Z = J("upper_arm.R")[2], J("forearm.R")[2], J("hand.R")[2], J("head")[2], J("hips")[2]
THIGH_Z = J("thigh.R")[2]
ANKLE_Z, SOLE_Z = 0.145, 0.0
HK = 0.92                                      # the scan's head scale (sable_source.py sets it)
SEC4 = [(1, 0), (0, 1), (-1, 0), (0, -1)]
SEC6 = [(np.cos(t), np.sin(t)) for t in np.linspace(0, 2 * np.pi, 6, endpoint=False)]
SEC8 = [(np.cos(t), np.sin(t)) for t in np.linspace(0, 2 * np.pi, 8, endpoint=False)]
ARM = {"R": 1.0, "L": -1.0}
S_NECK = 1.60                                  # the scan's neck z (sable_source.py)


def hs(p):
    """The scan's head (its metres, sole at 0) -> rig."""
    return np.array([0, 0, NECK_Z]) + (np.asarray(p, float) - [0, 0, S_NECK]) * HK


# ---- the eyes and mouth, on the scan (measured off the grid renders)
EYE = np.array([0.040, 0.058, 1.574])         # rig space, read off the fitted head (x from the face's centre line)
EYE_W, EYE_H = 0.0228, 0.0137
BROW = np.array([0.05, 0.055, 1.60])
MOUTH = np.array([0.03, 0.08, 1.512])
MARK = np.array([0.060, 0.03, 1.548])          # the one beauty mark, on her right cheek (the scan's is a smudge: cleaned and redrawn)
FACE_X = 0.001


def eye_c(s):
    return EYE * [s, 1, 1] + [FACE_X, 0, 0]


# ---- hands: a leather palm, bare lilac fingers (the master's fingerless gloves); each closes on its pistol's grip
def wrist(side):
    return np.array([ARM[side] * SH, 0.0, HAND_Z + 0.012])


def grip(side):
    """The fist's hole, rest pose: a point the pistol's grip runs through."""
    return wrist(side) + np.array([0, 0, -0.078]) + np.array([-ARM[side] * 0.022, 0.0, 0.0])


def hand(side):
    s = ARM[side]
    w = wrist(side)
    k = np.array([0, 1.0, 0])                  # the knuckle line, first finger first
    a = np.array([0, 0, -1.0])
    o = np.array([s, 0, 0.0])
    curl = (1.3, 1.45, 0.95)
    knuck = w + a * 0.07
    centre = [w - a * 0.022, w + a * 0.024, w + a * 0.052, knuck]
    width = np.array([0.027, 0.034, 0.039, 0.037])
    depth = np.array([0.024, 0.0205, 0.0195, 0.0165])
    palm = sweep("palm" + side, "leather-dark", centre, SEC8, width, side_hint=o, depth=depth)
    t_, s_, n_ = frames(np.asarray(centre), o)
    for i in range(len(centre)):
        for j in range(8):
            d = palm.v[i * 8 + j] - centre[i]
            x = np.dot(d, s_[i]) / width[i]
            y = np.dot(d, n_[i]) / depth[i]
            palm.v[i * 8 + j] = centre[i] + k * x * width[i] + o * y * depth[i]
    out = [palm.rigid("hand." + side)]
    lens = [(0.030, 0.021, 0.019), (0.033, 0.023, 0.020), (0.031, 0.022, 0.019), (0.025, 0.017, 0.016)]
    rads = [0.0088, 0.0092, 0.0087, 0.0077]
    for f in range(4):
        base = knuck + k * (0.0275 - f * 0.0183) + o * 0.003
        p = [base - a * 0.01, base.copy()]
        cur = base.copy()
        ang = 0.0
        for jn in range(3):
            ang += curl[jn]
            sign = 1.0 if np.dot(np.cross(k, a), o) < 0 else -1.0
            dd = rot_about(a, k, ang * sign)
            cur = cur + dd * lens[f][jn]
            p.append(cur.copy())
        p = np.array(p)
        wd = np.array([1.0, 1.02, 1.0, 0.92, 0.76]) * rads[f]
        out.append(sweep("finger%d%s" % (f, side), "skin-face", p, SEC6, wd, side_hint=k).rigid("hand." + side))
    base = w + a * 0.022 + k * 0.036 - o * 0.006
    t1 = base + norm(a * 0.72 + k * 0.42 - o * 0.5) * 0.031
    t2 = t1 + norm(a * 0.9 + k * 0.05 - o * 0.45) * 0.024
    t3 = t2 + norm(a * 0.9 - k * 0.35 - o * 0.2) * 0.02
    out.append(sweep("thumb" + side, "skin-face", [base - a * 0.008, t1, t2, t3], SEC6, np.array([0.015, 0.0115, 0.0095, 0.008]), side_hint=o).rigid("hand." + side))
    return out


# ---- the twin flintlocks. Rest: hanging at her thighs, muzzle down (the master's back view), the lock's top toward +Y. p(u along the barrel, v up to the lock, w across)
B_REST, U_REST = np.array([0, 0, -1.0]), np.array([0, 1.0, 0])
MUZZLE_U = 0.335


def P_at(side):
    g = grip(side)

    def p(u, v=0.0, w=0.0):
        return g + B_REST * u + U_REST * v + np.array([ARM[side], 0, 0]) * w
    return p


def pistol(side):
    p = P_at(side)
    bone = "hand." + side
    x_ = np.array([1.0, 0, 0])
    out = []
    BV = 0.052                              # the barrel's height over the fist
    # the barrel: octagonal, a ring at the breech and mid-way, flaring to a bell mouth
    us = [-0.030, 0.0, 0.11, 0.12, 0.13, 0.25, 0.30, 0.325, MUZZLE_U]
    rs = [0.0235, 0.0218, 0.0208, 0.0245, 0.0208, 0.0199, 0.0245, 0.0334, 0.038]       # the bell mouth .038 (the sheet)
    out.append(sweep("barrel" + side, "metal-silver", [p(u, BV) for u in us], SEC8, np.array(rs), side_hint=x_, tip=False))
    # the mouth's glowing plug
    m0, m1 = p(MUZZLE_U - 0.012, BV), p(MUZZLE_U + 0.001, BV)
    out.append(sweep("mouth" + side, "glow-rune", [m0, m1, m1 + (m1 - m0) * 0.01], SEC8, np.array([0.03, 0.03, 0.001]), side_hint=x_))
    # the ramrod under the barrel
    out.append(sweep("rod" + side, "metal-silver", [p(u, BV - 0.037) for u in (0.11, 0.25, 0.29, 0.30)], SEC6[::2], np.array([0.0055, 0.0055, 0.0085, 0.006]), side_hint=x_))
    # stock: the forestock under the barrel, the wrist through the fist, the swelling butt; flattened sideways
    path = catmull([p(0.235, BV - 0.015), p(0.12, BV - 0.015), p(0.03, BV - 0.012), p(0.0, 0.02), p(-0.005, -0.02), p(-0.03, -0.065), p(-0.075, -0.098)], 12)
    wd = np.array([0.013, 0.017, 0.019, 0.021, 0.0215, 0.022, 0.0215, 0.022, 0.024, 0.027, 0.030, 0.030]) * 1.2
    dp = np.array([0.012, 0.019, 0.021, 0.024, 0.024, 0.026, 0.024, 0.024, 0.026, 0.030, 0.034, 0.030]) * 1.25
    out.append(sweep("stock" + side, "leather-dark", path, SEC8, wd, side_hint=x_, depth=dp))
    # the butt cap
    c = path[-1]
    d = norm(path[-1] - path[-2])
    out.append(sweep("cap" + side, "metal-silver", [c - d * 0.016, c, c + d * 0.012, c + d * 0.024], SEC8, np.array([0.034, 0.038, 0.033, 0.0008]), side_hint=x_))
    # lock plate, cock, frizzen: on her outer side, chunky so they read
    lock = sweep("lock" + side, "metal-silver", [p(-0.04, BV - 0.012, 0.024), p(0.0, BV - 0.012, 0.024), p(0.05, BV - 0.012, 0.024), p(0.07, BV - 0.012, 0.024)], SEC4, np.array([0.015, 0.02, 0.018, 0.008]), side_hint=x_ * 0 + U_REST, depth=np.full(4, 0.006))
    out.append(lock)
    cock = sweep("cock" + side, "metal-silver", catmull([p(-0.03, BV + 0.008, 0.016), p(-0.046, BV + 0.042, 0.016), p(-0.018, BV + 0.06, 0.016), p(0.002, BV + 0.054, 0.016)], 5), SEC4, np.array([0.009, 0.0075, 0.007, 0.0075, 0.008]), side_hint=x_, depth=np.full(5, 0.0055))
    out.append(cock)
    out.append(sweep("frizzen" + side, "metal-silver", catmull([p(0.05, BV + 0.012, 0.014), p(0.035, BV + 0.04, 0.014), p(0.017, BV + 0.05, 0.014)], 4), SEC4, np.array([0.011, 0.011, 0.012, 0.009]), side_hint=x_, depth=np.full(4, 0.005)))
    # the violet crystal in the cock's jaws
    cc = p(0.007, BV + 0.058, 0.016)
    out.append(gem_piece("crystal" + side, cc, 0.0165, 0.012, U_REST))
    # trigger guard
    th = np.linspace(0.15, np.pi - 0.15, 8)
    g0 = p(0.045, 0.0)
    guard = np.array([g0 + B_REST * (0.045 * np.cos(t)) + U_REST * (0.03 - 0.05 * np.sin(t)) for t in th])
    out.append(sweep("guard" + side, "metal-silver", guard, SEC4, np.full(8, 0.0042), side_hint=x_))
    # runes: a raised strip on each flank and on top of the barrel, painted with glyphs (bright on dark) in the glow slot
    for nm, w, n_ in (("runeA", 0.0222, x_), ("runeB", -0.0222, -x_)):
        a0, a1 = 0.135, 0.285
        c0, c1 = p(a0, BV, w), p(a1, BV, w)
        hv = U_REST * 0.0098
        q = [c0 - hv + n_ * 0.0012, c0 + hv + n_ * 0.0012, c1 + hv + n_ * 0.0012, c1 - hv + n_ * 0.0012]
        pc = Piece(nm + side, "glow-rune", np.array(q), [[0, 1, 2, 3]])
        pc.rune = (a0, a1)
        out.append(pc)
    # ... and one along the top, the side the match camera sees
    a0, a1 = 0.135, 0.285
    hw = x_ * 0.0098
    tn = U_REST * (0.0222 + 0.0012)
    c0, c1 = p(a0, BV), p(a1, BV)
    out.append(Piece("runeC" + side, "glow-rune", np.array([c0 + tn + hw * ARM[side], c0 + tn - hw * ARM[side], c1 + tn - hw * ARM[side], c1 + tn + hw * ARM[side]]), [[0, 1, 2, 3]]))
    for q in out:
        q.rigid(bone)
    return out


def gem_piece(name, c, h, w, up):
    """A cut crystal: a girdle and two points."""
    up = norm(up)
    a = norm(np.cross(up, (0.31, 0.2, 0.93)))
    b = np.cross(up, a)
    v = [np.asarray(c) + up * h, np.asarray(c) - up * h * 1.3]
    for i in range(6):
        t = i / 6 * 2 * np.pi
        v.append(np.asarray(c) + up * h * 0.25 + (a * np.cos(t) + b * np.sin(t)) * w)
    f = []
    for i in range(6):
        j = (i + 1) % 6
        f.append([0, 2 + i, 2 + j])
        f.append([1, 2 + j, 2 + i])
    return Piece(name, "glow-rune", np.array(v), f)


# ---- the antennae: feather plumes in a V off the hairline (the turnaround's front view): a thin dark stem with dusty lilac fuzz combed out on BOTH sides,
# narrow at the root, widest past the middle, to a point. Two sheets back to back, one bone each.
ANT_N = 2
ANT_RINGS = 13                                 # 5 verts a ring, 2 sheets: 192 tris an antenna (the budget's share)


def antenna(s):
    side = "R" if s > 0 else "L"
    top = hs([0, 0, 1.857])[2]
    pts = np.array([(0.03, 0.062, top - 0.05), (0.052, 0.052, top + 0.01), (0.082, 0.034, top + 0.08), (0.112, 0.012, top + 0.15), (0.135, -0.012, top + 0.215)]) * [s, 1, 1]
    n = ANT_RINGS
    path = catmull(pts, n)
    u = np.linspace(0, 1, n)
    t_ = norm(np.gradient(path, axis=0))
    side_v = norm(np.cross(t_, np.array([0, 1.0, 0])))                # across the plume, in her front plane
    side_v = side_v * np.sign(side_v[n // 2, 0] * s)                   # +side_v points out, away from her midline
    # (the plumes stay square to her front: tipped back about their stems they faced apart, and the one turned from the sun went black)
    nrm = norm(np.cross(side_v, t_))
    half = 0.036 * smooth(0.1, 0.55, u) * smooth(1.0, 0.7, u) + 0.0025      # the fuzz either side of the stem
    barb = np.array([1.0 if i % 2 == 0 else 0.82 for i in range(n)])     # the feather's notched edge
    ks = (-1.0, -0.45, 0.0, 0.45, 1.0)
    v, f = [], []
    for lay, off in ((0, 0.0025), (1, -0.0025)):
        base = len(v)
        for i in range(n):
            lean = t_[i] * (0.025 * smooth(0.2, 0.6, u[i]))              # the barbs comb toward the tip
            for k in ks:
                edge = abs(k) > 0.9
                v.append(path[i] + side_v[i] * half[i] * k * (barb[i] if edge else 1.0) + lean * abs(k) + nrm[i] * off * (1.0 if edge or k == 0 else 1.6))
        for i in range(n - 1):
            for r in range(len(ks) - 1):
                a = base + i * len(ks) + r
                q = [a, a + 1, a + len(ks) + 1, a + len(ks)]
                f.append(q if lay == 0 else q[::-1])
    p = Piece("antenna" + side, "fur-feather", np.array(v), f)
    a_, b_, c_ = (p.v[f[len(f) // 8][i]] for i in (0, 1, 2))
    if np.dot(np.cross(b_ - a_, c_ - a_), nrm[n // 4]) < 0:    # each sheet faces away from its twin (the body shader culls back faces)
        p.f = [q[::-1] for q in p.f]
    p.path, p.u = path, u
    return p


def antenna_points(p):
    return [tuple(p.path[int(round(t * (len(p.path) - 1)))]) for t in np.linspace(0.08, 1.0, ANT_N)]


# ---- the one braid: fat lobes in a zigzag, two lilac ties, a soft tuft. It leaves the nape over the collar and falls behind her right arm to the hip (the turnaround's back view, narrowed to the arm's rest).
BRAID_N = 6


def braid():
    pts = np.array([(0.0, -0.1, 1.56), (0.012, -0.15, 1.50), (0.04, -0.172, 1.40), (0.075, -0.182, 1.28), (0.105, -0.188, 1.15), (0.13, -0.192, 1.035)])
    lobes = 11
    rings = lobes * 2 + 1
    path = catmull(pts, rings)
    u = np.linspace(0, 1, rings)
    wd = np.zeros(rings)
    offs = np.zeros(rings)
    for i in range(rings):
        ph = i / 2.0
        fr = ph - np.floor(ph)
        wd[i] = (0.034 - 0.008 * u[i]) * (0.92 + 0.08 * np.sin(fr * np.pi))      # a shallow pinch between lobes (deeper reads as beads)
        offs[i] = (1 if int(ph) % 2 else -1) * 0.0075 * np.sin(fr * np.pi)
    t, s_, n_ = frames(path, (1, 0, 0))
    centre = path + s_ * offs[:, None]
    p = sweep("braid", "hair-braid", centre, SEC6, wd, side_hint=np.array([1.0, 0, 0]), depth=wd * 0.86)
    p.path, p.u = path, u
    return p


def hairback():
    """The back of the skull, where the scan's buns were cut away: an ellipsoid fitted inside the scan's hair at the sides and shallow in front (so it never reaches her face or ears), tapering down the nape into the braid."""
    C, R, FRONT = np.array([0.0, -0.012, 1.63]), np.array([0.117, 0.113, 0.097]), 0.055
    rows = [(1.726, 0.1), (1.72, 0.3), (1.705, 0.55), (1.68, 0.8), (1.655, 0.94), (1.625, 1.0), (1.595, 0.93), (1.57, 0.82), (1.545, 0.62), (1.525, 0.4), (1.5, 0.34), (1.475, 0.26)]
    n = 16
    v, f = [], []
    for z, k in rows:
        for i in range(n):
            t = i / n * 2 * np.pi
            sn = np.sin(t)
            v.append((C[0] + np.cos(t) * R[0] * k, C[1] + sn * (FRONT if sn > 0 else R[1]) * k - 0.02 * smooth(1.6, 1.53, z), z))
    for r in range(len(rows) - 1):
        for i in range(n):
            j = (i + 1) % n
            f.append([r * n + i, (r + 1) * n + i, (r + 1) * n + j, r * n + j])
    f.append(list(range(n)))
    f.append([len(rows) * n - 1 - i for i in range(n)])
    return Piece("hairback", "hair-braid", np.array(v), f).rigid("head")


def braid_tie(p, at_u, name, rad):
    i = int(at_u * (len(p.path) - 2))
    a, b = p.path[i], p.path[i + 1]
    d = norm(b - a)
    c = (a + b) / 2
    return sweep(name, "hair-braid", [c - d * 0.018, c - d * 0.014, c + d * 0.014, c + d * 0.018], SEC8, np.array([rad * 0.82, rad, rad, rad * 0.82]), side_hint=np.array([1.0, 0, 0]))


def braid_tuft(p):
    e = p.path[-1]
    d = norm(p.path[-1] - p.path[-3])
    sd = norm(np.cross(d, (0, 1, 0)))
    path = catmull([e - d * 0.02, e + d * 0.04, e + d * 0.09 + sd * 0.01, e + d * 0.14 + sd * 0.03, e + d * 0.175 + sd * 0.06], 8)
    wd = np.array([0.016, 0.027, 0.034, 0.034, 0.029, 0.022, 0.012, 0.002])
    q = sweep("tuft", "hair-braid", path, SEC6, wd, side_hint=np.array([1.0, 0, 0]), depth=wd * 0.6)
    q.path = path
    return q


# ---- the long coat: two panels from the jacket's hem. The back stays closed under the belt, then the split opens in a curve all the way to the sharp corner at the side, over the wings;
# the front edge falls from the hip to the same corner (the turnaround's back view). Outer leather and a violet lining: two sheets back to back. On hips at the top, on 2 bones a chain below.
HEM_Z = 0.19
TAIL_ROWS, TAIL_COLS = 8, 9
SPLIT_T = (0.0, 0.24, 0.5, 0.72, 0.87, 1.0)     # the split's half width down the panel (metres at the hem's flare)
SPLIT_X = (0.0, 0.03, 0.095, 0.19, 0.28, 0.33)


def tail_grid(s, top_z=0.80, r0=(0.165, 0.128), cy=-0.012):
    """(rows, cols, 3): row 0 the top ring, col 0 the front edge, the last col the split."""
    G = np.zeros((TAIL_ROWS, TAIL_COLS, 3))
    for r in range(TAIL_ROWS):
        t = r / (TAIL_ROWS - 1)
        fl = 1.0 + 0.78 * t ** 1.3
        rx, ry = r0[0] * fl, r0[1] * fl
        a0 = np.radians(60 + 36 * t ** 1.4)
        a1 = max(np.pi - np.arcsin(min(np.interp(t, SPLIT_T, SPLIT_X) / rx, 1.0)), a0 + 0.02)
        for c in range(TAIL_COLS):
            k = c / (TAIL_COLS - 1)
            a = a0 + (a1 - a0) * k
            fold = 1 + 0.045 * t * np.cos(k * 13.0)                    # soft folds down the leather
            x, y = np.sin(a) * rx * fold, np.cos(a) * ry * fold + cy
            y -= 0.1 * t ** 1.5                                       # the rest shape leans back, so the panels read from above
            G[r, c] = (s * x, y, top_z - (top_z - HEM_Z) * t)
    return G


def coat_tail(s, **kw):
    side = "R" if s > 0 else "L"
    G = tail_grid(s, **kw)
    R, C = G.shape[:2]
    idx = lambda r, c: r * C + c
    fo, fi = [], []
    for r in range(R - 1):
        for c in range(C - 1):
            q = [idx(r, c), idx(r, c + 1), idx(r + 1, c + 1), idx(r + 1, c)]
            fo.append(q if s > 0 else q[::-1])
            fi.append(q[::-1] if s > 0 else q)
    out = Piece("tail" + side, "leather-dark", G.reshape(-1, 3), fo)
    rr, cc = np.mgrid[0:R, 0:C]
    out.rowf, out.colf = (rr / (R - 1)).ravel(), (cc / (C - 1)).ravel()
    # the lining sits a hair inside: pushed toward the legs
    H = G.copy()
    centre = np.array([0, -0.02, 0.0])
    d = H - centre
    d[..., 2] = 0
    H -= norm(d) * 0.006
    inn = Piece("lining" + side, "cloth-coat", H.reshape(-1, 3), fi)
    inn.rowf, inn.colf = out.rowf, out.colf
    out.grid = G
    return out, inn


def tail_chain(G, col_u):
    """A chain of joints down the panel at col fraction col_u."""
    R, C = G.shape[:2]
    c = col_u * (C - 1)
    a, b = int(np.floor(c)), min(int(np.floor(c)) + 1, C - 1)
    q = c - a
    pts = G[:, a] * (1 - q) + G[:, b] * q
    idx = np.linspace(0, R - 1, 3).round().astype(int)
    return [tuple(pts[i]) for i in idx]


# ---- the moth wings: cards hanging from under the coat's split, on 2 bones (the card slot draws both sides). Outline and paint: the turnaround's back view (proj/wings.png, its crop flipped so x grows outward).
W_COLS = 6
WING_N = 3
W_PX = 0.00064                 # metres a pixel of that crop, at the rig's height below the belt
W_XR = 318.0                   # the pixel of her centre line
W_Y0 = 220.0                   # the crop's row at the wing's root
# the outline in that crop: row, inner x, outer x
W_EDGE = [(0, 328, 334), (80, 345, 362), (210, 354, 402), (380, 366, 500), (540, 377, 670), (580, 380, 655), (740, 430, 600), (870, 482, 555), (955, 515, 517)]
W_LEN = 955 * W_PX


def wing_plane(s):
    """Root (the centre line at the wing's top), along (down the wing), across (outward and forward), both in the wing's rest plane."""
    root = np.array([0, -0.118, 0.745])
    along = norm(np.array([0, -0.2, -0.98]))
    across = norm(np.array([s, 0.38, 0.0]))     # curving forward round the legs, under the panels
    return root, along, across


def wing(s):
    side = "R" if s > 0 else "L"
    root, along, across = wing_plane(s)
    normal = norm(np.cross(across, along))
    v, f = [], []
    for (y, xi, xo) in W_EDGE:
        for c in range(W_COLS):
            k = c / (W_COLS - 1)
            x = xi + (xo - xi) * k
            bow = 0.03 * np.sin(k * np.pi) * np.sin(min(y / W_EDGE[-1][0] * 1.2, 1) * np.pi)
            v.append(root + along * y * W_PX + across * (x - W_XR) * W_PX + normal * bow)
    for r in range(len(W_EDGE) - 1):
        for c in range(W_COLS - 1):
            q = r * W_COLS + c
            f.append([q, q + 1, q + 1 + W_COLS, q + W_COLS])
    p = Piece("wing" + side, "card-wing", np.array(v), f)
    p.root, p.along, p.across = root, along, across
    return p


def wing_points(s):
    root, along, across = wing_plane(s)
    return [tuple(root + along * W_LEN * t + across * (0.02 + 0.12 * t)) for t in np.linspace(0.0, 1.0, WING_N)]


# ---- the belt's hangers: keys and one tiny bell on a ring at her right hip, on a little hang chain
BELT_Z = 0.835


def hang_path(top, drop, n=3):
    top = np.asarray(top, float)
    return [tuple(top + np.array([0, 0, -drop * i / (n - 1)])) for i in range(n)]


def keys(top):
    top = np.asarray(top, float)
    out = []
    th = np.linspace(0, 2 * np.pi, 7)
    ring = np.array([top + np.array([0.021 * np.cos(t), 0.004, -0.021 - 0.021 * np.sin(t)]) for t in th])
    out.append(sweep("keyring", "metal-silver", ring, SEC4, np.full(7, 0.0036), side_hint=np.array([0, 1.0, 0]), tip=False))
    for i, a in enumerate((-0.32, 0.02)):
        d = np.array([np.sin(a), 0.0, -np.cos(a)])
        c0 = top + np.array([0.0, 0.004, -0.04])
        c1 = c0 + d * 0.105
        sh = sweep("keyshaft%d" % i, "metal-silver", [c0, c0 + d * 0.03, c1 - d * 0.02, c1], SEC4, np.array([0.0075, 0.0045, 0.0045, 0.0045]), side_hint=np.array([0, 1.0, 0]))
        out.append(sh)
        sd = np.array([np.cos(a), 0.0, np.sin(a)])
        out.append(sweep("keybit%d" % i, "metal-silver", [c1 - d * 0.03, c1 - d * 0.03 + sd * 0.022, c1 - d * 0.03 + sd * 0.024], SEC4, np.array([0.0085, 0.0085, 0.0001]), side_hint=np.array([0, 1.0, 0])))
    c = top + np.array([0.034, 0.006, -0.095])
    out.append(sweep("bellcord", "metal-silver", [top + np.array([0.012, 0.004, -0.04]), c + np.array([0, 0, 0.02])], SEC4, np.full(2, 0.0028), side_hint=np.array([0, 1.0, 0])))
    out.append(ball("bell", c, 0.019))
    return out


def ball(name, c, r):
    """A low sphere with a ridge: it reads as the sheet's banded weight once painted."""
    c = np.asarray(c, float)
    path = [c + np.array([0, 0, r * z]) for z in (1.0, 0.72, 0.0, -0.72, -1.0)]
    wd = np.array([0.001, 0.7, 1.03, 0.7, 0.001]) * r
    return sweep(name, "metal-silver", path, SEC8, wd, side_hint=np.array([1.0, 0, 0]))


# ---- the sheaths: a pair of knives on each hip, hilts up at the belt, the blades' moth-curved ends bare below the leather (turnaround). A knife is a little over a pistol's half on the sheet, 0.34 at the rig's scale.
KNIFE_TOP, KNIFE_TIP = np.array([0.172, 0.0, 0.955]), np.array([0.208, 0.0, 0.617])
KNIFE_Y = (0.05, 0.002)                        # the outer pair's depth, then the second, set a little shorter


def knife(s, k):
    tag = ("R" if s > 0 else "L") + str(k)
    y_ = np.array([0, KNIFE_Y[k], 0])
    a, b = KNIFE_TOP * [s, 1, 1] + y_, KNIFE_TIP * [s, 1, 1] + y_ + [0, 0, 0.05 * k]
    d = norm(b - a)
    L = np.linalg.norm(b - a)
    o = np.array([s, 0, 0.0])
    at = lambda t, off=0.0: a + d * (t * L) + o * off
    out = [sweep("pommel" + tag, "metal-silver", [at(-0.03), at(-0.02), at(0.01)], SEC6, np.array([0.002, 0.0145, 0.0125]), side_hint=o),
           sweep("hilt" + tag, "cloth-coat", [at(0.01), at(0.12), at(0.22)], SEC6, np.array([0.0125, 0.0115, 0.0125]), side_hint=o, depth=np.array([0.01, 0.0095, 0.01])),
           sweep("sheath" + tag, "leather-dark", [at(0.21), at(0.24), at(0.45), at(0.6, 0.003), at(0.65, 0.004)], SEC6, np.array([0.024, 0.031, 0.03, 0.025, 0.017]), side_hint=o, depth=np.array([0.014, 0.017, 0.016, 0.013, 0.009]))]
    # the blade: flat and leaf-wide, its back bowed out, its belly in a moth wing's curve to the point
    bow = catmull([at(0.58, 0.004), at(0.72, 0.012), at(0.87, 0.012), at(1.0, -0.014)], 6)
    wd = np.array([0.018, 0.026, 0.0265, 0.021, 0.012, 0.0012])
    out.append(sweep("blade" + tag, "metal-silver", bow, SEC4, wd, side_hint=o, depth=wd * 0.2))
    for q in out:
        q.rigid("hips")
    return out


def gem(y):
    """The pendant at the sternum: a silver kite round a cut crystal, on the scan's surface (y: its depth there). -> pieces, the stone's centre."""
    c = np.array([0, y + 0.012, 1.213])
    y_ = np.array([0, 1.0, 0])
    x = np.array([1.0, 0, 0])
    z = np.array([0, 0, 1.0])
    rim = [c + x * a + z * b for a, b in ((0, 0.044), (0.027, 0.0), (0, -0.052), (-0.027, 0.0), (0, 0.044))]
    out = [sweep("gemframe", "metal-silver", rim, SEC4, np.full(5, 0.0048), side_hint=y_, tip=False)]
    v = [q for q in rim[:-1]] + [c + y_ * 0.012, c - y_ * 0.008]
    f = []
    for i in range(4):
        j = (i + 1) % 4
        f.append([4, i, j])
        f.append([5, j, i])
    out.append(Piece("gemstone", "glow-rune", np.array(v), f))
    return out, c


# ---- the chains over the bare chest and midriff: (left stud, sag): the V up from the gem to the collar, then three swags from coat edge to coat edge
SWAGS = ((0.084, 1.114, 1.077), (0.08, 1.0675, 1.024), (0.082, 1.024, 0.9725))
COLLAR_STUD = (0.066, 1.333)


def swag(name, pts, room=0.004):
    return sweep(name, "metal-silver", pts, SEC4, np.full(len(pts), room), side_hint=np.array([0, 1.0, 0]))
