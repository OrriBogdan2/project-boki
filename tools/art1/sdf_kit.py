"""A small scripted sculpting kit (ART-1): a part of a Hunter is a signed distance field in numpy, its surface comes out
as a mesh by surface nets, Blender decimates that to the tri budget, and the part's paint function is evaluated on the
true field at every texel of the atlas (normal, cavity and occlusion come from the field itself, so sculpted detail
far finer than the low mesh still lands in the paint). Needs numpy only; bpy where a function says so.

Blender frame: the Hunter faces +Y, Z up, its right hand at +X (tools/blender/warden_kit.py g2b).
"""
import numpy as np


# ---------------------------------------------------------------------------------------------- distance primitives
def vec(*a):
    return np.array(a, dtype=np.float32)


def length(v):
    return np.sqrt((v * v).sum(-1))


def sphere(P, c, r):
    return length(P - np.asarray(c, np.float32)) - r


def ellipsoid(P, c, r, rot=None):
    """A close approximation of the distance to an ellipsoid (radii r, optional 3x3 rot: world = rot @ local)."""
    q = P - np.asarray(c, np.float32)
    if rot is not None:
        q = q @ np.asarray(rot, np.float32)
    r = np.asarray(r, np.float32)
    k0 = length(q / r)
    k1 = length(q / (r * r))
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-6)


def box(P, c, b, rot=None, round_=0.0):
    q = P - np.asarray(c, np.float32)
    if rot is not None:
        q = q @ np.asarray(rot, np.float32)
    d = np.abs(q) - (np.asarray(b, np.float32) - round_)
    return length(np.maximum(d, 0.0)) + np.minimum(d.max(-1), 0.0) - round_


def capsule(P, a, b, r):
    return cone(P, a, b, r, r)


def cone(P, a, b, ra, rb):
    """A capsule whose radius runs from ra at a to rb at b (linear in the segment's parameter; a good bound)."""
    a = np.asarray(a, np.float32)
    ba = np.asarray(b, np.float32) - a
    pa = P - a
    t = np.clip((pa * ba).sum(-1) / max(float((ba * ba).sum()), 1e-9), 0.0, 1.0)
    return length(pa - t[..., None] * ba) - (ra + (rb - ra) * t)


def polyline(P, pts, radii, k=0.0):
    """A chain of cones through pts (a strap, a lip, a loc); k > 0 blends the links smoothly."""
    d = None
    r = radii if hasattr(radii, "__len__") else [radii] * len(pts)
    for i in range(len(pts) - 1):
        e = cone(P, pts[i], pts[i + 1], r[i], r[i + 1])
        d = e if d is None else (smin(d, e, k) if k > 0 else np.minimum(d, e))
    return d


def torus_y(P, c, R, r, flat=1.0):
    """A ring round the Z axis through c (R major, r minor; flat scales the height of its section)."""
    q = P - np.asarray(c, np.float32)
    rad = np.sqrt(q[..., 0] ** 2 + q[..., 1] ** 2) - R
    return np.sqrt(rad ** 2 + (q[..., 2] / flat) ** 2) - r


def smin(a, b, k):
    """Polynomial smooth minimum: a union with a fillet about k wide."""
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b + (a - b) * h - k * h * (1.0 - h)


def smax(a, b, k):
    return -smin(-a, -b, k)


def sstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def mix(a, b, t):
    t = np.asarray(t)
    if np.ndim(a) > np.ndim(t) or np.ndim(b) > np.ndim(t):
        t = t[..., None]
    return a + (b - a) * t


def rot_x(a):
    c, s = np.cos(a), np.sin(a)
    return np.array(((1, 0, 0), (0, c, -s), (0, s, c)), np.float32)


def rot_y(a):
    c, s = np.cos(a), np.sin(a)
    return np.array(((c, 0, s), (0, 1, 0), (-s, 0, c)), np.float32)


def rot_z(a):
    c, s = np.cos(a), np.sin(a)
    return np.array(((c, -s, 0), (s, c, 0), (0, 0, 1)), np.float32)


