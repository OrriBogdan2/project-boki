"""Nettlynx, a lynx kitten whose ear tufts and tail are stinging nettle: shapes and coat. Game axes as vespyx.py.
NEW design (roster 50, #16), owner approval pending."""
import math

import numpy as np

import boki_grown
import boki_tools
from boki_sdf import Cone, Ellipsoid, Shape, frame, v3, value_noise
from vespyx_paint import edge, hexc, mixc, paint_shell, sat, tool_colour
from vespyx_sides import SIDES

SCALE = 0.92
HEAD_C = v3(0, 0.33, -0.2)
HEAD_R = v3(0.2, 0.175, 0.175)
EYE_C = v3(0.09, 0.35, -0.33)
EYE_R = v3(0.047, 0.052, 0.03)
EYE_YAW = 0.42
GLOW_PIECES = ()
LIT_PIECES = ("leaves",)
PALE_PIECES = ("leaves",)
BERRY_C = v3(0, 0.05, -0.5)
NOSE_C = v3(0, 0.318, -0.39)
FACE = {"mouth_w": 0.045, "mouth_y": 0.275, "mouth_z": -0.39, "cat_mouth": True, "brow_x": 0.09, "brow_up": 0.02,
        "brow_k": 0.8, "fang_k": 0.6}
TAIL_PTS = [v3(0, 0.25, 0.2), v3(0, 0.29, 0.28), v3(0, 0.34, 0.325), v3(0, 0.395, 0.35)]
TAIL_R = (0.048, 0.042, 0.036, 0.03)
# legs: (bone stem, paw bone, z of the shoulder or hip)
LEGS = (("fleg", "fpaw", -0.07), ("hleg", "hpaw", 0.17))
PAW_R = v3(0.066, 0.042, 0.072)     # huge round kitten paws
EAR_BASE = v3(0.12, 0.45, -0.18)
EAR_TIP = v3(0.165, 0.565, -0.17)
EAR_LEAF_TIP = v3(0.19, 0.675, -0.155)
# nettle leaves: (bone, base, tip, face normal, width); the ear tufts and a three-leaf sprig at the tail's end
LEAVES = [("ear2.%s", EAR_TIP - v3(0.006, 0.015, 0), EAR_LEAF_TIP, v3(0.25, 0.05, -1.0), 0.056),
          ("tail3", TAIL_PTS[3] - v3(0, 0.01, 0.005), v3(0, 0.55, 0.43), v3(0, -0.45, 1.0), 0.1),
          ("tail3", TAIL_PTS[3] - v3(0, 0.02, 0.0), v3(-0.13, 0.43, 0.42), v3(-0.2, 1.0, -0.25), 0.075),
          ("tail3", TAIL_PTS[3] - v3(0, 0.02, 0.0), v3(0.13, 0.43, 0.42), v3(0.2, 1.0, -0.25), 0.075)]
TEETH = 4           # saw teeth down each side of a leaf


def eye_frame(sx):
    out = v3(sx * math.sin(EYE_YAW), 0.1, -math.cos(EYE_YAW))
    fr = frame(out, v3(0, 1, 0))
    if (fr[0] @ v3(sx, 0, 0)) < 0:
        fr[0] = -fr[0]
    return fr


def leaf_list():
    """Every leaf, mirrored for the ears: (bone, base, tip, normal, width)."""
    out = []
    for bone, base, tip, nrm, w in LEAVES:
        if "%s" in bone:
            for sd, sx in SIDES:
                m = v3(sx, 1, 1)
                out.append((bone % sd, base * m, tip * m, nrm * m, w))
        else:
            out.append((bone, base, tip, nrm, w))
    return out


def leaf_axes(base, tip, nrm):
    """Unit vectors along the leaf, across it, and through it."""
    along = (tip - base) / np.linalg.norm(tip - base)
    across = np.cross(nrm, along)
    across = across / np.linalg.norm(across)
    return along, across, np.cross(along, across)


def leaf(name, bone, base, tip, nrm, w):
    """A nettle leaf: an ovate blade, a drawn-out point and saw teeth down both edges, all thin."""
    along, across, thru = leaf_axes(base, tip, nrm)
    length = np.linalg.norm(tip - base)
    flat = {"flat": 0.3, "flat_axis": thru}
    out = [Ellipsoid(name + "b", bone, base + along * length * 0.42, v3(w * 0.5, length * 0.42, 0.0055),
                     rot=frame(thru, along), k=0),
           Cone(name + "t", bone, base + along * length * 0.6, tip, w * 0.24, 0.002, k=0.01, **flat)]
    for i in range(TEETH):
        u = 0.18 + 0.62 * i / (TEETH - 1)
        half = w * 0.5 * math.sqrt(max(0.0, 1 - ((u - 0.42) / 0.42) ** 2)) * 0.92
        for sgn in (-1, 1):
            at = base + along * length * u + across * sgn * half
            out.append(Cone("%s%d%d" % (name, i, sgn > 0), bone, at - across * sgn * 0.008,
                            at + (across * sgn * 0.55 + along) * w * 0.2, 0.011, 0.0015, k=0.004, **flat))
    return out


