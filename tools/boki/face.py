"""The Boki face as geometry: lids that slide over the eye dome, brows and a mouth that lies on the muzzle.

Every expression is the same vertex grid with a different edge curve, so each one is one blend shape and they mix.
Lid and mouth columns run out from the nose: a = 0 at the inner corner side of the eye centre, a = 1 outward.
"""
import math

import numpy as np

# blend shape -> (upper lid edge, lower lid edge) as functions of a in -1..1 (a > 0 outward), in dome units; h(a) is
# the top of the dome, so 0.96 * h is a wide open eye
def h(a):
    return np.sqrt(np.clip(1.0 - a * a, 0.0, 1.0))


OPEN_U = lambda a: 0.90 * h(a)
OPEN_L = lambda a: -0.97 * h(a)
LIDS = {
    "blink": (lambda a: -0.20 + 0.30 * a * a, lambda a: -0.13 + 0.30 * a * a),
    "closed": (lambda a: -0.22 + 0.42 * a * a, lambda a: -0.13 + 0.42 * a * a),
    "happy": (lambda a: 0.42 - 0.72 * a * a - 0.05, lambda a: 0.42 - 0.72 * a * a + 0.05),
    "sad": (lambda a: np.minimum((0.66 - 0.40 * a), 0.95) * h(a), lambda a: -0.90 * h(a)),
    "sleepy": (lambda a: 0.02 + 0.06 * a * a, lambda a: -0.82 * h(a)),
    "angry": (lambda a: np.minimum(0.30 + 0.48 * a, 0.92 * h(a)), lambda a: -0.70 * h(a)),
}
BROWS = {  # dx outward, dy, tilt (radians, + is the inner end down)
    "rest": (0.0, 0.0, 0.10),
    "happy": (0.0, 0.016, 0.0),
    "sad": (-0.006, 0.020, -0.55),
    "sleepy": (0.0, -0.008, -0.1),
    "angry": (-0.012, -0.030, 0.62),
    "closed": (0.0, -0.004, 0.0),
    "blink": (0.0, -0.002, 0.1),
}
# the species' numbers (its module's FACE overrides these before the build)
FACE = {"mouth_w": 0.084, "mouth_y": 0.385, "mouth_z": -0.36, "cat_mouth": True, "brow_x": 0.100, "brow_up": 0.040,
        "brow_k": 1.0, "fang_k": 1.0}


def mouth_shapes():
    """Shape -> (upper edge(x), lower edge(x), width scale), with x in -w..w."""
    w, y0 = FACE["mouth_w"], FACE["mouth_y"]
    h_k = w / 0.084

    def rest_u(x):
        t = np.abs(x) / w
        if FACE["cat_mouth"]:
            return y0 + 0.020 * (t - 0.42) ** 2 * 2.4 - 0.008 + 0.012 * t
        return y0 - 0.016 * h_k * (1 - t * t)

    def line_l(x):
        return rest_u(x) - 0.0085

    def open_u(x, d, ws):
        return lambda xx: y0 + d - 0.012 * (xx / w) ** 2

    return {
        "rest": (rest_u, line_l, 1.0),
        "m_smile": (lambda x: rest_u(x) + 0.004, lambda x: rest_u(x) - 0.058 * (1 - (x / w) ** 2) - 0.004, 1.1),
        "m_frown": (lambda x: y0 - 0.006 - 0.018 * (x / w) ** 2, lambda x: y0 - 0.018 - 0.018 * (x / w) ** 2, 0.8),
        "m_snarl": (lambda x: y0 + 0.006 - 0.005 * (x / w) ** 2, lambda x: y0 - 0.050 + 0.026 * (x / w) ** 2, 1.05),
        "m_chomp": (lambda x: y0 + 0.002 - 0.010 * (x / w) ** 2, lambda x: y0 - 0.064 * (1 - (x / w) ** 2) - 0.006, 0.72),
        "m_o": (lambda x: y0 - 0.006 + 0.014 * (1 - (x / w) ** 2), lambda x: y0 - 0.006 - 0.016 * (1 - (x / w) ** 2), 0.34),
    }


