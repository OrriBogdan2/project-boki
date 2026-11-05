"""ART-1 Kael: the rebuilt pieces (head and face, mask, cowl, mane, collar, hands, chains, greatsword) as data.
Blender frame: Z up, he faces +Y, his right hand is +X. See /home/boki/shots-s2/art1/STYLE_NOTES.md."""
import numpy as np
from meshkit import (Piece, catmull, norm, smooth, sweep, sd_ell, sd_cap, smin, smax, rot_about, frames)

# ---- the rig (kael_rig.json with archetype body.chest 0.9), Blender frame
SH = 0.2608 * 0.9
ARM = {"R": 1.0, "L": -1.0}
HAND_Z, ELBOW_Z, SHOULDER_Z = 0.706, 0.941, 1.151
ANKLE_Z = 0.085
NECK_Z = 1.2957
HS = 0.93                                     # head size
C = np.array([0.0, 0.012, 1.405])             # the head's centre
EYE = np.array([0.036, 0.0625, 0.008])        # head-local; x mirrored
EYE_R = 0.0215


def hl(p):
    """Head-local -> world."""
    return C + np.asarray(p, dtype=np.float64) * HS


def head_sdf(p):
    d = sd_ell(p, (0, -0.012, 0.03), (0.083, 0.098, 0.085))
    d = smin(d, sd_ell(p, (0, 0.018, -0.035), (0.070, 0.074, 0.088)), 0.02)
    d = smin(d, sd_ell(p, (0, 0.02, -0.09), (0.058, 0.058, 0.044)), 0.02)
    for s in (-1.0, 1.0):
        # the heavy brow ridge, sloping down toward the nose: the scowl lives in the bone
        d = smin(d, sd_cap(p, (s * 0.010, 0.084, 0.024), (s * 0.066, 0.052, 0.046), 0.0125), 0.014)
        d = smin(d, sd_ell(p, (s * 0.056, 0.058, -0.024), (0.022, 0.022, 0.014)), 0.014)     # cheekbone
        d = smax(d, -sd_ell(p, (s * 0.037, 0.095, 0.009), (0.023, 0.021, 0.0185)), 0.008)    # the socket
    d = smin(d, sd_cap(p, (0, 0.082, 0.016), (0, 0.104, -0.03), 0.0105), 0.012)              # the nose bridge
    d = smax(d, -sd_cap(p, (0, 0.11, 0.04), (0, 0.11, 0.016), 0.0026), 0.005)             # the frown furrow
    return d


def ray_y(x, z, y0=0.17, steps=48):
    """The head's surface along -Y from in front at each (x, z): a heightfield y(x, z)."""
    x, z = np.asarray(x, float), np.asarray(z, float)
    y = np.full(x.shape, y0)
    for _ in range(steps):
        d = head_sdf(np.stack([x, y, z], -1))
        y = y - np.clip(d, -0.01, 0.02) * 0.9
    return y


def ray_out(ang, z, extra=None, r0=0.2, steps=48):
    """The surface along the ray from the axis at height z, angle `ang` from +Y round Z (toward +X)."""
    ang, z = np.asarray(ang, float), np.asarray(z, float)
    dirx, diry = np.sin(ang), np.cos(ang)
    r = np.full(ang.shape, r0)
    for _ in range(steps):
        p = np.stack([dirx * r, diry * r, z], -1)
        d = head_sdf(p)
        if extra is not None:
            d = np.minimum(d, extra(p))
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


def face_patch():
    xs = np.concatenate([np.linspace(-0.094, -0.066, 3), np.linspace(-0.058, 0.058, 19), np.linspace(0.066, 0.094, 3)])
    zs = np.concatenate([np.linspace(-0.05, -0.028, 3), np.linspace(-0.02, 0.05, 13), np.linspace(0.06, 0.098, 4)])
    X, Z = np.meshgrid(xs, zs)
    Y = np.maximum(ray_y(X, Z), 0.0)
    v = hl(np.stack([X, Y, Z], -1).reshape(-1, 3))
    return Piece("face", "skin-kael", v, grid_faces(len(zs), len(xs))).rigid("head")


def skull():
    """The rest of the head, coarse: all of it sits under the hair and the mask."""
    rows, cols = 8, 14
    zs = np.linspace(0.105, -0.14, rows)
    angs = np.linspace(0, 2 * np.pi, cols, endpoint=False)
    A, Z = np.meshgrid(angs, zs)
    R = ray_out(A, Z, r0=0.14) * 0.985
    v = hl(np.stack([np.sin(A) * R, np.cos(A) * R, Z], -1).reshape(-1, 3))
    return Piece("skull", "skin-kael", v, grid_faces(rows, cols, True)).rigid("head")


def eyeball(s):
    """The front cap of the eye, facing out a touch. Corner UVs are a flat view of it, painted by paint_eye."""
    c = EYE * [s, 1, 1]
    rows, cols = 5, 9
    v, uv = [], []
    for i in range(rows):
        for j in range(cols):
            a, b = (j / (cols - 1) - 0.5) * 2.0, (i / (rows - 1) - 0.5) * 1.5
            d = norm(np.array([np.sin(a) * np.cos(b), np.cos(a) * np.cos(b), np.sin(b)]))
            d = rot_about(d, (0, 0, 1), -s * 0.1)
            v.append(c + d * EYE_R)
            uv.append((a, b))
    p = Piece("eye" + ("R" if s > 0 else "L"), "eyes-kael", hl(v), grid_faces(rows, cols)).rigid("head")
    p.eye_uv = np.array(uv)
    return p


