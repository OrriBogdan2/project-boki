"""ART-1 Vex: head, face, hair, braid, goggles, cyber-eye, spine, ammo belt, as data. The head's SHAPE is the scan's (a clean grid cast onto it, so the
face's features survive the budget); hair and the rest are scripted. Blender frame: Z up, she faces +Y, her right hand is +X."""
import numpy as np
from mathutils import Vector
from meshkit import Piece, catmull, norm, smooth, sweep, frames, rot_about
from vex_cannon import J, ring, box, belt_path_tile

NECK = J("head")
SK = 1.08                                   # scan head -> rig
S_NECK = np.array([0, -0.02, 1.614])


def hs(p):
    return NECK + (np.asarray(p, float) - S_NECK) * SK + np.array([0, 0.02, 0]) * 0


# scan units (flipped: +X her right), read on grid_front
HC = hs((0, -0.015, 1.785))                  # the head's centre
GRID_CHIN0 = hs((0, 0, 1.655))[2]
EYE_Z = GRID_CHIN0 + 0.003 + 0.384 * 0.295        # the head scan's eye line (vex_headscan.py)
EYE_X = 0.0408
EYE_R = 0.0245
GRID_CHIN = hs((0, 0, 1.655))[2]
TOP = hs((0, 0, 1.9))[2]
LENS = [(-1, 0), (-0.45, 0.38), (0.45, 0.38), (1, 0), (0.45, -0.3), (-0.45, -0.3)]


def grid_faces(rows, cols, wrap=False):
    f = []
    for i in range(rows - 1):
        for j in range(cols - (0 if wrap else 1)):
            a = i * cols + j
            b = i * cols + (j + 1) % cols
            f.append([a, b, b + cols, a + cols])
    return f


def cast(bvh, ang, z):
    """The scan's surface from outside toward the head axis, at height z, angle ang from +Y toward +X."""
    d = Vector((-np.sin(ang), -np.cos(ang), 0))
    o = Vector((HC[0] + np.sin(ang) * 0.3, HC[1] + np.cos(ang) * 0.3, z))
    hit = bvh.ray_cast(o, d, 0.5)
    return None if hit[0] is None else np.array(hit[0])


def head(bvh):
    """The whole head as one grid: rows closer through the features, columns closer across the face. The neck end sinks into the scan's collar."""
    zs = np.concatenate([np.linspace(GRID_CHIN - 0.012, EYE_Z - 0.09, 3), np.linspace(EYE_Z - 0.078, EYE_Z + 0.045, 13), np.linspace(EYE_Z + 0.06, TOP - 0.03, 5), [TOP - 0.008]])
    angs = np.concatenate([np.linspace(-np.pi + 0.4, -1.15, 4), np.linspace(-0.95, 0.95, 19), np.linspace(1.15, np.pi - 0.4, 4), [np.pi]])
    rows, cols = len(zs), len(angs)
    G = np.zeros((rows, cols, 3))
    for i, z in enumerate(zs):
        for j, a in enumerate(angs):
            p = cast(bvh, a, z)
            if p is None:
                k = max(0.05, 1 - ((z - HC[2]) / 0.135) ** 2) ** 0.5
                p = HC + np.array([np.sin(a), np.cos(a), 0]) * 0.11 * k + [0, 0, z - HC[2]]
            G[i, j] = p
    # sockets: a shallow dish where the eyes sit
    v = G.reshape(-1, 3)
    for s in (1.0, -1.0):
        c = eye_c(s)
        q = (v - c) * [1.0 / 0.04, 0, 1.0 / 0.028]
        d2 = (q * q).sum(1)
        v = v - np.array([0, 1.0, 0]) * (0.011 * np.exp(-d2 * 1.4))[:, None]
    p = Piece("face", "skin-vex", v, grid_faces(rows, cols, True)).rigid("head")
    p.orient(tuple(HC))
    return p


def eye_c(s):
    return np.array([s * EYE_X * SK * 0.95, EYE_FRONT_Y[0] - 0.012, EYE_Z])


EYE_FRONT_Y = [HC[1] + 0.095]


