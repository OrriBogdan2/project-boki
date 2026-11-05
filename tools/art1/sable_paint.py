"""ART-1 Sable: the texel-space paint (recipe: kael_paint.py): arrays of texels (world position, normal, occlusion) to sRGB in 0..1. Palette off sable_FINAL_sheet: dark plum leather,
purple trim and lining, pearl moth wings with grey-lilac eye-spots, white hair, lilac skin, silver, dark wood, violet glow."""
import os
import numpy as np
from meshkit import norm, smooth
from kael_paint import hexc, mix, fbm, lit, ramp, hash3
import sable_pieces as K
import imgio

ART = os.path.expanduser("~/meshy/sable_f/proj/")      # crops of the owner's sheets
WINGS, HEAD, GUN = imgio.load(ART + "wings.png"), imgio.load(ART + "head.png"), imgio.load(ART + "gun.png")

LEATHER = [hexc("#1d1520"), hexc("#2c2130"), hexc("#3f2f45"), hexc("#5a4562"), hexc("#7d6a86")]
LINING = [hexc("#2d1147"), hexc("#46196e"), hexc("#5f2595"), hexc("#7a35b5"), hexc("#9a55d2")]
HAIR = [hexc("#8f8a9c"), hexc("#b6b2c2"), hexc("#d5d2dd"), hexc("#ecebf1"), hexc("#ffffff")]
SKIN = [hexc("#5e5470"), hexc("#7e7492"), hexc("#a097b2"), hexc("#bcb4cb"), hexc("#d6d0e0")]
SILVER = [hexc("#4c4a58"), hexc("#7b7988"), hexc("#a9a8b5"), hexc("#d3d3dc"), hexc("#fbfbff")]
WOOD = [hexc("#35202a"), hexc("#4c2c36"), hexc("#643b45"), hexc("#7f4f5a"), hexc("#9d6a75")]
TRIM = hexc("#6a2aa8")


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
    c = mix(c, np.clip((col - lum) * 1.9 + lum, 0, 1) * np.array([1.06, 0.92, 1.3]), purple)
    dark = smooth(0.32, 0.16, lum[:, 0]) * (p[:, 2] < K.NECK_Z)
    c = c + dark[:, None] * np.array([0.02, 0.012, 0.03])
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


def bola(p, n, ao):
    t = lit(n, ao) * 1.0 + 0.04
    band = smooth(0.012, 0.007, np.abs(np.modf((p[:, 2] + p[:, 0] * 0.0) * 14.0 + 40)[0] - 0.5) / 14.0 * 3.0)
    return ramp(np.clip(t - band * 0.28, 0, 1), SILVER)


def feather(p, n, ao):
    """White, a fine comb of barbs along the feather, a grey quill."""
    x = p[:, 0] * 300.0 + p[:, 2] * 380.0
    barbs = 0.5 + 0.5 * np.sin(x + 3.0 * fbm(p * 30.0, 2))
    return ramp(np.clip(0.74 + lit(n, ao) * 0.26 + (barbs - 0.5) * 0.2, 0, 1), HAIR)


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


def braid(p, n, ao, path):
    """Three strands: diagonal gaps crossing the lobes, dark in the weave."""
    u, d, sd = path_u(p, path)
    k = u * 9.0
    w = np.abs(((k + sd * 22.0) % 1.0) - 0.5) * 2
    w2 = np.abs(((k - sd * 22.0) % 1.0) - 0.5) * 2
    gap = smooth(0.18, 0.04, np.where(np.floor(k) % 2 == 0, w, w2))
    return ramp(np.clip(lit(n, ao) * 0.85 + 0.24 - gap * 0.6, 0, 1), HAIR)


def tuft(p, n, ao):
    s = 0.5 + 0.5 * np.sin(p[:, 0] * 260 + p[:, 2] * 40)
    return ramp(np.clip(lit(n, ao) * 0.9 + 0.3 + (s - 0.5) * 0.14, 0, 1), HAIR)


