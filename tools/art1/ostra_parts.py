"""Ostra's pieces as numpy meshes (ART-1, numpy only; ostra_build.py makes them Blender objects, ostra_paint.py paints them).
Blender space: z up, he faces +y, his right hand is +x. Every piece carries its own (s, t) on its patch of the atlas, and bone
weights as {bone: array}. The joints are the rig's (art/wardens/src/ostra_rig.json); the mask is ostra_mask.py."""
import numpy as np
import ostra_mask as M

SH_X, SH_Z = 0.1565, 1.256      # shoulder
EL_Z, WR_Z = 1.046, 0.811       # elbow, wrist
HEAD_Z = 1.442
HIPS_Z = 0.756
SKIRT_Z = 0.826


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


# ---------------------------------------------------------------------------- the body
def torso():
    zs = np.array((1.415, 1.385, 1.345, 1.300, 1.255, 1.185, 1.105, 1.045, 0.985, 0.93))
    rx = np.array((0.045, 0.055, 0.105, 0.150, 0.158, 0.132, 0.100, 0.086, 0.092, 0.098))
    ry = np.array((0.045, 0.056, 0.075, 0.082, 0.088, 0.086, 0.074, 0.066, 0.068, 0.070))
    yc = np.array((0.00, 0.00, 0.00, 0.00, 0.00, 0.008, 0.004, 0.0, -0.002, -0.004))
    rows = 15
    z = np.interp(np.linspace(0, len(zs) - 1, rows), np.arange(len(zs)), zs)
    k = np.argsort(zs)
    a = np.linspace(0, 2 * np.pi, 22, endpoint=False)
    P = np.zeros((rows, 22, 3))
    for i in range(rows):
        x = np.interp(z[i], zs[k], rx[k])
        y = np.interp(z[i], zs[k], ry[k])
        c = np.interp(z[i], zs[k], yc[k])
        ca, sa = np.cos(a), np.sin(a)
        e = 2.5
        r = (np.abs(ca) ** e + np.abs(sa) ** e) ** (-1 / e)
        P[i, :, 0] = r * ca * x
        P[i, :, 1] = r * sa * y + c
        P[i, :, 2] = z[i]
    V, F, ST = grid(P, closed=True, flip=True)
    return Part("torso", "cloth", V, F, ST, rigid("hips", len(V)), "torso", (420, 420))


def skirt():
    """the coat from the waist, open in an inverted V at the front, ending in torn points; its lining is the Void"""
    nu, nv = 53, 9
    s = np.linspace(0, 1, nu)
    v = np.linspace(0, 1, nv)
    P = np.zeros((nv, nu, 3))
    n_dags = 7
    for i, t in enumerate(v):
        o = np.radians(5 + 31 * t ** 1.2)       # half the front's opening
        a = o + (2 * np.pi - 2 * o) * s        # from the front (+y), round his right, the back, to the left
        rx = 0.092 + (0.335 - 0.092) * t ** 1.2
        ry = 0.070 + (0.275 - 0.070) * t ** 1.2
        pl = 1 + 0.07 * t * np.sin(a * 9.0) + 0.03 * t * np.sin(a * 17.0 + 1.0)      # pleats
        # dags: a saw of long points, with tears cut in (the hem falls past the hands)
        q = (s * n_dags) % 1.0
        tri = 1.0 - np.abs(q * 2.0 - 1.0)
        tear = 0.5 + 0.5 * np.sin(s * 71.0 + 1.3) * np.sin(s * 31.0)
        side = 0.5 - 0.5 * np.cos(2 * np.pi * s)
        hem = 0.84 - 0.10 * side - 0.27 * tri ** 1.3 - 0.03 * tear
        z = 1.05 + (hem - 1.05) * t
        P[i, :, 0] = np.sin(a) * rx * pl
        P[i, :, 1] = np.cos(a) * ry * pl - 0.012 * t
        P[i, :, 2] = z
    V, F, ST = grid(P, flip=True)
    ang = np.linspace(0, 1, nu)
    w_low = (1.05 - V[:, 2]) / 0.3
    k = np.clip(w_low, 0, 1)
    W = {"hips": 1 - k, "skirt": k}
    return Part("skirt", "cloth", V, F, ST, W, "skirt", (900, 300)), P