def body_prims():
    p = [
        Ellipsoid("torso", "hips", v3(0, 0.235, 0.08), v3(0.15, 0.135, 0.16), k=0.03),
        Ellipsoid("chest", "spine", v3(0, 0.245, -0.04), v3(0.15, 0.145, 0.13), k=0.05),
        Cone("neck", "neck", v3(0, 0.26, -0.06), v3(0, 0.3, -0.14), 0.12, 0.13, k=0.05),
        Ellipsoid("head", "head", HEAD_C, HEAD_R, k=0.04),
        Ellipsoid("muzzle", "head", v3(0, 0.29, -0.345), v3(0.088, 0.062, 0.055), k=0.035),
        Ellipsoid("nose", "head", NOSE_C, v3(0.02, 0.014, 0.012), k=0.006),
    ]
    for sd, sx in SIDES:
        # the lynx ruff: full cheeks ending in two soft points
        p.append(Ellipsoid("cheek" + sd, "head", v3(sx * 0.14, 0.285, -0.24), v3(0.085, 0.07, 0.085), k=0.04))
        for j, (dy, dz) in enumerate(((0.0, 0.0), (-0.05, 0.03))):
            a = v3(sx * 0.18, 0.28 + dy, -0.22 + dz)
            p.append(Cone("ruff%s%d" % (sd, j), "head", a, a + v3(sx * 0.07, -0.035, 0.03), 0.035, 0.006, k=0.02))
        n = v3(sx * 0.3, 0.1, -1.0)
        p.append(Cone("ear" + sd, "ear1." + sd, EAR_BASE * v3(sx, 1, 1), EAR_TIP * v3(sx, 1, 1), 0.056, 0.01, k=0.025,
                      flat=0.45, flat_axis=n))
        p.append(Cone("earhole" + sd, "ear1." + sd, EAR_BASE * v3(sx, 1, 1) + v3(0, 0.01, -0.03),
                      EAR_TIP * v3(sx, 1, 1) + v3(0, -0.02, -0.012), 0.036, 0.004, k=0.01, flat=0.4, flat_axis=n,
                      sub=True))
        for leg, paw, z in LEGS:
            hind = leg == "hleg"
            top = v3(sx * 0.1, 0.19, z)
            knee = v3(sx * 0.11, 0.11, z + (0.02 if hind else -0.005))
            ankle = v3(sx * 0.115, 0.05, z - 0.005)
            if hind:
                p.append(Ellipsoid("haunch" + sd, "hleg1." + sd, v3(sx * 0.1, 0.2, z), v3(0.068, 0.085, 0.09), k=0.03))
            p.append(Cone(leg + "1" + sd, "%s1.%s" % (leg, sd), top, knee, 0.056, 0.048, k=0.03))
            p.append(Cone(leg + "2" + sd, "%s2.%s" % (leg, sd), knee, ankle, 0.048, 0.044, k=0.015))
            p.append(Ellipsoid(paw + sd, "%s.%s" % (paw, sd), ankle + v3(sx * 0.006, -0.008, -0.03), PAW_R, k=0.02))
    for i in range(len(TAIL_PTS) - 1):
        p.append(Cone("tail%d" % i, "tail%d" % (i + 1), TAIL_PTS[i], TAIL_PTS[i + 1], TAIL_R[i], TAIL_R[i + 1],
                      k=0.03 if i == 0 else 0.012))
    return p


def leaf_prims():
    out = []
    for i, (bone, base, tip, nrm, w) in enumerate(leaf_list()):
        out += leaf("l%d" % i, bone, base, tip, nrm, w)
    return out


def parts():
    return {
        "body": (Shape(body_prims()), 0.0035, 2600),
        "leaves": (Shape(leaf_prims()), 0.0022, 440),
    }


AXIS = np.array((0.0, 0.5, -0.866))
GRIP = v3(0, 0.27, -0.42)


def prop_parts():
    out = boki_tools.tools(GRIP, AXIS)
    out["berry"] = (Shape([Ellipsoid("b", "prop_berry", BERRY_C, v3(0.054, 0.052, 0.054), k=0)]), 0.003, 24)
    return out


