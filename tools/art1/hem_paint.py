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


C = {"skin": rgb("bb8560"), "skin_sh": rgb("85503b"), "blush": rgb("ae6a50"), "lip": rgb("a83a40"), "ear": rgb("85503b"),
     "hair": rgb("1a161c"), "hair_hi": rgb("5e6a88"), "hair_dk": rgb("0b0a0f"),
     "porc": rgb("f4f0ea"), "porc_sh": rgb("b6b2c0"), "gold": rgb("e0ae42"), "gold_dk": rgb("8c5e1a"), "thread": rgb("e8141e"),
     "corset": rgb("3a3236"), "corset_hi": rgb("7c6e70"), "seam": rgb("1a1618"), "trouser": rgb("383036"), "trouser_hi": rgb("6e6268"),
     "boot": rgb("4e2c28"), "boot_hi": rgb("93645a"), "boot_top": rgb("5e3632"), "lace": rgb("140f12"),
     "jacket": rgb("cc1420"), "jacket_hi": rgb("f4383a"), "jacket_sh": rgb("6e0a16"), "jacket_dk": rgb("6c0f22"), "cuff": rgb("322a2e"),
     "tape": rgb("d9c49c"), "tape_dk": rgb("8b7654"), "leather": rgb("6e4228"), "leather_hi": rgb("a8724a"), "buckle": rgb("b9b7bd"),
     "steel": rgb("d6dae2"), "steel_dk": rgb("6c7284"), "wood": rgb("c49a6c"), "nail": rgb("e6b4ac"),
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
    c = mix(sh, base, smooth(0.18, 0.55, k))
    c = mix(c, hi, smooth(0.60, 0.96, k) * 0.7 * sheen)
    return c * (1 - 0.5 * smooth(0.25, 0.9, cav))[:, None]


def stitch(d, along, w=0.0024, per=170.0):
    """A dashed red stitch: d the distance across the line, along the distance along it."""
    return smooth(w, w * 0.5, np.abs(d)) * (np.sin(along * per) > -0.2)


def jacket(p, n, cav, lab):
    c = _fabric(p, n, C["corset"], C["corset_hi"], C["seam"], cav, 1.0)
    c = mix(c, C["thread"], (lab == H.JACKET_DK) * 0.9)
    # a run of red stitch up the sleeve and round the shoulder line
    ax = np.sign(p[:, 0]) * 0.1662
    th = np.arctan2(p[:, 1], p[:, 0] - ax)
    onarm = np.abs(p[:, 0]) > 0.125
    c = mix(c, C["thread"], stitch((np.abs(th) - 1.4) * 0.038, p[:, 2]) * onarm)
    return c


def pauldron(p, n, cav):
    """More red on the shoulders than the sheet: she reads from above. Black under the plates' lip, a stitched edge."""
    k = form(n)
    up = smooth(-0.2, 0.45, n[:, 2])
    c = mix(C["jacket_sh"], C["jacket"], smooth(0.25, 0.7, k))
    c = mix(c, C["jacket_hi"], smooth(0.78, 1.0, k) * 0.5)
    c = mix(C["corset"], c, up)
    c = c * (1 - 0.6 * smooth(0.25, 0.8, cav))[:, None]
    z = p[:, 2]
    c = mix(c, C["thread"] * 1.1, stitch(z - 1.262, np.arctan2(p[:, 1], np.abs(p[:, 0]) - 0.16) * 0.05, 0.0030, 640.0))
    return np.clip(c, 0, 1)


def corset(p, n, cav, lab):
    c = _fabric(p, n, C["corset"], C["corset_hi"], C["seam"], cav, 1.1)
    a = np.abs(p[:, 0])
    z = p[:, 2]
    front = p[:, 1] > -0.02
    # red herringbone down the seams
    for dx in (0.0, 0.040, 0.086):
        d = np.abs(a - dx)
        chev = smooth(0.0030, 0.0014, np.abs(((z + d * 0.9) * 90.0) % 1.0 - 0.5) / 90.0 * 4.0)
        c = mix(c, C["thread"], chev * smooth(0.0105, 0.0085, d) * front)
    # its lower edge piped red; the laced back
    c = mix(c, C["thread"], smooth(0.0065, 0.0035, z - H.corset_low(p[:, 0], p[:, 1])))
    back = ~front
    lace = smooth(0.0035, 0.0018, np.abs(a - ((z * 26.0) % 1.0 - 0.5).__abs__() * 0.05))
    c = mix(c, C["thread"], lace * back * (a < 0.03))
    return c


def boot(p, n, cav, lab):
    c = _fabric(p, n, C["boot"], C["boot_hi"], C["seam"], cav, 1.2)
    c = mix(c, C["boot_top"], (lab == H.BOOT_TOP) * 0.9)
    # the laces up the front, black crosses with red eyelets, from the toe's root to the cuff
    a = np.abs(np.abs(p[:, 0]) - 0.0924)
    z = p[:, 2]
    front = (n[:, 1] > 0.5) & (z > 0.10) & (z < 0.40)
    v = np.abs(((z * 34.0) % 1.0) - 0.5) * 0.030 + 0.001
    c = mix(c, rgb("0a0809"), smooth(0.0030, 0.0014, np.abs(a - v)) * front)
    eye = (a > 0.0135) & (a < 0.0185) & (((z * 34.0) % 1.0) < 0.18) & front
    c = mix(c, C["thread"], eye * 1.0)
    return c


def tape(p, n, cav):
    """The stitched bracer: black, a red lace up the forearm's outside, stitched at both ends."""
    c = _fabric(p, n, C["corset"], C["corset_hi"], C["seam"], cav)
    ax = np.sign(p[:, 0]) * 0.1662
    th = np.arctan2(p[:, 1], (p[:, 0] - ax) * np.sign(p[:, 0]))
    d = np.abs(th) * 0.03
    z = p[:, 2]
    v = np.abs((z * 42.0) % 1.0 - 0.5) * 0.024
    c = mix(c, C["thread"], smooth(0.0032, 0.0016, np.abs(d - v)) * (np.abs(th) < 0.75))
    return c


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
    m = lab == H.PAULDRON
    put(m, pauldron(p[m], n[m], cav[m]))
    m = np.isin(lab, (H.STEEL, H.BUCKLE, H.NEEDLE))
    put(m, steel(p[m], n[m], cav[m]))
    m = lab == H.LACE
    put(m, _fabric(p[m], n[m], C["wood"], C["wood"], C["leather"], cav[m]))
    m = np.isin(lab, (H.SKIN, 0, H.LID, H.NAIL, H.LIP))
    put(m, chest_skin(p[m], n[m], cav[m]))
    # the navel's little shadow
    m = (lab == H.SKIN) & (p[:, 2] < 1.02) & (p[:, 1] > 0)
    c[m] = c[m] * (1 - 0.4 * smooth(0.0065, 0.002, np.hypot(p[m, 0], p[m, 2] - 0.965)))[:, None]
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
    m = lab == H.NAIL
    c[m] = C["nail"]
    # fingerless gloves: black from the wrist to the knuckles, a red stitch across
    wz = 0.832
    d = wz - p[:, 2]
    gl = smooth(0.094, 0.086, d)
    g = _fabric(p, n, C["corset"], C["corset_hi"], C["seam"], cav)
    c = mix(c, g, gl)
    return mix(c, C["thread"], stitch(d - 0.012, p[:, 1], 0.0016, 400.0))


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
    # warmth on the cheek and the ears
    c = mix(c, C["blush"], smooth(1.62, 1.60, p[:, 2]) * smooth(0.03, 0.06, np.abs(p[:, 0])) * 0.38)
    c = mix(c, C["ear"], (lab == H.EAR_IN) * 0.8)
    c = c * (1 - 0.18 * smooth(0.6, 1.0, cav))[:, None]
    # the neck in the jaw's shadow
    c = mix(c, C["skin_sh"] * 0.8, smooth(1.505, 1.470, p[:, 2]) * 0.7)
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
        bz = 1.62 + 0.16 * np.maximum(1 - (bu - 0.1) ** 2 * 1.6, -0.6) + 0.16 * bu - 0.22 * smooth(0.45, 1.0, bu) ** 2
        th = (0.26 - 0.17 * smooth(-0.6, 1.1, bu))
        br = smooth(th * 1.25, th * 0.6, np.abs(v - bz)) * smooth(-1.02, -0.8, bu) * smooth(1.2, 1.0, bu) * front
        hairs = 0.75 + 0.25 * np.sin((u * 3.0 + v * 1.6) * 34.0)
        c = mix(c, rgb("1b1518"), br * hairs)
    # the mouth: painted to the sculpt's own curve, a cupid's bow, the lower lip the fuller, a soft shine on it
    x, z = p[:, 0], p[:, 2]
    ax = np.abs(x)
    fr = p[:, 1] > 0.05
    mid = 1.5424 + 0.0066 * smooth(0.006, 0.0245, ax) ** 1.5
    top = mid + 0.0030 * smooth(0.0245, 0.012, ax) + 0.0062 * np.exp(-((ax - 0.0056) / 0.0072) ** 2) - 0.0004
    bot = mid - 0.0108 * np.exp(-(ax / 0.0150) ** 2) - 0.0010 * smooth(0.0245, 0.016, ax)
    lm = smooth(-0.0006, 0.0005, z - bot) * smooth(-0.0006, 0.0005, top - z) * smooth(0.0255, 0.0232, ax) * fr
    c = mix(c, mix(rgb("8e2a30"), C["lip"], smooth(0.25, 0.7, k)), lm)
    c = mix(c, rgb("d8797a"), lm * np.exp(-((ax - 0.0015) / 0.0088) ** 2 - ((z - 1.5362) / 0.0024) ** 2) * 0.9)
    c = mix(c, rgb("c25a60"), lm * np.exp(-((ax - 0.0052) / 0.0050) ** 2 - ((z - 1.5478) / 0.0014) ** 2) * 0.55)
    c = mix(c, rgb("4a161a"), smooth(0.0005, 0.0002, np.abs(z - mid)) * smooth(0.0262, 0.024, ax) * fr * 0.85)
    c = mix(c, rgb("5a2418"), smooth(0.0022, 0.0005, np.hypot(ax - 0.0262, z - (mid + 0.0))) * fr * 0.35)
    # what carries a low mesh: the nose's underside and side, nostrils, under the lip, the cheek's hollow, the jaw's turn
    c = mix(c, C["skin_sh"], smooth(0.0046, 0.0, np.abs(z - 1.5690)) * smooth(0.0125, 0.003, ax) * fr * 0.8)
    c = mix(c, rgb("5a2c20"), smooth(0.0018, 0.0008, np.hypot(ax - 0.0050, (z - 1.5712) * 1.6)) * fr * 0.8)
    c = mix(c, C["skin_sh"], smooth(0.0045, 0.0, np.abs(z - 1.5292)) * smooth(0.0150, 0.006, ax) * fr * 0.6)
    c = mix(c, C["skin_sh"], smooth(0.0034, 0.0, np.abs(ax - 0.0098)) * smooth(1.574, 1.584, z) * smooth(1.606, 1.592, z) * fr * 0.45)
    c = mix(c, rgb("eaae7c"), np.exp(-(x / 0.0040) ** 2) * smooth(1.578, 1.590, z) * smooth(1.622, 1.606, z) * fr * 0.6)
    c = mix(c, rgb("eaae7c"), np.exp(-(x / 0.0065) ** 2 - ((z - 1.5825) / 0.0040) ** 2) * fr * 0.55)     # the nose's tip
    c = mix(c, rgb("e4a474"), np.exp(-(x / 0.0085) ** 2 - ((z - 1.5175) / 0.0055) ** 2) * fr * 0.4)      # the chin's light
    c = mix(c, C["blush"], np.exp(-((ax - 0.050) / 0.018) ** 2 - ((z - 1.585) / 0.014) ** 2) * fr * 0.5)
    c = mix(c, C["skin_sh"], smooth(0.012, 0.0, np.abs(ax + (z - 1.52) * -0.42 - 0.052)) * smooth(1.60, 1.56, z) * fr * 0.4)
    # the mask's strap, running back from its points under the hair
    c = mix(c, rgb("1c1518"), smooth(0.0046, 0.0028, np.abs(p[:, 2] - 1.645 - 0.05 * np.minimum(p[:, 1] - 0.012, 0.0))) * (p[:, 1] < 0.03))
    return c


def eyes(p, n):
    """The eyeballs: bright green irises, a dark ring, a catchlight."""
    ex, ey, ez = H.EYE
    c = np.empty((len(p), 3), F)
    s = np.sign(p[:, 0])
    dx = np.abs(p[:, 0]) - ex + s * 0.0
    # she looks a touch inward: hard focus
    dx = dx * 1.0 + 0.0009
    dz = p[:, 2] - ez + 0.0004
    r = np.sqrt(dx * dx + dz * dz)
    white = mix(rgb("d8cfca"), rgb("fbf5f0"), smooth(0.016, 0.006, r))
    iris = mix(rgb("9cf23c"), rgb("2fd02c"), smooth(0.0035, 0.0072, r))
    iris = mix(iris, rgb("0e4a14"), smooth(0.0076, 0.0088, r))
    # radial streaks
    a = np.arctan2(dz, dx)
    iris = iris * (0.86 + 0.14 * np.sin(a * 23))[:, None]
    c = mix(white, iris, smooth(0.0091, 0.0084, r))
    c = mix(c, rgb("0b0708"), smooth(0.0033, 0.0028, r))
    # the upper lid's shadow on the eye, the catchlight
    c = c * (1 - 0.55 * smooth(0.0015, 0.0075, dz))[:, None]
    hl = np.sqrt((dx + 0.0026) ** 2 + (dz - 0.0030) ** 2)
    return mix(c, rgb("fff8f2"), smooth(0.0019, 0.0013, hl))


def hairc(p, n, f, lab):
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
    c = c * (1 - 0.6 * smooth(0.35, 0.9, cav))[:, None]
    m = lab == H.THREAD
    c[m] = mix(C["jacket_sh"], C["jacket_hi"], smooth(0.2, 0.9, k[m]))
    return c


def lockc(p, n):
    k = form(n)
    w = fbm(p[:, 0] * 30, p[:, 1] * 30, p[:, 2] * 1.5, 3.0, 3)
    st = np.clip((w - 0.3) * 2.6, 0, 1)
    c = mix(C["hair_dk"], C["hair"], 0.3 + 0.7 * st)
    return mix(c, C["hair_hi"], smooth(0.6, 0.95, k) * (0.3 + 0.6 * st))


# ---- the mask: dark leather, red cross-stitches round each eye, a raised red edge
def _poly_d(px, pz, pts):
    pts = np.array(pts, F)
    best = np.full(px.shape, 9.0, F)
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        ab = b - a
        t = np.clip(((px - a[0]) * ab[0] + (pz - a[1]) * ab[1]) / float(ab @ ab), 0, 1)
        best = np.minimum(best, np.hypot(px - (a[0] + ab[0] * t), pz - (a[1] + ab[1] * t)))
    return best


def mask(p, n, lab, f):
    k = form(n)
    x, z = p[:, 0], p[:, 2]
    c = mix(rgb("120d10"), rgb("2e2024"), smooth(0.3, 0.8, k))
    c = mix(c, rgb("6a5258"), smooth(0.8, 1.0, k) * 0.5)
    for s in (-1, 1):
        ex, ez = H.EYE[0] * s, H.EYE[2]
        for a in np.linspace(0.3, math.tau + 0.3, 9)[:-1]:
            cx, cz = ex + 0.0290 * math.cos(a), ez + 0.0160 * math.sin(a) + 0.0
            for d in ((1, 1), (1, -1)):
                ds = _poly_d(x, z, [(cx - d[0] * 0.0040, cz - d[1] * 0.0040), (cx + d[0] * 0.0040, cz + d[1] * 0.0040)])
                c = mix(c, rgb("d8222c"), smooth(0.0015, 0.0009, ds))
    # its raised edge, from the sculpt's own region: a decimated mesh projects its labels onto the rim
    m = np.abs(H.mask_region(p[:, 0], p[:, 1], p[:, 2]) + 0.0005) < 0.0016
    c[m] = mix(C["jacket_sh"], C["thread"], smooth(0.2, 0.8, k[m]))
    return c


def needle(p, n):
    k = form(n)
    c = mix(C["steel_dk"], C["steel"], smooth(0.2, 0.62, k))
    return mix(c, rgb("ffffff"), smooth(0.8, 1.0, k) * 0.7)


def bowc(p, n, lab, f):
    """Silver: a long bright highlight down each limb, a cool blue-grey turn. The grip red-wrapped."""
    c = needle(p, n)
    band = 0.5 + 0.5 * np.sin(p[:, 2] * 19.0 + n[:, 1] * 2.5)
    c = mix(c, rgb("8d93a8"), band * 0.35)
    m = lab == H.THREAD
    tw = 0.5 + 0.5 * np.sin(p[:, 2] * 560 + p[:, 0] * 120)
    c[m] = mix(rgb("8f0f1c"), rgb("e22a30"), tw[m])
    return c


def spool_thread(p, n, cav):
    a, b = H.QUIVER_A, H.QUIVER_B
    u = (b - a) / np.linalg.norm(b - a)
    t = (p - a) @ u
    s = np.cross(u, (0.0, 1.0, 0.0))
    s /= np.linalg.norm(s)
    v = np.cross(u, s)
    r = p - a
    ang = np.arctan2(r @ v, r @ s)
    # wound thread, laid in crossing bands, a brighter sheen on the turn
    w1 = 0.5 + 0.5 * np.sin(t * 300 + ang * 2.0)
    w2 = 0.5 + 0.5 * np.sin(t * 120 - ang * 7.0)
    k = form(n)
    c = mix(rgb("6a0a14"), rgb("c2161f"), smooth(0.2, 0.7, k))
    c = mix(c, rgb("f04040"), smooth(0.65, 1.0, k) * w1 * 0.7)
    c = c * (0.78 + 0.22 * w1)[:, None] * (0.88 + 0.12 * w2)[:, None]
    return np.clip(c, 0, 1)


def quiver(p, n, lab, f):
    cav = cavity(f, p, n)
    c = spool_thread(p, n, cav)
    m = lab == H.LACE
    k = form(n)
    w = 0.5 + 0.5 * np.sin((p[:, 0] + p[:, 1] * 0.6) * 300)
    c[m] = (mix(rgb("8a6642"), rgb("d8b080"), smooth(0.2, 0.8, k)) * (0.9 + 0.1 * w)[:, None])[m]
    return c


def gearlab(p, n, lab):
    c = needle(p, n)
    m = lab == H.THREAD
    c[m] = mix(rgb("8f0f1c"), rgb("e22a30"), smooth(0.2, 0.8, form(n)))[m]
    m = lab == H.FEATHER
    c[m] = mix(rgb("8d7458"), rgb("cdb896"), smooth(0.2, 0.8, form(n)))[m]
    m = lab == H.BUCKLE
    c[m] = C["steel_dk"]
    return c


def scarf(p, n, f):
    """Saturated crimson, soft folds: the brightest thing she wears, for the top-down read."""
    cav = cavity(f, p, n, 0.012) if f is not None else np.zeros(len(p), F)
    fold = (fbm(p[:, 0] * 1.2, p[:, 1] * 1.2, p[:, 2] * 1.2, 7.0, 2) - 0.5) * 0.9
    k = np.clip(form(n) * 0.9 + fold, 0, 1)
    c = mix(rgb("6e0810"), rgb("c80e18"), smooth(0.12, 0.55, k))
    c = mix(c, rgb("f23830"), smooth(0.66, 0.95, k) * 0.6)
    return c * (1 - 0.55 * smooth(0.25, 0.9, cav))[:, None]


def string(p, n):
    return np.tile(rgb("ff2a18"), (len(p), 1))
