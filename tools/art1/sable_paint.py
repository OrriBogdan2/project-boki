"""ART-1 Sable v2: the texel-space paint (recipe: kael_paint.py): arrays of texels (world position, normal, occlusion) to sRGB in 0..1. Palette off sable_v2_turnaround and the master sheet: dark plum leather,
violet trim and lining, pearl moth wings with violet eye spots, white hair, grey-lilac skin, silver, red-brown wood, violet glow."""
import os
import numpy as np
from meshkit import norm, smooth
from kael_paint import hexc, mix, fbm, lit, ramp, hash3
import sable_pieces as K
import imgio

WINGS = imgio.load(os.path.expanduser("~/meshy/sable_v2/proj/wings.png"))      # the turnaround's back view, flipped so x grows outward

LEATHER = [hexc("#2a1d30"), hexc("#3b2a43"), hexc("#533c5e"), hexc("#73587f"), hexc("#9a7fa6")]
LINING = [hexc("#2d1147"), hexc("#46196e"), hexc("#5f2595"), hexc("#7a35b5"), hexc("#9a55d2")]
HAIR = [hexc("#8f8a9c"), hexc("#b6b2c2"), hexc("#d5d2dd"), hexc("#ecebf1"), hexc("#ffffff")]
SKIN = [hexc("#5a5568"), hexc("#7d7889"), hexc("#a09bab"), hexc("#bcb8c6"), hexc("#d6d3de")]
SILVER = [hexc("#3c3a47"), hexc("#5b5968"), hexc("#7b7a8a"), hexc("#9c9bab"), hexc("#c2c1cd")]      # a step under the sheet: the engine lifts metal
WOOD = [hexc("#2b1316"), hexc("#43201f"), hexc("#5a2d2a"), hexc("#73403a"), hexc("#8c584c")]        # the sheet's deep maroon stock, not red
FUZZ = [hexc("#6a5a80"), hexc("#857596"), hexc("#a08fb0"), hexc("#b9a9c6"), hexc("#d0c3da")]
STEM = hexc("#4a3a66")
SKIN_LIFT = np.array([0.92, 0.98, 1.05])
TRIM = hexc("#7c34c4")


def sample(img, x, y):
    """Bilinear lookup, clamped to the image."""
    h, w = img.shape[:2]
    x, y = np.clip(x, 0, w - 1.001), np.clip(y, 0, h - 1.001)
    x0, y0 = x.astype(int), y.astype(int)
    fx, fy = (x - x0)[:, None], (y - y0)[:, None]
    return (img[y0, x0] * (1 - fx) + img[y0, x0 + 1] * fx) * (1 - fy) + (img[y0 + 1, x0] * (1 - fx) + img[y0 + 1, x0 + 1] * fx) * fy


def scan_grade(col, p, ao):
    """The scan's paint graded to the master: the leather pushed plum, the purple piping up, the blacks charcoal (near-black reads as gloss under the toon rim)."""
    lum = col.mean(1, keepdims=True)
    sat = (col.max(1) - col.min(1)) / np.maximum(col.max(1), 0.01)
    purple = smooth(0.25, 0.5, sat) * smooth(0.02, 0.08, col[:, 2] - col[:, 1]) * (p[:, 2] < K.NECK_Z)
    c = col.copy()
    c = mix(c, np.clip((col - lum) * 1.25 + lum, 0, 1) * np.array([1.0, 0.95, 1.1]), purple)
    # the coat a step up and toward plum, so its purple reads in the toon light
    body = smooth(K.NECK_Z - 0.02, K.NECK_Z - 0.06, p[:, 2]) * smooth(0.5, 0.36, lum[:, 0])
    c = mix(c, c * np.array([1.26, 1.14, 1.32]) + np.array([0.032, 0.014, 0.042]), body)
    # (the scan's near-black slivers at the shoulders and behind the ear: its unpainted seams)
    sliver = smooth(0.11, 0.06, lum[:, 0])
    c = mix(c, hexc("#2e2233"), sliver * (p[:, 2] < K.NECK_Z - 0.02))
    c = mix(c, hexc("#d9d6e0"), smooth(0.3, 0.2, lum[:, 0]) * smooth(K.NECK_Z + 0.03, K.NECK_Z + 0.07, p[:, 2]) * (p[:, 1] < 0.0))
    return np.clip(c, 0, 1)


def skin(p, n, ao):
    return ramp(np.clip(lit(n, ao) * 1.0 + 0.16, 0, 1), SKIN)


def glove(p, n, ao):
    return ramp(np.clip(lit(n, ao) * 1.05, 0, 1), LEATHER)


def silver(p, n, ao):
    return ramp(np.clip(lit(n, ao) * 1.05 + 0.04, 0, 1), SILVER)


def silver_engraved(p, n, ao):
    t = lit(n, ao) * 1.2 + 0.1
    eng = smooth(0.42, 0.46, fbm(p * 170.0, 2)) * smooth(0.5, 0.46, fbm(p * 170.0, 2))
    return ramp(np.clip(t - eng * 0.3, 0, 1), SILVER)


