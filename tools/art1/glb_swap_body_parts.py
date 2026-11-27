"""Replaces a rigged body primitive's mesh with static parts from a Meshy part split of the SAME model, with no Blender.
Made 11-26 for Meeko round 13: the r12 body had its tail fused to the back of the legs (one welded surface), so a
tail bone pulled a skin sheet off the legs. Meshy's split ("wings, tail") gives a closed body and a closed tail on the
same atlas and UVs; Blender only fits them into the rig's frame and decimates them (r13 tools/bl_parts_fit.py).
Weights: every vertex of a --part takes the inverse-distance blend of its k nearest old vertices' skin (top 4 kept);
old vertices that are tail (nearest vertex of --exclude NPZ with W > 0.3: Meshy's task-rig tail chain) are not used,
so the backs of the legs the tail used to hide take leg weights. A --rigid part takes one bone at 1.0 (the tail on the
parent of its future bone; glb_tail_bone.py then moves it onto a Tail bone). The material, its texture, the rig, the
clips and every other primitive stay byte for byte.

  python3 tools/art1/glb_swap_body_parts.py IN.glb OUT.glb --mat Material_0 --parts body.glb [--rigid tail.glb=Hips]
      [--exclude tail.npz] [--k 4] [--far 0.012 --relax 200]
Cap faces (Meshy's cut caps: every UV on one atlas point) are re-mapped to the nearest real UVs (fix_caps).
Part vertices farther than --far m from every usable old vertex (new surfaces) get their weights by --relax rounds of
neighbour averaging along the part's mesh, the near vertices held fixed.
"""

import argparse
import sys

import numpy as np
from scipy.spatial import cKDTree

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from glb_add_clips import prune, read, write  # noqa: E402
from glb_tail_bone import acc, add_acc  # noqa: E402


def fix_caps(p, u, i, name):
    """Meshy's split caps its cuts with faces whose UVs all sit on one atlas point (a flat light patch). Each connected
    patch of such zero-area-UV triangles takes ONE UV: that of the real-UV vertex nearest the patch centre (3D), so it
    reads as the fur around it (per-vertex nearest UVs land on different atlas islands and paint streaks)."""
    t = i.reshape(-1, 3)
    d1, d2 = u[t[:, 1]] - u[t[:, 0]], u[t[:, 2]] - u[t[:, 0]]
    deg = np.abs(d1[:, 0] * d2[:, 1] - d1[:, 1] * d2[:, 0]) / 2 < 1e-10
    good_v = np.zeros(len(p), bool)
    good_v[t[~deg].ravel()] = True
    bad_v = np.zeros(len(p), bool)
    bad_v[t[deg].ravel()] = True
    bad_v &= ~good_v
    if not bad_v.any():
        return u
    u = u.copy()
    _, wi = np.unique(np.round(p, 5), axis=0, return_inverse=True)  # weld by position: caps meet the body at seams
    wi = wi.ravel()
    ct = t[deg]
    e = np.vstack([wi[ct[:, [0, 1]]], wi[ct[:, [1, 2]]]])
    from scipy.sparse import coo_matrix
    from scipy.sparse.csgraph import connected_components

    nv = wi.max() + 1
    _, lab = connected_components(coo_matrix((np.ones(len(e)), (e[:, 0], e[:, 1])), shape=(nv, nv)), directed=False)
    gi = np.where(good_v)[0]
    tree = cKDTree(p[gi])
    comps = np.unique(lab[wi[bad_v]])
    for c in comps:
        vs = np.where(bad_v & (lab[wi] == c))[0]
        _, ix = tree.query(p[vs].mean(0))
        u[vs] = u[gi[ix]]
    print(
        "%s: %d cap triangles with a zero-area UV, %d vertices in %d patches re-mapped"
        % (name, deg.sum(), bad_v.sum(), len(comps))
    )
    return u


