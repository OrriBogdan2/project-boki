"""A talking NPC's game GLB from Meshy's animate output (docs/art/npcs/PIPELINE.md), by its recipe in
tools/meshy/npc_recipes.json: the clips renamed to the NPC's poses, the painted albedo kept (down to "tex" px, JPEG),
the PBR normal and metal/rough maps dropped (the toon shader draws the light), each material named "npc-<id>[-<prop>]".
Props (a Meshy prop GLB each: Hob's mallet, Pell's lantern) ride their own bone, keyed in every clip so the prop moves
rigidly with its carrier bone as if it had been modelled in place at rest; a clip can hand it to another bone and spot
("clips": {"hammer": {"bone": "RightHand", ...}}). A "hang" prop (Pell's lantern) only follows the carrier at its top point
and stays upright, as if it hung from the hand by its ring.
The recipe's "anims" are Meshy animate outputs of one rig task (their clips are merged), its props' "glb" files sit
beside them in <src dir>.
Run: blender -b --factory-startup --python tools/meshy/npc_bake.py -- <src dir> <out.glb> <id>
"""
import json
import math
import os
import sys

import bpy
from mathutils import Euler, Matrix, Vector

RECIPES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "npc_recipes.json")
PROP_TEX = 512      # px: a prop's albedo


def main(src, out, nid):
    rec = json.load(open(RECIPES))[nid]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(src, rec["anims"][0]))
    arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    for o in [o for o in bpy.context.scene.objects if o.type == "MESH" and not o.data.materials]:
        bpy.data.objects.remove(o)      # (the importer's bone-shape icosphere)
    for more in rec["anims"][1:]:       # (the same rig: only its clips are kept)
        keep = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(src, more))
        for o in [o for o in bpy.data.objects if o not in keep]:
            bpy.data.objects.remove(o)
    for m in [m for m in bpy.data.meshes if not m.users]:
        bpy.data.meshes.remove(m)
    for m in [m for m in bpy.data.materials if not m.users]:
        bpy.data.materials.remove(m)
    _rename_clips(rec["clips"])
    _flatten_materials(list(bpy.data.materials), "npc-" + nid, nid + "_albedo", rec.get("tex", 2048))
    for name, p in rec.get("props", {}).items():
        _prop(arm, nid, name, p, os.path.join(src, p["glb"]))
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_image_format="JPEG",
                              export_jpeg_quality=90, export_animation_mode="ACTIONS", export_yup=True)
    print("baked", out, sorted(a.name for a in bpy.data.actions))


def _rename_clips(names):
    """Meshy's clip names -> poses ({"Idle": "idle", ...}); clips not named are dropped."""
    for a in list(bpy.data.actions):
        for k, v in names.items():
            if k in a.name.split("|"):
                a.name = v
                break
        else:
            bpy.data.actions.remove(a)


def _flatten_materials(mats, mat_name, img_name, tex):
    for m in mats:
        if not m.use_nodes:
            continue
        m.name = mat_name
        nt = m.node_tree
        bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        for sock in ("Normal", "Metallic", "Roughness"):
            for link in list(bsdf.inputs[sock].links):
                nt.links.remove(link)
        bsdf.inputs["Metallic"].default_value = 0.0
        bsdf.inputs["Roughness"].default_value = 1.0
        for _ in range(3):      # (a map's image node goes once the node it fed has gone)
            for n in list(nt.nodes):
                if n.type in ("TEX_IMAGE", "NORMAL_MAP", "SEPARATE_COLOR", "SEPRGB") and not any(o.links for o in n.outputs):
                    nt.nodes.remove(n)
        for n in nt.nodes:
            if n.type == "TEX_IMAGE" and n.image:
                if n.image.size[0] > tex:
                    n.image.scale(tex, tex)
                n.image.name = img_name


def _place(p, arm):
    """A spot ({"at": [x, y, z] m in the model's rest space (Z up, faces -Y), "rot": [x, y, z] degrees}) -> armature space."""
    w = Matrix.Translation(Vector(p["at"])) @ Euler([math.radians(r) for r in p.get("rot", [0, 0, 0])]).to_matrix().to_4x4()
    return arm.matrix_world.inverted() @ w


def _prop(arm, nid, name, p, path):
    """Imports a prop, sizes it ("size": m along its longest side, centred on its bounds), skins it to its own bone
    and keys that bone in every clip to follow the carrier bone ("bone"), or a clip's own bone and spot."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    _flatten_materials({s.material for o in meshes for s in o.material_slots if s.material},
                       "npc-%s-%s" % (nid, name), "%s_%s_albedo" % (nid, name), PROP_TEX)
    pts = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
    lo = Vector([min(q[i] for q in pts) for i in range(3)])
    hi = Vector([max(q[i] for q in pts) for i in range(3)])
    norm = Matrix.Scale(p["size"] / max(hi - lo), 4) @ Matrix.Translation(-(lo + hi) / 2)
    rest = _place(p, arm)                                  # the prop's spot at rest, armature space
    top = rest @ Vector((0, 0, (hi - lo).z * p["size"] / max(hi - lo) / 2))      # its top point (a "hang" prop's ring)
    for o in meshes:
        o.data.transform(arm.matrix_world @ rest @ norm @ o.matrix_world)
        o.matrix_world = Matrix()
    for o in new:
        if o.type != "MESH":
            bpy.data.objects.remove(o)
    bpy.context.view_layer.objects.active = meshes[0]
    for o in meshes:
        o.select_set(True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    mesh = meshes[0]
    mesh.name = "%s_%s" % (nid, name)
    if len(mesh.data.polygons) > p.get("faces", 1e9):
        dec = mesh.modifiers.new("Decimate", "DECIMATE")
        dec.ratio = p["faces"] / len(mesh.data.polygons)
        bpy.context.view_layer.objects.active = mesh
        bpy.ops.object.modifier_apply(modifier=dec.name)
    bone = "prop_" + name
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones.new(bone)
    eb.head, eb.tail, eb.roll = (0, 0, 0), (0, 10, 0), 0.0       # rest = identity in armature space
    bpy.ops.object.mode_set(mode="OBJECT")
    mesh.parent = arm
    mesh.matrix_parent_inverse = arm.matrix_world.inverted()
    mesh.vertex_groups.new(name=bone).add(range(len(mesh.data.vertices)), 1.0, "REPLACE")
    mesh.modifiers.new("Armature", "ARMATURE").object = arm
    pb = arm.pose.bones[bone]
    pb.rotation_mode = "QUATERNION"
    sc = bpy.context.scene
    for act in bpy.data.actions:
        spec = p.get("clips", {}).get(act.name, {})
        carrier = arm.pose.bones[spec.get("bone", p["bone"])]
        spot = _place(spec, arm) if spec else rest
        off = carrier.bone.matrix_local.inverted() @ spot @ rest.inverted()     # (the mesh is already at rest)
        arm.animation_data.action = act
        if hasattr(arm.animation_data, "action_slot") and act.slots:
            arm.animation_data.action_slot = act.slots[0]
        f0, f1 = (int(round(x)) for x in act.frame_range)
        for f in range(f0, f1 + 1):
            sc.frame_set(f)
            if p.get("hang"):
                pb.matrix_basis = Matrix.Translation(carrier.matrix @ carrier.bone.matrix_local.inverted() @ top - top)
            else:
                pb.matrix_basis = carrier.matrix @ off
            for path in ("location", "rotation_quaternion", "scale"):
                pb.keyframe_insert(path, frame=f, group=bone)
    print("prop", name, "on", p["bone"], len(mesh.data.polygons), "faces")


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:]
    main(argv[0], argv[1], argv[2])