# ---------------------------------------------------------------------------------------------------------- noise
def _hash(ix, iy, iz, seed):
    h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435)
    h = (h ^ (h >> 13)) * 1274126177
    return ((h ^ (h >> 16)) & 0xFFFFFF).astype(np.float32) / 0xFFFFFF


def noise(P, scale=1.0, seed=0):
    """Value noise in -1..1, smooth, about 1 / scale m per feature."""
    q = P * scale
    f = np.floor(q)
    t = q - f
    t = t * t * (3.0 - 2.0 * t)
    i = f.astype(np.int64)
    x, y, z = i[..., 0], i[..., 1], i[..., 2]
    def c(a, b, cc):
        return _hash(x + a, y + b, z + cc, seed)
    x00 = c(0, 0, 0) * (1 - t[..., 0]) + c(1, 0, 0) * t[..., 0]
    x10 = c(0, 1, 0) * (1 - t[..., 0]) + c(1, 1, 0) * t[..., 0]
    x01 = c(0, 0, 1) * (1 - t[..., 0]) + c(1, 0, 1) * t[..., 0]
    x11 = c(0, 1, 1) * (1 - t[..., 0]) + c(1, 1, 1) * t[..., 0]
    y0 = x00 * (1 - t[..., 1]) + x10 * t[..., 1]
    y1 = x01 * (1 - t[..., 1]) + x11 * t[..., 1]
    return (y0 * (1 - t[..., 2]) + y1 * t[..., 2]) * 2.0 - 1.0


def fbm(P, scale=1.0, seed=0, octaves=3, gain=0.5):
    out = 0.0
    a = 1.0
    tot = 0.0
    for o in range(octaves):
        out = out + a * noise(P, scale * (2.0 ** o), seed + o * 7)
        tot += a
        a *= gain
    return out / tot


def voronoi(P, seeds):
    """Nearest seed index, distance to it, and the distance to the cell border, in chunks."""
    n = P.shape[0]
    idx = np.zeros(n, np.int32)
    gap = np.zeros(n, np.float32)
    d1 = np.zeros(n, np.float32)
    S = np.asarray(seeds, np.float32)
    for s in range(0, n, 200000):
        p = P[s:s + 200000]
        d = np.sqrt(((p[:, None, :] - S[None, :, :]) ** 2).sum(-1))
        o = np.argpartition(d, 1, axis=1)[:, :2]
        r = np.arange(p.shape[0])
        a, b = d[r, o[:, 0]], d[r, o[:, 1]]
        sw = a > b
        o0 = np.where(sw, o[:, 1], o[:, 0])
        o1 = np.where(sw, o[:, 0], o[:, 1])
        idx[s:s + 200000] = o0
        d1[s:s + 200000] = np.minimum(a, b)
        # (the true distance to the cell's border, the bisector: a plain d2 - d1 smears wide where two seeds lie close)
        gap[s:s + 200000] = np.abs(b * b - a * a) / np.maximum(2.0 * length(S[o0] - S[o1]), 1e-5)
    return idx, d1, gap


# ---------------------------------------------------------------------------------------------------- field -> mesh
def field_grid(fn, lo, hi, h, block=6):
    """The field on a grid of step h, with only the blocks near the surface evaluated finely."""
    lo = np.asarray(lo, np.float64)
    hi = np.asarray(hi, np.float64)
    n = np.ceil((hi - lo) / h).astype(int) + 1
    nb = np.ceil(n / block).astype(int) + 1
    bh = h * block
    cx = lo[0] + (np.arange(nb[0]) + 0.5) * bh
    cy = lo[1] + (np.arange(nb[1]) + 0.5) * bh
    cz = lo[2] + (np.arange(nb[2]) + 0.5) * bh
    C = np.stack(np.meshgrid(cx, cy, cz, indexing="ij"), -1).reshape(-1, 3).astype(np.float32)
    coarse = np.concatenate([fn(C[i:i + 400000]) for i in range(0, C.shape[0], 400000)])
    near = np.abs(coarse) < bh * 1.25
    G = np.full(tuple(n), 1.0, np.float32)
    # far blocks keep their sign
    bi = np.stack(np.unravel_index(np.arange(C.shape[0]), tuple(nb)), -1)
    for (i, j, k), v in zip(bi[~near & (coarse < 0)], coarse[~near & (coarse < 0)]):
        G[i * block:(i + 1) * block, j * block:(j + 1) * block, k * block:(k + 1) * block] = v
    act = bi[near]
    off = np.stack(np.meshgrid(np.arange(block), np.arange(block), np.arange(block), indexing="ij"), -1).reshape(-1, 3)
    for s in range(0, act.shape[0], 4000):
        ids = (act[s:s + 4000, None, :] * block + off[None, :, :]).reshape(-1, 3)
        ids = ids[(ids < n).all(1)]
        G[ids[:, 0], ids[:, 1], ids[:, 2]] = fn((lo + ids * h).astype(np.float32))
    return G, lo


