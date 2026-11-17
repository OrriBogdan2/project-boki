"""Marchleaf, a leafcutter ant holding up a leaf like a sail, three tiny workers marching behind: shapes and coat.
Game axes as vespyx.py. NEW design (roster 50, #20), owner approval pending."""
import math

import numpy as np

import boki_grown
import boki_tools
from boki_sdf import Cone, Ellipsoid, Shape, frame, v3, value_noise
from vespyx_paint import edge, hexc, mixc, paint_shell, sat, tool_colour
from vespyx_sides import SIDES

SCALE = 0.95
HEAD_C = v3(0, 0.33, -0.2)
HEAD_R = v3(0.175, 0.16, 0.155)
EYE_C = v3(0.086, 0.366, -0.316)
EYE_R = v3(0.041, 0.046, 0.03)
EYE_YAW = 0.48
GLOW_PIECES = ("antips",)
PALE_PIECES = ("leaf", "minis")
BERRY_C = v3(0, 0.05, -0.5)
FACE = {"mouth_w": 0.046, "mouth_y": 0.29, "mouth_z": -0.36, "cat_mouth": True, "brow_x": 0.086, "brow_up": 0.02,
        "brow_k": 0.75, "fang_k": 0.0}
THORAX_C = v3(0, 0.215, -0.03)
GASTER_PTS = (v3(0, 0.22, 0.08), v3(0, 0.29, 0.33))      # the tail1 bone: the round hind body sways like a tail
GASTER_C = v3(0, 0.255, 0.2)
GASTER_R = v3(0.13, 0.12, 0.14)
# the antennae, elbowed: base, elbow, tip (right side)
FEELER = (v3(0.06, 0.47, -0.25), v3(0.12, 0.6, -0.26), v3(0.2, 0.64, -0.36))
JAW_TIP = v3(0.026, 0.212, -0.385)
# the leaf's stem runs out of the right mandible, up past the cheek (where it bends: the leaf1 bone), to the blade
# over and behind the head
STEM = (v3(0.03, 0.215, -0.375), v3(0.17, 0.235, -0.33), v3(0.235, 0.36, -0.27), v3(0.2, 0.53, -0.15))
LEAF_BASE = STEM[-1]
LEAF_TIP = v3(-0.1, 0.9, 0.06)
LEAF_FACING = v3(0.15, 0.5, -0.85)        # the blade faces forward and up: the cameras see it whole
LEAF_HALF = (0.15, 0.012, 0.215)          # half width, half thickness, half length (m)
# the tiny workers: where each stands (on the ground), each on its own free bone
MINIS = (v3(0.025, 0.0, 0.43), v3(-0.02, 0.0, 0.56), v3(0.02, 0.0, 0.69))
MINI_K = 1.25      # the workers' size against the numbers in mini_prims
# short chibi legs, all four off the thorax: hip, knee, ankle (right side)
LEGS = (("fleg", v3(0.06, 0.18, -0.07), v3(0.13, 0.15, -0.12), v3(0.16, 0.03, -0.15)),
        ("hleg", v3(0.06, 0.18, 0.02), v3(0.14, 0.15, 0.08), v3(0.17, 0.03, 0.12)))


def eye_frame(sx):
    out = v3(sx * math.sin(EYE_YAW), 0.1, -math.cos(EYE_YAW))
    fr = frame(out, v3(0, 1, 0))
    if (fr[0] @ v3(sx, 0, 0)) < 0:
        fr[0] = -fr[0]
    return fr


def leaf_frame():
    """Rows: across the blade, its face normal, along it from the stem to the tip."""
    along = LEAF_TIP - LEAF_BASE
    n = LEAF_FACING - along * (LEAF_FACING @ along) / (along @ along)
    return frame(along, n / np.linalg.norm(n))


LEAF_ROT = leaf_frame()
LEAF_C = LEAF_BASE + (LEAF_TIP - LEAF_BASE) * 0.48


def leg(p, sd, sx, name, top, knee, ankle, r):
    p.append(Cone(name + "1" + sd, "%s1.%s" % (name, sd), top, knee, r, r * 0.8, k=0.02))
    p.append(Cone(name + "2" + sd, "%s2.%s" % (name, sd), knee, ankle, r * 0.8, r * 0.62, k=0.012))
    paw = name[0] + "paw." + sd
    p.append(Ellipsoid(name[0] + "paw" + sd, paw, ankle + v3(sx * 0.006, -0.008, -0.016), v3(0.036, 0.024, 0.044), k=0.01))