def lining(P):
    Q = P.copy()
    Q[..., :2] -= Q[..., :2] / np.maximum(np.linalg.norm(Q[..., :2], axis=2, keepdims=True), 1e-4) * 0.008
    V, F, ST = grid(Q)
    k = np.clip((1.05 - V[:, 2]) / 0.3, 0, 1)
    return Part("lining", "void-lining", V, F, ST, {"hips": 1 - k, "skirt": k}, "lining", (64, 64))


def sleeve(side):
    """shoulder to wrist; the fold of the glove's cuff is its own piece"""
    x = side * SH_X
    zs = np.linspace(1.315, 0.835, 15)
    rd = rmp(zs, [0.835, 0.90, EL_Z, 1.16, 1.27, 1.315], [0.034, 0.036, 0.042, 0.052, 0.058, 0.05])
    bend = 0.015 * side * np.sin((zs - 0.835) / 0.48 * np.pi)        # a little outward bow
    path = np.stack((np.full_like(zs, x) + bend, 0.004 * np.sin(zs * 9), zs), axis=1)
    path[0, 0] -= side * 0.03
    P = tube(path, rd, 10)
    V, F, ST = grid(P, closed=True)
    # (+y faces front: a tube's winding depends on the frames; ostra_build recalculates the normals)
    z = V[:, 2]
    W = bone_blend(z, [(EL_Z, 0.028, "upper_arm." + ("R" if side > 0 else "L"), "forearm." + ("R" if side > 0 else "L"))])
    return Part("sleeve" + ("R" if side > 0 else "L"), "cloth", V, F, ST, W, "sleeve", (220, 300))


def cuff(side):
    """the glove's flared cuff with its torn points"""
    x = side * SH_X
    nu, nv = 25, 4
    P = np.zeros((nv, nu, 3))
    a = np.linspace(0, 2 * np.pi, nu)
    for i, t in enumerate(np.linspace(0, 1, nv)):
        q = (a / (2 * np.pi) * 6) % 1.0
        tri = 1 - np.abs(q * 2 - 1)
        L = 0.05 + 0.075 * tri ** 1.2
        z = 0.845 + 0.075 - (0.075 + L) * t * 0.9 - 0.0 * t
        r = 0.04 + 0.03 * t
        P[i, :, 0] = x + np.cos(a) * r
        P[i, :, 1] = np.sin(a) * r
        P[i, :, 2] = 0.965 - (0.965 - (0.86 - L * 0.7)) * t
        P[i, :, 2] += 0.0
    V, F, ST = both(*grid(P))
    n = "R" if side > 0 else "L"
    k = M.sm(WR_Z + 0.03, WR_Z - 0.03, V[:, 2])
    return Part("cuff" + n, "cloth", V, F, ST, {"forearm." + n: 1 - k * 0.6, "hand." + n: k * 0.6}, "cuff", (220, 90))


