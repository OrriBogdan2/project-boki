"""Puts anchor nodes (empties: no mesh rides them) of a game .glb on points (glTF scene metres, Y up), at rest: each
node's local translation is set so its rest position lands on the point under its parent. Clips that key the anchor
itself are not touched (anchors are not keyed). With --rod-tips the points are the tips of the rods behind the head
(Sparkle's pack: the top of each loose cluster above `anchor_head_top`, behind it by ROD_BACK), given to the named
anchors in x order (fewer tips than anchors: the middle anchors share the middle tip).
Run: python3 tools/art1/glb_anchor_set.py IN OUT NAME=x,y,z ... | --rod-tips anchor_rod_0,anchor_rod_1,..."""
import sys

import numpy as np

from glb_add_clips import read, write
from glb_prop_move import _local

ROD_BACK = 0.1          # m behind the head's top (glTF +Z: the game glb faces -Z): a rod, not a hair tuft
ROD_MIN_VERTS = 20
ROD_GAP = 0.03          # m in x between two rods' vertices


def globals_(j):
    par = {c: i for i, n in enumerate(j["nodes"]) for c in n.get("children", [])}
    memo = {}

    def g(i):
        if i not in memo:
            memo[i] = (g(par[i]) if i in par else np.eye(4)) @ _local(j["nodes"][i])
        return memo[i]
    return g, par


def accessor_vec3(j, b, i):
    a = j["accessors"][i]
    v = j["bufferViews"][a["bufferView"]]
    off = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = v.get("byteStride", 0) or 12
    return np.array([np.frombuffer(bytes(b[off + k * stride:off + k * stride + 12]), np.float32) for k in range(a["count"])])


def rod_tips(j, b, top_y, back_z):
    V = np.concatenate([accessor_vec3(j, b, pr["attributes"]["POSITION"]) for me in j["meshes"] for pr in me["primitives"]])
    top = V[(V[:, 1] > top_y + 0.03) & (V[:, 2] > back_z + ROD_BACK)]
    xs = np.sort(top[:, 0])
    cut = np.where(np.diff(xs) > ROD_GAP)[0]
    edges = np.r_[xs[0], (xs[cut] + xs[cut + 1]) / 2, xs[-1] + 1]
    tips = []
    for lo, hi in zip(edges[:-1], edges[1:]):
        c = top[(top[:, 0] >= lo) & (top[:, 0] < hi)]
        if len(c) >= ROD_MIN_VERTS:
            tips.append(c[c[:, 1].argmax()])
    return tips


def main():
    a = sys.argv[1:]
    src, out = a[0], a[1]
    j, b = read(src)
    g, par = globals_(j)
    idx = {n.get("name"): i for i, n in enumerate(j["nodes"])}
    want = {}
    if a[2] == "--rod-tips":
        names = a[3].split(",")
        ht = g(idx["anchor_head_top"])[:3, 3]
        tips = rod_tips(j, b, ht[1], ht[2])
        if not tips:
            sys.exit("glb_anchor_set: no rod tips found")
        for k, n in enumerate(names):
            want[n] = tips[min(len(tips) - 1, round(k * (len(tips) - 1) / max(1, len(names) - 1)))]
    else:
        for w in a[2:]:
            n, xyz = w.split("=")
            want[n] = np.array([float(c) for c in xyz.split(",")])
    for n, p in want.items():
        i = idx[n]
        pg = g(par[i]) if i in par else np.eye(4)
        loc = np.linalg.inv(pg) @ np.r_[p, 1.0]
        before = g(i)[:3, 3]
        j["nodes"][i]["translation"] = [float(c) for c in loc[:3]]
        print("%s: %s -> %s" % (n, np.round(before.astype(float), 3).tolist(), np.round(np.asarray(p, float), 3).tolist()))
    write(out, j, b)


main()
