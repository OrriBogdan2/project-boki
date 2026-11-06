"""Grimble's atlas (ART-1): every texel coloured from the sculpt. The toon shader only adds a soft light, so the paint carries its
own form shadow and top light. Value plan for the match camera: pale stone-grey skin, mid browns with clear plank lines, light
iron, saturated gold; dark only in the creases, big soft shapes, no fine speckle. Colours sRGB 0..1."""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import grimble_sculpt as G
from hem_sdf import fbm, smooth, vnoise, worley

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


def seg_d(p, a, b):
    a, b = np.array(a, F), np.array(b, F)
    ab = b - a
    t = np.clip(((p - a) @ ab) / float(ab @ ab), 0, 1)
    return np.linalg.norm(p - (a + ab * t[:, None]), axis=1), t * float(np.linalg.norm(ab))


def stitch(c, p, pts, w=0.0032, per=0.021, tick=0.0115):
    """A dark scar along a polyline, with short cross stitches: reads at the viewer camera, gone (quietly) at match zoom."""
    best = np.full(len(p), 9.0, F)
    along = np.zeros(len(p), F)
    run = 0.0
    for a, b in zip(pts[:-1], pts[1:]):
        d, s = seg_d(p, a, b)
        m = d < best
        best[m] = d[m]
        along[m] = s[m] + run
        run += float(np.linalg.norm(np.array(b, F) - np.array(a, F)))
    near = best < tick * 1.4
    line = smooth(w, w * 0.45, best)
    t = np.abs(((along / per) % 1.0) - 0.5) * per
    ticks = smooth(0.0028, 0.0014, t) * smooth(tick, tick * 0.75, best)
    a = np.maximum(line, ticks) * near
    return mix(c, C["stitch"], a * 0.92)


# scars on the body and limbs, model space, read off the turnaround
SCARS = [
    [(-0.150, 0.100, 1.085), (-0.060, 0.128, 1.020), (0.05, 0.113, 0.940), (0.135, 0.070, 0.880)],      # (mostly under the strap)
    [(0.238, 0.040, 1.170), (0.170, 0.095, 1.120), (0.11, 0.125, 1.105)],
    [(-0.275, 0.042, 0.945), (-0.240, 0.040, 0.905), (-0.300, 0.028, 0.885)],
    [(0.105, 0.052, 0.560), (0.163, 0.074, 0.548), (0.225, 0.042, 0.555)],
    [(-0.105, 0.052, 0.500), (-0.163, 0.072, 0.490), (-0.225, 0.040, 0.495)],
    [(0.118, 0.018, 0.255), (0.163, 0.040, 0.245), (0.205, 0.015, 0.25)],
    [(0.060, -0.205, 1.215), (0.150, -0.160, 1.235)],
]


def skin(p, n, lab, f):
    cav = cavity(f, p, n, 0.010)
    oc = ao(f, p, n, 0.045)
    c = ramp(n, C["skin_sh"], C["skin"], C["skin_hi"], cav, 0.62)
    # stone mottling, broad, and a warm flush low on the limbs and in the creases, the art's
    mot = fbm(p[:, 0], p[:, 1], p[:, 2], 6.0, 3)
    c = c * (0.93 + 0.14 * mot)[:, None]
    c = mix(c, C["skin_warm"], smooth(0.2, 0.8, cav) * 0.30)
    c = c * (1 - 0.34 * smooth(0.25, 1.0, oc))[:, None]
    for s in SCARS:
        c = stitch(c, p, s)
    return np.clip(c, 0, 1)


def head(p, n, lab, f):
    c = skin(p, n, lab, f)
    h = p - G.HEAD_C
    # the forehead seam, a short cross seam, a crack down his left cheek
    c = stitch(c, p, [tuple(G.HEAD_C + (-0.006, 0.070, 0.095)), tuple(G.HEAD_C + (0.004, 0.012, 0.117)), tuple(G.HEAD_C + (0.0, -0.06, 0.112))], 0.0024, 0.0145, 0.0078)
    c = stitch(c, p, [tuple(G.HEAD_C + (-0.052, 0.074, 0.083)), tuple(G.HEAD_C + (-0.018, 0.09, 0.094)), tuple(G.HEAD_C + (0.010, 0.082, 0.098))], 0.0022, 0.0145, 0.0065)
    c = stitch(c, p, [(-0.075, 0.10, 1.262), (0.0, 0.03, 1.24)], 0.0, 0.016, 0.0)
    # the other socket, stitched shut: one dark seam, heavy cross stitches
    c = stitch(c, p, [tuple(G.HEAD_C + (-0.074, 0.070, 0.016)), tuple(G.HEAD_C + (-0.052, 0.092, 0.010)), tuple(G.HEAD_C + (-0.030, 0.100, 0.014))], 0.0030, 0.0120, 0.0115)
    # the socket's shade, so the monocle sits in a pit
    d = np.linalg.norm(p - G.EYE_C, axis=1)
    c = c * (1 - 0.5 * smooth(0.062, 0.042, d))[:, None]
    # dark under the lips
    m = lab == G.MOUTH
    k = np.clip((h[:, 1] - 0.03) / 0.08, 0, 1)
    c[m] = mix(C["throat"], C["gum"], smooth(0.35, 1.0, k[m]))
    m = lab == G.LIP
    c[m] = ramp(n[m], C["throat"], C["lip"], rgb("a85058"))
    m = lab == G.DARK
    c[m] = C["dark"]
    return c


def tooth(p, n, lab, f):
    k = form(n)
    c = mix(C["tooth_sh"], C["tooth"], smooth(0.18, 0.55, k))
    h = p - G.HEAD_C
    # yellowed and dirty toward the gum
    g = np.abs(h[:, 2] - G.grin_z(h[:, 0])) / np.maximum(G.grin_h(h[:, 0]), 1e-4)
    return mix(c, rgb("8a6a3a"), smooth(0.55, 1.05, g) * 0.75)


def eye(p, n):
    """The one eye: green glass depth, a dark rim, a thin cat's slit, a hot crescent of light."""
    d = p - G.EYE_C
    ax = np.array(G.MONO_AX, F)
    u = np.cross((0, 0, 1), ax)
    u /= np.linalg.norm(u)
    v = np.cross(ax, u)
    x, y = d @ u, d @ v
    r = np.sqrt(x * x + y * y)
    c = mix(rgb("6fe88a"), rgb("14b858"), smooth(0.004, 0.018, r))
    c = mix(c, rgb("076a36"), smooth(0.018, 0.032, r))
    c = mix(c, rgb("053a22"), smooth(0.030, 0.036, r))
    c = mix(c, rgb("05070a"), smooth(0.0044, 0.0028, np.abs(x)) * smooth(0.0225, 0.0185, np.abs(y)))
    c = mix(c, rgb("f4fff0"), smooth(0.0085, 0.0045, np.sqrt((x - 0.011) ** 2 + (y - 0.014) ** 2)))
    return c


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


def loincloth(p, n, lab, f):
    c = gear(p, n, lab, f)
    # grimy toward the torn hem
    return mix(c, C["loin_sh"], smooth(0.56, 0.44, p[:, 2]) * 0.55)


def flat(p, n, key):
    return ramp(n, C[key + "_sh"], C[key], C[key + "_hi"])
