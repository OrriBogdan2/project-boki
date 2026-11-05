"""Gloamshell, a garden snail whose shell is smoked obsidian: shapes and coat. Game axes as vespyx.py.
NEW design (roster 50, #15), owner approval pending. No legs: a foot that glides, a head on a soft neck, two feelers
with glowing tips (the face keeps its eyes on the head, so it emotes like every other Boki)."""
import math

import numpy as np

import boki_grown
import boki_tools
from boki_sdf import Cone, Ellipsoid, Shape, frame, v3, value_noise
from vespyx_paint import edge, hexc, mixc, paint_shell, sat, tool_colour
from vespyx_sides import SIDES

SCALE = 0.95
HEAD_C = v3(0, 0.3, -0.25)
HEAD_R = v3(0.135, 0.125, 0.125)
EYE_C = v3(0.062, 0.33, -0.34)
EYE_R = v3(0.042, 0.046, 0.027)
EYE_YAW = 0.42
GLOW_PIECES = ("tips",)
LIT_PIECES = ()
BERRY_C = v3(0, 0.05, -0.5)
FACE = {"mouth_w": 0.045, "mouth_y": 0.262, "mouth_z": -0.36, "cat_mouth": False, "brow_x": 0.07, "brow_up": 0.02,
        "brow_k": 0.75, "fang_k": 0.0}
# the shell: a log spiral in the side plane round COIL_C, from the mouth (at the body) up over the back
COIL_C = v3(0, 0.33, 0.1)
COIL_R0 = 0.19           # m, radius of the coil at the mouth
COIL_B = 0.16             # how fast the coil tightens per radian
COIL_TURNS = 2.6         # length of the coil in half-turns (pi radians each)
COIL_PHI0 = -1.87        # the mouth sits low and forward
STALK_TIP = v3(0.085, 0.56, -0.29)


def eye_frame(sx):
    out = v3(sx * math.sin(EYE_YAW), 0.08, -math.cos(EYE_YAW))
    fr = frame(out, v3(0, 1, 0))
    if (fr[0] @ v3(sx, 0, 0)) < 0:
        fr[0] = -fr[0]
    return fr


def whorl_points(n=26):
    """(theta, centre, tube radius) along the spiral tube, mouth first."""
    out = []
    for i in range(n):
        th = COIL_TURNS * math.pi * i / (n - 1)
        r = COIL_R0 * math.exp(-COIL_B * th)
        ph = th + COIL_PHI0
        out.append((th, COIL_C + v3(0, math.sin(ph), math.cos(ph)) * r, 0.5 * r))
    return out


def body_prims():
    p = [
        Ellipsoid("foot", "spine", v3(0, 0.085, -0.06), v3(0.15, 0.085, 0.17), k=0.03),
        Ellipsoid("rear", "hips", v3(0, 0.08, 0.14), v3(0.145, 0.08, 0.17), k=0.05),
        Cone("tail0", "tail1", v3(0, 0.075, 0.24), v3(0, 0.06, 0.33), 0.1, 0.07, k=0.04),
        Cone("tail1", "tail2", v3(0, 0.06, 0.33), v3(0, 0.04, 0.42), 0.07, 0.026, k=0.02),
        Cone("neck", "neck", v3(0, 0.12, -0.13), v3(0, 0.25, -0.22), 0.115, 0.105, k=0.05),
        Ellipsoid("head", "head", HEAD_C, HEAD_R, k=0.04),
        Ellipsoid("lip", "head", v3(0, 0.255, -0.31), v3(0.09, 0.05, 0.06), k=0.03),
    ]
    for sd, sx in SIDES:     # the skirt: the foot's soft rim, a little wider than the body
        p.append(Ellipsoid("skirt" + sd, "spine", v3(sx * 0.1, 0.035, 0.02), v3(0.08, 0.035, 0.26), k=0.04))
        base = v3(sx * 0.045, 0.4, -0.25)
        tip = v3(sx * STALK_TIP[0], STALK_TIP[1], STALK_TIP[2])
        p.append(Cone("stalk" + sd, "ear1." + sd, base, tip, 0.024, 0.013, k=0.02))
    return p


def tip_prims():
    return [Ellipsoid("tip" + sd, "ear1." + sd, v3(sx * STALK_TIP[0], STALK_TIP[1] + 0.012, STALK_TIP[2]),
                      v3(0.026, 0.026, 0.026), k=0) for sd, sx in SIDES]


def shell_prims():
    pts = whorl_points()
    out = [Cone("w%d" % i, "shell", a, b, ra, rb, k=0.012) for i, ((_, a, ra), (_, b, rb)) in enumerate(zip(pts, pts[1:]))]
    out.append(Ellipsoid("cap", "shell", pts[-1][1], v3(pts[-1][2], pts[-1][2], pts[-1][2]) * 1.2, k=0.01))
    out.append(Ellipsoid("core", "shell", COIL_C + v3(0, 0.01, 0.02), v3(0.05, 0.075, 0.075), k=0.02))   # no hole
    return out


def parts():
    return {
        "body": (Shape(body_prims()), 0.003, 2200),
        "shell": (Shape(shell_prims()), 0.0035, 1350),
        "tips": (Shape(tip_prims()), 0.003, 70),
    }


AXIS = np.array((0.0, 0.5, -0.866))
GRIP = v3(0, 0.26, -0.37)


def prop_parts():
    out = boki_tools.tools(GRIP, AXIS)
    out["berry"] = (Shape([Ellipsoid("b", "prop_berry", BERRY_C, v3(0.05, 0.048, 0.05), k=0)]), 0.003, 24)
    return out