def set_eye_y(bvh):
    o = Vector((EYE_X * SK * 0.95, 0.4, EYE_Z))
    hit = bvh.ray_cast(o, Vector((0, -1, 0)), 0.6)
    if hit[0] is not None:
        EYE_FRONT_Y[0] = hit[0][1]


def eyeball():
    """Her natural left eye: the front cap of a ball, corner uvs a flat view of it."""
    c = eye_c(-1.0) + [0, -0.012, 0]
    rows, cols = 5, 9
    v, uv = [], []
    for i in range(rows):
        for j in range(cols):
            a, b = (j / (cols - 1) - 0.5) * 2.0, (i / (rows - 1) - 0.5) * 1.5
            d = norm(np.array([np.sin(a) * np.cos(b), np.cos(a) * np.cos(b), np.sin(b)]))
            d = rot_about(d, (0, 0, 1), 0.14)
            v.append(c + d * EYE_R)
            uv.append((a, b))
    p = Piece("eyeL", "eyes-vex", np.array(v), grid_faces(rows, cols)).rigid("head")
    p.eye_uv = np.array(uv)
    p.orient(tuple(c))
    return p


def lids():
    """The left eye's almond: lids on a sphere round the eye. The upper turns on lid.L (blink, wink), the lower stays; both flick up at the outer corner: the wing."""
    s = -1.0
    c = eye_c(s) + [0, -0.012, 0]
    out = []
    for up in (True, False):
        rows, cols = 4, 8
        v = []
        for i in range(rows):
            for j in range(cols):
                az = (j / (cols - 1) - 0.5) * 2.2
                bow = 1 - (az / 1.1) ** 2
                edge = (0.02 + 0.40 * bow + 0.22 * az) if up else (0.02 - 0.28 * bow + 0.22 * az)
                top = 1.2 if up else -1.15
                el = edge + (top - edge) * i / (rows - 1)
                d = np.array([np.sin(az) * s * np.cos(el), np.cos(az) * np.cos(el), np.sin(el)])
                d = rot_about(d, (0, 0, 1), 0.14)
                v.append(c + d * (EYE_R * (1.08 + 0.1 * i / (rows - 1))))
        p = Piece("lid%sL" % ("U" if up else "D"), "skin-vex", np.array(v), grid_faces(rows, cols))
        p.rigid("lid.L" if up else "head")
        p.orient(tuple(c))
        out.append(p)
    return out


def brows():
    out = []
    for s in (1.0, -1.0):
        side = "R" if s > 0 else "L"
        y = EYE_FRONT_Y[0]
        pts = np.array([(0.012, y + 0.006, EYE_Z + 0.036), (0.04, y + 0.003, EYE_Z + 0.046), (0.07, y - 0.012, EYE_Z + 0.05), (0.098, y - 0.04, EYE_Z + 0.036)]) * [s, 1, 1]
        path = catmull(pts, 6)
        wd = np.array([0.006, 0.0075, 0.0072, 0.006, 0.004, 0.0006])
        b = sweep("brow" + side, "hair-mane", path, [(-1, 0), (0, 0.3), (1, 0), (0, -0.3)], wd, side_hint=np.array([0, 1.0, 0.3]), uv_rect=(0.1, 0.02, 0.18, 0.1), room=0.0)
        out.append(b.rigid("brow." + side))
    return out


def cyber_eye():
    """The brass cyber-eye on her right: a lensed barrel out of the dark eye plate. Three lathes along the view."""
    c = eye_c(1.0) + [0, 0.0, 0]
    d = norm(np.array([0.2, 1.0, 0.02]))
    a = norm(np.cross(d, (0, 0, 1.0)))
    b = np.cross(a, d)

    def lat(name, mat, prof, n=14):
        v, f = [], []
        for s_, r in prof:
            for t in np.linspace(0, 2 * np.pi, n, endpoint=False):
                v.append(c + d * s_ + a * np.cos(t) * r + b * np.sin(t) * r)
        for i in range(len(prof) - 1):
            for j in range(n):
                p, q = i * n + j, i * n + (j + 1) % n
                f.append([p, q, q + n, p + n])
        return Piece(name, mat, np.array(v), f).rigid("head")
    rim = lat("eyerim", "brass-vex", [(-0.012, 0.043), (0.006, 0.043), (0.014, 0.037), (0.014, 0.03), (0.006, 0.026)])
    lens = lat("eyelens", "glow-vex", [(0.006, 0.0265), (0.0095, 0.02), (0.0095, 0.0085), (0.0095, 0.0)], n=12)
    ringd = lat("eyering", "metal-vex", [(0.0095, 0.017), (0.0115, 0.0165), (0.0115, 0.0115), (0.0095, 0.011)], n=12)
    pup = lat("eyepupil", "metal-vex", [(0.0095, 0.0055), (0.0125, 0.0045), (0.0125, 0.0)], n=8)
    return [rim, lens, ringd, pup]


