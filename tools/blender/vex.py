"""Vex, the Hired Gun: the Blender build of her Warden model (RIG_CONTRACT.md).

Run: ~/tools/blender-4.5.15-linux-x64/blender -b --factory-startup --python tools/blender/vex.py -- [--render <dir>]
Needs art/wardens/src/vex_rig.json (godot --headless -- --warden-rig-json). Writes art/wardens/vex/vex.glb;
--render also writes a turnaround (front, 3/4, side, back) to <dir>/blender_turnaround.png.

Her design: docs/art/gen/wardens/venatrix_turnaround.png and _splash.png (the Warden block in
docs/art/gen/index.md). A woman, part machine, a devout soldier: tilted navy beret with a brass badge,
orange signal scarf streaming behind, slate plate carrier over khaki fatigues, one oversized slate shoulder
plate with the white open-eye-in-a-teardrop sigil, a brass bandolier, a short dark braid, a brass-rimmed
mechanical right eye glowing orange, and a mechanical LEFT arm (gunmetal and brass, pistons and cables,
prayer beads at the wrist; the sheet draws it on her right, her block and the splash on her left). Her
ember rifle is its own `weapon` mesh, modelled in the held weapon's space (the Gun node).
Built on her rig's proportions (big readable head, the game's hero build); every joint where the rig bends.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import warden_kit as K  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RIG = os.path.join(ROOT, "art/wardens/src/vex_rig.json")
OUT_DIR = os.path.join(ROOT, "art/wardens/vex")

# palette (sRGB): lifted a step from the sheet so she reads at dusk under the toon shader
SKIN = K.hexcol("c98e66")
HAIR = K.hexcol("3e2a1e")
BERET = K.hexcol("34407c")
BRASS = K.hexcol("d0a048")
SCARF = K.hexcol("f07030")
SHIRT = K.hexcol("b8a47a")
PANTS = K.hexcol("a49270")
VEST = K.hexcol("6a7c94")
PLATE = K.hexcol("7a8ea8")
BOOT = K.hexcol("54402f")
BELT = K.hexcol("74523a")
GUNMETAL = K.hexcol("4e5462")
GLOVE = K.hexcol("43444e")
WOOD = K.hexcol("6a3f28")
PAPER = K.hexcol("efe4c8")
WAX = K.hexcol("c03028")
WHITE = K.hexcol("f4f0e6")
IRIS = K.hexcol("5a3420")
DARK = K.hexcol("2a2026")
EMBER = K.hexcol("ffa040")


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    render_dir = args[args.index("--render") + 1] if "--render" in args else ""
    K.reset()
    rig = K.load_rig(RIG)
    arm = K.build_armature(rig)
    J = {n: K.bone_head(rig, n) for n in rig["bones"]}
    crown = rig["land"]["crown"]
    pieces = []
    pieces += legs(J)
    pieces += torso(J)
    pieces += arm_right(J)
    pieces += arm_left(J)
    pieces += head(J, crown)
    pieces += scarf(J)
    weapon = rifle(rig["weapon"])
    img = K.bake_atlas(pieces + weapon)
    body, mats = K.finish(pieces, arm, img)
    gun = _weapon_finish(weapon, mats)
    K.anchor(arm, "head", "anchor_head_top", (0, 0, crown + 0.07))
    K.anchor(arm, "hips", "anchor_chest", (0, 0.12, J["upper_arm.L"].z - 0.14))
    print("VEXBUILD triangles: body %d, weapon %d" % (K.tris([body]), K.tris([gun] + list(gun.children))))
    out = os.path.join(OUT_DIR, "vex.glb")
    K.export(out, [arm, body, gun, gun.children[0]] + [o for o in bpy.data.objects if o.name.startswith("anchor_")])
    print("VEXBUILD wrote", out)
    if render_dir:
        import warden_render
        warden_render.turnaround(arm, body, gun, J["hand.R"], os.path.join(render_dir, "blender_turnaround.png"))


def _weapon_finish(objs, mats):
    """The rifle pieces joined into the `weapon` mesh; its magazine stays a child, `weapon_mag`, so the reload
    drops and slaps it in (the loader makes it the Gun's Mag)."""
    for ob in objs:
        ob.data.materials.clear()
        ob.data.materials.append(mats[ob["slot"]])
    mag = next(ob for ob in objs if ob.name == "mag")
    objs = [ob for ob in objs if ob is not mag]
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    g = bpy.context.view_layer.objects.active
    g.name = "weapon"
    g.data.name = "weapon"
    bpy.ops.object.material_slot_remove_unused()
    mag.name = "weapon_mag"
    mag.parent = g
    return g


# --- legs and boots ----------------------------------------------------------------------------------

def legs(J):
    out = []
    knee = J["shin.L"].z
    for sd, sx in (("L", -1), ("R", 1)):
        top = J["thigh." + sd]
        x = top.x
        th, sh = "thigh." + sd, "shin." + sd

        def leg_w(p, th=th, sh=sh):
            w = K.blend(th, sh, K.smooth01(knee + 0.05, knee - 0.05, p.z))
            hip = K.smooth01(top.z - 0.02, top.z + 0.06, p.z) * 0.45
            return {k: v * (1 - hip) for k, v in w.items()} | {"hips": hip}

        # fatigues: full thigh, a slight bow at the knee, tapering into the boot
        rings = [((x, -0.01, top.z + 0.06), 0.085, 0.09), ((x, 0, top.z - 0.04), 0.088, 0.092),
                 ((x * 1.04, 0.0, top.z - 0.17), 0.074, 0.08), ((x * 1.04, 0.01, knee + 0.04), 0.06, 0.065),
                 ((x * 1.03, 0.012, knee - 0.03), 0.058, 0.062), ((x, 0.0, knee - 0.15), 0.052, 0.058),
                 ((x, -0.005, 0.2), 0.05, 0.054)]
        pants = K.loft("pants" + sd, rings, 12)
        K.subsurf(pants, 1)
        K.folds(pants, 0.006, 0.04)
        out.append(K.weigh(K.paint(pants, "cloth", PANTS, grad=0.22), leg_w))
        # cargo pocket on the outer thigh
        pk = K.box("pocket" + sd, (x + sx * 0.075, 0.0, top.z - 0.15), (0.03, 0.09, 0.1), bevel=0.01)
        out.append(K.weigh(K.paint(pk, "cloth", PANTS, grad=0.3, ao=0.6), leg_w))
        # slate knee pad over the knee
        kp = K.ellipsoid("kneepad" + sd, (x * 1.04, 0.055, knee), (0.055, 0.035, 0.06), 14, 8, cut=-0.1)
        out.append(K.weigh(K.paint(kp, "metal", VEST, grad=0.25, edge=0.4), lambda p, sh=sh: {sh: 1.0}))
        # combat boot: shaft, foot, toe cap, sole
        bt = K.loft("boot" + sd, [((x, -0.005, 0.23), 0.058, 0.062), ((x, 0.0, 0.12), 0.056, 0.064),
                                  ((x, 0.03, 0.07), 0.058, 0.09), ((x, 0.055, 0.035), 0.056, 0.105)], 14)
        K.subsurf(bt, 1)
        out.append(K.weigh(K.paint(bt, "leather", BOOT, grad=0.3, edge=0.3), lambda p, sh=sh: {sh: 1.0}))
        toe = K.ellipsoid("toe" + sd, (x, 0.1, 0.04), (0.052, 0.07, 0.04), 12, 8)
        out.append(K.weigh(K.paint(toe, "leather", BOOT, grad=0.3, edge=0.4), lambda p, sh=sh: {sh: 1.0}))
        sole = K.box("sole" + sd, (x, 0.05, 0.012), (0.12, 0.26, 0.024), bevel=0.008)
        out.append(K.weigh(K.paint(sole, "leather", DARK, grad=0.1), lambda p, sh=sh: {sh: 1.0}))
        cuff = K.torus("bootcuff" + sd, (x, -0.005, 0.225), 0.06, 0.012, segs=14, tube=5)
        out.append(K.weigh(K.paint(cuff, "leather", BOOT, grad=0.1, edge=0.3), lambda p, sh=sh: {sh: 1.0}))
    return out


# --- torso: fatigues, plate carrier, belt, bandolier ----------------------------------------------

def torso(J):
    out = []
    hz = J["hips"].z
    sz = J["upper_arm.L"].z
    nz = J["head"].z
    sw = abs(J["upper_arm.L"].x)

    def tw(p):
        # the trunk on the hips; its foot blends into the thighs
        leg = "thigh.L" if p.x < 0 else "thigh.R"
        t = K.smooth01(hz + 0.02, hz - 0.08, p.z) * 0.5 * min(1.0, abs(p.x) / 0.08)
        return {"hips": 1 - t, leg: t}

    # a woman's trunk: full hips, a narrow waist, a strong back and shoulders
    rings = [((0, -0.01, hz - 0.08), 0.12, 0.09), ((0, -0.015, hz - 0.01), 0.165, 0.11),
             ((0, -0.01, hz + 0.08), 0.155, 0.1), ((0, 0.0, hz + 0.17), 0.13, 0.092),
             ((0, 0.005, hz + 0.28), 0.145, 0.105), ((0, 0.01, hz + 0.38), 0.16, 0.112),
             ((0, 0.0, sz - 0.03), sw + 0.01, 0.11), ((0, -0.005, sz + 0.05), sw - 0.04, 0.095),
             ((0, 0.0, nz - 0.07), 0.09, 0.07), ((0, 0.0, nz - 0.03), 0.055, 0.05)]
    trunk = K.loft("trunk", rings, 16)
    K.subsurf(trunk, 1, smooth=2)
    K.folds(trunk, 0.004, 0.05)
    out.append(K.weigh(K.paint(trunk, "cloth", SHIRT, grad=0.2), tw))
    # the plate carrier: a slate shell over the chest and back, waist to the shoulders
    vrings = [((0, -0.002, hz + 0.12), 0.148, 0.106), ((0, 0.004, hz + 0.24), 0.16, 0.118),
              ((0, 0.012, hz + 0.36), 0.176, 0.128), ((0, 0.006, sz - 0.04), 0.17, 0.12),
              ((0, 0.0, sz + 0.02), 0.13, 0.1)]
    vest = K.loft("vest", vrings, 20, cap=False)
    sol = vest.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = 0.016
    K.apply_mods(vest)
    out.append(K.weigh(K.paint(vest, "metal", VEST, grad=0.25, ao=0.5, edge=0.5), tw))
    # front pouches on the carrier
    for i, px in enumerate((-0.09, -0.03, 0.03, 0.09)):
        pz = K.box("pouch%d" % i, (px, 0.135, hz + 0.16), (0.05, 0.035, 0.07), bevel=0.008)
        out.append(K.weigh(K.paint(pz, "cloth", K.hexcol("7a8a76"), grad=0.3, ao=0.6, edge=0.3), tw))
    # dog tags on a chain
    tag = K.box("dogtag", (0.025, 0.145, sz - 0.07), (0.022, 0.006, 0.032), bevel=0.003)
    out.append(K.weigh(K.paint(tag, "metal", K.hexcol("d8dce0"), grad=0.1, edge=0.6), tw))
    # the belt with a brass buckle and spiked brass charges round the front
    belt = K.torus("belt", (0, -0.008, hz + 0.02), 1.0, 0.022, segs=24, tube=6, scale=(0.168, 0.118, 1.0))
    out.append(K.weigh(K.paint(belt, "leather", BELT, grad=0.1, edge=0.3), tw))
    buckle = K.box("buckle", (0, 0.122, hz + 0.02), (0.05, 0.012, 0.04), bevel=0.004)
    out.append(K.weigh(K.paint(buckle, "metal", BRASS, grad=0.1, edge=0.6), tw))
    for i in range(7):
        a = math.radians(-60 + i * 20 + (10 if i >= 3 else 0))
        c = (math.sin(a) * 0.175, math.cos(a) * 0.125 - 0.008, hz + 0.02)
        sh = K.cyl("charge%d" % i, (c[0], c[1], c[2] - 0.03), (c[0], c[1], c[2] + 0.02), 0.011, 0.011, 8)
        tip = K.cyl("chargetip%d" % i, (c[0], c[1], c[2] + 0.02), (c[0], c[1], c[2] + 0.045), 0.011, 0.002, 8)
        for ob in (sh, tip):
            out.append(K.weigh(K.paint(ob, "metal", BRASS, grad=0.2, edge=0.6), tw))
    # the bandolier from her right shoulder to her left hip, brass charges along it
    path = [(sw - 0.06, 0.02, sz + 0.04), (0.08, 0.13, sz - 0.08), (-0.04, 0.14, hz + 0.25),
            (-0.13, 0.11, hz + 0.08)]
    band = K.loft("bandolier", [(p, 0.03, 0.007) for p in path], 6)
    out.append(K.weigh(K.paint(band, "leather", BELT, grad=0.1, edge=0.3), tw))
    for i in range(1, 6):
        t = i / 6
        a = Vector(path[0]).lerp(Vector(path[-1]), t)
        a.y = 0.15 - abs(t - 0.45) * 0.08
        sh = K.cyl("bandcharge%d" % i, a - Vector((0, 0, 0.018)), a + Vector((0, 0, 0.018)), 0.009, 0.009, 8)
        out.append(K.weigh(K.paint(sh, "metal", BRASS, grad=0.2, edge=0.6), tw))
    # a scripture strip hanging off the belt, a red wax seal on it (her left hip)
    strip = K.ribbon("beltstrip", [(-0.15, 0.08, hz + 0.0), (-0.155, 0.085, hz - 0.08), (-0.15, 0.09, hz - 0.17)],
                     [0.035, 0.035, 0.03], up=(1, 0.3, 0))
    out.append(K.weigh(K.paint(strip, "cloth", PAPER, grad=0.15, ao=0.3), tw))
    seal = K.cyl("seal", (-0.15, 0.08, hz - 0.01), (-0.15, 0.094, hz - 0.01), 0.013, 0.013, 10)
    out.append(K.weigh(K.paint(seal, "cloth", WAX, grad=0.1), tw))
    # neck
    neck = K.cyl("neck", (0, -0.005, sz + 0.02), (0, 0.0, nz + 0.08), 0.052, 0.046, 12)
    out.append(K.weigh(K.paint(neck, "skin", SKIN, grad=0.25), lambda p: K.blend("hips", "head",
                                                                                 K.smooth01(nz - 0.03, nz + 0.05, p.z))))
    return out


# --- arms --------------------------------------------------------------------------------------------

def _arm_w(sd, J):
    sh, el, wr = J["upper_arm." + sd], J["forearm." + sd], J["hand." + sd]

    def w(p):
        up = K.smooth01(el.z - 0.03, el.z + 0.03, p.z)
        hand = K.smooth01(wr.z + 0.015, wr.z - 0.015, p.z)
        chest = K.smooth01(sh.z - 0.06, sh.z + 0.05, p.z) * 0.35
        return {"hips": chest, "upper_arm." + sd: up * (1 - chest), "forearm." + sd: (1 - up) * (1 - hand),
                "hand." + sd: hand}
    return w


def _fingers(name, wr, sx, col, slot, w, mech=False):
    out = []
    palm = K.box(name + "palm", (wr.x, wr.y + 0.005, wr.z - 0.045), (0.032, 0.07, 0.07), bevel=0.012)
    out.append(K.weigh(K.paint(palm, slot, col, grad=0.2, edge=0.4 if mech else 0.2), w))
    for i in range(4):
        fy = wr.y + 0.03 - i * 0.02
        base = Vector((wr.x, fy, wr.z - 0.08))
        mid = base + Vector((sx * 0.004, 0.006, -0.03))
        tip = mid + Vector((sx * 0.004, 0.012, -0.022))
        r = 0.0085 if not mech else 0.009
        for k, (a, b) in enumerate(((base, mid), (mid, tip))):
            f = K.cyl("%sfinger%d_%d" % (name, i, k), a, b, r, r * 0.9, 6)
            out.append(K.weigh(K.paint(f, slot, col, grad=0.1, edge=0.4 if mech else 0.1), w))
            if mech:
                j = K.ellipsoid("%sknuckle%d_%d" % (name, i, k), a, (r * 1.2,) * 3, 5, 3)
                out.append(K.weigh(K.paint(j, "metal", GUNMETAL, edge=0.5), w))
    thumb = K.cyl(name + "thumb", (wr.x, wr.y + 0.04, wr.z - 0.04), (wr.x - sx * 0.002, wr.y + 0.065, wr.z - 0.075),
                  0.01, 0.009, 6)
    out.append(K.weigh(K.paint(thumb, slot, col, grad=0.1), w))
    return out


def arm_right(J):
    """Her human arm: a khaki sleeve rolled above the elbow, a bare forearm, a fingerless glove."""
    out = []
    sh, el, wr = J["upper_arm.R"], J["forearm.R"], J["hand.R"]
    w = _arm_w("R", J)
    sleeve = K.loft("sleeveR", [((sh.x - 0.01, 0, sh.z + 0.06), 0.05, 0.05), ((sh.x + 0.01, 0, sh.z), 0.07, 0.066),
                                ((sh.x, 0, el.z + 0.1), 0.056, 0.055), ((sh.x, 0, el.z + 0.06), 0.057, 0.056)], 12)
    K.subsurf(sleeve, 1)
    K.folds(sleeve, 0.003, 0.03)
    out.append(K.weigh(K.paint(sleeve, "cloth", SHIRT, grad=0.2), w))
    roll = K.torus("rollR", (sh.x, 0, el.z + 0.06), 0.05, 0.012, segs=12, tube=5)
    out.append(K.weigh(K.paint(roll, "cloth", SHIRT, grad=0.1, ao=0.5), w))
    fore = K.loft("forearmR", [((sh.x, 0, el.z + 0.07), 0.042, 0.042), ((el.x, 0.0, el.z), 0.042, 0.04),
                               ((el.x, 0.004, el.z - 0.1), 0.038, 0.034), ((wr.x, 0.006, wr.z + 0.01), 0.029, 0.026)], 12)
    K.subsurf(fore, 1)
    out.append(K.weigh(K.paint(fore, "skin", SKIN, grad=0.25), w))
    cuff = K.cyl("gloveCuffR", (wr.x, 0.006, wr.z + 0.035), (wr.x, 0.006, wr.z - 0.01), 0.033, 0.031, 10)
    out.append(K.weigh(K.paint(cuff, "leather", GLOVE, grad=0.1, edge=0.3), w))
    out += _fingers("handR", wr, 1, GLOVE, "leather", w)
    return out


def arm_left(J):
    """Her mechanical left arm: a brass shoulder ball, a gunmetal upper arm with pistons and cables, a
    brass elbow gear, a banded forearm, prayer beads wound round the wrist, a jointed brass hand."""
    out = []
    sh, el, wr = J["upper_arm.L"], J["forearm.L"], J["hand.L"]
    w = _arm_w("L", J)
    ball = K.ellipsoid("shoulderBall", (sh.x, 0, sh.z), (0.058, 0.058, 0.058), 12, 8)
    out.append(K.weigh(K.paint(ball, "metal", BRASS, grad=0.3, edge=0.6), w))
    up = K.loft("mechUpper", [((sh.x, 0, sh.z - 0.03), 0.045, 0.048), ((sh.x, 0, el.z + 0.03), 0.04, 0.042)], 10)
    K.subsurf(up, 1)
    out.append(K.weigh(K.paint(up, "metal", GUNMETAL, grad=0.25, edge=0.6), w))
    for k, (dx, dy) in enumerate(((0.035, 0.02), (-0.03, -0.03))):
        rod = K.cyl("piston%d" % k, (sh.x + dx, dy, sh.z - 0.04), (el.x + dx, dy, el.z + 0.04), 0.008, 0.008, 6)
        cylr = K.cyl("pistonBody%d" % k, (sh.x + dx, dy, sh.z - 0.04), (sh.x + dx, dy, sh.z - 0.12), 0.013, 0.013, 8)
        out.append(K.weigh(K.paint(rod, "metal", K.hexcol("c8ccd4"), grad=0.1, edge=0.6), w))
        out.append(K.weigh(K.paint(cylr, "metal", BRASS, grad=0.1, edge=0.6), w))
    cable = K.loft("cable", [((sh.x + 0.02, -0.06, sh.z + 0.02), 0.009, 0.009), ((sh.x + 0.03, -0.075, sh.z - 0.08), 0.009, 0.009),
                             ((el.x + 0.015, -0.05, el.z + 0.02), 0.009, 0.009)], 6)
    out.append(K.weigh(K.paint(cable, "leather", DARK, grad=0.1), w))
    gear = K.cyl("elbowGear", (el.x - 0.05, 0, el.z), (el.x + 0.05, 0, el.z), 0.046, 0.046, 14)
    out.append(K.weigh(K.paint(gear, "metal", BRASS, grad=0.2, edge=0.7), w))
    for i in range(10):
        a = 2 * math.pi * i / 10
        tooth = K.box("tooth%d" % i, (el.x - 0.051, math.cos(a) * 0.05, el.z + math.sin(a) * 0.05), (0.012, 0.014, 0.014))
        out.append(K.weigh(K.paint(tooth, "metal", BRASS, edge=0.7), w))
    fore = K.loft("mechFore", [((el.x, 0.005, el.z - 0.02), 0.042, 0.044), ((wr.x, 0.008, wr.z + 0.03), 0.034, 0.035)], 10)
    K.subsurf(fore, 1)
    out.append(K.weigh(K.paint(fore, "metal", GUNMETAL, grad=0.25, edge=0.6), w))
    for k, bz in enumerate((el.z - 0.07, el.z - 0.15)):
        band = K.torus("band%d" % k, (el.x, 0.006, bz), 0.04, 0.008, segs=12, tube=5)
        out.append(K.weigh(K.paint(band, "metal", BRASS, edge=0.6), w))
    # prayer beads wound tight round the wrist (two loops) and one short hanging tail with a tassel
    for loop in range(1):
        for i in range(12):
            a = 2 * math.pi * (i + loop * 0.5) / 12
            c = (wr.x + math.cos(a) * 0.04, 0.008 + math.sin(a) * 0.04, wr.z + 0.02 + loop * 0.018)
            bead = K.ellipsoid("bead%d_%d" % (loop, i), c, (0.009, 0.009, 0.009), 5, 3)
            out.append(K.weigh(K.paint(bead, "leather", WOOD, grad=0.2, edge=0.4), w))
    for i in range(4):
        c = (wr.x - 0.038, 0.035, wr.z - 0.005 - i * 0.017)
        bead = K.ellipsoid("beadTail%d" % i, c, (0.008, 0.008, 0.008), 5, 3)
        out.append(K.weigh(K.paint(bead, "leather", WOOD, grad=0.2), w))
    out += _fingers("handL", wr, -1, BRASS, "metal", w, mech=True)
    # the oversized slate plate over the mechanical shoulder: a bevelled dome, the sigil in white on its face
    pw = lambda p: {"pauldron.L": 1.0}  # noqa: E731
    plate = K.ellipsoid("plate", (sh.x - 0.02, -0.005, sh.z - 0.02), (0.15, 0.155, 0.13), 16, 12, rot=(0, -32, 0),
                        cut=-0.42)
    sol = plate.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = 0.014
    bev = plate.modifiers.new("bevel", "BEVEL")
    bev.width = 0.004
    bev.segments = 2
    bev.limit_method = "ANGLE"
    K.apply_mods(plate)
    out.append(K.weigh(K.paint(plate, "metal", PLATE, grad=0.3, ao=0.5, edge=0.8), pw))
    out += _sigil(Vector((sh.x - 0.155, -0.005, sh.z + 0.035)), pw)
    # a scripture strip with a wax seal tied to the plate's front edge
    strip = K.ribbon("plateStrip", [(sh.x - 0.06, 0.1, sh.z - 0.02), (sh.x - 0.07, 0.11, sh.z - 0.1),
                                     (sh.x - 0.075, 0.11, sh.z - 0.18)], [0.03, 0.03, 0.026], up=(1, 0, 0.2))
    out.append(K.weigh(K.paint(strip, "cloth", PAPER, grad=0.15, ao=0.3), pw))
    seal = K.cyl("plateSeal", (sh.x - 0.06, 0.1, sh.z - 0.03), (sh.x - 0.06, 0.116, sh.z - 0.03), 0.012, 0.012, 10)
    out.append(K.weigh(K.paint(seal, "cloth", WAX), pw))
    return out


def _sigil(c, w, n=(-0.9, 0.0, 0.42)):
    """The open eye inside a teardrop, white on the plate's outer face (facing n). The eye is wide along
    the arm's front-back; the teardrop hangs below it."""
    out = []
    n = Vector(n).normalized()
    down = Vector((0, 0, -1)) - n * n.z
    down.normalize()
    eye = K.torus("sigilEye", c, 1.0, 0.006, axis=n, segs=20, tube=4, scale=(0.024, 0.046, 1.0))
    pupil = K.ellipsoid("sigilPupil", c + n * 0.004, (0.012, 0.012, 0.012), 8, 6)
    drop = K.torus("sigilDrop", c + down * 0.045 + n * 0.002, 1.0, 0.005, axis=n, segs=14, tube=4,
                   scale=(0.018, 0.012, 1.0))
    for ob in (eye, pupil, drop):
        out.append(K.weigh(K.paint(ob, "cloth", WHITE, grad=0.05, ao=0.1, noise=0.03), w))
    return out


# --- head: face, eyes, beret, hair -----------------------------------------------------------------

def head(J, crown):
    out = []
    nz = J["head"].z
    hc = Vector((0, 0.008, nz + 0.17))           # the skull's middle
    hw = lambda p: K.blend("hips", "head", K.smooth01(nz - 0.02, nz + 0.05, p.z))  # noqa: E731
    hh = lambda p: {"head": 1.0}  # noqa: E731
    sk = K.ellipsoid("skull", hc, (0.118, 0.13, 0.16), 26, 18)
    # sculpt: a softer, narrower jaw and chin, full cheeks, a flat back of the head
    for v in sk.data.vertices:
        p = v.co
        dz = p.z - hc.z
        if dz < 0:
            k = 1.0 - min(1.0, -dz / 0.16) * 0.32
            p.x *= k
            if p.y > hc.y:
                p.y = hc.y + (p.y - hc.y) * (1.0 - min(1.0, -dz / 0.16) * 0.12)
        if p.y < hc.y - 0.06:
            p.y = hc.y - 0.06 + (p.y - (hc.y - 0.06)) * 0.75
        if -0.07 < dz < 0.0 and p.y > hc.y + 0.05:
            p.x *= 1.04            # cheeks
    out.append(K.weigh(K.paint(sk, "skin", SKIN, grad=0.2, ao=0.5), hw))
    R = (0.118, 0.13, 0.16)

    def face(x, z, out_by=0.0):
        """A point on the front of the skull at (x, z), pushed out_by along the face."""
        dz = z - hc.z
        jaw = 1.0 - min(1.0, max(0.0, -dz) / 0.16) * 0.32
        u = (x / (R[0] * jaw)) ** 2 + (dz / R[2]) ** 2
        y = R[1] * math.sqrt(max(0.0, 1.0 - u))
        if dz < 0:
            y *= 1.0 - min(1.0, -dz / 0.16) * 0.12
        return Vector((x, hc.y + y + out_by, z))

    nose = K.loft("nose", [(face(0, hc.z - 0.0, -0.004), 0.011, 0.008), (face(0, hc.z - 0.04, 0.012), 0.014, 0.012),
                           (face(0, hc.z - 0.052, 0.006), 0.012, 0.008)], 8)
    K.subsurf(nose, 1)
    out.append(K.weigh(K.paint(nose, "skin", SKIN, grad=0.1, ao=0.3), hh))
    for sx in (-1, 1):
        ear = K.ellipsoid("ear%d" % sx, (sx * 0.112, hc.y - 0.008, hc.z - 0.012), (0.011, 0.02, 0.028), 8, 6)
        out.append(K.weigh(K.paint(ear, "skin", SKIN, grad=0.1, ao=0.5), hh))
    ez = hc.z + 0.005
    # her left eye: human, big and wide open (a little too wide), an upper lid line and lashes
    le = face(-0.046, ez, -0.008)
    white = K.ellipsoid("eyeWhite", le, (0.026, 0.012, 0.022), 14, 8, rot=(0, 0, -12))
    iris = K.ellipsoid("iris", le + Vector((0.002, 0.009, 0)), (0.013, 0.006, 0.014), 12, 6)
    pupil = K.ellipsoid("pupil", le + Vector((0.002, 0.0135, 0)), (0.006, 0.003, 0.007), 8, 4)
    glint = K.ellipsoid("glint", le + Vector((0.006, 0.0155, 0.006)), (0.003, 0.002, 0.003), 6, 4)
    out.append(K.weigh(K.paint(white, "eyes", WHITE, grad=0.05, ao=0.2, noise=0.02), hh))
    out.append(K.weigh(K.paint(iris, "eyes", IRIS, grad=0.05, ao=0.1, noise=0.02), hh))
    out.append(K.weigh(K.paint(pupil, "eyes", DARK, grad=0.0, ao=0.0, noise=0.0), hh))
    out.append(K.weigh(K.paint(glint, "eyes", WHITE, grad=0.0, ao=0.0, noise=0.0), hh))
    lid = K.loft("lidL", [(le + Vector((0.026, 0.004, 0.006)), 0.0035, 0.003), (le + Vector((0.0, 0.012, 0.021)), 0.0045, 0.004),
                          (le + Vector((-0.028, 0.002, 0.01)), 0.004, 0.003), (le + Vector((-0.036, -0.002, 0.016)), 0.002, 0.002)], 6)
    out.append(K.weigh(K.paint(lid, "hair", DARK, grad=0.0, ao=0.0, noise=0.0), hh))
    # her right eye: the brass-rimmed mechanical lens glowing orange, on a riveted gunmetal patch
    re = face(0.048, ez, -0.004)
    patch = K.ellipsoid("eyePatch", re + Vector((0.004, -0.008, 0.0)), (0.04, 0.016, 0.04), 14, 8)
    out.append(K.weigh(K.paint(patch, "metal", GUNMETAL, grad=0.2, edge=0.5), hh))
    rim = K.torus("lensRim", re + Vector((0, 0.008, 0)), 0.022, 0.007, axis=(0, 1, 0), segs=16, tube=5)
    out.append(K.weigh(K.paint(rim, "metal", BRASS, grad=0.1, edge=0.7), hh))
    lens = K.ellipsoid("lens", re + Vector((0, 0.008, 0)), (0.017, 0.008, 0.017), 12, 6)
    out.append(K.weigh(K.paint(lens, "glow", EMBER, grad=0.0, ao=0.0, noise=0.03), hh))
    for i in range(4):
        a = math.radians(45 + 90 * i)
        rv = K.ellipsoid("rivet%d" % i, re + Vector((math.cos(a) * 0.033, 0.006, math.sin(a) * 0.032)), (0.004,) * 3, 6, 4)
        out.append(K.weigh(K.paint(rv, "metal", BRASS, edge=0.5), hh))
    # brows: dark, strong, her left one nicked; the right raised over the lens
    for sx in (-1, 1):
        b0 = face(sx * 0.018, ez + 0.036, 0.0)
        b1 = face(sx * 0.05, ez + 0.044 + (0.006 if sx > 0 else 0.0), 0.0)
        b2 = face(sx * 0.075, ez + 0.036, -0.004)
        brow = K.loft("brow%d" % sx, [(b0, 0.004, 0.003), (b1, 0.006, 0.004), (b2, 0.0035, 0.003)], 6)
        out.append(K.weigh(K.paint(brow, "hair", HAIR, grad=0.0, ao=0.0), hh))
    nick = K.box("browNick", face(-0.055, ez + 0.044, 0.004), (0.004, 0.006, 0.012))
    out.append(K.weigh(K.paint(nick, "skin", SKIN, grad=0.0, ao=0.0), hh))
    # lips: a calm, faint smile
    mz = hc.z - 0.088
    upper = K.loft("lipUpper", [(face(-0.026, mz + 0.002, -0.002), 0.002, 0.002), (face(-0.01, mz + 0.006, 0.002), 0.005, 0.004),
                                (face(0.01, mz + 0.006, 0.002), 0.005, 0.004), (face(0.027, mz + 0.004, -0.002), 0.002, 0.002)], 6)
    lower = K.loft("lipLower", [(face(-0.018, mz - 0.003, 0.0), 0.003, 0.003), (face(0, mz - 0.008, 0.003), 0.007, 0.005),
                                (face(0.019, mz - 0.002, 0.0), 0.003, 0.003)], 6)
    for ob in (upper, lower):
        out.append(K.weigh(K.paint(ob, "skin", K.hexcol("a05a48"), grad=0.1, ao=0.0), hh))
    # a scar from the lens patch down her cheek
    scar = K.loft("scar", [(face(0.06, ez - 0.03, 0.0), 0.0025, 0.002), (face(0.07, ez - 0.07, 0.0), 0.002, 0.002)], 5)
    out.append(K.weigh(K.paint(scar, "skin", K.hexcol("8a5640"), grad=0.0, ao=0.0), hh))
    # hair: a dark cap under the beret, swept back, and a short tied braid
    hair = K.ellipsoid("hair", hc + Vector((0, -0.012, 0.025)), (0.124, 0.134, 0.15), 20, 12, cut=-0.25)
    for v in hair.data.vertices:
        if v.co.y > hc.y + 0.02 and v.co.z < hc.z + 0.09:
            v.co.y = hc.y + 0.02 - (v.co.y - hc.y - 0.02) * 0.2      # clear of the brow and face: hair at the sides and back
    out.append(K.weigh(K.paint(hair, "hair", HAIR, grad=0.25, ao=0.4), hh))
    for i in range(5):
        c = (0.0, hc.y - 0.13 - i * 0.008, hc.z - 0.04 - i * 0.032)
        r = 0.026 - i * 0.003
        b = K.ellipsoid("braid%d" % i, c, (r, r * 0.9, r * 1.2), 8, 6)
        out.append(K.weigh(K.paint(b, "hair", HAIR, grad=0.2, ao=0.4), hh))
    tie = K.torus("braidTie", (0.0, hc.y - 0.135, hc.z - 0.105), 0.016, 0.005, segs=10, tube=4)
    out.append(K.weigh(K.paint(tie, "cloth", SCARF), hh))
    # the beret, tilted to her right, a darker band, the brass badge with the eye sigil at the front left
    bc = hc + Vector((0.03, -0.005, 0.13))
    beret = K.ellipsoid("beret", bc, (0.165, 0.158, 0.065), 30, 14, rot=(5, -20, 0))
    for v in beret.data.vertices:
        p = v.co
        if p.z < bc.z - 0.015:
            p.z = bc.z - 0.015 + (p.z - (bc.z - 0.015)) * 0.45
        # the soft crown slumps over to her right
        side = max(0.0, (p.x - bc.x) / 0.165)
        p.z -= side * side * 0.03
    K.folds(beret, 0.005, 0.05)
    out.append(K.weigh(K.paint(beret, "cloth", BERET, grad=0.3, ao=0.4), hh))
    band = K.torus("beretBand", hc + Vector((0.006, 0.0, 0.098)), 1.0, 0.008, segs=24, tube=4, scale=(0.121, 0.134, 1.0))
    out.append(K.weigh(K.paint(band, "cloth", K.hexcol("283066"), grad=0.1, ao=0.3), hh))
    badge = K.ellipsoid("badge", hc + Vector((-0.045, 0.13, 0.112)), (0.016, 0.006, 0.02), 10, 6, rot=(0, 0, -20))
    out.append(K.weigh(K.paint(badge, "metal", BRASS, edge=0.7), hh))
    return out


# --- scarf ----------------------------------------------------------------------------------------

def scarf(J):
    """The orange signal scarf: a knot at the throat and two tails streaming back over her left shoulder."""
    out = []
    nz = J["head"].z
    sw = lambda p: K.blend("hips", "scarf", K.smooth01(-0.02, -0.12, p.y))  # noqa: E731
    wrap = K.torus("scarfWrap", (0, 0.0, nz + 0.0), 1.0, 0.024, segs=18, tube=6, scale=(0.072, 0.066, 1.0))
    K.folds(wrap, 0.005, 0.03)
    out.append(K.weigh(K.paint(wrap, "cloth", SCARF, grad=0.2, ao=0.5), lambda p: {"hips": 1.0}))
    knot = K.ellipsoid("scarfKnot", (0.02, 0.07, nz - 0.03), (0.03, 0.022, 0.028), 10, 6)
    out.append(K.weigh(K.paint(knot, "cloth", SCARF, grad=0.2, ao=0.4), lambda p: {"hips": 1.0}))
    flap = K.ribbon("scarfFlap", [(0.02, 0.085, nz - 0.04), (0.035, 0.1, nz - 0.1), (0.03, 0.11, nz - 0.15)],
                    [0.05, 0.045, 0.03], up=(1, 0, 0))
    out.append(K.weigh(K.paint(flap, "cloth", SCARF, grad=0.25, ao=0.3), lambda p: {"hips": 1.0}))
    for k, (side, dz) in enumerate(((-1, 0.0), (-0.8, -0.03))):
        path = []
        n = 9
        for i in range(n):
            t = i / (n - 1)
            path.append((side * (0.05 + t * 0.32), -0.06 - t * 0.2, nz + 0.0 + dz + math.sin(t * 6.0 + k) * 0.03 + t * 0.03))
        tail = K.ribbon("scarfTail%d" % k, path, [0.065 - 0.035 * (i / (n - 1)) for i in range(n)], up=(0.1, 0.25, 1))
        K.folds(tail, 0.004, 0.04)
        out.append(K.weigh(K.paint(tail, "cloth", SCARF, grad=0.25, ao=0.3), sw))
    return out


# --- her rifle (the held weapon's space: Godot's Gun node, forward -Z there, +Y here) -------------------

def rifle(wd):
    """The long ember rifle: dark wood stock, gunmetal receiver, a shroud whose vents glow orange, a long
    barrel with a muzzle brake at the Muzzle, a scope, brass bands, a scripture strip tied on."""
    out = []
    mz = K.g2b(wd["muzzle"])           # the shots leave here
    z0 = mz.z
    stock = K.loft("stock", [((0, -0.36, z0 - 0.09), 0.02, 0.055), ((0, -0.24, z0 - 0.06), 0.022, 0.045),
                             ((0, -0.08, z0 - 0.02), 0.022, 0.03)], 8)
    K.subsurf(stock, 1)
    out.append(K.paint(stock, "leather", WOOD, grad=0.3, edge=0.4))
    butt = K.box("butt", (0, -0.37, z0 - 0.09), (0.042, 0.02, 0.11), bevel=0.006)
    out.append(K.paint(butt, "metal", GUNMETAL, edge=0.5))
    grip = K.box("grip", (0, -0.03, z0 - 0.09), (0.03, 0.04, 0.1), rot=(-20, 0, 0), bevel=0.008)
    out.append(K.paint(grip, "leather", WOOD, grad=0.2, edge=0.4))
    rec = K.box("receiver", (0, 0.06, z0 - 0.005), (0.05, 0.26, 0.075), bevel=0.01)
    out.append(K.paint(rec, "metal", GUNMETAL, grad=0.25, edge=0.7))
    shroud = K.box("shroud", (0, 0.32, z0), (0.056, 0.32, 0.066), bevel=0.012)
    out.append(K.paint(shroud, "metal", K.hexcol("5a606e"), grad=0.25, edge=0.7))
    for i in range(4):
        for sx in (-1, 1):
            v = K.box("vent%d%d" % (i, sx), (sx * 0.029, 0.2 + i * 0.075, z0), (0.006, 0.045, 0.018), bevel=0.004)
            out.append(K.paint(v, "glow", EMBER, grad=0.0, ao=0.0, noise=0.05))
    barrel = K.cyl("barrel", (0, 0.47, z0), (0, mz.y - 0.02, z0), 0.014, 0.012, 10)
    out.append(K.paint(barrel, "metal", GUNMETAL, edge=0.5))
    brake = K.cyl("brake", (0, mz.y - 0.035, z0), (0, mz.y + 0.03, z0), 0.021, 0.021, 10)
    out.append(K.paint(brake, "metal", GUNMETAL, grad=0.2, edge=0.7))
    for i, y in enumerate((0.5, 0.6)):
        band = K.torus("rband%d" % i, (0, y, z0), 0.016, 0.004, axis=(0, 1, 0), segs=10, tube=4)
        out.append(K.paint(band, "metal", BRASS, edge=0.6))
    scope = K.cyl("scope", (0, 0.0, z0 + 0.06), (0, 0.17, z0 + 0.06), 0.017, 0.019, 10)
    out.append(K.paint(scope, "metal", DARK, edge=0.6))
    mount = K.box("mount", (0, 0.085, z0 + 0.04), (0.02, 0.08, 0.02))
    out.append(K.paint(mount, "metal", GUNMETAL, edge=0.5))
    mag = K.box("mag", (0, 0.1, z0 - 0.08), (0.03, 0.06, 0.09), rot=(10, 0, 0), bevel=0.006)
    out.append(K.paint(mag, "metal", BRASS, grad=0.2, edge=0.6))
    strip = K.ribbon("rifleStrip", [(0.03, 0.52, z0 - 0.01), (0.034, 0.53, z0 - 0.08), (0.03, 0.525, z0 - 0.15)],
                     [0.026, 0.026, 0.022], up=(0, 1, 0))
    out.append(K.paint(strip, "cloth", PAPER, grad=0.15, ao=0.3))
    return out


if __name__ == "__main__":
    main()
