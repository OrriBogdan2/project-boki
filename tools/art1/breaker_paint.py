"""Breaker's paint (ART-1): colour per texel on the sculpt's own surface. The toon shader adds soft light on top, so
the sculpt's form, cavities and frost are painted in, the way the concept art is."""
import os

import imgio
import numpy as np

import breaker_sculpt as B
import sculpt_kit as S
from sculpt_kit import fbm, smooth, vnoise, worley

F32 = np.float32
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
    col = mix(C("6a8a30"), C("33501e"), fbm(x, y, z, 26.0, 3)[:, None] * 1.3)
    col = mix(col, C("93ad42"), smooth(0.62, 0.8, fbm(x + 1, y, z, 44.0, 2)) * 0.5)
    return shade(col, ao, cv * 0.7, n, 0.6, 0.3, (0.45, 0.6, 0.55))


def p_sail(p, n, c):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    col = mix(C("e8e0d2"), C("a89c8a"), fbm(x, y, z, 12.0, 3)[:, None] * 1.1)     # mossy_v2: off-white torn cloth
    return col * (0.8 + 0.2 * smooth(0.8, 1.05, z))[:, None]


def p_drum(p, n, c):
    f = c["f"]
    ao, cv = form(f, p, n, (0.008, 0.02, 0.05), 1.0)
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    ang = np.arctan2(z - 0.54, y) / 6.283 * 16
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
    col = wood_col(p, (2.5, 2.5, 0.28)) * 0.82
    col = col * (0.85 + 0.3 * vnoise(pid * 7.3, pid * 2.1, pid * 0.7, 1.0))[:, None]
    col = mix(col, C("1e140e"), seam * 0.9)
    col = shade(col, ao, cv * 0.8, n, 0.75, 0.5, (0.6, 0.58, 0.66))
    # the carved woman: pale weathered stone, with her face drawn in
    st = C("c4beb2") * (0.92 + 0.14 * fbm(x, y, z, 18.0, 2))[:, None]
    fz = z - (0.28 + 0.405)
    ax = np.abs(x)
    eyes = smooth(0.0045, 0.002, np.abs(fz - 0.012 + 40 * (ax - 0.024) ** 2)) * (ax < 0.044) * (ax > 0.008)
    brow = smooth(0.0035, 0.0015, np.abs(fz - 0.03 + 30 * (ax - 0.024) ** 2)) * (ax < 0.048) * (ax > 0.006)
    nose = smooth(0.0035, 0.0015, ax - 0.002 - 0.09 * (fz + 0.02)) * (fz < 0.01) * (fz > -0.022)
    lips = smooth(0.0045, 0.002, np.abs(fz + 0.04 - 60 * ax ** 2)) * (ax < 0.02)
    st = mix(st, C("4a4640"), np.maximum.reduce([eyes, brow * 0.7, nose * 0.5, lips]))
    hair = 0.5 + 0.5 * np.sin(x * 240.0 + np.sin(z * 9.0) * 3.0)
    st = st * (0.86 + 0.2 * (hair * (np.abs(fz) > 0.08) * (z > 0.45))[:, None])
    fig = st * (0.72 + 0.28 * smooth(0.2, 0.8, ao) + 0.12 * n[:, 2])[:, None]      # (flat: the mesh is too coarse to shade her face)
    # (her silhouette seen face-on, so no wood shows through her hair)
    sil = f.fig.d.min(axis=1)
    q = np.rint((p - f.fig.lo) / f.fig.vox).astype(int)
    near = sil[np.clip(q[:, 0], 0, sil.shape[0] - 1), np.clip(q[:, 2], 0, sil.shape[1] - 1)]
    return np.where((near < 0.006)[:, None], fig, col)


def p_fish(p, n, c):
    f = c["f"]
    ao, cv = form(f, p, n, (0.004, 0.012, 0.03), 1.5)
    lab = f.label(p)
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    col = mix(C("d98a4a"), C("8f3d22"), smooth(-0.03, 0.05, z - 0.98)[:, None])     # mossy_v2: a rust-orange angler
    col = mix(col, C("5a2414"), smooth(0.6, 0.8, fbm(x, y, z, 60.0, 2)) * 0.4)
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


# ---- the art projected (FINE-DETAIL): model points -> pixels of the turnaround, the weapon and head sheets. Coordinates are read off
# mossy_v2_turnaround (the body, read at 1600 wide) and breaker_weapons (the shield, 1500 wide), scaled at load.
REFS = os.environ.get("BOKI_ART_REFS", "/home/boki/briefs-wt/briefs/art-refs")
_art = {}


def art(name):
    if name not in _art:
        path = os.path.join(REFS, name)
        im = imgio.load(path if os.path.splitext(path)[1] else path + ".png")
        # the sheet's pale background is bled over from the figure, so a texel past the drawn edge never paints white
        lo, hi = im.min(2), im.max(2)
        fg = ~((lo > 0.55) & (hi - lo < 0.07))
        _art[name] = S.dilate(im, fg, 90)
    return _art[name]


