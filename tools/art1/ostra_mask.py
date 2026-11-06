"""Motley's face (ART-1): the starry void inside the hood, its sharp grin and slit eyes. Drawn on a plane, the owner's call: an emissive
texture (numpy only). u -1..1 across (+ his right), v -1 chin .. 1 brow. The shape follows ostra_FINAL_sheet's close-up."""
import numpy as np


def sm(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def gauss(u, v, cu, cv, su, sv, rot=0.0):
    du, dv = u - cu, v - cv
    if rot:
        c, s = np.cos(rot), np.sin(rot)
        du, dv = c * du + s * dv, -s * du + c * dv
    return np.exp(-(du * du / (su * su) + dv * dv / (sv * sv)))


def seg_dist(u, v, pts):
    pts = np.asarray(pts, float)
    best = np.full(u.shape, 1e9)
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        ab = b - a
        t = np.clip(((u - a[0]) * ab[0] + (v - a[1]) * ab[1]) / (ab @ ab), 0.0, 1.0)
        best = np.minimum(best, np.hypot(u - a[0] - t * ab[0], v - a[1] - t * ab[1]))
    return best


def grin(u, v):
    """0..1 inside the grin (ostra_head): one huge solid white crescent, the corners hooked up to points, a few small fangs cut down into its
    top edge toward the corners; -> the shape, and the fangs' cuts"""
    au = np.abs(u)
    top = -0.32 + 0.52 * (au / 0.80) ** 2.4
    bot = -0.72 + 0.92 * (au / 0.80) ** 2.2
    saw = np.abs(((u * 8.5) % 1.0) - 0.5) * 2.0
    cut = 0.055 * saw * sm(0.22, 0.42, au) * sm(0.8, 0.6, au)
    inside = sm(-0.012, 0.012, top - cut - v) * sm(-0.012, 0.012, v - bot) * (au < 0.80)
    return inside, np.zeros_like(inside)


def slits(u, v):
    """the eyes: two crescents, thick in the middle, drawn to points, the outer tip high: a laughing, cruel squint"""
    au = np.abs(u)
    x = (au - 0.40) / 0.30
    mid = 0.27 + 0.09 * x
    top = mid + 0.085 * (1.0 - x * x)
    low = mid - 0.0 * x + 0.02 * (1.0 - x * x) - 0.05 * (1.0 - x * x)
    return sm(0.012, -0.006, v - top) * sm(-0.012, 0.006, v - low) * (np.abs(x) < 1.0)


def textures(size=1024):
    """-> albedo, emission (rows top to bottom, v = 1 on top), floats 0..1: the deep with its stars, the grin and eyes glowing white-violet"""
    xs = (np.arange(size) + 0.5) / size * 2 - 1
    U, V = np.meshgrid(xs, -xs)
    rng = np.random.RandomState(12)

    def noise(c, sd):
        r = np.random.RandomState(sd)
        g = r.rand(c + 2, c + 2)
        x, y = (U + 1) * 0.5 * c, (V + 1) * 0.5 * c
        xi, yi = np.clip(x.astype(int), 0, c), np.clip(y.astype(int), 0, c)
        fx, fy = x - xi, y - yi
        fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        return (g[yi, xi] * (1 - fx) + g[yi, xi + 1] * fx) * (1 - fy) + (g[yi + 1, xi] * (1 - fx) + g[yi + 1, xi + 1] * fx) * fy

    neb = noise(5, 1) * 0.6 + noise(11, 2) * 0.3 + noise(23, 3) * 0.1
    ang = np.arctan2(V + 0.1, U)
    rad = np.hypot(U, V + 0.1)
    swirl = 0.5 + 0.5 * np.sin(ang * 2 + rad * 8 + neb * 5)
    deep = np.array((0.03, 0.02, 0.10))
    mid = np.array((0.34, 0.14, 0.78))
    c = deep + (mid - deep) * np.clip((neb * swirl * 2.6 - 0.3), 0, 1)[..., None]
    def blur_s(a):
        return (np.roll(a, 2, 0) + np.roll(a, -2, 0) + np.roll(a, 2, 1) + np.roll(a, -2, 1)) * 0.35

    stars = np.zeros(U.shape, np.float32)
    n = 420
    ys, xs2, b = rng.randint(2, size - 2, n), rng.randint(2, size - 2, n), rng.rand(n)
    stars[ys, xs2] = b
    stars[ys + 1, xs2] = b
    stars[ys, xs2 + 1] = b
    stars[ys + 1, xs2 + 1] = b
    stars = np.clip(stars * 1.5 + blur_s(stars), 0, 1)
    g, cut = grin(U, V)
    e = slits(U, V)
    shape = np.maximum(g, e)

    def blur(a, r):
        k = 2 * r + 1
        out = a
        for ax in (0, 1):
            cs = np.cumsum(np.concatenate((np.zeros_like(np.take(out, [0], ax)), out), ax), ax)
            hi = np.take(cs, np.minimum(np.arange(size) + r + 1, size), ax)
            lo = np.take(cs, np.maximum(np.arange(size) - r, 0), ax)
            out = (hi - lo) / k
        return out

    bloom = np.clip(blur(shape, 18) * 0.8 + blur(shape, 6) * 0.7, 0, 1)
    hot = np.array((1.0, 0.97, 1.0))
    vio = np.array((0.62, 0.26, 1.0))
    em = vio * (bloom * 0.6)[..., None] + c * 0.6
    em = em + stars[..., None] * np.array((0.9, 0.85, 1.0)) * (1 - shape[..., None])
    teeth = shape
    em = em * (1 - teeth[..., None]) + hot * teeth[..., None]
    alb = c * 0.35 * (1 - shape[..., None]) + np.array((0.9, 0.85, 1.0)) * teeth[..., None]
    return np.clip(alb, 0, 1).astype(np.float32), np.clip(em, 0, 1).astype(np.float32)
