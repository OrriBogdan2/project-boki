"""ART-1 Cinder: the texel-space paint (recipe: kael_paint.py): arrays of texels (world position, normal, occlusion) to sRGB in 0..1."""
import numpy as np
from meshkit import norm, smooth
from kael_paint import hexc, mix, fbm, vnoise, lit, ramp
import cinder_pieces as K

HOT = np.array([1.0, 0.68, 0.2])         # keyed fully hot by hero_toon's glow_key; she keeps her painted colours (no model_glow core), so the iris stays
HOT_RIM = np.array([0.86, 0.3, 0.07])    # keyed partly
SKIN = [hexc("#2c282e"), hexc("#413c43"), hexc("#585259"), hexc("#6f6870"), hexc("#88808a")]
COPPER = [hexc("#4a2210"), hexc("#7c3f1c"), hexc("#ad6230"), hexc("#d68a4c"), hexc("#f6c08c")]
BRASS = [hexc("#4a3414"), hexc("#7e5e24"), hexc("#b08a3c"), hexc("#d8b45c"), hexc("#f6e0a0")]
STEEL = [hexc("#35343a"), hexc("#55535a"), hexc("#7a7880"), hexc("#a09ea6"), hexc("#cfced4")]
LEATHER = [hexc("#1c0f0a"), hexc("#351d12"), hexc("#50301d"), hexc("#6d452b"), hexc("#8d6141")]
RUBBER = [hexc("#170d0c"), hexc("#2b1612"), hexc("#422219"), hexc("#5a3122"), hexc("#74432e")]
WRAP = [hexc("#2e0a08"), hexc("#561410"), hexc("#7e1f16"), hexc("#a83422"), hexc("#c95236")]


def worley(p, f):
    """(F2 - F1, cell hash) of a 3D cell noise at frequency f."""
    q = np.asarray(p, dtype=np.float64) * f
    i = np.floor(q)
    d1, d2 = np.full(q.shape[:-1], 9.0), np.full(q.shape[:-1], 9.0)
    h1 = np.zeros(q.shape[:-1])
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for dz in (-1, 0, 1):
                c = i + (dx, dy, dz)
                h = np.sin(c @ np.array([127.1, 311.7, 74.7])) * 43758.5453
                j = np.stack([h % 1.0, (h * 1.37) % 1.0, (h * 1.91) % 1.0], -1)
                d = np.linalg.norm(c + j - q, axis=-1)
                n2 = np.where(d < d1, d1, np.minimum(d2, d))
                h1 = np.where(d < d1, h % 1.0, h1)
                d1 = np.minimum(d1, d)
                d2 = n2
    return d2 - d1, h1


def hot_cracks(c, p, f, wd, amount=1.0):
    """Glowing fissures laid over colours c."""
    e, _ = worley(p + 0.012 * (fbm(p * 34)[..., None] - 0.5), f)
    keep = amount * (0.55 + 0.45 * np.sin(p[..., 0] * 41 + p[..., 2] * 67 + p[..., 1] * 23) > 0.42)
    core = (1 - smooth(wd * 0.45, wd, e)) * keep
    rim = (1 - smooth(wd, wd * 2.1, e)) * keep
    c = mix(c, HOT_RIM, rim * 0.85)
    return mix(c, HOT, core)


def skin(p, n, ao):
    t = lit(n, ao) + (fbm(p * 60) - 0.5) * 0.05
    return ramp(t * 0.92, SKIN)


def skull(p, n, ao):
    return hot_cracks(skin(p, n, ao), p, 16.0, 0.05)


def hands(p, n, ao):
    return hot_cracks(skin(p, n, ao), p, 22.0, 0.035, 0.6)


