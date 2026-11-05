"""Hem's atlas (ART-1): every texel coloured from the sculpt, by region, with the art's shapes painted in. The toon shader
adds only a soft light, so the paint carries its own form shadow and rim. Palette: crimson, black, porcelain, silver,
red glow (HEM_KIT.md). Each function takes points, normals and the field's labels; colours are sRGB 0..1."""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import hem_sculpt as H
from hem_sdf import fbm, smooth, vnoise, worley

F = np.float32


def rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], F)


C = {"skin": rgb("efcfc4"), "skin_sh": rgb("c98f8c"), "blush": rgb("e39f9c"), "lip": rgb("a81c2a"), "ear": rgb("c98a84"),
     "hair": rgb("17151c"), "hair_hi": rgb("5c5a70"), "hair_dk": rgb("0b0a0f"),
     "porc": rgb("f4f0ea"), "porc_sh": rgb("b6b2c0"), "gold": rgb("e0ae42"), "gold_dk": rgb("8c5e1a"), "thread": rgb("cf1a22"),
     "corset": rgb("26222b"), "corset_hi": rgb("565064"), "seam": rgb("0e0c10"), "trouser": rgb("201d24"), "trouser_hi": rgb("3e3a48"),
     "boot": rgb("2c2422"), "boot_hi": rgb("5e4c44"), "boot_top": rgb("3c302c"), "lace": rgb("8d2028"),
     "jacket": rgb("a8182a"), "jacket_hi": rgb("d83a3e"), "jacket_sh": rgb("5e0c1e"), "jacket_dk": rgb("6c0f22"), "cuff": rgb("1c1a20"),
     "tape": rgb("d9c49c"), "tape_dk": rgb("8b7654"), "leather": rgb("5a3524"), "leather_hi": rgb("8c5c3c"), "buckle": rgb("b9b7bd"),
     "steel": rgb("c5c8d0"), "steel_dk": rgb("5e6270"), "wood": rgb("c49a6c"), "nail": rgb("e6b4ac"),
     "lacquer": rgb("15141a"), "lacquer_hi": rgb("6b6c7c")}


def mix(a, b, t):
    t = np.asarray(t, F)
    if t.ndim == 1:
        t = t[:, None]
    return a * (1 - t) + b * t


def cavity(f, p, n, r=0.008):
    """-1..1: how sunk a point is (the sculpt's own creases, for the paint's dark lines)."""
    d = f.sample((p + n * r).astype(F))
    return np.clip(1.0 - d / r, -1, 1)


def form(n, lo=0.0, hi=1.0):
    """A soft painted light from above and her front right (the art's key)."""
    l = np.array((0.28, 0.42, 0.86), F)
    l /= np.linalg.norm(l)
    return np.clip((n @ l) * 0.5 + 0.5, 0, 1)


def _fabric(p, n, base, hi, sh, cav, sheen=1.0):
    k = form(n)
    c = mix(sh, base, smooth(0.22, 0.62, k))
    c = mix(c, hi, smooth(0.66, 1.0, k) * 0.55 * sheen)
    return c * (1 - 0.55 * smooth(0.25, 0.9, cav))[:, None]


def jacket(p, n, cav, lab):
    fold = fbm(p[:, 0] * 1.2, p[:, 1] * 1.2, p[:, 2] * 0.5, 9.0, 3) - 0.5
    k = np.clip(form(n) + fold * 0.45, 0, 1)
    c = mix(C["jacket_sh"], C["jacket"], smooth(0.2, 0.6, k))
    c = mix(c, C["jacket_hi"], smooth(0.68, 1.0, k) * 0.5)
    c = mix(c, C["jacket_dk"], (lab == H.JACKET_DK) * 0.85)
    return c * (1 - 0.5 * smooth(0.3, 0.9, cav))[:, None]


