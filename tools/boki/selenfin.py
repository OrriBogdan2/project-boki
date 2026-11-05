"""Selenfin, a hatchetfish with a moonstone set in its keel: shapes and coat. Game axes as vespyx.py.
NEW design (roster 50, #19), owner approval pending. It floats upright (FRAME "hover"): a round chibi head, a deep
thin hatchet body, a forked tail; pectoral fins on the ear bones, so its inborn ear shapes set the fins."""
import math

import numpy as np

import boki_grown
import boki_tools
from boki_sdf import Cone, Ellipsoid, Shape, frame, v3, value_noise
from vespyx_paint import edge, hexc, mixc, paint_shell, sat, tool_colour
from vespyx_sides import SIDES

SCALE = 0.95
HEAD_C = v3(0, 0.47, -0.15)
HEAD_R = v3(0.15, 0.15, 0.14)
EYE_C = v3(0.082, 0.515, -0.25)
EYE_R = v3(0.048, 0.052, 0.03)
EYE_YAW = 0.55
GLOW_PIECES = ()
LIT_PIECES = ("moonstone",)
PALE_PIECES = ("fins", "moonstone")
BERRY_C = v3(0, 0.05, -0.42)
FACE = {"mouth_w": 0.05, "mouth_y": 0.425, "mouth_z": -0.285, "cat_mouth": False, "brow_x": 0.08, "brow_up": 0.02,
        "brow_k": 0.75, "fang_k": 0.0}
GEM_C = v3(0, 0.2, -0.02)          # the moonstone, low in the keel
TAIL_PTS = [v3(0, 0.42, 0.15), v3(0, 0.43, 0.24), v3(0, 0.44, 0.31), v3(0, 0.45, 0.37)]
SIDE = v3(1, 0, 0)


def eye_frame(sx):
    """Its eyes look a little up, as a hatchetfish's do."""
    out = v3(sx * math.sin(EYE_YAW), 0.22, -math.cos(EYE_YAW))
    fr = frame(out, v3(0, 1, 0))
    if (fr[0] @ v3(sx, 0, 0)) < 0:
        fr[0] = -fr[0]
    return fr


def body_prims():
    flat = {"flat": 0.55, "flat_axis": SIDE}
    p = [
        Ellipsoid("head", "head", HEAD_C, HEAD_R, k=0.04),
        Ellipsoid("cheek", "head", v3(0, 0.43, -0.2), v3(0.13, 0.1, 0.11), k=0.04),
        Ellipsoid("chest", "spine", v3(0, 0.4, -0.02), v3(0.1, 0.19, 0.16), k=0.06),
        Ellipsoid("flank", "hips", v3(0, 0.43, 0.08), v3(0.085, 0.14, 0.12), k=0.05),
        # the hatchet: a deep keel curving down and back under the chest
        Ellipsoid("keel", "spine", v3(0, 0.27, -0.01), v3(0.065, 0.14, 0.15), rot=frame(v3(0, -0.35, 1), v3(0, 1, 0)),
                  k=0.05),
        Cone("blade", "spine", v3(0, 0.3, -0.1), v3(0, 0.13, 0.04), 0.075, 0.055, k=0.04, **flat),
        Cone("stalk0", "tail1", TAIL_PTS[0], TAIL_PTS[1], 0.07, 0.045, k=0.03, **flat),
        Cone("stalk1", "tail2", TAIL_PTS[1], TAIL_PTS[2], 0.045, 0.03, k=0.015, **flat),
    ]
    return p