def claws(c, p, segs):
    """Dark red-black nails on their tips."""
    d = np.full(p.shape[:-1], 9.0)
    for a, b in segs:
        a, b = np.asarray(a), np.asarray(b)
        ab = b - a
        h = np.clip((p - a) @ ab / (ab @ ab), 0, 1)
        d = np.minimum(d, np.linalg.norm(p - (a + h[..., None] * ab), axis=-1))
    return mix(c, hexc("#2a0b0b"), 1 - smooth(0.0045, 0.0085, d))


def fin(p, n, ao, rootp):
    """The web glows ember toward its rim; dark at the root."""
    d = np.linalg.norm(p - rootp, axis=-1)
    t = smooth(0.03, 0.15, d)
    c = mix(ramp(lit(n, ao) * 0.8, SKIN), hexc("#d2401a"), t * 0.92)
    return mix(c, hexc("#ff8a2c"), smooth(0.11, 0.17, d) * 0.7)


def tail(p, n, ao, path, wd):
    """Charcoal with a pale ringed belly; big cells split by magma, hotter toward the tip."""
    from scipy_free import nearest_on_path
    u, along_up = nearest_on_path(p, n, path)
    t = lit(n, ao)
    c = ramp(t * 0.85, SKIN)
    belly = smooth(0.15, 0.55, -along_up)
    rings = 0.5 + 0.5 * np.sin(u * 120.0)
    pale = ramp(np.clip(t * 0.9 + 0.22, 0, 1), [hexc("#3a2a2c"), hexc("#5e4442"), hexc("#7d5f58"), hexc("#987a70"), hexc("#b0958a")])
    c = mix(c, pale * (0.78 + 0.22 * rings)[..., None], belly)
    e, h = worley(p, 17.0)
    w = 0.022 + 0.026 * smooth(0.4, 1.0, u)
    back = (1 - belly) * smooth(0.02, 0.2, u)
    c = mix(c, hexc("#1f1a1e"), back * 0.5 * (h > 0.45))
    keep = smooth(0.25, 0.42, fbm(p * 7.0)) + smooth(0.75, 1.0, u)
    core = (1 - smooth(w * 0.5, w, e)) * back * np.clip(keep, 0, 1)
    rim = (1 - smooth(w, w * 2.4, e)) * back * np.clip(keep, 0, 1)
    c = mix(c, HOT_RIM, rim * 0.8)
    return mix(c, HOT, core)


def metal(rampc, p, n, ao, grime=0.25, sheen=0.25):
    t = lit(n, ao)
    spec = np.clip(n[..., 2] * 0.5 + 0.5, 0, 1) ** 6 * sheen
    g = fbm(p * 26)
    c = ramp(np.clip(t * 0.95 + spec + (g - 0.5) * 0.14, 0, 1), rampc)
    d = smooth(0.55, 0.72, fbm(p * 11 + 7.0))
    return mix(c, c * 0.58, d * grime)


def copper(p, n, ao):
    c = metal(COPPER, p, n, ao, 0.45, 0.32)
    # a green-blue bloom low in the seams
    v = smooth(0.62, 0.8, fbm(p * 19 + 3.0)) * (1 - np.clip(ao, 0, 1)) * 2.0
    return mix(c, hexc("#4e7a6a"), np.clip(v, 0, 0.5))


def brass(p, n, ao):
    return metal(BRASS, p, n, ao, 0.3, 0.4)


def steel(p, n, ao):
    return metal(STEEL, p, n, ao, 0.35, 0.35)


def leather(p, n, ao):
    t = lit(n, ao) + (fbm(p * 50) - 0.5) * 0.12
    return ramp(np.clip(t * 0.92, 0, 1), LEATHER)


def hose(p, n, ao, axis_ribs=True):
    t = lit(n, ao)
    r = 0.5 + 0.5 * np.sin((p[..., 0] * 3 + p[..., 1] * 5 + p[..., 2] * 7) * 34)
    return ramp(np.clip(t * 0.86 + (r - 0.5) * 0.16, 0, 1), RUBBER)


