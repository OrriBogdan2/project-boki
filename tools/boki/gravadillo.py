"""Gravadillo (pebbit), an armadillo with a rhino beetle's horn and violet gravity in its seams: shapes and coat.
Game axes as vespyx.py."""
import math

import numpy as np

import boki_grown
import boki_tools
from boki_sdf import Cone, Ellipsoid, Shape, frame, v3, value_noise
from vespyx_paint import edge, hexc, mixc, paint_shell, sat, tool_colour
from vespyx_sides import SIDES

SCALE = 0.95
HEAD_C = v3(0, 0.29, -0.32)
HEAD_R = v3(0.18, 0.158, 0.16)
EYE_C = v3(0.094, 0.309, -0.430)
EYE_R = v3(0.042, 0.047, 0.028)
EYE_YAW = 0.42
GLOW_PIECES = ("glow",)
BERRY_C = v3(0, 0.05, -0.52)
FACE = {"mouth_w": 0.054, "mouth_y": 0.238, "mouth_z": -0.50, "cat_mouth": False, "brow_x": 0.092, "brow_up": 0.02,
        "brow_k": 0.68, "fang_k": 0.0}
# the shell: two domes (front on the spine, back on the hips), cut flat at the rim, banded by glowing seams
SHELL = ((v3(0, 0.28, -0.04), v3(0.265, 0.225, 0.20), "spine"), (v3(0, 0.28, 0.12), v3(0.265, 0.225, 0.21), "hips"))
RIM_Y = 0.145
SEAMS_Z = (-0.142, -0.024, 0.094, 0.212)
SEAM_R = 0.0085
GROOVE_R = 0.0125
HORN_PTS = [v3(0, 0.345, -0.42), v3(0, 0.45, -0.465), v3(0, 0.535, -0.467), v3(0, 0.598, -0.44),
            v3(0, 0.632, -0.40)]
HORN_R = [(0.048, 0.039), (0.037, 0.031), (0.029, 0.023), (0.022, 0.017)]
HORN_TIP = v3(0, 0.638, -0.387)
TAIL_PTS = [v3(0, 0.17, 0.30), v3(0, 0.145, 0.37), v3(0, 0.115, 0.43), v3(0, 0.085, 0.475), v3(0, 0.06, 0.505)]
TAIL_R = [(0.05, 0.042), (0.041, 0.033), (0.032, 0.024), (0.023, 0.014)]


def eye_frame(sx):
    out = v3(sx * math.sin(EYE_YAW), 0.1, -math.cos(EYE_YAW))
    fr = frame(out, v3(0, 1, 0))
    if (fr[0] @ v3(sx, 0, 0)) < 0:
        fr[0] = -fr[0]
    return fr


def shell_domes():
    return [Ellipsoid("shell%d" % i, bone, c, r, k=0.09) for i, (c, r, bone) in enumerate(SHELL)]


def seam_points(z0, n=15):
    """Points along the shell's surface where it crosses z = z0, rim to rim over the top."""
    dome = Shape(shell_domes())
    centre = v3(0, 0.24, z0)
    out = []
    for th in np.linspace(-2.0, 2.0, n):
        d = v3(math.sin(th), math.cos(th), 0)
        lo, hi = 0.0, 0.5
        for _ in range(30):
            mid = (lo + hi) / 2
            if dome.eval((centre + d * mid)[None])[0] < 0:
                lo = mid
            else:
                hi = mid
        p = centre + d * lo
        if p[1] > RIM_Y + 0.004:
            out.append(p)
    return out


def seam_bone(z):
    return "spine" if z < 0.04 else "hips"


def seam_chain(tag, z0, r, sink=0.0, sub=False):
    pts = seam_points(z0)
    centre = v3(0, 0.24, z0)
    pts = [p - (p - centre) / np.linalg.norm(p - centre) * sink for p in pts]
    return [Cone("%s%d" % (tag, i), seam_bone(z0), a, b, r, r, k=0.004 if sub else 0.0, sub=sub)
            for i, (a, b) in enumerate(zip(pts, pts[1:]))]


