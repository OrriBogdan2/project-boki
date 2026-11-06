"""A scripted sculpt for the ART-1 Hunters, in Blender's Python (numpy): signed distance fields on a voxel grid,
smooth unions and carves, surface nets, a decimated game mesh, and a per-texel atlas painter that samples the
sculpt (so the high detail survives in the paint). Nothing here is Hunter specific; tools/art1/<hero>_art1.py
holds the shapes.

Space: Blender's, the Hunter facing +Y, its right +X, up +Z, metres at the class-neutral size (RIG_CONTRACT)."""
import math

import numpy as np

F = np.float32


# ------------------------------------------------------------------ primitives: fn(x, y, z) -> distance, plus a box
class Prim:
    def __init__(self, fn, lo, hi):
        self.fn, self.lo, self.hi = fn, np.array(lo, F), np.array(hi, F)


def _rotm(rot):
    """A rotation given as Euler XYZ (radians) or a 3x3 matrix."""
    if rot is None:
        return None
    r = np.array(rot, F)
    if r.shape == (3, 3):
        return r
    cx, sx, cy, sy, cz, sz = math.cos(r[0]), math.sin(r[0]), math.cos(r[1]), math.sin(r[1]), math.cos(r[2]), math.sin(r[2])
    rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]], F)
    ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]], F)
    rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]], F)
    return rz @ ry @ rx


def _local(x, y, z, c, m):
    px, py, pz = x - c[0], y - c[1], z - c[2]
    if m is None:
        return px, py, pz
    # (world -> local: the transpose of the rotation)
    return (m[0, 0] * px + m[1, 0] * py + m[2, 0] * pz, m[0, 1] * px + m[1, 1] * py + m[2, 1] * pz,
            m[0, 2] * px + m[1, 2] * py + m[2, 2] * pz)


def ell(c, r, rot=None):
    c, r = np.array(c, F), np.array(r, F)
    m = _rotm(rot)

    def fn(x, y, z):
        px, py, pz = _local(x, y, z, c, m)
        k0 = np.sqrt((px / r[0]) ** 2 + (py / r[1]) ** 2 + (pz / r[2]) ** 2)
        k1 = np.sqrt((px / r[0] ** 2) ** 2 + (py / r[1] ** 2) ** 2 + (pz / r[2] ** 2) ** 2)
        return k0 * (k0 - 1.0) / np.maximum(k1, 1e-5)
    e = float(r.max())
    return Prim(fn, c - e, c + e)


def sph(c, r):
    return ell(c, (r, r, r))


def cap(a, b, ra, rb=None):
    """A round cone from a to b."""
    a, b = np.array(a, F), np.array(b, F)
    rb = ra if rb is None else rb
    ab = b - a
    l2 = float(ab @ ab) or 1e-9

    def fn(x, y, z):
        px, py, pz = x - a[0], y - a[1], z - a[2]
        t = np.clip((px * ab[0] + py * ab[1] + pz * ab[2]) / l2, 0.0, 1.0)
        dx, dy, dz = px - ab[0] * t, py - ab[1] * t, pz - ab[2] * t
        return np.sqrt(dx * dx + dy * dy + dz * dz) - (ra + (rb - ra) * t)
    e = max(ra, rb)
    return Prim(fn, np.minimum(a, b) - e, np.maximum(a, b) + e)


def path(pts, radii):
    """A chain of round cones through pts (one sdf, hard union: a tube, a rope, a finger)."""
    ps = [cap(pts[i], pts[i + 1], radii[i], radii[i + 1]) for i in range(len(pts) - 1)]

    def fn(x, y, z):
        d = ps[0].fn(x, y, z)
        for p in ps[1:]:
            d = np.minimum(d, p.fn(x, y, z))
        return d
    return Prim(fn, np.min([p.lo for p in ps], 0), np.max([p.hi for p in ps], 0))


def box(c, h, r=0.0, rot=None):
    c, h = np.array(c, F), np.array(h, F)
    m = _rotm(rot)
    ih = h - r

    def fn(x, y, z):
        px, py, pz = _local(x, y, z, c, m)
        qx, qy, qz = np.abs(px) - ih[0], np.abs(py) - ih[1], np.abs(pz) - ih[2]
        o = np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2 + np.maximum(qz, 0) ** 2)
        return o + np.minimum(np.maximum(qx, np.maximum(qy, qz)), 0.0) - r
    e = float(np.sqrt(h @ h))
    return Prim(fn, c - e, c + e)


