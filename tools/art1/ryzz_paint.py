"""ART-1 Sparkle: texel-space paint (display values). Art colours sampled off ryzz_FINAL_sheet."""
import numpy as np
from meshkit import smooth, norm
from kael_paint import hexc, ramp, fbm


def mix(a, b, t):
    """t is a scalar or already has its colour axis (kael_paint.mix adds one itself: two make an n x n array)."""
    return a * (1 - t) + b * t

KEY = np.array([1.0, 0.0, 1.0])          # the neon: warden_look paint_glow lights this colour; pure magenta, nothing in the art is near it
SKIN = [hexc("#b9735f"), hexc("#dd9c84"), hexc("#f2bda6"), hexc("#fcd8c4")]
COPPER = [hexc("#7a3e20"), hexc("#c87a44"), hexc("#eda56c"), hexc("#ffd6a8")]
LEATHER_C = [hexc("#6a3a1e"), hexc("#a9683a"), hexc("#d39a62")]


def shade(n, ao):
    l = np.clip(0.5 + 0.34 * n[..., 2] + 0.18 * n[..., 1], 0, 1)
    return np.clip(l * 0.75 + 0.25 * np.clip(ao, 0, 1), 0, 1)


def skin(p, n, ao):
    return ramp(shade(n, ao) * 0.9 + 0.1, SKIN)


def lid(p, n, ao, s, c, ang, eye_z, eye_h):
    """Painted as it lies closed: a soft pink-violet shadow, a dark lash line along the bottom; the scar across her left lid (v2 art)."""
    ca, sa = np.cos(-ang), np.sin(-ang)
    d = p - c
    q = np.stack([d[..., 0], d[..., 1] * ca - d[..., 2] * sa, d[..., 1] * sa + d[..., 2] * ca], -1) + c
    col = mix(skin(p, n, np.maximum(ao, 0.7)), hexc("#c27ab8"), 0.55)
    t = (q[..., 2] - (eye_z - eye_h)) / (2 * eye_h)
    col = mix(col, hexc("#1c1020"), smooth(0.2, 0.1, t)[..., None])
    if s < 0:
        col = mix(col, hexc("#a8327e"), smooth(0.0035, 0.0015, np.abs(q[..., 0] - c[0] + 0.004 - 0.25 * (q[..., 2] - eye_z)))[..., None])
    return col


def eye(a, b):
    """The eye tile: a, b are the angles round the eyeball. Bright blue, as the sheet."""
    r = np.sqrt(a * a + b * b)
    c = np.ones(a.shape + (3,)) * hexc("#f3efea")
    iris = ramp(np.clip(1 - r / 0.52 + 0.25 * np.sin(np.arctan2(b, a) * 14) * 0.25, 0, 1), [hexc("#1c4f95"), hexc("#2f8ad8"), hexc("#7fd0f5")])
    c = mix(c, iris, smooth(0.53, 0.49, r)[..., None])
    c = mix(c, hexc("#0e1320"), smooth(0.24, 0.20, r)[..., None])
    c = mix(c, hexc("#ffffff"), smooth(0.11, 0.07, np.hypot(a - 0.14, b - 0.17))[..., None])
    return c


def hair_tile(h, w):
    """Across: 4 strips of strands. Up: blue, through violet-pink, to hot pink."""
    v = (np.arange(h) + 0.5)[:, None] / h * np.ones((1, w))
    u = (np.arange(w) + 0.5)[None, :] / w * np.ones((h, 1))
    t = np.clip(v, 0, 1)
    c = ramp(smooth(0.30, 0.62, t + 0.05 * np.sin(u * 37.0)), [hexc("#5aa2dc"), hexc("#a884d6"), hexc("#f33fa8"), hexc("#ff5fb9")])
    st = 0.5 + 0.5 * np.sin(u * 2 * np.pi * 26 + 3.0 * np.sin(v * 9.0))
    st2 = 0.5 + 0.5 * np.sin(u * 2 * np.pi * 61 + 1.3)
    k = 0.72 + 0.26 * st + 0.12 * st2
    edge = np.minimum((u * 4) % 1, 1 - (u * 4) % 1)
    k *= 0.72 + 0.28 * smooth(0.0, 0.2, edge)
    c = c * k[..., None]
    return np.clip(c + 0.09 * smooth(0.82, 1.0, st)[..., None], 0, 1)


def copper_tile(h, w):
    u = (np.arange(w) + 0.5)[None, :] / w * np.ones((h, 1))
    t = 0.5 + 0.5 * np.sin(u * 2 * np.pi)
    return ramp(t, COPPER)


def harness(p, n, ao, rivets, bolt):
    """The v2 pack: polished copper, rivets, and the pink bolt on its face (the glow key)."""
    t = shade(n, ao)
    c = ramp(t * 0.75 + 0.05 + 0.08 * fbm(p * 40.0, 3), COPPER)
    for r in rivets:
        d = np.linalg.norm(p - r, axis=-1)
        c = mix(c, hexc("#ffd6a8"), smooth(0.0085, 0.0065, d)[..., None])
    lit = inside(PACK_BOLT, p[..., 0] - bolt[0], p[..., 2] - bolt[1]) & (n[..., 1] < -0.5)
    return mix(c, KEY, lit[..., None] * 1.0)


PACK_BOLT = np.array([(0.02, 0.068), (-0.027, -0.007), (0.002, -0.007), (-0.02, -0.068), (0.029, 0.01), (0.0, 0.01)])     # m, x then z (a third of the pack's height)


def inside(poly, x, z):
    """Even-odd test of the points (x, z) against a closed polygon."""
    k = np.zeros(x.shape, bool)
    for (x0, z0), (x1, z1) in zip(poly, np.roll(poly, -1, 0)):
        c = (z0 > z) != (z1 > z)
        k ^= c & (x < x0 + (z - z0) * (x1 - x0) / (z1 - z0 + 1e-12))
    return k


def gum(p, n, ao, c0):
    d = p - c0
    u = norm(d)
    t = np.clip(0.55 + 0.4 * u[..., 2], 0, 1)
    c = ramp(t, [hexc("#e769bf"), hexc("#f59ad6"), hexc("#fcc7ea")])
    return mix(c, hexc("#ffffff"), smooth(0.86, 0.95, (u @ norm(np.array([-0.45, 0.5, 0.74]))))[..., None] * 0.9)


def glove(p, n, ao):
    c = ramp(shade(n, ao), [hexc("#16121a"), hexc("#2c2733"), hexc("#4a4452")])
    return c


def nail(c, p, tip, d, col):
    k = smooth(0.0115, 0.0085, np.linalg.norm(p - tip + d * 0.002, axis=-1))
    return mix(c, hexc(col), k[..., None])