def lids(s):
    """Shells on a sphere round the eye: the upper lid turns on its bone, the lower stays; together they cut the almond.
    The upper edge is nearly straight and slopes down toward the nose: narrowed, cold."""
    c = EYE * [s, 1, 1]
    out = []
    for up in (True, False):
        rows, cols = 4, 8
        v = []
        for i in range(rows):
            for j in range(cols):
                az = (j / (cols - 1) - 0.5) * 2.1                 # + is outward, away from the nose
                if up:
                    edge = 0.05 + 0.26 * az + 0.03 * np.cos(az * 2.2)
                    top = 1.15
                else:
                    edge = -0.34 - 0.10 * (az * az) + 0.08 * az
                    top = -1.1
                el = edge + (top - edge) * i / (rows - 1)
                d = np.array([np.sin(az) * s * np.cos(el), np.cos(az) * np.cos(el), np.sin(el)])
                v.append(c + d * (EYE_R * (1.1 + (0.05 * i / (rows - 1)))))
        f = grid_faces(rows, cols)
        p = Piece("lid%s%s" % ("U" if up else "D", "R" if s > 0 else "L"), "skin-kael", hl(v), f)
        p.rigid(("lid.%s" % ("R" if s > 0 else "L")) if up else "head")
        out.append(p)
    return out


def brows(s):
    """The white brow: a heavy wedge from the frown out past the temple, with feathered tips."""
    out = []
    side = "R" if s > 0 else "L"
    pts = [(0.010, 0.0975, 0.029), (0.030, 0.094, 0.036), (0.052, 0.080, 0.046), (0.074, 0.056, 0.060)]
    for k, (dz, wid, tipz, tipx) in enumerate([(0.0, 0.0105, 0.012, 0.004), (-0.005, 0.0075, -0.004, 0.012),
                                               (0.007, 0.006, 0.02, -0.012)]):
        p = np.array(pts) * [s, 1, 1] + [0, 0.003, dz]
        p[-1] += [s * tipx, 0, tipz]
        path = catmull(p, 6)
        wd = wid * np.array([0.45, 0.95, 1.0, 0.85, 0.5, 0.05])
        b = sweep("brow%d%s" % (k, side), "hair-brow", hl(path), [(-1, 0), (0, 0.28), (1, 0), (0, -0.28)], wd * HS,
                  side_hint=np.array([0, 1.0, 0.3]), uv_rect=(0.1, 0.5, 0.3, 0.6), room=0.0)
        out.append(b.rigid("brow." + side))
    return out


def mask():
    """The scarf over the nose and mouth: a shell on the head with the nose tented, one lip along its top edge."""
    tent = lambda p: np.minimum(sd_cap(p, (0, 0.094, 0.002), (0, 0.114, -0.036), 0.0135),
                                sd_ell(p, (0, 0.056, -0.075), (0.066, 0.056, 0.066)))
    cols = 21
    angs = np.linspace(-1.95, 1.95, cols)
    rows = 7
    top = -0.03 + 0.024 * np.exp(-(angs / 0.16) ** 2) + 0.012 * smooth(0.7, 1.6, np.abs(angs))
    v = []
    for i in range(rows):
        k = i / (rows - 1)
        z = top + (-0.165 - top) * k ** 0.9
        r = ray_out(angs, z, tent, r0=0.17)
        r = r + 0.0065 + 0.0022 * np.sin(angs * 7.0 + k * 5.0) * smooth(0.0, 0.3, k)
        v.append(np.stack([np.sin(angs) * r, np.cos(angs) * r, z], -1))
    v = np.array(v).reshape(-1, 3)
    # the lip: the top edge turned in against the skin
    lip = v[:cols].copy()
    rad = norm(lip * [1, 1, 0])
    lip = lip - rad * 0.0075 + [0, 0, -0.002]
    verts = np.vstack([lip, v])
    return Piece("mask", "cloth-kael", hl(verts), grid_faces(rows + 1, cols)).rigid("head")