GROWN = {
    "horn": ((0.06, 0.48, -0.25), (0.11, 0.6, -0.31), 0.032), "fang": ((0.022, 0.265, -0.39), (0.026, 0.225, -0.395), 0.012),
    "antenna": ((0.05, 0.49, -0.26), (0.1, 0.63, -0.34), 0.011), "brow": ((0.014, 0.43, -0.34), (0.12, 0.435, -0.3), 0.016),
    "head_top": (0, 0.49, -0.22), "fang_at": (0, 0.27, -0.38), "brow_at": (0, 0.42, -0.33), "third_eye": (0, 0.43, -0.34),
    "back": ((0, 0.36, -0.08), (0, 0.37, 0.04), (0, 0.35, 0.16)), "back_at": (0, 0.36, 0.04), "plates": (0, 0.37, -0.02),
    "plate_r": (0.12, 0.036, 0.09), "shell_c": (0, 0.24, 0.06), "shell_r": (0.165, 0.155, 0.06), "tail_bone": "tail2",
    "club_at": tuple(TAIL_PTS[2]), "club_dir": tuple(TAIL_PTS[3] - TAIL_PTS[1]), "club_r": 0.055,
    "spots": ((0.15, 0.25, -0.02, 0.022), (0.15, 0.24, 0.08, 0.02), (0.14, 0.22, 0.16, 0.02)), "spots_at": (0, 0.24, 0.06),
    "wing": ((0.12, 0.33, 0.0), (0.31, 0.43, 0.1), (0.27, 0.39, 0.19)), "wing_at": (0, 0.33, 0.02),
    "fin": ((0.14, 0.24, 0.12), (0.2, 0.34, 0.22)), "fin_at": (0, 0.24, 0.12), "crest": (0.48, -0.24, 0.05, 0.06),
    "crest_at": (0, 0.48, -0.2),
}


def grown_parts():
    return boki_grown.grown_parts(GROWN)


# ---------------------------------------------------------------- coat
FUR = hexc("8a9a4a")
FUR_LIGHT = hexc("abb862")
FUR_DARK = hexc("5e6c2e")
SPOT = hexc("3e4622")
CREAM = hexc("e8e0c0")
EAR_IN = hexc("f0d8c0")
EAR_TIP_DARK = hexc("343a1c")
BLUSH = hexc("ff9c8a")
NOSE = hexc("e88a8a")
PAD = hexc("d8a890")
LEAF = hexc("3e7a26")
LEAF_DEEP = hexc("24521a")
LEAF_VEIN = hexc("8fd04a")
LEAF_EDGE = hexc("d0ff4a")
STING = hexc("f4ffe0")
LILAC = hexc("4e5a26")     # brows
LID = FUR_LIGHT
INK = hexc("262c14")
MOUTH_DARK = hexc("5e2424")
TONGUE = hexc("f08a8a")
IRIS = hexc("e0b03a")
IRIS_DEEP = hexc("4a3008")
HORN_A = hexc("d6e08a")
HORN_B = hexc("8a9a4a")
HORN_C = hexc("4e5a26")


