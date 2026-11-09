"""Bellowary (cindowary): a tall cassowary runner and mount, shaggy ash-black plumage, a leather forge bellows
strapped over its chest under a brass nozzle beak, red and blue wattles, thick scaly legs with brass spurs and a
saddle behind the neck.

Its body is the Meshy model of the owner's sheet (briefs/art-refs/boki/cindowary_turnaround.png), read by
meshy_body from ~/meshy/cindowary/run1 (raw files stay out of git). The primitives below are the rig's proxy."""
import math

import numpy as np

import boki_grown
import boki_tools
from boki_sdf import Cone, Ellipsoid, Shape, frame, v3
from meshy_body import Meshy, MeshShape
from vespyx_paint import hexc, mixc, tool_colour

MESHY_DIR = "~/meshy/cindowary/run1"
HEIGHT = 0.66            # the model's height in game metres, before SCALE
SCALE = 0.95
BODY_TRIS = 3600
SIDES = (("L", 1), ("R", -1))
HEAD_C = v3(0, 0.605, -0.09)
EYE_C = v3(0.036, 0.612, -0.124)
EYE_R = v3(0.019, 0.021, 0.012)
EYE_YAW = 0.95           # a bird's eyes look out to the side
GLOW_PIECES = ("gust",)
BERRY_C = v3(0, 0.05, -0.3)
FACE = {"mouth_w": 0.022, "mouth_y": 0.566, "mouth_z": -0.16, "cat_mouth": False,
        "brow_x": 0.036, "brow_up": 0.006, "brow_k": 0.9, "fang_k": 0.0}
# the chain from the hips up the neck: hips, spine (chest and bellows), two neck bones, the head
HIP = v3(0, 0.3, 0.05)
CHEST = v3(0, 0.38, -0.06)
NECK = [v3(0, 0.43, -0.1), v3(0, 0.5, -0.105), v3(0, 0.565, -0.095)]
HEAD_TOP = v3(0, 0.66, -0.08)
NOZZLE = v3(0, 0.583, -0.205)              # the brass beak's mouth: the gust and the ember glow leave from here
BELLOWS = (v3(0, 0.37, -0.12), v3(0, 0.37, -0.2))
SADDLE = (v3(0, 0.435, 0.03), v3(0, 0.5, 0.03))      # the rider's seat: its bone is the mount anchor
TAIL_PTS = (v3(0, 0.33, 0.12), v3(0, 0.34, 0.21))
SHOULDER = v3(0.1, 0.38, -0.03)
WING_TIP = v3(0.11, 0.29, 0.15)
HIP_JOINT = v3(0.05, 0.25, 0.035)
KNEE = v3(0.047, 0.185, 0.035)
ANKLE = v3(0.047, 0.035, 0.02)
TOE = v3(0.05, 0.008, -0.07)
EAR_PTS = (v3(0.024, 0.63, -0.075), v3(0.031, 0.66, -0.06))   # the head feathers: the coats' ear tufts sit here
GRIP = v3(0, 0.58, -0.215)
AXIS = np.array((0.0, 0.42, -0.907))
# Meshy painted its own eyes; the Boki face (lids, brows, a mouth that move) takes their place
PAINTED_EYE_R = 0.026


def mir(p, sx):
    return v3(sx * p[0], p[1], p[2])


def eye_frame(sx):
    out = v3(sx * math.sin(EYE_YAW), 0.05, -math.cos(EYE_YAW))
    fr = frame(out, v3(0, 1, 0))
    if (fr[0] @ v3(sx, 0, 0)) < 0:
        fr[0] = -fr[0]
    return fr


def proxy_prims():
    out = [Ellipsoid("body", "hips", v3(0, 0.33, 0.04), v3(0.12, 0.1, 0.16), k=0.03),
           Ellipsoid("chest", "spine", CHEST, v3(0.1, 0.09, 0.09), k=0.03),
           Ellipsoid("bellows", "bellows", v3(0, 0.37, -0.165), v3(0.07, 0.1, 0.045), k=0.02),
           Ellipsoid("saddle", "saddle", v3(0, 0.44, 0.035), v3(0.07, 0.035, 0.075), k=0.02),
           Cone("tail", "tail1", TAIL_PTS[0], TAIL_PTS[1], 0.06, 0.04, k=0.02),
           Cone("neck1", "neck", NECK[0], NECK[1], 0.05, 0.04, k=0.02),
           Cone("neck2", "neck2", NECK[1], NECK[2], 0.04, 0.04, k=0.02),
           Ellipsoid("wattles", "neck2", v3(0, 0.5, -0.155), v3(0.045, 0.06, 0.03), k=0.02),
           Ellipsoid("head", "head", HEAD_C, v3(0.05, 0.05, 0.06), k=0.02),
           Cone("beak", "head", v3(0, 0.585, -0.13), NOZZLE, 0.03, 0.02, k=0.01)]
    for sd, sx in SIDES:
        out += [Ellipsoid("wing." + sd, "wing." + sd, mir(v3(0.11, 0.33, 0.05), sx), v3(0.025, 0.08, 0.12), k=0.02),
                Ellipsoid("thigh." + sd, "hleg1." + sd, mir(v3(0.055, 0.235, 0.035), sx), v3(0.045, 0.04, 0.05),
                          k=0.02),
                Cone("shin." + sd, "hleg2." + sd, mir(KNEE, sx), mir(ANKLE, sx), 0.024, 0.02, k=0.01),
                Cone("spur." + sd, "hleg2." + sd, mir(v3(0.05, 0.07, 0.04), sx), mir(v3(0.075, 0.17, 0.09), sx),
                     0.016, 0.006, k=0.01),
                Cone("foot." + sd, "hpaw." + sd, mir(ANKLE, sx), mir(TOE, sx), 0.02, 0.012, k=0.01),
                Ellipsoid("toes." + sd, "hpaw." + sd, mir(v3(0.07, 0.012, -0.03), sx), v3(0.06, 0.014, 0.05),
                          k=0.01)]
    return out


