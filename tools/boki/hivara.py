"""Hivara (hivara), a honeybee with a praying mantis's folded blades and a crown of wax, a little swarm in tow: shapes
and coat. Game axes as vespyx.py."""
import math

import numpy as np

import boki_grown
import boki_tools
from boki_sdf import Cone, Ellipsoid, Shape, frame, v3, value_noise
from vespyx_paint import edge, hexc, mixc, paint_shell, sat, tool_colour
from vespyx_sides import SIDES

SCALE = 0.95
HEAD_C = v3(0, 0.43, -0.17)
HEAD_R = v3(0.195, 0.172, 0.172)
EYE_C = v3(0.096, 0.45, -0.31)
EYE_R = v3(0.05, 0.058, 0.033)
EYE_YAW = 0.46
GLOW_PIECES = ("honey",)
FACE = {"mouth_w": 0.05, "mouth_y": 0.355, "mouth_z": -0.36, "cat_mouth": False, "brow_x": 0.094, "brow_up": 0.034,
        "brow_k": 0.8, "fang_k": 0.0}
ABDOMEN_C = v3(0, 0.275, 0.17)
ABDOMEN_R = v3(0.15, 0.14, 0.165)
TAIL_PTS = [v3(0, 0.27, 0.22), v3(0, 0.25, 0.33), v3(0, 0.22, 0.42)]
# antennae: root, elbow, tip (the right one)
ANT_PTS = [v3(0.05, 0.598, -0.2), v3(0.105, 0.72, -0.24), v3(0.17, 0.755, -0.32)]
CROWN_C = v3(0, 0.585, -0.13)
CROWN_R = 0.105
# mantis blades, folded in front of the chest: shoulder, elbow, blade tip (the right one)
BLADE = (v3(0.085, 0.22, -0.13), v3(0.105, 0.29, -0.27), v3(0.095, 0.15, -0.24))
# wings on the back: root, tip and half width, fore and hind (the right one)
WINGS = ((v3(0.07, 0.385, 0.0), v3(0.21, 0.52, 0.14), 0.062), (v3(0.07, 0.37, 0.04), v3(0.18, 0.43, 0.19), 0.045))
# the swarm: orbit centre, and each bee's angle (turns), radius and height off it
SWARM_C = v3(0, 0.52, 0.06)
BEES = ((0.0, 0.34, 0.06), (0.36, 0.30, -0.06), (0.68, 0.36, 0.12))
BERRY_C = v3(0.0, 0.2, -0.36)


def eye_frame(sx):
    out = v3(sx * math.sin(EYE_YAW), 0.08, -math.cos(EYE_YAW))
    fr = frame(out, v3(0, 1, 0))
    if (fr[0] @ v3(sx, 0, 0)) < 0:
        fr[0] = -fr[0]
    return fr


def mirror(p, sx):
    return v3(p[0] * sx, p[1], p[2])


def bee_at(i):
    """Where bee i sits at rest, and the way it faces (along its orbit)."""
    turn, r, dy = BEES[i]
    a = math.tau * turn
    at = SWARM_C + v3(math.sin(a) * r, dy, math.cos(a) * r)
    return at, v3(math.cos(a), 0, -math.sin(a))


