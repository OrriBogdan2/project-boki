"""Breaker's paint (ART-1): colour per texel on the sculpt's own surface. The toon shader adds soft light on top, so
the sculpt's form, cavities and frost are painted in, the way the concept art is."""
import numpy as np

import breaker_sculpt as B
import sculpt_kit as S
from sculpt_kit import fbm, smooth, vnoise, worley

C = lambda h: np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


def raster_aux(uv, pos, nrm, aux, size):
    out = {"p": np.zeros((size, size, 3), np.float32), "n": np.zeros((size, size, 3), np.float32),
           "id": np.full((size, size), -1, np.int16), "a": np.zeros((size, size, 2), np.float32)}
    uvp = uv * size - 0.5
    for t in range(len(uvp)):
        a, b, c = uvp[t]
        lo = np.floor(np.minimum(np.minimum(a, b), c) - 1).astype(int)
        hi = np.ceil(np.maximum(np.maximum(a, b), c) + 1).astype(int)
        x0, y0, x1, y1 = max(lo[0], 0), max(lo[1], 0), min(hi[0], size - 1), min(hi[1], size - 1)
        if x1 < x0 or y1 < y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1, dtype=np.float32), np.arange(y0, y1 + 1, dtype=np.float32))
        den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(den) < 1e-9:
            continue
        w0 = ((b[1] - c[1]) * (gx - c[0]) + (c[0] - b[0]) * (gy - c[1])) / den
        w1 = ((c[1] - a[1]) * (gx - c[0]) + (a[0] - c[0]) * (gy - c[1])) / den
        w2 = 1 - w0 - w1
        m = (w0 >= -0.02) & (w1 >= -0.02) & (w2 >= -0.02)
        if not m.any():
            continue
        iy, ix = gy[m].astype(int), gx[m].astype(int)
        W = np.stack([w0[m], w1[m], w2[m]], 1)
        out["p"][iy, ix] = W @ pos[t]
        out["n"][iy, ix] = W @ nrm[t]
        out["a"][iy, ix] = W @ aux[t]
        out["id"][iy, ix] = 1
    return out


def form(f, p, n, steps=(0.012, 0.035, 0.09), wide=5.0):
    """(ao 0..1, curvature): the sculpt's occlusion along the normal, and how convex it is here."""
    ao = np.ones(len(p), np.float32)
    w = 1.0
    occ = np.zeros(len(p), np.float32)
    for s in steps:
        d = f.sample(p + n * s)
        occ += w * np.clip(1.0 - d / s, 0, 1)
        w *= 0.7
    ao = 1.0 - occ / (1 + 0.7 + 0.49)
    e = f.vox * 2.5
    lap = -6.0 * f.sample(p)
    for i in range(3):
        o = np.zeros(3, np.float32)
        o[i] = e
        lap += f.sample(p + o) + f.sample(p - o)
    e2 = e * wide
    lap2 = -6.0 * f.sample(p)
    for i in range(3):
        o = np.zeros(3, np.float32)
        o[i] = e2
        lap2 += f.sample(p + o) + f.sample(p - o)
    return ao, np.clip(lap / e, -1.5, 1.0) + 0.6 * np.clip(lap2 / e2, -1.0, 0.7) * (wide > 1.5)


def shade(col, ao, curv, n, cav=0.55, hi=0.28, tint=(0.62, 0.68, 0.92)):
    """Painted light: cool occlusion in the creases, a lit top, a pale edge on what bulges."""
    t = np.array(tint, np.float32)
    k = smooth(0.25, 0.86, ao)[:, None]
    out = col * (t * 0.55 + (1 - (t * 0.55)) * k)
    top = 0.5 + 0.5 * n[:, 2:3]
    out = out * (0.86 + 0.26 * top)
    out = out * (1.0 - cav * smooth(-0.1, -0.6, curv))[:, None] if False else out
    c = curv[:, None]
    out = out * (1.0 - cav * np.clip(c * 1.3, 0, 1))        # (positive laplacian: a crease)
    out = out + (out * 0.5 + 0.06) * hi * np.clip(-c * 1.0, 0, 1)
    return out


