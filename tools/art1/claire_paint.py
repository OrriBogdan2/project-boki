"""ART-1 Claire: the texel-space paint for the rebuilt pieces (recipe: kael_paint.py): arrays of texels (world position, normal, occlusion) to sRGB in 0..1."""
import numpy as np
from meshkit import norm, smooth
from kael_paint import hexc, mix, fbm, lit, ramp
import claire_pieces as K

HOT = np.array([1.0, 0.76, 0.44])        # hero_toon's glow key: these texels glow in the archetype's model_glow colours
ICE = [hexc("#3f7fc4"), hexc("#6aa8e4"), hexc("#9cd0f6"), hexc("#c9ecff"), hexc("#f0fbff")]
GLOVE = [hexc("#7e6fb4"), hexc("#9a8bcc"), hexc("#b5a8df"), hexc("#cdc3ec"), hexc("#e4ddf6")]       # the sheet's lilac gloves
FUR = [hexc("#7f9cc4"), hexc("#a4bfe0"), hexc("#bdd3ec"), hexc("#d2e2f4"), hexc("#e6f0fa")]
PINK = hexc("#f2b2c0")
HAIR = [hexc("#9db4dc"), hexc("#bcd0ec"), hexc("#d3e2f5"), hexc("#e6effa"), hexc("#f6faff")]
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


def ear(p, n, ao, path, wd):
    """White fur outside, the shell-pink hollow on her front side of it, a soft fur rim; the tips frosted ice blue."""
    u, d = path_u(p, path)
    w = np.interp(u, np.linspace(0, 1, len(wd)), wd)
    c = ramp(np.clip(lit(n, ao) * 1.1 + 0.1 + (fbm(p * 70) - 0.5) * 0.14, 0, 1), FUR)
    front = smooth(0.05, 0.45, n[:, 1])
    rim = smooth(0.8, 0.55, d / np.maximum(w, 1e-3))
    tipfade = smooth(0.04, 0.16, u) * smooth(0.9, 0.78, u)
    c = mix(c, PINK * (0.72 + 0.34 * np.clip(ao, 0, 1))[:, None], front * rim * tipfade * 0.92)
    return mix(c, ICE[3], smooth(0.8, 0.97, u) * 0.75)


def puff(p, n, ao, c0):
    """The tail: white fluff, a cool shade under it."""
    t = np.clip(lit(n, ao) * 1.05 + 0.15 + (fbm(p * 90) - 0.5) * 0.2, 0, 1)
    return ramp(t, FUR)


def braid(p, n, ao, path):
    """The plait: white at the top fading to the sheet's icy blue, a crossing strand shadow every lobe."""
    u, d = path_u(p, path)
    c = ramp(np.clip(lit(n, ao) * 0.9 + 0.12, 0, 1), HAIR)
    c = mix(c, ramp(np.clip(lit(n, ao) * 0.9 + 0.1, 0, 1), ICE[1:]), smooth(0.45, 0.95, u))
    k = np.abs(np.sin(u * np.pi * 11 + (p[:, 0] - path[0][0]) * 40))
    return c * (0.8 + 0.2 * smooth(0.05, 0.35, k))[:, None]


def flake(p, n, ao):
    return mix(hexc("#9fdcff"), hexc("#f4fdff"), smooth(0.2, 0.9, np.clip(np.abs(n[:, 1]), 0, 1)))


def heart(p, n, ao, c0, size):
    d = np.linalg.norm(p - c0, axis=1) / size
    c = mix(hexc("#e8fbff"), hexc("#7cc8ff"), smooth(0.1, 1.0, d))
    k = np.abs(np.sin(p[:, 0] * 90 + p[:, 2] * 70))
    return mix(c, hexc("#f6feff"), smooth(0.9, 1.0, k) * 0.5)


def blade(p, n, ao):
    c = mix(hexc("#74d0ff"), hexc("#f2fdff"), smooth(0.075, 0.0, p[:, 2]))
    streak = np.abs(np.sin(p[:, 1] * 80 + p[:, 2] * 240))
    return mix(c, hexc("#ffffff"), smooth(0.85, 1.0, streak) * 0.6)


def spear_u(p):
    """-> (u along the shaft, angle round it, across the flat) in the rest pose."""
    q = p - K.GRIP_AT
    return q[:, 1], np.arctan2(q[:, 0], q[:, 2]), q[:, 2]


def shaft(p, n, ao):
    """The sheet's candy cane: white and lavender spiralling, thin stripes."""
    u, a, _ = spear_u(p)
    w = ((u * 12.0 + a / (2 * np.pi)) % 1.0)
    st = smooth(0.46, 0.5, w) * smooth(1.0, 0.96, w)
    c = mix(hexc("#f6f2fb"), hexc("#9f86cf"), st)
    return c * (0.76 + 0.3 * lit(n, ao))[:, None]


def lace(p, n, ao):
    """The skate laces: candy-cane red and white twisting stripes (the sheet), along the lace's own run."""
    w = ((p[:, 2] * 150 + p[:, 0] * 110 * np.sign(p[:, 0])) % 1.0)
    c = mix(hexc("#fbf3f3"), hexc("#d93c4f"), smooth(0.42, 0.5, w) * smooth(1.0, 0.92, w))
    return c * (0.8 + 0.25 * lit(n, ao))[:, None]


def puff_cuff(p, n, ao):
    """The boot's fur cuff: white fluff with tufts shaded cool, like the tail puff."""
    t = np.clip(lit(n, ao) * 1.0 + 0.2 + (fbm(p * 110) - 0.5) * 0.3, 0, 1)
    return ramp(t, FUR)


def crystal(p, n, ao):
    u, a, w = spear_u(p)
    t = np.clip(0.55 + 0.45 * np.abs(n[:, 2]) * 0.8 + (0.5 - np.abs(w) * 10) * 0.3, 0, 1)
    return ramp(t, ICE)


def collar(p, n, ao):
    return ramp(np.clip(lit(n, ao) * 1.2 + 0.05, 0, 1), [hexc("#6d86ac"), hexc("#9fb7d4"), hexc("#d2e0ee"), hexc("#eef5fb"), hexc("#ffffff")])


def lid(p, n, ao, skin, liner_fn):
    c = skin * (0.86 + 0.16 * np.clip(ao, 0, 1))[:, None]
    return mix(c, hexc("#2b3c63"), liner_fn(p))
