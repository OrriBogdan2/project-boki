"""ART-1 paint helpers (first written for Kael): texel arrays in, sRGB out."""
import numpy as np
from meshkit import norm, smooth


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def mix(a, b, t):
    t = np.asarray(t)[..., None] if np.ndim(t) else t
    return a * (1 - t) + b * t


def hash3(ix, iy, iz):
    v = (ix * 127 + iy * 311 + iz * 74) & 0xffff
    v = (v * (v * v * 15731 + 789221) + 1376312589) & 0x7fffffff
    return (v % 100003) / 100003.0


def vnoise(p):
    p = np.asarray(p, dtype=np.float64)
    i = np.floor(p).astype(np.int64)
    f = p - i
    u = f * f * (3 - 2 * f)
    out = 0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (u[..., 0] if dx else 1 - u[..., 0]) * (u[..., 1] if dy else 1 - u[..., 1]) * \
                    (u[..., 2] if dz else 1 - u[..., 2])
                out = out + w * hash3(i[..., 0] + dx, i[..., 1] + dy, i[..., 2] + dz)
    return out


def fbm(p, oct=4):
    s, a, t = 0.0, 0.5, 0.0
    for k in range(oct):
        s = s + a * vnoise(p * (2 ** k))
        t += a
        a *= 0.5
    return s / t


L = norm(np.array([-0.35, 0.55, 0.78]))


def lit(n, ao, rim_k=0.25):
    """A painted light: broad top-front key, a hint of bounce, the occlusion multiplied in."""
    d = np.clip(np.sum(n * L, -1), -1, 1)
    key = smooth(-0.35, 0.75, d)
    top = np.clip(n[..., 2], 0, 1)
    return np.clip(ao, 0, 1) ** 1.15 * (0.42 + 0.46 * key + 0.16 * top)


def ramp(t, cols):
    """Colour ramp over 0..1 through evenly spaced stops."""
    c = np.array(cols)
    x = np.clip(t, 0, 0.9999) * (len(c) - 1)
    i = x.astype(int)
    f = (x - i)[..., None]
    return c[i] * (1 - f) + c[i + 1] * f


SKIN = [hexc("#2e1a1c"), hexc("#4f2e28"), hexc("#74463a"), hexc("#99654f"), hexc("#bf8a6a")]
CLOTH = [hexc("#1c070d"), hexc("#340d16"), hexc("#4e1520"), hexc("#68202b"), hexc("#84333a")]
GOLD = [hexc("#5c360c"), hexc("#99621a"), hexc("#c98a2a"), hexc("#e8b24c"), hexc("#ffe08c")]
IRON = [hexc("#1e1b1f"), hexc("#3a363a"), hexc("#5b5659"), hexc("#7f7a7b"), hexc("#b0abaa")]
RUST = hexc("#6a3a24")