def fin_prims():
    thin = {"flat": 0.16, "flat_axis": SIDE}
    out = [
        # forked tail
        Cone("tailU", "tail3", TAIL_PTS[2], TAIL_PTS[3] + v3(0, 0.11, 0.08), 0.03, 0.012, k=0.01, **thin),
        Cone("tailD", "tail3", TAIL_PTS[2], TAIL_PTS[3] + v3(0, -0.09, 0.09), 0.03, 0.012, k=0.01, **thin),
        # a little sail on top, and a fringe along the back of the keel
        Cone("dorsal", "spine", v3(0, 0.56, 0.0), v3(0, 0.67, 0.1), 0.045, 0.01, k=0.012, **thin),
        Cone("anal", "hips", v3(0, 0.3, 0.12), v3(0, 0.25, 0.22), 0.035, 0.01, k=0.012, **thin),
    ]
    for sd, sx in SIDES:
        n = v3(sx * 0.25, 1, 0.1)
        out.append(Ellipsoid("pec" + sd, "ear1." + sd, v3(sx * 0.15, 0.37, -0.04), v3(0.045, 0.01, 0.075),
                             rot=frame(v3(sx * 1.0, -0.25, 0.55), n), k=0))
    return out


def gem_prims():
    return [Ellipsoid("gem", "spine", GEM_C, v3(0.088, 0.048, 0.062), k=0)]


def parts():
    return {
        "body": (Shape(body_prims()), 0.003, 2300),
        "fins": (Shape(fin_prims()), 0.0025, 380),
        "moonstone": (Shape(gem_prims()), 0.0025, 110),
    }


AXIS = np.array((0.0, 0.3, -0.954))
GRIP = v3(0, 0.42, -0.3)


def prop_parts():
    out = boki_tools.tools(GRIP, AXIS)
    out["berry"] = (Shape([Ellipsoid("b", "prop_berry", BERRY_C, v3(0.05, 0.048, 0.05), k=0)]), 0.003, 24)
    return out


GROWN = {
    "horn": ((0.05, 0.6, -0.17), (0.1, 0.71, -0.23), 0.026), "fang": ((0.022, 0.415, -0.29), (0.025, 0.38, -0.295), 0.011),
    "antenna": ((0.04, 0.6, -0.18), (0.09, 0.74, -0.26), 0.01), "brow": ((0.012, 0.585, -0.24), (0.1, 0.59, -0.2), 0.015),
    "head_top": (0, 0.61, -0.15), "fang_at": (0, 0.42, -0.28), "brow_at": (0, 0.58, -0.23), "third_eye": (0, 0.59, -0.25),
    "back": ((0, 0.6, -0.08), (0, 0.6, 0.04), (0, 0.55, 0.15)), "back_at": (0, 0.58, 0.04), "plates": (0, 0.57, 0.0),
    "plate_r": (0.08, 0.03, 0.1), "shell_c": (0, 0.4, 0.02), "shell_r": (0.11, 0.2, 0.06), "tail_bone": "tail2",
    "club_at": tuple(TAIL_PTS[2]), "club_dir": tuple(TAIL_PTS[3] - TAIL_PTS[1]), "club_r": 0.045,
    "spots": ((0.09, 0.42, 0.0, 0.02), (0.085, 0.4, 0.08, 0.018), (0.075, 0.38, 0.15, 0.016)), "spots_at": (0, 0.4, 0.06),
    "wing": ((0.08, 0.5, -0.02), (0.26, 0.6, 0.06), (0.22, 0.56, 0.15)), "wing_at": (0, 0.5, -0.02),
    "fin": ((0.09, 0.44, 0.06), (0.16, 0.54, 0.16)), "fin_at": (0, 0.44, 0.06), "crest": (0.6, -0.18, 0.05, 0.06),
    "crest_at": (0, 0.6, -0.15),
}


def grown_parts():
    return boki_grown.grown_parts(GROWN)