def body_prims():
    p = [
        Ellipsoid("petiole", "hips", v3(0, 0.215, 0.075), v3(0.05, 0.052, 0.05), k=0.025),
        Ellipsoid("thorax", "spine", THORAX_C, v3(0.088, 0.085, 0.1), k=0.03),
        Cone("neck", "neck", v3(0, 0.22, -0.08), v3(0, 0.26, -0.14), 0.062, 0.07, k=0.04),
        Ellipsoid("head", "head", HEAD_C, HEAD_R, k=0.03),
        Ellipsoid("cheeks", "head", v3(0, 0.27, -0.25), v3(0.15, 0.1, 0.12), k=0.05),
        Ellipsoid("gaster", "tail1", GASTER_C, GASTER_R, rot=frame(GASTER_PTS[1] - GASTER_PTS[0], v3(1, 0, 0)), k=0.03),
    ]
    for sd, sx in SIDES:
        root = v3(sx * 0.06, 0.225, -0.335)
        bend = v3(sx * 0.07, 0.205, -0.37)
        p.append(Cone("jaw" + sd, "head", root, bend, 0.022, 0.017, k=0.01))
        p.append(Cone("jawtip" + sd, "head", bend, JAW_TIP * v3(sx, 1, 1), 0.017, 0.007, k=0.006))
        base, elbow, tip = (f * v3(sx, 1, 1) for f in FEELER)
        p.append(Cone("scape" + sd, "ear1." + sd, base, elbow, 0.017, 0.013, k=0.012))
        p.append(Cone("funicle" + sd, "ear2." + sd, elbow, tip, 0.013, 0.012, k=0.006))
        for name, top, knee, ankle in LEGS:
            leg(p, sd, sx, name, top * v3(sx, 1, 1), knee * v3(sx, 1, 1), ankle * v3(sx, 1, 1), 0.034)
    return p


def antip_prims():
    return [Ellipsoid("tip" + sd, "ear2." + sd, FEELER[2] * v3(sx, 1, 1), v3(0.024, 0.024, 0.024), k=0)
            for sd, sx in SIDES]


def leaf_prims():
    """A cut piece of leaf: a broad blade with a pointed tip and a half-moon bite out of its edge, on a bent stem."""
    out = [Cone("stem%d" % i, "head" if i < 2 else "leaf1", a, b, 0.016, 0.014, k=0.01)
           for i, (a, b) in enumerate(zip(STEM, STEM[1:]))]
    rot = LEAF_ROT
    w, th, ln = LEAF_HALF
    out.append(Ellipsoid("blade", "leaf2", LEAF_C, v3(w, th, ln), rot=rot, k=0.0))
    out.append(Cone("point", "leaf2", LEAF_C + rot[2] * ln * 0.4, LEAF_TIP + rot[2] * 0.04, w * 0.62, 0.004, k=0.02,
                    flat=th / (w * 0.62), flat_axis=rot[1]))
    out.append(Cone("rib", "leaf2", LEAF_BASE, LEAF_TIP, 0.013, 0.006, k=0.012))
    out.append(Ellipsoid("bite", "leaf2", LEAF_C + rot[0] * w * 1.08 + rot[2] * ln * 0.22, v3(0.07, 0.06, 0.07),
                         k=0.008, sub=True))
    return out


def mini_prims():
    """Three tiny workers, each holding up a leaf chip of its own."""
    out = []
    k = MINI_K
    chip = frame(v3(-0.4, 1, 0.3), v3(0, 0.3, -1))
    for i, at in enumerate(MINIS):
        bone = "mini%d" % (i + 1)
        out += [Ellipsoid("mh%d" % i, bone, at + v3(0, 0.05, -0.045) * k, v3(0.03, 0.028, 0.028) * k, k=0.01),
                Ellipsoid("mt%d" % i, bone, at + v3(0, 0.042, -0.008) * k, v3(0.017, 0.016, 0.022) * k, k=0.012),
                Ellipsoid("mg%d" % i, bone, at + v3(0, 0.048, 0.04) * k, v3(0.028, 0.026, 0.034) * k, k=0.012)]
        for sx in (-1.0, 1.0):
            out.append(Cone("ml%d%d" % (i, sx > 0), bone, at + v3(sx * 0.008, 0.035, -0.005) * k,
                            at + v3(sx * 0.028, 0.004, -0.004) * k, 0.009, 0.008, k=0.006))
        out.append(Ellipsoid("mc%d" % i, bone, at + v3(-0.012, 0.115, -0.02) * k, v3(0.042, 0.007, 0.05) * k,
                             rot=chip, k=0))
        out.append(Cone("ms%d" % i, bone, at + v3(0.0, 0.05, -0.07) * k, at + v3(-0.01, 0.1, -0.03) * k, 0.006, 0.006,
                        k=0.004))
    return out


