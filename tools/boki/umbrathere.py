"""Umbrathere (umbrathere): a hunched, massive two-legged ground sloth on thick legs and a heavy dragging tail, long
arms hanging with hooked claws, and a domed umbrella canopy growing from its spine, torn at the edges and tipped
violet.

Its body is the Meshy model of the owner's sheet (briefs/art-refs/boki/umbrathere_turnaround.png at 7e91f47b5), read
from ~/meshy/umbrathere/run1 (boki_meshy.py; raw files stay out of git). The primitives below are the biped proxy the
rig and the skin weights read; the joint points are measured off the Meshy model at HEIGHT."""
import math
import os

import numpy as np

import boki_grown
import boki_tools
from boki_meshy import Meshy, MeshShape
from boki_sdf import Cone, Ellipsoid, Shape, frame, v3
from vespyx_paint import hexc, mixc, paint_shell, sat, tool_colour
from vespyx_sides import SIDES

MESHY_DIR = os.path.expanduser("~/meshy/umbrathere/run1")
HEIGHT = 0.8             # the model's height in game metres (canopy tip), before SCALE
BODY_TRIS = 3600
HEAD_C = v3(0, 0.49, -0.165)


def hd(x, y, z):
    """A point on the head, from its centre."""
    return HEAD_C + v3(x, y, z)


def mir(p, sx):
    """A right-side (+x) point, for the side `sx`."""
    return (p[0] * sx, p[1], p[2])


# the spine, centre line
PELVIS = v3(0, 0.19, 0.0)
CHEST = v3(0, 0.33, -0.02)
NECK = v3(0, 0.40, -0.07)
HEAD_BASE = v3(0, 0.44, -0.12)
HEAD_TOP = v3(0, 0.60, -0.18)
# the canopy grows from the upper back; its hub tip is the model's top, its dome tilts back over the shoulders
CANOPY_BASE = v3(0, 0.45, 0.10)
CANOPY_TOP = v3(0, 0.80, 0.04)
# right arm, as Meshy's A-pose leaves it: shoulder, elbow, wrist, claw tips
ARM_PTS = [v3(0.145, 0.37, -0.03), v3(0.27, 0.29, -0.03), v3(0.36, 0.23, -0.03), v3(0.49, 0.21, -0.03)]
# right leg: hip, knee, ankle, toes
LEG_PTS = [v3(0.08, 0.19, 0.0), v3(0.09, 0.10, -0.04), v3(0.09, 0.035, -0.01), v3(0.09, 0.01, -0.13)]
# the tail drags on the ground behind, curling to its right
TAIL_PTS = [v3(0, 0.18, 0.09), v3(0.01, 0.07, 0.17), v3(0.06, 0.035, 0.25), v3(0.13, 0.03, 0.32)]
SIT_DROP = -0.09

# the Boki eye sits in Meshy's dark eye patches, the mouth under the nose
EYE_C = v3(0.058, 0.508, -0.238)
EYE_R = v3(0.024, 0.024, 0.014)
EYE_YAW = 0.42
GLOW_PIECES = ()
BERRY_C = v3(0, 0.05, -0.36)
FACE = {"mouth_w": 0.045, "mouth_y": 0.44, "mouth_z": -0.25, "cat_mouth": False,
        "brow_x": 0.06, "brow_up": 0.012, "brow_k": 0.6, "fang_k": 0.5}
GRIP = v3(0.40, 0.21, -0.05)
AXIS = np.array((0.0, 0.5, -0.866))


def eye_frame(sx):
    out = v3(sx * math.sin(EYE_YAW), 0.1, -math.cos(EYE_YAW))
    fr = frame(out, v3(0, 1, 0))
    if (fr[0] @ v3(sx, 0, 0)) < 0:
        fr[0] = -fr[0]
    return fr


def proxy_prims():
    p = [
        Ellipsoid("belly", "hips", v3(0, 0.24, -0.02), v3(0.17, 0.12, 0.13), k=0.05),
        Ellipsoid("chest", "spine", v3(0, 0.35, -0.03), v3(0.16, 0.09, 0.13), k=0.05),
        Cone("neck", "neck", NECK, HEAD_BASE, 0.09, 0.09, k=0.03),
        Ellipsoid("head", "head", HEAD_C, v3(0.12, 0.1, 0.11), k=0.04),
        Ellipsoid("snout", "head", hd(0, -0.02, -0.08), v3(0.06, 0.05, 0.04), k=0.02),
        Ellipsoid("canopy", "canopy", v3(0, 0.66, -0.05), v3(0.3, 0.13, 0.28), k=0.03),
        Ellipsoid("skirt", "canopy", v3(0, 0.5, 0.17), v3(0.24, 0.1, 0.05), k=0.02),
        Cone("stem", "canopy", CANOPY_BASE, CANOPY_TOP, 0.02, 0.015, k=0.01),
    ]
    for sd, sx in SIDES:
        sh, el, wr, tip = (v3(*mir(q, sx)) for q in ARM_PTS)
        p.append(Cone("arm1" + sd, "arm1." + sd, sh, el, 0.06, 0.05, k=0.02))
        p.append(Cone("arm2" + sd, "arm2." + sd, el, wr, 0.05, 0.045, k=0.02))
        p.append(Cone("hand" + sd, "hand." + sd, wr, tip, 0.045, 0.02, k=0.01))
        hip, knee, ankle, toe = (v3(*mir(q, sx)) for q in LEG_PTS)
        p.append(Cone("hleg1" + sd, "hleg1." + sd, hip, knee, 0.075, 0.065, k=0.02))
        p.append(Cone("hleg2" + sd, "hleg2." + sd, knee, ankle, 0.06, 0.055, k=0.01))
        p.append(Ellipsoid("hpaw" + sd, "hpaw." + sd, v3(sx * 0.09, 0.025, -0.06), v3(0.055, 0.03, 0.08), k=0.01))
    for i in range(len(TAIL_PTS) - 1):
        p.append(Cone("tail%d" % i, "tail%d" % (i + 1), TAIL_PTS[i], TAIL_PTS[i + 1], 0.07 - 0.02 * i, 0.03, k=0.01))
    return p