# ---------------------------------------------------------------- coat
SILVER = hexc("d6dcea")
SILVER_HI = hexc("f6f8ff")
DUSK = hexc("7c88a8")            # the darker back
BELLY = hexc("f8f8ff")
SHEEN_A = hexc("cfe2ff")
SHEEN_B = hexc("f0dcff")
PHOTO = hexc("fff0a0")           # the glowing dots down the keel
FIN = hexc("e6ecf8")
FIN_EDGE = hexc("a8b4d0")
MOON_A = hexc("eef2ff")
MOON_B = hexc("c8d8ff")
MOON_GLOW = hexc("fff0a0")
BLUSH = hexc("ffa8c4")
LILAC = hexc("8a96b4")     # brows
LID = SILVER
INK = hexc("2c3448")
MOUTH_DARK = hexc("4a2a44")
TONGUE = hexc("f0a0b8")
IRIS = hexc("6a8ad8")
IRIS_DEEP = hexc("1a2450")
SHELL_A = hexc("eef2ff")
SHELL_B = hexc("b8c4dc")
SHELL_C = hexc("7c88a8")


def paint_body(p, n, prim):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    col = mixc(SILVER, SILVER_HI, sat(np.abs(n[:, 0]) * 0.8))
    # a darker back fading down into mirror-bright sides, an opal sheen that shifts with the normal
    back = sat((y - 0.48) / 0.1 + n[:, 1] * 0.4)
    col = mixc(col, DUSK, back * 0.75)
    sheen = 0.5 + 0.5 * np.sin(n[:, 1] * 5 + n[:, 2] * 4)
    col = mixc(col, mixc(SHEEN_A, SHEEN_B, sheen), 0.25 * sat(1 - back))
    col = mixc(col, BELLY, edge(0.3 - y, 0.04))
    # a row of photophores along the bottom of the keel
    for i in range(7):
        c = np.array([0.0, 0.165 + 0.012 * abs(i - 3), -0.11 + i * 0.04])
        d = np.hypot(y - c[1], z - c[2])
        col = mixc(col, PHOTO, edge(0.011 - d, 0.004) * (np.abs(x) > 0.02))
    # scales: a soft scallop on the flanks
    scale = 0.5 + 0.5 * np.sin(z * 120 + np.sin(y * 120) * 1.2)
    col = mixc(col, SILVER * 0.92, scale * 0.12 * (z > -0.1) * (y > 0.3))
    for sx in (-1.0, 1.0):
        q = (p - np.array([sx * 0.11, 0.455, 0])) / np.array([0.036, 0.024, 1.0])
        col = mixc(col, BLUSH, np.exp(-(q[:, 0] ** 2 + q[:, 1] ** 2) * 1.25) * (z < -0.18) * 0.6)
    return col


def paint_fins(q, n):
    """Pale, nearly clear fins with fine rays and a darker edge."""
    rays = 0.5 + 0.5 * np.sin(np.arctan2(q[:, 1] - 0.44, q[:, 2] - 0.3) * 40)
    col = mixc(FIN, FIN_EDGE, rays * 0.25)
    return mixc(col, MOON_GLOW, sat(value_noise(q * 60) - 0.7) * 0.6)


def paint_moonstone(q, n):
    """A milky moonstone: a blue sheen floating over a pale body, a warm glow in its heart."""
    d = np.linalg.norm((q - GEM_C) / np.array([0.088, 0.048, 0.062]), axis=1)
    col = mixc(MOON_A, MOON_B, sat(n[:, 1] * 0.5 + 0.5))
    col = mixc(col, MOON_GLOW, sat(1.0 - d) * 0.6)
    return mixc(col, SILVER_HI, sat(n[:, 1] * 2 - 1.2))


def paint_piece(pc, q, nn, prim):
    if pc.name == "body":
        return paint_body(q, nn, prim)
    if pc.name == "fins":
        return paint_fins(q, nn)
    if pc.name == "moonstone":
        return paint_moonstone(q, nn)
    if pc.name.startswith("gp_"):
        if pc.look == "white":
            return np.ones((len(q), 3))
        if pc.look == "glow":
            return np.tile(MOON_GLOW, (len(q), 1))
        return paint_shell(q, nn, np.full(len(q), 1.0), SHELL_A, SHELL_B, SHELL_C)
    return tool_colour(pc.name, q)
