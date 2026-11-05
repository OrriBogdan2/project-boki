"""ART-1 shared mesh helpers (Blender python): pieces are plain data, joined and skinned at the end.

A Piece holds numpy verts (Blender frame: Z up, the hunter faces +Y, his right hand is +X), faces (lists of indices),
one material name per piece, a uv per loop (per-face list) and bone weights as {bone: array of per-vertex weights}.
"""
import numpy as np


class Piece:
    def __init__(self, name, mat, verts, faces, uvs=None, weights=None, room=1.0):
        self.name, self.mat = name, mat
        self.v = np.asarray(verts, dtype=np.float64)
        self.f = [list(q) for q in faces]
        self.uv = uvs                  # per-face list of per-corner (u, v), or None: unwrap later
        self.w = weights or {}
        self.room = room               # the ink shell's room here (0..1 of 2 cm, RIG_CONTRACT ink_room)

    def rigid(self, bone):
        self.w = {bone: np.ones(len(self.v))}
        return self

    def orient(self, ref=None):
        """Winds each connected part outward: from `ref` for an open sheet (a point inside the shape it lies on), from its
        own centre for a closed part. Corner UVs turn with the faces."""
        n = len(self.v)
        par = list(range(n))

        def find(a):
            while par[a] != a:
                par[a] = par[par[a]]
                a = par[a]
            return a
        for q in self.f:
            r = find(q[0])
            for x in q[1:]:
                par[find(x)] = r
        comp = {}
        for i, q in enumerate(self.f):
            comp.setdefault(find(q[0]), []).append(i)
        for ids in comp.values():
            pts = self.v[sorted({x for i in ids for x in self.f[i]})]
            c = pts.mean(0) if ref is None else np.asarray(ref, dtype=np.float64)
            vol = 0.0
            for i in ids:
                q = self.f[i]
                a = self.v[q[0]] - c
                for k in range(1, len(q) - 1):
                    vol += np.dot(a, np.cross(self.v[q[k]] - c, self.v[q[k + 1]] - c))
            if vol < 0:
                for i in ids:
                    self.f[i] = self.f[i][::-1]
                    if self.uv is not None:
                        self.uv[i] = self.uv[i][::-1]
        return self

    def tris(self):
        return sum(len(q) - 2 for q in self.f)


def norm(a, axis=-1):
    a = np.asarray(a, dtype=np.float64)
    n = np.linalg.norm(a, axis=axis, keepdims=True)
    return a / np.maximum(n, 1e-9)