# atlas strips (u0, u1)
STRIP = {"upper": (0.02, 0.18), "lower": (0.24, 0.40), "brow": (0.46, 0.58), "mouth": (0.64, 0.82), "fang": (0.88, 0.98)}
UPPER_ROWS, COLS = 7, 13
LID_V = tuple(np.linspace(0.0, 0.72, UPPER_ROWS - 1)) + (1.0,)     # atlas v of the rows: the dark starts at 0.72
MOUTH_ROWS, MOUTH_COLS = 2, 11
LIFT = 0.0065   # decals float this far off the true surface: the decimated head cuts corners


class FaceMesh:
    def __init__(self):
        self.base = []     # one (n, 3) block per piece
        self.keys = {}     # shape -> blocks in the same order
        self.uv = []
        self.tris = []
        self.count = 0

    def add(self, base, uv, tris, keys):
        tris = np.asarray(tris) + self.count
        self.tris.append(tris)
        self.base.append(base)
        self.uv.append(uv)
        for k, v in keys.items():
            self.keys.setdefault(k, {})[len(self.base) - 1] = v
        self.count += len(base)

    def done(self):
        base = np.concatenate(self.base)
        keys = {}
        for k, blocks in self.keys.items():
            arr = [blocks.get(i, self.base[i]) for i in range(len(self.base))]
            keys[k] = np.concatenate(arr)
        return base, np.concatenate(self.uv), np.concatenate(self.tris), keys


def grid_tris(rows, cols, flip=False):
    out = []
    for r in range(rows - 1):
        for c in range(cols - 1):
            a, b = r * cols + c, r * cols + c + 1
            d, e = (r + 1) * cols + c, (r + 1) * cols + c + 1
            out += [(a, b, e), (a, e, d)] if not flip else [(a, e, b), (a, d, e)]
    return out


def dome(c, fr, r, a, b, lift):
    z = np.sqrt(np.clip(1.0 - a * a - b * b, 0.0, 1.0))
    return c + (a[..., None] * r[0]) * fr[0] + (b[..., None] * r[1]) * fr[1] + (z[..., None] * r[2] + np.asarray(lift)[..., None]) * fr[2]


LID_LIFT = 0.008    # over a coarse dome: its chords, and the lid's, must not cross
LID_LIGHT = 1.13    # lids have no top light of their own: paint them lighter so they meet the head's colour
LASH = {True: 0.15, False: 0.07}   # dome units: the dark line along a lid's edge, the same width in every expression


def lid_points(c, fr, r, edge, upper, lift, rim_scale=1.10):
    """A patch from just past the rim of the dome to the edge curve; the last two rows are a fixed distance apart."""
    sign = 1.0 if upper else -1.0
    th = np.linspace(0.0, math.pi, COLS)
    ca, sb = np.cos(th), np.sin(th) * sign
    ea = ca
    eb = np.clip(np.array(edge(ea), dtype=float), -h(ea), h(ea))
    back = np.clip(eb + sign * LASH[upper], -h(ea) * rim_scale, h(ea) * rim_scale)
    pts = []
    for i in range(UPPER_ROWS):
        if i == UPPER_ROWS - 1:
            a, b = ea, eb
        elif i == UPPER_ROWS - 2:
            a, b = ea, back
        else:
            v = i / (UPPER_ROWS - 2)
            a = ca * rim_scale * (1 - v) + ea * v
            b = sb * rim_scale * (1 - v) + back * v
        rad = np.sqrt(a * a + b * b)
        k = np.minimum(1.0, 0.999 / np.maximum(rad, 1e-6))
        pts.append(dome(c, fr, r, a * k, b * k, lift + (rad > 1.0) * (rad - 1.0) * 0.02))
    return np.array(pts).reshape(-1, 3)