def cowl():
    """The scarf's cowl: rolled folds round the neck, then a torn drape over the chest and shoulders."""
    cols = 22
    # (z, half width, half depth, y): the profile from under the chin to the drape's hem
    prof = [(1.318, 0.074, 0.08, 0.012), (1.296, 0.084, 0.088, 0.012), (1.276, 0.108, 0.108, 0.010),
            (1.262, 0.128, 0.125, 0.008), (1.247, 0.128, 0.122, 0.010), (1.232, 0.142, 0.132, 0.014),
            (1.213, 0.170, 0.146, 0.012), (1.192, 0.196, 0.154, 0.010), (1.168, 0.205, 0.152, 0.006)]
    rows = len(prof)
    verts, w_head = [], []
    rng = np.random.RandomState(7)
    jag = rng.uniform(-1, 1, cols)
    for i, (z, hw, hd, y) in enumerate(prof):
        k = i / (rows - 1)
        for j in range(cols):
            a = j / cols * 2 * np.pi
            sx, cy = np.sin(a), np.cos(a)
            # front sags, back rides up; folds run round, broken by big soft lobes
            sag = (0.5 * (cy + 1)) ** 1.5 * 0.055 * k ** 1.4 - (0.5 * (1 - cy)) * 0.03 * k
            lobes = (0.008 * np.sin(a * 3 + 0.8 + k * 2.2) + 0.006 * np.sin(a * 5 + 2.1)) * smooth(0.1, 0.5, k)
            hem = (0.016 * jag[j]) * (k ** 6)
            verts.append([sx * (hw + lobes), y + cy * (hd + lobes), z - sag + hem])
            w_head.append(1.0 - smooth(0.15, 0.62, k))
    verts = np.array(verts)
    w = np.array(w_head)
    return Piece("cowl", "cloth-kael", verts, grid_faces(rows, cols, True), weights={"head": w, "hips": 1 - w})


def tail(bvh):
    """The hanging end of the scarf on his left chest, torn, on a spring chain."""
    rows, cols = 9, 5
    top_z, bot_z = 1.19, 0.86
    verts = []
    jag = np.array([0.0, 0.05, -0.03, 0.06, -0.015])
    for i in range(rows):
        k = i / (rows - 1)
        z = top_z + (bot_z - top_z) * k
        for j in range(cols):
            u = j / (cols - 1) - 0.5
            cx = -0.082 + 0.012 * np.sin(k * 3.0)
            wd = 0.105 + 0.03 * smooth(0.0, 0.6, k)
            x = cx + u * wd + 0.004 * np.sin(k * 9 + j)
            zz = z + (jag[j] * smooth(0.55, 1.0, k))
            hit = bvh.ray_cast((x, 0.5, zz), (0, -1, 0))
            yy = (hit[0].y if hit[0] is not None else 0.12) + 0.011 + 0.004 * np.sin(u * 8 + k * 2)
            verts.append([x, yy, zz])
    verts = np.array(verts)
    faces = grid_faces(rows, cols)
    # two moth-eaten holes
    drop = {(rows - 3) * (cols - 1) + 1, (rows - 4) * (cols - 1) + 3}
    faces = [f for n, f in enumerate(faces) if n not in drop]
    return Piece("tail", "cloth-kael", verts, faces, room=0.25)


def collar():
    """His relic: the broken gold collar, two chunky plates cracked open at the throat."""
    out = []
    for s in (-1.0, 1.0):
        angs = np.linspace(0.16, 0.86, 7)
        path, wd = [], []
        for k, a in enumerate(angs):
            drop = 0.05 * (1.0 - a / 1.02)
            path.append([s * np.sin(a) * 0.165, 0.016 + np.cos(a) * 0.146, 1.172 - drop + 0.03 * a])
            wd.append([0.028, 0.027, 0.022, 0.024, 0.020, 0.016, 0.006][k])
        sec = [(-1, 0.0), (-0.55, 0.42), (0.55, 0.42), (1, 0.0), (0.55, -0.3), (-0.55, -0.3)]
        p = sweep("collar" + ("R" if s > 0 else "L"), "brass-kael", path, sec, wd,
                  side_hint=np.array([0, 0.9, 0.5]), depth=np.array(wd) * 0.42 + 0.004)
        # snapped ends: a jagged step at the broken end
        p.v[:6] += [s * -0.012, 0.012, -0.01]
        out.append(p.rigid("hips"))
    return out


def under_thighs():
    """The thighs the skirt hides (the scan has only skirt there), so a stride shows a leg, not the void."""
    out = []
    for s, bone in ((1.0, "R"), (-1.0, "L")):
        zs = [0.46, 0.52, 0.58, 0.64, 0.72]
        rs = [0.06, 0.07, 0.08, 0.086, 0.08]
        path = [[s * (0.1191 + (z - 0.4) * -0.03), 0.0, z] for z in zs]
        sec = [(np.cos(a), np.sin(a)) for a in np.linspace(0, 2 * np.pi, 8, endpoint=False)]
        p = sweep("thigh" + bone, "skin-kael", path, sec, rs, side_hint=np.array([0, 1.0, 0]))
        p.rigid("thigh." + bone)
        out.append(p)
    return out