def hand(side):
    """a long spidery gloved hand, hanging, palm to the body, thumb forward; -> parts, finger joints for the bones"""
    n = "R" if side > 0 else "L"
    x0 = side * SH_X
    out = []
    # the palm: a flattened loft from the wrist to the knuckles
    zs = np.array((WR_Z + 0.015, WR_Z - 0.015, WR_Z - 0.05, WR_Z - 0.078, WR_Z - 0.095))
    wy = np.array((0.026, 0.03, 0.044, 0.05, 0.042))
    wx = np.array((0.026, 0.022, 0.021, 0.018, 0.012))
    a = np.linspace(0, 2 * np.pi, 10, endpoint=False)
    P = np.zeros((5, 10, 3))
    for i in range(5):
        P[i, :, 0] = x0 + np.cos(a) * wx[i] - side * 0.004 * i
        P[i, :, 1] = np.sin(a) * wy[i]
        P[i, :, 2] = zs[i]
    V, F, ST = grid(P, closed=True)
    k0 = M.sm(WR_Z + 0.012, WR_Z - 0.012, V[:, 2])
    out.append(Part("palm" + n, "leather", V, F, ST, {"forearm." + n: 1 - k0, "hand." + n: k0}, "glove", (128, 128)))
    # the fingers: index to little, forward to back
    J = {}
    specs = [("1", 0.033, 0.150, 0.05), ("2", 0.012, 0.172, 0.0), ("3", -0.011, 0.160, -0.04), ("4", -0.032, 0.130, -0.11)]
    kn_z = WR_Z - 0.09
    palm_dir = -side          # which way the fingers curl in x
    for nm, y, L, spread in specs:
        k = np.array((x0 - side * 0.012, y, kn_z))
        mid = k + np.array((palm_dir * 0.006, spread * L * 0.45, -L * 0.45))
        j2 = mid + np.array((palm_dir * 0.012, spread * L * 0.3, -L * 0.28))
        tip = j2 + np.array((palm_dir * 0.03, spread * L * 0.2, -L * 0.27))
        path = resample([k + (0, 0, 0.012), k, mid, j2, tip], 9)
        rd = rmp(np.linspace(0, 1, 9), [0, 0.1, 0.42, 0.5, 0.72, 0.8, 1.0], [0.0105, 0.0125, 0.0098, 0.0108, 0.0085, 0.0075, 0.0008])
        Pf = tube(path, rd, 7)
        V, F, ST = grid(Pf, closed=True)
        d = np.linalg.norm(V - k, axis=1)
        kb = M.sm(L * 0.40, L * 0.52, d)
        wb = "x_fing%sb.%s" % (nm, n)
        wa = "x_fing%s.%s" % (nm, n)
        out.append(Part("fing%s%s" % (nm, n), "leather", V, F, ST, {wa: 1 - kb, wb: kb}, "finger", (40, 128)))
        J[wa] = (k, mid, "hand." + n)
        J[wb] = (mid, tip, wa)
    # the thumb
    k = np.array((x0 - side * 0.012, 0.042, WR_Z - 0.03))
    mid = k + np.array((palm_dir * 0.018, 0.045, -0.04))
    tip = mid + np.array((palm_dir * 0.03, 0.035, -0.06))
    path = resample([k, mid, tip], 8)
    rd = rmp(np.linspace(0, 1, 8), [0, 0.45, 0.7, 1.0], [0.014, 0.0105, 0.008, 0.0008])
    V, F, ST = grid(tube(path, rd, 7), closed=True)
    d = np.linalg.norm(V - k, axis=1)
    kb = M.sm(0.05, 0.07, d)
    out.append(Part("thumb" + n, "leather", V, F, ST, {"x_thumb." + n: 1 - kb, "x_thumbb." + n: kb}, "finger", (40, 128)))
    J["x_thumb." + n] = (k, mid, "hand." + n)
    J["x_thumbb." + n] = (mid, tip, "x_thumb." + n)
    return out, J


# ---------------------------------------------------------------------------- the head
def hood():
    """the cap's skull: a bag from the loop round the mask's edge to the back of the head (star-shaped about C)"""
    C = np.array((0.0, -0.035, 1.665))
    R = np.array((0.158, 0.172, 0.196))
    # the edge loop, in the mask's u, v: the V on the forehead, over the brows, down past the cheeks, under the chin
    loop = np.array(((0, 0.60), (0.22, 0.76), (0.55, 0.84), (0.85, 0.66), (0.98, 0.36), (1.0, 0.0), (0.97, -0.4), (0.8, -0.8), (0.5, -1.0),
                     (0.0, -1.1), (-0.5, -1.0), (-0.8, -0.8), (-0.97, -0.4), (-1.0, 0.0), (-0.98, 0.36), (-0.85, 0.66), (-0.55, 0.84),
                     (-0.22, 0.76), (0, 0.60)))
    n = 36
    uv = resample(np.c_[loop, np.zeros(len(loop))], n + 1)[:-1, :2]
    uu, vv = uv[:, 0], np.clip(uv[:, 1], -1.15, 1)
    x = uu * M.HALF_W * np.maximum(M.outline(np.clip(vv, -0.98, 0.98)), 0.55)
    z = M.CHIN + (vv + 1.0) * 0.5 * (M.TOP - M.CHIN)
    _, y, _ = M.shape(np.clip(uu, -0.97, 0.97), np.clip(vv, -0.98, 0.98))
    h = M.height(x / M.HALF_W, vv) * M.sm(1.0, 0.86, np.abs(uu)) * M.sm(1.0, 0.93, np.abs(vv))
    E = np.stack((x, y + M.DEPTH * h + 0.006, z), axis=1)
    back = np.array((0.0, -1.0, 0.05))
    rows = 11
    P = np.zeros((rows, n, 3))
    for i in range(n):
        d0 = E[i] - C
        r0 = np.linalg.norm(d0)
        d0 /= r0
        for k in range(rows):
            t = k / (rows - 1)
            ang = np.arccos(np.clip(d0 @ back, -1, 1))
            so = max(np.sin(ang), 1e-3)
            d = (np.sin((1 - t) * ang) * d0 + np.sin(t * ang) * back) / so
            q = np.linalg.norm(d / R) ** -1 * (1.0 + 0.012 * np.sin(5 * t * np.pi))
            r = r0 + (q - r0) * M.sm(0.0, 0.22, t)
            P[k, i] = C + d * r
    V, F, ST = grid(P, closed=True)
    return Part("hood", "cloth", V, F, ST, rigid("head", len(V)), "hood", (400, 200))


