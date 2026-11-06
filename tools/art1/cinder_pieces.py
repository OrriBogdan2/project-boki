"""ART-1 Cinder: the rebuilt pieces (head and face, goggles, fins, fire hair, tail, tank, hoses, nozzle gun, hands, vials) as data.
Blender frame: Z up, she faces +Y, her right hand is +X. See /home/boki/shots-s2/art1/STYLE_NOTES.md.
Flame pieces are strips with raw UV (u across, v root to tip) and their seed in the vertex colour: shaders/hero_flame.gdshader."""
import json, os
import numpy as np
from meshkit import (Piece, catmull, norm, smooth, sweep, sd_ell, sd_cap, smin, smax, rot_about, frames)

HERE = os.path.dirname(os.path.abspath(__file__))
_rig = json.load(open(os.path.join(HERE, "..", "..", "art", "wardens", "src", "cinder_rig.json")))["bones"]


def J(b):
    x, y, z = _rig[b]["head"]
    return np.array([x, -z, y], float)


SH = J("upper_arm.R")[0]
SHOULDER_Z, ELBOW_Z, HAND_Z = J("upper_arm.R")[2], J("forearm.R")[2], J("hand.R")[2]
NECK_Z = J("head")[2]
HIPS_Z = J("hips")[2]
THIGH_Z = J("thigh.R")[2]
THIGH_X = J("thigh.R")[0]
ANKLE_Z = 0.09
HEAD_MAT = "skin-cinderhead-hot"              # the head's own surface and texture (2x density)
HS = 0.9                                      # head size
C = np.array([0.0, 0.016, NECK_Z + 0.127])    # the head's centre
EYE = np.array([0.042, 0.066, -0.0085])       # head-local; x mirrored
EYE_R = 0.0255
SEC6 = [(np.cos(t), np.sin(t)) for t in np.linspace(0, 2 * np.pi, 6, endpoint=False)]
SEC8 = [(np.cos(t), np.sin(t)) for t in np.linspace(0, 2 * np.pi, 8, endpoint=False)]


def hl(p):
    """Head-local -> world."""
    return C + np.asarray(p, dtype=np.float64) * HS


def mouth_z(x):
    """The lips' parting (the bottom of the upper teeth), head-local: the grin, corners high."""
    return -0.0745 + 5.5 * np.asarray(x) ** 2


def head_sdf(p):
    """To the head sheet: an oval face, a small pointed chin, a fine nose, a closed smile."""
    d = sd_ell(p, (0, -0.014, 0.030), (0.080, 0.094, 0.084))
    d = smin(d, sd_ell(p, (0, 0.016, -0.030), (0.066, 0.072, 0.082)), 0.02)
    d = smin(d, sd_ell(p, (0, 0.034, -0.086), (0.036, 0.044, 0.036)), 0.024)
    for s in (-1.0, 1.0):
        d = smin(d, sd_cap(p, (s * 0.014, 0.082, 0.012), (s * 0.066, 0.056, 0.024), 0.0055), 0.014)     # the brow's bone
        d = smin(d, sd_ell(p, (s * 0.052, 0.062, -0.034), (0.022, 0.021, 0.016)), 0.016)                # the cheek
        d = smax(d, -sd_ell(p, (s * 0.042, 0.098, -0.0085), (0.027, 0.016, 0.012)), 0.008)              # the socket
        d = smax(d, -sd_ell(p, (s * 0.0345, 0.092, -0.069), (0.004, 0.009, 0.006)), 0.005)              # the smile's corner
        d = smin(d, sd_ell(p, (s * 0.0105, 0.094, -0.0555), (0.0055, 0.006, 0.005)), 0.005)             # the nose's wing
    d = smin(d, sd_cap(p, (0, 0.080, 0.004), (0, 0.0985, -0.046), 0.0052), 0.012)                       # the nose
    d = smin(d, sd_ell(p, (0, 0.0995, -0.0515), (0.0085, 0.008, 0.0068)), 0.006)
    d = smin(d, sd_cap(p, (-0.02, 0.0885, -0.0725), (0.02, 0.0885, -0.0725), 0.0042), 0.007)            # the upper lip
    d = smin(d, sd_cap(p, (-0.016, 0.0875, -0.0805), (0.016, 0.0875, -0.0805), 0.0052), 0.007)          # the lower lip
    return d


def ray_y(x, z, y0=0.17, steps=48):
    x, z = np.asarray(x, float), np.asarray(z, float)
    y = np.full(x.shape, y0)
    for _ in range(steps):
        d = head_sdf(np.stack([x, y, z], -1))
        y = y - np.clip(d, -0.01, 0.02) * 0.9
    return y


def ray_out(ang, z, r0=0.2, steps=48):
    ang, z = np.asarray(ang, float), np.asarray(z, float)
    dirx, diry = np.sin(ang), np.cos(ang)
    r = np.full(ang.shape, r0)
    for _ in range(steps):
        d = head_sdf(np.stack([dirx * r, diry * r, z], -1))
        r = np.maximum(r - np.clip(d, -0.01, 0.03) * 0.9, 0.004)
    return r


def grid_faces(rows, cols, wrap=False):
    f = []
    for i in range(rows - 1):
        for j in range(cols - (0 if wrap else 1)):
            a = i * cols + j
            b = i * cols + (j + 1) % cols
            f.append([a, b, b + cols, a + cols])
    return f


def half_width(z):
    """The head's half width at height z (head-local), a little behind the face's middle: the face patch's columns stop at the head's real edge, so none
    hang in the air."""
    z = np.asarray(z, float)
    x = np.full(z.shape, 0.14)
    for _ in range(40):
        d = head_sdf(np.stack([x, np.full(z.shape, 0.03), z], -1))
        x = np.maximum(x - np.clip(d, -0.01, 0.02) * 0.9, 0.002)
    return x


FACE_U = np.concatenate([np.linspace(-1.0, -0.8, 3), np.linspace(-0.68, 0.68, 21), np.linspace(0.8, 1.0, 3)])


def face_parts():
    """The front of the head, its own dense pass: an upper patch and a jaw patch split along the lips, so the jaw bone opens a real mouth; past the corners both share a
    line. Columns stop at the head's real edge."""
    U = FACE_U
    x_est = np.abs(U) * 0.072
    mz = mouth_z(np.minimum(x_est, 0.05))
    ztop = [0.104, 0.08, 0.055, 0.032, 0.02, 0.008, -0.004, -0.016, -0.028, -0.04, -0.05, -0.058]
    ks = (0.4, 0.75, 1.0)                        # (the last rows ease down onto the lips' line, which runs high at the corners)
    ZU = np.zeros((len(ztop) + len(ks), len(U)))
    for i, z in enumerate(ztop):
        ZU[i] = z
    for i, k in enumerate(ks):
        ZU[len(ztop) + i] = ztop[-1] + (mz - ztop[-1]) * k
    XU = U[None, :] * half_width(ZU)
    YU = np.maximum(ray_y(XU, ZU), 0.0)
    up = Piece("face", HEAD_MAT, hl(np.stack([XU, YU, ZU], -1).reshape(-1, 3)), grid_faces(ZU.shape[0], len(U))).rigid("head")
    fr = np.array([0.0, 0.14, 0.3, 0.5, 0.74, 1.0])
    ZL = np.stack([mz + (-0.126 - mz) * k for k in fr])
    XL = U[None, :] * half_width(ZL)
    XL[0] = XU[-1]
    YL = np.maximum(ray_y(XL, ZL), 0.0)
    v = hl(np.stack([XL, YL, ZL], -1).reshape(-1, 3))
    lo = Piece("jaw", HEAD_MAT, v, grid_faces(len(ZL), len(U)))
    w = smooth(0.05, 0.03, np.abs(XL)).ravel()
    lo.w = {"jaw": w, "head": 1 - w}
    return [up, lo]


