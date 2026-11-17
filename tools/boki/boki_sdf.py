"""Signed-distance kit for the Boki creature models (run inside Blender's Python; numpy only).

A creature is a list of named primitives. Each primitive knows its distance, the bone it rides and a blend radius,
so one definition gives the mesh (surface nets), the skin weights (nearest primitives) and the paint (regions read
off the same fields). See docs/art/kin/RIGGED_BOKI.md.
"""
import numpy as np


def v3(*a):
    return np.array(a, dtype=np.float64)


def smin(a, b, k):
    """Polynomial smooth minimum: the seam between two shapes rounds off over about k metres."""
    if k <= 0:
        return np.minimum(a, b)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b + (a - b) * h - k * h * (1.0 - h)


def smax(a, b, k):
    return -smin(-a, -b, k)


def frame(fwd, up_hint):
    """An orthonormal basis (rows x, y, z) with z along fwd."""
    z = np.asarray(fwd, float)
    z = z / np.linalg.norm(z)
    x = np.cross(up_hint, z)
    x = x / np.linalg.norm(x)
    return np.stack([x, np.cross(z, x), z])


class Prim:
    def __init__(self, name, bone, k=0.02, sub=False):
        self.name, self.bone, self.k, self.sub = name, bone, k, sub
        self.lo, self.hi = None, None

    def d(self, p):
        raise NotImplementedError


class Ellipsoid(Prim):
    def __init__(self, name, bone, c, r, rot=None, k=0.02, sub=False):
        super().__init__(name, bone, k, sub)
        self.c, self.r = np.asarray(c, float), np.asarray(r, float)
        self.rot = np.eye(3) if rot is None else rot
        m = self.r.max() + 0.08
        self.lo, self.hi = self.c - m, self.c + m

    def d(self, p):
        q = (p - self.c) @ self.rot.T
        k0 = np.linalg.norm(q / self.r, axis=-1)
        k1 = np.linalg.norm(q / (self.r * self.r), axis=-1)
        return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


class Cone(Prim):
    """Round cone from a (radius ra) to b (radius rb), optionally flattened along `flat_axis` by `flat`."""

    def __init__(self, name, bone, a, b, ra, rb, k=0.02, flat=1.0, flat_axis=None, sub=False):
        super().__init__(name, bone, k, sub)
        self.a, self.b, self.ra, self.rb = np.asarray(a, float), np.asarray(b, float), ra, rb
        self.flat, self.axis = flat, None if flat_axis is None else np.asarray(flat_axis, float)
        m = max(ra, rb) + 0.08
        self.lo = np.minimum(self.a, self.b) - m
        self.hi = np.maximum(self.a, self.b) + m

    def d(self, p):
        q = p
        if self.flat != 1.0:
            n = self.axis / np.linalg.norm(self.axis)
            off = (q - self.a) @ n
            q = q + np.outer(off, n).reshape(q.shape) * (1.0 / self.flat - 1.0)
        ba = self.b - self.a
        pa = q - self.a
        l2 = ba @ ba
        rr = self.ra - self.rb
        a2 = l2 - rr * rr
        il2 = 1.0 / l2
        y = pa @ ba
        z = y - l2
        x2 = ((pa * l2 - y[..., None] * ba) ** 2).sum(-1)
        y2 = y * y * l2
        z2 = z * z * l2
        k = np.sign(rr) * rr * rr * x2
        s1 = np.sign(z) * a2 * z2 > k
        s2 = np.sign(y) * a2 * y2 < k
        mid = (np.sqrt(np.maximum(x2 * a2 * il2, 0)) + y * rr) * il2 - self.ra
        out = np.where(s1, np.sqrt(x2 + z2) * il2 - self.rb, np.where(s2, np.sqrt(x2 + y2) * il2 - self.ra, mid))
        return out * self.flat if self.flat < 1.0 else out


class Shape:
    """Primitives folded in order: additions smooth-union, `sub` primitives smooth-subtract."""

    def __init__(self, prims):
        self.prims = prims

    def bounds(self):
        lo = np.min([p.lo for p in self.prims if not p.sub], axis=0)
        hi = np.max([p.hi for p in self.prims if not p.sub], axis=0)
        return lo, hi

    def eval(self, p):
        out = None
        for pr in self.prims:
            d = pr.d(p)
            if out is None:
                out = d
            elif pr.sub:
                out = smax(out, -d, pr.k)
            else:
                out = smin(out, d, pr.k)
        return out

    def eval_grid(self, xs, ys, zs):
        """The field on a regular grid; each primitive is evaluated only inside its own box."""
        out = np.full((len(xs), len(ys), len(zs)), 1.0, dtype=np.float32)
        for pr in self.prims:
            ix = np.searchsorted(xs, [pr.lo[0], pr.hi[0]])
            iy = np.searchsorted(ys, [pr.lo[1], pr.hi[1]])
            iz = np.searchsorted(zs, [pr.lo[2], pr.hi[2]])
            sub = (slice(ix[0], ix[1]), slice(iy[0], iy[1]), slice(iz[0], iz[1]))
            gx, gy, gz = np.meshgrid(xs[sub[0]], ys[sub[1]], zs[sub[2]], indexing="ij")
            pts = np.stack([gx.ravel(), gy.ravel(), gz.ravel()], -1)
            d = pr.d(pts).reshape(gx.shape).astype(np.float32)
            if pr.sub:
                out[sub] = smax(out[sub], -d, pr.k)
            else:
                out[sub] = smin(out[sub], d, pr.k)
        return out

    def grad(self, p, e=0.0012):
        g = np.zeros_like(p)
        for i in range(3):
            dv = np.zeros(3)
            dv[i] = e
            g[..., i] = self.eval(p + dv) - self.eval(p - dv)
        n = np.linalg.norm(g, axis=-1, keepdims=True)
        return g / np.maximum(n, 1e-9)

    def project(self, p, offset=0.0, steps=6):
        """Walks points onto the surface (or `offset` outside it) along the gradient."""
        q = p.copy()
        for _ in range(steps):
            q = q - self.grad(q) * (self.eval(q) - offset)[..., None]
        return q


