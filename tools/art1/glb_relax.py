"""Relaxes the skin weights of a shipped Hero .glb in place (tools/art1/skin_relax.py on the .glb's own clips), so no
clip tears the skin, without a re-bake: only JOINTS_0, WEIGHTS_0 and ripped triangles' indices change, in place;
every other byte of the file stays as it was.
The clips are sampled from the .glb (the same maths as the game's skin and tools/stretch_check.gd). Vertices that the
seams split (one per UV island) are welded first, so both sides of a seam get the same weights.
Each mesh first loses the deeper limb bones off its torso and other limbs (skin_relax.limbs_apart), then the
triangles that still join such a limb to the body (a scan's hand fused to the thigh it hung beside): they become
degenerate (not drawn), so the contact opens as the arm swings away instead of pulling a web of skin after it.
Run: python3 tools/art1/glb_relax.py <in.glb> <out.glb>   (numpy only, no Blender)"""
import struct
import sys

import numpy as np

import glb_add_clips
import skin_relax

SAMPLE = 0.1        # s between samples of a clip (the end is always sampled)
WELD = 1e-5         # m: seam copies of one vertex sit at the same position
WELD_WEIGHT = 1e-3  # and carry the same weights (to this step)
TYPES = {"SCALAR": 1, "VEC3": 3, "VEC4": 4, "MAT4": 16}
DTYPE = {5121: np.uint8, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}


def accessor(j, bin_, i):
    """(array [count, n], its byte offset in the bin, the view's byte stride) of accessor i."""
    ac = j["accessors"][i]
    bv = j["bufferViews"][ac["bufferView"]]
    n, dt = TYPES[ac["type"]], np.dtype(DTYPE[ac["componentType"]])
    start = bv.get("byteOffset", 0) + ac.get("byteOffset", 0)
    stride = bv.get("byteStride", n * dt.itemsize)
    rows = [np.frombuffer(bin_, dt, n, start + k * stride) for k in range(ac["count"])]
    return np.array(rows), start, stride