def wood(p, n, ao):
    g = fbm(p * np.array([60.0, 60.0, 9.0]), 3)
    return ramp(np.clip(lit(n, ao) * 0.95 + (g - 0.5) * 0.45, 0, 1), WOOD)


def mouth_glow(p, n, ao):
    return np.tile(hexc("#c24dff"), (len(p), 1))


def runes(p, n, ao):
    """Blocky glyphs along the barrel: cells of bright strokes on a dark plate, a gap between glyphs."""
    side = np.where(p[:, 0] > 0, 1.0, -1.0)
    u = -(p[:, 2] - K.grip("R")[2])
    v = p[:, 1] - K.grip("R")[1] - 0.052
    cu = np.floor(u / 0.0115)
    glyph = (cu.astype(int) % 3) != 2
    cell = np.stack([np.floor(u / 0.0038), np.floor((v + np.abs(p[:, 0]) * 3.0 + 0.01) / 0.0036), np.abs(p[:, 0]) * 0 + 7 * side], 1)
    cell = cell.astype(np.int64) + 1000
    on = (hash3(cell[:, 0], cell[:, 1], cell[:, 2]) > 0.42) & glyph
    return mix(hexc("#2c0f4c"), hexc("#c43cff"), on.astype(float))


def crystal(p, n, ao):
    k = np.abs(n[:, 0] * 0.6 + n[:, 1] * 0.8 + n[:, 2] * 0.3)
    return mix(hexc("#9a1fd8"), hexc("#f6a2ff"), smooth(0.3, 0.95, k))


def path_u(p, path):
    path = np.asarray(path)
    a, b = path[:-1], path[1:]
    best = np.full(len(p), 9e9)
    us = np.zeros(len(p))
    n = len(a)
    side = np.zeros(len(p))
    for i in range(n):
        ab = b[i] - a[i]
        t = np.clip((p - a[i]) @ ab / (ab @ ab), 0, 1)
        q = p - (a[i] + t[:, None] * ab)
        d = np.linalg.norm(q, axis=1)
        m = d < best
        best[m] = d[m]
        us[m] = (i + t[m]) / n
        side[m] = q[m, 0]
    return us, best, side


def feather(p, n, ao, path):
    """The thin dark stem, the dusty lilac fuzz combed out either side of it: darker by the stem, paler and notched at the edge."""
    u, d, sd = path_u(p, path)
    barbs = 0.5 + 0.5 * np.sin(u * 110.0 + d * 120.0)
    fz = ramp(np.clip(0.2 + 0.5 * smooth(0.004, 0.03, d) + lit(n, ao) * 0.22 + (barbs - 0.5) * 0.2, 0, 1), FUZZ)
    return mix(fz, STEM[None, :] * (0.8 + 0.3 * np.clip(lit(n, ao), 0, 1))[:, None], smooth(0.0045, 0.0025, d))


def braid(p, n, ao, path):
    """Fat crossing lobes: the creases between them run in chevrons down the plait (so it reads woven, not beaded), fine strands combed along each lobe."""
    u, d, sd = path_u(p, path)
    k = u * 11.0 + np.abs(sd) * 7.0
    fr = k - np.floor(k)
    flip = np.where(np.floor(k) % 2 == 0, 1.0, -1.0)
    crease = smooth(0.12, 0.03, np.minimum(fr, 1 - fr))
    strands = np.sin((fr * 2.2 + flip * sd * 24.0) * 9.0)
    return ramp(np.clip(0.58 + lit(n, ao) * 0.42 - crease * 0.5 + strands * 0.05, 0, 1), HAIR)


def hairback(p, n, ao, c=np.array([0.0, -0.012, 1.63])):
    """White hair combed from the crown down to the nape, the scan's tone."""
    q = p - c
    st = 0.5 + 0.5 * np.sin(np.arctan2(q[:, 0], -q[:, 1]) * 26.0)
    return np.clip(hexc("#efedf2")[None, :] * (0.93 + 0.07 * st)[:, None], 0, 1)


def tie(p, n, ao):
    return ramp(np.clip(lit(n, ao) * 0.8 + 0.2, 0, 1), FUZZ)


def tuft(p, n, ao):
    s = 0.5 + 0.5 * np.sin(p[:, 0] * 260 + p[:, 2] * 40)
    return ramp(np.clip(lit(n, ao) * 0.9 + 0.3 + (s - 0.5) * 0.14, 0, 1), HAIR)


def coat_outer(p, n, ao, G):
    """Plum leather with soft creases; violet piping down the front edge and the split."""
    c = ramp(np.clip(lit(n, ao) * 0.92 + (fbm(p * np.array([9.0, 9.0, 3.0])) - 0.5) * 0.3, 0, 1), LEATHER)
    # distance to the panel's free edges, in the grid
    d = np.full(len(p), 9.0)
    for line in (G[:, 0], G[:, -1]):
        a, b = line[:-1], line[1:]
        for i in range(len(a)):
            ab = b[i] - a[i]
            t = np.clip((p - a[i]) @ ab / (ab @ ab), 0, 1)
            d = np.minimum(d, np.linalg.norm(p - (a[i] + t[:, None] * ab), axis=1))
    return mix(c, TRIM * (0.7 + 0.4 * np.clip(ao, 0, 1))[:, None], smooth(0.03, 0.022, d))