def parts():
    return {
        "body": (Shape(body_prims()), 0.003, 2300),
        "antips": (Shape(antip_prims()), 0.0025, 40),
        "leaf": (Shape(leaf_prims()), 0.003, 380),
        "minis": (Shape(mini_prims()), 0.002, 360),
    }


AXIS = np.array((0.0, 0.5, -0.866))
GRIP = v3(0, 0.21, -0.39)


def prop_parts():
    out = boki_tools.tools(GRIP, AXIS)
    out["berry"] = (Shape([Ellipsoid("b", "prop_berry", BERRY_C, v3(0.05, 0.048, 0.05), k=0)]), 0.003, 24)
    return out


GROWN = {
    "horn": ((0.06, 0.46, -0.25), (0.11, 0.58, -0.31), 0.03), "fang": ((0.03, 0.27, -0.35), (0.032, 0.235, -0.36), 0.011),
    "antenna": ((0.03, 0.47, -0.24), (0.06, 0.62, -0.3), 0.01), "brow": ((0.015, 0.43, -0.32), (0.11, 0.435, -0.29), 0.016),
    "head_top": (0, 0.48, -0.21), "fang_at": (0, 0.28, -0.35), "brow_at": (0, 0.42, -0.31), "third_eye": (0, 0.43, -0.32),
    "back": ((0, 0.29, -0.04), (0, 0.33, 0.14), (0, 0.33, 0.26)), "back_at": (0, 0.3, 0.06), "plates": (0, 0.36, 0.18),
    "plate_r": (0.1, 0.03, 0.08), "shell_c": (0, 0.255, 0.2), "shell_r": (0.14, 0.13, 0.05), "tail_bone": "tail1",
    "club_at": tuple(GASTER_PTS[1]), "club_dir": tuple(GASTER_PTS[1] - GASTER_PTS[0]), "club_r": 0.05,
    "spots": ((0.12, 0.27, 0.15, 0.018), (0.12, 0.25, 0.22, 0.016), (0.1, 0.23, 0.28, 0.016)), "spots_at": (0, 0.25, 0.2),
    "wing": ((0.06, 0.28, -0.03), (0.26, 0.36, 0.08), (0.22, 0.32, 0.16)), "wing_at": (0, 0.28, -0.02),
    "fin": ((0.12, 0.27, 0.18), (0.17, 0.37, 0.28)), "fin_at": (0, 0.27, 0.18), "crest": (0.47, -0.25, 0.05, 0.06),
    "crest_at": (0, 0.47, -0.21),
}


def grown_parts():
    return boki_grown.grown_parts(GROWN)


# ---------------------------------------------------------------- coat
CHITIN = hexc("8a3a2a")
CHITIN_LIGHT = hexc("c0603e")
CHITIN_DARK = hexc("4a1a14")
CREAM = hexc("d8a07a")
CREAM_LIGHT = hexc("f2cfa8")
BLUSH = hexc("ff8a80")
GREEN = hexc("4aa83a")
GREEN_LIGHT = hexc("9ad85a")
GREEN_DARK = hexc("2a6a2c")
VEIN = hexc("d8f49a")
GLOW = hexc("9aff6a")
LILAC = CREAM      # brows
LID = CHITIN_LIGHT
INK = hexc("2a1210")
MOUTH_DARK = hexc("5a1a1a")
TONGUE = hexc("f07a78")
IRIS = hexc("7ad84a")
IRIS_DEEP = hexc("1e4a12")
GROWN_A = hexc("e0866a")
GROWN_B = hexc("8a3a2a")
GROWN_C = hexc("4a1a14")


def chitin(p, n, base, light, dark):
    """Glossy plates: dark underneath, a broad warm sheen on top, a sharp white catch-light."""
    h = np.array([-0.35, 0.8, -0.48])
    h = h / np.linalg.norm(h)
    up = sat(n[:, 1] * 0.5 + 0.5)
    col = mixc(dark, base, sat(up * 1.5 + (value_noise(p * 40) - 0.5) * 0.2))
    col = mixc(col, light, sat((n @ h - 0.7) / 0.2) ** 2 * 0.8)
    return mixc(col, np.array([1.0, 0.92, 0.86]), sat((n @ h - 0.95) / 0.03) * 0.75)