def cyl(c, axis, rad, half, r=0.003):
    """A rounded disc or drum about an axis ('x', 'y', 'z' or a rotation)."""
    c = np.array(c, F)
    m = _rotm(axis) if not isinstance(axis, str) else None
    ia = "xyz".index(axis) if isinstance(axis, str) else 2

    def fn(x, y, z):
        lp = _local(x, y, z, c, m)
        a = lp[ia]
        b, d = [lp[i] for i in range(3) if i != ia]
        qr = np.sqrt(b * b + d * d) - (rad - r)
        qa = np.abs(a) - (half - r)
        return np.sqrt(np.maximum(qr, 0) ** 2 + np.maximum(qa, 0) ** 2) + np.minimum(np.maximum(qr, qa), 0.0) - r
    e = math.sqrt(rad * rad + half * half) + r
    return Prim(fn, c - e, c + e)


def icicle(a, b, r):
    """A cone from a to a sharp point at b, a touch bulged."""
    a2 = np.array(a, F)
    b2 = np.array(b, F)
    return path([a2, a2 * 0.65 + b2 * 0.35, b2], [r, r * 0.55, 0.0008])


# ------------------------------------------------------------------ noise
_rng = np.random.default_rng(7)
_LAT = _rng.random((64, 64, 64), dtype=F)
_JIT = _rng.random((32, 32, 32, 3), dtype=F)


def vnoise(x, y, z, f=1.0):
    """Smooth value noise in 0..1."""
    x, y, z = np.asarray(x, F) * f, np.asarray(y, F) * f, np.asarray(z, F) * f
    xi, yi, zi = np.floor(x).astype(np.int32), np.floor(y).astype(np.int32), np.floor(z).astype(np.int32)
    u, v, w = x - xi, y - yi, z - zi
    u, v, w = u * u * (3 - 2 * u), v * v * (3 - 2 * v), w * w * (3 - 2 * w)
    a = xi & 63
    b = yi & 63
    c = zi & 63
    a1, b1, c1 = (a + 1) & 63, (b + 1) & 63, (c + 1) & 63
    L = _LAT
    return ((L[a, b, c] * (1 - u) + L[a1, b, c] * u) * (1 - v) + (L[a, b1, c] * (1 - u) + L[a1, b1, c] * u) * v) * (1 - w) \
        + ((L[a, b, c1] * (1 - u) + L[a1, b, c1] * u) * (1 - v) + (L[a, b1, c1] * (1 - u) + L[a1, b1, c1] * u) * v) * w


def fbm(x, y, z, f=1.0, oct=4, gain=0.5):
    s, a, n = 0.0, 1.0, 0.0
    for i in range(oct):
        s = s + a * vnoise(x + i * 3.7, y - i * 1.3, z + i * 2.1, f)
        n += a
        a *= gain
        f *= 2.03
    return s / n


def worley(x, y, z, f=1.0):
    """(F1, F2 - F1): the distance to the nearest cell point and the crack width term, for frost cracks and plates."""
    x, y, z = np.asarray(x, F) * f, np.asarray(y, F) * f, np.asarray(z, F) * f
    xi, yi, zi = np.floor(x).astype(np.int32), np.floor(y).astype(np.int32), np.floor(z).astype(np.int32)
    d1 = np.full(x.shape, 9.0, F)
    d2 = np.full(x.shape, 9.0, F)
    for i in (-1, 0, 1):
        for j in (-1, 0, 1):
            for k in (-1, 0, 1):
                a, b, c = xi + i, yi + j, zi + k
                J = _JIT[a & 31, b & 31, c & 31]
                dd = (a + J[..., 0] - x) ** 2 + (b + J[..., 1] - y) ** 2 + (c + J[..., 2] - z) ** 2
                new2 = np.where(dd < d1, d1, np.minimum(d2, dd))
                d1 = np.minimum(d1, dd)
                d2 = new2
    d1, d2 = np.sqrt(d1), np.sqrt(d2)
    return d1, d2 - d1


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