def corset(p, n, cav, lab):
    c = _fabric(p, n, C["corset"], C["corset_hi"], C["seam"], cav, 1.1)
    # the top edge piped in crimson, a fine stitch by each seam
    edge = np.abs(p[:, 2] - H.neckline(p[:, 0]))
    c = mix(c, C["jacket"], smooth(0.0065, 0.0035, edge))
    a = np.abs(p[:, 0])
    for dx in (0.034, 0.078, 0.116):
        s = smooth(0.0016, 0.0006, np.abs(a - dx - 0.0058)) * (np.sin(p[:, 2] * 820) > 0)
        c = mix(c, C["corset_hi"], s * 0.7 * (p[:, 1] > 0))
    c = mix(c, C["seam"], (lab == H.CORSET_SEAM) * 0.9)
    return c


def boot(p, n, cav, lab):
    c = _fabric(p, n, C["boot"], C["boot_hi"], C["seam"], cav, 1.2)
    c = mix(c, C["boot_top"], (lab == H.BOOT_TOP) * 0.9)
    # the laces up the front: crimson crosses from the toe's root to the cuff
    a = np.abs(np.abs(p[:, 0]) - 0.0924)
    z = p[:, 2]
    front = (n[:, 1] > 0.5) & (z > 0.09) & (z < 0.47)
    v = np.abs(((z * 34.0) % 1.0) - 0.5) * 0.024 + 0.0
    lc = smooth(0.0032, 0.0014, np.abs(a - v)) * front
    c = mix(c, C["lace"], lc)
    return c


def tape(p, n, cav):
    z = p[:, 2] + 0.18 * p[:, 1]
    band = (z * 125.0 / math.pi) % 1.0
    c = mix(C["tape_dk"], C["tape"], smooth(0.02, 0.14, band) * smooth(1.0, 0.86, band))
    # the tape-measure's ticks
    th = np.arctan2(p[:, 1], p[:, 0] - np.sign(p[:, 0]) * 0.1662)
    tk = (th * 11.0) % 1.0 < 0.14
    c = mix(c, C["tape_dk"] * 0.6, (tk & (band > 0.2) & (band < 0.55)) * 0.8)
    return c * (0.65 + 0.35 * smooth(0.1, 0.65, form(n)))[:, None]


def leather(p, n, cav, lab):
    c = _fabric(p, n, C["leather"], C["leather_hi"], C["seam"] * 2, cav)
    w = (fbm(p[:, 0], p[:, 1], p[:, 2], 60.0, 2) - 0.5)
    return np.clip(c * (1 + w * 0.35)[:, None], 0, 1)


def steel(p, n, cav):
    k = form(n)
    c = mix(C["steel_dk"], C["steel"], smooth(0.25, 0.7, k))
    return c * (1 - 0.5 * smooth(0.3, 0.9, cav))[:, None]


def trunk(p, n, lab, f, ctx):
    cav = cavity(f, p, n)
    c = np.empty((len(p), 3), F)
    def put(m, v):
        c[m] = v
    m = np.isin(lab, (H.JACKET, H.JACKET_DK))
    put(m, jacket(p[m], n[m], cav[m], lab[m]))
    m = np.isin(lab, (H.CORSET, H.CORSET_SEAM))
    put(m, corset(p[m], n[m], cav[m], lab[m]))
    m = lab == H.TROUSER
    put(m, _fabric(p[m], n[m], C["trouser"], C["trouser_hi"], C["seam"], cav[m]))
    m = np.isin(lab, (H.BOOT, H.BOOT_TOP))
    put(m, boot(p[m], n[m], cav[m], lab[m]))
    m = lab == H.LEATHER
    put(m, leather(p[m], n[m], cav[m], lab[m]))
    m = lab == H.TAPE
    put(m, tape(p[m], n[m], cav[m]))
    m = lab == H.CUFF
    put(m, _fabric(p[m], n[m], C["cuff"], C["corset_hi"], C["seam"], cav[m]))
    m = np.isin(lab, (H.STEEL, H.BUCKLE, H.NEEDLE))
    put(m, steel(p[m], n[m], cav[m]))
    m = lab == H.LACE
    put(m, _fabric(p[m], n[m], C["wood"], C["wood"], C["leather"], cav[m]))
    m = np.isin(lab, (H.SKIN, 0, H.LID, H.NAIL, H.LIP))
    put(m, chest_skin(p[m], n[m], cav[m]))
    return c