def paint_body(p, n, prim):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    ax = np.abs(x)
    grain = value_noise(p * np.array([90, 40, 40]))
    col = mixc(FUR_DARK, FUR, sat(n[:, 1] * 0.55 + 0.6 + (grain - 0.5) * 0.35))
    col = mixc(col, FUR_LIGHT, sat(n[:, 1] - 0.3) * 0.45)
    jag = (value_noise(p * np.array([70, 20, 70])) - 0.5) * 0.02
    # dark spots on the back, flanks and haunches (not on the face)
    spots = sat((value_noise(p * 52 + 3.1) - 0.64) / 0.04) * edge(z + 0.1, 0.02) * edge(y - 0.17, 0.02)
    col = mixc(col, SPOT, spots * 0.85)
    # cream chin, muzzle, bib, belly and the ruff's points
    legs = np.min(np.stack([prim[leg + k + sd].d(p) for leg, _, _ in LEGS for k in "12" for sd in "LR"], -1), -1)
    under = edge(-n[:, 1] - 0.3 + jag * 4, 0.1) * edge(legs - 0.015, 0.01)
    bib = edge(0.065 + (0.29 - y) * 0.3 - ax + jag, 0.01) * edge(0.3 - y, 0.012) * edge(-0.03 - z, 0.03)
    muzzle = edge(0.004 - prim["muzzle"].d(p), 0.008) * edge(0.31 - y, 0.012)
    ruff = sum(edge(0.004 - prim["ruff%s%d" % (sd, j)].d(p), 0.006) for sd in "LR" for j in (0, 1))
    col = mixc(col, CREAM, sat(under + bib + muzzle + ruff * 0.8))
    # lynx cheek lines: two thin dark strokes back from each eye
    for sx in (-1.0, 1.0):
        for dy in (0.0, -0.035):
            d = np.abs((y - 0.32 - dy) + (ax - 0.13) * 0.35)
            col = mixc(col, SPOT, edge(0.006 - d, 0.002) * edge(ax - 0.12, 0.01) * edge(0.19 - ax, 0.01)
                       * (np.sign(x) == sx) * (z < -0.18) * 0.8)
    for sd in "LR":
        ear = prim["ear" + sd].d(p) < 0.01
        col = mixc(col, EAR_IN, edge(0.005 - prim["earhole" + sd].d(p), 0.004) * ear)
        col = mixc(col, EAR_TIP_DARK, edge(y - 0.53, 0.01) * ear)
        for _, paw, _ in LEGS:
            on_paw = edge(0.004 - prim[paw + sd].d(p), 0.006)
            col = mixc(col, mixc(CREAM, FUR_LIGHT, sat(0.4 - n[:, 1])), on_paw * 0.85)
            col = mixc(col, PAD, on_paw * (n[:, 1] < -0.5))
    for sx in (-1.0, 1.0):
        q = (p - np.array([sx * 0.13, 0.3, 0])) / np.array([0.042, 0.026, 1.0])
        col = mixc(col, BLUSH, np.exp(-(q[:, 0] ** 2 + q[:, 1] ** 2) * 1.25) * (z < -0.25) * 0.7)
    return mixc(col, NOSE, edge(0.003 - prim["nose"].d(p), 0.0015))


def paint_paws(p, col, prim):
    """Toe lines on top of the big paws."""
    for _, paw, _ in LEGS:
        for sd, sx in SIDES:
            c = prim[paw + sd].c
            q = p - c
            on = (prim[paw + sd].d(p) < 0.006) & (q[:, 1] > -0.005) & (q[:, 2] < -0.02)
            for k in (-1, 1):
                d = np.abs(q[:, 0] - k * 0.02 - q[:, 2] * k * 0.15)
                col = mixc(col, FUR_DARK * 0.8, edge(0.003 - d, 0.0015) * on)
    return col


def paint_leaves(q, n):
    """Nettle green, a pale midrib and veins, lime saw teeth along the edge, a few pale stinging hairs."""
    leaves = leaf_list()
    best = np.full(len(q), 1e9)
    along_k = np.zeros(len(q))
    across_k = np.zeros(len(q))
    for bone, base, tip, nrm, w in leaves:
        along, across, thru = leaf_axes(base, tip, nrm)
        r = q - base
        d = np.abs(r @ thru)
        u = (r @ along) / np.linalg.norm(tip - base)
        v = (r @ across) / (w * 0.5)
        score = d + np.maximum(0.0, np.abs(u - 0.5) - 0.5) * 0.1
        near = score < best
        best = np.where(near, score, best)
        along_k = np.where(near, u, along_k)
        across_k = np.where(near, v, across_k)
    av = np.abs(across_k)
    profile = np.sqrt(sat(1 - ((along_k - 0.42) / 0.42) ** 2)) * 0.92
    col = mixc(LEAF_DEEP, LEAF, sat(n[:, 1] * 0.3 + 0.6 + av * 0.3))
    vein = edge(0.06 - np.abs(np.modf((along_k - av * 0.55) * 5 + 10)[0] - 0.5) * 0.6, 0.02) * edge(0.85 - av, 0.05)
    col = mixc(col, LEAF_VEIN, sat(edge(0.07 - av, 0.02) + vein * 0.7))
    col = mixc(col, LEAF_EDGE, edge(av - profile * 0.82, 0.04) + edge(along_k - 0.86, 0.04))
    return mixc(col, STING, sat((value_noise(q * 300) - 0.86) / 0.04))


def paint_piece(pc, q, nn, prim):
    if pc.name == "body":
        return paint_paws(q, paint_body(q, nn, prim), prim)
    if pc.name == "leaves":
        return paint_leaves(q, nn)
    if pc.name.startswith("gp_"):
        if pc.look == "white":
            return np.ones((len(q), 3))
        if pc.look == "glow":
            return np.tile(LEAF_EDGE, (len(q), 1))
        return paint_shell(q, nn, np.full(len(q), 1.0), HORN_A, HORN_B, HORN_C)
    return tool_colour(pc.name, q)