def surface_nets(G, lo, h):
    """Naive surface nets: vertices (float32 Nx3) and quads (int Mx4), oriented outward (field < 0 inside)."""
    inside = G < 0
    nx, ny, nz = G.shape
    c = np.zeros((8, nx - 1, ny - 1, nz - 1), np.float32)
    for i in range(8):
        a, b, cc = i & 1, (i >> 1) & 1, (i >> 2) & 1
        c[i] = G[a:nx - 1 + a, b:ny - 1 + b, cc:nz - 1 + cc]
    s = c < 0
    cnt = s.sum(0)
    active = (cnt > 0) & (cnt < 8)
    ci = np.argwhere(active)
    ids = -np.ones(active.shape, np.int64)
    ids[active] = np.arange(ci.shape[0])
    ca = c[:, active]
    edges = ((0, 1), (2, 3), (4, 5), (6, 7), (0, 2), (1, 3), (4, 6), (5, 7), (0, 4), (1, 5), (2, 6), (3, 7))
    corner = np.array([[i & 1, (i >> 1) & 1, (i >> 2) & 1] for i in range(8)], np.float32)
    tot = np.zeros((ci.shape[0], 3), np.float32)
    num = np.zeros(ci.shape[0], np.float32)
    for a, b in edges:
        va, vb = ca[a], ca[b]
        m = (va < 0) != (vb < 0)
        t = va[m] / (va[m] - vb[m])
        tot[m] += corner[a] + (corner[b] - corner[a]) * t[:, None]
        num[m] += 1
    V = (ci + tot / num[:, None]) * h + lo
    Q = []
    for ax in range(3):
        u, v = (ax + 1) % 3, (ax + 2) % 3
        sl = [slice(None)] * 3
        sl2 = [slice(None)] * 3
        sl[ax] = slice(0, -1)
        sl2[ax] = slice(1, None)
        flip = inside[tuple(sl)] != inside[tuple(sl2)]
        # (grid edges on the outer shell have no four cells round them)
        ed = np.argwhere(flip)
        ed = ed[(ed[:, u] > 0) & (ed[:, v] > 0) & (ed[:, u] < G.shape[u] - 1) & (ed[:, v] < G.shape[v] - 1)]
        if ed.shape[0] == 0:
            continue
        def cell(du, dv):
            e = ed.copy()
            e[:, u] -= du
            e[:, v] -= dv
            return ids[e[:, 0], e[:, 1], e[:, 2]]
        q = np.stack((cell(1, 1), cell(0, 1), cell(0, 0), cell(1, 0)), 1)
        pos = inside[ed[:, 0], ed[:, 1], ed[:, 2]]
        q[~pos] = q[~pos][:, ::-1]
        Q.append(q)
    Q = np.concatenate(Q)
    Q = Q[(Q >= 0).all(1)]
    return V.astype(np.float32), Q


def gradient(fn, P, e=0.002):
    """The field's unit gradient by central differences."""
    g = np.zeros_like(P)
    for i in range(3):
        d = np.zeros(3, np.float32)
        d[i] = e
        g[:, i] = fn(P + d) - fn(P - d)
    return g / np.maximum(length(g), 1e-9)[:, None]


