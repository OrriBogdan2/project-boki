"""Scales a prop skinned whole to one bone (the hammer on x_weapon) about that bone's origin, the grip, to a length (m: the
longest side of its box, as --warden-clips-check measures it), with no Blender. The mesh's bind positions and the bone's
child anchors (FX points, the thrown frame) scale, so the hand keeps the grip and every clip, which only turns the bone,
keeps its swing arc at the new size. The rig, weights, clips, normals (a uniform scale) and paint stay byte for byte. A
prop at the length already keeps its size, so the step can run again on a .glb that has had it.
Run: python3 tools/art1/glb_prop_scale.py <in.glb> <out.glb> <mesh> <bone> <length m>"""

import sys

import numpy as np

from glb_add_clips import read, write
from kael_retarget import get, set_


def scale(j, b, mesh_name, bone_name, length):
    nodes = j["nodes"]
    bone = next(i for i, n in enumerate(nodes) if n.get("name") == bone_name)
    mesh = next(i for i, m in enumerate(j["meshes"]) if m.get("name") == mesh_name)
    skin = j["skins"][next(n["skin"] for n in nodes if n.get("mesh") == mesh)]
    joint = skin["joints"].index(bone)
    to_bone = get(j, b, skin["inverseBindMatrices"]).reshape(-1, 4, 4)[joint].T.astype(np.float64)  # (column-major)
    prims = j["meshes"][mesh]["primitives"]
    for p in prims:  # (a vertex partly on another bone would tear away from it)
        on = get(j, b, p["attributes"]["WEIGHTS_0"]) * (get(j, b, p["attributes"]["JOINTS_0"]) == joint)
        assert np.allclose(on.sum(1), 1.0, atol=1e-3), "%s is not skinned whole to %s" % (mesh_name, bone_name)
    pos = [get(j, b, p["attributes"]["POSITION"]).astype(np.float64) for p in prims]
    k = length / np.ptp(np.concatenate(pos), 0).max()
    for p, xyz in zip(prims, pos):
        local = np.c_[xyz, np.ones(len(xyz))] @ to_bone.T
        local[:, :3] *= k
        out = (local @ np.linalg.inv(to_bone).T)[:, :3].astype(np.float32)
        acc = p["attributes"]["POSITION"]
        set_(j, b, acc, out)
        j["accessors"][acc]["min"], j["accessors"][acc]["max"] = out.min(0).tolist(), out.max(0).tolist()
    for c in nodes[bone].get("children", []):
        assert c not in skin["joints"], "a bone rides %s: its bind would have to move too" % bone_name
        if "translation" in nodes[c]:
            nodes[c]["translation"] = [v * k for v in nodes[c]["translation"]]
    return k


if __name__ == "__main__":
    src, dst, mesh_name, bone_name, length = sys.argv[1:6]
    j, b = read(src)
    print("%s x%.4f about %s" % (mesh_name, scale(j, b, mesh_name, bone_name, float(length)), bone_name))
    write(dst, j, b)
