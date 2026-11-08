"""Grimble's atlas (ART-1): every texel coloured from the sculpt. The toon shader only adds a soft light, so the paint carries its
own form shadow and top light. Value plan for the match camera: pale stone-grey skin, mid browns with clear plank lines, light
iron, saturated gold; dark only in the creases, big soft shapes, no fine speckle. Colours sRGB 0..1."""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import grimble_sculpt as G
from hem_sdf import fbm, smooth, worley

F = np.float32


def rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], F)


C = {"skin": rgb("85848b"), "skin_hi": rgb("b4b3b6"), "skin_sh": rgb("4c4954"), "skin_warm": rgb("8c6a62"), "stitch": rgb("26222a"),
     "iron": rgb("646b78"), "iron_hi": rgb("a2aab6"), "iron_sh": rgb("343843"), "rust": rgb("74402a"), "rust_hi": rgb("9a6038"),
     "wood": rgb("6e4726"), "wood_hi": rgb("97693e"), "wood_sh": rgb("432815"), "wood_gap": rgb("2c180c"),
     "burlap": rgb("6e573e"), "burlap_hi": rgb("93795a"), "burlap_sh": rgb("4c3a2a"),
     "gold": rgb("e0a418"), "gold_hi": rgb("f8d868"), "gold_sh": rgb("a8640e"),
     "brass": rgb("b08428"), "brass_hi": rgb("e2c070"), "brass_sh": rgb("6a4514"),
     "leather": rgb("64402a"), "leather_hi": rgb("8e6442"), "leather_sh": rgb("3e2414"),
     "loin": rgb("7c7642"), "loin_hi": rgb("aba564"), "loin_sh": rgb("423e22"),
     "lip": rgb("6a2a32"), "gum": rgb("7a1f2a"), "throat": rgb("1a0a0e"), "tooth": rgb("efe6c8"), "tooth_sh": rgb("a6966e"),
     "dark": rgb("2e2422"), "glass": rgb("a8d8b0"), "lamp": rgb("ffcf4a")}


def mix(a, b, t):
    t = np.asarray(t, F)
    if t.ndim == 1:
        t = t[:, None]
    return a * (1 - t) + b * t


def form(n):
    """A soft painted light, mostly from above (the match camera) and his front right."""
    l = np.array((0.22, 0.30, 0.93), F)
    l /= np.linalg.norm(l)
    return np.clip((n @ l) * 0.5 + 0.5, 0, 1)


def cavity(f, p, n, r=0.008):
    d = f.sample((p + n * r).astype(F))
    return np.clip(1.0 - d / r, 0, 1)


def ao(f, p, n, r=0.05):
    """Big contact shadows between forms (0 open .. 1 shut in)."""
    d = f.sample((p + n * r).astype(F))
    return np.clip(1.0 - d / r, 0, 1)


def ramp(n, sh, base, hi, cav=None, gain=0.55, a=0.16, b=0.52, c=0.64, d=0.97, top=0.7):
    k = form(n)
    o = mix(sh, base, smooth(a, b, k))
    o = mix(o, hi, smooth(c, d, k) * top)
    if cav is not None:
        o = o * (1 - gain * smooth(0.18, 0.95, cav))[:, None]
    return o


# scars on the body and limbs, model space, read off the turnaround


def _iron(p, n, f, lab, rust=0.28):
    cav = cavity(f, p, n, 0.008) if f is not None else None
    c = ramp(n, C["iron_sh"], C["iron"], C["iron_hi"], cav, 0.55)
    r = fbm(p[:, 0], p[:, 1], p[:, 2], 7.0, 3)
    rr = smooth(0.58 - rust * 0.25, 0.70 - rust * 0.25, r)
    if lab is not None:
        rr = np.maximum(rr, (lab == G.RUST) * smooth(0.46, 0.62, r))
    rc = ramp(n, C["rust"] * 0.6, C["rust"], C["rust_hi"], None)
    return mix(c, rc, rr * 0.82)


def plank(s, t, width, seed=1.0, grain=26.0):
    """s across the planks, t along: -> (value -1..1 per plank and grain, gap 0..1)."""
    i = np.floor(s / width)
    fr = s / width - i
    gap = smooth(0.09, 0.03, np.minimum(fr, 1 - fr))
    jit = np.sin(i * 12.9898 + seed) * 43758.5453
    jit = (jit - np.floor(jit)) * 2 - 1
    g = np.sin(t * grain * 0.3 + s * 40 + 2.2 * np.sin(s * 19 + t * 3.0))
    return 0.55 * jit + 0.20 * g, gap


