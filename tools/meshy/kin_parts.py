"""Cuts a baked Boki mesh (tools/meshy/bake_warden.py's low.glb) into the parts KinPuppet animates, in Blender 4.5:

  ~/tools/blender-4.5.15-linux-x64/blender -b --factory-startup --python tools/meshy/kin_parts.py -- <spec.json>

Meshy's frame is +Z up, facing -Y. The output .glb is a Boki rest pose in the game's frame (ground at y = 0, facing -Z)
with the same node names Models.kin builds for a procedural Boki, so KinPuppet moves it unchanged:
  Hull (the body, head, horn and shell: static), Tail, Ears (EarL, EarR), Legs (Leg0..Leg3: front left, front right,
  rear left, rear right, as seen from the front), each with its origin at its joint so it rotates there.
The spec (art/kin/src/<species>_parts.json): in, out, scale, tex (texture size), tail {y_min, half_width, z_max, pivot},
ears {centres [[x, y, z] ...], r, pivot}, legs {feet [[x, y] ...], z_max, r, hip_z}. Coordinates are Meshy's, where
the game's x is mirrored: list the feet as Leg0..Leg3 = front left, front right, rear left, rear right in the GAME.
"""
import json
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector


def log(*a):
    print("KINPARTS", *a, flush=True)


def load(path):
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    ob = max(meshes, key=lambda m: len(m.data.polygons))
    for o in meshes:
        if o is not ob:
            bpy.data.objects.remove(o)
    ob.parent = None
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return ob


def group_of(c, spec):
    """The part a face centred at c (Meshy's frame) belongs to."""
    t = spec["tail"]
    if c.y > t["y_min"] and abs(c.x) < t["half_width"] and c.z < t["z_max"]:
        return "Tail"
    for i, e in enumerate(spec["ears"]["centres"]):
        if (c - Vector(e)).length < spec["ears"]["r"]:
            return "Ear%d" % i
    lg = spec["legs"]
    if c.z < lg["z_max"]:
        for i, f in enumerate(lg["feet"]):
            if (Vector((c.x, c.y)) - Vector(f)).length < lg["r"]:
                return "Leg%d" % i
    return "Hull"


def split(ob, spec):
    """One object per part, each with its faces and UVs, and its origin moved to its joint."""
    me = ob.data
    names = {}
    for p in me.polygons:
        names.setdefault(group_of(Vector(p.center), spec), []).append(p.index)
    log("faces", {k: len(v) for k, v in names.items()})
    out = {}
    for name, idx in names.items():
        keep = set(idx)
        dup = ob.copy()
        dup.data = me.copy()
        bpy.context.scene.collection.objects.link(dup)
        bm = bmesh.new()
        bm.from_mesh(dup.data)
        bm.faces.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in keep], context="FACES")
        bm.to_mesh(dup.data)
        bm.free()
        dup.name = name
        out[name] = dup
    bpy.data.objects.remove(ob)
    return out


def pivot_of(name, spec):
    if name == "Tail":
        return Vector(spec["tail"]["pivot"])
    if name.startswith("Ear"):
        return Vector(spec["ears"]["pivot"])
    if name.startswith("Leg"):
        f = spec["legs"]["feet"][int(name[3:])]
        return Vector((f[0], f[1], spec["legs"]["hip_z"]))
    return Vector((0, 0, 0))


def to_game(v, s, ground):
    """Meshy's frame to the game's: ground at 0, scaled, turned 180 degrees about the up axis (facing +Y, which the
    glTF export turns into -Z). Still Blender's Z-up here."""
    return Vector((-v.x * s, -v.y * s, (v.z - ground) * s))


def place(objs, spec):
    s = float(spec["scale"])
    ground = min((o.matrix_world @ v.co).z for o in objs.values() for v in o.data.vertices)
    for name, o in objs.items():
        piv = to_game(pivot_of(name, spec), s, ground)
        for v in o.data.vertices:
            v.co = to_game(v.co, s, ground) - piv
        o.location = piv
        o.rotation_euler = (0, 0, 0)
        o.scale = (1, 1, 1)
    return s


def build_tree(objs, spec):
    root = bpy.data.objects.new("Boki", None)
    bpy.context.scene.collection.objects.link(root)
    ears = bpy.data.objects.new("Ears", None)
    legs = bpy.data.objects.new("Legs", None)
    for e in (ears, legs):
        bpy.context.scene.collection.objects.link(e)
        e.parent = root
    ears.location = objs["Ear0"].location
    legs.location = (0, 0, 0)
    for name, o in objs.items():
        if name.startswith("Ear"):
            o.parent = ears
            o.location = (0, 0, 0)
            o.name = "EarL" if name == "Ear0" else "EarR"
        elif name.startswith("Leg"):
            o.parent = legs
        else:
            o.parent = root
    return root


def shrink_texture(ob, tex):
    for mat in ob.data.materials:
        for n in mat.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image:
                n.image.scale(tex, tex)


def main():
    spec = json.load(open(sys.argv[sys.argv.index("--") + 1]))
    ob = load(os.path.expanduser(spec["in"]))
    objs = split(ob, spec)
    s = place(objs, spec)
    root = build_tree(objs, spec)
    for o in objs.values():
        shrink_texture(o, int(spec.get("tex", 2048)))
    bpy.ops.object.select_all(action="SELECT")
    out = os.path.expanduser(spec["out"])
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_yup=True, export_image_format="JPEG",
                              export_jpeg_quality=90, use_selection=True, export_apply=False)
    tris = sum(len(o.data.polygons) for o in objs.values())
    log("wrote", out, "tris", tris, "scale", s)


main()
