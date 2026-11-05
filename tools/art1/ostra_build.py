"""Ostra rebuilt for ART-1: blender -b --factory-startup --python tools/art1/ostra_build.py -- [out.blend]
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
OUT = os.environ.get("OSTRA_WORK", os.path.expanduser("~/art1/ostra"))
MASK_TRIS = 3400


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


def mask_mesh():
    """the dense sculpt, decimated: its uv stays the texture's, and (uv) tells the bones what each vertex is"""
    S, UV, pu, v, h = M.surface(301, 401)
    R, C = S.shape[:2]
    V = S.reshape(-1, 3)
    F = [(r * C + c, r * C + c + 1, (r + 1) * C + c + 1, (r + 1) * C + c) for r in range(R - 1) for c in range(C - 1)]
    me = bpy.data.meshes.new("Mask")
    me.from_pydata(V.tolist(), [], F)
    uvl = me.uv_layers.new(name="UVMap")
    loops = np.zeros(len(me.loops), int)
    me.loops.foreach_get("vertex_index", loops)
    uvs = UV.reshape(-1, 2)[loops]
    uvl.data.foreach_set("uv", uvs.ravel())
    ob = bpy.data.objects.new("Mask", me)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.0004)
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    if me.polygons[len(me.polygons) // 2].normal.y < 0:
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.flip_normals()
        bpy.ops.object.mode_set(mode="OBJECT")
    mod = ob.modifiers.new("d", "DECIMATE")
    mod.ratio = MASK_TRIS / (len(me.polygons) * 2)
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier="d")
    ob.select_set(False)
    return ob


def mask_weights(ob):
    me = ob.data
    n = len(me.vertices)
    uvs = np.zeros(len(me.loops) * 2)
    me.uv_layers[0].data.foreach_get("uv", uvs)
    uvs = uvs.reshape(-1, 2)
    loops = np.zeros(len(me.loops), int)
    me.loops.foreach_get("vertex_index", loops)
    uv = np.zeros((n, 2))
    uv[loops] = uvs
    u, v = uv[:, 0] * 2 - 1, uv[:, 1] * 2 - 1
    au = np.abs(u)
    top, bot = M.lips(u)
    mid = top + (bot - top) * 0.5
    # the jaw: everything under the teeth's seam, fading out up the cheeks
    jaw = M.sm(mid + 0.03, mid - 0.04, v) * M.sm(0.98, 0.72, au) * M.sm(-1.05, -0.55, -v + -0.0 + 0 * u + 0) * 1.0
    W = {"x_jaw": jaw.copy()}
    for s, nm in ((1, "R"), (-1, "L")):
        side = (u * s) > 0
        br = M.gauss(au, v, 0.33, 0.46, 0.34, 0.15) * side
        W["x_brow." + nm] = np.clip(br * 1.1, 0, 1) * (1 - jaw)
        ch = M.gauss(au, v, 0.56, -0.13, 0.28, 0.2) * side
        W["x_cheek." + nm] = np.clip(ch * 1.05, 0, 1) * (1 - jaw) * (1 - W["x_brow." + nm])
    tot = sum(W.values())
    W["head"] = np.clip(1 - tot, 0, 1)
    return W


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