def body_prims():
    p = [
        Ellipsoid("abdomen", "hips", ABDOMEN_C, ABDOMEN_R, k=0.03),
        Ellipsoid("rump", "tail1", (TAIL_PTS[0] + TAIL_PTS[1]) * 0.5 + v3(0, 0.005, 0.02), v3(0.118, 0.112, 0.10), k=0.05),
        Ellipsoid("thorax", "spine", v3(0, 0.27, -0.03), v3(0.128, 0.128, 0.115), k=0.04),
        Cone("neck", "neck", v3(0, 0.29, -0.08), v3(0, 0.36, -0.13), 0.09, 0.1, k=0.05),
        Ellipsoid("head", "head", HEAD_C, HEAD_R, k=0.04),
        Ellipsoid("muzzle", "head", v3(0, 0.37, -0.29), v3(0.085, 0.06, 0.065), k=0.04),
    ]
    # the fuzz: a ruff round the neck, tufts on the head
    for i in range(10):
        a = math.tau * (i + 0.5) / 10
        c = v3(math.sin(a) * 0.12, 0.30 + math.cos(a) * 0.1, -0.07)
        tip = c + v3(math.sin(a) * 0.05, math.cos(a) * 0.045, 0.03)
        if c[1] > 0.2:
            p.append(Cone("ruff%d" % i, "spine", c, tip, 0.04, 0.003, k=0.016))
    for nm, a, b, r in (("top0", (0.0, 0.59, -0.23), (0.01, 0.635, -0.285), 0.03),
                        ("top1", (-0.035, 0.585, -0.24), (-0.05, 0.62, -0.29), 0.022)):
        p.append(Cone(nm, "head", v3(*a), v3(*b), r, 0.003, k=0.016))
    for sd, sx in SIDES:
        p.append(Ellipsoid("cheek" + sd, "head", v3(sx * 0.085, 0.37, -0.23), v3(0.105, 0.08, 0.095), k=0.04))
        a = [mirror(q, sx) for q in ANT_PTS]
        p.append(Cone("ant1" + sd, "ear1." + sd, a[0], a[1], 0.016, 0.012, k=0.012))
        p.append(Cone("ant2" + sd, "ear2." + sd, a[1], a[2], 0.012, 0.01, k=0.008))
        p.append(Ellipsoid("antb" + sd, "ear2." + sd, a[2], v3(0.028, 0.028, 0.028), k=0.008))
        for leg, z, par in (("f", -0.04, "f"), ("h", 0.12, "h")):
            hip = v3(sx * 0.09, 0.18, z)
            knee = v3(sx * 0.155, 0.115, z - 0.01)
            ankle = v3(sx * 0.165, 0.035, z - 0.015)
            p.append(Cone(leg + "leg1" + sd, "%sleg1.%s" % (par, sd), hip, knee, 0.038, 0.03, k=0.02))
            p.append(Cone(leg + "leg2" + sd, "%sleg2.%s" % (par, sd), knee, ankle, 0.03, 0.026, k=0.01))
            p.append(Ellipsoid(leg + "paw" + sd, "%spaw.%s" % (par, sd), ankle + v3(sx * 0.004, -0.01, -0.018),
                               v3(0.036, 0.025, 0.044), k=0.012))
    p.append(Cone("sting", "tail2", TAIL_PTS[1] + v3(0, 0.0, 0.04), TAIL_PTS[2] + v3(0, -0.01, 0.0), 0.03, 0.003, k=0.01))
    return p


def blade_prims(sd, sx):
    """A mantis forearm: a stout upper arm, then the blade folded back along it, toothed on the inside edge."""
    sh, el, tip = [mirror(q, sx) for q in BLADE]
    out = [Cone("upper" + sd, "arm." + sd, sh, el, 0.036, 0.03, k=0.012),
           Cone("blade" + sd, "claw." + sd, el, tip, 0.032, 0.008, k=0.012, flat=0.45, flat_axis=v3(1, 0, 0))]
    d = tip - el
    for i, k in enumerate((0.3, 0.52, 0.74)):
        at = el + d * k + v3(-sx * 0.01, 0, -0.012)
        out.append(Cone("tooth%s%d" % (sd, i), "claw." + sd, at, at + v3(-sx * 0.004, 0.006, -0.03), 0.009, 0.002, k=0.004))
    out.append(Cone("hook" + sd, "claw." + sd, tip, tip + v3(0, 0.03, -0.03), 0.01, 0.002, k=0.006))
    return out


