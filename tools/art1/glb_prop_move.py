"""Moves a part skinned whole to one bone (Sparkle's gum bubble on `gum`), with that bone, so the bone's head lands on a
point (glTF scene metres, Y up), with no Blender. The part's bind positions, the bone's rest translation, its inverse bind
and every clip's translation keys on it shift by the same offset, so each clip (Sparkle's gum only scales the bubble)
plays as before, about the new spot; child anchors ride the bone. Weights, normals, paint and every other bone stay byte
for byte. A target is a point, not an offset, so the step can run again on a .glb that has had it.
Run: python3 tools/art1/glb_prop_move.py <in.glb> <out.glb> <mesh> <bone> <x> <y> <z>"""

import sys

import numpy as np

from glb_add_clips import read, write
from kael_retarget import get, set_


def _local(n):
    """A node's TRS as a 4x4 (column vectors)."""
    x, y, z, w = n.get("rotation", [0.0, 0.0, 0.0, 1.0])
    r = np.array(
        [
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
        ]
    )
    m = np.eye(4)
    m[:3, :3] = r * np.array(n.get("scale", [1.0, 1.0, 1.0]))
    m[:3, 3] = n.get("translation", [0.0, 0.0, 0.0])
    return m


def move(j, b, mesh_name, bone_name, to):
    nodes = j["nodes"]
    parent = {c: i for i, n in enumerate(nodes) for c in n.get("children", [])}

    def world(i):
        m = _local(nodes[i])
        while i in parent:
            i = parent[i]
            m = _local(nodes[i]) @ m
        return m

    bone = next(i for i, n in enumerate(nodes) if n.get("name") == bone_name)
    assert "matrix" not in nodes[bone] and bone in parent
    mesh = next(i for i, m in enumerate(j["meshes"]) if m.get("name") == mesh_name)
    skin = j["skins"][next(n["skin"] for n in nodes if n.get("mesh") == mesh)]
    joint = skin["joints"].index(bone)
    g = world(bone)
    d = np.asarray(to, np.float64) - g[:3, 3]
    g2 = g.copy()
    g2[:3, 3] += d
    old = np.array(nodes[bone].get("translation", [0.0, 0.0, 0.0]))
    new = (np.linalg.inv(world(parent[bone])) @ g2)[:3, 3]
    nodes[bone]["translation"] = new.tolist()
    ibm = get(j, b, skin["inverseBindMatrices"]).astype(np.float64)
    ibm[joint] = np.linalg.inv(g2).T.reshape(16)  # (column-major)
    set_(j, b, skin["inverseBindMatrices"], ibm.astype(np.float32))
    moved = 0
    for p in j["meshes"][mesh]["primitives"]:
        at = p["attributes"]
        on = (get(j, b, at["WEIGHTS_0"]) * (get(j, b, at["JOINTS_0"]) == joint)).sum(1)
        hit = on > 1e-3
        assert np.allclose(on[hit], 1.0, atol=1e-3), "%s is not skinned whole to %s" % (mesh_name, bone_name)
        xyz = get(j, b, at["POSITION"]).astype(np.float64)
        xyz[hit] += d
        out = xyz.astype(np.float32)
        set_(j, b, at["POSITION"], out)
        j["accessors"][at["POSITION"]]["min"], j["accessors"][at["POSITION"]]["max"] = (
            out.min(0).tolist(),
            out.max(0).tolist(),
        )
        moved += int(hit.sum())
    users = {}
    for an in j.get("animations", []):
        for ch in an["channels"]:
            tg = ch["target"]
            users.setdefault(an["samplers"][ch["sampler"]]["output"], set()).add((tg.get("node"), tg["path"]))
    keyed = set()
    for an in j.get("animations", []):
        for ch in an["channels"]:
            if ch["target"].get("node") != bone or ch["target"]["path"] != "translation":
                continue
            acc = an["samplers"][ch["sampler"]]["output"]
            assert users[acc] == {(bone, "translation")}, "a key track is shared with another channel"
            if acc in keyed:
                continue
            keys = get(j, b, acc).astype(np.float64) + (new - old)
            set_(j, b, acc, keys.astype(np.float32))
            if "min" in j["accessors"][acc]:
                j["accessors"][acc]["min"], j["accessors"][acc]["max"] = keys.min(0).tolist(), keys.max(0).tolist()
            keyed.add(acc)
    return d, moved, len(keyed)


if __name__ == "__main__":
    src, dst, mesh_name, bone_name = sys.argv[1:5]
    j, b = read(src)
    d, n, k = move(j, b, mesh_name, bone_name, [float(v) for v in sys.argv[5:8]])
    print("%s on %s moved by %s m: %d vertices, %d key tracks" % (mesh_name, bone_name, np.round(d, 4).tolist(), n, k))
    write(dst, j, b)