# ------------------------------------------------------------------ hands
def hand(side, grip_dir, curl, spread=0.0, bone_prefix=True):
    """A big hand on the wrist. curl: finger joint angles (radians) from flat. Frame: k along the knuckles (thumb side
    first), a from wrist to knuckles, o out of the back of the hand."""
    s = ARM[side]
    wrist = np.array([s * SH, 0.0, HAND_Z + 0.012])
    k = norm(np.asarray(grip_dir, float))
    a = np.array([0, 0, -1.0])
    a = norm(a - k * np.dot(a, k))
    o = norm(np.cross(a, k)) * 1.0
    if o[0] * s < 0:
        o = -o
    pieces = []
    sec8 = [(np.cos(t), np.sin(t)) for t in np.linspace(0, 2 * np.pi, 8, endpoint=False)]
    # the palm: a wedge from the wrist out to the knuckles
    knuck = wrist + a * 0.082
    centre = [wrist - a * 0.018, wrist + a * 0.03, wrist + a * 0.062, knuck]
    width = np.array([0.036, 0.046, 0.052, 0.050])
    depth = np.array([0.031, 0.027, 0.026, 0.023])
    palm = sweep("palm" + side, "skin-kael", centre, sec8, width, side_hint=o, depth=depth)
    t_, s_, n_ = frames(np.asarray(centre), o)
    # rotate the sweep's section so its long axis lies along the knuckles
    for i in range(len(centre)):
        for j in range(8):
            d = palm.v[i * 8 + j] - centre[i]
            x = np.dot(d, s_[i]) / width[i]
            y = np.dot(d, n_[i]) / depth[i]
            palm.v[i * 8 + j] = centre[i] + k * x * width[i] + o * y * depth[i]
    pieces.append(palm.rigid("hand." + side))
    # the fingers, each three bones, curling from the knuckle toward the palm
    lens = [(0.036, 0.026, 0.024), (0.040, 0.029, 0.025), (0.037, 0.026, 0.024), (0.029, 0.021, 0.020)]
    rads = [0.0118, 0.0122, 0.0116, 0.0104]
    for f in range(4):
        base = knuck + k * (0.036 - f * 0.024) + o * 0.006
        p = [base - a * 0.012]
        d = a.copy()
        fan = rot_about(d, o, -spread * (f - 1.5))
        d = norm(fan)
        p.append(base.copy())
        cur = base.copy()
        ang = 0.0
        for jn in range(3):
            ang += curl[jn]
            dd = rot_about(d, k, ang * (1.0 if np.dot(np.cross(k, a), o) < 0 else -1.0))
            cur = cur + dd * lens[f][jn]
            p.append(cur.copy())
        p = np.array(p)
        wd = np.array([1.0, 1.02, 1.0, 0.93, 0.8]) * rads[f]
        sec = [(np.cos(t), np.sin(t)) for t in np.linspace(0, 2 * np.pi, 6, endpoint=False)]
        fp = sweep("finger%d%s" % (f, side), "skin-kael", p, sec, wd, side_hint=k)
        bone = "hand." + side if side == "R" else "fingers." + side
        fp.w = {"hand." + side: 1 - smooth(0.015, 0.02, np.linalg.norm(fp.v - base, axis=1)), bone: 0 * fp.v[:, 0]}
        if bone != "hand." + side:
            fp.w[bone] = 1 - fp.w["hand." + side]
        else:
            fp.w = {bone: np.ones(len(fp.v))}
        pieces.append(fp)
    # the thumb
    base = wrist + a * 0.028 + k * 0.048 - o * 0.008
    t1 = base + norm(a * 0.72 + k * 0.42 - o * 0.5) * 0.04
    t2 = t1 + norm(a * 0.9 + k * 0.05 - o * 0.45) * 0.03
    t3 = t2 + norm(a * 0.9 - k * 0.35 - o * 0.2) * 0.026
    sec = [(np.cos(t), np.sin(t)) for t in np.linspace(0, 2 * np.pi, 6, endpoint=False)]
    tp = sweep("thumb" + side, "skin-kael", [base - a * 0.01, t1, t2, t3], sec, np.array([0.02, 0.0155, 0.0125, 0.0105]),
               side_hint=o)
    if side == "R":
        tp.rigid("hand.R")
    else:
        q = smooth(0.01, 0.03, np.linalg.norm(tp.v - base, axis=1))
        tp.w = {"hand.L": 1 - q, "thumb.L": q}
    pieces.append(tp)
    return pieces


# ------------------------------------------------------------------ chains
RING = [(np.cos(t), np.sin(t)) for t in (0.5, 2.6, 4.7)]


def link(centre, along, side, ln=0.040, wid=0.020, th=0.0058, uv=(0, 0, 1, 1)):
    """One chain link: a stadium ring, 8 segments of a triangular wire."""
    along, side = norm(along), norm(side)
    nrm = np.cross(along, side)
    pts = []
    for t in np.linspace(0, 2 * np.pi, 6, endpoint=False):
        cx, sx = np.cos(t), np.sin(t)
        pts.append(along * (cx * (ln * 0.5 - wid * 0.1) + np.sign(cx) * 0.0) + side * sx * wid * 0.5)
    v, f, uvs = [], [], []
    n = len(pts)
    for i in range(n):
        o = norm(pts[i] * [1, 1, 1])
        for a, b in RING:
            v.append(centre + pts[i] + o * a * th + nrm * b * th)
    for i in range(n):
        for j in range(3):
            aa = i * 3 + j
            bb = i * 3 + (j + 1) % 3
            cc = ((i + 1) % n) * 3 + (j + 1) % 3
            dd = ((i + 1) % n) * 3 + j
            f.append([aa, bb, cc, dd])
            u0, v0, u1, v1 = uv
            uu = u0 + (u1 - u0) * (j / 3.0)
            uw = u0 + (u1 - u0) * ((j + 1) / 3.0)
            vv = v0 + (v1 - v0) * (i / n)
            vw = v0 + (v1 - v0) * ((i + 1) / n)
            uvs.append([(uu, vv), (uw, vv), (uw, vw), (uu, vw)])
    return v, f, uvs