def lining(p, n, ao):
    return ramp(np.clip(lit(n, ao) * 0.95 + 0.1, 0, 1), LINING)


def wing(p, n, ao, root, along, across):
    """Projected from the turnaround's back view: the outline in sable_pieces.W_EDGE is cut to it, so its pixels land on the card. The two wings mirror."""
    q = p - root
    y, x = (q @ along) / K.W_PX + K.W_Y0, (q @ across) / K.W_PX + K.W_XR
    return sample(WINGS, x, y) * (0.92 + 0.1 * np.clip(ao, 0, 1))[:, None]


def blade(p, n, ao):
    """Pale lilac steel, a violet sheen down the belly."""
    k = 0.5 + 0.5 * np.sin(p[:, 2] * 38.0 + np.abs(p[:, 0]) * 70.0)
    return mix(ramp(np.clip(lit(n, ao) * 0.7 + 0.42, 0, 1), FUZZ), hexc("#8a4fe0"), 0.42 * k)


def wrap(p, n, ao):
    """The hilt's violet cord."""
    w = 0.5 + 0.5 * np.sin((p[:, 2] + np.abs(p[:, 0]) * 1.5) * 300.0)
    return ramp(np.clip(lit(n, ao) * 0.7 + 0.12 + w * 0.2, 0, 1), LINING)


def face_fix(c, p):
    """The scan's face cleaned: its stitched mouth corners back to skin, the beauty mark redrawn."""
    f = smooth(0.0, 0.03, p[:, 1])
    ax = np.abs(p[:, 0] - K.FACE_X)
    skin_ = np.median(c[(ax > 0.03) & (ax < 0.05) & (np.abs(p[:, 2] - 1.53) < 0.01) & (p[:, 1] > 0.03)], axis=0)
    # the scan's skin toward the sheet's grey-lilac: cooler, and a step down so it stays apart from the hair in the toon light
    lum, sat = c.mean(1), (c.max(1) - c.min(1)) / np.maximum(c.max(1), 0.01)
    c = mix(c, np.clip(c * SKIN_LIFT, 0, 1), smooth(0.34, 0.42, lum) * smooth(0.76, 0.68, lum) * smooth(0.32, 0.24, sat))
    skin_ = skin_ * SKIN_LIFT
    # the mouth wiped and redrawn as the sheet's thin smile, the lower lip a soft shade under it
    mz, z_ = K.MOUTH[2] - 0.002, p[:, 2]
    c = mix(c, skin_ * 0.97, smooth(0.05, 0.042, ax) * smooth(0.024, 0.018, np.abs(z_ - mz)) * f)
    line = smooth(0.0032, 0.0016, np.abs(z_ - mz - 0.0075 * (ax / 0.036) ** 2))
    c = mix(c, hexc("#3a2c44"), 0.85 * line * smooth(0.034, 0.028, ax) * f)
    c = mix(c, hexc("#8b8095"), 0.35 * smooth(0.011, 0.003, np.abs(z_ - mz + 0.012)) * smooth(0.024, 0.012, ax) * f)
    dm = np.hypot(p[:, 0] - K.MARK[0], p[:, 2] - K.MARK[2])
    c = mix(c, skin_, smooth(0.022, 0.012, dm) * f)
    c = mix(c, hexc("#2a2233"), smooth(0.0052, 0.0036, dm) * f)
    # the collar's violet that bled onto the neck, back to skin
    lum, sat = c.mean(1), (c.max(1) - c.min(1)) / np.maximum(c.max(1), 0.01)
    c = mix(c, skin_ * 0.88, smooth(0.062, 0.05, ax) * smooth(1.385, 1.4, z_) * smooth(1.485, 1.47, z_) * smooth(-0.04, -0.02, p[:, 1]) * smooth(0.16, 0.24, sat))
    # behind the ears, where the buns were cut: the white scraps low on the collar go dark, higher up it is hair
    back = smooth(-0.03, -0.05, p[:, 1])
    c = mix(c, hexc("#2c2333"), smooth(1.46, 1.48, z_) * smooth(1.53, 1.52, z_) * back * smooth(0.3, 0.38, lum) * smooth(0.4, 0.3, sat))
    c = mix(c, hexc("#e4e2ea"), smooth(1.515, 1.535, z_) * smooth(1.6, 1.585, z_) * back * smooth(0.112, 0.1, ax))
    # the scan's speckled belt buckles down to one plain silver
    lum, sat = c.mean(1), (c.max(1) - c.min(1)) / np.maximum(c.max(1), 0.01)
    bk = smooth(0.76, 0.78, p[:, 2]) * smooth(0.95, 0.93, p[:, 2]) * smooth(0.3, 0.36, lum) * smooth(0.34, 0.24, sat)
    return mix(c, hexc("#a9a6b2"), bk)


def lid(p, n, ao, skin_c, liner_fn):
    c = skin_c * (0.84 + 0.16 * np.clip(ao, 0, 1))[:, None]
    return mix(c, hexc("#17121f"), liner_fn(p))