def surface_nets(field, xs, ys, zs):
    """Quads over a sign change: returns verts (n, 3) and quads (m, 4), outward facing for field < 0 inside."""
    inside = field < 0.0
    nx, ny, nz = field.shape
    corners = np.zeros((nx - 1, ny - 1, nz - 1), dtype=np.int8)
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                corners += inside[dx:nx - 1 + dx, dy:ny - 1 + dy, dz:nz - 1 + dz]
    active = (corners > 0) & (corners < 8)
    index = np.full(active.shape, -1, dtype=np.int64)
    ci = np.argwhere(active)
    index[active] = np.arange(len(ci))
    total = np.zeros((len(ci), 3))
    count = np.zeros(len(ci))
    h = np.array([xs[1] - xs[0], ys[1] - ys[0], zs[1] - zs[0]])
    org = np.array([xs[0], ys[0], zs[0]])
    edges = []
    for a in range(3):
        o = [c for c in range(3) if c != a]
        for s0 in (0, 1):
            for s1 in (0, 1):
                d0 = [0, 0, 0]
                d0[o[0]] = s0
                d0[o[1]] = s1
                edges.append((a, np.array(d0)))
    cell = ci.T
    for axis, d0 in edges:
        p0 = cell + d0[:, None]
        p1 = p0.copy()
        p1[axis] += 1
        f0 = field[tuple(p0)]
        f1 = field[tuple(p1)]
        hit = (f0 < 0) != (f1 < 0)
        t = f0[hit] / (f0[hit] - f1[hit])
        pos = p0[:, hit].T.astype(np.float64)
        pos[:, axis] += t
        np.add.at(total, np.nonzero(hit)[0], pos)
        np.add.at(count, np.nonzero(hit)[0], 1)
    verts = org + total / count[:, None] * h
    quads = []
    for axis in range(3):
        o = [c for c in range(3) if c != axis]
        s0 = [slice(None)] * 3
        s1 = [slice(None)] * 3
        s0[axis] = slice(0, -1)
        s1[axis] = slice(1, None)
        cross = inside[tuple(s0)] != inside[tuple(s1)]
        lim = [slice(None)] * 3
        lim[o[0]] = slice(1, -1)
        lim[o[1]] = slice(1, -1)
        mask = np.zeros_like(cross)
        mask[tuple(lim)] = cross[tuple(lim)]
        at = np.argwhere(mask)
        flip = inside[tuple(s0)][mask]
        for (d1, d2) in [(0, 0)]:
            a, b = at.copy(), at.copy()
            c, d = at.copy(), at.copy()
            a[:, o[0]] -= 1
            a[:, o[1]] -= 1
            b[:, o[1]] -= 1
            d[:, o[0]] -= 1
            q = np.stack([index[tuple(a.T)], index[tuple(b.T)], index[tuple(c.T)], index[tuple(d.T)]], -1)
        flipped = flip if axis == 1 else ~flip
        q[flipped] = q[flipped][:, ::-1]
        quads.append(q)
    return verts, np.concatenate(quads)


def mesh_shape(shape, h):
    lo, hi = shape.bounds()
    lo, hi = lo + 0.05, hi - 0.05
    xs = np.arange(lo[0], hi[0] + h, h)
    ys = np.arange(lo[1], hi[1] + h, h)
    zs = np.arange(lo[2], hi[2] + h, h)
    field = shape.eval_grid(xs, ys, zs)
    verts, quads = surface_nets(field, xs, ys, zs)
    return shape.project(verts, steps=3), quads


def value_noise(p, seed=7):
    """Smooth 3D value noise in 0..1."""
    i = np.floor(p).astype(np.int64)
    f = p - i
    f = f * f * (3 - 2 * f)

    def hashv(ix, iy, iz):
        h = (ix * 374761393 + iy * 668265263 + iz * 2147483647 + seed * 1274126177) & 0xFFFFFFFF
        h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
        return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0

    x, y, z = i[..., 0], i[..., 1], i[..., 2]
    fx, fy, fz = f[..., 0], f[..., 1], f[..., 2]
    c = [[[hashv(x + a, y + b, z + c_) for c_ in (0, 1)] for b in (0, 1)] for a in (0, 1)]
    lz = [[c[a][b][0] * (1 - fz) + c[a][b][1] * fz for b in (0, 1)] for a in (0, 1)]
    ly = [lz[a][0] * (1 - fy) + lz[a][1] * fy for a in (0, 1)]
    return ly[0] * (1 - fx) + ly[1] * fx