def chain_along(name, path, step=0.033, uv=(0, 0, 1, 1), ln=0.040, wid=0.021, th=0.0058, flip=0.0):
    """Links along a path, every other one turned 90 degrees about the path."""
    p = np.asarray(path, dtype=np.float64)
    seg = np.linalg.norm(np.diff(p, axis=0), axis=1)
    s = np.concatenate([[0], np.cumsum(seg)])
    cnt = max(1, int(s[-1] / step))
    v, f, uvs = [], [], []
    t, side, nrm = frames(p, (0.3, 0.4, 0.9))
    for i in range(cnt):
        d = (i + 0.5) * step
        k = np.searchsorted(s, d) - 1
        k = int(np.clip(k, 0, len(p) - 2))
        q = (d - s[k]) / max(seg[k], 1e-6)
        c = p[k] * (1 - q) + p[k + 1] * q
        a = t[k]
        tw = (i % 2) * (np.pi / 2) + flip + (i * 0.17)
        sd = side[k] * np.cos(tw) + nrm[k] * np.sin(tw)
        vv, ff, uu = link(c, a, sd, ln=ln, wid=wid, th=th, uv=uv)
        o = len(v)
        v += vv
        f += [[o + x for x in q2] for q2 in ff]
        uvs += uu
    return Piece(name, "metal-chain", v, f, uvs, room=0.15)


def wrist_chain(uv):
    """The chain wound round his right forearm and the bandaged wrist."""
    cx = SH
    pts = []
    turns = 3.1
    n = 90
    for i in range(n):
        k = i / (n - 1)
        a = k * turns * 2 * np.pi + 0.6
        z = 0.828 - 0.118 * k + 0.008 * np.sin(a * 2.3)
        r = 0.058 - 0.012 * k + 0.003 * np.sin(a * 1.7)
        pts.append([cx + np.cos(a) * r * 1.06, np.sin(a) * r, z])
    p = chain_along("chain_wrap", pts, step=0.0345, uv=uv, ln=0.042, wid=0.023, th=0.0064)
    return p.rigid("forearm.R")


def hanging_chain(uv):
    """From the wrist down to the hook. Bones spring_hangwarchain_*: the game hangs it from the fist."""
    top = np.array([SH + 0.046, 0.022, 0.70])
    path = [top + [0, 0, -k * 0.54] for k in np.linspace(0, 1, 12)]
    p = chain_along("chain_hang", path, step=0.0395, uv=uv, ln=0.046, wid=0.026, th=0.0068)
    ring_c = top + [0, 0, -0.562]
    # the eye and the hook itself, a forged J
    pts = catmull([ring_c + [0, 0, 0.0], ring_c + [0.0, 0.0, -0.05], ring_c + [0.0, 0.016, -0.115],
                   ring_c + [0, 0.05, -0.15], ring_c + [0, 0.098, -0.13], ring_c + [0, 0.112, -0.082],
                   ring_c + [0, 0.098, -0.05]], 10)
    wd = np.array([0.018, 0.018, 0.019, 0.021, 0.021, 0.02, 0.018, 0.015, 0.01, 0.0015])
    sec = [(-1, 0), (0, 0.55), (1, 0), (0, -0.55)]
    # (flattened across the hook's plane, the art's forged blade section)
    hook = sweep("hook", "metal-hook", pts, sec, wd * 0.72, side_hint=np.array([1.0, 0, 0]), depth=wd * 1.05, uv_rect=uv)
    hook.tipn = 4
    bones = ["spring_hangwarchain_%d" % i for i in range(7)]
    chain_pts = [top + [0, 0, -0.6 * i / 6.0] for i in range(7)]
    return p, hook, chain_pts


def cuff_chain(uv):
    top = np.array([-SH - 0.05, 0.0, 0.742])
    path = [top + [0, 0, -k * 0.21] for k in np.linspace(0, 1, 6)]
    p = chain_along("chain_cuff", path, step=0.038, uv=uv, ln=0.044, wid=0.024, th=0.0062)
    return p, [top + [0, 0, -0.24 * i / 3.0] for i in range(4)]


# ------------------------------------------------------------------ the mane
LENS = [(-1, 0), (-0.45, 0.38), (0.45, 0.38), (1, 0), (0.45, -0.3), (-0.45, -0.3)]
DIA = [(-1, 0), (0, 0.42), (1, 0), (0, -0.32)]


def lock(name, pts, w0, rings=7, wide=False, peak=0.32, tip=0.0, hint=None, tile=0.0, group=None):
    path = catmull(pts, rings)
    k = np.linspace(0, 1, rings)
    prof = np.minimum(1.0, 0.55 + k / peak * 0.45) * (1 - smooth(peak, 1.0, k)) ** 0.8
    wd = w0 * np.maximum(prof, 0.012) + tip
    if hint is None:
        c = np.array([0, -0.03, 1.40])
        hint = norm(path[0] - c)
    u0 = tile
    p = sweep(name, "hair-mane", path, LENS if wide else DIA, wd, side_hint=hint, uv_rect=(u0, 0, u0 + 0.25, 1),
              room=0.0, depth=wd * (0.5 if wide else 0.62))
    p.t = np.repeat(k, len(LENS if wide else DIA))
    p.group = group
    p.path = path
    return p