# ------------------------------------------------------------------ the voxel field
class Field:
    """A signed distance grid (negative inside) with a label per voxel (which prim's material won)."""

    def __init__(self, lo, hi, vox):
        self.lo = np.array(lo, F)
        self.vox = float(vox)
        self.n = (np.ceil((np.array(hi, F) - self.lo) / vox).astype(int) + 1)
        self.d = np.full(tuple(self.n), 1.0, F)
        self.lab = np.zeros(tuple(self.n), np.uint8)
        self.prims = []        # (prim, bone, group) for the skin weights
        self.grp = 0           # this field's group (0 the trunk; merge() keeps which won per voxel)
        self.gmap = None

    def like(self, vox=None):
        """An empty field on the same grid."""
        o = Field.__new__(Field)
        o.lo, o.vox, o.n = self.lo.copy(), self.vox, self.n.copy()
        o.d = np.full(tuple(o.n), 1.0, F)
        o.lab = np.zeros(tuple(o.n), np.uint8)
        o.prims, o.grp, o.gmap = [], 0, None
        return o

    def _win(self, p, m):
        a = np.maximum(np.floor((p.lo - m - self.lo) / self.vox).astype(int), 0)
        b = np.minimum(np.ceil((p.hi + m - self.lo) / self.vox).astype(int) + 1, self.n)
        if np.any(b <= a):
            return None
        s = tuple(slice(int(a[i]), int(b[i])) for i in range(3))
        ax = [self.lo[i] + np.arange(a[i], b[i], dtype=F) * self.vox for i in range(3)]
        x = ax[0][:, None, None]
        y = ax[1][None, :, None]
        z = ax[2][None, None, :]
        return s, x, y, z

    def add(self, p, k=0.02, lab=None, bone=None, disp=None):
        """Smooth union (k: the blend, m). disp(x, y, z) -> a displacement in metres."""
        w = self._win(p, k + 0.03)
        if w is None:
            return self
        s, x, y, z = w
        b = np.broadcast_to(p.fn(x, y, z), self.d[s].shape).astype(F)
        if disp is not None:
            b = b - disp(x, y, z)
        a = self.d[s]
        if k > 0:
            h = np.clip(0.5 + 0.5 * (a - b) / k, 0, 1)
            out = a * (1 - h) + b * h - k * h * (1 - h)
        else:
            out = np.minimum(a, b)
        if lab is not None:
            self.lab[s] = np.where(b < a, lab, self.lab[s])
        self.d[s] = out
        if bone:
            self.prims.append((p, bone, self.grp))
        return self

    def sub(self, p, k=0.01, lab=None):
        """Smooth carve; lab paints the carved walls."""
        w = self._win(p, k + 0.03)
        if w is None:
            return self
        s, x, y, z = w
        b = -np.broadcast_to(p.fn(x, y, z), self.d[s].shape).astype(F)
        a = self.d[s]
        h = np.clip(0.5 - 0.5 * (a - b) / max(k, 1e-5), 0, 1) if k > 0 else None
        if k > 0:
            h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
            out = a * (1 - h) + b * h + k * h * (1 - h)
        else:
            out = np.maximum(a, b)
        if lab is not None:
            self.lab[s] = np.where(b > a - 0.004, lab, self.lab[s])
        self.d[s] = out
        return self

    def merge(self, o, k=0.0, kfn=None, bone_keep=True):
        """Union another field on the same grid: k, or kfn(x, y, z) the blend per voxel (0: a hard min)."""
        a, b = self.d, o.d
        if kfn is not None:
            x, y, z = self.grid()
            kk = np.maximum(kfn(x, y, z), 1e-4).astype(F)
        else:
            kk = max(k, 1e-4)
        h = np.clip(0.5 + 0.5 * (a - b) / kk, 0, 1)
        self.d = a * (1 - h) + b * h - kk * h * (1 - h)
        self.lab = np.where(b < a, o.lab, self.lab)
        if self.gmap is None:
            self.gmap = np.zeros(a.shape, np.uint8)
        self.gmap = np.where(b < a, np.uint8(o.grp), self.gmap)
        self.prims += [(p, bn, o.grp) for p, bn, _ in o.prims]
        return self

    def grid(self):
        return (self.lo[0] + np.arange(self.n[0], dtype=F)[:, None, None] * self.vox,
                self.lo[1] + np.arange(self.n[1], dtype=F)[None, :, None] * self.vox,
                self.lo[2] + np.arange(self.n[2], dtype=F)[None, None, :] * self.vox)

    def sample(self, pts):
        """Trilinear distance at points (N, 3)."""
        return _tri(self.d, (pts - self.lo) / self.vox)

    def label(self, pts):
        q = np.clip(np.rint((pts - self.lo) / self.vox).astype(int), 0, self.n - 1)
        return self.lab[q[:, 0], q[:, 1], q[:, 2]]

    def grad(self, pts, e=None):
        e = e or self.vox
        g = np.empty(pts.shape, F)
        for i in range(3):
            o = np.zeros(3, F)
            o[i] = e
            g[:, i] = self.sample(pts + o) - self.sample(pts - o)
        return g / np.maximum(np.linalg.norm(g, axis=1, keepdims=True), 1e-6)

    def project(self, pts, it=3):
        """Moves points onto the surface along the gradient."""
        p = pts.astype(F).copy()
        for _ in range(it):
            d = self.sample(p)[:, None]
            p -= self.grad(p) * np.clip(d, -0.03, 0.03)
        return p

    def group(self, pts):
        q = np.clip(np.rint((pts - self.lo) / self.vox).astype(int), 0, self.n - 1)
        return self.gmap[q[:, 0], q[:, 1], q[:, 2]] if self.gmap is not None else np.zeros(len(pts), np.uint8)

    def weights(self, pts, sigma=0.03, allow=None):
        """{bone: weight (N)} from each tagged prim's distance: the closest forms' bones win, softly.
        allow(prim_group, bone, point_groups, pts) -> a 0/1 mask keeps a limb's verts off the belly beside it."""
        out = {}
        g = self.group(pts)
        for p, bone, pg in self.prims:
            d = p.fn(pts[:, 0], pts[:, 1], pts[:, 2])
            w = np.exp(-np.maximum(d, 0) / sigma)
            if allow is not None:
                w = w * allow(pg, bone, g, pts)
            out[bone] = np.maximum(out.get(bone, 0), w)
        return out