def mouth_back():
    """What a parted jaw shows: dark, set back, on the head."""
    xs = np.linspace(-0.034, 0.034, 4)
    zs = np.linspace(-0.066, -0.1, 3)
    X, Z = np.meshgrid(xs, zs)
    Y = np.full(X.shape, 0.06)
    return Piece("mouthb", HEAD_MAT, hl(np.stack([X, Y, Z], -1).reshape(-1, 3)), grid_faces(3, 4)).rigid("head")


def teeth():
    """The upper teeth, behind the lips: only a parted jaw shows them."""
    xs = np.linspace(-0.027, 0.027, 5)
    Z0 = mouth_z(xs) + 0.0015
    Z1 = Z0 - 0.0095
    Y0 = ray_y(xs, Z0) - 0.0065
    v = [(x, y, z) for x, y, z in zip(xs, Y0, Z0)] + [(x, y, z) for x, y, z in zip(xs, Y0 - 0.0015, Z1)]
    return Piece("teeth", HEAD_MAT, hl(np.array(v)), grid_faces(2, 5)).rigid("head")


def fangs():
    """Two small upper fangs, real geometry so they catch in profile."""
    out = []
    for s in (1.0, -1.0):
        x = s * 0.0178
        z0 = float(mouth_z(x)) + 0.0015
        y = float(ray_y(np.array([x]), np.array([z0]))[0]) + 0.0008
        base = [(x - 0.0031, y, z0), (x + 0.0031, y, z0), (x, y + 0.0024, z0), (x, y - 0.003, z0)]
        tip = (x, y + 0.0008, z0 - 0.0125)
        out.append(Piece("fang" + ("R" if s > 0 else "L"), HEAD_MAT, hl(np.array(base + [tip])),
                         [[1, 0, 4], [2, 1, 4], [0, 2, 4], [0, 3, 2], [3, 1, 2]]).rigid("head"))
    return out


def skull():
    """The rest of the head, coarse: it sits under the goggles and the fire."""
    rows, cols = 7, 12
    zs = np.linspace(0.112, -0.135, rows)
    angs = np.linspace(0, 2 * np.pi, cols, endpoint=False)
    A, Z = np.meshgrid(angs, zs)
    # (coarse: well inside the face patch at the front, or its corners poke through the cheeks)
    R = ray_out(A, Z, r0=0.14) * (0.975 - 0.2 * smooth(0.0, 0.7, np.cos(A)))
    v = hl(np.stack([np.sin(A) * R, np.cos(A) * R, Z], -1).reshape(-1, 3))
    return Piece("skull", "skin-cinder-hot", v, grid_faces(rows, cols, True)).rigid("head")


def lids(s):
    """The upper lid: a shell on the eye that sits up under the brow at rest (the eye is painted on the face) and turns down on
    its bone for a blink or a narrow."""
    c = EYE * [s, 1, 1] + [0, -0.004, 0]
    rows, cols = 3, 7
    v = []
    for i in range(rows):
        for j in range(cols):
            az = (j / (cols - 1) - 0.5) * 1.9
            el = 0.95 + 0.8 * i / (rows - 1)
            r = EYE_R * 1.15
            v.append(c + np.array([np.sin(az) * s * np.cos(el) * 1.34, np.cos(az) * np.cos(el), np.sin(el) * 0.82]) * r)
    p = Piece("lid" + ("R" if s > 0 else "L"), HEAD_MAT, hl(v), grid_faces(rows, cols))
    p.rigid("lid." + ("R" if s > 0 else "L"))
    return p


def brows(s):
    """The head sheet's glowing arched brows, lying on the plate's own, so a raise moves fire over fire."""
    side = "R" if s > 0 else "L"
    pts = [(0.0155, 0.0905, 0.0122), (0.03, 0.0865, 0.0255), (0.0447, 0.0765, 0.0304), (0.0678, 0.0545, 0.0287)]
    q = np.array(pts) * [s, 1, 1] + [0, 0.002, 0]
    path = catmull(q, 7)
    wd = 0.0042 * np.array([0.8, 1.0, 1.0, 0.92, 0.78, 0.5, 0.06])
    b = sweep("brow" + side, HEAD_MAT, hl(path), [(-1, 0), (0, 0.3), (1, 0), (0, -0.3)], wd * HS, side_hint=np.array([0, 0.5, 1.0]), room=0.0)
    return [b.rigid("brow." + side)]


def goggles():
    """Up on her brow: two brass cups with cracked lenses, a bridge, the strap round the head under the fire."""
    out = []
    tilt = np.radians(32)
    up = np.array([0, np.sin(tilt), np.cos(tilt)])
    for s in (1.0, -1.0):
        side = "R" if s > 0 else "L"
        c = np.array([s * 0.04, 0.073, 0.094])
        d = norm(np.array([s * 0.26, 0.72, 0.62]))
        loc = lambda t, r: None
        k = norm(np.cross(d, (0, 0, 1)))
        l2 = norm(np.cross(d, k))
        ring = [(0.012, -0.014), (0.0285, -0.014), (0.0325, 0.0), (0.030, 0.014), (0.024, 0.015), (0.0222, 0.005)]
        v, f = [], []
        n = 10
        for rr, dd in ring:
            for a in np.linspace(0, 2 * np.pi, n, endpoint=False):
                v.append(c + (k * np.cos(a) + l2 * np.sin(a)) * rr + d * dd)
        for i in range(len(ring) - 1):
            for j in range(n):
                a, b = i * n + j, i * n + (j + 1) % n
                f.append([a, b, b + n, a + n])
        out.append(Piece("gogR" + side, "metal-cinder", hl(v), f).rigid("head"))
        v2 = [c + (k * np.cos(a) + l2 * np.sin(a)) * 0.0228 + d * 0.0045 for a in np.linspace(0, 2 * np.pi, n, endpoint=False)]
        v2.append(c + d * 0.009)
        f2 = [[j, (j + 1) % n, n] for j in range(n)]
        lens = Piece("lens" + side, "metal-cinder", hl(v2), f2).rigid("head")
        lens.frame = (hl(c), k, l2, 0.0228 * HS, s)
        out.append(lens)
    bridge = sweep("gogB", "metal-cinder", hl(catmull([(-0.013, 0.1, 0.108), (0, 0.104, 0.112), (0.013, 0.1, 0.108)], 3)), SEC6[::2] + SEC6[1::2][:0], np.full(3, 0.0065), side_hint=np.array([0, 0, 1.0]))
    out.append(bridge.rigid("head"))
    # the strap: round the skull from cup to cup, behind
    angs = np.radians(np.linspace(52, 308, 11))
    z0 = 0.08
    r = ray_out(angs, np.full(angs.shape, z0)) + 0.0045
    path = np.stack([np.sin(angs) * r, np.cos(angs) * r, z0 + 0.004 * np.cos(angs) - 0.012 * (1 - np.cos(angs))], -1)
    st = sweep("strap", "leather-cinder", hl(path), [(-1, 0.25), (1, 0.25), (1, -0.25), (-1, -0.25)], np.full(11, 0.0125),
               side_hint=np.array([0, 0, 1.0]))
    out.append(st.rigid("head"))
    return out