def horn(side):
    """one of the cap's two great horns, a floppy stuffed cone; its tip and bell swing on a spring chain"""
    n = "R" if side > 0 else "L"
    pts = np.array(((0.055, -0.04, 1.765), (0.135, -0.055, 1.815), (0.225, -0.07, 1.836), (0.31, -0.075, 1.80),
                    (0.375, -0.068, 1.72), (0.405, -0.058, 1.625), (0.412, -0.052, 1.58)))
    pts[:, 0] *= side
    path = resample(pts, 17)
    t = np.linspace(0, 1, 17)
    rd = rmp(t, [0, 0.15, 0.33, 0.55, 0.8, 1.0], [0.085, 0.098, 0.082, 0.058, 0.03, 0.012])
    rd = rd * (1 + 0.07 * np.sin(t * 19.0) * (t > 0.08) * (t < 0.9))      # the cloth's dents
    P = tube(path, rd, 11, lambda a, tt: 1 + 0.1 * np.cos(2 * a) * (1 - tt))
    V, F, ST = grid(P, closed=True)
    ts = np.repeat(t, 11)
    return Part("horn" + n, "cloth", V, F, ST, chain_w("spring_horn%s" % n, ts, 3, 0.35, "head"), "horn", (420, 160)), path


def chain_w(prefix, t, bones, start, parent):
    """weights along a chain of `bones` skinning bones from t = start on, the parent before it"""
    W = {parent: np.zeros(len(t), np.float32)}
    k = np.clip((t - start) / (1 - start), 0, 1) * bones
    for i in range(bones):
        W["%s_%d" % (prefix, i)] = np.clip(1 - np.abs(k - i - 0.5) + 0.0, 0, 1).astype(np.float32)
    W[parent] = np.clip(1 - k * 3.5, 0, 1).astype(np.float32)
    # keep the weights a partition
    tot = sum(W.values())
    return {b: w / np.maximum(tot, 1e-6) for b, w in W.items()}


def bell(side, at, chain):
    n = "R" if side > 0 else "L"
    c = np.array(at)
    rows, cols = 7, 9
    P = np.zeros((rows, cols, 3))
    a = np.linspace(0, 2 * np.pi, cols, endpoint=False)
    for i in range(rows):
        p = np.pi * (i + 0.15) / (rows - 0.7)
        r = np.sin(p) * 0.042 * (1 + 0.15 * M.sm(0.5, 1.0, i / (rows - 1)))
        P[i, :, 0] = c[0] + np.cos(a) * r
        P[i, :, 1] = c[1] + np.sin(a) * r
        P[i, :, 2] = c[2] - np.cos(p) * 0.04 * -1 - 0.03
    V, F, ST = grid(P, closed=True)
    return Part("bell" + n, "metal", V, F, ST, rigid(chain, len(V)), "bell", (64, 64))