def wrap(p, n, ao, g, b):
    """The grip's red leather wrap: a spiral."""
    h = (p - g) @ b
    t = lit(n, ao)
    q = np.arctan2(p[..., 2] - g[2], p[..., 0] - g[0])
    band = 0.5 + 0.5 * np.sin(h * 170 + q * 2)
    return ramp(np.clip(t * 0.95 + 0.18 * (band - 0.5), 0, 1), WRAP)


def lens(p, frame):
    c, k, l2, r, s = frame
    d = p - c
    x, y = d @ k / r, d @ l2 / r
    q = np.sqrt(x * x + y * y)
    col = mix(hexc("#1f2a30"), hexc("#7a5a3c"), smooth(0.2, 1.0, y * 0.7 + 0.45))
    glint = np.exp(-((x * 0.8 + y - 0.35) / 0.12) ** 2) * 0.75 + np.exp(-((x * 0.8 + y + 0.1) / 0.05) ** 2) * 0.4
    col = col + glint[..., None] * 0.55
    crack = np.minimum(np.abs(x + 0.5 * y + 0.2 * s), np.abs(y - 0.65 * x * s - 0.25))
    return np.clip(mix(col, hexc("#e8e4dc"), (1 - smooth(0.0, 0.04, crack)) * 0.6), 0, 1)


def gauge(p, gc, gd):
    k = norm(np.cross(gd, (0, 0, 1)))
    l2 = norm(np.cross(gd, k))
    d = p - gc
    x, y = d @ k / 0.046, d @ l2 / 0.046
    r = np.sqrt(x * x + y * y)
    a = np.arctan2(x, y)
    c = np.broadcast_to(hexc("#e6dcc0"), p.shape).copy()
    red = (a > 0.9) & (a < 2.3) & (r > 0.72) & (r < 0.9)
    c[red] = hexc("#c8281a")
    ticks = (np.abs(((a + 3.2) / 0.32) % 1 - 0.5) > 0.42) & (r > 0.76) & (r < 0.92) & (np.abs(a) < 2.4)
    c[ticks] = hexc("#2a2422")
    nd = 1.05
    h = np.array([np.sin(nd), np.cos(nd)])
    along = x * h[0] + y * h[1]
    across = np.abs(x * h[1] - y * h[0])
    needle = (along > -0.12) & (along < 0.78) & (across < 0.05 * (1 - along * 0.8))
    c[needle] = hexc("#b01a10")
    c[r < 0.11] = hexc("#2a2422")
    return c


def face(plate, p, n, ao):
    """The plate: a straight-on painted head (from the owner's sheet and portrait, Meshy image edit), projected flat on the sculpt. Its eyes,
    cracks and the iris go to the hot key; its painted brows are out, the brow geometry moves over clean skin. Past its edge: plain skin."""
    q = (p - K.C) / K.HS
    img, clean, H = plate
    sc = 895.0 / 0.25
    px = (510.0 + q[..., 0] * sc)
    py = (40.0 + (0.115 - q[..., 2]) * sc)
    ix = np.clip(px, 0, H - 1).astype(int)
    iy = np.clip(py, 0, H - 1).astype(int)
    c = img[iy, ix]
    # the lit relief of the sculpt over the flat plate
    c0 = clean[iy, ix]
    lum = c.mean(-1)
    r_ = np.sqrt(((px - 510) / 300.0) ** 2 + ((py - 487) / 442.0) ** 2)
    sh = 0.72 + 0.42 * smooth(-0.4, 0.8, n[..., 2] * 0.45 + n[..., 1] * 0.75)
    out = c * (sh * 0.92)[..., None] * np.array([1.03, 0.98, 1.0])
    # the cracks and the eyes keep the plate's own fire, a little lifted
    hot = smooth(0.14, 0.3, c[..., 0] - c[..., 2]) * smooth(0.34, 0.5, c[..., 0])
    out = mix(out, np.minimum(c * 1.18, 1.0), hot)
    edge = smooth(0.84, 0.97, r_)
    s = skin(p, n, ao)
    return mix(out, s, edge)
