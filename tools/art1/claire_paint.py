"""ART-1 Claire: the texel-space paint for the rebuilt pieces (recipe: paintkit.py): arrays of texels (world position, normal, occlusion) to sRGB in 0..1."""
import numpy as np
from meshkit import norm, smooth
from paintkit import hexc, mix, fbm, lit, ramp
import claire_pieces as K

HOT = np.array([1.0, 0.76, 0.44])        # hero_toon's glow key: these texels glow in the archetype's model_glow colours
ICE = [hexc("#3f7fc4"), hexc("#6aa8e4"), hexc("#9cd0f6"), hexc("#c9ecff"), hexc("#f0fbff")]
RIBBON = [hexc("#4a8fd6"), hexc("#74b1ea"), hexc("#9dcdf5"), hexc("#c0e2fb"), hexc("#e4f4ff")]
GLOVE = [hexc("#8ea4c8"), hexc("#adc2de"), hexc("#c7d7ea"), hexc("#dbe6f2"), hexc("#ecf3fa")]
FUR = [hexc("#7f9cc4"), hexc("#a4bfe0"), hexc("#bdd3ec"), hexc("#d2e2f4"), hexc("#e6f0fa")]
PINK = hexc("#f2b2c0")
HAIR = [hexc("#9db4dc"), hexc("#bcd0ec"), hexc("#d3e2f5"), hexc("#e6effa"), hexc("#f6faff")]
# the head sheet's face, in its own pixels (2752 wide), against the sculpt: (metres off the eye line, sheet row), (metres off the centre, sheet px)
SHEET_Z = ([-0.13, -0.11, -0.067, -0.046, 0.0, 0.025, 0.07, 0.115, 0.14], [870.0, 840.0, 784.0, 757.5, 692.0, 647.0, 604.0, 562.0, 540.0])
SHEET_X = ([0.0, 0.036, 0.11, 0.13], [0.0, 63.7, 145.0, 165.0])


def sheet_xy(x, z):
    sx = 322.7 + np.sign(x) * np.interp(np.abs(x), *SHEET_X)
    sy = np.interp(z, *SHEET_Z)
    return sx, sy


def load_sheet(path):
    import bpy
    im = bpy.data.images.load(path)
    w, h = im.size
    a = np.zeros(w * h * im.channels, np.float32)
    im.pixels.foreach_get(a)
    return a.reshape(h, w, im.channels)[::-1, :, :3]


def sample_sheet(a, x, y):
    x0, y0 = np.clip(np.floor(x).astype(int), 0, a.shape[1] - 2), np.clip(np.floor(y).astype(int), 0, a.shape[0] - 2)
    fx, fy = (x - x0)[:, None], (y - y0)[:, None]
    c = (a[y0, x0] * (1 - fx) + a[y0, x0 + 1] * fx) * (1 - fy) + (a[y0 + 1, x0] * (1 - fx) + a[y0 + 1, x0 + 1] * fx) * fy
    # (the toon pass adds its own contrast and warmth on top of a painted sheet: lifted and calmed so her skin stays the sheet's pale)
    lum = c.mean(1, keepdims=True)
    c = lum + (c - lum) * 0.72
    c = np.clip(np.power(np.clip(c, 0, 1), 0.74) * np.array([0.99, 1.0, 1.04]), 0, 1)
    # (white fur and pale hair sit on the skin slot here, and its warm light turns them cream: cooled ahead of it)
    cool = smooth(0.62, 0.75, c.mean(1)) * smooth(0.06, 0.0, c[:, 0] - c[:, 2])
    return c * (1 - cool[:, None]) + c * np.array([0.84, 0.93, 1.06]) * cool[:, None]


def path_u(p, path):
    """-> (u 0..1 along the polyline, distance from it, signed side vector)."""
    path = np.asarray(path)
    a, b = path[:-1], path[1:]
    best = np.full(len(p), 9e9)
    us = np.zeros(len(p))
    n = len(a)
    for i in range(n):
        ab = b[i] - a[i]
        t = np.clip((p - a[i]) @ ab / (ab @ ab), 0, 1)
        d = np.linalg.norm(p - (a[i] + t[:, None] * ab), axis=1)
        m = d < best
        best[m] = d[m]
        us[m] = (i + t[m]) / n
    return us, best


def glove(p, n, ao):
    return ramp(np.clip(lit(n, ao) * 1.08 + 0.1, 0, 1), GLOVE)