def mane():
    locks = []
    add = lambda *a, **k: locks.append(lock(*a, **k))
    tile = lambda i: (i * 0.25) % 1.0
    # the crown: swept up off a centre part, then back and out, tips flying past the silhouette
    for s in (1.0, -1.0):
        add("crown_a%d" % s, [(s * .012, .094, 1.515), (s * .05, .095, 1.552), (s * .105, .065, 1.558), (s * .160, .010, 1.535),
                               (s * .212, -.02, 1.490)], .058, rings=7, wide=True, tile=tile(0), group=None)
        add("crown_b%d" % s, [(s * .012, .070, 1.530), (s * .040, .050, 1.561), (s * .090, -.005, 1.568),
                               (s * .150, -.070, 1.55), (s * .205, -.115, 1.525)], .060, rings=7, wide=True, tile=tile(1))
        add("crown_c%d" % s, [(s * .010, .020, 1.545), (s * .022, -.030, 1.568), (s * .040, -.100, 1.566),
                               (s * .066, -.165, 1.54), (s * .100, -.205, 1.555)], .056, rings=6, wide=True, tile=tile(2))
        add("temple_a%d" % s, [(s * .070, .078, 1.505), (s * .118, .060, 1.500), (s * .150, .025, 1.455), (s * .168, -.005, 1.395),
                               (s * .205, -.015, 1.350)], .050, rings=6, wide=True, tile=tile(3), group=None)
        add("temple_b%d" % s, [(s * .085, .040, 1.530), (s * .145, .010, 1.530), (s * .195, -.030, 1.485), (s * .235, -.050, 1.445)],
            .040, rings=5, tile=tile(1))
        # the forelocks: thin strands down each side of the face, curling in over the mask
        add("fore_a%d" % s, [(s * .010, .094, 1.505), (s * .040, .103, 1.482), (s * .070, .098, 1.430), (s * .079, .087, 1.365),
                             (s * .060, .094, 1.300)], .019, rings=6, tile=tile(0))
        add("fore_b%d" % s, [(s * .046, .094, 1.512), (s * .074, .093, 1.470), (s * .092, .075, 1.410), (s * .094, .060, 1.340)],
            .022, rings=5, tile=tile(2))
    add("part", [(0.0, .099, 1.525), (0.004, .107, 1.495), (-.003, .106, 1.465), (-.002, .104, 1.452)], .021, rings=5, tile=tile(1))
    # the curtain: heavy side falls behind the shoulders, staggered, each tip flicking out
    for s, g in ((1.0, "r"), (-1.0, "l")):
        ks = [(.086, .030, -.02, 1.03, .058), (.100, -.012, .0, .90, .056), (.078, -.050, -.04, .95, .064)]
        for i, (x, y, dx, low, w) in enumerate(ks):
            mid = (1.40 + low) * 0.5
            add("side%d_%s" % (i, g), [(s * x, y, 1.50), (s * (x + .055), y - .015, 1.42), (s * (x + .082 + dx), y - .045, 1.30),
                                       (s * (x + .088 + dx), y - .085, mid), (s * (x + .070 + dx), y - .10, low + .08),
                                       (s * (x + .096 + dx * 2), y - .09, low)], w, rings=8, wide=True, tile=tile(i + 1), group=g)
    # the back: a broad wedge of hair, then long locks over it, the tips making the V the turnaround shows
    for name, x, y, low, w, g in [("back_u0", -.03, -.075, 1.02, .20, "c"), ("back_u1", .03, -.075, 1.02, .20, "c"), ("back_c", 0.0, -.11, .84, .190, "c"), ("back_l", -.070, -.095, .92, .160, "l"),
                                  ("back_r", .070, -.095, .90, .160, "r")]:
        add(name, [(x * .5, y + .06, 1.56), (x * .9, y - .04, 1.47), (x * 1.3, y - .055, 1.30), (x * 1.5, y - .05, 1.10),
                   (x * 1.4, y - .03, .96), (x * .9, y - .03, low)], w, rings=8, wide=True, peak=.45, tile=tile(0),
            group=g, hint=np.array([0, -1.0, 0.1]))
    over = [(-.11, -.02, 1.53, .90), (-.065, -.07, 1.56, .83), (-.03, -.09, 1.57, .78), (.025, -.095, 1.58, .76),
            (.06, -.08, 1.56, .84), (.105, -.03, 1.54, .88), (-.14, .0, 1.50, .98), (.14, .0, 1.50, 1.0)]
    for i, (x, y, top, low) in enumerate(over):
        g = "c" if abs(x) < .05 else ("l" if x < 0 else "r")
        add("over%d" % i, [(x * .6, y - .06, top), (x * 1.05, y - .13, 1.46), (x * 1.3, y - .165, 1.28), (x * 1.42, y - .16, 1.08),
                           (x * 1.34, y - .135, .92), (x * 1.5, y - .13, low)], .096, rings=8, peak=.4, tile=tile(i),
            group=g, hint=np.array([0, -1.0, 0.1]))
    # below the shoulders the whole mane gathers in behind the back (the turnaround's narrow fall)
    for p in locks:
        k = 0.34 * smooth(1.44, 1.12, p.v[:, 2])
        p.v[:, 0] *= 1 - k
        p.path[:, 0] *= 1 - 0.34 * smooth(1.44, 1.12, p.path[:, 2])
    cap = hair_cap()
    return [cap] + locks