def sample(name, px, py, w=1500.0):
    """Bilinear, (px, py) in the sheet's coordinates when `w` px wide."""
    im = art(name)
    k = im.shape[1] / w
    x = np.clip(px * k, 0, im.shape[1] - 1.001)
    y = np.clip(py * k, 0, im.shape[0] - 1.001)
    i, j = x.astype(int), y.astype(int)
    u, v = (x - i)[:, None], (y - j)[:, None]
    return (im[j, i] * (1 - u) + im[j, i + 1] * u) * (1 - v) + (im[j + 1, i] * (1 - u) + im[j + 1, i + 1] * u) * v


def hot(col):
    """The art's teal light becomes the toon shader's hot key."""
    m = np.minimum(col[:, 1], col[:, 2]) - col[:, 0] * 1.05
    return mix(col, KEY, smooth(0.2, 0.3, m) * smooth(0.45, 0.6, col[:, 2]))


V2 = "mossy_v2/mossy_v2_turnaround.jpg"     # read at 1600 wide: the front view's centre x 245, the side's 1023, the back's 1355
FC, SC, BC = 245.0, 1023.0, 1355.0
PX = 298.0                                 # px a metre: the helmet's half width, 70 px, is HELM_R[0]


def _views(f, b, sd, n, side_w=1.0):
    out = mix(b, f, smooth(-0.25, 0.25, n[:, 1]))
    return mix(out, sd, smooth(0.5, 0.8, np.abs(n[:, 0]) ** 2) * side_w)


def p_fist(p, n, c):
    """The fists, planar from the front and back views' hands (his right is image left in the front view)."""
    s = float(c["part"]["side"])
    ctr = p.mean(0)
    hw = max(float(np.abs(p[:, 0] - ctr[0]).max()), 0.02)
    hh = max(float(np.abs(p[:, 2] - ctr[2]).max()), 0.02)
    dx, dz = (p[:, 0] - ctr[0]) / hw, (p[:, 2] - ctr[2]) / hh
    py = 625.0 - dz * 38.0
    f = sample(V2, FC - s * 178.0 - dx * 30.0, py, 1600.0)
    b = sample(V2, BC + s * 178.0 + dx * 30.0, py, 1600.0)
    return hot(mix(b, f, smooth(-0.3, 0.3, n[:, 1])))


def p_dial(p, n, c):
    """The compass, round and on its own non-glowing brass surface; the rest of the hull is keyed."""
    q = p - c["part"]["centre"]
    return sample(V2, FC - q[:, 0] / 0.1 * 30.0, 478.0 - q[:, 2] / 0.1 * 30.0, 1600.0)


def p_helmet(p, n, c):
    """The dome from the front, side and back views; the dome's centre at y 325."""
    x, y = p[:, 0], p[:, 1] - B.HELM_C[1]
    py = 325.0 - (p[:, 2] - B.HELM_C[2]) * PX
    f = sample(V2, FC - x * PX, py, 1600.0)
    b = sample(V2, BC + x * PX * 0.8, py, 1600.0)      # (the back view draws the dome a fifth narrower)
    sd = sample(V2, SC + y * PX, py, 1600.0)
    return _views(f, b, sd, n)


def p_collar(p, n, c):
    """The collar, plan-mapped: its band runs y 355..395 in the front view, round the dome's brim (y 332) at the back."""
    x, y = p[:, 0], p[:, 1]
    u = x / 0.34
    r = np.clip(np.sqrt((x / 0.34) ** 2 + (y / 0.3) ** 2), 0, 1)
    f = sample(V2, FC - u * 101.0, 355.0 + (r - 0.7) / 0.3 * 40.0, 1600.0)
    b = sample(V2, BC + u * 101.0, 334.0 + (r - 0.7) / 0.3 * 12.0, 1600.0)
    return mix(b, f, smooth(-0.15, 0.15, y))


def p_door_art(p, n, c):
    """The hatch shield, front and back of breaker_weapons (1500 wide)."""
    x = p[:, 0]
    z = (p[:, 2] - 0.28) / 0.585
    f = sample("breaker_weapons", 935.0 + x / 0.3 * 92.0, 615.0 - z * 180.0)
    b = sample("breaker_weapons", 1340.0 - x / 0.3 * 92.0, 615.0 - z * 180.0)
    return mix(b, f, smooth(0.3, -0.3, n[:, 1]))


TABLE = {"fist": p_fist, "helmet": p_helmet, "collar": p_collar, "dial": p_dial, "mast": p_mast, "iron": p_iron, "brass": p_brass, "compass": p_compass, "moss": p_moss,
         "sail": p_sail, "drum": p_drum, "door": p_door_art, "fish": p_fish, "lure": p_lure, "rope": p_rope}


def key_scan(col):
    """The scan's paint for a keyed material: its teal light on the key, every other warm texel below it."""
    out = hot(col)
    k = np.abs(out - KEY).sum(1) < 0.12
    warm = (out[:, 0] - out[:, 2] > 0.1) & ~k
    out[:, 0] = np.where(warm, np.minimum(out[:, 0], 0.41), out[:, 0])
    return out


def paint(name, p, n, ctx):
    col = np.clip(TABLE[name](p, n, ctx), 0, 1)
    # on a keyed material any bright warm texel glows (hero_toon glow_key): only the real key may stay that bright
    if ctx["part"]["slot"] in ("scan", "wood"):
        key = np.abs(col - KEY).sum(1) < 0.12
        warm = (col[:, 0] - col[:, 2] > 0.1) & ~key
        col[:, 0] = np.where(warm, np.minimum(col[:, 0], 0.41), col[:, 0])
    return col