def _wood(n, s, t, width, cav, seed=1.0):
    v, gap = plank(s, t, width, seed)
    c = ramp(n, C["wood_sh"], C["wood"], C["wood_hi"], cav, 0.42)
    c = c * (1.0 + 0.20 * v)[:, None]
    return mix(c, C["wood_gap"], gap * 0.85)


def links(c, p, n, per=0.040):
    """The lashing chain: one roped form painted as bright links."""
    s = (p[:, 0] * 0.6 + p[:, 1] * 0.4 + p[:, 2]) / per
    a = 0.5 + 0.5 * np.sin(s * math.tau)
    o = ramp(n, C["iron_sh"], C["iron"], C["iron_hi"])
    return o * (0.62 + 0.44 * a)[:, None]


def coins(p, n, f):
    cav = cavity(f, p, n, 0.012)
    c = ramp(n, C["gold_sh"], C["gold"], C["gold_hi"], cav, 0.65, 0.10, 0.45, 0.60, 0.95, 0.9)
    w = worley(p[:, 0], p[:, 1], p[:, 2], 17.0)
    d = w[0] if isinstance(w, tuple) else w
    return c * (0.58 + 0.50 * smooth(0.60, 0.22, d))[:, None]


def hoard(p, n, lab, f):
    cav = cavity(f, p, n, 0.014)
    oc = ao(f, p, n, 0.075)
    c = np.zeros((len(p), 3), F)
    for it in G.HOARD:
        m = lab == it["id"]
        if not m.any():
            continue
        q = (p[m] - it["c"]) @ it["R"]
        u, v, w = q[:, 0], q[:, 1], q[:, 2]
        nm, cm = n[m], cav[m]
        k = it["kind"]
        if k == "chest":
            top = (np.abs(nm @ it["R"][:, 0]) > 0.7) * 1.0
            s = np.where(top > 0, v, w + 0.3 * v)
            c[m] = _wood(nm, s, u, 0.062, cm, it["id"])
        elif k == "barrel":
            an = np.arctan2(v, u)
            c[m] = _wood(nm, an * 0.105, w, 0.046, cm, it["id"])
            cap_ = np.abs(nm @ it["R"][:, 2]) > 0.8
            c[m] = np.where(cap_[:, None], _wood(nm, u, v, 0.045, cm, it["id"] + 3), c[m])
        elif k in ("shield", "door"):
            c[m] = _wood(nm, u + 0.02, w, 0.072 if k == "door" else 0.055, cm, it["id"])
        elif k == "beam":
            c[m] = ramp(nm, C["wood_sh"], C["wood"] * 1.08, C["wood_hi"], cm, 0.4)
        elif k in ("plate", "ballplate"):
            c[m] = _iron(p[m], nm, None, None, 0.40) * (1 - 0.45 * smooth(0.2, 0.9, cm))[:, None]
        elif k == "ballwood":
            c[m] = _wood(nm, p[m][:, 2] + p[m][:, 0], p[m][:, 1], 0.08, cm, it["id"])
    m = (lab == G.IRON) | (lab == G.RUST)
    c[m] = _iron(p[m], n[m], f, lab[m])
    m = lab == G.BURLAP
    c[m] = ramp(n[m], C["burlap_sh"], C["burlap"], C["burlap_hi"], cav[m], 0.5)
    m = lab == G.GOLD
    c[m] = coins(p[m], n[m], f)
    m = lab == G.ROPE
    c[m] = links(c[m], p[m], n[m])
    m = lab == G.LEATHER
    c[m] = ramp(n[m], C["leather_sh"], C["leather"], C["leather_hi"], cav[m], 0.5)
    m = lab == G.DARK
    c[m] = C["dark"]
    g = lab == G.GOLD
    a = 0.40 * smooth(0.25, 1.0, oc)
    a[g] *= 0.5
    return c * (1 - a)[:, None]


