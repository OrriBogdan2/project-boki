"""Relaxes the skin weights of a finished Warden .glb (skin_relax, no cuts) and writes them back into a copy of it.
Everything but JOINTS_0 and WEIGHTS_0 stays byte for byte as it was: triangles, clips, anchors, materials, atlas.
For a model whose pipeline never ran skin_relax (docs/DEBT.md "Skin stretch") and cannot be rebuilt.
Run: blender -b --python tools/art1/glb_relax.py -- <in.glb> <out.glb> [NAME=value ...]   (NAME: a skin_relax constant, e.g. LIMIT=1.15)
Blender imports every glTF vertex as it is (no merge), so it measures the same edges the game does, including the ones
across a UV seam. The vertices that sit at one point with the same weights (a seam's two sides) relax as one. The result is
looked up per glTF vertex by position (and weights), and only vertices whose weights changed are written."""
import json
import os
import struct
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import skin_relax

CELL = 1e-3          # m: grid of the position lookup
SAME = 1e-4          # m: a glTF vertex and the Blender vertex it maps to may not be farther apart than this


def read(path):
    b = open(path, "rb").read()
    n = struct.unpack("<I", b[12:16])[0]
    at = 20 + n
    m = struct.unpack("<I", b[at:at + 4])[0]
    return json.loads(b[20:at]), b[20:at], bytearray(b[at + 8:at + 8 + m])


def accessor(j, blob, i):
    """(array [count, comps], byte offset, byte stride) of accessor i; the view's stride is honoured."""
    a = j["accessors"][i]
    v = j["bufferViews"][a["bufferView"]]
    comps = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
    dt = {5121: np.uint8, 5123: np.uint16, 5126: np.float32}[a["componentType"]]
    size = comps * np.dtype(dt).itemsize
    stride = v.get("byteStride", size)
    off = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    raw = np.frombuffer(blob, np.uint8, count=stride * (a["count"] - 1) + size, offset=off)
    rows = np.lib.stride_tricks.as_strided(raw, (a["count"], size), (stride, 1))
    return rows.copy().view(dt).reshape(a["count"], comps), off, stride


def lookup(co):
    """{cell: [vertex indices]} of the Blender vertices (glTF space)."""
    grid = {}
    for i, c in enumerate(np.floor(co / CELL).astype(int).tolist()):
        grid.setdefault(tuple(c), []).append(i)
    return grid


def nearest(grid, co, p, row, old):
    """The Blender vertex at p and its distance; of several at one point (their weights differ), the one whose weights were `row`."""
    c = np.floor(p / CELL).astype(int)
    best, key = -1, (True, 1e9)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for dz in (-1, 0, 1):
                for i in grid.get((c[0] + dx, c[1] + dy, c[2] + dz), ()):
                    d = np.abs(co[i] - p).max()
                    k = (d > SAME, d if d > SAME else np.abs(old[i] - row).sum())
                    if k < key:
                        best, key = i, k
    return best, np.abs(co[best] - p).max()


def weld(relax_once):
    """skin_relax's relax_once, then every set of vertices that began at one point with one set of weights averaged back to one."""
    def welded(self, bad_edges):
        if not hasattr(self, "same"):
            key = np.c_[np.round(self.rest / SAME), np.round(self.w, 3)]
            self.same = np.unique(key, axis=0, return_inverse=True)[1].ravel()
        relax_once(self, bad_edges)
        total = np.zeros((self.same.max() + 1, self.w.shape[1]))
        np.add.at(total, self.same, self.w)
        self.w = (total / np.bincount(self.same)[:, None])[self.same]
    return welded


def weights(ob, bones):
    w = np.zeros((len(ob.data.vertices), len(bones)))
    for v in ob.data.vertices:
        for g in v.groups:
            name = ob.vertex_groups[g.group].name
            if name in bones:
                w[v.index, bones.index(name)] = g.weight
    return w


def main(src, dst, over):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src, merge_vertices=False)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    bones = arm.data.bones.keys()
    meshes = {o.name: o for o in bpy.data.objects if o.type == "MESH" and any(m.type == "ARMATURE" for m in o.modifiers)}
    before = {n: weights(o, bones) for n, o in meshes.items()}
    for k, v in over.items():
        setattr(skin_relax, k, type(getattr(skin_relax, k))(v))
    skin_relax.CUTS = 0
    skin_relax.Skin.relax_once = weld(skin_relax.Skin.relax_once)
    left = skin_relax.relax(arm)
    after = {n: weights(o, bones) for n, o in meshes.items()}
    j, jblob, bin_ = read(src)
    joints = [j["nodes"][n]["name"] for n in j["skins"][0]["joints"]]
    col = [bones.index(n) if n in bones else -1 for n in joints]           # joint index -> bone index
    pos = [col.index(b) if b in col else 0 for b in range(len(bones))]     # bone index -> joint index
    changed = 0
    for node in j["nodes"]:
        if "mesh" not in node or node.get("skin") is None or node["name"] not in meshes:
            continue
        ob = meshes[node["name"]]
        n = len(ob.data.vertices)
        co = np.empty(n * 3)
        ob.data.vertices.foreach_get("co", co)
        co = co.reshape(n, 3) @ np.array(ob.matrix_basis)[:3, :3].T
        co = np.c_[co[:, 0], co[:, 2], -co[:, 1]]                          # Blender Z-up back to glTF Y-up
        grid = lookup(co)
        moved = np.abs(after[node["name"]] - before[node["name"]]).max(1) > 1e-4
        for prim in j["meshes"][node["mesh"]]["primitives"]:
            P, _, _ = accessor(j, bin_, prim["attributes"]["POSITION"])
            J, joff, jst = accessor(j, bin_, prim["attributes"]["JOINTS_0"])
            W, woff, wst = accessor(j, bin_, prim["attributes"]["WEIGHTS_0"])
            for v in range(len(P)):
                row = np.zeros(len(bones))
                for jn, wt in zip(J[v], W[v]):
                    row[col[jn]] += wt
                i, d = nearest(grid, co, P[v], row, before[node["name"]])
                if d > SAME:
                    raise SystemExit("%s: glTF vertex %d is %.5f m from any Blender vertex" % (node["name"], v, d))
                if not moved[i]:
                    continue
                row = after[node["name"]][i]
                top = np.argsort(-row)[:4]
                top = [b for b in top if row[b] > 1e-4] or [int(np.argmax(row))]
                wt = np.zeros(4, np.float32)
                jn = np.zeros(4, np.uint8)
                for k, b in enumerate(top):
                    jn[k], wt[k] = pos[b], row[b]
                wt /= wt.sum()
                bin_[joff + v * jst:joff + v * jst + 4] = jn.tobytes()
                bin_[woff + v * wst:woff + v * wst + 16] = wt.tobytes()
                changed += 1
    js = jblob
    total = 12 + 8 + len(js) + 8 + len(bin_)
    with open(dst, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<I4s", len(js), b"JSON") + js)
        f.write(struct.pack("<I4s", len(bin_), b"BIN\0") + bytes(bin_))
    print("glb_relax: %d vertices re-weighted, %d edges still over %.2f, wrote %s" % (changed, left, skin_relax.LIMIT, dst))


if __name__ == "__main__":
    a = sys.argv[sys.argv.index("--") + 1:]
    main(a[0], a[1], dict(x.split("=") for x in a[2:]))