def hair_cap():
    """The scalp under the crown: a coarse shell, so no bald gap shows between the locks."""
    rows, cols = 7, 14
    zs = np.linspace(0.122, -0.1, rows)
    A, Z = np.meshgrid(np.linspace(0, 2 * np.pi, cols, endpoint=False) + 0.2, zs)
    R = ray_out(A, Z, r0=0.15) + 0.009
    front = np.cos(A) > 0.25
    R = R * (1 - 0.0 * front)
    v = hl(np.stack([np.sin(A) * R, np.cos(A) * R, Z], -1).reshape(-1, 3))
    f = grid_faces(rows, cols, True)
    # the hairline: no cap over the forehead
    keep = []
    for q in f:
        c = v[q].mean(0)
        if not (c[1] > 0.02 and c[2] < 1.495):
            keep.append(q)
    uv = [[(0.5 * ((j % 4) / 4), 0.02), (0.5 * ((j % 4) / 4) + .125, .02), (0.5 * ((j % 4) / 4) + .125, .2),
           (0.5 * ((j % 4) / 4), .2)] for j in range(len(keep))]
    p = Piece("cap", "hair-mane", v, keep, uv, room=0.0).rigid("head")
    p.group = None
    p.t = None
    return p


CHAIN_BONES = 6


def mane_chains(locks):
    """Mean paths of the groups that swing: spring_mane_<g>_<i>; the group's locks skinned along it by arc length."""
    out = {}
    for g in ("c", "l", "r"):
        ms = [p for p in locks if getattr(p, "group", None) == g]
        res = []
        for p in ms:
            s = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(p.path, axis=0), axis=1))])
            s /= s[-1]
            t = np.linspace(0.14, 1.0, CHAIN_BONES)
            res.append(np.stack([np.interp(t, s, p.path[:, i]) for i in range(3)], -1))
        out[g] = np.mean(res, axis=0)
        names = ["spring_mane_%s_%d" % (g, i) for i in range(CHAIN_BONES)]
        for p in ms:
            w = {"head": np.zeros(len(p.v))}
            for n in names[:-1]:
                w[n] = np.zeros(len(p.v))
            for vi in range(len(p.v)):
                t = p.t[vi]
                u = smooth(0.08, 0.3, t)
                x = np.clip((t - 0.14) / 0.86, 0, 0.9999) * (CHAIN_BONES - 2)
                b0 = int(x)
                q = x - b0
                w["head"][vi] = 1 - u
                w[names[b0]][vi] += u * (1 - q)
                w[names[min(b0 + 1, CHAIN_BONES - 2)]][vi] += u * q
            p.w = w
    for p in locks:
        if not p.w:
            p.rigid("head")
    return out


# ------------------------------------------------------------------ the greatsword
GRIP_DIR = norm(np.array([0.0, 0.76, -0.65]))    # the blade from the fist, rest pose (he faces +Y)
_a = norm(np.array([0, 0, -1.0]) - GRIP_DIR * np.dot(np.array([0, 0, -1.0]), GRIP_DIR))
GRIP_AT = np.array([SH, 0.0, HAND_Z + 0.012]) + _a * 0.094 + np.array([-0.03, 0.0, 0.0])    # inside the closed fist
BLADE_LEN, BLADE_W = 0.88, 0.098                 # guard to the broken end; half width


def sword_frame():
    b = GRIP_DIR                                 # along the blade
    e = norm(np.cross(b, (1.0, 0, 0)))           # along the edge
    if e[2] < 0:
        e = -e
    n = np.cross(b, e)                           # out of the flat
    return b, e, n


def outline():
    """The blade's silhouette: (along, across) from the guard, a slab with a broken crenellated end."""
    L, W = BLADE_LEN, BLADE_W
    rng = np.random.RandomState(4)
    right = [(0.0, 1.0), (.10, 1.0), (.2, .97), (.32, 1.03), (.43, .98), (.52, .94), (.6, 1.0), (.68, 1.06),
             (.74, .99), (.8, 1.12), (.84, 1.03), (.88, 1.09)]
    tip = [(.93, .9), (.915, .72), (.965, .6), (.95, .42), (1.0, .08), (.965, -.06), (.975, -.34), (.93, -.46),
           (.945, -.72), (.895, -.9)]
    left = [(.86, -1.13), (.8, -1.0), (.73, -1.08), (.66, -.98), (.57, -1.02), (.48, -.95), (.36, -1.03), (.26, -.97),
            (.14, -1.02), (0.0, -1.0)]
    pts = right + tip + left
    return np.array([(a * L, c * W) for a, c in pts])