def gear(p, n, lab, f):
    """Everything else, by label."""
    cav = cavity(f, p, n, 0.008) if f is not None else np.zeros(len(p), F)
    c = np.zeros((len(p), 3), F) + C["iron"]
    m = (lab == G.IRON) | (lab == G.RUST)
    if m.any():
        c[m] = _iron(p[m], n[m], f, lab[m])
    for lb, a, b, d in ((G.LEATHER, "leather_sh", "leather", "leather_hi"), (G.LOIN, "loin_sh", "loin", "loin_hi"), (G.BRASS, "brass_sh", "brass", "brass_hi")):
        m = lab == lb
        if m.any():
            c[m] = ramp(n[m], C[a], C[b], C[d], cav[m], 0.5, 0.12, 0.46, 0.58, 0.92, 0.85)
    m = lab == G.WOOD
    if m.any():
        c[m] = ramp(n[m], C["wood_sh"], C["wood"], C["wood_hi"], cav[m], 0.4)
    m = lab == G.GLASS
    if m.any():
        c[m] = mix(rgb("1fbf62"), rgb("c8ffd0"), smooth(0.62, 0.98, form(n[m])))
    m = lab == G.LAMP
    if m.any():
        q = p[m]
        an = np.arctan2(q[:, 1], q[:, 0]) * 2 / math.pi
        c[m] = mix(rgb("fff2b0"), C["lamp"], smooth(0.0, 0.05, np.abs(q[:, 2] + 0.105)))
    m = lab == G.DARK
    if m.any():
        c[m] = C["dark"]
    m = lab == G.ROPE
    if m.any():
        c[m] = links(c[m], p[m], n[m], 0.08)
    return c


def flat(p, n, key):
    return ramp(n, C[key + "_sh"], C[key], C[key + "_hi"])


# ------------------------------------------------------------------ v2's scan paint, fixed where it blurs (canon: grimble_v2/index.md)
VEIN_KEY = rgb("a648f0")     # the corruption veins' painted colour: warden_look's paint_glow keys on it
SQUINT_R = (0.030, 0.020)    # (m) the smug squint's lid, half width and half height round his left eye
MOUTH_TOP = 1.205            # (m) the grin's top on the fitted head (above it: cheeks, pale like the teeth)


def scan_face(p, c):
    """His left eye a smug squint (a heavy lid over its top), the scan's blurred teeth silver scrap metal, the yellow one gold,
    the gums a deep purple. p: texel positions on the fitted body, c: the scan's paint there (both n x 3)."""
    lum = c @ np.array((0.3, 0.59, 0.11), F)
    face = face_mask(p)
    white = face & (lum > 0.62) & (p[:, 0] < -0.02) & (p[:, 2] > G.EYE_C[2] - 0.04)
    if white.any():
        e = p[white].mean(0)
        d = ((p[:, 0] - e[0]) / SQUINT_R[0]) ** 2 + ((p[:, 2] - e[2]) / SQUINT_R[1]) ** 2
        lid_z = e[2] + 0.004
        pupil = white & ((p[:, 0] - e[0] - 0.004) ** 2 + (p[:, 2] - e[2] + 0.001) ** 2 < 0.0065 ** 2)
        c[pupil] = C["throat"]
        lid = face & (d < 1.0) & (p[:, 2] > lid_z)
        c[lid] = mix(C["skin_sh"], C["skin"], smooth(lid_z, e[2] + SQUINT_R[1], p[lid, 2]))
        c[face & (d < 1.1) & (np.abs(p[:, 2] - lid_z) < 0.002)] = C["skin_sh"] * 0.6
    mouth = face & (p[:, 2] < MOUTH_TOP) & (np.abs(p[:, 0]) < 0.12)
    r, g, b = c[:, 0], c[:, 1], c[:, 2]
    gold = mouth & (r - b > 0.14) & (g - b > 0.08)
    tooth = mouth & (lum > 0.45) & ~gold
    gum = mouth & (b - g > 0.06) & (lum < 0.45)
    c[tooth] = mix(C["iron"], C["iron_hi"] * 1.15, smooth(0.45, 0.75, lum[tooth]))
    c[gold] = mix(C["gold_sh"], C["gold_hi"], smooth(0.35, 0.75, lum[gold]))
    c[gum] = mix(c[gum], rgb("6a2a6e"), 0.6)
    return c


def face_mask(p):
    return (p[:, 1] > G.HEAD_C[1] + 0.06) & (p[:, 2] > G.HEAD_C[2] - 0.12)


def vein_key(img, mask, r=6):
    """The purple veins on his skin, found by contrast (more purple than the skin round them, so the purple arm's own colour
    stays) and painted VEIN_KEY, which glows."""
    pur = (img[..., 0] - img[..., 1]) + (img[..., 2] - img[..., 1])
    m = mask.astype(F)
    k = np.ones(2 * r + 1, F)
    blur = lambda a: np.apply_along_axis(lambda v: np.convolve(v, k, "same"), 0, np.apply_along_axis(lambda v: np.convolve(v, k, "same"), 1, a))
    local = blur(pur * m) / np.maximum(blur(m), 1)
    vein = mask & (pur > 0.2) & (pur - local > 0.05)
    img[vein] = mix(img[vein], VEIN_KEY, 0.85)
    return int(vein.sum())