def shell_prims():
    p = shell_domes()
    p.append(Ellipsoid("cut", "hips", v3(0, RIM_Y - 1.0, 0.03), v3(2.0, 1.0, 2.0), k=0.012, sub=True))
    for j, z in enumerate(SEAMS_Z):
        p += seam_chain("groove%d_" % j, z, GROOVE_R, sub=True)
    return p


def body_prims():
    p = [
        Ellipsoid("torso", "hips", v3(0, 0.215, 0.12), v3(0.215, 0.145, 0.19), k=0.03),
        Ellipsoid("chest", "spine", v3(0, 0.22, -0.06), v3(0.21, 0.15, 0.16), k=0.06),
        Cone("neck", "neck", v3(0, 0.225, -0.12), v3(0, 0.26, -0.23), 0.12, 0.13, k=0.05),
        Ellipsoid("head", "head", HEAD_C, HEAD_R, k=0.04),
        Ellipsoid("muzzle", "head", v3(0, 0.245, -0.405), v3(0.12, 0.085, 0.08), k=0.05),
    ]
    for sd, sx in SIDES:
        c = v3(sx * 0.13, 0.425, -0.29)
        n = v3(sx * 0.4, 0.2, -1.0)
        p.append(Ellipsoid("ear" + sd, "ear1." + sd, c, v3(0.04, 0.05, 0.017), rot=frame(n, v3(0, 1, 0)), k=0.012))
        p.append(Ellipsoid("earhole" + sd, "ear1." + sd, c + n / np.linalg.norm(n) * 0.014, v3(0.024, 0.032, 0.01),
                           rot=frame(n, v3(0, 1, 0)), k=0.006, sub=True))
        for leg, z in (("f", -0.12), ("h", 0.2)):
            top = v3(sx * 0.13, 0.17, z)
            knee = v3(sx * 0.148, 0.09, z - 0.008)
            ankle = v3(sx * 0.152, 0.036, z - 0.014)
            p.append(Cone(leg + "leg1" + sd, "%sleg1.%s" % (leg, sd), top, knee, 0.06, 0.052, k=0.03))
            p.append(Cone(leg + "leg2" + sd, "%sleg2.%s" % (leg, sd), knee, ankle, 0.052, 0.048, k=0.012))
            paw = v3(sx * 0.154, 0.027, z - 0.036)
            p.append(Ellipsoid(leg + "paw" + sd, "%spaw.%s" % (leg, sd), paw, v3(0.054, 0.028, 0.062), k=0.016))
            for j, dx in enumerate((-0.03, 0.0, 0.03)):
                toe = paw + v3(sx * dx, -0.004, -0.05 + abs(dx) * 0.4)
                p.append(Ellipsoid("%stoe%s%d" % (leg, sd, j), "%spaw.%s" % (leg, sd), toe, v3(0.017, 0.016, 0.018),
                                   k=0.006))
    return p


def horn_prims():
    out = []
    for i, (ra, rb) in enumerate(HORN_R):
        out.append(Cone("horn%d" % i, "horn", HORN_PTS[i], HORN_PTS[i + 1], ra, rb, k=0.004))
    return out


def tail_prims():
    out = []
    for i, (ra, rb) in enumerate(TAIL_R):
        out.append(Cone("seg%d" % i, "tail%d" % (i + 1), TAIL_PTS[i], TAIL_PTS[i + 1], ra, rb, k=0.0))
    return out


def ring(name, bone, at, along, r):
    return Ellipsoid(name, bone, at, v3(r, r, 0.0055), rot=frame(along, v3(1, 0, 0)), k=0)


