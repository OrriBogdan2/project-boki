"""Chuggamus (scaldamus): a barrel hippo that is half steam engine: a riveted iron boiler round its middle, two
smokestacks by its ears, a cowcatcher grille on its lower jaw, a firebox glowing on its chest, lava cracks in the hide.

Its body is the Meshy model of the owner's sheet (briefs/art-refs/boki/scaldamus_turnaround.png), read from
~/meshy/scaldamus/run1 (boki_meshy.py; raw files stay out of git). The primitives below are the quadruped proxy the
rig and the skin weights read."""
import math
import os

import numpy as np

import boki_grown
import boki_tools
from boki_meshy import Meshy, MeshShape
from boki_sdf import Cone, Ellipsoid, Shape, frame, v3
from vespyx_paint import hexc, mixc, paint_shell, sat, tool_colour
from vespyx_sides import SIDES

MESHY_DIR = os.path.expanduser("~/meshy/scaldamus/run1")
HEIGHT = 0.6             # the model's height in game metres (stack tops), before SCALE
SCALE = 0.95
BODY_TRIS = 3200
HEAD_C = v3(0, 0.41, -0.29)


def hd(x, y, z):
    """A point on the head, from its centre."""
    return HEAD_C + v3(x, y, z)


# the Boki eye sits in Meshy's brass goggle rings, the mouth on the lip above the grille
EYE_C = v3(0.088, 0.478, -0.262)
EYE_R = v3(0.03, 0.033, 0.018)
EYE_YAW = 0.5
GLOW_PIECES = ("firebox",)
FIREBOX_C = v3(0, 0.19, -0.26)     # a point in front of the chest; the glowing door is laid on the surface nearest it
FIREBOX_R = (0.036, 0.04)
BERRY_C = v3(0, 0.05, -0.5)
FACE = {"mouth_w": 0.07, "mouth_y": 0.35, "mouth_z": -0.395, "cat_mouth": False,
        "brow_x": 0.088, "brow_up": 0.016, "brow_k": 0.6, "fang_k": 0.0}
FRONT_Z, HIND_Z = -0.095, 0.21     # leg columns (m), measured off the Meshy model
FRONT_X, HIND_X = 0.082, 0.093
LEG_TOP, KNEE, ANKLE = 0.17, 0.095, 0.035
TAIL_PTS = [v3(0, 0.31, 0.30), v3(0, 0.27, 0.37), v3(0, 0.224, 0.42)]
STACK_X, STACK_Z = 0.075, -0.175
GRIP = v3(0, 0.29, -0.41)
AXIS = np.array((0.0, 0.5, -0.866))


def eye_frame(sx):
    out = v3(sx * math.sin(EYE_YAW), 0.1, -math.cos(EYE_YAW))
    fr = frame(out, v3(0, 1, 0))
    if (fr[0] @ v3(sx, 0, 0)) < 0:
        fr[0] = -fr[0]
    return fr


def proxy_prims():
    p = [
        Ellipsoid("barrel", "hips", v3(0, 0.29, 0.10), v3(0.21, 0.2, 0.2), k=0.04),
        Ellipsoid("chest", "spine", v3(0, 0.28, -0.07), v3(0.2, 0.2, 0.15), k=0.05),
        Cone("neck", "neck", v3(0, 0.33, -0.15), v3(0, 0.38, -0.22), 0.14, 0.13, k=0.04),
        Ellipsoid("head", "head", HEAD_C, v3(0.13, 0.12, 0.12), k=0.04),
        Ellipsoid("muzzle", "head", hd(0, -0.05, -0.08), v3(0.115, 0.09, 0.07), k=0.04),
        Ellipsoid("grille", "head", hd(0, -0.13, -0.09), v3(0.1, 0.05, 0.05), k=0.02),
    ]
    for sd, sx in SIDES:
        p.append(Ellipsoid("ear" + sd, "ear1." + sd, v3(sx * 0.12, 0.52, -0.23), v3(0.03, 0.03, 0.02), k=0.01))
        p.append(Cone("stack" + sd, "head", v3(sx * STACK_X, 0.48, STACK_Z), v3(sx * STACK_X, 0.6, STACK_Z),
                      0.03, 0.03, k=0.01))
        for leg, x, z in (("f", FRONT_X, FRONT_Z), ("h", HIND_X, HIND_Z)):
            top, knee, ankle = v3(sx * x, LEG_TOP, z), v3(sx * x, KNEE, z), v3(sx * x, ANKLE, z)
            p.append(Cone(leg + "leg1" + sd, "%sleg1.%s" % (leg, sd), top, knee, 0.055, 0.05, k=0.02))
            p.append(Cone(leg + "leg2" + sd, "%sleg2.%s" % (leg, sd), knee, ankle, 0.05, 0.05, k=0.01))
            p.append(Ellipsoid(leg + "paw" + sd, "%spaw.%s" % (leg, sd), v3(sx * x, 0.02, z - 0.01),
                               v3(0.055, 0.025, 0.06), k=0.01))
    for i in range(len(TAIL_PTS) - 1):
        p.append(Cone("tail%d" % i, "tail%d" % (i + 1), TAIL_PTS[i], TAIL_PTS[i + 1], 0.035 - 0.012 * i, 0.02, k=0.01))
    return p