# ---- hair
def lock(name, pts, w0, rings=7, peak=0.32, tip=0.0, hint=None, tile=0.0, group=None, root=0.45, soft=0.0, tilt=0.62):
    path = catmull(np.asarray(pts, float) + HC, rings)
    k = np.linspace(0, 1, rings)
    prof = np.minimum(1.0, root + k / peak * (1 - root)) * (1 - smooth(peak, 1.0, k)) ** 0.8
    wd = w0 * np.maximum(prof, 0.012 + soft * smooth(0.8, 1.0, k)) + tip
    if hint is None:
        hint = norm(path[0] - HC)
    p = sweep(name, "hair-mane", path, LENS, wd, side_hint=hint, uv_rect=(tile, 0.0, tile + 0.25, 1), room=0.0, depth=wd * tilt)
    p.t = np.repeat(k, len(LENS))
    p.group = group
    p.path = path
    p.mid = path[len(path) // 2]
    return p


def skull_pt(bvh, d, lift):
    d = norm(np.asarray(d, float))
    hit = bvh.ray_cast(Vector(HC + d * 0.32), Vector(-d), 0.5)
    r = 0.13 if hit[0] is None else np.linalg.norm(np.array(hit[0]) - HC)
    return d * (r + lift)


def hair(bvh):
    L = []
    add = lambda *a, **k: L.append(lock(*a, **k))
    tile = lambda i: (i * 0.25) % 1.0
    # the crown: clumps from the parting on her left, over the skull and back, drifting toward her right
    for i, deg in enumerate((-82, -60, -38, -14, 12, 38, 62, 88)):
        al = np.radians(deg)
        pts = []
        line = 50 - 8 * np.cos(al * 2.2) + 4 * np.sin(i * 2.4)
        for t_ in np.linspace(0, 1, 6):
            th = np.radians(line + (150 - line) * t_)
            b = al * (1 - 0.15 * t_) + 0.28 * t_
            d = np.array([np.sin(th) * np.sin(b), np.cos(th), np.sin(th) * np.cos(b)])
            pts.append(skull_pt(bvh, d, 0.009 + 0.02 * smooth(0.0, 0.4, t_)))
        add("sweep%d" % i, pts, .082, rings=6, peak=.45, tile=tile(i), root=.5, soft=.2)
    # the swept fringe: from the parting across her forehead, past the right eye's temple, long down the front of her right shoulder
    add("fore0", [(-.035, .105, .125), (.03, .128, .095), (.09, .112, .04), (.128, .07, -.03), (.142, .05, -.13), (.13, .06, -.24), (.112, .075, -.36), (.105, .085, -.47)], .05, rings=9, peak=.3, tile=tile(0), group="f", root=.75)
    add("fore1", [(-.02, .115, .115), (.04, .124, .07), (.082, .115, .012), (.108, .095, -.06), (.122, .085, -.13), (.118, .09, -.21)], .034, rings=7, peak=.3, tile=tile(1), root=.7, soft=.1)
    add("fore2", [(.0, .12, .10), (.05, .125, .05), (.078, .118, .0), (.085, .11, -.05)], .022, rings=5, peak=.3, tile=tile(2), root=.8)
    # her left: shorter, hooked out at the jaw
    add("left0", [(-.06, .10, .10), (-.115, .07, .05), (-.142, .04, -.04), (-.15, .02, -.13), (-.175, .01, -.2), (-.215, .0, -.235)], .05, rings=7, peak=.35, tile=tile(3), root=.7)
    add("left1", [(-.09, .06, .10), (-.14, .02, .03), (-.158, -.02, -.07), (-.168, -.03, -.17), (-.2, -.04, -.26)], .05, rings=6, peak=.35, tile=tile(0), root=.7)
    add("right1", [(.10, .03, .09), (.14, .0, .02), (.158, -.03, -.08), (.165, -.04, -.17), (.195, -.05, -.25)], .052, rings=6, peak=.35, tile=tile(1), root=.7)
    # the back: a full fall to the nape, points flicking out
    for i, (x, low, w, sx) in enumerate(((-.115, -.25, .06, -.05), (-.06, -.3, .068, -.015), (.0, -.33, .07, .0), (.06, -.3, .068, .015), (.115, -.25, .06, .05))):
        add("back%d" % i, [(x * .5, -.09, .125), (x, -.14, .05), (x * 1.15, -.155, -.05), (x * 1.2, -.135, -.16), (x * 1.2 + sx, -.125, low + .05), (x * 1.2 + sx * 2.2, -.13, low)], w, rings=6, peak=.45, tile=tile(i), hint=np.array([0, -1.0, 0.1]), root=.7)
    # the cowlick
    add("cowl0", [(.01, .02, .138), (.015, .0, .175), (.0, -.03, .2), (-.03, -.05, .205)], .018, rings=4, peak=.3, tile=tile(2), root=.9)
    add("cowl1", [(-.01, -.02, .138), (.02, -.05, .17), (.06, -.07, .178)], .014, rings=3, peak=.3, tile=tile(3), root=.9)
    # scalp under the locks
    rows, cols = 6, 12
    cap_v = []
    for i in range(rows):
        th = np.radians(36 + (140 - 36) * i / (rows - 1))
        for j in range(cols):
            a = j / cols * 2 * np.pi
            cap_v.append(skull_pt(bvh, (np.sin(th) * np.sin(a), np.cos(th) * 0.92 - 0.0, np.sin(th) * np.cos(a)) if False else
                                  (np.sin(a) * np.sin(th), np.cos(a) * np.sin(th), np.cos(th)), 0.004))
    cap_v = np.array(cap_v) + HC
    f = grid_faces(rows, cols, True)
    keep = [q for q in f if not (((cap_v[q].mean(0) - HC)[1] > 0.045) and ((cap_v[q].mean(0) - HC)[2] < 0.08))]
    uv = [[(.0, .3), (.2, .3), (.2, .5), (.0, .5)] for _ in keep]
    cap = Piece("cap", "hair-mane", cap_v, keep, uv, room=0.0).rigid("head")
    cap.orient(tuple(HC))
    cap.group, cap.t = None, None
    return [cap] + L


BRAID_N = 8


def braid():
    """One long braid from the nape, down behind her left shoulder to the thigh: alternate fat lobes on a spring chain, a brass tie, a fanned tip."""
    z0 = HC[2] - 0.11
    pts = np.array([(-.02, HC[1] - .09, z0 - .02), (-.075, HC[1] - .165, z0 - .14), (-.115, HC[1] - .20, z0 - .32), (-.135, HC[1] - .195, z0 - .52), (-.15, HC[1] - .18, z0 - .72), (-.17, HC[1] - .175, z0 - .86)])
    path = catmull(pts, 40)
    t, s_, n = frames(path, (0, 1.0, 0))
    out = []
    N = 13
    for i in range(N):
        a, b = int(i / N * 34), int((i + 1) / N * 34)
        tw = 0.45 * (1 if i % 2 else -1)
        ctr = path[(a + b) // 2]
        axis = norm(path[b] - path[a] + s_[a] * 0.45 * (1 if i % 2 else -1) * np.linalg.norm(path[b] - path[a]))
        off = s_[a] * 0.012 * (1 if i % 2 else -1)
        L_ = np.linalg.norm(path[b] - path[a]) * 0.95
        rd = 0.03 * (1 - 0.35 * i / N) + 0.002
        loc = [ctr + off - axis * L_, ctr + off - axis * L_ * 0.4, ctr + off + axis * L_ * 0.4, ctr + off + axis * L_]
        p = sweep("braid%d" % i, "hair-mane", loc, [(np.cos(x), np.sin(x)) for x in np.linspace(0, 2 * np.pi, 6, endpoint=False)], np.array([0.25, 1.0, 1.0, 0.25]) * rd, side_hint=np.array([0, 1.0, 0]), uv_rect=(i % 4 * .25, .2, i % 4 * .25 + .25, .9), tip=False)
        p.bc = (a + b) / 2 / 39.0
        p.rigid("head")
        p.group = "braid"
        out.append(p)
    tp = path[34]
    tie = sweep("braidtie", "brass-vex", [tp - t[34] * .012, tp, tp + t[34] * .012], [(np.cos(x), np.sin(x)) for x in np.linspace(0, 2 * np.pi, 6, endpoint=False)], np.array([0.016, 0.018, 0.016]), side_hint=np.array([0, 1.0, 0]), tip=False)
    tie.bc = 34 / 39.0
    tie.group = "braid"
    out.append(tie.rigid("head"))
    for i, (dx, dz, w) in enumerate(((.03, -.17, .034), (-.02, -.2, .036), (-.075, -.15, .028))):
        a0 = tp - HC
        p = lock("btip%d" % i, [a0, a0 + [dx * .4, 0, dz * .4], a0 + [dx, .0, dz]], w, rings=4, peak=.3, tile=.25 * i, root=.7, hint=np.array([0, 1.0, 0]))
        p.bc = 0.95
        p.group = "braid"
        p.rigid("head")
        out.append(p)
    return out, path


def braid_chain(ps, path):
    idx = np.linspace(1, 39, BRAID_N + 1).astype(int)
    pts = path[idx]
    pos = np.linspace(0, 1, BRAID_N + 1)
    names = ["spring_braid_%d" % i for i in range(BRAID_N)]
    for p in ps:
        # along the path by nearest point, soft between the links
        d = np.linalg.norm(p.v[:, None, :] - path[None, :, :], axis=2)
        u = np.argmin(d, axis=1) / 39.0
        x = np.clip(u * (BRAID_N - 1) / 0.98, 0, BRAID_N - 1.0001)
        w = {n: np.zeros(len(p.v)) for n in names}
        for vi, xv in enumerate(x):
            b = int(xv)
            q = xv - b
            w[names[b]][vi] += 1 - q
            w[names[min(b + 1, BRAID_N - 1)]][vi] += q
        p.w = w
    return names, pts


def fore_chain(L):
    """The long front lock swings on a short chain."""
    p = next(q for q in L if q.name == "fore0")
    n = 4
    names = ["spring_hairfront_%d" % i for i in range(n)]
    pts = p.path[[3, 4, 6, 7, 8]]
    w = {"head": np.zeros(len(p.v))}
    for b in names:
        w[b] = np.zeros(len(p.v))
    k = p.t
    for vi, t_ in enumerate(k):
        u = smooth(0.3, 0.45, t_)
        x = np.clip((t_ - 0.35) / 0.65, 0, 0.9999) * (n - 1)
        b0 = int(x)
        q = x - b0
        w["head"][vi] = 1 - u
        w[names[b0]][vi] += u * (1 - q)
        w[names[min(b0 + 1, n - 1)]][vi] += u * q
    p.w = w
    return names, pts


def goggles(bvh):
    """Racing goggles pushed up into her hair: two big lenses, a frame, the strap round the head."""
    out = []
    y0 = HC[1] + 0.098
    z = HC[2] + 0.108
    tilt = norm(np.array([0, 0.72, 0.7]))
    side = np.array([1.0, 0, 0])
    up = np.cross(tilt, side)
    if up[2] < 0:
        up = -up
    for s in (1.0, -1.0):
        c = np.array([s * 0.056 + 0.004, y0, z - 0.004 * s])
        for nm, mat, r0, wf, hf, th in (("gfr", "metal-vex", 1.0, 0.052, 0.036, 0.02), ("gl", "metal-vex", 0.8, 0.052, 0.036, 0.0225)):
            v = [c - tilt * 0.012]
            f = []
            n = 11
            ring_ = []
            for t in np.linspace(0, 2 * np.pi, n, endpoint=False):
                ring_.append(c + side * np.cos(t) * wf * r0 + up * np.sin(t) * hf * r0)
            top = [p + tilt * th for p in ring_]
            v = ring_ + top + [c + tilt * (th + 0.003)]
            for j in range(n):
                a, b = j, (j + 1) % n
                f.append([a, b, b + n, a + n])
                f.append([a + n, b + n, 2 * n])
            p = Piece(nm + ("R" if s > 0 else "L"), mat, np.array(v), f).rigid("head")
            p.orient(tuple(c - tilt * 0.02))
            out.append(p)
    out.append(box("gbridge", "metal-vex", (0, y0 + 0.01, z), (0.012, 0, 0), tilt * 0.006, up * 0.01, "head"))
    pts = []
    for a in np.linspace(-np.pi * 0.62, np.pi * 0.62, 11):
        a2 = a
        d = norm(np.array([np.sin(a2), -np.cos(a2) * -1.0, 0.82 - 0.36 * abs(a2) / 2.0]))
        pts.append(HC + skull_pt(bvh, d, 0.026))
    st = sweep("gstrap", "leather-vex", pts, [(-1, 0), (0, .25), (1, 0), (0, -.25)], np.full(len(pts), 0.016), side_hint=np.array([0, 0, 1.0]), tip=False, depth=np.full(len(pts), 0.012)).rigid("head")
    out.append(st)
    return out


def ear(bvh):
    """Her left ear with the plug and a ring (the right one sits under the fringe)."""
    c = HC + np.array([-0.128, -0.012, -0.03])
    ax = norm(np.array([-1.0, -0.25, 0.0]))
    a = np.array([0, 0, 1.0])
    b = norm(np.cross(ax, a))
    v = []
    prof = [(-0.003, 0.0), (0.006, 0.7), (0.008, 1.0)]
    f = []
    n = 8
    for s, r in prof:
        for t in np.linspace(0, 2 * np.pi, n, endpoint=False):
            v.append(c + ax * s + a * np.sin(t) * r * 0.036 + b * np.cos(t) * r * 0.024)
    for i in range(2):
        for j in range(n):
            p, q = i * n + j, i * n + (j + 1) % n
            f.append([p, q, q + n, p + n])
    pc = Piece("ear", "skin-vex", np.array(v), f).rigid("head")
    pc.orient(tuple(c - ax * 0.03))
    th = np.linspace(0, 2 * np.pi, 8)
    rg = c + ax * 0.012 + a * -0.04
    r = sweep("earring", "metal-vex", [rg + a * np.cos(t) * 0.011 + b * np.sin(t) * 0.011 for t in th], ring(3), np.full(8, 0.0026), side_hint=ax, tip=False).rigid("head")
    return [pc, r]


def spine(z0, z1, ysurf):
    """The cyber-spine: chrome vertebrae down the bare back, a glowing core in each, side stubs. ysurf(z) -> her back's y."""
    out = []
    N = 11
    for i, z in enumerate(np.linspace(z1, z0, N)):
        y = ysurf(z)
        b = "hips" if z > 0.5 * (z0 + z1) * 0 + Z_WAIST else "root"
        w = 0.021 * (1 - 0.2 * i / N)
        out.append(box("vert%d" % i, "metal-vex", (0, y - 0.006, z), (w, 0, 0), (0, 0.012, 0), (0, 0, 0.0165), b))
        out.append(box("vstub%d" % i, "metal-vex", (0, y - 0.002, z), (w * 2.1, 0, 0), (0, 0.006, 0), (0, 0, 0.0052), b))
        out.append(box("vglow%d" % i, "glow-vex", (0, y - 0.0185, z), (w * 0.6, 0, 0), (0, 0.0015, 0), (0, 0, 0.01), b))
    return out


Z_WAIST = 0.0


def ammo_belt(surf, pts_top, pts_low):
    pass


# ---- the fine-detail head: the head scan carries face, hair, goggles, ears, cyber-eye plate; here only what must move or glow on it
def surf(bvh, x, z, off=0.0):
    hit = bvh.ray_cast(Vector((x, 0.6, z)), Vector((0, -1, 0)), 1.2)
    return None if hit[0] is None else np.array(hit[0]) + np.array(hit[1]) * off


K_REF = EYE_X * SK * 0.95 / 70.0            # metres per pixel of vex_head.png's front view (displayed): half the eye span is 70 px


def scan_brows(bvh):
    """The brows as bone-driven strips laid on the painted ones (front view of the head sheet)."""
    out = []
    pts_ref = [(32, 16), (55, 26), (82, 33), (112, 34), (128, 24)]
    wd = np.array([0.0052, 0.0062, 0.0058, 0.0042, 0.0012])
    for s, side in ((-1.0, "L"), (1.0, "R")):
        path = []
        for rx, rz in pts_ref:
            p = surf(bvh, s * rx * K_REF, EYE_Z + rz * K_REF, 0.0022)
            if p is not None:
                path.append(p)
        if len(path) < 3:
            continue
        path = catmull(np.array(path), 6)
        b = sweep("ebrow" + side, "leather-vex", path, [(-1, 0), (0, 0.3), (1, 0), (0, -0.3)], np.interp(np.linspace(0, 1, 6), np.linspace(0, 1, 5), wd), side_hint=np.array([0, 1.0, 0.3]), room=0.0)
        out.append(b.rigid("brow." + side))
    return out


def scan_lens(bvh):
    """The glowing ring of the cyber-eye on the scan's brass plate."""
    c = surf(bvh, EYE_X * SK * 0.95, EYE_Z, -0.004)
    n_ = norm(np.array([0.22, 1.0, 0.0]))
    a = norm(np.cross(n_, (0, 0, 1.0)))
    b = np.cross(a, n_)

    def lat(name, mat, prof, m=12):
        v, f = [], []
        for s_, r in prof:
            for t in np.linspace(0, 2 * np.pi, m, endpoint=False):
                v.append(c + n_ * s_ + a * np.cos(t) * r + b * np.sin(t) * r)
        for i in range(len(prof) - 1):
            for j in range(m):
                p, q = i * m + j, i * m + (j + 1) % m
                f.append([p, q, q + m, p + m])
        return Piece(name, mat, np.array(v), f).rigid("head")
    k = K_REF
    return [lat("eyelens", "glow-vex", [(0.0065, 24 * k), (0.0072, 16.5 * k), (0.0072, 10.5 * k), (0.0062, 8.5 * k)]),
            lat("eyepupil", "metal-vex", [(0.006, 8.5 * k), (0.0075, 5 * k), (0.0075, 0.0)], m=8)]


def blink_lid(bvh):
    """Her left upper lid: at rest tucked up under the brow's skin (hidden), lid.L brings it down over the painted eye. Skin shell round the eye's centre."""
    p0 = surf(bvh, -EYE_X * SK * 0.95, EYE_Z)
    r = 0.03
    c = p0 - np.array([0, r - 0.0012, 0])
    rows, cols = 4, 9
    v = []
    for i in range(rows):
        for j in range(cols):
            az = (j / (cols - 1) - 0.5) * 1.5
            el = 0.72 + 0.62 * i / (rows - 1)            # above the eye: under the skin at rest
            d = np.array([-np.sin(az) * np.cos(el), np.cos(az) * np.cos(el), np.sin(el)])
            v.append(c + d * r)
    p = Piece("lidUL", "skin-vex", np.array(v), grid_faces(rows, cols)).rigid("lid.L")
    p.orient(tuple(c))
    return p, c


def spine_plate(z_top, ysurf, hit):
    """The chrome plate between her shoulder blades that the spine runs from: wider at the top, brass-edged by paint. On the back's surface."""
    rows, cols = 5, 7
    v = []
    for i in range(rows):
        k = i / (rows - 1)
        z = z_top - 0.13 * k
        w = 0.092 - 0.05 * smooth(0.45, 0.8, k)
        for j in range(cols):
            x = (j / (cols - 1) - 0.5) * 2 * w
            h = hit(x, z)
            y = (h[1] if h is not None else ysurf(z)) - 0.006
            v.append((x, y, z))
    p = Piece("splate", "metal-vex", np.array(v), grid_faces(rows, cols)).rigid("hips")
    p.orient((0, 0.05, z_top - 0.06))
    return [p]