def quat_matrix(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def local_matrix(trs):
    m = np.eye(4)
    m[:3, :3] = quat_matrix(trs["rotation"]) * np.array(trs["scale"])[None, :]
    m[:3, 3] = trs["translation"]
    return m


def sample(times, values, mode, path, t):
    """A channel's value at time t (LINEAR: lerp, rotations nlerp; STEP; CUBICSPLINE: the key values, no tangents)."""
    if mode == "CUBICSPLINE":
        values = values[1::3]
    k = int(np.searchsorted(times, t, side="right")) - 1
    if k < 0:
        return values[0]
    if k >= len(times) - 1 or mode == "STEP":
        return values[min(k, len(times) - 1)]
    f = (t - times[k]) / max(times[k + 1] - times[k], 1e-9)
    a, b = values[k], values[k + 1]
    if path == "rotation":
        b = b if np.dot(a, b) >= 0 else -b
        q = a * (1 - f) + b * f
        return q / np.linalg.norm(q)
    return a * (1 - f) + b * f


def poses(j, bin_, skin):
    """[(clip, skinning matrices [joint, 4, 4])] every SAMPLE s of every clip (the joint's global pose times its inverse
    bind), and each node's parent."""
    nodes = j["nodes"]
    parent = [-1] * len(nodes)
    for i, nd in enumerate(nodes):
        for c in nd.get("children", []):
            parent[c] = i
    rest = [{"translation": nd.get("translation", [0, 0, 0]), "rotation": nd.get("rotation", [0, 0, 0, 1]),
             "scale": nd.get("scale", [1, 1, 1])} for nd in nodes]
    ibm = accessor(j, bin_, skin["inverseBindMatrices"])[0].reshape(-1, 4, 4).transpose(0, 2, 1)
    out = []
    for anim in j.get("animations", []):
        chans = []
        for ch in anim["channels"]:
            smp = anim["samplers"][ch["sampler"]]
            times = accessor(j, bin_, smp["input"])[0][:, 0].astype(float)
            vals = accessor(j, bin_, smp["output"])[0].astype(float)
            if ch["target"]["path"] in ("translation", "rotation", "scale"):
                mode = smp.get("interpolation", "LINEAR")
                chans.append((ch["target"]["node"], ch["target"]["path"], times, vals, mode))
        end = max(c[2][-1] for c in chans)
        for t in sorted(set(np.arange(0.0, end, SAMPLE).tolist()) | {end}):
            trs = [dict(r) for r in rest]
            for node, path, times, vals, mode in chans:
                trs[node][path] = sample(times, vals, mode, path, t)
            glob = [None] * len(nodes)

            def world(i):
                if glob[i] is None:
                    glob[i] = local_matrix(trs[i]) if parent[i] < 0 else world(parent[i]) @ local_matrix(trs[i])
                return glob[i]
            out.append((anim["name"], np.array([world(jt) @ ibm[k] for k, jt in enumerate(skin["joints"])])))
    return out, parent


def skinned(j, bin_):
    """Every skinned mesh's primitives: {mesh: [{pos, joints, weights, offsets and strides of JOINTS_0 and
    WEIGHTS_0, idx and its offset}]}."""
    out = {}
    for m in j["meshes"]:
        for pr in m["primitives"]:
            at = pr["attributes"]
            if "JOINTS_0" not in at:
                continue
            assert "JOINTS_1" not in at, "8 bones a vertex: not handled"
            jo, jo_at, jo_st = accessor(j, bin_, at["JOINTS_0"])
            wt, wt_at, wt_st = accessor(j, bin_, at["WEIGHTS_0"])
            assert j["accessors"][at["WEIGHTS_0"]]["componentType"] == 5126, "float weights only"
            idx, idx_at, _ = accessor(j, bin_, pr["indices"])
            pos = accessor(j, bin_, at["POSITION"])[0].astype(float)
            out.setdefault(m["name"], []).append({"pos": pos, "joints": jo.astype(int), "weights": wt.astype(float),
                                                  "jo": (jo_at, jo_st, jo.dtype), "wt": (wt_at, wt_st),
                                                  "idx": idx[:, 0], "idx_at": idx_at})
    return out


def weld(prims, bones):
    """One vertex per position and weights over the mesh's primitives (a split with its own weights is kept split):
    (rest [v, 3], weights [v, bone], each primitive's map to them)."""
    allpos = np.concatenate([p["pos"] for p in prims])
    dense = np.zeros((len(allpos), bones))
    joints = np.concatenate([p["joints"] for p in prims])
    np.put_along_axis(dense, joints, np.concatenate([p["weights"] for p in prims]), axis=1)
    key = np.c_[np.round(allpos / WELD), np.round(dense / WELD_WEIGHT)].astype(np.int64)
    _, first, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
    inv = inv.ravel()
    sizes = np.cumsum([0] + [len(p["pos"]) for p in prims])
    maps = [inv[a:b] for a, b in zip(sizes[:-1], sizes[1:])]
    return allpos[first], dense[first], maps


def triangles(prims, maps):
    """Every primitive's triangles as welded vertex ids [n, 3]."""
    return [mp[p["idx"].reshape(-1, 3)] for p, mp in zip(prims, maps)]


def edges_of(tris):
    """The unique edges [n, 2] of the triangles that are not degenerate."""
    t = np.concatenate(tris)
    e = np.sort(np.concatenate([t[:, [0, 1]], t[:, [1, 2]], t[:, [2, 0]]]), axis=1)
    e = np.unique(e, axis=0)
    return e[e[:, 0] != e[:, 1]]


def rip(tris, w, apart):
    """Makes every triangle with two corners whose main bones are apart degenerate (all three corners the first one)."""
    dom = w.argmax(1)
    ripped = 0
    for t in tris:
        d = dom[t]
        bad = np.zeros(len(t), bool)
        for a, b in ((0, 1), (1, 2), (2, 0)):
            bad |= apart[d[:, a], d[:, b]] | apart[d[:, b], d[:, a]]
        t[bad] = t[bad][:, :1]
        ripped += int(bad.sum())
    return ripped


def store(bin_, prims, w, maps, tris):
    """Writes each vertex's top skin_relax.MAX_INFL bones and weights over its JOINTS_0 and WEIGHTS_0, and the ripped
    triangles over the indices (a ripped corner takes the first corner's own index), in place."""
    for p, mp, t in zip(prims, maps, tris):
        idx = p["idx"].reshape(-1, 3).copy()
        gone = t[:, 1] == t[:, 0]
        idx[gone] = idx[gone][:, :1]
        bin_[p["idx_at"]:p["idx_at"] + idx.nbytes] = idx.tobytes()
        top = np.argsort(-w[mp], axis=1)[:, :skin_relax.MAX_INFL]
        wt = np.take_along_axis(w[mp], top, 1)
        wt = wt / np.maximum(wt.sum(1, keepdims=True), 1e-9)
        top[wt == 0.0] = 0
        jo_at, jo_st, jo_dt = p["jo"]
        wt_at, wt_st = p["wt"]
        for v in range(len(mp)):
            o = jo_at + v * jo_st
            bin_[o:o + 4 * jo_dt.itemsize] = top[v].astype(jo_dt).tobytes()
            o = wt_at + v * wt_st
            bin_[o:o + 16] = struct.pack("<4f", *wt[v])


def per_clip(s, pz, out):
    """Raises out[clip] to the skin's worst ratio in that clip."""
    _, per = s.stretch(pz)
    for (name, _), r in zip(pz, per):
        out[name] = max(out.get(name, 0.0), float(r))


def relax_mesh(prims, pz, apart, name, before, after):
    """Welds one mesh, takes the limbs apart, rips what still joins them, relaxes the weights and writes them back."""
    rest, w, maps = weld(prims, len(apart))
    tris = triangles(prims, maps)
    s = skin_relax.Skin.of(rest, w, edges_of(tris))
    per_clip(s, pz, before)
    s.keep_apart(apart)
    ripped = rip(tris, s.w, apart)
    s = skin_relax.Skin.of(rest, s.w, edges_of(tris))
    skin_relax.relax_skin(s, pz, "%s (%d triangles ripped)" % (name, ripped))
    per_clip(s, pz, after)
    return s.w, maps, tris


def main(args):
    j, bin_ = glb_add_clips.read(args[0])
    skin = j["skins"][0]
    pz, parent = poses(j, bin_, skin)
    names = [j["nodes"][jt]["name"] for jt in skin["joints"]]
    joint_of = {jt: k for k, jt in enumerate(skin["joints"])}
    apart = skin_relax.limbs_apart(names, [joint_of.get(parent[jt], -1) for jt in skin["joints"]])
    before, after = {}, {}
    for name, prims in skinned(j, bin_).items():
        w, maps, tris = relax_mesh(prims, pz, apart, name, before, after)
        store(bin_, prims, w, maps, tris)
    for clip in before:
        print("glb_relax %-14s %6.2f -> %6.2f" % (clip, before[clip], after[clip]))
    print("glb_relax worst %.2f -> %.2f" % (max(before.values()), max(after.values())))
    glb_add_clips.write(args[1], j, bin_)


if __name__ == "__main__":
    main(sys.argv[1:])
