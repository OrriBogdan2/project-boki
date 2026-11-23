"""Grimble (dredge) native body r6: the goo arm and the hoard pack skinned so no clip pulls them into sheets.

Meshy fused the goo arm's hanging tail and puddle to the right shin, and its auto-weights tie the tail to both the
arm and the leg bones, so in Attack/run the arm dragged a ribbon from the hand to the floor (r4's re-weighting made
it worse: a few triangles stretched 300x). The pack's vertices took the weights of the nearest back vertex one by
one, so the arm shredded it into flat shards. This re-skins the r5 body glb (two primitives skin-native / skin-goo
share the vertex buffer; brass/leather pack and the coin cap are their own primitives):

- goo: Meshy's own weights (the r3 file), then the cross-links removed: above Y_CUT (0.8 m: no skin is fused there,
  it is the arm) only arm/torso weights, below it (the tail, puddle and the shin contact) only leg weights. The skin
  under the cut carries no arm weight either. A vertex left with nothing takes the mean of its neighbours (harmonic
  fill, the cut not crossed). Triangles across the cut are dropped and both rims capped with goo (a goo-on-goo cut,
  so no shin skin is ever exposed); a cap centre rides the mean weights of its rim.
- pack: rigid on the spine, a blend of the two spine bones around each vertex's height.

  python3 tools/meshy/dredge_reskin.py OUT.glb R5.glb R3.glb [Y_CUT]    # build
  python3 tools/meshy/dredge_reskin.py --stretch FILE.glb               # edges/triangles stretched >3x per clip

Needs numpy and scipy. Reports the worst edge stretch (pose length / rest length) for Idle, Attack, run, walk, jump.
"""

import sys

import native_pack as n
import numpy as np
import scipy.sparse as sp

BULGE = 0.5  # cap centre height over the rim, share of the rim radius
FILL_ITERS = 400  # harmonic fill sweeps
RIGHT_ARM = ("RightShoulder", "RightArm", "RightForeArm", "RightHand")
LEGS_BELOW_HIP = ("LeftLeg", "LeftFoot", "LeftToeBase", "RightLeg", "RightFoot", "RightToeBase")
ALL_LEGS = ("LeftUpLeg", "RightUpLeg") + LEGS_BELOW_HIP
SPINE = ("Hips", "Spine02", "Spine01", "Spine")
SPINE_Y = np.array([1.05, 1.17, 1.29, 1.40])  # rest height of those joints (m)
STRETCH_CLIPS = (("Idle", 0.3), ("Attack", 0.1), ("Attack", 0.3), ("Attack", 0.5), ("run", 0.1), ("walk", 0.3), ("Jump_Run", 0.1))


