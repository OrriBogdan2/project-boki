"""Motley rebuilt for ART-1 (id and files: ostra): blender -b --factory-startup --python tools/art1/ostra_build.py -- [out.blend]
Builds every piece (ostra_parts.py, ostra_mask.py), paints it (ostra_paint.py), skins it on the contract armature with fingers, jaw,
brows, lids, the orb's bone and the spring chains, and saves the .blend that ostra_anim.py keys and exports."""
import json, os, subprocess, sys
import numpy as np
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "meshy"))
import imgio
import ostra_mask as M
import ostra_paint as PT
import ostra_parts as P

REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.environ.get("OSTRA_WORK", os.path.expanduser("~/art1/motley"))


def to_blender(p):
    return (p[0], -p[2], p[1])


def armature(joints):
    rig = json.load(open(os.path.join(REPO, "art/wardens/src/ostra_rig.json")))["bones"]
    data = bpy.data.armatures.new("Armature")
    arm = bpy.data.objects.new("Armature", data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = data.edit_bones
    order = []
    def add(name):
        if name in order or name not in rig:
            return
        if rig[name]["parent"]:
            add(rig[name]["parent"])
        order.append(name)
    for n in rig:
        add(n)
    for n in order:
        b = rig[n]
        e = eb.new(n)
        h = Vector(to_blender(b["head"]))
        y = Vector(to_blender(b["y"]))
        z = Vector(to_blender(b["z"]))
        e.head = h
        e.tail = h + y * 0.1
        e.align_roll(z)
        if b["parent"]:
            e.parent = eb[b["parent"]]
    for name, (head, tail, parent) in joints:
        e = eb.new(name)
        e.head = Vector(tuple(float(c) for c in head))
        e.tail = Vector(tuple(float(c) for c in tail))
        if (e.tail - e.head).length < 0.005:
            e.tail = e.head + Vector((0, 0, 0.05))
        e.parent = eb[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def set_weights(ob, W):
    for bone, w in W.items():
        vg = ob.vertex_groups.get(bone) or ob.vertex_groups.new(name=bone)
        for i in np.nonzero(w > 0.002)[0]:
            vg.add([int(i)], float(w[i]), "ADD")


def make_part_object(name, parts, atlases, material, flat=False):
    """joins parts into one mesh with shared material, uvs mapped into their atlas rects"""
    V, F, UV, W = [], [], [], {}
    base = 0
    n_total = sum(len(p.V) for p in parts)
    for p in parts:
        at = atlases
        at.put(p.paint, p.px)
        V.append(p.V)
        for f, st in zip(p.F, p.ST):
            F.append([i + base for i in f])
            UV.extend([at.uv(p.paint, s, t) for s, t in st])
        for b, w in p.W.items():
            arr = W.setdefault(b, np.zeros(n_total, np.float32))
            arr[base:base + len(p.V)] = w
        base += len(p.V)
    V = np.vstack(V)
    me = bpy.data.meshes.new(name)
    me.from_pydata(V.tolist(), [], F)
    uvl = me.uv_layers.new(name="UVMap")
    uvl.data.foreach_set("uv", np.array(UV, np.float32).ravel())
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    me.materials.append(material)
    me.polygons.foreach_set("use_smooth", [not flat] * len(me.polygons))
    set_weights(ob, W)
    return ob


def image(name, arr, path, fmt="JPEG"):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    imgio.save(arr, path)
    im = bpy.data.images.load(path)
    im.name = name
    im.pack()
    return im


def material(name, img, emit_img=None, normal=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bs = m.node_tree.nodes["Principled BSDF"]
    bs.inputs["Roughness"].default_value = 0.7
    if img is not None:
        t = m.node_tree.nodes.new("ShaderNodeTexImage")
        t.image = img
        m.node_tree.links.new(t.outputs[0], bs.inputs["Base Color"])
    if emit_img is not None:
        t = m.node_tree.nodes.new("ShaderNodeTexImage")
        t.image = emit_img
        m.node_tree.links.new(t.outputs[0], bs.inputs["Emission Color"])
        bs.inputs["Emission Strength"].default_value = 1.0
    if normal is not None:
        t = m.node_tree.nodes.new("ShaderNodeTexImage")
        t.image = normal
        nm = m.node_tree.nodes.new("ShaderNodeNormalMap")
        m.node_tree.links.new(t.outputs[0], nm.inputs["Color"])
        m.node_tree.links.new(nm.outputs[0], bs.inputs["Normal"])
    return m


def outward(ob, ref=None):
    """closed tubes wind by their frames: turn their faces out"""
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    ob.select_set(False)


def write_void_card():
    """item 136: the card he flicks, a texture the kit's projectile wears (scripts/heroes/void_card.gd)"""
    w, h = 256, 360
    ss, tt = np.meshgrid((np.arange(w) + 0.5) / w, (np.arange(h) + 0.5) / h)
    imgio.save(PT.p_voidcard(ss.astype(np.float32), tt.astype(np.float32)), os.path.join(REPO, "art/wardens/ostra/void_card.png"))


def add_cards(arm, at, mat):
    """the chaotic swirl: two orbits at different heights and radii, cards at all angles, some burnt or torn; tilted up for the match camera.
    ostra.json "swirl" tumbles them (WardenSway)."""
    idx = 0
    for name, centre, r, items in (
            ("orbit_cards", (0, 0, 1.32), 0.62, ((15, 0.1, "cardburn"), (85, -0.14, "cardback"), (160, 0.2, "cardburn"), (235, -0.05, "card"), (305, 0.14, "cardburn"))),
            ("orbit_cardsb", (0, 0, 0.92), 0.5, ((50, 0.06, "cardburn"), (175, -0.08, "card"), (285, 0.02, "cardburn")))):
        orbit = bpy.data.objects.new(name, None)
        bpy.context.scene.collection.objects.link(orbit)
        orbit.parent = arm
        orbit.parent_type = "BONE"
        orbit.parent_bone = "hips"
        pb = arm.data.bones["hips"]
        orbit.matrix_parent_inverse = Matrix.Identity(4)
        orbit.matrix_world = Matrix.Translation(Vector(centre))
        bpy.context.view_layer.update()
        for deg, h, key in items:
            ang = np.radians(deg)
            d = np.array((np.sin(ang), np.cos(ang), 0.0))
            side = np.array((np.cos(ang), -np.sin(ang), 0.0))
            up = np.array((0, 0, 1.0)) * 0.72 + d * 0.7
            w, hh = 0.095, 0.135
            o = d * r + np.array((0, 0, h))
            pts = [-side * w - up * hh, side * w - up * hh, side * w + up * hh, -side * w + up * hh]
            uv = [(0, 1), (1, 1), (1, 0), (0, 0)]
            if key == "cardburn":     # a corner burnt away
                pts = [pts[0], pts[1], side * w + up * hh * 0.2, side * w * 0.1 + up * hh, pts[3]]
                uv = [(0, 1), (1, 1), (1, 0.4), (0.55, 0), (0, 0)]
                flame = [side * w * 1.0 + up * hh * 0.2, side * w * 1.16 + up * hh * 0.72, side * w * 0.92 + up * hh * 0.78, side * w * 0.72 + up * hh * 1.08, side * w * 0.46 + up * hh * 0.92, side * w * 0.1 + up * hh * 1.0]
            n = len(pts)
            me = bpy.data.meshes.new("card%d" % idx)
            faces = [tuple(range(n)), tuple(range(n - 1, -1, -1))]
            q = [at.uv(key, a, b) for a, b in uv]
            corners = q + q[::-1]
            if key == "cardburn":     # the flame licking off the burnt edge
                m = len(flame)
                pts = pts + flame
                faces += [tuple(range(n, n + m)), tuple(range(n + m - 1, n - 1, -1))]
                fl = [at.uv("flame", 0.5, 1.0 - 0.9 * i / max(m - 1, 1)) for i in range(m)]
                corners += fl + fl[::-1]
            me.from_pydata([tuple(p) for p in pts], [], faces)
            uvl = me.uv_layers.new(name="UVMap")
            uvl.data.foreach_set("uv", [c for p in corners for c in p])
            me.materials.append(mat)
            ob = bpy.data.objects.new("orbit_cards_%d" % idx, me)
            bpy.context.scene.collection.objects.link(ob)
            ob.parent = orbit
            ob.location = o
            an = bpy.data.objects.new("anchor_orbit_cards_%d" % idx, None)
            bpy.context.scene.collection.objects.link(an)
            an.parent = ob
            idx += 1


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(OUT, exist_ok=True)
    groups = {"cloth": [], "cloth-ruff": [], "metal": [], "void-body": [], "void-wisp": [], "glow-cards": [], "leather-face": []}
    joints = [("x_box", ((0, 0, 0.18), (0, 0, 0.3), "root"))]
    def add(p):
        groups[p.mat].append(p)
    for p in P.box() + P.box_rim():
        add(p)
    ps, hinge = P.lid()
    for p in ps:
        add(p)
    joints.append(("x_boxlid", (hinge, tuple(np.array(hinge) + (0.1, 0, 0)), "x_box")))
    ps, axle = P.crank()
    for p in ps:
        add(p)
    joints.append(("x_crank", (axle, tuple(axle + (0.1, 0, 0)), "x_box")))
    add(P.spring())
    add(P.smoke_wrap())
    joints.append(("x_smoke", ((0, 0, 0.5), (0, 0, 0.62), "x_box")))
    joints.append(("x_void", ((0, 0, 0.3), (0, 0, 0.4), "x_box")))
    add(P.torso())
    pl, g_ = P.peplum()
    add(pl)
    add(P.lining(g_))
    ps, js = P.tails()
    for p in ps:
        add(p)
    joints += js
    for side in (1, -1):
        add(P.sleeve(side))
        add(P.cuff(side))
        hs, J = P.hand(side)
        for h in hs:
            add(h)
        joints += list(J.items())
    add(P.hood())
    add(P.face())
    for side in (1, -1):
        n = "R" if side > 0 else "L"
        h, path = P.horn(side)
        add(h)
        add(P.ball("bell" + n, path[-1] + (0, 0, -0.03), 0.042, "spring_horn%s_2" % n))
        pts = [path[i] for i in (7, 11, 15, 21)] + [path[-1] + (0, 0, -0.07)]
        for i in range(4):
            parent = "head" if i == 0 else "spring_horn%s_%d" % (n, i - 1)
            joints.append(("spring_horn%s_%d" % (n, i), (pts[i], pts[i + 1], parent)))
    add(P.ruff())
    for p in P.collar() + P.buttons():
        add(p)
    wp, path = P.wisp()
    for p in wp:
        add(p)
    idx = np.linspace(0, len(path) * 0.84, 6).astype(int)
    for i in range(5):
        parent = "x_void" if i == 0 else "spring_wisp_%d" % (i - 1)
        joints.append(("spring_wisp_%d" % i, (path[idx[i]], path[idx[i + 1]], parent)))
    # (item 136: no weapon. His palms are the cast points; the fan in his left hand is the deck the flurry deals from)
    palm_r = (P.SH_X - 0.03, 0.0, P.WR_Z - 0.08)
    palm_l = (-P.SH_X + 0.03, 0.0, P.WR_Z - 0.08)
    f, fc = P.fan()
    add(f)
    joints.append(("x_fan", (fc, fc + (0, 0, -0.1), "hand.L")))
    for side in (1, -1):
        n = "R" if side > 0 else "L"
        joints.append(("x_brow." + n, ((side * 0.05, 0.14, 1.72), (side * 0.05, 0.2, 1.72), "head")))
        joints.append(("x_cheek." + n, ((side * 0.085, 0.12, 1.62), (side * 0.085, 0.18, 1.62), "head")))
    joints.append(("x_jaw", ((0, -0.04, 1.66), (0, 0.06, 1.58), "head")))

    atlas = PT.Atlas(2048, 1536)
    aglow = PT.Atlas(512, 256)
    for k, px in (("card", (96, 136)), ("cardback", (96, 136)), ("cardburn", (96, 136)), ("flame", (32, 64))):
        aglow.put(k, px)
    avoid = PT.Atlas(256, 128)
    awisp = PT.Atlas(256, 512)
    pending = []
    for g, ps in groups.items():
        if g == "leather-face":
            continue
        at = atlas if g in ("cloth", "cloth-ruff", "metal") else (aglow if g.startswith("glow") else (awisp if g == "void-wisp" else avoid))
        for p in ps:
            at.put(p.paint, p.px)
        pending.append((g, ps, at))
    write_void_card()
    alb, emit = M.textures(1024)
    tex = OUT + "/tex/"
    im_main = image("atlas", atlas.img, tex + "atlas.png")
    im_nrm = image("normal", PT.normal_map(atlas), tex + "normal.png")
    im_nrm.colorspace_settings.name = "Non-Color"
    im_glow = image("glow", aglow.img, tex + "glow.png")
    im_void = image("void", avoid.img, tex + "void.png")
    im_wisp = image("wisp", awisp.img, tex + "wisp.png")
    im_face = image("face", alb, tex + "face.png")
    im_emit = image("face_emit", emit, tex + "face_emit.png")
    obs = []
    names = {"cloth": ("Body", "cloth-body", im_main), "cloth-ruff": ("Ruff", "cloth-ruff", im_main), "metal": ("Brass", "metal-body", im_main), "void-body": ("Lining", "void-body", im_void),
             "void-wisp": ("Wisp", "void-wisp", im_wisp), "glow-cards": ("Fan", "glow-cards", im_glow)}
    mats = {}
    for g, ps, at in pending:
        nm, mn, im = names[g]
        mats[g] = material(mn, im, normal=im_nrm if g in ("cloth", "cloth-ruff", "metal") else None)
        obs.append(make_part_object(nm, ps, at, mats[g]))
    # the face: its corners are already the face texture's
    fp = groups["leather-face"][0]
    class Same:
        def put(self, *a): pass
        def uv(self, k, s, t): return (s, 1.0 - t)
    ob = make_part_object("Face", [fp], Same(), material("leather-face", im_face, im_emit))
    obs.append(ob)
    arm = armature(joints)
    for ob in obs:
        ob.parent = arm
        m = ob.modifiers.new("Armature", "ARMATURE")
        m.object = arm
    add_cards(arm, aglow, mats["glow-cards"])
    tot = sum(sum(len(p.vertices) - 2 for p in ob.data.polygons) for ob in obs) + 8 * 6 + 5 * 8
    print("OSTRA tris", tot, {ob.name: sum(len(p.vertices) - 2 for p in ob.data.polygons) for ob in obs})
    def anchor(name, bone, at):
        e = bpy.data.objects.new(name, None)
        bpy.context.scene.collection.objects.link(e)
        e.parent = arm
        e.parent_type = "BONE"
        e.parent_bone = bone
        pb = arm.data.bones[bone]
        e.matrix_parent_inverse = Matrix.Identity(4)
        e.location = pb.matrix_local.inverted() @ Vector(at) - Vector((0, pb.length, 0))
    anchor("anchor_head_top", "head", (0, 0, 1.95))
    anchor("anchor_chest", "hips", (0, 0.10, 1.116))
    anchor("anchor_orb", "hand.R", palm_r)
    anchor("anchor_hand_r", "hand.R", palm_r)
    anchor("anchor_hand_l", "hand.L", palm_l)
    anchor("anchor_cards", "hand.L", palm_l)
    anchor("weapon_muzzle", "hand.R", (palm_r[0], palm_r[1], palm_r[2] - 0.14))
    anchor("anchor_grin", "head", (0, 0.14, 1.6))
    anchor("anchor_box", "x_box", (0, 0, 0.36))
    anchor("anchor_box_base", "x_box", (0, 0, 0.02))
    anchor("anchor_spring_base", "x_box", (0, 0, 0.33))
    anchor("anchor_spring_top", "hips", (0, 0, P.SPRING_TOP))
    anchor("anchor_lid", "x_boxlid", (0, -0.31, 0.75))
    anchor("anchor_crank", "x_crank", tuple(axle + (0.1, 0, 0)))
    anchor("anchor_fan", "x_fan", tuple(fc + (0, 0, -0.1)))
    p_ = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 1 else OUT + "/ostra.blend"
    bpy.ops.wm.save_as_mainfile(filepath=p_)
    print("OSTRA saved", p_)


main()