def coat_outer(p, n, ao, G):
    """Plum leather with soft creases; a purple piped hem and front edge."""
    c = ramp(np.clip(lit(n, ao) * 0.92 + (fbm(p * np.array([9.0, 9.0, 3.0])) - 0.5) * 0.3, 0, 1), LEATHER)
    # distance to the panel's free edges, in the grid
    d = np.full(len(p), 9.0)
    for line in (G[-1], G[:, 0], G[:, -1]):
        a, b = line[:-1], line[1:]
        for i in range(len(a)):
            ab = b[i] - a[i]
            t = np.clip((p - a[i]) @ ab / (ab @ ab), 0, 1)
            d = np.minimum(d, np.linalg.norm(p - (a[i] + t[:, None] * ab), axis=1))
    return mix(c, TRIM * (0.7 + 0.4 * np.clip(ao, 0, 1))[:, None], smooth(0.03, 0.022, d))


def lining(p, n, ao):
    return ramp(np.clip(lit(n, ao) * 0.95 + 0.1, 0, 1), LINING)


def wing(p, n, ao, root, along, across, s):
    """Projected from the turnaround's back view: the outline in sable_pieces.W_EDGE is cut to it, so its pixels land on the wing."""
    q = p - root
    y, x = (q @ along) / K.W_PX, (q @ across) / K.W_PX + K.W_XR
    if s < 0:
        x = K.W_MIRROR - x
    return sample(WINGS, x, y) * (0.92 + 0.1 * np.clip(ao, 0, 1))[:, None]


def pistol_art(p, n, ao, fallback):
    """The weapon sheet's side view on the pistol's own (u, v) plane: dark wood and silver per the master (the sheet's brass goes to silver, its wood darker); off the drawing, the fallback paint."""
    g = K.grip("R")
    u, v = g[2] - p[:, 2], p[:, 1] - g[1]
    px, py = 25 + (K.MUZZLE_U - u) * 1780.0, 100 + (0.052 - v) * 1780.0
    c = sample(GUN, px, py)
    lum, sat = c.mean(1), (c.max(1) - c.min(1)) / np.maximum(c.max(1), 0.01)
    warm = smooth(0.15, 0.3, sat) * (c[:, 0] > c[:, 2])
    wood = mix(c, c * np.array([0.72, 0.56, 0.62]), warm)
    brass = warm * smooth(0.42, 0.56, lum)
    out = mix(wood, np.stack([lum, lum, lum * 1.06], 1) * 1.05, brass)
    off = smooth(0.72, 0.8, lum) * smooth(0.12, 0.06, sat)             # the sheet's grey ground
    fb = fallback(p, n, ao)
    return mix(out, fb, off)


def face_art(col, p, n):
    """The master's head close-up on the face, front on, graded to the scan's skin. -> (colour, mask)."""
    px, py = 193 - (p[:, 0] - K.FACE_X) * 1467.0, 252 + (K.EYE[2] - p[:, 2]) * 1338.0
    c = sample(HEAD, px, py)
    m = smooth(1.0, 0.8, np.hypot((px - 193) / 128.0, (py - 292) / 118.0)) * smooth(0.02, 0.05, p[:, 1]) * smooth(0.3, 0.6, n[:, 1])
    ref = (np.hypot(px - 193, py - 372) < 26) & (m > 0.9)              # the chin, to match the two skins
    if ref.sum() > 20:
        c = np.clip(c * (np.median(col[ref], 0) / np.maximum(np.median(c[ref], 0), 0.02)), 0, 1)
    return c, m


def lacing(c, p):
    """The master's corset lacing on the coat's lower back."""
    z0, z1 = 0.915, 1.125
    k = (p[:, 2] - z0) / (z1 - z0)
    w = 0.032 - 0.016 * k
    t = (k * 5.0) % 1.0
    line = np.abs(np.abs(p[:, 0]) / w - np.abs(2 * t - 1))
    m = smooth(0.2, 0.1, line) * (p[:, 1] < -0.04) * (np.abs(p[:, 0]) < w * 1.08) * (k > 0) * (k < 1)
    c = mix(c, hexc("#17111d"), (np.abs(p[:, 0]) < 0.011 + 0 * k) * (p[:, 1] < -0.04) * (k > 0) * (k < 1) * 0.75)
    return mix(c, hexc("#b9acc9"), m)


def lid(p, n, ao, skin_c, liner_fn):
    c = skin_c * (0.84 + 0.16 * np.clip(ao, 0, 1))[:, None]
    return mix(c, hexc("#17121f"), liner_fn(p))
