"""Glomwort, a slime mold carrying three puffballs: shapes and coat. Game axes as vespyx.py.
NEW design (roster 50, #22), owner approval pending. No legs: a gooey dome that oozes on a rim of short pseudopods
(lobes, each on its own bone), its face on the front of the dome."""
import math

import numpy as np

import boki_grown
import boki_tools
from boki_sdf import Cone, Ellipsoid, Shape, frame, v3, value_noise
from vespyx_paint import edge, hexc, mixc, paint_shell, sat, tool_colour
from vespyx_sides import SIDES

SCALE = 0.95
FACE_C = v3(0, 0.21, -0.1)
FACE_R = v3(0.17, 0.15, 0.14)
EYE_C = v3(0.06, 0.255, -0.208)
EYE_R = v3(0.036, 0.04, 0.024)
EYE_YAW = 0.35
GLOW_PIECES = ()
LIT_PIECES = ("puffs",)
PALE_PIECES = ("puffs",)
BERRY_C = v3(0, 0.05, -0.42)
FACE = {"mouth_w": 0.05, "mouth_y": 0.19, "mouth_z": -0.24, "cat_mouth": True, "brow_x": 0.065, "brow_up": 0.018,
        "brow_k": 0.7, "fang_k": 0.0}
LOBES = 7                  # pseudopods round the rim
LOBE_R0 = 0.19             # m from the centre where a lobe leaves the dome
# puffballs on its back: (centre, radius, bone)
PUFFS = [(v3(-0.085, 0.33, 0.07), 0.075, "puff0"), (v3(0.085, 0.32, 0.09), 0.066, "puff1"),
         (v3(0.0, 0.29, 0.19), 0.056, "puff2")]


def eye_frame(sx):
    out = v3(sx * math.sin(EYE_YAW), 0.12, -math.cos(EYE_YAW))
    fr = frame(out, v3(0, 1, 0))
    if (fr[0] @ v3(sx, 0, 0)) < 0:
        fr[0] = -fr[0]
    return fr


def lobe_dir(i):
    """The way lobe i points, round from the back (the front is left clear for the face)."""
    a = math.pi * (0.25 + 1.5 * i / (LOBES - 1))      # 45 to 315 degrees, 0 = straight back
    return v3(math.sin(a), 0, math.cos(a))


def body_prims():
    p = [
        Ellipsoid("dome", "hips", v3(0, 0.15, 0.06), v3(0.22, 0.15, 0.22), k=0.04),
        Ellipsoid("front", "spine", v3(0, 0.14, -0.06), v3(0.2, 0.13, 0.17), k=0.05),
        Ellipsoid("face", "head", FACE_C, FACE_R, k=0.06),
        Ellipsoid("skirt", "root", v3(0, 0.04, 0.02), v3(0.25, 0.04, 0.25), k=0.05),
    ]
    for i in range(LOBES):
        d = lobe_dir(i)
        a = v3(0, 0.05, 0.02) + d * LOBE_R0
        b = a + d * 0.1 + v3(0, -0.02, 0)
        p.append(Cone("lobe%d" % i, "lobe%d" % i, a, b, 0.055, 0.03, k=0.04))
    return p


def puff_prims():
    out = []
    for i, (c, r, bone) in enumerate(PUFFS):
        out.append(Cone("stem%d" % i, bone, c - v3(0, r * 1.1, 0), c - v3(0, r * 0.4, 0), r * 0.5, r * 0.6, k=0.01))
        out.append(Ellipsoid("puff%d" % i, bone, c, v3(r, r * 0.92, r), k=0.012))
    return out


def parts():
    return {
        "body": (Shape(body_prims()), 0.003, 2300),
        "puffs": (Shape(puff_prims()), 0.003, 550),
    }


AXIS = np.array((0.0, 0.5, -0.866))
GRIP = v3(0, 0.17, -0.25)


def prop_parts():
    out = boki_tools.tools(GRIP, AXIS)
    out["berry"] = (Shape([Ellipsoid("b", "prop_berry", BERRY_C, v3(0.05, 0.048, 0.05), k=0)]), 0.003, 24)
    return out


