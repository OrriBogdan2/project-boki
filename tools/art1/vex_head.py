"""ART-1 Vex (v2): what the head scan can't do itself, as data: the braid on its spring chain, the brows on their bones, the blink lid.
The head's shape, face, hair, goggles and the brass eye wire are the head scan's (vex_headscan.py). Blender frame: Z up, she faces +Y,
her right hand is +X."""
import numpy as np
from mathutils import Vector
from meshkit import Piece, catmull, norm, smooth, sweep, frames
from vex_cannon import J

NECK = J("head")
SK = 1.08                                   # scan head -> rig
S_NECK = np.array([0, -0.02, 1.614])


def hs(p):
    return NECK + (np.asarray(p, float) - S_NECK) * SK


# the rig's head targets (the body scan's head, scan units: +X her right): the head scan is placed on these
HC = hs((0, -0.015, 1.785))                  # the head's centre
GRID_CHIN = hs((0, 0, 1.655))[2]
EYE_Z = GRID_CHIN + 0.003 + 0.384 * 0.295   # the eye line
EYE_X = 0.0391                              # half the eye span (head scan, scaled): her eyes' centres at x = +-EYE_X * SK * 0.95
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


EYE_FRONT_Y = [HC[1] + 0.095]


def set_eye_y(bvh):
    o = Vector((EYE_X * SK * 0.95, 0.4, EYE_Z))
    hit = bvh.ray_cast(o, Vector((0, -1, 0)), 0.6)
    if hit[0] is not None:
        EYE_FRONT_Y[0] = hit[0][1]


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


BRAID_N = 8


def braid():
    """One thick braid from the back of the head down between her shoulder blades (the v2 sheet: to the jacket's hem line), lobes
    alternating on a spring chain, a gold cartridge-bead ring at its root and one near its end, a fanned tip."""
    z0 = HC[2] - 0.08
    pts = np.array([(-.01, HC[1] - .10, z0), (-.025, HC[1] - .14, z0 - .08), (-.04, HC[1] - .16, z0 - .18), (-.05, HC[1] - .165, z0 - .28),
                    (-.055, HC[1] - .16, z0 - .38), (-.06, HC[1] - .155, z0 - .45)])
    path = catmull(pts, 40)
    t, s_, n = frames(path, (0, 1.0, 0))
    out = []
    N = 9
    for i in range(N):
        a, b = int(i / N * 34), int((i + 1) / N * 34)
        ctr = path[(a + b) // 2]
        axis = norm(path[b] - path[a] + s_[a] * 0.45 * (1 if i % 2 else -1) * np.linalg.norm(path[b] - path[a]))
        off = s_[a] * 0.014 * (1 if i % 2 else -1)
        L_ = np.linalg.norm(path[b] - path[a]) * 0.95
        rd = 0.036 * (1 - 0.3 * i / N) + 0.002
        loc = [ctr + off - axis * L_, ctr + off - axis * L_ * 0.4, ctr + off + axis * L_ * 0.4, ctr + off + axis * L_]
        sec = [(np.cos(x), np.sin(x)) for x in np.linspace(0, 2 * np.pi, 6, endpoint=False)]
        p = sweep("braid%d" % i, "hair-mane", loc, sec, np.array([0.25, 1.0, 1.0, 0.25]) * rd, side_hint=np.array([0, 1.0, 0]), uv_rect=(i % 4 * 0.25, 0, i % 4 * 0.25 + 0.25, 1))
        p.bc = (a + b) / 2 / 39.0
        p.rigid("head")
        p.group = "braid"
        out.append(p)
    for k, (i_, r) in enumerate(((3, 0.03), (31, 0.026))):
        tp = path[i_]
        sec = [(np.cos(x), np.sin(x)) for x in np.linspace(0, 2 * np.pi, 8, endpoint=False)]
        tie = sweep("braidtie%d" % k, "brass-vex", [tp - t[i_] * .016, tp, tp + t[i_] * .016], sec, np.array([r, r + 0.003, r]), side_hint=np.array([0, 1.0, 0]), tip=False)
        tie.bc = i_ / 39.0
        tie.group = "braid"
        out.append(tie.rigid("head"))
    tp = path[34]
    for i, (dx, dz, w) in enumerate(((.02, -.08, .03), (-.015, -.095, .032), (-.045, -.07, .026))):
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


def surf(bvh, x, z, off=0.0):
    hit = bvh.ray_cast(Vector((x, 0.6, z)), Vector((0, -1, 0)), 1.2)
    return None if hit[0] is None else np.array(hit[0]) + np.array(hit[1]) * off


K_REF = EYE_X * SK * 0.95 / 70.0            # metres per pixel of vex_head.png's front view (displayed): half the eye span is 70 px


K_REF = EYE_X * SK * 0.95 / 81.5            # metres per pixel of the head scan's front grid render (hgrid_front.png): half the eye span is 81.5 px


def scan_brows(bvh):
    """The brows as bone-driven strips laid on the painted ones (front view of the head sheet)."""
    out = []
    pts_ref = [(34, 32), (55, 52), (71, 63), (101, 70), (119, 60)]
    wd = np.array([0.0062, 0.0064, 0.006, 0.0052, 0.0024])
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