def build_face(shape, eye_c, eye_r, eye_frame):
    """Returns (verts, uvs, tris, keys) for lids, brows, mouth; and the eye domes as (verts, uvs, tris)."""
    fm = FaceMesh()
    for sx in (-1.0, 1.0):
        c = eye_c * np.array([sx, 1, 1])
        fr = eye_frame(sx)
        r = eye_r
        for upper in (True, False):
            base_edge = OPEN_U if upper else OPEN_L
            base = lid_points(c, fr, r, base_edge, upper, LID_LIFT)
            keys = {}
            for k, (eu, el) in LIDS.items():
                keys[k] = lid_points(c, fr, r, eu if upper else el, upper, LID_LIFT)
            u0, u1 = STRIP["upper" if upper else "lower"]
            uv = []
            for rr in LID_V:
                for cc in np.linspace(0, 1, COLS):
                    uv.append((u0 + (u1 - u0) * cc, rr))
            mirror = (sx < 0) != upper
            fm.add(base, np.array(uv), grid_tris(UPPER_ROWS, COLS, flip=mirror), keys)
        # brow: a little oval lying on the head above the eye
        fm_brow(fm, shape, sx, c, r)
    fm_mouth(fm, shape)
    return fm.done()


def fm_brow(fm, shape, sx, c, r):
    n = 7
    ctr = np.array([sx * FACE["brow_x"], c[1] + r[1] + FACE["brow_up"]])
    bk = FACE["brow_k"]

    def patch(dx, dy, tilt):
        th = np.linspace(0, 2 * math.pi, n, endpoint=False)
        ex = 0.031 * bk * np.cos(th)
        ey = 0.0135 * bk * np.sin(th)
        ca, sa = math.cos(tilt), math.sin(tilt)
        px = ex * ca + ey * sa
        py = -ex * sa + ey * ca
        # +x of the patch runs toward the nose
        xs = ctr[0] + sx * (dx - px)
        ys = ctr[1] + dy + py
        pts = np.stack([np.append(xs, ctr[0] + sx * dx), np.append(ys, ctr[1] + dy), np.full(n + 1, FACE["mouth_z"] + 0.06)], -1)
        return shape.project(pts, LIFT, steps=8)

    base = patch(*BROWS["rest"])
    keys = {k: patch(*v) for k, v in BROWS.items() if k != "rest"}
    u0, u1 = STRIP["brow"]
    uv = np.column_stack([np.full(n + 1, (u0 + u1) / 2), np.full(n + 1, 0.5)])
    tris = []
    for i in range(n):
        j = (i + 1) % n
        tris.append((n, i, j) if sx > 0 else (n, j, i))      # facing out, as the mouth does
    fm.add(base, uv, tris, keys)


def fm_mouth(fm, shape):
    mouths = mouth_shapes()
    z0 = FACE["mouth_z"]

    def patch(upper, lower, ws, lift=LIFT):
        xs = np.linspace(-1, 1, MOUTH_COLS) * FACE["mouth_w"] * ws
        pts = []
        for v in np.linspace(0, 1, MOUTH_ROWS):
            ys = lower(xs / ws) * (1 - v) + upper(xs / ws) * v
            pts.append(np.stack([xs, ys, np.full(MOUTH_COLS, z0)], -1))
        return shape.project(np.array(pts).reshape(-1, 3), lift, steps=10)

    upper, lower, ws = mouths["rest"]
    base = patch(upper, lower, ws)
    keys = {k: patch(*v) for k, v in mouths.items() if k != "rest"}
    u0, u1 = STRIP["mouth"]
    uv = []
    for rr in np.linspace(0, 1, MOUTH_ROWS):
        for cc in np.linspace(0, 1, MOUTH_COLS):
            uv.append((u0 + (u1 - u0) * cc, rr))
    fm.add(base, np.array(uv), grid_tris(MOUTH_ROWS, MOUTH_COLS, flip=True), keys)
    fm_fang(fm, shape, mouths)


