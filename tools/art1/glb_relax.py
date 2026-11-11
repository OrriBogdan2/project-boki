"""Relaxes the skin weights of a shipped Hero .glb in place (skin_relax.relax, no cuts) when its build blend or master is not at hand.
Blender reads the .glb and welds every vertex that shares a position (a UV seam or a two-sided layer keeps one set of weights; the
importer's own merge keeps vertices whose normals differ apart) and relaxes them against every clip; then only the
JOINTS_0 and WEIGHTS_0 bytes of each skinned primitive are written back, so the clips, meshes, textures and JSON stay byte for byte.
Settings: a v95 spec's "relax" object (as v95_swap.py reads it) or the same object inline; CUTS is forced to 0 (a cut changes the mesh).
Run: blender -b --factory-startup --python tools/art1/glb_relax.py -- <hero.glb> <spec.json | '{"MAX_ITER": 200}'> [out.glb]"""
import json
import os
import struct
import sys

import bmesh
import bpy
import numpy as np
from mathutils import kdtree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import skin_relax  # noqa: E402

WELD = 1e-5          # m: a glTF vertex must sit this close to the merged Blender vertex it takes its weights from


def accessor_view(j, i):
    """(byte offset in the BIN chunk, element count) of accessor i, tightly packed."""
    a = j["accessors"][i]
    v = j["bufferViews"][a["bufferView"]]
    assert v.get("byteStride") in (None, 4, 16), "interleaved skin data"
    return v.get("byteOffset", 0) + a.get("byteOffset", 0), a["count"]


def patch(path, out):
    raw = bytearray(open(path, "rb").read())
    n = struct.unpack_from("<I", raw, 12)[0]
    j = json.loads(raw[20:20 + n])
    base = 20 + n + 8                                      # the BIN chunk's data
    slot = {j["nodes"][ni]["name"]: k for k, ni in enumerate(j["skins"][0]["joints"])}
    meshes = {o.data.name: o for o in bpy.data.objects if o.type == "MESH" and o.find_armature()}
    arm = next(iter(meshes.values())).find_armature()
    for m in j["meshes"]:
        prims = [p for p in m["primitives"] if "JOINTS_0" in p["attributes"]]
        if not prims:
            continue
        s = skin_relax.Skin(meshes[m["name"]], arm)
        names = arm.data.bones.keys()
        top = np.argsort(-s.w, axis=1)[:, :4]
        wt = np.take_along_axis(s.w, top, 1)
        wt = (wt / np.maximum(wt.sum(1, keepdims=True), 1e-9)).astype("<f4")
        joints = np.vectorize(lambda b: slot[names[b]])(top).astype(np.uint8)
        joints[wt == 0] = 0
        tree = kdtree.KDTree(len(s.rest))
        co = meshes[m["name"]].data.vertices
        for i, v in enumerate(co):
            tree.insert(v.co, i)
        tree.balance()
        for p in prims:
            at, count = accessor_view(j, p["attributes"]["POSITION"])
            pos = np.frombuffer(raw, "<f4", count * 3, base + at).reshape(-1, 3)
            ja, _ = accessor_view(j, p["attributes"]["JOINTS_0"])
            wa, _ = accessor_view(j, p["attributes"]["WEIGHTS_0"])
            pick = []
            for x, y, z in pos:
                c, i, d = tree.find((x, -z, y))           # glTF y-up to Blender z-up
                assert d < WELD, "no merged vertex at %s" % c
                pick.append(i)
            raw[base + ja:base + ja + count * 4] = joints[pick].tobytes()
            raw[base + wa:base + wa + count * 16] = wt[pick].tobytes()
        print("glb_relax %s: %d primitives rewritten" % (m["name"], len(prims)), flush=True)
    open(out, "wb").write(raw)


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    glb = args[0]
    relax = json.loads(args[1]) if args[1].startswith("{") else json.load(open(args[1])).get("relax", {})
    for k, v in relax.items():
        setattr(skin_relax, k, v)
    skin_relax.CUTS = 0
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb, merge_vertices=True)
    for o in bpy.data.objects:
        if o.type == "MESH" and o.find_armature():
            bm = bmesh.new()
            bm.from_mesh(o.data)
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=WELD)
            bm.to_mesh(o.data)
            bm.free()
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    skin_relax.relax(arm)
    patch(glb, args[2] if len(args) > 2 else glb)


main()