def ear(p, n, ao, path, s):
    """White fur outside, the shell-pink hollow on her side of it; a soft fur rim."""
    u, d = path_u(p, path)
    c = ramp(np.clip(lit(n, ao) * 1.1 + 0.1 + (fbm(p * 70) - 0.5) * 0.14, 0, 1), FUR)
    front = smooth(0.1, 0.5, n[:, 1])
    rim = smooth(0.045, 0.028, np.abs(p[:, 0] - np.interp(u, np.linspace(0, 1, len(path)), np.asarray(path)[:, 0])))
    tipfade = smooth(0.08, 0.2, u) * smooth(0.98, 0.86, u)
    return mix(c, PINK * (0.72 + 0.34 * np.clip(ao, 0, 1))[:, None], front * rim * tipfade * 0.92)


def horn(p, n, ao, path):
    u, d = path_u(p, path)
    t = lit(n, ao) * 1.05 + 0.08
    band = np.abs(np.sin(u * 24))              # the plates' seams
    c = ramp(np.clip(t * 0.86 + 0.06 + 0.12 * smooth(0.3, 1.0, u), 0, 1), ICE)
    c = mix(c, hexc("#2f6fb8"), smooth(0.14, 0.04, band) * 0.55)
    return mix(c, hexc("#eefbff"), smooth(0.55, 0.9, np.abs(n[:, 2])) * 0.35)


def wing(p, n, ao, tips, wrist):
    """Ice membrane: pale at the scallops, deeper near the arm, faint frost veins; a touch of lilac."""
    d = np.linalg.norm(p - wrist, axis=1)
    t = smooth(0.05, 0.3, d)
    c = mix(hexc("#7fb6ec"), hexc("#d5f0ff"), t)
    c = mix(c, hexc("#c9c4f4"), smooth(0.45, 0.8, fbm(p * 8.0)) * 0.3)
    v = fbm(p * 34.0)
    c = mix(c, hexc("#f4fdff"), smooth(0.015, 0.0, np.abs(v - 0.5)) * 0.45)
    return c * (0.8 + 0.25 * np.clip(ao, 0, 1))[:, None]


def wingarm(p, n, ao):
    return ramp(np.clip(lit(n, ao) * 1.1, 0, 1), ICE)


def tail(p, n, ao, path):
    u, d = path_u(p, path)
    c = ramp(np.clip(lit(n, ao) * 1.0 + 0.2 * u, 0, 1), RIBBON)
    return c


def heart(p, n, ao, c0, size):
    d = np.linalg.norm(p - c0, axis=1) / size
    c = mix(hexc("#e8fbff"), hexc("#7cc8ff"), smooth(0.1, 1.0, d))
    k = np.abs(np.sin(p[:, 0] * 90 + p[:, 2] * 70))
    return mix(c, hexc("#f6feff"), smooth(0.9, 1.0, k) * 0.5)


def ribbon(p, n, ao):
    t = lit(n, ao) * 1.05 + 0.1
    sheen = np.clip(np.sin(p[:, 0] * 38 + p[:, 2] * 19), 0, 1) ** 2 * 0.1
    return ramp(np.clip(t + sheen, 0, 1), RIBBON)


def blade(p, n, ao):
    c = mix(hexc("#74d0ff"), hexc("#f2fdff"), smooth(0.075, 0.0, p[:, 2]))
    streak = np.abs(np.sin(p[:, 1] * 80 + p[:, 2] * 240))
    return mix(c, hexc("#ffffff"), smooth(0.85, 1.0, streak) * 0.6)


def spear_u(p):
    """-> (u along the shaft, angle round it, across the flat) in the rest pose."""
    q = p - K.GRIP_AT
    return q[:, 1], np.arctan2(q[:, 0], q[:, 2]), q[:, 2]


def shaft(p, n, ao):
    """The master's candy cane: white and pale blue spiralling."""
    u, a, _ = spear_u(p)
    w = ((u * 7.5 + a / (2 * np.pi)) % 1.0)
    st = smooth(0.46, 0.5, w) * smooth(1.0, 0.96, w)
    c = mix(hexc("#ffffff"), hexc("#84c4f4"), st)
    return c * (0.76 + 0.3 * lit(n, ao))[:, None]


def crystal(p, n, ao):
    u, a, w = spear_u(p)
    t = np.clip(0.55 + 0.45 * np.abs(n[:, 2]) * 0.8 + (0.5 - np.abs(w) * 10) * 0.3, 0, 1)
    return ramp(t, ICE)


def collar(p, n, ao):
    return ramp(np.clip(lit(n, ao) * 1.2 + 0.05, 0, 1), [hexc("#6d86ac"), hexc("#9fb7d4"), hexc("#d2e0ee"), hexc("#eef5fb"), hexc("#ffffff")])


def lid(p, n, ao, skin, liner_fn):
    c = skin * (0.86 + 0.16 * np.clip(ao, 0, 1))[:, None]
    return mix(c, hexc("#2b3c63"), liner_fn(p))
