"""ART-1 Claire: the texel-space paint for the rebuilt pieces (recipe: kael_paint.py): arrays of texels (world position, normal, occlusion) to sRGB in 0..1."""
import numpy as np
from meshkit import norm, smooth
from kael_paint import hexc, mix, fbm, lit, ramp
import claire_pieces as K

HOT = np.array([1.0, 0.76, 0.44])        # hero_toon's glow key: these texels glow in the archetype's model_glow colours
ICE = [hexc("#3f7fc4"), hexc("#6aa8e4"), hexc("#9cd0f6"), hexc("#c9ecff"), hexc("#f0fbff")]
RIBBON = [hexc("#4a8fd6"), hexc("#74b1ea"), hexc("#9dcdf5"), hexc("#c0e2fb"), hexc("#e4f4ff")]
GLOVE = [hexc("#9fb2d2"), hexc("#c3d2e8"), hexc("#dfe8f5"), hexc("#f1f5fb"), hexc("#ffffff")]
FUR = [hexc("#8fa6c8"), hexc("#bfd0e6"), hexc("#dfe9f5"), hexc("#f3f7fc"), hexc("#ffffff")]
PINK = hexc("#f2b2c0")


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
    band = 0.5 + 0.5 * np.sin(u * 62)
    c = ramp(np.clip(t + (band - 0.5) * 0.2 + 0.18 * smooth(0.3, 1.0, u), 0, 1), ICE)
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