def static_mesh(path):
    j, b = read(path)
    P, N, U, I = [], [], [], []
    base = 0
    for m in j["meshes"]:
        for pr in m["primitives"]:
            at = pr["attributes"]
            P.append(acc(j, b, at["POSITION"]))
            N.append(acc(j, b, at["NORMAL"]))
            U.append(acc(j, b, at["TEXCOORD_0"]))
            I.append(acc(j, b, pr["indices"]).reshape(-1).astype(np.int64) + base)
            base += len(P[-1])
    for n in j["nodes"]:
        if any(k in n for k in ("matrix", "translation", "rotation", "scale")):
            raise SystemExit("%s: node %s has a transform; export with it applied" % (path, n.get("name")))
    return np.vstack(P), np.vstack(N), np.vstack(U), np.concatenate(I)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--mat", default="Material_0")
    ap.add_argument("--parts", required=True)
    ap.add_argument("--rigid", default="")
    ap.add_argument("--exclude", default="")
    ap.add_argument("--k", type=int, default=4)
    ap.add_argument("--far", type=float, default=0.012)
    ap.add_argument("--relax", type=int, default=200)
    a = ap.parse_args()
    j, b = read(a.src)
    mesh_node = next(n for n in j["nodes"] if "mesh" in n and "skin" in n)
    sk = j["skins"][mesh_node["skin"]]
    jn = [j["nodes"][i]["name"] for i in sk["joints"]]
    mats = [m.get("name") for m in j["materials"]]
    pr = next(p for p in j["meshes"][mesh_node["mesh"]]["primitives"] if mats[p["material"]] == a.mat)
    OP = acc(j, b, pr["attributes"]["POSITION"]).astype(np.float64)
    OJ = acc(j, b, pr["attributes"]["JOINTS_0"]).astype(np.int64)
    OW = acc(j, b, pr["attributes"]["WEIGHTS_0"]).astype(np.float64)
    keep = np.ones(len(OP), bool)
    if a.exclude:
        e = np.load(a.exclude)
        d, ix = cKDTree(e["P"]).query(OP)
        keep = ~((d < 0.03) & (e["W"][ix] > 0.3))
    src_i = np.where(keep)[0]
    tree = cKDTree(OP[src_i])
    P, N, U, I, J, W = [], [], [], [], [], []
    base = 0
    for path in a.parts.split(","):
        p, n, u, i = static_mesh(path)
        u = fix_caps(p, u, i, path)
        d, ix = tree.query(p, k=a.k)
        wt = 1.0 / np.maximum(d, 1e-4)
        wt /= wt.sum(1, keepdims=True)
        full = np.zeros((len(p), len(jn)))
        for kk in range(a.k):
            oi = src_i[ix[:, kk]]
            for s in range(4):
                np.add.at(full, (np.arange(len(p)), OJ[oi, s]), wt[:, kk] * OW[oi, s])
        far = d[:, 0] > a.far
        if (
            far.any()
        ):  # surfaces the old mesh did not have (the leg backs under the tail): weights diffuse in along the mesh
            e = np.vstack([i.reshape(-1, 3)[:, [0, 1]], i.reshape(-1, 3)[:, [1, 2]], i.reshape(-1, 3)[:, [2, 0]]])
            _, wi = np.unique(np.round(p, 5), axis=0, return_inverse=True)
            wi = wi.ravel()
            e = wi[e]
            nv = wi.max() + 1
            fw = np.zeros((nv, len(jn)))
            np.add.at(fw, wi, full)
            cnt = np.bincount(wi, minlength=nv)[:, None]
            fw /= cnt
            fixed = np.ones(nv, bool)
            fixed[wi[far]] = False
            deg = np.bincount(e.ravel(), minlength=nv)[:, None]
            for _ in range(a.relax):
                acc_ = np.zeros_like(fw)
                np.add.at(acc_, e[:, 0], fw[e[:, 1]])
                np.add.at(acc_, e[:, 1], fw[e[:, 0]])
                new = acc_ / np.maximum(deg, 1)
                fw[~fixed] = new[~fixed]
            full = fw[wi]
        top = np.argsort(-full, 1)[:, :4]
        tw = np.take_along_axis(full, top, 1)
        tw /= tw.sum(1, keepdims=True)
        print("%s: %d far verts relaxed" % (path, far.sum()))
        print(
            "%s: %d verts, %d tris, nearest old vertex median %.1f mm, p99 %.1f mm"
            % (path, len(p), len(i) // 3, 1000 * np.median(d[:, 0]), 1000 * np.percentile(d[:, 0], 99))
        )
        P.append(p), N.append(n), U.append(u), I.append(i + base), J.append(top), W.append(tw)
        base += len(p)
    for spec in [s for s in a.rigid.split(",") if s]:
        path, bone = spec.split("=")
        p, n, u, i = static_mesh(path)
        u = fix_caps(p, u, i, path)
        top = np.zeros((len(p), 4), np.int64)
        top[:, 0] = jn.index(bone)
        tw = np.zeros((len(p), 4))
        tw[:, 0] = 1
        print("%s: %d verts, %d tris, rigid on %s" % (path, len(p), len(i) // 3, bone))
        P.append(p), N.append(n), U.append(u), I.append(i + base), J.append(top), W.append(tw)
        base += len(p)
    P, N, U, I = np.vstack(P), np.vstack(N), np.vstack(U), np.concatenate(I)
    J, W = np.vstack(J), np.vstack(W)
    W[W < 1e-6] = 0
    at = pr["attributes"]
    for k in [k for k in at if k not in ("POSITION", "NORMAL", "TEXCOORD_0", "JOINTS_0", "WEIGHTS_0")]:
        del at[k]
    at["POSITION"] = add_acc(j, b, P.astype(np.float32), 5126, "VEC3", True)
    at["NORMAL"] = add_acc(j, b, N.astype(np.float32), 5126, "VEC3")
    at["TEXCOORD_0"] = add_acc(j, b, U.astype(np.float32), 5126, "VEC2")
    at["JOINTS_0"] = add_acc(j, b, J.astype(np.uint16), 5123, "VEC4")
    at["WEIGHTS_0"] = add_acc(j, b, W.astype(np.float32), 5126, "VEC4")
    pr["indices"] = add_acc(j, b, I.astype(np.uint32).reshape(-1, 1), 5125, "SCALAR")
    j["accessors"][pr["indices"]]["type"] = "SCALAR"
    j["buffers"][0]["byteLength"] = len(b)
    write(a.dst, j, prune(j, b))
    print("%s: %d verts, %d tris on %s (was %d verts)" % (a.dst, len(P), len(I) // 3, a.mat, len(OP)))


if __name__ == "__main__":
    main()
