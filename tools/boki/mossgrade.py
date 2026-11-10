"""Mossgrade, a plump water bear wearing a cushion of moss: shapes and coat. Game axes as vespyx.py.
NEW design (roster 50, #13), owner approval pending."""
import math
import random

import numpy as np

import boki_grown
import boki_tools
from boki_sdf import Cone, Ellipsoid, Shape, frame, v3, value_noise
from vespyx_paint import edge, hexc, mixc, paint_shell, sat, tool_colour
from vespyx_sides import SIDES

SCALE = 0.95
HEAD_C = v3(0, 0.26, -0.2)
HEAD_R = v3(0.205, 0.19, 0.17)
EYE_C = v3(0.095, 0.3, -0.32)
EYE_R = v3(0.05, 0.055, 0.032)
EYE_YAW = 0.42
GLOW_PIECES = ()
LIT_PIECES = ("moss",)
BERRY_C = v3(0, 0.045, -0.44)
MUZZLE_C = v3(0, 0.212, -0.34)
FACE = {"mouth_w": 0.04, "mouth_y": 0.2, "mouth_z": -0.38, "cat_mouth": False, "brow_x": 0.095, "brow_up": 0.02,
        "brow_k": 0.75, "fang_k": 0.0}
# the barrel behind the head: (centre, radii, bone); the creases between them are its rings
RINGS = [(v3(0, 0.255, -0.06), v3(0.205, 0.19, 0.105), "neck"), (v3(0, 0.26, 0.045), v3(0.215, 0.2, 0.11), "spine"),
         (v3(0, 0.25, 0.15), v3(0.2, 0.185, 0.105), "hips"), (v3(0, 0.235, 0.235), v3(0.16, 0.15, 0.08), "hips")]
# four pairs of stubby legs, front to back: (bone stem, z, splay back)
LEGS = [("fleg1", "fpaw", -0.075, -0.1), ("m1leg", "m1paw", 0.03, 0.0), ("m2leg", "m2paw", 0.135, 0.15),
        ("hleg1", "hpaw", 0.225, 0.5)]
CUSHION = Ellipsoid("cushion", "spine", v3(0, 0.415, 0.06), v3(0.2, 0.085, 0.215), k=0.025)   # the moss's dome
# flowers in the moss: (x, z, bone), each on its own bone that the clips scale (a bud, a bloom)
FLOWERS = [(-0.075, -0.06, "spine"), (0.085, -0.02, "spine"), (-0.015, 0.07, "spine"), (0.1, 0.13, "hips"),
           (-0.1, 0.15, "hips"), (0.03, 0.2, "hips")]
FLOWER_R = 0.06                   # m, the open bloom's petal ring
PETALS = 5


def eye_frame(sx):
    out = v3(sx * math.sin(EYE_YAW), 0.12, -math.cos(EYE_YAW))
    fr = frame(out, v3(0, 1, 0))
    if (fr[0] @ v3(sx, 0, 0)) < 0:
        fr[0] = -fr[0]
    return fr


def barrel_prims():
    p = [Ellipsoid("head", "head", HEAD_C, HEAD_R, k=0.035)]
    for i, (c, r, bone) in enumerate(RINGS):
        p.append(Ellipsoid("ring%d" % i, bone, c, r, k=0.035))
    p.append(Ellipsoid("muzzle", "head", MUZZLE_C, v3(0.082, 0.062, 0.05), k=0.035))
    return p


def on_top(shape, x, z, lift=0.0):
    """The point of the shape's top over (x, z), `lift` metres out of it."""
    return shape.project(np.array([[x, 0.7, z]]), offset=lift, steps=14)[0]


def body_prims():
    p = barrel_prims()
    for sd, sx in SIDES:
        # little round nubs where a bear's ears would be (a water bear's head cirri)
        nub = v3(sx * 0.13, 0.405, -0.2)
        p.append(Ellipsoid("ear" + sd, "ear1." + sd, nub, v3(0.042, 0.04, 0.034), k=0.03))
        for leg, paw, z, back in LEGS:
            top = v3(sx * 0.12, 0.14, z)
            ankle = v3(sx * 0.172, 0.038, z + back * 0.06)
            p.append(Cone(leg + sd, "%s.%s" % (leg, sd), top, ankle, 0.05, 0.044, k=0.02))
            p.append(Ellipsoid(paw + sd, "%s.%s" % (paw, sd), ankle + v3(sx * 0.006, -0.012, -0.01),
                               v3(0.05, 0.03, 0.052), k=0.016))
    return p


def claw_prims():
    """Two little hooked claws on the front of every foot."""
    out = []
    for sd, sx in SIDES:
        for leg, paw, z, back in LEGS:
            ankle = v3(sx * 0.178, 0.024, z + back * 0.06 - 0.052)
            for j in (-1, 1):
                a = ankle + v3(j * 0.016, 0.0, 0.0)
                out.append(Cone("cl%s%s%d" % (paw, sd, j), "%s.%s" % (paw, sd), a, a + v3(j * 0.004, -0.016, -0.02),
                                0.0085, 0.003, k=0))
    return out


