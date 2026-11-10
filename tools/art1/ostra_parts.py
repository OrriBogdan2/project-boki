"""Motley's pieces as numpy meshes (ART-1; the id and files stay ostra; ostra_build.py makes them Blender objects, ostra_paint.py paints
them). The cursed jack-in-the-box of briefs/art-refs ostra_FINAL_sheet and motley_turnaround. Blender space: z up, he faces +y, his right
hand is +x. Every piece carries its own (s, t) on its patch of the atlas, and bone weights as {bone: array}. The joints are the rig's
(art/wardens/src/ostra_rig.json): root is the Rig, the box hangs on x_box, and hips sit at the top of the spring, so the whole upper body
sways and compresses about there."""
import numpy as np
import ostra_mask as M

SH_X, SH_Z = 0.1565, 1.256      # shoulder
EL_Z, WR_Z = 1.046, 0.811       # elbow, wrist
HEAD_Z = 1.442
HIPS_Z = 0.756
SKIRT_Z = 0.826
NECK = np.array((0.0, 0.0, 1.44))
HEAD_K = 0.82       # the head and hat 0.82 of v1's (the sheet's is ~0.65; kept larger so the grin reads at the match camera and he stands the line-up's 1.20x a hunter, warden_model_check)


def headpt(p):
    """a point modelled at v1's head size, scaled about the neck to v2's"""
    return NECK + (np.asarray(p, float) - NECK) * HEAD_K


class Part:
    def __init__(self, name, mat, V, F, ST, W, paint=None, px=(128, 128)):
        self.name, self.mat, self.V, self.F, self.ST, self.W = name, mat, np.asarray(V, np.float32), F, ST, W
        self.paint, self.px = paint, px

    def tris(self):
        return sum(len(f) - 2 for f in self.F)


def rigid(bone, n):
    return {bone: np.ones(n, np.float32)}


def grid(P, closed=False, flip=False):
    """P (rows, cols, 3) -> V, F, corner (s, t). Rows run t 0..1, cols s 0..1. closed: the last col joins the first."""
    R, C = P.shape[:2]
    V = P.reshape(-1, 3)
    F, ST = [], []
    cn = C if closed else C - 1
    for r in range(R - 1):
        for c in range(cn):
            c2 = (c + 1) % C
            f = [r * C + c, r * C + c2, (r + 1) * C + c2, (r + 1) * C + c]
            s0, s1 = c / cn, (c + 1) / cn
            t0, t1 = r / (R - 1), (r + 1) / (R - 1)
            st = [(s0, t0), (s1, t0), (s1, t1), (s0, t1)]
            if flip:
                f, st = f[::-1], st[::-1]
            F.append(f)
            ST.append(st)
    if closed and R > 2:
        # (a closed tube winds by its frames: turn its faces out)
        r = R // 2
        c = P[r].mean(axis=0)
        A, B, D = P[r, 0], P[r, 1], P[r + 1, 0]
        n = np.cross(B - A, D - A)
        if (n @ (A - c) < 0) != flip:
            F = [f[::-1] for f in F]
            ST = [st[::-1] for st in ST]
    return V, F, ST


def both(V, F, ST):
    """a thin sheet: the back faces too, on their own vertices (hero_toon culls back faces)"""
    n = len(V)
    return np.vstack((V, V)), F + [[i + n for i in f[::-1]] for f in F], ST + [st[::-1] for st in ST]


def frames(path):
    """parallel transport frames along a path -> tangents, normals, binormals"""
    d = np.gradient(path, axis=0)
    T = d / np.maximum(np.linalg.norm(d, axis=1, keepdims=True), 1e-6)
    up = np.array((0, 0.13, 1.0)) if abs(T[0][2]) < 0.9 else np.array((1.0, 0, 0))
    N = np.cross(up, T[0])
    N /= np.linalg.norm(N)
    Ns = [N]
    for i in range(1, len(T)):
        n = Ns[-1] - T[i] * (Ns[-1] @ T[i])
        Ns.append(n / max(np.linalg.norm(n), 1e-6))
    Ns = np.array(Ns)
    return T, Ns, np.cross(T, Ns)


def resample(pts, n):
    """a smooth curve (Catmull-Rom) through pts, n points at even spacing"""
    pts = np.asarray(pts, float)
    p = np.vstack((2 * pts[0] - pts[1], pts, 2 * pts[-1] - pts[-2]))
    out = []
    for i in range(1, len(p) - 2):
        for t in np.linspace(0, 1, 16, endpoint=False):
            a, b, c, d = p[i - 1], p[i], p[i + 1], p[i + 2]
            out.append(0.5 * (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t ** 2 + (3 * b - a - 3 * c + d) * t ** 3))
    out.append(pts[-1])
    out = np.array(out)
    L = np.r_[0, np.cumsum(np.linalg.norm(np.diff(out, axis=0), axis=1))]
    q = np.linspace(0, L[-1], n)
    return np.stack([np.interp(q, L, out[:, k]) for k in range(3)], axis=1)


