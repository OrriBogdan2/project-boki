"""Zippelith (caecilith): a thick ringed legless worm standing up in a column, its tail flat on the ground behind,
zipper teeth down its back and a pull tag at the tail tip.

Unlike the other Boki its body is not built from primitives: it is the Meshy model of the owner's sheet
(briefs/art-refs/boki/caecilith_turnaround.png), read from ~/meshy/caecilith/run1 (raw files stay out of git), turned
into game axes, decimated to the budget and painted from Meshy's own texture. The primitives below are a proxy: the
skin weights and the rig read them; MeshShape answers the face's and the occlusion's surface questions from the
full Meshy surface."""
import math
import os

import numpy as np

import boki_grown
import boki_tools
from boki_meshy import Meshy, MeshShape
from boki_sdf import Cone, Ellipsoid, Shape, frame, v3
from vespyx_paint import hexc, mixc, paint_shell, sat, tool_colour

MESHY_DIR = os.path.expanduser("~/meshy/caecilith/run1")
HEIGHT = 0.62            # the model's height in game metres, before SCALE
SCALE = 0.9
BODY_TRIS = 3000
HEAD_C = v3(0, 0.51, -0.145)


def hd(x, y, z):
    """A point on the head, from its centre."""
    return HEAD_C + v3(x, y, z)


EYE_C = v3(0.057, 0.514, -0.241)
EYE_R = v3(0.034, 0.037, 0.018)
EYE_YAW = 0.48
GLOW_PIECES = ()
PALE_PIECES = ()
BERRY_C = v3(0, 0.05, -0.40)
FACE = {"mouth_w": 0.07, "mouth_y": 0.458, "mouth_z": -0.272, "cat_mouth": False,
        "brow_x": 0.058, "brow_up": 0.014, "brow_k": 0.55, "fang_k": 0.0}
# the body chain, head to tail: the column up from the ground, then the tail flat behind; segment i rides BODY_BONES[i]
SPINE = [v3(0, 0.42, -0.125), v3(0, 0.33, -0.125), v3(0, 0.24, -0.145), v3(0, 0.13, -0.12), v3(0, 0.095, -0.03),
         v3(0, 0.09, 0.04), v3(0, 0.088, 0.10), v3(0, 0.085, 0.15), v3(0, 0.08, 0.20), v3(0, 0.05, 0.25)]
SPINE_R = [0.095, 0.095, 0.105, 0.11, 0.095, 0.09, 0.085, 0.07, 0.05, 0.03]
BODY_BONES = ["neck", "spine", "hips", "tail1", "tail2", "tail3", "tail4", "tail5", "tail6"]
TAIL_N = 6
HEAD_TOP = v3(0, 0.62, -0.14)
GRIP = v3(0, 0.455, -0.29)
AXIS = np.array((0.0, 0.5, -0.866))
# Meshy painted its own eyes and mouth; the Boki face (lids, brows, mouth that move) takes their place
PAINTED_EYES = [v3(sx * 0.078, 0.512, -0.222) for sx in (1, -1)]
PAINTED_MOUTH = (0.455, -0.27)
BLUSH_AT = [v3(sx * 0.088, 0.474, -0.225) for sx in (1, -1)]


def eye_frame(sx):
    out = v3(sx * math.sin(EYE_YAW), 0.1, -math.cos(EYE_YAW))
    fr = frame(out, v3(0, 1, 0))
    if (fr[0] @ v3(sx, 0, 0)) < 0:
        fr[0] = -fr[0]
    return fr


def proxy_prims():
    out = [Cone("seg%d" % i, bone, SPINE[i], SPINE[i + 1], SPINE_R[i], SPINE_R[i + 1], k=0.03)
           for i, bone in enumerate(BODY_BONES)]
    out.append(Ellipsoid("head", "head", HEAD_C, v3(0.105, 0.11, 0.135), k=0.04))
    return out


def model():
    return Meshy.get(MESHY_DIR, HEIGHT)


def parts():
    return {"body": (MeshShape(proxy_prims(), model()), 0.0035, BODY_TRIS)}


def prop_parts():
    out = boki_tools.tools(GRIP, AXIS)
    out["berry"] = (Shape([Ellipsoid("b", "prop_berry", BERRY_C, v3(0.05, 0.048, 0.05), k=0)]), 0.003, 24)
    return out