def ruff():
    """the great pleated ruff: a lens of folded cloth, its edge a run of scallops, tipped down at the front"""
    pleats, per = 19, 3
    nu = pleats * per
    rows = 8
    a = np.linspace(0, 2 * np.pi, nu, endpoint=False)
    P = np.zeros((rows, nu, 3))
    for i in range(rows):
        t = i / (rows - 1)
        # out along the top (t 0..0.5), back along the underside (0.5..1)
        q = 1 - abs(t * 2 - 1)
        ph = a * pleats
        scal = 1 + 0.085 * np.cos(ph) * q ** 2
        rx = 0.06 + 0.185 * q ** 0.8
        ry = 0.058 + 0.163 * q ** 0.8
        lift = (0.03 if t < 0.5 else -0.03) * (1 - q) + 0.018 * np.sin(ph) * q + (0.016 if t < 0.5 else -0.016) * np.sin(q * np.pi)
        P[i, :, 0] = np.sin(a) * rx * scal
        P[i, :, 1] = np.cos(a) * ry * scal
        P[i, :, 2] = 1.432 + lift - 0.19 * P[i, :, 1] * (0.2 + q) - 0.02 * q ** 2
    V, F, ST = grid(P, closed=True)
    r = np.hypot(V[:, 0], V[:, 1])
    k = M.sm(0.14, 0.07, r) * 0.4
    return Part("ruff", "cloth", V, F, ST, {"hips": 1 - k, "head": k}, "ruff", (480, 120))


def collar():
    """two tiers of torn points over the shoulders and chest, in turn violet and black"""
    out = []
    #     angle from the front, half width (rad), length, tier
    long_ = [(-158, 24, 0.31), (-122, 22, 0.33), (-84, 21, 0.30), (-50, 20, 0.33), (-20, 16, 0.36), (20, 16, 0.36), (50, 20, 0.33),
             (84, 21, 0.30), (122, 22, 0.33), (158, 24, 0.31)]
    short = [(-180, 18, 0.2), (-140, 18, 0.21), (-102, 18, 0.2), (-66, 17, 0.2), (-35, 15, 0.22), (0, 13, 0.2), (35, 15, 0.22), (66, 17, 0.2),
             (102, 18, 0.2), (140, 18, 0.21)]
    for tier, lst in enumerate((long_, short)):
        for i, (deg, hw, L) in enumerate(lst):
            nu, nv = 4, 6
            P = np.zeros((nv, nu, 3))
            c0 = np.radians(deg)
            hw = np.radians(hw)
            for r, t in enumerate(np.linspace(0, 1, nv)):
                # the width narrows to a point, with a torn notch part way down
                w = hw * (1 - t ** 2.2) * (1 - 0.3 * np.exp(-((t - 0.62) / 0.08) ** 2) * ((i * 7 % 3) == 1))
                a = c0 + np.linspace(-1, 1, nu) * w
                sh = np.abs(np.sin(a))              # over the shoulders it stays out; at chest and back it falls
                d = t * L
                rad = 0.062 + d * (0.3 + 0.5 * sh ** 1.2) + 0.02 * tier * 0
                drop = d * (0.92 - 0.42 * sh ** 1.5) + 0.05 * sh * t + 0.004 * tier * -1
                P[r, :, 0] = np.sin(a) * rad * 1.28
                P[r, :, 1] = np.cos(a) * rad * 0.92 + 0.012 * np.cos(a)
                P[r, :, 2] = 1.402 + 0.012 * tier - drop + 0.012 * np.sin(t * 7 + i) * t - 0.1 * np.cos(a) * (rad - 0.06)
            # lie on the chest: the point's belly stays off the torso
            V, F, ST = both(*grid(P))
            r = np.hypot(V[:, 0], V[:, 1])
            k = M.sm(0.09, 0.24, np.abs(V[:, 0])) * 0.8
            W = {"hips": 1 - k, ("pauldron.R" if deg > 0 else "pauldron.L"): k}
            sty = "collar_v" if (i + tier) % 2 == 0 else "collar_k"
            out.append(Part("collar%d_%d" % (tier, i), "cloth", V, F, ST, W, sty, (70, 110)))
    return out