def chest_skin(p, n, cav):
    k = form(n)
    c = mix(C["skin_sh"], C["skin"], smooth(0.18, 0.6, k))
    # the collarbones and the hollow of the throat
    for s in (-1, 1):
        d = np.abs(p[:, 2] - (1.335 - 0.25 * np.abs(p[:, 0] - s * 0.0) * 0.5))
    return c * (1 - 0.3 * smooth(0.35, 0.95, cav))[:, None]


def skin_hand(p, n, lab, f):
    cav = cavity(f, p, n, 0.004)
    c = chest_skin(p, n, cav)
    knuck = 0.5 + 0.5 * n[:, 0] * 0
    c = mix(c, C["blush"], 0.12)
    m = lab == H.STEEL
    c[m] = steel(p[m], n[m], cav[m])
    m = lab == H.NAIL
    c[m] = C["nail"]
    return c


def _eye_uv(p, s):
    """Coordinates about the eye: (u outward along the canted axis, v up), in units of the eye's half width."""
    ex, ey, ez = H.EYE
    c, si = math.cos(H.CANT), math.sin(H.CANT)
    px, pz = s * p[:, 0] - ex, p[:, 2] - ez
    return (px * c + pz * si) / H.EYE_W, (-px * si + pz * c) / H.EYE_W


def head(p, n, lab, f):
    cav = cavity(f, p, n, 0.003)
    k = form(n)
    c = mix(C["skin_sh"], C["skin"], smooth(0.16, 0.58, k))
    # a porcelain-pale forehead, warmth low on the cheek and the ears, cool lavender in the temple's turn
    c = mix(c, C["blush"], smooth(1.62, 1.60, p[:, 2]) * smooth(0.03, 0.06, np.abs(p[:, 0])) * 0.38)
    c = mix(c, C["ear"], (lab == H.EAR_IN) * 0.8)
    c = c * (1 - 0.42 * smooth(0.45, 0.95, cav))[:, None]
    # the neck in the jaw's shadow
    c = mix(c, C["skin_sh"] * 0.82, smooth(1.51, 1.455, p[:, 2]) * 0.0 + smooth(1.492, 1.462, p[:, 2]) * smooth(0.2, 1.0, n[:, 2] * -1.0 + 0.7) * 0.55)
    for s in (-1, 1):
        u, v = _eye_uv(p, s)
        front = (p[:, 1] > 0.03) & (s * p[:, 0] > 0)
        # the shadow on the lids (a smoky wine), the liner with its wing, the lash line
        lid = np.exp(-((u + 0.02) / 1.25) ** 2 - ((v - 0.40) / 0.46) ** 2) * front
        c = mix(c, rgb("6c3a48"), lid * 0.62)
        up = 0.42 * np.maximum(1 - (u + 0.04) ** 2, 0) ** 0.8
        lo = -0.27 * np.maximum(1 - u ** 2, 0) ** 0.8
        liner = smooth(0.20, 0.07, np.abs(v - up - 0.05)) * smooth(1.08, 0.94, np.abs(u)) * front
        wing = smooth(0.085, 0.03, np.abs(v - (0.0 + (u - 0.95) * 0.74))) * smooth(0.88, 1.0, u) * smooth(1.62, 1.28, u) * front
        low = smooth(0.09, 0.03, np.abs(v - lo)) * smooth(-0.1, 0.5, u) * smooth(1.05, 0.9, u) * front
        c = mix(c, C["hair_dk"], np.clip(liner + wing + low * 0.7, 0, 1))
        # the brow: strong, arched, tapering outward
        bu = (u + 0.1) / 1.35
        bz = 1.02 + 0.30 * np.maximum(1 - (bu - 0.2) ** 2 * 1.6, -0.6) - 0.22 * smooth(0.0, 1.0, bu) ** 3
        th = (0.22 - 0.15 * smooth(-0.6, 1.1, bu))
        br = smooth(th * 1.25, th * 0.6, np.abs(v - bz)) * smooth(-1.02, -0.8, bu) * smooth(1.2, 1.0, bu) * front
        hairs = 0.75 + 0.25 * np.sin((u * 3.0 + v * 1.6) * 34.0)
        c = mix(c, rgb("1b1518"), br * hairs)
    # the choker, its red stitch
    m = lab == H.CUFF
    c[m] = mix(C["cuff"], C["corset_hi"], smooth(0.5, 0.95, k[m]) * 0.6)
    st = (np.abs(p[:, 2] - 1.438) < 0.0015) & (np.sin(np.arctan2(p[:, 0], p[:, 1]) * 40) > 0.1) & m
    c[st] = C["thread"]
    return c


