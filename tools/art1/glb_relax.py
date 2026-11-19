"""Skin fix on a finished Warden .glb, for a model whose bake cannot be re-run or whose clips changed after it: v95_swap.py's
`detach` and tools/art1/skin_relax.py's weight relax, against the .glb's own clips. Only the body mesh changes: the vertices
on a detach cut are doubled, the two openings get cap triangles, and the reweighed vertices get new JOINTS_0 and WEIGHTS_0.
Every body face stays where it was and every other accessor keeps its data (clips, nodes, anchors, inverse binds, props,
textures; the buffer is laid out again when the body grew), so no clip timing and no prop moves.
The spec is the Warden's v95 swap spec (art/wardens/src/<id>_v95.json): `game` is the .glb, `detach` the bone pairs to cut
apart and `relax` the skin_relax settings (v95_swap.py reads the same keys, so a later re-swap does the same).
Measured as tools/stretch_check.gd does: spring_* vertices are left out, growth on all three axes is not stretch.
Run (numpy, no Blender needed): python3 tools/art1/glb_relax.py SPEC [OUT_GLB]      (no OUT_GLB: measure only)"""
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import skin_relax
from glb_add_clips import read, write
from kael_retarget import DTYPE, get, set_

REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
FPS = 30             # the clips' frames per second (posekit.FPS; posekit itself needs Blender)
RIGID = 0.999        # this much weight on one bone: a rigid vertex (a prop's own); the report counts those that changed
ISLAND = 40          # faces: a smaller island on a bone it is detached from joins that bone


def local(t, r, s):
    """Node matrices [n, 4, 4] from translations, xyzw rotations and scales."""
    x, y, z, w = (r / np.linalg.norm(r, axis=1, keepdims=True)).T
    m = np.zeros((len(t), 4, 4))
    m[:, :3, :3] = np.stack([1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w),
                             2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w),
                             2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)], 1).reshape(-1, 3, 3) * s[:, None, :]
    m[:, :3, 3], m[:, 3, 3] = t, 1.0
    return m