def model():
    return Meshy.get(MESHY_DIR, HEIGHT)


def firebox_prims():
    """The firebox door: a flat glowing disc laid on the chest, just proud of Meshy's brass ring."""
    loc, nor, _ = model().nearest(FIREBOX_C[None])
    rx, ry = FIREBOX_R
    return [Ellipsoid("door", "spine", loc[0] + nor[0] * 0.004, v3(rx, ry, 0.006), rot=frame(nor[0], v3(0, 1, 0)), k=0)]


def parts():
    return {"body": (MeshShape(proxy_prims(), model()), 0.0035, BODY_TRIS),
            "firebox": (Shape(firebox_prims()), 0.003, 60)}


def prop_parts():
    out = boki_tools.tools(GRIP, AXIS)
    out["berry"] = (Shape([Ellipsoid("b", "prop_berry", BERRY_C, v3(0.054, 0.052, 0.054), k=0)]), 0.003, 24)
    return out


GROWN = {
    "horn": (hd(0.05, 0.1, 0.04), hd(0.1, 0.19, 0.08), 0.026),
    "fang": (hd(0.04, -0.08, -0.12), hd(0.042, -0.115, -0.125), 0.012),
    "antenna": (hd(0.04, 0.1, 0.0), hd(0.09, 0.21, -0.04), 0.01),
    "brow": (hd(0.03, 0.085, -0.03), hd(0.12, 0.09, 0.0), 0.012),
    "head_top": hd(0, 0.11, 0.02), "fang_at": hd(0, -0.08, -0.12), "brow_at": hd(0, 0.08, -0.04),
    "third_eye": hd(0, 0.08, -0.07), "back_at": (0, 0.47, 0.22), "plates": (0, 0.46, 0.22),
    "back": ((0, 0.47, 0.18), (0, 0.46, 0.24), (0, 0.43, 0.29)),
    "plate_r": (0.15, 0.04, 0.1), "shell_c": (0, 0.4, 0.2), "shell_r": (0.19, 0.09, 0.12), "tail_bone": "tail1",
    "club_at": tuple(TAIL_PTS[2]), "club_dir": tuple(TAIL_PTS[2] - TAIL_PTS[0]), "club_r": 0.04,
    "spots": ((0.19, 0.33, 0.2, 0.022), (0.2, 0.27, 0.16, 0.02), (0.18, 0.36, -0.12, 0.02)),
    "spots_at": (0, 0.3, 0.18),
    "wing": ((0.17, 0.42, 0.18), (0.36, 0.53, 0.24), (0.32, 0.48, 0.32)), "wing_at": (0, 0.42, 0.2),
    "fin": ((0.2, 0.32, 0.24), (0.27, 0.42, 0.32)), "fin_at": (0, 0.32, 0.24),
    "crest": (HEAD_C[1] + 0.11, HEAD_C[2] + 0.04, 0.05, 0.06),
    "crest_at": hd(0, 0.11, 0.04),
}


def grown_parts():
    return boki_grown.grown_parts(GROWN)


# ---------------------------------------------------------------- coat
HIDE = hexc("7a5f6e")       # plum grey, the sheet's hide
LILAC = hexc("4a3644")      # brows
LID = HIDE
INK = hexc("1c1218")
MOUTH_DARK = hexc("3a1622")
TONGUE = hexc("e07a88")
IRIS = hexc("e08a2a")
IRIS_DEEP = hexc("3a1806")
GLOW = hexc("ffa040")
HORN_A = hexc("d8b070")      # brass, for grown parts
HORN_B = hexc("8a6a3a")
HORN_C = hexc("2a2226")
HIDE_GRADE = 0.6            # how far Meshy's pinker hide is pulled to the sheet's plum grey


def paint_body(q):
    col = model().colour(q)
    # the hide is the pink-violet: blue over green; brass, orange cracks and black iron keep Meshy's colours
    pink = sat((col[:, 2] - col[:, 1]) / 0.06) * sat((col[:, 0] - col[:, 2]) / 0.02 + 1)
    lum = col @ np.array([0.3, 0.55, 0.15])
    graded = HIDE[None] * (lum / (HIDE @ np.array([0.3, 0.55, 0.15])))[:, None] * 0.92
    return mixc(col, np.clip(graded, 0, 1), HIDE_GRADE * pink)


def paint_piece(pc, q, nn, prim):
    if pc.name == "body":
        return paint_body(q)
    if pc.name in GLOW_PIECES:
        return np.tile(GLOW, (len(q), 1))
    if pc.name.startswith("gp_"):
        if pc.look == "white":
            return np.ones((len(q), 3))
        if pc.look == "glow":
            return np.tile(GLOW, (len(q), 1))
        return paint_shell(q, nn, np.full(len(q), 1.0), HORN_A, HORN_B, HORN_C)
    return tool_colour(pc.name, q)