def tube(path, radii, sides, section=None):
    """a tube along path, radii per point, section(angle, t) -> a radial scale"""
    T, N, B = frames(path)
    a = np.linspace(0, 2 * np.pi, sides, endpoint=False)
    P = np.zeros((len(path), sides, 3))
    for i in range(len(path)):
        t = i / (len(path) - 1)
        s = np.ones(sides) if section is None else section(a, t)
        P[i] = path[i] + (np.outer(np.cos(a) * s, N[i]) + np.outer(np.sin(a) * s, B[i])) * radii[i]
    return P


def rmp(x, xs, ys):
    return np.interp(x, xs, ys)


def bone_blend(z, joints):
    """chain of bones along z (top to bottom): joints [(z_at, width, upper bone, lower bone)]"""
    W = {}
    for at, wd, up, lo in joints:
        k = M.sm(at + wd, at - wd, z)
        W.setdefault(up, np.ones(len(z), np.float32))
        W[up] = W[up] * (1 - k)
        W[lo] = W.get(lo, np.ones(len(z), np.float32)) * k
    return W


# ---------------------------------------------------------------------------- the box
BOX_W, BOX_B, BOX_T = 0.2, 0.02, 0.4           # half width, bottom, top (v2 sheet: about a cube)
SPRING_TOP = 0.79


def box():
    """the music box: walls with an inset panel per suit, its open mouth; each wall on its own patch (v2 sheet: spade front and back,
    diamond on either side)"""
    out = []
    w, b, t = BOX_W, BOX_B, BOX_T
    # a wall: outward face (y = +w seen from the front) as a 2 x 2 frame, turned about z
    for i, (key, turn) in enumerate((("wall_s", 0), ("wall_d", 90), ("wall_sb", 180), ("wall_db", 270))):
        c, sn = np.cos(np.radians(turn)), np.sin(np.radians(turn))
        P = np.zeros((3, 3, 3))
        for r, z in enumerate((t, (t + b) * 0.5, b)):
            for k, x in enumerate((-w, 0, w)):
                bulge = 0.006 * (r == 1) * (k == 1)
                lx, ly = -x, w + bulge         # seen from outside: +x of the picture is his left on the front wall
                P[r, k] = (lx * c - ly * sn, lx * sn + ly * c, z)
        V, F, ST = grid(P, flip=True)
        out.append(Part(key, "cloth", V, F, ST, rigid("x_box", len(V)), key, (256, 200)))
    return out


def box_rim():
    """the rim's four rails, the corner irons, the base rail: dark wood and old iron, the box's hard silhouette"""
    out = []
    w, b, t = BOX_W, BOX_B, BOX_T
    def bar(p0, p1, r, sides=6):
        path = np.linspace(p0, p1, 3)
        return tube(path, np.full(3, r), sides, lambda a, tt: 1.0)
    edges_ = []
    for (x, y) in ((w, w), (-w, w), (-w, -w), (w, -w)):
        edges_.append(((x, y, b - 0.005), (x, y, t + 0.005), 0.024))         # corner posts
    for z, r in ((t + 0.004, 0.022), (b, 0.024)):
        for (p, q) in (((-w, w), (w, w)), ((w, w), (w, -w)), ((w, -w), (-w, -w)), ((-w, -w), (-w, w))):
            edges_.append(((p[0], p[1], z), (q[0], q[1], z), r))
    for i, (p0, p1, r) in enumerate(edges_):
        V, F, ST = grid(bar(np.array(p0, float), np.array(p1, float), r), closed=True)
        out.append(Part("rail%d" % i, "cloth", V, F, ST, rigid("x_box", len(V)), "rail", (64, 64)))
    # the iron corner plates, nailed over the rails: a bent L on each face of each corner, top and bottom
    k = 0.062
    for sx in (-1, 1):
        for sy in (-1, 1):
            for z0, zd in ((t + 0.006, -1), (b - 0.003, 1)):
                x, y = sx * (w + 0.026), sy * (w + 0.026)
                L1 = np.array(((x, y, z0), (x - sx * k, y, z0), (x - sx * k * 0.45, y, z0 + zd * k * 0.5), (x, y, z0 + zd * k)))
                L2 = np.array(((x, y, z0), (x, y - sy * k, z0), (x, y - sy * k * 0.45, z0 + zd * k * 0.5), (x, y, z0 + zd * k)))
                for q in (L1, L2):
                    V, F, ST = both(q, [[0, 1, 2, 3]], [[(0, 0), (1, 0), (1, 1), (0, 1)]])
                    out.append(Part("iron", "metal", V, F, ST, rigid("x_box", len(V)), "bell", (64, 64)))
    # the mouth: a shallow dark tray just under the rim
    q = w - 0.012
    V = np.array(((-q, q, t - 0.05), (q, q, t - 0.05), (q, -q, t - 0.05), (-q, -q, t - 0.05)))
    out.append(Part("mouth", "void-body", V, [[0, 1, 2, 3]], [[(0, 0), (1, 0), (1, 1), (0, 1)]], rigid("x_box", 4), "lining", (64, 64)))
    return out