def material(name, img, emit_img=None):
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


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(OUT, exist_ok=True)
    groups = {"cloth": [], "leather": [], "metal": [], "void-lining": [], "void-orb": [], "void-wisp": [], "glow-orb": [], "glow-halo": [], "glow-eyes": []}
    joints = []
    def add(p):
        groups[p.mat].append(p)
    add(P.torso())
    sk, grid_ = P.skirt()
    add(sk)
    add(P.lining(grid_))
    for side in (1, -1):
        add(P.sleeve(side))
        add(P.cuff(side))
        hs, J = P.hand(side)
        for h in hs:
            add(h)
        joints += [(k, v) for k, v in J.items()]
    add(P.hood())
    for side in (1, -1):
        n = "R" if side > 0 else "L"
        h, path = P.horn(side)
        h.paint = "horn" + n
        add(h)
        add(P.bell(side, path[-1], "spring_horn%s_2" % n))
        # the chain: from a third along the horn to its tip (a last unskinned bone is the rope's end)
        ks = [6, 9, 12, 16, 16]
        pts = [path[i] for i in ks[:4]] + [path[-1] + (0, 0, -0.07)]
        for i in range(4):
            parent = "head" if i == 0 else "spring_horn%s_%d" % (n, i - 1)
            joints.append(("spring_horn%s_%d" % (n, i), (pts[i], pts[i + 1], parent)))
    add(P.ruff())
    for p in P.collar() + P.bow() + P.buttons() + P.tears():
        add(p)
    wp, path = P.wisp()
    for p in wp:
        add(p)
    idx = np.linspace(0, len(path) - 1, 7).astype(int)
    for i in range(7):
        parent = "hips" if i == 0 else "spring_wisp_%d" % (i - 1)
        tail = path[idx[i + 1]] if i < 6 else path[-1] + (path[-1] - path[-2])
        joints.append(("spring_wisp_%d" % i, (path[idx[i]], tail, parent)))
    orb_at = np.array((P.SH_X, 0, P.WR_Z)) + P.ORB_LOCAL
    for p in P.orb(orb_at):
        add(p)
    joints.append(("x_weapon", (orb_at, orb_at + (0, 0, 0.1), "hand.R")))
    add(P.halo())
    joints.append(("x_halo", (P.HALO_C, P.HALO_C + (0, 0, 0.1), "head")))
    for side in (1, -1):
        e, c = P.eye_ball(side)
        add(e)
        n = "R" if side > 0 else "L"
        joints.append(("x_lid." + n, (c, c + (0, 0.05, 0), "head")))
        joints.append(("x_brow." + n, ((side * 0.075, 0.1, 1.73), (side * 0.075, 0.15, 1.73), "head")))
        joints.append(("x_cheek." + n, ((side * 0.09, 0.1, 1.61), (side * 0.09, 0.15, 1.61), "head")))
    joints.append(("x_jaw", ((0, 0.0, 1.60), (0, 0.1, 1.5), "head")))

    atlas = PT.Atlas(2048, 2048)
    aglow = PT.Atlas(1024, 512)
    aglow.put("card", (96, 140))
    avoid = PT.Atlas(512, 256)
    awisp = PT.Atlas(256, 512)
    awisp.x = awisp.y = 0
    bag = {}
    mats = {}
    def mat_for(key, at):
        return None
    pending = []
    for g, ps in groups.items():
        at = atlas if g in ("cloth", "leather", "metal") else (aglow if g.startswith("glow") else (awisp if g == "void-wisp" else avoid))
        for p in ps:
            at.put(p.paint, p.px)
        pending.append((g, ps, at))
    alb, emit = PT.mask_textures(1024)
    tex = OUT + "/tex/"
    im_main = image("ostra_atlas", atlas.img, tex + "ostra_atlas.png")
    im_glow = image("ostra_glow", aglow.img, tex + "ostra_glow.png")
    im_void = image("ostra_void", avoid.img, tex + "ostra_void.png")
    im_wisp = image("ostra_wisp", awisp.img, tex + "ostra_wisp.png")
    im_mask = image("ostra_mask", alb, tex + "ostra_mask.png")
    im_emit = image("ostra_mask_emit", emit, tex + "ostra_mask_emit.png")
    obs = []
    names = {"cloth": ("Body", "cloth-body", im_main), "leather": ("Gloves", "leather-body", im_main), "metal": ("Bells", "metal-body", im_main),
             "void-lining": ("Lining", "void-body", im_void), "void-orb": ("Orb", "void-orb", im_void), "void-wisp": ("Wisp", "void-wisp", im_wisp),
             "glow-orb": ("OrbSwirl", "glow-orb", im_glow), "glow-halo": ("Halo", "glow-halo", im_glow), "glow-eyes": ("Eyes", "glow-eyes", im_glow)}
    for g, ps, at in pending:
        nm, mn, im = names[g]
        ob = make_part_object(nm, ps, at, material(mn, im), flat=g in ("glow-halo",))
        if g not in ("void-lining",) :
            pass
        obs.append(ob)
    # (closed pieces and sheets carry their own winding: see the preview's backface check)
    for ob in obs:
        if ob.name in ("Eyes", "Orb", "Bells", "Gloves"):
            outward(ob)
    mk = mask_mesh()
    mk.data.materials.append(material("leather-mask", im_mask, im_emit))
    mk.data.polygons.foreach_set("use_smooth", [True] * len(mk.data.polygons))
    set_weights(mk, mask_weights(mk))
    obs.append(mk)
    arm = armature(joints)
    for ob in obs:
        ob.parent = arm
        m = ob.modifiers.new("Armature", "ARMATURE")
        m.object = arm
    tot = sum(sum(len(p.vertices) - 2 for p in ob.data.polygons) for ob in obs)
    print("OSTRA tris", tot, {ob.name: sum(len(p.vertices) - 2 for p in ob.data.polygons) for ob in obs})
    # the cards on their orbit, round the orb
    cards(arm, orb_at, im_glow, aglow)
    # the anchors
    def anchor(name, bone, at):
        e = bpy.data.objects.new(name, None)
        bpy.context.scene.collection.objects.link(e)
        e.parent = arm
        e.parent_type = "BONE"
        e.parent_bone = bone
        pb = arm.data.bones[bone]
        e.matrix_parent_inverse = Matrix.Identity(4)
        e.location = pb.matrix_local.inverted() @ Vector(at) - Vector((0, pb.length, 0))
        return e
    anchor("anchor_head_top", "head", (0, 0, 1.969))
    anchor("anchor_chest", "hips", (0, 0.10, 1.116))
    anchor("anchor_orb", "x_weapon", tuple(orb_at))
    anchor("anchor_halo", "x_halo", tuple(P.HALO_C))
    w = bpy.data.objects.new("weapon", None)
    bpy.context.scene.collection.objects.link(w)
    w.parent = arm
    path_ = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 1 else OUT + "/ostra.blend"
    bpy.ops.wm.save_as_mainfile(filepath=path_)
    print("OSTRA saved", path_)


