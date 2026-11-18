"""A game .glb with new skin weights and nothing else: main's file byte for byte, except JOINTS_0/WEIGHTS_0 of its
body mesh.
The weights come from a second .glb of the same Hunter (a v95_swap build with --weights meshy or weights=voxel):
each vertex takes its nearest vertex's weights (bones by name), then weights that clash with a neighbour's (the nearest
vertex was on another layer or limb) are smoothed. Mesh, UVs, images, materials, nodes and clips stay.
Run: python3 glb_reweight.py <main.glb> <weights.glb> <out.glb> <body node> [<body node> ...]   (needs numpy, scipy)"""

import json
import struct
import sys

import numpy as np
from scipy.spatial import cKDTree

CLASH = 0.6  # two neighbours whose weights differ by more than this (sum of absolute differences, max 2) clash
CLASH_RINGS = 2  # vertex rings around a clash that are smoothed too
SMOOTH_PASSES = 8
PARTS = ["torso", "head", "armL", "armR", "legL", "legR"]
MIN_PART = 50  # fewest vertices a part has in the weights mesh, else its vertices look at all of them
ICP_STEPS = 12
ALIGN_GAIN = 0.8  # a part is aligned when that brings its vertices this much closer
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


def part_of(bone):
    """The body part of a bone: a head, an arm or a leg of one side, or the torso (hips, skirt, cloth chains)."""
    side = bone[-1] if bone[-2:] in (".L", ".R") else ""
    words_of = (
        ("head", ("head", "jaw", "lip")),
        ("arm", ("arm", "hand", "pauldron")),
        ("leg", ("thigh", "shin", "foot")),
    )
    for part, words in words_of:
        if any(w in bone for w in words):
            return part + (side if part != "head" else "")
    return "torso"


def parts_of(names, joints, weights):
    """Each vertex's part: the one its bones' weights add up to most. Returns an index into `PARTS`."""
    idx = np.array([PARTS.index(part_of(n)) for n in names])
    total = np.zeros((len(joints), len(PARTS)))
    np.add.at(total, (np.repeat(np.arange(len(joints)), joints.shape[1]), idx[joints].ravel()), weights.ravel())
    return total.argmax(1)


def align(src, dst):
    """`src` moved onto `dst` by rigid steps (ICP): a part (an arm) the two builds posed apart."""
    out = src.copy()
    for _ in range(ICP_STEPS):
        pairs = dst[cKDTree(dst).query(out)[1]]
        mu_a, mu_b = out.mean(0), pairs.mean(0)
        u, sv, vt = np.linalg.svd((out - mu_a).T @ (pairs - mu_b))
        rot = (u @ np.diag([1, 1, np.sign(np.linalg.det(u @ vt))]) @ vt).T
        out = (out - mu_a) @ rot.T + mu_b
    return out


def smooth_clashes(tris, weights):
    """Where neighbouring vertices got different bones (a nearest vertex on the wrong layer or limb), the weights of
    those vertices and the ring around them are averaged with their neighbours', SMOOTH_PASSES times."""
    edges = np.concatenate([tris[:, [0, 1]], tris[:, [1, 2]], tris[:, [2, 0]]])
    edges = np.concatenate([edges, edges[:, ::-1]])
    clash = np.abs(weights[edges[:, 0]] - weights[edges[:, 1]]).sum(1) > CLASH
    mask = np.zeros(len(weights), bool)
    mask[edges[clash, 0]] = True
    for _ in range(CLASH_RINGS):
        grown = mask.copy()
        grown[edges[mask[edges[:, 0]], 1]] = True
        mask = grown
    for _ in range(SMOOTH_PASSES):
        total = np.zeros_like(weights)
        count = np.zeros(len(weights))
        np.add.at(total, edges[:, 0], weights[edges[:, 1]])
        np.add.at(count, edges[:, 0], 1)
        ok = mask & (count > 0)
        weights[ok] = 0.5 * weights[ok] + 0.5 * total[ok] / count[ok][:, None]
    return int(mask.sum())


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
        prims = body_prims(jm, node)
        pos_m = [read(jm, bm, p["attributes"]["POSITION"]) for p in prims]
        P = np.concatenate(pos_m)
        joints_m = np.concatenate([read(jm, bm, p["attributes"]["JOINTS_0"]) for p in prims]).astype(int)
        wts_m = np.concatenate([read(jm, bm, p["attributes"]["WEIGHTS_0"]) for p in prims])
        part_m = parts_of(names_m, joints_m, wts_m)
        part_n = parts_of(names_n, joints, wts)
        k = np.zeros(len(P), int)
        dist = np.zeros(len(P))
        for part in range(len(PARTS)):
            mine, theirs = np.nonzero(part_m == part)[0], np.nonzero(part_n == part)[0]
            if len(mine) == 0:
                continue
            if len(theirs) < MIN_PART:
                theirs = np.arange(len(pos))
            tree = cKDTree(pos[theirs])
            dist[mine], near = tree.query(P[mine])
            moved = align(P[mine], pos[theirs])
            dist_moved, near_moved = tree.query(moved)
            if dist_moved.mean() < ALIGN_GAIN * dist[mine].mean():  # (a part the builds posed apart)
                dist[mine], near = dist_moved, near_moved
            k[mine] = theirs[near]
        J, W = remap[joints[k]], wts[k]
        if ((J < 0) & (W > 0)).any():
            sys.exit("glb_reweight: a bone of %s is not in %s" % (new, main))
        dense = np.zeros((len(P), len(names_m)))
        np.add.at(dense, (np.repeat(np.arange(len(P)), 4), np.maximum(J, 0).ravel()), W.ravel())
        _, weld = np.unique(np.round(P, 5), axis=0, return_inverse=True)  # (one vertex per place: seams and parts join)
        weld = weld.ravel()
        base = np.cumsum([0] + [len(x) for x in pos_m])
        tris = np.concatenate([weld[read(jm, bm, p["indices"]).reshape(-1, 3) + o] for p, o in zip(prims, base)])
        shared = np.zeros((weld.max() + 1, dense.shape[1]))
        shared[weld] = dense
        smoothed = smooth_clashes(tris, shared)
        dense = shared[weld]
        top = np.argsort(-dense, axis=1)[:, :4]
        top_w = np.take_along_axis(dense, top, 1)
        top_w /= top_w.sum(1, keepdims=True)
        print(
            "%s: %d vertices, nearest distance mean %.4f max %.4f m, %d welded vertices smoothed"
            % (node, len(P), dist.mean(), dist.max(), smoothed)
        )
        for p, lo, hi in zip(prims, base[:-1], base[1:]):
            for key, arr in (("JOINTS_0", top[lo:hi]), ("WEIGHTS_0", top_w[lo:hi])):
                off, st, sz, cnt, dt, n = span(jm, p["attributes"][key])
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