def bow():
    """the ribbon at his throat: two loops and two tails"""
    out = []
    c = np.array((0.0, 0.098, 1.295))
    for side in (1, -1):
        s = side
        # a loop
        pts = [c + (0, 0.004, 0), c + (s * 0.06, 0.01, 0.022), c + (s * 0.115, 0.004, -0.03), c + (s * 0.065, 0.012, -0.06), c + (0, 0.006, -0.008)]
        path = resample(pts, 9)
        P = np.zeros((9, 3, 3))
        for i in range(9):
            for j, w in enumerate((-1, 0, 1)):
                P[i, j] = path[i] + np.array((0, 0.0, w * 0.014 * (0.5 + np.sin(i / 8 * np.pi))))
        V, F, ST = both(*grid(P))
        out.append(Part("bow%d" % side, "cloth", V, F, ST, rigid("hips", len(V)), "ribbon", (60, 110)))
        # a tail
        pts = [c, c + (s * 0.03, 0.012, -0.10), c + (s * 0.02, 0.016, -0.2), c + (s * 0.05, 0.018, -0.3)]
        path = resample(pts, 8)
        P = np.zeros((8, 3, 3))
        for i in range(8):
            t = i / 7
            wd = 0.016 + 0.012 * t
            for j, w in enumerate((-1, 0, 1)):
                P[i, j] = path[i] + np.array((w * wd, 0, (abs(w) * -0.03 if i == 7 else 0)))
        V, F, ST = both(*grid(P))
        out.append(Part("tail%d" % side, "cloth", V, F, ST, rigid("hips", len(V)), "ribbon", (60, 110)))
    # the knot
    P = np.zeros((4, 6, 3))
    a = np.linspace(0, 2 * np.pi, 6, endpoint=False)
    for i, t in enumerate((0, 0.35, 0.7, 1)):
        rr = np.sin(np.pi * (0.1 + 0.8 * t)) * 0.02
        P[i, :, 0] = c[0] + np.cos(a) * rr
        P[i, :, 1] = c[1] + 0.012 + np.sin(a) * rr * 0.7
        P[i, :, 2] = c[2] + 0.018 - t * 0.04
    V, F, ST = grid(P, closed=True)
    out.append(Part("knot", "cloth", V, F, ST, rigid("hips", len(V)), "ribbon", (60, 110)))
    return out


def buttons():
    out = []
    for i, z in enumerate((1.17, 1.105, 1.04)):
        P = np.zeros((4, 8, 3))
        a = np.linspace(0, 2 * np.pi, 8, endpoint=False)
        y0 = 0.086 - (1.17 - z) * 0.13
        for k, (r, dy) in enumerate(((0.002, 0.0), (0.017, -0.001), (0.019, -0.006), (0.018, -0.012))):
            P[3 - k, :, 0] = np.cos(a) * r * 0.75
            P[3 - k, :, 1] = y0 + 0.012 + dy
            P[3 - k, :, 2] = z + np.sin(a) * r * 1.3
        V, F, ST = grid(P, closed=True)
        out.append(Part("btn%d" % i, "cloth", V, F, ST, rigid("hips", len(V)), "button", (24, 24)))
    return out


def tears():
    """rents in the coat's chest and sleeves that open on the Void: patches just off the cloth (hero_void's starfield)"""
    out = []
    spec = [(-0.06, 1.19, 0.05, 0.075, 0.2), (0.075, 1.12, 0.042, 0.07, -0.25)]
    for j, (x, z, w, h, rot) in enumerate(spec):
        a = np.linspace(0, 2 * np.pi, 9, endpoint=False)
        r = 1 + 0.35 * np.sin(a * 3 + j) * np.cos(a * 2)
        ca, sa = np.cos(rot), np.sin(rot)
        lx = np.cos(a) * r * w
        lz = np.sin(a) * r * h
        px = x + lx * ca - lz * sa
        pz = z + lx * sa + lz * ca
        rx = rmp(pz, [1.04, 1.105, 1.185, 1.255], [0.086, 0.1, 0.132, 0.158])
        ry = rmp(pz, [1.04, 1.105, 1.185, 1.255], [0.066, 0.074, 0.086, 0.088])
        e = np.clip(1 - np.abs(px / rx) ** 2.5, 0, 1) ** (1 / 2.5)
        py = e * ry + 0.0065 + 0.006
        V = np.vstack((np.stack((px, py, pz), axis=1), (x, np.interp(z, [1.04, 1.255], [0.076, 0.098]), z)))
        n = len(a)
        F = [[n, i, (i + 1) % n] for i in range(n)]
        F = [f[::-1] for f in F]
        ST = [[(0.5, 0.5), (0.2, 0.2), (0.8, 0.8)] for f in F]
        out.append(Part("rent%d" % j, "void-lining", V, F, ST, rigid("hips", len(V)), "lining", (64, 64)))
    return out


# ---------------------------------------------------------------------------- the wisp, the orb, the halo
WISP_PATH = [(0.0, -0.01, 1.02), (0.0, -0.02, 0.86), (-0.03, -0.03, 0.70), (-0.075, -0.05, 0.54), (-0.095, -0.08, 0.40), (-0.025, -0.11, 0.27),
             (0.075, -0.10, 0.17), (0.13, -0.06, 0.09), (0.085, 0.0, 0.03), (0.0, 0.02, 0.06), (-0.04, -0.01, 0.12)]