def lid():
    """the lid, hinged along the back of the box, open past upright as in the sheet; its bone turns it shut"""
    w = BOX_W * 1.03
    hy, hz = -BOX_W, BOX_T
    ang = np.radians(104)             # open: from lying forward over the box, up and over
    L = 2 * w
    def at(x, d, o):
        # d along the lid from the hinge, o through its thickness (+ is its inside)
        c, s_ = np.cos(ang), np.sin(ang)
        return (x, hy + d * c - o * s_, hz + d * s_ + o * c)
    P = np.zeros((4, 3, 3))
    for k, x in enumerate((-w, 0, w)):
        for r, (d, o) in enumerate(((0, 0.0), (L, 0.0), (L, 0.024), (0, 0.024))):
            P[r, k] = at(x, d, o)
    V, F, ST = grid(P, closed=False)
    # the inside (wood) and the outside as two simple faces, plus a top-of-lid rail
    W = rigid("x_boxlid", len(V))
    out = [Part("lidbody", "cloth", V, F, ST, W, "lid", (200, 200))]
    Pc = np.array(((at(-w, 0, 0.0), at(w, 0, 0.0)), (at(-w, L, 0.0), at(w, L, 0.0))))
    Vi, Fi, STi = both(*grid(np.array(Pc)))
    out.append(Part("lidface", "cloth", Vi, Fi, STi, rigid("x_boxlid", len(Vi)), "lid", (200, 200)))
    Pb = np.array(((at(-w, 0, 0.024), at(w, 0, 0.024)), (at(-w, L, 0.024), at(w, L, 0.024))))
    Vi, Fi, STi = both(*grid(np.array(Pb)))
    out.append(Part("lidback", "cloth", Vi, Fi, STi, rigid("x_boxlid", len(Vi)), "lid", (200, 200)))
    path = np.array((at(-w, L, 0.012), at(0, L, 0.012), at(w, L, 0.012)))
    V, F, ST = grid(tube(path, np.full(3, 0.02), 4), closed=True)
    out.append(Part("lidrail", "cloth", V, F, ST, rigid("x_boxlid", len(V)), "rail", (64, 64)))
    return out, (0, hy, hz)


CRANK_AXLE = np.array((BOX_W + 0.012, 0.0, 0.2))     # x_crank's pivot; v2 has no crank mesh, the bone stays for the clips


def spring():
    """the brass spring from the box to his hips, the top coils the widest; compressing it is the two bones closing"""
    z0, z1 = BOX_T - 0.04, SPRING_TOP
    n = 60
    t = np.linspace(0, 1, n)
    ang = t * 2 * np.pi * 4.4
    r = 0.098 + 0.03 * np.sin(t * np.pi * 4.4 * 0.5) ** 2 + 0.018 * t
    path = np.stack((np.cos(ang) * r, np.sin(ang) * r - 0.01, z0 + (z1 - z0) * t), axis=1)
    V, F, ST = grid(tube(path, np.full(n, 0.0135), 8), closed=True)
    tt = np.repeat(t, 8)
    k = M.sm(0.0, 1.0, tt)
    return Part("spring", "metal", V, F, ST, {"x_box": (1 - k), "hips": k}, "brass", (64, 64))


def smoke_wrap():
    """void smoke wound round the spring, a bone hides it: it shows only while the spring compresses (owner: in stills the spring is clear)"""
    n = 26
    t = np.linspace(0, 1, n)
    ang = t * 2 * np.pi * 2.4 + 0.8
    r = 0.16 - 0.03 * t
    path = np.stack((np.cos(ang) * r, np.sin(ang) * r, BOX_T + 0.01 + 0.29 * t), axis=1)
    V, F, ST = grid(tube(path, 0.035 * np.sin(t * np.pi) ** 0.6 + 0.003, 6), closed=True)
    return Part("smokewrap", "void-wisp", V, F, ST, rigid("x_smoke", len(V)), "wisp", (256, 512))