def eyes(p, n):
    """The eyeballs: dark brown irises (NOT red), a big pupil, a catchlight."""
    ex, ey, ez = H.EYE
    c = np.empty((len(p), 3), F)
    s = np.sign(p[:, 0])
    dx = np.abs(p[:, 0]) - ex + s * 0.0
    # she looks a touch inward: hard focus
    dx = dx * 1.0 + 0.0009
    dz = p[:, 2] - ez + 0.0004
    r = np.sqrt(dx * dx + dz * dz)
    white = mix(rgb("bfb6b8"), rgb("efe8e6"), smooth(0.016, 0.006, r))
    iris = mix(rgb("4a2416"), rgb("8a5230"), smooth(0.0035, 0.0072, r))
    iris = mix(iris, rgb("1a0d0a"), smooth(0.0072, 0.0086, r))
    # radial streaks
    a = np.arctan2(dz, dx)
    iris = iris * (0.86 + 0.14 * np.sin(a * 23))[:, None]
    c = mix(white, iris, smooth(0.0091, 0.0084, r))
    c = mix(c, rgb("0b0708"), smooth(0.0040, 0.0034, r))
    # the upper lid's shadow on the eye, the catchlight
    c = c * (1 - 0.55 * smooth(0.0015, 0.0075, dz))[:, None]
    hl = np.sqrt((dx + 0.0026) ** 2 + (dz - 0.0030) ** 2)
    return mix(c, rgb("fff8f2"), smooth(0.0019, 0.0013, hl))


def hairc(p, n, f):
    # strands raked to the bun: noise stretched along their run, so no regular ribs; a band of sheen across the crown
    ph = np.arctan2(p[:, 0] - H.BUN[0], p[:, 1] - H.BUN[1])
    dist0 = np.sqrt((p[:, 0] - H.BUN[0]) ** 2 + (p[:, 1] - H.BUN[1]) ** 2 + (p[:, 2] - H.BUN[2]) ** 2)
    st = np.clip((fbm(np.cos(ph) * 9, np.sin(ph) * 9, dist0 * 5, 1.0, 3) - 0.3) * 2.6, 0, 1)
    st2 = np.clip((fbm(np.cos(ph) * 26, np.sin(ph) * 26, dist0 * 9, 1.0, 2) - 0.3) * 2.6, 0, 1)
    k = form(n)
    cav = cavity(f, p, n, 0.004) if f is not None else np.zeros(len(p), F)
    # the sheen rides a ring round the bun (anisotropic: strands catch the light across their run)
    dist = np.sqrt((p[:, 0] - H.BUN[0]) ** 2 + (p[:, 1] - H.BUN[1]) ** 2 + (p[:, 2] - H.BUN[2]) ** 2)
    band = np.exp(-((dist - 0.125 - 0.012 * np.sin(ph * 3.0)) / 0.024) ** 2) * smooth(0.45, 0.8, k)
    c = mix(C["hair_dk"], C["hair"], 0.35 + 0.65 * st)
    c = mix(c, C["hair_hi"], np.clip(band * (0.25 + 0.75 * st2 * st) * 0.95, 0, 1))
    c = mix(c, C["hair_hi"] * 0.8, smooth(0.72, 1.0, k) * 0.22 * st)
    return c * (1 - 0.6 * smooth(0.35, 0.9, cav))[:, None]


def lockc(p, n):
    k = form(n)
    st = 0.5 + 0.5 * np.sin(p[:, 2] * 40 + (p[:, 0] + p[:, 1]) * 400)
    c = mix(C["hair_dk"], C["hair"], st)
    return mix(c, C["hair_hi"], smooth(0.62, 0.95, k) * 0.7)


# ---- the mask: cracked porcelain, stitched with red thread, a painted fragment of smile, a gilt rim
SMILE = [(-0.0345, 1.5610), (-0.0250, 1.5500), (-0.0130, 1.5440), (0.0, 1.5425), (0.0130, 1.5440), (0.0250, 1.5500), (0.0345, 1.5610)]


