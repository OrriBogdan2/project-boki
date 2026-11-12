"""Shared bpy helpers for the Warden models (docs/art/wardens/RIG_CONTRACT.md, PIPELINE.md): the contract
armature from a rig JSON (`godot --headless -- --warden-rig-json`), anchors, triangle counts and the .glb
export. tools/meshy/fit_warden.py fits a Meshy model with them.

Coordinates: the rig JSON is Godot model space (+Y up, facing -Z); here Blender's (+Z up), the Warden facing
+Y: g2b() converts. The glTF exporter's +Y-up conversion turns it back.
"""
import json

import bpy
from mathutils import Matrix, Vector

SLOTS = ["skin", "hair", "cloth", "leather", "metal", "eyes", "team", "glow", "ice"]
BONE_LEN = {"root": 0.12, "hips": 0.2, "head": 0.25, "pauldron.L": 0.1, "pauldron.R": 0.1, "skirt": 0.1,
            "scarf": 0.12, "hand.L": 0.08, "hand.R": 0.08, "shin.L": 0.3, "shin.R": 0.3}


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




def hexcol(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


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


def export(path, objs, image_format="AUTO", colors=False):
    """colors: each mesh's active colour attribute goes out as COLOR_0 (fit_warden's ink room)."""
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=False,
                              export_animations=False, export_skins=True, export_yup=True,
                              export_materials="EXPORT", export_image_format=image_format,
                              export_jpeg_quality=92, export_extras=False,
                              export_vertex_color="ACTIVE" if colors else "MATERIAL")