def parts():
    return {"body": (MeshShape(proxy_prims(), MESHY_DIR, HEIGHT), 0.0035, BODY_TRIS)}


def prop_parts():
    out = boki_tools.tools(GRIP, AXIS)
    out["berry"] = (Shape([Ellipsoid("b", "prop_berry", BERRY_C, v3(0.05, 0.048, 0.05), k=0)]), 0.003, 24)
    # Gale Lance: the gust the bellows blows out of the nozzle, a cone of ember-lit air
    out["gust"] = (Shape([Cone("g", "prop_gust", NOZZLE + v3(0, 0, -0.01), NOZZLE + v3(0, 0, -0.16), 0.015, 0.05,
                               k=0.01)]), 0.003, 60)
    return out


GROWN = {
    "horn": ((0.03, 0.645, -0.08), (0.06, 0.72, -0.05), 0.016),
    "fang": ((0.012, 0.57, -0.17), (0.013, 0.55, -0.172), 0.007),
    "antenna": ((0.025, 0.65, -0.06), (0.06, 0.74, -0.03), 0.008),
    "brow": ((0.012, 0.632, -0.13), (0.05, 0.635, -0.1), 0.01),
    "head_top": tuple(HEAD_TOP), "fang_at": (0, 0.57, -0.165), "brow_at": (0, 0.632, -0.125),
    "third_eye": (0, 0.635, -0.13),
    "back": ((0, 0.42, 0.11), (0, 0.4, 0.15), (0, 0.37, 0.18)), "back_at": (0, 0.4, 0.13), "plates": (0, 0.4, 0.14),
    "plate_r": (0.08, 0.035, 0.05), "shell_c": (0, 0.33, 0.1), "shell_r": (0.13, 0.1, 0.12), "tail_bone": "tail1",
    "club_at": tuple(TAIL_PTS[1]), "club_dir": tuple(TAIL_PTS[1] - TAIL_PTS[0]), "club_r": 0.04,
    "spots": ((0.12, 0.34, 0.0, 0.016), (0.12, 0.3, 0.06, 0.016), (0.11, 0.27, 0.11, 0.014)),
    "spots_at": (0, 0.31, 0.05),
    "wing": ((0.11, 0.38, 0.02), (0.22, 0.46, 0.1), (0.2, 0.4, 0.14)), "wing_at": (0, 0.38, 0.02),
    "fin": ((0.07, 0.16, 0.06), (0.11, 0.24, 0.12)), "fin_at": (0, 0.2, 0.06),
    "crest": (HEAD_TOP[1], HEAD_TOP[2] - 0.02, 0.03, 0.05),
    "crest_at": tuple(HEAD_TOP),
}


def grown_parts():
    return boki_grown.grown_parts(GROWN)


# ---------------------------------------------------------------- coat (Meshy's texture, the painted eyes out)
ASH = hexc("1e1c22")
EMBER = hexc("ff8a2a")
LILAC = hexc("3a3440")     # brows
INK = hexc("100c10")
LID = hexc("2a262e")
MOUTH_DARK = hexc("3a1810")
TONGUE = hexc("e0604a")
IRIS = hexc("ff9a1e")
IRIS_DEEP = hexc("8a2a06")
SHELL_A = hexc("c89a5a")
SHELL_B = hexc("8a5a2e")
SHELL_C = hexc("3a2414")


def paint_body(q):
    col = Meshy.get(MESHY_DIR, HEIGHT).colour(q)
    gone = np.zeros(len(q))
    for sx in (1, -1):
        d = np.linalg.norm((q - mir(EYE_C, sx)) * v3(1, 1, 0.8), axis=1)
        gone = np.maximum(gone, np.clip((PAINTED_EYE_R - d) / 0.01, 0, 1))
    return mixc(col, np.tile(ASH, (len(q), 1)), gone)


def paint_piece(pc, q, nn, prim):
    if pc.name == "body":
        return paint_body(q)
    if pc.name == "gust":
        return np.tile(EMBER, (len(q), 1))
    if pc.name.startswith("gp_"):
        if pc.look == "white":
            return np.ones((len(q), 3))
        if pc.look == "glow":
            return np.tile(EMBER, (len(q), 1))
        return mixc(np.tile(SHELL_B, (len(q), 1)), np.tile(SHELL_A, (len(q), 1)), np.clip(nn[:, 1], 0, 1))
    return tool_colour(pc.name, q)