def _poly_d(px, pz, pts):
    pts = np.array(pts, F)
    best = np.full(px.shape, 9.0, F)
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        ab = b - a
        t = np.clip(((px - a[0]) * ab[0] + (pz - a[1]) * ab[1]) / float(ab @ ab), 0, 1)
        best = np.minimum(best, np.hypot(px - (a[0] + ab[0] * t), pz - (a[1] + ab[1] * t)))
    return best


# (her right cheek: the stitched seam from the rim down to the jaw; her left: a shorter one)
SEAM_R = [(0.0205, 1.6030), (0.0300, 1.5840), (0.0430, 1.5690), (0.0520, 1.5540), (0.0610, 1.5300)]
SEAM_L = [(-0.0405, 1.5990), (-0.0520, 1.5820), (-0.0660, 1.5720)]


def mask(p, n, lab, f):
    k = form(n)
    x, z = p[:, 0], p[:, 2]
    c = mix(C["porc_sh"], C["porc"], smooth(0.2, 0.62, k))
    c = mix(c, rgb("ffffff"), smooth(0.78, 1.0, k) * 0.7)
    # the crazing: a few big plates
    d1, gap = worley(p[:, 0] + 0.31, p[:, 1], p[:, 2] * 1.1, 21.0)
    wob = (fbm(p[:, 0], p[:, 1], p[:, 2], 110.0, 2) - 0.5) * 0.12
    crack = smooth(0.030, 0.010, gap + wob * 0.6)
    c = mix(c, rgb("4c4450"), crack * 0.85)
    c = mix(c, rgb("ffffff"), smooth(0.05, 0.03, gap + wob) * (1 - crack) * 0.25)
    # the seams
    for pts in (SEAM_R, SEAM_L):
        d = _poly_d(x, z, pts)
        c = mix(c, rgb("5a2c30"), smooth(0.0016, 0.0006, d))
        # cross-stitches along it
        pa = np.array(pts, F)
        L = np.r_[0, np.cumsum(np.linalg.norm(np.diff(pa, axis=0), axis=1))]
        for t in np.arange(0.006, L[-1], 0.0095):
            i = min(np.searchsorted(L, t) - 1, len(pa) - 2)
            i = max(i, 0)
            u = (t - L[i]) / (L[i + 1] - L[i])
            a = pa[i] * (1 - u) + pa[i + 1] * u
            dr = (pa[i + 1] - pa[i]) / (L[i + 1] - L[i])
            nr = np.array((-dr[1], dr[0]), F) * 0.0052
            ds = _poly_d(x, z, [a - nr, a + nr])
            c = mix(c, C["thread"], smooth(0.0016, 0.0009, ds))
    # the painted smile: full red lips, the corners lifted and long
    up = _poly_d(x, z, SMILE)
    ax = np.abs(x)
    top = 1.5442 + 0.0085 * np.exp(-((ax - 0.0052) / 0.0088) ** 2) + 0.0115 * smooth(0.016, 0.034, ax) ** 2
    bot = 1.5430 - 0.0088 * np.exp(-(ax / 0.0135) ** 2) + 0.0120 * smooth(0.015, 0.034, ax) ** 2
    lipm = smooth(-0.0007, 0.0003, z - bot) * smooth(-0.0007, 0.0003, top - z) * smooth(0.0325, 0.0300, ax)
    c = mix(c, rgb("b01a26"), lipm)
    c = mix(c, rgb("f07070"), lipm * np.exp(-((ax - 0.003) / 0.008) ** 2 - ((z - 1.5375) / 0.0026) ** 2) * 0.8)
    c = mix(c, rgb("5a0c14"), smooth(0.0011, 0.0004, up) * smooth(0.036, 0.03, ax) * 0.9)
    # the nose's shading
    c = mix(c, rgb("c8bcc0"), smooth(1.572, 1.5645, z) * smooth(1.558, 1.566, z) * smooth(0.016, 0.004, ax) * 0.5)
    # gold
    g = mix(C["gold_dk"], C["gold"], smooth(0.25, 0.72, k))
    g = mix(g, rgb("ffe9a8"), smooth(0.76, 0.98, k) * 0.7)
    m = lab == H.GOLD
    c[m] = g[m]
    return c


