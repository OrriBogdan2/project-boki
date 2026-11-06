"""ART-1 Sable: the rebuilt pieces as data: fingerless gloved hands round twin flintlocks, feathery moth antennae, the long white braid, the split coat tails
and their purple lining, the moth wings, the belt's keys, bola and gem, the upper lids. The body, hair cap and face are the scan's (sable_source.py).
Blender frame: Z up, she faces +Y, her right hand is +X. Budget: <=15k tris incl. both pistols, <=8 materials. Recipe: /home/boki/shots-s2/art1/STYLE_NOTES.md."""
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
EYE = np.array([0.045, 0.094, 1.607])         # rig space, read off the fitted head (x from the face's centre line)
EYE_W, EYE_H = 0.0295, 0.0125
BROW = np.array([0.04, 0.097, 1.632])
MOUTH = np.array([0.023, 0.113, 1.536])
MARK_OFF = np.array([-0.058, 0.074, 1.575])    # the scan's second beauty mark, painted out: the master has one, on her right cheek
MARK_ON = np.array([0.058, 0.074, 1.577])
FACE_X = 0.002


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
    rs = [0.019, 0.0175, 0.0165, 0.0195, 0.0165, 0.0160, 0.0195, 0.027, 0.0305]
    out.append(sweep("barrel" + side, "metal-silver", [p(u, BV) for u in us], SEC8, np.array(rs), side_hint=x_, tip=False))
    # the mouth's glowing plug
    m0, m1 = p(MUZZLE_U - 0.012, BV), p(MUZZLE_U + 0.001, BV)
    out.append(sweep("mouth" + side, "glow-rune", [m0, m1, m1 + (m1 - m0) * 0.01], SEC8, np.array([0.024, 0.024, 0.001]), side_hint=x_))
    # the ramrod under the barrel
    out.append(sweep("rod" + side, "metal-silver", [p(u, BV - 0.031) for u in (0.11, 0.25, 0.29, 0.30)], SEC6[::2], np.array([0.0055, 0.0055, 0.0085, 0.006]), side_hint=x_))
    # stock: the forestock under the barrel, the wrist through the fist, the swelling butt; flattened sideways
    path = catmull([p(0.235, BV - 0.015), p(0.12, BV - 0.015), p(0.03, BV - 0.012), p(0.0, 0.02), p(-0.005, -0.02), p(-0.03, -0.065), p(-0.075, -0.098)], 12)
    wd = np.array([0.013, 0.017, 0.019, 0.021, 0.0215, 0.022, 0.0215, 0.022, 0.024, 0.027, 0.030, 0.030])
    dp = np.array([0.012, 0.019, 0.021, 0.024, 0.024, 0.026, 0.024, 0.024, 0.026, 0.030, 0.034, 0.030])
    out.append(sweep("stock" + side, "leather-dark", path, SEC8, wd, side_hint=x_, depth=dp))
    # the butt cap
    c = path[-1]
    d = norm(path[-1] - path[-2])
    out.append(sweep("cap" + side, "metal-silver", [c - d * 0.016, c, c + d * 0.012, c + d * 0.024], SEC8, np.array([0.028, 0.031, 0.027, 0.0008]), side_hint=x_))
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
    for nm, w, n_ in (("runeA", 0.0165, x_), ("runeB", -0.0165, -x_)):
        a0, a1 = 0.135, 0.285
        c0, c1 = p(a0, BV, w), p(a1, BV, w)
        hv = U_REST * 0.0078
        q = [c0 - hv + n_ * 0.0012, c0 + hv + n_ * 0.0012, c1 + hv + n_ * 0.0012, c1 - hv + n_ * 0.0012]
        pc = Piece(nm + side, "glow-rune", np.array(q), [[0, 1, 2, 3]])
        pc.rune = (a0, a1)
        out.append(pc)
    # ... and one along the top, the side the match camera sees
    a0, a1 = 0.135, 0.285
    hw = x_ * 0.0078
    tn = U_REST * (0.0165 + 0.0012)
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


# ---- the antennae: a thin stem off the hairline, then one big feather sweeping out and up, barbed along its lower edge. Two sheets back to back.
ANT_N = 4


