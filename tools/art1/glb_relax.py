"""Skin relax on a game Warden .glb (ART-1): skin_relax, the step the v95 swap ends with, run on the .glb the game ships,
for a Hero whose swap work files are gone. Only JOINTS_0 and WEIGHTS_0 are written back: the mesh, clips, anchors and paint
stay byte for byte. The export split vertices at UV and material seams (same place, same weights); they are welded for the
relax, so both copies keep one set of weights and the seam cannot open.
Use: blender -b --factory-startup --python tools/art1/glb_relax.py -- SPEC
SPEC: the Hero's v95 spec (art/wardens/src/<name>_v95.json): "game" is the .glb, "relax" the skin_relax overrides (CUTS 0:
cutting would change the mesh). Blender only (bpy, bmesh, numpy)."""
import json
import os
import struct
import sys

import bmesh
import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import skin_relax

FLOAT, UBYTE = 5126, 5121       # glTF component types of WEIGHTS_0 and JOINTS_0 as the v95 swap exports them


def read_glb(path):
    """[json dict, bin chunk as a bytearray, the bytes before the bin chunk's data (header and json chunk)]."""
    b = open(path, "rb").read()
    n = struct.unpack_from("<I", b, 12)[0]
    return json.loads(b[20:20 + n]), bytearray(b[28 + n:]), b[:28 + n]


def same_order(g, bin_, prims, ob):
    """Asserts the import kept the glTF vertices in order (primitives one after another, Y up turned to Z up)."""
    pos = []
    for pr in prims:
        a = g["accessors"][pr["attributes"]["POSITION"]]
        off = g["bufferViews"][a["bufferView"]].get("byteOffset", 0) + a.get("byteOffset", 0)
        pos.append(np.frombuffer(bin_, np.float32, a["count"] * 3, off).reshape(-1, 3))
    p = np.concatenate(pos)
    co = np.empty(len(ob.data.vertices) * 3)
    ob.data.vertices.foreach_get("co", co)
    assert len(co) == p.size and np.abs(co.reshape(-1, 3) - p[:, [0, 2, 1]] * [1, -1, 1]).max() < 1e-5, ob.name


def weld(ob):
    """Welds each seam's copies (same rest place, same weights) into one vertex; returns [welded index] per glTF vertex."""
    me = ob.data
    names = [g.name for g in ob.vertex_groups]
    keys = [(tuple(np.round(v.co, 6)), tuple(sorted((names[g.group], round(g.weight, 5)) for g in v.groups))) for v in me.vertices]
    first = {}
    keep = [first.setdefault(k, i) for i, k in enumerate(keys)]
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    orig = bm.verts.layers.int.new("orig")
    for v in bm.verts:
        v[orig] = v.index
    bmesh.ops.weld_verts(bm, targetmap={bm.verts[i]: bm.verts[k] for i, k in enumerate(keep) if k != i})
    at = {v[orig]: v.index for v in bm.verts}
    bm.to_mesh(me)
    bm.free()
    me.update()
    print("relax %s: %d verts, %d after the seam weld" % (ob.name, len(keys), len(at)), flush=True)
    return [at[k] for k in keep]


def patch(g, bin_, prims, ob, back, joints):
    """Writes the welded mesh's weights (top 4, normalised) into each primitive's JOINTS_0 and WEIGHTS_0."""
    names = [gr.name for gr in ob.vertex_groups]
    k = 0
    for pr in prims:
        aj, aw = (g["accessors"][pr["attributes"][a]] for a in ("JOINTS_0", "WEIGHTS_0"))
        assert aj["componentType"] == UBYTE and aw["componentType"] == FLOAT and aj["count"] == aw["count"]
        vj, vw = g["bufferViews"][aj["bufferView"]], g["bufferViews"][aw["bufferView"]]
        assert "byteStride" not in vj and "byteStride" not in vw
        oj = vj.get("byteOffset", 0) + aj.get("byteOffset", 0)
        ow = vw.get("byteOffset", 0) + aw.get("byteOffset", 0)
        for i in range(aj["count"]):
            groups = ob.data.vertices[back[k + i]].groups
            gs = sorted(((gr.weight, joints[names[gr.group]]) for gr in groups if gr.weight > 0), reverse=True)
            gs = gs[:skin_relax.MAX_INFL]
            tot = sum(w for w, _ in gs)
            assert tot > 0, (ob.name, k + i)
            gs += [(0.0, 0)] * (4 - len(gs))
            struct.pack_into("<4B", bin_, oj + i * 4, *[j for _, j in gs])
            struct.pack_into("<4f", bin_, ow + i * 16, *[w / tot for w, _ in gs])
        k += aj["count"]
    assert k == len(back)


def main():
    spec_path = sys.argv[sys.argv.index("--") + 1]
    spec = json.load(open(spec_path))
    path = spec["game"]
    for name, v in spec.get("relax", {}).items():
        setattr(skin_relax, name, v)
    assert skin_relax.CUTS == 0, "a cut changes the mesh; glb_relax writes weights only"
    g, bin_, head = read_glb(path)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path, bone_heuristic="BLENDER")
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    skinned = [nd for nd in g["nodes"] if "mesh" in nd and "skin" in nd]
    for nd in skinned:
        same_order(g, bin_, g["meshes"][nd["mesh"]]["primitives"], bpy.data.objects[nd["name"]])
    backs = {nd["name"]: weld(bpy.data.objects[nd["name"]]) for nd in skinned}
    skin_relax.relax(arm)
    for nd in skinned:
        joints = {g["nodes"][j]["name"]: i for i, j in enumerate(g["skins"][nd["skin"]]["joints"])}
        patch(g, bin_, g["meshes"][nd["mesh"]]["primitives"], bpy.data.objects[nd["name"]], backs[nd["name"]], joints)
    with open(path, "wb") as f:
        f.write(head)
        f.write(bin_)
    print("relax wrote", path, flush=True)


main()
