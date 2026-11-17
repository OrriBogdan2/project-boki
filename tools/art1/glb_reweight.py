"""A game .glb with new skin weights and nothing else: main's file byte for byte, except JOINTS_0/WEIGHTS_0 of its
body mesh.
The weights come from a second .glb of the same Hunter (a v95_swap build with --weights meshy or weights=voxel):
each vertex takes its nearest vertex's weights (bones by name), then a vertex further than HEAL from that mesh (an arm
the two builds posed differently) takes its neighbours' weights. Mesh, UVs, images, materials, nodes and clips stay.
Run: python3 glb_reweight.py <main.glb> <weights.glb> <out.glb> <body node> [<body node> ...]   (needs numpy, scipy)"""

import json
import struct
import sys

import numpy as np
from scipy.spatial import cKDTree

HEAL = 0.02  # m: a vertex further than this from the weights mesh takes its neighbours' weights
HEAL_PASSES = 8
CT = {5121: np.uint8, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def load(path):
    """(json, bin chunk) of a .glb."""
    d = open(path, "rb").read()
    jl = struct.unpack_from("<I", d, 12)[0]
    off = 20 + jl
    bl = struct.unpack_from("<I", d, off)[0]
    return json.loads(d[20:off]), d[off + 8 : off + 8 + bl]


def span(j, i):
    """(byte offset, stride, bytes per element, count, dtype, components) of accessor i."""
    a = j["accessors"][i]
    v = j["bufferViews"][a["bufferView"]]
    dt, n = np.dtype(CT[a["componentType"]]).newbyteorder("<"), NC[a["type"]]
    off = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    return off, v.get("byteStride") or n * dt.itemsize, n * dt.itemsize, a["count"], dt, n


def read(j, b, i):
    off, st, sz, cnt, dt, n = span(j, i)
    raw = np.frombuffer(b, np.uint8, count=st * cnt, offset=off).reshape(cnt, st)[:, :sz]
    return np.ascontiguousarray(raw).view(dt).reshape(cnt, n)


def joint_names(j):
    return [j["nodes"][i]["name"] for i in j["skins"][0]["joints"]]


def body_prims(j, name):
    node = next(n for n in j["nodes"] if n.get("name") == name)
    return j["meshes"][node["mesh"]]["primitives"]


def heal(prim, j, b, weights, far):
    """Dense per-vertex bone weights where `far` vertices take the mean of their near neighbours', pass by pass."""
    tris = read(j, b, prim["indices"]).ravel().reshape(-1, 3).astype(np.int64)
    for _ in range(HEAL_PASSES):
        total, count = np.zeros_like(weights), np.zeros(len(weights))
        for x, y in ((0, 1), (1, 2), (2, 0)):
            for u, v in ((tris[:, x], tris[:, y]), (tris[:, y], tris[:, x])):
                ok = ~far[v]
                np.add.at(total, u[ok], weights[v[ok]])
                np.add.at(count, u[ok], 1)
        fix = far & (count > 0)
        weights[fix] = total[fix] / count[fix][:, None]
        far &= ~fix


def reweight(main, new, out, nodes):
    jm, bm = load(main)
    jn, bn = load(new)
    bm = bytearray(bm)
    names_m, names_n = joint_names(jm), joint_names(jn)
    remap = np.array([names_m.index(x) if x in names_m else -1 for x in names_n])
    for node in nodes:
        prims_n = body_prims(jn, node)
        pos = np.concatenate([read(jn, bn, p["attributes"]["POSITION"]) for p in prims_n])
        joints = np.concatenate([read(jn, bn, p["attributes"]["JOINTS_0"]) for p in prims_n]).astype(np.int64)
        wts = np.concatenate([read(jn, bn, p["attributes"]["WEIGHTS_0"]) for p in prims_n])
        tree = cKDTree(pos)
        for p in body_prims(jm, node):
            at = p["attributes"]
            P = read(jm, bm, at["POSITION"])
            dist, k = tree.query(P)
            J, W = remap[joints[k]], wts[k]
            if ((J < 0) & (W > 0)).any():
                sys.exit("glb_reweight: a bone of %s is not in %s" % (new, main))
            dense = np.zeros((len(P), len(names_m)))
            np.add.at(dense, (np.repeat(np.arange(len(P)), 4), np.maximum(J, 0).ravel()), W.ravel())
            far = dist > HEAL
            if far.any():
                heal(p, jm, bm, dense, far)
            top = np.argsort(-dense, axis=1)[:, :4]
            top_w = np.take_along_axis(dense, top, 1)
            top_w /= top_w.sum(1, keepdims=True)
            print(
                "%s: %d vertices, nearest distance mean %.4f max %.4f m, %d far"
                % (node, len(P), dist.mean(), dist.max(), (dist > HEAL).sum())
            )
            for key, arr in (("JOINTS_0", top), ("WEIGHTS_0", top_w)):
                off, st, sz, cnt, dt, n = span(jm, at[key])
                data = arr.astype(dt).tobytes()
                for r in range(cnt):
                    bm[off + r * st : off + r * st + sz] = data[r * sz : (r + 1) * sz]
    d = bytearray(open(main, "rb").read())
    off = 20 + struct.unpack_from("<I", d, 12)[0]
    d[off + 8 : off + 8 + len(bm)] = bm
    open(out, "wb").write(d)


if __name__ == "__main__":
    if len(sys.argv) < 5:
        sys.exit(__doc__)
    reweight(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:])