def relax(fn, V, steps=2):
    """Pulls vertices onto the true surface (surface nets leaves them a little off it)."""
    for _ in range(steps):
        d = fn(V)
        V = V - gradient(fn, V, 0.0015) * d[:, None]
    return V


def chunked(fn, P, n=300000):
    return np.concatenate([fn(P[i:i + n]) for i in range(0, P.shape[0], n)])


def occlusion(fn, P, N, dists=(0.008, 0.02, 0.045, 0.09), k=None):
    """Field-sampled ambient occlusion in 0..1 (1 open): how much closer to the surface a step out along the normal
    stays than a flat wall would."""
    occ = np.zeros(P.shape[0], np.float32)
    w = 1.0
    tot = 0.0
    for d in dists:
        v = chunked(fn, P + N * d)
        occ += w * np.clip((d - v) / d, 0.0, 1.0)
        tot += w
        w *= 0.7
    return 1.0 - occ / tot


def cavity(fn, P, N, r=0.006):
    """Curvature in about -1..1: positive in a crease, negative on a ridge, from the field's Laplacian on the surface."""
    e = r
    s = 0.0
    for i in range(3):
        d = np.zeros(3, np.float32)
        d[i] = e
        s = s + chunked(fn, P + d) + chunked(fn, P - d)
    return np.clip(-(s - 6.0 * chunked(fn, P)) / (6.0 * e), -1.0, 1.0)


def rasterize(uv, tris, px, attrs):
    """Interpolates per-corner attributes over the UV triangles: returns a mask (px, px) and an array per attribute.
    uv: Tx3x2 in 0..1; attrs: list of Tx3xK arrays."""
    out = [np.zeros((px, px, a.shape[2]), np.float32) for a in attrs]
    mask = np.zeros((px, px), bool)
    tid = -np.ones((px, px), np.int32)
    uvp = uv * px - 0.5
    for t in range(uv.shape[0]):
        a, b, c = uvp[t]
        lo = np.floor(np.minimum(np.minimum(a, b), c)).astype(int)
        hi = np.ceil(np.maximum(np.maximum(a, b), c)).astype(int)
        x0, y0 = max(lo[0], 0), max(lo[1], 0)
        x1, y1 = min(hi[0], px - 1), min(hi[1], px - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(den) < 1e-12:
            continue
        w0 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / den
        w1 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / den
        w2 = 1.0 - w0 - w1
        m = (w0 >= -0.02) & (w1 >= -0.02) & (w2 >= -0.02)
        if not m.any():
            continue
        yy, xx = ys[m], xs[m]
        mask[yy, xx] = True
        tid[yy, xx] = t
        for o, at in zip(out, attrs):
            o[yy, xx] = (w0[m, None] * at[t, 0] + w1[m, None] * at[t, 1] + w2[m, None] * at[t, 2])
    return mask, out, tid


def dilate(img, mask, px=8):
    """Grows the painted texels into the empty ones px times, so mip levels and seams never sample black."""
    img = img.copy()
    m = mask.copy()
    for _ in range(px):
        grown = np.zeros_like(img)
        cnt = np.zeros(m.shape, np.float32)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            r = np.roll(np.roll(m, dx, 1), dy, 0)
            grown += np.roll(np.roll(img, dx, 1), dy, 0) * (np.roll(np.roll(m, dx, 1), dy, 0))[..., None]
            cnt += r
        new = (~m) & (cnt > 0)
        img[new] = grown[new] / cnt[new][:, None]
        m = m | new
    return img


def to_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)


def hexc(h):
    """A hex colour as display-referred rgb 0..1 (paint happens in display space, as a painter would)."""
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


def ramp(t, stops):
    """A colour ramp: t 0..1 across the hex stops."""
    cols = np.stack([hexc(s) for s in stops])
    x = np.clip(t, 0.0, 1.0) * (len(stops) - 1)
    i = np.minimum(x.astype(int), len(stops) - 2)
    f = (x - i)[..., None]
    return cols[i] * (1 - f) + cols[i + 1] * f