def antenna(s):
    side = "R" if s > 0 else "L"
    top = hs([0, 0, 1.87])[2]
    pts = np.array([(0.030, 0.036, top - 0.02), (0.05, 0.018, top + 0.05), (0.09, 0.0, top + 0.115), (0.15, -0.012, top + 0.16), (0.205, -0.018, top + 0.225), (0.232, -0.018, top + 0.335)]) * [s, 1, 1]
    n = 11
    path = catmull(pts, n)
    u = np.linspace(0, 1, n)
    t_ = norm(np.gradient(path, axis=0))
    side_v = norm(np.cross(t_, np.array([0, 1.0, 0])))                # in her front plane
    if side_v[n // 2, 2] > 0:
        side_v = -side_v                                               # the barbs point out and down
    wd = 0.082 * smooth(0.16, 0.5, u) * smooth(1.0, 0.7, u) + 0.0055
    up_w = 0.012 * smooth(0.25, 0.6, u) * smooth(1.0, 0.8, u) + 0.003
    v, f = [], []
    barb = np.array([1.0 if i % 2 == 0 else 0.76 for i in range(n)])     # the feather's notched edge
    rows = 3
    for lay, off in ((0, 0.0028), (1, -0.0028)):
        base = len(v)
        for i in range(n):
            lean = t_[i] * (0.03 * smooth(0.25, 0.6, u[i]))              # the barbs comb toward the tip
            v.append(path[i] - side_v[i] * up_w[i] + [0, off, 0])
            v.append(path[i] + side_v[i] * wd[i] * 0.45 + lean * 0.5 + [0, off * 1.6, 0])
            v.append(path[i] + side_v[i] * wd[i] * barb[i] + lean + [0, off, 0])
        for i in range(n - 1):
            for r in range(rows - 1):
                a = base + i * rows + r
                q = [a, a + 1, a + rows + 1, a + rows]
                f.append(q if lay == 0 else q[::-1])
    p = Piece("antenna" + side, "fur-feather", np.array(v), f)
    # the front sheet winds toward the front (+y), its twin away
    a_, b_, c_ = (p.v[f[len(f) // 8][i]] for i in (0, 1, 2))
    if np.cross(b_ - a_, c_ - a_)[1] < 0:
        p.f = [q[::-1] for q in p.f]
    p.path, p.u = path, u
    return p


def antenna_points(p):
    return [tuple(p.path[int(round(t * (len(p.path) - 1)))]) for t in np.linspace(0.08, 1.0, ANT_N)]


# ---- the braid: fat lobes laid in a zigzag, two ties, a soft tuft. It leaves the nape and swings out behind her right side so the camera sees it.
BRAID_N = 7


def braid():
    n0 = NECK_Z
    pts = np.array([(0.0, -0.075, n0 + 0.075), (0.012, -0.112, n0 - 0.02), (0.05, -0.150, n0 - 0.16), (0.108, -0.175, n0 - 0.30), (0.168, -0.195, n0 - 0.44), (0.205, -0.21, n0 - 0.56), (0.222, -0.22, n0 - 0.64)])
    lobes = 9
    rings = lobes * 3 + 1
    path = catmull(pts, rings)
    u = np.linspace(0, 1, rings)
    wd = np.zeros(rings)
    offs = np.zeros(rings)
    for i in range(rings):
        ph = i / 3.0
        fr = ph - np.floor(ph)
        wd[i] = (0.044 - 0.014 * u[i]) * (0.74 + 0.26 * np.sin(fr * np.pi))
        offs[i] = (1 if int(ph) % 2 else -1) * 0.011 * np.sin(fr * np.pi)
    t, s_, n_ = frames(path, (1, 0, 0))
    centre = path + s_ * offs[:, None]
    p = sweep("braid", "hair-braid", centre, SEC6, wd, side_hint=np.array([1.0, 0, 0]), depth=wd * 0.86)
    p.path, p.u = path, u
    return p


def nape():
    """Hair over the place the scan's bun was: the braid's root sits in it."""
    n0 = NECK_Z
    c = [np.array(q) for q in ((0.0, -0.062, n0 + 0.135), (0.0, -0.086, n0 + 0.105), (0.0, -0.1, n0 + 0.065), (0.0, -0.098, n0 + 0.03), (0.0, -0.088, n0 + 0.0))]
    return sweep("nape", "hair-braid", c, SEC8, np.array([0.03, 0.062, 0.066, 0.05, 0.004]), side_hint=np.array([1.0, 0, 0]), depth=np.array([0.012, 0.03, 0.038, 0.032, 0.004])).rigid("head")


def braid_tie(p, at_u, name, rad):
    i = int(at_u * (len(p.path) - 2))
    a, b = p.path[i], p.path[i + 1]
    d = norm(b - a)
    c = (a + b) / 2
    return sweep(name, "metal-silver", [c - d * 0.022, c - d * 0.016, c + d * 0.016, c + d * 0.022], SEC8, np.array([rad * 0.82, rad, rad, rad * 0.82]), side_hint=np.array([1.0, 0, 0]))


def braid_tuft(p):
    e = p.path[-1]
    d = norm(p.path[-1] - p.path[-3])
    sd = norm(np.cross(d, (0, 1, 0)))
    path = catmull([e - d * 0.02, e + d * 0.05, e + d * 0.12 + sd * 0.015, e + d * 0.2 + sd * 0.05, e + d * 0.25 + sd * 0.11], 8)
    wd = np.array([0.019, 0.032, 0.041, 0.042, 0.036, 0.027, 0.015, 0.002])
    q = sweep("tuft", "hair-braid", path, SEC6, wd, side_hint=np.array([1.0, 0, 0]), depth=wd * 0.55)
    q.path = path
    return q


# ---- the coat tails: two panels from the jacket's hem to the shin, split at the front and the back. Outer leather and a purple lining: two sheets back to back.
HEM_Z = 0.20
TAIL_ROWS, TAIL_COLS = 8, 9
TOP_Z = None     # set by the source (the scan's jacket hem)


def tail_grid(s, top_z=0.80, r0=(0.165, 0.128), cy=-0.012):
    """(rows, cols, 3): row 0 the top ring, col 0 the front edge, the last col the back edge."""
    G = np.zeros((TAIL_ROWS, TAIL_COLS, 3))
    a0, a1 = np.radians(16), np.radians(150)
    for r in range(TAIL_ROWS):
        t = r / (TAIL_ROWS - 1)
        for c in range(TAIL_COLS):
            k = c / (TAIL_COLS - 1)
            # the front corner lifts in a curve off the legs; the back corner hangs furthest; the side falls in a soft point
            front_cut = 1 - 0.20 * smooth(0.28, 0.0, k)
            back_lift = 1 - 0.06 * smooth(0.82, 1.0, k)
            ln = (top_z - HEM_Z) * front_cut * back_lift
            z = top_z - ln * t ** 1.05
            a = a0 + (a1 - a0) * k
            fl = 1.0 + 0.34 * t ** 1.2 + 0.1 * t * np.sin(k * np.pi)
            fold = 1 + 0.05 * t * np.cos(k * 15.0)                     # three soft folds down the leather
            rx, ry = r0[0] * fl * fold, r0[1] * fl * fold
            x, y = np.sin(a) * rx, np.cos(a) * ry + cy
            y -= 0.1 * t ** 1.5                                       # the rest shape leans back, so the tails read from above
            G[r, c] = (s * x, y, z)
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
    idx = np.linspace(0, R - 1, 4).round().astype(int)
    return [tuple(pts[i]) for i in idx]


# ---- the moth wings, hanging from the small of her back inside the coat's split, tips swept behind. One sheet each (the card slot draws both sides).
W_COLS = 6
WING_N = 4
W_PX = 0.00111                 # metres a pixel of the turnaround's back view (the wing is projected from it, sable_paint.wing)
W_XR = 229.0                   # the pixel of her right wing's inner edge, where it meets the rig
W_MIRROR = 430.0               # her left wing's pixels: W_MIRROR - x
# her right wing's outline in that crop: y, inner x, outer x
W_EDGE = [(0, 240, 282), (60, 236, 312), (120, 232, 345), (180, 230, 380), (240, 229, 412), (300, 228, 432), (350, 229, 438), (400, 232, 430), (440, 237, 405), (480, 243, 400),
          (530, 252, 392), (580, 270, 372), (620, 290, 348), (650, 312, 332), (666, 322, 324)]
W_LEN = 666 * W_PX


def wing_plane(s):
    """Root, along (down the wing), across (outward), both in the wing's rest plane."""
    root = np.array([s * 0.018, -0.118, 0.905])
    along = norm(np.array([s * 0.10, -0.40, -0.92]))
    across = norm(np.cross(along, np.array([0, -1.0, 0.25])))
    if across[0] * s < 0:
        across = -across
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
            bow = 0.035 * np.sin(k * np.pi) * np.sin(min(y / 666.0 * 1.2, 1) * np.pi)
            v.append(root + along * y * W_PX + across * (x - W_XR) * W_PX + normal * bow)
    for r in range(len(W_EDGE) - 1):
        for c in range(W_COLS - 1):
            q = r * W_COLS + c
            f.append([q, q + 1, q + 1 + W_COLS, q + W_COLS])
    p = Piece("wing" + side, "card-wing", np.array(v), f)
    p.root, p.along, p.across, p.s = root, along, across, s
    return p


def wing_points(s):
    root, along, across = wing_plane(s)
    return [tuple(root + along * W_LEN * t + across * 0.05 * t) for t in np.linspace(0.0, 1.0, WING_N)]


# ---- the belt's hangers: keys on a ring, the bola's two weights on a cord, the gem on its chain. Each on a little hang chain.
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
    for i, a in enumerate((-0.32, 0.02, 0.36)):
        d = np.array([np.sin(a), 0.0, -np.cos(a)])
        c0 = top + np.array([0.0, 0.004, -0.04])
        c1 = c0 + d * 0.105
        sh = sweep("keyshaft%d" % i, "metal-silver", [c0, c0 + d * 0.03, c1 - d * 0.02, c1], SEC4, np.array([0.0075, 0.0045, 0.0045, 0.0045]), side_hint=np.array([0, 1.0, 0]))
        out.append(sh)
        sd = np.array([np.cos(a), 0.0, np.sin(a)])
        out.append(sweep("keybit%d" % i, "metal-silver", [c1 - d * 0.03, c1 - d * 0.03 + sd * 0.022, c1 - d * 0.03 + sd * 0.024], SEC4, np.array([0.0085, 0.0085, 0.0001]), side_hint=np.array([0, 1.0, 0])))
    return out


def ball(name, c, r):
    """A low sphere with a ridge: it reads as the sheet's banded weight once painted."""
    c = np.asarray(c, float)
    path = [c + np.array([0, 0, r * z]) for z in (1.0, 0.72, 0.0, -0.72, -1.0)]
    wd = np.array([0.001, 0.7, 1.03, 0.7, 0.001]) * r
    return sweep(name, "metal-silver", path, SEC8, wd, side_hint=np.array([1.0, 0, 0]))


def bola(top):
    top = np.asarray(top, float)
    a = top + np.array([0.038, 0.0, -0.205])
    b = top + np.array([-0.022, 0.012, -0.235])
    out = [ball("bolaA", a, 0.034), ball("bolaB", b, 0.034)]
    out.append(sweep("cordA", "leather-dark", [top, (top + a) / 2 + [0.006, 0, 0], a + [0, 0, 0.03]], SEC4[::1], np.full(3, 0.0045), side_hint=np.array([0, 1.0, 0])))
    out.append(sweep("cordB", "leather-dark", [top, (top + b) / 2 + [-0.003, 0, 0], b + [0, 0, 0.03]], SEC4[::1], np.full(3, 0.0045), side_hint=np.array([0, 1.0, 0])))
    return out


def gem(top):
    """The pendant: a silver shield frame round a cut crystal, on a chain from the belt."""
    top = np.asarray(top, float)
    c = top + np.array([0, 0.0, -0.205])
    out = [sweep("gemchain", "metal-silver", [top, top + np.array([-0.005, 0, -0.08]), c + np.array([0, 0, 0.065])], SEC4, np.array([0.004, 0.004, 0.0065]), side_hint=np.array([0, 1.0, 0]))]
    y = np.array([0, 1.0, 0])
    x = np.array([1.0, 0, 0])
    z = np.array([0, 0, 1.0])
    # the frame
    rim = [c + x * a + z * b for a, b in ((0, 0.066), (0.046, 0.024), (0.04, -0.012), (0, -0.07), (-0.04, -0.012), (-0.046, 0.024), (0, 0.066))]
    out.append(sweep("gemframe", "metal-silver", rim, SEC4, np.full(7, 0.0062), side_hint=y, tip=False))
    # the stone: faceted, both faces
    ring = rim[:-1]
    v = [p for p in ring] + [c + y * 0.016, c - y * 0.016]
    f = []
    for i in range(6):
        j = (i + 1) % 6
        f.append([6, j, i])
        f.append([7, i, j])
    out.append(Piece("gemstone", "glow-rune", np.array(v), f))
    return out, c