# ---------------------------------------------------------------------------- the body
def torso():
    zs = np.array((1.42, 1.39, 1.345, 1.300, 1.255, 1.185, 1.105, 1.045, 0.985, 0.94))
    rx = np.array((0.04, 0.05, 0.10, 0.148, 0.155, 0.128, 0.098, 0.084, 0.09, 0.10))
    ry = np.array((0.04, 0.05, 0.074, 0.082, 0.088, 0.086, 0.074, 0.066, 0.07, 0.075))
    rows = 17
    z = np.interp(np.linspace(0, len(zs) - 1, rows), np.arange(len(zs)), zs)
    k = np.argsort(zs)
    a = np.linspace(0, 2 * np.pi, 24, endpoint=False)
    P = np.zeros((rows, 24, 3))
    for i in range(rows):
        x, y = np.interp(z[i], zs[k], rx[k]), np.interp(z[i], zs[k], ry[k])
        ca, sa = np.cos(a), np.sin(a)
        r = (np.abs(ca) ** 2.5 + np.abs(sa) ** 2.5) ** (-1 / 2.5)
        P[i, :, 0], P[i, :, 1], P[i, :, 2] = r * ca * x, r * sa * y, z[i]
    V, F, ST = grid(P, closed=True, flip=True)
    return Part("torso", "cloth", V, F, ST, rigid("hips", len(V)), "torso", (360, 360))


def peplum():
    """the coat's short flare under the belt, open in a V at the front on the starry void"""
    nu, nv = 41, 5
    s = np.linspace(0, 1, nu)
    P = np.zeros((nv, nu, 3))
    for i, t in enumerate(np.linspace(0, 1, nv)):
        o = np.radians(4 + 26 * t)
        a = o + (2 * np.pi - 2 * o) * s
        rx, ry = 0.09 + 0.19 * t ** 1.2, 0.07 + 0.17 * t ** 1.2
        P[i, :, 0] = np.sin(a) * rx
        P[i, :, 1] = np.cos(a) * ry
        P[i, :, 2] = 1.05 - 0.23 * t
    V, F, ST = grid(P, flip=True)
    return Part("peplum", "cloth", V, F, ST, rigid("hips", len(V)), "peplum", (360, 110)), P


def lining(P):
    Q = P.copy()
    Q[..., :2] -= Q[..., :2] / np.maximum(np.linalg.norm(Q[..., :2], axis=2, keepdims=True), 1e-4) * 0.008
    V, F, ST = grid(Q)
    return Part("lining", "void-body", V, F, ST, rigid("hips", len(V)), "lining", (64, 64))


TAILS = ((30, 0.46, 0.72), (90, 0.56, 0.76), (150, 0.50, 0.73), (-150, 0.50, 0.73), (-90, 0.56, 0.76), (-30, 0.46, 0.72))   # sheet: the bells hang clear above the box, the spring shows


def tails():
    """the six coat tails: broad at the flare, flung out and hooked down to a point with a brass bell, ending above the box as on the sheet; each swings on its spring chain"""
    out, joints = [], []
    for i, (deg, reach, drop) in enumerate(TAILS):
        a = np.radians(deg)
        d = np.array((np.sin(a), np.cos(a), 0.0))
        side = np.array((np.cos(a), -np.sin(a), 0.0))
        pts = [d * 0.17 + (0, 0, 0.99), d * 0.27 + (0, 0, 0.90), d * (reach * 0.78) + (0, 0, drop + 0.08), d * reach + (0, 0, drop), d * (reach + 0.02) + (0, 0, drop - 0.08)]
        path = resample(pts, 15)
        t = np.linspace(0, 1, 15)
        wd = rmp(t, [0, 0.3, 0.7, 1], [0.13, 0.10, 0.05, 0.004])
        P = np.zeros((15, 3, 3))
        for r in range(15):
            P[r, 0] = path[r] - side * wd[r]
            P[r, 1] = path[r] + np.array((0, 0, 0.012)) * (1 - t[r]) + d * 0.012 * (1 - t[r])
            P[r, 2] = path[r] + side * wd[r]
        V, F, ST = both(*grid(P))
        n = "spring_tail%d" % i
        ts = np.tile(np.repeat(t, 3), 2)
        out.append(Part("tail%d" % i, "cloth", V, F, ST, chain_w(n, ts, 2, 0.22, "hips"), "tail_v" if i % 2 == 0 else "tail_k", (70, 200)))
        ks = [4, 9, 14]
        for j in range(3):
            parent = "hips" if j == 0 else "%s_%d" % (n, j - 1)
            tail_ = path[ks[j + 1]] if j < 2 else path[-1] + (path[-1] - path[-2]) * 0.9
            joints.append(("%s_%d" % (n, j), (path[ks[j]], tail_, parent)))
        out.append(ball("tbell%d" % i, path[-1] + (0, 0, -0.024), 0.032, "%s_1" % n))
    return out, joints


def ball(nm, c, r, bone, rows=7, cols=10):
    c = np.array(c)
    a = np.linspace(0, 2 * np.pi, cols, endpoint=False)
    P = np.zeros((rows, cols, 3))
    for i in range(rows):
        p = np.pi * (i + 0.2) / (rows - 0.6)
        q = np.sin(p) * r * (1 + 0.14 * (i >= rows - 2))
        P[i, :, 0], P[i, :, 1], P[i, :, 2] = c[0] + np.cos(a) * q, c[1] + np.sin(a) * q, c[2] + np.cos(p) * r
    V, F, ST = grid(P, closed=True, flip=True)
    return Part(nm, "metal", V, F, ST, rigid(bone, len(V)), "bell", (64, 64))


