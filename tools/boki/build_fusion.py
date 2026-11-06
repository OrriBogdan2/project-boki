"""Builds a Boki's Fusion parts (what it becomes on a Hunter): art/kin/<id>/<id>_fusion.glb.

  blender -b --factory-startup --python tools/boki/build_fusion.py
"""
import os
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import boki_rig
import boki_sdf
import build_boki as bb
import importlib

ATLAS_PX = 1024
MODULES = {"cindle": "vespyx_fusion", "puddlet": "prismander_fusion", "burrlet": "mycroll_fusion",
           "zephyrak": "zephyrak_fusion", "wisplet": "lunowl_fusion"}
fusion = None


def paint_atlas(pieces, verts, tris, piece_of, uv):
    nrm = bb.vertex_normals(verts, tris)
    tri_uv = np.arange(len(tris) * 3).reshape(-1, 3)
    xs, ys, tid, bary = bb.rasterize(uv, tri_uv, ATLAS_PX)
    tv = tris[tid]
    pos = (verts[tv] * bary[..., None]).sum(1)
    nor = (nrm[tv] * bary[..., None]).sum(1)
    nor /= np.maximum(np.linalg.norm(nor, axis=1, keepdims=True), 1e-9)
    owner = piece_of[tv[:, 0]]
    col = np.ones((len(pos), 3))
    for i, pc in enumerate(pieces):
        m = owner == i
        if m.any():
            col[m] = fusion.paint_piece(pc.look, pos[m], nor[m], pc.shape.prims)
    img = np.zeros((ATLAS_PX, ATLAS_PX, 3))
    mask = np.zeros((ATLAS_PX, ATLAS_PX), dtype=bool)
    img[ys, xs] = col
    mask[ys, xs] = True
    return bb.dilate(img, mask)


def main():
    global fusion
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    species = next((a[10:] for a in argv if a.startswith("--species=")), "cindle")
    bb.use_species(species)
    fusion = importlib.import_module(MODULES[species])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    boki_rig.HIDE_AT.clear()
    pieces = []
    boki_rig.CLIP_SCALE = 1.0
    for name, (shape, tris, slot, look) in fusion.parts().items():
        v, q = boki_sdf.mesh_shape(shape, 0.005)
        v, t = bb.decimated(v, q, tris)
        pc = bb.Piece(name, shape, v, t, slot, prop=name in getattr(fusion, "HARD", ()))
        pc.look = look
        pieces.append(pc)
    verts, tris, piece_of = bb.join(pieces)
    bb.SCALE = 1.0
    obj = bb.mesh_object("Fusion", verts, tris)
    uv = bb.uv_unwrap(obj)
    atlas = paint_atlas(pieces, verts, tris, piece_of, uv)
    obj.data.materials.append(bb.material("boki_coat", bb.image_from(species + "_fusion_atlas", atlas)))
    obj.data.materials.append(bb.material("boki_glow", color=(0.45, 1.0, 0.1, 1.0)))
    obj.data.materials.append(bb.material("boki_lit", obj.data.materials[0].node_tree.nodes["Image Texture"].image))
    slots = np.array([pieces[piece_of[t[0]]].slot for t in tris])
    obj.data.polygons.foreach_set("material_index", slots.tolist())
    arm = boki_rig.armature(fusion.bones(), bb.bl)
    boki_rig.skin_only(obj, arm, pieces)
    boki_rig.make_clips(arm, fusion.CLIPS)
    boki_rig.export(os.path.join(bb.REPO, "art/kin", bb.SPECIES, bb.SPECIES + "_fusion.glb"))


if __name__ == "__main__":
    main()