def cards(arm, c, img, at):
    orbit = bpy.data.objects.new("orbit_cards", None)
    bpy.context.scene.collection.objects.link(orbit)
    orbit.parent = arm
    orbit.parent_type = "BONE"
    orbit.parent_bone = "x_weapon"
    pb = arm.data.bones["x_weapon"]
    orbit.matrix_parent_inverse = Matrix.Identity(4)
    orbit.matrix_world = Matrix.Translation(Vector(c))
    bpy.context.view_layer.update()
    r = 0.235
    m = None
    for i in range(4):
        ang = np.radians(20 + i * 90)
        cx, cy = np.sin(ang) * r, np.cos(ang) * r
        z = (0.0, -0.06, 0.012, -0.05)[i]
        # the card, tipped up toward the camera; a string runs from it to the orb
        w, h = 0.05, 0.075
        d = np.array((np.sin(ang), np.cos(ang), 0.0))
        side = np.array((np.cos(ang), -np.sin(ang), 0.0))
        up = np.array((0, 0, 1.0)) * 0.76 + d * 0.65
        pts = [-side * w - up * h, side * w - up * h, side * w + up * h, -side * w + up * h]
        o = np.array((cx, cy, z))
        vs = [p + o for p in pts]
        ins = o * -0.92
        s = np.array((0, 0, 0.0016))
        vs += [o + s, o - s, o + ins - s, o + ins + s]
        faces = [(0, 1, 2, 3), (3, 2, 1, 0), (4, 5, 6, 7), (7, 6, 5, 4)]
        me = bpy.data.meshes.new("card%d" % i)
        me.from_pydata([tuple(v) for v in vs], [], faces)
        uvl = me.uv_layers.new(name="UVMap")
        cuv = [at.uv("card", a, b) for a, b in ((0, 1), (1, 1), (1, 0), (0, 0))]
        mid = at.uv("card", 0.5, 0.02)
        uvs = cuv + cuv[::-1] + [mid] * 8
        uvl.data.foreach_set("uv", [c for p in uvs for c in p])
        if m is None:
            m = material("glow-cards", img)
        me.materials.append(m)
        ob = bpy.data.objects.new("orbit_cards_%d" % i, me)
        bpy.context.scene.collection.objects.link(ob)
        ob.parent = orbit
        an = bpy.data.objects.new("anchor_orbit_cards_%d" % i, None)
        bpy.context.scene.collection.objects.link(an)
        an.parent = ob
        an.location = o


main()
