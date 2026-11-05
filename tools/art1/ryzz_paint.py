"""ART-1 Ryzz: texel-space paint (display values). Art colours sampled off ryzz_FINAL_sheet."""
import numpy as np
from meshkit import smooth, norm
import ryzz_pieces as K
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


def seg_dist(p, a, b):
    a, b = np.asarray(a), np.asarray(b)
    u = b - a
    h = np.clip(((p - a) @ u) / (u @ u), 0, 1)
    return np.linalg.norm(p - (a + h[..., None] * u), axis=-1)


BOLT = [(0.031, 0.094), (0.045, 0.054), (0.033, 0.047), (0.054, 0.006), (0.040, -0.002), (0.061, -0.052)]


def bolt_d(x, z):
    """Distance to the zig-zag on her right side, head-local; the taper makes it read as a bolt."""
    q = np.stack([x, z], -1)
    d = np.full(x.shape, 9.0)
    for i in range(len(BOLT) - 1):
        wd = 0.0032 + 0.0022 * (1 - abs(i - 2.0) / 2.5)
        d = np.minimum(d, seg_dist(q, BOLT[i], BOLT[i + 1]) - wd)
    return d


def face(p, n, ao):
    q = (p - K.C) / K.HS
    x, y, z = q[..., 0], q[..., 1], q[..., 2]
    c = skin(p, n, np.maximum(ao, 0.55))
    ax = np.abs(x)
    # blush and the warm nose
    c = mix(c, hexc("#ec8d7c"), 0.42 * np.exp(-(((ax - 0.056) / 0.028) ** 2 + ((z + 0.034) / 0.019) ** 2))[..., None])
    c = mix(c, hexc("#e8917d"), 0.3 * np.exp(-((x / 0.014) ** 2 + ((z + 0.034) / 0.012) ** 2))[..., None])
    # freckles
    fr = fbm(p * 900.0, 2)
    c = mix(c, hexc("#b5654e"), (smooth(0.68, 0.72, fr) * np.exp(-(((ax - 0.034) / 0.034) ** 2 + ((z + 0.02) / 0.016) ** 2)) * 0.7)[..., None])
    # eye shadow: pink over the wink, a soft violet on the other
    es = np.exp(-(((ax - K.EYE[0]) / 0.03) ** 2 + ((z - 0.02) / 0.014) ** 2))
    c = mix(c, np.where((x > 0)[..., None], hexc("#f03fa8"), hexc("#a56fd0")), (es * np.where(x > 0, 0.85, 0.55))[..., None])
    # lips
    up = np.exp(-((x / 0.0235) ** 4 + ((z + 0.0605) / 0.0062) ** 2))
    lo = np.exp(-((x / 0.0195) ** 4 + ((z + 0.0725) / 0.0078) ** 2))
    c = mix(c, hexc("#c8405e"), np.clip(up * 1.3, 0, 1)[..., None] * 0.95)
    c = mix(c, hexc("#de5a76"), np.clip(lo * 1.3, 0, 1)[..., None] * 0.95)
    line = np.exp(-(((z + 0.0663 - 0.09 * x * x * 40) / 0.0012) ** 2)) * smooth(0.031, 0.026, ax)
    c = mix(c, hexc("#57202c"), line[..., None])
    # the bolt
    d = bolt_d(x, z)
    c = mix(c, hexc("#ff2fa8"), smooth(0.0028, 0.0, d)[..., None])
    c = mix(c, KEY, smooth(0.0006, -0.0004, d)[..., None])
    return c


def lid(p, n, ao, s, c, ang, eye_z, eye_h):
    """Painted as it lies closed: pink on the wink, a soft violet on the other, a dark lash line along the bottom; the bolt across the wink."""
    ca, sa = np.cos(-ang), np.sin(-ang)
    d = p - c
    q = np.stack([d[..., 0], d[..., 1] * ca - d[..., 2] * sa, d[..., 1] * sa + d[..., 2] * ca], -1) + c
    col = skin(p, n, np.maximum(ao, 0.7))
    col = mix(col, hexc("#f03fa8") if s > 0 else hexc("#b98ad8"), 0.82 if s > 0 else 0.5)
    t = (q[..., 2] - (eye_z - eye_h)) / (2 * eye_h)
    col = mix(col, hexc("#1c1020"), smooth(0.2, 0.1, t)[..., None])
    if s > 0:
        col = mix(col, KEY, smooth(0.0035, 0.0015, np.abs(q[..., 0] - 0.044 - 0.25 * (q[..., 2] - eye_z)))[..., None])
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


def chain_tile(h, w):
    v = (np.arange(h) + 0.5)[:, None] / h * np.ones((1, w))
    t = 0.5 + 0.5 * np.sin(v * 2 * np.pi * 6)
    return ramp(t ** 2, [hexc("#2c130a"), hexc("#a85a2e"), hexc("#f0a56c")])


def harness(p, n, ao, rivets):
    t = shade(n, ao)
    c = ramp(t * 0.9 + 0.2 * fbm(p * 60.0, 3), LEATHER_C)
    for r in rivets:
        d = np.linalg.norm(p - r, axis=-1)
        c = mix(c, hexc("#f3b27a"), smooth(0.0085, 0.0065, d)[..., None])
    return c


def strap(p, n, ao):
    return ramp(shade(n, ao), LEATHER_C)


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


def fishnet(p, sh):
    """The lattice in the thigh's own surface coordinates: two diagonal line families, 26 mm apart, on warm skin."""
    x0 = np.sign(p[..., 0]) * 0.085
    ang = np.arctan2(p[..., 1], p[..., 0] - x0) * 0.078
    a = (ang + p[..., 2]) / 0.026
    b = (ang - p[..., 2]) / 0.026
    fa, fb = np.abs((a % 1) - 0.5), np.abs((b % 1) - 0.5)
    ln = np.maximum(smooth(0.42, 0.47, fa), smooth(0.42, 0.47, fb))
    base = sh * 0.82 + hexc("#6a3a4a") * 0.1
    return mix(base, hexc("#2d1c30"), ln[..., None] * 0.92)