def moss_prims():
    """A domed pillow over the back, lumpy with clumps."""
    def bone(z):
        return "neck" if z < -0.06 else "spine" if z < 0.1 else "hips"

    dome = Shape([CUSHION])
    out = [CUSHION]
    rng = random.Random(1313)
    for i in range(80):
        u, w = rng.uniform(-1, 1), rng.uniform(-1, 1)
        if u * u + w * w > 0.92:
            continue
        x, z = u * CUSHION.r[0], CUSHION.c[2] + w * CUSHION.r[2]
        at = on_top(dome, x, z, -0.012)
        r = rng.uniform(0.03, 0.046)
        out.append(Ellipsoid("m%d" % i, bone(z), at, v3(r, r * 0.85, r), k=0.02))
    return out


def flower_base(i):
    x, z, _ = FLOWERS[i]
    return on_top(Shape([CUSHION]), x, z, 0.012)


def flower_prims():
    """Five round petals, a fat centre, on a short stalk: the bone's head is the stalk's foot, so it scales from there."""
    out = []
    for i, (x, z, _) in enumerate(FLOWERS):
        bone = "bloom%d" % i
        base = flower_base(i)
        top = base + v3(0, 0.045, 0)
        out.append(Cone("st%d" % i, bone, base - v3(0, 0.03, 0), top, 0.009, 0.008, k=0))
        out.append(Ellipsoid("c%d" % i, bone, top + v3(0, 0.007, 0), v3(0.017, 0.013, 0.017), k=0))
        spin = i * 0.7
        for j in range(PETALS):
            a = spin + math.tau * j / PETALS
            out_dir = v3(math.cos(a), 0, math.sin(a))
            cup = v3(0, 1, 0) - out_dir * 0.35       # the petal's face, tipped in: a shallow cup
            out.append(Ellipsoid("p%d_%d" % (i, j), bone, top + out_dir * FLOWER_R * 0.55 + v3(0, 0.006, 0),
                                 v3(0.019, 0.026, 0.0065), rot=frame(cup, out_dir), k=0.004))
    return out


def parts():
    return {
        "body": (Shape(body_prims()), 0.0035, 5000),
        "claws": (Shape(claw_prims()), 0.0022, 420),
        "moss": (Shape(moss_prims()), 0.0035, 1400),
        "flowers": (Shape(flower_prims()), 0.0022, 1100),
    }


AXIS = np.array((0.0, 0.5, -0.866))
GRIP = v3(0, 0.19, -0.39)


def prop_parts():
    out = boki_tools.tools(GRIP, AXIS)
    out["berry"] = (Shape([Ellipsoid("b", "prop_berry", BERRY_C, v3(0.054, 0.052, 0.054), k=0)]), 0.003, 90)
    return out


GROWN = {
    "horn": ((0.06, 0.41, -0.24), (0.12, 0.54, -0.3), 0.032), "fang": ((0.022, 0.185, -0.37), (0.026, 0.15, -0.375), 0.011),
    "antenna": ((0.05, 0.415, -0.25), (0.11, 0.57, -0.33), 0.011), "brow": ((0.015, 0.365, -0.33), (0.115, 0.37, -0.29), 0.016),
    "head_top": (0, 0.42, -0.22), "fang_at": (0, 0.19, -0.36), "brow_at": (0, 0.36, -0.32), "third_eye": (0, 0.37, -0.33),
    "back": ((0, 0.49, -0.09), (0, 0.51, 0.07), (0, 0.48, 0.22)), "back_at": (0, 0.48, 0.07), "plates": (0, 0.5, -0.04),
    "plate_r": (0.15, 0.045, 0.08), "shell_c": (0, 0.255, 0.08), "shell_r": (0.225, 0.215, 0.07), "tail_bone": "hips",
    "club_at": (0, 0.23, 0.33), "club_dir": (0, 0.0, 1.0), "club_r": 0.05,
    "spots": ((0.2, 0.24, -0.04, 0.022), (0.21, 0.23, 0.07, 0.02), (0.19, 0.22, 0.18, 0.02)), "spots_at": (0, 0.23, 0.07),
    "wing": ((0.17, 0.4, 0.0), (0.37, 0.5, 0.08), (0.33, 0.45, 0.18)), "wing_at": (0, 0.4, 0.02),
    "fin": ((0.19, 0.2, 0.18), (0.29, 0.28, 0.3)), "fin_at": (0, 0.22, 0.18), "crest": (0.41, -0.23, 0.05, 0.06),
    "crest_at": (0, 0.42, -0.2),
}


def grown_parts():
    return boki_grown.grown_parts(GROWN)