def crown_prims():
    """A ring of wax with six comb points standing up round the top of the head."""
    out = []
    for i in range(12):
        a = math.tau * i / 12
        b = math.tau * (i + 1) / 12
        pa = CROWN_C + v3(math.sin(a) * CROWN_R, 0, math.cos(a) * CROWN_R * 0.95)
        pb = CROWN_C + v3(math.sin(b) * CROWN_R, 0, math.cos(b) * CROWN_R * 0.95)
        out.append(Cone("ring%d" % i, "head", pa, pb, 0.024, 0.024, k=0.01))
    for i in range(6):
        a = math.tau * (i + 0.5) / 6
        base = CROWN_C + v3(math.sin(a) * CROWN_R, 0.0, math.cos(a) * CROWN_R * 0.95)
        h = 0.075 if math.cos(a) < 0 else 0.055
        out.append(Cone("point%d" % i, "head", base, base + v3(math.sin(a) * 0.012, h, math.cos(a) * 0.012), 0.03,
                        0.012, k=0.01))
    return out


def honey_prims():
    """Glowing honey: a drop on each point, a few drips down the ring."""
    out = []
    for i in range(6):
        a = math.tau * (i + 0.5) / 6
        h = 0.075 if math.cos(a) < 0 else 0.055
        top = CROWN_C + v3(math.sin(a) * (CROWN_R + 0.012), h + 0.012, math.cos(a) * (CROWN_R + 0.012) * 0.95)
        out.append(Ellipsoid("drop%d" % i, "head", top, v3(0.016, 0.016, 0.016), k=0))
    for i, (a, length) in enumerate(((-0.08, 0.05), (0.42, 0.035), (0.58, 0.045), (0.9, 0.03))):
        a = math.tau * a
        at = CROWN_C + v3(math.sin(a) * (CROWN_R + 0.02), 0.0, math.cos(a) * (CROWN_R + 0.02) * 0.95)
        out.append(Cone("drip%d" % i, "head", at, at + v3(0, -length, 0), 0.012, 0.015, k=0.006))
    return out


def wing_prims():
    out = []
    for sd, sx in SIDES:
        for i, (root, tip, w) in enumerate(WINGS):
            a, b = mirror(root, sx), mirror(tip, sx)
            d = b - a
            n = np.cross(d, v3(0, 0, 1) if i == 0 else v3(0, 0.3, 1))
            out.append(Ellipsoid("w%s%d" % (sd, i), "wing%d.%s" % (i + 1, sd), a + d * 0.55,
                                 v3(w, np.linalg.norm(d) * 0.58, 0.012), rot=frame(n, d), k=0))
    return out


def swarm_prims():
    out = []
    for i in range(len(BEES)):
        at, fwd = bee_at(i)
        rot = frame(fwd, v3(0, 1, 0))
        bone = "bee%d" % (i + 1)
        out.append(Ellipsoid("bb%d" % i, bone, at, v3(0.026, 0.026, 0.034), rot=rot, k=0))
        out.append(Ellipsoid("bh%d" % i, bone, at + fwd * 0.034 + v3(0, 0.004, 0), v3(0.02, 0.02, 0.02), k=0.01))
        for sx in (-1.0, 1.0):
            side = np.cross(v3(0, 1, 0), fwd) * sx
            out.append(Ellipsoid("bw%d%d" % (i, sx > 0), bone, at + side * 0.026 + v3(0, 0.026, 0),
                                 v3(0.022, 0.004, 0.014), rot=frame(v3(0, 1, 0), fwd), k=0))
    return out


def parts():
    out = {
        "body": (Shape(body_prims()), 0.0035, 2300),
        "crown": (Shape(crown_prims()), 0.0035, 185),
        "honey": (Shape(honey_prims()), 0.0035, 110),
        "wings": (Shape(wing_prims()), 0.005, 150),
        "swarm": (Shape(swarm_prims()), 0.0025, 140),
    }
    for sd, sx in SIDES:
        out["blade" + sd] = (Shape(blade_prims(sd, sx)), 0.0035, 145)
    return out


# the pick is held in the right blade's hook
GRIP = mirror(BLADE[2], 1.0) + v3(-0.02, 0.01, -0.02)
AXIS = np.array((0.0, -0.94, -0.34))