def glow_prims():
    """The seams between the bands, the rings of the horn and tail, the horn's tip."""
    out = []
    for j, z in enumerate(SEAMS_Z):
        out += seam_chain("seam%d_" % j, z, SEAM_R, sink=0.005)
    for i in range(1, len(HORN_PTS) - 1):
        d = HORN_PTS[i + 1] - HORN_PTS[i - 1]
        out.append(ring("hring%d" % i, "horn", HORN_PTS[i], d, HORN_R[i][0] + 0.005))
    out.append(Ellipsoid("tip", "horn", HORN_TIP, v3(0.024, 0.024, 0.024), k=0))
    for i in range(1, len(TAIL_PTS) - 1):
        d = TAIL_PTS[i + 1] - TAIL_PTS[i - 1]
        out.append(ring("tring%d" % i, "tail%d" % (i + 1), TAIL_PTS[i], d, TAIL_R[i][0] + 0.004))
    return out


def parts():
    return {
        "body": (Shape(body_prims()), 0.0035, 2050),
        "shell": (Shape(shell_prims()), 0.0035, 900),
        "horn": (Shape(horn_prims()), 0.0035, 135),
        "tail": (Shape(tail_prims()), 0.0035, 135),
        "glow": (Shape(glow_prims()), 0.0025, 345),
    }


AXIS = np.array((0.0, 0.5, -0.866))
GRIP = v3(0, 0.222, -0.485)


def prop_parts():
    out = boki_tools.tools(GRIP, AXIS)
    out["berry"] = (Shape([Ellipsoid("b", "prop_berry", BERRY_C, v3(0.054, 0.052, 0.054), k=0)]), 0.003, 24)
    return out


GROWN = {
    "horn": ((0.08, 0.42, -0.34), (0.16, 0.54, -0.38), 0.032),
    "fang": ((0.036, 0.222, -0.48), (0.039, 0.185, -0.485), 0.013),
    "antenna": ((0.06, 0.425, -0.33), (0.13, 0.59, -0.40), 0.012),
    "brow": ((0.04, 0.378, -0.435), (0.135, 0.382, -0.395), 0.012),
    "head_top": (0, 0.44, -0.32), "fang_at": (0, 0.23, -0.47), "brow_at": (0, 0.38, -0.42),
    "third_eye": (0, 0.42, -0.488),
    "back": ((0, 0.515, -0.08), (0, 0.525, 0.03), (0, 0.505, 0.15)), "back_at": (0, 0.50, 0.03),
    "plates": (0, 0.505, 0.0),
    "plate_r": (0.17, 0.04, 0.11), "shell_c": (0, 0.42, 0.04), "shell_r": (0.215, 0.1, 0.17), "tail_bone": "tail3",
    "club_at": tuple(TAIL_PTS[3]), "club_dir": tuple(TAIL_PTS[4] - TAIL_PTS[2]), "club_r": 0.05,
    "spots": ((0.262, 0.31, -0.085, 0.022), (0.262, 0.29, 0.015, 0.02), (0.25, 0.27, 0.115, 0.022)),
    "spots_at": (0, 0.29, 0.02),
    "wing": ((0.18, 0.45, 0.0), (0.38, 0.56, 0.08), (0.34, 0.51, 0.18)), "wing_at": (0, 0.46, 0.02),
    "fin": ((0.235, 0.30, 0.17), (0.31, 0.40, 0.28)), "fin_at": (0, 0.30, 0.17), "crest": (0.43, -0.30, 0.05, 0.06),
    "crest_at": (0, 0.43, -0.27),
}


def grown_parts():
    return boki_grown.grown_parts(GROWN)


# ---------------------------------------------------------------- coat
SLATE = hexc("5a6290")
SLATE_LIGHT = hexc("7e86b2")
BAND_BLUE = hexc("6c79a2")
BAND_BLUE_LIGHT = hexc("94a0c8")
BAND_MAUVE = hexc("8e8aa8")
BAND_MAUVE_LIGHT = hexc("aea6c4")
RIM = hexc("2c2f44")
CREAM = hexc("f2e6c6")
CREAM_SHADE = hexc("d8c8a8")
EAR_IN = hexc("b8a6c0")
BLUSH = hexc("ff8fa6")
LILAC = hexc("7c74a4")     # brows: read on the cream and on the slate
LID = CREAM
INK = hexc("262438")
MOUTH_DARK = hexc("5a2440")
TONGUE = hexc("f08aa0")
IRIS = hexc("9a6cff")
HORN = hexc("646a94")
HORN_LIGHT = hexc("aab0da")
HORN_DARK = hexc("3a3e5c")


