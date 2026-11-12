"""Vespyx's coat, painted straight off the shape fields. Colours are sRGB 0..1."""
import numpy as np

from boki_sdf import value_noise


def hexc(s):
    return np.array([int(s[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


PLUM = hexc("7c4fa2")
PLUM_LIGHT = hexc("9a6cbc")
LILAC = hexc("e2cff2")
SOCK = hexc("4c2858")
INK = hexc("2b1533")
EAR_IN = hexc("cfa8dc")
SHELL = hexc("9a4674")
SHELL_LIGHT = hexc("d680ac")
SHELL_DARK = hexc("5e264c")
BLUSH = hexc("ff8aa0")
NOSE = hexc("2a1830")
MOUTH_DARK = hexc("54172f")
TONGUE = hexc("f0708a")
WOOD = hexc("8a5a30")
STEEL = hexc("aeb8c8")
BERRY = hexc("e23a5a")
IRIS = hexc("9de23a")
LID = PLUM


def sat(x):
    return np.clip(x, 0.0, 1.0)


def mixc(a, b, t):
    t = t[..., None]
    return a * (1 - t) + b * t


def edge(x, w):
    """0 below -w, 1 above +w."""
    return sat(x / (2 * w) + 0.5)


def paint_body(p, n, prim):
    """p, n: (N, 3) points and normals on the body; prim: name -> primitive."""
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    ax = np.abs(x)
    jag = (value_noise(p * v3s(70, 16, 70)) - 0.5) * 0.030       # hair-edged boundaries between coat colours
    fine = value_noise(p * v3s(120, 34, 120))
    col = mixc(PLUM, PLUM_LIGHT, sat(fine * 0.75 - 0.15) * 0.45)
    # lower face: a fox mask, a W under the eyes that sweeps up into the cheek ruff
    yb = np.interp(ax, [0, 0.022, 0.055, 0.12, 0.20, 0.34], [0.442, 0.438, 0.385, 0.352, 0.385, 0.545])
    head = (y > 0.285) | (z < -0.20)
    mask = edge(yb + jag * 0.8 - y, 0.004) * edge(-z + 0.05 + (ax - 0.2) * 0.8, 0.02) * head
    col = mixc(col, LILAC, mask)
    # bib and belly
    bib = edge(1.0 - (x / 0.098) ** 2 - ((y - 0.235) / 0.135) ** 2 + jag * 6, 0.05) * edge(0.0 - z, 0.03)
    belly = edge(0.135 - y + jag, 0.006) * edge(0.10 - ax + jag, 0.008) * edge(0.14 - z, 0.03)
    col = mixc(col, LILAC, sat(bib + belly) * (~head))
    col = mixc(col, SOCK, edge(0.098 - y + jag * 0.35, 0.005) * (y < 0.2))
    # ears: pale in the scoop, dark tips with a torn edge
    for sd in "LR":
        hole = prim["earhole" + sd].d(p)
        ear = prim["ear2" + sd].d(p) < 0.03
        ear1 = prim["ear1" + sd].d(p) < 0.03
        tip = edge(y - 0.745 + jag * 1.4 + (0.215 - ax) * 0.25, 0.005) * ear
        col = mixc(col, EAR_IN, edge(0.006 - hole, 0.004) * (ear | ear1))
        col = mixc(col, SOCK, tip)
    # blush and nose
    for sx in (-1.0, 1.0):
        q = (p - np.array([sx * 0.168, 0.392, 0])) / np.array([0.058, 0.033, 1.0])
        blush = np.exp(-(q[:, 0] ** 2 + q[:, 1] ** 2) * 1.25) * (z < -0.1)
        col = mixc(col, BLUSH, blush * 0.72)
    nose = edge(0.0035 - prim["nose"].d(p), 0.0015)
    col = mixc(col, NOSE, nose)
    return col


def paint_shell(p, n, nearest_gap, light=SHELL_LIGHT, shell=SHELL, dark=SHELL_DARK):
    """Glossy plates: pale catch-light, ink in the creases (nearest_gap small between two plates)."""
    h = np.array([-0.35, 0.8, -0.48])
    h = h / np.linalg.norm(h)
    spec = sat((n @ h - 0.82) / 0.11) ** 2
    up = sat(n[:, 1] * 0.5 + 0.5)
    col = mixc(dark, shell, sat(up * 1.5))
    col = mixc(col, light, spec * 0.85)
    gloss = sat((n @ h - 0.965) / 0.02)
    col = mixc(col, np.array([1.0, 0.86, 0.94]), gloss * 0.8)
    return mixc(col, dark * 0.5, edge(0.006 - nearest_gap, 0.003))


def v3s(*a):
    return np.array(a, dtype=float)



def paint_piece(pc, q, nn, prim):
    """The colour of one piece of the creature at q."""
    if pc.name == "body":
        return paint_body(q, nn, prim)
    if pc.name == "tail" or pc.name.startswith("claw") or pc.name == "collar":
        ds = np.sort(np.stack([pr.d(q) for pr in pc.shape.prims], -1), axis=-1)
        gap = ds[:, 1] - ds[:, 0] if pc.name == "tail" else np.full(len(q), 1.0)
        return paint_shell(q, nn, gap)
    if pc.name.startswith("gp_"):
        if pc.look == "white":
            return np.ones((len(q), 3))
        return paint_shell(q, nn, np.full(len(q), 1.0))
    if pc.name == "sting":
        return np.tile(np.array([0.72, 1.0, 0.3]), (len(q), 1))
    return tool_colour(pc.name, q)


def tool_colour(name, q):
    if name.endswith("handle"):
        return np.tile(WOOD, (len(q), 1))
    if name == "berry":
        return np.tile(BERRY, (len(q), 1))
    return np.tile(STEEL, (len(q), 1))