def prop_parts():
    out = {k: v for k, v in boki_tools.tools(GRIP, AXIS, -boki_tools.SIDE).items() if k.startswith("pick")}
    out["berry"] = (Shape([Ellipsoid("b", "prop_berry", BERRY_C, v3(0.05, 0.048, 0.05), k=0)]), 0.003, 24)
    return out


GROWN = {
    "horn": ((0.06, 0.56, -0.24), (0.11, 0.68, -0.31), 0.032), "fang": ((0.03, 0.335, -0.35), (0.032, 0.30, -0.355), 0.013),
    "antenna": ((0.03, 0.58, -0.22), (0.05, 0.75, -0.2), 0.011), "brow": ((0.015, 0.53, -0.32), (0.13, 0.545, -0.28), 0.018),
    "head_top": (0, 0.6, -0.17), "fang_at": (0, 0.34, -0.34), "brow_at": (0, 0.53, -0.31), "third_eye": (0, 0.54, -0.32),
    "back": ((0, 0.4, -0.02), (0, 0.415, 0.1), (0, 0.4, 0.2)), "back_at": (0, 0.4, 0.08), "plates": (0, 0.4, 0.12),
    "plate_r": (0.12, 0.036, 0.1), "shell_c": (0, 0.275, 0.17), "shell_r": (0.165, 0.155, 0.06), "tail_bone": "tail1",
    "club_at": tuple(TAIL_PTS[1]), "club_dir": tuple(TAIL_PTS[2] - TAIL_PTS[0]), "club_r": 0.06,
    "spots": ((0.145, 0.3, 0.12, 0.022), (0.15, 0.26, 0.2, 0.02), (0.135, 0.3, 0.27, 0.02)), "spots_at": (0, 0.28, 0.17),
    "wing": ((0.1, 0.37, 0.04), (0.28, 0.47, 0.14), (0.24, 0.43, 0.22)), "wing_at": (0, 0.37, 0.04),
    "fin": ((0.14, 0.27, 0.18), (0.18, 0.4, 0.3)), "fin_at": (0, 0.27, 0.18), "crest": (0.6, -0.2, 0.04, 0.06),
    "crest_at": (0, 0.6, -0.2),
}


def grown_parts():
    return boki_grown.grown_parts(GROWN)


# ---------------------------------------------------------------- coat
GOLD = hexc("d9a42a")
GOLD_LIGHT = hexc("f2c650")
GOLD_DARK = hexc("a8761a")
FUZZ = hexc("ffe08a")
BROWN = hexc("3b2a1c")
BROWN_LIGHT = hexc("5e4430")
GLOW = hexc("ffe680")
WING = hexc("f4efd2")
WAX = hexc("f6e3a0")
WAX_DARK = hexc("d4b25a")
LILAC = hexc("5a3a1c")     # brows: dark on the gold, so they read
LID = hexc("c48e1e")      # a shade under the coat: the lit lids then meet the head
INK = hexc("2a1a0e")
BLUSH = hexc("ff8a6a")
MOUTH_DARK = hexc("4a1a10")
TONGUE = hexc("f07a6a")
IRIS = hexc("5a3a1c")
BLADE_LIGHT = hexc("e8a850")
BLADE_MID = hexc("9a5e1e")
BLADE_DARK = hexc("4a2a10")