def fin(s):
    """A fin ear (head sheet): a tall point up and out, a scalloped web under it down to the jaw. Two sheets back to back."""
    side = "R" if s > 0 else "L"
    tips = [np.array([s * 0.172, -0.012, 0.094]), np.array([s * 0.158, -0.02, 0.032]), np.array([s * 0.136, -0.016, -0.022]), np.array([s * 0.106, -0.004, -0.066])]
    roots = [np.array([s * 0.074, 0.006, 0.026]), np.array([s * 0.077, 0.002, 0.008]), np.array([s * 0.077, 0.002, -0.012]), np.array([s * 0.072, 0.012, -0.034])]
    rows = 4
    G = []
    for r0, t in zip(roots, tips):
        for k in range(rows):
            u = k / (rows - 1)
            G.append(r0 + (t - r0) * u + np.array([0, 0.012, 0]) * np.sin(u * np.pi))
    # the web between: a column sagging in from the spines, for the scallop
    sp = len(tips)
    verts, kk = [], []
    for i in range(sp):
        for k in range(rows):
            verts.append(G[i * rows + k])
            kk.append(k / (rows - 1))
        if i < sp - 1:
            for k in range(rows):
                u = k / (rows - 1)
                m = (G[i * rows + k] + G[(i + 1) * rows + k]) / 2
                r_m = (G[i * rows] + G[(i + 1) * rows]) / 2
                verts.append(r_m + (m - r_m) * (1 - 0.24 * u * u))
                kk.append(u * 0.8)
    cols = 2 * sp - 1
    verts = hl(np.array(verts))
    fa = []
    for i in range(cols - 1):
        for k in range(rows - 1):
            a = i * rows + k
            fa.append([a, a + 1, a + rows + 1, a + rows])
    # (the ear faces forward: its true normal, or the two sheets lie on each other and fight)
    nrm = norm(np.cross(tips[0] - roots[0], tips[3] - roots[0]))
    if nrm[1] < 0:
        nrm = -nrm
    n = len(verts)
    # (wound so the front sheet faces out on either side)
    q0 = verts[fa[0]]
    if np.dot(np.cross(q0[1] - q0[0], q0[2] - q0[0]), nrm) < 0:
        fa = [q[::-1] for q in fa]
    allv = np.vstack([verts, verts - nrm * 0.004])
    p = Piece("fin" + side, HEAD_MAT, allv, fa + [[x + n for x in q[::-1]] for q in fa])
    kk = np.tile(np.array(kk), 2)
    p.w = {"head": 1 - smooth(0.0, 0.3, kk), "fin." + side: smooth(0.0, 0.3, kk)}
    return p


# ------------------------------------------------------------------ fire
def strip(name, mat, pts, width, rows=6, hint=(0, 1, 0), seed=None, bright=0.0, tent=0.22, peak=0.3, root=0.5):
    """One tongue of fire: three columns of verts along a path (a shallow tent, so it's no flat card). Raw UV: u across, v along.
    width: the widest, m; root: its share at the root; it narrows to a point. One-sided faces, drawn from both (cull_disabled)."""
    path = catmull(pts, rows)
    k = np.linspace(0, 1, rows)
    prof = np.minimum(1.0, root + k / peak * (1 - root)) * (1 - smooth(peak, 1.0, k)) ** 0.75
    wd = width * np.maximum(prof, 0.05)
    t, s, nn = frames(path, np.asarray(hint, float))
    v, uv = [], []
    for i in range(rows):
        for u, off in ((0.0, -1.0), (0.5, 0.0), (1.0, 1.0)):
            v.append(path[i] + s[i] * off * wd[i] * 0.5 + nn[i] * (1 - abs(off)) * wd[i] * tent)
            uv.append((u, k[i]))
    f, fuv = [], []
    for i in range(rows - 1):
        for j in range(2):
            a = i * 3 + j
            q = [a, a + 1, a + 4, a + 3]
            f.append(q)
            fuv.append([uv[x] for x in q])
    p = Piece(name, mat, v, f, fuv, room=0.0)
    p.flame = True
    p.t = np.repeat(k, 3)
    p.path = path
    sd = (hash(name) % 997) / 997.0 if seed is None else seed
    p.fire = (sd, bright, 1.0)
    return p


