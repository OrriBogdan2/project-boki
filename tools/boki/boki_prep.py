"""Puts a finished Meshy model where boki_meshy.Meshy reads it: ~/meshy/boki/<id>/dex/glb.glb and tex0_base_color.png
(the model's own base-colour image), and prints its size in game metres (EXT json: height, half width x, nose z, tail z).

  blender -b --factory-startup --python tools/boki/boki_prep.py -- <id> <model.glb>
"""
import json
import os
import shutil
import sys

import bpy
import numpy as np

ROOT = os.path.expanduser("~/meshy/boki")


def base_colour_image(obj):
    for slot in obj.material_slots:
        nodes = slot.material.node_tree.nodes if slot.material and slot.material.use_nodes else []
        for n in nodes:
            if n.type == "TEX_IMAGE" and n.image is not None:
                return n.image
    raise SystemExit("no base-colour image on the model")


def main(species, glb):
    run = os.path.join(ROOT, species, "dex")
    os.makedirs(run, exist_ok=True)
    bpy.ops.import_scene.gltf(filepath=glb)
    obj = max((o for o in bpy.data.objects if o.type == "MESH"), key=lambda o: len(o.data.vertices))
    v = np.zeros(len(obj.data.vertices) * 3)
    obj.data.vertices.foreach_get("co", v)
    m = np.array(obj.matrix_world)
    w = v.reshape(-1, 3) @ m[:3, :3].T + m[:3, 3]
    g = np.stack([-w[:, 0], w[:, 2], w[:, 1]], -1)  # game axes, facing -Z (boki_meshy.Meshy)
    g[:, 1] -= g[:, 1].min()
    tex = os.path.join(run, "tex0_base_color.png")
    if not os.path.exists(tex):  # files already in place are never overwritten
        img = base_colour_image(obj)
        img.filepath_raw = tex
        img.file_format = "PNG"
        img.save()
    if not os.path.exists(os.path.join(run, "glb.glb")):
        shutil.copyfile(glb, os.path.join(run, "glb.glb"))
    h = g[:, 1].max()
    print("EXT", json.dumps({"tris": len(obj.data.polygons), "h": round(h, 4), "w": round(float(np.ptp(g[:, 0]) / 2), 4),
                             "zf": round(float(g[:, 2].min() / h), 4), "zb": round(float(g[:, 2].max() / h), 4),
                             "zc": round(float(g[:, 2].mean() / h), 4)}))


main(sys.argv[sys.argv.index("--") + 1], sys.argv[sys.argv.index("--") + 2])