def mix(a, b, m):
    m = np.asarray(m, np.float32)
    if m.ndim == 1:
        m = m[:, None]
    return a * (1 - m) + b * m


KEY = np.array((1.0, 0.76, 0.44), np.float32)     # hero_toon glow_key: these texels glow in model_glow's colour


def ones(p):
    return np.ones((len(p), 1), np.float32)


def wood_col(p, along, tone=0.0):
    """Sea-dark timber; `along` (N, 3) scales the grain's length per axis."""
    x, y, z = p[:, 0] * along[0], p[:, 1] * along[1], p[:, 2] * along[2]
    g = vnoise(x, y, z, 70.0)[:, None]
    col = mix(C("8c6a48"), C("553a26"), g * 1.15)
    col = mix(col, C("3d2a1c"), smooth(0.5, 0.72, fbm(x, y, z, 7.0, 3)) * 0.55)
    col = mix(col, C("7f6a52"), smooth(0.55, 0.75, fbm(p[:, 0] + 3, p[:, 1], p[:, 2], 6.0, 3)) * 0.35)     # sea-bleached
    return col


def stains(col, p):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    return mix(col, C("4d6a38"), smooth(0.58, 0.72, fbm(x, y, z + 2, 9.0, 3)) * 0.5)


def p_hull(p, n, c):
    f = c["f"]
    ao, cv = form(f, p, n)
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    r = np.sqrt(x * x + y ** 2) + 1e-4
    v = (z - 0.5 - 0.12 * (r / 0.38) ** 2 * smooth(0.0, 0.35, np.abs(x))) / 0.058
    pid = np.floor(v + 0.5)
    q = (v + 0.5) % 1.0 - 0.5
    seam = smooth(0.09, 0.03, np.abs(np.abs(q) - 0.5))
    col = wood_col(p, (0.35, 0.35, 4.0))
    col = col * (0.82 + 0.36 * vnoise(pid * 3.1, pid * 1.7, pid, 1.0))[:, None]
    col = stains(col, p)
    col = mix(col, C("1e140e"), seam * 0.9)
    col = shade(col, ao, cv * 0.5, n, 0.5, 0.25, (0.6, 0.62, 0.72))
    # the sea's light between the planks: patches of seam, wider where the hull has sprung
    a = np.arctan2(x, y)
    patch = smooth(0.6, 0.66, fbm(a * 0.7, a * 0.3, pid * 0.23, 4.0, 2))
    wide = smooth(0.12, 0.02, np.abs(np.abs(q) - 0.5) + (vnoise(a * 6.0, pid, pid, 1.0) - 0.5) * 0.14)
    lit = patch * wide * smooth(0.25, 0.32, z) * smooth(0.76, 0.68, z)
    # and the collar: a ring of it under the helmet, running down in drips
    ring = smooth(0.74, 0.77, z + (vnoise(a * 7.0, a, a, 1.0) - 0.5) * 0.12) * smooth(-0.02, 0.1, y)
    run = smooth(0.08, 0.02, np.abs(((a * 3.1 + 0.4) % 1.0) - 0.5) * 0.14 + 0.0) * smooth(0.7, 0.83, z) * (y > 0.0)
    hot = np.maximum(np.maximum(lit, ring), run * 0.0)
    col = mix(col, C("3fbfb4"), np.clip(smooth(0.0, 0.5, hot) * 0.55, 0, 1))
    return mix(col, KEY, smooth(0.45, 0.6, hot))