def _tri(d, q):
    n = np.array(d.shape)
    q = np.clip(q, 0, n - 1.001)
    i = q.astype(int)
    f = (q - i).astype(F)
    x, y, z = i[:, 0], i[:, 1], i[:, 2]
    u, v, w = f[:, 0], f[:, 1], f[:, 2]
    c00 = d[x, y, z] * (1 - u) + d[x + 1, y, z] * u
    c10 = d[x, y + 1, z] * (1 - u) + d[x + 1, y + 1, z] * u
    c01 = d[x, y, z + 1] * (1 - u) + d[x + 1, y, z + 1] * u
    c11 = d[x, y + 1, z + 1] * (1 - u) + d[x + 1, y + 1, z + 1] * u
    return (c00 * (1 - v) + c10 * v) * (1 - w) + (c01 * (1 - v) + c11 * v) * w


def blurred(d, r):
    """A low-pass of a distance grid: three box passes of radius r voxels (the game mesh is cut from this, the paint keeps the
    detail: a decimate left to the detail spends its budget there and collapses the big forms)."""
    if r < 1:
        return d
    out = d
    w = 2 * r + 1
    for _ in range(2):
        for ax in range(3):
            pad = [(0, 0)] * 3
            pad[ax] = (r + 1, r)
            c = np.cumsum(np.pad(out, pad, mode="edge"), axis=ax, dtype=np.float64)
            hi = [slice(None)] * 3
            lo = [slice(None)] * 3
            hi[ax] = slice(w, None)
            lo[ax] = slice(0, -w)
            out = ((c[tuple(hi)] - c[tuple(lo)]) / w).astype(F)
    return out