# ---------------------------------------------------------------- coat
SKIN = hexc("7a9a5a")
SKIN_LIGHT = hexc("a3bf7f")
SKIN_DARK = hexc("55703e")
BELLY = hexc("d9e6b8")
MUZZLE = hexc("e6eecb")
SOLE = hexc("c9d6a0")
CLAW = hexc("f2ead2")
BLUSH = hexc("ff9a8c")
MOSS_DEEP = hexc("2f6a26")
MOSS = hexc("5fa83a")
MOSS_TIP = hexc("a8e05a")
SPECK = hexc("d8ff9a")
PETAL_PINK = hexc("ffb8d2")
PETAL_WHITE = hexc("fff6e8")
PETAL_ROOT = hexc("ff7fae")
CENTRE = hexc("ffd84a")
STEM = hexc("4f8a2e")
LILAC = hexc("4f6a36")     # brows
LID = SKIN_LIGHT
INK = hexc("26331c")
MOUTH_DARK = hexc("5a2a2a")
TONGUE = hexc("f08a8a")
IRIS = hexc("c08a3e")
IRIS_DEEP = hexc("3e2410")
CUSHION_A = hexc("b8d88a")
CUSHION_B = hexc("7aa84e")
CUSHION_C = hexc("456a2e")


def paint_body(p, n, prim):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    soft = value_noise(p * np.array([60, 60, 60]))
    col = mixc(SKIN_DARK, SKIN, sat(n[:, 1] * 0.5 + 0.62 + (soft - 0.5) * 0.3))
    col = mixc(col, SKIN_LIGHT, sat(n[:, 1] - 0.25) * 0.5)
    # the rings: a darker crease where two segments meet, fine wrinkles across each
    segs = np.sort(np.stack([prim["head"].d(p)] + [prim["ring%d" % i].d(p) for i in range(len(RINGS))], -1), -1)
    crease = edge(0.008 - (segs[:, 1] - segs[:, 0]), 0.005) * (z > -0.2) * sat(n[:, 1] + 0.6)
    wrinkle = (0.5 + 0.5 * np.sin(z * math.tau / 0.034 + (soft - 0.5) * 3)) * edge(z + 0.12, 0.03)
    col = mixc(col, SKIN_DARK * 0.85, sat(crease * 0.5 + wrinkle * 0.1))
    # a pale belly underneath (not down the legs) and a pale soft muzzle
    leg = np.min(np.stack([prim[leg + sd].d(p) for leg, _, _, _ in LEGS for sd in "LR"], -1), -1)
    belly = edge(-n[:, 1] - 0.25 + (soft - 0.5) * 0.08, 0.1) * edge(leg - 0.012, 0.01) * edge(0.15 - y, 0.02)
    col = mixc(col, BELLY, belly)
    muz = edge(0.006 - prim["muzzle"].d(p), 0.01) * (z < -0.3)
    col = mixc(col, MUZZLE, muz)
    for sd in "LR":
        for _, paw, _, _ in LEGS:
            col = mixc(col, SOLE, edge(0.003 - prim[paw + sd].d(p), 0.004) * (n[:, 1] < -0.2))
    for sx in (-1.0, 1.0):
        q = (p - np.array([sx * 0.125, 0.235, 0])) / np.array([0.045, 0.028, 1.0])
        col = mixc(col, BLUSH, np.exp(-(q[:, 0] ** 2 + q[:, 1] ** 2) * 1.25) * (z < -0.22) * 0.7)
    return col


def paint_moss(q, n):
    """Deep green in the hollows, bright at the clump tops, a few pale-lime sparks."""
    clump = value_noise(q * 90)
    up = sat(n[:, 1] * 0.8 + 0.2)
    col = mixc(MOSS_DEEP, MOSS, sat(up * 1.1 + (clump - 0.5) * 0.8))
    col = mixc(col, MOSS_TIP, sat((clump - 0.55) / 0.2) * up)
    return mixc(col, SPECK, sat((value_noise(q * 260) - 0.78) / 0.05) * up)


def paint_flowers(q, n):
    """Pink and white blooms, a yellow heart, green stalks."""
    tops = np.array([flower_base(i) + v3(0, 0.045, 0) for i in range(len(FLOWERS))])
    d = np.linalg.norm(q[:, None, :] - tops[None], axis=-1)
    own = d.argmin(1)
    r = d.min(1)
    petal = np.where((own % 2 == 0)[:, None], PETAL_PINK, PETAL_WHITE)
    col = mixc(petal, PETAL_ROOT, sat((0.034 - r) / 0.014) * 0.6)
    col = mixc(col, CENTRE, edge(0.019 - r, 0.002))
    stem = edge(q[:, 1] - (tops[own][:, 1] - 0.004), 0.002)
    return mixc(np.tile(STEM, (len(q), 1)), col, stem)


def paint_piece(pc, q, nn, prim):
    if pc.name == "body":
        return paint_body(q, nn, prim)
    if pc.name == "claws":
        return np.tile(CLAW, (len(q), 1))
    if pc.name == "moss":
        return paint_moss(q, nn)
    if pc.name == "flowers":
        return paint_flowers(q, nn)
    if pc.name.startswith("gp_"):
        if pc.look == "white":
            return np.ones((len(q), 3))
        if pc.look == "glow":
            return np.tile(MOSS_TIP, (len(q), 1))
        return paint_shell(q, nn, np.full(len(q), 1.0), CUSHION_A, CUSHION_B, CUSHION_C)
    return tool_colour(pc.name, q)