class Rig:
    """A native glb: skin joints, rest pose, clips (numpy linear-blend skinning, only for the stretch report)."""

    def __init__(self, path):
        self.js, self.b = n.load(path)
        js = self.js
        self.joints = js["skins"][0]["joints"]
        self.names = [js["nodes"][i]["name"] for i in self.joints]
        self.ibm = n.floats(js, self.b, js["skins"][0]["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
        self.parent = {c: i for i, nd in enumerate(js["nodes"]) for c in nd.get("children", [])}
        self.clips = {a["name"]: a for a in js.get("animations", [])}

    def verts(self, prim):
        js, b = self.js, self.b
        at = js["meshes"][0]["primitives"][prim]["attributes"]
        ja = js["accessors"][at["JOINTS_0"]]
        dt = np.uint8 if ja["componentType"] == 5121 else np.uint16
        joints = np.frombuffer(n.view_bytes(js, b, ja["bufferView"]), dt, ja["count"] * 4, ja.get("byteOffset", 0))
        return n.floats(js, b, at["POSITION"]), joints.reshape(-1, 4), n.floats(js, b, at["WEIGHTS_0"])

    def faces(self, prim):
        js = self.js
        ia = js["accessors"][js["meshes"][0]["primitives"][prim]["indices"]]
        dt = np.uint32 if ia["componentType"] == 5125 else np.uint16
        raw = np.frombuffer(n.view_bytes(js, self.b, ia["bufferView"]), dt, ia["count"], ia.get("byteOffset", 0))
        return raw.reshape(-1, 3).astype(np.int64)

    def pose(self, clip, t):
        js = self.js
        over = {}
        for ch in self.clips[clip]["channels"]:
            sm = self.clips[clip]["samplers"][ch["sampler"]]
            ts, vs = n.floats(js, self.b, sm["input"])[:, 0], n.floats(js, self.b, sm["output"])
            if len(ts) < 2:
                ts, vs = np.array([0.0, 1.0]), np.concatenate([vs, vs])
            k = int(np.clip(np.searchsorted(ts, min(t, ts[-1])) - 1, 0, len(ts) - 2))
            f = float(np.clip((min(t, ts[-1]) - ts[k]) / max(ts[k + 1] - ts[k], 1e-9), 0, 1))
            a, c = vs[k], vs[k + 1]
            rot = ch["target"]["path"] == "rotation"
            if rot and a @ c < 0:
                c = -c
            v = a * (1 - f) + c * f
            over.setdefault(ch["target"]["node"], {})[ch["target"]["path"]] = v / np.linalg.norm(v) if rot else v
        world = {}

        def wm(i):
            if i not in world:
                nd, o = js["nodes"][i], over.get(i, {})
                m = np.eye(4)
                m[:3, :3] = quat_mat(o.get("rotation", nd.get("rotation", [0, 0, 0, 1]))) * np.array(o.get("scale", nd.get("scale", [1, 1, 1])))
                m[:3, 3] = o.get("translation", nd.get("translation", [0, 0, 0]))
                world[i] = wm(self.parent[i]) @ m if i in self.parent else m
            return world[i]

        return np.array([wm(j) @ self.ibm[k] for k, j in enumerate(self.joints)])


def quat_mat(q):
    x, y, z, w = q
    return np.array(
        [
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
        ]
    )


def skin(pos, joints, weights, mats):
    ph = np.c_[pos, np.ones(len(pos))]
    out = np.zeros((len(pos), 3))
    for k in range(4):
        out += weights[:, k : k + 1] * np.einsum("nij,nj->ni", mats[joints[:, k]], ph)[:, :3]
    return out


def stretch_report(path):
    rig = Rig(path)
    for prim, label in enumerate(("skin", "goo")):
        pos, joints, weights = rig.verts(prim)
        f = rig.faces(prim)
        e = np.concatenate([f[:, [0, 1]], f[:, [1, 2]], f[:, [2, 0]]])
        rest = np.maximum(np.linalg.norm(pos[e[:, 0]] - pos[e[:, 1]], axis=1), 1e-5)
        cells = []
        for clip, t in STRETCH_CLIPS:
            q = skin(pos, joints, weights, rig.pose(clip, t))
            r = np.linalg.norm(q[e[:, 0]] - q[e[:, 1]], axis=1) / rest
            cells.append(f"{clip}{t}: {int((r > 3).sum())} edges >3x, max {r.max():.1f}x")
        print(label, " | ".join(cells))


def dense(joints, weights, nb):
    d = np.zeros((len(joints), nb), np.float32)
    np.add.at(d, (np.repeat(np.arange(len(joints)), 4), joints.ravel().astype(np.int64)), weights.ravel())
    return d


def top4(d):
    t = np.argsort(-d, 1)[:, :4]
    w = np.take_along_axis(d, t, 1)
    return t.astype(np.uint16), (w / np.maximum(w.sum(1, keepdims=True), 1e-9)).astype(np.float32)


def adjacency(f, nv):
    e = np.concatenate([f[:, [0, 1]], f[:, [1, 2]], f[:, [2, 0]]])
    a = sp.coo_matrix((np.ones(len(e)), (e[:, 0], e[:, 1])), (nv, nv)).tocsr()
    return ((a + a.T) > 0).astype(np.float32)


def goo_weights(rig5, rig3, y_cut):
    """Weights (vertices x joints) for every vertex, plus the goo vertex mask and its upper (arm) part."""
    pos, j5, w5 = rig5.verts(0)
    _, j3, w3 = rig3.verts(0)
    names, nb = rig5.names, len(rig5.names)
    ix = lambda group: [names.index(x) for x in group]  # noqa: E731
    fg, fn = rig5.faces(1), rig5.faces(0)
    goo = np.zeros(len(pos), bool)
    goo[np.unique(fg)] = True
    up = goo & (pos[:, 1] >= y_cut)
    lo = goo & ~up
    d5, dg = dense(j5, w5, nb), dense(j3, w3, nb)
    dg[np.ix_(up, ix(LEGS_BELOW_HIP))] = 0
    dg[np.ix_(lo, ix(RIGHT_ARM))] = 0
    skin_low = (pos[:, 1] < y_cut - 0.05) & ~goo  # the skin below the cut carries no arm weight either
    dg[skin_low] = d5[skin_low]
    dg[np.ix_(skin_low, ix(RIGHT_ARM))] = 0
    edit = goo | skin_low
    unknown = edit & (dg.sum(1) < 0.05)
    dg[unknown] = 0
    cross = up[fg].any(1) & lo[fg].any(1)
    adj = adjacency(np.concatenate([fg[~cross], fn]), len(pos))
    deg = np.maximum(np.asarray(adj.sum(1)).ravel(), 1)
    d = np.where(edit[:, None], dg / np.maximum(dg.sum(1, keepdims=True), 1e-9), d5)
    for _ in range(FILL_ITERS):
        d = np.where(unknown[:, None], (adj @ d) / deg[:, None], d)
    return d, goo, up, fg[~cross], len(pos)


def cap_loops(pos, f_kept, f_all, up):
    """The boundary loops the cut made: edges of kept triangles whose twin was dropped, grouped into loops."""
    key, inv = np.unique(np.round(pos, 5), axis=0, return_inverse=True)
    inv = inv.ravel()

    def edges(t):
        e = np.concatenate([t[:, [0, 1]], t[:, [1, 2]], t[:, [2, 0]]])
        return e, np.sort(inv[e], 1)

    def counts(k):
        u, c = np.unique(k, axis=0, return_counts=True)
        return {tuple(x): y for x, y in zip(u, c)}

    e_new, k_new = edges(f_kept)
    c_new, c_old = counts(k_new), counts(edges(f_all)[1])
    bnd = np.array([c_new[tuple(k)] == 1 and c_old.get(tuple(k), 0) == 2 for k in k_new])
    parent = {}

    def find(x):
        while parent.setdefault(x, x) != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for a, b in k_new[bnd]:
        ra, rb = find(int(a)), find(int(b))
        if ra != rb:
            parent[ra] = rb
    loops = {}
    for (a, b), (k, _) in zip(e_new[bnd], k_new[bnd]):
        loops.setdefault(find(int(k)), []).append((int(a), int(b)))
    return list(loops.values())


def pack_weights(pos, names):
    k = np.clip(np.searchsorted(SPINE_Y, np.clip(pos[:, 1], SPINE_Y[0], SPINE_Y[-1])) - 1, 0, 2)
    f = (np.clip(pos[:, 1], SPINE_Y[0], SPINE_Y[-1]) - SPINE_Y[k]) / (SPINE_Y[k + 1] - SPINE_Y[k])
    ids = np.array([names.index(x) for x in SPINE])
    joints = np.zeros((len(pos), 4), np.uint16)
    weights = np.zeros((len(pos), 4), np.float32)
    joints[:, 0], joints[:, 1], weights[:, 0], weights[:, 1] = ids[k], ids[k + 1], 1 - f, f
    return joints, weights


def build(out_path, r5_path, r3_path, y_cut):
    rig5, rig3 = Rig(r5_path), Rig(r3_path)
    js, b = rig5.js, rig5.b
    pos = rig5.verts(0)[0]
    d, goo, up, f_kept, nv = goo_weights(rig5, rig3, y_cut)
    joints, weights = top4(d)
    at0 = js["meshes"][0]["primitives"][0]["attributes"]
    attrs = {k: n.floats(js, b, v)[:nv] for k, v in at0.items() if k not in ("JOINTS_0", "WEIGHTS_0")}
    attrs["JOINTS_0"], attrs["WEIGHTS_0"] = joints, weights
    rows = {k: [] for k in attrs}
    tris, nxt = [], nv
    for es in cap_loops(pos, f_kept, rig5.faces(1), up):
        vs = np.unique(np.array(es).ravel())
        ctr = pos[vs].mean(0)
        rad = np.linalg.norm(pos[vs] - ctr, axis=1).mean()
        normal = np.array([0, -1.0 if up[vs].all() else 1.0, 0], np.float32)  # the open end of its piece
        cj, cw = top4(d[vs].mean(0, keepdims=True))
        centre, nxt = nxt, nxt + 1
        for k in attrs:
            row = attrs[k][vs[0]].copy()
            row = {"POSITION": (ctr + normal * BULGE * rad), "NORMAL": normal, "JOINTS_0": cj[0], "WEIGHTS_0": cw[0]}.get(k, row)
            rows[k].append(row)
        dup = {}
        for v in vs:  # the rim copies carry the centre's texel, so a cap never samples across the atlas
            dup[int(v)], nxt = nxt, nxt + 1
            for k in attrs:
                rows[k].append(attrs["TEXCOORD_0"][vs[0]] if k == "TEXCOORD_0" else normal if k == "NORMAL" else attrs[k][v])
        tris += [[dup[b_], dup[a_], centre] for a_, b_ in es]
    f_out = np.concatenate([f_kept, np.array(tris, np.int64).reshape(-1, 3)]).astype(np.uint32)
    for k in attrs:
        attrs[k] = np.concatenate([attrs[k], np.array(rows[k], attrs[k].dtype)])
    out = n.Out(js, b)
    acc = {}
    for k, arr in attrs.items():
        if k == "JOINTS_0":
            out.js["accessors"].append({"bufferView": out.add_view(arr.astype(np.uint16).tobytes()), "componentType": 5123, "count": len(arr), "type": "VEC4"})
            acc[k] = len(out.js["accessors"]) - 1
        else:
            acc[k] = out.add_floats(arr, {2: "VEC2", 3: "VEC3", 4: "VEC4"}[arr.shape[1]])
    js["accessors"][acc["POSITION"]].update(min=attrs["POSITION"].min(0).tolist(), max=attrs["POSITION"].max(0).tolist())
    prims = js["meshes"][0]["primitives"]
    for p in prims[:2]:
        p["attributes"].update(acc)
    js["accessors"].append({"bufferView": out.add_view(f_out.tobytes()), "componentType": 5125, "count": int(f_out.size), "type": "SCALAR"})
    prims[1]["indices"] = len(js["accessors"]) - 1
    for p in prims:
        if js["materials"][p["material"]]["name"] in ("brass-pack", "leather-pack"):
            pj, pw = pack_weights(n.floats(js, b, p["attributes"]["POSITION"]), rig5.names)
            p["attributes"]["WEIGHTS_0"] = out.add_floats(pw, "VEC4")
            js["accessors"].append({"bufferView": out.add_view(pj.tobytes()), "componentType": 5123, "count": len(pj), "type": "VEC4"})
            p["attributes"]["JOINTS_0"] = len(js["accessors"]) - 1
    compact(out)
    out.write(out_path)
    print("goo vertices", int(goo.sum()), "upper", int(up.sum()), "cap triangles", len(tris), "written", out_path)


def compact(out):
    """Drops the accessors and buffer views nothing uses (the rewrite leaves the old arrays behind)."""
    js, data = out.js, b"".join(out.chunks)
    acc = set()
    for p in js["meshes"][0]["primitives"]:
        acc.update(p["attributes"].values())
        acc.add(p["indices"])
    acc.add(js["skins"][0]["inverseBindMatrices"])
    for a in js.get("animations", []):
        for s in a["samplers"]:
            acc.update((s["input"], s["output"]))
    acc = sorted(acc)
    amap = {o: i for i, o in enumerate(acc)}
    old_acc, old_views = js["accessors"], js["bufferViews"]
    views = sorted({old_acc[i]["bufferView"] for i in acc} | {im["bufferView"] for im in js.get("images", []) if "bufferView" in im})
    js["accessors"], js["bufferViews"], out.chunks, out.size = [old_acc[i] for i in acc], [], [], 0
    vmap = {}
    for v in views:
        bv = dict(old_views[v])
        vmap[v] = out.add_view(data[bv.get("byteOffset", 0) : bv.get("byteOffset", 0) + bv["byteLength"]], bv)
    for a in js["accessors"]:
        a["bufferView"] = vmap[a["bufferView"]]
    for im in js.get("images", []):
        im["bufferView"] = vmap.get(im["bufferView"], im["bufferView"])
    for p in js["meshes"][0]["primitives"]:
        p["attributes"] = {k: amap[v] for k, v in p["attributes"].items()}
        p["indices"] = amap[p["indices"]]
    js["skins"][0]["inverseBindMatrices"] = amap[js["skins"][0]["inverseBindMatrices"]]
    for a in js.get("animations", []):
        for s in a["samplers"]:
            s["input"], s["output"] = amap[s["input"]], amap[s["output"]]


if __name__ == "__main__":
    if sys.argv[1] == "--stretch":
        stretch_report(sys.argv[2])
    else:
        build(sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4]) if len(sys.argv) > 4 else 0.8)
