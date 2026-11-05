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
     "hair": rgb("211b22"), "hair_hi": rgb("7a8cb0"), "hair_dk": rgb("0d0b10"),
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


PLATE = None         # the face plate (the owner's face, flat and frontal: edit_face), set by hem_art1


# the face plate (px on a 640 frame) on the head scan: eyes' spacing for x; brow, eyes, nose, mouth, chin for z
PLATE_X = 170.0 / 0.082
PLATE_Z = ((1.4895, 545.0), (1.5318, 462.0), (1.5675, 400.0), (1.6065, 312.0), (1.629, 265.0), (1.70, 110.0))


def plate(p):
    """The plate's colour at model points, straight from the front."""
    h, w = PLATE.shape[:2]
    k = w / 640.0
    py = np.interp(p[:, 2], [q[0] for q in PLATE_Z], [q[1] for q in PLATE_Z])
    px = 320.0 + p[:, 0] * PLATE_X
    return PLATE[np.clip((py * k).astype(int), 0, h - 1), np.clip((px * k).astype(int), 0, w - 1)]


def head(p, n, lab, f):
    c = plate(p)
    # behind the cheek the plate has nothing to say: its skin tone, shaded
    k = form(n)
    back = mix(C["skin_sh"], C["skin"], smooth(0.15, 0.6, k))
    c = mix(c, back, smooth(0.050, 0.010, p[:, 1]))
    # below the jaw: the neck in its shadow, not the plate's
    c = mix(c, mix(C["skin_sh"], back, 0.35), smooth(1.522, 1.490, p[:, 2]))
    return mix(c, C["ear"], (lab == H.EAR_IN) * 0.7)


def eyes(p, n):
    return plate(p)


def headscan(c, p, n):
    """The head sheet's paint: a touch more contrast and sheen in the hair; the red tie and cowl crisp; a soft form shade (the toon light is near white)."""
    c = np.clip(c, 0, 1)
    k = form(n)
    dark = c.max(1) < 0.22
    h = mix(c * 1.1 + 0.018, rgb("7f90b4"), smooth(0.74, 1.0, k) * 0.28)
    c[dark] = h[dark]
    light = ~dark
    c[light] = (c * (0.76 + 0.3 * smooth(0.15, 0.7, k))[:, None])[light]
    # a stray tip of hair the scan left on her throat
    tip = dark & (p[:, 2] < 1.505) & (np.abs(p[:, 0]) < 0.052) & (p[:, 1] > 0.015)
    c[tip] = mix(C["skin_sh"], C["skin"], 0.45)
    # the features from the art: the plate over the face, fading out before the hair and jaw
    ax = np.abs(p[:, 0])
    fw = smooth(0.0585, 0.046, ax) * smooth(1.492, 1.503, p[:, 2]) * smooth(1.668, 1.652, p[:, 2]) * smooth(0.03, 0.06, p[:, 1]) * smooth(0.2, 0.45, n[:, 1])
    return np.clip(mix(c, plate(p), fw), 0, 1)


def scan(c, p, n):
    """The scan's paint for the toon shader: blacks up to a charcoal that shows form, reds crisper; the shoulders' tops take more red (the top-down read)."""
    c = np.clip(c, 0, 1) ** 0.82
    red = np.clip((c[:, 0:1] - c[:, 1:2] * 1.6) * 4.0, 0, 1)
    c = np.clip(c + (c - c.mean(1, keepdims=True)) * red * 0.55 + red * 0.05, 0, 1)
    # the side views drew the hanging hand over the hip, and the scan took it as paint: back to capri
    tan = (c[:, 0] > 0.42) & (c[:, 1] > c[:, 0] * 0.42) & (c[:, 1] < c[:, 0] * 0.9) & (c[:, 2] < c[:, 1] * 0.95)
    hip = tan & (p[:, 2] > 0.40) & ((p[:, 2] < 0.82) | ((p[:, 2] < 0.905) & (np.abs(p[:, 0]) < 0.135)))
    c[hip] = mix(rgb("1c1619"), rgb("4a3f48"), smooth(0.2, 0.8, form(n)))[hip]
    # graded to the master sheet: its blacks lean plum, not neutral
    dark = 1 - smooth(0.15, 0.4, c.max(1))
    c = np.clip(c * (1 + dark[:, None] * np.array((0.04, -0.08, 0.14), F)), 0, 1)
    sh = smooth(0.105, 0.14, np.abs(p[:, 0])) * smooth(1.20, 1.25, p[:, 2]) * smooth(0.25, 0.7, n[:, 2])
    return mix(c, rgb("c0141e"), sh * 0.8)


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
    """Long strands: noise stretched along the fall; a blue-grey sheen band that catches the shine, as the sheet's."""
    k = form(n)
    a = np.clip((fbm(p[:, 0] * 34, p[:, 1] * 34, p[:, 2] * 1.3, 3.0, 3) - 0.3) * 2.8, 0, 1)
    b = np.clip((fbm(p[:, 0] * 90, p[:, 1] * 90, p[:, 2] * 2.2, 3.0, 2) - 0.3) * 2.8, 0, 1)
    c = mix(C["hair_dk"], C["hair"], 0.25 + 0.75 * a)
    sheen = np.exp(-((np.sin(p[:, 2] * 7.5 + 0.7) - 0.55) / 0.4) ** 2)
    c = mix(c, C["hair_hi"], np.clip(smooth(0.45, 0.9, k) * sheen * (0.25 + 0.75 * b), 0, 1) * 0.95)
    return mix(c, C["hair_hi"] * 1.15, smooth(0.8, 1.0, k) * b * 0.4)


def mask(p, n, lab, f):
    return plate(p)


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
    fold = (fbm(p[:, 0] * 1.2, p[:, 1] * 1.2, p[:, 2] * 1.2, 7.0, 2) - 0.5) * (0.9 if f is not None else 0.3)
    k = np.clip(form(n) * 0.9 + fold, 0, 1)
    c = mix(rgb("6e0810"), rgb("c80e18"), smooth(0.12, 0.55, k))
    c = mix(c, rgb("f23830"), smooth(0.66, 0.95, k) * 0.6)
    return c * (1 - 0.55 * smooth(0.25, 0.9, cav))[:, None]


def string(p, n):
    return np.tile(rgb("ff2a18"), (len(p), 1))
