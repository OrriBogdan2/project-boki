"""Shared bpy helpers for the Warden builds (docs/art/wardens/RIG_CONTRACT.md).

A Warden script (tools/blender/<name>.py) builds its pieces with these helpers, each piece a separate
object tagged with its toon slot, its painted look and its skin weights; then bake_atlas() paints every
piece into one 1024 atlas from procedural shaders (gradient, AO, edge wear, noise), finish() joins the
body, skins it to the contract armature (rig JSON from `godot --headless -- --warden-rig-json`) and
export() writes the .glb the game's loader takes.

Coordinates: the rig JSON is Godot model space (+Y up, facing -Z); here Blender's (+Z up), the Warden
facing +Y: g2b() converts. The glTF exporter's +Y-up conversion turns it back.
"""
import json
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

SLOTS = ["skin", "hair", "cloth", "leather", "metal", "eyes", "team", "glow"]
ATLAS_PX = 1024


def g2b(p):
    """Godot model space -> Blender (x, -z, y)."""
    return Vector((p[0], -p[2], p[1]))


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"
    return sc


def load_rig(path):
    with open(path) as f:
        return json.load(f)


def _depth(rig, name):
    d = 0
    p = rig["bones"][name]["parent"]
    while p:
        d += 1
        p = rig["bones"][p]["parent"]
    return d


BONE_LEN = {"root": 0.12, "hips": 0.2, "head": 0.25, "pauldron.L": 0.1, "pauldron.R": 0.1, "skirt": 0.1,
            "scarf": 0.12, "hand.L": 0.08, "hand.R": 0.08, "shin.L": 0.3, "shin.R": 0.3}