GROWN = {
    "horn": ((0.05, 0.33, -0.12), (0.1, 0.44, -0.18), 0.026), "fang": ((0.022, 0.18, -0.235), (0.025, 0.145, -0.24), 0.011),
    "antenna": ((0.04, 0.34, -0.12), (0.09, 0.48, -0.2), 0.01), "brow": ((0.012, 0.31, -0.2), (0.1, 0.315, -0.17), 0.015),
    "head_top": (0, 0.35, -0.1), "fang_at": (0, 0.19, -0.23), "brow_at": (0, 0.3, -0.19), "third_eye": (0, 0.315, -0.2),
    "back": ((0, 0.3, -0.04), (0, 0.31, 0.02), (0, 0.27, 0.16)), "back_at": (0, 0.29, 0.04), "plates": (0, 0.3, 0.0),
    "plate_r": (0.14, 0.03, 0.1), "shell_c": (0, 0.15, 0.06), "shell_r": (0.235, 0.165, 0.05), "tail_bone": "hips",
    "club_at": (0, 0.1, 0.27), "club_dir": (0, 0, 1), "club_r": 0.05,
    "spots": ((0.2, 0.14, -0.02, 0.02), (0.21, 0.13, 0.06, 0.018), (0.19, 0.12, 0.14, 0.018)), "spots_at": (0, 0.13, 0.06),
    "wing": ((0.15, 0.24, 0.0), (0.33, 0.34, 0.08), (0.29, 0.3, 0.17)), "wing_at": (0, 0.24, 0.0),
    "fin": ((0.18, 0.16, 0.1), (0.26, 0.26, 0.2)), "fin_at": (0, 0.16, 0.1), "crest": (0.34, -0.1, 0.05, 0.06),
    "crest_at": (0, 0.34, -0.1),
}


def grown_parts():
    return boki_grown.grown_parts(GROWN)


# ---------------------------------------------------------------- coat
GOO = hexc("e8c43a")
GOO_LIGHT = hexc("fff0a0")
GOO_DEEP = hexc("b8862a")
VEIN = hexc("c87a1e")
BELLY = hexc("fff2b0")
PUFF = hexc("f4ecd6")
PUFF_SHADE = hexc("d8cba8")
SPECK = hexc("a08a62")
PORE = hexc("3fe0c0")
BLUSH = hexc("ff9a7a")
LILAC = hexc("b8862a")     # brows
LID = GOO
INK = hexc("4a3010")
MOUTH_DARK = hexc("6a2e1a")
TONGUE = hexc("f09080")
IRIS = hexc("2a2010")
IRIS_DEEP = hexc("0a0804")
SHELL_A = hexc("f4ecd6")
SHELL_B = hexc("d8b060")
SHELL_C = hexc("8a6a2a")


def paint_body(p, n, prim):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    col = mixc(GOO_DEEP, GOO, sat(n[:, 1] * 0.6 + 0.65))
    col = mixc(col, GOO_LIGHT, sat(n[:, 1] - 0.45) * 0.7)
    # a net of branching veins, thickest toward the rim and out along the lobes
    r = np.hypot(x, z)
    v1 = np.abs(value_noise(p * np.array([18, 30, 18])) - 0.5)
    v2 = np.abs(value_noise(p * np.array([38, 50, 38]) + 3.1) - 0.5)
    rim = sat((r - 0.1) / 0.15) * sat((0.24 - y) / 0.12)
    col = mixc(col, VEIN, edge(0.035 - v1, 0.01) * (0.4 + 0.5 * rim))
    col = mixc(col, VEIN, edge(0.022 - v2, 0.008) * 0.5 * rim)
    col = mixc(col, BELLY, edge(0.02 - y, 0.01))
    for sx in (-1.0, 1.0):
        q = (p - np.array([sx * 0.11, 0.21, 0])) / np.array([0.034, 0.022, 1.0])
        col = mixc(col, BLUSH, np.exp(-(q[:, 0] ** 2 + q[:, 1] ** 2) * 1.25) * (z < -0.15) * 0.55)
    return col


def paint_puffs(q, n):
    """Cream puffballs, freckled, each with a glowing pore on top."""
    col = mixc(PUFF_SHADE, PUFF, sat(n[:, 1] * 0.7 + 0.5))
    col = mixc(col, SPECK, sat((value_noise(q * 160) - 0.72) / 0.05) * 0.7)
    for c, r, _ in PUFFS:
        d = np.linalg.norm(q - (c + v3(0, r * 0.9, 0)), axis=1)
        col = mixc(col, PORE, edge(r * 0.28 - d, 0.006))
    return col


def paint_piece(pc, q, nn, prim):
    if pc.name == "body":
        return paint_body(q, nn, prim)
    if pc.name == "puffs":
        return paint_puffs(q, nn)
    if pc.name.startswith("gp_"):
        if pc.look == "white":
            return np.ones((len(q), 3))
        if pc.look == "glow":
            return np.tile(PORE, (len(q), 1))
        return paint_shell(q, nn, np.full(len(q), 1.0), SHELL_A, SHELL_B, SHELL_C)
    return tool_colour(pc.name, q)