def p_limb(p, n, c):
    f = c["f"]
    ao, cv = form(f, p, n)
    lab = f.label(p)
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    col = stains(wood_col(p, (2.5, 2.5, 0.3)), p)
    a = np.arctan2(y, np.abs(x) - 0.44)
    col = shade(col, ao, cv * 0.7, n, 0.65, 0.3, (0.6, 0.62, 0.72))
    iron = mix(C("5b5048"), C("3e342e"), fbm(x, y, z, 14.0, 3)[:, None] * 1.1)
    iron = mix(iron, C("6e4a34"), smooth(0.48, 0.64, fbm(x + 5, y, z, 12.0, 4)) * 0.6)
    col = np.where((lab == B.IRON)[:, None], shade(iron, ao, cv * 0.8, n, 0.6, 0.9, (0.65, 0.6, 0.7)), col)
    col = np.where((lab == B.RIVET)[:, None], shade(C("8a7f74") * ones(p), ao, cv * 0.5, n, 0.5, 0.9), col)
    barn = C("c4bcaa") * ones(p) * (0.8 + 0.4 * fbm(x, y, z, 90.0, 2))[:, None]
    col = np.where((lab == B.BARN)[:, None], shade(barn, ao, cv, n, 0.8, 0.4), col)
    # a few long teal splits down the staves
    sp = smooth(0.74, 0.8, vnoise(x * 5.0, y * 5.0, z * 0.5, 16.0)) * (lab == B.WOOD) * smooth(0.45, 0.5, z) * smooth(0.72, 0.66, z)
    return mix(col, KEY, sp)


def p_mast(p, n, c):
    f = c["f"]
    ao, cv = form(f, p, n, (0.006, 0.016), 1.0)
    lab = f.label(p)
    col = wood_col(p, (1.2, 1.2, 0.6))
    col = shade(col, ao, cv * 0.6, n, 0.6, 0.3, (0.6, 0.6, 0.7))
    return np.where((lab == B.RIVET)[:, None], shade(C("b49a6a") * ones(p), ao, cv, n, 0.7, 0.3), col)


def p_iron(p, n, c):
    f = c["f"]
    ao, cv = form(f, p, n, (0.005, 0.014, 0.03), 1.0)
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    lab = f.label(p)
    col = mix(C("665a50"), C("40362f"), fbm(x, y, z, 14.0, 3)[:, None] * 1.1)
    rust = smooth(0.46, 0.62, fbm(x + 5, y, z, 11.0, 4))
    col = mix(col, C("6e4a34"), rust * 0.7)
    col = mix(col, C("8c5a38"), smooth(0.6, 0.72, fbm(x, y + 3, z, 26.0, 2)) * rust * 0.4)
    col = mix(col, C("a09488"), (lab == B.RIVET) * 0.7)
    return shade(col, ao, cv * 0.8, n, 0.6, 0.6, (0.65, 0.6, 0.7))


def p_brass(p, n, c):
    f = c["f"]
    ao, cv = form(f, p, n, (0.004, 0.012, 0.03), 1.5)
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    lab = f.label(p)
    col = mix(C("d8a858"), C("9a6c30"), fbm(x, y, z, 16.0, 3)[:, None] * 1.1)
    col = mix(col, C("3f8f80"), smooth(0.45, 0.2, ao) * 0.6)                       # verdigris in the creases
    col = mix(col, C("55483c"), (lab == B.IRON) * 0.85)
    col = mix(col, C("f0d28a"), (lab == B.RIVET) * 0.6)
    col = mix(col, C("15282c"), (lab == B.GLASS) * 0.9)
    return shade(col, ao, cv * 0.6, n, 0.6, 1.3, (0.75, 0.6, 0.5))


def p_compass(p, n, c):
    q = p - c["part"]["centre"]
    nn = c["part"]["normal"]
    up = np.array((0, 0, 1), np.float32)
    up = up - nn * (up @ nn)
    up /= np.linalg.norm(up)
    rt = np.cross(up, nn)
    u, v = q @ rt, q @ up
    r = np.sqrt(u * u + v * v)
    ang = np.arctan2(u, v)
    col = C("9a9a84") * ones(p)
    st = r - (0.012 + 0.052 * np.abs(np.cos(ang + 0.4)) ** 7)
    rose = smooth(0.002, -0.002, st)
    col = mix(col, np.where(((np.cos(ang + 0.4) > 0))[:, None], C("c23a2a") * ones(p), C("1f6a78") * ones(p)), rose)
    ticks = smooth(0.012, 0.004, np.abs(((ang / 6.283 * 16) % 1.0) - 0.5) / 16 * 6.283 * r) * smooth(0.058, 0.062, r)
    col = mix(col, C("5a4020"), ticks)
    # the warm light is the ring of the dial
    return mix(col, KEY, smooth(0.066, 0.07, r) + 0.0)


