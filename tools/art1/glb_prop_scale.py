"""Scales a prop skinned whole to one bone (a hammer on x_weapon) about that bone's origin, the grip, with no Blender: the
mesh's bind positions and the bone's child anchors (FX points, the thrown pivot) scale by k, so the hand keeps the grip
and every clip, which only turns the bone, keeps its swing arc at the new size. The rig, weights, clips, normals (a
uniform scale) and paint stay byte for byte.
Run: python3 tools/art1/glb_prop_scale.py <in.glb> <out.glb> <mesh> <bone> <k>"""
import sys

import numpy as np

from glb_add_clips import read, write
from kael_retarget import get, set_


def scale(j, b, mesh_name, bone_name, k):
    nodes = j["nodes"]
    bone = next(i for i, n in enumerate(nodes) if n.get("name") == bone_name)
    mesh = next(i for i, m in enumerate(j["meshes"]) if m.get("name") == mesh_name)
    skin = j["skins"][next(n["skin"] for n in nodes if n.get("mesh") == mesh)]
    inv_bind = get(j, b, skin["inverseBindMatrices"]).reshape(-1, 4, 4)[skin["joints"].index(bone)]
    to_bone = inv_bind.T.astype(np.float64)      # glTF matrices are column-major
    to_mesh = np.linalg.inv(to_bone)
    for p in j["meshes"][mesh]["primitives"]:
        acc = p["attributes"]["POSITION"]
        pos = get(j, b, acc)
        local = np.c_[pos, np.ones(len(pos))] @ to_bone.T
        local[:, :3] *= k
        pos = (local @ to_mesh.T)[:, :3].astype(np.float32)
        set_(j, b, acc, pos)
        j["accessors"][acc]["min"], j["accessors"][acc]["max"] = pos.min(0).tolist(), pos.max(0).tolist()
    for c in nodes[bone].get("children", []):
        if "translation" in nodes[c]:
            nodes[c]["translation"] = [v * k for v in nodes[c]["translation"]]


if __name__ == "__main__":
    src, out, mesh_name, bone_name, k = sys.argv[1:6]
    j, b = read(src)
    scale(j, b, mesh_name, bone_name, float(k))
    write(out, j, b)