def smooth(a, b, x):
    t = np.clip((np.asarray(x, dtype=np.float64) - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def catmull(pts, n):
    """n points along a Catmull-Rom spline through pts."""
    p = np.asarray(pts, dtype=np.float64)
    q = np.vstack([2 * p[0] - p[1], p, 2 * p[-1] - p[-2]])
    out = []
    segs = len(p) - 1
    for i in range(n):
        s = i / (n - 1) * segs
        k = min(int(s), segs - 1)
        t = s - k
        a, b, c, d = q[k], q[k + 1], q[k + 2], q[k + 3]
        out.append(0.5 * (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (3 * b - a - 3 * c + d) * t ** 3))
    return np.array(out)


def frames(path, up_hint=(0, 0, 1)):
    """A parallel-transport frame (tangent, side, normal) along a path."""
    p = np.asarray(path)
    t = norm(np.gradient(p, axis=0))
    side = np.cross(t[0], up_hint)
    if np.linalg.norm(side) < 1e-4:
        side = np.cross(t[0], (1, 0, 0))
    side = norm(side)
    sides = [side]
    for i in range(1, len(p)):
        s = sides[-1] - t[i] * np.dot(sides[-1], t[i])
        sides.append(norm(s))
    s = np.array(sides)
    return t, s, norm(np.cross(s, t))


def sweep(name, mat, path, section, width, side_hint=None, uv_rect=(0, 0, 1, 1), closed=True, tip=True, room=1.0,
          twist=None, depth=None):
    """A tube along `path`. `section`: [(a, b), ...] in the (side, normal) plane, unit size; width: one value per ring
    (scales `a`); depth likewise (scales `b`; default width). A `tip` closes the end in a point. UV: u round the
    section, v along the path, inside uv_rect."""
    path = np.asarray(path, dtype=np.float64)
    n = len(path)
    t, s, nn = frames(path, side_hint if side_hint is not None else (0, 0, 1))
    depth = width if depth is None else depth
    m = len(section)
    verts = []
    for i in range(n):
        tw = 0.0 if twist is None else twist[i]
        c, si = np.cos(tw), np.sin(tw)
        for a, b in section:
            aa, bb = a * c - b * si, a * si + b * c
            verts.append(path[i] + s[i] * aa * width[i] + nn[i] * bb * depth[i])
    faces, uvs = [], []
    u0, v0, u1, v1 = uv_rect
    cols = m if closed else m - 1
    for i in range(n - 1):
        for j in range(cols):
            a = i * m + j
            b = i * m + (j + 1) % m
            c = (i + 1) * m + (j + 1) % m
            d = (i + 1) * m + j
            faces.append([a, b, c, d])
            ua, ub = u0 + (u1 - u0) * j / cols, u0 + (u1 - u0) * (j + 1) / cols
            va, vb = v0 + (v1 - v0) * i / (n - 1), v0 + (v1 - v0) * (i + 1) / (n - 1)
            uvs.append([(ua, va), (ub, va), (ub, vb), (ua, vb)])
    return Piece(name, mat, verts, faces, uvs, room=room)


def holed_sheet(name, mat, G, wrap=False, holes=(), room=1.0):
    """A sheet from a (rows, cols, 3) grid of points, with real holes cut: holes = [(row, col, radius in cells, seed)]. Each hole's cells are
    re-triangulated round an irregular ring (a constrained Delaunay in grid space). -> Piece with .rowf (0..1 per vertex)."""
    from mathutils.geometry import delaunay_2d_cdt
    from mathutils import Vector
    G = np.asarray(G, dtype=np.float64)
    R, C_ = G.shape[:2]

    def at(r, c):
        r0 = int(np.clip(np.floor(r), 0, R - 2))
        q = r - r0
        c0 = int(np.floor(c))
        p = c - c0
        a, b = c0 % C_, (c0 + 1) % C_
        if not wrap:
            a, b = min(c0, C_ - 2), min(c0, C_ - 2) + 1
            p = c - a
        return (G[r0, a] * (1 - p) + G[r0, b] * p) * (1 - q) + (G[r0 + 1, a] * (1 - p) + G[r0 + 1, b] * p) * q

    verts, rowf, index, faces = [], [], {}, []

    def vid(r, c):
        k = (round(r, 4), round(c % C_ if wrap else c, 4))
        if k not in index:
            index[k] = len(verts)
            verts.append(at(r, c))
            rowf.append(r / (R - 1))
        return index[k]
    taken = set()
    for hr, hc, rad, seed in holes:
        r0, r1 = int(np.floor(hr - rad - 0.5)), int(np.ceil(hr + rad + 0.5))
        c0, c1 = int(np.floor(hc - rad - 0.5)), int(np.ceil(hc + rad + 0.5))
        r0, r1 = max(r0, 0), min(r1, R - 1)
        if not wrap:
            c0, c1 = max(c0, 0), min(c1, C_ - 1)
        for r in range(r0, r1):
            for c in range(c0, c1):
                taken.add((r, c % C_))
        outer = [(float(c), float(r0)) for c in range(c0, c1)] + [(float(c1), float(r)) for r in range(r0, r1)] + \
            [(float(c), float(r1)) for c in range(c1, c0, -1)] + [(float(c0), float(r)) for r in range(r1, r0, -1)]
        rng = np.random.RandomState(seed)
        ring = []
        for k in range(9):
            a = k / 9 * 2 * np.pi
            q = rad * rng.uniform(0.55, 1.1)
            ring.append((hc + np.cos(a) * q, hr + np.sin(a) * q * 0.8))
        co = [Vector(p) for p in outer + ring]
        loops = [list(range(len(outer))), list(range(len(outer), len(outer) + len(ring)))]
        out = delaunay_2d_cdt(co, [], loops, 2, 1e-5)
        for f in out[2]:
            q = [out[0][i] for i in f]
            faces.append([vid(p.y, p.x) for p in q])
    for r in range(R - 1):
        for c in range(C_ - (0 if wrap else 1)):
            if (r, c) in taken:
                continue
            faces.append([vid(r, c), vid(r, c + 1), vid(r + 1, c + 1), vid(r + 1, c)])
    p = Piece(name, mat, verts, faces, room=room)
    p.rowf = np.array(rowf)
    p.at = at
    return p


def rot_about(v, axis, ang):
    """Rodrigues: rotates vectors v about a unit axis."""
    v = np.asarray(v, dtype=np.float64)
    axis = np.asarray(axis, dtype=np.float64) / np.linalg.norm(axis)
    c, s = np.cos(ang), np.sin(ang)
    return v * c + np.cross(axis, v) * s + np.outer(np.dot(v, axis), axis) * (1 - c) if v.ndim == 2 else \
        v * c + np.cross(axis, v) * s + axis * np.dot(v, axis) * (1 - c)


# ---- signed distance helpers (head sculpt)
def sd_ell(p, c, r):
    q = (p - np.asarray(c)) / np.asarray(r)
    k = np.linalg.norm(q, axis=-1)
    return (k - 1.0) * np.min(r)


def sd_cap(p, a, b, r):
    a, b = np.asarray(a, dtype=np.float64), np.asarray(b, dtype=np.float64)
    pa, ba = p - a, b - a
    h = np.clip(np.sum(pa * ba, axis=-1) / np.dot(ba, ba), 0, 1)
    return np.linalg.norm(pa - ba * h[..., None], axis=-1) - r


def smin(a, b, k):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    return b * (1 - h) + a * h - k * h * (1 - h)


def smax(a, b, k):
    return -smin(-a, -b, k)