def surface_nets(fld):
    """The iso surface of a Field as a quad mesh: (verts (N, 3) in metres, quads (M, 4))."""
    d = fld.d
    inside = d < 0
    nx, ny, nz = d.shape
    cell = lambda i, j, k: (i * (ny - 1) + j) * (nz - 1) + k
    ids, ps = [], []
    cross = []
    for ax in range(3):
        sl0 = [slice(None)] * 3
        sl1 = [slice(None)] * 3
        sl0[ax] = slice(0, -1)
        sl1[ax] = slice(1, None)
        s0, s1 = tuple(sl0), tuple(sl1)
        e = inside[s0] != inside[s1]
        i, j, k = np.nonzero(e)
        d0, d1 = d[s0][e], d[s1][e]
        t = d0 / (d0 - d1)
        p = np.stack([i, j, k], 1).astype(F)
        p[:, ax] += t
        cross.append((i, j, k, inside[s0][e]))
        for da, db in ((0, 0), (0, 1), (1, 0), (1, 1)):
            c = [i.copy(), j.copy(), k.copy()]
            o = [a for a in range(3) if a != ax]
            c[o[0]] -= da
            c[o[1]] -= db
            ok = (c[0] >= 0) & (c[1] >= 0) & (c[2] >= 0) & (c[0] < nx - 1) & (c[1] < ny - 1) & (c[2] < nz - 1)
            ids.append(cell(c[0][ok], c[1][ok], c[2][ok]))
            ps.append(p[ok])
    ids = np.concatenate(ids)
    ps = np.concatenate(ps)
    uq, inv = np.unique(ids, return_inverse=True)
    v = np.zeros((len(uq), 3), np.float64)
    np.add.at(v, inv, ps)
    v /= np.bincount(inv, minlength=len(uq))[:, None]
    quads = []
    for ax in range(3):
        i, j, k, sign = cross[ax]
        o = [a for a in range(3) if a != ax]
        c = np.stack([i, j, k], 1)
        ok = (c[:, o[0]] > 0) & (c[:, o[1]] > 0) & (c[:, ax] < d.shape[ax] - 1) \
            & (c[:, o[0]] < d.shape[o[0]] - 1) & (c[:, o[1]] < d.shape[o[1]] - 1)
        c = c[ok]
        sg = sign[ok]
        corners = []
        for da, db in ((1, 1), (0, 1), (0, 0), (1, 0)):
            q = c.copy()
            q[:, o[0]] -= da
            q[:, o[1]] -= db
            corners.append(np.searchsorted(uq, cell(q[:, 0], q[:, 1], q[:, 2])))
        qd = np.stack(corners, 1)
        flip = sg if ax != 1 else ~sg
        qd[flip] = qd[flip][:, ::-1]
        quads.append(qd)
    quads = np.concatenate(quads)
    return (fld.lo + v * fld.vox).astype(F), quads


# ------------------------------------------------------------------ the atlas: rasterise UV triangles into maps
def raster(uv, pos, nrm, tris, size, part=None, out=None):
    """Writes position, normal and a part id per texel for triangles (uv (T, 3, 2), pos (T, 3, 3), nrm (T, 3, 3))."""
    if out is None:
        out = {"p": np.zeros((size, size, 3), F), "n": np.zeros((size, size, 3), F),
               "id": np.full((size, size), -1, np.int16)}
    P, N, ID = out["p"], out["n"], out["id"]
    uvp = uv * size - 0.5
    for t in range(len(uvp)):
        a, b, c = uvp[t]
        lo = np.floor(np.minimum(np.minimum(a, b), c) - 1).astype(int)
        hi = np.ceil(np.maximum(np.maximum(a, b), c) + 1).astype(int)
        x0, y0 = max(lo[0], 0), max(lo[1], 0)
        x1, y1 = min(hi[0], size - 1), min(hi[1], size - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs = np.arange(x0, x1 + 1, dtype=F)
        ys = np.arange(y0, y1 + 1, dtype=F)
        gx, gy = np.meshgrid(xs, ys)
        den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(den) < 1e-9:
            continue
        w0 = ((b[1] - c[1]) * (gx - c[0]) + (c[0] - b[0]) * (gy - c[1])) / den
        w1 = ((c[1] - a[1]) * (gx - c[0]) + (a[0] - c[0]) * (gy - c[1])) / den
        w2 = 1 - w0 - w1
        m = (w0 >= -0.02) & (w1 >= -0.02) & (w2 >= -0.02)
        if not m.any():
            continue
        iy = gy[m].astype(int)
        ix = gx[m].astype(int)
        W = np.stack([w0[m], w1[m], w2[m]], 1)
        P[iy, ix] = W @ pos[t]
        N[iy, ix] = W @ nrm[t]
        ID[iy, ix] = part if part is not None else t
    return out


def dilate(img, mask, it=6):
    """Bleeds painted texels into the gutters so mips and the bilinear filter never reach black."""
    img = img.copy()
    m = mask.copy()
    for _ in range(it):
        s = np.zeros(img.shape, F)
        c = np.zeros(m.shape, F)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            mm = np.roll(np.roll(m, dx, 1), dy, 0)
            s += np.roll(np.roll(img * m[..., None], dx, 1), dy, 0)
            c += mm
        grow = (~m) & (c > 0)
        img[grow] = s[grow] / c[grow][:, None]
        m = m | grow
    return img