GROWN = {
    "horn": ((0.05, 0.4, -0.29), (0.1, 0.5, -0.35), 0.026), "fang": ((0.022, 0.25, -0.37), (0.025, 0.215, -0.375), 0.011),
    "antenna": ((0.03, 0.41, -0.29), (0.06, 0.5, -0.36), 0.01), "brow": ((0.012, 0.39, -0.345), (0.095, 0.395, -0.31), 0.015),
    "head_top": (0, 0.42, -0.25), "fang_at": (0, 0.26, -0.36), "brow_at": (0, 0.38, -0.34), "third_eye": (0, 0.395, -0.35),
    "back": ((0, 0.4, -0.02), (0, 0.47, 0.1), (0, 0.4, 0.26)), "back_at": (0, 0.42, 0.1), "plates": (0, 0.16, 0.02),
    "plate_r": (0.12, 0.03, 0.12), "shell_c": (0, 0.1, 0.05), "shell_r": (0.165, 0.09, 0.2), "tail_bone": "tail2",
    "club_at": (0, 0.05, 0.4), "club_dir": (0, -0.1, 1), "club_r": 0.045,
    "spots": ((0.14, 0.09, -0.08, 0.02), (0.15, 0.085, 0.02, 0.018), (0.14, 0.08, 0.12, 0.018)), "spots_at": (0, 0.09, 0.0),
    "wing": ((0.1, 0.2, -0.08), (0.28, 0.3, 0.0), (0.24, 0.26, 0.08)), "wing_at": (0, 0.2, -0.08),
    "fin": ((0.13, 0.1, 0.1), (0.2, 0.2, 0.22)), "fin_at": (0, 0.1, 0.1), "crest": (0.42, -0.27, 0.05, 0.06),
    "crest_at": (0, 0.42, -0.25),
}


def grown_parts():
    return boki_grown.grown_parts(GROWN)


# ---------------------------------------------------------------- coat
SKIN = hexc("7a6c94")
SKIN_LIGHT = hexc("a294bc")
SKIN_DARK = hexc("54486a")
SOLE = hexc("c8b8d8")
BLUSH = hexc("ff8fbe")
OBSIDIAN = hexc("2a2236")
OBSIDIAN_LIGHT = hexc("5c4c78")
SMOKE = hexc("8a7aa8")
VIOLET = hexc("8a6aff")
LILAC = hexc("6a5c84")     # brows
LID = SKIN_LIGHT
INK = hexc("241c30")
MOUTH_DARK = hexc("5a2244")
TONGUE = hexc("e88ab4")
IRIS = hexc("9a7aff")
IRIS_DEEP = hexc("2a1a5a")
SHELL_A = hexc("6c5c8a")
SHELL_B = hexc("3e3454")
SHELL_C = hexc("241c30")


def paint_body(p, n, prim):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    wet = value_noise(p * np.array([45, 45, 45]))
    col = mixc(SKIN_DARK, SKIN, sat(n[:, 1] * 0.6 + 0.6 + (wet - 0.5) * 0.5))
    col = mixc(col, SKIN_LIGHT, sat(n[:, 1] - 0.4) * 0.6)
    # little dark tubercles on the neck and back of the foot, a pale sole and skirt edge
    bumps = sat((value_noise(p * 55) - 0.66) / 0.05) * (y > 0.06)
    col = mixc(col, SKIN_DARK, bumps * 0.6)
    col = mixc(col, SOLE, edge(0.04 - y, 0.012))
    for sx in (-1.0, 1.0):
        q = (p - np.array([sx * 0.095, 0.29, 0])) / np.array([0.036, 0.024, 1.0])
        col = mixc(col, BLUSH, np.exp(-(q[:, 0] ** 2 + q[:, 1] ** 2) * 1.25) * (z < -0.28) * 0.7)
    return col


def paint_shell_coat(q, n, pc):
    """Glassy black obsidian: dark whorls, a smoky sheen on the tops, a faint violet glow from the mouth inward."""
    prims = [pr for pr in pc.shape.prims if pr.name.startswith("w")]   # the whorl tube, mouth first
    ds = np.stack([pr.d(q) for pr in prims], -1)
    seg = ds.argmin(1) / max(len(prims) - 1, 1)
    sheen = sat(n[:, 1] * 0.8 + n[:, 2] * 0.2)
    col = mixc(OBSIDIAN, OBSIDIAN_LIGHT, sheen * 0.8)
    # growth lines across the tube, and the seam where whorls meet goes dark
    lines = 0.5 + 0.5 * np.sin(seg * 140)
    col = mixc(col, OBSIDIAN, lines * 0.25)
    seam = edge(0.008 - np.sort(ds, 1)[:, 1] + ds.min(1), 0.004)
    col = mixc(col, INK, seam * 0.7)
    smoke = sat((value_noise(q * np.array([30, 30, 30])) - 0.45) / 0.3)
    col = mixc(col, SMOKE, smoke * sheen * 0.35)
    # the violet heart: brightest at the mouth, a thin glowing band along the coil's spiral
    glow = sat(1 - seg * 4) * 0.45 + edge(0.01 - np.abs(n[:, 0]), 0.02) * 0.15
    return mixc(col, VIOLET, sat(glow))


def paint_piece(pc, q, nn, prim):
    if pc.name == "body":
        return paint_body(q, nn, prim)
    if pc.name == "shell":
        return paint_shell_coat(q, nn, pc)
    if pc.name == "tips":
        return np.tile(VIOLET, (len(q), 1))
    if pc.name.startswith("gp_"):
        if pc.look == "white":
            return np.ones((len(q), 3))
        if pc.look == "glow":
            return np.tile(VIOLET, (len(q), 1))
        return paint_shell(q, nn, np.full(len(q), 1.0), SHELL_A, SHELL_B, SHELL_C)
    return tool_colour(pc.name, q)