def drape(name, pts, width, rows=9, cols=5, hint=(0, 1, 0), seed=0.5, bright=0.0, bulge=0.2, root=0.75, peak=0.45, outward=None):
    """A broad curtain of fire: a curved sheet along a path, wide most of its way and tapering at its end. Its fire runs in long streaks, no strip's outline (vertex colour b: 0)."""
    path = catmull(pts, rows)
    k = np.linspace(0, 1, rows)
    prof = np.minimum(1.0, root + k / peak * (1 - root)) * (1 - smooth(0.62, 1.0, k) * 0.72)
    wd = width * prof
    t, s, nn = frames(path, np.asarray(hint, float))
    if outward is not None and np.dot(nn[rows // 2], outward) < 0:
        nn = -nn
    v, uv = [], []
    for i in range(rows):
        for c in range(cols):
            u = c / (cols - 1)
            a = (u - 0.5) * np.pi
            v.append(path[i] + s[i] * np.sin(a) * wd[i] * 0.5 + nn[i] * np.cos(a) * wd[i] * bulge)
            uv.append((u, k[i]))
    f, fuv = [], []
    for i in range(rows - 1):
        for j in range(cols - 1):
            a = i * cols + j
            q = [a, a + 1, a + cols + 1, a + cols]
            f.append(q)
            fuv.append([uv[x] for x in q])
    p = Piece(name, "flame-hair", v, f, fuv, room=0.0)
    p.flame = True
    p.t = np.repeat(k, cols)
    p.path = path
    p.fire = (seed, bright, 0.0)
    return p


HAIR_BONES = {"c": 4, "l": 5, "r": 5}


def _on_skull(th, al):
    d = np.array([np.sin(th) * np.sin(al), np.cos(th), np.sin(th) * np.cos(al)])
    r = 0.14
    for _ in range(40):
        r = max(r - float(head_sdf((d * r)[None, :])[0]) * 0.9, 0.01)
    return hl(d * r * 0.98), d


def hair():
    """A soft mass of fire, as the sheets: a body swept back off the brow, long curtains pouring past the shoulders round the tank, a short fall at the nape; tall
    smooth flames stand off the crown (the master sheet) so it reads from straight above. Crown: on the head (the shader licks it); curtains: on spring chains."""
    out = []
    top = C[2] + 0.06
    h = C[2]
    # the body over the skull, brow to nape, three sheets side by side
    for i, x in enumerate((-0.062, 0.0, 0.062)):
        b_ = drape("crownb%d" % i, [(x * 1.25, 0.012, h + 0.118), (x * 1.5, -0.03, h + 0.155), (x * 1.6, -0.09, h + 0.15), (x * 1.6, -0.14, h + 0.095), (x * 1.5, -0.15, h + 0.02)], 0.15, rows=7, cols=4, hint=(0, 0, 1),
                   seed=0.12 + 0.3 * i, bright=0.1, outward=np.array([0, 0, 1.0]), root=0.9, peak=0.3)
        out.append(b_.rigid("head"))
    # tall flames off the crown (master sheet), smooth S curves
    crown = [(-48, 0.19, 0.115), (-24, 0.26, 0.135), (-4, 0.31, 0.15), (18, 0.27, 0.14), (42, 0.2, 0.12), (-30, 0.2, 0.12), (6, 0.24, 0.13), (32, 0.18, 0.115)]
    for i, (az, ln, w) in enumerate(crown):
        a = np.radians(az)
        back = i >= 5
        p0, d0 = _on_skull(np.radians(128 if back else 96), a)        # (behind the goggles)
        o = norm(d0 * 0.34 + np.array([0, -0.16, 1.0]))
        side = norm(np.cross(o, (0, 1, 0)) + 1e-6)
        k_ = 0.05 * (1 if i % 2 else -1)
        pts = [p0 - o * 0.03, p0 + o * ln * 0.3 + side * k_ * 0.6, p0 + o * ln * 0.62 - side * k_ * 0.3 + [0, -0.015, 0], p0 + o * ln * 0.84 - side * k_ + [0, -0.03, 0], p0 + o * ln + side * k_ * 0.2 + [0, -0.05, 0]]
        s_ = strip("crown%d" % i, "flame-hair", pts, w * 1.2, rows=9, hint=np.array([0, 1.0, 0.0]) + np.cross(d0, o) * (abs(az) / 60.0) + 1e-3, seed=i * 0.083, bright=0.2, root=0.85, tent=0.3)
        out.append(s_.rigid("head"))
    chains = {}
    # the curtains: past the fin, over the shoulder, out and back round the tank; a second layer behind it
    for sg, g in ((1.0, "r"), (-1.0, "l")):
        rad = norm(np.array([sg, -0.6, 0.0]))
        a_ = drape("sideA" + g, [(sg * .05, -.05, top + .04), (sg * .082, -.1, top - .06), (sg * .13, -.125, top - .2), (sg * .185, -.125, top - .38), (sg * .21, -.135, top - .54), (sg * .245, -.15, top - .68), (sg * .275, -.17, top - .8)],
                   0.25, rows=10, hint=rad, seed=0.11 + sg * .03, bright=0.12, outward=rad, root=0.42, peak=0.5)
        out.append(a_)
        a_.group = g
        rad2 = norm(np.array([sg, -1.2, 0.0]))
        b_ = drape("sideB" + g, [(sg * .045, -.085, top + .03), (sg * .095, -.13, top - .1), (sg * .135, -.15, top - .26), (sg * .185, -.165, top - .42), (sg * .235, -.185, top - .56), (sg * .285, -.215, top - .66)],
                   0.23, rows=9, hint=rad2, seed=0.47 + sg * .04, bright=0.0, outward=rad2)
        out.append(b_)
        b_.group = g
        # loose tongues off the curtains' ends and one framing the face
        for j, (x0, y0, z0, wd_) in enumerate(((.205, -.12, -.56, .1), (.17, -.1, -.64, .09))):
            t_ = strip("sidetg%s%d" % (g, j), "flame-hair", [(sg * x0, y0, top + z0), (sg * (x0 + .03), y0 - .01, top + z0 - .1), (sg * (x0 + .015), y0 - .02, top + z0 - .2), (sg * (x0 + .05), y0 - .03, top + z0 - .3)],
                       wd_, rows=6, hint=rad, seed=0.21 * j + 0.4, bright=0.1, root=0.8)
            t_.group = g
            out.append(t_)
        d_ = strip("sideD" + g, "flame-hair", [(sg * .074, .03, top - .025), (sg * .096, .014, top - .12), (sg * .108, .028, top - .24), (sg * .112, .018, top - .36), (sg * .126, .03, top - .46)], 0.08, rows=7,
                   hint=np.array([0.3 * sg, 1.0, 0.2]), seed=0.84 + sg * .02, bright=0.2)
        d_.group = g
        out.append(d_)
        chains[g] = np.array([a_.path[int(round(x))] for x in np.linspace(2, 9, HAIR_BONES[g] + 1)])
    nape = drape("nape", [(0, -.1, top + .0), (0, -.13, top - .1), (0, -.135, top - .22), (.012, -.125, top - .34), (0, -.12, top - .42)], 0.2, rows=7, hint=(0, -1.0, 0), seed=0.33, outward=np.array([0, -1.0, 0]))
    nape.group = "c"
    out.append(nape)
    chains["c"] = np.array([nape.path[int(round(x))] for x in np.linspace(1, 6, HAIR_BONES["c"] + 1)])
    return out, chains


def weight_falls(locks, chains):
    """Each fall's verts ride the chain of its group by how far down it they are; the root stays on the head."""
    for p in locks:
        g = getattr(p, "group", None)
        if g is None:
            continue
        pts = chains[g]
        nb = len(pts) - 1
        names = ["spring_scarftail_hair%s_%d" % (g, i) for i in range(nb + 1)]
        w = {n: np.zeros(len(p.v)) for n in names[:-1]}
        w["head"] = np.zeros(len(p.v))
        for i, t in enumerate(p.t):
            u = float(smooth(0.08, 0.26, t))
            x = np.clip((t - 0.12) / 0.88, 0, 0.9999) * (nb - 1)
            b = int(x)
            q = x - b
            w["head"][i] = 1 - u
            w[names[b]][i] += u * (1 - q)
            w[names[min(b + 1, nb - 1)]][i] += u * q
        p.w = w


# ------------------------------------------------------------------ the tail
TAIL_N = 9
TAIL_PTS = [(0, -.055, HIPS_Z + .075), (0, -.15, HIPS_Z - .05), (.03, -.29, HIPS_Z - .26), (.13, -.42, HIPS_Z - .46), (.31, -.50, HIPS_Z - .58), (.52, -.47, HIPS_Z - .6),
            (.70, -.33, HIPS_Z - .56), (.80, -.12, HIPS_Z - .46), (.82, .10, HIPS_Z - .30)]


def tail():
    """A long tapering tail: out behind her, then low round her right side in a wide arc, the tip up: it reads from straight above whichever way she faces."""
    rows = 17
    path = catmull(TAIL_PTS, rows)
    k = np.linspace(0, 1, rows)
    wd = 0.078 * (1 - k) ** 0.85 + 0.009
    p = sweep("tail", "skin-cinder-hot", path, SEC8[::1], wd, side_hint=np.array([0, 0, 1.0]), depth=wd * 0.92)
    p.t = np.repeat(k, 8)
    p.path = path
    p.wd = wd
    return p


def tail_flames(tl):
    """Fire along her tail: a fringe licking off its outer curve, and the burning tip."""
    out = []
    path, wd = tl.path, tl.wd
    t_, s_, n_ = frames(path, np.array([0, 0, 1.0]))
    n = len(path)
    for i, u in enumerate((0.16, 0.26, 0.36, 0.46, 0.56, 0.66, 0.76, 0.84)):
        c = int(u * (n - 1))
        base = path[c]
        o = norm(n_[c] * 0.9 - s_[c] * 0.4 + np.array([0, 0, 0.35]))
        ln = 0.13 + 0.05 * np.sin(i * 1.9)
        fl = strip("tflame%d" % i, "flame-jet", [base + o * wd[c] * 0.5, base + o * (wd[c] + ln * 0.4) - t_[c] * 0.02, base + o * (wd[c] + ln * 0.8) - t_[c] * 0.07,
                                                 base + o * (wd[c] + ln * 1.2) - t_[c] * 0.13], 0.1, rows=4, hint=np.cross(o, t_[c]), seed=0.09 * i, bright=0.1, root=0.9)
        fl.tail_u = u
        out.append(fl)
    tip = path[-1]
    tg = norm(path[-1] - path[-3])
    up = norm(tg + np.array([0, 0, 0.9]))
    for i, a in enumerate((0.0, 1.05, 2.1)):
        side = np.array([np.cos(a), np.sin(a), 0.0])
        ln = 0.3 - 0.05 * i
        fl = strip("tiptop%d" % i, "flame-jet", [tip - up * 0.04, tip + up * ln * 0.35 + side * 0.012, tip + up * ln * 0.7 - side * 0.015, tip + up * ln + side * 0.01], 0.15 - 0.02 * i,
                   rows=5, hint=side, seed=0.33 + 0.2 * i, bright=0.5, root=0.9)
        fl.tail_u = 0.985
        out.append(fl)
    return out


def weight_tail(tl, flames, pts):
    names = ["spring_scarftail_tail_%d" % i for i in range(TAIL_N)]
    nb = TAIL_N - 1

    def set_w(pc, ts):
        w = {n: np.zeros(len(pc.v)) for n in names[:-1]}
        w["root"] = np.zeros(len(pc.v))
        for i, t in enumerate(ts):
            u = float(smooth(0.0, 0.08, t))
            x = np.clip(t, 0, 0.9999) * (nb - 1 + 0.999)
            b = int(x)
            q = x - b
            w["root"][i] = 1 - u
            w[names[min(b, nb - 1)]][i] += u * (1 - q)
            w[names[min(b + 1, nb - 1)]][i] += u * q
        pc.w = w
    set_w(tl, tl.t)
    for f in flames:
        set_w(f, np.full(len(f.v), f.tail_u))


# ------------------------------------------------------------------ the tank
TANK_C = np.array([0.0, -0.262, 0.0])
BAND0, BAND1 = HIPS_Z + 0.022, HIPS_Z + 0.056        # the lower copper band
GL0, GL1 = BAND1, HIPS_Z + 0.335                     # the glass
BAND2 = GL1 + 0.035


def lathe(name, mat, prof, centre, axis=(0, 0, 1), segs=12, cap=False):
    """A surface of revolution: prof [(r, along)] round `axis` through `centre`. UV u round, v along."""
    axis = norm(np.array(axis, float))
    a = norm(np.cross(axis, (0.3, 1, 0.2)))
    b = np.cross(axis, a)
    rows = len(prof)
    v = []
    for r, h in prof:
        for j in range(segs):
            t = j / segs * 2 * np.pi
            v.append(np.asarray(centre) + axis * h + (a * np.cos(t) + b * np.sin(t)) * r)
    f = grid_faces(rows, segs, True)
    uvs = None
    if cap:
        c = len(v)
        v.append(np.asarray(centre) + axis * prof[-1][1])
        for j in range(segs):
            f.append([(rows - 1) * segs + j, (rows - 1) * segs + (j + 1) % segs, c])
    return Piece(name, mat, v, f)


def tank():
    """Riveted copper and glass: a rounded foot, band, the glass of bubbling fire, band, dome, two exhaust stacks and the gauge."""
    out = []
    z0 = BAND0
    prof = [(0.05, z0 - 0.095), (0.10, z0 - 0.08), (0.133, z0 - 0.045), (0.147, z0 - 0.008), (0.152, z0), (0.152, BAND1), (0.136, BAND1 + 0.002)]
    out.append(lathe("tankfoot", "metal-cinder", prof, TANK_C).rigid("hips"))
    out.append(lathe("tankring", "metal-cinder", [(0.136, GL1 - 0.002), (0.152, GL1), (0.152, GL1 + 0.034), (0.147, GL1 + 0.041), (0.128, GL1 + 0.09), (0.09, GL1 + 0.132), (0.05, GL1 + 0.15), (0.03, GL1 + 0.155)],
                     TANK_C).rigid("hips"))
    # the glass: raw UV for the fuel shader
    segs = 14
    v, f, uv = [], [], []
    for i, z in enumerate((GL0 - 0.005, (GL0 + GL1) / 2, GL1 + 0.005)):
        for j in range(segs + 1):
            t = j / segs * 2 * np.pi
            v.append(TANK_C + [np.sin(t) * 0.135, np.cos(t) * 0.135, z])
    for i in range(2):
        for j in range(segs):
            a = i * (segs + 1) + j
            q = [a + 1, a, a + segs + 1, a + segs + 2]
            f.append(q)
            uv.append([((j + 1) / segs, i / 2), (j / segs, i / 2), (j / segs, (i + 1) / 2), ((j + 1) / segs, (i + 1) / 2)])
    g = Piece("glass", "flame-liquid", v, f, uv, room=0.3).rigid("hips")
    g.flame = True
    g.fire = (0.3, 0.0)
    out.append(g)
    # three bars over the glass, as the sheet's back view
    for a in (2.4, np.pi, 3.88):
        d = np.array([np.sin(a), np.cos(a), 0.0])
        s_ = np.array([d[1], -d[0], 0.0])
        c0 = TANK_C + d * 0.143
        vv = []
        for z in (GL0 - 0.01, GL1 + 0.01):
            for sx, dy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                vv.append(c0 + s_ * sx * 0.012 + d * dy * 0.007 + [0, 0, z])
        out.append(Piece("bar%d" % int(a * 10), "metal-cinder", vv, grid_faces(2, 4, True)).rigid("hips"))
    # rivets on both bands
    for z in ((BAND0 + BAND1) / 2, GL1 + 0.017):
        for i in range(10):
            a = i / 10 * 2 * np.pi + 0.3
            d = np.array([np.sin(a), np.cos(a), 0.0])
            c0 = TANK_C + d * 0.1515 + [0, 0, z]
            k1 = np.array([d[1], -d[0], 0.0])
            pts = [c0 + k1 * 0.009, c0 + [0, 0, 0.009], c0 - k1 * 0.009, c0 - [0, 0, 0.009], c0 + d * 0.006]
            out.append(Piece("rivet%d_%d" % (int(z * 100), i), "metal-cinder", pts, [[0, 1, 4], [1, 2, 4], [2, 3, 4], [3, 0, 4]]).rigid("hips"))
    # the harness: leather bands round the copper, a strap from each up over her shoulder blade
    out.append(lathe("hband0", "leather-cinder", [(0.1535, BAND1 + 0.0), (0.1565, BAND1 - 0.004), (0.1565, BAND0 + 0.004), (0.1535, BAND0)], TANK_C, segs=14).rigid("hips"))
    for sg, nm in ((1.0, "hstrapR"), (-1.0, "hstrapL")):
        q = catmull([TANK_C + [sg * 0.06, 0.13, GL1 + 0.02], (sg * 0.075, -0.125, SHOULDER_Z + 0.02), (sg * 0.088, -0.07, SHOULDER_Z + 0.075), (sg * 0.095, -0.015, SHOULDER_Z + 0.075)], 5)
        out.append(sweep(nm, "leather-cinder", q, [(-1, 0.22), (1, 0.22), (1, -0.22), (-1, -0.22)], np.full(5, 0.021), side_hint=np.array([0, 1.0, 0.4])).rigid("hips"))
    # the exhaust stacks
    top = GL1 + 0.15
    stacks = [(np.array([-0.05, TANK_C[1] - 0.005, top - 0.005]), norm(np.array([-0.08, 0.02, 1.0])), 0.128),
              (np.array([0.075, TANK_C[1] - 0.012, top - 0.03]), norm(np.array([0.62, -0.1, 1.0])), 0.112)]
    tips = []
    for i, (c0, ax, ln) in enumerate(stacks):
        prof = [(0.05, -0.02), (0.042, 0.0), (0.03, 0.022), (0.026, 0.05), (0.041, ln - 0.052), (0.042, ln - 0.03), (0.03, ln - 0.022), (0.032, ln - 0.018),
                (0.04, ln), (0.04, ln + 0.02), (0.026, ln + 0.021)]
        out.append(lathe("stack%d" % i, "metal-cinder", prof, c0, ax, segs=8).rigid("hips"))
        tips.append((c0 + ax * (ln + 0.02), ax))
    # the gauge on a bent pipe, out at her right
    pa = TANK_C + [0.144, -0.012, GL1 - 0.1]
    pipe = sweep("gpipe", "metal-cinder", catmull([pa, pa + [0.05, -0.004, 0.0], pa + [0.098, -0.008, 0.012], pa + [0.102, -0.009, 0.075]], 6), SEC6, np.full(6, 0.0105),
                 side_hint=np.array([0, 1.0, 0.0]))
    out.append(pipe.rigid("hips"))
    gc = pa + [0.108, -0.01, 0.118]
    gd = norm(np.array([0.18, -0.92, 0.36]))
    out.append(lathe("gauge", "metal-cinder", [(0.03, -0.021), (0.052, -0.02), (0.056, -0.012), (0.056, 0.012), (0.052, 0.018), (0.046, 0.016), (0.046, 0.010)], gc, gd, segs=11).rigid("hips"))
    face_ = lathe("gface", "metal-cinder", [(0.046, 0.0105), (0.002, 0.0105)], gc, gd, segs=11).rigid("hips")
    face_.gauge = (gc, gd)
    out.append(face_)
    return out, tips


def jet_flames(tips):
    """The stacks' pilot flames: crossed strips on their own bones, which the flight clip stretches into jets."""
    out = []
    for i, (p, ax) in enumerate(tips):
        k1 = norm(np.cross(ax, (0.2, 1, 0)))
        for j, a in enumerate((0.0, 1.05, 2.1)):
            side = k1 * np.cos(a) + np.cross(ax, k1) * np.sin(a)
            ln = 0.27 - 0.04 * j
            o = strip("jet%d_%d" % (i, j), "flame-jet", [p - ax * 0.015, p + ax * ln * 0.35 + side * 0.012, p + ax * ln * 0.7 - side * 0.015, p + ax * ln + side * 0.012], 0.135 - 0.02 * j,
                      rows=5, hint=side, seed=0.11 + 0.17 * i + 0.21 * j, bright=0.45, root=0.9)
            out.append(o.rigid("jet.%d" % i))
    return out


# ------------------------------------------------------------------ the gun
# Built from briefs/art-refs/cinder_weapons.png (pistol grip, brass body with a glass chamber, copper barrel over a lower pipe with the leather foregrip, gauge, the
# hose into the butt of the grip), with the master sheet's spearhead nozzle and red grip wrap. In the rest pose the arm hangs, so the barrel lies along the
# forearm and points at the ground; every clip poses it by its own frame.
GUN_B = np.array([0.0, 0.0, -1.0])                     # along the barrel, muzzle-ward
GUN_E = np.array([0.0, 1.0, 0.0])                      # the gun's top (her thumb's side)
GRIP_RAKE = np.radians(22)
GRIP_K = GUN_E * np.cos(GRIP_RAKE) + GUN_B * np.sin(GRIP_RAKE)     # up the grip, toward the barrel: her knuckle line
_ga = norm(np.array([0, 0, -1.0]) - GRIP_K * np.dot(np.array([0, 0, -1.0]), GRIP_K))
GRIP_AT = np.array([SH, 0.0, HAND_Z + 0.006]) + _ga * 0.082 + np.array([-0.022, 0.0, 0.0])     # inside the closed fist, on the grip
BORE = 0.084                                           # the barrel's line above the grip point, along the gun's top
FORE = 0.34                                            # the grip to the off hand's place on the lower pipe
MUZZLE = 0.88                                          # the grip to the nozzle's tip
GRIP_BASE = GRIP_AT - GRIP_K * 0.088


def gun_at(h, e=0.0, x=0.0):
    return GRIP_AT + GUN_B * h + GUN_E * e + np.array([x, 0, 0])


def gun():
    """Skinned 100% to the right hand (item 76b). The glass is the fuel shader's."""
    out = []

    def ring(name, mat, prof, segs=8, e=BORE):
        return lathe(name, mat, prof, gun_at(0.0, e), GUN_B, segs=segs).rigid("hand.R")
    out.append(ring("gunbody", "metal-cinder", [(0.0, -0.205), (0.03, -0.204), (0.034, -0.19), (0.03, -0.178), (0.042, -0.172), (0.05, -0.15), (0.05, -0.062), (0.058, -0.058), (0.058, -0.04), (0.05, -0.036)], segs=10))
    out.append(ring("guncol", "metal-cinder", [(0.05, 0.13), (0.058, 0.134), (0.058, 0.15), (0.05, 0.155), (0.05, 0.2), (0.032, 0.24), (0.024, 0.25)], segs=10))
    out.append(ring("gunbarrel", "metal-cinder", [(0.0185, 0.25), (0.0185, 0.56), (0.026, 0.565), (0.026, 0.585), (0.019, 0.59), (0.019, 0.61), (0.036, 0.615), (0.036, 0.755), (0.024, 0.76)]))
    # the glass: raw UV
    segs, zs = 10, (-0.036, 0.13)
    v, f, uv = [], [], []
    for i, h in enumerate(zs):
        for j in range(segs + 1):
            t = j / segs * 2 * np.pi
            v.append(gun_at(h, BORE + np.cos(t) * 0.05, np.sin(t) * 0.05))
    for j in range(segs):
        q = [j, j + 1, j + segs + 2, j + segs + 1]
        f.append(q)
        uv.append([(j / segs, 0.0), ((j + 1) / segs, 0.0), ((j + 1) / segs, 1.0), (j / segs, 1.0)])
    gl = Piece("gunglass", "flame-liquid", v, f, uv, room=0.3).rigid("hand.R")
    gl.flame = True
    gl.fire = (0.7, 0.0)
    out.append(gl)
    # the spearhead (master sheet)
    h0 = 0.76
    pts = []
    for wd, dp, h in ((0.024, 0.024, h0), (0.05, 0.017, h0 + 0.04), (0.022, 0.011, h0 + 0.09), (0.003, 0.003, MUZZLE)):
        for a in np.linspace(0, 2 * np.pi, 6, endpoint=False):
            pts.append(gun_at(h, BORE + np.sin(a) * dp, np.cos(a) * wd))
    out.append(Piece("gunhead", "metal-cinder", pts, grid_faces(4, 6, True)).rigid("hand.R"))
    # the grip, flattened, wrapped; base collar for the hose
    gp = [GRIP_AT + GRIP_K * 0.058, GRIP_AT + GRIP_K * 0.01, GRIP_AT - GRIP_K * 0.045, GRIP_BASE]
    grip = sweep("gungrip", "leather-cinder", np.array(gp), SEC6, np.array([0.024, 0.022, 0.024, 0.021]), side_hint=np.array([1.0, 0, 0]), depth=np.array([0.016, 0.015, 0.016, 0.015]))
    out.append(grip.rigid("hand.R"))
    out.append(lathe("gunbase", "metal-cinder", [(0.0, 0.032), (0.021, 0.03), (0.022, 0.0), (0.016, -0.03)], GRIP_BASE, -GRIP_K, segs=6).rigid("hand.R"))
    # the trigger guard: a brass wire from the grip's foot to the body, the trigger in it
    tg = sweep("gunguard", "metal-cinder", catmull([GRIP_BASE + GUN_B * 0.01, gun_at(0.03, -0.1), gun_at(0.1, -0.075), gun_at(0.135, 0.01), gun_at(0.14, 0.05)], 7), SEC6[::2], np.full(7, 0.0055),
               side_hint=np.array([1.0, 0, 0]))
    out.append(tg.rigid("hand.R"))
    tr = sweep("guntrig", "metal-cinder", catmull([gun_at(0.056, 0.038), gun_at(0.07, 0.008), gun_at(0.055, -0.024)], 4), SEC6[::2], np.array([0.006, 0.006, 0.0055, 0.003]), side_hint=np.array([1.0, 0, 0]))
    out.append(tr.rigid("hand.R"))
    # the lower pipe, the leather foregrip on it, the two clamps, the brass stay up to the nozzle
    pp = np.array([gun_at(0.17, 0.03), gun_at(0.56, 0.03)])
    out.append(sweep("gunpipe", "metal-cinder", np.linspace(pp[0], pp[1], 3), SEC6, np.full(3, 0.0105), side_hint=np.array([1.0, 0, 0])).rigid("hand.R"))
    out.append(lathe("gunfore", "leather-cinder", [(0.012, FORE - 0.066), (0.022, FORE - 0.06), (0.0255, FORE - 0.03), (0.0225, FORE), (0.0255, FORE + 0.03), (0.022, FORE + 0.06), (0.012, FORE + 0.066)], gun_at(0.0, 0.03), GUN_B, segs=7).rigid("hand.R"))
    for i, h in enumerate((0.262, 0.545)):
        c0 = gun_at(h, 0.057)
        vv = [c0 + GUN_E * dy + np.array([sx * 0.016, 0, 0]) + GUN_B * dz for dz in (-0.012, 0.012) for sx, dy in ((-1, -0.044), (1, -0.044), (1, 0.044), (-1, 0.044))]
        out.append(Piece("gunclamp%d" % i, "metal-cinder", vv, grid_faces(2, 4, True) + [[3, 2, 1, 0], [4, 5, 6, 7]]).rigid("hand.R"))
    st = sweep("gunstay", "metal-cinder", catmull([gun_at(0.70, 0.062), gun_at(0.665, -0.002), gun_at(0.60, -0.03), gun_at(0.48, -0.03), gun_at(0.44, 0.02)], 6), SEC6[::2], np.full(6, 0.0048), side_hint=np.array([1.0, 0, 0]))
    out.append(st.rigid("hand.R"))
    # the gauge, on its side at the root of the pipe, and the filler knob on the chamber
    gc = gun_at(0.205, 0.022, 0.03)
    gd = np.array([1.0, 0, 0])
    out.append(lathe("ggauge", "metal-cinder", [(0.02, -0.018), (0.036, -0.016), (0.039, -0.008), (0.039, 0.008), (0.033, 0.012), (0.032, 0.008)], gc, gd, segs=9).rigid("hand.R"))
    gf = lathe("ggface", "metal-cinder", [(0.032, 0.0075), (0.002, 0.0075)], gc, gd, segs=9).rigid("hand.R")
    gf.gauge = (gc, gd, 0.032)
    out.append(gf)
    out.append(lathe("gunknob", "metal-cinder", [(0.012, 0.0), (0.012, 0.042), (0.024, 0.044), (0.024, 0.06), (0.0, 0.062)], gun_at(0.15, BORE + 0.05), GUN_E, segs=7).rigid("hand.R"))
    return out


# ------------------------------------------------------------------ hoses
def hoses():
    """The feed hose from the tank's foot, round her right hip in a slack loop, to the butt of the gun: it blends from the hips to the
    hand, so it pays out as she aims. Two coils hang off the tank's sides, as the sheet's."""
    out = []
    base = TANK_C + [0.11, 0.02, BAND0 - 0.06]
    butt = GRIP_BASE - GRIP_K * 0.028
    pts = [base, base + [0.09, 0.04, -0.06], base + [0.16, 0.08, -0.17], butt + [0.09, -0.16, -0.05], butt + [0.075, -0.13, -0.12], butt + [0.02, -0.075, -0.09], butt]
    rows = 15
    path = catmull(pts, rows)
    h = sweep("hose", "metal-cinder", path, SEC6, np.full(rows, 0.0135), side_hint=np.array([1.0, 0, 0.3]))
    h.mat = "leather-cinder"
    t = np.repeat(np.linspace(0, 1, rows), 6)
    u = smooth(0.15, 0.97, t)
    h.w = {"hips": 1 - u, "hand.R": u}
    h.t = t
    out.append(h)
    for sg, nm in ((-1.0, "coilL"), (1.0, "coilR")):
        a = TANK_C + [sg * 0.115, -0.02, BAND0 - 0.05]
        b = TANK_C + [sg * 0.128, 0.09, BAND0 + 0.0]
        q = catmull([a, a + [sg * 0.05, -0.03, -0.1], a + [sg * 0.13, 0.0, -0.21], a + [sg * 0.175, 0.1, -0.2], a + [sg * 0.165, 0.17, -0.09], b + [sg * 0.05, 0.015, 0.0], b], 13)
        c = sweep(nm, "leather-cinder", q, SEC6, np.full(13, 0.0125), side_hint=np.array([0, 0, 1.0]))
        out.append(c.rigid("hips"))
    return out


# ------------------------------------------------------------------ vials
VIAL_N = 4
BELT_Z = HIPS_Z + 0.098
VIAL_RX, VIAL_RY = 0.142, 0.118


def vials():
    """The vial belt (cinder_weapons.png): four vials of fuel in leather loops, her left hip round to the front, cork stoppers up, tilted out like cartridges."""
    out = []
    spots = []
    ang = np.radians(np.linspace(-24, -96, VIAL_N))
    # the backing strap
    rows = 9
    a2 = np.radians(np.linspace(-14, -106, rows))
    G = []
    for z in (BELT_Z - 0.045, BELT_Z + 0.022):
        for a in a2:
            G.append((np.sin(a) * VIAL_RX, np.cos(a) * VIAL_RY, z))
    out.append(Piece("rack", "leather-cinder", G, grid_faces(2, rows)).rigid("root"))
    for i, a in enumerate(ang):
        d = np.array([np.sin(a), np.cos(a), 0.0])
        c0 = np.array([d[0] * (VIAL_RX + 0.026), d[1] * (VIAL_RY + 0.026), BELT_Z - 0.032])
        ax = norm(np.array([d[0] * 0.2, d[1] * 0.2, 1.0]))
        segs = 7
        # the fuel: a capsule, raw UV
        v, f, uv = [], [], []
        hs = (-0.044, -0.03, 0.02)
        rs = (0.004, 0.0172, 0.0172)
        k1 = norm(np.cross(ax, (0.3, 0.9, 0.1)))
        k2 = np.cross(ax, k1)
        for r_, (h, r) in enumerate(zip(hs, rs)):
            for j in range(segs + 1):
                t = j / segs * 2 * np.pi
                v.append(c0 + ax * h + (k1 * np.cos(t) + k2 * np.sin(t)) * r)
        for r_ in range(2):
            for j in range(segs):
                p = r_ * (segs + 1) + j
                q = [p, p + 1, p + segs + 2, p + segs + 1]
                f.append(q)
                uv.append([(j / segs, r_ / 2), ((j + 1) / segs, r_ / 2), ((j + 1) / segs, (r_ + 1) / 2), (j / segs, (r_ + 1) / 2)])
        vp = Piece("vial%d" % i, "flame-liquid", v, f, uv, room=0.2).rigid("root")
        vp.flame = True
        vp.fire = (0.1 * i, 0.0)
        out.append(vp)
        out.append(lathe("vcap%d" % i, "metal-cinder", [(0.0165, 0.018), (0.0195, 0.02), (0.0195, 0.034), (0.0125, 0.038), (0.0, 0.04)], c0, ax, segs=6).rigid("root"))
        loop_ = lathe("vloop%d" % i, "leather-cinder", [(0.0195, -0.02), (0.0205, -0.016), (0.0205, 0.002), (0.0195, 0.006)], c0, ax, segs=6).rigid("root")
        out.append(loop_)
        spots.append(c0 + ax * 0.05)
    return out, spots


# ------------------------------------------------------------------ hands and claws
def hand(side, grip_dir, curl, spread=0.0):
    """A slim long-fingered hand on the wrist, black claws. curl: finger joint angles (radians) from flat."""
    s = 1.0 if side == "R" else -1.0
    wrist = np.array([s * SH, 0.0, HAND_Z + 0.006])
    k = norm(np.asarray(grip_dir, float))
    a = np.array([0, 0, -1.0])
    a = norm(a - k * np.dot(a, k))
    o = norm(np.cross(a, k))
    if o[0] * s < 0:
        o = -o
    pieces = []
    knuck = wrist + a * 0.07
    centre = [wrist - a * 0.022, wrist + a * 0.024, wrist + a * 0.052, knuck]
    width = np.array([0.028, 0.035, 0.040, 0.038])
    depth = np.array([0.024, 0.019, 0.019, 0.016])
    palm = sweep("palm" + side, "skin-cinder-hot", centre, SEC8, width, side_hint=o, depth=depth)
    t_, s_, n_ = frames(np.asarray(centre), o)
    for i in range(len(centre)):
        for j in range(8):
            d = palm.v[i * 8 + j] - centre[i]
            x = np.dot(d, s_[i]) / width[i]
            y = np.dot(d, n_[i]) / depth[i]
            palm.v[i * 8 + j] = centre[i] + k * x * width[i] + o * y * depth[i]
    pieces.append(palm.rigid("hand." + side))
    lens = [(0.034, 0.024, 0.022), (0.038, 0.027, 0.023), (0.035, 0.025, 0.022), (0.028, 0.019, 0.018)]
    rads = [0.0088, 0.0091, 0.0087, 0.0078]
    fbone = "hand." + side if side == "R" else "fingers." + side
    for f in range(4):
        base = knuck + k * (0.0285 - f * 0.019) + o * 0.003
        p = [base - a * 0.01]
        d = norm(rot_about(a.copy(), o, -spread * (f - 1.5)))
        p.append(base.copy())
        cur = base.copy()
        ang = 0.0
        for jn in range(3):
            ang += curl[jn]
            dd = rot_about(d, k, ang * (1.0 if np.dot(np.cross(k, a), o) < 0 else -1.0))
            cur = cur + dd * lens[f][jn]
            p.append(cur.copy())
        # the claw
        p.append(cur + dd * 0.0165)
        p = np.array(p)
        wd = np.array([1.0, 1.02, 1.0, 0.92, 0.78, 0.03]) * rads[f]
        fp = sweep("finger%d%s" % (f, side), "skin-cinder-hot", p, SEC6, wd, side_hint=k)
        fp.claw = (cur, p[-1])
        if side == "R":
            fp.rigid("hand.R")
        else:
            q = smooth(0.015, 0.022, np.linalg.norm(fp.v - base, axis=1))
            fp.w = {"hand.L": 1 - q, fbone: q}
        pieces.append(fp)
    base = wrist + a * 0.024 + k * 0.036 - o * 0.006
    t1 = base + norm(a * 0.72 + k * 0.42 - o * 0.5) * 0.032
    t2 = t1 + norm(a * 0.9 + k * 0.05 - o * 0.45) * 0.024
    t3 = t2 + norm(a * 0.9 - k * 0.35 - o * 0.2) * 0.021
    t4 = t3 + norm(a * 0.9 - k * 0.45 - o * 0.1) * 0.015
    tp = sweep("thumb" + side, "skin-cinder-hot", [base - a * 0.008, t1, t2, t3, t4], SEC6, np.array([0.0155, 0.012, 0.0098, 0.0082, 0.0003]), side_hint=o)
    tp.claw = (t3, t4)
    if side == "R":
        tp.rigid("hand.R")
    else:
        q = smooth(0.008, 0.024, np.linalg.norm(tp.v - base, axis=1))
        tp.w = {"hand.L": 1 - q, "thumb.L": q}
    pieces.append(tp)
    return pieces