def needle(p, n):
    k = form(n)
    c = mix(C["steel_dk"], C["steel"], smooth(0.2, 0.62, k))
    return mix(c, rgb("ffffff"), smooth(0.8, 1.0, k) * 0.6)


def bowc(p, n, lab, f):
    # the local frame: limbs black lacquer with pale edge highlights where the facets meet
    k = form(n)
    c = mix(C["lacquer"], C["lacquer_hi"] * 0.55, smooth(0.45, 0.95, k))
    bright = smooth(0.62, 0.8, np.abs(n[:, 0]) * 0.0 + np.abs(n[:, 1])) * smooth(0.1, 0.45, np.abs(n[:, 0]))
    c = mix(c, C["lacquer_hi"], bright * 0.85)
    m = lab == H.LEATHER
    wrap = 0.5 + 0.5 * np.sin(p[:, 2] * 520 + p[:, 0] * 90)
    c[m] = mix(rgb("1c181a"), rgb("3e3436"), wrap[m])
    m = lab == H.THREAD
    tw = 0.5 + 0.5 * np.sin(p[:, 2] * 900)
    c[m] = mix(rgb("9a141c"), rgb("e43030"), tw[m])
    m = lab == H.LACE
    c[m] = mix(rgb("8a6642"), C["wood"], smooth(0.2, 0.7, k[m]))
    return c


def quiver(p, n, lab, f):
    cav = cavity(f, p, n)
    c = leather(p, n, cav, lab)
    m = lab == H.LACE
    c[m] = _fabric(p[m], n[m], C["boot_top"], C["boot_hi"], C["seam"], cav[m])
    # the red seam stitched up its back
    a = H.QUIVER_A
    b = H.QUIVER_B
    u = (b - a) / np.linalg.norm(b - a)
    t = (p - a) @ u
    r = (p - a) - t[:, None] * u
    side = r @ np.array((0.97, 0.0, -0.23), F) * 1.0
    wave = 0.012 * np.sin(t * 22)
    sd = np.abs(side - wave)
    back = r[:, 1] < -0.012
    c = mix(c, C["thread"], smooth(0.0034, 0.0018, sd) * back)
    st = smooth(0.012, 0.009, sd) * (np.sin(t * 150) > 0.55) * back
    return mix(c, C["thread"], st)


def coat(p, n, inside=False):
    fold = 0.5 + 0.5 * n[:, 0] * 0.3
    k = form(n)
    if inside:
        return mix(rgb("120f13"), rgb("3a1218"), smooth(0.3, 0.9, k))
    fold = (fbm(p[:, 0] * 1.4, p[:, 1] * 1.4, p[:, 2] * 0.25, 7.0, 2) - 0.5) * 0.5
    c = mix(C["jacket_sh"], C["jacket"], smooth(0.2, 0.62, k + fold))
    c = mix(c, C["jacket_hi"], smooth(0.7, 1.0, k + fold) * 0.5)
    # the hem: a dark turned band, a line of red stitch over it (the coat's own edges read at the match camera)
    th = np.arctan2(-p[:, 0], -p[:, 1])
    d = p[:, 2] - H.coat_hem(th)
    c = mix(c, C["jacket_dk"] * 0.7, smooth(0.052, 0.046, d))
    s = smooth(0.0035, 0.002, np.abs(d - 0.062)) * (np.sin(np.arctan2(p[:, 0], p[:, 1]) * 90) > 0)
    # and the front edges
    edge = math.radians(128) - np.abs(th)
    c = mix(c, C["jacket_dk"] * 0.7, smooth(0.075, 0.06, edge))
    return mix(c, rgb("e8a050"), s)


def collar(p, n, inside=False):
    k = form(n)
    if inside:
        return mix(rgb("6c1020"), rgb("a02334"), smooth(0.2, 0.8, k))
    return mix(C["jacket_sh"], C["jacket"], smooth(0.15, 0.6, k))


def string(p, n):
    return np.tile(rgb("ff2a18"), (len(p), 1))