def model():
    return Meshy.get(MESHY_DIR, HEIGHT)


def parts():
    return {"body": (MeshShape(proxy_prims(), model()), 0.0035, BODY_TRIS)}


def prop_parts():
    out = boki_tools.tools(GRIP, AXIS)
    out["berry"] = (Shape([Ellipsoid("b", "prop_berry", BERRY_C, v3(0.054, 0.052, 0.054), k=0)]), 0.003, 24)
    return out


GROWN = {
    "horn": (hd(0.05, 0.08, 0.03), hd(0.1, 0.15, 0.07), 0.024),
    "fang": (hd(0.03, -0.06, -0.09), hd(0.032, -0.09, -0.095), 0.011),
    "antenna": (hd(0.04, 0.08, 0.0), hd(0.09, 0.15, -0.04), 0.01),
    "brow": (hd(0.025, 0.06, -0.08), hd(0.1, 0.065, -0.05), 0.011),
    "head_top": hd(0, 0.1, 0.0), "fang_at": hd(0, -0.06, -0.09), "brow_at": hd(0, 0.06, -0.08),
    "third_eye": hd(0, 0.06, -0.09), "back_at": (0, 0.36, 0.17), "plates": (0, 0.34, 0.17),
    "back": ((0, 0.40, 0.16), (0, 0.33, 0.17), (0, 0.26, 0.14)),
    "plate_r": (0.14, 0.04, 0.09), "shell_c": (0, 0.31, 0.07), "shell_r": (0.19, 0.1, 0.12), "tail_bone": "tail1",
    "club_at": tuple(TAIL_PTS[3]), "club_dir": tuple(TAIL_PTS[3] - TAIL_PTS[1]), "club_r": 0.045,
    "spots": ((0.18, 0.30, 0.04, 0.022), (0.17, 0.24, 0.07, 0.02), (0.16, 0.36, 0.0, 0.02)),
    "spots_at": (0, 0.3, 0.1),
    "wing": ((0.14, 0.38, 0.15), (0.32, 0.48, 0.22), (0.28, 0.42, 0.3)), "wing_at": (0, 0.38, 0.16),
    "fin": ((0.16, 0.26, 0.15), (0.23, 0.35, 0.22)), "fin_at": (0, 0.26, 0.15),
    "crest": (HEAD_C[1] + 0.1, HEAD_C[2] + 0.02, 0.05, 0.05),
    "crest_at": hd(0, 0.1, 0.02),
}


def grown_parts():
    return boki_grown.grown_parts(GROWN)


# ---------------------------------------------------------------- coat
FUR = hexc("3a3040")         # charcoal (content/kin_v2 body)
LILAC = hexc("4a3a54")       # brows
LID = hexc("6a5a70")
INK = hexc("140f18")
MOUTH_DARK = hexc("2a1430")
TONGUE = hexc("c87a98")
IRIS = hexc("9a7aff")
IRIS_DEEP = hexc("2a1a4a")
GLOW = hexc("9a7aff")        # the canopy tips' violet glow
HORN_A = hexc("c8b8d8")      # pale bone, for grown parts
HORN_B = hexc("6a5a7a")
HORN_C = hexc("1e1824")
LUM = np.array([0.3, 0.55, 0.15])


def paint_body(q):
    return grade(model().colour(q), q)


def grade(col, q):
    """Meshy's texture, regraded to the sheet: the fur and belly go near neutral charcoal and grey (the game shader
    saturates any violet cast), and only the canopy's lilac rib tips are pushed to the violet glow."""
    b, g = col[:, 2], col[:, 1]
    lum = col @ LUM
    tint = 0.7 + 0.3 * FUR / (FUR @ LUM)
    out = col * 0.2 + np.clip(lum[:, None] * tint[None], 0, 1) * 0.8
    canopy = sat((q[:, 1] - 0.44) / 0.03) * sat((np.linalg.norm(q - HEAD_C, axis=1) - 0.13) / 0.02)
    lilac = sat((b - g - 0.03) / 0.06) * sat((lum - 0.3) / 0.12)
    glow = np.clip(GLOW[None] * (lum / (GLOW @ LUM))[:, None] * 1.2, 0, 1)
    return mixc(out, glow, lilac * canopy * 0.85)


def paint_piece(pc, q, nn, prim):
    if pc.name == "body":
        return paint_body(q)
    if pc.name.startswith("gp_"):
        if pc.look == "white":
            return np.ones((len(q), 3))
        if pc.look == "glow":
            return np.tile(GLOW, (len(q), 1))
        return paint_shell(q, nn, np.full(len(q), 1.0), HORN_A, HORN_B, HORN_C)
    return tool_colour(pc.name, q)