def p_moss(p, n, c):
    f = c["f"]
    ao, cv = form(f, p, n, (0.008, 0.02, 0.05), 1.5)
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    col = mix(C("7f9a34"), C("38551e"), fbm(x, y, z, 26.0, 3)[:, None] * 1.3)
    col = mix(col, C("b2c84e"), smooth(0.62, 0.8, fbm(x + 1, y, z, 44.0, 2)) * 0.6)
    return shade(col, ao, cv * 0.7, n, 0.6, 0.3, (0.45, 0.6, 0.55))


def p_sail(p, n, c):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    col = mix(C("cdbf9c"), C("8a7a60"), fbm(x, y, z, 12.0, 3)[:, None] * 1.1)
    return col * (0.8 + 0.2 * smooth(0.8, 1.05, z))[:, None]


def p_drum(p, n, c):
    f = c["f"]
    ao, cv = form(f, p, n, (0.008, 0.02, 0.05), 1.0)
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    ang = np.arctan2(z - 0.5, y) / 6.283 * 16
    seam = smooth(0.1, 0.03, np.abs((ang + 0.5) % 1.0 - 0.5))
    col = wood_col(p, (0.3, 2.0, 2.0)) * (1.0 + 0.1)
    col = mix(col, C("1e140e"), seam * 0.9)
    return shade(col, ao, cv * 0.5, n, 0.5, 0.3, (0.6, 0.6, 0.7))


def p_door(p, n, c):
    f = c["f"]
    ao, cv = form(f, p, n, (0.006, 0.018, 0.045), 1.0)
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    lab = f.label(p)
    px = (x + 0.46) / 0.11
    pid = np.floor(px)
    seam = smooth(0.06, 0.02, np.abs(px - np.round(px)))
    col = wood_col(p, (2.5, 2.5, 0.28))
    col = col * (0.85 + 0.3 * vnoise(pid * 7.3, pid * 2.1, pid * 0.7, 1.0))[:, None]
    col = mix(col, C("1e140e"), seam * 0.9)
    st = C("8d887e") * (0.8 + 0.4 * vnoise(x * 3.0, y, z * 0.7, 110.0))[:, None]
    col = np.where((lab == 4)[:, None], st, col)
    return shade(col, ao, cv * 1.0, n, 0.85, 0.7, (0.6, 0.58, 0.66))


def p_fish(p, n, c):
    f = c["f"]
    ao, cv = form(f, p, n, (0.004, 0.012, 0.03), 1.5)
    lab = f.label(p)
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    col = mix(C("52c8ac"), C("237a78"), smooth(-0.03, 0.05, z - 0.98)[:, None])
    col = mix(col, C("9ff0d2"), smooth(0.6, 0.8, fbm(x, y, z, 60.0, 2)) * 0.4)
    col = shade(col, ao, cv * 0.7, n, 0.7, 0.5, (0.45, 0.6, 0.65))
    col = np.where((lab == 2)[:, None], C("24101c") * ones(p), col)
    col = np.where((lab == 3)[:, None], C("f2ead2") * ones(p), col)
    return np.where((lab == 4)[:, None], C("f0fff0") * ones(p), col)


def p_lure(p, n, c):
    return C("d8fff4") * ones(p)


def p_rope(p, n, c):
    a = c["aux"]
    col = mix(C("b89c6c"), C("6e583a"), (0.5 + 0.5 * np.sin((a[:, 0] * 210.0 + a[:, 1] * 6.283 * 2.0)))[:, None] ** 3)
    return col * (0.72 + 0.4 * (0.5 + 0.5 * np.sin(a[:, 1] * 6.283 + 1.0))[:, None])


TABLE = {"hull": p_hull, "limb": p_limb, "mast": p_mast, "iron": p_iron, "brass": p_brass, "compass": p_compass, "moss": p_moss,
         "sail": p_sail, "drum": p_drum, "door": p_door, "fish": p_fish, "lure": p_lure, "rope": p_rope}


def paint(name, p, n, ctx):
    return np.clip(TABLE[name](p, n, ctx), 0, 1)
