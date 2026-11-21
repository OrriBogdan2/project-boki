"""Blender half of the two-rigger pilot (tools/meshy/rig_pilot.py, docs/art/wardens/RIG_GATE.md), Blender 4.5:

  blender -b --factory-startup --python tools/blender/rig_pilot.py -- static  <rigged.glb> <out.glb> [turn_deg]
  blender -b --factory-startup --python tools/blender/rig_pilot.py -- autoweight <rigged.glb> <out.json> [fingers]

static: the hunter's body mesh with no skin (bind pose; the weapon object `hammer` left out: a rigger reads a humanoid
from the body alone), turned `turn_deg` (Meshy wants +Z facing), for a rigger.
autoweight: Blender's own automatic (bone heat) weights of the glb's body vertices on its contract armature
(RIG_CONTRACT bones; the finger bones too when `fingers`), written as {"pos": [[x, y, z]], "w": [{bone: weight}]} in
the glb's own (glTF, Y up) frame, for tools/meshy/rig_pilot.py to patch into the glb.
"""
import json
import math
import sys

import bpy
from mathutils import Matrix

BODY = ("hips", "head", "upper_arm", "forearm", "hand", "thigh", "shin")
FINGER = ("x_fing", "x_thumb", "x_foot")


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def meshes():
    return [o for o in bpy.data.objects if o.type == "MESH"]


def joined():
    ms = meshes()
    bpy.ops.object.select_all(action="DESELECT")
    for o in ms:
        o.select_set(True)
    bpy.context.view_layer.objects.active = ms[0]
    if len(ms) > 1:
        bpy.ops.object.join()
    return bpy.context.view_layer.objects.active


def static(src, dst, turn):
    clear()
    bpy.ops.import_scene.gltf(filepath=src)
    for o in meshes():
        if o.name.startswith("hammer"):
            bpy.data.objects.remove(o)
    for o in meshes():  # apply the rest transforms, drop the armature
        for m in list(o.modifiers):
            o.modifiers.remove(m)
        o.vertex_groups.clear()
        o.parent = None
    for o in list(bpy.data.objects):
        if o.type == "ARMATURE":
            bpy.data.objects.remove(o)
    ob = joined()
    ob.matrix_world = Matrix.Rotation(math.radians(turn), 4, "Y") @ ob.matrix_world
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", use_selection=True, export_yup=True)
    print("RIGPILOT static", len(ob.data.vertices), "verts ->", dst)


def autoweight(src, dst, fingers):
    clear()
    bpy.ops.import_scene.gltf(filepath=src)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    use = [b.name for b in arm.data.bones if b.name.split(".")[0] in BODY or (fingers and b.name.split(".")[0] in FINGER)]
    ob = joined()
    # the body = vertices whose heaviest group is a body bone; the rest (weapon, cloth, hair) is not re-skinned
    groups = {g.index: g.name for g in ob.vertex_groups}
    body = []
    for v in ob.data.vertices:
        gs = sorted(v.groups, key=lambda g: -g.weight)
        if gs and groups[gs[0].group].split(".")[0] in BODY + FINGER:
            body.append(v.index)
    ob.vertex_groups.clear()
    for m in list(ob.modifiers):
        ob.modifiers.remove(m)
    bpy.ops.object.mode_set(mode="OBJECT")
    # a separate object of the body vertices only, auto-weighted on the deform bones alone
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="DESELECT")
    bpy.ops.object.mode_set(mode="OBJECT")
    for i in body:
        ob.data.vertices[i].select = True
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.separate(type="SELECTED")
    bpy.ops.object.mode_set(mode="OBJECT")
    part = [o for o in meshes() if o is not ob][0]
    # bone heat needs a watertight mesh: weight a voxel-remeshed copy; rig_pilot.py takes the nearest vertex of it
    bpy.context.view_layer.objects.active = part
    mod = part.modifiers.new("remesh", "REMESH")
    mod.mode, mod.voxel_size, mod.use_smooth_shade = "VOXEL", 0.016, True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    mw = part.matrix_world.copy()
    part.parent = None
    part.matrix_world = mw
    part.vertex_groups.clear()
    for m in list(part.modifiers):
        part.modifiers.remove(m)
    for b in arm.data.bones:
        b.use_deform = b.name in use
    print("RIGPILOT deform bones", len(use), "arm scale", tuple(arm.scale), "part verts", len(part.data.vertices))
    bpy.ops.object.select_all(action="DESELECT")
    part.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    print("RIGPILOT groups", len(part.vertex_groups), "parent", part.parent and part.parent.name, [m.type for m in part.modifiers])
    pos, ws = [], []
    names = {g.index: g.name for g in part.vertex_groups}
    for v in part.data.vertices:
        pos.append(list(part.matrix_world @ v.co))
        ws.append({names[g.group]: g.weight for g in v.groups if g.weight > 1e-4})
    # Blender is Z up: back to glTF's Y up (x, z, -y)
    pos = [[p[0], p[2], -p[1]] for p in pos]
    json.dump({"pos": pos, "w": ws}, open(dst, "w"))
    n_empty = sum(1 for w in ws if not w)
    print("RIGPILOT autoweight", len(ws), "body verts,", n_empty, "unweighted ->", dst)


if __name__ == "__main__":
    a = sys.argv[sys.argv.index("--") + 1 :]
    if a[0] == "static":
        static(a[1], a[2], float(a[3]) if len(a) > 3 else 0.0)
    elif a[0] == "autoweight":
        autoweight(a[1], a[2], len(a) > 3 and a[3] == "fingers")