def fm_fang(fm, shape, mouths):
    """Fangs hang from the upper lip: the right one always shows (its sly look), both when it snarls."""
    def tri(sx, upper, ws, length):
        x0 = sx * FACE["mouth_w"] * 0.5 * ws
        w = 0.011
        length *= FACE["fang_k"]
        y = float(upper(np.array([x0 / ws])))
        z = FACE["mouth_z"]
        pts = np.array([[x0 - w, y + 0.002, z], [x0 + w, y + 0.002, z], [x0 + 0.002 * sx, y - length, z]])
        return shape.project(pts, LIFT + 0.0008, steps=10)

    u0, u1 = STRIP["fang"]
    uv = np.array([[u0, 0.5], [u1, 0.5], [(u0 + u1) / 2, 0.5]])
    lengths = {"rest": (0.0, 0.021), "m_smile": (0.0, 0.021), "m_frown": (0.0, 0.0), "m_snarl": (0.028, 0.028),
               "m_chomp": (0.0, 0.018), "m_o": (0.0, 0.0)}
    for i, sx in enumerate((-1.0, 1.0)):
        upper, _, ws = mouths["rest"]
        base = tri(sx, upper, ws, max(lengths["rest"][i], 0.0004))
        keys = {}
        for k in mouths:
            if k == "rest":
                continue
            up, _, w = mouths[k]
            keys[k] = tri(sx, up, w, max(lengths[k][i], 0.0004))
        fm.add(base, uv, [(0, 1, 2)], keys)


def eye_dome(eye_c, eye_r, eye_frame):
    verts, uvs, tris = [], [], []
    rings, seg = 4, 13
    for sx in (-1.0, 1.0):
        c = eye_c * np.array([sx, 1, 1])
        fr = eye_frame(sx)
        start = len(verts)
        verts.append(dome(c, fr, eye_r, np.array(0.0), np.array(0.0), 0.0))
        uvs.append((0.5, 0.5))
        for ri in range(1, rings + 1):
            rad = 1.0 * ri / rings * 1.0
            for s in range(seg):
                th = s / seg * math.tau
                a, b = rad * math.cos(th) * 0.999, rad * math.sin(th) * 0.999
                verts.append(dome(c, fr, eye_r, np.array(a), np.array(b), 0.0))
                uvs.append((0.5 + 0.5 * a * sx, 0.5 + 0.5 * b))
        flip = sx < 0
        for s in range(seg):
            t = (start, start + 1 + s, start + 1 + (s + 1) % seg)
            tris.append(t if flip else (t[0], t[2], t[1]))
        for ri in range(rings - 1):
            r0 = start + 1 + ri * seg
            r1 = r0 + seg
            for s in range(seg):
                n = (s + 1) % seg
                q = [(r0 + s, r1 + s, r1 + n), (r0 + s, r1 + n, r0 + n)]
                for t in q:
                    tris.append(t if flip else (t[0], t[2], t[1]))
    return np.array(verts), np.array(uvs), np.array(tris)


def face_atlas(pal, px=256):
    """RGB (0..1, sRGB) of the strips: lids the skin's colour to a dark lash, pale brows, mouth, fangs."""
    INK, MOUTH_DARK, TONGUE = pal.INK, pal.MOUTH_DARK, pal.TONGUE
    img = np.zeros((px, px, 3))
    v = np.linspace(0, 1, px)[:, None]    # rows bottom to top of the strip

    def strip(name, col):
        u0, u1 = STRIP[name]
        i0, i1 = int(u0 * px) - 3, int(u1 * px) + 3
        img[:, i0:i1] = col
    skin = np.minimum(pal.LID * LID_LIGHT, 1.0)
    dark = np.clip((v - 0.72) / 0.1, 0, 1)
    up = skin * (1 - dark) + INK * dark
    lo = up
    strip("upper", up[:, None, :].repeat(1, 1))
    strip("lower", lo[:, None, :].repeat(1, 1))
    strip("brow", pal.LILAC)
    t = np.clip((0.42 - v) / 0.1, 0, 1)
    mouth = MOUTH_DARK * (1 - t) + TONGUE * t
    edge = np.clip((np.abs(v - 0.5) - 0.40) / 0.06, 0, 1)
    mouth = mouth * (1 - edge) + INK * edge
    strip("mouth", mouth[:, None, :])
    strip("fang", np.array([1.0, 0.98, 0.95]))
    return img
