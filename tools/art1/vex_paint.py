"""ART-1 Vex v2: the texel-space paint of the rebuilt pieces (see paintkit.py): arrays of texels in, sRGB out."""
import os, sys
import numpy as np
from meshkit import smooth
from paintkit import hexc, fbm, lit, ramp
import vex_cannon as VC
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "meshy"))
import imgio

STEEL = [hexc("#222329"), hexc("#3f4148"), hexc("#61636c"), hexc("#868992"), hexc("#b0b3ba")]
BLACKM = [hexc("#141417"), hexc("#26262b"), hexc("#3b3b42"), hexc("#585862"), hexc("#7a7a86")]
BRASS = [hexc("#3d2a14"), hexc("#6e4c26"), hexc("#a07842"), hexc("#c9a266"), hexc("#ead3a2")]    # the sheet's worn brass
# the gun's stickers (the sheet): (s, angle round the axis from outward toward the top, the axis's u, f; half size along s, half size
# round, colour, the lower half's colour)
STICKERS = [(0.055, 0.75, 0.0, 0.0, 0.022, 0.024, hexc("#79d6bf"), hexc("#79d6bf")),
            (0.19, 0.25, 0.0, 0.0, 0.02, 0.02, hexc("#b357d6"), hexc("#b357d6")),
            (0.18, -0.2, 0.0, VC.DRUM_F, 0.026, 0.03, hexc("#ef8b3b"), hexc("#3a6fd8"))]


def scs(p):
    """World rest -> cannon space (s, u, f)."""
    E = VC.E
    return -(p[..., 2] - E[2]), p[..., 0] - E[0] - VC.OUT, p[..., 1] - E[1]


def scuff(p, c):
    n = fbm(p * 55 + 3.0)
    edge = smooth(0.58, 0.72, n)
    return c * (1 - 0.18 * edge[..., None])


def steel(p, n, ao, cols=STEEL):
    return scuff(p, ramp(np.clip(lit(n, ao) * 1.05 + (fbm(p * 30) - .5) * .18, 0, 1), cols))


def brass(p, n, ao):
    return scuff(p, ramp(np.clip(lit(n, ao) * 1.08 + (fbm(p * 24) - .5) * .16, 0, 1), BRASS))


def gun_brass(p, n, ao):
    """The cuff, receiver and drum: brass with the sheet's three stickers (teal on the cuff, purple on the receiver's side, orange
    and blue on the drum), each with a dark edge."""
    c = brass(p, n, ao)
    s, u, f = scs(p)
    for s0, a0, cu, cf, hs_, ha, top, low in STICKERS:
        a = np.arctan2(f - cf, u - cu)
        r = np.hypot(u - cu, f - cf)
        d = np.maximum(np.abs(s - s0) / hs_, np.abs((a - a0) * r) / ha)
        on = d < 1.0
        k = np.where((a > a0)[..., None], top, low)
        lt = np.clip(lit(n, ao) * 1.1, 0.35, 1.05)[..., None]
        c = np.where(on[..., None], k * lt, c)
        c = np.where(((d > 0.86) & on)[..., None], hexc("#2a1d14") + 0 * c, c)
    return c


def belt_tile(h, w):
    """The ribbed belt loop: u round the link (1 lit crest .. 0 edge), v along it; worn tan-brass links, a dark gap between."""
    v, u = np.mgrid[0:h, 0:w]
    u, v = (u + .5) / w, (v + .5) / h
    shade = np.clip(0.25 + 0.8 * u ** 1.2, 0, 1)
    c = ramp(shade, [hexc("#4d3a22"), hexc("#8a6a42"), hexc("#b8956a"), hexc("#dcc29a"), hexc("#f2e2c4")])
    return np.where((v < 0.12)[..., None], ramp(shade * .5, BLACKM), c)


def hair_tile(h, w):
    v, u = np.mgrid[0:h, 0:w]
    u, v = (u + 0.5) / w, (v + 0.5) / h
    warp = (fbm(np.stack([u * 5, v * 2.0, u * 0 + 2.0], -1)) - 0.5) * 0.09
    st = np.abs(np.sin((u + warp) * np.pi * 15))
    fine = np.abs(np.sin((u + warp * 1.4) * np.pi * 43))
    t = 0.40 + 0.44 * smooth(0.05, 0.75, st) + 0.16 * (fine - 0.5)
    t -= 0.34 * (1 - smooth(0.0, 0.2, v))
    t += 0.2 * np.exp(-((v - 0.38 - warp) / 0.12) ** 2)
    t *= 1 - 0.26 * (np.abs(((u * 4) % 1) * 2 - 1) ** 5)
    return ramp(np.clip(t, 0, 1), [hexc("#1d3a33"), hexc("#2f5a4d"), hexc("#4a7d68"), hexc("#74a58b"), hexc("#b6d8c0")])


SKIN_R = [hexc("#8a5560"), hexc("#b87a7c"), hexc("#d69a96"), hexc("#ebbcae"), hexc("#fad8c8")]


def clean_skin(col, m, blur):
    """The body scan's skin, warm and calm: its mottling halved (a blend with a blurred copy), then its light put on a warm ramp. Only
    skin-coloured texels: the bandeau, the strap, the tattoos and freckles (dark) keep the scan's paint."""
    m = m & (col[..., 0] > col[..., 1] * 1.03) & (col.mean(-1) > 0.3)
    mf = m.astype(np.float32)
    l = col.mean(-1)
    l = 0.5 * l + 0.5 * blur(l, mf, 8)
    t = np.clip(0.18 + (l - 0.3) * 1.3, 0.1, 0.92)
    return np.where(m[..., None], ramp(t, SKIN_R).astype(np.float32), col)