def paint_body(p, n, prim):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    ax = np.abs(x)
    fine = value_noise(p * np.array([60, 40, 60]))
    dark = mixc(SLATE, SLATE_LIGHT, sat(n[:, 1] * 0.6 + 0.2 + (fine - 0.5) * 0.3))
    # the cream: the face up over the eyes, throat and belly; the slate runs down between the eyes into the horn
    face_line = np.interp(ax, [0, 0.03, 0.07, 0.14, 0.2], [0.33, 0.345, 0.392, 0.388, 0.35])
    on_head = z < -0.2
    head_cream = edge(face_line - y, 0.005) * on_head
    belly = edge(0.205 - y + ax * 0.15, 0.008) * (z >= -0.2) * edge(0.2 - ax, 0.02)
    legs = (y < 0.15) & (ax > 0.1)
    dark = mixc(dark, SLATE_LIGHT * 1.1, legs * 0.45)
    cream = sat(head_cream + belly) * (~legs)
    shade = mixc(CREAM_SHADE, CREAM, sat(n[:, 1] * 0.5 + 0.7))
    col = mixc(dark, shade, cream)
    # belly segments: soft lines across it
    band = np.abs(((z + 0.2) / 0.075) % 1.0 - 0.5)
    col = mixc(col, CREAM_SHADE * 0.9, edge(0.05 - band, 0.025) * belly * (~legs) * (z > -0.15) * (z < 0.3) * 0.6)
    for sd in "LR":
        hole = prim["earhole" + sd].d(p)
        ear = prim["ear" + sd].d(p) < 0.02
        col = mixc(col, EAR_IN, edge(0.004 - hole, 0.002) * ear)
    for sx in (-1.0, 1.0):
        q = (p - np.array([sx * 0.122, 0.262, 0])) / np.array([0.04, 0.026, 1.0])
        col = mixc(col, BLUSH, np.exp(-(q[:, 0] ** 2 + q[:, 1] ** 2) * 1.25) * (z < -0.33) * 0.65)
    return col


def paint_shell_bands(p, n):
    """Blue and mauve bands, glossy on top, darker to the rim, a dark lip underneath."""
    z = p[:, 2]
    band = np.searchsorted(np.array(SEAMS_Z), z) % 2
    mottle = (value_noise(p * np.array([26, 26, 40])) - 0.5) * 0.35
    up = sat(n[:, 1] * 0.6 + 0.45 + mottle)
    blue = mixc(BAND_BLUE * 0.78, BAND_BLUE_LIGHT, up)
    mauve = mixc(BAND_MAUVE * 0.76, BAND_MAUVE_LIGHT, up)
    col = np.where(band[:, None] == 1, mauve, blue)
    h = np.array([-0.35, 0.8, -0.48])
    h = h / np.linalg.norm(h)
    col = mixc(col, np.array([0.93, 0.92, 1.0]), sat((n @ h - 0.95) / 0.04) * 0.45)
    return mixc(col, RIM, edge(-n[:, 1] - 0.55, 0.12))


def paint_piece(pc, q, nn, prim):
    if pc.name == "body":
        return paint_body(q, nn, prim)
    if pc.name == "shell":
        return paint_shell_bands(q, nn)
    if pc.name in ("horn", "tail"):
        return paint_shell(q, nn, np.full(len(q), 1.0), HORN_LIGHT, HORN, HORN_DARK)
    if pc.name.startswith("gp_"):
        if pc.look == "white":
            return np.ones((len(q), 3))
        if pc.look == "glow":
            return np.tile(hexc("c8a8ff"), (len(q), 1))
        return paint_shell(q, nn, np.full(len(q), 1.0), HORN_LIGHT, HORN, HORN_DARK)
    if pc.name in GLOW_PIECES:
        return np.tile(hexc("c8a8ff"), (len(q), 1))
    return tool_colour(pc.name, q)