def core_outline():
    """The white-hot channel down the blade's heart."""
    L, W = BLADE_LEN, BLADE_W
    pts = [(0.0, .34), (.3, .3), (.42, .36), (.46, .24), (.6, .22), (.65, .28), (.72, .13), (.85, .1), (.94, 0.0),
           (.85, -.1), (.74, -.16), (.68, -.1), (.58, -.3), (.5, -.22), (.4, -.27), (.28, -.2), (.12, -.32), (0.0, -.34)]
    return np.array([(a * L, c * W) for a, c in pts])


def resample_like(core, ol):
    """Each outline point's nearest core point, for the bevel ring between them."""
    return np.array([core[np.argmin(np.linalg.norm(core - p * [1, .4], axis=1))] for p in ol])


def blade():
    b, e, n = sword_frame()
    guard_at = GRIP_AT + b * 0.105
    ol, co = outline(), core_outline()
    m = len(ol)
    TH = 0.030
    from mathutils.geometry import tessellate_polygon
    from mathutils import Vector
    v, faces = [], []

    def put(a, c, h):
        return guard_at + b * a + e * c + n * h
    rng = np.random.RandomState(9)
    jit = rng.uniform(-.0035, .0035, m)
    # the rings: edge (shared), both faces' rim tops, both faces' inner walls
    for i, (a, c) in enumerate(ol):
        v.append(put(a, c, 0.0))
    for sgn in (1.0, -1.0):
        for i, (a, c) in enumerate(ol):
            a2, c2 = a - 0.008 * np.sign(a - .5), c * 0.74
            v.append(put(a2, c2, sgn * (TH + jit[i])))
        for i, (a, c) in enumerate(ol):
            a3, c3 = a * 0.985, c * 0.5
            v.append(put(a3, c3, sgn * (TH * 0.78 + jit[i] * .5)))
    for k in range(2):
        r0 = m * (1 + 2 * k)
        r1 = r0 + m
        for i in range(m - 1):
            j = i + 1
            faces.append([i, j, r0 + j, r0 + i] if k == 0 else [j, i, r0 + i, r0 + j])
            faces.append([r0 + i, r0 + j, r1 + j, r1 + i] if k == 0 else [r0 + j, r0 + i, r1 + i, r1 + j])
    # the bottom end is hidden by the guard. Each face's middle stays solid metal under the core's glow plates.
    for k, sgn in enumerate((1.0, -1.0)):
        r1 = m * (2 + 2 * k)
        loop = [r1 + i for i in range(m)]
        tri = tessellate_polygon([[Vector(v[i]) for i in loop]])
        for t in tri:
            q = [loop[t[0]], loop[t[1]], loop[t[2]]]
            faces.append(q if sgn < 0 else q[::-1])
    plate = Piece("blade", "metal-blade", v, faces).rigid("hand.R")
    plate.ol = ol
    plate.guard_at, plate.frame = guard_at, (b, e, n)
    cores = []
    for k, sgn in enumerate((1.0, -1.0)):
        vv = [guard_at + b * a + e * c + n * sgn * (TH * 0.78 + 0.0035) for a, c in co]
        tri = tessellate_polygon([[Vector(p) for p in vv]])
        ff = [list(t) if sgn > 0 else list(t)[::-1] for t in tri]
        # keep the fan's winding out of the flat
        q = np.array(vv)
        d = np.cross(q[ff[0][1]] - q[ff[0][0]], q[ff[0][2]] - q[ff[0][0]])
        if np.dot(d, n * sgn) < 0:
            ff = [f[::-1] for f in ff]
        cores.append(Piece("core%d" % k, "glow-sword", vv, ff, room=0.0).rigid("hand.R"))
    return [plate] + cores


def hilt(uv_chain):
    b, e, n = sword_frame()
    g = GRIP_AT + b * 0.105
    out = []
    # the cross guard: a heavy iron bar
    sec = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    path = [g + e * d for d in (-0.135, -0.11, 0.11, 0.135)]
    bar = sweep("guard", "metal-guard", path, sec, np.array([0.02, 0.026, 0.026, 0.02]), side_hint=b,
                depth=np.array([0.018, 0.024, 0.024, 0.018]))
    out.append(bar.rigid("hand.R"))
    # the grip and the pommel collar, chain wound in the paint
    p = [g - b * 0.235, g - b * 0.205, g - b * 0.19, g - b * 0.02, g]
    sec8 = [(np.cos(t), np.sin(t)) for t in np.linspace(0, 2 * np.pi, 8, endpoint=False)]
    grip = sweep("grip", "leather-grip", p, sec8, np.array([0.024, 0.030, 0.019, 0.019, 0.022]), side_hint=e)
    out.append(grip.rigid("hand.R"))
    # three turns of chain round the blade's root: a ribbon of links
    for r in range(3):
        base = g + b * (0.032 + r * 0.033)
        pts = []
        for t in np.linspace(0, 2 * np.pi, 15):
            pts.append(base + e * np.cos(t) * (BLADE_W * 1.05) + n * np.sin(t) * 0.04 + b * 0.008 * np.sin(t * 2 + r))
        c = chain_along("wrap%d" % r, pts, step=0.047, uv=uv_chain, ln=0.056, wid=0.03, th=0.0066, flip=r * .4)
        out.append(c.rigid("hand.R"))
    return out