def sleeve(side):
    x = side * SH_X
    zs = np.linspace(1.315, 0.84, 15)
    rd = rmp(zs, [0.84, 0.92, EL_Z, 1.16, 1.27, 1.315], [0.036, 0.038, 0.044, 0.052, 0.058, 0.05])
    path = np.stack((np.full_like(zs, x) + 0.012 * side * np.sin((zs - 0.84) / 0.48 * np.pi), 0 * zs, zs), axis=1)
    path[0, 0] -= side * 0.03
    V, F, ST = grid(tube(path, rd, 10), closed=True)
    n = "R" if side > 0 else "L"
    W = bone_blend(V[:, 2], [(EL_Z, 0.028, "upper_arm." + n, "forearm." + n)])
    return Part("sleeve" + n, "cloth", V, F, ST, W, "sleeve_k" if side > 0 else "sleeve_v", (200, 260))


def cuff(side):
    """the white glove's pointed cuff"""
    x = side * SH_X
    nu, nv = 21, 3
    a = np.linspace(0, 2 * np.pi, nu)
    P = np.zeros((nv, nu, 3))
    for i, t in enumerate(np.linspace(0, 1, nv)):
        tri = 1 - np.abs((a / (2 * np.pi) * 5 % 1.0) * 2 - 1)
        P[i, :, 0] = x + np.cos(a) * (0.036 + 0.04 * t)
        P[i, :, 1] = np.sin(a) * (0.036 + 0.04 * t)
        P[i, :, 2] = 0.82 + (0.91 + 0.08 * tri * t - 0.82) * t
    V, F, ST = both(*grid(P))
    n = "R" if side > 0 else "L"
    k = M.sm(WR_Z + 0.03, WR_Z - 0.01, V[:, 2])
    return Part("cuff" + n, "cloth", V, F, ST, {"forearm." + n: 1 - k, "hand." + n: k}, "glove", (64, 64))


def hand(side):
    """a slim white glove, hanging, palm to the body, thumb forward"""
    n = "R" if side > 0 else "L"
    x0 = side * SH_X
    out, J = [], {}
    zs = np.array((WR_Z + 0.015, WR_Z - 0.015, WR_Z - 0.05, WR_Z - 0.078, WR_Z - 0.095))
    wy, wx = np.array((0.026, 0.03, 0.046, 0.05, 0.042)), np.array((0.026, 0.024, 0.024, 0.02, 0.013))
    a = np.linspace(0, 2 * np.pi, 8, endpoint=False)
    P = np.zeros((5, 8, 3))
    for i in range(5):
        P[i, :, 0], P[i, :, 1], P[i, :, 2] = x0 + np.cos(a) * wx[i], np.sin(a) * wy[i], zs[i]
    V, F, ST = grid(P, closed=True)
    k0 = M.sm(WR_Z + 0.012, WR_Z - 0.012, V[:, 2])
    out.append(Part("palm" + n, "cloth", V, F, ST, {"forearm." + n: 1 - k0, "hand." + n: k0}, "glove", (64, 64)))
    kn_z = WR_Z - 0.09
    pd = -side
    for nm, y, L, sp in (("1", 0.034, 0.105, 0.06), ("2", 0.012, 0.12, 0.0), ("3", -0.011, 0.112, -0.05), ("4", -0.032, 0.092, -0.14)):
        k = np.array((x0 - side * 0.006, y, kn_z))
        mid = k + np.array((pd * 0.006, sp * L * 0.5, -L * 0.5))
        tip = mid + np.array((pd * 0.016, sp * L * 0.5, -L * 0.5))
        path = resample([k + (0, 0, 0.012), k, mid, tip], 8)
        rd = rmp(np.linspace(0, 1, 8), [0, 0.15, 0.5, 0.8, 1.0], [0.012, 0.0135, 0.0115, 0.0095, 0.002])
        V, F, ST = grid(tube(path, rd, 8), closed=True)
        kb = M.sm(L * 0.42, L * 0.56, np.linalg.norm(V - k, axis=1))
        wa, wb = "x_fing%s.%s" % (nm, n), "x_fing%sb.%s" % (nm, n)
        out.append(Part("fing%s%s" % (nm, n), "cloth", V, F, ST, {wa: 1 - kb, wb: kb}, "glove", (64, 64)))
        J[wa], J[wb] = (k, mid, "hand." + n), (mid, tip, wa)
    k = np.array((x0 - side * 0.01, 0.042, WR_Z - 0.03))
    mid = k + np.array((pd * 0.018, 0.04, -0.035))
    tip = mid + np.array((pd * 0.022, 0.03, -0.045))
    path = resample([k, mid, tip], 6)
    V, F, ST = grid(tube(path, rmp(np.linspace(0, 1, 6), [0, 0.5, 1.0], [0.015, 0.0115, 0.002]), 6), closed=True)
    kb = M.sm(0.045, 0.06, np.linalg.norm(V - k, axis=1))
    out.append(Part("thumb" + n, "cloth", V, F, ST, {"x_thumb." + n: 1 - kb, "x_thumbb." + n: kb}, "glove", (64, 64)))
    J["x_thumb." + n], J["x_thumbb." + n] = (k, mid, "hand." + n), (mid, tip, "x_thumb." + n)
    return out, J