def wisp():
    """the smoke he trails: a twisted tapering rope and three strands peeling off it, on a spring chain under the hips"""
    out = []
    path = resample(WISP_PATH, 28)
    t = np.linspace(0, 1, 28)
    rd = rmp(t, [0, 0.12, 0.3, 0.55, 0.8, 1.0], [0.085, 0.14, 0.135, 0.092, 0.05, 0.006])
    tw = lambda a, tt: 1 + 0.18 * np.cos(5 * a + tt * 13.0) + 0.1 * np.cos(3 * a - tt * 7.0)
    V, F, ST = grid(tube(path, rd, 12, tw), closed=True)
    ts = np.repeat(t, 12)
    ST = [[(s, tt) for s, tt in st] for st in ST]
    out.append(Part("wisp", "void-wisp", V, F, ST, chain_w("spring_wisp", ts, 6, 0.0, "hips"), "wisp", (256, 512)))
    # strands
    for j, (a0, st, en, off) in enumerate(((0.8, 0.22, 0.80, 0.11), (2.9, 0.35, 0.95, 0.09), (4.6, 0.15, 0.68, 0.12))):
        q = np.linspace(st, en, 14)
        base = np.stack([np.interp(q, t, path[:, k]) for k in range(3)], axis=1)
        tt = (q - st) / (en - st)
        spread = off * np.sin(tt * np.pi * 0.9) ** 0.8 * (1 + 0.5 * tt)
        p = base + np.stack((np.cos(a0 + tt * 3) * spread, np.sin(a0 + tt * 3) * spread, 0 * tt), axis=1)
        rr = rmp(tt, [0, 0.2, 0.7, 1], [0.012, 0.03, 0.017, 0.002])
        V, F, ST = grid(tube(p, rr, 6), closed=True)
        # (v of the whole wisp, so all of it fades together)
        ST = [[(s, st + (en - st) * tv) for s, tv in c] for c in ST]
        ts = np.repeat(q, 6)
        out.append(Part("strand%d" % j, "void-wisp", V, F, ST, chain_w("spring_wisp", ts, 6, 0.0, "hips"), "wisp", (256, 512)))
    return out, path


ORB_LOCAL = (-0.15, 0.0, -0.125)        # the orb from the right wrist at rest: off the palm, a little down the fingers


def orb(at):
    out = []
    c = np.array(at)
    rows, cols = 8, 12
    P = np.zeros((rows, cols, 3))
    a = np.linspace(0, 2 * np.pi, cols, endpoint=False)
    for i in range(rows):
        p = np.pi * i / (rows - 1)
        P[i, :, 0] = c[0] + np.cos(a) * np.sin(p) * 0.098
        P[i, :, 1] = c[1] + np.sin(a) * np.sin(p) * 0.098
        P[i, :, 2] = c[2] + np.cos(p) * 0.098
    V, F, ST = grid(P, closed=True)
    out.append(Part("orbcore", "void-orb", V, F, ST, rigid("x_weapon", len(V)), "orbcore", (64, 64)))
    # three swirling ribbons hugging it, opposite faces glowing
    for j in range(3):
        n = 22
        tt = np.linspace(0, 1, n)
        ang = tt * 4.4 + j * 2.09
        tilt = 0.55 + j * 0.5
        r = 0.104 + 0.075 * (tt ** 1.4)
        ca, sa = np.cos(ang), np.sin(ang)
        p = np.stack((ca * r, sa * r * np.cos(tilt), sa * r * np.sin(tilt)), axis=1) + c
        nrm = np.array((0, -np.sin(tilt), np.cos(tilt)))
        wd = rmp(tt, [0, 0.3, 1], [0.05, 0.03, 0.002])
        P = np.zeros((n, 2, 3))
        for i in range(n):
            P[i, 0] = p[i] - (p[i] - c) / np.linalg.norm(p[i] - c) * wd[i] * 0.5 + nrm * 0.0
            P[i, 1] = p[i] + (p[i] - c) / np.linalg.norm(p[i] - c) * wd[i] * 0.5
        V, F, ST = both(*grid(P))
        out.append(Part("orbswirl%d" % j, "glow-orb", V, F, ST, rigid("x_weapon", len(V)), "orbswirl", (64, 128)))
    return out


