"""Skin-weight relax on a built Warden .glb, in place: only the JOINTS_0 and WEIGHTS_0 bytes change, so the mesh, rig,
clips, anchors and materials stay byte for byte (for a Warden whose bake cannot be re-run; a bake calls skin_relax.relax).
Poses every clip from the file's own keys (the maths of the game's skin and of tools/stretch_check.gd), then hands the
welded mesh to skin_relax: no clip may stretch an edge past its LIMIT. Vertices on spring_* bones (the game's physics
ropes and cloth, which the check does not measure) and on the bones named in --keep keep their weights.
Run: python3 tools/art1/glb_relax.py <in.glb> [out.glb] [--keep=bone,bone] [--dry: measure only]   (numpy; any Python that has it,
or Blender's: blender -b --python tools/art1/glb_relax.py -- <in.glb> ...)"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb_add_clips
import skin_relax

STEP = 1.0 / 16.0    # s between samples of a clip (the check samples every 0.125 s and at the end)
END = 0.001          # s before a clip's end that the check takes its last sample at
SIZES = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
TYPES = {5121: np.uint8, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}


def view(j, b, i):
    """Accessor i as a numpy view into the buffer [count, components] (writes go to the file's bytes)."""
    ac = j["accessors"][i]
    bv = j["bufferViews"][ac["bufferView"]]
    dt = np.dtype(TYPES[ac["componentType"]])
    n = SIZES[ac["type"]]
    at = bv.get("byteOffset", 0) + ac.get("byteOffset", 0)
    stride = bv.get("byteStride", dt.itemsize * n)
    return np.ndarray((ac["count"], n), dt, b, at, (stride, dt.itemsize))


def matrices(t, r, s):
    """Local matrices [..., 4, 4] from translations, xyzw quaternions and scales."""
    x, y, z, w = (r / np.linalg.norm(r, axis=-1, keepdims=True)).T
    rot = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                    [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                    [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]).T.swapaxes(-1, -2)
    m = np.zeros(t.shape[:-1] + (4, 4))
    m[..., :3, :3] = rot * s[..., None, :]
    m[..., :3, 3] = t
    m[..., 3, 3] = 1.0
    return m


def sample(times, keys, at, quat):
    """Linear keys at the times `at` (quaternions take the short way round and are normalised by matrices())."""
    hi = np.clip(np.searchsorted(times, at), 1, max(len(times) - 1, 1)) if len(times) > 1 else np.zeros(len(at), int)
    lo = np.maximum(hi - 1, 0)
    k = np.clip((at - times[lo]) / np.maximum(times[hi] - times[lo], 1e-9), 0.0, 1.0)[:, None]
    a, b = keys[lo], keys[hi]
    if quat:
        b = np.where((a * b).sum(1, keepdims=True) < 0.0, -b, b)
    return a * (1 - k) + b * k


def poses(j, b):
    """[(clip name, skinning matrices [joint, 4, 4])] for every sampled time of every clip."""
    nodes = j["nodes"]
    skin = j["skins"][0]
    ibm = view(j, b, skin["inverseBindMatrices"]).reshape(-1, 4, 4).swapaxes(1, 2).astype(float)
    parent = {c: i for i, n in enumerate(nodes) for c in n.get("children", [])}
    order = []
    todo = [i for i in range(len(nodes)) if i not in parent]
    while todo:
        i = todo.pop()
        order.append(i)
        todo += nodes[i].get("children", [])
    rest = {"translation": np.array([n.get("translation", [0, 0, 0]) for n in nodes], float),
            "rotation": np.array([n.get("rotation", [0, 0, 0, 1]) for n in nodes], float),
            "scale": np.array([n.get("scale", [1, 1, 1]) for n in nodes], float)}
    out = []
    for an in j.get("animations", []):
        length = max(float(view(j, b, s["input"]).max()) for s in an["samplers"])
        at = np.unique(np.append(np.arange(0.0, length, STEP), max(length - END, 0.0)))
        trs = {k: np.repeat(v[None], len(at), 0) for k, v in rest.items()}
        for ch in an["channels"]:
            path = ch["target"]["path"]
            if path in trs:
                smp = an["samplers"][ch["sampler"]]
                times = view(j, b, smp["input"])[:, 0].astype(float)
                trs[path][:, ch["target"]["node"]] = sample(times, view(j, b, smp["output"]).astype(float), at, path == "rotation")
        flat = len(at) * len(nodes)
        local = matrices(trs["translation"].reshape(flat, 3), trs["rotation"].reshape(flat, 4),
                         trs["scale"].reshape(flat, 3)).reshape(len(at), len(nodes), 4, 4)
        world = np.empty_like(local)
        for i in order:
            world[:, i] = world[:, parent[i]] @ local[:, i] if i in parent else local[:, i]
        mats = world[:, skin["joints"]] @ ibm
        out += [(an["name"], m) for m in mats]
    return out


class Mesh:
    """Every skinned primitive of the file as one welded mesh: vertices at one place with one set of weights are one.
    Vertices whose heaviest bone is a spring_* one or one of `keep` are left out of the edges, so nothing measures or moves them."""

    def __init__(self, j, b, keep):
        joints = np.array([j["nodes"][i].get("name", "") for i in j["skins"][0]["joints"]])
        self.views = []          # (JOINTS_0 view, WEIGHTS_0 view, its first row in the split arrays)
        pos, dense, tris = [], [], []
        n = 0
        for node in j["nodes"]:
            if "skin" not in node or "mesh" not in node:
                continue
            for pr in j["meshes"][node["mesh"]]["primitives"]:
                a = pr["attributes"]
                if "JOINTS_0" not in a or "indices" not in pr:
                    continue
                jv, wv, p = view(j, b, a["JOINTS_0"]), view(j, b, a["WEIGHTS_0"]), view(j, b, a["POSITION"])
                w = np.zeros((len(p), len(joints)))
                np.add.at(w, (np.arange(len(p))[:, None], jv.astype(int)), wv.astype(float))
                self.views.append((jv, wv, n))
                pos.append(p.astype(float))
                dense.append(w / np.maximum(w.sum(1, keepdims=True), 1e-9))
                tris.append(view(j, b, pr["indices"]).reshape(-1, 3).astype(np.int64) + n)
                n += len(p)
        pos, dense, tris = np.concatenate(pos), np.concatenate(dense), np.concatenate(tris)
        _, first, weld = np.unique(np.c_[np.round(pos, 5), np.round(dense, 4)], axis=0, return_index=True, return_inverse=True)
        self.weld = weld.ravel()
        tw = self.weld[tris]
        edges = np.unique(np.sort(np.concatenate([tw[:, [0, 1]], tw[:, [1, 2]], tw[:, [2, 0]]]), axis=1), axis=0)
        w = dense[first]
        held = np.array([nm.startswith("spring_") or nm in keep for nm in joints[w.argmax(1)]])
        self.skin = skin_relax.Skin(pos[first], w, edges[(edges[:, 0] != edges[:, 1]) & ~held[edges].any(1)])

    def store(self):
        """Writes the welded weights back to every split vertex: its four heaviest bones, summing to 1."""
        w = self.skin.w[self.weld]
        top = np.argsort(-w, axis=1)[:, :skin_relax.MAX_INFL]
        wt = np.take_along_axis(w, top, 1)
        wt = wt / np.maximum(wt.sum(1, keepdims=True), 1e-9)
        top[wt <= 0.0] = 0
        for jv, wv, at in self.views:
            jv[:] = top[at:at + len(jv)]
            wv[:] = wt[at:at + len(wv)]


def report(skin, all_poses, label):
    """Prints the worst stretch and the clips over the check's limit."""
    worst, per = skin.stretch(all_poses)
    by_clip = {}
    for (name, _), r in zip(all_poses, per):
        by_clip[name] = max(by_clip.get(name, 0.0), r)
    over = sorted((r, nm) for nm, r in by_clip.items() if r > skin_relax.CUT_LIMIT)
    print("%s: worst %.2f, edges over %.2f: %d, clips over: %d of %d%s" % (
        label, max(per), skin_relax.CUT_LIMIT, int((worst > skin_relax.CUT_LIMIT).sum()), len(over), len(by_clip),
        " (worst %s)" % over[-1][1] if over else ""), flush=True)
    return by_clip


def main(args):
    paths = [a for a in args if not a.startswith("--")]
    keep = set(",".join(a[7:] for a in args if a.startswith("--keep=")).split(","))
    j, b = glb_add_clips.read(paths[0])
    mesh = Mesh(j, b, keep)
    all_poses = poses(j, b)
    report(mesh.skin, all_poses, "before")
    if "--dry" in args:
        return
    done = skin_relax.settle(mesh.skin, all_poses)
    print("relax: edges over %.2f: %d -> %d after %d passes" % (skin_relax.LIMIT, *done[:3]))
    report(mesh.skin, all_poses, "after")
    mesh.store()
    glb_add_clips.write(paths[-1], j, b)


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:])