# ---------------------------------------------------------------------------- the head
HEAD_C = np.array((0.0, -0.01, 1.655))
FACE_TILT = np.radians(16)          # the face plane looks up a little: the match camera sits high


def face_point(u, v):
    """a point on the face plane: an oval, dished, tipped up"""
    hw, hh = 0.116, 0.182
    x = u * hw
    z = v * hh
    y = 0.112 - 0.03 * (1 - u * u) * (1 - v * v)
    c, s_ = np.cos(FACE_TILT), np.sin(FACE_TILT)
    return headpt(np.stack((x, HEAD_C[1] + y * c - z * s_, HEAD_C[2] + z * c + y * s_ - 0.03), axis=-1))


def face():
    """the void face: an oval grid; x_jaw, x_brow, x_cheek bend the painted grin and slits"""
    nu, nv = 17, 23
    us, vs = np.meshgrid(np.linspace(-1, 1, nu), np.linspace(1, -1, nv))
    # squeeze the square into the oval, the chin coming to a point
    wd = np.sqrt(np.clip(1 - vs ** 2, 0.0, 1)) * (1 - 0.32 * M.sm(0.0, -1.0, vs))
    P = face_point(us * wd, vs)
    V, F, ST = grid(P)
    # (the texture's square, so the paint's u, v are the face's)
    Vp = P.reshape(-1, 3)
    pu = (us * wd).ravel()
    pv = vs.ravel()
    corners = []
    for f in F:
        corners.append([(pu[i] * 0.5 + 0.5, 0.5 - pv[i] * 0.5) for i in f])
    au = np.abs(pu)
    top, bot = -0.26 + 0.50 * (au / 0.86) ** 2.3, -0.76 + 0.92 * (au / 0.86) ** 2.1
    mid = top + (bot - top) * 0.5
    jaw = M.sm(mid + 0.02, mid - 0.06, pv) * M.sm(1.0, 0.7, au)
    W = {"x_jaw": jaw}
    for s_, nm in ((1, "R"), (-1, "L")):
        sd = (pu * s_ > 0)
        W["x_brow." + nm] = np.clip(M.gauss(au, pv, 0.42, 0.34, 0.42, 0.22) * 1.3, 0, 1) * sd * (1 - jaw)
        W["x_cheek." + nm] = np.clip(M.gauss(au, pv, 0.74, -0.05, 0.3, 0.26) * 1.2, 0, 1) * sd * (1 - jaw) * (1 - W["x_brow." + nm])
    W["head"] = np.clip(1 - sum(W.values()), 0, 1)
    return Part("face", "leather-face", V, F, corners, W, None)


def hood():
    """the cap's skull: a bag from the oval round the face to the back of the head"""
    C = headpt(HEAD_C)
    R = np.array((0.135, 0.17, 0.225)) * HEAD_K
    n = 44
    loop = []
    for k in range(n):
        a = 2 * np.pi * k / n          # from the top, round his right
        u, v = np.sin(a), np.cos(a)
        # the V of the cap's edge on the brow, and the chin's point
        v2 = v * (1.05 - 0.30 * M.sm(0.7, 1.0, v) * M.sm(0.3, 0.0, np.abs(u)))
        wd = 1.03 * (1 - 0.3 * M.sm(0.0, -1.0, v))
        loop.append(face_point(np.array(u * wd), np.array(v2)) + np.array((0, 0.005, 0)))
    E = np.array(loop)
    back = np.array((0.0, -1.0, 0.08))
    back /= np.linalg.norm(back)
    rows = 16
    P = np.zeros((rows, n, 3))
    for i in range(n):
        d0 = E[i] - C
        r0 = np.linalg.norm(d0)
        d0 /= r0
        ang = np.arccos(np.clip(d0 @ back, -1, 1))
        so = max(np.sin(ang), 1e-3)
        for k in range(rows):
            t = k / (rows - 1)
            d = (np.sin((1 - t) * ang) * d0 + np.sin(t * ang) * back) / so
            q = np.linalg.norm(d / R) ** -1
            # (a broad rim standing proud round the face, then the hood proper behind a soft crease)
            lip = 0.022 * M.sm(0.0, 0.05, t) * M.sm(0.27, 0.17, t)
            P[k, i] = C + d * (r0 + (q - r0) * M.sm(0.0, 0.2, t) + lip)
    V, F, ST = grid(P, closed=True)
    return Part("hood", "cloth", V, F, ST, rigid("head", len(V)), "hood", (340, 180))


