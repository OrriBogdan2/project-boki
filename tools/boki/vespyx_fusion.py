"""The Venom Fusion: what Vespyx becomes on a Hunter. Coordinates are the torso's (MergeLook hangs parts there, a 1.0
Hunter, head top about y 1.12, its back toward +z). Its tail rises off the lower back and hangs over the head, its
pincers ride the shoulders, its ears and ruff frame the neck."""
import math

import numpy as np

import vespyx_paint as paint
from boki_sdf import Cone, Ellipsoid, Shape, frame, v3

SIDES = (("L", -1.0), ("R", 1.0))
TAIL = [v3(0, 0.42, 0.16), v3(0.02, 0.56, 0.33), v3(0.05, 0.76, 0.44), v3(0.08, 0.98, 0.43), v3(0.10, 1.18, 0.33),
        v3(0.11, 1.32, 0.17), v3(0.11, 1.36, -0.01), v3(0.10, 1.29, -0.15)]
RADII = [0.112, 0.118, 0.118, 0.112, 0.103, 0.092, 0.08]
STING_C = v3(0.095, 1.24, -0.20)
STING_DIR = np.array((0.0, -0.55, -0.83))


def tail_shape():
    prims = []
    for i, r in enumerate(RADII):
        a, b = TAIL[i], TAIL[i + 1]
        d = b - a
        prims.append(Ellipsoid("plate%d" % i, "tail%d" % (i + 1), (a + b) * 0.5, v3(r, r * 0.96, np.linalg.norm(d) * 0.72),
                               rot=frame(d, v3(1, 0, 0)), k=0.008))
    return Shape(prims)


def sting_shape():
    return Shape([Cone("bulb", "sting", STING_C, STING_C + STING_DIR * 0.24, 0.125, 0.008, k=0)])


def claw_shape(sd, sx):
    s = v3(sx, 1, 1)
    claw, nip = "claw." + sd, "nip." + sd
    return Shape([
        Ellipsoid("palm", claw, v3(0.36, 0.86, -0.05) * s, v3(0.13, 0.105, 0.135), k=0.01),
        Cone("finger", claw, v3(0.42, 0.87, -0.14) * s, v3(0.43, 0.88, -0.27) * s, 0.066, 0.046, k=0.02),
        Cone("fingertip", claw, v3(0.43, 0.88, -0.27) * s, v3(0.34, 0.89, -0.35) * s, 0.046, 0.005, k=0.012),
        Cone("nip0", nip, v3(0.28, 0.86, -0.15) * s, v3(0.26, 0.87, -0.26) * s, 0.054, 0.04, k=0.0),
        Cone("nip1", nip, v3(0.26, 0.87, -0.26) * s, v3(0.32, 0.88, -0.335) * s, 0.04, 0.005, k=0.012),
    ])


def ruff_shape():
    prims = [Ellipsoid("collar", "ruff", v3(0, 0.80, 0.0), v3(0.22, 0.09, 0.2), k=0)]
    for i in range(11):
        a = math.tau * i / 11 + 0.3
        o = v3(math.cos(a) * 0.18, 0.80, math.sin(a) * 0.16)
        t = v3(math.cos(a) * 0.40, 0.70 + 0.05 * (i % 2), math.sin(a) * 0.34)
        prims.append(Cone("tuft%d" % i, "ruff", o, t, 0.075, 0.004, k=0.03))
    return Shape(prims)


def ear_shape(sd, sx):
    n = v3(sx * 0.3, 0.0, -1.0)
    base = v3(sx * 0.13, 1.02, 0.03)
    mid = v3(sx * 0.21, 1.20, 0.05)
    tip = v3(sx * 0.29, 1.40, 0.07)
    bone = "ear." + sd
    ear = (tip - base) / np.linalg.norm(tip - base)
    nn = n / np.linalg.norm(n)
    return Shape([
        Cone("ear1", bone, base, mid, 0.135, 0.095, k=0.03, flat=0.36, flat_axis=n),
        Cone("ear2", bone, mid, tip, 0.095, 0.004, k=0.012, flat=0.36, flat_axis=n),
        Ellipsoid("hole", bone, base + ear * 0.16 + nn * 0.048, v3(0.08, 0.15, 0.034), rot=frame(nn, ear), k=0.014, sub=True),
    ])


def parts():
    """name -> (Shape, tris, slot, paint name)."""
    out = {"tail": (tail_shape(), 900, 0, "shell"), "sting": (sting_shape(), 200, 1, "glow"),
           "ruff": (ruff_shape(), 500, 0, "ruff")}
    for sd, sx in SIDES:
        out["claw" + sd] = (claw_shape(sd, sx), 420, 0, "shell")
        out["ear" + sd] = (ear_shape(sd, sx), 260, 0, "ear")
    return out


def bones():
    b = {"root": ((0, 0, 0), (0, 0.2, 0), None), "ruff": ((0, 0.8, 0), (0, 0.95, 0), "root")}
    parent = "root"
    for i in range(7):
        n = "tail%d" % (i + 1)
        b[n] = (tuple(TAIL[i]), tuple(TAIL[i + 1]), parent)
        parent = n
    b["sting"] = (tuple(TAIL[7]), tuple(STING_C), "tail7")
    for sd, sx in SIDES:
        s = v3(sx, 1, 1)
        b["claw." + sd] = (tuple(v3(0.28, 0.86, -0.0) * s), tuple(v3(0.36, 0.86, -0.13) * s), "root")
        b["nip." + sd] = (tuple(v3(0.28, 0.86, -0.15) * s), tuple(v3(0.26, 0.87, -0.26) * s), "claw." + sd)
        b["ear." + sd] = (tuple(v3(0.13, 1.02, 0.03) * s), tuple(v3(0.29, 1.40, 0.07) * s), "root")
    return b


def idle(t):
    """The tail sways over the head, ready to strike; the pincers snip now and then; the ears twitch."""
    p = {}
    for i in range(7):
        ph = math.tau * (t - i * 0.09)
        p["tail%d" % (i + 1)] = (0.028 * math.sin(ph), 0.05 * math.sin(ph + 0.8), 0)
    snip = max(0.0, math.sin(math.tau * t * 3)) ** 4 * (1 if t > 0.55 else 0)
    p["nip.L"] = (0, -0.45 * snip, 0)
    p["nip.R"] = (0, 0.45 * snip, 0)
    flick = max(0.0, math.sin(math.tau * (t * 4 - 0.2))) ** 8
    p["ear.L"] = (0.05 * flick, 0, 0)
    p["ear.R"] = (0.05 * flick, 0, 0)
    return p


CLIPS = {"idle": (3.0, True, idle)}


def paint_piece(name, p, n, prims):
    if name == "shell":
        ds = np.sort(np.stack([pr.d(p) for pr in prims], -1), axis=-1)
        gap = ds[:, 1] - ds[:, 0] if len(prims) > 6 else np.full(len(p), 1.0)
        return paint.paint_shell(p, n, gap)
    if name == "ruff":
        return paint.mixc(paint.LILAC, paint.PLUM_LIGHT, paint.sat(np.abs(p[:, 1] - 0.72) / 0.1))
    if name == "ear":
        hole = next(pr for pr in prims if pr.name == "hole")
        col = np.tile(paint.PLUM, (len(p), 1))
        col = paint.mixc(col, paint.EAR_IN, paint.edge(0.006 - hole.d(p), 0.004))
        return paint.mixc(col, paint.SOCK, paint.edge(p[:, 1] - 1.26, 0.006))
    return np.tile(np.array([0.72, 1.0, 0.3]), (len(p), 1))