HALO_C = np.array((0.0, -0.25, 1.69))
HALO_R = 0.415
HALO_TILT = np.radians(19)          # leaned back so the match camera sees its face


def halo():
    """the great cracked crescent behind his head: a plate with a ridge, wider than the head and the cap's horns, opening up to his left"""
    n = 40
    t = np.linspace(0, 1, n)
    # angle measured in the plane: +x is his right; the crescent runs from upper-left (his), over the top? no: from the high tip on his
    # left, down round his right and under, to the low tip on his left (front view: open to the viewer's upper right)
    a = np.radians(rmp(t, [0, 1], [62, 322]))
    wd = (np.sin(t * np.pi) ** 0.75) * 0.135 + 0.004
    wd *= 1 + 0.08 * np.sin(t * 23) + 0.05 * np.sin(t * 47)
    rows = np.array((-1.0, -0.32, 0.32, 1.0))
    P = np.zeros((6, n, 3))
    c, s = np.cos(HALO_TILT), np.sin(HALO_TILT)
    for k, (q, dp) in enumerate(((1.0, 0.0), (0.32, 0.022), (-0.5, 0.012), (-1.0, 0.0), (0.0, -0.02), (1.0, 0.0))):
        r = HALO_R - wd * 0.5 + q * wd * 0.5 * 1.0
        lx = -np.cos(a) * r
        lz = np.sin(a) * r
        ly = np.full(n, dp) * (wd / 0.16)
        P[k, :, 0] = HALO_C[0] + lx
        P[k, :, 1] = HALO_C[1] + ly * c - lz * s * -1 * -1
        P[k, :, 2] = HALO_C[2] + lz * c + ly * s
    V, F, ST = grid(P)
    # the shards flung from its cracks
    Vs, Fs, STs = [V], list(F), list(ST)
    base = len(V)
    rng = np.random.RandomState(4)
    for i, (deg, off, sz) in enumerate(((215, 0.09, 0.03), (240, -0.11, 0.022), (300, 0.08, 0.024), (120, 0.09, 0.02), (165, -0.1, 0.018), (280, -0.1, 0.016))):
        aa = np.radians(deg)
        rr = HALO_R + off
        ct = np.array((HALO_C[0] - np.cos(aa) * rr, HALO_C[1] - np.sin(aa) * rr * s, HALO_C[2] + np.sin(aa) * rr * c))
        d = rng.normal(size=(4, 3))
        d /= np.linalg.norm(d, axis=1, keepdims=True)
        tet = ct + d * sz * np.array((1.2, 0.5, 1.4))
        Vs.append(tet)
        b = base
        Fs += [[b, b + 1, b + 2], [b, b + 2, b + 3], [b, b + 3, b + 1], [b + 1, b + 3, b + 2]]
        STs += [[(0.1, 0.5), (0.12, 0.5), (0.1, 0.52)]] * 4
        base += 4
    V = np.vstack(Vs)
    return Part("halo", "glow-halo", V, Fs, STs, rigid("x_halo", len(V)), "halo", (512, 160))


def eye_ball(side):
    u, v = M.eyes()[0 if side > 0 else 1]
    u, v = np.array([u]), np.array([v])
    x = u * M.HALF_W
    _, y, z = M.shape(u / np.maximum(M.outline(v), 0.3), v)
    h = M.height(u, v)
    c = np.array((x[0], y[0] + M.DEPTH * h[0] + 0.003, z[0]))
    rows, cols = 6, 8
    P = np.zeros((rows, cols, 3))
    a = np.linspace(0, 2 * np.pi, cols, endpoint=False)
    for i in range(rows):
        p = np.pi * i / (rows - 1)
        P[i, :, 0] = c[0] + np.cos(a) * np.sin(p) * 0.024
        P[i, :, 1] = c[1] + np.sin(a) * np.sin(p) * 0.01
        P[i, :, 2] = c[2] + np.cos(p) * 0.016
    V, F, ST = grid(P, closed=True)
    return Part("eye" + ("R" if side > 0 else "L"), "glow-eyes", V, F, ST, rigid("x_lid." + ("R" if side > 0 else "L"), len(V)), "eye", (32, 32)), c