def clip_poses(j, b):
    """The skinning matrices [joint, 4, 4] of every sampled frame of every clip, with the clip's name (skin_relax's poses)."""
    nodes, skin = j["nodes"], j["skins"][0]
    parent = {c: i for i, n in enumerate(nodes) for c in n.get("children", [])}
    order = []
    for i in range(len(nodes)):      # parents first
        chain = []
        while i is not None and i not in order:
            chain.append(i)
            i = parent.get(i)
        order += chain[::-1]
    rest = {"translation": np.array([n.get("translation", [0, 0, 0]) for n in nodes], float),
            "rotation": np.array([n.get("rotation", [0, 0, 0, 1]) for n in nodes], float),
            "scale": np.array([n.get("scale", [1, 1, 1]) for n in nodes], float)}
    inv_bind = get(j, b, skin["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1).astype(float)
    out = []
    for an in j["animations"]:
        tracks = [(ch["target"]["node"], ch["target"]["path"], get(j, b, an["samplers"][ch["sampler"]]["input"])[:, 0],
                   get(j, b, an["samplers"][ch["sampler"]]["output"]).astype(float)) for ch in an["channels"]]
        end = max(t[2][-1] for t in tracks)
        for at in sorted(set(np.arange(0.0, end, skin_relax.STEP / FPS).tolist()) | {float(end)}):
            trs = {k: v.copy() for k, v in rest.items()}
            for node, path, times, vals in tracks:
                k = int(np.clip(np.searchsorted(times, at), 1, max(len(times) - 1, 1)))
                if len(times) == 1:
                    trs[path][node] = vals[0]
                    continue
                f = float(np.clip((at - times[k - 1]) / (times[k] - times[k - 1]), 0.0, 1.0))
                a, c = vals[k - 1], vals[k]
                if path == "rotation" and a @ c < 0:
                    c = -c
                trs[path][node] = a + (c - a) * f      # (nlerp between neighbouring frames; local() normalises)
            loc = local(trs["translation"], trs["rotation"], trs["scale"])
            world = [None] * len(nodes)
            for i in order:
                world[i] = world[parent[i]] @ loc[i] if i in parent else loc[i]
            out.append((an["name"], np.array([world[n] @ inv_bind[k] for k, n in enumerate(skin["joints"])])))
    return out


def body(j):
    """The skinned mesh with the most vertices: the body (a bow, an arrow are their own small meshes)."""
    size = lambda m: sum(j["accessors"][p["attributes"]["POSITION"]]["count"] for p in m["primitives"])
    return max((j["meshes"][n["mesh"]] for n in j["nodes"] if "mesh" in n and "skin" in n), key=size)


class Body:
    """The body's primitives as one vertex table: at[attribute] rows, each row's primitive, the triangles and theirs.
    weld is each row's welded vertex: rows that share a place and their weights are one (the export split them at UV seams)."""

    def __init__(self, j, b, mesh):
        self.prims = mesh["primitives"]
        assert all(p["attributes"].keys() == self.prims[0]["attributes"].keys() for p in self.prims)
        self.at = {k: np.concatenate([get(j, b, p["attributes"][k]) for p in self.prims]) for k in self.prims[0]["attributes"]}
        n = [j["accessors"][p["attributes"]["POSITION"]]["count"] for p in self.prims]
        self.prim = np.repeat(np.arange(len(n)), n)
        self.tri = np.concatenate([get(j, b, p["indices"]).reshape(-1, 3).astype(np.int64) + at
                                   for p, at in zip(self.prims, np.cumsum([0] + n))])
        self.tri_prim = np.repeat(np.arange(len(n)), [j["accessors"][p["indices"]]["count"] // 3 for p in self.prims])
        raw = lambda k: self.at[k].view(np.uint8).reshape(len(self.prim), -1)
        _, first, weld = np.unique(np.concatenate([raw("POSITION"), raw("JOINTS_0"), raw("WEIGHTS_0")], 1), axis=0,
                                   return_index=True, return_inverse=True)
        self.weld, jn = weld.ravel(), self.at["JOINTS_0"][first]
        self.rest = self.at["POSITION"][first].astype(float)
        self.w = np.zeros((len(first), len(j["skins"][0]["joints"])))
        np.add.at(self.w, (np.repeat(np.arange(len(first)), jn.shape[1]), jn.ravel()), self.at["WEIGHTS_0"][first].ravel())
        self.w /= np.maximum(self.w.sum(1, keepdims=True), 1e-9)

    def add(self, src, prim, **over):
        """New rows: copies of rows `src` in primitive `prim`, with `over`'s attributes. Returns their indices."""
        for k in self.at:
            self.at[k] = np.concatenate([self.at[k], np.broadcast_to(over[k], self.at[k][src].shape).astype(self.at[k].dtype) if k in over else self.at[k][src]])
        self.prim, self.weld = np.r_[self.prim, np.full(len(src), prim)], np.r_[self.weld, self.weld[src]]
        return np.arange(len(self.prim) - len(src), len(self.prim))

    def skin(self, name, names):
        """The welded mesh as skin_relax's Weights, and the vertices on a spring_* bone (the check leaves them out)."""
        spring = np.array([n.startswith("spring_") for n in names])[self.w.argmax(1)]
        f = self.weld[self.tri]
        ed = np.sort(np.concatenate([f[:, [0, 1]], f[:, [1, 2]], f[:, [2, 0]]]), axis=1)
        ed = np.unique(ed[ed[:, 0] != ed[:, 1]], axis=0)
        return skin_relax.Weights(name, self.rest, self.w, ed[~(spring[ed[:, 0]] | spring[ed[:, 1]])]), spring

    def store(self, j, b, moved):
        """Writes the moved welded vertices' four largest weights to their rows and every primitive back: a primitive that kept
        its size in place, a grown one as new bufferViews (the buffer is laid out again; no other accessor changes)."""
        top = np.argsort(-self.w, axis=1)[:, :skin_relax.MAX_INFL]
        wt = np.take_along_axis(self.w, top, 1)
        wt[wt < 1e-4] = 0.0
        top[wt == 0.0] = 0
        wt /= wt.sum(1, keepdims=True)
        pick = moved[self.weld]
        self.at["JOINTS_0"][pick], self.at["WEIGHTS_0"][pick] = top[self.weld[pick]], wt[self.weld[pick]]
        new = {}

        def swap(i, arr):
            ac = j["accessors"][i]
            if len(arr) == ac["count"]:
                return set_(j, b, i, arr)
            assert sum(a.get("bufferView") == ac["bufferView"] for a in j["accessors"]) == 1, "shared bufferView"
            ac["count"] = len(arr)
            if "min" in ac:
                ac["min"], ac["max"] = arr.min(0).tolist(), arr.max(0).tolist()
            new[ac["bufferView"]] = arr.astype(DTYPE[ac["componentType"]]).tobytes()
        for i, p in enumerate(self.prims):
            rows = np.nonzero(self.prim == i)[0]
            at = np.full(len(self.prim), -1)
            at[rows] = np.arange(len(rows))
            for k, a in p["attributes"].items():
                swap(a, self.at[k][rows])
            swap(p["indices"], at[self.tri[self.tri_prim == i]].reshape(-1, 1))
        if new:
            out = bytearray()
            for i, bv in enumerate(j["bufferViews"]):
                data = new.get(i, b[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]])
                out.extend(b"\0" * (-len(out) % 4))
                bv["byteOffset"], bv["byteLength"] = len(out), len(data)
                out.extend(data)
            out.extend(b"\0" * (-len(out) % 4))
            b[:] = out
            j["buffers"][0]["byteLength"] = len(b)


def detach(m, pairs, names, fixed):
    """v95_swap.py's `detach` on the finished mesh, for parts the scan fused that the clips swing apart (a hand on the thigh,
    a forearm on the hip): each face goes with its vertices' main bone, the edges between the faces of a `pairs` bone pair
    ("*": any other bone) are cut, both openings are capped, and a vertex keeps no weight on a bone its faces are cut from
    (the bake's smooth leaks the hand onto the whole thigh). An island of fewer than ISLAND faces on a bone it is cut from
    is that bone's (a skirt tatter the heat gave to the hand). The body's faces all stay, so the rest pose looks the same.
    Returns each welded vertex's index before the cut."""
    apart = np.zeros((len(names), len(names)), bool)
    for x, y in pairs:
        xs, ys = ([i for i, n in enumerate(names) if k in ("*", n)] for k in (x, y))
        apart[np.ix_(xs, ys)] = apart[np.ix_(ys, xs)] = True
    np.fill_diagonal(apart, False)
    f0 = m.weld[m.tri]
    f, d = f0.copy(), m.w.argmax(1)[f0]
    lab = np.where(d[:, 1] == d[:, 2], d[:, 1], d[:, 0])
    edge_faces, at = {}, {}
    for i, t in enumerate(f0.tolist()):
        for a, c in zip(t, t[1:] + t[:1]):
            if a != c:
                edge_faces.setdefault((min(a, c), max(a, c)), []).append(i)
                at.setdefault(a, []).append(i)
    group = list(range(len(f)))

    def root(i):
        while group[i] != i:
            group[i] = i = group[group[i]]
        return i
    for fs in edge_faces.values():      # islands: faces of one bone joined by edges
        for g in fs[1:]:
            if lab[g] == lab[fs[0]]:
                group[root(g)] = root(fs[0])
    size, votes = np.bincount([root(i) for i in range(len(f))], minlength=len(f)), {}
    for fs in edge_faces.values():
        for a in fs:
            for c in fs:
                if apart[lab[a], lab[c]] and size[root(a)] < ISLAND:
                    votes.setdefault(root(a), []).append(lab[c])
    for i in range(len(f)):
        if root(i) in votes:
            lab[i] = max(set(votes[root(i)]), key=votes[root(i)].count)
    cut = {e for e, fs in edge_faces.items() if len(fs) == 2 and apart[lab[fs[0]], lab[fs[1]]]}
    src, n0 = np.arange(len(m.w)), len(m.w)
    for v in sorted({v for e in cut for v in e}):      # a vertex on the cut: one copy per fan of faces between cut edges
        fan = {i: i for i in at[v]}

        def top(i):
            while fan[i] != i:
                i = fan[i]
            return i
        for i in at[v]:
            for u in f0[i]:
                e = (min(u, v), max(u, v))
                if u != v and e not in cut:
                    for g in edge_faces[e]:
                        fan[top(g)] = top(i)
        for r in sorted({top(i) for i in at[v]})[1:]:
            for i in at[v]:
                if top(i) == r:
                    f[i][f[i] == v] = len(src)
            src = np.r_[src, v]
    m.w, m.rest, fixed = m.w[src], m.rest[src], fixed[src]
    use, more = {}, {}
    for (i, k), g in np.ndenumerate(m.tri):      # rows follow their faces' copy; a row both sides use is doubled
        if use.setdefault(g, f[i, k]) != f[i, k]:
            if (g, f[i, k]) not in more:
                more[g, f[i, k]] = m.add([g], m.prim[g])[0]
            m.tri[i, k] = more[g, f[i, k]]
        m.weld[m.tri[i, k]] = f[i, k]
    drop, own = np.zeros(m.w.shape, bool), np.zeros(len(src), int)
    for k in range(3):
        np.logical_or.at(drop, f[:, k], apart[lab])
        own[f[:, k]] = lab
    keep = np.where(drop & ~fixed[:, None], 0.0, m.w)
    m.w = np.where(keep.sum(1, keepdims=True) > 1e-6, keep / np.maximum(keep.sum(1, keepdims=True), 1e-9), np.eye(len(names))[own])
    out, row, caps = {}, {w: g for g, w in enumerate(m.weld.tolist())}, 0
    for e in cut:      # the openings: each side's run of cut edges, in its faces' direction
        for i in edge_faces[e]:
            for a, c in zip(f[i], np.roll(f[i], -1)):
                if {src[a], src[c]} == set(e):
                    out.setdefault(a, []).append((c, i))
    todo = {(a, c, i) for a, go in out.items() for c, i in go}
    ends = {(c, i) for a, c, i in todo}
    for a, c, i in sorted(todo, key=lambda t: any(not apart[lab[g], lab[t[2]]] for x, g in ends if x == t[0])):      # open runs from their start
        if (a, c, i) not in todo:
            continue
        run, g = [a], i
        while c is not None:
            todo.discard((run[-1], c, g))
            run.append(c)
            c, g = next(((x, h) for x, h in out.get(c, []) if (c, x, h) in todo and not apart[lab[h], lab[i]]), (None, None))
        run = run[:-1] if run[-1] == run[0] else run
        if len(run) < 3:
            continue
        p = m.rest[run[::-1]]      # the cap: a fan with one flat normal and the first vertex's paint, wound against its rim
        nrm = np.cross(p[1:-1] - p[0], p[2:] - p[0]).sum(0)
        rows = m.add([row[v] for v in run], m.tri_prim[i], NORMAL=nrm / max(np.linalg.norm(nrm), 1e-9), TEXCOORD_0=m.at["TEXCOORD_0"][row[run[0]]])
        m.tri = np.concatenate([m.tri, np.stack([np.full(len(run) - 2, rows[0]), rows[2:], rows[1:-1]], 1)])
        m.tri_prim = np.r_[m.tri_prim, np.full(len(run) - 2, m.tri_prim[i])]
        caps += len(run) - 2
    by = [" and ".join(sorted(names[lab[i]] for i in edge_faces[e])) for e in cut]
    print("GLB_RELAX detach: %d edges cut (%s), %d vertices doubled, %d cap triangles"
          % (len(cut), ", ".join("%s %d" % (k, by.count(k)) for k in sorted(set(by))), len(src) - n0, caps))
    return src


def per_clip(s, poses):
    """Each clip's worst stretch, in the .glb's clip order."""
    out = {}
    for (name, _), r in zip(poses, s.stretch(poses)[1]):
        out[name] = max(out.get(name, 0.0), float(r))
    return out


def main(spec_p, out_p=None):
    spec = json.load(open(spec_p))
    for k, v in spec.get("relax", {}).items():
        setattr(skin_relax, k, v)
    j, b = read(os.path.join(REPO, spec["game"]))
    mesh = body(j)
    names = [j["nodes"][n]["name"] for n in j["skins"][0]["joints"]]
    m = Body(j, b, mesh)
    s, fixed = m.skin(mesh.get("name", "body"), names)
    poses = clip_poses(j, b)
    before, w0 = per_clip(s, poses), m.w.copy()
    if out_p:
        src = detach(m, spec.get("detach", []), names, fixed)
        s, w0 = m.skin(s.name, names)[0], w0[src]
        skin_relax.settle(s, poses)
        moved = np.abs(s.w - w0).max(1) > 1e-6
        m.store(j, b, moved)
        write(out_p, j, b)
        print("GLB_RELAX %s: %d of %d vertices reweighed (%d of them rigid on one bone before), wrote %s"
              % (s.name, moved.sum(), len(s.w), (moved & (w0.max(1) >= RIGID)).sum(), out_p))
    after = per_clip(s, poses)
    print("GLB_RELAX clip | before | after")
    for name in before:
        print("GLB_RELAX %s | %.2f | %.2f" % (name, before[name], after[name]))
    print("GLB_RELAX worst %.2f -> %.2f, best %.2f -> %.2f" % (max(before.values()), max(after.values()), min(before.values()), min(after.values())))


if __name__ == "__main__":
    main(*sys.argv[1:3])