def horn(side):
    """a floppy horn, rising then drooping to its bell, swinging on a spring chain"""
    n = "R" if side > 0 else "L"
    pts = np.array(((0.05, -0.05, 1.78), (0.115, -0.06, 1.93), (0.2, -0.07, 1.96), (0.275, -0.07, 1.89), (0.32, -0.06, 1.72), (0.338, -0.05, 1.61), (0.34, -0.045, 1.56)))
    pts[:, 0] *= side
    path = resample(headpt(pts), 22)
    t = np.linspace(0, 1, 22)
    rd = rmp(t, [0, 0.15, 0.35, 0.6, 0.85, 1.0], [0.095, 0.105, 0.092, 0.066, 0.03, 0.012]) * HEAD_K
    V, F, ST = grid(tube(path, rd, 14, lambda a, tt: 1 + 0.08 * np.cos(2 * a) * (1 - tt)), closed=True)
    return Part("horn" + n, "cloth", V, F, ST, chain_w("spring_horn%s" % n, np.repeat(t, 14), 3, 0.35, "head"), "horn" + n, (320, 120)), path


def chain_w(prefix, t, bones, start, parent):
    W = {parent: np.zeros(len(t), np.float32)}
    k = np.clip((t - start) / (1 - start), 0, 1) * bones
    for i in range(bones):
        W["%s_%d" % (prefix, i)] = np.clip(1 - np.abs(k - i - 0.5), 0, 1).astype(np.float32)
    W[parent] = np.clip(1 - k * 3.5, 0, 1).astype(np.float32)
    tot = sum(W.values())
    return {b: w / np.maximum(tot, 1e-6) for b, w in W.items()}


RUFF_K = 0.80       # v2 sheet: the ruff a little narrower than v1's, with the smaller head


def ruff():
    """the great white ruff, a separate drum of folded cloth (ostra_head): radial pleats on top, S-looped accordion folds round its outer wall,
    tipped down at the front. The first read at the match camera"""
    pleats, per = 29, 3
    nu = pleats * per
    a = np.linspace(0, 2 * np.pi, nu, endpoint=False)
    sec = ((0.075, 0.035), (0.14, 0.05), (0.21, 0.058), (0.265, 0.056), (0.292, 0.03), (0.297, 0.0), (0.292, -0.03), (0.265, -0.056), (0.21, -0.058), (0.14, -0.05), (0.075, -0.035))
    rows = len(sec)
    P = np.zeros((rows, nu, 3))
    for i, (rr, h) in enumerate(sec):
        q = rr / 0.297
        wall = M.sm(0.75, 0.95, q)
        ph = a * pleats + 2.2 * (h / 0.058) * wall      # (the folds snake down the wall)
        scal = 1 + (0.03 * q ** 2 + 0.05 * wall) * np.cos(ph)
        P[i, :, 0] = np.sin(a) * rr * scal * 1.04 * RUFF_K
        P[i, :, 1] = np.cos(a) * rr * scal * 0.96 * RUFF_K
        P[i, :, 2] = 1.435 + h * (1 + 0.22 * np.sin(a * pleats) * q ** 3) - 0.16 * P[i, :, 1]
    V, F, ST = grid(P, closed=True)
    r = np.hypot(V[:, 0], V[:, 1])
    k = M.sm(0.15 * RUFF_K, 0.07, r) * 0.4
    return Part("ruff", "cloth-ruff", V, F, ST, {"hips": 1 - k, "head": k}, "ruff", (560, 140))


def collar():
    """the points under the ruff, in turn violet and black, a brass bell on each tip"""
    out = []
    for i, deg in enumerate((-157, -113, -68, -24, 24, 68, 113, 157)):
        a0 = np.radians(deg)
        hw = np.radians(24)
        nu, nv = 5, 6
        P = np.zeros((nv, nu, 3))
        L = 0.17 + 0.06 * abs(np.sin(a0))
        for r, t in enumerate(np.linspace(0, 1, nv)):
            a = a0 + np.linspace(-1, 1, nu) * hw * (1 - t ** 1.6)
            sh = np.abs(np.sin(a))
            rad = 0.075 + t * L * (0.5 + 0.8 * sh)
            P[r, :, 0] = np.sin(a) * rad * 1.2
            P[r, :, 1] = np.cos(a) * rad * 0.9
            P[r, :, 2] = 1.36 - t * L * (0.62 - 0.34 * sh) - 0.06 * np.cos(a) * t
        V, F, ST = both(*grid(P))
        k = M.sm(0.1, 0.25, np.abs(V[:, 0])) * 0.8
        side = "pauldron.R" if deg > 0 else "pauldron.L"
        out.append(Part("collar%d" % i, "cloth", V, F, ST, {"hips": 1 - k, side: k}, "collar_v" if i % 2 == 0 else "collar_k", (64, 80)))
        tip = P[-1, 2]
        out.append(ball("cbell%d" % i, tip + (0, 0, -0.014), 0.017, side, 4, 5))
    return out