def paint_body(p, n, prim):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    ax = np.abs(x)
    jag = (value_noise(p * np.array([80, 30, 80])) - 0.5) * 0.02
    fine = value_noise(p * np.array([140, 60, 140]))
    col = mixc(GOLD_DARK, GOLD, sat(n[:, 1] * 0.6 + 0.8))
    col = mixc(col, GOLD_LIGHT, sat(n[:, 1] - 0.2) * 0.6 + (fine - 0.5) * 0.15)
    # the abdomen's stripes: dark bands round it, running to a dark tip
    ab = np.minimum(prim["abdomen"].d(p), prim["rump"].d(p)) < 0.012
    band = np.sin((z - 0.075) * math.tau / 0.105) > 0.25 + jag * 20
    tip = edge(z - 0.34 + jag, 0.006)
    col = mixc(col, mixc(BROWN, BROWN_LIGHT, sat(n[:, 1] * 0.5 + 0.3)), sat(ab * band * edge(z - 0.06, 0.004) + tip))
    # dark under the body and the legs
    under = edge(0.17 - y + jag, 0.006) * (z > -0.15)
    legs = edge(0.13 - y + jag, 0.004)
    col = mixc(col, BROWN, sat(under + legs))
    # the fuzz: a paler ruff and a cream muzzle
    ruff = edge(0.012 - np.min(np.stack([prim["ruff%d" % i].d(p) for i in range(10) if "ruff%d" % i in prim], -1), 1),
                0.006)
    col = mixc(col, FUZZ, ruff * 0.85)
    head = (y > 0.3) & (z < -0.14)
    yb = np.interp(ax, [0, 0.04, 0.09, 0.16, 0.24], [0.4, 0.395, 0.37, 0.345, 0.31])
    col = mixc(col, FUZZ, edge(yb + jag - y, 0.004) * head)
    for sd in "LR":
        col = mixc(col, BROWN, edge(0.006 - np.minimum(prim["ant1" + sd].d(p), prim["ant2" + sd].d(p)), 0.003))
        col = mixc(col, BROWN_LIGHT, edge(0.004 - prim["antb" + sd].d(p), 0.002))
    for sx in (-1.0, 1.0):
        q = (p - np.array([sx * 0.13, 0.375, 0])) / np.array([0.045, 0.028, 1.0])
        col = mixc(col, BLUSH, np.exp(-(q[:, 0] ** 2 + q[:, 1] ** 2) * 1.25) * (z < -0.15) * 0.65)
    return col


def paint_wings(p, n):
    """Pale, with a sheen toward the edge and fine darker veins."""
    vein = sat((np.abs(np.sin(p[:, 0] * 160 + p[:, 2] * 60)) - 0.93) / 0.07)
    sheen = sat(n[:, 1] * 0.5 + 0.5)
    col = mixc(WING * 0.92, WING, sheen)
    col = mixc(col, hexc("dfe8ff"), sat(np.abs(p[:, 0]) * 5 - 0.6) * 0.5)
    return mixc(col, WAX_DARK, vein * 0.5)


def paint_swarm(p, pc):
    """Little gold bees with brown bands and pale wings."""
    col = np.tile(GOLD_LIGHT, (len(p), 1))
    names = [pr.name for pr in pc.shape.prims]
    ds = np.stack([pr.d(p) for pr in pc.shape.prims], -1)
    own = np.array(names)[ds.argmin(1)]
    for i in range(len(BEES)):
        at, fwd = bee_at(i)
        m = own == "bb%d" % i
        band = np.sin(((p[m] - at) @ fwd) * math.tau / 0.024) > 0.2
        col[m] = np.where(band[:, None], BROWN, GOLD_LIGHT)
    col[np.char.startswith(own.astype(str), "bh")] = BROWN
    col[np.char.startswith(own.astype(str), "bw")] = WING
    return col


def paint_piece(pc, q, nn, prim):
    if pc.name == "body":
        return paint_body(q, nn, prim)
    if pc.name == "wings":
        return paint_wings(q, nn)
    if pc.name == "swarm":
        return paint_swarm(q, pc)
    if pc.name == "crown":
        return mixc(np.tile(WAX_DARK, (len(q), 1)), WAX, sat(nn[:, 1] * 0.7 + 0.6))
    if pc.name == "honey":
        return np.tile(GLOW, (len(q), 1))
    if pc.name.startswith("blade"):
        return paint_shell(q, nn, np.full(len(q), 1.0), BLADE_LIGHT, BLADE_MID, BLADE_DARK)
    if pc.name.startswith("gp_"):
        if pc.look == "white":
            return np.ones((len(q), 3))
        if pc.look == "glow":
            return np.tile(GLOW, (len(q), 1))
        return paint_shell(q, nn, np.full(len(q), 1.0), BLADE_LIGHT, GOLD, BLADE_DARK)
    return tool_colour(pc.name, q)