GROWN = {
    "horn": (hd(0.045, 0.08, 0.0), hd(0.085, 0.17, 0.03), 0.022),
    "fang": (hd(0.03, -0.05, -0.122), hd(0.032, -0.078, -0.125), 0.009),
    "antenna": (hd(0.035, 0.09, -0.02), hd(0.08, 0.19, -0.06), 0.008),
    "brow": (hd(0.015, 0.042, -0.112), hd(0.085, 0.048, -0.08), 0.011),
    "head_top": hd(0, 0.105, 0.0), "fang_at": hd(0, -0.05, -0.12), "brow_at": hd(0, 0.04, -0.11),
    "third_eye": hd(0, 0.06, -0.112), "back_at": (0, 0.30, -0.03), "plates": (0, 0.30, -0.04),
    "back": ((0, 0.37, -0.04), (0, 0.29, -0.03), (0, 0.21, -0.04)),
    "plate_r": (0.07, 0.03, 0.06), "shell_c": (0, 0.13, 0.06), "shell_r": (0.1, 0.07, 0.1), "tail_bone": "tail5",
    "club_at": tuple(SPINE[8]), "club_dir": tuple(SPINE[9] - SPINE[7]), "club_r": 0.045,
    "spots": ((0.098, 0.31, -0.13, 0.016), (0.104, 0.22, -0.14, 0.016), (0.09, 0.1, 0.02, 0.014)),
    "spots_at": (0, 0.22, -0.12),
    "wing": ((0.06, 0.36, -0.06), (0.18, 0.44, 0.0), (0.16, 0.40, 0.05)), "wing_at": (0, 0.36, -0.06),
    "fin": ((0.08, 0.1, 0.12), (0.14, 0.06, 0.2)), "fin_at": (0, 0.1, 0.12),
    "crest": (HEAD_C[1] + 0.105, HEAD_C[2] + 0.03, 0.04, 0.05),
    "crest_at": hd(0, 0.105, 0.03),
}


def grown_parts():
    return boki_grown.grown_parts(GROWN)


OBSIDIAN = hexc("2b2233")
GLOW = hexc("a87aff")
LILAC = hexc("6a5a7a")     # brows
INK = hexc("120c18")
LID = hexc("3a2f45")
MOUTH_DARK = hexc("3a1430")
TONGUE = hexc("ff7fa0")
BLUSH = hexc("a8405e")
IRIS = hexc("6b3fd0")
IRIS_DEEP = hexc("1c0c3a")
SHELL_A = hexc("b8b4c4")
SHELL_B = hexc("5f5b6b")
SHELL_C = hexc("2a2730")
DARKEN = 0.55          # Meshy's coat is lighter than the sheet's obsidian


def paint_body(q, nn):
    col = model().colour(q)
    lum = col @ np.array([0.3, 0.55, 0.15])
    # the dark coat goes darker, the gunmetal teeth and the violet seam keep their light
    keep = sat((lum - 0.35) / 0.2)
    col = col * (DARKEN + (1 - DARKEN) * keep)[:, None]
    gone = np.zeros(len(q))
    for c in PAINTED_EYES:
        gone = np.maximum(gone, sat((0.05 - np.linalg.norm((q - c) * v3(1, 0.9, 1.2), axis=1)) / 0.012))
    my, mz = PAINTED_MOUTH
    mouth = (sat((0.022 - np.abs(q[:, 1] - my - 6 * q[:, 0] ** 2)) / 0.008) * sat((-0.2 - q[:, 2]) / 0.02)
             * sat((0.068 - np.abs(q[:, 0])) / 0.012))
    gone = np.maximum(gone, mouth)
    col = mixc(col, np.tile(OBSIDIAN, (len(q), 1)), gone)
    blush = np.zeros(len(q))
    for c in BLUSH_AT:
        blush = np.maximum(blush, sat((0.024 - np.linalg.norm((q - c) * v3(0.8, 1.3, 1), axis=1)) / 0.014))
    return mixc(col, np.tile(BLUSH, (len(q), 1)), 0.7 * blush)


def paint_piece(pc, q, nn, prim):
    if pc.name == "body":
        return paint_body(q, nn)
    if pc.name.startswith("gp_"):
        if pc.look == "white":
            return np.ones((len(q), 3))
        if pc.look == "glow":
            return np.tile(GLOW, (len(q), 1))
        return paint_shell(q, nn, np.full(len(q), 1.0), SHELL_A, SHELL_B, SHELL_C)
    return tool_colour(pc.name, q)