def buttons():
    out = []
    for i, z in enumerate((1.2, 1.13, 1.06)):
        y = 0.094 - (1.2 - z) * 0.12
        out.append(ball("btn%d" % i, (0.0, y, z), 0.017, "hips", 3, 5))
    return out


# ---------------------------------------------------------------------------- the void, the orb, the cards
WISP_PATH = [(0.02, -0.03, 0.26), (0.0, 0.03, 0.34), (-0.13, 0.09, 0.42), (-0.27, 0.09, 0.54), (-0.30, 0.03, 0.68), (-0.21, -0.06, 0.82), (-0.08, -0.05, 0.95), (0.0, -0.01, 1.05)]


def wisp():
    """the starry void pouring from the box, beside the spring, up into the coat; based on the box, its top rides the hips"""
    out = []
    path = resample(WISP_PATH, 30)
    t = np.linspace(0, 1, 30)
    rd = rmp(t, [0, 0.14, 0.4, 0.7, 1.0], [0.16, 0.11, 0.115, 0.105, 0.09])
    # (v2 sheet: a broad flat ribbon of smoke, not a round tube)
    tw = lambda a, tt: (1 + 0.35 * np.cos(2 * a + tt * 4.0)) * (1 + 0.16 * np.cos(4 * a + tt * 11.0) + 0.08 * np.cos(3 * a - tt * 7.0))
    V, F, ST = grid(tube(path, rd, 14, tw), closed=True)
    # (v = 1 down at the box: hero_void's soft fade pours it into the mouth)
    ST = [[(s, 1.0 - tv) for s, tv in c] for c in ST]
    def wts(ts):
        W = chain_w("spring_wisp", ts, 4, 0.08, "x_void")
        k = M.sm(0.72, 0.9, ts)
        W = {b: w * (1 - k) for b, w in W.items()}
        W["hips"] = W.get("hips", 0) + k
        return W
    out.append(Part("wisp", "void-wisp", V, F, ST, wts(np.repeat(t, 14)), "wisp", (256, 512)))
    for j, (a0, st, en, off) in enumerate(((0.8, 0.2, 0.8, 0.1), (2.9, 0.08, 0.6, 0.11))):
        q = np.linspace(st, en, 12)
        base = np.stack([np.interp(q, t, path[:, k]) for k in range(3)], axis=1)
        tt = (q - st) / (en - st)
        sp = off * np.sin(tt * np.pi) ** 0.8
        p = base + np.stack((np.cos(a0 + tt * 3) * sp, np.sin(a0 + tt * 3) * sp, 0 * tt), axis=1)
        V, F, ST = grid(tube(p, rmp(tt, [0, 0.2, 0.7, 1], [0.008, 0.026, 0.015, 0.002]), 5), closed=True)
        ST = [[(s, 1.0 - (st + (en - st) * tv)) for s, tv in c] for c in ST]
        out.append(Part("strand%d" % j, "void-wisp", V, F, ST, wts(np.repeat(q, 5)), "wisp", (256, 512)))
    return out, path


def fan(side=-1):
    """the fan of cards in his off hand, five backs, on x_fan so a clip can snap it shut"""
    x0 = side * SH_X
    c = np.array((x0 + 0.05, 0.0, WR_Z - 0.09))         # off the palm
    Vs, Fs, STs = [], [], []
    b = 0
    for i, deg in enumerate((-40, -20, 0, 20, 40)):
        a = np.radians(deg)
        up = np.array((0, np.sin(a), -np.cos(a)))
        sd = np.array((0, np.cos(a), np.sin(a)))
        off = np.array((0.006 * i, 0, 0))
        q = [c + off - sd * 0.05, c + off + sd * 0.05, c + off + sd * 0.05 + up * 0.15, c + off - sd * 0.05 + up * 0.15]
        Vs += q
        Fs += [[b, b + 1, b + 2, b + 3], [b + 3, b + 2, b + 1, b]]
        STs += [[(0, 1), (1, 1), (1, 0), (0, 0)], [(0, 0), (1, 0), (1, 1), (0, 1)]]
        b += 4
    return Part("fan", "glow-cards", np.array(Vs), Fs, STs, rigid("x_fan", len(Vs)), "cardback", (96, 140)), c