def paint_body(p, n, prim):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    col = chitin(p, n, CHITIN, CHITIN_LIGHT, CHITIN_DARK)
    # a cream muzzle round the mouth and between the jaws, so the face reads on the dark head
    q = (p - np.array([0, 0.278, 0])) / np.array([0.115, 0.07, 1.0])
    muzzle = edge(1.0 - q[:, 0] ** 2 - q[:, 1] ** 2, 0.08) * edge(-0.27 - z, 0.02)
    col = mixc(col, mixc(CREAM, CREAM_LIGHT, sat(n[:, 1] + 0.3)), muzzle)
    for sx in (-1.0, 1.0):
        q = (p - np.array([sx * 0.122, 0.305, 0])) / np.array([0.04, 0.026, 1.0])
        col = mixc(col, BLUSH, np.exp(-(q[:, 0] ** 2 + q[:, 1] ** 2) * 1.3) * (z < -0.22) * 0.7)
    # the gaster: cream underneath, its plates ringed with dark seams
    gas = prim["gaster"].d(p) < 0.004
    along = (p - GASTER_PTS[0]) @ ((GASTER_PTS[1] - GASTER_PTS[0]) / np.linalg.norm(GASTER_PTS[1] - GASTER_PTS[0]))
    seam = np.zeros(len(p))
    for at in (0.12, 0.18, 0.225):
        seam = np.maximum(seam, edge(0.006 - np.abs(along - at), 0.003))
    col = mixc(col, CREAM, edge(0.2 - y - np.abs(x) * 0.4, 0.015) * gas)
    col = mixc(col, CHITIN_DARK * 0.8, seam * gas * 0.8)
    # mandibles and feet darker, the jaw tips nearly black
    for sd in "LR":
        jaw = edge(0.003 - np.minimum(prim["jaw" + sd].d(p), prim["jawtip" + sd].d(p)), 0.002)
        col = mixc(col, chitin(p, n, CHITIN_DARK, CHITIN, INK), jaw)
    return mixc(col, CHITIN_DARK, edge(0.06 - y, 0.02))


def paint_leaf(q, n, pc):
    """Green both sides, lighter where it faces the sky, a pale midrib and veins, a darker rim; a paler stem."""
    loc = (q - LEAF_C) @ LEAF_ROT.T
    across, along = loc[:, 0], loc[:, 2]
    w, _, ln = LEAF_HALF
    col = mixc(GREEN_DARK, GREEN, sat(n[:, 1] * 0.6 + 0.6))
    col = mixc(col, GREEN_LIGHT, sat(n[:, 1] - 0.4) * 0.7 + (value_noise(q * 50) - 0.5) * 0.2)
    rib = edge(0.007 - np.abs(across), 0.003)
    vein = edge(0.004 - np.abs(((along - np.abs(across) * 0.9) % 0.055) - 0.0275), 0.002) * edge(0.85 * w - np.abs(across), 0.02)
    col = mixc(col, VEIN, sat(rib + vein * 0.7))
    rim = edge((across / w) ** 2 + (np.minimum(along, 0) / ln) ** 2 - 0.82, 0.06)
    col = mixc(col, GREEN_DARK, rim * 0.6)
    ds = np.stack([pr.d(q) for pr in pc.shape.prims], -1)
    stem = ds[:, :len(STEM) - 1].min(1) < ds[:, len(STEM) - 1:].min(1)
    return np.where(stem[:, None], mixc(GREEN, GREEN_LIGHT, sat(n[:, 1])), col)


def paint_minis(q, n, pc):
    ds = np.stack([pr.d(q) for pr in pc.shape.prims], -1)
    own = np.array([pr.name for pr in pc.shape.prims])[ds.argmin(1)]
    col = chitin(q, n, CHITIN, CHITIN_LIGHT, CHITIN_DARK)
    chip = np.char.startswith(own, "mc") | np.char.startswith(own, "ms")
    col[chip] = mixc(GREEN, GREEN_LIGHT, sat(n[chip, 1] * 0.7 + 0.4))
    for i, at in enumerate(MINIS):
        for sx in (-1.0, 1.0):
            eye = np.hypot(q[:, 0] - at[0] - sx * 0.016, q[:, 1] - 0.072) < 0.009
            col[eye & (own == "mh%d" % i) & (q[:, 2] < at[2] - 0.075)] = INK
    return col


def paint_piece(pc, q, nn, prim):
    if pc.name == "body":
        return paint_body(q, nn, prim)
    if pc.name == "leaf":
        return paint_leaf(q, nn, pc)
    if pc.name == "minis":
        return paint_minis(q, nn, pc)
    if pc.name == "antips":
        return np.tile(GLOW, (len(q), 1))
    if pc.name.startswith("gp_"):
        if pc.look == "white":
            return np.ones((len(q), 3))
        if pc.look == "glow":
            return np.tile(GLOW, (len(q), 1))
        return paint_shell(q, nn, np.full(len(q), 1.0), GROWN_A, GROWN_B, GROWN_C)
    return tool_colour(pc.name, q)