def build_armature(rig):
    """The contract armature: each bone's head on its rig node, Y along the limb, parents as the contract."""
    data = bpy.data.armatures.new("Armature")
    arm = bpy.data.objects.new("Armature", data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = data.edit_bones
    names = sorted(rig["bones"], key=lambda n: _depth(rig, n))
    for name in names:
        b = rig["bones"][name]
        e = eb.new(name)
        e.head = g2b(b["head"])
        y = g2b(b["y"]).normalized()
        e.tail = e.head + y * BONE_LEN.get(name, 0.2)
        e.align_roll(g2b(b["z"]))
        if b["parent"]:
            e.parent = eb[b["parent"]]
            e.use_connect = False
    # limbs reach their child joint
    for name in names:
        b = rig["bones"][name]
        for child in names:
            if rig["bones"][child]["parent"] == name and name.split(".")[0] in ("upper_arm", "forearm", "thigh"):
                eb[name].tail = eb[child].head
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def bone_head(rig, name):
    return g2b(rig["bones"][name]["head"])


# --- pieces ------------------------------------------------------------------------------------------

def _new_obj(name, bm, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def _frame(d):
    d = d.normalized()
    ref = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((0, 1, 0))
    x = ref.cross(d).normalized()
    y = d.cross(x).normalized()
    return x, y


def loft(name, rings, segs=16, cap=True, twist=0.0):
    """A tube through rings [(centre, rx, ry), ...] (each ring square to the path; rx along the frame's x
    axis, which for a vertical path is world X), capped at both ends."""
    bm = bmesh.new()
    loops = []
    for i, (c, rx, ry) in enumerate(rings):
        c = Vector(c)
        a = Vector(rings[max(0, i - 1)][0])
        b = Vector(rings[min(len(rings) - 1, i + 1)][0])
        d = (b - a) if (b - a).length > 1e-6 else Vector((0, 0, 1))
        d = d.normalized()
        if abs(d.z) > 0.7:
            # (near-vertical paths: rx stays along world X, ry along Y)
            x = (Vector((1, 0, 0)) - d * d.x).normalized()
            y = d.cross(x).normalized()
            if y.y < 0:
                y = -y
        else:
            x, y = _frame(d)
        ring = []
        for j in range(segs):
            t = 2 * math.pi * j / segs + twist
            ring.append(bm.verts.new(c + x * (math.cos(t) * rx) + y * (math.sin(t) * ry)))
        loops.append(ring)
    for i in range(len(loops) - 1):
        for j in range(segs):
            j1 = (j + 1) % segs
            bm.faces.new((loops[i][j], loops[i][j1], loops[i + 1][j1], loops[i + 1][j]))
    if cap:
        bm.faces.new(list(reversed(loops[0])))
        bm.faces.new(loops[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _new_obj(name, bm)


def ellipsoid(name, centre, radii, segs=16, rings=10, rot=(0, 0, 0), cut=None):
    """A UV sphere scaled to radii; cut=z keeps only the part above that local height (a dome)."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0)
    if cut is not None:
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < cut - 1e-4], context="VERTS")
    m = Matrix.Translation(Vector(centre)) @ _euler(rot) @ Matrix.Diagonal(Vector((*radii, 1.0)))
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return _new_obj(name, bm)


def _euler(rot):
    from mathutils import Euler
    return Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4()


def cyl(name, p0, p1, r0, r1=None, segs=12, cap=True):
    r1 = r0 if r1 is None else r1
    return loft(name, [(p0, r0, r0), (p1, r1, r1)], segs, cap)


def box(name, centre, size, rot=(0, 0, 0), bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    m = Matrix.Translation(Vector(centre)) @ _euler(rot) @ Matrix.Diagonal(Vector((*size, 1.0)))
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    ob = _new_obj(name, bm, smooth=False)
    if bevel > 0:
        mod = ob.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        apply_mods(ob)
    return ob


def torus(name, centre, R, r, axis=(0, 0, 1), segs=16, tube=6, scale=(1, 1, 1)):
    bm = bmesh.new()
    for i in range(segs):
        a = 2 * math.pi * i / segs
        for j in range(tube):
            b = 2 * math.pi * j / tube
            p = Vector(((R + r * math.cos(b)) * math.cos(a), (R + r * math.cos(b)) * math.sin(a), r * math.sin(b)))
            bm.verts.new(p)
    bm.verts.ensure_lookup_table()
    for i in range(segs):
        for j in range(tube):
            a = bm.verts[i * tube + j]
            b = bm.verts[((i + 1) % segs) * tube + j]
            c = bm.verts[((i + 1) % segs) * tube + (j + 1) % tube]
            d = bm.verts[i * tube + (j + 1) % tube]
            bm.faces.new((a, b, c, d))
    rotm = Vector((0, 0, 1)).rotation_difference(Vector(axis).normalized()).to_matrix().to_4x4()
    m = Matrix.Translation(Vector(centre)) @ rotm @ Matrix.Diagonal(Vector((*scale, 1.0)))
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _new_obj(name, bm)


def ribbon(name, path, widths, up=(0, 0, 1), thick=0.006):
    """A flat strip along path points, width per point, facing `up` across; solidified."""
    bm = bmesh.new()
    rows = []
    for i, p in enumerate(path):
        p = Vector(p)
        a = Vector(path[max(0, i - 1)])
        b = Vector(path[min(len(path) - 1, i + 1)])
        d = (b - a).normalized()
        across = Vector(up).normalized()
        w = widths[i] * 0.5
        rows.append((bm.verts.new(p + across * w), bm.verts.new(p - across * w)))
    for i in range(len(rows) - 1):
        bm.faces.new((rows[i][0], rows[i][1], rows[i + 1][1], rows[i + 1][0]))
    ob = _new_obj(name, bm)
    sol = ob.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = thick
    apply_mods(ob)
    return ob


def apply_mods(ob):
    bpy.context.view_layer.objects.active = ob
    for m in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def subsurf(ob, levels=1, smooth=0):
    m = ob.modifiers.new("sub", "SUBSURF")
    m.levels = levels
    m.render_levels = levels
    if smooth:
        s = ob.modifiers.new("smooth", "SMOOTH")
        s.iterations = smooth
        s.factor = 0.5
    apply_mods(ob)
    return ob


def folds(ob, strength=0.006, size=0.05, seed=0):
    """Cloth-like soft displacement (cloud noise along the normals)."""
    tex = bpy.data.textures.new(ob.name + "_folds", "CLOUDS")
    tex.noise_scale = size
    tex.noise_depth = 1
    m = ob.modifiers.new("folds", "DISPLACE")
    m.texture = tex
    m.strength = strength
    m.mid_level = 0.5
    m.texture_coords = "GLOBAL"
    apply_mods(ob)
    return ob


def shade_smooth(ob, angle=50):
    for p in ob.data.polygons:
        p.use_smooth = True
    try:
        bpy.context.view_layer.objects.active = ob
        ob.select_set(True)
        bpy.ops.object.shade_auto_smooth(angle=math.radians(angle))
        ob.select_set(False)
    except Exception:
        pass


# --- paint, slots, weights -----------------------------------------------------------------------

def paint(ob, slot, colour, grad=0.18, ao=0.45, edge=0.0, noise=0.08, flip_grad=False):
    """Tags a piece with its toon slot and its painted look (baked by bake_atlas)."""
    ob["slot"] = slot
    ob["paint"] = json.dumps({"c": list(colour), "grad": grad, "ao": ao, "edge": edge, "noise": noise,
                              "flip": flip_grad})
    return ob


def weigh(ob, fn):
    """Skin weights: fn(world position) -> {bone: weight}."""
    groups = {}
    for v in ob.data.vertices:
        w = fn(ob.matrix_world @ v.co)
        tot = sum(w.values()) or 1.0
        for b, x in w.items():
            if x <= 1e-4:
                continue
            if b not in groups:
                groups[b] = ob.vertex_groups.get(b) or ob.vertex_groups.new(name=b)
            groups[b].add([v.index], x / tot, "REPLACE")
    ob["weighed"] = True
    return ob


def blend(a, b, t):
    """{a: 1-t, b: t}, t clamped."""
    t = max(0.0, min(1.0, t))
    return {a: 1.0 - t, b: t}


def smooth01(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def hexcol(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def _lin(c):
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def _bake_material(ob, img):
    p = json.loads(ob["paint"])
    mat = bpy.data.materials.new(ob.name + "_paint")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emit = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(emit.outputs[0], out.inputs[0])
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    base = _lin(p["c"])
    # painted value structure: light at the top of the part, darker at its foot
    gr = nt.nodes.new("ShaderNodeMapRange")
    gr.inputs[3].default_value = (1.0 + p["grad"] * 0.5) if p["flip"] else (1.0 - p["grad"])
    gr.inputs[4].default_value = (1.0 - p["grad"]) if p["flip"] else (1.0 + p["grad"] * 0.5)
    nt.links.new(sep.outputs[2], gr.inputs[0])
    # ambient occlusion (folds, armpits, under the beret and the plate)
    aon = nt.nodes.new("ShaderNodeAmbientOcclusion")
    aon.inputs["Distance"].default_value = 0.12
    aom = nt.nodes.new("ShaderNodeMapRange")
    aom.inputs[3].default_value = 1.0 - p["ao"]
    aom.inputs[4].default_value = 1.0
    nt.links.new(aon.outputs["AO"], aom.inputs[0])
    # hand-painted variation
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 18.0
    nz.inputs["Detail"].default_value = 3.0
    nzm = nt.nodes.new("ShaderNodeMapRange")
    nzm.inputs[3].default_value = 1.0 - p["noise"]
    nzm.inputs[4].default_value = 1.0 + p["noise"]
    nt.links.new(nz.outputs["Fac"], nzm.inputs[0])
    # edge wear: convex edges lighter (pointiness)
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    edm = nt.nodes.new("ShaderNodeMapRange")
    edm.inputs[1].default_value = 0.5
    edm.inputs[2].default_value = 0.56
    edm.inputs[3].default_value = 1.0
    edm.inputs[4].default_value = 1.0 + p["edge"]
    nt.links.new(geo.outputs["Pointiness"], edm.inputs[0])
    m1 = nt.nodes.new("ShaderNodeMath")
    m1.operation = "MULTIPLY"
    nt.links.new(gr.outputs[0], m1.inputs[0])
    nt.links.new(aom.outputs[0], m1.inputs[1])
    m2 = nt.nodes.new("ShaderNodeMath")
    m2.operation = "MULTIPLY"
    nt.links.new(m1.outputs[0], m2.inputs[0])
    nt.links.new(nzm.outputs[0], m2.inputs[1])
    m3 = nt.nodes.new("ShaderNodeMath")
    m3.operation = "MULTIPLY"
    nt.links.new(m2.outputs[0], m3.inputs[0])
    nt.links.new(edm.outputs[0], m3.inputs[1])
    rgb = nt.nodes.new("ShaderNodeRGB")
    rgb.outputs[0].default_value = (*base, 1.0)
    mix = nt.nodes.new("ShaderNodeVectorMath")
    mix.operation = "SCALE"
    nt.links.new(rgb.outputs[0], mix.inputs[0])
    nt.links.new(m3.outputs[0], mix.inputs["Scale"])
    nt.links.new(mix.outputs[0], emit.inputs[0])
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    nt.nodes.active = tex
    ob.data.materials.clear()
    ob.data.materials.append(mat)


def bake_atlas(objs, path=None, samples=24):
    """One shared UV layout for every piece, then each piece's painted look baked into a 1024 atlas."""
    sc = bpy.context.scene
    heavy = sorted(objs, key=lambda o: -tris([o]))[:40]
    print("WARDENKIT heaviest pieces:", ", ".join("%s %d" % (o.name, tris([o])) for o in heavy))
    img = bpy.data.images.new("atlas", ATLAS_PX, ATLAS_PX, alpha=False)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        if not ob.data.uv_layers:
            ob.data.uv_layers.new(name="UVMap")
        ob.select_set(True)
        _bake_material(ob, img)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004, scale_to_bounds=False)
    bpy.ops.uv.pack_islands(margin=0.003)
    bpy.ops.object.mode_set(mode="OBJECT")
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.render.bake.margin = 6
    bpy.ops.object.bake(type="EMIT")
    if path:
        img.filepath_raw = path
        img.file_format = "PNG"
        img.save()
    else:
        img.pack()          # (the .glb carries it; the game extracts it on import)
    return img


def slot_materials(img):
    mats = {}
    for s in SLOTS:
        m = bpy.data.materials.new(s)
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = img
        m.node_tree.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.8
        if s == "glow":
            m.node_tree.links.new(tex.outputs[0], bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = 1.5
        mats[s] = m
    return mats


def finish(objs, arm, img, name="Body"):
    """Slot materials onto the pieces, joined into one skinned body mesh on the armature."""
    mats = slot_materials(img)
    for ob in objs:
        ob.data.materials.clear()
        ob.data.materials.append(mats[ob["slot"]])
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    body.name = name
    body.data.name = name
    # merge equal slot materials left as duplicates by the join
    bpy.ops.object.material_slot_remove_unused()
    body.parent = arm
    mod = body.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return body, mats


def anchor(arm, bone, name, world):
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    e.parent = arm
    e.parent_type = "BONE"
    e.parent_bone = bone
    bpy.context.view_layer.update()
    e.matrix_world = Matrix.Translation(Vector(world))
    return e


def tris(objs):
    n = 0
    for ob in objs:
        for p in ob.data.polygons:
            n += len(p.vertices) - 2
    return n


def export(path, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=False,
                              export_animations=False, export_skins=True, export_yup=True,
                              export_materials="EXPORT", export_image_format="AUTO", export_extras=False)
